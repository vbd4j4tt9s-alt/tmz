"""Game data for the renders, read from the repo's own Lua sources (no Blender needed).

cfg   : KeeperRigConfig's table (stages 1-7, the uploaded-mesh rigs), with the V110 dragon-wing stretch applied exactly as
        the module does at require time (x1.35 about each wing hinge: Parts, Bounds, FloorSamples).
upg   : KeeperUpgradeData (the native biped rigs that replace stages 1, 5 and 7 in game).
poses : group frames from the REAL pose modules (BeastPose, KeeperSignatureStrike, VeiledKeeper81) and the real
        KeeperAccents parts, dumped by dump_poses.luau on the repo's Roblox mock (see run.sh).
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..', '..'))
sys.path.insert(0, HERE)
from luaparse import P  # noqa: E402


def _table_after(text, start):
    p = P(text)
    p.i = start
    return p.table()


def load_cfg():
    src = open(os.path.join(REPO, 'src', 'ReplicatedStorage', 'KeeperRigConfig.lua')).read()
    line = src.split('\n')[1]
    cfg = _table_after(line, line.find('{'))
    dragon = cfg[4]
    f = 1.35  # V110: dragon.WingScale

    def stretch(pt, pv):
        return [pv[i] + (pt[i] - pv[i]) * f for i in range(3)]
    for g in ('LeftWing', 'RightWing'):
        pv = dragon['Pivots'][g]
        b = dragon['Bounds'][g]
        dragon['Bounds'][g] = [stretch(b[0], pv), stretch(b[1], pv)]
        dragon['FloorSamples'][g] = [stretch(p, pv) for p in dragon['FloorSamples'][g]]
        for part in dragon['Parts']:
            if part['Group'] == g:
                part['Center'] = stretch(part['Center'], pv)
                part['Size'] = [s * f for s in part['Size']]
    return {str(k): v for k, v in cfg.items()}


def load_upg():
    src = open(os.path.join(REPO, 'src', 'ReplicatedStorage', 'KeeperUpgradeData.lua')).read()
    upg = _table_after(src, src.find('return {') + 7)
    return {str(k): v for k, v in upg.items()}


def load_poses(path):
    return json.load(open(path))
