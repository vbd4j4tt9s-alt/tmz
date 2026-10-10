"""R149 z-fighting detector (owner: "try to take out all the z fighting within the shop and so on").

Usage: python3 zfight.py <scene.json> [--area AREA] [--tier TIER] [--grep TEXT] [--group] [--list N] [--json out.json]
A scene is {"parts": [...], "playable": [[x0, z0, x1, z1], ...]} as written by rbxl_geom.py (the place file) or by
tests/zfight_scene.luau (the whole map after the real start-up builders): each part has path, name, class / shape, size, p,
r (3x3 rows), color, material, t (transparency), optional ltm (LocalTransparencyModifier), optional faces (Decal / Texture /
SurfaceGui on a face, a Decal / Texture with its own t and ltm), mesh (SpecialMesh) and area (a label for the per-area table).

What the player sees is the EFFECTIVE transparency 1 - (1 - t) x (1 - ltm), for parts and for decals / textures: the R149
keyboard hides the real track floor (BiomeGround_n, and its decals) on every client with LocalTransparencyModifier = 1, so a
floor with t = 0 and ltm = 1 is not drawn and nothing can fight with it.

What counts as z-fighting (both surfaces visible and looking different, otherwise no flicker can be seen):
  * two flat faces of different parts that point the SAME way, lie in (nearly) the same plane and overlap (> 0.02 stud^2):
      coplanar  |offset| <= 0.002 studs
      near      |offset| <= 0.02 (also "a big thin part lying 0.01 above the floor")
      far       |offset| < 4 depth steps of a 24-bit depth buffer without reversed Z (the worst case, older phones) with
                Roblox's near plane (Camera.NearPlaneZ = -0.5) at the distance D the overlap is seen from:
                step = D^2 / (0.5 x 2^24), limit = max(0.02, 4 x step) (0.02 up to 205 studs, 0.043 at 300). D is how far
                away the overlap still covers ~8 pixels of a 720p screen (64 x its smaller side), capped at 300 studs.
      strict    reported, NOT counted: the rule of thumb "offset >= 0.002 x D" fails although the depth-buffer limit holds.
                It asks for 0.2-0.6 stud steps on big floors (pavers, aprons, the keyboard bed) that would change the look
                and that no depth buffer needs.
    Opposite faces (a part resting on another) never fight.
  * two balls with the same centre and radius, two cylinders on the same axis with the same radius (their round sides).
Faces: Block 6 rectangles; Wedge bottom, back, slope and its two triangles; CornerWedge bottom; Cylinder end discs (sampled
inside the disc); MeshPart / Union the bounding-box faces, reported as 'mesh' (the real surface may not reach the box).
A pair is not counted when nobody can see it: every sample point just in front of the overlap lies inside a third solid
part, or outside the playable boxes (the map's outer faces), or, for a face pointing down, there is no floor under it (the
underside of the map) or less than 0.5 stud of room between it and the solid under it (no camera fits).
Look-alike pairs (same colour within 1/255 per channel, same material, transparency and face decals / textures / GUIs)
flicker invisibly and are listed apart; a Decal / Texture / SurfaceGui makes its face look different, and a see-through
part carrying a SurfaceGui still draws that GUI (its decorated faces take part).
The keyboard fills the space under its floor: a downward face inside the keyboard's volume (from the top of its sunken bed up to
CAMERA_GAP above the resting key tops, over the bed) is never looked at, whatever the gaps between the keycaps leave free: the
keycaps are meshes (no solid here) but the camera cannot get between them (0.5 stud gaps) - see keyboard_fill()."""
import json, math, sys, collections

COPLANAR, NEAR, FAR_CAP, FAR_K, PIXELS_K = 0.002, 0.02, 300.0, 0.002, 64.0
NEAR_PLANE = 0.5           # Roblox Camera.NearPlaneZ is -0.5
DEPTH_K = 4 / (NEAR_PLANE * 2 ** 24)  # 4 depth steps of a 24-bit buffer: step(D) ~ D^2 / (near * 2^24)
MIN_AREA = 0.02            # stud^2 of overlap below which a flicker is a few pixels at most
NORMAL_DOT = 0.99995       # same direction (about 0.6 degrees)
SAMPLE_LIFT = 0.04         # how far in front of the faces the visibility samples sit
VISIBLE_T = 0.98
CAMERA_GAP = 0.5           # a downward face less than this above the solid under it cannot be looked at (camera near plane)
LOOK_ALIKE = 1             # colours this close (per 0-255 channel; float rounding), same material / transparency / decals: no visible flicker
PLAYABLE = []              # [x0, z0, x1, z1] boxes a camera can be in (the scene's "playable"); empty = everywhere


def effective_t(t, ltm=0.0):
    """What the client draws: Roblox multiplies the two opacities (Transparency, LocalTransparencyModifier) of a part / decal."""
    return 1.0 - (1.0 - float(t or 0.0)) * (1.0 - float(ltm or 0.0))


def vadd(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def vsub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def vmul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])
def norm(a):
    m = math.sqrt(dot(a, a))
    return (a[0] / m, a[1] / m, a[2] / m) if m > 0 else (0.0, 0.0, 0.0)


FACE_AXIS = {'Right': (0, 1), 'Left': (0, -1), 'Top': (1, 1), 'Bottom': (1, -1), 'Back': (2, 1), 'Front': (2, -1)}


class Part:
    __slots__ = ('i', 'path', 'name', 'shape', 'size', 'p', 'cols', 'color', 'material', 't', 'decor', 'faces', 'lo', 'hi', 'solid',
                 'mesh', 'src', 'area', 'gui_only')

    def __init__(self, i, d):
        self.i = i
        self.path = d.get('path') or d.get('name', '?')
        self.name = d.get('name', self.path.rsplit('/', 1)[-1])
        self.src = d
        self.area = d.get('area')
        shape = d.get('shape', 'Block')
        size = list(d['size'])
        r = d['r']
        if len(r) == 9:
            r = [r[0:3], r[3:6], r[6:9]]
        self.cols = [(r[0][k], r[1][k], r[2][k]) for k in range(3)]  # right, up, back (local X, Y, Z in world)
        self.p = tuple(d['p'])
        mesh = d.get('mesh')
        self.mesh = False
        if mesh:
            mt = mesh.get('type', 'Brick')
            sc = mesh.get('scale', [1, 1, 1])
            off = mesh.get('offset', [0, 0, 0])
            if mt in ('Brick',):
                size = [size[k] * sc[k] for k in range(3)]
            elif mt == 'Wedge':
                size = [size[k] * sc[k] for k in range(3)]; shape = 'Wedge'
            elif mt == 'Sphere':
                size = [size[k] * sc[k] for k in range(3)]; shape = 'Ellipsoid'
            elif mt == 'Cylinder':
                size = [size[k] * sc[k] for k in range(3)]; shape = 'YCylinder'
            else:
                shape = 'Mesh'; size = [size[k] * sc[k] for k in range(3)] if mt != 'FileMesh' else size
            if any(off):
                self.p = vadd(self.p, vadd(vadd(vmul(self.cols[0], off[0]), vmul(self.cols[1], off[1])), vmul(self.cols[2], off[2])))
        if shape in ('Mesh',) or d.get('class') in ('MeshPart', 'UnionOperation'):
            self.mesh = True
            shape = 'Mesh'
        if shape == 'Ball':
            m = min(size); size = [m, m, m]
        if shape == 'Cylinder':
            m = min(size[1], size[2]); size = [size[0], m, m]
        self.shape = shape
        self.size = size
        self.color = tuple(int(c) for c in d.get('color', (163, 162, 165)))
        self.material = d.get('material', 'Plastic')
        self.t = effective_t(d.get('t', 0), d.get('ltm', 0))
        self.decor = collections.defaultdict(list)
        for f in d.get('faces', []) or []:
            if effective_t(f.get('t', 0), f.get('ltm', 0)) < VISIBLE_T and not f.get('alwaysOnTop'):
                self.decor[f['face']].append(f.get('kind', '?') + ':' + str(f.get('sig', '')))
        ext = [sum(abs(self.cols[k][a]) * size[k] / 2 for k in range(3)) for a in range(3)]
        self.lo = tuple(self.p[a] - ext[a] for a in range(3))
        self.hi = tuple(self.p[a] + ext[a] for a in range(3))
        self.solid = self.t < 0.5 and shape not in ('Mesh',)
        # a see-through part still draws its SurfaceGuis / Decals: those faces alone take part
        self.gui_only = self.t >= VISIBLE_T and bool(self.decor)
        self.faces = self.build_faces()
        if self.gui_only:
            self.faces = [f for f in self.faces if f['face'] in self.decor]

    def world(self, x, y, z):
        c = self.cols
        return (self.p[0] + c[0][0] * x + c[1][0] * y + c[2][0] * z,
                self.p[1] + c[0][1] * x + c[1][1] * y + c[2][1] * z,
                self.p[2] + c[0][2] * x + c[1][2] * y + c[2][2] * z)

    def local(self, w):
        d = vsub(w, self.p)
        return (dot(d, self.cols[0]), dot(d, self.cols[1]), dot(d, self.cols[2]))

    def build_faces(self):
        hx, hy, hz = (s / 2 for s in self.size)
        out = []

        def rect(name, corners, normal_local):
            pts = [self.world(*c) for c in corners]
            n = norm(vadd(vadd(vmul(self.cols[0], normal_local[0]), vmul(self.cols[1], normal_local[1])), vmul(self.cols[2], normal_local[2])))
            out.append({'face': name, 'pts': pts, 'n': n, 'disc': None})
        if self.shape in ('Block', 'Mesh'):
            rect('Right', [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)], (1, 0, 0))
            rect('Left', [(-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz), (-hx, -hy, -hz)], (-1, 0, 0))
            rect('Top', [(-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz)], (0, 1, 0))
            rect('Bottom', [(-hx, -hy, hz), (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz)], (0, -1, 0))
            rect('Back', [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)], (0, 0, 1))
            rect('Front', [(hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)], (0, 0, -1))
        elif self.shape == 'Wedge':
            # Roblox wedge: full bottom, full back (+Z), slope rising from the front-bottom edge to the back-top edge.
            rect('Bottom', [(-hx, -hy, hz), (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz)], (0, -1, 0))
            rect('Back', [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)], (0, 0, 1))
            rect('Right', [(hx, -hy, -hz), (hx, hy, hz), (hx, -hy, hz)], (1, 0, 0))
            rect('Left', [(-hx, -hy, hz), (-hx, hy, hz), (-hx, -hy, -hz)], (-1, 0, 0))
            sl = norm((0.0, 2 * hz, -2 * hy)) if hy > 0 and hz > 0 else (0.0, 1.0, 0.0)
            rect('Top', [(-hx, -hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, -hy, -hz)], sl)
        elif self.shape == 'CornerWedge':
            rect('Bottom', [(-hx, -hy, hz), (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz)], (0, -1, 0))
        elif self.shape == 'Cylinder':
            r = hy
            for sgn, name in ((1, 'Right'), (-1, 'Left')):
                rect(name, [(sgn * hx, -r, -r), (sgn * hx, r, -r), (sgn * hx, r, r), (sgn * hx, -r, r)] if sgn > 0 else
                     [(sgn * hx, -r, r), (sgn * hx, r, r), (sgn * hx, r, -r), (sgn * hx, -r, -r)], (sgn, 0, 0))
                out[-1]['disc'] = (self.world(sgn * hx, 0, 0), r)
        elif self.shape == 'YCylinder':
            r = min(hx, hz)
            for sgn, name in ((1, 'Top'), (-1, 'Bottom')):
                rect(name, [(-r, sgn * hy, -r), (-r, sgn * hy, r), (r, sgn * hy, r), (r, sgn * hy, -r)] if sgn > 0 else
                     [(-r, sgn * hy, r), (-r, sgn * hy, -r), (r, sgn * hy, -r), (r, sgn * hy, r)], (0, sgn, 0))
                out[-1]['disc'] = (self.world(0, sgn * hy, 0), r)
        for f in out:
            f['d'] = dot(f['n'], f['pts'][0])
        return out

    def contains(self, w, margin=0.0):
        """Is w strictly inside the solid (shrunk by margin)?"""
        x, y, z = self.local(w)
        hx, hy, hz = (s / 2 - margin for s in self.size)
        if hx <= 0 or hy <= 0 or hz <= 0:
            return False
        if self.shape in ('Ball', 'Ellipsoid'):
            return (x / hx) ** 2 + (y / hy) ** 2 + (z / hz) ** 2 < 1
        if abs(x) >= hx or abs(y) >= hy or abs(z) >= hz:
            return False
        if self.shape == 'Block' or self.shape == 'Mesh':
            return True
        if self.shape == 'Wedge':
            # below the slope: (y + hy) / (2hy) < (z + hz) / (2hz)
            return (y + hy) * hz < (z + hz) * hy
        if self.shape == 'Cylinder':
            return y * y + z * z < hy * hy
        if self.shape == 'YCylinder':
            return x * x + z * z < min(hx, hz) ** 2
        if self.shape == 'CornerWedge':
            return False
        return False

    def look(self, face):
        if self.gui_only:
            return ((-1, -1, -1), 'gui', 1.0, tuple(sorted(self.decor.get(face, []))))
        return (self.color, self.material, round(self.t, 2), tuple(sorted(self.decor.get(face, []))))


def clip(subject, a, b):
    """Keep the part of 2D polygon `subject` left of the directed edge a->b."""
    out = []
    n = len(subject)
    if n == 0:
        return out

    def side(p): return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
    for i in range(n):
        cur, prev = subject[i], subject[i - 1]
        sc, sp = side(cur), side(prev)
        if sc >= 0:
            if sp < 0:
                t = sp / (sp - sc); out.append((prev[0] + (cur[0] - prev[0]) * t, prev[1] + (cur[1] - prev[1]) * t))
            out.append(cur)
        elif sp >= 0:
            t = sp / (sp - sc); out.append((prev[0] + (cur[0] - prev[0]) * t, prev[1] + (cur[1] - prev[1]) * t))
    return out


def area2(poly):
    s = 0.0
    for i in range(len(poly)):
        x0, y0 = poly[i - 1]; x1, y1 = poly[i]
        s += x0 * y1 - x1 * y0
    return s / 2


def ccw(poly):
    return poly if area2(poly) >= 0 else list(reversed(poly))


def intersect(pa, pb):
    out = ccw(pa)
    clipper = ccw(pb)
    for i in range(len(clipper)):
        out = clip(out, clipper[i - 1], clipper[i])
        if not out:
            break
    return out


def basis(n):
    a = (1.0, 0.0, 0.0) if abs(n[0]) < 0.9 else (0.0, 1.0, 0.0)
    u = norm(cross(n, a)); v = cross(n, u)
    return u, v


def samples(poly, k=5):
    """Points spread over a convex 2D polygon (grid over its box, kept when inside; centroid always)."""
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    cx = sum(xs) / len(xs); cy = sum(ys) / len(ys)
    out = [(cx, cy)]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    cp = ccw(poly)
    for i in range(k):
        for j in range(k):
            x = x0 + (x1 - x0) * (i + .5) / k; y = y0 + (y1 - y0) * (j + .5) / k
            inside = True
            for e in range(len(cp)):
                a, b = cp[e - 1], cp[e]
                if (b[0] - a[0]) * (y - a[1]) - (b[1] - a[1]) * (x - a[0]) < -1e-9:
                    inside = False; break
            if inside:
                out.append((x, y))
    return out


class Grid:
    def __init__(self, parts, cell=16.0):
        self.cell = cell
        self.cells = collections.defaultdict(list)
        for p in parts:
            for key in self.keys(p.lo, p.hi):
                self.cells[key].append(p)

    def keys(self, lo, hi):
        c = self.cell
        for x in range(int(math.floor(lo[0] / c)), int(math.floor(hi[0] / c)) + 1):
            for z in range(int(math.floor(lo[2] / c)), int(math.floor(hi[2] / c)) + 1):
                yield (x, z)

    def at(self, w):
        return self.cells.get((int(math.floor(w[0] / self.cell)), int(math.floor(w[2] / self.cell))), ())

    def column(self, x, z):
        return self.cells.get((int(math.floor(x / self.cell)), int(math.floor(z / self.cell))), ())


def covered(grid, w, skip):
    for q in grid.at(w):
        if q.solid and q.i not in skip and q.lo[0] <= w[0] <= q.hi[0] and q.lo[1] <= w[1] <= q.hi[1] and q.lo[2] <= w[2] <= q.hi[2]:
            if q.contains(w, 0.0):
                return True
    return False


KEYBOARD_MARK = 'KeyboardTrackVisuals'
FILL = []                  # [x0, z0, x1, z1, ylo, yhi] volumes a camera cannot be in (the keyboard: bed top .. resting key tops + CAMERA_GAP)


def keyboard_fill(parts):
    """The space the R149 keyboard fills. Its keycaps are MeshParts (not solid here) standing in 0.5 stud gaps on a sunken bed, so the
    scene sees 'a floor 0.6 below' under every face of the real floor and under a shovel hole's rim: a downward face there looks
    like a ceiling a camera can look up at, but nothing fits between the keys. For every keyboard bed block (a Block called Bed
    under KeyboardTrackVisuals) the volume over the bed from its top to CAMERA_GAP above the resting key tops is filled (the keys of the
    scene set the height; a scene only has the keys around its runner, the bed runs the whole track)."""
    out = []
    tops = [k.hi[1] for k in parts if KEYBOARD_MARK in k.path and k.name in ('Key', 'Spacebar') and k.t < VISIBLE_T]
    for b in parts:
        if KEYBOARD_MARK not in b.path or b.name != 'Bed' or b.shape != 'Block' or b.t >= VISIBLE_T:
            continue
        above = [t for t in tops if t > b.hi[1]]
        if above:
            out.append([b.lo[0], b.lo[2], b.hi[0], b.hi[2], b.hi[1], max(above) + CAMERA_GAP])
    return out


def in_fill(w):
    for x0, z0, x1, z1, ylo, yhi in FILL:
        if x0 <= w[0] <= x1 and z0 <= w[2] <= z1 and ylo <= w[1] <= yhi:
            return True
    return False


def floor_below(grid, w, skip):
    """Can a camera get under a downward face at w and look up at it? Only when there is a floor somewhere below (not the
    underside of the map), at least CAMERA_GAP of free space between the face and the first solid under it, and the point is not
    inside the keyboard's filled volume (keycaps and their gaps over the bed)."""
    if in_fill(w):
        return False
    best = None
    for q in grid.column(w[0], w[2]):
        if q.i in skip or q.t >= VISIBLE_T or q.lo[1] >= w[1] or not q.solid:
            continue
        if q.lo[0] <= w[0] <= q.hi[0] and q.lo[2] <= w[2] <= q.hi[2]:
            # the highest point of q on the vertical line under w (sampled)
            top = min(w[1] - 0.01, q.hi[1]); bot = q.lo[1]
            n = max(6, int((top - bot) / 0.05) + 1) if top - bot < 2 else 41
            for k in range(n + 1):
                y = top - (top - bot) * k / n
                if q.contains((w[0], y, w[2]), 0.0):
                    best = y if best is None else max(best, y)
                    break
    return best is not None and w[1] - best >= CAMERA_GAP


def view_distance(poly):
    """How far away the overlap still spans ~8 px on a 720p screen (64 x its smaller side), capped at FAR_CAP."""
    xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
    a = abs(area2(poly)); long_side = max(max(xs) - min(xs), max(ys) - min(ys), 1e-6)
    short = min(a / long_side, long_side)
    return min(PIXELS_K * short, FAR_CAP)


def far_threshold(poly):
    return max(NEAR, DEPTH_K * view_distance(poly) ** 2)


def strict_threshold(poly):
    return max(NEAR, FAR_K * view_distance(poly))


def detect(parts, max_offset=0.6, want=None):
    """Returns findings: list of dicts (pair, faces, offset, area, tier, visible fraction, look-alike)."""
    live = [p for p in parts if p.t < VISIBLE_T or p.gui_only]
    FILL[:] = keyboard_fill(live)
    grid = Grid(live)
    groups = collections.defaultdict(list)
    BIN = 0.25
    for p in live:
        for fi, f in enumerate(p.faces):
            n = f['n']
            key = (round(n[0], 3), round(n[1], 3), round(n[2], 3))
            groups[key].append((f['d'], p, f))
    findings = []
    seen = set()
    for key, items in groups.items():
        items.sort(key=lambda t: t[0])
        # sweep along the plane offset: candidates within max_offset
        m = len(items)
        lo_idx = 0
        # index faces in 2D grid per window via simple sweep with AABB test
        for i in range(m):
            di, pi, fi = items[i]
            j = i + 1
            while j < m and items[j][0] - di <= max_offset:
                dj, pj, fj = items[j]
                j += 1
                if pj.i == pi.i:
                    continue
                if pi.lo[0] > pj.hi[0] + max_offset or pj.lo[0] > pi.hi[0] + max_offset or pi.lo[1] > pj.hi[1] + max_offset or \
                        pj.lo[1] > pi.hi[1] + max_offset or pi.lo[2] > pj.hi[2] + max_offset or pj.lo[2] > pi.hi[2] + max_offset:
                    continue
                if dot(fi['n'], fj['n']) < NORMAL_DOT:
                    continue
                f = check_pair(grid, pi, fi, pj, fj)
                if f:
                    k2 = (min(pi.i, pj.i), max(pi.i, pj.i), f['faceA'], f['faceB'])
                    if k2 in seen:
                        continue
                    seen.add(k2)
                    findings.append(f)
    findings += curved(live)
    return findings


def check_pair(grid, pa, fa, pb, fb):
    n = fa['n']
    offset = fb['d'] - fa['d']
    u, v = basis(n)
    A = [(dot(q, u), dot(q, v)) for q in fa['pts']]
    B = [(dot(q, u), dot(q, v)) for q in fb['pts']]
    poly = intersect(A, B)
    if len(poly) < 3:
        return None
    a = abs(area2(poly))
    if a < MIN_AREA:
        return None
    off = abs(offset)
    far = far_threshold(poly)
    strict = strict_threshold(poly)
    if off <= COPLANAR:
        tier = 'coplanar'
    elif off <= NEAR:
        tier = 'near'
    elif off < far:
        tier = 'far'
    elif off < strict:
        tier = 'strict'
    else:
        return None
    # visibility: sample points in front of the nearer face
    front = max(fa['d'], fb['d']) + SAMPLE_LIFT
    pts = samples(poly)
    vis = 0; total = 0
    skip = {pa.i, pb.i}
    for (x, y) in pts:
        w = vadd(vadd(vmul(u, x), vmul(v, y)), vmul(n, front))
        # discs: keep samples inside both discs
        ok = True
        for f in (fa, fb):
            if f['disc']:
                c, r = f['disc']
                dd = vsub(w, c); dd = vsub(dd, vmul(n, dot(dd, n)))
                if dot(dd, dd) > r * r:
                    ok = False
        if not ok:
            continue
        total += 1
        if PLAYABLE and not any(b[0] <= w[0] <= b[2] and b[1] <= w[2] <= b[3] for b in PLAYABLE):
            continue  # in front of the map's outer edge: no camera gets there
        if covered(grid, w, skip):
            continue
        if n[1] < -0.7 and not floor_below(grid, w, skip):
            continue
        vis += 1
    if total == 0 or vis == 0:
        return None
    frac = vis / total
    la, lb = pa.look(fa['face']), pb.look(fb['face'])
    same = la[1:] == lb[1:] and max(abs(x - y) for x, y in zip(la[0], lb[0])) <= LOOK_ALIKE
    mesh = pa.mesh or pb.mesh
    return {'a': pa.i, 'b': pb.i, 'pathA': pa.path, 'pathB': pb.path, 'faceA': fa['face'], 'faceB': fb['face'], 'offset': round(offset, 4),
            'area': round(a * frac, 3), 'tier': tier, 'visible': round(frac, 2), 'same_look': same, 'mesh': mesh,
            'normal': [round(c, 3) for c in n], 'at': [round(c, 2) for c in vadd(vmul(u, sum(p[0] for p in poly) / len(poly)),
                                                                                   vadd(vmul(v, sum(p[1] for p in poly) / len(poly)), vmul(n, fa['d'])))],
            'far_limit': round(far, 3), 'strict_limit': round(strict, 3),
            'poly': [[round(c, 3) for c in vadd(vadd(vmul(u, x), vmul(v, y)), vmul(n, fa['d']))] for (x, y) in poly]}


def curved(parts):
    """Concentric equal spheres, coaxial equal cylinders whose lengths overlap."""
    out = []
    balls = [p for p in parts if p.shape in ('Ball',)]
    cyl = [p for p in parts if p.shape == 'Cylinder']
    def key(p): return (round(p.p[0] / 2), round(p.p[1] / 2), round(p.p[2] / 2))
    idx = collections.defaultdict(list)
    for p in balls:
        idx[key(p)].append(p)
    for p in balls:
        k = key(p)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    for q in idx.get((k[0] + dx, k[1] + dy, k[2] + dz), ()):
                        if q.i <= p.i:
                            continue
                        dc = math.sqrt(dot(vsub(p.p, q.p), vsub(p.p, q.p)))
                        dr = abs(p.size[0] - q.size[0]) / 2
                        if dc + dr <= NEAR and p.look('Top') != q.look('Top'):
                            out.append({'a': p.i, 'b': q.i, 'pathA': p.path, 'pathB': q.path, 'faceA': 'Sphere', 'faceB': 'Sphere',
                                        'offset': round(dc + dr, 4), 'area': round(math.pi * p.size[0] ** 2, 3), 'tier': 'coplanar' if dc + dr <= COPLANAR else 'near',
                                        'visible': 1.0, 'same_look': False, 'mesh': False, 'normal': [0, 0, 0], 'at': [round(c, 2) for c in p.p], 'far_limit': 0})
    idx = collections.defaultdict(list)
    for p in cyl:
        idx[key(p)].append(p)
    for p in cyl:
        for q in cyl:
            if q.i <= p.i:
                continue
            if abs(abs(dot(p.cols[0], q.cols[0])) - 1) > 1e-4:
                continue
            r1, r2 = p.size[1] / 2, q.size[1] / 2
            if abs(r1 - r2) > NEAR:
                continue
            d = vsub(q.p, p.p); along = dot(d, p.cols[0]); perp = vsub(d, vmul(p.cols[0], along))
            if math.sqrt(dot(perp, perp)) + abs(r1 - r2) > NEAR:
                continue
            ov = min(p.size[0] / 2, along + q.size[0] / 2) - max(-p.size[0] / 2, along - q.size[0] / 2)
            if ov <= 0.05 or p.look('Top') == q.look('Top'):
                continue
            off = math.sqrt(dot(perp, perp)) + abs(r1 - r2)
            out.append({'a': p.i, 'b': q.i, 'pathA': p.path, 'pathB': q.path, 'faceA': 'Side', 'faceB': 'Side', 'offset': round(off, 4),
                        'area': round(2 * math.pi * r1 * ov, 3), 'tier': 'coplanar' if off <= COPLANAR else 'near', 'visible': 1.0, 'same_look': False,
                        'mesh': False, 'normal': [0, 0, 0], 'at': [round(c, 2) for c in p.p], 'far_limit': 0})
    return out


def load(path, area_fn=None):
    d = json.load(open(path))
    raw = d['parts']
    PLAYABLE[:] = d.get('playable', [])
    parts = []
    for i, x in enumerate(raw):
        try:
            parts.append(Part(i, x))
        except Exception as e:  # noqa
            print('skip part', x.get('path'), e, file=sys.stderr)
    return parts


def summarize(findings, parts, area_of):
    by = collections.Counter()
    for f in findings:
        if f['same_look']:
            continue
        a = area_of(parts[f['a']]) if area_of else 'all'
        b = area_of(parts[f['b']]) if area_of else 'all'
        key = a if a == b else a + '+' + b
        by[(key, f['tier'] + ('/mesh' if f['mesh'] else ''))] += 1
    return by


def area_label(parts, f):
    a, b = parts[f['a']].area or 'other', parts[f['b']].area or 'other'
    return a if a == b else '+'.join(sorted((a, b)))


def contrast(parts, f):
    pa, pb = parts[f['a']], parts[f['b']]
    if pa.look(f['faceA'])[1:] != pb.look(f['faceB'])[1:]:
        return 255
    return max(abs(x - y) for x, y in zip(pa.color, pb.color))


def run(path, max_offset=0.6):
    parts = load(path)
    byi = {p.i: p for p in parts}
    fs = detect(parts, max_offset)
    for f in fs:
        f['area_label'] = area_label(byi, f)
        f['contrast'] = contrast(byi, f)
    return parts, fs


def table(fs, key=lambda f: f['area_label']):
    """Counts of visible findings per area and tier (mesh pairs counted apart)."""
    rows = collections.defaultdict(collections.Counter)
    for f in fs:
        if f['same_look']:
            continue
        rows[key(f)][f['tier'] + ('/mesh' if f['mesh'] else '')] += 1
    return rows


TIERS = ['coplanar', 'near', 'far', 'coplanar/mesh', 'near/mesh', 'far/mesh', 'strict', 'strict/mesh']
COUNTED = ['coplanar', 'near', 'far']


def print_table(rows, title=''):
    if title:
        print(title)
    print('  %-26s %s  %s' % ('area', ' '.join('%13s' % t for t in TIERS), 'counted (coplanar+near+far, mesh included)'))
    tot = collections.Counter()
    for area in sorted(rows):
        r = rows[area]; tot.update(r)
        print('  %-26s %s  %5d' % (area, ' '.join('%13d' % r[t] for t in TIERS), counted(r)))
    print('  %-26s %s  %5d' % ('TOTAL', ' '.join('%13d' % tot[t] for t in TIERS), counted(tot)))


def counted(r):
    return sum(v for k, v in r.items() if k.split('/')[0] in COUNTED)


if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument('scene')
    ap.add_argument('--json')
    ap.add_argument('--list', type=int, default=40)
    ap.add_argument('--area', default=None)
    ap.add_argument('--tier', default=None)
    ap.add_argument('--grep', default=None)
    ap.add_argument('--group', action='store_true')
    ap.add_argument('--max-offset', type=float, default=0.6)
    a = ap.parse_args()
    parts, fs = run(a.scene, a.max_offset)
    vis = [f for f in fs if not f['same_look']]
    print('%d parts, %d findings (+%d look-alike pairs whose flicker cannot be seen)' % (len(parts), len(vis), len(fs) - len(vis)))
    print_table(table(fs))
    sel = [f for f in vis if (a.area is None or a.area in f['area_label']) and (a.tier is None or f['tier'] == a.tier)
           and (a.grep is None or a.grep in f['pathA'] or a.grep in f['pathB'])]
    sel.sort(key=lambda f: ({'coplanar': 0, 'near': 1, 'far': 2, 'strict': 3}[f['tier']], f['mesh'], -f['area']))
    if a.group:
        g = collections.OrderedDict()
        for f in sel:
            na = f['pathA'].rsplit('/', 1)[-1]; nb = f['pathB'].rsplit('/', 1)[-1]
            pa = f['pathA'].replace('Workspace/ChestChaseMap/', '').rsplit('/', 1)[0]
            k = (f['tier'], f['area_label'], pa, na + '.' + f['faceA'], nb + '.' + f['faceB'])
            if k not in g:
                g[k] = [0, 0.0, f]
            g[k][0] += 1; g[k][1] = max(g[k][1], f['area'])
        for k, (n, mx, f) in list(g.items())[:a.list]:
            print('%-8s %-12s x%-3d maxA=%6.2f off=%+.4f lim=%.3f c=%3d %s | %s <-> %s  e.g. at %s' % (k[0], k[1], n, mx, f['offset'], f['far_limit'], f['contrast'], k[2][-60:], k[3], k[4], f['at']))
        sel = []
    for f in sel[:a.list]:
        print('%-8s %-10s off=%+.4f lim=%.3f area=%7.2f vis=%.2f c=%3d %s %s.%s  <->  %s.%s  at %s' % (
            f['tier'], f['area_label'], f['offset'], f['far_limit'], f['area'], f['visible'], f['contrast'], 'MESH' if f['mesh'] else '',
            f['pathA'].replace('Workspace/ChestChaseMap/', ''), f['faceA'], f['pathB'].replace('Workspace/ChestChaseMap/', ''), f['faceB'], f['at']))
    if a.json:
        json.dump(fs, open(a.json, 'w'), indent=0)
