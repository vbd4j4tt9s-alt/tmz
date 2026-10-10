"""Usage: python3 make_holo_sheet158d.py <AFTER render dir> <BEFORE render dir> <out dir>
Composes holo_rework158d.png from render_holo158d.mjs' PNGs and dump_holo158d.luau's INFO rows (visible parts per picture): the Holo Melon's three forms
(the harvested fruit as the hotbar / Bag / Index picture, and the plant) and the Holo Apple Tree (its fruit pictures, the tree and a close-up of its fruit),
before (the base commit) | after (this checkout). Approximate renders (three.js, Neon drawn unlit), not Roblox screenshots."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

after_dir, before_dir, out = sys.argv[1:4]


def info(path):
    d = {}
    for line in open(os.path.join(path, 'scenes.txt'), encoding='utf-8'):
        f = line.rstrip('\n').split('\t')
        if f[0] == 'INFO':
            d[f[1]] = int(f[2])
    return d


A, B = info(after_dir), info(before_dir)
BG, INK, SUB, HEAD, GOLD = (16, 22, 30), (255, 255, 255), (190, 204, 220), (140, 214, 255), (255, 214, 120)
RED, GREEN = (232, 72, 60), (110, 210, 140)


def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def img(folder, name, w):
    im = Image.open(os.path.join(folder, name + '.png')).convert('RGB')
    scale = max(w / im.width, w / im.height)
    im = im.resize((int(im.width * scale + .5), int(im.height * scale + .5)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - w) // 2
    return im.crop((x, y, x + w, y + w))


def pair(name, w, cap, sub):
    t = Image.new('RGB', (w * 2 + 4, w + 46), BG)
    t.paste(img(before_dir, name, w), (0, 0))
    t.paste(img(after_dir, name, w), (w + 4, 0))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, w - 1, w - 1], outline=RED, width=3)
    d.rectangle([w + 4, 0, 2 * w + 3, w - 1], outline=GREEN, width=3)
    for k, lab in enumerate(('before', 'after')):
        x0 = k * (w + 4) + 6
        d.rectangle([x0, 6, x0 + 8 + int(font(12).getlength(lab)), 24], fill=(0, 0, 0))
        d.text((x0 + 4, 8), lab, font=font(12), fill=INK)
    d.text((w + 2, w + 4), cap, font=font(14), fill=INK, anchor='ma')
    d.text((w + 2, w + 24), sub, font=font(12, False), fill=GOLD, anchor='ma')
    return t


def band(title, tiles, W2, gap=10):
    h = max(t.height for t in tiles)
    b = Image.new('RGB', (W2, h + 44), (10, 14, 20))
    ImageDraw.Draw(b).text((14, 8), title, font=font(22), fill=HEAD)
    x = (W2 - sum(t.width for t in tiles) - gap * (len(tiles) - 1)) // 2
    for t in tiles:
        b.paste(t, (x, 40))
        x += t.width + gap
    return b


def parts(name):
    return '%d -> %d parts' % (B[name], A[name])


W2 = 1900
blocks = []
FORMS = ['Holo Melon', 'Holo Cantaloupe', 'Holo Pumpkin']
PW = 296
blocks.append(band('Holo Melon, the fruit as the hotbar / Bag / Index picture: wire box -> the Watermelon mesh, the Watermelon mesh rounder, the Ember Pumpkin mesh',
                   [pair('item_melon_%d' % i, PW, FORMS[i], parts('item_melon_%d' % i)) for i in range(3)], W2))
blocks.append(band('Holo Melon on its projector (the plant): the same three forms, one per harvest',
                   [pair('plant_melon_%d' % i, PW, FORMS[i] + ' (plant)', parts('plant_melon_%d' % i) + ' in all') for i in range(3)], W2))
TREE = ['Holo Apple', 'Holo Pear', 'Holo Orange']
TW = 176
blocks.append(band('Holo Apple Tree: the fruit is the real apple (body, shoulders, base, dimple, stem, leaf), the pear and the orange stretch it',
                   [pair('item_tree_%d' % i, TW, TREE[i], parts('item_tree_%d' % i)) for i in range(3)]
                   + [pair('plant_tree', TW, 'the tree (apple, pear, orange, apple)', parts('plant_tree') + ' in all'),
                      pair('zoom_tree', TW, 'close-up of its fruit', '4 fruit: 88 -> 40 parts')], W2, 8))
H2 = 96 + sum(b.height for b in blocks) + 80
sheet = Image.new('RGB', (W2, H2), (10, 14, 20))
d = ImageDraw.Draw(sheet)
d.text((W2 // 2, 14), 'R158d: Holo Melon and Holo Apple Tree rework, before | after (three.js preview of the real build path)', font=font(27), fill=INK, anchor='ma')
d.text((W2 // 2, 56), 'Built by the real modules on the Roblox mock: "before" = the R158d starting commit, "after" = this checkout with the server bake of HoloMelon158 / HoloPumpkin158 '
       '(drawn from the vertex data FruitMeshes149 generated).', font=font(15, False), fill=SUB, anchor='ma')
y = 96
for b in blocks:
    sheet.paste(b, (0, y))
    y += b.height
foot = ['Approximate: Neon drawn unlit and translucent, mesh vertex colours x part colour; no Roblox bloom, lighting or hologram spin. The Holo Melon keeps its wire boxes (the "before") on a server whose bake failed.',
        'Parts = visible parts in the picture. Per fruit: Holo Melon 36 -> 7, Cantaloupe 42 -> 9, Pumpkin 36 -> 7, Apple / Pear / Orange 22 -> 10. Thin scan rings replace the wire stripes; the spin, the cycle and the names are as before.']
for k, line in enumerate(foot):
    d.text((W2 // 2, y + 14 + k * 22), line, font=font(14, False), fill=GOLD, anchor='ma')
sheet.save(os.path.join(out, 'holo_rework158d.png'), optimize=True)
print('wrote holo_rework158d.png', sheet.size)
