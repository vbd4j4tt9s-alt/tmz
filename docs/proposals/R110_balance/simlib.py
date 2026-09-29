from sim import *
from current_odds import current_seed_odds
import proposed as PR

def current_rules():
    return Ruleset('current', lambda st, pk, L: current_seed_odds(st, pk, min(L, PLAYER_LUCK_CLAMP)), rarity_of, BOOT_LUCK, BOOT_COST)

def proposed_rules(boot_cost=None, **kw):
    return Ruleset('proposed', PR.seed_odds, PR.tier_of, PR.BOOT_LUCK, boot_cost or BOOT_COST, **kw)

def show(res, title):
    print('==', title)
    for k, v in sorted([kv for kv in res.items() if not kv[0].startswith('_')], key=lambda kv: kv[1][0]):
        h, frac = v
        print(f'  {k:18s} {h:8.2f} h  ({frac*100:.0f}%)')
    print('  first tier (median h, share of runs):', {k: (round(v[0], 2), round(v[1], 2)) for k, v in sorted(res['_tier_first'].items(), key=lambda kv: kv[1][0])})
    print('  late packs/h:', res['_pph'])
