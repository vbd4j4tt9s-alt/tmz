-- SoundGroup gain sits above existing fades; volume changes never restart a track.
local SoundService=game:GetService('SoundService');local Players=game:GetService('Players')
local Config=require(script.Parent.SettingsConfig);local M={};local values=Config.Read();local groups={};local started=false
local names={Music='ChestChaseMusic',Chase='ChestChaseActionMusic',Ambience='GardenAmbience',Effects='GardenEffects',Interface='GardenInterface'}
function M.Group(key)
 if not names[key]then return nil end
 local group=groups[key]or SoundService:FindFirstChild(names[key])
 if not group or not group:IsA('SoundGroup')then group=Instance.new('SoundGroup');group.Name=names[key];group.Parent=SoundService end
 group.Volume=values[key]/100;groups[key]=group;return group
end
function M.Set(key,value)if not Config.Valid(key,value)then return false end;values[key]=value;if names[key]then M.Group(key).Volume=value/100 end;return true end
function M.Get(key)return values[key]end
function M.Route(sound,key)
 if not Players.LocalPlayer or not sound:IsA('Sound')then return end
 if not key then
  if sound.Name:match('^Interaction_')then key='Interface'
  elseif sound.Name=='BiomeScenicMusic'or sound.Name=='ChestChaseBackgroundMusic'then key='Music'
  elseif sound.Name=='ChestChaseActionTrack'then key='Chase'
  elseif sound.Name=='BiomeForestBirds'then key='Ambience'
  elseif sound.SoundGroup then return else key='Effects'end
 end
 sound.SoundGroup=M.Group(key)
end
function M.Start()
 if started or not Players.LocalPlayer then return end;started=true
 for key in pairs(names)do M.Group(key)end
 for _,sound in ipairs(SoundService:GetDescendants())do M.Route(sound)end
 SoundService.DescendantAdded:Connect(function(sound)M.Route(sound)end)
 -- Class check only: no map traversal, distance polling or per-frame sound search.
 workspace.DescendantAdded:Connect(function(sound)M.Route(sound)end)
end
return M
