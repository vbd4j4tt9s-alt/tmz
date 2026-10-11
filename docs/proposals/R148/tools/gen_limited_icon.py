"""R148: builds the data of the LIMITED tab icon from limited_icon.py and (with --write) puts it into the game's two data modules,
in exactly the format of the other tab logos.

  BiomeIconData.lua          Limited={Size=96,TinyWidth=24,TinyHeight=24,RGBA="<base64 of a zstd frame of the 96x96 RGBA raster>",
                                      Palette={...14 colours...},Runs={{x,y,w,colour,h},...}}      (like Forest ... Mech)
  ArtworkFallbackData89.lua  ["Limited"]="<hex of the prepared 64x64 smooth-strip fallback>"       (decoded by that module, drawn by
                                                                                                   ArtworkRuntime87 before / without the image)

  python3 gen_limited_icon.py                 # prints sizes, writes nothing
  python3 gen_limited_icon.py --png OUT.png   # also saves the 96x96 icon
  python3 gen_limited_icon.py --write         # (re)writes the two modules in this checkout (idempotent: replaces an old Limited entry)

The RGBA field is a real zstd frame (python `zstandard`; `pip install zstandard` if it is missing): single segment, content size
36864, no checksum - the same header the existing entries have (28 B5 2F FD 60 00 8F ...), which EncodingService:DecompressBuffer
(Enum.CompressionAlgorithm.Zstd) reads. --verify decompresses it again and compares every byte.
"""
import base64, math, os, re, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
RS = os.path.join(REPO, 'src', 'ReplicatedStorage')
KIND = 'Limited'


def zstd_module():
    try:
        import zstandard
        return zstandard
    except ImportError:
        sys.exit('python module "zstandard" is missing: pip install zstandard (or pip install --target DIR zstandard and set PYTHONPATH=DIR)')


# ---------------------------------------------------------------------------------------------------------------------------------
def palettize(img, k=96, iters=12):
    """The other logos carry 48 colours; this one keeps 96 (k-means over the visible pixels) so its gradients stay smooth, and
    keeps the full alpha of its edges. Colour of fully transparent pixels is 0 (compresses better, nothing can see it)."""
    a = np.array(img.convert('RGBA'), dtype=np.uint8)
    vis = a[..., 3] > 0
    px = a[vis][:, :3].astype(np.float64)
    seed = Image.fromarray(px.astype(np.uint8).reshape(-1, 1, 3), 'RGB').quantize(colors=k, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    c = np.array(seed.getpalette()[:k * 3], dtype=np.float64).reshape(k, 3)
    for _ in range(iters + 1):
        label = ((px[:, None, :] - c[None, :, :]) ** 2).sum(2).argmin(1)
        for j in range(k):
            m = label == j
            if m.any():
                c[j] = px[m].mean(0)
    label = ((px[:, None, :] - c[None, :, :]) ** 2).sum(2).argmin(1)
    a[vis, :3] = np.round(c[label]).astype(np.uint8)
    a[a[..., 3] == 0] = 0
    return Image.fromarray(a, 'RGBA')


def raster(img):
    """The 96x96 RGBA bytes."""
    return np.array(img.convert('RGBA'), dtype=np.uint8).tobytes()


def compress(raw):
    z = zstd_module()
    best = None
    for level in (19, 20, 21, 22):
        c = z.ZstdCompressor(level=level, write_content_size=True, write_checksum=False, write_dict_id=False).compress(raw)
        if best is None or len(c) < len(best):
            best = c
    return best


def rgba_field(raw):
    return base64.b64encode(compress(raw)).decode('ascii')


# ---- the 24x24 palette + runs (what Forest ... Mech carry as Palette / Runs) --------------------------------------------------------
def tiny(img, colors=14):
    a = np.array(img.convert('RGBA'), dtype=np.float64)
    pre = a.copy()
    pre[..., :3] *= pre[..., 3:4] / 255.0
    box = pre.reshape(24, 4, 24, 4, 4).mean(axis=(1, 3))        # premultiplied box average 96 -> 24
    alpha = box[..., 3]
    rgb = np.where(alpha[..., None] > 0, box[..., :3] / np.maximum(alpha[..., None], 1e-6) * 255.0, 0).clip(0, 255)
    opaque = alpha >= 120
    im = Image.fromarray(rgb.astype(np.uint8), 'RGB').quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = im.getpalette()[:colors * 3]
    idx = np.array(im)
    palette = [tuple(int(v) for v in pal[i * 3:i * 3 + 3]) for i in range(colors)]
    runs = []
    done = np.zeros((24, 24), bool)
    for y in range(24):
        x = 0
        while x < 24:
            if not opaque[y, x] or done[y, x]:
                x += 1
                continue
            c = idx[y, x]
            w = 1
            while x + w < 24 and opaque[y, x + w] and not done[y, x + w] and idx[y, x + w] == c:
                w += 1
            h = 1
            while h < 3 and y + h < 24 and all(opaque[y + h, x + k] and not done[y + h, x + k] and idx[y + h, x + k] == c for k in range(w)):
                h += 1
            done[y:y + h, x:x + w] = True
            runs.append((x, y, w, int(c) + 1, h))
            x += w
    return palette, runs


def lua_tiny(palette, runs):
    return 'Palette={' + ','.join('{%d,%d,%d}' % p for p in palette) + '},Runs={' + ','.join('{%d,%d,%d,%d,%d}' % r for r in runs) + '}'


# ---- the prepared smooth fallback (ArtworkFallbackData89 format) --------------------------------------------------------------------
def fallback_strips(raw, w=96, h=96, thr=28):
    """Python port of ArtworkFallback87.Build (the runtime's own builder): 64 rows, <= 32 stops per row in groups of 6."""
    height = 64
    width = max(2, math.floor(height * w / h + .5))
    a = np.frombuffer(raw, np.uint8).reshape(h, w, 4).astype(np.float64)
    strips = []
    for y in range(height):
        row = []
        sy = (y + .5) * h / height - .5
        for x in range(width):
            sx = (x + .5) * w / width - .5
            sx = min(max(sx, 0), w - 1)
            syc = min(max(sy, 0), h - 1)
            x0, y0 = math.floor(sx), math.floor(syc)
            x1, y1 = min(x0 + 1, w - 1), min(y0 + 1, h - 1)
            fx, fy = sx - x0, syc - y0
            p = []
            for c in range(4):
                v = (a[y0, x0, c] + (a[y0, x1, c] - a[y0, x0, c]) * fx) * (1 - fy) + (a[y1, x0, c] + (a[y1, x1, c] - a[y1, x0, c]) * fx) * fy
                p.append(math.floor(v + .5))
            row.append(p)
        idx = [1, width]
        while len(idx) < 32:
            worst, at = thr, None
            for j in range(len(idx) - 1):
                lo, hi = idx[j], idx[j + 1]
                for k in range(lo + 1, hi):
                    t = (k - lo) / (hi - lo)
                    for c in range(4):
                        e = abs(row[lo - 1][c] + (row[hi - 1][c] - row[lo - 1][c]) * t - row[k - 1][c]) * (1 if c == 3 else row[k - 1][3] / 255)
                        if e > worst:
                            worst, at = e, k
            if at is None:
                break
            idx.append(at)
            idx.sort()
        j = 0
        while j < len(idx) - 1:
            last = min(j + 5, len(idx) - 1)
            lo, hi = idx[j], idx[last]
            keys, visible = [], False
            for i in range(j, last + 1):
                k = idx[i]
                p = row[k - 1]
                keys.append(((k - lo) / (hi - lo), p[0], p[1], p[2], p[3]))
                if p[3] >= 3:
                    visible = True
            if visible:
                strips.append((lo - 1, y, hi - lo + 1, keys))
            j += 5
    return width, height, strips


def fallback_hex(raw, colors=48):
    width, height, strips = fallback_strips(raw)
    cols = np.array([k[1:4] for s in strips for k in s[3]], dtype=np.uint8).reshape(-1, 1, 3)
    pal_img = Image.fromarray(cols, 'RGB').quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    pal = np.array(pal_img.getpalette()[:colors * 3], dtype=np.int32).reshape(colors, 3)
    out = bytearray([width, height, colors])
    for p in pal:
        out += bytes(int(v) for v in p)
    out += bytes([len(strips) & 255, len(strips) >> 8])
    for x, y, w, keys in strips:
        out += bytes([x, y, w, len(keys)])
        for t, r, g, b, al in keys:
            d = ((pal - np.array([r, g, b])) ** 2).sum(axis=1)
            out += bytes([int(round(t * 255)), int(d.argmin()), al])
    return out.hex(), (width, height, strips)


def decode_fallback(hexs):
    """The decoder of ArtworkFallbackData89, in Python: (w, h, strips[(x,y,w,[(t,r,g,b,a)])])."""
    b = bytes.fromhex(hexs)
    at = 0

    def byte():
        nonlocal at
        v = b[at]
        at += 1
        return v
    w, h, n = byte(), byte(), byte()
    pal = [(byte(), byte(), byte()) for _ in range(n)]
    cnt = byte() + byte() * 256
    strips = []
    for _ in range(cnt):
        x, y, ww, k = byte(), byte(), byte(), byte()
        keys = []
        for _ in range(k):
            t, i, al = byte(), byte(), byte()
            keys.append((t / 255, *pal[i], al))
        strips.append((x, y, ww, keys))
    assert at == len(b), 'invalid fallback artwork'
    return w, h, strips


def render_fallback(spec, scale=4, bg=(73, 109, 204)):
    """Draws strips the way the game does (each strip = one gradient frame, colour and alpha interpolated)."""
    w, h, strips = spec
    im = Image.new('RGBA', (w * scale, h * scale), bg + (255,))
    px = im.load()
    for x, y, ww, keys in strips:
        for X in range(int(ww * scale)):
            t = (X + .5) / (ww * scale)
            k0, k1 = keys[0], keys[-1]
            for a, b in zip(keys, keys[1:]):
                if a[0] <= t <= b[0]:
                    k0, k1 = a, b
                    break
            u = 0 if k1[0] == k0[0] else min(1, max(0, (t - k0[0]) / (k1[0] - k0[0])))
            c = [k0[i] + (k1[i] - k0[i]) * u for i in range(1, 5)]
            al = c[3] / 255
            for Y in range(scale):
                xx, yy = x * scale + X, y * scale + Y
                if 0 <= xx < w * scale and 0 <= yy < h * scale:
                    o = px[xx, yy]
                    px[xx, yy] = tuple(int(o[i] * (1 - al) + c[i] * al) for i in range(3)) + (255,)
    return im


# ---- the modules ---------------------------------------------------------------------------------------------------------------------
def biome_entry(img, raw):
    palette, runs = tiny(img)
    return 'Limited={Size=96,TinyWidth=24,TinyHeight=24,RGBA="%s",%s}' % (rgba_field(raw), lua_tiny(palette, runs))


def patch_biome_icons(entry):
    path = os.path.join(RS, 'BiomeIconData.lua')
    lines = open(path, encoding='utf-8').read().split('\n')
    start = next(i for i, l in enumerate(lines) if l.strip() == 'return {')
    head = lines[:start + 1]
    # one entry per line; every entry but the last ends with a comma. An older Limited entry is replaced.
    entries = [l.rstrip(',') for l in lines[start + 1:] if re.match(r'^\w+=\{', l) and not l.startswith(KIND + '=')]
    entries.append(entry)
    open(path, 'w', encoding='utf-8', newline='\n').write('\n'.join(head) + '\n' + ',\n'.join(entries) + '\n}\n')


def patch_fallback(hexs):
    path = os.path.join(RS, 'ArtworkFallbackData89.lua')
    s = open(path, encoding='utf-8').read()
    s = re.sub(r',\["%s"\]="[0-9a-f]*"' % KIND, '', s)
    i = s.index('local encoded={')
    j = s.index('}\nlocal function decode', i)
    s = s[:j] + ',["%s"]="%s"' % (KIND, hexs) + s[j:]
    open(path, 'w', encoding='utf-8', newline='\n').write(s)


def verify(img, raw, field, hexs, spec):
    z = zstd_module()
    comp = base64.b64decode(field)
    assert comp[:4] == bytes.fromhex('28b52ffd'), 'zstd magic'
    assert z.ZstdDecompressor().decompress(comp, max_output_size=96 * 96 * 4) == raw, 'zstd round trip differs'
    assert len(raw) == 96 * 96 * 4
    fb = decode_fallback(hexs)
    assert fb[0] == spec[0] and fb[1] == spec[1] and len(fb[2]) == len(spec[2]), 'fallback decode'
    return True


def main(argv):
    from limited_icon import draw
    img = palettize(draw())
    raw = raster(img)
    if '--png' in argv:
        img.save(argv[argv.index('--png') + 1])
    field = rgba_field(raw)
    hexs, spec = fallback_hex(raw)
    verify(img, raw, field, hexs, spec)
    comp = base64.b64decode(field)
    print('icon 96x96, zstd frame %d bytes (header %s), RGBA field %d chars, fallback %d strips / %d hex chars' % (
        len(comp), comp[:8].hex(), len(field), len(spec[2]), len(hexs)))
    if '--write' in argv:
        patch_biome_icons(biome_entry(img, raw))
        patch_fallback(hexs)
        print('wrote', os.path.join(RS, 'BiomeIconData.lua'), 'and', os.path.join(RS, 'ArtworkFallbackData89.lua'))


if __name__ == '__main__':
    main(sys.argv[1:])
