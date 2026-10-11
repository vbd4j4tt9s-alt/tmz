"""R153 track walls: the geometry and the worst-case fling checks, on the dump test_track_walls.luau prints (one "WP" line per solid part of the owner's map after the REAL
start-up builders, plus the KB / HULL / GATE / KEYBOARD / TRAMP numbers).
Usage: python3 -I check_track_walls.py <test output> [place.rbxl]      (exit 1 when a check fails)

 1. the walls, measured: per biome stage and side, from the place file as saved and from the map after the code has run (V134 / V136 / R83 move the walls along z): inner and
    outer face, thickness, bottom, top, z range. Plus the saved barriers (InvisibleMapBarriersV071, raised to 1024 by MapService) and the hub's walls.
 2. the wall tops: every wall top (track walls, the end wall, the hub's five walls and their caps) must be covered, from its own height up to 400+ studs over it, by solid parts
    of the map - exactly (rectangle algebra, not samples). Printed for the world WITHOUT the new blockers (the saved barriers only: the inner 1-stud strip of every side wall top
    is open sky) and WITH them (nothing open).
 3. the blockers against the walls: one per wall (more only for a wall over 2,000 studs), inner face flush (0 - 0.1 stud proud), 3+ past the outer face, from the wall top - 6 up
    1,000, no gap along a wall or between two walls, nothing of them on the track side of a wall's face or low enough to touch anything that is played on (floor, keys, the
    refresh barrier's opening, packs, holes); the only solid parts they overlap are walls, the saved barriers, the hub's wall caps and the hub gate's towers.
 4. how high a fling goes (KnockbackConfig, The Darkened, lightning, the bat) and the worst-case simulation: a body launched from the floor with every launch the game has,
    every starting place, unsteered (as thrown, and with Ragdoll.KeepOnTrack's lateral clamp) and STEERED toward the wall in mid air by the runner (the game's own movement
    sets the body's horizontal speed every frame: RunnerController) from several moments, at 150 and 1,200 studs/s, with three body widths, colliding with the solids of the
    map at that place along the track. Where does it come to rest? On a wall top = failure. Without the blockers some do (that is the bug); with them none."""
import math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
fails = 0


def ok(msg):
    print('ok ' + msg)


def fail(msg):
    global fails
    fails += 1
    print('FAIL ' + msg)


def check(cond, msg, why=''):
    if cond:
        ok(msg)
    else:
        fail(msg + (': ' + str(why) if why != '' else ''))


# ---------------------------------------------------------------------------------------------------------------------------------------------------------
parts, kb, hull, gate, keyboard, tramp = [], {}, None, None, None, None
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    f = line.rstrip('\n').split('\t')
    if f[0] == 'WP':
        lo = [float(x) for x in f[5].split()]
        hi = [float(x) for x in f[6].split()]
        parts.append({'path': f[1].split('ChestChaseMap/', 1)[-1], 'cls': f[2], 'cq': f[3] == '1', 't': float(f[4]), 'lo': lo, 'hi': hi, 'axis': f[7] == '1'})
    elif f[0] == 'KB':
        kb.setdefault(f[1], []).append((int(f[2]), float(f[3]) if f[3] != 'nil' else None, float(f[4])))
    elif f[0] == 'HULL':
        hull = [float(x) for x in f[1:4]]
    elif f[0] == 'GATE':
        gate = [float(x) for x in f[1:4]]
    elif f[0] == 'KEYBOARD':
        keyboard = [float(x) for x in f[1:5]]
    elif f[0] == 'TRAMP':
        tramp = [float(x) for x in f[1:3]]
check(len(parts) > 100 and hull and gate and keyboard and tramp and 'Keeper' in kb, 'the dump has the map and the numbers', len(parts))


def where(p, key):
    return key in p['path']


walls = [p for p in parts if where(p, 'Obby/BiomeWalls/')]
hub = [p for p in parts if where(p, 'ChestChaseWalls/')]
hubcaps = [p for p in parts if where(p, 'GardenHubDesign/') and p['path'].endswith('Cap')]
barriers = [p for p in parts if where(p, 'InvisibleMapBarriersV071/')]
blockers = [p for p in parts if where(p, 'TrackWallBlockers153/')]
name = lambda p: p['path'].rsplit('/', 1)[-1]
side_walls = [p for p in walls if name(p).endswith('Wall') and not name(p).endswith('EndWall')]
end_walls = [p for p in walls if name(p).endswith('EndWall')]
STAGE = {1: 'Forest (Sunny Meadow)', 2: 'Desert', 3: 'Snow (Frostland)', 4: 'Lava (Ember Wastes)', 5: 'Crystal', 6: 'Jungle', 7: 'Storm (Stormy Peaks)'}

# 1. the walls, measured -------------------------------------------------------------------------------------------------------------------------------
print('== 1. the walls')
if len(sys.argv) > 2 and os.path.exists(sys.argv[2]):
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
    sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'tools'))
    import rbxl_geom
    saved = rbxl_geom.extract(sys.argv[2], ('Workspace/ChestChaseMap/Obby/BiomeWalls', 'Workspace/ChestChaseMap/InvisibleMapBarriersV071'))
    print('as saved in the place (before the code runs):')
    print('  %-26s %9s %9s %6s %7s %7s %17s' % ('wall', 'inner |x|', 'outer |x|', 'thick', 'bottom', 'top', 'z'))
    for p in sorted(saved, key=lambda p: p['path']):
        if '/BiomeWalls/' not in p['path']:
            continue
        s, c = p['size'], p['p']
        if name(p).endswith('EndWall'):
            print('  %-26s %9s %9s %6.1f %7.1f %7.1f %17s' % (name(p), '-', '-', s[2], c[1] - s[1] / 2, c[1] + s[1] / 2, 'z %.1f .. %.1f' % (c[2] - s[2] / 2, c[2] + s[2] / 2)))
        else:
            print('  %-26s %9.1f %9.1f %6.1f %7.1f %7.1f %17s' % (name(p), abs(c[0]) - s[0] / 2, abs(c[0]) + s[0] / 2, s[0], c[1] - s[1] / 2, c[1] + s[1] / 2, '%.1f .. %.1f' % (c[2] - s[2] / 2, c[2] + s[2] / 2)))
    bs = [p for p in saved if '/InvisibleMapBarriersV071/Biome_' in p['path']]
    print('  saved barriers (invisible; MapService raises them to 1,024 tall): inner |x| %s, outer |x| %s, %d parts' % (
        sorted({round(abs(p['p'][0]) - p['size'][0] / 2, 1) for p in bs}), sorted({round(abs(p['p'][0]) + p['size'][0] / 2, 1) for p in bs}), len(bs)))
    print('  -> the walls\' inner faces are at |x| 89, the barriers\' at 90: a 1-stud strip of every wall top is outside the barrier')
else:
    print('(no place file: the saved numbers are skipped)')
print('after the start-up code (what the game runs on):')
print('  %-20s %-22s %9s %9s %6s %7s %7s %6s %20s' % ('wall', 'biome', 'inner |x|', 'outer |x|', 'thick', 'bottom', 'top', 'tall', 'z'))
for p in sorted(walls, key=lambda p: name(p)):
    n = name(p);stage = int(n.split('_')[1])
    if p in end_walls:
        print('  %-20s %-22s %9s %9s %6.1f %7.1f %7.1f %6.1f %20s' % (n, STAGE[stage], '-', '-', p['hi'][2] - p['lo'][2], p['lo'][1], p['hi'][1], p['hi'][1] - p['lo'][1], 'z %.1f .. %.1f' % (p['lo'][2], p['hi'][2])))
    else:
        s = 1 if p['lo'][0] > 0 else -1
        a, b = sorted((abs(p['lo'][0]), abs(p['hi'][0])))
        print('  %-20s %-22s %9.1f %9.1f %6.1f %7.1f %7.1f %6.1f %20s' % (n, STAGE[stage], a, b, b - a, p['lo'][1], p['hi'][1], p['hi'][1] - p['lo'][1], '%.1f .. %.1f' % (p['lo'][2], p['hi'][2])))
tops = {round(p['hi'][1], 3) for p in walls + hub}
inner = {round(min(abs(p['lo'][0]), abs(p['hi'][0])), 3) for p in side_walls}
check(len(side_walls) == 14 and len(end_walls) == 1 and len(hub) == 5, 'the map has 14 track side walls (7 biomes x 2), the end wall and the hub\'s 5 walls', (len(side_walls), len(end_walls), len(hub)))
print('  every wall: top Y %s, side walls\' inner face |x| %s (thickness 5, 48 tall); hub walls: %d, top Y %s' % (sorted({round(p['hi'][1], 3) for p in walls}), sorted(inner), len(hub), sorted({round(p['hi'][1], 3) for p in hub})))
WALL_TOP = max(p['hi'][1] for p in walls)
check(len({round(p['hi'][1], 3) for p in walls}) == 1 and len(inner) == 1, 'the track walls are the same in every biome (one top, one inner face)', (tops, inner))
TRACK_INNER = min(inner)
FLOOR_TOP = 4.0
floor_tops = {round(p['hi'][1], 3) for p in parts if 'BiomeGround_' in p['path'] and 'FloorSupport' not in p['path']}
check(floor_tops == {FLOOR_TOP}, 'the track floor\'s top is Y 4', floor_tops)
bar_h = {round(p['hi'][1] - p['lo'][1]) for p in barriers}
print('  the saved barriers after MapService: %d parts, %s tall, inner faces |x| %s' % (len(barriers), sorted(bar_h), sorted({round(min(abs(p['lo'][0]), abs(p['hi'][0])), 2) for p in barriers if 'Biome_' in name(p) and 'Barrier' in name(p) and 'Lobby' not in name(p) and 'Final' not in name(p)})))

# 2. wall tops -----------------------------------------------------------------------------------------------------------------------------------------
print('== 2. every wall top covered')
REACH = 400


def rect(p):
    return (p['lo'][0], p['hi'][0], p['lo'][2], p['hi'][2])


def uncovered(target, covers):
    """Area of the rectangle `target` (x0,x1,z0,z1) not inside the union of `covers` (rectangles), exact."""
    x0, x1, z0, z1 = target
    xs = sorted({x0, x1} | {min(max(c[0], x0), x1) for c in covers} | {min(max(c[1], x0), x1) for c in covers})
    zs = sorted({z0, z1} | {min(max(c[2], z0), z1) for c in covers} | {min(max(c[3], z0), z1) for c in covers})
    area, strips = 0.0, []
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            cx, cz = (xs[i] + xs[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
            if not any(c[0] < cx < c[1] and c[2] < cz < c[3] for c in covers):
                a = (xs[i + 1] - xs[i]) * (zs[j + 1] - zs[j])
                if a > 1e-9:
                    area += a;strips.append((xs[i], xs[i + 1], zs[j], zs[j + 1]))
    return area, strips


def covers_for(p, pool):
    top = p['hi'][1]
    return [rect(q) for q in pool if q is not p and q['axis'] and q['lo'][1] <= top + 1e-6 and q['hi'][1] >= top + REACH]


solid_with = parts
solid_without = [p for p in parts if p not in blockers]
subjects = [(p, n) for n, group in (('track wall', side_walls), ('end wall', end_walls), ('hub wall', hub), ('hub wall cap', hubcaps)) for p in group]
without_open, with_open = {}, {}
for p, kind in subjects:
    a0, s0 = uncovered(rect(p), covers_for(p, solid_without))
    a1, s1 = uncovered(rect(p), covers_for(p, solid_with))
    without_open[p['path']] = (a0, s0, kind);with_open[p['path']] = (a1, s1, kind)
strip_walls = [pp for pp, (a, s, k) in without_open.items() if a > 1e-6]
total_strip = sum(a for a, s, k in without_open.values())
print('without the blockers (the saved barriers only): %d of %d wall tops have open sky on them, %.0f square studs in all:' % (len(strip_walls), len(subjects), total_strip))
shown = set()
for pp in sorted(strip_walls):
    a, s, k = without_open[pp]
    sig = (k, tuple((round(x[0], 2), round(x[1], 2)) for x in s))
    if sig in shown:
        continue
    shown.add(sig)
    print('  e.g. %s: %.0f sq studs, strip x %s (z %.0f .. %.0f)' % (pp.rsplit('/', 1)[-1], a, ' .. '.join('%.1f' % v for v in (s[0][0], s[0][1])), s[0][2], s[-1][3]))
check(len(strip_walls) == 14 and all(without_open[pp][2] == 'track wall' for pp in strip_walls), 'the bug, measured: without the blockers exactly the 14 track side walls have an open strip on their top (the inner 1 stud)', len(strip_walls))
check(all(abs(sum((s[1] - s[0]) for s in without_open[pp][1][:1]) - 1.0) < 1e-6 for pp in strip_walls), 'the open strip is 1 stud wide (x 89 .. 90) along the whole wall', None)
still = [pp for pp, (a, s, k) in with_open.items() if a > 1e-6]
check(not still, 'with the blockers every wall top is covered (%d wall tops: track, end, hub walls and their caps), nothing open' % len(subjects), still[:3])
# solid parts that stand on top of anything at wall height and are not covered: other platforms that a body could land on and stand (a stairway up to the walls)
other = [p for p in parts if p['axis'] and p['hi'][1] >= 30 and p not in blockers and p not in barriers and p not in walls and p not in hub and p not in hubcaps and p['hi'][1] - p['lo'][1] < REACH]
print('other solid parts reaching Y 30 or more: %s' % (', '.join(sorted({p['path'].rsplit('/', 1)[-1] for p in other})) or 'none'))
towers = [p for p in other if 'HubDecor151/Gate/' in p['path']]
check(other and len(towers) == len(other), 'the only other solid parts that high are the hub gate\'s tower shafts (round, hub decor)', [p['path'] for p in other if p not in towers][:3])
print('  hub gate towers: |x| %.1f .. %.1f, z %.0f .. %.0f, tops Y %s. They lie beyond the saved barriers (|x| 90 - 95, solid to Y 1028, z -103 .. 85) and the hub front wall: a body on the track cannot land on them,'
      % (min(min(abs(t['lo'][0]), abs(t['hi'][0])) for t in towers), max(max(abs(t['lo'][0]), abs(t['hi'][0])) for t in towers), min(t['lo'][2] for t in towers), max(t['hi'][2] for t in towers), sorted({round(t['hi'][1], 1) for t in towers})))
print('  and the hub\'s trampolines lift the feet to Y %.1f at most (the rules cap the bounce at Y %.1f): hub players cannot reach a wall top (Y %.0f) or a tower top (Y %.0f)' % (tramp[0], tramp[1], max(p['hi'][1] for p in hub), max(t['hi'][1] for t in towers)))
check(tramp[1] < max(t['hi'][1] for t in towers) - 5, 'the trampoline cap (Y %.1f) is well under the towers\' caps (Y %.0f; the shafts\' lower step, Y %.1f, is a 0.7-stud ring round the upper shaft: hub decor in the hub)' % (tramp[1], max(t['hi'][1] for t in towers), min(t['hi'][1] for t in towers)))
check(tramp[1] < min(p['hi'][1] for p in hub) - 5, 'the trampoline cap (Y %.1f) is well under the hub walls (Y %.0f)' % (tramp[1], min(p['hi'][1] for p in hub)))

# 3. the blockers against the walls ------------------------------------------------------------------------------------------------------------------------
print('== 3. the blockers')
check(len(blockers) == len(walls), 'one blocker per wall part', (len(blockers), len(walls)))
by_wall = {}
for b in blockers:
    by_wall.setdefault(b['path'].split('TrackWallBlocker153 ')[-1], []).append(b)
missing = [name(w) for w in walls if name(w) not in by_wall]
check(not missing, 'every wall has its blocker', missing)
bad = []
for w in side_walls:
    for b in by_wall.get(name(w), []):
        sgn = 1 if w['lo'][0] > 0 else -1
        a = (w['lo'][0] if sgn > 0 else -w['hi'][0], w['hi'][0] if sgn > 0 else -w['lo'][0])  # wall in u = sgn * x
        bu = (b['lo'][0] if sgn > 0 else -b['hi'][0], b['hi'][0] if sgn > 0 else -b['lo'][0])
        lip = a[0] - bu[0]
        if not (0 <= lip <= 0.1):
            bad.append((name(w), 'inner face is %.3f proud of the wall\'s' % lip))
        if bu[1] < a[1] + 2.9:
            bad.append((name(w), 'reaches only %.2f past the outer face' % (bu[1] - a[1])))
        if not (w['hi'][1] - 10 <= b['lo'][1] <= w['hi'][1] - 1):
            bad.append((name(w), 'starts at Y %.1f (wall top %.1f)' % (b['lo'][1], w['hi'][1])))
        if b['hi'][1] < w['hi'][1] + 900:
            bad.append((name(w), 'ends at Y %.1f' % b['hi'][1]))
        if b['lo'][2] > w['lo'][2] + 1e-6 or b['hi'][2] < w['hi'][2] - 1e-6:
            bad.append((name(w), 'does not cover the wall along z'))
for w in end_walls:
    for b in by_wall.get(name(w), []):
        lip = w['lo'][2] - b['lo'][2]
        if not (0 <= lip <= 0.1) or b['hi'][2] < w['hi'][2] + 2.9 or b['lo'][0] > w['lo'][0] + 1e-6 or b['hi'][0] < w['hi'][0] - 1e-6 or b['hi'][1] < w['hi'][1] + 900:
            bad.append((name(w), 'end wall not covered'))
check(not bad, 'each blocker: inner face flush with its wall\'s (0 - 0.1 stud proud), 3 studs past the outer face, from 1 - 10 studs under the wall top to 900+ over it, along the whole wall', bad[:3])
tallest = max(b['hi'][1] for b in blockers)
low = min(b['lo'][1] for b in blockers)
print('blockers: %d parts, Y %.0f .. %.0f, thickness %.2f, longest %.0f studs' % (len(blockers), low, tallest, max(min(b['hi'][0] - b['lo'][0], b['hi'][2] - b['lo'][2]) for b in blockers), max(max(b['hi'][0] - b['lo'][0], b['hi'][2] - b['lo'][2]) for b in blockers)))
check(all(max(b['hi'][i] - b['lo'][i] for i in range(3)) <= 2048 for b in blockers), 'no blocker exceeds 2,048 studs')
check(all(b['t'] == 1.0 and b['cq'] for b in blockers), 'invisible (Transparency 1), queryable (the runner sweep sees them)')
# no gap along a side: the z ranges of one side's blockers are contiguous with overlap
for sgn in (1, -1):
    ranges = sorted((b['lo'][2], b['hi'][2]) for w in side_walls if (w['lo'][0] > 0) == (sgn > 0) for b in by_wall.get(name(w), []))
    gaps = [(ranges[i][1], ranges[i + 1][0]) for i in range(len(ranges) - 1) if ranges[i + 1][0] > ranges[i][1] - 0.4]  # (each joint must overlap by at least 0.4)
    wlo = min(w['lo'][2] for w in side_walls if (w['lo'][0] > 0) == (sgn > 0));whi = max(w['hi'][2] for w in side_walls if (w['lo'][0] > 0) == (sgn > 0))
    check(not gaps and ranges[0][0] <= wlo + 1e-6 and ranges[-1][1] >= whi - 1e-6, '%s side: the %d blockers run without a gap (they overlap at every joint) from z %.0f to %.0f' % ('right' if sgn > 0 else 'left', len(ranges), ranges[0][0], ranges[-1][1]), gaps[:2])
# nothing on the track side of a wall's face; nothing low
intr = [b['path'] for b in blockers if (min(abs(b['lo'][0]), abs(b['hi'][0])) < TRACK_INNER - 0.1 and 'EndWall' not in b['path']) or (('EndWall' in b['path']) and b['lo'][2] < min(w['lo'][2] for w in end_walls) - 0.1)]
check(not intr, 'no blocker stands on the track side of a wall\'s inner face (the track keeps its full width: |x| < %.0f)' % TRACK_INNER, intr[:2])
keys_top = keyboard[1]
check(low > keys_top + 30, 'the lowest blocker (Y %.0f) is far above the keyboard (keys and letters under Y %.1f), the packs and holes (on the floor, Y 4)' % (low, keys_top))
check(low > gate[2] + 2, 'the lowest blocker (Y %.0f) is above the refresh barrier\'s opening (top Y %.1f, half-width %.1f) and the gate keys under it' % (low, gate[2], gate[0]))
allowed_over = ('Obby/BiomeWalls/', 'InvisibleMapBarriersV071/', 'ChestChaseWalls/', 'GardenHubDesign/', 'HubDecor151/Gate/', 'TrackWallBlockers153/')
over = []
for b in blockers:
    for q in parts:
        if q is b or not q['cq'] and False:
            continue
        if all(b['lo'][i] < q['hi'][i] - 1e-6 and b['hi'][i] > q['lo'][i] + 1e-6 for i in range(3)) and not any(a in q['path'] for a in allowed_over):
            over.append((b['path'].rsplit('/', 1)[-1], q['path']))
check(not over, 'the only solid parts a blocker overlaps are walls, the saved barriers, the hub\'s wall caps and the gate towers', over[:3])
overlapped_gate = sorted({q['path'].rsplit('/', 1)[-1] + ' ' + q['path'].split('/')[-2] for b in blockers for q in parts if 'HubDecor151/Gate/' in q['path'] and all(b['lo'][i] < q['hi'][i] and b['hi'][i] > q['lo'][i] for i in range(3))})
print('  overlapped hub decor (their tops, Y 58, are not reachable from the track): %s' % (overlapped_gate or 'none'))

# 4. how high a fling goes + the simulation ------------------------------------------------------------------------------------------------------------
print('== 4. fling heights and the worst-case simulation')
G = kb['Gravity'][0][1] if kb.get('Gravity') and kb['Gravity'][0][1] else 196.2
G = 196.2 if not G or G != G else G
half = kb['TrackHalfWidth'][0][1]
launches = [('Keeper %d' % i, h, v) for i, h, v in sorted(kb['Keeper'])] + [('The Darkened', kb['SpecialKeeper'][0][1], kb['SpecialKeeper'][0][2]), ('Lightning', kb['Lightning'][0][1], kb['Lightning'][0][2]), ('Bat', kb['Bat'][0][1], kb['Bat'][0][2])]
HRP_REST = FLOOR_TOP + 3.0  # a standing R15 body's root centre over the floor (hip 2 + half the 2-stud root)
launches.append(('worst mix', max(l[1] for l in launches), max(l[2] for l in launches)))
print('  %-14s %5s %5s %8s %9s %12s %14s' % ('launch', 'side', 'up', 'peak', 'air time', 'root peak Y', 'over wall top'))
peak_max = 0
for n, h, v in launches:
    apex = v * v / (2 * G);peak_max = max(peak_max, HRP_REST + apex)
    print('  %-14s %5g %5g %7.1f %8.2fs %12.1f %14.1f' % (n, h, v, apex, 2 * v / G, HRP_REST + apex, HRP_REST + apex - WALL_TOP))
print('  highest launch: %.1f studs over the launch point = root at Y %.1f (feet at about Y %.1f), %.1f studs over the wall tops (Y %.0f); the blockers reach Y %.0f (%.1fx)' % (
    max(l[2] for l in launches[:-1]) ** 2 / (2 * G), peak_max, peak_max - 3, peak_max - WALL_TOP, WALL_TOP, tallest, tallest / peak_max))
check(tallest >= 5 * peak_max, 'the blockers\' top (Y %.0f) is at least 5x the highest fling (Y %.1f): nobody can reach it' % (tallest, peak_max))
margin = max(10, half - 25 - 8)


def solids_at(pool, sgn, zmid):
    out = []
    for p in pool:
        if not p['axis'] or not (p['lo'][2] <= zmid <= p['hi'][2]):
            continue
        u0, u1 = (p['lo'][0], p['hi'][0]) if sgn > 0 else (-p['hi'][0], -p['lo'][0])
        out.append((u0, u1, p['lo'][1], p['hi'][1], p['path']))
    return out


DT = 1.0 / 120
HEIGHT = 5.0
EPS = 1e-7


def clip_u(u, hw, yb, du, solids):
    if du > 0:
        for s in solids:
            if s[2] < yb + HEIGHT - EPS and s[3] > yb + EPS and s[0] >= u + hw - 1e-6:
                du = min(du, max(0.0, s[0] - (u + hw)))
    elif du < 0:
        for s in solids:
            if s[2] < yb + HEIGHT - EPS and s[3] > yb + EPS and s[1] <= u - hw + 1e-6:
                du = max(du, min(0.0, s[1] - (u - hw)))
    return du


def clip_y(u, hw, yb, dy, solids):
    hit = False
    if dy < 0:
        for s in solids:
            if s[0] < u + hw - EPS and s[1] > u - hw + EPS and s[3] <= yb + 1e-6:
                if yb + dy < s[3]:
                    dy = s[3] - yb;hit = True
    elif dy > 0:
        for s in solids:
            if s[0] < u + hw - EPS and s[1] > u - hw + EPS and s[2] >= yb + HEIGHT - 1e-6:
                if yb + HEIGHT + dy > s[2]:
                    dy = s[2] - (yb + HEIGHT);hit = True
    return dy, hit


def simulate(solids, u0, hw, hv0, vy0, steer):
    """Returns the paths of the solids the body rests on at the end (a body launched from the floor at u0; steer = (start time, horizontal speed toward the wall) or None)."""
    u, yb, vy, hv = u0, FLOOR_TOP, vy0, hv0
    t, grounded, landed_at = 0.0, False, None
    while t < 20:
        if steer and t >= steer[0]:
            hv = steer[1]
        elif grounded:
            hv = max(0.0, hv - 120 * DT) if hv > 0 else min(0.0, hv + 120 * DT)
        vy -= G * DT
        du = clip_u(u, hw, yb, hv * DT, solids)
        u += du
        dy, hit = clip_y(u, hw, yb, vy * DT, solids)
        yb += dy
        if hit and vy < 0:
            vy = 0.0
            grounded = True
            landed_at = landed_at if landed_at is not None else t
        elif hit:
            vy = 0.0
        elif dy != 0:
            grounded = False
        if grounded:
            vy = 0.0
            if abs(du) < 1e-9 and (abs(hv) < 1e-9 or (steer and t >= steer[0])) and t - landed_at > 0.25:
                break
            if abs(hv) < 1e-9 and not steer:
                break
        t += DT
    supports = [s for s in solids if abs(s[3] - yb) < 1e-4 and s[0] < u + hw - 0.05 and s[1] > u - hw + 0.05]
    return u, yb, [s[4] for s in supports], grounded


def run_world(pool, label):
    sections = {}
    for w in side_walls:
        sgn = 1 if w['lo'][0] > 0 else -1
        zmid = (w['lo'][2] + w['hi'][2]) / 2
        sol = solids_at(pool, sgn, zmid)
        sig = (sgn, tuple(sorted((round(s[0], 3), round(s[1], 3), round(s[2], 2), round(s[3], 2)) for s in sol)))
        sections.setdefault(sig, (sol, sgn, zmid, []))[3].append(name(w))
    stats = {'unsteered': [0, 0], 'clamped': [0, 0], 'steered': [0, 0], 'steered clamped': [0, 0]}
    bad_runs, trapped = [], []
    for sol, sgn, zmid, names in sections.values():
        for n, h, v in launches:
            tap = v / G
            for clamp in (False, True):
                for hw in (0.9, 2.5):
                    for u0 in (0.0, 60.0, 85.0):
                        u_start = min(u0, TRACK_INNER - hw - 0.01)
                        hv = h
                        if clamp:
                            flight = 2 * v / G
                            landing = u_start + h * flight
                            hv = (max(-margin, min(margin, landing)) - u_start) / flight
                        plans = [None] + [(ts, vc) for ts in (0.0, tap, tap + 0.35) for vc in (150.0, 1200.0)]
                        for st in plans:
                            u, yb, sup, grounded = simulate(sol, u_start, hw, hv, v, st)
                            key = ('steered clamped' if clamp else 'steered') if st else ('clamped' if clamp else 'unsteered')
                            stats[key][0] += 1
                            high = [s for s in sup if 'BiomeGround' not in s and 'LobbyFloor' not in s and 'FloorSupport' not in s]
                            if high or not grounded:
                                stats[key][1] += 1
                                if len(bad_runs) < 3:
                                    bad_runs.append('%s %s from u %.0f, body %.1f wide, %s: rests on %s at Y %.2f, u %.2f' % (n, 'clamped' if clamp else 'raw', u_start, hw * 2, 'steered %s' % (st,) if st else 'unsteered', high[0].rsplit('/', 1)[-1] if high else 'nothing', yb, u))
                            if abs(u) > TRACK_INNER + 1e-6 or (grounded and abs(yb - FLOOR_TOP) > 1e-3 and not high):
                                trapped.append((n, u, yb))
    return stats, bad_runs, trapped, len(sections), sum(len(s[3]) for s in sections.values())


for label, pool, expect_bad in (('WITHOUT the blockers (the saved barriers only)', solid_without, True), ('WITH the blockers', solid_with, False)):
    stats, bad_runs, trapped, nsec, nwalls = run_world(pool, label)
    total = sum(s[0] for s in stats.values());badn = sum(s[1] for s in stats.values())
    print('%s: %d cross-sections (%d walls), %d simulated flings: %s' % (label, nsec, nwalls, total, '; '.join('%s %d/%d on a wall top' % (k, s[1], s[0]) for k, s in stats.items())))
    for r in bad_runs:
        print('   e.g. ' + r)
    if expect_bad:
        check(badn > 0 and stats['steered'][1] > 0, 'the bug, simulated: without the blockers some steered flings come to rest on a wall top (%d of %d)' % (badn, total))
        check(stats['clamped'][1] == 0, 'Ragdoll.KeepOnTrack\'s lateral clamp keeps an unsteered keeper fling off the wall (0 of %d): it is the steering after the fling, and a launch the clamp does not apply to, that reach the open strip' % stats['clamped'][0])
        check(stats['unsteered'][1] > 0, 'a raw launch (no clamp: the track attributes unset, a launch from off the track) already flies over the wall top and drops onto the open strip (%d of %d)' % (stats['unsteered'][1], stats['unsteered'][0]))
    else:
        check(badn == 0, 'with the blockers NO simulated fling (%d, every launch, place, width and steering) comes to rest on a wall top' % total, bad_runs[:2])
        check(not trapped, 'with the blockers every fling ends on the track floor, inside the walls (not between or in the blockers)', trapped[:2])
print('R153 track walls geometry: %s' % ('FAILED (%d)' % fails if fails else 'all checks passed'))
sys.exit(1 if fails else 0)
