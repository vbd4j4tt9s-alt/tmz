"""R158 HUD tests: bundle every ReplicatedStorage module of this checkout plus the client scripts the HUD scene runs (the wheel's SettingsClient / ChestIndex / GamePassClient /
DailyRewardsClient, TravelButtons, the Hotbar, the BeginnerTutorial, the TreadmillBonusClient) into OUT_DIR/rs_bundle.luau for the Roblox mock (tools/tests/roblox.luau +
inventory_R113/tests/world.luau).
Usage: python3 mkbundle_hud158.py OUT_DIR [Name=path ...]   (extra pairs replace a module / script: the mutation checks and the "before" copies)"""
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
out = sys.argv[1]
extra = [a for a in sys.argv[2:] if '=' in a]
pairs = {}
for f in sorted(os.listdir(os.path.join(src, 'ReplicatedStorage'))):
    if f.endswith('.lua'):
        pairs[f[:-4]] = os.path.join(src, 'ReplicatedStorage', f)
client = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
for name in ('ChestIndex', 'DailyRewardsClient', 'TravelButtons', 'SettingsClient', 'GamePassClient', 'Hotbar', 'BeginnerTutorial', 'TreadmillBonusClient'):
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
