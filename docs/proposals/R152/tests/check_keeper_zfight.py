"""R152 z-fighting inside the baked keepers (rev 6 models): two triangles that face the same way, lie in (nearly) one plane, overlap, are both drawn and look different flicker.
Reads keeper_zfight_dump.luau's output (the game's own decoder + pose code on the Roblox mock) and checks every pair of triangles of the DRAWN parts of each keeper in its REST pose
(awake, standing) and its ASLEEP pose with the R149 detector's rules, see ../tools/zfight_mesh.py (the rules, what is drawn, what is seen): coplanar <= 0.002, near <= 0.02, far < 4 depth
steps of a 24-bit buffer at the distance the overlap is seen from (0.02 .. 0.043). `strict` (up to 0.002 x that distance) is listed, not counted. Pairs inside ONE mesh part count too
(the generator merges blocks into one mesh), tagged 'inside one part'.
Usage: python3 check_keeper_zfight.py <dump.txt> [--list N] [--json out.json] [--poses rest,asleep,bind,bindsleep] [--moves ../blender/keeper_zfight_moves.json]
  --moves: the check has teeth: every slide blender/fix_zfight.py made is undone ON ITS OWN (the piece put back where the generator had it) and the check must find a counted
  finding in that keeper again.
Exit 1 when a counted finding is left (or, with --moves, when an undone slide goes unnoticed)."""
import argparse, collections, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import zfight_mesh as M  # noqa: E402
Z = M.Z


def teeth(keepers, moves_path):
    import numpy as np
    by_key = {k['key']: k for k in keepers}
    missed = 0
    for m in json.load(open(moves_path)):
        k = by_key[m['key']]
        pi = next(i for i, p in enumerate(k['parts']) if p['name'] == m['part'])
        p = k['parts'][pi]
        root = np.array(M.components(p['T'], len(p['V'])))
        idx = np.nonzero(root == root[m['piece']])[0]
        V = p['V'].copy()
        V[idx] = np.round((V[idx] - np.array(m['by'])) * 512) / 512
        found = []
        for state in ('rest', 'asleep'):
            fs, _, _ = M.analyse(k, state, V_by_part={pi: V})
            found += [f for f in fs if f['tier'] in Z.COUNTED and m['part'] in (f['a'], f['b'])]
        print('  %-14s %-18s put back by %s: %s' % (k['name'], m['part'], m['by'], ('%d counted findings again' % len(found)) if found else 'NOT NOTICED'))
        missed += 0 if found else 1
    print('keeper z-fighting teeth: %d of %d undone slides noticed' % (len(json.load(open(moves_path))) - missed, len(json.load(open(moves_path)))))
    return missed


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('dump'); ap.add_argument('--list', type=int, default=30); ap.add_argument('--json'); ap.add_argument('--poses', default='rest,asleep')
    ap.add_argument('--moves')
    a = ap.parse_args()
    keepers = M.parse(a.dump)
    if a.moves:
        return 1 if teeth(keepers, a.moves) else 0
    allf = []; counted = 0; tris = 0; poses = a.poses.split(',')
    for k in keepers:
        for state in poses:
            fs, np_, nt = M.analyse(k, state)
            tris += nt
            allf += fs
            c = [f for f in fs if f['tier'] in Z.COUNTED]
            s = [f for f in fs if f['tier'] == 'strict']
            counted += len(c)
            print('%-14s %-6s %2d parts %5d triangles: counted %3d (coplanar %d, near %d, far %d), strict %d' % (
                k['name'], state, np_, nt, len(c), sum(f['tier'] == 'coplanar' for f in c), sum(f['tier'] == 'near' for f in c), sum(f['tier'] == 'far' for f in c), len(s)))
            g = collections.OrderedDict()
            for f in c:
                g.setdefault((f['tier'], f['a'], f['b'], f['inside']), []).append(f)
            for (tier, pa, pb, ins), lst in list(g.items())[:a.list]:
                f = lst[0]
                print('    %-8s x%-3d off=%+.4f area=%7.3f %s%s <-> %s  %s/%s at %s' % (tier, len(lst), f['offset'], max(x['area'] for x in lst), pa, ' (inside one part)' if ins else '', pb, f['colA'][:3], f['colB'][:3], f['at']))
    print('keeper z-fighting: %d triangles checked in %d poses, %d counted findings' % (tris, len(poses) * len(keepers), counted))
    if a.json: json.dump(allf, open(a.json, 'w'), indent=0)
    print('keeper z-fighting: %s' % ('PASS' if counted == 0 else 'FAIL (%d)' % counted))
    return 1 if counted else 0


if __name__ == '__main__':
    sys.exit(main())
