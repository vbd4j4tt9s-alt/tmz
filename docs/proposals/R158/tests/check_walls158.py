"""R158 walls: the checks on the BUILT data (dump_specs158.luau prints TrackWallSpecs158's lists; TrackWalls158 builds exactly these parts).

Usage: python3 check_walls158.py <specs.txt> [<specs_again.txt>]      exits 1 when a rule is broken.
 1. counts      - parts per biome (both walls) never above the design's numbers (docs/proposals/R158/design/design.md), and exactly the numbers locked in EXPECT (the data has fixed seeds:
                  a change of the generator shows up here on purpose); the lite set is the full set without the "bay" extras.
 2. placement   - every part: how far it stands into the track (3.2 studs below Y 12, 4.5 up to Y 45, 6 on the wall top), at most 1 stud past the outer face, nothing under Y 5.25 inside the
                  keys' reach (|x| < 89.75), nothing in the gatehouse (z -104.5 .. -95.5 over Y 44), the Desert walkway (z 972 .. 1038, LEFT wall) only flat bands (under 0.7 proud) below Y 30,
                  nothing in the R157 pyramid's footprint (x -84.47 .. -39.67, z 982.6 .. 1027.4) or the walkway's 4.5 studs, nothing at all inside the track's walkable width (|x| < 83) except
                  the 6-stud wall-top crystals above Y 51, ground slabs only outside the walls (|x| >= 94) and off the hub (z >= -99), the base caps only on the wall tops.
 3. shadows     - only parts 20+ studs long are shadow casters (Shadow is false on every other part), the ground casts none.
 4. variety     - NOT REPEATED: no run of 5 posts / pillars / teeth in a row with the same size (the same Name along one wall), per Name the heights / sizes vary, neighbouring parts of one name
                  are not evenly spaced (spacing spread > 30 %); the base caps use at least 3 close shades.
 5. determinism - the second dump equals the first (a fixed seed per wall, no run-time randomness).
 6. floating    - every Snow icicle touches the cap it hangs from.
 7. no drips    - no Lava wall part is named like a drip (owner: gone), the rest of the Lava wall design is there.
 8. no round    - no wall part is a Ball, carries a sphere mesh or is named like a ball / blob / leaf crown / drip (owner: "remove those leaf balls, don't have plain balls").
Prints the high-part list (over the refresh cover's roof or past its sides, inside |x| 95) and the shadow-caster numbers for design.md."""
import collections, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'design'))
import make158 as M  # noqa: E402  (corners / load_specs: the design's own helpers)

DESIGN = {'Forest': 306, 'Jungle': 250, 'Desert': 197, 'Snow': 236, 'Lava': 228, 'Crystal': 238, 'Storm Peaks': 256, 'Borders': 36, 'Walls': 1747, 'Lite': 1206, 'Ground': 15, 'BaseA': 261}
# The numbers this data builds (fixed seeds): lock them so a change of the generator is a visible, deliberate edit.
EXPECT = {'Forest': 238, 'Jungle': 159, 'Desert': 140, 'Snow': 142, 'Lava': 190, 'Crystal': 180, 'Storm Peaks': 225, 'Borders': 36, 'Walls': 1310, 'Lite': 1020}
IN, OUT = 89.0, 94.0


def counts(S):
    c = collections.Counter()
    for s in S['specs']['walls']:
        g = s['Group'].split('/')[1]
        c['Borders' if g.startswith('Border') else g] += 1
    return c


def check_counts(S, bad):
    c = counts(S)
    walls = S['specs']['walls']
    lite = S['specs']['walls_lite']
    print('parts: ' + ', '.join('%s %d' % (k, c[k]) for k in ('Forest', 'Jungle', 'Desert', 'Snow', 'Lava', 'Crystal', 'Storm Peaks', 'Borders')) +
          '; walls %d (lite %d), ground %d, base A %d' % (len(walls), len(lite), len(S['specs']['backdrops']), len(S['specs']['baseA'])))
    for k in ('Forest', 'Jungle', 'Desert', 'Snow', 'Lava', 'Crystal', 'Storm Peaks', 'Borders'):
        if c[k] > DESIGN[k]:
            bad.append('%s has %d parts, the design says %d at most' % (k, c[k], DESIGN[k]))
    if len(walls) > DESIGN['Walls']:
        bad.append('walls %d > design %d' % (len(walls), DESIGN['Walls']))
    if len(lite) > DESIGN['Lite'] or len(lite) >= len(walls):
        bad.append('the lite set is %d (design %d, full %d)' % (len(lite), DESIGN['Lite'], len(walls)))
    if any(s.get('Bay') for s in lite):
        bad.append('a "bay" extra is in the lite set')
    if len(S['specs']['backdrops']) != DESIGN['Ground']:
        bad.append('the ground has %d slabs, the design has %d' % (len(S['specs']['backdrops']), DESIGN['Ground']))
    if any(s['Name'] != 'Outer ground' for s in S['specs']['backdrops']):
        bad.append('the outer track data holds something other than ground slabs (the backdrop objects are the owner\'s models now)')
    if len(S['specs']['baseA']) != DESIGN['BaseA']:
        bad.append('base A has %d parts, the design has %d' % (len(S['specs']['baseA']), DESIGN['BaseA']))
    for k, v in EXPECT.items():
        got = c[k] if k in c else {'Walls': len(walls), 'Lite': len(lite)}.get(k)
        if got != v:
            bad.append('%s builds %d parts, the locked number is %d' % (k, got, v))
    return c


def check_placement(S, bad):
    n = 0
    high = []
    for s in S['specs']['walls']:
        P = M.corners(s)
        xs = [abs(p[0]) for p in P]
        ys = [p[1] for p in P]
        zs = [p[2] for p in P]
        tag = s['Group'] + '/' + s['Name']
        end = min(zs) > 5975  # the end wall's own pieces
        reach = 3.2 if min(ys) < 12 else 4.5 if min(ys) < 45 else 6
        if not end and min(xs) < IN - reach:
            bad.append('%s reaches %.2f into the track (more than %.1f at Y %.1f)' % (tag, IN - min(xs), reach, min(ys)))
        if not end and max(xs) > OUT + 1.0:
            bad.append('%s reaches past the outer face by %.2f' % (tag, max(xs) - OUT))
        if min(xs) < 89.75 and min(ys) < 5.25 and not end:
            bad.append('%s goes down to Y %.2f inside the keys\' reach' % (tag, min(ys)))
        if min(zs) < -95.5 and max(ys) > 44:
            bad.append('%s at z %.1f meets the gatehouse' % (tag, min(zs)))
        left = min(p[0] for p in P) < 0
        if left and max(zs) > 972 and min(zs) < 1038 and min(xs) < IN - .7 and min(ys) < 30:
            bad.append('%s stands %.2f proud on the Desert walkway (z %.0f)' % (tag, IN - min(xs), min(zs)))
        if not end and min(xs) < 83 and not (min(ys) > 50.9 and s['Name'] in ('Crystal', 'Wall crystal')):
            bad.append('%s is inside the walkable width (|x| %.1f)' % (tag, min(xs)))
        # the R157 pyramid (x -84.47 .. -39.67): nothing of the walls comes near its footprint
        if min(p[0] for p in P) > -88 and max(p[0] for p in P) < 0 and max(zs) > 982.6 and min(zs) < 1027.4:
            bad.append('%s is over the pyramid\'s footprint' % tag)
        if end and (max(abs(p[0]) for p in P) > IN or min(p[2] for p in P) < 5975.5 - 2):
            bad.append('%s (end wall) is out of its wall' % tag)
        # inside the refresh cover's footprint, over its roof (Y 55) or past its sides (|x| 94)
        if (max(ys) > 55 or max(xs) > 94 + 1e-6) and max(xs) <= 95 and min(zs) > -100:
            high.append(s)
        n += 1
    for s in S['specs']['backdrops']:
        P = M.corners(s)
        tag = s['Group'] + '/' + s['Name']
        if min(abs(p[0]) for p in P) < OUT - 1e-6 and min(p[2] for p in P) < 5985:
            bad.append('%s comes inside the walls' % tag)
        if min(p[2] for p in P) < -99 - 1e-6:
            bad.append('%s reaches over the hub' % tag)
        if max(p[1] for p in P) > 3.6 + 1e-6:
            bad.append('%s is above the ground (Y %.2f)' % (tag, max(p[1] for p in P)))
        if max(s['Size']) > 2048:
            bad.append('%s is %.0f long (a part may not exceed 2048)' % (tag, max(s['Size'])))
        n += 1
    gate_x, gate_z = 96, (-105.5, -94.5)
    for s in S['specs']['baseA']:
        P = M.corners(s)
        tag = s['Group'] + '/' + s['Name']
        if min(p[1] for p in P) < 42 or max(abs(p[0]) for p in P) > 341 or min(p[2] for p in P) < -624 or max(p[2] for p in P) > -91:
            bad.append('base A: %s leaves the wall tops' % tag)
        # nothing inside the gatehouse's solid (wall z -104.5 .. -95.5 + cornice -105.5 .. -94.5, Y 44 .. 59.3, between the towers): caps stand on the merlons, above it
        if max(abs(p[0]) for p in P) < gate_x and min(p[2] for p in P) < gate_z[1] and max(p[2] for p in P) > gate_z[0] and min(p[1] for p in P) < 59.3 - 1e-6 and max(p[1] for p in P) > 44:
            bad.append('base A: %s is inside the gatehouse (Y %.2f .. %.2f)' % (tag, min(p[1] for p in P), max(p[1] for p in P)))
        n += 1
    print('placement rules: %d parts checked' % n)
    return high


def check_floating(S, bad):
    """Nothing floats (code review of the walls build): every Snow icicle hangs from the cap (its top at the cap's underside, Y 50.2) with its wall side under the cap's inner face
    (1.5 studs proud: |x| 87.5), so the two touch."""
    ic = 0
    for s in S['specs']['walls']:
        if s['Name'] == 'Icicle':
            ic += 1
            P = M.corners(s)
            if abs(max(p[1] for p in P) - 50.2) > 1e-3 or max(abs(p[0]) for p in P) <= IN - 1.5 + 0.02:
                bad.append('Snow icicle at z %.1f hangs free of the cap: top Y %.2f, wall side at |x| %.2f (the cap\'s inner face is |x| %.1f)' % (s['CF'][2], max(p[1] for p in P), max(abs(p[0]) for p in P), IN - 1.5))
    if not ic:
        bad.append('no icicles in the data')
    print('floating: %d icicles touch the snow cap' % ic)


def check_no_round(S, bad):
    """Owner: "remove those leaf balls, don't have plain balls or anything that might reduce the look of the walls": no part of any wall (track walls, lite set, base caps, ground) is a Ball,
    carries a sphere mesh (an egg / blob) or is named like a ball / blob / leaf / crown / tuft / overgrowth / rubble / pillow / mound / drip / egg / sphere."""
    import re
    word = re.compile(r'ball|blob|leaf|leaves|crown|tuft|overgrowth|rubble|pillow|mound|drip|egg|sphere', re.I)
    n = 0
    for name, lst in S['specs'].items():
        for s in lst:
            n += 1
            if s['Shape'] == 'Ball':
                bad.append('%s: %s/%s is a Ball' % (name, s['Group'], s['Name']))
            if s.get('Mesh') == 'Sphere':
                bad.append('%s: %s/%s carries a sphere mesh' % (name, s['Group'], s['Name']))
            if word.search(s['Name']):
                bad.append('%s: %s/%s is named like a ball / blob / leaf / drip' % (name, s['Group'], s['Name']))
    print('round pieces: none in %d parts (no Ball, no sphere mesh, no ball / blob / leaf / drip name)' % n)


def check_no_drips(S, bad):
    """Owner: the Lava walls' Neon "Lava drip" pieces under the wall top are gone for good: no Lava wall part (full or lite set) is named like a drip, and the rest of the Lava design is still there."""
    names = collections.Counter()
    for lst in (S['specs']['walls'], S['specs']['walls_lite']):
        for s in lst:
            if s['Group'] == 'TrackWalls158/Lava':
                names[s['Name']] += 1
                if 'drip' in s['Name'].lower():
                    bad.append('Lava wall part %s at z %.1f is a drip (the owner removed them)' % (s['Name'], s['CF'][2]))
    for need in ('Basalt foot', 'Ember seam', 'Under glow', 'Basalt top', 'Rock tooth', 'Basalt column', 'Glowing crack'):
        if not names[need]:
            bad.append('the Lava wall lost its %s' % need)
    print('lava wall: no drips; parts by name: %s' % ', '.join('%s %d' % kv for kv in sorted(names.items())))


def faces(s):
    """The six faces of a box part: (outward normal, a point on it, the 4 corners)."""
    c = s['CF']
    R = [[c[3], c[4], c[5]], [c[6], c[7], c[8]], [c[9], c[10], c[11]]]
    h = [v / 2 for v in s['Size']]
    ctr = [c[0], c[1], c[2]]
    out = []
    for ax in range(3):
        col = [R[i][ax] for i in range(3)]
        o1, o2 = [a for a in range(3) if a != ax]
        c1 = [R[i][o1] for i in range(3)]
        c2 = [R[i][o2] for i in range(3)]
        for sg in (-1, 1):
            n = [sg * v for v in col]
            pt = [ctr[i] + n[i] * h[ax] for i in range(3)]
            quad = [[pt[i] + a * h[o1] * c1[i] + b * h[o2] * c2[i] for i in range(3)] for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
            out.append((n, pt, quad))
    return out


def clip_area(a, b):
    """Area of the overlap of two convex polygons (lists of (x, y), either winding)."""
    def area(P):
        return sum(P[i][0] * P[(i + 1) % len(P)][1] - P[(i + 1) % len(P)][0] * P[i][1] for i in range(len(P))) / 2
    if area(a) < 0:
        a = a[::-1]
    if area(b) < 0:
        b = b[::-1]
    out = a
    for i in range(len(b)):
        if not out:
            return 0.0
        p1, p2 = b[i], b[(i + 1) % len(b)]
        def inside(q):
            return (p2[0] - p1[0]) * (q[1] - p1[1]) - (p2[1] - p1[1]) * (q[0] - p1[0]) >= -1e-12
        def cross(q1, q2):
            d1 = (p2[0] - p1[0]) * (q1[1] - p1[1]) - (p2[1] - p1[1]) * (q1[0] - p1[0])
            d2 = (p2[0] - p1[0]) * (q2[1] - p1[1]) - (p2[1] - p1[1]) * (q2[0] - p1[0])
            t = d1 / (d1 - d2)
            return (q1[0] + t * (q2[0] - q1[0]), q1[1] + t * (q2[1] - q1[1]))
        inp, out = out, []
        for j in range(len(inp)):
            cur, prv = inp[j], inp[j - 1]
            if inside(cur):
                if not inside(prv):
                    out.append(cross(prv, cur))
                out.append(cur)
            elif inside(prv):
                out.append(cross(prv, cur))
    return abs(area(out)) if len(out) >= 3 else 0.0


def check_planes(S, bad):
    """R154 (strict hub mode): the base walls stand in the hub, where two faces that look the same and lie in one plane flicker (a textured material lays its texture out from each part's own position).
    So no two base wall parts may have faces that point the same way, lie less than 0.02 studs apart (in one plane) and overlap in area."""
    parts = S['specs']['baseA']
    F = [faces(s) for s in parts]
    boxes = []
    for s in parts:
        P = M.corners(s)
        boxes.append([(min(p[i] for p in P) - .03, max(p[i] for p in P) + .03) for i in range(3)])
    n = pairs = 0
    for i in range(len(parts)):
        for j in range(i + 1, len(parts)):
            if any(boxes[i][k][1] < boxes[j][k][0] or boxes[j][k][1] < boxes[i][k][0] for k in range(3)):
                continue
            pairs += 1
            for n1, p1, q1 in F[i]:
                for n2, p2, q2 in F[j]:
                    if sum(a * b for a, b in zip(n1, n2)) < .9995:
                        continue
                    if abs(sum(n1[k] * (p2[k] - p1[k]) for k in range(3))) >= .02:
                        continue
                    # plane basis from n1
                    t = [1, 0, 0] if abs(n1[0]) < .9 else [0, 1, 0]
                    u = [n1[1] * t[2] - n1[2] * t[1], n1[2] * t[0] - n1[0] * t[2], n1[0] * t[1] - n1[1] * t[0]]
                    ul = math.sqrt(sum(v * v for v in u))
                    u = [v / ul for v in u]
                    w = [n1[1] * u[2] - n1[2] * u[1], n1[2] * u[0] - n1[0] * u[2], n1[0] * u[1] - n1[1] * u[0]]
                    f = lambda q: [(sum(pt[k] * u[k] for k in range(3)), sum(pt[k] * w[k] for k in range(3))) for pt in q]
                    a = clip_area(f(q1), f(q2))
                    if a > 1e-3:
                        bad.append('base A: %s and %s have faces in one plane (%.3f studs apart) that overlap by %.2f square studs near (%.1f, %.1f, %.1f)' % (
                            parts[i]['Name'], parts[j]['Name'], abs(sum(n1[k] * (p2[k] - p1[k]) for k in range(3))), a, p1[0], p1[1], p1[2]))
                    n += 1
    print('base wall planes: %d near pairs, no two same-facing faces share a plane and overlap (R154 strict hub mode)' % pairs)


def check_shadows(S, bad):
    for name, lst in S['specs'].items():
        casters = [s for s in lst if s.get('Shadow') is not False]
        small = [s for s in casters if max(s['Size']) < 20]
        big_off = [s for s in lst if s.get('Shadow') is False and max(s['Size']) >= 20 and name not in ('backdrops',)]
        if small:
            bad.append('%s: %d part(s) under 20 studs cast a shadow (first: %s)' % (name, len(small), small[0]['Name']))
        if name == 'backdrops' and casters:
            bad.append('the ground casts a shadow')
        if name in ('walls', 'baseA'):
            print('shadows %s: %d casters of %d parts (%d parts of 20+ studs without one: %d)' % (name, len(casters), len(lst), len(big_off), len(big_off)))


def check_variety(S, bad):
    """Not repeated: along one wall, the posts / pillars / teeth of one name must not be one copy repeated."""
    by = collections.defaultdict(list)
    for s in S['specs']['walls']:
        g = s['Group']
        if g.startswith('TrackWalls158/Border'):
            continue
        side = -1 if s['CF'][0] < 0 else 1
        by[(g, s['Name'], side)].append(s)
    worst = []
    judged = 0
    for (g, name, side), lst in sorted(by.items()):
        if len(lst) < 8:
            continue
        # a run of identical-size neighbours in z order
        lst = sorted(lst, key=lambda s: s['CF'][2])
        sizes = [tuple(round(v, 2) for v in s['Size']) for s in lst]
        run = best = 1
        for i in range(1, len(sizes)):
            run = run + 1 if sizes[i] == sizes[i - 1] else 1
            best = max(best, run)
        zs = [s['CF'][2] for s in lst]
        gaps = [zs[i + 1] - zs[i] for i in range(len(zs) - 1) if zs[i + 1] - zs[i] > 0.01]
        judged += 1
        if best >= 5:
            bad.append('%s %s (side %d): %d neighbours in a row have the same size' % (g, name, side, best))
        # runs of one band are allowed to be even (they are cut in lengths), details are not
        if len(gaps) >= 8 and name not in ('Sandstone foot', 'Painted band', 'Stone foot', 'Basalt foot', 'Slate foot', 'Ice band', 'Glyph band', 'Top step', 'Temple top', 'Snow drift', 'Moss bank', 'Log rail', 'Ember seam', 'Under glow', 'Glow line', 'Log', 'Log tip', 'Snow pillow'):
            mean = sum(gaps) / len(gaps)
            sd = math.sqrt(sum((x - mean) ** 2 for x in gaps) / len(gaps))
            if sd / mean < 0.2:
                worst.append((sd / mean, g, name, side))
    for cv, g, name, side in sorted(worst)[:5]:
        bad.append('%s %s (side %d): spacing is nearly even (spread %.0f %%)' % (g, name, side, 100 * cv))
    # logs: heights and thicknesses vary, the first / second half do not repeat each other
    for side in (-1, 1):
        logs = sorted([s for s in S['specs']['walls'] if s['Name'] == 'Log' and (s['CF'][0] < 0) == (side < 0)], key=lambda s: s['CF'][2])
        tops = [round(s['CF'][1] + s['Size'][0] / 2, 1) for s in logs]
        ds = sorted(set(round(s['Size'][1], 2) for s in logs))
        mt = sum(tops) / len(tops)
        sd_top = math.sqrt(sum((t - mt) ** 2 for t in tops) / len(tops))
        th = [s['Size'][1] for s in logs]
        mh = sum(th) / len(th)
        sd_th = math.sqrt(sum((t - mh) ** 2 for t in th) / len(th))
        run = best = 1
        for i in range(1, len(tops)):
            run = run + 1 if tops[i] == tops[i - 1] else 1
            best = max(best, run)
        if sd_top < 1.0 or sd_th < 0.25 or best > 2:
            bad.append('Forest logs (side %d) repeat: top spread %.2f, thickness spread %.2f, %d equal tops in a row (%d logs)' % (side, sd_top, sd_th, best, len(logs)))
    shades = set(tuple(s['Color']) for s in S['specs']['baseA'] if s['Name'] == 'Merlon cap')
    if len(shades) < 3:
        bad.append('the base caps use only %d shade(s)' % len(shades))
    for a in shades:
        for b in shades:
            if max(abs(a[i] - b[i]) for i in range(3)) > 12:
                bad.append('two cap shades are not close: %s %s' % (a, b))
    print('variety: %d part groups judged; base caps in %d close shades' % (judged, len(shades)))


def main():
    S = M.load_specs(sys.argv[1])
    bad = []
    c = check_counts(S, bad)
    high = check_placement(S, bad)
    check_shadows(S, bad)
    check_planes(S, bad)
    check_floating(S, bad)
    check_no_drips(S, bad)
    check_no_round(S, bad)
    check_variety(S, bad)
    print('parts reaching over the refresh cover (above Y 55 or past |x| 94, inside |x| 95): %d of %d' % (len(high), len(S['specs']['walls'])))
    if len(sys.argv) > 2:
        if open(sys.argv[1], 'rb').read() != open(sys.argv[2], 'rb').read():
            bad.append('the second dump differs from the first (the data must be fixed-seed)')
        else:
            print('determinism: the second dump is byte-identical')
    for b, n in collections.Counter(bad).most_common(40):
        print('  RULE x%d %s' % (n, b))
    print('R158 walls data checks: %s' % ('PASS' if not bad else 'FAIL (%d)' % len(bad)))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
