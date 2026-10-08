"""R153: breaks a COPY of src in one specific way so run_fixes.sh mutate can prove the R153 suites notice it.
Usage: python3 mutate153.py <src dir (a COPY: edited in place)> <mutation name | list | suite NAME>
`suite NAME` prints which test is meant to catch it: barrier (test_barrier153), belt (test_belt153), popups (test_popups153)."""
import os
import sys

src, name = sys.argv[1], sys.argv[2]
RS = 'ReplicatedStorage/'

# name: (suite, file under src, old text, new text)
M = {
    # the barrier is as tall as the old 53-stud wall again (it stands over the keys and the gatehouse)
    'barrier_tall': ('barrier', RS + 'RefreshBarrier.lua', 'local top=math.min(G.BeamY0,G.KeyY-G.KeySize/2)-B.Margin.Top', 'local top=line.Position.Y-1+53'),
    # it ignores the hanging keys: only the gatehouse's lower edge limits it (the moon and the count sit behind the keys again)
    'barrier_over_keys': ('barrier', RS + 'RefreshBarrier.lua', 'local top=math.min(G.BeamY0,G.KeyY-G.KeySize/2)-B.Margin.Top', 'local top=G.BeamY0-B.Margin.Top'),
    # it is as wide as the old 188-stud wall (it runs into the tower shafts)
    'barrier_wide': ('barrier', RS + 'RefreshBarrier.lua', 'local half=G.TowerX-G.TowerD/2-B.Margin.Side', 'local half=94'),
    # the sign is the full-size R124 sign (taller than the panel)
    'barrier_sign_full': ('barrier', RS + 'RefreshBarrier.lua', 'local k=math.min(1,canvas.Y*B.Fill/B.SignSize.Y)', 'local k=1'),
    # the barrier's front face lies in the plane of the gatehouse's / haunches' front faces (z-fighting)
    'barrier_coplanar': ('barrier', RS + 'RefreshBarrier.lua', 'local z=math.min(startZ,line.Position.Z)', 'local z=math.min(startZ,line.Position.Z)-2.5'),
    # the barrier reads its numbers from nowhere (hard-coded, the kit is ignored)
    'barrier_not_from_kit': ('barrier', RS + 'RefreshBarrier.lua', "return{TowerX=G.TowerX or 99,TowerD=G.TowerD or 14.4,BeamY0=G.BeamY0 or 44,KeyY=G.KeyY or 50,KeySize=G.KeySize or 15,", 'return{TowerX=99,TowerD=14.4,BeamY0=44,KeyY=50,KeySize=15,'),
    # the gate keys are back in the R152 frame: the legends read sideways (bottom to top)
    'keys_old_frame': ('barrier', RS + 'HubDecorKit151.lua', 'function K.KeyFrame(pos)return CFrame.fromMatrix(pos,V(0,-1,0),V(0,0,-1),V(1,0,0))end', 'function K.KeyFrame(pos)return CFrame.fromMatrix(pos,V(-1,0,0),V(0,0,-1),V(0,-1,0))end'),
    # the keys face the wrong way round (mirrored): reading toward +X
    'keys_mirrored': ('barrier', RS + 'HubDecorKit151.lua', 'function K.KeyFrame(pos)return CFrame.fromMatrix(pos,V(0,-1,0),V(0,0,-1),V(1,0,0))end', 'function K.KeyFrame(pos)return CFrame.fromMatrix(pos,V(0,-1,0),V(0,0,-1),V(-1,0,0))end'),
    # no wings: the centre slab is the whole width again (it runs into the haunches)
    'barrier_no_wings': ('barrier', RS + 'RefreshBarrier.lua', 'local core=math.min(half,foot+math.max(0,G.BeamY0-top)/slope)', 'local core=half'),
    # the wing slabs reach the full height (into the haunches)
    'barrier_wing_into_haunch': ('barrier', RS + 'RefreshBarrier.lua', 'local edge=core<half and G.BeamY0-(half-foot)*slope or top', 'local edge=top'),
    # the pattern is behind the quality gate again (the R152 cause)
    'belt_gated': ('belt', RS + 'TreadmillFx.lua', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible and record.Distance<=range', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible and record.Distance<=range and policy.Animate'),
    # FastMode stops it
    'belt_fastmode': ('belt', RS + 'TreadmillFx.lua', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible and record.Distance<=range', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and not policy.Fast and record.Visible and record.Distance<=range'),
    # Reduced Motion does not stop it
    'belt_reduced': ('belt', RS + 'TreadmillFx.lua', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible', 'record.Scrolling=#l.Textures>0 and record.Visible'),
    # it scrolls from any distance
    'belt_far': ('belt', RS + 'TreadmillFx.lua', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible and record.Distance<=range', 'record.Scrolling=#l.Textures>0 and not policy.Reduced and record.Visible'),
    # a layer runs faster than the chevrons again
    'belt_layer_rate': ('belt', RS + 'TreadmillLook151.lua', "Glow={'circuit',RGB(255,236,120),.15,4.6,4.6,1}", "Glow={'circuit',RGB(255,236,120),.15,4.6,4.6,1.6}"),
    # the training speed is not the chevrons'
    'belt_speed': ('belt', RS + 'TreadmillLook151.lua', 'L.Scroll={Training=3.0,', 'L.Scroll={Training=2.0,'),
    # the offset wraps past its tile (a jump at every wrap)
    'belt_jump': ('belt', RS + 'TreadmillFx.lua', 'local offset=(base+record.Travel*sign*e.Rate)%period', 'local offset=(base+record.Travel*sign*e.Rate)%(period*1.1)'),
    # a write on every tick, changed or not
    'belt_always_write': ('belt', RS + 'TreadmillFx.lua', "if e.Wrote~=offset then e.Wrote=offset;v['OffsetStuds'..axis]=offset end", "e.Wrote=offset;v['OffsetStuds'..axis]=offset"),
    # the live Sign override is ignored
    'belt_sign_ignored': ('belt', RS + 'TreadmillFx.lua', 'self.Axis=(axis==\'U\'or axis==\'V\')and axis or nil;self.Sign=(sign==1 or sign==-1)and sign or nil', 'self.Axis=nil;self.Sign=nil'),
    # the popups are 1x again (R154: the sizes are 1.6x R151's: 35 / 32 / 240 x 58 / 38 / 3)
    'popup_size_1x': ('popups', RS + 'SpeedPopupStyle.lua', 'S.Size = {Text = 35, Icon = 32, Box = {240, 58}, IconBox = 38, Gap = 3,', 'S.Size = {Text = 22, Icon = 20, Box = {150, 36}, IconBox = 24, Gap = 2,'),
    # R154: the popups are back at R153's 2x (the owner asked for 20% less)
    'popup_size_2x': ('popups', RS + 'SpeedPopupStyle.lua', 'S.Size = {Text = 35, Icon = 32, Box = {240, 58}, IconBox = 38, Gap = 3,', 'S.Size = {Text = 44, Icon = 40, Box = {300, 72}, IconBox = 48, Gap = 4,'),
    # the icon is not scaled
    'popup_icon_small': ('popups', RS + 'SpeedPopupStyle.lua', 'S.Size = {Text = 35, Icon = 32,', 'S.Size = {Text = 35, Icon = 20,'),
    # the fan ignores the screen (Base x Base everywhere: off a phone's screen)
    'popup_fan_blind': ('popups', RS + 'SpeedPopupStyle.lua', 'return clamp(x, f.Min, f.Max), clamp(y, f.Min, f.Max)', 'return 1.6, 1.6'),
    # the motion changed: a slower fling
    'popup_slow_fling': ('popups', RS + 'SpeedPopupStyle.lua', 'S.Fling = {Time = 0.40,', 'S.Fling = {Time = 0.55,'),
    # the rate changed: 15 a second
    'popup_rate': ('popups', RS + 'SpeedPopupStyle.lua', 'S.Cadence = {SplitTo = 2,', 'S.Cadence = {SplitTo = 3,'),
    # the pooled field no longer holds the biggest fan
    'popup_field_small': ('popups', RS + 'SpeedPopupStyle.lua', 'Width = 768, Height = 608,', 'Width = 440, Height = 330,'),
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
if name == 'suite':
    print(M[sys.argv[3]][0])
    sys.exit(0)
suite, file, old, new = M[name]
path = os.path.join(src, file)
text = open(path, encoding='utf-8').read()
assert text.count(old) == 1, (name, file, text.count(old), old[:70])
open(path, 'w', encoding='utf-8').write(text.replace(old, new, 1))
print('ok')
