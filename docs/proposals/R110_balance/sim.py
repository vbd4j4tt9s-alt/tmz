"""Rough progression simulator for one ACTIVE player. Monte Carlo over pack rolls.

Loop per 300 s pack-refresh cycle (SeedPackRules.RefreshInterval):
  * speed = PointCurve(points); a biome is 'unlocked' when speed >= keeper floor * UNLOCK_MARGIN.
  * The player raids the top 2 unlocked biomes: up to PACKS_PER_BIOME*SHARE packs each, one pack per run.
    Run time = 2 * camp distance / speed + OVERHEAD (steal, dodge, open/reveal, plant).
  * Time left in the cycle (plus the 10 s closed window) is spent on the treadmill:
    points += 100/s * machine * trail.
  * Cash: pack-open index cash (IndexFirst first time, IndexRepeat after; PremiumProgress.SeedCollectReward)
    + garden income. Every seed is planted into a garden of GARDEN_CAP plants (replace the worst);
    a plant earns Value*FruitCount/RegrowSeconds * HARVEST_EFF (single-harvest plants pay once).
  * Purchases: the cheapest affordable of {next machine, next trail, next boot} (greedy).
ASSUMPTIONS (all adjustable, reported in the doc): SHARE, OVERHEAD, GARDEN_CAP, HARVEST_EFF, UNLOCK_MARGIN.
"""
import random, statistics, math
from data import *

DEFAULTS = dict(SHARE=0.6, OVERHEAD=15.0, GARDEN_CAP=40, HARVEST_EFF=0.5, UNLOCK_MARGIN=1.10,
                HOURS=400, CYCLE=300.0, CLOSED=10.0, TARGET_BIOMES=2, STOP_EVENT=None)


class Ruleset:
    def __init__(self, name, seed_odds, tier_of, boot_luck, boot_cost, machine_mult=MACHINE_MULT,
                 machine_cost=MACHINE_COST, trail_mult=TRAIL_MULT, trail_cost=TRAIL_COST, speed=speed_from_points,
                 keeper_floor=None, pps=TRAINING_PPS):
        self.name, self.seed_odds, self.tier_of = name, seed_odds, tier_of
        self.boot_luck, self.boot_cost = boot_luck, boot_cost
        self.machine_mult, self.machine_cost = machine_mult, machine_cost
        self.trail_mult, self.trail_cost = trail_mult, trail_cost
        self.speed = speed
        self.keeper_floor = keeper_floor or {s: KEEPER[s][0] for s in KEEPER}
        self.pps = pps
        self._cache = {}

    def odds(self, stage, pack, boot):
        key = (stage, pack, boot)
        if key not in self._cache:
            luck = 1.0 if boot < 0 else self.boot_luck[boot]
            items = list(self.seed_odds(stage, pack, luck).items())
            cum, acc = [], 0.0
            for sid, p in items:
                acc += p
                cum.append((acc, sid))
            self._cache[key] = cum
        return self._cache[key]


def plant_rate(sid):
    e = ECON[sid]
    return e['value'] * e['fruits'] / e['regrow'] if e['regrows'] else 0.0


def run_once(rs, rng, P):
    t = 0.0
    cash = 0.0
    points = 0.0
    machine, trail, boot = 0, -1, -1
    discovered = set()
    garden = []            # plant rates
    events = {}
    packs_total = 0
    packs_log = []         # (t, packs this cycle)
    tier_first = {}
    mix_c = []
    acc = 0
    for pk in PACKS:
        acc += PACK_MIX[pk]
        mix_c.append((acc, pk))
    horizon = P['HOURS'] * 3600
    while t < horizon:
        S = rs.speed(points)
        unlocked = [b for b in BIOME_ORDER if b == 1 or S >= rs.keeper_floor[b] * P['UNLOCK_MARGIN']]
        for b in unlocked:
            events.setdefault('biome:' + BIOME_NAME[b], t)
        targets = list(reversed(unlocked))[:P['TARGET_BIOMES']]
        left = P['CYCLE'] - P['CLOSED']
        n_cycle = 0
        for b in targets:
            avail = PACKS_PER_BIOME * P['SHARE']
            whole = int(avail) + (1 if rng.random() < avail - int(avail) else 0)
            run_t = 2 * CAMP_DIST[b] / S + P['OVERHEAD']
            for _ in range(whole):
                if left < run_t:
                    break
                left -= run_t
                r = rng.random()
                pack = next(pk for c, pk in mix_c if r < c) if r < mix_c[-1][0] else PACKS[-1]
                r = rng.random()
                cum = rs.odds(b, pack, boot)
                sid = next((s for c, s in cum if r < c), cum[-1][1])
                e = ECON[sid]
                cash += e['repeat'] if sid in discovered else e['first']
                discovered.add(sid)
                tier = rs.tier_of(sid)
                tier_first.setdefault(tier, t)
                if e['regrows']:
                    rate = plant_rate(sid)
                    if len(garden) < P['GARDEN_CAP']:
                        garden.append(rate)
                    else:
                        i = min(range(len(garden)), key=garden.__getitem__)
                        if rate > garden[i]:
                            garden[i] = rate
                else:
                    cash += e['value'] * e['fruits'] * P['HARVEST_EFF']
                n_cycle += 1
        packs_total += n_cycle
        packs_log.append(n_cycle)
        train_s = left + P['CLOSED']
        mult = rs.machine_mult[machine] * (rs.trail_mult[trail] if trail >= 0 else 1)
        points += rs.pps * mult * train_s
        cash += sum(garden) * P['HARVEST_EFF'] * P['CYCLE']
        t += P['CYCLE']
        # purchases
        while True:
            opts = []
            if machine + 1 < len(rs.machine_cost):
                opts.append((rs.machine_cost[machine + 1], 'machine'))
            if trail + 1 < len(rs.trail_cost):
                opts.append((rs.trail_cost[trail + 1], 'trail'))
            if boot + 1 < len(rs.boot_cost):
                opts.append((rs.boot_cost[boot + 1], 'boot'))
            opts = [o for o in opts if o[0] <= cash]
            if not opts:
                break
            cost, kind = min(opts)
            cash -= cost
            if kind == 'machine':
                machine += 1
                events['machine%d' % (machine + 1)] = t
            elif kind == 'trail':
                trail += 1
                events['trail:' + TRAILS[trail]] = t
            else:
                boot += 1
                events['boot:' + BOOTS[boot]] = t
        if boot == len(rs.boot_cost) - 1 and 'biome:Storm' in events and machine == len(rs.machine_cost) - 1:
            break
        if P['STOP_EVENT'] and P['STOP_EVENT'] in events:
            break
    events['_packs_per_hour_last10h'] = sum(packs_log[-120:]) / min(10, len(packs_log) / 12) if packs_log else 0
    events['_tier_first'] = tier_first
    return events


def simulate(rs, runs=40, seed=1, **overrides):
    P = dict(DEFAULTS)
    P.update(overrides)
    rng = random.Random(seed)
    allev = [run_once(rs, rng, P) for _ in range(runs)]
    keys = []
    for e in allev:
        for k in e:
            if not k.startswith('_') and k not in keys:
                keys.append(k)
    out = {}
    for k in keys:
        vals = [e[k] for e in allev if k in e]
        out[k] = (statistics.median(vals) / 3600, len(vals) / runs)
    tiers = {}
    for e in allev:
        for tr, tt in e['_tier_first'].items():
            tiers.setdefault(tr, []).append(tt)
    out['_tier_first'] = {tr: (statistics.median(v) / 3600, len(v) / runs) for tr, v in tiers.items()}
    out['_pph'] = statistics.median(e['_packs_per_hour_last10h'] for e in allev)
    return out
