"""Find floating / disconnected parts in the market (owner: "fix all dislocated or disconnected parts").
Usage: python3 check_market.py new.json [tolerance studs, default .04]
Reads a dump_market.luau scene. Parts become surface samples (blocks, balls, round part cylinders); two parts touch
when a sample of one lies inside the other (grown by the tolerance). Each showcase model (fruit, plant, pack) counts as
one piece. Everything must connect to the ground (bottom at the market's floor level) through touching parts.
Prints what doesn't and exits 1 if anything floats. The client-only Fruit of the Hour (group -1) floats on purpose."""
import json, sys, math, os
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../seeds_R133/preview'))
from check_floating import world_samples, inside, frame

def half_y(p):
    r, _ = frame(p); return float(np.abs(r[1]) @ np.array(p['size'])) / 2

if __name__ == '__main__':
    scene = json.load(open(sys.argv[1])); tol = float(sys.argv[2]) if len(sys.argv) > 2 else .04
    ground = scene['center'][1]
    parts = [p for p in scene['parts'] if p.get('group', 0) >= 0 and p['t'] < .99]
    n = len(parts); pts = [world_samples(p) for p in parts]
    centers = np.array([p['p'] for p in parts]); radii = np.array([np.linalg.norm(p['size']) / 2 for p in parts])
    parent = list(range(n))
    def find(i):
        while parent[i] != i: parent[i] = parent[parent[i]]; i = parent[i]
        return i
    def union(i, j): parent[find(i)] = find(j)
    groups = {}
    for i, p in enumerate(parts):
        if p.get('group', 0) > 0: groups.setdefault(p['group'], []).append(i)
    for members in groups.values():
        for i in members[1:]: union(i, members[0])
    for i in range(n):
        for j in range(i + 1, n):
            if np.linalg.norm(centers[i] - centers[j]) > radii[i] + radii[j] + tol: continue
            if find(i) == find(j): continue
            if inside(parts[j], pts[i], tol).any() or inside(parts[i], pts[j], tol).any(): union(i, j)
    rooted = {find(i) for i, p in enumerate(parts) if p['p'][1] - half_y(p) <= ground + tol}
    loose = {}
    for i, p in enumerate(parts):
        if find(i) not in rooted:
            key = ('showcase #%d' % p['group']) if p.get('group', 0) > 0 else p['name']
            loose[key] = loose.get(key, 0) + 1
    for k, v in sorted(loose.items()): print('FLOATING %-28s x%d' % (k, v))
    print('%d parts checked, %d floating groups' % (n, len(loose)))
    sys.exit(1 if loose else 0)
