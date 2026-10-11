"""Bundle every ReplicatedStorage module, every ChestChaseServer module and the client scripts the Cloudy-sky suites run, from ANY src tree (this checkout's, or a
mutated copy for the mutation checks), for the R151 Cloudy suites (run_cloudy.sh) on the inventory_R113 mock world (world.luau + roblox.luau).
Usage: python3 bundle_cloudy.py <src dir> <out dir>      writes <out>/rs_bundle.luau and <out>/srv_names.luau"""
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
        pairs.append((f[:-4], os.path.join(srv, f)))
        server.append(f[:-4])
sp = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
for name, f in (('WorldEvents', 'WorldEvents.client.lua'), ('BiomePresentation', 'BiomePresentation.client.lua'),
                ('HubLife151Client', 'HubLife151.client.lua'), ('WeatherWorld', 'WeatherWorld149.client.lua'),
                ('BiomeAmbience', 'BiomeAmbience.client.lua'), ('KeyboardTrackClient', 'KeyboardTrack.client.lua')):
    pairs.append((name, os.path.join(sp, f)))
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
