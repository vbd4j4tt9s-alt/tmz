"""Build every proposed keeper in Blender, render the preview panels in Cycles (CPU), export one FBX per keeper.

Usage (bpy 4.5 Python):  python render_all.py -- POSES_JSON PANEL_DIR OUT_DIR [what ...]
  what: any of fbx sheets faces ba lineup (default: all). KEEPERS=1,6 limits the keepers, SAMPLES=24 sets samples,
  SKIP_EXISTING=1 keeps panels already rendered.
Writes PANEL_DIR/*.png (raw renders), OUT_DIR/fbx/*.fbx + *_atlas.png + *.json, and PANEL_DIR/meta.json for
compose_sheets.py.
"""
import sys, os, json, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view
import kit, today, proposed, assemble, data
from faces import STATES
from connectivity import golem_tree

args = sys.argv[sys.argv.index('--') + 1:]
POSES, PANELS, OUT = args[0], args[1], args[2]
WHAT = set(args[3:]) or {'fbx', 'sheets', 'faces', 'ba', 'lineup'}
os.makedirs(PANELS, exist_ok=True)
os.makedirs(os.path.join(OUT, 'fbx'), exist_ok=True)
CFG, UPG, PZ = data.load_cfg(), data.load_upg(), data.load_poses(POSES)
SAMPLES = int(os.environ.get('SAMPLES', '24'))
KEEP = [int(x) for x in os.environ.get('KEEPERS', '').split(',') if x] or proposed.ORDER
SKIP = os.environ.get('SKIP_EXISTING') == '1'
GROUND = {1: (0.55, 0.74, 0.44), 6: (0.50, 0.70, 0.42), 2: (0.95, 0.84, 0.58), 3: (0.84, 0.90, 0.97), 4: (0.42, 0.38, 0.40),
          5: (0.78, 0.75, 0.92), 7: (0.58, 0.63, 0.74), 0: (0.45, 0.42, 0.55)}
RETAINED_ACCENTS = {2}  # only the snake's rattle stays a client accent; the knight's orbiting shards and the colossus cloud are retired
META_PATH = os.path.join(PANELS, 'meta.json')
META = json.load(open(META_PATH)) if os.path.exists(META_PATH) else {}


def save_meta():
    json.dump(META, open(META_PATH, 'w'), indent=1)


def lift(st):
    return 5.0 if st == 0 else 4.0


def frames_for(st, pose):
    return PZ['veiled'][pose] if st == 0 else PZ['stages'][str(st)][pose]


def scene(st, ground=None):
    sc = kit.reset_scene()
    sc.cycles.samples = SAMPLES
    kit.stage_lighting(sc, ground_rgb=ground or GROUND[st], radius=1500)
    return sc


def build(which, st, pose, coll, state='Idle'):
    """which: 'new' (proposed) or 'today'. Returns (Built, KeeperModel or None), posed, face state shown."""
    k = None
    if which == 'new':
        k = proposed.BUILDERS[st]()
        b = assemble.build_proposed(k, coll)
        if st == 1 and pose == 'sleep':
            golem_tree(b, k, UPG, lift(1))
        else:
            b.pose(frames_for(st, pose), lift(st))
        if st in RETAINED_ACCENTS:
            today.add_accents(b, PZ['accents'][str(st)][pose], coll)
            today.pose_accents(b, lift(st))
        assemble.show_state(b, k, state)
    else:
        if st == 0:
            b = today.build_veiled(coll)
        elif st in (1, 5, 7):
            b = today.build_native(st, UPG, coll, tree=(st == 1 and pose == 'sleep'))
        else:
            b = today.build_hull(st, CFG, coll)
        if st == 1 and pose == 'sleep':
            b.pose({}, lift(st))
        else:
            b.pose(frames_for(st, pose), lift(st))
        if str(st) in PZ['accents']:
            today.add_accents(b, PZ['accents'][str(st)][pose], coll)
            today.pose_accents(b, lift(st))
    return b, k


def shown(b):
    return [o for o in b.objects() if not o.hide_render]


def shoot(sc, objs, path, az, el, w, h, lens=50, margin=0.05):
    cam = kit.make_camera(sc, lens=lens)
    pts = kit.sample_points(objs, step=2)
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    kit.frame_points(sc, cam, pts, (mn + mx) / 2, az, el, margin=margin, w=w, h=h)
    if kit.billboard(sc, cam):   # the turned Z may reach further out: frame again (same angles, so it stays turned)
        pts = kit.sample_points(objs, step=2)
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        kit.frame_points(sc, cam, pts, (mn + mx) / 2, az, el, margin=margin, w=w, h=h)
    kit.render(sc, path, w, h)
    return cam


PANEL_SET = [('front', 'stand', 'Idle', 0, 6), ('three_quarter', 'stand', 'Idle', 38, 12), ('side', 'stand', 'Idle', 90, 5),
             ('back', 'stand', 'Idle', 180, 10), ('chase', 'run', 'Chase', 18, 3), ('windup', 'cock', 'Attack', 52, 8),
             ('strike', 'strike', 'Attack', 62, 8), ('asleep', 'sleep', 'Asleep', 40, 20)]
FACE_SET = [('Idle', 'stand'), ('Chase', 'run'), ('Attack', 'strike'), ('Asleep', 'sleep'), ('Gloat', 'stand')]


def keeper_sheets():
    for st in KEEP:
        k0 = proposed.BUILDERS[st]()
        key = k0.key
        for name, pose, state, az, el in PANEL_SET:
            path = os.path.join(PANELS, '%s_%s.png' % (key, name))
            if SKIP and os.path.exists(path):
                continue
            sc = scene(st)
            b, k = build('new', st, pose, sc.collection, state)
            shoot(sc, shown(b), path, az, el, 520, 390)
            print('panel', path, flush=True)
        m = META.setdefault(key, {})
        m.update(name=k0.name, stage=st, biome=proposed.BIOME[st], tris=k0.tris(), tris_visible=k0.tris_visible(),
                 parts=len(list(k0.parts())), groups=sorted({g for g, _, _, _ in k0.parts()}), personality=k0.personality,
                 fidget=k0.fidget, fx=k0.fx_notes)
        save_meta()


def face_closeups():
    """Portrait of the head in each face state, in the pose that state is shown in, from in front of the face."""
    for st in KEEP:
        k0 = proposed.BUILDERS[st]()
        for state, pose in FACE_SET:
            path = os.path.join(PANELS, 'face_%s_%s.png' % (k0.key, state))
            if SKIP and os.path.exists(path):
                continue
            if st in (1, 6, 0) and pose == 'sleep':
                pose = 'stand'   # the golem sleeps as a tree (face hidden), the gorilla lies on its side and The Darkened
                #                  curls up face-down: show the sleeping face upright
            sc = scene(st)
            b, k = build('new', st, pose, sc.collection, state)
            for o in b.objects():
                if o.get('piece') == 'Z':
                    o.hide_render = True   # close-ups are about the face; the sleep 'Z' is in each sheet's asleep view
            heads = [o for o in shown(b) if o.get('group') == 'Head' and o.get('kind') in ('eyes', 'face')]
            pts_e = kit.sample_points(heads, step=1)
            cen = sum(pts_e, Vector()) / len(pts_e)
            span = max((p - cen).length for p in pts_e)
            near = [o for o in shown(b) if o.get('group') in ('Head', 'Jaw') and o.get('kind') != 'fx' and o.get('piece') != 'Canopy']
            pts = [p for p in kit.sample_points(near, step=1) if (p - cen).length < span * 1.9]
            hf = [o for o in b.objects() if o.get('group') == 'Head'][0].matrix_world
            fwd = (hf.to_3x3() @ Vector((0, 1, 0))).normalized()   # roblox -Z (face) -> blender +Y, through the head frame
            az = math.degrees(math.atan2(fwd.x, fwd.y)) + 22
            el = math.degrees(math.asin(max(-0.6, min(0.6, fwd.z)))) + 8
            cam = kit.make_camera(sc, lens=60)
            kit.frame_points(sc, cam, pts, cen, az, el, margin=0.06, w=360, h=360)
            kit.billboard(sc, cam)
            kit.render(sc, path, 360, 360)
            print('face', path, flush=True)


def before_after():
    for st in KEEP:
        sc = scene(st)
        bt, _ = build('today', st, 'stand', sc.collection)
        bn, k = build('new', st, 'stand', sc.collection, 'Idle')
        pl = kit.player_standin(sc.collection, x=0, y_b=0)
        mn, mx = kit.world_bounds(shown(bt) + shown(bn))
        pl.matrix_world = Matrix.Translation((mn.x - 3.5, mx.y - 1.0, 0)) @ Matrix.Translation(Vector(pl['rest_center']))
        cam = kit.make_camera(sc, lens=50)
        pts = kit.sample_points(shown(bt) + shown(bn) + [pl], step=2)
        mnp = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mxp = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        kit.frame_points(sc, cam, pts, (mnp + mxp) / 2, 38, 12, margin=0.05, w=520, h=410)
        new_vis = {o.name: o.hide_render for o in bn.objects()}
        for which in ('today', 'new'):
            for o in bt.objects():
                o.hide_render = which != 'today'
            for o in bn.objects():
                o.hide_render = True if which == 'today' else new_vis[o.name]
            kit.render(sc, os.path.join(PANELS, 'ba_%s_%s.png' % (k.key, which)), 520, 410)
        META.setdefault(k.key, {})['today_tris_standin'] = bt.tris
        save_meta()
        print('ba', k.key, flush=True)


def lineup():
    """All keepers in a row (each turned to a 3/4 view), a 5-stud player beside each, orthographic so sizes compare.
    The camera looks from +Y (the keepers' front), so +X is on the image's left: the row runs toward -X."""
    for which in ('new', 'today'):
        sc = scene(3, ground=(0.80, 0.84, 0.78))
        cursor = 0.0
        info = []
        for st in proposed.ORDER:
            b, k = build(which, st, 'stand', sc.collection, 'Idle')
            yaw = Matrix.Rotation(math.radians(-38), 4, 'Z')
            objs = b.objects()
            for o in objs:
                o.matrix_world = yaw @ o.matrix_world
            mn, mx = kit.world_bounds(shown(b))
            wdt = mx.x - mn.x
            off = Vector((cursor - mx.x, -(mn.y + mx.y) / 2, 0))
            for o in objs:
                o.matrix_world = Matrix.Translation(off) @ o.matrix_world
            kit.player_standin(sc.collection, x=cursor - wdt - 1.6, y_b=(mx.y - mn.y) / 2 + 1.5)
            info.append({'stage': st, 'xa': cursor + 0.0, 'xb': cursor - wdt - 3.0, 'height': mx.z - mn.z, 'name': b.name})
            cursor -= wdt + 3.2 + 7.0
        span = -cursor
        W, H = 3200, 900
        sc.render.resolution_x, sc.render.resolution_y = W, H
        cam = kit.make_camera(sc)
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = span * 1.01
        half = cam.data.ortho_scale * H / W / 2
        el = math.radians(5)
        cx = -span / 2 + 3.0
        cz = half * 0.86
        cam.location = Vector((cx, 600 * math.cos(el), cz + 600 * math.sin(el)))
        cam.rotation_euler = (Vector((cx, 0, cz)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        cam.data.clip_end = 3000
        bpy.context.view_layer.update()
        a = world_to_camera_view(sc, cam, Vector((cx, 0, 0)))
        bb = world_to_camera_view(sc, cam, Vector((cx, 0, 10)))
        ppx = (bb.y - a.y) * H / 10.0
        for it in info:
            p0 = world_to_camera_view(sc, cam, Vector((it['xa'], 0, 0))).x * W
            p1 = world_to_camera_view(sc, cam, Vector((it['xb'], 0, 0))).x * W
            it['px0'], it['px1'] = min(p0, p1), max(p0, p1)
        kit.render(sc, os.path.join(PANELS, 'lineup_%s.png' % which), W, H)
        META['lineup_%s' % which] = {'px_per_stud': ppx, 'ground_y': (1 - a.y) * H, 'items': info, 'W': W, 'H': H}
        save_meta()
        print('lineup', which, flush=True)


def export_fbx():
    """One FBX per keeper: a mesh object per part (origin = its bounding-box centre, placed where it sits on the rig,
    1 unit = 1 stud, -Z forward / Y up like Roblox), the palette atlas embedded, plus a JSON manifest per keeper.
    Effects (fire, lightning, the sleep Z) are not exported: they are particles / beams / a billboard in game."""
    for st in KEEP:
        sc = kit.reset_scene()
        k = proposed.BUILDERS[st]()
        atlas_path = os.path.join(OUT, 'fbx', 'keeper_%s_atlas.png' % k.key)
        img = k.pal.write_atlas(atlas_path)
        b = assemble.build_proposed(k, sc.collection, studs=False, fx=False)
        mat = kit.mat_atlas('Atlas_%s' % k.key, img)
        for ob in b.objects():
            ob.data.materials.clear()
            if ob.get('kind') in ('main', 'face'):
                ob.data.materials.append(mat)
                for p in ob.data.polygons:
                    p.material_index = 0
            else:
                rgb = k.eye_rgb if ob['kind'] == 'eyes' else k.glow_rgb.get(ob['group'], k.glow_rgb.get('*', (1, 1, 1)))
                if ob['kind'] == 'eyes' and ob['piece'] in k.state_rgb:
                    rgb = k.state_rgb[ob['piece']][0]
                ob.data.materials.append(kit.mat_flat_export('%s_%s' % (ob['kind'], k.key), rgb))
            ob.matrix_world = Matrix.Translation(Vector(ob['rest_center']))
        bpy.ops.object.select_all(action='DESELECT')
        for ob in b.objects():
            ob.select_set(True)
        path = os.path.join(OUT, 'fbx', 'keeper_%s.fbx' % k.key)
        bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, axis_forward='-Z', axis_up='Y',
                                 bake_space_transform=True, apply_unit_scale=True, global_scale=1.0, mesh_smooth_type='FACE',
                                 path_mode='COPY', embed_textures=True, colors_type='SRGB', add_leaf_bones=False)
        size = os.path.getsize(path)
        if size > 5 * 1024 * 1024:
            os.remove(path)
            print('FBX over 5 MB, skipped', path)
        manifest(k, b, st, path if os.path.exists(path) else None)
        print('fbx', path, size, flush=True)


def _old_bounds(st, group):
    if st == 0:  # The Darkened: union of today's part boxes in that group (group-local space)
        mn, mx = [1e9] * 3, [-1e9] * 3
        for p in today.veiled_parts():
            if p['group'] != group:
                continue
            for i in range(3):
                mn[i] = min(mn[i], p['at'][i] - p['size'][i] / 2)
                mx[i] = max(mx[i], p['at'][i] + p['size'][i] / 2)
        return [mn, mx] if mn[0] < 1e8 else None
    rig = UPG[str(st)] if str(st) in UPG else CFG[str(st)]
    return rig['Bounds'].get(group)


def manifest(k, b, st, fbx):
    """What the config would need: per part name, group, centre, size (Roblox studs, rig space), triangles, flags;
    per group the new bounding box against today's Bounds; hull points that could replace FloorSamples."""
    import bmesh
    parts, groups = [], {}
    for ob in b.objects():
        me = ob.data
        cen = Vector(ob['rest_center'])
        vs = [kit.CI @ (v.co + cen) for v in me.vertices]
        mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        kind, piece = ob['kind'], ob['piece']
        entry = {'Name': ob.name, 'Group': ob['group'], 'Kind': kind, 'Center': [round(c, 4) for c in (mn + mx) / 2],
                 'Size': [round(c, 4) for c in (mx - mn)], 'Triangles': tris, 'EyeGlow': kind == 'eyes', 'Glow': kind == 'glow'}
        if kind == 'face' or (kind == 'eyes' and piece in STATES):
            entry['FaceState'] = piece
        if kind == 'eyes':
            entry['Color'] = list(k.state_rgb[piece][0] if piece in k.state_rgb else k.eye_rgb)
        elif kind == 'glow':
            entry['Color'] = list(k.glow_rgb.get(ob['group'], k.glow_rgb.get('*')))
        if st == 1:
            key = (ob['group'], piece or None) if kind == 'main' else (ob['group'], 'Face' if kind == 'face' else kind.capitalize())
            entry['TreeFollows'] = k.tree_map.get(key)
        if st == 0:
            entry['Cosmetic'] = (ob['group'], piece or None) in k.cosmetic or kind in ('glow', 'face')
        if (ob['group'], piece or None) in k.floating or (ob['group'], kind.capitalize()) in k.floating:
            entry['FloatingByDesign'] = True
        parts.append(entry)
        g = groups.setdefault(ob['group'], {'min': [1e9] * 3, 'max': [-1e9] * 3, 'pts': []})
        if entry.get('Cosmetic') and st == 0:
            continue
        for i in range(3):
            g['min'][i] = min(g['min'][i], mn[i])
            g['max'][i] = max(g['max'][i], mx[i])
        if kind == 'main':
            g['pts'].extend(vs)
    out_groups = {}
    for name, g in groups.items():
        old = _old_bounds(st, name)
        over = None
        if old and g['min'][0] < 1e8:
            over = max(max(old[0][i] - g['min'][i], g['max'][i] - old[1][i]) for i in range(3))
        samples = []
        if g['pts']:
            bm = bmesh.new()
            for p in g['pts']:
                bm.verts.new(p)
            hull = bmesh.ops.convex_hull(bm, input=bm.verts)
            hv = [v for v in hull['geom'] if isinstance(v, bmesh.types.BMVert)]
            step = max(1, len(hv) // 48)
            samples = [[round(c, 3) for c in hv[i].co] for i in range(0, len(hv), step)]
            bm.free()
        out_groups[name] = {'Bounds': [[round(c, 3) for c in g['min']], [round(c, 3) for c in g['max']]] if g['min'][0] < 1e8 else None,
                            'TodayBounds': old, 'Overshoot': None if over is None else round(over, 3), 'FloorSamples': samples}
    doc = {'Keeper': k.name, 'Stage': st, 'Personality': k.personality, 'Triangles': k.tris(), 'TrianglesOnScreen': k.tris_visible(),
           'MeshParts': len(parts), 'Fbx': os.path.basename(fbx) if fbx else None, 'Atlas': 'keeper_%s_atlas.png' % k.key,
           'FaceStates': STATES, 'Space': 'Roblox rig space (studs, face toward -Z, floor at y = -%g)' % lift(st)
           if st else 'The Darkened: group-local space (part CFrame = group frame * VeiledFrame)', 'Parts': parts, 'Groups': out_groups}
    json.dump(doc, open(os.path.join(OUT, 'fbx', 'keeper_%s.json' % k.key), 'w'), indent=1)
    m = META.setdefault(k.key, {})
    m['overshoot'] = {g: v['Overshoot'] for g, v in out_groups.items()}
    m['mesh_parts'] = len(parts)
    m['fbx_bytes'] = os.path.getsize(fbx) if fbx else None
    save_meta()


if 'fbx' in WHAT:
    export_fbx()
if 'sheets' in WHAT:
    keeper_sheets()
if 'faces' in WHAT:
    face_closeups()
if 'ba' in WHAT:
    before_after()
if 'lineup' in WHAT:
    lineup()
