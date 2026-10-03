"""How well does each fruit stand on a shelf? Usage: python3 fruit_stand.py fruits.json
Per fruit (visible parts only): pieces = separate clusters (loose berries = many), main = share of the volume in the
biggest cluster, base = width of what touches the bottom 15% compared with the fruit's widest point, and a verdict."""
import json, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_floating import world_samples, inside
scene = json.load(open(sys.argv[1])); tol = .03
by = {}
for p in scene['parts']: by.setdefault(p['seed'], []).append(p)
rows = []
for seed, parts in sorted(by.items()):
    n = len(parts); pts = [world_samples(p) for p in parts]
    parent = list(range(n))
    def find(i):
        while parent[i] != i: parent[i] = parent[parent[i]]; i = parent[i]
        return i
    for i in range(n):
        for j in range(i + 1, n):
            if find(i) != find(j) and (inside(parts[j], pts[i], tol).any() or inside(parts[i], pts[j], tol).any()): parent[find(i)] = find(j)
    vol = {}
    for i, p in enumerate(parts): vol[find(i)] = vol.get(find(i), 0) + float(np.prod(p['size']))
    total = sum(vol.values()); main = max(vol.values()) / total
    allp = np.vstack(pts); lo, hi = allp.min(axis=0), allp.max(axis=0); h = hi[1] - lo[1]
    low = allp[allp[:, 1] <= lo[1] + .15 * h]
    width = max(hi[0] - lo[0], hi[2] - lo[2]); base = max(np.ptp(low[:, 0]), np.ptp(low[:, 2])) / width if width > 0 else 0
    clusters = sum(1 for v in vol.values() if v / total > .02)
    ok = clusters <= 2 and main >= .85 and base >= .35
    rows.append((scene['labels'][seed - 1]['text'], clusters, main, base, ok))
for name, c, m, b, ok in rows:
    print('%-18s pieces %2d  main %3.0f%%  base %3.0f%%  %s' % (name, c, m * 100, b * 100, 'STANDS' if ok else '-'))
