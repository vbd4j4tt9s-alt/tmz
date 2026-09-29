"""Cross-check: the real Luau odds (dump111.tsv from dump111.luau) against the independent Python model (model111.py)
and, for OddsVersion 81 packs, against the verified port of the old odds (current_odds.py) with luck mapped back
to the old boots. Also: monotonic check and the smallest share left for a pack's lowest tier."""
import collections
from data import POOL, PACKS, BIOME_ORDER, BIOME_NAME, rarity_of
import model111 as M
from current_odds import current_seed_odds

rows = [l.rstrip('\n').split('\t') for l in open('dump111.tsv')]
worst = {111: (0, 0, None), 81: (0, 0, None)}   # (abs pct points, relative, where)
n = collections.Counter()
for f in rows:
    if f[0] != 'ODDS':
        continue
    ver, st, pk, L, sid, got = int(f[1]), int(f[2]), f[3], float(f[4]), f[5], float(f[7])
    if ver == 111:
        exp = M.seed_odds(st, pk, L)[sid] * 100
    else:
        exp = current_seed_odds(st, pk, M.legacy_luck(L))[sid] * 100
    a = abs(got - exp)
    r = a / exp if exp > 0 else (0 if got == 0 else float('inf'))
    w = worst[ver]
    worst[ver] = (max(w[0], a), max(w[1], r), w[2] if r <= w[1] else (BIOME_NAME[st], pk, L, sid))
    n[ver] += 1
print(f'OddsVersion 111: {n[111]} seed odds (7 biomes x 6 packs x 13 luck values), Luau vs Python: '
      f'max abs diff {worst[111][0]:.2e} percentage points, max relative diff {worst[111][1]:.2e}')
print(f'OddsVersion 81 : {n[81]} seed odds, Luau (new code, luck mapped to old boots) vs verified old-odds port: '
      f'max abs diff {worst[81][0]:.2e} pp, max relative {worst[81][1]:.2e}')

# Void 111
void = {f[2]: float(f[4]) for f in rows if f[0] == 'VOID' and f[1] == '111'}
direct = [sid for sid in void if M.rarity_of(sid) in ('Secret', 'Cosmic', 'King') and not sid.startswith(('Holo', 'Nebula', 'Crowncore', 'Plasma', 'PrismLotus'))]
present = {rarity_of(s) for s in direct}
vt = M.void_tier_odds(present)
cnt = collections.Counter(rarity_of(s) for s in direct)
vw = 0
for s in direct:
    exp = 100 * (1 - M.VOID_MECH) * vt[rarity_of(s)] / cnt[rarity_of(s)]
    vw = max(vw, abs(void[s] - exp) / exp)
king = sum(void[s] for s in direct if rarity_of(s) == 'King') / 100
cosmic = sum(void[s] for s in direct if rarity_of(s) == 'Cosmic') / 100
print(f'Void 111: {len(direct)} direct seeds, max relative diff {vw:.1e}; King tier 1 in {1/king:,.0f}, Cosmic 1 in {1/cosmic:.2f}, '
      f'total {sum(void.values()):.12f}%')

# Monotonic: better boot (same pack) or better pack (same boot) never lowers P(tier X or better)
lucks = [1] + M.BOOT_LUCK
viol = checks = 0
minfloor = (1, None)
for st in BIOME_ORDER:
    for pk in PACKS:
        prev = None
        for L in lucks:
            o = M.stage_tier_odds(st, pk, L)
            fl = min(o, key=lambda t: M.RANK[t])
            base_fl = M.stage_tier_odds(st, pk, 1)[fl]
            if o[fl] / base_fl < minfloor[0]:
                minfloor = (o[fl] / base_fl, (BIOME_NAME[st], pk, L, round(o[fl], 4)))
            if prev:
                for t in M.TIERS:
                    a = sum(v for q, v in prev.items() if M.RANK[q] >= M.RANK[t])
                    b = sum(v for q, v in o.items() if M.RANK[q] >= M.RANK[t])
                    checks += 1
                    if b < a - 1e-12:
                        viol += 1
            prev = o
    for L in lucks:
        prev = None
        for pk in PACKS:
            o = M.stage_tier_odds(st, pk, L)
            if prev:
                for t in M.TIERS:
                    a = sum(v for q, v in prev.items() if M.RANK[q] >= M.RANK[t])
                    b = sum(v for q, v in o.items() if M.RANK[q] >= M.RANK[t])
                    checks += 1
                    if b < a - 1e-12:
                        viol += 1
            prev = o
print(f'Monotonic: {checks} comparisons (better boot same pack, better pack same boot, every tier "X or better"): {viol} violations')
print(f'Lowest tier keeps at least {minfloor[0]*100:.1f}% of its no-boot share (worst: {minfloor[1]})')
# every table sums to 1 and has no negative entries
bad = 0
for st in BIOME_ORDER:
    for pk in PACKS:
        for L in lucks:
            o = M.stage_tier_odds(st, pk, L)
            bad += abs(sum(o.values()) - 1) > 1e-12 or min(o.values()) < 0
print(f'Tables summing to 1 with no negative share: {7*6*len(lucks) - bad}/{7*6*len(lucks)}')
