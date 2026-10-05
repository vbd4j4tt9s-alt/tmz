"""TODAY's keepers, as close as this environment allows.

- Stages 1, 5, 7 (Timber Golem, Crystal Knight, Storm Colossus) and The Darkened are built from native Parts in the game's
  source (KeeperUpgradeData / VeiledKeeper81): every block, wedge and ball is drawn at its exact size and rest frame.
  Only the Roblox materials are approximated.
- Stages 2, 3, 4, 6 (Sand Snake, Ice Fang, Lava Dragon, Jungle King) are uploaded MeshParts whose mesh files cannot be
  downloaded here. They are STAND-INS: each rig group is the convex hull of that group's FloorSamples (points the game
  took from the real mesh), in an ASSUMED texture colour; the small untextured details (eyes, nose, teeth, vines) are
  rounded boxes at their exact Center / Size from KeeperRigConfig.
- Client accents (KeeperAccents: golem rune and mushrooms, snake rattle, the tiger's ice spines and R149 armour, knight
  shards, colossus cloud crown) are drawn from the real KeeperAccents output for the same pose.
"""
import math
import bmesh, bpy
from mathutils import Vector, Matrix
import kit
from kit import Geo, Palette, rb

ASSUMED = {  # texture colours are not readable here: assumed body colour per mesh keeper (labelled as such)
    2: {'*': (0.80, 0.64, 0.40)},
    3: {'*': (0.90, 0.92, 0.95)},
    4: {'*': (0.50, 0.15, 0.11), 'LeftWing': (0.36, 0.13, 0.11), 'RightWing': (0.36, 0.13, 0.11)},
    6: {'*': (0.27, 0.28, 0.27)},
}

# The Darkened's parts (VeiledKeeper81.Build): name, group, size, local frame (x, y, z, rx, ry, rz radians), colour, material, shape
BLACK, CLOTH, METAL, GLOW = (11 / 255, 12 / 255, 19 / 255), (25 / 255, 21 / 255, 35 / 255), (157 / 255, 135 / 255, 93 / 255), (204 / 255, 173 / 255, 1.0)


def veiled_parts():
    P = []

    def part(name, group, size, at=(0, 0, 0, 0, 0, 0), color=BLACK, mat='SmoothPlastic', shape='Block', cosmetic=False):
        P.append(dict(name=name, group=group, size=size, at=at, color=color, mat=mat, shape=shape, cosmetic=cosmetic))
    part('BroadChest', 'Torso', (5.5, 3.5, 2.4), color=CLOTH)
    part('SlimWaist', 'Waist', (2.35, 3.4, 1.65), color=CLOTH)
    part('SunkenCore', 'Torso', (.15, 2.7, .10), (0, 0, -1.23, 0, 0, 0), GLOW, 'Neon', cosmetic=True)
    part('Pelvis', 'Hip', (2.7, 2.0, 1.8))
    part('Neck', 'Neck', (1.1, 1.4, 1.1))
    part('VeiledMask', 'Head', (2.0, 3.0, 1.48))
    part('CleftLight', 'Head', (.085, 1.95, .06), (.02, 0, -.77, 0, 0, 0), GLOW, 'Neon', cosmetic=True)
    for side in (-1, 1):
        q = 'L' if side < 0 else 'R'
        part(q + 'Shoulder', 'Torso', (1.6, 1.6, 1.8), (side * 2.65, .95, 0, 0, 0, 0), CLOTH, shape='Ball')
        part(q + 'UpperArm', q + 'UpperArm', (1.25, 4.4, 1.35))
        part(q + 'Elbow', q + 'Forearm', (1.25, 1.25, 1.25), (0, 2.1, 0, 0, 0, 0), shape='Ball')
        part(q + 'Forearm', q + 'Forearm', (1.05, 4.2, 1.15))
        part(q + 'Hand', q + 'Hand', (1.3, 1.1, .85))
        part(q + 'Wrist', q + 'Hand', (.95, .6, .9), (0, .55, 0, 0, 0, 0), shape='Ball')
        for i in (1, 2, 3):
            part(q + 'LongFinger%d' % i, q + 'Hand', (.25, 1.55, .3), ((i - 2) * .4, -1.12, 0, -.06, 0, (i - 2) * .035))
        part(q + 'HipSocket', 'Hip', (1.6, 1.6, 1.6), (side * .95, -.65, 0, 0, 0, 0), shape='Ball')
        part(q + 'Thigh', q + 'Thigh', (1.4, 4, 1.55))
        part(q + 'Knee', q + 'Shin', (1.3, 1.3, 1.3), (0, 1.8, 0, 0, 0, 0), shape='Ball')
        part(q + 'Shin', q + 'Shin', (1.1, 3.6, 1.2))
        part(q + 'Foot', q + 'Foot', (1.4, .7, 2.6))
        part(q + 'WristBand', q + 'Forearm', (1.15, .16, 1.25), (0, -1.7, 0, 0, 0, 0), METAL, 'Metal', cosmetic=True)
        for rib in (1, 2, 3):
            part(q + 'Rib%d' % rib, 'Torso', (2.1, .12, .1), (side * 1.25, 1.25 - rib * .7, -1.23, 0, 0, side * .13), METAL, 'Metal', cosmetic=True)
    return P


def euler_xyz(rx, ry, rz):
    # CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
    return kit.Rx(rx) @ kit.Ry(ry) @ kit.Rz(rz)


class Built:
    """Objects of one keeper: group -> list of (object, rest translation matrix)."""

    def __init__(self, name):
        self.name = name
        self.groups = {}
        self.extra = []  # pose-dependent objects (accents), rebuilt per pose
        self.tris = 0

    def add(self, group, ob):
        self.groups.setdefault(group, []).append(ob)
        self.tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)

    def pose(self, frames, lift):
        G = Matrix.Translation((0, 0, lift))
        for group, obs in self.groups.items():
            F = kit.frame_b(frames[group]) if group in frames else Matrix.Identity(4)
            for ob in obs:
                ob.matrix_world = G @ F @ Matrix.Translation(Vector(ob['rest_center']))

    def objects(self):
        return [o for obs in self.groups.values() for o in obs] + self.extra


def _material_for(mat, rgb, transp=0.0):
    if mat == 'Neon':
        return kit.mat_flat('neon', rgb, emit=2.4)
    if mat == 'Metal':
        return kit.mat_flat('metal', rgb, rough=0.35, metallic=0.75)
    if mat in ('Glass', 'Ice'):
        return kit.mat_flat('glass', rgb, rough=0.15, transmission=0.4, spec=0.6)
    if mat in ('Slate', 'Basalt', 'Wood', 'Grass', 'LeafyGrass', 'Sandstone', 'Rock'):
        return kit.mat_flat('rough', rgb, rough=0.85, spec=0.2)
    return kit.mat_flat('plastic', rgb, rough=0.5)


def _single(coll, name, shape, size, color, mat, y0, y1):
    g = Geo(name)
    key = 'c'
    if shape in ('Ball', 'Ellipsoid'):
        kit.blob(g, (0, 0, 0), (size[0] / 2, size[1] / 2, size[2] / 2), key, seg=16, rings=10)
    elif shape == 'Wedge':
        kit.box(g, (0, 0, 0), size, key, wedge=True)
    elif shape in ('Cylinder', 'CylinderX'):
        kit.cylinder_x(g, (0, 0, 0), size, key)
    else:
        kit.box(g, (0, 0, 0), size, key)
    pal = Palette({key: tuple(color)})
    return kit.make_object(g, pal, coll, y0, y1, _material_for(mat, color), origin=None)


def build_native(stage, upg, coll, tree=False):
    """Stages 1 / 5 / 7: every native part at its exact size and rest frame. tree=True: the Timber Golem's sleeping
    tree disguise (TreeRest / TreeSize, which the game shows instead of the group frames while it sleeps)."""
    rig = upg[str(stage)]
    b = Built(rig['Name'])
    for i, p in enumerate(rig['Parts']):
        size = p['TreeSize'] if (tree and 'TreeSize' in p) else p['Size']
        rest = p['TreeRest'] if (tree and 'TreeRest' in p) else p['Rest']
        if tree and p['Name'] == 'Glowing slit':
            continue  # the eyes are hidden while it is a tree
        ob = _single(coll, '%s_%d' % (p['Group'], i), p['Shape'], size, p['Color'], p['Material'], -4, 30)
        M = kit.C @ kit.cf_matrix(rest) @ kit.CI
        # fold the rest frame into the mesh so the object behaves like a rig-space mesh with its origin at 0
        ob.data.transform(M)
        ob['rest_center'] = [0, 0, 0]
        b.add(p['Group'], ob)
    return b


def build_hull(stage, cfg, coll):
    """Stages 2 / 3 / 4 / 6: convex hull of each group's FloorSamples + exact small untextured details."""
    rig = cfg[str(stage)]
    b = Built(rig['Name'])
    cols = ASSUMED[stage]
    for group, pts in rig['FloorSamples'].items():
        bm = bmesh.new()
        for p in pts:
            bm.verts.new(rb(p))
        bmesh.ops.convex_hull(bm, input=bm.verts)
        me = bpy.data.meshes.new('hull_' + group)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new('%s_hull' % group, me)
        coll.objects.link(ob)
        rgb = cols.get(group, cols['*'])
        me.materials.append(kit.mat_flat('hull', rgb, rough=0.7))
        ob['rest_center'] = [0, 0, 0]
        b.add(group, ob)
    for p in rig['Parts']:
        s = p['Size']
        vol = s[0] * s[1] * s[2]
        if p['Textured'] or vol > 60 or max(s) > 9:
            continue
        g = Geo(p['Name'])
        kit.rbox(g, p['Center'], s, 'c', round_=0.5)
        mat = kit.mat_flat('eye', p['Color'], emit=2.4) if (p['EyeGlow'] or p['Glow']) else kit.mat_flat('detail', p['Color'], rough=0.5)
        ob = kit.make_object(g, Palette({'c': tuple(p['Color'])}), coll, -4, 10, mat, origin=None)
        ob['rest_center'] = [0, 0, 0]
        b.add(p['Group'], ob)
    return b


def build_veiled(coll):
    b = Built('The Darkened')
    for p in veiled_parts():
        ob = _single(coll, p['name'], p['shape'], p['size'], p['color'], p['mat'], -5, 14)
        x, y, z, rx, ry, rz = p['at']
        M = kit.C @ (kit.T(x, y, z) @ euler_xyz(rx, ry, rz)) @ kit.CI
        ob.data.transform(M)
        ob['rest_center'] = [0, 0, 0]
        b.add(p['group'], ob)
    return b


def add_accents(b, items, coll):
    """Accent / gear parts already posed by the real KeeperAccents (absolute rig-space frames)."""
    for o in b.extra:
        bpy.data.objects.remove(o, do_unlink=True)
    b.extra = []
    for i, it in enumerate(items or []):
        ob = _single(coll, 'accent_%d' % i, it['sh'], it['s'], it['c'], it['mat'], -4, 30)
        if it['t'] > 0.05:
            ob.data.materials[0] = kit.mat_flat('acc_t', it['c'], rough=0.3, transmission=0.3 if it['mat'] in ('Glass', 'Ice') else 0.0, alpha=1 - it['t'] * 0.6)
        ob['frame'] = it['m']
        b.extra.append(ob)


def pose_accents(b, lift):
    G = Matrix.Translation((0, 0, lift))
    for ob in b.extra:
        ob.matrix_world = G @ kit.frame_b(ob['frame'])
