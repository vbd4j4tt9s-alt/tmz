"""Turn a proposed KeeperModel into Blender objects (one per mesh part), grouped like the game's rig groups."""
import bpy
from mathutils import Vector, Matrix
import kit
from today import Built
from faces import STATES

# colours that never get the stud pattern (eyes, mouths, teeth): they use a plain copy of the material
NO_STUDS = {'white', 'pupil', 'eyedark', 'lash', 'mouthin', 'tooth', 'tongue', 'drool', 'goldtooth', 'zcol', 'zedge', 'flamein',
            'boltin', 'lip', 'brow'}


def build_proposed(k, coll, atlas_img=None, studs=True, fx=True):
    b = Built(k.name)
    ys = [p.y for _, kind, _, g in k.parts() for p in g.v]
    y0, y1 = min(ys), max(ys)
    k.y_range = (y0, y1)
    main_mat = kit.mat_vcol('Keeper_%s' % k.key, rough=0.6, spec=0.3, atlas_img=atlas_img)
    plain_mat = kit.mat_vcol('KeeperPlain_%s' % k.key, rough=0.45, spec=0.4)
    if studs:
        kit.add_studs(main_mat)
    for group, kind, piece, geo in k.parts(fx=fx):
        if kind in ('main', 'face'):
            mat = main_mat
        elif kind == 'eyes':
            if piece in STATES:
                rgb, strength = k.state_rgb.get(piece, (k.eye_rgb, 2.6))
                mat = kit.mat_flat('eyes_%s_%s' % (k.key, piece), rgb, emit=strength)
            else:
                mat = kit.mat_flat('eyes_%s' % k.key, k.eye_rgb, emit=2.6)
        elif kind == 'fx':
            mat = None
        else:
            rgb = k.glow_rgb.get(group, k.glow_rgb.get('*', (1, 0.6, 0.2)))
            mat = kit.mat_flat('glow_%s_%s' % (k.key, group), rgb, emit=2.4)
        if kind == 'fx':
            ob = kit.make_object(geo, k.pal, coll, y0, y1, kit.mat_fx('fx_%s' % k.key))
        else:
            if kind in ('main', 'face'):
                ob = kit.make_object(geo, k.pal, coll, y0, y1, mat, mat_index_fn=lambda key: 1 if key in NO_STUDS else 0)
                ob.data.materials.append(plain_mat)
            else:
                ob = kit.make_object(geo, k.pal, coll, y0, y1, mat)
        ob['group'] = group
        ob['kind'] = kind
        ob['piece'] = piece or ''
        b.add(group, ob)
    return b


def show_state(b, k, state, pose=None):
    """Show exactly one face state (and the knight's matching eye piece); effects by state."""
    for ob in b.objects():
        kind, piece = ob.get('kind'), ob.get('piece', '')
        if kind == 'face' or (kind == 'eyes' and piece in STATES):
            ob.hide_render = piece != state
        elif kind == 'fx':
            if piece == 'Z':
                ob.hide_render = not (state == 'Asleep' and k.stage != 1)
            elif piece == 'Smoke':
                ob.hide_render = state not in ('Idle', 'Asleep')
            else:
                ob.hide_render = False


def visible_parts(b):
    return [o for o in b.objects() if not o.hide_render and o.get('kind') != 'fx']
