"""R156 preview: the SCENE / INFO lines of menu_wheel_scene156.luau (one log per variant and view) -> PNGs with headless Chromium (R155's render_gui155.mjs) -> the sheet
docs/proposals/R156/menu_wheel_daily.png. Usage: python3 make_menu_wheel_sheet156.py SCRATCH OUT.png   (run_menu_wheel156.sh calls it)
APPROXIMATE: the wheel, SETTINGS / INDEX / SHOP / DAILY / INVITE, the badges, BASE / TRACK and the pity bars are the real GUI trees on the Roblox mock, drawn by Chromium (Fredoka One
when the font package is there); the hotbar, balances, status card, jump button / stick and Roblox's own top bar buttons are stand-ins placed by HudLayout's metrics; the sky is a plain
gradient. Not a Studio screenshot."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
SKY = 'linear-gradient(180deg,#7fc3ee 0%,#c4e6fa 44%,#86c46a 45%,#4f9a4a 100%)'
VIEWS = ('pc', 'land', 'port', 'tiny')
TB = {'pc': 52, 'land': 44, 'port': 44, 'tiny': 44}
HUD = {'pc': (1920, 1080), 'land': (844, 390), 'port': (390, 844), 'tiny': (750, 311)}

# ---- read the logs ----------------------------------------------------------------------------------------------------------------------------------------------
scene_json, info = {}, {}
for variant in ('current', 'proposed'):
    for view in VIEWS:
        info[(variant, view)] = {}
        for line in open(os.path.join(S, variant, view, 'scene.log'), encoding='utf-8'):
            if line.startswith('SCENE '):
                parts = line.rstrip('\n').split(' ', 7)
                scene_json[(variant, view, parts[1])] = parts[7]
            elif line.startswith('INFO '):
                parts = line.rstrip('\n').split(' ', 3)
                info[(variant, view)][parts[2]] = parts[3] if len(parts) > 3 else ''


def rect(variant, view, name):
    v = info[(variant, view)].get('rect.' + name)
    return tuple(int(t) for t in v.split()) if v else None


def num(variant, view, key):
    return float(info[(variant, view)][key].split(',')[0])


def up(view):  # px the MENU button moved up (proposed vs this checkout)
    return round(-num('proposed', view, 'menuShiftY') + num('current', view, 'menuShiftY'))


def radii(view):  # (up, down, arc width) of the proposed wheel
    p = info[('proposed', view)]
    return round(float(p['radius'])), round(float(p['offset5'].split(',')[1])), round(float(p['radiusX']))


# ---- what to render ---------------------------------------------------------------------------------------------------------------------------------------------
jobs = []


def job(name, variant, view, state, crop=None, scale=1.0):
    w, h = HUD[view][0], HUD[view][1] + TB[view]
    jobs.append({'name': name, 'json': scene_json[(variant, view, state)], 'scale': scale, 'bg': SKY, 'crop': crop or [0, 0, w, h]})


for variant in ('current', 'proposed'):
    for view in VIEWS:
        for state in ('closed', 'open'):
            job('%s_%s_%s' % (variant, view, state), variant, view, state)


def box_union(rects, pad):
    x0 = min(r[0] for r in rects) - pad
    y0 = min(r[1] for r in rects) - pad
    x1 = max(r[0] + r[2] for r in rects) + pad
    y1 = max(r[1] + r[3] for r in rects) + pad
    return [max(0, x0), max(0, y0), x1 - max(0, x0), y1 - max(0, y0)]


# PC: the wheel's zone at 1x (the same box for all three states), the top row strip
pc_opts = [rect('proposed', 'pc', 'opt%d' % i) for i in range(1, 6)] + [rect('proposed', 'pc', 'hub')]
WHEEL_BOX = box_union(pc_opts, 22)
WHEEL_BOX[2] = max(WHEEL_BOX[2], 300)
for variant, state in (('current', 'open'), ('proposed', 'open'), ('proposed', 'closed')):
    job('zoom_pc_%s_%s' % (variant, state), variant, 'pc', state, WHEEL_BOX, 1.0)
pc_pair = rect('current', 'pc', 'pair')
pc_inv = rect('current', 'pc', 'topInvite')
STRIP = [pc_pair[0] - 12, 0, (pc_inv[0] + pc_inv[2] + 12) - (pc_pair[0] - 12), TB['pc']]
for variant in ('current', 'proposed'):
    job('strip_pc_%s' % variant, variant, 'pc', 'closed', STRIP, 1.0)
# the badge at 4x (portrait phone): R155's DAILY button in the top row, the DAILY option in the wheel, the INDEX option (the badge DAILY now matches)
top_daily = rect('current', 'port', 'topDaily')
job('badge_cur_daily', 'current', 'port', 'open', [top_daily[0] - 14, 0, top_daily[2] + 34, top_daily[1] + top_daily[3] + 12], 4.0)
o4, o2 = rect('proposed', 'port', 'opt4'), rect('proposed', 'port', 'opt2')
job('badge_prop_daily', 'proposed', 'port', 'open', [o4[0] - 18, o4[1] - 44, o4[2] + 40, o4[3] + 58], 4.0)
job('badge_prop_index', 'proposed', 'port', 'open', [o2[0] - 18, o2[1] - 22, o2[2] + 40, o2[3] + 38], 4.0)

os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(jobs, f)
subprocess.run(['node', os.path.join(REPO, 'docs/proposals/R155/preview/render_gui155.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)


def png(name, width=None):
    im = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')
    if width and im.width != width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    return im


# ---- drawing helpers --------------------------------------------------------------------------------------------------------------------------------------------
INK, PAPER, MUTED = (24, 28, 44), (246, 247, 251), (92, 100, 124)
YELLOW, ORANGE, GREEN, GREY, RED = (255, 214, 0), (255, 140, 20), (20, 150, 70), (235, 235, 245), (210, 40, 60)


def font(px, bold=True):
    for p in (os.path.join(FONTS, 'fredoka-one-latin-400-normal.woff'),) if bold and px >= 30 else ():
        try:
            return ImageFont.truetype(p, px)
        except Exception:
            pass
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)


def wrap(draw, text, fnt, width):
    lines, line = [], ''
    for word in text.split(' '):
        trial = (line + ' ' + word).strip()
        if draw.textlength(trial, font=fnt) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def outline(im, r, crop, scale, color, width=3, dash=False, pad=3):
    """Outline the canvas rect r on image im (a crop (x, y) of the canvas, drawn at `scale`)."""
    d = ImageDraw.Draw(im)
    x0, y0 = (r[0] - crop[0]) * scale - pad, (r[1] - crop[1]) * scale - pad
    x1, y1 = (r[0] + r[2] - crop[0]) * scale + pad, (r[1] + r[3] - crop[1]) * scale + pad
    if not dash:
        d.rounded_rectangle([x0, y0, x1, y1], radius=8 * scale, outline=color, width=width)
        return
    step = 9
    for x in range(int(x0), int(x1), step * 2):
        d.line([x, y0, min(x + step, x1), y0], fill=color, width=width)
        d.line([x, y1, min(x + step, x1), y1], fill=color, width=width)
    for y in range(int(y0), int(y1), step * 2):
        d.line([x0, y, x0, min(y + step, y1)], fill=color, width=width)
        d.line([x1, y, x1, min(y + step, y1)], fill=color, width=width)


def tag(im, xy, text, fill, ink=INK, size=15):
    d = ImageDraw.Draw(im)
    f = font(size)
    lines = text.split('\n')
    w = max(d.textlength(t, font=f) for t in lines)
    h = len(lines) * (size + 4) + 6
    d.rounded_rectangle([xy[0], xy[1], xy[0] + w + 14, xy[1] + h], radius=9, fill=fill, outline=(20, 20, 30), width=2)
    for i, t in enumerate(lines):
        d.text((xy[0] + 7, xy[1] + 4 + i * (size + 4)), t, font=f, fill=ink)


def frame(im):
    out = Image.new('RGB', (im.width + 4, im.height + 4), (60, 66, 90))
    out.paste(im, (2, 2))
    return out


def shot(variant, view, state, scale=1.0, marks=True):
    """The whole screen of a variant / state at `scale`, with the outlines of the sheet."""
    im = png('%s_%s_%s' % (variant, view, state)).copy()
    crop = (0, 0)
    if marks:
        if variant == 'current':
            if state == 'open':
                for n in ('topDaily', 'topInvite'):
                    outline(im, rect('current', view, n), crop, 1, YELLOW, 3)
            else:
                outline(im, rect('current', view, 'topDaily'), crop, 1, ORANGE, 3)
        else:
            if state == 'open':
                for n in ('opt4', 'opt5'):
                    outline(im, rect('proposed', view, n), crop, 1, YELLOW, 3)
                if abs(num('proposed', view, 'menuShiftY')) > 0.5:  # where the MENU button was in R155
                    outline(im, rect('current', view, 'hub'), crop, 1, (255, 255, 255), 2, dash=True, pad=4)
            else:
                h = rect('proposed', view, 'hub')
                outline(im, (h[0] + h[2] - 20, h[1] - 12, 38, 38), crop, 1, ORANGE, 3, pad=0)
                tag(im, (h[0] + h[2] + 14, h[1] + 2), 'SUGGESTION:\nthe MENU button carries\nthe red ! while a reward waits' if im.width < 800 else 'SUGGESTION: the MENU button carries the red ! while a reward waits', (255, 214, 120), size=15)
                if abs(num('proposed', view, 'menuShiftY')) > 0.5:
                    outline(im, rect('current', view, 'hub'), crop, 1, (255, 255, 255), 2, dash=True, pad=4)
    if scale != 1.0:
        im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    return frame(im)


def numbers(view):
    p, c = info[('proposed', view)], info[('current', view)]
    hud = '%s x %s' % HUD[view]
    off = [tuple(float(t) for t in p['offset%d' % i].split(',')) for i in range(1, 6)]
    lines = ['HUD area ' + hud + ' (+ the top bar row of ' + str(TB[view]) + ' px above it)',
             'MENU button centre y: R155 %s, proposed %s (%+.0f px)' % (c['hubCenterY'].split('.')[0], p['hubCenterY'].split('.')[0], float(p['menuShiftY'])),
             'options %s px; arc radius up %s px, down %s px, width %s px%s' % (p['optionSize'], p['radius'].split('.')[0], '%.0f' % off[4][1], p['radiusX'].split('.')[0],
                                                                          '' if abs(off[1][0] / off[2][0] - 0.7071) < 0.01 else ' (flat fan: diagonals at %.2f of the width)' % (off[1][0] / off[2][0])),
             'offsets from the MENU centre: ' + '  '.join('(%.0f, %.0f)' % o for o in off),
             'overlap with another HUD box: ' + p['wheelClashes']]
    return lines


# ---- the sheet --------------------------------------------------------------------------------------------------------------------------------------------------
WIDTH, M = 2700, 30
sections = []  # (height, painter(canvas, y))
canvas_parts = []
probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))
F_TITLE, F_SEC, F_CAP, F_NOTE = font(40), font(26), font(17, False), font(16, False)


def caption(text, width, fnt=None):
    fnt = fnt or F_CAP
    return wrap(probe, text, fnt, width)


class Sheet:
    def __init__(self):
        self.items = []
        self.y = M

    def text(self, x, text, fnt, fill=INK, width=None, gap=6):
        lines = wrap(probe, text, fnt, width) if width else [text]
        for ln in lines:
            self.items.append(('text', x, self.y, ln, fnt, fill))
            self.y += fnt.size + gap
        return len(lines)

    def image(self, x, y, im):
        self.items.append(('image', x, y, im))

    def render(self):
        canvas = Image.new('RGB', (WIDTH, self.y + M), PAPER)
        d = ImageDraw.Draw(canvas)
        for it in self.items:
            if it[0] == 'text':
                d.text((it[1], it[2]), it[3], font=it[4], fill=it[5])
            else:
                canvas.paste(it[3], (it[1], it[2]))
        return canvas


sh = Sheet()
sh.text(M, 'R156 PREVIEW (not a release): DAILY and INVITE move into the menu wheel', F_TITLE, INK)
sh.y += 2
sh.text(M, 'Owner: "daily and invite can also be put into the menu wheel meaning that we can readjust the menu wheel further up to make space for them this also means we can put the daily notifier at the correct position without anything obstructing it"',
        F_CAP, MUTED, width=WIDTH - 2 * M)
sh.y += 4
sh.text(M, 'APPROXIMATE, not a Studio screenshot: the wheel, its five buttons, the badges, BASE / TRACK and the pity bars are the real GUI trees (this checkout for "current": the R156 release, with the R155 HUD; patched copies of its scripts for "proposed") on the Roblox mock, drawn by Chromium; '
           'the hotbar, balances, status card, jump / stick and Roblox\'s own top bar buttons are stand-ins from HudLayout\'s metrics. The HUD area is what HudLayout sees; Roblox\'s top bar row sits above it.',
        F_NOTE, MUTED, width=WIDTH - 2 * M)
sh.y += 6
# legend
ly = sh.y
leg = Image.new('RGB', (WIDTH - 2 * M, 34), PAPER)
ld = ImageDraw.Draw(leg)
x = 0
for color, dash, label in ((YELLOW, False, 'yellow outline = DAILY / INVITE (R155: squares in the top row; proposed: wheel options 4 and 5)'), ((120, 120, 140), True, 'dashed white outline = where the MENU button was in R155'),
                           (ORANGE, False, 'orange = suggestion (closed wheel)')):
    ld.rounded_rectangle([x, 6, x + 34, 28], radius=5, outline=color, width=3)
    ld.text((x + 44, 8), label, font=font(16, False), fill=INK)
    x += 44 + ld.textlength(label, font=font(16, False)) + 36
sh.image(M, ly, leg)
sh.y += 44

CW, GAP = 860, 30


def block_title(text):
    sh.y += 14
    sh.text(M, text, F_SEC, INK)
    sh.y += 2


def three(variants, view, width, titles, caps):
    """Three whole-screen images side by side (each `width` wide); returns the y below the captions."""
    y0 = sh.y
    ys = []
    for i, (v, state) in enumerate(variants):
        x = M + i * (width + GAP)
        im = shot(v, view, state, width / png('%s_%s_%s' % (v, view, state)).width)
        sh.items.append(('text', x, y0, titles[i], font(21), INK if i != 1 else GREEN))
        sh.image(x, y0 + 30, im)
        ys.append(y0 + 30 + im.height + 6)
    ybottom = max(ys)
    capy = ybottom
    maxlines = 0
    for i in range(3):
        x = M + i * (width + GAP)
        yy = ybottom
        lines = caption(caps[i], width)
        for ln in lines:
            sh.items.append(('text', x, yy, ln, F_CAP, INK))
            yy += 22
        maxlines = max(maxlines, len(lines))
    sh.y = capy + 22 * maxlines + 8


# ---- 1. PC ------------------------------------------------------------------------------------------------------------------------------------------------------
block_title('1. PC, HUD area 1920 x 1080')
y0 = sh.y
cols = [('current', 'open', 'CURRENT (R155 HUD): wheel open'), ('proposed', 'open', 'PROPOSED: wheel open, 5 options'), ('proposed', 'closed', 'PROPOSED, wheel closed')]
pc_caps = ['R155: the wheel has 3 options (SETTINGS up, INDEX, SHOP right); DAILY and INVITE are the two squares right of BASE / TRACK in the top bar row, DAILY\'s red badge is pressed against the top of the screen.',
           'Proposed: the wheel is a half circle of 5 (SETTINGS, INDEX, SHOP where they were, DAILY down-right, INVITE straight down). The MENU button does not need to move on a computer. BASE / TRACK stand alone in the top bar row.',
           'Suggestion: with the wheel closed the MENU button carries the red "!" while a daily reward waits (the same "!" it already shows for Index rewards), so DAILY is still noticed.']
for i, (v, state, title) in enumerate(cols):
    x = M + i * (CW + GAP)
    sh.items.append(('text', x, y0, title, font(21), INK if i != 1 else GREEN))
    im = shot(v, 'pc', state, CW / 1920)
    sh.image(x, y0 + 30, im)
yb = y0 + 30 + 507 + 12
# zooms
for i, (v, state, title) in enumerate(cols):
    x = M + i * (CW + GAP)
    z = png('zoom_pc_%s_%s' % (v, state)).copy()
    box = WHEEL_BOX
    if v == 'current' and state == 'open':
        for n in ('opt1', 'opt2', 'opt3'):
            pass
    if v == 'proposed' and state == 'open':
        for n in ('opt4', 'opt5'):
            outline(z, rect('proposed', 'pc', n), (box[0], box[1]), 1, YELLOW, 3)
    if v == 'proposed' and state == 'closed':
        h = rect('proposed', 'pc', 'hub')
        outline(z, (h[0] + h[2] - 20, h[1] - 12, 38, 38), (box[0], box[1]), 1, ORANGE, 3, pad=0)
    sh.image(x, yb, frame(z))
    cap_w = CW - 470 - 24 if z.width <= 480 else CW
sh_strip_x = lambda i: M + i * (CW + GAP) + 484
# top row strips beside the first two zooms
for i, v in enumerate(('current', 'proposed')):
    x = sh_strip_x(i)
    st = png('strip_pc_%s' % v).copy()
    if v == 'current':
        for n in ('topDaily', 'topInvite'):
            outline(st, rect('current', 'pc', n), (STRIP[0], 0), 1, YELLOW, 2, pad=1)
    sh.items.append(('text', x, yb, ('R155: the top bar row' if v == 'current' else 'Proposed: the top bar row'), font(16), INK))
    sh.image(x, yb + 22, frame(st.resize((min(st.width, CW - 484 - 4), round(st.height * min(st.width, CW - 484 - 4) / st.width)), Image.LANCZOS)))
    lines = caption('DAILY / INVITE squares sit right of TRACK; the badge hangs over the screen top.' if v == 'current' else 'BASE / TRACK alone, centred on the screen. Nothing above or beside the DAILY badge any more.', CW - 484)
    yy = yb + 22 + 56 + 10
    for ln in lines:
        sh.items.append(('text', x, yy, ln, F_NOTE, INK))
        yy += 21
# numbers panel in the third column's free half
x3 = M + 2 * (CW + GAP) + 484
yy = yb
for ln in numbers('pc'):
    for w in caption(ln, CW - 484, F_NOTE):
        sh.items.append(('text', x3, yy, w, F_NOTE, INK))
        yy += 21
sh.y = yb + png('zoom_pc_current_open').height + 30

# ---- 2. landscape phone -----------------------------------------------------------------------------------------------------------------------------------------
block_title('2. Landscape phone, HUD area 844 x 390')
three([('current', 'open'), ('proposed', 'open'), ('proposed', 'closed')], 'land', 844,
      ['CURRENT (R155 HUD): wheel open', 'PROPOSED: wheel open, 5 options', 'PROPOSED, wheel closed'],
      ['R155: DAILY and INVITE are in the top row; the MENU button sits in the middle of the left edge and the wheel opens up and to the right.',
       'Proposed: the MENU button moves up %d px so the half circle (%d px up, %d px down) fits between the Roblox top bar and the balances: SETTINGS right under the top bar, INVITE just above SPEED. Same 64 px buttons.' % (up('land'), radii('land')[0], radii('land')[1]),
       'Suggestion: closed wheel, only a daily reward waiting: the red "!" is on the MENU button.'])
sh.y += 6
# ---- 3. portrait phone ------------------------------------------------------------------------------------------------------------------------------------------
block_title('3. Portrait phone, HUD area 390 x 844')
y0 = sh.y
PW = 390
cols = [('current', 'open', 'CURRENT (R155 HUD): wheel open'), ('proposed', 'open', 'PROPOSED: wheel open'), ('proposed', 'closed', 'PROPOSED, wheel closed')]
pcap = ['R155: DAILY / INVITE in the top row, next to BASE / TRACK.', 'Proposed: MENU moves up %d px; INVITE ends above the pity bars, the balances and timers (top right) are clear.' % up('port'), 'Suggestion: closed wheel, the MENU button carries the "!".']
ymax = y0
for i, (v, state, title) in enumerate(cols):
    x = M + i * (PW + 24)
    sh.items.append(('text', x, y0, title, font(19), INK if i != 1 else GREEN))
    im = shot(v, 'port', state, 1.0)
    sh.image(x, y0 + 28, im)
    yy = y0 + 28 + im.height + 6
    for ln in caption(pcap[i], PW):
        sh.items.append(('text', x, yy, ln, F_NOTE, INK))
        yy += 21
    ymax = max(ymax, yy)
# right of the three phones: the badge zoomed 4x, then the numbers
rx = M + 3 * (PW + 24) + 20
ry = y0
sh.items.append(('text', rx, ry, 'The DAILY badge, zoomed 4x', font(21), INK))
ry += 32
zs = [('badge_cur_daily', 'R155: DAILY square in the top row; the badge is pressed against the screen top (no overhang above)', None),
      ('badge_prop_daily', 'Proposed: DAILY in the wheel; the badge hangs over the top-right corner, nothing above it', GREEN),
      ('badge_prop_index', 'For comparison: the INDEX badge (same size, same overhang; unchanged)', None)]
zx = rx
zmax = ry
for name, cap, color in zs:
    z = frame(png(name))
    sh.image(zx, ry, z)
    yy = ry + z.height + 6
    for ln in caption(cap, z.width, F_NOTE):
        sh.items.append(('text', zx, yy, ln, F_NOTE, INK))
        yy += 21
    zx += z.width + 24
    zmax = max(zmax, yy)
ry = zmax + 20
sh.items.append(('text', rx, ry, 'Numbers (portrait phone)', font(21), INK))
ry += 32
for ln in numbers('port'):
    for w in caption(ln, WIDTH - rx - M, F_CAP):
        sh.items.append(('text', rx, ry, w, F_CAP, INK))
        ry += 23
ry += 10
for ln in ['What the owner asked for, in the pictures:',
           '- DAILY and INVITE are wheel options in the same button style, keeping their own colours and emoji.',
           '- The wheel is further up where the arc needs it (landscape phone -%d px, portrait phone -%d px, short landscape phone -%d px); on a PC it stays in the middle.' % (up('land'), up('port'), up('tiny')),
           '- The DAILY "1" badge sits on its option\'s top-right corner like the INDEX badge; the option above it (SHOP) is 14 px clear.',
           '- BASE / TRACK have the top row to themselves.',
           '- Nothing is covered: balances, timers, hotbar, pity bars and the Roblox top bar buttons are clear of all five options (checked on 20 screen sizes: the table in the .md).']:
    for w in caption(ln, WIDTH - rx - M, F_CAP):
        sh.items.append(('text', rx, ry, w, F_CAP, INK))
        ry += 23
sh.y = max(ymax, ry) + 10

# ---- 4. short landscape phone ----------------------------------------------------------------------------------------------------------------------------------
block_title('4. Stress case: short landscape phone, HUD area 750 x 311 (an 844 x 390 phone minus its safe-area insets)')
three([('current', 'open'), ('proposed', 'open'), ('proposed', 'closed')], 'tiny', 750,
      ['CURRENT (R155 HUD): wheel open', 'PROPOSED: wheel open (tighter)', 'PROPOSED, wheel closed'],
      ['R155: three options, the MENU button in the middle of the left edge.',
       'Proposed: a full circle no longer fits (balances below, the top bar above). It takes a TIGHTER radius (%d px up / %d down instead of 102) and a FLATTER fan (diagonals pulled in, the arc %d px wide); the buttons stay 64 px. MENU moves up %d px.' % (radii('tiny') + (up('tiny'),)),
       'Suggestion: closed wheel.'])
sh.y += 4
sh.text(M, 'Below ~280 px of HUD height the buttons shrink (56, 52, 48, then 44 px); under ~230 px no arc fits and DAILY / INVITE go in a row beyond SHOP (a second ring). See the table in menu_wheel_daily.md.', F_CAP, MUTED, width=WIDTH - 2 * M)
canvas = sh.render()
os.makedirs(os.path.dirname(OUT), exist_ok=True)
canvas.save(OUT, optimize=True)
print('wrote', OUT, canvas.size)
