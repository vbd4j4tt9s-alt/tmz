"""R150: z-fighting on the mystery pedestal (docs/proposals/R149/tools/zfight.py, the R149 detector) in every state and biome.
Usage: python3 check_pedestal_zfight.py <dump_zscene.luau output> [--list]
Reads the "SCENE <name> <json>" lines, runs the detector on each and FAILS when a COUNTED finding (coplanar / near / far: two visible faces pointing the
same way in nearly one plane and overlapping, which flicker) involves a pedestal part, a client fx part or the pack. The strict tier (an offset under
0.002 x the viewing distance, no depth buffer needs it) is only reported. Surfaces are never within .02 stud of each other if this passes."""
import collections, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

lines = [l for l in open(sys.argv[1], encoding='utf-8').read().split('\n') if l.startswith('SCENE ')]
bad = 0
total_parts = 0
strict_total = collections.Counter()
counted_total = 0
for l in lines:
    name, js = l[6:].split(' ', 1)
    path = os.path.join(os.path.dirname(os.path.abspath(sys.argv[1])), 'zscene_%s.json' % name)
    open(path, 'w', encoding='utf-8').write(js)
    parts, fs = Z.run(path)
    total_parts = max(total_parts, len(parts))
    mine = [f for f in fs if not f['same_look'] and ('MysteryPedestal' in f['pathA'] or 'MysteryPedestal' in f['pathB'])]
    counted = [f for f in mine if f['tier'] in Z.COUNTED]
    strict = [f for f in mine if f['tier'] == 'strict']
    counted_total += len(counted)
    strict_total[name.split('_')[0]] += len(strict)
    for f in counted:
        bad += 1
        print('  FLICKER %s: %s %s off=%+.4f  %s.%s <-> %s.%s at %s' % (name, f['tier'], f['area_label'], f['offset'], f['pathA'].rsplit('/', 2)[-2] + '/' + f['pathA'].rsplit('/', 1)[-1], f['faceA'],
              f['pathB'].rsplit('/', 2)[-2] + '/' + f['pathB'].rsplit('/', 1)[-1], f['faceB'], f['at']))
    if '--list' in sys.argv:
        for f in strict:
            print('  strict %s: off=%+.4f %s.%s <-> %s.%s' % (name, f['offset'], f['pathA'].rsplit('/', 1)[-1], f['faceA'], f['pathB'].rsplit('/', 1)[-1], f['faceB']))
print('%d scenes (%d parts at most): %d counted findings on the pedestal; strict-rule-only (reported, not counted): %s' % (
    len(lines), total_parts, counted_total, ', '.join('%s %d' % kv for kv in sorted(strict_total.items())) or 'none'))
print('pedestal z-fighting: %s' % ('PASS' if bad == 0 and lines else 'FAIL (%d)' % bad))
sys.exit(0 if bad == 0 and lines else 1)
