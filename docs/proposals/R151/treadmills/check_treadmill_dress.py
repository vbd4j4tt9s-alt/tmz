"""R151 treadmill look PROPOSAL: checks of the prototype on the Roblox mock scenes (treadmill_scene.luau, before = today, after = + the
prototype TreadmillDress151.luau), per level 1..7:
  * the training belt (size, CFrame, CanCollide) is identical before and after; no part of the treadmill art or of the sign collides or
    answers raycasts (CanCollide / CanQuery false: the step detection only ever sees the belt);
  * new parts within the per-grade budget (net of the retired belt pieces), real lights within the per-grade cap;
  * the "+N/step" label = Config.TrainingPointsPerSecond (100) x Config.TrainingInterval (1/6 s) x the machine multiplier, popup format;
  * z-fighting: the R149 detector (docs/proposals/R149/tools/zfight.py, same rules as run_zfight.sh) on the whole base, before vs after:
    no counted finding involves a new part (TreadmillDress / TreadmillUpgradeSign), and no counted finding is new.
Usage: python3 check_treadmill_dress.py <scenes dir with before.txt / after.txt> <repo>   (exit 1 on any failure)"""
import collections, json, os, re, sys, tempfile

scenes, repo = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(repo, 'docs', 'proposals', 'R149', 'tools'))
import zfight as Z  # noqa: E402

MULT = [1, 4, 20, 100, 600, 4000, 30000]  # BalanceValues81.MachineMultipliers (R81 override)
GRADE = ['low', 'low', 'mid', 'mid', 'mid', 'top', 'top']
BUDGET = {'low': 48, 'mid': 48, 'top': 48}
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
    check('L%d new parts within the %s budget (%d net <= %d)' % (L, g, new - retired, BUDGET[g]), new - retired <= BUDGET[g])
    check('L%d real lights within the %s cap (%s <= %d)' % (L, g, a['lights'], CAP[g]), int(a['lights']) <= CAP[g])
    want = '+' + fmt(100 / 6 * MULT[L - 1]) + '/step'
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
    mine = [f for f in res['after'][1] if 'TreadmillDress' in f['pathA'] + f['pathB'] or 'TreadmillUpgradeSign' in f['pathA'] + f['pathB']]
    new = [f for f in res['after'][1] if ak[key(f)] > bk.get(key(f), 0)]
    print('L%d z-fighting: before %d counted on the base, after %d; with a new part %d; new vs before %d'
          % (L, len(res['before'][1]), len(res['after'][1]), len(mine), len(new)))
    for f in (mine + new)[:12]:
        print('   %-8s off=%+.4f area=%6.2f %s.%s <-> %s.%s' % (f['tier'], f['offset'], f['area'], f['pathA'][-70:], f['faceA'], f['pathB'][-70:], f['faceB']))
    check('L%d z-fighting: no counted finding with a new part, none new' % L, not mine and not new)
print('treadmill dress checks: %s' % ('all passed' if not fails else '%d FAILED' % fails))
sys.exit(1 if fails else 0)
