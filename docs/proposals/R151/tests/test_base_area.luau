--!nocheck
-- R151 Seed Festival Square: checks of the REAL code (ChestChaseServer.HubDecor151 run by MapService.new, ReplicatedStorage.HubLifeArt151,
-- StarterPlayerScripts.HubLife151.client) on the owner's place (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py) in the R149
-- Roblox mock, after the real start-up builders (treadmills, fences, mystery pedestals, Verity, leaderboards). Prints "ok <name>" /
-- "FAIL <name>: why" and "BUDGET ..." lines; errors at the end if anything failed.
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
end

-- 2. server parts: anchored, untouchable, unqueryable; only the gate towers collide ----------------------------------------------------------
local serverParts=partsUnder(dec)
do local bad,coll={},0
 for _,p in ipairs(serverParts)do
  if p._props.Anchored~=true or p._props.CanTouch~=false or p._props.CanQuery~=false then bad[#bad+1]=path(p)end
  if p._props.CanCollide then coll+=1;if p.Name~='Gate tower'then bad[#bad+1]='collides: '..path(p)end end
 end
 check('server: every part anchored, CanTouch / CanQuery off',#bad==0,first(bad))
 check('server: only the two gate towers collide',coll==2,coll)
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
-- arch and gate clearances
do local ok,why=true,nil
 for i,r in pairs(records)do local arch=dec.BaseEntrances:FindFirstChild('Base'..i..'Arch');local trim=arch and arch:FindFirstChild('Arch beam trim')
  local padTop=r.Pad._props.CFrame.Position.Y+r.Pad._props.Size.Y/2
  local lo=trim and select(1,aabb(trim))
  if not lo or lo[2]-padTop<14 then ok=false;why='Base'..i end
 end
 check('clearance: every base arch is at least 14 studs over its pad',ok,why)
 local beamLo=select(1,boxOf(dec.Gate['Arch trim']));check('clearance: the gate beam\'s lowest trim is 39.5 studs over the floor',beamLo[2]-4>=39.5,beamLo[2])
 local keyLo=math.huge;for _,k in ipairs(dec.Gate:GetChildren())do if k:GetAttribute('R151Stage')then keyLo=math.min(keyLo,select(1,aabb(k))[2])end end
 check('clearance: the gate keys hang 38 studs over the floor',keyLo-4>=38,keyLo)
 local towersOk=true;for _,t in ipairs(dec.Gate:GetChildren())do if t.Name=='Gate tower'then local a,b=aabb(t);if math.min(math.abs(a[1]),math.abs(b[1]))<90.9 then towersOk=false end end end
 check('clearance: the gate towers stay outside the 180-wide run-up and track (|x| > 90.9)',towersOk)
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

-- 5. server: re-Apply is idempotent; the arch beams follow the owners -------------------------------------------------------------------------
do
 local n0=#serverParts
 local H=server('HubDecor151')
 local dec2=H.Apply(map)
 local count=0;for _,c in ipairs(map:GetChildren())do if c.Name=='HubDecor151'then count+=1 end end
 check('server: Apply twice leaves one HubDecor151 with the same parts',count==1 and #partsUnder(dec2)==n0,#partsUnder(dec2)..' vs '..n0)
 local w=map.ChestChaseWalls.LobbyBackWall
 check('server: the walls\' original colour survives a second Apply',w:GetAttribute('R151OldColor')==savedWalls.LobbyBackWall.Color)
 dec=dec2
 records[1].Model:SetAttribute('BaseOwnerDisplayName','Ben')
 local beam=dec.BaseEntrances.Base1Arch['Arch name beam']
 check('server: the arch beam shows the owner ("BEN\'S BASE")',beam.OwnerName.Line1.Text=='BEN\'S BASE',beam.OwnerName.Line1.Text)
 records[1].Model:SetAttribute('BaseOwnerDisplayName','')
 check('server: a free base reads "FREE BASE"',beam.OwnerName.Line1.Text=='FREE BASE',beam.OwnerName.Line1.Text)
 records[1].Model:SetAttribute('BaseOwnerDisplayName','Ben');records[3].Model:SetAttribute('BaseOwnerDisplayName','Leo')
 local server1=0;for _,p in ipairs(partsUnder(dec))do server1+=1 end
 print(string.format('BUDGET server (Phase 1) parts %d',server1))
 check('budget: server (Phase 1) parts <= 800',server1<=800,server1)
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
 check('variety: at least 15 tree kinds / sizes / colours',n>=15,n)
 local crowns={};local dup=0
 for _,p in ipairs(clientParts)do if p.Name=='Tree crown'or p.Name=='Blossom crown'then local key=string.format('%.2f|%.2f|%d,%d,%d',p._props.Size.X,p._props.CFrame.Position.Y%10,math.floor(p._props.Color.R*255),math.floor(p._props.Color.G*255),math.floor(p._props.Color.B*255))
  if crowns[key]then dup+=1 end;crowns[key]=true end end
 check('variety: no two crowns identical in size, height and shade',dup==0,dup)
 local a=W.module('HubDecorKit151').Rng('oak:M:1')();local b=W.module('HubDecorKit151').Rng('oak:M:1')()
 check('variety: deterministic per instance (same seed, same tree on every client)',a==b)
end

-- 8. detail by distance ----------------------------------------------------------------------------------------------------------------------
api.Near.detail,api.Near.fine=saveNear[1],saveNear[2]
cam.CFrame=CF(0,12,-180);api.ApplyLod();local atGate=visible(api)
cam.CFrame=CF(0,12,1200);api.ApplyLod();local onTrack=visible(api)
cam.CFrame=CF(0,12,-392);api.ApplyLod();local atFountain=visible(api)
print(string.format('BUDGET visible at the front street: core %d, detail %d, fine %d; at the fountain: core %d, detail %d, fine %d',atGate.core,atGate.detail,atGate.fine,atFountain.core,atFountain.detail,atFountain.fine))
check('lod: near the front street some detail is hidden (far cells)',atGate.detail>0 and atGate.detail<counts[3].detail)
check('lod: far down the track everything is hidden',onTrack.core==0 and onTrack.detail==0 and onTrack.fine==0)
check('lod: at the fountain its fine level shows',atFountain.fine>0)
budget.Tier=2;cam.CFrame=CF(0,12,-180);api.ApplyLod();local phone=visible(api);budget.Tier=3
print(string.format('BUDGET visible on a phone (tier 2) at the front street: core %d, detail %d, fine %d (total %d)',phone.core,phone.detail,phone.fine,phone.core+phone.detail+phone.fine))
check('lod: tier 2 (phones) shows less detail than the desktop and no fine level',phone.detail<atGate.detail and phone.fine==0)
player:SetAttribute('FastMode',true);api.ApplyLod();local fast=visible(api)
check('lod: FastMode hides detail and fine',fast.detail==0 and fast.fine==0 and fast.core>0)
player:SetAttribute('FastMode',nil);api.ApplyLod()

-- 9. ambience only when near, never with Reduced Motion -------------------------------------------------------------------------------------
cam.CFrame=CF(0,12,-392);api.ApplyLod()
check('ambience: wanted near the fountain',api.AmbienceWanted())
local bf=api.State.Ctx.Butterflies[1];for _,b in ipairs(api.State.Ctx.Butterflies)do if(b.Home-V3(0,8,-392)).Magnitude<(bf.Home-V3(0,8,-392)).Magnitude then bf=b end end
local before=bf.Left._props.CFrame.Position
api.AmbienceStep(.1);api.AmbienceStep(.1)
check('ambience: butterflies move',(bf.Left._props.CFrame.Position-before).Magnitude>0)
local emit=0;for _,pe in ipairs(api.State.Ctx.Emitters)do if pe.Enabled then emit+=1 end end
check('ambience: petals / sparkles on near the fountain',emit>0,emit)
cam.CFrame=CF(0,12,1200);api.ApplyLod()
check('ambience: off far away',not api.AmbienceWanted())
cam.CFrame=CF(0,12,-392);W.Gui.ReducedMotionEnabled=true;api.ApplyLod()
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

-- 12. signposts show the owners ---------------------------------------------------------------------------------------------------------------
do api.ApplySigns()
 local found=false;for _,s in ipairs(api.State.Ctx.Signs)do if s.Base==1 and s.Line.Text=='Ben · Leo'then found=true end end
 check('signposts: the base boards show the owners ("Ben · Leo")',found)
 records[2].Model:SetAttribute('BaseOwnerDisplayName','Mia');api.ApplySigns()
 local mia=false;for _,s in ipairs(api.State.Ctx.Signs)do if s.Base==2 and s.Line.Text:find('Mia')then mia=true end end
 check('signposts: follow owner changes',mia)
end

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

print(string.format('R151 base area: %d passed, %d failed',passed,failed))
if failed>0 then error('R151 base area: '..failed..' failed')end
