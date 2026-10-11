"""R153 preview cells, rendered in Blender (bpy 4.5, Cycles on the CPU) from tools/make_preview.py's scene.json.

Usage (the shared bpy venv; run from a directory with no bisect.py / random.py next to it):
  <bpyenv>/bin/python docs/proposals/R153/blender/render_preview.py <scene.json> <cells dir> [--samples 32] [--size 520] [--only prefix,prefix]

Every object of a cell is a mesh given in the PACK's frame (Roblox axes: x right, y up, z towards the back), turned into Blender's (x, -z, y). A colour is
sRGB 0..255; `emit` makes it glow (a Neon part), `alpha` < 1 makes it see-through, `smooth` shades it smooth. A camera is a location and a target in the
pack's frame, orthographic with `ortho` (the view's width in studs) or a lens in mm."""
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector


def B(p):
    return (p[0], -p[2], p[1])


def lin(c):
    return tuple(((v / 255.0) / 12.92 if v / 255.0 <= 0.04045 else (((v / 255.0) + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.use_denoising = True
    try:
        sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:  # noqa: BLE001
        pass
    sc.view_settings.view_transform = 'Standard'
    sc.render.threads = 4
    sc.render.film_transparent = False
    w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.50, 0.68, 0.86, 1)
    bg.inputs['Strength'].default_value = 0.9
    for name, loc, energy, size in (('key', (-6.0, -7.0, 8.0), 1300, 8), ('fill', (7.0, -6.0, 3.0), 450, 9), ('rim', (1.0, 8.0, 6.0), 380, 8), ('side', (-9.0, 2.0, 2.0), 500, 8)):
        ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy; ld.size = size
        lo = bpy.data.objects.new(name, ld); lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 0.5)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.collection.objects.link(lo)
    return sc


_mats = {}


def material(color, emit=False, alpha=1.0):
    key = (tuple(color), emit, round(alpha, 3))
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new('m%d' % len(_mats)); m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = lin(color)
    bsdf.inputs['Roughness'].default_value = 0.55
    if emit:
        bsdf.inputs['Emission Color'].default_value = lin(color)
        bsdf.inputs['Emission Strength'].default_value = 1.6
    if alpha < 0.999:
        bsdf.inputs['Alpha'].default_value = alpha
        try:
            m.blend_method = 'BLEND'
        except Exception:  # noqa: BLE001
            pass
    _mats[key] = m
    return m


def add(sc, i, o):
    me = bpy.data.meshes.new('o%d' % i)
    me.from_pydata([B(p) for p in o['v']], [], [list(f) for f in o['f']])
    me.validate(); me.update()
    if o.get('smooth'):
        for poly in me.polygons:
            poly.use_smooth = True
    me.materials.append(material(o['color'], o.get('emit', False), o.get('alpha', 1.0)))
    ob = bpy.data.objects.new('o%d' % i, me)
    sc.collection.objects.link(ob)


def camera(sc, cam):
    cd = bpy.data.cameras.new('cam')
    if cam.get('ortho'):
        cd.type = 'ORTHO'; cd.ortho_scale = cam['ortho']
    else:
        cd.lens = cam.get('lens', 50)
    cd.clip_start = 0.01
    ob = bpy.data.objects.new('cam', cd); sc.collection.objects.link(ob)
    loc, tgt = Vector(B(cam['loc'])), Vector(B(cam['target']))
    ob.location = loc
    f = (tgt - loc).normalized(); up0 = Vector((0, 0, 1))
    right = f.cross(up0).normalized(); up = right.cross(f)
    ob.rotation_euler = Matrix(((right.x, up.x, -f.x), (right.y, up.y, -f.y), (right.z, up.z, -f.z))).to_euler()
    sc.camera = ob


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:]
    scene, cells = argv[0], argv[1]
    samples = int(argv[argv.index('--samples') + 1]) if '--samples' in argv else 32
    size = int(argv[argv.index('--size') + 1]) if '--size' in argv else 520
    os.makedirs(cells, exist_ok=True)
    only = argv[argv.index('--only') + 1].split(',') if '--only' in argv else None
    for cell in json.load(open(scene))['cells']:
        if only and not any(cell['name'].startswith(o) for o in only):
            continue
        _mats.clear()
        sc = reset()
        for i, o in enumerate(cell['objects']):
            add(sc, i, o)
        camera(sc, cell['camera'])
        sc.cycles.samples = samples
        sc.render.resolution_x = size; sc.render.resolution_y = size; sc.render.resolution_percentage = 100
        sc.render.image_settings.file_format = 'PNG'
        sc.render.filepath = os.path.join(cells, cell['name'] + '.png')
        bpy.ops.render.render(write_still=True)
        print('rendered', cell['name'])


if __name__ == '__main__':
    main()
