"""R158e tutorial storyboard: turns the SCENE / WORLD lines of scenes158e.luau (SCRATCH/pc, SCRATCH/phone) into one picture. The GUI layers are drawn by Chromium (R150
render_gui.mjs: the real tutorial GUI as the script built it); the world (stand-in scenery + the tutorial's own 3D pieces: the red arrow, the chevrons, the ring, the beam) is drawn
here from the projected, shaded faces. Each moment: sky, world faces far to near, the stand-in HUD, the world billboards, the tutorial layers.
Usage: python3 make_sheet158e.py SCRATCH OUT.png (run_preview158e.sh calls it)."""
import json, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.join(HERE, '..', '..', 'R150', 'preview', 'render_gui.mjs')
FRED = os.path.join(HERE, '..', '..', 'shop_R120', 'tests', 'FredokaOne.ttf')
SIZES = {'pc': (1280, 720), 'phone': (844, 390)}
CAPTIONS = {
    '01_spawn': '1  you spawn: the big red arrow points at the pack',
    '02_track': '2  the TRACK teleport button (arrow, ring, pressing hand)',
    '03_steal': '3  steal: the arrow over the pack + your key (hold E)',
    '04_carry': '3  carrying it: the arrow points home',
    '05_open': '4  open it: the clicking mouse + pips',
    '06_base': '5  the BASE teleport button',
    '07_plant': '6  plant: the arrow on your dirt + the pressing hand',
    '08_grow': '7  the first fruit: a 10-second ring timer',
    '09_harvest': '8  harvest: the arrow on the ripe fruit + E',
    '10_market': '9  sell: the arrow leads to the market (E there)',
    '11_sell': '9  the market window: Sell crops, then Sell all',
    '12_treadmill': '10  treadmill = faster; every 6:00 a bonus roll (more packs)',
    '13_finish': 'done: trophy + the free pack, confetti',
}

scenes, layers, worlds = [], {}, {}
for view in ('pc', 'phone'):
    for line in open(os.path.join(S, view, 'scenes.log'), encoding='utf-8'):
        if line.startswith('WORLD '):
            _, moment, payload = line.rstrip('\n').split(' ', 2)
            worlds[(view, moment)] = json.loads(payload)
            continue
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


def world(view, moment):
    w, h = SIZES[view]
    im = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(im)
    for yy in range(h):  # sky (the ground is drawn as faces)
        t = yy / h
        d.line([(0, yy), (w, yy)], fill=(int(124 + 90 * t), int(196 + 44 * t), 255, 255))
    faces = worlds.get((view, moment), [])
    faces.sort(key=lambda f: (f['l'], -f['z']))
    glow = Image.new('RGBA', (w, h))
    gd = ImageDraw.Draw(glow)
    for f in faces:
        pts = [tuple(p) for p in f['p']]
        if len(pts) < 3:
            continue
        a = max(0.0, min(1.0, f['a']))
        layer = Image.new('RGBA', (w, h))
        ImageDraw.Draw(layer).polygon(pts, fill=tuple(f['c']) + (int(255 * a),))
        im.alpha_composite(layer)
        if f['g'] and a > .3:
            gd.polygon(pts, fill=tuple(f['c']) + (150,))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
    return im


ORDER = {'hud': 0, 'goal': 1, 'tapspot': 1, 'growtimer': 1, 'tut': 2, 'tap': 3}
shots = {}
for (view, moment), ls in layers.items():
    im = world(view, moment)
    for layer, x, y, name in sorted(ls, key=lambda l: ORDER.get(l[0], 1)):
        part = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGBA')
        im.alpha_composite(part, (max(0, x), max(0, y)))
    shots[(view, moment)] = im.convert('RGB')

pc = sorted(m for v, m in shots if v == 'pc')
ph = sorted(m for v, m in shots if v == 'phone')
cells = [('pc', m) for m in pc] + [('phone', m) for m in ph]
COLS, PAD, LAB = 4, 18, 34
CW = 520
def cell_size(view):
    w, h = SIZES[view]
    return CW, int(h * CW / w)
rows = [cells[i:i + COLS] for i in range(0, len(cells), COLS)]
row_h = [max(cell_size(v)[1] for v, _ in r) + LAB + PAD for r in rows]
W = PAD + COLS * (CW + PAD)
H = 96 + sum(row_h)
sheet = Image.new('RGB', (W, H), (13, 18, 32))
d = ImageDraw.Draw(sheet)
try:
    big, small = ImageFont.truetype(FRED, 30), ImageFont.truetype(FRED, 17)
except Exception:
    big = small = ImageFont.load_default()
d.text((PAD, 16), 'R158e tutorial: the real script on the mock, one frame per step (PC 1280x720, last row: phone 844x390)', font=big, fill=(255, 224, 71))
d.text((PAD, 56), 'Approximate: block scenery and a stand-in HUD (BASE / TRACK / MENU / BONUS ROLL / the market window are the game\'s own buttons); the tutorial itself shows no words.', font=small, fill=(150, 160, 185))
y = 96
for r, rh in zip(rows, row_h):
    x = PAD
    for view, m in r:
        cw, ch = cell_size(view)
        cap = CAPTIONS.get(m, m)
        d.text((x, y + 8), ('phone: ' if view == 'phone' else '') + cap, font=small, fill=(232, 237, 246))
        sheet.paste(shots[(view, m)].resize((cw, ch), Image.LANCZOS), (x, y + LAB))
        x += CW + PAD
    y += rh
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
