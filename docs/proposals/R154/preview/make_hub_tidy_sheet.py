"""R154 hub tidy: put the before / after renders on one sheet (docs/proposals/R154/hub_tidy.png).
Usage: python3 make_hub_tidy_sheet.py <render dir> <views.json> <out.png> <scenes dir> <before ref>
<render dir> holds {before,after}_{clear,cloudy}_<view>.png from render_cloudy.mjs; <scenes dir> holds the four scene dumps ("SCENE" lines of cloudy_scene.luau), which
carry every part (the counts below are read from them) and the lights (the lamp numbers). The pictures are an approximate three.js render."""
import collections
import json
import sys
from PIL import Image, ImageDraw, ImageFont

src, views_file, out, scenes, ref = sys.argv[1:6]
views = {v['name']: v for v in json.load(open(views_file))['views']}
rows = [('clear', 'aerial'), ('clear', 'plaza'), ('clear', 'corner'), ('cloudy', 'plaza'), ('cloudy', 'street')]
scene = {}
for side in ('before', 'after'):
    for sky in ('clear', 'cloudy'):
        scene[side, sky] = json.load(open('%s/%s_%s.json' % (scenes, side, sky)))
W, H = 760, 428
pad, head, cap = 18, 74, 44


def font(size, bold=False):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/' + ('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'), size)
    except OSError:
        return ImageFont.load_default()


F_TITLE, F_HEAD, F_CAP, F_SMALL = font(24, True), font(22, True), font(16), font(14)


def names(side):
    c = collections.Counter()
    for p in scene[side, 'clear']['parts']:
        if 'HubLife151' in p.get('path', ''):
            c[p['name']] += 1
    return c


nb, na = names('before'), names('after')
GROUPS = [
    ('Flower beds (rim, soil, flowers, stems)', ['Bed rim', 'Bed soil', 'Flower', 'Flower stem']),
    ('Benches (seat, back, legs, knobs, slab, blocks)', ['Bench seat', 'Bench back', 'Bench leg', 'Bench knob', 'Bench slab', 'Bench block']),
    ('Lamps (base, collar, pole, arm, lantern, cap, bollard)', ['Lamp base', 'Lamp collar', 'Lamp pole', 'Lamp arm', 'Lamp lantern', 'Lamp cap', 'Bollard']),
    ('Pebbles', ['Pebble']),
    ('Bunting (lines and pennants)', ['Bunting line', 'Pennant']),
    ('Bushes', ['Bush']),
    ('Trees (crowns, trunks, palms, pines, ember, poplar ...)', ['Tree crown', 'Tree crown top', 'Tree trunk', 'Root flare', 'Poplar crown', 'Palm leaf', 'Palm trunk', 'Ember crown', 'Blossom crown', 'Pine tier', 'Pine trunk', 'Pine snow', 'Cactus', 'Cactus arm', 'Charred branch', 'Leaf tuft', 'Basalt rock']),
    ('Topiary pots, grass patches, verges, wall lanterns, butterflies', ['Topiary pot', 'Topiary pot rim', 'Topiary cone', 'Topiary stem', 'Topiary ball', 'Grass patch', 'Verge rim', 'Verge soil', 'Verge flower', 'Snow rim', 'Wall lantern', 'Wall lantern bracket', 'Wall lantern cap', 'Butterfly wing']),
]
tb, ta = sum(nb.values()), sum(na.values())


def lamp_lights(side):
    return [l for l in scene[side, 'cloudy'].get('lights', []) if not l.get('off') and (abs(l['p'][1] - 17) < .1 or abs(l['p'][1] - 15) < .1) and -420 < l['p'][2] < -150]  # (the lamp heads: posts at 17, doubles at 15)


lb, la = lamp_lights('before'), lamp_lights('after')
sheet_w = pad * 3 + W * 2
sheet_h = head + 40 + len(rows) * (H + cap + pad) + 60 + 22 * (len(GROUPS) + 5) + 170
sheet = Image.new('RGB', (sheet_w, sheet_h), (28, 32, 40))
d = ImageDraw.Draw(sheet)
d.text((pad, 14), 'R154 hub tidy: fewer lamps, no flower beds or benches, brighter warmer lamps under Cloudy', font=F_TITLE, fill=(240, 244, 250))
d.text((pad, 46), 'Left: the hub as the R153 release has it (%s). Right: this checkout. The real builders and client; the pictures are an approximate three.js render.' % ref, font=F_CAP, fill=(170, 180, 196))
y = head
for i, (label, colr) in enumerate((('BEFORE (R153 release)', (255, 190, 120)), ('AFTER (R154 tidy)', (150, 235, 160)))):
    d.text((pad + i * (W + pad), y), label, font=F_HEAD, fill=colr)
y += 40
for sky, name in rows:
    for i, side in enumerate(('before', 'after')):
        try:
            img = Image.open('%s/%s_%s_%s.png' % (src, side, sky, name)).convert('RGB').resize((W, H), Image.LANCZOS)
        except OSError:
            img = Image.new('RGB', (W, H), (60, 60, 60))
        x = pad + i * (W + pad)
        sheet.paste(img, (x, y))
        title = views[name]['title'] + ('  [Cloudy sky]' if sky == 'cloudy' else '')
        d.text((x, y + H + 6), title if i == 0 else '', font=F_SMALL, fill=(220, 226, 236))
        if sky == 'cloudy':
            ll = lb if side == 'before' else la
            if ll:
                b, r = ll[0]['brightness'], ll[0]['range']
                col = ll[0]['color']
                line = '%d lamps with a real light on: Brightness %.2f, Range %.1f, colour (%d,%d,%d)' % (len(ll), b, r, col[0], col[1], col[2])
            else:
                line = ''
            d.text((x, y + H + 24), line, font=F_SMALL, fill=(255, 224, 150))
    y += H + cap + pad
d.text((pad, y + 2), 'Parts of the client square (HubLife151), counted from the four dumps (desktop tier, every detail level shown)', font=F_CAP, fill=(240, 244, 250))
y += 30
for label, keys in GROUPS:
    b, a = sum(nb[k] for k in keys), sum(na[k] for k in keys)
    d.text((pad, y), label, font=F_SMALL, fill=(170, 180, 196))
    d.text((pad + 520, y), '%4d  ->  %4d' % (b, a), font=F_SMALL, fill=(255, 224, 150) if b != a else (150, 160, 175))
    y += 22
d.text((pad, y + 4), 'All parts of the square', font=F_SMALL, fill=(240, 244, 250))
d.text((pad + 520, y + 4), '%4d  ->  %4d  (%d fewer, %.0f%%)' % (tb, ta, tb - ta, 100.0 * (tb - ta) / max(1, tb)), font=F_SMALL, fill=(150, 235, 160))
y += 36
tot_b = len(scene['before', 'clear']['parts'])
tot_a = len(scene['after', 'clear']['parts'])
d.text((pad, y), 'Whole map, visible parts (incl. the trampolines now filling their circles): %d -> %d' % (tot_b, tot_a), font=F_SMALL, fill=(170, 180, 196))
y += 26
if lb and la:
    fb = (lb[0]['brightness'], lb[0]['range'])
    d.text((pad, y), 'Lamp light under full Cloudy: Brightness %.2f -> %.2f, Range %.1f -> %.1f (base %.1f / %.0f -> %.1f / %.0f, x1.5 and x1.3 at full glow, colour toward amber (255,150,60))' % (fb[0], la[0]['brightness'], fb[1], la[0]['range'], 1.4, 22, 1.8, 28), font=F_SMALL, fill=(255, 224, 150))
    y += 22
d.text((pad, y), 'Real lights: %d before, %d after (the same 8; the tier caps 8 / 4 / 0 are unchanged). Lamps: 26 -> 12 posts (30 -> 16 heads).' % (len(lb), len(la)), font=F_SMALL, fill=(170, 180, 196))
sheet = sheet.crop((0, 0, sheet_w, y + 40))
sheet.save(out)
print('wrote', out, sheet.size)
