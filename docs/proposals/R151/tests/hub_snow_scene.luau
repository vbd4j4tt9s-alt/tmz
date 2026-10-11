--!nocheck
-- R151 hub snow on the OWNER'S PLACE (not a unit test on its own: run_perf.sh runs it and checks its STATS / SCENE lines, and the preview
-- renders its SCENE). Loads Workspace.ChestChaseMap (place_tree.luau from docs/proposals/R149/tools/rbxl_geom.py --tree) into the Roblox mock
-- (docs/proposals/R149/tests/zfight_world.luau), runs the REAL start-up builders like docs/proposals/R151/preview/base_area_scene.luau
-- (MapService.new, the six treadmills, the garden fences, the mystery pedestals, Verity's dais, the leaderboards) plus the R151 hub
-- displays (HubDisplayArt.BuildFrame), then the REAL WeatherWorld149.client.lua of the bundled src tree with a blizzard, the player at
-- PLAYER, for SECONDS. workspace:Raycast is a straight-down ray against every part of the scene (box / disc / ball tops, CanCollide honoured
-- with RespectCanCollide), so the snow's ground and avoid checks see the real hub.
-- Globals (set by the runner): PLAYER = {x, z}, SECONDS, TIER (ClientFxBudget), WEATHER ('Blizzard' ...), DUMP (print the SCENE line).
-- Prints "STATS {...}": snow discs drawn, drifts, disc budget, raycasts, property writes in the last 10 s, coverage of the hub floor (on a
-- 4-stud grid), the parts each snow disc overlaps that it must not (avoided things), and per-kind counts.
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
local map=Z.loadPlace(require('./place_tree'),W.workspace)
local failed=0
local function step(name,fn,...)local ok,err=pcall(fn,...);if not ok then failed+=1;print('STEP '..name..' FAILED '..tostring(err))end;return ok end
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local Config;step('Config',function()Config=server('Config')end)
local art;step('BiomeVisuals',function()art=server('BiomeVisuals')end)
step('MapService.new',function()server('MapService').new(Config);R.advance(.1)end)
local skins={1,3,1,5,2,1};local records={}
for _,base in ipairs(map.Bases:GetChildren())do if base:GetAttribute('BaseIndex')then
 local i=base:GetAttribute('BaseIndex');records[#records+1]={Index=i,Model=base,Pad=base:FindFirstChild('Pad')}
 step('Treadmill '..base.Name,function()art.BuildTreadmillV131(base,skins[i]or 1)end)
end end
table.sort(records,function(a,b)return a.Index<b.Index end)
step('GardenTypography',function()W.module('GardenTypography').Apply(map)end)
step('GardenFenceArt',function()local A=server('GardenFenceArt');for _,r in ipairs(records)do A.Build(r.Model,skins[r.Index]or 1)end end)
step('MysteryPedestal',function()local S=server('MysteryPackService');local svc=S.new(Config,{},{Map=nil},{},{},{MapRoot=map});for _,r in ipairs(records)do svc:_build(r)end end)
step('VerityDais',function()local S=server('VerityService');local svc=S.new(Config,{},{},{},{MapRoot=map,EconomyHub=map.EconomyHub});svc:_build(map.EconomyHub)end)
step('Leaderboards',function()local L=W.module('LeaderboardLandscape');for _,m in ipairs(map.EconomyHub.GeneratedHubScenery:GetChildren())do if m:GetAttribute('SceneryOwner')=='ChestChase'then L.Apply(m)end end end)
if folder:FindFirstChild('HubDisplayArt')then
 step('HubDisplays',function()
  local Art=server('HubDisplayArt');local Rules=W.module('HubDisplayRules')
  local f=R.new('Folder');f.Name='HubDisplays151';f.Parent=map
  Art.BuildFrame(f,'Pull',Rules.Layout,4);Art.BuildFrame(f,'Fruit',Rules.Layout,4)
 end)
end
R.advance(1)

-- Client ----------------------------------------------------------------------------------------------------------------------------------
Run.IsClient=function()return true end;Run.IsServer=function()return false end
local player=R.new('Player');player.Name='Tester';player.UserId=1001;player.Parent=Players;Players.LocalPlayer=player
player.CharacterAdded=R.signal();player.CharacterRemoving=R.signal()
function Players.GetPlayers()return{player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
function W.workspace.BulkMoveTo(_,parts,cfs)for i,p in ipairs(parts)do p.CFrame=cfs[i]end end
function R.Inst.Play()end;function R.Inst.Stop()end;function R.Inst.Clear()end
W.service('ContentProvider').PreloadAsync=function()end
local tier=TIER or 3
W.stub('ClientFxBudget',{Get=function()return tier end,Low=function()return tier==1 end})
local P=PLAYER or{-120,-260}
local model=R.new('Model');model.Name='Tester'
local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.Transparency=1;root.CanCollide=false;root.Parent=model
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=model;model.PrimaryPart=root;model.Parent=W.workspace;player.Character=model
root.CFrame=CF(P[1],7,P[2])
W.workspace.CurrentCamera.CFrame=CF(P[1],20,P[2]+18)
-- the R151 festival square's client layer (trees, beds, grass patches ...) when this src tree has it, every detail level shown
if RS:FindFirstChild('HubLife151Client')then step('HubLife151.client',function()
 local sc=R.new('LocalScript');sc.Name='HubLife151';sc:SetAttribute('R151TestHook',true);sc.Parent=pg
 local api=W.load('HubLife151Client',sc);assert(api,'no test hook')
 assert(api.Build(),'HubLife151 build failed')
 api.Near.detail=1e6;api.Near.fine=1e6;api.ApplyLod()
end)end

-- Straight-down raycasts against the scene: every BasePart's top over (x, z), the highest one under the origin.
local index,cell={},16
local function isUnder(o,list)for _,f in ipairs(list)do if o==f or o:IsDescendantOf(f)then return true end end;return false end
local function footprint(p)
 local cf=p._props.CFrame;local s=p._props.Size;local r=cf.R
 local hx=(math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2
 local hz=(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2
 local hy=(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2
 return cf.Position,hx,hy,hz
end
local function addIndex(p)
 local c,hx,_,hz=footprint(p)
 if c.Z-hz>300 then return end
 for i=math.floor((c.X-hx)/cell),math.floor((c.X+hx)/cell)do for j=math.floor((c.Z-hz)/cell),math.floor((c.Z+hz)/cell)do
  local k=i*100000+j;local l=index[k];if not l then l={};index[k]=l end;l[#l+1]=p
 end end
end
local snowFolderName='_WeatherWorldR149'
for _,p in ipairs(W.workspace:GetDescendants())do if p:IsA('BasePart')and p._props.CFrame and p._props.Size then addIndex(p)end end
local function topAt(p,x,z)
 local cf=p._props.CFrame;local s=p._props.Size;local r=cf.R;local c=cf.Position
 local shape=p._props.Shape;shape=shape and shape.Name or'Block'
 if p._class~='Part'and p._class~='SpawnLocation'then shape='Block'end
 if shape=='Cylinder'and math.abs(r[2][1])>.9 then -- axis (part X) upright: a disc
  local rad=math.min(s.Y,s.Z)/2;if(x-c.X)^2+(z-c.Z)^2>rad*rad then return nil end
  return c.Y+s.X/2
 elseif shape=='Ball'then
  local rad=s.X/2;local d2=(x-c.X)^2+(z-c.Z)^2;if d2>rad*rad then return nil end
  return c.Y+math.sqrt(rad*rad-d2)
 end
 if math.abs(r[2][2])>.98 then -- upright box: its own footprint
  local ux,uz=r[1][1],r[3][1];local dx,dz=x-c.X,z-c.Z
  local lx,lz=dx*ux+dz*uz,-dx*uz+dz*ux
  if math.abs(lx)>s.X/2 or math.abs(lz)>s.Z/2 then return nil end
  return c.Y+s.Y/2
 end
 local _,hx,hy,hz=footprint(p)
 if math.abs(x-c.X)>hx or math.abs(z-c.Z)>hz then return nil end
 return c.Y+hy
end
local rays=0
function W.workspace.Raycast(_,origin,dir,params)
 rays+=1
 if math.abs(dir.X)>1e-6 or math.abs(dir.Z)>1e-6 or dir.Y>=0 then return nil end
 local list=index[math.floor(origin.X/cell)*100000+math.floor(origin.Z/cell)];if not list then return nil end
 local filter=params and params.FilterDescendantsInstances or{}
 local respect=params and params.RespectCanCollide==true
 local best,bestY=nil,-math.huge
 for _,p in ipairs(list)do
  if p._parent and p._props.CanQuery~=false and not(respect and p._props.CanCollide==false)then
   local y=topAt(p,origin.X,origin.Z)
   if y and y<=origin.Y and y>=origin.Y+dir.Y and y>bestY and not isUnder(p,filter)then best,bestY=p,y end
  end
 end
 if not best then return nil end
 return{Position=V3(origin.X,bestY,origin.Z),Normal=V3(0,1,0),Instance=best}
end
W.env.RaycastParams={new=function()return{}end}

-- property writes (the last 10 s), by class.property; weatherWrites = the ones on the weather client's own folder (snow discs, emitters)
local counting,writes,byKey,wWrites=false,0,{},0
do local meta=R.instMeta;local nidx=meta.__newindex
 meta.__newindex=function(o,k,v)
  if counting and k~='Parent'then writes+=1;local key=o._class..'.'..k;byKey[key]=(byKey[key]or 0)+1
   local a=o;while a do if a._props.Name==snowFolderName then wWrites+=1;break end;a=a._parent end
  end
  return nidx(o,k,v)
 end
end
RS:SetAttribute('GlobalWeather',WEATHER or'Blizzard')
local sc=R.new('LocalScript');sc.Name='WeatherWorld149';sc:SetAttribute('R151TestHook',true);local hook=W.load('WeatherWorld',sc)
local total=SECONDS or 30
local created0=#R.created
W.frames(math.floor((total-10)*60),1/60)
local r0=rays;counting=true
W.frames(600,1/60)
counting=false

-- Stats ---------------------------------------------------------------------------------------------------------------------------------
local wf=W.workspace:FindFirstChild(snowFolderName);local pf=wf and wf:FindFirstChild('Snow patches')
local discs={};if pf then for _,d in ipairs(pf:GetChildren())do if d._props.Transparency<1 then discs[#discs+1]=d end end end
local made=pf and #pf:GetChildren()or 0
-- coverage of the hub floor (x -335..335, z -618..-104) on a 4-stud grid, and of the open hub (not on a base pad)
local function covered(x,z)
 for _,d in ipairs(discs)do
  local c=d._props.CFrame;local p=c.Position;local s=d._props.Size
  local dx,dz=x-p.X,z-p.Z
  if math.abs(dx)<math.max(s.Y,s.Z)/2 and math.abs(dz)<math.max(s.Y,s.Z)/2 then
   local look=c.LookVector;local up=c.UpVector -- (the disc's own Z axis lies along -LookVector, its Y axis along UpVector, both horizontal)
   local u=dx*(-look.X)+dz*(-look.Z);local v=dx*up.X+dz*up.Z
   if(u/(s.Z/2))^2+(v/(s.Y/2))^2<=1 then return true end
  end
 end
 return false
end
local cov,cells=0,0
local zones={}
for x=-333,333,4 do for z=-616,-106,4 do
 cells+=1
 if covered(x,z)then cov+=1
  local zx=math.floor((x+335)/224);local zz=math.floor((z+618)/172)
  zones[zx*10+zz]=(zones[zx*10+zz]or 0)+1
 end
end end
local zoneCount=0;for _ in pairs(zones)do zoneCount+=1 end
-- discs over things they must not cover: a disc whose ellipse overlaps (in plan) a part of an avoided group and lies above its top
local bad={}
local avoidPaths={'GardenPlots','GardenDesign','TreadmillArt','MysteryPedestal','MerchantStands','VerityNPC','HubDisplays151','GeneratedHubScenery','SafeZonePresentation','BaseBoundaryLine'}
local function groupOf(p)local path=Z.path(p);for _,g in ipairs(avoidPaths)do if path:find(g,1,true)then return g end end;return nil end
for _,d in ipairs(discs)do
 local c=d._props.CFrame.Position;local s=d._props.Size;local rr=math.max(s.Y,s.Z)/2;local top=c.Y+s.X/2
 for i=math.floor((c.X-rr)/cell),math.floor((c.X+rr)/cell)do for j=math.floor((c.Z-rr)/cell),math.floor((c.Z+rr)/cell)do
  for _,p in ipairs(index[i*100000+j]or{})do
   local g=groupOf(p)
   if g and(p._props.Transparency or 0)<1 then
    -- sample the disc on a 1-stud grid: any point inside the ellipse over this part, with the part's top under the disc's top
    for x=c.X-rr,c.X+rr,1 do for z=c.Z-rr,c.Z+rr,1 do
     local y=topAt(p,x,z)
     if y and y<top then
      local look=d._props.CFrame.LookVector;local up=d._props.CFrame.UpVector;local dx,dz=x-c.X,z-c.Z
      local u=dx*(-look.X)+dz*(-look.Z);local v=dx*up.X+dz*up.Z
      if(u/(s.Z/2))^2+(v/(s.Y/2))^2<=1 then bad[g]=(bad[g]or 0)+1;break end
     end
    end end
   end
  end
 end end
end
local badList={};for g,n in pairs(bad)do badList[#badList+1]=string.format('"%s":%d',g,n)end
local keys={};for k,n in pairs(byKey)do keys[#keys+1]=string.format('"%s":%d',k,n)end;table.sort(keys)
-- per kind: drifts in the layout / ok / avoided / below the tier / pending, and the scales used (R151 client hook only)
if type(hook)=='table'and hook.Layout then
 local L=hook.Layout();local per={}
 for k=1,L.N do local s=L[k];local e=per[s.Kind]or{n=0,ok=0,av=0,tier=0,pend=0,un=0,small=0};per[s.Kind]=e
  e.n+=1;local st=hook.Stat[k]
  if st==1 then e.ok+=1;if(hook.Scale[k]or 1)<1 then e.small+=1 end elseif st==3 then e.av+=1 elseif st==2 then e.tier+=1 elseif st==4 then e.pend+=1 else e.un+=1 end
 end
 local t={};for kind,e in pairs(per)do t[#t+1]=string.format('"%s":[%d,%d,%d,%d,%d,%d,%d]',kind,e.n,e.ok,e.av,e.tier,e.pend,e.un,e.small)end;table.sort(t)
 print('KINDS {'..table.concat(t,',')..'} (layout, ok, avoided, tier, pending, unchecked, smaller)')
 if DEBUG then
  local H=W.module('HubSnow151');local AB,an,AC,cn=hook.Avoid()
  for k=1,L.N do local s=L[k]
   if hook.Stat[k]~=1 and s.Kind~='inner'then
    local why='ground'
    local sc=.5;local t={X=s.X,Z=s.Z,N=1,LX={s.LX[1]*sc},LZ={s.LZ[1]*sc},LA={s.LA[1]*sc},LB={s.LB[1]*sc},LY={s.LY[1]}}
    for i=0,(an-1)*6,6 do if H.LobeHitsBox(t,1,1,AB[i+1],AB[i+2],AB[i+3],AB[i+4],AB[i+5],AB[i+6])then why=string.format('box(%.0f,%.0f %.0fx%.0f)',AB[i+1],AB[i+2],AB[i+3],AB[i+4]);break end end
    for i=1,cn*3,3 do if H.LobeHitsCircle(t,1,1,AC[i],AC[i+1],AC[i+2])then why=string.format('circle(%.0f,%.0f r%.0f)',AC[i],AC[i+1],AC[i+2]);break end end
    print(string.format('DEBUG %s (%.0f,%.0f) stat %s %s',s.Kind,s.X,s.Z,tostring(hook.Stat[k]),why))
   end
  end
 end
end
-- particles: live drops / splash particles (rate x mean lifetime of every enabled emitter), emitters on, parts in the weather folder
local drops,splash,emOn,wparts=0,0,0,0
if wf then for _,o in ipairs(wf:GetDescendants())do
 if o._class=='ParticleEmitter'and o._props.Enabled==true and(o._props.Rate or 0)>0 then
  emOn+=1;local l=o._props.Lifetime;local live=o._props.Rate*(l.Min+l.Max)/2
  if o._props.Name=='Precipitation'then drops+=live else splash+=live end
 elseif o:IsA('BasePart')then wparts+=1 end
end end
print(string.format('PARTICLES {"weather":"%s","tier":%d,"drops":%.0f,"splash":%.0f,"emittersOn":%d,"weatherParts":%d}',WEATHER or'Blizzard',tier,drops,splash,emOn,wparts))
print(string.format('STATS {"budget":%d,"tier":%d,"player":[%d,%d],"discs":%d,"made":%d,"created":%d,"rays10s":%d,"writes10s":%d,"weatherWrites10s":%d,"coverage":%.4f,"zones":%d,"bad":{%s},"writes":{%s},"failed":%d}',
 (type(hook)=="table"and hook.HubCfg and hook.HubCfg().Discs)or 0,tier,P[1],P[2],#discs,made,#R.created-created0,rays-r0,writes,wWrites,cov/cells,zoneCount,table.concat(badList,','),table.concat(keys,','),failed))
if DUMP then
 local function areaOf(p)
  local path=Z.path(p)
  if path:find(snowFolderName,1,true)then return'snow'end
  if path:find('/Bases/',1,true)then return'bases'end
  if path:find('/EconomyHub/',1,true)then return'hub'end
  if path:find('/Lobby/',1,true)or path:find('ChestChaseWalls',1,true)or path:find('GardenHubDesign',1,true)then return'lobby'end
  if path:find('HubDisplays151',1,true)then return'displays'end
  if path:find('HubDecor151',1,true)then return'decor'end
  if path:find('HubLife151',1,true)then return'life'end
  return'track'
 end
 local parts=Z.dump(W.workspace,areaOf)
 local keep={}
 for _,s in ipairs(parts)do if not s:find('"area":"track"',1,true)then keep[#keep+1]=s end end
 print('SCENE {"playable":[[-340,-623,340,-99]],"parts":['..table.concat(keep,',')..'],"guis":[],"lights":[],"emitters":[]}')
end
