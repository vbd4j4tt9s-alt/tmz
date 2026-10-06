do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R151 (owner: BEST PULL TODAY and BIGGEST FRUIT TODAY in the hub's two empty corners): the part each player runs on their own screen. The server (HubDisplayService /
-- HubDisplayArt) builds everything that is still: the pedestal, the words, the showcase item and the champion's avatar. This adds what moves, and only while it is near and nothing
-- is switched off:
--   * the "New board in 5h 12m" countdown (a text on the pedestal's plaque: the display's NextAt attribute is the server time of the next UTC midnight; kept up to date for every display
--     that has streamed in, every 5 s, a couple of text writes)
--   * R152: the item turns slowly over the pedestal (a gentle bob too), and its sparkles, an emitter on the item's own ItemCore part in the champion's colour, turn with it (within NEAR_IN
--     studs of the camera, leaving at NEAR_OUT)
--   * the avatar: it dances on the Animator the server started (HubDisplayAvatar.Animate: a replicated track); here it is only paused (speed 0) while reduced motion or the lowest quality
--     tier is on. A rig the server could not animate (AvatarMode 'pose') cheers instead: HubAvatarPose.CheerAt written into its Motor6D.Transform (a client-side property that never
--     replicates), and a bigger celebration (both arms up) when a new champion arrives
--   * the pop when the champion changes (a burst of sparks over the item) and the celebration sound the server asks for when someone in THIS server takes the top spot
--     (InteractionAudio GemClaim, the game's own reward chime, through the Interface group like every cue).
-- Per-frame work: one function, connected only while a display is near; it moves the item's parts (at most 150) in one BulkMoveTo every frame (30 times a second on the middle quality tier: 12 a second turned in visible steps) and sets about 8 joint
-- transforms 30 times a second (a cheering rig only). Reduced motion (GuiService.ReducedMotionEnabled): none of the motion, no pop (the countdown and the sound stay). Low quality
-- (ClientFxBudget tier 1): no motion either. A display that streams out is forgotten and a streamed-back copy starts clean; nothing here counts on any child existing yet.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local CS=game:GetService('CollectionService')
local Run=game:GetService('RunService');local GuiService=game:GetService('GuiService');local Debris=game:GetService('Debris')
local Rules=require(RS:WaitForChild('HubDisplayRules'));local Pose=require(RS:WaitForChild('HubAvatarPose'))
local Batch;pcall(function()Batch=require(RS:WaitForChild('PlantAnimationBatch'))end)
local Audio;pcall(function()Audio=require(RS:WaitForChild('InteractionAudio'))end)
local ClientFx;pcall(function()ClientFx=require(RS:WaitForChild('ClientFxBudget'))end)
local RGB=Color3.fromRGB
local NEAR_IN,NEAR_OUT=260,300   -- studs from the camera to the item: the motion starts inside, stops outside (the stand is a landmark: it turns for the whole hub)
local TICK=.5                    -- how often the distance (and what is on the display) is looked at
local TEXT_EVERY=5               -- seconds between countdown writes
local SPIN=.6                    -- the item's turn, radians a second
local BOB=.6                     -- the item's float up and down (studs, every ~4 s)
local ITEM_HZ,ITEM_HZ_LOW,POSE_HZ=math.huge,30,30 -- how often the item's parts (every frame; ITEM_HZ_LOW on the middle quality tier: phones) / the avatar's joints are written while near
local itemHz=ITEM_HZ
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local entries={}                 -- model -> entry
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
local function now()return workspace:GetServerTimeNow()end
local function accentOf(model)
 local c=model:GetAttribute('Accent');if typeof(c)=='Color3'then return c end
 return RGB(255,214,90)
end
-- The countdown text on the sign's footer.
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
 local origin=CFrame.new(center);local list={}
 for _,p in ipairs(item:GetDescendants())do if p:IsA('BasePart')then list[#list+1]={Part=p,Rel=origin:ToObjectSpace(p.CFrame),Home=p.CFrame}end end
 entry.ItemModel=item;entry.Parts=list;entry.Center=center;entry.Angle=0;entry.Core=item:FindFirstChild('ItemCore')
end
local function restoreItem(entry)
 if not entry.Parts then return end
 for _,r in ipairs(entry.Parts)do if r.Part.Parent then r.Part.CFrame=r.Home end end
 entry.Angle=0
end
-- The avatar's joints that the cheer moves (by name; a joint that is missing is skipped): only a rig the server put in the static pose ('pose'); a dancing rig belongs to its Animator.
local function captureAvatar(entry)
 entry.Joints=nil;entry.AvatarModel=nil;entry.Mode=nil;entry.Speed=nil
 local folder=entry.Model:FindFirstChild('Avatar');local rig=folder and folder:FindFirstChildOfClass('Model')
 entry.AvatarModel=rig
 entry.Mode=rig and rig:GetAttribute('AvatarMode')or nil
 if not rig or rig:GetAttribute('Fallback')or entry.Mode~='pose'then return end
 local joints={}
 for name in pairs(Pose.CheerAt(0,0))do local j=Pose.Joint(rig,name);if j then joints[name]=j end end
 if next(joints)then entry.Joints=joints end
end
local function resetAvatar(entry)
 if not entry.Joints then return end
 for _,j in pairs(entry.Joints)do if j.Parent then pcall(function()j.Transform=CFrame.new()end)end end
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
-- A dancing rig is paused (speed 0) while motion is not allowed, and runs again when it is: the replicated track's local copy, so it costs the server nothing.
local function danceSpeed(entry,speed)
 if entry.Mode~='dance'or entry.Speed==speed then return end
 local rig=entry.AvatarModel;local humanoid=rig and rig:FindFirstChildOfClass('Humanoid');local animator=humanoid and humanoid:FindFirstChildOfClass('Animator')
 if not animator then return end
 local ok,tracks=pcall(function()return animator:GetPlayingAnimationTracks()end)
 if not ok or type(tracks)~='table'then return end
 for _,t in ipairs(tracks)do pcall(function()t:AdjustSpeed(speed)end)end
 if #tracks>0 then entry.Speed=speed end -- (no track yet: look again next tick)
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
     for _,r in ipairs(entry.Parts)do if r.Part.Parent then entry.Batch:Set(r.Part,turn*r.Rel)end end
     entry.Batch:Flush()
    end
   end
   if doPose and entry.Joints then -- (only a rig in its static pose: a dancing one is the Animator's)
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
-- What a display needs every TICK: the right captures, near / far, the dance's speed, the pop on a new champion, the countdown.
local function update(entry)
 local model=entry.Model
 local folder=model:FindFirstChild('Item');local item=folder and folder:FindFirstChildOfClass('Model')
 if item~=entry.ItemModel then restoreItem(entry);captureItem(entry)end
 local avatarFolder=model:FindFirstChild('Avatar');local rig=avatarFolder and avatarFolder:FindFirstChildOfClass('Model')
 -- (the server says how the avatar moves a moment after the rig arrives: look again when that changes)
 if rig~=entry.AvatarModel or(rig and rig:GetAttribute('AvatarMode')~=entry.Mode)then resetAvatar(entry);captureAvatar(entry)end
 local d=distance(entry)
 local wasActive=entry.Active==true
 local allowed=not reduced()and tier()>=2
 itemHz=tier()>=3 and ITEM_HZ or ITEM_HZ_LOW
 local active=allowed and(wasActive and d<=NEAR_OUT or d<=NEAR_IN)
 entry.Active=active
 danceSpeed(entry,allowed and 1 or 0)
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
  if e then sparks(e,false)end
 end)
end
local function forget(model)
 local e=entries[model];if not e then return end
 entries[model]=nil;sparks(e,false)
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
-- The slow tick: distance, captures, countdown (a delayed call that schedules the next, so nothing waits in a loop).
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
