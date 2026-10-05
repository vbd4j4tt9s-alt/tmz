"""R151: breaks a COPY of the Index PACKS / badge code in one specific way, so run_index_packs.sh --mutations can prove the suites notice it.
Usage: python3 mutate_indexpacks.py <src dir (a COPY: it is edited in place)> <mutation name | list | suite NAME>
`suite NAME` prints which suite is meant to catch it (data, ui, shape, badge, daily)."""
import os
import sys

src, name = sys.argv[1], sys.argv[2]
RS = os.path.join(src, 'ReplicatedStorage')
CLIENT = os.path.join(src, 'StarterPlayer', 'StarterPlayerScripts')


def patch(file, old, new):
    path = os.path.join(CLIENT if file.endswith('.client.lua') else RS, file)
    text = open(path, encoding='utf-8').read()
    assert text.count(old) == 1, (name, file, text.count(old), old[:70])
    open(path, 'w', encoding='utf-8').write(text.replace(old, new, 1))


# name: (suite that must notice it, file, old text, new text)
M = {
    # the badge's room in the wheel's CanvasGroup back to 4 px (the R150 cut)
    'margin4': ('badge', 'NotifyBadge151.lua', 'Margin=12,', 'Margin=4,'),
    # HudLayout forgets the badge margin (a hard 4)
    'hud_pad4': ('badge', 'HudLayout.lua', 'local PAD=okBadge and NotifyBadge.Margin or 12', 'local PAD=4'),
    # the disc is a rounded square, not a circle
    'not_circle': ('badge', 'NotifyBadge151.lua', 'c.CornerRadius=UDim.new(1,0)', 'c.CornerRadius=UDim.new(0,6)'),
    # the tab dots hang out of their tab again (the tab row clips at its top)
    'dot_out': ('badge', 'ChestIndex.client.lua', "Badge.Make(t.Button,'RewardDot',14,-3)", "Badge.Make(t.Button,'RewardDot',14,3)"),
    # the DAILY badge hangs off the top of the screen again
    'daily_off_screen': ('daily', 'DailyRewardsClient.client.lua', "Badge.Make(dailyButton,'RewardBadge',20,1)", "Badge.Make(dailyButton,'RewardBadge',20,6)"),
    # past nine the badge says 10, 11 ...
    'no_overflow': ('badge', 'NotifyBadge151.lua', "return n>9 and'9+'or tostring(n)", 'return tostring(n)'),
    # the count is not centred on the disc
    'text_off_center': ('badge', 'NotifyBadge151.lua', "label.Position=UDim2.fromScale(.5,.5)", "label.Position=UDim2.fromScale(.5,.62)"),
    # a badge that appears under Reduced Motion still pops in
    'reduced_ignored': ('badge', 'NotifyBadge151.lua', 'if Gui.ReducedMotionEnabled then\n  local scale=b:FindFirstChildOfClass', 'if false then\n  local scale=b:FindFirstChildOfClass'),
    # switching Reduced Motion on does not stop the pulses that are running
    'reduced_keeps_pulse': ('badge', 'NotifyBadge151.lua', 'if Gui.ReducedMotionEnabled then for badge in pairs(pulses)do stop(badge)end end', 'if false then for badge in pairs(pulses)do stop(badge)end end'),
    # the Index's pictures are not marked DefaultPackShape
    'no_default_flag': ('shape', 'IndexPacksView151.lua', "f:SetAttribute('DefaultPackShape',true)", "f:SetAttribute('DefaultPackShape',false)"),
    # SeedPackRenderer asks for a shape variation even for a marked bag
    'renderer_ignores_flag': ('shape', 'SeedPackRenderer.lua', "bag:GetAttribute('DefaultPackShape')~=true and require(script.Parent.PackShapes151).ForBuild(key) or nil", 'require(script.Parent.PackShapes151).ForBuild(key)'),
    # the Index's look has no key of its own: it shares the hotbar's shaped template
    'no_plain_key': ('shape', 'ItemPictures.lua', "..(plain and'|Plain'or'')", "..''"),
    # the Verity pack's Index picture is the server's shaped pouch
    'verity_ignores_flag': ('shape', 'VerityPackArt.lua', "if bag:GetAttribute('DefaultPackShape')==true then", 'if false then'),
    # the odds are the boosted ones (a hidden mechanic leaks into the list)
    'boosted_odds': ('data', 'IndexPackData151.lua', 'local odds=Rules.SeedOdds(cfg,stage,variant,1,version) -- luck 1', 'local odds=Rules.SeedOdds(cfg,stage,variant,1,version,2) -- luck 1'),
    # the spawn rates typed in instead of read from the weights
    'spawn_typed_in': ('data', 'IndexPackData151.lua', 'spawn[key]=100*Rules.Variants[key].SpawnWeight/weight', "spawn[key]=({Pack01=40,Pack02=30,Pack03=15,Pack04=8,Pack05=5,Pack06=2})[key]"),
    # a spawn rate in percent, not 1/N
    'percent_text': ('data', 'IndexPackData151.lua', 'Spawn={Percent=spawn[variant],Text=Odds.Format(spawn[variant])', 'Spawn={Percent=spawn[variant],Text=Odds.Percent(spawn[variant])'),
    # a word about a hidden mechanic in a card
    'pity_text': ('data', 'IndexPackData151.lua', "Of='of packs on its track'", "Of='of packs on its track (pity helps)'"),
    # a legacy sack listed
    'legacy_listed': ('data', 'IndexPackData151.lua', 'for _,variant in ipairs(Rules.VariantOrder)do\n   local e=track(', "for _,variant in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small'})do\n   local e=track("),
    # every card is built at once
    'eager_build': ('ui', 'IndexPacksView151.lua', 'PerPass=3,Margin=160', 'PerPass=3,Margin=1e9'),
}
if name == 'list':
    print(' '.join(M))
    sys.exit(0)
if name == 'suite':
    print(M[sys.argv[3]][0])
    sys.exit(0)
suite, file, old, new = M[name]
patch(file, old, new)
print('ok')
