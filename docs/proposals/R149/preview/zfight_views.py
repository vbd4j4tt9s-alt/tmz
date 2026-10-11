"""R149 z-fighting preview data: the parts around each close-up view and the flagged overlaps, before and after.
Usage: python3 zfight_views.py <before scene.json> <after scene.json> <out views.json>
Overlaps are the detector's counted findings (tools/zfight.py: coplanar / near / far): 'ours' (fixed in R149) in magenta, the ones
left for other files (fruit / plant art, the keyboard, meshes; see tests/check_zfight.py) in orange."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
sys.path.insert(0, os.path.join(HERE, '..', 'tests'))
import zfight as Z  # noqa: E402
from check_zfight import owner  # noqa: E402

C = (0, 4, -269.275)  # the market's centre (MarketLayout.Center)


def at(dx, dy, dz):
    return [C[0] + dx, C[1] + dy, C[2] + dz]


VIEWS = [
    {'name': 'Roof courses and front gable', 'cam': at(-26, 34, -62), 'at': at(-4, 22, -12), 'fov': 34, 'r': 46},
    {'name': 'Porch awning stripes, from above', 'cam': at(-6, 19.5, -31), 'at': at(-1, 12.6, -18.5), 'fov': 40, 'r': 14},
    {'name': 'Produce stand steps', 'cam': at(-15, 8.5, -33), 'at': at(-23, 4.6, -21.5), 'fov': 38, 'r': 16},
    {'name': 'Counter crates', 'cam': at(3, 9.5, -8), 'at': at(0, 5.3, 2.5), 'fov': 42, 'r': 16},
    {'name': 'Side door, window frames', 'cam': at(-32, 14, -12), 'at': at(-19.8, 13.5, 1), 'fov': 42, 'r': 28},
    {'name': 'Back gable boards over the back wall', 'cam': at(10, 21, 42), 'at': at(0, 19, 15.6), 'fov': 36, 'r': 18},
]


def compact(p):
    r = p['r']
    if len(r) == 3:
        r = [c for row in r for c in row]
    d = {'s': p['size'], 'p': p['p'], 'r': r, 'c': p['color'], 'sh': p['shape'], 'm': p['material'], 't': p['t']}
    if p.get('mesh'):
        d['mesh'] = p['mesh']['type']
    return d


def pack(scene_path):
    parts, fs = Z.run(scene_path)
    raw = json.load(open(scene_path))['parts']
    out = []
    for v in VIEWS:
        c = v['at']; r2 = v['r'] ** 2
        cam = v['cam']
        sel = [compact(p) for p in raw if (p['p'][0] - c[0]) ** 2 + (p['p'][1] - c[1]) ** 2 + (p['p'][2] - c[2]) ** 2 <= r2
               and p['t'] < 0.98 and 'KeyboardTrackVisuals' not in p['path']]
        polys = []
        for f in fs:
            if f['tier'] not in Z.COUNTED or f['same_look'] or 'poly' not in f:
                continue
            q = f['at']
            if (q[0] - c[0]) ** 2 + (q[1] - c[1]) ** 2 + (q[2] - c[2]) ** 2 > r2:
                continue
            # lift the overlay a hair toward the camera so it draws on top of the face it marks
            polys.append({'pts': f['poly'], 'n': f['normal'], 'kind': 'theirs' if owner(f) else 'ours', 'what': '%s.%s / %s.%s' % (
                f['pathA'].rsplit('/', 1)[-1], f['faceA'], f['pathB'].rsplit('/', 1)[-1], f['faceB'])})
        out.append({'parts': sel, 'polys': polys})
    return out


def main():
    before, after, dest = sys.argv[1:4]
    b, a = pack(before), pack(after)
    views = []
    for v, vb, va in zip(VIEWS, b, a):
        views.append(dict(v, before=vb, after=va))
        print('%-32s before %3d flagged (%d ours)   after %3d flagged (%d ours)' % (v['name'], len(vb['polys']), sum(1 for p in vb['polys'] if p['kind'] == 'ours'),
              len(va['polys']), sum(1 for p in va['polys'] if p['kind'] == 'ours')))
    json.dump({'views': views}, open(dest, 'w'), separators=(',', ':'))


if __name__ == '__main__':
    main()
