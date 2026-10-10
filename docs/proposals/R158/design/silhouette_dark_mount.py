"""R158: the owner's dark mountain before / after the cut (1,532 blocks -> 280): front, side and top silhouettes, differences in red.  python3 silhouette_dark_mount.py [out.png]
(the same cut as make_models158.py: no "Steps", then the biggest blocks by volume)."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
KEEP = 280
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'dark_mount_cut.png')
d = json.load(open(os.path.join(HERE, 'assets', 'dark_mount_parts.json')))
parts = [p for p in d if p['ClassName'] == 'Part']


def corners(p):
    r, s, pos = p['CFrame']['rot'], p['size'], p['CFrame']['pos']
    out = []
    for a in (-.5, .5):
        for b in (-.5, .5):
            for c in (-.5, .5):
                v = (a * s[0], b * s[1], c * s[2])
                out.append([pos[i] + r[3 * i] * v[0] + r[3 * i + 1] * v[1] + r[3 * i + 2] * v[2] for i in range(3)])
    return out


allc = [corners(p) for p in parts]
lo = [min(c[i] for cs in allc for c in cs) for i in range(3)]
hi = [max(c[i] for cs in allc for c in cs) for i in range(3)]
RES = 0.5
W = [int((hi[i] - lo[i]) / RES) + 2 for i in range(3)]


def raster(sel, u, v):
    img = np.zeros((W[v], W[u]), bool)
    for i in sel:
        pts = np.array([[(c[u] - lo[u]) / RES, (c[v] - lo[v]) / RES] for c in allc[i]])
        pts = pts[np.lexsort((pts[:, 1], pts[:, 0]))]
        def cr(o, a, b): return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
        lower, upper = [], []
        for q in pts:
            while len(lower) >= 2 and cr(lower[-2], lower[-1], q) <= 0: lower.pop()
            lower.append(q)
        for q in pts[::-1]:
            while len(upper) >= 2 and cr(upper[-2], upper[-1], q) <= 0: upper.pop()
            upper.append(q)
        h = np.array(lower[:-1] + upper[:-1])
        x0, x1, y0, y1 = int(h[:, 0].min()), int(h[:, 0].max()) + 1, int(h[:, 1].min()), int(h[:, 1].max()) + 1
        xs, ys = np.meshgrid(np.arange(x0, x1) + .5, np.arange(y0, y1) + .5)
        ins = np.ones(xs.shape, bool)
        for k in range(len(h)):
            a, b = h[k], h[(k + 1) % len(h)]
            ins &= ((b[0] - a[0]) * (ys - a[1]) - (b[1] - a[1]) * (xs - a[0])) >= -1e-9
        sub = img[y0:y1, x0:x1]
        img[y0:y1, x0:x1] = sub | ins[:sub.shape[0], :sub.shape[1]]
    return img


def vol(p): return p['size'][0] * p['size'][1] * p['size'][2]


full = list(range(len(parts)))
base = [i for i in full if parts[i]['Name'] != 'Steps']
kept = sorted(base, key=lambda i: -vol(parts[i]))[:KEEP]
views = [('front (x across, y up)', 0, 1), ('side (z across, y up)', 2, 1), ('top (x across, z deep)', 0, 2)]
F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
font = lambda n, b=False: ImageFont.truetype(F % ('-Bold' if b else ''), n)
cell = 360
sheet = Image.new('RGB', (3 * cell + 4 * 14, 130 + 2 * (cell + 66)), (24, 26, 31))
dr = ImageDraw.Draw(sheet)
dr.text((14, 12), 'The dark mountain: before and after the cut', font=font(28, True), fill=(250, 226, 150))
dr.text((14, 52), 'Before: 1,532 blocks (172 of them "Steps"), 19 spot lights, 32 cylinder meshes, 3,266 welds.  After: %d blocks, nothing else.' % len(kept), font=font(16), fill=(176, 182, 194))
dr.text((14, 76), 'Grey = both have it.  Red = in the full model only (what the cut loses).  The silhouette overlap is printed on each picture.', font=font(16), fill=(176, 182, 194))
for row, (label, sel) in enumerate((('BEFORE: all %d blocks' % len(parts), full), ('AFTER: %d blocks (the biggest by volume)' % len(kept), kept))):
    y0 = 120 + row * (cell + 66)
    dr.text((14, y0 - 6), label, font=font(20, True), fill=(238, 240, 245))
    for col, (vl, u, v) in enumerate(views):
        a = raster(full, u, v)
        b = raster(sel, u, v)
        iou = float((a & b).sum() / (a | b).sum())
        im = np.zeros(a.shape + (3,), np.uint8)
        im[:] = (40, 44, 52)
        im[b] = (170, 176, 188)
        im[a & ~b] = (220, 70, 70)
        im = im[::-1] if v == 1 else im  # y up
        pil = Image.fromarray(im).resize((cell, int(cell * im.shape[0] / im.shape[1])) if im.shape[1] >= im.shape[0] else (int(cell * im.shape[1] / im.shape[0]), cell), Image.NEAREST)
        x = 14 + col * (cell + 14)
        sheet.paste(pil, (x, y0 + 52))
        dr.text((x, y0 + 28), '%s   overlap %.1f %%' % (vl, 100 * iou), font=font(14), fill=(176, 182, 194))
sheet.save(OUT, optimize=True)
print('wrote', OUT)
