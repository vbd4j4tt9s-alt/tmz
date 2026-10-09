"""R156 preview: the SCENE lines of title_tips_scene156.luau (one log per view) -> PNGs with headless Chromium (render_gui156.mjs, R155's renderer with a font-load fix) -> docs/proposals/R156/title_tips.png.
Usage: python3 make_sheet156.py SCRATCH OUT.png   (run_title_tips156.sh calls it)
APPROXIMATE, not a Studio screenshot: the title (letters, tip line, button, Shade veil) is the real GUI tree of TitleScreen104 (+ the tip line) on the Roblox mock, laid out by its own code
at each size; Chromium draws it (Fredoka One when the font package is there, the game's own font). Stand-ins: the blurred hub behind (a crop of the three.js hub render
docs/proposals/R151/snow_hub.png, blurred; the game's real blur is a BlurEffect of size 18 over the live hub) and the green seed pack (the game draws a 3D ViewportFrame)."""
import base64
import json
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
VIEWS = {'pc': (1920, 1080), 'land': (844, 390), 'port': (390, 844)}
os.makedirs(os.path.join(S, 'png'), exist_ok=True)

# the stand-in seed pack: a tilted green chip-bag pack with crimped ends and a leaf (the title's own pack is tilted -0.12 rad about its roll axis)
PACK = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 280 500">
<defs><linearGradient id="b" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#2f9a3c"/><stop offset=".45" stop-color="#6fdc57"/><stop offset="1" stop-color="#2a8c39"/></linearGradient>
<pattern id="c" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="8" height="8" fill="#b9f08c"/><rect width="4" height="8" fill="#8fd96a"/></pattern></defs>
<g transform="rotate(-8 140 250)" stroke="#17250f" stroke-width="6" stroke-linejoin="round">
<ellipse cx="140" cy="478" rx="92" ry="12" fill="#000" opacity=".25" stroke="none"/>
<rect x="38" y="36" width="204" height="34" rx="4" fill="url(#c)"/>
<path d="M40 70 C14 150 14 350 40 430 L240 430 C266 350 266 150 240 70 Z" fill="url(#b)"/>
<rect x="38" y="430" width="204" height="34" rx="4" fill="url(#c)"/>
<g stroke="none"><ellipse cx="86" cy="190" rx="16" ry="90" fill="#fff" opacity=".22"/>
<path d="M140 150 C190 170 200 235 140 300 C80 235 90 170 140 150 Z" fill="#fff6c7" stroke="#17250f" stroke-width="5"/>
<path d="M140 170 L140 290" stroke="#58a23f" stroke-width="6" fill="none"/><path d="M140 215 L168 195 M140 245 L112 225 M140 262 L170 240" stroke="#58a23f" stroke-width="4" fill="none"/></g>
<text x="140" y="352" font-family="Fredoka, sans-serif" font-size="40" text-anchor="middle" fill="#fff6c7" stroke="#17250f" stroke-width="7" paint-order="stroke">SEEDS</text>
</g></svg>'''
PACK_URI = 'data:image/svg+xml;base64,' + base64.b64encode(PACK.encode()).decode()

# the blurred hub behind each view: a cover crop of the repo's hub render, blurred
hub = Image.open(os.path.join(REPO, 'docs/proposals/R151/snow_hub.png')).convert('RGB').crop((796, 106, 1556, 534))
bgs = {}
for view, (w, h) in VIEWS.items():
    scale = max(w / hub.width, h / hub.height)
    im = hub.resize((round(hub.width * scale), round(hub.height * scale)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    im = im.crop((x, y, x + w, y + h)).filter(ImageFilter.GaussianBlur(w * 0.0065 + 3))
    path = os.path.join(S, 'png', 'hub_' + view + '.jpg')
    im.save(path, quality=92)
    bgs[view] = "url('file://%s') center / cover no-repeat" % path

scenes, info = [], {}
for view in VIEWS:
    for line in open(os.path.join(S, view, 'scenes.log'), encoding='utf-8'):
        if line.startswith('SCENE '):
            head, backdrop, title = line.rstrip('\n').split('\t')
            name = head.split(' ', 1)[1]
            b, t = json.loads(backdrop), json.loads(title)
            t['kids'] = b['kids'] + t['kids']  # the Shade veil first, then the title content
            scenes.append({'name': name, 'json': json.dumps(t), 'scale': 1, 'bg': bgs[view], 'img': PACK_URI})
        elif line.startswith('TIP '):
            m = re.match(r'TIP (\w+) (\w+) (\w+) alpha=([\d.]+) layout: (.*?) \| (.*)$', line.rstrip('\n'))
            info[m.group(2)] = {'kind': m.group(3), 'alpha': float(m.group(4)), 'layout': m.group(5), 'text': m.group(6)}
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
render = os.path.join(HERE, 'render_gui156.mjs')
subprocess.run(['node', render, os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)


def font(px, fredoka=False):
    if fredoka:
        try:
            return ImageFont.truetype(os.path.join(FONTS, 'fredoka-one-latin-400-normal.woff'), px)
        except Exception:
            pass
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if fredoka else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', px)


def png(name, width=None, crop=None):
    im = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')
    if crop:
        im = im.crop(crop)
    if width and im.width != width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    return im


INK, PAPER, MUTED, CARD = (24, 28, 44), (246, 247, 251), (92, 100, 124), (255, 255, 255)
KIND = {'howto': ('HOW-TO (checked in the code)', (46, 150, 66)), 'lore': ('LORE / OMINOUS', (126, 70, 214)), 'egg': ('EASTER EGG (owner\'s line)', (226, 130, 24))}
W_SHEET, M = 2400, 40
sheet = Image.new('RGB', (W_SHEET, 3600), PAPER)
d = ImageDraw.Draw(sheet)


def text(x, y, s, px, color=INK, fredoka=False, anchor='la'):
    d.text((x, y), s, font=font(px, fredoka), fill=color, anchor=anchor)


def chip(x, y, kind):
    label, color = KIND[kind]
    f = font(17)
    w = d.textlength(label, font=f) + 24
    d.rounded_rectangle((x, y, x + w, y + 30), 15, fill=color)
    d.text((x + 12, y + 15), label, font=f, fill=(255, 255, 255), anchor='lm')
    return x + w + 10


def frame(im, x, y, kind, caption, width_for_caption):
    d.rounded_rectangle((x - 4, y - 4, x + im.width + 4, y + im.height + 4), 8, fill=KIND[kind][1])
    sheet.paste(im, (x, y))
    cy = y + im.height + 10
    chip(x, cy, kind)
    # wrapped caption
    f = font(16)
    words, line, lines = caption.split(), '', []
    for wd in words:
        trial = (line + ' ' + wd).strip()
        if d.textlength(trial, font=f) > width_for_caption:
            lines.append(line);line = wd
        else:
            line = trial
    lines.append(line)
    for i, ln in enumerate(lines):
        d.text((x, cy + 38 + i * 21), ln, font=f, fill=MUTED)
    return cy + 38 + len(lines) * 21


y = 28
text(M, y, 'STEAL A PACK: tips on the title screen, Style B (the owner\'s pick)', 46, INK, True)
y += 62
text(M, y, 'PREVIEW, not a release. The title is the real TitleScreen104 on the Roblox mock plus a "tip:" line above Click to play!; a new tip every 5 s with a 0.35 s fade (no fade with Reduced Motion).', 21, MUTED)
y += 30
text(M, y, 'APPROXIMATE, not a Studio screenshot: the blurred hub is a stand-in (a blurred crop of an earlier hub render) and the green pack is a stand-in for the 3D pack; everything else is drawn from the real GUI tree.', 21, MUTED)
y += 42
x = M
for k in ('howto', 'lore', 'egg'):
    x = chip(x, y, k)
text(x + 12, y + 4, 'Each frame\'s frame colour = the tip\'s kind. Three kinds are mixed in each rotation.', 18, MUTED)
y += 56

# ---- PC -------------------------------------------------------------------------------------------------------------------------
text(M, y, 'PC 1920 x 1080', 30, INK, True)
y += 44
big = png('pc_1', 1150)
sheet_y = y
frame(big, M, y, info['pc_1']['kind'], 'tip 1 settled (the whole screen): the line sits just above the button, clear of the logo, the pack and the button. ' + info['pc_1']['layout'], 1150)
sx = M + 1150 + 40
sy = y
STRIP = (0, 700, 1920, 1080)
for name, label in (('pc_2', 'tip 2 settled, 5 s later (lore)'), ('pc_3', 'tip 3 (the easter egg)'), ('pc_fade', 'mid-fade: 4.8 s into a tip, the line is ~50% see-through')):
    im = png(name, 1130, STRIP)
    bottom = frame(im, sx, sy, info[name]['kind'], label + ' (bottom of the screen)', 1130)
    sy = bottom + 16
y = max(sy, sheet_y + big.height + 120) + 24

# ---- landscape phone (native size, 2 x 2) + how it behaves ------------------------------------------------------------------------------------
text(M, y, 'Landscape phone 844 x 390 (the logo is ~11% smaller here to make room; nothing is covered)', 30, INK, True)
y += 44
gy = y
bottoms = []
for i, (name, label) in enumerate((('land_1', 'tip 1 settled: the longest tip fits on one line'), ('land_2', 'tip 2 settled (lore)'),
                                   ('land_3', 'tip 3 (the easter egg)'), ('land_fade', 'mid-fade: ~50% see-through'))):
    im = png(name)
    x = M + (i % 2) * (844 + 28)
    yy = gy + (i // 2) * (390 + 100)
    bottoms.append(frame(im, x, yy, info[name]['kind'], label, 844))
nx = M + 2 * (844 + 28) + 16
panel_h = max(bottoms) - gy
d.rounded_rectangle((nx, gy, W_SHEET - M, gy + panel_h), 16, fill=CARD, outline=(214, 218, 230), width=2)
notes = [
    ('How it behaves', None),
    ('A tip every 5 s: it fades in over 0.35 s, holds, fades out over the last 0.35 s; the text changes while it is invisible.', 1),
    ('The first tip of a visit is random; the rest follow in a shuffled order, so no tip repeats before every tip has shown.', 1),
    ('Reduced Motion: no fade. The text just changes every 5 s.', 1),
    ('It lives in the title\'s CanvasGroup: it fades in with the title, fades out when u click, and never takes a click.', 1),
    ('One line on a PC / landscape phone, two on a portrait phone; the text shrinks to fit (11 to 32 px).', 1),
    ('PC and portrait phone: the logo, the pack and the button stay exactly where they are today. Landscape phone: the logo is ~11% smaller (422 px wide, was 477) to make room.', 1),
    ('The tip list is one module, TitleTips156 (ReplicatedStorage): add a tip = add one line.', 1),
]
ty = gy + 20
f = font(18)
for s_, bullet in notes:
    if bullet is None:
        d.text((nx + 24, ty), s_, font=font(26, True), fill=INK);ty += 44
        continue
    words, line, lines = s_.split(), '', []
    for wd in words:
        trial = (line + ' ' + wd).strip()
        if d.textlength(trial, font=f) > W_SHEET - M - nx - 70:
            lines.append(line);line = wd
        else:
            line = trial
    lines.append(line)
    d.text((nx + 24, ty), '-', font=f, fill=MUTED)
    for ln in lines:
        d.text((nx + 44, ty), ln, font=f, fill=INK);ty += 25
    ty += 10
y = max(bottoms) + 28

# ---- portrait phone (native size) + the whole tip list --------------------------------------------------------------------------------------
text(M, y, 'Portrait phone 390 x 844 (a long tip wraps to two lines; the logo and the pack are unchanged)', 30, INK, True)
y += 44
x = M
bottom = y
for name, label in (('port_1', 'tip 1 settled: a long tip wraps to 2 lines'), ('port_2', 'tip 2 settled (lore)'), ('port_3', 'tip 3 (the easter egg)'), ('port_fade', 'mid-fade: ~50% see-through')):
    im = png(name)
    bottom = max(bottom, frame(im, x, y, info[name]['kind'], label, 390))
    x += 390 + 26
nx = x + 14
tips = re.findall(r"\{Kind='(\w+)',Text='((?:[^'\\]|\\.)*)'\}", open(os.path.join(HERE, 'TitleTips156.lua'), encoding='utf-8').read())
tips = [(k, t.replace("\\'", "'")) for k, t in tips]
d.rounded_rectangle((nx, y, W_SHEET - M, bottom), 16, fill=CARD, outline=(214, 218, 230), width=2)
ty = y + 18
d.text((nx + 24, ty), 'All %d tips (TitleTips156.lua)' % len(tips), font=font(26, True), fill=INK)
ty += 34
d.text((nx + 24, ty), '(the emoji some tips carry are left out of this list)', font=font(14), fill=MUTED)
ty += 26
for kind in ('howto', 'lore', 'egg'):
    chip_x = nx + 24
    chip(chip_x, ty, kind)
    ty += 40
    for k, t in tips:
        if k != kind:
            continue
        d.text((nx + 30, ty), 'tip: ' + re.sub('[\U0001F000-\U0001FFFF\u2600-\u27BF\u2B00-\u2BFF]', '', t).strip(), font=font(15), fill=INK)
        ty += 21
    ty += 12
y = bottom + 28
text(M, y, 'docs/proposals/R156/title_tips.md has the tip list with each tip\'s source file, the timings and how the tips are stored. Made by docs/proposals/R156/preview/run_title_tips156.sh.', 18, MUTED)
y += 40
sheet = sheet.crop((0, 0, W_SHEET, y))
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
