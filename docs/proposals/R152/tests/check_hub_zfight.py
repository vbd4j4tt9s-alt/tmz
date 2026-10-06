"""R152 hub decor: z-fighting check of the finished hub (the real HubDecor151 + HubLife151 client, see ../preview/run_hub_scenes.sh) with the R149
detector (docs/proposals/R149/tools/zfight.py, all tiers).
Usage: python3 check_hub_zfight.py <before scene.json> <after scene.json> [--tight 0.1] [--list N] [--json out.json]
For each scene it prints the findings that involve a part of the hub decor (Workspace/ChestChaseMap/HubDecor151/..., the client's HubLife151/...) or
one of the saved hub walls / caps / piers / floor the decor sits on:
  counted   coplanar / near / far (the depth-buffer rule: |offset| < 4 steps of a 24-bit buffer at the distance the overlap is seen from, 0.02 - 0.043):
            two visible faces of different parts that point the same way, overlap, and look different. Must be ZERO with a decor part.
  tight     (R152 owner request "fix any signs of z fighting") the 'strict' tier (offset 0.043 .. 0.6 where the rule of thumb 0.002 x distance is not
            met) restricted to |offset| < --tight (default 0.1): a flicker that only older phones at long range could still show.
            Must be ZERO between two decor parts or a decor part and a saved wall / cap.
Exits 1 when a counted finding has a decor part, or a tight finding is between decor parts or a decor part and a saved wall, except the paving's
designed flat layers (DESIGNED below: 0.05 - 0.06 stud steps between the hub's own streets, plazas, curbs and grass patches, over the 0.043 the
depth-buffer rule asks for at 300 studs; HubSnow151.Keep lists their planes). The lobby floor is told apart: decor lies 0.06 - 0.32 over it by
design, a 0.2 stud lift is invisible but 0.002 x 300 asks for 0.6.
"""
import argparse, collections, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

MARKS = ('/HubDecor151/', 'HubLife151/', '/HubTrampolines153/')  # (R153: the trampolines in the garden nooks)
SAVED = ('ChestChaseWalls/', 'GardenHubDesign/')
DESIGNED = (('Grass patch', 'Grass patch'), ('Stage circle', 'Market square'), ('South street', 'South plaza'), ('Garden walk', 'Garden nook'),
            ('Back lane', 'Lane nook'), ('Corner circle', 'Curb'))


def ours(f):
    return any(m in f['pathA'] or m in f['pathB'] for m in MARKS)


def both_ours(f):
    return all(any(m in f[k] for m in MARKS) for k in ('pathA', 'pathB'))


def saved(f):
    return any(k in f['pathA'] or k in f['pathB'] for k in SAVED)


def designed(f):
    a, b = f['pathA'].rsplit('/', 1)[-1], f['pathB'].rsplit('/', 1)[-1]
    return any((a.startswith(x) and b.startswith(y)) or (a.startswith(y) and b.startswith(x)) for x, y in DESIGNED)


def short(p):
    p = p.replace('Workspace/ChestChaseMap/', '').replace('Workspace/', '')
    parts = p.split('/')
    return parts[0] + '/' + parts[-1] if len(parts) > 2 else p


def group(fs):
    g = collections.OrderedDict()
    for f in fs:
        k = (f['tier'], short(f['pathA']) + '.' + f['faceA'], short(f['pathB']) + '.' + f['faceB'])
        g.setdefault(k, []).append(f)
    return g


def analyse(path, tight):
    parts, fs = Z.run(path)
    vis = [f for f in fs if not f['same_look']]
    mine = [f for f in vis if ours(f)]
    counted = [f for f in mine if f['tier'] in Z.COUNTED]
    strict = [f for f in mine if f['tier'] == 'strict']
    tight_all = [f for f in strict if abs(f['offset']) < tight]
    tight_bad = [f for f in tight_all if (both_ours(f) or saved(f)) and not designed(f)]
    steps = [f for f in tight_all if (both_ours(f) or saved(f)) and designed(f)]
    return parts, vis, mine, counted, strict, tight_all, tight_bad, steps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('before'); ap.add_argument('after')
    ap.add_argument('--tight', type=float, default=0.1)
    ap.add_argument('--list', type=int, default=25)
    ap.add_argument('--json')
    a = ap.parse_args()
    out = {}
    bad = 0
    for label, path in (('BEFORE', a.before), ('AFTER', a.after)):
        parts, vis, mine, counted, strict, tight_all, tight_bad, steps = analyse(path, a.tight)
        n_decor = sum(1 for p in parts if any(m in p.path for m in MARKS))
        print('%s %s: %d parts (%d decor), %d visible findings on the whole map; with a decor part: counted %d, strict %d (tight < %.2f: %d, of which decor<->decor or decor<->saved wall: %d + %d designed paving steps)'
              % (label, os.path.basename(path), len(parts), n_decor, len(vis), len(counted), len(strict), a.tight, len(tight_all), len(tight_bad), len(steps)))
        out[label] = {'parts': len(parts), 'decor': n_decor, 'counted': len(counted), 'strict': len(strict), 'tight': len(tight_all), 'tight_bad': len(tight_bad), 'designed_steps': len(steps)}
        for title, lst in (('counted', counted), ('tight (decor <-> decor / saved wall)', tight_bad)):
            for k, v in list(group(lst).items())[:a.list]:
                f = v[0]
                print('   %-9s x%-3d off=%+.4f area=%6.2f %s <-> %s at %s' % (k[0], len(v), f['offset'], f['area'], k[1], k[2], f['at']))
        if label == 'AFTER':
            bad = len(counted) + len(tight_bad)
    if a.json:
        json.dump(out, open(a.json, 'w'), indent=1)
    print('R152 hub z-fighting: %s' % ('NONE' if bad == 0 else '%d findings' % bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
