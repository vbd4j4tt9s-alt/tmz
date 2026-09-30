"""Builds every table in R113_economy_proposal.md (writes out_tables.md). ~2 minutes."""
import collections, sys
from live import *
import sim, proposal as PR

PRICES = {  # rounded from proposal.tune() (proposed_prices.json)
    'machine': [150e3, 85e6, 1.5e9, 45e9, 2.5e12, 60e12],
    'trail': [5e6, 130e6, 10e9, 600e9, 20e12, 150e12],
    'boot': [12e6, 2.5e9, 200e9, 13e12, 150e12],
    'fence': [12e6, 200e6, 25e9, 1e12, 30e12, 160e12],
}
RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 40
out = []
P = out.append

live = sim.live_economy()
prop = PR.economy(PRICES)
NEW = prop.plants


def pack_value(plants, st, boot):
    agg = collections.defaultdict(float)
    for pk in PACKS:
        for s, p in ODDS[(st, pk, boot)].items():
            agg[s] += PACK_MIX[pk] * p
    once = sum(p * plants[s]['value'] for s, p in agg.items() if not plants[s]['regrows'])
    rate = sum(p * plants[s]['value'] * plants[s]['fruits'] / plants[s]['regrow'] for s, p in agg.items() if plants[s]['regrows'])
    best = max((plants[s]['value'] for s, p in agg.items() if p > 0.02), default=0)
    return once, rate * 3600, sum(p * plants[s]['repeat'] for s, p in agg.items())


P('### Plants: value per fruit, income per plant, index cash (current -> proposed)\n')
P('| Biome | Plant | Tier | Fruits x regrow | Value/fruit now | proposed | Income/plant/h now | proposed | Index first/repeat now | proposed |')
P('|---|---|---|---|---|---|---|---|---|---|')
for sid, p in PLANT.items():
    q = NEW[sid]
    rn = p['value'] * p['fruits'] / p['regrow'] * 3600 if p['regrows'] else None
    rp = q['value'] * q['fruits'] / q['regrow'] * 3600 if q['regrows'] else None
    fr = '%d x %ds' % (p['fruits'], p['regrow']) if p['regrows'] else 'single, %ds' % p['seconds']
    P(f"| {BIOME_NAME[p['stage']]} | {p['name']} | {p['rarity']} | {fr} | {fmt(p['value'])} | **{fmt(q['value'])}** | "
      f"{fmt(rn) if rn else 'once'} | {fmt(rp) if rp else 'once'} | {fmt(p['first'])} / {fmt(p['repeat'])} | {fmt(q['first'])} / {fmt(q['repeat'])} |")

P('\n### What an average pack is worth, per biome (no boots / Thunder boots)\n')
P('Garden income the pack adds (cash per hour if every fruit is picked), plus one-off single-harvest cash.\n')
P('| Biome | now: adds /h | now: one-off | proposed: adds /h | proposed: one-off |')
P('|---|---|---|---|---|')
for st in BIOME_ORDER:
    cells = []
    for plants in (PLANT, NEW):
        a = pack_value(plants, st, 0); b = pack_value(plants, st, 5)
        cells += [f'{fmt(a[1])} / {fmt(b[1])}', f'{fmt(a[0])} / {fmt(b[0])}']
    P(f'| {BIOME_NAME[st]} | ' + ' | '.join(cells) + ' |')

ev_l, sn_l = sim.simulate(live, runs=RUNS, seed=1)
ev_p, sn_p = sim.simulate(prop, runs=RUNS, seed=1)

P('\n### Prices and buy times (median active hours, %d simulated players)\n' % RUNS)
P('| Item | Effect | Price now | Bought at (now) | **Proposed price** | Target | Bought at (proposed) |')
P('|---|---|---|---|---|---|---|')
rows = []
for i in range(6):
    rows.append(('Machine %d (%s)' % (i + 2, ['Jungle', 'Desert', 'Snow', 'Lava', 'Crystal', 'Storm'][i]), 'x%g training' % MACHINE_MULT[i + 1],
                 MACHINE_COST[i + 1], 'machine%d' % (i + 2), PRICES['machine'][i], PR.TARGET['machine'][i]))
for i in range(6):
    rows.append((TRAILS[i] + ' trail', 'x%g training' % TRAIL_MULT[i], TRAIL_COST[i], 'trail:' + TRAILS[i], PRICES['trail'][i], PR.TARGET['trail'][i]))
for i in range(5):
    rows.append((BOOTS[i] + ' boots', 'x%s luck' % fmt(BOOT_LUCK[i]), BOOT_COST[i], 'boot:' + BOOTS[i], PRICES['boot'][i], PR.TARGET['boot'][i]))
for i in range(6):
    rows.append(('Fence %d (%s)' % (i + 2, FENCE[i + 1]['name']), '%.1f%% faster; proposed +%d%% sell' % ((1 - FENCE[i + 1]['time']) * 100, 8 * (i + 1)),
                 FENCE[i + 1]['cost'], 'fence%d' % (i + 2), PRICES['fence'][i], PR.TARGET['fence'][i]))
for name, eff, now, k, new, tgt in rows:
    a = ev_l.get(k, (None, 0))[0]; b = ev_p.get(k, (None, 0))[0]
    P(f'| {name} | {eff} | {fmt(now)} | {hours(a) if a is not None else ">100 h"} | **{fmt(new)}** | {hours(tgt * 3600)} | {hours(b) if b is not None else ">100 h"} |')

P('\n### Milestones (median active hours)\n')
P('| Milestone | now | proposed |')
P('|---|---|---|')
for k in ['biome:Jungle', 'biome:Desert', 'biome:Snow', 'biome:Lava', 'biome:Crystal', 'biome:Storm', 'tier:Mythic', 'tier:Secret', 'tier:Cosmic', 'tier:King']:
    a = ev_l.get(k, (None, 0)); b = ev_p.get(k, (None, 0))
    fa = hours(a[0]) if a[0] is not None else '>100 h'; fb = hours(b[0]) if b[0] is not None else '>100 h'
    if k == 'tier:King':
        fa += ' (%d%% of players by 100 h)' % (a[1] * 100); fb += ' (%d%% by 100 h)' % (b[1] * 100)
    P(f'| {k.replace("biome:", "reach ").replace("tier:", "first ")} | {fa} | {fb} |')


def snap_table(sn_l, sn_p):
    P('| Hours | | Cash on hand | Earned total | Machine | Trail | Boots | Fence | Top biome | Speed | Packs opened |')
    P('|---|---|---|---|---|---|---|---|---|---|---|')
    for h in sim.DEFAULTS['CHECKPOINTS']:
        for lab, s in (('now', sn_l[h]), ('**proposed**', sn_p[h])):
            P(f"| {h} | {lab} | {fmt(s['cash'])} | {fmt(s['earned'])} | {s['machine']:.0f}/7 | {s['trail']:.0f}/6 | {s['boot']:.0f}/5 | {s['fence']:.0f}/7 | {s['biome']} | {s['speed']:.0f} | {s['packs']:.0f} |")


P('\n### Active player after 1 / 5 / 20 / 50 / 100 hours (medians)\n')
snap_table(sn_l, sn_p)

P('\n### Sensitivity (proposed economy; median hours to reach Storm / buy Thunder boots / buy Machine 7 / buy Royal)\n')
P('| Assumption | Storm | Thunder | Machine 7 | Royal | Cash at 100 h |')
P('|---|---|---|---|---|---|')
for lab, kw in [('baseline (share 0.6, 75 s garden + 60 s treadmill per 5 min, 1 fruit/s)', {}),
                ('speed pass (x2 training)', dict(SPEED_PASS=True)),
                ('growth pass (x2 growth)', dict(GROWTH_PASS=True)),
                ('lazy harvester (0.5 fruit/s)', dict(PICK_RATE=0.5)),
                ('busy server (share 0.3)', dict(SHARE=0.3)),
                ('solo server (share 1.0)', dict(SHARE=1.0)),
                ('garden focus (150 s garden)', dict(GARDEN_S=150.0))]:
    ev, sn = sim.simulate(prop, runs=max(10, RUNS // 2), seed=3, **kw)
    g = lambda k: hours(ev[k][0]) if k in ev and ev[k][0] is not None else '>100 h'
    P(f"| {lab} | {g('biome:Storm')} | {g('boot:Thunder')} | {g('machine7')} | {g('trail:Royal')} | {fmt(sn[100]['cash'])} |")
open('out_tables.md', 'w').write('\n'.join(out) + '\n')
print('\n'.join(out))
