"""Final tables for R111_balancing_spec.md (odds from model112 = verified equal to the Luau module; speed facts from
speed112.tsv = the real Progression81/KeeperPursuit on the edited src). Writes out_tables112.md."""
import math, collections
from data import POOL, PACKS, PACK_MIX, BIOME_ORDER, BIOME_NAME, CAMP_DIST, BIOME_LEN, POINT_CURVE, speed_from_points
import model112 as M

OUT = []
w = OUT.append
PPH = 72


def one_in(p):
    n = 1 / p
    for u, s in ((1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')):
        if n >= u:
            return f'1 in {n / u:.3g}{s}'
    return f'1 in {n:.3g}'


def hours(p):
    h = 1 / p / PPH
    if h < 1:
        return f'{h * 60:.0f} min'
    if h < 1000:
        return f'{h:,.0f} h' if h >= 10 else f'{h:.1f} h'
    y = h / 24 / 365
    return f'{h:,.0f} h (~{y:,.1f} yr nonstop)' if y < 100 else f'never (~{y:,.0f} yr nonstop)'


def avg(stage, luck, tiers):
    o = M.avg_tier_odds(stage, luck)
    return {t: sum(v for q, v in o.items() if M.RANK[q] >= M.RANK[t]) for t in tiers}   # "this tier or better"


boots = [('none', 1)] + list(zip(M.BOOTS, M.BOOT_LUCK))
tiers = ['Mythic', 'Secret', 'Cosmic', 'King']
w('### F1. What players experience: Storm Peaks, average pack (real spawn mix), 72 packs/hour')
w('')
w('Chance per pack of getting that tier **or better**, and the average active time to see one.')
w('')
w('| Boot (shown luck) | Mythic+ | Secret+ | Cosmic+ | King |')
w('|---|---|---|---|---|')
for name, L in boots:
    a = avg(7, L, tiers)
    shown = 'x' + (f'{L/1e6:g}M' if L >= 1e6 else f'{L/1e3:g}K' if L >= 1e3 else f'{L:g}') if L > 1 else '-'
    w(f'| {name} ({shown}) | ' + ' | '.join(f'{one_in(a[t])} ({hours(a[t])})' for t in tiers) + ' |')
w('')
# Same, per pack tier for Electric and none (King only)
w('### F2. King per pack (1 in N), no boots vs Electric boots (x5M), any biome with a King seed')
w('')
w('| Pack | no boots | Electric |')
w('|---|---|---|')
for pk, name in zip(PACKS, ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Mythic']):
    a, b = M.stage_tier_odds(7, pk, 1)['King'], M.stage_tier_odds(7, pk, M.MAX_LUCK)['King']
    w(f'| {name} | {one_in(a)} | {one_in(b)} |')
w('')

# ---------------- speed
rows = [l.rstrip('\n').split('\t') for l in open('speed112.tsv')]
settle = {(int(r[1]), int(r[2])): float(r[3]) for r in rows if r[0] == 'SETTLE'}
keeper = {int(r[1]): tuple(map(float, r[2:5])) for r in rows if r[0] == 'KEEPER'}
knots = [(int(r[1]), float(r[2])) for r in rows if r[0] == 'KNOT']
need = {s: max(24, round(keeper[s][0] * 1.10)) for s in BIOME_ORDER}
w('### S1. Tracks vs speed (camp = pack cluster; distances from the base line, geometry unchanged)')
w('')
w('"Need" = keeper close speed x1.10 (Forest: the starting 24). "Prev" = the speed needed for the biome before '
  '(what you have when you first try it).')
w('')
w('| Biome | Length | Camp at | Keeper close/mid/far | Need | To camp @need | To camp @prev | Cross @need | Cross @prev | Round trip @need +15 s | Keeper settles behind you @need |')
w('|---|---|---|---|---|---|---|---|---|---|---|')
prev = None
for s in BIOME_ORDER:
    k = keeper[s]
    n = need[s]
    p = need[prev] if prev else None
    st = settle.get((s, n), float('nan'))
    stt = 'never catches (gap grows)' if math.isinf(st) else f'{st:.0f} studs'
    w(f'| {BIOME_NAME[s]} | {BIOME_LEN[s]} | {CAMP_DIST[s]} | {k[0]:g}/{k[1]:g}/{k[2]:g} | {n} | {CAMP_DIST[s]/n:.1f} s | '
      + (f'{CAMP_DIST[s]/p:.1f} s' if p else '-') + f' | {BIOME_LEN[s]/n:.1f} s | ' + (f'{BIOME_LEN[s]/p:.1f} s' if p else '-')
      + f' | {2*CAMP_DIST[s]/n+15:.0f} s | {stt} |')
    prev = s
w('')
# ---------------- first 10 minutes
w('### N1. New player: speed vs time on the starter treadmill (100 points/s; x2 with the speed pass)')
w('')
w('| Treadmill time | Points | Speed live (R110) | Speed approved proposal | Speed final | vs Forest keeper (close 20) | vs Jungle keeper (close 32) |')
w('|---|---|---|---|---|---|---|')
prop = [(0, 24), (6000, 35), (120000, 55), (1500000, 88), (20000000, 141), (300000000, 226), (5000000000, 363), (100000000000, 500)]
spd = {int(r[1]): float(r[2]) for r in rows if r[0] == 'SPEED'}
for secs in [0, 5, 15, 30, 45, 60, 120, 300, 600]:
    pts = secs * 100
    live = speed_from_points(pts, POINT_CURVE)
    ap = speed_from_points(pts, prop)
    fin = speed_from_points(pts, knots)
    fk = 'outruns x%.2f' % (fin / 20)
    jk = ('outruns x%.2f' % (fin / 32)) if fin > 32 else 'too slow'
    w(f'| {secs//60}:{secs%60:02d} | {pts:,} | {live:.1f} | {ap:.1f} | {fin:.1f} | {fk} | {jk} |')
w('')
open('out_tables112.md', 'w').write('\n'.join(OUT) + '\n')
print('\n'.join(OUT))
