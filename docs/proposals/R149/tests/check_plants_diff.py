"""R149 regression diff: compares dump_plants.luau run on a BASE commit with the same dump on this checkout.
Usage: python3 check_plants_diff.py <base dump> <new dump>              (base = the branch commit before the fruit redesigns, 0b08836)
       python3 check_plants_diff.py --fallback <base dump> <new dump>   (base = the R149 part-built fruit, 3484f31; new = this checkout with no
                                                                         fruit-mesh bake, or with every bake failing)
Default (against the commit before the redesigns). Allowed to differ (everything else must be IDENTICAL, line for line):
  * the 7 redesigned fruit (Watermelon SunflowerSeed, Snow Melon SnowdropSeed, Apple AppleSeed, Elderbloom, Ember Pumpkin EmberBloomSeed,
    Blueberry BluebellSeed, Iceberry IceberrySeed): the art (specs), the built plant, growing stages, coats, harvest items, far proxies, detail
    cost. NOT allowed to differ: the catalog row, the art key, the prompt / reach / socket of every fruit, the plant's own parts without any fruit
    group ('bodyonly', 'supportsnoidx': the art-list index of body specs behind a changed fruit moves, nothing else).
  * the Ash Tomato (AshRoseSeed): its look stays: a crop that lands on design 1 (key ending d0) must match the base in EVERY mode except the key
    (which gains the design suffix); the catalog row is identical; at least one of the sampled crops lands on each of the other 3 designs.
    EXCEPT its 12 "Flat ash patch" blocks (review part 2, finding 5: .02 thicker, .01 higher, no z-fighting with the tomato top): dump_plants.luau
    writes a twin "<mode>~np" of every Ash Tomato mode without those parts / specs; a mode may differ only when its twin is identical (so exactly the
    patch lines differ), and the patch touch-up must show (the specs and the built plant differ).
  * the Prickly Pear (CactusSeed) is back to its current look (owner): identical in every mode, all 8 sampled crops, both designs.
--fallback: a server whose fruit-mesh bake fails (or never runs) must show exactly the R149 part-built fruit: every plant identical in every mode,
  the Watermelon / Snow Melon / Ember Pumpkin included; only the Prickly Pear may differ (R149 had redesigned it, this checkout reverts it), and
  for it only the art / plant / harvest lines (catalog, key, prompts, body-only parts identical); and the Ash Tomato's flat ash patches (all four
  designs, same twin rule as above).
Prints one summary line per group and 'only the allowed lines differ' when it holds (exit 0), else the offending lines (exit 1)."""
import sys

args = [a for a in sys.argv[1:] if not a.startswith('--')]
FALLBACK = '--fallback' in sys.argv
if FALLBACK:
    REDESIGNED = {'CactusSeed'}
else:
    REDESIGNED = {'SunflowerSeed', 'SnowdropSeed', 'AppleSeed', 'ElderbloomSeed', 'EmberBloomSeed', 'BluebellSeed', 'IceberrySeed'}
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


base, new = load(args[0]), load(args[1])
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


def patch_rules(crop, modes, label):
    """The Ash Tomato's flat ash patches may differ, nothing else: a mode may differ only when its '~np' twin (the same mode without the patch
    parts / specs) is identical, and the twins themselves must be identical. Returns how many modes differ because of the patches."""
    differ = 0
    for mode, (b, n) in sorted(modes.items()):
        if mode == 'key':
            continue
        if mode.endswith('~np'):
            if b != n:
                bad.append('AshRoseSeed %s %s (%s) changed beyond the flat ash patches' % (crop, mode, label))
        elif b != n:
            twin = modes.get(mode + '~np')
            if twin is None or twin[0] != twin[1]:
                bad.append('AshRoseSeed %s %s (%s) changed beyond the flat ash patches' % (crop, mode, label))
            else:
                differ += 1
    for must in ('specs', 'ripe'):
        if modes[must][0] == modes[must][1]:
            bad.append('AshRoseSeed %s %s (%s): the flat ash patches were not touched up' % (crop, must, label))
    return differ


if FALLBACK:
    for must in ('SunflowerSeed', 'SnowdropSeed', 'EmberBloomSeed'):
        if must not in plants:
            bad.append('%s was not compared' % must)
    ash_patch_lines = 0
    for crop, modes in sorted(ash.items()):
        if modes['key'][0] != modes['key'][1]:
            bad.append('AshRoseSeed %s key changed' % crop)
        ash_patch_lines += patch_rules(crop, modes, 'all designs')
    if len(ash) < 8:
        bad.append('AshRoseSeed was not compared in full (%d crops)' % len(ash))
    print('Ash Tomato: %d crops, %d patch-dependent lines differ (the flat ash patches only), everything else identical' % (len(ash), ash_patch_lines))
    print('%d plants (%d lines) identical to the R149 part-built base, the Watermelon / Snow Melon / Ember Pumpkin included' % (len(plants), same))
    print('Prickly Pear: %d catalog / key / prompt / reach / socket / body-only lines identical, %d art / plant / harvest lines differ (back to its current look)'
          % (redesigned_same, redesigned_diff))
    if redesigned_diff == 0:
        bad.append('the Prickly Pear does not differ from the R149 redesign: was it reverted?')
else:
    designs = {}
    ash_patch_lines = 0
    for crop, modes in ash.items():
        keyn = modes['key'][1][0]
        d = keyn.rsplit('d', 1)[1] if 'd' in keyn.split(':')[-1] else None
        designs.setdefault(d, []).append(crop)
        if d == '0':
            ash_patch_lines += patch_rules(crop, modes, 'design 1')
        else:
            if modes['ripe'][0] == modes['ripe'][1]:
                bad.append('AshRoseSeed %s (design %s) is not a variation' % (crop, d))
    for d in ('0', '1', '2', '3'):
        if d not in designs:
            bad.append('no sampled Ash Tomato crop lands on design %s' % (int(d) + 1))
    pear = sum(1 for (p, c, m) in base if p == 'CactusSeed')
    if 'CactusSeed' not in plants or pear < 8 * 4:
        bad.append('the Prickly Pear was not compared in full (%d lines)' % pear)
    print('%d plants (%d lines) identical to the base, the Prickly Pear (%d lines, 8 crops) included, none changed: %s...' % (len(plants), same, pear, ', '.join(sorted(plants)[:6])))
    print('7 redesigned fruit: %d catalog / key / prompt / reach / socket / body-only lines identical, %d art / plant / harvest lines differ' % (redesigned_same, redesigned_diff))
    print('Ash Tomato: crops per design %s; a design-1 crop is identical to the base in every mode but its flat ash patches (%d patch-dependent lines differ)'
          % ({('design %d' % (int(k) + 1)): len(v) for k, v in sorted(designs.items()) if k is not None}, ash_patch_lines))
if bad:
    print('\n'.join(bad[:40]))
    sys.exit(1)
print('only the allowed lines differ')
