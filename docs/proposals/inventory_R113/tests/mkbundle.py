"""Bundle all ReplicatedStorage modules + chosen client scripts. Usage: python3 mkbundle.py OUT [extra name=path ...]"""
import sys, os
out = sys.argv[1]
src = '/home/user/tmz/src'
pairs = []
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs.append((f[:-4], src + '/ReplicatedStorage/' + f))
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
