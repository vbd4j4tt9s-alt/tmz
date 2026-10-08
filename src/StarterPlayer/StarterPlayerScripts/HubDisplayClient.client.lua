do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R151 (owner: BEST PULL TODAY and BIGGEST FRUIT TODAY in the hub's two empty corners): the part each player runs on their own screen. The server (HubDisplayService /
-- HubDisplayArt) builds everything that is still: the pedestal, the words, the showcase item and the champion's avatar. This adds what moves, and only while it is near and nothing
-- is switched off:
--   * the "New board in 5h 12m" countdown (R153: the Footer row of the big label over the item: the display's NextAt attribute is the server time of the next UTC midnight; kept up to
--     date for every display that has streamed in, every 5 s, a couple of text writes)
--   * R152: the item turns slowly over the pedestal (a gentle bob too), and its sparkles, an emitter on the item's own ItemCore part in the champion's colour, turn with it (within NEAR_IN
--     studs of the camera, leaving at NEAR_OUT)
--   * R153 (owner's Studio: the giant stood posed, then "violently shaking ... not on the ground", "or it would stop", "and freeze"): the avatar's DANCE is played HERE, on this screen.
--     The server leaves the rig ready (AvatarMode 'dance': an Animator on its Humanoid, the joints at rest, only the root anchored, the state machine off, DanceId) and plays nothing.
--     This loads ONE looped track of HubDisplayRules.DanceIds on that Animator (one made here if the server's never came) and plays it at any distance; a load with no Length after
--     DanceTry seconds is dropped and the next id tried, DanceTries times, then the rig is posed here (HubAvatarPose in its joints' C0) and cheers like R151. A watchdog every TICK
--     keeps it ONE looped track, playing, at the wanted speed (any other track on that Animator is stopped: a second dance is the shaking). It pauses (speed 0) only for what the
--     player chose (reduced motion, Fast Mode), never for the automatic quality tier: a frame-rate dip used to freeze it mid-move. Nothing culls it: on screen it always dances.
--     A rig the server could only pose (AvatarMode 'pose') cheers: HubAvatarPose.CheerAt written into its Motor6D.Transform (never while any track plays on it), and a bigger
--     celebration (both arms up) when a new champion arrives. What the dance did is told to the server for the owner's `/test hubdisplays` (HubDisplayAvatarReport, on change only).
--   * the pop when the champion changes (a burst of sparks over the item) and the celebration sound the server asks for when someone in THIS server takes the top spot
--     (InteractionAudio GemClaim, the game's own reward chime, through the Interface group like every cue).
-- Per-frame work: one function, connected only while a display is near; it moves the item's parts (at most 150) in one BulkMoveTo every frame (30 times a second on the middle quality tier: 12 a second turned in visible steps) and sets about 8 joint
-- transforms 30 times a second (a cheering rig only). Reduced motion (GuiService.ReducedMotionEnabled): none of the motion, no pop, the dance paused (the countdown and the sound stay). Low quality
-- (ClientFxBudget tier 1): no item motion either. A display that streams out is forgotten and a streamed-back copy starts clean; nothing here counts on any child existing yet.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService');local Debris=game:GetService('Debris')
local Rules=require(RS:WaitForChild('HubDisplayRules'));local Pose=require(RS:WaitForChild('HubAvatarPose'))
local Batch;pcall(function()Batch=require(RS:WaitForChild('PlantAnimationBatch'))end)
local Audio;pcall(function()Audio=require(RS:WaitForChild('InteractionAudio'))end)
local ClientFx;pcall(function()ClientFx=require(RS:WaitForChild('ClientFxBudget'))end)
local Cull;pcall(function()Cull=require(RS:WaitForChild('ViewCull152',5))end) -- R152 perf: an item out of view does not move its pieces (its core, light and sparkles still turn)
local RGB=Color3.fromRGB
local NEAR_IN,NEAR_OUT=260,300   -- studs from the camera to the item: the motion starts inside, stops outside (the stand is a landmark: it turns for the whole hub)
local TICK=.5                    -- how often the distance (and what is on the display) is looked at
local TEXT_EVERY=5               -- seconds between countdown writes
local SPIN=.6                    -- the item's turn, radians a second
local BOB=.6                     -- the item's float up and down (studs, every ~4 s)
local ITEM_HZ,ITEM_HZ_LOW,POSE_HZ=math.huge,30,30 -- how often the item's parts (every frame; ITEM_HZ_LOW on the middle quality tier: phones) / the cheering avatar's joints (out of view; in view every frame) are written while near
local FADE=.3                    -- the dance fades in over this (seconds)
local itemHz=ITEM_HZ
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local entries={}                 -- model -> entry
local posedHere=setmetatable({},{__mode='k'}) -- rigs this screen put in the static pose (once each: Pose.Apply turns C0 again on every call)
local reportRemote                -- ChestChaseRemotes.HubDisplayAvatarReport, once it is there
local loop;local lastText=0
local function reduced()
 local ok,value=pcall(function()return GuiService.ReducedMotionEnabled end)
 return ok and value==true
end
local function tier()
 if not ClientFx then return 3 end
 local ok,value=pcall(ClientFx.Get)
 return ok and type(value)=='number'and value or 3
end
-- The dance pauses only for the player's own choice: reduced motion or Fast Mode (their lowest quality). ClientFxBudget's tier also drops by itself for a while when the frame rate dips.
local function fastMode()
 local ok,value=pcall(function()return Players.LocalPlayer:GetAttribute('FastMode')end)
 return ok and value==true
end
local function now()return workspace:GetServerTimeNow()end
local function accentOf(model)
 local c=model:GetAttribute('Accent');if typeof(c)=='Color3'then return c end
 return RGB(255,214,90)
end
-- The countdown text on the label's Footer row.
local function footer(entry)
 local label=entry.Footer
 if not label or not label.Parent then label=entry.Model:FindFirstChild('Footer',true);entry.Footer=label end
 if not label then return end
 local at=entry.Model:GetAttribute('NextAt');local prefix=entry.Model:GetAttribute('FooterPrefix')
 if type(at)~='number'or type(prefix)~='string'then return end
 local text=prefix..Rules.Countdown(at-now())
 if label.Text~=text then label.Text=text end
end
-- The showcase item's parts and where each sits relative to its centre (captured again whenever the server swaps the item).
local function captureItem(entry)
 entry.Parts=nil;entry.ItemModel=nil;entry.Core=nil;entry.Emitter=nil
 local folder=entry.Model:FindFirstChild('Item');local item=folder and folder:FindFirstChildOfClass('Model')
 local center=entry.Model:GetAttribute('ItemCenter')
 if not item or typeof(center)~='Vector3'then return end
 local origin=CFrame.new(center);local list={};local reach=0
 for _,p in ipairs(item:GetDescendants())do if p:IsA('BasePart')then
  local rel=origin:ToObjectSpace(p.CFrame);list[#list+1]={Part=p,Rel=rel,Home=p.CFrame}
  reach=math.max(reach,rel.Position.Magnitude+p.Size.Magnitude/2)
 end end
 entry.ItemModel=item;entry.Parts=list;entry.Center=center;entry.Angle=0;entry.Core=item:FindFirstChild('ItemCore')
 entry.Reach=reach+BOB+2 -- (R152 perf: a ball round the whole item as it turns and bobs; out of view = no piece of it can be on screen)
 entry.CoreRec=nil;for _,r in ipairs(list)do if r.Part==entry.Core then entry.CoreRec=r end end
end
local function restoreItem(entry)
 if not entry.Parts then return end
 for _,r in ipairs(entry.Parts)do if r.Part.Parent then r.Part.CFrame=r.Home end end
 entry.Angle=0
end
-- The avatar ------------------------------------------------------------------------------------------------------------------------------------------------
-- The joints the cheer moves (by name; a joint that is missing is skipped): only a posed rig's (the server's 'pose', or this screen's when the dance would not load).
local function cheerJoints(entry,rig)
 local joints={}
 for name in pairs(Pose.CheerAt(0,0))do local j=Pose.Joint(rig,name);if j then joints[name]=j end end
 entry.Joints=next(joints)and joints or nil
 local ok,cf,size=pcall(rig.GetBoundingBox,rig) -- R153: the ball the cheer is drawn in (the view test of step)
 if ok and typeof(cf)=='CFrame'and typeof(size)=='Vector3'then entry.AvatarCenter,entry.AvatarReach=cf.Position,size.Magnitude/2+2 else entry.AvatarCenter,entry.AvatarReach=nil,nil end
end
local function resetAvatar(entry)
 if not entry.Joints then return end
 for _,j in pairs(entry.Joints)do if j.Parent then pcall(function()j.Transform=CFrame.new()end)end end
end
-- The dance's id for a try: the server's pick (DanceId) first, then the next ones.
local function danceId(rig,try)
 local list=Rules.DanceIds
 local first=table.find(list,rig:GetAttribute('DanceId'))or Rules.DanceIndex(rig:GetAttribute('UserId'),1)
 return list[(first+try-2)%#list+1]
end
local function animatorOf(rig,d,make)
 local humanoid=rig:FindFirstChildOfClass('Humanoid');if not humanoid then return nil end
 local animator=humanoid:FindFirstChildOfClass('Animator')
 if not animator and make then animator=Instance.new('Animator');animator.Name='HubDanceAnimator';animator.Parent=humanoid;d.OwnAnimator=animator end
 return animator
end
local function lengthOf(track)local ok,v=pcall(function()return track.Length end);return ok and type(v)=='number'and v==v and v or 0 end
local function playingOf(track)local ok,v=pcall(function()return track.IsPlaying end);return ok and v==true end
local function dropTrack(d)
 local track,anim=d.Track,d.Anim;d.Track=nil;d.Anim=nil;d.Speed=nil
 if track then pcall(function()track:Stop(0)end);pcall(function()track:Destroy()end)end
 if anim then pcall(function()anim:Destroy()end)end
end
-- One dance only: every OTHER track playing on the rig's Animator is stopped (a track an older server played, or anything else: two dances at once are the shaking). Returns how many.
local function quiet(animator,keep)
 if not animator then return 0 end
 local ok,list=pcall(function()return animator:GetPlayingAnimationTracks()end)
 if not ok or type(list)~='table'then return 0 end
 local n=0
 for _,t in ipairs(list)do if t~=keep then pcall(function()t:Stop(0)end);n+=1 end end
 return n
end
local function stopDance(entry)
 local d=entry.Dance;entry.Dance=nil
 if not d then return end
 dropTrack(d)
 if d.OwnAnimator then pcall(function()d.OwnAnimator:Destroy()end)end
end
-- Tells the server what the avatar does on this screen (only for the owner's status line; once per change).
local function report(entry)
 if not entry.Local then return end
 entry.Unsent=true
 if not reportRemote then return end
 entry.Unsent=nil
 local d=entry.Dance;local rig=entry.AvatarModel
 local info={Kind=entry.Model:GetAttribute('Kind'),Mode=entry.Local,User=rig and rig:GetAttribute('UserId')or 0,Id=d and d.Id or nil,Loaded=d~=nil and d.Loaded==true,
  Length=d and d.Length or 0,Tries=d and d.Try or 0,Paused=entry.Want==0}
 pcall(function()reportRemote:FireServer(info)end)
end
-- A try: a new track of the try's id on the rig's Animator (the server's; from the second try one is made here if it never came), looped, fading in.
local function startTry(entry,d)
 d.Try+=1;d.Started=os.clock();d.Id=danceId(d.Rig,d.Try);d.Length=0;d.Error=nil
 local ok,err=pcall(function()
  local animator=animatorOf(d.Rig,d,d.Try>1)
  if not animator then error('no Animator yet')end
  d.Animator=animator
  local anim=Instance.new('Animation');anim.Name='HubDance';anim.AnimationId=d.Id;d.Anim=anim
  local track=animator:LoadAnimation(anim);d.Track=track
  track.Looped=true;track.Priority=Enum.AnimationPriority.Action
  quiet(animator,track)
  track:Play(FADE)
  local speed=entry.Want or 1;track:AdjustSpeed(speed);d.Speed=speed
 end)
 if not ok then d.Error=tostring(err);dropTrack(d)end
end
-- The dance would not load: the static pose in the joints' C0 on this screen (once per rig), and the cheer.
local function fallBack(entry,d)
 d.Failed=true;dropTrack(d);quiet(d.Animator or animatorOf(d.Rig,d,false),nil)
 local rig=d.Rig
 if not posedHere[rig]then posedHere[rig]=true;pcall(Pose.Apply,rig)end
 entry.Local='pose';cheerJoints(entry,rig)
 warn(('[R153] Hub display %s: the dance did not load in %d s (%d tries, last %s, Length %.2f%s); the avatar is posed on this screen instead'):format(tostring(entry.Model:GetAttribute('Kind')),
  Rules.DanceTry*Rules.DanceTries,d.Try,tostring(d.Id),d.Length or 0,d.Error and(', '..d.Error)or''))
 report(entry)
end
-- Loading: true once the track has its Length and plays.
local function loaded(entry,d)
 local track=d.Track;if not track then return false end
 d.Length=lengthOf(track)
 if d.Length<=0 then return false end
 if not playingOf(track)then pcall(function()track:Play(FADE)end)end
 if not playingOf(track)then return false end
 d.Loaded=true;d.Restarts=0;entry.Local='dance';quiet(d.Animator,track);report(entry)
 return true
end
-- Every TICK (and at once for a new rig): load / retry / fall back, then the watchdog: one looped track, playing, at the wanted speed, nothing else on its Animator.
local function danceStep(entry)
 local d=entry.Dance;if not d or d.Failed or not d.Rig.Parent then return end
 if not d.Loaded then
  if loaded(entry,d)then return end
  if d.Try>0 and os.clock()-d.Started<Rules.DanceTry then return end
  dropTrack(d)
  if d.Try>=Rules.DanceTries then fallBack(entry,d);return end
  startTry(entry,d)
  if not loaded(entry,d)and d.Try==1 then report(entry)end
  return
 end
 local track=d.Track
 if not track or animatorOf(d.Rig,d,false)~=d.Animator then -- (the track or its Animator is gone, or the server's Animator came after this screen made one: load it again)
  dropTrack(d);d.Loaded=false;d.Try=0;entry.Local='loading'
  if d.OwnAnimator and animatorOf(d.Rig,d,false)~=d.OwnAnimator then pcall(function()d.OwnAnimator:Destroy()end);d.OwnAnimator=nil end
  report(entry);return
 end
 if track.Looped~=true then pcall(function()track.Looped=true end)end
 if not playingOf(track)then
  d.Restarts=(d.Restarts or 0)+1
  if d.Restarts>3 then dropTrack(d);d.Loaded=false;d.Try=0;entry.Local='loading';report(entry);return end
  pcall(function()track:Play(FADE)end)
 else d.Restarts=0 end
 local want=entry.Want or 1
 local okSpeed,speed=pcall(function()return track.Speed end) -- (what the track says, should anything else have changed it)
 if d.Speed~=want or(okSpeed and type(speed)=='number'and speed~=want)then if pcall(function()track:AdjustSpeed(want)end)then d.Speed=want end end
 quiet(d.Animator,track)
end
-- The avatar the server put in the display (looked at again when it or its AvatarMode changes).
local function captureAvatar(entry)
 stopDance(entry);entry.Joints=nil;entry.Mode=nil;entry.Local=nil
 local folder=entry.Model:FindFirstChild('Avatar');local rig=folder and folder:FindFirstChildOfClass('Model')
 entry.AvatarModel=rig
 if not rig then return end
 entry.Mode=rig:GetAttribute('AvatarMode')
 if rig:GetAttribute('Fallback')or entry.Mode=='static'then entry.Local='static';report(entry);return end
 if entry.Mode=='dance'then entry.Dance={Rig=rig,Try=0,Started=0};entry.Local='loading';danceStep(entry);return end
 if entry.Mode=='pose'then entry.Local='pose';cheerJoints(entry,rig);report(entry)end
end
-- Sparkles on the item itself, in the champion's colour: an emitter on the item's ItemCore (an invisible part at its centre that turns with it), spawning on a sphere round the item and
-- drifting outward. Gone when the item is, or when it is far, or the display is calm (nobody holds the spot).
local function sparks(entry,on)
 local core=entry.Core
 if on and core and core.Parent and not entry.Emitter then
  local e=Instance.new('ParticleEmitter');e.Name='HubSparks';e.Texture=SPARK;e.Color=ColorSequence.new(accentOf(entry.Model));e.LightEmission=.9;e.LightInfluence=0
  e.Shape=Enum.ParticleEmitterShape.Sphere;e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface;e.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward
  e.Rate=tier()>=3 and 16 or 8;e.Lifetime=NumberRange.new(2,3);e.Speed=NumberRange.new(1.5,3.5);e.Rotation=NumberRange.new(0,360)
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.3,1.1),NumberSequenceKeypoint.new(1,0)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.2),NumberSequenceKeypoint.new(1,1)})
  e.Parent=core;entry.Emitter=e
 elseif not on and entry.Emitter then entry.Emitter:Destroy();entry.Emitter=nil end
end
-- A burst of sparks over the item when a new champion takes the spot.
local function pop(entry)
 if reduced()or not entry.Center then return end
 local color=accentOf(entry.Model)
 local spot=Instance.new('Part');spot.Name='HubPopSparks';spot.Size=Vector3.new(.2,.2,.2);spot.Transparency=1;spot.Anchored=true;spot.CanCollide=false;spot.CanQuery=false
 spot.CanTouch=false;spot.CastShadow=false;spot.CFrame=CFrame.new(entry.Center);spot.Parent=workspace
 local att=Instance.new('Attachment');att.Parent=spot
 local e=Instance.new('ParticleEmitter');e.Texture=SPARK;e.Color=ColorSequence.new(color);e.LightEmission=1;e.LightInfluence=0;e.Lifetime=NumberRange.new(.8,1.4)
 e.Speed=NumberRange.new(14,26);e.SpreadAngle=Vector2.new(180,180);e.Size=NumberSequence.new(1.2,0);e.Rate=0;e.Parent=att
 e:Emit(tier()>=3 and 36 or 18)
 Debris:AddItem(spot,1.8)
 entry.CelebrateAt=os.clock()
end
local function cameraPosition()
 local camera=workspace.CurrentCamera;return camera and camera.CFrame.Position or nil
end
local function distance(entry)
 local at=cameraPosition();local center=entry.Model:GetAttribute('ItemCenter')
 if not at or typeof(center)~='Vector3'then return math.huge end
 return(at-center).Magnitude
end
-- The per-frame function (connected only while some display is near).
local itemClock,poseClock=0,0
local function step(dt)
 local t=os.clock();local any=false
 itemClock+=dt;poseClock+=dt
 local doItem,doPose=itemClock>=1/itemHz,poseClock>=1/POSE_HZ
 for model,entry in pairs(entries)do
  if entry.Active and model.Parent then
   any=true
   if doItem and entry.Parts then
    entry.Angle=(entry.Angle+itemClock*SPIN)%(math.pi*2)
    if Batch then
     entry.Batch=entry.Batch or Batch.new(workspace)
     local turn=CFrame.new(entry.Center+Vector3.new(0,math.sin(t*1.5)*BOB,0))*CFrame.Angles(0,entry.Angle,0)
     -- R152 perf: out of view (and not close: the giant pieces' close-up fade) only the core moves: its light and sparkles stay right; the pieces
     -- (no shadow, no light) are put where they belong again in the frame the item comes back into view
     if Cull and entry.Reach and Cull.Hidden(workspace.CurrentCamera,entry.Center,entry.Reach,12)then
      local r=entry.CoreRec;if r and r.Part.Parent then entry.Batch:Set(r.Part,turn*r.Rel)end
     else
      for _,r in ipairs(entry.Parts)do if r.Part.Parent then entry.Batch:Set(r.Part,turn*r.Rel)end end
     end
     entry.Batch:Flush()
    end
   end
   -- R153 (owner: "reduce jitter in effects"): the cheer is written every frame while the avatar is in view (30 Hz before: a giant rig stepping); out of view POSE_HZ
   local seen=not(Cull and entry.AvatarReach and Cull.Hidden(workspace.CurrentCamera,entry.AvatarCenter,entry.AvatarReach,12))
   if(doPose or seen)and entry.Joints and entry.Local=='pose'then -- (only a posed rig: a dancing one is its Animator's alone)
    local boost=entry.CelebrateAt and Pose.CelebrateAt(t-entry.CelebrateAt)or 0
    local pose=Pose.CheerAt(t,boost)
    for name,j in pairs(entry.Joints)do if j.Parent and pose[name]then pcall(function()j.Transform=pose[name]end)end end
   end
  end
 end
 if doItem then itemClock=0 end
 if doPose then poseClock=0 end
 if not any and loop then loop:Disconnect();loop=nil end
end
-- What a display needs every TICK: the right captures, near / far, the dance (load, retry, watchdog, speed), the pop on a new champion, the countdown.
local function update(entry)
 local model=entry.Model
 local folder=model:FindFirstChild('Item');local item=folder and folder:FindFirstChildOfClass('Model')
 if item~=entry.ItemModel then restoreItem(entry);captureItem(entry)end
 local paused=reduced()or fastMode()
 local want=paused and 0 or 1
 local wantChanged=entry.Want~=nil and entry.Want~=want
 entry.Want=want
 local avatarFolder=model:FindFirstChild('Avatar');local rig=avatarFolder and avatarFolder:FindFirstChildOfClass('Model')
 -- (the server says how the avatar moves a moment after the rig arrives: look again when that changes)
 if rig~=entry.AvatarModel or(rig and rig:GetAttribute('AvatarMode')~=entry.Mode)then resetAvatar(entry);captureAvatar(entry)end
 danceStep(entry)
 if wantChanged and entry.Local=='dance'then report(entry)end
 if entry.Local=='pose'and entry.AvatarModel then -- (a posed rig: nothing may play on it while the cheer writes its joints)
  local humanoid=entry.AvatarModel:FindFirstChildOfClass('Humanoid');quiet(humanoid and humanoid:FindFirstChildOfClass('Animator'),nil)
 end
 if entry.Unsent and reportRemote then report(entry)end
 local d=distance(entry)
 local wasActive=entry.Active==true
 local allowed=not paused and tier()>=2
 itemHz=ITEM_HZ -- R153 (owner: "fix all jittery type effects"): the item turns every frame on every tier (ITEM_HZ_LOW, 30 Hz on tier 2, stepped on a 60 Hz screen); out of view only its core moves (ViewCull152)
 local active=allowed and(wasActive and d<=NEAR_OUT or d<=NEAR_IN)
 entry.Active=active
 if active then
  sparks(entry,model:GetAttribute('Calm')~=true)
  if not loop then itemClock,poseClock=0,0;loop=Run.RenderStepped:Connect(step)end
 elseif wasActive or not allowed then
  sparks(entry,false);restoreItem(entry);resetAvatar(entry)
 end
 -- a new champion (the server bumps Rev last): pop it, if this screen is looking at it
 local rev=model:GetAttribute('Rev')
 if entry.Rev~=nil and rev~=entry.Rev and model:GetAttribute('State')=='Champion'and d<=NEAR_OUT*1.6 then pop(entry)end
 entry.Rev=rev
end
local function safe(entry,fn)
 local ok,err=pcall(fn,entry)
 if not ok and entry.LastError~=err then entry.LastError=err;warn('[R151] Hub display: '..tostring(err))end -- (told once per different problem; the display is just plainer)
end
local function drop(e)sparks(e,false);stopDance(e);resetAvatar(e)end
local function register(model)
 if entries[model]or not model:IsA('Model')then return end
 local entry={Model=model,Rev=nil}
 entries[model]=entry
 entry.Rev=model:GetAttribute('Rev')
 safe(entry,footer);safe(entry,update)
 -- the server writes the countdown's attributes with the display (or a moment after it): follow them at once
 for _,name in ipairs({'NextAt','FooterPrefix'})do model:GetAttributeChangedSignal(name):Connect(function()safe(entry,footer)end)end
 model.Destroying:Connect(function()
  local e=entries[model];entries[model]=nil
  if e then pcall(drop,e)end
 end)
end
local function forget(model)
 local e=entries[model];if not e then return end
 entries[model]=nil;pcall(drop,e)
end
for _,model in ipairs(CS:GetTagged(Rules.Tag))do task.spawn(register,model)end
CS:GetInstanceAddedSignal(Rules.Tag):Connect(function(model)task.spawn(register,model)end)
CS:GetInstanceRemovedSignal(Rules.Tag):Connect(forget)
-- The celebration sound: someone in this server took a top spot (the server asks for it in step with the record's chat line: after the puller's own reveal).
task.spawn(function()
 local remotes=RS:WaitForChild('ChestChaseRemotes',30);local remote=remotes and remotes:WaitForChild('HubDisplayCelebrate',30)
 if not remote then return end
 remote.OnClientEvent:Connect(function(info)
  if type(info)~='table'or(info.Kind~='Pull'and info.Kind~='Fruit')then return end
  if Audio then pcall(Audio.Play,'GemClaim')end
 end)
end)
-- R153: the dance report remote (the server makes it at start; whatever was waiting goes out at once)
task.spawn(function()
 local ok,remote=pcall(function()local remotes=RS:WaitForChild('ChestChaseRemotes',30);return remotes and remotes:WaitForChild(Rules.ReportRemote,30)end)
 if not ok or not remote then return end
 reportRemote=remote
 for _,e in pairs(entries)do if e.Unsent then pcall(report,e)end end
end)
-- The slow tick: distance, captures, the dance, countdown (a delayed call that schedules the next, so nothing waits in a loop).
local function tick()
 local text=os.clock()-lastText>=TEXT_EVERY
 if text then lastText=os.clock()end
 for _,entry in pairs(entries)do
  if entry.Model.Parent then
   safe(entry,update)
   if text then safe(entry,footer)end
  end
 end
 task.delay(TICK,tick)
end
task.delay(TICK,tick)
