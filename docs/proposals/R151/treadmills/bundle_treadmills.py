"""R151 treadmill look PROPOSAL (preview only): bundle the game's modules from a src tree (docs/proposals/R149/tests/zfight_bundle.py:
every ReplicatedStorage module and every ChestChaseServer module) plus this folder's prototype TreadmillDress151.luau as the
ReplicatedStorage module 'TreadmillDress151'. The prototype is NOT in src/ and is not shipped: it only exists to draw the previews.
Usage: python3 bundle_treadmills.py <src dir> <out dir>"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
src, out = sys.argv[1], sys.argv[2]
subprocess.check_call([sys.executable, os.path.join(REPO, 'docs', 'proposals', 'R149', 'tests', 'zfight_bundle.py'), src, out],
                      stdout=subprocess.DEVNULL)
bundle = os.path.join(out, 'rs_bundle.luau')
text = open(bundle, encoding='utf-8').read().rstrip()
assert text.endswith('}')
s = open(os.path.join(HERE, 'TreadmillDress151.luau'), encoding='utf-8').read()
level = 1
while (']' + '=' * level + ']') in s:
    level += 1
eq = '=' * level
open(bundle, 'w', encoding='utf-8').write(text[:-1] + '["TreadmillDress151"]=[%s[\n%s]%s],\n}' % (eq, s, eq))
print('bundled + TreadmillDress151')
