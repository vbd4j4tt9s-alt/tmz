do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R43. Native tool activation supports mouse, touch and controller. No client hit claims.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local C=require(RS:WaitForChild('BatConfig'))
local Pose=require(RS:WaitForChild('BatSwingPose'))
local Sfx=require(RS:WaitForChild('LocalSfx'))
local player=Players.LocalPlayer
local folder=RS:WaitForChild('ChestChaseRemotes',20);if not folder then return end
local remote=folder:WaitForChild('BatSwing',20);if not remote then return end
Sfx.Preload({C.SlapSoundId,Sfx.WhooshId})
local bound,poses,connections={},{},{}
local preAnimation,preSimulation
local activateFrames
local function resetJoint(entry)
 local joint=entry.Joint
 if joint.Parent and entry.Written and joint[entry.Property]==entry.Written then joint[entry.Property]=entry.Base end
 entry.Written=nil
end
local function restore(character)
 local pose=poses[character];poses[character]=nil
 if pose then for _,entry in ipairs(pose.Joints)do resetJoint(entry)end end
 if not next(poses)then
  if preAnimation then preAnimation:Disconnect();preAnimation=nil end
  if preSimulation then preSimulation:Disconnect();preSimulation=nil end
 end
end
local function joints(character,handle)
 local chosen={}
 for _,joint in ipairs(character:GetDescendants())do
  local name=joint.Name:gsub(' ','')
  if name=='RightGrip'and(joint:IsA('Weld')or joint:IsA('Motor6D'))and joint.Part1==handle then
   chosen[name]={Joint=joint,Name=name,Property='C0',Base=joint.C0}
  elseif name=='RightShoulder'or name=='RightElbow'or name=='RightWrist'or name=='Waist'or name=='RootJoint'or name=='LeftShoulder'or name=='LeftElbow'then
   local frame
   if joint:IsA('AnimationConstraint')and joint.Attachment0 and joint.Attachment1 then frame=joint.Attachment0.CFrame
   elseif joint:IsA('Motor6D')and not chosen[name]then frame=joint.C0 end
   if frame then chosen[name]={Joint=joint,Name=name,Property='Transform',Basis=frame.Rotation}end
  end
 end
 if chosen.Waist then chosen.RootJoint=nil end
 local result={};for _,entry in pairs(chosen)do table.insert(result,entry)end;return result
end
local function bind(tool)
 if not tool:IsA('Tool')or tool:GetAttribute('ChestChaseBat')~=true or bound[tool]then return end
 local links={};bound[tool]=links
 table.insert(links,tool.Activated:Connect(function()
  if tool.Parent==player.Character and tool.Enabled then remote:FireServer()end
 end))
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
end
local backpack=player:WaitForChild('Backpack')
local backpackLink=watch(backpack)
table.insert(connections,player.ChildAdded:Connect(function(child)
 if child:IsA('Backpack')and child~=backpack then
  backpackLink:Disconnect();backpack=child;backpackLink=watch(child)
 end
end))
table.insert(connections,player.CharacterAdded:Connect(characterAdded))
table.insert(connections,player.CharacterRemoving:Connect(function(character)restore(character);if characterLink then characterLink:Disconnect();characterLink=nil end end))
if player.Character then characterAdded(player.Character)end
table.insert(connections,remote.OnClientEvent:Connect(function(event)
 if type(event)~='table'or event.Kind~='Swing'or typeof(event.Character)~='Instance'
  or type(event.At)~='number'or workspace:GetServerTimeNow()-event.At>C.Windup+C.Recovery then return end
 local character=event.Character;local tool
 for _,item in ipairs(character:GetChildren())do if item:IsA('Tool')and item:GetAttribute('ChestChaseBat')then tool=item;break end end
 if not tool then return end
 local handle=tool:FindFirstChild('Handle');if not handle then return end
 restore(character)
 -- R150: a swing is heard even when it misses: the whoosh is timed so it meets the contact frame (At + Windup), and joins late like the pose does.
 local root=character:FindFirstChild('HumanoidRootPart');local camera=workspace.CurrentCamera
 if root and camera and (camera.CFrame.Position-root.Position).Magnitude<=C.SwingSoundRange then
  local wait=event.At+C.Windup-C.SwingSoundLead-workspace:GetServerTimeNow()
  local function whoosh()if root.Parent then Sfx.Play(Sfx.WhooshId,root.Position,C.SwingSoundVolume,C.SwingSoundPitch,2,wait<0 and-wait or 0)end end
  if wait>0 then task.delay(wait,whoosh)else whoosh()end
 end
 local entries=joints(character,handle);if #entries==0 then return end
 -- R112: Lead lets a late-arriving swing still show its full wind-back; R6 samples the one-piece arm.
 local hum=character:FindFirstChildOfClass('Humanoid')
 poses[character]={Tool=tool,Joints=entries,At=event.At,Lead=math.max(0,workspace:GetServerTimeNow()-event.At),
  R6=hum~=nil and hum.RigType==Enum.HumanoidRigType.R6};activateFrames()
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
 for character,p in pairs(poses)do
  local t=now-p.At;local hum=character:FindFirstChildOfClass('Humanoid')
  if not character.Parent or p.Tool.Parent~=character or not p.Tool.Enabled or not hum or hum.Health<=0
   or character:GetAttribute('ChestChaseRagdollActive')or t>=C.Windup+C.Recovery then restore(character)
  else
   for _,entry in ipairs(p.Joints)do if entry.Joint.Parent then
    local target,weight=Pose.Sample(entry.Name,t,p.Lead,p.R6)
    if entry.Property=='Transform'then
     resetJoint(entry);entry.Base=entry.Joint.Transform
     target=entry.Basis:Inverse()*target*entry.Basis
     entry.Written=entry.Base:Lerp(target,weight)
    else entry.Written=entry.Base*CFrame.new():Lerp(target,weight)end
    entry.Joint[entry.Property]=entry.Written
   end end
  end
 end
end)
end
script.Destroying:Connect(function()
 backpackLink:Disconnect()
 if characterLink then characterLink:Disconnect()end
 for _,link in ipairs(connections)do link:Disconnect()end
 for _,links in pairs(bound)do for _,link in ipairs(links)do link:Disconnect()end end
 for character in pairs(poses)do restore(character)end
end)
