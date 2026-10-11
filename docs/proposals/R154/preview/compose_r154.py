"""R154 preview sheet: docs/proposals/R154/badges_popups.png = the notification badge text (R153 as the owner saw it vs R154), the speed popups 20% smaller (R153 vs R154 on a computer and a phone, one popup
over its life: its size is constant after the 0.28 s pop-in) and how long the popups live on quality tier 1 (R153: cut at ~0.4 s; R154: the whole 0.65 s).
Usage: python3 compose_r154.py <scratch dir with the JSONs> <out png> [owner screenshot of the badges] [owner screenshot of the popups]
Inputs (written by run_preview154.sh): badge_<before|after>_nav.json and badge9_<before|after>_nav.json (the real ChestIndex tree, 390 x 844; before = the R153 NotifyBadge151), popups.json
(popups_scene154.luau), life_<before|after>.json (lifetimes_scene.luau). The owner's two screenshots of R153 are optional (they are his; they are shown as the real "before" when given).
APPROXIMATE: the badge / popup frames are drawn by the R137 renderer / Pillow from the Roblox mock's tree, DejaVu Sans Bold stands in for Fredoka, the mock draws a TextScaled label at its maximum
size (the engine drew R153's far smaller: the owner's screenshot). Not a Studio screenshot."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
OWNER_BADGE = sys.argv[3] if len(sys.argv) > 3 and os.path.exists(sys.argv[3]) else None
OWNER_POPUP = sys.argv[4] if len(sys.argv) > 4 and os.path.exists(sys.argv[4]) else None
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
RENDER = os.path.join(REPO, 'docs', 'proposals', 'R137', 'preview', 'render_index.py')
BG = (18, 26, 40)
GREEN, RED, YELLOW, GREY = (150, 255, 110), (255, 130, 130), (255, 226, 96), (205, 215, 240)
Z = 5


def font(px):
    return ImageFont.truetype(BOLD, max(6, int(round(px))))


FIXED = os.path.join(S, 'render_index_fixed.py')
open(FIXED, 'w', encoding='utf-8').write(open(RENDER, encoding='utf-8').read().replace('c[0] + c[2], c[1] + c[3]', 'c[0] + max(0, c[2]), c[1] + max(0, c[3])'))


def render(json_file, png, k, crop):
    meta = png + '.crop'
    if os.path.exists(png) and os.path.exists(meta) and open(meta).read() == '%s %s %s' % (k, crop, os.path.getmtime(json_file)):  # (the R137 renderer takes minutes: cached)
        return Image.open(png).convert('RGB')
    env = dict(os.environ, IMGDIR=S)
    subprocess.run([sys.executable, FIXED, json_file, png, str(k), '%d,%d,%d' % BG, ','.join(str(v) for v in crop)], check=True, env=env, stdout=subprocess.DEVNULL)
    open(meta, 'w').write('%s %s %s' % (k, crop, os.path.getmtime(json_file)))
    return Image.open(png).convert('RGB')


def items(path):
    return json.load(open(path))['items']


def find(its, name):
    return [i for i in its if i['n'] == name]


def badge_crops(prefix):
    nav_json = os.path.join(S, '%s_nav.json' % prefix)
    nav = items(nav_json)
    btn = find(nav, 'IndexButton')[0]
    hub = find(nav, 'MenuButton')[0]
    a = render(nav_json, os.path.join(S, 'r154_%s_a.png' % prefix), Z, [int(btn['x']) + int(btn['w']) - 50, int(btn['y']) - 22, 76, 66])
    c = render(nav_json, os.path.join(S, 'r154_%s_c.png' % prefix), Z, [int(hub['x'] + hub['w']) - 50, int(hub['y']) - 22, 66, 62])
    return a, c


def bolt(d, cx, cy, h, fill, outline):
    w = h * .55
    pts = [(cx + w * .15, cy - h / 2), (cx - w * .5, cy + h * .08), (cx - w * .02, cy + h * .08), (cx - w * .2, cy + h / 2), (cx + w * .5, cy - h * .12), (cx + w * .04, cy - h * .12)]
    d.polygon(pts, fill=fill, outline=outline)


def mix(c, bg, a):
    return tuple(int(bg[i] + (c[i] - bg[i]) * a) for i in range(3))


def draw_popup(d, cx, cy, text, text_px, icon_px, s, alpha, bg, k=1.0):
    tp, ip = text_px * s * k, icon_px * s * k
    fnt = font(tp)
    tw = d.textlength(text, font=fnt)
    iw = ip * .6
    total = iw + 3 * k + tw
    x0 = cx - total / 2
    bolt(d, x0 + iw / 2, cy, ip, mix((255, 222, 66), bg, alpha), mix((17, 26, 42), bg, alpha))
    d.text((x0 + iw + 3 * k, cy), text, font=fnt, fill=mix((125, 248, 255), bg, alpha), anchor='lm', stroke_width=max(1, int(tp * .11)), stroke_fill=mix((17, 26, 42), bg, alpha))


def popup_view(view, key, text_key, icon_key, scale):
    W_, H_ = int(view['w'] * scale), int(view['h'] * scale)
    bg = (70, 110, 150)
    img = Image.new('RGB', (W_, H_), bg)
    d = ImageDraw.Draw(img)
    d.rectangle((0, int(H_ * .78), W_, H_), fill=(78, 128, 82))
    for b in view['hud']:
        if b['n'] in ('OwnerTools',):
            continue
        d.rounded_rectangle((b['x'] * scale, b['y'] * scale, (b['x'] + b['w']) * scale, (b['y'] + b['h']) * scale), radius=6, outline=(255, 200, 80) if b['n'].startswith(('Wallet', 'Status')) else (230, 230, 240),
                            fill=(40, 48, 66))
    hx, hy = view['head'][0] * scale, view['head'][1] * scale
    d.ellipse((hx - 14 * scale, hy - 16 * scale, hx + 14 * scale, hy + 16 * scale), fill=(255, 214, 170))
    d.rectangle((hx - 18 * scale, hy + 14 * scale, hx + 18 * scale, hy + 70 * scale), fill=(80, 90, 170))
    for f in view[key]:
        draw_popup(d, hx + f['x'] * scale, hy + f['y'] * scale, f['text'], view[text_key], view[icon_key], f['s'], f['a'], bg, scale)
    return img


def heading(d, y, text, size, fill, maxw):
    """Draws `text` wrapped to maxw px; returns the y below it."""
    f = font(size)
    words, line, lines = text.split(' '), '', []
    for w in words:
        t = (line + ' ' + w).strip()
        if d.textlength(t, font=f) > maxw and line:
            lines.append(line)
            line = w
        else:
            line = t
    lines.append(line)
    for i, l in enumerate(lines):
        d.text((pad, y + i * (size + 5)), l, font=f, fill=fill)
    return y + len(lines) * (size + 5)


def life_panel(path, width, label, color):
    data = json.load(open(path))
    pops = data['popups'][:18]
    row, top = 9, 22
    img = Image.new('RGB', (width, top + row * len(pops) + 8), (24, 32, 50))
    d = ImageDraw.Draw(img)
    d.text((6, 3), label, font=font(14), fill=color)
    scale = (width - 160) / 3.0
    for i, p in enumerate(pops):
        y = top + i * row
        x0, x1 = 80 + p['t0'] * scale, 80 + p['t1'] * scale
        full = (p['t1'] - p['t0']) >= data['life'] - .04
        d.rectangle((x0, y + 1, x1, y + row - 2), fill=(110, 220, 120) if full else (240, 120, 110))
        d.text((x1 + 5, y + row / 2), '%.2f s%s' % (p['t1'] - p['t0'], '' if full else '  cut, alpha %.2f' % p['a']), font=font(9), fill=GREY, anchor='lm')
    d.text((6, top + 4), 'popups, in order', font=font(10), fill=GREY)
    return img


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
before_a, before_c = badge_crops('badge_before')
after_a, after_c = badge_crops('badge_after')
before9_a, _ = badge_crops('badge9_before')
after9_a, _ = badge_crops('badge9_after')
pop = json.load(open(os.path.join(S, 'popups.json')))
pc = [v for v in pop['views'] if v['w'] == 1280][0]
phone = [v for v in pop['views'] if v['w'] == 844][0]
pc_old, pc_new = popup_view(pc, 'old', 'textOld', 'iconOld', .55), popup_view(pc, 'new', 'textNew', 'iconNew', .55)
ph_old, ph_new = popup_view(phone, 'old', 'textOld', 'iconOld', .8), popup_view(phone, 'new', 'textNew', 'iconNew', .8)
pad = 28
W_ = 1560
MAXW = W_ - 2 * pad
sheet = Image.new("RGB", (W_, 3800), (12, 16, 28))
d = ImageDraw.Draw(sheet)
y = 20
d.text((pad, y), 'R154: the text fills the notification bubble; speed popups 20% smaller, one size, no glitch', font=font(30), fill=YELLOW)
y += 46
y = heading(d, y, 'APPROXIMATE: the real ChestIndex / NotifyBadge151 / SpeedPopupStyle / SpeedGainPopup of this checkout on the Roblox mock, drawn with Pillow (DejaVu stands in for Fredoka, which is narrower: its "9+" fits the disc, see the tests). Not a Studio screenshot.', 15, GREY, MAXW) + 14
# 1. the badges ------------------------------------------------------------------------------------------------------------------------------------------------
y = heading(d, y, '1. NOTIFICATION BADGE TEXT, zoomed 5x. R153: the engine\'s TextScaled fit left the digits about a third of the bubble; R154: an explicit text size, 78% of the bubble for "2" / "!", 68% for "9+"', 19, YELLOW, MAXW) + 26
x = pad
panels = []
if OWNER_BADGE:
    im = Image.open(OWNER_BADGE).convert('RGB')
    a = im.crop((160, 30, 240, 100)).resize((400, 350), Image.LANCZOS)
    c = im.crop((70, 115, 150, 175)).resize((400, 300), Image.LANCZOS)
    panels += [(a, 'R153 INDEX "9+": the owner\'s screenshot', RED), (c, 'R153 MENU "!": the owner\'s screenshot', RED)]
else:
    panels += [(before9_a, 'R153 INDEX "9+" as the MOCK draws it (TextScaled at its max; the engine drew it smaller)', RED), (before_c, 'R153 MENU "!" (as the mock draws it)', RED)]
panels += [(after_a, 'R154 INDEX "2" (36 px)', GREEN), (after9_a, 'R154 INDEX "9+"', GREEN), (after_c, 'R154 MENU "!" (30 px)', GREEN)]
rowh = 0
for img, label, col in panels:
    if x + img.width > W_ - pad:
        x = pad
        y += rowh + 40
        rowh = 0
    d.text((x, y - 22), label, font=font(13), fill=col)
    sheet.paste(img, (x, y))
    x += img.width + 18
    rowh = max(rowh, img.height)
y += rowh + 44
# 2. the popups -------------------------------------------------------------------------------------------------------------------------------------------------
y = heading(d, y, '2. SPEED POPUPS 20% SMALLER (text 44 -> 35, bolt 40 -> 32, box 300 x 72 -> 240 x 58, outline 5 -> 4; the fan, pop, fling, fade and 10 a second are the same, the fan scaled with them)', 19, YELLOW, MAXW) + 26
d.text((pad, y - 22), 'R153: 1280 x 720', font=font(13), fill=RED)
d.text((pad + pc_old.width + 24, y - 22), 'R154: 1280 x 720', font=font(13), fill=GREEN)
sheet.paste(pc_old, (pad, y))
sheet.paste(pc_new, (pad + pc_old.width + 24, y))
y += pc_old.height + 40
d.text((pad, y - 22), 'R153: 844 x 390 phone', font=font(13), fill=RED)
d.text((pad + ph_old.width + 24, y - 22), 'R154: 844 x 390 phone (fan %.2f x %.2f)' % tuple(phone['fan']), font=font(13), fill=GREEN)
sheet.paste(ph_old, (pad, y))
sheet.paste(ph_new, (pad + ph_old.width + 24, y))
y += ph_old.height + 40
if OWNER_POPUP:
    im = Image.open(OWNER_POPUP).convert('RGB')
    d.text((pad, y - 22), 'R153: the owner\'s screenshot (the small popup at the bottom right is just born: the pop-in; the half-faded one behind the cursor is in its fade, or was cut by the tier-1 cap)', font=font(13), fill=RED)
    sheet.paste(im, (pad, y))
    y += im.height + 40
# 3. one popup over its life -----------------------------------------------------------------------------------------------------------------------------------
y = heading(d, y, '3. ONE POPUP OVER ITS LIFE at ages 0, .05, .1, .2, .3, .4, .5, .6 s: the size is constant after the 0.28 s pop-in (0.45 -> 1.07 -> 1), only the last 0.15 s fades', 19, YELLOW, MAXW) + 26
cell_w, cell_h = 186, 84
for label, text_px, icon_px, col in (('R153 (text 44)', 44, 40, RED), ('R154 (text 35)', 35, 32, GREEN)):
    d.text((pad, y - 20), label, font=font(13), fill=col)
    for i, st in enumerate(pop['life']):
        x0 = pad + i * (cell_w + 6)
        d.rectangle((x0, y, x0 + cell_w, y + cell_h), fill=(70, 110, 150))
        dd = ImageDraw.Draw(sheet)
        draw_popup(dd, x0 + cell_w / 2, y + cell_h / 2, '+72K', text_px, icon_px, st['s'], st['a'], (70, 110, 150))
        d.text((x0 + 4, y + 3), '%.2f s  x%.2f' % (st['age'], st['s']), font=font(11), fill=(230, 235, 245))
    y += cell_h + 36
y += 6
# 4. lifetimes on tier 1 ---------------------------------------------------------------------------------------------------------------------------------------------
y = heading(d, y, '4. THE GLITCH: how long each popup lived on quality tier 1 (FastMode, a slow frame rate: Studio after a few slow seconds), 60 fps, 10 popups a second, first 18 popups', 19, YELLOW, MAXW) + 12
pb = life_panel(os.path.join(S, 'life_before.json'), W_ - 2 * pad, 'R153: the own cap on tier 1 was 4, below the 6-7 popups the stream keeps alive: every popup is cut at ~0.4 s and fades out in 0.08 s while flying', RED)
pa = life_panel(os.path.join(S, 'life_after.json'), W_ - 2 * pad, 'R154: own popups hold 8 on every tier: each popup lives its whole 0.65 s (pop, fling, hold, fade)', GREEN)
sheet.paste(pb, (pad, y))
y += pb.height + 14
sheet.paste(pa, (pad, y))
y += pa.height + 24
sheet = sheet.crop((0, 0, W_, y))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
