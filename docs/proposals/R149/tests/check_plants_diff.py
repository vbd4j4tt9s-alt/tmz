"""R149 regression diff: compares dump_plants.luau run on the BASE commit with the same dump on this checkout.
Usage: python3 check_plants_diff.py <base dump> <new dump>
Allowed to differ (everything else must be IDENTICAL, line for line):
  * the 8 redesigned fruit (Watermelon SunflowerSeed, Snow Melon SnowdropSeed, Apple AppleSeed, Elderbloom, Ember Pumpkin EmberBloomSeed,
    Prickly Pear CactusSeed, Blueberry BluebellSeed, Iceberry IceberrySeed): the art (specs), the built plant, growing stages, coats, harvest
    items, far proxies, detail cost. NOT allowed to differ: the catalog row, the art key, the prompt / reach / socket of every fruit, the plant's own
    parts without any fruit group ('bodyonly', 'supportsnoidx': the art-list index of body specs behind a changed fruit moves, nothing else).
  * the Ash Tomato (AshRoseSeed): its look stays: a crop that lands on design 1 (key ending d0) must match the base in EVERY mode except the key
    (which gains the design suffix); the catalog row is identical; at least one of the sampled crops lands on each of the other 3 designs.
Prints one summary line per group and 'only the allowed lines differ' when it holds (exit 0), else the offending lines (exit 1)."""
import sys

REDESIGNED = {'SunflowerSeed', 'SnowdropSeed', 'AppleSeed', 'ElderbloomSeed', 'EmberBloomSeed', 'CactusSeed', 'BluebellSeed', 'IceberrySeed'}
MUST_MATCH = ('catalog', 'key', 'prompt', 'bodyonly', 'supportsnoidx')


def load(path):
    rows = {}
    for line in open(path, encoding='utf-8'):
        f = line.rstrip('\n').split('\t')
        if len(f) != 5 or line.startswith('#'):
            continue
        rows[(f[0], f[1], f[2])] = (f[3], f[4])
    return rows


def kind(mode):
    for k in ('prompt', 'harvest', 'proxy', 'grow'):
        if mode.startswith(k):
            return k
    return mode


base, new = load(sys.argv[1]), load(sys.argv[2])
bad, same, redesigned_same, redesigned_diff, plants = [], 0, 0, 0, set()
ash = {}
if set(base) != set(new):
    only = sorted(set(base) ^ set(new))[:10]
    bad.append('different line keys: %s' % only)
for key in sorted(set(base) & set(new)):
    plant, crop, mode = key
    b, n = base[key], new[key]
    if plant in REDESIGNED:
        if kind(mode) in MUST_MATCH:
            if b != n:
                bad.append('%s %s %s changed (must not)' % key)
            else:
                redesigned_same += 1
        else:
            redesigned_diff += (b != n)
    elif plant == 'AshRoseSeed':
        if crop == '-':
            if b != n:
                bad.append('AshRoseSeed catalog row changed')
        else:
            ash.setdefault(crop, {})[mode] = (b, n)
    else:
        plants.add(plant)
        if b == n:
            same += 1
        else:
            bad.append('%s %s %s changed: %s -> %s' % (plant, crop, mode, b[0][:12], n[0][:12]))
    if b[0].startswith('ERR') or n[0].startswith('ERR'):
        bad.append('%s %s %s did not build (%s / %s)' % (plant, crop, mode, b[0], n[0]))
designs = {}
for crop, modes in ash.items():
    keyn = modes['key'][1][0]
    d = keyn.rsplit('d', 1)[1] if 'd' in keyn.split(':')[-1] else None
    designs.setdefault(d, []).append(crop)
    if d == '0':
        for mode, (b, n) in modes.items():
            if mode != 'key' and b != n:
                bad.append('AshRoseSeed %s %s (design 1) changed: its look must stay' % (crop, mode))
    else:
        if modes['ripe'][0] == modes['ripe'][1]:
            bad.append('AshRoseSeed %s (design %s) is not a variation' % (crop, d))
for d in ('0', '1', '2', '3'):
    if d not in designs:
        bad.append('no sampled Ash Tomato crop lands on design %s' % (int(d) + 1))
print('%d plants (%d lines) identical to the base, none changed: %s...' % (len(plants), same, ', '.join(sorted(plants)[:6])))
print('8 redesigned fruit: %d catalog / key / prompt / reach / socket / body-only lines identical, %d art / plant / harvest lines differ' % (redesigned_same, redesigned_diff))
print('Ash Tomato: crops per design %s; a design-1 crop is identical to the base in every mode' % {('design %d' % (int(k) + 1)): len(v) for k, v in sorted(designs.items()) if k is not None})
if bad:
    print('\n'.join(bad[:40]))
    sys.exit(1)
print('only the allowed lines differ')
