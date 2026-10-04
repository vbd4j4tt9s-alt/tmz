"""Bundle every ReplicatedStorage module of THIS checkout (not a fixed path) for world.luau.
Usage: python3 mkbundle_verity.py OUT [extra name=path ...]"""
import sys, os
out = sys.argv[1]
repo = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'))
src = os.path.join(repo, 'src', 'ReplicatedStorage')
pairs = [(f[:-4], os.path.join(src, f)) for f in sorted(os.listdir(src)) if f.endswith('.lua')]
for p in sys.argv[2:]:
    n, path = p.split('=', 1)
    pairs.append((n, path))
parts = ['return {']
for name, path in pairs:
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s: level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(out, 'w', encoding='utf-8').write('\n'.join(parts))
print(len(pairs), 'modules')
