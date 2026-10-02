--!nocheck
-- R121 server purchases under the Roblox mock: real PremiumService / PremiumRouting / ProductGiftService /
-- PremiumProgress / PassGiftService with stubbed MarketplaceService, DataStoreService and a small fake
-- PlayerDataService (profile saves are deep copies, so save/load is real PremiumProgress.Decode).
-- Run from a folder holding roblox.luau, world.luau and rs_bundle.luau (see run.sh).
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
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name=='Buyer'and'Buyer'or'Friendly';p.UserId=id;p.Parent=Players;present[id]=p
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
local Market=W.service('MarketplaceService');local prompts={};local robux={}
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptProductPurchase=function(_,p,id)prompts[#prompts+1]={p,id}end
Market.GetUsersPriceLevelsAsync=function(_,ids)local out={};for _,id in ipairs(ids)do out[#out+1]={UserId=id,PriceLevel=100}end;return out end
Market.UserOwnsGamePassAsync=function()return false end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
-- Server modules live in ServerScriptService.ChestChaseServer so script.Parent lookups work.
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs({'PremiumService','PremiumRouting','SecurityGate','PassGiftService','PassGiftState','ProductGiftService','ProductGiftState','PremiumProgress','BaseService'})do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
-- Product ids ------------------------------------------------------------------------------------------
local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog');local GiftProducts=W.module('GiftProducts');local Boost=W.module('SpeedBoost')
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
RS.PassGiftCatalog:SetAttribute('GrowthGiftProductId',401);RS.PassGiftCatalog:SetAttribute('SpeedGiftProductId',402);robux[401]=499;robux[402]=449
RS.PremiumPricing:SetAttribute('SpeedBoost10ProductId',501);robux[501]=49
local giftId={}
for i,row in ipairs(GiftProducts.Rows)do
 if row.Key~='CashMega'then giftId[row.Key]=600+i;RS.GiftProducts:SetAttribute(row.Attribute,600+i);robux[600+i]=49 end
end
-- Fake PlayerDataService (+ real PremiumProgress methods) ----------------------------------------
local Progress=server('PremiumProgress')
local notes={}
local Data={Premium={},CanSave={},Loaded={},Saved={},Gardens={},Chests={},Speed={},Cash={},FailSave=false,
 Config={MaxSavedChests=200,GardenPlants={}},Notifications={Show=function(_,p,msg)notes[#notes+1]={P=p,Text=msg}end}}
local function deep(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=deep(v)end;return o end
function Data:IsLoaded(p)return self.Loaded[p]==true end
function Data:MarkDirty()end;function Data:WaitForSave()end;function Data:QueueGardenSave()end;function Data:_gardenChanged()end;function Data:_notifySeedInventory()end
function Data:Save(p)if self.FailSave or not self.Loaded[p]then return false end;self.Saved[p.UserId]={Premium=deep(self:GetPremium(p)),Garden=deep(self.Gardens[p]),Chests=deep(self.Chests[p]),Speed=self.Speed[p]};return true end
function Data:GetCash(p)return self.Cash[p]or 0 end
function Data:GetChestRecords(p)return self.Chests[p]end
function Data:AddChest(p,record)table.insert(self.Chests[p],record);return record end
function Data:GetOrCreateSpeedValue(p)return {Value=self.Speed[p]or 0}end
function Data:AddSpeed(p,n)self.Speed[p]=(self.Speed[p]or 0)+n;return n end
function Data:GetPendingSales(p)return self.Gardens[p].PendingSales or{}end
function Data:GetOrCreateDiscoveredSeeds(p)local f=p:FindFirstChild('DiscoveredSeeds');if not f then f=R.Instance.new('Folder');f.Name='DiscoveredSeeds';f.Parent=p end;return f end
function Data:GetTreadmillData()return {Tier=1}end
Progress.Attach(Data)
function Data:RefreshBiomeRewards()end -- index rewards are out of scope here
-- "Join": decode the last saved profile (or a new one), like PlayerDataService:Load.
local function join(p)
 local saved=Data.Saved[p.UserId]
 local premium=Progress.Decode(saved and deep(saved.Premium)or nil);assert(premium,'premium decode failed')
 Data.Premium[p]=premium;Data.Gardens[p]=saved and deep(saved.Garden)or{PendingSales={}};Data.Chests[p]=saved and deep(saved.Chests)or{};Data.Speed[p]=saved and saved.Speed or 0
 present[p.UserId]=p;p.Parent=Players;Data.Loaded[p]=true;Data.CanSave[p]=true
end
local function leave(p,svc)present[p.UserId]=nil;p.Parent=nil;Data.Loaded[p]=nil;Data.CanSave[p]=nil;Data.Premium[p]=nil;if svc then svc:Cleanup(p)end end
join(buyer);join(friend)
local chests={SyncTools=function()end}
local passes={Refresh=function()end}
local Service=server('PremiumService').new(Data,chests,passes)
local remote=RS.ChestChaseRemotes.PremiumRequest
local function invoke(p,action,value)advance(1);return remote.OnServerInvoke(p,action,value)end
local purchaseN=0
local function receipt(p,id,purchaseId)
 if not purchaseId then purchaseN+=1;purchaseId='purchase-'..purchaseN end
 return Market.ProcessReceipt({ProductId=id,PurchaseId=purchaseId,PlayerId=p.UserId}),purchaseId
end
local Granted=R.Enum.ProductPurchaseDecision.PurchaseGranted;local Later=R.Enum.ProductPurchaseDecision.NotProcessedYet
local function noteFor(p,pattern)for i=#notes,1,-1 do if notes[i].P==p and string.find(notes[i].Text,pattern,1,true)then return notes[i].Text end end;return nil end
local function pendingCash(p)local n=0;for _,r in ipairs(Data.Gardens[p].PendingSales or{})do if r.Currency=='Cash'then n+=r.Amount end end;return n end
local inbox=stores['ChestChase_ProductInbox_v1']
check(inbox~=nil,'product gift inbox DataStore opened')
-- Routing ---------------------------------------------------------------------------------------------
local Routing=server('PremiumRouting')
check(select(1,Routing.Resolve(501))=='Boost','boost id routes to Boost')
for key,id in pairs(giftId)do local kind,k=Routing.Resolve(id);check(kind=='ProductGift'and k==key,'gift id routes '..key)end
check(Routing.Resolve(201)=='Bundle'and Routing.Resolve(301)=='Mech'and Routing.Resolve(401)=='Gift','existing routes unchanged')
check(GiftProducts.ProductId('CashMega')==0,'missing gift id reads 0')
-- State ---------------------------------------------------------------------------------------------
local st=invoke(buyer,'State')
check(st.ProductGifts and st.ProductGifts.CashSmall.Available==true,'State: gift CashSmall available')
check(st.ProductGifts.CashMega.Available==false,'State: gift without id unavailable')
check(st.ProductGifts.MechPack5.Available==true and st.ProductGifts.SpeedBoost10.Available==true,'State: Mech/boost gifts available')
check(st.Boost and st.Boost.Available==true and st.Boost.Remaining==0,'State: boost purchasable, inactive')
-- Gift flow: dialog -> prompt the GIFT product -> receipt -> recipient gets the reward -----------------
prompts={}
local r=invoke(buyer,'RobuxProductGift',{Key='CashSmall',RecipientId=2})
check(r.Success==true,'RobuxProductGift succeeds ('..tostring(r.Message)..')')
check(#prompts==1 and prompts[1][1]==buyer and prompts[1][2]==giftId.CashSmall,'gift product prompted (not the normal product)')
local friendCash=pendingCash(friend);local buyerCash=pendingCash(buyer)
local decision,pid=receipt(buyer,giftId.CashSmall)
check(decision==Granted,'gift receipt granted')
check(pendingCash(friend)==friendCash+30000000000,'recipient received +30B cash ('..pendingCash(friend)..')')
check(pendingCash(buyer)==buyerCash,'buyer did not receive the cash')
check((Data:GetPremium(buyer).ProductGiftCredits.CashSmall or 0)==0,'buyer credit spent on delivery')
check(noteFor(buyer,'Gift sent to Friendly')~=nil,'buyer notified')
check(noteFor(friend,'Buyer gifted you +30B CASH')~=nil,'recipient notified')
-- Idempotent per PurchaseId.
check(receipt(buyer,giftId.CashSmall,pid)==Granted,'duplicate receipt acknowledged')
check(pendingCash(friend)==friendCash+30000000000,'duplicate receipt grants nothing')
check((Data:GetPremium(buyer).ProductGiftCredits.CashSmall or 0)==0,'duplicate receipt adds no credit')
-- Durable chain completes: outbox and inbox clean up after the recovery loop runs.
advance(121) -- R123: gift recovery runs every 60 s (was 15/30 s)
check(next(Data:GetPremium(buyer).ProductOutbox)==nil,'buyer outbox cleared')
check(inbox.Data['2']==nil or next(inbox.Data['2'])==nil,'recipient inbox cleared')
check(next(Data:GetPremium(friend).ProductGiftReceipts)==nil,'recipient receipt marker cleared')
check(pendingCash(friend)==friendCash+30000000000,'no double grant through recovery')
-- Speed bundle + Mech pack gifts.
local speed0=Data.Speed[friend]
invoke(buyer,'RobuxProductGift',{Key='SpeedSmall',RecipientId=2});receipt(buyer,giftId.SpeedSmall)
check(Data.Speed[friend]==speed0+Pricing.Find('SpeedSmall').Amount,'speed bundle gift adds speed to recipient')
local packs=#Data.Chests[friend]
invoke(buyer,'RobuxProductGift',{Key='MechPack5',RecipientId=2});receipt(buyer,giftId.MechPack5)
check(#Data.Chests[friend]==packs+5,'Mech x5 gift adds 5 packs to recipient')
check(Data.Chests[friend][#Data.Chests[friend]].PaidRandom==true,'gifted packs marked paid')
friend:SetAttribute('PaidRandomAllowed',false);prompts={}
r=invoke(buyer,'RobuxProductGift',{Key='MechPack1',RecipientId=2})
check(r.Success==false and #prompts==0,'no Mech gift to a player whose policy blocks paid packs')
friend:SetAttribute('PaidRandomAllowed',true)
-- Missing gift id / bad recipients.
prompts={}
r=invoke(buyer,'RobuxProductGift',{Key='CashMega',RecipientId=2});check(r.Success==false and #prompts==0,'missing gift id: no prompt')
r=invoke(buyer,'RobuxProductGift',{Key='CashSmall',RecipientId=1});check(r.Success==false and #prompts==0,'cannot gift yourself')
r=invoke(buyer,'RobuxProductGift',{Key='CashSmall',RecipientId=99});check(r.Success==false and #prompts==0,'recipient must be in the server')
-- Recipient left before the receipt: the gift is kept as the buyer's credit, then sent later.
invoke(buyer,'RobuxProductGift',{Key='CashMedium',RecipientId=2})
leave(friend,Service)
check(receipt(buyer,giftId.CashMedium)==Granted,'receipt granted while recipient is away')
check(Data:GetPremium(buyer).ProductGiftCredits.CashMedium==1,'gift kept as buyer credit')
check(noteFor(buyer,'gift saved')~=nil or noteFor(buyer,'Gift saved')~=nil,'buyer told the gift is saved')
st=invoke(buyer,'State');check(st.ProductGiftCredits.CashMedium==1,'State reports the saved credit')
join(friend);Service:Setup(friend)
local before=pendingCash(friend)
r=invoke(buyer,'GiftProduct',{Key='CashMedium',RecipientId=2})
check(r.Success==true,'saved credit sent with GiftProduct ('..tostring(r.Message)..')')
check(pendingCash(friend)==before+100000000000,'recipient received the saved gift')
check((Data:GetPremium(buyer).ProductGiftCredits.CashMedium or 0)==0,'credit spent')
r=invoke(buyer,'GiftProduct',{Key='CashMedium',RecipientId=2});check(r.Success==false,'no second send without credit')
-- Recipient offline after the debit: the durable inbox delivers on the next join.
Data:GetPremium(buyer).ProductGiftCredits.Cash=1
local svcGifts=Service.ProductGifts
local origRecover=svcGifts.Recover;local skip=true
svcGifts.Recover=function(self,p)if skip and p==friend then return end;return origRecover(self,p)end
before=pendingCash(friend)
r=invoke(buyer,'GiftProduct',{Key='Cash',RecipientId=2});check(r.Success,'send while recipient about to leave')
leave(friend,Service);skip=false
check(inbox.Data['2']~=nil and next(inbox.Data['2'])~=nil,'gift waits in the durable inbox')
join(friend);Service:Setup(friend)
check(pendingCash(friend)==before+300000000000,'offline recipient receives the gift on rejoin')
svcGifts.Recover=origRecover
-- Save failure: the receipt is not acknowledged (Roblox retries it).
Data.FailSave=true
invoke(buyer,'RobuxProductGift',{Key='SpeedMedium',RecipientId=2})
local d2,pid2=receipt(buyer,giftId.SpeedMedium)
check(d2==Later,'receipt not acknowledged when the save fails')
Data.FailSave=false
check(receipt(buyer,giftId.SpeedMedium,pid2)==Granted,'retried receipt granted')
check(Data:GetPremium(buyer).ProductGiftCredits.SpeedMedium==1,'retried gift receipt credited exactly once')
-- 10-minute x2 boost -----------------------------------------------------------------------------------------
local Base=server('BaseService')
local fakeBase={PlayerData=Data,Config={TreadmillTiers={{Multiplier=1}}}}
local function mult(p)return Base.GetTreadmillMultiplier(fakeBase,p)end
check(mult(buyer)==1,'training x1 without boost')
prompts={}
r=invoke(buyer,'RobuxBoost');check(r.Success==true and #prompts==1 and prompts[1][2]==501,'RobuxBoost prompts the boost product')
check(receipt(buyer,501)==Granted,'boost receipt granted')
local ends=Data:GetPremium(buyer).SpeedBoostEndsAt
check(ends==math.floor(R.clock)+600,'boost sets expiry now+10 min')
check(buyer:GetAttribute('SpeedBoostEndsAt')==ends,'expiry mirrored to player attribute')
check(noteFor(buyer,'x2 Speed boost active')~=nil,'boost notification')
check(mult(buyer)==2,'training x2 during boost')
buyer:SetAttribute('DoubleSpeedOwned',true);check(mult(buyer)==4,'boost stacks with the x2 pass (x4)');buyer:SetAttribute('DoubleSpeedOwned',false)
local _,bpid=receipt(buyer,501)
check(Data:GetPremium(buyer).SpeedBoostEndsAt==ends+600,'second boost extends by 10 min')
check(receipt(buyer,501,bpid)==Granted and Data:GetPremium(buyer).SpeedBoostEndsAt==ends+600,'boost receipt idempotent')
st=invoke(buyer,'State');check(st.Boost.Remaining>=1190 and st.Boost.Remaining<=1200,'State reports remaining boost ('..tostring(st.Boost.Remaining)..')')
for _=1,4 do receipt(buyer,501)end
st=invoke(buyer,'State');check(st.Boost.Available==false,'boost capped at 60 min for new purchases')
prompts={};r=invoke(buyer,'RobuxBoost');check(r.Success==false and #prompts==0,'no prompt when the boost is full')
-- Persists across save/load (expiry in server time).
Data:Save(buyer);local endsSaved=Data:GetPremium(buyer).SpeedBoostEndsAt
leave(buyer,Service);advance(60);join(buyer);Service:Setup(buyer)
check(Data:GetPremium(buyer).SpeedBoostEndsAt==endsSaved,'boost expiry survives rejoin')
check(buyer:GetAttribute('SpeedBoostEndsAt')==endsSaved,'attribute republished on join')
check(mult(buyer)==2,'training x2 after rejoin')
advance(endsSaved-R.clock+1)
check(mult(buyer)==1,'training back to x1 after expiry')
check(Boost.PlayerRemaining(buyer)==0,'client remaining 0 after expiry')
-- Boost gift.
local fEnds=Data:GetPremium(friend).SpeedBoostEndsAt
invoke(buyer,'RobuxProductGift',{Key='SpeedBoost10',RecipientId=2});receipt(buyer,giftId.SpeedBoost10)
check(Data:GetPremium(friend).SpeedBoostEndsAt==math.floor(R.clock)+600 and fEnds==nil,'boost gift starts the recipient boost')
check(mult(friend)==2,'gifted boost doubles the recipient training')
-- Save validation.
local saved=deep(Data.Saved[buyer.UserId].Premium)
saved.SpeedBoostEndsAt='broken';local dec=Progress.Decode(saved)
check(dec~=nil and dec.SpeedBoostEndsAt==nil,'damaged boost expiry is dropped, save kept')
saved=deep(Data.Saved[buyer.UserId].Premium);saved.ProductGiftCredits={Nope=1}
check(Progress.Decode(saved)==nil,'unknown gift credit key rejected like pass gifts')
-- Existing flows untouched ------------------------------------------------------------------------------------
prompts={}
r=invoke(buyer,'RobuxBundle','CashSmall');check(r.Success and prompts[1][2]==201,'RobuxBundle still prompts the normal product')
before=pendingCash(buyer);receipt(buyer,201);check(pendingCash(buyer)==before+30000000000,'normal bundle receipt grants the buyer')
prompts={};r=invoke(buyer,'RobuxPack',1);check(r.Success and prompts[1][2]==301,'RobuxPack still prompts')
prompts={};r=invoke(buyer,'RobuxGift','Speed');check(r.Success and prompts[1][2]==402,'pass gift prompt unchanged')
receipt(buyer,402);check(Data:GetPremium(buyer).GiftCredits.Speed==1,'pass gift receipt still credits GiftCredits')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
