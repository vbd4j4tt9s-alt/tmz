"""R155 preview sheet: docs/proposals/R155/popups_zoom.png = the speed popups over a runner at four camera distances (12.5 studs = the default zoom, 25 = 2x, 50 = 4x, 4 = close-up), R154 vs R155
side by side, and the on-screen text size against the camera distance.
Usage: python3 compose_zoom155.py <scratch dir with zoom_before.txt, zoom_after.txt> <out png>
Inputs (written by run_zoom_preview155.sh): the "ZOOM {...}" lines of zoom_scene155.luau for the R154 client and for this checkout's (every showing popup of the REAL client's tree after a 2 s
stream, plus its zoom container's scale / visibility) and the "CURVE" line of this checkout's SpeedPopupStyle.ZoomScale.
APPROXIMATE: drawn with Pillow from the Roblox mock's tree, DejaVu Sans Bold stands in for Fredoka, a block runner at the size a 70 degree camera gives it. Not a Studio screenshot."""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
GREEN, RED, YELLOW, GREY = (150, 255, 110), (255, 130, 130), (255, 226, 96), (205, 215, 240)
SKY, GROUND = (112, 166, 214), (84, 132, 84)
DESIGN_W, DESIGN_H = 1920, 1080
K = 0.4167                      # panel scale: 800 x 450 for the 1920 x 1080 design screen
PW_, PH_ = int(DESIGN_W * K), int(DESIGN_H * K)
HEAD_Y = 0.36                   # SpeedPopupStyle.Fan.HeadY: where the head is on the screen
PX_PER_STUD_AT_1 = (DESIGN_H / 2) / math.tan(math.radians(35))   # 70 degree vertical field of view: px per stud at 1 stud away


def font(px):
    return ImageFont.truetype(BOLD, max(6, int(round(px))))


def load(name):
    zooms, curve = {}, None
    for line in open(os.path.join(S, name), encoding='utf-8'):
        kind, _, body = line.partition(' ')
        if kind == 'ZOOM':
            z = json.loads(body)
            zooms[z['d']] = z
        elif kind == 'CURVE':
            curve = json.loads(body)
    return zooms, curve


def mix(c, bg, a):
    return tuple(int(bg[i] + (c[i] - bg[i]) * a) for i in range(3))


def bolt(d, cx, cy, h, fill, outline):
    w = h * .55
    pts = [(cx + w * .15, cy - h / 2), (cx - w * .5, cy + h * .08), (cx - w * .02, cy + h * .08), (cx - w * .2, cy + h / 2), (cx + w * .5, cy - h * .12), (cx + w * .04, cy - h * .12)]
    d.polygon(pts, fill=fill, outline=outline)


def draw_popup(d, cx, cy, text, text_px, icon_px, s, alpha, bg):
    tp, ip = text_px * s * K, icon_px * s * K
    fnt = font(tp)
    tw = d.textlength(text, font=fnt)
    iw = ip * .6
    total = iw + 3 * s * K + tw
    x0 = cx - total / 2
    bolt(d, x0 + iw / 2, cy, ip, mix((255, 222, 66), bg, alpha), mix((17, 26, 42), bg, alpha))
    d.text((x0 + iw + 3 * s * K, cy), text, font=fnt, fill=mix((125, 248, 255), bg, alpha), anchor='lm', stroke_width=max(1, int(tp * .11)), stroke_fill=mix((17, 26, 42), bg, alpha))


def box(d, x0, y0, x1, y1, fill):
    """A rectangle clipped to the panel (a close-up runner is taller than the screen)."""
    x0, x1, y0, y1 = max(-4, x0), min(PW_ + 4, x1), max(-4, y0), min(PH_ + 4, y1)
    if x1 >= x0 and y1 >= y0:
        d.rectangle((x0, y0, x1, y1), fill=fill)


def panel(z, label_color, build):
    """One panel: the runner at z['d'] studs and the popups of the build's tree."""
    img = Image.new('RGB', (PW_, PH_), SKY)
    d = ImageDraw.Draw(img)
    pps = PX_PER_STUD_AT_1 / z['d'] * K          # panel px per stud at this distance
    hx, hy = PW_ / 2, PH_ * HEAD_Y
    feet = hy + 4.6 * pps
    box(d, 0, feet, PW_, PH_, GROUND)
    box(d, hx - 3.2 * pps, feet, hx + 3.2 * pps, feet + .7 * pps, (58, 62, 78))          # the treadmill
    box(d, hx - 1.0 * pps, hy + 2.6 * pps, hx - 0.05 * pps, feet, (60, 80, 120))          # legs
    box(d, hx + 0.05 * pps, hy + 2.6 * pps, hx + 1.0 * pps, feet, (60, 80, 120))
    box(d, hx - 1.0 * pps, hy + 0.6 * pps, hx + 1.0 * pps, hy + 2.6 * pps, (214, 90, 80))  # torso
    box(d, hx - 2.0 * pps, hy + 0.6 * pps, hx - 1.0 * pps, hy + 2.6 * pps, (255, 214, 170))  # arms
    box(d, hx + 1.0 * pps, hy + 0.6 * pps, hx + 2.0 * pps, hy + 2.6 * pps, (255, 214, 170))
    d.ellipse((hx - .65 * pps, hy - .65 * pps, hx + .65 * pps, hy + .65 * pps), fill=(255, 214, 170))  # head, centred on the field's anchor
    zs, shown, unit = z['zs'], z['shown'], z['unit']
    if not shown:
        zs = min(1.3, 12.5 / z['d'])      # (a hidden container keeps its last written scale: what it would be at this distance)
    text_px = z['text'] * unit * zs
    if shown:
        for p in sorted(z['pops'], key=lambda p: p['z']):
            draw_popup(d, hx + p['x'] * zs * K, hy + p['y'] * zs * K, p['text'], z['text'], z['icon'], p['s'] * zs, p['a'], SKY)
    note = '%s: container x%.3f, text %.1f px at 1080 p' % (build, zs, text_px)
    if not shown:
        note = '%s: container x%.3f, HIDDEN (the text would be %.1f px)' % (build, zs, text_px)
        d.text((hx, hy - 1.2 * pps - 8), 'hidden', font=font(14), fill=(255, 255, 255), anchor='mm')
    d.rectangle((0, 0, PW_ - 1, PH_ - 1), outline=(18, 26, 40), width=2)
    d.rectangle((0, 0, PW_, 22), fill=(18, 26, 40))
    d.text((8, 11), note, font=font(13), fill=label_color, anchor='lm')
    return img


def chart(curve, width, height):
    img = Image.new('RGB', (width, height), (24, 32, 50))
    d = ImageDraw.Draw(img)
    left, right, top, bottom = 70, width - 30, 40, height - 46
    xmax, ymax = 60.0, 50.0

    def X(v):
        return left + (right - left) * v / xmax

    def Y(v):
        return bottom - (bottom - top) * v / ymax

    fade_at, hide_at = 12.5 * 35 / 14, 12.5 * 35 / 12
    d.rectangle((X(fade_at), top, X(hide_at), bottom), fill=(70, 62, 30))
    d.rectangle((X(hide_at), top, right, bottom), fill=(40, 40, 48))
    d.text((X(hide_at) + 8, top + 8), 'R155: hidden past %.2f studs (text 12 px)' % hide_at, font=font(13), fill=GREY)
    d.text((X(fade_at) - 4, top - 18), 'fade %.2f .. %.2f studs' % (fade_at, hide_at), font=font(12), fill=YELLOW, anchor='ls')
    for v in range(0, 51, 10):
        d.line((left, Y(v), right, Y(v)), fill=(52, 62, 84))
        d.text((left - 8, Y(v)), str(v), font=font(12), fill=GREY, anchor='rm')
    for v in range(0, 61, 10):
        d.line((X(v), top, X(v), bottom), fill=(52, 62, 84))
        d.text((X(v), bottom + 6), str(v), font=font(12), fill=GREY, anchor='mt')
    d.text((left, bottom + 26), 'camera distance to the runner, studs', font=font(12), fill=GREY)
    d.text((8, top - 18), 'popup text, px at 1080 p', font=font(12), fill=GREY, anchor='ls')
    # the runner, scaled so that it is 35 at the default zoom: what "same size relative to the character" looks like
    pts = [(X(dd), Y(35 * 12.5 / dd)) for dd in [x / 2 for x in range(10, 121)] if 35 * 12.5 / dd <= ymax]
    for a, b in zip(pts[::2], pts[1::2]):
        d.line((a, b), fill=(150, 160, 190), width=2)
    d.line((X(0), Y(35), X(xmax), Y(35)), fill=RED, width=3)
    pts = [(X(p[0]), Y(35 * p[1])) for p in curve['pts'] if p[0] > 0 and p[2] > 0]
    d.line(pts, fill=GREEN, width=4)
    for dist, tag in ((4, 'close-up 4: capped 45.5'), (12.5, 'default zoom 12.5: 35'), (25, '2x: 17.5'), (50, '4x: hidden')):
        s = min(1.3, 12.5 / dist)
        if dist < 36.5:
            d.ellipse((X(dist) - 5, Y(35 * s) - 5, X(dist) + 5, Y(35 * s) + 5), fill=GREEN, outline=(255, 255, 255))
            d.text((X(dist) + 9, Y(35 * s) + (6 if dist < 5 else -12)), tag, font=font(12), fill=GREEN)
        else:
            d.text((X(dist), Y(2)), tag, font=font(12), fill=GREY, anchor='mb')
    d.text((right - 4, Y(35) - 8), 'R154: 35 px at every distance (the runner shrinks, the numbers do not)', font=font(13), fill=RED, anchor='rb')
    d.text((right - 4, Y(35) + 36), 'R155: follows the runner (dashed grey), capped at 1.3x close up, gone past the cutoff', font=font(13), fill=GREEN, anchor='rt')
    return img


before, _ = load('zoom_before.txt')
after, curve = load('zoom_after.txt')
pad = 28
W_ = pad * 3 + 2 * PW_
sheet = Image.new('RGB', (W_, 3000), (12, 16, 28))
d = ImageDraw.Draw(sheet)
y = 20
d.text((pad, y), 'R155: the speed popups are objects in the world - they follow the zoom', font=font(28), fill=YELLOW)
y += 42
for line in ('APPROXIMATE: the popups are read off the tree of the REAL SpeedGainPopup client (R154 release vs this checkout) on the Roblox mock after a 2 s stream; the runner is a block figure at the size a',
             '70 degree camera gives it; DejaVu stands in for Fredoka. 1080 p design screen shown at 0.42x. Not a Studio screenshot.'):
    d.text((pad, y), line, font=font(14), fill=GREY)
    y += 20
y += 14
rows = ((12.5, 'DEFAULT ZOOM, 12.5 studs: exactly what R154 drew'), (25, '2x THE DISTANCE, 25 studs: half the size, like the runner'),
        (50, '4x THE DISTANCE, 50 studs: a quarter - past the cutoff, hidden (R154 still draws 35 px numbers on a runner this small)'), (4, 'CLOSE-UP, 4 studs: capped at 1.3x (a giant popup never covers the screen)'))
for dist, title in rows:
    d.text((pad, y), title, font=font(18), fill=YELLOW)
    y += 30
    sheet.paste(panel(before[dist], RED, 'R154'), (pad, y))
    sheet.paste(panel(after[dist], GREEN, 'R155'), (pad * 2 + PW_, y))
    y += PH_ + 22
d.text((pad, y), 'THE NUMBERS: popup text size against the camera distance (35 px text at 1080 p, the field scales with 12.5 / distance)', font=font(18), fill=YELLOW)
y += 30
c = chart(curve, W_ - 2 * pad, 330)
sheet.paste(c, (pad, y))
y += c.height + 24
sheet = sheet.crop((0, 0, W_, y))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
