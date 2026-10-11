"""R155 preview: the SCENE / CAPTION lines of inventory_scenes155.luau (pc and phone logs) -> PNGs with Chromium (R153's render_gui153.mjs) -> one storyboard sheet.
Usage: python3 make_inventory_sheet155.py SCRATCH OUT.png   (run_inventory_preview.sh calls it)"""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')  # (render_gui155.mjs: Fredoka One for the pity bars + Montserrat beside it)
SKY = 'linear-gradient(180deg,#8fd0f6 0%,#cdeafb 46%,#78c060 47%,#4e9c48 100%)'


def font(px, weight='700'):
    try:
        return ImageFont.truetype(os.path.join(FONTS, '..', '..', 'montserrat', 'files', 'montserrat-latin-%s-normal.woff' % weight), px)
    except Exception:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


scenes, captions, order = [], {}, []
for view in ('pc', 'phone'):
    for line in open(os.path.join(S, view, 'scenes.log'), encoding='utf-8'):
        if line.startswith('SCENE '):
            parts = line.rstrip('\n').split(' ', 7)
            name, x, y, cw, ch, scale = parts[1:7]
            scenes.append({'name': name, 'json': parts[7], 'scale': float(scale), 'bg': SKY, 'crop': [int(x), int(y), int(cw), int(ch)]})
            order.append(name)
        elif line.startswith('CAPTION '):
            name, text = line.rstrip('\n').split(' ', 2)[1:]
            captions[name] = text
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
subprocess.run(['node', os.path.join(HERE, 'render_gui155.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'),
                FONTS if os.path.isdir(FONTS) else ''], check=True)


def wrap(draw, text, fnt, width):
    words, lines, cur = text.split(' '), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=fnt) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


# layout: pc scenes 2 per row at 620 px wide, phone scenes 2 per row at 620 px wide
CELL_W, PAD, CAP_H = 620, 22, 58
tiles = []
for name in order:
    im = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')
    h = round(im.height * CELL_W / im.width)
    tiles.append((name, im.resize((CELL_W, h), Image.LANCZOS)))
rows = [tiles[i:i + 2] for i in range(0, len(tiles), 2)]
title_h = 86
height = title_h + sum(max(t[1].height for t in row) + CAP_H + PAD for row in rows) + PAD
width = PAD + 2 * (CELL_W + PAD)
sheet = Image.new('RGB', (width, height), (24, 40, 33))
d = ImageDraw.Draw(sheet)
d.text((PAD, 18), 'R155: the hotbar and the Bag work like Roblox\'s inventory; 200 items; discarding; tooltips', font=font(26, '900'), fill=(255, 255, 255))
d.text((PAD, 52), 'The real Hotbar / Bag of this checkout on the mock (pc 1280x720 mouse, phone 844x390 touch). Item pictures are stand-in emoji (the game draws 3D pictures).',
       font=font(14, '500'), fill=(190, 225, 200))
y = title_h
for row in rows:
    x = PAD
    rh = max(t[1].height for t in row)
    for name, im in row:
        sheet.paste(im, (x, y))
        d.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=(147, 255, 69), width=1)
        lines = wrap(d, captions.get(name, name), font(14), CELL_W)
        for k, ln in enumerate(lines[:3]):
            d.text((x, y + rh + 6 + k * 17), ln, font=font(14), fill=(235, 245, 235))
        x += CELL_W + PAD
    y += rh + CAP_H + PAD
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size, len(tiles), 'scenes')
