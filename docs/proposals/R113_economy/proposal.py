"""R113 proposed economy. Sell values from one formula; prices tuned by the simulator to target buy times.

Per-plant income rate  R = BIOME_BASE[biome] x TIER_MULT[tier]   (cash per second while it regrows)
Per-fruit Value         = R x RegrowSeconds / FruitCount          (regrowing plants; timings/fruit counts unchanged)
Single-harvest Value    = R x SINGLE_SECONDS (600 s)               (Sunflower, Dune Lotus, Aurora Lily, Lava Lotus)
IndexRepeat = R x 30 s, IndexFirst = R x 300 s                     (pack-open index cash)
Values are rounded like EconomyScaling91.Round (3 significant figures).
"""
import math, json, sys
from live import *
import sim

BIOME_BASE = {1: 1000, 6: 3000, 2: 10000, 3: 30000, 4: 100000, 5: 300000, 7: 1000000}
TIER_MULT = dict(Common=1, Uncommon=1.6, Rare=2.5, Legendary=4, Mythic=7, Secret=20, Cosmic=60, King=500)
SINGLE_SECONDS = 600
MECH_BASE = 1000000        # Mech (gem pack) plants are priced like Storm plants of the same tier...
MECH_TIER_MULT = dict(TIER_MULT, Cosmic=40, King=100)   # ...except Cosmic/King: the paid pack rolls King 1 in 200, not 1 in 1T
# Value tier override: Desert has no Rare/Legendary seed, so Dune Lotus (Mythic) absorbs their share (~44% of Desert
# pulls with no boots). It is priced as a Rare so it stops out-earning Snow; its displayed rarity/odds stay Mythic.
VALUE_TIER = {'DatePalmSeed': 'Rare'}
INDEX_REPEAT_S, INDEX_FIRST_S = 30, 300


def rnd(v):
    if v <= 0:
        return 0
    unit = max(5, 10 ** (math.floor(math.log10(v)) - 2))
    return math.floor(v / unit + .5) * unit


def proposed_plants():
    out = {}
    for sid, p in PLANT.items():
        base = MECH_BASE if p['stage'] == 8 else BIOME_BASE[p['stage']]
        R = base * (MECH_TIER_MULT if p['stage'] == 8 else TIER_MULT)[VALUE_TIER.get(sid, p['rarity'])]
        q = dict(p)
        q['rate'] = R
        q['value'] = rnd(R * p['regrow'] / p['fruits']) if p['regrows'] else rnd(R * SINGLE_SECONDS)
        q['repeat'] = rnd(R * INDEX_REPEAT_S)
        q['first'] = rnd(R * INDEX_FIRST_S)
        out[sid] = q
    return out


# Target cumulative ACTIVE hours to buy each item (early fast, late long but steady).
TARGET = {
    'machine': [0.08, 0.5, 1.5, 5, 15, 40],
    'trail': [0.15, 0.75, 3, 10, 30, 80],
    'boot': [0.3, 2, 8, 25, 70],
    'fence': [0.25, 1, 4, 12, 35, 90],
}
KINDS = ['machine', 'trail', 'boot', 'fence']
# Fence rework (open decision): each tier adds +8% fruit sell value (Stormline +48%), and keeps the 5% faster growth.
FENCE_VALUE = [1 + .08 * i for i in range(7)]
FENCE_TIME = [f['time'] for f in FENCE]


def economy(prices, fence_value=True):
    plants = proposed_plants()
    eco = sim.Economy('proposed R113', plants, [0] + prices['machine'], MACHINE_MULT, prices['trail'], TRAIL_MULT,
                      prices['boot'], [0] + prices['fence'], FENCE_TIME)
    eco.fence_value = FENCE_VALUE if fence_value else [1] * 7
    return eco


def key(kind, i):
    if kind == 'machine':
        return 'machine%d' % (i + 2)
    if kind == 'trail':
        return 'trail:' + TRAILS[i]
    if kind == 'boot':
        return 'boot:' + BOOTS[i]
    return 'fence%d' % (i + 2)


def tune(iters=24, runs=16):
    # start from the live prices
    prices = {'machine': MACHINE_COST[1:], 'trail': list(TRAIL_COST), 'boot': list(BOOT_COST),
              'fence': [f['cost'] for f in FENCE][1:]}
    for it in range(iters):
        ev, _ = sim.simulate(economy(prices), runs=runs, seed=100 + it, CHECKPOINTS=(160,))
        worst = 0
        for kind in KINDS:
            for i, tgt in enumerate(TARGET[kind]):
                got = ev.get(key(kind, i), (None, 0))[0]
                got_h = 320 if got is None else got / 3600
                ratio = tgt / max(got_h, 0.02)
                worst = max(worst, abs(math.log(ratio)))
                prices[kind][i] *= min(8, max(1 / 8, ratio)) ** 0.5
        # keep each ladder strictly increasing
        for kind in KINDS:
            for i in range(1, len(prices[kind])):
                prices[kind][i] = max(prices[kind][i], prices[kind][i - 1] * 1.5)
        print('iter', it, 'worst log-ratio %.2f' % worst, file=sys.stderr)
    return {k: [rnd(v) for v in vs] for k, vs in prices.items()}


if __name__ == '__main__':
    p = tune()
    json.dump(p, open('proposed_prices.json', 'w'), indent=1)
    print(json.dumps(p))
