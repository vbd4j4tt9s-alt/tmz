"""R153: does the pinned SPEED NEEDED sign clip into anything saved in the owner's place (the hub, the gate, the track, its props)?

Usage: python3 -I check_label_clear.py <repo> <place.rbxl> <scratch dir>

For each of the 7 biome keepers: the sign's centre is the keeper's spawn point (the saved GuardianNPCPlaceholder_Stage<N>/HumanoidRootPart, which is
where ChaseService takes the camp from: GuardianHomeCFrames) + (0, resting body top + LIFT, 0). The resting body top is read from KeeperRigConfig152
(every part's rest frame, the golem's tree form too); LIFT and The Darkened's standing height are read from KeeperSpeedLabels.client.lua itself.
Nothing saved in the place (every part under Workspace but the keepers' own placeholders) may come within RADIUS studs of that centre: a fixed
104x36 px sign is a few studs across over the run-up and wider far away, so the nearest saved thing must be well clear of it.
The track gate (HubDecor151, built at run time from HubDecorKit151's K.Gate) is checked from its numbers: the Forest keeper is the nearest.
The Darkened's spawn is computed at run time from the map (the stage 7 pack ground), not saved: it stands in the stage 7 camp's lane and is covered
by the same arithmetic as the stage 7 keeper (same lane, no props over it).
Exit 1 when any sign is within RADIUS of a saved part or of the gate."""
import json, math, os, re, subprocess, sys

repo, place, out = sys.argv[1], sys.argv[2], sys.argv[3]
RADIUS = 12.0
os.makedirs(out, exist_ok=True)
label = open(os.path.join(repo, 'src/StarterPlayer/StarterPlayerScripts/KeeperSpeedLabels.client.lua'), encoding='utf-8').read()
LIFT = float(re.search(r'^local LIFT=([0-9.]+)', label, re.M).group(1))
DARK = float(re.search(r'^local DARKENED_TOP=([0-9.]+)', label, re.M).group(1))

# 1. resting body tops from KeeperRigConfig152 (rest frames are axis aligned; the golem's tree form has rotations)
cfg = open(os.path.join(repo, 'src/ReplicatedStorage/KeeperRigConfig152.lua'), encoding='utf-8').read()
tops = {}
for m in re.finditer(r'^ \[(\d)\]=\{Name=', cfg, re.M):
    stage = int(m.group(1))
    end = cfg.find('\n [', m.end())
    block = cfg[m.start(): end if end > 0 else len(cfg)]
    best = -1e9
    for line in block.split('\n'):
        p = re.search(r"\{Name='[A-Za-z_0-9]+',Group='[A-Za-z0-9_]+',Kind='[a-z]+',Center=\{([^}]*)\},Size=\{([^}]*)\}", line)
        if not p:
            continue
        c = [float(x) for x in p.group(1).split(',')]
        s = [float(x) for x in p.group(2).split(',')]
        best = max(best, c[1] + s[1] / 2)
        tr = re.search(r'TreeRest=\{([^}]*)\},TreeSize=\{([^}]*)\}', line)
        if tr:
            r = [float(x) for x in tr.group(1).split(',')]
            ts = [float(x) for x in tr.group(2).split(',')]
            best = max(best, r[1] + (abs(r[6]) * ts[0] + abs(r[7]) * ts[1] + abs(r[8]) * ts[2]) / 2)
    tops[stage] = best
tops[0] = DARK
assert all(tops[k] > 3 for k in range(0, 8)), tops

# 2. the saved geometry
geom = os.path.join(out, 'geom.json')
here = os.path.dirname(os.path.abspath(__file__))
subprocess.run([sys.executable, '-I', os.path.join(here, '../../R149/tools/rbxl_geom.py'), place, geom, 'Workspace'], check=True, stdout=subprocess.DEVNULL)
parts = json.load(open(geom))['parts']
homes = {}
for p in parts:
    m = re.search(r'GuardianNPCPlaceholder_Stage(\d)/HumanoidRootPart$', p['path'])
    if m:
        homes[int(m.group(1))] = p['p']
assert sorted(homes) == [1, 2, 3, 4, 5, 6, 7], 'saved keeper spawn points: %s' % sorted(homes)


def aabb(p):
    r, s, c = p['r'], p['size'], p['p']
    h = [0.5 * sum(abs(r[i][j]) * s[j] for j in range(3)) for i in range(3)]
    return [c[i] - h[i] for i in range(3)], [c[i] + h[i] for i in range(3)]


def gap(point, lo, hi):
    return math.sqrt(sum(max(lo[i] - point[i], 0, point[i] - hi[i]) ** 2 for i in range(3)))


bad = 0
for stage in range(1, 8):
    h = homes[stage]
    centre = [h[0], h[1] + tops[stage] + LIFT, h[2]]
    near, name = 1e9, None
    for p in parts:
        if 'GuardianNPCPlaceholder' in p['path']:
            continue
        lo, hi = aabb(p)
        g = gap(centre, lo, hi)
        if g < near:
            near, name = g, p['path']
    ok = near >= RADIUS
    bad += 0 if ok else 1
    print('stage %d: spawn (%.1f, %.1f, %.1f), body top %.1f over the root, sign centre y %.1f; nearest saved part %.1f studs away (%s) %s' % (
        stage, h[0], h[1], h[2], tops[stage], centre[1], near, '/'.join(name.split('/')[-2:]), 'ok' if ok else 'TOO CLOSE'))

# 3. the track gate (built at run time from HubDecorKit151: two rook towers and a gatehouse across the track)
kit = open(os.path.join(repo, 'src/ReplicatedStorage/HubDecorKit151.lua'), encoding='utf-8').read()
g = {k: float(v) for k, v in re.findall(r'(TowerX|TowerZ|TowerD|BeamY0|BeamY1)=(-?[0-9.]+)', re.search(r'^K\.Gate=\{[^\n]*', kit, re.M).group(0))}
lo = [-g['TowerX'] - g['TowerD'] / 2, 0, g['TowerZ'] - 7]
hi = [g['TowerX'] + g['TowerD'] / 2, g['BeamY1'] + 12, g['TowerZ'] + 7]
for stage in range(1, 8):
    h = homes[stage]
    centre = [h[0], h[1] + tops[stage] + LIFT, h[2]]
    d = gap(centre, lo, hi)
    ok = d >= RADIUS
    bad += 0 if ok else 1
    if stage == 1 or not ok:
        print('track gate (z %.0f, %.0f studs wide, up to y %.0f): the stage %d sign is %.1f studs from it %s' % (g['TowerZ'], 2 * g['TowerX'], g['BeamY1'] + 12, stage, d, 'ok' if ok else 'TOO CLOSE'))
print('R153 sign clearance: %d of 14 checks failed (RADIUS %.0f studs, LIFT %.0f)' % (bad, RADIUS, LIFT))
sys.exit(1 if bad else 0)
