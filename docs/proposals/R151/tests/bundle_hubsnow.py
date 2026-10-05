"""R151 hub snow / performance: bundle a src tree for the Roblox mock - every ReplicatedStorage module and ChestChaseServer module
(docs/proposals/R149/tests/zfight_bundle.py) plus the client scripts the hub snow and the perf harness run (WeatherWorld149, WorldEvents,
SnowBiome149, KeyboardTrack, HubLife151 when present). Works for any src tree (this checkout, or the base commit's for the 'before' numbers).
Usage: python3 bundle_hubsnow.py <src dir> <out dir>"""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
src, out = sys.argv[1], sys.argv[2]
subprocess.check_call([sys.executable, os.path.join(REPO, 'docs', 'proposals', 'R149', 'tests', 'zfight_bundle.py'), src, out],
                      stdout=subprocess.DEVNULL)
path = os.path.join(out, 'rs_bundle.luau')
text = open(path, encoding='utf-8').read().rstrip()
assert text.endswith('}')
sp = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')
extra = []
for name, f in (('WeatherWorld', 'WeatherWorld149.client.lua'), ('WorldEvents', 'WorldEvents.client.lua'),
                ('StormWeather', 'StormWeather.client.lua'), ('HubLife151Client', 'HubLife151.client.lua')):
    p = os.path.join(sp, f)
    if not os.path.exists(p):
        continue
    s = open(p, encoding='utf-8').read()
    level = 1
    while (']' + '=' * level + ']') in s:
        level += 1
    eq = '=' * level
    extra.append('["%s"]=[%s[\n%s]%s],' % (name, eq, s, eq))
open(path, 'w', encoding='utf-8').write(text[:-1] + '\n'.join(extra) + '\n}')
print('bundled', src)
