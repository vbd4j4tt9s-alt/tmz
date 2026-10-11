"""R151 speed popups: bundle every ReplicatedStorage module of THIS checkout (resolved from this file's location) plus the REAL SpeedGainPopup client script into
OUT/rs_bundle.luau for the Roblox mock (the R123 world loads each entry lazily as a ModuleScript / script source).
Usage: python3 mkbundle_speed_popups.py OUTDIR [Name=path ...]   (extra pairs override or add entries, e.g. SpeedGainPopup=/path/to/mutant.lua)"""
import os
import sys

out = sys.argv[1]
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.normpath(os.path.join(here, '../../../../src'))
pairs = {}
for f in sorted(os.listdir(src + '/ReplicatedStorage')):
    if f.endswith('.lua'):
        pairs[f[:-4]] = src + '/ReplicatedStorage/' + f
pairs['SpeedGainPopup'] = src + '/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua'
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
print(len(pairs), 'modules')
