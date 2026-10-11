"""Usage: python3 make_growth_built_sheet.py <scenes.txt> <dir with the rendered <plant>_<row>_<moment>.png> <out.png>
One sheet: for each plant a BEFORE row and an AS BUILT row, 8 moments each, with a caption under every tile (R149 growth style, phase 1 as built).
Rows come from dump_growth_built.luau: 'today' = the base commit's PlantGrowth, 'built' = this checkout's PlantGrowth + PlantGrowthFx."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
scenes, src, out = sys.argv[1:4]
info, swatches = {}, []
for line in open(scenes, encoding='utf-8'):
    if line.startswith('INFO'):
        f = line.rstrip('\n').split('\t')
        info[f[1]] = {'name': f[3], 'seconds': f[5], 'regrow': f[7], 'fruits': f[9], 'parts': f[11]}
    elif line.startswith('SWATCHES '):
        swatches = json.loads(line[len('SWATCHES '):])
def font(size, bold=False):
    try:
        return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if bold else ''), size)
    except Exception:
        return ImageFont.load_default()
PLANTS = [('blueberry', 'Blueberry', 'bush'), ('apple', 'Apple', 'tree'), ('melon', 'Watermelon', 'ground vine')]
MOMENTS = [
    ('f0', '4 s after planting', 'close-up'),
    ('f25', '25 % grown', 'whole plant'),
    ('f50', '50 % grown', 'whole plant'),
    ('f75', '75 % grown', 'whole plant'),
    ('ripe', '100 %: ripe', 'whole plant'),
    ('harvest', 'harvest (+0.25 s)', 'close-up on the picked fruit'),
    ('regrow15', 'regrow 15 %', 'close-up'),
    ('regrow60', 'regrow 60 %', 'close-up'),
]
CAPTION = {
    'today': ['seed + a 0.1-stud sprout', '~20 % size, see-through leaves', 'leaves still see-through', 'young fruit = leaf green',
              'nothing marks the moment', 'fruit gone in one frame', 'a tiny green bud, hard to see', 'leaf green, then a muddy mix'],
    'built': ['#3 seedling springs up, leaves open', '#4 #5 ~35 % size, solid leaves', 'solid leaves, ~65 % size', '#6 pale unripe fruit, swelling',
              '#7 one bounce + glints', '#8 the fruit floats to the player', '#6 a bud, no fruit yet', '#6 pale fruit, colour comes last'],
}
TW, TH, LABEL, CAP, HEAD, GAP = 232, 255, 132, 22, 40, 4
COLS = len(MOMENTS)
W = LABEL + COLS * (TW + GAP) + 12
TITLE, COLHEAD, FOOT, SW = 92, 46, 96, 236
block = HEAD + 2 * (TH + CAP + 6)
H = TITLE + COLHEAD + len(PLANTS) * block + SW + FOOT
BG, INK, SUB, TODAY, PROP, GOLD = (24, 26, 32), (238, 241, 246), (160, 170, 186), (232, 120, 104), (120, 214, 140), (255, 214, 120)
sheet = Image.new('RGB', (W, H), BG)
d = ImageDraw.Draw(sheet)
d.text((W // 2, 14), 'Growth style, phase 1 as built: before vs now (R149)', font=font(28, True), fill=INK, anchor='ma')
d.text((W // 2, 52), 'BEFORE = the base commit\'s PlantGrowth. NOW = the real PlantGrowth + PlantGrowthFx of this checkout, built by PlantVisuals on the Roblox mock.',
       font=font(14), fill=SUB, anchor='ma')
d.text((W // 2, 70), 'Whole-plant frames share one fixed camera per plant, so sizes compare honestly. The glints and the player block are drawn as small parts here.',
       font=font(14), fill=SUB, anchor='ma')
y = TITLE
for c, (_, head, sub) in enumerate(MOMENTS):
    x = LABEL + c * (TW + GAP) + TW // 2
    d.text((x, y + 2), head, font=font(15, True), fill=INK, anchor='ma')
    d.text((x, y + 22), sub, font=font(12), fill=SUB, anchor='ma')
y += COLHEAD
for key, name, kind in PLANTS:
    i = info.get(key, {})
    d.rectangle([8, y + 4, W - 8, y + HEAD - 6], fill=(36, 40, 50))
    d.text((18, y + 9), '%s (%s)' % (name, kind), font=font(17, True), fill=INK)
    d.text((18 + font(17, True).getlength('%s (%s)' % (name, kind)) + 16, y + 12),
           'grows in %s s, each fruit regrows in %s s, %s fruits, %s parts per growth tick' % (i.get('seconds', '?'), i.get('regrow', '?'), i.get('fruits', '?'), i.get('parts', '?')),
           font=font(13), fill=SUB)
    y += HEAD
    for row, colour, label in (('today', TODAY, 'BEFORE'), ('built', PROP, 'NOW')):
        d.text((LABEL // 2, y + TH // 2), label, font=font(18, True), fill=colour, anchor='mm')
        for c, (moment, _, _) in enumerate(MOMENTS):
            x = LABEL + c * (TW + GAP)
            path = os.path.join(src, '%s_%s_%s.png' % (key, row, moment))
            im = Image.open(path).convert('RGB').resize((TW, TH), Image.LANCZOS)
            sheet.paste(im, (x, y))
            if row == 'built' and moment in ('ripe', 'harvest', 'f0'):
                d.rectangle([x, y, x + TW - 1, y + TH - 1], outline=GOLD, width=2)
            d.text((x + TW // 2, y + TH + 3), CAPTION[row][c], font=font(12), fill=colour if row == 'built' else SUB, anchor='ma')
        y += TH + CAP + 6
# Swatch panel: the fruit colour from 0 % to 100 % of a fruit's growth, before vs now (#6).
d.text((18, y + 8), 'Fruit colour from 0 % to 100 % of a fruit\'s growth (#6)', font=font(17, True), fill=INK)
d.text((18 + font(17, True).getlength('Fruit colour from 0 % to 100 % of a fruit\'s growth (#6)') + 16, y + 11),
       'before: leaf green blended straight to the ripe colour (muddy middle on red / orange fruit).  now: a pale green of the fruit\'s own brightness, ripe colour over the last 45 %.',
       font=font(13), fill=SUB)
BW, SQ, NAME = (W - 24) // 3, 38, 196
for k, sw in enumerate(swatches[:6]):
    bx, by = 12 + (k % 3) * BW, y + 40 + (k // 3) * 96
    d.text((bx + 6, by + 26), sw['name'], font=font(14, True), fill=INK)
    for r, (row, colour, label) in enumerate((('today', TODAY, 'before'), ('built', PROP, 'now'))):
        d.text((bx + NAME - 8, by + 4 + r * 40 + SQ // 2 - 4), label, font=font(11), fill=colour, anchor='rm')
        for i, c in enumerate(sw[row]):
            x0 = bx + NAME + i * (SQ + 2)
            d.rectangle([x0, by + 4 + r * 40, x0 + SQ, by + 4 + r * 40 + SQ - 4], fill=tuple(c))
    for i in (0, 5, 10):
        d.text((bx + NAME + i * (SQ + 2) + SQ // 2, by + 84), '%d %%' % (i * 10), font=font(10), fill=SUB, anchor='ma')
y += SW
foot = [
    'Gold frame = a moment phase 1 adds (#3 sprout pop, #7 ripe bounce + glints, #8 the picked fruit floats to the player; the frame shows it 40 % of the way, on the real flight curve).',
    'Not visible in stills: #1 about 50 times fewer part writes (same pixels), #2 growing and regrowing plants sway like ripe ones, the hotbar slot flashes when the fruit arrives.',
    'Excluded from every look change: Lantern Fern and Amethyst Grape. Ash Tomato keeps its model. The blossom (#9) and the glide (#10) are phase 2 and not built.',
]
for k, line in enumerate(foot):
    d.text((18, H - FOOT + 10 + k * 24), line, font=font(14), fill=GOLD if k == 0 else SUB)
sheet.save(out, optimize=True)
print('wrote', out, sheet.size, os.path.getsize(out) // 1024, 'KB')
