"""R153 lag audit: builds the census world (R152 perf152_world.py: the owner's place + every real start-up builder + the keyboard / snow / hub clients)
for one src tree, with lag153_census.luau in place of perf152_world.luau's shots.
Usage: python3 lag153_world.py <src dir> <out dir> <place_tree.luau>      then: cd <out dir> && luau run.luau (with TIER / SPOT / RUNNER globals first)"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
src, out, tree = sys.argv[1], sys.argv[2], sys.argv[3]
R152 = os.path.join(REPO, 'docs', 'proposals', 'R152', 'tests')
subprocess.check_call([sys.executable, os.path.join(R152, 'perf152_world.py'), src, out, tree], stdout=subprocess.DEVNULL)
# every client script as 'Client_<name>' (lag153_census.luau loads them all when ALLCLIENT is set)
bundle = os.path.join(out, 'rs_bundle.luau')
text = open(bundle, encoding='utf-8').read().rstrip()
assert text.endswith('}')
sp = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
extra, names = [], []
for f in sorted(os.listdir(sp)):
    if not f.endswith('.client.lua'):
        continue
    s = open(os.path.join(sp, f), encoding='utf-8').read()
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    extra.append('["Client_%s"]=[%s[\n%s]%s],' % (f[:-11], eq, s, eq))
    names.append(f[:-11])
open(bundle, 'w', encoding='utf-8').write(text[:-1] + '\n'.join(extra) + '\n}')
open(os.path.join(out, 'client_names.luau'), 'w').write('return {' + ','.join('"%s"' % n for n in names) + '}')
scene = os.path.join(out, 'scene.luau')
s = open(scene, encoding='utf-8').read()
marker = "local FP=require('./perf152_fp')(W);FP.orderedPairs()"
assert s.count(marker) == 1, 'perf152 tail not found'
s = s[:s.index(marker)] + open(os.path.join(HERE, 'lag153_census.luau'), encoding='utf-8').read()
open(os.path.join(out, 'census.luau'), 'w', encoding='utf-8').write(s)
print('census world ready in', out)
