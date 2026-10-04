"""R148 roster change: compares dump_roster.luau run on the BASE and on the CHANGE.
Usage: python3 check_roster_diff.py base_dump.txt new_dump.txt
Owner decision (no windfall): packs banked before the update roll Fire Pepper / Moon Melon at their NEW tiers, so only the Lava (4) and
Crystal (5) rows of banked packs may change; everything else (Forest, Desert, Snow, Jungle, Storm, Void, Mech, Verity, every size variant,
every odds version 0 / 81 / 112 / 137, every luck level, with and without the 2x boost, every seeded roll) must be byte-identical.
Prints a summary and exits 1 on any violation."""
import sys

NEW_IDS = {'DesertAloeSeed', 'SandFruitSeed'}
PROMOTED = {'FirePepperSeed': 'Mythic', 'MoonflowerSeed': 'Legendary'}
# Seeds whose odds may change in a banked Lava / Crystal PACK (Pack01-06) of version 112 / 137: the promoted seed and the seeds that
# share a tier with it (its old Rare tier, its new tier). Secret / Cosmic / King seeds must not move.
SHARE = {'4': {'FirePepperSeed', 'EmberBloomSeed', 'AshRoseSeed', 'LavaLotusSeed'},
         '5': {'MoonflowerSeed', 'AmethystSeed', 'PrismOrchidSeed', 'DiamondVineSeed'}}
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
            d[k] = float(v)
        out[tuple(p[1:6])] = (l, d)
    return out


ob, on = odds_rows(B['ODDS']), odds_rows(N['ODDS'])
if ob.keys() != on.keys():
    fail('ODDS rows differ in number')
same = other = 0
changed_rows = {}
for key in ob:
    stage, variant, ver = key[0], key[1], key[2]
    if ob[key][0] == on[key][0]:
        same += 1
        continue
    if stage not in ('4', '5'):
        fail('ODDS %s changed but only Lava (4) and Crystal (5) may' % ' '.join(key))
        continue
    other += 1
    changed_rows[key] = (ob[key][1], on[key][1])
    ids = set(ob[key][1]) | set(on[key][1])
    moved = {i for i in ids if abs(ob[key][1].get(i, 0) - on[key][1].get(i, 0)) > 1e-12}
    if NEW_IDS & ids:
        fail('a banked pack row lists a new seed: %s' % ' '.join(key))
    if variant.startswith('Pack') and ver in ('v112', 'v137') and not moved <= SHARE[stage]:
        fail('ODDS %s: a Secret / Cosmic / King seed moved %s' % (' '.join(key), sorted(moved - SHARE[stage])))
notes.append('ODDS rows: %d identical (every stage but Lava / Crystal, all 4 banked versions x 9 variants x 6 luck x 2 boost), %d Lava / Crystal rows re-split' % (same, other))

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
rsame = 0
for key in rb:
    stage = key[1]
    if sum(rb[key][1].values()) != sum(rn[key][1].values()):
        fail('ROLL %s: different number of rolls' % ' '.join(key))
    for k in rn[key][1]:
        sid = k.split(':')[0]
        if sid in NEW_IDS:
            fail('ROLL %s: a banked pack rolled %s' % (' '.join(key), sid))
        if sid in PROMOTED and k.split(':')[1] != PROMOTED[sid]:
            fail('ROLL %s: %s must be labelled %s' % (' '.join(key), sid, PROMOTED[sid]))
    if rb[key][0] == rn[key][0]:
        rsame += 1
    elif stage not in ('4', '5'):
        fail('ROLL %s changed but only Lava (4) and Crystal (5) may' % ' '.join(key))
    else:
        for k in rb[key][1]:
            if k.split(':')[0] in PROMOTED and k.split(':')[1] != 'Rare':
                fail('ROLL %s: the base labelled a promoted seed %s' % (' '.join(key), k))
notes.append('ROLL lines: %d of %d identical (all of Forest / Desert / Snow / Jungle / Storm); the Lava / Crystal ones re-split; promoted seeds carry their new label' % (rsame, len(rb)))

# --- Fruit of the Hour ----------------------------------------------------------------------------------------------------
fb, fn = B['FOH'][0].split(' '), N['FOH'][0].split(' ')
cb, cn = fb[2].split(','), fn[2].split(',')
if int(fb[1]) != 51 or int(fn[1]) != 53 or set(cn) != set(cb) | NEW_IDS or len(cn) != 53:
    fail('Fruit of the Hour: %s -> %s' % (fb[1], fn[1]))
notes.append('Fruit of the Hour: %s -> %s candidates (+ the two new fruits)' % (fb[1], fn[1]))

# --- what banked Lava / Crystal packs do now (v137 = the current odds) -----------------------------------------------------
print('banked Lava / Crystal packs (odds version 137, boots x1), % before -> after:')
for stage, name in (('4', 'Lava'), ('5', 'Crystal')):
    for variant in ('Pack01', 'Pack03', 'Pack06'):
        key = (stage, variant, 'v137', 'L1', 'B0')
        a, b = changed_rows[key]
        moved = sorted(i for i in set(a) | set(b) if abs(a.get(i, 0) - b.get(i, 0)) > 1e-12)
        print('  %-7s %-6s %s' % (name, variant, '  '.join('%s %.4g -> %.4g' % (i.replace('Seed', ''), a.get(i, 0), b.get(i, 0)) for i in moved)))
for n in notes:
    print(n)
if fails:
    for f in fails[:40]:
        print('FAIL: ' + f)
    print('%d violations' % len(fails))
    sys.exit(1)
print('roster regression diff: only the allowed lines differ')
