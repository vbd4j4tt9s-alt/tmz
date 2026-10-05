"""R151: compares two fingerprint_packs.luau outputs (BEFORE = the base commit, AFTER = this checkout), pack by pack and instance by instance.
Usage: python3 compare_fingerprints.py before.txt after.txt [--expect-only REGEX ...]

Prints the number of packs compared, how many are identical and, for the others, the differences grouped by what changed (instance name with its
digits folded, the properties that differ). With --expect-only, every difference must match one of the regexes (applied to the grouped
description) or the exit status is 1: "nothing but the documented fixes changed"."""
import collections, re, sys


def load(path):
    packs, cur = collections.OrderedDict(), None
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('PACK '):
            cur = line[5:]; packs[cur] = []
        elif line.startswith('  ') and cur is not None:
            packs[cur].append(line[2:])
    return packs


def fields(line):
    parts = line.split('|')
    return parts[0], parts[1] if len(parts) > 1 else '', parts[2:]


def fold(name):
    return re.sub(r'\d+', 'N', name)


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    expect = []
    if '--expect-only' in sys.argv:
        expect = [re.compile(x) for x in sys.argv[sys.argv.index('--expect-only') + 1:]]
    same = 0
    groups = collections.Counter()
    example = {}
    for label, la in a.items():
        lb = b.get(label)
        if lb is None:
            groups['missing in AFTER: ' + label] += 1
            continue
        if la == lb:
            same += 1
            continue
        da = collections.OrderedDict((fields(x)[0] + '|' + fields(x)[1] + '#' + str(i), x) for i, x in enumerate(la))
        db = collections.OrderedDict((fields(x)[0] + '|' + fields(x)[1] + '#' + str(i), x) for i, x in enumerate(lb))
        if len(la) != len(lb):
            groups['instance count %d -> %d (%s)' % (len(la), len(lb), label.split()[0])] += 1
            continue
        for xa, xb in zip(la, lb):
            if xa == xb:
                continue
            ca, na, pa = fields(xa); cb, nb, pb = fields(xb)
            if (ca, na) != (cb, nb):
                groups['order / identity changed: %s %s -> %s %s' % (ca, na, cb, nb)] += 1
                continue
            changed = sorted({p.split('=')[0] for p in set(pa) ^ set(pb)})
            key = '%s %s: %s' % (ca, fold(na), ','.join(changed) or '?')
            groups[key + '  [%s]' % label.split()[0]] += 1
            example.setdefault(key + '  [%s]' % label.split()[0], (label, xa, xb))
    print('%d packs compared, %d identical, %d changed' % (len(a), same, len(a) - same))
    bad = 0
    for k, v in sorted(groups.items()):
        ok = any(r.search(k) for r in expect) if expect else True
        print('  %s x%d  %s' % ('ok ' if ok else 'BAD', v, k))
        if not ok:
            bad += 1
            label, xa, xb = example.get(k, ('', '', ''))
            print('      e.g. %s\n        before: %s\n        after:  %s' % (label, xa[:300], xb[:300]))
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
