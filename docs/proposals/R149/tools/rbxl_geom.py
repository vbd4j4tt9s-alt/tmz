"""Read the visible geometry of a binary .rbxl (read-only) for the R149 z-fighting detector.

Usage: python3 rbxl_geom.py <place.rbxl> <out.json> [root ...]      (roots default: Workspace)

Writes {"parts": [...]} in the scene format zfight.py reads: one entry per BasePart under the roots with
path, class, shape, size, p (position), r (3x3 rotation, rows), color, material, t (transparency), mesh (SpecialMesh
type/scale/offset when present), faces (Decal / Texture / SurfaceGui faces with a short signature).
Only what the detector needs is decoded (CFrame, size, shape, Color3uint8, Material, Transparency, SpecialMesh,
Decal/Texture/SurfaceGui Face, MeshId/TextureID). tools/rbxl.py does the chunk decompression."""
import json, os, struct, sys, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'tools'))
import rbxl  # noqa: E402

PART_CLASSES = {'Part', 'WedgePart', 'CornerWedgePart', 'MeshPart', 'UnionOperation', 'TrussPart', 'SpawnLocation', 'Seat',
                'VehicleSeat', 'PartOperation', 'IntersectOperation'}
NORMALS = [(1, 0, 0), (0, 1, 0), (0, 0, 1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)]
FACE_NAMES = ['Right', 'Top', 'Back', 'Left', 'Bottom', 'Front']  # Enum.NormalId values 0..5
SHAPES = {0: 'Ball', 1: 'Block', 2: 'Cylinder', 3: 'Wedge', 4: 'CornerWedge'}
MESH_TYPES = {0: 'Head', 1: 'Torso', 2: 'Wedge', 3: 'Sphere', 4: 'Cylinder', 5: 'FileMesh', 6: 'Brick', 7: 'Prism', 8: 'Pyramid',
              9: 'ParallelRamp', 10: 'RightAngleRamp', 11: 'CornerWedge'}
# Enum.Material values (the ones that matter for "same look").
MATERIALS = {256: 'Plastic', 272: 'SmoothPlastic', 288: 'Neon', 512: 'Wood', 528: 'WoodPlanks', 784: 'Marble', 788: 'Basalt', 800: 'Slate',
             804: 'CrackedLava', 816: 'Concrete', 820: 'Limestone', 832: 'Granite', 836: 'Pavement', 848: 'Brick', 864: 'Pebble',
             880: 'Cobblestone', 896: 'Rock', 912: 'Sandstone', 1040: 'CorrodedMetal', 1056: 'DiamondPlate', 1072: 'Foil', 1088: 'Metal',
             1280: 'Grass', 1284: 'LeafyGrass', 1296: 'Sand', 1312: 'Fabric', 1328: 'Snow', 1344: 'Mud', 1360: 'Ground', 1376: 'Asphalt',
             1392: 'Salt', 1536: 'Ice', 1552: 'Glacier', 1568: 'Glass', 1584: 'ForceField', 2048: 'Air', 2064: 'Water', 1600: 'Cardboard',
             1616: 'Carpet', 1632: 'CeramicTiles', 1648: 'ClayRoofTiles', 1664: 'RoofShingles', 1680: 'Leather', 1696: 'Plaster', 1712: 'Rubber'}


def u32s(b, o, n):
    raw = b[o:o + 4 * n]
    return [(raw[i] << 24) | (raw[n + i] << 16) | (raw[2 * n + i] << 8) | raw[3 * n + i] for i in range(n)], o + 4 * n


def f32s(b, o, n):
    vals, o = u32s(b, o, n)
    out = []
    for v in vals:
        v = (v >> 1) | ((v & 1) << 31)
        out.append(struct.unpack('<f', struct.pack('<I', v))[0])
    return out, o


def basic_rotation(rid):
    rid -= 1
    x, y = NORMALS[rid // 6], NORMALS[rid % 6]
    z = (x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0])
    # columns are the right / up / back vectors; rows of the matrix:
    return [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]


def decode(body, o, t, n):
    """Returns a list of n values or None for types we skip."""
    if t == 0x01:
        out = []
        for _ in range(n):
            s, o = rbxl.rstr(body, o); out.append(s)
        return out
    if t == 0x02:
        return [bool(body[o + i]) for i in range(n)]
    if t == 0x03:
        vals, _ = rbxl.deinterleave_i32(body, o, n); return vals
    if t == 0x04:
        vals, _ = f32s(body, o, n); return vals
    if t == 0x0C:
        r, o = f32s(body, o, n); g, o = f32s(body, o, n); b_, o = f32s(body, o, n)
        return list(zip(r, g, b_))
    if t == 0x0E:
        x, o = f32s(body, o, n); y, o = f32s(body, o, n); z, o = f32s(body, o, n)
        return list(zip(x, y, z))
    if t == 0x10:
        rots = []
        for _ in range(n):
            rid = body[o]; o += 1
            if rid == 0:
                m = struct.unpack_from('<9f', body, o); o += 36
                rots.append([list(m[0:3]), list(m[3:6]), list(m[6:9])])
            else:
                rots.append(basic_rotation(rid))
        x, o = f32s(body, o, n); y, o = f32s(body, o, n); z, o = f32s(body, o, n)
        return [(r, (a, b_, c)) for r, a, b_, c in zip(rots, x, y, z)]
    if t == 0x1E:  # OptionalCFrame: a CFrame array, then a bool array (has value)
        cfs = decode(body, o + 1, 0x10, n)
        # skip the CFrame block to read the bools: recompute its length
        q = o + 1
        for _ in range(n):
            q += 1 + (36 if body[q] == 0 else 0)
        q += 12 * n
        has = [bool(body[q + 1 + i]) for i in range(n)]
        return [c if h else None for c, h in zip(cfs, has)]
    if t == 0x12:
        vals, _ = u32s(body, o, n); return vals
    if t == 0x13:
        vals, _ = rbxl.refs(body, o, n); return vals
    if t == 0x1A:
        return [(body[o + i], body[o + n + i], body[o + 2 * n + i]) for i in range(n)]
    return None


WANT = {'Name', 'CFrame', 'size', 'Size', 'shape', 'Color3uint8', 'Material', 'Transparency', 'MeshType', 'Scale', 'Offset', 'Face',
        'MeshId', 'TextureID', 'TextureId', 'Texture', 'Color3', 'Enabled', 'Adornee', 'InitialSize', 'DoubleSided', 'ZOffset',
        'AlwaysOnTop', 'CastShadow', 'StudsPerTileU', 'StudsPerTileV', 'PrimaryPart', 'WorldPivotData', 'Value', 'AttributesSerialize',
        'Text', 'Anchored', 'CanCollide'}


def attributes(blob):
    """Decode AttributesSerialize (string, bool, number, Vector3, CFrame, Color3, Vector2; other types end the read)."""
    out = {}
    if not blob or len(blob) < 4:
        return out
    o = 0
    n, = struct.unpack_from('<I', blob, o); o += 4
    try:
        for _ in range(n):
            kl, = struct.unpack_from('<I', blob, o); o += 4
            key = blob[o:o + kl].decode('utf-8', 'replace'); o += kl
            t = blob[o]; o += 1
            if t == 0x02:
                l, = struct.unpack_from('<I', blob, o); o += 4; out[key] = blob[o:o + l].decode('utf-8', 'replace'); o += l
            elif t == 0x03:
                out[key] = bool(blob[o]); o += 1
            elif t == 0x05:
                out[key] = struct.unpack_from('<f', blob, o)[0]; o += 4
            elif t == 0x06:
                out[key] = struct.unpack_from('<d', blob, o)[0]; o += 8
            elif t == 0x0F:
                out[key] = {'Color3': list(struct.unpack_from('<3f', blob, o))}; o += 12
            elif t == 0x10:
                out[key] = {'Vector2': list(struct.unpack_from('<2f', blob, o))}; o += 8
            elif t == 0x11:
                out[key] = {'Vector3': list(struct.unpack_from('<3f', blob, o))}; o += 12
            elif t == 0x14:
                pos = struct.unpack_from('<3f', blob, o); o += 12
                rid = blob[o]; o += 1
                if rid == 0:
                    m = struct.unpack_from('<9f', blob, o); o += 36
                    rot = [list(m[0:3]), list(m[3:6]), list(m[6:9])]
                else:
                    rot = basic_rotation(rid)
                out[key] = {'CFrame': [list(pos), rot]}
            elif t == 0x0E:
                out[key] = {'BrickColor': struct.unpack_from('<I', blob, o)[0]}; o += 4
            elif t == 0x15:
                l, = struct.unpack_from('<I', blob, o); o += 4; en = blob[o:o + l].decode(); o += l
                out[key] = {'Enum': [en, struct.unpack_from('<I', blob, o)[0]]}; o += 4
            elif t == 0x1B:
                out[key] = {'NumberRange': list(struct.unpack_from('<2f', blob, o))}; o += 8
            else:
                break
    except struct.error:
        pass
    return out


def load(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'<roblox!'
    pos, classes, inst, parent = 32, {}, {}, {}
    while pos < len(d):
        name = d[pos:pos + 4]; clen, ulen, _ = struct.unpack_from('<III', d, pos + 4); pos += 16
        if clen == 0:
            body = d[pos:pos + ulen]; pos += ulen
        else:
            body = rbxl.decomp(d[pos:pos + clen], ulen); pos += clen
        if name == b'INST':
            cid, = struct.unpack_from('<I', body, 0)
            cname, o = rbxl.rstr(body, 4); o += 1
            n, = struct.unpack_from('<I', body, o); o += 4
            rs, o = rbxl.refs(body, o, n)
            classes[cid] = (cname.decode(), rs)
            for r in rs:
                inst[r] = {'ClassName': cname.decode()}
        elif name == b'PROP':
            cid, = struct.unpack_from('<I', body, 0)
            pname, o = rbxl.rstr(body, 4); pname = pname.decode()
            t = body[o]; o += 1
            if pname not in WANT:
                continue
            _, rs = classes[cid]
            vals = decode(body, o, t, len(rs))
            if vals is None:
                continue
            for r, v in zip(rs, vals):
                inst[r][pname] = v
        elif name == b'PRNT':
            n, = struct.unpack_from('<I', body, 1)
            ch, o = rbxl.refs(body, 5, n)
            pa, o = rbxl.refs(body, o, n)
            parent.update(zip(ch, pa))
        elif name == b'END\x00':
            break
    return inst, parent


def text(v):
    return v.decode('utf-8', 'replace') if isinstance(v, bytes) else v


def extract(path, roots=('Workspace',)):
    inst, parent = load(path)
    kids = collections.defaultdict(list)
    for c, p in parent.items():
        kids[p].append(c)
    names = {r: text(i.get('Name', b'?')) for r, i in inst.items()}
    paths = {}

    def path_of(r):
        if r in paths:
            return paths[r]
        out = []
        x = r
        while x in inst:
            out.append(names[x]); x = parent.get(x, -1)
        paths[r] = '/'.join(reversed(out))
        return paths[r]
    parts = []
    for r, i in inst.items():
        if i['ClassName'] not in PART_CLASSES or 'CFrame' not in i:
            continue
        p = path_of(r)
        if not any(p == root or p.startswith(root + '/') for root in roots):
            continue
        rot, pos = i['CFrame']
        size = i.get('size') or i.get('Size') or (4, 1.2, 2)
        cls = i['ClassName']
        shape = 'Block'
        if cls in ('Part', 'SpawnLocation', 'Seat'):
            shape = SHAPES.get(i.get('shape', 1), 'Block')
        elif cls == 'WedgePart':
            shape = 'Wedge'
        elif cls == 'CornerWedgePart':
            shape = 'CornerWedge'
        elif cls in ('MeshPart', 'UnionOperation', 'PartOperation', 'IntersectOperation'):
            shape = 'Mesh'
        c = i.get('Color3uint8', (163, 162, 165))
        entry = {'path': p, 'name': names[r], 'class': cls, 'shape': shape, 'size': [round(v, 5) for v in size],
                 'p': [round(v, 5) for v in pos], 'r': [[round(v, 7) for v in row] for row in rot], 'color': list(c),
                 'material': MATERIALS.get(i.get('Material', 256), str(i.get('Material'))), 't': round(i.get('Transparency', 0.0), 4),
                 'ref': r}
        if cls == 'MeshPart':
            entry['meshId'] = text(i.get('MeshId', b'')); entry['tex'] = text(i.get('TextureID', b''))
            if i.get('DoubleSided'):
                entry['double'] = True
        faces = []
        for k in kids[r]:
            ki = inst[k]; kc = ki['ClassName']
            if kc == 'SpecialMesh':
                entry['mesh'] = {'type': MESH_TYPES.get(ki.get('MeshType', 6), str(ki.get('MeshType'))), 'scale': list(ki.get('Scale', (1, 1, 1))),
                                 'offset': list(ki.get('Offset', (0, 0, 0))), 'meshId': text(ki.get('MeshId', b''))}
            elif kc in ('Decal', 'Texture'):
                faces.append({'kind': kc, 'face': FACE_NAMES[ki.get('Face', 5)], 'sig': text(ki.get('Texture', b'')), 't': round(ki.get('Transparency', 0.0), 3),
                              'name': names[k]})
            elif kc == 'SurfaceGui' and ki.get('Enabled', True) and ki.get('Adornee', -1) in (-1, None):
                faces.append({'kind': kc, 'face': FACE_NAMES[ki.get('Face', 5)], 'sig': 'gui:' + names[k], 't': 0, 'name': names[k],
                              'alwaysOnTop': bool(ki.get('AlwaysOnTop', False)), 'zoffset': ki.get('ZOffset', 0)})
        if faces:
            entry['faces'] = faces
        parts.append(entry)
    # SurfaceGuis adorned to a part from elsewhere (e.g. in a ScreenGui / Folder) still draw on that part.
    byref = {e['ref']: e for e in parts}
    for r, i in inst.items():
        if i['ClassName'] == 'SurfaceGui' and i.get('Adornee', -1) not in (-1, None) and i['Adornee'] in byref and i.get('Enabled', True):
            byref[i['Adornee']].setdefault('faces', []).append({'kind': 'SurfaceGui', 'face': FACE_NAMES[i.get('Face', 5)], 'sig': 'gui:' + names[r],
                                                                't': 0, 'name': names[r], 'adorned': True,
                                                                'alwaysOnTop': bool(i.get('AlwaysOnTop', False))})
    return parts


def lua_value(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, float)):
        return repr(float(v)) if v == v and abs(v) != float('inf') else '0'
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'
    if isinstance(v, dict):
        (k, x), = v.items()
        if k == 'Vector3':
            return '{V3={%s}}' % ','.join(repr(float(a)) for a in x)
        if k == 'Color3':
            return '{C3={%s}}' % ','.join(repr(float(a)) for a in x)
        if k == 'Vector2':
            return '{V2={%s}}' % ','.join(repr(float(a)) for a in x)
        if k == 'CFrame':
            pos, rot = x
            return '{CF={%s}}' % ','.join(repr(float(a)) for a in list(pos) + [c for row in rot for c in row])
        if k == 'NumberRange':
            return '{NR={%s}}' % ','.join(repr(float(a)) for a in x)
        return 'nil'
    return 'nil'


def tree(path, roots, skip=()):
    """Every instance under the roots (minus `skip` subtrees) as a Luau data module for the mock world (zfight_place.luau):
    return {{c=class,n=name,p=parent index (0 = the roots' parent),cf={x,y,z,r00..r22},s={x,y,z},col={r,g,b},m=material,t=,sh=,a={attributes}}...}"""
    inst, parent = load(path)
    kids = collections.defaultdict(list)
    for c, p in parent.items():
        kids[p].append(c)
    names = {r: text(i.get('Name', b'?')) for r, i in inst.items()}

    def path_of(r):
        out = []
        while r in inst:
            out.append(names[r]); r = parent.get(r, -1)
        return '/'.join(reversed(out))
    order, index = [], {}
    for r in sorted(inst):
        p = path_of(r)
        if p in roots:
            stack = [(r, 0)]
            while stack:
                x, par = stack.pop()
                px = path_of(x)
                if any(px == s or px.startswith(s + '/') for s in skip):
                    continue
                order.append((x, par)); index[x] = len(order)
                for k in sorted(kids[x], reverse=True):
                    stack.append((k, x))
    lines = ['return {']
    for r, par in order:
        i = inst[r]
        f = ['c="%s"' % i['ClassName'], 'n=%s' % lua_value(names[r]), 'p=%d' % (index.get(par, 0))]
        if 'CFrame' in i:
            rot, pos = i['CFrame']
            f.append('cf={%s}' % ','.join('%.6g' % v for v in list(pos) + [c for row in rot for c in row]))
        size = i.get('size') or i.get('Size')
        if size is not None and isinstance(size, tuple) and len(size) == 3:
            f.append('s={%s}' % ','.join('%.6g' % v for v in size))
        if 'Color3uint8' in i:
            f.append('col={%d,%d,%d}' % i['Color3uint8'])
        if 'Material' in i and i['ClassName'] != 'Terrain':
            f.append('m="%s"' % MATERIALS.get(i['Material'], 'Plastic'))
        if 'Transparency' in i:
            f.append('t=%.4g' % i['Transparency'])
        if 'shape' in i:
            f.append('sh="%s"' % SHAPES.get(i['shape'], 'Block'))
        if 'Face' in i:
            f.append('face="%s"' % FACE_NAMES[i['Face']])
        if 'MeshType' in i:
            f.append('mt="%s"' % MESH_TYPES.get(i['MeshType'], 'Brick'))
        if 'Scale' in i and isinstance(i['Scale'], tuple):
            f.append('sc={%s}' % ','.join('%.6g' % v for v in i['Scale']))
        if 'Offset' in i and isinstance(i['Offset'], tuple):
            f.append('off={%s}' % ','.join('%.6g' % v for v in i['Offset']))
        for k in ('MeshId', 'TextureID', 'Texture', 'Text'):
            if k in i and isinstance(i[k], bytes):
                f.append('%s=%s' % (k, lua_value(text(i[k]))))
        for k in ('Enabled', 'Anchored', 'CanCollide', 'AlwaysOnTop', 'CastShadow'):
            if k in i:
                f.append('%s=%s' % (k, 'true' if i[k] else 'false'))
        if 'Color3' in i and isinstance(i['Color3'], tuple):
            f.append('c3={%s}' % ','.join('%.6g' % v for v in i['Color3']))
        if i.get('PrimaryPart', -1) in index:
            f.append('pp=%d' % index[i['PrimaryPart']])
        if i.get('WorldPivotData'):
            rot, pos = i['WorldPivotData']
            f.append('pivot={%s}' % ','.join('%.6g' % v for v in list(pos) + [c for row in rot for c in row]))
        at = attributes(i.get('AttributesSerialize', b''))
        if at:
            f.append('a={%s}' % ','.join('[%s]=%s' % (lua_value(k), lua_value(v)) for k, v in sorted(at.items()) if lua_value(v) != 'nil'))
        lines.append('{' + ','.join(f) + '},')
    lines.append('}')
    return '\n'.join(lines), len(order)


if __name__ == '__main__':
    if sys.argv[1] == '--tree':
        # python3 rbxl_geom.py --tree <place.rbxl> <out.luau> <root> [--skip path ...]
        place, out, root = sys.argv[2], sys.argv[3], sys.argv[4]
        skip = sys.argv[sys.argv.index('--skip') + 1:] if '--skip' in sys.argv else []
        src, n = tree(place, {root}, skip)
        open(out, 'w', encoding='utf-8').write(src)
        print('exported', n, 'instances under', root)
        sys.exit(0)
    place, out = sys.argv[1], sys.argv[2]
    roots = sys.argv[3:] or ['Workspace']
    parts = extract(place, roots)
    json.dump({'parts': parts}, open(out, 'w'), separators=(',', ':'))
    print('extracted', len(parts), 'parts under', ', '.join(roots))
