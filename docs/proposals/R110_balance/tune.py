"""Search points-curve knots and boot prices so the proposed rules hit target times. Uses the rough sim."""
import math, json, sys
from simlib import *
import speed_proposal as SP
import proposed as PR

TARGET_BIOME_H = {6: 0.08, 2: 0.25, 3: 0.6, 4: 1.5, 5: 4.5, 7: 14.0}
TARGET_BOOT_H = [0.3, 1.0, 2.5, 7.0, 45.0]   # Sand..Electric
RUNS = 16

def rules(points_at, boot_cost):
    return proposed_rules(boot_cost=boot_cost, speed=SP.speed_fn(points_at), keeper_floor=SP.FLOORS)

def t_of(res, key):
    v = res.get(key)
    return v[0] if v and v[1] >= 0.5 else float('inf')

def nice(x):
    e = 10 ** math.floor(math.log10(x))
    for m in (1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10):
        if x <= m * e * 1.0001:
            return m * e

def tune_speed(points_at, boot_cost):
    pa = dict(points_at)
    prev = 0
    for s in BIOME_ORDER[1:]:
        key = 'biome:' + BIOME_NAME[s]
        lo, hi = math.log10(max(prev * 1.5, 200)), math.log10(max(prev * 1.5, 200) * 1e4)
        for _ in range(12):
            mid = (lo + hi) / 2
            pa[s] = 10 ** mid
            later = [q for q in BIOME_ORDER[BIOME_ORDER.index(s) + 1:]]
            for i, q in enumerate(later):
                pa[q] = pa[s] * 10 ** (i + 1) * 3   # placeholders, far away
            res = simulate(rules(pa, boot_cost), runs=RUNS, STOP_EVENT=key, HOURS=60)
            if t_of(res, key) > TARGET_BIOME_H[s]:
                hi = mid
            else:
                lo = mid
        pa[s] = nice(10 ** lo)
        prev = pa[s]
        print('  speed', BIOME_NAME[s], f'{pa[s]:.3g} points', flush=True)
    return pa

def tune_boots(points_at, boot_cost):
    bc = list(boot_cost)
    for i in range(5):
        key = 'boot:' + BOOTS[i]
        lo = math.log10(bc[i - 1] * 2 if i else 1e4)
        hi = lo + 6
        for _ in range(12):
            mid = (lo + hi) / 2
            bc[i] = 10 ** mid
            for j in range(i + 1, 5):
                bc[j] = 1e16
            res = simulate(rules(points_at, bc), runs=RUNS, STOP_EVENT=key, HOURS=200)
            if t_of(res, key) > TARGET_BOOT_H[i]:
                hi = mid
            else:
                lo = mid
        bc[i] = nice(10 ** lo)
        print('  boot', BOOTS[i], f'{bc[i]:.3g}', flush=True)
    return bc

if __name__ == '__main__':
    pa = dict(SP.POINTS_AT)
    bc = list(BOOT_COST)
    for rnd in range(2):
        print('round', rnd, flush=True)
        pa = tune_speed(pa, bc)
        bc = tune_boots(pa, bc)
    json.dump({'points_at': {str(k): v for k, v in pa.items()}, 'boot_cost': bc}, open('tuned.json', 'w'), indent=1)
    print(pa, bc)
