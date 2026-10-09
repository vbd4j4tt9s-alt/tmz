"""R154 (+ R155's zoom): deliberate breakages of SpeedGainPopup.client.lua / SpeedPopupStyle.lua, each of which must make test_popups154 (docs/proposals/R154/tests) or the R151 style test fail: a suite that
still passes with the breakage would not protect the popups' constant size, their smooth flight, the caps or the pool.
(The badge text has its own mutants in docs/proposals/R151/tests/mutate_badges.py: text_small, text_nine_wide, text_scaled.)
Usage: python3 mutate154.py SCRATCH_DIR   (run_fixes.sh mutate calls it)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
R151 = os.path.join(REPO, 'docs/proposals/R151/tests')
SCRIPT = os.path.join(REPO, 'src/StarterPlayer/StarterPlayerScripts/SpeedGainPopup.client.lua')
STYLE = os.path.join(REPO, 'src/ReplicatedStorage/SpeedPopupStyle.lua')
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
script_src = open(SCRIPT, encoding='utf-8').read()
style_src = open(STYLE, encoding='utf-8').read()

# (name, file, [old, ...], [new, ...])
MUTATIONS = [
    # the own cap of the low tier (FastMode, a slow Studio) back to 4: every popup is cut short at 0.4 s
    ('own cap of tier 1 back to 4', 'style', '[1] = {Own = 8, Others = 1}', '[1] = {Own = 4, Others = 1}'),
    ('own cap of tier 2 back to 6', 'style', '[2] = {Own = 8, Others = 2}', '[2] = {Own = 6, Others = 2}'),
    # a busy pool takes the oldest LIVE popup again (it jumps to the new popup's place and text)
    ('a live popup is reused when the pool is busy', 'script', ['if #field.Free == 0 and #field.Popups < Style.Field.MaxFrames then', 'if not popup then return end'],
     ['if false then', 'if not popup then popup = table.remove(active, 1) end']),
    # the pool is not grown and the popup is simply dropped: nothing may be lost in a burst either
    ('the pool never grows (a burst drops popups)', 'script', 'if #field.Free == 0 and #field.Popups < Style.Field.MaxFrames then', 'if false then'),
    # the popup shrinks while it flies
    ('a popup shrinks in flight', 'style', 'return x, y, scale, alpha, age < S.Life and alpha > 0', 'return x, y, scale * (1 - 0.25 * math.min(age, 0.65)), alpha, age < S.Life and alpha > 0'),
    # the popups grow after the pop
    ('a popup grows after its pop', 'style', 'return x, y, scale, alpha, age < S.Life and alpha > 0', 'return x, y, scale + 0.15 * clamp((age - 0.3) / 0.3, 0, 1), alpha, age < S.Life and alpha > 0'),
    # the field is sized in studs (scale): it shrinks with the camera distance
    ('the field is sized in studs', 'script', 'gui.Size = UDim2.fromOffset(f.Width, f.Height)', 'gui.Size = UDim2.fromScale(f.Width / 40, f.Height / 40)'),
    # the popup's size follows the camera distance
    ('the size follows the camera distance', 'script', '\tscale = scale * unit\n', '\tscale = scale * unit * (30 / math.max(5, (workspace.CurrentCamera.CFrame.Position - popup.Field.Gui.Adornee.Position).Magnitude))\n'),
    # the unit is read every frame: a resize in flight changes the size of popups that are flying
    ('the unit is read every frame', 'script', '\tlocal unit = popup.Unit\n', '\tlocal unit = Style.Unit(workspace.CurrentCamera.ViewportSize.Y)\n'),
    # the fan hangs on the bobbing head again
    ('the fan hangs on the head', 'script', 'field.Gui.Adornee = root or head', 'field.Gui.Adornee = head'),
    # the z order is flat
    ('flat z order', 'script', 'popup.Frame.ZIndex = field.Seq', 'popup.Frame.ZIndex = 1'),
    # the position is written in big steps
    ('the position is written in 24 px steps', 'script', 'if math.abs(x - popup.PX) > 0.05 or math.abs(y - popup.PY) > 0.05 then', 'if math.abs(x - popup.PX) > 24 or math.abs(y - popup.PY) > 24 then'),
    # the transparency is written in half steps
    ('the transparency is written in half steps', 'script', 'if math.abs(alpha - popup.PA) > 0.004 then', 'if math.abs(alpha - popup.PA) > 0.5 then'),
    # a cut popup vanishes at once
    ('a cut popup vanishes opaque', 'style', 'S.RetireFade = 0.08', 'S.RetireFade = 0.0001'),
    # R153's sizes
    ('the sizes are R153\'s 2x again', 'style', 'S.Size = {Text = 35, Icon = 32, Box = {240, 58}, IconBox = 38, Gap = 3,', 'S.Size = {Text = 44, Icon = 40, Box = {300, 72}, IconBox = 48, Gap = 4,'),
    ('the outline is R153\'s 5 px', 'style', 'S.StrokeThickness = 4\n', 'S.StrokeThickness = 5\n'),
    # the pop is removed from the size check's reach: popups start tiny
    ('the pop starts far too small', 'style', 'S.Pop = {From = 0.45,', 'S.Pop = {From = 0.2,'),
    # the label sizes itself in scale
    ('the text is TextScaled', 'script', '\tlabel.TextSize = textSize\n', '\tlabel.TextSize = textSize\n\tlabel.TextScaled = true\n'),
    # R155 (the zoom): the pure curve
    ('R155: the popups do not shrink with the distance', 'style', 'local scale = math.min(z.Distance / math.max(num(distance, z.Distance), 0.05), z.MaxScale)', 'local scale = 1'),
    ('R155: no cap when the camera is close', 'style', 'local scale = math.min(z.Distance / math.max(num(distance, z.Distance), 0.05), z.MaxScale)', 'local scale = z.Distance / math.max(num(distance, z.Distance), 0.05)'),
    ('R155: the cap is 2x', 'style', 'MaxScale = 1.3,', 'MaxScale = 2.0,'),
    ('R155: the default zoom is 20 studs', 'style', 'S.Zoom = {Distance = 12.5,', 'S.Zoom = {Distance = 20,'),
    ('R155: never hidden', 'style', 'HideText = 12,', 'HideText = 0,'),
    ('R155: hidden at once, no fade', 'style', 'return scale, clamp((scale - hide) / (from - hide), 0, 1)', 'return scale, (scale > hide) and 1 or 0'),
    ('R155: a coarse epsilon (the size steps)', 'style', 'Epsilon = 0.004}', 'Epsilon = 0.1}'),
    ('R155: the field is R154\'s 768 x 608 again', 'style', "Width = 1000, Height = 792,", "Width = 768, Height = 608,"),
    # R155: the client
    ('R155: the container scale is never written', 'script', '\t\tfield.ZoomScale.Scale = scale\n', '\t\tfield.ZoomScale.Scale = 1\n'),
    ('R155: the container scale is written every frame', 'script', 'if not field.Hidden and (field.ZS == nil or math.abs(scale - field.ZS) > Style.Zoom.Epsilon) then', 'if not field.Hidden then'),
    ('R155: the container is never hidden', 'script', '\t\tfield.Zoom.Visible = not field.Hidden\n', '\t\tfield.Zoom.Visible = true\n'),
    ('R155: the fade is not applied to the popups', 'script', '\talpha = alpha * popup.Field.Fade -- (R155: the field\'s fade when the camera is far)\n', ''),
    ('R155: the camera is ignored', 'script', '\tcameraPosition = camera and camera.CFrame.Position or nil\n', '\tcameraPosition = nil\n'),
    ('R155: the distance is measured from the world origin', 'script', '(field.Anchor.Position + field.Offset - cameraPosition).Magnitude', '(field.Anchor.Position + field.Offset).Magnitude'),
    ('R155: the zoom is a frame late', 'script', ['\tif entry.Field then refreshZoom(entry.Field) end\n\tlocal pending = entry.Pending\n', '\treturn #active > 0 or #pending > 0\nend\n\nlocal function step()'],
     ['\tlocal pending = entry.Pending\n', '\tif entry.Field then refreshZoom(entry.Field) end\n\treturn #active > 0 or #pending > 0\nend\n\nlocal function step()']),
    ('R155: the popup itself takes the zoom (it would shrink twice)', 'script', '\tscale = scale * unit\n', '\tscale = scale * unit * (popup.Field.ZS or 1)\n'),
    ('R155: a hidden field is still moved', 'script', '\t\t\tif not popup.Field.Hidden then apply(popup, x, y, scale, alpha) end\n', '\t\t\tapply(popup, x, y, scale, alpha)\n'),
    ('R155: the popups are not in the container', 'script', '\tframe.Parent = field.Zoom\n', '\tframe.Parent = field.Gui\n'),
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
    subprocess.run([sys.executable, os.path.join(R151, 'mkbundle_speed_popups.py'), d, '%s=%s' % (key, mpath)], check=True, stdout=subprocess.DEVNULL)
    for f in (os.path.join(REPO, 'tools/tests/roblox.luau'), os.path.join(REPO, 'docs/proposals/treadmill_bonus_R123/tests/world.luau'), os.path.join(R151, 'speed_popups_world.luau'),
              os.path.join(R151, 'test_speed_popups_style.luau'), os.path.join(HERE, 'test_popups154.luau')):
        shutil.copy(f, d)
    failed = None
    for suite in ('test_popups154', 'test_speed_popups_style'):  # (the new checks first: they must see the glitches themselves; the R151 style test is the second net)
        r = subprocess.run(['/opt/luau/luau', suite + '.luau'], cwd=d, capture_output=True, text=True, timeout=900)
        if r.returncode != 0:
            failed = suite
            break
    print('%-52s %s' % (name, ('killed by ' + failed) if failed else 'SURVIVED'))
    if not failed:
        survivors.append(name)
if survivors:
    print('%d of %d mutations survived: %s' % (len(survivors), len(MUTATIONS), ', '.join(survivors)))
    sys.exit(1)
print('all %d mutations killed' % len(MUTATIONS))
