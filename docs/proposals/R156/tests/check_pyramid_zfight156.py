"""R156: no z-fighting on or around the Desert's Classic Pyramid (the R149 / R152 rule), on a scene of the owner's place after the real start-up passes with the
keyboard drawn around the pyramid (R152's sweep world: run_variant.sh, RUNNER next to the pyramid).
Usage: python3 check_pyramid_zfight156.py <scene.json>
  1. R149's detector (docs/proposals/R149/tools/zfight.py, every tier, MeshParts as their boxes, as R152's sweep counts them): no coplanar / near / far pair that
     involves a pyramid part, whatever it looks like (two Limestone faces of the same colour count too: the look-alike exception is not taken here).
  2. the pyramid's own parts, every pair, with no visibility shortcut (the chamber is sealed: R149's rule would not even look in there, but a camera that
     clips in, or a player walking in through the walk-through walls, would): no two faces that point the same way, lie within 0.05 stud of one plane and
     overlap by more than 0.0001 stud^2 (touching edges only). Every pyramid part is an upright box, so the faces are exact rectangles.
Exits 1 on any finding."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

KEY = 'MythicLandmarks/Biome2_Landmark/'
path = sys.argv[1]
scene = json.load(open(path))
mine = [p for p in scene['parts'] if KEY in p['path'] and p.get('t', 0) < .98]
bad = 0
xs = [p['p'][0] for p in mine]
zs = [p['p'][2] for p in mine]
keys = [p for p in scene['parts'] if 'KeyboardTrackVisuals' in p['path'] and min(xs) - 40 < p['p'][0] < max(xs) + 40 and min(zs) - 40 < p['p'][2] < max(zs) + 40]
if len(mine) != 60 or not keys:
    bad += 1
    print('  THE SCENE IS NOT THE ONE TO CHECK: %d pyramid parts, %d keyboard parts around it (the keyboard must be drawn around the pyramid)' % (len(mine), len(keys)))
# 1. the detector
parts, fs = Z.run(path)
ours = [f for f in fs if KEY in f['pathA'] or KEY in f['pathB']]
tiers = {}
for f in ours:
    tiers[f['tier']] = tiers.get(f['tier'], 0) + 1
    if f['tier'] in Z.COUNTED:
        bad += 1
        print('  Z-FIGHTING: %s off=%+.4f area=%.3f %s.%s <-> %s.%s at %s (same look: %s)' % (f['tier'], f['offset'], f['area'], f['pathA'], f['faceA'], f['pathB'], f['faceB'], f['at'], f['same_look']))
print('detector: %d pyramid parts and %d keyboard parts around them in a scene of %d; findings that touch the pyramid: %s' % (len(mine), len(keys), len(scene['parts']), ', '.join('%s %d' % kv for kv in sorted(tiers.items())) or 'none'))
# 2. every pair of pyramid parts
for p in mine:
    r = p['r']
    assert all(abs(r[i][j] - (1 if i == j else 0)) < 1e-9 for i in range(3) for j in range(3)), 'a pyramid part is turned: ' + p['path']
boxes = [(p['path'].split('/')[-1], [p['p'][i] - p['size'][i] / 2 for i in range(3)], [p['p'][i] + p['size'][i] / 2 for i in range(3)]) for p in mine]
pairs = 0
same = 0
for i in range(len(boxes)):
    for j in range(i + 1, len(boxes)):
        na, la, ha = boxes[i]
        nb, lb, hb = boxes[j]
        for ax in range(3):
            u, v = [k for k in range(3) if k != ax]
            ou = min(ha[u], hb[u]) - max(la[u], lb[u])
            ov = min(ha[v], hb[v]) - max(la[v], lb[v])
            if ou <= 0 or ov <= 0 or ou * ov <= 1e-4:
                continue
            for side, pa, pb in ((+1, ha[ax], hb[ax]), (-1, la[ax], lb[ax])):
                pairs += 1
                if abs(pa - pb) <= 0.05:
                    bad += 1
                    same += 1
                    print('  SAME PLANE: %s and %s, their %s%s faces %.4f apart over %.3f stud^2' % (na, nb, '+' if side > 0 else '-', 'XYZ'[ax], abs(pa - pb), ou * ov))
print('pyramid self-check: %d parts, %d face pairs that overlap in plan looked at, %d in one plane' % (len(boxes), pairs, same))
print('R156 pyramid z-fighting: %s' % ('PASS' if bad == 0 else 'FAIL (%d)' % bad))
sys.exit(1 if bad else 0)
