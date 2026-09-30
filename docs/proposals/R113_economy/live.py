"""Loads the LIVE (R112) economy dumped from the real modules (econ_live.tsv, produced by dump_economy.luau)."""
import os, collections
HERE = os.path.dirname(os.path.abspath(__file__))
TIERS = ['Common', 'Uncommon', 'Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
RANK = {t: i for i, t in enumerate(TIERS)}
BIOME_ORDER = [1, 6, 2, 3, 4, 5, 7]
BIOME_NAME = {1: 'Forest', 6: 'Jungle', 2: 'Desert', 3: 'Snow', 4: 'Lava', 5: 'Crystal', 7: 'Storm', 8: 'Mech'}
PACKS = ['Pack01', 'Pack02', 'Pack03', 'Pack04', 'Pack05', 'Pack06']
BOOTS = ['Sand', 'Frost', 'Lava', 'Crystal', 'Thunder']
TRAILS = ['Mint', 'Arc', 'Solar', 'Aurora', 'Nebula', 'Royal']
PACK_MIX = dict(zip(PACKS, [0.379382, 0.25, 0.15, 0.07, 0.100143, 0.050475]))  # R111_balance/mix_dump.tsv MIXAVG

PLANT = collections.OrderedDict()
ODDS = collections.defaultdict(dict)       # (stage, pack, boot 0..5) -> {seed: p}
MACHINE_COST, MACHINE_MULT, TRAIL_COST, TRAIL_MULT, BOOT_COST, BOOT_LUCK = [], [], [], [], [], []
FENCE = []
CURVE = []
BUNDLES = []
MECH_CHANCE = {}
MISC = {}
for line in open(os.path.join(HERE, 'econ_live.tsv')):
    f = line.rstrip('\n').split('\t')
    k = f[0]
    if k == 'PLANT':
        PLANT[f[2]] = dict(stage=int(f[1]), id=f[2], name=f[3], rarity=f[4], value=float(f[5]), fruits=int(f[6]),
                           seconds=float(f[7]), regrow=float(f[8]), regrows=f[9] == 'true', mode=f[10],
                           first=float(f[11]), repeat=float(f[12]))
    elif k == 'ODDS':
        ODDS[(int(f[1]), f[2], int(f[3]))][f[4]] = float(f[5])
    elif k == 'MACHINE':
        MACHINE_COST.append(float(f[2])); MACHINE_MULT.append(float(f[3]))
    elif k == 'TRAIL':
        TRAIL_COST.append(float(f[2])); TRAIL_MULT.append(float(f[3]))
    elif k == 'BOOT':
        BOOT_COST.append(float(f[2])); BOOT_LUCK.append(float(f[3]))
    elif k == 'FENCE':
        FENCE.append(dict(name=f[2], cost=float(f[3]), size=float(f[4]), time=float(f[5])))
    elif k == 'CURVE':
        CURVE.append((float(f[2]), float(f[3])))
    elif k == 'BUNDLE':
        BUNDLES.append(dict(key=f[1], kind=f[2], amount=float(f[3]), gems=int(f[4]), robux=int(f[5])))
    elif k == 'MECHCHANCE':
        MECH_CHANCE[f[1]] = float(f[3]) / 100
    elif k == 'MULT':
        MISC['mult_' + f[1]] = float(f[2])
    elif k == 'MISC':
        for a, b in zip(f[1::2], f[2::2]):
            MISC[a] = b

POOL = collections.defaultdict(list)
for sid, p in PLANT.items():
    POOL[p['stage']].append(sid)

# Geometry / pacing (R111_balancing_spec.md S1; RouteBalance83 x1.6 ladder)
CAMP_DIST = {1: 100, 6: 405, 2: 955, 3: 1705, 4: 2655, 5: 3830, 7: 5280}
NEED = {1: 24, 6: 35, 2: 55, 3: 88, 4: 141, 5: 226, 7: 363}          # keeper close x1.10 (spec S1)
SPEED_TAIL = .1
LOG_FROM = 2000000


def speed_from_points(p, curve=None):
    curve = curve or CURVE
    last = curve[-1]
    if p > last[0]:
        import math
        return last[1] + SPEED_TAIL * (math.log10(p) - math.log10(last[0]))
    import math
    for a, b in zip(curve, curve[1:]):
        if p <= b[0]:
            if a[0] >= LOG_FROM:
                t = math.log(p / a[0]) / math.log(b[0] / a[0])
            else:
                t = (p - a[0]) / (b[0] - a[0])
            return a[1] + (b[1] - a[1]) * t
    return last[1]


def fmt(x):
    if x is None:
        return '-'
    for s, v in (('Qa', 1e15), ('T', 1e12), ('B', 1e9), ('M', 1e6), ('K', 1e3)):
        if abs(x) >= v:
            y = x / v
            return ('%.3g' % y) + s
    return '%.3g' % x


def hours(sec):
    if sec is None:
        return 'never'
    if sec < 3600:
        return '%d min' % max(1, round(sec / 60))
    return '%.1f h' % (sec / 3600)
