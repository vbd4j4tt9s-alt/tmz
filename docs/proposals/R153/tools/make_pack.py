"""R153: the owner's bonus pack picture -> a small straight-RGBA image -> the Luau data module src/ReplicatedStorage/BonusPackImage153.lua.
Clean edges: scaled down in PREMULTIPLIED space (no halo from the colour of transparent pixels), and every transparent pixel carries the colour of the nearest
opaque one (so bilinear scaling on screen never shows a dark fringe). Then a 256-colour palette + an alpha plane, raw deflate, base64.
Raw layout (what EmbeddedImage153 decodes): 256 x 3 palette bytes, W x H palette indices (row by row), W x H alpha bytes.
Usage: python3 -I make_pack.py <source.webp> <out.lua> [size=112] [preview.png]   (the preview is what the decoder will produce)"""
import base64
import sys
import zlib

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 112
preview = sys.argv[4] if len(sys.argv) > 4 else None
im = Image.open(src).convert('RGBA')
# the owner's file is 252 / 253 where it is solid (not 255): stretch that to fully opaque, drop the faint noise
im.putalpha(im.getchannel('A').point(lambda v: 0 if v < 6 else min(255, round(v * 255 / 252))))
im = im.crop(im.getchannel('A').getbbox())
margin = max(1, round(size * 0.02))
scale = (size - 2 * margin) / max(im.size)
nw, nh = max(1, round(im.size[0] * scale)), max(1, round(im.size[1] * scale))
small = im.convert('RGBa').resize((nw, nh), Image.LANCZOS, reducing_gap=3.0).convert('RGBA')
canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
canvas.paste(small, ((size - nw) // 2, (size - nh) // 2))
W = H = size
px = list(canvas.getdata())
alpha = [p[3] if p[3] >= 4 else 0 for p in px]
rgb = [(p[0], p[1], p[2]) for p in px]
known = [a > 0 for a in alpha]
frontier = [i for i in range(W * H) if known[i]]
while frontier:  # colour bleed: breadth-first from every pixel that has alpha
    nxt = []
    for i in frontier:
        x, y = i % W, i // W
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H:
                j = yy * W + xx
                if not known[j]:
                    known[j] = True
                    rgb[j] = rgb[i]
                    nxt.append(j)
    frontier = nxt
flat = Image.new('RGB', (W, H))
flat.putdata(rgb)
q = flat.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
pal = (q.getpalette() or [])[:256 * 3]
pal += [0] * (256 * 3 - len(pal))
raw = bytes(pal) + bytes(q.getdata()) + bytes(alpha)
c = zlib.compressobj(9, zlib.DEFLATED, -15)
comp = c.compress(raw) + c.flush()
b64 = base64.b64encode(comp).decode()
chunks = [b64[i:i + 100] for i in range(0, len(b64), 100)]
lines = [
    "-- R153: the owner's BONUS ROLL pack picture (a glossy green chip bag with a big yellow \"?\"), embedded as data: nothing is uploaded. Made by",
    "-- docs/proposals/R153/tools/make_pack.py from the owner's 1254 x 1254 picture: scaled down in premultiplied space (clean edges), transparent pixels carry the",
    "-- nearest edge colour (no dark fringe when it is scaled on screen), then a 256-colour palette + an alpha plane, raw deflate, base64. EmbeddedImage153 decodes it",
    "-- (256 x 3 palette bytes, W x H palette indices, W x H alpha bytes = Bytes) and draws it with an EditableImage. Check = the Adler-32 of the decoded bytes.",
    "return {Key='BonusPack153',Width=%d,Height=%d,Colors=256,Bytes=%d,Check=%d,Data={" % (W, H, len(raw), zlib.adler32(raw) & 0xffffffff),
]
lines += [" '%s'%s" % (ch, ',' if i < len(chunks) - 1 else '') for i, ch in enumerate(chunks)]
lines.append('}}')
text = '\n'.join(lines) + '\n'
open(out, 'w').write(text)
print('size', W, 'raw', len(raw), 'deflated', len(comp), 'base64', len(b64), 'file', len(text))
if preview:
    rec = Image.new('RGBA', (W, H))
    p2 = q.convert('RGB')
    rec.putdata([p2.getpixel((i % W, i // W)) + (alpha[i],) for i in range(W * H)])
    rec.save(preview)
