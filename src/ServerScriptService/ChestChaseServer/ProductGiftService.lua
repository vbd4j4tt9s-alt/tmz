-- R121: gift versions of every shop developer product (cash/speed bundles, Mech packs, x2 Speed boost).
-- Same durable chain as R79 pass gifts, with its own DataStore:
--  receipt -> saved buyer credit (idempotent per PurchaseId in PremiumService) -> saved debit/outbox
--  -> durable recipient inbox -> saved grant on the recipient -> acknowledgement.
-- A paid gift is never lost: if the chosen recipient left, the credit stays with the buyer and the
-- shop's gift dialog shows "Send gift · N ready"; inbox gifts wait for offline recipients.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local DS=game:GetService('DataStoreService')
local Http=game:GetService('HttpService');local Market=game:GetService('MarketplaceService')
local Catalog=require(RS.GiftProducts);local Mech=require(RS.MechCatalog)
local S={};S.__index=S
S.IntentSeconds=900
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
local function userId(n)return type(n)=='number'and n==n and n%1==0 and n>0 and n<9007199254740991 end
function S.new(data,chests,passGifts)
 local self=setmetatable({Data=data,Chests=chests,PassGifts=passGifts,Busy={},Working={},Intent={},Warned={},
  Store=DS:GetDataStore('ChestChase_ProductInbox_v1'..(game:GetService('RunService'):IsStudio()and'_Studio'or''))},S)
 task.spawn(function()while task.wait(15)do for _,p in ipairs(Players:GetPlayers())do task.spawn(function()self:Recover(p)end)end end end)
 return self
end
function S:Ready(p)return p and p.Parent and self.Data:IsLoaded(p)and self.Data.CanSave[p]end
function S:Save(p,reason)self.Data:WaitForSave(p,5);return self:Ready(p)and self.Data:Save(p,reason,true)end
function S:Notify(p,message)
 local n=self.Data.Notifications
 if n and p and p.Parent then pcall(n.Show,n,p,message,nil,4)end
end
-- Can this player be given this product right now (bag space, currency limit, pack policy)?
function S:CanReceive(p,key)
 local row=Catalog.Find(key);if not row or not self:Ready(p)then return false,'Player unavailable.'end
 if row.Kind=='Bundle'then local ok,why=self.Data:CanReceiveBundle(p,row.Key);return ok==true,why end
 if row.Kind=='Mech'then
  if p:GetAttribute('PaidRandomAllowed')~=true then return false,'Packs cannot be gifted to this player.'end
  local ok,why=self.Data:CanReceiveMechPacks(p,row.Count);return ok==true,why
 end
 return true
end
function S:Grant(p,key)
 local row=Catalog.Find(key);if not row then return false end
 if row.Kind=='Bundle'then local ok,why=self.Data:GrantPremiumBundle(p,row.Key);return ok==true,why end
 if row.Kind=='Mech'then
  local added,why=self.Data:GrantMechPacks(p,true,row.Count)
  if added and self.Chests then pcall(self.Chests.SyncTools,self.Chests,p)end
  return added~=nil,why
 end
 return self.Data:ExtendSpeedBoost(p)
end
-- Buyer chose a recipient in the gift dialog: remember it, then open the gift product prompt.
function S:Prompt(from,key,recipientId)
 local row=Catalog.Find(key);if not row then return false,'THIS GIFT PURCHASE IS UNAVAILABLE'end
 if not userId(recipientId)then return false,'Choose a player.'end
 local to=Players:GetPlayerByUserId(recipientId)
 if not to or to==from or not self:Ready(from)or not self:Ready(to)then return false,'Choose a player in this server.'end
 if row.Kind=='Mech'and(from:GetAttribute('PaidRandomAllowed')~=true or not Mech.OnSale())then return false,'THIS GIFT PURCHASE IS UNAVAILABLE'end
 if(self.Data:GetPremium(from).ProductGiftCredits[key]or 0)>=Catalog.MaxCredits then return false,'Send your saved gifts first.'end
 local ok,why=self:CanReceive(to,key)
 if not ok then return false,to.DisplayName..' cannot receive this right now'..(type(why)=='string'and(': '..why)or'.')end
 local allowed,reason=self.PassGifts:PriceLevelAllowed(from,to)
 if not allowed then return false,reason end
 if not self:Ready(from)or not self:Ready(to)then return false,'Player unavailable.'end
 self.Intent[from]={Key=key,RecipientId=recipientId,At=os.clock()}
 local opened=pcall(Market.PromptProductPurchase,Market,from,Catalog.ProductId(key))
 return opened,opened and'Complete the Roblox purchase prompt.'or'Purchase could not open.'
end
-- Called once after a fresh gift receipt was saved and acknowledged.
function S:AfterReceipt(from,key)
 local intent=self.Intent[from];local name=Catalog.Name(key)
 if intent and intent.Key==key and os.clock()-intent.At<=S.IntentSeconds then
  local to=Players:GetPlayerByUserId(intent.RecipientId)
  if to and to~=from then
   for _=1,10 do if not self.Busy[from]and not self.Working[from]then break end;task.wait(.5)end
   local ok,message=self:Send(from,key,intent.RecipientId)
   if ok then self:Notify(from,message);return true end
   self:Notify(from,'Gift saved ('..tostring(message)..') Send it from the shop.');return false
  end
 end
 self:Notify(from,name..' gift saved! Press its gift button in the shop to send it.')
 return false
end
-- Sends one saved credit to a player in this server.
function S:Send(from,key,recipientId)
 local row=Catalog.Find(key)
 if not row or not userId(recipientId)then return false,'Choose a player.'end
 local to=Players:GetPlayerByUserId(recipientId)
 if not to or to==from or not self:Ready(from)or not self:Ready(to)or self.Busy[from]or self.Working[from]then return false,'Player unavailable.'end
 self.Busy[from]=true
 local okay,success,message=pcall(function()
  local allowed,reason=self.PassGifts:PriceLevelAllowed(from,to)
  if not allowed then return false,reason end
  if not self:Ready(from)or not self:Ready(to)then return false,'Player unavailable.'end
  local can,why=self:CanReceive(to,key)
  if not can then return false,to.DisplayName..' cannot receive this right now'..(type(why)=='string'and(': '..why)or'.')end
  local state=self.Data:GetPremium(from)
  if count(state.ProductOutbox)>=Catalog.MaxOutbox then return false,'Pending gifts are still saving.'end
  if(state.ProductGiftCredits[key]or 0)<1 then return false,'No purchased gift ready.'end
  local id=Http:GenerateGUID(false)
  -- Debit and outbox insertion never yield in between.
  state.ProductGiftCredits[key]-=1;if state.ProductGiftCredits[key]==0 then state.ProductGiftCredits[key]=nil end
  state.ProductOutbox[id]={RecipientId=recipientId,Key=key,State='Pending'};self.Data:MarkDirty(from);self.Data:PublishPremium(from)
  if not self:Save(from,'ProductGiftDebit')then return true,'Gift pending. Delivery retries automatically.'end
  for attempt=1,3 do
   local box=self:QueueInbox(from,recipientId,key,id)
   if box and box[id]then return true,'Gift sent to '..to.DisplayName..'!'end
   if attempt<3 then task.wait(attempt)end
  end
  return true,'Gift pending. Delivery retries automatically.'
 end)
 self.Busy[from]=nil
 if okay and success then task.spawn(function()self:Recover(from);self:Recover(to)end)end
 return okay and success==true,okay and message or'Gift pending. Please try again shortly.'
end
function S:ChangeInbox(id,change)
 local okay,result=pcall(self.Store.UpdateAsync,self.Store,tostring(id),function(old)
  if old~=nil and type(old)~='table'then return nil end
  local box=clone(old or{});if change(box)==false then return nil end;return box
 end)
 return okay and type(result)=='table'and result or nil
end
function S:QueueInbox(from,recipientId,key,id)
 local fromId=type(from)=='number'and from or from.UserId
 local fromName=type(from)~='number'and string.sub(from.DisplayName,1,40)or nil
 return self:ChangeInbox(recipientId,function(inbox)
  if not inbox[id]then if count(inbox)>=Catalog.MaxInbox then return false end;inbox[id]={State='Ready',From=fromId,FromName=fromName,Key=key}end
  return true
 end)
end
function S:Recover(p)
 if not self:Ready(p)or self.Busy[p]or self.Working[p]then return end;self.Working[p]=true
 local okay,why=pcall(function()
  local state=self.Data:GetPremium(p)
  if next(state.ProductOutbox)and not self:Save(p,'ProductGiftOutbox')then return end
  for id,gift in pairs(state.ProductOutbox)do
   if not self:Ready(p)or self.Data:GetPremium(p)~=state then return end
   if gift.State=='Pending'then
    local box=self:QueueInbox(p.UserId,gift.RecipientId,gift.Key,id)
    if box and box[id]and(box[id].State=='Delivered'or box[id].State=='Final')then
     gift.State='Acked';self.Data:MarkDirty(p);if not self:Save(p,'ProductGiftAcknowledge')then return end
    end
   end
   if gift.State=='Acked'then
    local box=self:ChangeInbox(gift.RecipientId,function(inbox)if inbox[id]then inbox[id].State='Final'end end)
    if box then state.ProductOutbox[id]=nil;self.Data:MarkDirty(p);if not self:Save(p,'ProductGiftComplete')then return end end
   end
  end
  local read,inbox=pcall(self.Store.GetAsync,self.Store,tostring(p.UserId));if not read or type(inbox)~='table'then return end
  for id,gift in pairs(inbox)do
   if not self:Ready(p)or self.Data:GetPremium(p)~=state then return end
   if type(gift)~='table'or not Catalog.Find(gift.Key)or type(id)~='string'or #id>100 then continue end
   if gift.State=='Ready'then
    local fresh=false
    if not state.ProductGiftReceipts[id]then
     if count(state.ProductGiftReceipts)>=Catalog.MaxInbox then continue end
     -- A full bag / currency limit keeps the gift waiting in the inbox; it is retried every 15 s.
     local can=self:CanReceive(p,gift.Key)
     if not can then
      if not self.Warned[p]then self.Warned[p]=true;self:Notify(p,'You have a gift waiting! Make room to receive '..Catalog.Name(gift.Key)..'.')end
      continue
     end
     local granted=self:Grant(p,gift.Key)
     if not granted then continue end
     state.ProductGiftReceipts[id]=true;self.Data:MarkDirty(p);fresh=true
    end
    if not self:Save(p,'ProductGiftReceived')then return end
    self.Data:PublishPremium(p)
    if fresh then
     local sender=Players:GetPlayerByUserId(gift.From)
     local name=sender and sender.DisplayName or(type(gift.FromName)=='string'and gift.FromName)or'A player'
     self:Notify(p,name..' gifted you '..Catalog.Name(gift.Key)..'!')
    end
    self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Ready'then box[id].State='Delivered'end end)
   elseif gift.State=='Final'then
    if state.ProductGiftReceipts[id]then state.ProductGiftReceipts[id]=nil;self.Data:MarkDirty(p)end
    if not self:Save(p,'ProductGiftReceiptComplete')then return end
    self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Final'then box[id]=nil end end)
   end
  end
 end)
 self.Working[p]=nil;if not okay then warn('[R121] Product gift recovery deferred: '..tostring(why))end
end
function S:Cleanup(p)self.Busy[p]=nil;self.Intent[p]=nil;self.Warned[p]=nil end
return S
