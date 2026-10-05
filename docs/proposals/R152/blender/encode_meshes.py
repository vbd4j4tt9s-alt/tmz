"""R152: write the game's keeper mesh data and rig config from the approved rev 6 models.

Usage: python3 encode_meshes.py MESHES_JSON FLOOR_JSON REPO
  MESHES_JSON  dump_meshes.py (bpy) output: every part's vertices, triangles, palette cells, the hulls and the sleep Z
  FLOOR_JSON   select_floor.luau output: the floor samples picked with the game's own pose code
Writes
  src/ServerScriptService/ChestChaseServer/KeeperMeshData152<Name>.lua  one per keeper (server only, never sent to players)
  src/ReplicatedStorage/KeeperRigConfig152.lua                          the parts, flags, floor samples, bounds per keeper

The mesh stream of one keeper (KeeperMeshes152.Decode reads it), all integers as LEB128 varints, signed ones zigzagged:
  version (1), part count, then per part in KeeperRigConfig152 order:
    vertex count V, triangle count T, palette flag (1: main / face parts carry a palette cell per triangle)
    X of every vertex, then Y, then Z: signed deltas (previous starts at 0) of the position in steps of 1/512 stud, rig space
    3T vertex indices (0-based): signed deltas from the previous index
    palette flag 1: runs (cell, count) covering the T triangles
The stream is raw-deflated (zlib, level 9) and base64-encoded in 1000-character strings. Normals are not stored: every
face of these models is flat (dump_meshes.py checks it), so the decoder takes each triangle's own normal. Colours are not
stored either: a vertex colour is the palette colour of its triangle times the generator's height shade
0.80 + 0.26 * t, t = (y - Y0) / (Y1 - Y0) clamped to 0..1 (kit.make_object; dump_meshes.py checks the formula).
"""
import base64, json, math, os, sys, zlib

STEP = 1 / 512
FILES = {'timber_golem': 'Golem', 'jungle_king': 'JungleKing', 'sand_snake': 'SandSnake', 'ice_fang': 'IceFang', 'lava_dragon': 'LavaDragon',
         'crystal_knight': 'CrystalKnight', 'storm_colossus': 'StormColossus', 'the_darkened': 'Darkened'}
HERE = os.path.dirname(os.path.abspath(__file__))
R151 = os.path.abspath(os.path.join(HERE, '..', '..', 'R151', 'keepers'))
sys.path.insert(0, os.path.join(R151, 'blender'))
import data  # noqa: E402

meshes, floor, repo = json.load(open(sys.argv[1])), json.load(open(sys.argv[2])), sys.argv[3]
cfg, upg = data.load_cfg(), data.load_upg()


def zz(n):
    return (n << 1) if n >= 0 else ((-n << 1) - 1)


def varint(out, n):
    assert n >= 0
    while n >= 128:
        out.append((n & 127) | 128)
        n >>= 7
    out.append(n)


def num(x):
    s = ('%.4f' % x).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def vec(v):
    return '{%s}' % ','.join(num(x) for x in v)


def lua_str(s):
    return "'%s'" % s.replace('\\', '\\\\').replace("'", "\\'")


def cf_mul(a, b):
    """CFrame components (x, y, z, r00..r22) product a * b."""
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


def encode_keeper(k, man):
    """The deflated stream and the quantized geometry facts (bbox centre / size per part) the config needs."""
    out = bytearray([1])
    varint(out, len(k['Parts']))
    facts = []
    for p, m in zip(k['Parts'], man['Parts']):
        assert p['Name'] == m['Name'] and len(p['T']) == m['Triangles'], (p['Name'], m['Name'])
        assert not any(p['S']), 'smooth faces are not supported by the decoder: %s' % p['Name']
        q = [[round(c / STEP) for c in v] for v in p['V']]
        pal = m['Kind'] in ('main', 'face')
        varint(out, len(q))
        varint(out, len(p['T']))
        varint(out, 1 if pal else 0)
        for axis in range(3):
            prev = 0
            for v in q:
                varint(out, zz(v[axis] - prev))
                prev = v[axis]
        prev = 0
        for t in p['T']:
            for i in t:
                varint(out, zz(i - prev))
                prev = i
        if pal:
            P, i = p['P'], 0
            while i < len(P):
                j = i
                while j < len(P) and P[j] == P[i]:
                    j += 1
                varint(out, P[i])
                varint(out, j - i)
                i = j
        lo = [min(v[a] for v in q) for a in range(3)]
        hi = [max(v[a] for v in q) for a in range(3)]
        facts.append({'Center': [(lo[a] + hi[a]) / 2 * STEP for a in range(3)], 'Size': [(hi[a] - lo[a]) * STEP for a in range(3)],
                      'Lo': [lo[a] * STEP for a in range(3)], 'Hi': [hi[a] * STEP for a in range(3)], 'Vertices': len(q)})
    raw = bytes(out)
    c = zlib.compressobj(9, zlib.DEFLATED, -15, 9)
    comp = c.compress(raw) + c.flush()
    assert zlib.decompress(comp, -15) == raw
    return raw, comp, facts


def write_data(k, raw, comp, path):
    b64 = base64.b64encode(comp).decode()
    chunks = [b64[i:i + 1000] for i in range(0, len(b64), 1000)]
    pal = ','.join(vec(c) for c in k['Palette'])
    tris = sum(len(p['T']) for p in k['Parts'])
    verts = sum(len(p['V']) for p in k['Parts'])
    src = ('-- R152: %s mesh data (the approved R151 rev 6 model, docs/proposals/R151/keepers). Generated by docs/proposals/R152/blender/run.sh\n'
           '-- (encode_meshes.py, whose header describes the stream); do not edit. KeeperMeshes152 decodes and bakes it once per server.\n'
           'return {Key=%s,Name=%s,Stage=%d,Parts=%d,Vertices=%d,Triangles=%d,Bytes=%d,Adler=%d,Step=1/512,Y0=%s,Y1=%s,\n'
           ' Palette={%s},\n Data={\n%s\n}}\n') % (
        k['Name'], lua_str(KEYS[k['Stage']]), lua_str(k['Name']), k['Stage'], len(k['Parts']), verts, tris, len(raw), zlib.adler32(raw),
        num(k['Y0']), num(k['Y1']), pal, ',\n'.join("'%s'" % c for c in chunks))
    open(path, 'w').write(src)
    return len(src.encode())


KEYS = {1: 'Stage1', 2: 'Stage2', 3: 'Stage3', 4: 'Stage4', 5: 'Stage5', 6: 'Stage6', 7: 'Stage7', 0: 'Darkened'}
# breath puff points of today's KeeperFx.Mouth, moved with the new jaw's front / top
MOUTH = {2: (0, 1.1, -8.2), 3: (0, 2.2, -10.9), 4: (0, 6.2, -13.2), 6: (0, 7.3, -5.3)}


def bounds(k, facts, man, groups):
    out = {}
    for p, f, m in zip(k['Parts'], facts, man['Parts']):
        if m['Kind'] != 'main' or m.get('Cosmetic'):
            continue
        b = out.setdefault(p['Group'], [[1e9] * 3, [-1e9] * 3])
        for a in range(3):
            b[0][a] = min(b[0][a], f['Lo'][a])
            b[1][a] = max(b[1][a], f['Hi'][a])
    for g in groups:
        assert g in out, 'no main geometry in group %s' % g
    return out


def part_spec(st, p, f, m):
    fields = ['Name=%s' % lua_str(m['Name']), 'Group=%s' % lua_str(m['Group']), 'Kind=%s' % lua_str(m['Kind']),
              'Center=%s' % vec(f['Center']), 'Size=%s' % vec(f['Size']), 'Triangles=%d' % m['Triangles']]
    state = m.get('FaceState')
    if state:
        fields.append('FaceState=%s' % lua_str(state))
    # the glowing eyes of the awake face are the keeper's eye glow (BeastAnimation lights them as it wakes); the asleep ones keep their dim colour
    fields.append('EyeGlow=%s' % ('true' if m['Kind'] == 'eyes' and state != 'Asleep' else 'false'))
    fields.append('Glow=%s' % ('true' if m['Kind'] == 'glow' else 'false'))
    if m.get('Color'):
        fields.append('Color=%s' % vec(m['Color']))
    if m.get('Cosmetic') or (st == 0 and m['Kind'] in ('eyes', 'face', 'glow')):
        fields.append('Cosmetic=true')
    if m.get('FloatingByDesign'):
        fields.append('Floating=true')
    if st == 1:
        old = next(q for q in upg['1']['Parts'] if q['Name'] == m['TreeFollows'] and q['Group'] == m['Group'])
        delta = cf_mul(old['TreeRest'], cf_inv(old['Rest']))
        sc = sum(old['TreeSize'][i] / old['Size'][i] for i in range(3)) / 3
        tree = cf_mul(delta, list(f['Center']) + [1, 0, 0, 0, 1, 0, 0, 0, 1])
        fields.append('TreeFollows=%s' % lua_str(m['TreeFollows']))
        fields.append('TreeRest={%s}' % ','.join(num(x) for x in tree))
        fields.append('TreeSize=%s' % vec([s * sc for s in f['Size']]))
    return '{%s}' % ','.join(fields)


def main():
    lines = []
    sizes = {}
    report = []
    for k in meshes['Keepers']:
        st = k['Stage']
        man = json.load(open(os.path.join(R151, 'fbx', 'keeper_%s.json' % k['Key'])))
        raw, comp, facts = encode_keeper(k, man)
        path = os.path.join(repo, 'src', 'ServerScriptService', 'ChestChaseServer', 'KeeperMeshData152%s.lua' % FILES[k['Key']])
        sizes[k['Name']] = write_data(k, raw, comp, path)
        specs = ',\n  '.join(part_spec(st, p, f, m) for p, f, m in zip(k['Parts'], facts, man['Parts']))
        onscreen = max(sum(m['Triangles'] for m in man['Parts'] if m.get('FaceState') in (None, state)) for state in ('Chase', 'Asleep'))
        body = ['Name=%s' % lua_str(k['Name']), 'Key=%s' % lua_str(KEYS[st]), 'Module=%s' % lua_str('KeeperMeshData152' + FILES[k['Key']]),
                'Triangles=%d' % sum(len(p['T']) for p in k['Parts']), 'TrianglesOnScreen=%d' % onscreen]
        report.append('%-15s %2d parts, %5d triangles (%5d on screen)' % (k['Name'], len(k['Parts']), sum(len(p['T']) for p in k['Parts']), onscreen))
        if st != 0:
            legacy = upg[str(st)] if str(st) in upg else cfg[str(st)]
            fl = floor[str(st)]
            assert set(fl['Samples']) == set(legacy['FloorSamples']), st
            assert fl['WorstError'] < 0.05, (st, fl['WorstError'])
            samples = ','.join('%s={%s}' % (g, ','.join(vec(p) for p in pts)) for g, pts in sorted(fl['Samples'].items()))
            b = bounds(k, facts, man, legacy['Pivots'])
            body.append('FloorSamples={%s}' % samples)
            body.append('Bounds={%s}' % ','.join('%s={%s,%s}' % (g, vec(v[0]), vec(v[1])) for g, v in sorted(b.items())))
            if st != 1 and k['Z']:
                # the big sleep Z: centre (Head rest space, where the R151 sheets draw it) and height in studs
                body.append('Z={Point=%s,Height=%s}' % (vec(k['Z']['Center']), num(k['Z']['Size'][1])))
            if st in MOUTH:
                oj = cfg[str(st)]['Bounds']['Jaw']
                nj = b['Jaw']
                m0 = MOUTH[st]
                body.append('Mouth=%s' % vec((m0[0], m0[1] + nj[1][1] - oj[1][1], m0[2] + nj[0][2] - oj[0][2])))
            report.append('%-15s floor samples %3d (today %3d), worst grounding error on unseen poses %.3f studs' % (
                k['Name'], fl['Picked'], sum(len(v) for v in legacy['FloorSamples'].values()), fl['WorstError']))
        body.append('Parts={\n  %s}' % specs)
        lines.append(' [%d]={%s},' % (st, ',\n '.join(body)))
    src = ('-- R152: the approved rev 6 keeper models (docs/proposals/R151/keepers) for KeeperMeshes152, which bakes them at server start.\n'
           '-- Generated by docs/proposals/R152/blender/run.sh (encode_meshes.py); do not edit. Per keeper (stage; 0 = The Darkened):\n'
           '--  Parts         in mesh-data order: rig group, Kind (main / face / eyes / glow), rest centre and size (studs, rig space; The\n'
           '--                Darkened: group-local), FaceState (the client shows Chase or Asleep), EyeGlow (lit as it wakes), Glow (Neon),\n'
           '--                Cosmetic (never hits), the golem\'s tree disguise (TreeRest / TreeSize: today\'s part it follows, KeeperUpgradeData)\n'
           '--  FloorSamples  the points the pose code grounds with (select_floor.luau); Bounds of the main pieces; Z the sleep Z; Mouth\n'
           '-- Get(stage) is the stage\'s config for the new models: these fields over today\'s (KeeperRigConfig: Pivots, Motion, Scale ...).\n'
           'local M={Variant=\'R152\',Version=152}\n'
           'M.Stages={\n%s\n}\n'
           'local merged={}\n'
           'function M.Get(stage)\n'
           ' local m=merged[stage];if m then return m end\n'
           ' local own=M.Stages[stage];if not own or stage==0 then return own end\n'
           ' local legacy=require(script.Parent.KeeperRigConfig)[stage]\n'
           ' m=setmetatable({WingScale=1},{__index=function(_,k)local v=own[k];if v~=nil then return v end;return legacy[k]end})\n'
           ' merged[stage]=m;return m\n'
           'end\n'
           'return M\n') % '\n'.join(lines)
    path = os.path.join(repo, 'src', 'ReplicatedStorage', 'KeeperRigConfig152.lua')
    open(path, 'w').write(src)
    total = sum(sizes.values())
    for name, s in sizes.items():
        print('%-15s data %6d bytes' % (name, s))
    print('mesh data total %d bytes (%.1f KB); KeeperRigConfig152 %d bytes' % (total, total / 1024, len(src.encode())))
    for r in report:
        print(r)


main()
