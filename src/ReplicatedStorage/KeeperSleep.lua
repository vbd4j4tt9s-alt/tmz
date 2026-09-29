-- V109 FIX1: shared stock snore only; sleeping clouds were removed by request.
-- Client presentation only; BeastAnimation owns lifecycle and behavior state.
local Content = game:GetService('ContentProvider')
local Sleep = {}
Sleep.__index = Sleep
Sleep.SoundId = 'rbxassetid://9113862735'
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
    local bounds = assert(config.Bounds.Head, 'Keeper head bounds required')
    local low, high = bounds[1], bounds[2]
    return setmetatable({Muted = _stage==1, Root = root, Attachment = attachment, Sound = sound, Playing = false,
        HeadPoint = Vector3.new((low[1] + high[1]) / 2, high[2] + 2, (low[3] + high[3]) / 2)}, Sleep)
end
-- Keep the existing BeastAnimation call signature; no second update owner.
function Sleep:Update(asleep, distance, _now, headFrame)
    if self.Destroyed then return end
    local nearby = asleep and distance < 65
    if nearby then
        self.Attachment.Position = self.Root.CFrame:PointToObjectSpace(headFrame * self.HeadPoint)
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
