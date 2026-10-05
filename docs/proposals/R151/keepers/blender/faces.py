"""Graphic keeper faces, revision 4: classic Roblox face decals on flat face planes, two faces per keeper.

  Chase   shown whenever the keeper is awake (guarding, chasing, attacking, after a catch): the fierce face.
  Asleep  closed eyes and a relaxed mouth (the big "Z" is an effect, not part of the face).

Rev 3 projected each shape onto a faceted, jittered head, so the shapes bent over the facets and looked stretched.
Rev 4 gives every head a FLAT face plane (the front of a block) and lays each shape on it as a flat plate of even
thickness: nothing bends, nothing stretches. Each shape is a few bold convex outlines; the two eyes are one outline
mirrored, so they are always the same size and shape and placed symmetrically. Every plate is sunk into the head
(and into the plate under it), so it always touches the head (connectivity.py checks this).

Per state the pieces go into two mesh parts in the Head group:
  Head_Face_<State>   pupils, sockets, brows, mouth, teeth, closed-eye lines (the head's palette material)
  Head_Eyes_<State>   the glowing eye shapes (a KeeperEyeGlow Neon part)
The game would show the parts of the current state and hide the others (LocalTransparencyModifier).

Coordinates are Roblox rig space (face toward -Z). A face frame is (c, n, up): c is a point ON the flat face plane,
n the outward normal; u runs to screen-right when you look at the face, v runs up.
"""
import math
from mathutils import Vector

STATES = ['Chase', 'Asleep']
AWAKE = 'Chase'

# eye-local outlines (x toward the OUTER corner, y up), unit size, scaled by the eye's (w, h)
FIERCE = [(-0.5, -0.12), (-0.36, -0.5), (0.36, -0.5), (0.5, -0.3), (0.5, 0.5), (-0.5, 0.06)]   # angry: inner top cut low
ALMOND = [(-0.5, -0.08), (-0.18, 0.26), (0.5, 0.5), (0.36, -0.12), (0.0, -0.4), (-0.3, -0.34)]  # fox: pointed, outer corner up
SLOT = [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.0)]                                     # a glowing slit / hollow
SLIT = [(0.0, -0.46), (0.13, 0.0), (0.0, 0.46), (-0.13, 0.0)]                                   # cat / snake pupil
SQUARE = [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]


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


def place(pts, cu, cv, s, ang=0.0, w=1.0, h=1.0, dx=0.0, dy=0.0):
    """Eye-local outline -> face (u, v): scale, shift, rotate (ang > 0 raises the outer end), mirror for side s."""
    ca, sa = math.cos(ang), math.sin(ang)
    out = []
    for x, y in pts:
        x, y = x * w + dx, y * h + dy
        xr, yr = x * ca - y * sa, x * sa + y * ca
        out.append((cu + s * xr, cv + yr))
    return out


class FlatFace:
    """frames: name -> dict(c=point on the face plane, n=outward normal, up=(0, 1, 0)); 'face' is the default.
    unit: the base plate thickness in studs."""

    def __init__(self, k, group, frames, unit=0.08):
        self.k, self.group, self.unit = k, group, unit
        self.frames = {}
        for name, f in frames.items():
            n = Vector(f['n']).normalized()
            up = Vector(f.get('up', (0, 1, 0)))
            up = (up - n * up.dot(n)).normalized()
            self.frames[name] = (Vector(f['c']), n, up, up.cross(n).normalized())

    def g(self, state, kind='face'):
        return self.k.g(self.group, kind, state)

    def uv(self, p, fr='face'):
        """A 3D point -> (u, v) on a frame's plane."""
        c, n, up, right = self.frames[fr]
        d = Vector(p) - c
        return d.dot(right), d.dot(up)

    def main(self):
        return self.k.g(self.group)

    # ------------------------------------------------------------------ the one primitive: a flat plate on the plane
    def plate(self, g, poly, col, layer=0, fr='face', sink=None):
        """A convex outline (u, v) as a flat plate: its top `layer + 1` units above the face plane, its bottom sunk
        `sink` into the head. Higher layers sit on top of lower ones (a pupil on an eye on a socket)."""
        poly = hull2(poly)
        if len(poly) < 3:
            return
        c, n, up, right = self.frames[fr]
        u = self.unit
        sink = u * 2.0 if sink is None else sink
        top = u * (1.0 + layer * 0.9)
        tops = [c + right * a + up * b + n * top for a, b in poly]
        bots = [c + right * a + up * b - n * sink for a, b in poly]
        K = len(poly)
        faces = [tuple(range(K)), tuple(range(2 * K - 1, K - 1, -1))]
        faces += [(i, K + i, K + (i + 1) % K, (i + 1) % K) for i in range(K)]
        g.add(tops + bots, faces, col, False)

    def bar(self, g, p0, p1, width, col, layer=0, fr='face', ext=0.0):
        """A straight band from p0 to p1 (u, v) of the given width, lengthened by `ext` at both ends."""
        p0, p1 = Vector(p0), Vector(p1)
        d = (p1 - p0).normalized()
        q = Vector((-d.y, d.x)) * width / 2
        p0, p1 = p0 - d * ext, p1 + d * ext
        self.plate(g, [p0 - q, p1 - q, p1 + q, p0 + q], col, layer, fr)

    def polyline(self, g, pts, width, col, layer=0, fr='face'):
        """Bands through the points; the ends overlap at every corner, so the line reads as one stroke."""
        for a, b in zip(pts, pts[1:]):
            self.bar(g, a, b, width, col, layer, fr, ext=width * 0.42)

    # ------------------------------------------------------------------ eyes and brows
    def eye(self, state, cu, cv, w, h, shape=FIERCE, slant=0.0, pupil=SLIT, pupil_w=None, pupil_dx=-0.08, socket='eyedark',
            fr='face', col='iris', glow=True):
        """One fierce eye per side: a dark socket outline, the glowing eye shape (the Eyes part) and a pupil."""
        for s in (-1, 1):
            if socket:
                self.plate(self.g(state), place(shape, cu * s, cv, s, slant, w * 1.22, h * 1.3), socket, 0, fr)
            self.plate(self.g(state, 'eyes') if glow else self.g(state), place(shape, cu * s, cv, s, slant, w, h), col, 1, fr)
            if pupil:
                pw = pupil_w or h
                self.plate(self.g(state), place(pupil, cu * s, cv, s, 0.0, pw, h * 0.86, dx=pupil_dx * w), 'pupil', 2, fr)

    def closed_eye(self, state, cu, cv, w, width=0.2, curve=0.22, slant=0.0, col='lash', fr='face'):
        """Asleep: a thick closed-eye line curving down (relaxed), one per side, mirrored."""
        for s in (-1, 1):
            pts = [(-0.5 + i / 4, -curve * (1 - 4 * (-0.5 + i / 4) ** 2)) for i in range(5)]
            self.polyline(self.g(state), place(pts, cu * s, cv, s, slant, w, 1.0), width, col, 1, fr)

    def brow(self, state, cu, cv, w, h, slant=0.35, col='brow', fr='face'):
        """A heavy brow bar per side, thicker at the inner end; slant > 0 raises the outer end (angry)."""
        shape = [(-0.5, -0.5), (0.5, -0.32), (0.5, 0.32), (-0.5, 0.5)]
        for s in (-1, 1):
            self.plate(self.g(state), place(shape, cu * s, cv, s, slant, w, h), col, 1, fr)

    # ------------------------------------------------------------------ mouths
    def mouth(self, state, cu, cv, w, h, teeth_up=3, teeth_low=2, tooth_h=0.3, fang=0.0, inside='mouthin', tooth='tooth',
              outline='lip', fr='face', shape='roar', gold=None):
        """An open graphic mouth: a dark outline, the inside, triangle teeth on the top and bottom edges, two fangs."""
        shapes = {'roar': [(-0.5, 0.35), (-0.3, 0.5), (0.3, 0.5), (0.5, 0.35), (0.3, -0.5), (-0.3, -0.5)],
                  'snarl': [(-0.5, 0.3), (-0.4, 0.5), (0.4, 0.5), (0.5, 0.3), (0.4, -0.5), (-0.4, -0.5)],
                  'hiss': [(-0.5, 0.5), (0.5, 0.5), (0.32, -0.5), (-0.32, -0.5)],
                  'o': [(math.cos(a) * 0.5, math.sin(a) * 0.5) for a in [i * math.pi / 4 + math.pi / 8 for i in range(8)]]}
        base = shapes[shape]
        g = self.g(state)
        if outline:
            self.plate(g, [(cu + x * (w + 0.22), cv + y * (h + 0.22)) for x, y in base], outline, 0, fr)
        self.plate(g, [(cu + x * w, cv + y * h) for x, y in base], inside, 1, fr)
        top, bot = cv + h * 0.5, cv - h * 0.5

        def tri(x, y_edge, length, width, down, col):
            sg = -1 if down else 1
            self.plate(g, [(cu + x - width / 2, y_edge - sg * 0.04), (cu + x + width / 2, y_edge - sg * 0.04),
                           (cu + x, y_edge + sg * length)], col, 2, fr)
        span = w * 0.62
        for i in range(teeth_up):
            x = ((i + 0.5) / teeth_up - 0.5) * span
            tri(x, top, tooth_h, span / teeth_up * 0.8, True, 'goldtooth' if gold == i else tooth)
        for i in range(teeth_low):
            x = ((i + 0.5) / teeth_low - 0.5) * span * 0.8
            tri(x, bot, tooth_h * 0.85, span / max(teeth_up, 1) * 0.8, False, tooth)
        if fang:
            for s in (-1, 1):
                tri(s * w * 0.36, top + 0.02, fang, w * 0.16, True, tooth)

    def line(self, state, pts, width, col='lip', fr='face', kind='face', layer=1):
        """A drawn line (a closed mouth, a crack) through (u, v) points; kind 'eyes' makes it glow."""
        self.polyline(self.g(state, kind), pts, width, col, layer, fr)
