"""R152: render the DECODED keeper meshes (what the game bakes) beside the approved R151 previews.

Usage (bpy 4.5 Python):  python render_roundtrip.py -- DECODED_JSON POSES_JSON PANEL_DIR
  DECODED_JSON  docs/proposals/R152/tests/check_roundtrip.py's decoded.json (KeeperMeshes152.Decode on the mock, checked against an
                independent Python decode)
  POSES_JSON    the game's real pose frames (docs/proposals/R151/keepers/blender/dump_poses.luau, as the R151 sheets used)
Each keeper is built from the decoded vertices / triangles / palette cells with the game's own colour formula (palette colour x height
shade, per corner), its eyes and glow as plain glowing colours, the awake face shown, and rendered in the R151 sheets' three-quarter
view of the 'stand' frame (same camera rule, light and ground). No stud texture: the game has none to put on MeshParts.
compose_roundtrip.py then lays them out next to the approved panels.
"""
import sys, os, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, '..', '..', 'R151', 'keepers', 'blender')))
import bpy, bmesh
from mathutils import Vector, Matrix
import kit

args = sys.argv[sys.argv.index('--') + 1:]
DEC, POSES, OUT = json.load(open(args[0])), json.load(open(args[1])), args[2]
os.makedirs(OUT, exist_ok=True)
SAMPLES = int(os.environ.get('SAMPLES', '24'))
GROUND = {1: (0.55, 0.74, 0.44), 6: (0.50, 0.70, 0.42), 2: (0.95, 0.84, 0.58), 3: (0.84, 0.90, 0.97), 4: (0.42, 0.38, 0.40),
          5: (0.78, 0.75, 0.92), 7: (0.58, 0.63, 0.74), 0: (0.45, 0.42, 0.55)}


def mesh_object(name, part, pal, y0, y1, coll):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(kit.rb(v)) for v in part['V']]
    col = bm.loops.layers.float_color.new('Col') if part['P'] else None
    span = max(1e-3, y1 - y0)
    for ti, t in enumerate(part['T']):
        try:
            f = bm.faces.new([vs[i - 1] for i in t])
        except ValueError:
            continue
        f.smooth = False
        if col is not None:
            rgb = pal[part['P'][ti]]
            for loop in f.loops:
                s = 0.80 + 0.26 * min(1, max(0, (loop.vert.co.z - y0) / span))
                loop[col] = tuple(kit.srgb_to_lin(min(1, c * s)) for c in rgb) + (1.0,)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def keeper(key, k):
    st = k['Stage']
    sc = kit.reset_scene()
    sc.cycles.samples = SAMPLES
    kit.stage_lighting(sc, ground_rgb=GROUND[st], radius=1500)
    frames = POSES['veiled']['stand'] if st == 0 else POSES['stages'][str(st)]['stand']
    G = Matrix.Translation((0, 0, 5.0 if st == 0 else 4.0))
    vmat = kit.mat_vcol('Keeper_%s' % key, rough=0.6, spec=0.3)
    objs = []
    for p in k['Parts']:
        if p['FaceState'] == 'Asleep':
            continue
        ob = mesh_object(p['Name'], p, k['Palette'], k['Y0'], k['Y1'], sc.collection)
        if p['Kind'] in ('main', 'face'):
            ob.data.materials.append(vmat)
        else:
            ob.data.materials.append(kit.mat_flat('%s_%s' % (p['Kind'], p['Name']), p['Color'], emit=2.6 if p['Kind'] == 'eyes' else 2.4))
        F = kit.frame_b(frames[p['Group']]) if p['Group'] in frames else Matrix.Identity(4)
        ob.matrix_world = G @ F
        objs.append(ob)
    cam = kit.make_camera(sc, lens=50)
    pts = kit.sample_points(objs, step=2)
    mn = Vector((min(q.x for q in pts), min(q.y for q in pts), min(q.z for q in pts)))
    mx = Vector((max(q.x for q in pts), max(q.y for q in pts), max(q.z for q in pts)))
    kit.frame_points(sc, cam, pts, (mn + mx) / 2, 38, 12, margin=0.05, w=520, h=390)
    path = os.path.join(OUT, 'decoded_%s.png' % key)
    kit.render(sc, path, 520, 390)
    print('render', path, flush=True)


for key, k in DEC.items():
    keeper(key, k)
