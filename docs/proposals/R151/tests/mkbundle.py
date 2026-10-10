"""R151: bundle every ReplicatedStorage module and every ChestChaseServer module of THIS checkout (resolved from this file's location) into
OUT/rs_bundle.luau for the Roblox mock, plus the client scripts the R151 tests load (PullAnnouncerClient, SettingsClient), and write
OUT/srv_names.luau (the server module names, moved under ServerScriptService.ChestChaseServer by the test).
When the repository history has the R150 release, its PlayerDataService is added as PlayerDataServiceR150 (not in srv_names: test_server loads it by hand to prove that an
R150 server can load and re-save a pack row that has the R151 TestGrant field). Without the history that test says SKIP.
Usage: python3 mkbundle.py OUTDIR [Name=path ...]   (extra pairs override or add modules, e.g. PullAnnouncerClient=/path/to/other.lua)"""
import os
import subprocess
import sys

R150_COMMIT = 'a1390a7'  # the last R150 commit: Config.Version 'V150 R150', ProfileVersion 22

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
for name in ('PullAnnouncerClient', 'SettingsClient'):
    pairs[name] = src + '/StarterPlayer/StarterPlayerScripts/' + name + '.client.lua'
try:
    old = subprocess.run(['git', '-C', src, 'show', R150_COMMIT + ':src/ServerScriptService/ChestChaseServer/PlayerDataService.lua'], capture_output=True, timeout=60)
except Exception:
    old = None
if old is not None and old.returncode == 0 and old.stdout:
    os.makedirs(out, exist_ok=True)
    scratch = os.path.join(out, 'r150_PlayerDataService.lua')
    open(scratch, 'wb').write(old.stdout)
    pairs['PlayerDataServiceR150'] = scratch
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
