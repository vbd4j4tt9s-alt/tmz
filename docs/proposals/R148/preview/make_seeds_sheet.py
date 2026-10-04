"""Usage: python3 make_seeds_sheet.py <dir with the rendered scene PNGs> <out dir>
Composes seeds_new.png from render_seeds_new.mjs's output: a row for the Aloe (seed, growing, grown, one harvested spike), a row for the Sand Fruit
round cactus (seed, growing, grown, one harvested fruit) and a row for Fire Pepper (the new Mythic seed, the plant before, after, and both to scale).
Approximate renders (three.js) of the real parts, not Roblox screenshots."""
import sys
from PIL import Image, ImageDraw, ImageFont

src, out = sys.argv[1], sys.argv[2]
BG = (23, 40, 33)


def font(size, bold=True):
    for name in ('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf',):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def load(name):
    return Image.open('%s/%s.png' % (src, name)).convert('RGB')


def wrap(text, fnt, width):
    lines, line = [], ''
    for word in text.split():
        trial = (line + ' ' + word).strip()
        if fnt.getlength(trial) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    lines.append(line)
    return lines


def panel(name, caption, sub, size):
    img = load(name)
    w, h = size
    img = img.resize((w, int(img.height * w / img.width)), Image.LANCZOS)
    cap = 84
    tile = Image.new('RGB', (w, max(h, img.height) + cap), BG)
    tile.paste(img, (0, 0))
    d = ImageDraw.Draw(tile)
    d.text((w // 2, img.height + 6), caption, font=font(22), fill=(255, 236, 161), anchor='ma')
    sf = font(15, False)
    for i, line in enumerate(wrap(sub, sf, w - 16)[:2]):
        d.text((w // 2, img.height + 36 + i * 20), line, font=sf, fill=(205, 222, 210), anchor='ma')
    return tile


NOTE = ('Approximate (three.js, plain materials, no Roblox textures or lighting). The Fire Pepper plant already reuses the game\'s existing red pepper model, at twice the size '
        '(the art\'s positions and sizes doubled); its baked meshes are not in the repo, so this preview draws stand-in ellipsoids of their bounding boxes and only its SIZE is shown. '
        'The Sand Fruit cactus is built from the game\'s own cactus pieces (the Prickly Pear\'s stem green, the Crown Cactus\' ribs and ivory spines); its fruits use Enum.Material.Sand, drawn here as a matt sand colour. '
        'Each plant is framed to fill its picture; the last Fire Pepper panel shows both at one scale. Fire Pepper keeps its single art (x2) with the same ten small size / turn variants (about 2%): too small to draw.')
TW, TH, GAP = 300, 450, 8
rows = [
    ('ALOE  |  Desert, Rare  |  1.0e7 per spike, 3 spikes, 960 s / regrow 530 s',
     [panel('seed_aloe', 'Seed', 'blue-green blades and a red-to-yellow flower spike', (TW, TH)),
      panel('aloe_growing', 'Growing: 50%', 'rosette first, spikes later', (TW, TH)),
      panel('aloe_grown', 'Grown', '127 parts, 8.3 studs high, 72 florets', (TW, TH)),
      panel('aloe_fruit', 'Harvested fruit', 'one flower spike: a stalk with 24 graded florets', (TW, TH))]),
    ('SAND FRUIT  |  Desert, Legendary  |  26.4M per fruit, 4 fruits, 2760 s / regrow 1520 s',
     [panel('seed_sand', 'Seed', 'sandy round seed, a cactus nub with spines, sparkles', (TW, TH)),
      panel('sand_growing', 'Growing: 50%', 'round cactus first, fruits later', (TW, TH)),
      panel('sand_grown', 'Grown', '95 parts, a round cactus 10.6 studs high', (TW, TH)),
      panel('sand_fruit', 'Harvested fruit', 'one fruit: a lumpy sand-textured ball', (TW, TH))]),
    ('ALOE VARIATIONS  |  four designs picked by the crop id, fully grown',
     [panel('aloe_variants', 'classic  |  tall  |  wide  |  windswept', '127 / 128 / 126 / 124 parts: 14-20 leaves, 21-25 florets a spike, spikes of other heights, leans and places, other spot patterns and colour balance', (4 * TW + 3 * GAP, 338))]),
    ('SAND FRUIT VARIATIONS  |  four designs picked by the crop id, fully grown',
     [panel('sand_variants', 'barrel  |  tall  |  squat  |  ribbed', '95 / 88 / 100 / 94 parts: 7-9 ribs, 0-3 pups, sparse to dense spines, barrels of other heights and widths, fruits at other places and sizes', (4 * TW + 3 * GAP, 338))]),
    ('FIRE PEPPER  |  Lava, now Mythic  |  285M per pepper, 4 peppers, 4300 s / regrow 2370 s',
     [panel('seed_fire', 'Seed (Mythic)', 'green calyx, curled stem, 3 flickering flames', (TW, TH)),
      panel('fire_before', 'Before', 'Rare: 6 studs high', (TW, TH)),
      panel('fire_after', 'After', 'Mythic: the same model x2 (12 studs)', (TW, TH)),
      panel('fire_both', 'Before | After', 'same scale; stand-in shapes, size only', (TW, TH))]),
]
HEAD, TITLE = 44, 64
tw = max(sum(t.width for t in r[1]) + GAP * (len(r[1]) + 1) for r in rows)
rowh = [max(t.height for t in r[1]) for r in rows]
noteLines = wrap(NOTE, font(14, False), tw - 40)
FOOT = 20 * len(noteLines) + 16
H = TITLE + sum(HEAD + h + GAP for h in rowh) + FOOT
sheet = Image.new('RGB', (tw, H), (10, 20, 15))
d = ImageDraw.Draw(sheet)
d.text((tw // 2, 16), 'R148 seed roster: Aloe, round-cactus Sand Fruit, bigger Fire Pepper (preview)', font=font(26), fill=(255, 255, 255), anchor='ma')
y = TITLE
for (title, tiles), h in zip(rows, rowh):
    d.text((GAP + 4, y + 8), title, font=font(24), fill=(150, 226, 170))
    y += HEAD
    x = GAP
    for t in tiles:
        sheet.paste(t, (x, y))
        x += t.width + GAP
    y += h + GAP
for i, line in enumerate(noteLines):
    d.text((tw // 2, H - FOOT + 6 + i * 20), line, font=font(14, False), fill=(255, 214, 120), anchor='ma')
sheet.save(out + '/seeds_new.png')
print('wrote seeds_new.png', sheet.size)
