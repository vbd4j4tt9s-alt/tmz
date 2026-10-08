"""R154 hub z-fighting: every pair of the hub, before and after, as one table (docs/proposals/R154/hub_pairs.tsv).
Usage: python3 make_pair_list.py <before pairs.json> <after pairs.json> <out.tsv>
The pairs.json files are check_hub_zfight154.py --json of the R153 src (before) and of this checkout (after), on the same scenes of the owner's place.
One row per pair of faces in the hub (both scenes: the hub, and the hub in a blizzard at three spots), worst first: the visible ones (by score), then the
tight ones, then the depth-safe ones, then the untextured look-alikes. "after" says what became of it: fixed (gone, or now apart by the depth rule),
the same, or new (a pair that only exists after, e.g. a grass disc now on its own plane over its neighbour)."""
import csv, json, sys

before, after, out = sys.argv[1:4]
B, A = json.load(open(before)), json.load(open(after))


def key(r):
    return (r['a'], r['faceA'], r['b'], r['faceB'], round(r['at'][0], 1), round(r['at'][2], 1))


def status(r):
    if r['visible']:
        return 'ALLOWED' if r['allowed'] else 'VISIBLE'
    if r['tight']:
        return 'tight'
    return 'look-alike (untextured)' if r['kind'] == 'plain' else 'depth-safe'


ORDER = {'VISIBLE': 0, 'ALLOWED': 1, 'tight': 2, 'depth-safe': 3, 'look-alike (untextured)': 4}
amap = {}
for r in A:
    amap.setdefault(key(r), []).append(r)
rows = []
for r in B:
    m = amap.get(key(r))
    if m:
        a = m.pop(0)
        res = 'same' if status(a) == status(r) and abs(a['offset'] - r['offset']) < 1e-4 else 'now %s (%+.3f)' % (status(a), a['offset'])
    else:
        res = 'fixed: gone' if r['visible'] and not r['allowed'] else 'gone'
    if status(r) == 'VISIBLE' and m is not None and res.startswith('now'):
        res = 'fixed: ' + res
    rows.append((r, status(r), res))
for lst in amap.values():
    for a in lst:
        rows.append((a, 'new after', 'new: %s (%+.3f)' % (status(a), a['offset'])))
rows.sort(key=lambda t: (ORDER.get(t[1], 5), -t[0]['score'], -t[0]['area']))
with open(out, 'w', newline='', encoding='utf-8') as fh:
    w = csv.writer(fh, delimiter='\t', lineterminator='\n')
    w.writerow(['rank', 'before (R153)', 'after (R154)', 'kind', 'tier', 'offset', 'needs', 'area stud2', 'score', 'where', 'x', 'y', 'z', 'part A . face', 'part B . face',
                'made by', 'material A / B', 'allowed because'])
    for i, (r, st, res) in enumerate(rows, 1):
        w.writerow([i, st, res, r['kind'], r['tier'], '%+.4f' % r['offset'], '%.3f' % r['limit'], '%.2f' % r['area'], '%.2f' % r['score'], r['where'],
                    '%.1f' % r['at'][0], '%.2f' % r['at'][1], '%.1f' % r['at'][2], r['a'] + ' . ' + r['faceA'], r['b'] + ' . ' + r['faceB'], r['origin'],
                    '%s / %s' % (r['matA'], r['matB']), r['allowed'] or ''])
print('wrote %s: %d pairs' % (out, len(rows)))
