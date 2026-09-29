"""Rarity/boot tables for the R110 proposal. Writes out_rarity.md (tables pasted into the proposal)."""
import math
from data import *
from current_odds import current_tier_odds, current_seed_odds
import proposed as PR

OUT = []


def w(s=''):
    OUT.append(s)


def one_in(p):
    if p <= 0:
        return '-'
    n = 1 / p
    for unit, suf in ((1e15, 'Qa'), (1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')):
        if n >= unit * 0.9995:
            v = n / unit
            return f'1 in {v:.3g}{suf}'
    return f'1 in {n:.3g}'


def hours(p, pph):
    if p <= 0:
        return 'never'
    h = 1 / (p * pph)
    if h < 1 / 60:
        return '<1 min'
    if h < 1:
        return f'{h * 60:.0f} min'
    if h < 10:
        return f'{h:.1f} h'
    if h < 720:
        return f'{h:,.0f} h'
    if h < 8766:
        return f'{h:,.0f} h, ~{h / 730:.0f} months nonstop'
    y = h / 8766
    if y < 100:
        return f'~{y:.1f} yr nonstop'
    return f'never: ~{y:.0e} yr'.replace('e+0', 'e').replace('e+', 'e')


def mix_avg(fn):
    acc = collections.defaultdict(float)
    for pk in PACKS:
        for t, p in fn(pk).items():
            acc[t] += PACK_MIX[pk] * p
    return acc


FULL = PR.full_ladder_pool()
ALL_BOOTS_P = [('none', 1)] + list(zip(BOOTS, PR.BOOT_LUCK))
ALL_BOOTS_C = [('none', 1)] + list(zip(BOOTS, BOOT_LUCK))


def cur_generic(pk, luck):
    """Current odds in a notional biome that has every current tier (one seed each)."""
    src = SEED_WEIGHTS[pk]
    luck = min(max(luck, 1), PLAYER_LUCK_CLAMP)
    a = {r: src[r] * (luck if i >= 6 else (1 + .5 * (luck - 1)) if i >= 4 else 1) for i, r in enumerate(ORDER8, 1)}
    s = sum(a.values())
    return {r: v / s for r, v in a.items()}


def prop_generic(pk, luck):
    return PR.tier_odds(0, pk, luck, FULL)


PPH = 72     # late-game packs/hour from sim (solo-ish server, SHARE=0.6); see throughput table

# ---------------- T1 ladder
w('### T1. Tier ladder (a biome that has every tier; averaged over the real pack spawn mix)')
w()
w('| Tier | Now: Common pack, no boots | Now: avg pack, no boots | Now: avg pack, best boots (x2) | Proposed: Common pack, no boots | Proposed: avg pack, no boots | Proposed: avg pack, best boots (x500) |')
w('|---|---|---|---|---|---|---|')
c1 = mix_avg(lambda pk: cur_generic(pk, 1))
c2 = mix_avg(lambda pk: cur_generic(pk, 2))
p1 = mix_avg(lambda pk: prop_generic(pk, 1))
p5 = mix_avg(lambda pk: prop_generic(pk, PR.BOOT_LUCK[-1]))
for t in PR.TIERS:
    w(f'| {t} | {one_in(cur_generic("Pack01", 1).get(t, 0)) if t in ORDER8 else "(new)"} | {one_in(c1.get(t, 0)) if t in ORDER8 else "-"} | {one_in(c2.get(t, 0)) if t in ORDER8 else "-"} '
      f'| {one_in(prop_generic("Pack01", 1).get(t, 0))} | {one_in(p1.get(t, 0))} | {one_in(p5.get(t, 0))} |')
w()

# ---------------- T2 per-pack data table
w('Legendary dips slightly with top boots because some of those rolls upgrade to Mythic or better; the chance of "X or better" never drops (T5).')
w()
w('### T2. Proposed per-pack odds, no boots (this is the data table that replaces `SeedWeights`)')
w()
w('Lowest tier of each pack = "rest". Pack spawn mix unchanged: ' + ', '.join(f'{PACK_NAME[p]} {PACK_MIX[p]*100:.1f}%' for p in PACKS) + '.')
w()
w('| Pack (spawn %) | ' + ' | '.join(PR.TIERS[1:]) + ' |')
w('|---|' + '---|' * (len(PR.TIERS) - 1))
for pk in PACKS:
    o = prop_generic(pk, 1)
    fl = PR.PACK_FLOOR[pk]
    cells = []
    for t in PR.TIERS[1:]:
        if PR.RANK[t] < PR.RANK[fl]:
            cells.append('-')
        elif t == fl:
            cells.append(f'rest ({o[t]*100:.0f}%)')
        else:
            cells.append(one_in(o[t]).replace('1 in ', '1/'))
    head = f'{PACK_NAME[pk]} ({PACK_MIX[pk]*100:.0f}%)' + (' - rest=Common ' + f'{o["Common"]*100:.0f}%' if fl == 'Common' else '')
    w(f'| {head} | ' + ' | '.join(cells) + ' |')
w()
w('For comparison, today\'s Mythic pack is Legendary 20% / Mythic 45% / Secret 22% / Cosmic 10% / King 3%.')
w()

# ---------------- T3 boots
w(f'### T3. Boots: luck and what it buys (average pack; {PPH} packs/hour, active late-game player)')
w()
w('| Boot | Now luck | Proposed luck | Proposed: Mythic | Secret | Cosmic | King | Divine | Eternal |')
w('|---|---|---|---|---|---|---|---|---|')
for (name, lp), (_, lc) in zip(ALL_BOOTS_P, ALL_BOOTS_C):
    a = mix_avg(lambda pk: prop_generic(pk, lp))
    row = [name, f'x{lc:g}' if name != 'none' else '-', f'x{lp:g}' if name != 'none' else '-']
    for t in ['Mythic', 'Secret', 'Cosmic', 'King', 'Divine', 'Eternal']:
        row.append(f'{one_in(a[t])} ({hours(a[t], PPH)})')
    w('| ' + ' | '.join(row) + ' |')
w()
w('Current game for comparison (average pack, best boots x2): ' + ', '.join(f'{t} {one_in(c2[t])} ({hours(c2[t], PPH)})' for t in ['Mythic', 'Secret', 'Cosmic', 'King']) + '.')
w()

# reference items
w('### T4. Time to see a "1 in N" item (top-tier rule: full luck, so N is divided by pack luck x boot luck)')
w()
avg_pack_top = sum(PACK_MIX[p] * PR.PACK_TOP_LUCK[p] for p in PACKS)
w(f'Average built-in pack luck for top tiers over the spawn mix = x{avg_pack_top:.1f}.')
w()
w('| Base 1 in N | No boots | Lava boots (x20) | Electric boots (x500) | Whole game, 1,000 players all with Electric boots |')
w('|---|---|---|---|---|')
for N, lab in [(1e6, '1M (Cosmic)'), (1e8, '100M (King)'), (1e9, '1B (reference)'), (1e12, '1T (Divine)'), (1e15, '1Qa (Eternal)')]:
    row = [lab]
    for L in [1, 20, 500]:
        p = min(avg_pack_top * L / N, 1)
        row.append(hours(p, PPH))
    p = avg_pack_top * 500 / N
    row.append(hours(p, PPH * 1000))
    w('| ' + ' | '.join(row) + ' |')
w()

# ---------------- checks
w('### T5. Safety checks (computed over all 7 biomes x 6 packs x 6 boot levels)')
w()
viol = 0
checks = 0
min_floor = (1, None)
for st in BIOME_ORDER:
    for pk in PACKS:
        prev = None
        for name, L in ALL_BOOTS_P:
            o = PR.tier_odds(st, pk, L)
            fl = min(o, key=lambda t: PR.RANK[t])
            if o[fl] < min_floor[0]:
                min_floor = (o[fl], f'{BIOME_NAME[st]} {PACK_NAME[pk]} pack, {name} boots')
            assert abs(sum(o.values()) - 1) < 1e-9
            if prev:
                for t in PR.TIERS:
                    a = sum(v for q, v in prev.items() if PR.RANK[q] >= PR.RANK[t])
                    b = sum(v for q, v in o.items() if PR.RANK[q] >= PR.RANK[t])
                    checks += 1
                    if b < a - 1e-12:
                        viol += 1
            prev = o
    for name, L in ALL_BOOTS_P:
        prev = None
        for pk in PACKS:
            o = PR.tier_odds(st, pk, L)
            if prev:
                for t in PR.TIERS:
                    a = sum(v for q, v in prev.items() if PR.RANK[q] >= PR.RANK[t])
                    b = sum(v for q, v in o.items() if PR.RANK[q] >= PR.RANK[t])
                    checks += 1
                    if b < a - 1e-12:
                        viol += 1
            prev = o
w(f'- "Better boots / better pack never lowers the chance of getting tier X or better": {checks} comparisons, {viol} violations.')
w(f'- Every table sums to 1 (asserted). Smallest share left for a pack\'s lowest tier: {min_floor[0]*100:.1f}% ({min_floor[1]}).')
w()

# ---------------- per-biome seeds
w('### T6. Every seed: tier and odds (average over the pack spawn mix)')
w()
w('| Biome | Seed | Tier now -> proposed | Now, no boots | Now, best boots | Proposed, no boots | Proposed, Electric x500 |')
w('|---|---|---|---|---|---|---|')
for st in BIOME_ORDER:
    cavg1 = collections.defaultdict(float)
    cavg2 = collections.defaultdict(float)
    pavg1 = collections.defaultdict(float)
    pavg5 = collections.defaultdict(float)
    for pk in PACKS:
        for sid, p in current_seed_odds(st, pk, 1).items():
            cavg1[sid] += PACK_MIX[pk] * p
        for sid, p in current_seed_odds(st, pk, 2).items():
            cavg2[sid] += PACK_MIX[pk] * p
        for sid, p in PR.seed_odds(st, pk, 1).items():
            pavg1[sid] += PACK_MIX[pk] * p
        for sid, p in PR.seed_odds(st, pk, PR.BOOT_LUCK[-1]).items():
            pavg5[sid] += PACK_MIX[pk] * p
    for sid, name, r in POOL[st]:
        nt = PR.tier_of(sid)
        tr = r if nt == r else f'{r} -> **{nt}**'
        w(f'| {BIOME_NAME[st]} | {name.replace(" Seed", "")} | {tr} | {one_in(cavg1[sid])} | {one_in(cavg2[sid])} | {one_in(pavg1[sid])} | {one_in(pavg5[sid])} |')
w()

# ---------------- void pack
w('### T7. Void pack (event pack, every 3rd refresh, luck does not apply)')
w()
vt = sum(EVENT_WEIGHTS.values())
w('| Tier | Now | Proposed |')
w('|---|---|---|')
for t in ['Secret', 'Cosmic', 'King', 'Divine', 'Eternal']:
    now = EVENT_WEIGHTS.get(t, 0) / vt * .995
    prop = (1 / PR.VOID_ONE_IN[t]) if t in PR.VOID_ONE_IN else None
    w(f'| {t} | {one_in(now) if now else "-"} | {one_in(prop) if prop else "rest"} |')
w()
w('(Now: 99.5% direct roll x tier weight; 0.5% goes to a Mech roll. Proposed keeps the 0.5% Mech roll.)')

open('out_rarity.md', 'w').write('\n'.join(OUT) + '\n')
print('\n'.join(OUT))
