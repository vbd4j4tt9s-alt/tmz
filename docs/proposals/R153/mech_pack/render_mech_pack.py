"""R153 Mech pack proposal: preview renders (bpy 4.5, Cycles CPU). Nothing here is game code.

What it draws
  * R151's chip-bag stand-in pouch (docs/proposals/R151/blender/pack_shapes.py: thickness(), the standard 1.97 x 2.06 footprint, ~1.0 deep,
    flat serrated crimps), so every option stays in the same pouch family as the real packs.
  * TODAY: the real Mech pack parts (today_parts.json, dumped from SpecialPackArt89 on the mock by R151's dump_packs.luau), placed on the
    stand-in's surface (their x / y / size / colour / material are the game's; the depth follows the stand-in, since Forest_01's real
    vertices are an uploaded asset).
  * Options A / B / C (look) and the reveal storyboard frames (option B), built from plain parts the way SpecialPackArt89 builds the rig.
  * Each tile is rendered on its own (PNG); compose_mech_pack.py lays out the sheet and writes the labels.

Coordinates: pack-local, X = right on screen (Roblox -x), Z = up (Roblox y), Y = depth, the FRONT face toward -Y (Roblox -z).

Usage (the bpy in the shared venv; run from the repo root, not from a folder that holds a stray bisect.py / random.py):
  .../bpyenv/bin/python docs/proposals/R153/mech_pack/render_mech_pack.py --out <tile dir> [--samples 48] [--only today,a,b,c,hotbar,story]
"""
import argparse
import json
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(REPO, 'docs', 'proposals', 'R151', 'blender'))
import pack_shapes as PS  # noqa: E402  (R151's stand-in pouch)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

HX, HY, HZ = PS.HALF
CY = PS.CENTER[1]
BG = (14, 30, 48)          # the shop's Mech hangar colour (PackViewport89), also the sheet's panel colour
ONLY_TILES = None          # --tiles: re-render only these tile files

# --- colours (sRGB 0..255) -----------------------------------------------------------------------------------------------------------------
TODAY_BODY = (231, 237, 239)
TODAY_TRIM = (246, 171, 75)
GUNMETAL = (46, 54, 66)          # option B body (near SeedPackRules.BiomeThemes[8].Body 31,43,57, a little lighter so it reads)
GUN_A = (62, 70, 82)             # option A body
STEEL = (132, 142, 154)
STEEL_DARK = (92, 102, 114)
STEEL_LIGHT = (200, 206, 214)
GRAPHITE = (53, 66, 79)
CYAN = (34, 231, 255)
GOLD = (242, 180, 65)
HAZARD_Y = (244, 178, 57)
HAZARD_K = (24, 26, 30)
LED_RED = (255, 64, 64)
MYTHIC_HINT = (230, 125, 255)    # RarePullRules.Tiers[5].Hint
LEGEND_HINT = (255, 207, 89)     # RarePullRules.Tiers[4].Hint


def lin(c):
    out = []
    for x in c[:3]:
        x = x / 255.0
        out.append(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


# --- the stand-in pouch's front surface ----------------------------------------------------------------------------------------------------
def w_at(X, Z):
    u = max(-1.0, min(1.0, X / HX))
    v = max(-1.0, min(1.0, (Z - CY) / HY))
    return PS.thickness(u, v)


def surf_point(X, Z):
    return Vector((X, -w_at(X, Z) * HZ, Z))


def surf_normal(X, Z):
    e = 0.004
    pu = surf_point(X + e, Z) - surf_point(X - e, Z)
    pv = surf_point(X, Z + e) - surf_point(X, Z - e)
    n = pu.cross(pv)
    if n.length < 1e-9:
        return Vector((0, -1, 0))
    n.normalize()
    if n.y > 0:
        n = -n
    return n


def surface_frame(X, Z, angle=0.0):
    n = surf_normal(X, Z)
    tr = Vector((1, 0, 0))
    tr = (tr - n * tr.dot(n)).normalized()
    tu = n.cross(tr)
    ca, sa = math.cos(angle), math.sin(angle)
    r = tr * ca + tu * sa
    u = -tr * sa + tu * ca
    return r, u, n


def mat4(r, u, n, c):
    return Matrix(((r.x, u.x, n.x, c.x), (r.y, u.y, n.y, c.y), (r.z, u.z, n.z, c.z), (0, 0, 0, 1)))


# --- scene --------------------------------------------------------------------------------------------------------------------------------
class Scene:
    def __init__(self, samples):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        sc = bpy.context.scene
        self.sc = sc
        sc.render.engine = 'CYCLES'
        sc.cycles.device = 'CPU'
        sc.cycles.samples = samples
        sc.cycles.use_denoising = True
        try:
            sc.cycles.denoiser = 'OPENIMAGEDENOISE'
        except Exception:
            pass
        sc.cycles.max_bounces = 6
        sc.cycles.transparent_max_bounces = 16
        sc.view_settings.view_transform = 'Standard'
        sc.view_settings.look = 'None'
        sc.render.film_transparent = False
        world = bpy.data.worlds.new('w')
        sc.world = world
        world.use_nodes = True
        nt = world.node_tree
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        out = nt.nodes.new('ShaderNodeOutputWorld')
        cam_bg = nt.nodes.new('ShaderNodeBackground')
        cam_bg.inputs['Color'].default_value = lin(BG)
        cam_bg.inputs['Strength'].default_value = 1.0
        # what reflections / bounce light see: a soft studio gradient (bright above, dark below), not the dark backdrop
        grad_tc = nt.nodes.new('ShaderNodeTexCoord')
        sep = nt.nodes.new('ShaderNodeSeparateXYZ')
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.35
        ramp.color_ramp.elements[0].color = (0.035, 0.045, 0.06, 1)
        ramp.color_ramp.elements[1].position = 0.75
        ramp.color_ramp.elements[1].color = (0.55, 0.6, 0.66, 1)
        mapr = nt.nodes.new('ShaderNodeMapRange')
        mapr.inputs['From Min'].default_value = -1
        mapr.inputs['From Max'].default_value = 1
        env_bg = nt.nodes.new('ShaderNodeBackground')
        env_bg.inputs['Strength'].default_value = 0.8
        lp = nt.nodes.new('ShaderNodeLightPath')
        mix = nt.nodes.new('ShaderNodeMixShader')
        nt.links.new(grad_tc.outputs['Generated'], sep.inputs['Vector'])
        nt.links.new(sep.outputs['Z'], mapr.inputs['Value'])
        nt.links.new(mapr.outputs['Result'], ramp.inputs['Fac'])
        nt.links.new(ramp.outputs['Color'], env_bg.inputs['Color'])
        nt.links.new(lp.outputs['Is Camera Ray'], mix.inputs['Fac'])
        nt.links.new(env_bg.outputs['Background'], mix.inputs[1])
        nt.links.new(cam_bg.outputs['Background'], mix.inputs[2])
        nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
        self.root = bpy.data.objects.new('pack', None)
        sc.collection.objects.link(self.root)
        self.mats = {}
        self.meshes = {}
        self.setup_compositor()

    def setup_compositor(self):
        sc = self.sc
        try:
            sc.use_nodes = True
            tree = sc.node_tree
            for n in list(tree.nodes):
                tree.nodes.remove(n)
            rl = tree.nodes.new('CompositorNodeRLayers')
            comp = tree.nodes.new('CompositorNodeComposite')
            glare = tree.nodes.new('CompositorNodeGlare')
            for t in ('BLOOM', 'FOG_GLOW'):
                try:
                    glare.glare_type = t
                    break
                except Exception:
                    continue
            for attr, val in (('quality', 'HIGH'), ('threshold', 1.0), ('size', 7), ('mix', -0.55)):
                try:
                    setattr(glare, attr, val)
                except Exception:
                    pass
            for name, val in (('Highlights Threshold', 1.0), ('Threshold', 1.0), ('Strength', 0.45), ('Size', 0.55)):
                if name in glare.inputs:
                    try:
                        glare.inputs[name].default_value = val
                    except Exception:
                        pass
            tree.links.new(rl.outputs['Image'], glare.inputs['Image'])
            tree.links.new(glare.outputs['Image'], comp.inputs['Image'])
        except Exception as e:  # the bloom is cosmetic
            print('compositor bloom skipped:', e)

    # materials ---------------------------------------------------------------------------------------------------------------------------
    def mat(self, kind, color=(255, 255, 255), strength=4.0, alpha=1.0):
        key = (kind, tuple(color), strength, alpha)
        if key in self.mats:
            return self.mats[key]
        m = bpy.data.materials.new('%s_%s' % (kind, '_'.join(map(str, color))))
        m.use_nodes = True
        nt = m.node_tree
        b = nt.nodes['Principled BSDF']
        out = nt.nodes['Material Output']
        b.inputs['Base Color'].default_value = lin(color)
        if kind == 'plastic':
            b.inputs['Roughness'].default_value = 0.5
        elif kind == 'paint':       # metallic paint for the gunmetal pouches
            b.inputs['Roughness'].default_value = 0.42
            b.inputs['Metallic'].default_value = 0.55
        elif kind == 'metal':
            b.inputs['Roughness'].default_value = 0.3
            b.inputs['Metallic'].default_value = 0.9
        elif kind == 'chrome':
            b.inputs['Roughness'].default_value = 0.1
            b.inputs['Metallic'].default_value = 1.0
        elif kind == 'neon':
            b.inputs['Emission Color'].default_value = lin(color)
            b.inputs['Emission Strength'].default_value = strength
            if alpha < 1:
                tr = nt.nodes.new('ShaderNodeBsdfTransparent')
                mx = nt.nodes.new('ShaderNodeMixShader')
                mx.inputs['Fac'].default_value = alpha
                nt.links.new(tr.outputs['BSDF'], mx.inputs[1])
                nt.links.new(b.outputs['BSDF'], mx.inputs[2])
                nt.links.new(mx.outputs['Shader'], out.inputs['Surface'])
        elif kind == 'glass':       # dark scanner glass
            b.inputs['Roughness'].default_value = 0.04
            b.inputs['Coat Weight'].default_value = 1.0
            b.inputs['Coat Roughness'].default_value = 0.02
        elif kind == 'holo':        # holographic chrome: thin-film interference over a bright metal (option C)
            b.inputs['Roughness'].default_value = 0.18
            b.inputs['Metallic'].default_value = 0.85
            # a pastel rainbow that shifts with the viewing angle (what a holographic foil print does)
            lw = nt.nodes.new('ShaderNodeLayerWeight')
            lw.inputs['Blend'].default_value = 0.35
            tc0 = nt.nodes.new('ShaderNodeTexCoord')
            nz = nt.nodes.new('ShaderNodeTexNoise')
            nz.inputs['Scale'].default_value = 1.6
            mixv = nt.nodes.new('ShaderNodeMath')
            mixv.operation = 'MULTIPLY_ADD'
            mixv.inputs[1].default_value = 0.9
            rr = nt.nodes.new('ShaderNodeMath')
            rr.operation = 'FRACT'
            ramp = nt.nodes.new('ShaderNodeValToRGB')
            stops = [(0.0, (150, 235, 255)), (0.2, (200, 160, 255)), (0.4, (255, 170, 220)), (0.6, (255, 236, 160)), (0.8, (160, 255, 200)), (1.0, (150, 235, 255))]
            cr = ramp.color_ramp
            cr.elements[0].position, cr.elements[0].color = stops[0][0], lin(stops[0][1])
            cr.elements[1].position, cr.elements[1].color = stops[-1][0], lin(stops[-1][1])
            for pos, col in stops[1:-1]:
                e = cr.elements.new(pos)
                e.color = lin(col)
            nt.links.new(tc0.outputs['Object'], nz.inputs['Vector'])
            nt.links.new(lw.outputs['Facing'], mixv.inputs[0])
            nt.links.new(nz.outputs['Fac'], mixv.inputs[2])
            nt.links.new(mixv.outputs['Value'], rr.inputs[0])
            nt.links.new(rr.outputs['Value'], ramp.inputs['Fac'])
            nt.links.new(ramp.outputs['Color'], b.inputs['Base Color'])
            if 'Thin Film Thickness' in b.inputs:
                tc = nt.nodes.new('ShaderNodeTexCoord')
                noise = nt.nodes.new('ShaderNodeTexNoise')
                noise.inputs['Scale'].default_value = 2.2
                noise.inputs['Detail'].default_value = 1.5
                mr = nt.nodes.new('ShaderNodeMapRange')
                mr.inputs['From Min'].default_value = 0.3
                mr.inputs['From Max'].default_value = 0.7
                mr.inputs['To Min'].default_value = 260
                mr.inputs['To Max'].default_value = 720
                nt.links.new(tc.outputs['Object'], noise.inputs['Vector'])
                nt.links.new(noise.outputs['Fac'], mr.inputs['Value'])
                nt.links.new(mr.outputs['Result'], b.inputs['Thin Film Thickness'])
                b.inputs['Thin Film IOR'].default_value = 1.45
        elif kind == 'steam':
            for n in list(nt.nodes):
                if n.type != 'OUTPUT_MATERIAL':
                    nt.nodes.remove(n)
            lw = nt.nodes.new('ShaderNodeLayerWeight')
            lw.inputs['Blend'].default_value = 0.5
            inv = nt.nodes.new('ShaderNodeMath')
            inv.operation = 'SUBTRACT'
            inv.inputs[0].default_value = 1.0
            pw = nt.nodes.new('ShaderNodeMath')
            pw.operation = 'POWER'
            pw.inputs[1].default_value = 2.5
            sc = nt.nodes.new('ShaderNodeMath')
            sc.operation = 'MULTIPLY'
            sc.inputs[1].default_value = alpha
            tr = nt.nodes.new('ShaderNodeBsdfTransparent')
            em = nt.nodes.new('ShaderNodeEmission')
            em.inputs['Color'].default_value = lin(color)
            em.inputs['Strength'].default_value = strength
            mx = nt.nodes.new('ShaderNodeMixShader')
            nt.links.new(lw.outputs['Facing'], inv.inputs[1])
            nt.links.new(inv.outputs['Value'], pw.inputs[0])
            nt.links.new(pw.outputs['Value'], sc.inputs[0])
            nt.links.new(sc.outputs['Value'], mx.inputs['Fac'])
            nt.links.new(tr.outputs['BSDF'], mx.inputs[1])
            nt.links.new(em.outputs['Emission'], mx.inputs[2])
            nt.links.new(mx.outputs['Shader'], out.inputs['Surface'])
        elif kind == 'hazard':      # diagonal yellow / black stripes in the pack's own frame
            tc = nt.nodes.new('ShaderNodeTexCoord')
            tc.object = self.root
            sep = nt.nodes.new('ShaderNodeSeparateXYZ')
            add = nt.nodes.new('ShaderNodeMath')
            add.operation = 'ADD'
            mul = nt.nodes.new('ShaderNodeMath')
            mul.operation = 'MULTIPLY'
            mul.inputs[1].default_value = 7.0
            fr = nt.nodes.new('ShaderNodeMath')
            fr.operation = 'FRACT'
            gt = nt.nodes.new('ShaderNodeMath')
            gt.operation = 'GREATER_THAN'
            gt.inputs[1].default_value = 0.5
            mx = nt.nodes.new('ShaderNodeMix')
            mx.data_type = 'RGBA'
            mx.inputs['A'].default_value = lin(HAZARD_Y)
            mx.inputs['B'].default_value = lin(HAZARD_K)
            nt.links.new(tc.outputs['Object'], sep.inputs['Vector'])
            nt.links.new(sep.outputs['X'], add.inputs[0])
            nt.links.new(sep.outputs['Z'], add.inputs[1])
            nt.links.new(add.outputs['Value'], mul.inputs[0])
            nt.links.new(mul.outputs['Value'], fr.inputs[0])
            nt.links.new(fr.outputs['Value'], gt.inputs[0])
            nt.links.new(gt.outputs['Value'], mx.inputs['Factor'])
            nt.links.new(mx.outputs['Result'], b.inputs['Base Color'])
            b.inputs['Roughness'].default_value = 0.45
        self.mats[key] = m
        return m

    # primitive meshes (shared) -----------------------------------------------------------------------------------------------------------
    def prim(self, kind):
        if kind in self.meshes:
            return self.meshes[kind]
        me = bpy.data.meshes.new(kind)
        bm = bmesh.new()
        if kind == 'cube':
            bmesh.ops.create_cube(bm, size=1.0)
        elif kind in ('cylZ', 'cylX', 'cylY', 'hexZ'):
            seg = 6 if kind == 'hexZ' else 32
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=0.5, radius2=0.5, depth=1.0)
            if kind == 'cylX':
                bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'Y'))
            elif kind == 'cylY':
                bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, 'X'))
        elif kind == 'sphere':
            bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=16, radius=0.5)
        elif kind == 'dome':        # a rivet head: the top half of a sphere, flat side at z = 0
            bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=10, radius=0.5)
            bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-6], context='VERTS')
        bm.to_mesh(me)
        bm.free()
        axis = {'cylZ': 2, 'hexZ': 2, 'cylX': 0, 'cylY': 1}.get(kind)
        for p in me.polygons:
            if kind in ('sphere', 'dome'):
                p.use_smooth = True
            elif axis is not None and kind != 'hexZ':
                p.use_smooth = abs(p.normal[axis]) < 0.5
        me.materials.append(None)
        self.meshes[kind] = me
        return me

    def add(self, name, kind, matrix, scale, material, parent=None):
        ob = bpy.data.objects.new(name, self.prim(kind))
        self.sc.collection.objects.link(ob)
        ob.parent = parent or self.root
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_basis = matrix @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        ob.material_slots[0].link = 'OBJECT'
        ob.material_slots[0].material = material
        return ob

    def on_surface(self, name, X, Z, size, material, kind='cube', angle=0.0, lift=0.0):
        """A part lying on the pouch's front face at (X, Z): size = (along the face, up the face, out of the face)."""
        r, u, n = surface_frame(X, Z, angle)
        c = surf_point(X, Z) + n * (lift + size[2] / 2)
        return self.add(name, kind, mat4(r, u, n, c), size, material)

    def on_plane(self, name, plane, X, Z, size, material, kind='cube', angle=0.0, lift=0.0):
        """A part on a flat plate whose back touches the face at plane = (X0, Z0) (the reactor / window stack)."""
        X0, Z0 = plane
        P0 = surf_point(X0, Z0)
        ca, sa = math.cos(angle), math.sin(angle)
        r = Vector((ca, 0, sa))
        u = Vector((-sa, 0, ca))
        n = Vector((0, -1, 0))
        c = Vector((X, P0.y, Z)) + n * (lift + size[2] / 2)
        return self.add(name, kind, mat4(r, u, n, c), size, material)

    def segment_path(self, name, pts, width, depth, material, lift=0.0, step=0.07):
        """A thin strip along a polyline on the face, cut into short pieces so it hugs the curved pouch."""
        k = 0
        for a, b in zip(pts, pts[1:]):
            ax, az = a
            bx, bz = b
            L = math.hypot(bx - ax, bz - az)
            n = max(1, int(math.ceil(L / step)))
            ang = math.atan2(bz - az, bx - ax)
            for i in range(n):
                t0, t1 = i / n, (i + 1) / n
                cx = ax + (bx - ax) * (t0 + t1) / 2
                cz = az + (bz - az) * (t0 + t1) / 2
                self.on_surface('%s_%d' % (name, k), cx, cz, (L / n + width * 0.9, width, depth), material, angle=ang, lift=lift)
                k += 1

    def patch(self, name, X, Z, w, h, material, lift=0.004, n=6, nz=None):
        """A panel that follows the pouch (like SpecialPackArt89's fitted armour, which was fitted to the real mesh): a grid of surface points."""
        verts, faces = [], []
        nz = nz or n
        for j in range(nz + 1):
            for i in range(n + 1):
                x = X - w / 2 + w * i / n
                z = Z - h / 2 + h * j / nz
                verts.append(tuple(surf_point(x, z) + surf_normal(x, z) * lift))
        for j in range(nz):
            for i in range(n):
                a = j * (n + 1) + i
                faces.append((a, a + 1, a + n + 2, a + n + 1))
        me = bpy.data.meshes.new(name)
        me.from_pydata(verts, [], faces)
        me.update()
        for p in me.polygons:
            p.use_smooth = True
        me.materials.append(material)
        ob = bpy.data.objects.new(name, me)
        self.sc.collection.objects.link(ob)
        ob.parent = self.root
        return ob

    def mirror_back(self):
        """The game builds every face part twice (SpecialPackArt89: flip = CFrame.Angles(0, pi, 0)); copy the front onto the back."""
        turn = Matrix.Rotation(math.pi, 4, 'Z')
        for ob in list(self.root.children):
            if ob.name.startswith(('pouch', 'BottomSeal', 'TearStrip', 'Antenna')):
                continue
            c = ob.copy()
            self.sc.collection.objects.link(c)
            c.parent = self.root
            c.matrix_parent_inverse = Matrix.Identity(4)
            c.matrix_basis = turn @ ob.matrix_basis

    # pouch, seal, strips ----------------------------------------------------------------------------------------------------------------
    def pouch(self, material):
        verts, faces, uvs = PS.bag_geometry(0)
        me = bpy.data.meshes.new('pouch')
        me.from_pydata([(x, -z, y) for (x, y, z) in verts], [], faces)
        me.update()
        for p in me.polygons:
            p.use_smooth = True
        me.materials.append(material)
        ob = bpy.data.objects.new('pouch', me)
        self.sc.collection.objects.link(ob)
        ob.parent = self.root
        return ob

    def seal(self, material, strip_materials=None, open_strips=None, seal_material=None):
        """The bottom seal and the 8 tear strips where the game puts them (root plane, y = -1.12 / 1.11). open_strips[i] in 0..1 flips strip i
        up and back (hinged on its lower edge) for the unlatch frames."""
        self.add('BottomSeal', 'cube', Matrix.Translation((0, 0, -1.12)), (1.9, 0.035, 0.16), seal_material or material)
        for s in range(8):
            x = -1.9 / 2 + (s + 0.5) * 1.9 / 8
            m = (strip_materials[s] if strip_materials else material)
            f = (open_strips[s] if open_strips else 0.0)
            hinge = Matrix.Translation((x, 0, 1.02)) @ Matrix.Rotation(-f * math.radians(80), 4, 'X') @ Matrix.Translation((0, 0, 0.09))
            self.add('TearStrip%d' % (s + 1), 'cube', hinge, (1.9 / 8 + 0.001, 0.035, 0.18), m)

    # lights / camera / render -------------------------------------------------------------------------------------------------------------
    def lights(self, key=900, extra=None):
        for name, loc, energy, size, color in (('key', (-4.5, -6.5, 5.5), key, 4.0, (1, 0.97, 0.93)), ('fill', (6.0, -5.0, 1.0), key * 0.35, 6.0, (0.85, 0.92, 1.0)),
                                               ('rim', (2.5, 6.0, 4.0), key * 0.55, 3.0, (0.75, 0.9, 1.0))):
            ld = bpy.data.lights.new(name, 'AREA')
            ld.energy = energy
            ld.size = size
            ld.color = color
            lo = bpy.data.objects.new(name, ld)
            lo.location = loc
            lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
            self.sc.collection.objects.link(lo)
        for (loc, energy, color, radius) in (extra or []):
            ld = bpy.data.lights.new('pt', 'POINT')
            ld.energy = energy
            ld.color = color
            ld.shadow_soft_size = radius
            lo = bpy.data.objects.new('pt', ld)
            lo.location = loc
            lo.visible_camera = False   # light only: not a glowing ball in the picture
            self.sc.collection.objects.link(lo)

    def camera(self, yaw=26.0, pitch=8.0, dist=9.5, lens=85, target=(0, 0, 0.02), ortho=None):
        cd = bpy.data.cameras.new('cam')
        if ortho:
            cd.type = 'ORTHO'
            cd.ortho_scale = ortho
        else:
            cd.lens = lens
        cam = bpy.data.objects.new('cam', cd)
        t = Vector(target)
        y, p = math.radians(yaw), math.radians(pitch)
        cam.location = t + Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p))) * dist
        cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
        self.sc.collection.objects.link(cam)
        self.sc.camera = cam

    def render(self, path, w, h):
        if ONLY_TILES and os.path.basename(path) not in ONLY_TILES:
            return
        self.sc.render.resolution_x = w
        self.sc.render.resolution_y = h
        self.sc.render.resolution_percentage = 100
        self.sc.render.image_settings.file_format = 'PNG'
        self.sc.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print('tile ->', path)


# --- TODAY: the game's own parts --------------------------------------------------------------------------------------------------------
M_RB = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))   # Roblox pack-local -> preview pack-local (a proper rotation)
REACTOR = ('ReactorHousing', 'ReactorInset', 'ReactorCore', 'ReactorEdge', 'CoreFacet', 'TurbineBlade', 'CounterGear')
PISTON = ('PistonChannel', 'SilverPiston', 'GoldPistonCap', 'PistonCuff', 'CuffLight')
REACTOR_CENTRE = (0.0, -0.02)   # (X, Z): SpecialPackArt89 base = CF(0, -.02, face)


def load_today():
    with open(os.path.join(HERE, 'today_parts.json'), encoding='utf-8') as f:
        return json.load(f)['parts']


def part_material(S, p, recolour=None):
    color = tuple(p['color'])
    if recolour:
        color = recolour(p['name'], color)
        if color is None:
            return None
    m = p['material']
    if m == 'Neon':
        return S.mat('neon', color, 3.2)
    if m == 'Metal':
        return S.mat('metal', color)
    return S.mat('plastic', color)


def today_parts(S, parts, keep=None, recolour=None, core_tint=None, turbine_angle=0.0, armour_lift=0.0):
    """Place the dumped parts on the stand-in face. keep(name) -> bool filters them; recolour(name, color) -> color | None (None = drop)."""
    P0 = surf_point(*REACTOR_CENTRE)
    for p in parts:
        name = p['name']
        if name == 'BottomSeal' or name.startswith('TearStrip'):
            continue
        if keep and not keep(name):
            continue
        material = part_material(S, p, recolour)
        if material is None:
            continue
        if core_tint and name.startswith(('ReactorCore', 'CoreFacet', 'ReactorEdge-12')):
            material = S.mat('neon', core_tint, 4.0)
        cols = [Vector((p['r'][0][i], p['r'][1][i], p['r'][2][i])) for i in range(3)]
        axes = [M_RB @ c for c in cols]
        pos = M_RB @ Vector(p['p'])
        size = p['size']
        kind = {'Cylinder': 'cylX', 'Ball': 'sphere'}.get(p['shape'], 'cube')
        # the part's out-of-face axis: the one most along -Y, signed outward
        k = max(range(3), key=lambda i: abs(axes[i].y))
        out = axes[k] * (-1 if axes[k].y > 0 else 1)
        zr = p['p'][2]
        if name.startswith(REACTOR):
            if name.startswith('TurbineBlade') and turbine_angle:
                rot = Matrix.Rotation(turbine_angle, 3, 'Y')
                d = Vector((pos.x - REACTOR_CENTRE[0], 0, pos.z - REACTOR_CENTRE[1]))
                d = rot @ d
                pos = Vector((REACTOR_CENTRE[0] + d.x, pos.y, REACTOR_CENTRE[1] + d.z))
                axes = [rot @ a for a in axes]
            depth_in_front = -0.587 - zr            # in front of the housing's centre
            y = P0.y - (0.014 + 0.008 + depth_in_front)
            c = Vector((pos.x, y, pos.z))
            M = Matrix(((axes[0].x, axes[1].x, axes[2].x, c.x), (axes[0].y, axes[1].y, axes[2].y, c.y), (axes[0].z, axes[1].z, axes[2].z, c.z), (0, 0, 0, 1)))
            S.add(name, kind, M, size, material)
            continue
        if name.startswith('FittedArmor'):
            S.patch(name, pos.x, pos.z, size[0], size[1], material, lift=0.004 + armour_lift)
            continue
        n = surf_normal(pos.x, pos.z)
        q = out.rotation_difference(n).to_matrix()
        axes = [q @ a for a in axes]
        if name.startswith(PISTON):
            offset = 0.0125 + 0.008 + (-0.415 - zr)
        elif name.startswith('FittedArmor'):
            offset = 0.004 + armour_lift
        else:
            offset = size[k] / 2 + 0.008 + 0.002
        c = surf_point(pos.x, pos.z) + n * offset
        M = Matrix(((axes[0].x, axes[1].x, axes[2].x, c.x), (axes[0].y, axes[1].y, axes[2].y, c.y), (axes[0].z, axes[1].z, axes[2].z, c.z), (0, 0, 0, 1)))
        S.add(name, kind, M, size, material)


# --- the designs ----------------------------------------------------------------------------------------------------------------------
def design_today(S, parts, state):
    S.pouch(S.mat('plastic', TODAY_BODY))
    trim = S.mat('plastic', TODAY_TRIM)
    S.seal(trim)
    today_parts(S, parts)


def design_a(S, parts, state):
    """A: REFIT. Today's rig untouched (reactor, turbine, pistons, panels), repainted: gunmetal pouch, steel panels with the two gold ones,
    bright bolt heads, and a yellow / black block seal (alternate tear strips, no texture needed)."""
    S.pouch(S.mat('paint', GUN_A))

    def recolour(name, color):
        if name.startswith('FittedArmor'):
            if color == (242, 180, 65):
                return HAZARD_Y
            return STEEL_DARK if color == (180, 197, 207) else STEEL
        if name.startswith('Bolt'):
            return None
        return color
    today_parts(S, parts, recolour=recolour)
    for x in (-0.43, 0.43):
        for z in (-0.73, 0.72):
            S.on_surface('BoltHead', -x, z, (0.12, 0.12, 0.035), S.mat('metal', STEEL_LIGHT), kind='hexZ', lift=0.008)
    ym, km = S.mat('plastic', HAZARD_Y), S.mat('plastic', HAZARD_K)
    S.seal(ym, strip_materials=[ym if i % 2 == 0 else km for i in range(8)], seal_material=ym)


CORNER_BOLTS = [(-0.6, 0.58), (0.6, 0.58), (-0.6, -0.62), (0.6, -0.62)]   # option B: the four click bolts, in click order


def circuit_paths():
    right = [
        [(0.47, 0.06), (0.60, 0.06), (0.60, 0.30), (0.70, 0.30)],
        [(0.46, -0.16), (0.66, -0.16), (0.66, -0.42)],
        [(0.26, 0.40), (0.26, 0.52), (0.44, 0.52)],
        [(0.24, -0.45), (0.24, -0.56), (0.40, -0.56)],
        [(0.40, 0.25), (0.52, 0.25), (0.52, 0.44), (0.62, 0.44)],
    ]
    out = []
    for path in right:
        out.append(path)
        out.append([(-x, z) for (x, z) in path])
    out.append([(0.0, 0.45), (0.0, 0.62)])
    return out


def design_b(S, parts, state):
    """B: CIRCUIT MECH. Gunmetal pouch, riveted steel frame, cyan circuit traces from the reactor, four hex corner bolts, a hazard-stripe
    seal, a small antenna with an LED on the top crimp, and a MECH plate. Keeps today's reactor + turbine + power LEDs (and their motion)."""
    st = state or {}
    S.pouch(S.mat('paint', GUNMETAL))
    steel, steel_l, dark = S.mat('metal', STEEL), S.mat('metal', STEEL_LIGHT), S.mat('plastic', (30, 34, 40))
    cyan = S.mat('neon', CYAN, 3.0)
    # frame
    fx, fz = 0.80, 0.80
    S.segment_path('FrameL', [(-fx, -fz), (-fx, fz)], 0.07, 0.02, steel, lift=0.0)
    S.segment_path('FrameR', [(fx, -fz), (fx, fz)], 0.07, 0.02, steel, lift=0.0)
    S.segment_path('FrameT', [(-fx, fz), (fx, fz)], 0.07, 0.02, steel, lift=0.0)
    S.segment_path('FrameB', [(-fx, -fz), (fx, -fz)], 0.07, 0.02, steel, lift=0.0)
    for i in range(9):
        t = -fz + i * (2 * fz) / 8
        for x in (-fx, fx):
            S.on_surface('RivetV', x, t, (0.045, 0.045, 0.03), steel_l, kind='dome', lift=0.02)
    for i in range(1, 8):
        t = -fx + i * (2 * fx) / 8
        for z in (-fz, fz):
            S.on_surface('RivetH', t, z, (0.045, 0.045, 0.03), steel_l, kind='dome', lift=0.02)
    # circuits + node pads + a chip
    tint = st.get('trace_color', CYAN)
    trace = S.mat('neon', tint, st.get('trace_strength', 2.6))
    pad = S.mat('neon', tint, 3.2)
    for i, path in enumerate(circuit_paths()):
        S.segment_path('Trace%d' % i, path, 0.022, 0.006, trace, lift=0.001)
        ex, ez = path[-1]
        S.on_surface('Pad%d' % i, ex, ez, (0.05, 0.05, 0.008), pad, lift=0.001)
        bx, bz = path[1] if len(path) > 2 else path[0]
        S.on_surface('Node%d' % i, bx, bz, (0.034, 0.034, 0.008), pad, lift=0.002)
    # reactor (today's) + power LEDs + accents
    keep = ('ReactorHousing', 'ReactorInset', 'ReactorCore', 'ReactorEdge', 'CoreFacet', 'TurbineBlade', 'CounterGear')
    today_parts(S, parts, keep=lambda n: n.startswith(keep), core_tint=st.get('core_tint'), turbine_angle=st.get('turbine', 0.0))
    # MECH plate
    S.on_surface('MechPlate', 0.0, -0.62, (0.5, 0.15, 0.012), dark, lift=0.0)
    txt = bpy.data.curves.new('mech', 'FONT')
    txt.body = 'MECH'
    txt.size = 0.115
    txt.align_x = 'CENTER'
    txt.align_y = 'CENTER'
    try:
        txt.font = bpy.data.fonts.load('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
    except Exception:
        pass
    txt.extrude = 0.002
    to = bpy.data.objects.new('mechtext', txt)
    S.sc.collection.objects.link(to)
    to.parent = S.root
    r, u, n = surface_frame(0.0, -0.62)
    c = surf_point(0.0, -0.62) + n * 0.016
    to.matrix_basis = mat4(r, u, n, c)
    to.data.materials.append(S.mat('neon', CYAN, 2.4))
    # the four click bolts (hex), backed out by state['bolts'] = [0..1] x 4
    bolts = st.get('bolts', [0, 0, 0, 0])
    for i, (x, z) in enumerate(CORNER_BOLTS):
        f = bolts[i]
        S.on_surface('Washer%d' % i, x, z, (0.17, 0.17, 0.008), dark, kind='cylZ', lift=0.0)
        S.on_surface('Bolt%d' % i, x, z, (0.15, 0.15, 0.05), steel_l, kind='hexZ', angle=f * 2.6, lift=0.008 + f * 0.24)
        S.on_surface('BoltSlot%d' % i, x, z, (0.1, 0.02, 0.004), dark, angle=0.5 + f * 2.6, lift=0.058 + f * 0.24)
        if f > 0:
            S.on_surface('BoltShaft%d' % i, x, z, (0.06, 0.06, 0.004 + f * 0.24), S.mat('metal', (230, 190, 90)), kind='cylZ', lift=0.004)
    # seal: hazard stripes
    hz = S.mat('hazard')
    S.seal(hz, open_strips=st.get('open_strips'))
    # antenna on the top crimp (rides on tear strip 7)
    if not st.get('no_antenna'):
        ax = 0.56
        lift7 = (st.get('open_strips') or [0] * 8)[6]
        if lift7 < 0.05:
            S.add('AntennaBase', 'cube', Matrix.Translation((ax, 0, 1.235)), (0.09, 0.07, 0.07), S.mat('plastic', GRAPHITE))
            S.add('AntennaRod', 'cylZ', Matrix.Translation((ax, 0, 1.235 + 0.2)), (0.026, 0.026, 0.34), S.mat('metal', STEEL_LIGHT))
            S.add('AntennaLED', 'sphere', Matrix.Translation((ax, 0, 1.235 + 0.4)), (0.08, 0.08, 0.08), S.mat('neon', LED_RED, st.get('led', 6.0)))


def design_c(S, parts, state):
    """C: HOLO-CHROME. A holographic chrome pouch (thin-film rainbow, like the Holo plants), a round scanner window where the reactor is with a
    seed hologram inside and a scan ring, two etched seams, chrome seal with a cyan light line."""
    S.pouch(S.mat('holo', (225, 230, 238)))
    chrome = S.mat('chrome', (205, 212, 222))
    plane = REACTOR_CENTRE
    S.on_plane('WindowRim', plane, 0, -0.02, (0.98, 0.98, 0.03), chrome, kind='cylZ', lift=0.004)
    S.on_plane('WindowGlass', plane, 0, -0.02, (0.84, 0.84, 0.012), S.mat('glass', (8, 20, 30)), kind='cylZ', lift=0.03)
    ring = S.mat('neon', CYAN, 3.0)
    for i in range(36):
        a = i * 2 * math.pi / 36
        S.on_plane('RingLED', plane, 0.445 * math.cos(a), -0.02 + 0.445 * math.sin(a), (0.07, 0.02, 0.01), ring, angle=a + math.pi / 2, lift=0.034)
    holo = S.mat('neon', (120, 240, 255), 2.2, alpha=0.55)
    # the seed hologram: a seed body + two leaves, floating in the window
    P0 = surf_point(*plane)
    c = Vector((0, P0.y - 0.12, -0.06))
    S.add('HoloSeed', 'sphere', Matrix.Translation(c) @ Matrix.Rotation(0.3, 4, 'Y'), (0.2, 0.16, 0.27), holo)
    for side in (-1, 1):
        S.add('HoloLeaf', 'sphere', Matrix.Translation(c + Vector((side * 0.09, 0, 0.2))) @ Matrix.Rotation(side * 0.7, 4, 'Y'), (0.16, 0.04, 0.07), holo)
    S.on_plane('ScanLine', plane, 0, 0.06, (0.8, 0.014, 0.004), S.mat('neon', (180, 250, 255), 5.0), lift=0.05)
    # etched seams + 4 rivets
    seam = S.mat('plastic', (90, 96, 108))
    S.patch('SeamT', 0.0, 0.62, 1.72, 0.016, seam, lift=0.003, n=48, nz=1)
    S.patch('SeamB', 0.0, -0.66, 1.72, 0.016, seam, lift=0.003, n=48, nz=1)
    for x in (-0.74, 0.74):
        for z in (0.62, -0.66):
            S.on_surface('Rivet', x, z, (0.06, 0.06, 0.03), chrome, kind='dome', lift=0.002)
    S.seal(chrome, seal_material=chrome)
    S.add('SealLight', 'cube', Matrix.Translation((0, -0.019, -1.12)), (1.7, 0.004, 0.025), S.mat('neon', CYAN, 3.0))


def design_context(S, parts, state):
    """Context for the hotbar row: a plain pale pouch in a Snow pack's colour (R151 audit), no print (stand-in)."""
    S.pouch(S.mat('plastic', (196, 206, 206)))
    S.seal(S.mat('plastic', (150, 170, 175)))


DESIGNS = {'today': design_today, 'a': design_a, 'b': design_b, 'c': design_c, 'context': design_context}


# --- effects for the storyboard ---------------------------------------------------------------------------------------------------------
def steam(S, centre, count, spread, size, seed, alpha=0.55, rise=0.0):
    rnd = random.Random(seed)
    m = S.mat('steam', (240, 244, 248), 1.5, alpha)
    for i in range(count):
        o = Vector((rnd.uniform(-spread, spread), rnd.uniform(-spread * 0.5, spread * 0.5), rnd.uniform(0, spread) + rise * i / max(1, count - 1)))
        s = size * rnd.uniform(0.6, 1.2)
        S.add('Steam', 'sphere', Matrix.Translation(Vector(centre) + o), (s, s, s * 0.85), m)


def sparks(S, origin, count, seed, length=0.11, color=(255, 214, 140)):
    rnd = random.Random(seed)
    m = S.mat('neon', color, 9.0)
    for i in range(count):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 0.2), rnd.uniform(-0.2, 1))).normalized()
        L = length * rnd.uniform(0.5, 1.2)
        c = Vector(origin) + d * (0.05 + rnd.uniform(0, 0.12)) + d * L / 2
        q = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
        S.add('Spark', 'cylZ', Matrix.Translation(c) @ q, (0.012, 0.012, L), m)


def scan_line(S, z, color, strength=6.0):
    m = S.mat('neon', color, strength)
    glow = S.mat('neon', color, 1.4, alpha=0.35)
    S.segment_path('Scan', [(-0.93, z), (0.93, z)], 0.022, 0.006, m, lift=0.03, step=0.05)
    S.segment_path('ScanGlow', [(-0.95, z), (0.95, z)], 0.11, 0.004, glow, lift=0.022, step=0.05)


def mech_seed(S, centre, scale=1.0):
    """A Mech seed like the Index art: a silver seed, two cyan crystal leaves, a violet core."""
    c = Vector(centre)
    S.add('SeedBody', 'sphere', Matrix.Translation(c), (0.34 * scale, 0.3 * scale, 0.4 * scale), S.mat('metal', (205, 212, 222)))
    S.add('SeedCore', 'cylY', Matrix.Translation(c + Vector((0, -0.15 * scale, -0.02 * scale))), (0.13 * scale, 0.03 * scale, 0.13 * scale), S.mat('neon', (200, 120, 255), 4.0))
    for side in (-1, 1):
        S.add('SeedLeaf', 'sphere', Matrix.Translation(c + Vector((side * 0.13 * scale, 0, 0.3 * scale))) @ Matrix.Rotation(side * 0.75, 4, 'Y'),
              (0.24 * scale, 0.06 * scale, 0.11 * scale), S.mat('neon', CYAN, 2.2))


# --- jobs ---------------------------------------------------------------------------------------------------------------------------------
def build(key, parts, samples, state=None, yaw=-24.0, fx=None, lights_extra=None):
    S = Scene(samples)
    DESIGNS[key](S, parts, state or {})
    S.mirror_back()
    S.root.rotation_euler = (0, 0, math.radians(yaw))
    if fx:
        fx(S)
    S.lights(extra=lights_extra)
    return S


def job_heroes(out, parts, samples, keys):
    for key in keys:
        S = build(key, parts, samples, yaw=-24.0)
        S.camera(yaw=0, pitch=7, dist=9.0, lens=85, target=(0, 0, 0.12))
        S.render(os.path.join(out, 'hero_%s.png' % key), 760, 900)
        S = build(key, parts, samples, yaw=-90.0)
        S.camera(yaw=0, pitch=0, dist=10.5, lens=85, target=(0, 0, 0.06))
        S.render(os.path.join(out, 'side_%s.png' % key), 300, 640)


def job_hotbar(out, parts, samples):
    for key in ('today', 'a', 'b', 'c', 'context'):
        S = build(key, parts, max(24, samples // 2), yaw=-20.0)
        S.camera(yaw=0, pitch=6, dist=10.5, lens=85, target=(0, 0, 0.1))
        S.render(os.path.join(out, 'icon_%s.png' % key), 300, 300)


def job_story(out, parts, samples):
    W, H = 600, 720
    cam = dict(yaw=0, pitch=7, dist=8.4, lens=85, target=(0, 0, 0.2))
    # 1 held: hum glow + antenna sparks
    S = build('b', parts, samples, state={'led': 9.0}, yaw=-22.0,
              fx=lambda S: sparks(S, (0.56, 0.0, 1.66), 7, 3),
              lights_extra=[((0.0, -1.6, 0.0), 60, (0.35, 0.9, 1.0), 0.8)])
    S.camera(**cam)
    S.render(os.path.join(out, 'story_1_held.png'), W, H)
    # 2 clicks: bolts back out one per click (here after click 3)

    def click_fx(S):
        x, z = CORNER_BOLTS[2]
        p = surf_point(x, z) + surf_normal(x, z) * 0.16   # (fx parts are parented to the pack: pack-local)
        sparks(S, tuple(p), 6, 11, length=0.08)
    S = build('b', parts, samples, state={'bolts': [1.0, 1.0, 0.55, 0.0]}, yaw=-22.0, fx=click_fx)
    S.camera(**cam)
    S.render(os.path.join(out, 'story_2_clicks.png'), W, H)
    # 3 scan: the line sweeps in the R152 hint colour, the core takes the same colour

    def scan_fx(S):
        scan_line(S, 0.18, MYTHIC_HINT)
    S = build('b', parts, samples, state={'bolts': [1, 1, 1, 1], 'core_tint': MYTHIC_HINT, 'trace_color': MYTHIC_HINT, 'trace_strength': 2.2, 'turbine': 0.6},
              yaw=-22.0, fx=scan_fx, lights_extra=[((0.0, -1.4, 0.2), 25, (0.9, 0.5, 1.0), 0.6)])
    S.camera(**cam)
    S.render(os.path.join(out, 'story_3_scan.png'), W, H)
    # 4 unlatch: the hazard seal flips open in the R152 tear groups (2, 3, 3) with a puff of steam each
    opened = [1, 1, 1, 1, 0.65, 0, 0, 0]

    def unlatch_fx(S):
        for s in range(8):
            if opened[s] > 0.5:
                x = -1.9 / 2 + (s + 0.5) * 1.9 / 8
                steam(S, (x, -0.06, 1.26), 5, 0.1, 0.22, 100 + s, alpha=0.3, rise=0.35)
    S = build('b', parts, samples, state={'bolts': [1, 1, 1, 1], 'core_tint': MYTHIC_HINT, 'trace_color': MYTHIC_HINT, 'trace_strength': 2.6, 'turbine': 1.4,
                                          'open_strips': opened}, yaw=-22.0, fx=unlatch_fx)
    S.camera(**cam)
    S.render(os.path.join(out, 'story_4_unlatch.png'), W, H)
    # 5 burst: steam ring, turbine stopped, the seed comes out (then the normal R152 card / scene)

    def burst_fx(S):
        rnd = random.Random(7)
        m = S.mat('steam', (240, 244, 248), 1.5, 0.4)
        for i in range(16):
            a = i * 2 * math.pi / 16
            r = 0.95 + rnd.uniform(-0.08, 0.1)
            S.add('SteamRing', 'sphere', Matrix.Translation((r * math.cos(a), r * math.sin(a) * 0.55, 1.15 + rnd.uniform(-0.05, 0.08))), (0.32, 0.32, 0.24), m)
        mech_seed(S, (0, -0.1, 2.05), 1.25)
    S = build('b', parts, samples, state={'bolts': [1, 1, 1, 1], 'open_strips': [1] * 8, 'no_antenna': True, 'core_tint': (120, 140, 150), 'trace_color': (60, 90, 100),
                                          'trace_strength': 0.6}, yaw=-22.0, fx=burst_fx, lights_extra=[((0.0, -1.5, 2.4), 30, (0.95, 0.9, 1.0), 0.5)])
    S.camera(yaw=0, pitch=7, dist=10.6, lens=85, target=(0, 0, 0.62))
    S.render(os.path.join(out, 'story_5_burst.png'), W, H)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--samples', type=int, default=48)
    ap.add_argument('--only', default='heroes,hotbar,story')
    ap.add_argument('--keys', default='today,a,b,c')
    ap.add_argument('--tiles', default='')
    a = ap.parse_args(argv)
    global ONLY_TILES
    ONLY_TILES = set(t for t in a.tiles.split(',') if t) or None
    os.makedirs(a.out, exist_ok=True)
    parts = load_today()
    jobs = a.only.split(',')
    if 'heroes' in jobs:
        job_heroes(a.out, parts, a.samples, a.keys.split(','))
    if 'hotbar' in jobs:
        job_hotbar(a.out, parts, a.samples)
    if 'story' in jobs:
        job_story(a.out, parts, a.samples)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
