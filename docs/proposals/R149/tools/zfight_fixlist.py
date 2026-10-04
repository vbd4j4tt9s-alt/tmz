"""R149: build ZFightFix149's data (the place parts the installer cannot edit) from a z-fighting scene of the live map.

Usage: python3 zfight_fixlist.py <scene.json> [--write src/ServerScriptService/ChestChaseServer/ZFightFix149.lua]

The scene comes from zfight_scene.luau run WITHOUT the fixer (the R148 map as the server builds it). Every counted finding
(coplanar / near / far, not look-alike, not a mesh) between two PLACE parts (parts the scene loaded from the place file; they
carry their saved CFrame / Size) gets one nudge: the part with the smaller face moves along the shared normal, out or in, by
0.04 (then 0.06) studs, in its own frame (so the map's rigid start-up moves keep it right). A nudge is kept only when, in the
scene, it clears that pair and gives the moved part no new finding. Prints what it chose; with --write it rewrites the data
block of ZFightFix149.lua (between the BEGIN / END DATA markers)."""
import json, math, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import zfight as Z  # noqa: E402

COUNTED = ('coplanar', 'near', 'far')


def counted(f):
    return f['tier'] in COUNTED and not f['same_look'] and not f['mesh']


def face_area(p, face):
    hx, hy, hz = p.size
    return {'Right': hy * hz, 'Left': hy * hz, 'Top': hx * hz, 'Bottom': hx * hz, 'Back': hx * hy, 'Front': hx * hy}.get(face, hx * hy * hz)


def neighbours(parts, p, pad=1.0):
    """Parts near p, plus everything under or over it (the visibility test looks for the floor below a downward face)."""
    return [q for q in parts if q.lo[0] <= p.hi[0] + pad and q.hi[0] >= p.lo[0] - pad and q.lo[2] <= p.hi[2] + pad and q.hi[2] >= p.lo[2] - pad]


def moved(p, d):
    """A copy of part p shifted by world vector d."""
    src = dict(p.src)
    src['p'] = [p.src['p'][k] + d[k] for k in range(3)]
    return Z.Part(p.i, src)


def local_findings(parts, p, extra_pad=1.0):
    near = neighbours(parts, p, extra_pad)
    fs = Z.detect(near)
    return [f for f in fs if counted(f) and (f['a'] == p.i or f['b'] == p.i)]


def main():
    scene = sys.argv[1]
    parts, fs = Z.run(scene)
    byi = {p.i: p for p in parts}
    todo = [f for f in fs if counted(f) and byi[f['a']].src.get('saved') and byi[f['b']].src.get('saved')]
    print('%d counted findings between place parts' % len(todo))
    chosen = {}
    for f in todo:
        a, b = byi[f['a']], byi[f['b']]
        if a.i in chosen or b.i in chosen:
            continue
        order = sorted([(a, f['faceA']), (b, f['faceB'])], key=lambda t: face_area(t[0], t[1]))
        n = f['normal']
        done = False
        for mover, face in order:
            for delta in (0.04, -0.04, 0.06, -0.06):
                d = [n[k] * delta for k in range(3)]
                trial = moved(mover, d)
                trial_parts = [trial if q.i == mover.i else q for q in parts]
                left = local_findings(trial_parts, trial)
                if not left:
                    r = mover.cols  # right, up, back in world
                    local = [sum(d[k] * r[c][k] for k in range(3)) for c in range(3)]
                    chosen[mover.i] = {'part': mover, 'move': local, 'why': '%s with %s.%s (%s, offset %.4f)' % (
                        face, (b if mover is a else a).name, f['faceB'] if mover is a else f['faceA'], f['tier'], f['offset'])}
                    parts = trial_parts
                    done = True
                    break
            if done:
                break
        if not done:
            print('NO SAFE NUDGE for', f['pathA'], f['faceA'], '<->', f['pathB'], f['faceB'])
    entries = []
    for i, c in sorted(chosen.items(), key=lambda t: t[1]['part'].path):
        p = c['part']
        path = p.path.replace('Workspace/ChestChaseMap/', '')
        parent, name = path.rsplit('/', 1)
        sv = p.src['saved']
        entries.append((parent, name, sv['cf'], sv['s'], c['move'], c['why']))
        print('  %-90s move %s   (%s)' % (path, ['%.3f' % v for v in c['move']], c['why']))
    if '--write' in sys.argv:
        target = sys.argv[sys.argv.index('--write') + 1]
        src = open(target, encoding='utf-8').read()
        a = src.index('-- BEGIN DATA'); b = src.index('-- END DATA')
        lines = ['-- BEGIN DATA (written by docs/proposals/R149/tools/zfight_fixlist.py from the z-fighting scene of the R148 map)', 'F.Fixes={']
        for parent, name, cf, s, mv, why in entries:
            lines.append(' {Path=%s,Name=%s,CFrame={%s},Size={%s},Move={%s}}, -- %s' % (
                json.dumps(parent), json.dumps(name), ','.join('%.6g' % v for v in cf), ','.join('%.6g' % v for v in s),
                ','.join('%.4g' % (0 if abs(v) < 1e-9 else v) for v in mv), why.replace('\n', ' ')))
        lines.append('}')
        src = src[:a] + '\n'.join(lines) + '\n' + src[b:]
        open(target, 'w', encoding='utf-8').write(src)
        print('wrote', len(entries), 'fixes into', target)


if __name__ == '__main__':
    main()
