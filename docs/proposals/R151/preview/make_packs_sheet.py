"""R151 pack audit contact sheet.
Usage: python3 make_packs_sheet.py jobs <scenes_after.txt> <jobs_before.json> <jobs_after.json>
       python3 make_packs_sheet.py sheet <render dir> <scenes_after.txt> <out png>

jobs  : writes the render jobs (render_packs.mjs) for the AFTER side (every design front + side, the special packs, the fixed defects) and for the BEFORE
        side (the two fixed defects as they were).
sheet : composes docs/proposals/R151/packs_audit.png from the renders: every one of the 42 ordinary designs (front and side), the Void / Mech / Verity
        packs, and the defects before -> after, circled.
Circles: green = fixed in R151, red = the defect as it was, orange = a suspect the place file cannot settle (the pouch meshes are uploaded assets whose
vertices are not available offline: they are drawn as their Size box) - to be looked at in Studio, blue = deliberate (a detached effect / a special design).
Approximate renders (three.js): plain materials, no Roblox textures, no Future lighting, MeshParts as stand-in rounded pouches."""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFont

BIOMES = ['Forest', 'Desert', 'Snow', 'Lava', 'Crystal', 'Jungle', 'Storm']
THEME_SCALE = {'Forest': 1.0, 'Desert': 1.04, 'Snow': 1.06, 'Lava': 1.08, 'Crystal': 1.10, 'Jungle': 1.02, 'Storm': 1.12}
BAG_SCALE = [.86, .92, 1.0, 1.06, .896, .96]
GREEN, RED, ORANGE, BLUE = (80, 210, 120), (255, 90, 80), (255, 170, 50), (90, 170, 255)
BG = (16, 19, 30)


def font(size, bold=True):
    try:
        return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
    except OSError:
        return ImageFont.load_default()


def scenes_of(path):
    out = {}
    for line in open(path, encoding='utf-8'):
        if line.startswith('SCENE '):
            s = json.loads(line[6:]); out[s['label']] = s
    return out


def body_of(scene):
    for p in scene['parts']:
        if p['name'] == 'ApprovedMesh01':
            return p
    return None


def is_tall(scene):
    b = body_of(scene)
    return b is not None and b['p'][1] + b['size'][1] / 2 > 1.02 + .05


T_W, T_H = 150, 176      # a front thumbnail
S_W = 86                 # a side thumbnail
SS = 2                   # rendered at 2x, shown at 1x


def jobs(after_scenes, jb, ja):
    sc = scenes_of(after_scenes)
    after = []
    for stage, biome in enumerate(BIOMES, 1):
        for d in range(1, 7):
            key = '%s_%02d' % (biome, d)
            m = ['TearStrip4', 'TearStrip5'] if is_tall(sc[key]) else []
            after.append({'scene': key, 'name': 'front', 'w': T_W * SS, 'h': T_H * SS, 'opts': {'az': 0, 'el': 4, 'fit': 'body', 'marks': m}})
            after.append({'scene': key, 'name': 'side', 'w': S_W * SS, 'h': T_H * SS, 'opts': {'az': 90, 'el': 4, 'fit': 'body', 'fov': 28}})
    for key in ('Void', 'Mech', 'Verity'):
        after.append({'scene': key, 'name': 'front', 'w': 300 * SS, 'h': 330 * SS, 'opts': {'az': 14, 'el': 7, 'fit': 'nofx' if key != 'Void' else 'all', 'marks': ['EventHorizon*', 'HaloDebris*'] if key == 'Void' else []}})
        after.append({'scene': key, 'name': 'side', 'w': 160 * SS, 'h': 330 * SS, 'opts': {'az': 90, 'el': 4, 'fit': 'all' if key == 'Void' else 'nofx', 'marks': ['EventHorizon*'] if key == 'Void' else []}})
    after.append({'scene': 'Giant25_Forest_03', 'name': 'near', 'w': 360 * SS, 'h': 330 * SS, 'opts': {'az': 18, 'el': 8, 'fade': .92, 'marks': ['BottomSeal', 'TearStrip*']}})
    after.append({'scene': 'Giant25_Forest_03', 'name': 'far', 'w': 360 * SS, 'h': 330 * SS, 'opts': {'az': 18, 'el': 8, 'marks': []}})
    # the Void's front details from the side, close up: a star at (-.66, .50) in front of the pouch
    zoom = {'az': 90, 'el': 0, 'zoom': [-.66, .5, -.6, .075], 'fov': 24, 'marks': ['StarVF1', 'ApprovedMesh01'], 'only': ['StarVF1', 'ApprovedMesh01'], 'outline': False, 'ortho': True, 'bg': 0x8e9ab0}
    after.append({'scene': 'Void', 'name': 'zoom', 'w': 340 * SS, 'h': 250 * SS, 'opts': zoom})
    before = [j for j in after if j['scene'] == 'Giant25_Forest_03' and j['name'] == 'near'] + [j for j in after if j['scene'] == 'Void' and j['name'] == 'zoom']
    json.dump(after, open(ja, 'w')); json.dump(before, open(jb, 'w'))
    print('jobs: %d after, %d before' % (len(after), len(before)))


def load(d, prefix, scene, name):
    return Image.open('%s/%s_%s_%s.png' % (d, prefix, scene, name)).convert('RGB')


def marks_of(d, prefix):
    p = '%s/%s_marks.json' % (d, prefix)
    return json.load(open(p)) if os.path.exists(p) else {}


def union(rects):
    rs = list(rects)
    return [min(r[0] for r in rs), min(r[1] for r in rs), max(r[2] for r in rs), max(r[3] for r in rs)] if rs else None


def circle(draw, rect, scale, color, pad=10, width=3, dashed=False):
    if rect is None:
        return
    x0, y0, x1, y1 = [v * scale for v in rect]
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2 + pad, (y1 - y0) / 2 + pad
    rx, ry = max(rx, 12), max(ry, 12)
    if not dashed:
        draw.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=color, width=width)
    else:
        for k in range(0, 360, 14):
            draw.arc([cx - rx, cy - ry, cx + rx, cy + ry], k, k + 8, fill=color, width=width)


def sheet(d, scenes_path, out):
    sc = scenes_of(scenes_path)
    am = marks_of(d, 'after'); bm = marks_of(d, 'before')
    W = 2020
    CELL = T_W + S_W + 22
    LAB = 150
    top = 190
    rows_h = 7 * (T_H + 54)
    sec2 = top + rows_h + 30
    sec3 = sec2 + 520
    H = sec3 + 560
    img = Image.new('RGB', (W, H), BG); dr = ImageDraw.Draw(img)
    dr.text((W // 2, 12), 'Seed pack models: every design, front and side, with the defects circled (R151 audit)', font=font(30), fill=(255, 255, 255), anchor='ma')
    for i, t in enumerate(['three.js preview of the parts the REAL modules build (SeedPackVisuals / SeedPackRenderer / EclipsePackArt / SpecialPackArt89 / VerityPackArt) from the REAL templates of the owner\'s place.',
                           'The 115 pouch MeshParts are uploaded assets whose vertices and printed vertex colours are not in the place file: each is drawn as a STAND-IN rounded pouch of its Size box (thin outline);',
                           'their prints and true silhouettes are NOT shown. Seal, tear strips, Void, Mech and Verity parts are drawn exactly as built. Not a Studio screenshot (no textures, no Future lighting).']):
        dr.text((W // 2, 54 + i * 19), t, font=font(14, False), fill=(190, 198, 215), anchor='ma')
    lx = 60
    for color, text in [(GREEN, 'fixed in R151'), (RED, 'the defect as it was'), (ORANGE, 'suspect: needs the real mesh (Studio)'), (BLUE, 'deliberate (detached fx / special design)')]:
        dr.ellipse([lx, 132, lx + 26, 158], outline=color, width=4); dr.text((lx + 36, 134), text, font=font(17, False), fill=(225, 230, 240)); lx += 40 + dr.textlength(text, font=font(17, False)) + 40
    dr.text((60, 168), 'A. The 42 ordinary designs (7 biomes x Pack01..Pack06), pack scale 1: front and side. Orange: the 11 designs whose pouch rises above the standard top - their tear strips sit inside it.', font=font(16), fill=(255, 220, 140))
    # --- A. the grid
    for r, biome in enumerate(BIOMES):
        y = top + r * (T_H + 54)
        dr.text((14, y + 70), biome, font=font(24), fill=(255, 255, 255))
        dr.text((14, y + 100), 'x%.2f biome' % THEME_SCALE[biome], font=font(13, False), fill=(170, 180, 200))
        for c in range(6):
            key = '%s_%02d' % (biome, c + 1)
            x = LAB + c * (CELL + 8)
            f = load(d, 'after', key, 'front').resize((T_W, T_H), Image.LANCZOS)
            s = load(d, 'after', key, 'side').resize((S_W, T_H), Image.LANCZOS)
            img.paste(f, (x, y)); img.paste(s, (x + T_W + 4, y))
            b = body_of(sc[key]); scale = BAG_SCALE[c] * THEME_SCALE[biome]
            w, h = b['size'][0] * scale, b['size'][1] * scale
            tall = is_tall(sc[key])
            nm = len([p for p in sc[key]['parts'] if p['shape'] == 'Mesh'])
            dr.text((x, y + T_H + 3), key, font=font(15), fill=(255, 205, 120) if tall else (255, 255, 255))
            dr.text((x + 94, y + T_H + 5), '%.2f x %.2f studs' % (w, h), font=font(12, False), fill=(190, 198, 215))
            dr.text((x, y + T_H + 22), 'pouch %.2f x %.2f x %.2f, %d mesh%s%s' % (b['size'][0], b['size'][1], b['size'][2], nm, '' if nm == 1 else 'es', ', TALL' if tall else ''), font=font(12, False), fill=(255, 205, 120) if tall else (150, 160, 180))
            if tall:
                mk = am.get('%s_front' % key, {})
                rect = union([mk[n] for n in ('TearStrip4', 'TearStrip5') if n in mk])
                if rect:
                    layer = Image.new('RGBA', (T_W, T_H), (0, 0, 0, 0)); ld = ImageDraw.Draw(layer)
                    circle(ld, rect, 1 / SS, ORANGE, pad=9, width=3, dashed=True)
                    img.paste(layer, (x, y), layer)
    # --- B. special packs
    y = sec2
    dr.text((14, y), 'B. The special packs (they do NOT use the standard pouch the way the ordinary designs do)', font=font(18), fill=(255, 220, 140))
    notes = {
        'Void': ['Forest_01 pouch, painted near-black + 180 parts of print and halo;', 'blue: the event-horizon halo (23 segments) and 3 debris blocks are welded', 'to the pack but float 0.1 - 0.3 u off the pouch on purpose (they spin).'],
        'Mech': ['Forest_01 pouch painted white + 174 parts: 5 x 6 fitted armour panels per', 'side, pistons, reactor, turbine. Every part touches the pouch box; 34 move', 'on MechServo motors (rest frame = C0, checked).'],
        'Verity': ['NO pouch mesh: a plain-parts sachet (R149), pure yellow with the face', 'as a Decal. Footprint = the Storm_02 pouch, but flat-faced and slimmer', '(56% depth): not the standard shape - see packs_audit.md for the options.'],
    }
    for i, key in enumerate(('Void', 'Mech', 'Verity')):
        x = 20 + i * 660
        f = load(d, 'after', key, 'front').resize((300, 330), Image.LANCZOS)
        s = load(d, 'after', key, 'side').resize((160, 330), Image.LANCZOS)
        img.paste(f, (x, y + 30)); img.paste(s, (x + 308, y + 30))
        dr.text((x, y + 366), key + ' pack', font=font(19), fill=(255, 255, 255))
        for j, t in enumerate(notes[key]):
            dr.text((x, y + 394 + j * 17), t, font=font(13, False), fill=(190, 198, 215))
        if key == 'Void':
            layer = Image.new('RGBA', (300, 330), (0, 0, 0, 0)); ld = ImageDraw.Draw(layer)
            mk = am.get('Void_front', {})
            rect = union([mk[n] for n in mk])
            circle(ld, rect, 1 / SS, BLUE, pad=4, width=3, dashed=True)
            img.paste(layer, (x, y + 30), layer)
    # --- C. fixed defects
    y = sec3 + 40
    dr.text((14, y - 24), 'C. Defects fixed in R151, before -> after', font=font(18), fill=(255, 220, 140))
    bn = load(d, 'before', 'Giant25_Forest_03', 'near').resize((360, 330), Image.LANCZOS)
    an = load(d, 'after', 'Giant25_Forest_03', 'near').resize((360, 330), Image.LANCZOS)
    img.paste(bn, (20, y + 20)); img.paste(an, (400, y + 20))
    for im_x, mk, color in ((20, bm.get('Giant25_Forest_03_near', {}), RED), (400, am.get('Giant25_Forest_03_near', {}), GREEN)):
        layer = Image.new('RGBA', (360, 330), (0, 0, 0, 0)); ld = ImageDraw.Draw(layer)
        for name in ('BottomSeal', 'TearStrip*'):
            circle(ld, mk.get(name), 1 / SS, color, pad=6, width=3)
        img.paste(layer, (im_x, y + 20), layer)
    dr.text((20, y + 356), 'BEFORE: a 25x pack with the camera close', font=font(14), fill=RED)
    dr.text((400, y + 356), 'AFTER: the whole pack fades', font=font(14), fill=GREEN)
    dr.text((20, y + 376), 'GiantVisualSafety fades every GiantVisualPart near the camera (pouch .92). The seal and the 8 tear strips', font=font(12, False), fill=(190, 198, 215))
    dr.text((20, y + 392), 'were never tagged: nine solid bars stayed behind in the air (all 156 giant packs of the test matrix).', font=font(12, False), fill=(190, 198, 215))
    bz = load(d, 'before', 'Void', 'zoom').resize((340, 250), Image.LANCZOS)
    az = load(d, 'after', 'Void', 'zoom').resize((340, 250), Image.LANCZOS)
    img.paste(bz, (800, y + 20)); img.paste(az, (1160, y + 20))
    for im_x, mk, color, label in ((800, bm.get('Void_zoom', {}), RED, '.031'), (1160, am.get('Void_zoom', {}), GREEN, '.015')):
        layer = Image.new('RGBA', (340, 250), (0, 0, 0, 0)); ld = ImageDraw.Draw(layer)
        star, pouch = mk.get('StarVF1'), mk.get('ApprovedMesh01')
        if star and pouch:
            sx0, sy0, sx1, sy1 = [v / SS for v in star]; px0, py0, px1, py1 = [v / SS for v in pouch]
            ym = (sy0 + sy1) / 2
            a, b = (sx1, px0) if sx1 <= px0 else (px1, sx0)
            ld.line([a, ym, b, ym], fill=color + (255,), width=3)
            for e in (a, b):
                ld.line([e, ym - 9, e, ym + 9], fill=color + (255,), width=3)
            ld.text((min(a, b) - 4, ym - 26), 'gap ' + label, font=font(13), fill=color + (255,))
            circle(ld, [v * SS for v in (sx0, sy0, sx1, sy1)], 1 / SS, color, pad=8, width=2)
        img.paste(layer, (im_x, y + 20), layer)
    dr.text((800, y + 276), 'BEFORE: star .031 off the pouch', font=font(14), fill=RED)
    dr.text((1160, y + 276), 'AFTER: backed, .015', font=font(14), fill=GREEN)
    dr.text((800, y + 296), 'Side view of one front star next to the stand-in pouch (pack units). The stars, specks and rune strokes', font=font(12, False), fill=(190, 198, 215))
    dr.text((800, y + 312), 'of the Void\'s print now reach back as far as the nebula discs do; their front face is where it was.', font=font(12, False), fill=(190, 198, 215))
    dr.text((1540, y + 20), 'Also fixed (not drawn):', font=font(14), fill=GREEN)
    for j, t in enumerate(['the pad under a world pack: moss patches and ice', 'glaze stood .018 - .019 over the pad top (inside the', '.02 z-fighting band): .006 thicker, .021 - .022 now.', '', 'Everything else: 0 floating parts, 0 unwelded parts,', '0 parts left behind in 120 simulated frames, the', 'same parts and pivot in every context.']):
        dr.text((1540, y + 46 + j * 17), t, font=font(12, False), fill=(190, 198, 215))
    dr.text((W // 2, H - 40), 'Every ordinary design is built by the same code from the same kind of template; they differ in their uploaded pouch mesh (42 distinct), tier scale (.86 - 1.06) and biome scale (1.00 - 1.12).', font=font(14, False), fill=(190, 198, 215), anchor='ma')
    img.save(out)
    print('wrote', out, img.size)


if __name__ == '__main__':
    if sys.argv[1] == 'jobs':
        jobs(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        sheet(sys.argv[2], sys.argv[3], sys.argv[4])
