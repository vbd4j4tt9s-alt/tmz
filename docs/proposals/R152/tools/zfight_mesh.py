"""R152 z-fighting inside baked meshes (the keepers): two triangles that face the same way, lie in (nearly) one plane, overlap, are both drawn and look different flicker.
Library for tests/check_keeper_zfight.py (the check) and blender/fix_zfight.py (the separation of the faces found), both reading keeper_zfight_dump.luau's output:
the game's own decoder (KeeperMeshes152.Decode) and pose code (BeastPose / VeiledKeeper81) on the Roblox mock.

The rules are the R149 detector's (docs/proposals/R149/tools/zfight.py): coplanar |offset| <= 0.002 studs, near <= 0.02, far < 4 steps of a 24-bit depth buffer at the distance the
overlap is seen from (0.02 .. 0.043; D = how far away it still covers ~8 px), `strict` (up to 0.002 x D) listed, not counted; overlaps under 0.02 stud^2 do not count.
A pair is only counted when both triangles are DRAWN (BeastAnimation / VeiledEventClient81: the Chase face + eyes awake, the Asleep face asleep, the golem's tree glow only awake),
look different (a different palette colour; look-alike triangles have the same vertex colours: nothing to flicker) and the overlap is SEEN: a few sample points of it, lifted 0.04 along
the normal, must have a clear line to some camera direction on the face's side (>= 0.3 of the normal, not below the ground, which is y = -4 in rig space where the keepers stand, and a
face that points down and is within CAMERA_GAP of the ground cannot be looked at), so an overlap buried in the body, a belly plate on the floor or a face hidden by a limb never counts.
Poses: 'bind' (every group frame the identity: the model as built), 'rest' (awake, standing) and 'asleep', each as the client poses the parts (the golem asleep: its tree rest and size)."""
import collections, itertools, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import zfight as Z  # noqa: E402

GROUND = -4.0                    # rig space: the keepers stand on y = -4 (BeastPose grounds the lowest floor sample there)
MIN_COS = 0.3                    # a camera direction must be at least this far toward the face's normal
_dirs = []
_phi = (1 + 5 ** .5) / 2
for _i in range(96):             # fibonacci sphere: camera directions
    _z = 1 - 2 * (_i + .5) / 96; _r = math.sqrt(1 - _z * _z); _a = 2 * math.pi * _i / _phi
    _dirs.append((_r * math.cos(_a), _z, _r * math.sin(_a)))
DIRS = np.array(_dirs)


def parse(path):
    keepers = collections.OrderedDict(); cur = None; part = None
    for line in open(path, encoding='utf-8').read().split('\n'):
        if line.startswith('KEEPER '):
            _, key, stage, name = line.split()
            cur = {'key': key, 'stage': int(stage), 'name': name, 'parts': [], 'frames': {'rest': {}, 'asleep': {}}, 'pal': []}
            keepers[key] = cur
        elif line.startswith('PAL '):
            cur['pal'] = [tuple(float(x) for x in c.split(',')) for c in line[4:].split()]
        elif line.startswith('PART '):
            head, tree, tsize, counts = line[5:].split('|')
            f = head.split()
            part = {'name': f[0], 'group': f[1], 'kind': f[2], 'face': None if f[3] == '-' else f[3], 'size': np.array([float(x) for x in f[4:7]]),
                    'tree': None if tree == '-' else np.array([float(x) for x in tree.split()]),
                    'tsize': None if tsize == '-' else np.array([float(x) for x in tsize.split()])}
            cur['parts'].append(part)
        elif line.startswith('V '):
            part['V'] = np.round(np.array([float(x) for x in line[2:].split()]).reshape(-1, 3) * 512) / 512      # (the data is on the 1/512 stud grid; the dump prints 5 decimals)
        elif line.startswith('T '):
            part['T'] = np.array([int(x) - 1 for x in line[2:].split()]).reshape(-1, 3)
        elif line.startswith('P '):
            part['P'] = None if line.strip() == 'P -' else np.array([int(x) for x in line[2:].split()])
        elif line.startswith('COLOR '):
            part['color'] = None if line.strip() == 'COLOR -' else tuple(float(x) for x in line[6:].split())
        elif line.startswith('FRAME '):
            _, key, state, group, *nums = line.split()
            n = [float(x) for x in nums]
            keepers[key]['frames'][state][group] = (np.array(n[0:3]), np.array(n[3:12]).reshape(3, 3))
    return list(keepers.values())


BIND = ('bind', 'bindsleep')     # the model as built (every group frame the identity), with the awake / the asleep face


def drawn(keeper, p, state):
    """BeastAnimation.faces / VeiledEventClient81: the face shown in this state (the golem's tree glow only awake)."""
    asleep = state in ('asleep', 'bindsleep')
    if p['face'] == 'Asleep' and not asleep: return False
    if p['face'] == 'Chase' and asleep: return False
    if keeper['stage'] == 1 and p['kind'] == 'glow' and asleep: return False
    return True


def world(keeper, p, state, V=None):
    V = p['V'] if V is None else V
    if state in BIND:
        return V
    fr = keeper['frames'][state][p['group']]
    if state == 'asleep' and p['tree'] is not None:      # the golem asleep: tree rest and size (UpgradePose.PartPose with awake = 0)
        c = (V.min(axis=0) + V.max(axis=0)) / 2
        c0 = (p['V'].min(axis=0) + p['V'].max(axis=0)) / 2
        sc = p['tsize'] / p['size']          # (config TreeSize = Size x this ratio: kept when the config is regenerated)
        t = p['tree']; R = t[3:12].reshape(3, 3)
        return (V - c) * sc @ R.T + t[0:3] + R @ (c - c0)   # (config TreeRest follows the part's centre: delta x Center)
    pos, R = fr
    return V @ R.T + pos


def colour_of(keeper, p, ti):
    if p['P'] is not None:
        return tuple(round(c * 255) for c in keeper['pal'][p['P'][ti]]) + ('plastic',)
    c = p['color'] or (1, 1, 1)
    return tuple(round(x * 255) for x in c) + ('neon',)


def _first_hit(o, d, tris):
    """Distance of the nearest crossing of the ray o + t d (t > 1e-4) with any triangle (rows of 3 points); inf when it crosses none."""
    a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
    e1, e2 = b - a, c - a
    h = np.cross(d, e2)
    det = (e1 * h).sum(axis=1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    s = o - a
    u = (s * h).sum(axis=1) * inv
    q = np.cross(s, e1)
    v = (q * d).sum(axis=1) * inv
    t = (e2 * q).sum(axis=1) * inv
    hit = ok & (u >= -1e-9) & (v >= -1e-9) & (u + v <= 1 + 1e-9) & (t > 1e-4)
    return float(t[hit].min()) if hit.any() else math.inf


CAMERA_NEAR = 4.0                # the line to the camera must be clear for at least this far (studs): nobody looks into a crevice a camera does not fit in
CAMERA_FAR = 100.0


def seen(point, n, tris, ground=True):
    """Can a camera see a point lifted just off a face with normal n? Some direction within MIN_COS of the normal along which a camera at least CAMERA_NEAR away (up to CAMERA_FAR,
    before the first triangle in the way) stands at least CAMERA_GAP above the ground (rig y = -4) with a clear line to the point."""
    ok = (DIRS @ n) >= MIN_COS
    if ground and point[1] < GROUND + 0.02:
        return False                           # under the ground
    for d in DIRS[ok]:
        reach = min(_first_hit(point, d, tris) - 0.05, CAMERA_FAR)
        if reach < CAMERA_NEAR:
            continue
        if ground:
            # the farthest camera spot along the ray that is still above the ground + the gap: down-going rays reach only so far
            y = point[1] + reach * d[1]
            if y < GROUND + Z.CAMERA_GAP:
                if d[1] >= 0:
                    continue
                reach = (point[1] - (GROUND + Z.CAMERA_GAP)) / -d[1]
                if reach < CAMERA_NEAR:
                    continue
        return True
    return False


def components(T, nv):
    """Vertex -> component root (triangles that share vertices: one box / one bevelled block of a generator)."""
    parent = list(range(nv))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    for a, b, c in T:
        ra = find(a)
        parent[find(b)] = ra
        parent[find(c)] = ra
    return [find(i) for i in range(nv)]


def _parity(pt, tris):
    """Odd = pt is inside the closed mesh `tris` (ray parity along an irrational direction)."""
    d = _PARITY_DIR
    a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
    e1, e2 = b - a, c - a
    h = np.cross(d, e2)
    det = (e1 * h).sum(axis=1)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    s = pt - a
    u = (s * h).sum(axis=1) * inv
    q = np.cross(s, e1)
    v = (q * d).sum(axis=1) * inv
    t = (e2 * q).sum(axis=1) * inv
    return int((ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 1e-9)).sum()) % 2 == 1


_PARITY_DIR = np.array([0.5773, 0.5771, 0.5779]); _PARITY_DIR = _PARITY_DIR / np.linalg.norm(_PARITY_DIR)


class Solids:
    """The closed pieces (components) of the drawn parts in world space: is a point inside one of them?"""

    def __init__(self, tri, comp):
        order = np.argsort(comp, kind='stable')
        self.tris = tri[order]
        c = comp[order]
        cuts = np.flatnonzero(np.diff(c)) + 1
        self.groups = np.split(np.arange(len(c)), cuts)
        self.lo = np.array([self.tris[g].min(axis=(0, 1)) for g in self.groups])
        self.hi = np.array([self.tris[g].max(axis=(0, 1)) for g in self.groups])

    def inside(self, pt):
        cand = np.flatnonzero(((self.lo <= pt) & (pt <= self.hi)).all(axis=1))
        for gi in cand:
            if _parity(pt, self.tris[self.groups[gi]]):
                return True
        return False


def analyse(keeper, state, V_by_part=None, max_offset=0.1, want_tris=False):
    """Findings of one keeper in one pose. V_by_part: {part index: vertices} replaces a part's geometry (the fixer's working copy)."""
    parts = []
    for i, p in enumerate(keeper['parts']):
        if drawn(keeper, p, state):
            parts.append((i, p))
    tri, owner, tidx, comp = [], [], [], []
    for pi, (i, p) in enumerate(parts):
        W = world(keeper, p, state, None if V_by_part is None else V_by_part.get(i))
        T = W[p['T']]
        if 'root' not in p:
            p['root'] = np.array(components(p['T'], len(p['V'])))
        tri.append(T); owner += [pi] * len(T); tidx += list(range(len(T)))
        comp += [pi * 100000 + int(p['root'][t[0]]) for t in p['T']]
    tri = np.concatenate(tri); owner = np.array(owner); tidx = np.array(tidx); comp = np.array(comp)
    e1, e2 = tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]
    nn = np.cross(e1, e2); m = np.linalg.norm(nn, axis=1)
    keep = m > 1e-9
    n = np.zeros_like(nn); n[keep] = nn[keep] / m[keep][:, None]
    d = (n * tri[:, 0]).sum(axis=1)
    lo, hi = tri.min(axis=1), tri.max(axis=1)
    N = len(tri)
    solids = Solids(tri[keep], comp[keep])
    pairs = []
    for i0 in range(0, N, 400):
        i1 = min(N, i0 + 400)
        dots = n[i0:i1] @ n.T
        dd = np.abs(d[None, :] - d[i0:i1, None])
        near = (dots > Z.NORMAL_DOT) & (dd <= max_offset)
        gi = np.arange(i0, i1)[:, None]; gj = np.arange(N)[None, :]
        near &= (gj > gi) & keep[None, :] & keep[i0:i1, None]
        ox = (lo[i0:i1, None, :] <= hi[None, :, :] + max_offset) & (lo[None, :, :] <= hi[i0:i1, None, :] + max_offset)
        near &= ox.all(axis=2)
        for a, b in zip(*np.nonzero(near)):
            pairs.append((i0 + a, int(b)))
    findings = []
    for i, j in pairs:
        pa, pb = parts[owner[i]], parts[owner[j]]
        ca, cb = colour_of(keeper, pa[1], tidx[i]), colour_of(keeper, pb[1], tidx[j])
        if ca == cb:
            continue                           # the same palette colour: the same vertex colours, nothing to flicker
        nrm = n[i]
        u, v = Z.basis(tuple(nrm))
        A = [(float(np.dot(q, u)), float(np.dot(q, v))) for q in tri[i]]
        B = [(float(np.dot(q, u)), float(np.dot(q, v))) for q in tri[j]]
        poly = Z.intersect(A, B)
        if len(poly) < 3: continue
        area = abs(Z.area2(poly))
        if area < Z.MIN_AREA: continue
        off = float(d[j] - d[i]); a_ = abs(off)
        far = Z.far_threshold(poly); strict = Z.strict_threshold(poly)
        if a_ <= Z.COPLANAR: tier = 'coplanar'
        elif a_ <= Z.NEAR: tier = 'near'
        elif a_ < far: tier = 'far'
        elif a_ < strict: tier = 'strict'
        else: continue
        front = max(d[i], d[j]) + Z.SAMPLE_LIFT
        vis = tot = 0
        samples = Z.samples(poly, 3)
        for (x, y) in samples:
            tot += 1
            w = np.array(u) * x + np.array(v) * y + nrm * front
            if not solids.inside(w) and seen(w, nrm, tri[keep], state not in BIND):
                vis += 1
        if vis == 0: continue
        cx = np.mean([p[0] for p in poly]); cy = np.mean([p[1] for p in poly])
        f = {'keeper': keeper['name'], 'state': state, 'tier': tier, 'offset': round(off, 4), 'area': round(area * vis / tot, 3),
             'a': pa[1]['name'], 'b': pb[1]['name'], 'inside': bool(owner[i] == owner[j]), 'visible': round(vis / tot, 2),
             'limit': round(far, 4), 'colA': ca, 'colB': cb, 'normal': [round(float(c), 3) for c in nrm],
             'at': [round(float(c), 2) for c in (np.array(u) * cx + np.array(v) * cy + nrm * d[i])]}
        if want_tris:
            f['partA'], f['triA'], f['partB'], f['triB'] = parts[owner[i]][0], int(tidx[i]), parts[owner[j]][0], int(tidx[j])
            f['nWorld'] = [float(c) for c in nrm]
        findings.append(f)
    return findings, len(parts), int(keep.sum())
