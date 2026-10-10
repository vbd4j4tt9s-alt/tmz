do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R43. Native tool activation supports mouse, touch and controller.
-- R158 (docs/proposals/R158/bats, owner-approved): your swing starts on your screen the moment you click (no wait for the server) and the request
-- carries that start time. During the strike (BatConfig HitFrom..HitTo) your client sweeps every other player's path as YOUR screen shows it
-- (BatHitbox) and claims the first one the bat's sector touches, with that exact moment, your spot and your facing; the server re-checks the claim
-- against its own history and decides (BatService / BatLagComp). Your hit is shown at once: the slap, the star, sparks and a short hit-stop of your
-- swing (no camera shake for you, no "SMACK!" word: the owner's choices). A short white trail follows the bat during the strike only (off in Fast
-- Mode / low graphics and far away). Other players' swings play from the server's packet as before (they join late and skip ahead, Lead).
-- Carrying a pack: the bat takes the right arm only (SeedCarryPose keeps the left hand on the pack); the waist's turn is folded into the right arm.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local C=require(RS:WaitForChild('BatConfig'))
local Pose=require(RS:WaitForChild('BatSwingPose'))
local Sfx=require(RS:WaitForChild('LocalSfx'))
local Hitbox=require(RS:WaitForChild('BatHitbox'))
local Burst=require(RS:WaitForChild('HitBurstFx'))
local player=Players.LocalPlayer
local folder=RS:WaitForChild('ChestChaseRemotes',20);if not folder then return end
local remote=folder:WaitForChild('BatSwing',20);if not remote then return end
Sfx.Preload({C.SlapSoundId,Sfx.WhooshId})
local bound,poses,connections={},{},{}
local preAnimation,preSimulation
local activateFrames
-- R158: your own swing's sweep (one table, reused) and, per other player, where it was relative to you at the last frame (kept, never remade)
local sweep={Active=false,Start=0,Id=0,Character=nil,PrevT=nil,OX=0,OY=0,OZ=0}
local prevX,prevY,prevZ,prevAt,bornAt,others,otherLinks={},{},{},{},{},{},{}
local sentId,lastStart=0,-math.huge
local trails=setmetatable({},{__mode='k'}) -- bat -> its Trail (made once per bat, the first time it swings near you)
local trailColor=ColorSequence.new(Color3.fromRGB(C.TrailRGB[1],C.TrailRGB[2],C.TrailRGB[3]))
local trailFade=NumberSequence.new({NumberSequenceKeypoint.new(0,.2),NumberSequenceKeypoint.new(1,1)})
local trailWidth=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.25)})
local ORDER={'Waist','RootJoint','RightShoulder','RightElbow','RightWrist','LeftShoulder','LeftElbow','RightGrip'}
local function resetJoint(entry)
 local joint=entry.Joint
 if joint.Parent and entry.Written and joint[entry.Property]==entry.Written then joint[entry.Property]=entry.Base end
 entry.Written=nil
end
local function stopFrames()
 if preAnimation then preAnimation:Disconnect();preAnimation=nil end
 if preSimulation then preSimulation:Disconnect();preSimulation=nil end
end
local function restore(character)
 local pose=poses[character];poses[character]=nil
 if pose then
  for _,entry in ipairs(pose.Joints)do resetJoint(entry)end
  if pose.Trail then pose.Trail.Enabled=false end
  character:SetAttribute('BatSwingArm',nil)
 end
 if not next(poses)and not sweep.Active then stopFrames()end
end
local function joints(character,handle)
 local chosen={}
 for _,joint in ipairs(character:GetDescendants())do
  local name=joint.Name:gsub(' ','')
  if name=='RightGrip'and(joint:IsA('Weld')or joint:IsA('Motor6D'))and joint.Part1==handle then
   chosen[name]={Joint=joint,Name=name,Property='C0',Base=joint.C0}
  elseif name=='RightShoulder'or name=='RightElbow'or name=='RightWrist'or name=='Waist'or name=='RootJoint'or name=='LeftShoulder'or name=='LeftElbow'then
   local frame,rest
   if joint:IsA('AnimationConstraint')and joint.Attachment0 and joint.Attachment1 then frame,rest=joint.Attachment0.CFrame,joint.Attachment1.CFrame
   elseif joint:IsA('Motor6D')and not chosen[name]then frame,rest=joint.C0,joint.C1 end
   if frame then chosen[name]={Joint=joint,Name=name,Property='Transform',Basis=frame.Rotation,Rest=rest.Rotation,
    Twist=name=='Waist'or name=='RootJoint',Left=name=='LeftShoulder'or name=='LeftElbow'}end
  end
 end
 if chosen.Waist then chosen.RootJoint=nil end
 -- (the waist first: a carrier's right arm takes its turn)
 local result={};for _,name in ipairs(ORDER)do if chosen[name]then table.insert(result,chosen[name])end end;return result
end
-- R158: the bat's trail, between two Attachments on the barrel (half way out and near the tip, found from the bat's own parts once)
local function trailFor(tool,handle)
 local trail=trails[tool]
 if trail and trail.Parent then return trail end
 local best,dir=0,nil;local inverse=handle.CFrame:Inverse()
 for _,part in ipairs(tool:GetChildren())do if part:IsA('BasePart')and part~=handle then
  local rel=inverse*part.Position;local size=part.Size
  if rel.Magnitude>.05 then
   local reach=rel.Magnitude+math.max(size.X,size.Y,size.Z)*.5
   if reach>best then best,dir=reach,rel.Unit end
  end
 end end
 if not dir then dir=Vector3.new(0,1,0);best=math.max(1,handle.Size.Y)end
 local mid=Instance.new('Attachment');mid.Name='BatTrailMid';mid.Position=dir*best*.55;mid.Parent=handle
 local tip=Instance.new('Attachment');tip.Name='BatTrailTip';tip.Position=dir*best*.95;tip.Parent=handle
 trail=Instance.new('Trail');trail.Name='BatSwingTrail';trail.Attachment0=mid;trail.Attachment1=tip;trail.Color=trailColor;trail.Transparency=trailFade
 trail.WidthScale=trailWidth;trail.Lifetime=C.TrailLifetime;trail.LightEmission=C.TrailLightEmission;trail.MinLength=0;trail.FaceCamera=false
 trail.Enabled=false;trail.Parent=handle;trails[tool]=trail
 return trail
end
-- a swing's pose (and whoosh, and trail) on a character: yours at your click, anyone else's from the server's packet. at = the swing's start (server time).
local function begin(character,tool,handle,at)
 restore(character)
 -- R150: a swing is heard even when it misses: the whoosh is timed so it meets the contact frame (At + Windup), and joins late like the pose does.
 local root=character:FindFirstChild('HumanoidRootPart');local camera=workspace.CurrentCamera
 local near=root~=nil and camera~=nil and (camera.CFrame.Position-root.Position).Magnitude<=C.SwingSoundRange
 if near then
  local wait=at+C.Windup-C.SwingSoundLead-workspace:GetServerTimeNow()
  local function whoosh()if root.Parent then Sfx.Play(Sfx.WhooshId,root.Position,C.SwingSoundVolume,C.SwingSoundPitch,2,wait<0 and-wait or 0)end end
  if wait>0 then task.delay(wait,whoosh)else whoosh()end
 end
 local entries=joints(character,handle);if #entries==0 then return end
 -- R112: Lead lets a late-arriving swing still show its full wind-back; R6 samples the one-piece arm.
 local hum=character:FindFirstChildOfClass('Humanoid')
 local pose={Tool=tool,Joints=entries,At=at,Lead=math.max(0,workspace:GetServerTimeNow()-at),R6=hum~=nil and hum.RigType==Enum.HumanoidRigType.R6,
  TrailAllowed=near and not Burst.Low(),TrailOn=false}
 if pose.TrailAllowed then pose.Trail=trailFor(tool,handle)end
 poses[character]=pose;character:SetAttribute('BatSwingArm',true);activateFrames()
end
local function swing(tool)
 local character=player.Character;local handle=tool:FindFirstChild('Handle')
 local hum=character and character:FindFirstChildOfClass('Humanoid')
 if not character or tool.Parent~=character or not tool.Enabled or not handle or not hum or hum.Health<=0 or character:GetAttribute('ChestChaseRagdollActive')then return end
 local start=workspace:GetServerTimeNow()
 if start<lastStart+C.Cooldown then return end -- (the server's cooldown, counted the same way: between the swings' starts)
 lastStart=start;sentId+=1
 remote:FireServer({Kind='Swing',Start=start,Id=sentId})
 local motion=RS:FindFirstChild('RunnerMotion');local map=workspace:FindFirstChild('ChestChaseMap')
 sweep.Active=true;sweep.Start=start;sweep.Id=sentId;sweep.Character=character;sweep.Tool=tool;sweep.PrevT=nil
 sweep.LineZ=motion and motion:GetAttribute('TrackBoundaryZ');sweep.CX=motion and motion:GetAttribute('TrackCenterX')
 sweep.Half=motion and motion:GetAttribute('TrackHalfWidth');sweep.EndZ=map and map:GetAttribute('BiomeTrackEndZ')
 begin(character,tool,handle,start)
 activateFrames()
end
-- R158: who your swing may claim, as far as your client can tell (the server checks it all again): on the track past the base line, not knocked down
-- or just thrown, no ForceField, not in its first SpawnGrace seconds.
local function hittable(other,character)
 local hum=character:FindFirstChildOfClass('Humanoid')
 if not hum or hum.Health<=0 or character:FindFirstChildOfClass('ForceField')or character:GetAttribute('ChestChaseRagdollActive')
  or other:GetAttribute('GuardianRagdollActive')or other:GetAttribute('GuardianFlingActive')or os.clock()-(bornAt[other]or-math.huge)<C.SpawnGrace then return false end
 return true
end
local function claim(other,view,ox,oy,oz,fx,fz,vx,vy,vz,now)
 sweep.Active=false
 remote:FireServer({Kind='Hit',Id=sweep.Id,Victim=other,ViewTime=view,Own=Vector3.new(ox,oy,oz),Look=Vector3.new(fx,0,fz)})
 -- your hit, at once: the slap, the star, the sparks, the hit-stop (the server's packet for it is then skipped on your screen; no camera shake)
 Burst.NoteOwnHit(other.UserId)
 local at=Vector3.new(vx,vy,vz)
 Sfx.Play(C.SlapSoundId,at,C.SlapVolume,1,2);Burst.Star(at);Burst.Sparks(at)
 local p=poses[sweep.Character]
 if p and not p.StopUntil then p.StopAt=now-p.At;p.StopUntil=now+C.HitStop end
end
-- once per frame of your swing: every other player's path since the last frame (relative to you, as your screen shows it) against the bat's sector
local function sweepFrame(now)
 local s=sweep;local character=s.Character
 local root=character and character.Parent and character:FindFirstChild('HumanoidRootPart')
 if not root or s.Tool.Parent~=character or not s.Tool.Enabled or character:GetAttribute('ChestChaseRagdollActive')or now-s.Start>C.HitTo+.25 then
  s.Active=false;return
 end
 if now<s.Start+C.HitFrom-.1 then return end
 local frame=root.CFrame;local p=frame.Position;local look=frame.LookVector
 local ox,oy,oz=p.X,p.Y,p.Z;local fx,fz=Hitbox.Flat(look.X,look.Z)
 local prevT=s.PrevT
 local strike=prevT~=nil and fx~=nil and prevT<s.Start+C.HitTo and now>=s.Start+C.HitFrom and not character:FindFirstChildOfClass('ForceField')
  and os.clock()-(bornAt[player]or-math.huge)>=C.SpawnGrace and Hitbox.OnTrack(ox,oz,s.LineZ,s.CX,s.Half,s.EndZ)
 for _,other in ipairs(others)do
  local oc=other.Character;local r=oc and oc:FindFirstChild('HumanoidRootPart')
  if r then
   local q=r.Position;local rx,ry,rz=q.X-ox,q.Y-oy,q.Z-oz
   if strike and prevAt[other]==prevT and hittable(other,oc)and Hitbox.OnTrack(q.X,q.Z,s.LineZ,s.CX,s.Half,s.EndZ)then
    local u=Hitbox.ClientFrame(prevX[other],prevY[other],prevZ[other],rx,ry,rz,fx,fz)
    if u then
     local ax,ay,az=s.OX+(ox-s.OX)*u,s.OY+(oy-s.OY)*u,s.OZ+(oz-s.OZ)*u
     claim(other,prevT+(now-prevT)*u,ax,ay,az,fx,fz,ax+prevX[other]+(rx-prevX[other])*u,ay+prevY[other]+(ry-prevY[other])*u,az+prevZ[other]+(rz-prevZ[other])*u,now)
     return
    end
   end
   prevX[other],prevY[other],prevZ[other],prevAt[other]=rx,ry,rz,now
  end
 end
 s.PrevT=now;s.OX,s.OY,s.OZ=ox,oy,oz
 if now>=s.Start+C.HitTo then s.Active=false end -- the strike is over: a miss (the whoosh was the sound)
end
-- one frame of a swing pose. A carrier's waist and left arm stay with the Animator and the carry pose; the waist's turn goes into the right arm.
local function poseFrame(character,p,now)
 local t=now-p.At
 if p.StopUntil then if now<p.StopUntil then t=p.StopAt else t-=C.HitStop end end
 local hum=character:FindFirstChildOfClass('Humanoid')
 if not character.Parent or p.Tool.Parent~=character or not p.Tool.Enabled or not hum or hum.Health<=0
  or character:GetAttribute('ChestChaseRagdollActive')or t>=Pose.Total then restore(character);return end
 local on=p.TrailAllowed and t>=C.TrailFrom and t<C.TrailTo
 if on~=p.TrailOn then p.TrailOn=on;if p.Trail then if on then p.Trail:Clear()end;p.Trail.Enabled=on end end
 local bag=character:FindFirstChild('CarriedSeed');local carrying=bag~=nil and bag:GetAttribute('SeedPackCarry')==true
 local fold
 for _,entry in ipairs(p.Joints)do if entry.Joint.Parent then
  local target,weight=Pose.Sample(entry.Name,t,p.Lead,p.R6)
  if entry.Property=='Transform'then
   resetJoint(entry);local base=entry.Joint.Transform;entry.Base=base
   local written=base:Lerp(entry.Basis:Inverse()*target*entry.Basis,weight)
   if carrying and entry.Twist then fold=(entry.Rest*base:Inverse()*written*entry.Rest:Inverse()).Rotation;written=nil
   elseif carrying and entry.Left then written=nil
   elseif fold and entry.Name=='RightShoulder'then written=entry.Basis:Inverse()*fold*entry.Basis*written end
   entry.Written=written
   if written then entry.Joint.Transform=written end
  else entry.Written=entry.Base*CFrame.new():Lerp(target,weight);entry.Joint[entry.Property]=entry.Written end
 end end
end
local function bind(tool)
 if not tool:IsA('Tool')or tool:GetAttribute('ChestChaseBat')~=true or bound[tool]then return end
 local links={};bound[tool]=links
 table.insert(links,tool.Activated:Connect(function()swing(tool)end))
 table.insert(links,tool.Destroying:Connect(function()for _,link in ipairs(links)do link:Disconnect()end;bound[tool]=nil end))
end
local function watch(container)
 for _,tool in ipairs(container:GetChildren())do bind(tool)end
 return container.ChildAdded:Connect(bind)
end
local characterLink
local function characterAdded(character)
 if characterLink then characterLink:Disconnect()end
 characterLink=watch(character)
 bornAt[player]=os.clock()
end
local backpack=player:WaitForChild('Backpack')
local backpackLink=watch(backpack)
table.insert(connections,player.ChildAdded:Connect(function(child)
 if child:IsA('Backpack')and child~=backpack then
  backpackLink:Disconnect();backpack=child;backpackLink=watch(child)
 end
end))
table.insert(connections,player.CharacterAdded:Connect(characterAdded))
table.insert(connections,player.CharacterRemoving:Connect(function(character)
 if sweep.Character==character then sweep.Active=false end
 restore(character);if characterLink then characterLink:Disconnect();characterLink=nil end
end))
if player.Character then characterAdded(player.Character)end
-- the other players (a list kept here, so the sweep makes no list per frame) and when their characters arrived
local function track(other)
 if other==player or table.find(others,other)then return end
 table.insert(others,other)
 otherLinks[other]=other.CharacterAdded:Connect(function()bornAt[other]=os.clock()end)
end
for _,other in ipairs(Players:GetPlayers())do track(other)end
table.insert(connections,Players.PlayerAdded:Connect(track))
table.insert(connections,Players.PlayerRemoving:Connect(function(other)
 local i=table.find(others,other);if i then table.remove(others,i)end
 if otherLinks[other]then otherLinks[other]:Disconnect();otherLinks[other]=nil end
 prevX[other],prevY[other],prevZ[other],prevAt[other],bornAt[other]=nil,nil,nil,nil,nil
end))
table.insert(connections,remote.OnClientEvent:Connect(function(event)
 if type(event)~='table'or event.Kind~='Swing'or typeof(event.Character)~='Instance'
  or type(event.At)~='number'or workspace:GetServerTimeNow()-event.At>C.Windup+C.Recovery then return end
 local character=event.Character
 -- R158: the server's echo of YOUR swing: it already started at your click
 if character==player.Character and type(event.Id)=='number'and event.Id<=sentId and event.Id>0 then return end
 local tool
 for _,item in ipairs(character:GetChildren())do if item:IsA('Tool')and item:GetAttribute('ChestChaseBat')then tool=item;break end end
 if not tool then return end
 local handle=tool:FindFirstChild('Handle');if not handle then return end
 begin(character,tool,handle,event.At)
end))
-- Clear our previous overlay before Animator evaluates; never accumulate a procedural offset.
activateFrames=function()
 if preAnimation then return end
 preAnimation=Run.PreAnimation:Connect(function()
 for _,pose in pairs(poses)do for _,entry in ipairs(pose.Joints)do
  if entry.Property=='Transform'then resetJoint(entry)end
 end end
end)
 preSimulation=Run.PreSimulation:Connect(function()
 local now=workspace:GetServerTimeNow()
 if sweep.Active then sweepFrame(now)end -- (first: a hit found this frame pauses your swing this frame)
 for character,p in pairs(poses)do poseFrame(character,p,now)end
 if not next(poses)and not sweep.Active then stopFrames()end
end)
end
script.Destroying:Connect(function()
 backpackLink:Disconnect()
 if characterLink then characterLink:Disconnect()end
 for _,link in ipairs(connections)do link:Disconnect()end
 for _,link in pairs(otherLinks)do link:Disconnect()end
 for _,links in pairs(bound)do for _,link in ipairs(links)do link:Disconnect()end end
 sweep.Active=false
 for character in pairs(poses)do restore(character)end
 stopFrames()
end)
