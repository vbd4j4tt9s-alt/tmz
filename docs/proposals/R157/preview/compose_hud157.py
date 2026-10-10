"""R157 preview: lays out docs/proposals/R157/hud157.png from what run_hud157_preview.sh made on this branch's real src/: the pity bars' and the menu wheel's SCENE lines
(drawn here by R155's render_gui155.mjs, headless Chromium) and the reveal's rendered layers (composed as R156's compose_reveal_fixes156.py does).
Usage: python3 compose_hud157.py <scratch dir> <out.png>
APPROXIMATE: the bars, the wheel and its options, the badges, BASE / TRACK, the reveal card, the SKIP pill, the hotbar (in the reveal) are the real GUI trees on the Roblox mock;
the slots (bars and wheel scenes), balances, status card, MENU (bars and reveal scenes), jump / stick, BONUS ROLL and Roblox's top bar are stand-ins; the world is a stand-in."""
import base64
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
R155 = os.path.normpath(os.path.join(HERE, '..', '..', 'R155', 'preview'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
SKY = 'linear-gradient(180deg,#7fc3ee 0%,#c4e6fa 44%,#86c46a 45%,#4f9a4a 100%)'
PAPER, INK, MUTED, RULE = (246, 247, 251), (24, 28, 44), (92, 100, 124), (200, 204, 216)
W_, PAD, GAP = 1900, 24, 14
TB = {'pc': 52, 'land': 44, 'port': 44}


def font(px, bold=True):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)
    except Exception:
        return ImageFont.load_default()


F_TITLE, F_SUB, F_HEAD, F_CAP = font(32), font(16, False), font(24), font(14, False)
PROBE = ImageDraw.Draw(Image.new('RGB', (10, 10)))


def wrap(text, f, width):
    lines, line = [], ''
    for w in text.split():
        t = (line + ' ' + w).strip()
        if PROBE.textlength(t, font=f) > width and line:
            lines.append(line)
            line = w
        else:
            line = t
    lines.append(line)
    return lines


# ---- 1. the GUI scenes (bars, wheel) -> PNGs ----------------------------------------------------------------------------------------------------------------------
clover = 'data:image/png;base64,' + base64.b64encode(open(os.path.join(S, 'clover.png'), 'rb').read()).decode('ascii')
jobs, crops = [], {}


def scenes(path, prefix, keep, render_scale=None):
    for line in open(path, encoding='utf-8'):
        if not line.startswith('SCENE '):
            continue
        parts = line.rstrip('\n').split(' ', 7)
        name, x, y, cw, ch, scale = parts[1:7]
        if name not in keep:
            continue
        crops[prefix + name] = [int(x), int(y), int(cw), int(ch)]
        sc = render_scale or (2.0 if float(scale) == 1 else float(scale))
        jobs.append({'name': prefix + name, 'json': parts[7], 'scale': sc, 'bg': SKY, 'crop': [int(x), int(y), int(cw), int(ch)], 'img': clover})


scenes(os.path.join(S, 'pity', 'pc', 'scenes.log'), 'bars_', {'pc_name', 'pc_zoom_99', 'pc_pop_e', 'pc_bonus'})
scenes(os.path.join(S, 'pity', 'land', 'scenes.log'), 'bars_', {'land_evheld'})
scenes(os.path.join(S, 'pity', 'port', 'scenes.log'), 'bars_', {'port_held9'})
for view in ('pc', 'land', 'port'):
    scenes(os.path.join(S, 'wheel', view, 'scene.log'), 'wheel_%s_' % view, {'closed', 'open'}, 1.0 if view == 'pc' else 2.0)
# the PC wheel up close: the box around MENU and its five options (the scene's INFO rect lines, canvas px), closed and open, at 2x
rects = {}
for line in open(os.path.join(S, 'wheel', 'pc', 'scene.log'), encoding='utf-8'):
    if line.startswith('INFO pc rect.'):
        p = line.split()
        rects[p[2][5:]] = [int(v) for v in p[3:7]]
box = [r for k, r in rects.items() if k == 'hub' or k.startswith('opt')]
x0, y0 = max(0, min(r[0] for r in box) - 10), max(0, min(r[1] for r in box) - 30)
x1, y1 = max(r[0] + r[2] for r in box) + 120, max(r[1] + r[3] for r in box) + 14
for j in [j for j in jobs if j['name'] in ('wheel_pc_closed', 'wheel_pc_open')]:
    jobs.append(dict(j, name=j['name'].replace('wheel_', 'wheelzoom_'), crop=[x0, y0, x1 - x0, y1 - y0], scale=2.0))
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(jobs, f)
subprocess.run(['node', os.path.join(R155, 'render_gui155.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)


def png(name):
    return Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')


# ---- 2. the reveal frames (R156's compose_reveal_fixes156.py: the world graded, the HUD under the seed's viewport, the card over it) ---------------------------------------
def grade(img, g, blur, scale):
    img = img.convert('RGB')
    if g:
        if g['s']:
            img = ImageEnhance.Color(img).enhance(max(0.0, 1 + g['s']))
        if g['c']:
            img = ImageEnhance.Contrast(img).enhance(max(0.0, 1 + g['c']))
        if g['b']:
            add = int(g['b'] * 255)
            img = img.point(lambda v: max(0, min(255, v + add)))
        t = g['tint']
        if t != [255, 255, 255]:
            r, gg, b = img.split()
            img = Image.merge('RGB', (r.point(lambda v: v * t[0] // 255), gg.point(lambda v: v * t[1] // 255), b.point(lambda v: v * t[2] // 255)))
    if blur and blur > .3:
        img = img.filter(ImageFilter.GaussianBlur(blur * .45 * scale))
    return img


def overlay(img, path):
    if os.path.exists(path):
        ov = Image.open(path).convert('RGBA')
        if ov.size != img.size:
            ov = ov.resize(img.size, Image.LANCZOS)
        img.alpha_composite(ov)


def frame(view, name):
    d = os.path.join(S, 'out', view)
    m = {x['name']: x for x in json.load(open(os.path.join(d, 'meta.json')))}[name]
    img = grade(Image.open(os.path.join(d, name + '_world.png')), m['grade'], m['blur'], m['h'] / 720).convert('RGBA')
    for i in range(m.get('under', 0)):
        overlay(img, os.path.join(d, '%s_under%d.png' % (name, i)))
    vp = m.get('vp')
    if vp and os.path.exists(os.path.join(d, name + '_vp.png')):
        x, y, w, h = vp['rect']
        s = max(1, int(w * vp['scale']))
        card = Image.open(os.path.join(d, name + '_vp.png')).convert('RGBA').resize((s, s), Image.LANCZOS)
        if vp['alpha'] < 1:
            card.putalpha(card.split()[3].point(lambda v: int(v * vp['alpha'])))
        img.alpha_composite(card, (int(x + w / 2 - s / 2), int(y + h / 2 - s / 2)))
    for i in range(m['guis']):
        overlay(img, os.path.join(d, '%s_gui%d.png' % (name, i)))
    return img.convert('RGB')


def lines_of(view, tag):
    out = {}
    for line in open(os.path.join(S, 'rev', 'cl', 'frames_%s.txt' % view), encoding='utf-8'):
        if line.startswith(tag + ' '):
            p = line.split(' ', 3)
            out[p[2]] = json.loads(p[3]) if p[3].strip().startswith('{') else p[3].strip()
    return out


# ---- 3. the sheet ------------------------------------------------------------------------------------------------------------------------------------------------
def captioned(img, caption, width):
    lines = wrap(caption, F_CAP, width)
    out = Image.new('RGB', (width, img.height + 8 + 19 * len(lines)), PAPER)
    out.paste(img, (0, 0))
    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, img.width - 1, img.height - 1], outline=RULE)
    for i, t in enumerate(lines):
        d.text((0, img.height + 6 + 19 * i), t, font=F_CAP, fill=INK)
    return out


def row(items, max_h):
    """items: [(image, caption)] scaled to one height so the row fills the sheet's width (at most max_h tall)"""
    room = W_ - 2 * PAD - GAP * (len(items) - 1)
    h = min(max_h, room / sum(im.width / im.height for im, _ in items))
    panels = []
    for im, cap in items:
        w = max(1, round(im.width * h / im.height))
        panels.append(captioned(im.resize((w, round(h)), Image.LANCZOS), cap, w))
    out = Image.new('RGB', (W_, max(p.height for p in panels)), PAPER)
    x = PAD + (room - sum(p.width for p in panels) + GAP * 0) // 2
    for p in panels:
        out.paste(p, (x, 0))
        x += p.width + GAP
    return out


def heading(text, note=''):
    lines = wrap(note, F_SUB, W_ - 2 * PAD) if note else []
    out = Image.new('RGB', (W_, 44 + 21 * len(lines)), PAPER)
    d = ImageDraw.Draw(out)
    d.line([PAD, 4, W_ - PAD, 4], fill=RULE, width=2)
    d.text((PAD, 12), text, font=F_HEAD, fill=INK)
    for i, t in enumerate(lines):
        d.text((PAD, 44 + 21 * i), t, font=F_SUB, fill=MUTED)
    return out


blocks = []
title = Image.new('RGB', (W_, 104), PAPER)
d = ImageDraw.Draw(title)
d.text((PAD, 16), 'R157 HUD, as built: pity bars v2, reveal fixes, DAILY + INVITE in the MENU wheel', font=F_TITLE, fill=INK)
for i, t in enumerate(wrap('Drawn from this branch\'s real src/ on the Roblox mock with the R156 preview scripts (no patch). APPROXIMATE, not a Studio screenshot: slots, balances, '
                          'status, jump / stick, BONUS ROLL and Roblox\'s top bar are stand-ins; the world is a stand-in garden.', F_SUB, W_ - 2 * PAD)):
    d.text((PAD, 58 + 20 * i), t, font=F_SUB, fill=MUTED)
blocks.append(title)

# 1. bars
blocks.append(heading('1. Pity bars v2: shade "Fresh" only, the clover, 8 px over the slots on a PC (6 on a phone), the name rows above the bars',
                      'NORMAL = clover green, EVENT = gold with a clover-green rim; the lucky pop and its shine in the bar\'s own colours; the event notice / tag carry a gold star.'))
blocks.append(row([(png('bars_pc_name'), 'PC 1920 x 1080: the held item\'s name + traits rows right above the bars, the bars 8 px over the slots'),
                   (png('bars_pc_pop_e'), 'PC: the event bar\'s lucky pop (gold, clover-green rim), its shine in the bar\'s own colours')], 330))
blocks.append(row([(png('bars_pc_zoom_99'), 'PC, 3x: the clover on its dark disc at the left end of both bars; NORMAL 9/10 (clover green), EVENT 9/10 (gold, clover-green rim)')], 170))
blocks.append(row([(png('bars_land_evheld'), 'Landscape phone 844 x 390: event pack in hand (6 px gap, name rows above)'),
                   (png('bars_port_held9'), 'Portrait phone 390 x 844 (bottom part): 6 px gap, name rows above'),
                   (png('bars_pc_bonus'), 'PC: BONUS ROLL clear of the bars and the name rows')], 330))

# 2. reveal
fit = {v: lines_of(v, 'FIT') for v in ('pc', 'land', 'port')}
pill = {v: lines_of(v, 'PILL') for v in ('pc', 'land', 'port')}
guide = {}
for v in ('pc', 'land', 'port'):
    for line in open(os.path.join(S, 'rev', 'cl', 'frames_%s.txt' % v), encoding='utf-8'):
        if line.startswith('GUIDE '):
            guide[v] = json.loads(line.split(' ', 2)[2])


def fitcap(v, label):
    f = fit[v].get('common_res')
    if not f:
        return label
    return '%s: card fitted to %d..%d px (BASE / TRACK end %d, bars + name rows start %d), k %.2f; "%s" right under the name' % (
        label, f['top'], f['bottom'], guide[v]['travel'], guide[v]['pity'], f['k'], 'click to collect!' if v == 'pc' else 'tap to collect!')


def pillcap(v, label):
    p = pill[v].get('scene_skip')
    return '%s: SKIP %d px from the right and %d px from the bottom' % (label, p['right'], p['bottom']) if p else label


blocks.append(heading('2. Reveal fixes: SKIP only for Secret / Cosmic / King, the card fitted between BASE / TRACK and the bars, the hint under the name',
                      'Common..Mythic: no SKIP pill (click / tap / Enter / B / R2 still collect once the result shows). Story scenes: the pill in the safe area\'s corner, 14 px in.'))
blocks.append(row([(frame('pc', 'common_res'), fitcap('pc', 'PC, Common card waiting')),
                   (frame('land', 'common_res'), fitcap('land', 'Landscape phone, Common')),
                   (frame('port', 'common_res'), fitcap('port', 'Portrait phone, Common'))], 420))
blocks.append(row([(frame('pc', 'scene_skip'), pillcap('pc', 'PC, Cosmic story scene')),
                   (frame('land', 'scene_skip'), pillcap('land', 'Landscape phone, King story scene')),
                   (frame('port', 'scene_skip'), pillcap('port', 'Portrait phone, Secret story scene'))], 420))

# 3. wheel
blocks.append(heading('3. DAILY + INVITE in the MENU wheel: five options in a half circle; BASE / TRACK alone in the top row',
                      'Closed: a daily reward waits -> one red "!" on MENU (the friend "+%" chip sits beside MENU when a friend boost is on). Open: SETTINGS, INDEX, SHOP, DAILY (badge on its '
                      'top-right like INDEX), INVITE.'))
blocks.append(row([(png('wheel_pc_closed'), 'PC 1920 x 1080, closed: MENU with its "!"'),
                   (png('wheelzoom_pc_closed'), 'PC, 2x: one red "!" on MENU (a daily reward waits)'),
                   (png('wheelzoom_pc_open'), 'PC, 2x, open: SETTINGS, INDEX (2), SHOP, DAILY (its badge top-right, like INDEX), INVITE'),
                   (png('wheel_pc_open'), 'PC, open: DAILY down-right, INVITE straight down')], 330))
blocks.append(row([(png('wheel_land_closed'), 'Landscape 844 x 390, closed'), (png('wheel_land_open'), 'Landscape, open (MENU moved up 41 px)'),
                   (png('wheel_port_closed'), 'Portrait 390 x 844, closed'), (png('wheel_port_open'), 'Portrait, open')], 420))

H = sum(b.height for b in blocks) + 10 * (len(blocks) - 1) + PAD
sheet = Image.new('RGB', (W_, H), PAPER)
y = 0
for b in blocks:
    sheet.paste(b, (0, y))
    y += b.height + 10
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
