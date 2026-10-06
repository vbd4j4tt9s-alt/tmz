-- R122: shovel holes on the biome track (server-authoritative). Limits and look live in ReplicatedStorage.TrackHoleConfig.
-- Client (TrackHoleClient) sends only an optional aim point; the server picks the shovel, ground, spacing and owner.
-- A carrier who steps on an armed hole is ragdolled through the chase service's own Ragdoll and drops the pack
-- through its public Finish(false,true,run,hit) - the same drop/return path a keeper or bat hit uses.
-- R153: the catch is SWEPT. Every Heartbeat the whole path of a carrier since the last step (previous root -> root now) is tested against each armed
-- hole's pit circle (flat) and the height band, so a step of 5,000+ studs cannot skip a hole. Only a teleport (MovementGuard.Reset / a correction bumps
-- the player's MovementResetSerial), a new run or a new character starts a fresh path.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local RS=game:GetService('ReplicatedStorage')
local C=require(RS:WaitForChild('TrackHoleConfig'))
local Gate=require(script.Parent.SecurityGate)
local V3=Vector3.new
local S={};S.__index=S

local SOIL_PIT=Color3.fromRGB(46,29,17)
local SOIL_RIM=Color3.fromRGB(92,60,35)
local CRUMBS={Color3.fromRGB(104,69,41),Color3.fromRGB(86,56,33),Color3.fromRGB(121,83,52)}

local function flat(v)return V3(v.X,0,v.Z)end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<1e6 end

function S.new(config,map,chase,notifications)
 local self=setmetatable({Config=config,Map=map,Chase=chase,Notifications=notifications,
  Holes={},Count=0,ByOwner={},NextDig={},Serial=0,Connections={},Random=Random.new(),Grounds=nil},S)
 local remotes=RS:FindFirstChild('ChestChaseRemotes')or(chase.RunAlertRemote and chase.RunAlertRemote.Parent)
 assert(remotes,'TrackHoleService needs ReplicatedStorage.ChestChaseRemotes')
 local remote=remotes:FindFirstChild('TrackHole')or Instance.new('RemoteEvent')
 assert(remote:IsA('RemoteEvent'),'TrackHole must be a RemoteEvent');remote.Name='TrackHole';remote.Parent=remotes
 self.Remote=remote
 local folder=Instance.new('Folder');folder.Name='TrackHoles';folder.Parent=map.RuntimeFolder or map.MapRoot
 self.Folder=folder
 return self
end

function S:Now()return os.clock()end
function S:Raycast(origin,direction,params)return workspace:Raycast(origin,direction,params)end

-- Biome ground parts (BiomeGround_N, including R83 stretched copies); rebuilt if any is gone.
function S:_grounds()
 local list=self.Grounds
 if list then for _,p in ipairs(list)do if not p.Parent then list=nil;break end end end
 if not list then
  list={}
  for _,p in ipairs(self.Map.MapRoot:GetDescendants())do
   if p:IsA('BasePart')and p.Name:match('^BiomeGround_%d')then list[#list+1]=p end
  end
  self.Grounds=list
 end
 return list
end

-- The walkable top surface at (x,z), only if it is the biome track ground (or a thin flat overlay on it).
function S:_groundAt(point)
 local origin=V3(point.X,point.Y+6,point.Z);local down=V3(0,-16,0)
 local include=RaycastParams.new();include.FilterType=Enum.RaycastFilterType.Include
 include.FilterDescendantsInstances=self:_grounds();include.IgnoreWater=true
 local ground=self:Raycast(origin,down,include)
 if not ground or ground.Normal.Y<.95 then return nil end
 local excluded={self.Folder}
 for _,p in ipairs(Players:GetPlayers())do if p.Character then excluded[#excluded+1]=p.Character end end
 local exclude=RaycastParams.new();exclude.FilterType=Enum.RaycastFilterType.Exclude
 exclude.FilterDescendantsInstances=excluded;exclude.IgnoreWater=true;exclude.RespectCanCollide=true
 local surface=self:Raycast(origin,down,exclude)
 if not surface or surface.Normal.Y<.95 or math.abs(surface.Position.Y-ground.Position.Y)>C.SurfaceTolerance then return nil end
 if surface.Instance and surface.Instance.Name=='GuardianCampPatch'then return nil end
 return V3(point.X,surface.Position.Y,point.Z)
end

function S:_onTrack(position,margin)
 local line=self.Map.BaseBoundaryLine
 return self.Map:IsInsideBiomeTrack(position)and position.Z>line.Position.Z+(margin or 0)
end

function S:_character(player)
 if not player or not player.Parent then return nil end
 local character=player.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
 if not humanoid or not root or humanoid.Health<=0 then return nil end
 return character,humanoid,root
end

function S:_carrying(player)
 local chase=self.Chase
 return (chase.Runs and chase.Runs[player]~=nil)or(chase.Starting and chase.Starting[player]==true)
  or player:GetAttribute('ChestChaseSeedCarrying')==true or player:GetAttribute('ChestChaseRunActive')==true
  or player:GetAttribute('ChestChaseQueued')==true
end

function S:_downed(player)
 local ragdoll=self.Chase.Ragdoll
 return player:GetAttribute('GuardianRagdollActive')==true or player:GetAttribute('GuardianFlingActive')==true
  or (ragdoll~=nil and ragdoll.Records~=nil and ragdoll.Records[player]~=nil)
end

-- R150: the refusals (cooldown, can't dig here / now) click the Denied cue on the client; 'Covered', 'Trapped' and 'Tripped' are news, not refusals.
local DENIED={Cooldown=true,Carrying=true,Refreshing=true,Ground=true,Pack=true,Camp=true,Entrance=true,Spacing=true,PlayerCap=true,ServerCap=true}
function S:_tell(player,key,...)
 local text=C.Messages[key];if not text then return end
 if select('#',...)>0 then text=string.format(text,...)end
 if self.Notifications then self.Notifications:Show(player,text,Color3.fromRGB(255,187,91),2,DENIED[key]and'Denied'or nil)end
end

function S:_campHomes()
 local homes={};local chase=self.Chase
 for stage in pairs(self.Map.GuardiansByStage or{})do
  local ok,frame=pcall(function()return chase:_getGuardianHomeCFrame(stage)end)
  if ok and typeof(frame)=='CFrame'then homes[#homes+1]=frame.Position end
 end
 for _,frame in pairs(chase.GuardianHomeCFrames or{})do if typeof(frame)=='CFrame'then homes[#homes+1]=frame.Position end end
 -- The Darkened (Event81) sits at its own home, not in GuardianHomeCFrames.
 local event=chase.Event81
 if event and event.Home and(event.Active==nil or event:Active())then homes[#homes+1]=event.Home.Position end
 return homes
end

-- nil = fine, else a message key.
function S:_spotProblem(point)
 if not self:_onTrack(point,C.EntranceClearance)then
  return self:_onTrack(point)and'Entrance'or'Ground'
 end
 for _,seed in ipairs(self.Map.Chests or{})do
  local body=seed.Body
  if body and body.Parent and flat(body.Position-point).Magnitude<C.PackClearance then return'Pack'end
 end
 local event=self.Chase.Event81
 for _,slot in ipairs(event and event.Slots or{})do
  local at=slot.PackHome or(slot.Body and slot.Body.Position)
  if not slot.Stolen and typeof(at)=='Vector3'and flat(at-point).Magnitude<C.PackClearance then return'Pack'end
 end
 for _,drop in pairs(self.Chase.Drops or{})do
  if typeof(drop.Position)=='Vector3'and flat(drop.Position-point).Magnitude<C.PackClearance then return'Pack'end
 end
 for _,home in ipairs(self:_campHomes())do
  if flat(home-point).Magnitude<C.KeeperCampClearance then return'Camp'end
 end
 for _,hole in pairs(self.Holes)do
  if flat(hole.Position-point).Magnitude<C.MinSpacing then return'Spacing'end
 end
 return nil
end

function S:_ownedNear(player,point)
 local best,bestDistance
 for _,hole in pairs(self.ByOwner[player]or{})do
  local d=flat(hole.Position-point).Magnitude
  if d<=C.Diameter/2+C.CoverSnap and(not bestDistance or d<bestDistance)then best,bestDistance=hole,d end
 end
 return best
end

-- Visual: a flat dark circle with a lighter rim and dirt crumbs. No terrain change, no collision, no queries.
function S:_build(hole)
 local model=Instance.new('Model');model.Name='TrackHole_'..hole.Id
 local function part(name,size,cframe,color,material,round)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=cframe;p.Color=color;p.Material=material
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if round then p.Shape=Enum.PartType.Cylinder end;p.Parent=model;return p
 end
 local at=hole.Position;local lay=CFrame.Angles(0,0,math.pi/2) -- cylinder axis X -> up
 local rimD=C.Diameter+C.RimWidth*2
 -- R149: the rim is thinner than the pit so the pit's top stands above the rim's (.02 flickered far away). R153: the hole is 5.1 across, so it is seen from up to
 -- 300 studs where 4 depth steps are .043: rim top .05 over the floor, pit top .10 (was .04 / .08), every step between the layers > .043.
 part('Rim',V3(.05,rimD,rimD),CFrame.new(at+V3(0,.025,0))*lay,SOIL_RIM,Enum.Material.Ground,true)
 local pit=part('Pit',V3(.10,C.Diameter,C.Diameter),CFrame.new(at+V3(0,.05,0))*lay,SOIL_PIT,Enum.Material.SmoothPlastic,true)
 local rng=self.Random
 for i=1,C.CrumbCount do
  local angle=(i/C.CrumbCount)*math.pi*2+rng:NextNumber(-.3,.3)
  local radius=rimD/2+rng:NextNumber(.1,1.1);local size=rng:NextNumber(.22,.5)
  local spot=at+V3(math.cos(angle)*radius,size*.35,math.sin(angle)*radius)
  part('Crumb',V3(size,size*rng:NextNumber(.6,1),size),CFrame.new(spot)*CFrame.Angles(rng:NextNumber(-.4,.4),rng:NextNumber(0,math.pi*2),rng:NextNumber(-.4,.4)),
   CRUMBS[(i%#CRUMBS)+1],Enum.Material.Ground)
 end
 model.PrimaryPart=pit
 model:SetAttribute('TrackHoleId',hole.Id);model:SetAttribute('OwnerUserId',hole.Owner.UserId)
 model:SetAttribute('ArmedAtServer',workspace:GetServerTimeNow()+C.ArmSeconds)
 model.Parent=self.Folder
 return model
end

function S:_fx(kind,hole,extra)
 local payload={Kind=kind,Id=hole.Id,Position=hole.Position,OwnerUserId=hole.Owner.UserId}
 if extra then for k,v in pairs(extra)do payload[k]=v end end
 self.Remote:FireAllClients(payload)
end

function S:_remove(hole,reason)
 if not hole or self.Holes[hole.Id]~=hole then return false end
 self.Holes[hole.Id]=nil;self.Count-=1
 local mine=self.ByOwner[hole.Owner];if mine then mine[hole.Id]=nil end
 if hole.Model and hole.Model.Parent then hole.Model:Destroy()end
 if reason=='Covered'then self:_fx('Cover',hole)end
 return true
end

function S:OwnedCount(player)
 local n=0;for _ in pairs(self.ByOwner[player]or{})do n+=1 end;return n
end

-- Remote entry. aim: optional Vector3 the player clicked/tapped. Returns ok, reason (tests and logs only).
function S:Request(player,aim)
 if not Gate.Allow(player,C.RemoteRoute,aim)then return false,'Rate'end
 if aim~=nil and(typeof(aim)~='Vector3'or not finite(aim.X)or not finite(aim.Y)or not finite(aim.Z))then return false,'Args'end
 local character,humanoid,root=self:_character(player)
 if not character or root.Anchored or humanoid.PlatformStand then return false,'Character'end
 local tool=character:FindFirstChildOfClass('Tool')
 if not tool or tool:GetAttribute('GardenShovel')~=true or not tool.Enabled then return false,'Shovel'end
 -- Off the track the shovel keeps only its garden behaviour; nothing to say.
 if not self:_onTrack(root.Position)then return false,'OffTrack'end
 if self.Map.Refreshing then self:_tell(player,'Refreshing');return false,'Refreshing'end
 if self:_downed(player)then return false,'Downed'end
 if self:_carrying(player)then self:_tell(player,'Carrying');return false,'Carrying'end
 local point=aim or root.Position
 if flat(point-root.Position).Magnitude>C.DigRange or math.abs(point.Y-root.Position.Y)>C.DigRange then
  point=root.Position -- a far/forged aim digs at your feet instead
 end
 local own=self:_ownedNear(player,point)
 if own then self:_remove(own,'Covered');self:_tell(player,'Covered');return true,'Covered'end
 local now=self:Now()
 local ready=self.NextDig[player]or 0
 if now<ready then self:_tell(player,'Cooldown',math.ceil(ready-now));return false,'Cooldown'end
 local ground=self:_groundAt(point)
 if not ground then self:_tell(player,'Ground');return false,'Ground'end
 local problem=self:_spotProblem(ground)
 if problem then self:_tell(player,problem);return false,problem end
 if self:OwnedCount(player)>=C.MaxPerPlayer then self:_tell(player,'PlayerCap',C.MaxPerPlayer);return false,'PlayerCap'end
 if self.Count>=C.MaxPerServer then self:_tell(player,'ServerCap');return false,'ServerCap'end
 self.Serial+=1
 local hole={Id=self.Serial,Owner=player,Position=ground,DugAt=now,ArmedAt=now+C.ArmSeconds,ExpiresAt=now+C.LifetimeSeconds}
 hole.Model=self:_build(hole)
 self.Holes[hole.Id]=hole;self.Count+=1
 self.ByOwner[player]=self.ByOwner[player]or{};self.ByOwner[player][hole.Id]=hole
 self.NextDig[player]=now+C.CooldownSeconds
 self:_fx('Dig',hole,{Character=character})
 return true,'Dug'
end

function S:_tutorialSafe(player)
 if player:GetAttribute('TutorialDone')==true then return false end
 return C.TutorialSafeSteps[tonumber(player:GetAttribute('TutorialStep'))or 0]==true
end

-- R153: the path a -> b (one step, any length) against the pit circle (cx,cz,r) on the ground plane and the height band [cy+dyMin, cy+dyMax] on
-- the root's height (it varies linearly along the step). Exact: no sampling, no .Touched. Returns the middle of the part of the path that is inside the
-- pit and inside the band as t (0 = a, 1 = b), and t where it first goes in; nil when the path never is. Pure numbers (no Vector3 per step).
function S.Cross(ax,ay,az,bx,by,bz,cx,cy,cz,r,dyMin,dyMax)
 local dx,dz=bx-ax,bz-az;local fx,fz=ax-cx,az-cz
 local t0,t1=0,1;local len2=dx*dx+dz*dz
 if len2<1e-8 then -- standing still
  if fx*fx+fz*fz>r*r then return nil end
 else
  local len=math.sqrt(len2);local ux,uz=dx/len,dz/len
  local perp=fx*uz-fz*ux                      -- flat distance from the centre to the infinite line
  if perp>r or perp<-r then return nil end
  local along=-(fx*ux+fz*uz);local half=math.sqrt(r*r-perp*perp)
  local s0,s1=along-half,along+half            -- the chord, in studs from a
  if s1<0 or s0>len then return nil end
  t0,t1=math.max(s0,0)/len,math.min(s1,len)/len
 end
 local dy=by-ay;local lo,hi=cy+dyMin,cy+dyMax
 if dy<1e-9 and dy>-1e-9 then
  if ay<lo or ay>hi then return nil end
 else
  local u0,u1=(lo-ay)/dy,(hi-ay)/dy;if u0>u1 then u0,u1=u1,u0 end
  t0,t1=math.max(t0,u0),math.min(t1,u1)
  if t0>t1 then return nil end
 end
 return (t0+t1)*.5,t0
end

-- at: where the fall happens (nil = the root where it is). A carrier faster than the pit is wide is already past it when the server sees him:
-- he is put back in the middle of the part of his path inside the pit, so he falls IN the hole (and the pack drops there), at any speed.
function S:_trap(player,run,hole,root,at)
 local chase=self.Chase
 if run.Finishing or chase.Runs[player]~=run or self.Map.Refreshing or not chase.Ragdoll:CanHit(player)then return false end
 self:_remove(hole,'Trap') -- reserve: one hole traps one carrier
 local here=root.Position
 if at and flat(here-hole.Position).Magnitude>C.Diameter/2 then
  local ok=pcall(function()local c=player.Character;c:PivotTo(CFrame.new(at)*root.CFrame.Rotation*root.CFrame:Inverse()*c:GetPivot())end)
  if ok then pcall(function()require(script.Parent.MovementGuard).Reset(player)end)end -- a server move: the client resyncs, the speed check restarts
 end
 local motion=flat(root.AssemblyLinearVelocity or Vector3.zero)
 local direction=motion.Magnitude>1 and motion.Unit or flat(root.CFrame.LookVector)
 direction=direction.Magnitude>.01 and direction.Unit or V3(0,0,-1)
 chase.Ragdoll:Apply(player,direction*C.FallHorizontal+V3(0,C.FallVertical,0),'Hole',C.RagdollSeconds)
 -- Same drop/return path as a keeper or bat hit; ImpactApplied skips the keeper fling.
 chase:Finish(false,true,run,{Cause='Hole',ImpactApplied=true})
 self:_tell(player,'Trapped')
 if hole.Owner~=player and hole.Owner.Parent then self:_tell(hole.Owner,'Tripped',player.DisplayName or player.Name)end
 self:_fx('Trap',hole,{VictimUserId=player.UserId})
 return true
end

function S:Step()
 local now=self:Now()
 if self.Map.Refreshing and self.Count>0 then self:ClearAll()end
 for _,hole in pairs(self.Holes)do
  if now>=hole.ExpiresAt or not hole.Owner.Parent then self:_remove(hole,'Expired')end
 end
 self.Last=self.Last or setmetatable({},{__mode='k'})
 local last=self.Last
 if self.Count==0 then table.clear(last);return end
 local radius=C.Diameter/2;local dyMin,dyMax=C.TrapHeightMin,C.TrapHeightMax
 self.StepId=(self.StepId or 0)+1;local stamp=self.StepId
 for player,run in pairs(self.Chase.Runs or{})do
  local character,_,root=self:_character(player)
  if character and run.Character==character and not run.Finishing then
   local here=root.Position;local hx,hy,hz=here.X,here.Y,here.Z
   local rec=last[player]
   if not rec then rec={};last[player]=rec end
   rec.Stamp=stamp
   -- A position that is not a number (NaN / inf) is ignored; the path goes on from the last good one.
   if finite(hx)and finite(hy)and finite(hz)then
    -- The path starts where the last step ended: same run, same character, no teleport (MovementResetSerial) in between. Otherwise only here.
    local serial=player:GetAttribute('MovementResetSerial')
    local ax,ay,az=hx,hy,hz
    if rec.Run==run and rec.Character==character and rec.Serial==serial and rec.X then ax,ay,az=rec.X,rec.Y,rec.Z end
    rec.Run,rec.Character,rec.Serial,rec.X,rec.Y,rec.Z=run,character,serial,hx,hy,hz
    if not self:_tutorialSafe(player)then
     -- spatial early-out: the box of the path against the box of each pit; the first hole the path goes into is the one that traps
     local loX,hiX=math.min(ax,hx)-radius,math.max(ax,hx)+radius
     local loZ,hiZ=math.min(az,hz)-radius,math.max(az,hz)+radius
     local best,bestMid,bestIn
     for _,hole in pairs(self.Holes)do
      local at=hole.Position
      if hole.Owner~=player and now>=hole.ArmedAt and at.X>=loX and at.X<=hiX and at.Z>=loZ and at.Z<=hiZ then
       local mid,enter=S.Cross(ax,ay,az,hx,hy,hz,at.X,at.Y,at.Z,radius,dyMin,dyMax)
       if mid and(not bestIn or enter<bestIn)then best,bestMid,bestIn=hole,mid,enter end
      end
     end
     if best then self:_trap(player,run,best,root,V3(ax+(hx-ax)*bestMid,ay+(hy-ay)*bestMid,az+(hz-az)*bestMid))end
    end
   end
  end
 end
 for player,rec in pairs(last)do if rec.Stamp~=stamp then last[player]=nil end end -- not carrying any more: the next run starts a new path
end

function S:ClearAll()
 local all={};for _,hole in pairs(self.Holes)do all[#all+1]=hole end
 for _,hole in ipairs(all)do self:_remove(hole,'Refresh')end
end

function S:CleanupPlayer(player)
 for _,hole in pairs(self.ByOwner[player]or{})do self:_remove(hole,'Left')end
 self.ByOwner[player]=nil;self.NextDig[player]=nil
 if self.Last then self.Last[player]=nil end
end

function S:Start()
 if self.Started then return end;self.Started=true
 table.insert(self.Connections,self.Remote.OnServerEvent:Connect(function(player,aim)
  local ok,err=pcall(self.Request,self,player,aim)
  if not ok then warn('[R122 holes] Dig request failed: '..tostring(err))end
 end))
 local root=self.Map.MapRoot
 table.insert(self.Connections,root:GetAttributeChangedSignal('BiomesRefreshing'):Connect(function()
  if root:GetAttribute('BiomesRefreshing')==true then self:ClearAll()end
 end))
 table.insert(self.Connections,RunService.Heartbeat:Connect(function()
  local ok,err=pcall(self.Step,self)
  if not ok then warn('[R122 holes] Step failed: '..tostring(err))end
 end))
end

return S
