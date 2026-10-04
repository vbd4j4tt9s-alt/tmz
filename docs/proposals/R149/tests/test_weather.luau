--!nocheck
-- R149 (owner): "rework weather ... not a camera-only thing ... make rain, blizzard and thunder actually happen: droplets actually fall from
-- the sky onto the ground ... snow patches fade in and fade out". Part 1: WeatherWorld149.lua (pure). Part 2: the real
-- WeatherWorld149.client.lua (+ WorldEvents.client.lua for thunder) on the Roblox mock world.
-- ADDED by the R149 performance patch (review part 1, fix round A): tier-2 (phone) particle cap 900 (worst live 1268 -> 878), opaque snow patches,
-- patch height steps (no two overlapping lobes coplanar), a clear sky does no raycast / attribute read, the weather area is read when the map
-- changes, a tier change in the middle of a fade-out keeps the fade (8b, 11b).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local RS,workspace=W.RS,W.workspace
local abs,floor,max,min,sqrt=math.abs,math.floor,math.max,math.min,math.sqrt
local WW=W.module('WeatherWorld149')

-- ======================================================================================================================
-- Part 1: WeatherWorld149.lua
-- ======================================================================================================================
do
 -- Fall: the lifetime is the time to fall exactly the cloud height (the slowest particle lands; the others carry on a little below).
 local kinds={'Rain','Thunderstorm','Blizzard'}
 for _,kind in ipairs(kinds)do for tier=1,3 do
  local p=WW.Profile(kind,tier,false)
  local slow=WW.FallDistance(p.SpeedMin,p.Gravity,p.LifeMin)
  check(near(slow,p.Height,p.Height*1e-6),('%s tier %d: the slowest drop falls exactly the cloud height in its lifetime (%.3f vs %d)'):format(kind,tier,slow,p.Height))
  local fast=WW.FallDistance(p.SpeedMax,p.Gravity,p.LifeMax)
  check(fast>=p.Height and fast<=p.Height*1.12,('%s tier %d: the fastest drop overshoots by at most 12%% (hidden under the floor): %.1f / %d'):format(kind,tier,fast,p.Height))
 end end
 local rain,snow=WW.Profile('Rain',3,false),WW.Profile('Blizzard',3,false)
 check(rain.LifeMin>.4 and rain.LifeMax<1.3,('rain falls from the cloud in about a second (%.2f s)'):format(rain.LifeMin))
 check(snow.LifeMin>2.5 and snow.LifeMax<5,('snow drifts down in a few seconds (%.2f s)'):format(snow.LifeMin))
 check(WW.Profile('Clear',3,false)==nil and WW.Profile('Nonsense',3,false)==nil,'no profile for Clear / unknown kinds')
 check(near(WW.FallTime(46,62,18),(-62+sqrt(62*62+2*18*46))/18,1e-9)and near(WW.FallTime(40,10,0),4,1e-9),'FallTime: with and without gravity')
 local rr=WW.Profile('Rain',3,true)
 check(rr.Gust==0 and rr.Density<rain.Density and rr.Cap<rain.Cap,'ReducedMotion: no gusts, lighter density and cap')
 -- the wind never changes sign (so the drift is known), gusts only change its size
 local sign=true
 for i=1,400 do local ax,az=WW.Wind(rain,i*.37,i*11.3);if ax<=0 or az>=0 or ax<rain.WindX*(1-rain.Gust)-1e-9 or ax>rain.WindX*(1+rain.Gust)+1e-9 then sign=false end end
 check(sign,'wind: always +X / -Z, between 1 - gust and 1 + gust times its size')

 -- Window: the centre cell follows the player with hysteresis.
 local s={}
 check(WW.Recenter(s,10,10,50,10)and s.I==0 and s.J==0,'first Recenter seats the window')
 check(not WW.Recenter(s,-9,59,50,10)and s.I==0 and s.J==0,'inside the hysteresis band the window stays')
 check(WW.Recenter(s,-11,20,50,10)and s.I==-1 and s.J==0,'past the band the window moves one cell')
 check(WW.Recenter(s,500,-500,50,10)and s.I==10 and s.J==-10,'a teleport re-centres at once')
 local moves=0;for x=0,300 do if WW.Recenter(s,x*.5+500,-500,50,10)then moves+=1 end end
 check(moves<=4,('walking 150 studs moves the window %d times (not every step)'):format(moves))
 check(WW.CellKey(-3,-5)~=WW.CellKey(-5,-3)and WW.CellKey(1,2)~=WW.CellKey(2,1),'cell keys are unique')

 -- Weights
 check(WW.Weight(0,15,90)==1 and WW.Weight(15,15,90)==1 and near(WW.Weight(90,15,90),WW.MinWeight)and near(WW.Weight(500,15,90),WW.MinWeight),'weight: 1 near the player, MinWeight far away')
 local mono=true;local last=2;for d=0,120,3 do local w=WW.Weight(d,15,90);if w>last+1e-12 then mono=false end;last=w end
 check(mono,'weight never increases with distance')

 -- Area clipping with drift
 local area={X0=-92,X1=92,Z0=-110,Z1=900,Valid=true}
 local function gridTile(i,j,sz)return i*sz,(i+1)*sz,j*sz,(j+1)*sz end
 local function clip(a,i,j,p)local x0,x1,z0,z1=gridTile(i,j,50);return WW.Clip(a,x0,x1,z0,z1,p)end
 local ok,cx,cz,w,d=clip(area,5,-3,rain)
 check(ok and w==50 and d==50 and cx==275 and cz==-125,'a tile beside the track keeps its whole footprint')
 check(not clip(area,0,2,rain),'a tile on the track gives nothing')
 ok,cx,cz,w,d=clip(area,0,-3,rain)
 check(ok and w==50 and cz+d/2<=-110-rain.InB+1e-9 and cz-d/2==-150,('a tile on the base / track border is cut back to the base side (z <= %.1f)'):format(-110-rain.InB))
 check(not WW.Clip({X0=-92,X1=92,Z0=-110,Z1=900,Valid=true},-25,25,-110,-60,rain),'a tile with nothing but track left gives nothing')
 check(select(2,WW.Clip({Valid=false},0,50,0,50,rain))==25,'no biome ranges -> no clipping')
 -- Fuzz: no piece touches the grown track rectangle, and no particle born in a piece (worst spread, biggest gust, longest life) lands on the track.
 local seed=7;local function rnd()seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
 local bad,badLand,pieces=0,0,0
 for _,kind in ipairs(kinds)do
  local p=WW.Profile(kind,3,false);local th=math.rad(p.Spread)
  for _=1,1500 do
   local i,j=floor(rnd()*30)-15,floor(rnd()*40)-10
   local x0,x1,z0,z1=gridTile(i,j,50)
   local okc,pcx,pcz,pw,pd=WW.Clip(area,x0,x1,z0,z1,p)
   if okc then
    pieces+=1
    local a0,a1,b0,b1=pcx-pw/2,pcx+pw/2,pcz-pd/2,pcz+pd/2
    if a0<x0-1e-9 or a1>x1+1e-9 or b0<z0-1e-9 or b1>z1+1e-9 then bad+=1 end
    for _=1,12 do
     local px,pz=a0+(a1-a0)*rnd(),b0+(b1-b0)*rnd()
     local tx,tz=(rnd()*2-1)*th,(rnd()*2-1)*th
     local v=p.SpeedMax;local life=p.LifeMax
     local lx=px+v*math.sin(tx)*life+.5*p.WindX*(1+p.Gust)*life*life
     local lz=pz+v*math.sin(tz)*life+.5*p.WindZ*(1+p.Gust)*life*life
     if lx>area.X0 and lx<area.X1 and lz>area.Z0 and lz<area.Z1 then badLand+=1 end
    end
   end
  end
 end
 check(pieces>2500 and bad==0,('clipped pieces stay inside their tile (%d pieces)'):format(pieces))
 check(badLand==0,'no particle born in a clipped piece lands on the track (worst spread, gust and fall time), '..badLand..' did')
 check(WW.Outside(area,300,0,5,2)and not WW.Outside(area,0,0,5,2)and not WW.Outside(area,-95,0,5,2)and WW.Outside(area,0,-140,5,2)and not WW.Outside(area,0,-120,15,2),'Outside(): circle vs the track rectangle')
 local mapA=R.new('Model');mapA:SetAttribute('FieldWidth',180);mapA:SetAttribute('BiomeStartZ_6',400);mapA:SetAttribute('BiomeEndZ_6',900);mapA:SetAttribute('BiomeStartZ_1',-110);mapA:SetAttribute('BiomeEndZ_1',400)
 local ar=WW.Area(mapA)
 check(ar.Valid and ar.X0==-92 and ar.X1==92 and ar.Z0==-110 and ar.Z1==900,'Area() reads FieldWidth/2+2 and the first start / last end')
 check(not WW.Area(R.new('Model')).Valid,'Area() of a map without biomes is not valid')

 -- Budget: the sum of rate x lifetime over all tiles never passes the tier cap, whatever the player's spot in a tile.
 local lines={};local phone={}
 for _,kind in ipairs(kinds)do
  local liveByTier={}
  for tier=1,3 do
   local p=WW.Profile(kind,tier,false);local cfg=p.Tier;local S,Rr=cfg.Tile,cfg.R
   local worst,worstRate,nearDensity=0,0,math.huge
   for _,off in ipairs({{.5,.5},{.02,.02},{.5,.02},{.98,.5},{.25,.75}})do
    local px,pz=off[1]*S,off[2]*S
    local sum,wts={},0;local list={}
    for i=-Rr,Rr do for j=-Rr,Rr do
     local dist=WW.RectDistance(px,pz,i*S,(i+1)*S,j*S,(j+1)*S);local wt=WW.Weight(dist,cfg.Near,cfg.Far)
     list[#list+1]={wt=wt,area=S*S};wts+=S*S*wt
    end end
    local scale=WW.Scale(p,wts*p.Density)
    local live=0;for _,t in ipairs(list)do local rate=WW.Rate(p,scale,t.wt,t.area);live+=rate*p.LifeAvg;worstRate=max(worstRate,rate)end
    live*=1+p.SplashFactor;worst=max(worst,live)
    local nd=min(WW.MaxTileRate*p.LifeAvg/(S*S),scale*p.Density);nearDensity=min(nearDensity,nd)
   end
   liveByTier[tier]=worst;if tier==2 then phone[kind]=worst end
   check(worst<=p.Cap*1.0001,('%s tier %d: live drops + splash particles %.0f <= cap %.0f'):format(kind,tier,worst,p.Cap))
   check(worstRate<=WW.MaxTileRate+1e-9,('%s tier %d: no emitter above %d drops/s (%.0f)'):format(kind,tier,WW.MaxTileRate,worstRate))
   lines[#lines+1]=('  %-12s tier %d: %2d tiles of %d, cap %4d, worst live %4.0f, density by the player %.3f /stud^2'):format(kind,tier,(2*Rr+1)^2,S,p.Cap,worst,nearDensity)
   check(nearDensity>=(tier==3 and .035 or tier==2 and .02 or .012),('%s tier %d: still dense by the player (%.3f)'):format(kind,tier,nearDensity))
  end
  check(liveByTier[1]<liveByTier[2]and liveByTier[2]<liveByTier[3],kind..': fewer particles on lower tiers')
 end
 print('budget table:');for _,l in ipairs(lines)do print(l)end
 check(WW.Tier(3).R==2 and WW.Tier(2).R==1 and WW.Tier(1).R==1 and WW.Tier(3).Tile>=50 and WW.Tier(3).Tile<=70,'tiers: 5x5 tiles of 50..70 studs on tier 3, 3x3 below')
 check(WW.Tier(3).Patch.Discs>WW.Tier(2).Patch.Discs and WW.Tier(2).Patch.Discs>WW.Tier(1).Patch.Discs and WW.Tier(3).Biome.Discs>WW.Tier(2).Biome.Discs and WW.Tier(2).Biome.Discs>WW.Tier(1).Biome.Discs,'tiers: fewer patch parts on lower tiers')
 check(WW.Tier(1).Biome.Dust==false and WW.Tier(3).Biome.Dust==true,'tiers: no key dusting on tier 1')
 -- R149 review part 1 (finding 5): rain on phones was ~13x R148's camera bubble (1,268 live particles); tier 2 is capped at 900
 check(WW.Tier(2).Cap==900 and WW.Tier(3).Cap==3200 and WW.Tier(1).Cap==600,'tiers: particle caps 3200 / 900 / 600 (tier 2 was 1300)')
 check(phone.Rain<=900*1.0001 and phone.Thunderstorm<=900*1.0001 and phone.Blizzard<=900*1.0001,('phones (tier 2): at most %.0f live rain / %.0f thunder / %.0f blizzard particles (cap 900; the review measured 1,268 for rain and thunder)'):format(phone.Rain,phone.Thunderstorm,phone.Blizzard))
 print(('phones (tier 2) worst live particles: rain %.0f, thunder %.0f, blizzard %.0f (before: 1268 / 1268 / 1268)'):format(phone.Rain,phone.Thunderstorm,phone.Blizzard))
 -- (finding 6) no snow patch is translucent once it has faded in: it stays out of the sorted transparent pass (translucent only while fading)
 check(WW.Patch.FinalTransparency==0 and WW.Biome.FinalTransparency==0 and WW.PatchTransparency(1)==0 and WW.PatchTransparency(.5)>0 and WW.PatchTransparency(.5)<1 and WW.PatchTransparency(0)==1,'snow patches: final transparency 0 (weather and Snow-biome), translucent only while fading in / out')
 check(WW.DustTransparency(200,26)==0 and WW.DustTransparency(26,26)==1,'Snow-biome dust: solid beyond its fade, hidden near the runner')

 -- Patch layout: deterministic, bounded, irregular
 local a,b={}, {}
 local same,present,total=true,0,0
 local maxExt,minExt=0,math.huge
 for i=-30,30 do for j=-30,30 do
  total+=1
  local pa=WW.PatchSpec(i,j,a);local pb=WW.PatchSpec(i,j,b)
  if pa~=pb or(pa and(a.X~=b.X or a.Z~=b.Z or a.LA[2]~=b.LA[2]or a.Shade~=b.Shade or a.DIn~=b.DIn))then same=false end
  if pa then
   present+=1;maxExt=max(maxExt,a.Extent);minExt=min(minExt,a.Extent)
   if a.N~=3 or a.DIn<10 or a.DIn>20 or a.DOut<20 or a.DOut>40 or a.Shade<1 or a.Shade>3 then same=false end
  end
 end end
 check(same,'patch layout is deterministic and its fade times stay in 10..20 s in / 20..40 s out')
 check(present/total>.55 and present/total<.69,('about 62%% of the cells carry a patch (%.2f)'):format(present/total))
 check(maxExt<16 and minExt>4,('patches are blobs of %.1f..%.1f studs reach'):format(minExt,maxExt))
 -- height steps: no two overlapping lobes (of any two patches up to 3 cells apart) are in the same plane. A weather patch lies W.PatchStep(i, j) =
 -- .012 x ((i mod 2) + 2 (j mod 2)) higher, its lobes .004 apart (LobeStep), so every (patch, lobe) pair has its own level in a 2 x 2 block.
 do
  local function inside(e,x,z)local dx,dz=x-e.X,z-e.Z;local u=dx*e.AX+dz*e.AZ;local v=dx*e.BX+dz*e.BZ;return(u/e.A)^2+(v/e.B)^2<=1 end
  local function overlaps(e1,e2)
   if inside(e2,e1.X,e1.Z)or inside(e1,e2.X,e2.Z)then return true end
   for t=0,23 do local a=t/24*2*math.pi
    for _,r in ipairs({1,.5})do
     local u,v=math.cos(a)*e1.A*r,math.sin(a)*e1.B*r
     if inside(e2,e1.X+u*e1.AX+v*e1.BX,e1.Z+u*e1.AZ+v*e1.BZ)then return true end
    end
   end
   return false
  end
  local list={};local sp={}
  for i=-12,12 do for j=-12,12 do
   if WW.PatchSpec(i,j,sp)then
    local c={I=i,J=j,N=sp.N,L={}}
    for k=1,sp.N do local sy,cy=math.sin(sp.LY[k]),math.cos(sp.LY[k]);c.L[k]={X=sp.X+sp.LX[k],Z=sp.Z+sp.LZ[k],A=sp.LA[k],B=sp.LB[k],AX=sy,AZ=cy,BX=-cy,BZ=sy,Y=WW.PatchStep(i,j)+(k-1)*WW.Patch.LobeStep}end
    list[#list+1]=c
   end
  end end
  local total,clash,sameLevel=0,0,0
  for a=1,#list do for b=a+1,#list do
   local A,Bp=list[a],list[b]
   if abs(A.I-Bp.I)<=3 and abs(A.J-Bp.J)<=3 then
    for _,la in ipairs(A.L)do for _,lb in ipairs(Bp.L)do
     if overlaps(la,lb)then total+=1;if abs(la.Y-lb.Y)<.004-1e-9 then clash+=1 end end
    end end
   end
  end end
  check(WW.PatchLevel(0,0)==0 and WW.PatchLevel(1,0)==1 and WW.PatchLevel(0,1)==2 and WW.PatchLevel(-1,-1)==3 and near(WW.PatchStep(1,1),.036)and near(WW.Patch.LobeStep,.004),'weather patch steps: .012 x ((i mod 2) + 2 (j mod 2)), lobes .004 apart')
  check(#list>200 and total>=5 and clash==0,('weather patches (%d in 25 x 25 cells): %d overlapping lobe pairs, none within .004 of each other in height (%d)'):format(#list,total,clash))
 end
 -- fade timing (Level folds the snow history)
 local ev=WW.NewEvents()
 check(not WW.Mark(ev,0,false)and ev.N==0,'no event for "no snow" at the start')
 check(WW.Mark(ev,100,true)and not WW.Mark(ev,101,true)and ev.N==1,'a snow start is recorded once')
 check(WW.Level(ev,100,10,20)==0 and near(WW.Level(ev,105,10,20),.5)and WW.Level(ev,110,10,20)==1 and WW.Level(ev,300,10,20)==1,'level fades in over its dIn and then persists while it snows')
 check(WW.Fading(ev,105)and not WW.Fading(ev,140)and WW.Active(ev,140),'Fading is over after the longest fade-in; the patches stay while it snows')
 check(WW.Mark(ev,200,false)and near(WW.Level(ev,210,10,20),.5)and near(WW.Level(ev,210,10,40),.75)and WW.Level(ev,220,10,20)==0 and WW.Level(ev,240,10,40)==0,'level fades out over its dOut after the snow ends')
 check(WW.Active(ev,230)and not WW.Active(ev,242)and(WW.Prune(ev,242)or ev.N==0),'the history is dropped once everything has faded')
 WW.Mark(ev,300,true);WW.Mark(ev,304,false)
 check(near(WW.Level(ev,304,10,20),.4)and near(WW.Level(ev,314,10,20),0)and near(WW.Level(ev,306,10,20),.3),'a short snow fades back out from where it got to')
 WW.Mark(ev,310,true)
 check(near(WW.Level(ev,310,10,20),.1)and near(WW.Level(ev,313,10,20),.4)and WW.Level(ev,330,10,20)==1,'snow again while fading continues from the current level')
 check(WW.PatchTransparency(0)==1 and near(WW.PatchTransparency(1),WW.Patch.FinalTransparency)and WW.PatchTransparency(.5)>WW.PatchTransparency(.8),'transparency 1 (gone) at level 0, the final value at level 1')

 -- Snow biome layout over a whole biome
 local z0,z1,cx=1180,2030,0
 local rows,cols=WW.BiomeRows(z0,z1),WW.BiomeCols()
 local KK=W.module('KeyboardTrack');local SPACE=KK.Config.SpaceRows*KK.Config.Pitch+3 -- the keyboard's spacebar + a margin (independent of the layout's own constant)
 local B=WW.Biome;local counts={edge=0,border=0,dust=0};local cells={edge=0,border=0,dust=0}
 local okLayout,spaceOk,xOk,zOk,dustSmall=true,true,true,true,true
 local s1,s2={}, {}
 for j=0,rows-1 do for i=0,cols-1 do
  local p1=WW.BiomeSpec(i,j,z0,z1,cx,s1);local p2=WW.BiomeSpec(i,j,z0,z1,cx,s2)
  if p1~=p2 or(p1 and(s1.X~=s2.X or s1.Z~=s2.Z or s1.Extent~=s2.Extent))then okLayout=false end
  cells[s1.Kind]=(cells[s1.Kind]or 0)+1
  if p1 then
   counts[s1.Kind]+=1
   if s1.Z-s1.Extent<z0+SPACE then spaceOk=false end
   if s1.Z+s1.Extent>z1 then zOk=false end
   if s1.X-s1.Extent*.6<cx-B.Half-1e-6 or s1.X+s1.Extent*.6>cx+B.Half+1e-6 then xOk=false end
   if s1.Kind=='dust'and(s1.N~=1 or s1.Extent>2.2)then dustSmall=false end
   if s1.Kind=='edge'and abs(s1.X-cx)<B.Half-B.Cell-B.Cell*.35-s1.Extent then okLayout=false end
  end
 end end
 check(okLayout,'Snow biome layout: deterministic; edge patches sit in the outer columns')
 check(spaceOk and B.SpaceClear>=SPACE,'Snow biome layout: nothing in the spacebar zone ('..SPACE..' studs from the biome start)')
 check(zOk and xOk,'Snow biome layout: nothing past the biome ends or the floor edges')
 check(dustSmall,'Snow biome layout: dust is one small disc')
 check(counts.edge>=cells.edge*.6 and counts.border>=cells.border*.25 and counts.dust>=cells.dust*.1,('Snow biome layout: %d edge, %d border, %d dust patches over %d x %d cells'):format(counts.edge,counts.border,counts.dust,cols,rows))
 check(near(WW.DustTransparency(20,26),1)and WW.DustTransparency(26,26)==1 and near(WW.DustTransparency(60,26),B.FinalTransparency)and WW.DustTransparency(31,26)<1 and WW.DustTransparency(31,26)>WW.DustTransparency(36,26),'dust is hidden within the clear radius and fades in beyond it')
 check(WW.BiomeLobes(WW.Tier(3).Biome,10,3)==3 and WW.BiomeLobes(WW.Tier(3).Biome,100,3)==2 and WW.BiomeLobes(WW.Tier(3).Biome,200,3)==1 and WW.BiomeLobes(WW.Tier(1).Biome,10,3)==1,'lobes by distance band: 3 / 2 / 1 on tier 3, 1 on tier 1')
end


-- ======================================================================================================================
-- Part 2: the real WeatherWorld149.client.lua (+ WorldEvents.client.lua for the thunder) on the mock world
-- ======================================================================================================================
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='Sound'then o._props.Loaded=R.signal();o._props.Ended=R.signal();o._props.IsLoaded=true;o._props.TimeLength=3 end
 return o end end
R.Inst.Play=function(self)self._props.IsPlaying=true end;R.Inst.Stop=function(self)self._props.IsPlaying=false end
local clears=0;R.Inst.Clear=function(self)if self:IsA('ParticleEmitter')then clears+=1 end end
local Players=W.service('Players');local Run=W.Run;local Gui=W.Gui
local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local GROUND=4.0
local char,hrp
local function spawnAt(x,y,z)
 char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
 hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=CF(x,y,z);hrp.Parent=char;char.Parent=workspace;player.Character=char
end
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace;map:SetAttribute('FieldWidth',180)
map:SetAttribute('BiomeStartZ_1',-110);map:SetAttribute('BiomeEndZ_1',400);map:SetAttribute('BiomeStartZ_6',400);map:SetAttribute('BiomeEndZ_6',900)
local area=WW.Area(map)
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local plots={}
local function addPlot(x,z,sx,sz)
 local p=R.new('Part');p.Name='DirtPlot_'..(#plots+1);p.Size=V3(sx,.4,sz);p.CFrame=CF(x,GROUND+.1,z);p.Anchored=true;p.Parent=bases
 plots[#plots+1]={part=p,x=x,z=z,hx=sx/2,hz=sz/2}
end
for _,a in ipairs({{-60,-200},{-60,-170},{-30,-200},{40,-210},{70,-180}})do addPlot(a[1],a[2],20,24)end
local floorPart=R.new('Part');floorPart.Name='LobbyFloor'
local rays=0
local attrReads=0 -- GetAttribute calls on the map (the weather area is 15 of them)
do local orig=R.Inst.GetAttribute;R.Inst.GetAttribute=function(self,k)if self==map then attrReads+=1 end;return orig(self,k)end end
local areaCalls=0 -- WeatherWorld149.Area calls (the client re-reads the area only when the map's attributes change)
do local orig=WW.Area;WW.Area=function(...)areaCalls+=1;return orig(...)end end
function workspace.Raycast(_,origin,dir)
 rays+=1
 for _,pl in ipairs(plots)do if abs(origin.X-pl.x)<=pl.hx and abs(origin.Z-pl.z)<=pl.hz then return {Position=V3(origin.X,GROUND+.3,origin.Z),Normal=V3(0,1,0),Instance=pl.part}end end
 return {Position=V3(origin.X,GROUND,origin.Z),Normal=V3(0,1,0),Instance=floorPart}
end
local tier=3
W.stub('ClientFxBudget',{Get=function()if player:GetAttribute('FastMode')==true then return 1 end return tier end,Low=function()return tier==1 end})
local cam=workspace.CurrentCamera
local function connected(sig)local n=0;for _,c in ipairs(sig._c)do if c.Connected then n+=1 end end;return n end
local heartbeat0=connected(Run.Heartbeat)

-- helpers over the pooled tiles
local function root()return workspace:FindFirstChild('_WeatherWorldR149')end
local function tiles()
 local f=root();local out={}
 local sky=f and f:FindFirstChild('Sky tiles');local gr=f and f:FindFirstChild('Ground tiles')
 if not sky then return out end
 local sk,gk=sky:GetChildren(),gr:GetChildren()
 for i,p in ipairs(sk)do
  out[i]={sky=p,e=p:FindFirstChildWhichIsA('ParticleEmitter'),ground=gk[i],spray=gk[i]:FindFirstChild('Splash spray'),ripple=gk[i]:FindFirstChild('Splash ripple')}
 end
 return out
end
local function active()local out={};for _,t in ipairs(tiles())do if t.e.Enabled==true and t.e.Rate>0 then out[#out+1]=t end end;return out end
local function rect(t)local p,s=t.sky.CFrame.Position,t.sky.Size;return p.X-s.X/2,p.X+s.X/2,p.Z-s.Z/2,p.Z+s.Z/2 end
local function life(e)return(e.Lifetime.Min+e.Lifetime.Max)/2 end
local function liveSum(list)local n=0;for _,t in ipairs(list)do n+=t.e.Rate*life(t.e)end;return n end
local function splashLive(list)local n=0;for _,t in ipairs(list)do if t.spray.Enabled then n+=t.spray.Rate*life(t.spray)end;if t.ripple.Enabled then n+=t.ripple.Rate*life(t.ripple)end end;return n end
local function intersectsTrack(x0,x1,z0,z1,margin)return x0<area.X1+margin and x1>area.X0-margin and z0<area.Z1+margin and z1>area.Z0-margin end

spawnAt(0,7,-150);cam.CFrame=CF(0,14,-165)  -- the player stands on a grid line (x = 0, z = -150): the worst case for tiles that follow a camera
W.RS:SetAttribute('GlobalWeather','Clear')
local sc=R.new('LocalScript');sc.Name='WeatherWorld149';W.load('WeatherWorld',sc)
frames(1)
check(root()~=nil and #active()==0 and #tiles()==0,'clear weather: nothing emits (and no tiles are even made)')
do
 local r0,a0=rays,attrReads;frames(10)
 check(rays==r0 and attrReads==a0,('clear sky: no ground raycast and no map attribute read while nothing falls or fades (%d raycasts, %d reads in 10 s; it was ~10 raycasts and ~150 reads a second)'):format(rays-r0,attrReads-a0))
end
check(connected(Run.Heartbeat)==heartbeat0+1,'one Heartbeat connection for the whole system')

-- 1. Rain: 5x5 world-fixed tiles around the player, clipped to the base
W.RS:SetAttribute('GlobalWeather','Rain');frames(2.5)
local rainP=WW.Profile('Rain',3,false);local S=50
local all=tiles()
check(#all==25,'tier 3: 5 x 5 = 25 pooled tiles ('..#all..')')
local expectOk=0
for i=-2,2 do for j=-5,-1 do local ok=WW.Clip(area,i*S,(i+1)*S,j*S,(j+1)*S,rainP);if ok then expectOk+=1 end end end
local act=active()
check(#act==expectOk and expectOk>=14,('rain: %d tiles emit - the base part of the window (%d expected)'):format(#act,expectOk))
local gridOk,flagsOk,locked,heightOk,fallOk,clipOk=true,true,true,true,true,true
for _,t in ipairs(act)do
 local x0,x1,z0,z1=rect(t);local p=t.sky.CFrame.Position
 if x1-x0==S and z1-z0==S and(not near(p.X/S-.5,floor(p.X/S),1e-9)or not near(p.Z/S-.5,floor(p.Z/S),1e-9))then gridOk=false end
 if t.sky.Anchored~=true or t.sky.CanCollide~=false or t.sky.CanTouch~=false or t.sky.CanQuery~=false or t.sky.CastShadow~=false or t.sky.Transparency~=1 then flagsOk=false end
 if t.e.LockedToPart~=false or t.e.VelocityInheritance~=0 or t.e.EmissionDirection.Name~='Bottom'then locked=false end
 if p.Y-GROUND<rainP.Height-1e-6 or p.Y-GROUND>rainP.Height+.31 then heightOk=false end -- a tile over a dirt plot hangs from the plot's top
 -- the particles fall the cloud height in their lifetime: distance(slowest speed, gravity, shortest life) = height above the ground
 local fall=WW.FallDistance(t.e.Speed.Min,-t.e.Acceleration.Y,t.e.Lifetime.Min)
 if abs(fall-(p.Y-GROUND))>(p.Y-GROUND)*.01 then fallOk=false end
 if intersectsTrack(x0,x1,z0,z1,2)then clipOk=false end
end
check(gridOk,'every unclipped tile is centred on a grid cell of 50 studs (snapped)')
check(flagsOk,'tiles are invisible, anchored, no collision / touch / query / shadow')
check(locked,'emitters: not locked to the part, no velocity inheritance, emitting downward')
check(heightOk,'tiles hang exactly the cloud height (46) above the ground')
check(fallOk,'a particle falls the whole cloud height in its lifetime: it reaches the ground (1% tolerance)')
check(clipOk,'no tile reaches the track (clipped to the base, with the drift taken into account)')
local liveRain=liveSum(act)
check(liveRain+splashLive(act)<=rainP.Cap*1.001 and liveRain>rainP.Cap*.4,('live drops %.0f + splash %.0f within the tier-3 cap %d'):format(liveRain,splashLive(act),rainP.Cap))

-- 2. Camera moves / spins: nothing moves, nothing stops, nothing is cleared
local function snap()
 local out={}
 for i,t in ipairs(tiles())do local p=t.sky.CFrame.Position;local s=t.sky.Size
  out[i]=string.format('%.4f,%.4f,%.4f|%.3f,%.3f|%s|%.2f|%s|%.2f|%s',p.X,p.Y,p.Z,s.X,s.Z,tostring(t.e.Enabled),t.e.Rate,tostring(t.spray.Enabled),t.spray.Rate,tostring(t.ripple.Enabled))end
 return out
end
local before=snap();clears=0
local minActive=math.huge
for i=1,720 do
 local a=i*.07;local p=V3(math.cos(a)*12,7+5,-150+math.sin(a)*12)
 cam.CFrame=R.CFrame.lookAt(p,V3(0,7,-150+(i%7)))
 W.frames(1,1/60);minActive=min(minActive,#active())
end
cam.CFrame=CF(900,60,900);frames(1);cam.CFrame=R.CFrame.lookAt(V3(-300,40,40),V3(0,0,0));frames(1.5);cam.CFrame=CF(0,14,-165);frames(.5)
local afterSnap=snap();local same=#before==#afterSnap
for i=1,#before do if before[i]~=afterSnap[i]then same=false;print('  changed:',before[i],'->',afterSnap[i])end end
check(same,'spinning the camera (720 frames), flying it 900 studs away and back: every tile identical (position, size, rate, enabled)')
check(clears==0,'the camera never clears a particle')
check(minActive==#act,'the number of emitting tiles never changed while the camera moved ('..tostring(minActive)..' / '..#act..')')

-- 3. The player walks: tiles are handed on cell by cell (snapped), the weather never stops
local lastPos,moves,badMove,minEnabled={}, 0,false,math.huge
for i,t in ipairs(tiles())do lastPos[i]=t.sky.CFrame.Position end
clears=0
for step=1,180 do
 hrp.CFrame=CF(step*.7,7,-150);cam.CFrame=CF(step*.7,14,-165)
 W.frames(1,1/60)
 for i,t in ipairs(tiles())do
  local p=t.sky.CFrame.Position
  if(p-lastPos[i]).Magnitude>1e-9 then
   moves+=1;lastPos[i]=p
   local x0,x1,z0,z1=rect(t);local ci,cj=floor(p.X/S),floor(p.Z/S)
   if x0<ci*S-1e-6 or x1>(ci+1)*S+1e-6 or z0<cj*S-1e-6 or z1>(cj+1)*S+1e-6 then badMove=true end
   if x1-x0==S and z1-z0==S and not near(p.X/S-.5,ci,1e-9)then badMove=true end
  end
 end
 minEnabled=min(minEnabled,#active())
end
frames(.5)
check(not badMove,'every tile move lands inside one grid cell, unclipped tiles on the cell centre')
check(moves>=8 and moves<=40,('walking 126 studs hands tiles on %d times (a camera-following box would move every frame)'):format(moves))
check(minEnabled>=expectOk-6,('while walking at least %d tiles keep emitting every frame (%d)'):format(expectOk-6,minEnabled))
check(clears==0,'walking clears nothing (a re-seated tile leaves its falling drops alone)')
local expectSet,gotSet={}, {}
local pi_,pj_=floor(126/S),-3
for i=pi_-2,pi_+2 do for j=pj_-2,pj_+2 do local ok,cx,cz=WW.Clip(area,i*S,(i+1)*S,j*S,(j+1)*S,rainP);if ok then expectSet[string.format('%.2f,%.2f',cx,cz)]=true end end end
for _,t in ipairs(active())do local p=t.sky.CFrame.Position;gotSet[string.format('%.2f,%.2f',p.X,p.Z)]=true end
local setOk=true;for k in pairs(expectSet)do if not gotSet[k]then setOk=false end end;for k in pairs(gotSet)do if not expectSet[k]then setOk=false end end
check(setOk,'after the walk the emitting tiles are exactly the base cells of the window around the player')

-- 4. Splashes on the ground (rain): spray + ripple under the near tiles
hrp.CFrame=CF(0,7,-150);cam.CFrame=CF(0,14,-165);frames(3)
local nearOn,farOff,ratioOk,groundOk=0,0,true,true
for _,t in ipairs(active())do
 local x0,x1,z0,z1=rect(t);local w=WW.Weight(WW.RectDistance(0,-150,x0,x1,z0,z1),rainP.Tier.Near,rainP.Tier.Far)
 local should=w>=rainP.Tier.SplashMin
 if should then nearOn+=1 else farOff+=1 end
 if t.spray.Enabled~=should or t.ripple.Enabled~=should then ratioOk=false end
 if should then
  if abs(t.spray.Rate-min(WW.Splash.MaxRate,t.e.Rate*WW.Splash.SprayShare))>t.spray.Rate*.06+1 or abs(t.ripple.Rate-min(WW.Splash.MaxRate,t.e.Rate*WW.Splash.RippleShare))>t.ripple.Rate*.06+1 then ratioOk=false end
  local gy=t.ground.CFrame.Position.Y
  if gy<GROUND+WW.Splash.Rise-1e-6 or gy>GROUND+.31+WW.Splash.Rise or t.ground.CanCollide~=false or t.ground.Transparency~=1 then groundOk=false end
  if t.ripple.Orientation.Name~='VelocityPerpendicular'or t.spray.EmissionDirection.Name~='Top'then groundOk=false;print('  orient',t.ripple.Orientation.Name,t.spray.EmissionDirection.Name)end
 end
end
check(nearOn>=6 and farOff>=1,('splashes under the %d near tiles, none under the %d far ones'):format(nearOn,farOff))
check(ratioOk,'splash spray / ripple rates follow the drops landing on the tile (50% / 35%) and are off for far tiles')
check(groundOk,'splash tiles sit just above the ground (0.12), invisible; ripples lie flat (VelocityPerpendicular), spray goes up')

-- 5. Thunderstorm: heavier rain (+ the lightning in WorldEvents, below); Blizzard: snow, no splashes
W.RS:SetAttribute('GlobalWeather','Thunderstorm');frames(2.5)
local stormP=WW.Profile('Thunderstorm',3,false)
local ta=active()
check(#ta==#act and ta[1].e.Speed.Min>rainP.SpeedMin and ta[1].sky.CFrame.Position.Y-GROUND>=stormP.Height-1e-6,'thunderstorm: harder, higher rain (profile of its own)')
check(liveSum(ta)+splashLive(ta)<=stormP.Cap*1.001 and splashLive(ta)>0,'thunderstorm: within the cap (splashes included), with splashes')
clears=0
local blizzardT0=R.clock
W.RS:SetAttribute('GlobalWeather','Blizzard');frames(2.5)
local snowP=WW.Profile('Blizzard',3,false)
local sa=active()
check(clears>0,'rain -> blizzard clears the old drops once (they must not turn into snow mid-air)')
local snowOk,noSplash=true,true
for _,t in ipairs(sa)do
 if t.e.Orientation.Name~='FacingCamera'or t.sky.CFrame.Position.Y-GROUND<snowP.Height-1e-6 or t.sky.CFrame.Position.Y-GROUND>snowP.Height+.31 then snowOk=false end
 if abs(WW.FallDistance(t.e.Speed.Min,-t.e.Acceleration.Y,t.e.Lifetime.Min)-snowP.Height)>snowP.Height*.01 then snowOk=false end
 if t.spray.Enabled or t.ripple.Enabled then noSplash=false end
end
local expectSnow=0
for i=-2,2 do for j=-5,-1 do if WW.Clip(area,i*S,(i+1)*S,j*S,(j+1)*S,snowP)then expectSnow+=1 end end end
check(#sa==expectSnow and snowOk,'blizzard: snow flakes (face the camera), born 40 studs up, lifetime = fall time')
check(noSplash,'blizzard: no rain splashes')
check(liveSum(sa)<=snowP.Cap*1.001,'blizzard: within the cap')
check(snowP.LifeMin>3 and sa[1].e.Lifetime.Min>3,('flakes need %.1f s to land'):format(sa[1].e.Lifetime.Min))

-- 6. Snow patches (the blizzard has been running ~2.5 s)
local pf=root():FindFirstChild('Snow patches')
local function discs()local out={};for _,d in ipairs(pf:GetChildren())do if d.CFrame.Position.Y>0 then out[#out+1]=d end end;return out end
local firstFinal,lastT,monotonic={}, {},true
local function sampleFade()
 local t=R.clock-blizzardT0
 for _,d in ipairs(discs())do
  local T=d.Transparency
  if lastT[d]~=nil and T>lastT[d]+1e-9 then monotonic=false end
  lastT[d]=T
  if T<=.06 and not firstFinal[d]then firstFinal[d]=t end
 end
end
sampleFade()
local early=discs();local minT,visibleEarly=1,0
for _,d in ipairs(early)do minT=min(minT,d.Transparency);if d.Transparency<1 then visibleEarly+=1 end end
check(#early>=20 and minT>=.72,('after 2.6 s patches are placed but still faint (%d discs, most opaque %.2f)'):format(#early,minT))
for _=1,50 do frames(.5);sampleFade()end
local shown=0;local allFinal=true;local props=true;local trackOk,plotOk,heightOk2=true,true,true
for _,d in ipairs(discs())do
 local T=d.Transparency
 if T<1 then
  shown+=1;if T~=0 then allFinal=false end
  local p=d.CFrame.Position;local r=max(d.Size.Y,d.Size.Z)/2
  if d.Anchored~=true or d.CanCollide~=false or d.CanTouch~=false or d.CanQuery~=false or d.CastShadow~=false or d.Shape.Name~='Cylinder'or d.Size.X>.1 then props=false end
  local bottom=p.Y-d.Size.X/2-GROUND
  if bottom<.05 or bottom>.15 then heightOk2=false end
  if WW.AreaDistance(area,p.X,p.Z)<r-1e-6 then trackOk=false end
  for _,pl in ipairs(plots)do if abs(p.X-pl.x)<pl.hx+r+.3-1e-6 and abs(p.Z-pl.z)<pl.hz+r+.3-1e-6 then plotOk=false end end
 end
end
check(shown>=60,('after 28 s the snow has settled: %d patch discs in view'):format(shown))
check(allFinal,'settled patches are fully opaque white (transparency 0, they were .04) - persist while it snows')
check(props,'patches are flat cylinders: anchored, no collision / touch / query / shadow, thinner than 0.1')
check(heightOk2,'patches lie 0.07-0.12 above the ground (no z-fighting, not floating)')
do -- no two overlapping discs (of any patches) are in one plane: the cell's step (.012 apart) + the lobes' step (.004 apart)
 local function ellipse(d)
  local p=d.CFrame.Position;local up,look=d.CFrame.UpVector,d.CFrame.LookVector
  return {X=p.X,Z=p.Z,Y=p.Y-d.Size.X/2,A=d.Size.Z/2,B=d.Size.Y/2,AX=-look.X,AZ=-look.Z,BX=up.X,BZ=up.Z}
 end
 local function inside(e,x,z)local dx,dz=x-e.X,z-e.Z;local u=dx*e.AX+dz*e.AZ;local v=dx*e.BX+dz*e.BZ;return(u/e.A)^2+(v/e.B)^2<=1 end
 local function overlaps(e1,e2)
  if inside(e2,e1.X,e1.Z)or inside(e1,e2.X,e2.Z)then return true end
  for t=0,23 do local a=t/24*2*math.pi
   for _,r in ipairs({1,.5})do
    local u,v=math.cos(a)*e1.A*r,math.sin(a)*e1.B*r
    if inside(e2,e1.X+u*e1.AX+v*e1.BX,e1.Z+u*e1.AZ+v*e1.BZ)then return true end
   end
  end
  return false
 end
 local es={};for _,d in ipairs(discs())do if d.Transparency<1 then es[#es+1]=ellipse(d)end end
 local nOver,nSame=0,0
 for a=1,#es do for b=a+1,#es do
  local e1,e2=es[a],es[b]
  if abs(e1.X-e2.X)<30 and abs(e1.Z-e2.Z)<30 and overlaps(e1,e2)then nOver+=1;if abs(e1.Y-e2.Y)<.004-1e-6 then nSame+=1 end end
 end end
 check(#es>=60 and nOver>=5 and nSame==0,('%d discs in view: %d pairs overlap, none lies in the plane of the other (%d coplanar)'):format(#es,nOver,nSame))
end
check(trackOk,'no patch reaches the track (weather area = base)')
check(plotOk,'no patch lies on a garden bed (DirtPlot)')
check(monotonic,'while it snows a patch only gets whiter (transparency never goes up)')
local nIn,minIn,maxIn,inRange=0,math.huge,0,0
for _,t in pairs(firstFinal)do nIn+=1;minIn=min(minIn,t);maxIn=max(maxIn,t);if t>=9.4 and t<=21 then inRange+=1 end end
check(nIn>=shown*.95 and inRange>=nIn*.97,('patches finish fading in between %.1f and %.1f s (10-20 s each; %d / %d in range)'):format(minIn,maxIn,inRange,nIn))
check(maxIn-minIn>=4,'the patches do not all fade at the same moment')
frames(30)
local shown2=0;for _,d in ipairs(discs())do if d.Transparency<1 then shown2+=1;if d.Transparency~=0 then allFinal=false end end end
check(shown2==shown and allFinal,'60 s into the snow: the same patches, still white (they persist while it snows)')
check(#pf:GetChildren()<=WW.Tier(3).Patch.Discs,'patch parts stay within the tier-3 budget ('..#pf:GetChildren()..' / '..WW.Tier(3).Patch.Discs..')')

-- the weather ends: patches fade out over 20-40 s
local tc=R.clock
W.RS:SetAttribute('GlobalWeather','Clear')
local startVisible,hiddenAt,lastT2,mono2,earlyHide={}, {}, {},true,false
for _,d in ipairs(discs())do if d.Transparency<1 then startVisible[d]=true;lastT2[d]=d.Transparency end end
local changedAt3=0;local total3=0
for k=1,92 do
 frames(.5);local t=R.clock-tc
 for d in pairs(startVisible)do
  local T=d.Transparency
  if T<lastT2[d]-1e-9 then mono2=false end
  lastT2[d]=T
  if T>=1 and not hiddenAt[d]then hiddenAt[d]=t;if t<19.4 then earlyHide=true end end
 end
 if k==6 then for d in pairs(startVisible)do total3+=1;if d.Transparency>.06+1e-9 then changedAt3+=1 end end;check(#active()==0,'the tiles stopped emitting within 3 s of Clear')end
end
local nOut,minOut,maxOut=0,math.huge,0
for _,t in pairs(hiddenAt)do nOut+=1;minOut=min(minOut,t);maxOut=max(maxOut,t)end
check(changedAt3>=total3*.9,'3 s after the weather ended the patches are already paling')
check(mono2 and not earlyHide,'patches only fade away, and none is gone before 19.4 s')
check(nOut==shown and minOut>=19.4 and maxOut<=41.5,('every patch is gone between %.1f and %.1f s after the weather (20-40 s each)'):format(minOut,maxOut))
check(maxOut-minOut>=8,'they disappear one after another, not all at once')
local left=0;for _,d in ipairs(pf:GetChildren())do if d.Transparency<1 then left+=1 end end
check(left==0,'46 s after the weather nothing is left on the ground')

-- 7. The track: no weather on it, weather again in the base
W.RS:SetAttribute('GlobalWeather','Rain');frames(3)
check(#active()>=10,'rain again')
clears=0;hrp.CFrame=CF(0,7,120);cam.CFrame=CF(0,14,105);frames(.4)
check(#active()==0,'on the track no tile emits')
frames(2);check(#active()==0 and clears==0,'... and the drops already falling are left to finish (nothing cleared)')
hrp.CFrame=CF(0,7,-150);cam.CFrame=CF(0,14,-165);frames(2.5)
check(#active()>=10,'back in the base the rain is back')

-- 8. Budgets: tiers, FastMode, ReducedMotion
local function expected(tn,kind)
 local p=WW.Profile(kind,tn,false);local cfg=p.Tier;local n=0
 local pi,pj=floor(0/cfg.Tile),floor(-150/cfg.Tile)
 for i=pi-cfg.R,pi+cfg.R do for j=pj-cfg.R,pj+cfg.R do if WW.Clip(area,i*cfg.Tile,(i+1)*cfg.Tile,j*cfg.Tile,(j+1)*cfg.Tile,p)then n+=1 end end end
 return n,p
end
local info={}
tier=2;frames(2.4)
check(#active()==expected(3,'Rain'),'a tier change only applies after it has held 3 s (still tier 3 after 2.4 s)')
frames(1.5)
local n2,p2=expected(2,'Rain');local a2=active();local live2=liveSum(a2)
check(#a2==n2 and n2<=9,('tier 2: %d tiles (3 x 3 window)'):format(#a2))
check(live2+splashLive(a2)<=p2.Cap*1.001 and live2>p2.Cap*.4,('tier 2: %.0f drops + %.0f splash particles within the cap %d'):format(live2,splashLive(a2),p2.Cap))
info[#info+1]=('tier 2: %d tiles, %.0f live drops (+%.0f splash particles)'):format(#a2,live2,splashLive(a2))
tier=1;frames(4)
local n1,p1=expected(1,'Rain');local a1=active();local live1=liveSum(a1)
check(#a1==n1 and live1+splashLive(a1)<=p1.Cap*1.001,('tier 1: %d tiles, %.0f drops + %.0f splash particles within the cap %d'):format(#a1,live1,splashLive(a1),p1.Cap))
local sp1=0;for _,t in ipairs(a1)do if t.spray.Enabled then sp1+=1 end end
check(sp1<=4,'tier 1: splashes only right under the player ('..sp1..' tiles)')
info[#info+1]=('tier 1: %d tiles, %.0f live drops (+%.0f splash particles)'):format(#a1,live1,splashLive(a1))
tier=3;frames(4)
local a3=active();local live3=liveSum(a3)
info[#info+1]=('tier 3: %d tiles, %.0f live drops (+%.0f splash particles)'):format(#a3,live3,splashLive(a3))
check(#a3==expected(3,'Rain'),('tier 3 again: %d tiles (%d expected)'):format(#a3,expected(3,'Rain')))
check(live3>live2*1.5 and live2>live1*1.5,'more particles on higher tiers')
player:SetAttribute('FastMode',true);frames(4)
local af=active()
check(#af==n1 and liveSum(af)<=p1.Cap*1.001,'FastMode counts as tier 1')
player:SetAttribute('FastMode',false);frames(4)
check(#active()==expected(3,'Rain'),'FastMode off: back to tier 3')
-- gusts: the wind changes strength but never direction; Reduced Motion has none and fewer particles
local seen,signOk,rangeOk={}, true,true
for _=1,24 do
 frames(.25);local t=active()[1];local ax,az=t.e.Acceleration.X,t.e.Acceleration.Z
 seen[string.format('%.2f',ax)]=true
 if ax<=0 or az>=0 then signOk=false end
 if ax<rainP.WindX*(1-rainP.Gust)-.01 or ax>rainP.WindX*(1+rainP.Gust)+.01 then rangeOk=false end
end
local gustCount=0;for _ in pairs(seen)do gustCount+=1 end
check(gustCount>=4,'the wind gusts ('..gustCount..' different strengths in 6 s)')
check(signOk and rangeOk,'the wind never turns: +X / -Z, 0.75 - 1.25 times its size')
Gui.ReducedMotionEnabled=true;frames(1.5)
local ar=active();local rP=WW.Profile('Rain',3,true)
check(liveSum(ar)<=rP.Cap*1.001 and liveSum(ar)<live3*.8,('Reduced Motion: fewer particles (%.0f live, cap %.0f)'):format(liveSum(ar),rP.Cap))
local fixed,ax0={}, ar[1].e.Acceleration.X
for _=1,12 do frames(.25);fixed[string.format('%.3f',active()[1].e.Acceleration.X)]=true end
local fixedCount=0;for _ in pairs(fixed)do fixedCount+=1 end
check(fixedCount==1,'Reduced Motion: no gusts (steady wind)')
Gui.ReducedMotionEnabled=false;frames(1.5)

-- 8b. R149 review part 1 (finding 15): a quality-tier change that lands while the weather is fading out used to cut the fade (setKind('Clear')
-- dropped the profile, every tile went quiet at once). The fade goes on with the new tier's numbers.
do
 W.RS:SetAttribute('GlobalWeather','Rain');tier=3;frames(4)
 tier=2;frames(2.6)                                 -- wanted for 2.6 s of the 3 s it has to hold
 check(#active()==expected(3,'Rain'),'(still tier 3: the change has not held 3 s yet)')
 W.RS:SetAttribute('GlobalWeather','Clear');frames(.3) -- the fade-out starts (1.5 s) ...
 local before=#active()
 frames(.4)                                          -- ... the tier changes in the middle of it (3.0 s)
 local mid=active();local midLive=liveSum(mid)
 local p2fade=WW.Profile('Rain',2,false)
 check(before>0 and #mid>0 and midLive>0,('a tier change in the middle of a fade-out: the drops are still falling (%d tiles before, %d after)'):format(before,#mid))
 check(midLive+splashLive(mid)<=p2fade.Cap*1.001,'...at the new tier\'s numbers (within its cap)')
 frames(.4)
 local late=liveSum(active())
 check(late<midLive,('...and still fading (%.0f -> %.0f live drops)'):format(midLive,late))
 frames(1.5)
 check(#active()==0,'...until they are gone')
 W.RS:SetAttribute('GlobalWeather','Rain');tier=3;frames(5)
 check(#active()==expected(3,'Rain'),'back to rain on tier 3')
end

-- 9. Respawn: the weather keeps falling; the window re-centres on the new spot
clears=0
player.CharacterRemoving:Fire(char);char:Destroy();player.Character=nil;frames(1.5)
check(#active()>=8,'with no character the weather keeps falling (around the camera)')
spawnAt(300,7,-250);cam.CFrame=CF(300,14,-265);player.CharacterAdded:Fire(char);frames(2.5)
local near300,total300=0,0
for _,t in ipairs(active())do total300+=1;local p=t.sky.CFrame.Position;if abs(p.X-300)<=2.5*S and abs(p.Z+250)<=2.5*S then near300+=1 end end
check(total300>=12 and near300==total300,('after respawning 300 studs away the emitting tiles surround the new spot (%d / %d)'):format(near300,total300))
check(clears==0,'respawning clears nothing')
hrp.CFrame=CF(0,7,-150);cam.CFrame=CF(0,14,-165);frames(3)

-- 10. Nothing is created while it runs
local n0=#R.created;local r0=rays
for i=1,300 do
 hrp.CFrame=CF(math.sin(i*.02)*60,7,-150-math.cos(i*.02)*30);local a=i*.09
 cam.CFrame=R.CFrame.lookAt(V3(math.cos(a)*14,12,-150+math.sin(a)*14),V3(0,7,-150))
 W.frames(1,1/60)
end
check(#R.created==n0,'no Instance is created while the weather runs and the camera spins ('..(#R.created-n0)..' new)')
check(rays-r0<=300*2,'raycasts stay bounded: '..(rays-r0)..' in 300 frames')

-- 11. Source rules
local text=W.B.WeatherWorld
check(text:find('LookVector',1,true)==nil and text:find('RenderStepped',1,true)==nil,'the tile code never reads the camera look direction and has no per-frame follower')
check(text:find('LockedToPart=false',1,true)~=nil and text:find('LockedToPart=true',1,true)==nil,'emitters are never locked to their part')
check(W.B.WorldEvents:find('Field.Target',1,true)==nil and W.B.WorldEvents:find("Name='Precipitation'",1,true)==nil and W.B.WorldEvents:find('LookVector',1,true)==nil,'WorldEvents no longer has a camera-following emitter or aims bolts by the camera')
check(text:find('RemoteEvent',1,true)==nil and text:find('FireServer',1,true)==nil,'client only: no remotes')

-- 11b. R149 review part 1 (finding 15): the weather area (15 map attribute reads) is read when the map's attributes change, not every 0.1 s; a clear
-- sky with nothing left to fade does no raycast and no attribute read at all.
do
 local r0,a0,c0=rays,attrReads,areaCalls;frames(10)
 check(areaCalls==c0,('rain falling steadily: the weather area is not re-read every step (%d reads in 10 s, it was 100)'):format(areaCalls-c0))
 c0=areaCalls;map:SetAttribute('BiomeEndZ_6',950);frames(1)
 check(areaCalls>c0,'...but it is read again when the map\'s attributes change ('..(areaCalls-c0)..' reads)')
 map:SetAttribute('BiomeEndZ_6',900);frames(1)
 W.RS:SetAttribute('GlobalWeather','Clear');frames(60)
 r0,a0=rays,attrReads;frames(10)
 check(rays==r0 and attrReads==a0,('after the weather and its patches have faded away: no raycast, no attribute read (%d / %d)'):format(rays-r0,attrReads-a0))
 W.RS:SetAttribute('GlobalWeather','Rain');frames(3)
 check(#active()>=8 and rays>r0,'...and rain starting again is picked up at once')
 check(W.B.WeatherWorld:find('byte(',1,true)~=nil,'garden parts that stream in are filtered by their first byte before any pattern match')
end

-- 12. Teardown
sc.Destroying:Fire()
check(root()==nil,'teardown removes the folder with every tile and patch')
check(connected(Run.Heartbeat)==heartbeat0,'teardown disconnects the Heartbeat connection')
W.RS:SetAttribute('GlobalWeather','Rain');frames(2);check(root()==nil,'a destroyed script does nothing more')
W.RS:SetAttribute('GlobalWeather','Clear')

-- 13. Thunder: lightning stays in WorldEvents; a bolt is a place in the world, never "in front of the camera"
W.service('ContentProvider').PreloadAsync=function()end
local function bolt(from,to)
 R.clock=5000;hrp.CFrame=CF(0,7,-150)
 cam.CFrame=R.CFrame.lookAt(from,to)
 W.RS:SetAttribute('GlobalWeather','Thunderstorm')
 local sc2=R.new('LocalScript');sc2.Name='WorldEvents';W.load('WorldEvents',sc2)
 W.frames(7,1/60)
 local f=workspace:FindFirstChild('_GlobalWeatherR59');local pl=f and f:FindFirstChild('PooledLightning')
 local list={};if pl then for _,p in ipairs(pl:GetChildren())do if p.Transparency<1 then local q=p.CFrame.Position;list[#list+1]=string.format('%.3f,%.3f,%.3f',q.X,q.Y,q.Z)end end end
 sc2.Destroying:Fire();W.RS:SetAttribute('GlobalWeather','Clear');W.frames(3,1/60)
 return list
end
local A=bolt(V3(0,14,-165),V3(0,14,300))
local B=bolt(V3(200,40,-100),V3(-500,10,-100))
check(#A>=10 and #A==#B,('a lightning bolt is drawn (%d segments)'):format(#A))
local identical=#A==#B;for i=1,#A do if A[i]~=B[i]then identical=false end end
check(identical,'the same strike lands in the same place whichever way the camera looks')
local sx,sz=0,0;for _,s in ipairs(A)do local x,_,z=s:match('([-%d%.]+),([-%d%.]+),([-%d%.]+)');sx+=tonumber(x);sz+=tonumber(z)end
sx/=#A;sz/=#A
local away=sqrt(sx*sx+(sz+150)^2)
check(WW.AreaDistance(area,sx,sz)>0 and away>85 and away<180,('the bolt falls in the base, %.0f studs from the player'):format(away))

for _,l in ipairs(info)do print('  '..l)end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
