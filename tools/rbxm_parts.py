"""Dump the geometry of a binary .rbxm (Parts / MeshParts / Wedges): class, name, size, position, rotation, colour, material, shape, transparency.
usage: python3 rbxm_parts.py FILE.rbxm [--json OUT.json]"""
import json, struct, sys, math
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rbxl import decomp, rstr, refs

def u32s(b, off, n):
    raw = b[off:off+4*n]
    return [(raw[i]<<24)|(raw[n+i]<<16)|(raw[2*n+i]<<8)|raw[3*n+i] for i in range(n)], off+4*n

def floats(b, off, n):
    vals, off = u32s(b, off, n)
    out = []
    for v in vals:
        bits = ((v >> 1) | ((v & 1) << 31)) & 0xffffffff
        out.append(struct.unpack('<f', struct.pack('<I', bits))[0])
    return out, off

def rot_from_id(i):
    # Roblox's special rotation ids: each picks the right / up / back axes from +-X/Y/Z
    axes = [(1,0,0),(0,1,0),(0,0,1),(-1,0,0),(0,-1,0),(0,0,-1)]
    r = (i - 1) // 6; u = (i - 1) % 6
    R = axes[r]; U = axes[u]
    B = (R[1]*U[2]-R[2]*U[1], R[2]*U[0]-R[0]*U[2], R[0]*U[1]-R[1]*U[0])
    return [R[0],U[0],B[0], R[1],U[1],B[1], R[2],U[2],B[2]]

def load(path):
    d = open(path, 'rb').read(); assert d[:8] == b'<roblox!'
    pos = 32; classes = {}; inst = {}; parent = {}
    while pos < len(d):
        name = d[pos:pos+4]; clen, ulen, _ = struct.unpack_from('<III', d, pos+4); pos += 16
        if clen == 0: body = d[pos:pos+ulen]; pos += ulen
        else: body = decomp(d[pos:pos+clen], ulen); pos += clen
        if name == b'INST':
            cid, = struct.unpack_from('<I', body, 0); cname, o = rstr(body, 4); o += 1
            n, = struct.unpack_from('<I', body, o); o += 4
            rs, o = refs(body, o, n); classes[cid] = (cname.decode(), rs)
            for r in rs: inst[r] = {'ClassName': cname.decode()}
        elif name == b'PROP':
            cid, = struct.unpack_from('<I', body, 0); pname, o = rstr(body, 4); pname = pname.decode()
            t = body[o]; o += 1; cname, rs = classes[cid]; n = len(rs)
            try:
                if t == 0x01:
                    for r in rs:
                        s, o = rstr(body, o)
                        if pname in ('Name', 'MeshId', 'TextureID', 'MaterialVariantSerialized', 'Source'): inst[r][pname] = s.decode('utf-8', 'replace')
                elif t == 0x02:
                    for i, r in enumerate(rs): inst[r][pname] = bool(body[o+i])
                elif t == 0x04:
                    vals, o = floats(body, o, n)
                    for r, v in zip(rs, vals): inst[r][pname] = v
                elif t == 0x0E:
                    xs, o = floats(body, o, n); ys, o = floats(body, o, n); zs, o = floats(body, o, n)
                    for r, x, y, z in zip(rs, xs, ys, zs): inst[r][pname] = [x, y, z]
                elif t == 0x10:
                    rots = []
                    for r in rs:
                        rid = body[o]; o += 1
                        if rid == 0: rots.append(list(struct.unpack_from('<9f', body, o))); o += 36
                        else: rots.append(rot_from_id(rid))
                    xs, o = floats(body, o, n); ys, o = floats(body, o, n); zs, o = floats(body, o, n)
                    for r, rot, x, y, z in zip(rs, rots, xs, ys, zs): inst[r][pname] = {'pos': [x, y, z], 'rot': rot}
                elif t == 0x12:
                    vals, o = u32s(body, o, n)
                    for r, v in zip(rs, vals): inst[r][pname] = v
                elif t == 0x1A:
                    R = body[o:o+n]; G = body[o+n:o+2*n]; B = body[o+2*n:o+3*n]
                    for i, r in enumerate(rs): inst[r][pname] = [R[i], G[i], B[i]]
            except Exception as e:
                print('skip', cname, pname, hex(t), e, file=sys.stderr)
        elif name == b'PRNT':
            n, = struct.unpack_from('<I', body, 1); ch, o = refs(body, 5, n); pa, o = refs(body, o, n); parent.update(zip(ch, pa))
        elif name == b'END\x00': break
    return inst, parent

if __name__ == '__main__':
    inst, parent = load(sys.argv[1])
    out = []
    for r, p in sorted(inst.items()):
        row = {'ref': r, 'parent': parent.get(r, -1)}
        for k in ('ClassName', 'Name', 'size', 'CFrame', 'Color3uint8', 'Material', 'shape', 'Transparency', 'Anchored', 'CanCollide', 'MeshId', 'TextureID', 'Source'):
            if k in p: row[k] = p[k]
        out.append(row)
    if '--json' in sys.argv: json.dump(out, open(sys.argv[sys.argv.index('--json')+1], 'w'), indent=1)
    from collections import Counter
    print(Counter(r['ClassName'] for r in out))
    for r in out[:60]:
        cf = r.get('CFrame'); pos = cf and [round(v, 2) for v in cf['pos']]; rot = cf and [round(v, 3) for v in cf['rot']]
        print(r['ref'], r['ClassName'], r.get('Name'), 'size', r.get('size') and [round(v, 2) for v in r['size']], 'pos', pos, 'rot', rot, 'col', r.get('Color3uint8'), 'mat', r.get('Material'), 'shape', r.get('shape'), 'tr', r.get('Transparency'))
