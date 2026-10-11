"""R152 preview: turns the two giveaway scenes (make_giveaway_scene.py: scene_open.json / scene_empty.json = every part of the finished hub in the zfight.py format, and gscene_open.json /
gscene_empty.json = the emitters, lights and the number's BillboardGui of what the client made) into the file render_giveaway.mjs draws: per state the hub's parts (blocks, wedges,
balls, cylinders; the pack's stand-in Body as a pouch), the lights, the emitters, the sign, and the camera views.
Usage: python3 giveaway_scenes.py <scene dir> <out scenes.json>
Views (the plaza centre is X 0 / Z -392, the plaza top y 4.26; the market is north, Verity's dais between): a wide aerial view of the hub's middle, the view of a player coming from the
market, the close-up of the pedestal with the number, the stone close-up (column lettering, pylons), the same close-up at dusk (the violet glow), the plan."""
import json, math, os, sys

d = sys.argv[1]
out = sys.argv[2]
SKIP_Z = -92.0   # parts north of this are the track, not the hub
MAT = {'SmoothPlastic': 'P', 'Plastic': 'P', 'Neon': 'N', 'Slate': 'S', 'Basalt': 'B', 'Cobblestone': 'C', 'Sandstone': 'D', 'Wood': 'W', 'WoodPlanks': 'W', 'Metal': 'M', 'Marble': 'R',
       'Ice': 'I', 'Glass': 'G', 'Grass': 'A', 'Ground': 'A', 'Sand': 'D', 'Snow': 'P', 'Concrete': 'S', 'Brick': 'C', 'Plaster': 'P', 'Fabric': 'P'}
CX, CZ = 0.0, -392.0


def load(name):
    return json.load(open(os.path.join(d, name), encoding='utf-8'))


def r4(v, k=3):
    return round(v, k)


def compact(p):
    shape = p['shape']
    s = list(p['size'])
    path = p['path']
    g = None
    if 'VoidGiveawayPacks152' in path:
        g = 'pack'
    elif '_VoidPackFx122' in path:
        g = 'pack'
    elif 'VoidGiveaway152' in path:
        g = 'giveaway'
    mesh = p.get('mesh')
    if mesh and mesh.get('type') == 'Sphere':
        shape = 'Ball'
        sc = mesh['scale']
        s = [s[0] * sc[0], s[1] * sc[1], s[2] * sc[2]]
    code = {'Block': 'K', 'Wedge': 'W', 'CornerWedge': 'V', 'Cylinder': 'Y', 'Ball': 'O'}.get(shape, 'K')
    if shape == 'Mesh' and g == 'pack' and p['name'] == 'Body':
        code = 'P'
    elif shape == 'Mesh':
        code = 'K'
    r = p['r']
    row = {'k': code, 's': [r4(x, 3) for x in s], 'p': [r4(x, 3) for x in p['p']], 'r': [r4(r[i][j], 4) for i in range(3) for j in range(3)], 'c': p['color'],
           'm': MAT.get(p['material'], 'P')}
    if p['t'] > 0:
        row['t'] = r4(p['t'], 3)
    if g:
        row['g'] = g
    return row


def view(name, cam, at, fov, w, h, **kw):
    v = {'name': name, 'cam': [r4(x, 2) for x in cam], 'at': [r4(x, 2) for x in at], 'fov': fov, 'w': w, 'h': h}
    v.update(kw)
    return v


def main():
    states = {}
    for state in ('open', 'empty'):
        scene = load('scene_%s.json' % state)
        extra = load('gscene_%s.json' % state)
        plaques = [json.loads(l) for l in open(os.path.join(d, 'gplaque_%s.jsonl' % state), encoding='utf-8') if l.strip()]
        parts = []
        for p in scene['parts']:
            if p['t'] >= .995 or p['p'][2] > SKIP_Z:
                continue
            if p['name'] in ('VoidFxCore',):
                continue
            row = compact(p)
            if row:
                parts.append(row)
        mine = [p for p in parts if p.get('g') in ('giveaway', 'pack')]
        views = [
            view('hub_wide', (96, 62, -322), (0, 14, -392), 52, 1800, 760),
            view('plaza', (40, 9.5, -330), (0, 17, -392), 56, 900, 640),
            view('close', (0, 9.3, -358), (0, 17.5, -392), 56, 900, 640),
            view('stone', (14, 7.4, -372), (0, 11.5, -392), 52, 900, 640),
            view('dusk', (0, 9.3, -358), (0, 17.5, -392), 56, 900, 640, dusk=True),
            view('plan', (0, 520, -392), (0, 4, -392), 14, 760, 760, plan=True, up=[0, 0, -1]),
        ]
        if state == 'empty':
            views = [v for v in views if v['name'] == 'close']
        states[state] = {'parts': parts, 'emitters': extra['emitters'], 'lights': extra['lights'], 'guis': extra['guis'], 'plaques': plaques, 'views': views}
        print('%s: %d parts (%d of the giveaway), %d emitters, %d lights, %d signs' % (state, len(parts), len(mine), len(extra['emitters']), len(extra['lights']), len(extra['guis'])))
    json.dump(states, open(out, 'w'), separators=(',', ':'))
    print('wrote', out)


main()
