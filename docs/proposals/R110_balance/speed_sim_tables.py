"""Speed tables + progression sim tables for the R110 proposal. Writes out_speed.md and out_sim.md."""
import math
from simlib import *
import speed_proposal as SP

OUT = []
w = lambda s="": OUT.append(s)


def fmt(n):
    for unit, suf in ((1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')):
        if n >= unit:
            return f'{n / unit:.3g}{suf}'
    return f'{n:.0f}'


def eq_gap(floor, mid, player):
    """KeeperPursuit.Speed: floor <=35 studs, ramps to mid at 100, ceiling at 250. Gap where keeper speed == player."""
    if player <= floor:
        return 'caught'
    if player >= mid:
        return '100+ (keeps growing)' if mid < player else '100'
    return f'{35 + 65 * (player - floor) / (mid - floor):.0f}'


cur_curve = POINT_CURVE
new_curve = SP.curve()
w('### S1. Speed per biome (keeper = close / 100 studs / 250+ studs behind you)')
w()
w('| Biome | Keeper now | Keeper proposed | Speed you need now -> proposed (keeper close-speed x1.10) | Points for that, now -> proposed | Keeper settles this many studs behind you (now -> proposed) | Seconds base->camp at that speed (now -> proposed) |')
w('|---|---|---|---|---|---|---|')
for s in BIOME_ORDER:
    kn, kp = KEEPER[s], SP.KEEPER_P[s]
    need_now = max(24, kn[0] * 1.10)
    need_new = SP.NEED[s] if s != 1 else 24
    pn = points_for_speed(need_now, cur_curve)
    pp = points_for_speed(max(need_new, 24), new_curve)
    w(f'| {BIOME_NAME[s]} | {kn[0]} / {kn[1]} / {kn[2]} | {kp[0]} / {kp[1]} / {kp[2]} | {need_now:.0f} -> {max(need_new,24)} | {fmt(pn)} -> {fmt(pp)} '
      f'| {eq_gap(kn[0], kn[1], need_now)} -> {eq_gap(kp[0], kp[1], max(need_new,24))} | {CAMP_DIST[s] / need_now:.1f} -> {CAMP_DIST[s] / max(need_new,24):.1f} |')
w()
w('### S2. Treadmill time for each step, on the machine named for the biome you are in (+ trail one tier lower)')
w()
w('| Step | Machine x trail | Gain/s | Treadmill time now | Treadmill time proposed |')
w('|---|---|---|---|---|')
prev_n = prev_p = 0
for k, s in enumerate(BIOME_ORDER[1:]):
    m = MACHINE_MULT[k]
    tr = TRAIL_MULT[k - 1] if k >= 1 else 1
    rate = TRAINING_PPS * m * tr
    pn = points_for_speed(KEEPER[s][0] * 1.10, cur_curve)
    pp = points_for_speed(SP.NEED[s], new_curve)
    w(f'| {BIOME_NAME[BIOME_ORDER[k]]} -> {BIOME_NAME[s]} | x{m} x {tr} | {fmt(rate)} | {max(0, pn - prev_n) / rate / 60:.1f} min | {max(0, pp - prev_p) / rate / 60:.1f} min |')
    prev_n, prev_p = pn, pp
w()
w('### S3. Points -> speed (existing saves keep their points; this is what they would run at)')
w()
w('| Saved points | 0 | 1K | 10K | 100K | 1M | 10M | 100M | 1B | 10B | 100B | 1T |')
w('|---|' + '---|' * 11)
pts = [0, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12]
w('| Speed now | ' + ' | '.join(f'{speed_from_points(p, cur_curve):.0f}' for p in pts) + ' |')
w('| Speed proposed | ' + ' | '.join(f'{speed_from_points(p, new_curve):.0f}' for p in pts) + ' |')
w()
w('Proposed `PointCurve` knots: ' + ', '.join(f'{{{int(a)},{b}}}' for a, b in new_curve) + ' (tail +0.1 speed per 10x points after 100B, unchanged).')
w()
open('out_speed.md', 'w').write('\n'.join(OUT) + '\n')
print('\n'.join(OUT))

# ---------------- sim
OUT2 = []
w = lambda s="": OUT2.append(s)
cur = current_rules()
p_odds = proposed_rules()
p_all = proposed_rules(speed=SP.speed_fn(), keeper_floor=SP.FLOORS)
runs = 40
R = {'Now (live R107)': simulate(cur, runs=runs),
     'Proposed odds+boots, today\'s speed': simulate(p_odds, runs=runs),
     'Proposed odds+boots+speed': simulate(p_all, runs=runs)}
keys = ['biome:Jungle', 'biome:Desert', 'biome:Snow', 'biome:Lava', 'biome:Crystal', 'biome:Storm',
        'boot:Sand', 'boot:Frost', 'boot:Lava', 'boot:Crystal', 'boot:Electric', 'machine7']


def hh(v):
    if v is None:
        return 'not reached'
    h, frac = v
    s = f'{h * 60:.0f} min' if h < 1 else f'{h:.1f} h'
    return s if frac >= .99 else s + f' ({frac * 100:.0f}% of runs)'


w(f'### SIM1. Active-player progression (median of {runs} simulated players, hours of active play)')
w()
w('| Milestone | ' + ' | '.join(R) + ' |')
w('|---|' + '---|' * len(R))
for k in keys:
    w(f'| {k.replace("biome:", "reach ").replace("boot:", "buy ").replace("machine7", "last treadmill (x30000)")} | ' + ' | '.join(hh(r.get(k)) for r in R.values()) + ' |')
for t in ['Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King', 'Divine', 'Eternal']:
    w(f'| first {t} seed | ' + ' | '.join(hh(r['_tier_first'].get(t)) for r in R.values()) + ' |')
w('| late-game packs/hour | ' + ' | '.join(f'{r["_pph"]:.0f}' for r in R.values()) + ' |')
w()
w('A run stops once everything is bought and Storm is reached, so "not reached" means not within that time (about 125-175 h).')
w()

w('### SIM2. Sensitivity (proposed odds+boots+speed; median hours)')
w()
w('| Assumption changed | reach Storm | buy Crystal boots | buy Electric boots | first Secret | first Cosmic |')
w('|---|---|---|---|---|---|')
for label, kw in [('baseline (share 0.6, overhead 15 s, garden 40, harvest 50%)', {}),
                  ('crowded server: share 0.3', dict(SHARE=0.3)),
                  ('solo server: share 1.0', dict(SHARE=1.0)),
                  ('garden 20 plants', dict(GARDEN_CAP=20)),
                  ('garden 80 plants', dict(GARDEN_CAP=80)),
                  ('harvest efficiency 25%', dict(HARVEST_EFF=.25)),
                  ('overhead 30 s per pack', dict(OVERHEAD=30))]:
    r = simulate(p_all, runs=24, **kw)
    w(f'| {label} | {hh(r.get("biome:Storm"))} | {hh(r.get("boot:Crystal"))} | {hh(r.get("boot:Electric"))} | {hh(r["_tier_first"].get("Secret"))} | {hh(r["_tier_first"].get("Cosmic"))} |')
w()

# throughput
w('### SIM3. Pack throughput at the speed you need for each biome (proposed speeds)')
w()
w('| Biome | Round trip + 15 s overhead | Max packs/hour if you take all 5 per refresh | ...if you get 3 of 5 |')
w('|---|---|---|---|')
for s in BIOME_ORDER:
    sp = max(SP.NEED[s], 24)
    rt = 2 * CAMP_DIST[s] / sp + 15
    per_cycle = min(5, int(290 // rt))
    w(f'| {BIOME_NAME[s]} | {rt:.0f} s | {per_cycle * 12} | {min(3, per_cycle) * 12} |')
w()
w('At the intended speeds every run is short enough to take all 5 packs of a biome before the next refresh, so the limit is pack supply (5 per biome per 300 s, shared by up to 6 players), not speed. Players also raid the biome below, so the sim sees ~70 packs/hour late game.')
open('out_sim.md', 'w').write('\n'.join(OUT2) + '\n')
print('\n'.join(OUT2))
