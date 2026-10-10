do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- Compact rare-spawn announcements, weather notices, dark clouds and thunder; gameplay lives on the server.
-- R149 (owner): the rain / snow itself moved to WeatherWorld149.client.lua (world-anchored tiles, splashes, snow patches); the old
-- camera-following precipitation box that starved the view whenever the camera moved is gone from here.
local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players');local Run=game:GetService('RunService');local Lighting=game:GetService('Lighting');local Gui=game:GetService('GuiService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui')
-- R99: countdowns must not wait for notification remotes, asset loads or notice setup.
local statusHud=require(RS.WorldStatusHud).Create(pg,player)
local alive=true;local Feed;local warned={};local noticeFolder;local folderConnections={};local remoteConnections={};local noticeWatches={}
local noticeMethods={RarePackSpawn='Pack',WeatherAdopted='Weather'}
local function noticeWarning(method,reason)
 if warned[method]then return end;warned[method]=true
 warn('[WorldEvents] '..method..' notification unavailable: '..tostring(reason))
end
local function deliver(method,...)
 if not alive or not Feed then return end
 local okay,reason=pcall(Feed[method],...)
 if not okay then noticeWarning(method,reason)end
end
local function disconnectRemotes()
 for key,entry in pairs(remoteConnections)do entry.Connection:Disconnect();remoteConnections[key]=nil end
end
local function bindRemote(name)
 local remote=noticeFolder and noticeFolder:FindFirstChild(name);local entry=remoteConnections[name]
 if entry and entry.Remote==remote then return end
 if entry then entry.Connection:Disconnect();remoteConnections[name]=nil end
 if not remote then return end
 if not remote:IsA('RemoteEvent')then noticeWarning(name,'expected RemoteEvent');return end
 remoteConnections[name]={Remote=remote,Connection=remote.OnClientEvent:Connect(function(payload)deliver(noticeMethods[name],payload)end)}
end
local function bindFolder()
 if not alive then return end
 local folder=RS:FindFirstChild('ChestChaseRemotes')
 if folder==noticeFolder then return end
 for _,connection in ipairs(folderConnections)do connection:Disconnect()end;table.clear(folderConnections);disconnectRemotes();noticeFolder=folder
 if not folder then return end
 folderConnections[1]=folder.ChildAdded:Connect(function(child)if noticeMethods[child.Name]then bindRemote(child.Name)end end)
 folderConnections[2]=folder.ChildRemoved:Connect(function(child)if noticeMethods[child.Name]then bindRemote(child.Name)end end)
 for name in pairs(noticeMethods)do bindRemote(name)end
end
script.Destroying:Connect(function()
 if not alive then return end;alive=false;statusHud.Destroy()
 disconnectRemotes();for _,connection in ipairs(folderConnections)do connection:Disconnect()end
 for _,connection in ipairs(noticeWatches)do connection:Disconnect()end
end)
task.defer(function()
 if not alive then return end
 local okay,value=pcall(function()return require(RS.NoticeFeed83)end)
 if not alive then return end
 if not okay then noticeWarning('initialization',value);return end
 Feed=value
 noticeWatches[1]=RS.ChildAdded:Connect(function(child)if child.Name=='ChestChaseRemotes'then bindFolder()end end)
 noticeWatches[2]=RS.ChildRemoved:Connect(function(child)if child.Name=='ChestChaseRemotes'then bindFolder()end end)
 bindFolder()
 -- Preload errors are reported separately; they cannot prevent timers or remote binding.
 deliver('Preload')
end)
local W=require(RS.WeatherTraits)
local previousKind='Clear'
local Fx=require(RS.ClientFxBudget);local Lightning=require(RS.WeatherLightning);local World=require(RS.WeatherWorld149)
local Timing=require(RS.SoundTiming)
local folder=Instance.new('Folder');folder.Name='_GlobalWeatherR59';folder.Parent=workspace
-- R73: the shared biome lighting controller blends weather colour; only lightning flashes live here.
local flash=Instance.new('ColorCorrectionEffect');flash.Name='DistantThunderGlow';flash.Enabled=false;flash.Parent=Lighting
local thunder=Instance.new('Sound');thunder.Name='DistantThunder';thunder.SoundId=require(RS.StormConfig).ThunderId;thunder.Volume=.22;thunder.PlaybackSpeed=.9;thunder.Parent=folder
-- R123: load the thunder before the first storm so it lands on the first bolt's flash instead of after it.
task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync({thunder})end)end)
local Notice=require(RS.WorldNoticeTiming)
local bolt=Lightning.New(folder);local nextBolt=0
local clock=0;local updateClock=0;local noticeClock=0;local lastBolt=-100
-- R129 (owner): weather belongs to the base area. There the rain / snow is real (world-space, and the old camera
-- "roof" check that switched it off whenever the camera passed under something is gone) and the clouds turn dark;
-- on the track there is no weather effect at all (the biome's own effects show instead).
local Mood=require(RS.BiomeMood)
local function inBase()
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local map=workspace:FindFirstChild('ChestChaseMap')
 if not root or not map then return true end
 return Mood.Stage(map,root.Position,0)==0
end
-- Dark clouds: the place's own Terrain clouds are thickened and darkened while it rains / snows in the base (only
-- Cover, Density and Color are touched; Enabled stays with RefreshSky). Without a cloud layer one is added for the
-- weather and removed after. Values ease in and out and are restored exactly.
-- R151: the Cloudy sky (WeatherCycle151, the other default weather) thickens and greys the same layer: Clouds.Step(kind, dt, ambient) with ambient =
-- its level 0..1 (the caller passes 0 in event weather, on the track and during a track refresh). The storm blends over the Cloudy layer by its own
-- Level, so an event starting or ending while it is cloudy crosses smoothly; with ambient 0 every value is exactly what it was before R151.
local Clouds={Level=0,Kind='Rain',Ambient=0}
Clouds.Targets={Rain={Cover=.86,Density=.82,Color=Color3.fromRGB(92,98,112)},Thunderstorm={Cover=.92,Density=.92,Color=Color3.fromRGB(60,64,78)},
 Blizzard={Cover=.88,Density=.75,Color=Color3.fromRGB(186,194,206)}}
function Clouds.Step(kind,dt,ambient)
 ambient=ambient or 0;Clouds.Ambient=ambient
 local target=kind and 1 or 0;if kind then Clouds.Kind=kind end
 Clouds.Level=Clouds.Level+(target-Clouds.Level)*(1-math.exp(-(dt or 0)*1.5))
 if math.abs(Clouds.Level-target)<.01 then Clouds.Level=target end
 local terrain=workspace:FindFirstChildOfClass('Terrain');if not terrain then return end
 local c=Clouds.Object
 if(Clouds.Level>0 or ambient>0)and(not c or not c.Parent)then
  c=terrain:FindFirstChildOfClass('Clouds')
  if c then Clouds.Saved={Cover=c.Cover,Density=c.Density,Color=c.Color};Clouds.Made=false
  else c=Instance.new('Clouds');c.Name='WeatherClouds';Clouds.Saved={Cover=0,Density=0,Color=Color3.fromRGB(255,255,255)};c.Cover=0;c.Density=0;c.Parent=terrain;Clouds.Made=true end
  Clouds.Object=c
 end
 if not c or not Clouds.Saved then return end
 local base,goal,k=Clouds.Saved,Clouds.Targets[Clouds.Kind]or Clouds.Targets.Rain,Clouds.Level
 if k<=0 and ambient<=0 then
  if Clouds.Made then c:Destroy()else c.Cover=base.Cover;c.Density=base.Density;c.Color=base.Color end
  Clouds.Object=nil;Clouds.Saved=nil;return
 end
 local cover,density,color=base.Cover,base.Density,base.Color
 if ambient>0 then
  local look=Mood.CloudyLook.Clouds
  cover=base.Cover+(math.max(base.Cover,look.Cover)-base.Cover)*ambient;density=base.Density+(math.max(base.Density,look.Density)-base.Density)*ambient
  color=base.Color:Lerp(look.Color,ambient)
 end
 if k>0 then
  cover=cover+(math.max(base.Cover,goal.Cover)-cover)*k;density=density+(math.max(base.Density,goal.Density)-density)*k
  color=color:Lerp(goal.Color,k)
 end
 c.Cover=cover;c.Density=density;c.Color=color
end
-- R151: is the player in the base? (the Cloudy sky only dims the base; asked at most four times a second)
local baseCheck={Age=1,Value=true}
local function inBaseCached(dt)
 baseCheck.Age+=dt;if baseCheck.Age>=.25 then baseCheck.Age=0;baseCheck.Value=inBase()end
 return baseCheck.Value
end
local okCycle,Cycle=pcall(function()return require(RS.WeatherCycle151)end);if not okCycle then Cycle=nil end
local function weather(kind)
 flash.Enabled=false
 if kind=='Clear'then return end
 local name=Notice.WeatherName(kind)
 if name then deliver('Plain',name,W.Traits[W.Events[kind]].Color,Notice.WeatherDuration)end
end
-- R149: a bolt is a place in the world, not "125 studs in front of the camera". Its direction and distance come from the strike's time
-- slot (so turning the camera never decides where it lands), and it must land in the base: nothing on the track.
local function strikePoint(now,from)
 local map=workspace:FindFirstChild('ChestChaseMap');local slot=math.floor(now*10)
 local start=World.Unit(slot,0,77)*math.pi*2;local distance=95+World.Unit(slot,1,78)*70
 for attempt=0,5 do
  local angle=start+attempt*1.0472
  local point=from+Vector3.new(math.cos(angle)*distance,0,math.sin(angle)*distance)
  if not map or Mood.Stage(map,point,0)==0 then return point end
 end
 return nil
end
local function clearStrike()bolt:Clear();flash.Enabled=false end
local tick=Run.Heartbeat:Connect(function(dt)
 updateClock+=dt;local tier=Fx.Get();local low=tier==1;if updateClock<(low and .1 or .05)then return end
 local step=updateClock;updateClock=0
 local camera=workspace.CurrentCamera;local now=workspace:GetServerTimeNow();clock+=step;noticeClock+=step
 local kind=RS:GetAttribute('GlobalWeather')or'Clear'
 if kind~=previousKind then weather(kind);previousKind=kind end
 local here=kind~='Clear'and inBase()
 -- R130: no weather clouds during a track refresh (the refresh sky is dark and cloudless).
 local refreshing=Lighting:GetAttribute('TrackRefreshActive')==true
 -- R151: the Cloudy sky's clouds: only in the base, never in event weather, a track refresh or a rare-pull story scene.
 local ambient=0
 if Cycle and kind=='Clear'and not refreshing then
  local level=Cycle.Read(RS,now)
  if level>0 and inBaseCached(step)then ambient=Cycle.Effective(level,0,kind,player:GetAttribute('RarePullCinematic'))end
 end
 Clouds.Step(here and not refreshing and kind or nil,step,ambient)
 -- On the track: no weather clouds, no lightning (the rain / snow tiles are WeatherWorld149's; drops already falling simply finish).
 if not camera or not here then clearStrike();return end
 local character=player.Character;local root=character and character:FindFirstChild('HumanoidRootPart')
 local p=root and root.Position or camera.CFrame.Position
 if kind=='Thunderstorm'then
  if now>=nextBolt then
   lastBolt=now;nextBolt=now+(low and 12 or 8.5)
   local far=strikePoint(now,p)
   if far then bolt:Strike(far+Vector3.new(0,100,0),far-Vector3.new(0,10,0),now,low,Gui.ReducedMotionEnabled)end
   Timing.Play(thunder)
  end
  local enabled=bolt:Step(now);if flash.Enabled~=enabled then flash.Enabled=enabled end
  if flash.Brightness~=.095 then flash.Brightness=.095 end
 else clearStrike()end

end)
local typography=require(RS.GardenTypography).Apply(pg)
script.Destroying:Connect(function()typography:Disconnect();tick:Disconnect();Clouds.Level=0;Clouds.Step(nil,0);bolt:Destroy();folder:Destroy();flash:Destroy()end)
