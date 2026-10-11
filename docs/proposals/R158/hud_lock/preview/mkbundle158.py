"""R158 HUD-lock preview: bundle every ReplicatedStorage module of a source tree plus the client scripts the preview loads (the wheel's SettingsClient / ChestIndex /
GamePassClient / DailyRewardsClient, TravelButtons and the Hotbar) into OUT/rs_bundle.luau for the Roblox mock (tools/tests/roblox.luau + inventory_R113/tests/world.luau).
Usage: python3 mkbundle158.py OUT_DIR SRC_DIR [Name=path ...]   (extra pairs override a module / script: the patched HudLayout copies of make_variants158.py)"""
import os
import sys

out, src = sys.argv[1], os.path.normpath(sys.argv[2])
extra = [a for a in sys.argv[3:] if '=' in a]
pairs = {}
for f in sorted(os.listdir(os.path.join(src, 'ReplicatedStorage'))):
    if f.endswith('.lua'):
        pairs[f[:-4]] = os.path.join(src, 'ReplicatedStorage', f)
client = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
for name in ('ChestIndex', 'DailyRewardsClient', 'TravelButtons', 'SettingsClient', 'GamePassClient', 'Hotbar'):
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
print(len(pairs), 'modules')
