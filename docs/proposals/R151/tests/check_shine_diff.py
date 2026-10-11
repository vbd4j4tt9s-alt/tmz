"""R151 (owner: "remove those white dots ik its for shine ... for all similar fruits"): compares docs/proposals/R149/tests/dump_plants.luau run on the BASE commit (the one before the
shine removal) with the same dump on this checkout. The dump fingerprints EVERY plant of the catalog, in every mode (art, ripe, growing, coats, harvest items, proxies, supports,
prompts), and, for the nine plants that had shine parts, a twin "<mode>~ng" of every mode computed without them.
Usage: python3 check_shine_diff.py <base dump> <new dump>
Holds when:
  * the two dumps have exactly the same rows;
  * every plant that never had a shine part (56 of the 65, the baked-mesh melons and pumpkin among the nine) is IDENTICAL in every mode, line for line;
  * the nine plants that had them (Watermelon, Snow Melon, Ember Pumpkin, Apple, Elderbloom, Blueberry, Iceberry, Moon Melon, Verity): a mode may differ only when its "~ng" twin is
    identical (so exactly the shine parts differ and nothing else: colours, stripes, sizes, pivots, bounding boxes, art indexes), the catalog / key / prompt lines are identical, the
    specs differ (the removal shows), and the number of parts of the ripe plant is smaller by exactly the number of shine parts it had;
  * the Ash Tomato's own twins ("~np", R149) are identical too (nothing but its flat ash patches differs, and not even those here).
Prints one summary line per group and 'only the shine parts differ' when it holds (exit 0), else the offending lines (exit 1)."""
import sys

# plant -> shine parts of its two sampled crops' ripe plant (the parts of the 'ripe' mode drop by this much)
SHINE = {
    'SunflowerSeed': 2,      # Watermelon: 'Fruit gloss' x2
    'SnowdropSeed': 2,       # Snow Melon: 'Fruit gloss' x2
    'EmberBloomSeed': 2,     # Ember Pumpkin: 'Fruit gloss' x2
    'AppleSeed': 4,          # Apple: 'Fruit gloss' x4
    'ElderbloomSeed': 5,     # Elderbloom's elder apples: 'Fruit gloss' x5
    'BluebellSeed': 12,      # Blueberry: 'Berry glint' x12
    'IceberrySeed': 12,      # Iceberry: 'Berry glint' x12
    'MoonflowerSeed': 2,     # Moon Melon: 'Moon glint' x2
    'VeritySeed': 4,         # Verity: 'Verity gloss' x2 + 'Verity glint' x2
}
MUST_MATCH = ('catalog', 'key', 'prompt')


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
bad = []
if set(base) != set(new):
    bad.append('different rows: %s' % sorted(set(base) ^ set(new))[:10])
plain_plants, plain_lines = set(), 0
shine = {}
for key in sorted(set(base) & set(new)):
    plant, crop, mode = key
    b, n = base[key], new[key]
    if b[0].startswith('ERR') or n[0].startswith('ERR'):
        bad.append('%s %s %s did not build (%s / %s)' % (plant, crop, mode, b[0], n[0]))
    if plant in SHINE:
        shine.setdefault((plant, crop), {})[mode] = (b, n)
    else:
        plain_plants.add(plant)
        plain_lines += 1
        if b != n:
            bad.append('%s %s %s changed: %s -> %s' % (plant, crop, mode, b[0][:12], n[0][:12]))
removed_lines = 0
for (plant, crop), modes in sorted(shine.items()):
    for mode, (b, n) in sorted(modes.items()):
        if mode.endswith('~ng'):
            if b != n:
                bad.append('%s %s %s: changed beyond the shine parts (the twin without them differs)' % (plant, crop, mode))
        elif crop == '-' or mode == 'key' or kind(mode) in MUST_MATCH:
            if b != n:
                bad.append('%s %s %s changed (must not)' % (plant, crop, mode))
        elif b != n:
            twin = modes.get(mode + '~ng')
            if twin is None or twin[0] != twin[1]:
                bad.append('%s %s %s: changed beyond the shine parts' % (plant, crop, mode))
            else:
                removed_lines += 1
    if crop != '-':
        if modes['specs'][0][0] == modes['specs'][1][0]:
            bad.append('%s %s: the shine parts were not removed (the specs are identical)' % (plant, crop))
        before, after = int(modes['ripe'][0][1]), int(modes['ripe'][1][1])
        if before - after != SHINE[plant]:
            bad.append('%s %s: the ripe plant lost %d parts, the shine parts are %d' % (plant, crop, before - after, SHINE[plant]))
seen = {p for (p, c) in shine}
for must in SHINE:
    if must not in seen:
        bad.append('%s was not compared' % must)
catalog = {p for (p, c, m) in base if m == 'catalog'}
if len(catalog) < 65:
    bad.append('only %d plants in the dump (65 expected)' % len(catalog))
print('%d plants (%d lines, every mode) identical to the base: nothing but the nine below changed (the Prickly Pear, Lantern Fern, Amethyst Grape, every other fruit)' % (len(plain_plants), plain_lines))
print('the nine plants that had shine parts (Watermelon, Snow Melon, Ember Pumpkin, Apple, Elderbloom, Blueberry, Iceberry, Moon Melon, Verity): %d lines differ, every one ONLY by the removed '
      'shine parts (the "~ng" twins without them are identical); their ripe plants lose exactly %s parts' % (removed_lines, ', '.join('%s %d' % (k, v) for k, v in SHINE.items())))
if bad:
    print('\n'.join(bad[:40]))
    sys.exit(1)
print('only the shine parts differ')
