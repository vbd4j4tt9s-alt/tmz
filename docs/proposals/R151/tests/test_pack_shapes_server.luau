--!nocheck
-- R151 pack shapes, part 2: every way a pack enters the world, on the Roblox mock with the REAL server modules (PlayerDataService, ChestService, ChaseService,
-- MysteryPackService, OwnerUpdateCommands82, PackShapeCommand151) and the real pack builders / templates (pack_world.luau, pouch_mock.luau):
--  1. the roll       PlayerDataService:AddChest rolls (uniform) for a pack made straight into a Bag (bonus rolls, daily rewards, gifts, owner commands ...), keeps the
--                    roll a world pack brought (0 = the default, kept for life), takes none for the Void / the Mech, a forced / off mode, an explicit shape for a Void is ignored
--  2. the record     the OPTIONAL PackShape field: serialised, decoded, saved and loaded through the DataStore, gifted; ProfileVersion stays 22; records saved before it are the
--                    default shape; garbage is the default shape; a Seed never carries one; the Verity hand-in rolls its own
--  3. the world      ChestService:RefreshWorldPack rolls once, builds the pack in it, stores it on the seed and the model, pins its pair; a pair not baked yet keeps the default
--                    for life; the Void takes none; SkinWorldSeeds plans the NEXT refresh ahead and asks for its pairs to be baked; distribution over the track
--  4. the journey    steal (the carried clone), carry, drop, pick up again, bank, tool, held, opening copy: the same shape in every context; the tool carries PackShape; the
--                    held pack waits (briefly) for its pair and is never a different shape from its picture
--  5. the Index      every catalogue / shop / "what's inside" picture, the Index and the mystery silhouette are the default shape; the stack key never mixes shapes
--  6. mystery        the pedestal's Ready pack is drawn in the roll the owner will get, and they get it; the locked silhouette is the default
--  7. hand-made      /test packs (they write records themselves) roll their shape too
--  8. static         where the shape is passed (and where it is not)
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function inv(c)return c:Inverse()end
local RS=W.RS
-- the server world (the R137 / R151 server tests' setup) ---------------------------------------------------------------------------------------------
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 if class=='Humanoid'then o.Died=R.signal();o.Health=100;o.PlatformStand=false end
 return o end end
R.Inst.UnequipTools=function()end;R.Inst.EquipTool=function()end
local Config=server('Config');local Rules=H.Rules;local Shapes=W.module('PackShapes151');local Pouch=W.module('VerityPouch151')
local ChestService=server('ChestService');local ChaseService=server('ChaseService')
local assets=RS.SeedPackMeshAssets
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do p.MeshSize=p.Size end end
local DEFAULTS={Enabled=true,Force=nil,LoadingSeconds=60,HoldWaitSeconds=2.5,MaxVertices=60000,MaxResidentVertices=400000,HardResidentVertices=600000,GraceSeconds=30,IdleSeconds=900,SweepSeconds=60}
local function folderOf()return RS:FindFirstChild(Shapes.Folder)end
local function fresh()
 Shapes.Reset();Mock.reset();Mock.vertices=200;for k,v in pairs(DEFAULTS)do Shapes.Config[k]=v end;Shapes.Config.Force=nil
 local f=folderOf();if f then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)end
 local v=RS:FindFirstChild(Pouch.Folder);if v then v:Destroy()end
end
local function withGoodRandom(fn)
 local mockRandom=W.env.Random;math.randomseed(20151)
 W.env.Random={new=function()return{NextNumber=function()return math.random()end,NextInteger=function(_,a,b)return math.random(a,b)end}end};Shapes.Reset()
 local ok,err=pcall(fn);W.env.Random=mockRandom;Shapes.Reset()
 if not ok then error(err,0)end
end
local function sig(bag)
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1;local out={}
 for _,p in ipairs(H.partsOf(bag,false))do
  local f=inv(root.CFrame)*p.CFrame
  out[(p.Parent==bag and''or'PackGeometry/')..p.Name]={Size=p.Size/scale,Pos=f.Position/scale,Frame=f,Class=p._class}
 end
 return out
end
local function cfDelta(a,b)local d=(a.Position-b.Position).Magnitude;local r=0;for _,axis in ipairs({'RightVector','UpVector','LookVector'})do r=math.max(r,math.acos(math.clamp(a[axis]:Dot(b[axis]),-1,1)))end;return d,r end
local function sameSig(a,b)
 for k,x in pairs(a)do
  local y=b[k];if not y then return false,'missing '..k end
  local d=math.max((x.Size-y.Size).Magnitude,(x.Pos-y.Pos).Magnitude,select(2,cfDelta(x.Frame,y.Frame))*.1)
  if d>1e-5 then return false,k..' differs by '..string.format('%.5f',d)end
 end
 for k in pairs(b)do if not a[k]then return false,'extra '..k end end
 return true
end
local function pouchOf(bag)return bag:FindFirstChild('ApprovedMesh01',true)end
local function baked(bag)local m=pouchOf(bag);return m~=nil and m.MeshId==''end
local function design(stage,variant)return Rules.DesignKey(stage,variant)end
local function defaultSig(stage,variant)local b=H.ground(stage,variant,1,'None');local s=sig(b);b:Destroy();return s end

-- 1. The roll (PlayerDataService:AddChest) --------------------------------------------------------------------------------------------------------------
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Notes={Show=function()end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
local function makePlayer(id,name,data)
 data=data or Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p);assert(data:Load(p),'load '..name)
 return p
end
local function pack(player,stage,variant,extra,data)
 local chest={Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion}
 for k,v in pairs(extra or{})do chest[k]=v end
 return(data or Data):AddChest(player,chest)
end
fresh();local A=makePlayer(301,'Ava')
do
 local rec=pack(A,1,'Pack02')
 check(rec and rec.PackShape~=nil and rec.PackShape>=1 and rec.PackShape<=6,'a pack made straight into a Bag (a bonus roll, a daily reward ...) rolls a shape: '..tostring(rec and rec.PackShape))
 check(Shapes.Status().Rolled[rec.PackShape]==1,'... through PackShapes151.Roll (the roll counter moved)')
 withGoodRandom(function()
  local counts={0,0,0,0,0,0};local n=900
  local B=makePlayer(302,'Ben')
  for i=1,n do
   local r=pack(B,1+i%7,string.format('Pack%02d',1+i%6));counts[r.PackShape]+=1
   table.remove(Data:GetChestRecords(B)) -- (the Bag is not full: keep it small)
  end
  local low,worst=1e9,0;for i=1,6 do low=math.min(low,counts[i]);worst=math.max(worst,math.abs(counts[i]-n/6))end
  check(low>0 and worst<=55,('900 AddChest rolls are uniform: %s (worst off by %d of 150 expected; 4.6 sigma is 53)'):format(table.concat(counts,' '),worst))
 end)
 -- every variant that takes one
 for _,variant in ipairs({'Pack01','Pack06','Small','Standard','Grand',H.VERITY})do local r=pack(A,variant==H.VERITY and 7 or 1,variant);check(r.PackShape~=nil,variant..' pack: rolls a shape')end
 for _,variant in ipairs({'EclipseReliquary','MechLimited'})do
  local r=pack(A,variant=='MechLimited'and 8 or 7,variant);check(r.PackShape==nil,variant..' pack: no shape (the Void and the Mech keep their own pouch)')
  local r2=pack(A,variant=='MechLimited'and 8 or 7,variant,{PackShape=3});check(r2.PackShape==nil,variant..' pack given a shape anyway: ignored')
 end
 local weird=pack(A,1,'NoSuchPack');check(weird.PackShape==nil and weird.BagVariant=='Standard','an unknown variant (saved as a Standard pack) rolls nothing')
 -- a world pack brings its roll: kept as it is, 0 = the default shape for life (no field, and NOT rolled again)
 local keep=pack(A,1,'Pack03',{PackShape=4});check(keep.PackShape==4,'a world pack that rolled 4 keeps 4')
 local def=pack(A,1,'Pack03',{PackShape=0});check(def.PackShape==nil,'a world pack that kept the default (0) is not rolled again: no field (the default shape)')
 local bad=pack(A,1,'Pack03',{PackShape=9});check(bad.PackShape==nil,'a garbage shape is the default shape')
 -- modes
 Shapes.SetMode(5);local f5=pack(A,2,'Pack01');local k4=pack(A,2,'Pack01',{PackShape=4})
 check(f5.PackShape==5 and k4.PackShape==4,'forced to 5: a new pack rolls 5; a pack that already has 4 keeps it')
 Shapes.SetMode('off');local off=pack(A,2,'Pack01');local offKeep=pack(A,2,'Pack01',{PackShape=4})
 check(off.PackShape==nil and offKeep.PackShape==4,'off: a new pack rolls nothing; a pack that already has 4 keeps its roll (the display switch hides it, the record keeps it)')
 Shapes.SetMode('auto')
 -- the AddChest source
 check(W.B.PlayerDataService:find('PackShapes.Roll(chest.BagVariant)',1,true)~=nil,'(source: AddChest rolls with PackShapes151.Roll)')
end

-- 2. The record ----------------------------------------------------------------------------------------------------------------------------------------
do
 fresh();local P=makePlayer(303,'Cy')
 local rec=pack(P,1,'Pack02',{PackShape=4});local plain=pack(P,1,'Pack02',{PackShape=0});local void=pack(P,7,'EclipseReliquary')
 local row=Data:SerializeSeedRecord(rec);local rowPlain=Data:SerializeSeedRecord(plain);local rowVoid=Data:SerializeSeedRecord(void)
 check(row.PackShape==4 and rowPlain.PackShape==nil and rowVoid.PackShape==nil,'the saved row carries PackShape 4; a default-shape pack and a Void carry no field')
 check(row.Kind=='Pack'and Config.ProfileVersion==22,'ProfileVersion is still 22 (the field is optional: an older server drops it)')
 local back=Data:_decodeSavedSeedRecord(P,row,1);check(back.PackShape==4,'decoded: the shape comes back')
 local back2=Data:_decodeSavedSeedRecord(P,rowPlain,1);check(back2.PackShape==nil,'decoded: a default-shape pack has none')
 -- old records and garbage
 local old={Id='303_90',Kind='Pack',Stage=2,BagVariant='Pack04',OddsVersion=112,PackSize=1,ChestNumber=90,ChestName='Seed Pack',SeedScale=1}
 local oldRec=Data:_decodeSavedSeedRecord(P,old,90);check(oldRec.PackShape==nil,'a record saved before pack shapes is the default shape (no field)')
 for _,junk in ipairs({0,7,-1,2.5,'3','x',true,{},0/0,math.huge})do
  local r=table.clone(old);r.PackShape=junk;local d=Data:_decodeSavedSeedRecord(P,r,90);check(d.PackShape==nil,'a saved PackShape of '..tostring(junk)..' is the default shape')
 end
 local seedRow=table.clone(old);seedRow.Kind='Seed';seedRow.SeedId='SunflowerSeed';seedRow.PackShape=3
 local seedRec=Data:_decodeSavedSeedRecord(P,seedRow,90);check(seedRec.PackShape==nil,'a Seed never carries a shape')
 local seedOut=Data:SerializeSeedRecord({Id='303_91',Kind='Seed',Stage=1,ChestNumber=91,ChestName='Sunflower',SeedId='SunflowerSeed',PackShape=3,AccentColor=R.Color3.new(1,1,1)})
 check(seedOut.PackShape==nil,'a Seed is never saved with one')
 -- a gift keeps it
 local Q=makePlayer(304,'Dee');local gifted=Data:DecodeGiftedSeed(Q,row);check(gifted and gifted.PackShape==4,'a gifted pack arrives with its shape')
 local giftedOld=Data:DecodeGiftedSeed(Q,old);check(giftedOld and giftedOld.PackShape==nil,'a gifted old pack arrives as the default shape')
 -- through the DataStore: save in one server, load in the next
 pack(P,3,'Pack05',{PackShape=6});pack(P,4,'Pack01',{PackShape=2});pack(P,5,'Pack06',{PackShape=0})
 local mine={};for _,r in ipairs(Data:GetChestRecords(P))do mine[r.Id]=r.PackShape or 0 end
 Data:MarkDirty(P);local saved=Data:Save(P,'test',true)
 check(saved==true,'the profile saves ('..tostring(saved)..')')
 local Data2=PDS.new(Config,Map,Notes);local P2=R.new('Player');P2.Name='Cy';P2.DisplayName='Cy';P2.UserId=303;P2.Parent=Players;present[9303]=P2
 function P2.Kick(_,why)error('kicked: '..tostring(why),0)end;R.new('Backpack').Parent=P2
 Data2:PreparePlayer(P2);local loaded=Data2:Load(P2)
 local theirs={};for _,r in ipairs(Data2:GetChestRecords(P2))do theirs[r.Id]=r.PackShape or 0 end
 local same,count=true,0;for id,s in pairs(mine)do count+=1;if theirs[id]~=s then same=false end end
 check(loaded and count==#Data:GetChestRecords(P)and same,'save / load through the DataStore: every pack keeps its shape ('..count..' packs; '..table.concat((function()local o={};for id,s in pairs(mine)do o[#o+1]=s end;table.sort(o);return o end)(),',')..')')
 -- the Verity hand-in: the Verity pack rolls its own
 local voidRec=pack(P,7,'EclipseReliquary');local verity=Data:ConvertVoidPack(P,voidRec.Id)
 check(verity and verity.BagVariant==H.VERITY and verity.PackShape~=nil and verity.PackShape>=1 and verity.PackShape<=6,'the Verity hand-in: the Verity pack rolls its own shape ('..tostring(verity and verity.PackShape)..'); the Void pack had none')
 Shapes.SetMode('off');local voidRec2=pack(P,7,'EclipseReliquary');local verity2=Data:ConvertVoidPack(P,voidRec2.Id);check(verity2 and verity2.PackShape==nil,'off: the Verity pack rolls nothing');Shapes.SetMode('auto')
end

-- 3. The world (ChestService:RefreshWorldPack, SkinWorldSeeds) ---------------------------------------------------------------------------------------
local runtime=R.new('Folder');runtime.Name='Runtime';runtime.Parent=W.workspace
local function makeSeed(stage,index)
 local model=R.new('Model');model.Name='Seed_'..stage..'_'..index;model.Parent=runtime
 local body=R.new('Part');body.Name='Body';body.CFrame=CF(index*10,0,stage*10);body.Anchored=true;body.Parent=model
 local prompt=R.new('ProximityPrompt');local bill=R.new('BillboardGui');local glow=R.new('PointLight')
 return {Stage=stage,SeedIndex=index,Model=model,Body=body,Prompt=prompt,Billboard=bill,Glow=glow,PartState={},PackHome=body.Position,Available=false}
end
local function makeChests()
 local fake=setmetatable({Map={Refreshing=false,Chests={}},PackRandom=W.env.Random.new(3),RarePackSpawn={FireAllClients=function()end}},ChestService)
 fake.FindPackPlacement=function(self,preferred,stage,variant,size)return CF(preferred),self:GetPackBounds(stage,variant,size)end
 return fake
end
local function packetOf(seed)return seed.Model:FindFirstChild('SeedPacket')end
do
 fresh();local chests=makeChests();local seed=makeSeed(1,1)
 chests:RefreshWorldPack(seed,'Pack02',nil,nil,1,1,3)
 local packet=packetOf(seed)
 check(seed.PackShape==3 and seed.Model:GetAttribute('PackShape')==3 and packet:GetAttribute('PackShape')==3 and packet:GetAttribute('PackShapeShown')==3,'a world pack that rolled 3 (its pair was baked): seed.PackShape 3, on the model and on the pack')
 check(baked(packet),'... and the pack on the track is built in the shape (a baked pouch)')
 -- rolled by the spawn when no plan gave one
 chests:RefreshWorldPack(seed,'Pack03',nil,nil,1,1)
 check(seed.PackShape~=nil and seed.PackShape>=1 and seed.PackShape<=6 and packetOf(seed):GetAttribute('PackShape')==seed.PackShape,'a spawn without a plan rolls its own ('..tostring(seed.PackShape)..')')
 -- the Void takes none
 chests:RefreshWorldPack(seed,'EclipseReliquary',nil,nil,1,1)
 check(seed.PackShape==nil and seed.Model:GetAttribute('PackShape')==nil and packetOf(seed):GetAttribute('PackShape')==nil,'a Void pack on the track: no shape (the seed and the model are cleared)')
 -- a pair that is not baked yet: the default shape for life
 fresh();Mock.slow=true
 chests:RefreshWorldPack(seed,'Pack02',nil,nil,1,1,3)
 check(seed.PackShape==0 and seed.Model:GetAttribute('PackShape')==0 and not baked(packetOf(seed))and packetOf(seed):GetAttribute('PackShapeShown')==0,'a roll whose pair is not baked yet: the pack keeps the default shape for life (0), on the seed, the model and the pack')
 check(Shapes.Status().Demoted==1,'... counted (Demoted 1)')
 while Mock.resume()do end
 chests:RefreshWorldPack(seed,'Pack02',nil,nil,1,1,3)
 check(seed.PackShape==3 and baked(packetOf(seed)),'the next spawn of that pair (now baked) keeps its roll')
 Mock.slow=false
 -- off: the default for life, also after switching on again
 fresh();Shapes.SetMode('off');chests:RefreshWorldPack(seed,'Pack02',nil,nil,1,1)
 check(seed.PackShape==0 and not baked(packetOf(seed)),'shapes off: an ordinary track pack is the default shape for life (0)')
 Shapes.SetMode('auto');check(seed.PackShape==0,'... switching them on again does not change a pack that is already there')
 check(W.B.ChestService:find('PackShapes.Unpin(seed)',1,true)~=nil and W.B.ChestService:find('PackShapes.Pin(seed',1,true)~=nil,'(source: a spawn unpins its slot\'s old pair and pins the new one)')
end
-- the plan: the next refresh is planned ahead and its pairs are baked before it
do
 fresh();Mock.slow=true;local chests=makeChests();for i=1,35 do chests.Map.Chests[i]=makeSeed(1+(i-1)%7,i)end
 for _,s in ipairs(chests.Map.Chests)do s.Stage=1+(s.SeedIndex-1)%7 end
 chests:SkinWorldSeeds()
 local demoted=0;local shaped=0;for _,s in ipairs(chests.Map.Chests)do if s.PackShape==0 then demoted+=1 elseif s.PackShape and s.PackShape>0 then shaped+=1 end end
 check(demoted==35 and shaped==0,'the first refresh of a server (nothing baked, the bakes are slow): all 35 packs keep the default shape ('..demoted..' default, '..shaped..' shaped)')
 check(chests.WorldPlan~=nil and chests.WorldPlan.Cycle==1,'... and the NEXT refresh was planned right after (cycle 1)')
 local wanted=0;for _,id in ipairs(chests.WorldPlan.Shapes)do if id then wanted+=1 end end
 check(wanted==35,'its plan holds a roll for every spot ('..wanted..')')
 check(Shapes.Status().Requested>=1 and Shapes.Status().Pending>=1,'... and the bakes of its pairs have been asked for ('..Shapes.Status().Requested..' pairs requested)')
 local plan=chests.WorldPlan
 while Mock.resume()do end
 check(Shapes.Status().Pending==0 and Shapes.Status().Failures==0,'the bakes finished (no pending, no failure)')
 chests:SkinWorldSeeds(1) -- (the bakes are still slow: a pair that had not been asked for ahead of the refresh would be demoted)
 local kept,zero=0,0;for i,s in ipairs(chests.Map.Chests)do if s.PackShape==plan.Shapes[i]then kept+=1 end;if s.PackShape==0 then zero+=1 end end
 check(kept==35 and zero==0,'the refresh after it: every pack keeps the roll it was planned with ('..kept..'/35, '..zero..' default)')
 Mock.slow=false;while Mock.resume()do end -- (the plan for refresh 2 is being baked: let it finish)
 local allBaked=true;for _,s in ipairs(chests.Map.Chests)do if not baked(packetOf(s))then allBaked=false end end
 check(allBaked,'... and every pack on the track is built in its shape')
 check(chests.WorldPlan~=nil and chests.WorldPlan.Cycle==2,'the refresh after that is planned (cycle 2)')
 -- the pins: every track pack's pair is held; a tiny cache is exceeded rather than evict them
 Shapes.Config.MaxResidentVertices=1;Shapes.Config.GraceSeconds=0;R.advance(5)
 for _=1,3 do Shapes.Request('Forest_01',1) end
 local held=0;for _,s in ipairs(chests.Map.Chests)do if s.PackShape and s.PackShape>0 and Shapes.State(design(s.Stage,s.BagVariant),s.PackShape)=='Ready'then held+=1 end end
 local total=0;for _,s in ipairs(chests.Map.Chests)do if s.PackShape and s.PackShape>0 then total+=1 end end
 check(held==total and total==35,'with a cache far over its cap, every pair of a pack on the track is still baked (pinned): '..held..'/'..total)
 -- the pack that was stolen and carried still builds from a baked pair
 local s1=chests.Map.Chests[1];local carriedBuild=H.ground(s1.Stage,s1.BagVariant,1,'None',nil,s1.PackShape);check(baked(carriedBuild),'a pinned pair builds the carried / dropped pack in its shape');carriedBuild:Destroy()
end
-- the distribution over many refreshes
do
 fresh();Shapes.Config.MaxResidentVertices=1e9;Shapes.Config.HardResidentVertices=1e9
 withGoodRandom(function()
  local chests=makeChests();for i=1,35 do chests.Map.Chests[i]=makeSeed(1+(i-1)%7,i)end
  for _,s in ipairs(chests.Map.Chests)do s.Stage=1+(s.SeedIndex-1)%7 end
  local counts={0,0,0,0,0,0};local zeros=0;local cycles=40
  chests:SkinWorldSeeds()
  for c=1,cycles do chests:SkinWorldSeeds(c);for _,s in ipairs(chests.Map.Chests)do if s.PackShape and s.PackShape>0 then counts[s.PackShape]+=1 else zeros+=1 end end end
  local n=35*cycles;local low,worst=1e9,0;for i=1,6 do low=math.min(low,counts[i]);worst=math.max(worst,math.abs(counts[i]-n/6))end
  check(zeros==0 and low>0 and worst<=75,('%d track packs over %d refreshes are uniform over the six: %s (worst off by %d of %d expected; none default)'):format(n,cycles,table.concat(counts,' '),worst,n/6))
 end)
end

-- 4. The journey: steal, carry, drop, pick up, bank, tool, hand, opening ----------------------------------------------------------------------------
local function character(player)
 local char,hrp,torso=H.character('R15');local hum=R.Instance.new('Humanoid');hum.Parent=char;char.Name=player.Name;player.Character=char
 player.CharacterRemoving=R.signal()
 return char,hrp,torso,hum
end
do
 fresh();local chests=makeChests();local seed=makeSeed(4,2)
 chests:RefreshWorldPack(seed,'Pack03',nil,nil,1,1,5)
 local ground=sig(packetOf(seed))
 check(seed.PackShape==5 and baked(packetOf(seed)),'(a Lava_03 pack on the track in shape 5)')
 -- steal: ConcurrentKeeperService clones the seed (the shape is in the clone)
 local carried=table.clone(seed);carried.OriginSlot=seed
 check(carried.PackShape==5,'the carried clone of the seed has the shape')
 check(W.B.ConcurrentKeeperService:find('local carriedSeed=table.clone(seed)',1,true)~=nil,'(source: a steal clones the whole seed table, so the shape rides along)')
 local B=makePlayer(311,'Eve');local char=character(B)
 local carry=ChaseService._createCarriedChest(nil,char,nil,carried)
 check(carry:GetAttribute('PackShape')==5 and carry:GetAttribute('PackShapeShown')==5 and baked(carry),'carry: the carried pack is built in the shape')
 local same,why=sameSig(sig(carry),ground);check(same,'carry: the same parts, sizes and positions as the pack on the track'..(why and(' ('..why..')')or''))
 -- drop
 local drops={}
 local chase={Chests=chests,Config=Config,Drops=drops,Map={RuntimeFolder=runtime,CreateRuntimePart=function(_,props)local p=R.new('Part');for k,v in pairs(props)do if k~='Parent'then p[k]=v end end;p.Parent=props.Parent;return p end}}
 function chase._claimDroppedChest()end
 local dropModel=ChaseService._createDroppedChest(chase,V3(0,0,0),carried,1)
 local dropPacket=dropModel:FindFirstChild('SeedPacket')
 check(dropModel:GetAttribute('PackShape')==5 and dropPacket and dropPacket:GetAttribute('PackShape')==5 and baked(dropPacket),'drop: the dropped pack and its model carry the shape')
 check(sameSig(sig(dropPacket),ground),'drop: the same parts as on the track')
 -- picked up again (the dropped chest table is the same table: carried again)
 local again=ChaseService._createCarriedChest(nil,char,nil,carried)
 check(again:GetAttribute('PackShapeShown')==5 and sameSig(sig(again),ground),'picked up again: the same shape')
 -- bank
 local record=ChestService.Bank({PlayerData=Data,SyncTools=function()end},B,carried)
 check(record and record.PackShape==5,'bank: the record keeps the shape the pack had on the track')
 -- a default-shape pack on the track stays default in the Bag (and is not rolled again)
 chests:RefreshWorldPack(seed,'Pack03',nil,nil,1,1,0);local carried0=table.clone(seed)
 local rec0=ChestService.Bank({PlayerData=Data,SyncTools=function()end},B,carried0);check(rec0 and rec0.PackShape==nil,'a track pack of the default shape banks as the default shape (never rolled again)')
 -- the tool
 local backpack=B:FindFirstChildOfClass('Backpack')
 local selfTool={PlayerData=Data,Config=Config,Openings={},_holdPack=ChestService._holdPack,_activatePack=ChestService._activatePack,_canOpenPack=ChestService._canOpenPack}
 selfTool.Openings=selfTool.Openings
 local tool=ChestService._createPackTool(selfTool,record,backpack)
 check(tool:GetAttribute('PackShape')==5 and tool:GetAttribute('SeedPackTool')==true,'the hotbar tool carries PackShape 5')
 local tool0=ChestService._createPackTool(selfTool,rec0,backpack);check(tool0:GetAttribute('PackShape')==nil,'a default-shape pack\'s tool has no PackShape attribute')
 local oldRecord=Data:_decodeSavedSeedRecord(B,{Id='311_90',Kind='Pack',Stage=2,BagVariant='Pack04',OddsVersion=112,PackSize=1,ChestNumber=90,ChestName='Seed Pack',SeedScale=1},90)
 local toolOld=ChestService._createPackTool(selfTool,oldRecord,backpack);check(toolOld:GetAttribute('PackShape')==nil,'a pack saved before pack shapes: its tool has no PackShape')
 -- the picture of that tool (the real ItemPictures key) and the stack key
 local Pic=W.module('ItemPictures')
 local k5,s5=Pic.Key(tool);local k0,s0=Pic.Key(tool0);local kOld,sOld=Pic.Key(toolOld)
 check(k5:sub(-2)=='|5'and s5.Shape==5 and s0.Shape==nil and sOld.Shape==nil and k0==('Pack|4|Pack03|None')and kOld=='Pack|2|Pack04|None','the picture keys: shape 5 is its own look; the default and an old pack are the old keys ('..k5..', '..k0..', '..kOld..')')
 -- the hand
 do
  local calls=Mock.calls
  fresh();Mock.slow=true
  local tool5=ChestService._createPackTool(selfTool,record,backpack)
  tool5.Parent=char
  local builders={};local realWait=R.task.wait
  R.task.wait=function(t)Mock.resume();R.advance(t or .03);return t or .03 end
  local co=coroutine.create(function()ChestService._holdPack(selfTool,B,tool5)end);local ok,err=coroutine.resume(co)
  check(ok,'the hold runs ('..tostring(err)..')')
  local opening=selfTool.Openings[B]
  check(opening and opening.Bag and opening.Bag:GetAttribute('PackShapeShown')==5 and baked(opening.Bag),'a pack put in the hand waits for its pair (a few frames here) and is the shape it rolled')
  check(opening and sameSig(sig(opening.Bag),ground),'the held pack has the same parts, sizes and positions as the pack on the track')
  -- the opening copy (SeedPackClient: the held bag cloned, welds removed, anchored)
  local copy=H.openingCopy(opening.Bag);check(sameSig(sig(copy),ground)and baked(copy),'the opening copy: the same shape');copy:Destroy()
  selfTool.Openings[B]=nil;opening.Bag:Destroy()
  -- a pair that never bakes: the hand waits its bounded time, then the default shape (never the shape later)
  fresh();Mock.mode='hang';R.task.wait=function(t)R.advance(t or .03);return t or .03 end
  local t0=R.clock;local co2=coroutine.create(function()ChestService._holdPack(selfTool,B,tool5)end);local ok2,err2=coroutine.resume(co2)
  local op2=selfTool.Openings[B]
  check(ok2 and op2 and op2.Bag and op2.Bag:GetAttribute('PackShapeShown')==0 and not baked(op2.Bag)and R.clock-t0>=Shapes.Config.HoldWaitSeconds-.1 and R.clock-t0<Shapes.Config.HoldWaitSeconds+1,'a pair that never bakes: the hand waited '..string.format('%.1f',R.clock-t0)..' s (limit '..Shapes.Config.HoldWaitSeconds..') and then holds the default shape')
  if op2 then selfTool.Openings[B]=nil;op2.Bag:Destroy()end
  R.task.wait=realWait;Mock.slow=false;tool5:Destroy()
 end
end

-- 5. The Index and every catalogue --------------------------------------------------------------------------------------------------------------------
do
 -- no catalogue / shop / what's-inside builder passes a shape: they call SeedPackVisuals.Bag / ItemPictures with the old arguments (checked at the source), and a pack
 -- built that way is the default shape whatever the player's packs rolled
 fresh();Shapes.Request('Forest_02',3)
 local plain=H.picture(1,'Pack02',1,'None');check(plain:GetAttribute('PackShape')==nil and not baked(plain),'a picture built the catalogue way (no shape) is the default shape even when the pair is baked');plain:Destroy()
 local Pic=W.module('ItemPictures')
 local proxy=R.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',1);proxy:SetAttribute('BagVariant','Pack02');proxy:SetAttribute('PackMutation','None')
 local kp,sp=Pic.Key(proxy);check(kp=='Pack|1|Pack02|None'and sp.Shape==nil,'a proxy (the Verity NPC, the daily / bonus reward panels) has the default key')
 local ks=Pic.SampleKey('All');check(ks=='Pack|1|Standard|None','the category tab sample is the default')
end

-- 6. The mystery pedestal ------------------------------------------------------------------------------------------------------------------------------
do
 fresh()
 do local art=folder.MysteryPedestalArt;art.Parent=RS;W.stub('MysteryPedestalArt',{Tint=function()end,Build=function()return{}end});art.Parent=folder end -- (the pedestal's own art is not under test)
 local Mystery=server('MysteryPackService')
 local C=makePlayer(321,'Flo')
 local chests=makeChests();chests.SyncTools=function()end
 local svc=Mystery.new(Config,Data,nil,chests,Notes,Map)
 local state={Day=20000,Seconds=900,Claimed=false,Owed={},Stage=3,Variant='Pack03'}
 local s1=svc:_shape(C,state);local s2=svc:_shape(C,state)
 check(s1~=nil and s1>=1 and s1<=6 and s1==s2,'the pedestal rolls once per owner and pack: the same shape every time ('..tostring(s1)..')')
 local other=svc:_shape(C,{Day=20001,Seconds=900,Claimed=false,Owed={},Stage=3,Variant='Pack03'});check(other~=nil,'a new day rolls again (one roll is kept per owner: the pedestal shows today\'s pack)')
 s1=svc:_shape(C,state);check(s1==svc:_shape(C,state),'(back to today\'s pack: a fresh roll, then stable)')
 -- the look
 local anchor=R.new('Part');anchor.CFrame=CF(0,5,0);anchor.Parent=W.workspace
 local model=R.new('Model');model.Parent=W.workspace
 local light=R.new('PointLight');light.Parent=anchor
 local p={Model=model,Anchor=anchor,Light=light,Art={}}
 Mock.slow=true
 svc:_look(p,'Ready',3,'Pack03',s1)
 local pk=model:FindFirstChild('MysteryPack')and model.MysteryPack:FindFirstChild('SeedPacket')
 check(pk~=nil and not baked(pk),'the Ready pack on the pedestal: the default shape until its pair is baked (never yields)')
 while Mock.resume()do end;Mock.slow=false
 svc:_look(p,'Ready',3,'Pack03',s1)
 local pk2=model:FindFirstChild('MysteryPack')and model.MysteryPack:FindFirstChild('SeedPacket')
 check(pk2~=nil and pk2:GetAttribute('PackShape')==s1 and baked(pk2),'... and the shape it will be given once it is baked (the pedestal redraws: the look key carries the shape shown)')
 local calls=Mock.calls;svc:_look(p,'Ready',3,'Pack03',s1);check(Mock.calls==calls and p.Look~=nil,'a look that has not changed is not rebuilt')
 svc:_look(p,'Locked',3,'Pack03',s1) -- (even when a shape is passed: the silhouette ignores it)
 local lk=model:FindFirstChild('MysteryPack')and model.MysteryPack:FindFirstChild('SeedPacket')
 check(lk~=nil and lk:GetAttribute('PackShape')==nil and not baked(lk),'the locked silhouette is the default plain pack: no shape (every locked pedestal looks the same, the roll is not leaked)')
 -- the grant
 local rec=svc:_give(C,state)
 check(rec and rec.PackShape==s1,'the pack the owner takes has the shape the pedestal showed ('..tostring(rec and rec.PackShape)..')')
 check(svc.Shapes[C]==nil,'... and the roll is used up')
 local owed=svc:_give(C,{Day=19999,Stage=2,Variant='Pack02'});check(owed and owed.PackShape~=nil,'an owed pack of an earlier day rolls its own in AddChest ('..tostring(owed and owed.PackShape)..')')
end

-- 7. Hand-made test packs -----------------------------------------------------------------------------------------------------------------------------
do
 check(W.B.StudioTestCommands:find("PackShape=isPack and require(RS:WaitForChild('PackShapes151')).Roll(variant)",1,true)~=nil,'(source: /test pack rolls its shape)')
 check(W.B.RarePackTests:find("PackShape=require(game:GetService('ReplicatedStorage').PackShapes151).Roll(",1,true)~=nil,'(source: /test rarepacks rolls its shape)')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
