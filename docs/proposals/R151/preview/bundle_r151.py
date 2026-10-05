"""R151 base area preview: bundle the game's modules (docs/proposals/R149/tests/zfight_bundle.py: every ReplicatedStorage module, every
ChestChaseServer module, the keyboard client) from a src tree, plus this folder's scratch builder HubDressing151.luau as the ReplicatedStorage
module 'HubDressing151' (design prototype only - it is NOT in src/ and is not shipped).
Usage: python3 bundle_r151.py <src dir> <out dir>"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
src, out = sys.argv[1], sys.argv[2]
subprocess.check_call([sys.executable, os.path.join(REPO, 'docs', 'proposals', 'R149', 'tests', 'zfight_bundle.py'), src, out],
                      stdout=subprocess.DEVNULL)
path = os.path.join(out, 'rs_bundle.luau')
text = open(path, encoding='utf-8').read().rstrip()
assert text.endswith('}')
extra = []
for name in ('HubDressing151',):
    s = open(os.path.join(HERE, name + '.luau'), encoding='utf-8').read()
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    extra.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
open(path, 'w', encoding='utf-8').write(text[:-1] + '\n'.join(extra) + '\n}')
print('bundled + HubDressing151')
