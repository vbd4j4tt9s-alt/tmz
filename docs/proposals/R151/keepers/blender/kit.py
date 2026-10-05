"""Shared Blender helpers for the R151 keeper proposal (bpy 4.5, Cycles CPU).

Everything is authored in Roblox rig space (studs; X right, Y up, the keeper's face toward -Z) and converted to
Blender space (Z up) only when a mesh is created: roblox (x, y, z) -> blender (x, -z, y). A group frame from the game
(a Roblox CFrame: x, y, z, R00..R22) becomes a Blender object matrix with C * F * C^-1, so the same frames the game's
pose code computes pose these meshes exactly the way the game would move the parts.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()


def rb(v):
    return Vector((v[0], -v[2], v[1]))


def cf_matrix(c):
    x, y, z, a, b, cc, d, e, f, g, h, i = c
    return Matrix(((a, b, cc, x), (d, e, f, y), (g, h, i, z), (0, 0, 0, 1)))


def frame_b(c):
    return C @ cf_matrix(c) @ CI


# ---------------------------------------------------------------- Roblox-space transform helpers
def T(x, y=None, z=None):
    if y is None:
        x, y, z = x
    return Matrix.Translation((x, y, z))


def Rx(a):
    return Matrix.Rotation(a, 4, 'X')


def Ry(a):
    return Matrix.Rotation(a, 4, 'Y')


def Rz(a):
    return Matrix.Rotation(a, 4, 'Z')


def V(x, y=None, z=None):
    if y is None:
        return Vector(x)
    return Vector((x, y, z))


def spow(x, e):
    return math.copysign(abs(x) ** e, x)


def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


# ---------------------------------------------------------------- geometry accumulator
class Geo:
    """Vertices (Roblox space), faces, and per-face colour keys / smooth flags for ONE mesh part."""

    def __init__(self, name):
        self.name = name
        self.v = []
        self.f = []
        self.fc = []
        self.fs = []

    def add(self, verts, faces, col, smooth=True):
        base = len(self.v)
        self.v.extend([Vector(p) for p in verts])
        for fa in faces:
            idx = tuple(base + i for i in fa)
            self.f.append(idx)
            if callable(col):
                cen = sum((self.v[i] for i in idx), Vector()) / len(idx)
                self.fc.append(col(cen))
            else:
                self.fc.append(col)
            self.fs.append(smooth)

    def tris(self):
        return sum(len(f) - 2 for f in self.f)

    def extend(self, other):
        base = len(self.v)
        self.v.extend(other.v)
        self.f.extend(tuple(base + i for i in fa) for fa in other.f)
        self.fc.extend(other.fc)
        self.fs.extend(other.fs)

    def bvh(self):
        from mathutils.bvhtree import BVHTree
        return BVHTree.FromPolygons([tuple(p) for p in self.v], self.f)

    def bbox(self):
        if not self.v:
            return None
        mn = Vector((min(p.x for p in self.v), min(p.y for p in self.v), min(p.z for p in self.v)))
        mx = Vector((max(p.x for p in self.v), max(p.y for p in self.v), max(p.z for p in self.v)))
        return mn, mx


def _xf(M, p):
    return (M @ Vector((p[0], p[1], p[2], 1.0))).xyz


DETAIL = float(os.environ.get('KEEPER_DETAIL', '1.0'))  # < 1 builds a lighter version (fewer segments) for tri estimates


def _d(n, lo):
    return max(lo, int(round(n * DETAIL)))


def blob(g, c, r, col, e1=1.0, e2=1.0, seg=14, rings=9, M=None, smooth=True, deform=None):
    """Superellipsoid: e1 = e2 = 1 is an ellipsoid, small exponents give rounded boxes / pillows."""
    seg, rings = _d(seg, 6), _d(rings, 4)
    verts = []
    for i in range(1, rings):
        phi = -math.pi / 2 + math.pi * i / rings
        cp, sp = math.cos(phi), math.sin(phi)
        for j in range(seg):
            th = 2 * math.pi * j / seg
            ct, st = math.cos(th), math.sin(th)
            verts.append([r[0] * spow(cp, e1) * spow(ct, e2), r[1] * spow(sp, e1), r[2] * spow(cp, e1) * spow(st, e2)])
    verts.append([0, -r[1], 0])
    verts.append([0, r[1], 0])
    nr = rings - 1
    faces = []
    for i in range(nr - 1):
        for j in range(seg):
            a = i * seg + j
            b = i * seg + (j + 1) % seg
            faces.append((a, (i + 1) * seg + j, (i + 1) * seg + (j + 1) % seg, b))
    bi, ti = len(verts) - 2, len(verts) - 1
    for j in range(seg):
        faces.append((bi, j, (j + 1) % seg))
        faces.append((ti, (nr - 1) * seg + (j + 1) % seg, (nr - 1) * seg + j))
    if deform:
        verts = [deform(Vector(p)) for p in verts]
    M = (T(c) @ (M or Matrix.Identity(4)))
    g.add([_xf(M, p) for p in verts], faces, col, smooth)


def _frames(pts, up=Vector((0, 1, 0))):
    n = len(pts)
    tans = []
    for i in range(n):
        if i == 0:
            t = pts[1] - pts[0]
        elif i == n - 1:
            t = pts[-1] - pts[-2]
        else:
            t = (pts[i + 1] - pts[i - 1])
        tans.append(t.normalized())
    ref = up if abs(tans[0].dot(up)) < 0.95 else Vector((0, 0, -1))
    side = tans[0].cross(ref).normalized()
    frames = []
    for i in range(n):
        if i > 0:
            # parallel transport
            axis = tans[i - 1].cross(tans[i])
            if axis.length > 1e-6:
                ang = tans[i - 1].angle(tans[i])
                side = (Matrix.Rotation(ang, 3, axis.normalized()) @ side)
            side = (side - tans[i] * side.dot(tans[i])).normalized()
        upv = side.cross(tans[i]).normalized()
        frames.append((tans[i], side, upv))
    return frames


def tube(g, pts, radii, col, seg=10, cap0='round', cap1='round', smooth=True, up=Vector((0, 1, 0)), twist=0.0, normals=None):
    """A tube through pts with per-point radius (float, or (side, up) for an elliptical section).
    Caps: 'round' (hemisphere), 'flat', 'none', or 'point' (closes to the axis).
    normals: optional per-point direction for the section's 'side' axis (used by surface strokes)."""
    pts = [Vector(p) for p in pts]
    if seg > 4:
        seg = _d(seg, 5)
    rad = [(r, r) if not isinstance(r, (tuple, list)) else tuple(r) for r in radii]
    fr = _frames(pts, up)
    if normals:
        fr2 = []
        for (t, s, u), nv in zip(fr, normals):
            nv = Vector(nv)
            s2 = (nv - t * nv.dot(t)).normalized()
            fr2.append((t, s2, s2.cross(t).normalized()))
        fr = fr2
    rings = []
    for k, (p, (t, s, u)) in enumerate(zip(pts, fr)):
        rings.append((p, t, s, u, rad[k]))
    verts, faces = [], []

    def ring(p, s, u, ra, rb_):
        out = []
        for j in range(seg):
            a = 2 * math.pi * j / seg + twist
            out.append(p + s * (math.cos(a) * ra) + u * (math.sin(a) * rb_))
        return out

    allr = []
    if cap0 == 'round':
        p, t, s, u, (ra, rb_) = rings[0]
        for q in (0.35, 0.72, 0.93):
            ang = math.acos(q)
            allr.append(('ring', ring(p - t * (max(ra, rb_) * math.sin(ang) * 0.9), s, u, ra * q, rb_ * q)))
    for p, t, s, u, (ra, rb_) in rings:
        allr.append(('ring', ring(p, s, u, max(ra, 1e-4), max(rb_, 1e-4))))
    if cap1 == 'round':
        p, t, s, u, (ra, rb_) = rings[-1]
        for q in (0.93, 0.72, 0.35):
            ang = math.acos(q)
            allr.append(('ring', ring(p + t * (max(ra, rb_) * math.sin(ang) * 0.9), s, u, ra * q, rb_ * q)))
    for _, rr in allr:
        verts.extend(rr)
    nrings = len(allr)
    for i in range(nrings - 1):
        for j in range(seg):
            a = i * seg + j
            b = i * seg + (j + 1) % seg
            faces.append((a, b, (i + 1) * seg + (j + 1) % seg, (i + 1) * seg + j))
    # end closures
    p0, t0 = rings[0][0], rings[0][1]
    p1, t1 = rings[-1][0], rings[-1][1]
    if cap0 in ('round', 'flat', 'point'):
        if cap0 == 'round':
            tip = p0 - t0 * (max(rings[0][4]) * 0.95)
        else:
            tip = p0
        verts.append(tip)
        ci = len(verts) - 1
        for j in range(seg):
            faces.append((ci, (j + 1) % seg, j))
    if cap1 in ('round', 'flat', 'point'):
        if cap1 == 'round':
            tip = p1 + t1 * (max(rings[-1][4]) * 0.95)
        else:
            tip = p1
        verts.append(tip)
        ci = len(verts) - 1
        last = (nrings - 1) * seg
        for j in range(seg):
            faces.append((ci, last + j, last + (j + 1) % seg))
    g.add(verts, faces, col, smooth)


def stroke(g, bvh, rays, col, width, thick=0.12, taper=True, seg=6, lift=0.05):
    """A painted-looking band lying on a surface: each ray (origin, direction) is cast at the target surface
    (a Geo.bvh()); the hits are joined by a flat tube whose section lies along the surface."""
    pts, nrm = [], []
    for o, d in rays:
        hit = bvh.ray_cast(Vector(o), Vector(d).normalized())
        if hit[0] is None:
            continue
        nv = hit[1] if hit[1].dot(Vector(d)) > 0 else -hit[1]  # rays start inside: the outward normal faces along the ray
        pts.append(hit[0] + nv * (thick * 0.5 + lift))
        nrm.append(nv)
    if len(pts) < 2:
        return
    n = len(pts)
    radii = []
    for i in range(n):
        f = math.sin(math.pi * (i + 0.5) / n) ** 0.5 if taper else 1.0
        radii.append((thick, max(0.03, width * f)))
    tube(g, pts, radii, col, seg=seg, cap0='point', cap1='point', normals=nrm)


def bezier(p0, p1, p2, p3=None, n=8):
    """Points along a quadratic (p3 None) or cubic Bezier."""
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    out = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            out.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)
        else:
            p3v = Vector(p3)
            out.append((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t * t * p2 + t ** 3 * p3v)
    return out


def horn(g, base, ctrl, tip, r0, col, seg=8, n=6):
    pts = bezier(base, ctrl, tip, n=n)
    radii = [r0 * (1 - i / n) ** 0.9 + 0.02 for i in range(n + 1)]
    tube(g, pts, radii, col, seg=seg, cap0='flat', cap1='point')


def spike(g, base, tip, r, col, seg=6, smooth=False):
    tube(g, [base, tip], [r, 0.0], col, seg=seg, cap0='flat', cap1='point', smooth=smooth)


def crystal(g, base, axis, r, h, col, sides=6, M=None, smooth=False):
    """Faceted crystal: prism to 0.72 h, then a point."""
    axis = Vector(axis).normalized()
    ref = Vector((0, 1, 0)) if abs(axis.y) < 0.9 else Vector((1, 0, 0))
    s = axis.cross(ref).normalized()
    u = s.cross(axis).normalized()
    base = Vector(base)
    verts = []
    for lvl, rr in ((0.0, r * 0.8), (0.72, r)):
        for j in range(sides):
            a = 2 * math.pi * j / sides + 0.3
            verts.append(base + axis * (h * lvl) + s * math.cos(a) * rr + u * math.sin(a) * rr)
    verts.append(base + axis * h)
    verts.append(base - axis * (h * 0.05))
    faces = []
    for j in range(sides):
        a, b = j, (j + 1) % sides
        faces.append((a, b, sides + b, sides + a))
        faces.append((sides + a, sides + b, 2 * sides))
        faces.append((b, a, 2 * sides + 1))
    g.add(verts, faces, col, smooth)


def membrane(g, outline, thick, col, smooth=False):
    """A thin plate through a closed outline of 3D points (fan from the centroid)."""
    pts = [Vector(p) for p in outline]
    n = len(pts)
    cen = sum(pts, Vector()) / n
    nrm = Vector()
    for i in range(n):
        nrm += (pts[i] - cen).cross(pts[(i + 1) % n] - cen)
    nrm.normalize()
    off = nrm * (thick / 2)
    verts = [p + off for p in pts] + [p - off for p in pts] + [cen + off, cen - off]
    faces = []
    ct, cb = 2 * n, 2 * n + 1
    for i in range(n):
        j = (i + 1) % n
        faces.append((ct, i, j))
        faces.append((cb, n + j, n + i))
        faces.append((i, n + i, n + j, j))
    g.add(verts, faces, col, smooth)


def rbox(g, c, size, col, round_=0.35, M=None, seg=12, rings=8, smooth=True):
    blob(g, c, (size[0] / 2, size[1] / 2, size[2] / 2), col, e1=round_, e2=round_, seg=seg, rings=rings, M=M, smooth=smooth)


def box(g, c, size, col, M=None, smooth=False, wedge=False):
    """Exact Roblox Block / WedgePart in local space (wedge slope faces -Z/up: full height at +Z)."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    if wedge:
        verts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz), (-hx, hy, hz), (hx, hy, hz)]
        faces = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
    else:
        verts = [(x, y, z) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
        faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    M = T(c) @ (M or Matrix.Identity(4))
    g.add([_xf(M, p) for p in verts], faces, col, smooth)


def cylinder_x(g, c, size, col, M=None, seg=16):
    """Roblox Cylinder part: axis along local X."""
    hx, ry, rz = size[0] / 2, size[1] / 2, size[2] / 2
    verts = []
    for sx in (-hx, hx):
        for j in range(seg):
            a = 2 * math.pi * j / seg
            verts.append((sx, math.cos(a) * ry, math.sin(a) * rz))
    verts += [(-hx, 0, 0), (hx, 0, 0)]
    faces = []
    for j in range(seg):
        k = (j + 1) % seg
        faces.append((j, k, seg + k, seg + j))
        faces.append((2 * seg, k, j))
        faces.append((2 * seg + 1, seg + j, seg + k))
    M = T(c) @ (M or Matrix.Identity(4))
    g.add([_xf(M, p) for p in verts], faces, col, True)


def mirror_x(fn):
    """Call fn(sign) for sign in (-1, 1)."""
    for s in (-1, 1):
        fn(s)


# ---------------------------------------------------------------- palette, atlas, Blender objects
ATLAS_CELLS = 16
ATLAS_CELL_PX = 16


def shade(t):
    return 0.80 + 0.26 * t


class Palette:
    def __init__(self, colours):
        self.keys = list(colours.keys())
        self.rgb = dict(colours)

    def index(self, key):
        return self.keys.index(key)

    def write_atlas(self, path):
        """A small texture atlas: one 16 px cell per palette colour, with the same soft top-to-bottom shade the
        vertex colours use (UV v inside the cell = height in the model)."""
        size = ATLAS_CELLS * ATLAS_CELL_PX
        img = bpy.data.images.new(os.path.basename(path), size, size, alpha=False)
        px = [0.0] * (size * size * 4)
        for k, key in enumerate(self.keys):
            cx, cy = k % ATLAS_CELLS, k // ATLAS_CELLS
            r, g_, b = self.rgb[key]
            for yy in range(ATLAS_CELL_PX):
                t = min(1, max(0, (yy / (ATLAS_CELL_PX - 1) - 0.1) / 0.8))
                s = shade(t)
                for xx in range(ATLAS_CELL_PX):
                    X = cx * ATLAS_CELL_PX + xx
                    Y = cy * ATLAS_CELL_PX + yy
                    o = (Y * size + X) * 4
                    px[o:o + 4] = [min(1, r * s), min(1, g_ * s), min(1, b * s), 1.0]
        img.pixels[:] = px
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        return img


def make_object(geo, pal, coll, y0, y1, mat=None, origin='bbox'):
    """Mesh object from a Geo: colour attribute 'Col' (shade by model height), UV 'Atlas' into the palette atlas,
    smooth flags, outward normals. The object origin is the bbox centre (the way Roblox recentres an imported mesh)."""
    me = bpy.data.meshes.new(geo.name)
    bm = bmesh.new()
    bverts = [bm.verts.new(rb(p)) for p in geo.v]
    bm.verts.ensure_lookup_table()
    col_layer = bm.loops.layers.float_color.new('Col')
    uv_layer = bm.loops.layers.uv.new('Atlas')
    span = max(1e-3, y1 - y0)
    for fi, fa in enumerate(geo.f):
        try:
            face = bm.faces.new([bverts[i] for i in fa])
        except ValueError:
            continue
        face.smooth = geo.fs[fi]
        key = geo.fc[fi]
        k = pal.index(key)
        cx, cy = k % ATLAS_CELLS, k // ATLAS_CELLS
        r, g_, b = pal.rgb[key]
        for loop in face.loops:
            yv = loop.vert.co.z  # blender Z = roblox Y
            t = min(1, max(0, (yv - y0) / span))
            s = shade(t)
            loop[col_layer] = (srgb_to_lin(min(1, r * s)), srgb_to_lin(min(1, g_ * s)), srgb_to_lin(min(1, b * s)), 1.0)
            loop[uv_layer].uv = ((cx + 0.5) / ATLAS_CELLS, (cy + (0.1 + 0.8 * t) * (ATLAS_CELL_PX - 1) / ATLAS_CELL_PX + 0.5 / ATLAS_CELL_PX) / ATLAS_CELLS)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(geo.name, me)
    coll.objects.link(ob)
    if origin == 'bbox' and len(me.vertices):
        mn = Vector((min(v.co.x for v in me.vertices), min(v.co.y for v in me.vertices), min(v.co.z for v in me.vertices)))
        mx = Vector((max(v.co.x for v in me.vertices), max(v.co.y for v in me.vertices), max(v.co.z for v in me.vertices)))
        cen = (mn + mx) / 2
        me.transform(Matrix.Translation(-cen))
        ob['rest_center'] = list(cen)
        ob['rest_matrix'] = [list(r) for r in Matrix.Translation(cen)]
    if mat:
        me.materials.append(mat)
    return ob


# ---------------------------------------------------------------- materials
_mats = {}


def mat_vcol(name='KeeperVCol', rough=0.55, spec=0.35, atlas_img=None):
    key = (name, rough, spec, atlas_img.name if atlas_img else None)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Specular IOR Level'].default_value = spec
    attr = nt.nodes.new('ShaderNodeVertexColor')
    attr.layer_name = 'Col'
    nt.links.new(attr.outputs['Color'], bsdf.inputs['Base Color'])
    if atlas_img is not None:
        # Kept for the FBX (the exporter embeds this texture); rendering uses the identical vertex colours.
        tex = nt.nodes.new('ShaderNodeTexImage')
        tex.image = atlas_img
        tex.interpolation = 'Closest'
        tex.location = (-600, 200)
    _mats[key] = m
    return m


def mat_flat(name, rgb, rough=0.5, metallic=0.0, emit=0.0, alpha=1.0, transmission=0.0, spec=0.4):
    key = ('flat', name, tuple(round(c, 4) for c in rgb), rough, metallic, emit, alpha, transmission)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes['Principled BSDF']
    lin = tuple(srgb_to_lin(c) for c in rgb) + (1.0,)
    bsdf.inputs['Base Color'].default_value = lin
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Specular IOR Level'].default_value = spec
    if emit > 0:
        bsdf.inputs['Emission Color'].default_value = lin
        bsdf.inputs['Emission Strength'].default_value = emit
    if transmission > 0:
        bsdf.inputs['Transmission Weight'].default_value = transmission
    if alpha < 1:
        bsdf.inputs['Alpha'].default_value = alpha
    _mats[key] = m
    return m


def mat_atlas(name, img):
    """Export material: the palette atlas through UV map 'Atlas' into Base Color (what the FBX carries)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes['Principled BSDF']
    bsdf.inputs['Roughness'].default_value = 0.6
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    uv = nt.nodes.new('ShaderNodeUVMap')
    uv.uv_map = 'Atlas'
    nt.links.new(uv.outputs['UV'], tex.inputs['Vector'])
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return m


def mat_flat_export(name, rgb):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = tuple(srgb_to_lin(c) for c in rgb) + (1.0,)
    return m


# ---------------------------------------------------------------- scene, camera, render
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 48
    sc.cycles.use_adaptive_sampling = True
    sc.cycles.adaptive_threshold = 0.03
    sc.cycles.use_denoising = True
    sc.cycles.denoiser = 'OPENIMAGEDENOISE'
    sc.cycles.max_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.glossy_bounces = 2
    sc.cycles.transmission_bounces = 4
    sc.cycles.transparent_max_bounces = 6
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.view_settings.exposure = -0.15
    sc.render.image_settings.file_format = 'PNG'
    sc.render.threads_mode = 'AUTO'
    return sc


def stage_lighting(sc, ground_rgb=(0.80, 0.84, 0.78), sky_top=(0.55, 0.72, 0.95), radius=1500):
    w = bpy.data.worlds.new('Sky')
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes['Background']
    grad = nt.nodes.new('ShaderNodeTexGradient')
    grad.gradient_type = 'LINEAR'
    geo = nt.nodes.new('ShaderNodeTexCoord')
    sep = nt.nodes.new('ShaderNodeSeparateXYZ')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (0.85, 0.88, 0.9, 1)
    ramp.color_ramp.elements[1].color = tuple(srgb_to_lin(c) for c in sky_top) + (1,)
    mapr = nt.nodes.new('ShaderNodeMapRange')
    mapr.inputs['From Min'].default_value = -0.1
    mapr.inputs['From Max'].default_value = 0.8
    nt.links.new(geo.outputs['Generated'], sep.inputs[0])
    nt.links.new(sep.outputs['Z'], mapr.inputs['Value'])
    nt.links.new(mapr.outputs['Result'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = 0.9
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN'))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.data.color = (1.0, 0.96, 0.9)
    sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(-35))
    sc.collection.objects.link(sun)
    fill = bpy.data.objects.new('Fill', bpy.data.lights.new('Fill', 'SUN'))
    fill.data.energy = 0.8
    fill.data.angle = math.radians(30)
    fill.data.color = (0.8, 0.88, 1.0)
    fill.rotation_euler = (math.radians(70), 0, math.radians(150))
    fill.visible_shadow = False
    sc.collection.objects.link(fill)
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=radius, fill_type='NGON', location=(0, 0, 0))
    gnd = bpy.context.active_object
    gnd.name = 'Ground'
    gnd.data.materials.append(mat_flat('Ground', ground_rgb, rough=0.95, spec=0.1))
    return gnd


def make_camera(sc, name='Cam', lens=50):
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    cam.data.clip_start = 0.5
    cam.data.clip_end = 2000
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def aim(cam, target, azimuth_deg, elev_deg, dist):
    """Camera around target: azimuth 0 = in front of the keeper's face (Blender +Y), 90 = keeper's +X side."""
    a = math.radians(azimuth_deg)
    e = math.radians(elev_deg)
    t = Vector(target)
    pos = t + Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.location = pos
    d = (t - pos)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def world_bounds(objs):
    pts = []
    for ob in objs:
        if ob.type != 'MESH' or ob.hide_render:
            continue
        for v in ob.data.vertices:
            pts.append(ob.matrix_world @ v.co)
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def fit_distance(cam, mn, mx, aspect, margin=1.12):
    rad = (mx - mn).length / 2
    fov = cam.data.angle  # horizontal for sensor_fit AUTO when width >= height
    vfov = 2 * math.atan(math.tan(fov / 2) / aspect) if aspect >= 1 else fov
    hfov = fov if aspect >= 1 else 2 * math.atan(math.tan(fov / 2) * aspect)
    use = min(vfov, hfov)
    return rad * margin / math.sin(use / 2)


def sample_points(objs, step=3):
    pts = []
    for ob in objs:
        if ob.type != 'MESH' or ob.hide_render:
            continue
        mw = ob.matrix_world
        vs = ob.data.vertices
        for i in range(0, len(vs), step):
            pts.append(mw @ vs[i].co)
    return pts


def frame_points(sc, cam, pts, target, az, el, margin=0.06, w=None, h=None):
    """Aim at target from (az, el), then find the distance and lens shift that fit every point inside the frame."""
    from bpy_extras.object_utils import world_to_camera_view
    if w:
        sc.render.resolution_x, sc.render.resolution_y = w, h
    cam.data.shift_x = cam.data.shift_y = 0.0
    aspect = sc.render.resolution_x / sc.render.resolution_y
    for _ in range(2):
        lo, hi = 1.0, 3000.0
        for _ in range(28):
            mid = (lo + hi) / 2
            aim(cam, target, az, el, mid)
            bpy.context.view_layer.update()
            ok = True
            for p in pts:
                c = world_to_camera_view(sc, cam, p)
                if c.z <= 0 or not (margin <= c.x <= 1 - margin and margin <= c.y <= 1 - margin):
                    ok = False
                    break
            if ok:
                hi = mid
            else:
                lo = mid
        aim(cam, target, az, el, hi)
        bpy.context.view_layer.update()
        cs = [world_to_camera_view(sc, cam, p) for p in pts]
        cx = (min(c.x for c in cs) + max(c.x for c in cs)) / 2
        cy = (min(c.y for c in cs) + max(c.y for c in cs)) / 2
        cam.data.shift_x += (cx - 0.5) * (1 if aspect >= 1 else aspect)
        cam.data.shift_y += (cy - 0.5) * (1 / aspect if aspect >= 1 else 1)
    return hi


def render(sc, path, w, h, samples=None):
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    if samples:
        sc.cycles.samples = samples
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def player_standin(coll, x=0.0, y_b=0.0, facing=0.0):
    """A 5-stud Roblox-sized player (classic block avatar proportions: legs 2, torso 2, head ~1.1)."""
    g = Geo('Player')
    pal = {'skin': (0.96, 0.80, 0.25), 'shirt': (0.10, 0.45, 0.85), 'pants': (0.30, 0.65, 0.25), 'face': (0.1, 0.1, 0.1)}
    rbox(g, (0.5, 1.0, 0), (0.95, 2.0, 0.95), 'pants', round_=0.15)
    rbox(g, (-0.5, 1.0, 0), (0.95, 2.0, 0.95), 'pants', round_=0.15)
    rbox(g, (0, 3.0, 0), (2.0, 2.0, 1.0), 'shirt', round_=0.18)
    rbox(g, (-1.5, 3.0, 0), (0.95, 2.0, 0.95), 'skin', round_=0.15)
    rbox(g, (1.5, 3.0, 0), (0.95, 2.0, 0.95), 'skin', round_=0.15)
    blob(g, (0, 4.55, 0), (0.62, 0.55, 0.58), 'skin', e1=0.6, e2=0.6)
    blob(g, (-0.22, 4.65, -0.57), (0.08, 0.12, 0.04), 'face')
    blob(g, (0.22, 4.65, -0.57), (0.08, 0.12, 0.04), 'face')
    p = Palette(pal)
    ob = make_object(g, p, coll, 0, 5, mat_vcol('PlayerMat', rough=0.6))
    ob.matrix_world = Matrix.Translation((x, y_b, 0)) @ Matrix.Rotation(facing, 4, 'Z') @ Matrix.Translation(Vector(ob['rest_center']))
    return ob
