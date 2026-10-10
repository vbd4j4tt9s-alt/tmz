"""R151: geometry checks on every pack scene dump_packs.luau prints.
Usage: python3 check_packs.py <scenes.txt> [--tol .03] [--json out.json] [--quiet]

For each "SCENE {...}" line (one pack: parts in the root frame, divided by the pack's scale, zfight.py's part format):
  1. FLOATING (adapted from docs/proposals/seeds_R133/preview/check_floating.py, which the plant suites use): every part becomes surface samples;
     two parts touch when a sample of one lies inside the other grown by the tolerance (default .03 of a pack unit). A MeshPart is its Size box
     (the mesh's own surface lies inside the box; its vertices are an uploaded asset that is not available offline), so "touching" for a mesh is
     the most generous reading. Every part must connect to the pack's body (the template's main pouch, ApprovedMesh01; the Verity pack's face block)
     through touching parts. Prints the parts that do not, with their gap to the body in pack units; fails (exit 1) when there is one.
  2. POKING OUT: a part whose box reaches past the pack's Bounds (SeedPackVisuals.Bounds is what the carry layout, the platform and the picture
     framing use) - reported by test_packs.luau; here only the box of the whole pack is listed.
  3. Z-FIGHTING (docs/proposals/R149/tools/zfight.py on the same parts): coplanar / near / far findings between two visible faces that point the
     same way. Pairs where both parts are MeshParts compare two bounding boxes, not two surfaces, so they are listed apart and not counted.
  4. KNOWN near-tier layers (KNOWN below): the Void's haze / singularity discs and the Mech's stepped reactor / piston print sit .004 - .018 above
     each other (tier "near": inside the .02 band tools/zfight.py counts). They are shallow printed layers of owner-approved designs; flicker needs
     less than about .0003 stud at 50 studs (a 24-bit depth buffer without reversed Z: D^2 / (near x 2^24)), and a >= .02 spacing would thicken the print
     by about .04 stud and re-place every detail on top of it. They are listed per pack and not counted; any coplanar (<= .002) pair, any near pair
     outside these named layers and any "far" pair is. (R153: the Mech pack's look B stacks every layer .024+ apart: it is no longer on the list.)
Exit status 1 when a pack has a floating part or a counted (not known) z-fighting pair."""
import collections, json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402


def samples(p):
    sx, sy, sz = p['size']; shape = p['shape']; pts = []
    if shape == 'Ball':
        for i in range(1, 12):
            th = math.pi * i / 12
            for j in range(18):
                ph = 2 * math.pi * j / 18
                pts.append((sx / 2 * math.sin(th) * math.cos(ph), sy / 2 * math.cos(th), sz / 2 * math.sin(th) * math.sin(ph)))
        pts += [(0, sy / 2, 0), (0, -sy / 2, 0)]
    elif shape == 'Cylinder':
        r = min(sy, sz) / 2
        for i in range(7):
            x = -sx / 2 + sx * i / 6
            for j in range(16):
                a = 2 * math.pi * j / 16; pts.append((x, r * math.cos(a), r * math.sin(a)))
    else:
        g = np.linspace(-.5, .5, 7)
        for a in g:
            for b in g:
                for face in (-.5, .5):
                    pts += [(face * sx, a * sy, b * sz), (a * sx, face * sy, b * sz), (a * sx, b * sy, face * sz)]
    return np.array(pts)


def frame(p):
    return np.array(p['r']).reshape(3, 3), np.array(p['p'])


def inside(p, world, tol):
    r, c = frame(p); local = (world - c) @ r
    sx, sy, sz = p['size']; shape = p['shape']
    if shape == 'Ball':
        a = np.array([sx / 2 + tol, sy / 2 + tol, sz / 2 + tol])
        return ((local / a) ** 2).sum(axis=1) <= 1
    if shape == 'Cylinder':
        rr = min(sy, sz) / 2 + tol
        return (np.abs(local[:, 0]) <= sx / 2 + tol) & (local[:, 1] ** 2 + local[:, 2] ** 2 <= rr * rr)
    h = np.array([sx / 2 + tol, sy / 2 + tol, sz / 2 + tol])
    return (np.abs(local) <= h).all(axis=1)


def world_samples(p):
    r, c = frame(p); return samples(p) @ r.T + c


def body_index(parts):
    for i, p in enumerate(parts):
        if p['name'] == 'ApprovedMesh01':
            return i
    return max(range(len(parts)), key=lambda i: parts[i]['size'][0] * parts[i]['size'][1] * parts[i]['size'][2])


def gap_to(part, others, tol_samples=None):
    """Smallest distance (pack units) from part's surface samples to any of `others` (boxes / balls / cylinders as `inside` knows them)."""
    pts = world_samples(part)
    best = 9.0
    for o in others:
        lo, hi = 0.0, 3.0
        for _ in range(14):  # bisect the grow distance at which a sample of part lies inside o
            mid = (lo + hi) / 2
            if inside(o, pts, mid).any():
                hi = mid
            else:
                lo = mid
        best = min(best, hi)
    return best


def floating(parts, tol):
    """Returns (loose parts, their gaps). The body is the template's main pouch; invisible parts (transparency >= .95) do not count."""
    n = len(parts); pts = [world_samples(p) for p in parts]
    centers = np.array([p['p'] for p in parts]); radii = np.array([np.linalg.norm(p['size']) / 2 for p in parts])
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for i in range(n):
        for j in range(i + 1, n):
            if np.linalg.norm(centers[i] - centers[j]) > radii[i] + radii[j] + tol:
                continue
            if find(i) == find(j):
                continue
            if inside(parts[j], pts[i], tol).any() or inside(parts[i], pts[j], tol).any():
                parent[find(i)] = find(j)
    body = find(body_index(parts))
    loose = [i for i in range(n) if find(i) != body]
    out = []
    for i in loose:
        out.append((i, gap_to(parts[i], [parts[j] for j in range(n) if find(j) == body])))
    return out


def zfight(parts):
    """(counted findings with a non-mesh part, mesh-vs-mesh findings), zfight.py's tiers coplanar / near / far."""
    zp = []
    for i, d in enumerate(parts):
        d = dict(d)
        if d.get('t', 0) >= 0.98:
            continue
        try:
            zp.append(Z.Part(i, d))
        except Exception:  # noqa
            pass
    fs = Z.detect(zp, 0.6)
    byi = {p.i: p for p in zp}
    counted, mesh = [], []
    for f in fs:
        if f['same_look'] or f['tier'] not in Z.COUNTED:
            continue
        a, b = byi[f['a']], byi[f['b']]
        if f['mesh'] and (a.src['class'] == 'MeshPart') and (b.src['class'] == 'MeshPart'):
            mesh.append(f)
        else:
            counted.append(f)
    return counted, mesh


KNOWN = [  # (pack label regex, part name regex, why)
    (r'^Void$', r'^(VoidNebula|VoidSingularity)', 'translucent haze discs + the opaque singularity, .004 - .018 apart'),
]


def known(label, f):
    import re
    a, b = f['pathA'].rsplit('/', 1)[-1], f['pathB'].rsplit('/', 1)[-1]
    if f['tier'] != 'near':
        return False
    return any(re.search(l, label) and re.search(n, a) and re.search(n, b) for l, n, _ in KNOWN)


def check_scene(scene, tol=.03):
    parts = [p for p in scene['parts'] if p.get('t', 0) < .95]
    loose = floating(parts, tol)
    counted, mesh = zfight(parts)
    kn = [f for f in counted if known(scene['label'], f)]
    counted = [f for f in counted if not known(scene['label'], f)]
    scene['known'] = kn
    return parts, loose, counted, mesh


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    tol = float(sys.argv[sys.argv.index('--tol') + 1]) if '--tol' in sys.argv else .03
    quiet = '--quiet' in sys.argv
    if '--tol' in sys.argv:
        args.remove(sys.argv[sys.argv.index('--tol') + 1])
    scenes = []
    for line in open(args[0], encoding='utf-8'):
        if line.startswith('SCENE '):
            scenes.append(json.loads(line[6:]))
    bad_float = bad_z = 0
    results = []
    tot_parts = tot_mesh = tot_known = 0
    for sc in scenes:
        parts, loose, counted, mesh = check_scene(sc, tol)
        tot_parts += len(parts); tot_mesh += len(mesh); tot_known += len(sc.get('known', []))
        results.append({'label': sc['label'], 'parts': len(parts), 'loose': [{'name': parts[i]['name'], 'gap': round(g, 4)} for i, g in loose],
                        'zfight': [{'a': f['pathA'], 'b': f['pathB'], 'tier': f['tier'], 'off': f['offset']} for f in counted], 'mesh_pairs': len(mesh),
                        'known_near': len(sc.get('known', []))})
        if loose:
            bad_float += 1
            if not quiet:
                print('FLOATING %-12s %s' % (sc['label'], ', '.join('%s (gap %.3f)' % (parts[i]['name'], g) for i, g in loose)))
        if counted:
            bad_z += 1
            if not quiet:
                for f in counted[:6]:
                    print('ZFIGHT   %-12s %-8s off %+.4f  %s.%s <-> %s.%s' % (sc['label'], f['tier'], f['offset'], f['pathA'].rsplit('/', 1)[-1], f['faceA'], f['pathB'].rsplit('/', 1)[-1], f['faceB']))
    print('%d packs, %d parts: %d with a floating part, %d with z-fighting (not counted: %d mesh-box pairs, %d known near-tier print layers on the Void / Mech)' % (
        len(scenes), tot_parts, bad_float, bad_z, tot_mesh, tot_known))
    if '--json' in sys.argv:
        json.dump(results, open(sys.argv[sys.argv.index('--json') + 1], 'w'), indent=1)
    sys.exit(1 if bad_float or bad_z else 0)


if __name__ == '__main__':
    main()
