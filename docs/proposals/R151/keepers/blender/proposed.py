"""PROPOSED keepers: chunky, rounded, big-faced creatures built by script, split into the SAME groups the game animates.

Each keeper is a KeeperModel: per rig group one main mesh (palette colours + atlas UVs), plus small single-colour parts:
  <Group>_Eyes  : the glowing irises (KeeperEyeGlow parts: the game turns them Neon in the keeper colour when awake),
  <Group>_Glow  : Neon accents (lava seams, crystal hearts, lightning cores) - same idea as today's Glow parts.
BeastBody keepers (stages 1-7) are authored in rig space (the frame the game's RestCFrame values use; the face looks to -Z,
the floor is y = -4). The Darkened is authored per group in its group-local space (its parts are placed frame * VeiledFrame).
"""
import math
from mathutils import Vector, Matrix
import kit
from kit import Geo, Palette, blob, tube, rbox, horn, spike, crystal, membrane, bezier, T, Rx, Ry, Rz, V

WHITE = (0.97, 0.97, 0.96)
PUPIL = (0.06, 0.06, 0.09)


class KeeperModel:
    def __init__(self, key, name, stage, palette, glow=None, eye_rgb=(1, 1, 1), floor=-4.0, local=False):
        self.key, self.name, self.stage = key, name, stage
        pal = {'white': WHITE, 'pupil': PUPIL, 'iris': eye_rgb}
        pal.update(palette)
        self.pal = Palette(pal)
        self.glow_rgb = glow or {}
        self.eye_rgb = eye_rgb
        self.geos = {}
        self.order = []
        self.floor = floor
        self.local = local  # The Darkened: per-group local geometry
        self.tree_map = {}  # golem: part name -> today's part whose tree delta it follows

    def g(self, group, kind='main', piece=None):
        k = (group, kind, piece)
        if k not in self.geos:
            name = group if kind == 'main' else '%s_%s' % (group, 'Eyes' if kind == 'eyes' else 'Glow')
            if piece:
                name = '%s_%s' % (name, piece)
            self.geos[k] = Geo(name)
            self.order.append(k)
        return self.geos[k]

    def parts(self):
        for k in self.order:
            group, kind, piece = k
            geo = self.geos[k]
            if geo.v:
                yield group, kind, piece, geo

    def tris(self):
        return sum(g.tris() for _, _, _, g in self.parts())


def eye(head, iris, E, r, s, yaw=0.3, pitch=0.0, brow=0.35, brow_col='brow', sclera='white', pupil='pupil',
        slit=False, brow_len=2.3, brow_th=0.45, hollow=None, pupils=True):
    """A big cartoon eye facing local -Z: sclera (head mesh), glowing iris (the KeeperEyeGlow part), pupil and glint
    in front of the iris (head mesh), and an angled brow (inner end low = determined / angry)."""
    M = T(E) @ Ry(-s * yaw) @ Rx(pitch)

    def at(x, y, z):
        return M @ T(x, y, z)
    if hollow:
        blob(head, (0, 0, 0), (r * 1.18, r * 1.18, r * 0.5), hollow, M=at(0, 0, 0.12 * r))
    elif sclera:
        blob(head, (0, 0, 0), (r, r * 1.08, r * 0.62), sclera, M=at(0, 0, 0), seg=14, rings=9)
    blob(iris, (0, 0, 0), (r * 0.70, r * 0.76, r * 0.30), 'iris', M=at(0, 0, -r * 0.40), seg=14, rings=8)
    if pupils:
        if slit:
            blob(head, (0, 0, 0), (r * 0.15, r * 0.62, r * 0.12), pupil, M=at(0, 0, -r * 0.62), seg=10, rings=7)
        else:
            blob(head, (0, 0, 0), (r * 0.34, r * 0.42, r * 0.12), pupil, M=at(0, -0.04 * r, -r * 0.62), seg=12, rings=7)
        blob(head, (0, 0, 0), (r * 0.16, r * 0.16, r * 0.08), 'white', M=at(-0.28 * r, 0.30 * r, -r * 0.70), seg=8, rings=5)
    if brow:
        rbox(head, (0, 0, 0), (brow_len * r, brow_th * r, 0.85 * r), brow_col, round_=0.45,
             M=at(-s * 0.05 * r, 1.08 * r, -0.28 * r) @ Rz(s * brow), seg=10, rings=6)


def mirror(fn):
    for s in (-1, 1):
        fn(s)


# =========================================================================================== Stage 3: Ice Fang (Snow)
def ice_fang():
    k = KeeperModel('ice_fang', 'Ice Fang', 3, {
        'fur': (0.93, 0.95, 0.98), 'fur2': (0.80, 0.86, 0.94), 'belly': (1.0, 1.0, 1.0), 'stripe': (0.30, 0.40, 0.56),
        'muzzle': (1.0, 0.99, 0.97), 'nose': (0.36, 0.42, 0.55), 'tooth': (0.98, 0.98, 1.0), 'inner': (0.55, 0.78, 0.98),
        'silver': (0.78, 0.81, 0.88), 'silverdk': (0.55, 0.60, 0.70), 'sapphire': (0.16, 0.38, 0.92), 'ice': (0.62, 0.86, 1.0),
        'brow': (0.36, 0.45, 0.60), 'claw': (0.70, 0.86, 1.0), 'mouth': (0.30, 0.16, 0.24), 'tongue': (0.92, 0.48, 0.55)},
        eye_rgb=(0.22, 0.72, 0.95))

    def fur(c):  # white belly, pale blue-grey back
        if c.y < 1.1:
            return 'belly'
        return 'fur'
    body = k.g('Body')
    torso = Geo('torso')
    # torso: deep chest, a slight waist, round hips (one smooth piece)
    tube(torso, [(0, 2.2, -2.5), (0, 2.4, 0.2), (0, 2.25, 3.6), (0, 2.25, 6.6), (0, 2.15, 9.5)],
         [(2.65, 2.4), (2.75, 2.45), (2.4, 2.2), (2.55, 2.3), (2.5, 2.3)], fur, seg=16)
    body.extend(torso)
    bvh = torso.bvh()
    # tiger stripes painted on as strokes lying on the fur (crisp edges, no staircase)
    for z0 in (-0.6, 1.7, 5.2, 7.6):
        for s in (-1, 1):
            rays = []
            for i in range(8):
                th = math.radians(22 + 105 * i / 7)
                zc = z0 + 0.7 * math.sin(th * 1.5)
                rays.append(((0, 2.3, zc), (s * math.sin(th), math.cos(th), 0.0)))
            kit.stroke(body, bvh, rays, 'stripe', 0.42, thick=0.1, seg=5)
    blob(body, (0, 1.2, -2.5), (2.45, 2.0, 2.0), 'belly', seg=14, rings=9)        # fluffy chest ruff
    for s in (-1, 1):
        for i, (y, z) in enumerate(((1.8, -3.6), (0.8, -3.2), (2.6, -3.9))):
            spike(body, (s * 1.3, y, z), (s * 1.6, y - 0.9, z - 1.0), 0.65, 'belly', smooth=True)
    blob(body, (0, 3.1, -3.3), (2.5, 1.8, 1.45), fur, seg=14, rings=9)           # neck / shoulders
    # silver saddle plate with the big sapphire, collar plate (R149 armour, now part of the mesh)
    blob(body, (0, 4.38, 3.5), (2.2, 0.45, 2.8), 'silver', e1=0.45, e2=0.6, seg=16, rings=8)
    crystal(body, (0, 4.56, 3.5), (0, 1, 0), 0.75, 0.9, 'sapphire', sides=6)
    tube(body, [(-2.25, 2.3, -3.7), (-1.65, 4.05, -3.95), (0, 4.85, -4.05), (1.65, 4.05, -3.95), (2.25, 2.3, -3.7)],
         [(0.5, 0.36)] * 5, 'silver', seg=8, cap0='round', cap1='round')
    for x in (-1.2, 0, 1.2):
        blob(body, (x, 4.5 - abs(x) * 0.55, -4.4), (0.3, 0.3, 0.22), 'sapphire', seg=8, rings=5, smooth=False)
    # ice spines along the spine (today's accent, now in the mesh)
    for z, h in ((-1.3, 1.4), (0.5, 1.7), (6.7, 1.55), (8.4, 1.2)):
        crystal(body, (0, 4.3, z), (0, 1, 0.45), 0.45, h, 'ice')
    # Head ---------------------------------------------------------------------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')

    skull = Geo('skull')
    blob(skull, (0, 3.55, -6.9), (2.7, 2.15, 2.75), 'fur', e1=0.92, e2=0.92, seg=16, rings=10)
    head.extend(skull)
    hb = skull.bvh()
    for s in (-1, 1):   # cheek stripes
        for dy in (0.85, 0.2):
            rays = [((0, 3.4 + dy, -6.6 + 0.45 * i), (s, 0.15, -0.25 + 0.06 * i)) for i in range(4)]
            kit.stroke(head, hb, rays, 'stripe', 0.2, thick=0.07, seg=5)
    mirror(lambda s: blob(head, (s * 2.05, 2.55, -6.1), (1.0, 1.25, 1.55), 'belly', seg=12, rings=8))   # cheek ruffs
    mirror(lambda s: [spike(head, (s * 2.55, 2.4 + d, -5.6), (s * 3.05, 2.0 + d * 1.4, -4.5), 0.42, 'belly', smooth=True)
                      for d in (-0.6, 0.3)])
    blob(head, (0, 2.55, -9.45), (1.55, 1.1, 1.45), 'muzzle', seg=14, rings=9)    # muzzle
    mirror(lambda s: blob(head, (s * 0.62, 2.55, -10.55), (0.72, 0.62, 0.55), 'muzzle', seg=10, rings=7))
    blob(head, (0, 3.32, -10.72), (0.55, 0.36, 0.32), 'nose', seg=10, rings=6)
    mirror(lambda s: spike(head, (s * 0.72, 2.15, -10.35), (s * 0.82, 0.55, -10.25), 0.27, 'tooth', seg=8, smooth=True))  # sabre fangs
    mirror(lambda s: blob(head, (s * 1.95, 5.15, -5.5), (1.0, 1.05, 0.48), 'fur', seg=10, rings=7, M=Rz(-s * 0.4)))   # ears
    mirror(lambda s: blob(head, (s * 1.98, 5.08, -5.8), (0.6, 0.66, 0.18), 'inner', seg=10, rings=6, M=Rz(-s * 0.4)))
    # silver helm plate with a sapphire between the brows
    blob(head, (0, 5.25, -6.9), (1.45, 0.42, 2.0), 'silver', e1=0.5, e2=0.6, seg=14, rings=7, M=Rx(-0.12))
    crystal(head, (0, 5.0, -8.65), (0, 0.55, -1), 0.42, 0.75, 'sapphire', sides=6)
    mirror(lambda s: eye(head, iris, (s * 1.18, 4.0, -9.25), 0.66, s, yaw=0.38, pitch=0.08, brow=0.38, brow_col='brow'))
    # Jaw ------------------------------------------------------------------------------------------------
    jaw = k.g('Jaw')
    blob(jaw, (0, 1.85, -8.75), (1.35, 0.55, 1.45), 'muzzle', seg=12, rings=8)
    blob(jaw, (0, 2.1, -8.9), (1.05, 0.25, 1.15), 'mouth', seg=12, rings=6)
    blob(jaw, (0, 2.2, -8.7), (0.6, 0.14, 0.8), 'tongue', seg=10, rings=5)
    mirror(lambda s: spike(jaw, (s * 0.85, 2.1, -9.7), (s * 0.85, 2.65, -9.75), 0.15, 'tooth', smooth=True))
    # Legs: thick, short, big paws with ice claws, silver bracers and pauldrons ----------------------------
    def leg(group, x, z0, top, piv, front):
        s = 1 if x > 0 else -1
        g = k.g(group)
        # muscular upper leg (shoulder / haunch) tapering into a thick forearm, big round paw
        if front:
            blob(g, (x, 1.25, z0 + 0.15), (1.3, 1.75, 1.75), fur, seg=14, rings=9)
        else:
            blob(g, (x, 1.25, z0 + 0.35), (1.42, 1.85, 1.95), fur, seg=14, rings=9)
        tube(g, [(x, 0.6, z0), (x + s * 0.05, -1.2, z0 - 0.15), (x, -2.9, z0 - 0.3)],
             [(1.22, 1.35), (1.08, 1.18), (1.1, 1.18)], fur, seg=12)
        blob(g, (x, -3.7, z0 - 0.75), (1.32, 0.88, 1.65), 'belly', e1=0.7, e2=0.8, seg=12, rings=8)     # big round paw
        for dx in (-0.62, 0, 0.62):
            spike(g, (x + dx, -3.95, z0 - 2.1), (x + dx, -4.5, z0 - 2.5), 0.2, 'claw', seg=6)
        lb = Geo('legtmp')
        tube(lb, [(x, 0.6, z0), (x + s * 0.05, -1.2, z0 - 0.15), (x, -2.9, z0 - 0.3)], [(1.22, 1.35), (1.08, 1.18), (1.1, 1.18)], 'fur', seg=12)
        bv = lb.bvh()
        for y in (-0.6,):
            rays = [((x, y, z0 - 0.15), (s * math.cos(a), 0.0, -math.sin(a))) for a in [math.radians(-50 + 18 * i) for i in range(8)]]
            kit.stroke(g, bv, rays, 'stripe', 0.3, thick=0.08, seg=5)
        if front:   # silver pauldron with a sapphire (R149 armour, now part of the mesh)
            blob(g, (x + s * 0.55, 1.95, z0), (1.15, 1.0, 1.65), 'silver', e1=0.5, e2=0.6, seg=12, rings=7, M=Rz(s * 0.35))
            blob(g, (x + s * 1.45, 1.75, z0), (0.36, 0.36, 0.36), 'sapphire', seg=8, rings=5, smooth=False)
    leg('LeftFrontLeg', -2.25, -3.35, 2.4, None, True)
    leg('RightFrontLeg', 2.25, -3.35, 2.4, None, True)
    leg('LeftBackLeg', -2.25, 9.85, 2.4, None, False)
    leg('RightBackLeg', 2.25, 9.85, 2.4, None, False)
    # Tail: thick striped tail curling up and to +X, with an ice crystal tip and a silver ring ----------------
    tail = k.g('Tail')
    pts = bezier((0.1, 2.1, 11.7), (0.8, 1.2, 16.5), (2.6, 2.4, 19.0), (3.0, 1.8, 21.3), n=10)

    trad = [1.15, 1.08, 1.0, 0.95, 0.9, 0.85, 0.82, 0.8, 0.78, 0.75, 0.7]
    tube(tail, pts, trad, 'fur', seg=12, cap1='round')
    for i in (3, 5, 7, 9):
        a_, b_ = pts[i], pts[i] + (pts[i + 1] - pts[i]) * 0.45
        tube(tail, [a_, b_], [trad[i] * 1.06, trad[i] * 1.06], 'stripe', seg=12, cap0='flat', cap1='flat')
    tube(tail, [(0.15, 1.95, 12.5), (0.25, 1.9, 13.2)], [1.22, 1.22], 'silver', seg=12, cap0='flat', cap1='flat')
    crystal(tail, (3.0, 1.8, 21.2), (0.25, 0.25, 1), 0.55, 1.2, 'ice')
    return k


# =========================================================================================== Stage 2: Sand Snake (Desert)
SNAKE_PIVOTS = [(0.0, -2.63, 0.6), (1.0, -2.75, 3.7), (3.15, -2.87, 6.7), (4.0, -3.0, 10.0), (3.3, -3.12, 13.3),
                (1.3, -3.24, 16.3), (-1.5, -3.36, 18.8), (-4.0, -3.49, 21.3), (-5.0, -3.61, 24.3), (-5.35, -3.75, 27.0)]


def sand_snake():
    k = KeeperModel('sand_snake', 'Sand Snake', 2, {
        'sand': (0.90, 0.72, 0.42), 'saddle': (0.62, 0.38, 0.20), 'rim': (0.98, 0.90, 0.68), 'belly': (0.99, 0.93, 0.74),
        'hood': (0.86, 0.62, 0.32), 'mark': (0.40, 0.22, 0.12), 'horn': (0.55, 0.36, 0.22), 'brow': (0.52, 0.31, 0.16),
        'mouth': (0.55, 0.16, 0.20), 'tongue': (0.86, 0.18, 0.26), 'tooth': (1.0, 1.0, 0.97), 'nose': (0.35, 0.20, 0.10)},
        eye_rgb=(0.96, 0.65, 0.12))
    radii = [1.55, 1.42, 1.28, 1.15, 1.0, 0.86, 0.72, 0.58, 0.45, 0.30]

    def segcol(i):
        def f(c):
            return 'sand'
        return f
    for i in range(9):
        g = k.g('Segment%d' % (i + 1))
        a, b = Vector(SNAKE_PIVOTS[i]), Vector(SNAKE_PIVOTS[i + 1])
        ra, rb_ = radii[i], radii[i + 1]
        pa = Vector((a.x, -4 + ra * 0.95, a.z))
        pb = Vector((b.x, -4 + rb_ * 0.95, b.z))
        mid = (pa + pb) / 2
        tube(g, [pa, mid, pb], [(ra * 1.22, ra * 0.95), ((ra + rb_) / 2 * 1.24, (ra + rb_) / 2 * 0.97), (rb_ * 1.22, rb_ * 0.95)],
             segcol(i), seg=14, cap0='round', cap1='round' if i < 8 else 'point')
        # desert-viper diamond saddle on the back of every segment (cream rim, brown diamond)
        d = pb - pa
        ang = math.atan2(d.x, d.z)
        rm = (ra + rb_) / 2
        top = -4 + rm * 0.95 + rm * 0.97
        ln = d.length
        blob(g, (mid.x, top - rm * 0.16, mid.z), (rm * 0.98, rm * 0.24, ln * 0.47), 'rim', e1=1.0, e2=1.7, seg=16, rings=6, M=Ry(ang))
        blob(g, (mid.x, top - rm * 0.1, mid.z), (rm * 0.72, rm * 0.24, ln * 0.36), 'saddle', e1=1.0, e2=1.7, seg=16, rings=6, M=Ry(ang))
    # Head: raised neck, a broad hood, a big rounded head with horns and amber eyes --------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')

    neck_pts = bezier((0, -2.45, 2.0), (0, -2.2, -0.3), (0, -0.4, -1.2), (0, 1.25, -3.0), n=8)
    neck = Geo('neck')
    tube(neck, neck_pts, [(1.6, 1.25), (1.58, 1.25), (1.5, 1.22), (1.45, 1.2), (1.4, 1.18), (1.38, 1.16), (1.35, 1.15), (1.32, 1.12), (1.3, 1.1)],
         'sand', seg=14)
    head.extend(neck)
    # cream belly scales down the front of the neck: a band painted on the surface (crisp edge)
    rays = []
    for i in range(1, 8):
        t = (neck_pts[i + 1] - neck_pts[i - 1]).normalized()
        n = t.cross(Vector((1, 0, 0)))
        if n.z > 0:
            n = -n
        rays.append((neck_pts[i], n))
    kit.stroke(head, neck.bvh(), rays, 'belly', 0.72, thick=0.1, seg=6, taper=False)
    # hood: sandy back with the dark spectacle mark, a cream inner face
    hood = Rx(-0.32)
    blob(head, (0, 1.2, -2.15), (2.85, 2.55, 0.55), 'hood', seg=18, rings=10, M=hood)
    blob(head, (0, 0, 0), (2.5, 2.2, 0.3), 'belly', seg=16, rings=9, M=T(0, 1.12, -2.4) @ hood)
    mirror(lambda s: blob(head, (s * 0.95, 1.65, -1.55), (0.62, 0.62, 0.12), 'mark', seg=10, rings=6, M=Rx(-0.32)))
    blob(head, (0, 2.05, -5.0), (2.05, 1.32, 2.45), 'sand', e1=0.85, e2=0.9, seg=18, rings=11)
    blob(head, (0, 1.85, -6.85), (1.45, 0.92, 0.85), 'sand', seg=12, rings=8)          # snout
    blob(head, (0, 1.2, -5.6), (1.7, 0.42, 2.2), 'belly', seg=14, rings=7)              # pale upper lip
    mirror(lambda s: blob(head, (s * 0.4, 2.25, -7.66), (0.08, 0.055, 0.05), 'nose', seg=6, rings=4))
    mirror(lambda s: eye(head, iris, (s * 1.28, 2.75, -6.0), 0.64, s, yaw=0.4, pitch=0.12, brow=0.45, brow_col='brow', slit=True))
    mirror(lambda s: horn(head, (s * 1.1, 3.25, -5.5), (s * 1.38, 4.15, -5.15), (s * 1.7, 4.1, -4.35), 0.36, 'horn'))
    mirror(lambda s: spike(head, (s * 0.72, 1.35, -6.75), (s * 0.78, 0.45, -6.9), 0.17, 'tooth', seg=6, smooth=True))   # fangs
    # Jaw: lower jaw, mouth and the forked tongue
    jaw = k.g('Jaw')
    blob(jaw, (0, 0.95, -5.0), (1.72, 0.38, 2.75), 'belly', seg=14, rings=7)
    blob(jaw, (0, 1.2, -5.3), (1.38, 0.16, 2.25), 'mouth', seg=12, rings=5)
    tube(jaw, [(0, 1.15, -6.4), (0, 1.0, -7.4), (0, 0.95, -7.8)], [0.12, 0.11, 0.1], 'tongue', seg=6, cap0='flat', cap1='none')
    mirror(lambda s: tube(jaw, [(0, 0.95, -7.75), (s * 0.28, 0.9, -8.1)], [0.1, 0.03], 'tongue', seg=6, cap0='round', cap1='point'))
    return k


# =========================================================================================== Stage 4: Lava Dragon (Lava)
def lava_dragon():
    k = KeeperModel('lava_dragon', 'Lava Dragon', 4, {
        'scale': (0.62, 0.13, 0.10), 'scale2': (0.42, 0.09, 0.09), 'belly': (0.98, 0.72, 0.30), 'belly2': (0.92, 0.56, 0.22),
        'horn': (0.98, 0.90, 0.74), 'spike': (0.22, 0.10, 0.11), 'wing': (0.95, 0.38, 0.16), 'wing2': (0.80, 0.22, 0.12),
        'bone': (0.30, 0.10, 0.10), 'brow': (0.28, 0.06, 0.07), 'mouth': (0.35, 0.05, 0.06), 'tooth': (1.0, 0.98, 0.92),
        'claw': (0.20, 0.12, 0.12), 'nostril': (0.2, 0.05, 0.05)},
        glow={'*': (1.0, 0.45, 0.08)}, eye_rgb=(0.95, 0.20, 0.05))

    def body_col(c):
        if c.y < 1.6 and c.z < 5.0:
            return 'belly' if int((c.y + 10) / 0.75) % 2 == 0 else 'belly2'
        return 'scale'
    body = k.g('Body')
    blob(body, (0, 2.15, 0.9), (3.35, 3.15, 4.4), body_col, e1=0.9, e2=0.92, seg=20, rings=12)
    blob(body, (0, 3.0, -2.6), (2.6, 2.3, 2.0), body_col, seg=14, rings=9)   # chest into the neck
    for z, h in ((-1.6, 1.3), (0.6, 1.6), (2.8, 1.5), (4.8, 1.2)):
        spike(body, (0, 4.9 - 0.04 * z * z * 0.2, z), (0, 4.9 + h, z + 0.9), 0.62, 'spike', seg=6)
    bglow = k.g('Body', 'glow')
    for z in (-0.5, 1.7, 3.8):
        blob(bglow, (0, 5.05, z), (0.42, 0.35, 0.8), 'iris', seg=8, rings=5)
    # Head + neck ------------------------------------------------------------------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    neck_pts = bezier((0, 3.3, -2.3), (0, 4.6, -4.0), (0, 6.3, -5.4), (0, 6.9, -7.0), n=7)
    neck = Geo('neck')
    tube(neck, neck_pts, [1.9, 1.85, 1.75, 1.65, 1.6, 1.58, 1.55, 1.5], 'scale', seg=14, cap0='flat')
    head.extend(neck)
    rays = []
    for i in range(1, 7):
        t = (neck_pts[i + 1] - neck_pts[i - 1]).normalized()
        n = t.cross(Vector((1, 0, 0)))
        if n.z > 0:
            n = -n
        rays.append((neck_pts[i], n))
    kit.stroke(head, neck.bvh(), rays, 'belly', 1.0, thick=0.1, seg=6, taper=False)
    blob(head, (0, 7.45, -8.4), (2.3, 1.9, 2.5), 'scale', e1=0.9, e2=0.9, seg=18, rings=11)       # skull
    blob(head, (0, 6.85, -11.3), (1.65, 1.15, 2.2), 'scale', e1=0.85, e2=0.9, seg=14, rings=9)    # snout
    blob(head, (0, 6.25, -11.0), (1.55, 0.55, 2.0), 'belly', seg=12, rings=6)                     # upper lip
    mirror(lambda s: blob(head, (s * 0.55, 7.55, -12.95), (0.24, 0.18, 0.14), 'nostril', seg=6, rings=4))
    mirror(lambda s: eye(head, iris, (s * 1.3, 8.15, -9.7), 0.66, s, yaw=0.45, pitch=0.1, brow=0.42, brow_col='brow', slit=True))
    mirror(lambda s: horn(head, (s * 1.15, 8.7, -7.3), (s * 1.6, 10.6, -6.4), (s * 1.95, 10.85, -3.3), 0.62, 'horn', seg=8, n=7))
    mirror(lambda s: horn(head, (s * 1.95, 6.9, -7.2), (s * 2.5, 7.3, -6.2), (s * 2.55, 7.6, -5.0), 0.32, 'horn', seg=6, n=4))
    for z in (-9.2, -10.3, -11.4, -12.3):
        mirror(lambda s: spike(head, (s * 1.25, 5.95, z), (s * 1.2, 5.45, z), 0.15, 'tooth', seg=5, smooth=True))
    hglow = k.g('Head', 'glow')
    mirror(lambda s: blob(hglow, (s * 0.55, 7.52, -13.05), (0.16, 0.12, 0.06), 'iris', seg=6, rings=4))
    # Jaw ----------------------------------------------------------------------------------------------------
    jaw = k.g('Jaw')
    blob(jaw, (0, 5.2, -10.1), (1.55, 0.58, 2.85), 'scale2', seg=14, rings=8)
    blob(jaw, (0, 5.62, -10.3), (1.25, 0.2, 2.4), 'mouth', seg=12, rings=5)
    for z in (-9.0, -10.4, -11.8):
        mirror(lambda s: spike(jaw, (s * 1.05, 5.6, z), (s * 1.0, 6.05, z), 0.13, 'tooth', seg=5, smooth=True))
    # Legs: stubby, scaled, big clawed feet ------------------------------------------------------------------
    def leg(group, x, z, front):
        s = 1 if x > 0 else -1
        g = k.g(group)
        if front:
            blob(g, (x, 1.3, z), (1.35, 1.5, 1.55), 'scale', seg=12, rings=8)
            tube(g, [(x, 1.0, z), (x - s * 0.1, -1.6, z - 0.4), (x, -3.5, z - 0.6)], [1.2, 1.0, 0.95], 'scale', seg=12)
            fz = z - 1.4
        else:
            blob(g, (x - s * 0.15, 0.6, z), (1.55, 2.0, 2.15), 'scale', seg=12, rings=8)
            tube(g, [(x, -0.4, z + 0.6), (x, -2.2, z + 0.7), (x, -3.6, z - 0.2)], [1.25, 1.05, 0.98], 'scale', seg=12)
            fz = z - 1.1
        blob(g, (x, -4.15, fz), (1.15, 0.65, 1.45), 'scale2', e1=0.7, e2=0.8, seg=12, rings=7)
        for dx in (-0.55, 0, 0.55):
            spike(g, (x + dx, -4.3, fz - 1.15), (x + dx * 1.1, -4.75, fz - 1.75), 0.22, 'claw', seg=6)
    leg('LeftFrontLeg', -2.75, -3.0, True)
    leg('RightFrontLeg', 2.75, -3.0, True)
    leg('LeftBackLeg', -2.85, 4.6, False)
    leg('RightBackLeg', 2.85, 4.6, False)
    # Tail with spikes and a lava-flame tip -----------------------------------------------------------------
    tail = k.g('Tail')
    pts = bezier((0, 1.2, 6.2), (0.4, 0.2, 10.0), (2.4, -0.2, 13.8), (4.0, 0.7, 17.4), n=10)
    rads = [1.55 * (1 - i / 11.5) + 0.32 for i in range(11)]
    tube(tail, pts, rads, lambda c: 'belly' if c.y < -0.1 and c.z < 12 else 'scale', seg=12, cap1='round')
    for i in (2, 4, 6, 8):
        p = pts[i]
        spike(tail, (p.x, p.y + rads[i] * 0.8, p.z), (p.x, p.y + rads[i] * 0.8 + 0.75, p.z + 0.65), 0.4, 'spike', seg=5)
    tglow = k.g('Tail', 'glow')
    tube(tglow, [(3.9, 0.75, 17.2), (4.2, 1.0, 18.0), (4.45, 1.5, 18.35)], [0.75, 0.55, 0.0], 'iris', seg=8, cap0='round', cap1='point')
    # Wings: arm, three finger bones, scalloped membrane (one mesh per wing, inside today's wing bounds) -------
    for s, group in ((-1, 'LeftWing'), (1, 'RightWing')):
        g = k.g(group)
        sh = Vector((s * 2.9, 4.7, -1.1))
        el = Vector((s * 7.3, 9.0, 0.3))
        wr = Vector((s * 10.4, 10.6, 1.0))
        tips = [Vector((s * 12.9, 8.3, 3.0)), Vector((s * 11.6, 5.9, 6.0)), Vector((s * 8.2, 4.0, 7.9))]
        root = Vector((s * 3.0, 4.4, 4.2))
        tube(g, [sh, el], [0.55, 0.42], 'bone', seg=8)
        tube(g, [el, wr], [0.42, 0.34], 'bone', seg=8)
        for tp in tips:
            tube(g, [wr, tp], [0.3, 0.1], 'bone', seg=6, cap1='point')
        spike(g, wr, wr + Vector((s * 0.3, 1.1, -0.6)), 0.25, 'claw', seg=5)
        # membrane panels, each sagging between its bones
        chain = [sh, el, wr]
        for tp in tips:
            chain.append(tp)
        panels = [(el, wr, tips[0], (el + tips[0]) / 2 + Vector((0, -0.6, 0.6))),
                  (wr, tips[0], (tips[0] + tips[1]) / 2 + Vector((-s * 0.8, 0.2, -0.3)), tips[1]),
                  (wr, tips[1], (tips[1] + tips[2]) / 2 + Vector((-s * 0.9, 0.4, -0.6)), tips[2]),
                  (sh, wr, tips[2], (tips[2] + root) / 2 + Vector((s * 0.3, 0.6, -0.9)), root)]
        for i, poly in enumerate(panels):
            membrane(g, poly, 0.18, 'wing' if i % 2 == 0 else 'wing2')
        # Designed at the wing's authored size, then enlarged x1.35 about the hinge like the game's V110 WingScale,
        # so the finished wing matches today's in-game wing bounds.
        pv = Vector((s * 2.84, 4.19, -1.3))
        g.v = [pv + (p - pv) * 1.35 for p in g.v]
    return k


# =========================================================================================== Stage 6: Jungle King (Jungle)
def jungle_king():
    k = KeeperModel('jungle_king', 'Jungle King', 6, {
        'fur': (0.24, 0.24, 0.26), 'fur2': (0.33, 0.33, 0.35), 'silver': (0.72, 0.74, 0.76), 'skin': (0.36, 0.30, 0.30),
        'muzzle': (0.48, 0.40, 0.38), 'brow': (0.20, 0.16, 0.16), 'nostril': (0.08, 0.06, 0.06), 'mouth': (0.35, 0.10, 0.12),
        'tooth': (1.0, 0.98, 0.92), 'vine': (0.24, 0.48, 0.16), 'leaf': (0.32, 0.70, 0.24), 'leaf2': (0.20, 0.55, 0.20),
        'gold': (0.98, 0.78, 0.25), 'knuckle': (0.28, 0.24, 0.24)},
        glow={'*': (1.0, 0.42, 0.78)}, eye_rgb=(0.95, 0.62, 0.15))

    def furcol(c):
        return 'silver' if c.z > 1.6 and c.y > 3.5 else 'fur'
    body = k.g('Body')
    blob(body, (0, 4.5, 0.6), (4.35, 3.15, 3.0), furcol, e1=0.85, e2=0.9, seg=20, rings=12)     # huge chest / back
    blob(body, (0, 1.7, 1.2), (3.1, 2.1, 2.5), 'fur', seg=16, rings=10)                          # belly / hips
    blob(body, (0, 4.4, -2.0), (2.8, 2.35, 0.95), 'skin', seg=16, rings=9)                       # chest skin
    mirror(lambda s: blob(body, (s * 1.3, 5.15, -2.35), (1.45, 1.05, 0.62), 'skin', seg=12, rings=7))  # pecs
    # vine sash with leaves across the chest
    sash = bezier((-3.7, 6.6, -1.4), (-1.0, 4.6, -3.25), (1.8, 2.4, -2.9), (3.2, 1.3, -1.7), n=10)
    tube(body, sash, [0.32] * 11, 'vine', seg=7)
    for i in (2, 5, 8):
        p = sash[i]
        blob(body, (p.x, p.y + 0.35, p.z - 0.35), (0.62, 0.16, 0.36), 'leaf', seg=8, rings=5, M=Rz(0.6) @ Rx(0.9))
    # Head ---------------------------------------------------------------------------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    blob(head, (0, 9.15, -2.1), (2.95, 2.35, 2.7), 'fur', e1=0.9, e2=0.9, seg=18, rings=11)
    blob(head, (0, 10.85, -1.3), (1.35, 0.95, 2.0), 'fur', seg=12, rings=8)                      # crest
    blob(head, (0, 8.75, -3.95), (2.35, 1.95, 1.15), 'skin', seg=16, rings=9)                    # face
    mirror(lambda s: rbox(head, (0, 0, 0), (2.7, 0.85, 1.35), 'brow', round_=0.5, M=T(s * 1.05, 9.9, -4.5) @ Rz(s * 0.3)))  # heavy V brow
    mirror(lambda s: eye(head, iris, (s * 1.02, 9.25, -4.85), 0.56, s, yaw=0.25, pitch=0.05, brow=None))
    blob(head, (0, 7.95, -4.75), (1.65, 1.0, 0.95), 'muzzle', seg=14, rings=8)
    mirror(lambda s: blob(head, (s * 0.38, 8.4, -5.55), (0.24, 0.17, 0.12), 'nostril', seg=6, rings=4))
    mirror(lambda s: blob(head, (s * 2.9, 9.0, -2.4), (0.45, 0.62, 0.5), 'skin', seg=8, rings=6))   # ears
    # leaf crown with a golden band and a glowing orchid
    tube(head, [Vector((math.cos(a) * 1.85, 11.15, -1.5 + math.sin(a) * 1.85)) for a in [i * math.pi / 6 for i in range(13)]],
         [0.26] * 13, 'gold', seg=6, cap0='none', cap1='none')
    for i in range(7):
        a = math.pi * (0.15 + 0.7 * i / 6)
        x, z = math.cos(a) * 1.9, -1.5 - math.sin(a) * 1.9
        blob(head, (x, 11.7, z), (0.5, 0.95, 0.18), 'leaf' if i % 2 else 'leaf2', seg=8, rings=6,
             M=Ry(-a + math.pi / 2) @ Rx(-0.3))
    hglow = k.g('Head', 'glow')
    for i in range(5):
        a = i * 2 * math.pi / 5
        blob(hglow, (1.55 + math.cos(a) * 0.3, 11.65 + math.sin(a) * 0.3, -2.75), (0.26, 0.26, 0.12), 'iris', seg=8, rings=5)
    # Jaw
    jaw = k.g('Jaw')
    blob(jaw, (0, 7.05, -4.3), (1.38, 0.52, 0.85), 'muzzle', seg=12, rings=7)
    blob(jaw, (0, 7.38, -4.55), (1.05, 0.2, 0.55), 'mouth', seg=10, rings=5)
    mirror(lambda s: spike(jaw, (s * 0.72, 7.3, -4.85), (s * 0.7, 8.0, -4.95), 0.17, 'tooth', seg=6, smooth=True))
    # Arms: massive, knuckle-walking, vine bracers -----------------------------------------------------------
    for s, group in ((-1, 'LeftArm'), (1, 'RightArm')):
        g = k.g(group)
        blob(g, (s * 4.65, 6.15, 0.1), (2.35, 2.3, 2.5), 'fur', seg=14, rings=9)
        tube(g, bezier((s * 4.75, 5.6, -0.1), (s * 5.15, 3.4, -0.6), (s * 5.15, 1.4, -1.5), (s * 5.35, -1.9, -2.5), n=7),
             [1.95, 1.7, 1.45, 1.55, 1.9, 1.95, 1.7, 1.5], 'fur', seg=14)
        blob(g, (s * 5.35, -2.95, -2.85), (1.95, 1.15, 1.7), 'skin', e1=0.75, e2=0.85, seg=14, rings=8)  # fist
        for dx in (-1.05, -0.35, 0.35, 1.05):
            blob(g, (s * 5.35 + dx, -3.55, -4.3), (0.42, 0.42, 0.38), 'knuckle', seg=8, rings=5)
        tube(g, [(s * 5.28, -0.35, -2.05), (s * 5.3, -0.95, -2.25)], [2.0, 1.98], 'vine', seg=14, cap0='flat', cap1='flat')
        for dz in (-0.8, 0.9):
            blob(g, (s * (5.3 + 1.85), -0.6, -2.15 + dz), (0.2, 0.75, 0.42), 'leaf', seg=8, rings=5, M=Rx(0.4 * dz))
        spike(g, (s * 6.4, 2.4, 0.1), (s * 7.2, 2.0, 1.2), 0.5, 'fur2', smooth=True)   # elbow tuft
    for s, group in ((-1, 'LeftBackLeg'), (1, 'RightBackLeg')):
        g = k.g(group)
        blob(g, (s * 1.95, 0.3, 1.5), (1.45, 1.7, 1.6), 'fur', seg=12, rings=8)
        tube(g, [(s * 1.95, -0.2, 1.3), (s * 2.0, -2.9, 0.6)], [1.25, 1.1], 'fur', seg=12)
        blob(g, (s * 2.0, -3.45, -0.1), (1.25, 0.6, 1.85), 'skin', e1=0.7, e2=0.8, seg=12, rings=7)
    return k


# =========================================================================================== Stage 1: Timber Golem (Forest)
def timber_golem():
    k = KeeperModel('timber_golem', 'Timber Golem', 1, {
        'bark': (0.50, 0.33, 0.20), 'bark2': (0.38, 0.24, 0.14), 'bark3': (0.62, 0.43, 0.27), 'moss': (0.40, 0.66, 0.27),
        'moss2': (0.30, 0.55, 0.22), 'leaf': (0.33, 0.62, 0.24), 'leaf2': (0.45, 0.74, 0.30), 'leaf3': (0.24, 0.50, 0.20),
        'hollow': (0.10, 0.07, 0.05), 'brow': (0.30, 0.19, 0.11), 'mush': (0.95, 0.56, 0.22), 'mush2': (1.0, 0.85, 0.55),
        'tooth': (0.80, 0.66, 0.45)},
        glow={'*': (0.51, 0.96, 0.64)}, eye_rgb=(0.51, 0.96, 0.64))

    def barkcol(c, cx=0.0, cz=0.0):
        return 'bark'

    def grooves(g, target, cx, cz, y0, y1, angles, width=0.2, n=6):
        """Vertical bark grooves painted on as strokes (crisp lines instead of stair-stepped face colours)."""
        bv = target.bvh()
        for a in angles:
            d = (math.cos(a), 0.0, math.sin(a))
            rays = [((cx, y0 + (y1 - y0) * i / (n - 1), cz), (d[0], 0.04 * math.sin(i * 1.7 + a * 3), d[2])) for i in range(n)]
            kit.stroke(g, bv, rays, 'bark2', width, thick=0.08, seg=4)
    # Body: one trunk piece + moss mantle + mushroom shelves + glowing heartwood rune -----------------------
    body = k.g('Body')
    trunk = Geo('trunk')
    blob(trunk, (0, 6.0, 0), (4.05, 4.2, 2.85), 'bark', e1=0.62, e2=0.8, seg=20, rings=11)
    body.extend(trunk)
    grooves(body, trunk, 0, 0, 2.6, 9.0, [math.radians(a) for a in (-150, -118, -62, -30, 10, 48, 80, 112, 145, 180, 215, 245, 295, 330)], 0.2)
    blob(body, (0, 9.85, 0.1), (4.25, 0.95, 2.95), 'moss', e1=0.7, seg=18, rings=8)
    for x, z, r in ((-2.6, -1.6, 1.0), (1.4, -2.2, 0.9), (2.9, 1.2, 1.1), (-1.5, 2.0, 0.9)):
        blob(body, (x, 10.4, z), (r, 0.55, r), 'moss2', seg=10, rings=6)
    for (x, y, z, r, c) in ((3.6, 8.6, -1.2, 1.15, 'mush'), (3.85, 7.9, 0.4, 0.8, 'mush2'), (-3.7, 5.2, 0.6, 0.95, 'mush')):
        blob(body, (x, y, z), (r, 0.32, r), c, seg=12, rings=6)
    bglow = k.g('Body', 'glow')
    crystal(bglow, (0, 5.4, -2.75), (0, 1, -0.12), 0.55, 2.2, 'iris', sides=4)
    # Head: stump head with the carved face (piece 'Stump'), leafy canopy (piece 'Canopy') ------------------
    head, iris = k.g('Head', 'main', 'Stump'), k.g('Head', 'eyes')
    stump = Geo('stump')
    blob(stump, (0, 12.3, -0.2), (2.75, 2.65, 2.6), 'bark', e1=0.55, e2=0.85, seg=16, rings=9)
    head.extend(stump)
    grooves(head, stump, 0, -0.2, 10.4, 14.2, [math.radians(a) for a in (-20, 20, 60, 100, 140, 180, 220)], 0.18, n=5)
    mirror(lambda s: eye(head, iris, (s * 1.12, 12.55, -2.55), 0.6, s, yaw=0.2, brow=0.42, brow_col='brow', hollow='hollow',
                         pupils=False, brow_len=2.6, brow_th=0.6))
    blob(head, (0, 10.95, -2.55), (1.55, 0.55, 0.42), 'hollow', seg=12, rings=6)                    # mouth
    for x in (-0.9, -0.3, 0.3, 0.9):
        spike(head, (x, 11.45, -2.75), (x, 10.95, -2.85), 0.2, 'tooth', seg=4)
    canopy = k.g('Head', 'main', 'Canopy')
    for (x, y, z, rx, ry, rz, c) in ((0, 17.0, 0.7, 6.0, 3.4, 5.4, 'leaf'), (-4.4, 15.6, 0.8, 3.0, 2.4, 3.3, 'leaf3'),
                                     (4.5, 15.7, 0.6, 3.0, 2.3, 3.3, 'leaf3'), (1.2, 19.6, 0.6, 3.7, 1.9, 3.2, 'leaf2'),
                                     (-1.8, 18.8, 2.2, 3.0, 1.8, 2.8, 'leaf2'), (0, 15.2, -3.0, 4.2, 1.5, 1.9, 'leaf3'),
                                     (0.6, 16.2, 4.4, 4.0, 2.0, 2.4, 'leaf3')):
        blob(canopy, (x, y, z), (rx, ry, rz), c, seg=14, rings=8)
    mirror(lambda s: tube(canopy, [(s * 1.9, 14.3, 0.6), (s * 3.2, 16.4, 0.7), (s * 4.5, 17.8, 0.3)], [0.55, 0.4, 0.22], 'bark2', seg=6))
    # Arms (LeftArm is +X): pieces Upper (shoulder + upper arm), Fist (forearm, fist, root fingers), Tier (leaf tiers, bough)
    for s, group in ((1, 'LeftArm'), (-1, 'RightArm')):
        up = k.g(group, 'main', 'Upper')
        blob(up, (s * 5.55, 8.45, 0.0), (1.85, 2.0, 2.3), 'bark', e1=0.7, seg=14, rings=9)
        blob(up, (s * 5.6, 10.25, 0.15), (2.0, 0.75, 2.45), 'moss', seg=12, rings=7)
        fist = k.g(group, 'main', 'Fist')
        fa = Geo('forearm')
        tube(fa, [(s * 5.75, 6.9, -0.2), (s * 6.05, 4.4, -0.5)], [1.65, 1.85], 'bark', seg=12)
        fist.extend(fa)
        grooves(fist, fa, s * 5.9, -0.35, 4.6, 6.9, [math.radians(a) for a in (0, 70, 140, 200, 270)], 0.17, n=4)
        blob(fist, (s * 6.1, 3.0, -0.85), (2.15, 1.75, 2.2), 'bark2', e1=0.7, e2=0.85, seg=14, rings=9)
        for dx in (-0.95, 0.0, 0.95):
            tube(fist, [(s * 6.1 + dx, 2.4, -2.3), (s * 6.1 + dx * 1.1, 1.6, -2.75), (s * 6.1 + dx * 1.2, 1.25, -2.4)],
                 [0.5, 0.42, 0.3], 'bark3', seg=7, cap1='round')
        blob(fist, (s * 7.6, 4.6, -0.6), (0.7, 0.22, 0.75), 'mush', seg=10, rings=5)
        tier = k.g(group, 'main', 'Tier')
        tube(tier, [(s * 6.6, 10.0, 0.9), (s * 7.3, 12.0, 0.9), (s * 7.9, 13.3, 0.6)], [0.6, 0.45, 0.3], 'bark2', seg=7)
        blob(tier, (s * 6.9, 12.35, 0.8), (2.65, 0.95, 2.45), 'leaf', seg=14, rings=8)
        blob(tier, (s * 7.45, 13.45, 0.8), (1.95, 0.75, 1.85), 'leaf2', seg=12, rings=7)
    # Legs: stumpy root legs with splayed root toes
    for s, group in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(group)
        lg = Geo('leg')
        tube(lg, [(s * 2.2, 0.6, 0.0), (s * 2.35, -1.8, -0.3)], [1.75, 1.9], 'bark', seg=12, cap0='round', cap1='none')
        g.extend(lg)
        grooves(g, lg, s * 2.28, -0.15, -1.7, 0.9, [math.radians(a) for a in (-30, 40, 110, 180, 250)], 0.17, n=4)
        blob(g, (s * 2.4, -3.1, -1.0), (2.05, 0.9, 2.55), 'bark2', e1=0.6, e2=0.85, seg=14, rings=8)
        for dx in (-0.9, 0.0, 0.9):
            tube(g, [(s * 2.4 + dx, -3.3, -2.6), (s * 2.4 + dx * 1.3, -3.7, -4.0), (s * 2.4 + dx * 1.5, -3.95, -4.6)],
                 [0.5, 0.38, 0.22], 'bark3', seg=7, cap1='round')
    # Which of today's parts each piece follows for the tree disguise (TreeRest / TreeSize deltas)
    k.tree_map = {('Body', None): 'Root torso', ('Head', 'Stump'): 'Stump head', ('Head', 'Canopy'): 'Oak Leaf crown',
                  ('LeftArm', 'Upper'): 'Heavy shoulder', ('LeftArm', 'Fist'): 'Heavy forearm', ('LeftArm', 'Tier'): 'Oak shoulder tier',
                  ('RightArm', 'Upper'): 'Heavy shoulder', ('RightArm', 'Fist'): 'Heavy forearm', ('RightArm', 'Tier'): 'Oak shoulder tier',
                  ('LeftLeg', None): 'Root leg', ('RightLeg', None): 'Root leg', ('Head', 'Eyes'): 'Glowing slit', ('Body', 'Glow'): 'Root torso'}
    return k


# =========================================================================================== Stage 5: Crystal Knight (Crystal)
def crystal_knight():
    k = KeeperModel('crystal_knight', 'Crystal Knight', 5, {
        'armor': (0.70, 0.72, 0.86), 'armor2': (0.88, 0.90, 0.97), 'under': (0.24, 0.19, 0.42), 'under2': (0.32, 0.26, 0.52),
        'crystal': (0.66, 0.42, 0.98), 'crystal2': (0.84, 0.66, 1.0), 'trim': (0.50, 0.32, 0.86), 'grip': (0.20, 0.15, 0.32),
        'recess': (0.10, 0.08, 0.18), 'blade': (0.86, 0.78, 1.0)},
        glow={'*': (0.74, 0.52, 1.0)}, eye_rgb=(0.80, 0.68, 0.98))
    body = k.g('Body')
    blob(body, (0, 15.1, 0.1), (6.3, 4.7, 3.9), 'armor', e1=0.55, e2=0.72, seg=20, rings=12)
    blob(body, (0, 15.4, -3.45), (5.0, 3.6, 0.75), 'armor2', e1=0.5, e2=0.7, seg=16, rings=9)
    blob(body, (0, 9.7, 0.0), (4.9, 1.5, 3.3), 'under', e1=0.6, e2=0.8, seg=16, rings=8)        # waist
    tube(body, [(-4.9, 10.6, -0.2), (0, 10.75, -3.45), (4.9, 10.6, -0.2)], [0.42, 0.42, 0.42], 'trim', seg=8)   # belt
    mirror(lambda s: blob(body, (s * 3.0, 8.1, -3.25), (2.4, 2.0, 0.55), 'armor', e1=0.45, e2=0.7, seg=12, rings=7, M=Rz(s * 0.12)))
    bglow = k.g('Body', 'glow')
    crystal(bglow, (0, 14.4, -4.15), (0, 1, -0.15), 1.05, 3.3, 'iris', sides=6)
    # Head: round helm, dark face recess, two angled glowing eyes (the EyeGlow parts), crystal crest
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    blob(head, (0, 23.4, 0.0), (3.55, 3.7, 3.3), 'armor', e1=0.62, e2=0.82, seg=20, rings=12)
    rbox(head, (0, 23.15, -2.95), (5.4, 1.15, 1.0), 'recess', round_=0.45)          # T-visor
    rbox(head, (0, 21.9, -2.95), (1.2, 2.4, 1.0), 'recess', round_=0.45)
    mirror(lambda s: blob(iris, (0, 0, 0), (0.85, 0.36, 0.22), 'iris', seg=12, rings=7, M=T(s * 1.35, 23.12, -3.38) @ Rz(s * 0.3)))
    mirror(lambda s: rbox(head, (0, 0, 0), (2.9, 0.62, 1.0), 'armor2', round_=0.4, M=T(s * 1.4, 24.15, -3.15) @ Rz(s * 0.25)))
    blob(head, (0, 21.15, -2.85), (2.3, 0.75, 0.7), 'armor2', seg=12, rings=6)                     # chin guard
    for (x, z, ax, h, r) in ((0, 0.3, (0, 1, 0.2), 3.3, 0.85), (0.95, 0.9, (0.35, 1, 0.45), 2.4, 0.6), (-0.95, 0.9, (-0.35, 1, 0.45), 2.4, 0.6),
                             (0, 1.6, (0, 1, 0.8), 2.0, 0.55)):
        crystal(head, (x, 26.5, z), ax, r, h, 'crystal' if x == 0 else 'crystal2')
    # Arms: pauldrons with crystal clusters + upper arm; forearm: elbow, gauntlet, fist with a glowing cuff
    for s, arm, fore in ((1, 'LeftArm', 'LeftForearm'), (-1, 'RightArm', 'RightForearm')):
        g = k.g(arm)
        blob(g, (s * 9.6, 19.4, 0.0), (3.4, 2.7, 3.6), 'armor', e1=0.55, e2=0.75, seg=16, rings=10)
        tube(g, [(s * 9.1, 18.0, -0.2), (s * 9.1, 11.6, -0.5)], [1.95, 1.8], 'under', seg=12)
        tube(g, [(s * 9.1, 14.6, -0.3), (s * 9.1, 13.3, -0.35)], [2.1, 2.1], 'armor2', seg=12, cap0='flat', cap1='flat')
        for (dx, dy, ax, h, r) in ((0.9, 1.9, (0.45, 1, 0.1), 2.6, 0.62), (2.3, 1.2, (0.9, 0.8, 0.0), 2.0, 0.5), (-0.4, 2.2, (0.0, 1, -0.3), 1.8, 0.5)):
            crystal(g, (s * (9.6 + dx), 19.4 + dy, 0.2), (s * ax[0], ax[1], ax[2]), r, h, 'crystal')
        f = k.g(fore)
        blob(f, (s * 9.1, 9.8, -0.6), (1.75, 1.6, 1.75), 'under2', seg=12, rings=8)
        blob(f, (s * 9.1, 6.2, -1.5), (2.45, 3.3, 2.55), 'armor2', e1=0.6, e2=0.75, seg=14, rings=9)
        blob(f, (s * 9.1, 2.85, -2.45), (2.1, 1.55, 2.1), 'armor', e1=0.6, e2=0.75, seg=12, rings=8)
        tube(f, [(s * 9.1, 4.25, -1.9), (s * 9.1, 3.75, -2.05)], [2.55, 2.55], 'trim', seg=12, cap0='flat', cap1='flat')
    for s, leg in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(leg)
        tube(g, [(s * 3.25, 7.0, 0.0), (s * 3.25, 2.2, -0.4)], [2.25, 2.05], 'under', seg=12)
        blob(g, (s * 3.25, 0.7, -0.6), (2.45, 2.7, 2.45), 'armor', e1=0.6, e2=0.8, seg=14, rings=9)
        crystal(g, (s * 3.25, 3.6, -2.2), (0, 0.4, -1), 0.9, 1.3, 'crystal')                          # knee crystal
        blob(g, (s * 3.25, -2.5, -1.4), (2.75, 1.45, 3.7), 'armor2', e1=0.5, e2=0.7, seg=14, rings=8)  # boot
    # Sword in the right hand (-X): crystal blade with a glowing core
    sw = k.g('Sword')
    tube(sw, [(-9.1, 3.9, -2.8), (-9.1, -0.1, -2.8)], [0.5, 0.5], 'grip', seg=8)
    blob(sw, (-9.1, 4.25, -2.8), (0.75, 0.6, 0.75), 'crystal2', seg=8, rings=6, smooth=False)
    rbox(sw, (-9.1, -0.55, -2.8), (5.6, 0.95, 1.7), 'armor2', round_=0.4)
    tube(sw, [(-9.1, -0.9, -2.8), (-9.1, -5.0, -2.8), (-9.1, -9.7, -2.8)], [(1.42, 0.42), (1.3, 0.38), (0.0, 0.0)], 'blade', seg=4,
         cap0='flat', cap1='none', smooth=False, up=Vector((0, 0, 1)), twist=0.0)
    swg = k.g('Sword', 'glow')
    tube(swg, [(-9.1, -1.2, -2.8), (-9.1, -8.4, -2.8)], [(0.32, 0.5), (0.0, 0.0)], 'iris', seg=4, cap0='flat', cap1='none', smooth=False)
    return k


# =========================================================================================== Stage 7: Storm Colossus (Storm)
def storm_colossus():
    k = KeeperModel('storm_colossus', 'Storm Colossus', 7, {
        'stone': (0.30, 0.34, 0.45), 'stone2': (0.22, 0.25, 0.34), 'stone3': (0.40, 0.45, 0.58), 'prong': (0.72, 0.78, 0.90),
        'recess': (0.08, 0.09, 0.14), 'brow': (0.18, 0.20, 0.28)},
        glow={'*': (0.55, 0.85, 1.0)}, eye_rgb=(0.72, 0.87, 1.0))

    def rock(c):
        return 'stone3' if c.y > 20.5 and c.z < 0 else 'stone'
    body = k.g('Body')
    blob(body, (0, 17.7, 0.2), (7.4, 6.6, 4.3), rock, e1=0.72, e2=0.85, seg=22, rings=13)
    blob(body, (0, 22.3, -1.4), (8.2, 2.3, 3.4), 'stone2', e1=0.55, e2=0.8, seg=18, rings=8)          # mantle
    for (x, z, r) in ((-5.0, 1.2, 1.4), (4.6, 1.6, 1.2), (-1.5, 2.8, 1.1)):
        blob(body, (x, 23.6, z), (r, r * 0.8, r), 'stone3', seg=8, rings=6, smooth=False)
    bglow = k.g('Body', 'glow')
    bolt = [(-0.3, 22.3), (1.4, 19.6), (0.1, 19.3), (1.2, 15.3), (-1.4, 18.6), (-0.1, 18.9), (-1.3, 22.3)]
    membrane(bglow, [(x, y, -4.25 - 0.02 * (y - 18) ** 2 * 0.0) for x, y in bolt], 0.5, 'iris')
    # Head: boulder head, heavy brow, deep recess, glowing angry eyes (EyeGlow), chin rock
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    blob(head, (0, 26.6, 0.0), (4.3, 3.55, 3.7), 'stone', e1=0.7, e2=0.85, seg=18, rings=11)
    mirror(lambda s: blob(head, (0, 0, 0), (1.35, 0.7, 0.5), 'recess', seg=12, rings=7, M=T(s * 1.55, 26.55, -3.3) @ Rz(s * 0.28)))
    mirror(lambda s: blob(iris, (0, 0, 0), (1.1, 0.42, 0.3), 'iris', seg=12, rings=7, M=T(s * 1.55, 26.5, -3.55) @ Rz(s * 0.28)))
    rbox(head, (0, 24.9, -3.2), (3.0, 0.35, 0.6), 'recess', round_=0.5, M=Rz(0.05))
    mirror(lambda s: rbox(head, (0, 0, 0), (4.2, 1.25, 1.7), 'brow', round_=0.45, M=T(s * 1.85, 27.75, -3.3) @ Rz(s * 0.22) @ Rx(0.1)))
    blob(head, (0, 24.2, -2.4), (2.6, 1.0, 1.5), 'stone2', seg=12, rings=7, smooth=False)
    # Arms: floating shoulder boulder with thunder prongs, glowing joint orb, huge fist with a glowing band
    for s, arm in ((1, 'LeftArm'), (-1, 'RightArm')):
        g = k.g(arm)
        blob(g, (s * 11.6, 20.8, 0.0), (4.0, 4.4, 4.8), 'stone', e1=0.7, e2=0.8, seg=16, rings=10)
        for (dx, dy, ax, h, r) in ((0.6, 3.5, (0.25, 1, 0.05), 4.3, 0.85), (2.4, 2.4, (0.7, 1, 0.0), 3.6, 0.75)):
            crystal(g, (s * (11.6 + dx), 20.8 + dy, 0.4), (s * ax[0], ax[1], ax[2]), r, h, 'prong')
        blob(g, (s * 12.65, 9.9, -1.4), (4.3, 4.55, 4.6), 'stone2', e1=0.66, e2=0.8, seg=16, rings=10)
        for dx in (-2.2, -0.75, 0.75, 2.2):
            blob(g, (s * 12.65 + dx, 8.2, -5.45), (0.85, 0.9, 0.7), 'stone3', seg=8, rings=6, smooth=False)
        ag = k.g(arm, 'glow')
        blob(ag, (s * 12.4, 15.4, -0.5), (1.35, 1.35, 1.35), 'iris', seg=12, rings=8)
        tube(ag, [(s * 12.65 - 3.7, 11.3, -5.85), (s * 12.65 + 3.7, 11.3, -5.85)], [0.36, 0.36], 'iris', seg=6)
    for s, leg in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(leg)
        blob(g, (s * 3.98, 3.3, 0.0), (2.75, 3.55, 3.05), 'stone', e1=0.7, e2=0.8, seg=14, rings=9)
        blob(g, (s * 3.98, -1.45, -2.2), (3.55, 1.7, 4.75), 'stone2', e1=0.6, e2=0.8, seg=14, rings=8)
        lg = k.g(leg, 'glow')
        blob(lg, (s * 3.91, 7.6, 0.0), (1.05, 1.05, 1.05), 'iris', seg=10, rings=7)
    return k


# =========================================================================================== The Darkened (Void event keeper)
def the_darkened():
    """Group-local geometry (each group is placed at its frame; parts at frame * VeiledFrame).
    The hit boxes stay today's part boxes: every new main piece fits inside the box of the part it replaces;
    the hood, cloak and claws are new COSMETIC pieces (VeiledCosmetic = true, never used for hits)."""
    k = KeeperModel('the_darkened', 'The Darkened', 0, {
        'cloth': (0.12, 0.10, 0.17), 'cloth2': (0.20, 0.16, 0.28), 'black': (0.05, 0.05, 0.08), 'mask': (0.90, 0.88, 0.94),
        'mask2': (0.70, 0.66, 0.80), 'metal': (0.62, 0.53, 0.37), 'claw': (0.82, 0.80, 0.90), 'wrap': (0.26, 0.22, 0.34)},
        glow={'*': (0.80, 0.68, 1.0)}, eye_rgb=(0.80, 0.68, 1.0), floor=-5.0, local=True)
    # Torso: broad chest (fits 5.5 x 3.5 x 2.4), shoulders, ribs; cosmetic tattered cloak behind
    t = k.g('Torso')
    blob(t, (0, 0.1, 0), (2.7, 1.72, 1.18), 'cloth', e1=0.6, e2=0.8, seg=16, rings=9)
    mirror(lambda s: blob(t, (s * 2.65, 0.95, 0), (0.8, 0.8, 0.9), 'cloth2', seg=12, rings=8))
    for rib in (1, 2, 3):
        mirror(lambda s: tube(t, [(s * 0.35, 1.25 - rib * 0.7, -1.18), (s * 1.3, 1.1 - rib * 0.7, -1.15), (s * 2.1, 1.0 - rib * 0.72, -0.95)],
                              [0.1, 0.1, 0.06], 'metal', seg=5, cap0='round', cap1='point'))
    cloak = k.g('Torso', 'main', 'Cloak')
    for i, x in enumerate((-2.9, -1.75, -0.6, 0.6, 1.75, 2.9)):
        ln = 8.2 + (1.4 if i % 2 else 0.0) - abs(x) * 0.3
        sp = 1.0 + abs(x) * 0.12
        membrane(cloak, [(x * 0.9 - 0.7, 1.7, 1.3), (x * 0.9 + 0.7, 1.7, 1.3), (x * sp + 0.6, 1.7 - ln, 2.1 + 0.08 * ln),
                         (x * sp, 1.7 - ln - 1.1, 2.15 + 0.08 * ln), (x * sp - 0.6, 1.7 - ln, 2.1 + 0.08 * ln)], 0.14,
                 'cloth2' if i % 2 else 'cloth')
    mirror(lambda s: blob(cloak, (s * 2.6, 1.7, 0.2), (1.2, 0.55, 1.25), 'cloth2', seg=12, rings=6))   # mantle over shoulders
    tg = k.g('Torso', 'glow')
    membrane(tg, [(0.03, 1.35, -1.22), (0.2, 0.62, -1.22), (-0.04, 0.3, -1.22), (0.14, -0.55, -1.22), (-0.02, -1.32, -1.22),
                  (-0.14, -0.48, -1.22), (0.08, -0.18, -1.22), (-0.16, 0.66, -1.22)], 0.08, 'iris')   # the sunken core: a thin jagged crack
    w = k.g('Waist')
    tube(w, [(0, -1.68, 0), (0, 0, 0), (0, 1.68, 0)], [(1.08, 0.74), (0.95, 0.66), (1.12, 0.78)], 'cloth', seg=12, cap0='flat', cap1='flat')
    h = k.g('Hip')
    blob(h, (0, 0, 0), (1.32, 0.95, 0.88), 'cloth', e1=0.7, seg=14, rings=8)
    mirror(lambda s: blob(h, (s * 0.95, -0.65, 0), (0.78, 0.78, 0.78), 'black', seg=10, rings=7))
    n = k.g('Neck')
    tube(n, [(0, -0.68, 0), (0, 0.68, 0)], [0.52, 0.44], 'black', seg=10, cap0='flat', cap1='flat')
    # Head: pale mask (fits 2 x 3 x 1.48) with glowing eyes and the cleft; cosmetic hood around it
    hd, iris = k.g('Head'), k.g('Head', 'eyes')
    blob(hd, (0, 0, -0.1), (0.98, 1.45, 0.62), lambda c: 'mask' if c.z < -0.25 else 'mask2', e1=0.85, e2=0.9, seg=16, rings=11)
    mirror(lambda s: blob(hd, (0, 0, 0), (0.36, 0.2, 0.1), 'black', seg=10, rings=6, M=T(s * 0.42, 0.35, -0.68) @ Rz(s * 0.35)))
    mirror(lambda s: blob(iris, (0, 0, 0), (0.24, 0.11, 0.06), 'iris', seg=10, rings=5, M=T(s * 0.42, 0.35, -0.74) @ Rz(s * 0.35)))
    hglow = k.g('Head', 'glow')
    tube(hglow, [(0.02, 0.05, -0.7), (0.02, -0.6, -0.68), (0.0, -1.1, -0.6)], [0.05, 0.04, 0.0], 'iris', seg=5, cap0='round', cap1='point')
    hood = k.g('Head', 'main', 'Hood')
    blob(hood, (0, 0.45, 0.4), (1.8, 2.2, 1.6), 'cloth', e1=0.9, e2=0.9, seg=16, rings=10,
         deform=lambda p: Vector((p.x, p.y, p.z if p.z > -0.6 else -0.6 + (p.z + 0.6) * 0.12)))
    spike(hood, (0, 2.3, 0.6), (0, 3.4, 2.0), 0.75, 'cloth', seg=8, smooth=True)
    mirror(lambda s: blob(hood, (s * 1.2, -1.5, 0.5), (0.9, 1.0, 1.0), 'cloth2', seg=10, rings=7))
    # Arms, hands with long claws; legs with wraps; pointed feet
    for q, s in (('L', -1), ('R', 1)):
        ua = k.g(q + 'UpperArm')
        tube(ua, [(0, 1.62, 0), (0, -1.68, 0)], [(0.6, 0.64), (0.5, 0.55)], 'cloth', seg=10)
        fa = k.g(q + 'Forearm')
        blob(fa, (0, 2.1, 0), (0.6, 0.6, 0.6), 'black', seg=10, rings=7)
        tube(fa, [(0, 1.9, 0), (0, -1.62, 0)], [(0.5, 0.55), (0.42, 0.48)], 'wrap', seg=10)
        tube(fa, [(0, -1.62, 0), (0, -1.78, 0)], [0.56, 0.56], 'metal', seg=10, cap0='flat', cap1='flat')
        hn = k.g(q + 'Hand')
        blob(hn, (0, 0, 0), (0.62, 0.52, 0.4), 'black', seg=10, rings=7)
        blob(hn, (0, 0.55, 0), (0.46, 0.3, 0.44), 'black', seg=8, rings=6)
        claws = k.g(q + 'Hand', 'main', 'Claws')
        for i in (1, 2, 3):
            x = (i - 2) * 0.4
            horn(claws, (x, -0.4, 0), (x * 1.1, -1.4, -0.15), (x * 1.15, -2.2, -0.55), 0.13, 'claw', seg=5, n=4)
        th = k.g(q + 'Thigh')
        tube(th, [(0, 1.3, 0), (0, -1.42, 0)], [(0.68, 0.74), (0.55, 0.6)], 'cloth', seg=10)
        sh = k.g(q + 'Shin')
        blob(sh, (0, 1.8, 0), (0.62, 0.62, 0.62), 'black', seg=10, rings=7)
        tube(sh, [(0, 1.6, 0), (0, -1.32, 0)], [(0.52, 0.58), (0.42, 0.48)], 'wrap', seg=10)
        ft = k.g(q + 'Foot')
        blob(ft, (0, 0, 0.15), (0.68, 0.34, 1.1), 'black', e1=0.7, seg=10, rings=6,
             deform=lambda p: Vector((p.x * (0.55 + 0.45 * min(1, (p.z + 1.1) / 1.2)), p.y, p.z)))
    k.cosmetic = {('Torso', 'Cloak'), ('Head', 'Hood'), ('LHand', 'Claws'), ('RHand', 'Claws')}
    return k


BUILDERS = {1: timber_golem, 6: jungle_king, 2: sand_snake, 3: ice_fang, 4: lava_dragon, 5: crystal_knight, 7: storm_colossus,
            0: the_darkened}
ORDER = [1, 6, 2, 3, 4, 5, 7, 0]  # biome order: Forest, Jungle, Desert, Snow, Lava, Crystal, Storm, then The Darkened
BIOME = {1: 'Forest', 6: 'Jungle', 2: 'Desert', 3: 'Snow', 4: 'Lava', 5: 'Crystal', 7: 'Storm', 0: 'Void event'}


