local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local Core=require(RS.KeyboardCore142)
local Scene=require(RS.KeyboardScene142)
local Rig=require(RS.KeeperRigConfig)
local Upgrades=require(RS.KeeperUpgradeData)
local Pose=require(RS.BeastPose)
local Veiled=require(RS.VeiledKeeper81)
local Server={}
function Server.playerContacts(character)
 if not character or not character.Parent then return nil end
 local hum=character:FindFirstChildOfClass('Humanoid');local root=character:FindFirstChild('HumanoidRootPart')
 if not hum or hum.Health<=0 or not root then return nil end
 local height=hum.HipHeight+root.Size.Y/2
 if hum.RigType==Enum.HumanoidRigType.R6 then
  local leg=character:FindFirstChild('Left Leg');height+=(leg and leg.Size.Y or 2)
 end
 local at=root.Position-Vector3.new(0,height,0)
 local contacts={{X=at.X,Y=at.Y,Z=at.Z,RX=math.clamp(root.Size.X/2+.9,1.5,3),RZ=1.9}}
 for _,name in ipairs({'LeftFoot','RightFoot','Left Leg','Right Leg'})do
  local foot=character:FindFirstChild(name)
  if foot and foot:IsA('BasePart')then
   local p=foot.CFrame:PointToWorldSpace(Vector3.new(0,-foot.Size.Y/2,0))
   -- Do not let an animated leg down below an airborne root keep a key held.
   if math.abs(p.Y-at.Y)<.8 then contacts[#contacts+1]={X=p.X,Y=p.Y,Z=p.Z,RX=foot.Size.X/2+.25,RZ=foot.Size.Z/2+.25}end
  end
 end
 return contacts
end
function Server.keeperContacts(model,now)
 if not model or not model.Parent or not model.PrimaryPart then return nil end
 local root=model.PrimaryPart;local stage=model:GetAttribute('Stage')
 local contacts={}
 if model:GetAttribute('VeiledKeeper81')then
  local frames=Veiled.Frames(model,now)
  if frames then for _,name in ipairs({'LFoot','RFoot'})do
   local cf=frames[name]
   if cf then local p=cf:PointToWorldSpace(Vector3.new(0,-.35,0));contacts[#contacts+1]={X=p.X,Y=p.Y,Z=p.Z,RX=.9,RZ=1.5}end
  end end
  -- Its sleeping pose rests on torso/hands, with support plane defined by E:Spawn floorY+5.
  if model:GetAttribute('GuardianBehavior')=='GUARDING'or model:GetAttribute('GuardianBehavior')=='SLEEPING'then
   local p=root.Position-Vector3.new(0,5,0);contacts[#contacts+1]={X=p.X,Y=p.Y,Z=p.Z,RX=2.8,RZ=3.2}
  end
  return contacts
 end
 local rig=Upgrades[stage]or Rig[stage]
 if not rig then return nil end
 local sleeping=model:GetAttribute('GuardianBehavior')=='GUARDING'or model:GetAttribute('GuardianBehavior')=='SLEEPING'
 local moving=model:GetAttribute('KeeperTravelSpeed')or 0
 local frames=Pose.Frames(stage,now,sleeping and 0 or 1,moving>0 and 1 or 0,now*math.pi*4,0,moving,0)
 -- Actual approved rig support hulls, transformed from CURRENT authoritative root. No cosmetic bounding box.
 for group,samples in pairs(rig.FloorSamples)do
  local f=frames[group]
  if f then
   local points={};local lowest=math.huge
   for _,sample in ipairs(samples)do local p=(root.CFrame*f):PointToWorldSpace(Vector3.new(table.unpack(sample)));points[#points+1]=p;lowest=math.min(lowest,p.Y)end
   local lx,hx,lz,hz=math.huge,-math.huge,math.huge,-math.huge
   for _,p in ipairs(points)do if p.Y<=lowest+.25 then lx=math.min(lx,p.X);hx=math.max(hx,p.X);lz=math.min(lz,p.Z);hz=math.max(hz,p.Z)end end
   if lx~=math.huge then contacts[#contacts+1]={X=(lx+hx)/2,Y=lowest,Z=(lz+hz)/2,RX=math.min(6,(hx-lx)/2+.2),RZ=math.min(6,(hz-lz)/2+.2)}end
  end
 end
 return contacts
end
function Server.actors(map,chase)
 local models={};local result={}
 for _,player in ipairs(Players:GetPlayers())do
  local model=player.Character;local c=Server.playerContacts(model)
  if c then models[model]=true;result[model]=c end
 end
 local function keeper(model)
  if model and not models[model]then models[model]=true;local c=Server.keeperContacts(model,workspace:GetServerTimeNow());if c then result[model]=c end end
 end
 for _,model in pairs(map.GuardiansByStage or{})do keeper(model)end
 for _,run in pairs(chase.Runs or{})do keeper(run.Chaser)end
 for _,record in pairs(chase.ReturningGuardians or{})do keeper(record.Guardian)end
 if chase.Event81 then keeper(chase.Event81.Guardian)end
 return result
end
function Server.step(state,rows,actors,previous)
 local contacts={}
 for actor,points in pairs(actors)do
  local keys={};contacts[actor]=keys
  for i,p in ipairs(points)do
   local function add(c)Scene.contact(rows,Vector3.new(c.X,c.Y,c.Z),c.RX,c.RZ,keys)end
   add(p)
   if previous[actor]and previous[actor][i]then Core.sweep(previous[actor][i],p,add)end
  end
 end
 local changes,sequence=Core.replace(state,contacts)
 return changes,sequence,actors
end
function Server.Start(map,chase)
 assert(not map.Keyboard142,'R142 already started')
 local rows=Scene.describe(map.MapRoot)
 assert(#rows>=14,'R142 missing track/base surfaces')
 for _,row in ipairs(rows)do row.Part.Color=Scene.Backing;row.Part.Material=Enum.Material.SmoothPlastic end
 local remote=RS:WaitForChild('Keyboard142State')
 local state=Core.new();local previous={};local readyAt={}
 local service={Rows=rows,State=state};map.Keyboard142=service
 local function descriptions()
  local result={}
  for i,r in ipairs(rows)do result[i]={Id=r.Id,Frame=r.Frame,Grid=r.Grid,Stage=r.Stage,Enabled=r.Enabled}end
  return result
 end
 local function snapshot(player)
  local held,sequence=Core.snapshot(state)
  remote:FireClient(player,'Snapshot',sequence,held,descriptions())
 end
 remote.OnServerEvent:Connect(function(player,command)
  if command~='Ready'or (readyAt[player]and os.clock()-readyAt[player]<1)then return end
  readyAt[player]=os.clock();snapshot(player)
 end)
 Players.PlayerRemoving:Connect(function(player)readyAt[player]=nil end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<Core.Tick then return end;elapsed=0
  local geometryChanged=false
  for _,r in ipairs(rows)do
   local enabled=r.Part.Parent~=nil
   if r.Enabled~=enabled then r.Enabled=enabled;geometryChanged=true end
   if enabled then
    local f=r.Part.CFrame*CFrame.new(0,r.Part.Size.Y/2,0)
    if f~=r.Frame or r.Part.Size.X~=r.Grid.X or r.Part.Size.Z~=r.Grid.Z then r.Frame=f;r.Grid=Core.grid(r.Part.Size.X,r.Part.Size.Z);geometryChanged=true end
   end
  end
  if geometryChanged then previous={}end
  local changes,sequence,nextPrevious=Server.step(state,rows,Server.actors(map,chase),previous);previous=nextPrevious
  if geometryChanged then state.Sequence+=1;local held,seq=Core.snapshot(state);remote:FireAllClients('Snapshot',seq,held,descriptions())
  elseif #changes>0 then remote:FireAllClients('Delta',sequence,changes)end
 end)
 return service
end
return Server
