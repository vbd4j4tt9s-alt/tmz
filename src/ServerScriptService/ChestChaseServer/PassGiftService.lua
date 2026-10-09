-- R79: saved debit/outbox -> durable inbox -> saved entitlement -> acknowledgement.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local DS=game:GetService('DataStoreService');local Http=game:GetService('HttpService')
local Market=game:GetService('MarketplaceService');local Catalog=require(RS.PassGiftCatalog);local Passes=require(RS.GamePassCatalog);local Mech=require(RS.MechCatalog)
local S={};S.__index=S
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
local function clone(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=clone(x)end;return t end
function S.new(data,passes)
 local self=setmetatable({Data=data,Passes=passes,Busy={},Working={},Store=DS:GetDataStore('ChestChase_PassInbox_v1'..(game:GetService('RunService'):IsStudio()and'_Studio'or''))},S)
 task.spawn(function()while task.wait(60)do for _,p in ipairs(Players:GetPlayers())do task.spawn(function()self:Recover(p)end)end end end)
 return self
end
function S:Owns(p,key)
 local pass=Catalog.Pass(key);if not pass then return nil end
 local state=self.Data:GetPremium(p)
 if state.Entitlements[key]or p:GetAttribute(pass.Attribute)==true then return true end
 local id=Passes.Id(pass);if id==0 then return false end
 local ok,result=pcall(Market.UserOwnsGamePassAsync,Market,p.UserId,id)
 if not self:Ready(p)or self.Data:GetPremium(p)~=state then return nil end
 if state.Entitlements[key]or p:GetAttribute(pass.Attribute)==true then return true end
 if ok and type(result)=='boolean'then return result end;return nil
end
function S:Ready(p)return p and p.Parent and self.Data:IsLoaded(p)and self.Data.CanSave[p]end
function S:Save(p,reason)
 self.Data:WaitForSave(p,5);return self:Ready(p)and self.Data:Save(p,reason,true)
end
function S:PriceLevelAllowed(from,to)
 local okay,rows=pcall(Market.GetUsersPriceLevelsAsync,Market,{from.UserId,to.UserId})
 if not okay or type(rows)~='table'then return false,'Can\'t get the gift price right now. Try again soon!'end
 local levels={};local n=0
 for _,row in pairs(rows)do
  n+=1
  if n>2 or type(row)~='table'or(row.UserId~=from.UserId and row.UserId~=to.UserId)
   or levels[row.UserId]~=nil or type(row.PriceLevel)~='number'or row.PriceLevel~=row.PriceLevel or row.PriceLevel<1 or row.PriceLevel>1000 then
   return false,'Can\'t get the gift price right now. Try again soon!'
  end
  levels[row.UserId]=row.PriceLevel
 end
 if levels[from.UserId]==nil or levels[to.UserId]==nil then return false,'Can\'t get the gift price right now. Try again soon!'end
 if levels[from.UserId]<levels[to.UserId]then return false,'This gift isn\'t allowed in their country.'end
 return true
end
function S:Send(from,key,userId,payment)
 if not Catalog.Pass(key)or type(userId)~='number'or userId~=userId or userId%1~=0 or userId<=0 or userId>=9007199254740991 then return false,'Pick a player first!'end
 local to=Players:GetPlayerByUserId(userId)
 if to==from or not self:Ready(from)or not self:Ready(to)or self.Busy[from]or self.Working[from]then return false,'That player isn\'t here.'end
 if payment~='Gems'and payment~='Credit'then return false,'Pick Gems or Robux!'end
 self.Busy[from]=true
 local okay,success,message=pcall(function()
  local allowed,reason=self:PriceLevelAllowed(from,to)
  if not allowed then return false,reason end
  if not self:Ready(from)or not self:Ready(to)then return false,'That player isn\'t here.'end
  local owned=self:Owns(to,key)
  if owned==nil then return false,'Try again soon!'end
  if owned then return false,'They already have this pass!'end
  if not self:Ready(from)or not self:Ready(to)then return false,'That player isn\'t here.'end
  local state=self.Data:GetPremium(from)
  if count(state.PassOutbox)>=Catalog.MaxOutbox then return false,'Your other gifts are still saving.'end
  for _,v in pairs(state.PassOutbox)do if v.RecipientId==userId and v.PassKey==key then return false,'This gift is already on its way!'end end
  local price=Mech.PassGemPrices[key]
  if payment=='Gems'and state.Gems<price then return false,'Not enough Gems!'end
  if payment=='Credit'and(state.GiftCredits[key]or 0)<1 then return false,'No gift is ready to send.'end
  local id=Http:GenerateGUID(false)
  -- This debit and outbox insertion cannot yield or be separated by another request.
  if payment=='Gems'then state.Gems-=price else state.GiftCredits[key]-=1 end
  state.PassOutbox[id]={RecipientId=userId,PassKey=key,State='Pending'};self.Data:MarkDirty(from);self.Data:PublishPremium(from)
  if not self:Save(from,'PassGiftDebit')then return true,'Gift on its way! It retries by itself.'end
  -- The saved debit authorizes this inbox write even if either player disconnects.
  -- Keep Busy set through bounded retries so acknowledgement cannot race a retry.
  for attempt=1,3 do
   local box=self:QueueInbox(from.UserId,userId,key,id)
   if box and box[id]then return true,'Gift sent to '..to.DisplayName..'.'end
   if attempt<3 then task.wait(attempt)end
  end
  return true,'Gift on its way! It retries by itself.'
 end)
 self.Busy[from]=nil
 if okay and success then task.spawn(function()self:Recover(from);self:Recover(to)end)end
 return okay and success==true,okay and message or'Gift on its way! Try again soon.'
end
function S:ChangeInbox(userId,change)
 local okay,result=pcall(self.Store.UpdateAsync,self.Store,tostring(userId),function(old)
  if old~=nil and type(old)~='table'then return nil end
  local box=clone(old or{});if change(box)==false then return nil end;return box
 end)
 return okay and type(result)=='table'and result or nil
end
function S:QueueInbox(fromId,userId,key,id)
 return self:ChangeInbox(userId,function(inbox)
  if not inbox[id]then if count(inbox)>=Catalog.MaxInbox then return false end;inbox[id]={State='Ready',From=fromId,PassKey=key}end
 end)
end
function S:Recover(p)
 if not self:Ready(p)or self.Busy[p]or self.Working[p]then return end;self.Working[p]=true
 local okay,why=pcall(function()
  local state=self.Data:GetPremium(p)
  if next(state.PassOutbox)and not self:Save(p,'PassGiftOutbox')then return end
  for id,gift in pairs(state.PassOutbox)do
   if not self:Ready(p)or self.Data:GetPremium(p)~=state then return end
   if gift.State=='Pending'then
    local box=self:QueueInbox(p.UserId,gift.RecipientId,gift.PassKey,id)
    if box and box[id]and(box[id].State=='Delivered'or box[id].State=='Final')then
     gift.State='Acked';self.Data:MarkDirty(p);if not self:Save(p,'PassGiftAcknowledge')then return end
    end
   end
   if gift.State=='Acked'then
    local box=self:ChangeInbox(gift.RecipientId,function(inbox)if inbox[id]then inbox[id].State='Final'end end)
    if box then state.PassOutbox[id]=nil;self.Data:MarkDirty(p);if not self:Save(p,'PassGiftComplete')then return end end
   end
  end
  local read,inbox=pcall(self.Store.GetAsync,self.Store,tostring(p.UserId));if not read or type(inbox)~='table'then return end
  for id,gift in pairs(inbox)do
   if not self:Ready(p)or self.Data:GetPremium(p)~=state then return end
   if type(gift)~='table'or not Catalog.Pass(gift.PassKey)or type(id)~='string'or #id>100 then continue end
   if gift.State=='Ready'then
    if not state.PassGiftReceipts[id]then
     if count(state.PassGiftReceipts)>=Catalog.MaxInbox then continue end
     local owned=self:Owns(p,gift.PassKey)
     if owned==nil or not self:Ready(p)or self.Data:GetPremium(p)~=state then return end
     -- A concurrent purchase cannot waste a gift: preserve it as a transferable credit.
     if owned then
      if(state.GiftCredits[gift.PassKey]or 0)>=Catalog.MaxCredits then continue end
      state.GiftCredits[gift.PassKey]=(state.GiftCredits[gift.PassKey]or 0)+1
     else state.Entitlements[gift.PassKey]=true end
     state.PassGiftReceipts[id]=true;self.Data:MarkDirty(p)
    end
    if not self:Save(p,'PassGiftReceived')then return end
    self.Data:PublishPremium(p);self.Passes:Refresh(p)
    self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Ready'then box[id].State='Delivered'end end)
   elseif gift.State=='Final'then
    if state.PassGiftReceipts[id]then state.PassGiftReceipts[id]=nil;self.Data:MarkDirty(p)end
    -- A previous save may have failed after clearing the in-memory receipt.
    if not self:Save(p,'PassGiftReceiptComplete')then return end
    self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Final'then box[id]=nil end end)
   end
  end
 end)
 self.Working[p]=nil;if not okay then warn('[R79] Pass gift recovery deferred: '..tostring(why))end
end
function S:Cleanup(p)self.Busy[p]=nil end
return S
