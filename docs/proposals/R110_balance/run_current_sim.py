from sim import *
from current_odds import current_seed_odds
cur = Ruleset('current', lambda st, pk, L: current_seed_odds(st, pk, min(L, PLAYER_LUCK_CLAMP)), rarity_of, BOOT_LUCK, BOOT_COST)
import time; t0=time.time()
res = simulate(cur, runs=30)
for k, v in sorted([kv for kv in res.items() if not kv[0].startswith("_")], key=lambda kv: kv[1][0]):
    h, frac = v
    if k.startswith('_'): continue
    print(f'{k:22s} {h:9.2f} h  (reached in {frac*100:.0f}% of runs)')
print('first tier:', {k: round(v[0],2) for k, v in res['_tier_first'].items()})
print('packs/h late:', res['_pph'], 'sim secs', round(time.time()-t0,1))
