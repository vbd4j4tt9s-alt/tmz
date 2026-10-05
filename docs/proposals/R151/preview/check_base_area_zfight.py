"""R151 base area: z-fighting check of the redesign scene with the R149 detector (docs/proposals/R149/tools/zfight.py, the same rules
run_zfight.sh uses: coplanar / near / far tiers counted, look-alike pairs and hidden overlaps not counted).
Usage: python3 check_base_area_zfight.py <before scene.json> <after scene.json> [<more after scenes> ...]
Prints, per scene, the counted findings that involve an R151 part (Workspace/R151HubDressing/...) or one of the saved hub walls / caps /
piers the redesign restyles, and the counted findings that are new compared with BEFORE. Fails (exit 1) if any counted finding involves
an R151 part."""
import collections, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

RESTYLED = ('ChestChaseWalls/', 'GardenHubDesign/')


def ours(f):
    return 'R151HubDressing' in f['pathA'] or 'R151HubDressing' in f['pathB']


def touches_restyled(f):
    return any(k in f['pathA'] or k in f['pathB'] for k in RESTYLED)


def counted(f):
    return f['tier'] in Z.COUNTED and not f['same_look']


def key(f):
    return tuple(sorted((f['pathA'] + '.' + f['faceA'], f['pathB'] + '.' + f['faceB'])))


def run(path):
    parts, fs = Z.run(path)
    return parts, [f for f in fs if counted(f)], [f for f in fs if f['tier'] == 'strict' and not f['same_look']]


def main():
    before, afters = sys.argv[1], sys.argv[2:]
    bparts, bfs, _ = run(before)
    bkeys = collections.Counter(key(f) for f in bfs)
    print('BEFORE %s: %d parts, %d counted findings on the whole map (all pre-existing)' % (os.path.basename(before), len(bparts), len(bfs)))
    bad = 0
    for a in afters:
        parts, fs, strict = run(a)
        mine = [f for f in fs if ours(f)]
        restyled = [f for f in fs if touches_restyled(f) and not ours(f)]
        akeys = collections.Counter(key(f) for f in fs)
        new = [f for f in fs if akeys[key(f)] > bkeys.get(key(f), 0)]
        r151 = sum(1 for p in parts if 'R151HubDressing' in p.path)
        print('AFTER  %s: %d parts (%d R151), %d counted findings; with an R151 part: %d; on a restyled wall part: %d; new vs before: %d; '
              'strict rule (reported, not counted) with an R151 part: %d'
              % (os.path.basename(a), len(parts), r151, len(fs), len(mine), len(restyled), len(new), sum(1 for f in strict if ours(f))))
        for f in (mine + [f for f in new if not ours(f)])[:30]:
            print('   %-8s off=%+.4f area=%6.2f %s.%s <-> %s.%s at %s' % (f['tier'], f['offset'], f['area'], f['pathA'][-60:], f['faceA'],
                                                                      f['pathB'][-60:], f['faceB'], f['at']))
        bad += len(mine)
    print('R151 z-fighting: %s' % ('NONE' if bad == 0 else '%d counted findings with R151 parts' % bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
