"""Usage: python3 extract_meshes.py <place.rbxl> <out.json>
Reads the baked plant meshes (ServerStorage/ApprovedPlantMeshIndex + ApprovedPlantMeshData1..N, NOT exported to src/) out of a
place file with tools/rbxl.py and writes {key: {"v": [...], "n": [...], "c": [...], "f": [...]}} for the three.js preview.
Read-only: nothing in the place or the repo changes. Without a place file the preview draws stand-in ellipsoids instead."""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', '..', 'tools'))
import rbxl  # noqa: E402

TOKEN = re.compile(r'\s*(?:(\[\s*"[^"]*"\s*\])|([{}=,])|(-?[0-9.]+(?:e[-+]?[0-9]+)?)|(return)|"([^"]*)")', re.I)


def parse(src):
    """The data modules are `return {["Vertices"]={{x,y,z},...},...}` (string keys, nested lists of numbers); the index maps keys to names."""
    pos, toks = 0, []
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            if src[pos:].strip() == '':
                break
            raise ValueError('unexpected %r' % src[pos:pos + 40])
        pos = m.end()
        if m.group(1):
            toks.append(('key', m.group(1).strip('[] "')))
        elif m.group(2):
            toks.append((m.group(2), None))
        elif m.group(3):
            toks.append(('num', float(m.group(3))))
        elif m.group(5) is not None:
            toks.append(('str', m.group(5)))
    i = 0

    def value():
        nonlocal i
        kind, v = toks[i]
        if kind in ('num', 'str'):
            i += 1
            return v
        assert kind == '{'
        i += 1
        if toks[i][0] == 'key':
            out = {}
            while toks[i][0] != '}':
                k = toks[i][1]
                assert toks[i + 1][0] == '='
                i += 2
                out[k] = value()
                if toks[i][0] == ',':
                    i += 1
            i += 1
            return out
        out = []
        while toks[i][0] != '}':
            out.append(value())
            if toks[i][0] == ',':
                i += 1
        i += 1
        return out
    return value()


place, out = sys.argv[1], sys.argv[2]
inst, parent = rbxl.load(place)
sources = {}
for r, i in inst.items():
    name = i.get('Name', b'').decode('utf-8', 'replace')
    if name.startswith('ApprovedPlantMesh') and 'Source' in i and rbxl.path_of(r, inst, parent)[0] == 'ServerStorage':
        sources[name] = i['Source'].decode('utf-8')
index = parse(sources['ApprovedPlantMeshIndex'])
meshes = {}
for key, module in sorted(index.items()):
    d = parse(sources[module])
    meshes[key] = {'v': d['Vertices'], 'n': d['Normals'], 'c': d['Colors'], 'f': d['Faces']}
json.dump(meshes, open(out, 'w'), separators=(',', ':'))
print('extracted', len(meshes), 'baked meshes from', os.path.basename(place))
