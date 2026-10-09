"""R156 preview: the SCENE / CAPTION lines of bag_scenes156.luau (current + option2, pc + phone logs) -> PNGs with Chromium (R155's render_gui155.mjs) -> one comparison sheet:
CURRENT on the left, OPTION 2 on the right, one row per scene, the PC rows first, then the landscape phone rows.
Usage: python3 make_bag_sheet156.py SCRATCH OUT.png   (run_bag_look.sh calls it)"""
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
# a neutral stand-in for the 3D world behind the GUI (the sheet and the empty hotbar slots are a little see-through; R155's green grass here would tint them green)
SKY = 'linear-gradient(180deg,#a9c9e8 0%,#c3d4e6 52%,#8e9eb2 100%)'
VARIANTS = (('current', 'CURRENT', (92, 98, 120)), ('option2', 'OPTION 2', (74, 85, 153)))
VIEWS = (('pc', 'PC  1280 x 720  (mouse)'), ('phone', 'LANDSCAPE PHONE  844 x 390  (touch)'))
ROWS = ('rest', 'drag', 'trash', 'search', 'popup', 'picked')


def font(px, weight='700'):
    try:
        return ImageFont.truetype(os.path.join(FONTS, '..', '..', 'montserrat', 'files', 'montserrat-latin-%s-normal.woff' % weight), px)
    except Exception:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


CAPTIONS = {
    ('pc', 'rest'): 'The Bag at rest. OPTION 2: navy sheet, cards and tabs in the hotbar slot colour, no green trim, the hint line is gone; the count stays left of Discard.',
    ('pc', 'drag'): 'A hotbar item (Watermelon Seed) dragged over the Bag. CURRENT: the whole sheet floods lime. OPTION 2: a thin light rim and a faint brighten; the other slots get thin light outlines.',
    ('pc', 'trash'): 'The same item over the Discard bin: the bin lights red in both (the item under the pointer covers part of it).',
    ('pc', 'search'): 'Search text ("seed") and the rarity dropdown open: the box, tabs and dropdown panel on the new sheet. (Uncommon stays green: it is a rarity colour.)',
    ('pc', 'popup'): 'The discard popup (a stack of 3, 2 picked): panel, picture box, amount buttons and Keep it recoloured; the red Discard button is unchanged.',
    ('phone', 'rest'): 'The Bag at rest. A sheet this short never showed the hint line (it shows on tall sheets only), so only the colours change.',
    ('phone', 'drag'): 'Hold a hotbar item and drag it over the Bag (the same thin light rim and faint brighten).',
    ('phone', 'trash'): 'The same item over the Discard bin: red in both.',
    ('phone', 'search'): 'Search text and the rarity dropdown open.',
    ('phone', 'popup'): 'The discard popup.',
    ('phone', 'picked'): 'An item picked (tap-tap): the "Moving ..." line and the Hold button were lime; every slot it can go to is outlined (lime / light).',
}
LEGEND = (  # what OPTION 2 changes (old -> new); the table in bag_look.md has the code names
    ('Sheet, rarity dropdown panel, discard popup', '#142E23', '#1F2246'),
    ('Cards, category tabs, rarity button, popup picture + amount buttons', '#254C39', '#30366A'),
    ('Selected tab, Hold button, drag ghost', '#41784C', '#4A5599'),
    ('Search box, count, popup count box', '#0E2119', '#192041'),
    ('Header band', '#41634D', '#424A80'),
    ('Sheet rim, header rule, popup rim', '#93FF45', '#6A90E1'),
    ('Drop highlight, slot outlines, picked ring, "Moving" text', '#93FF45', '#EAF0FF'),
    ('Keep it button', '#466E56', '#424C8A'),
)
scenes = {}      # (variant, view, row) -> png path
captions = {}    # (view, row) -> caption
for var, _, _ in VARIANTS:
    sc = []
    for view, _ in VIEWS:
        for line in open(os.path.join(S, var, view, 'scenes.log'), encoding='utf-8'):
            if line.startswith('SCENE '):
                parts = line.rstrip('\n').split(' ', 7)
                name, x, y, cw, ch, scale = parts[1:7]
                sc.append({'name': name, 'json': parts[7], 'scale': float(scale), 'bg': SKY, 'crop': [int(x), int(y), int(cw), int(ch)]})
            elif line.startswith('CAPTION ') and var == 'current':
                name, text = line.rstrip('\n').split(' ', 2)[1:]
                v, r = name.split('_', 1)
                captions[(v, r)] = text
    out = os.path.join(S, 'png_' + var)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(S, 'scenes_%s.json' % var), 'w', encoding='utf-8') as f:
        json.dump(sc, f)
    subprocess.run(['node', RENDERER, os.path.join(S, 'scenes_%s.json' % var), out, FONTS if os.path.isdir(FONTS) else ''], check=True)
    for s in sc:
        v, r = s['name'].split('_', 1)
        scenes[(var, v, r)] = os.path.join(out, s['name'] + '.png')

CELL_W, PAD = 760, 22
title_h, section_h, cap_h = 112, 46, 46
tiles = {}
for (var, v, r), path in scenes.items():
    im = Image.open(path).convert('RGB')
    tiles[(var, v, r)] = im.resize((CELL_W, round(im.height * CELL_W / im.width)), Image.LANCZOS)
plan = []  # (view label, [rows that exist])
for view, label in VIEWS:
    rows = [r for r in ROWS if ('current', view, r) in tiles and ('option2', view, r) in tiles]
    plan.append((view, label, rows))
height = title_h + PAD
for view, label, rows in plan:
    height += section_h + sum(tiles[('current', view, r)].height + cap_h + PAD for r in rows)
width = PAD + 2 * (CELL_W + PAD)
legend_h = 46 + 30 * ((len(LEGEND) + 1) // 2) + 40
height += legend_h
BG = (22, 24, 38)
sheet = Image.new('RGB', (width, height), BG)
d = ImageDraw.Draw(sheet)
d.text((PAD, 16), 'R156 PREVIEW: the Bag without green, and without the hint line', font=font(26, '900'), fill=(255, 255, 255))
d.text((PAD, 52), 'Owner: "dont make this green and remove that text saying click to hold and so on".  CURRENT = this checkout (hint line kept, as it is today).  OPTION 2 = navy sheet,',
       font=font(14, '500'), fill=(205, 214, 240))
d.text((PAD, 72), 'no green chrome anywhere in the Bag (only rarity colours stay), a neutral light drop highlight (Discard stays red), the hint line gone. The count stays left of Discard.',
       font=font(14, '500'), fill=(205, 214, 240))
d.text((PAD, 92), 'APPROXIMATE: the real Bag GUI tree drawn by a mock + Chromium (stand-in emoji for the 3D item pictures, Montserrat for Gotham), not a Studio screenshot.',
       font=font(14, '500'), fill=(255, 214, 140))
y = title_h


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


def pill(img_draw, x0, y0, text, color):
    f = font(13, '900')
    w = int(img_draw.textlength(text, font=f)) + 18
    img_draw.rounded_rectangle([x0, y0, x0 + w, y0 + 22], radius=11, fill=color)
    img_draw.text((x0 + 9, y0 + 3), text, font=f, fill=(255, 255, 255))


for view, label, rows in plan:
    d.rectangle([PAD, y + 6, width - PAD, y + section_h - 10], fill=(40, 44, 70))
    d.text((PAD + 12, y + 12), label, font=font(18, '900'), fill=(255, 255, 255))
    y += section_h
    for r in rows:
        x = PAD
        rh = tiles[('current', view, r)].height
        for var, tag, color in VARIANTS:
            im = tiles[(var, view, r)]
            sheet.paste(im, (x, y))
            d.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=(96, 104, 140), width=1)
            pill(d, x + 8, y + 8, tag, color)
            x += CELL_W + PAD
        for k, ln in enumerate(wrap(d, CAPTIONS.get((view, r), captions.get((view, r), r)), font(14), width - 2 * PAD)[:2]):
            d.text((PAD, y + rh + 5 + k * 19), ln, font=font(14), fill=(235, 238, 250))
        y += rh + cap_h + PAD
# the legend: every colour OPTION 2 changes, old -> new
d.rectangle([PAD, y + 4, width - PAD, y + 38], fill=(40, 44, 70))
d.text((PAD + 12, y + 10), 'OPTION 2: every colour changed (old -> new)', font=font(18, '900'), fill=(255, 255, 255))
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
d.text((PAD, y), 'Unchanged: the red Discard bin and buttons (#7A2C34, #C44048, target #FF6060), white selection outlines, amber / red count, rarity colours (Common line #92A68E, Uncommon name green).',
       font=font(13, '500'), fill=(205, 214, 240))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size, len(tiles), 'scenes')
