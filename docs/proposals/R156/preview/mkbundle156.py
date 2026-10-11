"""Bundle every ReplicatedStorage module of a src tree plus the client scripts into OUT/rs_bundle.luau for the Roblox mock.
A copy of R150's mkbundle_sfx.py that takes the src tree as an argument, so the preview can bundle a scratch copy with the look change applied (src/ itself stays unchanged).
Usage: python3 mkbundle156.py SRC OUTDIR [Name=path ...]   (paths are relative to SRC or absolute; the word all-client adds every StarterPlayerScripts script)"""
import os
import sys

src, out = os.path.abspath(sys.argv[1]), sys.argv[2]
pairs = {}
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs[f[:-4]] = src + '/ReplicatedStorage/' + f
for arg in sys.argv[3:]:
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
