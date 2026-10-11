"""Bundle the two client scripts of the R158l party commands (the disco and the falling packs) as strings, for test_party158l.luau (the R152 bundle holds only the server modules and the
ReplicatedStorage ones). Usage: python3 bundle_party158l.py <src dir> <out dir>      writes <out>/party_clients.luau"""
import os, sys

src, out = sys.argv[1], sys.argv[2]
parts = ['return {']
for name in ('DiscoClient158l', 'PackRainFx158l'):
    s = open(os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts', name + '.client.lua'), 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(os.path.join(out, 'party_clients.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
print(2, 'client scripts')
