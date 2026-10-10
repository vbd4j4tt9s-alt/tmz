"""R151 preview (R152: the pedestal, the showcase item and the dancing giant; R153: one big label over the item, no plaque): composes docs/proposals/R153/hub_displays.png from render_hub.mjs's images (Pillow).
Usage: python3 make_hub_sheet.py <render out dir> <scene dir (scene_champions.json, champions.steps)> <out.png>"""
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
scene = json.load(open(os.path.join(SC, 'scene_champions.json'), encoding='utf-8'))['parts']


def box(p):
    r, s = p['r'], p['size']
    e = [(abs(r[i][0]) * s[0] + abs(r[i][1]) * s[1] + abs(r[i][2]) * s[2]) / 2 for i in range(3)]
    return (p['p'][0] - e[0], p['p'][0] + e[0], p['p'][1] - e[1], p['p'][1] + e[1], p['p'][2] - e[2], p['p'][2] + e[2])


def numbers():
    """The pedestal's footprint and height, the avatar's height, and the smallest plan gap (studs) between the pull display and the map's own pieces."""
    mine = [p for p in scene if 'BestPullDisplay' in p['path']]
    ped = [p for p in mine if '/Pedestal/' in p['path']]
    av = [p for p in mine if '/Avatar/' in p['path']]
    trim = [p for p in ped if p['name'] == 'Plinth trim'][0]
    head = [box(p) for p in av if p['name'] == 'Head']
    feet = [box(p) for p in av if p['name'] in ('LeftFoot', 'RightFoot')]
    prongs = max(box(p)[3] for p in ped) - 4
    item_h = float(re.search(r'R\.ItemHeight=([\d.]+)', open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..', 'src', 'ReplicatedStorage', 'HubDisplayRules.lua'), encoding='utf-8').read()).group(1))
    lp = json.loads([l for l in open(os.path.join(SC, 'champions.steps'), encoding='utf-8') if l.startswith('HUBTEXT ')][0][len('HUBTEXT '):])['label']
    label_top = lp['p'][1] + lp['h'] / 2 - 4
    others = [p for p in scene if 'HubDisplays151' not in p['path'] and (p.get('area') or '') in ('bases', 'fence', 'treadmill', 'pedestal', 'shop', 'verity', 'hub')]
    best = 1e9
    for p in others:
        b = box(p)
        for q in mine:
            a = box(q)
            best = min(best, math.hypot(max(a[0] - b[1], b[0] - a[1], 0.0), max(a[4] - b[5], b[4] - a[5], 0.0)))
    return {'plinth': max(trim['size'][0], trim['size'][2]), 'prongs': prongs, 'avatar': (max(b[3] for b in head) - min(b[2] for b in feet)) if head and feet else 0, 'item': item_h, 'gap': best, 'label': label_top}


N = numbers()
rows = []   # (label, [tiles]) each tile (image, caption)


def tile(state, name, caption):
    return (img(state, name), caption)


banner = img('champions', 'banner')
banner = banner.crop((0, 90, banner.width, banner.height - 110))   # (less sky, and the market's canopy under the camera cropped away)
rows.append(('The two displays from above the hub (a champion on each)', [(banner, 'Best Pull Today (right) and Biggest Fruit Today (left) stand in the two empty back corners, turned to the market')]))
rows.append(("From a player's base, a champion on each: Base 4's and Base 3's spawn (about 170 studs)", [
    tile('champions', 'pull_wide', 'BEST PULL TODAY from Base 4 (%d studs)' % round(dist(meta('champions', 'pull_wide')))),
    tile('champions', 'fruit_wide', 'BIGGEST FRUIT TODAY from Base 3 (%d studs)' % round(dist(meta('champions', 'fruit_wide'))))]))
rows.append(("From the same spawns, nobody has taken the spot yet", [
    tile('empty', 'pull_wide', 'BEST PULL TODAY, empty: the black mystery seed and a black silhouette (static, the same giant size)'),
    tile('empty', 'fruit_wide', 'BIGGEST FRUIT TODAY, empty: the fruit of the day, a black silhouette')]))
rows.append(('Close up: the pedestal, the seed and the big label over it, the avatar beside it', [
    tile('champions', 'pull_close', 'the rarest seed pulled today: it turns over the prongs, its light and sparkles on it'),
    tile('champions', 'fruit_close', "today's fruit (it changes every day): the heaviest one, Gold coat")]))
rows.append(('Close up, empty', [
    tile('empty', 'pull_close', 'BEST PULL TODAY: "Nobody yet", "???", "Open a pack to grab it!", the countdown'),
    tile('empty', 'fruit_close', 'BIGGEST FRUIT TODAY: "Nobody yet", "Pick one to grab it!", "Today: ... Watermelon", the countdown')]))
rows.append(('The pedestal and the label, three-quarter view', [
    tile('champions', 'pull_detail', 'the Fruit of the Hour pedestal x 3.2 (no plaque): the label has the title, winner, seed, rarity and chance, countdown'),
    tile('champions', 'fruit_detail', 'the same for the fruit: "Today: ... " is the fruit of the day')]))
rows.append(('How big: a normal 5.3 stud player 32 studs in front of each stand', [
    tile('champions', 'pull_scale', 'the avatar is %.0f studs tall (a normal one is 5.3: about 4.7 times), the pedestal %.0f studs (prongs)' % (N['avatar'], N['prongs'])),
    tile('champions', 'fruit_scale', 'the showcase item is about %.0f studs, floating over the prongs' % N['item'])]))

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
d.text((PAD + 12, 16), 'R153  Hub displays: one big label over the spinning showcase, a dancing giant', font=font(40, True), fill=INK)
d.text((PAD + 12, 72), 'BEST PULL TODAY and BIGGEST FRUIT TODAY: the Fruit of the Hour pedestal built big (no plaque), the winning seed / fruit turning under ONE big label, the champion 25 studs tall beside it.', font=font(20), fill=SOFT)
d.text((PAD + 12, 98), 'Approximate render (three.js): plain materials, no Roblox textures or lighting, not the Fredoka font; the avatar is a stand-in rig in ONE frame of its dance (the real one dances), sparkles frozen.', font=font(17), fill=(205, 170, 120))
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
    ('Both stay inside the corner HubDecorKit151 reserves (x 145 .. 335, z -618 .. -420, mirrored), 30+ studs from the walls, turned to the market.', False),
    ('Nearest piece of the map: %.0f studs away (bases, fences, treadmills, pedestals, the market); nothing overlaps.' % N['gap'], False),
    ('', False),
    ('Size', True),
    ('Pedestal: the Fruit of the Hour\'s own parts x 3.2, a %.1f stud plinth, the prongs %.1f studs up. The showcase item about %.0f studs, floating over the prongs; the label over it ends %.0f studs up (the walls are 48).' % (N['plinth'], N['prongs'], N['item'], N['label']), False),
    ('Avatar: %.1f studs tall, soles on the floor (a normal one is 5.3), Model:ScaleTo; it dances one of Roblox\'s three default R15 dances on its Animator (the static pose only if that cannot load).' % N['avatar'], False),
    ('Parts: BEST PULL %d pedestal + %d item + %d avatar; BIGGEST FRUIT %d + %d + %d (the old display was 53 + 45 + 22 and 53 + 12 + 22; no board, posts, slab, halo or tube).' % (info['Pull'] + info['Fruit']), False),
    ('', False),
    ('Not drawn here', True),
    ('The client\'s motion: the item\'s slow turn and float, the sparkles circling it (a frozen frame is drawn), the dance itself (one frame is drawn), the burst on a new champion.', False),
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
