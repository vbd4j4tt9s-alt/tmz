"""R153 belt test bundle: the R149 z-fighting bundle of a src tree (every ReplicatedStorage and ChestChaseServer module) plus the chevrons' own code, the "V134 forward arrows and biome
track motion" block that closes StarterPlayerScripts/SpeedGainPopup.client.lua, as the module 'BeltArrows' (a chunk that runs the block when loaded). The test loads it next to
TreadmillFx so the arrows and the belt pattern run in one world, on the same frames, and are compared.
Usage: python3 mkbundle_belt.py <src dir> <out dir>"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
src, out = sys.argv[1], sys.argv[2]
subprocess.check_call([sys.executable, os.path.join(REPO, 'docs', 'proposals', 'R149', 'tests', 'zfight_bundle.py'), src, out], stdout=subprocess.DEVNULL)
text = open(os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts', 'SpeedGainPopup.client.lua'), encoding='utf-8').read()
start = text.index('\ndo\n-- V134: broad forward arrows') + 1
mark = text.index("print('[V134] PASS", start)
end = text.index('\nend\n', mark) + 5
block = text[start:end]
assert block.count('\ndo\n') == 0 and 'Heartbeat' in block and 'TrackRest' in block, 'the V134 block was not cut cleanly'
bundle = os.path.join(out, 'rs_bundle.luau')
body = open(bundle, encoding='utf-8').read().rstrip()
assert body.endswith('}')
level = 1
while (']' + '=' * level + ']') in block:
    level += 1
eq = '=' * level
open(bundle, 'w', encoding='utf-8').write(body[:-1] + '["BeltArrows"]=[%s[\n%s]%s],\n}' % (eq, block, eq))
print('bundled + BeltArrows (%d lines of SpeedGainPopup.client.lua)' % block.count('\n'))
