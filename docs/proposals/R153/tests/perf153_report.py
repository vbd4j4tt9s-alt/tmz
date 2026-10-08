"""R153 perf: the numbers of run_perf153.sh's census runs (lag153_census.luau with IMAGES), before -> after, per tier and spot.
Usage: python3 perf153_report.py <base census dir> <now census dir>   (each holds n_t<tier>_<spot>.out.gz)"""
import gzip, os, re, sys


def read(path):
    if not os.path.exists(path):
        return None
    with gzip.open(path, 'rt', encoding='utf-8', errors='replace') as f:
        lines = f.read().split('\n')
    out = {}
    for l in lines:
        m = re.match(r'GUI tier=\d+ spot=\w+ playergui instances=(\d+)', l)
        if m:
            out['ui'] = int(m.group(1))
        m = re.match(r'FALLBACK_LOADED .* playergui=(\d+) icon_fallbacks=(\d+) instances_in_them=(\d+)', l)
        if m:
            out['ui_loaded'], out['fallbacks_loaded'] = int(m.group(1)), int(m.group(3))
        m = re.match(r'FALLBACK tier=.* instances_in_them=(\d+)', l)
        if m:
            out['fallbacks'] = int(m.group(1))
        m = re.match(r'RADIUS tier=\d+ spot=\w+ r=400 drawn=(\d+)', l)
        if m:
            out['drawn400'] = int(m.group(1))
        m = re.match(r'LOOPS tier=\d+ spot=\w+ n=(\d+)', l)
        if m:
            out['loops'] = int(m.group(1))
        m = re.match(r'WRITES tier=\d+ spot=\w+ total/frame=([\d.]+) \| (.*)', l)
        if m:
            out['writes'] = float(m.group(1))
            g = re.search(r'giveaway pack \(client\) ([\d.]+)', m.group(2))
            out['giveaway'] = float(g.group(1)) if g else 0.0
            k = re.search(r'map/GuardianEncounters ([\d.]+)', m.group(2))
            out['keepers'] = float(k.group(1)) if k else 0.0
        m = re.match(r'LUAMS tier=\d+ spot=\w+ handlers=\d+ sum=([\d.]+) ms/frame \(mock, best of 4 windows\) (.*)', l)
        if m:
            out['luams'] = float(m.group(1))
            out['luatop'] = dict((a, float(b)) for a, b in re.findall(r'(\w+) ([\d.]+)', m.group(2)))
        m = re.match(r'CENSUS_TOTAL tier=\d+ spot=\w+ \| inst=(\d+) parts=(\d+)', l)
        if m:
            out['inst'], out['parts'] = int(m.group(1)), int(m.group(2))
    return out


ROWS = [('ui', 'PlayerGui instances (icons loading)', '%d'), ('ui_loaded', 'PlayerGui instances (icons loaded)', '%d'),
        ('fallbacks_loaded', '  of which hidden icon fallback strips', '%d'), ('inst', 'Workspace instances', '%d'),
        ('drawn400', 'drawn parts within 400 studs', '%d'), ('loops', 'per-frame connections alive', '%d'), ('writes', 'property writes / frame', '%.1f'),
        ('giveaway', '  the giveaway pack', '%.1f'), ('keepers', '  the keepers', '%.1f'), ('luams', 'Lua ms / frame (mock)', '%.2f')]


def main():
    base, now = sys.argv[1], sys.argv[2]
    for spot in ('hub', 'track'):
        cols = []
        for t in (3, 2, 1):
            b, n = read(os.path.join(base, 'n_t%d_%s.out.gz' % (t, spot))), read(os.path.join(now, 'n_t%d_%s.out.gz' % (t, spot)))
            cols.append((t, b or {}, n or {}))
        print('\n%s (tier 3 / tier 2 / tier 1), before -> after' % ('the hub plaza' if spot == 'hub' else 'the track (z 1300)'))
        print('| | tier 3 | tier 2 | tier 1 |')
        print('|---|---|---|---|')
        for key, label, fmt in ROWS:
            cells = []
            for t, b, n in cols:
                if key in b or key in n:
                    cells.append((fmt % b[key] if key in b else '?') + ' -> ' + (fmt % n[key] if key in n else '?'))
                else:
                    cells.append('')
            if any(cells):
                print('| %s | %s |' % (label, ' | '.join(cells)))
        for script in ('VoidGiveawayClient152', 'BeastAnimation', 'SettingsClient'):
            cells = []
            for t, b, n in cols:
                x, y = b.get('luatop', {}).get(script), n.get('luatop', {}).get(script)
                cells.append(('%.3f' % x if x is not None else '-') + ' -> ' + ('%.3f' % y if y is not None else '-'))
            print('| %s (Lua ms, mock) | %s |' % (script, ' | '.join(cells)))


if __name__ == '__main__':
    main()
