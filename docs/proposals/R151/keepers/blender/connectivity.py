"""No floating pieces: build each proposed keeper, put it in its rest pose and in every rendered pose (the game's real
frames), and require every mesh island to touch the rest of the keeper.

Two islands are joined when their surfaces intersect, come within 0.02 studs, or one lies inside the other. The check
runs on every visible piece of that pose: rig-group meshes, eyes, Neon accents, the face shown in that pose (awake or
asleep; rest: both at once) and the client accents that stay (the snake's rattle). Effects (fire, lightning, the sleep Z)
are not meshes and are skipped. The Storm Colossus's floating fists and shoulder rocks are allowed by the owner and are
reported as "by design".

Usage: python connectivity.py -- POSES_JSON [OUT_JSON]   (bpy 4.5 Python)
"""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
from mathutils import Matrix, Vector
import kit, today, proposed, assemble, data

POSE_STATE = [('rest', None), ('stand', 'Chase'), ('run', 'Chase'), ('cock', 'Chase'), ('strike', 'Chase'), ('sleep', 'Asleep')]
RETAINED_ACCENTS = {2}


def build_posed(st, pose, state, coll, upg, pz):
    k = proposed.BUILDERS[st]()
    b = assemble.build_proposed(k, coll, studs=False)
    lift = 5.0 if st == 0 else 4.0
    if pose == 'rest':
        for ob in b.objects():
            ob.matrix_world = Matrix.Translation((0, 0, lift)) @ Matrix.Translation(Vector(ob['rest_center']))
        for ob in b.objects():
            if ob.get('kind') == 'fx':
                ob.hide_render = True
    else:
        frames = pz['veiled'][pose] if st == 0 else pz['stages'][str(st)][pose]
        if st == 1 and pose == 'sleep':
            golem_tree(b, k, upg, lift)
        else:
            b.pose(frames, lift)
        if st in RETAINED_ACCENTS:
            today.add_accents(b, pz['accents'][str(st)][pose], coll)
            today.pose_accents(b, lift)
            for o in b.extra:
                o['kind'] = 'accent'
                o['piece'] = ''
        assemble.show_state(b, k, state)
    return k, b


def golem_tree(b, k, upg, lift):
    """The golem asleep: each piece follows the TreeRest / TreeSize delta of the part of today's golem it replaces."""
    G = Matrix.Translation((0, 0, lift))
    parts = upg['1']['Parts']
    for ob in b.objects():
        kind = ob.get('kind')
        if kind in ('eyes', 'glow', 'fx'):
            ob.hide_render = True
            continue
        key = (ob['group'], ob['piece'] or None) if kind == 'main' else (ob['group'], 'Face')
        name = k.tree_map.get(key)
        group = ob['group']
        old = next(p for p in parts if p['Name'] == name and p['Group'] == group)
        delta = kit.cf_matrix(old['TreeRest']) @ kit.cf_matrix(old['Rest']).inverted()
        sc_ = sum(old['TreeSize'][i] / old['Size'][i] for i in range(3)) / 3
        ob.matrix_world = G @ kit.C @ delta @ kit.CI @ Matrix.Translation(Vector(ob['rest_center'])) @ Matrix.Scale(sc_, 4)


def classify(k, comps):
    """Main body = the largest component. Others: 'by design' if every island in it belongs to a piece the owner allowed
    to float (Storm Colossus), else a failure."""
    floating_names = set()
    for (group, piece) in k.floating:
        if piece in ('Glow', 'Eyes'):
            floating_names.add('%s_%s' % (group, piece))
        else:
            floating_names.add('%s_%s' % (group, piece) if piece else group)
    by_design, bad = [], []
    for c in comps[1:]:
        names = {lab.split('#')[0] for lab in c}
        if names and names <= floating_names:
            by_design.append(c)
        else:
            bad.append(c)
    return by_design, bad


def run(pz_path, out=None, keepers=None):
    upg = data.load_upg()
    pz = data.load_poses(pz_path)
    table = {}
    for st in keepers or proposed.ORDER:
        row = {}
        for pose, state in POSE_STATE:
            sc = kit.reset_scene()
            k, b = build_posed(st, pose, state, sc.collection, upg, pz)
            if pose == 'rest':
                objs = [o for o in b.objects() if o.get('kind') != 'fx']
            else:
                objs = [o for o in b.objects() + b.extra if not o.hide_render and o.get('kind') != 'fx']
            bpy.context.view_layer.update()
            n, comps = kit.connectivity(objs)
            by_design, bad = classify(k, comps)
            label = '%s/%s' % (pose, state or 'both faces')
            row[label] = {'components': n, 'by_design': len(by_design), 'floating': [c[:6] for c in bad]}
            print('%-16s %-18s islands=%4d  components=%2d  by_design=%d  floating=%d %s' % (
                k.name, label, sum(len(c) for c in comps), n, len(by_design), len(bad), [c[:4] for c in bad][:4]), flush=True)
        table[k.name] = row
    if out:
        json.dump(table, open(out, 'w'), indent=1)
    return table


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:]
    kit.DEBUG_AT = os.environ.get('DEBUG_AT') == '1'
    only = [int(x) for x in os.environ.get('KEEPERS', '').split(',') if x] or None
    run(args[0], args[1] if len(args) > 1 else None, only)
