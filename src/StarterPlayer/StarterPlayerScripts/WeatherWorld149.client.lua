do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
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
--
-- R151 (owner: "make sure the snow piles are visible throughout and not just when players walk into an area that it appears"; "snow piles can
-- be bigger and more combined so we don't have to deal with that much performance demand"; "some of the droplets can have impact with the
-- ground, not all"; "do a performance patch on the weather"):
--  * SNOW covers the WHOLE hub during a blizzard: one fixed layout of big drifts (HubSnow151: wall banks, corner drifts, fence banks, broad
--    open drifts, a sprinkle inside the bases on tier 3) instead of small patches in a radius around the player. Each drift is checked once
--    (avoid list + ground rays, cached), shrinks / slides to fit between the R151 streets, takes its lobes by distance (LOD) within the tier's
--    part budget, follows the one snow level (WeatherWorld149.Level) and is put away down the track. See the section below.
--  * SPLASHES: a share of the landing drops (fewer away from the player and on lower tiers); the drops keep their R149 density.
--  * PERFORMANCE: the rate pass is skipped while nothing it depends on moved, far tiles' gusts are written less often, the base check reads
--    the track rectangle (no 14 attribute-name strings + reads ten times a second), and the R149 Level bug that left the second blizzard of a
--    session with no snow at all is fixed (WeatherWorld149.Level / Prune).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Gui=game:GetService('GuiService')
local W=require(RS:WaitForChild('WeatherWorld149'));local Patches=require(RS:WaitForChild('SnowPatches149'))
local Fx=require(RS:WaitForChild('ClientFxBudget'))
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
local seats=0 -- bumped whenever a tile is seated or released (the rates pass runs again)
local stepClock,gustClock,patchClock=0,0,0
local rayParams=RaycastParams.new();rayParams.FilterType=Enum.RaycastFilterType.Exclude;rayParams.IgnoreWater=true
-- (the hub snow's ground rays pass through what does not collide: the R151 props, invisible zones, other players' accessories)
local snowRay=RaycastParams.new();snowRay.FilterType=Enum.RaycastFilterType.Exclude;snowRay.IgnoreWater=true;snowRay.RespectCanCollide=true
local rayChar,rayInit=nil,false

local function cast(x,y,z,dy,params)
 local ok,hit=pcall(workspace.Raycast,workspace,V3(x,y,z),V3(0,dy,0),params or rayParams)
 if ok then return hit end
 return nil
end
local function setRayFilter()
 local c=player.Character
 if not rayInit or c~=rayChar then
  rayInit=true;rayChar=c;rayParams.FilterDescendantsInstances=c and{folder,c}or{folder};snowRay.FilterDescendantsInstances=rayParams.FilterDescendantsInstances
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
 if t.Key then tileOf[t.Key]=nil;tileCount-=1;seats+=1 end
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
 t.Key=W.CellKey(i,j);tileOf[t.Key]=t;tileCount+=1;t.I,t.J=i,j;seats+=1
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
-- R151 performance: the rates only change when the player moved (a quarter stud), the fade blend moved, a tile was seated / released, or the
-- profile / tier changed; otherwise the pass is skipped (a player standing in the rain cost 25 weight + rate evaluations ten times a second
-- for nothing - no emitter property changed anyway). Splashes: a share of the landing drops (W.SplashShare: fewer far away and on lower tiers).
local rateFx,rateFz,rateBlend,rateSeats,rateP,rateTier=nil,nil,-1,-1,nil,nil
local function updateRates()
 local p=profile
 if not p or blend<=0 or not inBase then
  if rateP~=false or rateSeats~=seats then for _,t in ipairs(tiles)do if t.Key then quiet(t)end end;rateP,rateSeats=false,seats end
  return
 end
 if rateP==p and rateBlend==blend and rateSeats==seats and rateTier==tierNow and abs(fx-rateFx)<.25 and abs(fz-rateFz)<.25 then return end
 rateP,rateBlend,rateSeats,rateTier,rateFx,rateFz=p,blend,seats,tierNow,fx,fz
 local sum=0
 for _,t in ipairs(tiles)do if t.Key and t.Ok then
  local hw,hd=t.CW/2,t.CD/2
  t.Wt=W.Weight(W.RectDistance(fx,fz,t.CX-hw,t.CX+hw,t.CZ-hd,t.CZ+hd),tierCfg.Near,tierCfg.Far)
  sum+=t.Area*t.Wt
 end end
 local scale=W.Scale(p,sum*p.Density)
 local splash=p.Splash;local S=W.Splash
 for _,t in ipairs(tiles)do if t.Key then
  if t.Ok then
   local rate=W.Rate(p,scale,t.Wt,t.Area)*blend
   t.Rate=setRate(t.Emitter,t.Rate,rate)
   local s=splash and t.Wt>=tierCfg.SplashMin and rate>0
   t.SprayRate=setRate(t.Spray,t.SprayRate,s and min(S.MaxRate,rate*W.SplashShare(S.SprayShare,t.Wt,tierNow))or 0)
   t.RippleRate=setRate(t.Ripple,t.RippleRate,s and min(S.MaxRate,rate*W.SplashShare(S.RippleShare,t.Wt,tierNow))or 0)
  else quiet(t)end
 end end
end
-- Gusts (4 Hz): a tile's acceleration is rewritten when the wind moved by .15 (X) / .05 (Z) right by the player, up to three times that far
-- away (R151: the far tiles' drops are small on screen; about half the writes).
local function updateGusts(now)
 local p=profile;if not p or p.Gust<=0 then return end
 for _,t in ipairs(tiles)do if t.Key and t.Ok and t.Rate>0 then
  local ax,az=W.Wind(p,now,t.CX)
  local k=3-2*(t.Wt or 1)
  if abs(ax-t.AX)>.15*k or abs(az-t.AZ)>.05*k then t.AX,t.AZ=ax,az;t.Emitter.Acceleration=V3(ax,-p.Gravity,az)end
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

-- Snow over the whole hub (blizzard, R151) --------------------------------------------------------------------------------------
-- R151 (owner: "make sure the snow piles are visible throughout and not just when players walk into an area"; "bigger and more combined"):
-- R149 laid small patches in a radius around the player. Now one fixed layout of big drifts covers the whole hub (HubSnow151.Layout: wall
-- banks, corner drifts, fence banks, open drifts, a sprinkle inside the bases; the same for every client), seen from anywhere in the hub.
-- Each drift is checked once against the avoid list (beds, paths, treadmills, pedestals, the market, Verity, displays, leaderboards, ground
-- titles, R151 festival parts, 'SnowAvoid' tags, holes, packs) and its ground is raycast once (only the floor / a base pad / a 'SnowGround'
-- part counts as ground); the result is kept for the session and looked at again only when the avoid list changes (streaming in a bed, a
-- display ...) or, for ground that was not streamed in yet, a few seconds later. Bound drifts follow WeatherWorld149.Level (one snow
-- history: fade in 10-20 s, out 20-40 s), take their lobes by distance band (LOD, within the tier's part budget) and are released when the
-- player is far from the hub (the track behind the 48-stud walls) or when everything has faded.
local Hub=require(RS:WaitForChild('HubSnow151'))
local CS=game:GetService('CollectionService')
local events=W.NewEvents()
local poolW=nil;local hubCfg=Hub.Tier(3)
local layout={N=0};local hub=nil;local hubSig=nil;local hubClock=99
local stat,gyOf,maskOf,farOf,scaleOf,oxOf,ozOf,retryAt,tries={}, {}, {}, {}, {}, {}, {}, {}, {}  -- per drift. stat: nil unchecked, 1 ok, 2 below the tier, 3 avoided / no ground, 4 not streamed in yet

local recOf={};local boundList,boundN={},0
local checkCursor,lodCursor,fadeCursor=1,1,1
local OK,TIER,AVOIDED,PENDING=1,2,3,4
local RETRY=3                                    -- seconds before a drift whose ground was not there (streaming) is looked at again
local AVOID_EVERY=4                              -- the avoid list is re-read this often while there is snow (and at once when something relevant appears)
local avoidN,avoidSig,avoidDirty,avoidClock=0,-1,true,99
local AB={}                                      -- avoid boxes, 6 numbers each: cx, cz, hx, hz (half sizes + margin), ux, uz (the box's own X axis)
local AC,acN={},0                                -- avoid circles (holes, packs): x, z, r
local basesWatch,basesOf,holesWatch,holeConns=nil,nil,nil,{}
local function markAvoid()avoidDirty=true end
-- a ReplicatedStorage module of the R151 festival square, if this place has it (looked for again until it is there)
local festivalMods={}
local function festival(name)
 local m=festivalMods[name]
 if m==nil then
  local mod=RS:FindFirstChild(name);if not mod then return nil end
  local ok,v=pcall(require,mod)
  m=ok and type(v)=='table'and v or false;festivalMods[name]=m
 end
 return m or nil
end

-- a part's world extents (it may be turned): centre, half sizes along X / Y / Z
local function extents(part)
 local cf,s=part.CFrame,part.Size;local rv,up=cf.RightVector,cf.UpVector;local lv=rv:Cross(up)
 return cf.Position,(abs(rv.X)*s.X+abs(up.X)*s.Y+abs(lv.X)*s.Z)/2,(abs(rv.Y)*s.X+abs(up.Y)*s.Y+abs(lv.Y)*s.Z)/2,(abs(rv.Z)*s.X+abs(up.Z)*s.Y+abs(lv.Z)*s.Z)/2
end
-- The hub's description from the map (HubSnow151.Default for what has not streamed in). Returns the hub and a signature.
local function readHub(map)
 local D=Hub.Default
 local h={X0=D.X0,X1=D.X1,Z0=D.Z0,Z1=D.Z1,Top=D.Top,Gap=D.Gap,Pads={},Area=area}
 local lobby=map:FindFirstChild('Lobby');local fl=lobby and lobby:FindFirstChild('LobbyFloor')
 if fl and fl:IsA('BasePart')then local c,_,hy=extents(fl);h.Top=c.Y+hy end
 local wf=map:FindFirstChild('ChestChaseWalls')
 if wf then
  for _,w in ipairs(wf:GetChildren())do if w:IsA('BasePart')then
   local c,hx,_,hz=extents(w);local n=w.Name
   if n=='LobbyLeftWall'then h.X0=c.X+hx elseif n=='LobbyRightWall'then h.X1=c.X-hx
   elseif n=='LobbyBackWall'then h.Z0=c.Z+hz elseif n=='LobbyFrontWallRight'then h.Z1=c.Z-hz;h.Gap=c.X-hx end
  end end
 end
 local bases=map:FindFirstChild('Bases')
 if bases then
  for i,b in ipairs(bases:GetChildren())do
   local pad=b:FindFirstChild('Pad')
   if pad and pad:IsA('BasePart')then
    local c,hx,hy,hz=extents(pad) -- (a pad may be turned a quarter)
    local p={Index=tonumber(b:GetAttribute('BaseIndex'))or tonumber(b.Name:match('(%d+)$'))or i,X0=c.X-hx,X1=c.X+hx,Z0=c.Z-hz,Z1=c.Z+hz,Top=c.Y+hy}
    local o=Hub.FenceOut;p.FX0,p.FX1,p.FZ0,p.FZ1=p.X0-o,p.X1+o,p.Z0-o,p.Z1+o
    h.Pads[#h.Pads+1]=p
   end
  end
  table.sort(h.Pads,function(a,b)return a.Index<b.Index end)
 end
 local q=function(v)return floor(v*4+.5)end
 local sig=table.concat({q(h.X0),q(h.X1),q(h.Z0),q(h.Z1),q(h.Top),q(h.Gap),area.Valid and 1 or 0,q(area.X0 or 0),q(area.X1 or 0),q(area.Z0 or 0)},',')
 for _,p in ipairs(h.Pads)do sig=sig..'|'..p.Index..':'..q(p.X0)..','..q(p.Z0)..','..q(p.X1)..','..q(p.Z1)..','..q(p.Top)end
 return h,sig
end

-- Avoid list ---------------------------------------------------------------------------------------------------------------------------
local function addBox(cx,cz,hx,hz,ux,uz,m)
 local i=avoidN*6;avoidN+=1
 AB[i+1],AB[i+2],AB[i+3],AB[i+4],AB[i+5],AB[i+6]=cx,cz,hx+m,hz+m,ux,uz
end
-- a part / bounding box (cf, size) as a box on the ground: its own footprint when it stands upright, else its world-aligned shadow
local function addFrame(cf,size,m)
 local up=cf.UpVector
 if abs(up.Y)>.98 then
  local r=cf.RightVector;local l=math.sqrt(r.X*r.X+r.Z*r.Z)
  if l>1e-3 then addBox(cf.X,cf.Z,size.X/2,size.Z/2,r.X/l,r.Z/l,m);return end
 end
 local rv=cf.RightVector;local lv=rv:Cross(up) -- (the part's Z axis, up to its sign: only its size along each world axis is used)
 local hx=(abs(rv.X)*size.X+abs(up.X)*size.Y+abs(lv.X)*size.Z)/2
 local hz=(abs(rv.Z)*size.X+abs(up.Z)*size.Y+abs(lv.Z)*size.Z)/2
 addBox(cf.X,cf.Z,hx,hz,1,0,m)
end
local function addThing(o,m)
 if o:IsA('BasePart')then addFrame(o.CFrame,o.Size,m)
 elseif o:IsA('Model')then local ok,cf,size=pcall(o.GetBoundingBox,o);if ok and cf and size and size.X>0 then addFrame(cf,size,m)end
 elseif o:IsA('Folder')then for _,c in ipairs(o:GetChildren())do if c:IsA('BasePart')or c:IsA('Model')then addThing(c,m)end end end
end
-- a festival / dressing container: its ground-level parts one by one (a street network is one model as big as the hub; its own box would
-- leave no snow anywhere), anything standing higher by its own box
local function addGround(o,top,m,budget)
 for _,d in ipairs(o:GetDescendants())do
  if budget<=0 then break end
  if d:IsA('BasePart')and d.Transparency<.98 then
   local c,s=d.CFrame,d.Size
   if c.Y-(abs(c.UpVector.Y)*s.Y)/2<=top+2 then addFrame(c,s,m);budget-=1 end
  end
 end
 return budget
end
local function addCircle(x,z,r)acN+=1;local i=acN*3;AC[i-2],AC[i-1],AC[i]=x,z,r end
local function findHoles(map)
 local runtime=map:FindFirstChild('_GameplayRuntime');local f=runtime and runtime:FindFirstChild('TrackHoles')
 if not f then runtime=workspace:FindFirstChild('_GameplayRuntime');f=runtime and runtime:FindFirstChild('TrackHoles')end
 return f or map:FindFirstChild('TrackHoles')
end
local function readAvoid(map)
 avoidN=0;acN=0
 local top=hub and hub.Top or Hub.Default.Top
 local bases=map:FindFirstChild('Bases')
 if bases then
  if bases~=basesOf then -- (a refreshed map has a new Bases: watch that one; the old connection goes)
   if basesWatch then basesWatch:Disconnect()end
   basesOf=bases
   -- what streams in under a base: one byte compare first ('D' = 68 for DirtPlot_n), then only a base's own children count
   basesWatch=bases.DescendantAdded:Connect(function(d)
    local n=d.Name
    if byte(n,1)==68 and n:match('^DirtPlot_%d')then avoidDirty=true;return end
    local p=d.Parent;if p and(p==bases or p.Parent==bases)then avoidDirty=true end
   end)
  end
  for _,b in ipairs(bases:GetChildren())do
   if b:IsA('BasePart')then
    if b.Name~='Pad'then addThing(b,byte(b.Name,1)==68 and .8 or 1.5)end
   else
    for _,c in ipairs(b:GetChildren())do
     local n=c.Name
     if n=='Pad'or n:match('^GardenFence')or n=='PerimeterFence'or n=='GardenBedBorders'then -- (the fence / pad hide snow at their feet; the borders sit round the beds)
     elseif n=='GardenPlots'then for _,p in ipairs(c:GetChildren())do if p:IsA('BasePart')then addThing(p,.8)end end
     elseif n:match('^GardenDesign')then for _,p in ipairs(c:GetDescendants())do if p:IsA('BasePart')then addThing(p,.5)end end
     elseif c:IsA('BasePart')or c:IsA('Model')or c:IsA('Folder')then addThing(c,byte(n,1)==68 and .8 or 2.5)end
    end
   end
  end
 end
 local eco=map:FindFirstChild('EconomyHub')
 if eco then for _,c in ipairs(eco:GetChildren())do
  if c:IsA('Folder')then for _,g in ipairs(c:GetChildren())do addThing(g,2.5)end else addThing(c,c.Name=='MerchantStands'and 3 or 2.5)end
 end end
 local lobby=map:FindFirstChild('Lobby')
 if lobby then for _,c in ipairs(lobby:GetChildren())do if c.Name~='LobbyFloor'then addThing(c,1)end end end
 local displays=map:FindFirstChild('HubDisplays151')
 if displays then for _,c in ipairs(displays:GetChildren())do addThing(c,3)end end
 local budget=1500
 -- the R151 Seed Festival Square (HubDecor151, built by the server): its streets, squares, plazas, spurs, mats and curbs part by part, plus
 -- the kit's own table of the main streets and plazas (kept clear before their parts have streamed in), and the arches' and the gate towers'
 -- feet. Not avoided: the dressed walls, murals and banners (the banks lean on the plinth), and the client's props (HubLife151: trees,
 -- benches, lamps stand in the snow; flower beds are raised and hide it; grass patches are flat discs at 4.07 / 4.12, planes no drift top
 -- uses - HubSnow151.Keep).
 local decor=map:FindFirstChild('HubDecor151')
 if decor then
  local kit=festival('HubDecorKit151')
  if kit and kit.Streets then
   for _,s in ipairs(kit.Streets)do addBox((s[1]+s[2])/2,(s[3]+s[4])/2,abs(s[2]-s[1])/2,abs(s[4]-s[3])/2,1,0,1)end
   for _,d in ipairs(kit.Discs or{})do addCircle(d[1],d[2],d[3]+1)end
  end
  for _,name in ipairs({'Paths','BaseEntrances','Gate'})do local m=decor:FindFirstChild(name);if m then budget=addGround(m,top,name=='Paths'and 1 or 1.5,budget)end end
 end
 for _,name in ipairs(Hub.AvoidFolders)do
  local f=map:FindFirstChild(name)
  if f then budget=addGround(f,top,1,budget)end
 end
 for _,o in ipairs(CS:GetTagged('SnowAvoid'))do if o:IsDescendantOf(workspace)then addThing(o,1.5)end end
 local seeds=map:FindFirstChild('Seeds')
 if seeds and hub then for _,m in ipairs(seeds:GetChildren())do
  local ok,pivot=pcall(m.GetPivot,m)
  if ok and pivot and pivot.X>hub.X0-10 and pivot.X<hub.X1+10 and pivot.Z>hub.Z0-10 and pivot.Z<hub.Z1+10 then addCircle(pivot.X,pivot.Z,8)end
 end end
 local holes=findHoles(map)
 if holes then
  -- a hole must never sit under snow: its changes re-read the list at once (re-hooked when the folder is replaced)
  if holes~=holesWatch then
   for _,c in ipairs(holeConns)do c:Disconnect()end;table.clear(holeConns)
   holesWatch=holes
   holeConns[1]=holes.DescendantAdded:Connect(markAvoid);holeConns[2]=holes.DescendantRemoving:Connect(markAvoid)
  end
  for _,model in ipairs(holes:GetChildren())do
   local pit=model:FindFirstChild('Pit')
   if pit and pit:IsA('BasePart')then
    local rim=model:FindFirstChild('Rim');local d=max(pit.Size.Y,pit.Size.Z)
    if rim and rim:IsA('BasePart')then d=max(d,rim.Size.Y,rim.Size.Z)end
    addCircle(pit.Position.X,pit.Position.Z,d*.5+.3)
   end
  end
 end
 local sig=avoidN*7919+acN*104729
 for i=1,avoidN*6 do local v=AB[i];if v then sig=(sig*31+floor(v*8))%1000000007 end end
 for i=1,acN*3 do sig=(sig*31+floor(AC[i]*8))%1000000007 end
 return sig
end
-- Does lobe l of drift s (stretched by f) reach anything on the avoid list?
local function avoided(s,l,f)
 local cx,cz=s.X+s.LX[l],s.Z+s.LZ[l];local reach=max(s.LA[l],s.LB[l])*f
 for i=0,(avoidN-1)*6,6 do
  local bx,bz,hx,hz=AB[i+1],AB[i+2],AB[i+3],AB[i+4]
  local rr=reach+hx+hz -- (a cheap first test: the box's half sizes summed cover its rotated reach)
  if abs(cx-bx)<rr and abs(cz-bz)<rr and Hub.LobeHitsBox(s,l,f,bx,bz,hx,hz,AB[i+5],AB[i+6])then return true end
 end
 for i=1,acN*3,3 do if Hub.LobeHitsCircle(s,l,f,AC[i],AC[i+1],AC[i+2])then return true end end
 return false
end

-- Drifts -------------------------------------------------------------------------------------------------------------------------------
local function dropPatch(rec)
 local last=boundList[boundN];boundList[rec.Idx]=last;last.Idx=rec.Idx;boundList[boundN]=nil;boundN-=1
 recOf[rec.Key]=nil;Patches.Release(poolW,rec)
end
local function clearPatches()
 if poolW then while boundN>0 do dropPatch(boundList[boundN])end end
end
local function buildPatchPool()
 if poolW then clearPatches();Patches.Destroy(poolW)end
 poolW=Patches.new(patchFolder,hubCfg.Discs,max(layout.N,1),4)
end
local function forget(k)stat[k]=nil end
local function newLayout(h,sig)
 clearPatches()
 hub,hubSig=h,sig
 Hub.Layout(h,layout)
 table.clear(stat);table.clear(gyOf);table.clear(maskOf);table.clear(farOf);table.clear(scaleOf);table.clear(oxOf);table.clear(ozOf);table.clear(retryAt);table.clear(tries)
 checkCursor=1
 buildPatchPool()
end
local function isGround(inst)
 local n=inst.Name
 return n=='LobbyFloor'or n=='Pad'or CS:HasTag(inst,'SnowGround')
end
-- One ray straight down at (x, z) from above the expected ground: the surface height, or false (not ground / not flat / not at that height),
-- or nil (nothing there: not streamed in).
local function groundY(x,z,base)
 local hit=cast(x,base+30,z,-60,snowRay)
 if not hit then return nil end
 if hit.Normal.Y<.9 or abs(hit.Position.Y-base)>.35 or not isGround(hit.Instance)then return false end
 return hit.Position.Y
end
-- (a point inside a wall - a bank or corner drift reaches into it, the wall hides that part - is not sampled)
local function inside(x,z)return x>hub.X0+.5 and x<hub.X1-.5 and z>hub.Z0+.5 and z<hub.Z1-.5 end
local function lobeGround(s,l,base)
 local y=groundY(s.X+s.LX[l],s.Z+s.LZ[l],base)
 if l==1 and y then -- the main lobe: both ends of its long axis too
  local a=s.LA[1]*.75;local dx,dz=math.sin(s.LY[1])*a,math.cos(s.LY[1])*a
  local y2,y3=y,y
  if inside(s.X+dx,s.Z+dz)then y2=groundY(s.X+dx,s.Z+dz,base);if not y2 then return y2 end end
  if inside(s.X-dx,s.Z-dz)then y3=groundY(s.X-dx,s.Z-dz,base);if not y3 then return y3 end end
  if max(y,y2,y3)-min(y,y2,y3)>.35 then return false end
  y=max(y,y2,y3)
 end
 return y
end
-- A drift whose main lobe reaches something is tried smaller (the lawns between the R151 streets are narrower than a big drift): the same
-- shape at 72 % / 50 % / 35 %, shrunk towards its anchor (a bank stays against its wall or fence); an open / inner drift may also slide
-- sideways by up to (1 - scale) x its reach, so it never leaves the circle HubSnow151.Assign gave it its heights for. ws is the scratch
-- copy being tried.
local SCALES={1,.72,.5,.35}
local NUDGE={0,0,1,0,-1,0,0,1,0,-1,.7,.7,-.7,.7,.7,-.7,-.7,-.7} -- (x, z) directions
local ws={LX={},LZ={},LA={},LB={},LY={}}
local function scaled(s,sc,ox,oz)
 if sc==1 and ox==0 and oz==0 then return s end
 ws.X,ws.Z,ws.N=s.AX+(s.X-s.AX)*sc+ox,s.AZ+(s.Z-s.AZ)*sc+oz,s.N
 for l=1,s.N do ws.LX[l],ws.LZ[l],ws.LA[l],ws.LB[l],ws.LY[l]=s.LX[l]*sc,s.LZ[l]*sc,s.LA[l]*sc,s.LB[l]*sc,s.LY[l]end
 return ws
end
-- Check drift k (avoid list + ground). Sets stat / gyOf / maskOf / farOf / scaleOf / oxOf / ozOf.
local function checkDrift(k,now)
 local s=layout[k]
 if s.Pri<hubCfg.MinPri then stat[k]=TIER;return end
 local v,sc,ox,oz=nil,1,0,0
 local slide=(s.Kind=='open'or s.Kind=='inner')and #NUDGE/2 or 1
 for _,c in ipairs(SCALES)do
  local d=(1-c)*s.Reach
  for n=1,(c<1 and slide or 1)do
   local dx,dz=NUDGE[2*n-1]*d,NUDGE[2*n]*d
   local t=scaled(s,c,dx,dz)
   if not avoided(t,1,1)then v,sc,ox,oz=t,c,dx,dz;break end
  end
  if v then break end
 end
 if not v then stat[k]=AVOIDED;return end
 local mask=0
 for l=2,v.N do if avoided(v,l,1)then mask+=2^(l-1)end end
 local base=hub.Top
 if s.Pad>0 then for _,p in ipairs(hub.Pads)do if p.Index==s.Pad then base=p.Top end end end
 local y=-math.huge
 for l=1,v.N do
  if mask%(2^l)<2^(l-1)then
   local g=lobeGround(v,l,base)
   if g==nil or g==false then
    if l==1 then
     -- nothing under the drift (not streamed in yet) or someone / something standing there: look again in a few seconds (three tries
     -- for "something else is there"; nothing at all is retried for as long as it takes)
     tries[k]=(tries[k]or 0)+(g==nil and 0 or 1)
     if tries[k]>=3 then stat[k]=AVOIDED else stat[k]=PENDING;retryAt[k]=now+RETRY end
     return
    end
    mask+=2^(l-1)
   else y=max(y,g)end
  end
 end
 gyOf[k]=y;maskOf[k]=mask;farOf[k]=not avoided(v,1,s.Far);scaleOf[k],oxOf[k],ozOf[k]=sc,ox,oz;stat[k]=OK
end
local function levelOf(rec,now)return W.Level(events,now,rec.Spec.DIn,rec.Spec.DOut)end
local function bindDrift(k,now)
 local rec=Patches.Take(poolW);if not rec then return false end
 local s,d,mask,sc=layout[k],rec.Spec,maskOf[k],scaleOf[k]or 1
 if not d.LT then d.LX,d.LZ,d.LA,d.LB,d.LY,d.LT={}, {}, {}, {}, {}, {}end -- (once per pooled record)
 local n=0
 for l=1,s.N do if mask%(2^l)<2^(l-1)then
  n+=1;d.LX[n],d.LZ[n],d.LA[n],d.LB[n],d.LY[n],d.LT[n]=s.LX[l]*sc,s.LZ[l]*sc,s.LA[l]*sc,s.LB[l]*sc,s.LY[l],Hub.Thickness(s,l)
 end end
 d.N=n;d.X,d.Z,d.Shade,d.DIn,d.DOut=s.AX+(s.X-s.AX)*sc+(oxOf[k]or 0),s.AZ+(s.Z-s.AZ)*sc+(ozOf[k]or 0),s.Shade,s.DIn,s.DOut
 rec.Key=k;recOf[k]=rec;boundN+=1;boundList[boundN]=rec;rec.Idx=boundN
 rec.T=W.PatchTransparency(levelOf(rec,now));rec.Far=farOf[k]and s.Far or 1
 local want=Hub.Lobes(hubCfg,math.sqrt((s.X-fx)^2+(s.Z-fz)^2),n,0)
 if Patches.FillStack(poolW,rec,want,rec.Far,gyOf[k]+Hub.Rise)==0 then dropPatch(rec)end
 return true
end
local function nearHub(extra)
 if not hub then return false end
 return W.RectDistance(fx,fz,hub.X0,hub.X1,hub.Z0,hub.Z1)<=hubCfg.Keep+(extra or 0)
end
local function updatePatches(now,dt)
 local map=workspace:FindFirstChild('ChestChaseMap')
 if not map then clearPatches();return end
 -- the hub's description (2 s), then the avoid list (on a relevant change, or every AVOID_EVERY s)
 hubClock+=dt
 if hubClock>=2 or not hub then
  hubClock=0
  local h,sig=readHub(map)
  if sig~=hubSig then newLayout(h,sig);avoidDirty=true end
 end
 avoidClock+=dt
 if avoidDirty or avoidClock>=AVOID_EVERY then
  avoidDirty=false;avoidClock=0
  local sig=readAvoid(map)
  if sig~=avoidSig then
   avoidSig=sig
   -- the list changed: bound drifts that now reach something go, avoided ones are looked at again
   for i=boundN,1,-1 do local rec=boundList[i];local k=rec.Key
    local s=rec.Spec;local hit=false -- (the drift as drawn: its kept lobes, at its scale)
    for l=1,s.N do if avoided(s,l,(l==1 and rec.Lobes==1)and rec.Far or 1)then hit=true;break end end
    if hit then dropPatch(rec);forget(k)end
   end
   for k=1,layout.N do if stat[k]==AVOIDED then forget(k);tries[k]=nil end end
  end
 end
 -- far from the hub (on the track): nothing is drawn; back near it the drifts are bound again (their checks are kept)
 if boundN>0 and not nearHub(hubCfg.Hyst*2)then clearPatches()end
 if not(haveFocus and nearHub())then return end
 -- check / bind a few drifts per step (each drift is checked once; pending ones when their retry is due)
 local budget=hubCfg.Bind;local n=layout.N
 if n>0 then
  for _=1,n do
   if budget<=0 then break end
   if checkCursor>n then checkCursor=1 end
   local k=checkCursor;checkCursor+=1
   local st=stat[k]
   if st==nil or(st==PENDING and now>=retryAt[k])then

    checkDrift(k,now);budget-=1;st=stat[k]
   end
   if st==OK and not recOf[k]and layout[k].Pri>=hubCfg.MinPri then if bindDrift(k,now)then budget-=1 end end -- (a drift checked on a higher tier waits)
  end
 end
 -- level of detail: a slice of the bound drifts per step, a few reshapes at most
 local reshape=hubCfg.Reshape
 for _=1,min(boundN,24)do
  if lodCursor>boundN then lodCursor=1 end
  local rec=boundList[lodCursor];lodCursor+=1
  local s=rec.Spec
  local want=Hub.Lobes(hubCfg,math.sqrt((s.X-fx)^2+(s.Z-fz)^2),s.N,rec.Lobes)
  if want~=rec.Lobes and reshape>0 then reshape-=1;Patches.FillStack(poolW,rec,want,rec.Far,rec.Y)end
 end
end
local function fadePatches(now)
 if boundN==0 then return end
 for _=1,min(boundN,24)do
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
  if tierWant~=tierNow and now-tierSince>=W.TierHold then
   tierNow=tierWant;tierCfg=W.Tier(tierNow);hubCfg=Hub.Tier(tierNow);releaseAll();win.I=nil
   -- the hub's snow takes the new tier's part budget; drifts skipped for the old tier's priority floor are looked at again
   for kk=1,layout.N do if stat[kk]==TIER then stat[kk]=nil end end
   buildPatchPool()
   if profile and shownKind~='Clear'then setKind(shownKind,now)end
  end
 end
 tierCfg=W.Tier(tierNow);hubCfg=Hub.Tier(tierNow)
 if not poolW then buildPatchPool()end
 -- weather kind
 local k=RS:GetAttribute('GlobalWeather');if not W.Kinds[k]then k='Clear'end
 if k~=kind then kind=k end
 local wasReduced=profile and profile.Gust==0
 if k~='Clear'and(shownKind~=k or(profile~=nil and wasReduced~=reduced))then shownKind=k;setKind(k,now)end
 -- clear sky and nothing left to fade out or show (the tiles went quiet in the step the fade ended): no base check, no area read, no ground
 -- raycast - that was ~10 raycasts and ~150 attribute reads a second for nothing. Weather starting is noticed above (kind / shownKind).
 if kind=='Clear'and shownKind=='Clear'and blend<=0 and boundN==0 and not W.Active(events,now)then return end
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
  if not W.SameArea(areaNext,area)then area,areaNext=areaNext,area;releaseAll();hubClock=99 end -- (the hub's layout is read again with it)
 end
 -- where the player is: weather belongs to the base (R129), i.e. everywhere but the track. R151: the track rectangle above (the biomes'
 -- range, BiomeMood.Stage's own rule for a contiguous track) instead of BiomeMood.Stage, which built 14 attribute-name strings and read 14
 -- attributes ten times a second whenever the player stood within the field's width (the whole middle of the hub)
 inBase=true
 if p and hasRoot and map and area.Valid then
  inBase=not(p.Y>=-20 and p.Y<=300 and abs(p.X)<=area.X1 and p.Z>=area.Z0 and p.Z<area.Z1)
 end
 local active=kind~='Clear'and inBase and haveFocus
 blend=max(0,min(1,blend+(active and dt/W.Ramp.Up or-dt/W.Ramp.Down)))
 if blend<=0 and kind=='Clear'and shownKind~='Clear'then shownKind='Clear';profile=nil end
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
 -- the hub's snow follows the weather, not the player's place: Blizzard = snowing
 local snowing=kind=='Blizzard'
 if W.Mark(events,now,snowing)then fadeCursor=1 end
 W.Prune(events,now)
 if W.Active(events,now)then updatePatches(now,dt)
 elseif boundN>0 then clearPatches()end
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
 for _,c in ipairs(holeConns)do c:Disconnect()end;table.clear(holeConns)
 for _,t in ipairs(tiles)do t.Emitter:Clear();t.Spray:Clear();t.Ripple:Clear()end
 table.clear(tiles);table.clear(tileOf);table.clear(recOf);table.clear(boundList);boundN=0
 folder:Destroy()
end
script.Destroying:Connect(cleanup)
-- (the offline tests set R151TestHook on the script to look inside; in the game nothing is returned)
if script:GetAttribute('R151TestHook')then
 return{Layout=function()return layout end,Hub=function()return hub end,Stat=stat,Scale=scaleOf,Mask=maskOf,Bound=function()return boundList,boundN end,
  Pool=function()return poolW end,HubCfg=function()return hubCfg end,Avoid=function()return AB,avoidN,AC,acN end}
end
