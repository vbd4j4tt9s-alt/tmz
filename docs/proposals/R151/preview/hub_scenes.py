"""R151 preview: turns the two hub scenes (tests/build_hub_scenes.sh: scene_empty.json, scene_champions.json, the HUBSIGN lines of the .steps files, place_geom.json) into the
file render_hub.mjs draws: one JSON per state with the parts of the hub (blocks, wedges, balls, cylinders), the two signs' words and layout, the camera views and the labels
of the plan view.
Usage: python3 hub_scenes.py <scene dir> <out scenes.json>
The views: the wide shots are from a player's spawn (the base's own, 170 studs away), the close-ups 60 studs in front of a display (eye 14), the detail shots 40 studs in front,
the banner from the market and the plan from above. Part shapes follow Roblox (a Wedge's slope falls to the front, a Cylinder's axis is X, a SpecialMesh Sphere is an ellipsoid
of part size x scale). The avatar is the mock's R15-shaped stand-in (blocks, posed by HubAvatarPose.Static; the head a ball): the real one is the player's own, loaded in Studio."""
import json, math, sys, os

d = sys.argv[1]
out = sys.argv[2]
SKIP_Z = -92.0   # parts south of this are the track, not the hub
MAT = {'SmoothPlastic': 'P', 'Plastic': 'P', 'Neon': 'N', 'Slate': 'S', 'Basalt': 'B', 'Cobblestone': 'C', 'Sandstone': 'D', 'Wood': 'W', 'WoodPlanks': 'W', 'Metal': 'M', 'Marble': 'R',
       'Ice': 'I', 'Glass': 'G', 'Grass': 'A', 'Ground': 'A', 'Sand': 'D', 'Snow': 'P', 'Concrete': 'S'}


def load(name):
    return json.load(open(os.path.join(d, name), encoding='utf-8'))


def signs(steps):
    res = {}
    for line in open(os.path.join(d, steps), encoding='utf-8'):
        if line.startswith('HUBSIGN '):
            s = json.loads(line[len('HUBSIGN '):])
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
    elif p['name'] == 'Halo' and 'HubDisplays151' in path:
        g = 'halo'
    elif p['name'] == 'Sign board' and 'HubDisplays151' in path:
        g = 'board'
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


def display_frame(sign):
    r = sign['board']['r']
    front = (-r[2], -r[5], -r[8])          # the board's front (local -Z) in world, x / y / z
    n = math.hypot(front[0], front[2])
    f = (front[0] / n, front[2] / n)
    b = sign['board']['p']
    center = (b[0] + f[0] * 11.5, 4.0, b[2] + f[1] * 11.5)
    left = (r[0], r[6])                    # local +X (the viewer's left), x / z
    return center, f, left


def main():
    geom = load('place_geom.json')['parts']
    spawns = {}
    for p in geom:
        if p['path'].endswith('/Spawn') and '/Bases/' in p['path']:
            spawns[p['path'].split('/')[-2]] = p['p']
    states = {}
    for state in ('empty', 'champions'):
        scene = load('scene_%s.json' % state)
        sg = signs('%s.steps' % state)
        parts = []
        for p in scene['parts']:
            if p['t'] >= .995 or p['p'][2] > SKIP_Z:
                continue
            row = compact(p)
            if row:
                parts.append(row)
        centers = {}
        for kind in ('Pull', 'Fruit'):
            centers[kind] = display_frame(sg[kind])
        views = []
        for kind, base in (('Pull', 'Base_4'), ('Fruit', 'Base_3')):
            c, f, left = centers[kind]
            sp = spawns[base]
            low = kind.lower()
            views.append(view(low + '_wide', (sp[0], sp[1] + 6.5, sp[2]), (c[0], 24, c[2]), 46, 900, 520))
            views.append(view(low + '_close', (c[0] + f[0] * 58, 14, c[2] + f[1] * 58), (c[0], 24, c[2]), 48, 900, 520))
            # the detail: in front and a little to the viewer's right, where the avatar stands (local -X is the viewer's right)
            views.append(view(low + '_detail', (c[0] + f[0] * 40 - left[0] * 16, 9, c[2] + f[1] * 40 - left[1] * 16), (c[0], 13.5, c[2]), 40, 900, 520))
        views.append(view('banner', (0, 48, -235), (0, 10, -520), 50, 1800, 620))
        labels = [{'p': [centers['Pull'][0][0], 52, centers['Pull'][0][2]], 'text': 'BEST PULL TODAY'}, {'p': [centers['Fruit'][0][0], 52, centers['Fruit'][0][2]], 'text': 'BIGGEST FRUIT TODAY'},
                  {'p': [0, 6, -265], 'text': 'Market'}, {'p': [0, 6, -330], 'text': 'Verity'}]
        for k, v in sorted(spawns.items()):
            labels.append({'p': [v[0], 6, v[2]], 'text': k.replace('_', ' ')})
        plan = view('plan', (0, 980, -361), (0, 4, -361), 33, 1000, 800, plan=True, up=[0, 0, -1])
        plan['labels'] = labels
        views.append(plan)
        states[state] = {'parts': parts, 'signs': [sg['Pull'], sg['Fruit']], 'views': views,
                         'frames': {k: {'center': list(centers[k][0]), 'front': list(centers[k][1])} for k in centers}}
        print('%s: %d parts, %d views' % (state, len(parts), len(views)))
    json.dump(states, open(out, 'w'), separators=(',', ':'))
    print('wrote', out)


main()
