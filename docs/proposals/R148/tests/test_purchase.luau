--!nocheck
-- R148 (owner: "remove this line when purchasing and add the vfx and sfx and also the notification for making a
-- successful purchase"), server half: the real PremiumService, PurchaseAnnouncer, GamePassService, PremiumRouting,
-- PremiumProgress, PassGiftService and SecurityGate on the Roblox mock, with a small fake PlayerDataService (saves are deep
-- copies, so save / load is the real PremiumProgress.Decode), stubbed MarketplaceService / DataStoreService, a recording
-- Notifications stub and a recording RemoteEvent:FireClient.
-- Covers: opening a Robux prompt (bundle / Mech pack / gift) returns NO message while real errors still do; a notice
-- "✅ Purchased: <what>!" plus ChestChaseRemotes.PurchaseDone {Kind, Name} go to the buyer only, once, for every receipt
-- (Mech packs, all 10 bundles, gift credits), every game-pass purchase and every successful gem purchase (BuyPack, BuyBundle,
-- BuyPerk, Convert); never for a duplicate or retried-after-announce receipt, a failed grant / save, a refused gem purchase
-- or an unfinished game-pass prompt; and a broken announcer never touches a purchase.
-- Run from a folder holding roblox.luau, world.luau, rs_bundle.luau and srv_names.luau (see run_purchase.sh).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- Scheduler where task.wait really yields (PassGiftService runs a `while task.wait(15)` loop).
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
-- Services ------------------------------------------------------------------------------------------
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 p:SetAttribute('PaidRandomAllowed',true);return p
end
local buyer=makePlayer(1,'Buyer');local friend=makePlayer(2,'Friend')
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;table.sort(out,function(a,b)return a.UserId<b.UserId end);return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local stores={}
local DS=W.service('DataStoreService')
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},
  UpdateAsync=function(self,key,fn)local v=fn(self.Data[key]);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end}
 return stores[name]
end
W.service('PolicyService').GetPolicyInfoForPlayerAsync=function()return {ArePaidRandomItemsRestricted=false,IsPaidItemTradingAllowed=true}end
-- Every RemoteEvent the server fires at a client is recorded (PurchaseDone is the one under test).
local sent={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(self,p,...)sent[#sent+1]={Remote=self.Name,P=p,Args={...}}end end
 return o end end
local Market=W.service('MarketplaceService');local prompts={};local robux={}
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptProductPurchase=function(_,p,id)prompts[#prompts+1]={p,id}end
Market.GetUsersPriceLevelsAsync=function(_,ids)local out={};for _,id in ipairs(ids)do out[#out+1]={UserId=id,PriceLevel=100}end;return out end
Market.UserOwnsGamePassAsync=function()return false end
Market.PromptGamePassPurchaseFinished=R.signal()
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
-- Server modules live in ServerScriptService.ChestChaseServer so script.Parent lookups work.
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
-- Product ids ------------------------------------------------------------------------------------------
local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog');local Passes=W.module('GamePassCatalog');local Gifts=W.module('PassGiftCatalog')
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
RS.PassGiftCatalog:SetAttribute('GrowthGiftProductId',401);RS.PassGiftCatalog:SetAttribute('SpeedGiftProductId',402);robux[401]=499;robux[402]=449
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102)
-- Fake PlayerDataService (+ real PremiumProgress methods) ----------------------------------------
local Progress=server('PremiumProgress')
local notes={}
local Data={Premium={},CanSave={},Loaded={},Saved={},Gardens={},Chests={},Speed={},Cash={},FailSave=false,
 Config={MaxSavedChests=200,GardenPlants={}},Notifications={Show=function(_,p,msg,color,seconds)notes[#notes+1]={P=p,Text=msg,Color=color,Seconds=seconds}end}}
local function deep(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=deep(v)end;return o end
function Data:IsLoaded(p)return self.Loaded[p]==true end
function Data:MarkDirty()end;function Data:WaitForSave()end;function Data:QueueGardenSave()end;function Data:_gardenChanged()end;function Data:_notifySeedInventory()end
function Data:Save(p)if self.FailSave or not self.Loaded[p]then return false end;self.Saved[p.UserId]={Premium=deep(self:GetPremium(p)),Garden=deep(self.Gardens[p]),Chests=deep(self.Chests[p]),Speed=self.Speed[p]};return true end
function Data:GetCash(p)return self.Cash[p]or 0 end
function Data:SpendCash(p,n)if (self.Cash[p]or 0)<n then return false end;self.Cash[p]-=n;return true end
function Data:GetChestRecords(p)return self.Chests[p]end
function Data:AddChest(p,record)table.insert(self.Chests[p],record);return record end
function Data:GetOrCreateSpeedValue(p)return {Value=self.Speed[p]or 0}end
function Data:AddSpeed(p,n)self.Speed[p]=(self.Speed[p]or 0)+n;return n end
function Data:GetPendingSales(p)return self.Gardens[p].PendingSales or{}end
function Data:GetOrCreateDiscoveredSeeds(p)local f=p:FindFirstChild('DiscoveredSeeds');if not f then f=R.Instance.new('Folder');f.Name='DiscoveredSeeds';f.Parent=p end;return f end
function Data:GetTreadmillData()return {Tier=1}end
Progress.Attach(Data)
function Data:RefreshBiomeRewards()end
local function join(p)
 local saved=Data.Saved[p.UserId]
 local premium=Progress.Decode(saved and deep(saved.Premium)or nil);assert(premium,'premium decode failed')
 Data.Premium[p]=premium;Data.Gardens[p]=saved and deep(saved.Garden)or{PendingSales={}};Data.Chests[p]=saved and deep(saved.Chests)or{};Data.Speed[p]=saved and saved.Speed or 0
 present[p.UserId]=p;p.Parent=Players;Data.Loaded[p]=true;Data.CanSave[p]=true
end
local function leave(p,svc)present[p.UserId]=nil;p.Parent=nil;Data.Loaded[p]=nil;Data.CanSave[p]=nil;Data.Premium[p]=nil;if svc then svc:Cleanup(p)end end
join(buyer);join(friend)
local chests={SyncTools=function()end}
local bases={RefreshTreadmill=function()end,GetPlayerBase=function()return nil end}
local Passes_=server('GamePassService').new(Data,bases,chests)
local Service=server('PremiumService').new(Data,chests,Passes_)
local remote=RS.ChestChaseRemotes.PremiumRequest
local function invoke(p,action,value)advance(1);return remote.OnServerInvoke(p,action,value)end
local purchaseN=0
local function receipt(p,id,purchaseId)
 if not purchaseId then purchaseN+=1;purchaseId='purchase-'..purchaseN end
 return Market.ProcessReceipt({ProductId=id,PurchaseId=purchaseId,PlayerId=p.UserId}),purchaseId
end
local Granted=R.Enum.ProductPurchaseDecision.PurchaseGranted;local Later=R.Enum.ProductPurchaseDecision.NotProcessedYet
-- What was sent to anybody since a mark.
local function mark()return {Sent=#sent,Notes=#notes}end
local function doneSince(m)local out={};for i=m.Sent+1,#sent do if sent[i].Remote=='PurchaseDone'then out[#out+1]=sent[i]end end;return out end
local function notesSince(m)local out={};for i=m.Notes+1,#notes do out[#out+1]=notes[i]end;return out end
-- Exactly one PurchaseDone, to `p` only, naming `kind` / `name`, with the matching notice to `p` only.
local function expectOne(m,p,kind,name,what)
 local done=doneSince(m);local ns=notesSince(m)
 local ok=check(#done==1,what..': exactly one PurchaseDone ('..#done..')')
 if ok then
  check(done[1].P==p,what..': PurchaseDone goes to the buyer only')
  local payload=done[1].Args[1]
  check(type(payload)=='table'and payload.Kind==kind and payload.Name==name,what..': payload {Kind='..kind..', Name='..name..'} (got '..tostring(payload and payload.Kind)..' / '..tostring(payload and payload.Name)..')')
 end
 check(#ns==1 and ns[1].P==p and ns[1].Text=='✅ Bought: '..name..'!',what..': one notice "✅ Bought: '..name..'!" to the buyer (got '..tostring(ns[1]and ns[1].Text)..')')
 return ok
end
local function expectNone(m,what)
 check(#doneSince(m)==0,what..': no PurchaseDone ('..#doneSince(m)..')')
 check(#notesSince(m)==0,what..': no notice ('..#notesSince(m)..')')
end
local function pendingCash(p)local n=0;for _,r in ipairs(Data.Gardens[p].PendingSales or{})do if r.Currency=='Cash'then n+=r.Amount end end;return n end
local function pendingGems(p)local n=0;for _,r in ipairs(Data.Gardens[p].PendingSales or{})do if r.Currency=='Gems'then n+=r.Amount end end;return n end
local Announcer=server('PurchaseAnnouncer')

-- 0. The item names, from the catalogs --------------------------------------------------------------------
check(Announcer.Name('Pack',1)=='1 Mech Pack'and Announcer.Name('Pack',5)=='5 Mech Packs'and Announcer.Name('Pack',10)=='10 Mech Packs','Mech pack names: 1 Mech Pack / 5 Mech Packs / 10 Mech Packs')
check(Announcer.Name('Pack',7)==nil and Announcer.Name('Pack','10')==nil and Announcer.Name('Pack',{})==nil,'an unknown pack count has no name')
local bundleNames={CashSmall='+30B Cash',CashMedium='+100B Cash',Cash='+300B Cash',CashValue='+650B Cash',CashMega='+1.4T Cash',
 SpeedSmall='+250K Speed',SpeedMedium='+1M Speed',Speed='+3M Speed',SpeedValue='+8M Speed',SpeedMega='+25M Speed'}
for _,row in ipairs(Pricing.Bundles)do check(Announcer.Name('Bundle',row.Key)==bundleNames[row.Key],'bundle name '..row.Key..' = '..tostring(bundleNames[row.Key])..' (got '..tostring(Announcer.Name('Bundle',row.Key))..')')end
check(Announcer.Name('Bundle',{Key='CashMega',Amount=1})=='+1.4T Cash','a quote table names its bundle')
check(Announcer.Name('Bundle','Nope')==nil,'an unknown bundle has no name')
check(Announcer.Name('Pass','Growth')=='Double Plant Growth Pass'and Announcer.Name('Pass','Speed')=='Double Speed Pass','pass names')
check(Announcer.Name('Gift','Speed')=='Double Speed Gift'and Announcer.Name('Gift','Growth')=='Double Plant Growth Gift','gift credit names')
check(Announcer.Name('Pass','Nope')==nil and Announcer.Name('Gift','Nope')==nil,'an unknown pass has no name')
check(Announcer.Name('Gems',1)=='1 Gem'and Announcer.Name('Gems',12)=='12 Gems'and Announcer.Name('Gems',9000)=='9,000 Gems','gem names (1 Gem / 12 Gems / 9,000 Gems)')
check(Announcer.Name('Gems',0)==nil and Announcer.Name('Gems',1.5)==nil and Announcer.Name('Gems','5')==nil and Announcer.Name('Gems',0/0)==nil,'a bad gem count has no name')
check(Announcer.Name('Wat',1)==nil,'an unknown kind has no name')
check(RS.ChestChaseRemotes:FindFirstChild('PurchaseDone')~=nil and RS.ChestChaseRemotes.PurchaseDone._class=='RemoteEvent','PurchaseDone is a RemoteEvent under ChestChaseRemotes (one, shared by both services)')
local doneRemotes=0;for _,c in ipairs(RS.ChestChaseRemotes:GetChildren())do if c.Name=='PurchaseDone'then doneRemotes+=1 end end
check(doneRemotes==1,'only one PurchaseDone remote exists even though two services made an announcer')

-- 1. Opening a Robux prompt shows no status line ------------------------------------------------------------
local m=mark()
prompts={};local r=invoke(buyer,'RobuxBundle','CashSmall')
check(r.Success==true and r.Message==nil and#prompts==1 and prompts[1][2]==201,'RobuxBundle: the prompt opens and there is NO message ('..tostring(r.Message)..')')
prompts={};r=invoke(buyer,'RobuxPack',1);check(r.Success==true and r.Message==nil and#prompts==1 and prompts[1][2]==301,'RobuxPack 1: prompt, no message')
prompts={};r=invoke(buyer,'RobuxPack',5);check(r.Success==true and r.Message==nil and prompts[1][2]==302,'RobuxPack 5: prompt, no message')
prompts={};r=invoke(buyer,'RobuxPack',10);check(r.Success==true and r.Message==nil and prompts[1][2]==303,'RobuxPack 10: prompt, no message')
prompts={};r=invoke(buyer,'RobuxGift','Speed');check(r.Success==true and r.Message==nil and#prompts==1 and prompts[1][2]==402,'RobuxGift: prompt, no message')
for _,row in ipairs(Pricing.Bundles)do
 prompts={};r=invoke(buyer,'RobuxBundle',row.Key);check(r.Success==true and r.Message==nil and#prompts==1,'RobuxBundle '..row.Key..': no message')
end
check(r.Message~='Complete the Roblox purchase prompt.','the old "Complete the Roblox purchase prompt." text is gone')
expectNone(m,'opening prompts announces nothing')
-- ...while real errors stay visible.
local promptStub=Market.PromptProductPurchase
Market.PromptProductPurchase=function()error('the prompt could not be shown')end
r=invoke(buyer,'RobuxBundle','CashSmall');check(r.Success==false and r.Message=='Couldn\'t open the purchase. Try again!','RobuxBundle: a prompt that fails to open says "Couldn\'t open the purchase. Try again!"')
r=invoke(buyer,'RobuxPack',1);check(r.Success==false and r.Message=='Couldn\'t open the purchase. Try again!','RobuxPack: a prompt that fails to open says so')
r=invoke(buyer,'RobuxGift','Speed');check(r.Success==false and r.Message=='Couldn\'t open the purchase. Try again!','RobuxGift: a prompt that fails to open says so')
Market.PromptProductPurchase=promptStub
local products=Service.Products.CashSmall;Service.Products.CashSmall={PriceInRobux=49,IsForSale=false}
r=invoke(buyer,'RobuxBundle','CashSmall');check(r.Success==false and r.Message=='CAN\'T BUY THIS RIGHT NOW','an off-sale bundle says CAN\'T BUY THIS RIGHT NOW')
Service.Products.CashSmall=products
r=invoke(buyer,'RobuxBundle','Nope');check(r.Success==false and r.Message=='CAN\'T BUY THIS RIGHT NOW','an unknown bundle says CAN\'T BUY THIS RIGHT NOW')
r=invoke(buyer,'RobuxPack',7);check(r.Success==false and r.Message=='CAN\'T BUY THIS RIGHT NOW','an unknown pack count says CAN\'T BUY THIS RIGHT NOW')
r=invoke(buyer,'RobuxGift','Nope');check(r.Success==false and r.Message=='CAN\'T GIFT THIS RIGHT NOW','an unknown gift says CAN\'T GIFT THIS RIGHT NOW')
r=invoke(buyer,'Nonsense');check(r.Success==false and r.Message=='TRY AGAIN!','an unknown action keeps TRY AGAIN!')
Data.CanSave[buyer]=false;r=invoke(buyer,'RobuxPack',1);check(r.Success==false and r.Message=='NO PURCHASES UNTIL UR DATA CAN SAVE','no-save data keeps its message');Data.CanSave[buyer]=true
expectNone(m,'refused prompts announce nothing')

-- 2. Robux receipts: one PurchaseDone + one notice per granted receipt ----------------------------------------------
for i,count in ipairs({1,5,10})do
 m=mark();local d,id=receipt(buyer,300+i)
 check(d==Granted,'Mech receipt x'..count..' is granted')
 expectOne(m,buyer,'Pack',Announcer.Name('Pack',count),'Mech receipt x'..count)
end
check(#Data.Chests[buyer]==16,'the three Mech receipts granted 1+5+10 packs ('..#Data.Chests[buyer]..')')
local n=notes[#notes]
check(n.Color.R==150/255 and n.Color.G==1 and n.Color.B==110/255 and n.Seconds==4,'the notice is light green and shown for 4 seconds')
for i,row in ipairs(Pricing.Bundles)do
 m=mark();local d=receipt(buyer,200+i)
 check(d==Granted,'bundle receipt '..row.Key..' is granted')
 expectOne(m,buyer,'Bundle',bundleNames[row.Key],'bundle receipt '..row.Key)
end
check(pendingCash(buyer)==30000000000+100000000000+300000000000+650000000000+1400000000000,'the five cash bundles queued their Cash')
m=mark();check(receipt(buyer,401)==Granted,'gift credit receipt (Growth) is granted')
expectOne(m,buyer,'Gift','Double Plant Growth Gift','gift credit receipt Growth')
m=mark();check(receipt(buyer,402)==Granted,'gift credit receipt (Speed) is granted')
expectOne(m,buyer,'Gift','Double Speed Gift','gift credit receipt Speed')
check(Data:GetPremium(buyer).GiftCredits.Growth==1 and Data:GetPremium(buyer).GiftCredits.Speed==1,'both gift credits were stored')
-- The friend buys too: only the friend is told.
m=mark();check(receipt(friend,303)==Granted,'the friend\'s Mech receipt is granted')
expectOne(m,friend,'Pack','10 Mech Packs','friend receipt')

-- 3. A duplicate / retried receipt never announces again ---------------------------------------------------------------
m=mark();local d1,sameId=receipt(buyer,201)
check(d1==Granted,'first delivery granted');expectOne(m,buyer,'Bundle','+30B Cash','first delivery of a receipt')
local cashBefore,chestsBefore=pendingCash(buyer),#Data.Chests[buyer]
m=mark();local d2=receipt(buyer,201,sameId)
check(d2==Granted,'a duplicate delivery of a granted receipt is acknowledged');expectNone(m,'duplicate receipt')
m=mark();receipt(buyer,201,sameId);receipt(buyer,201,sameId);expectNone(m,'duplicate receipt again and again')
check(pendingCash(buyer)==cashBefore,'a duplicate never grants twice')
local _,mechId=receipt(buyer,301);chestsBefore=#Data.Chests[buyer]
m=mark();check(receipt(buyer,301,mechId)==Granted,'a duplicate Mech receipt is acknowledged');expectNone(m,'duplicate Mech receipt')
check(#Data.Chests[buyer]==chestsBefore,'a duplicate Mech receipt gives no second pack')
local _,giftId=receipt(buyer,402);m=mark();receipt(buyer,402,giftId);expectNone(m,'duplicate gift-credit receipt')
-- A receipt Roblox re-delivers after the rejoin (saved profile has it) is a duplicate too.
local _,savedId=receipt(buyer,202)
leave(buyer,Service);join(buyer)
m=mark();check(receipt(buyer,202,savedId)==Granted,'a saved receipt re-delivered after a rejoin is acknowledged');expectNone(m,'saved receipt after a rejoin')

-- 4. Failed grants and failed saves never announce ---------------------------------------------------------------------
m=mark();check(receipt(buyer,501)==Later,'an unknown product is not granted');expectNone(m,'unknown product')
m=mark();check(Market.ProcessReceipt({ProductId='x',PurchaseId='p',PlayerId=1})==Later and Market.ProcessReceipt({})==Later,'a malformed receipt is not granted');expectNone(m,'malformed receipt')
-- Bag full: the Mech packs do not fit.
local bag=Data.Chests[buyer];local keep=bag;Data.Chests[buyer]={};for i=1,200 do Data.Chests[buyer][i]={}end
m=mark();check(receipt(buyer,303)==Later,'Mech packs that do not fit are not granted');expectNone(m,'Mech receipt with a full Bag')
Data.Chests[buyer]=keep
-- Cash bundle with no room for another floating reward.
local pendingKeep=Data.Gardens[buyer].PendingSales;local limit=W.module('SaleReceiptRules').MaxReceipts
Data.Gardens[buyer].PendingSales={};for i=1,limit do Data.Gardens[buyer].PendingSales[i]={Id='x'..i,Currency='Gems',Amount=1,Count=3,Claimed=0}end
m=mark();check(receipt(buyer,201)==Later,'a Cash bundle with no room for a floating reward is not granted');expectNone(m,'Cash bundle without room')
Data.Gardens[buyer].PendingSales=pendingKeep
-- Gift credits at the cap.
local credits=Data:GetPremium(buyer).GiftCredits;local creditKeep=credits.Speed;credits.Speed=Gifts.MaxCredits
m=mark();check(receipt(buyer,402)==Later,'a gift credit past the cap is not granted');expectNone(m,'gift credit at the cap')
credits.Speed=creditKeep
-- Grant code that throws.
local realGrant=Data.GrantPremiumBundle;Data.GrantPremiumBundle=function()error('boom')end
m=mark();check(receipt(buyer,203)==Later,'a grant that throws is not acknowledged');expectNone(m,'grant that throws')
Data.GrantPremiumBundle=realGrant
-- Player data not ready / busy.
Data.CanSave[buyer]=false;m=mark();check(receipt(buyer,203)==Later,'a receipt while the data cannot save is not granted');expectNone(m,'data cannot save');Data.CanSave[buyer]=true
Data.Loaded[buyer]=nil;m=mark();check(receipt(buyer,203)==Later,'a receipt while the data is loading is not granted');expectNone(m,'data loading');Data.Loaded[buyer]=true
Service.Busy[buyer]=true;m=mark();check(receipt(buyer,203)==Later,'a receipt while another is being processed waits');expectNone(m,'busy buyer');Service.Busy[buyer]=nil
present[buyer.UserId]=nil;m=mark();check(receipt(buyer,203)==Later,'a receipt for a player who left is not granted');expectNone(m,'buyer gone');present[buyer.UserId]=buyer
-- The save fails: not acknowledged, not announced; the retry that finally saves announces ONCE.
Data.FailSave=true
local packsBefore=#Data.Chests[buyer]
m=mark();local dFail,failId=receipt(buyer,302)
check(dFail==Later,'a receipt whose save fails is not acknowledged');expectNone(m,'save fails')
check(#Data.Chests[buyer]==packsBefore+5,'the packs were granted in memory on the first try')
m=mark();check(receipt(buyer,302,failId)==Later,'the retry while the save still fails waits again');expectNone(m,'save still failing')
check(#Data.Chests[buyer]==packsBefore+5,'a retry never grants the packs twice')
Data.FailSave=false
m=mark();check(receipt(buyer,302,failId)==Granted,'the retry that saves is acknowledged')
expectOne(m,buyer,'Pack','5 Mech Packs','the retry that finally saves')
check(#Data.Chests[buyer]==packsBefore+5,'...and still only one grant of packs')
m=mark();check(receipt(buyer,302,failId)==Granted,'one more delivery is acknowledged');expectNone(m,'delivery after the announcement')
-- The save fails, the buyer leaves, and the receipt comes back in a new session: it is granted again from the saved
-- profile, and announced once there (the first session never told them anything).
Data.FailSave=true;m=mark();local _,lostId=receipt(buyer,303);expectNone(m,'save fails (before the buyer leaves)')
Data.FailSave=false
leave(buyer,Service);join(buyer)
local packsAfterRejoin=#Data.Chests[buyer]
m=mark();check(receipt(buyer,303,lostId)==Granted,'the unsaved receipt is granted from the saved profile after a rejoin')
expectOne(m,buyer,'Pack','10 Mech Packs','receipt after a rejoin that lost it')
check(#Data.Chests[buyer]==packsAfterRejoin+10,'...once')
m=mark();receipt(buyer,303,lostId);expectNone(m,'and its duplicate')
-- Cleanup forgets what was owed (no leak).
Data.FailSave=true;receipt(buyer,201);Data.FailSave=false
check(next(Service.Unannounced[buyer]or{})~=nil,'a receipt waiting for its save is remembered')
Service:Cleanup(buyer);check(Service.Unannounced[buyer]==nil,'Cleanup forgets the player\'s unannounced receipts')

-- 5. Gem purchases ----------------------------------------------------------------------------------------------------
Data:GetPremium(buyer).Gems=100000;Data.Cash[buyer]=5e13
m=mark();r=invoke(buyer,'BuyPack',1)
check(r.Success==true and r.Message==nil,'BuyPack: succeeds and its "added to your bag" line is replaced by the notice ('..tostring(r.Message)..')');expectOne(m,buyer,'Pack','1 Mech Pack','BuyPack 1')
m=mark();r=invoke(buyer,'BuyPack',5);expectOne(m,buyer,'Pack','5 Mech Packs','BuyPack 5')
m=mark();r=invoke(buyer,'BuyPack',10);expectOne(m,buyer,'Pack','10 Mech Packs','BuyPack 10')
check(Data:GetPremium(buyer).Gems==100000-80-375-700,'the Gems were spent ('..Data:GetPremium(buyer).Gems..')')
-- refusals
m=mark();r=invoke(buyer,'BuyPack',7);check(r.Success==false and r.Message=='TRY AGAIN!','BuyPack 7 is refused with its message');expectNone(m,'BuyPack with a bad quantity')
local gems=Data:GetPremium(buyer).Gems;Data:GetPremium(buyer).Gems=10
m=mark();r=invoke(buyer,'BuyPack',1);check(r.Success==false and r.Message=='NOT ENOUGH GEMS','BuyPack without Gems says NOT ENOUGH GEMS');expectNone(m,'BuyPack without Gems')
Data:GetPremium(buyer).Gems=gems
RS.MechCatalog:SetAttribute('SaleEnabled',false)
m=mark();r=invoke(buyer,'BuyPack',1);check(r.Success==false and r.Message=='THIS PACK IS OFF SALE','BuyPack off sale says so');expectNone(m,'BuyPack off sale')
RS.MechCatalog:SetAttribute('SaleEnabled',nil)
local keepBag=Data.Chests[buyer];Data.Chests[buyer]={};for i=1,200 do Data.Chests[buyer][i]={}end
m=mark();r=invoke(buyer,'BuyPack',1);check(r.Success==false and r.Message:find('MAKE ROOM')~=nil,'BuyPack with a full Bag says MAKE ROOM');expectNone(m,'BuyPack with a full Bag')
Data.Chests[buyer]=keepBag
-- BuyBundle
local function quote(key)return Data:BundleQuote(buyer,key)end
m=mark();r=invoke(buyer,'BuyBundle',quote('SpeedSmall'))
check(r.Success==true and r.Message==nil,'BuyBundle Speed: succeeds, its "Speed added!" line is replaced by the notice ('..tostring(r.Message)..')');expectOne(m,buyer,'Bundle','+250K Speed','BuyBundle SpeedSmall')
m=mark();r=invoke(buyer,'BuyBundle','SpeedMega');expectOne(m,buyer,'Bundle','+25M Speed','BuyBundle SpeedMega (by key)')
m=mark();r=invoke(buyer,'BuyBundle',quote('CashMega'))
check(r.Success==true and r.Message=='Grab ur Cash!','BuyBundle Cash keeps its "Grab ur Cash!" hint (it tells the buyer what to do)');expectOne(m,buyer,'Bundle','+1.4T Cash','BuyBundle CashMega')
m=mark();r=invoke(buyer,'BuyBundle',{Key='CashSmall',Amount=1,GemPrice=1});check(r.Success==false and r.Message=='The offer changed! Check the new amount.','a stale quote is refused');expectNone(m,'BuyBundle with a stale quote')
m=mark();r=invoke(buyer,'BuyBundle','Nope');check(r.Success==false and r.Message=='NOT AVAILABLE RIGHT NOW','an unknown bundle is refused');expectNone(m,'BuyBundle unknown')
Data:GetPremium(buyer).Gems=5
m=mark();r=invoke(buyer,'BuyBundle',quote('Speed'));check(r.Success==false and r.Message=='NOT ENOUGH GEMS','BuyBundle without Gems says NOT ENOUGH GEMS');expectNone(m,'BuyBundle without Gems')
Data:GetPremium(buyer).Gems=gems
-- BuyPerk
m=mark();r=invoke(buyer,'BuyPerk','Growth')
check(r.Success==true and r.Message==nil,'BuyPerk: succeeds, its "unlocked." line is replaced by the notice ('..tostring(r.Message)..')');expectOne(m,buyer,'Pass','Double Plant Growth Pass','BuyPerk Growth')
m=mark();r=invoke(buyer,'BuyPerk','Growth');check(r.Success==false and r.Message=='U ALREADY HAVE THIS!','a second BuyPerk says U ALREADY HAVE THIS!');expectNone(m,'BuyPerk twice')
m=mark();r=invoke(buyer,'BuyPerk','Nope');check(r.Success==false and r.Message=='TRY AGAIN!','BuyPerk unknown says TRY AGAIN!');expectNone(m,'BuyPerk unknown')
Data:GetPremium(buyer).Gems=3
m=mark();r=invoke(buyer,'BuyPerk','Speed');check(r.Success==false and r.Message=='NOT ENOUGH GEMS','BuyPerk without Gems says NOT ENOUGH GEMS');expectNone(m,'BuyPerk without Gems')
Data:GetPremium(buyer).Gems=gems
m=mark();r=invoke(buyer,'BuyPerk','Speed');expectOne(m,buyer,'Pass','Double Speed Pass','BuyPerk Speed')
-- Convert (Cash -> Gems): a purchase of Gems; its "Collect your Gems." hint stays
m=mark();r=invoke(buyer,'Convert',12)
check(r.Success==true and r.Message=='Grab ur Gems!','Convert keeps its "Grab ur Gems!" hint');expectOne(m,buyer,'Gems','12 Gems','Convert 12')
m=mark();r=invoke(buyer,'Convert',1);expectOne(m,buyer,'Gems','1 Gem','Convert 1')
m=mark();r=invoke(buyer,'Convert',9001);check(r.Success==false and r.Message=='TYPE A WHOLE NUMBER OF GEMS','Convert 9001 is refused');expectNone(m,'Convert out of range')
m=mark();r=invoke(buyer,'Convert',2.5);check(r.Success==false,'Convert 2.5 is refused');expectNone(m,'Convert fractional')
Data.Cash[buyer]=5
m=mark();r=invoke(buyer,'Convert',3);check(r.Success==false and r.Message=='NOT ENOUGH CASH','Convert without Cash says NOT ENOUGH CASH');expectNone(m,'Convert without Cash')
Data.Cash[buyer]=5e13
-- Other actions that are not purchases announce nothing.
m=mark();invoke(buyer,'State');invoke(buyer,'ClaimSeed','Nope');invoke(buyer,'Nonsense');expectNone(m,'State / a refused claim / an unknown action')

-- 6. Game passes bought with Robux (GamePassService) -------------------------------------------------------------------
m=mark();Market.PromptGamePassPurchaseFinished:Fire(buyer,101,true)
expectOne(m,buyer,'Pass','Double Plant Growth Pass','game pass purchase (Growth)')
check(buyer:GetAttribute('DoubleGrowthOwned')==true,'the pass is switched on as before')
m=mark();Market.PromptGamePassPurchaseFinished:Fire(buyer,102,true);expectOne(m,buyer,'Pass','Double Speed Pass','game pass purchase (Speed)')
m=mark();Market.PromptGamePassPurchaseFinished:Fire(friend,102,true);expectOne(m,friend,'Pass','Double Speed Pass','game pass purchase by the friend')
m=mark();Market.PromptGamePassPurchaseFinished:Fire(buyer,101,false);Market.PromptGamePassPurchaseFinished:Fire(buyer,102,false);expectNone(m,'a game-pass prompt that was cancelled')
m=mark();Market.PromptGamePassPurchaseFinished:Fire(buyer,999,true);expectNone(m,'a game-pass id that is not ours')
local gone=makePlayer(9,'Gone');gone.Parent=nil
m=mark();Market.PromptGamePassPurchaseFinished:Fire(gone,101,true);expectNone(m,'a buyer who already left')

-- 7. A broken announcer never touches a purchase -------------------------------------------------------------------------
local noticeStub=Data.Notifications.Show
Data.Notifications.Show=function()error('notifications are down')end
local fireStub=Service.Announcer.Remote.FireClient
Service.Announcer.Remote.FireClient=function()error('the remote is gone')end
m=mark();local d=receipt(buyer,203);check(d==Granted,'a receipt is still granted when the notice and the event both fail')
check(#doneSince(m)==0,'(nothing was delivered)')
m=mark();r=invoke(buyer,'BuyPack',1);check(r.Success==true and r.Message=='Mech pack is in ur bag!','a gem purchase still succeeds, and keeps its confirmation line when no celebration could be sent')
Service.Announcer.Remote.FireClient=fireStub;Data.Notifications.Show=noticeStub
m=mark();Data.Notifications.Show=nil;d=receipt(buyer,204);check(d==Granted,'a receipt is granted when Notifications has no Show')
check(#doneSince(m)==1 and doneSince(m)[1].Args[1].Name=='+650B Cash','... and the event still goes (the notice is best effort)');Data.Notifications.Show=noticeStub
-- A missing module only means no celebration.
local savedAnnouncer=folder.PurchaseAnnouncer;savedAnnouncer.Parent=nil
local warnsBefore=W.warns or 0
local Bare=server('PremiumService').new(Data,chests,Passes_)
check(Bare.Announcer==nil,'with PurchaseAnnouncer missing the service starts without an announcer')
check((W.warns or 0)>warnsBefore,'... and says so in the Output')
savedAnnouncer.Parent=folder
local bareReceipt=Bare:ProcessReceipt({ProductId=203,PurchaseId='bare-1',PlayerId=buyer.UserId})
check(bareReceipt==Granted,'... and purchases are still granted')
-- The announcer never fires for a missing player / empty text.
check(Service.Announcer:Announce(nil,'Pack',1)==false and Service.Announcer:Announce(gone,'Pack',1)==false and Service.Announcer:Announce(buyer,'Pack',99)==false,'Announce refuses a missing player, a player who left and an unknown item')

print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
