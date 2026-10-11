"""R158 bunting: put the before / after renders on one sheet (docs/proposals/R158/bunting158.png).
Usage: python3 make_bunting_sheet158.py <render dir> <views.json> <out.png> <scenes dir> <before ref>
<render dir> holds {before,after}_<view>.png from render_cloudy.mjs; <scenes dir> holds before.json / after.json (the "SCENE" lines of cloudy_scene.luau), which carry every part:
the bunting's numbers below are read from them. The pictures are an approximate three.js render (no Roblox lighting)."""
import collections
import json
import math
import sys
from PIL import Image, ImageDraw, ImageFont

src, views_file, out, scenes, ref = sys.argv[1:6]
views = {v['name']: v for v in json.load(open(views_file))['views']}
rows = ['string', 'close', 'along', 'avenue']
scene = {side: json.load(open('%s/%s.json' % (scenes, side))) for side in ('before', 'after')}
W, H = 760, 428
pad, head, cap = 18, 78, 40


def font(size, bold=False):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/' + ('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'), size)
    except OSError:
        return ImageFont.load_default()


F_TITLE, F_HEAD, F_CAP, F_SMALL = font(24, True), font(22, True), font(16), font(14)


def bunting(side):
    return [p for p in scene[side]['parts'] if p['name'] in ('Bunting line', 'Pennant')]


def strings(side):
    """Group the rods into strings (rods whose ends meet) and report, per string, the worst distance of a pennant's top edge from the string."""
    rods = [p for p in bunting(side) if p['name'] == 'Bunting line']
    pen = [p for p in bunting(side) if p['name'] == 'Pennant']

    def ends(p):
        r = p['r']
        ax = (r[0][0], r[1][0], r[2][0])  # a rod's (cylinder's) axis is its local X
        h = p['size'][0] / 2
        c = p['p']
        return [c[i] - ax[i] * h for i in range(3)], [c[i] + ax[i] * h for i in range(3)]

    def dist_to_rod(pt, p):
        a0, a1 = ends(p)
        d = [a1[i] - a0[i] for i in range(3)]
        L2 = sum(x * x for x in d)
        t = max(0, min(1, sum((pt[i] - a0[i]) * d[i] for i in range(3)) / L2))
        return math.dist(pt, [a0[i] + d[i] * t for i in range(3)])

    worst = 0.0
    for q in pen:
        # the wedge's top edge (its slope face) mid point is the part's centre: the pennant is centred on its hypotenuse
        worst = max(worst, min(dist_to_rod(q['p'], r) for r in rods)) if rods else 0
    return len(rods), len(pen), worst


def fit(img):
    return img.convert('RGB').resize((W, H), Image.LANCZOS)


sheet_w = pad * 3 + W * 2
sheet_h = head + 40 + len(rows) * (H + cap + pad) + 120
sheet = Image.new('RGB', (sheet_w, sheet_h), (28, 32, 40))
d = ImageDraw.Draw(sheet)
d.text((pad, 14), 'R158 bunting: the flags hang from the string', font=F_TITLE, fill=(240, 244, 250))
d.text((pad, 46), 'Left: the hub before (%s): one straight string, pennants on a lower curve. Right: this checkout: the string follows the sag and the pennants hang from it.' % ref, font=F_CAP, fill=(170, 180, 196))
y = head
for i, (label, colr) in enumerate((('BEFORE', (255, 190, 120)), ('AFTER', (150, 235, 160)))):
    d.text((pad + i * (W + pad), y), label, font=F_HEAD, fill=colr)
y += 40
for name in rows:
    for i, side in enumerate(('before', 'after')):
        try:
            img = fit(Image.open('%s/%s_%s.png' % (src, side, name)))
        except OSError:
            img = Image.new('RGB', (W, H), (60, 60, 60))
        x = pad + i * (W + pad)
        sheet.paste(img, (x, y))
    d.text((pad, y + H + 8), views[name]['title'], font=F_SMALL, fill=(220, 226, 236))
    y += H + cap + pad
rb, pb, wb = strings('before')
ra, pa, wa = strings('after')
d.text((pad, y + 2), 'Bunting parts (5 strings): rods %d -> %d, pennants %d -> %d, total %d -> %d (all in the "detail" level; nothing per frame)' % (rb, ra, pb, pa, rb + pb, ra + pa), font=F_SMALL, fill=(255, 224, 150))
d.text((pad, y + 28), 'Worst distance from a pennant\'s top edge to the string: %.2f studs before, %.2f after' % (wb, wa), font=F_SMALL, fill=(255, 224, 150))
d.text((pad, y + 54), 'The pictures are an approximate three.js render of the real builders (HubLifeArt151 on the owner\'s place): no Roblox lighting, materials or colour grade.', font=F_SMALL, fill=(170, 180, 196))
sheet = sheet.crop((0, 0, sheet_w, y + 90))
sheet.save(out)
print('wrote', out, sheet.size)
