"""Usage: python3 cut_seeds.py row.png OUTDIR id1 id2 ... - cuts a shootSeeds row (200 px per seed) into OUTDIR/<id>.png,
keys out the dark green background, trims, and also writes OUTDIR/<id>_dark.png (the Index's silhouette for unknown seeds)."""
import sys, os
from PIL import Image
src, out, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
os.makedirs(out, exist_ok=True)
row = Image.open(src).convert('RGBA'); bg = row.getpixel((3, 3))[:3]
for i, sid in enumerate(ids):
    cell = row.crop((i * 200, 0, (i + 1) * 200, min(row.height, 250)))
    px = cell.load()
    for y in range(cell.height):
        for x in range(cell.width):
            r, g, b, a = px[x, y]; d = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
            if d < 18: px[x, y] = (r, g, b, 0)
            elif d < 40: px[x, y] = (r, g, b, int(255 * (d - 18) / 22))
    box = cell.getbbox()
    if box: cell = cell.crop(box)
    cell.save(os.path.join(out, sid + '.png'))
    dark = Image.new('RGBA', cell.size, (9, 14, 29, 0)); dark.putalpha(cell.getchannel('A'))
    dark.save(os.path.join(out, sid + '_dark.png'))
print('cut', len(ids))
