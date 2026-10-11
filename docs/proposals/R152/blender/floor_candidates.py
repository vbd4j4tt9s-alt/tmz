"""R152: floor-sample candidates for the new keeper models (input of select_floor.luau).

Usage: python3 floor_candidates.py MESHES_JSON OUT_LUAU
For every stage 1-7, the groups that today's KeeperRigConfig grounds with (the biped rigs: the legs only; the others: every
group) get the convex-hull vertices of their new main, non-cosmetic pieces (dump_meshes.py: geometry buried below the floor
by design in the rest pose is left out). select_floor.luau keeps the few that are ever the lowest point of their group.
"""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', '..', 'R151', 'keepers', 'blender')))
import data  # noqa: E402

meshes = json.load(open(sys.argv[1]))
cfg, upg = data.load_cfg(), data.load_upg()
out = ['return {']
for k in meshes['Keepers']:
    st = k['Stage']
    if st == 0:
        continue
    legacy = upg[str(st)] if str(st) in upg else cfg[str(st)]
    rows = []
    for g in legacy['FloorSamples']:
        pts = k['Hulls'].get(g)
        assert pts, 'no hull for %s %s' % (k['Name'], g)
        rows.append('%s={%s}' % (g, ','.join('{%g,%g,%g}' % tuple(p) for p in pts)))
    out.append('[%d]={%s},' % (st, ','.join(rows)))
out.append('}')
open(sys.argv[2], 'w').write('\n'.join(out))
print('candidates for', sum(1 for k in meshes['Keepers'] if k['Stage']), 'stages')
