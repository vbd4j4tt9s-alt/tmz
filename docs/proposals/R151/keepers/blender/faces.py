"""Bold, expressive cartoon faces with swappable states, built as raised mesh pieces on a keeper's head.

Static (always shown): eye whites in the head mesh, the glowing irises (the KeeperEyeGlow part), pupils and two white
catchlights per eye. Per state (one small mesh part each, in the Head group, only one shown at a time): eyelids with a
dark lash line, bold brows, the mouth (opening, teeth, fangs, tongue, lips), cheeks and extras (drool, smoke).
Brows, lips and mouths are placed ON the head by casting rays at the skull mesh, so they always touch the head.

Coordinates are Roblox rig space (face toward -Z). An eye's local frame: x across (the eye sits on side s = +1 / -1),
y up, -z out of the face.
"""
import math
from mathutils import Vector, Matrix
import kit
from kit import Geo, blob, tube, rbox, spike, T, Rx, Ry, Rz

STATES = ['Idle', 'Chase', 'Attack', 'Asleep', 'Gloat']


def lid_cap(g, M, radii, h, t, u, upper, col, seg=18, rings=4, lash=None, lash_r=0.0):
    """The part of the ellipsoid (a, b, c) above (upper) or below the plane y = h + t*x + u*z, closed flat along the cut,
    plus an optional dark lash tube along the front of the cut edge."""
    a, b, c = radii

    def cut(th):
        kk = t * a * math.cos(th) + u * c * math.sin(th)
        lo, hi = -math.pi / 2, math.pi / 2
        f = lambda p: b * math.sin(p) - (h + kk * math.cos(p))
        if f(lo) > 0 or f(hi) < 0:
            return None
        for _ in range(40):
            m = (lo + hi) / 2
            if f(m) > 0:
                hi = m
            else:
                lo = m
        return (lo + hi) / 2
    cuts = [cut(2 * math.pi * j / seg) for j in range(seg)]
    if any(cp is None for cp in cuts):
        return
    verts, faces = [], []
    pe = math.pi / 2 if upper else -math.pi / 2
    for i in range(rings + 1):
        for j in range(seg):
            th = 2 * math.pi * j / seg
            p = cuts[j] + (pe - cuts[j]) * (i / (rings + 1))
            verts.append((a * math.cos(p) * math.cos(th), b * math.sin(p), c * math.cos(p) * math.sin(th)))
    pole = len(verts)
    verts.append((0, b if upper else -b, 0))
    for i in range(rings):
        for j in range(seg):
            q = (j + 1) % seg
            faces.append((i * seg + j, i * seg + q, (i + 1) * seg + q, (i + 1) * seg + j))
    for j in range(seg):
        faces.append((rings * seg + j, rings * seg + (j + 1) % seg, pole))
    cen = Vector((0, 0, 0))
    for j in range(seg):
        cen += Vector(verts[j])
    cen /= seg
    ci = len(verts)
    verts.append(tuple(cen))
    for j in range(seg):
        faces.append((ci, (j + 1) % seg, j))
    g.add([(M @ Vector((p[0], p[1], p[2], 1))).xyz for p in verts], faces, col, True)
    if lash:
        pts = []
        for j in range(13):
            th = math.pi * (1.06 + 0.88 * j / 12)
            p = cut(th)
            if p is None:
                continue
            pts.append((M @ Vector((a * math.cos(p) * math.cos(th) * 1.01, b * math.sin(p), c * math.cos(p) * math.sin(th) * 1.01, 1))).xyz)
        if len(pts) >= 2:
            tube(g, pts, [lash_r] * len(pts), lash, seg=6, cap0='round', cap1='round', smooth=True)


class Face:
    """One keeper's face. skull: a Geo of the head surface the face sits on (for ray placement).
    eyes: list of dict(E, r, s, yaw, pitch). mouth: dict(c = a point inside the head behind the mouth,
    n = outward direction, up = up direction)."""

    def __init__(self, k, group, skull, eyes, lid_col, lash_col='lash', brow_col='brow', mouth=None, sclera='white',
                 iris_r=0.70, iris_kind='eyes'):
        self.k, self.group, self.skull = k, group, skull
        self.bvh = skull.bvh()
        self.eyes = eyes
        self.lid_col, self.lash_col, self.brow_col = lid_col, lash_col, brow_col
        self.mouth = mouth
        self.sclera = sclera
        self.iris_r = iris_r
        self.iris_kind = iris_kind

    def eyeM(self, e):
        return T(e['E']) @ Ry(-e['s'] * e.get('yaw', 0.3)) @ Rx(e.get('pitch', 0.0)) @ Rz(e.get('roll', 0.0) * e['s'])

    # ------------------------------------------------------------------ static eye parts
    def build_eyes(self, pupil=True, slit=False, catch=True):
        head = self.k.g(self.group)
        iris = self.k.g(self.group, self.iris_kind)
        for e in self.eyes:
            M = self.eyeM(e)
            r = e['r']
            ia, ib = r * self.iris_r, r * (self.iris_r + 0.06)
            if self.sclera:
                blob(head, (0, 0, 0), (r, r * 1.1, r * 0.62), self.sclera, M=M, seg=18, rings=11, smooth=True)
            blob(iris, (0, 0, 0), (ia, ib, r * 0.30), 'iris', M=M @ T(0, 0, -r * 0.40), seg=18, rings=10, smooth=True)

            def zs(x, y):
                q = 1 - (x / ia) ** 2 - (y / ib) ** 2
                return -(r * 0.40 + r * 0.30 * math.sqrt(max(0.0, q)))
            if pupil:
                if slit:
                    blob(head, (0, 0, 0), (r * 0.15, r * 0.6, r * 0.12), 'pupil', M=M @ T(0, 0, zs(0, 0) + r * 0.07), seg=12, rings=8, smooth=True)
                else:
                    blob(head, (0, 0, 0), (r * 0.34, r * 0.40, r * 0.12), 'pupil', M=M @ T(0, -0.03 * r, zs(0, 0) + r * 0.07), seg=14, rings=8, smooth=True)
            if catch:
                x1, y1 = -0.28 * r, 0.30 * r
                blob(head, (0, 0, 0), (r * 0.18, r * 0.18, r * 0.08), 'white', M=M @ T(x1, y1, zs(x1, y1) - r * 0.015), seg=10, rings=6, smooth=True)
                x2, y2 = 0.22 * r, -0.22 * r
                blob(head, (0, 0, 0), (r * 0.09, r * 0.09, r * 0.05), 'white', M=M @ T(x2, y2, zs(x2, y2) - r * 0.015), seg=8, rings=5, smooth=True)

    # ------------------------------------------------------------------ per-state pieces
    def g(self, state):
        return self.k.g(self.group, 'face', state)

    def lids(self, state, spec):
        """spec per eye: dict(up=(h, t, u) or None, low=(h, t, u) or None) with h in units of r; t (x slope) is
        mirrored per side so t > 0 lowers the inner corner (angry), u (z slope) curves the lid line."""
        g = self.g(state)
        for e, sp in zip(self.eyes, spec):
            r = e['r']
            M = self.eyeM(e)
            radii = (r * 1.1, r * 1.2, r * 0.86)
            if sp.get('up'):
                h, t, u = sp['up']
                lid_cap(g, M, radii, h * r, t * e['s'], u, True, self.lid_col, lash=self.lash_col, lash_r=0.08 * r)
            if sp.get('low'):
                h, t, u = sp['low']
                lid_cap(g, M, radii, h * r, t * e['s'], u, False, self.lid_col,
                        lash=self.lash_col if sp.get('lowlash') else None, lash_r=0.06 * r)

    def _surface(self, origin, direction):
        """The outermost surface point along the ray (cast back from far outside) and its outward normal."""
        d = Vector(direction).normalized()
        hit = self.bvh.ray_cast(Vector(origin) + d * 60.0, -d)
        if hit[0] is None:
            return None, None
        n = hit[1] if hit[1].dot(d) > 0 else -hit[1]
        return hit[0], n

    def brows(self, state, spec, col=None):
        """spec per eye (None = no brow): dict(dy, ang, dx, arch, len, thick, width) in units of r.
        ang > 0 lowers the inner end (angry), ang < 0 raises it (worried / smug)."""
        g = self.g(state)
        for e, sp in zip(self.eyes, spec):
            if sp is None:
                continue
            r = e['r']
            M = self.eyeM(e)
            ln = sp.get('len', 2.3)
            n = 6
            centre_in = (M @ Vector((0, 0, r * 1.8, 1))).xyz
            rays = []
            for i in range(n):
                f = i / (n - 1) - 0.5
                x = f * ln * r + sp.get('dx', 0) * r * e['s']
                y = r * (1.3 + sp.get('dy', 0)) + math.tan(sp.get('ang', 0.3)) * (x - sp.get('dx', 0) * r * e['s']) * e['s']
                y += sp.get('arch', 0.12) * r * (1 - 4 * f * f)
                target = (M @ Vector((x, y, -r * 0.55, 1))).xyz
                rays.append((centre_in, target - centre_in))
            kit.stroke(g, self.bvh, rays, col or self.brow_col, sp.get('width', 0.42) * r, thick=sp.get('thick', 0.38) * r,
                       seg=5, lift=0.02, outside=True)

    def frame(self):
        m = self.mouth
        n = Vector(m['n']).normalized()
        up = Vector(m['up'])
        up = (up - n * up.dot(n)).normalized()
        right = up.cross(n).normalized()
        return n, up, right

    def on_face(self, u, v):
        n, up, right = self.frame()
        o = Vector(self.mouth['c']) + right * u + up * v
        p, nn = self._surface(o, n)
        return p, nn, right, up

    def mouth_line(self, state, pts, width, thick, col='mouth'):
        """A drawn mouth line (smirk, frown, closed mouth) through (u, v) points, lying on the face."""
        n, up, right = self.frame()
        rays = [((Vector(self.mouth['c']) + right * u + up * v), n) for u, v in pts]
        kit.stroke(self.g(state), self.bvh, rays, col, width, thick=thick, seg=6, lift=0.02, taper=True, outside=True)

    def mouth_open(self, state, w, h, dv=0.0, du=0.0, shape='oval', teeth_up=0, teeth_low=0, tooth=0.18, tongue=True,
                   col='mouthin', tooth_col='tooth', tongue_col='tongue', lip=None, fang=0.0, tilt=0.0, depth=0.5,
                   lower_fang=0.0):
        """An open mouth: a hollow (dark red inside) pressed half into the face, teeth along the edges, fangs, a tongue,
        and an optional lip ring. shape: 'oval', 'D' (flat top: grin / laugh), 'Dinv' (flat bottom: frown / yell)."""
        g = self.g(state)
        p, nn, right, up = self.on_face(du, dv)
        if p is None:
            return
        R = Matrix((right, up, nn)).transposed().to_4x4() @ Rz(tilt)

        def deform(q):
            if shape == 'D' and q.y > 0:
                return Vector((q.x, q.y * 0.2, q.z))
            if shape == 'Dinv' and q.y < 0:
                return Vector((q.x, q.y * 0.2, q.z))
            return q
        M = T(p) @ R
        blob(g, (0, 0, 0), (w / 2, h / 2, depth), col, M=M, seg=18, rings=10, deform=deform, smooth=True)
        top = h / 2 * (0.2 if shape == 'D' else 1.0)
        bot = h / 2 * (0.2 if shape == 'Dinv' else 1.0)

        def edge_y(x, row):
            curved = (row == 'up' and shape != 'D') or (row == 'low' and shape != 'Dinv')
            yy = (top if row == 'up' else bot)
            if curved:
                yy *= math.sqrt(max(0.0, 1 - (2 * x / w) ** 2))
            return yy if row == 'up' else -yy
        for row, cnt in (('up', teeth_up), ('low', teeth_low)):
            for i in range(cnt):
                f = (i + 0.5) / cnt - 0.5
                x = f * w * 0.8
                y0 = edge_y(x, row)
                sgn = -1 if row == 'up' else 1
                c = (M @ Vector((x, y0 + sgn * tooth * 0.38, depth * 0.35, 1))).xyz
                blob(g, (0, 0, 0), (tooth * 0.42, tooth * 0.6, tooth * 0.45), tooth_col, M=T(c) @ R, e1=0.6, e2=0.7, seg=8, rings=6)
        if fang:
            for sx in (-1, 1):
                x = sx * w * 0.3
                y0 = edge_y(x, 'up')
                c = (M @ Vector((x, y0 + tooth * 0.2, depth * 0.3, 1))).xyz
                tip = (M @ Vector((x, y0 - fang, depth * 0.45, 1))).xyz
                spike(g, c, tip, tooth * 0.55, tooth_col, seg=5, smooth=False)
        if lower_fang:
            for sx in (-1, 1):
                x = sx * w * 0.36
                y0 = edge_y(x, 'low')
                c = (M @ Vector((x, y0 - tooth * 0.2, depth * 0.3, 1))).xyz
                tip = (M @ Vector((x, y0 + lower_fang, depth * 0.45, 1))).xyz
                spike(g, c, tip, tooth * 0.5, tooth_col, seg=5, smooth=False)
        if tongue:
            c = (M @ Vector((w * 0.06, -bot * 0.5, depth * 0.45, 1))).xyz
            blob(g, (0, 0, 0), (w * 0.24, h * 0.2, depth * 0.3), tongue_col, M=T(c) @ R, seg=12, rings=7, smooth=True)
        if lip:
            pts = []
            for i in range(19):
                a = 2 * math.pi * i / 18
                q = deform(Vector((math.cos(a) * w / 2 * 1.02, math.sin(a) * h / 2 * 1.02, 0)))
                q = (Rz(tilt) @ q.to_4d()).xyz
                pts.append((du + q.x, dv + q.y))
            self.mouth_line(state, pts, lip[0], lip[1], col=lip[2] if len(lip) > 2 else 'lip')

    def cheek(self, state, u, v, rad, col):
        g = self.g(state)
        p, nn, right, up = self.on_face(u, v)
        if p is None:
            return
        blob(g, p, (rad, rad * 0.75, rad * 0.5), col, M=Matrix((right, up, nn)).transposed().to_4x4(), seg=12, rings=7)

    def drool(self, state, u, v, length, col='drool'):
        g = self.g(state)
        p, nn, right, up = self.on_face(u, v)
        if p is None:
            return
        pts = [p - nn * 0.08, p - up * length * 0.5 + nn * 0.04, p - up * length]
        tube(g, pts, [length * 0.12, length * 0.1, length * 0.15], col, seg=8, cap0='round', cap1='round', smooth=True)
        blob(g, p - up * length * 1.05, (length * 0.2, length * 0.26, length * 0.2), col, seg=10, rings=7, smooth=True)
