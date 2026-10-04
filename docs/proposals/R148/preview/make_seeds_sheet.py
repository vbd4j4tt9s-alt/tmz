"""Usage: python3 make_seeds_sheet.py <dir with the rendered scene PNGs> <out dir>
Composes seeds_new.png from render_seeds_new.mjs's output: a row for the Aloe (seed, growing, grown, one harvested spike), a row for the Sand Fruit
palm (seed, growing, grown, one harvested bunch) and a row for Fire Pepper (the new Mythic seed, the plant before, after, and both to scale).
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


NOTE = ['Approximate (three.js, plain materials, no Roblox textures or lighting). Fire Pepper\'s baked meshes are not in the repo: its plant is drawn from the',
        'art\'s bounding boxes as ellipsoids, so only its SIZE is shown; each plant is framed to fill its picture: the last panel shows both at one scale.']
TW, TH = 300, 450
rows = [
    ('ALOE  |  Desert, Rare  |  1.0e7 per spike, 3 spikes, 960 s / regrow 530 s',
     [panel('seed_aloe', 'Seed', 'blue-green blades and a red-orange flower spike', (TW, TH)),
      panel('aloe_growing', 'Growing: 50%', 'rosette first, spikes later', (TW, TH)),
      panel('aloe_grown', 'Grown', '96 parts, 8.2 studs high', (TW, TH)),
      panel('aloe_fruit', 'Harvested fruit', 'one flower spike: a stalk with 9 florets and a bud', (TW, TH))]),
    ('SAND FRUIT  |  Desert, Legendary  |  26.4M per bunch, 4 bunches, 2760 s / regrow 1520 s',
     [panel('seed_sand', 'Seed', 'dune ripples, a tiny palm crown, twinkling sparkles', (TW, TH)),
      panel('sand_growing', 'Growing: 50%', 'trunk rising, crown not yet bearing', (TW, TH)),
      panel('sand_grown', 'Grown', '99 parts, 14.2 studs high', (TW, TH)),
      panel('sand_fruit', 'Harvested fruit', 'one bunch (stalk + 3 sand fruits)', (TW, TH))]),
    ('FIRE PEPPER  |  Lava, now Mythic  |  285M per pepper, 4 peppers, 4300 s / regrow 2370 s',
     [panel('seed_fire', 'Seed (Mythic)', 'green calyx, curled stem, 3 flickering flames', (TW, TH)),
      panel('fire_before', 'Before', 'Rare: 6 studs high', (TW, TH)),
      panel('fire_after', 'After', 'Mythic: twice as big (12 studs), peppers too', (TW, TH)),
      panel('fire_both', 'Before | After', 'same scale, side by side', (TW, TH))]),
]
GAP, HEAD, FOOT, TITLE = 8, 44, 56, 64
tw = max(sum(t.width for t in r[1]) + GAP * (len(r[1]) + 1) for r in rows)
rowh = [max(t.height for t in r[1]) for r in rows]
H = TITLE + sum(HEAD + h + GAP for h in rowh) + FOOT
sheet = Image.new('RGB', (tw, H), (10, 20, 15))
d = ImageDraw.Draw(sheet)
d.text((tw // 2, 16), 'R148 seed roster: Aloe, Sand Fruit palm, bigger Fire Pepper (three.js preview)', font=font(28), fill=(255, 255, 255), anchor='ma')
y = TITLE
for (title, tiles), h in zip(rows, rowh):
    d.text((GAP + 4, y + 8), title, font=font(24), fill=(150, 226, 170))
    y += HEAD
    x = GAP
    for t in tiles:
        sheet.paste(t, (x, y))
        x += t.width + GAP
    y += h + GAP
for i, line in enumerate(NOTE):
    d.text((tw // 2, H - FOOT + 6 + i * 20), line, font=font(14, False), fill=(255, 214, 120), anchor='ma')
sheet.save(out + '/seeds_new.png')
print('wrote seeds_new.png', sheet.size)
