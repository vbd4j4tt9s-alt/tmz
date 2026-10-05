"""PROPOSED keepers, revision 4: classic Roblox block builds, following the owner's rev 3 feedback.

Style (every keeper but The Darkened): chunky, blocky, simple and readable, like a classic Roblox build. Masses are
chamfered blocks, wedges and cylinders (kit.cbox / kit.beam / kit.cyl): thick limbs, big heads, hands and paws, few
small details, the stud texture on the big faces. Faces (faces.py) are flat graphic decals on a flat face plane (the
front of a block), so nothing stretches; the two eyes are one outline mirrored. Two faces per keeper: Chase (fierce,
shown whenever the keeper is awake) and Asleep. The Timber Golem and the Storm Colossus keep their creature faces
(glowing slits and a crack); the Crystal Knight keeps a closed helm with glowing eyes; The Darkened is exactly rev 3.
Every piece touches the body (connectivity.py), except the Storm Colossus's floating fists, shoulder rocks and storm
cores, which the owner allowed as part of its design.

Mesh parts per keeper:
  <Group>                main mesh of a rig group (same groups and pivots the game animates today)
  <Group>_<Piece>        extra main pieces (golem pieces for its tree disguise, the Darkened's cosmetic cloak, ...)
  <Group>_Glow           Neon accents (lava seams, sap cracks, crystal cores, lightning)
  Head_Face_<State>      the face shapes of one state (Chase, Asleep); the client shows one (LocalTransparencyModifier)
  Head_Eyes_<State>      the glowing eyes of one state (a KeeperEyeGlow Neon part)
Effects (fx kind: flames, lightning arcs, smoke, wisps, the sleep Z) are preview stand-ins for particles / beams /
a billboard, not meshes to upload.
"""
import math
from mathutils import Vector, Matrix
import kit
from kit import Geo, Palette, blob, tube, rbox, horn, spike, crystal, membrane, bezier, shards, cbox, box, beam, cyl, T, Rx, Ry, Rz, V
from faces import FlatFace, STATES, FIERCE, ALMOND, SLOT, SLIT, SQUARE, place

WHITE = (0.98, 0.98, 0.97)
PUPIL = (0.05, 0.05, 0.08)
COMMON = {'white': WHITE, 'pupil': PUPIL, 'lash': (0.06, 0.04, 0.06), 'mouthin': (0.40, 0.03, 0.06), 'tongue': (0.80, 0.22, 0.28),
          'tooth': (1.0, 0.97, 0.88), 'drool': (0.62, 0.86, 1.0), 'zcol': (0.30, 0.85, 1.0), 'zedge': (0.05, 0.22, 0.55),
          'lip': (0.06, 0.04, 0.05), 'eyedark': (0.05, 0.04, 0.05), 'eyedim': (0.16, 0.12, 0.08)}


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
        self.state_eyes = False      # Crystal Knight / The Darkened: glowing eyes (or line) per state, no face pieces
        self.state_rgb = {}          # per-state eye colour / brightness
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
        """Triangles on screen at once: everything but the face / eye parts of the other state (the larger state)."""
        best = 0
        for state in STATES:
            total = 0
            for group, kind, piece, g in self.parts():
                if kind in ('face', 'eyes') and piece in STATES and piece != state:
                    continue
                total += g.tris()
            best = max(best, total)
        return best

    def transform(self, groups, M):
        """Re-pose rest geometry of whole groups (posture: a head held high, a tilted head)."""
        for (group, kind, piece), geo in self.geos.items():
            if group in groups:
                geo.v = [(M @ Vector((p.x, p.y, p.z, 1))).xyz for p in geo.v]


def mirror(fn):
    for s in (-1, 1):
        fn(s)


def joint(g, p, size, col):
    """A hidden core cube centred on a group's pivot: its centre stays put under any rotation about the pivot, so the
    parent (which overlaps it) always touches the limb. Rev 4: a plain chamfered cube in the limb's colour, 4 % under
    its nominal size so it never shares a face with a block of the same width (coplanar faces render black)."""
    size *= 0.96
    cbox(g, p, (size, size, size), col, bevel=0.2)


def lerp(a, b, t):
    a, b = Vector(a), Vector(b)
    return a + (b - a) * t


def band(g, pts, n, width, depth, col):
    """A flat band lying on a plane with normal n (a crack, a stripe, a seam): blocks through the 3D points."""
    for a, b in zip(pts, pts[1:]):
        beam(g, a, b, depth, width, col, bevel=0.12, side=n, ext=width * 0.42)


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
_UPG = None


def native(stage):
    """Today's native parts of a keeper (KeeperUpgradeData): name, group, size, rest frame, shape, colour."""
    global _UPG
    if _UPG is None:
        import data
        _UPG = data.load_upg()
    return _UPG[str(stage)]['Parts']


def nat(g, p, col, bevel=0.1, grow=(0, 0, 0), M2=None):
    """One of today's native parts, rebuilt at its exact rest frame and size: a Block as a crisp chamfered block, a
    Wedge as a wedge. grow adds to its size (chunkier); M2 is an extra local transform (a tilt)."""
    M = kit.cf_matrix(p['Rest']) @ (M2 or Matrix.Identity(4))
    size = [s + d for s, d in zip(p['Size'], grow)]
    if p['Shape'] == 'Wedge':
        box(g, (0, 0, 0), size, col, M=M, wedge=True)
    else:
        cbox(g, (0, 0, 0), size, col, bevel=bevel, M=M)


def timber_golem():
    """Rev 5: TODAY's in-game Timber Golem, improved. Every one of today's native parts (KeeperUpgradeData) is rebuilt
    at its exact size, rest frame and colour as a crisp bevelled block or wedge: the brown trunk with its split-bark
    beard, the moss shoulders, the big green stepped leaf hood, the stump head with its hollow face and heavy brows,
    the block arms with dark root knuckles and leafy shoulder tiers, the wide root legs. Improvements: a clean
    glowing-slit face, today's green chest rune as a glowing rune in a knothole, today's orange mushrooms, moss drips
    and tufts, bark bands, a few bright leaf cubes and a little bird's nest on the hood. The pieces follow today's
    tree-disguise moves exactly (each piece groups parts that share one TreeRest move)."""
    k = KeeperModel('timber_golem', 'Timber Golem', 1, {
        'bark': (0.42, 0.30, 0.19), 'bark2': (0.33, 0.23, 0.14), 'ridge': (0.50, 0.36, 0.23), 'brow': (0.36, 0.24, 0.15),
        'knuckle': (0.18, 0.13, 0.11), 'moss': (0.30, 0.55, 0.24), 'moss2': (0.24, 0.47, 0.19), 'leaf': (0.24, 0.46, 0.22),
        'leaf2': (0.30, 0.55, 0.24), 'leaf3': (0.35, 0.59, 0.26), 'leaf4': (0.45, 0.70, 0.30), 'hollow': (0.18, 0.13, 0.11),
        'mush': (0.93, 0.58, 0.24), 'mush2': (0.97, 0.75, 0.38), 'spot': (1.0, 0.95, 0.85), 'nest': (0.55, 0.38, 0.20),
        'egg': (0.55, 0.85, 0.95), 'bird': (0.30, 0.60, 0.95), 'beak': (1.0, 0.65, 0.10), 'eyedark': (0.07, 0.05, 0.03),
        'eyedim': (0.20, 0.36, 0.26)},
        glow={'*': (0.51, 0.96, 0.64)}, eye_rgb=(0.51, 0.96, 0.64))
    k.personality = 'Grumpy old tree that hates being woken: a heavy, silent glare from two glowing slits under its leafy hood; a bird nests on top.'
    k.fidget = 'Scratches its bark with a root knuckle; the chest rune pulses; the bird hops on the hood; leaves drift down.'
    k.fx_notes = 'Falling leaves and drifting spores (ParticleEmitter); the chest rune pulses (a brightness tween); dust burst on the hammer slam.'
    leafs = {(0.24, 0.46, 0.22): 'leaf', (0.30, 0.55, 0.24): 'leaf2', (0.35, 0.59, 0.26): 'leaf3'}
    for p in native(1):
        n, grp = p['Name'], p['Group']
        if n == 'Glowing slit':
            continue                                                      # replaced by the face (below)
        if grp == 'Body':
            nat(k.g('Body'), p, {'Root torso': 'bark', 'Moss shoulders': 'moss'}.get(n, 'ridge'),
                grow=(0.2, 0.3, 0.2) if n == 'Moss shoulders' else (0, 0, 0))
        elif grp == 'Head':
            if n.startswith('Oak'):
                nat(k.g('Head', 'main', 'Canopy'), p, leafs[tuple(round(c, 2) for c in p['Color'])], bevel=0.08)
            elif n == 'Heavy brow':
                s = 1 if p['Rest'][0] > 0 else -1
                nat(k.g('Head', 'main', 'Stump'), p, 'brow', grow=(0.2, 0.1, 0.1), M2=Rz(s * 0.22))   # angled: a scowl
            else:
                nat(k.g('Head', 'main', 'Stump'), p, {'Hollow face': 'hollow', 'Jaw': 'brow'}.get(n, 'bark'))
        elif grp in ('LeftArm', 'RightArm'):
            piece = {'Heavy forearm': 'Fist', 'Root knuckle': 'Fist', 'Oak shoulder tier': 'Tier'}.get(n, 'Upper')
            col = {'Moss plate': 'moss', 'Root knuckle': 'knuckle', 'Oak shoulder tier': 'leaf2'}.get(n, 'bark')
            nat(k.g(grp, 'main', piece), p, col, grow=(0.15, 0.2, 0.15) if n == 'Moss plate' else (0, 0, 0))
        else:
            nat(k.g(grp), p, 'bark')
    # Body details: a knothole with today's green rune (glowing), moss drips and tufts, today's orange mushrooms ------
    body = k.g('Body')
    box(body, (0, 6.4, -2.6), (1.0, 2.6, 0.3), 'hollow')                                  # the knothole between the bark plates
    rune = k.g('Body', 'glow')
    cbox(rune, (0, 7.1, -2.78), (0.62, 0.62, 0.3), 'iris', bevel=0.2, M=Rz(math.pi / 4))
    cbox(rune, (0, 5.95, -2.78), (0.26, 1.3, 0.3), 'iris', bevel=0.2)
    for s in (-1, 1):
        beam(rune, (0, 6.2, -2.78), (s * 0.3, 5.75, -2.78), 0.22, 0.3, 'iris', side=(0, 0, 1))
    for x, h in ((-3.5, 1.1), (-2.2, 0.7), (-0.7, 1.4), (1.4, 0.9), (3.4, 1.3)):
        box(body, (x, 9.3 - h / 2, -2.86), (0.8, h, 0.3), 'moss2')                        # moss dripping over the front
    for x, z in ((-2.8, 1.6), (-0.6, -1.6), (2.2, 2.0)):
        cbox(body, (x, 10.55, z), (1.2, 0.6, 1.2), 'moss2', bevel=0.25)                    # moss tufts on the shoulders
    for (x, y, z, w, h, c) in ((2.9, 10.45, -1.2, 1.6, 0.55, 'mush'), (3.4, 10.05, 0.4, 1.1, 0.4, 'mush2')):   # today's mushrooms
        cbox(body, (x, y, z), (w, h, w), c, bevel=0.3)
        box(body, (x + 0.25, y + h / 2 + 0.02, z - 0.2), (0.28, 0.06, 0.28), 'spot')
    for s in (-1, 1):
        for z in (-1.2, 1.2):
            box(body, (s * 3.95, 5.4, z), (0.16, 6.2, 0.45), 'bark2')                      # bark grooves on the sides (torso x +-3.885)
    # Head: today's hollow face, now a clean creature face; a bird's nest and bright leaf cubes on the hood --------------
    joint(k.g('Head', 'main', 'Stump'), (0, 10.985, 0), 2.6, 'bark')
    can = k.g('Head', 'main', 'Canopy')
    for (x, y, z, sz, c) in ((-6.7, 14.8, -2.6, 1.7, 'leaf4'), (6.8, 15.2, 2.4, 1.6, 'leaf4'), (3.4, 20.0, -2.6, 1.5, 'leaf4'),
                             (-3.0, 18.9, 3.6, 1.6, 'leaf3'), (-6.2, 17.4, 2.8, 1.4, 'leaf3'), (5.6, 18.3, -1.6, 1.4, 'leaf4')):
        cbox(can, (x, y, z), (sz, sz * 0.85, sz), c, bevel=0.15)
    nest = Vector((0.9, 21.9, 1.3))
    cbox(can, nest, (2.6, 0.9, 2.6), 'nest', bevel=0.3)
    cbox(can, nest + Vector((-0.5, 0.6, 0.5)), (0.6, 0.7, 0.6), 'egg', bevel=0.3)
    cbox(can, nest + Vector((0.25, 0.6, 0.8)), (0.55, 0.65, 0.55), 'egg', bevel=0.3)
    cbox(can, nest + Vector((0.4, 0.8, -0.5)), (0.9, 0.8, 1.2), 'bird', bevel=0.25)
    cbox(can, nest + Vector((0.4, 1.5, -0.9)), (0.75, 0.7, 0.75), 'bird', bevel=0.25)
    box(can, nest + Vector((0.4, 1.4, -1.4)), (0.3, 0.22, 0.4), 'beak')
    for dx in (0.2, 0.6):
        box(can, nest + Vector((dx, 1.63, -1.28)), (0.1, 0.12, 0.04), 'pupil')
    face = FlatFace(k, 'Head', {'face': dict(c=(0, 11.91, -2.67), n=(0, 0, -1))}, unit=0.06)    # the hollow face plane
    for s in (-1, 1):
        face.plate(face.g('Chase', 'eyes'), place(SLOT, s * 1.18, 0.18, s, 0.0, 1.75, 0.58), 'iris', 1)
        face.plate(face.g('Asleep'), place(SQUARE, s * 1.18, 0.1, s, 0.0, 1.5, 0.14), 'eyedim', 1)
    face.line('Chase', [(-1.45, -0.72), (-0.97, -0.98), (-0.48, -0.7), (0.0, -1.0), (0.48, -0.7), (0.97, -0.98), (1.45, -0.72)], 0.2,
              col='iris', kind='eyes')
    # Arms: joint cores, a dark bark band on each forearm, a leaf sprout on each shoulder bough --------------------------
    for s, grp in ((1, 'LeftArm'), (-1, 'RightArm')):
        joint(k.g(grp, 'main', 'Upper'), (s * 4.81, 8.95, 0), 2.6, 'bark')
        cbox(k.g(grp, 'main', 'Fist'), (s * 5.88, 5.6, -0.37), (4.62, 0.45, 4.43), 'bark2', bevel=0.15)
        cbox(k.g(grp, 'main', 'Upper'), (s * 7.03, 14.3, 0.93), (1.5, 1.2, 1.5), 'leaf4', bevel=0.2)
        cbox(k.g(grp, 'main', 'Upper'), (s * 5.2, 10.85, -0.9), (1.2, 0.55, 1.2), 'moss2', bevel=0.25)
    for s, grp in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(grp)
        joint(g, (s * 2.035, 1.735, 0), 2.6, 'bark')
        for x in (0.9, 2.3, 3.7):
            box(g, (s * x, -0.95, -1.66), (0.35, 2.6, 0.12), 'bark2')                       # bark grooves on the leg front
    sleep_z(k, (3.2, 23.5, -1.0), 2.6)
    k.tree_map = {('Body', None): 'Root torso', ('Head', 'Stump'): 'Stump head', ('Head', 'Canopy'): 'Oak Leaf crown',
                  ('LeftArm', 'Upper'): 'Heavy shoulder', ('LeftArm', 'Fist'): 'Heavy forearm', ('LeftArm', 'Tier'): 'Oak shoulder tier',
                  ('RightArm', 'Upper'): 'Heavy shoulder', ('RightArm', 'Fist'): 'Heavy forearm', ('RightArm', 'Tier'): 'Oak shoulder tier',
                  ('LeftLeg', None): 'Root leg', ('RightLeg', None): 'Root leg', ('Head', 'Eyes'): 'Glowing slit', ('Body', 'Glow'): 'Root torso',
                  ('Head', 'Face'): 'Stump head', ('Head', None): 'Stump head'}
    return k


# =========================================================================================== Stage 6: Jungle King (Jungle)
def jungle_king():
    """Today's in-game gorilla (owner screenshots), improved: the same dark brown fur, grey-green face mask and chest
    plate, glowing yellow eyes, mossy shoulders and arms and the hunched knuckle-walking build, as a cleaner, chunkier
    block build with a clean flat-mask face, vine bands, leaf accents and a small moss-and-leaf crown."""
    k = KeeperModel('jungle_king', 'Jungle King', 6, {
        'fur': (0.19, 0.13, 0.09), 'fur2': (0.28, 0.20, 0.14), 'mask': (0.42, 0.47, 0.39), 'mask2': (0.31, 0.35, 0.29),
        'moss': (0.27, 0.50, 0.16), 'moss2': (0.38, 0.62, 0.22), 'vine': (0.17, 0.33, 0.10), 'leaf': (0.30, 0.64, 0.20),
        'leaf2': (0.44, 0.76, 0.26), 'flower': (0.95, 0.35, 0.55), 'nostril': (0.08, 0.09, 0.08), 'eyedark': (0.06, 0.06, 0.05),
        'lash': (0.07, 0.07, 0.06), 'tooth': (0.93, 0.90, 0.78)},
        eye_rgb=(1.0, 0.86, 0.15))
    k.personality = 'Grumpy jungle king: hunched on his knuckles, glares with burning yellow eyes, roars in your face, wears a crown of moss.'
    k.fidget = 'Beats his chest twice, knuckle-drums the ground, picks a leaf off his moss crown.'
    k.fx_notes = 'Chest-beat shockwave ring and dust (ParticleEmitter); falling jungle leaves; yellow eye glow.'
    body = k.g('Body')
    cbox(body, (0, 4.6, 0.4), (8.8, 5.8, 5.8), 'fur', bevel=0.12)          # chest  y 1.7..7.5, front z -2.5
    cbox(body, (0, 1.6, 1.4), (6.4, 3.2, 4.6), 'fur', bevel=0.12)          # belly / hips
    cbox(body, (0, 6.5, 2.0), (7.8, 2.6, 4.2), 'fur2', bevel=0.15)         # broad hunched back
    for s in (-1, 1):
        cbox(body, (s * 2.1, 7.85, 2.3), (2.8, 0.5, 2.6), 'moss', bevel=0.2)   # moss on the back
        cbox(body, (s * 1.65, 5.2, -2.55), (3.1, 2.6, 0.6), 'mask', bevel=0.2) # grey-green chest plate (two pecs)
    cbox(body, (0, 3.0, -2.5), (3.8, 1.7, 0.5), 'mask2', bevel=0.2)
    box(body, (2.6, 7.95, 3.0), (0.8, 0.2, 0.8), 'leaf2')
    # Head: a big block head, the flat grey-green mask and muzzle, a heavy brow, a small moss crown -------------------
    head = k.g('Head')
    cbox(head, (0, 6.8, -1.2), (3.6, 2.0, 3.0), 'fur', bevel=0.2)          # neck core
    cbox(head, (0, 9.3, -2.4), (5.4, 4.4, 4.6), 'fur', bevel=0.12)         # y 7.1..11.5, z -4.7..-0.1
    cbox(head, (0, 9.0, -4.75), (4.6, 3.2, 0.5), 'mask', bevel=0.2)        # face mask, plane z -5.0
    cbox(head, (0, 7.9, -5.4), (3.4, 1.8, 1.2), 'mask2', bevel=0.15)       # muzzle, plane z -6.0
    for s in (-1, 1):
        cbox(head, (s * 1.2, 10.5, -5.1), (2.7, 0.8, 1.0), 'fur', bevel=0.2, M=Rz(s * 0.22))     # heavy V brow
        cbox(head, (s * 2.75, 8.8, -2.6), (0.6, 2.2, 2.4), 'fur2', bevel=0.2)                    # side tufts
    cbox(head, (0, 11.7, -2.4), (5.0, 0.6, 4.2), 'moss', bevel=0.2)       # the moss crown
    for i, x in enumerate((-1.8, -0.6, 0.6, 1.8)):
        beam(head, (x, 11.6, -4.3), (x * 1.15, 12.9 + 0.25 * (i in (1, 2)), -4.5), 0.85, 0.25, 'leaf' if i % 2 else 'leaf2',
             side=(1, 0, 0), top=0.15, ext=0.15)
    for s in (-1, 1):
        beam(head, (s * 2.3, 11.6, -2.6), (s * 2.9, 12.7, -2.4), 0.25, 0.9, 'leaf', side=(1, 0, 0), top=0.15, ext=0.15)
    cbox(head, (1.6, 12.1, -4.4), (0.55, 0.55, 0.3), 'flower', bevel=0.2, M=Rz(math.pi / 4))
    face = FlatFace(k, 'Head', {'eyes': dict(c=(0, 9.0, -5.0), n=(0, 0, -1)), 'mouth': dict(c=(0, 7.9, -6.0), n=(0, 0, -1))},
                    unit=0.07)
    for s in (-1, 1):
        face.plate(head, place(SQUARE, s * 0.45, 0.58, s, 0.0, 0.48, 0.28), 'nostril', 0, fr='mouth')
    # Chase: glowing yellow angry eyes, a roaring mouth with fangs
    face.eye('Chase', 1.05, 0.38, 1.3, 0.8, shape=FIERCE, pupil=SQUARE, pupil_w=0.34, fr='eyes')
    face.mouth('Chase', 0.0, -0.3, 2.45, 1.0, teeth_up=3, teeth_low=2, tooth_h=0.26, fang=0.42, fr='mouth')
    # Asleep: closed eyes, a round snoring mouth
    face.closed_eye('Asleep', 1.05, 0.36, 1.25, width=0.2, curve=0.2, fr='eyes')
    face.mouth('Asleep', 0.0, -0.32, 0.72, 0.56, teeth_up=0, teeth_low=0, shape='o', fr='mouth')
    jaw = k.g('Jaw')
    joint(jaw, (0, 7.15, -3.6), 1.3, 'mask2')
    cbox(jaw, (0, 6.75, -4.9), (3.0, 0.9, 2.2), 'mask2', bevel=0.2)
    for s in (-1, 1):
        beam(jaw, (s * 0.85, 6.9, -6.05), (s * 0.85, 7.6, -6.05), 0.32, 0.32, 'tooth', top=0.2)
    # Arms: massive knuckle-walking blocks, moss on the shoulders and upper arms, vine bands -----------------------
    for s, group in ((-1, 'LeftArm'), (1, 'RightArm')):
        g = k.g(group)
        joint(g, (s * 4.15, 6.45, 0.25), 2.6, 'fur')
        cbox(g, (s * 5.0, 6.2, 0.2), (3.4, 3.2, 3.8), 'fur', bevel=0.12)
        cbox(g, (s * 5.1, 7.95, 0.2), (3.6, 0.5, 4.0), 'moss', bevel=0.2)
        cbox(g, (s * 6.75, 6.4, 0.0), (0.5, 2.4, 3.0), 'moss2', bevel=0.2)
        a, b = Vector((s * 5.1, 5.0, 0.0)), Vector((s * 5.3, 1.4, -1.4))
        beam(g, a, b, 2.8, 3.0, 'fur', ext=0.3)
        cbox(g, (0, 0, 0), (0.4, 2.6, 2.0), 'moss', bevel=0.2,
             M=kit.T(lerp(a, b, 0.35) + Vector((s * 1.45, 0, 0))) @ kit.frame_from(b - a))
        a2, b2 = Vector((s * 5.3, 1.6, -1.3)), Vector((s * 5.4, -2.0, -2.4))
        beam(g, a2, b2, 3.0, 3.2, 'fur', ext=0.3)
        for t in (0.3, 0.72):
            beam(g, lerp(a2, b2, t), lerp(a2, b2, t + 0.12), 3.2, 3.4, 'vine', bevel=0.12)
        cbox(g, (s * 6.85, -0.4, -2.0), (0.3, 1.0, 1.2), 'leaf2', bevel=0.2)
        cbox(g, (s * 5.4, -2.9, -2.8), (3.0, 2.2, 3.0), 'fur', bevel=0.15)
        cbox(g, (s * 5.4, -3.3, -4.35), (2.6, 0.9, 0.4), 'mask2', bevel=0.25)      # knuckle pads
    for s, group in ((-1, 'LeftBackLeg'), (1, 'RightBackLeg')):
        g = k.g(group)
        joint(g, (s * 1.65, 0.9, 1.9), 2.4, 'fur')
        cbox(g, (s * 2.0, 0.0, 1.6), (2.8, 3.0, 3.0), 'fur', bevel=0.12)
        cbox(g, (s * 2.1, -2.2, 1.2), (2.4, 2.4, 2.4), 'fur', bevel=0.12)
        cbox(g, (s * 2.1, -3.55, 0.3), (2.6, 0.9, 3.6), 'mask2', bevel=0.15)
    sleep_z(k, (2.6, 15.0, -3.0), 2.2)
    return k


# =========================================================================================== Stage 2: Sand Snake (Desert)
SNAKE_PIVOTS = [(0.0, -2.63, 0.6), (1.0, -2.75, 3.7), (3.15, -2.87, 6.7), (4.0, -3.0, 10.0), (3.3, -3.12, 13.3),
                (1.3, -3.24, 16.3), (-1.5, -3.36, 18.8), (-4.0, -3.49, 21.3), (-5.0, -3.61, 24.3), (-5.35, -3.75, 27.0)]


def sand_snake():
    """Today's in-game Sand Snake (owner screenshots), improved: the same tan rattlesnake with the brown diamond back,
    the wedge viper head with yellow eyes and a dark eye stripe, small golden brow horns, the golden lower jaw and
    the rattle; chunkier block segments and a bigger, more readable head."""
    k = KeeperModel('sand_snake', 'Sand Snake', 2, {
        'tan': (0.86, 0.76, 0.58), 'tan2': (0.93, 0.85, 0.68), 'diamond': (0.48, 0.31, 0.16), 'blotch': (0.62, 0.45, 0.27),
        'belly': (0.96, 0.90, 0.74), 'gold': (0.90, 0.62, 0.16), 'gold2': (0.78, 0.50, 0.12), 'stripe': (0.30, 0.18, 0.09),
        'nose': (0.25, 0.14, 0.06), 'brow': (0.30, 0.17, 0.07), 'eyedark': (0.14, 0.08, 0.04), 'lash': (0.28, 0.15, 0.06)},
        eye_rgb=(1.0, 0.84, 0.12))
    k.personality = 'Sly desert rattler: rears up in an S, narrows its yellow eyes, flashes its fangs; strikes before you see it move.'
    k.fidget = 'Flicks its forked tongue, sways its head side to side, rattles the tail tip.'
    k.fx_notes = 'Sand swirl at the tail and a dust trail while chasing (ParticleEmitter); the rattle keeps its buzz.'
    radii = [1.75, 1.62, 1.48, 1.33, 1.17, 1.0, 0.84, 0.68, 0.52, 0.36]
    for i in range(9):
        g = k.g('Segment%d' % (i + 1))
        a, b = Vector(SNAKE_PIVOTS[i]), Vector(SNAKE_PIVOTS[i + 1])
        ra, rb_ = radii[i], radii[i + 1]
        rm = (ra + rb_) / 2
        pa = Vector((a.x, -4 + ra * 0.95, a.z))
        pb = Vector((b.x, -4 + rb_ * 0.95, b.z))
        h, w = 2 * rm * 0.95, 2 * rm * 1.15
        last = i == 8
        tp = (0.25, 0.25) if last else (rb_ / rm, rb_ / rm)
        bt = (ra / rm, ra / rm)
        M = beam(g, pa, pb, h, w, 'tan', bevel=0.15, side=(0, 1, 0), ext=rm * 0.3, top=tp, bottom=bt)
        L = (pb - pa).length
        cbox(g, (0, 0, 0), (h * 0.3, L + rm * 0.45, w * 1.03), 'belly', bevel=0.15, M=M @ T(-h * 0.36, 0, 0), top=tp, bottom=bt)
        if not last:    # the diamond back: a brown diamond with a tan centre on top, half-diamonds on the sides
            d = rm * 1.25
            cbox(g, (0, 0, 0), (0.16, d, d), 'diamond', bevel=0.12, M=M @ T(h * 0.5, 0, 0) @ Rx(math.pi / 4))
            cbox(g, (0, 0, 0), (0.2, d * 0.5, d * 0.5), 'tan2', bevel=0.12, M=M @ T(h * 0.53, 0, 0) @ Rx(math.pi / 4))
            for s in (-1, 1):
                cbox(g, (0, 0, 0), (d * 0.62, d * 0.62, 0.16), 'blotch', bevel=0.12,
                     M=M @ T(h * 0.08, L * 0.25 * s, s * w * 0.5) @ Rz(math.pi / 4))
        if i > 0:
            joint(g, a, ra * 1.5, 'tan')
    # Head: a stepped block neck (a hidden root reaches into the first segment for the coil wind-up) ------------------
    head = k.g('Head')
    npts = [Vector((0, -2.45, 2.0)), Vector((0, -2.1, -0.2)), Vector((0, -0.5, -1.6)), Vector((0, 1.0, -2.9))]
    for i, (a, b, wd) in enumerate(zip(npts, npts[1:], (3.3, 3.1, 3.0))):
        Mn = beam(head, a, b, wd, wd * 0.85, 'tan', side=(1, 0, 0), ext=0.5)
        L = (b - a).length
        cbox(head, (0, 0, 0), (wd * 0.7, L * 0.9, 0.3), 'belly', bevel=0.2, M=Mn @ T(0, 0, -wd * 0.85 / 2))
        d = wd * 0.62
        cbox(head, (0, 0, 0), (d, d, 0.16), 'diamond', bevel=0.12, M=Mn @ T(0, 0, wd * 0.85 / 2) @ Rz(math.pi / 4))
        cbox(head, (0, 0, 0), (d * 0.5, d * 0.5, 0.2), 'tan2', bevel=0.12, M=Mn @ T(0, 0, wd * 0.85 / 2 + 0.03) @ Rz(math.pi / 4))
    beam(head, (0, -2.3, 1.8), (0.3, -5.4, 0.5), 1.6, 1.6, 'tan')               # hidden root (under the floor at rest)
    # the viper head: a wedge (wide at the back, narrow snout), flat top, sloping sides
    ha, hb = Vector((0, 2.05, -2.9)), Vector((0, 1.95, -7.9))
    HW, HH, TX, TZ = 4.8, 2.5, 0.52, 0.8
    beam(head, ha, hb, HW, HH, 'tan', side=(1, 0, 0), top=(TX, TZ), bevel=0.12)
    def at(t, sx, sy):   # a point on the wedge: t along it (0 back, 1 snout), sx / sy in -1..1 across its width / height
        p = lerp(ha, hb, t)
        f = 1 + (TX - 1) * t
        fz = 1 + (TZ - 1) * t
        return Vector((sx * HW / 2 * f, p.y + sy * HH / 2 * fz, p.z))
    t = at(1, 0, 1) - at(0, 0, 1)
    frames = {'top': dict(c=at(0.55, 0, 1), n=Vector((0, -t.z, t.y)).normalized(), up=(0, 0, -1)),   # v runs to the snout
              'snout': dict(c=at(1, 0, 0), n=(0, 0, -1))}
    for s in (-1, 1):
        e = at(1, s, 0) - at(0, s, 0)
        n = Vector((-e.z, 0, e.x))
        if n.x * s < 0:
            n = -n
        frames['side%d' % s] = dict(c=at(0.45, s, 0), n=n.normalized())   # the vertical side planes, facing out and forward
    face = FlatFace(k, 'Head', frames, unit=0.06)
    # always: the dark eye stripe through each eye, a brown chevron on top, nostrils, the brow ridges with gold horns
    for s in (-1, 1):
        fr = 'side%d' % s
        p0, p1 = face.uv(at(0.5, s, 0.2), fr), face.uv(at(0.05, s, -0.45), fr)
        face.bar(head, p0, p1, 0.42, 'stripe', 0, fr)
        ridge0, ridge1 = at(0.35, s * 0.93, 0.98), at(0.72, s * 0.9, 0.98)
        beam(head, ridge0, ridge1, 0.55, 0.45, 'brow', side=(0, 1, 0), ext=0.2)
        for t, hgt in ((0.42, 0.75), (0.58, 0.6)):
            p = lerp(ridge0, ridge1, (t - 0.35) / 0.37)
            beam(head, p - Vector((0, 0.1, 0)), p + Vector((s * 0.15, hgt, 0.35)), 0.3, 0.3, 'gold', top=0.15)
        face.plate(head, place(SQUARE, 0.32 * s, 0.25, 1, 0.0, 0.22, 0.16), 'nose', 0, fr='snout')
    face.bar(head, (-0.9, -0.6), (0.0, 0.4), 0.3, 'diamond', 0, fr='top')
    face.bar(head, (0.9, -0.6), (0.0, 0.4), 0.3, 'diamond', 0, fr='top')
    face.bar(head, (-0.75, 0.9), (0.0, 1.9), 0.3, 'diamond', 0, fr='top')
    face.bar(head, (0.75, 0.9), (0.0, 1.9), 0.3, 'diamond', 0, fr='top')
    for s in (-1, 1):
        fr = 'side%d' % s
        sm = -s                                     # on each side plane, +u runs toward the snout on the +X side
        cu, cv = face.uv(at(0.66, s, 0.32), fr)
        # Chase: a fierce yellow slit eye under a dark brow bar
        g = face.g('Chase')
        face.plate(g, place(FIERCE, cu, cv, sm, 0.0, 1.3 * 1.22, 0.78 * 1.3), 'eyedark', 1, fr)
        face.plate(face.g('Chase', 'eyes'), place(FIERCE, cu, cv, sm, 0.0, 1.3, 0.78), 'iris', 2, fr)
        face.plate(g, place(SLIT, cu, cv, sm, 0.0, 0.9, 0.7, dx=-0.08 * 1.3), 'pupil', 3, fr)
        face.plate(g, place([(-0.5, -0.5), (0.5, -0.3), (0.5, 0.3), (-0.5, 0.5)], cu, cv + 0.62, sm, 0.32, 1.5, 0.3), 'brow', 2, fr)
        # Asleep: a closed-eye line
        pts = [(-0.5 + i / 4, -0.16 * (1 - 4 * (-0.5 + i / 4) ** 2)) for i in range(5)]
        face.polyline(face.g('Asleep'), place(pts, cu, cv, sm, 0.0, 1.2, 1.0), 0.18, 'lash', 2, fr)
    fc = face.g('Chase')                                                        # Chase: the open mouth and two fangs
    cbox(fc, at(0.88, 0, -1), (1.9, 0.3, 1.1), 'mouthin', bevel=0.2)
    for s in (-1, 1):
        p = at(0.97, s * 0.55, -1)
        beam(fc, p + Vector((0, 0.15, 0)), p + Vector((0, -0.75, -0.05)), 0.26, 0.26, 'tooth', top=0.15)
    jaw = k.g('Jaw')                                                            # the golden lower jaw and the tongue
    joint(jaw, (0, 1.0, -2.6), 1.4, 'gold2')
    beam(jaw, (0, 0.45, -3.0), (0, 0.45, -7.6), 4.4, 0.75, 'gold', side=(1, 0, 0), top=(0.5, 1.0), bevel=0.15)
    beam(jaw, (0, 0.72, -7.4), (0, 0.66, -8.6), 0.4, 0.14, 'tongue', side=(1, 0, 0))
    for s in (-1, 1):
        beam(jaw, (0, 0.66, -8.5), (s * 0.32, 0.62, -9.05), 0.22, 0.12, 'tongue', side=(1, 0, 0), ext=0.05)
    sleep_z(k, (1.8, 5.6, -5.0), 1.8)
    return k


# =========================================================================================== Stage 3: Ice Fang (Snow)
def ice_fang():
    """Rev 5: a snow fox, improved. A clean fox head held up on a neck: a compact cranium, a tapered pointed white
    snout, big triangular ears with blue tips, white cheek ruffs, almond eyes with a dark eyeliner flick, a sapphire on
    the brow, sabre fangs. A fox body: a deep chest with a white ruff, a slim waist, round haunches, blue-grey socks,
    big paws with ice claws, and a huge bushy tail with a white tip and ice crystals. Icy white and blue, a few bold
    blue bands, the silver-and-sapphire collar, saddle and shoulder plates."""
    k = KeeperModel('ice_fang', 'Ice Fang', 3, {
        'fur': (0.94, 0.96, 1.0), 'fur2': (0.70, 0.79, 0.93), 'mark': (0.10, 0.36, 0.88), 'mark2': (0.30, 0.66, 1.0),
        'muzzle': (1.0, 1.0, 1.0), 'nose': (0.06, 0.10, 0.30), 'inner': (0.50, 0.72, 1.0), 'silver': (0.58, 0.63, 0.74),
        'sapphire': (0.10, 0.26, 0.86), 'ice': (0.45, 0.85, 1.0), 'claw': (0.35, 0.75, 1.0), 'brow': (0.03, 0.14, 0.48),
        'eyedark': (0.03, 0.06, 0.18), 'lash': (0.04, 0.10, 0.32)},
        eye_rgb=(0.15, 0.85, 1.0))
    k.personality = 'Proud, cold snow fox: head high, sly icy glare, bares its sabres the moment it sees you.'
    k.fidget = 'Licks a paw, swivels its big ears, sweeps the huge crystal-tipped tail around its feet.'
    k.fx_notes = 'Frost aura and snowflake sparkles (ParticleEmitter); icy breath puff on the snarl; ice glint on the tail crystals.'
    body = k.g('Body')
    cbox(body, (0, 2.9, -1.7), (5.4, 5.2, 5.2), 'fur', bevel=0.12)                 # deep chest  y 0.3..5.5, z -4.3..0.9
    cbox(body, (0, 3.3, 4.0), (4.4, 3.4, 7.6), 'fur', bevel=0.12)                  # slim waist  y 1.6..5.0
    cbox(body, (0, 3.0, 9.4), (5.2, 4.6, 4.6), 'fur', bevel=0.12)                  # haunches    y 0.7..5.3, z 7.1..11.7
    cbox(body, (0, 2.6, -4.55), (4.6, 3.8, 1.0), 'muzzle', bevel=0.2)              # white chest ruff
    for s in (-1, 0, 1):
        beam(body, (s * 1.3, 1.4, -4.7), (s * 1.1, -0.1, -4.5), 1.5, 0.8, 'muzzle', top=0.15, side=(1, 0, 0))   # ruff points
    for z, w in ((3.2, 0.9), (5.4, 0.9), (9.0, 1.0)):                               # a few bold blue bands over the back
        cbox(body, (0, 0, 0), (w, 0.2, 4.6 if z < 7 else 5.4), 'mark', bevel=0.2, M=T(0, 5.0 if z < 7 else 5.3, z) @ Ry(math.pi / 2))
        for s in (-1, 1):
            box(body, (s * (2.22 if z < 7 else 2.62), 4.1 if z < 7 else 4.3, z), (0.12, 1.6, w), 'mark')
    cbox(body, (0, 5.1, 2.5), (3.4, 0.45, 2.4), 'silver', bevel=0.2)               # saddle plate with a sapphire
    cbox(body, (0, 5.45, 2.5), (0.9, 0.7, 0.9), 'sapphire', bevel=0.2, M=Ry(math.pi / 4))
    cbox(body, (0, 4.6, -4.35), (4.4, 0.6, 1.0), 'silver', bevel=0.2)              # collar with three sapphires
    for x in (-1.3, 0.0, 1.3):
        cbox(body, (x, 4.6, -4.9), (0.55, 0.55, 0.3), 'sapphire', bevel=0.2, M=Rz(math.pi / 4))
    crystal(body, (0, 5.2, 7.6), (0, 1, 0.4), 0.45, 1.3, 'ice', sides=4)
    # Head: a neck held up, a compact cranium, a tapered snout, big ears, cheek ruffs ----------------------------------
    head = k.g('Head')
    joint(head, (0, 2.4, -3.7), 2.6, 'fur')
    beam(head, (0, 2.6, -3.5), (0, 4.4, -5.6), 3.0, 2.8, 'fur', side=(1, 0, 0), ext=0.5)      # the neck, rising forward
    cbox(head, (0, 2.9, -6.6), (3.0, 1.6, 2.6), 'muzzle', bevel=0.2)                          # white throat (holds the jaw)
    cbox(head, (0, 4.8, -6.6), (4.2, 3.4, 3.2), 'fur', bevel=0.12)                            # cranium y 3.1..6.5, face z -8.2
    sa, sb = Vector((0, 3.85, -8.0)), Vector((0, 3.5, -10.9))
    beam(head, sa, sb, 2.5, 1.6, 'muzzle', side=(1, 0, 0), top=(0.42, 0.6), bevel=0.15)       # tapered pointed snout
    cbox(head, (0, 3.72, -10.95), (0.9, 0.66, 0.55), 'nose', bevel=0.25)
    for s in (-1, 1):
        beam(head, (s * 1.8, 3.8, -7.3), (s * 3.2, 3.1, -6.0), 1.6, 1.0, 'muzzle', top=0.12)     # cheek ruffs
        beam(head, (s * 1.35, 6.1, -6.3), (s * 1.95, 9.2, -5.9), 2.0, 0.8, 'fur', top=0.06)      # big triangular ears
        beam(head, (s * 1.36, 6.4, -6.72), (s * 1.88, 8.5, -6.3), 1.1, 0.2, 'inner', top=0.06)
        beam(head, (s * 1.82, 8.4, -5.95), (s * 1.95, 9.22, -5.9), 0.95, 0.85, 'mark', top=0.06)  # blue ear tips
        beam(head, (s * 0.72, 3.2, -9.7), (s * 0.78, 1.9, -9.9), 0.36, 0.36, 'tooth', top=0.15)  # sabre fangs
    crystal(head, (0, 6.3, -7.6), (0, 1, -0.5), 0.35, 0.9, 'sapphire', sides=4)               # the brow sapphire
    face = FlatFace(k, 'Head', {'face': dict(c=(0, 4.8, -8.2), n=(0, 0, -1))}, unit=0.065)
    main = k.g('Head')
    face.plate(main, [(0, 1.05), (0.24, 1.3), (0, 1.58), (-0.24, 1.3)], 'mark', 0)            # small forehead diamond
    for s in (-1, 1):
        face.bar(main, (s * 1.62, 0.62), (s * 2.0, 0.92), 0.2, 'brow')                          # eyeliner flicks
    # Chase: almond icy eyes with slit pupils under a slanted lid line, small teeth under the snout
    face.eye('Chase', 1.0, 0.45, 1.4, 0.72, shape=ALMOND, pupil=SLIT, pupil_w=0.85)
    face.brow('Chase', 0.95, 1.0, 1.3, 0.24, slant=0.4)
    fc = face.g('Chase')
    for s in (-1, 1):
        for t in (0.2, 0.5):
            p = lerp(sa, sb, t)
            hw = 1.25 * (1 - 0.58 * t)
            hh = 0.8 * (1 - 0.4 * t)
            beam(fc, (s * (hw - 0.12), p.y - hh + 0.12, p.z), (s * (hw - 0.12), p.y - hh - 0.3, p.z), 0.24, 0.24, 'tooth', top=0.15)
    # Asleep: closed eyes, a relaxed lid line
    face.closed_eye('Asleep', 1.0, 0.4, 1.25, width=0.18, curve=0.16)
    jaw = k.g('Jaw')
    joint(jaw, (0, 2.0, -7.1), 1.3, 'muzzle')
    cbox(jaw, (0, 2.5, -7.4), (1.8, 1.2, 1.4), 'muzzle', bevel=0.2)                          # hinge block
    beam(jaw, (0, 2.85, -7.6), (0, 2.95, -10.4), 1.9, 0.8, 'muzzle', side=(1, 0, 0), top=(0.6, 0.8))
    def leg(group, x, front):
        s = 1 if x > 0 else -1
        g = k.g(group)
        if front:
            z0 = -2.5
            joint(g, (x, 2.3, z0), 2.2, 'fur')
            cbox(g, (x, 0.9, z0 - 0.1), (2.2, 3.6, 2.6), 'fur', bevel=0.12)                   # y -0.9..2.7
            cbox(g, (x, -2.1, z0 - 0.2), (1.8, 2.8, 2.0), 'fur2', bevel=0.12)                 # blue-grey sock
            cbox(g, (x + s * 0.35, 2.3, z0 - 0.1), (2.6, 1.4, 3.0), 'silver', bevel=0.2)      # shoulder plate
            cbox(g, (x + s * 1.66, 2.3, z0 - 0.1), (0.3, 0.7, 0.7), 'sapphire', bevel=0.2, M=Rx(math.pi / 4))
            pz = z0 - 0.7
        else:
            z0 = 10.0
            joint(g, (x, 1.85, z0), 2.4, 'fur')
            cbox(g, (x, 1.2, z0 - 0.1), (2.6, 3.6, 3.6), 'fur', bevel=0.12)                   # round thigh y -0.6..3.0
            beam(g, (x, -0.3, z0 + 0.6), (x, -3.1, z0 - 0.1), 1.8, 2.0, 'fur2', ext=0.3)      # sock, angled at the hock
            pz = z0 - 0.7
        cbox(g, (x, -3.55, pz), (2.4, 0.9, 3.0), 'muzzle', bevel=0.15)                         # big paw
        for dx in (-0.7, 0.0, 0.7):
            beam(g, (x + dx, -3.6, pz - 1.3), (x + dx * 1.1, -3.95, pz - 2.1), 0.4, 0.4, 'claw', top=0.2)
    leg('LeftFrontLeg', -2.15, True)
    leg('RightFrontLeg', 2.15, True)
    leg('LeftBackLeg', -2.2, False)
    leg('RightBackLeg', 2.2, False)
    tail = k.g('Tail')                                                                         # a huge bushy fox tail
    joint(tail, (0, 1.7, 11.65), 2.2, 'fur')
    tp = [Vector(p) for p in ((0, 2.6, 11.3), (0.4, 3.6, 13.8), (1.2, 4.6, 16.4), (2.2, 5.0, 19.0), (3.0, 4.8, 21.2))]
    for i, (a, b, sz) in enumerate(zip(tp, tp[1:], (2.0, 3.0, 3.6, 3.0))):
        beam(tail, a, b, sz, sz * 1.1, 'muzzle' if i == 3 else 'fur', side=(0, 1, 0), ext=0.5)
        if i == 2:
            beam(tail, lerp(a, b, 0.62), lerp(a, b, 0.82), sz * 1.05, sz * 1.15, 'mark', side=(0, 1, 0))
    for (d, h) in (((0.3, 0.5, 1), 1.6), ((0.8, 0.0, 1), 1.3), ((-0.2, 0.2, 1), 1.2), ((0.3, -0.4, 1), 1.0)):
        crystal(tail, tp[-1] + Vector((0, 0, -0.3)), d, 0.45, h, 'ice', sides=4)
    sleep_z(k, (2.0, 10.2, -8.0), 1.9)
    return k


# =========================================================================================== Stage 4: Lava Dragon (Lava)
def lava_dragon():
    """A cuboid dragon in the style of the 'Ice and Fire' fire dragon, after the owner's two reference images, built as
    our own geometry: a low chunky block body, a long stepped-block neck, a long square snout with an open jaw of
    block teeth, a crown of swept bone horns and frill spikes, a continuous row of bone spikes from the neck to the
    tail tip, sturdy legs with stubby toe blocks, and huge wings: a thick arm beam and a fan of long rectangular finger
    struts with stepped membrane panels and claw tips. Lava colouring: charcoal and dark red scale bands, an orange
    belly, glowing lava seams, a yellow eye, flaming back spikes (effect)."""
    k = KeeperModel('lava_dragon', 'Lava Dragon', 4, {
        'plate': (0.17, 0.16, 0.19), 'plate2': (0.44, 0.10, 0.07), 'plate3': (0.26, 0.24, 0.28), 'belly': (0.98, 0.62, 0.18),
        'bone': (0.88, 0.79, 0.60), 'strut': (0.13, 0.12, 0.14), 'wingm': (0.30, 0.11, 0.09), 'wingm2': (0.40, 0.15, 0.11),
        'brow': (0.05, 0.04, 0.05), 'nostril': (0.05, 0.03, 0.03), 'eyedark': (0.04, 0.02, 0.02), 'lash': (0.06, 0.04, 0.04),
        'smoke': (0.45, 0.42, 0.44), 'flame': (1.0, 0.55, 0.08), 'flamein': (1.0, 0.36, 0.05), 'tooth': (1.0, 0.97, 0.90)},
        glow={'*': (1.0, 0.45, 0.06)}, eye_rgb=(1.0, 0.80, 0.12))
    k.personality = 'Hot-headed and furious: glares, snarls fire, snorts smoke even in its sleep.'
    k.fidget = 'Snorts two smoke puffs, stomps a front foot, stretches the wing fans, the back flames flare up.'
    k.fx_notes = 'Flames on the back spikes and the tail tip, embers, nostril smoke (ParticleEmitter); fire glow in the open jaw.'
    body = k.g('Body')
    cbox(body, (0, 2.0, 1.8), (6.0, 4.4, 14.4), 'plate', bevel=0.12)            # rev 5: a longer torso  y -0.2..4.2, z -5.4..9.0
    cbox(body, (0, 2.5, -3.8), (5.8, 4.8, 3.2), 'plate', bevel=0.12)            # chest  y 0.1..4.9, z -5.4..-2.2
    cbox(body, (0, 2.2, 7.6), (5.6, 4.2, 3.0), 'plate', bevel=0.12)             # hips over the tail root
    bglow = k.g('Body', 'glow')
    for z in (-2.6, 0.4, 3.4, 6.4):                                              # dark red scale bands, lava seams at their edges
        cbox(body, (0, 2.0, z), (6.16, 4.56, 1.1), 'plate2', bevel=0.12)
        for dz in (-0.62, 0.62):
            box(bglow, (0, 4.25, z + dz), (5.2, 0.14, 0.16), 'iris')
            for s in (-1, 1):
                box(bglow, (s * 3.03, 2.0, z + dz), (0.14, 3.4, 0.16), 'iris')
    box(bglow, (0, 4.27, 1.8), (0.45, 0.14, 13.6), 'iris')                     # the seam along the spine
    for z in (-4.6, -3.0, -1.4, 0.2, 1.8, 3.4, 5.0, 6.6, 8.2):                 # orange belly plates
        cbox(body, (0, -0.3, z), (4.2, 0.45, 1.4), 'belly', bevel=0.2)
    fx = k.g('Body', 'fx')
    for i, z in enumerate((-4.6, -3.4, -2.2, -1.0, 0.2, 1.4, 2.6, 3.8, 5.0, 6.2, 7.4, 8.6)):   # bone back spikes, some flaming
        hgt = 1.9 if i % 2 == 0 else 1.5
        top_y = (4.8 if z < -2.2 else 4.1)
        beam(body, (0, top_y - 0.3, z), (0, top_y + hgt, z + 0.9), 0.35, 1.0, 'bone', side=(1, 0, 0), top=0.12)
        if i in (1, 3, 5, 7, 9, 11):
            flame(fx, (0, top_y + hgt, z + 0.9), (0, 1, 0.3), 1.6, 0.8, seed=i)
    # Head: a long stepped neck, a block skull, a long square snout, a crown of swept horns and frills ------------------
    head = k.g('Head')
    joint(head, (0, 3.3, -3.9), 2.6, 'plate')
    for i, (c, sz) in enumerate((((0, 4.4, -4.8), (3.4, 3.2, 2.8)), ((0, 5.7, -6.4), (3.0, 3.0, 2.6)), ((0, 6.9, -7.8), (2.8, 2.8, 2.4)))):
        cbox(head, c, sz, 'plate2' if i == 1 else 'plate', bevel=0.12)
        cbox(head, (c[0], c[1] - sz[1] / 2 + 0.15, c[2] - 0.1), (sz[0] * 0.7, 0.45, sz[2] * 0.9), 'belly', bevel=0.2)
        beam(head, (0, c[1] + sz[1] / 2 - 0.3, c[2] + 0.2), (0, c[1] + sz[1] / 2 + 1.2, c[2] + 1.0), 0.32, 0.9, 'bone',
             side=(1, 0, 0), top=0.12)
    cbox(head, (0, 7.9, -9.7), (3.6, 3.2, 3.4), 'plate', bevel=0.12)           # skull: y 6.3..9.5, face plane z -11.4
    cbox(head, (0, 7.0, -12.55), (2.4, 1.6, 2.7), 'plate', bevel=0.12)         # snout: y 6.2..7.8, z -13.9..-11.2
    cbox(head, (0, 7.85, -12.4), (1.2, 0.3, 2.2), 'plate3', bevel=0.2)
    for s in (-1, 1):
        box(head, (s * 0.55, 7.82, -13.55), (0.4, 0.1, 0.35), 'nostril')
        for z in (-13.55, -12.85, -12.15, -11.45):
            cbox(head, (s * 0.95, 6.05, z), (0.28, 0.42, 0.28), 'tooth', bevel=0.2)
        cbox(head, (s * 1.0, 9.35, -11.5), (1.9, 0.5, 0.75), 'plate3', bevel=0.2, M=Rz(s * 0.3))       # brow ridge
        beam(head, (s * 1.4, 9.35, -11.0), (s * 1.9, 10.4, -10.2), 0.32, 0.32, 'bone', top=0.15)       # brow spike
        Mh = beam(head, (s * 1.2, 9.2, -9.0), (s * 1.6, 10.9, -7.0), 0.75, 0.75, 'bone', top=0.6, ext=0.2)   # swept horns
        beam(head, (s * 1.6, 10.9, -7.0), (s * 2.0, 11.7, -5.0), 0.45, 0.45, 'bone', top=0.2, ext=0.15)
        beam(head, (s * 1.7, 7.4, -9.9), (s * 3.0, 8.0, -8.0), 0.25, 0.8, 'plate2', top=0.12, side=(0, 1, 0))  # cheek frills
        beam(head, (s * 1.75, 8.4, -9.5), (s * 2.9, 9.7, -7.7), 0.3, 0.7, 'bone', top=0.12, side=(0, 1, 0))
    beam(head, (0, 9.3, -10.4), (0, 10.8, -9.0), 0.3, 0.9, 'bone', side=(1, 0, 0), top=0.12)
    beam(head, (0, 9.3, -9.0), (0, 11.3, -7.6), 0.3, 0.9, 'bone', side=(1, 0, 0), top=0.12)
    hglow = k.g('Head', 'glow')
    for s in (-1, 1):
        box(hglow, (s * 1.81, 7.3, -9.7), (0.12, 0.14, 2.6), 'iris')           # lava seam along the jaw line
    face = FlatFace(k, 'Head', {'face': dict(c=(0, 7.9, -11.4), n=(0, 0, -1))}, unit=0.06)
    smoke_fx = k.g('Head', 'fx', 'Smoke')
    mirror(lambda s: [blob(smoke_fx, (s * (0.6 + 0.4 * i), 8.0 + 0.3 * i, -14.0 - 0.6 * i), (0.2 + 0.07 * i,) * 3, 'smoke', seg=8, rings=5)
                      for i in range(3)])
    # Chase: furious yellow slit-pupil eyes; the open jaw glows fire-orange between the teeth
    face.eye('Chase', 1.12, 0.72, 1.05, 0.68, shape=FIERCE, pupil=SLIT, pupil_w=0.8)
    cbox(face.g('Chase'), (0, 6.0, -12.4), (2.0, 0.42, 3.0), 'flamein', bevel=0.2)
    # Asleep: grumpy closed eyes; smoke puffs (fx)
    face.closed_eye('Asleep', 1.12, 0.66, 1.0, width=0.2, curve=0.08, slant=0.18, col='flamein')   # ember lids: readable on charcoal
    jaw = k.g('Jaw')
    joint(jaw, (0, 5.5, -7.6), 1.6, 'plate')
    cbox(jaw, (0, 5.3, -10.6), (2.2, 1.1, 6.2), 'plate3', bevel=0.12)         # y 4.75..5.85, z -13.7..-7.5
    box(jaw, (0, 4.72, -10.6), (1.6, 0.12, 5.4), 'belly')
    for s in (-1, 1):
        for z in (-13.25, -12.45, -11.75):
            cbox(jaw, (s * 0.8, 5.95, z), (0.26, 0.35, 0.26), 'tooth', bevel=0.2)
    # Legs: sturdy blocks, scale bands, stubby bone toe blocks --------------------------------------------------------
    def leg(group, s, front):
        g = k.g(group)
        if front:
            joint(g, (s * 2.8, 2.0, -2.7), 2.3, 'plate')
            cbox(g, (s * 3.1, 0.4, -2.8), (2.2, 3.4, 2.6), 'plate', bevel=0.12)
            cbox(g, (s * 3.1, 0.9, -2.8), (2.3, 0.7, 2.7), 'plate2', bevel=0.12)
            cbox(g, (s * 3.1, -2.3, -3.1), (1.9, 2.6, 2.1), 'plate', bevel=0.12)
            fz, tz = -3.6, -5.15
        else:
            joint(g, (s * 2.8, 1.5, 4.55), 2.4, 'plate')
            cbox(g, (s * 3.15, 1.2, 4.6), (2.6, 3.6, 3.4), 'plate', bevel=0.12)
            cbox(g, (s * 3.15, 1.6, 4.6), (2.7, 0.8, 3.5), 'plate2', bevel=0.12)
            cbox(g, (s * 3.2, -1.9, 5.0), (2.0, 3.0, 2.2), 'plate', bevel=0.12)
            fz, tz = 4.4, 2.65
        x = s * (3.1 if front else 3.2)
        cbox(g, (x, -3.6, fz), (2.4, 0.8, 2.6 if front else 3.0), 'plate3', bevel=0.15)
        for dx in (-0.75, 0.0, 0.75):
            cbox(g, (x + dx, -3.62, tz), (0.55, 0.65, 0.8), 'bone', bevel=0.2)
        lg = k.g(group, 'glow')
        box(lg, (x + s * (1.11 if front else 1.36), 0.9 if front else 1.6, -2.8 if front else 4.6), (0.12, 0.2, 2.2), 'iris')
    leg('LeftFrontLeg', -1, True)
    leg('RightFrontLeg', 1, True)
    leg('LeftBackLeg', -1, False)
    leg('RightBackLeg', 1, False)
    # Tail: long tapering block segments in alternating scale bands, bone spikes, a glowing spade tip -----------------
    tail = k.g('Tail')
    joint(tail, (0, 0.5, 6.55), 2.6, 'plate')
    beam(tail, (0, 0.6, 6.55), (0, 1.6, 8.6), 2.8, 3.0, 'plate')                 # tail root, inside the body at rest
    tp = [Vector(p) for p in ((0, 1.6, 8.6), (0.2, 1.2, 11.8), (0.9, 0.8, 14.8), (2.0, 0.7, 17.6), (3.2, 0.8, 20.2), (4.2, 1.0, 22.4))]
    sizes = [(3.0, 3.4), (2.6, 2.9), (2.1, 2.4), (1.7, 1.9), (1.3, 1.4)]
    for i, (a, b, (hh, ww)) in enumerate(zip(tp, tp[1:], sizes)):
        Mt = beam(tail, a, b, hh, ww, 'plate' if i % 2 == 0 else 'plate2', side=(0, 1, 0), ext=0.35, top=0.85)
        L = (b - a).length
        beam(tail, (Mt @ Vector((hh / 2 - 0.2, 0, 0, 1))).xyz, (Mt @ Vector((hh / 2 + 1.3 - 0.18 * i, L * 0.3, 0, 1))).xyz,
             0.3, 0.85, 'bone', side=(1, 0, 0), top=0.12)
        cbox(tail, (0, 0, 0), (0.3, L * 0.8, ww * 0.6), 'belly', bevel=0.2, M=Mt @ T(-hh / 2 + 0.05, 0, 0))
    tglow = k.g('Tail', 'glow')
    d = (tp[-1] - tp[-2]).normalized()
    tip = tp[-1] + d * 0.6
    cbox(tglow, (0, 0, 0), (1.8, 0.35, 1.8), 'iris', bevel=0.2, M=T(tip) @ Ry(math.atan2(d.x, d.z) + math.pi / 4))
    flame(k.g('Tail', 'fx'), tip + Vector((0, 0.2, 0)), (0.2, 1, 0.5), 2.2, 1.1, seed=9)
    # Wings: a thick arm beam, a fan of five finger struts from the wrist, stepped membranes, bone claw tips -----------
    for s, group in ((-1, 'LeftWing'), (1, 'RightWing')):
        g = k.g(group)
        pv = Vector((s * 2.84, 4.19, -1.3))
        sh, el, wr = Vector((s * 2.9, 4.7, -1.1)), Vector((s * 7.3, 9.0, 0.3)), Vector((s * 10.4, 10.6, 1.0))
        tips = [Vector((s * x, y, z)) for x, y, z in ((13.0, 9.4, 2.4), (12.6, 7.4, 4.6), (11.2, 5.6, 6.6), (9.2, 4.4, 8.0), (6.6, 3.9, 8.3))]
        root = Vector((s * 3.1, 4.3, 4.6))
        beam(g, sh, el, 1.0, 1.0, 'strut', ext=0.4)
        beam(g, el, wr, 0.9, 0.9, 'strut', ext=0.4)
        beam(g, wr, wr + Vector((s * 0.2, 1.1, -0.7)), 0.38, 0.38, 'bone', top=0.15, ext=0.1)            # thumb claw
        for tp_ in tips:
            beam(g, wr, tp_, 0.42, 0.42, 'strut', ext=0.2)
            cbox(g, tp_ + (tp_ - wr).normalized() * 0.3, (0.5, 0.5, 0.5), 'bone', bevel=0.2)
        for i in range(len(tips) - 1):
            a, b = tips[i], tips[i + 1]
            notch = wr + ((a + b) / 2 - wr) * 0.84
            membrane(g, [wr, a, notch, b], 0.16, 'wingm' if i % 2 == 0 else 'wingm2')
        membrane(g, [sh, el, wr, tips[-1], (tips[-1] + root) / 2 + Vector((0, 0.3, -0.4)), root], 0.16, 'wingm2')
        g.v = [pv + (p - pv) * 1.35 for p in g.v]    # the game's V110 x1.35 wing scale, baked in
        joint(g, pv, 2.2, 'strut')                    # shoulder core at the hinge, overlapping the body
    sleep_z(k, (2.2, 13.4, -10.0), 2.2)
    return k


# =========================================================================================== Stage 5: Crystal Knight (Crystal)
def crystal_knight():
    """A BULKY knight after the owner's reference (an R6-proportioned armoured knight): huge stacked pauldrons, ribbed
    arms, a great helm with a crest ridge and a wing plume, a layered chest with a centre ridge, a heavy belt, thick
    legs. Crystal theme: purple / lavender armour, crystal medallions where the reference has skulls, glowing visor
    eyes (fierce slants awake, dim lines asleep), a crystal blade."""
    k = KeeperModel('crystal_knight', 'Crystal Knight', 5, {
        'armor': (0.40, 0.34, 0.58), 'armor2': (0.62, 0.55, 0.84), 'armor3': (0.21, 0.17, 0.33), 'under': (0.17, 0.12, 0.27),
        'trim': (0.82, 0.78, 0.96), 'gold': (0.92, 0.70, 0.18), 'crystal': (0.62, 0.30, 1.0), 'crystal2': (0.85, 0.62, 1.0),
        'grip': (0.14, 0.09, 0.24), 'recess': (0.03, 0.02, 0.07), 'blade': (0.78, 0.66, 1.0), 'plume': (0.72, 0.42, 1.0)},
        glow={'*': (0.74, 0.52, 1.0)}, eye_rgb=(0.85, 0.75, 1.0))
    k.personality = 'Stern, merciless sentinel: plants his feet, sword ready, two burning slits in a closed great helm.'
    k.fidget = 'Rolls his huge shoulders, taps the sword hilt twice, turns the helm left and right like a guard on patrol.'
    k.fx_notes = 'Crystal sparkle aura, a slash trail on the sword (Trail), crystal shards bursting on impact.'
    k.state_eyes = True
    body = k.g('Body')
    cbox(body, (0, 15.6, -0.2), (12.6, 8.0, 8.0), 'armor', bevel=0.1)         # chest  y 11.6..19.6, front z -4.2
    for s in (-1, 1):
        cbox(body, (s * 2.75, 16.7, -4.45), (5.0, 4.6, 0.7), 'armor2', bevel=0.15, M=Ry(s * 0.12))   # layered chest plates
        cbox(body, (s * 2.9, 13.4, -4.35), (4.6, 1.8, 0.6), 'armor2', bevel=0.15)
    cbox(body, (0, 15.6, -4.5), (1.1, 7.2, 1.1), 'armor3', bevel=0.2, M=Ry(math.pi / 4))        # centre ridge
    bglow = k.g('Body', 'glow')
    crystal(bglow, (0, 18.9, -4.95), (0, 1, -0.25), 0.6, 1.5, 'iris', sides=4)
    cbox(body, (0, 20.0, -0.2), (6.4, 1.8, 6.0), 'armor3', bevel=0.15)          # thick gorget
    cbox(body, (0, 10.6, 0.0), (10.6, 2.6, 7.0), 'armor3', bevel=0.12)         # abdomen
    cbox(body, (0, 9.4, -0.1), (11.8, 1.8, 7.8), 'under', bevel=0.15)          # heavy belt
    cbox(body, (0, 9.4, -4.05), (2.4, 2.0, 0.5), 'gold', bevel=0.2)
    cbox(body, (0, 9.4, -4.4), (1.0, 1.0, 0.4), 'crystal', bevel=0.2, M=Rz(math.pi / 4))
    cbox(body, (0, 6.2, 0.0), (7.2, 3.6, 4.8), 'under', bevel=0.15)            # hip core (the legs' pivots sit in it)
    for s in (-1, 1):
        cbox(body, (s * 2.7, 7.2, -3.85), (4.6, 3.0, 0.8), 'armor', bevel=0.12, M=Rx(0.1))        # tassets
        cbox(body, (s * 2.7, 6.9, -4.35), (1.9, 1.9, 0.4), 'trim', bevel=0.2)                       # crystal medallions
        cbox(body, (s * 2.7, 6.9, -4.6), (1.0, 1.0, 0.45), 'crystal', bevel=0.2, M=Rz(math.pi / 4))
        cbox(body, (s * 5.75, 7.4, -0.2), (0.8, 2.8, 5.6), 'armor', bevel=0.12)
    cbox(body, (0, 7.4, 3.75), (9.4, 2.8, 0.8), 'armor', bevel=0.12)
    # Head: a closed great helm with a crest ridge, a crystal crest and a wing plume ---------------------------------
    head = k.g('Head')
    cbox(head, (0, 23.7, -0.4), (6.8, 6.8, 6.8), 'armor', bevel=0.1)          # y 20.3..27.1, front z -3.8
    cbox(head, (0, 23.2, -3.95), (5.8, 5.0, 0.5), 'armor2', bevel=0.15)        # face plate, plane z -4.2
    cbox(head, (0, 24.1, -4.25), (4.9, 1.0, 0.3), 'recess', bevel=0.2)         # visor slit
    cbox(head, (0, 22.6, -4.35), (0.8, 2.6, 0.5), 'armor', bevel=0.2)          # vertical nose bar
    for i in range(3):
        for s in (-1, 1):
            box(head, (s * (1.2 + 0.55 * i), 21.6, -4.22), (0.32, 0.32, 0.1), 'recess')        # breathing holes
    cbox(head, (0, 25.95, -3.95), (7.0, 0.7, 0.9), 'trim', bevel=0.2)          # brow band
    cbox(head, (0, 27.6, -0.4), (0.9, 1.4, 7.4), 'armor2', bevel=0.2)          # crest ridge over the top
    cbox(head, (0, 26.4, -4.05), (0.9, 2.4, 0.9), 'armor2', bevel=0.2)         # ... running down the front
    for s in (-1, 1):
        cbox(head, (s * 3.55, 22.4, -1.4), (0.7, 3.8, 4.4), 'armor2', bevel=0.15)   # cheek guards
    for z, h in ((-2.4, 2.4), (-0.8, 3.2), (0.8, 2.8), (2.2, 2.0)):
        crystal(head, (0, 28.0, z), (0, 1, 0.35), 0.5, h, 'crystal', sides=4)
    cbox(head, (3.65, 25.6, 0.6), (0.8, 1.4, 1.4), 'trim', bevel=0.2)          # the wing plume on the left side
    for i, tp_ in enumerate(((5.0, 30.4, 2.6), (5.9, 29.6, 3.4), (6.5, 28.4, 4.0), (6.8, 27.0, 4.4), (6.6, 25.7, 4.6))):
        beam(head, (3.7, 25.6, 0.6), tp_, 0.95, 0.24, 'plume' if i % 2 == 0 else 'crystal2', top=0.3, ext=0.1, side=(0, 0, 1))
    k.state_rgb = {'Chase': ((1.0, 0.42, 0.95), 4.0), 'Asleep': ((0.40, 0.32, 0.62), 0.5)}
    for s in (-1, 1):
        box(k.g('Head', 'eyes', 'Chase'), (s * 1.25, 24.1, -4.42), (1.7, 0.42, 0.2), 'iris', M=Rz(s * 0.22))   # fierce slants
        box(k.g('Head', 'eyes', 'Asleep'), (s * 1.25, 23.95, -4.4), (1.5, 0.14, 0.2), 'iris')                  # dim lines
    # Arms: huge stacked pauldrons, ribbed upper arms with a crystal medallion, chunky gauntlets ------------------------
    for s, arm, fore in ((1, 'LeftArm', 'LeftForearm'), (-1, 'RightArm', 'RightForearm')):
        g = k.g(arm)
        joint(g, (s * 8.0, 18.0, 0), 3.8, 'armor3')
        cbox(g, (s * 9.2, 20.0, 0), (5.4, 4.0, 6.6), 'armor3', bevel=0.12)
        for j, (dx, y, w, d, ang, col) in enumerate(((0.0, 21.5, 6.8, 7.8, 0.20, 'armor'), (0.6, 20.2, 6.6, 7.6, 0.30, 'armor2'),
                                                       (1.2, 18.9, 5.8, 7.2, 0.40, 'armor'))):
            cbox(g, (s * (9.4 + dx), y, 0), (w, 1.5, d), col, bevel=0.12, M=Rz(-s * ang))
        crystal(g, (s * 8.8, 22.0, -0.8), (s * 0.2, 1, 0), 0.6, 2.4, 'crystal', sides=4)
        crystal(g, (s * 10.4, 21.6, 1.2), (s * 0.5, 1, 0.1), 0.5, 2.0, 'crystal', sides=4)
        cbox(g, (s * 9.1, 14.4, -0.3), (3.8, 7.4, 4.0), 'armor3', bevel=0.12)
        for y in (16.6, 15.4, 14.2, 13.0):
            cbox(g, (s * 9.1, y, -0.3), (4.4, 0.7, 4.6), 'armor2', bevel=0.15)
        cbox(g, (s * 11.3, 14.6, -0.3), (0.5, 2.0, 2.0), 'trim', bevel=0.2)
        cbox(g, (s * 11.6, 14.6, -0.3), (0.5, 1.2, 1.2), 'crystal', bevel=0.2, M=Rx(math.pi / 4))
        f = k.g(fore)
        joint(f, (s * 9.1, 9.9, -0.6), 3.8, 'armor3')
        cbox(f, (s * 9.1, 6.8, -1.3), (4.8, 5.4, 4.8), 'armor2', bevel=0.12)
        for y in (8.4, 7.0):
            cbox(f, (s * 9.1, y, -1.3), (5.2, 0.6, 5.2), 'armor', bevel=0.15)
        cbox(f, (s * 9.1, 4.4, -1.5), (5.4, 1.0, 5.4), 'trim', bevel=0.15)
        cbox(f, (s * 9.1, 2.6, -2.0), (4.2, 3.0, 4.4), 'armor', bevel=0.12)
        cbox(f, (s * 9.1, 2.9, -4.3), (3.6, 1.6, 0.6), 'armor3', bevel=0.2)
        crystal(f, (s * 11.4, 7.0, -1.3), (s, 0.4, 0), 0.5, 1.6, 'crystal', sides=4)
    # Legs: thick thighs with crystal medallions, knee plates, greaves, big boots, a wide stance ---------------------
    for s, leg in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(leg)
        joint(g, (s * 3.25, 4.68, 0), 3.4, 'armor3')
        cbox(g, (s * 3.4, 5.6, -0.2), (5.0, 5.0, 5.2), 'armor', bevel=0.12)
        cbox(g, (s * 3.4, 4.4, -2.95), (1.9, 1.9, 0.5), 'trim', bevel=0.2)
        cbox(g, (s * 3.4, 4.4, -3.25), (1.0, 1.0, 0.5), 'crystal', bevel=0.2, M=Rz(math.pi / 4))
        cbox(g, (s * 3.4, 2.6, -2.6), (4.2, 2.0, 1.0), 'armor2', bevel=0.15)
        crystal(g, (s * 3.4, 2.6, -3.0), (0, 0.3, -1), 0.5, 1.0, 'crystal', sides=4)
        cbox(g, (s * 3.5, -0.2, -0.4), (4.8, 4.4, 5.0), 'armor2', bevel=0.12)
        cbox(g, (s * 3.5, 0.6, -0.4), (5.2, 0.6, 5.4), 'armor', bevel=0.15)
        cbox(g, (s * 3.6, -3.1, -1.1), (5.4, 1.8, 7.2), 'armor', bevel=0.12)
    # Rev 5: a real knight's longsword (not a dagger): a long straight double-edged blade, longer than his leg, with a
    # short point; a wide crossguard with down-turned crystal quillons; a wrapped grip; a gold pommel with a crystal.
    sw = k.g('Sword')
    cbox(sw, (-9.1, 1.9, -2.8), (0.9, 4.2, 0.9), 'grip', bevel=0.2)                # grip   y -0.2..4.0
    for y in (0.5, 1.5, 2.5, 3.4):
        cbox(sw, (-9.1, y, -2.8), (1.02, 0.28, 1.02), 'under', bevel=0.25)        # leather wraps
    cbox(sw, (-9.1, 4.45, -2.8), (1.6, 1.2, 1.6), 'gold', bevel=0.3)               # pommel
    cbox(sw, (-9.1, 4.45, -3.62), (0.7, 0.7, 0.2), 'crystal', bevel=0.2, M=Rz(math.pi / 4))
    cbox(sw, (-9.1, -0.45, -2.8), (7.0, 0.9, 1.4), 'gold', bevel=0.2)              # crossguard y -0.9..0.0
    for s in (-1, 1):
        beam(sw, (-9.1 + s * 3.2, -0.45, -2.8), (-9.1 + s * 3.75, -1.6, -2.8), 0.85, 1.2, 'gold', side=(0, 0, 1), ext=0.2)   # quillons
        cbox(sw, (-9.1 + s * 3.8, -1.85, -2.8), (0.8, 0.8, 0.8), 'crystal', bevel=0.2, M=Rz(math.pi / 4))
    cbox(sw, (-9.1, -1.25, -2.8), (2.5, 0.7, 0.9), 'gold', bevel=0.2)              # blade collar
    # The blade in two parts: Sword reaches exactly as far as today's sword (y -9.9), so hits are unchanged; the
    # longer part, Sword_Point, is cosmetic (KeeperContact skips it, like the face parts).
    cbox(sw, (-9.1, -5.45, -2.8), (2.1, 8.9, 0.55), 'blade', bevel=0.2)            # straight blade  y -9.9..-1.0
    pt = k.g('Sword', 'main', 'Point')
    cbox(pt, (-9.1, -11.95, -2.8), (2.1, 4.3, 0.55), 'blade', bevel=0.2)           # y -14.1..-9.8
    cbox(pt, (-9.1, -15.05, -2.8), (2.1, 2.0, 0.55), 'blade', bevel=0.2, bottom=(0.06, 0.5))   # the point  y -16.05..-14.05
    for s in (-1, 1):
        box(sw, (-9.1 + s * 0.9, -5.5, -2.8), (0.3, 8.6, 0.6), 'trim')             # two bright edges: double-edged
        box(pt, (-9.1 + s * 0.9, -11.9, -2.8), (0.3, 4.2, 0.6), 'trim')
    cbox(k.g('Sword', 'glow'), (-9.1, -5.55, -2.8), (0.55, 8.5, 0.65), 'iris', bevel=0.2)         # glowing crystal fuller
    cbox(k.g('Sword', 'glow', 'Point'), (-9.1, -11.3, -2.8), (0.55, 3.2, 0.65), 'iris', bevel=0.2)
    k.cosmetic |= {('Sword', 'Point')}
    sleep_z(k, (3.8, 32.5, -2.5), 3.0)
    return k


# =========================================================================================== Stage 7: Storm Colossus (Storm)
def storm_colossus():
    """Rev 5: TODAY's in-game Storm Colossus, improved. Today's native parts (KeeperUpgradeData) are rebuilt at their
    exact size, rest frame and colour as crisp bevelled blocks and wedges: the dark slate core and chest mantle with
    the lightning bolt, the floating tilted shoulder rocks with their V-shaped thunder prongs, the floating heavy fists
    with glowing bands, the glowing charged joints between, the suspended shins with charged knees and wedge feet, and
    today's storm-cloud crown floating over the head (block clouds). Improvements: a clean block head (today's
    forward-sloping top kept as a crest) with a dark visor, two glowing slits and a glowing crack; storm-glow veins on
    the chest; charged hip cores over the knees; knuckle and toe blocks. Floating by design: the shoulder rocks,
    fists, charged joints, the suspended legs and the cloud crown (as today), linked by lightning."""
    k = KeeperModel('storm_colossus', 'Storm Colossus', 7, {
        'slate': (0.18, 0.20, 0.26), 'slate2': (0.26, 0.29, 0.38), 'slate3': (0.36, 0.40, 0.50), 'prong': (0.60, 0.65, 0.75),
        'visor': (0.08, 0.09, 0.13), 'cloud': (0.27, 0.30, 0.36), 'cloud2': (0.32, 0.35, 0.42), 'cloud3': (0.24, 0.26, 0.32),
        'eyedark': (0.02, 0.03, 0.06), 'eyedim': (0.18, 0.24, 0.32), 'bolt': (0.72, 0.87, 1.0)},
        glow={'*': (0.72, 0.87, 1.0)}, eye_rgb=(0.72, 0.87, 1.0))
    k.personality = 'A walking storm of slate: no face, only two burning slits and a crackling jaw; fists, shoulders and legs hang on storm power under its own thundercloud.'
    k.fidget = 'Punches its floating fists together (sparks), cracks its neck, the cloud crown rumbles and flickers.'
    k.fx_notes = 'Lightning arcs linking every floating piece to the body (Beams), crackling sparks, flashes inside the cloud crown, rain under it.'
    for p in native(7):
        n, grp = p['Name'], p['Group']
        if n in ('Head', 'Lightning eye'):
            continue                                                       # the head and eyes are rebuilt (below)
        if grp == 'Body':
            if n == 'Lightning core':
                nat(k.g('Body', 'glow'), p, 'iris')
            else:
                nat(k.g('Body'), p, 'slate' if n == 'Obsidian core' else 'slate2')
        elif grp in ('LeftArm', 'RightArm'):
            if n in ('Charged joint', 'Fist band'):
                nat(k.g(grp, 'glow'), p, 'iris')
            elif n == 'Heavy fist':
                nat(k.g(grp, 'main', 'Fist'), p, 'slate')
            else:
                nat(k.g(grp, 'main', 'Rock'), p, 'prong' if n == 'Thunder prong' else 'slate2')
        elif grp in ('LeftLeg', 'RightLeg'):
            if n == 'Charged knee':
                nat(k.g(grp, 'glow'), p, 'iris')
            else:
                nat(k.g(grp), p, 'slate2' if n == 'Suspended shin' else 'slate')
        elif n == 'Face shadow':
            nat(k.g('Head'), p, 'visor')
    for s, arm in ((1, 'LeftArm'), (-1, 'RightArm')):
        k.floating |= {(arm, 'Rock'), (arm, 'Fist'), (arm, 'Glow')}
    for leg in ('LeftLeg', 'RightLeg'):
        k.floating |= {(leg, None), (leg, 'Glow')}
    k.floating |= {('Head', 'Cloud')}
    # Body: storm-glow veins branching off today's lightning bolt; charged hip cores over the knees ------------------
    bglow = k.g('Body', 'glow')
    band(bglow, [(0.6, 21.4, -4.62), (2.0, 22.2, -4.62), (3.4, 21.5, -4.62), (4.6, 22.4, -4.62)], (0, 0, -1), 0.26, 0.16, 'iris')
    band(bglow, [(-0.9, 15.2, -4.62), (-2.4, 14.4, -4.62), (-3.6, 15.1, -4.62), (-5.0, 14.2, -4.62)], (0, 0, -1), 0.26, 0.16, 'iris')
    band(bglow, [(-0.8, 19.6, -4.62), (-2.0, 19.0, -4.62), (-2.8, 19.8, -4.62)], (0, 0, -1), 0.22, 0.16, 'iris')
    for s in (-1, 1):
        cbox(bglow, (s * 3.9, 10.7, 0.0), (1.5, 1.5, 1.5), 'iris', bevel=0.2, M=Ry(math.pi / 4))
    # Head: a block head with today's forward-sloping top as a crest, today's face shadow as a dark visor ------------
    head = k.g('Head')
    joint(head, (0, 23.54, 0), 3.6, 'slate')
    cbox(head, (0, 26.0, 0.0), (9.35, 6.1, 7.82), 'slate2', bevel=0.1)            # y 22.95..29.05, front z -3.91
    box(head, (0, 29.9, 0.4), (9.35, 1.8, 7.0), 'slate2', wedge=True)              # today's sloped top, as a crest
    cbox(head, (0, 28.55, -4.05), (8.7, 0.9, 1.0), 'slate3', bevel=0.15)          # rock brow ledge over the visor
    cbox(head, (0, 23.7, -4.0), (6.0, 1.2, 0.8), 'slate3', bevel=0.15)            # a heavy chin
    for s in (-1, 1):
        cbox(head, (s * 4.75, 26.2, -1.0), (0.5, 4.0, 4.4), 'slate3', bevel=0.15)   # cheek plates
    face = FlatFace(k, 'Head', {'face': dict(c=(0, 27.04, -4.25), n=(0, 0, -1))}, unit=0.08)   # the visor front
    for s in (-1, 1):
        face.plate(face.g('Chase', 'eyes'), place(SLOT, s * 2.05, 0.3, s, 0.0, 2.9, 0.78), 'iris', 1)
        face.plate(face.g('Asleep'), place(SQUARE, s * 2.05, 0.1, s, 0.0, 2.5, 0.18), 'eyedim', 1)
    face.line('Chase', [(-2.6, -0.75), (-1.73, -1.12), (-0.87, -0.75), (0.0, -1.14), (0.87, -0.75), (1.73, -1.12), (2.6, -0.75)], 0.3,
              col='iris', kind='eyes')
    # Today's storm-cloud crown, floating over the head: chunky cloud blocks where today's five cloud balls are --------
    cloud = k.g('Head', 'main', 'Cloud')
    for (x, y, z, sx, sy, sz, c) in ((-4.99, 32.58, 0.97, 8.6, 4.6, 7.6, 'cloud'), (5.09, 32.96, -0.62, 8.0, 4.4, 7.2, 'cloud2'),
                                     (-0.3, 34.44, 0.06, 10.0, 5.4, 8.8, 'cloud3'), (-2.23, 32.57, -3.07, 6.4, 3.6, 5.6, 'cloud2'),
                                     (2.74, 32.38, 3.41, 6.8, 3.6, 6.0, 'cloud')):
        cbox(cloud, (x, y + 0.8, z), (sx * 0.86, sy * 0.8, sz * 0.86), c, bevel=0.3)     # floats clear of the crest
    hfx = k.g('Head', 'fx')                                                       # storm flashes in the cloud (effect)
    bolt(hfx, (-5.6, 29.2, 2.0), (-5.0, 30.6, 1.6), 0.14, seed=11)
    bolt(hfx, (5.4, 29.6, 1.4), (5.0, 31.0, 1.0), 0.14, seed=12)
    # Arms: knuckle blocks on today's heavy fists ----------------------------------------------------------------------
    fx = k.g('Body', 'fx')
    for s, arm in ((1, 'LeftArm'), (-1, 'RightArm')):
        fist = k.g(arm, 'main', 'Fist')
        for dx in (-2.7, -0.9, 0.9, 2.7):
            cbox(fist, (s * 12.65 + dx, 7.6 - 0.14 * dx * s, -6.25), (1.6, 2.0, 0.9), 'slate3', bevel=0.2)
        afx = k.g(arm, 'fx')
        bolt(afx, (s * 8.0, 20.0, 0.0), (s * 8.9, 20.6, 0.2), 0.16, seed=1 + s)
        bolt(afx, (s * 12.4, 16.8, -0.5), (s * 12.0, 18.4, -0.3), 0.16, seed=3 + s)
        bolt(afx, (s * 12.4, 13.9, -0.6), (s * 12.5, 14.7, -0.6), 0.16, seed=5 + s)
    # Legs: toe blocks on today's wedge feet, a slate plate on each shin; lightning from the hip cores to the knees ----
    for s, leg in ((1, 'LeftLeg'), (-1, 'RightLeg')):
        g = k.g(leg)
        for dx in (-2.4, 0.0, 2.4):
            cbox(g, (s * 3.98 + dx, -2.75, -6.45), (1.7, 0.9, 1.3), 'slate3', bevel=0.2)
        lfx = k.g(leg, 'fx')
        bolt(lfx, (s * 3.9, 9.9, 0.0), (s * 3.91, 8.7, 0.0), 0.16, seed=7 + s)
    sleep_z(k, (6.0, 38.5, -2.0), 3.2)
    return k


# =========================================================================================== The Darkened (Void event keeper)
def wisp(g, base, direction, length, width, seed=0):
    """Void wisp stand-in (a ParticleEmitter in game): two thin curling purple tongues."""
    import random
    rnd = random.Random(seed)
    d = Vector(direction).normalized()
    for i in range(2):
        off = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.3), rnd.uniform(-1, 1))) * width * 0.5
        side = Vector((rnd.uniform(-1, 1), 0, rnd.uniform(-1, 1))) * length * 0.25
        p0 = Vector(base) + off
        tube(g, [p0, p0 + d * length * 0.5 + side, p0 + d * length + side * 0.2], [width * 0.35, width * 0.22, 0.0], 'wisp',
             seg=5, cap0='round', cap1='point', smooth=True)


def the_darkened():
    """Today's design, polished: the slim faceless black head with its one glowing line, crisp chamfered blocks where
    today has plain blocks, angular cores instead of today's ball joints, metal ribs, a glowing chest slit, plus a
    tattered cloak, long claws and void wisps. Group-local geometry (each group is placed at its frame; parts at
    frame * VeiledFrame), at today's part positions and inside today's part sizes, so the hit boxes are unchanged; the
    cloak, claws and ankle cores are cosmetic (never used for hits). Its two 'faces' are the line: bright awake, dim
    asleep."""
    k = KeeperModel('the_darkened', 'The Darkened', 0, {
        'black': (0.035, 0.035, 0.05), 'black2': (0.075, 0.07, 0.10), 'cloth': (0.09, 0.07, 0.13), 'cloth2': (0.16, 0.10, 0.24),
        'metal': (0.62, 0.52, 0.30), 'claw': (0.82, 0.80, 0.92), 'mark': (0.30, 0.10, 0.48), 'recess': (0.01, 0.0, 0.02),
        'wisp': (0.55, 0.22, 0.95)},
        glow={'*': (0.80, 0.42, 1.0)}, eye_rgb=(0.88, 0.45, 1.0), floor=-5.0, local=True)
    k.personality = "Silent and wrong: today's faceless black head and its one glowing line; it never speaks, it tilts its head and stares."
    k.fidget = 'A slow head tilt; the line flickers; long claws drum the air; the cloak tatters drift.'
    k.fx_notes = 'Void-purple wisps from the cloak hem, hands and feet (ParticleEmitter); the line pulses (a slow brightness tween) and leaves a faint trail while chasing.'
    k.state_eyes = True
    k.state_rgb = {'Chase': ((0.90, 0.45, 1.0), 5.0), 'Asleep': ((0.30, 0.14, 0.42), 0.6)}
    # Torso: today's broad chest as a crisp block, angular pauldrons for today's ball shoulders, metal ribs, the core slit
    t = k.g('Torso')
    cbox(t, (0, 0, 0), (5.5, 3.5, 2.4), 'cloth', bevel=0.3, bottom=(0.86, 1.0))
    for s in (-1, 1):
        cbox(t, (s * 2.65, 0.95, 0), (1.7, 1.7, 1.9), 'cloth2', bevel=0.35, top=0.8)
        shards(t, (s * 3.0, 1.6, 0.0), (s * 0.7, 1, 0.1), 1.0, 0.7, 'cloth2', n=2, spread=0.3, seed=310 + s, sink=0.5)
        for rib in (1, 2, 3):
            box(t, (s * 1.25, 1.25 - rib * 0.7, -1.18), (2.1, 0.14, 0.16), 'metal', M=Rz(s * 0.13))
    membrane(t, [(0, 1.5, -1.19), (0.22, 0.0, -1.19), (0, -1.5, -1.19), (-0.22, 0.0, -1.19)], 0.1, 'recess')
    tg = k.g('Torso', 'glow')
    membrane(tg, [(0, 1.38, -1.21), (0.1, 0.0, -1.21), (0, -1.38, -1.21), (-0.1, 0.0, -1.21)], 0.12, 'iris')
    cloak = k.g('Torso', 'main', 'Cloak')                       # tattered cloak hanging from the shoulders (cosmetic)
    for i, x in enumerate((-2.9, -1.75, -0.6, 0.6, 1.75, 2.9)):
        ln = 8.2 + (1.4 if i % 2 else 0.0) - abs(x) * 0.3
        sp = 1.0 + abs(x) * 0.12
        z = 2.1 + 0.08 * ln
        membrane(cloak, [(x * 0.9 - 0.7, 1.7, 1.0), (x * 0.9 + 0.7, 1.7, 1.0), (x * sp + 0.7, 1.7 - ln + 0.6, z),
                         (x * sp + 0.35, 1.7 - ln - 0.5, z + 0.05), (x * sp, 1.7 - ln + 0.2, z), (x * sp - 0.3, 1.7 - ln - 1.2, z + 0.05),
                         (x * sp - 0.7, 1.7 - ln + 0.4, z)], 0.14, 'cloth2' if i % 2 else 'cloth')
    for s in (-1, 1):
        cbox(cloak, (s * 2.55, 1.75, 0.35), (2.2, 0.9, 2.3), 'cloth2', bevel=0.3)
    for i, x in enumerate((-2.4, -1.2, 1.2, 2.4)):
        shards(cloak, (x, 1.9, 0.6), (x * 0.4, 1, 0.3), 1.4, 0.8, 'cloth2', n=2, seed=300 + i)            # tattered collar
    fx = k.g('Torso', 'fx', 'Wisp')
    for i, x in enumerate((-2.6, -0.6, 1.5, 3.0)):
        wisp(fx, (x, -7.0 + (0.8 if i % 2 else 0.0), 2.7), (x * 0.05, 1, 0.3), 1.6, 0.45, seed=400 + i)
    k.cosmetic |= {('Torso', 'Cloak'), ('LHand', 'Claws'), ('RHand', 'Claws'), ('LFoot', 'Ankle'), ('RFoot', 'Ankle')}
    cbox(k.g('Waist'), (0, 0, 0), (2.35, 3.4, 1.65), 'cloth', bevel=0.3, top=1.0, bottom=0.92)
    h = k.g('Hip')
    cbox(h, (0, 0, 0), (2.7, 2.0, 1.8), 'black', bevel=0.3)
    for s in (-1, 1):
        cbox(h, (s * 0.95, -0.65, 0), (1.45, 1.45, 1.45), 'black', bevel=0.4)                           # hip cores
    cbox(k.g('Neck'), (0, 0, 0), (1.1, 1.4, 1.1), 'black', bevel=0.3, top=0.85)
    # Head: today's slim black head, crisper (bevelled edges, a narrower chin) with the one glowing line --------------
    hd = k.g('Head')
    cbox(hd, (0, 0, 0), (2.0, 3.0, 1.48), 'black', bevel=0.28, bottom=(0.8, 1.0))
    membrane(hd, [(0.02, 1.2, -0.735), (0.17, 0.0, -0.735), (0.02, -1.2, -0.735), (-0.13, 0.0, -0.735)], 0.08, 'recess')   # the cleft
    for s in (-1, 1):                                                                                     # subtle markings
        membrane(hd, [(s * 0.42, 1.38, -0.735), (s * 0.52, 1.38, -0.735), (s * 0.86, 0.72, -0.735), (s * 0.76, 0.72, -0.735)], 0.05, 'mark')
        membrane(hd, [(s * 1.0, 1.05, 0.25), (s * 1.0, 1.05, 0.38), (s * 1.0, -0.55, -0.05), (s * 1.0, -0.55, -0.18)], 0.05, 'mark')
    membrane(k.g('Head', 'eyes', 'Chase'), [(0.02, 1.08, -0.76), (0.1, 0.0, -0.76), (0.02, -1.08, -0.76), (-0.06, 0.0, -0.76)],
             0.08, 'iris')                                                                                  # awake: bright line
    membrane(k.g('Head', 'eyes', 'Asleep'), [(0.02, 0.95, -0.75), (0.05, 0.0, -0.75), (0.02, -0.95, -0.75), (-0.01, 0.0, -0.75)],
             0.06, 'iris')                                                                                  # asleep: thin, dim
    for q, s in (('L', -1), ('R', 1)):
        cbox(k.g(q + 'UpperArm'), (0, 0, 0), (1.25, 4.4, 1.35), 'cloth', bevel=0.3, bottom=0.88)
        fa = k.g(q + 'Forearm')
        cbox(fa, (0, 2.1, 0), (1.15, 1.15, 1.15), 'black', bevel=0.4)                                      # elbow core
        cbox(fa, (0, 0, 0), (1.05, 4.2, 1.15), 'black2', bevel=0.3, bottom=0.85)
        box(fa, (0, -1.7, 0), (1.17, 0.18, 1.27), 'metal')
        shards(fa, (s * 0.45, 0.6, 0.2), (s * 1, 0.3, 0.4), 0.9, 0.5, 'cloth2', n=2, spread=0.25, seed=330 + s, sink=0.55)
        hn = k.g(q + 'Hand')
        cbox(hn, (0, 0, 0), (1.3, 1.1, 0.85), 'black', bevel=0.35)
        cbox(hn, (0, 0.55, 0), (0.9, 0.6, 0.85), 'black', bevel=0.4)                                        # wrist core
        for i in (1, 2, 3):
            x = (i - 2) * 0.4
            cbox(hn, (x, -1.12, 0), (0.25, 1.55, 0.3), 'black2', bevel=0.4, M=Rx(-0.06) @ Rz((i - 2) * 0.035))
        claws = k.g(q + 'Hand', 'main', 'Claws')
        for i in (1, 2, 3):
            x = (i - 2) * 0.4
            horn(claws, (x * 1.02, -1.55, 0.0), (x * 1.12, -2.35, -0.12), (x * 1.22, -3.05, -0.6), 0.15, 'claw', seg=4, n=4)
        cbox(k.g(q + 'Thigh'), (0, 0, 0), (1.4, 4.0, 1.55), 'cloth', bevel=0.3, bottom=0.88)
        sh = k.g(q + 'Shin')
        cbox(sh, (0, 1.8, 0), (1.2, 1.2, 1.2), 'black', bevel=0.4)                                          # knee core
        cbox(sh, (0, 0, 0), (1.1, 3.6, 1.2), 'black2', bevel=0.3, bottom=0.85)
        spike(sh, (0, 1.75, -0.4), (0, 2.25, -1.25), 0.32, 'black', seg=4)                                 # knee spike
        cbox(k.g(q + 'Foot', 'main', 'Ankle'), (0, 0.35, 0.55), (1.0, 1.0, 1.0), 'black', bevel=0.4)      # cosmetic core
        ft = k.g(q + 'Foot')
        cbox(ft, (0, 0, 0.25), (1.4, 0.7, 2.1), 'black', bevel=0.35)
        spike(ft, (0, -0.05, -0.6), (0, -0.2, -1.35), 0.42, 'black', seg=4)                                # pointed toe
        fx = k.g(q + 'Foot', 'fx', 'Wisp')
        wisp(fx, (0, -0.3, 0.3), (0, 1, 0.2), 1.2, 0.45, seed=420 + s)
        fx = k.g(q + 'Hand', 'fx', 'Wisp')
        wisp(fx, (0, -1.2, 0), (0, -1, -0.3), 1.0, 0.35, seed=440 + s)
    sleep_z(k, (0.9, 2.6, -0.5), 1.1)
    # posture: creepy head tilt
    k.transform(['Head'], Rz(0.14))
    return k


BUILDERS = {1: timber_golem, 6: jungle_king, 2: sand_snake, 3: ice_fang, 4: lava_dragon, 5: crystal_knight, 7: storm_colossus,
            0: the_darkened}
ORDER = [1, 6, 2, 3, 4, 5, 7, 0]  # biome order: Forest, Jungle, Desert, Snow, Lava, Crystal, Storm, then The Darkened
BIOME = {1: 'Forest', 6: 'Jungle', 2: 'Desert', 3: 'Snow', 4: 'Lava', 5: 'Crystal', 7: 'Storm', 0: 'Void event'}
