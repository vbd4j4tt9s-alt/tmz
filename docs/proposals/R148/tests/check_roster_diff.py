"""R148 roster change: compares dump_roster.luau run on the BASE and on the CHANGE.
Usage: python3 check_roster_diff.py base_dump.txt new_dump.txt
Owner decision (no windfall): a pack banked before the update (OddsVersion none / 0 / 81 / 112 / 137) cannot roll Fire Pepper or Moon Melon at all.
So in every banked row, for every version and every variant (Small / Standard / Grand / Pack01-06), every luck level and with and without the 2x
boost, ONLY the seeds that shared a tier with a promoted seed may differ: the promoted seed itself (it drops to 0) and the seeds of its old Rare tier
(they absorb its share). Every other seed's odds must be byte-identical, and so must every other stage, the Void / Mech / Verity odds (Void 149 =
Void 137), and every seeded roll outside Lava and Crystal. Prints a summary and exits 1 on any violation."""
import sys

NEW_IDS = {'DesertAloeSeed', 'SandFruitSeed'}
PROMOTED = {'FirePepperSeed': 'Mythic', 'MoonflowerSeed': 'Legendary'}
# The only banked rows that may change: Lava (4) and Crystal (5). A promoted seed drops out of them; its old tier-mates (the seeds of its old Rare tier)
# absorb its share, so nothing outside {promoted seed} + {old tier-mates} may move.
TIER_MATES = {'4': {'EmberBloomSeed', 'AshRoseSeed', 'LavaLotusSeed'},
              '5': {'AmethystSeed', 'PrismOrchidSeed', 'DiamondVineSeed'}}
PROMOTED_IN = {'4': 'FirePepperSeed', '5': 'MoonflowerSeed'}
fails = []
notes = []


def fail(msg):
    fails.append(msg)


def lines(path):
    return [l.rstrip('\n') for l in open(path, encoding='utf-8')]


base, new = lines(sys.argv[1]), lines(sys.argv[2])


def split(rows):
    out = {}
    for l in rows:
        kind = l.split(' ', 1)[0].split('\t', 1)[0]
        out.setdefault(kind, []).append(l)
    return out


B, N = split(base), split(new)
if set(B) != set(N):
    fail('different line kinds: %s vs %s' % (sorted(B), sorted(N)))
if B.get('VALIDATE') != ['VALIDATE\ttrue'] or N.get('VALIDATE') != ['VALIDATE\ttrue']:
    fail('Config.Validate failed: %s / %s' % (B.get('VALIDATE'), N.get('VALIDATE')))

# --- plants -------------------------------------------------------------------------------------------------------------
FIELDS = ['Id', 'Seconds', 'Regrow', 'Value', 'Rarity', 'Rank', 'FruitCount', 'Name', 'HarvestName', 'Height', 'Radius', 'Sockets', 'Centers', 'Radii', 'Regrows']


def plants(rows):
    out = {}
    for l in rows:
        f = l[len('PLANT '):].split('|')
        out[f[0]] = dict(zip(FIELDS, f))
    return out


pb, pn = plants(B['PLANT']), plants(N['PLANT'])
if set(pn) - set(pb) != NEW_IDS or not set(pb) <= set(pn):
    fail('plant ids: added %s, removed %s' % (sorted(set(pn) - set(pb)), sorted(set(pb) - set(pn))))
changed = sorted(i for i in pb if i in pn and pb[i] != pn[i])
if changed != ['AloeSeed', 'FirePepperSeed', 'MoonflowerSeed']:
    fail('plants that changed: %s' % changed)
notes.append('plants: %d before, %d after; changed %s; added %s' % (len(pb), len(pn), changed, sorted(NEW_IDS)))
diff = [k for k in FIELDS if pb['AloeSeed'][k] != pn['AloeSeed'][k]]
if diff != ['Name', 'HarvestName'] or pn['AloeSeed']['Name'] != 'Aloe Sprout':
    fail('retired AloeSeed: only its display name may change (%s)' % diff)
diff = [k for k in FIELDS if pb['MoonflowerSeed'][k] != pn['MoonflowerSeed'][k]]
if diff != ['Seconds', 'Regrow', 'Value', 'Rarity', 'Rank']:
    fail('Moon Melon: only time / regrow / value / rarity / rank may change (%s)' % diff)
diff = [k for k in FIELDS if pb['FirePepperSeed'][k] != pn['FirePepperSeed'][k]]
if diff != ['Seconds', 'Regrow', 'Value', 'Rarity', 'Rank', 'Height', 'Radius', 'Sockets', 'Centers', 'Radii']:
    fail('Fire Pepper: unexpected changes (%s); FruitCount, Name and HarvestName must stay' % diff)


def nums(s):
    return [float(x) for p in s.split(';') for x in p.split(',')] if s else []


for k in ('Height', 'Radius'):
    if abs(float(pn['FirePepperSeed'][k]) - 2 * float(pb['FirePepperSeed'][k])) > 2e-4:
        fail('Fire Pepper %s is not x2' % k)
for k in ('Sockets', 'Centers', 'Radii'):
    a, b = nums(pb['FirePepperSeed'][k]), nums(pn['FirePepperSeed'][k])
    if len(a) != len(b) or any(abs(2 * x - y) > 3e-4 for x, y in zip(a, b)):
        fail('Fire Pepper %s is not x2' % k)

# --- odds ---------------------------------------------------------------------------------------------------------------


def odds_rows(rows):
    out = {}
    for l in rows:
        p = l.split(' ')
        d = {}
        for kv in p[6:]:
            k, v = kv.split('=')
            d[k] = v  # the exact %.12g text: "byte-identical" means the same text
        out[tuple(p[1:6])] = (l, d)
    return out


ob, on = odds_rows(B['ODDS']), odds_rows(N['ODDS'])
if ob.keys() != on.keys():
    fail('ODDS rows differ in number')
versions = sorted({k[2] for k in ob})
variants = sorted({k[1] for k in ob})
if versions != ['v0', 'v112', 'v137', 'v81'] or variants != ['Grand', 'Pack01', 'Pack02', 'Pack03', 'Pack04', 'Pack05', 'Pack06', 'Small', 'Standard']:
    fail('the dump must cover every banked version and variant: %s %s' % (versions, variants))
same = resplit = 0
changed_rows = {}
for key in ob:
    stage = key[0]
    if ob[key][0] == on[key][0]:
        same += 1
        continue
    if stage not in TIER_MATES:
        fail('ODDS %s changed but only Lava (4) and Crystal (5) may' % ' '.join(key))
        continue
    resplit += 1
    changed_rows[key] = (ob[key][1], on[key][1])
    a, b = ob[key][1], on[key][1]
    if NEW_IDS & set(b):
        fail('a banked pack row lists a new seed: %s' % ' '.join(key))
    promoted = PROMOTED_IN[stage]
    if promoted in b:
        fail('ODDS %s: a banked pack still rolls %s' % (' '.join(key), promoted))
    if promoted not in a:
        fail('ODDS %s: the base row did not list %s (the check is out of date)' % (' '.join(key), promoted))
    allowed = TIER_MATES[stage] | {promoted}
    moved = {i for i in set(a) | set(b) if a.get(i) != b.get(i)}
    if not moved <= allowed:
        fail('ODDS %s: a seed that is not a tier-mate of %s moved: %s' % (' '.join(key), promoted, sorted(moved - allowed)))
    mates_before = sum(float(a.get(i, 0)) for i in allowed)
    mates_after = sum(float(b.get(i, 0)) for i in allowed)
    if abs(mates_before - mates_after) > 1e-9:
        fail('ODDS %s: the tier-mates did not absorb the whole share (%.12g -> %.12g)' % (' '.join(key), mates_before, mates_after))
    for i in TIER_MATES[stage]:
        if float(b.get(i, 0)) < float(a.get(i, 0)) - 1e-12:
            fail('ODDS %s: tier-mate %s lost share' % (' '.join(key), i))
notes.append('ODDS rows: %d identical, %d Lava / Crystal rows changed (%d banked versions x %d variants x 6 luck levels x 2 boosts x 7 stages in all): in each the promoted seed is gone, only its old tier-mates moved, and they absorbed its whole share' % (same, resplit, len(versions), len(variants)))

# --- Void / Verity / Mech -------------------------------------------------------------------------------------------------
for kind in ('VOID', 'VERITY', 'MECH'):
    for a, b in zip(B[kind], N[kind]):
        if a != b and a.split(' ')[1] != '149':
            fail('%s changed: %s' % (kind, a.split(' ')[1]))
v137 = [l for l in N['VOID'] if l.split(' ')[1] == '137'][0].split(' ', 2)[2]
v149 = [l for l in N['VOID'] if l.split(' ')[1] == '149'][0].split(' ', 2)[2]
v137b = [l for l in B['VOID'] if l.split(' ')[1] == '137'][0].split(' ', 2)[2]
if not (v137 == v149 == v137b):
    fail('Void 149 must equal Void 137 (and the base Void 137)')
notes.append('Void / Verity / Mech odds: identical for every version (Void 149 = Void 137)')

# --- seeded rolls ---------------------------------------------------------------------------------------------------------


def rolls(rows):
    out = {}
    for l in rows:
        p = l.split(' ')
        d = {}
        for kv in p[4:]:
            k, v = kv.rsplit('=', 1)
            d[k] = int(v)
        out[tuple(p[1:4])] = (l, d)
    return out


rb, rn = rolls(B['ROLL']), rolls(N['ROLL'])
if rb.keys() != rn.keys() or not any(k[0] == 'nil' for k in rb):
    fail('ROLL rows: different keys, or no pack without a saved odds version (nil)')
rsame = 0


def label(d):
    return {k.split(':', 1)[0]: k.split(':', 1)[1] for k in d}


for key in rb:
    stage = key[1]
    if sum(rb[key][1].values()) != sum(rn[key][1].values()):
        fail('ROLL %s: different number of rolls' % ' '.join(key))
    for k in rn[key][1]:
        sid = k.split(':')[0]
        if sid in NEW_IDS or sid in PROMOTED:
            fail('ROLL %s: a banked pack rolled %s' % (' '.join(key), sid))
    lb, ln = label(rb[key][1]), label(rn[key][1])
    for sid in ln:
        if sid in lb and lb[sid] != ln[sid]:
            fail('ROLL %s: %s changed its label %s -> %s' % (' '.join(key), sid, lb[sid], ln[sid]))
    if rb[key][0] == rn[key][0]:
        rsame += 1
    elif stage not in TIER_MATES:
        fail('ROLL %s changed but only Lava (4) and Crystal (5) may' % ' '.join(key))
notes.append('ROLL lines (versions nil / 81 / 112 / 137, stages 1-7, Pack01 / 04 / 06): %d of %d identical; the Lava / Crystal ones lost the promoted seed; no banked roll ever gave a new or promoted seed' % (rsame, len(rb)))

# --- Fruit of the Hour ----------------------------------------------------------------------------------------------------
fb, fn = B['FOH'][0].split(' '), N['FOH'][0].split(' ')
cb, cn = fb[2].split(','), fn[2].split(',')
if int(fb[1]) != 51 or int(fn[1]) != 53 or set(cn) != set(cb) | NEW_IDS or len(cn) != 53:
    fail('Fruit of the Hour: %s -> %s' % (fb[1], fn[1]))
notes.append('Fruit of the Hour: %s -> %s candidates (+ the two new fruits)' % (fb[1], fn[1]))

# --- what banked Lava / Crystal packs do now (v137 = the current odds before this release) ---------------------------------------
print('banked Lava / Crystal packs (odds version 137, luck 1, no boost), % before -> after:')
for stage, name in (('4', 'Lava'), ('5', 'Crystal')):
    for variant in ('Pack01', 'Pack03', 'Pack06'):
        if (stage, variant, 'v137', 'L1', 'B0') not in changed_rows:
            print('  %-7s %-6s unchanged (the promoted seed was never in this pack)' % (name, variant))
            continue
        a, b = changed_rows[(stage, variant, 'v137', 'L1', 'B0')]
        moved = sorted(i for i in set(a) | set(b) if a.get(i) != b.get(i))
        print('  %-7s %-6s %s' % (name, variant, '  '.join('%s %.4g -> %.4g' % (i.replace('Seed', ''), float(a.get(i, 0)), float(b.get(i, 0))) for i in moved)))
for n in notes:
    print(n)
if fails:
    for f in fails[:40]:
        print('FAIL: ' + f)
    print('%d violations' % len(fails))
    sys.exit(1)
print('roster regression diff: only the allowed lines differ')
