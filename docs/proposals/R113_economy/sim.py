"""R113 active-player economy simulator (Monte Carlo over pack rolls; everything else is a rate model).

Uses the LIVE R112 pack odds dumped from the real SeedPackRules/PackOdds112 (econ_live.tsv, 7 biomes x 6 packs x
no boots + 5 boots) for BOTH the current and the proposed economy: odds, boot luck and the speed curve are not changed.

One loop step = one 300 s pack refresh (SeedPackRules.RefreshInterval):
  1. Raid: the player takes up to SHARE x 5 packs from each of the top TARGET_BIOMES unlocked biomes (a biome is
     unlocked when speed >= NEED[b] = keeper close speed x1.10, spec S1). One pack per run; a run costs
     2 x camp distance / speed + OVERHEAD s (steal, dodge, open, plant). Pack tier from the real spawn mix.
     Opening pays index cash (IndexFirst first time, IndexRepeat after; PremiumProgress.SeedCollectReward).
  2. Plant every seed (garden holds ~1,800 plants at 3-stud spacing, Config.lua:524-526,633-644 -> treated as
     unlimited up to GARDEN_CAP). A regrowing plant produces FruitCount fruits every RegrowSeconds after its first
     Seconds; fruits wait on the plant (at most FruitCount ready). Single-harvest plants give one fruit once.
  3. Harvest: the player spends up to GARDEN_S seconds picking the most valuable ready fruits at PICK_RATE fruits/s
     (one press per fruit, GardenHoldHarvest.lua:1), then sells everything. Fruit value x MULT (average
     size/Gold/Diamond/weather bonus measured with the real PlantRules.Fruit: +1.8%).
  4. Treadmill: the rest of the 300 s: 100 pts/s x machine x trail (x2 speed pass).
  5. Shopping: repeatedly buy the cheapest affordable next item among machine / trail / boot / fence (greedy).
"""
import random, statistics, math, collections
from live import *

DEFAULTS = dict(SHARE=0.6, OVERHEAD=15.0, TARGET_BIOMES=2, CYCLE=300.0, GARDEN_S=75.0, PICK_RATE=1.0,
                GARDEN_CAP=1800, MULT=1.018, SPEED_PASS=False, GROWTH_PASS=False, BUY_FENCE=True,
                CHECKPOINTS=(1, 5, 20, 50, 100))


class Economy:
    """Everything the owner can tune. `plants` = {id: dict(value, fruits, seconds, regrow, regrows, first, repeat)}"""
    def __init__(self, name, plants, machine_cost, machine_mult, trail_cost, trail_mult, boot_cost, fence_cost,
                 fence_time, curve=None):
        self.name, self.plants = name, plants
        self.machine_cost, self.machine_mult = machine_cost, machine_mult
        self.trail_cost, self.trail_mult = trail_cost, trail_mult
        self.boot_cost, self.fence_cost, self.fence_time = boot_cost, fence_cost, fence_time
        self.curve = curve or CURVE


def live_economy():
    return Economy('live R112', {k: dict(v) for k, v in PLANT.items()}, MACHINE_COST, MACHINE_MULT, TRAIL_COST,
                   TRAIL_MULT, BOOT_COST, [f['cost'] for f in FENCE], [f['time'] for f in FENCE])


_cum = {}


def roll(rng, stage, pack, boot):
    key = (stage, pack, boot)
    if key not in _cum:
        acc, rows = 0.0, []
        for sid, p in ODDS[key].items():
            acc += p
            rows.append((acc, sid))
        _cum[key] = rows
    rows = _cum[key]
    r = rng.random() * rows[-1][0]
    for c, sid in rows:
        if r < c:
            return sid
    return rows[-1][1]


MIX_C = []
_a = 0
for _pk in PACKS:
    _a += PACK_MIX[_pk]
    MIX_C.append((_a, _pk))


def run_once(eco, rng, P, trace=False):
    t, cash, earned, points = 0.0, 0.0, 0.0, 0.0
    earned_src = collections.Counter()
    machine, trail, boot, fence = 0, -1, -1, 0
    discovered = set()
    n = collections.Counter()           # regrowing plants per seed
    ready = collections.Counter()       # ready fruits per seed (regrowing)
    single = collections.Counter()      # ready single-harvest fruits per seed
    growing = []                        # (mature_t, sid)
    plants_total = 0
    events, snaps = {}, {}
    packs = 0
    best_tier = -1
    tiers_seen = collections.Counter()
    horizon = max(P['CHECKPOINTS']) * 3600
    cps = list(P['CHECKPOINTS'])
    growth = 2.0 if P['GROWTH_PASS'] else 1.0
    while t < horizon:
        S = speed_from_points(points, eco.curve)
        unlocked = [b for b in BIOME_ORDER if S >= NEED[b]]
        for b in unlocked:
            events.setdefault('biome:' + BIOME_NAME[b], t)
        targets = list(reversed(unlocked))[:P['TARGET_BIOMES']]
        left = P['CYCLE']
        ftime = eco.fence_time[fence]
        for b in targets:
            avail = PACKS_PER * P['SHARE']
            whole = int(avail) + (1 if rng.random() < avail - int(avail) else 0)
            run_t = 2 * CAMP_DIST[b] / S + P['OVERHEAD']
            for _ in range(whole):
                if left < run_t:
                    break
                left -= run_t
                r = rng.random()
                pack = next((pk for c, pk in MIX_C if r < c), PACKS[-1])
                sid = roll(rng, b, pack, boot + 1)
                e = eco.plants[sid]
                idx = e['repeat'] if sid in discovered else e['first']
                cash += idx; earned += idx; earned_src['index'] += idx
                discovered.add(sid)
                packs += 1
                tr = RANK[PLANT[sid]['rarity']]
                tiers_seen[PLANT[sid]['rarity']] += 1
                if tr > best_tier:
                    best_tier = tr
                    events.setdefault('tier:' + PLANT[sid]['rarity'], t)
                if plants_total < P['GARDEN_CAP'] or not e['regrows']:
                    growing.append((t + e['seconds'] * ftime / growth, sid))
                    if e['regrows']:
                        plants_total += 1
        # fruit production during this cycle
        dt = P['CYCLE']
        still = []
        for mt, sid in growing:
            if mt <= t + dt:
                e = eco.plants[sid]
                if e['regrows']:
                    n[sid] += 1
                    ready[sid] += e['fruits']
                else:
                    single[sid] += e['fruits']
            else:
                still.append((mt, sid))
        growing = still
        for sid, k in n.items():
            e = eco.plants[sid]
            cap = k * e['fruits']
            ready[sid] = min(cap, ready[sid] + k * e['fruits'] * dt * growth / (e['regrow'] * ftime))
        # harvest the best fruits first
        budget_s = min(P['GARDEN_S'], left)
        budget = budget_s * P['PICK_RATE']
        pool = [(eco.plants[s]['value'], s, 'r') for s in ready if ready[s] >= 1] + \
               [(eco.plants[s]['value'], s, 's') for s in single if single[s] >= 1]
        pool.sort(reverse=True)
        used = 0.0
        for v, s, kind in pool:
            if budget < 1:
                break
            src = ready if kind == 'r' else single
            k = min(math.floor(src[s]), math.floor(budget))
            src[s] -= k
            budget -= k
            used += k / P['PICK_RATE']
            got = k * v * P['MULT']
            cash += got; earned += got; earned_src['fruit'] += got
        left -= used
        mult = eco.machine_mult[machine] * (eco.trail_mult[trail] if trail >= 0 else 1) * (2 if P['SPEED_PASS'] else 1)
        points += 100 * mult * max(0.0, left)
        t += dt
        # shopping (greedy cheapest)
        while True:
            opts = []
            if machine + 1 < len(eco.machine_cost):
                opts.append((eco.machine_cost[machine + 1], 'machine'))
            if trail + 1 < len(eco.trail_cost):
                opts.append((eco.trail_cost[trail + 1], 'trail'))
            if boot + 1 < len(eco.boot_cost):
                opts.append((eco.boot_cost[boot + 1], 'boot'))
            if P['BUY_FENCE'] and fence + 1 < len(eco.fence_cost):
                opts.append((eco.fence_cost[fence + 1], 'fence'))
            opts = [o for o in opts if o[0] <= cash]
            if not opts:
                break
            cost, kind = min(opts)
            cash -= cost
            if kind == 'machine':
                machine += 1; events['machine%d' % (machine + 1)] = t
            elif kind == 'trail':
                trail += 1; events['trail:' + TRAILS[trail]] = t
            elif kind == 'boot':
                boot += 1; events['boot:' + BOOTS[boot]] = t
            else:
                fence += 1; events['fence%d' % (fence + 1)] = t
        while cps and t >= cps[0] * 3600:
            h = cps.pop(0)
            top = max(unlocked, key=BIOME_ORDER.index)
            snaps[h] = dict(cash=cash, earned=earned, machine=machine + 1, trail=trail + 1, boot=boot + 1,
                            fence=fence + 1, biome=BIOME_NAME[top], speed=S, packs=packs, plants=plants_total,
                            best=TIERS[best_tier], fruit_share=earned_src['fruit'] / max(1, earned),
                            secret=tiers_seen['Secret'], cosmic=tiers_seen['Cosmic'], king=tiers_seen['King'])
    return events, snaps


PACKS_PER = 5


def simulate(eco, runs=40, seed=1, **kw):
    P = dict(DEFAULTS); P.update(kw)
    rng = random.Random(seed)
    res = [run_once(eco, rng, P) for _ in range(runs)]
    ev_keys = []
    for e, _ in res:
        for k in e:
            if k not in ev_keys:
                ev_keys.append(k)
    events = {}
    for k in ev_keys:
        vals = sorted(e.get(k, float('inf')) for e, _ in res)
        med = vals[len(vals) // 2]
        events[k] = (None if med == float('inf') else med, sum(1 for v in vals if v < float('inf')) / runs)
    snaps = {}
    for h in P['CHECKPOINTS']:
        rows = [s[h] for _, s in res if h in s]
        out = {}
        for key in rows[0]:
            vals = [r[key] for r in rows]
            if isinstance(vals[0], str):
                out[key] = collections.Counter(vals).most_common(1)[0][0]
            else:
                out[key] = statistics.median(vals)
        snaps[h] = out
    return events, snaps
