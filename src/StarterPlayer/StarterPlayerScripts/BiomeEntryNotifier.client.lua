-- R69: illustrated biome crest and warm lettering; short, forward-only notices.
-- R124: a plain Frame faded element by element (a CanvasGroup that runs out of render memory draws unfaded, so the
-- title popped off instead of fading). Fades in, holds, then fades away.
local Players = game:GetService('Players')
local Run = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Styles = require(ReplicatedStorage:WaitForChild('BiomeTitleStyle'))
local Gate = require(ReplicatedStorage:WaitForChild('BiomeEntryGate'))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local map = workspace:WaitForChild('ChestChaseMap')
local old = playerGui:FindFirstChild('BiomeEntryUI')
if old then old:Destroy() end
local gui = Instance.new('ScreenGui')
gui.Name = 'BiomeEntryUI'
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 45
gui.Parent = playerGui
local group = Instance.new('Frame')
group.Name = 'BiomeTitle'
group.Size = UDim2.fromOffset(490, 110)
group.AnchorPoint = Vector2.new(.5, .5)
group.Position = UDim2.fromScale(.5, .18) -- User-approved original position.
group.BackgroundTransparency = 1
group.Visible = false
group.Parent = gui
local scale = Instance.new('UIScale')
scale.Parent = group
-- V140: biome lettering has no rectangular backdrop.
local title = Instance.new('TextLabel')
title.Name = 'BiomeName'
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(.5, .5)
title.Size = UDim2.fromOffset(350, 56)
title.Position = UDim2.fromOffset(292, 51)
title.Font = Enum.Font.FredokaOne
title.Text = ''
title.TextSize = 36
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeColor3 = Color3.fromRGB(20, 29, 35)
title.TextStrokeTransparency = .18
title.ZIndex = 3
title.Parent = group
local gradient = Instance.new('UIGradient')
gradient.Parent = title
-- Keep the name as the main landmark; the smaller illustrated badge decorates it.
local badge=Instance.new('Frame');badge.Name='BiomeBadge';badge.Size=UDim2.fromOffset(80,80);badge.Position=UDim2.fromOffset(27,9);badge.BackgroundTransparency=1;badge.BorderSizePixel=0;badge.Active=false;badge.Parent=group
local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=badge
local edge=Instance.new('UIStroke');edge.Name='BadgeRim';edge.Thickness=1.5;edge.Transparency=1;edge.Parent=badge
local ribbon=Instance.new('Frame');ribbon.Name='SoftRibbon';ribbon.Position=UDim2.fromOffset(53,27);ribbon.Size=UDim2.fromOffset(415,54);ribbon.BackgroundColor3=Color3.fromRGB(11,25,29);ribbon.BackgroundTransparency=.46;ribbon.BorderSizePixel=0;ribbon.ZIndex=0;ribbon.Parent=group
local round=Instance.new('UICorner');round.CornerRadius=UDim.new(1,0);round.Parent=ribbon
local fade=Instance.new('UIGradient');fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(.18,0),NumberSequenceKeypoint.new(.72,0),NumberSequenceKeypoint.new(1,1)});fade.Parent=ribbon
local leaves={}
for _,v in ipairs({{112,82,-28},{126,89,24},{430,81,30},{416,89,-24}})do
 local leaf=Instance.new('Frame');leaf.Name='CrestFlourish';leaf.Position=UDim2.fromOffset(v[1],v[2]);leaf.Size=UDim2.fromOffset(18,7);leaf.Rotation=v[3];leaf.BorderSizePixel=0;leaf.Parent=group
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(1,0);corner.Parent=leaf;leaves[#leaves+1]=leaf
end
local underline=Instance.new('Frame');underline.Name='CrestUnderline';underline.Position=UDim2.fromOffset(153,86);underline.Size=UDim2.fromOffset(246,2);underline.BorderSizePixel=0;underline.BackgroundTransparency=.3;underline.Parent=group
local taper=Instance.new('UIGradient');taper.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,0),NumberSequenceKeypoint.new(.8,0),NumberSequenceKeypoint.new(1,1)});taper.Parent=underline
local logos={};local names={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm'}
local function decorate(style,stage)
 for _,logo in pairs(logos)do logo.Visible=false end
 local kind=names[stage];if not kind then return end
 badge.BackgroundColor3=style.Color;edge.Color=style.Accent
 underline.BackgroundColor3=style.Accent;for _,leaf in ipairs(leaves)do leaf.BackgroundColor3=style.Accent end
 local logo=logos[stage]
 if not logo then logo=require(ReplicatedStorage.BiomeArtwork).Attach(badge,kind);logo.Name='BiomeLogo';logo.Size=UDim2.fromOffset(76,76);logo.Position=UDim2.fromOffset(2,2);logos[stage]=logo end
 logo.Visible=true;title.Visible=true
end
local gate = Gate.new()
local shownAt, poll = -100, 0
local dismissAt, dismissFrom
local IN, HOLD, OUT = .2, 2.2, .8 -- seconds: fade in, fully visible until HOLD, then fade away over OUT
-- Every transparency under the title, with its resting value; alpha 0 = resting, 1 = gone.
local fades, alphaNow = {}, 1
local function addFade(x)
    local function add(prop) fades[#fades+1] = {Item=x, Prop=prop, Base=x[prop]} end
    if x:IsA('GuiObject') then add('BackgroundTransparency') end
    if x:IsA('TextLabel') then add('TextTransparency'); add('TextStrokeTransparency')
    elseif x:IsA('ImageLabel') then add('ImageTransparency')
    elseif x:IsA('UIStroke') then add('Transparency') end
end
local function setAlpha(alpha)
    alphaNow = alpha
    for _, f in ipairs(fades) do
        local v = f.Base + (1 - f.Base) * alpha
        if f.Item[f.Prop] ~= v then f.Item[f.Prop] = v end
    end
end
local function captureFades()
    setAlpha(0); table.clear(fades) -- back to resting values before re-reading them
    for _, x in ipairs(group:GetDescendants()) do addFade(x) end
end
-- Artwork that finishes loading while the title shows joins the fade.
group.DescendantAdded:Connect(function(x) if group.Visible then local n = #fades; addFade(x); for i = n + 1, #fades do local f = fades[i]; f.Item[f.Prop] = f.Base + (1 - f.Base) * alphaNow end end end)
local function dismiss()
    if group.Visible and not dismissAt then
        dismissAt=os.clock();dismissFrom=alphaNow
    end
end
local function show(stage)
    local style = Styles[stage]
    if not style then dismiss(); return end
    title.Text = style.Name
    local measured=game:GetService('TextService'):GetTextSize(style.Name,36,Enum.Font.FredokaOne,Vector2.new(350,56)).X
    local textWidth=math.min(350,measured+12);local left=(490-(80+14+textWidth))/2
    badge.Position=UDim2.fromOffset(left,9);title.Size=UDim2.fromOffset(textWidth,56);title.Position=UDim2.fromOffset(left+94+textWidth/2,51)
    ribbon.Position=UDim2.fromOffset(left+26,27);ribbon.Size=UDim2.fromOffset(68+textWidth,54)
    underline.Position=UDim2.fromOffset(145,86);underline.Size=UDim2.fromOffset(200,2)
    for i,leaf in ipairs(leaves)do leaf.Position=UDim2.fromOffset(({110,124,366,352})[i],i%2==0 and 89 or 82)end
    decorate(style,stage)
    gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(.45,style.Accent),ColorSequenceKeypoint.new(1,style.Color)})
    shownAt = os.clock()
    dismissAt=nil;dismissFrom=nil
    captureFades()
    setAlpha(1)
    group.Visible = true
end
local spawnConnection = player.CharacterAdded:Connect(function()
    gate:Reset()
    poll = 0
    dismissAt=nil;dismissFrom=nil
    group.Visible = false
end)
local renderConnection
renderConnection = Run.RenderStepped:Connect(function(dt)
    if not gui.Parent then
        spawnConnection:Disconnect()
        renderConnection:Disconnect()
        return
    end
    poll += dt
    if poll >= .12 then
        local elapsed = poll
        poll = 0
        local character = player.Character
        local root = character and character:FindFirstChild('HumanoidRootPart')
        local humanoid = character and character:FindFirstChildOfClass('Humanoid')
        if not root or not humanoid or humanoid.Health <= 0 then
            gate:Reset()
            dismiss()
        else
            local position = root.Position
            local stage, startZ = 0, nil
            if math.abs(position.X) <= 90 and position.Y >= -10 and position.Y <= 150 then
                for id in pairs(Styles) do
                    local a, b = map:GetAttribute('BiomeStartZ_' .. id), map:GetAttribute('BiomeEndZ_' .. id)
                    if a and b and position.Z >= a and position.Z < b then
                        stage, startZ = id, a
                        break
                    end
                end
            end
            local announce, hide = gate:Step(position, stage, startZ,
                humanoid.MoveDirection.Z, elapsed, humanoid.WalkSpeed)
            if announce then show(stage) elseif hide then dismiss() end
        end
    end
    if not group.Visible then return end
    local now=os.clock();local age=now-shownAt
    -- Fade in, hold, fade away; turning back also fades without restarting the clock.
    local alpha
    if dismissAt then
        local progress=math.clamp((now-dismissAt)/.45,0,1)
        local eased=progress*progress*(3-2*progress)
        alpha=dismissFrom+(1-dismissFrom)*eased
    elseif age<IN then alpha=1-age/IN
    else
        local progress=math.clamp((age-HOLD)/OUT,0,1)
        alpha=progress*progress*(3-2*progress)
    end
    if alpha~=alphaNow then setAlpha(alpha) end
    if age>=HOLD+OUT or(dismissAt and now-dismissAt>=.45)then setAlpha(1);group.Visible=false;return end
    local camera = workspace.CurrentCamera
    local fit = group:GetAttribute('NoticeFit')or(camera and math.clamp((camera.ViewportSize.X - 24) / 490, .55, 1)or 1)
    local reduced=game:GetService('GuiService').ReducedMotionEnabled
    local progress=math.min(age/.35,1);local settle=1+2.2*(progress-1)^3+1.2*(progress-1)^2
    local away=reduced and 0 or math.clamp((age-HOLD)/OUT,0,1)*.06 -- shrinks a touch as it fades away
    scale.Scale=fit*(reduced and 1 or .9+.1*settle)*(1-away)
    badge.Rotation=reduced and 0 or(-5-9*math.exp(-age*9)*math.cos(age*12))
end)

gui.Destroying:Connect(function()spawnConnection:Disconnect();renderConnection:Disconnect()end)
