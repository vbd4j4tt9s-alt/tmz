"""R153 lag audit: render-cost census of a binary .rbxl (read-only).

Usage: python3 -I place_census.py <place.rbxl> [out.json]

Prints, for Workspace (by top-level area) and Lighting: instance / part / MeshPart / union counts, CastShadow on small parts,
transparent / Glass / Neon / ForceField parts, unanchored parts, lights (and which cast shadows), Highlights, emitters / beams /
trails / Fire / Smoke / Sparkles (enabled, rates), Decals / Textures, SurfaceGuis (PixelsPerStud, CanvasSize), the Lighting
service and its post effects, and Workspace streaming settings. tools/rbxl.py does the chunk decompression."""
import collections, json, os, struct, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'tools'))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'R149', 'tools'))
import rbxl  # noqa: E402
import rbxl_geom as g  # noqa: E402

PARTS = {'Part', 'WedgePart', 'CornerWedgePart', 'MeshPart', 'UnionOperation', 'TrussPart', 'SpawnLocation', 'Seat', 'VehicleSeat',
         'PartOperation', 'IntersectOperation', 'NegateOperation'}
LIGHTS = {'PointLight', 'SpotLight', 'SurfaceLight'}
FX = {'ParticleEmitter', 'Beam', 'Trail', 'Fire', 'Smoke', 'Sparkles'}
SKIP = {'Source', 'Tags', 'AttributesSerialize', 'HistoryId', 'UniqueId', 'Capabilities', 'SourceAssetId', 'PhysicalConfigData',
        'MeshData', 'PhysicsData', 'ChildData', 'ModelMeshData', 'SlimHash', 'InitialSize', 'LinkedSource', 'ScriptGuid'}


def decode(body, o, t, n):
    if t == 0x0D:  # Vector2
        x, o = g.f32s(body, o, n); y, o = g.f32s(body, o, n)
        return list(zip(x, y))
    if t == 0x12:  # enum token
        v, _ = g.u32s(body, o, n); return v
    return g.decode(body, o, t, n)


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
            cname, rs = classes[cid]
            if pname in SKIP:
                continue
            try:
                vals = decode(body, o, t, len(rs))
            except Exception:
                vals = None
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


def txt(v):
    return v.decode('utf-8', 'replace') if isinstance(v, bytes) else v


def main(path, out=None):
    inst, parent = load(path)
    names = {r: txt(i.get('Name', b'?')) for r, i in inst.items()}
    cache = {}

    def path_of(r):
        if r in cache:
            return cache[r]
        out_, x = [], r
        while x in inst:
            out_.append(names[x]); x = parent.get(x, -1)
        cache[r] = '/'.join(reversed(out_))
        return cache[r]

    def area(r):
        p = path_of(r).split('/')
        if p[0] != 'Workspace':
            return p[0]
        if len(p) >= 3 and p[1] == 'ChestChaseMap':
            return 'ChestChaseMap/' + p[2]
        return 'Workspace/' + (p[1] if len(p) > 1 else '')

    def inside(r, root):
        p = path_of(r)
        return p == root or p.startswith(root + '/')

    res = {}
    ws = [r for r in inst if inside(r, 'Workspace')]
    by_area = collections.defaultdict(collections.Counter)
    for r in ws:
        i = inst[r]; c = i['ClassName']; a = area(r)
        by_area[a]['instances'] += 1
        if c in PARTS:
            by_area[a]['parts'] += 1
            if c == 'MeshPart':
                by_area[a]['MeshPart'] += 1
            if c in ('UnionOperation', 'PartOperation', 'IntersectOperation', 'NegateOperation'):
                by_area[a]['unions'] += 1
            size = i.get('size') or i.get('Size') or (4, 1, 2)
            t = i.get('Transparency', 0.0)
            cast = i.get('CastShadow', True)
            mat = g.MATERIALS.get(i.get('Material', 256), str(i.get('Material')))
            if t >= 0.999:
                by_area[a]['invisible(t=1)'] += 1
            elif t > 0.001:
                by_area[a]['semi-transparent'] += 1
            if mat in ('Glass', 'Neon', 'ForceField') and t < 0.999:
                by_area[a][mat] += 1
            if cast and t < 0.999:
                by_area[a]['CastShadow'] += 1
                if max(size) < 4:
                    by_area[a]['CastShadow small(<4)'] += 1
            if cast and t >= 0.999:
                by_area[a]['CastShadow on invisible'] += 1
            if not i.get('Anchored', False):
                by_area[a]['UNANCHORED'] += 1
        elif c in LIGHTS:
            by_area[a][c] += 1
            if i.get('Enabled', True) and i.get('Shadows', False):
                by_area[a][c + ' Shadows'] += 1
        elif c in FX:
            by_area[a][c] += 1
            if i.get('Enabled', True):
                by_area[a][c + ' on'] += 1
                if c == 'ParticleEmitter':
                    by_area[a]['emitter rate sum'] += round(i.get('Rate', 0))
        elif c in ('Highlight', 'SelectionBox', 'BoxHandleAdornment', 'Decal', 'Texture', 'SurfaceGui', 'BillboardGui', 'Humanoid',
                   'AnimationController', 'Model', 'ProximityPrompt', 'Weld', 'WeldConstraint', 'Motor6D', 'Attachment'):
            by_area[a][c] += 1
        elif c == 'Sound':
            by_area[a]['Sound'] += 1
            if i.get('Playing'):
                by_area[a]['Sound playing'] += 1
        elif c.endswith('Constraint'):
            by_area[a]['constraints'] += 1
    res['areas'] = {a: dict(cn) for a, cn in sorted(by_area.items(), key=lambda kv: -kv[1]['parts'])}
    tot = collections.Counter()
    for cn in by_area.values():
        tot.update(cn)
    res['workspace_total'] = dict(tot)
    cls = collections.Counter(inst[r]['ClassName'] for r in ws)
    res['workspace_classes'] = dict(cls.most_common(60))
    lights = []
    for r in ws:
        i = inst[r]
        if i['ClassName'] in LIGHTS:
            lights.append({'path': path_of(r), 'class': i['ClassName'], 'shadows': bool(i.get('Shadows', False)), 'enabled': i.get('Enabled', True),
                           'range': round(i.get('Range', 0), 2), 'brightness': round(i.get('Brightness', 0), 2)})
    res['lights'] = lights
    res['fx'] = [{'path': path_of(r), 'class': inst[r]['ClassName'], 'enabled': inst[r].get('Enabled', True), 'rate': round(inst[r].get('Rate', 0) or 0, 2)}
                 for r in ws if inst[r]['ClassName'] in FX]
    sg = []
    for r in inst:
        i = inst[r]
        if i['ClassName'] == 'SurfaceGui':
            sg.append({'path': path_of(r), 'pps': i.get('PixelsPerStud'), 'canvas': i.get('CanvasSize'), 'sizing': i.get('SizingMode'),
                       'maxdist': i.get('MaxDistance'), 'enabled': i.get('Enabled', True), 'aot': i.get('AlwaysOnTop', False)})
    res['surfaceguis'] = sg
    res['highlights'] = [{'path': path_of(r), 'enabled': inst[r].get('Enabled', True), 'depth': inst[r].get('DepthMode')} for r in inst
                         if inst[r]['ClassName'] == 'Highlight']
    res['unanchored'] = [path_of(r) for r in ws if inst[r]['ClassName'] in PARTS and not inst[r].get('Anchored', False)]
    for svc in ('Lighting', 'Workspace'):
        rs = [r for r in inst if inst[r]['ClassName'] == svc]
        if rs:
            res[svc] = {k: txt(v) for k, v in inst[rs[0]].items() if len(str(v)) < 200}
    post = []
    for r in inst:
        c = inst[r]['ClassName']
        if c in ('Atmosphere', 'BloomEffect', 'SunRaysEffect', 'DepthOfFieldEffect', 'ColorCorrectionEffect', 'BlurEffect', 'Sky', 'Clouds'):
            post.append({'path': path_of(r), 'class': c, **{k: txt(v) for k, v in inst[r].items() if k != 'ClassName'}})
    res['post'] = post
    res['terrain'] = [{k: v for k, v in inst[r].items() if not isinstance(v, bytes)} for r in inst if inst[r]['ClassName'] == 'Terrain']
    stores = collections.Counter()
    for r in inst:
        p = path_of(r).split('/')
        if p[0] in ('ReplicatedStorage', 'ServerStorage', 'StarterGui', 'StarterPlayer', 'ReplicatedFirst', 'Lighting'):
            key = '/'.join(p[:2])
            if inst[r]['ClassName'] in PARTS:
                stores[key + ' parts'] += 1
            stores[key + ' instances'] += 1
    res['stores'] = dict(stores.most_common(40))

    keys = ['instances', 'parts', 'MeshPart', 'unions', 'CastShadow', 'CastShadow small(<4)', 'CastShadow on invisible', 'semi-transparent',
            'invisible(t=1)', 'Glass', 'Neon', 'ForceField', 'UNANCHORED', 'PointLight', 'PointLight Shadows', 'SpotLight', 'SpotLight Shadows',
            'SurfaceLight', 'SurfaceLight Shadows', 'Highlight', 'ParticleEmitter on', 'emitter rate sum', 'Beam on', 'Trail', 'Fire on', 'Smoke on',
            'Sparkles on', 'Decal', 'Texture', 'SurfaceGui', 'BillboardGui', 'Sound', 'Sound playing', 'Humanoid', 'ProximityPrompt', 'constraints']
    print('== Workspace by area (sorted by parts) ==')
    for a, cn in res['areas'].items():
        print(' ', a, ' '.join('%s=%s' % (k, cn[k]) for k in keys if cn.get(k)))
    print('== Workspace total ==')
    print(' ', ' '.join('%s=%s' % (k, tot[k]) for k in keys if tot.get(k)))
    print('== Workspace classes ==')
    print(' ', ', '.join('%s %d' % kv for kv in cls.most_common(45)))
    print('== Lights ==', len(lights), 'with Shadows on:', sum(1 for l in lights if l['shadows'] and l['enabled']))
    for l in lights[:40]:
        print('  ', l)
    print('== Highlights ==', len(res['highlights']))
    for h in res['highlights'][:20]:
        print('  ', h)
    print('== SurfaceGuis ==', len(sg))
    for s in sg[:40]:
        print('  ', s)
    print('== Unanchored parts in Workspace ==', len(res['unanchored']))
    for u in res['unanchored'][:40]:
        print('  ', u)
    print('== Lighting ==')
    for k, v in sorted(res.get('Lighting', {}).items()):
        print('  ', k, v)
    print('== Workspace (streaming / physics / rendering) ==')
    for k, v in sorted(res.get('Workspace', {}).items()):
        print('  ', k, v)
    print('== Post / sky ==')
    for p_ in post:
        print('  ', p_)
    print('== Terrain ==', res['terrain'])
    print('== Template stores ==')
    for k, v in res['stores'].items():
        print('  ', k, v)
    if out:
        json.dump(res, open(out, 'w'), indent=1, default=str)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
