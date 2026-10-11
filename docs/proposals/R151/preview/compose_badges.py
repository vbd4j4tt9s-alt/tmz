"""R151 badge preview sheet: docs/proposals/R151/index_badges.png = the Index (desktop and phone) as it opens, and the notification badge before (R150) and after, zoomed.
Usage: python3 compose_badges.py <scratch dir with the JSONs> <out png>
Inputs (written by run_badges_preview.sh): badge_<before|after>_nav.json and badge_<x>_gui.json (JSON_NAV + JSON_GUI of the 390x844 scene), desktop_after_gui.json (the 1280x1000 scene).
The GUI JSON is the REAL ChestIndex tree under the Roblox mock, drawn by the R137 renderer (render_index.py) with Pillow.
APPROXIMATE: DejaVu Sans Bold stands in for Fredoka, no real font metrics. Not a Studio screenshot."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
RENDER = os.path.join(REPO, 'docs', 'proposals', 'R137', 'preview', 'render_index.py')
BG = (18, 26, 40)
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'


def font(px):
    return ImageFont.truetype(BOLD, px)


# The R137 renderer stops on a clipped item that lies entirely outside its clip (a negative clip width: a tab scrolled off the row, a card below the list). Such an item is simply not
# drawn: the two rectangle calls get max(0, ...) in a scratch copy of the renderer (the renderer itself is shared and stays as it is).
FIXED = os.path.join(S, 'render_index_fixed.py')
open(FIXED, 'w', encoding='utf-8').write(open(RENDER, encoding='utf-8').read().replace('c[0] + c[2], c[1] + c[3]', 'c[0] + max(0, c[2]), c[1] + max(0, c[3])'))


def render(json_file, png, k, crop=None):
    env = dict(os.environ, IMGDIR=S)
    args = [sys.executable, FIXED, json_file, png, str(k), '%d,%d,%d' % BG]
    if crop:
        args.append(','.join(str(v) for v in crop))
    subprocess.run(args, check=True, env=env, stdout=subprocess.DEVNULL)
    return Image.open(png).convert('RGB')


def items(path):
    return json.load(open(path))['items']


def find(its, name):
    return [i for i in its if i['n'] == name]


def panel_crop(path):
    p = find(items(path), 'IndexPanel')[0]
    return [int(p['x']) - 6, int(p['y']) - 6, int(p['w']) + 12, int(p['h']) + 12]


def clean(path):  # the renderer's font has no emoji
    out = path + '.clean.json'
    open(out, 'w', encoding='utf-8').write(open(path, encoding='utf-8').read())
    return out


# --- the Index as it opens (the badge's place in it) ---------------------------------------------------------------------------------------------------------
shots = {}
for name, src, k in (('desktop', 'desktop_after_gui.json', 1.0), ('phone', 'badge_after_gui.json', 1.45)):
    path = os.path.join(S, src)
    shots[name] = render(clean(path), os.path.join(S, name + '.png'), k, [v for v in panel_crop(path)])

# --- the badge, before and after --------------------------------------------------------------------------------------------------------------------------------------
Z = 5


def badge_crops(which):
    nav_json, gui_json = os.path.join(S, 'badge_%s_nav.json' % which), os.path.join(S, 'badge_%s_gui.json' % which)
    nav, gui = items(nav_json), items(gui_json)
    btn = find(nav, 'IndexButton')[0]
    group = [i for i in nav if i['n'] == 'MenuOption2'][0]
    cx, cy, cw, ch = int(btn['x']) - 4, int(btn['y']) - 22, int(btn['w']) + 49, int(btn['h']) + 30   # (not the MENU button's alert below)
    a = render(nav_json, os.path.join(S, 'badge_%s_a.png' % which), Z, [cx, cy, cw, ch])
    d = ImageDraw.Draw(a)
    gx0, gy0 = (group['x'] - cx) * Z, (group['y'] - cy) * Z
    gx1, gy1 = gx0 + group['w'] * Z, gy0 + group['h'] * Z
    for x in range(int(gx0), int(gx1), 16):  # the CanvasGroup's edge, dashed (it clips everything outside)
        d.line((x, gy0, min(x + 8, gx1), gy0), fill=(255, 200, 60), width=2)
        d.line((x, gy1, min(x + 8, gx1), gy1), fill=(255, 200, 60), width=2)
    for y in range(int(gy0), int(gy1), 16):
        d.line((gx0, y, gx0, min(y + 8, gy1)), fill=(255, 200, 60), width=2)
        d.line((gx1, y, gx1, min(y + 8, gy1)), fill=(255, 200, 60), width=2)
    hub = find(nav, 'MenuButton')[0]
    c = render(nav_json, os.path.join(S, 'badge_%s_c.png' % which), Z, [int(hub['x'] + hub['w']) - 36, int(hub['y']) - 14, 50, 44])
    tab = find(gui, 'Biome1')[0]
    strip = find(gui, 'BiomeProgress')[0]
    tx, ty, tw, th = int(tab['x'] + tab['w']) - 52, int(strip['y']) - 14, 70, 56
    b = render(gui_json, os.path.join(S, 'badge_%s_b.png' % which), Z, [tx, ty, tw, th])
    d = ImageDraw.Draw(b)
    ey = (strip['y'] - ty) * Z
    for x in range(0, b.width, 16):  # the tab row's top edge (a ScrollingFrame clips at it)
        d.line((x, ey, x + 8, ey), fill=(255, 200, 60), width=2)
    return a, b, c


before_a, before_b, before_c = badge_crops('before')
after_a, after_b, after_c = badge_crops('after')

# --- the sheet ------------------------------------------------------------------------------------------------------------------------------------------------------------
pad = 28
badge_w = before_a.width + after_a.width + before_b.width + after_b.width + before_c.width + after_c.width + 5 * 24 + 60
top_w = shots['desktop'].width + 40 + shots['phone'].width
top_h = max(shots['desktop'].height, shots['phone'].height)
W_ = max(pad * 2 + top_w, badge_w + pad * 2)
H_ = 110 + 30 + top_h + 36 + 70 + max(before_a.height, before_b.height, before_c.height) + 60
sheet = Image.new('RGB', (W_, H_), (12, 16, 28))
d = ImageDraw.Draw(sheet)
d.text((pad, 18), 'R151: the polished Index notification badge', font=font(34), fill=(255, 226, 96))
d.text((pad, 66), 'APPROXIMATE: the real ChestIndex tree under the Roblox mock, drawn with Pillow (DejaVu stands in for Fredoka). Not a Studio screenshot.', font=font(17), fill=(205, 215, 240))
y0 = 110
d.text((pad, y0), 'DESKTOP 1280x1000: the Index as it opens (a red dot on the Forest tab)', font=font(19), fill=(150, 255, 110))
sheet.paste(shots['desktop'], (pad, y0 + 30))
x1 = pad + shots['desktop'].width + 40
d.text((x1, y0), 'PHONE 390x844', font=font(19), fill=(150, 255, 110))
sheet.paste(shots['phone'], (x1, y0 + 30))
y2 = y0 + 30 + top_h + 36
d.text((pad, y2), 'NOTIFICATION BADGE, zoomed 5x.  Yellow dashes = the edge of what clips it.', font=font(24), fill=(255, 226, 96))
x = pad
y3 = y2 + 70
for img, label, col in ((before_a, 'BEFORE (R150): INDEX count, cut off by the wheel\'s CanvasGroup', (255, 130, 130)), (after_a, 'AFTER: the polished badge, whole', (150, 255, 110)),
                        (before_b, 'BEFORE: tab dot, cut at the tab row\'s top', (255, 130, 130)), (after_b, 'AFTER: dot inside its tab', (150, 255, 110)),
                        (before_c, 'BEFORE: MENU "!"', (255, 130, 130)), (after_c, 'AFTER: MENU "!"', (150, 255, 110))):
    d.text((x, y3 - 40), label, font=font(15), fill=col)
    sheet.paste(img, (x, y3))
    x += img.width + 24
sheet = sheet.crop((0, 0, W_, y3 + max(before_a.height, before_b.height, before_c.height) + 24))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
