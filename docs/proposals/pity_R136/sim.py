#!/usr/bin/env python3
"""R136 proposal numbers: big-pack sizes + pity, and the Legendary/Mythic nerf per biome.

Usage: python3 sim.py [odds_now.json]
odds_now.json is the real PackOdds112 output per biome and pack (odds_now.luau on the mock); the "now" model below
is checked against it before any proposed number is printed.
"""
import json, random, sys, os

ORDER = ['Common', 'Uncommon', 'Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
RANK = {t: i for i, t in enumerate(ORDER)}
BIOMES = [(1, 'Forest'), (6, 'Jungle'), (2, 'Desert'), (3, 'Snow'), (4, 'Lava'), (5, 'Crystal'), (7, 'Storm Peaks')]
STAGE_FLOOR = {1: 'Common', 6: 'Common', 2: 'Uncommon', 3: 'Uncommon', 4: 'Rare', 5: 'Rare', 7: 'Rare'}
PACKS = ['Pack01', 'Pack02', 'Pack03', 'Pack04', 'Pack05', 'Pack06']
PACK_NAME = dict(zip(PACKS, ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic']))
PACK_FLOOR = {'Pack01': 'Common', 'Pack02': 'Common', 'Pack03': 'Uncommon', 'Pack04': 'Rare', 'Pack05': 'Rare', 'Pack06': 'Legendary'}
TOP = {'Secret': 1e4, 'Cosmic': 1e6, 'King': 1e12}
TOP_LUCK = {'Pack01': 1, 'Pack02': 2.5, 'Pack03': 6, 'Pack04': 20, 'Pack05': 60, 'Pack06': 200}
MID = {
    'Pack01': {'Uncommon': 4, 'Rare': 8, 'Legendary': 30, 'Mythic': 200},
    'Pack02': {'Uncommon': 3, 'Rare': 5, 'Legendary': 15, 'Mythic': 80},
    'Pack03': {'Rare': 2.5, 'Legendary': 7, 'Mythic': 30},
    'Pack04': {'Legendary': 3, 'Mythic': 10},
    'Pack05': {'Legendary': 2.5, 'Mythic': 4},
    'Pack06': {'Mythic': 2.5},
}
# Proposal B: Legendary and Mythic "1 in N" are multiplied by the biome's factor (Common/Uncommon/Rare packs) or by
# half of it (Epic/Legendary/Mythic packs, so the named packs still feel like their name). No more pass-up, and a
# missing floor tier steps down instead of up (see tier_odds).
FACTOR = {1: 2, 6: 2.5, 2: 3, 3: 3.5, 4: 4, 5: 5, 7: 6}
HALF_PACKS = {'Pack04', 'Pack05', 'Pack06'}


def one_in(pack, tier, stage=None):
    n = MID[pack].get(tier) or TOP[tier] / TOP_LUCK[pack]
    if stage is not None and tier in ('Legendary', 'Mythic'):
        f = FACTOR[stage]
        n *= 1 + (f - 1) / 2 if pack in HALF_PACKS else f
    return n


def tier_odds(present, stage, pack, proposed):
    """Luck 1. present: set of tiers with a seed in this biome. Mirrors PackOdds112.TierOdds."""
    floor_rank = max(RANK[PACK_FLOOR[pack]], RANK[STAGE_FLOOR[stage]])
    floor = next((t for t in ORDER[floor_rank:] if t in present), None)
    if proposed and floor is not None and RANK[floor] > floor_rank:
        # proposed: a missing floor tier steps DOWN to the nearest tier that exists (Desert's Epic+ packs no longer
        # always give its Mythic), and only steps up when nothing exists below it.
        below = next((t for t in reversed(ORDER[RANK[STAGE_FLOOR[stage]]:floor_rank]) if t in present), None)
        floor = below or floor
    if floor is None:
        return {}
    out = {}
    for t in ORDER[RANK[floor] + 1:]:
        if proposed and t not in present:
            continue  # proposed: a missing tier's share stays with the floor
        p = 1 / one_in(pack, t, stage if proposed else None)
        if t in present:
            out[t] = out.get(t, 0) + p
        elif not proposed and RANK[t] <= RANK['Mythic']:
            # now: a missing Common..Mythic tier passes its share up to the next tier that exists (never Secret+)
            for up in ORDER[RANK[t] + 1:RANK['Mythic'] + 1]:
                if up in present:
                    out[up] = out.get(up, 0) + p
                    break
    out[floor] = out.get(floor, 0) + 1 - sum(out.values())
    return out


def fmt(p):
    if p <= 0:
        return '—'
    r = 1 / p
    if r < 9.95:
        n = round(r, 1)
        return '1/%s' % (('%d' % n) if n == int(n) else ('%.1f' % n))
    return '1/{:,}'.format(round(r))


def biome_odds(now_path):
    real = {b['stage']: b for b in json.load(open(now_path))}
    rows = []
    worst = 0
    for stage, name in BIOMES:
        present = {t for t, n in real[stage]['count'].items() if n > 0}
        for pack in PACKS:
            now = tier_odds(present, stage, pack, False)
            for t in ORDER:  # the model must match the real module
                worst = max(worst, abs(now.get(t, 0) * 100 - real[stage]['packs'][pack][t]))
            new = tier_odds(present, stage, pack, True)
            rows.append((stage, name, pack, now, new))
    return rows, worst, real


# ---- Proposal A: pack sizes ------------------------------------------------------------------------------------
SIZES_NOW = [(.5, 3), (1, 76.5), (1.5, 14), (2.5, 4.5), (3.5, 1.4), (5, .45), (7.5, .1), (10, .035), (15, .01), (20, .004), (25, .001)]
SIZES_NEW = [(.5, 2), (1, 69.991), (1.5, 17), (2.5, 7), (3.5, 2.6), (5, 1), (7.5, .28), (10, .09), (15, .025), (20, .01), (25, .004)]
SLOTS, REFRESH_S = 35, 300
FLOOR_BIG_EVERY, FLOOR_GIANT_EVERY = 6, 12      # refreshes: 30 min and 1 h
METER_BIG, METER_GIANT = 30, 200                # personal hard pity, in packs opened


def share(table, at_least):
    return sum(w for s, w in table if s >= at_least) / sum(w for _, w in table)


def roll(table, rng, at_least=0):
    pool = [(s, w) for s, w in table if s >= at_least]
    t = rng.random() * sum(w for _, w in pool)
    for s, w in pool:
        t -= w
        if t < 0:
            return s
    return pool[-1][0]


def server_hours(table, floors, hours, rng):
    big = giant = 0
    refreshes = int(hours * 3600 / REFRESH_S)
    for cycle in range(1, refreshes + 1):
        sizes = [roll(table, rng) for _ in range(SLOTS)]
        if floors:
            if cycle % FLOOR_GIANT_EVERY == 0 and max(sizes) < 10:
                sizes[min(range(SLOTS), key=lambda i: sizes[i])] = roll(table, rng, 10)
            if cycle % FLOOR_BIG_EVERY == 0 and max(sizes) < 5:
                sizes[min(range(SLOTS), key=lambda i: sizes[i])] = roll(table, rng, 5)
        big += sum(1 for s in sizes if s >= 5)
        giant += sum(1 for s in sizes if s >= 10)
    return big / hours, giant / hours


def player(table, meter, packs, rng):
    """Packs one player opens in a row. Returns (gaps between 5x+, gaps between 10x+, longest dry run)."""
    since_big = since_giant = 0
    gaps_big, gaps_giant = [], []
    longest = 0
    total = 0
    for _ in range(packs):
        s = roll(table, rng)
        if meter:
            if since_giant + 1 >= METER_GIANT and s < 10:
                s = roll(table, rng, 10)
            elif since_big + 1 >= METER_BIG and s < 5:
                s = roll(table, rng, 5)
        total += s
        since_big += 1
        since_giant += 1
        if s >= 5:
            gaps_big.append(since_big)
            longest = max(longest, since_big)
            since_big = 0
        if s >= 10:
            gaps_giant.append(since_giant)
            since_giant = 0
    return gaps_big, gaps_giant, longest, total / packs


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(q * len(xs)))]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    rows, worst, real = biome_odds(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, 'odds_now.json'))
    print('model vs real PackOdds112: worst difference %.2e %%' % worst)
    assert worst < 1e-6, 'the "now" model does not match the real module'
    print('\nB. Legendary / Mythic per biome (luck 1)')
    for stage, name, pack, now, new in rows:
        print('%-11s %-9s Legendary %-8s -> %-8s Mythic %-8s -> %-8s' % (name, PACK_NAME[pack], fmt(now.get('Legendary', 0)), fmt(new.get('Legendary', 0)),
                                                                      fmt(now.get('Mythic', 0)), fmt(new.get('Mythic', 0))))
    # Mythic seeds per server-hour from world packs (spawn weights from RouteBalance83, ignoring the tier floors)
    spawn = dict(zip(PACKS, [42.92, 28.24, 16.94, 7.9, 3, 1]))
    tot = sum(spawn.values())
    for label, idx in (('now', 3), ('new', 4)):
        leg = myth = 0
        for stage, name, pack, now, new in rows:
            o = now if label == 'now' else new
            per_hour = 5 * 3600 / REFRESH_S * spawn[pack] / tot
            leg += per_hour * o.get('Legendary', 0)
            myth += per_hour * o.get('Mythic', 0)
        print('world packs per server-hour, %s: %.1f Legendary seeds, %.1f Mythic seeds' % (label, leg, myth))

    print('\nA. Pack sizes')
    for label, table in (('now', SIZES_NOW), ('new', SIZES_NEW)):
        mean = sum(s * w for s, w in table) / sum(w for _, w in table)
        print('%s: 5x+ %s (%.3f%%), 10x+ %s (%.3f%%), 25x %s, average size %.3f' % (
            label, fmt(share(table, 5)), share(table, 5) * 100, fmt(share(table, 10)), share(table, 10) * 100, fmt(share(table, 25)), mean))
    rng = random.Random(136)
    for label, table, floors in (('now', SIZES_NOW, False), ('new sizes', SIZES_NEW, False), ('new sizes + server floors', SIZES_NEW, True)):
        big, giant = server_hours(table, floors, 4000, rng)
        print('server, %-26s 5x+ %.1f/h, 10x+ %.2f/h (one every %.0f min)' % (label, big, giant, 60 / giant))
    for label, table, meter in (('now', SIZES_NOW, False), ('new sizes', SIZES_NEW, False), ('new sizes + meter', SIZES_NEW, True)):
        gb, gg, longest, mean = player(table, meter, 3_000_000, rng)
        print('player, %-18s packs per 5x+: average %.1f, 9 in 10 within %d, worst %d | packs per 10x+: average %.0f, 9 in 10 within %d | average size %.3f' % (
            label, sum(gb) / len(gb), pct(gb, .9), longest, sum(gg) / len(gg), pct(gg, .9), mean))


if __name__ == '__main__':
    main()
