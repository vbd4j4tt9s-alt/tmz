"""R155 Mech pack coats: Blender tiles of the REAL parts the game builds for a plain / Gold / Diamond Mech pack (dump_mech_coats.luau: SeedPackVisuals.Bag, MechPackArt153,
MechPackFx153, PlantVisuals on the owner's templates, dumped on the Roblox mock): the pack, the hotbar icon, the held pack, a frame of the opening, a Gold and a Diamond Mech plant
with their coated fruit, the seeds. Reuses docs/proposals/R153/mech_pack/render_mech_pack.py's scene, lights and camera. Nothing here is game code.

Every part is drawn at its own size / CFrame / colour / material (Roblox frame -> preview frame by render_mech_pack.M_RB), the pouch as its real generated triangles. A Roblox Metal part
with Reflectance is polished metal; a Glass part with Transparency is a tinted transmissive solid (approximate: no Future lighting, bloom imitated).

Usage (the bpy venv, from the repo root):
  .../bpyenv/bin/python docs/proposals/R155/preview/render_mech_coats.py --dump <dump.txt> --out <tile dir> [--samples 32]
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R153', 'mech_pack'))
import render_mech_pack as RM  # noqa: E402
import render_mech_built as RB  # noqa: E402  (wedge mesh)

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

lin = RM.lin


def load(dump):
    items = []
    for line in open(dump, encoding='utf-8'):
        if line.startswith('ITEM '):
            items.append(json.loads(line[5:]))
    return items


def glass(S, color, t):
    """A Roblox Glass part: the coat's ice colour, transmissive, a little rough, slightly reflective (Reflectance .28)."""
    key = ('ice', tuple(color), round(t, 2))
    if key in S.mats:
        return S.mats[key]
    m = bpy.data.materials.new('ice_%s_%s' % ('_'.join(map(str, color)), t))
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(color)
    b.inputs['Roughness'].default_value = 0.06
    b.inputs['IOR'].default_value = 1.45
    for name in ('Transmission Weight', 'Transmission'):
        if name in b.inputs:
            b.inputs[name].default_value = 0.55 + 2.5 * (0.2 - min(t, 0.2))   # t .10 -> .80, .20 -> .55
            break
    b.inputs['Specular IOR Level'].default_value = 0.8 if 'Specular IOR Level' in b.inputs else 0.5
    S.mats[key] = m
    return m


def metal(S, color, refl):
    """Metal: with Reflectance (a coat's .38 gold) it is polished."""
    key = ('metalr', tuple(color), round(refl, 2))
    if key in S.mats:
        return S.mats[key]
    m = bpy.data.materials.new('metal_%s' % '_'.join(map(str, color)))
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = lin(color)
    b.inputs['Metallic'].default_value = 0.92
    b.inputs['Roughness'].default_value = 0.30 - 0.25 * min(refl, 0.4)   # reflectance .38 -> .20
    S.mats[key] = m
    return m


def material(S, p):
    color = tuple(p['color'])
    m = p['material']
    t = p.get('t', 0)
    refl = p.get('refl', 0) or 0
    if m == 'Neon':
        return S.mat('neon', color, 3.0 if t < .5 else 2.0, 1.0 - t)
    if m == 'Glass':
        return glass(S, color, t)
    if m == 'Metal':
        return metal(S, color, refl)
    return S.mat('plastic', color)


def add_parts(S, parts, skip=(), led=None):
    M = RM.M_RB
    for p in parts:
        if p['shape'] == 'Mesh' or p['name'] in skip:
            continue
        if p['material'] != 'Glass' and p['t'] >= 0.99:
            continue
        cols = [M @ Vector((p['r'][0][i], p['r'][1][i], p['r'][2][i])) for i in range(3)]
        c = M @ Vector(p['p'])
        mat4 = Matrix(((cols[0].x, cols[1].x, cols[2].x, c.x), (cols[0].y, cols[1].y, cols[2].y, c.y), (cols[0].z, cols[1].z, cols[2].z, c.z), (0, 0, 0, 1)))
        mt = material(S, p)
        if p['name'] == 'AntennaLED':
            mt = S.mat('neon', tuple(p['color']), led or 6.0)
        size = p['size']
        if p['class'] == 'WedgePart':
            o = bpy.data.objects.new(p['name'], RB.wedge_mesh(S))
            S.sc.collection.objects.link(o)
            o.parent = S.root
            o.matrix_basis = mat4 @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
            o.material_slots[0].link = 'OBJECT'
            o.material_slots[0].material = mt
            continue
        kind = {'Cylinder': 'cylX', 'Ball': 'sphere'}.get(p['shape'], 'cube')
        if p.get('mesh') and p['mesh'].get('type') == 'Sphere':   # a stretched ellipsoid (SpecialMesh sphere)
            kind = 'sphere'
            sc = p['mesh'].get('scale') or [1, 1, 1]
            size = [size[0] * sc[0], size[1] * sc[1], size[2] * sc[2]]
        S.add(p['name'], kind, mat4, size, mt)


def add_pouch(S, item):
    pv = item['pouch']
    M = RM.M_RB
    me = bpy.data.meshes.new('pouch')
    me.from_pydata([tuple(M @ Vector(p)) for p in pv['v']], [], [tuple(f) for f in pv['f']])
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    mt = glass(S, tuple(pv['color']), pv['t']) if pv['material'] == 'Glass' else (metal(S, tuple(pv['color']), pv['refl']) if pv['material'] == 'Metal' and pv['refl'] > 0 else S.mat('paint', tuple(pv['color'])))
    me.materials.append(mt)
    ob = bpy.data.objects.new('pouch', me)
    S.sc.collection.objects.link(ob)
    ob.parent = S.root


def hum_lights(item, yaw):
    out = []
    for f in item.get('fx', []):
        if f['name'] == 'MechHum':
            q = RM.M_RB @ Vector(f['p'])
            rot = Matrix.Rotation(math.radians(yaw), 3, 'Z')
            out.append((tuple(rot @ (q + Vector((0, -0.75, 0)))), 22, (0.35, 0.88, 1.0), 0.6))
    return out


def pack_scene(item, samples, yaw, hum=False, led=6.0):
    S = RM.Scene(samples)
    add_pouch(S, item)
    add_parts(S, item['parts'], led=led)
    S.root.rotation_euler = (0, 0, math.radians(yaw))
    S.lights(extra=hum_lights(item, yaw) if hum else None)
    return S


def held_scene(item, samples, yaw):
    S = RM.Scene(samples)
    add_pouch(S, item)
    add_parts(S, item['parts'])
    # the carrier: its torso, head and root as plain grey-blue boxes in the pack's frame (the pack hangs on the torso's front)
    M = RM.M_RB
    for c in item['char']:
        if c['name'] == 'HumanoidRootPart':
            continue
        cols = [M @ Vector((c['r'][0][i], c['r'][1][i], c['r'][2][i])) for i in range(3)]
        cc = M @ Vector(c['p'])
        mat4 = Matrix(((cols[0].x, cols[1].x, cols[2].x, cc.x), (cols[0].y, cols[1].y, cols[2].y, cc.y), (cols[0].z, cols[1].z, cols[2].z, cc.z), (0, 0, 0, 1)))
        S.add('carrier_' + c['name'], 'cube', mat4, c['size'], S.mat('plastic', (64, 76, 100)))
    S.root.rotation_euler = (0, 0, math.radians(yaw))
    S.lights(extra=hum_lights(item, yaw))
    return S


def plain_scene(item, samples, yaw):
    S = RM.Scene(samples)
    add_parts(S, item['parts'])
    S.root.rotation_euler = (0, 0, math.radians(yaw))
    S.lights()
    return S


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--dump', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--samples', type=int, default=32)
    ap.add_argument('--tiles', default='', help='re-render only these tile files (comma separated)')
    a = ap.parse_args(argv)
    RM.ONLY_TILES = set(t for t in a.tiles.split(',') if t) or None
    os.makedirs(a.out, exist_ok=True)
    items = load(a.dump)

    def get(kind, coat, extra=None):
        for it in items:
            if it['kind'] == kind and it['coat'] == coat and (extra is None or it.get('seed') == extra):
                return it
        raise KeyError((kind, coat, extra))

    hero = dict(yaw=0, pitch=7, dist=9.0, lens=85, target=(0, 0, 0.18))
    for coat in ('None', 'Gold', 'Diamond'):
        tag = coat.lower() if coat != 'None' else 'plain'
        pack = get('pack', coat)
        S = pack_scene(pack, a.samples, -24.0, hum=True)
        S.camera(**hero)
        S.render(os.path.join(a.out, 'hero_%s.png' % tag), 760, 900)
        S = pack_scene(pack, max(24, a.samples // 2), -20.0, led=6.0)
        S.camera(yaw=0, pitch=6, dist=11.2, lens=85, target=(0, 0, 0.16))
        S.render(os.path.join(a.out, 'icon_%s.png' % tag), 300, 300)
        held = get('held', coat)
        S = held_scene(held, a.samples, -34.0)
        S.camera(yaw=0, pitch=10, dist=15.0, lens=85, target=(0, 0.4, 0.5))
        S.render(os.path.join(a.out, 'held_%s.png' % tag), 700, 800)
        op = get('open', coat)
        S = pack_scene(op, a.samples, -24.0)
        S.camera(yaw=0, pitch=7, dist=9.4, lens=85, target=(0, 0, 0.18))
        S.render(os.path.join(a.out, 'open_%s.png' % tag), 760, 900)
    for seed, coat, tag, height in (('PlasmaPepperSeed', 'Gold', 'plant_gold', 6.6), ('PlasmaPepperSeed', 'Diamond', 'plant_diamond', 6.6)):
        it = get('plant', coat, seed)
        S = plain_scene(it, a.samples, -18.0)
        S.camera(yaw=0, pitch=9, dist=height * 3.4 + 5, lens=85, target=(0, 0, height * 0.46))
        S.render(os.path.join(a.out, tag + '.png'), 760, 900)
    for seed in ('PlasmaPepperSeed',):
        for coat in ('None', 'Gold', 'Diamond'):
            it = get('seed', coat, seed)
            S = plain_scene(it, max(24, a.samples // 2), -20.0)
            S.camera(yaw=0, pitch=14, dist=12, lens=85, target=(0, 0, 0.4))
            S.render(os.path.join(a.out, 'seed_%s_%s.png' % (seed, coat.lower())), 360, 360)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
