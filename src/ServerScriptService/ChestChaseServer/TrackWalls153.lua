-- R153 track walls (owner: "there are also some issues with being able to stand on track walls if flung up high enough fix that so u cant stand on track walls").
-- What was wrong: the track's side walls (Obby.BiomeWalls, 5 thick, 48 tall: top at Y 51) sit at |x| 89 - 94, but the saved invisible barriers that were meant to
-- crown them (InvisibleMapBarriersV071, raised to 1024 tall by MapService) sit at |x| 90 - 95: a 1-stud strip of every wall top, the inner one, is open sky. A keeper
-- launch goes up 110 - 200 studs/s (peak 31 - 102 studs over the launch point, i.e. up to Y ~ 109: well over the wall top), and the game's runner sweep (RunnerSweep, a
-- Blockcast hull) puts a body that is steered against the barrier's face with its centre at |x| ~ 89.1: over that strip. It lands there and the Humanoid's floor ray finds
-- the wall top: the player stands, and runs, on the wall.
-- The fix (built once at start-up by MapService.new, after every pass that moves a wall):
--  1. BLOCKERS: for every wall part under Obby.BiomeWalls, one invisible, anchored, colliding slab standing on it: its inner face flush with the wall's (0.02 proud, so a
--     seam can never leave a ledge), reaching 3 studs past the wall's outer face, from 6 studs inside the wall (hidden) up to 1000 studs over its top. Nothing of it lies
--     below the wall top - 6 or on the track side of the wall's face, so the track, the keepers, packs, holes, keys, the refresh barrier and the gate are untouched; nothing
--     stands over the wall top and nothing can reach the blockers' own top (1051; the highest fling peaks at ~109). One part per wall (15 parts), a Persistent model (always
--     present on every client under StreamingEnabled, never streamed out). Transparency 1, CastShadow off, CanTouch off: never drawn, no Touched events. CanQuery stays ON, like
--     the game's other invisible colliders (FloorSafety86, RefreshBarrier, the garden ramps): the runner's hull sweeps and the server's guard only see colliders they can query, and
--     must stop at the same face the physics does. The Roblox camera ignores a part that is fully transparent, so it never zooms in on them.
--  2. FALLBACK (M.Start): a body that RESTS (|vertical speed| <= 2.5) inside a blocker's volume or on the wall top, on two samples in a row (0.25 s apart), is moved straight
--     back onto the track (6 studs in from the wall's face), keeping its height, so it falls to the floor. A flung body passes through at speed and is never touched.
--     Four checks a second, no per-frame work; owner test flying / noclip is left alone.
-- Pure geometry lives in M.Plan / M.Inspect / M.Landing (numbers only, unit-tested).
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local M={Version=153,Name='TrackWallBlockers153',Zones={},Seen=setmetatable({},{__mode='k'}),Rescues=0}
local V,CF=Vector3.new,CFrame.new
M.Settings={
 Reach=1000,        -- studs the blocker stands over the wall top (the highest fling peaks ~109 over the floor, 58 over the wall top)
 Sink=6,            -- studs it reaches down into the wall (never seen: inside the wall)
 Outer=3,           -- studs past the wall's outer face
 Lip=.02,           -- the inner face stands this far on the track side of the wall's inner face
 Overlap=.5,        -- studs it reaches along the wall past a joint with the next wall
 Seam=1,            -- walls closer than this (inner faces, ends) are one wall
 MaxLength=2000,    -- a part may not exceed 2048 studs
 MaxThickness=12,   -- a wall is thinner than this on its thin axis
 -- the fallback
 Interval=.25,      -- seconds between two looks at the players
 RestSpeed=2.5,     -- studs/s: slower than this vertically counts as resting
 InnerMargin=1.5,   -- studs on the track side of the wall's face that count as "on the wall" (a body resting at the face above the top)
 Landing=6,         -- studs in from the wall's inner face where a rescued body is put
}
-- Pure geometry ------------------------------------------------------------------------------------------------------------------------------------
-- walls: list of {Name,CX,CY,CZ,HX,HY,HZ} (centre and half extents of each wall's world box). Returns {Blockers={{Name,Wall,Cx,Cy,Cz,Sx,Sy,Sz}},Zones={...}}.
function M.Plan(walls,cfg)
 cfg=cfg or M.Settings
 local out={Blockers={},Zones={}}
 local n=#walls;if n==0 then return out end
 local mx,mz=0,0
 for _,w in ipairs(walls)do mx+=w.CX;mz+=w.CZ end
 mx/=n;mz/=n
 local recs={}
 for _,w in ipairs(walls)do
  local alongZ=w.HX<=w.HZ -- thin along X: a side wall running along Z (else the end wall, running along X)
  local half=alongZ and w.HX or w.HZ
  if half*2<=cfg.MaxThickness then
   local mid=alongZ and w.CX or w.CZ
   local sign=mid>=(alongZ and mx or mz) and 1 or -1 -- which way is "outside": away from the middle of the walls
   local c=alongZ and w.CZ or w.CX;local h=alongZ and w.HZ or w.HX
   recs[#recs+1]={Wall=w,AlongZ=alongZ,Sign=sign,Inner=mid-sign*half,OuterFace=mid+sign*half,Lo=c-h,Hi=c+h,Top=w.CY+w.HY}
  end
 end
 local function joins(a,b,atHi)
  if a==b or a.AlongZ~=b.AlongZ or a.Sign~=b.Sign or math.abs(a.Inner-b.Inner)>cfg.Seam then return false end
  if atHi then return math.abs(b.Lo-a.Hi)<=cfg.Seam end
  return math.abs(b.Hi-a.Lo)<=cfg.Seam
 end
 for _,r in ipairs(recs)do
  local lo,hi=r.Lo,r.Hi
  for _,o in ipairs(recs)do
   if joins(r,o,false)then lo-=cfg.Overlap end
   if joins(r,o,true)then hi+=cfg.Overlap end
  end
  local tin=r.Inner-r.Sign*cfg.Lip;local tout=r.OuterFace+r.Sign*cfg.Outer
  local t0,t1=math.min(tin,tout),math.max(tin,tout)
  local y0,y1=r.Top-cfg.Sink,r.Top+cfg.Reach
  local count=math.max(1,math.ceil((hi-lo)/cfg.MaxLength));local span=(hi-lo)/count
  for k=1,count do
   local a=lo+(k-1)*span-(k>1 and cfg.Overlap or 0);local b=lo+k*span+(k<count and cfg.Overlap or 0)
   local tc,lc=(t0+t1)/2,(a+b)/2;local ts,ls=t1-t0,b-a
   local blocker={Name='TrackWallBlocker153 '..r.Wall.Name..(count>1 and(' '..k)or''),Wall=r.Wall.Name,Cy=(y0+y1)/2,Sy=y1-y0}
   if r.AlongZ then blocker.Cx,blocker.Cz,blocker.Sx,blocker.Sz=tc,lc,ts,ls else blocker.Cx,blocker.Cz,blocker.Sx,blocker.Sz=lc,tc,ls,ts end
   out.Blockers[#out.Blockers+1]=blocker
  end
  local z0,z1=r.Inner-r.Sign*cfg.InnerMargin,r.OuterFace+r.Sign*(cfg.Outer+2)
  out.Zones[#out.Zones+1]={Name=r.Wall.Name,AlongZ=r.AlongZ,Sign=r.Sign,Inner=r.Inner,T0=math.min(z0,z1),T1=math.max(z0,z1),L0=r.Lo,L1=r.Hi,Y0=r.Top-1.5,Y1=r.Top+cfg.Reach}
 end
 return out
end
-- The zone a body at (x,y,z) with vertical speed vy rests in (inside a blocker's volume or on / at the wall top), or nil.
function M.Inspect(x,y,z,vy,zones,cfg)
 cfg=cfg or M.Settings
 if math.abs(vy)>cfg.RestSpeed then return nil end
 for _,zone in ipairs(zones)do
  if y>=zone.Y0 and y<=zone.Y1 then
   local t,l=zone.AlongZ and x or z,zone.AlongZ and z or x
   if t>=zone.T0 and t<=zone.T1 and l>=zone.L0 and l<=zone.L1 then return zone end
  end
 end
 return nil
end
-- Where a rescued body goes: Landing studs in from the zone's wall face, same height and place along the wall.
function M.Landing(zone,x,y,z,cfg)
 cfg=cfg or M.Settings
 local t=zone.Inner-zone.Sign*cfg.Landing
 if zone.AlongZ then return t,y,z end
 return x,y,t
end
-- World ----------------------------------------------------------------------------------------------------------------------------------------------------
function M.Measure(map)
 local obby=map and map:FindFirstChild('Obby');local folder=obby and obby:FindFirstChild('BiomeWalls')
 local list={}
 if folder then for _,p in ipairs(folder:GetChildren())do
  if p:IsA('BasePart')and p.CanCollide~=false then
   local cf,s=p.CFrame,p.Size;local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector;local pos=cf.Position
   list[#list+1]={Name=p.Name,CX=pos.X,CY=pos.Y,CZ=pos.Z,
    HX=(math.abs(r.X)*s.X+math.abs(u.X)*s.Y+math.abs(l.X)*s.Z)/2,
    HY=(math.abs(r.Y)*s.X+math.abs(u.Y)*s.Y+math.abs(l.Y)*s.Z)/2,
    HZ=(math.abs(r.Z)*s.X+math.abs(u.Z)*s.Y+math.abs(l.Z)*s.Z)/2}
  end
 end end
 table.sort(list,function(a,b)return a.Name<b.Name end)
 return list
end
-- Builds the blockers for the walls now in `map` (replacing an earlier set) and keeps the zones for the fallback. Returns the model (nil: no walls found).
function M.Apply(map)
 local old=map:FindFirstChild(M.Name);if old then old:Destroy()end
 local plan=M.Plan(M.Measure(map))
 M.Zones=plan.Zones
 if #plan.Blockers==0 then warn('[R153] No track walls found: no wall blockers were built.');return nil end
 local model=Instance.new('Model');model.Name=M.Name;model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 for _,b in ipairs(plan.Blockers)do
  local p=Instance.new('Part');p.Name=b.Name
  p.Anchored=true;p.CanCollide=true;p.CanTouch=false;p.CanQuery=true;p.CastShadow=false;p.Transparency=1;p.Material=Enum.Material.SmoothPlastic
  p.Size=V(b.Sx,b.Sy,b.Sz);p.CFrame=CF(b.Cx,b.Cy,b.Cz)
  p:SetAttribute('Wall',b.Wall)
  p.Parent=model
 end
 model:SetAttribute('Version',M.Version)
 model.Parent=map
 return model,plan
end
-- The fallback ---------------------------------------------------------------------------------------------------------------------------------------
function M.Rescue(player,character,root,zone)
 local p=root.Position
 local nx,ny,nz=M.Landing(zone,p.X,p.Y,p.Z)
 local moved=pcall(function()character:PivotTo(character:GetPivot()+V(nx-p.X,ny-p.Y,nz-p.Z))end)
 if not moved then return false end
 local v=root.AssemblyLinearVelocity
 root.AssemblyLinearVelocity=V(0,math.min(v.Y,0),0);root.AssemblyAngularVelocity=V(0,0,0)
 pcall(function()require(script.Parent.MovementGuard).Reset(player,.6)end) -- (the guard must not take the move for a speed hack)
 M.Rescues+=1
 return true
end
-- One look at the players (called every Interval). Returns how many were moved.
function M.Step(players)
 local zones=M.Zones
 if #zones==0 then return 0 end
 local moved=0
 for _,player in ipairs(players or Players:GetPlayers())do
  local zone
  local character=player.Character
  local root=character and character:FindFirstChild('HumanoidRootPart')
  local humanoid=character and character:FindFirstChildOfClass('Humanoid')
  if root and humanoid and humanoid.Health>0 and root:IsA('BasePart')and not root.Anchored
   and not player:GetAttribute('StudioTestFlying')and not player:GetAttribute('StudioTestNoclip')then
   local p,v=root.Position,root.AssemblyLinearVelocity
   zone=M.Inspect(p.X,p.Y,p.Z,v.Y,zones)
  end
  if zone and M.Seen[player]==zone then
   M.Seen[player]=nil
   if M.Rescue(player,character,root,zone)then moved+=1 end
  else M.Seen[player]=zone end
 end
 return moved
end
function M.Start()
 if M.Connection then return M.Connection end
 local waited=0
 M.Connection=Run.Heartbeat:Connect(function(dt)
  waited+=dt;if waited<M.Settings.Interval then return end
  waited=0
  local ok,err=pcall(M.Step)
  if not ok then warn('[R153] Track wall guard step failed: '..tostring(err))end
 end)
 return M.Connection
end
function M.Stop()
 if M.Connection then M.Connection:Disconnect();M.Connection=nil end
end
return M
