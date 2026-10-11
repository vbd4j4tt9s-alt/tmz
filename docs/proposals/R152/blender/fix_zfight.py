"""R152 z-fighting inside the baked keepers: separates the faces that lie in one plane.

Two triangles of a keeper that face the same way, lie in (nearly) one plane, overlap, look different and are both drawn flicker (z-fighting). The Blender generators stack
bevelled boxes on each other (a leaf cube on a hood step, a bright edge strip on a blade, a glow slit on a plate) and some faces landed exactly in the plane of their neighbour.
This pass moves ONE of the two pieces (a piece = the triangles that share vertices: one box / one bevelled block, nothing else) out along the face's normal until the planes are
at least the detector's depth-buffer-safe gap apart (tests/check_keeper_zfight.py, tools/zfight_mesh.py: the R149 rules, 0.02 stud for small overlaps up to 0.043 at 300 studs;
this pass aims at 0.03 - 0.05). Which piece moves is fixed by rule, so the result is deterministic: an overlay (glow, eyes, face) before a main part, then the piece with the
smaller box, then the later part, then the later triangle. A moved piece keeps its shape (a rigid slide of 0.01 - 0.05 stud): looks stay the same to the eye.

Usage: python3 fix_zfight.py data REPO DUMP [--dry]
  fixes the committed KeeperMeshData152*.lua and KeeperRigConfig152.lua in place; DUMP = tests/keeper_zfight_dump.luau's output for them. run.sh runs it right after
  encode_meshes.py (Blender's output is the same every time, so the moves are too); --dry only lists the moves.
The pass is idempotent: on data with nothing left to fix it changes nothing. It iterates (each round re-checks the rest and asleep poses of every keeper) until the check is
clean, at most 6 rounds. Before it touches anything it checks that its own encoder reproduces every committed module byte for byte and that its config formulas reproduce
KeeperRigConfig152 (Center / Size of every part, the golem's TreeRest / TreeSize, Bounds, Mouth) from the committed vertices.
After the geometry changed, those config fields are rewritten with encode_meshes.py's formulas (a part's box changes by at most the slide itself)."""
import base64, collections, json, math, os, re, sys, zlib
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import zfight_mesh as M  # noqa: E402
Z = M.Z

STEP = 1 / 512
FILES = {'Stage1': 'Golem', 'Stage6': 'JungleKing', 'Stage2': 'SandSnake', 'Stage3': 'IceFang', 'Stage4': 'LavaDragon', 'Stage5': 'CrystalKnight',
         'Stage7': 'StormColossus', 'Darkened': 'Darkened'}
GAP_MIN = 0.03           # the least separation aimed at (the detector's small-overlap limit is 0.02)
GAP_FACTOR = 1.25        # ... or this much over the overlap's own limit (up to 0.043 for a big overlap)
OVERLAY = ('glow', 'eyes', 'face')
POSES = ('rest', 'asleep')     # what a player sees a keeper still in (the bind pose shows overlaps a pose hides: belly plates on the floor)


def components(T, nv):
    """Vertex -> component root (triangles that share vertices)."""
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


def quantize(v):
    return np.round(v / STEP) * STEP


class Work:
    """One keeper's geometry being fixed: the vertices by part (a working copy), the components, the moves made."""

    def __init__(self, keeper):
        self.k = keeper
        self.V = {i: p['V'].copy() for i, p in enumerate(keeper['parts'])}
        self.root = {i: np.array(components(p['T'], len(p['V']))) for i, p in enumerate(keeper['parts'])}
        self.moves = []

    def comp_of_tri(self, part, tri):
        return int(self.root[part][self.k['parts'][part]['T'][tri][0]])

    def comp_verts(self, part, comp):
        return np.nonzero(self.root[part] == comp)[0]

    def comp_stats(self, part, comp):
        idx = self.comp_verts(part, comp)
        P = self.V[part][idx]
        tris = int(np.count_nonzero(self.root[part][self.k['parts'][part]['T'][:, 0]] == comp))
        return tris, float(np.prod(np.maximum(P.max(axis=0) - P.min(axis=0), 1e-6)))

    def rank(self, part, comp):
        p = self.k['parts'][part]
        tris, vol = self.comp_stats(part, comp)
        return (0 if p['kind'] in OVERLAY else 1, round(vol, 4), -part, -comp)

    def normal_rig(self, part, tri):
        p = self.k['parts'][part]
        a, b, c = self.V[part][p['T'][tri]]
        n = np.cross(b - a, c - a)
        return n / np.linalg.norm(n)

    def slide(self, part, comp, n, dist, why):
        idx = self.comp_verts(part, comp)
        self.V[part][idx] = quantize(self.V[part][idx] + n * dist)
        self.moves.append({'keeper': self.k['name'], 'key': self.k['key'], 'part': self.k['parts'][part]['name'], 'piece': int(idx.min()), 'triangles': self.comp_stats(part, comp)[0],
                           'by': [round(float(c), 4) for c in n * dist], 'why': why})


def required_gap(f):
    """The separation a finding needs (studs): 0.03, or GAP_FACTOR x the overlap's own depth-buffer limit."""
    lim = max(Z.NEAR, f.get('limit', Z.NEAR))
    return max(GAP_MIN, round(lim * GAP_FACTOR, 3))


def round_of_fixes(w):
    """One look at every pose; returns how many pieces moved."""
    k = w.k
    todo = {}
    for state in POSES:
        fs, _, _ = M.analyse(k, state, V_by_part=w.V, want_tris=True)
        for f in fs:
            if f['tier'] not in Z.COUNTED:
                continue
            key = (f['partA'], w.comp_of_tri(f['partA'], f['triA']), f['partB'], w.comp_of_tri(f['partB'], f['triB']))
            todo.setdefault(key, []).append((state, f))
    moved = 0
    touched = set()
    for (pa, ca, pb, cb), lst in sorted(todo.items()):
        # both pieces are the same piece: nothing to slide apart (does not happen for boxes)
        if (pa, ca) == (pb, cb):
            continue
        # a piece that already moved this round (for another pair) is not moved again: the next round looks at the rest with the new places
        if (pa, ca) in touched or (pb, cb) in touched:
            continue
        mover, other = ((pa, ca), (pb, cb)) if w.rank(pa, ca) < w.rank(pb, cb) else ((pb, cb), (pa, ca))
        mover_is_a = mover == (pa, ca)
        # the finding with the biggest need decides the slide
        best = None
        for state, f in lst:
            need = required_gap(f)
            # signed distance of the mover's plane in front of the other's, along the outward normal (world offsets are rigid except the golem's tree scale)
            front = (-f['offset']) if mover_is_a else f['offset']
            extra = need - front
            if best is None or extra > best[0]:
                best = (extra, f)
        extra, f = best
        if extra <= 0:
            continue
        need = required_gap(f)
        front = (-f['offset']) if mover_is_a else f['offset']
        if w.k['parts'][mover[0]]['kind'] not in OVERLAY:
            back = -(need + front)                 # a main piece may also sink behind the other one: the shorter slide wins
            if abs(back) < extra:
                extra = back
        extra = math.copysign(math.ceil(abs(extra) / STEP - 1e-9) * STEP, extra)    # (whole 1/512 steps: the data is quantized)
        ti = f['triA'] if mover_is_a else f['triB']
        n = w.normal_rig(mover[0], ti)
        w.slide(mover[0], mover[1], n, extra, '%s %s: %s <-> %s, off %+.4f' % (f['state'], f['tier'], f['a'], f['b'], f['offset']))
        touched.add(mover); touched.add(other)
        moved += 1
    return moved


def fix_keeper(keeper, rounds=6):
    w = Work(keeper)
    for r in range(rounds):
        if round_of_fixes(w) == 0:
            break
    else:
        left = sum(len([f for f in M.analyse(keeper, s, V_by_part=w.V)[0] if f['tier'] in Z.COUNTED]) for s in POSES)
        if left:
            raise SystemExit('%s: %d findings left after %d rounds' % (keeper['name'], left, rounds))
    return w


# ---- data modules -------------------------------------------------------------------------------------------------------------------------------
def zz(n):
    return (n << 1) if n >= 0 else ((-n << 1) - 1)


def varint(out, n):
    assert n >= 0
    while n >= 128:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)


def encode_stream(keeper, V):
    """The stream encode_meshes.py writes (see its header), from the (fixed) vertices; returns the raw bytes."""
    out = bytearray([1])
    varint(out, len(keeper['parts']))
    for i, p in enumerate(keeper['parts']):
        q = np.round(V[i] / STEP).astype(np.int64)
        varint(out, len(q)); varint(out, len(p['T'])); varint(out, 1 if p['P'] is not None else 0)
        for axis in range(3):
            prev = 0
            for v in q[:, axis]:
                varint(out, zz(int(v) - prev)); prev = int(v)
        prev = 0
        for t in p['T']:
            for ix in t:
                varint(out, zz(int(ix) - prev)); prev = int(ix)
        if p['P'] is not None:
            P, j = p['P'], 0
            while j < len(P):
                e = j
                while e < len(P) and P[e] == P[j]:
                    e += 1
                varint(out, int(P[j])); varint(out, e - j)
                j = e
    return bytes(out)


def write_module(path, raw):
    src = open(path, encoding='utf-8').read()
    c = zlib.compressobj(9, zlib.DEFLATED, -15, 9)
    comp = c.compress(raw) + c.flush()
    assert zlib.decompress(comp, -15) == raw
    b64 = base64.b64encode(comp).decode()
    chunks = [b64[i:i + 1000] for i in range(0, len(b64), 1000)]
    src = re.sub(r'Bytes=\d+,Adler=\d+', 'Bytes=%d,Adler=%d' % (len(raw), zlib.adler32(raw)), src, count=1)
    head = src[:src.index(' Data={')]
    src = head + ' Data={\n' + ',\n'.join("'%s'" % ch for ch in chunks) + '\n}}\n'
    open(path, 'w', encoding='utf-8').write(src)
    return len(src.encode())


def module_raw(path):
    src = open(path, encoding='utf-8').read()
    comp = base64.b64decode(''.join(re.findall(r"'([A-Za-z0-9+/=]+)'", src[src.index(' Data={'):])))
    return zlib.decompress(comp, -15)


def selftest_modules(repo, keepers):
    """encode_stream reproduces every committed module's stream byte for byte from its decoded vertices (so a rewritten module differs only where a piece moved)."""
    bad = 0
    sss = os.path.join(repo, 'src', 'ServerScriptService', 'ChestChaseServer')
    for k in keepers:
        path = os.path.join(sss, 'KeeperMeshData152%s.lua' % FILES[k['key']])
        if module_raw(path) != encode_stream(k, {i: p['V'] for i, p in enumerate(k['parts'])}):
            bad += 1
            print('selftest: the stream of %s is not reproduced' % path)
    return bad


# ---- the rig config -----------------------------------------------------------------------------------------------------------------------------
def num(x):
    s = ('%.4f' % x).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def vec(v):
    return '{%s}' % ','.join(num(float(x)) for x in v)


def facts_of(V):
    lo, hi = V.min(axis=0), V.max(axis=0)
    return {'Center': (lo + hi) / 2, 'Size': hi - lo, 'Lo': lo, 'Hi': hi}


def cf_mul(a, b):
    ra = [a[3:6], a[6:9], a[9:12]]
    rb = [b[3:6], b[6:9], b[9:12]]
    p = [a[i] + sum(ra[i][j] * b[j] for j in range(3)) for i in range(3)]
    r = [[sum(ra[i][k] * rb[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return p + r[0] + r[1] + r[2]


def cf_inv(a):
    r = [a[3:6], a[6:9], a[9:12]]
    rt = [[r[j][i] for j in range(3)] for i in range(3)]
    p = [-sum(rt[i][j] * a[j] for j in range(3)) for i in range(3)]
    return p + rt[0] + rt[1] + rt[2]


MOUTH = {2: (0, 1.1, -8.2), 3: (0, 2.2, -10.9), 4: (0, 6.2, -13.2), 6: (0, 7.3, -5.3)}   # encode_meshes.py: today's KeeperFx.Mouth


def spec_block(src, st):
    return re.search(r"\n \[%d\]=\{.*?(?=\n \[\d+\]=\{|\nlocal merged)" % st, src, re.S).group(0)


def expected(k, V, src, cfg, upg):
    """What encode_meshes.py writes into KeeperRigConfig152 for this keeper from these vertices: {'parts': {name: [Center / Size text, tree text]}, 'bounds': text, 'mouth': text or None}."""
    st = k['stage']
    facts = [facts_of(V[i]) for i in range(len(k['parts']))]
    spec = spec_block(src, st)
    cosmetic = set(re.findall(r"Name='([^']*)',Group='[^']*',Kind='[^']*',Center=\{[^}]*\},Size=\{[^}]*\},Triangles=\d+,(?:FaceState='[^']*',)?EyeGlow=\w+,Glow=\w+,(?:Color=\{[^}]*\},)?Cosmetic=true", spec))
    out = {'parts': {}, 'bounds': None, 'mouth': None}
    for p, f in zip(k['parts'], facts):
        e = ['Center=%s,Size=%s' % (vec(f['Center']), vec(f['Size']))]
        if st == 1 and p['tree'] is not None:
            follows = re.search(r"Name='%s',Group='%s'.*?TreeFollows='([^']*)'" % (re.escape(p['name']), re.escape(p['group'])), spec).group(1)
            old = next(q for q in upg['1']['Parts'] if q['Name'] == follows and q['Group'] == p['group'])
            delta = cf_mul(old['TreeRest'], cf_inv(old['Rest']))
            sc = sum(old['TreeSize'][i] / old['Size'][i] for i in range(3)) / 3
            tree = cf_mul(delta, [float(c) for c in f['Center']] + [1, 0, 0, 0, 1, 0, 0, 0, 1])
            e.append('TreeRest={%s},TreeSize=%s' % (','.join(num(x) for x in tree), vec([float(s) * sc for s in f['Size']])))
        out['parts'][p['name']] = e
    if st != 0:
        b = {}
        for p, f in zip(k['parts'], facts):
            if p['kind'] != 'main' or p['name'] in cosmetic:
                continue
            g = b.setdefault(p['group'], [[1e9] * 3, [-1e9] * 3])
            for a in range(3):
                g[0][a] = min(g[0][a], float(f['Lo'][a])); g[1][a] = max(g[1][a], float(f['Hi'][a]))
        out['bounds'] = 'Bounds={%s}' % ','.join('%s={%s,%s}' % (g, vec(v[0]), vec(v[1])) for g, v in sorted(b.items()))
        if st in MOUTH and 'Jaw' in b:
            oj, nj, m0 = cfg[str(st)]['Bounds']['Jaw'], b['Jaw'], MOUTH[st]
            out['mouth'] = 'Mouth=%s' % vec((m0[0], m0[1] + nj[1][1] - oj[1][1], m0[2] + nj[0][2] - oj[0][2]))
    return out


def load_game_data():
    sys.path.insert(0, os.path.join(HERE, '..', '..', 'R151', 'keepers', 'blender'))
    import data  # noqa: E402
    return data.load_cfg(), data.load_upg()


def selftest(cfg_path, keepers):
    """The formulas reproduce the committed config from the committed (unchanged) vertices: Center / Size / TreeRest / TreeSize of every part, Bounds, Mouth."""
    src = open(cfg_path, encoding='utf-8').read()
    cfg, upg = load_game_data()
    bad = 0
    for k in keepers:
        e = expected(k, {i: p['V'] for i, p in enumerate(k['parts'])}, src, cfg, upg)
        spec = spec_block(src, k['stage'])
        for name, texts in e['parts'].items():
            for t in texts:
                if t not in spec:
                    bad += 1
                    print('selftest: %s / %s: expected %s' % (k['name'], name, t))
        for t in (e['bounds'], e['mouth']):
            if t and t not in spec:
                bad += 1
                print('selftest: %s: expected %s' % (k['name'], t[:120]))
    return bad


def patch_config(cfg_path, keepers, works):
    """Rewrite what the moves changed: a part's Center / Size (and the golem's TreeRest / TreeSize), the keeper's Bounds and Mouth."""
    src = open(cfg_path, encoding='utf-8').read()
    cfg, upg = load_game_data()
    changed = []
    for k in keepers:
        w = works[k['key']]
        if not w.moves:
            continue
        old = expected(k, {i: p['V'] for i, p in enumerate(k['parts'])}, src, cfg, upg)
        new = expected(k, w.V, src, cfg, upg)
        spec = spec_block(src, k['stage'])
        spec2 = spec
        for name in new['parts']:
            for a, b in zip(old['parts'][name], new['parts'][name]):
                if a != b:
                    assert spec2.count(a) == 1, (k['name'], name, a)
                    spec2 = spec2.replace(a, b)
                    if (k['name'], name) not in changed:
                        changed.append((k['name'], name))
        for key in ('bounds', 'mouth'):
            if old[key] != new[key]:
                assert spec2.count(old[key]) == 1, (k['name'], key)
                spec2 = spec2.replace(old[key], new[key])
        src = src.replace(spec, spec2, 1)
    open(cfg_path, 'w', encoding='utf-8').write(src)
    return changed


# ---- entry points -------------------------------------------------------------------------------------------------------------------------------
def main(argv):
    mode = argv[1]
    if mode == 'data':
        repo, dump = argv[2], argv[3]
        dry = '--dry' in argv
        keepers = M.parse(dump)
        cfg_path = os.path.join(repo, 'src', 'ReplicatedStorage', 'KeeperRigConfig152.lua')
        bad = selftest_modules(repo, keepers) + selftest(cfg_path, keepers)
        if bad:
            raise SystemExit('the encoder / config formulas do not reproduce the committed files (%d differences): not touching them' % bad)
        works = {}
        for k in keepers:
            w = fix_keeper(k)
            works[k['key']] = w
            for mv in w.moves:
                print('%-14s %-18s %3d triangles slide %s   (%s)' % (mv['keeper'], mv['part'], mv['triangles'], mv['by'], mv['why']))
        total = sum(len(w.moves) for w in works.values())
        print('%d pieces slide apart in %d keepers' % (total, sum(1 for w in works.values() if w.moves)))
        if dry or total == 0:
            return 0
        # every slide, for tests/check_keeper_zfight.py --moves: it puts each piece back and expects the check to fail again
        rec = sorted(({k: m[k] for k in ('key', 'part', 'piece', 'by')} for w in works.values() for m in w.moves), key=lambda m: (m['key'], m['part'], m['piece']))
        open(os.path.join(HERE, 'keeper_zfight_moves.json'), 'w').write('[\n' + ',\n'.join(json.dumps(m) for m in rec) + '\n]\n')
        sss = os.path.join(repo, 'src', 'ServerScriptService', 'ChestChaseServer')
        for k in keepers:
            w = works[k['key']]
            if not w.moves:
                continue
            raw = encode_stream(k, w.V)
            n = write_module(os.path.join(sss, 'KeeperMeshData152%s.lua' % FILES[k['key']]), raw)
            print('wrote KeeperMeshData152%s.lua (%d bytes)' % (FILES[k['key']], n))
        changed = patch_config(cfg_path, keepers, works)
        print('KeeperRigConfig152: %d parts changed their box: %s' % (len(changed), ', '.join('%s/%s' % c for c in changed)))
        return 0
    raise SystemExit('usage: fix_zfight.py data REPO DUMP [--dry]')


if __name__ == '__main__':
    sys.exit(main(sys.argv))
