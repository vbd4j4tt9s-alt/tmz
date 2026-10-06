"""R151: breaks a COPY of the notification badge / default pack shape code in one specific way, so run_badges.sh --mutations can prove the suites notice it.
Usage: python3 mutate_badges.py <src dir (a COPY: it is edited in place)> <mutation name | list | suite NAME>
`suite NAME` prints which suite is meant to catch it (shape, badge, daily)."""
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
    'margin4': ('badge', 'NotifyBadge151.lua', 'Margin=16,', 'Margin=4,'),
    # HudLayout forgets the badge margin (a hard 4)
    'hud_pad4': ('badge', 'HudLayout.lua', 'local PAD=okBadge and NotifyBadge.Margin or 16', 'local PAD=4'),
    # the disc is a rounded square, not a circle
    'not_circle': ('badge', 'NotifyBadge151.lua', 'c.CornerRadius=UDim.new(1,0)', 'c.CornerRadius=UDim.new(0,6)'),
    # the tab dots hang out of their tab again (the tab row clips at its top)
    'dot_out': ('badge', 'ChestIndex.client.lua', "Badge.Make(t.Button,'RewardDot',Badge.Sizes.Dot,Badge.Overhang.Dot)", "Badge.Make(t.Button,'RewardDot',Badge.Sizes.Dot,3)"),
    # the DAILY badge hangs off the top of the screen again
    'daily_off_screen': ('daily', 'DailyRewardsClient.client.lua', "Badge.Make(dailyButton,'RewardBadge',Badge.Sizes.Daily,Badge.Overhang.Daily)", "Badge.Make(dailyButton,'RewardBadge',Badge.Sizes.Daily,12)"),
    # past nine the badge says 10, 11 ...
    'no_overflow': ('badge', 'NotifyBadge151.lua', "return n>9 and'9+'or tostring(n)", 'return tostring(n)'),
    # the count is not centred on the disc
    'text_off_center': ('badge', 'NotifyBadge151.lua', "label.Position=UDim2.fromScale(.5,.5)", "label.Position=UDim2.fromScale(.5,.62)"),
    # a badge that appears under Reduced Motion still pops in
    'reduced_ignored': ('badge', 'NotifyBadge151.lua', 'if Gui.ReducedMotionEnabled then\n  local scale=b:FindFirstChildOfClass', 'if false then\n  local scale=b:FindFirstChildOfClass'),
    # switching Reduced Motion on does not stop the pulses that are running
    'reduced_keeps_pulse': ('badge', 'NotifyBadge151.lua', 'if Gui.ReducedMotionEnabled then for badge in pairs(pulses)do stop(badge)end end', 'if false then for badge in pairs(pulses)do stop(badge)end end'),
    # R153: the badges are back at their R151 size (24 / 20 / 20 / 14)
    'sizes_r151': ('badge', 'NotifyBadge151.lua', 'B.Sizes={Count=36,Alert=30,Daily=30,Dot=21}', 'B.Sizes={Count=24,Alert=20,Daily=20,Dot=14}'),
    # R153: the MENU alert hangs so far past its corner that it leaves the screen
    'alert_off_screen': ('badge', 'NotifyBadge151.lua', 'B.Overhang={Count=9,Alert=9,', 'B.Overhang={Count=9,Alert=26,'),
    # R153: the INDEX count hangs further than the wheel's CanvasGroup keeps room for (cut flat again)
    'count_cut': ('badge', 'NotifyBadge151.lua', 'B.Overhang={Count=9,', 'B.Overhang={Count=20,'),
    # SeedPackVisuals.Bag does not mark the bag DefaultPackShape (the flag is lost between the picture and the renderer)
    'no_default_flag': ('shape', 'SeedPackVisuals.lua', "if defaultShape==true then m:SetAttribute('DefaultPackShape',true)\n    elseif", "if false then m:SetAttribute('DefaultPackShape',true)\n    elseif"),
    # SeedPackRenderer asks for a shape variation even for a marked bag
    'renderer_ignores_flag': ('shape', 'SeedPackRenderer.lua', "local shape=bag:GetAttribute('DefaultPackShape')~=true and bag:GetAttribute('PackShape')or nil", "local shape=bag:GetAttribute('PackShape')"),
    # the Index's look has no key of its own: it shares the hotbar's shaped template
    'no_plain_key': ('shape', 'ItemPictures.lua', "..(plain and'|Plain'or'')", "..''"),
    # R152: the Verity pack takes a shape again (its Index / hotbar pictures and the world pack carry a PackShape)
    'verity_shaped': ('shape', 'PackShapes151.lua', "or variantKey==require(script.Parent.VerityCatalog).Variant then return false end", " then return false end"),
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
