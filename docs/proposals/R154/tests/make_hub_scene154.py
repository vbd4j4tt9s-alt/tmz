"""R154 hub z-fighting: builds hub154_scene.luau, the WHOLE hub as players see it, for check_hub_zfight154.py.
Start: R151's base area scene (docs/proposals/R151/preview/base_area_scene.luau: the owner's place in the R149 Roblox mock, the REAL start-up builders through
MapService.new - ZFightFix149, MarketLayout, GardenBaseLayout, HubDecor151 with the trampolines, R154's HubZFix154 -, the six treadmills, the garden fences,
the mystery pedestals, Verity's dais, the leaderboards, the keyboard client around a runner at the gate and the REAL HubLife151 client with every detail
level shown). Added before the dump, as the R152 sweep adds them to the R149 map scene:
  * the two hub displays through the REAL HubDisplayService (docs/proposals/R151/tests/make_hub_scene.py's block: pedestal, showcase item, giant avatar);
  * the Void Pack giveaway pedestal (docs/proposals/R152/tests/zfight_sweep_extra.luau: the REAL VoidGiveaway152 on the south plaza).
Usage: python3 make_hub_scene154.py <base_area_scene.luau> <out hub154_scene.luau>"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
P = os.path.normpath(os.path.join(HERE, '..', '..'))
src, out = sys.argv[1], sys.argv[2]
s = open(src, encoding='utf-8').read()

# the displays block, as make_hub_scene.py writes it (one source for it): run it on a stub that has only its two markers
MARK = "-- Where a camera can be:"
AREA = "local function areaOf(p)\n local path=Z.path(p)\n"
fd, stub = tempfile.mkstemp(suffix='.luau')
os.write(fd, (MARK + "\n" + AREA).encode('utf-8'))
os.close(fd)
made = stub + '.out'
subprocess.run([sys.executable, os.path.join(P, 'R151', 'tests', 'make_hub_scene.py'), stub, made], check=True, stdout=subprocess.DEVNULL)
displays = open(made, encoding='utf-8').read().split(MARK)[0]
os.remove(stub)
os.remove(made)
assert "step('HubDisplays'" in displays, 'the displays block was not found'
giveaway = open(os.path.join(P, 'R152', 'tests', 'zfight_sweep_extra.luau'), encoding='utf-8').read()

dump = "-- Dump -----"
assert s.count(dump) == 1, 'dump marker not found'
block = ("-- R154: the hub displays and the Void giveaway pedestal (built server-side in the game; here after the client layer, as the R152 sweep does)\n"
         "Run.IsClient=function()return false end;Run.IsServer=function()return true end\n" + displays + giveaway +
         "Run.IsClient=function()return true end;Run.IsServer=function()return false end\nR.advance(.5)\n")
s = s.replace(dump, block + dump)
old = AREA
assert s.count(old) == 1, 'areaOf not found'
s = s.replace(old, old + " if path:find('HubDisplays151',1,true)then return'hubdisplay'end\n if path:find('VoidGiveaway152',1,true)then return'giveaway'end\n")
open(out, 'w', encoding='utf-8').write(s)
print('wrote', out)
