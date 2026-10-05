"""R151 preview (R152: the pedestal, the showcase item and the dancing giant): turns the two hub scenes (tests/build_hub_scenes.sh: scene_empty.json, scene_champions.json, the HUBTEXT lines of the
.steps files, place_geom.json) into the file render_hub.mjs draws: one JSON per state with the parts of the hub (blocks, wedges, balls, cylinders), the two plaques' and labels' words and
layout, the camera views and the labels of the plan view.
Usage: python3 hub_scenes.py <scene dir> <out scenes.json>
The views: the wide shots are from a player's spawn (the base's own, about 170 studs away), the close-ups 85 studs in front of a display, the detail shots 50 studs in front and to the avatar's
side, the scale shots 60 studs in front with a normal 5.3 stud avatar standing 30 studs from the stand (to show how big it is), the banner from the market and the plan from above.
Part shapes follow Roblox (a Wedge's slope falls to the front, a Cylinder's axis is X, a SpecialMesh Sphere is an ellipsoid of part size x scale). The avatar is the mock's R15-shaped stand-in
(blocks, one frame of a dance put in by hand; the head a ball): the real one is the player's own, loaded in Studio, and dances on its Animator."""
import json, math, sys, os

d = sys.argv[1]
out = sys.argv[2]
SKIP_Z = -92.0   # parts south of this are the track, not the hub
MAT = {'SmoothPlastic': 'P', 'Plastic': 'P', 'Neon': 'N', 'Slate': 'S', 'Basalt': 'B', 'Cobblestone': 'C', 'Sandstone': 'D', 'Wood': 'W', 'WoodPlanks': 'W', 'Metal': 'M', 'Marble': 'R',
       'Ice': 'I', 'Glass': 'G', 'Grass': 'A', 'Ground': 'A', 'Sand': 'D', 'Snow': 'P', 'Concrete': 'S'}


def load(name):
    return json.load(open(os.path.join(d, name), encoding='utf-8'))


def texts(steps):
    res = {}
    for line in open(os.path.join(d, steps), encoding='utf-8'):
        if line.startswith('HUBTEXT '):
            s = json.loads(line[len('HUBTEXT '):])
            res[s['kind']] = s
    return res


def r4(v, k=3):
    return round(v, k)


def compact(p):
    path = p['path']
    shape = p['shape']
    s = list(p['size'])
    mesh = p.get('mesh')
    g = None
    if mesh and mesh.get('type') == 'Sphere':
        shape = 'Ball'
        sc = mesh['scale']
        s = [s[0] * sc[0], s[1] * sc[1], s[2] * sc[2]]
    elif shape == 'Mesh':
        shape = 'Block'
    if '/Avatar/' in path:
        g = 'av'
        if p['name'] == 'Head':
            shape = 'Ball'
        if p['name'] == 'Handle':
            return None  # (the mock's hats are cubes: not drawn)
    elif '/Item/' in path:
        g = 'item'
    if 'HubDisplays151' in path:
        g = g or 'hub'
    code = {'Block': 'K', 'Wedge': 'W', 'CornerWedge': 'V', 'Cylinder': 'Y', 'Ball': 'O'}.get(shape, 'K')
    r = p['r']
    row = {'k': code, 's': [r4(x, 3) for x in s], 'p': [r4(x, 3) for x in p['p']], 'r': [r4(r[i][j], 4) for i in range(3) for j in range(3)], 'c': p['color'],
           'm': MAT.get(p['material'], 'P')}
    if p['t'] > 0:
        row['t'] = r4(p['t'], 3)
    if g:
        row['g'] = g
    if p.get('name') == 'Head' and g == 'av':
        row['face'] = 1
    return row


def view(name, cam, at, fov, w, h, **kw):
    v = {'name': name, 'cam': [r4(x, 2) for x in cam], 'at': [r4(x, 2) for x in at], 'fov': fov, 'w': w, 'h': h}
    v.update(kw)
    return v


def reference_figure(x, z, face):
    """A normal player, 5.3 studs tall (the R15 default), as blocks: for the 'scale' views only. face = the direction (x, z) it looks toward."""
    fx, fz = face
    n = math.hypot(fx, fz)
    fx, fz = fx / n, fz / n
    # local axes: look = (fx, fz) (the figure's front = its -Z), right = look x up
    rx, rz = -fz, fx
    # a Roblox CFrame faces -Z: its Z column is minus the look vector; X column = right = (look x up)
    rot = [rx, 0, -fx, 0, 1, 0, rz, 0, -fz]
    parts = []

    def block(shape, size, off, color):
        px = x + rx * off[0]
        pz = z + rz * off[0]
        parts.append({'k': shape, 's': size, 'p': [r4(px), r4(4 + off[1]), r4(pz)], 'r': rot, 'c': color, 'm': 'P', 'g': 'ref'})
    skin, shirt, pants = [245, 205, 48], [13, 105, 172], [75, 151, 75]
    block('K', [1, 2, 1], (-.5, 1, 0), pants)
    block('K', [1, 2, 1], (.5, 1, 0), pants)
    block('K', [2, 2, 1], (0, 3, 0), shirt)
    block('O', [1.2, 1.2, 1.2], (0, 4.6, 0), skin)
    block('K', [1, 2, 1], (-1.5, 3, 0), skin)
    block('K', [1, 2, 1], (1.5, 3, 0), skin)
    parts[3]['face'] = 1
    return parts


def main():
    geom = load('place_geom.json')['parts']
    spawns = {}
    for p in geom:
        if p['path'].endswith('/Spawn') and '/Bases/' in p['path']:
            spawns[p['path'].split('/')[-2]] = p['p']
    states = {}
    for state in ('empty', 'champions'):
        scene = load('scene_%s.json' % state)
        tx = texts('%s.steps' % state)
        parts = []
        for p in scene['parts']:
            if p['t'] >= .995 or p['p'][2] > SKIP_Z:
                continue
            row = compact(p)
            if row:
                parts.append(row)
        frames = {}
        for kind in ('Pull', 'Fruit'):
            t = tx[kind]
            o, lk = t['origin'], t['look']
            f = (lk[0], lk[2])                       # the display's front, x / z (toward the market)
            r = t['plaque']['r']
            left = (r[0], r[6])                      # local +X = the viewer's left, x / z
            frames[kind] = {'center': [o[0], o[1], o[2]], 'front': list(f), 'left': list(left), 'item': t['item']}
        views = []
        for kind, base in (('Pull', 'Base_4'), ('Fruit', 'Base_3')):
            fr = frames[kind]
            c, f, left = fr['center'], fr['front'], fr['left']
            sp = spawns[base]
            low = kind.lower()
            views.append(view(low + '_wide', (sp[0], sp[1] + 6.5, sp[2]), (c[0], 19, c[2]), 40, 900, 520))
            views.append(view(low + '_close', (c[0] + f[0] * 85, 13, c[2] + f[1] * 85), (c[0], 19, c[2]), 50, 900, 520))
            # the detail: in front and to the viewer's right (local -X, where the avatar stands), a 3/4 view of the pedestal, the plaque and the avatar
            views.append(view(low + '_detail', (c[0] + f[0] * 50 - left[0] * 26, 9, c[2] + f[1] * 50 - left[1] * 26), (c[0], 17, c[2]), 52, 900, 520))
            # the scale: a normal player 30 studs in front of the stand, to the avatar's side
            views.append(view(low + '_scale', (c[0] + f[0] * 62 + left[0] * 4, 8.5, c[2] + f[1] * 62 + left[1] * 4), (c[0], 16, c[2]), 52, 900, 520, ref=True))
        views.append(view('banner', (0, 48, -235), (0, 10, -520), 50, 1800, 620))
        labels = [{'p': [frames['Pull']['center'][0], 44, frames['Pull']['center'][2]], 'text': 'BEST PULL TODAY'}, {'p': [frames['Fruit']['center'][0], 44, frames['Fruit']['center'][2]], 'text': 'BIGGEST FRUIT TODAY'},
                  {'p': [0, 6, -265], 'text': 'Market'}, {'p': [0, 6, -330], 'text': 'Verity'}]
        for k, v in sorted(spawns.items()):
            labels.append({'p': [v[0], 6, v[2]], 'text': k.replace('_', ' ')})
        plan = view('plan', (0, 980, -361), (0, 4, -361), 33, 1000, 800, plan=True, up=[0, 0, -1])
        plan['labels'] = labels
        views.append(plan)
        for kind in ('Pull', 'Fruit'):   # the reference players (drawn only in the 'scale' views)
            fr = frames[kind]
            c, f, left = fr['center'], fr['front'], fr['left']
            parts.extend(reference_figure(c[0] + f[0] * 32 - left[0] * 2, c[2] + f[1] * 32 - left[1] * 2, (f[0], f[1])))    # (facing the camera, away from the stand)
        states[state] = {'parts': parts, 'texts': [tx['Pull'], tx['Fruit']], 'views': views, 'frames': frames}
        print('%s: %d parts, %d views' % (state, len(parts), len(views)))
    json.dump(states, open(out, 'w'), separators=(',', ':'))
    print('wrote', out)


main()
