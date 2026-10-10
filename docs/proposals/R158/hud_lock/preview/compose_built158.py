"""R158 BUILT pictures: the SCENE / INFO lines of built_scene158.luau (one log per PC size, run_built158.sh) -> PNGs with headless Chromium (R155's render_gui155.mjs with R157's text-stroke
fix) -> the two sheets  <out>/built_menu.png  (five PC sizes, the wheel closed and open)  and  <out>/built_scale.png  (the same arrangement on every window, just smaller).
Usage: python3 compose_built158.py SCRATCH OUT_DIR.  Also writes <scratch>/built_numbers.tsv (the numbers hud_lock.md and the report quote) and prints it.
APPROXIMATE: the HUD is the real scripts' GUI trees on the Roblox mock, drawn by Chromium (Fredoka One when the font package is there); Roblox's own top bar and the sky are stand-ins.
Not a Studio screenshot."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
SKY = 'linear-gradient(180deg,#7fc3ee 0%,#c4e6fa 44%,#86c46a 45%,#4f9a4a 100%)'
TB = 52                      # Roblox's top bar on a PC (the HUD area starts under it)
PC = [(1920, 1080), (1366, 768), (1280, 720), (1024, 768), (800, 600)]
SCALED = [(1920, 1080), (1366, 768), (1280, 720), (800, 600)]
INK, PAPER, MUTED = (24, 28, 44), (246, 247, 251), (92, 100, 124)
CYAN, ORANGE, GREEN, RED, PURPLE = (0, 170, 220), (255, 140, 20), (20, 150, 70), (225, 30, 50), (150, 70, 220)
os.makedirs(os.path.join(S, 'png'), exist_ok=True)


def sname(size):
    return '%dx%d' % size


def read_log(size):
    scenes, info = {}, {}
    for line in open(os.path.join(S, 'runs', sname(size), 'scene.log'), encoding='utf-8'):
        if line.startswith('SCENE '):
            p = line.rstrip('\n').split(' ', 7)
            scenes[p[1]] = (tuple(int(t) for t in p[2:6]), p[7])
        elif line.startswith('INFO '):
            p = line.rstrip('\n').split(' ', 2)
            info[p[1]] = p[2] if len(p) > 2 else ''
    return scenes, info


def rects(info):
    return {k[5:]: tuple(float(t) for t in v.split()) for k, v in info.items() if k.startswith('rect.')}


def union(rs):
    x0, y0 = min(r[0] for r in rs), min(r[1] for r in rs)
    x1, y1 = max(r[0] + r[2] for r in rs), max(r[1] + r[3] for r in rs)
    return (x0, y0, x1 - x0, y1 - y0)


def overlap(a, b, pad=0.0):
    return a[0] < b[0] + b[2] + pad and a[0] + a[2] > b[0] - pad and a[1] < b[1] + b[3] + pad and a[1] + a[3] > b[1] - pad


RUN = {size: read_log(size) for size in PC}
CW, GUT, MARGIN = 900, 30, 40          # built_menu: the width of one picture
W2 = 1100                               # built_scale: the equal-width panels
jobs = []


def job(name, size, scene, scale):
    crop, js = RUN[size][0][scene]
    jobs.append({'name': name, 'json': js, 'scale': scale, 'bg': SKY, 'crop': list(crop)})


for size in PC:
    job('bm_closed_%s' % sname(size), size, 'closed_all', CW / float(size[0]))
    job('bm_open_%s' % sname(size), size, 'open_all', CW / float(size[0]))
for size in SCALED:
    job('bs_open_%s' % sname(size), size, 'open_all', W2 / float(size[0]))
    job('bs_small_%s' % sname(size), size, 'open_all', 0.4)
job('bs_ref', (1920, 1080), 'closed_all', 1.0)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(jobs, f)
subprocess.run(['node', os.path.join(S, 'render_gui158.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)
for j in jobs:  # (each page is ~7 MB of HTML: not needed again)
    try:
        os.remove(os.path.join(S, 'png', j['name'] + '.html'))
    except OSError:
        pass


def png(name):
    return Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')


# ---- numbers ----------------------------------------------------------------------------------------------------------------------------------------------------------
def numbers(size):
    scenes, info = RUN[size]
    r = rects(info)
    hub = r['hub']
    opts = [r['opt%d' % i] for i in range(1, 6)]
    wheel = union([hub] + opts)
    rows = [r['wallet_speed'], r['wallet_cash'], r['wallet_gem']]
    balances = union(rows)
    hotbar = union([r['dock'], r['pity']] + ([r['namerows']] if 'namerows' in r else []))
    others = {'balances': rows, 'hotbar': [r['dock']], 'pity bars': [r['pity']], 'status card': [r['status']]}
    hits = []
    for i, o in enumerate(opts + [hub]):
        label = 'option %d' % (i + 1) if i < 5 else 'MENU'
        if o[0] < 0 or o[1] < 0 or o[0] + o[2] > size[0] or o[1] + o[3] > size[1]:
            hits.append((o, None, label + ' off the screen'))
        for name, lst in others.items():
            for b in lst:
                if overlap(o, b):
                    hits.append((o, b, '%s over the %s' % (label, name)))
    return {'hud': float(info['hudScale']), 'menu': float(info['menuScale']), 'laid': info['laidOut'], 'cy': hub[1] + hub[3] / 2, 'hub': hub[2], 'option': opts[0][2],
            'top': wheel[1], 'bottom': wheel[1] + wheel[3], 'wheel': wheel, 'balances': balances, 'hotbar': hotbar, 'status': r['status'], 'slot': float(info['slotSize']),
            'rowH': float(info['walletH']), 'gap': balances[1] - (wheel[1] + wheel[3]), 'hits': hits, 'r': r, 'details': info['details'] == 'true'}


NUM = {size: numbers(size) for size in PC}
lines = ['size\tHUD scale\tMENU scale\tlaid out\tMENU centre y\thub px\toption px\twheel top\twheel bottom\tgap to balances\tslot px\tbalance row px\toverlaps']
for size in PC:
    n = NUM[size]
    lines.append('\t'.join([sname(size), '%.3f' % n['hud'], '%.3f' % n['menu'], n['laid'], '%.0f' % n['cy'], '%.1f' % n['hub'], '%.1f' % n['option'], '%.0f' % n['top'], '%.0f' % n['bottom'],
                            '%.0f' % n['gap'], '%.1f' % n['slot'], '%.1f' % n['rowH'], '; '.join(h[2] for h in n['hits']) or 'none']))
open(os.path.join(S, 'built_numbers.tsv'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
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


def box(im, r, k, color, width=2, dy=TB, pad=3):
    """Outline the HUD-area rect r (screen px) on im, drawn at k px per px, the HUD area starting dy (px) down."""
    ImageDraw.Draw(im).rectangle([r[0] * k - pad, (r[1] + dy) * k - pad, (r[0] + r[2]) * k + pad, (r[1] + r[3] + dy) * k + pad], outline=color, width=width)


def label(im, xy, text, f, color=INK, bg=(255, 255, 255), pad=3):
    d = ImageDraw.Draw(im)
    w = text_w(d, text, f)
    d.rectangle([xy[0] - pad, xy[1] - pad, xy[0] + w + pad, xy[1] + f.size + pad], fill=bg)
    d.text(xy, text, font=f, fill=color)


def vdim(im, x, y0, y1, text, k, color, f, small=False):
    """a vertical dimension line from HUD y0 to y1 (px) at HUD x, with its number."""
    d = ImageDraw.Draw(im)
    X, Y0, Y1 = x * k, (y0 + TB) * k, (y1 + TB) * k
    d.line([X, Y0, X, Y1], fill=color, width=2)
    d.line([X - 5, Y0, X + 5, Y0], fill=color, width=2)
    d.line([X - 5, Y1, X + 5, Y1], fill=color, width=2)
    label(im, (X + 8, (Y1 + 4) if small else (Y0 + Y1) / 2 - f.size / 2), text, f, color)


f_title, f_head, f_sub, f_cap, f_small = font(34), font(24), font(17, False), font(16), font(14, False)

# ---- built_menu.png ---------------------------------------------------------------------------------------------------------------------------------------------------
SHEET_W = 2 * CW + GUT + 2 * MARGIN
cells = {}
for size in PC:
    n = NUM[size]
    k = CW / float(size[0])
    closed = png('bm_closed_%s' % sname(size))
    opened = png('bm_open_%s' % sname(size))
    box(opened, n['wheel'], k, CYAN, 2, pad=4)
    box(opened, n['balances'], k, ORANGE, 2, pad=3)
    for hit in n['hits']:
        box(opened, hit[0], k, RED, 3, pad=2)
        if hit[1]:
            box(opened, hit[1], k, RED, 3, pad=2)
    fd = font(max(12, int(15 * min(1, k * 1.6))))
    cx = n['wheel'][0] + n['wheel'][2] + 14
    if n['gap'] >= 0:
        vdim(opened, cx, n['bottom'], n['balances'][1], '%.0f px' % n['gap'], k, ORANGE, fd)
    vdim(opened, cx, 0, n['top'], '%.0f px' % n['top'], k, CYAN, fd, small=n['top'] * k < 2.2 * fd.size)
    # the closed MENU button, outlined, with its size
    hub = n['r']['hub']
    box(closed, hub, k, CYAN, 2, pad=3)
    cells[size] = (closed, opened)
HEAD_H, ROW_HEAD, CAP_H = 150, 46, 64
H = HEAD_H + sum(ROW_HEAD + 30 + cells[s][0].height + CAP_H + 26 for s in PC) + 150
sheet = Image.new('RGB', (SHEET_W, H), PAPER)
d = ImageDraw.Draw(sheet)
d.text((MARGIN, 28), 'PC HUD as built: MENU a third of the way down, close to its original size', font=f_title, fill=INK)
sub = ('Every PC window is the 1920 x 1080 layout of your screenshot, drawn smaller when the window is smaller. MENU sits at option A (its centre a third of the way down) and shrinks only down to '
       '85% of its 1920 x 1080 size, so it never looks tiny; the open wheel keeps clear of the balances at every size. The pictures are the real HUD scripts on the Roblox mock. Sizes are the game area under '
       'Roblox\'s top bar (the picture adds that 52 px bar on top).')
yy = 78
for ln in wrap(d, sub, f_sub, SHEET_W - 2 * MARGIN):
    d.text((MARGIN, yy), ln, font=f_sub, fill=MUTED)
    yy += 23
y = HEAD_H
for size in PC:
    n = NUM[size]
    d.rectangle([MARGIN, y + 6, SHEET_W - MARGIN, y + ROW_HEAD - 6], fill=(228, 232, 244))
    d.text((MARGIN + 12, y + 9), 'PC %d x %d      HUD scale %.2f      MENU scale %.2f' % (size[0], size[1], n['hud'], n['menu']), font=f_head, fill=INK)
    y += ROW_HEAD + 30
    closed, opened = cells[size]
    for i, (im, title) in enumerate(((closed, 'wheel closed: the MENU button is %.0f px' % n['hub']), (opened, 'wheel open'))):
        x = MARGIN + i * (CW + GUT)
        sheet.paste(im, (x, y))
        d.rectangle([x - 1, y - 1, x + CW, y + im.height], outline=(120, 128, 150), width=1)
        d.text((x, y - 28), title, font=f_cap, fill=INK)
    x = MARGIN + CW + GUT
    cy = y + closed.height + 8
    d.text((x, cy), 'MENU centre %.0f px under the top bar   |   hub and options %.1f px (full size 64)' % (n['cy'], n['hub']), font=f_small, fill=INK)
    d.text((x, cy + 18), 'wheel %.0f to %.0f   |   %.0f px under the top bar   |   %.0f px over the balances' % (n['top'], n['bottom'], n['top'], n['gap']), font=f_small, fill=INK)
    d.text((x, cy + 36), ('no overlap: the wheel, balances, hotbar, bars and status card are all clear' if not n['hits'] else 'OVERLAP: ' + '; '.join(h[2] for h in n['hits'])),
           font=f_small, fill=GREEN if not n['hits'] else RED)
    d.text((MARGIN, cy), 'balances full size (%.1f px rows), hotbar slots %.1f px (82 at full size)' % (n['rowH'], n['slot']), font=f_small, fill=MUTED)
    y += closed.height + CAP_H + 26
d.rectangle([MARGIN, y + 6, SHEET_W - MARGIN, y + 120], fill=(255, 255, 255), outline=(200, 205, 220))
for i, (c, t) in enumerate([(CYAN, 'the open wheel (MENU and its 5 options): px between the top bar and the wheel'), (ORANGE, 'the three balance rows: px between the wheel and the balances'),
                            (RED, 'an overlap (none in any picture when no red box is drawn)')]):
    d.rectangle([MARGIN + 16, y + 20 + i * 28, MARGIN + 44, y + 38 + i * 28], outline=c, width=3)
    d.text((MARGIN + 56, y + 20 + i * 28), t, font=f_small, fill=INK)
d.text((MARGIN + 16, y + 20 + 3 * 28 - 4), 'APPROXIMATE: not a Studio screenshot. Roblox\'s top bar (R, chat, three round buttons) and the sky are stand-ins. Re-render: sh preview/run_built158.sh <scratch dir>.', font=f_small, fill=MUTED)
sheet = sheet.crop((0, 0, SHEET_W, y + 136))
sheet.save(os.path.join(OUT, 'built_menu.png'), optimize=True)
print('built_menu.png', sheet.size)

# ---- built_scale.png --------------------------------------------------------------------------------------------------------------------------------------------------
PCOL = {'menu': GREEN, 'balances': ORANGE, 'hotbar': CYAN, 'status': PURPLE}
SHEET2 = 2 * W2 + 30 + 2 * MARGIN
ref = png('bs_ref')
ref = ref.crop((10, ref.height - 313, 1910, ref.height))
true_k = 0.4
small = {size: png('bs_small_%s' % sname(size)) for size in SCALED}
big = {size: png('bs_open_%s' % sname(size)) for size in SCALED}
true_h = max(im.height for im in small.values())
rows2 = [(SCALED[0], SCALED[1]), (SCALED[2], SCALED[3])]
HEAD2 = 150
Hh = HEAD2 + 36 + ref.height + 60 + 36 + true_h + 70 + 76 + sum(max(big[a].height, big[b].height) + 30 + 80 for a, b in rows2) + 200
sheet2 = Image.new('RGB', (SHEET2, Hh), PAPER)
d2 = ImageDraw.Draw(sheet2)
d2.text((MARGIN, 28), 'PC HUD as built: the same layout on every window, just smaller', font=f_title, fill=INK)
sub2 = ('The layout of your screenshot is the PC layout. A smaller window does not move anything: the HUD is laid out as if the window were 1920 x 1080 and then shrunk to fit (scale = the smaller of '
        'width / 1920 and height / 720, never more than 1.0). MENU sits a third of the way down and shrinks only to 85% of its size (the green box), so it is the one piece that stays a little bigger. '
        'Roblox\'s own top bar keeps its normal size.')
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
    im = small[size]
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
        n = NUM[size]
        pieces = {'menu': n['wheel'], 'balances': n['balances'], 'hotbar': n['hotbar'], 'status': n['status']}
        for name, r in pieces.items():
            box(im, r, k, PCOL[name], 3, pad=4)
        d2.text((x0, y - 28), 'PC %d x %d   (HUD scale %.2f, MENU scale %.2f)' % (size[0], size[1], n['hud'], n['menu']), font=f_cap, fill=INK)
        sheet2.paste(im, (x0, y))
        d2.rectangle([x0 - 1, y - 1, x0 + W2, y + im.height], outline=(120, 128, 150))
        c1 = 'hotbar slot %.0f px (82 at full size)   balance row %.0f px (56)   MENU and wheel option %.0f px (64)' % (n['slot'], n['rowH'], n['option'])
        c2 = 'MENU centre %.0f px under the top bar   (HUD laid out as a %s window)' % (n['cy'], n['laid'].replace('x', ' x '))
        d2.text((x0, y + im.height + 8), c1, font=f_small, fill=INK)
        d2.text((x0, y + im.height + 28), c2, font=f_small, fill=INK)
    y += rh + 30 + 80
d2.rectangle([MARGIN, y, SHEET2 - MARGIN, y + 110], fill=(255, 255, 255), outline=(200, 205, 220))
for i, (name, t) in enumerate([('balances', 'balances'), ('hotbar', 'hotbar, pity bars and name rows'), ('status', 'luck rows, timers and THE DARKENED card'), ('menu', 'MENU and its open wheel')]):
    xx = MARGIN + 16 + (i % 2) * 560
    yy = y + 14 + (i // 2) * 28
    d2.rectangle([xx, yy, xx + 28, yy + 18], outline=PCOL[name], width=3)
    d2.text((xx + 40, yy), t, font=f_small, fill=INK)
d2.text((MARGIN + 16, y + 74), 'APPROXIMATE: not a Studio screenshot. Roblox\'s top bar and the sky are stand-ins. Re-render: sh preview/run_built158.sh <scratch dir>.', font=f_small, fill=MUTED)
sheet2 = sheet2.crop((0, 0, SHEET2, y + 130))
sheet2.save(os.path.join(OUT, 'built_scale.png'), optimize=True)
print('built_scale.png', sheet2.size)
