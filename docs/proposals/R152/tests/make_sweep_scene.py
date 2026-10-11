"""Builds sweep_scene.luau for run_zfight_sweep.sh: R151's hub scene (make_hub_scene.py on R149's whole-map zfight_scene.luau: the real start-up builders on the owner's place + the two hub
displays) plus zfight_sweep_extra.luau (the Void giveaway pedestal, the keyboard grid printout) injected before the dump.
Usage: python3 make_sweep_scene.py <R149 zfight_scene.luau> <out sweep_scene.luau>"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
src, out = sys.argv[1], sys.argv[2]
tmp = tempfile.mktemp(suffix='.luau')
subprocess.run([sys.executable, os.path.join(HERE, '..', '..', 'R151', 'tests', 'make_hub_scene.py'), src, tmp], check=True, stdout=subprocess.DEVNULL)
s = open(tmp, encoding='utf-8').read()
os.remove(tmp)
extra = open(os.path.join(HERE, 'zfight_sweep_extra.luau'), encoding='utf-8').read()
marker = "-- Where a camera can be:"
assert s.count(marker) == 1, 'marker not found'
s = s.replace(marker, extra + marker)
old = "local function areaOf(p)\n local path=Z.path(p)\n"
assert s.count(old) == 1, 'areaOf not found'
s = s.replace(old, old + " if path:find('VoidGiveaway152',1,true)then return'giveaway'end\n")
open(out, 'w', encoding='utf-8').write(s)
print('wrote', out)
