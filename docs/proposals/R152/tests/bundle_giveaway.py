"""Bundle every ReplicatedStorage module, every ChestChaseServer module and the giveaway pedestal's client script, from ANY src tree (this checkout's, or a mutated
copy for the mutation checks), for the R152 Void Pack giveaway suites and preview (giveaway_harness.luau on top of the R150 pedestal harness and the R149 zfight_world mock).
Usage: python3 bundle_giveaway.py <src dir> <out dir>      writes <out>/rs_bundle.luau and <out>/srv_names.luau"""
import os, sys

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
