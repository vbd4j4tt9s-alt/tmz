"""R152 round trip, part 2. Usage: python3 check_roundtrip.py ROUNDTRIP_TXT OBJ_DIR REPO

ROUNDTRIP_TXT is roundtrip.luau's output (the game's Luau decoder on the mock). This script
  1. decodes every KeeperMeshData152 module again with an INDEPENDENT Python decoder (base64 -> zlib raw inflate -> the stream that
     encode_meshes.py describes) and requires the Luau decode to be the same (every vertex to 1e-6 studs, every triangle, every cell);
  2. compares each keeper with the approved R151 manifest (docs/proposals/R151/keepers/fbx/keeper_<name>.json): the same parts in the
     same order, the same groups and kinds, the same triangle counts, centres and sizes within the 1/512-stud quantization;
  3. compares with KeeperRigConfig152 (centre, size, triangles per part);
  4. writes OBJ_DIR/<Key>.obj (one object per part) and OBJ_DIR/decoded.json (vertices, triangles, cells, palette, shade range, kinds,
     glow colours) for render_roundtrip.py.
"""
import base64, json, os, re, sys, zlib

txt, objdir, repo = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(objdir, exist_ok=True)
FILES = {'Stage1': 'Golem', 'Stage6': 'JungleKing', 'Stage2': 'SandSnake', 'Stage3': 'IceFang', 'Stage4': 'LavaDragon', 'Stage5': 'CrystalKnight',
         'Stage7': 'StormColossus', 'Darkened': 'Darkened'}
MANIFEST = {'Stage1': 'timber_golem', 'Stage6': 'jungle_king', 'Stage2': 'sand_snake', 'Stage3': 'ice_fang', 'Stage4': 'lava_dragon',
            'Stage5': 'crystal_knight', 'Stage7': 'storm_colossus', 'Darkened': 'the_darkened'}
# R152 z-fighting (blender/fix_zfight.py): the parts whose bounding box changed because a piece slid 0.01 - 0.06 stud out of its neighbour's plane (their config Center / Size follow);
# every other part still matches the approved manifest within the quantization
ZFIGHT_MOVED = {'Stage2': ('Segment1',), 'Stage4': ('Jaw', 'LeftFrontLeg_Glow', 'RightFrontLeg_Glow'), 'Stage5': ('Sword_Point',)}
ZFIGHT_BOX = 0.07
fails = 0
checks = 0


def check(ok, msg):
    global fails, checks
    checks += 1
    if not ok:
        fails += 1
        print('FAIL:', msg)


# --- the Luau decode ----------------------------------------------------------------------------------------------------------------
luau = {}
cur = part = None
for line in open(txt):
    line = line.rstrip('\n')
    if line.startswith('KEEPER '):
        _, key, stage, name = line.split(' ')
        cur = luau[key] = {'Stage': int(stage), 'Name': name.replace('_', ' '), 'Parts': []}
    elif line.startswith('o '):
        _, name, group, kind, nv, nt = line.split(' ')
        part = {'Name': name, 'Group': group, 'Kind': kind, 'V': [], 'T': [], 'P': None}
        cur['Parts'].append(part)
    elif line.startswith('v '):
        part['V'].append([float(x) for x in line.split(' ')[1:]])
    elif line.startswith('f '):
        part['T'].append([int(x) for x in line.split(' ')[1:]])
    elif line.startswith('# cells '):
        part['P'] = [int(x) for x in line[8:].split(' ')]


# --- an independent decoder ---------------------------------------------------------------------------------------------------------
def module(key):
    src = open(os.path.join(repo, 'src', 'ServerScriptService', 'ChestChaseServer', 'KeeperMeshData152%s.lua' % FILES[key])).read()
    data = ''.join(re.findall(r"'([A-Za-z0-9+/=]+)'", src[src.index('Data={'):]))
    num = lambda k: float(re.search(r'\b%s=(-?[0-9.]+)' % k, src).group(1))
    pal = [[float(x) for x in t.split(',')] for t in re.findall(r'\{(-?[0-9.]+,-?[0-9.]+,-?[0-9.]+)\}', src[src.index('Palette={'):src.index('Data={')])]
    return {'B64': data, 'Bytes': int(num('Bytes')), 'Adler': int(num('Adler')), 'Y0': num('Y0'), 'Y1': num('Y1'), 'Palette': pal}


def decode(m):
    raw = zlib.decompress(base64.b64decode(m['B64']), -15)
    assert len(raw) == m['Bytes'] and zlib.adler32(raw) == m['Adler']
    pos = [0]

    def u():
        v = s = 0
        while True:
            c = raw[pos[0]]
            pos[0] += 1
            v |= (c & 127) << s
            s += 7
            if c < 128:
                return v

    def z():
        v = u()
        return v >> 1 if v % 2 == 0 else -((v + 1) >> 1)
    assert u() == 1
    parts = []
    for _ in range(u()):
        nv, nt, pal = u(), u(), u()
        V = [[0, 0, 0] for _ in range(nv)]
        for a in range(3):
            q = 0
            for j in range(nv):
                q += z()
                V[j][a] = q / 512
        T, q = [], 0
        for _ in range(nt):
            t = []
            for _ in range(3):
                q += z()
                t.append(q + 1)
            T.append(t)
        P = None
        if pal:
            P = []
            while len(P) < nt:
                c, n = u(), u()
                P.extend([c] * n)
        parts.append({'V': V, 'T': T, 'P': P})
    assert pos[0] == len(raw)
    return parts


cfg_src = open(os.path.join(repo, 'src', 'ReplicatedStorage', 'KeeperRigConfig152.lua')).read()
decoded = {}
for key, k in luau.items():
    m = module(key)
    py = decode(m)
    man = json.load(open(os.path.join(repo, 'docs', 'proposals', 'R151', 'keepers', 'fbx', 'keeper_%s.json' % MANIFEST[key])))
    check(len(py) == len(k['Parts']) == len(man['Parts']), '%s: %d parts (Python %d, manifest %d)' % (key, len(k['Parts']), len(py), len(man['Parts'])))
    worstV = worstM = 0.0
    tris = 0
    for a, b, mp in zip(k['Parts'], py, man['Parts']):
        check(a['Name'] == mp['Name'] and a['Group'] == mp['Group'] and a['Kind'] == mp['Kind'], '%s: part %s is the manifest\'s %s' % (key, a['Name'], mp['Name']))
        check(len(a['V']) == len(b['V']) and a['T'] == b['T'] and a['P'] == b['P'], '%s %s: Luau and Python decode the same triangles and cells' % (key, a['Name']))
        for va, vb in zip(a['V'], b['V']):
            worstV = max(worstV, max(abs(va[i] - vb[i]) for i in range(3)))
        check(len(a['T']) == mp['Triangles'], '%s %s: %d triangles (manifest %d)' % (key, a['Name'], len(a['T']), mp['Triangles']))
        lo = [min(v[i] for v in a['V']) for i in range(3)]
        hi = [max(v[i] for v in a['V']) for i in range(3)]
        for i in range(3):
            d = max(abs((lo[i] + hi[i]) / 2 - mp['Center'][i]), abs(hi[i] - lo[i] - mp['Size'][i]))
            if a['Name'] in ZFIGHT_MOVED.get(key, ()):   # a piece of this part slid apart from its neighbour's plane (blender/fix_zfight.py): its box may differ by the slide
                check(d < ZFIGHT_BOX, '%s %s: the box moved by %.4f studs (the z-fight pass allows %.2f)' % (key, a['Name'], d, ZFIGHT_BOX))
            else:
                worstM = max(worstM, d)
        tris += len(a['T'])
        if b['P']:
            check(max(b['P']) < len(m['Palette']), '%s %s: every cell is in the palette' % (key, a['Name']))
    check(worstV < 1e-6, '%s: Luau and Python vertices agree (worst %.2g)' % (key, worstV))
    check(worstM < 2.5e-3, '%s: every part\'s centre and size match the approved manifest within the quantization (worst %.4f studs)' % (key, worstM))
    check(tris == sum(p['Triangles'] for p in man['Parts']), '%s: %d triangles in all' % (key, tris))
    print('ok %-9s %-15s %2d parts %5d triangles %5d vertices, worst centre / size vs manifest %.4f studs' % (
        key, k['Name'], len(k['Parts']), tris, sum(len(p['V']) for p in k['Parts']), worstM))
    with open(os.path.join(objdir, '%s.obj' % key), 'w') as f:
        f.write('# R152 %s decoded by KeeperMeshes152.Decode on the mock (rig space, studs)\n' % k['Name'])
        base = 0
        for p in k['Parts']:
            f.write('o %s\n' % p['Name'])
            for v in p['V']:
                f.write('v %.6f %.6f %.6f\n' % tuple(v))
            for t in p['T']:
                f.write('f %d %d %d\n' % tuple(i + base for i in t))
            base += len(p['V'])
    decoded[key] = {'Stage': k['Stage'], 'Name': k['Name'], 'Y0': m['Y0'], 'Y1': m['Y1'], 'Palette': m['Palette'],
                    'Parts': [{'Name': p['Name'], 'Group': p['Group'], 'Kind': p['Kind'], 'V': p['V'], 'T': p['T'], 'P': p['P'],
                               'Color': mp.get('Color'), 'FaceState': mp.get('FaceState')} for p, mp in zip(k['Parts'], man['Parts'])]}
json.dump(decoded, open(os.path.join(objdir, 'decoded.json'), 'w'))
check(len(decoded) == 8, 'all 8 keepers decoded (%d)' % len(decoded))
print('R152 round trip: %d checks, %d failures' % (checks, fails))
sys.exit(1 if fails else 0)
