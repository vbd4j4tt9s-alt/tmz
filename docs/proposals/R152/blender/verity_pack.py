"""R152 Verity pack, before / after, rendered in Blender (bpy 4.5, Cycles on the CPU).

Owner: "verity pack is also not flat for some reason and there is some leftover design". R151 painted a COPY of the standard pouch's uploaded mesh yellow: that mesh carries
its print partly as relief (embossed shapes at the corners and edges) and its belly is puffy, so the yellow pack was bumpy and curved and the face Decal, which Roblox projects
along the face, bent round the curve. R152 generates a clean flat pouch (VerityPouch151.Generate).

  AFTER   the REAL mesh the game bakes: tools/dump_verity_pouch.py runs VerityPouch151.Generate on the Luau interpreter and writes it as an OBJ (the module's own vertex
          normals are applied), placed at the template's PackLocalFrame (pouch centre 0, -.01, -.0474 in the pack's frame) with the pack's own BottomSeal and 8 TearStrips
          in the darker yellow the pouch pack uses.
  BEFORE  a STAND-IN for R151's pack: the pouch's mesh is an uploaded asset that is not available offline (the same limit as docs/proposals/R151/blender/pack_shapes.py), so
          this is the repo's own parametric chip-bag stand-in (1.97 x 2.06 x ~1.0 studs, pillow body, pinched serrated ends) plus a simulated embossed relief (rings in the four
          corners, a frame along the edges): what the owner described, not the asset itself. Pure yellow everywhere, the seal and the strips included, as R151 had them.
  The face is a drawn smiley (the real picture, rbxassetid://102712963740896, cannot be downloaded here) projected along the face exactly like a Roblox Decal on a MeshPart
  (planar from the front / back, over the pouch's whole Front / Back face), so a curved surface bends it and a flat one keeps it crisp.

Views: FRONT; the owner's SIDE angle (about 62 degrees round, so the face is still seen); PROFILE (90 degrees, orthographic); HELD (a blocky R15 stand-in with the pack at the
carry layout: SeedPackVisuals.CarryLayout / PackCarryLayout, hands on the grip points).

Usage (the shared bpy venv; run from a directory with no bisect.py / random.py next to it):
  .../bpyenv/bin/python docs/proposals/R152/blender/verity_pack.py --obj docs/proposals/R152/verity_pouch.obj --cells /tmp/cells [--samples 48] [--size 640]
  python3 docs/proposals/R152/blender/compose_sheet.py /tmp/cells docs/proposals/R152/verity_pack.png
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

W, H = 1.97, 2.06                    # the standard pouch's box (Storm_02)
CENTER = (0.0, -0.01, -0.0474)       # the pouch's centre in the pack's frame (PackLocalFrame)
YELLOW = (255, 255, 0)
SEAL = (230, 230, 0)                 # VerityPackArt.Seal
SEAL_BEFORE = (255, 255, 0)


def lin(c):
    return tuple(((v / 255.0) / 12.92 if v / 255.0 <= 0.04045 else (((v / 255.0) + 0.055) / 1.055) ** 2.4) for v in c) + (1.0,)


# ---- the drawn smiley (a stand-in for Verity's picture) ----------------------------------------------------------------------------------------------------------
def smiley_image(n=768):
    yy, xx = np.mgrid[0:n, 0:n]
    x = (xx + 0.5) / n - 0.5
    y = 0.5 - (yy + 0.5) / n            # y up; array row 0 is the TOP of the picture
    a = np.zeros((n, n), dtype=np.float32)
    for sx in (-1, 1):                  # eyes
        d = ((x - sx * 0.155) / 0.034) ** 2 + ((y - 0.115) / 0.062) ** 2
        a = np.maximum(a, np.clip(1.6 - d * 1.6, 0, 1))
    # smile: an arc of a circle (centre above), thick line
    cx, cy, r = 0.0, 0.33, 0.50
    ang = np.arctan2(x - cx, -(y - cy))
    dist = np.abs(np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - r)
    on = (np.abs(ang) < 0.58)
    a = np.maximum(a, np.clip(1.5 - dist / 0.011 * 1.0, 0, 1) * on)
    img = np.zeros((n, n, 4), dtype=np.float32)
    img[..., 3] = a
    img = img[::-1]                     # Blender images start at the bottom row
    im = bpy.data.images.new('smiley', n, n, alpha=True)
    im.pixels = img.reshape(-1).tolist()
    im.alpha_mode = 'STRAIGHT'
    im.pack()
    return im


# ---- materials ---------------------------------------------------------------------------------------------------------------------------------------------
def solid(name, rgb, rough=0.42):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(rgb)
    b.inputs['Roughness'].default_value = rough
    return m


def decal_material(name, rgb, image, rough=0.42):
    """The colour with the picture projected along the face (planar, like a Decal on a MeshPart): u from x (mirrored on the -z face so it reads right from outside), v from y."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    b.inputs['Roughness'].default_value = rough
    tc = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    nrm = nt.nodes.new('ShaderNodeSeparateXYZ')
    nt.links.new(tc.outputs['Object'], sep.inputs['Vector'])
    nt.links.new(tc.outputs['Normal'], nrm.inputs['Vector'])

    def math_node(op, a=None, b_=None):
        n = nt.nodes.new('ShaderNodeMath')
        n.operation = op
        if a is not None:
            n.inputs[0].default_value = a
        if b_ is not None:
            n.inputs[1].default_value = b_
        return n

    facing = math_node('GREATER_THAN', None, 0.0)                    # +z face?
    nt.links.new(nrm.outputs['Z'], facing.inputs[0])
    sgn = math_node('MULTIPLY_ADD')                                   # +1 / -1
    nt.links.new(facing.outputs['Value'], sgn.inputs[0])
    sgn.inputs[1].default_value = 2.0
    sgn.inputs[2].default_value = -1.0
    ux = math_node('MULTIPLY')
    nt.links.new(sep.outputs['X'], ux.inputs[0])
    nt.links.new(sgn.outputs['Value'], ux.inputs[1])
    u = math_node('MULTIPLY_ADD')
    nt.links.new(ux.outputs['Value'], u.inputs[0])
    u.inputs[1].default_value = 1.0 / W
    u.inputs[2].default_value = 0.5
    v = math_node('MULTIPLY_ADD')
    nt.links.new(sep.outputs['Y'], v.inputs[0])
    v.inputs[1].default_value = 1.0 / H
    v.inputs[2].default_value = 0.5
    comb = nt.nodes.new('ShaderNodeCombineXYZ')
    nt.links.new(u.outputs['Value'], comb.inputs['X'])
    nt.links.new(v.outputs['Value'], comb.inputs['Y'])
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = image
    tex.extension = 'CLIP'
    tex.interpolation = 'Linear'
    nt.links.new(comb.outputs['Vector'], tex.inputs['Vector'])
    mix = nt.nodes.new('ShaderNodeMix')
    mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = lin(rgb)
    mix.inputs['B'].default_value = (0.012, 0.012, 0.012, 1)
    nt.links.new(tex.outputs['Alpha'], mix.inputs['Factor'])
    nt.links.new(mix.outputs['Result'], b.inputs['Base Color'])
    return m


# ---- geometry ----------------------------------------------------------------------------------------------------------------------------------------------
def load_obj(path):
    verts, norms, faces = [], [], []
    for line in open(path, encoding='utf-8'):
        if line.startswith('v '):
            verts.append(tuple(float(c) for c in line.split()[1:4]))
        elif line.startswith('vn '):
            norms.append(tuple(float(c) for c in line.split()[1:4]))
        elif line.startswith('f '):
            faces.append(tuple(int(p.split('/')[0]) - 1 for p in line.split()[1:4]))
    return verts, norms, faces


def mesh_object(name, verts, faces, material, normals=None, parent=None, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    for p in me.polygons:
        p.use_smooth = True
    if normals is not None:
        try:
            me.normals_split_custom_set_from_vertices(normals)
        except Exception as e:  # noqa: BLE001
            print('custom normals not applied:', e)
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent is not None:
        ob.parent = parent
    return ob


def box(name, size, loc, material, parent):
    me = bpy.data.meshes.new(name)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)]
    me.from_pydata(v, [], f)
    me.update()
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.parent = parent
    return ob


def cylinder_between(name, a, b, radius, material, parent):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=(b - a).length, vertices=24, location=(a + b) / 2)
    ob = bpy.context.active_object
    ob.name = name
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = (b - a).to_track_quat('Z', 'Y')
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.parent = parent
    return ob


def sphere(name, loc, radius, material, parent, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=32, ring_count=16, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.parent = parent
    return ob


def clamp01(x):
    return np.clip(x, 0.0, 1.0)


def ss(a, b, x):
    t = clamp01((x - a) / (b - a))
    return t * t * (3 - 2 * t)


def before_geometry(relief=True):
    """R151's pack, as a stand-in: the chip-bag stand-in of pack_shapes.py (pillow body, pinched serrated ends) + simulated embossed relief. Returns verts, faces."""
    nu, nv = 150, 210
    u = np.linspace(-1, 1, nu + 1)[None, :]
    v = np.linspace(-1, 1, nv + 1)[:, None]
    side = np.where(np.abs(u) < 1, (1 - np.abs(u) ** 2.4) ** 0.6, 0.0)
    core = 1 - 0.9 * ss(0.50, 0.94, np.abs(v))
    ripple = 1 + 0.18 * np.sin(2 * math.pi * 17 * (u + 1) / 2) * ss(0.90, 0.96, np.abs(v))
    closing = 1 - ss(0.985, 1.0, np.abs(v))
    t = side * core * ripple * closing
    z = 0.5 * t
    if relief:
        a, h = W / 2, H / 2
        mask = (1 - ss(0.80, 0.94, np.abs(v))) * clamp01((t - 0.15) / 0.3)
        emb = np.zeros_like(z)
        for cu in (-0.78, 0.78):
            for cv in (-0.78, 0.78):
                r = np.sqrt(((u - cu) * a) ** 2 + ((v - cv) * h) ** 2)
                emb += 0.038 * np.exp(-(((r - 0.20) / 0.024) ** 2)) + 0.026 * np.exp(-((r / 0.06) ** 2))
        for su in (-1, 1):                                           # the frame along the long edges
            emb += 0.026 * np.exp(-(((np.abs(u) - 0.90) * a / 0.022) ** 2)) * ss(0.70, 0.60, np.abs(v)) * (np.sign(u) == su)
        emb += 0.026 * np.exp(-(((np.abs(v) - 0.76) * h / 0.022) ** 2)) * ss(0.78, 0.68, np.abs(u))
        for k in (-1, 0, 1):                                         # a row of small embossed bars along the bottom
            emb += 0.022 * np.exp(-((((u - 0.22 * k) * a) / 0.07) ** 2 + (((v + 0.62) * h) / 0.035) ** 2))
        z = z + emb * mask
    xs = np.broadcast_to(u * (W / 2), z.shape)
    ys = np.broadcast_to(v * (H / 2) + CENTER[1], z.shape)
    verts = []
    front = {}
    back = {}
    idx = 0
    for jv in range(nv + 1):
        for iu in range(nu + 1):
            zz = float(z[jv, iu])
            front[(iu, jv)] = idx
            verts.append((float(xs[jv, iu]), float(ys[jv, iu]), CENTER[2] + zz))
            idx += 1
            if zz <= 1e-9:
                back[(iu, jv)] = front[(iu, jv)]
            else:
                back[(iu, jv)] = idx
                verts.append((float(xs[jv, iu]), float(ys[jv, iu]), CENTER[2] - zz))
                idx += 1
    faces = []
    for jv in range(nv):
        for iu in range(nu):
            a_, b_, c_, d_ = (iu, jv), (iu + 1, jv), (iu + 1, jv + 1), (iu, jv + 1)
            faces.append((front[a_], front[b_], front[c_], front[d_]))
            faces.append((back[d_], back[c_], back[b_], back[a_]))
    return verts, faces


# ---- scene -------------------------------------------------------------------------------------------------------------------------------------------------
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
    sc.view_settings.look = 'None'
    sc.render.threads = 4
    w = bpy.data.worlds.new('w')
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.50, 0.68, 0.86, 1)
    bg.inputs['Strength'].default_value = 0.85
    return sc


def lights(sc):
    for name, loc, energy, size in (('key', (-5.5, -8.0, 9.0), 1100, 8), ('fill', (7.0, -6.0, 3.5), 380, 9), ('rim', (1.0, 8.0, 7.0), 320, 8)):
        ld = bpy.data.lights.new(name, 'AREA')
        ld.energy = energy
        ld.size = size
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        lo.rotation_euler = (Vector((0, 0, 1.2)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        sc.collection.objects.link(lo)


def pack_objects(which, root, verts_after, normals_after, faces_after, mats):
    """The pack in the pack's own frame (x right, y up, z towards the holder), children of `root` (the Roblox -> Blender axis swap)."""
    if which == 'after':
        pouch = mesh_object('pouch', verts_after, faces_after, mats['decal_after'], normals_after, root, CENTER)
        seal, strip = mats['seal_after'], mats['seal_after']
    else:
        verts, faces = before_geometry(True)
        pouch = mesh_object('pouch_before', verts, faces, mats['decal_before'], None, root)
        seal, strip = mats['seal_before'], mats['seal_before']
    box('BottomSeal', (1.9, 0.16, 0.035), (0, -1.12, 0), seal, root)
    for i in range(1, 9):
        box('TearStrip%d' % i, (1.9 / 8 + 0.001, 0.18, 0.035), (-1.9 / 2 + (i - 0.5) * 1.9 / 8, 1.11, 0), strip, root)
    return pouch


def camera(sc, root, loc, target, ortho=None, lens=50):
    cd = bpy.data.cameras.new('cam')
    if ortho:
        cd.type = 'ORTHO'
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cam = bpy.data.objects.new('cam', cd)
    sc.collection.objects.link(cam)
    cam.parent = root
    cam.location = loc
    f = (Vector(target) - Vector(loc)).normalized()                 # look-at in the root's frame (Roblox axes: +y up)
    right = f.cross(Vector((0, 1, 0))).normalized()
    up = right.cross(f)
    m = Matrix(((right.x, up.x, -f.x), (right.y, up.y, -f.y), (right.z, up.z, -f.z)))
    cam.rotation_euler = m.to_euler()
    sc.camera = cam
    return cam


def figure(root, mats):
    """A blocky R15 stand-in (studs, the HumanoidRootPart at 0, 3, 0, facing -z) with the hands on the grip points of PackCarryLayout."""
    cloth, skin, dark = mats['cloth'], mats['skin'], mats['dark']
    box('LowerTorso', (2.0, 0.4, 1.0), (0, 2.4, 0), dark, root)
    box('UpperTorso', (2.0, 1.6, 1.0), (0, 3.4, 0), cloth, root)
    sphere('Head', (0, 4.75, 0), 0.62, skin, root, (1.0, 0.95, 0.95))
    for s in (-1, 1):
        box('Leg%d' % s, (0.95, 2.0, 1.0), (s * 0.5, 1.0, 0), dark, root)
        hand = (s * 0.67, 3.34, -1.21)                               # PackCarryLayout.Grip: anchor * (+-width, GripY, BackZ + .18 * avatar)
        cylinder_between('Arm%d' % s, (s * 1.25, 3.95, -0.1), hand, 0.26, cloth, root)
        sphere('Hand%d' % s, hand, 0.30, skin, root)
    return root


def render(sc, path, size, samples):
    sc.cycles.samples = samples
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main(argv):
    obj, cells, samples, size = None, None, 48, 640
    only = None
    i = 0
    while i < len(argv):
        if argv[i] == '--obj':
            obj = argv[i + 1]
            i += 1
        elif argv[i] == '--cells':
            cells = argv[i + 1]
            i += 1
        elif argv[i] == '--samples':
            samples = int(argv[i + 1])
            i += 1
        elif argv[i] == '--size':
            size = int(argv[i + 1])
            i += 1
        elif argv[i] == '--only':
            only = argv[i + 1].split(',')
            i += 1
        i += 1
    os.makedirs(cells, exist_ok=True)
    verts_after, normals_after, faces_after = load_obj(obj)
    views = [
        ('front', dict(loc=(0, -0.01, 12), target=(0, -0.01, 0), ortho=2.95)),
        ('side', dict(loc=(5.8 * math.sin(math.radians(62)), 0.55, 5.8 * math.cos(math.radians(62))), target=(0, -0.01, 0), lens=60)),
        ('profile', dict(loc=(12, -0.01, 0), target=(0, -0.01, 0), ortho=2.95)),
        ('held', dict(loc=(5.2, 5.2, -7.6), target=(0, 3.55, -1.2), lens=42, held=True)),
    ]
    for which in ('before', 'after'):
        for name, spec in views:
            if only and name not in only:
                continue
            sc = reset()
            lights(sc)
            root = bpy.data.objects.new('root', None)                   # Roblox (x, y up, z towards the viewer) -> Blender (x, -z, y up)
            sc.collection.objects.link(root)
            root.rotation_euler = (math.pi / 2, 0, 0)
            image = smiley_image()
            mats = dict(
                decal_after=decal_material('decal_after', YELLOW, image),
                decal_before=decal_material('decal_before', YELLOW, image),
                seal_after=solid('seal_after', SEAL),
                seal_before=solid('seal_before', SEAL_BEFORE),
                cloth=solid('cloth', (96, 120, 170), 0.7), skin=solid('skin', (232, 190, 140), 0.6), dark=solid('dark', (62, 66, 84), 0.7))
            holder = root
            if spec.get('held'):
                figure(root, mats)
                holder = bpy.data.objects.new('pack', None)
                sc.collection.objects.link(holder)
                holder.parent = root
                # the pack root (SeedPackVisuals.CarryLayout): HumanoidRootPart + (0, .85, BackZ - MaxZ) = (0, 3.85, -1.364 - .455)
                holder.location = (0, 3.85, -1.819)
            pack_objects(which, holder, verts_after, normals_after, faces_after, mats)
            camera(sc, root, spec['loc'], spec['target'], spec.get('ortho'), spec.get('lens', 50))
            render(sc, os.path.join(cells, '%s_%s.png' % (which, name)), size, samples)
            print('cell', which, name)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
