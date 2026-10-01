--!nocheck
-- R122 giving under the Roblox mock: the real FruitGiftService, PlayerDataService (+ PremiumProgress,
-- TutorialProgress, GardenFenceData), Config, SecurityGate and MovementGuard. DataStores are in-memory and
-- every write is deep-copied through a "DataStore-safe" check (plain tables, strings, numbers, booleans only),
-- so a Color3 or Instance reaching a save or an inbox fails the test. Run from a folder holding roblox.luau,
-- world.luau, rs_bundle.luau and srv_names.luau (see run.sh).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Scheduler where task.wait really yields (FruitGiftService runs a `while task.wait(15)` loop).
local sleeping={}
local task2=table.clone(R.task)
task2.spawn=function(f,...)local co=type(f)=='thread'and f or coroutine.create(f);local ok,e=coroutine.resume(co,...);if not ok then error(debug.traceback(co,tostring(e)),0)end;return co end
task2.wait=function(t)
 t=t or 0
 if not coroutine.isyieldable()then return t end
 table.insert(sleeping,{At=R.clock+t,Co=coroutine.running()});coroutine.yield();return t
end
W.env.task=task2
local function advance(dt)
 local target=R.clock+dt
 while true do
  local nextAt;for _,s in ipairs(sleeping)do if not nextAt or s.At<nextAt then nextAt=s.At end end
  if not nextAt or nextAt>target then break end
  R.advance(math.max(0,nextAt-R.clock))
  local due={};local keep={}
  for _,s in ipairs(sleeping)do if s.At<=R.clock then due[#due+1]=s else keep[#keep+1]=s end end
  sleeping=keep
  for _,s in ipairs(due)do local ok,e=coroutine.resume(s.Co);if not ok then error(debug.traceback(s.Co,tostring(e)),0)end end
 end
 R.advance(math.max(0,target-R.clock))
end
-- Services -------------------------------------------------------------------------------------------
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;table.sort(out,function(a,b)return a.UserId<b.UserId end);return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
function Players.GetPlayerFromCharacter(_,m)for _,p in pairs(present)do if p.Character==m then return p end end;return nil end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
-- DataStore-safe deep copy: anything Roblox could not serialize is an error.
local function dsCopy(v,path)
 path=path or'value'
 local t=type(v)
 if t=='string'or t=='number'or t=='boolean'or t=='nil'then return v end
 if t~='table'or getmetatable(v)~=nil or v.__type then error('not DataStore-safe at '..path..': '..R.typeof(v),0)end
 local o={};for k,x in pairs(v)do o[k]=dsCopy(x,path..'.'..tostring(k))end;return o
end
local stores={};local dsFail={}
local DS=W.service('DataStoreService')
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Name=name,Data={},
  UpdateAsync=function(self,key,fn)
   if dsFail[self.Name]then error('DataStore down',0)end
   local v=fn(dsCopy(self.Data[key]),nil);if v~=nil then self.Data[key]=dsCopy(v)end;return dsCopy(self.Data[key])end,
  GetAsync=function(self,key)if dsFail[self.Name]then error('DataStore down',0)end;return dsCopy(self.Data[key])end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
-- Mock gaps used by these modules.
W.env.RaycastParams={new=function()return {}end}
local blockLine=false
function W.workspace.Raycast()return blockLine and {Instance=W.workspace}or nil end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end;return o end end
-- Real modules ---------------------------------------------------------------------------------------
local Config=server('Config')
local notes={}
local Map={GetStageAccent=function(_,stage)return R.Color3.new(stage/10,.5,.5)end}
local Data=server('PlayerDataService').new(Config,Map,{Show=function(_,p,msg)notes[#notes+1]={P=p,Text=msg}end})
local Chase={Busy={}};function Chase:IsPlayerBusy(p)return self.Busy[p]==true end
-- ChestService stand-in: SyncTools mirrors the real rule (a seed/pack/fruit Tool exists only while its record does).
local Chests={Openings={},Synced={}}
function Chests:SyncTools(p)
 self.Synced[p]=(self.Synced[p]or 0)+1
 local ids={};for _,r in ipairs(Data:GetChestRecords(p))do ids[r.Id]=r end
 local crops={};for _,c in ipairs(Data.Gardens[p].Harvests)do crops[c.Id]=true end
 for _,container in ipairs({p:FindFirstChildOfClass('Backpack'),p.Character})do
  for _,t in ipairs(container and container:GetChildren()or{})do if t:IsA('Tool')then
   local sid=t:GetAttribute('SeedInventoryId');local hid=t:GetAttribute('HarvestInventoryId')
   if(sid and not ids[sid])or(hid and not crops[hid])then t:Destroy()end
  end end
 end
end
local Gifts=server('FruitGiftService').new(Data,Chests,Chase,nil)
local Remote=remotes.FruitGift
local fired={}
function Remote.FireClient(_,p,action,msg)fired[#fired+1]={P=p,Action=action,Text=msg}end
local function lastFor(p)for i=#fired,1,-1 do if fired[i].P==p then return fired[i]end end end
-- Players ---------------------------------------------------------------------------------------------
local unequipped=0
local function makePlayer(id,name,x)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 local bp=R.new('Backpack');bp.Parent=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace
 local h=R.new('Humanoid');h.Health=100;h.Parent=c
 function h.UnequipTools()unequipped+=1;for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')then t.Parent=bp end end end
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Position=R.Vector3.new(x,3,0);root.Parent=c
 p.Character=c
 p:SetAttribute('PaidTradingAllowed',true);p:SetAttribute('PaidRandomAllowed',true)
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 Data:GetPremium(p).Tutorial.Done=true;Data:PublishTutorial(p)
 return p
end
local A=makePlayer(101,'Alice',0);local B=makePlayer(202,'Bob',6);local C=makePlayer(303,'Carol',60)
local function rootOf(p)return p.Character.HumanoidRootPart end
local function hold(p,record)
 local t=R.new('Tool');t.Name='item'
 if record.Kind=='Pack'then t:SetAttribute('SeedPackTool',true)else t:SetAttribute('GardenSeed',true)end
 t:SetAttribute('SeedInventoryId',record.Id);t.Parent=p.Character;return t
end
local function holdFruit(p,crop)local t=R.new('Tool');t:SetAttribute('HarvestItemTool',true);t:SetAttribute('HarvestInventoryId',crop.Id);t.Parent=p.Character;return t end
local function find(p,id)for _,r in ipairs(Data:GetChestRecords(p))do if r.Id==id then return r end end end
local function seedRecords(p)return #Data:GetChestRecords(p)end
-- Each send is a fresh remote call through SecurityGate after the 2 s gift cooldown.
-- Like Roblox, every remote call and recovery pass runs on its own thread (they may yield on DataStores).
local function fire(...)local a=table.pack(...);task2.spawn(function()Remote.OnServerEvent:Fire(table.unpack(a,1,a.n))end)end
local function recover(p)task2.spawn(function()Gifts:Recover(p)end);advance(5)end
local function send(p,action,to,id)advance(2.1);fire(p,action,to and to.UserId,id)advance(5)end
local function savedRow(p,id)
 local key='Player_'..p.UserId;local profile
 for _,s in pairs(stores)do if s.Data[key]then profile=s.Data[key]end end
 for _,row in ipairs(profile and profile.Seeds or{})do if row.Id==id then return row end end
end
local function seedStore()for name,s in pairs(stores)do if name:find('SeedInbox')then return s end end end
-- Inventory items -------------------------------------------------------------------------------------
local pack=Data:AddChest(A,{Stage=3,BagVariant='Pack06',PackSize=2,PackMutation='Diamond',Weather='Drippy'})
check(pack and pack.Kind=='Pack','fixture pack added')
local mutated=Data:AddChest(A,{Stage=2,BagVariant='Pack03',PackSize=1,PackMutation='None',Weather='None'})
local seed=Data:OpenSeedPack(A,mutated.Id,function()return .5 end)
check(seed and seed.Kind=='Seed','fixture seed opened')
seed=find(A,mutated.Id);seed.PackMutation='Gold';seed.SeedScale=1.5;seed.Weather='Frosted'
local packTraits=Data:SerializeSeedRecord(pack);local seedTraits=Data:SerializeSeedRecord(seed)
local function sameTraits(row,expect,label)
 for _,k in ipairs({'Kind','Stage','BagVariant','PackSize','PackMutation','Weather','SeedScale','SeedId','SeedName','OddsVersion','PaidRandom','Id','ChestName'})do
  check(row and row[k]==expect[k],label..' keeps '..k..' ('..tostring(row and row[k])..' vs '..tostring(expect[k])..')')
 end
end
Data:Save(A,'fixture',true);Data:Save(B,'fixture',true)

-- 1. Pack gift: success, traits, giver loses it, recipient gets it, both saved -------------------------
local beforeA,beforeB=seedRecords(A),seedRecords(B)
local tool=hold(A,pack)
local aRevision,bRevision=Data.Revision[A],Data.Revision[B]
send(A,'GiveSeed',B,pack.Id)
check(find(A,pack.Id)==nil,'pack left the giver')
check(seedRecords(A)==beforeA-1 and seedRecords(B)==beforeB+1,'counts moved by one')
local got=find(B,pack.Id)
check(got and got.Kind=='Pack','recipient owns the pack')
sameTraits(got and Data:SerializeSeedRecord(got),packTraits,'gifted pack')
check(got and got.ChestNumber==B:GetAttribute('ChestInventorySerial'),'recipient numbered the pack from its own serial')
check(tool.Parent==nil,'held pack Tool removed from giver')
check(unequipped>=1,'giver unequipped before removal')
check(savedRow(A,pack.Id)==nil,'giver save no longer lists the pack')
sameTraits(savedRow(B,pack.Id),packTraits,'recipient save')
check(Data.Revision[A]>aRevision and Data.Revision[B]>bRevision,'both profiles marked dirty')
check(A:GetAttribute('SeedInventoryCount')==seedRecords(A)and B:GetAttribute('SeedInventoryCount')==seedRecords(B),'both inventory counters refreshed')
check((Chests.Synced[A]or 0)>0 and(Chests.Synced[B]or 0)>0,'both hotbars resynced')
local recv=lastFor(B);check(recv and recv.Action=='Received'and recv.Text:find('seed pack'),'recipient notified: '..tostring(recv and recv.Text))
local sent=false;for _,f in ipairs(fired)do if f.P==A and f.Text and f.Text:find('Gift sent to Bob')then sent=true end end
check(sent,'giver notified')
advance(31) -- acknowledgements finish on the 15 s background recovery loop (same as fruit)
check(next(Data.Gardens[A].OutgoingSeedGifts)==nil,'giver outbox cleaned up')
local box=seedStore().Data[tostring(B.UserId)]
check(box==nil or next(box)==nil,'recipient inbox cleaned up')

-- 2. Seed gift with traits ------------------------------------------------------------------------------
hold(A,seed)
send(A,'GiveSeed',B,seed.Id)
check(find(A,seed.Id)==nil,'seed left the giver')
local gs=find(B,seed.Id)
check(gs and gs.Kind=='Seed','recipient owns the seed')
sameTraits(gs and Data:SerializeSeedRecord(gs),seedTraits,'gifted seed')
check(B.DiscoveredSeeds:FindFirstChild(seed.SeedId)~=nil,'recipient index marks the seed discovered')
recv=lastFor(B);check(recv and recv.Text:find('a seed!'),'seed receipt notice')

-- 3. Recipient full: refused up front, nothing lost ------------------------------------------------------
local p2=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p2)
local cap=Config.MaxSavedChests;Config.MaxSavedChests=seedRecords(B)
send(A,'GiveSeed',B,p2.Id)
check(find(A,p2.Id)~=nil,'full recipient: giver keeps the pack')
check(find(B,p2.Id)==nil,'full recipient: nothing added')
check(lastFor(A).Text=='Their seed inventory is full.','full recipient message')
-- Full only at delivery time: the gift waits in the inbox, is not lost, and lands once there is room.
Config.MaxSavedChests=cap
local realRecover=Gifts.Recover;local heldRecover=true
Gifts.Recover=function(self,p)if heldRecover and p==B then return end;return realRecover(self,p)end
send(A,'GiveSeed',B,p2.Id)
check(find(A,p2.Id)==nil,'race: debited from giver')
Config.MaxSavedChests=seedRecords(B);heldRecover=false;Gifts.Recover=realRecover
recover(B)
check(find(B,p2.Id)==nil,'race: still full, not inserted')
local inbox=seedStore().Data[tostring(B.UserId)]
local waiting=false;for _,g in pairs(inbox or{})do if g.State=='Ready'and g.Seed.Id==p2.Id then waiting=true end end
check(waiting,'race: gift kept safely in the inbox')
Config.MaxSavedChests=cap;recover(B);recover(A)
check(find(B,p2.Id)~=nil,'race: delivered after making room')
recover(B);recover(A)
check(next(Data.Gardens[A].OutgoingSeedGifts)==nil,'race: outbox acknowledged and cleared')

-- 4. Forged / invalid ids -----------------------------------------------------------------------------------
local p3=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});local t3=hold(A,p3)
local n=seedRecords(A)
send(A,'GiveSeed',B,'202_1') -- someone else's id
send(A,'GiveSeed',B,string.rep('x',101))
send(A,'GiveSeed',B,{Id=p3.Id})
send(A,'GiveSeed',{UserId=0/0},p3.Id)
send(A,'GiveSeed',A,p3.Id) -- to self
fire(A,'GiveSeed',999999,p3.Id);advance(3) -- player not in server
check(seedRecords(A)==n and find(A,p3.Id)~=nil,'forged ids / targets rejected')
-- Not holding it (only in the backpack) is rejected too.
t3.Parent=A.Backpack;send(A,'GiveSeed',B,p3.Id);check(find(A,p3.Id)~=nil,'not held: rejected')
-- Holding a Tool whose kind does not match the record (fake seed tool for a pack) is rejected.
t3:SetAttribute('SeedPackTool',nil);t3:SetAttribute('GardenSeed',true);t3.Parent=A.Character
send(A,'GiveSeed',B,p3.Id);check(find(A,p3.Id)~=nil,'tool/record kind mismatch rejected')
t3:SetAttribute('GardenSeed',nil);t3:SetAttribute('SeedPackTool',true)

-- 5. Too far / blocked line of sight -----------------------------------------------------------------------
send(A,'GiveSeed',C,p3.Id);check(find(A,p3.Id)~=nil and find(C,p3.Id)==nil,'too far rejected')
blockLine=true;send(A,'GiveSeed',B,p3.Id);blockLine=false;check(find(A,p3.Id)~=nil,'wall between players rejected')

-- 6. Rate limit: a burst within the 2 s cooldown moves only one item ---------------------------------------
local p4=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p4)
advance(3)
fire(A,'GiveSeed',B.UserId,p3.Id)
fire(A,'GiveSeed',B.UserId,p4.Id)
advance(5)
local moved=(find(B,p3.Id)and 1 or 0)+(find(B,p4.Id)and 1 or 0)
check(moved==1,'burst moved exactly one item (moved '..moved..')')
-- Fruit and seed gifts share the cooldown, so alternating cannot double the rate.
local p5=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p5)
advance(3);fire(A,'Give',B.UserId,'nope');fire(A,'GiveSeed',B.UserId,p5.Id);advance(5)
check(find(A,p5.Id)~=nil,'fruit + seed gift share one cooldown')

-- 7. Carrying / running / queued / tutorial / chase / opening block the giver ----------------------------
for _,attr in ipairs({'ChestChaseSeedCarrying','ChestChaseRunActive','ChestChaseQueued'})do
 A:SetAttribute(attr,true);send(A,'GiveSeed',B,p5.Id);A:SetAttribute(attr,nil)
 check(find(A,p5.Id)~=nil,attr..' blocks giving')
end
Chase.Busy[A]=true;send(A,'GiveSeed',B,p5.Id);Chase.Busy[A]=nil;check(find(A,p5.Id)~=nil,'active chase blocks giving')
Data:GetPremium(A).Tutorial.Done=false;Data:GetPremium(A).Tutorial.Mask=1;Data:PublishTutorial(A)
send(A,'GiveSeed',B,p5.Id);check(find(A,p5.Id)~=nil and lastFor(A).Text=='Finish the tutorial first.','tutorial blocks giving')
Data:GetPremium(A).Tutorial.Done=true;Data:PublishTutorial(A)
Chests.Openings[A]={Committed=true,Tool=R.new('Tool')};send(A,'GiveSeed',B,p5.Id);Chests.Openings[A]=nil
check(find(A,p5.Id)~=nil,'pack mid-reveal blocks giving')
-- A pack that is only being held (uncommitted opening of this very pack) can be given.
local held5;for _,t in ipairs(A.Character:GetChildren())do if t:GetAttribute('SeedInventoryId')==p5.Id then held5=t end end
Chests.Openings[A]={Committed=false,Tool=held5};send(A,'GiveSeed',B,p5.Id);Chests.Openings[A]=nil
check(find(A,p5.Id)==nil and find(B,p5.Id)~=nil,'held (unopened) pack can be given')
-- Recipient busy in a chase is rejected.
local p6=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p6)
Chase.Busy[B]=true;send(A,'GiveSeed',B,p6.Id);Chase.Busy[B]=nil;check(find(A,p6.Id)~=nil,'recipient in a chase rejected')

-- 8. Paid packs (Mech) follow the paid-item policy --------------------------------------------------------
local mech=Data:GrantMechPack(A,true);hold(A,mech)
B:SetAttribute('PaidTradingAllowed',false);send(A,'GiveSeed',B,mech.Id)
check(find(A,mech.Id)~=nil,'paid pack blocked when trading paid items is not allowed')
B:SetAttribute('PaidTradingAllowed',true);B:SetAttribute('PaidRandomAllowed',false);send(A,'GiveSeed',B,mech.Id)
check(find(A,mech.Id)~=nil,'paid pack blocked when the recipient cannot open paid random items')
B:SetAttribute('PaidRandomAllowed',true);local mechTraits=Data:SerializeSeedRecord(mech);send(A,'GiveSeed',B,mech.Id)
local gm=find(B,mech.Id);check(gm~=nil,'paid pack gifted when both accounts allow it')
sameTraits(gm and Data:SerializeSeedRecord(gm),mechTraits,'mech pack')

-- 9. Save failure: debit stays in the outbox, nothing is lost or duplicated ------------------------------
local p7=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p7)
local profileStore;for name,s in pairs(stores)do if s.Data['Player_'..A.UserId]then profileStore=name end end
dsFail[profileStore]=true;send(A,'GiveSeed',B,p7.Id);dsFail[profileStore]=nil
check(find(A,p7.Id)==nil and find(B,p7.Id)==nil,'failed save: item held in the outbox only')
check(Data.Gardens[A].OutgoingSeedGifts and next(Data.Gardens[A].OutgoingSeedGifts)~=nil,'failed save: outbox entry kept')
check(lastFor(A).Text:find('pending a safe save'),'failed save: giver told it will retry')
Data.Revision[A]=(Data.Revision[A]or 0)+1;advance(16) -- background retry loop
recover(B);recover(A);recover(B);recover(A)
local copies=0;for _,p in ipairs({A,B})do if find(p,p7.Id)then copies+=1 end end
check(copies==1 and find(B,p7.Id)~=nil,'retry delivered exactly one copy')

-- 10. Forged inbox entries are not decoded into the inventory ----------------------------------------------
local store=seedStore()
store.Data[tostring(B.UserId)]={evil={State='Ready',From=101,Seed={Id='x',Kind='Seed',SeedId='NotARealSeed',Stage=1,ChestNumber=1,ChestName='x'}},
 evil2={State='Ready',From=101,Seed={Id='y',Kind='Chest',Stage=1,ChestNumber=1,ChestName='y'}}}
local nb=seedRecords(B);recover(B)
check(seedRecords(B)==nb,'invalid inbox rows refused')
store.Data[tostring(B.UserId)]=nil

-- 11. Fruit giving still works (regression) -----------------------------------------------------------------
local fruitSeed;for _,r in ipairs(Data:GetChestRecords(A))do if r.Kind=='Seed'and Config.GardenPlants[r.SeedId]then fruitSeed=r end end
if not fruitSeed then
 local fp=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});Data:OpenSeedPack(A,fp.Id,function()return .1 end);fruitSeed=find(A,fp.Id)
end
check(fruitSeed and Config.GardenPlants[fruitSeed.SeedId],'fruit fixture seed plantable')
local now=os.time()
local planted,crop=Data:PlantSeed(A,1,fruitSeed.Id,{OffsetX=0,OffsetZ=0},now)
check(planted,'fixture planted: '..tostring(crop))
local ok,harvest=Data:HarvestPlant(A,1,crop.Id,crop.ReadyAt+1)
check(ok,'fixture harvested: '..tostring(harvest))
local fruit=Data.Gardens[A].Harvests[#Data.Gardens[A].Harvests]
local fruitId=fruit.Id;local fruitValue=fruit.Value
local hb=#Data.Gardens[B].Harvests
holdFruit(A,fruit);send(A,'Give',B,fruitId)
local fa=false;for _,c in ipairs(Data.Gardens[A].Harvests)do if c.Id==fruitId then fa=true end end
local fb;for _,c in ipairs(Data.Gardens[B].Harvests)do if c.Id==fruitId then fb=c end end
check(not fa and fb~=nil and #Data.Gardens[B].Harvests==hb+1,'fruit moved to recipient')
check(fb and fb.Value==fruitValue,'fruit value preserved')
recv=lastFor(B);check(recv and recv.Text=='A gifted crop was added to your bag.','fruit receipt notice unchanged')
advance(31)
check(next(Data.Gardens[A].OutgoingGifts)==nil,'fruit outbox cleaned')
local fruitBox;for name,s in pairs(stores)do if name:find('FruitInbox')then fruitBox=s end end
local fb2=fruitBox and fruitBox.Data[tostring(B.UserId)];check(fb2==nil or next(fb2)==nil,'fruit inbox cleaned')
-- A seed id sent through the fruit action does nothing.
local p8=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p8)
send(A,'Give',B,p8.Id);check(find(A,p8.Id)~=nil,'pack id via the fruit action is ignored')

-- 12. Reload round trip: the recipient's saved items decode to the same traits ---------------------------
Data:Save(B,'final',true)
local live={};for _,r in ipairs(Data:GetChestRecords(B))do live[r.Id]=Data:SerializeSeedRecord(r)end
Data:PreparePlayer(B);check(Data:Load(B),'recipient reloads')
for _,id in ipairs({pack.Id,seed.Id,mech.Id})do local r=find(B,id);sameTraits(r and Data:SerializeSeedRecord(r),live[id],'reloaded '..id)end

print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
