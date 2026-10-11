"""R158 HUD-lock preview: the SCENE / INFO lines of hud_scene158.luau (one log per run, run_hud_lock158.sh) -> PNGs with headless Chromium (R155's render_gui155.mjs with R157's
text-stroke fix) -> the two sheets  <out>/menu_higher.png  and  <out>/pc_scale.png.   Usage: python3 compose_hud_lock158.py SCRATCH OUT_DIR
Also writes <scratch>/numbers.tsv (the numbers the .md and the report quote) and prints it.
APPROXIMATE: the HUD is the real scripts' GUI trees on the Roblox mock, drawn by Chromium (Fredoka One when the font package is there); Roblox's own top bar and the sky are
stand-ins. Not a Studio screenshot."""
import json
import math
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../../..'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
SKY = 'linear-gradient(180deg,#7fc3ee 0%,#c4e6fa 44%,#86c46a 45%,#4f9a4a 100%)'
TB = 52                      # Roblox's top bar on a PC (the HUD area starts under it)
PC = [(1920, 1080), (1366, 768), (1280, 720), (1024, 768), (800, 600)]
SCALED = [(1920, 1080), (1366, 768), (1280, 720), (800, 600)]
VARIANTS = ['cur', 'A', 'B']
TITLE = {'cur': 'TODAY (R157)', 'A': 'A: MENU at 1/3 of the height', 'B': 'B: wheel top under the top bar'}
INK, PAPER, MUTED = (24, 28, 44), (246, 247, 251), (92, 100, 124)
CYAN, ORANGE, GREEN, RED, PURPLE, YELLOW = (0, 170, 220), (255, 140, 20), (20, 150, 70), (225, 30, 50), (150, 70, 220), (255, 214, 0)
os.makedirs(os.path.join(S, 'png'), exist_ok=True)


def sname(size):
    return '%dx%d' % size


def read_log(run):
    scenes, info = {}, {}
    for line in open(os.path.join(S, 'runs', run, 'scene.log'), encoding='utf-8'):
        if line.startswith('SCENE '):
            p = line.rstrip('\n').split(' ', 7)
            scenes[p[1]] = (tuple(int(t) for t in p[2:6]), p[7])
        elif line.startswith('INFO '):
            p = line.rstrip('\n').split(' ', 2)
            info[p[1]] = p[2] if len(p) > 2 else ''
    return scenes, info


def rects(info):
    out = {}
    for k, v in info.items():
        if k.startswith('rect.'):
            out[k[5:]] = tuple(float(t) for t in v.split())
    return out


def scale_of(size):
    w, h = size
    return min(1.0, w / 1920.0, h / 720.0)


def virtual_of(size):
    s = scale_of(size)
    return math.ceil(size[0] / s - 1e-6), math.ceil(size[1] / s - 1e-6)


# ---- read every log ---------------------------------------------------------------------------------------------------------------------------------------------------
RUN = {}
for v in VARIANTS:
    for size in PC:
        RUN[(v, size)] = read_log('%s_%s' % (v, sname(size)))
for size in SCALED:
    RUN[('scale', size)] = read_log('scale_%s' % sname(size))

jobs = []
W2 = 1100  # the equal-width panels of pc_scale.png


def job(name, run, scene, crop=None, scale=1.0):
    c, js = RUN[run][0][scene]
    jobs.append({'name': name, 'json': js, 'scale': scale, 'bg': SKY, 'crop': crop or list(c)})


for v in VARIANTS:
    for size in PC:
        job('mh_%s_%s' % (v, sname(size)), (v, size), 'open_all')
job('ref_closed', ('A', (1920, 1080)), 'closed_all')
for size in SCALED:
    vw, vh = virtual_of(size)
    assert RUN[('scale', size)][1]['hud'] == '%dx%d' % (vw, vh), (size, RUN[('scale', size)][1]['hud'], vw, vh)
    job('sc_%s_hud' % sname(size), ('scale', size), 'open_hud', [0, 0, vw, vh], size[0] / float(vw))
    job('sc_%s_top' % sname(size), ('A', size), 'open_top', [0, 0, size[0], TB], 1.0)
    # (the same two pictures drawn straight at the equal-width panels' size, so the smallest window is not an enlarged 1x picture)
    job('sc_%s_hudL' % sname(size), ('scale', size), 'open_hud', [0, 0, vw, vh], W2 / float(vw))
    job('sc_%s_topL' % sname(size), ('A', size), 'open_top', [0, 0, size[0], TB], W2 / float(size[0]))
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(jobs, f)
subprocess.run(['node', os.path.join(S, 'render_gui158.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'),
                FONTS if os.path.isdir(FONTS) else ''], check=True)
for j in jobs:  # (each page is ~7 MB of HTML: not needed again)
    try:
        os.remove(os.path.join(S, 'png', j['name'] + '.html'))
    except OSError:
        pass


def png(name):
    return Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')


# ---- numbers ----------------------------------------------------------------------------------------------------------------------------------------------------------
def overlap(a, b, pad=0.0):
    return a[0] < b[0] + b[2] + pad and a[0] + a[2] > b[0] - pad and a[1] < b[1] + b[3] + pad and a[1] + a[3] > b[1] - pad


def union(rs):
    x0, y0 = min(r[0] for r in rs), min(r[1] for r in rs)
    x1, y1 = max(r[0] + r[2] for r in rs), max(r[1] + r[3] for r in rs)
    return (x0, y0, x1 - x0, y1 - y0)


def numbers(variant, size):
    scenes, info = RUN[(variant, size)]
    r = rects(info)
    hub = r['hub']
    opts = [r['opt%d' % i] for i in range(1, 6)]
    wheel = union([hub] + opts)
    rows = [r['wallet_speed'], r['wallet_cash'], r['wallet_gem']]
    balances = union(rows)
    others = {'balances': rows, 'hotbar': [r['dock']], 'pity bars': [r['pity']] if 'pity' in r else [], 'status card': [r['status']]}
    hits = []
    for o_i, o in enumerate(opts + [hub]):
        label = 'option %d' % (o_i + 1) if o_i < 5 else 'MENU'
        if o[0] < 0 or o[1] < 0 or o[0] + o[2] > size[0] or o[1] + o[3] > size[1]:
            hits.append((o, None, label + ' off the screen'))
        for name, lst in others.items():
            for b in lst:
                if overlap(o, b):
                    hits.append((o, b, '%s over the %s' % (label, name)))
    n = {
        'cy': hub[1] + hub[3] / 2, 'top': wheel[1], 'bottom': wheel[1] + wheel[3], 'wheel': wheel, 'balances': balances, 'rows': rows,
        'gap_balances': balances[1] - (wheel[1] + wheel[3]), 'gap_top': wheel[1], 'hits': hits, 'rowH': float(info['walletH']), 'rowW': float(info['walletW']),
        'slot': float(info['slotSize']), 'slots': int(info['slots']), 'details': info['details'] == 'true', 'option': float(info['optionSize']),
        'rect': r, 'info': info,
    }
    # the wheel's horizontal reach against the balances: only a "gap" when the two share some x
    n['under'] = wheel[0] < balances[0] + balances[2] and wheel[0] + wheel[2] > balances[0]
    return n


NUM = {(v, size): numbers(v, size) for v in VARIANTS for size in PC}
lines = ['layout\tsize\tMENU centre y\twheel top\twheel bottom\tgap to balances\tgap under top bar\tgap from Roblox buttons\tbalance row h\tname rows\toverlaps']
for size in PC:
    for v in VARIANTS:
        n = NUM[(v, size)]
        lines.append('\t'.join([v, sname(size), '%.0f' % n['cy'], '%.0f' % n['top'], '%.0f' % n['bottom'], '%.0f' % n['gap_balances'] if n['under'] else 'n/a', '%.0f' % n['gap_top'],
                                '%.0f' % (n['gap_top'] + 6), '%.0f' % n['rowH'], 'shown' if n['details'] else 'hidden', '; '.join(h[2] for h in n['hits']) or 'none']))
open(os.path.join(S, 'numbers.tsv'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('\n'.join(lines))


# ---- drawing helpers --------------------------------------------------------------------------------------------------------------------------------------------------
def font(px, bold=True):
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)


def text_w(d, t, f):
    return d.textlength(t, font=f)


def wrap(d, text, f, width):
    out, line = [], ''
    for word in text.split(' '):
        trial = (line + ' ' + word).strip()
        if text_w(d, trial, f) <= width:
            line = trial
        else:
            out.append(line)
            line = word
    out.append(line)
    return out


def box(im, r, k, color, width=2, dy=TB, pad=3, dash=False):
    """Outline the HUD-area rect r (px) on im, drawn at k px per px, the HUD area starting dy (px) down."""
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = (r[0]) * k - pad, (r[1] + dy) * k - pad, (r[0] + r[2]) * k + pad, (r[1] + r[3] + dy) * k + pad
    if not dash:
        d.rectangle([x0, y0, x1, y1], outline=color, width=width)
        return
    step = 8
    x = x0
    while x < x1:
        d.line([x, y0, min(x + step / 2, x1), y0], fill=color, width=width)
        d.line([x, y1, min(x + step / 2, x1), y1], fill=color, width=width)
        x += step
    y = y0
    while y < y1:
        d.line([x0, y, x0, min(y + step / 2, y1)], fill=color, width=width)
        d.line([x1, y, x1, min(y + step / 2, y1)], fill=color, width=width)
        y += step


def label(im, xy, text, f, color=INK, bg=(255, 255, 255), pad=3):
    d = ImageDraw.Draw(im)
    w = text_w(d, text, f)
    d.rectangle([xy[0] - pad, xy[1] - pad, xy[0] + w + pad, xy[1] + f.size + pad], fill=bg)
    d.text(xy, text, font=f, fill=color)


def vdim(im, x, y0, y1, text, k, color, f, small=False):
    """a vertical dimension line from HUD y0 to y1 (px) at HUD x, with its number (a short line: the number sits just under it)."""
    d = ImageDraw.Draw(im)
    X, Y0, Y1 = x * k, (y0 + TB) * k, (y1 + TB) * k
    d.line([X, Y0, X, Y1], fill=color, width=2)
    d.line([X - 5, Y0, X + 5, Y0], fill=color, width=2)
    d.line([X - 5, Y1, X + 5, Y1], fill=color, width=2)
    label(im, (X + 8, (Y1 + 4) if small else (Y0 + Y1) / 2 - f.size / 2), text, f, color)


# ---- menu_higher.png --------------------------------------------------------------------------------------------------------------------------------------------------
CW, GUT, MARGIN = 760, 30, 40
SHEET_W = 3 * CW + 2 * GUT + 2 * MARGIN
f_title, f_head, f_sub, f_cap, f_small = font(34), font(24), font(17, False), font(16), font(14, False)
probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))


def cell(v, size):
    w, h = size
    n = NUM[(v, size)]
    k = CW / float(w)
    im = png('mh_%s_%s' % (v, sname(size)))
    im = im.resize((CW, round((h + TB) * k)), Image.LANCZOS)
    box(im, n['wheel'], k, CYAN, 2, pad=4)
    box(im, n['balances'], k, ORANGE, 2, pad=3)
    for hit in n['hits']:
        box(im, hit[0], k, RED, 3, pad=2)
        if hit[1]:
            box(im, hit[1], k, RED, 3, pad=2)
    fd = font(max(12, int(15 * min(1, k * 1.6))))
    cx = n['wheel'][0] + n['wheel'][2] + 14
    if n['under'] and n['gap_balances'] >= 0:
        vdim(im, cx, n['bottom'], n['balances'][1], '%.0f px' % n['gap_balances'], k, ORANGE, fd)
    vdim(im, cx, 0, n['top'], '%.0f px' % n['top'], k, CYAN, fd, small=n['top'] * k < 2.2 * fd.size)
    return im


def caption(v, size, width):
    n = NUM[(v, size)]
    out = ['MENU centre y %.0f   |   wheel %.0f to %.0f' % (n['cy'], n['top'], n['bottom'])]
    out.append('under top bar %.0f px   |   to balances %s' % (n['top'], ('%.0f px' % n['gap_balances']) if n['under'] else 'not above them'))
    full = max(NUM[(x, size)]['rowH'] for x in VARIANTS)
    notes = []
    if n['hits']:
        notes.append(('OVERLAP: ' + '; '.join(h[2] for h in n['hits']), RED))
    else:
        notes.append(('no overlap', GREEN))
    if n['rowH'] < full - 0.5:
        notes.append(('balance rows shortened to %.0f px (full size %.0f)' % (n['rowH'], full), ORANGE))
    elif v != 'cur':
        notes.append(('balances at full size (%.0f px rows)' % n['rowH'], MUTED))
    if not n['details']:
        notes.append(('held-item name rows hidden', ORANGE))
    return out, notes


cells = {}
row_h = {}
for size in PC:
    for v in VARIANTS:
        cells[(v, size)] = cell(v, size)
    row_h[size] = cells[('cur', size)].height
HEAD_H, ROW_HEAD, CAP_H = 150, 46, 84
H = HEAD_H + sum(ROW_HEAD + 30 + row_h[s] + CAP_H + 26 for s in PC) + 170
sheet = Image.new('RGB', (SHEET_W, H), PAPER)
d = ImageDraw.Draw(sheet)
d.text((MARGIN, 28), 'PC HUD: where should MENU sit? (wheel open)', font=f_title, fill=INK)
sub = ('Today the MENU button sits in the middle of the left edge. A and B move it up so the whole open wheel stays clear of your balances at every PC size, so the balance rows never have to '
       'shrink. The pictures are the real HUD scripts (hotbar, balances, status, pity bars, wheel) on the Roblox mock, in the numbers of your screenshot. Sizes are the game area under Roblox\'s top bar '
       '(the picture adds that 52 px bar on top).')
yy = 78
for ln in wrap(d, sub, f_sub, SHEET_W - 2 * MARGIN):
    d.text((MARGIN, yy), ln, font=f_sub, fill=MUTED)
    yy += 23
y = HEAD_H
for size in PC:
    d.rectangle([MARGIN, y + 6, SHEET_W - MARGIN, y + ROW_HEAD - 6], fill=(228, 232, 244))
    d.text((MARGIN + 12, y + 9), 'PC %d x %d' % size, font=f_head, fill=INK)
    y += ROW_HEAD + 30
    for i, v in enumerate(VARIANTS):
        x = MARGIN + i * (CW + GUT)
        sheet.paste(cells[(v, size)], (x, y))
        d.rectangle([x - 1, y - 1, x + CW, y + row_h[size]], outline=(120, 128, 150), width=1)
        t = TITLE[v]
        d.text((x, y - 28), t, font=f_cap, fill=INK)
        lines_, notes = caption(v, size, CW)
        cy = y + row_h[size] + 8
        for ln in lines_:
            d.text((x, cy), ln, font=f_small, fill=INK)
            cy += 18
        for text, color in notes:
            d.text((x, cy), text, font=f_small, fill=color)
            cy += 18
    y += row_h[size] + CAP_H + 26
# legend
d.rectangle([MARGIN, y + 6, SHEET_W - MARGIN, y + 160], fill=(255, 255, 255), outline=(200, 205, 220))
for i, (c, t) in enumerate([(CYAN, 'the open wheel (MENU and its 5 options): px between the top bar and the wheel'),
                            (ORANGE, 'the three balance rows: px between the wheel and the balances'),
                            (RED, 'an overlap (none in any picture when no red box is drawn)')]):
    d.rectangle([MARGIN + 16, y + 20 + i * 28, MARGIN + 44, y + 38 + i * 28], outline=c, width=3)
    d.text((MARGIN + 56, y + 20 + i * 28), t, font=f_small, fill=INK)
d.text((MARGIN + 16, y + 20 + 3 * 28 - 4), 'B: the owner-only TOOLS square (top left) hides while the wheel is open, so the wheel may use its place. A closed MENU is 64 px tall, centred on the same y.', font=f_small, fill=MUTED)
d.text((MARGIN + 16, y + 20 + 3 * 28 + 16), 'APPROXIMATE: not a Studio screenshot. Roblox\'s top bar (R, chat, three round buttons) and the sky are stand-ins. Re-render: sh preview/run_hud_lock158.sh <scratch dir>.', font=f_small, fill=MUTED)
sheet = sheet.crop((0, 0, SHEET_W, y + 176))
sheet.save(os.path.join(OUT, 'menu_higher.png'), optimize=True)
print('menu_higher.png', sheet.size)


# ---- pc_scale.png -----------------------------------------------------------------------------------------------------------------------------------------------------
def screen(size, big=False):
    """The whole screen: Roblox's top bar row at its true size over the HUD (drawn shrunk). big: the render made for the equal-width panels (W2 px wide)."""
    w, h = size
    top = png('sc_%s_%s' % (sname(size), 'topL' if big else 'top'))
    hud = png('sc_%s_%s' % (sname(size), 'hudL' if big else 'hud'))
    k = W2 / float(w) if big else 1.0
    want = (round(w * k), round(h * k))
    if hud.size != want:
        hud = hud.resize(want, Image.LANCZOS)
    im = Image.new('RGB', (want[0], want[1] + top.height))
    im.paste(top, (0, 0))
    im.paste(hud, (0, top.height))
    return im


def scaled_rects(size):
    """The pieces of the HUD in screen px (under the top bar): the rects of the virtual layout x s."""
    s = scale_of(size)
    info = RUN[('scale', size)][1]
    r = rects(info)
    mul = lambda b: (b[0] * s, b[1] * s, b[2] * s, b[3] * s)
    wheel = union([r['hub']] + [r['opt%d' % i] for i in range(1, 6)])
    pieces = {
        'menu': mul(wheel),
        'balances': mul(union([r['wallet_speed'], r['wallet_cash'], r['wallet_gem']])),
        'hotbar': mul(union([r['dock'], r['pity']])),
        'status': mul(r['status']),
    }
    return pieces, info, s


PCOL = {'menu': GREEN, 'balances': ORANGE, 'hotbar': CYAN, 'status': PURPLE}
SHEET2 = 2 * W2 + 30 + 2 * MARGIN
big = {size: screen(size, True) for size in SCALED}
small = {size: screen(size) for size in SCALED}
ref = png('ref_closed')
ref = ref.crop((10, ref.height - 313, 1910, ref.height))
true_k = 0.4
true_h = max(round((s[1] + TB) * true_k) for s in SCALED)
rows2 = [(SCALED[0], SCALED[1]), (SCALED[2], SCALED[3])]
HEAD2 = 150
Hh = HEAD2 + 36 + ref.height + 60 + 36 + true_h + 70 + 76 + sum(max(big[a].height, big[b].height) + 30 + 80 for a, b in rows2) + 200
sheet2 = Image.new('RGB', (SHEET2, Hh), PAPER)
d2 = ImageDraw.Draw(sheet2)
d2.text((MARGIN, 28), 'PC HUD: the same layout on every window, just smaller', font=f_title, fill=INK)
sub2 = ('The layout of your screenshot is the PC layout. A smaller window does not move anything: the HUD is laid out as if the window were 1920 x 1080 and then shrunk to fit '
        '(scale = the smaller of width / 1920 and height / 720, never more than 1.0). MENU is shown at option A (1/3 of the height). Roblox\'s own top bar keeps its normal size.')
yy = 78
for ln in wrap(d2, sub2, f_sub, SHEET2 - 2 * MARGIN):
    d2.text((MARGIN, yy), ln, font=f_sub, fill=MUTED)
    yy += 23
y = HEAD2
d2.text((MARGIN, y), 'Reference: the bottom of the 1920 x 1080 HUD (the same 1900 x 313 piece as your screenshot), true size', font=f_head, fill=INK)
y += 36
sheet2.paste(ref, (MARGIN, y))
d2.rectangle([MARGIN - 1, y - 1, MARGIN + ref.width, y + ref.height], outline=(120, 128, 150))
y += ref.height + 60
d2.text((MARGIN, y - 4), 'The four windows side by side at one scale (0.4x of real pixels): a smaller window gives a smaller HUD, the same arrangement', font=f_head, fill=INK)
y += 36
x = MARGIN
for size in SCALED:
    im = small[size].resize((round(size[0] * true_k), round((size[1] + TB) * true_k)), Image.LANCZOS)
    sheet2.paste(im, (x, y))
    d2.rectangle([x - 1, y - 1, x + im.width, y + im.height], outline=(120, 128, 150))
    d2.text((x, y + im.height + 6), '%d x %d' % size, font=f_cap, fill=INK)
    x += im.width + 28
y += true_h + 70
d2.text((MARGIN, y - 4), 'The same four windows, each drawn as wide as the page, with the pieces outlined: they sit in the same places', font=f_head, fill=INK)
y += 76
for a, b in rows2:
    rh = max(big[a].height, big[b].height)
    for i, size in enumerate((a, b)):
        x0 = MARGIN + i * (W2 + 30)
        k = W2 / float(size[0])
        im = big[size].copy()
        pieces, info, s = scaled_rects(size)
        for name, r in pieces.items():
            box(im, r, k, PCOL[name], 3, pad=4)
        d2.text((x0, y - 28), 'PC %d x %d   (HUD scale %.2f)' % (size[0], size[1], s), font=f_cap, fill=INK)
        sheet2.paste(im, (x0, y))
        d2.rectangle([x0 - 1, y - 1, x0 + W2, y + im.height], outline=(120, 128, 150))
        slot, rowh = float(info['slotSize']) * s, float(info['walletH']) * s
        vw, vh = (int(t) for t in info['hud'].split('x'))
        laid = '1920 x %d' % vh if abs(vw - 1920) <= 2 else '%d x %d' % (vw, vh)
        c1 = 'hotbar slot %.0f px (82 at full size)   balance row %.0f px (56)   wheel option %.0f px (64)' % (slot, rowh, float(info['optionSize']) * s)
        c2 = 'MENU centre %.0f px under the top bar   (HUD laid out as a %s window)' % (float(info['hubCenterY']) * s, laid)
        d2.text((x0, y + im.height + 8), c1, font=f_small, fill=INK)
        d2.text((x0, y + im.height + 28), c2, font=f_small, fill=INK)
    y += rh + 30 + 80
# legend
d2.rectangle([MARGIN, y, SHEET2 - MARGIN, y + 110], fill=(255, 255, 255), outline=(200, 205, 220))
for i, (name, t) in enumerate([('balances', 'balances'), ('hotbar', 'hotbar and pity bars'), ('status', 'luck rows, timers and THE DARKENED card'), ('menu', 'MENU and its open wheel')]):
    xx = MARGIN + 16 + (i % 2) * 560
    yy = y + 14 + (i // 2) * 28
    d2.rectangle([xx, yy, xx + 28, yy + 18], outline=PCOL[name], width=3)
    d2.text((xx + 40, yy), t, font=f_small, fill=INK)
d2.text((MARGIN + 16, y + 74), 'APPROXIMATE: not a Studio screenshot. Roblox\'s top bar and the sky are stand-ins. Re-render: sh preview/run_hud_lock158.sh <scratch dir>.', font=f_small, fill=MUTED)
sheet2 = sheet2.crop((0, 0, SHEET2, y + 130))
sheet2.save(os.path.join(OUT, 'pc_scale.png'), optimize=True)
print('pc_scale.png', sheet2.size)
