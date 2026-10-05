"""Bundle all ReplicatedStorage modules + chosen client scripts. Usage: python3 mkbundle.py OUT [extra name=path ...]"""
import sys, os
out = sys.argv[1]
src = '/home/user/tmz/src'
# R151: run in place, this bundler bundles the src of the checkout it lives in (it used to bundle the main checkout's from any worktree); a copy of it elsewhere
# (the runners `sed` the literal above into their own checkout's path) keeps the literal
_here = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../../src'))
if os.path.isdir(os.path.join(_here, 'ReplicatedStorage')):
    src = _here
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
