"""R110 PROPOSAL (not live). Rarity ladder, per-pack '1 in N' odds, boot luck, and the roll rule.

Rule, in plain words:
  * Every tier above a pack's lowest tier has a '1 in N' chance (ONE_IN below).
  * Boots multiply that chance by luck**POWER[tier] (full effect on Cosmic and up, partial below),
    never above CAP[tier] (unless the pack's own base is already higher).
  * The pack's lowest tier gets whatever is left, and keeps at least 40% of its no-boot share. If boots
    would squeeze it more, the partially-boosted tiers give chance back, lowest tier first (each keeps at
    least half its no-boot share), so the advertised Cosmic/King/Divine/Eternal odds stay exact (apart
    from CAP in the very best packs). Checked: a better boot or pack never lowers P(tier X or better).
  * A tier with no seed in a biome: Common..Mythic keep today's behaviour (share moves up to the next tier
    that exists, but never into Secret+); Secret and above are simply not rolled (share stays with lower tiers).
  * Several seeds of one tier in one biome split that tier's chance evenly (as today).
"""
from data import *

TIERS = ORDER8 + ['Divine', 'Eternal']
RANK = {t: i for i, t in enumerate(TIERS)}
TOP_TIERS = ['Secret', 'Cosmic', 'King', 'Divine', 'Eternal']

# Two existing seeds promoted to the new apex tiers (no new art needed). Everything else keeps its tier.
RETIER = {'PrismMonarchSeed': 'Divine',     # Crystal, was King
          'PulsarStarfruitSeed': 'Eternal'}  # Storm, was King

PACK_FLOOR = dict(Pack01='Common', Pack02='Common', Pack03='Uncommon', Pack04='Rare', Pack05='Rare', Pack06='Legendary')

# Top-tier ladder for a Common pack with no boots, and each pack's built-in multiplier for those tiers.
TOP_ONE_IN = dict(Secret=1e4, Cosmic=1e6, King=1e8, Divine=1e12, Eternal=1e15)
PACK_TOP_LUCK = dict(Pack01=1, Pack02=2.5, Pack03=6, Pack04=20, Pack05=60, Pack06=200)
# Common..Mythic are hand-set per pack, close to today's shares but a bit rarer (1 in N).
MID_ONE_IN = {
    'Pack01': dict(Uncommon=4, Rare=8, Legendary=30, Mythic=200),
    'Pack02': dict(Uncommon=3, Rare=5, Legendary=15, Mythic=80),
    'Pack03': dict(Rare=2.5, Legendary=7, Mythic=30),
    'Pack04': dict(Legendary=3, Mythic=10),
    'Pack05': dict(Legendary=2.5, Mythic=4),
    'Pack06': dict(Mythic=2.5),
}
ONE_IN = {}
for pk in PACKS:
    row = dict(MID_ONE_IN[pk])
    for t in TOP_TIERS:
        row[t] = TOP_ONE_IN[t] / PACK_TOP_LUCK[pk]
    ONE_IN[pk] = row

POWER = dict(Uncommon=0, Rare=0, Legendary=.2, Mythic=.4, Secret=.7, Cosmic=1, King=1, Divine=1, Eternal=1)
CAP = dict(Uncommon=1, Rare=1, Legendary=.5, Mythic=.45, Secret=.25, Cosmic=.05, King=.01, Divine=.001, Eternal=.001)
FLOOR_KEEP = .40      # the pack's lowest tier keeps at least 40% of its no-boot share
GIVEBACK_KEEP = .50   # a mid tier squeezed by the guard keeps at least 50% of its no-boot share

BOOT_LUCK = [2, 5, 20, 100, 500]
# Prices: see sim results. Same geometric shape as today (EconomyScaling91.Curve), start/end tuned by the sim.
BOOT_COST = None   # filled in by tune step; None -> keep live prices

# Void pack (event, every 3rd refresh): guaranteed Secret+, luck-free (as today).
VOID_ONE_IN = dict(Cosmic=20, King=20000, Divine=2e8, Eternal=2e11)


def tier_of(seed_id):
    return RETIER.get(seed_id) or rarity_of(seed_id)


def tier_odds(stage, pack, luck=1.0, pool=None):
    """-> {tier: probability} for one biome/pack/luck under the proposal."""
    pool = pool if pool is not None else [(sid, n, tier_of(sid)) for sid, n, _ in POOL[stage]]
    present = {t for _, _, t in pool}
    floor_rank = max(RANK[PACK_FLOOR[pack]], RANK[MIN_RARITY_BY_STAGE.get(stage, 'Common')])
    # floor = lowest present tier at/above the pack+biome floor
    floor = next(t for t in TIERS[floor_rank:] if t in present)
    p = {}
    for t in TIERS[RANK[floor] + 1:]:
        base = 1 / ONE_IN[pack][t]
        boosted = base * luck ** POWER[t]
        p[t] = min(max(base, CAP[t]), boosted)
    # missing tiers: Common..Mythic move up to next present tier <= Mythic; else (and Secret+) fall to floor
    out = collections.defaultdict(float)
    for t, v in p.items():
        if t in present:
            out[t] += v
        elif RANK[t] <= RANK['Mythic']:
            up = next((q for q in TIERS[RANK[t] + 1:RANK['Mythic'] + 1] if q in present), None)
            if up:
                out[up] += v
        # else: not rolled
    # floor guard: the floor keeps >= FLOOR_KEEP of its no-boot share. If boots would take more, the
    # partially-boosted tiers give chance back, lowest tier first (Legendary, then Mythic, then Secret),
    # each keeping at least GIVEBACK_KEEP of its no-boot share. Full-power tiers (Cosmic+) are untouched.
    if luck > 1:
        base_out = tier_odds(stage, pack, 1.0, pool)
        limit = 1 - FLOOR_KEEP * base_out[floor]
        need = sum(out.values()) - limit
        for t in [q for q in TIERS if q in out and 0 < POWER.get(q, 0) < 1]:
            if need <= 0:
                break
            give = min(need, out[t] - GIVEBACK_KEEP * base_out.get(t, 0))
            out[t] -= give
            need -= give
    out[floor] = out.get(floor, 0) + 1 - sum(out.values())
    return dict(out)


def seed_odds(stage, pack, luck=1.0):
    pool = [(sid, n, tier_of(sid)) for sid, n, _ in POOL[stage]]
    t = tier_odds(stage, pack, luck, pool)
    cnt = collections.Counter(x for _, _, x in pool)
    return {sid: t.get(tr, 0) / cnt[tr] for sid, _, tr in pool}


def full_ladder_pool():
    """A notional biome that has one seed of every tier, for biome-independent tables."""
    return [(t, t, t) for t in TIERS]
