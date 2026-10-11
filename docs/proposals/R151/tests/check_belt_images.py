"""R151 treadmill polish: the belt images the game draws (the "ALPHA name w h hex" lines of test_treadmills151.luau: TreadmillBeltArt151.Pattern on
the mock) must equal, byte for byte, the PNGs shipped for upload (docs/proposals/R151/treadmills/textures/*.png) and what make_belt_textures.py
writes now. Usage: python3 check_belt_images.py <test log> <repo> <scratch dir>   (exit 1 on any difference)"""
import os, subprocess, sys
from PIL import Image

log, repo, out = sys.argv[1], sys.argv[2], sys.argv[3]
here = os.path.join(repo, 'docs', 'proposals', 'R151', 'treadmills')
os.makedirs(out, exist_ok=True)
subprocess.check_call([sys.executable, os.path.join(here, 'make_belt_textures.py'), out, '--alpha', os.path.join(out, 'alpha_py.txt')],
                      stdout=subprocess.DEVNULL)
game = {}
for line in open(log, encoding='utf-8'):
    if line.startswith('ALPHA '):
        _, name, w, h, hx = line.split()
        game[name] = (int(w), int(h), bytes.fromhex(hx))
py = {}
for line in open(os.path.join(out, 'alpha_py.txt')):
    if line.strip():
        name, w, h, hx = line.split()
        py[name] = (int(w), int(h), bytes.fromhex(hx))
fails = 0
for name in ('slats', 'circuit', 'crust', 'veins', 'stream'):
    png = Image.open(os.path.join(here, 'textures', name + '.png')).convert('RGBA')
    w, h = png.size
    alpha = png.getchannel('A').tobytes()
    raw = png.tobytes()
    white = all(raw[i:i + 3] == b'\xff\xff\xff' for i in range(0, len(raw), 4) if raw[i + 3] > 0)
    g = game.get(name)
    same_game = g is not None and g[0] == w and g[1] == h and g[2] == alpha
    same_py = py[name][2] == alpha
    ok = same_game and same_py and white
    if not ok:
        fails += 1
    lit = sum(1 for a in alpha if a)
    print('%s %-8s %dx%d: game == PNG %s, generator == PNG %s, white %s (%d lit pixels)' % ('ok  ' if ok else 'FAIL', name, w, h, same_game, same_py, white, lit))
print('belt images: %s' % ('the game draws exactly the shipped PNGs' if not fails else '%d differ' % fails))
sys.exit(1 if fails else 0)
