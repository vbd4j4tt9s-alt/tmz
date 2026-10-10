-- R149 (owner): "rework weather and make it so that it is not a camera-only thing". Pure config + maths for the world-anchored weather
-- (WeatherWorld149.client.lua: rain / thunder / blizzard tiles, ground splashes, snow patches) and the permanent Snow-biome patches
-- (SnowBiome149.client.lua). No Instances, no Roblox services, no randomness: every layout is a hash of grid cells, so every client builds
-- the same patches.
--
--  TILES   rain / snow is born by a pooled grid of invisible emitter tiles fixed in WORLD space (cells of Tile studs, centres snapped to the
--          grid), a few studs above the cloud height. The grid follows the PLAYER cell by cell (hysteresis), never the camera: turning or
--          moving the camera does not move a tile, and a particle already falling is never dragged along.
--  FALL    a particle is born Height studs above the ground with Speed (down) and Gravity (extra downward acceleration); its lifetime is the
--          time to fall exactly Height (FallTime), so it reaches the ground and is gone. Wind is a horizontal acceleration (always the same
--          sign, gusts only change its size), so the sideways drift of a particle is known and the weather area is clipped with it (Clip).
--  AREA    weather exists where it did in R129: the base. The track is a rectangle (Area); a tile is cut to the part of it outside the track
--          (cut back by the drift toward the track), so nothing falls on the track.
--  BUDGET  Profile(kind, tier) -> live-particle cap per tier; tile rates are weighted by distance from the player (Weight) and scaled so
--          the sum of rate x lifetime never passes the cap.
--  PATCHES snow patches are made of 1..3 overlapping flat ellipses (an irregular blob), laid out by hash per grid cell. Weather patches fade
--          in over 10-20 s and out over 20-40 s (Level folds the weather's snow / no snow history, so a patch bound late is already right);
--          the Snow biome's patches are permanent (BiomeSpec). R151: the blizzard's snow is laid over the WHOLE hub by HubSnow151 (big drifts,
--          one fixed layout); PatchSpec / Tiers[n].Patch below are the R149 radius patches, kept for reference and the R149 tests only. The
--          fade history (Mark / Level / Prune) and PatchTransparency are what HubSnow151's drifts use.
local W={Version=149}
local floor,max,min,sqrt,sin,cos,tan,rad,pi=math.floor,math.max,math.min,math.sqrt,math.sin,math.cos,math.tan,math.rad,math.pi
local C3=Color3.fromRGB
local sparkles='rbxasset://textures/particles/sparkles_main.dds'

W.StageCount=7
W.StartKey,W.EndKey={}, {}
for id=1,W.StageCount do W.StartKey[id]='BiomeStartZ_'..id;W.EndKey[id]='BiomeEndZ_'..id end

local function hash(a,b,c)
 local h=bit32.bxor((a+100003)*73856093%4294967296,(b+100019)*19349663%4294967296)
 h=bit32.bxor(h,((c or 0)+101)*83492791%4294967296)
 h=bit32.bxor(h,bit32.rshift(h,13));h=(h*1664525+1013904223)%4294967296;h=bit32.bxor(h,bit32.rshift(h,16))
 return h
end
local function unit(a,b,c)return hash(a,b,c)/4294967296 end
W.Hash,W.Unit=hash,unit

-- Weather kinds (WeatherTraits.Events: Rain, Thunderstorm, Blizzard). Height = cloud height above the ground the particles are born at,
-- Speed = downward speed at birth (+-SpeedJitter), Gravity = extra downward acceleration, WindX / WindZ = horizontal acceleration
-- (studs/s^2; always the same sign, Gust 0..1 scales it up and down), Spread = emission cone (degrees), Density = live particles per
-- square stud right around the player (before the tier cap).
W.SpeedJitter=.03
W.Kinds={
 Rain={Snow=false,Height=46,Speed=62,Gravity=18,WindX=9,WindZ=-1.5,Gust=.25,Spread=2.5,Density=.12,
  Texture=sparkles,Color=C3(171,212,246),Size=.55,Emission=.13,Fade=.3,Splash=true},
 Thunderstorm={Snow=false,Height=52,Speed=70,Gravity=20,WindX=14,WindZ=-2.5,Gust=.35,Spread=3,Density=.16,
  Texture=sparkles,Color=C3(150,190,235),Size=.6,Emission=.15,Fade=.26,Splash=true},
 Blizzard={Snow=true,Height=40,Speed=11,Gravity=0,WindX=2.6,WindZ=-.8,Gust=.4,Spread=6,Density=.2,
  Texture=sparkles,Color=C3(238,250,255),Size=.34,Emission=.24,Fade=.12,Splash=false},
}
-- Ground impact (rain / thunder): a small spray of droplets and a flat ripple, on a ground tile just above the floor, for a SHARE of the
-- landing drops. R151 (owner: "some of the droplets can have impact with the ground, not all"): the shares went .4 / .3 -> .2 / .14, and they
-- thin out away from the player and on lower tiers (SplashShare: x Tier[tier], x (Near + (1 - Near) x the tile's weight)). The particle cap
-- still reserves room for the old shares (BudgetSpray / BudgetRipple -> Profile.SplashFactor), so the falling rain is exactly as dense as
-- before and the splashes simply take fewer particles.
W.Splash={Rise=.12,SprayShare=.2,RippleShare=.14,BudgetSpray=.4,BudgetRipple=.3,MaxRate=260,SprayLife={.18,.3},RippleLife={.45,.6},
 Tier={[3]=1,[2]=.75,[1]=.6},Near=.45}
function W.SplashShare(share,weight,tier)
 local S=W.Splash
 return share*(S.Tier[tier]or S.Tier[1])*(S.Near+(1-S.Near)*max(0,min(1,weight or 1)))
end
W.MaxTileRate=480 -- no emitter is asked for more than this
W.CapMargin=.975  -- rates are only rewritten when they moved by 2.5%; this keeps the stale ones under the cap

-- Quality tiers (ClientFxBudget 3 best .. 1 lowest; FastMode = 1). R = tiles each side of the player's cell (2 -> 5x5, 1 -> 3x3), Tile =
-- tile size, Cap = live particles (rate x lifetime, splashes too) over all tiles, Near / Far = distance (nearest point of a tile to the player) at which the
-- tile weight is 1 / MinWeight, SplashMin = lowest tile weight that gets ground splashes. Cap counts the splash particles as well. Patch = R149 weather snow patches (Radius around the
-- player, Discs = pooled flat parts; R151: the hub-wide drifts take their budgets from HubSnow151.Tiers), Biome = permanent Snow-biome patches (Lobes by distance band: <Near, <Mid, farther; Dust = the
-- sparse dusting on the keys). Tier 2 (phones) Cap 900 (R149 review: 1300 was ~13x R148's camera bubble; ~40% fewer particles right around the
-- player stay dense enough, the far tiles are the ones thinned).
W.MinWeight=.1
W.Tiers={
 [3]={R=2,Tile=50,Cap=3200,Near=15,Far=90,SplashMin=.3,Patch={Radius=130,Discs=210},
  Biome={Radius=170,Discs=300,Lobes={3,2,1},Near=70,Mid=120,Dust=true,Bind=40,Reshape=8}},
 [2]={R=1,Tile=50,Cap=900,Near=12,Far=70,SplashMin=.6,Patch={Radius=100,Discs=120},
  Biome={Radius=120,Discs=170,Lobes={3,2,1},Near=50,Mid=90,Dust=true,Bind=30,Reshape=6}},
 [1]={R=1,Tile=50,Cap=600,Near=10,Far=50,SplashMin=.99,Patch={Radius=70,Discs=50},
  Biome={Radius=80,Discs=60,Lobes={1,1,1},Near=0,Mid=0,Dust=false,Bind=20,Reshape=4}},
}
function W.Tier(tier)return W.Tiers[floor(tonumber(tier)or 1)]or W.Tiers[1]end
W.StepSeconds={[3]=.1,[2]=.1,[1]=.2}   -- weather update interval per tier
W.TierHold=3                            -- a tier change applies after it has held this long (seconds)
W.Ramp={Up=2,Down=1.5}                  -- seconds for the emission to fade in / out when the weather starts / ends

-- Fall maths -----------------------------------------------------------------------------------------------------------------
-- Time to fall h studs starting at speed v (down) with extra downward acceleration g.
function W.FallTime(h,v,g)
 if g<1e-6 then return h/v end
 return(-v+sqrt(v*v+2*g*h))/g
end
function W.FallDistance(v,g,t)return v*t+.5*g*t*t end

-- Profile(kind, tier, reduced) -> the numbers the emitters are set to (nil for Clear). LifeMin is the time for the SLOWEST particle to fall
-- Height, so every particle reaches the ground (the faster ones carry on a little below it, hidden by the floor).
function W.Profile(kind,tier,reduced)
 local k=W.Kinds[kind];if not k then return nil end
 local t=W.Tier(tier)
 local vmin,vmax=k.Speed*(1-W.SpeedJitter),k.Speed*(1+W.SpeedJitter)
 local life=W.FallTime(k.Height,vmin,k.Gravity)
 local p={Kind=kind,Snow=k.Snow,Height=k.Height,SpeedMin=vmin,SpeedMax=vmax,Gravity=k.Gravity,LifeMin=life,LifeMax=life*1.03,
  Spread=k.Spread,WindX=k.WindX,WindZ=k.WindZ,Gust=reduced and 0 or k.Gust,Density=k.Density*(reduced and .6 or 1),
  Cap=t.Cap*(reduced and .6 or 1),Splash=k.Splash==true,Tier=t,Look=k}
 p.LifeAvg=(p.LifeMin+p.LifeMax)/2
 -- splash particles per live drop (spray + ripple lifetimes x their share of landing drops): the cap counts them too
 local sp=W.Splash
 p.SplashFactor=k.Splash and(sp.BudgetSpray*(sp.SprayLife[1]+sp.SprayLife[2])/2+sp.BudgetRipple*(sp.RippleLife[1]+sp.RippleLife[2])/2)/p.LifeAvg or 0
 -- Largest sideways drift of a particle between birth and landing: wind (with the biggest gust) + the emission cone.
 local top=1+p.Gust;local l=p.LifeMax
 p.DriftX=.5*p.WindX*top*l*l;p.DriftZ=.5*p.WindZ*top*l*l
 p.Cone=k.Height*tan(rad(k.Spread))+.5
 -- How far a tile is cut back from the track on each side: tiles left of the track (-X) drift toward it when the wind is +X, and so on.
 p.InL=max(0,p.DriftX)+p.Cone;p.InR=max(0,-p.DriftX)+p.Cone
 p.InB=max(0,p.DriftZ)+p.Cone;p.InF=max(0,-p.DriftZ)+p.Cone
 return p
end
-- Wind acceleration at time t over world x (a gust wave travelling through the tiles; never changes sign).
function W.Wind(p,t,x)
 local m=1+p.Gust*sin(t*.9+x*.013)
 return p.WindX*m,p.WindZ*m
end

-- Grid ---------------------------------------------------------------------------------------------------------------------------
function W.Cell(v,size)return floor(v/size)end
function W.CellCenter(i,size)return(i+.5)*size end
function W.CellKey(i,j)return(i+8192)*16384+(j+8192)end
-- Re-centre the window on the player: the centre cell only changes once the player has left it by more than hyst studs. s = {I, J, Size}.
function W.Recenter(s,x,z,size,hyst)
 if s.I==nil or s.Size~=size then s.I,s.J,s.Size=floor(x/size),floor(z/size),size;return true end
 local x0,z0=s.I*size,s.J*size
 if x<x0-hyst or x>=x0+size+hyst or z<z0-hyst or z>=z0+size+hyst then s.I,s.J=floor(x/size),floor(z/size);return true end
 return false
end
function W.RectDistance(x,z,x0,x1,z0,z1)
 local dx=max(x0-x,0,x-x1);local dz=max(z0-z,0,z-z1)
 return sqrt(dx*dx+dz*dz)
end
-- Tile weight by distance: 1 near the player, MinWeight far away.
function W.Weight(d,near,far)
 if d<=near then return 1 end
 if d>=far then return W.MinWeight end
 return 1-(1-W.MinWeight)*(d-near)/(far-near)
end
-- Emission rate of a tile (drops per second) for its weight and clipped area; scale is the tier cap factor (Scale of the live drops,
-- Density x sum of weight x area).
function W.Rate(p,scale,weight,area)
 return min(W.MaxTileRate,scale*p.Density*area*weight/p.LifeAvg)
end
function W.Scale(p,liveSum)
 if liveSum<=0 then return 1 end
 return min(1,p.Cap*W.CapMargin/(liveSum*(1+p.SplashFactor)))
end

-- Weather area ---------------------------------------------------------------------------------------------------------------
-- The track as a rectangle (X +-(FieldWidth/2 + 2) like BiomeMood.Stage, Z from the first biome's start to the last one's end). Weather
-- belongs to everything outside it. map needs :GetAttribute; out is reused. out.Valid is false without any biome range.
function W.Area(map,out)
 out=out or {}
 local half=(tonumber(map:GetAttribute('FieldWidth'))or 180)/2+2
 local lo,hi=math.huge,-math.huge
 for id=1,W.StageCount do
  local a,b=map:GetAttribute(W.StartKey[id]),map:GetAttribute(W.EndKey[id])
  if type(a)=='number'and type(b)=='number'and b>a then lo=min(lo,a);hi=max(hi,b)end
 end
 out.X0,out.X1=-half,half
 out.Valid=hi>lo;out.Z0=out.Valid and lo or 0;out.Z1=out.Valid and hi or 0
 return out
end
function W.SameArea(a,b)return a.Valid==b.Valid and a.X0==b.X0 and a.X1==b.X1 and a.Z0==b.Z0 and a.Z1==b.Z1 end
-- Distance from a point to the track rectangle (0 inside).
function W.AreaDistance(a,x,z)
 if not a or not a.Valid then return math.huge end
 return W.RectDistance(x,z,a.X0,a.X1,a.Z0,a.Z1)
end
-- Clip a tile rectangle to the weather area. p carries the insets (Profile). Returns ok, cx, cz, width, depth of the largest piece outside
-- the track rectangle grown by the insets; ok is false when nothing usable is left. Allocates nothing.
W.MinPiece=8 -- a sliver this narrow would emit next to nothing
function W.Clip(a,x0,x1,z0,z1,p)
 if not a or not a.Valid then return true,(x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0 end
 local ax0,ax1,az0,az1=a.X0-p.InL,a.X1+p.InR,a.Z0-p.InB,a.Z1+p.InF
 if not(x0<ax1 and x1>ax0 and z0<az1 and z1>az0)then return true,(x0+x1)/2,(z0+z1)/2,x1-x0,z1-z0 end
 local best,bx0,bx1,bz0,bz1=0,0,0,0,0
 if x0<ax0 then local e=min(x1,ax0);local ar=(e-x0)*(z1-z0);if ar>best then best,bx0,bx1,bz0,bz1=ar,x0,e,z0,z1 end end
 if x1>ax1 then local s=max(x0,ax1);local ar=(x1-s)*(z1-z0);if ar>best then best,bx0,bx1,bz0,bz1=ar,s,x1,z0,z1 end end
 if z0<az0 then local e=min(z1,az0);local ar=(e-z0)*(x1-x0);if ar>best then best,bx0,bx1,bz0,bz1=ar,x0,x1,z0,e end end
 if z1>az1 then local s=max(z0,az1);local ar=(z1-s)*(x1-x0);if ar>best then best,bx0,bx1,bz0,bz1=ar,x0,x1,s,z1 end end
 if best<=0 or bx1-bx0<W.MinPiece or bz1-bz0<W.MinPiece then return false,0,0,0,0 end
 return true,(bx0+bx1)/2,(bz0+bz1)/2,bx1-bx0,bz1-bz0
end
-- A circle (centre, radius) lies outside the track rectangle grown by margin.
function W.Outside(a,x,z,radius,margin)
 if not a or not a.Valid then return true end
 return W.AreaDistance(a,x,z)>=radius+(margin or 0)
end

-- Snow patches -------------------------------------------------------------------------------------------------------------------
-- A patch is up to three flat ellipses (lobes): offset (LX, LZ), half-sizes (LA along its own X, LB along its own Z) and yaw LY, in a
-- table the caller owns (spec), filled in place. Shade 1..3 picks the white; Extent = how far the blob reaches from its centre.
W.Shades={C3(246,250,255),C3(235,244,253),C3(251,252,255)}
local function lobes(spec,i,j,salt,r,count)
 spec.LX=spec.LX or{};spec.LZ=spec.LZ or{};spec.LA=spec.LA or{};spec.LB=spec.LB or{};spec.LY=spec.LY or{}
 spec.N=count;local extent=0
 for k=1,count do
  local a,b,ox,oz
  if k==1 then ox,oz=0,0;a=r;b=r*(.6+.35*unit(i,j,salt+4))
  else
   local ang=unit(i,j,salt+10*k)*2*pi;local off=r*(.45+.25*unit(i,j,salt+10*k+1))
   ox,oz=cos(ang)*off,sin(ang)*off;a=r*(.42+.25*unit(i,j,salt+10*k+2));b=a*(.55+.4*unit(i,j,salt+10*k+3))
  end
  spec.LX[k],spec.LZ[k],spec.LA[k],spec.LB[k]=ox,oz,a,b;spec.LY[k]=unit(i,j,salt+10*k+5)*pi
  extent=max(extent,sqrt(ox*ox+oz*oz)+max(a,b))
 end
 spec.Extent=extent
end

-- Weather patches (base): cells of Cell studs, Chance of a patch per cell, main radius RMin..RMax.
W.Patch={Cell=26,Chance=.62,RMin=4.5,RMax=8.5,Count=3,Thickness=.06,Rise=.07,FinalTransparency=0,FadeIn={10,20},FadeOut={20,40},Samples=.6,
 LobeStep=.004,Step=.012}
-- Fills spec for cell (i, j); returns false when the cell has no patch.
function W.PatchSpec(i,j,spec)
 local P=W.Patch
 spec.Present=false;spec.Kind='weather'
 if unit(i,j,1)>=P.Chance then return false end
 local r=P.RMin+(P.RMax-P.RMin)*unit(i,j,2)
 spec.X=(i+.5)*P.Cell+(unit(i,j,3)-.5)*16;spec.Z=(j+.5)*P.Cell+(unit(i,j,4)-.5)*16
 lobes(spec,i,j,5,r,P.Count)
 spec.Shade=1+hash(i,j,6)%#W.Shades
 spec.DIn=P.FadeIn[1]+(P.FadeIn[2]-P.FadeIn[1])*unit(i,j,7);spec.DOut=P.FadeOut[1]+(P.FadeOut[2]-P.FadeOut[1])*unit(i,j,8)
 spec.Thickness=P.Thickness;spec.Present=true
 return true
end
-- The snow / no snow history of the weather: events = {N, [k] = {T, Snow}}. Mark appends a change; Level folds it for one patch (fade-in
-- seconds dIn, fade-out seconds dOut) into 0..1; Fading says whether any patch level can still be changing, Active whether the patches
-- are still needed at all (snowing or fading).
function W.NewEvents()return{N=0,T={},Snow={}}end
function W.Mark(ev,now,snow)
 local n=ev.N
 if n>0 and ev.Snow[n]==snow then return false end
 if n==0 and not snow then return false end
 if n>=8 then for k=1,n-2 do ev.T[k],ev.Snow[k]=ev.T[k+2],ev.Snow[k+2] end;n-=2 end
 n+=1;ev.T[n]=now;ev.Snow[n]=snow;ev.N=n
 return true
end
function W.Level(ev,now,dIn,dOut)
 local level=0
 for k=1,ev.N do
  local dt=max(0,(k<ev.N and ev.T[k+1]or now)-ev.T[k]) -- (R151: only the live entries - a pruned history leaves old times behind)
  if ev.Snow[k]then level=min(1,level+dt/dIn)else level=max(0,level-dt/dOut)end
 end
 return level
end
function W.Fading(ev,now)
 local n=ev.N;if n==0 then return false end
 if ev.Snow[n]then return now-ev.T[n]<W.Patch.FadeIn[2]+1 end
 return now-ev.T[n]<W.Patch.FadeOut[2]+1
end
function W.Active(ev,now)
 local n=ev.N;if n==0 then return false end
 return ev.Snow[n]==true or W.Fading(ev,now)
end
-- Forget a finished event (everything faded out).
function W.Prune(ev,now)
 local n=ev.N
 if n>0 and not ev.Snow[n]and now-ev.T[n]>=W.Patch.FadeOut[2]+1 then ev.N=0;table.clear(ev.T);table.clear(ev.Snow)end
end
function W.Quant(t)return floor(t*50+.5)/50 end
-- Transparency of a patch at a level: 1 (gone) .. FinalTransparency.
function W.PatchTransparency(level,final)
 final=final or W.Patch.FinalTransparency
 return W.Quant(1-level*(1-final))
end

-- Height steps: two patches of neighbouring cells can overlap and would be drawn in the same plane (z-fighting, now that no patch is
-- translucent any more). Every patch lies a deterministic step higher by its cell's parity: level = (i mod 2) + 2 (j mod 2), so the four
-- cells of every 2 x 2 block (any two cells of Chebyshev distance 1) are on four different planes. Weather patches step by Patch.Step
-- (.012: their lobes are .004 apart, so no lobe of one patch shares a plane with a lobe of another), Snow-biome patches by Biome.Step (.004,
-- all their lobes in one plane).
function W.PatchLevel(i,j)return(i%2)+2*(j%2)end
function W.PatchStep(i,j)return W.PatchLevel(i,j)*W.Patch.Step end
-- (R151: an edge bank covers two rows - its level alternates with every bank, (i mod 2) + 2 ((j div 2) mod 2): two banks of one edge never share
-- a plane; next to a border patch (the other column parity) never either)
function W.BiomeStep(i,j,kind)
 if kind=='edge'then return((i%2)+2*((j//2)%2))*W.Biome.Step end
 return W.PatchLevel(i,j)*W.Biome.Step
end

-- Snow biome (permanent): cells of Cell studs from the biome's start, 12 columns across the floor. Edge columns at both sides get big
-- drifts, the first / last BorderRows rows (past the spacebar) get patches over the whole width, the rest only a sparse dusting of small
-- discs. Nothing in the spacebar zone (SpaceClear studs from the biome start) so its label stays clean, nothing past the biome's ends,
-- nothing past the floor's edges.
-- R151 (owner: "snow piles can be bigger and more combined so we don't have to deal with that much performance demand"): the edge drifts
-- merge two rows into one longer bank along the floor's edge (every other row holds one, its lobes stretched EdgeStretch along the track,
-- centred between its two rows), and the border patches take every other cell (a checkerboard) at BorderScale the size: about half the
-- patches - and parts - of R149 for the same look (white drifts along the edges, blobs at the entry and exit of the snow).
W.Biome={Cell=15,Half=90,EdgeCols=1,BorderRows=4,SpaceClear=12,EdgeChance=.9,BorderChance=.62,DustChance=.2,
 Edge={RMin=4.2,RMax=8.6},Border={RMin=3.5,RMax=7.4},Dust={RMin=.7,RMax=1.9},EdgeStretch=1.75,BorderScale=1.35,
 Rise=.1,Thickness=.06,DustThickness=.04,FinalTransparency=0,DustClear=26,DustFade=10,FarScale=1.25,Step=.004}
function W.BiomeCols()return floor(2*W.Biome.Half/W.Biome.Cell+.5)end
function W.BiomeRows(z0,z1)return max(0,floor((z1-z0)/W.Biome.Cell))end
-- Fills spec for cell (i = column 0.., j = row 0.. from z0); cx = track centre X. Returns false when the cell has no patch.
function W.BiomeSpec(i,j,z0,z1,cx,spec)
 local B=W.Biome;spec.Present=false
 local cols,rows=W.BiomeCols(),W.BiomeRows(z0,z1)
 if i<0 or i>=cols or j<0 or j>=rows then return false end
 local kind,chance,range='dust',B.DustChance,B.Dust
 if i<B.EdgeCols or i>=cols-B.EdgeCols then kind,chance,range='edge',B.EdgeChance,B.Edge
 elseif j<B.BorderRows or j>=rows-B.BorderRows then kind,chance,range='border',B.BorderChance,B.Border end
 spec.Kind=kind
 if kind=='edge'and j%2==1 then return false end          -- (a bank covers rows j and j + 1)
 if kind=='border'and(i+j)%2==1 then return false end      -- (a checkerboard of bigger blobs)
 if unit(i,j,31)>=chance then return false end
 local r=range.RMin+(range.RMax-range.RMin)*unit(i,j,32)
 if kind=='border'then r*=B.BorderScale end
 if kind=='dust'then lobes(spec,i,j,35,r,1)else lobes(spec,i,j,35,r,3)end
 local x=cx-B.Half+(i+.5)*B.Cell+(unit(i,j,33)-.5)*B.Cell*.7
 local z=z0+(j+.5)*B.Cell+(unit(i,j,34)-.5)*B.Cell*.7
 if kind=='edge'then
  -- one bank along the edge: every lobe stretched along the track (its long axis turned within +-0.2 rad of Z), offsets stretched too
  z=z0+(j+1)*B.Cell+(unit(i,j,34)-.5)*B.Cell*.4
  local e=0
  for k=1,spec.N do
   local a,b=spec.LA[k],spec.LB[k]
   spec.LA[k]=max(a,b)*B.EdgeStretch;spec.LB[k]=min(a,b)
   spec.LY[k]=(unit(i,j,37+k)-.5)*.4
   spec.LZ[k]*=B.EdgeStretch;spec.LX[k]*=.6
   e=max(e,sqrt(spec.LX[k]^2+spec.LZ[k]^2)+spec.LA[k])
  end
  spec.Extent=e
 end
 local e=spec.Extent
 x=min(max(x,cx-B.Half+e*.6),cx+B.Half-e*.6)
 if kind=='edge'then x=min(max(x,cx-B.Half+spec.LB[1]*.6),cx+B.Half-spec.LB[1]*.6)end -- (a bank hugs the edge: its width, not its length, keeps it on the floor)
 if z-e<z0+B.SpaceClear or z+e>z1 then return false end
 spec.X,spec.Z=x,z
 spec.Shade=1+hash(i,j,36)%#W.Shades
 spec.Thickness=kind=='dust'and B.DustThickness or B.Thickness
 spec.Present=true
 return true
end
-- Dust is hidden near the runner (the keys under and around his feet carry their letters) and fades in over DustFade studs beyond that.
function W.DustTransparency(d,clear,final)
 clear=clear or W.Biome.DustClear
 if d<=clear then return 1 end
 final=final or W.Biome.FinalTransparency
 local k=min(1,(d-clear)/W.Biome.DustFade)
 return W.Quant(1-k*(1-final))
end
-- How many lobes a Snow-biome patch is drawn with at distance d (tier config), and the factor for a lone lobe standing in for the blob.
function W.BiomeLobes(cfg,d,count)
 local l=cfg.Lobes;local n
 if d<cfg.Near then n=l[1]elseif d<cfg.Mid then n=l[2]else n=l[3]end
 return min(n,count)
end
return W
