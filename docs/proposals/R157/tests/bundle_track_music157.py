"""Bundle for run_track_music157.sh: R149's z-fighting bundle of a src tree (every ReplicatedStorage module, every ChestChaseServer module) plus the music script to test
as the client script 'BackgroundMusic' (this checkout's, a broken copy's, or the R156 release's).
Usage: python3 bundle_track_music157.py <src dir> <out dir> <BackgroundMusic.client.lua>      writes <out>/rs_bundle.luau and <out>/srv_names.luau"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
src, out, music = sys.argv[1:4]
subprocess.run([sys.executable, os.path.join(HERE, '..', '..', 'R149', 'tests', 'zfight_bundle.py'), src, out], check=True, stdout=subprocess.DEVNULL)
path = os.path.join(out, 'rs_bundle.luau')
bundle = open(path, encoding='utf-8').read()
assert bundle.rstrip().endswith('}')
s = open(music, 'rb').read().decode('utf-8')
level = 1
while (']' + '=' * level + ']') in s:
    level += 1
eq = '=' * level
bundle = bundle.rstrip()[:-1] + '["BackgroundMusic"]=[%s[\n%s]%s],\n}' % (eq, s, eq)
open(path, 'w', encoding='utf-8').write(bundle)
print('bundled', music)
