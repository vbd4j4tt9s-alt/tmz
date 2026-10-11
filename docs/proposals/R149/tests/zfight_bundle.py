"""Bundle every ReplicatedStorage module, every ChestChaseServer module and the client scripts that put parts in the world, from ANY
src tree (this checkout's, or the R148 release's for the 'before' numbers), for the z-fighting scene (zfight_scene.luau).
Usage: python3 zfight_bundle.py <src dir> <out dir>      writes <out>/rs_bundle.luau and <out>/srv_names.luau
The server modules are moved under ServerScriptService.ChestChaseServer by the scene (script.Parent.X works); the client scripts are
loaded by name (KeyboardTrackClient, SnowBiome, ...) like the R147 / R149 suites do."""
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
clients = {'KeyboardTrackClient': 'KeyboardTrack.client.lua', 'SnowBiome': 'SnowBiome149.client.lua'}
sp = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
for name, f in clients.items():
    if os.path.exists(os.path.join(sp, f)):
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
