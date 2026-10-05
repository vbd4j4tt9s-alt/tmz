"""R151 preview: turns the SCENE lines of announce_scenes.luau (one log per view: desktop / phone / portrait) into PNGs with Chromium (R150's render_gui.mjs) and lays
them out as docs/proposals/R151/announcements.png. Usage: python3 make_sheet.py SCRATCH OUTFILE   (run_announce_preview.sh calls it)."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
RENDER = os.path.normpath(os.path.join(HERE, '../../R150/preview/render_gui.mjs'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'montserrat', 'files')
WORLD = 'linear-gradient(180deg,#5da4d6 0%,#a9d8f0 40%,#6fb85c 41%,#3f8a46 100%)'
VIEWS = (('desktop', 'Desktop 1280 x 720', 700), ('phone', 'Phone 844 x 390 (landscape)', 600), ('portrait', 'Phone 390 x 844 (portrait)', 470))
ROWS = (('legendary', 'LEGENDARY', 'Legendary pull in this server: a banner and a chat line for everyone in the server'),
        ('mythic', 'MYTHIC', ''), ('secret', 'SECRET', 'Secret and above is also sent to the other servers'), ('cosmic', 'COSMIC', ''),
        ('king', 'KING (gold coat)', ''),
        ('global', 'OTHER SERVER', 'The small gold banner other servers show for a Secret+ pull'),
        ('record', 'RECORD', 'For the hub displays: "took BEST PULL TODAY!"'))


def font(px, weight='900'):
    path = os.path.join(FONTS, 'montserrat-latin-%s-normal.woff' % weight)
    try:
        return ImageFont.truetype(path, px)
    except Exception:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


scenes, meta = [], {}
for view, _, _ in VIEWS:
    log = os.path.join(S, view, 'scenes.log')
    for line in open(log, encoding='utf-8'):
        if not line.startswith('SCENE '):
            continue
        parts = line.rstrip('\n').split(' ', 7)
        name, x, y, w, h, scale, payload = parts[1], parts[2], parts[3], parts[4], parts[5], parts[6], parts[7]
        key = '%s_%s' % (view, name)
        scenes.append({'name': key, 'json': payload, 'scale': float(scale), 'bg': WORLD, 'crop': [int(x), int(y), int(w), int(h)]})
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
fontdir = FONTS if os.path.isdir(FONTS) else ''
subprocess.run(['node', RENDER, os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), fontdir], check=True)


def load(view, name, width=None):
    p = os.path.join(S, 'png', '%s_%s.png' % (view, name))
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert('RGBA')
    if width and im.width > width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    return im


BG, TXT, SUB = (16, 20, 34), (235, 238, 250), (170, 182, 210)
PAD, LABEL = 16, 190
col_w = [c[2] for c in VIEWS]
cells = {(r[0], v[0]): load(v[0], r[0], v[2]) for r in ROWS for v in VIEWS}
row_h = [max((cells[(r[0], v[0])].height if cells[(r[0], v[0])] else 0) for v in VIEWS) + PAD for r in ROWS]
ctx = [load(v[0], 'context', 1280 if v[0] == 'desktop' else 1266 if v[0] == 'phone' else 585) for v in VIEWS]
width = LABEL + sum(col_w) + PAD * (len(VIEWS) + 1)
ctx_w = max(sum(c.width for c in ctx if c) + PAD * 4, width)
width = max(width, ctx_w)
top = 118
height = top + 40 + sum(row_h) + 70 + max(c.height for c in ctx if c) + 40 + PAD
sheet = Image.new('RGB', (width, height), BG)
d = ImageDraw.Draw(sheet)
d.text((PAD, 14), 'R151 pull announcements: the banner for a Legendary+ pull in this server, the small one for a Secret+ pull in another server, and records', font=font(26), fill=(255, 226, 96))
d.text((PAD, 52), 'Drawn by the real client scripts under a Roblox mock and a headless browser: the seed picture and the headshot are stand-in drawings (the game shows the 3D seed and the player\'s Roblox headshot),', font=font(14, '700'), fill=SUB)
d.text((PAD, 72), 'the font is Montserrat for Gotham, sparkles and the shine sweep are caught half a second in. Frame colours are the rarity colours of the game (Legendary gold, Mythic red, Secret white, Cosmic lavender, King pale gold); other servers gold; records amber.', font=font(14, '700'), fill=SUB)
x = LABEL + PAD
for (view, caption, cw) in VIEWS:
    d.text((x, top + 6), caption, font=font(20), fill=TXT)
    x += cw + PAD
y = top + 40
for ri, (name, label, note) in enumerate(ROWS):
    d.text((PAD, y + 8), label, font=font(20), fill=(255, 226, 96))
    if note:
        words, line, ly = note.split(' '), '', y + 36
        for w in words:
            if d.textlength(line + ' ' + w, font=font(12, '700')) > LABEL - 24:
                d.text((PAD, ly), line.strip(), font=font(12, '700'), fill=SUB);ly += 15;line = ''
            line += ' ' + w
        d.text((PAD, ly), line.strip(), font=font(12, '700'), fill=SUB)
    x = LABEL + PAD
    for (view, caption, cw) in VIEWS:
        im = cells[(name, view)]
        d.rounded_rectangle((x - 3, y - 3, x + cw + 3, y + row_h[ri] - PAD + 3), 8, fill=(26, 32, 52))
        if im:
            sheet.paste(im, (x + (cw - im.width) // 2, y), im)
        x += cw + PAD
    y += row_h[ri]
y += 14
d.text((PAD, y), 'In place: the top of the screen with the travel buttons and a notice row. While the banner shows, the row sits below it (HudNotices) and goes back afterwards.', font=font(20), fill=(255, 226, 96))
y += 44
x = PAD
for c in ctx:
    if c:
        d.rounded_rectangle((x - 3, y - 3, x + c.width + 3, y + c.height + 3), 8, fill=(26, 32, 52))
        sheet.paste(c, (x, y), c)
        x += c.width + PAD
sheet.save(OUT)
print('wrote', OUT, sheet.size)
