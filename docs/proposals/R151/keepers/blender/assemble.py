"""Turn a proposed KeeperModel into Blender objects (one per mesh part), grouped like the game's rig groups."""
import bpy
from mathutils import Vector, Matrix
import kit
from today import Built


def build_proposed(k, coll, atlas_img=None):
    b = Built(k.name)
    ys = [p.y for _, _, _, g in k.parts() for p in g.v]
    y0, y1 = min(ys), max(ys)
    k.y_range = (y0, y1)
    main_mat = kit.mat_vcol('Keeper_%s' % k.key, rough=0.55, spec=0.35, atlas_img=atlas_img)
    for group, kind, piece, geo in k.parts():
        if kind == 'main':
            mat = main_mat
        elif kind == 'eyes':
            mat = kit.mat_flat('eyes_%s' % k.key, k.eye_rgb, emit=2.6)
        else:
            rgb = k.glow_rgb.get(group, k.glow_rgb.get('*', (1, 0.6, 0.2)))
            mat = kit.mat_flat('glow_%s_%s' % (k.key, group), rgb, emit=2.4)
        ob = kit.make_object(geo, k.pal, coll, y0, y1, mat)
        ob['group'] = group
        ob['kind'] = kind
        ob['piece'] = piece or ''
        b.add(group, ob)
    return b
