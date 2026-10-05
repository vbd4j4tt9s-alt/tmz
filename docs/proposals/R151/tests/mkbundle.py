"""R151: bundle every ReplicatedStorage module and every ChestChaseServer module of THIS checkout (resolved from this file's location) into
OUT/rs_bundle.luau for the Roblox mock, plus the client scripts the R151 tests load (PullAnnouncerClient, SettingsClient, HudNotices), and write
OUT/srv_names.luau (the server module names, moved under ServerScriptService.ChestChaseServer by the test).
Usage: python3 mkbundle.py OUTDIR [Name=path ...]   (extra pairs override or add modules, e.g. PullAnnouncerClient=/path/to/other.lua)"""
import os
import sys

out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
pairs, server = {}, []
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs[f[:-4]] = src + '/ReplicatedStorage/' + f
for f in sorted(os.listdir(src + '/ServerScriptService/ChestChaseServer')):
    if f.endswith('.lua') and not f.endswith('.server.lua'):
        pairs[f[:-4]] = src + '/ServerScriptService/ChestChaseServer/' + f
        server.append(f[:-4])
for name in ('PullAnnouncerClient', 'SettingsClient', 'HudNotices'):
    pairs[name] = src + '/StarterPlayer/StarterPlayerScripts/' + name + '.client.lua'
for arg in sys.argv[2:]:
    name, path = arg.split('=', 1)
    pairs[name] = path
parts = ['return {']
for name, path in pairs.items():
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
os.makedirs(out, exist_ok=True)
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
open(os.path.join(out, 'srv_names.luau'), 'w').write('return {' + ','.join('"%s"' % n for n in server) + '}')
print(len(pairs), 'modules')
