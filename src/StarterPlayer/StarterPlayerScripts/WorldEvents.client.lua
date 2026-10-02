-- Compact rare-spawn announcements and client-only precipitation; gameplay lives on the server.
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
local Fx=require(RS.ClientFxBudget);local Presentation=require(RS.WeatherPresentation);local Lightning=require(RS.WeatherLightning)
local mobile=game:GetService('UserInputService').TouchEnabled
local Timing=require(RS.SoundTiming)
local folder=Instance.new('Folder');folder.Name='_GlobalWeatherR59';folder.Parent=workspace
local anchor=Instance.new('Part');anchor.Size=Vector3.new(86,.1,78);anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false;anchor.Parent=folder
local Field=require(RS:WaitForChild('AmbientParticleField128'));local field=Field.new() -- R128: rain/snow live in the world
local emitter=Instance.new('ParticleEmitter');emitter.Name='Precipitation';emitter.VelocityInheritance=0;emitter.Texture='rbxasset://textures/particles/sparkles_main.dds';emitter.Enabled=false;emitter.Rate=0;emitter.EmissionDirection=Enum.NormalId.Bottom;emitter.LightInfluence=.2;emitter.SpreadAngle=Vector2.new(12,12);emitter.VelocityInheritance=0;emitter.Parent=anchor
-- R73: the shared biome lighting controller blends weather colour; only lightning flashes live here.
local flash=Instance.new('ColorCorrectionEffect');flash.Name='DistantThunderGlow';flash.Enabled=false;flash.Parent=Lighting
local thunder=Instance.new('Sound');thunder.Name='DistantThunder';thunder.SoundId=require(RS.StormConfig).ThunderId;thunder.Volume=.22;thunder.PlaybackSpeed=.9;thunder.Parent=folder
-- R123: load the thunder before the first storm so it lands on the first bolt's flash instead of after it.
task.spawn(function()pcall(function()game:GetService('ContentProvider'):PreloadAsync({thunder})end)end)
local Notice=require(RS.WorldNoticeTiming)
local bolt=Lightning.New(folder);local profile;local profileTier;local nextBolt=0;local lastPosition;local lastCamera
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
local Clouds={Level=0,Kind='Rain'}
Clouds.Targets={Rain={Cover=.86,Density=.82,Color=Color3.fromRGB(92,98,112)},Thunderstorm={Cover=.92,Density=.92,Color=Color3.fromRGB(60,64,78)},
 Blizzard={Cover=.88,Density=.75,Color=Color3.fromRGB(186,194,206)}}
function Clouds.Step(kind,dt)
 local target=kind and 1 or 0;if kind then Clouds.Kind=kind end
 Clouds.Level=Clouds.Level+(target-Clouds.Level)*(1-math.exp(-(dt or 0)*1.5))
 if math.abs(Clouds.Level-target)<.01 then Clouds.Level=target end
 local terrain=workspace:FindFirstChildOfClass('Terrain');if not terrain then return end
 local c=Clouds.Object
 if Clouds.Level>0 and(not c or not c.Parent)then
  c=terrain:FindFirstChildOfClass('Clouds')
  if c then Clouds.Saved={Cover=c.Cover,Density=c.Density,Color=c.Color};Clouds.Made=false
  else c=Instance.new('Clouds');c.Name='WeatherClouds';Clouds.Saved={Cover=0,Density=0,Color=Color3.fromRGB(255,255,255)};c.Cover=0;c.Density=0;c.Parent=terrain;Clouds.Made=true end
  Clouds.Object=c
 end
 if not c or not Clouds.Saved then return end
 local base,goal,k=Clouds.Saved,Clouds.Targets[Clouds.Kind]or Clouds.Targets.Rain,Clouds.Level
 if k<=0 then
  if Clouds.Made then c:Destroy()else c.Cover=base.Cover;c.Density=base.Density;c.Color=base.Color end
  Clouds.Object=nil;Clouds.Saved=nil;return
 end
 c.Cover=base.Cover+(math.max(base.Cover,goal.Cover)-base.Cover)*k;c.Density=base.Density+(math.max(base.Density,goal.Density)-base.Density)*k
 c.Color=base.Color:Lerp(goal.Color,k)
end
local function weather(kind)
 emitter:Clear();emitter.Enabled=false;flash.Enabled=false
 if kind=='Clear'then return end
 local snow=kind=='Blizzard'
 emitter.Color=ColorSequence.new(snow and Color3.fromRGB(238,250,255)or Color3.fromRGB(171,212,246))
 emitter.Squash=NumberSequence.new(snow and 0 or -.88)
 emitter.Orientation=snow and Enum.ParticleOrientation.FacingCamera or Enum.ParticleOrientation.VelocityParallel
 emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,.18),NumberSequenceKeypoint.new(.8,.24),NumberSequenceKeypoint.new(1,1)})
 emitter.LightEmission=snow and .24 or .13;emitter.LockedToPart=false
 emitter.Rotation=NumberRange.new(0,snow and 360 or 0);emitter.RotSpeed=NumberRange.new(snow and -40 or 0,snow and 40 or 0)
 emitter.Acceleration=snow and Vector3.new(10,-4,3)or Vector3.new(5,-18,0)
 profileTier=nil
 local name=Notice.WeatherName(kind)
 if name then deliver('Plain',name,W.Traits[W.Events[kind]].Color,Notice.WeatherDuration)end
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
 Clouds.Step(here and Lighting:GetAttribute('TrackRefreshActive')~=true and kind or nil,step)
 -- On the track: no rain, snow or lightning (drops already falling simply finish).
 if not camera or not here then if emitter.Enabled then emitter.Enabled=false end;clearStrike();return end
 if profileTier~=tier then
  profile=Presentation.Profile(kind,tier,mobile);profileTier=tier
  anchor.Size=Vector3.new(profile.Width,.1,profile.Depth)
  emitter.Rate=profile.Rate;emitter.Size=NumberSequence.new(profile.Size)
  emitter.Lifetime=NumberRange.new(profile.Life*.8,profile.Life);emitter.Speed=NumberRange.new(profile.Speed*.85,profile.Speed*1.15)
 end
 local p=camera.CFrame.Position
 if camera~=lastCamera or(lastPosition and(p-lastPosition).Magnitude>150)then emitter:Clear();clock=.5;Field.Reset(field)end -- R128: teleports only, not fast running
 lastCamera=camera;lastPosition=p
 local look=camera.CFrame.LookVector;local forward=Vector3.new(look.X,0,look.Z)
 forward=forward.Magnitude>.01 and forward.Unit or Vector3.new(0,0,-1)
 if not emitter.Enabled then emitter.Enabled=true end
 if kind=='Thunderstorm'then
  if now>=nextBolt then
   lastBolt=now;nextBolt=now+(low and 12 or 8.5)
   local far=p+forward*125
   bolt:Strike(far+Vector3.new(0,100,0),far-Vector3.new(0,10,0),now,low,Gui.ReducedMotionEnabled)
   Timing.Play(thunder)
  end
  local enabled=bolt:Step(now);if flash.Enabled~=enabled then flash.Enabled=enabled end
  if flash.Brightness~=.095 then flash.Brightness=.095 end
 else clearStrike()end

end)
-- R128: the precipitation birth box follows the camera every frame, led ahead of a runner by the fall time.
local follow=Run.RenderStepped:Connect(function(dt)
 local camera=workspace.CurrentCamera
 if not camera or not profile or not emitter.Enabled then return end
 local velocity=Field.Track(field,camera.CFrame.Position,dt)
 local lead,maxLead=Field.Lead(profile.Height,profile.Speed,true)
 local target=Field.Target(camera.CFrame,7,profile.Height,velocity,lead,maxLead)
 if (anchor.Position-target).Magnitude>.05 then anchor.CFrame=CFrame.new(target)end
end)
local typography=require(RS.GardenTypography).Apply(pg)
script.Destroying:Connect(function()typography:Disconnect();tick:Disconnect();follow:Disconnect();Clouds.Level=0;Clouds.Step(nil,0);bolt:Destroy();folder:Destroy();flash:Destroy()end)
