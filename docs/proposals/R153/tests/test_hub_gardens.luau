--!nocheck
-- R153 hub fixes: checks of the REAL code (ChestChaseServer.GardenBaseLayout + HubDecor151 -> HubTrampoline153 run by MapService.new, ReplicatedStorage.HubLifeArt151,
-- HubTrampolineRules153, StarterPlayerScripts.HubTrampoline153.client) on the owner's place (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py) in the R149
-- Roblox mock. Prints "ok <name>" / "FAIL <name>: why" and "INFO ..." lines; errors at the end if anything failed. MUTANT (a global the runner may set): 'noramps' = the
-- garden ramps are removed before the measurements, 'stack' = a bounce that adds to the speed, 'nodebounce' = no cooldown: each must make the test fail (run.sh mutate).
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local MUT=MUTANT
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal();function Players.GetPlayers()return{}end
function Players.GetPlayerByUserId()return nil end;function Players.GetUserThumbnailAsync()return'',true end
local Http=W.service('HttpService');local guid=0;function Http.GenerateGUID()guid+=1;return'guid-'..guid end;function Http.JSONEncode(_,t)return'{}'end;function Http.JSONDecode()return{}end
local DS=W.service('DataStoreService');function DS.GetDataStore()return{GetAsync=function()return nil end,SetAsync=function()end,UpdateAsync=function()return nil end}end;DS.GetOrderedDataStore=DS.GetDataStore
local MS=W.service('MarketplaceService');MS.PromptProductPurchaseFinished=R.signal();MS.PromptGamePassPurchaseFinished=R.signal()
W.env.bit32=bit32
do local Inst=R.Inst;local raw=Inst.IsA
 function Inst:IsA(c)if self._class=='SpawnLocation'and(c=='Part'or c=='BasePart'or c=='PVInstance'or c=='FormFactorPart')then return true end;return raw(self,c)end
end
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='BindableEvent'then o.Event=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 return o end
 W.env.Instance=R.Instance
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
if not RS:FindFirstChild('R142Keycap')then
 local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55)
 local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
 local tl=R.new('TextLabel');tl.Name='TextLabel';tl.Parent=tgui;template.Parent=RS
end
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function info(s)print('INFO '..s)end
local function first(list)return list[1]and(tostring(list[1])..' (+'..(#list-1)..' more)')or nil end
-- the saved plots and pads as the place file has them (before anything runs)
local saved={}
for _,b in ipairs(map.Bases:GetChildren())do for _,p in ipairs(b:GetDescendants())do if p:IsA('BasePart')and(p.Name=='Pad'or p.Name:match('^DirtPlot_%d'))then
 saved[p]={Pos=p._props.CFrame.Position,Size=p._props.Size,R=p._props.CFrame.R,Collide=p._props.CanCollide}
end end end
local Config=server('Config')
server('MapService').new(Config);R.advance(.1)
R.advance(1)

-- geometry helpers ---------------------------------------------------------------------------------------------------------------------------
local function aabb(p)
 local c=p._props.CFrame;local s=p._props.Size;local r=c.R;local q=c.Position
 local e={(math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2}
 return{q.X-e[1],q.Y-e[2],q.Z-e[3]},{q.X+e[1],q.Y+e[2],q.Z+e[3]}
end
local function corners(p) -- the 8 world corners of a box part
 local c=p._props.CFrame;local s=p._props.Size;local out={}
 for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do for _,sz in ipairs({-1,1})do out[#out+1]=c*V3(sx*s.X/2,sy*s.Y/2,sz*s.Z/2)end end end
 return out
end
local function solid(p)return p._props.CanCollide~=false end
local function parts(root)local out={};for _,p in ipairs(root:GetDescendants())do if p:IsA('BasePart')then out[#out+1]=p end end;return out end
local function path(p)return Z.path(p)end

-- 0. the runner's step limit: what the game's own sweep (RunnerSweep.Hull) lets a body step over ------------------------------------------
local Sweep=W.module('RunnerSweep')
local LIMIT=math.huge
do
 local function rig(rootY,hip,leg)
  local ch=R.new('Model');local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,rootY,1);root.Parent=ch
  local hum=R.new('Humanoid');hum.HipHeight=hip;hum.RigType=leg and R.Enum.HumanoidRigType.R6 or R.Enum.HumanoidRigType.R15;hum.Parent=ch
  if leg then local l=R.new('Part');l.Name='Left Leg';l.Size=V3(1,leg,1);l.Parent=ch end
  local size,off=Sweep.Hull(ch,hum,root)
  local standing=rootY/2+hip+(leg or 0)
  return off.Y-size.Y/2+standing -- the hull's bottom over the feet
 end
 local rigs={R15=rig(2,2),R15small=rig(1.4,1.2),R15big=rig(3,3),R6=rig(2,0,2)}
 for _,c in pairs(rigs)do LIMIT=math.min(LIMIT,c)end
 info(string.format('step limit: the runner sweep clears %.2f studs over the feet (R15 %.2f, small R15 %.2f, big R15 %.2f, R6 %.2f)',LIMIT,rigs.R15,rigs.R15small,rigs.R15big,rigs.R6))
 check('step limit: the game steps over at least 1 stud and no more than 1.2 (RunnerSweep.Hull, four rigs)',LIMIT>=1 and LIMIT<=1.2,LIMIT)
end

-- 1. the benches (and the beds they flanked) in the two garden nooks are gone ---------------------------------------------------------------
local K=W.module('HubDecorKit151');local Art=W.module('HubLifeArt151');local T=W.module('HubTrampolineRules153')
local NOOKS={{312,-269},{-312,-269}}
do
 local near={}
 for _,b in ipairs(Art.Layout.benches)do for _,n in ipairs(NOOKS)do if (b[1]-n[1])^2+(b[2]-n[2])^2<20^2 then near[#near+1]=b[1]..','..b[2]end end end
 check('benches: none of the layout\'s benches stands within 20 studs of a garden nook\'s centre (the two teal pairs are gone)',#near==0,first(near))
 check('benches: the other five stay (two wooden on the front lawns, two garden benches by the market, one stone bench at the lane nook)',#Art.Layout.benches==5,#Art.Layout.benches)
 local kinds={};for _,b in ipairs(Art.Layout.benches)do kinds[b[4]]=(kinds[b[4]]or 0)+1 end
 check('benches: 2 wood, 2 garden, 1 stone',kinds.wood==2 and kinds.garden==2 and kinds.stone==1)
 local bedsNear={};for _,b in ipairs(Art.Layout.beds)do for _,n in ipairs(NOOKS)do if (b[1]-n[1])^2+(b[2]-n[2])^2<8^2 then bedsNear[#bedsNear+1]=b[1]..','..b[2]end end end
 check('benches: the flower beds at the nooks\' centres (the dark disc ringed in white) are gone too: 11 beds left, the trampolines stand there',#bedsNear==0 and #Art.Layout.beds==11,first(bedsNear)or#Art.Layout.beds)
 check('benches: the kit keeps both trampoline circles open (HubLifeArt151.Clear refuses them)',#K.Open==3 and select(2,Art.Clear(312,-269,0))=='open'and select(2,Art.Clear(-312,-269,0))=='open'and select(2,Art.Clear(0,-392,0))=='open')
 -- built (every device tier): no bench parts and no bed rim at the nooks
 local root=R.new('Folder');root.Name='ArtTest';root.Parent=W.workspace
 local ctx=Art.Build(root,3,{},{})
 local seats,slabs,rims,badNear={},{},{},{}
 for _,p in ipairs(parts(root))do
  local q=p._props.CFrame.Position
  if p.Name=='Bench seat'then seats[#seats+1]=p elseif p.Name=='Bench slab'then slabs[#slabs+1]=p elseif p.Name=='Bed rim'then rims[#rims+1]=p end
  for _,n in ipairs(NOOKS)do if (q.X-n[1])^2+(q.Z-n[2])^2<12^2 and(p.Name:find('^Bench')or p.Name:find('^Bed ')or p.Name=='Flower')then badNear[#badNear+1]=p.Name end end
 end
 check('benches: built: 4 bench seats (2 wood, 2 garden) and 1 stone slab, no bench part and no bed part within 12 studs of a nook',#seats==4 and #slabs==1 and #badNear==0,#seats..'/'..#slabs..' '..tostring(first(badNear)))
 check('benches: built: 11 flower bed rims',#rims==11,#rims)
 root:Destroy()
end

-- 2. the trampolines: geometry, collision = look, step, room ---------------------------------------------------------------------------------
local tf=map:FindFirstChild(T.FolderName)
check('trampolines: ChestChaseMap.HubTrampolines153 exists (built by HubDecor151.Apply)',tf~=nil)
if not tf then error('no trampolines')end
local models=tf:GetChildren()
local function modelOf(name)for _,m in ipairs(models)do if m.Name=='Trampoline '..name then return m end end end
check('trampolines: one in the Desert nook (+X) and one in the Lava nook (-X), persistent models',#models==2 and modelOf('Desert')~=nil and modelOf('Lava')~=nil and modelOf('Desert')._props.ModelStreamingMode==R.Enum.ModelStreamingMode.Persistent)
local dec=map.HubDecor151
do
 local rimSolid={}
 for _,p in ipairs(parts(tf))do if solid(p)and p.Name~='Trampoline collider'then rimSolid[#rimSolid+1]=path(p)end end
 check('trampolines: the collider is the ONLY part that collides (2 in all); the dressing is walk-through',#rimSolid==0,first(rimSolid))
 local bad={}
 for _,p in ipairs(parts(tf))do
  local isCol=p.Name=='Trampoline collider'
  if p._props.Anchored~=true or p._props.CanTouch~=false or p._props.CanQuery~=(isCol and true or false)then bad[#bad+1]=path(p)end
 end
 check('trampolines: every part anchored, untouchable; only the collider can be queried (clicks and rays pass through the dressing)',#bad==0,first(bad))
 local decorCollide=0;for _,p in ipairs(parts(dec))do if solid(p)then decorCollide+=1 end end
 check('trampolines: HubDecor151 itself is as R152 left it: only the 4 gate shafts collide there',decorCollide==4,decorCollide)
end
local TRAMP={}
for _,spot in ipairs(T.Spots)do
 local m=modelOf(spot.Name);local cx,cz=spot.X,spot.Z
 local count={};local col
 for _,p in ipairs(m:GetChildren())do count[p.Name]=(count[p.Name]or 0)+1;if p.Name=='Trampoline collider'then col=p end end
 check('trampoline '..spot.Name..': 1 collider, 6 feet, 16 frame boxes, 1 dark gap, 16 springs, 1 mat, 1 badge (42 parts)',count['Trampoline collider']==1 and count['Trampoline foot']==6 and count['Trampoline frame']==16
  and count['Trampoline gap']==1 and count['Trampoline spring']==16 and count['Trampoline mat']==1 and count['Trampoline badge']==1 and #m:GetChildren()==42,#m:GetChildren())
 local lo,hi=aabb(col)
 local radius=col._props.Size.Y/2
 local mat=m:FindFirstChild('Trampoline mat');local matLo,matHi=aabb(mat)
 local frameTop,frameOut,frameIn=-math.huge,0,math.huge
 for _,p in ipairs(m:GetChildren())do if p.Name=='Trampoline frame'then
  local _,h=aabb(p);frameTop=math.max(frameTop,h[2])
  for _,c in ipairs(corners(p))do local d=math.sqrt((c.X-cx)^2+(c.Z-cz)^2);frameOut=math.max(frameOut,d);frameIn=math.min(frameIn,d)end
 end end
 check('trampoline '..spot.Name..': the collider is centred on the nook\'s middle (312 / -269) and invisible',math.abs((lo[1]+hi[1])/2-cx)<.01 and math.abs((lo[3]+hi[3])/2-cz)<.01 and col._props.Transparency==1)
 check('trampoline '..spot.Name..': the collider\'s walking top is the rules\' Top (floor + 0.9) and the mat, the badge\'s base and the frame stand within 0.1 of it',
  math.abs(hi[2]-T.Top())<.001 and math.abs(matHi[2]-hi[2])<.1 and math.abs(frameTop-hi[2])<.1,string.format('collider %.3f mat %.3f frame %.3f',hi[2],matHi[2],frameTop))
 check('trampoline '..spot.Name..': the collider covers the frame\'s footprint (radius 6.05; the 16-gon\'s outer corners within 0.2), the mat (r 4.15) lies inside the frame\'s inner edge',
  math.abs(radius-T.Dims.Radius)<.01 and math.abs(frameOut-radius)<.2 and frameIn>=4.9 and math.abs((matHi[1]-matLo[1])/2-T.Dims.MatRadius)<.01,string.format('collider %.2f frame %.2f..%.2f',radius,frameIn,frameOut))
 local ringFree=13-radius
 check('trampoline '..spot.Name..': inside the nook (13-stud brick disc) with a '..string.format('%.2f',ringFree)..'-stud ring to walk round it (6 or more)',ringFree>=6)
 TRAMP[spot.Name]={Model=m,Collider=col,Mat=mat,Cx=cx,Cz=cz,Top=hi[2]}
 -- every solid thing in the map within 20 studs of the collider is the floor or its support (nothing to bump, nothing blocked)
 local nearSolid={}
 for _,p in ipairs(parts(map))do if solid(p)and p~=col and p.Name~='LobbyFloor'and not p.Name:find('^Support_')then
  local a,b=aabb(p);if a[1]<cx+radius+8 and b[1]>cx-radius-8 and a[3]<cz+radius+8 and b[3]>cz-radius-8 and b[2]>4.2 then nearSolid[#nearSolid+1]=path(p)end
 end end
 check('trampoline '..spot.Name..': no other solid part within 8 studs of its edge (the wall is 17 studs away)',#nearSolid==0,first(nearSolid))
end
do -- the garden walk reaches the nook 7 studs from the frame; the nook's rim is 6.95 studs from it
 local walkEnd=299;local gap=(312-T.Dims.Radius)-walkEnd
 check('trampolines: the garden walk meets the nook\'s rim 7 studs before the frame (the way in stays open on both sides)',gap>=6.5,gap)
 local wall=335;local edge=312+T.Dims.Radius
 check('trampolines: 17 studs between the frame and the wall',wall-edge>=15,wall-edge)
 local lo,hi=aabb(TRAMP.Desert.Collider)
 check('trampolines: the mat\'s walking top is within the runner\'s step limit over the floor (0.9 <= '..string.format('%.2f',LIMIT)..'): walk on, no jump needed',hi[2]-K.Floor<=LIMIT and hi[2]-K.Floor>=.5,hi[2]-K.Floor)
end

-- 3. the bounce: velocity, apex, debounce, no stacking ---------------------------------------------------------------------------------------
if MUT=='nodebounce'then T.Cooldown=0 end
if MUT=='stack'then T.Launch=function(v,up)return V3(v.X,v.Y+up,v.Z)end end
local G=196.2
do
 local v=T.Velocity(G)
 check('bounce: one config value, BounceHeight = 30 studs; the launch speed is sqrt(2 g h) = '..string.format('%.1f',v)..' studs/s',T.BounceHeight==30 and math.abs(v-math.sqrt(2*G*30))<1e-9)
 local apex=T.Apex(v,G)
 check('bounce: the apex is 25 - 35 studs over the mat ('..string.format('%.2f',apex)..')',apex>=25 and apex<=35,apex)
 local ok=true;for _,g in ipairs({60,100,150,196.2,250,400})do local a=T.Apex(T.Velocity(g),g);if math.abs(a-30)>1e-6 then ok=false end end
 check('bounce: the apex is the same 30 under any gravity (the launch speed follows workspace.Gravity)',ok)
 check('bounce: an odd gravity (nil, 0, NaN) falls back to 196.2',math.abs(T.Velocity(nil)-v)<1e-9 and math.abs(T.Velocity(0)-v)<1e-9 and math.abs(T.Velocity(0/0)-v)<1e-9)
 local m=RS:FindFirstChild('HubTrampolineRules153')
 m:SetAttribute('BounceHeight',200);local tall=T.Height();m:SetAttribute('BounceHeight',-3);local low=T.Height();m:SetAttribute('BounceHeight',0/0);local nan=T.Height();m:SetAttribute('BounceHeight','x');local str=T.Height()
 m:SetAttribute('BounceHeight',nil)
 check('bounce: the Studio attribute is clamped to 12 - 40 studs (never a sky launch); junk reads as 30',tall==T.MaxHeight and low==T.MinHeight and nan==30 and str==30 and T.MaxHeight<=40 and T.Height()==30,tall..' '..low..' '..nan..' '..str)
 -- a body simulated at 60 Hz on the mat: the rules decide, T.Launch sets the speed
 local function simulate(seconds,hold)
  local st=T.NewState();local now=0;local y=T.Top()+.05;local vel=V3(3,-20,-2);local bounces,apexes,maxUp={},{},0;local peak=y
  for _=1,math.floor(seconds*60)do
   now+=1/60
   if hold then vel=V3(0,0,0);y=T.Top()else
    vel=V3(vel.X,vel.Y-G/60,vel.Z);y+=vel.Y/60
    if y<=T.Top()and vel.Y<0 then y=T.Top();vel=V3(vel.X,0,vel.Z)end
   end
   local up=T.Step(st,now,0,0,y,vel.Y,G)
   if up then
    if #bounces>0 then apexes[#apexes+1]=peak-T.Top()end;peak=y
    bounces[#bounces+1]=now;vel=T.Launch(vel,up)
   end
   maxUp=math.max(maxUp,vel.Y);peak=math.max(peak,y)
  end
  return bounces,apexes,maxUp,vel
 end
 local bounces,apexes,maxUp,vel=simulate(20)
 local lo,hi=math.huge,0;for _,a in ipairs(apexes)do lo=math.min(lo,a);hi=math.max(hi,a)end
 check('bounce: 20 s on the mat bounce after bounce ('..#bounces..'), every apex 29 - 31 studs ('..string.format('%.2f',lo)..' - '..string.format('%.2f',hi)..'), never higher: no stacking',#bounces>=12 and lo>=29 and hi<=31,#bounces..' '..lo..' '..hi)
 check('bounce: the speed never exceeds the launch speed ('..string.format('%.1f',maxUp)..' <= '..string.format('%.1f',v)..'), the horizontal speed is kept',maxUp<=v+1e-6 and vel.X==3 and vel.Z==-2,maxUp)
 local gap=math.huge;for i=2,#bounces do gap=math.min(gap,bounces[i]-bounces[i-1])end
 check('bounce: bounces are at least the flight time and the 0.45 s cooldown apart ('..string.format('%.2f',gap)..' s)',gap>=T.Cooldown-1e-9 and gap>1,gap)
 local held=simulate(10,true)
 check('debounce: a body held on the mat (no way to leave) bounces at most once per 0.45 s: '..#held..' in 10 s (<= 23)',#held>=20 and #held<=23,#held)
 -- single decisions
 local st=T.NewState();local top=T.Top()
 check('rules: standing on the mat (feet at the top, not rising) bounces: stepping on counts',T.Step(st,100,0,0,top,0,G)~=nil)
 check('rules: the cooldown holds .44 s and releases at .45 s',T.Step(st,100.44,0,0,top,0,G)==nil and T.Step(st,100.451,0,0,top,0,G)~=nil)
 local s2=T.NewState()
 check('rules: a body still rising (a bounce, a jump: 21 studs/s or more) is left alone; 20 or less bounces',T.Step(s2,1,0,0,top,50,G)==nil and T.Step(s2,1,0,0,top,108,G)==nil and T.Step(s2,1,0,0,top,20,G)~=nil)
 local s3=T.NewState()
 check('rules: off the mat (6.3 studs out), or flying over it (feet 1 stud above the top) does nothing',T.Step(s3,1,6.3,0,top,0,G)==nil and T.Step(s3,1,0,0,top+1,-30,G)==nil and T.Step(s3,1,4,4,top,0,G)~=nil)
 check('rules: a body that tunnelled to the floor in one fast step (feet at 4.0) still bounces; one far under the floor does not',T.Step(T.NewState(),1,0,0,4.0,-100,G)~=nil and T.Step(T.NewState(),1,0,0,3.2,-100,G)==nil)
 check('rules: the bounce SETS the vertical speed (a launch at 15 studs/s is exactly v, not 15 + v; the sideways speed stays)',T.Launch(V3(7,15,-4),v).Y==v and T.Launch(V3(7,15,-4),v).X==7 and T.Launch(V3(7,15,-4),v).Z==-4)
 check('rules: the squash is 1 at the bounce, rebounds past 0 and is gone by 0.6 s',T.Squash(0)==1 and T.Squash(.25)<0 and T.Squash(.6)==0 and T.Squash(-1)==0 and T.SquashDepth<=.3 and T.Top()-T.SquashDepth>T.Floor+.62)
 -- MovementGuard: a rising player is allowed 18 + max(jump, 48, ceiling x .65) x elapsed x 1.5 studs per sample (read from the source)
 local formula=W.B.MovementGuard:find('local riseAllowance=18+math.max(jump,48,ceiling*.65)*elapsed*1.5',1,true)
 check('guard: MovementGuard still allows 18 + max(jump, 48, ceiling x .65) x elapsed x 1.5 studs of rise per sample (the formula is in the source)',formula~=nil)
 local worst,flight=0,2*v/G
 for off=0,9 do -- samples every .1 s at ten different phases through the whole flight
  local prev=0
  for k=0,math.floor(flight/.1) do
   local t=off/100+k*.1;if t>flight then break end
   local y=v*t-.5*G*t*t;worst=math.max(worst,y-prev);prev=y
  end
 end
 local allow=18+math.max(50,48,0)*.1*1.5
 check('guard: the biggest rise between two .1 s samples of a bounce is '..string.format('%.1f',worst)..' studs, under the guard\'s '..string.format('%.1f',allow)..' (a launch is never corrected)',worst<allow,worst)
end

-- 4. the client script in the mock ---------------------------------------------------------------------------------------------------------------
do
 local plays,preloads={},{}
 W.stub('LocalSfx',{Play=function(id,pos,vol,pitch,life)plays[#plays+1]={Id=id,Pos=pos,Vol=vol,Pitch=pitch,Life=life};return{}end,Preload=function(ids)preloads[#preloads+1]=ids end})
 local plr=R.new('Player');plr.Name='Tester';plr.UserId=1001;plr.Parent=Players;Players.LocalPlayer=plr
 local other=R.new('Player');other.Name='Other';other.UserId=1002;other.Parent=Players
 local list={plr,other};function Players.GetPlayers()return list end
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=plr
 W.workspace.Gravity=G
 local function character(name,x,y,z)
  local m=R.new('Model');m.Name=name
  local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Transparency=1;root.Parent=m
  local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.RigType=R.Enum.HumanoidRigType.R15;hum.Parent=m;m.PrimaryPart=root;m.Parent=W.workspace
  root.CFrame=CF(x,y,z);return m,root,hum
 end
 local feetToRoot=3 -- root half height 1 + hip height 2
 local function put(root,x,feet,z,vx,vy,vz)root.CFrame=CF(x,feet+feetToRoot,z);root.AssemblyLinearVelocity=V3(vx or 0,vy or 0,vz or 0)end
 local mineM,mine,mineH=character('Tester',100,10,-269);plr.Character=mineM
 local otherM,oroot=character('Other',0,10,-269);other.Character=otherM
 local sc=R.new('LocalScript');sc.Name='HubTrampoline153';sc:SetAttribute('R153TestHook',true);sc.Parent=pg
 local api=W.load('HubTrampoline153Client',sc)
 W.frames(2)
 check('client: finds both trampolines on its first look',#api.Spots==2 and api.Spots[1].Mat~=nil and api.Spots[2].Badge~=nil,#api.Spots)
 check('client: the script announced itself',sc:GetAttribute('R153Loaded')==true)
 local d=TRAMP.Desert
 local up=T.Velocity(G)
 -- far away (100 studs from the nook): a body on the mat is nobody's business of this client
 put(oroot,312,d.Top,-269,0,-30,0);W.frames(3)
 check('client: far from a nook (the local character is 212 studs away) nothing runs: no boing, no squash',#plays==0 and #api.Active==0)
 put(oroot,0,60,-100,0,0,0)
 -- the local character lands on the Desert mat from above, falling at 50
 put(mine,312,d.Top+.1,-269,5,-50,-2);W.frames(1)
 local v1=mine.AssemblyLinearVelocity
 check('client: landing on the mat sets the vertical speed to the launch speed ('..string.format('%.1f',v1.Y)..'), the sideways speed stays (5, -2)',math.abs(v1.Y-up)<1e-6 and v1.X==5 and v1.Z==-2,tostring(v1))
 check('client: ONE boing per bounce, at the mat: the owner\'s trampoline file (94320656351627), pitch 1 (no pitch shift), quiet (R153: it replaced Bubble04 at .8)',#plays==1 and plays[1].Id=='rbxassetid://94320656351627'and plays[1].Pitch==1 and plays[1].Vol>0 and plays[1].Vol<=.5 and math.abs(plays[1].Pos.X-312)<.01 and math.abs(plays[1].Pos.Y-d.Top)<.01,#plays)
 local n1=#plays
 check('client: the mat squashes (one active) and has not left its rest pose by more than 0.2 studs',#api.Active==1)
 W.frames(6)
 local dy=api.Active[1] and(api.Active[1].MatCF.Position.Y-api.Active[1].Mat._props.CFrame.Position.Y)
 check('client: squashing: the mat and its badge are off their rest pose, within 0.2 studs ('..tostring(dy and string.format('%.3f',dy))..')',dy~=nil and math.abs(dy)>.001 and math.abs(dy)<=T.SquashDepth+1e-9,dy)
 W.frames(40)
 local s=api.Spots[1]
 check('client: after 0.7 s the mat and the badge are back exactly at rest and nothing is animating',#api.Active==0 and s.Mat._props.CFrame.Position.Y==s.MatCF.Position.Y and s.Badge._props.CFrame.Position.Y==s.BadgeCF.Position.Y)
 -- debounce: touching down again .2 s later does nothing; .5 s after the first bounce bounces again
 put(mine,312,d.Top+.05,-269,0,-40,0);W.frames(1)
 -- (that was ~.77 s after the first: it bounces; now a quick second contact)
 local after=mine.AssemblyLinearVelocity.Y
 check('client: the next landing (.7 s later) bounces again to the same speed',math.abs(after-up)<1e-6,after)
 check('client: ...with one more boing (once per bounce: '..#plays..' in all)',#plays==n1+1,#plays)
 put(mine,312,d.Top+.05,-269,0,-40,0);W.frames(12) -- .2 s
 check('client: a second contact within the cooldown (.2 s) is ignored: no stacking, no re-launch ('..string.format('%.1f',mine.AssemblyLinearVelocity.Y)..')',math.abs(mine.AssemblyLinearVelocity.Y+40)<1e-6,mine.AssemblyLinearVelocity.Y)
 check('client: ...and no boing for it (the debounced contact is silent)',#plays==n1+1,#plays)
 W.frames(20) -- .33 s more: .53 s since the bounce
 check('client: past the cooldown it bounces again',math.abs(mine.AssemblyLinearVelocity.Y-up)<1e-6,mine.AssemblyLinearVelocity.Y)
 check('client: ...with its own boing (the cooldown passed: '..#plays..' in all)',#plays==n1+2,#plays)
 -- stacking: a body that is going up a little (15 studs/s) on the mat gets exactly the launch speed
 W.frames(40)
 put(mine,312,d.Top,-269,0,15,0);W.frames(1)
 check('client: a launch is never added to the body\'s own speed (15 + v would be '..string.format('%.1f',15+up)..'): '..string.format('%.1f',mine.AssemblyLinearVelocity.Y),math.abs(mine.AssemblyLinearVelocity.Y-up)<1e-6,mine.AssemblyLinearVelocity.Y)
 W.frames(40)
 put(mine,312,d.Top+4,-269,0,-30,0);W.frames(1)
 check('client: feet 4 studs over the mat (flying over it) are left alone',mine.AssemblyLinearVelocity.Y==-30,mine.AssemblyLinearVelocity.Y)
 put(mine,312,d.Top+30,-269,0,60,0);W.frames(1)
 check('client: a body rising at 60 over the mat is left alone',mine.AssemblyLinearVelocity.Y==60,mine.AssemblyLinearVelocity.Y)
 put(mine,325,d.Top,-269,0,-10,0);W.frames(1)
 check('client: 13 studs from the centre (the nook\'s rim) is off the mat',mine.AssemblyLinearVelocity.Y==-10,mine.AssemblyLinearVelocity.Y)
 -- the Lava mat works too, at its own spot
 W.frames(40)
 local l=TRAMP.Lava
 put(mine,-312+3,l.Top+.1,-269-3,0,-30,0);W.frames(1)
 check('client: the Lava nook\'s trampoline bounces too ('..string.format('%.1f',mine.AssemblyLinearVelocity.Y)..')',math.abs(mine.AssemblyLinearVelocity.Y-up)<1e-6,mine.AssemblyLinearVelocity.Y)
 W.frames(40)
 -- somebody else lands: the squash and the boing happen on this screen, nothing is applied to them
 local pn=#plays;put(mine,-312+3,l.Top+.1,-269-3,0,-30,0);W.frames(1);W.frames(40)
 put(mine,-312+10,l.Top,-269,0,0,0)
 put(oroot,-312-2,l.Top+.1,-269+1,0,-30,0);W.frames(1)
 check('client: another player landing squashes the mat and boings on this screen but their speed is not touched by us ('..string.format('%.1f',oroot.AssemblyLinearVelocity.Y)..')',oroot.AssemblyLinearVelocity.Y==-30 and #plays==pn+2 and #api.Active>=1,#plays-pn)
 put(oroot,0,60,-100,0,0,0);W.frames(40)
 -- guards: ragdolled, sitting, anchored, dead: nothing
 put(mine,312,d.Top+.1,-269,0,-30,0);plr:SetAttribute('GuardianRagdollActive',true);W.frames(1)
 local rag=mine.AssemblyLinearVelocity.Y==-30;plr:SetAttribute('GuardianRagdollActive',nil)
 mineH.Sit=true;W.frames(1);local sit=mine.AssemblyLinearVelocity.Y==-30;mineH.Sit=false
 mine.Anchored=true;W.frames(1);local anch=mine.AssemblyLinearVelocity.Y==-30;mine.Anchored=false
 mineH.Health=0;W.frames(1);local dead=mine.AssemblyLinearVelocity.Y==-30;mineH.Health=100
 check('client: not while ragdolled / flung, seated, anchored (a lift, a teleport) or dead',rag and sit and anch and dead)
 -- Reduced Motion: still a bounce (it is gameplay), no squash
 W.frames(40);W.Gui.ReducedMotionEnabled=true
 put(mine,312,d.Top+.1,-269,0,-30,0);W.frames(1)
 check('client: with Reduced Motion the bounce stays but the mat does not squash',math.abs(mine.AssemblyLinearVelocity.Y-up)<1e-6 and #api.Active==0)
 W.Gui.ReducedMotionEnabled=false
 -- R153 client bug review, finding 3: the folder is read again while a mat is squashing (the other nook streams in or out, a mat arrives late, the server dresses the look). The dipped pose
 -- must not become the mat's rest (it used to: the mat stayed 0.1 - 0.2 studs low and every later squash dipped from there), and repeating it must not compound.
 W.frames(40)
 do
  local sp0=api.Spots[1];local mat0,badge0=sp0.Mat,sp0.Badge;local restY=mat0._props.CFrame.Position.Y;local badgeY=badge0._props.CFrame.Position.Y
  check('client (re-read mid-squash): the mat and its badge start at the rest the spot recorded',sp0.MatCF.Position.Y==restY and sp0.BadgeCF.Position.Y==badgeY,restY)
  local worst,dips,sameMat,restOk=0,0,true,true
  for round=1,3 do
   put(mine,312,d.Top+.1,-269,0,-30,0);W.frames(6)
   local dipped=restY-mat0._props.CFrame.Position.Y;if dipped>.001 then dips+=1 end
   local folder=map[T.FolderName];folder:SetAttribute('Looks',(folder:GetAttribute('Looks')or 0)+1);api.Coarse(1) -- (the client looks at the folder again, 6 frames into the squash)
   local sp=api.Spots[1];sameMat=sameMat and sp.Mat==mat0
   restOk=restOk and sp.MatCF.Position.Y==restY and sp.BadgeCF.Position.Y==badgeY
   W.frames(45)
   worst=math.max(worst,math.abs(mat0._props.CFrame.Position.Y-restY),math.abs(badge0._props.CFrame.Position.Y-badgeY))
  end
  check('client (re-read mid-squash): the mat was dipping each time ('..dips..' of 3) when the folder was read again',dips==3,dips)
  check('client (re-read mid-squash): the same mat is found again and its recorded rest is the real one, not the dipped height (3 rounds)',sameMat and restOk)
  check('client (re-read mid-squash): after each round the mat and its badge are back exactly at rest, nothing sunk or compounding (worst '..string.format('%.4f',worst)..' studs)',worst==0 and #api.Active==0,worst)
 end
 -- the server rebuilds the folder (HubDecor151.Apply again): the client finds the new mats
 W.frames(40)
 local oldMat=api.Spots[1].Mat
 server('HubDecor151').Apply(map)
 W.frames(40)
 check('client: when the server rebuilds the trampolines the client picks up the new mats',api.Spots[1].Mat~=oldMat and api.Spots[1].Mat:IsDescendantOf(W.workspace)and #api.Spots==2)
 check('client: the rebuilt folder is the same: 2 models, 84 parts',#map[T.FolderName]:GetChildren()==2 and map[T.FolderName]:GetAttribute('Parts')==84)
 -- R153 (owner: "2nd one will be trampoline bounce sound"): every boing of this whole test is the owner's file at pitch 1; the file is preloaded once
 local wrong=0;for _,p in ipairs(plays)do if p.Id~='rbxassetid://94320656351627'or p.Pitch~=1 then wrong+=1 end end
 check('client: every boing above is the owner\'s file at pitch 1 (never Bubble04, nothing pitched): '..#plays..' boings, '..wrong..' other',#plays>=6 and wrong==0,wrong)
 check('client: the owner\'s file is preloaded once, when a player first comes near a nook',#preloads==1 and #preloads[1]==1 and preloads[1][1]=='rbxassetid://94320656351627',#preloads)
 sc:Destroy()
 -- the same client on the REAL LocalSfx / SoundTiming / AudioMixer (no stub): what the player would actually hear
 W.stub('LocalSfx',nil)
 do
  local sounds={};local inew=R.Instance.new
  R.Instance.new=function(class,parent)
   local o=inew(class,parent)
   if class=='Sound'then
    o.Ended=R.signal();o.Loaded=R.signal();o.IsLoaded=true;o.IsPlaying=false;o.TimeLength=2;o.TimePosition=0;o.Plays=0
    o.Play=function(self)self.IsPlaying=true;self.Plays+=1 end;o.Stop=function(self)self.IsPlaying=false end
    sounds[#sounds+1]=o
   end
   return o
  end
  W.service('Debris').AddItem=function()end;W.service('ContentProvider').PreloadAsync=function()end
  local Mixer=W.module('AudioMixer')
  local sc2=R.new('LocalScript');sc2.Name='HubTrampoline153';sc2:SetAttribute('R153TestHook',true);sc2.Parent=pg
  local api2=W.load('HubTrampoline153Client',sc2)
  W.frames(40)
  local function boings()local list={};for _,x in ipairs(sounds)do if x.Name=='ChestChaseOneShot'then list[#list+1]=x end end;return list end
  put(mine,312,d.Top+.1,-269,0,-30,0);W.frames(1)
  local b=boings();local one=b[1]
  check('client (real LocalSfx): a bounce makes ONE sound: the owner\'s file, unpitched (PlaybackSpeed 1), at the client\'s volume ('..#b..')',#b==1 and one.SoundId=='rbxassetid://94320656351627'and one.PlaybackSpeed==1 and one.Volume==api2.Boing.Volume and api2.Boing.Volume>0 and api2.Boing.Volume<=.5 and api2.Boing.Pitch==1)
  check('client (real LocalSfx): it plays once, from SoundTiming\'s lead-in for it (unmeasured: 0; Start_94320656351627 tunes it), on the Effects group, 3D at the mat',
   one~=nil and one.IsPlaying and one.Plays==1 and one.TimePosition==W.module('SoundTiming').Offset(one) and one.SoundGroup==Mixer.Group('Effects')
   and one.Parent~=nil and one.Parent.Name=='ChestChaseSfx'and math.abs(one.Parent.Position.X-312)<.01 and math.abs(one.Parent.Position.Y-d.Top)<.01)
  put(mine,312,d.Top+.05,-269,0,-40,0);W.frames(12)
  check('client (real LocalSfx): a contact inside the cooldown makes no second sound ('..#boings()..')',#boings()==1)
  W.frames(20) -- (.53 s since the bounce: the body is still held on the mat)
  check('client (real LocalSfx): past the cooldown the next bounce makes exactly one more ('..#boings()..')',#boings()==2 and boings()[2].SoundId=='rbxassetid://94320656351627')
  sc2:Destroy();R.Instance.new=inew
 end
end

-- 5. the gardens ---------------------------------------------------------------------------------------------------------------------------------------
local Layout=server('GardenBaseLayout')
local ramps=map:FindFirstChild(Layout.RampFolder)
check('gardens: MapService.new builds ChestChaseMap.GardenBedRamps153 (GardenBaseLayout.Apply)',ramps~=nil and ramps:GetAttribute('Ramps')~=nil)
local rampParts={}
if ramps then for _,p in ipairs(ramps:GetChildren())do rampParts[#rampParts+1]=p end end
if MUT=='noramps'then for _,p in ipairs(rampParts)do p:Destroy()end;rampParts={} end
local bases={}
for _,b in ipairs(map.Bases:GetChildren())do if b:GetAttribute('BaseIndex')then bases[b:GetAttribute('BaseIndex')]=b end end
check('gardens: the owner\'s place has the six bases, each with a pad and ten plots',(function()local n=0;for i=1,6 do local b=bases[i];if b and b:FindFirstChild('Pad')and #b.GardenPlots:GetChildren()==10 then n+=1 end end;return n end)()==6)

-- measure: heights (tops of everything that collides near the beds), the climbs
local function surface(p,x,z)
 local c=p._props.CFrame;local s=p._props.Size;local r=c.R;local q=c.Position
 local dx,dz=x-q.X,z-q.Z
 local lx=dx*r[1][1]+dz*r[3][1];local lz=dx*r[1][3]+dz*r[3][3]
 if math.abs(lx)>s.X/2+1e-6 or math.abs(lz)>s.Z/2+1e-6 then return nil end
 if p._class=='WedgePart'then return q.Y-s.Y/2+s.Y*((lz+s.Z/2)/s.Z)end
 return q.Y+s.Y/2
end
local colliders={}
for _,p in ipairs(parts(map))do if solid(p)and(p._class=='Part'or p._class=='WedgePart'or p._class=='SpawnLocation')and p._props.Shape~=R.Enum.PartType.Ball and p._props.Shape~=R.Enum.PartType.Cylinder then colliders[#colliders+1]=p end end
local function heightAt(x,z,near)
 local h=-math.huge
 for _,p in ipairs(near)do local y=surface(p,x,z);if y and y>h then h=y end end
 return h
end
local function nearParts(lox,hix,loz,hiz)
 local out={}
 for _,p in ipairs(colliders)do local a,b=aabb(p);if a[1]<hix and b[1]>lox and a[3]<hiz and b[3]>loz then out[#out+1]=p end end
 return out
end
-- THE WALK. A body walks the ground, so what counts is the ground's height under its feet along the way, not the runner sweep's 1.1-stud clearance (R153 first
-- version: that limit let the 0.8-stud step from a 1.0-stud apron onto the soil, exactly where the fence stands, through the test and stopped the owner there).
-- A way is walkable if the ground never jumps up more than CLIFF in one .05-stud step and never climbs more than SLOPE per stud over half a stud (the ramps are 0.4
-- per stud = 22 degrees; the Humanoid climbs far steeper). Every exposed side of every one of the 60 plots, every convex corner (diagonally), the pad's rim on its
-- four sides, and every fence post (a straight line through the post from the lawn) is walked from 6 studs out; then a flood fill over a .25-stud grid of the real
-- ground (everything that collides near the base, taller things = walls) from the lawn, one cell step up at most STEPCELL, must reach every cell of every soil bed
-- and every cell of the pad within 3 studs of one (the aprons, the aisles, the ends, the corners).
local DEPTH,STEP=6,.05
local CLIFF,SLOPE,STEPCELL,CELL=.2,.85,.3,.25
local function boxes(list)
 local out={};for _,p in ipairs(list)do local a,b=aabb(p);out[#out+1]={P=p,A=a,B=b}end;return out
end
local function walkMetrics(entries,qx,qz,nx,nz,d0,d1)
 -- the line q + n*d from d0 down to d1; the parts that can matter are the ones whose box meets the line's
 local ex,ez=qx+nx*d0,qz+nz*d0;local fx,fz=qx+nx*d1,qz+nz*d1
 local lox,hix,loz,hiz=math.min(ex,fx)-.5,math.max(ex,fx)+.5,math.min(ez,fz)-.5,math.max(ez,fz)+.5
 local near={};for _,e in ipairs(entries)do if e.A[1]<hix and e.B[1]>lox and e.A[3]<hiz and e.B[3]>loz then near[#near+1]=e.P end end
 local hs={};local d=d0
 while d>=d1-1e-9 do hs[#hs+1]=heightAt(qx+nx*d,qz+nz*d,near);d-=STEP end
 local cliff,slope=0,0
 for i=2,#hs do local r=hs[i]-hs[i-1];if r>cliff then cliff=r end;if i>10 then local s=(hs[i]-hs[i-10])/(STEP*10);if s>slope then slope=s end end end
 return cliff,slope,hs
end
local function newReport()return{Walks=0,Corners=0,Posts=0,Rim=0,Flush=0,Apron=0,Cliff=0,Slope=0,Fail={},Faces={}}end
local function record(rep,i,label,x,z,cliff,slope)
 rep.Walks+=1;if cliff>rep.Cliff then rep.Cliff=cliff end;if slope>rep.Slope then rep.Slope=slope end
 if cliff>CLIFF+1e-6 or slope>SLOPE+1e-6 then rep.Fail[#rep.Fail+1]={Base=i,Label=label,X=x,Z=z,Cliff=cliff,Slope=slope};rep.Faces[i..' '..label]=(rep.Faces[i..' '..label]or 0)+1 end
end
local function raster(entries,x0,z0,nx,nz)
 local H=table.create(nx*nz,K.Floor)
 for _,e in ipairs(entries)do
  local p=e.P;local ix0,ix1=math.max(1,math.floor((e.A[1]-x0)/CELL)+1),math.min(nx,math.ceil((e.B[1]-x0)/CELL))
  local iz0,iz1=math.max(1,math.floor((e.A[3]-z0)/CELL)+1),math.min(nz,math.ceil((e.B[3]-z0)/CELL))
  for iz=iz0,iz1 do for ix=ix0,ix1 do
   local y=surface(p,x0+(ix-.5)*CELL,z0+(iz-.5)*CELL);local k=(iz-1)*nx+ix;if y and y>H[k]then H[k]=y end
  end end
 end
 return H
end
local function flood(H,nx,nz)
 local seen=table.create(nx*nz,false);local queue,head={},1
 local function push(k)if not seen[k]and H[k]<12 then seen[k]=true;queue[#queue+1]=k end end
 for ix=1,nx do push(ix);push((nz-1)*nx+ix)end;for iz=1,nz do push((iz-1)*nx+1);push((iz-1)*nx+nx)end
 while head<=#queue do
  local k=queue[head];head+=1
  local ix=(k-1)%nx+1;local iz=(k-1)//nx+1;local h=H[k]
  for dz=-1,1 do for dx=-1,1 do if dx~=0 or dz~=0 then
   local jx,jz=ix+dx,iz+dz
   if jx>=1 and jx<=nx and jz>=1 and jz<=nz then local j=(jz-1)*nx+jx;if not seen[j]and H[j]<12 and H[j]-h<=STEPCELL+1e-9 then seen[j]=true;queue[#queue+1]=j end end
  end end end
 end
 return seen
end
local function measure(includeRamps)
 local rep=newReport();rep.Cells=0;rep.Missed=0;rep.MissedList={};rep.Soil=0
 for i=1,6 do
  local base=bases[i];local plots={};local lox,hix,loz,hiz=math.huge,-math.huge,math.huge,-math.huge
  for _,p in ipairs(base.GardenPlots:GetChildren())do
   local a,b=aabb(p);plots[#plots+1]={P=p,X0=a[1],X1=b[1],Z0=a[3],Z1=b[3],Top=b[2]}
  end
  local pa,pb=aabb(base.Pad);lox,hix,loz,hiz=pa[1],pb[1],pa[3],pb[3]
  local near=nearParts(lox-DEPTH-9,hix+DEPTH+9,loz-DEPTH-9,hiz+DEPTH+9)
  if not includeRamps then local keep={};for _,p in ipairs(near)do if p._class~='WedgePart'then keep[#keep+1]=p end end;near=keep end
  local entries=boxes(near)
  local function inPlot(x,z)for _,q in ipairs(plots)do if x>q.X0+1e-6 and x<q.X1-1e-6 and z>q.Z0+1e-6 and z<q.Z1-1e-6 then return true end end;return false end
  -- every side of every plot, every .5 stud, walked in from 6 studs out to 1 stud into the soil
  for _,q in ipairs(plots)do
   for _,side in ipairs({{-1,0,q.X0,'X0'},{1,0,q.X1,'X1'},{0,-1,q.Z0,'Z0'},{0,1,q.Z1,'Z1'}})do
    local nx,nz=side[1],side[2];local a,b=q.Z0,q.Z1;if nx==0 then a,b=q.X0,q.X1 end
    local t=a+.25
    while t<b do
     local px,pz=side[3],t;if nx==0 then px,pz=t,side[3]end
     if not inPlot(px+nx*.05,pz+nz*.05)then
      local c,s=walkMetrics(entries,px,pz,nx,nz,DEPTH,-1);record(rep,i,side[4]..' '..q.P.Name,px,pz,c,s)
      -- a side within 1.5 studs of the pad's rim: flush with it (the rear bed) or an apron (the 1.0 strip beside the fence, between the soil and the rim)
      local rimAt=nx~=0 and math.min(math.abs(px-lox),math.abs(hix-px))or math.min(math.abs(pz-loz),math.abs(hiz-pz))
      if rimAt<.1 then rep.Flush+=1 elseif rimAt<1.5 then rep.Apron+=1 end
     end
     t+=.5
    end
   end
   for _,cx in ipairs({{q.X0,-1},{q.X1,1}})do for _,cz in ipairs({{q.Z0,-1},{q.Z1,1}})do
    local x,z,sx,sz=cx[1],cz[1],cx[2],cz[2]
    if not inPlot(x+sx*.05,z)and not inPlot(x,z+sz*.05)and not inPlot(x+sx*.05,z+sz*.05)then
     local k=math.sqrt(.5);local c,s=walkMetrics(entries,x,z,sx*k,sz*k,DEPTH,-1);record(rep,i,'corner '..q.P.Name,x,z,c,s);rep.Corners+=1
    end
   end end
  end
  -- the pad's rim on its four sides, every 1 stud, from 6 studs out to 6 studs in; and its four corners diagonally
  for _,side in ipairs({{-1,0,lox,loz,hiz},{1,0,hix,loz,hiz},{0,-1,loz,lox,hix},{0,1,hiz,lox,hix}})do
   local nx,nz=side[1],side[2];local t=side[4]+.5
   while t<side[5]do
    local px,pz=side[3],t;if nx==0 then px,pz=t,side[3]end
    local c,s=walkMetrics(entries,px,pz,nx,nz,DEPTH,-6);record(rep,i,'rim',px,pz,c,s);rep.Rim+=1;t+=1
   end
  end
  for _,cx in ipairs({{lox,-1},{hix,1}})do for _,cz in ipairs({{loz,-1},{hiz,1}})do
   local k=math.sqrt(.5);local c,s=walkMetrics(entries,cx[1],cz[1],cx[2]*k,cz[2]*k,DEPTH,-4);record(rep,i,'rim corner',cx[1],cz[1],c,s);rep.Rim+=1
  end end
  -- the fence posts (walk-through, but they are where a player's path would cross the fence): the line through each from the lawn, 6 studs out of the rim to 8 in
  for _,p in ipairs(parts(base))do if p.Name=='Fence pillar'or p.Name=='Entrance pillar'then
   local q=p._props.CFrame.Position;local dd={q.X-lox,hix-q.X,q.Z-loz,hiz-q.Z};local k,m=1,dd[1];for j=2,4 do if dd[j]<m then k,m=j,dd[j]end end
   local nx,nz=0,0;if k==1 then nx=1 elseif k==2 then nx=-1 elseif k==3 then nz=1 else nz=-1 end -- (inward)
   local c,s=walkMetrics(entries,q.X,q.Z,-nx,-nz,m+8,-3);record(rep,i,'post',q.X,q.Z,c,s);rep.Posts+=1
  end end
  -- the flood fill
  local x0,z0=lox-8,loz-8;local gx,gz=math.ceil((hix-lox+16)/CELL),math.ceil((hiz-loz+16)/CELL)
  local H=raster(entries,x0,z0,gx,gz);local seen=flood(H,gx,gz)
  local crowd={}
  for _,n in ipairs({'Spawn','Treadmill'})do local p=base:FindFirstChild(n,true);if p then local a,c=aabb(p);crowd[#crowd+1]={a[1]-1,a[3]-1,c[1]+1,c[3]+1}end end
  for iz=1,gz do for ix=1,gx do
   local x,z=x0+(ix-.5)*CELL,z0+(iz-.5)*CELL
   local need=false;local soil=false
   for _,q in ipairs(plots)do
    if x>q.X0+.3 and x<q.X1-.3 and z>q.Z0+.3 and z<q.Z1-.3 then need=true;soil=true;break end
    if x>q.X0-3 and x<q.X1+3 and z>q.Z0-3 and z<q.Z1+3 and x>lox+.3 and x<hix-.3 and z>loz+.3 and z<hiz-.3 then need=true end
   end
   if need then for _,o in ipairs(crowd)do if x>o[1]and x<o[3]and z>o[2]and z<o[4]then need=false;break end end end
   if need then
    rep.Cells+=1;if soil then rep.Soil+=1 end
    if not seen[(iz-1)*gx+ix]then rep.Missed+=1;if #rep.MissedList<6 then rep.MissedList[#rep.MissedList+1]=string.format('base %d (%.1f,%.1f) h %.2f',i,x,z,H[(iz-1)*gx+ix])end end
   end
  end end
 end
 return rep
end
local after=measure(true)
info(string.format('gardens: %d walks from 6 studs out (every side of 60 plots every .5 stud, %d convex corners diagonally, %d pad-rim walks, %d fence posts; %d of the side walks end at the rear bed\'s flush edges, %d at the 1.0 aprons beside the fence): worst cliff %.2f, worst slope %.2f per stud (limits %.2f / %.2f)',after.Walks,after.Corners,after.Rim,after.Posts,after.Flush,after.Apron,after.Cliff,after.Slope,CLIFF,SLOPE))
info(string.format('gardens: flood fill from the lawn over the real ground (.25 grid, one cell up at most %.2f): %d of %d cells that matter reached (%d of them soil)%s',STEPCELL,after.Cells-after.Missed,after.Cells,after.Soil,after.Missed>0 and(' missed '..table.concat(after.MissedList,'; '))or''))
check('gardens: EVERY way onto a bed on all 6 bases (every side of all 60 plots every .5 stud, every convex corner diagonally, the pad rim on its four sides, a line through every fence post) is walkable: no ledge over '..CLIFF..', no slope over '..SLOPE..' per stud ('..string.format('worst %.2f / %.2f',after.Cliff,after.Slope)..')',
 #after.Fail==0 and after.Walks>2500 and after.Corners>=100 and after.Posts>=100 and after.Flush>=300 and after.Apron>=500,#after.Fail..' failing of '..after.Walks..' e.g. '..tostring(after.Fail[1]and(after.Fail[1].Base..' '..after.Fail[1].Label..string.format(' at %.1f,%.1f cliff %.2f slope %.2f',after.Fail[1].X,after.Fail[1].Z,after.Fail[1].Cliff,after.Fail[1].Slope))))
if #after.Fail>0 then
 local by={};for _,f in ipairs(after.Fail)do local k=f.Base..' '..f.Label:gsub(' DirtPlot_%d+','');local e=by[k]or{N=0,C=0,S=0};e.N+=1;if f.Cliff>e.C then e.C=f.Cliff;e.X=f.X;e.Z=f.Z end;if f.Slope>e.S then e.S=f.Slope end;by[k]=e end
 local keys={};for k in pairs(by)do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys)do local e=by[k];info(string.format('  fail %s: %d walks, worst cliff %.2f slope %.2f at %.1f,%.1f',k,e.N,e.C,e.S,e.X,e.Z))end
end
check('gardens: a flood fill from the lawn (one .25-stud cell step up at most '..STEPCELL..') reaches EVERY cell of every bed and every cell of the pad within 3 studs of a bed (aprons, aisles, ends, corners; all 6 bases): no pocket, no trap',after.Missed==0 and after.Cells>50000 and after.Soil>40000,after.Missed..' missed of '..after.Cells..' '..tostring(after.MissedList[1]))
if not MUT then
 local before=measure(false)
 local faces=0;for _ in pairs(before.Faces)do faces+=1 end
 info(string.format('gardens: WITHOUT the ramps %d of %d walks fail (worst cliff %.2f) and the flood fill misses %d of %d cells (%d plot sides / corners / the rim)',#before.Fail,before.Walks,before.Cliff,before.Missed,before.Cells,faces))
 check('gardens: the measurement has teeth: without the ramps the beds\' 0.8 and 1.8 sides and the 1.0 rim fail the walk, and the flood fill from the lawn reaches nothing on the pad',#before.Fail>before.Walks*.4 and before.Cliff>1.7 and before.Missed==before.Cells)
 local lows={};for _,f in ipairs(before.Fail)do if f.Cliff>.7 and f.Cliff<.9 then lows[f.Label:match('^%a+')]=true end end
 check('gardens: and the 0.8-stud step from the pad onto the soil (the apron beside the fence) fails it too: that is the step the first R153 ramps left',next(lows)~=nil)
end
-- the ramps are queryable floors, so check what a ray sees: planting's server check ("KEEP A CLEAR VIEW OF THE SOIL") casts from the player's head to the soil point
-- and must hit the plot; digging and plant inspection cast from the camera. From heads 4.5 studs over the ground (pad, floor or ramp), 1.5 / 4 / 9 studs out from every
-- bed edge (sampled every 2 studs), to soil points half a stud in: no point of any ray lies inside a ramp.
do
 local rays,hits=0,{}
 local function insideRamp(p,x,y,z)
  local c=p._props.CFrame;local s=p._props.Size;local r=c.R;local q=c.Position
  local dx,dy,dz=x-q.X,y-q.Y,z-q.Z
  local lx=dx*r[1][1]+dz*r[3][1];local lz=dx*r[1][3]+dz*r[3][3]
  if math.abs(lx)>=s.X/2 or math.abs(lz)>=s.Z/2 then return false end
  return dy>-s.Y/2 and dy<-s.Y/2+s.Y*((lz+s.Z/2)/s.Z)-1e-6
 end
 for i=1,6 do
  local base=bases[i];local plots={};local lox,hix,loz,hiz=math.huge,-math.huge,math.huge,-math.huge
  for _,p in ipairs(base.GardenPlots:GetChildren())do
   local a,b=aabb(p);plots[#plots+1]={X0=a[1],X1=b[1],Z0=a[3],Z1=b[3],Top=b[2]}
   lox=math.min(lox,a[1]);hix=math.max(hix,b[1]);loz=math.min(loz,a[3]);hiz=math.max(hiz,b[3])
  end
  local near=nearParts(lox-16,hix+16,loz-16,hiz+16)
  local mine={};for _,p in ipairs(rampParts)do if p:GetAttribute('BaseIndex')==i then mine[#mine+1]=p end end
  local function inPlot(x,z)for _,q in ipairs(plots)do if x>q.X0+1e-6 and x<q.X1-1e-6 and z>q.Z0+1e-6 and z<q.Z1-1e-6 then return true end end;return false end
  for _,q in ipairs(plots)do
   for _,side in ipairs({{-1,0,q.X0},{1,0,q.X1},{0,-1,q.Z0},{0,1,q.Z1}})do
    local nx,nz=side[1],side[2];local a,b=q.Z0,q.Z1;if nx==0 then a,b=q.X0,q.X1 end
    local t=a+1
    while t<b do
     local px,pz=side[3],t;if nx==0 then px,pz=t,side[3]end
     if not inPlot(px+nx*.05,pz+nz*.05)then
      local tx,tz=px-nx*.5,pz-nz*.5
      for _,d in ipairs({1.5,4,9})do
       local hx,hz=px+nx*d,pz+nz*d;local hy=heightAt(hx,hz,near)+4.5
       rays+=1
       local len=math.sqrt((hx-tx)^2+(hy-q.Top)^2+(hz-tz)^2);local n=math.floor(len/.1)
       for k=0,n-3 do -- (the last .3 studs are the soil itself)
        local f=k/n;local x,y,z=hx+(tx-hx)*f,hy+(q.Top-hy)*f,hz+(tz-hz)*f
        for _,r in ipairs(mine)do if insideRamp(r,x,y,z)then hits[#hits+1]=i..' '..r.Name..string.format(' at %.1f,%.1f,%.1f',x,y,z);break end end
       end
      end
     end
     t+=2
    end
   end
  end
 end
 info('gardens: '..rays..' rays from a head to a soil point at a bed edge checked against the ramps')
 check('gardens: no ray from a player\'s head (4.5 studs up, 1.5 - 9 studs out) to a soil point at any bed edge crosses a ramp: planting\'s clear-view check, digging and inspection stay as they were',#hits==0 and rays>1500,#hits..' hits of '..rays..' '..tostring(hits[1]))
end
-- the step table the owner asked for
do
 local pad=bases[1].Pad;local plot=bases[1].GardenPlots.DirtPlot_5;local border
 for _,p in ipairs(bases[1].GardenBedBorders:GetChildren())do border=p;break end
 local floorTop=K.Floor;local padTop=aabb(pad)[2]and select(2,aabb(pad))[2];local soilTop=select(2,aabb(plot))[2];local bTop=select(2,aabb(border))[2]
 info(string.format('gardens: heights: hub floor %.2f, pad top %.2f (rim %.2f over the floor), soil top %.2f (%.2f over the pad, %.2f over the floor), border top %.2f (%.2f over the soil; CanCollide %s)',
  floorTop,padTop,padTop-floorTop,soilTop,soilTop-padTop,soilTop-floorTop,bTop,bTop-soilTop,tostring(border._props.CanCollide)))
 check('gardens: measured: pad rim 1.0, pad to soil 0.8, soil over the hub floor 1.8: the ramps\' height is the soil\'s (2.5 studs of run per stud of rise), and every one of the three steps is far over what a body walks up ('..CLIFF..')',math.abs(padTop-floorTop-1)<.001 and math.abs(soilTop-padTop-.8)<.001 and math.abs(soilTop-floorTop-1.8)<.001 and padTop-floorTop>CLIFF and soilTop-padTop>CLIFF)
 local solidBorders={};for _,b in pairs(bases)do for _,p in ipairs(b.GardenBedBorders:GetChildren())do if solid(p)then solidBorders[#solidBorders+1]=path(p)end end end
 check('gardens: the wooden bed borders (6 x 17 pieces, just over the soil) do not collide at all: walk-through (WalkthroughProps90), not the obstacle',#solidBorders==0,first(solidBorders))
 local fenceParts,fenceSolid=0,{}
 for _,b in pairs(bases)do local f=b:FindFirstChild('GardenFence34');if f then for _,p in ipairs(parts(f))do fenceParts+=1;if solid(p)or p._props.CanQuery~=false then fenceSolid[#fenceSolid+1]=path(p)end end end;if b:FindFirstChild('PerimeterFence')then fenceSolid[#fenceSolid+1]='old PerimeterFence on '..b.Name end end
 check('gardens: the fence (GardenFence34: pillars, rails, footings, sills, '..fenceParts..' parts on 6 bases) is what GardenFenceArt builds and none of it collides or answers a query: it is only dressing, the ramps are the only thing this fix adds (nothing of the fence was moved or made solid)',fenceParts>600 and #fenceSolid==0,first(fenceSolid)or fenceParts)
end
-- planting, harvesting, plant inspection and digging: the soil and everything planted on it are untouched; the ramps cannot be queried or touched
do
 local moved,notSolid={},{}
 for p,s in pairs(saved)do
  local c=p._props.CFrame
  if(c.Position-s.Pos).Magnitude>1e-6 or p._props.Size~=s.Size or p._props.CanCollide~=s.Collide then moved[#moved+1]=path(p)end
  if p.Name:match('^DirtPlot_%d')and not solid(p)then notSolid[#notSolid+1]=path(p)end
 end
 check('gardens: the 60 plots and 6 pads keep their saved position, size and collision (the soil surface plants stand on does not move)',#moved==0,first(moved))
 check('gardens: every plot still collides (the soil keeps its walkable height)',#notSolid==0)
 local bad={}
 for _,p in ipairs(rampParts)do
  if p._props.CanQuery~=true or p._props.CanTouch~=false or p._props.CanCollide~=true or p._props.Anchored~=true or p._props.Transparency~=1 or p._class~='WedgePart'then bad[#bad+1]=p.Name end
 end
 check('gardens: every ramp is an anchored, invisible, solid wedge that is queryable (a floor to the Humanoid and the runner sweep, like the pad and the soil) and untouchable',#bad==0 and #rampParts>0,first(bad)or#rampParts)
 -- never above the soil, never over a plot (but .03 into its face), never off the hub floor
 local over,inside,outside={},{},{}
 for _,p in ipairs(rampParts)do
  local a,b=aabb(p);local top=b[2]
  if top>5.8+1e-6 then over[#over+1]=p.Name end
  local cx,cz=(a[1]+b[1])/2,(a[3]+b[3])/2
  for _,plot in ipairs(saved and parts(map.Bases)or{})do
   if plot.Name:match('^DirtPlot_%d')then
    local pa,pb=aabb(plot)
    -- the horizontal overlap of the ramp's box and the plot's, in studs: only the .02 under the soil's face is allowed
    local ox=math.min(b[1],pb[1])-math.max(a[1],pa[1]);local oz=math.min(b[3],pb[3])-math.max(a[3],pa[3])
    if ox>.03 and oz>.03 and b[2]>pb[2]+1e-6 then inside[#inside+1]=p.Name end
   end
  end
  if b[1]>336 or a[1]<-336 or a[3]<-617 or b[3]>-104.5 then outside[#outside+1]=p.Name end
 end
 check('gardens: no ramp rises above the soil top (5.8) or stands above a plot: a ray that ends on the soil or a plant (planting\'s clear-view check, digging, inspection) comes from above that plane and crosses no ramp; nothing is under a plant',#over==0 and #inside==0,first(over)or first(inside))
 check('gardens: every ramp is inside the hub (x within the walls, z between the front wall and the back wall): the keepers\' track (z > -104) and the biomes are not touched',#outside==0,first(outside))
 -- clear of the things that stand on a pad: the spawn, the treadmill's collider, the mystery pedestal's spot (MysteryPackRules.Offset 34, 75 on the pad), 2 studs of room
 local MPR=W.module('MysteryPackRules');local crowd={}
 for i,b in pairs(bases)do
  for _,n in ipairs({'Spawn','Treadmill'})do local p=b:FindFirstChild(n,true);if p then local a,c=aabb(p);crowd[#crowd+1]={Name='Base'..i..' '..n,Lo={a[1]-2,a[3]-2},Hi={c[1]+2,c[3]+2}}end end
  local at=b.Pad._props.CFrame*V3(MPR.Offset.X,0,MPR.Offset.Z);crowd[#crowd+1]={Name='Base'..i..' pedestal',Lo={at.X-6.5,at.Z-6.5},Hi={at.X+6.5,at.Z+6.5}}
 end
 -- (a ramp's lower part lies inside the pad slab; what matters is where a ramp stands ABOVE the pad: sampled every .5 stud over each box)
 local crowded={}
 for _,o in ipairs(crowd)do
  local bx={};for _,p in ipairs(rampParts)do local a,c=aabb(p);if a[1]<o.Hi[1]and c[1]>o.Lo[1]and a[3]<o.Hi[2]and c[3]>o.Lo[2]then bx[#bx+1]=p end end
  local x=o.Lo[1]
  while x<=o.Hi[1]do local z=o.Lo[2]
   while z<=o.Hi[2]do for _,p in ipairs(bx)do local y=surface(p,x,z);if y and y>5.01 then crowded[#crowded+1]=p.Name..' / '..o.Name;break end end;z+=.5 end
   x+=.5
  end
 end
check('gardens: no ramp stands above the pad within 2 studs of a spawn or a treadmill, or within 6.5 studs of the mystery pedestal\'s spot',#crowded==0 and #crowd==18,first(crowded)or#crowd)
 local counts={};for _,p in ipairs(rampParts)do local i=p:GetAttribute('BaseIndex');counts[i]=(counts[i]or 0)+1 end
 local line={};for i=1,6 do line[#line+1]=i..':'..tostring(counts[i])end
 info('gardens: '..#rampParts..' ramps ('..table.concat(line,' ')..')')
 if not MUT then
  local even=true;for i=1,6 do if counts[i]~=counts[1]then even=false end end
  check('gardens: every base gets the same ramps (6 identical layouts)',even and counts[1]~=nil and counts[1]>=8,counts[1])
 end
 -- re-Apply is idempotent: one folder, the same ramps
 if not MUT then
  Layout.Apply(map)
  local again=map:FindFirstChild(Layout.RampFolder)
  local n=0;for _,c in ipairs(map:GetChildren())do if c.Name==Layout.RampFolder then n+=1 end end
  check('gardens: running GardenBaseLayout.Apply again replaces the folder (one folder, the same ramp count)',n==1 and again~=nil and #again:GetChildren()==#rampParts)
 end
end

-- 6. the look from the owner's asset 12088629887 (HubTrampoline153: template -> InsertService -> built) ---------------------------------------------------------
do
 local IS,AS=W.service('InsertService'),W.service('AssetService')
 local HT=server('HubTrampoline153')
 if MUT=='nostrip'then W.module('HubStudTrees151').Sanitize=function()return 0,0 end end -- (a loader that strips nothing: the look test must fail)
 local calls={IS=0,AS=0}
 local function routes(isFn,asFn)
  IS.LoadAsset=function(_,id)calls.IS+=1;return isFn(id)end;AS.LoadAssetAsync=function(_,id)calls.AS+=1;return asFn(id)end
 end
 local DENIED=function()error('User is not authorized to access Asset.')end
 local function part(parent,name,size,pos,tr)
  local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=CF(pos[1],pos[2],pos[3]);p.Anchored=false;p.CanCollide=true;p.CanTouch=true;p.CanQuery=true;p.Transparency=tr or 0;p.Parent=parent;return p
 end
 -- a store trampoline in its own units (20 wide): a frame, 4 legs, 8 springs, a mat, and everything a store model may carry
 local function asset(o)
  o=o or{}
  local m=R.new('Model');m.Name=o.Name or'Trampoline Pro'
  if o.Generic then -- two like flat discs, no names to tell them by
   part(m,'Part',V3(20,.4,20),{0,3.2,0});part(m,'Part',V3(20,.4,20),{0,3.25,0});part(m,'Part',V3(1,3,1),{9,1.5,9})
  else
   part(m,'Frame',V3(20,.6,20),{0,3.3,0})
   for _,c in ipairs({{9,1.5,9},{-9,1.5,9},{9,1.5,-9},{-9,1.5,-9}})do part(m,'Leg',V3(1,3,1),c)end
   for k=1,8 do part(m,'Spring',V3(.5,.8,.5),{math.cos(k)*8,3.2,math.sin(k)*8})end
   part(m,'Mat',V3(17,.4,17),{0,3.2,0})
  end
  if o.Junk~=false then
   local g=part(m,'Giant',V3(5000,1,5000),{0,0,0});part(m,'Hull',V3(60,5,60),{0,2,0},1)
   local s=R.new('Script');s.Name='Evil';s.Parent=m
   local l=R.new('LocalScript');l.Name='Spy';l.Parent=m:FindFirstChild('Frame')or g
   local sub=R.new('Model');sub.Name='Inner';sub.Parent=m;local ms=R.new('ModuleScript');ms.Name='Req';ms.Parent=sub
   for _,c in ipairs({'Sound','ClickDetector','ProximityPrompt','Humanoid','WeldConstraint','Attachment','ParticleEmitter','SurfaceGui','RemoteEvent'})do local x=R.new(c);x.Name='Junk'..c;x.Parent=m end
  end
  for _=1,(o.Extra or 0)do part(m,'Bolt',V3(.3,.3,.3),{0,1,0})end
  return m
 end
 local function container(m)local c=R.new('Model');c.Name='Model';m.Parent=c;return c end
 local CODE={'Script','LocalScript','ModuleScript'};local ALIEN={'Sound','ClickDetector','ProximityPrompt','Humanoid','WeldConstraint','Attachment','ParticleEmitter','SurfaceGui','RemoteEvent'}
 local function leftovers(root)
  local out={};for _,d in ipairs(root:GetDescendants())do for _,c in ipairs(CODE)do if d._class==c then out[#out+1]=c end end;for _,c in ipairs(ALIEN)do if d._class==c then out[#out+1]=c end end end;return out
 end
 local function fold()return map:FindFirstChild(T.FolderName)end
 local function lookOf(spot)local m=fold():FindFirstChild('Trampoline '..spot.Name);return m,m and m:FindFirstChild('Trampoline look')end
 local function solids()local n=0;for _,p in ipairs(parts(fold()))do if solid(p)then n+=1 end end;return n end
 local function names(m)local out={};for _,c in ipairs(m:GetChildren())do out[c.Name]=(out[c.Name]or 0)+1 end;return out end
 local function flat(look)local bad={};for _,p in ipairs(parts(look))do local a,b=aabb(p);if b[2]-a[2]<=.5 then for _,y in ipairs({4.14,4.2,4.26,4.32})do if math.abs(b[2]-y)<.04 then bad[#bad+1]=p.Name end end end end;return bad end
 local function box(look)local lo,hi;for _,p in ipairs(parts(look))do local a,b=aabb(p);lo=lo and{math.min(lo[1],a[1]),math.min(lo[2],a[2]),math.min(lo[3],a[3])}or a;hi=hi and{math.max(hi[1],b[1]),math.max(hi[2],b[2]),math.max(hi[3],b[3])}or b end;return lo,hi end
 local function reload(isFn,asFn)calls.IS,calls.AS=0,0;routes(isFn,asFn);HT.Reset();HT.Build(map);return HT.Status end

 -- A. the asset loads (a model with scripts and junk inside, as a store model may come)
 local st=reload(function()return container(asset())end,DENIED)
 check('look: a successful InsertService:LoadAsset(12088629887) dresses both trampolines (asset, one call, AssetService not asked)',HT.Look=='asset'and st.Route=='InsertService:LoadAsset'and calls.IS==1 and calls.AS==0 and T.AssetId==12088629887 and fold():GetAttribute('Look')=='asset',tostring(HT.Look)..' '..tostring(st.Route))
 check('look: the 3 scripts (Script, LocalScript, ModuleScript) are counted and gone, and so is everything else that is not geometry (9 kinds: sounds, click detectors, prompts, welds, humanoids, attachments, particles, guis, remotes)',st.Scripts==3 and st.Other>=9 and #leftovers(fold())==0,'scripts '..tostring(st.Scripts)..' other '..tostring(st.Other)..' left '..#leftovers(fold()))
 check('look: the absurd (5000 studs) and the invisible (hull) parts are dropped; 14 parts stay per trampoline (frame, 4 legs, 8 springs, mat)',st.Dropped==2 and st.Parts==14,tostring(st.Dropped)..' '..tostring(st.Parts))
 local worstScale,placed,flatBad,lockBad,gone,matOk,oneLook=true,true,{},{},true,true,true
 for _,spot in ipairs(T.Spots)do
  local m,look=lookOf(spot)
  if not look then oneLook=false else
   local lo,hi=box(look);local foot=math.max(hi[1]-lo[1],hi[3]-lo[3])
   if math.abs(foot-T.Dims.Radius*2)>.01 then worstScale=false end
   if math.abs((lo[1]+hi[1])/2-spot.X)>.01 or math.abs((lo[3]+hi[3])/2-spot.Z)>.01 then placed=false end
   local mat=look:FindFirstChild('Trampoline mat',true)
   local mh=mat and select(2,aabb(mat))
   if not mat or math.abs(mh[2]-T.Top())>.001 or math.abs(mat._props.Size.X-17*(T.Dims.Radius*2/20))>.01 then matOk=false end
   for _,p in ipairs(parts(look))do if p._props.Anchored~=true or p._props.CanCollide~=false or p._props.CanTouch~=false or p._props.CanQuery~=false then lockBad[#lockBad+1]=p.Name end end
   for _,n in ipairs(flat(look))do flatBad[#flatBad+1]=n end
   local nm=names(m);for _,b in ipairs({'Trampoline foot','Trampoline frame','Trampoline spring','Trampoline gap','Trampoline badge','Trampoline mat'})do if nm[b]then gone=false end end
   if nm['Trampoline collider']~=1 or nm['Trampoline look']~=1 or #m:GetChildren()~=2 then oneLook=false end
  end
 end
 check('look: scaled so the footprint is the collider\'s 12.1 studs (20 x 0.605) and centred on each nook (312 / -269 and -312 / -269)',worstScale and placed)
 check('look: the mat (the largest flat top part, named Mat) is renamed "Trampoline mat", 10.3 studs, with its top exactly at the collider\'s walking top (4.9): the feet land where they look',matOk)
 check('look: every look part anchored, CanCollide / CanTouch / CanQuery off',#lockBad==0 and #parts(fold())==2*(1+14),first(lockBad)or#parts(fold()))
 check('look: the built feet, frame, springs, gap, mat and badge are gone: one look, the collider and the look model only',gone and oneLook)
 local c1=lookOf(T.Spots[1]):FindFirstChild('Trampoline collider');local _,ch=aabb(c1)
 check('look: ONE collider per trampoline (2 solid parts in the whole folder), still 0.9 over the floor and 6.05 round',solids()==2 and math.abs(ch[2]-T.Top())<.001 and math.abs(c1._props.Size.Y/2-6.05)<.01)
 check('look: no flat top of the look lies on a plane of the paving (4.14 / 4.20 / 4.26 / 4.32)',#flatBad==0,first(flatBad))
 local ok,text=HT.Command(nil,nil,{})
 check('command: /test trampoline says THE ASSET 12088629887, how it loaded, the parts and the squash mat',ok and text:find('THE ASSET 12088629887',1,true)~=nil and text:find('InsertService:LoadAsset',1,true)~=nil and text:find('14 parts',1,true)~=nil and text:find('"Mat"',1,true)~=nil and text:find('one invisible collider',1,true)~=nil,text)
 info('look: a store look with 14 parts per trampoline here; the cap is '..T.AssetMaxParts..' per trampoline (a bigger one is refused and the built trampoline stays)')
 -- B. a rebuild (HubDecor151.Apply again) re-dresses at once, no second load
 local before=calls.IS;HT.Build(map)
 local _,l1=lookOf(T.Spots[1])
 check('look: Build again (HubDecor151.Apply runs again) puts the same look back without loading again',calls.IS==before and l1~=nil and HT.Look=='asset'and solids()==2)

 -- C. the client on the asset look: the bounce is unchanged and the asset's mat squashes
 do
  local plays={}
  W.stub('LocalSfx',{Play=function(id)plays[#plays+1]=id;return{}end,Preload=function()end})
  local plr=R.new('Player');plr.Name='Looker';plr.UserId=2001;plr.Parent=Players;Players.LocalPlayer=plr
  function Players.GetPlayers()return{plr}end
  local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=plr
  local mdl=R.new('Model');mdl.Name='Looker';local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Parent=mdl
  local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.RigType=R.Enum.HumanoidRigType.R15;hum.Parent=mdl;mdl.PrimaryPart=root;mdl.Parent=W.workspace;plr.Character=mdl
  local function put(x,feet,z,vy)root.CFrame=CF(x,feet+3,z);root.AssemblyLinearVelocity=V3(0,vy,0)end
  local sc=R.new('LocalScript');sc.Name='HubTrampoline153';sc:SetAttribute('R153TestHook',true);sc.Parent=pg
  local api=W.load('HubTrampoline153Client',sc)
  put(0,60,-100,0);W.frames(2)
  check('look client: finds both nooks and the asset\'s mat (a part inside the look model; the asset has no badge)',#api.Spots==2 and api.Spots[1].Mat~=nil and api.Spots[1].Mat.Name=='Trampoline mat'and api.Spots[1].Mat:IsDescendantOf(select(2,lookOf(T.Spots[1])))and api.Spots[1].Badge==nil)
  local up=T.Velocity(196.2)
  put(312,T.Top()+.1,-269,-50);W.frames(1)
  check('look client: landing on the asset trampoline gives the same bounce ('..string.format('%.1f',root.AssemblyLinearVelocity.Y)..' studs/s, the apex 30), one boing',math.abs(root.AssemblyLinearVelocity.Y-up)<1e-6 and #plays==1)
  W.frames(6)
  local s=api.Spots[1];local dy=s.MatCF.Position.Y-s.Mat._props.CFrame.Position.Y
  local dipped=math.abs(dy)>.001 and math.abs(dy)<=T.SquashDepth+1e-9
  W.frames(40)
  check('look client: the asset\'s mat squashes (off its rest pose, within 0.2 studs) and is back at rest after 0.7 s',dipped and s.Mat._props.CFrame.Position.Y==s.MatCF.Position.Y and #api.Active==0,dy)
  put(312,T.Top()+.05,-269,-40);W.frames(1);local second=root.AssemblyLinearVelocity.Y;put(312,T.Top()+.05,-269,-40);W.frames(6)
  check('look client: the debounce is unchanged (a contact .1 s after a bounce is ignored; no stacking)',math.abs(second-up)<1e-6 and root.AssemblyLinearVelocity.Y==-40,root.AssemblyLinearVelocity.Y)
  sc:Destroy()
 end

 -- D. the owner's asset is refused ("User is not authorized to access Asset"): the hand-placed template, then the built trampoline
 st=reload(DENIED,DENIED)
 check('fallback: "User is not authorized to access Asset" on both routes keeps the BUILT trampoline (42 parts each, one collider), nothing breaks',HT.Look=='built'and calls.IS==1 and calls.AS==1 and solids()==2 and #lookOf(T.Spots[1]):GetChildren()==42 and fold():GetAttribute('Look')=='built',tostring(HT.Look))
 local ok2,text2=HT.Command(nil,nil,{})
 check('fallback: /test trampoline says THE BUILT TRAMPOLINE, why (the real errors of both routes) and how to cure "not authorized" (Get Model, HubTrampolineTemplates153)',ok2 and text2:find('THE BUILT TRAMPOLINE',1,true)~=nil and text2:find('InsertService:LoadAsset: ',1,true)~=nil and text2:find('AssetService:LoadAssetAsync: ',1,true)~=nil and text2:find('User is not authorized',1,true)~=nil and text2:find('Get Model',1,true)~=nil and text2:find('HubTrampolineTemplates153',1,true)~=nil,text2)
 -- the hand-placed template
 local tf=R.new('Folder');tf.Name=T.TemplateFolder;tf.Parent=RS
 local hand=asset({Name='My Trampoline'});hand.Parent=tf
 st=reload(DENIED,DENIED)
 check('template: a model the owner dropped into ReplicatedStorage.HubTrampolineTemplates153 is used (scripts and junk stripped from a COPY), the asset is not even tried',HT.Look=='template'and calls.IS==0 and calls.AS==0 and st.Name=='My Trampoline'and st.Scripts==3 and #leftovers(fold())==0 and solids()==2)
 local keepsScript=false;for _,d in ipairs(hand:GetDescendants())do if d._class=='Script'then keepsScript=true end end
 check('template: the owner\'s original in the folder is never used in place (it still holds its own Script, and no part of it is in the world)',keepsScript and not hand:IsDescendantOf(W.workspace))
 local _,look=lookOf(T.Spots[2]);local lo,hi=box(look);local tm=look:FindFirstChild('Trampoline mat',true)
 check('template: scaled and placed like the asset (12.1 studs, centred on the Lava nook, mat top 4.9)',math.abs(math.max(hi[1]-lo[1],hi[3]-lo[3])-12.1)<.01 and math.abs((lo[1]+hi[1])/2-T.Spots[2].X)<.01 and tm~=nil and math.abs(select(2,aabb(tm))[2]-T.Top())<.001)
 st=reload(function()return container(asset())end,DENIED)
 check('template: preferred over an asset that WOULD load (the asset is not asked: 0 calls)',HT.Look=='template'and calls.IS==0)
 -- a template with nothing usable falls through to the asset, and an empty folder to the built one
 for _,c in ipairs(tf:GetChildren())do c:Destroy()end
 local bad=R.new('Model');bad.Name='OnlyCode';local bs=R.new('Script');bs.Parent=bad;bad.Parent=tf
 st=reload(function()return container(asset())end,DENIED)
 check('template: one with nothing but a script is refused (why is told) and the asset is used',HT.Look=='asset'and calls.IS==1 and st.Tried[1]~=nil and st.Tried[1]:find('OnlyCode',1,true)~=nil and st.Tried[1]:find('no usable parts',1,true)~=nil,tostring(st.Tried[1]))
 for _,c in ipairs(tf:GetChildren())do c:Destroy()end
 st=reload(DENIED,DENIED)
 check('fallback: template removed again and the asset still refused: back to the built trampoline',HT.Look=='built'and solids()==2 and #lookOf(T.Spots[1]):GetChildren()==42)
 tf:Destroy()

 -- E. the asset comes back wrong
 st=reload(function()coroutine.yield()end,DENIED)
 check('fallback: a load that never answers times out ('..T.LoadTimeout..' s) and the built trampoline stays',HT.Look=='built'and st.Tried[1]~=nil and st.Tried[1]:find('timed out after '..T.LoadTimeout..' s',1,true)~=nil,tostring(st.Tried[1]))
 st=reload(function()return container(asset({Extra=T.AssetMaxParts}))end,DENIED)
 check('fallback: an asset with more than '..T.AssetMaxParts..' parts per trampoline is not used (the count is told) and the built one stays',HT.Look=='built'and(st.Tried[#st.Tried]or''):find('too many parts',1,true)~=nil,tostring(st.Tried[#st.Tried]))
 local codeOnly=R.new('Model');local cs=R.new('Script');cs.Parent=codeOnly
 st=reload(function()return container(codeOnly)end,DENIED)
 check('fallback: an asset that is nothing but a script has no usable parts: built stays, nothing runs',HT.Look=='built'and(st.Tried[#st.Tried]or''):find('no usable parts',1,true)~=nil and #leftovers(fold())==0)
 st=reload(function()return nil end,function()return container(asset())end)
 check('fallback: InsertService returning nothing falls through to AssetService:LoadAssetAsync (the second route)',HT.Look=='asset'and calls.IS==1 and calls.AS==1 and st.Route=='AssetService:LoadAssetAsync')
 local sp,why=HT.Prepare(R.new('Script'))
 check('security: a script handed in as the look is refused, and so is anything that is not a model or a part',sp==nil and why:find('script',1,true)~=nil and HT.Prepare(R.new('Humanoid'))==nil)
 -- a look that cannot be fitted leaves BOTH built trampolines exactly as they were (nothing half dressed)
 do local raw=R.Inst.ScaleTo;R.Inst.ScaleTo=function()error('cannot scale this model')end
  st=reload(function()return container(asset())end,DENIED)
  R.Inst.ScaleTo=raw
  local n1,n2=#lookOf(T.Spots[1]):GetChildren(),#lookOf(T.Spots[2]):GetChildren()
  check('fallback: a look that cannot be scaled / placed keeps both built trampolines untouched (42 parts each) and says why',HT.Look=='built'and n1==42 and n2==42 and solids()==2 and(st.Tried[#st.Tried]or''):find('could not be placed',1,true)~=nil and fold():GetAttribute('Look')=='built',tostring(st.Tried[#st.Tried]))
 end
 -- a single part, and a look whose mat cannot be told
 local one=R.new('Part');one.Name='Flat';one.Size=V3(8,1,8);one.CFrame=CF(50,10,50)
 st=reload(function()return container(one)end,DENIED)
 local m1,l=lookOf(T.Spots[1]);local lo1,hi1=box(l)
 check('look: a single part is taken too (wrapped, scaled to 12.1, centred, its top at 4.9); one part has no separate mat: no squash, the bounce stays',HT.Look=='asset'and st.Parts==1 and st.MatName==nil and math.abs(hi1[1]-lo1[1]-12.1)<.01 and math.abs(hi1[2]-T.Top())<.001 and m1:GetAttribute('HasMat')==false)
 st=reload(function()return container(asset({Generic=true,Junk=false}))end,DENIED)
 check('look: two like flat discs with no telling names: no mat is guessed (no squash), the look is still used',HT.Look=='asset'and st.MatName==nil and lookOf(T.Spots[1]):GetAttribute('HasMat')==false)
 -- the nudge: a flat part whose top would land on the nook paving (4.26) lifts the look
 local nudge=R.new('Model');nudge.Name='Nudge'
 part(nudge,'Mat',V3(12.1,.4,12.1),{0,3.2,0});part(nudge,'Pan',V3(12.1,.1,12.1),{0,2.71,0});part(nudge,'Leg',V3(1,3,1),{5,1.5,5})
 st=reload(function()return container(nudge)end,DENIED)
 local _,ln=lookOf(T.Spots[1])
 check('look: a flat part that would lie on the paving plane 4.26 is lifted off it (the look is nudged up by tenths, at most three)',HT.Look=='asset'and ln:GetAttribute('Nudged')>=1 and ln:GetAttribute('Nudged')<=3 and #flat(ln)==0,tostring(ln:GetAttribute('Nudged')))
 -- the command
 local rok,rtext=HT.Command(nil,nil,{'reload'})
 local bok=HT.Command(nil,nil,{'bogus'})
 check('command: trampoline reload rebuilds and says so; an unknown argument is refused',rok and rtext:find('rebuilt',1,true)~=nil and bok==false)
 -- leave the world as the game starts: the built look
 routes(DENIED,DENIED);HT.Reset();HT.Build(map)
 check('look: back to the built trampoline when nothing can be loaded (the state the rest of the suite and the game start in)',HT.Look=='built'and solids()==2)
end

print(string.format('R153 hub fixes: %d checks, %d failures',passed+failed,failed))
if failed>0 then error('failed')end
