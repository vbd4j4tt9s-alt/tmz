"""Bundle every ReplicatedStorage module of ANY src tree (the base commit's archive or this checkout) for world.luau.
Usage: python3 mkbundle_any.py <src/ReplicatedStorage dir> <out file> [name=path ...]   (extra modules, e.g. PlantArtForestBase=<base path>)"""
import os, sys

src, out = sys.argv[1], sys.argv[2]
pairs = [(f[:-4], os.path.join(src, f)) for f in sorted(os.listdir(src)) if f.endswith('.lua')]
for p in sys.argv[3:]:
    n, path = p.split('=', 1)
    pairs.append((n, path))
parts = ['return {']
for name, path in pairs:
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(out, 'w', encoding='utf-8').write('\n'.join(parts))
print(len(pairs), 'modules')
