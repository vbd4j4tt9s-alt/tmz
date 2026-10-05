"""PROPOSED keepers, revision 2: following the owner's Steal an Egg screenshots.

Style taken from the references: chunky, angular, faceted low-poly bodies (flat shading), shard-like fur and spike
tufts, bold graphic markings, strong body / accent colour contrast, glowing eyes, the Roblox stud texture, big effects,
a big stylised "Z" while asleep. Every keeper has a personality, an expressive face and five swappable face states
(Idle, Chase, Attack, Asleep, Gloat). Every piece touches the body (checked by connectivity.py), except the Storm
Colossus's floating fists and shoulder rocks, which the owner allowed as part of its design.

Mesh parts per keeper:
  <Group>                main mesh of a rig group (same groups and pivots the game animates today)
  <Group>_<Piece>        extra main pieces (golem pieces for its tree disguise, the Darkened's cosmetic cloak, ...)
  <Group>_Eyes           the glowing irises (KeeperEyeGlow parts)
  <Group>_Glow           Neon accents (lava seams, sap cracks, crystal cores, lightning)
  Head_Face_<State>      one per face state; the client shows exactly one (LocalTransparencyModifier)
  Head_Eyes_<State>      the Crystal Knight's per-state glowing visor eyes (eyes-only expressions)
Effects (fx kind: flames, lightning arcs, the sleep Z) are preview stand-ins for particles / beams, not meshes to upload.
"""
import math
from mathutils import Vector, Matrix
import kit
from kit import Geo, Palette, blob, tube, rbox, horn, spike, crystal, membrane, bezier, shards, T, Rx, Ry, Rz, V
from faces import Face, STATES

WHITE = (0.98, 0.98, 0.97)
PUPIL = (0.05, 0.05, 0.08)
COMMON = {'white': WHITE, 'pupil': PUPIL, 'lash': (0.08, 0.06, 0.08), 'mouthin': (0.55, 0.06, 0.10), 'tongue': (0.95, 0.42, 0.50),
          'tooth': (1.0, 0.98, 0.92), 'drool': (0.62, 0.86, 1.0), 'zcol': (0.30, 0.85, 1.0), 'zedge': (0.05, 0.22, 0.55)}


class KeeperModel:
    def __init__(self, key, name, stage, palette, glow=None, eye_rgb=(1, 1, 1), floor=-4.0, local=False):
        self.key, self.name, self.stage = key, name, stage
        pal = dict(COMMON)
        pal['iris'] = eye_rgb
        pal.update(palette)
        self.pal = Palette(pal)
        self.glow_rgb = glow or {}
        self.eye_rgb = eye_rgb
        self.geos = {}
        self.order = []
        self.floor = floor
        self.local = local
        self.tree_map = {}
        self.cosmetic = set()
        self.floating = set()        # (group, piece) floating by design (Storm Colossus only)
        self.personality = ''
        self.state_eyes = False      # Crystal Knight: per-state glowing eyes instead of face pieces
        self.state_rgb = {}          # per-state eye colour / brightness (knight)
        self.fidget = ''
        self.fx_notes = ''

    def g(self, group, kind='main', piece=None):
        key = (group, kind, piece)
        if key not in self.geos:
            names = {'main': None, 'eyes': 'Eyes', 'glow': 'Glow', 'face': 'Face', 'fx': 'Fx'}
            name = group if names[kind] is None else '%s_%s' % (group, names[kind])
            if piece:
                name = '%s_%s' % (name, piece)
            self.geos[key] = Geo(name)
            self.order.append(key)
        return self.geos[key]

    def parts(self, fx=False):
        for key in self.order:
            group, kind, piece = key
            geo = self.geos[key]
            if geo.v and (fx or kind != 'fx'):
                yield group, kind, piece, geo

    def tris(self):
        return sum(g.tris() for _, _, _, g in self.parts())

    def tris_visible(self):
        """Triangles on screen at once: everything except the 4 hidden face / eye states."""
        total = 0
        seen_state = False
        for group, kind, piece, g in self.parts():
            if (kind == 'face' or (kind == 'eyes' and piece in STATES)):
                if piece != 'Idle':
                    continue
            total += g.tris()
        return total

    def transform(self, groups, M):
        """Re-pose rest geometry of whole groups (posture: a head held high, a tilted head)."""
        for (group, kind, piece), geo in self.geos.items():
            if group in groups:
                geo.v = [(M @ Vector((p.x, p.y, p.z, 1))).xyz for p in geo.v]


def mirror(fn):
    for s in (-1, 1):
        fn(s)


def joint(g, p, r, col):
    """A ball centred on a group's pivot: it stays put under any rotation about the pivot, so the parent can overlap it."""
    blob(g, p, (r, r, r), col, seg=10, rings=7)


def sleep_z(k, at, h=2.2, M=None):
    """The reference's big sleep marker (preview stand-in for a BillboardGui image)."""
    g = k.g('Head', 'fx', 'Z')
    at = Vector((-at[0], at[1], at[2]))      # beside the head on the keeper's left (screen right from the front)
    kit.z_letter(g, at, h, 'zcol', 'zedge', M=M)
    kit.z_letter(g, at + Vector((-h * 0.7, h * 0.75, 0)), h * 0.65, 'zcol', 'zedge', M=M)   # the small z up and to the right


def flame(g, base, direction, length, width, seed=0):
    """Fire stand-in (a ParticleEmitter in game): a few glowing tongues."""
    import random
    rnd = random.Random(seed)
    d = Vector(direction).normalized()
    for i in range(3):
        off = Vector((rnd.uniform(-1, 1), 0, rnd.uniform(-1, 1))) * width * 0.4
        tip = Vector(base) + off + d * length * rnd.uniform(0.7, 1.1) + Vector((rnd.uniform(-0.3, 0.3), 0, rnd.uniform(-0.3, 0.3))) * width
        tube(g, [Vector(base) + off, (Vector(base) + off + tip) / 2 + off * 0.3, tip], [width * 0.5, width * 0.32, 0.0], 'flame',
             seg=6, cap0='round', cap1='point', smooth=True)


def bolt(g, a, b, r, seed=0, kinks=5):
    """Lightning stand-in (a Beam in game) from a to b."""
    import random
    rnd = random.Random(seed)
    a, b = Vector(a), Vector(b)
    pts = [a]
    for i in range(1, kinks):
        f = i / kinks
        p = a + (b - a) * f
        p += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * (b - a).length * 0.08
        pts.append(p)
    pts.append(b)
    tube(g, pts, [r] * len(pts), 'bolt', seg=5, cap0='round', cap1='round', smooth=True)


# =========================================================================================== Stage 1: Timber Golem (Forest)
def timber_golem():
    k = KeeperModel('timber_golem', 'Timber Golem', 1, {
        'bark': (0.47, 0.31, 0.19), 'bark2': (0.33, 0.21, 0.12), 'bark3': (0.62, 0.43, 0.26), 'moss': (0.40, 0.70, 0.25),
        'moss2': (0.28, 0.55, 0.18), 'leaf': (0.30, 0.66, 0.22), 'leaf2': (0.50, 0.80, 0.26), 'leaf3': (0.20, 0.48, 0.16),
        'face': (0.78, 0.60, 0.40), 'brow': (0.36, 0.66, 0.20), 'mush': (0.90, 0.20, 0.16), 'spot': (1.0, 0.96, 0.88),
        'stem': (0.96, 0.90, 0.78), 'nest': (0.55, 0.38, 0.20), 'egg': (0.55, 0.85, 0.95), 'bird': (0.30, 0.60, 0.95),
        'beak': (1.0, 0.65, 0.10), 'tooth': (0.93, 0.84, 0.62), 'lip': (0.30, 0.18, 0.10), 'eyedark': (0.12, 0.09, 0.06)},
        glow={'*': (1.0, 0.72, 0.18)}, eye_rgb=(0.55, 1.0, 0.45))
    k.personality = 'Grumpy old forest grump: hates being woken, glares from under mossy brows, a bird lives in his hair.'
    k.fidget = 'Scratches his bark with the small arm; the bird in his crown hops and chirps; leaves drift down.'
    k.fx_notes = 'Falling leaves and drifting spores (ParticleEmitter); glowing sap drips from the cracks; dust burst on the hammer slam.'
    # Body: faceted barrel trunk, bark plates, glowing sap cracks, moss mantle, red mushrooms ---------------------------
    body = k.g('Body')
    trunk = Geo('trunk')
    blob(trunk, (0, 6.0, 0), (4.05, 4.25, 2.9), 'bark', e1=0.7, e2=0.85, seg=16, rings=10)
    body.extend(trunk)
    tb = trunk.bvh()
    for i, a in enumerate((-150, -110, -60, -25, 25, 60, 110, 150, 200, 245, 295, 335)):
        th = math.radians(a)
        rays = [((0, y, 0), (math.cos(th), 0.03 * math.sin(i + y), math.sin(th))) for y in (2.6, 4.2, 5.8, 7.4, 8.8)]
        kit.stroke(body, tb, rays, 'bark2', 0.26, thick=0.14, seg=4)
    blob(body, (0, 9.95, 0.1), (4.35, 1.0, 3.05), 'moss', e1=0.7, seg=14, rings=6)
    for i, (x, z) in enumerate(((-3.3, -1.8), (-1.4, -2.5), (1.6, -2.4), (3.4, -1.4), (3.6, 1.4), (-3.5, 1.6))):
        shards(body, (x, 9.7, z), (x * 0.25, -1.0, z * 0.3), 1.3, 0.75, 'moss2', n=3, spread=0.35, seed=i)
    sap = k.g('Body', 'glow')
    for pts in (((0.1, 8.2, -2.92), (0.6, 7.0, -2.95), (-0.2, 5.9, -2.95), (0.4, 4.6, -2.88)),
                ((-2.2, 7.6, -2.55), (-2.0, 6.5, -2.7), (-2.6, 5.4, -2.5)),
                ((2.4, 4.0, -2.45), (2.0, 3.0, -2.55))):
        rays = [((p[0] * 0.3, p[1], 0), (p[0], 0, p[2])) for p in pts]
        kit.stroke(sap, tb, rays, 'iris', 0.22, thick=0.16, seg=4, taper=True)
    for (x, y, z, r) in ((3.55, 8.4, -1.3, 1.05), (3.85, 7.6, 0.4, 0.75), (-3.7, 5.4, 0.8, 0.9)):
        s = 1 if x > 0 else -1
        blob(body, (x, y, z), (r, 0.4, r), 'mush', seg=10, rings=5)
        blob(body, (x + s * 0.25, y + 0.32, z), (r * 0.18, r * 0.08, r * 0.18), 'spot', seg=6, rings=4)
        blob(body, (x - s * 0.1, y + 0.3, z + r * 0.45), (r * 0.14, r * 0.07, r * 0.14), 'spot', seg=6, rings=4)
    # Head: stump head with a bold face; canopy with a bird's nest and mushrooms -------------------------------------
    head = k.g('Head', 'main', 'Stump')
    stump = Geo('stump')
    blob(stump, (0, 12.4, -0.3), (2.85, 2.75, 2.65), 'bark', e1=0.6, e2=0.85, seg=14, rings=9)
    head.extend(stump)
    blob(head, (0, 12.2, -2.35), (2.35, 1.95, 0.8), 'face', e1=0.6, e2=0.8, seg=12, rings=7)   # pale carved face plate
    face_geo = Geo('faceplate')
    blob(face_geo, (0, 12.2, -2.35), (2.35, 1.95, 0.8), 'face', e1=0.6, e2=0.8, seg=12, rings=7)
    face_geo.extend(stump)
    blob(head, (0, 12.15, -3.05), (0.45, 0.85, 0.5), 'bark3', seg=8, rings=5, M=Rx(0.2))   # knobbly nose
    # old man's moss beard hanging from the chin (static)
    for i, x in enumerate((-1.3, -0.45, 0.45, 1.3)):
        shards(head, (x, 10.25, -2.3), (x * 0.15, -1, -0.25), 1.8 - abs(x) * 0.35, 0.8, 'moss', n=2, spread=0.25, seed=10 + i, sink=0.3)
    canopy = k.g('Head', 'main', 'Canopy')
    for (x, y, z, rx, ry, rz, c) in ((0, 17.0, 0.7, 6.0, 3.3, 5.4, 'leaf'), (-4.4, 15.6, 0.8, 3.0, 2.4, 3.3, 'leaf3'),
                                     (4.6, 15.8, 0.6, 3.0, 2.3, 3.3, 'leaf3'), (1.2, 19.4, 0.6, 3.8, 1.9, 3.3, 'leaf2'),
                                     (-1.9, 18.7, 2.2, 3.0, 1.8, 2.8, 'leaf2'), (0, 15.3, -3.1, 4.2, 1.5, 1.9, 'leaf3'),
                                     (0.6, 16.2, 4.4, 4.0, 2.0, 2.4, 'leaf3')):
        blob(canopy, (x, y, z), (rx, ry, rz), c, seg=10, rings=6)
    for i, (x, z) in enumerate(((-5.2, -1.0), (5.3, -0.5), (-3.5, 3.6), (3.8, 3.4), (0, -4.3), (-2.4, -3.6), (2.6, -3.7))):
        shards(canopy, (x, 15.2, z), (x * 0.18, -0.8, z * 0.18), 1.6, 1.0, 'leaf3', n=2, spread=0.4, seed=20 + i)
    mirror(lambda s: tube(canopy, [(s * 1.9, 14.3, 0.6), (s * 3.2, 16.4, 0.7), (s * 4.5, 17.8, 0.3)], [0.55, 0.4, 0.22], 'bark2', seg=6))
    # bird's nest on top with two eggs and a little blue bird
    tube(canopy, [Vector((math.cos(a) * 1.55, 21.05 + 0.12 * math.sin(3 * a), 0.4 + math.sin(a) * 1.55)) for a in [i * math.pi / 7 for i in range(15)]],
         [0.42] * 15, 'nest', seg=6, cap0='none', cap1='none')
    blob(canopy, (0, 20.85, 0.4), (1.45, 0.45, 1.45), 'nest', seg=10, rings=5)
    blob(canopy, (-0.45, 21.35, 0.7), (0.32, 0.42, 0.32), 'egg', seg=8, rings=6)
    blob(canopy, (0.15, 21.35, 0.95), (0.3, 0.4, 0.3), 'egg', seg=8, rings=6)
    blob(canopy, (0.5, 21.7, 0.0), (0.55, 0.5, 0.6), 'bird', seg=10, rings=6)
    blob(canopy, (0.5, 22.25, -0.2), (0.38, 0.36, 0.38), 'bird', seg=8, rings=6)
    spike(canopy, (0.5, 22.25, -0.5), (0.5, 22.2, -0.95), 0.12, 'beak', seg=4)
    blob(canopy, (0.62, 22.35, -0.47), (0.07, 0.07, 0.05), 'pupil', seg=6, rings=4)
    blob(canopy, (0.38, 22.35, -0.47), (0.07, 0.07, 0.05), 'pupil', seg=6, rings=4)
    tube(canopy, [(0.5, 21.75, 0.5), (0.55, 21.95, 1.0)], [0.25, 0.05], 'bird', seg=4, cap1='point')
    for (x, y, z, r) in ((-3.6, 18.6, -1.6, 0.9), (3.1, 18.9, 2.2, 0.75)):
        tube(canopy, [(x, y - 0.8, z), (x, y, z)], [0.22, 0.2], 'stem', seg=6)
        blob(canopy, (x, y + 0.15, z), (r, 0.45, r), 'mush', seg=10, rings=5)
        blob(canopy, (x + r * 0.3, y + 0.5, z), (r * 0.2, r * 0.1, r * 0.2), 'spot', seg=6, rings=4)
    # Face: amber-green glowing eyes on dark sockets, mossy brows, a grumpy wooden mouth --------------------------------
    eyes = [dict(E=(s * 1.12, 12.75, -2.72), r=0.72, s=s, yaw=0.18, pitch=0.05) for s in (-1, 1)]
    face = Face(k, 'Head', face_geo, eyes, lid_col='bark', brow_col='brow',
                mouth=dict(c=(0, 10.95, -1.0), n=(0, -0.08, -1), up=(0, 1, 0)), sclera='white', iris_r=0.72)
    face.build_eyes()
    # Idle: grumpy, heavy half lids, one brow lower, down-turned mouth
    face.lids('Idle', [dict(up=(0.32, 0.25, 0.0)), dict(up=(0.42, 0.1, 0.0))])
    face.brows('Idle', [dict(dy=0.0, ang=0.28, len=2.6, thick=0.5, width=0.55), dict(dy=0.15, ang=0.12, len=2.6, thick=0.5, width=0.55)])
    face.mouth_line('Idle', [(-1.15, -0.25), (-0.55, 0.05), (0.2, 0.1), (0.9, -0.05), (1.25, -0.35)], 0.22, 0.16, col='lip')
    face.cheek('Idle', -1.3, 0.45, 0.45, 'face')
    # Chase: angry, brows slammed down, teeth bared
    face.lids('Chase', [dict(up=(0.42, 0.55, 0.0)), dict(up=(0.42, 0.55, 0.0))])
    face.brows('Chase', [dict(dy=-0.05, ang=0.55, len=2.6, thick=0.55, width=0.55)] * 2)
    face.mouth_open('Chase', 2.4, 0.95, dv=0.0, shape='Dinv', teeth_up=5, teeth_low=4, tooth=0.3, tongue=False, depth=0.45, lip=(0.12, 0.1, 'lip'))
    # Attack: roar, eyes wide, brows up-angry
    face.lids('Attack', [dict(up=(0.85, 0.3, 0.0)), dict(up=(0.85, 0.3, 0.0))])
    face.brows('Attack', [dict(dy=0.15, ang=0.45, len=2.6, thick=0.55, width=0.55)] * 2)
    face.mouth_open('Attack', 2.3, 1.55, dv=-0.15, shape='oval', teeth_up=5, teeth_low=4, tooth=0.3, depth=0.55, lip=(0.12, 0.1, 'lip'))
    # Asleep: closed eyes, snoring "o" with a drool drop
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.2, ang=-0.1, len=2.5, thick=0.5, width=0.55)] * 2)
    face.mouth_open('Asleep', 0.75, 0.6, dv=0.0, du=0.25, shape='oval', tongue=False, depth=0.35)
    face.drool('Asleep', 0.45, -0.25, 0.8)
    # Gloat: smug ^ ^ eyes, lopsided toothy grin
    face.lids('Gloat', [dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5)), dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5))])
    face.brows('Gloat', [dict(dy=0.35, ang=-0.25, len=2.5, thick=0.5, width=0.55), dict(dy=0.1, ang=0.1, len=2.5, thick=0.5, width=0.55)])
    face.mouth_open('Gloat', 2.3, 0.85, dv=0.0, shape='D', teeth_up=5, tooth=0.3, tongue=False, depth=0.45, tilt=0.12, lip=(0.12, 0.1, 'lip'))
    # Arms (LeftArm is +X): the left is a huge club log with a sprouting branch, the right is smaller -------------------
    for s, group, big in ((1, 'LeftArm', True), (-1, 'RightArm', False)):
        f = 1.0 if big else 0.82
        piv = Vector((s * 4.81, 8.95, 0))
        up = k.g(group, 'main', 'Upper')
        joint(up, piv, 1.6, 'bark2')
        blob(up, (s * 5.6, 8.5, 0.0), (1.95 * f, 2.05, 2.35 * f), 'bark', e1=0.75, seg=10, rings=6)
        blob(up, (s * 5.6, 10.3, 0.15), (2.1 * f, 0.8, 2.5 * f), 'moss', seg=10, rings=5)
        shards(up, (s * 6.4, 10.4, 0.2), (s * 0.6, 1, 0.1), 1.2, 0.7, 'moss2', n=3, seed=40 + s)
        fist = k.g(group, 'main', 'Fist')
        tube(fist, [(s * 5.75, 7.4, -0.2), (s * 6.05, 4.5, -0.5)], [1.55 * f, 1.85 * f], 'bark', seg=10)
        fs = 1.3 if big else 0.95
        blob(fist, (s * 6.15, 3.0, -0.85), (2.2 * fs, 1.85 * fs, 2.25 * fs), 'bark2', e1=0.7, e2=0.85, seg=10, rings=6)
        for dx in (-0.95, 0.0, 0.95):
            tube(fist, [(s * 6.15 + dx * fs, 2.4 - 0.4 * (fs - 1), -2.0 * fs), (s * 6.15 + dx * fs * 1.1, 1.5 - 0.5 * (fs - 1), -2.65 * fs),
                        (s * 6.15 + dx * fs * 1.2, 1.15 - 0.5 * (fs - 1), -2.35 * fs)], [0.5 * fs, 0.42 * fs, 0.3 * fs], 'bark3', seg=6, cap1='round')
        if big:   # a living branch sprouting from the club arm, with leaves
            tube(fist, [(s * 7.3, 4.6, -0.4), (s * 8.6, 6.2, -0.6), (s * 9.4, 7.6, -0.2)], [0.45, 0.32, 0.18], 'bark2', seg=6)
            blob(fist, (s * 9.5, 7.9, -0.2), (0.9, 0.55, 0.7), 'leaf2', seg=8, rings=5)
            blob(fist, (s * 8.7, 6.5, -1.0), (0.7, 0.4, 0.5), 'leaf', seg=8, rings=5)
        else:
            blob(fist, (s * 7.2, 4.8, -0.4), (0.7, 0.24, 0.75), 'mush', seg=8, rings=4)
        tier = k.g(group, 'main', 'Tier')
        tube(tier, [(s * 6.4, 9.6, 0.9), (s * 7.3, 12.0, 0.9), (s * 7.9, 13.3, 0.6)], [0.6, 0.45, 0.3], 'bark2', seg=6)
        blob(tier, (s * 6.9, 12.35, 0.8), (2.65 * f, 0.95, 2.45 * f), 'leaf', seg=10, rings=5)
        blob(tier, (s * 7.45, 13.45, 0.8), (1.95 * f, 0.75, 1.85 * f), 'leaf2', seg=9, rings=5)
    for s, group in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(group)
        joint(g, (s * 2.035, 1.735, 0), 1.35, 'bark2')
        tube(g, [(s * 2.2, 1.0, 0.0), (s * 2.35, -2.6, -0.5)], [1.75, 1.9], 'bark', seg=10, cap0='round', cap1='round')
        blob(g, (s * 2.4, -3.1, -1.0), (2.05, 0.9, 2.55), 'bark2', e1=0.6, e2=0.85, seg=10, rings=5)
        for dx in (-0.9, 0.0, 0.9):
            tube(g, [(s * 2.4 + dx, -3.3, -2.6), (s * 2.4 + dx * 1.3, -3.7, -4.0), (s * 2.4 + dx * 1.5, -3.95, -4.6)],
                 [0.5, 0.38, 0.22], 'bark3', seg=6, cap1='round')
    sleep_z(k, (3.2, 23.5, -1.0), 2.6)
    k.tree_map = {('Body', None): 'Root torso', ('Head', 'Stump'): 'Stump head', ('Head', 'Canopy'): 'Oak Leaf crown',
                  ('LeftArm', 'Upper'): 'Heavy shoulder', ('LeftArm', 'Fist'): 'Heavy forearm', ('LeftArm', 'Tier'): 'Oak shoulder tier',
                  ('RightArm', 'Upper'): 'Heavy shoulder', ('RightArm', 'Fist'): 'Heavy forearm', ('RightArm', 'Tier'): 'Oak shoulder tier',
                  ('LeftLeg', None): 'Root leg', ('RightLeg', None): 'Root leg', ('Head', 'Eyes'): 'Glowing slit', ('Body', 'Glow'): 'Root torso',
                  ('Head', 'Face'): 'Stump head', ('Head', None): 'Stump head'}
    return k


# =========================================================================================== Stage 6: Jungle King (Jungle)
def jungle_king():
    k = KeeperModel('jungle_king', 'Jungle King', 6, {
        'fur': (0.13, 0.15, 0.25), 'fur2': (0.20, 0.23, 0.36), 'mask': (0.99, 0.88, 0.80), 'mask2': (0.93, 0.78, 0.70),
        'gold': (1.0, 0.78, 0.12), 'gold2': (0.85, 0.58, 0.05), 'gem': (0.95, 0.12, 0.18), 'brow': (0.10, 0.11, 0.18),
        'nostril': (0.35, 0.20, 0.22), 'knuckle': (0.88, 0.74, 0.66), 'lip': (0.45, 0.22, 0.25), 'eyedark': (0.10, 0.06, 0.08),
        'goldtooth': (1.0, 0.80, 0.15)},
        glow={'*': (1.0, 0.2, 0.15)}, eye_rgb=(1.0, 0.16, 0.12))
    k.personality = 'Cocky show-off king: smirks with a gold tooth, chest puffed out, crown tilted, loves an audience.'
    k.fidget = 'Beats his chest twice and adjusts his crown; flexes the gold-banded arm.'
    k.fx_notes = 'Chest-beat shockwave ring and dust (ParticleEmitter); falling leaves; red eye glow.'
    body = k.g('Body')
    chest = Geo('chest')
    blob(chest, (0, 4.55, 0.6), (4.45, 3.25, 3.1), 'fur', e1=0.85, e2=0.9, seg=16, rings=9)
    body.extend(chest)
    blob(body, (0, 1.7, 1.2), (3.1, 2.1, 2.5), 'fur', seg=12, rings=7)
    # cream chest with a zig-zag shard edge (the reference's cream chest)
    blob(body, (0, 4.3, -1.95), (3.0, 2.55, 1.1), 'mask', e1=0.75, e2=0.85, seg=12, rings=7)
    mirror(lambda s: blob(body, (s * 1.35, 5.05, -2.45), (1.55, 1.15, 0.7), 'mask', seg=10, rings=6))   # puffed pecs
    for i in range(5):
        x = -1.8 + i * 0.9
        shards(body, (x, 2.35 - 0.3 * (i % 2), -2.2), (x * 0.1, -1, -0.25), 0.9, 0.7, 'mask', n=1, seed=60 + i, sink=0.6)
    # huge spiky shoulder tufts and back fur
    for s in (-1, 1):
        for i, (dy, dz) in enumerate(((0.0, 0.0), (0.8, 1.2), (-0.6, 1.5), (1.4, -0.4))):
            shards(body, (s * 3.6, 6.8 + dy, 0.6 + dz), (s * 0.9, 0.8, 0.15), 2.4, 1.3, 'fur2', n=3, spread=0.45, seed=70 + i + (s + 1) * 5)
    for i in range(5):
        shards(body, (0, 6.6 + 0.2 * (i % 2), 0.8 + i * 0.6), (0, 0.8, 0.6), 1.8, 1.1, 'fur', n=2, seed=90 + i)
    # Head (posture: chin up, crown tilted) -------------------------------------------------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    skull = Geo('skull')
    blob(skull, (0, 9.15, -2.1), (2.95, 2.4, 2.7), 'fur', e1=0.85, e2=0.88, seg=14, rings=8)
    head.extend(skull)
    blob(head, (0, 10.9, -1.3), (1.4, 1.0, 2.0), 'fur', seg=8, rings=5)
    mask = Geo('mask')
    blob(mask, (0, 8.75, -3.95), (2.45, 2.0, 1.2), 'mask', e1=0.8, e2=0.85, seg=12, rings=8)
    blob(mask, (0, 7.95, -4.75), (1.75, 1.05, 1.0), 'mask', e1=0.8, seg=10, rings=6)
    head.extend(mask)
    mask.extend(skull)
    mirror(lambda s: blob(head, (s * 0.38, 8.4, -5.5), (0.26, 0.18, 0.2), 'nostril', seg=6, rings=4))
    mirror(lambda s: shards(head, (s * 2.7, 9.2, -2.4), (s * 1, 0.15, 0.3), 1.2, 0.75, 'fur2', n=2, seed=100 + s))   # side tufts
    # gold crown: band + spikes + a red gem, worn slightly tilted
    crown = [Vector((math.cos(a) * 1.95, 11.35 + 0.25 * math.cos(a), -1.5 + math.sin(a) * 1.95)) for a in [i * math.pi / 8 for i in range(17)]]
    tube(head, crown, [0.38] * 17, 'gold', seg=6, cap0='none', cap1='none')
    for i in range(8):
        a = i * math.pi / 4
        b = Vector((math.cos(a) * 1.95, 11.35 + 0.25 * math.cos(a), -1.5 + math.sin(a) * 1.95))
        spike(head, b - Vector((0, 0.2, 0)), b + Vector((math.cos(a) * 0.25, 1.35 + 0.3 * (i % 2), math.sin(a) * 0.25)), 0.38, 'gold', seg=4)
    crystal(head, (0, 11.5, -3.35), (0, 0.15, -1), 0.42, 0.5, 'gem')
    eyes = [dict(E=(s * 1.02, 9.3, -4.9), r=0.6, s=s, yaw=0.25, pitch=0.05) for s in (-1, 1)]
    face = Face(k, 'Head', mask, eyes, lid_col='mask2', brow_col='brow', sclera='eyedark', iris_r=0.8,
                mouth=dict(c=(0, 7.55, -3.6), n=(0, -0.05, -1), up=(0, 1, 0)))
    face.build_eyes(pupil=False)
    # Idle: cocky, one brow up, half-lidded, smirk with a gold tooth
    face.lids('Idle', [dict(up=(0.35, 0.15, 0.0)), dict(up=(0.55, -0.1, 0.0))])
    face.brows('Idle', [dict(dy=-0.05, ang=0.35, len=2.4, thick=0.55, width=0.6), dict(dy=0.45, ang=-0.2, len=2.4, thick=0.55, width=0.6)])
    face.mouth_line('Idle', [(-1.0, 0.05), (-0.4, -0.05), (0.3, 0.05), (0.9, 0.35), (1.15, 0.45)], 0.18, 0.14, col='lip')
    face.cheek('Idle', 0.95, 0.35, 0.42, 'mask2')
    p, nn, right, up = face.on_face(0.45, 0.05)
    blob(face.g('Idle'), p + nn * 0.02, (0.17, 0.24, 0.12), 'goldtooth', M=Matrix((right, up, nn)).transposed().to_4x4(), seg=6, rings=4)
    # Chase: snarl, fangs
    face.lids('Chase', [dict(up=(0.45, 0.6, 0.0))] * 2)
    face.brows('Chase', [dict(dy=-0.1, ang=0.6, len=2.5, thick=0.6, width=0.6)] * 2)
    face.mouth_open('Chase', 2.3, 1.0, dv=-0.1, shape='Dinv', teeth_up=4, teeth_low=4, tooth=0.26, fang=0.55, tongue=False, depth=0.45)
    # Attack: huge roar (the reference's roaring mouth: fangs, red inside)
    face.lids('Attack', [dict(up=(0.75, 0.45, 0.0))] * 2)
    face.brows('Attack', [dict(dy=0.0, ang=0.55, len=2.5, thick=0.6, width=0.6)] * 2)
    face.mouth_open('Attack', 2.5, 1.8, dv=-0.3, shape='oval', teeth_up=4, teeth_low=4, tooth=0.26, fang=0.75, lower_fang=0.5, depth=0.55)
    # Asleep: closed eyes, mouth hanging open snoring, drool
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.15, ang=-0.05, len=2.4, thick=0.5, width=0.55)] * 2)
    face.mouth_open('Asleep', 1.5, 1.1, dv=-0.25, shape='oval', teeth_up=2, tooth=0.24, fang=0.4, depth=0.45)
    face.drool('Asleep', -0.55, -0.85, 1.0)
    # Gloat: laughing, eyes squeezed ^ ^
    face.lids('Gloat', [dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5))] * 2)
    face.brows('Gloat', [dict(dy=0.35, ang=-0.15, len=2.4, thick=0.55, width=0.6)] * 2)
    face.mouth_open('Gloat', 2.4, 1.35, dv=-0.2, shape='D', teeth_up=5, tooth=0.26, fang=0.4, depth=0.5)
    # Jaw: cream chin with the lower canines
    jaw = k.g('Jaw')
    joint(jaw, (0, 7.15, -3.4), 0.55, 'mask2')
    blob(jaw, (0, 7.05, -4.35), (1.45, 0.55, 0.9), 'mask', seg=10, rings=6)
    mirror(lambda s: spike(jaw, (s * 0.75, 7.25, -4.95), (s * 0.72, 7.85, -5.05), 0.17, 'tooth', seg=5))
    # posture: chin up a little, the whole head (and jaw) about the neck
    piv = Vector((0, 6.3, -1.0))
    k.transform(['Head', 'Jaw'], T(piv) @ Rx(-0.08) @ Rz(0.04) @ T(-piv))
    # Arms: massive, knuckle-walking, a gold band on the left arm (as in the reference) ---------------------------------
    for s, group in ((-1, 'LeftArm'), (1, 'RightArm')):
        g = k.g(group)
        joint(g, (s * 4.15, 6.45, 0.25), 1.6, 'fur')
        blob(g, (s * 4.7, 6.15, 0.1), (2.35, 2.3, 2.5), 'fur', seg=10, rings=6)
        tube(g, bezier((s * 4.75, 5.6, -0.1), (s * 5.15, 3.4, -0.6), (s * 5.15, 1.4, -1.5), (s * 5.35, -1.9, -2.5), n=7),
             [1.95, 1.7, 1.45, 1.55, 1.9, 1.95, 1.7, 1.5], 'fur', seg=10)
        blob(g, (s * 5.35, -2.95, -2.85), (1.95, 1.15, 1.7), 'mask', e1=0.75, e2=0.85, seg=10, rings=6)   # cream fist
        for dx in (-1.05, -0.35, 0.35, 1.05):
            blob(g, (s * 5.35 + dx, -3.5, -4.25), (0.42, 0.42, 0.38), 'knuckle', seg=6, rings=4)
        for i, dy in enumerate((3.0, 1.0)):
            shards(g, (s * 6.5, dy, -0.8), (s * 1, -0.1, 0.5), 1.4, 0.9, 'fur2', n=2, seed=110 + i + s)   # forearm tufts
        if s == -1:
            tube(g, [(s * 5.2, 2.6, -1.25), (s * 5.25, 1.6, -1.55)], [2.0, 2.0], 'gold', seg=10, cap0='flat', cap1='flat')
            tube(g, [(s * 5.2, 2.75, -1.2), (s * 5.2, 2.55, -1.27)], [2.15, 2.15], 'gold2', seg=10, cap0='flat', cap1='flat')
    for s, group in ((-1, 'LeftBackLeg'), (1, 'RightBackLeg')):
        g = k.g(group)
        joint(g, (s * 1.65, 0.9, 1.9), 1.2, 'fur')
        blob(g, (s * 1.95, 0.3, 1.5), (1.45, 1.7, 1.6), 'fur', seg=10, rings=6)
        tube(g, [(s * 1.95, -0.2, 1.3), (s * 2.0, -2.9, 0.6)], [1.25, 1.1], 'fur', seg=10)
        blob(g, (s * 2.0, -3.45, -0.1), (1.25, 0.6, 1.85), 'mask', e1=0.7, e2=0.8, seg=10, rings=5)
    sleep_z(k, (2.4, 13.6, -3.0), 2.2)
    return k


# =========================================================================================== Stage 2: Sand Snake (Desert)
SNAKE_PIVOTS = [(0.0, -2.63, 0.6), (1.0, -2.75, 3.7), (3.15, -2.87, 6.7), (4.0, -3.0, 10.0), (3.3, -3.12, 13.3),
                (1.3, -3.24, 16.3), (-1.5, -3.36, 18.8), (-4.0, -3.49, 21.3), (-5.0, -3.61, 24.3), (-5.35, -3.75, 27.0)]


def sand_snake():
    k = KeeperModel('sand_snake', 'Sand Snake', 2, {
        'sand': (0.95, 0.76, 0.36), 'saddle': (0.45, 0.22, 0.10), 'rim': (1.0, 0.93, 0.66), 'belly': (1.0, 0.93, 0.72),
        'hood': (0.93, 0.66, 0.28), 'mark': (0.40, 0.16, 0.08), 'horn': (0.40, 0.24, 0.14), 'brow': (0.42, 0.20, 0.10),
        'nose': (0.35, 0.18, 0.08), 'lip': (0.55, 0.30, 0.12), 'spine': (0.80, 0.52, 0.20), 'eyedark': (0.98, 0.95, 0.80)},
        eye_rgb=(0.85, 0.95, 0.15))
    k.personality = 'Sly, smug trickster: half-lidded eyes, a lopsided smirk, always looks like it knows something you do not.'
    k.fidget = 'Flicks its forked tongue, sways its head side to side, rattles the tail tip.'
    k.fx_notes = 'Sand swirl at the tail and a dust trail while chasing (ParticleEmitter); the rattle keeps its buzz.'
    radii = [1.55, 1.42, 1.28, 1.15, 1.0, 0.86, 0.72, 0.58, 0.45, 0.30]
    for i in range(9):
        g = k.g('Segment%d' % (i + 1))
        a, b = Vector(SNAKE_PIVOTS[i]), Vector(SNAKE_PIVOTS[i + 1])
        ra, rb_ = radii[i], radii[i + 1]
        pa = Vector((a.x, -4 + ra * 0.95, a.z))
        pb = Vector((b.x, -4 + rb_ * 0.95, b.z))
        mid = (pa + pb) / 2
        tube(g, [pa, mid, pb], [(ra * 1.22, ra * 0.95), ((ra + rb_) / 2 * 1.24, (ra + rb_) / 2 * 0.97), (rb_ * 1.22, rb_ * 0.95)],
             'sand', seg=10, cap0='round', cap1='round' if i < 8 else 'point')
        d = pb - pa
        ang = math.atan2(d.x, d.z)
        rm = (ra + rb_) / 2
        top = -4 + rm * 0.95 + rm * 0.97
        ln = d.length
        blob(g, (mid.x, top - rm * 0.16, mid.z), (rm * 1.0, rm * 0.26, ln * 0.47), 'rim', e1=1.0, e2=1.8, seg=12, rings=5, M=Ry(ang))
        blob(g, (mid.x, top - rm * 0.1, mid.z), (rm * 0.74, rm * 0.27, ln * 0.37), 'saddle', e1=1.0, e2=1.8, seg=12, rings=5, M=Ry(ang))
        if i < 7:
            spike(g, (mid.x, top - rm * 0.2, mid.z), (mid.x, top + rm * 0.55, mid.z + d.normalized().z * 0.3), rm * 0.3, 'spine', seg=4)
    # Head: neck with a hidden root that reaches into the first segment (keeps it attached in the coil wind-up)
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    neck_pts = bezier((0, -2.45, 2.0), (0, -2.2, -0.3), (0, -0.4, -1.2), (0, 1.25, -3.0), n=7)
    neck = Geo('neck')
    tube(neck, neck_pts, [(1.6, 1.25), (1.58, 1.25), (1.5, 1.22), (1.45, 1.2), (1.4, 1.18), (1.36, 1.15), (1.32, 1.12), (1.3, 1.1)], 'sand', seg=10)
    head.extend(neck)
    tube(head, [(0, -2.45, 2.0), (0.15, -3.7, 1.3), (0.3, -5.6, 0.4)], [1.15, 1.0, 0.9], 'sand', seg=8, cap0='none')   # hidden root
    rays = []
    for i in range(1, 7):
        t = (neck_pts[i + 1] - neck_pts[i - 1]).normalized()
        n = t.cross(Vector((1, 0, 0)))
        if n.z > 0:
            n = -n
        rays.append((neck_pts[i], n))
    kit.stroke(head, neck.bvh(), rays, 'belly', 0.75, thick=0.12, seg=4, taper=False)
    hood = Rx(-0.32)
    blob(head, (0, 1.2, -2.15), (2.95, 2.6, 0.55), 'hood', seg=14, rings=8, M=hood)
    blob(head, (0, 0, 0), (2.55, 2.25, 0.3), 'belly', seg=12, rings=7, M=T(0, 1.12, -2.4) @ hood)
    # bold markings on the back of the hood (two big eye-spots and a chevron)
    mirror(lambda s: blob(head, (s * 1.05, 1.75, -1.8), (0.75, 0.75, 0.22), 'mark', seg=10, rings=6, M=Rx(-0.32)))
    mirror(lambda s: blob(head, (s * 1.05, 1.75, -1.66), (0.36, 0.36, 0.16), 'rim', seg=8, rings=5, M=Rx(-0.32)))
    for i, x in enumerate((-2.3, -1.6, 1.6, 2.3)):
        local = Vector((x, 2.6 * math.sqrt(max(0.0, 1 - (x / 2.95) ** 2)) - 0.45, 0.0, 1.0))
        base = Vector((0, 1.2, -2.15)) + (hood @ local).xyz
        shards(head, base, (x * 0.3, 1, 0.3), 0.9, 0.6, 'spine', n=1, seed=130 + i, sink=0.6)
    skull = Geo('skull')
    blob(skull, (0, 2.05, -5.0), (2.1, 1.35, 2.5), 'sand', e1=0.85, e2=0.9, seg=14, rings=8)
    blob(skull, (0, 1.85, -6.85), (1.45, 0.92, 0.85), 'sand', seg=10, rings=6)
    head.extend(skull)
    blob(head, (0, 1.2, -5.6), (1.72, 0.42, 2.2), 'belly', seg=10, rings=5)
    mirror(lambda s: blob(head, (s * 0.4, 2.2, -7.5), (0.1, 0.07, 0.12), 'nose', seg=6, rings=4))
    mirror(lambda s: horn(head, (s * 1.1, 3.25, -5.5), (s * 1.4, 4.2, -5.1), (s * 1.75, 4.15, -4.3), 0.38, 'horn', seg=5))
    mirror(lambda s: spike(head, (s * 0.72, 1.4, -6.75), (s * 0.78, 0.45, -6.9), 0.17, 'tooth', seg=5))
    eyes = [dict(E=(s * 1.28, 2.78, -6.0), r=0.66, s=s, yaw=0.42, pitch=0.12) for s in (-1, 1)]
    face = Face(k, 'Head', skull, eyes, lid_col='sand', brow_col='brow', sclera='eyedark', iris_r=0.76,
                mouth=dict(c=(0, 1.6, -5.6), n=(0, -0.1, -1), up=(0, 1, 0)))
    face.build_eyes(slit=True)
    # Idle: smug, heavy lids, one brow up, lopsided smirk
    face.lids('Idle', [dict(up=(0.15, 0.1, 0.0)), dict(up=(0.32, -0.15, 0.0))])
    face.brows('Idle', [dict(dy=-0.05, ang=0.2, len=2.2), dict(dy=0.4, ang=-0.35, len=2.2)])
    face.mouth_line('Idle', [(-1.3, -0.25), (-0.6, -0.3), (0.2, -0.25), (0.9, -0.05), (1.3, 0.2)], 0.15, 0.12, col='lip')
    # Chase: narrowed eyes, hiss with fangs
    face.lids('Chase', [dict(up=(0.3, 0.55, 0.0), low=(-0.55, 0.0, 0.0))] * 2)
    face.brows('Chase', [dict(dy=-0.05, ang=0.55, len=2.2)] * 2)
    face.mouth_open('Chase', 1.8, 0.55, dv=-0.3, shape='Dinv', tooth=0.22, fang=0.45, tongue=True, depth=0.35)
    # Attack: wide eyes, gaping mouth
    face.lids('Attack', [dict(up=(0.85, 0.35, 0.0))] * 2)
    face.brows('Attack', [dict(dy=0.15, ang=0.4, len=2.2)] * 2)
    face.mouth_open('Attack', 2.2, 0.9, dv=-0.4, shape='oval', tooth=0.22, fang=0.6, depth=0.4)
    # Asleep: closed eyes, lazy tongue
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.1, ang=-0.1, len=2.1)] * 2)
    face.mouth_line('Asleep', [(-1.2, -0.3), (-0.4, -0.38), (0.4, -0.38), (1.2, -0.3)], 0.12, 0.1, col='lip')
    face.drool('Asleep', 0.6, -0.45, 0.6)
    # Gloat: sly ^ ^ eyes, wide closed smile
    face.lids('Gloat', [dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5))] * 2)
    face.brows('Gloat', [dict(dy=0.3, ang=-0.25, len=2.1), dict(dy=0.15, ang=0.0, len=2.1)])
    face.mouth_line('Gloat', [(-1.4, 0.15), (-0.8, -0.3), (0.0, -0.45), (0.8, -0.3), (1.4, 0.2)], 0.17, 0.13, col='lip')
    jaw = k.g('Jaw')
    joint(jaw, (0, 1.0, -2.1), 0.6, 'belly')
    blob(jaw, (0, 0.95, -5.0), (1.72, 0.4, 2.75), 'belly', seg=10, rings=5)
    blob(jaw, (0, 1.2, -5.3), (1.38, 0.16, 2.25), 'mouthin', seg=10, rings=4)
    tube(jaw, [(0, 1.15, -6.4), (0, 1.0, -7.4), (0, 0.95, -7.8)], [0.12, 0.11, 0.1], 'tongue', seg=6, cap0='flat', cap1='none', smooth=True)
    mirror(lambda s: tube(jaw, [(0, 0.95, -7.75), (s * 0.28, 0.9, -8.1)], [0.1, 0.03], 'tongue', seg=6, cap0='round', cap1='point', smooth=True))
    # posture: sly head tilt
    piv = Vector((0, -2.8, 1.35))
    k.transform(['Head', 'Jaw'], T(piv) @ Rz(0.07) @ T(-piv))
    sleep_z(k, (1.6, 5.4, -4.2), 1.8)
    return k


# =========================================================================================== Stage 3: Ice Fang (Snow)
def ice_fang():
    k = KeeperModel('ice_fang', 'Ice Fang', 3, {
        'fur': (0.96, 0.97, 1.0), 'fur2': (0.82, 0.88, 0.96), 'mark': (0.10, 0.55, 0.95), 'mark2': (0.35, 0.80, 1.0),
        'muzzle': (1.0, 1.0, 1.0), 'nose': (0.20, 0.35, 0.65), 'inner': (0.55, 0.80, 1.0), 'silver': (0.80, 0.83, 0.90),
        'sapphire': (0.12, 0.32, 0.92), 'ice': (0.60, 0.90, 1.0), 'brow': (0.10, 0.45, 0.85), 'claw': (0.55, 0.85, 1.0),
        'lip': (0.20, 0.40, 0.70), 'eyedark': (0.98, 0.99, 1.0)},
        eye_rgb=(0.15, 0.75, 1.0))
    k.personality = 'Proud, noble guardian: chin up, calm and composed, only bares its sabres when it means it.'
    k.fidget = 'Licks a paw, then raises its head and flicks the crystal tail.'
    k.fx_notes = 'Frost aura and snowflake sparkles (ParticleEmitter); icy breath puff on the roar.'
    body = k.g('Body')
    torso = Geo('torso')
    tube(torso, [(0, 2.2, -2.5), (0, 2.4, 0.2), (0, 2.25, 3.6), (0, 2.25, 6.6), (0, 2.15, 9.5)],
         [(2.65, 2.4), (2.75, 2.45), (2.4, 2.2), (2.55, 2.3), (2.5, 2.3)], 'fur', seg=12)
    body.extend(torso)
    bvh = torso.bvh()
    # bold ice-blue swirl markings (Mitsui's bold-marking idea): a spiral on each shoulder and haunch, stripes between
    for zc, yc in ((-0.8, 2.6), (8.0, 2.4)):
        for s in (-1, 1):
            rays = []
            for i in range(14):
                a = i * 0.55
                rr = 0.25 + 0.11 * i
                rays.append(((0, yc, zc), (s * 1.0, (yc - 2.3) * 0.1 + math.sin(a) * rr * 0.55, math.cos(a) * rr * 0.55)))
            kit.stroke(body, bvh, rays, 'mark', 0.32, thick=0.1, seg=4, taper=True)
    for z0 in (2.2, 4.0, 5.8):
        for s in (-1, 1):
            rays = [((0, 2.3, z0 + 0.6 * math.sin(math.radians(25 + 100 * i / 6) * 1.5)), (s * math.sin(math.radians(25 + 100 * i / 6)),
                     math.cos(math.radians(25 + 100 * i / 6)), 0.0)) for i in range(7)]
            kit.stroke(body, bvh, rays, 'mark', 0.4, thick=0.1, seg=4)
    blob(body, (0, 1.2, -2.5), (2.45, 2.0, 2.0), 'muzzle', seg=10, rings=6)
    for i, (x, y) in enumerate(((-1.4, 1.7), (0, 0.6), (1.4, 1.7), (-0.8, 2.9), (0.8, 2.9))):
        shards(body, (x, y, -3.6), (x * 0.3, -0.6, -1), 1.5, 1.0, 'fur', n=2, seed=150 + i)          # neck ruff shards
    for i, z in enumerate((-1.0, 0.8, 6.2, 8.0)):
        shards(body, (0, 4.4, z), (0, 1, 0.5), 1.5, 0.95, 'fur2', n=2, spread=0.3, seed=160 + i)       # spiky back fur
    # R149 armour, simplified and built in: saddle plate + big sapphire, collar with three sapphires
    blob(body, (0, 4.42, 3.6), (2.2, 0.45, 2.6), 'silver', e1=0.45, e2=0.6, seg=10, rings=5)
    crystal(body, (0, 4.6, 3.6), (0, 1, 0), 0.75, 0.9, 'sapphire', sides=6)
    tube(body, [(-2.25, 2.3, -3.7), (-1.65, 4.05, -3.95), (0, 4.85, -4.05), (1.65, 4.05, -3.95), (2.25, 2.3, -3.7)],
         [(0.5, 0.36)] * 5, 'silver', seg=6, cap0='round', cap1='round')
    for x in (-1.2, 0, 1.2):
        blob(body, (x, 4.5 - abs(x) * 0.55, -4.4), (0.3, 0.3, 0.22), 'sapphire', seg=6, rings=4)
    for z, h in ((1.5, 1.4), (5.6, 1.3)):
        crystal(body, (0, 4.3, z), (0, 1, 0.45), 0.45, h, 'ice')
    # Head (posture: chin up, noble) --------------------------------------------------------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    skull = Geo('skull')
    blob(skull, (0, 3.55, -6.9), (2.7, 2.15, 2.75), 'fur', e1=0.9, e2=0.9, seg=14, rings=8)
    blob(skull, (0, 2.55, -9.45), (1.55, 1.1, 1.45), 'muzzle', seg=10, rings=6)
    head.extend(skull)
    mirror(lambda s: blob(head, (s * 0.62, 2.55, -10.55), (0.72, 0.62, 0.55), 'muzzle', seg=8, rings=5))
    blob(head, (0, 3.3, -10.55), (0.55, 0.38, 0.42), 'nose', seg=8, rings=5)
    mirror(lambda s: spike(head, (s * 0.72, 2.2, -10.35), (s * 0.82, 0.55, -10.25), 0.27, 'tooth', seg=5))   # sabres
    mirror(lambda s: [shards(head, (s * 2.4, 2.6 + d, -6.0), (s * 1, -0.3 + d * 0.3, 0.6), 1.5, 0.9, 'fur', n=2, seed=170 + int(d * 10) + s)
                      for d in (-0.5, 0.5)])   # cheek ruff shards
    mirror(lambda s: spike(head, (s * 1.9, 4.9, -5.5), (s * 2.2, 6.35, -4.9), 0.85, 'fur', seg=4))         # pointed ears
    mirror(lambda s: spike(head, (s * 1.95, 5.0, -5.75), (s * 2.18, 6.0, -5.25), 0.45, 'inner', seg=4))
    # ice-crystal horns sweeping back (like the reference wolf's horns, in ice)
    mirror(lambda s: horn(head, (s * 1.3, 5.2, -6.6), (s * 1.9, 6.4, -5.4), (s * 2.5, 6.2, -3.6), 0.42, 'ice', seg=5, n=6))
    blob(head, (0, 5.25, -6.9), (1.3, 0.4, 1.8), 'silver', e1=0.5, e2=0.6, seg=10, rings=5, M=Rx(-0.12))
    crystal(head, (0, 5.0, -8.6), (0, 0.55, -1), 0.42, 0.75, 'sapphire', sides=6)
    # bold markings on the face: eyeliner flicks and forehead swirl
    hb = skull.bvh()
    for s in (-1, 1):
        rays = [((s * 0.5, 3.6, -7.0), (s * 1.0, 0.25 + 0.06 * i, -0.9 + 0.15 * i)) for i in range(5)]
        kit.stroke(head, hb, rays, 'mark', 0.22, thick=0.08, seg=4)
        rays = [((0, 3.2, -7.4), (s * 1.0, -0.2 - 0.1 * i, -0.3 + 0.2 * i)) for i in range(5)]
        kit.stroke(head, hb, rays, 'mark2', 0.2, thick=0.08, seg=4)
    eyes = [dict(E=(s * 1.18, 4.0, -9.25), r=0.7, s=s, yaw=0.38, pitch=0.08) for s in (-1, 1)]
    face = Face(k, 'Head', skull, eyes, lid_col='fur', brow_col='brow', sclera='eyedark', iris_r=0.74,
                mouth=dict(c=(0, 2.1, -9.0), n=(0, -0.15, -1), up=(0, 1, 0)))
    face.build_eyes()
    # Idle: calm, composed, slight noble smile
    face.lids('Idle', [dict(up=(0.45, -0.05, 0.0))] * 2)
    face.brows('Idle', [dict(dy=0.15, ang=0.05, len=2.0, thick=0.4, width=0.45)] * 2)
    face.mouth_line('Idle', [(-0.75, -0.05), (-0.3, -0.2), (0.0, -0.1), (0.3, -0.2), (0.75, -0.05)], 0.12, 0.09, col='lip')
    # Chase: fierce
    face.lids('Chase', [dict(up=(0.4, 0.55, 0.0))] * 2)
    face.brows('Chase', [dict(dy=-0.05, ang=0.55, len=2.0, thick=0.45, width=0.45)] * 2)
    face.mouth_open('Chase', 1.4, 0.6, dv=-0.35, shape='Dinv', teeth_low=3, tooth=0.18, tongue=False, depth=0.35)
    # Attack: roar
    face.lids('Attack', [dict(up=(0.85, 0.35, 0.0))] * 2)
    face.brows('Attack', [dict(dy=0.1, ang=0.45, len=2.0, thick=0.45, width=0.45)] * 2)
    face.mouth_open('Attack', 1.6, 1.0, dv=-0.45, shape='oval', teeth_low=3, tooth=0.18, depth=0.4)
    # Asleep: peaceful closed eyes, tiny snore
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.2, ang=-0.05, len=1.9, thick=0.4, width=0.45)] * 2)
    face.mouth_open('Asleep', 0.45, 0.35, dv=-0.3, du=0.15, tongue=False, depth=0.25)
    # Gloat: proud wink and a smug smile
    face.lids('Gloat', [dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5)), dict(up=(0.5, -0.1, 0.0))])
    face.brows('Gloat', [dict(dy=0.2, ang=0.0, len=2.0, thick=0.4, width=0.45), dict(dy=0.45, ang=-0.25, len=2.0, thick=0.4, width=0.45)])
    face.mouth_line('Gloat', [(-0.85, 0.0), (-0.3, -0.25), (0.3, -0.2), (0.85, 0.15)], 0.13, 0.1, col='lip')
    jaw = k.g('Jaw')
    joint(jaw, (0, 2.0, -7.1), 0.6, 'muzzle')
    blob(jaw, (0, 1.85, -8.75), (1.35, 0.55, 1.45), 'muzzle', seg=10, rings=6)
    mirror(lambda s: spike(jaw, (s * 0.8, 1.85, -9.6), (s * 0.82, 2.65, -9.72), 0.16, 'tooth', seg=5))
    piv = Vector((0, 2.4, -3.7))
    k.transform(['Head', 'Jaw'], T(piv) @ Rx(-0.07) @ T(-piv))
    def leg(group, x, z0, front):
        s = 1 if x > 0 else -1
        g = k.g(group)
        blob(g, (x, 1.25, z0 + (0.15 if front else 0.35)), (1.32, 1.8, 1.8) if front else (1.45, 1.9, 1.95), 'fur', seg=10, rings=6)
        tube(g, [(x, 0.6, z0), (x + s * 0.05, -1.2, z0 - 0.15), (x, -2.9, z0 - 0.3)], [(1.22, 1.35), (1.08, 1.18), (1.1, 1.18)], 'fur', seg=10)
        blob(g, (x, -3.7, z0 - 0.75), (1.35, 0.9, 1.68), 'muzzle', e1=0.7, e2=0.8, seg=10, rings=6)
        for dx in (-0.62, 0, 0.62):
            spike(g, (x + dx, -3.95, z0 - 2.0), (x + dx, -4.5, z0 - 2.5), 0.2, 'claw', seg=4)
        lb = Geo('legtmp')
        tube(lb, [(x, 0.6, z0), (x + s * 0.05, -1.2, z0 - 0.15), (x, -2.9, z0 - 0.3)], [(1.22, 1.35), (1.08, 1.18), (1.1, 1.18)], 'fur', seg=10)
        rays = [((x, -0.6, z0 - 0.15), (s * math.cos(a), 0.0, -math.sin(a))) for a in [math.radians(-50 + 18 * i) for i in range(8)]]
        kit.stroke(g, lb.bvh(), rays, 'mark', 0.32, thick=0.08, seg=4)
        if front:
            blob(g, (x + s * 0.55, 1.95, z0), (1.15, 1.0, 1.65), 'silver', e1=0.5, e2=0.6, seg=10, rings=5, M=Rz(s * 0.35))
            blob(g, (x + s * 1.45, 1.75, z0), (0.36, 0.36, 0.36), 'sapphire', seg=6, rings=4)
    leg('LeftFrontLeg', -2.25, -3.35, True)
    leg('RightFrontLeg', 2.25, -3.35, True)
    leg('LeftBackLeg', -2.25, 9.85, False)
    leg('RightBackLeg', 2.25, 9.85, False)
    tail = k.g('Tail')
    pts = bezier((0.1, 2.1, 11.2), (0.8, 1.2, 16.5), (2.6, 2.4, 19.0), (3.0, 1.8, 21.3), n=9)
    trad = [1.2, 1.1, 1.0, 0.95, 0.9, 0.85, 0.82, 0.8, 0.76, 0.7]
    tube(tail, pts, trad, 'fur', seg=10, cap1='round')
    for i in (3, 5, 7):
        a_, b_ = pts[i], pts[i] + (pts[i + 1] - pts[i]) * 0.45
        tube(tail, [a_, b_], [trad[i] * 1.06, trad[i] * 1.06], 'mark', seg=10, cap0='flat', cap1='flat')
    shards(tail, (3.0, 1.8, 21.2), (0.25, 0.25, 1), 1.6, 1.1, 'ice', n=4, spread=0.45, seed=180)          # crystal tail tip
    sleep_z(k, (2.0, 7.8, -8.0), 1.9)
    return k


# =========================================================================================== Stage 4: Lava Dragon (Lava)
def lava_dragon():
    k = KeeperModel('lava_dragon', 'Lava Dragon', 4, {
        'plate': (0.17, 0.16, 0.19), 'plate2': (0.26, 0.24, 0.28), 'belly': (0.95, 0.55, 0.15), 'horn': (0.95, 0.88, 0.75),
        'spike': (0.20, 0.18, 0.21), 'wing': (0.22, 0.18, 0.22), 'wing2': (0.55, 0.16, 0.08), 'bone': (0.12, 0.11, 0.13),
        'brow': (0.08, 0.07, 0.09), 'claw': (0.10, 0.09, 0.10), 'nostril': (0.05, 0.03, 0.03), 'lip': (0.40, 0.08, 0.05),
        'eyedark': (0.10, 0.06, 0.05), 'smoke': (0.45, 0.42, 0.44), 'flame': (1.0, 0.55, 0.08), 'flamein': (1.0, 0.50, 0.08)},
        glow={'*': (1.0, 0.45, 0.06)}, eye_rgb=(1.0, 0.78, 0.10))
    k.personality = 'Hot-headed: permanently furious, snorts smoke when annoyed, roars at the slightest thing.'
    k.fidget = 'Snorts two smoke puffs, stomps a front foot, the back flames flare up.'
    k.fx_notes = 'Flames on every back spike and the tail tip, embers, nostril smoke (ParticleEmitter); fire breath glow on the roar.'
    body = k.g('Body')
    torso = Geo('torso')
    blob(torso, (0, 2.15, 0.9), (3.35, 3.15, 4.4), 'plate', e1=0.85, e2=0.88, seg=14, rings=8)
    blob(torso, (0, 3.0, -2.6), (2.6, 2.3, 2.0), 'plate', seg=10, rings=6)
    body.extend(torso)
    tb = torso.bvh()
    for i, z in enumerate((-2.2, -0.6, 1.0, 2.6, 4.2)):   # angular back plates
        rays = [((0, 2.0, z), (math.sin(a), math.cos(a), 0.0)) for a in [math.radians(-60 + 24 * j) for j in range(6)]]
        kit.stroke(body, tb, rays, 'plate2', 0.55, thick=0.18, seg=4, taper=False)
    blob(body, (0, 0.45, 0.6), (2.6, 1.6, 3.6), 'belly', e1=0.6, e2=0.75, seg=10, rings=6)
    bglow = k.g('Body', 'glow')
    for pts in (((0, 4.9, -2.2), (0, 5.0, 0.0), (0, 4.8, 2.4), (0, 4.4, 4.6)),          # lava seam down the spine
                ((-2.2, 3.4, -1.5), (-2.9, 2.6, 0.5), (-2.6, 2.0, 2.6)), ((2.2, 3.4, -1.5), (2.9, 2.6, 0.5), (2.6, 2.0, 2.6))):
        rays = [((0, 2.2, p[2]), (p[0], p[1] - 2.2, 0.001)) for p in pts]
        kit.stroke(bglow, tb, rays, 'iris', 0.32, thick=0.14, seg=4, taper=True)
    fx = k.g('Body', 'fx')
    for i, (z, h) in enumerate(((-1.6, 1.6), (0.3, 2.0), (2.2, 1.9), (4.0, 1.5))):
        base = Vector((0, 4.9 - 0.02 * z * z, z))
        crystal(bglow, base - Vector((0, 0.3, 0)), (0, 1, 0.25), 0.62, h + 0.3, 'iris', sides=4)   # glowing back spikes
        flame(fx, base + Vector((0, h, 0.4)), (0, 1, 0.3), 1.8, 0.9, seed=i)
    # Head + neck: charcoal plates, big bone horns, angry brow ridge -----------------------------------------------------
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    neck_pts = bezier((0, 3.3, -2.3), (0, 4.6, -4.0), (0, 6.3, -5.4), (0, 6.9, -7.0), n=6)
    neck = Geo('neck')
    tube(neck, neck_pts, [1.9, 1.85, 1.75, 1.65, 1.6, 1.55, 1.5], 'plate', seg=10, cap0='flat')
    head.extend(neck)
    rays = []
    for i in range(1, 6):
        t = (neck_pts[i + 1] - neck_pts[i - 1]).normalized()
        n = t.cross(Vector((1, 0, 0)))
        if n.z > 0:
            n = -n
        rays.append((neck_pts[i], n))
    kit.stroke(head, neck.bvh(), rays, 'belly', 1.0, thick=0.12, seg=4, taper=False)
    skull = Geo('skull')
    blob(skull, (0, 7.45, -8.4), (2.3, 1.9, 2.5), 'plate', e1=0.85, e2=0.85, seg=12, rings=7)
    blob(skull, (0, 6.85, -11.3), (1.65, 1.15, 2.2), 'plate', e1=0.8, e2=0.85, seg=10, rings=6)
    head.extend(skull)
    blob(head, (0, 6.25, -11.0), (1.55, 0.55, 2.0), 'plate2', seg=8, rings=5)
    mirror(lambda s: blob(head, (s * 0.55, 7.55, -12.95), (0.26, 0.2, 0.15), 'nostril', seg=6, rings=4))
    mirror(lambda s: horn(head, (s * 1.15, 8.7, -7.3), (s * 1.6, 10.6, -6.4), (s * 1.95, 10.85, -3.3), 0.62, 'horn', seg=5, n=6))
    mirror(lambda s: horn(head, (s * 1.7, 7.0, -7.5), (s * 2.5, 7.3, -6.2), (s * 2.55, 7.6, -5.0), 0.34, 'horn', seg=4, n=4))
    for z, x in ((-9.2, 1.2), (-10.3, 1.15), (-11.4, 1.0), (-12.3, 0.75)):
        mirror(lambda s: spike(head, (s * x, 6.15, z), (s * x * 0.97, 5.45, z), 0.15, 'tooth', seg=4))
    hglow = k.g('Head', 'glow')
    hb = skull.bvh()
    mirror(lambda s: kit.stroke(hglow, hb, [((0, 7.2, -9.0), (s * 1, -0.2, 0.3 * j - 0.6)) for j in range(4)], 'iris', 0.18, thick=0.08, seg=4))
    eyes = [dict(E=(s * 1.3, 8.15, -9.75), r=0.68, s=s, yaw=0.45, pitch=0.1) for s in (-1, 1)]
    face = Face(k, 'Head', skull, eyes, lid_col='plate', brow_col='brow', sclera='eyedark', iris_r=0.8,
                mouth=dict(c=(0, 6.3, -10.6), n=(0, -0.25, -1), up=(0, 1, 0)))
    face.build_eyes(slit=True)
    smoke_fx = k.g('Head', 'fx', 'Smoke')
    mirror(lambda s: [blob(smoke_fx, (s * (0.85 + 0.45 * i), 7.5 + 0.3 * i, -13.55 - 0.6 * i), (0.2 + 0.07 * i,) * 3, 'smoke', seg=8, rings=5)
                      for i in range(3)])
    # Idle: grumpy pout, furrowed brows
    face.lids('Idle', [dict(up=(0.42, 0.45, 0.0))] * 2)
    face.brows('Idle', [dict(dy=-0.05, ang=0.5, len=2.3, thick=0.55, width=0.55)] * 2)
    face.mouth_line('Idle', [(-1.0, 0.15), (-0.4, -0.05), (0.3, -0.05), (1.0, 0.1)], 0.16, 0.12, col='lip')
    # Chase: yelling
    face.lids('Chase', [dict(up=(0.5, 0.6, 0.0))] * 2)
    face.brows('Chase', [dict(dy=-0.1, ang=0.6, len=2.3, thick=0.6, width=0.55)] * 2)
    face.mouth_open('Chase', 1.8, 0.8, dv=-0.15, shape='Dinv', teeth_up=4, tooth=0.22, tongue=False, depth=0.4)
    # Attack: roar with fire inside
    face.lids('Attack', [dict(up=(0.8, 0.4, 0.0))] * 2)
    face.brows('Attack', [dict(dy=0.05, ang=0.5, len=2.3, thick=0.6, width=0.55)] * 2)
    face.mouth_open('Attack', 2.0, 1.2, dv=-0.25, shape='oval', teeth_up=4, teeth_low=3, tooth=0.22, col='flamein', depth=0.45)
    # Asleep: closed eyes, smoke puffs (fx)
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.1, ang=0.2, len=2.2, thick=0.5, width=0.5)] * 2)
    face.mouth_line('Asleep', [(-0.9, 0.1), (-0.3, -0.05), (0.3, -0.05), (0.9, 0.1)], 0.13, 0.1, col='lip')
    # Gloat: toothy grin, smug squint
    face.lids('Gloat', [dict(up=(0.3, 0.2, 0.0), low=(-0.25, 0.0, 0.0), lowlash=True)] * 2)
    face.brows('Gloat', [dict(dy=0.15, ang=0.25, len=2.3, thick=0.55, width=0.55), dict(dy=0.35, ang=-0.1, len=2.3, thick=0.55, width=0.55)])
    face.mouth_open('Gloat', 2.0, 0.7, dv=-0.1, shape='D', teeth_up=5, tooth=0.22, tongue=False, depth=0.4, tilt=-0.08)
    jaw = k.g('Jaw')
    joint(jaw, (0, 5.5, -6.9), 1.0, 'plate2')
    blob(jaw, (0, 5.25, -9.8), (1.55, 0.6, 3.3), 'plate2', seg=12, rings=6)
    blob(jaw, (0, 5.62, -10.3), (1.25, 0.2, 2.4), 'mouthin', seg=10, rings=4)
    for z, x in ((-9.0, 1.05), (-10.4, 0.95), (-11.8, 0.7)):
        mirror(lambda s: spike(jaw, (s * x, 5.45, z), (s * x * 0.95, 6.05, z), 0.13, 'tooth', seg=4))
    def leg(group, x, z, front):
        s = 1 if x > 0 else -1
        g = k.g(group)
        if front:
            joint(g, (s * 2.8, 2.0, -2.7), 1.3, 'plate')
            blob(g, (x, 1.3, z), (1.35, 1.5, 1.55), 'plate', seg=10, rings=6)
            tube(g, [(x, 1.0, z), (x - s * 0.1, -1.6, z - 0.4), (x, -3.5, z - 0.6)], [1.2, 1.0, 0.95], 'plate', seg=8)
            fz = z - 1.4
        else:
            joint(g, (s * 2.8, 1.5, 4.55), 1.3, 'plate')
            blob(g, (x - s * 0.15, 0.6, z), (1.55, 2.0, 2.15), 'plate', seg=10, rings=6)
            tube(g, [(x, -0.4, z + 0.6), (x, -2.2, z + 0.7), (x, -3.6, z - 0.2)], [1.25, 1.05, 0.98], 'plate', seg=8)
            fz = z - 1.1
        blob(g, (x, -4.15, fz), (1.15, 0.65, 1.45), 'plate2', e1=0.7, e2=0.8, seg=10, rings=5)
        for dx in (-0.55, 0, 0.55):
            spike(g, (x + dx, -4.3, fz - 1.15), (x + dx * 1.1, -4.75, fz - 1.75), 0.22, 'claw', seg=4)
        lg = k.g(group, 'glow')
        blob(lg, (x + s * 0.9, 1.0 if front else 0.4, z), (0.35, 0.8, 0.5), 'iris', seg=6, rings=4)
    leg('LeftFrontLeg', -2.75, -3.0, True)
    leg('RightFrontLeg', 2.75, -3.0, True)
    leg('LeftBackLeg', -2.85, 4.6, False)
    leg('RightBackLeg', 2.85, 4.6, False)
    tail = k.g('Tail')
    pts = bezier((0, 1.2, 5.6), (0.4, 0.2, 10.0), (2.4, -0.2, 13.8), (4.0, 0.7, 17.4), n=9)
    rads = [1.6 * (1 - i / 10.5) + 0.32 for i in range(10)]
    tube(tail, pts, rads, 'plate', seg=8, cap0='round', cap1='round')
    tglow = k.g('Tail', 'glow')
    tfx = k.g('Tail', 'fx')
    for i in (2, 4, 6):
        p = pts[i]
        crystal(tglow, (p.x, p.y + rads[i] * 0.6, p.z), (0, 1, 0.5), 0.42, 1.0, 'iris', sides=4)
    tube(tglow, [(3.85, 0.7, 17.0), (4.2, 1.0, 17.9), (4.45, 1.5, 18.35)], [0.75, 0.55, 0.0], 'iris', seg=6, cap0='round', cap1='point')
    flame(tfx, (4.3, 1.4, 18.2), (0.2, 1, 0.5), 2.4, 1.2, seed=9)
    for s, group in ((-1, 'LeftWing'), (1, 'RightWing')):
        g = k.g(group)
        pv = Vector((s * 2.84, 4.19, -1.3))
        sh = Vector((s * 2.9, 4.7, -1.1))
        el = Vector((s * 7.3, 9.0, 0.3))
        wr = Vector((s * 10.4, 10.6, 1.0))
        tips = [Vector((s * 12.9, 8.3, 3.0)), Vector((s * 11.6, 5.9, 6.0)), Vector((s * 8.2, 4.0, 7.9))]
        root = Vector((s * 3.0, 4.4, 4.2))
        tube(g, [sh, el], [0.55, 0.42], 'bone', seg=6)
        tube(g, [el, wr], [0.42, 0.34], 'bone', seg=6)
        for tp in tips:
            tube(g, [wr, tp], [0.3, 0.1], 'bone', seg=5, cap1='point')
        spike(g, wr, wr + Vector((s * 0.3, 1.1, -0.6)), 0.25, 'claw', seg=4)
        panels = [(el, wr, tips[0], (el + tips[0]) / 2 + Vector((0, -0.6, 0.6))),
                  (wr, tips[0], (tips[0] + tips[1]) / 2 + Vector((-s * 0.8, 0.2, -0.3)), tips[1]),
                  (wr, tips[1], (tips[1] + tips[2]) / 2 + Vector((-s * 0.9, 0.4, -0.6)), tips[2]),
                  (sh, wr, tips[2], (tips[2] + root) / 2 + Vector((s * 0.3, 0.6, -0.9)), root)]
        for i, poly in enumerate(panels):
            membrane(g, poly, 0.18, 'wing' if i % 2 == 0 else 'wing2')
        g.v = [pv + (p - pv) * 1.35 for p in g.v]    # the game's V110 x1.35 wing scale, baked in
        joint(g, pv, 1.55, 'bone')                    # shoulder ball at the hinge, overlapping the body
    sleep_z(k, (2.2, 12.6, -9.0), 2.2)
    return k


# =========================================================================================== Stage 5: Crystal Knight (Crystal)
def crystal_knight():
    k = KeeperModel('crystal_knight', 'Crystal Knight', 5, {
        'armor': (0.72, 0.74, 0.88), 'armor2': (0.90, 0.92, 0.98), 'under': (0.22, 0.17, 0.40), 'under2': (0.32, 0.25, 0.52),
        'crystal': (0.66, 0.40, 1.0), 'crystal2': (0.86, 0.66, 1.0), 'trim': (0.95, 0.78, 0.25), 'grip': (0.20, 0.15, 0.32),
        'recess': (0.06, 0.05, 0.12), 'blade': (0.82, 0.72, 1.0), 'tabard': (0.45, 0.20, 0.80), 'plume': (0.80, 0.30, 0.95)},
        glow={'*': (0.74, 0.52, 1.0)}, eye_rgb=(0.85, 0.75, 1.0))
    k.personality = 'Stern, by-the-book sentinel: stands to attention, sword upright, never lets anything slide.'
    k.fidget = 'Straightens up, taps the sword hilt twice, turns the helm left and right like a guard on patrol.'
    k.fx_notes = 'Crystal sparkle aura, a slash trail on the sword (Trail), crystal shards bursting on impact.'
    k.state_eyes = True
    body = k.g('Body')
    blob(body, (0, 15.1, 0.1), (6.3, 4.7, 3.9), 'armor', e1=0.6, e2=0.75, seg=12, rings=8)
    blob(body, (0, 15.4, -3.45), (5.0, 3.6, 0.75), 'armor2', e1=0.5, e2=0.7, seg=10, rings=6)
    blob(body, (0, 9.7, 0.0), (4.9, 1.5, 3.3), 'under', e1=0.6, e2=0.8, seg=10, rings=6)
    mirror(lambda s: blob(body, (s * 6.6, 18.0, 0.0), (2.6, 2.0, 2.6), 'armor', seg=8, rings=5))     # shoulder sockets
    tube(body, [(-4.9, 10.6, -0.2), (0, 10.75, -3.45), (4.9, 10.6, -0.2)], [0.42, 0.42, 0.42], 'trim', seg=6)
    blob(body, (0, 11.3, -3.75), (2.2, 3.4, 0.35), 'tabard', e1=0.4, e2=0.6, seg=8, rings=5)          # tabard with emblem
    crystal(body, (0, 11.6, -4.05), (0, 0, -1), 0.6, 0.6, 'trim', sides=4)
    mirror(lambda s: blob(body, (s * 3.0, 8.1, -3.25), (2.4, 2.0, 0.55), 'armor', e1=0.45, e2=0.7, seg=10, rings=5, M=Rz(s * 0.12)))
    bglow = k.g('Body', 'glow')
    crystal(bglow, (0, 14.5, -4.0), (0, 1, -0.15), 1.05, 3.3, 'iris', sides=6)
    # Head: a CLOSED helm (no face): visor slit, nose guard, cheek guards, a tall crystal plume crest ---------------
    head = k.g('Head')
    blob(head, (0, 23.4, 0.0), (3.55, 3.7, 3.3), 'armor', e1=0.6, e2=0.8, seg=14, rings=8)
    blob(head, (0, 23.4, -2.6), (3.3, 3.2, 1.0), 'armor2', e1=0.45, e2=0.7, seg=12, rings=7)        # face plate
    rbox(head, (0, 23.35, -3.35), (5.6, 0.95, 0.7), 'recess', round_=0.3)                            # visor slit
    rbox(head, (0, 22.05, -3.42), (0.8, 2.0, 0.5), 'armor', round_=0.3)                               # nose guard
    for i in range(5):                                                                                  # breathing holes
        mirror(lambda s: blob(head, (s * (0.9 + 0.38 * i), 21.5 - 0.1 * i, -3.3 + 0.12 * i), (0.12, 0.12, 0.1), 'recess', seg=6, rings=4))
    rbox(head, (0, 24.55, -3.25), (6.2, 0.65, 0.9), 'trim', round_=0.3)                              # gold brow band
    for i, (x, z, ax, h, r) in enumerate(((0, -1.6, (0, 1, 0.15), 3.6, 0.7), (0, -0.2, (0, 1, 0.45), 3.4, 0.62), (0, 1.2, (0, 1, 0.75), 2.8, 0.55),
                                           (0, 2.3, (0, 0.8, 1.0), 2.2, 0.45))):
        crystal(head, (x, 26.4 - 0.2 * i, z), ax, r, h, 'plume' if i % 2 else 'crystal')
    mirror(lambda s: crystal(head, (s * 3.3, 24.2, -0.5), (s * 1, 0.6, 0.2), 0.45, 1.5, 'crystal2'))
    # eyes-only expressions: glowing shapes inside the visor slit, one piece per state ------------------------------
    k.state_rgb = {'Idle': ((0.85, 0.75, 1.0), 2.4), 'Chase': ((1.0, 0.55, 0.95), 3.0), 'Attack': ((1.0, 0.92, 1.0), 4.5),
                   'Asleep': ((0.45, 0.38, 0.65), 0.6), 'Gloat': ((0.85, 0.75, 1.0), 2.6)}
    y0, z0 = 23.35, -3.62
    for s in (-1, 1):
        x0 = s * 1.45
        rbox(k.g('Head', 'eyes', 'Idle'), (x0, y0, z0), (1.5, 0.32, 0.3), 'iris', round_=0.4)                 # calm narrow bars
        g = k.g('Head', 'eyes', 'Chase')                                                                    # sharp angry slants
        tube(g, [(x0 - s * 0.9, y0 - 0.25, z0), (x0 + s * 0.85, y0 + 0.28, z0)], [(0.2, 0.32), (0.06, 0.12)], 'iris', seg=4, cap0='round', cap1='point', smooth=False)
        g = k.g('Head', 'eyes', 'Attack')                                                                   # wide, bright, flared
        blob(g, (x0, y0, z0), (0.9, 0.44, 0.22), 'iris', seg=10, rings=6)
        for a in (-0.5, 0.0, 0.5):
            spike(g, (x0 + s * 0.6, y0 + a * 0.3, z0), (x0 + s * 1.35, y0 + a * 0.9, z0 - 0.05), 0.12, 'iris', seg=4)
        g = k.g('Head', 'eyes', 'Asleep')                                                                   # dim flat lines
        rbox(g, (x0, y0 - 0.12, z0 + 0.05), (1.3, 0.1, 0.25), 'iris', round_=0.4)
        g = k.g('Head', 'eyes', 'Gloat')                                                                    # happy ^ ^ arcs
        tube(g, [(x0 - 0.7, y0 - 0.25, z0), (x0, y0 + 0.28, z0 - 0.03), (x0 + 0.7, y0 - 0.25, z0)], [0.13, 0.15, 0.13], 'iris', seg=6, cap0='round', cap1='round', smooth=True)
    # Arms ------------------------------------------------------------------------------------------------------------
    for s, arm, fore in ((1, 'LeftArm', 'LeftForearm'), (-1, 'RightArm', 'RightForearm')):
        g = k.g(arm)
        joint(g, (s * 9.1, 18.0, 0.0), 2.0, 'under')
        blob(g, (s * 9.6, 19.4, 0.0), (3.4, 2.7, 3.6), 'armor', e1=0.55, e2=0.75, seg=12, rings=7)
        tube(g, [(s * 9.1, 18.0, -0.2), (s * 9.1, 11.0, -0.5)], [1.95, 1.8], 'under', seg=8)
        tube(g, [(s * 9.1, 14.6, -0.3), (s * 9.1, 13.3, -0.35)], [2.1, 2.1], 'armor2', seg=8, cap0='flat', cap1='flat')
        for (dx, dy, ax, h, r) in ((0.9, 1.9, (0.45, 1, 0.1), 2.6, 0.62), (2.3, 1.2, (0.9, 0.8, 0.0), 2.0, 0.5), (-0.4, 2.2, (0.0, 1, -0.3), 1.8, 0.5)):
            crystal(g, (s * (9.6 + dx), 19.4 + dy, 0.2), (s * ax[0], ax[1], ax[2]), r, h, 'crystal')
        f = k.g(fore)
        joint(f, (s * 9.1, 9.8, -0.6), 1.75, 'under2')
        blob(f, (s * 9.1, 6.2, -1.5), (2.45, 3.3, 2.55), 'armor2', e1=0.6, e2=0.75, seg=10, rings=6)
        blob(f, (s * 9.1, 2.85, -2.45), (2.1, 1.55, 2.1), 'armor', e1=0.6, e2=0.75, seg=10, rings=6)
        tube(f, [(s * 9.1, 4.25, -1.9), (s * 9.1, 3.75, -2.05)], [2.55, 2.55], 'trim', seg=8, cap0='flat', cap1='flat')
    for s, leg in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(leg)
        joint(g, (s * 3.25, 4.68, 0.0), 2.0, 'under')
        tube(g, [(s * 3.25, 8.6, 0.0), (s * 3.25, 2.2, -0.4)], [2.25, 2.05], 'under', seg=8)
        blob(g, (s * 3.25, 0.7, -0.6), (2.45, 2.7, 2.45), 'armor', e1=0.6, e2=0.8, seg=10, rings=6)
        crystal(g, (s * 3.25, 3.6, -2.2), (0, 0.4, -1), 0.9, 1.3, 'crystal')
        blob(g, (s * 3.25, -2.5, -1.4), (2.75, 1.45, 3.7), 'armor2', e1=0.5, e2=0.7, seg=10, rings=5)
    sw = k.g('Sword')
    tube(sw, [(-9.1, 3.9, -2.8), (-9.1, -0.1, -2.8)], [0.5, 0.5], 'grip', seg=6)
    blob(sw, (-9.1, 4.25, -2.8), (0.75, 0.6, 0.75), 'crystal2', seg=6, rings=4)
    rbox(sw, (-9.1, -0.55, -2.8), (5.6, 0.95, 1.7), 'trim', round_=0.35)
    tube(sw, [(-9.1, -0.7, -2.8), (-9.1, -5.0, -2.8), (-9.1, -9.7, -2.8)], [(1.42, 0.42), (1.3, 0.38), (0.0, 0.0)], 'blade', seg=4,
         cap0='flat', cap1='none', smooth=False, up=Vector((0, 0, 1)))
    swg = k.g('Sword', 'glow')
    tube(swg, [(-9.1, -0.9, -2.8), (-9.1, -8.4, -2.8)], [(0.32, 0.5), (0.0, 0.0)], 'iris', seg=4, cap0='flat', cap1='none', smooth=False)
    sleep_z(k, (3.8, 31.5, -2.5), 3.0)
    return k


# =========================================================================================== Stage 7: Storm Colossus (Storm)
def storm_colossus():
    k = KeeperModel('storm_colossus', 'Storm Colossus', 7, {
        'stone': (0.28, 0.32, 0.44), 'stone2': (0.20, 0.23, 0.33), 'stone3': (0.40, 0.46, 0.60), 'prong': (0.80, 0.62, 0.30),
        'recess': (0.06, 0.07, 0.12), 'brow': (0.14, 0.16, 0.24), 'cloud': (0.50, 0.55, 0.66), 'cloud2': (0.36, 0.40, 0.52),
        'lip': (0.10, 0.11, 0.18), 'tooth': (0.85, 0.88, 0.95), 'eyedark': (0.05, 0.06, 0.10), 'bolt': (0.65, 0.92, 1.0), 'boltin': (0.45, 0.85, 1.0)},
        glow={'*': (0.55, 0.88, 1.0)}, eye_rgb=(0.55, 0.92, 1.0))
    k.personality = 'Loud brute: shouts everything, huge underbite, laughs like thunder; fists float on storm power.'
    k.fidget = 'Punches its floating fists together (sparks), cracks its neck, the cloud mane rumbles.'
    k.fx_notes = 'Lightning arcs linking the floating fists and shoulder rocks to the body (Beams), crackling sparks, a rain cloud.'
    body = k.g('Body')
    torso = Geo('torso')
    blob(torso, (0, 17.7, 0.2), (7.4, 6.6, 4.3), 'stone', e1=0.75, e2=0.85, seg=14, rings=8)
    body.extend(torso)
    blob(body, (0, 22.3, -1.2), (8.0, 2.3, 3.4), 'stone2', e1=0.6, e2=0.8, seg=12, rings=6)              # mantle
    blob(body, (0, 9.6, 0.0), (5.4, 2.6, 3.4), 'stone2', e1=0.7, e2=0.85, seg=12, rings=6)              # hips: legs attach here
    for i, (x, z) in enumerate(((-5.0, 1.0), (4.6, 1.4), (-1.5, 2.6), (2.0, -0.6))):
        shards(body, (x, 23.6, z), (x * 0.08, 1, 0.2), 2.2, 1.6, 'stone3', n=2, seed=200 + i)          # rock spikes on the mantle
    for i, x in enumerate((-6.0, 6.0)):
        blob(body, (x, 24.0, 0.8), (2.6, 1.4, 2.4), 'cloud', seg=10, rings=6)                            # storm clouds on the shoulders
        blob(body, (x * 1.12, 24.5, -0.4), (1.8, 1.1, 1.7), 'cloud2', seg=8, rings=5)
    tb = torso.bvh()
    bglow = k.g('Body', 'glow')
    for pts in (((0.0, 22.0), (1.6, 19.6), (-0.2, 18.8), (1.4, 15.4), (-0.6, 14.0)),
                ((-4.6, 21.0), (-3.5, 18.5), (-5.0, 16.5)), ((4.8, 20.5), (3.8, 18.0), (5.2, 15.6))):
        rays = [((0, 17.7, 0), (x, y - 17.7, -3.0)) for x, y in pts]
        kit.stroke(bglow, tb, rays, 'iris', 0.36, thick=0.16, seg=4, taper=True)
    # Head: boulder head, heavy brow, huge underbite jaw, storm-cloud mane, copper lightning-rod horns -----------
    head, iris = k.g('Head'), k.g('Head', 'eyes')
    skull = Geo('skull')
    blob(skull, (0, 26.6, 0.0), (4.3, 3.55, 3.7), 'stone', e1=0.75, e2=0.85, seg=12, rings=7)
    blob(skull, (0, 24.6, -1.4), (3.8, 1.7, 2.7), 'stone3', e1=0.6, e2=0.8, seg=10, rings=6)           # big jaw
    head.extend(skull)
    for i, x in enumerate((-2.2, 2.2)):
        spike(head, (x, 25.0, -3.6), (x * 1.05, 26.9, -3.95), 0.42, 'tooth', seg=4)                    # underbite tusks
    for i, (x, z, r) in enumerate(((0, 1.5, 2.6), (-2.6, 1.2, 2.0), (2.6, 1.0, 2.0), (0, 3.2, 1.8), (-1.6, 2.8, 1.5), (1.6, 2.9, 1.5))):
        blob(head, (x, 29.4 - 0.4 * abs(x) / 2.6, z), (r, r * 0.7, r), 'cloud' if i % 2 == 0 else 'cloud2', seg=8, rings=5)
    mirror(lambda s: tube(head, [(s * 2.6, 28.8, -0.5), (s * 3.6, 30.6, -0.2), (s * 3.9, 32.2, 0.2)], [0.32, 0.25, 0.18], 'prong', seg=5))
    mirror(lambda s: blob(head, (s * 3.9, 32.3, 0.2), (0.38, 0.38, 0.38), 'prong', seg=6, rings=4))
    hb = skull.bvh()
    hglow = k.g('Head', 'glow')
    kit.stroke(hglow, hb, [((0, 26.6, 0), (0.3 * j - 0.6, 1.0, -0.6)) for j in range(4)], 'iris', 0.25, thick=0.1, seg=4)
    eyes = [dict(E=(s * 1.6, 27.0, -3.2), r=0.82, s=s, yaw=0.2, pitch=0.05) for s in (-1, 1)]
    face = Face(k, 'Head', skull, eyes, lid_col='stone', brow_col='brow', sclera='eyedark', iris_r=0.78,
                mouth=dict(c=(0, 25.25, 0.0), n=(0, -0.05, -1), up=(0, 1, 0)))
    face.build_eyes(pupil=False)
    # Idle: grumpy frown
    face.lids('Idle', [dict(up=(0.4, 0.35, 0.0))] * 2)
    face.brows('Idle', [dict(dy=-0.05, ang=0.4, len=2.6, thick=0.6, width=0.6)] * 2)
    face.mouth_line('Idle', [(-1.6, -0.55), (-0.8, -0.2), (0.0, -0.1), (0.8, -0.2), (1.6, -0.55)], 0.26, 0.18, col='lip')
    # Chase: yelling
    face.lids('Chase', [dict(up=(0.5, 0.6, 0.0))] * 2)
    face.brows('Chase', [dict(dy=-0.1, ang=0.6, len=2.6, thick=0.65, width=0.6)] * 2)
    face.mouth_open('Chase', 2.8, 1.3, dv=-0.2, shape='Dinv', teeth_low=5, tooth=0.35, tongue=False, depth=0.55, col='mouthin')
    # Attack: thunder roar with lightning inside
    face.lids('Attack', [dict(up=(0.85, 0.4, 0.0))] * 2)
    face.brows('Attack', [dict(dy=0.1, ang=0.55, len=2.6, thick=0.65, width=0.6)] * 2)
    face.mouth_open('Attack', 3.2, 2.0, dv=-0.35, shape='oval', teeth_up=5, teeth_low=5, tooth=0.35, col='boltin', depth=0.6)
    # Asleep: snoring big mouth, drool
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.15, ang=0.0, len=2.5, thick=0.55, width=0.55)] * 2)
    face.mouth_open('Asleep', 1.6, 1.1, dv=-0.3, du=0.4, shape='oval', tongue=True, depth=0.45)
    face.drool('Asleep', 1.1, -0.85, 1.3)
    # Gloat: thunder laugh, eyes squeezed shut
    face.lids('Gloat', [dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5))] * 2)
    face.brows('Gloat', [dict(dy=0.3, ang=-0.2, len=2.5, thick=0.6, width=0.6)] * 2)
    face.mouth_open('Gloat', 3.0, 1.6, dv=-0.3, shape='D', teeth_up=6, tooth=0.35, depth=0.55)
    # Arms: a shoulder rock and a big fist, both FLOATING by design, linked to the body by lightning --------------
    fx = k.g('Body', 'fx')
    for s, arm in ((1, 'LeftArm'), (-1, 'RightArm')):
        rock = k.g(arm, 'main', 'Rock')
        blob(rock, (s * 11.9, 20.8, 0.0), (3.6, 4.0, 4.4), 'stone', e1=0.7, e2=0.8, seg=10, rings=6)
        for (dx, dy, ax, h, r) in ((0.6, 3.3, (0.25, 1, 0.05), 3.8, 0.8), (2.4, 2.2, (0.7, 1, 0.0), 3.2, 0.7)):
            crystal(rock, (s * (11.9 + dx), 20.8 + dy, 0.4), (s * ax[0], ax[1], ax[2]), r, h, 'stone3')
        fist = k.g(arm, 'main', 'Fist')
        blob(fist, (s * 12.65, 9.9, -1.4), (4.1, 4.4, 4.4), 'stone2', e1=0.66, e2=0.8, seg=10, rings=6)
        for dx in (-2.1, -0.7, 0.7, 2.1):
            blob(fist, (s * 12.65 + dx, 8.3, -5.25), (0.85, 0.9, 0.75), 'stone3', seg=6, rings=4)
        ag = k.g(arm, 'glow')
        blob(ag, (s * 12.4, 15.4, -0.5), (1.35, 1.35, 1.35), 'iris', seg=8, rings=6)          # the storm-core joint
        k.floating |= {(arm, 'Rock'), (arm, 'Fist'), (arm, 'Glow')}
        afx = k.g(arm, 'fx')
        bolt(afx, (s * 7.2, 20.0, 0.0), (s * 8.6, 20.6, 0.2), 0.16, seed=1 + s)
        bolt(afx, (s * 12.0, 16.6, -0.4), (s * 11.9, 18.0, -0.2), 0.16, seed=3 + s)
        bolt(afx, (s * 12.4, 14.1, -0.6), (s * 12.5, 13.0, -0.8), 0.16, seed=5 + s)
    for s, leg in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(leg)
        joint(g, (s * 3.74, 6.54, 0.0), 2.2, 'stone2')
        blob(g, (s * 3.98, 3.3, 0.0), (2.75, 3.55, 3.05), 'stone', e1=0.7, e2=0.8, seg=10, rings=6)
        blob(g, (s * 3.98, -1.45, -2.2), (3.55, 1.7, 4.75), 'stone2', e1=0.6, e2=0.8, seg=10, rings=5)
        lg = k.g(leg, 'glow')
        blob(lg, (s * 3.91, 7.0, -1.6), (1.0, 1.0, 1.0), 'iris', seg=8, rings=5)
    sleep_z(k, (5.0, 34.0, -2.0), 3.2)
    return k


# =========================================================================================== The Darkened (Void event keeper)
def the_darkened():
    """Group-local geometry (each group is placed at its frame; parts at frame * VeiledFrame). Body pieces stay inside
    today's hit boxes; the hood, cloak and claws are cosmetic (VeiledCosmetic = true, never used for hits)."""
    k = KeeperModel('the_darkened', 'The Darkened', 0, {
        'cloth': (0.10, 0.08, 0.15), 'cloth2': (0.20, 0.14, 0.30), 'black': (0.04, 0.04, 0.07), 'mask': (0.94, 0.92, 0.98),
        'mask2': (0.74, 0.70, 0.86), 'metal': (0.70, 0.58, 0.32), 'claw': (0.86, 0.84, 0.95), 'wrap': (0.26, 0.20, 0.36),
        'brow': (0.30, 0.16, 0.50), 'lip': (0.20, 0.10, 0.30), 'eyedark': (0.04, 0.03, 0.06), 'mark': (0.55, 0.25, 0.85),
        'mouthin': (0.12, 0.02, 0.20)},
        glow={'*': (0.80, 0.55, 1.0)}, eye_rgb=(0.85, 0.55, 1.0), floor=-5.0, local=True)
    k.personality = 'Creepy and silent: never speaks, tilts its head, stares; the smile is the scariest part.'
    k.fidget = 'Slow head tilt to one side and back, long fingers drum the air, the cloak drifts.'
    k.fx_notes = 'Purple void smoke aura and drifting motes (ParticleEmitter); eye glow trails (Trail) while chasing.'
    t = k.g('Torso')
    blob(t, (0, 0.1, 0), (2.7, 1.72, 1.18), 'cloth', e1=0.6, e2=0.8, seg=12, rings=7)
    mirror(lambda s: blob(t, (s * 2.65, 0.95, 0), (0.8, 0.8, 0.9), 'cloth2', seg=8, rings=6))
    for rib in (1, 2, 3):
        mirror(lambda s: tube(t, [(s * 0.35, 1.25 - rib * 0.7, -1.0), (s * 1.3, 1.1 - rib * 0.7, -0.98), (s * 2.0, 1.0 - rib * 0.72, -0.72)],
                              [0.1, 0.1, 0.06], 'metal', seg=5, cap0='round', cap1='point'))
    cloak = k.g('Torso', 'main', 'Cloak')
    for i, x in enumerate((-2.9, -1.75, -0.6, 0.6, 1.75, 2.9)):
        ln = 8.2 + (1.4 if i % 2 else 0.0) - abs(x) * 0.3
        sp = 1.0 + abs(x) * 0.12
        membrane(cloak, [(x * 0.9 - 0.7, 1.7, 1.0), (x * 0.9 + 0.7, 1.7, 1.0), (x * sp + 0.6, 1.7 - ln, 2.1 + 0.08 * ln),
                         (x * sp, 1.7 - ln - 1.1, 2.15 + 0.08 * ln), (x * sp - 0.6, 1.7 - ln, 2.1 + 0.08 * ln)], 0.14,
                 'cloth2' if i % 2 else 'cloth')
    mirror(lambda s: blob(cloak, (s * 2.6, 1.7, 0.2), (1.2, 0.55, 1.25), 'cloth2', seg=10, rings=5))
    for i, x in enumerate((-2.4, -1.2, 1.2, 2.4)):
        shards(cloak, (x, 1.9, 0.6), (x * 0.4, 1, 0.3), 1.3, 0.8, 'cloth2', n=2, seed=300 + i)            # tattered collar shards
    k.cosmetic |= {('Torso', 'Cloak'), ('Head', 'Hood'), ('LHand', 'Claws'), ('RHand', 'Claws'), ('LFoot', 'Ankle'), ('RFoot', 'Ankle')}
    tg = k.g('Torso', 'glow')
    membrane(tg, [(0.03, 1.35, -1.04), (0.2, 0.62, -1.04), (-0.04, 0.3, -1.04), (0.14, -0.55, -1.04), (-0.02, -1.32, -1.04),
                  (-0.14, -0.48, -1.04), (0.08, -0.18, -1.04), (-0.16, 0.66, -1.04)], 0.22, 'iris')
    w = k.g('Waist')
    tube(w, [(0, -1.68, 0), (0, 0, 0), (0, 1.68, 0)], [(1.08, 0.74), (0.95, 0.66), (1.12, 0.78)], 'cloth', seg=10, cap0='flat', cap1='flat')
    h = k.g('Hip')
    blob(h, (0, 0, 0), (1.32, 0.95, 0.88), 'cloth', e1=0.7, seg=10, rings=6)
    mirror(lambda s: blob(h, (s * 0.95, -0.65, 0), (0.78, 0.78, 0.78), 'black', seg=8, rings=6))
    n = k.g('Neck')
    tube(n, [(0, -0.68, 0), (0, 0.68, 0)], [0.52, 0.44], 'black', seg=8, cap0='flat', cap1='flat')
    hd, iris = k.g('Head'), k.g('Head', 'eyes')
    skull = Geo('mask')
    blob(skull, (0, 0, -0.1), (0.98, 1.45, 0.62), 'mask', e1=0.85, e2=0.9, seg=12, rings=8)
    hd.extend(skull)
    hb = skull.bvh()
    for s in (-1, 1):   # void markings down the mask
        kit.stroke(hd, hb, [((s * 0.2, 0.2 - 0.25 * j, 0.2), (s * 0.35, -0.05, -1)) for j in range(5)], 'mark', 0.07, thick=0.04, seg=4)
    hglow = k.g('Head', 'glow')
    kit.stroke(hglow, hb, [((0.0, 1.1 - 0.35 * j, 0.2), (0.02 * (-1) ** j, 0.0, -1)) for j in range(5)], 'iris', 0.06, thick=0.04, seg=4)
    hood = k.g('Head', 'main', 'Hood')
    blob(hood, (0, 0.45, 0.4), (1.8, 2.2, 1.6), 'cloth', e1=0.9, e2=0.9, seg=12, rings=7,
         deform=lambda p: Vector((p.x, p.y, p.z if p.z > -0.6 else -0.6 + (p.z + 0.6) * 0.12)))
    spike(hood, (0, 2.3, 0.6), (0, 3.4, 2.0), 0.75, 'cloth', seg=6)
    mirror(lambda s: blob(hood, (s * 1.2, -1.5, 0.5), (0.9, 1.0, 1.0), 'cloth2', seg=8, rings=5))
    eyes = [dict(E=(s * 0.43, 0.33, -0.56), r=0.27, s=s, yaw=0.15, pitch=0.0) for s in (-1, 1)]
    face = Face(k, 'Head', skull, eyes, lid_col='mask', brow_col='brow', sclera='eyedark', iris_r=0.7,
                mouth=dict(c=(0, -0.55, 0.0), n=(0, 0, -1), up=(0, 1, 0)))
    face.build_eyes(pupil=True)
    # Idle: blank stare, no mouth, one brow slightly raised (creepy calm)
    face.lids('Idle', [dict(up=(0.55, 0.0, 0.0)), dict(up=(0.75, -0.15, 0.0))])
    face.brows('Idle', [dict(dy=0.1, ang=0.0, len=2.0, thick=0.4, width=0.45), dict(dy=0.3, ang=-0.2, len=2.0, thick=0.4, width=0.45)])
    face.mouth_line('Idle', [(-0.12, 0.0), (0.12, 0.0)], 0.04, 0.03, col='lip')
    # Chase: wide staring eyes, pin pupils feel, a thin line mouth
    face.lids('Chase', [dict(up=(0.9, 0.35, 0.0))] * 2)
    face.brows('Chase', [dict(dy=0.0, ang=0.5, len=2.0, thick=0.45, width=0.45)] * 2)
    face.mouth_line('Chase', [(-0.4, -0.05), (-0.1, 0.03), (0.15, -0.03), (0.4, 0.05)], 0.05, 0.04, col='lip')
    # Attack: the mask splits into a jagged grin
    face.lids('Attack', [dict(up=(0.9, 0.5, 0.0))] * 2)
    face.brows('Attack', [dict(dy=0.0, ang=0.6, len=2.0, thick=0.45, width=0.45)] * 2)
    face.mouth_open('Attack', 1.15, 0.45, dv=0.0, shape='D', teeth_up=6, teeth_low=6, tooth=0.11, tongue=False, depth=0.25)
    # Asleep: eyes closed, mask calm
    face.lids('Asleep', [dict(up=(-0.05, 0.0, 0.35), low=(-0.05, 0.0, 0.35))] * 2)
    face.brows('Asleep', [dict(dy=0.15, ang=-0.1, len=1.9, thick=0.35, width=0.4)] * 2)
    # Gloat: crescent eyes and a far-too-wide thin smile
    face.lids('Gloat', [dict(up=(0.12, 0.0, -0.5), low=(0.12, 0.0, -0.5))] * 2)
    face.brows('Gloat', [dict(dy=0.3, ang=-0.25, len=1.9, thick=0.4, width=0.45)] * 2)
    face.mouth_line('Gloat', [(-0.75, 0.2), (-0.45, -0.05), (0.0, -0.15), (0.45, -0.05), (0.75, 0.2)], 0.06, 0.04, col='lip')
    for q, s in (('L', -1), ('R', 1)):
        ua = k.g(q + 'UpperArm')
        tube(ua, [(0, 1.62, 0), (0, -1.68, 0)], [(0.6, 0.64), (0.5, 0.55)], 'cloth', seg=8)
        fa = k.g(q + 'Forearm')
        blob(fa, (0, 2.1, 0), (0.6, 0.6, 0.6), 'black', seg=8, rings=5)
        tube(fa, [(0, 1.9, 0), (0, -1.62, 0)], [(0.5, 0.55), (0.42, 0.48)], 'wrap', seg=8)
        tube(fa, [(0, -1.62, 0), (0, -1.78, 0)], [0.56, 0.56], 'metal', seg=8, cap0='flat', cap1='flat')
        hn = k.g(q + 'Hand')
        blob(hn, (0, 0, 0), (0.62, 0.52, 0.4), 'black', seg=8, rings=5)
        blob(hn, (0, 0.55, 0), (0.46, 0.3, 0.44), 'black', seg=6, rings=4)
        claws = k.g(q + 'Hand', 'main', 'Claws')
        for i in (1, 2, 3):
            x = (i - 2) * 0.4
            horn(claws, (x, -0.3, 0), (x * 1.1, -1.4, -0.15), (x * 1.15, -2.2, -0.55), 0.13, 'claw', seg=4, n=4)
        th = k.g(q + 'Thigh')
        tube(th, [(0, 1.3, 0), (0, -1.42, 0)], [(0.68, 0.74), (0.55, 0.6)], 'cloth', seg=8)
        sh = k.g(q + 'Shin')
        blob(sh, (0, 1.8, 0), (0.62, 0.62, 0.62), 'black', seg=8, rings=5)
        tube(sh, [(0, 1.6, 0), (0, -1.32, 0)], [(0.52, 0.58), (0.42, 0.48)], 'wrap', seg=8)
        ankle = k.g(q + 'Foot', 'main', 'Ankle')            # cosmetic: keeps foot and shin joined when the knee folds
        blob(ankle, (0, 0.35, 0.55), (0.5, 0.5, 0.5), 'black', seg=8, rings=5)
        ft = k.g(q + 'Foot')
        blob(ft, (0, 0, 0.15), (0.68, 0.34, 1.1), 'black', e1=0.7, seg=8, rings=5,
             deform=lambda p: Vector((p.x * (0.55 + 0.45 * min(1, (p.z + 1.1) / 1.2)), p.y, p.z)))
    sleep_z(k, (0.9, 2.6, -0.5), 1.1)
    # posture: creepy head tilt
    k.transform(['Head'], Rz(0.14))
    return k


BUILDERS = {1: timber_golem, 6: jungle_king, 2: sand_snake, 3: ice_fang, 4: lava_dragon, 5: crystal_knight, 7: storm_colossus,
            0: the_darkened}
ORDER = [1, 6, 2, 3, 4, 5, 7, 0]  # biome order: Forest, Jungle, Desert, Snow, Lava, Crystal, Storm, then The Darkened
BIOME = {1: 'Forest', 6: 'Jungle', 2: 'Desert', 3: 'Snow', 4: 'Lava', 5: 'Crystal', 7: 'Storm', 0: 'Void event'}
