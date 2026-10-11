"""Find floating / detached parts in seed models (owner: "make sure floating or dislocated parts in seeds are fixed").
Usage: python3 check_floating.py scene.json [tolerance studs, default .03]
Reads a dump_seeds.luau scene. Each part becomes surface samples (blocks, balls/ellipsoids, round part cylinders);
two parts touch when a sample of one lies inside the other (grown by the tolerance). Every part must connect to the
seed body (the 'Gradient' slices) through touching parts. Prints the parts that don't, per seed, and exits 1 if any."""
import json, sys, math
import numpy as np

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
        g = np.linspace(-.5, .5, 6)
        for a in g:
            for b in g:
                for face in (-.5, .5):
                    pts += [(face * sx, a * sy, b * sz), (a * sx, face * sy, b * sz), (a * sx, b * sy, face * sz)]
    return np.array(pts)

def frame(p):
    r = np.array(p['r']).reshape(3, 3); return r, np.array(p['p'])

def inside(p, world, tol):
    r, c = frame(p); local = (world - c) @ r  # world -> local (columns of r are the local axes)
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

def check(parts, tol):
    n = len(parts); pts = [world_samples(p) for p in parts]
    centers = np.array([p['p'] for p in parts]); radii = np.array([np.linalg.norm(p['size']) / 2 for p in parts])
    parent = list(range(n))
    def find(i):
        while parent[i] != i: parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for i in range(n):
        for j in range(i + 1, n):
            if np.linalg.norm(centers[i] - centers[j]) > radii[i] + radii[j] + tol: continue
            if find(i) == find(j): continue
            if inside(parts[j], pts[i], tol).any() or inside(parts[i], pts[j], tol).any():
                parent[find(i)] = find(j)
    body = {find(i) for i, p in enumerate(parts) if p['name'] == 'Gradient'}
    return [p for i, p in enumerate(parts) if find(i) not in body]

if __name__ == '__main__':
    scene = json.load(open(sys.argv[1])); tol = float(sys.argv[2]) if len(sys.argv) > 2 else .03
    by = {}
    for p in scene['parts']:
        if p['seed'] > 0: by.setdefault(p['seed'], []).append(p)
    names = {i + 1: l['text'] for i, l in enumerate(scene['labels'])}
    bad = 0
    for seed, parts in sorted(by.items()):
        loose = check(parts, tol)
        if loose:
            bad += 1; counts = {}
            for p in loose: counts[p['name']] = counts.get(p['name'], 0) + 1
            print('%-18s %s' % (names.get(seed, seed), ', '.join('%s x%d' % kv for kv in sorted(counts.items()))))
    print('%d of %d seeds have floating parts' % (bad, len(by)))
    sys.exit(1 if bad else 0)
