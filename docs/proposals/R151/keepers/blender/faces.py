"""Graphic keeper faces, revision 3: two faces per keeper, swapped by state.

  Chase   shown whenever the keeper is awake (guarding, chasing, attacking, after a catch): the fierce face. Glowing
          angular eyes in dark sockets, heavy slanted brows, a roaring or snarling mouth with teeth and fangs.
  Asleep  closed eyes, relaxed brows, a snoring or relaxed mouth (the big "Z" is an effect, not part of the face).

Each face is a set of flat graphic shapes (not carved): every shape is a convex outline drawn in a face plane, projected
onto the head's outermost surface along the face direction, raised a little above it and sunk into it, so it always
touches the head (connectivity.py checks this). Per state the pieces go into two mesh parts in the Head group:
  Head_Face_<State>   sockets, pupils, brows, mouth, teeth, closed-eye lines (the head's palette material)
  Head_Eyes_<State>   the glowing eye shapes (a KeeperEyeGlow Neon part); only the Chase face has one
The game would show the parts of the current state and hide the others (LocalTransparencyModifier).

Coordinates are Roblox rig space (face toward -Z). A face frame is (c, n, up): c is a point inside the head, n the
outward face direction; u runs to screen-right when you look at the face, v runs up.
"""
import math
from mathutils import Vector
import kit

STATES = ['Chase', 'Asleep']
AWAKE = 'Chase'

# outlines in eye-local units (x toward the outer corner, y up), scaled by the eye's (w, h)
ANGRY_EYE = [(-0.5, -0.02), (-0.36, 0.14), (0.38, 0.5), (0.5, 0.3), (0.38, -0.28), (0.02, -0.5), (-0.32, -0.38)]
LID_EYE = [(-0.5, 0.0), (-0.3, 0.32), (0.3, 0.36), (0.5, 0.05), (0.3, -0.3), (-0.3, -0.32)]
SLIT = [(0.0, -0.46), (0.11, 0.0), (0.0, 0.46), (-0.11, 0.0)]
DOT = [(math.cos(a) * 0.17, math.sin(a) * 0.24) for a in [i * math.pi / 3 + 0.3 for i in range(6)]]
BROW = [(-0.55, -0.62), (0.58, -0.30), (0.62, 0.22), (-0.5, 0.62)]          # thick at the inner end
MOUTHS = {
    'roar': [(-0.5, 0.22), (-0.3, 0.5), (0.3, 0.5), (0.5, 0.22), (0.32, -0.38), (0.0, -0.5), (-0.32, -0.38)],
    'snarl': [(-0.5, 0.12), (-0.36, 0.5), (0.36, 0.5), (0.5, 0.12), (0.36, -0.5), (-0.36, -0.5)],
    'grin': [(-0.5, 0.5), (0.5, 0.5), (0.42, 0.05), (0.2, -0.42), (-0.2, -0.42), (-0.42, 0.05)],
    'hiss': [(-0.5, 0.4), (0.5, 0.4), (0.3, -0.45), (-0.3, -0.45)],
    'snore': [(math.cos(a) * 0.5, math.sin(a) * 0.5) for a in [i * math.pi / 4 for i in range(8)]],
}


def hull2(pts):
    """Convex hull of 2D points, counter-clockwise (monotone chain)."""
    pts = sorted(set((round(p[0], 6), round(p[1], 6)) for p in pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
            hi.pop()
        hi.append(p)
    return lo[:-1] + hi[:-1]


def span_y(poly, x):
    """(bottom, top) of a convex polygon at x."""
    ys = []
    n = len(poly)
    for i in range(n):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % n]
        if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
            ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
    return (min(ys), max(ys)) if ys else (0.0, 0.0)


class Face:
    """skull: a Geo of the head surface the face is laid on. frames: name -> dict(c, n, up); 'face' is the default.
    unit: the base thickness step in studs (about 1/12 of an eye's height)."""

    def __init__(self, k, group, skull, frames, unit=0.08):
        self.k, self.group = k, group
        self.bvh = skull.bvh()
        self.frames = {}
        for name, f in frames.items():
            n = Vector(f['n']).normalized()
            up = Vector(f.get('up', (0, 1, 0)))
            up = (up - n * up.dot(n)).normalized()
            self.frames[name] = (Vector(f['c']), n, up, up.cross(n).normalized())
        self.unit = unit

    def g(self, state, kind='face'):
        return self.k.g(self.group, kind, state)

    # ------------------------------------------------------------------ the one primitive: a projected plate
    def project(self, fr, u, v):
        c, n, up, right = self.frames[fr]
        o = c + right * u + up * v
        hit = self.bvh.ray_cast(o + n * 60.0, -n)
        if hit[0] is not None:
            return hit[0]
        near = self.bvh.find_nearest(o)          # off the edge of the head: snap to the closest surface point
        return near[0] if near[0] is not None else o

    def plate(self, g, poly, col, thick, lift=0.0, sink=None, fr='face', res=None):
        """A convex 2D outline (u, v) laid on the head: top at surface + lift + thick, bottom `sink` below the surface."""
        poly = hull2(poly)
        if len(poly) < 3:
            return
        c, n, up, right = self.frames[fr]
        sink = self.unit * 2.5 if sink is None else sink
        res = res or max(0.25, self.unit * 4.5)
        outline = []
        for i in range(len(poly)):
            a, b = Vector(poly[i]), Vector(poly[(i + 1) % len(poly)])
            m = max(1, int(math.ceil((b - a).length / res)))
            outline += [a + (b - a) * (j / m) for j in range(m)]
        cen = sum(outline, Vector((0.0, 0.0))) / len(outline)
        K = len(outline)
        R = max(1, min(3, int(math.ceil(max((p - cen).length for p in outline) / res))))
        grid = [cen] + [cen + (p - cen) * (r / R) for r in range(1, R + 1) for p in outline]
        tops, bots = [], []
        for q in grid:
            p = self.project(fr, q.x, q.y)
            tops.append(p + n * (lift + thick))
            bots.append(p - n * sink)
        N = len(grid)

        def ix(r, kk):
            return 0 if r == 0 else 1 + (r - 1) * K + (kk % K)
        faces = []
        for kk in range(K):
            faces.append((ix(0, 0), ix(1, kk), ix(1, kk + 1)))
            for r in range(1, R):
                faces.append((ix(r, kk), ix(r + 1, kk), ix(r + 1, kk + 1), ix(r, kk + 1)))
        bottom = [tuple(N + i for i in reversed(f)) for f in faces]
        sides = [(ix(R, kk), N + ix(R, kk), N + ix(R, kk + 1), ix(R, kk + 1)) for kk in range(K)]
        g.add(tops + bots, faces + bottom + sides, col, False)

    # ------------------------------------------------------------------ shape helpers
    @staticmethod
    def place(pts, cu, cv, s, ang=0.0, w=1.0, h=1.0, dx=0.0, dy=0.0):
        """Eye-local outline -> face (u, v): scale, shift, rotate (ang > 0 raises the outer end), mirror for side s."""
        ca, sa = math.cos(ang), math.sin(ang)
        out = []
        for x, y in pts:
            x, y = x * w + dx, y * h + dy
            xr, yr = x * ca - y * sa, x * sa + y * ca
            out.append((cu + s * xr, cv + yr))
        return out

    # ------------------------------------------------------------------ eyes
    def eye(self, state, cu, cv, w, h, s, slant=0.3, pupil='slit', pupil_dx=-0.06, socket='eyedark', pad=0.2, fr='face',
            glow=True, col='iris'):
        """A fierce glowing eye: dark socket, angular glowing shape (the Eyes part), slit or dot pupil."""
        u = self.unit
        fg = self.g(state)
        if socket:
            self.plate(fg, self.place(ANGRY_EYE, cu, cv, s, slant, w * (1 + pad), h * (1 + pad * 1.6)), socket, u * 1.0, fr=fr)
        self.plate(self.g(state, 'eyes') if glow else fg, self.place(ANGRY_EYE, cu, cv, s, slant, w, h), col, u * 1.0, lift=u * 0.8, fr=fr)
        if pupil:
            shape = SLIT if pupil == 'slit' else DOT
            self.plate(fg, self.place(shape, cu, cv, s, slant, w, h, dx=pupil_dx * w), 'pupil', u * 0.8, lift=u * 1.6, fr=fr)

    def closed_eye(self, state, cu, cv, w, h, s, slant=0.0, lid='lid', line='lash', curve=0.22, fr='face'):
        """Asleep: a lid shape in a darker head tone and a thick closed-eye line curving down (relaxed)."""
        u = self.unit
        fg = self.g(state)
        if lid:
            self.plate(fg, self.place(LID_EYE, cu, cv, s, slant, w * 1.05, h * 0.9), lid, u * 1.0, fr=fr)
        pts = []
        for i in range(7):
            x = -0.5 + i / 6
            pts.append((x, -curve * (1 - 4 * x * x)))
        pts = self.place(pts, cu, cv, s, slant, w * 0.92, h)
        c, n, up, right = self.frames[fr]
        rays = [(c + right * a + up * b, n) for a, b in pts]
        kit.stroke(fg, self.bvh, rays, line, max(0.05, h * 0.13), thick=u * 1.2, seg=5, lift=u * 1.0, outside=True)

    def brow(self, state, cu, cv, w, h, s, slant=0.35, col='brow', fr='face', thick=None):
        """A heavy angular brow slab, thicker at the inner end."""
        u = self.unit
        self.plate(self.g(state), self.place(BROW, cu, cv, s, slant, w, h), col, thick or u * 2.6, lift=u * 0.6, fr=fr)

    # ------------------------------------------------------------------ mouths
    def mouth(self, state, cu, cv, w, h, shape='roar', teeth_up=4, teeth_low=4, tooth_h=0.24, fang=0.0, lower_fang=0.0,
              inside='mouthin', tooth='tooth', tongue='tongue', outline='lip', pad=0.1, gold=None, fr='face', tooth_w=None):
        """An open graphic mouth: a dark outline, the inside, a tongue, triangle teeth along the top and bottom edges and
        bigger fangs. gold: index of one top tooth drawn in 'goldtooth'."""
        u = self.unit
        fg = self.g(state)
        base = [(x * w, y * h) for x, y in MOUTHS[shape]]
        poly = [(cu + x, cv + y) for x, y in base]
        if outline:
            self.plate(fg, [(cu + x * (1 + pad), cv + y * (1 + pad * 2.2)) for x, y in base], outline, u * 0.8, fr=fr)
        self.plate(fg, poly, inside, u * 0.8, lift=u * 0.4, fr=fr)
        if tongue:
            self.plate(fg, [(cu + x * w * 0.42, cv - h * 0.24 + y * h * 0.36) for x, y in MOUTHS['snore']], tongue, u * 0.6,
                       lift=u * 1.0, fr=fr)
        loc = [(x, y) for x, y in base]
        tw = tooth_w or w * 0.8 / max(teeth_up, teeth_low, 1) * 0.8

        def tri(x, y_base, length, width, down, col):
            sg = -1 if down else 1
            pts = [(cu + x - width / 2, cv + y_base - sg * u * 0.6), (cu + x + width / 2, cv + y_base - sg * u * 0.6),
                   (cu + x, cv + y_base + sg * length)]
            self.plate(fg, pts, col, u * 0.9, lift=u * 1.0, fr=fr)
        for row, cnt in (('up', teeth_up), ('low', teeth_low)):
            for i in range(cnt):
                x = ((i + 0.5) / cnt - 0.5) * w * 0.78
                lo, hi = span_y(loc, x)
                col = 'goldtooth' if (gold is not None and row == 'up' and i == gold) else tooth
                if row == 'up':
                    tri(x, hi, tooth_h, tw, True, col)
                else:
                    tri(x, lo, tooth_h * 0.85, tw, False, col)
        for sx in (-1, 1):
            if fang:
                x = sx * w * 0.3
                tri(x, span_y(loc, x)[1], fang, tw * 1.35, True, tooth)
            if lower_fang:
                x = sx * w * 0.36
                tri(x, span_y(loc, x)[0], lower_fang, tw * 1.25, False, tooth)

    def line(self, state, pts, width, col='lip', fr='face', kind='face'):
        """A drawn line on the face (a closed mouth, a crack) through (u, v) points; kind 'eyes' makes it glow."""
        c, n, up, right = self.frames[fr]
        rays = [(c + right * a + up * b, n) for a, b in pts]
        kit.stroke(self.g(state, kind), self.bvh, rays, col, width, thick=self.unit * 1.2, seg=5, lift=self.unit * 0.3, outside=True)

    def drool(self, state, cu, cv, length, col='drool', fr='face'):
        w = length * 0.32
        pts = [(cu - w * 0.35, cv), (cu + w * 0.35, cv), (cu + w * 0.5, cv - length * 0.8), (cu, cv - length),
               (cu - w * 0.5, cv - length * 0.8)]
        self.plate(self.g(state), pts, col, self.unit * 0.8, lift=self.unit * 1.0, fr=fr)

    def mark(self, state, poly, col, fr='face', lift=None):
        """A bold graphic marking (war paint, a scar, a cheek stripe) as one convex plate."""
        self.plate(self.g(state), poly, col, self.unit * 0.7, lift=self.unit * 0.3 if lift is None else lift, fr=fr)
