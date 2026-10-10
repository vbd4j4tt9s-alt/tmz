"""R158: deliberate breakages of SpeedGainPopup.client.lua / SpeedPopupStyle.lua, each of which must make test_popups158 (docs/proposals/R158/tests), the R154 popup test or the R151 style test fail,
or (the client's one call site) check_layout_site158.py: a suite that still passed with the breakage would not protect the new size, the phone rule, the zoom's distances or the cost.
Usage: python3 mutate_popups158.py SCRATCH_DIR   (run_popups158.sh mutate calls it)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
P = os.path.join(REPO, 'docs/proposals')
R151 = os.path.join(P, 'R151/tests')
R154 = os.path.join(P, 'R154/tests')
SCRIPT = os.path.join(REPO, 'src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua')
STYLE = os.path.join(REPO, 'src/ReplicatedStorage/SpeedPopupStyle.lua')
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
script_src = open(SCRIPT, encoding='utf-8').read()
style_src = open(STYLE, encoding='utf-8').read()

NEW_SIZE = 'S.Size = {Text = 53, Icon = 48, Box = {360, 86}, IconBox = 58, Gap = 5,'
CALL = 'popup.Unit, popup.FanX, popup.FanY = Style.Layout(viewport and viewport.X, viewport and viewport.Y)'
# (name, file, [old, ...], [new, ...])
MUTATIONS = [
    # the sizes
    ('the sizes are R154\'s again', 'style', NEW_SIZE, 'S.Size = {Text = 35, Icon = 32, Box = {240, 58}, IconBox = 38, Gap = 3,'),
    ('the text is bigger but the bolt is not', 'style', 'Icon = 48,', 'Icon = 32,'),
    ('the box is not bigger (the number would wrap)', 'style', 'Box = {360, 86}', 'Box = {240, 58}'),
    ('the text is 2x R154\'s (too big)', 'style', NEW_SIZE, 'S.Size = {Text = 70, Icon = 64, Box = {480, 116}, IconBox = 76, Gap = 6,'),
    ('the outline stays R154\'s 4 px', 'style', 'S.StrokeThickness = 6\n', 'S.StrokeThickness = 4\n'),
    ('the fan is R154\'s (the bigger popups pile up 2.25x)', 'style', 'S.Fan = {Base = 2.4, Max = 3.6, Min = 0.9,', 'S.Fan = {Base = 1.6, Max = 2.4, Min = 0.6,'),
    ('the half popup is R154\'s (the room is overestimated)', 'style', 'HalfWidth = 134, HalfHeight = 36,', 'HalfWidth = 89, HalfHeight = 24,'),
    ('the pooled field is R155\'s 1000 x 792 (the fan does not fit)', 'style', 'Width = 1500, Height = 1188,', 'Width = 1000, Height = 792,'),
    # the size share of a small screen
    ('phones get the full size (no size share)', 'style', 'if x * y >= want then return 1 end', 'if true then return 1 end'),
    ('the size share has no floor worth the name (phones below R154)', 'style', 'MinSize = 2 / 3}', 'MinSize = 0.4}'),
    ('the size share keeps too little of the fan', 'style', 'Keep = 0.85,', 'Keep = 0.5,'),
    ('the size share is far too strict (phones stay small)', 'style', 'Keep = 0.85,', 'Keep = 0.97,'),
    ('the size share searches once only (coarse)', 'style', 'for _ = 1, 12 do', 'for _ = 1, 1 do'),
    ('the size share searches the wrong way', 'style', 'if x * y >= want then lo = mid else hi = mid end', 'if x * y >= want then hi = mid else lo = mid end'),
    ('the fan does not know the size share', 'style', 'return fanAt(w, h, S.SizeScale(w, h))', 'return fanAt(w, h, 1)'),
    ('the unit does not carry the size share', 'style', 'return S.Unit(h) * size, x, y', 'return S.Unit(h), x, y'),
    ('the fan does not know the size share in Layout', 'style', '\tlocal x, y = fanAt(w, h, size)\n\treturn S.Unit(h) * size, x, y', '\tlocal x, y = fanAt(w, h, 1)\n\treturn S.Unit(h) * size, x, y'),
    ('Layout allocates a table (a table per popup)', 'style', '\treturn S.Unit(h) * size, x, y', '\tlocal t = {S.Unit(h) * size, x, y}\n\treturn t[1], t[2], t[3]'),
    ('SizeScale allocates a table (a table per call)', 'style', '\tlocal want = f.Keep * f.Base * f.Base\n', '\tlocal want = f.Keep * f.Base * f.Base\n\tlocal junk = {w, h}\n\twant = want + #junk * 0\n'),
    # the zoom keeps R155's distances
    ('the zoom cutoffs are R155\'s text px again (hidden at 55 studs)', 'style', 'HideScale = 12 / 35,', 'HideScale = 12 / 53,'),
    ('the zoom fade starts at R155\'s 14 px of 53 (47 studs)', 'style', 'FadeScale = 0.4,', 'FadeScale = 14 / 53,'),
    ('the zoom cap is 2x', 'style', 'MaxScale = 1.3,', 'MaxScale = 2.0,'),
    ('MaxDistance is cut to 30 studs', 'style', 'S.MaxDistance = 100', 'S.MaxDistance = 30'),
    # what must not move
    ('the fling is slower', 'style', 'S.Fling = {Time = 0.40,', 'S.Fling = {Time = 0.55,'),
    ('the pop starts tiny', 'style', 'S.Pop = {From = 0.45,', 'S.Pop = {From = 0.2,'),
    ('the rate is 15 a second', 'style', 'S.Cadence = {SplitTo = 2,', 'S.Cadence = {SplitTo = 3,'),
    ('the amount colour is white', 'style', 'Text = {125, 248, 255},', 'Text = {255, 255, 255},'),
    # the client
    ('the client uses the plain unit and fan (no size share)', 'script', CALL,
     'popup.Unit, popup.FanX, popup.FanY = Style.Unit(viewport and viewport.Y), Style.FanScale(viewport and viewport.X, viewport and viewport.Y)'),
    ('the client reads the layout every frame (in apply)', 'script', '\tlocal unit = popup.Unit\n',
     '\tlocal unit = popup.Unit\n\tlocal camera = workspace.CurrentCamera\n\tlocal viewport = camera and camera.ViewportSize\n\tlocal u0 = Style.Layout(viewport and viewport.X, viewport and viewport.Y)\n\tunit = u0\n'),
]


def run_suites(d):
    for suite in ('test_popups158', 'test_popups154', 'test_speed_popups_style'):
        r = subprocess.run(['/opt/luau/luau', suite + '.luau'], cwd=d, capture_output=True, text=True, timeout=900)
        if r.returncode != 0:
            return suite
    return None


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
    subprocess.run([sys.executable, os.path.join(R151, 'mkbundle_speed_popups.py'), d, '%s=%s' % (key, mpath)], check=True, stdout=subprocess.DEVNULL)
    for f in (os.path.join(REPO, 'tools/tests/roblox.luau'), os.path.join(P, 'treadmill_bonus_R123/tests/world.luau'), os.path.join(R151, 'speed_popups_world.luau'),
              os.path.join(R151, 'test_speed_popups_style.luau'), os.path.join(R154, 'test_popups154.luau'), os.path.join(HERE, 'test_popups158.luau')):
        shutil.copy(f, d)
    killers = []
    if which == 'script':  # (the call site of the client is a static check: it must see a per-frame call)
        r = subprocess.run([sys.executable, os.path.join(HERE, 'check_layout_site158.py'), mpath], capture_output=True, text=True)
        if r.returncode != 0:
            killers.append('check_layout_site158')
    suite = run_suites(d)
    if suite:
        killers.append(suite)
    print('%-70s %s' % (name, ('killed by ' + ' and '.join(killers)) if killers else 'SURVIVED'))
    if not killers:
        survivors.append(name)
if survivors:
    print('%d of %d mutations survived: %s' % (len(survivors), len(MUTATIONS), ', '.join(survivors)))
    sys.exit(1)
print('all %d mutations killed' % len(MUTATIONS))
