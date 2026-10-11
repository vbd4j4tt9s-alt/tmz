"""Bundle every ReplicatedStorage module, every ChestChaseServer module and the giveaway pedestal's client script, from ANY src tree (this checkout's, or a mutated
copy for the mutation checks), for the R152 Void Pack giveaway suites and preview (giveaway_harness.luau on top of the R150 pedestal harness and the R149 zfight_world mock).
Usage: python3 bundle_giveaway.py <src dir> <out dir>      writes <out>/rs_bundle.luau and <out>/srv_names.luau"""
import os, subprocess, sys

src, out = sys.argv[1], sys.argv[2]
pairs, server = [], []
rs = os.path.join(src, 'ReplicatedStorage')
for f in sorted(os.listdir(rs)):
    if f.endswith('.lua'):
        pairs.append((f[:-4], os.path.join(rs, f)))
srv = os.path.join(src, 'ServerScriptService', 'ChestChaseServer')
for f in sorted(os.listdir(srv)):
    if f.endswith('.lua') and not f.endswith('.server.lua'):
        pairs.append((f[:-4], os.path.join(srv, f))); server.append(f[:-4])
sp = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
pairs.append(('VoidGiveawayClient152', os.path.join(sp, 'VoidGiveawayClient152.client.lua')))
# The R151 release's PlayerDataService (git history, 24ed94b = R151 as handed over), as PlayerDataServiceR151 (not in srv_names: test_giveaway_real loads it by hand to prove an R151
# server ignores the optional GiftLocked field). Without the history that test says SKIP.
try:
    old = subprocess.run(['git', '-C', os.path.dirname(os.path.abspath(__file__)), 'show', '24ed94b:src/ServerScriptService/ChestChaseServer/PlayerDataService.lua'], capture_output=True, timeout=60)
except Exception:
    old = None
if old is not None and old.returncode == 0 and old.stdout:
    scratch = os.path.join(out, 'r151_PlayerDataService.lua')
    open(scratch, 'wb').write(old.stdout)
    pairs.append(('PlayerDataServiceR151', scratch))
parts = ['return {']
for name, path in pairs:
    s = open(path, 'rb').read().decode('utf-8')
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    parts.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
parts.append('}')
open(os.path.join(out, 'rs_bundle.luau'), 'w', encoding='utf-8').write('\n'.join(parts))
open(os.path.join(out, 'srv_names.luau'), 'w').write('return {' + ','.join('"%s"' % n for n in server) + '}')
print(len(pairs), 'modules')
