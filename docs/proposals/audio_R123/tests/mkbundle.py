"""Bundle every ReplicatedStorage module plus the client scripts under test into OUT/rs_bundle.luau.
Usage: python3 mkbundle.py OUTDIR [Name=path ...]  (extra pairs override / add, e.g. a base copy of a script)."""
import sys, os
out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
pairs = {}
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs[f[:-4]] = src + '/ReplicatedStorage/' + f
for n in ('TrackRefreshSky', 'ChestRunAlert', 'NotificationClient83', 'TrackHoleClient'):
    pairs[n] = src + '/StarterPlayer/StarterPlayerScripts/' + n + '.client.lua'
for arg in sys.argv[2:]:
    k, v = arg.split('=', 1); pairs[k] = v
parts = ['return {']
for name, path in pairs.items():
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s: level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
print(len(pairs), 'modules')
