--!nocheck
-- R158 boot: MapService.new must never wait for an asset request (the R153 boot rule: asset loads are spawned; players are set up right after the map). Code review of the walls
-- build: LavaVolcano158.Apply asked for the owner's volcano on the boot thread: the mesh (up to OuterTrackAssets158.LoadSeconds = 8 s), then asset 5138892863 through
-- AssetService:LoadAssetAsync (8 s) and InsertService:LoadAsset (8 s): about 24 s with Roblox's asset requests hanging, before anyone was set up.
-- The mock's task.wait does not yield (it moves the clock and returns), so a spawned thread would run to its end at once. Here task is Roblox's: task.spawn starts a thread that runs until
-- its first task.wait, which parks it (a clock to wake it) and gives control back; the main thread's task.wait moves the clock and wakes whoever is due.
-- Usage: luau run.luau with MODE='hang' or MODE='arrive' on the first line (run_walls158.sh writes it in front of this file):
--   hang    every asset request (CreateMeshPartAsync, LoadAssetAsync, LoadAsset) never answers: MapService.new returns at once (no wait), the lava streams are gone, the old cone is still
--           there, the keyboard's skip scan has run on it; each request is made ONCE (the volcano's swap and the background loader share the in-flight request, they do not both ask);
--           after the longest wait both give up with one plain note and the old cone stays.
--   arrive  the volcano's mesh answers 3 s later: the old cone is replaced by the owner's volcano then (one request, shared), the four outside volcanoes are placed from the same mesh.
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local MODE=MODE or'hang'
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
local printed,warned={},{}
W.env.print=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;printed[#printed+1]=table.concat(t,' ')end
local baseWarn=W.env.warn
W.env.warn=function(...)local t={};for i=1,select('#',...)do t[#t+1]=tostring((select(i,...)))end;warned[#warned+1]=table.concat(t,' ');baseWarn(...)end
-- Roblox's scheduler, as far as the loaders need it: spawn runs until the first wait; a wait inside a spawned thread parks it until the clock reaches its time
local sleepers,spawned={},{}
local function wake()
 local due,keep={},{}
 for _,s in ipairs(sleepers)do if s.at<=R.clock+1e-9 then due[#due+1]=s else keep[#keep+1]=s end end
 sleepers=keep
 for _,s in ipairs(due)do local ok,e=coroutine.resume(s.co);if not ok then print('THREAD ERROR '..tostring(e))end end
end
local function pump(dt)R.advance(dt);wake()end
W.env.task=setmetatable({
 wait=function(t)
  t=t or .03
  local co=coroutine.running()
  if not spawned[co]then pump(t) -- the main thread: the clock moves on and whoever is due wakes
  else sleepers[#sleepers+1]={co=co,at=R.clock+t};coroutine.yield()end
  return t
 end,
 spawn=function(f,...)
  local co=coroutine.create(f);spawned[co]=true
  local ok,e=coroutine.resume(co,...)
  if not ok then print('THREAD ERROR '..tostring(e))end
  return co
 end,
},{__index=R.task})
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=Z.loadPlace(require('./place_tree'),W.workspace)
for _,n in ipairs({'ChestChaseRoutesV134Backup','ChestChaseRoutePolishV136Backup'})do local f=R.new('Folder');f.Name=n;f.Parent=W.service('ServerStorage')end
local movement=R.new('ModuleScript');movement.Name='RunnerMotion';if not RS:FindFirstChild('RunnerMotion')then movement.Parent=RS end
local passed,failed=0,0
local function check(name,cond,why)
 if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end
end
local function info(s)print('INFO '..s)end
local function partsOf(root)local out={};if root:IsA('BasePart')then out[1]=root end;for _,d in ipairs(root:GetDescendants())do if d:IsA('BasePart')then out[#out+1]=d end end;return out end

-- the asset requests ---------------------------------------------------------------------------------------------------------------------------------
local VOLCANO_MESH,VOLCANO_ASSET='rbxassetid://5138886694',5138892863
local AS=W.service('AssetService');local IS=W.service('InsertService')
local calls={Mesh={},LoadAssetAsync={},LoadAsset={}}
local parked={} -- the threads of requests that have not answered
local function idOf(content)return type(content)=='table'and content.Uri or content end
AS.CreateMeshPartAsync=function(self,content,options)
 local id=idOf(content)
 local seenAt=#calls.Mesh+1
 calls.Mesh[seenAt]={Id=id,At=R.clock}
 if MODE=='arrive'and id==VOLCANO_MESH then
  parked[#parked+1]=coroutine.running()
  return coroutine.yield() -- (answered by the test below)
 end
 coroutine.yield() -- (never answers)
 return nil
end
AS.LoadAssetAsync=function(self,id)calls.LoadAssetAsync[#calls.LoadAssetAsync+1]={Id=id,At=R.clock};coroutine.yield();return nil end
IS.LoadAsset=function(self,id)calls.LoadAsset[#calls.LoadAsset+1]={Id=id,At=R.clock};coroutine.yield();return nil end
local function countOf(list,id)local n=0;for _,c in ipairs(list)do if c.Id==id then n+=1 end end;return n end

-- the real start-up on the owner's place ---------------------------------------------------------------------------------------------------------------
local Config=server('Config')
local t0=R.clock
local mapService=server('MapService').new(Config)
local waited=R.clock-t0
local Assets=server('OuterTrackAssets158');local Loader=server('OuterTrackLoader158')
local landmarks=map.MythicLandmarks
local cone=landmarks:FindFirstChild('Biome4_Landmark')
local function streams()
 local n=0
 for _,d in ipairs(map:GetDescendants())do local nm=d.Name;if nm:find('^VolcanoMagmaChannel')or nm=='MoltenCrater'or nm=='ContinuousLavaRiver'or nm=='IrregularMagmaPools'or nm:find('^LavaRiver')or nm=='Pool shore'then n+=1 end end
 return n
end
check('boot ('..MODE..'): MapService.new returned without waiting for any asset request ('..string.format('%.2f',waited)..' s of the mock clock; the old build waited about 24 s)',waited<2,waited)
check('boot ('..MODE..'): the map is built: the walls, the ground and the base caps are there, and the keyboard\'s skip scan has run (the map says which keys to leave out)',map:FindFirstChild('TrackWalls158')~=nil and map:FindFirstChild('TrackBackdrops158')~=nil and map:FindFirstChild('BaseWalls158')~=nil and map:GetAttribute('KeyboardSkip')~=nil)
check('boot ('..MODE..'): the lava streams and pools are removed already (that part does not wait)',streams()==0)
check('boot ('..MODE..'): the old cone is still standing while the owner\'s volcano is being asked for',cone~=nil and cone:GetAttribute('Volcano158')==nil and cone:FindFirstChild('BasaltSlope')~=nil)
check('boot ('..MODE..'): the volcano\'s mesh was asked for once so far (the swap and the background loader share the request)',countOf(calls.Mesh,VOLCANO_MESH)<=1,countOf(calls.Mesh,VOLCANO_MESH))

if MODE=='hang'then
 for _=1,600 do pump(.1)end -- a minute of the mock clock: every wait runs out
 check('boot (hang): after the longest wait the old cone stays for good (nothing replaced it)',landmarks:FindFirstChild('Biome4_Landmark')==cone and cone:GetAttribute('Volcano158')==nil)
 check('boot (hang): the volcano\'s mesh was asked for ONCE in all (the swap and the loader never both asked)',countOf(calls.Mesh,VOLCANO_MESH)==1,countOf(calls.Mesh,VOLCANO_MESH))
 check('boot (hang): asset 5138892863 was asked for once through AssetService and once through InsertService',countOf(calls.LoadAssetAsync,VOLCANO_ASSET)==1 and countOf(calls.LoadAsset,VOLCANO_ASSET)==1,countOf(calls.LoadAssetAsync,VOLCANO_ASSET)..' / '..countOf(calls.LoadAsset,VOLCANO_ASSET))
 local notes=0;for _,l in ipairs(printed)do if l:find('^%[R158 volcano%]')and l:find('the old cone stays',1,true)then notes+=1 end end
 check('boot (hang): ONE plain note says the old cone stays',notes==1,notes)
 local warnedOurs;for _,w in ipairs(warned)do if w:find('R158',1,true)then warnedOurs=w end end
 check('boot (hang): no warning from the R158 build',warnedOurs==nil,warnedOurs)
 local outsideVolcanoes=0;for _,m in ipairs(map.TrackBackdrops158.Lava:FindFirstChild('Models')and map.TrackBackdrops158.Lava.Models:GetChildren()or{})do if m.Name:find('^LavaVolcano')then outsideVolcanoes+=1 end end
 check('boot (hang): the four outside volcanoes are skipped the same way (nothing built in their place)',outsideVolcanoes==0)
else -- arrive
 pump(3)
 check('boot (arrive): the volcano\'s mesh request is still open after 3 s (the old cone still there)',#parked==1 and landmarks:FindFirstChild('Biome4_Landmark')==cone)
 local mp=R.new('MeshPart');mp.Name='MeshPart';mp.Size=V3(70,52.6,59.8);mp.CFrame=CF(0,0,0);mp.MeshId=VOLCANO_MESH
 local ok,e=coroutine.resume(parked[1],mp) -- the answer arrives
 if not ok then print('THREAD ERROR '..tostring(e))end
 for _=1,400 do pump(.1)end
 local new=landmarks:FindFirstChild('Biome4_Landmark')
 check('boot (arrive): when the mesh arrives the old cone is replaced by the owner\'s volcano (in the background)',new~=nil and new~=cone and new:GetAttribute('Volcano158')==true and cone._destroyed==true)
 check('boot (arrive): the mesh was asked for ONCE in all (the swap and the loader shared the request)',countOf(calls.Mesh,VOLCANO_MESH)==1,countOf(calls.Mesh,VOLCANO_MESH))
 local outsideVolcanoes=0;for _,m in ipairs(map.TrackBackdrops158.Lava:FindFirstChild('Models')and map.TrackBackdrops158.Lava.Models:GetChildren()or{})do if m.Name:find('^LavaVolcano')then outsideVolcanoes+=1 end end
 check('boot (arrive): the four outside volcanoes were placed from the same mesh ('..outsideVolcanoes..')',outsideVolcanoes==#Assets.SlotsOf('LavaVolcano'),outsideVolcanoes)
 local errs=0;for _,l in ipairs(printed)do if l:find('THREAD ERROR',1,true)then errs+=1 end end
 check('boot (arrive): no thread raised an error',errs==0,errs)
end
print('R158 boot ('..MODE..'): '..passed..' checks passed, '..failed..' failed')
if failed>0 then error('R158 boot: '..failed..' checks failed')end
