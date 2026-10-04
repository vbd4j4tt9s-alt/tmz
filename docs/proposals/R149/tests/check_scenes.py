"""R149 floating check (the R134 tool, docs/proposals/seeds_R133/preview/check_floating.py) over the scenes of test_fruit_models.luau.
Usage: python3 check_scenes.py <check_floating.py> plants <scene.json> <base scene.json>
       python3 check_scenes.py <check_floating.py> fruit  <scene.json>
 plants: every plant scene must have 0 floating parts, except those the BASE commit's plant of the same label already has (Elderbloom's
         trunk "Ancient living rune" x2, which belong to the trunk, not to a fruit): no new floating part anywhere.
 fruit : every redesigned fruit built alone (as a harvest item and as held in the hand), with ellipsoids checked as ellipsoids, hangs together:
         0 floating parts in each. (A fruit on its plant is checked by 'plants' with the tool's box approximation, as R148 does.)"""
import importlib.util, json, sys
from collections import Counter

spec = importlib.util.spec_from_file_location('check_floating', sys.argv[1])
cf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cf)
mode, scene_path = sys.argv[2], sys.argv[3]


def loose_by_label(path):
    scene = json.load(open(path))
    by = {}
    for p in scene['parts']:
        by.setdefault(p['seed'], []).append(p)
    out = {}
    for seed, parts in by.items():
        label = scene['labels'][seed - 1]['text']
        out[label] = Counter(p['name'] for p in cf.check(parts, .03))
    return out, len(scene['labels']), sum(len(v) for v in by.values())


new, scenes, nparts = loose_by_label(scene_path)
bad = []
if mode == 'plants':
    base, _, _ = loose_by_label(sys.argv[4])
    inherited = 0
    for label, loose in new.items():
        allowed = base.get(label, Counter())
        if label.startswith('Elderbloom'):
            allowed = allowed + Counter({'Ancient living rune': 2})
        for name, n in loose.items():
            if n > allowed.get(name, 0):
                bad.append('%s: %s x%d floating' % (label, name, n))
            else:
                inherited += n
    print('%d plant scenes, %d parts: %d floating part(s) new, %d inherited from the base (Elderbloom\'s trunk runes)' % (scenes, nparts, len(bad), inherited))
else:
    for label, loose in new.items():
        if loose:
            bad.append('%s: %s floating' % (label, dict(loose)))
    print('%d fruit scenes, %d parts: %d floating part(s)' % (scenes, nparts, sum(1 for l in new.values() if l)))
if bad:
    print('\n'.join(bad[:30]))
    sys.exit(1)
