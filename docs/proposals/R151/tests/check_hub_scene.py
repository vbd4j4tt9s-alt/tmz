"""R151 (R152: the pedestal, the showcase item and the giant dancing avatar): the two hub displays in the FINISHED hub (docs/proposals/R149/tests/zfight_scene.luau + the real HubDisplayService, see
make_hub_scene.py): the place file's map after every real start-up builder (bases, fences, treadmills, mystery pedestals, the market, Verity's dais, the leaderboards ...), once with both
boards empty and once with a champion and an avatar on each.
Usage: python3 check_hub_scene.py <scene_empty.json> <scene_champions.json> <steps_champions.txt> <place_geom.json>
  (place_geom.json: docs/proposals/R149/tools/rbxl_geom.py <place> out.json Workspace/ChestChaseMap: every part of the saved map, invisible ones too: the bases' Spawn parts)
Checks (every one fails the run):
  * z-fighting: docs/proposals/R149/tools/zfight.py on each scene: no COUNTED finding (coplanar / near / far) that involves a part of a display's frame (the pedestal: plinth, trim, studs, column,
    inlays, plaque, band, capital, prongs). The showcase item is the game's own seed / fruit art and the avatar is Roblox's rig (a mock here): their findings are listed apart, not counted;
  * nothing but a pedestal, an item and an avatar: no sign board, posts, stage, halo, disc or tube (no part of the frame is round, translucent, neon or named like the old ones);
  * placement: every display part is inside its back corner (HubDecorKit151.K.Reserved: BEST PULL x 145 .. 335, BIGGEST FRUIT x -335 .. -145, z -618 .. -420) with at least WALL_GAP studs to the walls,
    clear of EVERY other part of the map in 3D (nothing overlaps), and at least MIN_GAP studs away in plan from the bases, their fences, treadmills and pedestals, the market, Verity, the
    leaderboards and the hub walls;
  * the avatar: 22 to 28 studs tall (head top to soles, the real scale of the stand), its soles on the hub floor, beside the pedestal;
  * the words: each plaque faces the market (the angle between its front and the way to the market is under 5 degrees); from every player's spawn (the six bases and the hub's own), the
    market's sides, Verity and the track gate the plaque's front is within 60 degrees (and the label over the item, which turns to the camera, is in plain view) and nothing in the hub stands between
    the spawn's eye and the plaque within PLAQUE_RANGE studs (the plaque's own draw distance; farther the display is a landmark with its label);
  * size: every display (frame + item + avatar) is at most 260 parts, the pedestal at most 24, the item at most 150.
"""
import collections, json, math, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

MIN_GAP = 40.0            # studs in plan between a display and the map's own pieces
CORNER = {'Pull': (145.0, 335.0, -618.0, -420.0), 'Fruit': (-335.0, -145.0, -618.0, -420.0)}   # HubDecorKit151.K.Reserved
WALL_GAP = 30.0            # studs between a display's parts and the hub's walls (x +-335, z -618)
PLAQUE_RANGE = 300.0       # the plaque's SurfaceGui MaxDistance (HubDisplayRules.Plaque): within it nothing may stand between a spawn and the plaque
LABEL_RANGE = 420.0        # the label's BillboardGui MaxDistance (HubDisplayRules.Label)
AVATAR_TALL = (22.0, 28.5)
SKIP = ('Lobby/LobbyFloor', 'Lobby/BaseBoundaryLine', 'Lobby/FallbackSpawn', 'SafeZonePresentation', 'Lobby/EntranceSign')


def extents(p):
    r, s = p['r'], p['size']
    return [(abs(r[i][0]) * s[0] + abs(r[i][1]) * s[1] + abs(r[i][2]) * s[2]) / 2 for i in range(3)]


def box(p):
    e = extents(p)
    c = p['p']
    return (c[0] - e[0], c[0] + e[0], c[1] - e[1], c[1] + e[1], c[2] - e[2], c[2] + e[2])


def gap_xz(a, b):
    dx = max(a[0] - b[1], b[0] - a[1], 0.0)
    dz = max(a[4] - b[5], b[4] - a[5], 0.0)
    return math.hypot(dx, dz)


def overlap3(a, b, eps=1e-3):
    return a[0] < b[1] - eps and b[0] < a[1] - eps and a[2] < b[3] - eps and b[2] < a[3] - eps and a[4] < b[5] - eps and b[4] < a[5] - eps


def seg_hits_box(p0, p1, b):
    t0, t1 = 0.0, 1.0
    for axis, (lo, hi) in enumerate(((b[0], b[1]), (b[2], b[3]), (b[4], b[5]))):
        d = p1[axis] - p0[axis]
        if abs(d) < 1e-12:
            if p0[axis] < lo or p0[axis] > hi:
                return False
        else:
            ta, tb = (lo - p0[axis]) / d, (hi - p0[axis]) / d
            if ta > tb:
                ta, tb = tb, ta
            t0, t1 = max(t0, ta), min(t1, tb)
            if t0 > t1:
                return False
    return True


def kind_of(path):
    return 'Pull' if 'BestPullDisplay' in path else 'Fruit' if 'BiggestFruitDisplay' in path else None


bad = 0
def fail(msg):
    global bad
    bad += 1
    print('  FAIL:', msg)


scenes = {}
for name, path in (('empty', sys.argv[1]), ('champions', sys.argv[2])):
    scenes[name] = path
steps = sys.argv[3] if len(sys.argv) > 3 else None

print('== z-fighting (R149 detector)')
for name, path in scenes.items():
    parts, fs = Z.run(path)
    def ours(f):
        return not any(('/Item/' in x or '/Avatar/' in x) for x in (f['pathA'], f['pathB']))
    mine_all = [f for f in fs if not f['same_look'] and ('HubDisplays151' in f['pathA'] or 'HubDisplays151' in f['pathB'])]
    mine = [f for f in mine_all if ours(f)]
    apart = [f for f in mine_all if not ours(f) and f['tier'] in Z.COUNTED]
    counted = [f for f in mine if f['tier'] in Z.COUNTED]
    strict = [f for f in mine if f['tier'] == 'strict']
    shown = sum(1 for p in parts if 'HubDisplays151' in p.path)
    print('  %s: %d parts in the scene, %d of them the displays; %d counted findings on the frame, %d strict-only (not counted); in the game\'s item art / the avatar rig (not ours, not counted): %d' % (name, len(parts), shown, len(counted), len(strict), len(apart)))
    for f in counted:
        fail('FLICKER %s: %s %s off=%+.4f %s.%s <-> %s.%s at %s' % (name, f['tier'], f['area_label'], f['offset'], f['pathA'].rsplit('/', 1)[-1], f['faceA'], f['pathB'].rsplit('/', 1)[-1], f['faceB'], f['at']))
    if shown < 40:
        fail('%s: the displays are missing from the scene (%d parts)' % (name, shown))

print('== placement (champions scene: the displays with their items and avatars)')
scene = json.load(open(scenes['champions'], encoding='utf-8'))
allparts = scene['parts']
mine = collections.defaultdict(list)
others = []
for p in allparts:
    k = kind_of(p['path'])
    if 'HubDisplays151' in p['path'] and k:
        mine[k].append(p)
    elif not any(s in p['path'] for s in SKIP):
        others.append(p)
obox = [(p, box(p)) for p in others]
gaps = collections.defaultdict(lambda: [1e9, ''])
overlaps = 0
for kind, plist in mine.items():
    lo = [1e9, 1e9, 1e9];hi = [-1e9, -1e9, -1e9]
    for p in plist:
        b = box(p)
        lo = [min(lo[0], b[0]), min(lo[1], b[2]), min(lo[2], b[4])];hi = [max(hi[0], b[1]), max(hi[1], b[3]), max(hi[2], b[5])]
        x0, x1, z0, z1 = CORNER[kind]
        if b[0] < x0 or b[1] > x1 or b[4] < z0 or b[5] > z1:
            fail('%s part %s leaves its corner: x %.1f..%.1f z %.1f..%.1f' % (kind, p['path'].rsplit('/', 1)[-1], b[0], b[1], b[4], b[5]))
        if min(335.0 - max(abs(b[0]), abs(b[1])), b[4] + 618.0) < WALL_GAP:
            fail('%s part %s is within %d studs of a wall: x %.1f..%.1f z %.1f..%.1f' % (kind, p['path'].rsplit('/', 1)[-1], WALL_GAP, b[0], b[1], b[4], b[5]))
        for q, qb in obox:
            if overlap3(b, qb):
                overlaps += 1;fail('%s part %s overlaps %s' % (kind, p['path'].rsplit('/', 1)[-1], q['path']))
            g = gap_xz(b, qb)
            area = q.get('area') or 'other'
            if g < gaps[(kind, area)][0]:
                gaps[(kind, area)] = [g, q['path'].split('/', 2)[-1][:60]]
    print('  %s: %d parts, x %.0f .. %.0f, z %.0f .. %.0f, up to %.1f studs tall (floor y 4)' % (kind, len(plist), lo[0], hi[0], lo[2], hi[2], hi[1] - 4))
    if hi[1] - 4 > 47:
        fail('%s display is taller than the hub walls (48): %.1f' % (kind, hi[1] - 4))
by_area = collections.defaultdict(dict)
for (kind, area), (g, who) in sorted(gaps.items()):
    by_area[area][kind] = (g, who)
print('  nearest other piece of the map, in plan (studs):')
for area in sorted(by_area):
    row = by_area[area]
    print('   %-10s %s' % (area, '   '.join('%s %.0f (%s)' % (k, v[0], v[1]) for k, v in sorted(row.items()))))
for (kind, area), (g, who) in gaps.items():
    if g < MIN_GAP:
        fail('%s display is only %.1f studs from %s (%s)' % (kind, g, area, who))
if overlaps == 0:
    print('  no display part overlaps any other part of the map')

print('== only a pedestal, an item and an avatar')
OLD = ('Sign board', 'Sign frame', 'Post', 'Post foot', 'Post collar', 'Post cap', 'Post gem', 'Crown band', 'Crown jewel', 'Apron', 'Stage', 'Stage skirt', 'Front step', 'Plinth', 'Plinth skirt',
       'Plinth glow', 'Halo', 'ItemAnchor', 'Projector beam', 'Cradle glow', 'PodiumPivot', 'Glow ring')
for kind, plist in mine.items():
    frame = [p for p in plist if '/Item/' not in p['path'] and '/Avatar/' not in p['path']]
    names = collections.Counter(p['name'] for p in frame)
    print('  %s: %d frame parts: %s' % (kind, len(frame), ', '.join('%s x%d' % (k, v) if v > 1 else k for k, v in sorted(names.items()))))
    for p in frame:
        if p['name'] in OLD:
            fail('%s still has a %s (the sign board, posts, stage slab, halo, disc and tube are gone)' % (kind, p['name']))
        if p['t'] > 0 or p['shape'] in ('Cylinder', 'Ball') or p['material'] in ('Neon', 'Glass'):
            fail('%s part %s is translucent / round / neon / glass (%s %s t=%s)' % (kind, p['name'], p['shape'], p['material'], p['t']))
    if len(frame) > 24:
        fail('%s pedestal is %d parts (cap 24)' % (kind, len(frame)))

print('== the avatar')
for kind, plist in mine.items():
    av = [p for p in plist if '/Avatar/' in p['path']]
    head = [p for p in av if p['name'] == 'Head']
    feet = [p for p in av if p['name'] in ('LeftFoot', 'RightFoot')]
    if not head or not feet:
        # the blocky silhouette: its blocks
        head = [p for p in av if p['name'] == 'Head'] or av[:1]
    if not av:
        fail('%s has no avatar' % kind)
        continue
    top = max(box(p)[3] for p in head)
    bottom = min(box(p)[2] for p in (feet or av))
    h = top - bottom
    print('  %s: avatar %.1f studs tall (head top %.1f, soles %.1f; the floor is y 4), %d parts' % (kind, h, top, bottom, len(av)))
    if not AVATAR_TALL[0] <= h <= AVATAR_TALL[1]:
        fail('%s avatar is %.1f studs tall (want %.0f to %.0f)' % (kind, h, AVATAR_TALL[0], AVATAR_TALL[1]))
    if abs(bottom - 4.0) > 0.3:
        fail('%s avatar\'s soles are at y %.2f, not on the floor (4.0)' % (kind, bottom))

print('== the words')
spawns = []
place = json.load(open(sys.argv[4], encoding='utf-8'))['parts'] if len(sys.argv) > 4 else []
for p in place:
    path = p['path']
    if '/Bases/' in path and path.endswith('/Spawn'):
        spawns.append((path.split('/')[-2] + ' spawn', tuple(p['p'])))
    if path.endswith('Lobby/FallbackSpawn'):
        spawns.append(('hub fallback spawn', tuple(p['p'])))
# where players stand to use the market (beside its 54-stud porch, on either side) and to talk to Verity (25 studs in front of her dais), and the track gate
spawns.append(('market (west side)', (-45.0, 4.1, -269.3)))
spawns.append(('market (east side)', (45.0, 4.1, -269.3)))
spawns.append(('Verity (talking)', (0.0, 4.1, -315.0)))
spawns.append(('track gate', (0.0, 4.1, -100.0)))
if len([s for s in spawns if 'Base' in s[0]]) != 6 or not [s for s in spawns if 'fallback' in s[0]]:
    fail('expected the six bases\' spawns and the hub\'s own, found %d' % len(spawns))
blockers = [(q, qb) for q, qb in obox if (q.get('area') or '') in ('bases', 'fence', 'pedestal', 'treadmill', 'shop', 'verity', 'hub') and qb[3] - qb[2] > 0.5]
for kind, plist in mine.items():
    board = [p for p in plist if p['path'].endswith('/Pedestal plaque')][0]
    r = board['r']
    front = (-r[0][2], -r[1][2], -r[2][2])
    c = board['p']
    to_market = (0 - c[0], 0, -265 - c[2])
    n = math.hypot(to_market[0], to_market[2])
    cosm = (front[0] * to_market[0] + front[2] * to_market[2]) / n / math.hypot(front[0], front[2])
    ang = math.degrees(math.acos(max(-1, min(1, cosm))))
    print('  %s plaque at (%.0f, %.0f, %.0f) faces %.1f degrees off the market' % (kind, c[0], c[1], c[2], ang))
    if ang > 5:
        fail('%s plaque does not face the market (%.1f degrees)' % (kind, ang))
    # the label floats over the item (45 studs or so up, turned to the camera): its middle
    label = None
    for line in (open(steps, encoding='utf-8') if steps and os.path.exists(steps) else []):
        if line.startswith('HUBTEXT '):
            t = json.loads(line[len('HUBTEXT '):])
            if t['kind'] == kind:
                label = t['label']
    for name, at in spawns:
        v = (at[0] - c[0], at[1] - c[1], at[2] - c[2])
        dist = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2)
        ang2 = math.degrees(math.acos(max(-1, min(1, (front[0] * v[0] + front[1] * v[1] + front[2] * v[2]) / dist / math.sqrt(sum(x * x for x in front))))))
        # eye 5 studs above the spawn pad; five rays at the plaque (its middle, its two ends, its top and bottom edge): it is hidden only when every ray is stopped (a fence post or a
        # porch column is not a wall: the player moves his head)
        eye = (at[0], at[1] + 5.0, at[2])
        right = (r[0][0], r[1][0], r[2][0])
        hw, hh = board['size'][0] / 2, board['size'][1] / 2
        def targets(center, half_w, half_h, axis):
            return [center, (center[0] + axis[0] * half_w, center[1], center[2] + axis[2] * half_w), (center[0] - axis[0] * half_w, center[1], center[2] - axis[2] * half_w),
                    (center[0], center[1] + half_h, center[2]), (center[0], center[1] - half_h, center[2])]
        def hidden(tlist):
            who_ = ''
            n_ = 0
            for target in tlist:
                for q, qb in blockers:
                    if seg_hits_box(eye, target, qb):
                        n_ += 1;who_ = q['path'].split('/', 2)[-1]
                        break
            return n_ == len(tlist), n_, who_
        gone, blocked, who = hidden(targets(tuple(c), hw, hh, right))
        seen = ''
        if label:
            lp = tuple(label['p'])
            ld = math.dist(at, lp)
            lgone, lblocked, lwho = hidden(targets(lp, label['w'] / 2, label['h'] / 2, right))
            seen = ', label %3.0f studs %s' % (ld, 'clear' if not lblocked else ('hidden by ' + lwho if lgone else '%d of 5 rays stopped' % lblocked))
            if ld <= LABEL_RANGE and lgone:
                fail('%s label is hidden from %s by %s' % (kind, name, lwho))
        print('    from %-20s %5.0f studs, %5.1f degrees off the front, plaque %s%s' % (name, dist, ang2, 'clear' if not blocked else ('hidden by ' + who if gone else '%d of 5 rays stopped' % blocked), seen))
        if ang2 > 60 and dist <= PLAQUE_RANGE:
            fail('%s plaque\'s front is %.1f degrees off the way to %s' % (kind, ang2, name))
        if gone and dist <= PLAQUE_RANGE:
            fail('%s plaque is hidden from %s (%.0f studs) by %s' % (kind, name, dist, who))

print('== size')
if steps and os.path.exists(steps):
    for line in open(steps, encoding='utf-8'):
        m = re.match(r'HUBINFO (Pull|Fruit) frame=(\d+) item=(\d+) avatar=(\d+)(?: source=(\w+) mode=(\w+))?', line)
        if m:
            kind, f, i, a = m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4))
            print('  %s: pedestal %d + item %d + avatar %d = %d parts (the old display was 120 or more); avatar %s, mode %s' % (kind, f, i, a, f + i + a, m.group(5), m.group(6)))
            if f + i + a > 260:
                fail('%s display has %d parts (cap 260)' % (kind, f + i + a))
            if f > 24:
                fail('%s pedestal has %d parts (cap 24)' % (kind, f))
            if i > 150:
                fail('%s item has %d parts (cap 150)' % (kind, i))
print('hub displays in the hub: %s' % ('PASS' if bad == 0 else 'FAIL (%d)' % bad))
sys.exit(0 if bad == 0 else 1)
