"""R153: the owner's 4 Leaf Clover picture (clover_owner.webp, 1254x1254 RGBA) -> src/ReplicatedStorage/CloverPassImage153.lua.
The game draws it on the client (EmbeddedImage153: base64 + inflate -> EditableImage) until / unless the pass's own Roblox icon is there, so nothing is uploaded.
Steps: crop to the picture's alpha box (alpha > 40) (+8 %, square, centred) -> resize to 128x128 in PREMULTIPLIED space (PIL mode 'RGBa': clean edges, no dark or
light fringe) -> back to straight RGBA -> every fully transparent pixel gets one dark green (it compresses, and bilinear filtering bleeds green, not
black, into the edge) -> the colour plane is quantised to 256 colours (median cut, no dither: the picture is flat-shaded low poly) ->
stream = palette (3 x Colors bytes: RGB) + indices (W x H, top row first) + alpha (W x H) -> raw deflate (RFC 1951, level 9) -> base64, in 100-character lines.
The module also holds Key (the cache key), Bytes (the stream length) and Check (Adler-32 of the stream); EmbeddedImage153 checks both.
Usage: python3 encode_clover.py [clover_owner.webp] [out.lua]      (needs Pillow + numpy)
       python3 encode_clover.py --check [out.lua]                  (re-reads the module with an independent decoder and prints the size and the alpha box)
       python3 encode_clover.py --adler [out.lua]                  (prints ADLER <Adler-32 of the decoded RGBA>: the game's own decoder must print the same, run_clover.sh compares)"""
import base64
import os
import re
import sys
import zlib

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE, COLORS = 128, 256
BLEED = (24, 110, 36)


def encode(src):
    im = Image.open(src).convert('RGBA')
    x0, y0, x1, y1 = im.getchannel('A').point(lambda v: 255 if v > 40 else 0).getbbox()  # (the soft fringe does not count)
    side = max(x1 - x0, y1 - y0) * 1.08
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    box = tuple(int(round(v)) for v in (cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2))
    small = im.crop(box).convert('RGBa').resize((SIZE, SIZE), Image.LANCZOS).convert('RGBA')
    a = np.array(small)
    alpha = a[..., 3].copy()
    alpha[alpha >= 248] = 255  # (the source's inside is alpha 252 / 253: make it solid)
    alpha[alpha < 8] = 0  # (a pixel with alpha 1..7 has lost its colour in the resize: it would be a black speck, so it is dropped)
    rgb = a[..., :3].copy()
    rgb[alpha == 0] = BLEED
    q = Image.fromarray(rgb, 'RGB').quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(q.getpalette()[:COLORS * 3], dtype=np.uint8).reshape(-1, 3)
    if len(pal) < COLORS:
        pal = np.concatenate([pal, np.zeros((COLORS - len(pal), 3), dtype=np.uint8)])
    idx = np.array(q, dtype=np.uint8)
    raw = pal.tobytes() + idx.tobytes() + alpha.tobytes()
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    z = c.compress(raw) + c.flush()
    return raw, z


def write(raw, z, out):
    b64 = base64.b64encode(z).decode('ascii')
    lines = [b64[i:i + 100] for i in range(0, len(b64), 100)]
    with open(out, 'w', encoding='utf-8') as f:
        f.write('-- R153 (owner: the 4 Leaf Clover pass picture): the owner\'s chunky low-poly clover, %dx%d, drawn on the client with EditableImage (CloverIcon153 -> EmbeddedImage153) until the pass\'s own Roblox icon is there.\n' % (SIZE, SIZE))
        f.write('-- Made by docs/proposals/R153/tools/encode_clover.py (it describes the format): stream = palette (Colors x RGB) + indices (Width x Height, top row first) + alpha (Width x Height),\n')
        f.write('-- raw deflate, base64. Bytes = the stream length, Key = the cache key, Check = its Adler-32. Decoded by EmbeddedImage153 (pure Luau), once per client.\n')
        f.write("return {Key='CloverPass153',Width=%d,Height=%d,Colors=%d,Bytes=%d,Check=%d,Data={\n" % (SIZE, SIZE, COLORS, len(raw), zlib.adler32(raw)))
        for l in lines:
            f.write("'%s',\n" % l)
        f.write('}}\n')
    return len(b64)


def check(path):
    text = open(path, encoding='utf-8').read()
    w, h, colors, nbytes, adler = (int(re.search(k + r'=(\d+)', text).group(1)) for k in ('Width', 'Height', 'Colors', 'Bytes', 'Check'))
    b64 = ''.join(re.findall(r"^'([A-Za-z0-9+/=]+)',$", text, re.M))
    raw = zlib.decompress(base64.b64decode(b64), -15)
    assert len(raw) == nbytes == colors * 3 + 2 * w * h, (len(raw), nbytes)
    assert zlib.adler32(raw) == adler
    pal = np.frombuffer(raw[:colors * 3], dtype=np.uint8).reshape(-1, 3)
    idx = np.frombuffer(raw[colors * 3:colors * 3 + w * h], dtype=np.uint8).reshape(h, w)
    alpha = np.frombuffer(raw[colors * 3 + w * h:], dtype=np.uint8).reshape(h, w)
    rgba = np.concatenate([pal[idx], alpha[..., None]], axis=2)
    ys, xs = np.nonzero(alpha)
    print('module %d bytes; %dx%d; alpha box x %d..%d y %d..%d; corners alpha %s; opaque pixels %d' % (
        os.path.getsize(path), w, h, xs.min(), xs.max(), ys.min(), ys.max(), [int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])], int((alpha == 255).sum())))
    return rgba


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    default_out = os.path.normpath(os.path.join(HERE, '../../../../src/ReplicatedStorage/CloverPassImage153.lua'))
    if '--adler' in sys.argv:
        print('ADLER %d' % zlib.adler32(check(args[0] if args else default_out).tobytes()))
    elif '--check' in sys.argv:
        check(args[0] if args else default_out)
    else:
        src = args[0] if args else os.path.join(HERE, 'clover_owner.webp')
        out = args[1] if len(args) > 1 else default_out
        raw, z = encode(src)
        n = write(raw, z, out)
        print('wrote %s: stream %d bytes -> deflate %d -> base64 %d; file %d bytes' % (out, len(raw), len(z), n, os.path.getsize(out)))
        check(out)
