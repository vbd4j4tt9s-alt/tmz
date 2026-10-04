"""Usage: python3 make_sheets.py <scenes.txt> <dir with the rendered PNGs> <out dir>
Composes fruit_models_today.png (every active fruit, grouped by biome, framed with its priority) and fruit_models_proposed.png
(cocoa / pepper references, prototypes next to today's fruit, Phase-2 meshes, plants before / after) from render_fruit_models.mjs's
output and the AUDIT / INFO / PLANT rows of dump_fruit_models.luau. Approximate renders (three.js), not Roblox screenshots."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

scenes, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
BG, INK, SUB, HEAD = (18, 30, 26), (255, 255, 255), (200, 216, 206), (150, 226, 170)
audit, info, plant = {}, {}, {}
for line in open(scenes, encoding='utf-8'):
    f = line.rstrip('\n').split('\t')
    if f[0] == 'AUDIT':
        audit[f[1]] = {'name': f[2], 'biome': f[3], 'rarity': f[4], 'fruits': int(f[5]), 'source': f[6], 'plant': int(f[7]), 'mesh': int(f[8]), 'harvest': int(f[9]), 'shapes': f[11]}
    elif f[0] == 'INFO':
        info[f[1]] = {'id': f[2], 'parts': int(f[7]), 'today': int(f[11])}
    elif f[0] == 'PLANT':
        plant[f[1]] = {'before': int(f[4]), 'after': int(f[8])}
standins = json.load(open(os.path.join(src, 'standins.json')))


def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def img(name, w, h=None):
    im = Image.open(os.path.join(src, name + '.png')).convert('RGB')
    h = h or w
    scale = max(w / im.width, h / im.height)
    im = im.resize((int(im.width * scale + .5), int(im.height * scale + .5)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))


def tile(name, w, h, cap, sub, border=None, sub2=None):
    caph = 52 if not sub2 else 70
    t = Image.new('RGB', (w, h + caph), BG)
    t.paste(img(name, w, h), (0, 0))
    d = ImageDraw.Draw(t)
    if border:
        d.rectangle([0, 0, w - 1, h - 1], outline=border, width=5)
    d.text((w // 2, h + 5), cap, font=font(17), fill=INK, anchor='ma')
    d.text((w // 2, h + 27), sub, font=font(13, False), fill=SUB, anchor='ma')
    if sub2:
        d.text((w // 2, h + 46), sub2, font=font(13, False), fill=(255, 214, 120), anchor='ma')
    return t


# Priority per fruit (fruit_models.md section 2): P1 blocky body, P2 plain round / heavy, OK stylised or already good, REF baked mesh.
P1 = {'SunflowerSeed', 'AppleSeed', 'AshRoseSeed', 'CactusSeed', 'SnowdropSeed', 'ElderbloomSeed', 'LanternFernSeed'}
P2 = {'EmberBloomSeed', 'BluebellSeed', 'IceberrySeed', 'AmethystSeed', 'PineappleSeed'}
REF = {'CocoaSeed', 'FirePepperSeed', 'PrismOrchidSeed', 'AncientWorldrootSeed'}
COL = {'P1': (232, 72, 60), 'P2': (240, 170, 50), 'OK': (110, 170, 120), 'REF': (255, 220, 90)}


def prio(i):
    return 'REF' if i in REF else 'P1' if i in P1 else 'P2' if i in P2 else 'OK'


# ---------------------------------------------------------------- today
T, GAP, LABEL = 200, 8, 120
order = ['Forest', 'Jungle', 'Desert', 'Snow', 'Lava', 'Crystal', 'Storm', 'Mech', 'Verity']
rows = [(b, [i for i in audit if audit[i]['biome'] == b]) for b in order]
rows = [(b, ids) for b, ids in rows if ids]
rows[-2] = ('Mech + Verity', rows[-2][1] + rows[-1][1]) if rows[-1][0] == 'Verity' else rows[-2]
if rows[-1][0] == 'Verity':
    rows.pop()
cols = max(len(ids) for _, ids in rows)
TITLE, FOOT, ROWH = 96, 92, T + 52 + GAP
W = LABEL + cols * (T + GAP) + GAP
sheet = Image.new('RGB', (W, TITLE + len(rows) * ROWH + FOOT), (10, 20, 15))
d = ImageDraw.Draw(sheet)
d.text((W // 2, 14), 'Fruit models today: every active fruit as the hotbar / sell viewport builds it (%d fruits)' % len(audit), font=font(28), fill=INK, anchor='ma')
legend = [('P1  blocky body: redo first', 'P1'), ('P2  plain round / heavy: improve', 'P2'), ('OK  stylised or already good', 'OK'), ('REF  baked mesh (cocoa / pepper look)', 'REF')]
x = 40
for text, k in legend:
    d.rectangle([x, 56, x + 26, 76], outline=COL[k], width=4)
    d.text((x + 34, 57), text, font=font(16, False), fill=SUB)
    x += 34 + int(font(16, False).getlength(text)) + 40
y = TITLE
for biome, ids in rows:
    d.text((LABEL // 2, y + T // 2), biome.replace(' + ', '\n+ '), font=font(20), fill=HEAD, anchor='mm', align='center')
    x = LABEL
    for i in ids:
        a = audit[i]
        sub = '%s | %d part%s%s' % (a['rarity'], a['harvest'], '' if a['harvest'] == 1 else 's', ' (mesh)' if 'ApprovedMesh' in a['shapes'] else '')
        sheet.paste(tile('today_' + i, T, T, a['name'], sub, COL[prio(i)]), (x, y))
        x += T + GAP
    y += ROWH
note = ['Approximate three.js renders of the real modules on the Roblox mock (plain materials; no Roblox textures, decals, Future lighting or bloom). Parts = parts in the',
        'hotbar / sell picture (HarvestPresentation.Build, stems hidden). Baked meshes are drawn from their real vertex data, read from the place file (ServerStorage, not in the repo)'
        + ('.' if not standins else '; NO place file given: %d scene(s) use stand-in ellipsoids.' % len(standins)),
        'Mech fruits are holograms in game (projection effect not drawn). Verity\'s face is a decal (not drawn).']
for k, line in enumerate(note):
    d.text((W // 2, y + 8 + k * 22), line, font=font(15, False), fill=(255, 214, 120), anchor='ma')
sheet.save(os.path.join(out, 'fruit_models_today.png'))
print('wrote fruit_models_today.png', sheet.size)

# ---------------------------------------------------------------- proposed
W2 = 1880
blocks = []


def band(title, tiles, gap=8):
    w = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    h = max(t.height for t in tiles)
    b = Image.new('RGB', (W2, h + 44), (10, 20, 15))
    dd = ImageDraw.Draw(b)
    dd.text((14, 8), title, font=font(22), fill=HEAD)
    x = (W2 - w) // 2
    for t in tiles:
        b.paste(t, (x, 40))
        x += t.width + gap
    blocks.append(b)


def pair(today, proto, w, cap, sub, sub2=None, labels=('today', 'proposed')):
    a, b = img(today, w), img(proto, w)
    caph = 52 if not sub2 else 70
    t = Image.new('RGB', (w * 2 + 4, w + caph), BG)
    t.paste(a, (0, 0)); t.paste(b, (w + 4, 0))
    dd = ImageDraw.Draw(t)
    dd.rectangle([0, 0, w - 1, w - 1], outline=COL['P1'], width=3)
    dd.rectangle([w + 4, 0, 2 * w + 3, w - 1], outline=(110, 210, 140), width=3)
    for k, lab in enumerate(labels):
        dd.rectangle([k * (w + 4) + 6, 6, k * (w + 4) + 14 + int(font(13).getlength(lab)), 26], fill=(0, 0, 0))
        dd.text((k * (w + 4) + 10, 9), lab, font=font(13), fill=INK)
    dd.text((w + 2, w + 5), cap, font=font(18), fill=INK, anchor='ma')
    dd.text((w + 2, w + 28), sub, font=font(14, False), fill=SUB, anchor='ma')
    if sub2:
        dd.text((w + 2, w + 48), sub2, font=font(14, False), fill=(255, 214, 120), anchor='ma')
    return t


R = 296
band('References: the cocoa pod and peppers (baked EditableMesh fruit; Plasma Pepper = parts)', [
    tile('today_CocoaSeed', R, R, 'Cocoa pod', 'FlutedCocoa: 10 flutes, colour gradient', COL['REF'], '1 mesh + pedicel'),
    tile('ref_cocoa_plant', R, R, 'Cocoa tree (Jungle Common)', 'TreeReworkData3, 4 pods', COL['REF'], '%d parts' % audit['CocoaSeed']['plant']),
    tile('today_FirePepperSeed', R, R, 'Fire Pepper', 'SmoothFirePepper mesh + 3 sepals + stalk', COL['REF'], '%d parts' % audit['FirePepperSeed']['harvest']),
    tile('ref_fire_plant', R, R, 'Fire Pepper plant (Mythic, x2)', 'meshes: stems, leaves, peppers', COL['REF'], '%d parts' % audit['FirePepperSeed']['plant']),
    tile('today_PrismOrchidSeed', R, R, 'Prism Pepper', 'SmoothPrismPepper: same shape, violet', COL['REF'], '%d parts' % audit['PrismOrchidSeed']['harvest']),
    tile('today_PlasmaPepperSeed', R, R, 'Plasma Pepper (Mech)', 'parts: shell rings, neon seams, ribs', COL['OK'], '%d parts' % audit['PlasmaPepperSeed']['harvest']),
])
PW = 178
protos = [('Watermelon', 'SunflowerSeed', 'Watermelon', 'ellipsoid rind, 7 stripe bands, stem, leaf, gloss'),
          ('Apple', 'AppleSeed', 'Apple', 'shoulder lobes, base tone, dimple, stem, leaf'),
          ('EmberPumpkin', 'EmberBloomSeed', 'Ember Pumpkin', '10 ribs, neon ember grooves, curled stem'),
          ('AshTomato', 'AshRoseSeed', 'Ash Tomato', '5 lobes, ember seams, star calyx, ash bloom'),
          ('PricklyPear', 'CactusSeed', 'Prickly Pear', 'barrel, 3-tone gradient, navel, areoles'),
          ('Blueberry', 'BluebellSeed', 'Blueberry', 'frosty bloom shells, crowns, stalk, glints'),
          ('AmethystGrape', 'AmethystSeed', 'Amethyst Grape', '3/3/2/1 bunch, row gradient, shard'),
          ('LanternFern', 'LanternFernSeed', 'Lantern Fern', 'physalis husk: 5 ribs over a neon core'),
          ('SnowMelon', 'SnowdropSeed', 'Snow Melon', 'melon build, frost palette, snow cap'),
          ('Iceberry', 'IceberrySeed', 'Iceberry', 'blueberry build, ice palette')]
cells = [pair('today_' + i, 'proto_' + k, PW, n, d_, 'parts %d -> %d' % (info[k]['today'], info[k]['parts'])) for k, i, n, d_ in protos]
band('Part-based prototypes (FruitModels149.luau built with the real PlantVisuals.Part), today | proposed, parts in the hotbar picture', cells[:5])
band('', cells[5:])
blocks[-1] = blocks[-1].crop((0, 30, W2, blocks[-1].height))
MW = 232
mesh = [tile('today_SunflowerSeed', MW, MW, 'Watermelon today', 'Block + 18 stripes', COL['P1'], '%d parts' % info['Watermelon']['today']),
        tile('proto_Watermelon', MW, MW, 'Phase 1: parts', 'ellipsoid + bands', (110, 210, 140), '%d parts' % info['Watermelon']['parts']),
        tile('proto_WatermelonMesh', MW, MW, 'Phase 2: baked mesh', 'RibbedMelon149 + stem/leaf', (255, 220, 90), '%d parts' % info['WatermelonMesh']['parts']),
        tile('plant_after_WatermelonMesh', MW, MW, 'Phase 2 on the vine', 'wavy vertex-colour stripes', (255, 220, 90), 'plant %d -> %d parts' % (plant['WatermelonMesh']['before'], plant['WatermelonMesh']['after'])),
        tile('today_EmberBloomSeed', MW, MW, 'Ember Pumpkin today', '6 lobes', COL['P2'], '%d parts' % info['EmberPumpkin']['today']),
        tile('proto_EmberPumpkin', MW, MW, 'Phase 1: parts', '10 ribs + neon grooves', (110, 210, 140), '%d parts' % info['EmberPumpkin']['parts']),
        tile('proto_EmberPumpkinMesh', MW, MW, 'Phase 2: baked mesh', 'LobedPumpkin149 + stem/leaf', (255, 220, 90), '%d parts' % info['EmberPumpkinMesh']['parts'])]
band('Phase 2: NEW baked meshes generated in-repo (gen_meshes.py, ApprovedPlantMeshData format) through the same s=\'ApprovedMesh\' path', mesh)
LW = 222
plants = []
for k, i, n in [('Watermelon', 'SunflowerSeed', 'Watermelon vine'), ('Apple', 'AppleSeed', 'Apple tree'), ('EmberPumpkin', 'EmberBloomSeed', 'Ember Pumpkin'), ('AmethystGrape', 'AmethystSeed', 'Amethyst Grape vine')]:
    plants.append(pair('plant_before_' + k, 'plant_after_' + k, LW, n, 'same fruit centres, connectors kept', 'plant %d -> %d parts' % (plant[k]['before'], plant[k]['after'])))
band('On the plant (today | proposed), full detail', plants)
H2 = 80 + sum(b.height for b in blocks) + 70
sheet = Image.new('RGB', (W2, H2), (10, 20, 15))
d = ImageDraw.Draw(sheet)
d.text((W2 // 2, 16), 'R149 proposal: cocoa-pod / pepper style for the other fruits (three.js preview of the real build path)', font=font(28), fill=INK, anchor='ma')
d.text((W2 // 2, 52), 'Prototypes live in docs/proposals/R149/preview/FruitModels149.luau (scratch, not wired into the game).', font=font(16, False), fill=SUB, anchor='ma')
y = 80
for b in blocks:
    sheet.paste(b, (0, y)); y += b.height
foot = ['Approximate: plain materials, no Roblox textures / Future lighting; Neon drawn unlit. Baked meshes (Cocoa, Fire / Prism Pepper) come from their real vertex data in the place',
        'file (ServerStorage, not in the repo)' + ('; the two Phase-2 meshes are generated by gen_meshes.py.' if not standins else '; NO place file given: baked meshes are stand-in ellipsoids.')]
for k, line in enumerate(foot):
    d.text((W2 // 2, y + 12 + k * 22), line, font=font(15, False), fill=(255, 214, 120), anchor='ma')
sheet.save(os.path.join(out, 'fruit_models_proposed.png'))
print('wrote fruit_models_proposed.png', sheet.size)
