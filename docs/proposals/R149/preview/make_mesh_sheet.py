"""Usage: python3 make_mesh_sheet.py <AFTER render dir (mesh)> <BEFORE render dir (parts)> <out dir>
Composes fruit_meshes.png from render_fruit_models.mjs' PNGs and dump_fruit_meshes.luau's INFO rows: per fruit, before (the R149 part-built
fruit, which FruitMeshes149 keeps when a bake fails) | after (one baked mesh body): the hotbar / Bag / Index pictures, the plant, Gold,
Diamond, and the plant growing. Approximate renders (three.js), not Roblox screenshots."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

after_dir, before_dir, out = sys.argv[1:4]


def rows(path):
    info = {}
    for line in open(os.path.join(path, 'scenes.txt'), encoding='utf-8'):
        f = line.rstrip('\n').split('\t')
        if f[0] == 'INFO':
            info[f[1]] = {'name': f[2], 'fruit': int(f[3]), 'plant': int(f[4]), 'tris': int(f[5])}
    return info


A, B = rows(after_dir), rows(before_dir)
BG, INK, SUB, HEAD, GOLD = (18, 30, 26), (255, 255, 255), (200, 216, 206), (150, 226, 170), (255, 214, 120)
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
    t = Image.new('RGB', (w * 2 + 4, w + 48), BG)
    t.paste(img(before_dir, name, w), (0, 0))
    t.paste(img(after_dir, name, w), (w + 4, 0))
    d = ImageDraw.Draw(t)
    d.rectangle([0, 0, w - 1, w - 1], outline=RED, width=3)
    d.rectangle([w + 4, 0, 2 * w + 3, w - 1], outline=GREEN, width=3)
    for k, lab in enumerate(('parts (R149)', 'baked mesh')):
        x0 = k * (w + 4) + 6
        d.rectangle([x0, 6, x0 + 8 + int(font(12).getlength(lab)), 24], fill=(0, 0, 0))
        d.text((x0 + 4, 8), lab, font=font(12), fill=INK)
    d.text((w + 2, w + 4), cap, font=font(15), fill=INK, anchor='ma')
    d.text((w + 2, w + 26), sub, font=font(12, False), fill=GOLD, anchor='ma')
    return t


W2 = 1900
blocks = []
FRUIT = [('SunflowerSeed', 'Watermelon', 'PlantArtForest'), ('SnowdropSeed', 'Snow Melon', 'PlantArtSnow'), ('EmberBloomSeed', 'Ember Pumpkin', 'PlantArtLava')]
PW = 176
for i, name, module in FRUIT:
    a, b = A[i], B[i]
    tiles = [pair('fruit_%s_1' % i, PW, 'hotbar / Bag / Index', 'parts %d -> %d (1 mesh, %d triangles)' % (b['fruit'], a['fruit'], a['tris'])),
             pair('fruit_%s_2' % i, PW, 'the second (smaller) fruit', 'same mesh, its own size'),
             pair('plant_%s' % i, PW, 'on the plant (full detail)', 'plant %d -> %d parts' % (b['plant'], a['plant'])),
             pair('coat_%s_Gold' % i, PW, 'Gold coat', 'the white "_Neutral" twin, Metal'),
             pair('coat_%s_Diamond' % i, PW, 'Diamond coat', 'the white "_Neutral" twin, Glass')]
    h = max(t.height for t in tiles)
    band = Image.new('RGB', (W2, h + 46), (10, 20, 15))
    d = ImageDraw.Draw(band)
    d.text((14, 8), '%s  (%s, %s): before | after' % (name, i, module), font=font(22), fill=HEAD)
    x = (W2 - sum(t.width for t in tiles) - 8 * (len(tiles) - 1)) // 2
    for t in tiles:
        band.paste(t, (x, 40))
        x += t.width + 8
    blocks.append(band)
GW = 230
tiles = []
for i, name, _ in FRUIT:
    t = Image.new('RGB', (GW * 2 + 4, GW + 26), BG)
    t.paste(img(before_dir, 'grow_' + i, GW), (0, 0))
    t.paste(img(after_dir, 'grow_' + i, GW), (GW + 4, 0))
    d = ImageDraw.Draw(t)
    d.text((t.width // 2, GW + 4), name + ' growing (75 %): parts | mesh', font=font(14), fill=INK, anchor='ma')
    tiles.append(t)
band = Image.new('RGB', (W2, GW + 26 + 46), (10, 20, 15))
d = ImageDraw.Draw(band)
d.text((14, 8), 'Growing: the fruit grows from its socket (the generic growth path scales the mesh like any part)', font=font(22), fill=HEAD)
x = (W2 - sum(t.width for t in tiles) - 12 * (len(tiles) - 1)) // 2
for t in tiles:
    band.paste(t, (x, 40))
    x += t.width + 12
blocks.append(band)
H2 = 92 + sum(b.height for b in blocks) + 70
sheet = Image.new('RGB', (W2, H2), (10, 20, 15))
d = ImageDraw.Draw(sheet)
d.text((W2 // 2, 14), 'R149: baked mesh bodies for the Watermelon, Snow Melon and Ember Pumpkin (three.js preview of the real build path)', font=font(27), fill=INK, anchor='ma')
d.text((W2 // 2, 54), 'Both columns are this checkout on the Roblox mock: "parts" = no bake (FruitMeshes149 keeps the R149 fruit), "baked mesh" = after the server bake; '
       'the meshes are drawn from the vertex data FruitMeshes149 generated.', font=font(15, False), fill=SUB, anchor='ma')
y = 92
for b in blocks:
    sheet.paste(b, (0, y))
    y += b.height
foot = ['Approximate: plain materials, no Roblox Future lighting; Neon drawn unlit; vertex colours x part colour like an EditableMesh MeshPart. Parts = visible parts in the picture / the plant.',
        'Same fruit centres, sockets, radii, FruitCount and connectors; stem, tendril / curl, leaf and the gloss patch (hidden on Gold / Diamond) stay parts.']
for k, line in enumerate(foot):
    d.text((W2 // 2, y + 12 + k * 22), line, font=font(14, False), fill=GOLD, anchor='ma')
sheet.save(os.path.join(out, 'fruit_meshes.png'))
print('wrote fruit_meshes.png', sheet.size)
