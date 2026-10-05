--!nocheck
-- R151 (owner): "for the snow make sure the snow piles are visible throughout and not just when players walk into an area that it appears" and
-- "snow piles can be bigger and more combined so we don't have to deal with that much performance demand too".
-- Part 1: HubSnow151.lua (pure layout). Part 2: the REAL WeatherWorld149.client.lua on a mock hub built like the owner's (floor, walls, six
-- bases with pads / beds / treadmills / pedestals, the market, Verity, the two R151 displays, the R151 festival streets, a tagged prop, a
-- shovel hole), with straight-down raycasts against those parts. Part 3: weather performance numbers (rain / thunder / blizzard, tiers).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local RS,workspace=W.RS,W.workspace
local abs,floor,max,min,sqrt=math.abs,math.floor,math.max,math.min,math.sqrt
local WW=W.module('WeatherWorld149');local H=W.module('HubSnow151')

-- The owner's hub (R150 place, docs/proposals/R151/base_area.md): inner wall faces, floor top 4, six base pads (top 5), the track from z -100.
local PADS={{1,-325,-145,-239.53,-121.53},{2,145,325,-239.53,-121.53},{3,-325,-145,-417.02,-299.02},{4,145,325,-417.02,-299.02},
 {5,-133,-15,-602.32,-422.32},{6,15,133,-602.32,-422.32}}
local AREA={X0=-92,X1=92,Z0=-100,Z1=2217.5,Valid=true}
local function hubDesc()
 local h={X0=-335,X1=335,Z0=-618,Z1=-104,Top=4,Gap=94,Area=AREA,Pads={}}
 for _,p in ipairs(PADS)do local o=H.FenceOut
  h.Pads[#h.Pads+1]={Index=p[1],X0=p[2],X1=p[3],Z0=p[4],Z1=p[5],Top=5,FX0=p[2]-o,FX1=p[3]+o,FZ0=p[4]-o,FZ1=p[5]+o}
 end
 return h
end
-- a drift's lobe as an ellipse: centre, half axes, axis directions (A along (sin yaw, cos yaw))
local function inEllipse(cx,cz,a,b,yaw,x,z)
 local sy,cy=math.sin(yaw),math.cos(yaw);local dx,dz=x-cx,z-cz
 local u=dx*sy+dz*cy;local v=-dx*cy+dz*sy
 return(u/a)^2+(v/b)^2<=1
end

-- ======================================================================================================================
-- Part 1: HubSnow151.lua
-- ======================================================================================================================
local hub=hubDesc()
local L=H.Layout(hub)
do
 local L2=H.Layout(hubDesc())
 local same=L.N==L2.N
 for k=1,math.min(L.N,L2.N)do local a,b=L[k],L2[k]
  if a.Key~=b.Key or a.X~=b.X or a.Z~=b.Z or a.N~=b.N or a.Slot~=b.Slot or a.LA[1]~=b.LA[1]or a.Shade~=b.Shade or a.DIn~=b.DIn then same=false end
 end
 check(same,'the layout is deterministic: the same hub gives the same drifts (every client builds the same snow)')
 local keys,dup={},false;for k=1,L.N do if keys[L[k].Key]then dup=true end;keys[L[k].Key]=true end
 check(not dup,'every drift has its own key')
 local by={};for k=1,L.N do local s=L[k];by[s.Kind]=(by[s.Kind]or 0)+1 end
 check((by.corner or 0)==4 and(by.wall or 0)>=25 and(by.fence or 0)>=25 and(by.open or 0)>=40 and(by.inner or 0)>=20,
  ('drifts of every kind: %d corner, %d wall, %d fence, %d open, %d inner'):format(by.corner or 0,by.wall or 0,by.fence or 0,by.open or 0,by.inner or 0))
 check(L.N<=240,('the whole hub takes %d drifts (R149 needed ~1,500 small patches to cover it)'):format(L.N))
 -- nothing on the track, every centre inside the walls, fades in 10-20 s / out 20-40 s, lobes in range
 local onTrack,outside,fades,lobesOk=0,0,true,true
 for k=1,L.N do local s=L[k]
  if not WW.Outside(AREA,s.X,s.Z,s.Reach,0)then onTrack+=1 end
  if s.X<hub.X0 or s.X>hub.X1 or s.Z<hub.Z0 or s.Z>hub.Z1 then outside+=1 end
  if s.DIn<10 or s.DIn>20 or s.DOut<20 or s.DOut>40 then fades=false end
  if s.N<1 or s.N>4 or s.Shade<1 or s.Shade>3 then lobesOk=false end
 end
 check(onTrack==0,'no drift reaches the track (weather belongs to the base)')
 check(outside==0,'every drift lies inside the hub walls')
 check(fades and lobesOk,'fade times 10-20 s in / 20-40 s out, 1-4 lobes, one of three whites')
 -- spread: the hub cut into 3 x 3 zones, every zone holds drifts (the R149 window only held the player's own)
 local zones={}
 for k=1,L.N do local s=L[k];local zx=floor((s.X-hub.X0)/((hub.X1-hub.X0)/3));local zz=floor((s.Z-hub.Z0)/((hub.Z1-hub.Z0)/3));zones[zx*3+zz]=(zones[zx*3+zz]or 0)+1 end
 local nz=0;for _ in pairs(zones)do nz+=1 end
 check(nz==9,'drifts in all 9 zones of the hub ('..nz..')')
 -- bigger, more combined: a wall bank runs 40+ studs, open drifts are 2-3x the R149 patches, banks deeper than open snow
 local wallLen,openR=math.huge,math.huge
 for k=1,L.N do local s=L[k];if s.Kind=='wall'then wallLen=min(wallLen,s.LA[1]*2)elseif s.Kind=='open'then openR=min(openR,s.LA[1])end end
 check(wallLen>=40 and openR>=WW.Patch.RMax,('drifts are big: wall banks >= %.0f studs long, open drifts >= %.1f studs radius (R149 patches %.1f..%.1f)'):format(wallLen,openR,WW.Patch.RMin,WW.Patch.RMax))
 check(H.Kinds.wall.Th>H.Kinds.fence.Th and H.Kinds.fence.Th>H.Kinds.open.Th and H.Kinds.corner.Th>=H.Kinds.wall.Th,'thicker along the walls and in the corners, thinner in the open')
 -- banks never reach a base's fence (the 6-stud alleys beside the bases get narrow banks)
 local bad=0
 for k=1,L.N do local s=L[k]
  if s.Kind=='wall'then
   for _,p in ipairs(hub.Pads)do for l=1,s.N do
    local cx,cz=s.X+s.LX[l],s.Z+s.LZ[l]
    for x=cx-s.LA[l],cx+s.LA[l],1 do for z=cz-s.LA[l],cz+s.LA[l],1 do
     if x>p.FX0 and x<p.FX1 and z>p.FZ0 and z<p.FZ1 and inEllipse(cx,cz,s.LA[l],s.LB[l],s.LY[l],x,z)then bad+=1 end
    end end
   end end
  end
 end
 check(bad==0,'no wall bank reaches into a base (fence / pad), '..bad..' sample points did')

 -- heights: overlapping drifts never share a top plane; no top within KeepGap of the hub's flat things; tapers distinct within a drift
 local shared,keepNear,inDrift=0,0,0
 for a=1,L.N do local s=L[a]
  for k=1,s.N do
   local top=H.Rise+H.Thickness(s,k)
   if s.Pad==0 then for _,y in ipairs({4.06,4.07,4.12,4.14,4.20,4.26,4.32})do if abs(4+top-y)<.01 then keepNear+=1 end end end
   for k2=k+1,s.N do if H.Plane(s,k)==H.Plane(s,k2)then inDrift+=1 end end
  end
  for b=a+1,L.N do local t=L[b]
   if t.Pad==s.Pad and(t.X-s.X)^2+(t.Z-s.Z)^2<(t.Reach+s.Reach)^2 then
    for k=1,s.N do for l=1,t.N do if H.Plane(s,k)==H.Plane(t,l)then shared+=1 end end end
   end
  end
 end
 check(shared==0,'no two overlapping drifts share a top plane (every top at least .004 apart): '..shared)
 check(keepNear==0,'no drift top within .01 of the hub\'s flat things (R151 streets 4.20, plazas 4.14 / 4.26, curbs 4.32, run-up 4.06, grass patches 4.07 / 4.12)')
 check(inDrift==0,'within a drift every lobe has its own plane (deepest in the middle, stepping down)')
 check(H.Unit>=.004 and H.Rise>=.07,'one plane = .004 (fix round A), bottoms .07 over the ground')

 -- budgets: the worst player position over the hub stays inside each tier's part budget; lower tiers need fewer parts
 local worst={}
 for t=3,1,-1 do local cfg=H.Tier(t);worst[t]=H.Budget(L,cfg,hub,15)
  check(worst[t]<=cfg.Discs and cfg.Discs<=({[3]=350,[2]=240,[1]=180})[t],('tier %d: at most %d snow parts anywhere in the hub (budget %d, phones 240 / FastMode 180 at most)'):format(t,worst[t],cfg.Discs))
 end
 check(worst[1]<worst[2]and worst[2]<worst[3],'fewer snow parts on lower tiers')
 check(H.Tier(1).MinPri>H.Kinds.inner.Pri and H.Tier(2).MinPri>H.Kinds.inner.Pri and H.Tier(3).MinPri<=H.Kinds.inner.Pri,'tiers 2 and 1 (phones, FastMode) skip the sprinkle inside the bases')
 print(('budget: worst snow parts over the hub %d / %d / %d (tiers 3 / 2 / 1)'):format(worst[3],worst[2],worst[1]))

 -- LOD bands with hysteresis
 local c3=H.Tier(3)
 check(H.Lobes(c3,10,4,0)==4 and H.Lobes(c3,c3.Near+1,4,0)==2 and H.Lobes(c3,c3.Mid+1,4,0)==1 and H.Lobes(c3,10,2,0)==2,'LOD: all lobes near, two in the middle band, one far (never more than the drift has)')
 check(H.Lobes(c3,c3.Near+c3.Hyst-1,4,4)==4 and H.Lobes(c3,c3.Near+c3.Hyst+1,4,4)==2 and H.Lobes(c3,c3.Near+1,4,2)==2,'LOD: a drift showing more lobes keeps them a little past the band edge (no flicker on the edge)')

 -- R151 fix: the second blizzard of a session. R149's Level read the time of an event the history had already forgotten (Prune only reset the
 -- count), so after one snow had faded away the next one stayed at level 0: no snow at all the second time
 do
  local ev=WW.NewEvents();WW.Mark(ev,0,true);WW.Mark(ev,30,false);WW.Prune(ev,80)
  check(ev.N==0,'(the first snow is forgotten once it has faded)')
  WW.Mark(ev,100,true)
  check(near(WW.Level(ev,105,10,20),.5)and WW.Level(ev,111,10,20)==1,'a second blizzard after the first was forgotten fades in again (R149: it stayed at 0)')
  -- a long history wraps (8 entries: the oldest two go); its level is the fold of the entries it still has, never of a forgotten one
  local ev2=WW.NewEvents()
  for i=1,9 do WW.Mark(ev2,100+i*30,i%2==1)end
  local want=0
  for k=1,ev2.N do local dt=(k<ev2.N and ev2.T[k+1]or 400)-ev2.T[k];if ev2.Snow[k]then want=math.min(1,want+dt/10)else want=math.max(0,want-dt/20)end end
  check(ev2.N==7 and ev2.Snow[7]==true and near(WW.Level(ev2,400,10,20),want)and WW.Level(ev2,400,10,20)==1,'a wrapped history: the level folds only its live entries (snowing for 130 s: 1)')
 end
 -- the ellipse / box test against brute force
 local seed=11;local function rnd()seed=(seed*1103515245+12345)%2147483648;return seed/2147483648 end
 local wrong=0
 for _=1,400 do
  local s={X=rnd()*40-20,Z=rnd()*40-20,LX={0},LZ={0},LA={2+rnd()*10},LB={1+rnd()*6},LY={rnd()*math.pi}}
  local bx,bz,hx,hz=rnd()*40-20,rnd()*40-20,.5+rnd()*8,.5+rnd()*8;local ang=rnd()*math.pi;local ux,uz=math.cos(ang),math.sin(ang)
  local got=H.LobeHitsBox(s,1,1,bx,bz,hx,hz,ux,uz)
  local brute=false
  for i=-20,20 do for j=-20,20 do
   local lx,lz=i/20*hx,j/20*hz;local x,z=bx+lx*ux-lz*uz,bz+lx*uz+lz*ux
   if inEllipse(s.X,s.Z,s.LA[1],s.LB[1],s.LY[1],x,z)then brute=true end
  end end
  if brute and not got then wrong+=1 end -- (never miss an overlap; a hair-thin graze the 41 x 41 samples miss may still count)
 end
 check(wrong==0,'LobeHitsBox never misses an ellipse / turned box overlap (400 random cases): '..wrong)
end

-- ======================================================================================================================
-- Part 2: the real WeatherWorld149.client.lua on a mock of the owner's hub
-- ======================================================================================================================
do local base=R.new;R.new=function(class,...)local o=base(class,...)
 if class=='Sound'then o._props.Loaded=R.signal();o._props.Ended=R.signal();o._props.IsLoaded=true;o._props.TimeLength=3 end
 return o end end
R.Inst.Play=function(self)self._props.IsPlaying=true end;R.Inst.Stop=function(self)self._props.IsPlaying=false end;R.Inst.Clear=function()end
local Players=W.service('Players');local Run=W.Run;local Gui=W.Gui;local CS=W.CS
local player=R.new('Player');player.Name='P';player.UserId=3;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
local char,hrp
local function spawnAt(x,z)
 if char then char.Parent=nil end
 char=R.new('Model');char.Name='P';local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
 hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CanCollide=false;hrp.CFrame=CF(x,7,z);hrp.Parent=char;char.Parent=workspace;player.Character=char
end
local function moveTo(x,z)hrp.CFrame=CF(x,7,z);workspace.CurrentCamera.CFrame=CF(x,20,z+18)end
local function frames(sec)W.frames(floor(sec*60+.5),1/60)end
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace;map:SetAttribute('FieldWidth',180)
map:SetAttribute('BiomeStartZ_1',-100);map:SetAttribute('BiomeEndZ_1',400);map:SetAttribute('BiomeStartZ_6',400);map:SetAttribute('BiomeEndZ_6',2217.5)
local function box(parent,name,x0,x1,y0,y1,z0,z1,props)
 local p=R.new('Part');p.Name=name;p.Size=V3(x1-x0,y1-y0,z1-z0);p.CFrame=CF((x0+x1)/2,(y0+y1)/2,(z0+z1)/2);p.Anchored=true
 for k,v in pairs(props or{})do p[k]=v end
 p.Parent=parent;return p
end
local function folder(parent,name,class)local f=R.new(class or'Folder');f.Name=name;f.Parent=parent;return f end
local lobby=folder(map,'Lobby')
local floorPart=box(lobby,'LobbyFloor',-340,340,3,4,-623,-99)
box(lobby,'SafeZoneGroundTitle',-50,50,4.12,4.2,-118,-104,{CanCollide=false,Transparency=1})
local walls=folder(map,'ChestChaseWalls')
box(walls,'LobbyLeftWall',-340,-335,3,51,-623,-99);box(walls,'LobbyRightWall',335,340,3,51,-623,-99);box(walls,'LobbyBackWall',-335,335,3,51,-623,-618)
box(walls,'LobbyFrontWallLeft',-335,-94,3,51,-104,-99);box(walls,'LobbyFrontWallRight',94,335,3,51,-104,-99)
local bases=folder(map,'Bases')
local AVOID={} -- {name, x0, x1, z0, z1}: what no snow may lie on
local function avoidBox(name,x0,x1,z0,z1)AVOID[#AVOID+1]={name,x0,x1,z0,z1}end
for _,p in ipairs(PADS)do
 local b=folder(bases,'Base_'..p[1],'Model');b:SetAttribute('BaseIndex',p[1])
 box(b,'Pad',p[2],p[3],4,5,p[4],p[5])
 local plots=folder(b,'GardenPlots')
 -- beds over most of the pad (the free strip by the opening holds the treadmill and pedestal), like the place
 local inner=p[2]<0 and p[3]<-100 -- bases 1 / 3: the opening at +X
 local bx0,bx1=p[2],p[3]-30;if p[2]>100 then bx0,bx1=p[2]+30,p[3]end
 if p[1]>=5 then bx0,bx1=p[2],p[3]end
 local bz0,bz1=p[4],p[5];if p[1]>=5 then bz0=p[4];bz1=p[5]-34 end
 box(plots,'DirtPlot_1',bx0,bx1,5,5.8,bz0,(bz0+bz1)/2-12);box(plots,'DirtPlot_2',bx0,bx1,5,5.8,(bz0+bz1)/2+12,bz1)
 avoidBox('bed',bx0,bx1,bz0,(bz0+bz1)/2-12);avoidBox('bed',bx0,bx1,(bz0+bz1)/2+12,bz1)
 local design=folder(b,'GardenDesign36','Model');box(design,'Aisle paver',bx0,bx1,5,5.16,(bz0+bz1)/2-10,(bz0+bz1)/2+10);avoidBox('aisle',bx0,bx1,(bz0+bz1)/2-10,(bz0+bz1)/2+10)
 local tx=p[2]<0 and p[3]-15 or p[2]+15;if p[1]>=5 then tx=(p[2]+p[3])/2 end
 local tz=p[1]>=5 and p[5]-17 or(p[4]+p[5])/2+30
 local tm=folder(b,'TreadmillArtV131','Model');box(tm,'Belt',tx-9,tx+9,5,6.2,tz-7,tz+7);avoidBox('treadmill',tx-9,tx+9,tz-7,tz+7)
 local pz=p[1]>=5 and p[5]-17 or(p[4]+p[5])/2-30;local px=p[1]>=5 and p[2]+12 or tx
 local ped=folder(b,'MysteryPedestal','Model');box(ped,'Plinth',px-7,px+7,5,11,pz-7,pz+7);avoidBox('pedestal',px-7,px+7,pz-7,pz+7)
end
local eco=folder(map,'EconomyHub')
local market=folder(eco,'MerchantStands','Model');box(market,'Market deck',-25,25,4,12,-291,-247);avoidBox('market',-25,25,-291,-247)
local verity=folder(eco,'VerityNPC','Model');box(verity,'Dais',-14,14,4,5.2,-354,-326);avoidBox('verity',-14,14,-354,-326)
local displays=folder(map,'HubDisplays151')
for _,sx in ipairs({-1,1})do local d=folder(displays,sx<0 and'FruitDisplay'or'PullDisplay','Model');box(d,'Apron',sx*236-30,sx*236+30,4,5,-534,-498);avoidBox('display',sx*236-30,sx*236+30,-534,-498)end
-- R151 festival square: the decor folder (its streets are the kit's table: HubDecorKit151 is a real module of this checkout) and one street part
local decor=folder(map,'HubDecor151');local paths=folder(decor,'Paths','Model')
box(paths,'Side street',-127,-109,3.9,4.2,-404,-166,{CanQuery=false,CanCollide=false})
local Kit=W.module('HubDecorKit151')
for _,s in ipairs(Kit.Streets)do avoidBox('street',math.min(s[1],s[2]),math.max(s[1],s[2]),math.min(s[3],s[4]),math.max(s[3],s[4]))end
-- a tagged prop and a shovel hole out in the open
local prop=box(workspace,'Statue base',200,210,4,9,-210,-200);CS:AddTag(prop,'SnowAvoid');avoidBox('tagged',200,210,-210,-200)
local runtime=folder(map,'_GameplayRuntime');local holes=folder(runtime,'TrackHoles')
local function dig(name,x,z)
 local m=folder(holes,name,'Model')
 local pit=R.new('Part');pit.Name='Pit';pit.Shape=R.Enum.PartType.Cylinder;pit.Size=V3(.1,3.2,3.2);pit.CFrame=CF(x,4.05,z)*R.CFrame.Angles(0,0,math.pi/2);pit.Parent=m
 local rim=R.new('Part');rim.Name='Rim';rim.Shape=R.Enum.PartType.Cylinder;rim.Size=V3(.04,4,4);rim.CFrame=CF(x,4.02,z)*R.CFrame.Angles(0,0,math.pi/2);rim.Parent=m
 return m
end
-- straight-down raycasts against every part (box tops; RespectCanCollide / CanQuery honoured; the filter list excluded)
local rays,snowRays=0,0 -- (the snow's ground rays are the ones that RespectCanCollide)
local function isUnder(o,list)for _,f in ipairs(list or{})do if o==f or o:IsDescendantOf(f)then return true end end;return false end
local allParts={}
local function rescan()allParts={};for _,p in ipairs(workspace:GetDescendants())do if p:IsA('BasePart')and p._props.Size then allParts[#allParts+1]=p end end end
function workspace.Raycast(_,origin,dir,params)
 rays+=1;if params and params.RespectCanCollide then snowRays+=1 end
 local best,bestY=nil,-math.huge
 for _,p in ipairs(allParts)do
  if p._parent and p:IsDescendantOf(workspace)and p._props.CanQuery~=false and not(params and params.RespectCanCollide and p._props.CanCollide==false)then
   local c,s=p._props.CFrame.Position,p._props.Size
   local hx,hz,top=s.X/2,s.Z/2,c.Y+s.Y/2
   if p._props.Shape and p._props.Shape.Name=='Cylinder'then hx,hz,top=s.Y/2,s.Z/2,c.Y+s.X/2 end
   if abs(origin.X-c.X)<=hx and abs(origin.Z-c.Z)<=hz and top<=origin.Y and top>=origin.Y+dir.Y and top>bestY and not isUnder(p,params and params.FilterDescendantsInstances)then best,bestY=p,top end
  end
 end
 if not best then return nil end
 return{Position=V3(origin.X,bestY,origin.Z),Normal=V3(0,1,0),Instance=best}
end
local tier=3
W.stub('ClientFxBudget',{Get=function()if player:GetAttribute('FastMode')==true then return 1 end return tier end,Low=function()return tier==1 end})
-- property writes, by class.property
local counting,writes,byKey=false,0,{}
do local meta=R.instMeta;local nidx=meta.__newindex
 meta.__newindex=function(o,k,v)if counting and k~='Parent'then writes+=1;local key=o._class..'.'..k;byKey[key]=(byKey[key]or 0)+1 end;return nidx(o,k,v)end
end
spawnAt(-60,-200);moveTo(-60,-200)
rescan()
RS:SetAttribute('GlobalWeather','Clear')
local sc=R.new('LocalScript');sc.Name='WeatherWorld149';sc:SetAttribute('R151TestHook',true);local hook=W.load('WeatherWorld',sc)
check(type(hook)=='table'and hook.Layout,'the client script returns its test hook (R151TestHook)')
frames(1)
local function snowFolder()local f=workspace:FindFirstChild('_WeatherWorldR149');return f and f:FindFirstChild('Snow patches')end
local function discs()local out={};local f=snowFolder();if f then for _,d in ipairs(f:GetChildren())do if d.Transparency<1 then out[#out+1]=d end end end;return out end
local function bound()local list,n=hook.Bound();return n,list end

-- 1. The blizzard: the WHOLE hub fills (the player stands in one spot by Base 1 / 3)
RS:SetAttribute('GlobalWeather','Blizzard');frames(3)
local n3=bound()
check(n3>=60,('3 s into the blizzard most of the hub\'s drifts are already laid (%d), still faint'):format(n3))
local early=discs();local faint=true;for _,d in ipairs(early)do if d.Transparency<.7 then faint=false end end
check(#early>0 and faint,'they start faint (fading in over 10-20 s)')
frames(25)
local ds=discs()
local nb,list=bound()
local zones,far,nearMany={},0,0
for i=1,nb do local s=list[i].Spec
 local zx=floor((s.X+335)/(670/3));local zz=floor((s.Z+618)/(514/3));zones[zx*3+zz]=true
 local d=sqrt((s.X+60)^2+(s.Z+200)^2)
 if d>H.Tier(3).Mid+H.Tier(3).Hyst and list[i].Lobes>1 then far+=1 end
 if d<H.Tier(3).Near*.6 and list[i].Lobes>=min(3,s.N)then nearMany+=1 end
end
local nz=0;for _ in pairs(zones)do nz+=1 end
check(nz==9,('snow lies in all 9 zones of the hub, seen from one spot (%d zones, %d drifts, %d parts)'):format(nz,nb,#ds))
check(far==0 and nearMany>=3,('LOD: far drifts are one stretched disc, near ones full detail (%d far with more, %d near with 3+)'):format(far,nearMany))
local allWhite=true;for _,d in ipairs(ds)do if d.Transparency~=0 then allWhite=false end end
check(allWhite and #ds>=100,('after 28 s every drift is solid white (%d parts)'):format(#ds))
check(#snowFolder():GetChildren()<=H.Tier(3).Discs,('parts within the tier-3 budget (%d / %d)'):format(#snowFolder():GetChildren(),H.Tier(3).Discs))

-- 2. nothing lies on what it must not: beds, paths, treadmills, pedestals, the market, Verity, displays, streets, the tagged prop
local function discEllipse(d)
 local c=d.CFrame;local p=c.Position;local look,up=c.LookVector,c.UpVector
 return{X=p.X,Z=p.Z,A=d.Size.Z/2,B=d.Size.Y/2,AX=-look.X,AZ=-look.Z,BX=up.X,BZ=up.Z,Top=p.Y+d.Size.X/2,Bottom=p.Y-d.Size.X/2}
end
local function covers(e,x,z)local dx,dz=x-e.X,z-e.Z;local u=dx*e.AX+dz*e.AZ;local v=dx*e.BX+dz*e.BZ;return(u/e.A)^2+(v/e.B)^2<=1 end
local function overAvoid(list)
 local hits={}
 for _,d in ipairs(list)do local e=discEllipse(d);local r=max(e.A,e.B)
  for _,a in ipairs(AVOID)do
   if e.X+r>a[2]and e.X-r<a[3]and e.Z+r>a[4]and e.Z-r<a[5]then
    local hit=false
    for x=max(a[2],e.X-r),min(a[3],e.X+r),1 do for z=max(a[4],e.Z-r),min(a[5],e.Z+r),1 do if not hit and covers(e,x,z)then hit=true end end end
    if hit then hits[a[1]]=(hits[a[1]]or 0)+1 end
   end
  end
 end
 return hits
end
local hits=overAvoid(ds)
local hs={};for k,v in pairs(hits)do hs[#hs+1]=k..'='..v end
check(#hs==0,'no snow on a bed, an aisle, a treadmill, a pedestal, the market, Verity, a display, an R151 street or the tagged prop: '..table.concat(hs,' '))
local trackHit=0;for _,d in ipairs(ds)do local e=discEllipse(d);if not WW.Outside(AREA,e.X,e.Z,max(e.A,e.B),0)then trackHit+=1 end end
check(trackHit==0,'no snow reaches the track')
-- heights: on the floor (4) or a pad (5), bottoms .07 over it; overlapping discs never share a top plane; no top near the streets' planes
local heightOk,shared,keep=true,0,0
local es={};for _,d in ipairs(ds)do es[#es+1]=discEllipse(d)end
for _,e in ipairs(es)do
 local g=e.Bottom-H.Rise
 if not(near(g,4,.001)or near(g,5,.001))then heightOk=false end
 if near(g,4,.001)then for _,y in ipairs({4.06,4.07,4.12,4.14,4.20,4.26,4.32})do if abs(e.Top-y)<.01 then keep+=1 end end end
end
for a=1,#es do for b=a+1,#es do local e1,e2=es[a],es[b]
 if abs(e1.X-e2.X)<60 and abs(e1.Z-e2.Z)<60 and abs(e1.Top-e2.Top)<.004-1e-6 then
  -- do they overlap? (sample e1's outline and centre)
  local ov=covers(e2,e1.X,e1.Z)or covers(e1,e2.X,e2.Z)
  for t=0,23 do if not ov then local an=t/24*2*math.pi;for _,rr in ipairs({1,.5})do
   local u,v=math.cos(an)*e1.A*rr,math.sin(an)*e1.B*rr
   if covers(e2,e1.X+u*e1.AX+v*e1.BX,e1.Z+u*e1.AZ+v*e1.BZ)then ov=true end end end end
  if ov then shared+=1 end
 end
end end
check(heightOk,'every disc lies .07 over its ground (the floor 4.0 or a base pad 5.0)')
check(shared==0,'no two overlapping discs share a top plane (z-fighting): '..shared)
check(keep==0,'no snow top near the R151 streets / plazas / curbs / grass patches planes: '..keep)

-- 3. a shovel hole in the hub: drifts that reach it go at once, and come back when it is filled
local holeX,holeZ
for i=1,nb do local s=list[i].Spec;if s.N>0 and abs(s.X)>150 and s.Z<-430 then holeX,holeZ=s.X+s.LX[1],s.Z+s.LZ[1];break end end
check(holeX~=nil,'(a drift to dig a hole under)')
local hole=dig('Hole1',holeX,holeZ);rescan();frames(.5)
local covered=0;for _,d in ipairs(discs())do local e=discEllipse(d);if covers(e,holeX,holeZ)or covers(e,holeX+2.2,holeZ)or covers(e,holeX-2.2,holeZ)then covered+=1 end end
check(covered==0,'a shovel hole dug under a drift: within half a second no snow covers it ('..covered..')')
hole:Destroy();rescan();frames(6)
local back=0;for _,d in ipairs(discs())do local e=discEllipse(d);if covers(e,holeX,holeZ)then back+=1 end end
check(back>0,'the hole is filled: the snow comes back')

-- 4. streaming: a bed that streams in under a drift drops it; a drift with no ground under it (not streamed in) waits and comes back
local bedX,bedZ
for i=1,select(1,bound())do local _,l=bound();local s=l[i].Spec;if hook.Layout()[l[i].Key].Pad==0 and abs(s.X)<300 and s.Z>-400 and s.Z<-150 and abs(s.X)>20 then bedX,bedZ=s.X,s.Z;break end end
local lateBed=box(bases,'DirtPlot_99',bedX-3,bedX+3,4,4.8,bedZ-3,bedZ+3);rescan();frames(.4)
local onBed=0;for _,d in ipairs(discs())do local e=discEllipse(d);for x=bedX-3,bedX+3,1 do for z=bedZ-3,bedZ+3,1 do if covers(e,x,z)then onBed+=1 end end end end
check(onBed==0,'a garden bed streaming in under a drift: the drift goes within half a second (DescendantAdded, not the 4 s re-read)')
lateBed:Destroy();rescan()

-- 5. the weather ends: everything fades out over 20-40 s, then every part is back in the pool
RS:SetAttribute('GlobalWeather','Clear');frames(3)
local pal=0;local nd=discs();for _,d in ipairs(nd)do if d.Transparency>0 then pal+=1 end end
check(pal>=#nd*.9,('3 s after the snow stops the drifts are paling (%d / %d)'):format(pal,#nd))
frames(20);check(#discs()>0,'... and still there 23 s later (20-40 s fade out)')
frames(22)
check(#discs()==0 and select(1,bound())==0,'45 s after the snow: nothing left, every drift released')

-- 6. tiers: the part budget per tier, tier 1 drops the sprinkle inside the bases; FastMode = tier 1
local perTier={}
for _,t in ipairs({2,1,3})do
 tier=t;frames(3.5)
 RS:SetAttribute('GlobalWeather','Blizzard');frames(30)
 local f=snowFolder();local made=#f:GetChildren();local n=#discs()
 perTier[t]=n
 local inner=0;local nbb,l=bound();for i=1,nbb do local spec=hook.Layout()[l[i].Key];if spec.Kind=='inner'then inner+=1 end end
 check(made<=H.Tier(t).Discs,('tier %d: %d snow parts made, budget %d'):format(t,made,H.Tier(t).Discs))
 if t<3 then check(inner==0,('tier %d: no snow inside the bases (the lowest priority)'):format(t))end
 RS:SetAttribute('GlobalWeather','Clear');frames(45)
end
check(perTier[1]<perTier[2]and perTier[2]<perTier[3],('fewer parts on lower tiers: %d / %d / %d'):format(perTier[3],perTier[2],perTier[1]))
print(('parts drawn (player at -60, -200): tier 3 %d, tier 2 %d, tier 1 %d'):format(perTier[3],perTier[2],perTier[1]))
tier=3;frames(4)

-- 7. walking through the hub in the blizzard: LOD follows, writes stay small, no part created, the budget always holds
RS:SetAttribute('GlobalWeather','Blizzard');frames(30)
for i=1,600 do local a=i/600*2*math.pi;moveTo(math.cos(a)*170,-330+math.sin(a)*170);W.frames(1,1/60)end -- (a first lap: the pool grows to what a lap needs)
local n0=#R.created
counting=true;writes=0;table.clear(byKey)
local maxParts=0
for i=1,600 do -- 10 s, ~40 studs/s around the market
 local a=i/600*2*math.pi;moveTo(math.cos(a)*170,-330+math.sin(a)*170)
 W.frames(1,1/60)
 if i%30==0 then maxParts=max(maxParts,#snowFolder():GetChildren())end
end
counting=false
local snowWrites=(byKey['Part.Size']or 0)+(byKey['Part.CFrame']or 0)+(byKey['Part.Transparency']or 0)+(byKey['Part.Color']or 0)
check(#R.created==n0,'walking round the hub a second time creates no Instance (the pool is warm): '..(#R.created-n0))
check(maxParts<=H.Tier(3).Discs,'the part budget holds while walking ('..maxParts..')')
check(snowWrites/600<=12,('walking at 40 studs/s: %.1f snow property writes a frame (LOD reshapes, bounded per step)'):format(snowWrites/600))
print(('walking: %.1f snow writes / frame, %.1f weather writes / frame in all'):format(snowWrites/600,writes/600))
-- standing still in the snow: nothing to do (after a second for the last LOD steps of the walk)
frames(1.5)
counting=true;writes=0;table.clear(byKey);local r0=snowRays
frames(10)
counting=false
local still=(byKey['Part.Size']or 0)+(byKey['Part.CFrame']or 0)+(byKey['Part.Transparency']or 0)
check(still==0,'standing in the settled snow: no snow property writes ('..still..')')
check(snowRays-r0==0,('standing: %d snow raycasts in 10 s (every drift was checked once)'):format(snowRays-r0))

-- 8. far from the hub (down the track behind the walls): the hub's snow is released; it comes back on return, with no new checks
local checked=0;for k,v in pairs(hook.Stat)do checked+=1 end
moveTo(0,700);frames(2)
check(select(1,bound())==0 and #discs()==0,'down the track the hub\'s snow is put away (0 parts drawn)')
r0=snowRays;moveTo(-60,-200);frames(4)
check(select(1,bound())>=100,'back in the hub it is all there again')
check(snowRays-r0==0,'... without checking the drifts again ('..(snowRays-r0)..' snow raycasts)')

-- 9. Reduced Motion: the snow is the same (it never moves)
local before=#discs();Gui.ReducedMotionEnabled=true;frames(2);check(#discs()==before,'Reduced Motion: the same snow');Gui.ReducedMotionEnabled=false

-- 10. rain (R151, owner: "some of the droplets can have impact with the ground, not all"): the falling rain is exactly as dense as before
-- (the cap keeps its room for the old splash shares), a share of the drops splash - fewer away from the player and on lower tiers
do
 local function emitters()
  local f=workspace:FindFirstChild('_WeatherWorldR149');local drops,spray,ripple,sprayOld,rippleOld=0,0,0,0,0
  local S=WW.Splash
  for _,t in ipairs(f['Sky tiles']:GetChildren())do local e=t:FindFirstChildWhichIsA('ParticleEmitter');if e.Enabled then drops+=e.Rate*(e.Lifetime.Min+e.Lifetime.Max)/2 end end
  for _,gt in ipairs(f['Ground tiles']:GetChildren())do
   local sp,rp=gt:FindFirstChild('Splash spray'),gt:FindFirstChild('Splash ripple')
   if sp.Enabled then spray+=sp.Rate*(sp.Lifetime.Min+sp.Lifetime.Max)/2 end
   if rp.Enabled then ripple+=rp.Rate*(rp.Lifetime.Min+rp.Lifetime.Max)/2 end
  end
  return drops,spray+ripple
 end
 local rows={}
 for _,t in ipairs({3,2,1})do
  for _,kind in ipairs({'Rain','Thunderstorm'})do
   tier=t;RS:SetAttribute('GlobalWeather',kind);frames(4)
   local drops,splash=emitters()
   local p=WW.Profile(kind,t,false)
   -- R149: every splash share applied to every near drop: the old splash particles = drops x the budget's splash factor (at most, near tiles)
   local oldSplash=drops*p.SplashFactor
   rows[#rows+1]=('%s tier %d: %.0f drops (as R149), %.0f splash particles (R149 up to %.0f)'):format(kind,t,drops,splash,oldSplash)
   check(drops+splash<=p.Cap*1.001,('%s tier %d: drops + splashes within the cap %d'):format(kind,t,p.Cap))
   check(splash>0 and splash<=oldSplash*.5,('%s tier %d: a share of the drops splash (%.0f splash particles, at most half of R149\'s %.0f)'):format(kind,t,splash,oldSplash))
  end
 end
 -- the drop density is the R149 one: Scale budgets the cap with the old shares, so the rates the drops get did not move
 local p=WW.Profile('Rain',2,false);local S=WW.Splash
 check(S.BudgetSpray==.4 and S.BudgetRipple==.3 and S.SprayShare<S.BudgetSpray and S.RippleShare<S.BudgetRipple,'the cap still reserves the R149 splash shares (.4 / .3): the drops keep their R149 density')
 check(WW.SplashShare(1,1,3)==1 and WW.SplashShare(1,0,3)<.5 and WW.SplashShare(1,1,1)<WW.SplashShare(1,1,2)and WW.SplashShare(1,1,2)<1,'splashes thin out away from the player and on lower tiers')
 for _,l in ipairs(rows)do print('  '..l)end
 tier=3;RS:SetAttribute('GlobalWeather','Clear');frames(4)
end

-- 11. teardown
sc.Destroying:Fire()
check(workspace:FindFirstChild('_WeatherWorldR149')==nil,'teardown removes every snow part')
RS:SetAttribute('GlobalWeather','Clear')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
