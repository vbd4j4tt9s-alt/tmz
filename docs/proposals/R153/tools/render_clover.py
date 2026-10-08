"""R153: renders the shop's 4 Leaf Clover card from the frame dumps of test_clover_shop.luau (DUMP lines) with the REAL clover picture: the test prints the RGBA the game's own decoder
(CloverIcon153.Decode: base64 -> inflate -> palette) made (CLOVERRGBA, hex) and marks the label that shows it ("im":"clover"); this draws it into that label's rectangle (fit, premultiplied-correct
resize). Everything else is render_shop.py of the R120 shop (rough PIL render: frames, gradients, corners, strokes, text in Fredoka One).
Usage: python3 render_clover.py shop.log OUTDIR [font.ttf]
Writes OUTDIR/<screen>_<tag>.png for every dump, and OUTDIR/clover.png: the PASSES section on a PC and on a phone, the card with its Robux button and without (id 0)."""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, '../../shop_R120/tests')))
import render_shop as RS  # noqa: E402

log, outdir = sys.argv[1], sys.argv[2]
font = sys.argv[3] if len(sys.argv) > 3 else os.path.normpath(os.path.join(HERE, '../../shop_R120/tests/FredokaOne.ttf'))
RS.FONT = font
os.makedirs(outdir, exist_ok=True)
dumps, rgba = [], None
for line in open(log, encoding='utf-8'):
    if line.startswith('DUMP '):
        dumps.append(json.loads(line[5:]))
    elif line.startswith('CLOVERRGBA ') and rgba is None:
        data = bytes.fromhex(line.split(' ', 1)[1].strip())
        assert len(data) == 128 * 128 * 4, len(data)
        rgba = Image.frombytes('RGBA', (128, 128), data)
assert rgba is not None and dumps
orig = RS.node_layer


def layer(n):
    if n.get('im') == 'clover':
        w, h = int(round(n['w'] * RS.SCALE)), int(round(n['h'] * RS.SCALE))
        side = min(w, h)
        pm = rgba.convert('RGBa').resize((side, side), Image.LANCZOS).convert('RGBA')
        out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        out.alpha_composite(pm, ((w - side) // 2, (h - side) // 2))
        return out, 0
    return orig(n)


RS.node_layer = layer
files = {}
for d in dumps:
    slug = d['screen'].lower().replace(' ', '_') + '_' + d['tag']
    path = os.path.join(outdir, slug + '.png')
    RS.render(d, path)
    files[(d['screen'], d['tag'])] = (path, d)
    print('wrote', path)


def panel_crop(key, pad=26):
    path, d = files[key]
    im = Image.open(path).convert('RGB')
    s = RS.SCALE
    L, T = d['inset'][0], d['inset'][1]
    shop = [n for n in d['nodes'] if n['n'] == 'PremiumShop']
    n = shop[0]
    box = (int((n['x'] + L - pad) * s), int((n['y'] + T - pad) * s), int((n['x'] + L + n['w'] + pad) * s), int((n['y'] + T + n['h'] + pad) * s))
    return im.crop(box)


# the sheet: PC (the passes section, with the Robux button) | phone (landscape) | the id-0 card (no Robux button) | owned
tiles = [('PC 1280x720', 'clover_passes', 'PC: the PASSES section'), ('Phone 844x390', 'clover_phone', 'Phone'), ('PC 1280x720', 'clover_soon', 'Robux id off: Gem button only'),
         ('PC 1280x720', 'clover_owned_gems', 'Owned (Gems, id off)')]
crops = [(panel_crop((s, t)), cap) for s, t, cap in tiles if (s, t) in files]
H = 560
rows = []
for im, cap in crops:
    r = im.resize((int(im.width * H / im.height), H), Image.LANCZOS)
    rows.append((r, cap))
gap = 24
W1 = rows[0][0].width + rows[1][0].width + gap
W2 = rows[2][0].width + rows[3][0].width + gap
sheet = Image.new('RGB', (max(W1, W2) + 2 * gap, 2 * (H + 44) + gap), (24, 26, 34))
d = ImageDraw.Draw(sheet)
f = RS.font(26)
x, y = gap, 8
for i, (r, cap) in enumerate(rows):
    if i == 2:
        x, y = gap, 8 + H + 44 + gap // 2
    d.text((x, y), cap, font=f, fill=(255, 255, 255))
    sheet.paste(r, (x, y + 36))
    x += r.width + gap
sheet.save(os.path.join(outdir, 'clover.png'), optimize=True)
print('wrote', os.path.join(outdir, 'clover.png'), sheet.size)
