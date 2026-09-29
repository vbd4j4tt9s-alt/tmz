"""Live (R107) balance data, read from dumps produced by running the REAL game modules in Luau
(run_current.luau / run_econ.luau / run_mix.luau), plus values copied verbatim from source files.
Every constant here has a file:line in the proposal doc."""
import os, math, collections
HERE = os.path.dirname(os.path.abspath(__file__))

ORDER8 = ['Common', 'Uncommon', 'Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
BIOME_ORDER = [1, 6, 2, 3, 4, 5, 7]           # physical order, RouteBalance83.Order
BIOME_NAME = {1: 'Forest', 6: 'Jungle', 2: 'Desert', 3: 'Snow', 4: 'Lava', 5: 'Crystal', 7: 'Storm'}
PACKS = ['Pack01', 'Pack02', 'Pack03', 'Pack04', 'Pack05', 'Pack06']
PACK_NAME = dict(zip(PACKS, ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic']))  # SeedPackRules.PackTiers

# ---- pools and live odds (from the real code) ----
POOL = collections.OrderedDict((s, []) for s in BIOME_ORDER)   # stage -> [(id, name, rarity)]
LIVE_ODDS = {}                                                 # (stage, pack, luck, id) -> percent
for line in open(os.path.join(HERE, 'current_dump.tsv')):
    f = line.rstrip('\n').split('\t')
    if f[0] == 'POOL':
        POOL[int(f[1])].append((f[2], f[3], f[4]))
    elif f[0] == 'ODDS':
        LIVE_ODDS[(int(f[1]), f[2], float(f[3]), f[4])] = float(f[6])

ECON = {}   # id -> dict
for line in open(os.path.join(HERE, 'econ_dump.tsv')):
    f = line.rstrip('\n').split('\t')
    if f[0] != 'PLANT':
        continue
    ECON[f[2]] = dict(stage=int(f[1]), rarity=f[3], value=float(f[4]), fruits=int(f[5]), seconds=float(f[6]),
                      regrow=float(f[7]), regrows=(f[8] == 'true'), first=float(f[9]), repeat=float(f[10]))

for line in open(os.path.join(HERE, 'mix_dump.tsv')):
    if line.startswith('MIXAVG'):
        PACK_MIX = dict(zip(PACKS, map(float, line.split('\t')[1].split(','))))

# ---- verbatim live values ----
# BalanceValues81.lua line 2 (SeedWeights; not overridden later)
SEED_WEIGHTS = {
    'Pack01': dict(Common=55, Uncommon=26, Rare=13, Legendary=4, Mythic=1.3, Secret=.5, Cosmic=.15, King=.05),
    'Pack02': dict(Common=25, Uncommon=38, Rare=25, Legendary=8, Mythic=2.5, Secret=1, Cosmic=.4, King=.1),
    'Pack03': dict(Common=0, Uncommon=25, Rare=48, Legendary=18, Mythic=6, Secret=2, Cosmic=.8, King=.2),
    'Pack04': dict(Common=0, Uncommon=0, Rare=45, Legendary=32, Mythic=15, Secret=5, Cosmic=2.3, King=.7),
    'Pack05': dict(Common=0, Uncommon=0, Rare=10, Legendary=40, Mythic=30, Secret=12, Cosmic=6, King=2),
    'Pack06': dict(Common=0, Uncommon=0, Rare=0, Legendary=20, Mythic=45, Secret=22, Cosmic=10, King=3),
}
BOOTS = ['Sand', 'Frost', 'Lava', 'Crystal', 'Electric']          # Config.lua:255-259 (Id RunnerHalo..MythicOrbit)
BOOT_LUCK = [1.15, 1.3, 1.5, 1.75, 2]                              # BalanceValues81.lua:10
BOOT_COST = [750000, 64100000, 5480000000, 468000000000, 40000000000000]   # EconomyBalance90.lua:9 via Scale.Curve (dumped)
PLAYER_LUCK_CLAMP = 2      # PlayerDataService.lua:634
ODDS_LUCK_CLAMP = 3.5      # PackOdds81.lua:18

MACHINE_MULT = [1, 4, 20, 100, 600, 4000, 30000]                   # BalanceValues81.lua:9
MACHINE_COST = [0, 250000, 11900000, 562000000, 26700000000, 1270000000000, 60000000000000]  # EconomyBalance90.lua:6 (dumped)
TRAILS = ['Mint', 'Arc', 'Solar', 'Aurora', 'Nebula', 'Royal']
TRAIL_MULT = [1.5, 2, 3, 4, 5, 6]                                   # BalanceValues81.lua line 2 TrailMultipliers
TRAIL_COST = [200000, 10400000, 538000000, 27900000000, 1450000000000, 75000000000000]  # EconomyBalance90.lua:7-8 (dumped)
TRAINING_PPS = 100          # Config.lua:733 (overrides 50 at :113)
POINT_CURVE = [(0, 24), (800, 30), (3000, 38), (10000, 48), (50000, 64), (300000, 82), (2000000, 110),
               (20000000, 155), (500000000, 215), (20000000000, 350), (100000000000, 500)]   # BalanceValues81.lua:8
SPEED_TAIL = .1             # BalanceValues81.lua:7
KEEPER = {1: (20, 22, 25), 6: (29, 34, 40), 2: (48, 56, 64), 3: (72, 84, 98), 4: (115, 140, 170),
          5: (220, 270, 320), 7: (400, 450, 520)}                   # RouteBalance83.lua:4
BIOME_LEN = {1: 180, 6: 450, 2: 650, 3: 850, 4: 1050, 5: 1300, 7: 1600}   # RouteBalance83.lua:3
# Camp (pack cluster) distance from the base boundary line (Z=-100) after all config transforms (run_camp.luau):
CAMP_DIST = {1: 100, 6: 405, 2: 955, 3: 1705, 4: 2655, 5: 3830, 7: 5280}
REFRESH_SECONDS = 300       # SeedPackRules.lua:7 (10 s of it closed, :8)
PACKS_PER_BIOME = 5         # SeedPackRules.lua:6
BASES_PER_SERVER = 6        # Workspace/ChestChaseMap/Bases has Base_1..Base_6 (place file)
EVENT_WEIGHTS = dict(Secret=80, Cosmic=17, King=3)   # BalanceValues81.lua line 2 (Void pack, every 3rd cycle)
MIN_RARITY_BY_STAGE = {1: 'Common', 6: 'Common', 2: 'Uncommon', 3: 'Uncommon', 4: 'Rare', 5: 'Rare', 7: 'Rare'}  # SeedPackRules.lua:127


def rarity_of(seed_id):
    for s, pool in POOL.items():
        for i, n, r in pool:
            if i == seed_id:
                return r


def speed_from_points(p, curve=POINT_CURVE, tail=SPEED_TAIL, log_from=2000000):
    """Progression81.curveSpeed (logarithmic interpolation for knots >= 2M)."""
    last = curve[-1]
    if p > last[0]:
        return last[1] + tail * (math.log10(p) - math.log10(last[0]))
    for a, b in zip(curve, curve[1:]):
        if p <= b[0]:
            if a[0] >= log_from:
                t = math.log(p / a[0]) / math.log(b[0] / a[0])
            else:
                t = (p - a[0]) / (b[0] - a[0])
            return a[1] + (b[1] - a[1]) * t
    return last[1]


def points_for_speed(s, curve=POINT_CURVE, tail=SPEED_TAIL, log_from=2000000):
    if s <= curve[0][1]:
        return 0.0
    for a, b in zip(curve, curve[1:]):
        if s <= b[1]:
            t = (s - a[1]) / (b[1] - a[1])
            if a[0] >= log_from:
                return a[0] * (b[0] / a[0]) ** t
            return a[0] + (b[0] - a[0]) * t
    last = curve[-1]
    return 10 ** (math.log10(last[0]) + (s - last[1]) / tail) if tail > 0 else float('inf')
