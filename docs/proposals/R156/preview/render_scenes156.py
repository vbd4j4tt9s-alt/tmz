"""R156 preview: the SCENE lines of pity_scene156.luau (one log per view x mode) -> PNGs with headless Chromium (R155's render_gui155.mjs).
Usage: python3 render_scenes156.py SCRATCH     -> SCRATCH/png/<view>-<mode>_<scene>.png (a scene is drawn at 2x, the close-ups at 3x; the sheet maker scales them)
The clover picture (SCRATCH/clover.png, decoded by decode_clover156.py from the game's CloverPassImage153) is the image every ImageLabel marked as having one draws."""
import base64
import json
import os
import subprocess
import sys

S = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
R155 = os.path.join(HERE, '..', '..', 'R155', 'preview')
FONTS = os.path.join(S, 'fonts', 'node_modules', '@fontsource', 'fredoka-one', 'files')
SKY = 'linear-gradient(180deg,#7fc3ee 0%,#c4e6fa 44%,#86c46a 45%,#4f9a4a 100%)'
clover = 'data:image/png;base64,' + base64.b64encode(open(os.path.join(S, 'clover.png'), 'rb').read()).decode('ascii')
scenes = []
for view in ('pc', 'land', 'port'):
    for mode in ('current', 'fresh', 'deep'):
        for line in open(os.path.join(S, '%s-%s' % (view, mode), 'scenes.log'), encoding='utf-8'):
            if not line.startswith('SCENE '):
                continue
            parts = line.rstrip('\n').split(' ', 7)
            name, x, y, cw, ch, scale = parts[1:7]
            scenes.append({'name': '%s-%s_%s' % (view, mode, name), 'json': parts[7], 'scale': 2.0 if float(scale) == 1 else float(scale), 'bg': SKY,
                           'crop': [int(x), int(y), int(cw), int(ch)], 'img': clover})
# the bars over other worlds than the grass (a green bar on a green garden is the hard case, the rest are the biomes' sand / snow and the night)
BACKDROPS = {'sand': '#d8c48e', 'snow': '#e9f1f7', 'night': '#141a30'}
for sc in list(scenes):
    if sc['name'].endswith('_pc_zoom_99') and not sc['name'].startswith('pc-current'):
        for key, color in BACKDROPS.items():
            scenes.append(dict(sc, name=sc['name'] + '_' + key, bg=color))
os.makedirs(os.path.join(S, 'png'), exist_ok=True)
with open(os.path.join(S, 'scenes.json'), 'w', encoding='utf-8') as f:
    json.dump(scenes, f)
subprocess.run(['node', os.path.join(R155, 'render_gui155.mjs'), os.path.join(S, 'scenes.json'), os.path.join(S, 'png'), FONTS if os.path.isdir(FONTS) else ''], check=True)
