-- V109 FIX1: shared stock snore only; sleeping clouds were removed by request.
-- Client presentation only; BeastAnimation owns lifecycle and behavior state.
local Content = game:GetService('ContentProvider')
local Sleep = {}
Sleep.__index = Sleep
Sleep.SoundId = 'rbxassetid://9113862735'
-- R113: three small drifting "z" letters over a sleeping beast (not the Golem: it sleeps disguised as a tree).
-- Text only (no cloud art); shown within ZzzDistance, hidden in low graphics. Set ShowZzz=false to remove.
Sleep.ShowZzz = true
Sleep.ZzzDistance = 55
local function zzz(attachment, stage)
    local gui = Instance.new('BillboardGui')
    gui.Name = 'KeeperZzzLocal'; gui.Size = UDim2.fromScale(4, 5); gui.StudsOffset = Vector3.new(1.2, 1.5, 0)
    gui.LightInfluence = 0; gui.AlwaysOnTop = false; gui.MaxDistance = Sleep.ZzzDistance; gui.Enabled = false
    local labels = {}
    for i = 1, 3 do
        local label = Instance.new('TextLabel')
        label.Name = 'Z' .. i; label.BackgroundTransparency = 1; label.AnchorPoint = Vector2.new(.5, .5)
        label.Size = UDim2.fromScale(.5, .3); label.Font = Enum.Font.FredokaOne; label.TextScaled = true
        label.Text = i == 3 and 'Z' or 'z'; label.TextColor3 = Color3.fromRGB(236, 242, 255)
        label.TextStrokeTransparency = .55; label.TextTransparency = 1; label.Parent = gui
        labels[i] = label
    end
    gui.Parent = attachment
    return gui, labels
end
-- R152: the baked rev 6 keepers (a config with Z: KeeperRigConfig152) get the new sleep marker instead: one big stylised cyan "Z" with a
-- dark outline and a small "z" up beside it, where the R151 sheets draw it (Z.Point, Head rest space; Z.Height studs). It bobs and breathes.
Sleep.ZColor = Color3.fromRGB(77, 217, 255); Sleep.ZEdge = Color3.fromRGB(13, 56, 140)
local function bigZ(attachment, height)
    local gui = Instance.new('BillboardGui')
    gui.Name = 'KeeperZzzLocal'; gui.Size = UDim2.fromScale(height * 1.15, height * 1.15); gui.LightInfluence = 0
    gui.AlwaysOnTop = false; gui.MaxDistance = Sleep.ZzzDistance; gui.Enabled = false
    local labels = {}
    for i, spec in ipairs({{'Z', .30, .62, .62}, {'z', .80, .22, .36}}) do
        local label = Instance.new('TextLabel')
        label.Name = 'Z' .. i; label.BackgroundTransparency = 1; label.AnchorPoint = Vector2.new(.5, .5)
        label.Position = UDim2.fromScale(spec[2], spec[3]); label.Size = UDim2.fromScale(spec[4], spec[4])
        label.Font = Enum.Font.FredokaOne; label.TextScaled = true; label.Text = spec[1]
        label.TextColor3 = Sleep.ZColor; label.TextStrokeColor3 = Sleep.ZEdge; label.TextStrokeTransparency = 0
        local stroke = Instance.new('UIStroke'); stroke.Color = Sleep.ZEdge; stroke.Thickness = 3; stroke.Parent = label
        label.Parent = gui; labels[i] = label
    end
    gui.Parent = attachment
    return gui, labels
end
local audioState = 'cold'
local function preload()
    if audioState ~= 'cold' then return end
    audioState = 'loading'
    local probe = Instance.new('Sound')
    probe.SoundId = Sleep.SoundId
    task.spawn(function()
        local fetched = false
        local ok = pcall(function()
            Content:PreloadAsync({probe}, function(_, status)
                if status == Enum.AssetFetchStatus.Success then fetched = true end
            end)
        end)
        if audioState == 'loading' then
            audioState = ok and (fetched or probe.IsLoaded) and 'ready' or 'unavailable'
            if audioState == 'unavailable' then warn('[V109] Shared sleep sound could not load; sleeping audio remains silent.') end
        end
        probe:Destroy()
    end)
    task.delay(12, function()
        if audioState == 'loading' then
            audioState = 'unavailable'
            probe:Destroy()
            warn('[V109] Sleep audio loading timed out; sleeping audio remains silent.')
        end
    end)
end
function Sleep.new(root, _stage, config)
    if _stage~=1 then preload()end
    local attachment = Instance.new('Attachment')
    attachment.Name = 'KeeperSleepLocal'; attachment.Parent = root
    local sound = Instance.new('Sound')
    sound.Name = 'KeeperSnoreLocal'; sound.SoundId = Sleep.SoundId
    sound.Volume = .16; sound.PlaybackSpeed = 1; sound.Looped = true
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 8; sound.RollOffMaxDistance = 65; sound.Parent = attachment
    -- R150: routed to Effects here (not left to whenever AudioMixer.Start happens to run), so the Effects slider, including 0, always covers the snore.
    pcall(function() require(script.Parent.AudioMixer).Route(sound, 'Effects') end)
    local bounds = assert(config.Bounds.Head, 'Keeper head bounds required')
    local low, high = bounds[1], bounds[2]
    local gui, labels
    local z = _stage ~= 1 and config.Z
    if z then gui, labels = bigZ(attachment, z.Height)
    elseif _stage ~= 1 then gui, labels = zzz(attachment, _stage) end
    return setmetatable({Muted = _stage==1, Root = root, Attachment = attachment, Sound = sound, Playing = false, Zzz = gui, Labels = labels, Big = z and true or nil, Faded = {},
        HeadPoint = z and Vector3.new(z.Point[1], z.Point[2], z.Point[3]) or Vector3.new((low[1] + high[1]) / 2, high[2] + 2, (low[3] + high[3]) / 2)}, Sleep)
end
-- Keep the existing BeastAnimation call signature; no second update owner.
function Sleep:Update(asleep, distance, _now, headFrame, low)
    if self.Destroyed then return end
    local nearby = asleep and distance < 65
    if nearby then
        self.Attachment.Position = self.Root.CFrame:PointToObjectSpace(headFrame * self.HeadPoint)
    end
    if self.Zzz then
        local show = Sleep.ShowZzz and nearby and distance < Sleep.ZzzDistance and not low
        if self.Zzz.Enabled ~= show then self.Zzz.Enabled = show end
        if show and self.Big then
            local t = os.clock()
            for i, label in ipairs(self.Labels) do
                local w = t * 1.6 + i * 1.3
                local s = (i == 1 and .62 or .36) * (1 + .06 * math.sin(w))
                label.Size = UDim2.fromScale(s, s)
                label.Position = UDim2.fromScale(i == 1 and .30 or .80, (i == 1 and .62 or .22) + .04 * math.sin(w * .7))
                label.TextTransparency = .08 + .1 * (1 + math.sin(w)) / 2
            end
        elseif show then
            local t = os.clock()
            for i, label in ipairs(self.Labels) do
                local u = (t * .38 + (i - 1) / 3) % 1
                label.Position = UDim2.fromScale(.3 + u * .4 + math.sin(u * 6.28) * .08, .9 - u * .8)
                label.Size = UDim2.fromScale(.25 + u * .3, .16 + u * .18)
                local fade = u < .2 and 1 - u / .2 * .75 or .25 + .75 * math.max(0, (u - .6) / .4)
                -- (R152 perf: the fade holds still for part of each drift: written when it changes, against what this wrote)
                local stroke = math.max(.55, fade); local was = self.Faded[i]
                if not was then was = {}; self.Faded[i] = was end
                if was[1] ~= fade then was[1] = fade; label.TextTransparency = fade end
                if was[2] ~= stroke then was[2] = stroke; label.TextStrokeTransparency = stroke end
            end
        end
    end
    local audible = not self.Muted and nearby and audioState == 'ready'
    if audible and not self.Playing then self.Sound:Play(); self.Playing = true
    elseif not audible and self.Playing then self.Sound:Stop(); self.Playing = false end
end
function Sleep:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true; self.Sound:Stop(); self.Attachment:Destroy()
end
return Sleep
