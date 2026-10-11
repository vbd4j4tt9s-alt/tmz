"""R158 design preview: track walls per biome, the outer track (backdrops) and the base wall tops (docs/proposals/R158/design/).

  python3 make158.py html   <R156 pyramid.html> <out pyramid.html>
      R156's three.js map renderer with one change: Ice is drawn as an opaque, shiny material (Roblox Ice is not see-through; R156 drew it as glass).
  python3 make158.py scenes <world dir> <specs.txt> <out dir>
      world dir: R152 sweep scenes (run_variant.sh: the owner's place after every REAL start-up pass, the REAL keyboard client around a runner):
      hub.json and one per biome (forest.json, jungle.json ...). specs.txt: dump158.luau's output (walls158.lua's parts).
      Writes the scenes the renderer draws (cut to what each view can see) and views.json.
  python3 make158.py zfight <world dir> <specs.txt> [out.txt]
      R149's detector (docs/proposals/R149/tools/zfight.py, the R152 sweep's), on the whole real map of every scene with ALL the proposed parts in it
      (walls + backdrops in every biome scene, each base option alone in the hub scene). Counted: a finding with a new part in the coplanar / near / far
      tiers (two visible faces that point the same way, overlap, look different and lie within the depth buffer's reach: 0.02 - 0.043 stud), and the
      R152 hub decor's tight rule (the strict tier under 0.1 stud). The camera may be anywhere (also outside the walls), so far-off backdrops count too.
      Exits 1 when one is left.
  python3 make158.py sheet  <render out dir> <specs.txt> <design dir>
      Composes track_walls.png, outer_track.png and base_walls.png.
APPROXIMATE: three.js, not Roblox (no Future lighting, PBR materials or bloom; materials are drawn as simple detail textures)."""
import collections, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = 'Workspace/ChestChaseMap/'

# The view spot of every biome (z of the camera's target stretch) and the runner the keyboard is drawn around (render.sh passes the same).
SPOTS = collections.OrderedDict([
    ('forest', {'z': 0, 'runner': (-30, 10)}),
    ('jungle', {'z': 300, 'runner': (-30, 330)}),
    ('desert', {'z': 930, 'runner': (-30, 960)}),
    ('snow', {'z': 1480, 'runner': (-30, 1500)}),
    ('lava', {'z': 2380, 'runner': (-30, 2400)}),
    ('crystal', {'z': 3580, 'runner': (-30, 3600)}),
    ('storm', {'z': 5600, 'runner': (-30, 5620)}),
])
# Outer track views: (camera x, y, z offset), (look x, y, z offset): the side with the best backdrop.
OUTER = {
    'forest': ((24, 26, -40), (-150, 72, 70)),
    'jungle': ((30, 26, -110), (-170, 90, 90)),
    'desert': ((-40, 30, -150), (200, 90, 150)),
    'snow': ((30, 30, -150), (-220, 110, 150)),
    'lava': ((-30, 30, -200), (220, 110, 160)),
    'crystal': ((40, 30, -140), (-200, 90, 160)),
    'storm': ((0, 30, -170), (0, 90, 380)),
}


def load_specs(path):
    out = {'specs': {}, 'hide': {}, 'restyle': {}, 'biomes': [], 'budget': {}, 'options': {}}
    for line in open(path, encoding='utf-8'):
        if line.startswith('SPECS '):
            _, name, js = line.split(' ', 2)
            out['specs'][name] = json.loads(js)
        elif line.startswith('HIDE '):
            _, name, js = line.split(' ', 2)
            out['hide'][name] = json.loads(js)
        elif line.startswith('RESTYLE '):
            out['restyle'] = json.loads(line[8:])
        elif line.startswith('BIOMES '):
            out['biomes'] = json.loads(line[7:])
        elif line.startswith('BASEOPTIONS '):
            out['options'] = json.loads(line[12:])
        elif line.startswith('BUDGET '):
            out['budget'] = json.loads(line[7:])
    assert out['specs'], 'no SPECS lines in ' + path
    return out


def spec_part(s):
    c = s['CF']
    p = {'path': ROOT + s['Group'] + '/' + s['Name'], 'name': s['Name'], 'class': 'WedgePart' if s['Shape'] == 'Wedge' else 'CornerWedgePart' if s['Shape'] == 'CornerWedge' else 'Part',
         'shape': s['Shape'], 'size': list(s['Size']), 'p': [c[0], c[1], c[2]], 'r': [[c[3], c[4], c[5]], [c[6], c[7], c[8]], [c[9], c[10], c[11]]],
         'color': list(s['Color']), 'material': s['Material'], 't': s.get('Transparency', 0) or 0, 'area': 'r158'}
    if s.get('Mesh') == 'Sphere':
        p['mesh'] = {'type': 'Sphere', 'scale': [1, 1, 1]}
    return p


def box_of(p):
    r, sz = p['r'], p['size']
    if len(r) == 9:
        r = [r[0:3], r[3:6], r[6:9]]
    e = [sum(abs(r[i][j]) * sz[j] for j in range(3)) / 2 for i in range(3)]
    return [p['p'][i] - e[i] for i in range(3)], [p['p'][i] + e[i] for i in range(3)]


def overlaps(p, x0, x1, z0, z1):
    lo, hi = box_of(p)
    return hi[0] >= x0 and lo[0] <= x1 and hi[2] >= z0 and lo[2] <= z1


def restyled(parts, restyle):
    out = []
    for p in parts:
        key = p['path'].replace(ROOT, '')
        if key in restyle:
            p = dict(p)
            p['color'] = restyle[key]['Color']
            p['material'] = restyle[key]['Material']
        out.append(p)
    return out


def hidden(parts, prefixes):
    return [p for p in parts if not any((ROOT + h) in p['path'] for h in prefixes)]


SIGN = ('HubDecor151/Gate/Gate sign',)  # the "THE TRACK" sign: removed by the R157b hotfix, so it is not drawn


def write(path, parts, guis=None, lights=None):
    json.dump({'parts': parts, 'guis': guis or [], 'lights': lights or [], 'emitters': []}, open(path, 'w'))


def biome_box(b, extra=0):
    return b['Z0'] - extra, b['Z1'] + extra


def cmd_html(src, out):
    s = open(src, encoding='utf-8').read()
    old = "if(m==='Glass'||m==='Ice'||m==='ForceField')kind='glass'"
    assert s.count(old) == 1, 'R156 renderer changed: ' + old
    s = s.replace(old, "if(m==='Glass'||m==='ForceField')kind='glass'")
    # the sky dome (radius 5000) follows the camera: the Storm end of the track is 6000 studs from the origin
    for a, b in (("if(!view.ortho)s.add(skyDome(night));", "let dome=null;if(!view.ortho){dome=skyDome(night);s.add(dome)}"),
                 ("renderer.render(s,cam);", "if(dome)dome.position.copy(cam.position);renderer.render(s,cam);")):
        assert s.count(a) == 1, 'R156 renderer changed: ' + a
        s = s.replace(a, b)
    s = s.replace('<title>Desert pyramid preview</title>', '<title>R158 walls preview</title>')
    open(out, 'w', encoding='utf-8').write(s)
    print('wrote', out)


def views_for():
    V = []
    for bid, sp in SPOTS.items():
        z = sp['z']
        V.append({'name': 'wall_' + bid, 'pos': [16, 21, z - 40], 'look': [-89, 32, z + 34], 'fov': 62, 'shadowAt': [-60, 20, z + 30], 'shadowExtent': 140,
                  'fogNear': 700, 'fogFar': 2600})
        (cx, cy, cz), (lx, ly, lz) = OUTER[bid]
        V.append({'name': 'out_' + bid, 'pos': [cx, cy, z + cz], 'look': [lx, ly, z + lz], 'fov': 64, 'shadowAt': [0, 20, z], 'shadowExtent': 260,
                  'fogNear': 1200, 'fogFar': 4200})
    V.append({'name': 'out_air1', 'pos': [0, 330, 380], 'look': [0, 30, 1500], 'fov': 62, 'shadowAt': [0, 20, 1200], 'shadowExtent': 500, 'fogNear': 1600, 'fogFar': 5200})
    V.append({'name': 'out_air2', 'pos': [0, 330, 2050], 'look': [0, 30, 3200], 'fov': 62, 'shadowAt': [0, 20, 2700], 'shadowExtent': 500, 'fogNear': 1600, 'fogFar': 5200})
    V.append({'name': 'out_hub', 'pos': [-40, 34, -205], 'look': [-10, 70, -40], 'fov': 62, 'shadowAt': [0, 20, -140], 'shadowExtent': 220, 'fogNear': 1200, 'fogFar': 4200})
    V.append({'name': 'hub_gate', 'pos': [-26, 40, -158], 'look': [-6, 63, -100], 'fov': 46, 'shadowAt': [0, 30, -110], 'shadowExtent': 130, 'fogNear': 900, 'fogFar': 2600})
    V.append({'name': 'hub_top', 'pos': [-168, 40, -146], 'look': [-236, 54, -104], 'fov': 44, 'shadowAt': [-220, 40, -110], 'shadowExtent': 90, 'fogNear': 900, 'fogFar': 2600})
    V.append({'name': 'hub_corner', 'pos': [-262, 34, -178], 'look': [-334, 53, -106], 'fov': 50, 'shadowAt': [-300, 40, -130], 'shadowExtent': 110, 'fogNear': 900, 'fogFar': 2600})
    V.append({'name': 'hub_dusk', 'pos': [-150, 34, -160], 'look': [-236, 52, -104], 'fov': 52, 'night': True, 'shadowAt': [-220, 40, -110], 'shadowExtent': 90})
    return V


def lantern_lights(parts):
    """Option C's lanterns as point lights for the dusk view (the build would give each a small PointLight)."""
    return [{'p': p['p'], 'color': [255, 196, 120], 'brightness': 1.4, 'range': 12} for p in parts if p['name'] == 'Lantern']


def cmd_scenes(world, specs_path, out):
    os.makedirs(out, exist_ok=True)
    S = load_specs(specs_path)
    B = {b['Id']: b for b in S['biomes']}
    walls = [spec_part(s) for s in S['specs']['walls']]
    back = [spec_part(s) for s in S['specs']['backdrops']]
    jobs = []
    for bid, sp in SPOTS.items():
        d = json.load(open(os.path.join(world, bid + '.json')))
        z = sp['z']
        near = [p for p in d['parts'] if overlaps(p, -400, 400, z - 260, z + 900)]
        guis = [g for g in d.get('guis', []) if z - 260 <= g['p'][2] <= z + 900]
        write(os.path.join(out, 'cur_%s.json' % bid), near, guis)
        new = restyled(near, S['restyle']) + [p for p in walls if overlaps(p, -400, 400, z - 260, z + 900)]
        write(os.path.join(out, 'new_%s.json' % bid), new, guis)
        far = [p for p in d['parts'] if overlaps(p, -2000, 2000, z - 700, z + 2400)]
        far = restyled(far, S['restyle']) + [p for p in walls + back if overlaps(p, -2000, 2000, z - 700, z + 2400)]
        write(os.path.join(out, 'out_%s.json' % bid), far, [g for g in d.get('guis', []) if z - 700 <= g['p'][2] <= z + 2400])
        air = {'desert': ',out_air1', 'lava': ',out_air2'}.get(bid, '')
        jobs += ['cur_%s=%s@wall_%s' % (bid, os.path.join(out, 'cur_%s.json' % bid), bid), 'new_%s=%s@wall_%s' % (bid, os.path.join(out, 'new_%s.json' % bid), bid),
                 'out_%s=%s@out_%s%s' % (bid, os.path.join(out, 'out_%s.json' % bid), bid, air)]
    d = json.load(open(os.path.join(world, 'hub.json')))
    hub = hidden([p for p in d['parts'] if overlaps(p, -700, 700, -700, 1400)], SIGN)
    guis = [g for g in d.get('guis', []) if 'Gate sign' not in g.get('path', '')]
    lights = d.get('lights', [])
    write(os.path.join(out, 'hub_cur.json'), hub, guis, lights)
    jobs.append('hub_cur=%s@hub_gate,hub_top,hub_corner,hub_dusk' % os.path.join(out, 'hub_cur.json'))
    for o in 'ABC':
        extra = [spec_part(s) for s in S['specs']['base' + o]]
        parts = hidden(hub, S['hide'].get('base' + o, [])) + extra
        L = lights
        write(os.path.join(out, 'hub_%s.json' % o), parts, guis, L)
        jobs.append('hub_%s=%s@hub_gate,hub_top,hub_corner%s' % (o, os.path.join(out, 'hub_%s.json' % o), ',hub_dusk' if o == 'C' else ''))
    # the first look from the hub over the gate: the Forest backdrop behind the gatehouse (with option A's tops, the calmest)
    first = restyled(hub, S['restyle']) + [p for p in walls + back if overlaps(p, -2000, 2000, -700, 900)]
    write(os.path.join(out, 'out_hub.json'), first, guis, lights)
    jobs.append('out_hub=%s@out_hub' % os.path.join(out, 'out_hub.json'))
    json.dump({'note': 'R158 views (make158.py views_for)', 'views': views_for()}, open(os.path.join(out, 'views.json'), 'w'), indent=1)
    open(os.path.join(out, 'jobs.txt'), 'w').write('\n'.join(jobs) + '\n')
    print('scenes: %d jobs in %s' % (len(jobs), out))


# ---- placement rules ----------------------------------------------------------------------------------------------------------------------
def corners(s):
    c = s['CF']
    R = [[c[3], c[4], c[5]], [c[6], c[7], c[8]], [c[9], c[10], c[11]]]
    hx, hy, hz = (v / 2 for v in s['Size'])
    out = []
    for a in (-hx, hx):
        for b in (-hy, hy):
            for d in (-hz, hz):
                out.append([c[i] + R[i][0] * a + R[i][1] * b + R[i][2] * d for i in range(3)])
    return out


def above(s, g):
    """The points that bound the part over the plane y = g (a box's corners over it and its edges' crossings; balls / cylinders / eggs: their box)."""
    P = corners(s)
    if s['Shape'] in ('Ball', 'Cylinder') or s.get('Mesh'):
        lo = [min(p[i] for p in P) for i in range(3)]
        hi = [max(p[i] for p in P) for i in range(3)]
        P = [[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
    pts = [p for p in P if p[1] >= g]
    for i in range(8):
        for j in range(i + 1, 8):
            a, b = P[i], P[j]
            if sum(1 for k in range(3) if abs(a[k] - b[k]) > 1e-9) and (a[1] - g) * (b[1] - g) < 0:
                if bin(i ^ j).count('1') != 1:
                    continue  # (only the 12 edges)
                t = (g - a[1]) / (b[1] - a[1])
                pts.append([a[k] + (b[k] - a[k]) * t for k in range(3)])
    return pts


def cmd_check(specs_path):
    """The placement rules every proposed part keeps (exits 1 on a break)."""
    S = load_specs(specs_path)
    bad = []
    IN, OUT, G = 89, 94, 3.6
    for s in S['specs']['walls']:
        P = corners(s)
        xs = [abs(p[0]) for p in P]
        ys = [p[1] for p in P]
        zs = [p[2] for p in P]
        tag = s['Group'] + '/' + s['Name']
        end = min(zs) > 5975  # the end wall's own pieces
        reach = 3.2 if min(ys) < 12 else 4.5 if min(ys) < 45 else 6  # where players run (under Y 12) / over their heads / on the wall top
        if not end and min(xs) < IN - reach:
            bad.append('%s reaches %.2f into the track (more than %.1f from the wall face at Y %.1f)' % (tag, IN - min(xs), reach, min(ys)))
        if not end and max(xs) > OUT + 1.0:
            bad.append('%s reaches past the outer face by %.2f' % (tag, max(xs) - OUT))
        if min(xs) < 89.75 and min(ys) < 5.25 and not end:
            bad.append('%s goes down to Y %.2f inside the keys\' reach (|x| < 89.75, keys up to Y 5.2)' % (tag, min(ys)))
        if min(zs) < -95.5 and max(ys) > 44:
            bad.append('%s at z %.1f meets the gatehouse (z -104.5 .. -95.5 over Y 44)' % (tag, min(zs)))
        left = min(p[0] for p in P) < 0
        if left and max(zs) > 972 and min(zs) < 1038 and min(xs) < IN - .7 and min(ys) < 30:
            bad.append('%s stands %.2f proud on the Desert walkway (z %.0f)' % (tag, IN - min(xs), min(zs)))
    for s in S['specs']['backdrops']:
        tag = s['Group'] + '/' + s['Name']
        pts = above(s, G + 0.01)
        if not pts:
            continue
        if s['Name'] == 'Outer ground':
            if min(abs(p[0]) for p in corners(s)) < OUT - 1e-6 and min(p[2] for p in corners(s)) < 5985:
                bad.append('%s comes inside the walls' % tag)
            continue
        if min(abs(p[0]) for p in pts) < 100 and min(p[2] for p in pts) < 5990:
            bad.append('%s comes within |x| %.1f (outside the walls only: >= 100, or behind the end wall)' % (tag, min(abs(p[0]) for p in pts)))
        if min(p[2] for p in pts) < -99:
            bad.append('%s reaches over the hub (z %.1f)' % (tag, min(p[2] for p in pts)))
    for o in 'ABC':
        for s in S['specs']['base' + o]:
            P = corners(s)
            if min(p[1] for p in P) < 42 or max(abs(p[0]) for p in P) > 341 or min(p[2] for p in P) < -624 or max(p[2] for p in P) > -91:
                bad.append('base %s: %s/%s leaves the wall tops' % (o, s['Group'], s['Name']))
    shadows = {k: sum(1 for s in v if s.get('Shadow') is not False) for k, v in S['specs'].items()}
    for b, n in collections.Counter(bad).most_common(40):
        print('  RULE x%d %s' % (n, b))
    print('placement rules: %d parts checked, %s; shadow casters %s' % (sum(len(v) for v in S['specs'].values()), 'PASS' if not bad else 'FAIL (%d)' % len(bad),
                                                                         ', '.join('%s %d' % kv for kv in sorted(shadows.items()))))
    return 1 if bad else 0


# ---- z-fighting ---------------------------------------------------------------------------------------------------------------------------
def cmd_zfight(world, specs_path, report=None):
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
    import zfight as Z  # noqa: E402
    S = load_specs(specs_path)
    walls = [spec_part(s) for s in S['specs']['walls']]
    back = [spec_part(s) for s in S['specs']['backdrops']]
    lines = []
    bad = 0
    tmp = os.path.join(world, '_r158_zscene.json')
    runs = [(bid, bid + '.json', walls + back, [], True) for bid in SPOTS] + [('hub ' + o, 'hub.json', [spec_part(s) for s in S['specs']['base' + o]], S['hide'].get('base' + o, []), False) for o in 'ABC']
    total_new = 0
    for label, fname, extra, hide, restyle in runs:
        d = json.load(open(os.path.join(world, fname)))
        parts = hidden(d['parts'], hide)
        if restyle:
            parts = restyled(parts, S['restyle'])
        # every part near a new one (the rest of the map cannot touch it); the camera may be anywhere: the backdrops are seen from afar
        lo = [min(box_of(p)[0][i] for p in extra) - 2 for i in range(3)]
        hi = [max(box_of(p)[1][i] for p in extra) + 2 for i in range(3)]
        near = [p for p in parts if overlaps(p, lo[0], hi[0], lo[2], hi[2])]
        play = d.get('playable', []) + [[-3000, -700, 3000, 7000]]
        json.dump({'parts': near + extra, 'playable': play}, open(tmp, 'w'))
        _, fs = Z.run(tmp)
        # ours: a pair with a new part, or with a restyled wall (its new colour / material can make an old look-alike pair visible)
        rs = tuple(ROOT + k for k in S['restyle']) if restyle else ()
        mine = [f for f in fs if '158/' in f['pathA'] or '158/' in f['pathB'] or f['pathA'] in rs or f['pathB'] in rs]
        counted = [f for f in mine if f['tier'] in Z.COUNTED and not f['same_look']]
        tight = [f for f in mine if f['tier'] == 'strict' and abs(f['offset']) < 0.1 and not f['same_look']]
        alike = [f for f in mine if f['same_look'] and f['tier'] in Z.COUNTED]
        total_new += len(extra)
        lines.append('%-10s %5d new parts with %5d map parts: counted %d, tight (< 0.1) %d, look-alike (no visible flicker) %d' % (label, len(extra), len(near), len(counted), len(tight), len(alike)))
        for f in (counted + tight)[:30]:
            lines.append('   %-8s off=%+.4f area=%.2f %s.%s <-> %s.%s at %s' % (f['tier'], f['offset'], f['area'], f['pathA'].replace(ROOT, ''), f['faceA'], f['pathB'].replace(ROOT, ''), f['faceB'], f['at']))
        bad += len(counted) + len(tight)
    os.remove(tmp)
    lines.append('R158 design z-fighting (R149 detector, R152 rules): %s' % ('PASS' if bad == 0 else 'FAIL (%d)' % bad))
    txt = '\n'.join(lines)
    print(txt)
    if report:
        open(report, 'w').write(txt + '\n')
    return 1 if bad else 0


# ---- sheets --------------------------------------------------------------------------------------------------------------------------------
def cmd_sheet(rendered, specs_path, design):
    from PIL import Image, ImageDraw, ImageFont
    S = load_specs(specs_path)
    F = '/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf'
    font = lambda n, b=False: ImageFont.truetype(F % ('-Bold' if b else ''), n)
    BG, INK, SUB, GOLD = (24, 26, 31), (238, 240, 245), (176, 182, 194), (250, 226, 150)
    NOW, NEW = (190, 84, 84), (66, 170, 110)
    W, H = 720, 405

    def img(name):
        p = os.path.join(rendered, name + '.png')
        if os.path.exists(p):
            return Image.open(p).convert('RGB').resize((W, H), Image.LANCZOS)
        im = Image.new('RGB', (W, H), (60, 30, 30))
        ImageDraw.Draw(im).text((20, 20), 'missing: ' + name, font=font(18), fill=INK)
        return im

    def tag(d, x, y, text, color):
        f = font(15, True)
        w = d.textlength(text, font=f)
        d.rounded_rectangle((x, y, x + w + 16, y + 24), 6, fill=color)
        d.text((x + 8, y + 3), text, font=f, fill=(255, 255, 255))

    def wrap(d, text, width, f):
        words, lines, cur = text.split(), [], ''
        for w in words:
            t = (cur + ' ' + w).strip()
            if d.textlength(t, font=f) <= width:
                cur = t
            else:
                lines.append(cur)
                cur = w
        if cur:
            lines.append(cur)
        return lines

    counts = collections.Counter(s['Group'].split('/')[1] for s in S['specs']['walls'])
    lite = collections.Counter(s['Group'].split('/')[1] for s in S['specs']['walls_lite'])
    bcount = collections.Counter(s['Group'].split('/')[1] for s in S['specs']['backdrops'])
    borders = sum(v for k, v in counts.items() if k.startswith('Border'))

    # track_walls.png: one row per biome, now | proposed
    head, cap, gap = 92, 62, 14
    rows = S['biomes']
    sheet = Image.new('RGB', (2 * W + 3 * gap, head + len(rows) * (H + cap + gap) + 60), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 14), 'Track walls: a wall that fits each biome (preview)', font=font(30, True), fill=GOLD)
    d.text((gap, 56), 'Left: your walls now.  Right: the new look. Drawn from your real place + the new parts (an approximate picture, not Roblox lighting).',
           font=font(17), fill=SUB)
    for i, b in enumerate(rows):
        y = head + i * (H + cap + gap)
        n = counts.get(b['Name'], 0)
        d.text((gap, y + 4), '%d. %s' % (i + 1, b['Name']), font=font(22, True), fill=INK)
        d.text((gap + 210, y + 8), '%d new parts for both walls (%d in the lite version)' % (n, lite.get(b['Name'], 0)), font=font(16), fill=SUB)
        lines = wrap(d, b['Look'], 2 * W + gap - 10, font(15))
        for k, l in enumerate(lines[:2]):
            d.text((gap, y + 30 + k * 18), l, font=font(15), fill=SUB)
        for k, (pre, label, color) in enumerate((('cur_', 'NOW', NOW), ('new_', 'NEW', NEW))):
            x = gap + k * (W + gap)
            sheet.paste(img('%s%s_wall_%s' % (pre, b['Id'], b['Id'])), (x, y + cap))
            tag(d, x + 8, y + cap + 8, label, color)
    fy = head + len(rows) * (H + cap + gap) + 4
    d.text((gap, fy), 'Walls: %d new parts in all (%d in the lite version), %d of them the 6 border towers where two biomes meet. Nothing new collides; the walls keep their size and height.' % (
        len(S['specs']['walls']), len(S['specs']['walls_lite']), borders), font=font(16), fill=SUB)
    d.text((gap, fy + 24), 'Every new part: anchored, no collision, no touch, no query (players, keepers, packs and the camera go through it).', font=font(16), fill=SUB)
    sheet.save(os.path.join(design, 'track_walls.png'), optimize=True)

    # outer_track.png: 2 columns x 4 rows (the first look from the hub + the 7 biomes)
    cells = [('out_hub_out_hub', 'From your hub: trees over the gate', 'the Forest oaks peek over the gatehouse')] + \
        [('out_%s_out_%s' % (b['Id'], b['Id']), b['Name'], None) for b in rows] + \
        [('out_desert_out_air1', 'From high up: Desert and Snow', 'the new ground outside the walls, dunes, the pyramid, snow mountains'),
         ('out_lava_out_air2', 'From high up: Lava and Crystal', 'volcanoes and lava peaks, crystal spires, purple mountains')]
    BACK = {'Forest': 'tall oaks behind both walls', 'Jungle': 'giant jungle trees, a stepped temple, a waterfall cliff', 'Desert': 'big dunes, two obelisks, a great pyramid far away',
            'Snow': 'snowy firs and big snow mountains', 'Lava': 'a volcano with a glowing top and lava streams, more lava peaks', 'Crystal': 'giant crystal spires, purple mountains',
            'Storm Peaks': 'dark peaks, lightning towers, a storm mountain behind the end wall'}
    nrow = (len(cells) + 1) // 2
    sheet = Image.new('RGB', (2 * W + 3 * gap, head + nrow * (H + cap + gap) + 60), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 14), 'Outer track: what you see over the walls (preview)', font=font(30, True), fill=GOLD)
    d.text((gap, 56), 'Big, cheap shapes far outside the walls. They never touch the track, cast no shadow and nothing can hit them.', font=font(17), fill=SUB)
    for i, (name, title, sub) in enumerate(cells):
        x = gap + (i % 2) * (W + gap)
        y = head + (i // 2) * (H + cap + gap)
        d.text((x, y + 4), title, font=font(21, True), fill=INK)
        if sub is None:
            sub = '%s (%d parts, with its ground)' % (BACK.get(title, ''), bcount.get(title, 0))
        d.text((x, y + 32), sub, font=font(15), fill=SUB)
        sheet.paste(img(name), (x, y + cap))
    fy = head + nrow * (H + cap + gap) + 4
    d.text((gap, fy), 'Outer track: %d parts for all 7 biomes (%d of them big: the ground pieces, mountains, dunes). All of it stays outside the walls (|x| 100+) and off the hub.' % (
        len(S['specs']['backdrops']), sum(1 for s in S['specs']['backdrops'] if max(s['Size']) >= 100)), font=font(16), fill=SUB)
    sheet.save(os.path.join(design, 'outer_track.png'), optimize=True)

    # base_walls.png: rows now / A / B / C, columns gate / wall top / corner
    opts = [('hub_cur', 'NOW', 'Plain merlons (what you have)', NOW, '')]
    for o in 'ABC':
        opts.append(('hub_' + o, o, S['options'][o]['Title'], NEW, '%d new parts' % len(S['specs']['base' + o])))
    cols = ['hub_gate', 'hub_top', 'hub_corner']
    w3, h3 = 560, 315
    capH = 70
    sheet = Image.new('RGB', (3 * w3 + 4 * gap, head + len(opts) * (h3 + capH + gap) + 60 + h3 + 46), BG)
    d = ImageDraw.Draw(sheet)
    d.text((gap, 14), 'Base walls: the top of your castle walls (pick A, B or C)', font=font(30, True), fill=GOLD)
    d.text((gap, 56), 'The gate (no sign, as in the hotfix; its biome keys drawn without their writing), a stretch of wall top, and a corner. Same walls, same height, same collision.',
           font=font(17), fill=SUB)
    looks = {'NOW': 'Square plaster merlons on the plain wall top: no caps, no trim.'}
    looks.update({o: S['options'][o]['Look'] for o in 'ABC'})
    for i, (pre, label, title, color, n) in enumerate(opts):
        y = head + i * (h3 + capH + gap)
        tag(d, gap, y + 8, label, color)
        tx = gap + 16 + d.textlength(label, font=font(15, True)) + 12
        d.text((tx, y + 6), title, font=font(21, True), fill=INK)
        if n:
            d.text((tx + d.textlength(title, font=font(21, True)) + 16, y + 11), n, font=font(16), fill=SUB)
        d.text((gap, y + 38), looks[label], font=font(15), fill=SUB)
        for k, c in enumerate(cols):
            p = os.path.join(rendered, '%s_%s.png' % (pre, c))
            im = Image.open(p).convert('RGB').resize((w3, h3), Image.LANCZOS) if os.path.exists(p) else Image.new('RGB', (w3, h3), (60, 30, 30))
            sheet.paste(im, (gap + k * (w3 + gap), y + capH))
    y = head + len(opts) * (h3 + capH + gap)
    d.text((gap, y + 8), 'At night (the track refresh): NOW and C, where the lanterns glow (picture made brighter so you can see it)', font=font(21, True), fill=INK)
    for k, pre in enumerate(['hub_cur', 'hub_C']):
        p = os.path.join(rendered, '%s_hub_dusk.png' % pre)
        im = Image.open(p).convert('RGB').resize((w3, h3), Image.LANCZOS) if os.path.exists(p) else Image.new('RGB', (w3, h3), (60, 30, 30))
        im = im.point(lambda v: min(255, int(255 * (v / 255) ** 0.55)))
        sheet.paste(im, (gap + k * (w3 + gap), y + 46))
    x3 = gap + 2 * (w3 + gap)
    for k, line in enumerate(['The lanterns are Neon: they glow by', 'themselves, with no real lights and', 'no scripts (nothing costs per frame).', '', 'The game is always day, except the', 'track refresh night and cloudy weather.']):
        d.text((x3 + 10, y + 60 + k * 26), line, font=font(17), fill=SUB)
    sheet.save(os.path.join(design, 'base_walls.png'), optimize=True)
    print('wrote track_walls.png, outer_track.png, base_walls.png in', design)


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'html':
        cmd_html(*sys.argv[2:4])
    elif cmd == 'scenes':
        cmd_scenes(*sys.argv[2:5])
    elif cmd == 'zfight':
        sys.exit(cmd_zfight(*sys.argv[2:5]))
    elif cmd == 'sheet':
        cmd_sheet(*sys.argv[2:5])
    elif cmd == 'check':
        sys.exit(cmd_check(sys.argv[2]))
    else:
        sys.exit(__doc__)
