--!nocheck
-- R121 server purchases under the Roblox mock: real PremiumService / PremiumRouting /
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
for _,n in ipairs({'PremiumService','PremiumRouting','SecurityGate','PassGiftService','PassGiftState','PremiumProgress','BaseService'})do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
-- Product ids ------------------------------------------------------------------------------------------
local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog');
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
RS.PassGiftCatalog:SetAttribute('GrowthGiftProductId',401);RS.PassGiftCatalog:SetAttribute('SpeedGiftProductId',402);robux[401]=499;robux[402]=449
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
-- R123: the R121 product gifts and 10-minute x2 boost are removed (their modules were deleted from the place).
local Routing=server('PremiumRouting')
check(select(1,Routing.Resolve(201))=='Bundle'and select(1,Routing.Resolve(301))=='Mech'and select(1,Routing.Resolve(402))=='Gift','bundle/Mech/pass-gift ids still route')
check(Routing.Resolve(501)==nil and Routing.Resolve(601)==nil,'old boost / product-gift ids route nowhere')
local st=invoke(buyer,'State')
check(st.Success==true and st.Boost==nil and st.ProductGifts==nil and st.ProductGiftCredits==nil,'State has no boost or product gifts')
local r=invoke(buyer,'RobuxBoost');check(r.Success==false and r.Message=='TRY AGAIN!','RobuxBoost is gone')
r=invoke(buyer,'RobuxProductGift',{Key='CashSmall',RecipientId=2});check(r.Success==false and r.Message=='TRY AGAIN!','RobuxProductGift is gone')
r=invoke(buyer,'GiftProduct',{Key='CashSmall',RecipientId=2});check(r.Success==false and r.Message=='TRY AGAIN!','GiftProduct is gone')
check(receipt(buyer,501)==Later,'a receipt for an unknown product is not granted')
local Base=server('BaseService')
local fakeBase={PlayerData=Data,Config={TreadmillTiers={{Multiplier=1}}}}
check(Base.GetTreadmillMultiplier(fakeBase,buyer)==1,'training stays x1 (no timed boost)')
-- Old saves that still hold R121 fields load fine and keep the fields untouched.
local old=deep(Data:GetPremium(buyer));old.SpeedBoostEndsAt=os.time()+600;old.ProductGiftCredits={CashSmall=1};old.ProductOutbox={x={RecipientId=2,Key='CashSmall',State='Pending'}};old.ProductGiftReceipts={y=true}
local dec=Progress.Decode(old)
check(dec~=nil and dec.ProductGiftCredits.CashSmall==1 and dec.SpeedBoostEndsAt==old.SpeedBoostEndsAt,'old R121 save fields decode and are kept')
Data.Premium[buyer]=dec;check(Base.GetTreadmillMultiplier(fakeBase,buyer)==1,'a saved boost no longer doubles training')
local before
-- Existing flows untouched ------------------------------------------------------------------------------------
prompts={}
r=invoke(buyer,'RobuxBundle','CashSmall');check(r.Success and prompts[1][2]==201,'RobuxBundle still prompts the normal product')
before=pendingCash(buyer);receipt(buyer,201);check(pendingCash(buyer)==before+30000000000,'normal bundle receipt grants the buyer')
prompts={};r=invoke(buyer,'RobuxPack',1);check(r.Success and prompts[1][2]==301,'RobuxPack still prompts')
prompts={};r=invoke(buyer,'RobuxGift','Speed');check(r.Success and prompts[1][2]==402,'pass gift prompt unchanged')
receipt(buyer,402);check(Data:GetPremium(buyer).GiftCredits.Speed==1,'pass gift receipt still credits GiftCredits')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
