"""R150 mutation check: breaks TreadmillBonusClient (and BonusGiftArt) in thirty ways a regression could (a listener that never stops, a leak, a lost tick, stacked
cues, overlapping rows, ...) and runs the R150 suites against each broken copy. Every mutation must make at least one suite FAIL; a mutation
that passes means a hole in the tests. Usage: python3 mutation_check.py [scratch dir]   (sh mutation_check.sh calls it)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
CLIENT = os.path.join(REPO, 'src/StarterPlayer/StarterPlayerScripts/TreadmillBonusClient.client.lua')
ART = os.path.join(REPO, 'src/ReplicatedStorage/BonusGiftArt.lua')
SCRATCH = sys.argv[1] if len(sys.argv) > 1 else '/tmp/r150_mutants'
src = open(CLIENT, encoding='utf-8').read()
art_src = open(ART, encoding='utf-8').read()

MUTANTS = [
    ('an ambient effect is never cancelled', 'if ambient then cancelEffect(ambient);ambient=nil end', 'if ambient then ambient=nil end', ['ui']),
    ('a double Skip tap celebrates twice', ' if not spin or not current or revealed then return end', ' if not spin or not current then return end', ['audio']),
    ('finished bursts are not destroyed', 'burst:Destroy();local i=table.find(liveBursts,burst)', 'local i=table.find(liveBursts,burst)', ['ui']),
    ('the 4 Hz timer never stops', 'if training()then task.delay(.25,loop)else ticking=false end', 'task.delay(.25,loop)', ['ui']),
    ('no cooldown between ready cues', 'local now=os.clock();if now-lastCue<.25 then return end', 'local now=os.clock()', ['audio']),
    ('the roll screen rows touch', 'local rowGap=8;', 'local rowGap=2;', ['layout']),
    ('ReducedMotion ignored by the ambient motion', 'stopAmbient();if reduced()then return end', 'stopAmbient();', ['ui']),
    ('the tick voices are built at the first tick (the dropped first tick)', 'do\n local id=Audio and Audio.Asset and Audio.Asset(\'MenuClick\')',
     'local function buildTicks()\n local id=Audio and Audio.Asset and Audio.Asset(\'MenuClick\')', ['audio']),
    ('the animator keeps its listener', 'if #effects==0 and effectConnection then effectConnection:Disconnect();effectConnection=nil end\n end\n addEffect',
     'if #effects==0 and effectConnection then effectConnection=nil end\n end\n addEffect', ['ui']),
    ('the lip is 6 px', 'local LIP=4\n', 'local LIP=6\n', ['layout']),
    # R150 review fix round
    ('the ribbon is under the reveal layer again (confetti crosses the header)',
     "BackgroundColor3=WHITE,ZIndex=5},panel) -- R150 review: above the reveal effect layer",
     "BackgroundColor3=WHITE,ZIndex=3},panel) -- R150 review: above the reveal effect layer", ['ui', 'layout']),
    ('the reveal layer is above the ribbon', "Size=UDim2.fromScale(1,1),Active=false,ZIndex=4},panel)",
     "Size=UDim2.fromScale(1,1),Active=false,ZIndex=30},panel)", ['ui', 'layout']),
    ('the reveal layer is back on the screen', "Size=UDim2.fromScale(1,1),Active=false,ZIndex=4},panel)",
     "Size=UDim2.fromScale(1,1),Active=false,ZIndex=30},overlay)", ['ui', 'layout']),
    ('the reveal word pops from its top-left corner',
     "word.AnchorPoint=Vector2.new(.5,.5);word.Position=UDim2.new(.5,0,0,y+wordH/2);word.Size=UDim2.new(1,-32,0,wordH);y+=wordH",
     "word.Position=status.Position;word.Size=UDim2.new(1,-32,0,wordH);y+=wordH", ['ui']),
    ('no Denied on a refusal', "if Audio then pcall(Audio.Play,'Denied')end -- R150 review",
     "if false then pcall(Audio.Play,'Denied')end -- R150 review", ['ui']),
    ('Denied also plays when a roll starts', "current=res;overlay.Enabled=true;layoutOverlay()",
     "current=res;if Audio then pcall(Audio.Play,'Denied')end;overlay.Enabled=true;layoutOverlay()", ['ui']),
    ('the HUD button pops from its top-left corner',
     "button.AnchorPoint=Vector2.new(.5,.5);button.Position=UDim2.fromOffset(r.X+r.W/2,r.Y+r.H/2);button.Size",
     "button.Position=UDim2.fromOffset(r.X,r.Y);button.Size", ['ui', 'layout']),
    ('the sparkle origin ignores the new anchor',
     "return button.Position.X.Offset-button.Size.X.Offset/2+26,button.Position.Y.Offset-button.Size.Y.Offset/2+(button.Size.Y.Offset-LIP)/2",
     "return button.Position.X.Offset+26,button.Position.Y.Offset+(button.Size.Y.Offset-LIP)/2", ['ui']),
    ('every card builds its gloss again', "if motion then -- R150 review: the soft gloss only on the special tiers",
     "if true then -- R150 review: the soft gloss only on the special tiers", ['ui']),
    ('twinkles sit on the odds fine print again', "{.3,.08},{.72,.07}})do",
     "{.3,.08},{.72,.07},{.5,.95},{.2,.95},{.8,.95},{.62,.9}})do", ['ui']),
    ('the sparkle burst is drawn off the gift',
     "local x,y=buttonCenter();spawnBurst(hud.Fx,x,y,sparkleOpts(GOLD,8))",
     "local x,y=buttonCenter();x,y=x+30,y+30;spawnBurst(hud.Fx,x,y,sparkleOpts(GOLD,8))", ['ui']),
    # R153: no bag line, the Secret tease
    ('the Secret tease is dropped (no Secret card on the reel)', " Style.Tease(reel,Rules.Strip.Win,Rules.Void,draw)", " local _unused=nil", ['ui']),
    ('the tease overwrites the winning card (a Secret always lands)', " Style.Tease(reel,Rules.Strip.Win,Rules.Void,draw)",
     " reel[Rules.Strip.Win]={Stage=Rules.Void.Stage,Variant=Rules.Void.Variant}", ['ui']),
    ('the bag line is back under the spin text', " result.Visible=false;result.Text=''", " result.Visible=true;result.Text='Ur pack is already in ur bag!'", ['ui', 'layout']),
    ('the spin text is not re-centred (it hangs at the top of the gap)', "status.Size=UDim2.new(1,-32,0,wordH+resultH)", "status.Size=UDim2.new(1,-32,0,wordH)", ['ui', 'layout']),
    ('special cards are animated off screen again', "if x>-Rules.Strip.CardWidth and x<viewW then animateDesign(entry,clock)end", "animateDesign(entry,clock)", ['ui']),
    ('the result line stays hidden after the reveal', " result.Visible=true;result.Text=(special", " result.Text=(special", ['ui', 'layout']),
    ('the fill is a plain pill inside the face again (a gap at its left end)', "pill(fillClip)\n", "\n", ['layout']),
    ('the fill is inset by 3 px again (it never reaches the outline)', "fill.Size=UDim2.fromScale(t.Fraction,1)", "fill.Size=UDim2.new(t.Fraction,-6*t.Fraction,1,-6)", ['layout', 'ui']),
    ('the plain pack stays under the picture', "if icon.Drawn.Parent then icon.Drawn:Destroy()end", "", ['image']),
    ('the button text is not stroked dark green', "label.TextStrokeColor3=Art.Pack.Edge;label.TextStrokeTransparency=0", "", ['ui', 'image']),
    ('the almost phase is not applied (no orange fill, no pulse)', "if phase~=lastPhase then lastPhase=phase;applyPhase(phase)end", "", ['ui', 'image']),
    # BonusGiftArt
    ('a sparkle is a Frame with two bars again', "BackgroundTransparency=0,ZIndex=opts.Z or 30},layer)\n",
     "BackgroundTransparency=0,ZIndex=opts.Z or 30},layer);if star then for k=1,2 do pill(make('Frame',{Name='Bar'..k,Size=UDim2.fromScale(1,.3)},frame))end end\n",
     ['style', 'ui'], 'art'),
    ('the shine sweeps the old way (pops in and out inside a tall card)', "stripe.Position=UDim2.fromScale(-.6+u*2,-.45)",
     "stripe.Position=UDim2.fromScale(-.35+u*1.5,-.45)", ['style'], 'art'),
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
ONLY = [t for t in os.environ.get('ONLY', '').split(',') if t]  # e.g. ONLY='tease,fill,picture' runs the mutants whose number or name contains one of them
for i, entry in enumerate(MUTANTS, 1):
    name, old, new, tests = entry[:4]
    if ONLY and not any(t == str(i) or t.lower() in name.lower() for t in ONLY):
        continue
    target = entry[4] if len(entry) > 4 else 'client'
    base = art_src if target == 'art' else src
    out = os.path.join(SCRATCH, 'm%02d' % i)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    if base.count(old) != 1:
        print('M%02d %-70s SKIPPED (pattern found %d times)' % (i, name, base.count(old)))
        bad += 1
        continue
    mutated = base.replace(old, new)
    if 'buildTicks' in new:
        assert LAZY_FIX[0] in mutated
        mutated = mutated.replace(LAZY_FIX[0], LAZY_FIX[1])
    path = os.path.join(out, 'client_mut.lua' if target == 'client' else 'art_mut.lua')
    open(path, 'w', encoding='utf-8').write(mutated)
    for f in (os.path.join(REPO, 'tools/tests/roblox.luau'), os.path.join(REPO, 'docs/proposals/treadmill_bonus_R123/tests/world.luau'), os.path.join(HERE, 'ui_world.luau')):
        shutil.copy(f, out)
    for t in tests:
        shutil.copy(os.path.join(HERE, 'test_bonus_%s.luau' % t), out)
    pair = ('TreadmillBonusClient=' if target == 'client' else 'BonusGiftArt=') + path
    subprocess.run([sys.executable, os.path.join(HERE, 'mkbundle.py'), out, pair], check=True, capture_output=True)
    failed, last = run(tests, out)
    if failed:
        print('M%02d %-70s caught by test_bonus_%s: %s' % (i, name, failed, last))
    else:
        print('M%02d %-70s NOT CAUGHT' % (i, name))
        bad += 1
print('%d mutants, %d not caught' % (len(MUTANTS), bad))
sys.exit(1 if bad else 0)
