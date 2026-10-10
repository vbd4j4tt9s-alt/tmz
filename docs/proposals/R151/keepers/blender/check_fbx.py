"""Re-import every exported FBX in Blender and compare each part with its manifest entry (count, name, triangles, size).
This checks that the files are complete and that the axis / scale settings round-trip; it is not a Roblox Studio import.
Usage: python check_fbx.py FBX_DIR  (bpy 4.5 Python)."""
import sys, os, json, glob
import bpy
from mathutils import Vector

d = sys.argv[-1]
bad = 0
for man in sorted(glob.glob(os.path.join(d, 'keeper_*.json'))):
    m = json.load(open(man))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(d, m['Fbx']), axis_forward='-Z', axis_up='Y')
    obs = {o.name: o for o in bpy.context.scene.objects if o.type == 'MESH'}
    worst = 0.0
    for p in m['Parts']:
        o = obs.get(p['Name'])
        if o is None:
            print('MISSING', m['Keeper'], p['Name'])
            bad += 1
            continue
        ws = [o.matrix_world @ v.co for v in o.data.vertices]
        # Blender (x, y, z) -> Roblox (x, z, -y)
        rs = [Vector((w.x, w.z, -w.y)) for w in ws]
        mn = Vector((min(v.x for v in rs), min(v.y for v in rs), min(v.z for v in rs)))
        mx = Vector((max(v.x for v in rs), max(v.y for v in rs), max(v.z for v in rs)))
        cen, size = (mn + mx) / 2, mx - mn
        err = max(max(abs(cen[i] - p['Center'][i]) for i in range(3)), max(abs(size[i] - p['Size'][i]) for i in range(3)))
        worst = max(worst, err)
        tris = sum(len(f.vertices) - 2 for f in o.data.polygons)
        if tris != p['Triangles']:
            print('TRIS', m['Keeper'], p['Name'], tris, p['Triangles'])
            bad += 1
    print('%-16s %2d/%2d parts back, worst centre/size difference %.4f studs' % (m['Keeper'], len(obs), len(m['Parts']), worst))
    if worst > 0.01:
        bad += 1
print('FBX check:', 'OK' if bad == 0 else '%d problems' % bad)
