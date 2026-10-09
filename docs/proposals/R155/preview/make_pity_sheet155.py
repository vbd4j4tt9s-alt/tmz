"""R155 preview: the SCENE lines of pity_scene155.luau (one log per view) -> PNGs with headless Chromium (render_gui155.mjs) -> docs/proposals/R155/pity_bars.png.
Usage: python3 make_pity_sheet155.py SCRATCH OUT.png   (run_pity_preview155.sh calls it)
APPROXIMATE: the bars, the notices and the reveal card are the real GUI trees on the Roblox mock; the hotbar, balances, status, MENU, BASE / TRACK and the touch
controls are stand-ins placed by HudLayout's metrics; the sky is a plain gradient; Chromium draws the trees (Fredoka One when the font package is there)."""
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

S, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
SKY = 'linear-gradient(180deg,#7fc3ee 0%,#c4e6fa 44%,#86c46a 45%,#4f9a4a 100%)'


def font(px):
    for p in (os.path.join(FONTS, 'fredoka-one-latin-400-normal.woff'),):
        try:
            return ImageFont.truetype(p, px)
        except Exception:
            pass
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', px)


scenes = []
for view in ('pc', 'land', 'port'):
    for line in open(os.path.join(S, view, 'scenes.log'), encoding='utf-8'):
        if not line.startswith('SCENE '):
            continue
        parts = line.rstrip('\n').split(' ', 7)
        name, x, y, cw, ch, scale = parts[1:7]
        scenes.append({'name': name, 'json': parts[7], 'scale': float(scale), 'bg': SKY, 'crop': [int(x), int(y), int(cw), int(ch)]})
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
subprocess.run(['node', os.path.join(HERE, 'render_gui155.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)


def png(name, width=None):
    im = Image.open(os.path.join(S, 'png', name + '.png')).convert('RGB')
    if width and im.width != width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    return im


INK, PAPER, MUTED = (24, 28, 44), (246, 247, 251), (92, 100, 124)
GOLD, PURPLE = (236, 152, 22), (122, 56, 224)
blocks = []  # (title, [(image, caption)])
blocks.append(('PC (1920 x 1080): the two bars, slightly above the hotbar and the held item\'s name', [
    (png('pc_33', 600), '3/10 and 3/10: gold = normal pity, purple = event pity (Void / Verity / Mech)'),
    (png('pc_held9', 600), 'holding a normal pack: the gold bar is brighter and 1.06x; at 9/10 it glows: "next one\'s lucky!"'),
    (png('pc_99', 600), 'both at 9/10: both glow (the pulse is steady with Reduced Motion)')]))
blocks.append(('The lucky pack: the bar pops, shines, says it, then goes back to 0/10 (real frames)', [
    (png('pc_pop_013', 440), '0.13 s: full, x1.2 pop, white flash, ring'),
    (png('pc_pop_042', 440), '0.42 s: the shine sweeps across'),
    (png('pc_pop_120', 440), '1.2 s: "LUCKY PACK! x1.5 luck", draining'),
    (png('pc_pop_240', 440), '2.4 s: back to 0/10 (the event bar untouched)')]))
blocks.append(('The lucky pack\'s opening: a tag on the real reveal card, then the bar pops when the seed is collected', [
    (png('pc_reveal', 900), 'a lucky Desert Common pack opens to a Legendary: "LUCKY PACK! x1.5 luck" sits on the card between the seed and its "1 in N"; the bars step aside while the card is up (its words are where they sit)'),
    (png('land_reveal', 520), 'the same on a landscape phone (844 x 390)'),
    (png('pc_after_collect', 430), 'collected: the card goes, the bars come back and the gold one pops'),
    (png('pc_full_pop', 480), 'after a Secret+ story scene (it hides the whole HUD), or with no reveal on screen: the top notice "LUCKY PACK! x1.5 luck on this one!" and the pop'),
    (png('pc_reduced', 430), 'Reduced Motion: no pop scale, no shine, no ring; the words and a steady glow')]))
blocks.append(('Phones: the bars keep clear of the hotbar, the item name, the jump button / stick, the balances, MENU and the SKIP corner', [
    (png('land_33', 560), 'landscape phone 844 x 390: 3/10 and 3/10'),
    (png('land_held9', 560), 'holding a Limited Mech pack: the purple bar is highlighted; event 9/10 glows'),
    (png('land_pop', 560), 'a lucky event pack: the purple bar pops, the notice says "LUCKY EVENT PACK!"'),
    (png('port_33', 270), 'portrait phone 390 x 844: 3/10, 3/10'),
    (png('port_held9', 270), 'held normal pack: 9/10, glowing')]))

W_ = 1900
pad, gap = 24, 18
title_f, head_f, cap_f, foot_f = font(34), font(24), font(16), font(15)


def wrap(text, f, width, d):
    words, lines, line = text.split(), [], ''
    for w in words:
        t = (line + ' ' + w).strip()
        if d.textlength(t, font=f) > width and line:
            lines.append(line)
            line = w
        else:
            line = t
    if line:
        lines.append(line)
    return lines


probe = ImageDraw.Draw(Image.new('RGB', (10, 10)))
layout = []
y = pad + 52
for head, items in blocks:
    head_y = y
    y += 34
    x = pad
    row_h = 0
    placed = []
    for im, cap in items:
        if x + im.width > W_ - pad:
            y += row_h + gap
            x, row_h = pad, 0
        lines = wrap(cap, cap_f, im.width, probe)
        h = im.height + 6 + len(lines) * 20
        placed.append((x, y, im, lines))
        x += im.width + gap
        row_h = max(row_h, h)
    layout.append((head, placed, head_y))
    y += row_h + gap
FOOT = ('APPROXIMATE: the bars, the lucky tag, the notices and the reveal card are the real GUI trees (PityBars155, NoticeFeed83, RarePullCard) on the Roblox mock, '
        'drawn by Chromium; the hotbar, balances, status, MENU, BASE / TRACK and the touch controls are stand-ins placed by HudLayout\'s metrics. Not a Studio screenshot.')
foot_lines = wrap(FOOT, foot_f, W_ - pad * 2, probe)
H_ = y + 20 + len(foot_lines) * 20 + pad
sheet = Image.new('RGB', (W_, H_), PAPER)
d = ImageDraw.Draw(sheet)
d.text((pad, pad), 'R155 pack pity: two bars above the hotbar, always on the HUD', font=title_f, fill=INK)
lx = W_ - pad - 400
d.rectangle([lx, pad + 6, lx + 24, pad + 30], fill=GOLD)
d.text((lx + 32, pad + 4), 'normal pity', font=head_f, fill=INK)
lx += 32 + d.textlength('normal pity', font=head_f) + 28
d.rectangle([lx, pad + 6, lx + 24, pad + 30], fill=PURPLE)
d.text((lx + 32, pad + 4), 'event pity', font=head_f, fill=INK)
for head, placed, hy in layout:
    d.text((pad, hy), head, font=head_f, fill=INK)
    for x, y0, im, lines in placed:
        sheet.paste(im, (x, y0))
        d.rectangle([x - 1, y0 - 1, x + im.width, y0 + im.height], outline=(200, 204, 216))
        for i, l in enumerate(lines):
            d.text((x, y0 + im.height + 6 + i * 20), l, font=cap_f, fill=MUTED)
for i, l in enumerate(foot_lines):
    d.text((pad, y + 10 + i * 20), l, font=foot_f, fill=MUTED)
os.makedirs(os.path.dirname(os.path.abspath(OUT)), exist_ok=True)
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size)
