"""R153 preview: docs/proposals/R153/pack_parts_fix.png (BEFORE = R152 as released, AFTER = this checkout), rendered in Blender from the REAL geometry.

  python3 make_preview.py scene <src dir> <base scenes.txt> <after scenes.txt> <out scene.json>
  <bpyenv>/bin/python ../blender/render_preview.py <scene.json> <cells dir> [--samples 32] [--size 520]
  python3 make_preview.py sheet <cells dir> <out png>

Rows (each BEFORE | AFTER):
  1. the Verity pack from the owner's angle (edge-on, a little of the face showing): the REAL flat pouch (VerityPouch151.Generate, via R152's
     tools/dump_verity_pouch.py) with the pack's own BottomSeal and 8 TearStrips; BEFORE it sits .0474 in front of them (the Storm_02 mesh's box centre),
     AFTER on their plane.
  2. its top end, straight from the side (orthographic, 4x): the pouch's crimp and the strips.
  3. a tall design with a shape: Lava_03 (crown above the pouch) with Shoulders, the top-right corner from the front (orthographic, 5x): its pouch body
     (the BagBody of the native data, moved by PackShapes151's field exactly as Deform does, BEFORE without and AFTER with the R153 hold) and the strips.
     The crown and print are left out so the crimp can be seen.
  4. the Void pack from the side (orthographic): the Forest_01 pouch (all of its native data) and every print part of both faces as the game builds them
     (dump_pack_parts.luau scenes); the halo is left out.
"""
import json
import math
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))

YELLOW, SEAL_Y = [255, 255, 0], [230, 230, 0]


def box_mesh(size, p, r):
    sx, sy, sz = size; v = []
    for x in (-.5, .5):
        for y in (-.5, .5):
            for z in (-.5, .5):
                v.append(np.array(r) @ np.array([x * sx, y * sy, z * sz]) + np.array(p))
    f = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return [list(map(float, q)) for q in v], f


def cyl_mesh(size, p, r, n=32):
    sx, sy, sz = size; rad = min(sy, sz) / 2; v = []
    for x in (-sx / 2, sx / 2):
        for k in range(n):
            a = 2 * math.pi * k / n
            v.append(np.array(r) @ np.array([x, rad * math.cos(a), rad * math.sin(a)]) + np.array(p))
    f = [list(range(n))[::-1], list(range(n, 2 * n))] + [[k, (k + 1) % n, n + (k + 1) % n, n + k] for k in range(n)]
    return [list(map(float, q)) for q in v], f


def seal_strips(color, dz=0.0):
    out = []
    v, f = box_mesh((1.9, .16, .035), (0, -1.12, 0), np.eye(3)); out.append({'v': v, 'f': f, 'color': color})
    for i in range(1, 9):
        v, f = box_mesh((1.9 / 8 + .001, .18, .035), (-1.9 / 2 + (i - .5) * 1.9 / 8, 1.11, 0), np.eye(3)); out.append({'v': v, 'f': f, 'color': color})
    return out


def verity_pouch(z):
    obj = os.path.join(os.environ.get('TMPDIR', '/tmp'), 'r153_verity_pouch.obj')
    subprocess.run([sys.executable, os.path.join(REPO, 'docs', 'proposals', 'R152', 'tools', 'dump_verity_pouch.py'), obj], check=True, capture_output=True)
    v, f = [], []
    for line in open(obj):
        if line.startswith('v '):
            x, y, zz = map(float, line.split()[1:4]); v.append([-x, y - .01, -zz + z])  # the template's turn (180 degrees about y), centre (0, -.01, z)
        elif line.startswith('f '):
            f.append([int(t.split('/')[0]) - 1 for t in line.split()[1:4]])
    return {'v': v, 'f': f, 'color': YELLOW, 'smooth': True}


def smile(z):
    """Verity's face stands in as a dark smile on the pouch's front (the real picture cannot be downloaded here), on the Front plane."""
    out = []
    zf = z - .281 - .002
    for k in range(9):
        a0, a1 = math.pi * (1.15 + .7 * k / 9), math.pi * (1.15 + .7 * (k + 1) / 9)
        p0 = np.array([.38 * math.cos(a0), .38 * math.sin(a0) + .05, zf]); p1 = np.array([.38 * math.cos(a1), .38 * math.sin(a1) + .05, zf])
        c = (p0 + p1) / 2; d = p1 - p0; ang = math.atan2(d[1], d[0])
        r = [[math.cos(ang), -math.sin(ang), 0], [math.sin(ang), math.cos(ang), 0], [0, 0, 1]]
        v, f = box_mesh((np.linalg.norm(d) + .01, .06, .004), c, r); out.append({'v': v, 'f': f, 'color': [30, 30, 50]})
    for x in (-.17, .17):
        v, f = box_mesh((.06, .22, .004), (x, .32, zf), np.eye(3)); out.append({'v': v, 'f': f, 'color': [30, 30, 50]})
    return out


def shaped_body(src, key, shape, hold):
    import pouch_mesh
    P = pouch_mesh.Pouch(src, key)
    sys.path.insert(0, os.path.join(REPO, 'docs', 'proposals', 'R153', 'tests'))
    import check_pack_parts as C
    T = C.templates(os.path.join(REPO, 'docs', 'proposals', 'R151', 'tests', 'pack_templates.luau'))[key]
    lo = np.min([p - np.abs(r) @ s / 2 for s, p, r in T.values()], 0); hi = np.max([p + np.abs(r) @ s / 2 for s, p, r in T.values()], 0)
    c, h = (lo + hi) / 2, (hi - lo) / 2

    def ss(a, b, x):
        t = min(1, max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t)

    def body(v):
        return 1 - ss(.80, .94, abs(v))

    def shoulder(v):
        return ss(.45, .80, abs(v)) * body(v)

    def scales(i, u, v, w):  # PackShapes151's six fields (the Lua is the test's; this only draws them)
        if i == 1:
            b = body(v) * (1 - v * v); return 1 - .04 * b, 1 + .05 * b
        if i == 2:
            b = body(v); return 1 - .09 * b * math.exp(-(v / .5) ** 2), 1 + .03 * b * math.exp(-(v / .6) ** 2)
        if i == 3:
            g = body(v) * v; return 1 - .05 * g, 1 - .03 * g
        if i == 4:
            g = body(v) * v; return 1 + .05 * g, 1 + .03 * g
        if i == 5:
            return 1 - .08 * ss(.45, .85, abs(u)) * shoulder(v), 1
        b = body(v); return 1 + .02 * b * (1 - v * v), 1 - .15 * b * math.exp(-(v / .75) ** 2) * (1 - .3 * u * u)
    out = []
    for q in P.body:
        u, v, w = (q - c) / h
        sx, sz = scales(shape, u, v, w)
        if hold:
            b = body(v); k = 1 if b <= 0 else min(1, body((q[1] + .01) / 1.03) / b)
            sx, sz = 1 + (sx - 1) * k, 1 + (sz - 1) * k
        out.append([float(c[0] + u * sx * h[0]), float(q[1]), float(c[2] + w * sz * h[2])])
    f = next(fc for n, v, fc in P.parts if n == 'BagBody')
    return {'v': out, 'f': f.tolist(), 'color': [210, 120, 70], 'smooth': True}


def void_objects(src, scenes, label='Void'):
    import pouch_mesh
    sc = next(json.loads(l[6:]) for l in open(scenes, encoding='utf-8') if l.startswith('SCENE ') and json.loads(l[6:])['label'] == label)
    out = []
    for n, v, f in pouch_mesh.components(src, 'Forest_01'):
        out.append({'v': v.tolist(), 'f': f.tolist(), 'color': [22, 14, 40], 'smooth': n == 'BagBody'})
    for p in sc['parts']:
        if p['class'] == 'MeshPart' or p.get('t', 0) >= .95 or p['name'].startswith(('EventHorizon', 'HaloDebris')):
            continue
        r = np.array(p['r'])
        if p['shape'] == 'Cylinder':
            v, f = cyl_mesh(p['size'], p['p'], r)
        else:
            v, f = box_mesh(p['size'], p['p'], r)
        out.append({'v': v, 'f': f, 'color': p['color'], 'alpha': 1 - p.get('t', 0), 'emit': p.get('material') == 'Neon'})
    return out


def scene(src, base_scenes, after_scenes, out):
    cells = []
    # 1 + 2: Verity
    for which, z in (('before', -.0474), ('after', 0.0)):
        objs = [verity_pouch(z)] + seal_strips(SEAL_Y) + smile(z)
        # the owner's angle: from the pack's left side, a few degrees round towards the front, a little above
        ang = math.radians(8)
        cam = [-4.6 * math.cos(ang), 1.05, -4.6 * math.sin(ang)]
        cells.append({'name': 'verity_side_' + which, 'objects': objs, 'camera': {'loc': cam, 'target': [0, .72, 0], 'lens': 85}})
        cells.append({'name': 'verity_top_' + which, 'objects': objs, 'camera': {'loc': [-5, 1.06, 0], 'target': [0, 1.06, 0], 'ortho': .5}})
    # 3: a tall design with a shape (Lava_03 Shoulders), the top-right corner from the front
    for which, hold in (('before', False), ('after', True)):
        objs = [shaped_body(src, 'Lava_03', 5, hold)] + seal_strips([60, 40, 30])
        cells.append({'name': 'tall_' + which, 'objects': objs, 'camera': {'loc': [.9, 1.03, -5], 'target': [.9, 1.03, 0], 'ortho': .26}})
    # 4: the Void from the side
    for which, sc_path in (('before', base_scenes), ('after', after_scenes)):
        objs = void_objects(src, sc_path)
        cells.append({'name': 'void_' + which, 'objects': objs, 'camera': {'loc': [-6, .05, -.06], 'target': [0, .05, -.06], 'ortho': 2.6}})
    json.dump({'cells': cells}, open(out, 'w'))
    print(len(cells), 'cells ->', out)


def sheet(cells_dir, out):
    from PIL import Image, ImageDraw, ImageFont

    def font(size, bold=True):
        try:
            return ImageFont.truetype('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf', size)
        except OSError:
            return ImageFont.load_default()
    rows = [('verity_side', 'Verity top, owner\'s angle', ['the strips stand off the crimp\'s middle', '(.047 in depth: clearer from the', 'side, next row)'], ['centred on the crimp']),
            ('verity_top', 'its top, from the side (4x)', ['the crimp (left) beside the strips', '(right): two steps'], ['the strips run on from the crimp']),
            ('tall', 'Lava_03 + Shoulders, corner (8x)', ['the shape pulled the crimp in under', 'the strips: their end sticks out .072'], ['the crimp is held: flush again']),
            ('void', 'Void, from the side', ['corner runes / stars hang up to .46', 'off the pouch (the sheet rests on', 'the raised leaf only)'], ['corner details seated on the pouch;', 'the sheet unchanged'])]
    C = 520; L, T, G = 400, 120, 12
    W = L + 2 * C + G + 20; H = T + len(rows) * (C + G) + 70
    img = Image.new('RGB', (W, H), (17, 20, 32)); d = ImageDraw.Draw(img)
    d.text((20, 16), 'R153: parts on packs, before (R152) and after', font=font(34), fill=(255, 255, 255))
    d.text((20, 60), 'Rendered from the real geometry (the pouches\' native render data, VerityPouch151.Generate, the parts as the game builds them).', font=font(18, False), fill=(190, 198, 215))
    for ci, (lab, col) in enumerate((('BEFORE (R152)', (255, 128, 112)), ('AFTER (R153)', (130, 230, 140)))):
        d.text((L + ci * (C + G) + 8, T - 34), lab, font=font(24), fill=col)
    for ri, (key, title, before, after) in enumerate(rows):
        y = T + ri * (C + G)
        d.text((20, y + 10), title, font=font(21), fill=(255, 255, 255))
        yy = y + 50
        d.text((20, yy), 'before:', font=font(17), fill=(255, 128, 112)); yy += 24
        for line in before:
            d.text((20, yy), line, font=font(16, False), fill=(200, 205, 220)); yy += 21
        yy += 10
        d.text((20, yy), 'after:', font=font(17), fill=(130, 230, 140)); yy += 24
        for line in after:
            d.text((20, yy), line, font=font(16, False), fill=(200, 205, 220)); yy += 21
        for ci, which in enumerate(('before', 'after')):
            p = os.path.join(cells_dir, '%s_%s.png' % (key, which))
            if os.path.exists(p):
                img.paste(Image.open(p).convert('RGB').resize((C, C)), (L + ci * (C + G), y))
    d.text((20, H - 50), 'Not a Studio screenshot: Cycles renders of the same data the game builds from. The Verity face is a drawn smile (the picture is not available offline).', font=font(16, False), fill=(160, 170, 190))
    img.save(out)
    print('sheet ->', out)


if __name__ == '__main__':
    if sys.argv[1] == 'scene':
        scene(*sys.argv[2:6])
    else:
        sheet(sys.argv[2], sys.argv[3])
