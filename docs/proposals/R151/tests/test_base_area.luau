--!nocheck
-- R151 Seed Festival Square: checks of the REAL code (ChestChaseServer.HubDecor151 run by MapService.new, ReplicatedStorage.HubLifeArt151,
-- StarterPlayerScripts.HubLife151.client) on the owner's place (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py) in the R149
-- Roblox mock, after the real start-up builders (treadmills, fences, mystery pedestals, Verity, leaderboards). Prints "ok <name>" /
-- "FAIL <name>: why" and "BUDGET ..." lines; errors at the end if anything failed.
-- R152 (owner: no fountain, fewer trees, no base entrances / signposts / banners / murals / corner towers, a chess-rook battlement on every wall,
-- the track gate as two rook towers): section 16 checks every removal and the battlement and the rook gate.
-- R153 (owner: "remove the ground design for the side gardens"): section 17 checks that the garden spurs are plain cobblestone: no welcome mats,
-- no base-coloured curbs or strips on the ground, and the cream street curbs run flush to each spur with no gap.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
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
local tree=require('./place_tree')
local map=Z.loadPlace(tree,W.workspace)
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
-- the saved walls as the place file has them (before anything runs)
local savedWalls={}
for _,w in ipairs(map.ChestChaseWalls:GetChildren())do savedWalls[w.Name]={CF=w._props.CFrame,Size=w._props.Size,Collide=w._props.CanCollide,Color=w._props.Color}end

local Config=server('Config');local art=server('BiomeVisuals')
server('MapService').new(Config);R.advance(.1)
local records={}
for _,base in ipairs(map.Bases:GetChildren())do if base:GetAttribute('BaseIndex')then
 local i=base:GetAttribute('BaseIndex');records[i]={Index=i,Model=base,Pad=base:FindFirstChild('Pad')}
 pcall(function()art.BuildTreadmillV131(base,i%7+1)end)
end end
pcall(function()local A=server('GardenFenceArt');for i,r in pairs(records)do A.Build(r.Model,i)end end)
pcall(function()local S=server('MysteryPackService');local svc=S.new(Config,{},{Map=nil},{},{},{MapRoot=map});for _,r in pairs(records)do svc:_build(r)end end)
pcall(function()local S=server('VerityService');local svc=S.new(Config,{},{},{},{MapRoot=map,EconomyHub=map.EconomyHub});svc:_build(map.EconomyHub)end)
R.advance(1)
local dec=map:FindFirstChild('HubDecor151')
check('server: MapService.new builds ChestChaseMap.HubDecor151',dec~=nil)
if not dec then error('no HubDecor151')end

-- helpers ------------------------------------------------------------------------------------------------------------------------------------
local function aabb(p)
 local c=p._props.CFrame;local s=p._props.Size;local r=c.R
 local e={(math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2}
 local q=c.Position
 return{q.X-e[1],q.Y-e[2],q.Z-e[3]},{q.X+e[1],q.Y+e[2],q.Z+e[3]}
end
local function boxOf(model)
 local lo,hi
 for _,p in ipairs(model:IsA('BasePart')and{model}or model:GetDescendants())do if p:IsA('BasePart')and(p._props.Transparency or 0)<1 then
  local a,b=aabb(p);lo=lo and{math.min(lo[1],a[1]),math.min(lo[2],a[2]),math.min(lo[3],a[3])}or a;hi=hi and{math.max(hi[1],b[1]),math.max(hi[2],b[2]),math.max(hi[3],b[3])}or b
 end end
 return lo,hi
end
local function overlap(a0,a1,b0,b1,m)m=m or 0;return a0[1]<b1[1]-m and a1[1]>b0[1]+m and a0[2]<b1[2]-m and a1[2]>b0[2]+m and a0[3]<b1[3]-m and a1[3]>b0[3]+m end
-- exact for balls and upright cylinders (their bounding boxes are bigger than they are), boxes for the rest
local function partOverlaps(p,lo,hi,m)
 m=m or 0
 local a,b=aabb(p);if not overlap(a,b,lo,hi,m)then return false end
 local sh=p._props.Shape;sh=sh and(sh.Name or tostring(sh))
 local c=p._props.CFrame;local s=p._props.Size;local q=c.Position
 local function d2(x,z)local dx=math.max(lo[1]-x,0,x-hi[1]);local dz=math.max(lo[3]-z,0,z-hi[3]);return dx*dx+dz*dz end
 if sh=='Ball'then local r=math.min(s.X,s.Y,s.Z)/2;local dy=math.max(lo[2]-q.Y,0,q.Y-hi[2]);return d2(q.X,q.Z)+dy*dy<(r-m)^2 end
 if sh=='Cylinder'and math.abs(c.R[2][1])>.99 then local r=math.min(s.Y,s.Z)/2;return d2(q.X,q.Z)<(r-m)^2 end
 return true
end
local function first(list)return list[1]and(list[1]..' (+'..(#list-1)..' more)')or nil end
local function partsUnder(root)local out={};for _,p in ipairs(root:GetDescendants())do if p:IsA('BasePart')then out[#out+1]=p end end;return out end
local function path(p)return Z.path(p)end

-- 1. walls unchanged (size, place, collision) and restyled -------------------------------------------------------------------------------------
do local ok,why=true,nil
 for _,w in ipairs(map.ChestChaseWalls:GetChildren())do local s=savedWalls[w.Name]
  local c=w._props.CFrame
  if not(s and c.Position==s.CF.Position and w._props.Size==s.Size and w._props.CanCollide==s.Collide)then ok=false;why=w.Name end
  if(w._props.Transparency or 0)~=0 then ok=false;why=w.Name..' transparent'end
 end
 check('walls: the five saved wall parts keep their CFrame, Size, CanCollide and stay opaque',ok,why)
 local w=map.ChestChaseWalls.LobbyBackWall
 check('walls: restyled cream plaster, the old colour kept as an attribute',w._props.Material and tostring(w._props.Material.Name)=='Plaster'and w:GetAttribute('R151OldColor')~=nil)
 local piers=0;for _,d in ipairs(map.GardenHubDesign:GetChildren())do if d.Name:find('TimberPier')and d._props.Transparency==1 then piers+=1 end end
 check('walls: the 13 old timber strips hidden',piers==13,piers)
 local caps=0;for _,d in ipairs(map.GardenHubDesign:GetChildren())do if d.Name:find('^Lobby.*Cap$')and d._props.Transparency==1 then caps+=1 end end
 check('walls: the 5 saved wood caps (51 - 52) hidden under the battlement',caps==5,caps)
end

-- 2. server parts: anchored, untouchable, unqueryable; only the gate towers collide ----------------------------------------------------------
local serverParts=partsUnder(dec)
do local bad,coll={},0
 for _,p in ipairs(serverParts)do
  if p._props.Anchored~=true or p._props.CanTouch~=false or p._props.CanQuery~=false then bad[#bad+1]=path(p)end
  if p._props.CanCollide then coll+=1;if p.Name~='Gate tower'then bad[#bad+1]='collides: '..path(p)end end
 end
 check('server: every part anchored, CanTouch / CanQuery off',#bad==0,first(bad))
 check('server: only the gate towers\' shafts collide (two stacked cylinders per rook)',coll==4,coll)
end

-- 3. clearances against every gameplay object -------------------------------------------------------------------------------------------------
local gameplay={}
local function add(name,lo,hi)if lo then gameplay[#gameplay+1]={Name=name,Lo=lo,Hi=hi}end end
for i,r in pairs(records)do
 for _,n in ipairs({'GardenPlots','TreadmillArtV131','MysteryPedestal','GardenBedBorders'})do local m=r.Model:FindFirstChild(n);if m then local a,b=boxOf(m);add('Base'..i..'/'..n,a,b)end end
 local sp=r.Model:FindFirstChild('Spawn',true);if sp then local a,b=aabb(sp);add('Base'..i..'/Spawn',{a[1],b[2],a[3]},{b[1],b[2]+6,b[3]})end -- (the standing room on it)
 -- the pad's interior (everything but the 4-stud rim where the fence and the arch posts stand), and the 32-stud opening up to 14 studs
 local pad=r.Pad;local top=pad._props.CFrame*CF(0,pad._props.Size.Y/2,0);local front=pad._props.Size.Z/2
 local function box(x0,x1,y0,y1,z0,z1)
  local lo,hi
  for _,x in ipairs({x0,x1})do for _,y in ipairs({y0,y1})do for _,z in ipairs({z0,z1})do local p=top*V3(x,y,z)
   lo=lo and{math.min(lo[1],p.X),math.min(lo[2],p.Y),math.min(lo[3],p.Z)}or{p.X,p.Y,p.Z};hi=hi and{math.max(hi[1],p.X),math.max(hi[2],p.Y),math.max(hi[3],p.Z)}or{p.X,p.Y,p.Z}
  end end end
  return lo,hi
 end
 local hx=pad._props.Size.X/2
 add('Base'..i..'/pad interior',box(-hx+4,hx-4,-1,40,-front+4,front-4.5))
 add('Base'..i..'/opening',box(-16,16,0,14,front-6,front+2))
end
do local a,b=aabb(map:FindFirstChild('FallbackSpawn',true));add('FallbackSpawn',{a[1],b[2],a[3]},{b[1],b[2]+6,b[3]})end -- (the standing room on it)
add('safe line',aabb(map.Lobby.BaseBoundaryLine))
add('market',boxOf(map.EconomyHub.MerchantStands))
add('Verity',boxOf(map.EconomyHub.VerityNPC))
for _,m in ipairs(map.EconomyHub.GeneratedHubScenery:GetChildren())do add('leaderboard '..m.Name,boxOf(m))end
add('track walkway',{-89,3,-99.8},{89,30,6000})
local function clashes(parts,allowed)
 local out={}
 for _,p in ipairs(parts)do if(p._props.Transparency or 0)<1 then local a,b=aabb(p)
  for _,g in ipairs(gameplay)do if partOverlaps(p,g.Lo,g.Hi,.01)and not(allowed and allowed(p,g))then out[#out+1]=path(p)..' x '..g.Name end end
 end end
 return out
end
-- (paving under the market / Verity / leaderboards and the arch's posts in the fence rim are by design; checked separately)
local function serverAllowed(p,g)
 if g.Name=='market'or g.Name=='Verity'then local a,b=aabb(p);return b[2]-a[2]<1 and(p.Name=='Market square'or p.Name=='Stage circle')end
 return false
end
do local c=clashes(serverParts,serverAllowed);check('clearances: no server part in a base plot / pad interior / 32-stud opening / treadmill / pedestal / spawn / safe line / market / Verity / leaderboard / track walkway',#c==0,first(c))end
-- the reserved back corners (R151 Best Pull / Biggest Fruit displays) stay empty (a 4-stud band along the walls holds the wall dressing)
local corners={{{145,0,-614},{331,200,-420}},{{-331,0,-614},{-145,200,-420}}}
local function inCorners(parts)local out={};for _,p in ipairs(parts)do if(p._props.Transparency or 0)<1 then for _,c in ipairs(corners)do if partOverlaps(p,c[1],c[2],.01)then out[#out+1]=path(p)end end end end;return out end
do local c=inCorners(serverParts);check('reserved corners: no server part',#c==0,first(c))end
-- gate clearances
do
 local trim=dec.Gate['Gatehouse trim'];local beamLo=select(1,boxOf(trim));check('clearance: the gatehouse\'s lowest trim is 39.5 studs over the floor',beamLo[2]-4>=39.5,beamLo[2])
 local keyLo=math.huge;for _,k in ipairs(dec.Gate:GetChildren())do if k:GetAttribute('R151Stage')then keyLo=math.min(keyLo,select(1,aabb(k))[2])end end
 check('clearance: the gate keys hang 38 studs over the floor',keyLo-4>=38,keyLo)
 local towersOk,baseOk=true,true
 for _,t in ipairs(dec.Gate:GetChildren())do
  if t.Name=='Gate tower'then local a,b=aabb(t);if math.min(math.abs(a[1]),math.abs(b[1]))<90.9 then towersOk=false end end
  if t.Name:find('^Gate base')then local a,b=aabb(t);if math.min(math.abs(a[1]),math.abs(b[1]))<90.2 then baseOk=false end end
 end
 check('clearance: the gate towers\' shafts stay outside the 180-wide run-up and track (|x| > 90.9)',towersOk)
 check('clearance: the rooks\' stepped bases reach no further in than the R151 plinth did (|x| > 90.2)',baseOk)
end

-- 4. gate keys: the keeper speeds -------------------------------------------------------------------------------------------------------------
do local keys={};for _,k in ipairs(dec.Gate:GetChildren())do local st=k:GetAttribute('R151Stage');if st then keys[#keys+1]=k end end
 check('gate: seven biome keys in track order',#keys==7)
 local Labels=W.module('KeeperPursuit')
 local ok=true
 for _,k in ipairs(keys)do if math.abs((k:GetAttribute('R151EscapeSpeed')or-1)-Labels.EscapeSpeed(k:GetAttribute('R151Stage')))>1e-6 then ok=false end end
 check('gate: each key carries its keeper\'s escape speed (KeeperPursuit.EscapeSpeed)',ok)
 local forest=dec.Gate['Biome key 1'];check('gate: the Forest key reads "⚡ 0"',forest.KeyLegend.Line3.Text=='⚡ 0',forest.KeyLegend.Line3.Text)
end

-- 5. server: re-Apply is idempotent -----------------------------------------------------------------------------------------------------------
do
 local n0=#serverParts
 local H=server('HubDecor151')
 local dec2=H.Apply(map)
 local count=0;for _,c in ipairs(map:GetChildren())do if c.Name=='HubDecor151'then count+=1 end end
 check('server: Apply twice leaves one HubDecor151 with the same parts',count==1 and #partsUnder(dec2)==n0,#partsUnder(dec2)..' vs '..n0)
 local w=map.ChestChaseWalls.LobbyBackWall
 check('server: the walls\' original colour survives a second Apply',w:GetAttribute('R151OldColor')==savedWalls.LobbyBackWall.Color)
 dec=dec2
 records[1].Model:SetAttribute('BaseOwnerDisplayName','Ben');records[3].Model:SetAttribute('BaseOwnerDisplayName','Leo')
 local server1=0;for _,p in ipairs(partsUnder(dec))do server1+=1 end
 print(string.format('BUDGET server (Phase 1) parts %d',server1))
 check('budget: server (Phase 1) parts <= 600 (R151: 725)',server1<=600,server1)
end

-- Client ---------------------------------------------------------------------------------------------------------------------------------------
Run.IsClient=function()return true end;Run.IsServer=function()return false end
local player=R.new('Player');player.Name='Tester';player.UserId=1001;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return{player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play(s)s._props.IsPlaying=true end;function R.Inst.Stop(s)s._props.IsPlaying=false end;function R.Inst.Pause(s)s._props.IsPlaying=false end
W.service('ContentProvider').PreloadAsync=function()end
local budget={Tier=3};W.stub('ClientFxBudget',{Get=function()return budget.Tier end,Low=function()return budget.Tier==1 end})
local model=R.new('Model');model.Name='Tester'
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.Transparency=1;hrp.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=model;model.PrimaryPart=hrp;model.Parent=W.workspace;player.Character=model
hrp.CFrame=CF(0,7,-200)
local cam=W.workspace.CurrentCamera
local function load()
 local sc=R.new('LocalScript');sc.Name='HubLife151';sc:SetAttribute('R151TestHook',true);sc.Parent=pg
 return W.load('HubLife151Client',sc),sc
end
local function tick(n,dt)for _=1,n or 1 do Run.Heartbeat:Fire(dt or .5)end end
local function visible(api)local c={core=0,detail=0,fine=0};for _,cell in pairs(api.State.Ctx.Cells)do for level,f in pairs(cell.Levels)do if f.Parent then c[level]+=#partsUnder(f)end end end;return c end

-- 6. budgets per device tier ------------------------------------------------------------------------------------------------------------------
local counts={}
for _,t in ipairs({1,2,3})do
 budget.Tier=t;local api,sc=load();tick(1)
 local ctx=api.State.Ctx
 check('client tier '..t..': builds',ctx~=nil and W.workspace:FindFirstChild('HubLife151')~=nil)
 counts[t]=ctx and{core=ctx.Counts.core,detail=ctx.Counts.detail,fine=ctx.Counts.fine}or{core=0,detail=0,fine=0}
 local tot=counts[t].core+counts[t].detail+counts[t].fine
 print(string.format('BUDGET client tier %d: core %d, detail %d, fine %d, total %d',t,counts[t].core,counts[t].detail,counts[t].fine,tot))
 sc:Destroy()
 check('client tier '..t..': the script\'s teardown removes its folder',W.workspace:FindFirstChild('HubLife151')==nil)
end
check('budget: tier 1 builds only the core level',counts[1].detail==0 and counts[1].fine==0)
check('budget: tier 2 builds core + detail, no fine',counts[2].detail>0 and counts[2].fine==0)
check('budget: core <= 500, core + detail <= 1300, all <= 1400',counts[3].core<=500 and counts[3].core+counts[3].detail<=1300 and counts[3].core+counts[3].detail+counts[3].fine<=1400)

-- 7. client parts: placement, flags, clearances, corners ---------------------------------------------------------------------------------------
budget.Tier=3
local api,sc=load();tick(1)
local life=W.workspace:FindFirstChild('HubLife151')
-- (show every level to test them all)
local saveNear={api.Near.detail,api.Near.fine};api.Near.detail=1e6;api.Near.fine=1e6;api.ApplyLod()
local clientParts=partsUnder(life)
do local bad={}
 for _,p in ipairs(clientParts)do if p._props.Anchored~=true or p._props.CanTouch~=false or p._props.CanQuery~=false or p._props.CanCollide then bad[#bad+1]=path(p)end end
 check('client: every part anchored, never collides, CanTouch / CanQuery off',#bad==0,first(bad))
 -- (the bunting strings are tied to the market's eaves by design)
 local c=clashes(clientParts,function(p,g)return g.Name=='market'and(p.Name=='Bunting line'or p.Name=='Pennant')end)
 check('clearances: no client part in a base plot / pad interior / opening / treadmill / pedestal / spawn / safe line / market / Verity / leaderboard / track',#c==0,first(c))
 local k=inCorners(clientParts);check('reserved corners: no client part',#k==0,first(k))
end
do local Art=W.module('HubLifeArt151');local bad={}
 local bases={};for i,r in pairs(records)do bases[i]={Frame=r.Pad._props.CFrame,Size=r.Pad._props.Size}end
 for _,t in ipairs(Art.Layout.trees)do local ok,why=Art.Clear(t[2],t[3],1.5,bases);if not ok then bad[#bad+1]=t[1]..' '..t[2]..','..t[3]..' '..why end end
 for _,list in ipairs({Art.Layout.bushes,Art.Layout.lamps,Art.Layout.topiary})do for _,t in ipairs(list)do
  local onSquare=list==Art.Layout.topiary and t[4]==true and math.abs(t[1])<52 and t[2]<-232 and t[2]>-312 -- (pots on the market square by design)
  local ok,why=Art.Clear(t[1],t[2],1,bases,onSquare);if not ok then bad[#bad+1]=t[1]..','..t[2]..' '..why end
 end end
 for _,b in ipairs(Art.Layout.benches)do local ok,why=Art.Clear(b[1],b[2],1,bases,true);if not ok then bad[#bad+1]='bench '..b[1]..','..b[2]..' '..why end end
 check('layout: every tree, bush, lamp and topiary stands on grass (not a street, base, run-up, market, Verity or corner)',#bad==0,first(bad))
 -- variety: species, deterministic, no two trees alike
 local species={};for _,t in ipairs(Art.Layout.trees)do species[t[1]..(t[4]and('/'..tostring(t[4]))or'')]=true end
 local n=0;for _ in pairs(species)do n+=1 end
 check('variety: at least 8 tree kinds / sizes / colours (R152: 24 trees, was 62)',n>=8,n)
 local crowns={};local dup=0
 for _,p in ipairs(clientParts)do if p.Name=='Tree crown'or p.Name=='Blossom crown'then local key=string.format('%.2f|%.2f|%d,%d,%d',p._props.Size.X,p._props.CFrame.Position.Y%10,math.floor(p._props.Color.R*255),math.floor(p._props.Color.G*255),math.floor(p._props.Color.B*255))
  if crowns[key]then dup+=1 end;crowns[key]=true end end
 check('variety: no two crowns identical in size, height and shade',dup==0,dup)
 local a=W.module('HubDecorKit151').Rng('oak:M:1')();local b=W.module('HubDecorKit151').Rng('oak:M:1')()
 check('variety: deterministic per instance (same seed, same tree on every client)',a==b)
 -- owner: "remove the apples or red stuff on the trees the trees are just trees"
 local fruity={}
 for _,p in ipairs(clientParts)do
  if p.Name=='Fruit'or p.Name=='Coconut'or p.Name=='Ember'or p.Name=='Cactus flower'then fruity[#fruity+1]=path(p)end
  local c=p._props.Color
  if c and(p.Name:find('crown')or p.Name:find('Crown')or p.Name:find('trunk')or p.Name=='Palm leaf'or p.Name=='Pine tier'or p.Name:find('[Cc]actus'))and c.R>=.35 and c.G<=.55*c.R and c.B<=.6*c.R then fruity[#fruity+1]='red '..path(p)end
 end
 local kinds={};for _,t in ipairs(Art.Layout.trees)do kinds[t[1]]=true end
 check('no fruit: no fruit, coconut, cactus flower or ember on any tree, nothing red on a tree, no fruit-tree slot left',#fruity==0 and not kinds.fruit and kinds.leafy,first(fruity))
end

-- 8. detail by distance ----------------------------------------------------------------------------------------------------------------------
api.Near.detail,api.Near.fine=saveNear[1],saveNear[2]
cam.CFrame=CF(0,12,-180);api.ApplyLod();local atGate=visible(api)
cam.CFrame=CF(0,12,1200);api.ApplyLod();local onTrack=visible(api)
cam.CFrame=CF(0,12,-392);api.ApplyLod();local atFountain=visible(api) -- (R152: the old fountain spot, the open south plaza)
print(string.format('BUDGET visible at the front street: core %d, detail %d, fine %d; at the old fountain spot: core %d, detail %d, fine %d',atGate.core,atGate.detail,atGate.fine,atFountain.core,atFountain.detail,atFountain.fine))
check('lod: near the front street some detail is hidden (far cells)',atGate.detail>0 and atGate.detail<counts[3].detail)
check('lod: far down the track everything is hidden',onTrack.core==0 and onTrack.detail==0 and onTrack.fine==0)
check('lod: at the old fountain spot (the south plaza) the fine level shows (butterflies of the south lawn)',atFountain.fine>0)
budget.Tier=2;cam.CFrame=CF(0,12,-180);api.ApplyLod();local phone=visible(api);budget.Tier=3
print(string.format('BUDGET visible on a phone (tier 2) at the front street: core %d, detail %d, fine %d (total %d)',phone.core,phone.detail,phone.fine,phone.core+phone.detail+phone.fine))
check('lod: tier 2 (phones) shows less detail than the desktop and no fine level',phone.detail<atGate.detail and phone.fine==0)
player:SetAttribute('FastMode',true);api.ApplyLod();local fast=visible(api)
check('lod: FastMode hides detail and fine',fast.detail==0 and fast.fine==0 and fast.core>0)
player:SetAttribute('FastMode',nil);api.ApplyLod()

-- 9. ambience only when near, never with Reduced Motion -------------------------------------------------------------------------------------
cam.CFrame=CF(100,12,-150);api.ApplyLod()
check('ambience: wanted near the butterflies and the blossoms by the gate',api.AmbienceWanted())
local bf=api.State.Ctx.Butterflies[1];for _,b in ipairs(api.State.Ctx.Butterflies)do if(b.Home-V3(100,8,-150)).Magnitude<(bf.Home-V3(100,8,-150)).Magnitude then bf=b end end
local before=bf.Left._props.CFrame.Position
api.AmbienceStep(.1);api.AmbienceStep(.1)
check('ambience: butterflies move',(bf.Left._props.CFrame.Position-before).Magnitude>0)
local emit=0;for _,pe in ipairs(api.State.Ctx.Emitters)do if pe.Enabled then emit+=1 end end
check('ambience: petals on near the blossoms (no fountain sparkles any more)',emit>0 and api.State.Ctx.Fountain==nil,emit)
cam.CFrame=CF(0,12,1200);api.ApplyLod()
check('ambience: off far away',not api.AmbienceWanted())
cam.CFrame=CF(100,12,-150);W.Gui.ReducedMotionEnabled=true;api.ApplyLod()
local on=0;for _,pe in ipairs(api.State.Ctx.Emitters)do if pe.Enabled then on+=1 end end
check('reduced motion: no ambience, no particles',not api.AmbienceWanted()and on==0)
W.Gui.ReducedMotionEnabled=false;api.ApplyLod()

-- 10. lamps in the dark ----------------------------------------------------------------------------------------------------------------------
do local Env=W.module('EnvironmentLighting');local lights=api.State.Ctx.Lights
 local function lit()local n=0;for _,l in ipairs(lights)do if l.Enabled then n+=1 end end;return n end
 api.ApplyLamps(true);check('lamps: off by day',lit()==0)
 Env.Level=1;api.ApplyLamps();check('lamps: on in The Darkened\'s blackout',lit()==#lights and #lights>0,#lights)
 Env.Level=0;api.ApplyLamps();RS:SetAttribute('GlobalWeather','Thunderstorm');api.ApplyLamps();check('lamps: on in a thunderstorm',lit()==#lights)
 RS:SetAttribute('GlobalWeather','Clear');api.ApplyLamps();check('lamps: off again when it clears',lit()==0)
 print(string.format('BUDGET lamp lights %d',#lights))
end

-- 11. gate keys tick per player ---------------------------------------------------------------------------------------------------------------
do local Pursuit=W.module('KeeperPursuit')
 local function line(i)return dec.Gate['Biome key '..i].KeyLegend.Line3 end
 player:SetAttribute('PhysicalWalkSpeed',Pursuit.EscapeSpeed(6)+.5);api.ApplyKeys()
 check('keys: a player faster than the Jungle keeper sees Forest and Jungle ticked green',line(1).Text:sub(1,3)=='✓'and line(2).Text:sub(1,3)=='✓'and line(2).TextColor3.G>.9 and line(3).Text:sub(1,3)~='✓',line(2).Text..' / '..line(3).Text)
 player:SetAttribute('PhysicalWalkSpeed',Pursuit.EscapeSpeed(7)+1);api.ApplyKeys()
 local all=true;for i=1,7 do if line(i).Text:sub(1,3)~='✓'then all=false end end
 check('keys: faster than the Storm keeper ticks all seven',all)
 player:SetAttribute('PhysicalWalkSpeed',0);api.ApplyKeys()
 check('keys: a slow player gets no tick on Jungle (and the number stays)',line(2).Text=='⚡ '..tostring(dec.Gate['Biome key 2']:GetAttribute('R151Need')),line(2).Text)
end

-- 12. (R152: the signposts are gone: see section 16) --------------------------------------------------------------------------------------------

-- 13. ambience sound zones --------------------------------------------------------------------------------------------------------------------
do local s=api.Sounds.Birds
 if s then
  hrp.CFrame=CF(60,7,-205);for _=1,20 do api.Tick(.25)end
  check('sound: birds near the welcome lawn',s.Sound.Volume>0,s.Sound.Volume)
  hrp.CFrame=CF(0,7,800);for _=1,40 do api.Tick(.25)end
  check('sound: silent outside the hub',s.Sound.Volume==0,s.Sound.Volume)
 else check('sound: birds layer created',false)end
end

-- 14. streaming / teardown: the server folder goes away and comes back ------------------------------------------------------------------------
do
 dec:Destroy();check('teardown: the client drops its props when HubDecor151 goes',W.workspace:FindFirstChild('HubLife151')==nil)
 dec=server('HubDecor151').Apply(map);tick(1)
 check('streaming: the client rebuilds when HubDecor151 comes back',W.workspace:FindFirstChild('HubLife151')~=nil and api.State.Ctx~=nil)
 sc:Destroy();check('teardown: destroying the script removes everything',W.workspace:FindFirstChild('HubLife151')==nil and not api.State.Ambience)
end

-- 15. the owner's studded tree models (a STAND-IN pair: the real ones cannot be downloaded here) -------------------------------------------------
do
 -- (Clone copies attributes on Roblox; the shared mock does not)
 local rawClone=R.Inst.Clone;R.Inst.Clone=function(self)local c=rawClone(self);c._attrs=table.clone(self._attrs);return c end
 local Kit=W.module('HubDecorKit151')
 local tf=RS:FindFirstChild(Kit.TreeFolder)
 check('trees: the server made ReplicatedStorage.HubTreeTemplates151 and tried both ids (offline: failed) - the part-built studded trees stand',
  tf~=nil and tf:GetAttribute('Ready')==true and tf:GetAttribute('Route16637971059')=='failed'and tf:GetAttribute('Route17280628013')=='failed')
 require('./standin_tree')(R,tf)
 local totals={}
 for _,t in ipairs({1,2,3})do
  budget.Tier=t;local api2,sc2=load();tick(1)
  local life2=W.workspace:FindFirstChild('HubLife151')
  local ctx=api2.State.Ctx;local n=0
  for _,d in ipairs(life2:GetDescendants())do if d.Name=='Studded tree'then n+=1 end end
  totals[t]=ctx.Counts.core+ctx.Counts.detail+ctx.Counts.fine
  print(string.format('BUDGET with the stand-in tree models, tier %d: %d clones, core %d, detail %d, fine %d, total %d (%s)',t,n,ctx.Counts.core,ctx.Counts.detail,ctx.Counts.fine,totals[t],tostring(life2:GetAttribute('UsedFor'))))
  if t==3 then
   api2.Near.detail=1e6;api2.Near.fine=1e6;api2.ApplyLod()
   local all=partsUnder(life2);local bad={}
   for _,p in ipairs(all)do if p._props.Anchored~=true or p._props.CanCollide~=false or p._props.CanTouch~=false or p._props.CanQuery~=false then bad[#bad+1]=path(p)end end
   check('trees: desktop - the leafy slots take the stand-in models ('..n..' clones: 8 oaks, 2 blossoms, 2 leafy trees)',n==12,n)
   check('trees: every part of the square with the models anchored, never collides, CanTouch / CanQuery off',#bad==0,first(bad))
   local c=clashes(all,function(p,g)return g.Name=='market'and(p.Name=='Bunting line'or p.Name=='Pennant')end)
   check('trees: clearances with the models (base plots / pads / openings / treadmills / pedestals / spawns / safe line / market / Verity / leaderboards / track)',#c==0,first(c))
   local k=inCorners(all);check('trees: reserved corners stay empty with the models',#k==0,first(k))
  end
  sc2:Destroy()
 end
 check('trees: budgets with the models - tier 1 <= 500, tier 2 <= 1300, tier 3 <= 1600',totals[1]<=500 and totals[2]<=1300 and totals[3]<=1600,totals[1]..' / '..totals[2]..' / '..totals[3])
 for _,c in ipairs(tf:GetChildren())do c:Destroy()end
 budget.Tier=3
end

-- 16. R152: what was removed, the chess-rook battlement round the walls, the rook gate -----------------------------------------------------------
-- (owner: "removing the fountain. reduce the amount of trees ... remove the front gates for the garden", "remove these painting and flatten out the
-- top of the wall ... the gate of the track has to be a castle like gate like u know a rook in chess", "remove the signs, the banners and that red
-- track thingy, make all the walls in the base area for the top design be like a rook in chess design")
do
 local Kit=W.module('HubDecorKit151');local Art=W.module('HubLifeArt151');local H=server('HubDecor151')
 local WALL_TOP=51
 local function namesLike(list,pats)local out={}
  for _,p in ipairs(list)do for _,pat in ipairs(pats)do if p.Name:find(pat)then out[#out+1]=p.Name..' @ '..path(p);break end end end
  return out
 end
 local sp=partsUnder(dec)
 -- the removed things (server): fountain, murals, banners, base entrances (every piece), corner towers, hedge, topiary, red crest, flags
 local entrance={'^Arch','Pennant','[Mm]edallion','Gate post','Guard','[Ss]tatue','Footing'}
 check('removed: no base entrance piece at any base (no arch footings, posts, post bands, ball tops, pennant poles / pennants, name beam, beam trim, number medallion), no BaseEntrances folder',
  #namesLike(sp,entrance)==0 and dec:FindFirstChild('BaseEntrances')==nil and H.UpdateOwnerNames==nil and H.FreeText==nil,first(namesLike(sp,entrance)))
 check('removed: no murals (plates, pieces, frames, plaques, crests, number keys) and no mural data in the kit',
  #namesLike(sp,{'Mural'})==0 and dec:FindFirstChild('Murals')==nil and Kit.Murals==nil and Kit.MuralW==nil and Kit.MuralH==nil and Kit.MuralY0==nil)
 check('removed: no base banners (rods, cloth, stripes, tails) and no banner data in the kit',#namesLike(sp,{'Banner'})==0 and dec:FindFirstChild('Banners')==nil and Kit.Banners==nil)
 check('removed: no corner towers (tower, plinth, band, three roofs, finial), no hedge, no topiary on the walls',
  #namesLike(sp,{'^Corner tower','^Tower ','^Hedge','^Topiary'})==0)
 check('removed: no red track crest, no flags and flag poles on the gate, no old gate roofs / finials / haunch names',
  #namesLike(sp,{'crest','Flag','^Gate roof','^Gate finial','^Gate tower band','^Gate tower plinth','^Arch '})==0 and Kit.Gate.FlagX==nil)
 check('removed: no fountain part and no fountain plaza in the server folder; the south plaza stays as paving',#namesLike(sp,{'[Ff]ountain'})==0 and dec.Paths:FindFirstChild('South plaza')~=nil and dec.Paths:FindFirstChild('Fountain plaza')==nil)
 check('removed: the art has no fountain and no signposts',Art.Fountain==nil and Art.Signpost==nil)
 -- trees: 22 .. 25 of the old 62 (a third to 40 %), none in the middle of the square, the streets or the lanes
 do local trees=Art.Layout.trees;local n=#trees
  check('trees: '..n..' of the old 62 stay (a third to 40 %)',n>=21 and n<=25 and n/62>=.33 and n/62<=.40,n)
  local mid={};for _,t in ipairs(trees)do if math.abs(t[2])<70 and t[3]>-540 then mid[#mid+1]=t[1]..' '..t[2]..','..t[3]end end
  check('trees: none on the central lawns, the avenue or the market square (|x| < 70; only the snow lane\'s far pines stand there)',#mid==0,first(mid))
  local slots=Art.TreeSlots();local leafy=0;for _,t in ipairs(slots)do if t.Kind=='oak'or t.Kind=='blossom'or t.Kind=='leafy'then leafy+=1 end end
  check('trees: the tree slots still list every tree in layout order for the owner\'s models ('..#slots..' slots, '..leafy..' leafy)',#slots==n and leafy==12,leafy)
 end
 -- the wall top: only battlement merlons stand over 51, all one size, evenly spaced, one on every outer corner, none anywhere near tower height
 local B=Kit.Battlement
 local merlons,otherTop={},-1
 for _,p in ipairs(partsUnder(dec.Walls))do local a,b=aabb(p);if p.Name=='Wall merlon'then merlons[#merlons+1]=p else otherTop=math.max(otherTop,b[2])end end
 check('walls: '..#merlons..' merlons (4 corners, 46 front, 102 side, 66 back)',#merlons==218,#merlons)
 check('walls: nothing but merlons rises above the wall top (plinth, string course, pilasters and their stone caps all end at 51 or under)',otherTop<=WALL_TOP+1e-6,otherTop)
 do local bad={}
  for _,p in ipairs(merlons)do local a,b=aabb(p);local sz=p._props.Size
   if math.abs(sz.X-B.Size)>1e-6 or math.abs(sz.Z-B.Size)>1e-6 or math.abs(sz.Y-B.Height)>1e-6 or math.abs(a[2]-WALL_TOP)>1e-6 or math.abs(b[2]-(WALL_TOP+B.Height))>1e-6 then bad[#bad+1]=path(p)end end
  check('walls: every merlon is one size ('..B.Size..' x '..B.Height..' x '..B.Size..'), square, standing on the wall top (bottom 51, top 57)',#bad==0,first(bad))
  local topAll=0;for _,p in ipairs(sp)do if not p:IsDescendantOf(dec.Gate)then topAll=math.max(topAll,select(2,aabb(p))[2])end end
  local crownTop=select(2,aabb(dec.Gate['Gate crown']))[2]
  check('walls: nothing of the walls or paths is over '..(WALL_TOP+B.Height)..' and the merlons are far under the gate towers (crown top '..crownTop..')',topAll<=WALL_TOP+B.Height+1e-6 and WALL_TOP+B.Height<crownTop-8,topAll)
 end
 do local at={};for _,p in ipairs(merlons)do local q=p._props.CFrame.Position;at[#at+1]={q.X,q.Z}end
  local function has(x,z)for _,q in ipairs(at)do if math.abs(q[1]-x)<.01 and math.abs(q[2]-z)<.01 then return true end end;return false end
  check('walls: a square merlon on each of the four outer corners (no tower, nothing higher)',has(337.5,-101.5)and has(-337.5,-101.5)and has(337.5,-620.5)and has(-337.5,-620.5))
  local lines={}
  local function add(key,v)lines[key]=lines[key]or{};table.insert(lines[key],v)end
  for _,q in ipairs(at)do
   if math.abs(q[2]+101.5)<.01 then add(q[1]>0 and'front east'or'front west',q[1])end
   if math.abs(q[2]+620.5)<.01 then add('back',q[1])end
   if math.abs(math.abs(q[1])-337.5)<.01 then add(q[1]>0 and'east'or'west',q[2])end
  end
  local bad={}
  for key,list in pairs(lines)do table.sort(list)
   local lo,hi=math.huge,0
   for i=2,#list do local d=list[i]-list[i-1];lo=math.min(lo,d);hi=math.max(hi,d)end
   if hi-lo>1e-3 or lo<9.9 or hi>10.1 then bad[#bad+1]=key..' '..lo..' .. '..hi end
  end
  check('walls: the merlons are evenly spaced along every run (front east / west, east, west, back: one pitch each, 9.9 - 10.1 studs, gaps = merlons)',#bad==0 and next(lines)~=nil,first(bad))
  local counts={};for k,l in pairs(lines)do counts[k]=#l end
  check('walls: run lengths 24 / 24 front, 53 / 53 side, 68 back (corners shared)',counts['front east']==24 and counts['front west']==24 and counts.east==53 and counts.west==53 and counts.back==68,
   string.format('%s %s %s %s %s',tostring(counts['front east']),tostring(counts['front west']),tostring(counts.east),tostring(counts.west),tostring(counts.back)))
 end
 -- client props never rise over the wall top near a wall (lanterns hang at 27)
 do budget.Tier=3;local api3,sc3=load();tick(1);local life2=W.workspace:FindFirstChild('HubLife151')
  api3.Near.detail=1e6;api3.Near.fine=1e6;api3.ApplyLod()
  local cp=partsUnder(life2);local high={}
  for _,p in ipairs(cp)do local q=p._props.CFrame.Position;local a,b=aabb(p)
   local d=math.min(335-math.abs(q.X),q.Z+618,(math.abs(q.X)>94 and -104-q.Z)or 1e9)
   if d<6 and b[2]>WALL_TOP then high[#high+1]=path(p)end end
  check('client: nothing within 6 studs of a wall stands over the wall top',#high==0,first(high))
  check('client: the wall lanterns stay (14), hung under the battlement',#api3.State.Ctx.Lanterns==14)
  -- the old fountain spot: nothing at all in the plaza circle (radius 19 of the 21-stud paving), no fountain / sign parts anywhere
  local inPlaza,fountain={},namesLike(cp,{'[Ff]ountain','^Ripple','^Seed pack','Sparkle','^Water arc','Signpost','^Sign board','^Sign tip'})
  for _,p in ipairs(cp)do local q=p._props.CFrame.Position;if q.X*q.X+(q.Z+392)^2<19*19 and p.Name~='Butterfly wing'then inPlaza[#inPlaza+1]=path(p)end end
  check('removed: the old fountain spot (south plaza, 19 studs round x = 0, z = -392) is clear of every prop (no benches round it, no spouts, no pack, no ripples)',#inPlaza==0,first(inPlaza))
  check('removed: no fountain, ripple, seed pack, sparkle, water arc or signpost / sign board part in the whole square',#fountain==0,first(fountain))
  local sparkles=0;for _,d in ipairs(life2:GetDescendants())do if d.Name=='Fountain sparkles'then sparkles+=1 end end
  check('removed: no fountain sparkles emitter, ctx.Fountain / ctx.Signs / ApplySigns gone',sparkles==0 and api3.State.Ctx.Fountain==nil and api3.State.Ctx.Signs==nil and api3.ApplySigns==nil)
  local spurPots={};for _,p in ipairs(cp)do if p.Name=='Topiary pot'then local q=p._props.CFrame.Position;if math.abs(math.abs(q.X)-131)<.01 or math.abs(q.Z+420.4)<.01 then spurPots[#spurPots+1]=path(p)end end end
  check('removed: no potted topiary guarding a base spur\'s street end',#spurPots==0,first(spurPots))
  check('removed: the layout has no bench (the four round the fountain went in R152, the nooks\' in R153, the other four and every flower bed in the R154 tidy: HubLifeArt151.Tidy) and the 12 lamps and the bunting between them stay',#Art.Layout.benches==0 and #Art.Layout.beds==0 and #Art.Layout.lamps==12 and #Art.Layout.bunting==5 and #Art.Full.benches==4 and #Art.Full.beds==10 and #Art.Full.lamps==26,#Art.Layout.benches..'/'..#Art.Layout.beds..'/'..#Art.Layout.lamps)
  -- the free Void Pack pedestal's plaza: a plain 18-stud circle round (0, -392) (Kit.Open): no tree, bush, bed, topiary, lamp, bench or sign, in the layout or built
  do local near,L={},Art.Layout
   local function chk(list,label,rad)for _,t in ipairs(list)do local x,z=t[1],t[2];if label=='tree'then x,z=t[2],t[3]end
    if x*x+(z+392)^2<(18+(rad or 0))^2 then near[#near+1]=label..' '..x..','..z end end end
   chk(L.trees,'tree',3);chk(L.bushes,'bush',2);chk(L.beds,'bed',3);chk(L.topiary,'topiary',2);chk(L.lamps,'lamp',1);chk(L.benches,'bench',4)
   local ok,why=Art.Clear(0,-392,0)
   check('plaza: the 18-stud circle round (0, -392) is kept clear for the free Void Pack pedestal (no tree, bush, bed, topiary, lamp or bench in the layout; HubLifeArt151.Clear refuses it)',
    #near==0 and ok==false and why=='open' and Kit.Open[1][3]==18,first(near))
   local built={};for _,p in ipairs(cp)do local q=p._props.CFrame.Position;if q.X*q.X+(q.Z+392)^2<18*18 and p.Name~='Butterfly wing'then built[#built+1]=p.Name end end
   for _,p in ipairs(sp)do local q=p._props.CFrame.Position;local a,b=aabb(p);if q.X*q.X+(q.Z+392)^2<18*18 and b[2]>4.5 then built[#built+1]=p.Name end end
   check('plaza: nothing built on it either - only paving (the server\'s parts there are under 4.5 studs high, the client has none)',#built==0,first(built))
  end
  local verges=0;for _,p in ipairs(cp)do if p.Name=='Verge rim'then verges+=1 end end
  check('kept: the flower verge at each of the six bases',verges==6,verges)
  sc3:Destroy()
 end
 -- the rook gate: two chess-rook towers and a crenellated gatehouse
 local G=dec.Gate;local kids=G:GetChildren()
 for _,sx in ipairs({-1,1})do
  local function mine(name)local out={};for _,p in ipairs(kids)do if p.Name==name and p._props.CFrame.Position.X*sx>0 and math.abs(math.abs(p._props.CFrame.Position.X)-99)<9 then out[#out+1]=p end end;return out end
  local bases={};for i=1,3 do bases[i]=mine('Gate base '..i)[1]end
  local shafts=mine('Gate tower');table.sort(shafts,function(a,b)return a._props.CFrame.Position.Y<b._props.CFrame.Position.Y end)
  local ring,collar,flare,crown=mine('Gate tower ring')[1],mine('Gate collar')[1],mine('Gate flare')[1],mine('Gate crown')[1]
  local ms=mine('Gate merlon')
  local tag='rook '..(sx<0 and'west'or'east')..': '
  check(tag..'a wide round stepped base (3 steps, 17.4 / 16.2 / 15.2, each narrower than the one under it)',bases[1]and bases[2]and bases[3]and bases[1]._props.Size.Y>bases[2]._props.Size.Y and bases[2]._props.Size.Y>bases[3]._props.Size.Y and bases[1]._props.Size.Y>=17)
  check(tag..'a round shaft that tapers (two stacked cylinders, 14.4 then 13, both colliding)',#shafts==2 and shafts[1]._props.Size.Y>shafts[2]._props.Size.Y and shafts[1]._props.CanCollide and shafts[2]._props.CanCollide)
  check(tag..'a gold ring, a collar, a flared crown (collar < flare < crown, the crown wider than the upper shaft)',ring~=nil and collar~=nil and flare~=nil and crown~=nil and collar._props.Size.Y<flare._props.Size.Y and flare._props.Size.Y<crown._props.Size.Y and crown._props.Size.Y>shafts[2]._props.Size.Y+3)
  local okM,why=#ms==8,#ms
  local crownTop=crown and select(2,aabb(crown))[2]or 0;local angs={};local cx,cz=crown._props.CFrame.Position.X,crown._props.CFrame.Position.Z
  for _,m in ipairs(ms)do local q=m._props.CFrame.Position;local sz=m._props.Size
   local r=math.sqrt((q.X-cx)^2+(q.Z-cz)^2);local a,b=aabb(m)
   if math.abs(sz.X-sz.Z)>1e-6 or math.abs(a[2]-crownTop)>1e-6 or r<5 or r>8 or math.sqrt((r+sz.Z/2)^2+(sz.X/2)^2)>crown._props.Size.Y/2+.01 then okM=false;why=path(m)end
   angs[#angs+1]=math.deg(math.atan2(q.Z-cz,q.X-cx))%360 end
  table.sort(angs);local even=#angs==8;for i=1,#angs do local d=(angs[i%#angs+1]-angs[i])%360;if math.abs(d-45)>.5 then even=false end end
  check(tag..'eight square merlons round the crown\'s rim, 45 degrees apart, on its top, inside its edge',okM and even,why)
 end
 do local wall=G['Gatehouse wall'];local a,b=aabb(wall)
  check('gate: a crenellated gatehouse wall spans between the rooks (its ends inside both shafts, over the whole 182-stud opening)',a[1]<=-95 and b[1]>=95 and b[2]-a[2]>=14)
  local gm,km={},{};for _,p in ipairs(kids)do if p.Name=='Gatehouse merlon'then gm[#gm+1]=p elseif p.Name=='Gatehouse keep merlon'then km[#km+1]=p end end
  local okS=true;local gx={}
  for _,p in ipairs(gm)do local sz=p._props.Size;if math.abs(sz.X-B.Size)>1e-6 or math.abs(sz.Y-B.Height)>1e-6 then okS=false end;gx[#gx+1]=p._props.CFrame.Position.X end
  local kx={};for _,p in ipairs(km)do local sz=p._props.Size;if math.abs(sz.X-B.Size)>1e-6 or math.abs(sz.Y-B.Height)>1e-6 then okS=false end;kx[#kx+1]=p._props.CFrame.Position.X end
  table.sort(gx);table.sort(kx)
  local evenG=#gx==12;for i=2,#gx do if gx[i]>0 and gx[i-1]>0 or gx[i]<0 and gx[i-1]<0 then if math.abs(gx[i]-gx[i-1]-10)>1e-6 then evenG=false end end end
  for i=2,#kx do if math.abs(kx[i]-kx[i-1]-10)>1e-6 then evenG=false end end
  check('gate: '..#gm..' + '..#km..' gatehouse merlons (12 on the wall, 5 on the keep), the wall\'s merlon size, on the same 10-stud rhythm',#gm==12 and #km==5 and okS and evenG,#gm..' '..#km)
  local rookTop=select(2,aabb(G['Gate merlon']))[2];local keepTop=0;for _,p in ipairs(km)do keepTop=math.max(keepTop,select(2,aabb(p))[2])end
  check('gate: the rook towers are the tallest part (merlon tops '..rookTop..' over the keep\'s '..keepTop..' over the wall\'s 57)',rookTop>keepTop and keepTop>WALL_TOP+B.Height)
  local sign=G['Gate sign'];local sa,sb=aabb(sign)
  check('gate: the "THE TRACK" sign sits on the gatehouse keep, readable from the hub (front face, text THE TRACK)',sign.HubText and sign.HubText.Line1.Text=='THE TRACK'and sa[1]>=-26 and sb[1]<=26 and sa[2]>=WALL_TOP+8 and G['Gate sign frame']~=nil)
  local nkeys=0;for _,k in ipairs(kids)do if k:GetAttribute('R151Stage')then nkeys+=1 end end
  check('gate: the seven biome speed keys stay on the gatehouse',nkeys==7)
 end
end

-- 17. R153: the garden spurs are plain cobblestone (no welcome mats, no base-coloured ground strips); the street curbs meet them flush ------------
-- (owner: "remove the ground design for the side gardens")
do
 local Kit=W.module('HubDecorKit151')
 -- six saturated base colours (purple first; the game's BaseService sets them, the mock has none), then a fresh Apply
 local palette={{150,60,200},{230,60,60},{60,140,230},{240,170,40},{40,190,110},{230,90,170}}
 for i,r in pairs(records)do r.Model:SetAttribute('BaseColor',R.Color3.fromRGB(table.unpack(palette[i])))end
 dec=server('HubDecor151').Apply(map)
 local pp=partsUnder(dec.Paths)
 local function rgb(c)return{c.R*255,c.G*255,c.B*255}end
 local function same(c,t)return math.abs(c[1]-t[1])<1.5 and math.abs(c[2]-t[2])<1.5 and math.abs(c[3]-t[3])<1.5 end
 local mats={};for _,p in ipairs(partsUnder(dec))do if p.Name:find('[Mm]at$')or p.Name:find('[Mm]at ')or p.Name:find('[Ww]elcome')then mats[#mats+1]=path(p)end end
 check('removed: no welcome mat (nor any "mat" part) in the server folder, none in the kit',#mats==0 and Kit.Mats==nil and Kit.WelcomeMat==nil,first(mats))
 -- no flat thing on the paving (top under 4.5) in a base's colour, whatever it is called
 local cols={};for _,r in pairs(records)do local c=r.Model:GetAttribute('BaseColor');if R.typeof(c)=='Color3'then cols[#cols+1]=rgb(c)end end
 local tinted={}
 for _,p in ipairs(pp)do local _,b=aabb(p);if b[2]<4.5 then for k,c in ipairs(cols)do if same(rgb(p._props.Color),c)then tinted[#tinted+1]=path(p)end end end end
 check('removed: no ground part in a base colour ('..#cols..' base colours): no coloured curb, strip or disc at any garden',#cols==6 and #tinted==0,first(tinted))
 -- every curb is neutral cream, bar the 4 themed garden-walk edgings (gold east, brick west: on the garden walks, not at a spur)
 local odd,edging={},0
 for _,p in ipairs(pp)do if p.Name=='Curb'then
  local q=p._props.CFrame.Position
  if same(rgb(p._props.Color),Kit.P.Cream)then elseif math.abs(math.abs(q.Z+269)-7.6)<.01 then edging+=1 else odd[#odd+1]=path(p)end
 end end
 check('curbs: all neutral cream, apart from the 4 garden-walk edgings ('..edging..')',#odd==0 and edging==4,first(odd))
 -- the six spurs: plain street-coloured cobblestone, with nothing laid on them or along their sides
 local plain,why=true,nil;local spurs={}
 for i=1,6 do local sp=dec.Paths:FindFirstChild('Base spur '..i);spurs[i]=sp
  if not sp or sp._props.Material.Name~='Cobblestone'or not same(rgb(sp._props.Color),Kit.P.Street)then plain=false;why='Base spur '..i end end
 check('spurs: six base spurs, each plain street-coloured cobblestone',plain,why)
 local clutter={}
 for i=1,6 do local sp=spurs[i];if sp then local a,b=aabb(sp)
  for _,p in ipairs(pp)do if p~=sp then local c,d=aabb(p)
   if d[1]>a[1]-1 and c[1]<b[1]+1 and d[3]>a[3]-1 and c[3]<b[3]+1 then -- within a stud of the spur
    local q=p._props.CFrame.Position
    local street=p.Name:find(' street$')~=nil or p.Name=='Garden walk'or p.Name=='Corner circle' -- what the spur joins
    local endCurb=p.Name=='Curb'and same(rgb(p._props.Color),Kit.P.Cream)and(math.abs(math.abs(q.X)-127.3)<.01 or math.abs(q.Z+418.3)<.01) -- the street's cream curb butting against its end
    if not street and not endCurb then clutter[#clutter+1]='spur '..i..': '..path(p)end
   end
  end end
 end end
 check('spurs: nothing laid on or beside a spur (no mat, no coloured curb; only the street\'s cream curb butts against its ends)',#clutter==0,first(clutter))
 -- no gap: along the side street's outer edge and the south street's south edge the cream curbs, the spurs and the garden walk leave no bare lawn
 local function covered(axis,lo,hi,fix,fixV) -- is [lo, hi] along axis covered by curbs on the line fix = fixV, spurs and garden walks?
  local iv={}
  for _,p in ipairs(pp)do local a,b=aabb(p)
   if p.Name:find('^Base spur')or p.Name=='Garden walk'or(p.Name=='Curb'and math.abs((a[fix]+b[fix])/2-fixV)<.4)then iv[#iv+1]={a[axis],b[axis]}end end
  table.sort(iv,function(x,y)return x[1]<y[1]end)
  local at=lo
  for _,v in ipairs(iv)do if v[1]<=at+1e-3 then at=math.max(at,v[2])elseif v[1]<hi then break end end
  return at>=hi-1e-3,at
 end
 local gaps={}
 for _,sx in ipairs({-1,1})do
  local ok,at=covered(3,-399,-195.534,1,sx*127.3);if not ok then gaps[#gaps+1]='side street '..sx..' outer edge: bare from z='..at end
  local ok2,at2=covered(1,sx>0 and 6.6 or-106,sx>0 and 106 or-6.6,3,-418.3);if not ok2 then gaps[#gaps+1]='south street edge '..sx..': bare from x='..at2 end
 end
 check('no gaps: the street curbs meet every spur flush (no bare lawn between a curb end and a spur)',#gaps==0,first(gaps))
end

-- 18. R154: the tidy (owner: "reduce the amount of lamps and remove the soil beds and benches ... just leave those parts empty. basically just tidy up the base area"; then "the bushes and
-- flags can stay"). HubLifeArt151.Tidy is the one table of what the square keeps; A.Full is everything it had, A.Layout is what is built. ------------------------------------------------
do
 local Art=W.module('HubLifeArt151');local T=Art.Tidy
 local function names(root)local by={};for _,p in ipairs(partsUnder(root))do by[p.Name]=(by[p.Name]or 0)+1 end;return by end
 local function xz(p)local q=p._props.CFrame.Position;return math.floor(q.X*10+.5)/10,math.floor(q.Z*10+.5)/10 end
 budget.Tier=3;local api4,sc4=load();tick(1);local life4=W.workspace:FindFirstChild('HubLife151')
 api4.Near.detail=1e6;api4.Near.fine=1e6;api4.ApplyLod()
 local by=names(life4);local ctx4=api4.State.Ctx
 -- the table
 local same=true;for _,k in ipairs({'trees','bushes','topiary','patches','butterflies'})do if #Art.Layout[k]~=#Art.Full[k]then same=false end end
 check('tidy: the table: no beds, no benches, no pebbles, 12 of the 26 lamps; the trees (24), bushes (16), topiary (8), grass patches (14) and butterflies (12) are exactly the full layout\'s (the owner: "the bushes and flags can stay")',
  T.Beds==false and T.Benches==false and T.Pebbles==false and #T.Lamps==12 and #Art.Full.lamps==26 and same and #Art.Full.trees==24 and #Art.Full.bushes==16 and #Art.Full.topiary==8 and #Art.Full.patches==14,#T.Lamps)
 check('tidy: the layout: 12 lamps (all 8 that carry a real light and the 4 that hold the candy bunting), no bed, no bench; the 6 bunting strings of the full layout are 5 (the avenue\'s two crossing ones, which hung from the two lower posts that went, are one string between the two that stay)',
  #Art.Layout.lamps==12 and #Art.Layout.beds==0 and #Art.Layout.benches==0 and #Art.Full.bunting==6 and #Art.Layout.bunting==5,#Art.Layout.lamps..'/'..#Art.Layout.bunting)
 local litFull,litKept=0,0
 for _,l in ipairs(Art.Full.lamps)do if l[4]then litFull+=1 end end
 for _,l in ipairs(Art.Layout.lamps)do if l[4]then litKept+=1 end end
 check('tidy: every lit lamp stays (8 of 8: the real lights, their tier caps and the mirror pairs are unchanged)',litFull==8 and litKept==8 and #ctx4.Lights==8,litKept)
 -- built: nothing of what went
 local gone={}
 for _,n in ipairs({'Bed rim','Bed soil','Flower','Flower stem','Bench seat','Bench back','Bench leg','Bench knob','Bench slab','Bench block','Pebble','Bollard'})do if by[n]then gone[#gone+1]=n..' x'..by[n]end end
 check('tidy: built: no bed, flower, bench, pebble or bollard part is left anywhere on the square',#gone==0,first(gone))
 -- built: the lamps are whole: no base without its pole, no head without its cap (nothing floats, nothing is left standing alone)
 local bases,collars,poles={}, {}, {}
 for _,p in ipairs(partsUnder(life4))do local x,z=xz(p);local k=string.format('%.1f,%.1f',x,z)
  if p.Name=='Lamp base'then bases[k]=(bases[k]or 0)+1 elseif p.Name=='Lamp collar'then collars[k]=(collars[k]or 0)+1 elseif p.Name=='Lamp pole'then poles[k]=(poles[k]or 0)+1 end end
 local nb,mismatch=0,{}
 for k,n in pairs(bases)do nb+=n;if poles[k]~=n or collars[k]~=n then mismatch[#mismatch+1]='base at '..k end end
 for k in pairs(poles)do if not bases[k]then mismatch[#mismatch+1]='pole at '..k end end
 local want={};for _,l in ipairs(Art.Layout.lamps)do want[string.format('%.1f,%.1f',l[1],l[2])]=true end
 for k in pairs(bases)do if not want[k]then mismatch[#mismatch+1]='unlisted lamp at '..k end end
 local wanted=0;for _ in pairs(want)do wanted+=1 end
 check('tidy: built: 12 lamp bases, each with its collar and its pole at the same spot (no base without a post, no post without a base), each standing at a layout lamp',nb==12 and wanted==12 and #mismatch==0 and by['Lamp pole']==12 and by['Lamp base']==12,first(mismatch)or nb)
 local heads,caps,arms=by['Lamp lantern']or 0,by['Lamp cap']or 0,by['Lamp arm']or 0
 local loose={}
 for _,p in ipairs(partsUnder(life4))do if p.Name=='Lamp lantern'then
  local x,z=p._props.CFrame.Position.X,p._props.CFrame.Position.Z;local near=false
  for _,l in ipairs(Art.Layout.lamps)do if (x-l[1])^2+(z-l[2])^2<=3.1^2 then near=true end end
  if not near then loose[#loose+1]=path(p)end
 end end
 check('tidy: built: 16 lamp heads (8 posts + 4 doubles x 2), each with a cap, 4 arms, and every head within 3 studs of a layout lamp (none floating alone)',heads==16 and caps==16 and arms==4 and #loose==0 and #ctx4.Heads==16,first(loose)or(heads..'/'..caps..'/'..arms))
 -- the lights and the bunting still find their lamps
 local badLight=0;for _,l in ipairs(ctx4.Lights)do local at=ctx4.LightAt[l];local ok=false;for _,k in ipairs(Art.Layout.lamps)do if k[4]and math.abs(at[1]-k[1])<.01 and math.abs(at[2]-k[2])<.01 then ok=true end end;if not ok or not l.Parent or l.Parent.Name~='Lamp lantern'then badLight+=1 end end
 check('tidy: the lighting script still finds its lamps: 8 real lights, each on a lamp head at a kept lit lamp, 16 heads in ctx.Heads (all neon), in mirror pairs',badLight==0 and #ctx4.Lights==8 and #ctx4.Heads==16,badLight)
 local lines,pennants=by['Bunting line']or 0,by['Pennant']or 0
 local hungOk=true
 for _,b in ipairs(Art.Layout.bunting)do for _,e in ipairs({b[1],b[2]})do
  for _,l in ipairs(Art.Full.lamps)do if math.abs(l[1]-e[1])<.01 and math.abs(l[2]-e[3])<.01 and not want[string.format('%.1f,%.1f',l[1],l[2])]then hungOk=false end end
 end end
 check('tidy: the flags stay and hang from lamps that stay: 5 strings of bunting built ('..lines..' lines, '..pennants..' pennants), none from a lamp that went',lines==5 and pennants>20 and hungOk,lines..' / '..pennants)
 check('tidy: nothing else changed on the square: 24 trees, the bushes, topiary pots and grass patches are all built',(by['Grass patch']or 0)>=14 and (by['Topiary pot']or 0)>=8 and (by['Bush']or 0)>=16)
 sc4:Destroy()
 -- the table is the knob: every kind comes back by flipping its value (the full layout), then the tidy is put back
 local root=R.new('Folder');root.Name='TidyBack';root.Parent=W.workspace
 local total={}
 for _,t in ipairs({1,2,3})do
  local fa=R.new('Folder');fa.Name='TidyAfter'..t;fa.Parent=root
  local after=Art.Build(fa,t,{},{});local a=after.Counts.core+after.Counts.detail+after.Counts.fine
  Art.SetTidy({Beds=true,Benches=true,Pebbles=true,Lamps=true})
  local full=R.new('Folder');full.Name='TidyFull'..t;full.Parent=root
  local before=Art.Build(full,t,{},{});local b=before.Counts.core+before.Counts.detail+before.Counts.fine
  if t==3 then
   local nm=names(full)
   check('tidy: flipping the table back brings every kind back: 26 lamps (22 posts and 4 bollards), 4 benches, 10 beds, the pebbles (A.Full)',#Art.Layout.lamps==26 and #Art.Layout.benches==4 and #Art.Layout.beds==10 and nm['Lamp pole']==22 and (nm['Bench seat']or 0)==4 and (nm['Bed rim']or 0)==10 and (nm['Pebble']or 0)>0,
    #Art.Layout.lamps..'/'..tostring(nm['Lamp pole'])..'/'..tostring(nm['Bench seat'])..'/'..tostring(nm['Bed rim']))
  end
  Art.SetTidy()
  total[t]={Before=b,After=a}
  print(string.format('BUDGET tidy tier %d: %d parts with everything (A.Full), %d after the tidy (%d fewer)',t,b,a,b-a))
 end
 check('tidy: the part counts fall on every tier (the numbers above): tier 1 '..total[1].Before..' -> '..total[1].After..', tier 2 '..total[2].Before..' -> '..total[2].After..', tier 3 '..total[3].Before..' -> '..total[3].After,
  total[1].After<total[1].Before and total[2].After<total[2].Before and total[3].After<total[3].Before and #Art.Layout.lamps==12 and #Art.Layout.beds==0)
 root:Destroy()
end

print(string.format('R151 base area: %d passed, %d failed',passed,failed))
if failed>0 then error('R151 base area: '..failed..' failed')end
