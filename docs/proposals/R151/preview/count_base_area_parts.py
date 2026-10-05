"""R151 base area: part budget of the redesign scenes (base_area_scene.luau dumps).
Usage: python3 count_base_area_parts.py <scene.json> [...]
Per scene: the visible parts of today's hub (z < -95: bases, market, walls ...) and the R151 parts per group (Workspace/R151HubDressing/<group>),
split into Phase 1 (server-built, everyone shares them) and Phase 2 / options (client-built), plus SurfaceGuis, lights and emitters of R151."""
import collections, json, os, sys

PHASE = {'Walls': 'P1 server', 'Murals': 'P1 server', 'Banners': 'P1 server', 'Gate': 'P1 server', 'Paths': 'P1 server',
         'BaseEntrances': 'P1 server', 'Life': 'P2 client', 'Slots': 'P3 ghosts (preview only)', 'Skyline': 'P3 option client'}
for path in sys.argv[1:]:
    d = json.load(open(path))
    hub = collections.Counter()
    r151 = collections.Counter()
    for p in d['parts']:
        if 'R151HubDressing' in p['path']:
            r151[p['path'].split('/')[2]] += 1
        elif p['p'][2] < -95 and 'KeyboardTrackVisuals' not in p['path']:
            seg = p['path'].split('/')
            hub[seg[3] if len(seg) > 3 and seg[2] in ('Bases', 'EconomyHub') else seg[2]] += 1
    guis = sum(1 for g in d.get('guis', []) if 'R151HubDressing' in g['path'])
    print('== %s' % os.path.basename(path))
    print('   today\'s hub (visible parts, z < -95): %d  (%s)' % (sum(hub.values()), ', '.join('%s %d' % kv for kv in hub.most_common(8))))
    by_phase = collections.Counter()
    for g, n in sorted(r151.items(), key=lambda kv: (PHASE.get(kv[0], '?'), kv[0])):
        by_phase[PHASE.get(g, '?')] += n
        print('   R151 %-14s %5d  %s' % (g, n, PHASE.get(g, '?')))
    for ph, n in sorted(by_phase.items()):
        print('   R151 total %-26s %5d' % (ph, n))
    print('   R151 total parts %d, SurfaceGuis %d' % (sum(r151.values()), guis))
