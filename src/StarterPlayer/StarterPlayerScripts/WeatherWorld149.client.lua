-- R149 (owner): "rework weather and make it so that it's not a camera-only thing: during rain, thunder or snow, when moving the camera the
-- effects stop for a while and take some time to begin again. Make rain, blizzard and thunder actually happen: droplets actually fall from
-- the sky onto the ground. For snow / blizzard add patches of snow on the ground; they fade in and fade out after a while."
-- Client only, presentation only (the weather state, mutations and remotes stay with WeatherService / WorldEvents).
--
-- WHY THE OLD RAIN STOPPED (WorldEvents R128): its one emitter sat in a 36 x 32 box that was moved to the camera every frame, 7 studs
-- ahead and 28 studs up. Turning the camera swung the box to another place; the drops born there needed the whole fall (0.4 s rain, ~1 s
-- snow) before they reached eye level, and the area you now looked at had none in flight, so every camera move starved the view for a
-- moment and then it "took a while to start again". The weather was a bubble around the camera, not weather in the world.
--
-- NOW: a pooled grid of invisible emitter tiles fixed in WORLD space (cells of 50 studs, centres snapped to the grid) above the ground
-- around the PLAYER (never the camera). Particles are born at cloud height, fall to the ground with a lifetime worked out from the height
-- and fall speed (WeatherWorld149.FallTime), and are not locked to anything. A tile only moves when it is handed to another grid cell
-- (the player crossed a cell border), and a re-seated tile never touches the drops already falling. Tiles are cut to the weather area
-- (the base; nothing on the track) with the sideways drift taken into account. Rain / thunder drops splash on the ground (spray + a flat
-- ripple, ground emitters under each tile). Blizzard lays snow patches on the ground (flat white blobs, fade in 10-20 s, out 20-40 s).
-- Budgets: ClientFxBudget tiers (tiles, particle cap, patches), FastMode = tier 1, ReducedMotion = fewer, no gusts. Pooled instances, a
-- fixed-rate update (10 Hz, 5 Hz on tier 1), bounded work per step, nothing allocated per frame.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local W=require(RS:WaitForChild('WeatherWorld149'));local Patches=require(RS:WaitForChild('SnowPatches149'))
local Fx=require(RS:WaitForChild('ClientFxBudget'));local Mood=require(RS:WaitForChild('BiomeMood'))
local V3,V2,CF=Vector3.new,Vector2.new,CFrame.new
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local byte=string.byte
local clock=os.clock
local player=Players.LocalPlayer
local KP,NR,NS=ColorSequence.new,NumberRange.new,NumberSequence.new
local KEY=NumberSequenceKeypoint.new

local folder=Instance.new('Folder');folder.Name='_WeatherWorldR149';folder.Parent=workspace
local function sub(name)local f=Instance.new('Folder');f.Name=name;f.Parent=folder;return f end
local skyFolder,groundFolder,patchFolder=sub('Sky tiles'),sub('Ground tiles'),sub('Snow patches')
local function part(name,parent)
 local p=Instance.new('Part');p.Name=name;p.Size=V3(4,.2,4);p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.CastShadow=false;p.CFrame=CF(0,-500,0);p.Parent=parent;return p
end

-- State ----------------------------------------------------------------------------------------------------------------------
local running=true;local conns={}
local tierNow,tierWant,tierSince=nil,nil,0
local tierCfg=W.Tier(3);local reduced=false
local kind='Clear';local profile=nil;local shownKind='Clear'
local blend=0
local area=W.Area({GetAttribute=function()return nil end});local areaNext={}
local areaMap,areaConn,areaDirty=nil,nil,true       -- the map the area was read from, its AttributeChanged connection, 'read it again'
local fx,fy,fz,fgy=0,0,0,0;local haveFocus=false;local inBase=true
local win={I=nil,J=nil,Size=0}
local tiles,tileOf,tileCount={}, {},0
local stepClock,gustClock,patchClock=0,0,0
local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.IgnoreWater=true
local rayChar,rayInit=nil,false

local function cast(x,y,z,dy)
 local ok,hit=pcall(workspace.Raycast,workspace,V3(x,y,z),V3(0,dy,0),rayParams)
 if ok then return hit end
 return nil
end
local function setRayFilter()
 local c=player.Character
 if not rayInit or c~=rayChar then
  rayInit=true;rayChar=c;rayParams.FilterDescendantsInstances=c and{folder,c}or{folder}
 end
end

-- Tiles ----------------------------------------------------------------------------------------------------------------------
local function applyDrops(e,p)
 local k=p.Look;local snow=p.Snow
 e.Texture=k.Texture;e.Color=KP(k.Color);e.LightEmission=k.Emission;e.LightInfluence=.2
 e.Size=NS({KEY(0,k.Size,k.Size*.3),KEY(1,k.Size,k.Size*.3)})
 e.Transparency=NS({KEY(0,1),KEY(.07,k.Fade),KEY(.93,k.Fade),KEY(1,1)})
 e.Lifetime=NR(p.LifeMin,p.LifeMax);e.Speed=NR(p.SpeedMin,p.SpeedMax)
 e.SpreadAngle=V2(p.Spread,p.Spread);e.Acceleration=V3(p.WindX,-p.Gravity,p.WindZ);e.Drag=0
 e.EmissionDirection=Enum.NormalId.Bottom;e.LockedToPart=false;e.VelocityInheritance=0
 e.Orientation=snow and Enum.ParticleOrientation.FacingCamera or Enum.ParticleOrientation.VelocityParallel
 e.Squash=NS(snow and 0 or -.88)
 e.Rotation=NR(0,snow and 360 or 0);e.RotSpeed=NR(snow and -40 or 0,snow and 40 or 0)
end
local function newTile()
 local t={Key=nil,Ok=false,I=0,J=0,CX=0,CZ=0,CW=0,CD=0,Area=0,GroundY=0,Wt=0,Rate=0,SprayRate=0,RippleRate=0,AX=0,AZ=0}
 t.Sky=part('Rain tile',skyFolder);t.Ground=part('Splash tile',groundFolder)
 local e=Instance.new('ParticleEmitter');e.Name='Precipitation';e.Enabled=false;e.Rate=0;e.Parent=t.Sky;t.Emitter=e
 local spray=Instance.new('ParticleEmitter');spray.Name='Splash spray';spray.Enabled=false;spray.Rate=0
 spray.Texture='rbxasset://textures/particles/sparkles_main.dds';spray.Color=KP(Color3.fromRGB(214,234,252));spray.LightEmission=.3;spray.LightInfluence=.2
 spray.Size=NS({KEY(0,.14,.04),KEY(1,.04)});spray.Transparency=NS({KEY(0,.1),KEY(.6,.4),KEY(1,1)})
 spray.Lifetime=NR(W.Splash.SprayLife[1],W.Splash.SprayLife[2]);spray.Speed=NR(4,8);spray.SpreadAngle=V2(55,55);spray.Acceleration=V3(0,-42,0)
 spray.EmissionDirection=Enum.NormalId.Top;spray.LockedToPart=false;spray.VelocityInheritance=0;spray.Drag=0;spray.Parent=t.Ground;t.Spray=spray
 local ring=Instance.new('ParticleEmitter');ring.Name='Splash ripple';ring.Enabled=false;ring.Rate=0
 ring.Texture='rbxasset://textures/particles/smoke_main.dds';ring.Color=KP(Color3.fromRGB(205,226,244));ring.LightEmission=.1;ring.LightInfluence=.4
 ring.Size=NS({KEY(0,.3),KEY(1,2.4)});ring.Transparency=NS({KEY(0,.62),KEY(1,1)})
 ring.Lifetime=NR(W.Splash.RippleLife[1],W.Splash.RippleLife[2]);ring.Speed=NR(.02,.04);ring.SpreadAngle=V2(0,0);ring.Acceleration=V3(0,0,0)
 ring.EmissionDirection=Enum.NormalId.Top;ring.Orientation=Enum.ParticleOrientation.VelocityPerpendicular;ring.Rotation=NR(0,360)
 ring.LockedToPart=false;ring.VelocityInheritance=0;ring.Drag=0;ring.Parent=t.Ground;t.Ripple=ring
 if profile then applyDrops(e,profile)end
 return t
end
local function maxTiles()return(2*tierCfg.R+1)^2 end
local function setRate(e,old,rate)
 if rate>.5 then
  if e.Enabled~=true then e.Enabled=true end
  if abs(rate-old)>max(1,old*.025)then e.Rate=rate;return rate end
  return old
 end
 if e.Enabled==true then e.Enabled=false end
 if old~=0 then e.Rate=0 end
 return 0
end
local function quiet(t)
 t.Rate=setRate(t.Emitter,t.Rate,0);t.SprayRate=setRate(t.Spray,t.SprayRate,0);t.RippleRate=setRate(t.Ripple,t.RippleRate,0)
end
local function releaseTile(t)
 if t.Key then tileOf[t.Key]=nil;tileCount-=1 end
 t.Key=nil;t.Ok=false;quiet(t)
end
local function releaseAll()for _,t in ipairs(tiles)do if t.Key then releaseTile(t)end end end
-- Ground height under a tile: a raycast from above, believed only when it lands on a flat surface at the player's own ground level (a
-- roof, a tree top or a fence is not the ground: the drops would stop in mid-air); otherwise the player's ground.
local function groundAt(x,z)
 local hit=cast(x,fgy+40,z,-80)
 if hit and hit.Normal.Y>.85 and hit.Position.Y>=fgy-3 and hit.Position.Y<=fgy+1.2 then return hit.Position.Y end
 return fgy
end
local function seat(t,i,j)
 local S=tierCfg.Tile
 t.Key=W.CellKey(i,j);tileOf[t.Key]=t;tileCount+=1;t.I,t.J=i,j
 local ok,cx,cz,w,d=W.Clip(area,i*S,(i+1)*S,j*S,(j+1)*S,profile or W.Profile('Rain',tierNow or 3,reduced))
 t.Ok=ok
 if not ok then quiet(t);return end
 local gy=groundAt(cx,cz)
 t.GroundY=gy;t.CX,t.CZ,t.CW,t.CD,t.Area=cx,cz,w,d,w*d
 local h=profile and profile.Height or 46
 t.Sky.Size=V3(w,.2,d);t.Sky.CFrame=CF(cx,gy+h,cz)
 t.Ground.Size=V3(w,.1,d);t.Ground.CFrame=CF(cx,gy+W.Splash.Rise,cz)
end
local function freeTile()
 for _,t in ipairs(tiles)do if not t.Key then return t end end
 if #tiles<maxTiles()then local t=newTile();tiles[#tiles+1]=t;return t end
 return nil
end

-- Re-seat the grid around the player: tiles outside the window go back to the pool, missing cells get a pooled tile, nearest first.
-- Moving a tile writes its CFrame / Size once; the particles already falling are left alone (nothing is cleared).
local SEAT_PER_STEP=8
local function fillWindow()
 local R=tierCfg.R
 for _,t in ipairs(tiles)do
  if t.Key and(abs(t.I-win.I)>R or abs(t.J-win.J)>R)then releaseTile(t)end
 end
 local budget=SEAT_PER_STEP
 for r=0,R do for di=-r,r do for dj=-r,r do
  if max(abs(di),abs(dj))==r then
   local i,j=win.I+di,win.J+dj
   if not tileOf[W.CellKey(i,j)]then
    local t=freeTile();if not t then return end
    seat(t,i,j);budget-=1;if budget<=0 then return end
   end
  end
 end end end
end

-- Weights, rates and gusts -----------------------------------------------------------------------------------------------------
local function updateRates()
 local p=profile
 if not p or blend<=0 or not inBase then for _,t in ipairs(tiles)do if t.Key then quiet(t)end end;return end
 local sum=0
 for _,t in ipairs(tiles)do if t.Key and t.Ok then
  local hw,hd=t.CW/2,t.CD/2
  t.Wt=W.Weight(W.RectDistance(fx,fz,t.CX-hw,t.CX+hw,t.CZ-hd,t.CZ+hd),tierCfg.Near,tierCfg.Far)
  sum+=t.Area*t.Wt
 end end
 local scale=W.Scale(p,sum*p.Density)
 local splash=p.Splash
 for _,t in ipairs(tiles)do if t.Key then
  if t.Ok then
   local rate=W.Rate(p,scale,t.Wt,t.Area)*blend
   t.Rate=setRate(t.Emitter,t.Rate,rate)
   local s=splash and t.Wt>=tierCfg.SplashMin and rate>0
   t.SprayRate=setRate(t.Spray,t.SprayRate,s and min(W.Splash.MaxRate,rate*W.Splash.SprayShare)or 0)
   t.RippleRate=setRate(t.Ripple,t.RippleRate,s and min(W.Splash.MaxRate,rate*W.Splash.RippleShare)or 0)
  else quiet(t)end
 end end
end
local function updateGusts(now)
 local p=profile;if not p or p.Gust<=0 then return end
 for _,t in ipairs(tiles)do if t.Key and t.Ok and t.Rate>0 then
  local ax,az=W.Wind(p,now,t.CX)
  if abs(ax-t.AX)>.15 or abs(az-t.AZ)>.05 then t.AX,t.AZ=ax,az;t.Emitter.Acceleration=V3(ax,-p.Gravity,az)end
 end end
end
local function setKind(newKind,now)
 local previous=profile
 profile=newKind~='Clear'and W.Profile(newKind,tierNow or 3,reduced)or nil
 if profile then
  for _,t in ipairs(tiles)do applyDrops(t.Emitter,profile);t.AX,t.AZ=profile.WindX,profile.WindZ
   -- rain -> blizzard (owner test commands): the old drops must not turn into the new look mid-air
   if previous and previous.Kind~=profile.Kind then t.Emitter:Clear()end
  end
  releaseAll()
 end
end

-- Snow patches (blizzard) -----------------------------------------------------------------------------------------------------
local events=W.NewEvents()
local poolW=nil;local bound,boundList,boundN={}, {},0;local rejected,rejectedN={},0
local plots,plotN,plotsDirty={}, 0,true;local basesWatch,basesOf
local function patchKey(i,j)return W.CellKey(i,j)end
local function collectPlots()
 plotsDirty=false;plotN=0
 local map=workspace:FindFirstChild('ChestChaseMap');local bases=map and map:FindFirstChild('Bases')
 if not bases then return end
 if bases~=basesOf then -- (a refreshed map has a new Bases: watch that one, the old connection goes)
  if basesWatch then basesWatch:Disconnect() end
  basesOf=bases
  -- every garden part that streams in passes here: one byte compare first ('D' = 68), the pattern only for names that start with it
  basesWatch=bases.DescendantAdded:Connect(function(d)local n=d.Name;if byte(n,1)==68 and n:match('^DirtPlot_%d')then plotsDirty=true end end)
 end
 for _,d in ipairs(bases:GetDescendants())do
  if byte(d.Name,1)==68 and d:IsA('BasePart')and d.Name:match('^DirtPlot_%d')then
   local c,s=d.CFrame,d.Size;local r,u=c.RightVector,c.UpVector;local l=r:Cross(u) -- the part's own axes (a plot may be turned a quarter)
   plotN+=1;local row=plots[plotN]or{};plots[plotN]=row
   row[1],row[2]=c.Position.X,c.Position.Z
   row[3]=abs(r.X)*s.X/2+abs(u.X)*s.Y/2+abs(l.X)*s.Z/2;row[4]=abs(r.Z)*s.X/2+abs(u.Z)*s.Y/2+abs(l.Z)*s.Z/2
  end
 end
end
local function overlapsPlot(x,z,radius)
 for k=1,plotN do local p=plots[k];if abs(x-p[1])<p[3]+radius and abs(z-p[2])<p[4]+radius then return true end end
 return false
end
-- Drop the lobes that would lie on a garden bed (the main lobe on one rejects the whole patch). Returns false then.
local function trimLobes(s)
 if plotN==0 then return true end
 local n=0
 for k=1,s.N do
  local x,z,r=s.X+s.LX[k],s.Z+s.LZ[k],max(s.LA[k],s.LB[k])
  if not overlapsPlot(x,z,r+.3)then
   n+=1;s.LX[n],s.LZ[n],s.LA[n],s.LB[n],s.LY[n]=s.LX[k],s.LZ[k],s.LA[k],s.LB[k],s.LY[k]
  elseif k==1 then return false end
 end
 s.N=n
 return n>0
end
-- The patch's surface height: three rays (centre and the two ends of its long axis) that all find the same low, flat, non-bed surface.
local function patchGround(s)
 local ya,yb=0,0
 local a=s.LA[1]*W.Patch.Samples;local yaw=s.LY[1]
 local dx,dz=math.sin(yaw)*a,math.cos(yaw)*a
 for n=1,3 do
  local px,pz=s.X,s.Z;if n==2 then px,pz=px+dx,pz+dz elseif n==3 then px,pz=px-dx,pz-dz end
  local hit=cast(px,fgy+30,pz,-60)
  if not hit or hit.Normal.Y<.9 or abs(hit.Position.Y-fgy)>3 or hit.Instance.Name:match('^DirtPlot')then return nil end
  local y=hit.Position.Y
  if n==1 then ya,yb=y,y else ya,yb=min(ya,y),max(yb,y)end
 end
 if yb-ya>.35 then return nil end
 return yb
end
local function levelOf(rec,now)return W.Level(events,now,rec.Spec.DIn,rec.Spec.DOut)end
local function dropPatch(rec)
 local last=boundList[boundN];boundList[rec.Idx]=last;last.Idx=rec.Idx;boundList[boundN]=nil;boundN-=1
 bound[rec.Key]=nil;Patches.Release(poolW,rec)
end
local function clearPatches()
 while boundN>0 do dropPatch(boundList[boundN])end
 table.clear(rejected);rejectedN=0
end
local function buildPatchPool()
 if poolW then clearPatches();Patches.Destroy(poolW)end
 poolW=Patches.new(patchFolder,tierCfg.Patch.Discs,floor(tierCfg.Patch.Discs/2)+20,3)
end
local function bindPatch(i,j,now)
 local rec=Patches.Take(poolW);if not rec then return false end
 local key=patchKey(i,j);local s=rec.Spec
 local ok=W.PatchSpec(i,j,s)
 if ok then ok=W.Outside(area,s.X,s.Z,s.Extent,2)and trimLobes(s)end
 local y=ok and patchGround(s)
 if not y then
  Patches.Release(poolW,rec)
  if rejectedN<4000 then rejected[key]=true;rejectedN+=1 end
  return true
 end
 rec.Key=key;bound[key]=rec;boundN+=1;boundList[boundN]=rec;rec.Idx=boundN
 rec.T=W.PatchTransparency(levelOf(rec,now))
 -- (a deterministic step by cell parity: overlapping patches of neighbouring cells never share a plane, W.PatchStep)
 if Patches.Fill(poolW,rec,s.N,1,y+W.Patch.Rise+s.Thickness/2+W.PatchStep(i,j))==0 then dropPatch(rec)end
 return true
end
local function updatePatches(now,snowing)
 local P=W.Patch;local radius=tierCfg.Patch.Radius
 if plotsDirty and snowing then collectPlots()end
 -- release patches that left the window
 for k=boundN,1,-1 do
  local rec=boundList[k];local s=rec.Spec
  if(s.X-fx)^2+(s.Z-fz)^2>(radius+P.Cell)^2 then dropPatch(rec)end
 end
 -- bind the ones that entered it (only where weather is allowed and while there is snow to show)
 if inBase and haveFocus and(snowing or W.Active(events,now))then
  local budget=2;local c1,c2=floor((fx-radius)/P.Cell),floor((fx+radius)/P.Cell);local r1,r2=floor((fz-radius)/P.Cell),floor((fz+radius)/P.Cell)
  for i=c1,c2 do for j=r1,r2 do
   local key=patchKey(i,j)
   if budget>0 and not bound[key]and not rejected[key]then
    local cx,cz=(i+.5)*P.Cell-fx,(j+.5)*P.Cell-fz
    if cx*cx+cz*cz<=radius*radius then if bindPatch(i,j,now)then budget-=1 end end
   end
  end end
 end
end
local fadeCursor=1
local function fadePatches(now)
 if boundN==0 then return end
 local n=boundN;local count=min(n,24)
 for _=1,count do
  if fadeCursor>boundN then fadeCursor=1 end
  local rec=boundList[fadeCursor];fadeCursor+=1
  Patches.Alpha(rec,W.PatchTransparency(levelOf(rec,now)))
 end
end

-- Main step ---------------------------------------------------------------------------------------------------------------------
local function readFocus()
 local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart')
 local p
 if root then p=root.Position else local cam=workspace.CurrentCamera;if cam then p=cam.CFrame.Position end end
 if not p then haveFocus=false;return nil end
 haveFocus=true;fx,fy,fz=p.X,p.Y,p.Z
 return p,root~=nil
end
local function step(dt,now)
 local p,hasRoot=readFocus()
 setRayFilter()
 reduced=Gui.ReducedMotionEnabled==true
 -- tier (a change applies once it has held)
 local t=Fx.Get()
 if tierNow==nil then tierNow,tierWant,tierSince=t,t,now
 else
  if t~=tierWant then tierWant,tierSince=t,now end
  -- (a tier change re-profiles the weather that is SHOWN: while it fades out (kind is Clear already) the fade goes on with the new tier's
  -- numbers instead of being cut by setKind('Clear') dropping the profile)
  if tierWant~=tierNow and now-tierSince>=W.TierHold then tierNow=tierWant;tierCfg=W.Tier(tierNow);releaseAll();win.I=nil;buildPatchPool();if profile and shownKind~='Clear'then setKind(shownKind,now)end end
 end
 tierCfg=W.Tier(tierNow)
 if not poolW then buildPatchPool()end
 -- weather kind
 local k=RS:GetAttribute('GlobalWeather');if not W.Kinds[k]then k='Clear'end
 if k~=kind then kind=k end
 local wasReduced=profile and profile.Gust==0
 if k~='Clear'and(shownKind~=k or(profile~=nil and wasReduced~=reduced))then shownKind=k;setKind(k,now)end
 -- clear sky and nothing left to fade out or show (the tiles went quiet in the step the fade ended): no base check, no area read, no ground
 -- raycast - that was ~10 raycasts and ~150 attribute reads a second for nothing. Weather starting is noticed above (kind / shownKind).
 if kind=='Clear'and shownKind=='Clear'and blend<=0 and boundN==0 and not W.Active(events,now)then return end
 -- where the player is: weather belongs to the base (R129)
 inBase=true
 if p then
  local map=workspace:FindFirstChild('ChestChaseMap')
  if hasRoot and map then inBase=Mood.Stage(map,p,0)==0 end
 end
 local active=kind~='Clear'and inBase and haveFocus
 blend=max(0,min(1,blend+(active and dt/W.Ramp.Up or-dt/W.Ramp.Down)))
 if blend<=0 and kind=='Clear'and shownKind~='Clear'then shownKind='Clear';profile=nil end
 -- weather area (the track rectangle): read again only when the map's attributes change (or the map instance is a new one)
 local map=workspace:FindFirstChild('ChestChaseMap')
 if map~=areaMap then
  if areaConn then areaConn:Disconnect();areaConn=nil end
  areaMap=map;areaDirty=true
  if map then areaConn=map.AttributeChanged:Connect(function()areaDirty=true end)end
 end
 if map and areaDirty then
  areaDirty=false
  W.Area(map,areaNext)
  if not W.SameArea(areaNext,area)then area,areaNext=areaNext,area;releaseAll();clearPatches()end
 end
 if haveFocus then
  local hit=cast(fx,fy+2,fz,-80)
  fgy=(hit and hit.Normal.Y>.7)and hit.Position.Y or(fy-3)
 end
 -- tiles
 if profile and haveFocus and blend>0 then
  if win.I==nil then releaseAll()end
  if W.Recenter(win,fx,fz,tierCfg.Tile,tierCfg.Tile*.2)or tileCount<(2*tierCfg.R+1)^2 then if inBase then fillWindow()end end
 end
 updateRates()
 -- snow patches follow the weather, not the player's place: Blizzard = snowing
 local snowing=kind=='Blizzard'
 if W.Mark(events,now,snowing)then fadeCursor=1 end
 W.Prune(events,now)
 if W.Active(events,now)or boundN>0 then
  updatePatches(now,snowing)
  if not W.Active(events,now)then clearPatches()end
 end
end
conns[#conns+1]=Run.Heartbeat:Connect(function(dt)
 if not running then return end
 stepClock+=dt;gustClock+=dt;patchClock+=dt
 local interval=W.StepSeconds[tierNow or 3]or .1
 if stepClock>=interval then
  local d=stepClock;stepClock=0;step(d,clock())
 end
 -- gusts 4 Hz; patch fades sliced across steps
 if gustClock>=.25 then gustClock=0;if blend>0 and inBase then updateGusts(clock())end end
 if patchClock>=.1 then
  patchClock=0;local now=clock()
  if W.Fading(events,now)then fadePatches(now)end
 end
end)
-- A death or respawn changes where the player is, nothing else: the tiles keep falling, the window re-centres on the new spot.
conns[#conns+1]=player.CharacterRemoving:Connect(function()rayInit=false end)
conns[#conns+1]=player.CharacterAdded:Connect(function()rayInit=false;stepClock=1 end)
local destroyed=false
local function cleanup()
 if destroyed then return end;destroyed=true;running=false
 for _,c in ipairs(conns)do c:Disconnect()end;table.clear(conns)
 if areaConn then areaConn:Disconnect();areaConn=nil end
 if basesWatch then basesWatch:Disconnect();basesWatch=nil end
 for _,t in ipairs(tiles)do t.Emitter:Clear();t.Spray:Clear();t.Ripple:Clear()end
 table.clear(tiles);table.clear(tileOf);table.clear(bound);table.clear(boundList);boundN=0
 folder:Destroy()
end
script.Destroying:Connect(cleanup)
