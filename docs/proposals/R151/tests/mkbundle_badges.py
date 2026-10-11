"""R151 notification badge / default pack shape tests: bundle every ReplicatedStorage module and every ChestChaseServer module of THIS checkout (resolved from this
file's location, or from SRC_DIR when given) into OUT/rs_bundle.luau for the Roblox mock (tools/tests/roblox.luau + docs/proposals/inventory_R113/tests/world.luau),
plus the client scripts the tests load (ChestIndex, DailyRewardsClient, TravelButtons), and write OUT/srv_names.luau (the server module names).
Usage: python3 mkbundle_badges.py OUT_DIR [SRC_DIR] [Name=path ...]
Extra Name=path pairs add or override a module (the "before" side of a comparison: ChestIndex / HudLayout from the base commit; a mutated copy of a module)."""
import os
import sys

out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[2:]
src = os.path.normpath(args[0]) if args and '=' not in args[0] else os.path.normpath(os.path.join(here, '../../../../src'))
extra = [a for a in args if '=' in a]
pairs, server = {}, []
for f in sorted(os.listdir(os.path.join(src, 'ReplicatedStorage'))):
    if f.endswith('.lua'):
        pairs[f[:-4]] = os.path.join(src, 'ReplicatedStorage', f)
srvdir = os.path.join(src, 'ServerScriptService', 'ChestChaseServer')
for f in sorted(os.listdir(srvdir)):
    if f.endswith('.lua') and not f.endswith('.server.lua'):
        pairs[f[:-4]] = os.path.join(srvdir, f)
        server.append(f[:-4])
client = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
for name in ('ChestIndex', 'DailyRewardsClient', 'TravelButtons'):
    pairs[name] = os.path.join(client, name + '.client.lua')
for arg in extra:
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
