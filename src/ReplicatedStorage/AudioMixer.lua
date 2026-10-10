-- SoundGroup gain sits above existing fades; volume changes never restart a track.
local SoundService=game:GetService('SoundService');local Players=game:GetService('Players')
local Config=require(script.Parent:WaitForChild('SettingsConfig'));local M={};local values=Config.Read();local groups={};local started=false -- R157b fix: WaitForChild (this module can be required before SettingsConfig has replicated, e.g. by InteractionAudio from the title)
local names={Music='ChestChaseMusic',Chase='ChestChaseActionMusic',Ambience='GardenAmbience',Effects='GardenEffects',Interface='GardenInterface'}
-- R150: the saved mix as early as it can be known. PlayerDataService publishes it on the Player as number attributes the moment the profile is
-- read (replicated, no remote to wait for); the groups take those values as soon as they exist, and keep following them until the player
-- (or SettingsState) sets that group, so a saved Music / Effects = 0 is not heard at 100% while SettingsState is still on its way.
M.Attributes=Config.AudioAttributes
local decided={};local wired=false
local function adopt(key)
 if decided[key]then return end
 local player=Players.LocalPlayer;if not player then return end
 local value=player:GetAttribute(M.Attributes[key])
 if not Config.Valid(key,value)then return end
 values[key]=value
 if groups[key]then groups[key].Volume=value/100 end
end
local function wire()
 if wired then return end
 local player=Players.LocalPlayer;if not player then return end
 wired=true
 for key,attribute in pairs(M.Attributes)do
  adopt(key)
  player:GetAttributeChangedSignal(attribute):Connect(function()adopt(key)end)
 end
end
wire()
function M.Group(key)
 if not names[key]then return nil end
 wire()
 local group=groups[key]or SoundService:FindFirstChild(names[key])
 if not group or not group:IsA('SoundGroup')then group=Instance.new('SoundGroup');group.Name=names[key];group.Parent=SoundService end
 group.Volume=values[key]/100;groups[key]=group;return group
end
function M.Set(key,value)if not Config.Valid(key,value)then return false end;values[key]=value;decided[key]=true;if names[key]then M.Group(key).Volume=value/100 end;return true end
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
 wire()
 for key in pairs(names)do M.Group(key)end
 for _,sound in ipairs(SoundService:GetDescendants())do M.Route(sound)end
 SoundService.DescendantAdded:Connect(function(sound)M.Route(sound)end)
 -- Class check only: no map traversal, distance polling or per-frame sound search.
 workspace.DescendantAdded:Connect(function(sound)M.Route(sound)end)
 -- R150: characters that already exist when this starts (yours and everyone else's) were never routed: their default jump / land / splash
 -- sounds ignored the Effects slider, including 0. Only the characters are walked, never the map.
 for _,other in ipairs(Players:GetPlayers())do
  local character=other.Character
  if character then for _,item in ipairs(character:GetDescendants())do M.Route(item)end end
 end
end
return M
