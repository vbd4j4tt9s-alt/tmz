"""R154: compare two dump_odds.luau outputs (the base release and this checkout) and allow ONLY what the R154 80% rule changes.
Usage: python3 check_r154_dump.py BASE_DUMP NEW_DUMP      (CANON lines of the new dump are ignored here; run_seed_rarity.sh checks them against the base INDEX)
Every line must be byte-identical, except:
  ODDS  a live world pack (stage 1-7, Pack01-06, OddsVersion 149 or none) whose base table gives one seed more than 80%: the new table must equal the rule applied to the
        base table by THIS file's own re-implementation (to 1e-9), and the rule must leave every other table alone;
  INDEX the Pack01 chance of a seed of such a pack (luck 1, no version): the rule's number;
  TIP   a hold tooltip of such a pack: the same seed names in the same order, the chances = the new table's (as printed);
  ROLL  the seeded rolls of such a pack (OddsVersion 149): the same number of rolls.
VOID / VERITY / MECH (no clover in the dump), RARITY and every other line: identical."""
import math
import sys

ORDER = ['Common', 'Uncommon', 'Rare', 'Legendary', 'Mythic', 'Secret', 'Cosmic', 'King']
RANK = {t: i + 1 for i, t in enumerate(ORDER)}
LIMIT, UPGRADE = .80, .01


def read(path):
    return open(path, encoding='utf-8').read().splitlines()


def table(text):
    out = {}
    for kv in text.split(' '):
        if kv:
            k, v = kv.split('=')
            out[k] = float(v)
    return out


def shape(odds, rarity):
    """The R154 rule, written from the spec: one seed over 80% -> 1% to the next tier's seeds (else the rarest), paid by the top; the top at most 80%;
    the rest to the other seeds in proportion to their share. Returns (table, acted)."""
    live = {k: v for k, v in odds.items() if v > 0}
    total = sum(live.values())
    if len(live) < 2 or total <= 0:
        return odds, False
    top = min(live, key=lambda k: (-live[k], k))
    share = live[top] / total
    if share <= LIMIT + 1e-9:
        return odds, False
    r = lambda k: RANK.get(rarity.get(k, 'Common'), 0)
    above = sorted({r(k) for k in live if r(k) > r(top)})
    target = above[0] if above else max(r(k) for k in live)
    ups = sorted(k for k in live if r(k) == target)
    out = {k: v / total for k, v in odds.items()}
    for u in ups:
        out[u] += UPGRADE / len(ups)
    out[top] -= UPGRADE
    excess = out[top] - LIMIT
    if excess > 0:
        out[top] = LIMIT
        for k, v in live.items():
            if k != top:
                out[k] += excess * (v / total) / (1 - share)
    return {k: v * total for k, v in out.items()}, True


def commas(n):
    return '{:,}'.format(int(n))


def count(n, floor=1):
    n = max(floor, math.floor((n or 0) + .5))
    if n < 1000:
        return '%d' % n
    if n < 1e4:
        return commas(float('%.3g' % n))
    if math.floor(n / 1000 + .5) < 1000:
        return commas(math.floor(n / 1000 + .5)) + 'K'
    suffix = ['K', 'M', 'B', 'T', 'Qa']
    group = min(max(math.floor(math.log10(n) / 3), 2), 5)
    v = float('%.3g' % (n / 1000 ** group))
    if v >= 1000 and group < 5:
        group += 1
        v /= 1000
    return ('%g' % v) + suffix[group - 1]


def fmt(percent):
    if percent is None or percent != percent or percent <= 0 or percent == math.inf:
        return '—'
    return '1/' + count(1 / (min(percent, 100) / 100))


def near(a, b, rel=1e-9):
    return abs(a - b) <= rel * max(1, abs(a), abs(b))


def main(base_path, new_path):
    base = read(base_path)
    new = [l for l in read(new_path) if not l.startswith('CANON ')]
    if len(base) != len(new):
        sys.exit('FAIL: %d lines in the base dump, %d in the new one' % (len(base), len(new)))
    rarity = {}
    for l in base:
        if l.startswith('RARITY '):
            _, sid, r = l.split(' ', 2)
            rarity[sid] = r
    # the ODDS rows the rule must act on, from the BASE tables
    acted = {}   # (stage, variant, ver, luck, boost) -> new table
    bad = []
    changed = {'ODDS': 0, 'INDEX': 0, 'TIP': 0, 'ROLL': 0}
    for b, n in zip(base, new):
        if not b.startswith('ODDS '):
            continue
        bk, bt = b.split(' ', 6)[:6], b.split(' ', 6)[6] if len(b.split(' ', 6)) > 6 else ''
        nk, nt = n.split(' ', 6)[:6], n.split(' ', 6)[6] if len(n.split(' ', 6)) > 6 else ''
        if bk != nk:
            bad.append('ODDS key order differs: %s / %s' % (b[:60], n[:60]))
            continue
        _, stage, variant, ver, luck, boost = bk
        if bt == 'ERROR' or nt == 'ERROR':
            if bt != nt:
                bad.append('ODDS error state differs: ' + b[:80])
            continue
        live = 1 <= int(stage) <= 7 and variant in ('Pack01', 'Pack02', 'Pack03', 'Pack04', 'Pack05', 'Pack06') and ver in ('v149', 'vnil')
        want, did = shape(table(bt), rarity) if live else (table(bt), False)
        got = table(nt)
        if did:
            acted[(stage, variant, ver, luck, boost)] = got
        if set(want) != set(got) or any(not near(want[k], got[k]) for k in want):
            bad.append('ODDS %s %s %s %s %s: not the rule applied to the base table' % (stage, variant, ver, luck, boost))
        elif b != n:
            if not did:
                bad.append('ODDS %s %s %s %s %s changed though the rule does not act there' % (stage, variant, ver, luck, boost))
            changed['ODDS'] += 1
    for b, n in zip(base, new):
        if b == n or b.startswith('ODDS '):
            continue
        kind = b.split(' ', 1)[0]
        if kind == 'INDEX':
            _, sid, stage, pct, text = b.split(' ', 4)
            _, sid2, stage2, pct2, text2 = n.split(' ', 4)
            t = acted.get((stage, 'Pack01', 'vnil', 'L1', 'B0'))
            if sid != sid2 or stage != stage2 or t is None or not near(float(pct2), t.get(sid, -1)) or text2.strip() != fmt(float(pct2)):
                bad.append('INDEX %s changed but not to the rule\'s Pack01 number' % sid)
            changed['INDEX'] += 1
        elif kind == 'TIP':
            _, stage, variant, rows = b.split(' ', 3)
            _, stage2, variant2, rows2 = n.split(' ', 3)
            t = acted.get((stage, variant, 'v149', 'L1', 'B0'))
            names = [r.rsplit(': ', 1)[0] for r in rows.split(' | ')]
            names2 = [r.rsplit(': ', 1)[0] for r in rows2.split(' | ')]
            texts2 = sorted(r.rsplit(': ', 1)[1] for r in rows2.split(' | '))
            if (stage, variant) != (stage2, variant2) or t is None or names != names2 or texts2 != sorted(fmt(p) for p in t.values() if p > 0):
                bad.append('TIP %s %s changed but not to the rule\'s table' % (stage, variant))
            changed['TIP'] += 1
        elif kind == 'ROLL':
            _, ver, stage, variant, luck, counts = b.split(' ', 5)
            _, ver2, stage2, variant2, luck2, counts2 = n.split(' ', 5)
            total = lambda c: sum(int(kv.rsplit('=', 1)[1]) for kv in c.split(' ') if kv)
            if (ver, stage, variant, luck) != (ver2, stage2, variant2, luck2) or ver != '149' or (stage, variant, 'v149', luck, 'B0') not in acted or total(counts) != total(counts2):
                bad.append('ROLL %s %s %s %s changed where the rule does not act' % (ver, stage, variant, luck))
            changed['ROLL'] += 1
        else:
            bad.append('%s line changed: %s' % (kind, b[:100]))
    if bad:
        print('\n'.join(bad[:40]))
        sys.exit('FAIL: %d lines differ from the base in a way the R154 rule does not explain' % len(bad))
    print('ok: identical to the base except the R154 80%% rule: %d odds tables (%d live tables the rule acts on, each = this checker\'s own re-implementation), %d Index chances, %d tooltips, %d seeded roll rows'
          % (changed['ODDS'], len(acted), changed['INDEX'], changed['TIP'], changed['ROLL']))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
