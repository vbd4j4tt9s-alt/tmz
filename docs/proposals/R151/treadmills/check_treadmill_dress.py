"""R151 treadmill polish: checks on the Roblox mock scenes of Base 1 of the owner's place (treadmill_scene.luau: before = the base commit's src,
after = this checkout, with the R151 dressing in BiomeVisuals and the sign in GardenUpgradeService), per level 1..7:
  * the training belt (size, CFrame, CanCollide) is identical before and after; no part of the treadmill art or of the sign collides or
    answers raycasts (CanCollide / CanQuery false: the step detection only ever sees the belt);
  * new parts within the per-grade budget (TreadmillLook151.Grades), real lights of the whole machine within the per-grade cap;
  * the "+N/step" label = the round per-step gain of the level (100 points/s x 1/6 s x BalanceValues81.MachineMultipliers), popup format;
  * z-fighting: the R149 detector (docs/proposals/R149/tools/zfight.py, same rules as run_zfight.sh) on the whole base, before vs after:
    no counted finding involves a new part (TreadmillDress151, the sign / button rim parts), and no counted finding is new.
Usage: python3 check_treadmill_dress.py <scenes dir with before.txt / after.txt> <repo>   (exit 1 on any failure)"""
import collections, json, os, re, sys, tempfile

scenes, repo = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, 'docs', 'proposals', 'R149', 'tools'))
import zfight as Z  # noqa: E402

LABELS = ['+20/step', '+65/step', '+335/step', '+2K/step', '+10K/step', '+65K/step', '+500K/step']  # R151: round per-step gains (BalanceValues81)
GRADE = ['low', 'low', 'mid', 'mid', 'mid', 'top', 'top']
BUDGET = {'low': 44, 'mid': 50, 'top': 50}  # TreadmillLook151.Grades
CAP = {'low': 3, 'mid': 5, 'top': 6}


def fmt(n):
    for d, u in ((1e12, 'T'), (1e9, 'B'), (1e6, 'M'), (1e3, 'K')):
        if n >= d:
            s = '%.1f' % (n / d)
            return (s[:-2] if s.endswith('.0') else s) + u
    return '%.0f' % n


def read(which):
    budgets, zs = {}, {}
    for line in open(os.path.join(scenes, which + '.txt'), encoding='utf-8'):
        if line.startswith('BUDGET '):
            m = re.match(r'BUDGET (\w+) L(\d) (.*)', line.strip())
            kv = dict(x.split('=', 1) for x in re.findall(r'(\w+=\S+)', m.group(3)))
            belt = re.search(r'belt=(.*)$', m.group(3)).group(1)
            kv['belt'] = belt
            kv['label'] = re.search(r'label=(\S+)', m.group(3)).group(1)
            budgets[int(m.group(2))] = kv
        elif line.startswith('ZSCENE '):
            name, js = line[7:].split(' ', 1)
            zs[int(name.split('_L')[1])] = js
    return budgets, zs


fails = 0
MARKS = ('TreadmillDress151', 'GardenUpgradeButtons/Sign ', 'GardenUpgradeButtons/Button rim glow')


def check(name, ok, why=''):
    global fails
    print(('ok   ' if ok else 'FAIL ') + name + ('' if ok else ': ' + why))
    if not ok:
        fails += 1


def counted(f):
    return f['tier'] in Z.COUNTED and not f['same_look']


def key(f):
    return tuple(sorted((f['pathA'] + '.' + f['faceA'], f['pathB'] + '.' + f['faceB'])))


B, BZ = read('before')
A, AZ = read('after')
print('level  grade  parts before -> after (new, retired)  lights  emitters  beams  textures  sign  label')
for L in range(1, 8):
    b, a = B[L], A[L]
    g = GRADE[L - 1]
    new, retired = int(a['new']), int(a['retired'])
    print('L%d     %-4s   %3s -> %3s (+%d, -%d)                %s -> %s   %s -> %s     %s -> %s  %s -> %s       %s    %s'
          % (L, g, b['parts'], a['parts'], new, retired, b['lights'], a['lights'], b['emitters'], a['emitters'], b['beams'], a['beams'],
             b['textures'], a['textures'], a['sign'], a['label']))
    check('L%d belt collider unchanged' % L, b['belt'] == a['belt'], '%s vs %s' % (b['belt'], a['belt']))
    check('L%d belt still collides' % L, 'solid=true' in a['belt'])
    check('L%d nothing new collides or answers raycasts' % L, a['collide'] == '0' and a['query'] == '0' and b['collide'] == '0',
          'collide=%s query=%s' % (a['collide'], a['query']))
    check('L%d new parts within the %s budget (%d <= %d)' % (L, g, new, BUDGET[g]), new <= BUDGET[g])
    check('L%d real lights within the %s cap (%s <= %d)' % (L, g, a['lights'], CAP[g]), int(a['lights']) <= CAP[g])
    want = LABELS[L - 1]
    check('L%d label %s' % (L, want), a['label'] == want, a['label'])
    check('L%d belt textures scroll (%s texture layers)' % (L, a['textures']), int(a['textures']) >= 1)
# z-fighting on the whole base
bad = 0
for L in range(1, 8):
    res = {}
    for which, src in (('before', BZ), ('after', AZ)):
        with tempfile.NamedTemporaryFile('w', suffix='.json', delete=False) as fh:
            fh.write(src[L])
        parts, fs = Z.run(fh.name)
        os.unlink(fh.name)
        res[which] = (parts, [f for f in fs if counted(f)])
    bk = collections.Counter(key(f) for f in res['before'][1])
    ak = collections.Counter(key(f) for f in res['after'][1])
    mine = [f for f in res['after'][1] if any(m in f['pathA'] + ' ' + f['pathB'] for m in MARKS)]
    new = [f for f in res['after'][1] if ak[key(f)] > bk.get(key(f), 0)]
    print('L%d z-fighting: before %d counted on the base, after %d; with a new part %d; new vs before %d'
          % (L, len(res['before'][1]), len(res['after'][1]), len(mine), len(new)))
    for f in (mine + new)[:12]:
        print('   %-8s off=%+.4f area=%6.2f %s.%s <-> %s.%s' % (f['tier'], f['offset'], f['area'], f['pathA'][-70:], f['faceA'], f['pathB'][-70:], f['faceB']))
    check('L%d z-fighting: no counted finding with a new part, none new' % L, not mine and not new)
# clearance: no new part (dressing, sign, button rim) pokes into anything else of the base (beds, borders, fence, pedestal, buttons ...). Bounding
# boxes, so this is strict; what a new part may touch: the pad and the treadmill apron it stands on, the button housing the rim hugs, its own machine.
OWN = ('/TreadmillArtV131/', '/Pad', 'Treadmill apron', 'GardenUpgradeButtons/Treadmill housing')


def box(p):
    r, s = p['r'], p['size']
    e = [(abs(r[i][0]) * s[0] + abs(r[i][1]) * s[1] + abs(r[i][2]) * s[2]) / 2 for i in range(3)]
    return [p['p'][i] - e[i] for i in range(3)], [p['p'][i] + e[i] for i in range(3)]


for L in range(1, 8):
    parts = json.loads(AZ[L])['parts']
    new = [p for p in parts if any(m in p['path'] for m in MARKS)]
    rest = [p for p in parts if not any(m in p['path'] for m in MARKS) and not any(o in p['path'] for o in OWN)]
    hits = []
    for a in new:
        a0, a1 = box(a)
        for b in rest:
            b0, b1 = box(b)
            if all(a0[i] < b1[i] - .02 and a1[i] > b0[i] + .02 for i in range(3)):
                hits.append('%s x %s' % (a['path'].split('/')[-1], b['path'][-60:]))
    check('L%d clearance: no new part pokes into anything else of the base (%d new parts)' % (L, len(new)), not hits, '; '.join(hits[:6]))
print('treadmill dress checks: %s' % ('all passed' if not fails else '%d FAILED' % fails))
sys.exit(1 if fails else 0)
