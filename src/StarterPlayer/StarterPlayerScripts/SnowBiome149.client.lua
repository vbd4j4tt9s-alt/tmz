-- R149 (owner): "for the snow biome add the snow patches there as permanent". Client only. The Snow stage (3) of the track gets flat white
-- snow patches, built from a deterministic layout (WeatherWorld149.BiomeSpec: a hash of grid cells, so every client builds the same) in a
-- window around the runner, with level of detail by distance. They never fade and do not depend on the weather.
--
-- THE KEYBOARD (R148, KeyboardTrack.client.lua) covers the whole 180-wide floor edge to edge: resting key tops 4.45 (K.KeyTop(0)), a dark
-- bed under them, plain blocks at the coarser layers a few hundredths lower. There is no bare snow floor left to lay patches on, so:
--  * the patches sit ABOVE the resting key tops (K.KeyTop(0) + Rise + half the patch thickness): never coplanar with a key, a block, the
--    bed or the floor, so nothing z-fights; a pressed key only sinks away from under a patch;
--  * EDGE DRIFTS: big irregular blobs (up to three overlapping flat ellipses) along both side edges of the floor (the outer 15 studs, where
--    the scenery stones and ice pillars stand) - the snow banks look snowy and the lane keys the runner uses stay clean;
--  * BORDER patches: over the whole width in the first and last rows of the biome (the entry and exit of the snow), but never in the
--    spacebar zone at the start: the "Snow" bar and its label stay clean;
--  * a light DUSTING of small discs between them, kept AWAY from the runner: dust is invisible within (legend radius + 6) studs of him and
--    fades in beyond, so the letters on the keys under and around his feet are never covered; off on tier 1 / FastMode;
--  * nothing within 16-24 studs of a pack or a keeper camp of the biome (they stay legible), nothing past the floor edges or the biome ends.
-- Budgets: ClientFxBudget tiers (window radius, part budget, lobes per distance band), 5 Hz scans, bounded binds / reshapes per scan,
-- pooled parts, nothing allocated per frame. The keyboard script is only read (its config and its folder), never changed.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local W=require(RS:WaitForChild('WeatherWorld149'));local Patches=require(RS:WaitForChild('SnowPatches149'));local Fx=require(RS:WaitForChild('ClientFxBudget'))
local okK,K=pcall(function()return require(RS:WaitForChild('KeyboardTrack'))end)
if not okK then K=nil end
local floor,min,max=math.floor,math.min,math.max
local clock=os.clock
local player=Players.LocalPlayer
local map=workspace:WaitForChild('ChestChaseMap')
local B=W.Biome
local STAGE=3

local folder=Instance.new('Folder');folder.Name='_SnowBiomeR149';folder.Parent=workspace
local running=true;local conns={}
local tierNow,tierWant,tierSince=nil,nil,0;local cfg=W.Tier(3)
local pool=nil
local z0,z1,cx=nil,nil,0;local layoutSig=''
local surface=nil
local bound,boundList,boundN={}, {},0;local skip,skipN={}, 0
local avoid,avoidN={}, 0;local avoidCount=-1
local fx,fz=0,0;local haveFocus=false
local stepClock,slowClock=0,1
local reshapeCursor=1

local function patchY(rec)return surface+B.Rise+(rec.Spec.Thickness or B.Thickness)/2 end
local function dropPatch(rec)
 local last=boundList[boundN];boundList[rec.Idx]=last;last.Idx=rec.Idx;boundList[boundN]=nil;boundN-=1
 bound[rec.Key]=nil;Patches.Release(pool,rec)
end
local function clearAll()
 if pool then while boundN>0 do dropPatch(boundList[boundN])end end
 table.clear(skip);skipN=0
end
local function buildPool()
 if pool then clearAll();Patches.Destroy(pool)end
 pool=Patches.new(folder,cfg.Biome.Discs,cfg.Biome.Discs,3)
end

-- The surface the patches lie on: the resting key tops while the keyboard is there, the bare floor otherwise.
local function readSurface()
 local keyboard=workspace:FindFirstChild('KeyboardTrackVisuals')
 if K and keyboard then return K.KeyTop(0)end
 return(K and K.Config.FloorTop or 4)
end
-- Packs and keeper camps of this biome: patches keep clear of them.
local function readAvoid()
 avoidN=0
 local seeds=map:FindFirstChild('Seeds')
 if seeds then for _,m in ipairs(seeds:GetChildren())do if m:GetAttribute('Stage')==STAGE then
  local ok,pivot=pcall(m.GetPivot,m)
  if ok and pivot then avoidN+=1;local a=avoid[avoidN]or{};avoid[avoidN]=a;a[1],a[2],a[3]=pivot.Position.X,pivot.Position.Z,16 end
 end end end
 local camps=map:FindFirstChild('GuardianEncounters')
 if camps then for _,m in ipairs(camps:GetChildren())do if m:GetAttribute('Stage')==STAGE then
  local home=m:GetAttribute('GuardianHomeCFrame')
  if typeof(home)=='CFrame'then avoidN+=1;local a=avoid[avoidN]or{};avoid[avoidN]=a;a[1],a[2],a[3]=home.Position.X,home.Position.Z,24 end
 end end end
end
local function nearAvoid(x,z,extent)
 for k=1,avoidN do local a=avoid[k];local dx,dz=x-a[1],z-a[2];local r=a[3]+extent*.5;if dx*dx+dz*dz<r*r then return true end end
 return false
end
local function readLayout()
 local a,b=map:GetAttribute(W.StartKey[STAGE]),map:GetAttribute(W.EndKey[STAGE])
 if type(a)~='number'or type(b)~='number'or b<=a then return nil end
 local motion=RS:FindFirstChild('RunnerMotion');local c=motion and motion:GetAttribute('TrackCenterX')
 return a,b,type(c)=='number'and c or 0
end
local function clearRadius()
 return(K and K.Tier(tierNow or 3).LegendRadius or 20)+6
end

local function bind(i,j)
 local rec=Patches.Take(pool);if not rec then return false end
 local key=W.CellKey(i,j);local s=rec.Spec
 local ok=W.BiomeSpec(i,j,z0,z1,cx,s)
 if ok and s.Kind=='dust'and not cfg.Biome.Dust then ok=false end
 if ok and nearAvoid(s.X,s.Z,s.Extent)then ok=false end
 if not ok then
  Patches.Release(pool,rec)
  if skipN<4000 then skip[key]=true;skipN+=1 end
  return true
 end
 local d=math.sqrt((s.X-fx)^2+(s.Z-fz)^2)
 rec.Key=key;bound[key]=rec;boundN+=1;boundList[boundN]=rec;rec.Idx=boundN
 rec.T=s.Kind=='dust'and W.DustTransparency(d,clearRadius())or B.FinalTransparency
 local lobes=s.Kind=='dust'and 1 or W.BiomeLobes(cfg.Biome,d,s.N)
 if Patches.Fill(pool,rec,lobes,B.FarScale,patchY(rec))==0 then dropPatch(rec)end
 return true
end

local function step(dt,now)
 -- the runner: his character, else the camera
 local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart')
 local p=root and root.Position
 if not p then local cam=workspace.CurrentCamera;p=cam and cam.CFrame.Position end
 haveFocus=p~=nil
 if p then fx,fz=p.X,p.Z end
 -- tier: a change applies once it has held
 local t=Fx.Get()
 if tierNow==nil then tierNow,tierWant,tierSince=t,t,now;cfg=W.Tier(t);buildPool()
 else
  if t~=tierWant then tierWant,tierSince=t,now end
  if tierWant~=tierNow and now-tierSince>=W.TierHold then tierNow=tierWant;cfg=W.Tier(tierNow);buildPool()end
 end
 local bc=cfg.Biome
 -- layout / surface / avoid list, once a second
 slowClock+=dt
 if slowClock>=1 then
  slowClock=0
  local a,b,c0=readLayout()
  local sig=a and(a..'|'..b..'|'..c0)or''
  if sig~=layoutSig then layoutSig=sig;z0,z1,cx=a,b,c0;clearAll()end
  local s=readSurface()
  if s~=surface then
   surface=s
   for k=1,boundN do local rec=boundList[k];Patches.Lift(rec,patchY(rec))end
  end
  local seeds=map:FindFirstChild('Seeds');local count=(seeds and #seeds:GetChildren()or 0)
  if count~=avoidCount then avoidCount=count;readAvoid()end
 end
 if not z0 or not haveFocus then return end
 local R=bc.Radius
 -- release what left the window
 for k=boundN,1,-1 do
  local rec=boundList[k];local s=rec.Spec
  if(s.X-fx)^2+(s.Z-fz)^2>(R+W.Biome.Cell)^2 then dropPatch(rec)end
 end
 -- bind what entered it (only while the runner is within reach of the biome)
 if fz>z0-R and fz<z1+R then
  local rows=W.BiomeRows(z0,z1);local cols=W.BiomeCols()
  local r1,r2=max(0,floor((fz-R-z0)/B.Cell)),min(rows-1,floor((fz+R-z0)/B.Cell))
  local budget=bc.Bind
  for j=r1,r2 do
   local zc=z0+(j+.5)*B.Cell
   for i=0,cols-1 do
    local key=W.CellKey(i,j)
    if budget>0 and not bound[key]and not skip[key]then
     local xc=cx-B.Half+(i+.5)*B.Cell
     if(xc-fx)^2+(zc-fz)^2<=R*R then if bind(i,j)then budget-=1 end end
    end
   end
  end
 end
 -- distance-driven look: dust hidden near the runner, lobes by band (a few per step)
 local clear=clearRadius();local reshape=bc.Reshape
 local n=boundN
 for k=1,n do
  local rec=boundList[k];local s=rec.Spec
  local d=math.sqrt((s.X-fx)^2+(s.Z-fz)^2)
  if s.Kind=='dust'then Patches.Alpha(rec,W.DustTransparency(d,clear))end
 end
 if n>0 then
  for _=1,min(n,24)do
   if reshapeCursor>boundN then reshapeCursor=1 end
   local rec=boundList[reshapeCursor];reshapeCursor+=1
   local s=rec.Spec
   if s.Kind~='dust'and reshape>0 then
    local d=math.sqrt((s.X-fx)^2+(s.Z-fz)^2)
    local want=W.BiomeLobes(bc,d,s.N)
    if want~=rec.Lobes then Patches.Fill(pool,rec,want,B.FarScale,patchY(rec));reshape-=1 end
   end
  end
 end
end
conns[#conns+1]=Run.Heartbeat:Connect(function(dt)
 if not running then return end
 stepClock+=dt
 if stepClock>=.2 then local d=stepClock;stepClock=0;step(d,clock())end
end)
local destroyed=false
script.Destroying:Connect(function()
 if destroyed then return end;destroyed=true;running=false
 for _,c in ipairs(conns)do c:Disconnect()end;table.clear(conns)
 table.clear(bound);table.clear(boundList);boundN=0
 folder:Destroy()
end)
