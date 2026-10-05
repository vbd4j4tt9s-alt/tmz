"""R151 speed popups mutation check: deliberate breakages of SpeedGainPopup.client.lua / SpeedPopupStyle.lua, each of which must make test_speed_popups_style or
test_speed_popups_client fail (a suite that still passes with the breakage would not protect the feel, the caps, the pool or the colours).
Usage: python3 mutation_speed_popups.py SCRATCH_DIR   (run_speed_popups.sh mutate calls it)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
SCRIPT = os.path.join(REPO, 'src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua')
STYLE = os.path.join(REPO, 'src/ReplicatedStorage/SpeedPopupStyle.lua')
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
script_src = open(SCRIPT, encoding='utf-8').read()
style_src = open(STYLE, encoding='utf-8').read()

# (name, file, old, new)
MUTATIONS = [
    ('cap ignored', 'script', 'if live >= cap then', 'if false then'),
    ('no pool: a new popup per spawn', 'script', 'local popup = table.remove(field.Free)', 'local popup = makePopup(field)'),
    ('popups are never hidden for reuse', 'script', '\tpopup.Frame.Visible = false\n\tpopup.Retired = nil', '\tpopup.Retired = nil'),
    ('popup frames destroyed instead of reused', 'script', '\tpopup.Frame.Visible = false\n\tpopup.Retired = nil\n\tlocal free = popup.Field.Free\n\tfree[#free + 1] = popup',
     '\tpopup.Frame:Destroy()\n\tpopup.Retired = nil\n\tlocal free = popup.Field.Free\n\tfree[#free + 1] = popup'),
    ('a tween per popup', 'script', '\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup', '\tgame:GetService("TweenService"):Create(popup.Frame, TweenInfo.new(1), {}):Play()\n\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup'),
    ('a task.delay per popup', 'script', '\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup', '\ttask.delay(1, function() end)\n\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup'),
    ('a Heartbeat listener per popup', 'script', '\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup', '\tRunService.Heartbeat:Connect(function() end)\n\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup'),
    ('the updater never disconnects', 'script', '\tif next(entries) == nil and connection then', '\tif false then'),
    ('a memory leak per spawn', 'script', '\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup', '\tLEAK = LEAK or {}\n\tLEAK[#LEAK + 1] = {now, item}\n\tpopup.Frame.Visible = true\n\tactive[#active + 1] = popup'),
    ('other players are split too', 'script', 'local split = Style.SplitFor(own, reducedMotion())', 'local split = Style.SplitFor(true, reducedMotion())'),
    ('Reduced Motion ignored', 'script', 'return ok and value == true\nend', 'return false\nend'),
    ('no range check', 'script', 'if camera and (camera.CFrame.Position - head.Position).Magnitude > Style.MaxDistance then return end', ''),
    # the stale-character check exists twice (when the award arrives, and every frame): both must go for an old character's award to show
    ('old-character awards accepted', 'script', ['if typeof(character) ~= "Instance" or targetPlayer.Character ~= character or targetPlayer.Parent == nil then return end',
                                               'if player.Parent == nil or player.Character ~= entry.Character or entry.Head.Parent == nil then return false end'],
     ['if typeof(character) ~= "Instance" or targetPlayer.Parent == nil then return end', 'if player.Parent == nil or entry.Head.Parent == nil then return false end']),
    ('a new character keeps the old popups', 'script', 'if player.Parent == nil or player.Character ~= entry.Character or entry.Head.Parent == nil then return false end', 'if player.Parent == nil then return false end'),
    ('a leaving player keeps their popups', 'script', '\tlocal entry = entries[player]\n\tif entry then\n\t\tfinishEntry(entry)\n\t\tentries[player] = nil\n\tend\n\tbags[player] = nil', '\tbags[player] = nil'),
    ('training is not checked', 'script', 'if player:GetAttribute("TreadmillTraining") == true and now - item.At < Style.Life then', 'if now - item.At < Style.Life then'),
    ('FastMode is not tier 1', 'script', '\tif localPlayer:GetAttribute("FastMode") == true then return 1 end\n', ''),
    ('amount shown is not the share', 'script', 'popup.Amount.Text = "+" .. Style.FormatGain(item.Amount)', 'popup.Amount.Text = "+" .. Style.FormatGain(item.Amount + 1)'),
    ('the extra points of a split are lost', 'script', 'each + (i <= extra and 1 or 0)', 'each'),
    ('amount colour changed to pure white', 'style', 'Text = {125, 248, 255}', 'Text = {255, 255, 255}'),
    ('bolt colour changed', 'style', 'Icon = {255, 222, 66}', 'Icon = {255, 255, 255}'),
    ('outline colour changed to black', 'style', 'TextStroke = {17, 26, 42}', 'TextStroke = {0, 0, 0}'),
    ('font changed', 'style', "S.Font = 'FredokaOne'", "S.Font = 'GothamBold'"),
    ('split off', 'style', 'S.Cadence = {SplitTo = 2,', 'S.Cadence = {SplitTo = 1,'),
    ('fling is a quad ease-out', 'style', 'S.Fling = {Time = 0.40, Power = 3,', 'S.Fling = {Time = 0.40, Power = 2,'),
    ('no pop', 'style', 'S.Pop = {From = 0.45, Time = 0.28, Back = 2.0}', 'S.Pop = {From = 1.0, Time = 0.28, Back = 0}'),
    ('lifetime 1.35 s again', 'style', 'S.Fade = {Start = 0.50, Length = 0.15}', 'S.Fade = {Start = 0.35, Length = 1.0}'),
    ('tier 2 caps wrong', 'style', '[2] = {Own = 6, Others = 2}', '[2] = {Own = 8, Others = 3}'),
    ('fan collapses to a narrow cone', 'style', 'HalfAngle = 75', 'HalfAngle = 15'),
    ('the same slot twice in a row', 'style', 'if bag.Last and slots[1] == bag.Last then slots[1], slots[#slots] = slots[#slots], slots[1] end', ''),
    ('reduced popup dead on its first frame', 'style', 'age < r.Life and (alpha > 0 or age < r.FadeIn)', 'age < r.Life and alpha > 0'),
    ('the share count ignores the points', 'style', 'return math.max(1, math.min(math.floor(amount), ticks * split, c.MaxShares))', 'return math.max(1, math.min(ticks * split, c.MaxShares))'),
    ('spacing ignores the split', 'style', 'return math.min(interval / math.max(1, num(split, 1)), 1 / math.max(1, num(shares, 1)))', 'return math.min(interval, 1 / math.max(1, num(shares, 1)))'),
]

survivors = []
for i, (name, which, old, new) in enumerate(MUTATIONS):
    src = script_src if which == 'script' else style_src
    mutated = src
    for o, n in zip(old if isinstance(old, list) else [old], new if isinstance(new, list) else [new]):
        if o not in mutated:
            print('MUTATION TARGET NOT FOUND: %s' % name)
            sys.exit(2)
        mutated = mutated.replace(o, n, 1)
    d = os.path.join(OUT, 'm%02d' % i)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    mpath = os.path.join(d, 'mutant.lua')
    open(mpath, 'w', encoding='utf-8').write(mutated)
    key = 'SpeedGainPopup' if which == 'script' else 'SpeedPopupStyle'
    subprocess.run([sys.executable, os.path.join(HERE, 'mkbundle_speed_popups.py'), d, '%s=%s' % (key, mpath)], check=True, stdout=subprocess.DEVNULL)
    for f in (os.path.join(REPO, 'tools/tests/roblox.luau'), os.path.join(REPO, 'docs/proposals/treadmill_bonus_R123/tests/world.luau'),
              os.path.join(HERE, 'speed_popups_world.luau'), os.path.join(HERE, 'test_speed_popups_style.luau'), os.path.join(HERE, 'test_speed_popups_client.luau')):
        shutil.copy(f, d)
    failed = None
    for suite in ('test_speed_popups_style', 'test_speed_popups_client'):
        r = subprocess.run(['/opt/luau/luau', suite + '.luau'], cwd=d, capture_output=True, text=True, timeout=900)
        if r.returncode != 0:
            failed = suite
            break
    print('%-48s %s' % (name, ('killed by ' + failed) if failed else 'SURVIVED'))
    if not failed:
        survivors.append(name)
if survivors:
    print('%d of %d mutations survived: %s' % (len(survivors), len(MUTATIONS), ', '.join(survivors)))
    sys.exit(1)
print('all %d mutations killed' % len(MUTATIONS))
