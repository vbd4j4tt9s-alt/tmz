"""R152: dump the approved rev 6 keeper meshes (the exact objects the R151 FBX export makes) as raw per-part data.

Usage (bpy 4.5 Python):  python dump_meshes.py OUT_JSON
Runs the R151 generators (docs/proposals/R151/keepers/blender: proposed.py -> assemble.build_proposed, studs off, effects
off: the FBX path) and writes, per keeper and per mesh part, in Roblox rig space (studs, face toward -Z):
  V   vertex positions (after the generator's merge of doubles, i.e. what the FBX holds)
  T   triangles (Blender's own triangulation of each polygon, outward winding as rendered)
  P   palette index per triangle (the atlas cell its UVs sit in = the generator's colour key)
  S   1 per triangle on a smooth-shaded polygon, else 0 (flat)
  N   per-corner normals of smooth triangles (Blender's corner normals, exactly what Cycles shaded), [] for flat ones
  C   per-corner colours (the generator's vertex colour 'Col', converted back to sRGB) to check the decoder's formula
plus the keeper's palette (sRGB), its model height range (y0, y1: the shade gradient) and the manifest fields.
"""
import sys, os, json, math
HERE = os.path.dirname(os.path.abspath(__file__))
R151 = os.path.abspath(os.path.join(HERE, '..', '..', 'R151', 'keepers', 'blender'))
sys.path.insert(0, R151)
import bpy
from mathutils import Vector
import kit, proposed, assemble

OUT = sys.argv[-1]


def lin_to_srgb(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def dump(st):
    sc = kit.reset_scene()
    k = proposed.BUILDERS[st]()
    b = assemble.build_proposed(k, sc.collection, studs=False, fx=False)
    y0, y1 = k.y_range
    parts = []
    for ob in b.objects():
        me = ob.data
        me.calc_loop_triangles()
        cen = Vector(ob['rest_center'])
        V = [list(kit.CI @ (v.co + cen)) for v in me.vertices]
        uv = me.uv_layers['Atlas'].data
        col = me.color_attributes['Col'].data if 'Col' in me.color_attributes else None
        cn = me.corner_normals
        T, P, S, N, C = [], [], [], [], []
        for lt in me.loop_triangles:
            poly = me.polygons[lt.polygon_index]
            T.append(list(lt.vertices))
            u, v = uv[lt.loops[0]].uv
            cell = int(math.floor(u * kit.ATLAS_CELLS)) + kit.ATLAS_CELLS * int(math.floor(v * kit.ATLAS_CELLS))
            P.append(cell)
            S.append(1 if poly.use_smooth else 0)
            N.append([list(kit.CI @ cn[li].vector) for li in lt.loops] if poly.use_smooth else [])
            if col is not None:
                C.append([[lin_to_srgb(x) for x in col[li].color[:3]] for li in lt.loops])
        # flat triangles: the winding must give Blender's own outward polygon normal (the decoder computes flat normals from it)
        for ti, lt in enumerate(me.loop_triangles):
            a, b_, c = (Vector(V[i]) for i in lt.vertices)
            n = (b_ - a).cross(c - a)
            if n.length > 1e-9 and n.normalized().dot(kit.CI @ me.polygons[lt.polygon_index].normal) < 0.5:
                WIND[0] += 1
        parts.append({'Name': ob.name, 'Group': ob['group'], 'Kind': ob['kind'], 'Piece': ob['piece'], 'V': V, 'T': T, 'P': P,
                      'S': S, 'N': N, 'C': C, 'Cosmetic': (ob['group'], ob['piece'] or None) in k.cosmetic})
    # Floor-sample candidates per rig group: the convex hull of the group's main, non-cosmetic pieces, leaving out geometry
    # buried below the floor by design in the rest pose (the snake's neck root reaches y = -5.7 at rest; floor y = -4).
    import bmesh
    hulls = {}
    for g in sorted({p['Group'] for p in parts}):
        pts = [v for p in parts if p['Group'] == g and p['Kind'] == 'main' and not p['Cosmetic'] for v in p['V'] if v[1] >= BURIED]
        if len(pts) < 4:
            continue
        bm = bmesh.new()
        for p in pts:
            bm.verts.new(p)
        hull = bmesh.ops.convex_hull(bm, input=bm.verts)
        hv = sorted({tuple(round(c, 4) for c in v.co) for v in hull['geom'] if isinstance(v, bmesh.types.BMVert)})
        bm.free()
        hulls[g] = [list(v) for v in hv]
    zg = k.geos.get(('Head', 'fx', 'Z'))
    z = None
    if zg is not None and zg.v:
        mn, mx = zg.bbox()
        z = {'Center': list((mn + mx) / 2), 'Size': list(mx - mn)}
    pal = [list(k.pal.rgb[key]) for key in k.pal.keys]
    return {'Key': k.key, 'Name': k.name, 'Stage': st, 'Y0': y0, 'Y1': y1, 'Palette': pal, 'PaletteKeys': k.pal.keys, 'Parts': parts,
            'Hulls': hulls, 'Z': z}


BURIED = -4.1
WIND = [0]


out = {'Keepers': [dump(st) for st in proposed.ORDER]}
json.dump(out, open(OUT, 'w'))
print('triangles whose winding disagrees with the polygon normal:', WIND[0])
for kk in out['Keepers']:
    print('%-16s parts %2d  verts %6d  tris %6d  smooth tris %5d  palette %d' % (
        kk['Name'], len(kk['Parts']), sum(len(p['V']) for p in kk['Parts']), sum(len(p['T']) for p in kk['Parts']),
        sum(sum(p['S']) for p in kk['Parts']), len(kk['Palette'])))
