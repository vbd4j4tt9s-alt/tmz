"""R151 preview: composes docs/proposals/R151/hub_displays.png from render_hub.mjs's images (Pillow).
Usage: python3 make_sheet.py <render out dir> <scene dir (scene_champions.json, champions.steps)> <out.png>"""
import json, math, os, re, sys
from PIL import Image, ImageDraw, ImageFont

R, SC, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
FONTS = ['/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']
BOLD = FONTS[1] if os.path.exists(FONTS[1]) else FONTS[0]
REG = FONTS[0]


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, size)


W, PAD, TILE_W, TILE_H = 1872, 24, 900, 520
BG, INK, SOFT, GOLD = (20, 22, 40), (240, 242, 255), (170, 178, 210), (255, 206, 84)


def img(state, name):
    return Image.open(os.path.join(R, '%s_%s.png' % (state, name))).convert('RGB')


def meta(state, name):
    return json.load(open(os.path.join(R, '%s_%s.json' % (state, name))))


def dist(m):
    c, a = m['view']['cam'], m['view']['at']
    return math.dist(c, a)


# ---- numbers from the data ----
info = {}
for line in open(os.path.join(SC, 'champions.steps'), encoding='utf-8'):
    mm = re.match(r'HUBINFO (Pull|Fruit) frame=(\d+) item=(\d+) avatar=(\d+)', line)
    if mm:
        info[mm.group(1)] = tuple(int(x) for x in mm.groups()[1:])
frames = meta('champions', 'plan')['frames']
pc, fc = frames['Pull']['center'], frames['Fruit']['center']


def gap_to_map():
    """The smallest plan gap (studs) between the displays and the map's own pieces (bases, fences, treadmills, pedestals, the market, Verity)."""
    scene = json.load(open(os.path.join(SC, 'scene_champions.json'), encoding='utf-8'))['parts']

    def box(p):
        r, s = p['r'], p['size']
        e = [(abs(r[i][0]) * s[0] + abs(r[i][1]) * s[1] + abs(r[i][2]) * s[2]) / 2 for i in range(3)]
        return (p['p'][0] - e[0], p['p'][0] + e[0], p['p'][2] - e[2], p['p'][2] + e[2])
    mine = [box(p) for p in scene if 'HubDisplays151' in p['path']]
    best = 1e9
    for p in scene:
        if 'HubDisplays151' in p['path'] or (p.get('area') or '') not in ('bases', 'fence', 'treadmill', 'pedestal', 'shop', 'verity', 'hub'):
            continue
        b = box(p)
        for a in mine:
            dx = max(a[0] - b[1], b[0] - a[1], 0.0)
            dz = max(a[2] - b[3], b[2] - a[3], 0.0)
            best = min(best, math.hypot(dx, dz))
    return best


GAP = gap_to_map()
rows = []   # (label, [tiles]) each tile (image, caption)


def tile(state, name, caption):
    return (img(state, name), caption)


banner = img('champions', 'banner')
banner = banner.crop((0, 90, banner.width, banner.height - 110))   # (less sky, and the market's canopy under the camera cropped away)
rows.append(('The two displays from above the hub (a champion on each)', [(banner, 'Best Pull Today (right) and Biggest Fruit Today (left) stand in the two empty back corners, signs turned to the market')]))
rows.append(("From a player's base: Base 4's and Base 3's spawn", [
    tile('champions', 'pull_wide', 'BEST PULL TODAY from Base 4 (%d studs)' % round(dist(meta('champions', 'pull_wide')))),
    tile('champions', 'fruit_wide', 'BIGGEST FRUIT TODAY from Base 3 (%d studs)' % round(dist(meta('champions', 'fruit_wide'))))]))
rows.append(('Close up: a champion and his avatar beside the giant item', [
    tile('champions', 'pull_close', 'the rarest seed pulled today: a giant Fire Pepper seed, its rarity colour, the puller beside it'),
    tile('champions', 'fruit_close', "today's fruit (it changes every day): the heaviest one, with its coat")]))
rows.append(('Podium, item and avatar', [
    tile('champions', 'pull_detail', 'the R150 pedestal art scaled up, a rarity glow, the posed avatar on its own plinth'),
    tile('champions', 'fruit_detail', 'the giant fruit on the same podium')]))
rows.append(('Nobody has taken the spot yet', [
    tile('empty', 'pull_close', 'BEST PULL TODAY: a mystery silhouette and "Open a pack to take the first spot!"'),
    tile('empty', 'fruit_close', 'BIGGEST FRUIT: the fruit shown, "Harvest the biggest ... today to get here!"')]))

lab_font, cap_font = font(26, True), font(17)
height = 150
for label, tiles in rows:
    height += 44 + max(t[0].height for t in tiles) + PAD
plan = img('champions', 'plan')
height += 44 + plan.height + PAD + 40
sheet = Image.new('RGB', (W, height), BG)
d = ImageDraw.Draw(sheet)
# header
d.rectangle((0, 0, W, 120), fill=(30, 33, 62))
d.text((PAD + 12, 16), 'R151  Hub displays: BEST PULL TODAY and BIGGEST FRUIT TODAY', font=font(40, True), fill=INK)
d.text((PAD + 12, 72), 'Two giant displays in the hub\'s two empty back corners: the rarest pull and the biggest fruit of the day across all servers, each with the player\'s own avatar beside it.', font=font(20), fill=SOFT)
d.text((PAD + 12, 98), 'Approximate render (three.js): plain materials, no textures or Roblox lighting, the font is not Fredoka; the avatar is a stand-in rig, the real one is the player\'s own (Studio).', font=font(17), fill=(205, 170, 120))
y = 140


def caption(im, text, at):
    dd = ImageDraw.Draw(im, 'RGBA')
    tw = dd.textlength(text, font=cap_font)
    dd.rounded_rectangle((at[0], at[1], at[0] + tw + 20, at[1] + 30), radius=10, fill=(10, 10, 24, 190))
    dd.text((at[0] + 10, at[1] + 4), text, font=cap_font, fill=(240, 240, 255, 255))


for label, tiles in rows:
    d.text((PAD + 12, y + 4), label, font=lab_font, fill=GOLD)
    y += 44
    x = PAD if len(tiles) > 1 else (W - tiles[0][0].width) // 2
    for im, cap in tiles:
        im = im.copy()
        caption(im, cap, (10, im.height - 40))
        sheet.paste(im, (x, y))
        x += im.width + PAD
    y += max(t[0].height for t in tiles) + PAD
# plan + the numbers
d.text((PAD + 12, y + 4), 'Plan of the hub: where they stand', font=lab_font, fill=GOLD)
y += 44
pm = meta('champions', 'plan')
pim = plan.copy()
pd = ImageDraw.Draw(pim, 'RGBA')
pts = {l['text']: (l['x'], l['y']) for l in pm['labels']}
for k in ('BEST PULL TODAY', 'BIGGEST FRUIT TODAY'):   # the line of sight to the market
    if k in pts and 'Market' in pts:
        a, b = pts[k], pts['Market']
        n = 24
        for i in range(0, n, 2):
            p0 = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
            p1 = (a[0] + (b[0] - a[0]) * (i + 1) / n, a[1] + (b[1] - a[1]) * (i + 1) / n)
            pd.line((p0, p1), fill=(255, 230, 120, 230), width=3)
for l in pm['labels']:
    f = font(18, True)
    tw = pd.textlength(l['text'], font=f)
    gold = 'TODAY' in l['text']
    pd.ellipse((l['x'] - 6, l['y'] - 6, l['x'] + 6, l['y'] + 6), fill=(255, 210, 80, 255) if gold else (255, 255, 255, 220))
    ox = -tw / 2
    pd.rounded_rectangle((l['x'] + ox - 7, l['y'] - 38, l['x'] + ox + tw + 7, l['y'] - 10), radius=9, fill=(10, 10, 24, 215))
    pd.text((l['x'] + ox, l['y'] - 36), l['text'], font=f, fill=(255, 222, 120, 255) if gold else (235, 238, 250, 255))
sheet.paste(pim, (PAD, y))
tx = PAD + pim.width + 28
ty = y + 6
panel = [
    ('Where', True),
    ('BEST PULL TODAY: back right corner, centre x %+d, z %d (about 100 studs from the right and back walls).' % (round(pc[0]), round(pc[2])), False),
    ('BIGGEST FRUIT TODAY: back left corner, centre x %+d, z %d.' % (round(fc[0]), round(fc[2])), False),
    ('Both face the market at the hub\'s middle: from every base\'s spawn, the market and Verity, the sign is turned toward the player.', False),
    ('Nearest piece of the map: %.0f studs away (bases, fences, treadmills, pedestals, the market); nothing overlaps.' % GAP, False),
    ('', False),
    ('Size', True),
    ('Sign board 48 x 20 studs, 35 studs up, text readable out to about 300 studs; the glowing giant item reads as a landmark from anywhere in the hub.', False),
    ('Stage 60 x 36, the giant item 10 studs tall on a podium, the avatar 10.5 studs on its own plinth; the top of the crown 47 studs (the walls are 48).', False),
    ('Parts: BEST PULL %d + %d item + %d avatar; BIGGEST FRUIT %d + %d + %d (frame + item + avatar; the cap is 150 for the item).' % (info['Pull'] + info['Fruit']), False),
    ('', False),
    ('Not drawn here', True),
    ('The client\'s motion: the item\'s slow turn and sparkles, the avatar\'s cheer, the pop when a new champion arrives; the fruit art of the live game (baked meshes: a stand-in here).', False),
]


def wrap(text, f, width):
    words, line, out = text.split(), '', []
    for w in words:
        t = (line + ' ' + w).strip()
        if d.textlength(t, font=f) > width:
            out.append(line);line = w
        else:
            line = t
    out.append(line)
    return out


for text, head in panel:
    if not text:
        ty += 12
        continue
    f = font(21, True) if head else font(18)
    for ln in wrap(text, f, W - tx - PAD - 8):
        d.text((tx, ty), ln, font=f, fill=GOLD if head else INK)
        ty += 28 if head else 25
    ty += 4
sheet.save(OUT, optimize=True)
print('wrote', OUT, sheet.size, os.path.getsize(OUT) // 1024, 'KB')
