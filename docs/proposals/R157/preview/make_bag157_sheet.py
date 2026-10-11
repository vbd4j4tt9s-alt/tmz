"""R157: the SCENE lines of bag_scenes156.luau, run on the real src (pc + phone logs) -> PNGs with Chromium (R155's render_gui155.mjs) -> one sheet:
the PC on the left, the landscape phone on the right; rows: at rest, an item dragged over the Bag, the Discard bin targeted, the discard popup; the colour table under them.
Usage: python3 make_bag157_sheet.py SCRATCH OUT.png   (run_bag157_png.sh calls it)"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
RENDERER = os.path.join(REPO, 'docs', 'proposals', 'R155', 'preview', 'render_gui155.mjs')
# a neutral stand-in for the 3D world behind the GUI (the sheet and the empty hotbar slots are a little see-through)
SKY = 'linear-gradient(180deg,#a9c9e8 0%,#c3d4e6 52%,#8e9eb2 100%)'
VIEWS = (('pc', 'PC  1280 x 720  (mouse)'), ('phone', 'LANDSCAPE PHONE  844 x 390  (touch)'))
ROWS = (
    ('rest', 'At rest'),
    ('drag', 'An item dragged over the Bag'),
    ('trash', 'The same item over Discard'),
    ('popup', 'The discard popup'),
)
CAPTIONS = {
    'rest': 'The Bag at rest: a navy sheet, cards and tabs in the hotbar slot colour, a blue rim, no hint line; the bottom bar is the count next to Discard (red).',
    'drag': 'Dragging a hotbar item over the Bag: a thin light rim and a faint brighten (before: the sheet flooded lime); the other slots get thin light outlines.',
    'trash': 'The Discard bin keeps its red when it is the target (the item under the pointer covers part of it).',
    'popup': 'The discard popup: navy panel, blue rim, navy amount buttons and Keep it; the Discard button stays red.',
}
LEGEND = (  # old -> new (the table in bag157.md has the code names)
    ('Sheet, rarity dropdown panel, discard popup', '#142E23', '#1F2246'),
    ('Cards, tabs, rarity button, popup picture + amount buttons', '#254C39', '#30366A'),
    ('Selected tab, Hold button, drag ghost', '#41784C', '#4A5599'),
    ('Search box, count, popup count box', '#0E2119', '#192041'),
    ('Header band', '#41634D', '#424A80'),
    ('Sheet rim, header rule, popup rim', '#93FF45', '#6A90E1'),
    ('Drop highlight, slot outlines, picked ring, "Moving" text', '#93FF45', '#EAF0FF'),
    ('Keep it button', '#466E56', '#424C8A'),
)


def font(px, weight='700'):
    try:
        return ImageFont.truetype(os.path.join(FONTS, '..', '..', 'montserrat', 'files', 'montserrat-latin-%s-normal.woff' % weight), px)
    except Exception:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


scenes = {}  # (view, row) -> png path
sc = []
for view, _ in VIEWS:
    for line in open(os.path.join(S, 'real', view, 'scenes.log'), encoding='utf-8'):
        if line.startswith('SCENE '):
            parts = line.rstrip('\n').split(' ', 7)
            name, x, y, cw, ch, scale = parts[1:7]
            sc.append({'name': name, 'json': parts[7], 'scale': float(scale), 'bg': SKY, 'crop': [int(x), int(y), int(cw), int(ch)]})
out = os.path.join(S, 'png_real')
os.makedirs(out, exist_ok=True)
with open(os.path.join(S, 'scenes_real.json'), 'w', encoding='utf-8') as f:
    json.dump(sc, f)
subprocess.run(['node', RENDERER, os.path.join(S, 'scenes_real.json'), out, FONTS if os.path.isdir(FONTS) else ''], check=True)
for s in sc:
    v, r = s['name'].split('_', 1)
    scenes[(v, r)] = os.path.join(out, s['name'] + '.png')

CELL_W, PAD = 700, 22
title_h, head_h, cap_h = 100, 40, 44
tiles = {k: Image.open(p).convert('RGB') for k, p in scenes.items()}
tiles = {k: im.resize((CELL_W, round(im.height * CELL_W / im.width)), Image.LANCZOS) for k, im in tiles.items()}
rows = [(r, label) for r, label in ROWS if all((v, r) in tiles for v, _ in VIEWS)]
row_h = {r: max(tiles[(v, r)].height for v, _ in VIEWS) for r, _ in rows}
width = PAD + 2 * (CELL_W + PAD)
legend_h = 46 + 30 * ((len(LEGEND) + 1) // 2) + 40
height = title_h + head_h + sum(row_h[r] + cap_h + PAD for r, _ in rows) + legend_h
sheet = Image.new('RGB', (width, height), (22, 24, 38))
d = ImageDraw.Draw(sheet)
d.text((PAD, 16), 'R157: the Bag without green, and without the hint line', font=font(26, '900'), fill=(255, 255, 255))
d.text((PAD, 52), 'Owner: "dont make this green and remove that text saying click to hold and so on". Rendered from the real src of this checkout.',
       font=font(14, '500'), fill=(205, 214, 240))
d.text((PAD, 72), 'APPROXIMATE: the real Bag GUI tree drawn by a mock + Chromium (stand-in emoji for the 3D item pictures, Montserrat for Gotham), not a Studio screenshot.',
       font=font(14, '500'), fill=(255, 214, 140))


def wrap(draw, text, fnt, w):
    lines, cur = [], ''
    for word in text.split(' '):
        t = (cur + ' ' + word).strip()
        if draw.textlength(t, font=fnt) <= w:
            cur = t
        else:
            lines.append(cur)
            cur = word
    lines.append(cur)
    return lines


y = title_h
for k, (view, label) in enumerate(VIEWS):
    x = PAD + k * (CELL_W + PAD)
    d.rectangle([x, y, x + CELL_W, y + head_h - 8], fill=(40, 44, 70))
    d.text((x + 12, y + 5), label, font=font(17, '900'), fill=(255, 255, 255))
y += head_h
for r, label in rows:
    for k, (view, _) in enumerate(VIEWS):
        x = PAD + k * (CELL_W + PAD)
        im = tiles[(view, r)]
        sheet.paste(im, (x, y))
        d.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=(96, 104, 140), width=1)
        f = font(13, '900')
        w = int(d.textlength(label, font=f)) + 18
        d.rounded_rectangle([x + 8, y + 8, x + 8 + w, y + 30], radius=11, fill=(74, 85, 153))
        d.text((x + 17, y + 11), label, font=f, fill=(255, 255, 255))
    for j, ln in enumerate(wrap(d, CAPTIONS[r], font(14), width - 2 * PAD)[:2]):
        d.text((PAD, y + row_h[r] + 5 + j * 19), ln, font=font(14), fill=(235, 238, 250))
    y += row_h[r] + cap_h + PAD
d.rectangle([PAD, y + 4, width - PAD, y + 38], fill=(40, 44, 70))
d.text((PAD + 12, y + 10), 'Every colour changed (old -> new)', font=font(18, '900'), fill=(255, 255, 255))
y += 52
colw = (width - 2 * PAD) // 2
for i, (what, old, new) in enumerate(LEGEND):
    cx, cy = PAD + (i % 2) * colw, y + (i // 2) * 30
    for k, hexv in enumerate((old, new)):
        rgb = tuple(int(hexv[j:j + 2], 16) for j in (1, 3, 5))
        d.rounded_rectangle([cx + k * 120, cy, cx + k * 120 + 26, cy + 22], radius=5, fill=rgb, outline=(150, 156, 180))
        d.text((cx + k * 120 + 32, cy + 3), hexv, font=font(13), fill=(235, 238, 250))
    d.text((cx + 236, cy + 3), what, font=font(13, '500'), fill=(205, 214, 240))
y += 30 * ((len(LEGEND) + 1) // 2) + 8
d.text((PAD, y), 'Unchanged: the red Discard bin and buttons (#7A2C34, #C44048, target #FF6060), white selection outlines, amber / red count, rarity colours, every other menu\'s green trim.',
       font=font(13, '500'), fill=(205, 214, 240))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size, len(tiles), 'scenes')
