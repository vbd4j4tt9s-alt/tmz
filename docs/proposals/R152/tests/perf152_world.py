"""R152 performance patch: builds the hub + keyboard world of run_perf152.sh for one src tree.
Usage: python3 perf152_world.py <src dir> <out dir> <place_tree.luau>
Writes <out>/rs_bundle.luau (zfight_bundle.py: every ReplicatedStorage and ChestChaseServer module + the keyboard / snow clients, plus the hub clients
HubLife151, HubDisplayClient and VoidGiveawayClient152 loaded by name), the mock files, and <out>/scene.luau: the R152 z-fight sweep's scene (R149
zfight_scene.luau: the owner's place with every real start-up builder and the keyboard client; R151 make_hub_scene.py: the two hub displays; R152
zfight_sweep_extra.luau: the Void giveaway pedestal) with the ClientFxBudget tier taken from the TIER global, random numbers seeded, and its z-fight dump
replaced by perf152_world.luau (the fingerprints and the per-frame numbers)."""
import os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
src, out, tree = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(out, exist_ok=True)
P = os.path.join(REPO, 'docs', 'proposals')
subprocess.check_call([sys.executable, os.path.join(P, 'R149', 'tests', 'zfight_bundle.py'), src, out], stdout=subprocess.DEVNULL)
bundle = os.path.join(out, 'rs_bundle.luau')
text = open(bundle, encoding='utf-8').read().rstrip()
assert text.endswith('}')
sp = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
extra = []
for name, f in (('HubLife151Client', 'HubLife151.client.lua'), ('HubDisplayClient', 'HubDisplayClient.client.lua'), ('VoidGiveawayClient152', 'VoidGiveawayClient152.client.lua')):
    s = open(os.path.join(sp, f), encoding='utf-8').read()
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    extra.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
open(bundle, 'w', encoding='utf-8').write(text[:-1] + '\n'.join(extra) + '\n}')
for f in (os.path.join(REPO, 'tools', 'tests', 'roblox.luau'), os.path.join(P, 'inventory_R113', 'tests', 'world.luau'), os.path.join(P, 'R149', 'tests', 'zfight_world.luau'),
          os.path.join(P, 'R151', 'tests', 'hub_rig.luau'), os.path.join(HERE, 'perf152_fp.luau'), os.path.join(P, 'inventory_R113', 'tests', 'fixtures.luau')):
    shutil.copy(f, out)
if os.path.abspath(tree) != os.path.abspath(os.path.join(out, 'place_tree.luau')):
    shutil.copy(tree, os.path.join(out, 'place_tree.luau'))
tmp = os.path.join(out, 'sweep_scene.luau')
subprocess.check_call([sys.executable, os.path.join(HERE, 'make_sweep_scene.py'), os.path.join(P, 'R149', 'tests', 'zfight_scene.luau'), tmp], stdout=subprocess.DEVNULL)
s = open(tmp, encoding='utf-8').read()
old = "W.stub('ClientFxBudget',{Get=function()return 3 end,Low=function()return false end})"
assert s.count(old) == 1, 'ClientFxBudget stub not found'
s = s.replace(old, "W.stub('ClientFxBudget',{Get=function()return TIER or 3 end,Low=function()return(TIER or 3)==1 end})")
marker = '-- Where a camera can be:'
assert s.count(marker) == 1
s = s[:s.index(marker)] + open(os.path.join(HERE, 'perf152_world.luau'), encoding='utf-8').read()
s = s.replace('--!nocheck\n', '--!nocheck\nmath.randomseed(152)\n', 1)
# the published pack meshes (R113 fixtures: the market showcase, the giveaway's Void pack) and a Clone that keeps attributes and the PrimaryPart, as Roblox's does
old = "local RS=W.RS\n"
assert s.count(old) >= 1
s = s.replace(old, old + open(os.path.join(HERE, 'perf152_world_pre.luau'), encoding='utf-8').read(), 1)
open(os.path.join(out, 'scene.luau'), 'w', encoding='utf-8').write(s)
print('world ready in', out)
