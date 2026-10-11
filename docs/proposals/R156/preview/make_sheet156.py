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
        elif line.startswith('TIP\t'):
            _, name, kind, alpha, scale, bob, layout, label = line.rstrip('\n').split('\t')
            info[name] = {'kind': kind, 'alpha': float(alpha), 'scale': float(scale), 'bob': float(bob), 'layout': json.loads(layout), 'label': label}
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
render = os.path.join(HERE, 'render_gui156.mjs')
subprocess.run(['node', render, os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)

# the tip list, with its mini-markup ({y}..{/y} yellow, {g}..{/g} green)
TIPS = [(k, t.replace("\\'", "'")) for k, t in re.findall(r"\{Kind='(\w+)',Text='((?:[^'\\]|\\.)*)'\}", open(os.path.join(HERE, 'TitleTips156.lua'), encoding='utf-8').read())]
HI = {'y': (255, 225, 77), 'g': (119, 229, 66)}


def segments(text):
    """[(string, colour letter or None)] from the mini-markup, emoji removed (the sheet's own font has none)."""
    out, pos = [], 0
    for m in re.finditer(r'\{([yg])\}(.*?)\{/\1\}', text):
        if m.start() > pos:
            out.append((text[pos:m.start()], None))
        out.append((m.group(2), m.group(1)))
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], None))
    return [(re.sub('[\U0001F000-\U0001FFFF☀-➿⬀-⯿]', '', s_), c) for s_, c in out]


def plain(text):
    return ''.join(s_ for s_, _ in segments(text)).strip()


def highlighted(frame):
    """The highlighted words of the tip a frame shows (from the label's RichText)."""
    return [re.sub(r'<[^>]+>', '', m) for m in re.findall(r'<font color="#(?:FFE14D|77E542)">(.*?)</font>', info[frame]['label'])]


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
sheet = Image.new('RGB', (W_SHEET, 4200), PAPER)
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


def wrap(s, f, width):
    words, line, lines = s.split(), '', []
    for wd in words:
        trial = (line + ' ' + wd).strip()
        if d.textlength(trial, font=f) > width:
            lines.append(line);line = wd
        else:
            line = trial
    lines.append(line)
    return lines


def frame(im, x, y, name, caption, width_for_caption, kind=None):
    kind = kind or info[name]['kind']
    d.rounded_rectangle((x - 4, y - 4, x + im.width + 4, y + im.height + 4), 8, fill=KIND[kind][1])
    sheet.paste(im, (x, y))
    cy = y + im.height + 10
    chip(x, cy, kind)
    f = font(16)
    words = highlighted(name)
    if words:
        caption += ' Highlighted: ' + ', '.join(words) + '.'
    lines = wrap(caption, f, width_for_caption)
    for i, ln in enumerate(lines):
        d.text((x, cy + 38 + i * 21), ln, font=f, fill=MUTED)
    return cy + 38 + len(lines) * 21


def panel(x0, y0, x1, y1, dark=False):
    d.rounded_rectangle((x0, y0, x1, y1), 16, fill=(22, 32, 28) if dark else CARD, outline=(214, 218, 230) if not dark else (60, 80, 70), width=2)


def bullets(x, y, items, width, color=INK, px=18):
    f = font(px)
    for s_ in items:
        lines = wrap(s_, f, width - 20)
        d.text((x, y), '-', font=f, fill=MUTED)
        for ln in lines:
            d.text((x + 20, y), ln, font=f, fill=color);y += px + 7
        y += 9
    return y


L1 = info['land_1']['layout']
LP = info['port_1']['layout']
LC = info['pc_1']['layout']
y = 28
text(M, y, 'STEAL A PACK: tips on the title screen, Style B (the owner\'s pick), second round', 46, INK, True)
y += 62
for ln in wrap('PREVIEW, not a release. The tip floats in the middle of the gap between the logo (with the pack) and Click to play!, a new one every 10 s with a fade, pulsing a little like Minecraft\'s splash, '
               'with 1-2 highlighted words in yellow or green. Simple words (3rd grade), the game\'s own words. The title is the real TitleScreen104 on the Roblox mock; the blurred hub and the green pack are '
               'stand-ins. APPROXIMATE, not a Studio screenshot.', font(21), W_SHEET - 2 * M):
    text(M, y, ln, 21, MUTED)
    y += 28
y += 14
x = M
for k in ('howto', 'lore', 'egg'):
    x = chip(x, y, k)
text(x + 12, y + 4, 'The frame colour is the tip\'s kind.  Highlights:', 18, MUTED)
x += 12 + d.textlength('The frame colour is the tip\'s kind.  Highlights:', font=font(18)) + 14
for letter, label in (('y', 'yellow = the key thing'), ('g', 'green = what it gives / does')):
    d.rounded_rectangle((x, y, x + d.textlength(label, font=font(17)) + 24, y + 30), 15, fill=(22, 32, 28))
    d.text((x + 12, y + 15), label, font=font(17), fill=HI[letter], anchor='lm')
    x += d.textlength(label, font=font(17)) + 36
y += 56

# ---- PC -------------------------------------------------------------------------------------------------------------------------
text(M, y, 'PC 1920 x 1080', 30, INK, True)
y += 44
big = png('pc_1', 1150)
pc_top = y
bottom_left = frame(big, M, y, 'pc_1', 'tip 1 settled: the line floats in the middle of the gap between the logo with the pack (bottom %d) and the button (top %d), %d px of air above and below; the logo, pack and button are exactly where they are today.' % (LC['logoBottom'], LC['buttonTop'], (LC['gap'] - LC['tipH']) / 2), 1150)
# the two pulse frames: the line at its largest (+5%) and its smallest (-5%), cropped around the line at the same size
y2 = bottom_left + 14
PULSE = (460, int(LC['tipY']) - 48, 1460, int(LC['tipY']) + 48)
for name, label in (('pc_big', 'zoomed in on the line - pulse, largest: scale %.2f (a full breath every 0.5 s)' % info['pc_big']['scale']), ('pc_small', 'zoomed in - pulse, smallest: scale %.2f (same tip, 0.25 s later)' % info['pc_small']['scale'])):
    im = png(name, 1150, PULSE)
    y2 = frame(im, M, y2, name, label + '.', 1150) + 14
right_x = M + 1150 + 40
sy = pc_top
STRIP = (0, 640, 1920, 1080)
for name, label in (('pc_2', 'tip 2 settled, one interval (10 s) later (lore); bottom of the screen'), ('pc_3', 'tip 3 (the easter egg)'), ('pc_fade', 'mid-fade: 9.8 s into a tip, the line is 50% see-through')):
    im = png(name, 1130, STRIP)
    sy = frame(im, right_x, sy, name, label + '.', 1130) + 16
y = max(sy, y2) + 24

# ---- landscape phone (native size, 2 x 2) + how it behaves ------------------------------------------------------------------------------------
text(M, y, 'Landscape phone 844 x 390 (the logo is %d%% smaller here to make room; nothing is covered)' % round(100 - 100 * L1['logoW'] / L1['todayLogoW']), 30, INK, True)
y += 44
gy = y
bottoms = []
for i, (name, label) in enumerate((('land_1', 'tip 1 settled: one line, centred in the gap'), ('land_2', 'tip 2 settled (lore)'), ('land_3', 'tip 3 (the easter egg)'), ('land_fade', 'mid-fade: 50% see-through'))):
    im = png(name)
    x = M + (i % 2) * (844 + 28)
    yy = gy + (i // 2) * (390 + 120)
    bottoms.append(frame(im, x, yy, name, label + '.', 844))
nx = M + 2 * (844 + 28) + 16
panel(nx, gy, W_SHEET - M, max(bottoms))
d.text((nx + 24, gy + 18), 'How it behaves', font=font(26, True), fill=INK)
bullets(nx + 24, gy + 62, [
    'Where: vertically centred in the gap between the bottom of the logo (the pack art is inside it) and the top of the button. The gap is kept at least the line\'s height + 20 px, so the pulse and the bob never touch the logo or the button.',
    'When: a new tip every 10 s. It fades in over 0.4 s, holds, fades out over the last 0.4 s; the text changes while it is invisible. The first tip of a visit is random, then a shuffled order (no repeats until all have shown).',
    'Motion: a gentle splash pulse, +-5% in size, a full breath every 0.5 s, plus a 1.5 px bob (a slow 1.9 s). Reduced Motion: no pulse, no bob and no fade; the text just changes every 10 s.',
    'Highlights: write {y}word{/y} (yellow #FFE14D) or {g}word{/g} (green #77E542, the title\'s PACK green) in the tip\'s text in TitleTips156; the title turns it into RichText. The rest is white with the title\'s dark outline.',
    'Size: one line on a PC / landscape phone, two on a portrait phone; the text shrinks to fit (11 to 32 px). The label takes no clicks.',
    'PC and portrait phone: the logo, pack and button stay exactly where they are today. Landscape phone: the logo is %d px wide (was %d) to make the room.' % (L1['logoW'], L1['todayLogoW']),
], W_SHEET - M - nx - 48)
y = max(bottoms) + 28

# ---- portrait phone (native size) + the whole tip list --------------------------------------------------------------------------------------
text(M, y, 'Portrait phone 390 x 844 (a long tip wraps to two lines; the logo and the pack are unchanged)', 30, INK, True)
y += 44
x = M
bottom = y
for name, label in (('port_1', 'tip 1 settled: a long tip wraps to 2 lines'), ('port_2', 'tip 2 settled (lore)'), ('port_3', 'tip 3 (the easter egg)'), ('port_fade', 'mid-fade: 50% see-through')):
    im = png(name)
    bottom = max(bottom, frame(im, x, y, name, label + '.', 390))
    x += 390 + 26
nx = x + 14
panel(nx, y, W_SHEET - M, bottom, dark=True)
ty = y + 18
d.text((nx + 24, ty), 'All %d tips (TitleTips156.lua)' % len(TIPS), font=font(26, True), fill=(255, 255, 242))
ty += 34
d.text((nx + 24, ty), '(the emoji some tips carry are left out of this list)', font=font(14), fill=(160, 178, 170))
ty += 28
f15 = font(15)
for kind in ('howto', 'lore', 'egg'):
    chip(nx + 24, ty, kind)
    ty += 38
    for k, t in TIPS:
        if k != kind:
            continue
        cx = nx + 30
        for seg, c in [('tip: ', None)] + segments(t):
            d.text((cx, ty), seg, font=f15, fill=HI[c] if c else (232, 238, 244))
            cx += d.textlength(seg, font=f15)
        ty += 21
    ty += 10
y = bottom + 28
text(M, y, 'docs/proposals/R156/title_tips.md has the tip list with each tip\'s source file and highlighted words, the timings and how the tips are stored. Made by docs/proposals/R156/preview/run_title_tips156.sh.', 18, MUTED)
y += 40
sheet = sheet.crop((0, 0, W_SHEET, y))
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
