"""R156 preview: lays out docs/proposals/R156/pity_bars_v2.png from the scenes pity_scene156.luau drew (render_scenes156.py: one PNG per view x mode x scene).
Usage: python3 make_pity_v2_sheet156.py SCRATCH OUT.png   (run_pity_v2_preview156.sh calls it)
Also prints the numbers the write-up quotes (the gaps, the colour distances between the two bars, the text contrast), and draws the colour-blindness simulations.
APPROXIMATE: the bars, the notices, the reveal card and the SKIP pill are the real GUI trees on the Roblox mock, drawn by Chromium; the hotbar, name rows, tooltip, balances, status,
MENU, the touch controls and the BONUS ROLL button are stand-ins placed by HudLayout's metrics and PityBars155's own answers. Not a Studio screenshot."""
import colorsys
import math
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
subprocess.run([sys.executable, '-W', 'ignore', os.path.join(HERE, 'render_scenes156.py'), S], check=True)
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')


def font(px):
    try:
        return ImageFont.truetype(os.path.join(FONTS, 'fredoka-one-latin-400-normal.woff'), px)
    except Exception:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


# ---- what the scenes printed ------------------------------------------------------------------------------------------------------------------------
META, PLACE, BAND, TIP = {}, {}, {}, {}
for view in ('pc', 'land', 'port'):
    for mode in ('current', 'fresh', 'deep'):
        for line in open(os.path.join(S, '%s-%s' % (view, mode), 'scenes.log'), encoding='utf-8'):
            if line.startswith('SCENE '):
                p = line.split(' ', 7)
                META[(view, mode, p[1])] = tuple(int(v) for v in p[2:6]) + (float(p[6]),)
            m = re.match(r'PLACE \w+ \w+ bars (\d+)x(\d+) pair (\d+),(\d+) (\d+)x(\d+) .*gap to the slots (\d+) px \| name rows end (\d+) px', line)
            if m:
                v = [int(x) for x in m.groups()]
                PLACE[(view, mode)] = dict(barW=v[0], barH=v[1], X=v[2], Y=v[3], W=v[4], H=v[5], gap=v[6], row=v[7])
            m = re.match(r'CHECK pc (\w+) tooltip bottom edge (\d+) px above', line)
            if m:
                TIP[m.group(1)] = int(m.group(2))
            m = re.match(r'BAND \w+ \w+ dock (\d+),(\d+) (\d+)x(\d+) band (\d+),(\d+) (\d+)x(\d+)', line)
            if m:
                v = [int(x) for x in m.groups()]
                BAND[(view, mode)] = dict(dockX=v[0], dockY=v[1], dockW=v[2], dockH=v[3], bandX=v[4], bandY=v[5], bandW=v[6], bandH=v[7])


def load(view, mode, name, suffix=''):
    return Image.open(os.path.join(S, 'png', '%s-%s_%s%s.png' % (view, mode, name, suffix))).convert('RGB')


def layout_scale(view, mode, name, im):
    """pixels of the PNG per layout pixel"""
    return im.width / META[(view, mode, name)][2]


def show(im, per_layout_px, target_per_layout_px):
    f = target_per_layout_px / per_layout_px
    return im.resize((max(1, round(im.width * f)), max(1, round(im.height * f))), Image.LANCZOS)


def region(view, mode, name, x0, y0, x1, y1, target, suffix=''):
    """the layout rectangle x0,y0 .. x1,y1 of a scene, shown at `target` display pixels per layout pixel"""
    im = load(view, mode, name, suffix)
    k = layout_scale(view, mode, name, im)
    cx, cy = META[(view, mode, name)][:2]
    return show(im.crop([round((x0 - cx) * k), round((y0 - cy) * k), round((x1 - cx) * k), round((y1 - cy) * k)]), k, target)


def tight(view, mode, name, target, left=24, right=24, below=14, above=8, suffix=''):
    """the part of a scene around the bars and, above them, the name rows, down to `below` px under the slots' top"""
    p, b = PLACE[(view, mode)], BAND[(view, mode)]
    return region(view, mode, name, p['X'] - left, min(p['Y'], b['bandY'] if mode != 'current' else p['Y']) - above, p['X'] + p['W'] + right, b['dockY'] + below, target, suffix)


def pair_only(view, mode, name, target, suffix='', pad=6):
    """just the two bars"""
    p = PLACE[(view, mode)]
    return region(view, mode, name, p['X'] - pad, p['Y'] - pad, p['X'] + p['W'] + pad, p['Y'] + p['H'] + pad, target, suffix)


def gap_arrow(im, view, mode, x0, y0, target, color=(225, 29, 116)):
    """a dimension line (bar bottom -> slot top) with its number, right of the pair, on an image whose layout origin is x0,y0 shown at `target` px per layout px"""
    p, b = PLACE[(view, mode)], BAND[(view, mode)]
    d = ImageDraw.Draw(im)
    x = (p['X'] + p['W'] + 16 - x0) * target
    top, bottom = (p['Y'] + p['H'] - y0) * target, (b['dockY'] - y0) * target
    d.line([x, top, x, bottom], fill=color, width=2)
    d.line([x - 6, top, x + 6, top], fill=color, width=2)
    d.line([x - 6, bottom, x + 6, bottom], fill=color, width=2)
    d.text((x + 10, (p['Y'] + p['H'] / 2 - y0) * target - 12), '%d px' % p['gap'], font=font(20), fill=color, stroke_width=3, stroke_fill=(255, 255, 255))
    return im


# ---- colours: the palettes, the distances ----------------------------------------------------------------------------------------------------------
def palettes():
    out, shade = {}, None
    for line in open(os.path.join(S, 'v2', 'src', 'ReplicatedStorage', 'PackPity155.lua'), encoding='utf-8'):
        m = re.match(r'^ (Fresh|Deep)=\{', line)
        if m:
            shade = m.group(1)
        m = re.match(r'^  (Normal|Event)=\{(.*)\},', line)
        if m and shade:
            out[(shade, m.group(1))] = {k: tuple(int(x) for x in v.split(',')) for k, v in re.findall(r'(\w+)=RGB\((\d+,\d+,\d+)\)', m.group(2))}
    return out


PAL = palettes()


def to_lin(c):
    c = np.asarray(c, dtype=float) / 255
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def from_lin(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - .055) * 255


def lab(rgb):
    M = np.array([[.4124564, .3575761, .1804375], [.2126729, .7151522, .0721750], [.0193339, .1191920, .9503041]])
    xyz = to_lin(rgb) @ M.T / np.array([.95047, 1, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.array([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])])


def de2000(a, b):
    L1, a1, b1 = lab(a)
    L2, a2, b2 = lab(b)
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cm = (C1 + C2) / 2
    G = .5 * (1 - math.sqrt(Cm ** 7 / (Cm ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p, h2p = math.degrees(math.atan2(b1, a1p)) % 360, math.degrees(math.atan2(b2, a2p)) % 360
    dL, dC = L2 - L1, C2p - C1p
    dh = h2p - h1p
    if C1p * C2p == 0:
        dh = 0
    elif dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    dH = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh / 2))
    Lm, Cmp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0:
        hm = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hm = (h1p + h2p) / 2
    else:
        hm = (h1p + h2p + 360) / 2 if h1p + h2p < 360 else (h1p + h2p - 360) / 2
    T = 1 - .17 * math.cos(math.radians(hm - 30)) + .24 * math.cos(math.radians(2 * hm)) + .32 * math.cos(math.radians(3 * hm + 6)) - .2 * math.cos(math.radians(4 * hm - 63))
    SL = 1 + .015 * (Lm - 50) ** 2 / math.sqrt(20 + (Lm - 50) ** 2)
    SC, SH = 1 + .045 * Cmp, 1 + .015 * Cmp * T
    RT = -2 * math.sqrt(Cmp ** 7 / (Cmp ** 7 + 25 ** 7)) * math.sin(math.radians(60 * math.exp(-(((hm - 275) / 25) ** 2))))
    return math.sqrt((dL / SL) ** 2 + (dC / SC) ** 2 + (dH / SH) ** 2 + RT * (dC / SC) * (dH / SH))


# Machado, Oliveira, Fernandes (2009), severity 1.0, applied to linear RGB
CVD = {
    'deuteranopia (no green cones)': np.array([[.367322, .860646, -.227968], [.280085, .672501, .047413], [-.011820, .042940, .968881]]),
    'protanopia (no red cones)': np.array([[.152286, 1.052583, -.204868], [.114503, .786281, .099216], [-.003882, -.048116, 1.051998]]),
    'tritanopia (no blue cones)': np.array([[1.255528, -.076749, -.178779], [-.078411, .930809, .147602], [.004733, .691367, .303900]]),
}


def simulate(arr, kind):
    """arr: float RGB 0..255 (..., 3) -> the same colours as a colour-blind viewer sees them; kind None = unchanged, 'grey' = lightness only"""
    if kind is None:
        return np.asarray(arr, dtype=float)
    lin = to_lin(arr)
    if kind == 'grey':
        y = lin @ np.array([.2126, .7152, .0722])
        return from_lin(np.stack([y, y, y], axis=-1))
    return from_lin(lin @ CVD[kind].T)


def mid(c):
    return tuple((np.array(c['Light']) + np.array(c['Deep'])) / 2)


def contrast(a, b):
    ya, yb = to_lin(a) @ np.array([.2126, .7152, .0722]), to_lin(b) @ np.array([.2126, .7152, .0722])
    hi, lo = max(ya, yb), min(ya, yb)
    return (hi + .05) / (lo + .05)


def hue(c):
    r, g, b = (np.array(c) / 255)
    return colorsys.rgb_to_hsv(r, g, b)[0] * 360


NUM = {}
for shade in ('Fresh', 'Deep'):
    n, e = PAL[(shade, 'Normal')], PAL[(shade, 'Event')]
    row = {'fill': {}, 'track': {}, 'rim': {}}
    for kind in (None, 'grey') + tuple(CVD):
        row['fill'][kind] = de2000(simulate(mid(n), kind), simulate(mid(e), kind))
        row['track'][kind] = de2000(simulate(n['Track'], kind), simulate(e['Track'], kind))
        row['rim'][kind] = de2000(simulate(n['RimHot'], kind), simulate(e['RimHot'], kind))
    row['hue'] = (hue(mid(n)), hue(mid(e)))
    row['dL'] = abs(lab(mid(n))[0] - lab(mid(e))[0])
    row['text'] = {g: (contrast((255, 255, 255), PAL[(shade, g)]['Ink']), contrast(PAL[(shade, g)]['Ink'], PAL[(shade, g)]['Light']), contrast(PAL[(shade, g)]['Ink'], PAL[(shade, g)]['Deep'])) for g in ('Normal', 'Event')}
    NUM[shade] = row
    print('NUMBERS %s: fill hue %.0f vs %.0f deg, dL* %.0f; dE2000 of the fills: normal vision %.0f, greyscale %.0f, %s; tracks (normal vision) %.0f; held rims %.0f' % (
        shade, row['hue'][0], row['hue'][1], row['dL'], row['fill'][None], row['fill']['grey'], ', '.join('%s %.0f' % (k.split(' ')[0], row['fill'][k]) for k in CVD), row['track'][None], row['rim'][None]))
    print('NUMBERS %s: text contrast white vs outline: normal %.1f, event %.1f; outline vs fill light / deep: normal %.1f / %.1f, event %.1f / %.1f' % (
        shade, row['text']['Normal'][0], row['text']['Event'][0], row['text']['Normal'][1], row['text']['Normal'][2], row['text']['Event'][1], row['text']['Event'][2]))
for view in ('pc', 'land', 'port'):
    print('NUMBERS gap %s: R155 %d px -> proposal %d px (name rows %d px above the slots)' % (view, PLACE[(view, 'current')]['gap'], PLACE[(view, 'fresh')]['gap'], PLACE[(view, 'fresh')]['row']))


def swatch(im_draw, x, y, c, w=34, h=22):
    im_draw.rectangle([x, y, x + w, y + h], fill=tuple(int(v) for v in c), outline=(60, 64, 80))


# ---- the sheet -------------------------------------------------------------------------------------------------------------------------------------
INK, PAPER, MUTED, HOT = (24, 28, 44), (246, 247, 251), (92, 100, 124), (225, 29, 116)
W_, pad, gap = 1900, 24, 18
title_f, head_f, sub_f, cap_f, foot_f = font(34), font(25), font(18), font(16), font(15)
probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))


def wrap(text, f, width):
    lines, line = [], ''
    for w in text.split():
        t = (line + ' ' + w).strip()
        if probe.textlength(t, font=f) > width and line:
            lines.append(line)
            line = w
        else:
            line = t
    if line:
        lines.append(line)
    return lines


blocks = []  # (heading, subtitle, [rows]); a row = [(image, caption)]


def block(head, sub, rows):
    blocks.append((head, sub, rows))


T = 1.0  # display pixels per layout pixel for the big scenes
FR, DP = 'fresh', 'deep'

# 0. at a glance
block('The owner\'s pick at a glance (PC 1920 x 1080, a normal pack in hand: 9/10 on the normal bar, 3/10 on the event bar)',
      'NORMAL pity = clover green. EVENT pity = gold with a clover-green rim. Both carry the clover. Two shades of green to choose between: shade 1 "Fresh" (the picture\'s own lime / leaf green) and shade 2 "Deep" (an emerald).',
      [[(tight('pc', 'current', 'pc_held9', 1.15), 'R155 today: gold + purple, diamonds, the bars 50 px above the slots'),
        (tight('pc', FR, 'pc_held9', 1.15), 'OWNER\'S PICK, shade 1 "Fresh": 8 px above the slots, the clover, green + gold'),
        (tight('pc', DP, 'pc_held9', 1.15), 'Owner\'s pick, shade 2 "Deep": the same with an emerald green')]])

# 1. position
POS_Y0 = 868  # (the same screen rectangle for R155 and the proposal)
bd = BAND[('pc', 'current')]
px0, px1 = bd['dockX'] - 16, bd['dockX'] + bd['dockW'] + 16
rows = []
for name, ca, cb, arrow in (
        ('pc_33', 'R155 today: the bars end 50 px above the slots: a 6 px lift + the 44 px the held item\'s name and traits rows always reserve (Hotbar.client: SelectedName at -44, SelectedTraits at -18)',
         'Proposal: 8 px above the slots. The name and traits rows (empty now: nothing is held) are above the bars, so nothing sits between the bars and the slots', True),
        ('pc_held9', 'R155, a pack in hand: its name sits between the bars and the slots', 'Proposal, a pack in hand: the name drops into the empty traits row, right over the bars; the selected slot\'s ring and the held bar\'s rim fit in the 8 px', False),
        ('pc_name', 'R155, worst case: a held fruit with a name and a traits line', 'Proposal, the same: both rows are above the bars; the bars stay 8 px from the slots', False)):
    pair = []
    for mode, cap in (('current', ca), (FR, cb)):
        im = region('pc', mode, name, px0, POS_Y0, px1, 1080, .9)
        if arrow:
            gap_arrow(im, 'pc', mode, px0, POS_Y0, .9)
        pair.append((im, cap))
    rows.append(pair)
tip_y0 = 715
rows.append([(region('pc', 'current', 'pc_tip', px0 - 130, tip_y0, px1, 1080, .8), 'R155, hovering a pack (the event pack in hand, 9/10): the tooltip (ItemTooltip155; a stand-in drawn where its own rule puts it) sits above the bars'),
             (region('pc', FR, 'pc_tip', px0 - 130, tip_y0, px1, 1080, .8), 'Proposal: its rule is unchanged (above the highest of the bars and the name rows), so it sits above the name (%d px above the slots; R155 %d px: the bars + name stack is shorter now), over nothing' % (TIP['fresh'], TIP['current']))])
block('1. Position, PC 1920 x 1080 (the same px as the owner\'s 1405 px window): R155 today on the left, the proposal on the right; the pink line is the gap',
      'Why the bars sat high: they were placed above the held item\'s name and traits rows (44 px, always reserved, even with nothing held) plus a 6 px lift, so 50 px above the slots. To sit tight, those two rows move ABOVE the bars (Hotbar.client reads how far up from a PlayerGui attribute the bars write).', rows)

rows = []
rows.append([(region('land', 'current', 'land_held9', 0, 0, 844, 390, 1), 'Landscape phone 844 x 390, R155: the bars 50 px above the slots'),
             (region('land', FR, 'land_held9', 0, 0, 844, 390, 1), 'Proposal: 6 px above the slots; the item name above them; MENU, balances, status and jump are untouched')])
by = BAND[('port', 'current')]['dockY'] - 140
rows.append([(region('port', 'current', 'port_held9', 0, by, 390, 844, 1), 'Portrait phone 390 x 844, R155'),
             (region('port', FR, 'port_held9', 0, by, 390, 844, 1), 'Proposal: 6 px above the slots'),
             (region('port', FR, 'port_evheld', 0, by, 390, 844, 1), 'Proposal, the event pack in hand')])
block('1b. Position on phones (scaled: 6 px, 5 px on a thin 16 px bar; a PC\'s 8 px would be loose on a phone\'s small slot row)',
      'Gap from the bars\' bottom edge to the slots\' top: PC 1920 x 1080: 50 -> 8 px; landscape phone 844 x 390: 50 -> 6 px; portrait phone 390 x 844: 50 -> 6 px. The item name and traits rows end 35 px (PC) / 29 px (phones) above the slots, over the bars.', rows)

# 2. icon
clover = Image.open(os.path.join(S, 'clover.png')).convert('RGBA')
cv = Image.new('RGB', (150, 150), (86, 160, 76))
cv.paste(clover.resize((140, 140), Image.LANCZOS), (5, 5), clover.resize((140, 140), Image.LANCZOS))


def zp(mode, name):
    return pair_only('pc', mode, name, 1.45, pad=10)


block('2. The icon: the clover instead of the diamonds, at the left end of both bars',
      'Used: the game\'s own clover picture, decoded from CloverPassImage153 (the drawn copy of the uploaded image 121815230112848, 128 x 128; in game CloverIcon153 shows the uploaded asset first and falls back to this copy, then to the PremiumEmblems "Clover" shapes). It sits on a dark disc in the bar\'s rim colour so it still reads over the fill; the fill now starts after the disc, so 1/10 is visible.',
      [[(cv, 'CloverPassImage153, decoded'), (zp('current', 'pc_zoom_33'), 'R155: diamonds, 3/10 and 3/10'), (zp(FR, 'pc_zoom_33'), 'Proposal, shade 1: the clover, 3/10 and 3/10')],
       [(zp(FR, 'pc_zoom_99'), 'Shade 1, normal pack in hand, 9/10 and 9/10: the glow, the held bar\'s bright rim and 1.06x; the event bar a little dimmer'), (zp(DP, 'pc_zoom_33'), 'Shade 2 "Deep": 3/10 and 3/10')]])


# 3. the colours: the owner's pick in two shades
def HEX(c):
    return '#%02X%02X%02X' % tuple(c)


def shade_rows(mode):
    out = []
    for view, names, ts in (('pc', ('pc_33', 'pc_held9', 'pc_evheld'), 1.12), ('land', ('land_33', 'land_held9', 'land_evheld'), 1.5), ('port', ('port_33', 'port_held9', 'port_evheld'), 1.6)):
        label = {'pc': 'PC', 'land': 'landscape phone', 'port': 'portrait phone'}[view]
        caps = ('3/10 and 3/10', 'normal pack in hand, 9/10 (glow); event 3/10', 'event pack in hand, event 9/10 (glow); normal 3/10')
        out.append([(tight(view, mode, n, ts, below=12 if view != 'pc' else 18), '%s: %s' % (label, c)) for n, c in zip(names, caps)])
    return out


for shade, mode, title in (('Fresh', FR, 'Owner\'s pick, shade 1: "Fresh" (the clover picture\'s own lime / leaf green)'), ('Deep', DP, 'Owner\'s pick, shade 2: "Deep" (an emerald; the same gold)')):
    n, e = PAL[(shade, 'Normal')], PAL[(shade, 'Event')]
    block('3. Colours - ' + title, 'NORMAL fill %s -> %s, rim %s (held %s), track %s.  EVENT fill %s -> %s, clover-green rim %s (held %s), track %s.  Clover disc %s.' % (
        HEX(n['Light']), HEX(n['Deep']), HEX(n['Rim']), HEX(n['RimHot']), HEX(n['Track']), HEX(e['Light']), HEX(e['Deep']), HEX(e['Rim']), HEX(e['RimHot']), HEX(e['Track']), HEX(n['Badge'])),
          shade_rows(mode))

# 4. telling them apart
rows = []
for shade, mode in (('Fresh', FR), ('Deep', DP)):
    row = []
    for key, label in (('', 'grass (green on green, the hard case)'), ('_sand', 'desert sand'), ('_snow', 'snow'), ('_night', 'night')):
        row.append((pair_only('pc', mode, 'pc_zoom_99', .9, suffix=key, pad=8), '%s, %s' % ('shade 1' if shade == 'Fresh' else 'shade 2', label)))
    rows.append(row)
for shade, mode in (('Fresh', FR), ('Deep', DP)):
    base = np.asarray(pair_only('pc', mode, 'pc_zoom_33', .7, pad=6), dtype=float)
    row = []
    for kind, label in ((None, 'normal vision'), ('grey', 'lightness only'), ('deuteranopia (no green cones)', 'deuteranopia'), ('protanopia (no red cones)', 'protanopia'), ('tritanopia (no blue cones)', 'tritanopia')):
        sim = Image.fromarray(np.clip(simulate(base, kind), 0, 255).astype('uint8'))
        row.append((sim, '%s, %s: the fills are %.0f apart' % ('shade 1' if shade == 'Fresh' else 'shade 2', label, NUM[shade]['fill'][kind])))
    rows.append(row)
block('4. Both bars carry green: how they still tell apart at a glance',
      'Five cues, none of them only a hue: (1) the FILL: green vs gold, ~70-100 degrees of hue apart AND 27-33 L* apart (the gold is pale, the green leaf-dark), so a greyscale or colour-blind viewer still sees two bars; (2) the TRACK tint: green-black vs warm-black, so even an empty bar has a colour; (3) the RIM: the event bar\'s is the clover green, the normal bar\'s is the pale mint of its own fill; (4) the WORDS "pity" vs "event pity", and the order (normal on the left); (5) the bar that is not in hand dims less (.85, was .75), so a gold fill over grass does not turn olive. Below: both bars over grass, sand, snow and night, then the pair as colour-blind viewers see it with the distance between the fills (dE2000: 10 is obvious at a glance, 2 is invisible).',
      rows)


# 5. BONUS ROLL / SKIP
def whole(view, name, k):
    im = load(view, FR, name)
    return show(im, layout_scale(view, FR, name, im), k)


block('5. Still clear: the BONUS ROLL button and the SKIP pill (proposal, shade 1)',
      'Both ask the bars where they are (PityBars155.ButtonSpot / Reserved); Reserved now includes the name rows above the bars, so both stay clear of bars, name rows and slots on all three screens (the CHECK lines of the preview run). The BONUS ROLL button ends up 3-5 px lower than in R155 (the stack above the hotbar has the same height, in another order); the SKIP pill is 4 px lower on a phone; on a PC it moves from beside the hotbar to the corner above the status stack.',
      [[(whole('pc', 'pc_bonus', .6), 'PC: BONUS ROLL button above the name rows and the bars'), (whole('pc', 'pc_skip', .5), 'PC: an opening\'s SKIP pill (bottom right)')],
       [(whole('land', 'land_bonus', .62), 'Landscape: BONUS ROLL button'), (whole('land', 'land_skip', .62), 'Landscape: SKIP pill (in-place card)'),
        (whole('port', 'port_bonus', .6), 'Portrait: BONUS ROLL button'), (whole('port', 'port_skip', .6), 'Portrait: SKIP pill')]])

# 6. the lucky pop
block('6. The lucky pop in the new colours (0.42 s: full, flash, the shine across; PC)', 'The pop, the flash and the ring use the bar\'s own colours, so they follow the palette. The lucky notice and the reveal-card tag read "LUCKY EVENT PACK" with a gold star now (the purple heart no longer matches).',
      [[(pair_only('pc', FR, 'pc_pop_n', .93, pad=8), 'shade 1: a lucky normal pack'), (pair_only('pc', FR, 'pc_pop_e', .93, pad=8), 'shade 1: a lucky event pack'),
        (pair_only('pc', DP, 'pc_pop_n', .93, pad=8), 'shade 2: a lucky normal pack'), (pair_only('pc', DP, 'pc_pop_e', .93, pad=8), 'shade 2: a lucky event pack')]])

# ---- placing ----------------------------------------------------------------------------------------------------------------------------------------
y = pad + 78
placed = []
for head, sub, rows_ in blocks:
    head_lines, sub_lines = wrap(head, head_f, W_ - 2 * pad), wrap(sub, sub_f, W_ - 2 * pad)
    hy = y
    y += len(head_lines) * 32 + len(sub_lines) * 24 + 8
    items = []
    for row in rows_:
        x, row_h, rit = pad, 0, []
        for im, cap in row:
            if x + im.width > W_ - pad and x > pad:
                items += rit
                y += row_h + gap
                x, row_h, rit = pad, 0, []
            lines = wrap(cap, cap_f, max(im.width, 220))
            rit.append((x, y, im, lines))
            row_h = max(row_h, im.height + 6 + len(lines) * 20)
            x += max(im.width, 220) + gap
        items += rit
        y += row_h + gap
    placed.append((head_lines, sub_lines, hy, items))
    y += 20
FOOT = ('APPROXIMATE preview, not a Studio screenshot: the bars (PityBars155 with pity_bars_v2.patch applied to a scratch copy, src/ unchanged), the notices, the reveal card and the SKIP pill are the real GUI '
        'trees on the Roblox mock, drawn by headless Chromium (Fredoka One as the HUD font); the hotbar slots, the held item\'s name rows, the item tooltip, balances, status, MENU, the touch controls and the BONUS ROLL '
        'button are stand-ins placed by HudLayout\'s metrics and PityBars155\'s own answers; the sky is a plain gradient. The clover is the decoded CloverPassImage153.')
foot_lines = wrap(FOOT, foot_f, W_ - 2 * pad)
H_ = y + len(foot_lines) * 20 + pad
sheet = Image.new('RGB', (W_, H_), PAPER)
d = ImageDraw.Draw(sheet)
d.text((pad, pad), 'R156 preview: the pity bars, closer to the hotbar, with the clover, in clover green and gold', font=title_f, fill=INK)
d.text((pad, pad + 44), 'Owner\'s pick: NORMAL pity = clover green, EVENT pity = gold + green.  One picture, the real R155 bars on the left of every pair for comparison.', font=sub_f, fill=MUTED)
for head_lines, sub_lines, hy, items in placed:
    for i, l in enumerate(head_lines):
        d.text((pad, hy + i * 32), l, font=head_f, fill=INK)
    for i, l in enumerate(sub_lines):
        d.text((pad, hy + len(head_lines) * 32 + i * 24), l, font=sub_f, fill=MUTED)
    for x, y0, im, lines in items:
        sheet.paste(im, (x, y0))
        d.rectangle([x - 1, y0 - 1, x + im.width, y0 + im.height], outline=(200, 204, 216))
        for i, l in enumerate(lines):
            d.text((x, y0 + im.height + 6 + i * 20), l, font=cap_f, fill=MUTED)
for i, l in enumerate(foot_lines):
    d.text((pad, y + i * 20), l, font=foot_f, fill=MUTED)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
