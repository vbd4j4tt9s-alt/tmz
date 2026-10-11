"""R158 walls: the BUILT map against the same map built WITHOUT the R158 passes (MapService's two R158 lines taken out), scene by scene (run_variant.sh: the owner's place after every
REAL start-up pass, the REAL keyboard client around a runner; the hub and one scene per biome).
Usage: python3 check_untouched158.py <baseline world dir> <built world dir> NAME [NAME ...]

 1. nothing else changed: every part of the baseline map that is not a Lava stream / pool is in the built map with the same path, size, place, turn, colour and material (the 15 saved
    walls: same size and place, only colour / material are new); the only extra parts are the R158 ones (TrackWalls158, TrackBackdrops158, BaseWalls158);
    the removed parts are exactly the lava streams and pools (the river, the two side pools, the three channels, the molten crater: names listed), nothing else.
 2. the groups the owner named are byte-identical: the R157 Desert pyramid, the keyboard (the only differences are the keys and floor strips that now fill the floor where lava was: z 2465 - 2655), the keepers, the pack spawn spots (the Seeds), the hub (walls, gate, paths, bases, market), the track floor and the saved scenery.
 3. the BUILT R158 parts obey the placement rules (check_walls158's rules, run on the scene, not on the data): reach into the track, keys, gatehouse, Desert walkway, pyramid footprint, the
    ground outside the walls and off the hub, the caps on the wall tops, every model part at |x| >= 100 (or behind the end wall) and off the hub.
Exits 1 on any failure."""
import collections, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'design'))
import check_walls158 as C  # noqa: E402
import make158 as M  # noqa: E402

ROOT = 'Workspace/ChestChaseMap/'
NEW = ('TrackWalls158/', 'TrackBackdrops158/', 'BaseWalls158/')
LAVA = ('PresentationV128/ContinuousLavaRiver', 'EnvironmentPolishV127/IrregularMagmaPools', 'MythicLandmarks/Biome4_Landmark/VolcanoMagmaChannel_', 'MythicLandmarks/Biome4_Landmark/MoltenCrater', 'Obby/Biomes/Biome_4_EMBER_WASTES/BiomeScenesV092/Pool shore')
GROUPS = collections.OrderedDict([
    ('the R157 Desert pyramid', lambda p: 'Biome2_Landmark' in p),
    ('the keyboard (keys, strips, bars, floor copies)', lambda p: 'KeyboardTrackVisuals' in p or '/GroundPatch' in p or 'LegendStrip' in p or 'LegendFar' in p),
    ('the keepers', lambda p: 'Guardian' in p or 'Keeper' in p),
    ('the pack spawn spots (Seeds)', lambda p: '/Seeds/' in p),
    ('the hub (walls, gate, paths, market, displays)', lambda p: any(k in p for k in ('/HubDecor151/', '/EconomyHub/', '/Lobby/', '/ChestChaseWalls/', '/GardenHubDesign/', 'HubDisplays151'))),
    ('the bases', lambda p: '/Bases/' in p),
    ('the track floor and the saved scenery', lambda p: '/Obby/' in p),
])


def key(p, with_look=True):
    f = lambda v: round(v, 2)
    r = p['r']
    k = (p['path'], p['name'], tuple(f(v) for v in p['size']), tuple(f(v) for v in p['p']), tuple(f(r[i][j]) for i in range(3) for j in range(3)))
    if with_look:
        k += (tuple(p['color']), p['material'], round(p['t'], 3))
    return k


def is_new(path):
    return any(n in path for n in NEW)


def is_lava(path):
    rel = path.replace(ROOT, '')
    return any(rel.startswith(l) for l in LAVA)


def spec_of(p):
    r = p['r']
    cf = [p['p'][0], p['p'][1], p['p'][2]] + [r[i][j] for i in range(3) for j in range(3)]
    return {'Group': p['path'].replace(ROOT, ''), 'Name': p['name'], 'Shape': p['shape'], 'Size': p['size'], 'CF': cf, 'Color': p['color'], 'Material': p['material'], 'Mesh': 'Sphere' if p.get('mesh') else None}


def main():
    base_dir, built_dir, names = sys.argv[1], sys.argv[2], sys.argv[3:]
    bad = []
    totals = collections.Counter()
    for n in names:
        base = json.load(open(os.path.join(base_dir, n + '.json')))['parts']
        built = json.load(open(os.path.join(built_dir, n + '.json')))['parts']
        walls = [p for p in built if '/Obby/BiomeWalls/' in p['path']]
        bwalls = {p['path']: p for p in base if '/Obby/BiomeWalls/' in p['path']}
        # 1. everything else
        base_other = collections.Counter()
        removed_expected = collections.Counter()
        for p in base:
            rel = p['path'].replace(ROOT, '')
            if is_lava(p['path']):
                removed_expected['Pool shore' if 'Pool shore' in rel else rel.split('/')[2] if rel.startswith('MythicLandmarks') else rel.split('/')[1]] += 1
            else:
                base_other[key(p, '/Obby/BiomeWalls/' not in p['path'])] += 1
        built_other = collections.Counter()
        added = []
        for p in built:
            if is_new(p['path']):
                added.append(p)
            else:
                built_other[key(p, '/Obby/BiomeWalls/' not in p['path'])] += 1
        missing = base_other - built_other
        extra = built_other - base_other
        # the keyboard may fill the floor where lava was (Lava scene, the lava area only)
        def lava_area_key(k):
            z = k[3][2]
            return 2465 <= z <= 2655 and ('KeyboardTrackVisuals' in k[0] or 'GroundPatch' in k[0] or 'Legend' in k[0])
        miss_other = [k for k in missing.elements() if not lava_area_key(k)]
        extra_other = [k for k in extra.elements() if not lava_area_key(k)]
        kb_diff = sum(1 for k in missing.elements() if lava_area_key(k)) + sum(1 for k in extra.elements() if lava_area_key(k))
        if miss_other:
            bad.append('%s: %d baseline parts are gone or changed, e.g. %s' % (n, len(miss_other), miss_other[0][:2]))
        if extra_other:
            bad.append('%s: %d parts are new or changed that are not R158 parts, e.g. %s' % (n, len(extra_other), extra_other[0][:2]))
        # the walls: same size and place, new look
        for path, p in bwalls.items():
            q = next((w for w in walls if w['path'] == path and key(w, False) == key(p, False)), None)
            if q is None:
                bad.append('%s: wall %s changed its size or place' % (n, path.split('/')[-1]))
        # the removed lava: exactly the streams and pools
        lava_removed = sum(removed_expected.values())
        totals['lava removed'] += lava_removed
        if n == names[0]:
            print('  lava parts the baseline has and the build removes: ' + ', '.join('%s %d' % kv for kv in sorted(removed_expected.items())))
        # 2. the groups
        for g, f in GROUPS.items():
            a = collections.Counter(key(p, '/Obby/BiomeWalls/' not in p['path']) for p in base if f(p['path']) and not is_lava(p['path']))
            b = collections.Counter(key(p, '/Obby/BiomeWalls/' not in p['path']) for p in built if f(p['path']) and not is_new(p['path']))
            d = (a - b) + (b - a)
            dd = [k for k in d.elements() if not (g.startswith('the keyboard') and lava_area_key(k))]
            totals[g] += sum(a.values())
            if dd:
                bad.append('%s: %s changed (%d parts differ, e.g. %s)' % (n, g, len(dd), dd[0][:2]))
        # 3. the built R158 parts obey the rules
        S = {'specs': {'walls': [], 'backdrops': [], 'baseA': [], 'walls_lite': []}}
        for p in added:
            rel = p['path'].replace(ROOT, '')
            if rel.startswith('TrackWalls158/'):
                S['specs']['walls'].append(spec_of(p))
            elif rel.startswith('BaseWalls158/'):
                S['specs']['baseA'].append(spec_of(p))
            elif rel.startswith('TrackBackdrops158/') and '/Models/' not in rel:
                S['specs']['backdrops'].append(spec_of(p))
        rb = []
        C.check_placement(S, rb)
        for b in rb:
            bad.append('%s: built part breaks a rule: %s' % (n, b))
        models = [p for p in added if '/Models/' in p['path']]
        for p in models:
            P = M.corners(spec_of(p))
            xs = [c[0] for c in P]
            zs = [c[2] for c in P]
            if min(zs) < -99.01:
                bad.append('%s: %s reaches over the hub' % (n, p['path'].split('/')[-3:]))
                break
            if min(zs) < 5990 and min(abs(x) for x in xs) < 99.99 and min(xs) * max(xs) <= 0 or (min(zs) < 5990 and min(xs) * max(xs) > 0 and min(abs(x) for x in xs) < 99.99):
                bad.append('%s: %s comes inside |x| 100' % (n, p['path'].split('/')[-3:]))
                break
        totals['R158 parts'] = max(totals['R158 parts'], len(added))
        print('%-7s %6d baseline parts, %6d built; R158 parts %d (walls %d, ground %d, base %d, models %d); lava parts removed %d; keys that fill the lava floor %d' % (
            n, len(base), len(built), len(added), len(S['specs']['walls']), len(S['specs']['backdrops']), len(S['specs']['baseA']), len(models), lava_removed, kb_diff))
    for g, c in totals.items():
        if g not in ('lava removed', 'R158 parts'):
            print('  unchanged: %-52s %6d part-checks' % (g, c))
    for b in bad[:40]:
        print('  FAIL', b)
    print('R158 untouched check: %s' % ('PASS' if not bad else 'FAIL (%d)' % len(bad)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
