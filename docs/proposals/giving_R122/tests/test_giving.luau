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
function Remote.FireClient(_,p,action,msg,info)fired[#fired+1]={P=p,Action=action,Text=msg,Info=info}end
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
 local t=R.new('Tool');t.Name=record.Kind=='Pack'and'Test Pack'or'Test Seed'
 if record.Kind=='Pack'then t:SetAttribute('SeedPackTool',true)else t:SetAttribute('GardenSeed',true)end
 t:SetAttribute('SeedInventoryId',record.Id);t.Parent=p.Character;return t
end
local function holdFruit(p,crop)local t=R.new('Tool');t.Name='Golden Apple';t:SetAttribute('HarvestItemTool',true);t:SetAttribute('HarvestInventoryId',crop.Id);t.Parent=p.Character;return t end
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
local recv=lastFor(B);check(recv and recv.Action=='Received'and recv.Text=='🎁 Alice gave you Test Pack!','recipient notified with giver and item (R130): '..tostring(recv and recv.Text))
local sent=false;for _,f in ipairs(fired)do if f.P==A and f.Text and f.Text:find('Gift sent to Bob')then sent=true end end
check(sent,'giver notified')
advance(121) -- acknowledgements finish on the background recovery loop (R123: every 60 s, two passes)
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
recv=lastFor(B);check(recv and recv.Text=='🎁 Alice gave you Test Seed!','seed receipt notice names the seed: '..tostring(recv and recv.Text))

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

-- 8b. R152: a free giveaway pack (record.GiftLocked) can't be gifted: not by the give click (OfferSeed), not by an offer that reaches AcceptSeed; an ordinary pack still can
do
 local free=Data:AddChest(A,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',GiftLocked=true});local freeTool=hold(A,free)
 check(free.GiftLocked==true,'R152: the fixture giveaway pack is GiftLocked')
 local outbox0=0;for _ in pairs(Data.Gardens[A].OutgoingSeedGifts or{})do outbox0+=1 end
 local beforeA,beforeB=seedRecords(A),seedRecords(B)
 local accepts,rawAccept=0,Gifts.Accept;Gifts.Accept=function(...)accepts+=1;return rawAccept(...)end -- (a refusal in OfferSeed itself never makes an offer to accept)
 send(A,'GiveSeed',B,free.Id)
 Gifts.Accept=rawAccept
 local told=lastFor(A)
 check(accepts==0,'R152: OfferSeed refuses it before any offer is made ('..accepts..' offers reached Accept)')
 check(find(A,free.Id)~=nil and find(B,free.Id)==nil and freeTool.Parent==A.Character,'R152: OfferSeed refuses a GiftLocked pack: the giver keeps it (and still holds it)')
 check(told and told.Action=='Status'and told.Text=="Free giveaway packs can't be gifted",'R152: ... with a short clear notice ('..tostring(told and told.Text)..')')
 local outbox1=0;for _ in pairs(Data.Gardens[A].OutgoingSeedGifts or{})do outbox1+=1 end
 check(outbox1==outbox0 and seedRecords(A)==beforeA and seedRecords(B)==beforeB,'R152: ... nothing staged, nothing moved')
 -- an offer that already exists (made before the pack was locked, or forged): AcceptSeed refuses too
 local before=#fired;local offerId='locked-offer-1'
 Gifts.Offers[offerId]={From=A,To=B,ItemId=free.Id,Kind='Seed',Expires=math.huge}
 task2.spawn(function()Gifts:Accept(B,offerId)end);advance(5)
 local refusal;for i=before+1,#fired do if fired[i].P==A and fired[i].Text=="Free giveaway packs can't be gifted"then refusal=fired[i]end end
 check(find(A,free.Id)~=nil and find(B,free.Id)==nil and refusal~=nil,'R152: AcceptSeed refuses a GiftLocked pack too (same notice to the giver)')
 check(seedRecords(A)==beforeA and seedRecords(B)==beforeB and Gifts.Offers[offerId]==nil,'R152: ... nothing moved, the offer is gone')
 -- an ordinary Void pack (the track\'s) is still a gift, and arrives unlocked
 local own=Data:AddChest(A,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None'});hold(A,own)
 send(A,'GiveSeed',B,own.Id)
 local got2=find(B,own.Id);check(got2 and find(A,own.Id)==nil and got2.GiftLocked==nil,'R152: an ordinary Void pack can still be gifted')
 -- tidy up so later sections see the same inventory
 for i,r in ipairs(Data:GetChestRecords(A))do if r.Id==free.Id then table.remove(Data:GetChestRecords(A),i);break end end;freeTool:Destroy()
 for i,r in ipairs(Data:GetChestRecords(B))do if r.Id==own.Id then table.remove(Data:GetChestRecords(B),i);break end end
 Data:_notifySeedInventory(A);Data:_notifySeedInventory(B)
end

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
-- R131: the receiver's client shows the notice and plays the chime from the 'Received' event (no second server notice).
local shown={};Gifts.Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
holdFruit(A,fruit);send(A,'Give',B,fruitId)
Gifts.Notes=nil
local fa=false;for _,c in ipairs(Data.Gardens[A].Harvests)do if c.Id==fruitId then fa=true end end
local fb;for _,c in ipairs(Data.Gardens[B].Harvests)do if c.Id==fruitId then fb=c end end
check(not fa and fb~=nil and #Data.Gardens[B].Harvests==hb+1,'fruit moved to recipient')
check(fb and fb.Value==fruitValue,'fruit value preserved')
recv=lastFor(B);check(recv and recv.Action=='Received'and recv.Text=='🎁 Alice gave you Golden Apple!'and recv.Info and recv.Info.From=='Alice'and recv.Info.Item=='Golden Apple','fruit receipt names giver and item: '..tostring(recv and recv.Text))
check(#shown==0,'no duplicate server notice')
local fs=false;for _,f in ipairs(fired)do if f.P==A and f.Text and f.Text:find('Gift sent to Bob! (Golden Apple)',1,true)then fs=true end end
check(fs,'fruit giver told the gift was sent (R130)')
advance(31)
check(next(Data.Gardens[A].OutgoingGifts)==nil,'fruit outbox cleaned')
local fruitBox;for name,s in pairs(stores)do if name:find('FruitInbox')then fruitBox=s end end
local fb2=fruitBox and fruitBox.Data[tostring(B.UserId)];check(fb2==nil or next(fb2)==nil,'fruit inbox cleaned')
-- A seed id sent through the fruit action does nothing.
local p8=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,p8)
send(A,'Give',B,p8.Id);check(find(A,p8.Id)~=nil,'pack id via the fruit action is ignored')

-- R131 gifting fixes ------------------------------------------------------------------------------------
do
 local Service=server('FruitGiftService')
 -- Every inbox read skips the DataStore read cache.
 local optsSeen={}
 for name,st in pairs(stores)do if name:find('Inbox')then local get=st.GetAsync
  st.GetAsync=function(self,key,opts)optsSeen[#optsSeen+1]=opts;return get(self,key)end end end
 -- Studio test players have negative UserIds (Player1 = -1, Player2 = -2).
 local S1=makePlayer(-1,'Player1',200);local S2=makePlayer(-2,'Player2',206)
 Service.SetStudio(true)
 local sp=Data:AddChest(S1,{Stage=2,BagVariant='Pack02',PackSize=1});hold(S1,sp)
 send(S1,'GiveSeed',S2,sp.Id)
 check(find(S1,sp.Id)==nil and find(S2,sp.Id)~=nil,'Studio: Player1 gives a pack to Player2 (negative UserIds)')
 local r=lastFor(S2);check(r and r.Action=='Received'and r.Info and r.Info.From=='Player1','Studio: Player2 is notified')
 Service.SetStudio(false)
 local sp2=Data:AddChest(S1,{Stage=2,BagVariant='Pack02',PackSize=1});hold(S1,sp2)
 send(S1,'GiveSeed',S2,sp2.Id);check(find(S1,sp2.Id)~=nil,'live servers still refuse ids <= 0')
 check(Service.ValidUserId(5)and not Service.ValidUserId(0)and not Service.ValidUserId(-3)and not Service.ValidUserId(1.5),'id rules (live)')
 -- Refusals say why instead of doing nothing.
 local function statusFor(p)for i=#fired,1,-1 do if fired[i].P==p and fired[i].Action=='Status'then return fired[i].Text end end end
 local q=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1});hold(A,q)
 Data.CanSave[B]=false;send(A,'GiveSeed',B,q.Id)
 check(find(A,q.Id)~=nil and(statusFor(A)or''):find("Bob's save is not ready",1,true),'receiver without a save: giver is told ('..tostring(statusFor(A))..')')
 Data.CanSave[B]=true;Data.CanSave[A]=false;Service.SetStudio(true);send(A,'GiveSeed',B,q.Id)
 check(find(A,q.Id)~=nil and(statusFor(A)or''):find('Studio API access',1,true),'Studio without saving: told to turn on API access')
 Data.CanSave[A]=true;Service.SetStudio(false)
 Chase.Busy[B]=true;send(A,'GiveSeed',B,q.Id);Chase.Busy[B]=nil
 check(find(A,q.Id)~=nil and(statusFor(A)or''):find('in a run',1,true),'receiver in a run: giver is told')
 blockLine=true;send(A,'GiveSeed',B,q.Id);blockLine=false
 check(find(A,q.Id)~=nil and(statusFor(A)or''):find('Something is between you',1,true),'blocked line of sight: giver is told')
 -- A gift save or inbox check in progress is waited out instead of refusing the click.
 Gifts.Working[B]=true;task2.spawn(function()task2.wait(1.5);Gifts.Working[B]=nil end)
 send(A,'GiveSeed',B,q.Id)
 check(find(A,q.Id)==nil and find(B,q.Id)~=nil,'gift goes through after the receiver\'s inbox check finishes')
 -- A gift that lands during the receiver's inbox check is picked up right after it.
 Gifts.Working[B]=true;Gifts:Recover(B);check(Gifts.Again and Gifts.Again[B]==true,'skipped inbox check is queued again')
 Gifts.Working[B]=nil;recover(B);advance(1)
 check(Gifts.Again[B]==nil,'and runs once more right after')
 local uncached=false;for _,o in ipairs(optsSeen)do if type(o)=='table'and o.UseCache==false then uncached=true end end
 check(uncached,'inbox reads skip the 4 s read cache')
end

-- 12. Reload round trip: the recipient's saved items decode to the same traits ---------------------------
Data:Save(B,'final',true)
local live={};for _,r in ipairs(Data:GetChestRecords(B))do live[r.Id]=Data:SerializeSeedRecord(r)end
Data:PreparePlayer(B);check(Data:Load(B),'recipient reloads')
for _,id in ipairs({pack.Id,seed.Id,mech.Id})do local r=find(B,id);sameTraits(r and Data:SerializeSeedRecord(r),live[id],'reloaded '..id)end

-- R126 (owner): bought Mech packs roll a pack size like world packs; the seed inside follows it (1x stays scale 1).
do
 local PackRules=W.module('SeedPackRules');local want={};for _,row in ipairs(PackRules.PackSizes)do want[row.Scale]=row.Weight/100 end
 local n,count,bad=6000,{},0
 for _=1,n do
  local rec=Data:GrantMechPack(C,true)
  if not(rec and rec.BagVariant=='MechLimited'and want[rec.PackSize]and rec.SeedScale==PackRules.NewSeedScale(8,'MechLimited',rec.PackSize))then bad+=1 end
  if rec then count[rec.PackSize]=(count[rec.PackSize]or 0)+1;Data:RemoveChest(C,rec.Id)end
 end
 check(bad==0,'R126: every Mech pack gets a world-table size and matching seed scale ('..bad..' bad)')
 local big=0;for s,c in pairs(count)do if s>1 then big+=c end end
 local share=(count[1]or 0)/n
 check(math.abs(share-want[1])<5*math.sqrt(want[1]*(1-want[1])/n),string.format('R126: ~%.1f%% of Mech packs are 1x (got %.1f%%)',want[1]*100,share*100))
 check(big>0 and(count[.5]or 0)>0,'R126: Mech sizes vary both ways ('..big..' bigger, '..tostring(count[.5])..' half-size)')
 check(PackRules.NewSeedScale(8,'MechLimited',1)==1 and PackRules.NewSeedScale(8,'MechLimited',2.5)==2.5 and PackRules.NewSeedScale(8,'MechLimited',.5)==.5,'R126: Mech seed scale 1x=1, 2.5x=2.5, 0.5x=0.5')
 local five=Data:GrantMechPacks(C,true,5)
 check(five and #five==5,'R126: a 5-pack purchase still grants 5 packs')
 if five then for _,r in ipairs(five)do Data:RemoveChest(C,r.Id)end end
 local big25=Data:AddChest(C,{Stage=8,BagVariant='MechLimited',PackSize=2.5,PackMutation='None'});big25.PaidRandom=true
 local opened=Data:OpenSeedPack(C,big25.Id,function()return .5 end)
 check(opened and opened.Kind=='Seed'and opened.SeedScale==2.5,'R126: opening a 2.5x Mech pack gives a 2.5x seed ('..tostring(opened and opened.SeedScale)..')')
 if opened then Data:RemoveChest(C,opened.Id)end
end
-- R132 (owner): the Fruit of the Hour sells for x1.5 to x3 (single sale, sell all, and the price the sell menu shows).
do
 local Hour=W.module('FruitOfHour')
 local slot=1
 local function grow(p)
  local fp=Data:AddChest(p,{Stage=1,BagVariant='Pack01',PackSize=1});Data:OpenSeedPack(p,fp.Id,function()return .1 end)
  slot+=1;local s=find(p,fp.Id);local ok,c=Data:PlantSeed(p,slot,s.Id,{OffsetX=0,OffsetZ=0},os.time())
  assert(ok,'R132 fixture plant: '..tostring(c));assert(Data:HarvestPlant(p,slot,c.Id,c.ReadyAt+1),'R132 fixture harvest')
  return Data.Gardens[p].Harvests[#Data.Gardens[p].Harvests]
 end
 Data.Gardens[A].Harvests={};Data.Gardens[A].PendingSales={}
 local crop=grow(A)
 local hot,cold
 for h=480000,480000+24*60 do local c=Hour.At(h*3600);if c.SeedId==crop.SeedId and not hot then hot=c end;if c.SeedId~=crop.SeedId and not cold then cold=c end end
 check(hot and cold,'R132 fixture: an hour with and one without this fruit')
 local realNow=W.workspace.GetServerTimeNow;local clock=hot.StartsAt+60
 W.workspace.GetServerTimeNow=function()return clock end
 local want=math.floor(crop.Value*hot.Multiplier+.5)
 local listed;for _,g in ipairs(Data:GetHarvestInventory(A))do if g.InventoryId==crop.Id then listed=g end end
 check(listed and listed.SellValue==want and listed.HourMultiplier==hot.Multiplier,('R132: sell menu lists the bonus price (%s -> %s, x%.1f)'):format(crop.Value,tostring(listed and listed.SellValue),hot.Multiplier))
 local ok,paid=Data:SellHarvest(A,crop.Id)
 local receipt=Data.Gardens[A].PendingSales[#Data.Gardens[A].PendingSales]
 check(ok and paid==want and receipt and receipt.Amount==want,('R132: selling the Fruit of the Hour pays the bonus (%s, receipt %s)'):format(tostring(paid),tostring(receipt and receipt.Amount)))
 Data.Gardens[A].PendingSales={}
 local c2=grow(A);clock=cold.StartsAt+60
 local ok2,paid2=Data:SellHarvest(A,c2.Id)
 check(ok2 and paid2==c2.Value,'R132: in another hour the same fruit sells for its normal price')
 local listed2;Data.Gardens[A].PendingSales={};local c3=grow(A);local c4=grow(A)
 for _,g in ipairs(Data:GetHarvestInventory(A))do if g.InventoryId==c3.Id then listed2=g end end -- (c3 only: two fruits roll their own sizes, so c4's price is not c3's)
 check(listed2 and listed2.SellValue==c3.Value and listed2.HourMultiplier==nil,'R132: no bonus shown outside its hour')
 clock=hot.StartsAt+3000
 local ok3,total,count=Data:SellAllHarvests(A)
 local wantAll=math.floor(c3.Value*hot.Multiplier+.5)+math.floor(c4.Value*hot.Multiplier+.5)
 check(ok3 and total==wantAll and count==2,('R132: sell all adds the bonus to each fruit (%s, want %s)'):format(tostring(total),wantAll))
 Data.Gardens[A].PendingSales={}
 -- /test fruithour (owner test): a chosen fruit and bonus for 10 minutes, then back to the clock.
 local Cmd=server('StudioTestCommands');local studio=Run.IsStudio;Run.IsStudio=function()return true end
 local ctx={Data=Data,Chase=Chase,Chests=Chests};clock=cold.StartsAt+10
 local name=Hour.Name(crop.SeedId)
 local okc,msgc=Cmd.Execute(ctx,A,'/test fruithour '..name..' 2.5')
 local forced=Hour.At(clock)
 check(okc and forced.SeedId==crop.SeedId and forced.Multiplier==2.5 and forced.Test,'R132: /test fruithour '..name..' 2.5 -> '..tostring(msgc))
 local c5=grow(A);local ok5,paid5=Data:SellHarvest(A,c5.Id)
 check(ok5 and paid5==math.floor(c5.Value*2.5+.5),'R132: the test fruit sells for the test bonus ('..tostring(paid5)..')')
 Data.Gardens[A].PendingSales={}
 clock+=601;check(Hour.At(clock).SeedId==cold.SeedId and not Hour.At(clock).Test,'R132: the test ends after 10 minutes')
 clock-=601;okc=Cmd.Execute(ctx,A,'/test fruithour off')
 check(okc and RS:GetAttribute('FruitOfHourTest')==nil and Hour.At(clock).SeedId==cold.SeedId,'R132: fruithour off goes back to the clock')
 check(not Cmd.Execute(ctx,A,'/test fruithour '..name..' 9'),'R132: a bonus over x3 is refused')
 check(not Cmd.Execute(ctx,A,'/test fruithour no such fruit'),'R132: an unknown fruit is refused')
 check(not Cmd.Execute(ctx,A,'/test fruithour '..name..' @Bob'),'R132: fruithour is server-wide (no @target)')
 local okr,msgr=Cmd.Execute(ctx,A,'/test fruithour');check(okr and Hour.At(clock).Test and Hour.At(clock).Multiplier==3,'R132: plain fruithour picks a fruit at x3: '..tostring(msgr))
 Cmd.Execute(ctx,A,'/test fruithour off');Run.IsStudio=studio
 W.workspace.GetServerTimeNow=realNow
end
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
