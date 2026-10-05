"""R150 preview: turns the SCENE lines of bonus_scenes.luau (one log per side / view) into PNGs with Chromium (render_gui.mjs) and lays
them out as before (R149) / after (R150) sheets. Usage: python3 make_sheets.py SCRATCH OUTDIR   (run_bonus_preview.sh calls it)."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'montserrat', 'files')
SKY = 'linear-gradient(180deg,#8fd0f6 0%,#cdeafb 46%,#78c060 47%,#4e9c48 100%)'
WORLD = 'linear-gradient(180deg,#5da4d6 0%,#a9d8f0 40%,#6fb85c 41%,#3f8a46 100%)'


def font(px, weight='900'):
    path = os.path.join(FONTS, 'montserrat-latin-%s-normal.woff' % weight)
    try:
        return ImageFont.truetype(path, px)
    except Exception:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


# 1. parse the logs -----------------------------------------------------------------------------------------------
scenes, meta = [], {}
for side in ('old', 'new'):
    for view in ('desktop', 'phone'):
        log = os.path.join(S, '%s_%s' % (side, view), 'scenes.log')
        for line in open(log, encoding='utf-8'):
            if not line.startswith('SCENE '):
                continue
            head, payload = line.rstrip('\n').split(' ', 7)[1:7], line.rstrip('\n').split(' ', 7)[7]
            name, x, y, w, h, scale = head
            key = '%s_%s_%s' % (side, view, name)
            roll = name.startswith('roll_')
            scenes.append({'name': key, 'json': payload, 'scale': float(scale), 'bg': WORLD if roll else SKY, 'crop': [int(x), int(y), int(w), int(h)]})
            meta[key] = (int(w), int(h), float(scale))
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
fontdir = FONTS if os.path.isdir(FONTS) else ''
subprocess.run(['node', os.path.join(HERE, 'render_gui.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), fontdir], check=True)


def load(side, view, name, width=None):
    p = os.path.join(S, 'png', '%s_%s_%s.png' % (side, view, name))
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert('RGBA')
    if width and im.width != width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    return im


BG = (16, 20, 34)
TXT = (235, 238, 250)
OLD_C, NEW_C = (255, 150, 150), (150, 255, 120)


def sheet(title, columns, rows, cell_w, cell_h, label_w=150, pad=14, note=None):
    """rows = [(label, color, [image|None per column])]; columns = [caption]. Returns an RGB image."""
    W = label_w + len(columns) * (cell_w + pad) + pad
    top = 70 + (30 if note else 0)
    H = top + 36 + len(rows) * (cell_h + pad) + pad
    sh = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(sh)
    d.text((pad, 14), title, font=font(28), fill=(255, 226, 96))
    if note:
        d.text((pad, 52), note, font=font(15, '700'), fill=(170, 182, 210))
    for ci, cap in enumerate(columns):
        d.text((label_w + ci * (cell_w + pad) + pad, top + 4), cap, font=font(18), fill=TXT)
    for ri, (label, color, imgs) in enumerate(rows):
        y = top + 36 + ri * (cell_h + pad)
        d.text((pad, y + cell_h // 2 - 10), label, font=font(22), fill=color)
        for ci, im in enumerate(imgs):
            x = label_w + ci * (cell_w + pad) + pad
            d.rounded_rectangle((x - 2, y - 2, x + cell_w + 2, y + cell_h + 2), 8, fill=(26, 32, 52))
            if im is None:
                d.text((x + 12, y + cell_h // 2 - 10), 'not shown in R149', font=font(16, '700'), fill=(120, 130, 160))
                continue
            sh.paste(im, (x + (cell_w - im.width) // 2, y + (cell_h - im.height) // 2), im)
    return sh


def fit_row(side, view, names, width):
    return [load(side, view, n, width) for n in names]


# 2. button ------------------------------------------------------------------------------------------------------------
btn_names = ['button_charging', 'button_almost', 'button_ready', 'button_ready2']
btn_caps = ['charging (about 3:10 left)', 'almost there (last 30 s)', 'READY (1)', 'READY x2 (count badge)']
rows = []
for view, tag in (('desktop', 'desktop'), ('phone', 'phone')):
    for side, label, color in (('old', 'R149 ' + tag, OLD_C), ('new', 'R150 ' + tag, NEW_C)):
        rows.append((label, color, fit_row(side, view, btn_names, 520)))
cell_h = max(im.height for _, _, imgs in rows for im in imgs if im)
button_sheet = sheet('BONUS ROLL button', btn_caps, rows, 520, cell_h, 190,
                     note='R149 has no button while charging; R150 shows it (calm, with the progress) only while standing on the treadmill.')
button_sheet.save(os.path.join(OUT, 'bonus_button.png'))
# 3. gift timer ---------------------------------------------------------------------------------------------------------
bar_names = ['bar_mid', 'bar_almost', 'bar_ready', 'bar_full']
bar_caps = ['mid (about 3:40 to go)', 'almost there (last 30 s)', 'a roll completes', 'at the cap (2 ready)']
rows = [('R149', OLD_C, fit_row('old', 'desktop', bar_names, 520)), ('R150', NEW_C, fit_row('new', 'desktop', bar_names, 520))]
cell_h = max(im.height for _, _, imgs in rows for im in imgs if im)
timer_sheet = sheet('Gift timer (the billboard over the player on the treadmill)', bar_caps, rows, 520, cell_h, 110,
                    note='R150: the gift fills with colour as the next roll nears; "ALMOST THERE!" in the last 30 s; a pop, shake and sparkles when a roll completes.')
timer_sheet.save(os.path.join(OUT, 'bonus_timer.png'))
# 4. roll screens ---------------------------------------------------------------------------------------------------------
roll_names = ['roll_spin', 'roll_common', 'roll_legendary', 'roll_mythic', 'roll_secret']
roll_caps = {'roll_spin': 'spinning', 'roll_common': 'Common reveal', 'roll_rare': 'Rare reveal', 'roll_legendary': 'Legendary reveal', 'roll_mythic': 'Mythic reveal', 'roll_secret': 'Secret reveal'}


def roll_sheet(view, names, cell_w, title):
    rows = []
    for n in names:
        rows.append((roll_caps[n], TXT, [load('old', view, n, cell_w), load('new', view, n, cell_w)]))
    ch = max(im.height for _, _, imgs in rows for im in imgs if im)
    return sheet(title, ['R149', 'R150'], rows, cell_w, ch, 190)


roll_sheet('desktop', roll_names, 760, 'Roll screen, desktop 1280 x 720 (shown at 59%)').save(os.path.join(OUT, 'bonus_roll_desktop.png'))
roll_sheet('phone', roll_names[:4], 760, 'Roll screen, phone 844 x 390 (landscape)').save(os.path.join(OUT, 'bonus_roll_phone.png'))
# 5. overview ---------------------------------------------------------------------------------------------------------------
parts = [Image.open(os.path.join(OUT, n)).convert('RGB') for n in ('bonus_button.png', 'bonus_timer.png', 'bonus_roll_desktop.png', 'bonus_roll_phone.png')]
W = max(p.width for p in parts)
total = sum(p.height for p in parts)
ov = Image.new('RGB', (W, total), BG)
y = 0
for p in parts:
    ov.paste(p, (0, y))
    y += p.height
ov.save(os.path.join(OUT, 'bonus_ui.png'))
print('wrote', [os.path.join(OUT, n) for n in ('bonus_ui.png', 'bonus_button.png', 'bonus_timer.png', 'bonus_roll_desktop.png', 'bonus_roll_phone.png')])
