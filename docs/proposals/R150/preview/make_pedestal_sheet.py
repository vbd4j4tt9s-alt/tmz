"""Compose docs/proposals/R150/pedestal.png from render_pedestal.mjs's <before|after>_<scene>.png files.
Usage: python3 make_pedestal_sheet.py <render dir> <out.png> [base commit label]"""
import os, sys, textwrap
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
base = sys.argv[3] if len(sys.argv) > 3 else '3ae5bb4'
PAD, HEAD = 16, 120
CW, CH = 560, 402           # a state cell
BW, BH = 850, 491           # a base-wide cell


def font(size, bold=False):
    for name in (['DejaVuSans-Bold.ttf'] if bold else []) + ['DejaVuSans.ttf']:
        for d in ('/usr/share/fonts/truetype/dejavu', '/usr/share/fonts/dejavu', '/usr/share/fonts'):
            p = os.path.join(d, name)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load(which, name, size):
    p = os.path.join(src, '%s_%s.png' % (which, name))
    if not os.path.exists(p):
        im = Image.new('RGB', size, (40, 44, 56))
        d = ImageDraw.Draw(im)
        d.text((14, size[1] // 2 - 8), '(not rendered: no %s)' % name, fill=(180, 186, 198), font=font(15))
        return im
    return Image.open(p).convert('RGB').resize(size, Image.LANCZOS)


# Each section: title, caption, list of rows [(row label, which, [scene names])], cell size
SECTIONS = [
    ('1. The three states', 'A player standing 30 studs from the pedestal in the base corner (the Forest treadmill: the pedestal wears the same biome).',
     [('BEFORE (R149)', 'before', ['locked_near', 'ready_near', 'taken_near']), ('AFTER (R150)', 'after', ['locked_near', 'ready_near', 'taken_near'])],
     ['LOCKED: the silhouette pack, a calm violet glow, a dim halo of 8 gems orbiting it, faint wisps, a padlock on the column',
      'UNLOCKED: the pad and gems light up gold, the halo goes gold and fast, sparkles rise, a light column over your own pack',
      'TAKEN: no pack, the glow is a dim mint ember, no fx; the sign says to come back tomorrow'], (CW, CH)),
    ('2. Close-ups', 'The column front (the padlock), the pack with its halo and the sign, and the same unlocked.',
     [('BEFORE (R149)', 'before', ['locked_front', 'locked_top', 'ready_top']), ('AFTER (R150)', 'after', ['locked_front', 'locked_top', 'ready_top'])],
     ['LOCKED, the column: a chunky gold padlock hangs on the front, facing the aisle', 'LOCKED, the pack: the silhouette, the dim halo, the pill sign (caption / big timer / bar)',
      'UNLOCKED, the pack: gold halo, sparkles, a soft light column, the gold pill'], (CW, CH)),
    ('3. The unlock moment', '0.12 s, 0.3 s and 0.6 s after it unlocks: the padlock pops open and drops, a ring + flash + sparks, the pack hops, the sign pops (once, only for your own pedestal).',
     [('BEFORE (R149): ring + sparks', 'before', ['unlock_a2', 'unlock_b2', 'unlock_c2']), ('AFTER, the pack', 'after', ['unlock_a2', 'unlock_b2', 'unlock_c2']),
      ('AFTER, the padlock', 'after', ['unlock_a', 'unlock_b', 'unlock_c'])],
     ['+0.12 s', '+0.3 s', '+0.6 s'], (CW, CH)),
    ('4. Taking it', '0.1 s, 0.35 s and 0.55 s after the take: the pack lifts off the pedestal and flies to the player (the harvest-flight arc), shrinking, with a whoosh and then the pack pickup sound.',
     [('BEFORE (R149): ring + sparks', 'before', ['take_a', 'take_b', 'take_c']), ('AFTER (R150)', 'after', ['take_a', 'take_b', 'take_c'])],
     ['+0.1 s: it lifts off', '+0.35 s: it flies to the player', '+0.55 s: it lands (a pop of sparks)'], (CW, CH)),
]
BIOMES = [(1, 'Forest'), (6, 'Jungle'), (2, 'Desert'), (3, 'Snow'), (4, 'Lava'), (5, 'Crystal'), (7, 'Storm')]
TW, TH = 392, 281

W_ = PAD * 4 + CW * 3
rows_h = 0
for title, cap, rows, notes, (cw, ch) in SECTIONS:
    rows_h += 70 + len(rows) * (ch + 34) + 34 + PAD + 40
rows_h += 70 + 2 * (TH + 30) + PAD                 # biomes (two lines of thumbnails)
rows_h += 70 + 2 * (BH + 34) + 34 + PAD            # base-wide, two states
H = HEAD + rows_h + 50
sheet = Image.new('RGB', (W_, H), (24, 28, 36))
d = ImageDraw.Draw(sheet)
d.text((PAD, 14), 'R150 mystery pack pedestal: before (R149) and after', fill=(255, 255, 255), font=font(30, True))
d.text((PAD, 58), 'Polish only: a sculpted, biome-coloured pedestal; states you can read from far away (calm locked, lit unlocked, dim taken); a friendlier sign; an unlock moment and a take flight.',
       fill=(210, 215, 225), font=font(16))
d.text((PAD, 84), 'Gameplay, timings and odds are unchanged. The sign is the same size, place and ranges as R148 (above the pack, shrinks with distance, hides past 90 / 120 studs).',
       fill=(210, 215, 225), font=font(16))


def tag(x, y, text, color=(0, 0, 0)):
    tw = d.textlength(text, font=font(14, True))
    d.rectangle([x + 8, y + 8, x + 20 + tw, y + 30], fill=color)
    d.text((x + 14, y + 11), text, fill=(255, 255, 255), font=font(14, True))


y = HEAD
for title, cap, rows, notes, (cw, ch) in SECTIONS:
    d.text((PAD, y), title, fill=(255, 236, 170), font=font(22, True))
    d.text((PAD, y + 32), cap, fill=(200, 205, 215), font=font(14))
    y += 70
    for r, (label, which, names) in enumerate(rows):
        for k, name in enumerate(names):
            x = PAD + k * (cw + PAD)
            sheet.paste(load(which, name, (cw, ch)), (x, y))
            tag(x, y, label, (0, 0, 0) if which == 'before' else (20, 90, 50))
        y += ch + 34
    lines = 1
    for k, note in enumerate(notes):
        wrapped = textwrap.wrap(note, width=int(cw / 7.2)) or ['']
        lines = max(lines, len(wrapped))
        for j, ln in enumerate(wrapped):
            d.text((PAD + k * (cw + PAD), y - 28 + j * 17), ln, fill=(190, 196, 208), font=font(13))
    y += 34 - 28 + (lines - 1) * 17 + PAD
# biomes
d.text((PAD, y), '5. The pedestal in each biome\'s colours (AFTER)', fill=(255, 236, 170), font=font(22, True))
d.text((PAD, y + 32), 'It wears the colours and body material of the player\'s best treadmill, taken from the treadmill\'s own theme (Forest wood, Jungle gold, Desert sandstone, Snow ice, Lava basalt, Crystal glass, Storm metal).',
       fill=(200, 205, 215), font=font(14))
y += 70
for i, (stage, name) in enumerate(BIOMES):
    x = PAD + (i % 4) * (TW + PAD)
    yy = y + (i // 4) * (TH + 30)
    sheet.paste(load('after', 'biome_%d' % stage, (TW, TH)), (x, yy))
    tag(x, yy, name, (20, 90, 50))
y += 2 * (TH + 30) + PAD
# base-wide
d.text((PAD, y), '6. In the base (the owner\'s real base from the place file, seen from inside the garden: the treadmill is on the right, the bonus board stands behind the pedestal)', fill=(255, 236, 170), font=font(22, True))
d.text((PAD, y + 32), 'Left to right: LOCKED, UNLOCKED. The sign is small and hangs above the pack at this distance (about 50 studs), as in R148.', fill=(200, 205, 215), font=font(14))
y += 70
for label, which in (('BEFORE (R149)', 'before'), ('AFTER (R150)', 'after')):
    for k, name in enumerate(('locked', 'ready')):
        x = PAD + k * (BW + PAD)
        sheet.paste(load(which, name, (BW, BH)), (x, y))
        tag(x, y, '%s: %s' % (label, 'LOCKED' if name == 'locked' else 'UNLOCKED'), (0, 0, 0) if which == 'before' else (20, 90, 50))
    y += BH + 34
d.text((PAD, y + 4), 'Approximate three.js render of the real MysteryPackService / MysteryPedestalArt / MysteryPackClient / MysteryPedestalFx on the Roblox mock (base commit %s = BEFORE). '
       'No Roblox materials, textures or lighting; the pack is a stand-in pouch.' % base, fill=(160, 166, 178), font=font(13))
sheet = sheet.crop((0, 0, W_, y + 34))
sheet.save(out, optimize=True)
print('wrote', out, sheet.size)
