"""Usage: python3 make_built_sheet.py <dir of the AFTER render: scenes.txt + PNGs> <dir of the BEFORE render> <out dir>
Composes fruit_models_built.png: the redesigned fruit as the REAL modules build them, before (the base commit) | after (this checkout), from the
output of render_fruit_models.mjs and the INFO / ASH rows of dump_fruit_built.luau. Approximate renders (three.js), not Roblox screenshots."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

after_dir, before_dir, out = sys.argv[1:4]


def rows(path):
    info, ash = {}, {}
    for line in open(os.path.join(path, 'scenes.txt'), encoding='utf-8'):
        f = line.rstrip('\n').split('\t')
        if f[0] == 'INFO':
            info[f[1]] = {'name': f[2], 'fruit': int(f[3]), 'plant': int(f[4])}
        elif f[0] == 'ASH':
            ash[int(f[1])] = {'crop': f[2], 'plant': int(f[3])}
    return info, ash


A, A_ash = rows(after_dir)
B, B_ash = rows(before_dir)
BG, INK, SUB, HEAD, GOLD = (18, 30, 26), (255, 255, 255), (200, 216, 206), (150, 226, 170), (255, 214, 120)
RED, GREEN = (232, 72, 60), (110, 210, 140)


def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def img(folder, name, w, h=None):
    im = Image.open(os.path.join(folder, name + '.png')).convert('RGB')
    h = h or w
    scale = max(w / im.width, h / im.height)
    im = im.resize((int(im.width * scale + .5), int(im.height * scale + .5)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def tile(folder, name, w, cap, sub=None, border=None, sub2=None, tag=None):
    caph = 24 + (22 if sub else 0) + (20 if sub2 else 0)
    t = Image.new('RGB', (w, w + caph), BG)
    t.paste(img(folder, name, w), (0, 0))
    d = ImageDraw.Draw(t)
    if border:
        d.rectangle([0, 0, w - 1, w - 1], outline=border, width=4)
    if tag:
        d.rectangle([5, 5, 13 + int(font(13).getlength(tag)), 25], fill=(0, 0, 0))
        d.text((9, 8), tag, font=font(13), fill=INK)
    y = w + 4
    d.text((w // 2, y), cap, font=font(15), fill=INK, anchor='ma')
    y += 22
    if sub:
        d.text((w // 2, y), sub, font=font(12, False), fill=SUB, anchor='ma')
        y += 20
    if sub2:
        d.text((w // 2, y), sub2, font=font(12, False), fill=GOLD, anchor='ma')
    return t


def pair(name, w, cap, sub, sub2, left, right, labels=('before', 'after')):
    a = img(left[0], left[1], w)
    b = img(right[0], right[1], w)
    caph = 24 + (22 if sub else 0) + (20 if sub2 else 0)
    t = Image.new('RGB', (w * 2 + 4, w + caph), BG)
    t.paste(a, (0, 0))
    t.paste(b, (w + 4, 0))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, w - 1, w - 1], outline=RED, width=3)
    d.rectangle([w + 4, 0, 2 * w + 3, w - 1], outline=GREEN, width=3)
    for k, lab in enumerate(labels):
        x0 = k * (w + 4) + 6
        d.rectangle([x0, 6, x0 + 8 + int(font(12).getlength(lab)), 24], fill=(0, 0, 0))
        d.text((x0 + 4, 8), lab, font=font(12), fill=INK)
    y = w + 4
    d.text((w + 2, y), cap, font=font(16), fill=INK, anchor='ma')
    y += 22
    if sub:
        d.text((w + 2, y), sub, font=font(12, False), fill=SUB, anchor='ma')
        y += 20
    if sub2:
        d.text((w + 2, y), sub2, font=font(12, False), fill=GOLD, anchor='ma')
    return t


W2 = 1880
blocks = []


def band(title, tiles, gap=10, subtitle=None):
    w = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    h = max(t.height for t in tiles)
    top = 40 if not subtitle else 62
    b = Image.new('RGB', (W2, h + top + 8), (10, 20, 15))
    dd = ImageDraw.Draw(b)
    if title:
        dd.text((14, 8), title, font=font(22), fill=HEAD)
    if subtitle:
        dd.text((14, 36), subtitle, font=font(14, False), fill=SUB)
    x = (W2 - w) // 2
    for t in tiles:
        b.paste(t, (x, top))
        x += t.width + gap
    blocks.append(b)


IDS = [('SunflowerSeed', 'Watermelon'), ('SnowdropSeed', 'Snow Melon'), ('AppleSeed', 'Apple'), ('ElderbloomSeed', 'Elderbloom (elder apple)'),
       ('EmberBloomSeed', 'Ember Pumpkin'), ('CactusSeed', 'Prickly Pear'), ('BluebellSeed', 'Blueberry'), ('IceberrySeed', 'Iceberry')]
PW = 205
cells = []
for i, name in IDS:
    cells.append(pair(i, PW, name, 'hotbar / Bag / Index picture', 'parts %d -> %d' % (B[i]['fruit'], A[i]['fruit']),
                      (before_dir, 'fruit_' + i), (after_dir, 'fruit_' + i)))
band('Hotbar / Bag / Index pictures (HarvestPresentation.Build of fruit 1), before | after', cells[:4])
band('', cells[4:])
blocks[-1] = blocks[-1].crop((0, 30, W2, blocks[-1].height))
LW = 210
cells = []
for i, name in IDS:
    cells.append(pair(i, LW, name, 'same fruit centres, connectors kept', 'plant %d -> %d parts (full detail)' % (B[i]['plant'], A[i]['plant']),
                      (before_dir, 'plant_' + i), (after_dir, 'plant_' + i)))
band('On the plant (full detail), before | after', cells[:4])
band('', cells[4:])
blocks[-1] = blocks[-1].crop((0, 30, W2, blocks[-1].height))
# Ash Tomato
AW = 262
tiles = [tile(before_dir, 'ash_1', AW, 'Ash Tomato today', 'one design', RED, 'plant %d parts' % B_ash[1]['plant'], 'before')]
for d in range(1, 5):
    if d in A_ash:
        tiles.append(tile(after_dir, 'ash_%d' % d, AW, 'design %d' % d, 'the base design' if d == 1 else 'variation of the base design', GREEN, 'plant %d parts' % A_ash[d]['plant'], 'after'))
band('Ash Tomato: its look stays; four designs picked per crop (hash of the crop id, plus the size / turn jitter)', tiles, subtitle='Variations: mirror / size / lean, leaves swung about their stems (a few fewer), each tomato scaled and twisted about its socket, a shade of red and green. Same 4 fruit.')
FW = 190
tiles = []
for d in range(1, 5):
    if d in A_ash:
        tiles.append(tile(after_dir, 'ashfruit_%d' % d, FW, 'design %d tomato' % d, 'hotbar picture', GREEN))
band('', tiles)
blocks[-1] = blocks[-1].crop((0, 30, W2, blocks[-1].height))
# coats
CW = 190
cells = []
for i, name in IDS:
    t = Image.new('RGB', (CW * 2 + 4, CW + 28), BG)
    t.paste(img(after_dir, 'coat_%s_Gold' % i, CW), (0, 0))
    t.paste(img(after_dir, 'coat_%s_Diamond' % i, CW), (CW + 4, 0))
    d = ImageDraw.Draw(t)
    d.text((CW + 2, CW + 5), name, font=font(15), fill=INK, anchor='ma')
    cells.append(t)
band('Gold | Diamond coats (the gloss / glint decor hides; every part is Metal / Glass)', cells[:4])
band('', cells[4:])
blocks[-1] = blocks[-1].crop((0, 30, W2, blocks[-1].height))
# growth
GW = 150
tiles = []
for i, name in [('SunflowerSeed', 'Watermelon'), ('AppleSeed', 'Apple'), ('EmberBloomSeed', 'Ember Pumpkin'), ('BluebellSeed', 'Blueberry')]:
    t = Image.new('RGB', (GW * 3 + 8, GW + 26), BG)
    for k in range(3):
        t.paste(img(after_dir, 'grow_%s_%d' % (i, k + 1), GW), (k * (GW + 4), 0))
    d = ImageDraw.Draw(t)
    d.text((t.width // 2, GW + 4), name + ': 30 / 60 / 90 %', font=font(14), fill=INK, anchor='ma')
    tiles.append(t)
band('Growing (the generic growth path: fruit grows from its socket)', tiles)
# unchanged
UW = 200
tiles = []
for i, name in [('LanternFernSeed', 'Lantern Fern'), ('AmethystSeed', 'Amethyst Grape')]:
    same = (B[i]['fruit'], B[i]['plant']) == (A[i]['fruit'], A[i]['plant'])
    tiles.append(tile(after_dir, 'unch_fruit_' + i, UW, name, 'unchanged: byte for byte', (255, 220, 90), 'fruit %d parts%s' % (A[i]['fruit'], '' if same else ' (CHANGED?)')))
    tiles.append(tile(after_dir, 'unch_plant_' + i, UW, name + ' plant', 'unchanged', (255, 220, 90), '%d parts' % A[i]['plant']))
band('Unchanged (owner: keep): Lantern Fern and Amethyst Grape', tiles)
H2 = 84 + sum(b.height for b in blocks) + 60
sheet = Image.new('RGB', (W2, H2), (10, 20, 15))
d = ImageDraw.Draw(sheet)
d.text((W2 // 2, 14), 'R149 built: part-based fruit models in the real art modules (three.js preview of the real build path)', font=font(28), fill=INK, anchor='ma')
d.text((W2 // 2, 52), 'Before = the base commit\'s modules, after = this checkout\'s, both built by dump_fruit_built.luau on the Roblox mock (docs/proposals/R149/preview).', font=font(16, False), fill=SUB, anchor='ma')
y = 84
for b in blocks:
    sheet.paste(b, (0, y))
    y += b.height
foot = ['Approximate: plain materials, no Roblox textures / Future lighting; Neon drawn unlit. Parts = parts in the picture / the plant at full detail (PlantVisuals.Build).',
        'Lantern Fern, Amethyst Grape and the Ash Tomato\'s look are unchanged (owner); Phase-2 baked meshes are not part of this release.']
for k, line in enumerate(foot):
    d.text((W2 // 2, y + 12 + k * 22), line, font=font(15, False), fill=GOLD, anchor='ma')
sheet.save(os.path.join(out, 'fruit_models_built.png'))
print('wrote fruit_models_built.png', sheet.size)
