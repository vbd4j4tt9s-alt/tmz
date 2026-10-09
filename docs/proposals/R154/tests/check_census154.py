"""R154 checks and numbers for run_census154.sh (base = the R153 release, now = this checkout).
Usage: python3 check_census154.py <base cw dir> <now cw dir>  (each holds s_t<tier>_<spot>.out: the census of lag153_census.luau + census154_tail.luau)
B1 (the SHADOWS lines): rules that must hold, then the before -> after table of the sun's shadow casters.
B3 (the census lines of the keyboard): rules on the phone's numbers (tier 2 only; tiers 3 and 1 are unchanged), then the before -> after table of the keyboard's
keys, SurfaceGuis, letter canvas pixels (= letter texture memory at 4 bytes a pixel) and letters.
Exit 1 when a rule fails."""
import os, re, sys

RUNS = [(3, 'hub'), (2, 'hub'), (1, 'hub'), (3, 'track'), (2, 'track'), (1, 'track')]


def lines(d, tier, spot):
    path = os.path.join(d, 's_t%d_%s.out' % (tier, spot))
    return open(path, encoding='utf-8', errors='replace').read().split('\n')


def shadows(d, tier, spot):
    for l in lines(d, tier, spot):
        if l.startswith('SHADOWS tier='):
            return dict((k, int(v)) for k, v in re.findall(r'(\w+)=(\d+)', l.split(' ', 3)[3]))
    raise SystemExit('no SHADOWS line for tier %d %s in %s' % (tier, spot, d))


def radius(d, tier, spot):
    # the census's own RADIUS line (drawn parts within 400 studs of the runner; the same definition as the audit's and run_perf153.sh's numbers)
    for l in lines(d, tier, spot):
        m = re.match(r'RADIUS tier=\d+ spot=\w+ r=400 drawn=(\d+) shadow=(\d+) shadow<1.5=(\d+)', l)
        if m:
            return int(m.group(2)), int(m.group(3))
    raise SystemExit('no RADIUS line for tier %d %s in %s' % (tier, spot, d))


def keyboard(d, tier, spot):
    for l in lines(d, tier, spot):
        m = re.match(r'CENSUS tier=\d+ spot=\w+ \| keyboard \| inst=(\d+) parts=(\d+) drawn=(\d+) mesh=(\d+) sgui=(\d+) sguiPx=([\d.]+)M labels=(\d+)', l)
        if m:
            return {'inst': int(m.group(1)), 'drawn': int(m.group(3)), 'keys': int(m.group(4)), 'sgui': int(m.group(5)), 'px': float(m.group(6)), 'labels': int(m.group(7))}
    return None


def main():
    base, now = sys.argv[1], sys.argv[2]
    bad = []
    rows = []
    for tier, spot in RUNS:
        b, n = shadows(base, tier, spot), shadows(now, tier, spot)
        b['within400'], b['within400_tiny'] = radius(base, tier, spot)
        n['within400'], n['within400_tiny'] = radius(now, tier, spot)
        tag = 'tier %d %s' % (tier, spot)
        rows.append((tag, b, n))
        if n['tiny_scripted'] != 0:
            bad.append('B1 %s: %d script-built parts under 1.5 studs still cast a shadow' % (tag, n['tiny_scripted']))
        if spot == 'hub' and b['tiny_scripted'] == 0:
            bad.append('B1 %s: the base side has no script-built tiny caster (the rule has nothing to do: is the base the R153 release?)' % tag)
        for k in ('tiny_saved', 'saved_casters', 'saved_nocast'):
            if b[k] != n[k]:
                bad.append('B1 %s: the saved map changed (%s %d -> %d)' % (tag, k, b[k], n[k]))
        for k in ('char_casters', 'char_tiny_casters', 'char_nocast'):
            if b[k] != n[k]:
                bad.append('B1 %s: characters / avatars changed (%s %d -> %d)' % (tag, k, b[k], n[k]))
        for k in ('big_casters', 'big_nocast'):
            if b[k] != n[k]:
                bad.append('B1 %s: parts of 1.5 studs and more changed (%s %d -> %d)' % (tag, k, b[k], n[k]))
        if n['casters'] != b['casters'] - (b['tiny_casters'] - n['tiny_casters']) - (b['kb_casters'] - n['kb_casters']):
            bad.append('B1 %s: casters do not add up (%d -> %d)' % (tag, b['casters'], n['casters']))
    print('B1: the sun\'s shadow casters, before -> after (R153 release -> this checkout)')
    print('| run | casters within 400 studs | of them under 1.5 studs | all casters in the workspace | script-built under 1.5 studs | saved map\'s own under 1.5 studs |')
    print('|---|---|---|---|---|---|')
    for tag, b, n in rows:
        print('| %s | %d -> %d | %d -> %d | %d -> %d | %d -> %d | %d -> %d |' % (
            tag, b['within400'], n['within400'], b['within400_tiny'], n['within400_tiny'], b['casters'], n['casters'],
            b['tiny_scripted'], n['tiny_scripted'], b['tiny_saved'], n['tiny_saved']))
    # B3 ---------------------------------------------------------------------------------------------------------------------------------------------------
    print('\nB3: the keyboard on the track (z 1300) and at the hub, before -> after')
    print('| run | keys (keycap meshes) | SurfaceGuis | letter canvas, M pixels | = texture memory, MB (4 bytes a pixel) | letters drawn | keyboard instances |')
    print('|---|---|---|---|---|---|---|')
    kb = {}
    for tier, spot in RUNS:
        b, n = keyboard(base, tier, spot), keyboard(now, tier, spot)
        kb[(tier, spot)] = (b, n)
        if not b or not n:
            print('| tier %d %s | (no keyboard drawn here) | | | | | |' % (tier, spot))
            continue
        print('| tier %d %s | %d -> %d | %d -> %d | %.1f -> %.1f | %.1f -> %.1f | %d -> %d | %d -> %d |' % (
            tier, spot, b['keys'], n['keys'], b['sgui'], n['sgui'], b['px'], n['px'], b['px'] * 4, n['px'] * 4, b['labels'], n['labels'], b['inst'], n['inst']))
    for tier in (3, 1):  # PC and tier 1 are unchanged by B3
        for spot in ('hub', 'track'):
            b, n = kb[(tier, spot)]
            if b != n:
                bad.append('B3 tier %d %s: the keyboard changed on a tier B3 does not touch (%s -> %s)' % (tier, spot, b, n))
    b, n = kb[(2, 'track')]
    if not b or not n:
        bad.append('B3 tier 2 track: no keyboard numbers')
    else:
        if not n['keys'] < b['keys']:
            bad.append('B3 tier 2 track: no fewer keys (%d -> %d)' % (b['keys'], n['keys']))
        if not n['px'] < b['px']:
            bad.append('B3 tier 2 track: no smaller letter canvas (%.1f -> %.1f M px)' % (b['px'], n['px']))
        if n['labels'] != b['labels'] and n['labels'] > b['labels']:
            bad.append('B3 tier 2 track: more letters (%d -> %d)' % (b['labels'], n['labels']))
    if bad:
        for x in bad:
            print('FAIL: ' + x)
        sys.exit(1)
    print('\nok B1: no script-built part under 1.5 studs casts a shadow; the saved map, characters / avatars and every part of 1.5 studs and more are as they were')
    print('ok B3: tier 2 has fewer keys, a smaller letter canvas and no more letters; tiers 3 and 1 are as they were')


if __name__ == '__main__':
    main()
