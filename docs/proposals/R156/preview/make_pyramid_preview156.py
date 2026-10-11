"""R156 preview of the Desert's secret pyramid (docs/proposals/R156/pyramid.png).

  python3 make_pyramid_preview156.py scenes <before scene.json> <after scene.json> <pack.txt> <SeedPackArtDesert06.lua> <out dir>
      before / after: R152's sweep scenes (run_variant.sh: the owner's place after the REAL start-up passes, the REAL keyboard client around a runner next to the
      pyramid) of the base commit's src (the Sunscar Pyramid) and of this checkout's (the Classic Pyramid). pack.txt: dump_pack156.luau's PACK line (the pack the
      REAL client script builds, its parts in the world). The pack's three pouch MeshParts are uploaded meshes (not available offline): they are drawn from the
      design's V120 native render data (Desert_06, the data the approved meshes were made from; R153 tools/pouch_mesh.py reads the same files), placed by the
      pack's root frame and visual scale. Writes before.json, after.json (with the pack) and claimed.json (without it), cut to the Desert around the pyramid.
  python3 make_pyramid_preview156.py sheet <rendered dir> <out png> <map log>
      Composes the views rendered by render_pyramid.mjs (pyramid_views.json) into one sheet with captions; the numbers come from pyramid_map156's GEO line.
APPROXIMATE: three.js, not Roblox (no Future lighting, no PBR materials, Limestone drawn as a plain detail texture, no bloom)."""
import json, math, os, re, sys

KEEP = (-100, 30, 860, 1150)  # x0, x1, z0, z1: the Desert around the pyramid


def load_scene(path):
    d = json.load(open(path))
    d['parts'] = [p for p in d['parts'] if KEEP[0] <= p['p'][0] <= KEEP[1] and KEEP[2] <= p['p'][2] <= KEEP[3] or 'BiomeGround_2' in p['path'] or 'Biome_2_' in p['path']]
    d['guis'] = [g for g in d.get('guis', []) if KEEP[0] <= g['p'][0] <= KEEP[1] and KEEP[2] <= g['p'][2] <= KEEP[3]]
    d['lights'] = []
    d['emitters'] = []
    return d


def native(path, key):
    s = open(path, encoding='utf-8').read()
    comps = []
    for m in re.finditer(r'\{Name="([^"]+)",V="([^"]*)",F="([^"]*)",Colors="([^"]*)",FaceColors="([^"]*)"', s):
        v = list(map(int, m.group(2).split(','))) if m.group(2) else []
        f = list(map(int, m.group(3).split(','))) if m.group(3) else []
        cols = list(map(int, m.group(4).split(','))) if m.group(4) else []
        fc = list(map(int, m.group(5).split(','))) if m.group(5) else []
        comps.append((m.group(1), v, f, cols, fc))
    assert comps, 'no native render data in ' + path
    return comps


def pack_meshes(pack, comps):
    r, p, k = pack['root']['r'], pack['root']['p'], pack['scale']
    pos, col = [], []
    for name, v, f, cols, fc in comps:
        pal = [cols[i:i + 3] for i in range(0, len(cols), 3)]
        for t in range(0, len(f), 3):
            c = pal[(fc[t // 3] if t // 3 < len(fc) else 1) - 1] if pal else [200, 200, 200]
            for vi in f[t:t + 3]:
                x, y, z = (v[(vi - 1) * 3] / 1e4 * k, v[(vi - 1) * 3 + 1] / 1e4 * k, v[(vi - 1) * 3 + 2] / 1e4 * k)
                pos += [p[0] + r[0][0] * x + r[0][1] * y + r[0][2] * z, p[1] + r[1][0] * x + r[1][1] * y + r[1][2] * z, p[2] + r[2][0] * x + r[2][1] * y + r[2][2] * z]
                col += c
    return [{'pos': [round(a, 4) for a in pos], 'col': col}]


def scenes(before, after, packtxt, lua, out):
    os.makedirs(out, exist_ok=True)
    line = next(l for l in open(packtxt) if l.startswith('PACK '))
    pack = json.loads(line[5:])
    b = load_scene(before)
    a = load_scene(after)
    json.dump(b, open(os.path.join(out, 'before.json'), 'w'))
    claimed = dict(a)
    json.dump(claimed, open(os.path.join(out, 'claimed.json'), 'w'))
    withpack = dict(a)
    withpack['parts'] = a['parts'] + [p for p in pack['parts'] if p['class'] != 'MeshPart']
    withpack['meshes'] = pack_meshes(pack, native(lua, pack['key']))
    json.dump(withpack, open(os.path.join(out, 'after.json'), 'w'))
    json.dump(pack, open(os.path.join(out, 'pack.json'), 'w'))
    print('scenes: before %d parts, after %d parts + the pack (%d parts, %d triangles of pouch)' % (len(b['parts']), len(a['parts']), len(pack['parts']), len(withpack['meshes'][0]['pos']) // 9))


def sheet(rendered, out_png, maplog):
    from PIL import Image, ImageDraw, ImageFont
    geo = ''
    for l in open(maplog, encoding='utf-8', errors='replace'):
        if l.startswith('GEO '):
            geo = l[4:].strip()
    num = dict(re.findall(r'(scale|base|top|slab|wall|reach|walkway|keys left out|parts) ([0-9.]+)', geo))
    W, Hh = 640, 360
    font = lambda n, b=False: ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf' % ('-Bold' if b else ''), n)
    cells = [
        ('before_overview', 'BEFORE: the Sunscar Pyramid (9 tiers, walk-through)'),
        ('after_overview', 'AFTER: ur Classic Pyramid, same spot, scale %s' % num.get('scale', '?')),
        ('after_cut', 'cut open: the hollow chamber + the floating Desert Mythic pack'),
        ('claimed_cut', 'after u claim it: the pack is gone (for u only)'),
        ('after_prompt', 'standing outside at the base: Hold E shows through the wall'),
        ('after_plan', 'from above: on the old footprint, keys under it left out'),
    ]
    head = 64
    cap = 30
    foot = 92
    img = Image.new('RGB', (2 * W + 30, head + 3 * (Hh + cap + 10) + foot), (24, 26, 31))
    d = ImageDraw.Draw(img)
    d.text((16, 12), 'R156 Desert pyramid: ur Classic Pyramid with the secret Mythic pack (preview)', font=font(24, True), fill=(250, 226, 150))
    d.text((16, 40), 'built from the real game code on ur place (approximate render: three.js, not Roblox lighting)', font=font(15), fill=(190, 196, 206))
    for i, (name, text) in enumerate(cells):
        x = 10 + (i % 2) * (W + 10)
        y = head + (i // 2) * (Hh + cap + 10)
        path = os.path.join(rendered, name + '.png')
        if os.path.exists(path):
            im = Image.open(path).convert('RGB').resize((W, Hh), Image.LANCZOS)
            img.paste(im, (x, y + cap))
        else:
            d.rectangle((x, y + cap, x + W, y + cap + Hh), outline=(120, 60, 60))
        d.text((x + 4, y + 5), text, font=font(17, True), fill=(235, 238, 242))
        inset = os.path.join(rendered, 'after_pack.png')
        if name == 'after_cut' and os.path.exists(inset):  # the pack up close, in the corner of the cut-away
            im = Image.open(inset).convert('RGB').resize((256, 144), Image.LANCZOS)
            d.rectangle((x + W - 266, y + cap + Hh - 154, x + W - 6, y + cap + Hh - 6), fill=(250, 226, 150))
            img.paste(im, (x + W - 264, y + cap + Hh - 152))
    fy = head + 3 * (Hh + cap + 10) + 6
    lines = [
        'base %s x %s studs (the old one was 44.8), %s tall, %s parts; each step %s tall; walls %s thick; Hold E reach %s studs from the pack (base half-diagonal + 6)' % (
            num.get('base', '?'), num.get('base', '?'), num.get('top', '?'), num.get('parts', '?'), num.get('slab', '?'), num.get('wall', '?'), num.get('reach', '?')),
        'a %s-stud walkway stays along the left wall; %s keyboard keys under the pyramid are left out (its first step is lower than a key)' % (num.get('walkway', '?'), num.get('keys left out', '?')),
        'the pack + the prompt are drawn per player: claimed players see the pyramid without them. The pouch is drawn from its own render data, the rest from the dumped parts.',
    ]
    for i, l in enumerate(lines):
        d.text((16, fy + i * 24), l, font=font(15), fill=(200, 206, 214))
    img.save(out_png)
    print('wrote', out_png, img.size)


if __name__ == '__main__':
    if sys.argv[1] == 'scenes':
        scenes(*sys.argv[2:7])
    elif sys.argv[1] == 'sheet':
        sheet(*sys.argv[2:5])
