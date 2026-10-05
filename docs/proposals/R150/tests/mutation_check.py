"""R150 mutation check: breaks TreadmillBonusClient in twelve ways a regression could (a listener that never stops, a leak, a lost tick, stacked
cues, overlapping rows, ...) and runs the R150 suites against each broken copy. Every mutation must make at least one suite FAIL; a mutation
that passes means a hole in the tests. Usage: python3 mutation_check.py [scratch dir]   (sh mutation_check.sh calls it)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
CLIENT = os.path.join(REPO, 'src/StarterPlayer/StarterPlayerScripts/TreadmillBonusClient.client.lua')
SCRATCH = sys.argv[1] if len(sys.argv) > 1 else '/tmp/r150_mutants'
src = open(CLIENT, encoding='utf-8').read()

MUTANTS = [
    ('an ambient effect is never cancelled', 'if ambient then cancelEffect(ambient);ambient=nil end', 'if ambient then ambient=nil end', ['ui']),
    ('a double Skip tap celebrates twice', ' if not spin or not current or revealed then return end', ' if not spin or not current then return end', ['audio']),
    ('finished bursts are not destroyed', 'burst:Destroy();local i=table.find(liveBursts,burst)', 'local i=table.find(liveBursts,burst)', ['ui']),
    ('the 4 Hz timer never stops', 'if training()then task.delay(.25,loop)else ticking=false end', 'task.delay(.25,loop)', ['ui']),
    ('no cooldown between ready cues', 'local now=os.clock();if now-lastCue<.25 then return end', 'local now=os.clock()', ['audio']),
    ('the gift timer clips its pop', 'ResetOnSpawn=false,Enabled=false,ClipsDescendants=false,ZIndexBehavior', 'ResetOnSpawn=false,Enabled=false,ClipsDescendants=true,ZIndexBehavior', ['ui']),
    ('the roll screen rows touch', 'local rowGap=8;', 'local rowGap=2;', ['layout']),
    ('ReducedMotion ignored by the ambient motion', 'stopAmbient();if reduced()then return end', 'stopAmbient();', ['ui']),
    ('the tick voices are built at the first tick (the dropped first tick)', 'do\n local id=Audio and Audio.Asset and Audio.Asset(\'MenuClick\')',
     'local function buildTicks()\n local id=Audio and Audio.Asset and Audio.Asset(\'MenuClick\')', ['audio']),
    ('the animator keeps its listener', 'if #effects==0 and effectConnection then effectConnection:Disconnect();effectConnection=nil end\n end\n addEffect',
     'if #effects==0 and effectConnection then effectConnection=nil end\n end\n addEffect', ['ui']),
    ('teardown forgets the gift timer', 'hud:Destroy();overlay:Destroy();bar:Destroy()', 'hud:Destroy();overlay:Destroy()', ['ui']),
    ('the lip is 6 px', 'local LIP=4\n', 'local LIP=6\n', ['layout']),
]
# the lazy-tick mutant also needs the first tick to build the pool
LAZY_FIX = ('local function tickSound(pitch)\n if #tickVoices==0 then return end', 'local function tickSound(pitch)\n if #tickVoices==0 then buildTicks() end\n if #tickVoices==0 then return end')


def run(tests, out):
    for t in tests:
        r = subprocess.run(['/opt/luau/luau', 'test_bonus_%s.luau' % t], cwd=out, capture_output=True, text=True)
        if r.returncode != 0:
            return t, (r.stdout + r.stderr).strip().splitlines()[-1][:110]
    return None, ''


bad = 0
os.makedirs(SCRATCH, exist_ok=True)
for i, (name, old, new, tests) in enumerate(MUTANTS, 1):
    out = os.path.join(SCRATCH, 'm%02d' % i)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    if src.count(old) != 1:
        print('M%02d %-70s SKIPPED (pattern found %d times)' % (i, name, src.count(old)))
        bad += 1
        continue
    mutated = src.replace(old, new)
    if 'buildTicks' in new:
        assert LAZY_FIX[0] in mutated
        mutated = mutated.replace(LAZY_FIX[0], LAZY_FIX[1])
    path = os.path.join(out, 'client_mut.lua')
    open(path, 'w', encoding='utf-8').write(mutated)
    for f in (os.path.join(REPO, 'tools/tests/roblox.luau'), os.path.join(REPO, 'docs/proposals/treadmill_bonus_R123/tests/world.luau'), os.path.join(HERE, 'ui_world.luau')):
        shutil.copy(f, out)
    for t in tests:
        shutil.copy(os.path.join(HERE, 'test_bonus_%s.luau' % t), out)
    subprocess.run([sys.executable, os.path.join(HERE, 'mkbundle.py'), out, 'TreadmillBonusClient=' + path], check=True, capture_output=True)
    failed, last = run(tests, out)
    if failed:
        print('M%02d %-70s caught by test_bonus_%s: %s' % (i, name, failed, last))
    else:
        print('M%02d %-70s NOT CAUGHT' % (i, name))
        bad += 1
print('%d mutants, %d not caught' % (len(MUTANTS), bad))
sys.exit(1 if bad else 0)
