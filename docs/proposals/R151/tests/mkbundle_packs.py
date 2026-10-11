"""R151: bundle every ReplicatedStorage module of a source tree, plus the client / server scripts the pack tests run, into OUT/rs_bundle.luau
for the Roblox mock (tools/tests/roblox.luau + docs/proposals/inventory_R113/tests/world.luau).
Usage: python3 mkbundle_packs.py OUT_DIR [SRC_DIR] [Name=path ...]
SRC_DIR defaults to this checkout's src/ (pass a `git archive` of another commit's src to bundle the BEFORE side of a comparison); extra
Name=path pairs override / add a module."""
import os
import sys

out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(sys.argv[2]) if len(sys.argv) > 2 and '=' not in sys.argv[2] else os.path.normpath(os.path.join(here, '../../../../src'))
extra = [a for a in sys.argv[2:] if '=' in a]  # (Name=path pairs; --server adds the server modules)
pairs = {}
for f in sorted(os.listdir(os.path.join(src, 'ReplicatedStorage'))):
    if f.endswith('.lua'):
        pairs[f[:-4]] = os.path.join(src, 'ReplicatedStorage', f)
client = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
for name in ('SeedPackRender', 'SeedPackClient', 'GiantVisualSafety', 'PackOpeningFeedback', 'MysteryPackClient', 'VeiledEventClient81', 'ItemCosmetics'):
    path = os.path.join(client, name + '.client.lua')
    if os.path.exists(path):
        pairs[name] = path
server = os.path.join(src, 'ServerScriptService', 'ChestChaseServer')
for name in ('MysteryPackService', 'PackPlacement', 'PackShapeCommand151'):
    path = os.path.join(server, name + '.lua')
    if os.path.exists(path):
        pairs[name] = path
server_names = []
if '--server' in sys.argv:
    # R151 (pack shapes): every ChestChaseServer module too (the real PlayerDataService / ChestService / ChaseService / MysteryPackService ...), and OUT/srv_names.luau
    # (their names, moved under ServerScriptService.ChestChaseServer by the test)
    for f in sorted(os.listdir(server)):
        if f.endswith('.lua') and not f.endswith('.server.lua'):
            pairs[f[:-4]] = os.path.join(server, f)
            server_names.append(f[:-4])
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
if server_names:
    open(os.path.join(out, 'srv_names.luau'), 'w').write('return {' + ','.join('"%s"' % n for n in server_names) + '}')
print(len(pairs), 'modules')
