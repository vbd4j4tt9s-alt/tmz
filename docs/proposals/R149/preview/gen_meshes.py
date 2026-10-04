"""Usage: python3 gen_meshes.py <out dir>
Phase-2 demo: generates NEW vertex-coloured fruit meshes in exactly the format ApprovedPlantMeshes bakes from
(ServerStorage/ApprovedPlantMeshData*: {Vertices, Normals, Colors (0..1), Faces (1-based)}, every axis normalised to -0.5..0.5,
so the spec's size `z` scales it like FlutedCocoa / SmoothFirePepper). Nothing is installed; it writes
  <out>/generated_meshes.json        the preview's mesh table (merged with the place's baked meshes by the renderer)
  <out>/<Key>.lua                    the module text an installer would add (size check only)
Meshes: RibbedMelon149 (watermelon: wavy dark stripes, pale ground spot, slight stripe relief) and LobedPumpkin149 (Ember Pumpkin:
10 lobes, dimpled top/bottom, ember-lit grooves, darker shoulder). Both are lathes around the mesh Y axis, like FlutedCocoa."""
import json, math, os, sys

out = sys.argv[1]
os.makedirs(out, exist_ok=True)


def lerp(a, b, t):
    return [a[i] + (b[i] - a[i]) * t for i in range(3)]


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def lathe(rings, segs, point, color):
    """point(phi, theta) -> (x, y, z); color(phi, theta) -> rgb 0..255. phi 0 = top pole, pi = bottom pole."""
    verts, cols = [], []
    verts.append(point(0.0, 0.0)); cols.append(color(0.0, 0.0))
    for i in range(1, rings):
        phi = math.pi * i / rings
        for j in range(segs):
            th = 2 * math.pi * j / segs
            verts.append(point(phi, th)); cols.append(color(phi, th))
    verts.append(point(math.pi, 0.0)); cols.append(color(math.pi, 0.0))
    faces = []
    ring = lambda i, j: 1 + (i - 1) * segs + (j % segs)  # 0-based index of ring i (1..rings-1)
    last = len(verts) - 1
    for j in range(segs):
        faces.append((0, ring(1, j + 1), ring(1, j)))
    for i in range(1, rings - 1):
        for j in range(segs):
            a, b, c, d = ring(i, j), ring(i, j + 1), ring(i + 1, j), ring(i + 1, j + 1)
            faces.append((a, b, d)); faces.append((a, d, c))
    for j in range(segs):
        faces.append((last, ring(rings - 1, j), ring(rings - 1, j + 1)))
    # normalise every axis to -0.5..0.5 (the baked meshes are unit boxes scaled by the part's Size)
    lo = [min(v[k] for v in verts) for k in range(3)]
    hi = [max(v[k] for v in verts) for k in range(3)]
    verts = [[(v[k] - (lo[k] + hi[k]) / 2) / (hi[k] - lo[k]) for k in range(3)] for v in verts]
    # smooth vertex normals = area-weighted face normals (in the normalised space)
    normals = [[0.0, 0.0, 0.0] for _ in verts]
    for a, b, c in faces:
        p, q, r = verts[a], verts[b], verts[c]
        u = [q[k] - p[k] for k in range(3)]; w = [r[k] - p[k] for k in range(3)]
        n = [u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0]]
        for idx in (a, b, c):
            for k in range(3):
                normals[idx][k] += n[k]
    for n in normals:
        m = math.sqrt(sum(x * x for x in n)) or 1.0
        n[:] = [x / m for x in n]
    # outward check: faces wind so that normals point away from the centre
    if sum(normals[i][1] * verts[i][1] + normals[i][0] * verts[i][0] for i in range(len(verts))) < 0:
        faces = [(a, c, b) for a, b, c in faces]
        normals = [[-x for x in n] for n in normals]
    return {'v': verts, 'n': normals, 'c': [[x / 255 for x in c] for c in cols], 'f': [[a + 1, b + 1, c + 1] for a, b, c in faces]}


def melon():
    dark, light, spot = [34, 92, 46], [124, 186, 88], [226, 214, 142]

    def stripe(phi, th):
        wob = 0.32 * math.sin(6 * phi + 2 * th) + 0.12 * math.sin(11 * phi - th)
        return smooth(0.15, 0.55, math.sin(9 * th + wob))  # 9 wavy dark stripes

    def point(phi, th):
        s = stripe(phi, th) if 0 < phi < math.pi else 0
        r = math.sin(phi) * (1 + 0.014 * s)  # dark stripes stand a hair proud (stripe relief, like the cocoa flutes)
        return [r * math.cos(th), math.cos(phi), r * math.sin(th)]

    def color(phi, th):
        c = lerp(light, dark, stripe(phi, th))
        dth = math.atan2(math.sin(th), math.cos(th))  # theta 0 = mesh +X = world down once the spec turns the melon on its side
        g = math.exp(-(dth ** 2 / 0.18 + (phi - math.pi * 0.55) ** 2 / 0.35))  # pale ground spot where the melon lies
        c = lerp(c, spot, 0.85 * g)
        pole = math.cos(phi) ** 8
        return lerp(c, [70, 120, 50], 0.5 * pole)  # darker stem / blossom ends
    return lathe(26, 48, point, color)


def pumpkin():
    lobe_c, groove_c, shoulder_c, base_c = [234, 112, 30], [255, 176, 52], [150, 58, 20], [246, 150, 60]

    def lobe(th):
        return abs(math.cos(5 * th)) ** 0.55  # 10 lobes: 1 on a lobe crest, 0 in a groove

    def point(phi, th):
        r = math.sin(phi) * (0.86 + 0.14 * lobe(th))
        y = 0.74 * math.cos(phi)
        dimple = math.exp(-(math.sin(phi) / 0.30) ** 2)  # top and bottom sink in around the stem / blossom end
        y -= 0.20 * dimple * (1 if math.cos(phi) > 0 else -1)
        return [r * math.cos(th), y, r * math.sin(th)]

    def color(phi, th):
        g = 1 - lobe(th)
        c = lerp(lobe_c, groove_c, smooth(0.35, 0.9, g) * math.sin(phi))  # ember-lit grooves (bright seams)
        top = smooth(0.3, 1.0, math.cos(phi))
        c = lerp(c, shoulder_c, 0.75 * top)  # dark shoulder gradient into the stem
        c = lerp(c, base_c, 0.45 * smooth(0.2, 1.0, -math.cos(phi)))  # lighter underside
        return c
    return lathe(24, 60, point, color)


meshes = {'RibbedMelon149': melon(), 'LobedPumpkin149': pumpkin()}
json.dump(meshes, open(os.path.join(out, 'generated_meshes.json'), 'w'), separators=(',', ':'))


def lua(m):
    f = lambda xs: '{' + ','.join('%.4g' % x for x in xs) + '}'
    parts = ['["Vertices"]={' + ','.join(f(v) for v in m['v']) + '}', '["Normals"]={' + ','.join(f(v) for v in m['n']) + '}',
             '["Colors"]={' + ','.join(f(v) for v in m['c']) + '}', '["Faces"]={' + ','.join('{%d,%d,%d}' % tuple(t) for t in m['f']) + '}']
    return 'return {' + ','.join(parts) + '}'


for key, m in meshes.items():
    text = lua(m)
    open(os.path.join(out, key + '.lua'), 'w').write(text)
    print('INFO generated %s: %d vertices, %d triangles, %.1f KB module source' % (key, len(m['v']), len(m['f']), len(text) / 1024))
