do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R73: quiet biome beds on the Ambience slider, independent of background/chase music.
local Players=game:GetService('Players');local SoundService=game:GetService('SoundService');local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage');local Content=game:GetService('ContentProvider')
local Mood=require(RS:WaitForChild('BiomeMood'));local Mixer=require(RS.AudioMixer);local player=Players.LocalPlayer
local voices={};local preload={};local dead=false;local alive=true;local stage=0;local elapsed=0;local age=0
-- R100: BackgroundMusic owns the restored scenic score. Keep every biome bed
-- independent on Ambience, without deleting or muting the Music controller's sound.
SoundService:SetAttribute('BiomeAmbientActive',false)
for _,row in ipairs(Mood.Audio)do
 local oldVoice=SoundService:FindFirstChild(row.Name);if oldVoice then oldVoice:Destroy()end
 local id=Mood.AudioId(row)
 if id then
  local sound=Instance.new('Sound');sound.Name=row.Name;sound.SoundId=id;sound.Looped=true;sound.Volume=0
  sound.SoundGroup=Mixer.Group('Ambience');sound.Parent=SoundService
  voices[#voices+1]={Sound=sound,Key=row.Key};preload[#preload+1]=sound
 end
end
-- One request; unavailable assets stay silent and never hold up rendering or gameplay.
local loader=task.spawn(function()pcall(function()Content:PreloadAsync(preload)end)end)
local function update(dt)
 if dead then return end;age+=dt
 local map=workspace:FindFirstChild('ChestChaseMap');local character=alive and player.Character
 local root=character and character:FindFirstChild('HumanoidRootPart');local hum=character and character:FindFirstChildOfClass('Humanoid')
 local playing=map and root and hum and hum.Health>0 or false
 stage=Mood.Stage(map,playing and root.Position or nil,stage)
 local targets=Mood.SoundTargets(stage,RS:GetAttribute('GlobalWeather')or'Clear',map and map:GetAttribute('BiomesRefreshing')==true,player:GetAttribute('ChestChaseRunActive')==true,playing)
 local alpha=1-math.exp(-math.min(dt,.2)*(player:GetAttribute('ChestChaseRunActive')and 8 or 2.4))
 for _,entry in ipairs(voices)do
  local sound=entry.Sound;local ready=sound.IsLoaded;local target=ready and Mixer.Get('Ambience')>0 and targets[entry.Key]or 0
  if not ready and not entry.Warned and age>=12 then entry.Warned=true;warn('[R73] '..sound.Name..' unavailable; check its experience audio permissions. Other audio continues.')end
  if target>0 and not sound.IsPlaying then if sound.IsPaused then sound:Resume()else sound:Play()end end
  local value=sound.Volume+(target-sound.Volume)*alpha;if math.abs(value-target)<.0005 then value=target end
  if value~=sound.Volume then sound.Volume=value end
  if value==0 and sound.IsPlaying then sound:Pause()end
 end
end
local connections={Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed<.1 then return end;local step=elapsed;elapsed=0;update(step)end)}
connections[#connections+1]=player.CharacterRemoving:Connect(function()alive=false;update(.1)end)
connections[#connections+1]=player.CharacterAdded:Connect(function()alive=true;stage=0;update(.1)end)
script.Destroying:Connect(function()
 if dead then return end;dead=true
 for _,c in ipairs(connections)do c:Disconnect()end
 if loader then pcall(task.cancel,loader)end
 for _,entry in ipairs(voices)do entry.Sound:Destroy()end
 table.clear(voices);table.clear(preload)
end)
