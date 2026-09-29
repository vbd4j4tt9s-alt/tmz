"""Python port of the LIVE odds (PackOdds81.Weights), verified against the real Luau output."""
from data import *


def current_seed_odds(stage, pack, luck):
    """Returns {seed_id: probability} exactly like PackOdds81.Weights + SeedPackRules.SeedOdds(version 81)."""
    pool = POOL[stage]
    src = SEED_WEIGHTS[pack]
    counts = collections.Counter(r for _, _, r in pool)
    alloc = {r: 0.0 for r in ORDER8}
    top = [r for r in ORDER8 if counts[r]][-1]
    for i, r in enumerate(ORDER8):
        target = next((q for q in ORDER8[i:] if counts[q]), top)
        alloc[target] += src.get(r, 0)
    luck = min(max(luck, 1), ODDS_LUCK_CLAMP)
    for i, r in enumerate(ORDER8, 1):
        alloc[r] *= luck if i >= 6 else (1 + .5 * (luck - 1)) if i >= 4 else 1
    w = {sid: alloc[r] / counts[r] for sid, _, r in pool}
    tot = sum(w.values())
    return {k: v / tot for k, v in w.items()}


def current_tier_odds(stage, pack, luck):
    out = collections.defaultdict(float)
    for sid, p in current_seed_odds(stage, pack, luck).items():
        out[rarity_of(sid)] += p
    return dict(out)


def verify():
    worst = 0
    n = 0
    for (stage, pack, luck, sid), pct in LIVE_ODDS.items():
        mine = current_seed_odds(stage, pack, luck)[sid] * 100
        worst = max(worst, abs(mine - pct))
        n += 1
    return n, worst


if __name__ == '__main__':
    n, worst = verify()
    print(f'verified {n} live (stage,pack,luck,seed) odds against the real Luau code; max abs diff = {worst:.2e} percentage points')
