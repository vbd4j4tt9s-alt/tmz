"""R152 tutorial preview: turns the SCENE lines of tutorial_real.luau (scratch/pc, scratch/phone) into PNGs with Chromium (R150
render_gui.mjs), stacks each moment's layers (backdrop, stand-in HUD, world billboards, the tutorial) and lays the moments out as one
sheet, phone landscape left, PC right. Usage: python3 make_tutorial_sheet.py SCRATCH OUT.png (run_tutorial_preview.sh calls it)."""
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.join(HERE, '..', '..', 'R150', 'preview', 'render_gui.mjs')
FRED = os.path.join(HERE, '..', '..', 'shop_R120', 'tests', 'FredokaOne.ttf')
SIZES = {'pc': (1280, 720), 'phone': (844, 390)}
WORDS = {'1_offtrack': 'off the track: TRACK', '2_nice': 'did it: the pop', '3_grab': '1 grab a pack', '4_home': '2 run home',
         '5_open': '3 open it (pick)', '6_tap': '3 keep tapping', '7_plant': '4 plant it', '8_gohome': 'on the track: BASE',
         '9_faster': '5 get faster', '10_finish': 'done'}

scenes, layers = [], {}
for view in ('phone', 'pc'):
    for line in open(os.path.join(S, view, 'scenes.log'), encoding='utf-8'):
        if not line.startswith('SCENE '):
            continue
        _, moment, layer, x, y, payload = line.rstrip('\n').split(' ', 5)
        name = '%s_%s_%s' % (view, moment, layer)
        scenes.append({'name': name, 'json': payload, 'scale': 1})
        layers.setdefault((view, moment), []).append((layer, int(x), int(y), name))
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
subprocess.run(['node', RENDER, os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), os.path.join(S, 'fonts')], check=True)


def backdrop(w, h):
    im = Image.new('RGB', (w, h));d = ImageDraw.Draw(im);hz = int(h * .42)
    for yy in range(h):
        if yy < hz:
            t = yy / hz;c = (int(124 + (216 - 124) * t), int(199 + (240 - 199) * t), 255)
        else:
            t = (yy - hz) / (h - hz);c = (int(120 - 50 * t), int(194 - 60 * t), int(90 - 30 * t))
        d.line([(0, yy), (w, yy)], fill=c)
    return im


ORDER = {'hud': 0, 'goal': 1, 'spot': 1, 'tut': 2, 'tap': 3}
shots = {}
for (view, moment), ls in layers.items():
    w, h = SIZES[view];im = backdrop(w, h).convert('RGBA')
    for layer, x, y, name in sorted(ls, key=lambda l: ORDER[l[0]]):
        part = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGBA')
        im.alpha_composite(part, (max(0, x), max(0, y)))
    shots[(view, moment)] = im.convert('RGB')
moments = sorted({m for _, m in shots}, key=lambda m: int(m.split('_')[0]))
K = {'phone': .78, 'pc': .56};pad, lab = 20, 34
cols = [('phone', int(844 * .78), int(390 * .78)), ('pc', int(1280 * .56), int(720 * .56))]
rowh = max(c[2] for c in cols) + lab + pad
W = 260 + sum(c[1] for c in cols) + pad * 3;H = 90 + rowh * len(moments)
sheet = Image.new('RGB', (W, H), (13, 18, 32));d = ImageDraw.Draw(sheet)
try:
    big, small = ImageFont.truetype(FRED, 30), ImageFont.truetype(FRED, 20)
except Exception:
    big = small = ImageFont.load_default()
d.text((pad, 18), 'R152 tutorial: the real script on the mock (phone landscape | PC)', font=big, fill=(255, 224, 71))
y = 80
for m in moments:
    d.text((pad, y + lab), WORDS.get(m, m), font=small, fill=(232, 237, 246))
    x = 260
    for view, cw, ch in cols:
        d.text((x, y + 6), '%s %dx%d' % (view, *SIZES[view]), font=small, fill=(135, 147, 171))
        if (view, m) in shots:
            sheet.paste(shots[(view, m)].resize((cw, ch), Image.LANCZOS), (x, y + lab))
        x += cw + pad
    y += rowh
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
