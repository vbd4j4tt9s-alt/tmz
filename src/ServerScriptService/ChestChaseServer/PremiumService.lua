local RS=game:GetService('ReplicatedStorage');local Players=game:GetService('Players')
local Market=game:GetService('MarketplaceService');local Policy=game:GetService('PolicyService')
local Catalog=require(RS.MechCatalog);local Pricing=require(RS.PremiumPricing)
local Gifts=require(RS.PassGiftCatalog);local Routing=require(script.Parent.PremiumRouting);local Gate=require(script.Parent.SecurityGate)
-- R123: the R121 gift products and 10-minute boost were removed (GiftProducts / SpeedBoost deleted).
local Service={};Service.__index=Service
local MAX_RECEIPTS=20000
-- R148: the "✅ Purchased: ...!" notice + PurchaseDone event. A missing or broken module only means no celebration; a purchase never depends on it.
local function announcer(data)
 local okay,made=pcall(function()return require(script.Parent.PurchaseAnnouncer).new(data)end)
 if okay then return made end
 warn('[R148] purchase feedback is unavailable: '..tostring(made));return nil
end
local function receiptSpace(state)
 local count=0;for _ in pairs(state.Receipts)do count+=1;if count>=MAX_RECEIPTS then return false end end;return true
end
local function productInfo(id,remote)
 for attempt=1,4 do
  if not remote.Parent then return nil end
  local okay,info=pcall(Market.GetProductInfoAsync,Market,id,Enum.InfoType.Product)
  if okay and type(info)=='table'and type(info.PriceInRobux)=='number'then return info end
  if attempt<4 then task.wait(attempt*2)end
 end
 return nil
end
local function productsChanged()
 RS:SetAttribute('PremiumProductsRevision',(RS:GetAttribute('PremiumProductsRevision')or 0)+1)
end
function Service:LoadProduct(id,publish,retryDelay)
 if not self.Remote.Parent then return end
 local info=productInfo(id,self.Remote)
 if not self.Remote.Parent then return end
 if info then publish(info);productsChanged();return end
 -- One delayed retry per unavailable product; ready offers keep their cached metadata.
 local delay=retryDelay or 15
 task.delay(delay,function()self:LoadProduct(id,publish,math.min(delay*2,300))end)
end
function Service.new(data,chests,passes)
 local remote=Instance.new('RemoteFunction');remote.Name='PremiumRequest';remote.Parent=RS:WaitForChild('ChestChaseRemotes')
 local self=setmetatable({Data=data,Chests=chests,Passes=passes,Last={},Busy={},Unannounced={},Announcer=announcer(data),Product=nil,PackProducts={},Products={},GiftProducts={},Gifts=require(script.Parent.PassGiftService).new(data,passes),Remote=remote},Service)
 remote.OnServerInvoke=function(p,action,value)
  if not Gate.Allow(p,'PremiumRequest',action,value)then return {Success=false,Message='Please wait.'}end
  if not data:IsLoaded(p)then return {Success=false,Message='YOUR DATA IS LOADING'}end
  if action=='Tutorial'then
   self.Last[p]=self.Last[p]or{};local now=os.clock()
   if now-(self.Last[p].Tutorial or-10)<.2 then return {Success=false}end;self.Last[p].Tutorial=now
   if value~='State'and not data:TutorialAction(p,value)then return {Success=false}end
   data:PublishTutorial(p)
   -- R138: finishing the tutorial (the last slides) earns the free 2x-luck Forest pack, once per account.
   if(value=='TreadmillInfo'or value=='Skip')and p:GetAttribute('TutorialDone')==true then
    local gift=data:GrantStarterPack(p)
    if gift then
     pcall(function()chests:SyncTools(p)end)
     if data.Notifications then data.Notifications:Show(p,require(RS.BeginnerGuide).StarterPack.Notice,Color3.fromRGB(150,255,110),5)end
    end
   end
   return require(script.Parent.TutorialTargets).State(data,chests,p)
  end
  -- R140: the DAILY panel: value 'State', 'ClaimLogin' or {Quest=index}. Claims need a profile that can save.
  if action=='Daily'then
   self.Last[p]=self.Last[p]or{};local now=os.clock()
   if now-(self.Last[p].Daily or-10)<.3 then return {Success=false,Message='TRY AGAIN IN A MOMENT'}end;self.Last[p].Daily=now
   if value=='State'then return data:DailyState(p)end
   if not data.CanSave[p]then local state=data:DailyState(p);state.Success=false;state.Message='NO REWARDS UNTIL UR DATA CAN SAVE';return state end
   local okay,message
   if value=='ClaimLogin'then
    okay,message=data:ClaimDailyLogin(p)
    if okay then pcall(function()chests:SyncTools(p)end)end -- day 7: the Mech pack lands in the hotbar
   elseif type(value)=='table'then okay,message=data:ClaimDailyQuest(p,value.Quest)
   else okay,message=false,'UNKNOWN ACTION'end
   local state=data:DailyState(p);state.Success=okay==true;state.Message=message;return state
  end
  if action=='SettingsState'or action=='SetSetting'then
   local config=require(RS.SettingsConfig);local state=data:GetPremium(p);state.Settings=config.Read(state.Settings)
   if action=='SettingsState'then return {Success=true,Settings=state.Settings}end
   if type(value)~='table'or not config.Valid(value.Key,value.Value)then return {Success=false,Message='Invalid setting.'}end
   self.Last[p]=self.Last[p]or{};local now=os.clock()
   if now-(self.Last[p].Settings or-10)<.12 then return {Success=false,Message='Please try again.'}end
   self.Last[p].Settings=now;state.Settings[value.Key]=value.Value;data:MarkDirty(p);data:QueueGardenSave(p)
   return {Success=true}
  end
  local now=os.clock();local key=action=='State'and'State'or'Action';self.Last[p]=self.Last[p]or{}
  if now-(self.Last[p][key]or-10)<(key=='State'and .35 or .65)then return {Success=false,Message='TRY AGAIN IN A MOMENT'}end
  self.Last[p][key]=now
  if action=='State'then
   data:RefreshBiomeRewards(p)
   local missing=false;for _,pass in ipairs(require(RS.GamePassCatalog))do if p:GetAttribute(pass.Key..'OwnershipReady')~=true then missing=true;break end end
   if missing and data.CanSave[p]and now-(self.Last[p].Ownership or -30)>=15 then
    self.Last[p].Ownership=now;task.spawn(function()passes:Refresh(p)end)
   end
   return self:State(p)
  end
  if not data.CanSave[p]then return {Success=false,Message='PURCHASES ARE UNAVAILABLE UNTIL YOUR DATA CAN SAVE'}end
  if(action=='RobuxBundle'or action=='RobuxGift'or action=='RobuxPack')and not receiptSpace(data:GetPremium(p))then
   local state=self:State(p);state.Success=false;state.Message='ROBUX PURCHASES ARE UNAVAILABLE FOR THIS SAVE';return state
  end
  local okay,message
  if action=='ClaimSeed'then okay,message=data:ClaimIndexSeed(p,value)
  elseif action=='ClaimBiome'then okay,message=data:ClaimIndexBiome(p,value)
  elseif action=='ClaimBiomeHalf'then okay,message=data:ClaimIndexBiomeHalf(p,value)
  elseif action=='Convert'then okay,message=data:ConvertGems(p,value)
  elseif action=='BuyPack'then okay,message=data:BuyMechPack(p,value);if okay then chests:SyncTools(p)end
  elseif action=='BuyBundle'then okay,message=data:BuyPremiumBundle(p,value)
  elseif action=='RobuxBundle'then
   local row=Pricing.Find(value);local info=row and self.Products[row.Key];local id=row and Pricing.ProductId(row)or 0
   local route,routed=Routing.Resolve(id)
   if row and route=='Bundle'and routed==row.Key and info and info.IsForSale~=false and data:CanReceiveBundle(p,row.Key)then
    okay=pcall(Market.PromptProductPurchase,Market,p,id);message=not okay and'Purchase could not open.'or nil -- R148: the opened prompt needs no status line
   else okay=false;message='THIS PURCHASE IS UNAVAILABLE'end
  elseif action=='GiftPass'then
   if type(value)=='table'then okay,message=self.Gifts:Send(p,value.Key,value.RecipientId,value.Payment)else okay=false;message='Choose a gift.'end
  elseif action=='RobuxGift'then
   local pass=type(value)=='string'and Gifts.Pass(value);local info=pass and self.GiftProducts[value];local id=pass and Gifts.ProductId(value)or 0
   local route,routed=Routing.Resolve(id);local credits=data:GetPremium(p).GiftCredits
   if pass and route=='Gift'and routed==value and info and info.IsForSale~=false and(credits[value]or 0)<Gifts.MaxCredits then
    okay=pcall(Market.PromptProductPurchase,Market,p,id);message=not okay and'Purchase could not open.'or nil -- R148: the opened prompt needs no status line
   else okay=false;message='THIS GIFT PURCHASE IS UNAVAILABLE'end
  elseif action=='BuyPerk'then okay,message=data:BuyGemPerk(p,value);if okay then task.spawn(function()passes:Refresh(p)end)end
  elseif action=='RobuxPack'then
   local offer=Catalog.Offer(value);local count=offer and offer.Count
   local entry=count and self:State(p).PackOffers[tostring(count)]
   local id=Catalog.ProductId(value);local route,routed=Routing.Resolve(id)
   if entry and entry.RobuxAvailable and route=='Mech'and routed==count and data:CanReceiveMechPacks(p,count)then
    okay=pcall(Market.PromptProductPurchase,Market,p,id);message=not okay and'Purchase could not open.'or nil -- R148: the opened prompt needs no status line
   else okay=false;message='THIS PURCHASE IS UNAVAILABLE'end
  else okay=false;message='UNKNOWN ACTION'end
  -- R148: a gem purchase that went through gets the notice, chime and sparkles; their confirmation line is then redundant
  -- (the "Collect your Gems / Cash." hints stay: they tell the buyer what to do next).
  if okay==true then
   if action=='BuyPack'then if self:Announce(p,'Pack',value)then message=nil end
   elseif action=='BuyBundle'then
    local row=Pricing.Find(type(value)=='table'and value.Key or value)
    if row and self:Announce(p,'Bundle',row.Key)and row.Kind=='Speed'then message=nil end
   elseif action=='BuyPerk'then if self:Announce(p,'Pass',value)then message=nil end
   elseif action=='Convert'then self:Announce(p,'Gems',value)end
  end
  local state=self:State(p);state.Success=okay==true;state.Message=message;return state
 end
 Market.ProcessReceipt=function(receipt)return self:ProcessReceipt(receipt)end
 for _,offer in ipairs(Catalog.Offers)do
  local id=Catalog.ProductId(offer.Count);local route,count=Routing.Resolve(id)
  if route=='Mech'and count==offer.Count then task.spawn(function()
   self:LoadProduct(id,function(info)self.PackProducts[offer.Count]=info;if offer.Count==1 then self.Product=info end end)
  end)end
 end
 for _,row in ipairs(Pricing.Bundles)do
  local id=Pricing.ProductId(row)
  if id>0 and id~=Catalog.ProductId()and Pricing.ProductKey(id)==row.Key then task.spawn(function()
   self:LoadProduct(id,function(info)self.Products[row.Key]=info end)
  end)end
 end
 for _,pass in ipairs(require(RS.GamePassCatalog))do
  local id=Gifts.ProductId(pass.Key);local route,key=Routing.Resolve(id)
  if route=='Gift'and key==pass.Key then task.spawn(function()
   self:LoadProduct(id,function(info)self.GiftProducts[pass.Key]=info end)
  end)end
 end
 return self
end
function Service:Setup(player)
 player:SetAttribute('PaidRandomAllowed',false);player:SetAttribute('PaidTradingAllowed',false)
 local okay,result=pcall(Policy.GetPolicyInfoForPlayerAsync,Policy,player)
 if not player.Parent then return end
 if okay and type(result)=='table'then
  player:SetAttribute('PaidRandomAllowed',result.ArePaidRandomItemsRestricted==false)
  player:SetAttribute('PaidTradingAllowed',result.IsPaidItemTradingAllowed==true)
 end
 self.Data:PublishPremium(player);self.Data:RefreshBiomeRewards(player);self.Gifts:Recover(player)
end
function Service:State(player)
 local state=self.Data:GetPremium(player);local bundles={};local giftProducts={};local offers={}
 local saveReady=self.Data:IsLoaded(player)and self.Data.CanSave[player]==true
 local robuxReady=saveReady and receiptSpace(state)
 for _,offer in ipairs(Catalog.Offers)do
  local count=offer.Count;local info=(self.PackProducts or{})[count]
  local route,key=Routing.Resolve(Catalog.ProductId(count))
  local allowed=saveReady and Catalog.OnSale()and player:GetAttribute('PaidRandomAllowed')==true and self.Data:CanReceiveMechPacks(player,count)
  offers[tostring(count)]={Count=count,GemPrice=offer.GemPrice,GemAvailable=allowed,
   RobuxAvailable=allowed and robuxReady and route=='Mech'and key==count and info~=nil and info.IsForSale~=false,
   RobuxPrice=info and info.PriceInRobux}
 end
 for _,row in ipairs(Pricing.Bundles)do
  local info=(self.Products or{})[row.Key];local route,key=Routing.Resolve(Pricing.ProductId(row));local quote=self.Data:BundleQuote(player,row.Key)
  bundles[row.Key]={Available=robuxReady and route=='Bundle'and key==row.Key and info~=nil and info.IsForSale~=false and self.Data:CanReceiveBundle(player,row.Key),
   Amount=quote and quote.Amount,GemPrice=quote and quote.GemPrice,RobuxAmount=row.Amount}
 end
 for _,pass in ipairs(require(RS.GamePassCatalog))do local route,key=Routing.Resolve(Gifts.ProductId(pass.Key));local info=(self.GiftProducts or{})[pass.Key];giftProducts[pass.Key]={Available=robuxReady and route=='Gift'and key==pass.Key and info~=nil and info.IsForSale~=false}end
 return {PackOffers=offers,GiftProducts=giftProducts,GiftCredits=state.GiftCredits,Bundles=bundles,Success=true,Gems=state.Gems,Cash=self.Data:GetCash(player),GemPrice=Catalog.GemPrice,CashPerGem=Catalog.CashPerGem,
  OnSale=Catalog.OnSale(),GemPackAvailable=offers['1'].GemAvailable,RobuxPrice=self.Product and self.Product.PriceInRobux,
  RobuxAvailable=offers['1'].RobuxAvailable,
  PendingSales=self.Data:GetPendingSales(player),Entitlements=state.Entitlements,BiomeRewards=state.Biomes}
end
function Service:ProcessReceipt(receipt)
 local later=Enum.ProductPurchaseDecision.NotProcessedYet
 if type(receipt)~='table'or type(receipt.ProductId)~='number'or type(receipt.PurchaseId)~='string'or #receipt.PurchaseId<1 or #receipt.PurchaseId>100 then return later end
 local kind,key=Routing.Resolve(receipt.ProductId);if not kind then return later end
 local mech=kind=='Mech';local bundle=kind=='Bundle'and key or nil;local fresh=false
 local player=Players:GetPlayerByUserId(receipt.PlayerId)
 if not player or not self.Data:IsLoaded(player)or not self.Data.CanSave[player]or self.Busy[player]then return later end
 self.Busy[player]=true
 -- R148: receipts granted in memory whose buyer has not been told yet (the save may fail and the retry finishes the job).
 -- An entry is made once, when the grant happens, and removed when it is announced, so a duplicate never announces twice.
 local owed=self.Unannounced[player];if not owed then owed={};self.Unannounced[player]=owed end
 local okay,decision=pcall(function()
  local state=self.Data:GetPremium(player)
  if not state.Receipts[receipt.PurchaseId]then
   if not receiptSpace(state)then return later end
   local granted
   if mech then granted=self.Data:GrantMechPacks(player,true,key)
   elseif bundle then granted=self.Data:GrantPremiumBundle(player,bundle)
   else
    if(state.GiftCredits[key]or 0)>=Gifts.MaxCredits then return later end
    state.GiftCredits[key]=(state.GiftCredits[key]or 0)+1;granted=true
   end
   if not granted then return later end
   -- Pack and receipt enter the same profile transaction. Never acknowledge before a successful save.
   state.Receipts[receipt.PurchaseId]=true;self.Data:MarkDirty(player);fresh=true
   owed[receipt.PurchaseId]=mech and{'Pack',key}or bundle and{'Bundle',bundle}or{'Gift',key}
  end
  self.Data:WaitForSave(player,5)
  if not self.Data:Save(player,'PremiumProductReceipt',true)then return later end
  if mech then self.Chests:SyncTools(player)end
  self.Data:PublishPremium(player)
  return Enum.ProductPurchaseDecision.PurchaseGranted
 end)
 self.Busy[player]=nil
 local result=okay and decision or later
 if result==Enum.ProductPurchaseDecision.PurchaseGranted then
  local item=owed[receipt.PurchaseId]
  if item then owed[receipt.PurchaseId]=nil;self:Announce(player,item[1],item[2])end
 end
 return result
end
-- R148: true when the buyer was sent PurchaseDone (and the notice).
function Service:Announce(player,kind,arg)
 return self.Announcer~=nil and self.Announcer:Announce(player,kind,arg)==true
end
function Service:Notify(player,message)
 local n=self.Data.Notifications;if n and player.Parent then pcall(n.Show,n,player,message,nil,4)end
end
function Service:Cleanup(player)self.Last[player]=nil;self.Unannounced[player]=nil;self.Gifts:Cleanup(player)end
return Service
