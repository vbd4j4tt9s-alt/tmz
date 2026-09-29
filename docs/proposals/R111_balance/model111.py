"""R111 (approved) pack odds - independent Python model of ReplicatedStorage/PackOdds111.lua.

Owner decisions: 8 tiers only (no Divine/Eternal), King 1 in 1T in a Common pack, pack ladder x1/2.5/6/20/60/200
on Secret/Cosmic/King, boots Sand x5 .. Electric x5M with luck applied per tier as luck**POWER[tier].
Everything else follows the R110 proposal (caps, 'lowest tier keeps >= 40%', missing-tier rules).
"""
import collections
from data import POOL, PACKS, BIOME_ORDER, BIOME_NAME, MIN_RARITY_BY_STAGE, PACK_MIX, rarity_of

TIERS = ['Common', 'Uncommon', 'Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
RANK = {t: i for i, t in enumerate(TIERS)}
PACK_FLOOR = dict(Pack01='Common', Pack02='Common', Pack03='Uncommon', Pack04='Rare', Pack05='Rare', Pack06='Legendary')
TOP_ONE_IN = dict(Secret=1e4, Cosmic=1e6, King=1e12)
PACK_TOP_LUCK = dict(Pack01=1, Pack02=2.5, Pack03=6, Pack04=20, Pack05=60, Pack06=200)
MID_ONE_IN = {
    'Pack01': dict(Uncommon=4, Rare=8, Legendary=30, Mythic=200),
    'Pack02': dict(Uncommon=3, Rare=5, Legendary=15, Mythic=80),
    'Pack03': dict(Rare=2.5, Legendary=7, Mythic=30),
    'Pack04': dict(Legendary=3, Mythic=10),
    'Pack05': dict(Legendary=2.5, Mythic=4),
    'Pack06': dict(Mythic=2.5),
}
POWER = dict(Uncommon=0, Rare=0, Legendary=.08, Mythic=.16, Secret=.28, Cosmic=.40, King=1)
CAP = dict(Uncommon=1, Rare=1, Legendary=.5, Mythic=.45, Secret=.25, Cosmic=.05, King=.01)
GIVEBACK = ['Legendary', 'Mythic', 'Secret']   # Cosmic and King are never squeezed by the floor guard
FLOOR_KEEP, GIVEBACK_KEEP = .40, .50
MAX_LUCK = 5e6
BOOTS = ['Sand', 'Frost', 'Lava', 'Crystal', 'Electric']
BOOT_LUCK = [5, 50, 2000, 100000, 5000000]
LEGACY_BOOT_LUCK = [1.15, 1.3, 1.5, 1.75, 2]
VOID_MECH = .005
VOID_ONE_IN = dict(Cosmic=20, King=2e8)   # Secret = rest; applies inside the 99.5% direct branch


def one_in(pack, tier):
    if tier in MID_ONE_IN[pack]:
        return MID_ONE_IN[pack][tier]
    return TOP_ONE_IN[tier] / PACK_TOP_LUCK[pack]


def tier_odds(present, biome_floor, pack, luck=1.0):
    luck = min(max(luck, 1), MAX_LUCK)
    floor_rank = max(RANK[PACK_FLOOR[pack]], RANK[biome_floor])
    floor = next(t for t in TIERS[floor_rank:] if t in present)
    out = collections.defaultdict(float)
    for t in TIERS[RANK[floor] + 1:]:
        base = 1 / one_in(pack, t)
        p = min(max(base, CAP[t]), base * luck ** POWER[t])
        if t in present:
            out[t] += p
        elif RANK[t] <= RANK['Mythic']:
            up = next((q for q in TIERS[RANK[t] + 1:RANK['Mythic'] + 1] if q in present), None)
            if up:
                out[up] += p
    if luck > 1:
        base_out = tier_odds(present, biome_floor, pack, 1.0)
        need = sum(out.values()) - (1 - FLOOR_KEEP * base_out[floor])
        for t in GIVEBACK:
            if need <= 0:
                break
            if t in out:
                give = min(need, out[t] - GIVEBACK_KEEP * base_out.get(t, 0))
                out[t] -= give
                need -= give
    out[floor] = out.get(floor, 0) + 1 - sum(out.values())
    return dict(out)


def stage_tier_odds(stage, pack, luck=1.0):
    present = {rarity_of(sid) for sid, _, _ in POOL[stage]}
    return tier_odds(present, MIN_RARITY_BY_STAGE[stage], pack, luck)


def seed_odds(stage, pack, luck=1.0):
    t = stage_tier_odds(stage, pack, luck)
    cnt = collections.Counter(rarity_of(sid) for sid, _, _ in POOL[stage])
    return {sid: t.get(rarity_of(sid), 0) / cnt[rarity_of(sid)] for sid, _, _ in POOL[stage]}


def avg_tier_odds(stage, luck):
    out = collections.defaultdict(float)
    for pk in PACKS:
        for t, v in stage_tier_odds(stage, pk, luck).items():
            out[t] += PACK_MIX[pk] * v
    return dict(out)


def void_tier_odds(present):
    out = {}
    for t in ('King', 'Cosmic'):
        if t in present:
            out[t] = 1 / VOID_ONE_IN[t]
    out['Secret'] = 1 - sum(out.values())
    return out


def legacy_luck(luck):
    old = 1
    for i, v in enumerate(BOOT_LUCK):
        if luck == luck and luck >= v:
            old = LEGACY_BOOT_LUCK[i]
    return old
