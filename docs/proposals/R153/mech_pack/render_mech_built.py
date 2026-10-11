"""R153 Mech pack as BUILT (look B): Blender tiles of the REAL parts the game builds (built_parts.json, dumped on the Roblox mock by dump_mech_built.luau:
MechPackArt153 through SeedPackVisuals.Bag on the owner's templates, on VerityPouch151's generated flat pouch), next to TODAY (R152: today_parts.json on
R151's stand-in pouch, as in the proposal sheet). Reuses render_mech_pack.py's scene, materials, lights and camera. Nothing here is game code.

Unlike the proposal's tiles, nothing is placed by hand: every part is drawn at its own size / CFrame / colour / material (Roblox pack frame -> preview frame
by render_mech_pack.M_RB), both faces as built (no mirroring), the pouch as its real generated triangles.

Usage (the bpy venv, from the repo root):
  .../bpyenv/bin/python docs/proposals/R153/mech_pack/render_mech_built.py --built <built_parts.json> --out <tile dir> [--samples 32]
"""
import argparse
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import render_mech_pack as RM  # noqa: E402  (bpy, R151's stand-in pouch, the proposal's Scene)

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402


def wedge_mesh(S):
    """Roblox's WedgePart in a unit box: the slope runs from the top-back edge (+Y, +Z) down to the bottom-front edge (-Y, -Z)."""
    if 'wedge' in S.meshes:
        return S.meshes['wedge']
    me = bpy.data.meshes.new('wedge')
    v = [(-.5, -.5, -.5), (-.5, -.5, .5), (-.5, .5, .5), (.5, -.5, -.5), (.5, -.5, .5), (.5, .5, .5)]
    f = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (0, 3, 5, 2)]
    me.from_pydata(v, [], f)
    me.update()
    me.materials.append(None)
    S.meshes['wedge'] = me
    return me


def material(S, p, overrides):
    color = tuple(overrides.get(p['name'], p['color']))
    m = p['material']
    if m == 'Neon':
        return S.mat('neon', color, 3.0)
    if m == 'Metal':
        return S.mat('metal', color)
    return S.mat('plastic', color)


def design_built(S, built, overrides=None, led=6.0):
    overrides = overrides or {}
    M = RM.M_RB
    # the pouch: its real triangles, Roblox root frame -> preview frame
    pv = built['pouch']
    me = bpy.data.meshes.new('pouch')
    me.from_pydata([tuple(M @ Vector(p)) for p in pv['v']], [], [tuple(f) for f in pv['f']])
    me.update()
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(S.mat('paint', tuple(pv['color'])))
    ob = bpy.data.objects.new('pouch', me)
    S.sc.collection.objects.link(ob)
    ob.parent = S.root
    for p in built['parts']:
        if p['shape'] == 'Mesh' or p['t'] >= 0.99:
            continue
        cols = [M @ Vector((p['r'][0][i], p['r'][1][i], p['r'][2][i])) for i in range(3)]
        c = M @ Vector(p['p'])
        mat4 = Matrix(((cols[0].x, cols[1].x, cols[2].x, c.x), (cols[0].y, cols[1].y, cols[2].y, c.y), (cols[0].z, cols[1].z, cols[2].z, c.z), (0, 0, 0, 1)))
        mt = material(S, p, overrides)
        if p['name'] == 'AntennaLED':
            mt = S.mat('neon', tuple(p['color']), led)
        if p['class'] == 'WedgePart':
            o = bpy.data.objects.new(p['name'], wedge_mesh(S))
            S.sc.collection.objects.link(o)
            o.parent = S.root
            o.matrix_basis = mat4 @ Matrix.Diagonal((p['size'][0], p['size'][1], p['size'][2], 1.0))
            o.material_slots[0].link = 'OBJECT'
            o.material_slots[0].material = mt
            continue
        kind = {'Cylinder': 'cylX', 'Ball': 'sphere'}.get(p['shape'], 'cube')
        S.add(p['name'], kind, mat4, p['size'], mt)


def build_built(built, samples, yaw, hum=True, overrides=None):
    S = RM.Scene(samples)
    design_built(S, built, overrides)
    S.root.rotation_euler = (0, 0, math.radians(yaw))
    extra = []
    if hum:   # the held hum light (MechHumLight at the pouch's centre: a soft cyan PointLight)
        for f in built.get('fx', []):
            if f['name'] == 'MechHum':
                q = RM.M_RB @ Vector(f['p'])
                rot = Matrix.Rotation(math.radians(yaw), 3, 'Z')
                extra.append((tuple(rot @ (q + Vector((0, -0.75, 0)))), 22, (0.35, 0.88, 1.0), 0.6))
    S.lights(extra=extra)
    return S


def build_today(parts, samples, yaw):
    S = RM.Scene(samples)
    RM.design_today(S, parts, {})
    S.mirror_back()
    S.root.rotation_euler = (0, 0, math.radians(yaw))
    S.lights()
    return S


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--built', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--samples', type=int, default=32)
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    built = json.load(open(a.built, encoding='utf-8'))
    today = RM.load_today()
    cam = dict(yaw=0, pitch=7, dist=9.0, lens=85, target=(0, 0, 0.12))
    # today and built B: front three-quarter, side; built B also from behind (both faces carry the design)
    S = build_today(today, a.samples, -24.0)
    S.camera(**cam)
    S.render(os.path.join(a.out, 'built_today_hero.png'), 760, 900)
    S = build_today(today, a.samples, -90.0)
    S.camera(yaw=0, pitch=0, dist=10.5, lens=85, target=(0, 0, 0.06))
    S.render(os.path.join(a.out, 'built_today_side.png'), 300, 640)
    S = build_built(built, a.samples, -24.0)
    S.camera(**dict(cam, target=(0, 0, 0.18)))
    S.render(os.path.join(a.out, 'built_b_hero.png'), 760, 900)
    S = build_built(built, a.samples, -90.0)
    S.camera(yaw=0, pitch=0, dist=10.5, lens=85, target=(0, 0, 0.12))
    S.render(os.path.join(a.out, 'built_b_side.png'), 300, 640)
    S = build_built(built, a.samples, 180 - 24.0)
    S.camera(**dict(cam, target=(0, 0, 0.18)))
    S.render(os.path.join(a.out, 'built_b_back.png'), 760, 900)
    # hotbar icons (ItemPictures' view: nearly straight on); rendered at 300 and shown at the hotbar's size by the composer
    S = build_today(today, max(24, a.samples // 2), -20.0)
    S.camera(yaw=0, pitch=6, dist=10.5, lens=85, target=(0, 0, 0.1))
    S.render(os.path.join(a.out, 'built_icon_today.png'), 300, 300)
    S = build_built(built, max(24, a.samples // 2), -20.0, hum=False)
    S.camera(yaw=0, pitch=6, dist=11.2, lens=85, target=(0, 0, 0.16))
    S.render(os.path.join(a.out, 'built_icon_b.png'), 300, 300)


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
