"""Bundle every ReplicatedStorage module of THIS checkout (resolved from this file's location, never a hard-coded path) plus the client / server
scripts named on the command line into OUT/rs_bundle.luau.
Usage: python3 mkbundle.py OUTDIR [Name=path ...]   (paths are relative to src/ or absolute; the word all-client adds every StarterPlayerScripts script)"""
import sys, os
out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
pairs = {}
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs[f[:-4]] = src + '/ReplicatedStorage/' + f
for arg in sys.argv[2:]:
    if arg == 'all-client':
        d = src + '/StarterPlayer/StarterPlayerScripts'
        for f in sorted(os.listdir(d)):
            if f.endswith('.client.lua'):
                pairs[f[:-11]] = d + '/' + f
        continue
    k, v = arg.split('=', 1)
    pairs[k] = v if os.path.isabs(v) else os.path.join(src, v)
parts = ['return {']
for name, path in pairs.items():
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
print(len(pairs), 'modules')
