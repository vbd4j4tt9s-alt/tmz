"""R158 preview sheet: docs/proposals/R158/speed_popups158.png = the treadmill speed popups before (35 px text on a computer) and after (53 px: 1.5x), over a runner, on a computer at the default
camera distance, zoomed out and zoomed right in (the zoom rule is unchanged), and on phones (landscape and portrait, with the HUD boxes of the real HudLayout).
Usage: python3 compose_popups158.py <scratch dir with shots_before.txt, shots_after.txt> <out png>
Inputs (written by run_popups_preview158.sh): the "SHOT {...}" lines of popups_scene158.luau for the build this round started from and for this checkout's: every showing popup of the REAL
SpeedGainPopup client's tree after a 2 s stream of "+60" popups, the field's zoom scale, the unit of the screen (with the size share of a small phone) and the real HudLayout boxes.
APPROXIMATE: drawn with Pillow from the Roblox mock's tree, DejaVu Sans Bold stands in for Fredoka, a block runner at the size a 70 degree camera gives it (a head 1.2 studs wide). Not a Studio screenshot."""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
REG = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
GREEN, RED, YELLOW, GREY = (150, 255, 110), (255, 130, 130), (255, 226, 96), (205, 215, 240)
SKY, GROUND = (112, 166, 214), (84, 132, 84)
HEAD_Y = 0.36


def font(px, bold=True):
    return ImageFont.truetype(BOLD if bold else REG, max(6, int(round(px))))


def load(name):
    shots = {}
    for line in open(os.path.join(S, name), encoding='utf-8'):
        kind, _, body = line.partition(' ')
        if kind == 'SHOT':
            z = json.loads(body)
            shots[z['name']] = z
    return shots


def mix(c, bg, a):
    return tuple(int(bg[i] + (c[i] - bg[i]) * a) for i in range(3))


def unit_of(h):
    return min(1.35, max(0.8, h / 1080))


def bolt(d, cx, cy, h, fill, outline, width):
    w = h * .55
    pts = [(cx + w * .15, cy - h / 2), (cx - w * .5, cy + h * .08), (cx - w * .02, cy + h * .08), (cx - w * .2, cy + h / 2), (cx + w * .5, cy - h * .12), (cx + w * .04, cy - h * .12)]
    d.polygon(pts, fill=fill, outline=outline, width=max(1, int(width)))


def draw_popup(d, cx, cy, text, text_px, icon_px, stroke_px, alpha, bg):
    fnt = font(text_px)
    tw = d.textlength(text, font=fnt)
    iw = icon_px * .6
    gap = text_px * .09
    total = iw + gap + tw
    x0 = cx - total / 2
    bolt(d, x0 + iw / 2, cy, icon_px, mix((255, 222, 66), bg, alpha), mix((17, 26, 42), bg, alpha), stroke_px)
    d.text((x0 + iw + gap, cy), text, font=fnt, fill=mix((125, 248, 255), bg, alpha), anchor='lm', stroke_width=max(1, int(round(stroke_px))), stroke_fill=mix((17, 26, 42), bg, alpha))


def rect(d, x0, y0, x1, y1, fill):
    """A rectangle clipped to the panel (a close-up runner is taller than the screen)."""
    iw, ih = d._image.size
    x0, y0, x1, y1 = max(-4, x0), max(-4, y0), min(iw + 4, x1), min(ih + 4, y1)
    if x1 >= x0 and y1 >= y0:
        d.rectangle((x0, y0, x1, y1), fill=fill)


HUD_SHORT = {'Hub': 'MENU', 'Hotbar': 'hotbar', 'WalletSpeed': 'speed', 'WalletCash': 'cash', 'WalletGem': 'gems', 'Status': 'status', 'ThumbL': '', 'ThumbR': '', 'Jump': 'jump'}


def panel(z, K, label, label_color, hud=True):
    w, h = int(z['w'] * K), int(z['h'] * K)
    img = Image.new('RGB', (w, h), SKY)
    d = ImageDraw.Draw(img)
    pps = (z['h'] / 2) / math.tan(math.radians(35)) / z['d'] * K      # panel px per stud (a 70 degree camera)
    hx, hy = z['head'][0] * K, z['head'][1] * K
    feet = hy + 4.6 * pps
    rect(d, 0, feet, w, h, GROUND)
    rect(d, hx - 3.2 * pps, feet, hx + 3.2 * pps, feet + .7 * pps, (58, 62, 78))                 # the treadmill
    rect(d, hx - 1.0 * pps, hy + 2.6 * pps, hx - 0.05 * pps, feet, (60, 80, 120))                 # legs
    rect(d, hx + 0.05 * pps, hy + 2.6 * pps, hx + 1.0 * pps, feet, (60, 80, 120))
    rect(d, hx - 1.0 * pps, hy + 0.6 * pps, hx + 1.0 * pps, hy + 2.6 * pps, (214, 90, 80))        # torso
    rect(d, hx - 2.0 * pps, hy + 0.6 * pps, hx - 1.0 * pps, hy + 2.6 * pps, (255, 214, 170))      # arms
    rect(d, hx + 1.0 * pps, hy + 0.6 * pps, hx + 2.0 * pps, hy + 2.6 * pps, (255, 214, 170))
    d.rectangle((hx - .6 * pps, hy - .6 * pps, hx + .6 * pps, hy + .6 * pps), fill=(255, 214, 170))  # the head box (1.2 studs), centred on the field's anchor
    zs = z['zs']
    text_px = z['text'] * z['unit'] * zs
    if z['shown']:
        for p in sorted(z['pops'], key=lambda p: p['z']):
            sc = p['s'] * zs * K
            draw_popup(d, hx + p['x'] * zs * K, hy + p['y'] * zs * K, p['text'], z['text'] * sc, z['icon'] * sc, z['stroke'] * sc, p['a'], SKY)
    else:
        d.text((hx, hy - 1.2 * pps - 8), 'hidden', font=font(14), fill=(255, 255, 255), anchor='mm')
    if hud and z['hud']:
        ov = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        for b in z['hud']:
            name = b['n']
            if name.startswith('Thumb'):
                continue
            x0, y0, x1, y1 = b['x'] * K, b['y'] * K, (b['x'] + b['w']) * K, (b['y'] + b['h']) * K
            od.rectangle((x0, y0, x1, y1), fill=(20, 26, 44, 150), outline=(255, 255, 255, 170))
            short = HUD_SHORT.get(name, name)
            if short and (x1 - x0) > 26 and (y1 - y0) > 10:
                od.text(((x0 + x1) / 2, (y0 + y1) / 2), short, font=font(min(11, (y1 - y0) * .6), False), fill=(255, 255, 255, 220), anchor='mm')
        img = Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB')
        d = ImageDraw.Draw(img)
    d.rectangle((0, 0, w - 1, h - 1), outline=(18, 26, 40), width=2)
    bar = 20
    d.rectangle((0, 0, w, bar), fill=(18, 26, 40))
    note = '%s: text %.1f px' % (label, text_px)
    if z['d'] != 12.5:
        note += ', camera %.1f studs' % z['d']
    d.text((6, bar / 2), note, font=font(12), fill=label_color, anchor='lm')
    return img


before = load('shots_before.txt')
after = load('shots_after.txt')
pad = 28
W_ = 1760
sheet = Image.new('RGB', (W_, 4200), (12, 16, 28))
d = ImageDraw.Draw(sheet)
y = 20
d.text((pad, y), 'R158: the speed popups are 1.5x bigger', font=font(30), fill=YELLOW)
y += 46
for line in ('APPROXIMATE: the popups are read off the tree of the REAL SpeedGainPopup client (the build this round started from vs this checkout) on the Roblox mock after a 2 s stream of "+60" popups; the runner',
             'is a block figure at the size a 70 degree camera gives it, DejaVu stands in for Fredoka, the boxes on the phones are the real HudLayout (the popups are drawn under the HUD in the game). Not a Studio screenshot.'):
    d.text((pad, y), line, font=font(14, False), fill=GREY)
    y += 20
y += 12


def row(name, title, K, note=None, hud=True):
    global y
    b, a = before[name], after[name]
    d.text((pad, y), title, font=font(19), fill=YELLOW)
    y += 30
    pb = panel(b, K, 'BEFORE', RED, hud)
    pa = panel(a, K, 'AFTER', GREEN, hud)
    sheet.paste(pb, (pad, y))
    sheet.paste(pa, (pad * 2 + pb.width, y))
    if note:
        d.text((pad * 3 + pb.width * 2, y + 4), note, font=font(14, False), fill=GREY)
    y += max(pb.height, pa.height) + 22
    return pb.width


def four(names, title, Ks):
    global y
    d.text((pad, y), title, font=font(19), fill=YELLOW)
    y += 30
    x = pad
    hmax = 0
    for name, K in zip(names, Ks):
        for shots, lab, col in ((before, 'BEFORE', RED), (after, 'AFTER', GREEN)):
            p = panel(shots[name], K, lab, col, True)
            sheet.paste(p, (x, y))
            x += p.width + 14
            hmax = max(hmax, p.height)
        x += 24
    y += hmax + 22


row('pc', 'A COMPUTER, 1920 x 1080, default camera (12.5 studs): text 35 -> 53 px, bolt 32 -> 48, outline 4 -> 6 (1.5x; the fan too)', .4167)
row('pc_far', 'ZOOMED OUT, 25 studs: half the size, like the runner (same zoom rule: fade from 31 studs, gone past 36.5)', .4167)
row('pc_near', 'ZOOMED RIGHT IN, 4 studs: capped at 1.3x, as before', .4167)
row('land', 'A LANDSCAPE PHONE, 844 x 390: 28 -> 36.9 px (1.32x: little room above the head, so a bit under 1.5x)', .9)
row('land_big', 'A BIG LANDSCAPE PHONE, 932 x 430: 28 -> 41.1 px (1.47x)', .82)
row('small', 'A SMALL LANDSCAPE PHONE, 568 x 320: no room, so the same size as before (28 px)', 1.3)
four(['port', 'port_se'], 'PORTRAIT PHONES: 390 x 844 (28 -> 32.4 px, 1.16x) and 375 x 667 (no room: same size)', [.55, .6])

# the numbers
d.text((pad, y), 'THE NUMBERS: popup text on the screen at the default camera (design 1080 p: 35 px before, 53 px after; a phone has the 0.8 floor and a size share)', font=font(17), fill=YELLOW)
y += 30
cols = [('screen', 0), ('text before', 230), ('text after', 400), ('times', 560), ('size share', 660)]
for t, x in cols:
    d.text((pad + x, y), t, font=font(14), fill=GREY)
y += 24
for name, label in (('pc', '1920 x 1080 (computer)'), ('land', '844 x 390 (phone, landscape)'), ('land_big', '932 x 430 (phone, landscape)'), ('small', '568 x 320 (phone, landscape)'),
                    ('port', '390 x 844 (phone, portrait)'), ('port_se', '375 x 667 (phone, portrait)')):
    b, a = before[name], after[name]
    tb, ta = b['text'] * b['unit'], a['text'] * a['unit']
    share = a['unit'] / unit_of(a['h'])
    vals = [label, '%.1f px' % tb, '%.1f px' % ta, '%.2fx' % (ta / tb), '%.2f' % share]
    for (t, x), v in zip(cols, vals):
        d.text((pad + x, y), v, font=font(14, False), fill=(235, 240, 255))
    y += 22
y += 20
sheet = sheet.crop((0, 0, W_, y))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
