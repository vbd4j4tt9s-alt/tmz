-- Durable outbox / inbox transfer. A fruit leaves the saved sender profile before
-- delivery. Recipient receipts make retries idempotent; acknowledgements permit cleanup.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService');local DS=game:GetService('DataStoreService')
local S={};S.__index=S
local function count(t)local n=0;for _ in pairs(t or{})do n+=1 end;return n end
local function clone(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
local function body(p)local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart');return h and h.Health>0 and r end
function S.new(data,chests,chase,notes)
 local folder=RS:WaitForChild('ChestChaseRemotes');local remote=Instance.new('RemoteEvent');remote.Name='FruitGift';remote.Parent=folder
 local self=setmetatable({Data=data,Chests=chests,Chase=chase,Notes=notes,Remote=remote,Offers={},Busy={},Last={},Working={},Store=DS:GetDataStore('ChestChase_FruitInbox_v1'..(game:GetService('RunService'):IsStudio()and'_Studio'or''))},S)
 remote.OnServerEvent:Connect(function(p,action,a,b)
  if not require(script.Parent.SecurityGate).Allow(p,'FruitGift',action,a,b)then return end
  if action=='Give'then self:Offer(p,a,b)end
 end)
 task.spawn(function()while remote.Parent do task.wait(15);for id,o in pairs(self.Offers)do if os.clock()>o.Expires or not o.From.Parent or not o.To.Parent then self.Offers[id]=nil end end;for _,p in ipairs(Players:GetPlayers())do task.spawn(function()self:Recover(p)end)end end end)
 return self
end
function S:Available(p)
 return p and p.Parent and self.Data:IsLoaded(p)and self.Data.CanSave[p]and not self.Busy[p]and not self.Working[p]and not self.Chase:IsPlayerBusy(p)and not p:GetAttribute('GuardianRagdollActive')and body(p)
end
function S:Near(a,b)local ar,br=body(a),body(b);if not ar or not br or(ar.Position-br.Position).Magnitude>18 then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={a.Character,b.Character};params.RespectCanCollide=true
 return workspace:Raycast(ar.Position,br.Position-ar.Position,params)==nil end
function S:Held(p,id)
 local c=p.Character;for _,t in ipairs(c and c:GetChildren()or{})do if t:IsA('Tool')and t:GetAttribute('HarvestItemTool')and t:GetAttribute('HarvestInventoryId')==id then return true end end;return false
end
function S:Offer(from,userId,cropId)
 local now=os.clock();if now-(self.Last[from]or -10)<2 then return end;self.Last[from]=now
 if type(userId)~='number'or userId~=userId or userId<=0 or userId>=9007199254740991 or userId%1~=0 or type(cropId)~='string'or #cropId>100 then return end
 local to=Players:GetPlayerByUserId(userId)
 if to==from or not require(script.Parent.MovementGuard).Check(from)or not self:Available(from)or not self:Available(to)or not self:Near(from,to)or not self:Held(from,cropId)then return end
 local crop;for _,c in ipairs(self.Data.Gardens[from].Harvests)do if c.Id==cropId then crop=c;break end end
 if not crop then return end
 if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then self.Remote:FireClient(from,'Status','This purchased crop cannot be gifted between these accounts.');return end
 if #self.Data.Gardens[to].Harvests>=self.Data.Config.MaxSavedHarvests then self.Remote:FireClient(from,'Status','Their crop bag is full.');return end
 for id,o in pairs(self.Offers)do if o.From==from or o.To==to then self.Offers[id]=nil end end
 local id=Http:GenerateGUID(false);self.Offers[id]={From=from,To=to,CropId=cropId,Expires=now+25}
 self:Accept(to,id) -- sender's direct click is the complete gift action

end
function S:Accept(to,id)
 if type(id)~='string'then return end;local offer=self.Offers[id]
 if not offer or offer.To~=to then return end;self.Offers[id]=nil
 local from=offer.From
 if os.clock()>offer.Expires or not self:Available(from)or not self:Available(to)or not self:Near(from,to)or not self:Held(from,offer.CropId)then self.Remote:FireClient(to,'Status','Gift expired. Ask them to offer again.');return end
 local garden=self.Data.Gardens[from];garden.OutgoingGifts=garden.OutgoingGifts or{}
 if count(garden.OutgoingGifts)>=32 or #self.Data.Gardens[to].Harvests>=self.Data.Config.MaxSavedHarvests then self.Remote:FireClient(from,'Status','Finish pending gifts or clear bag space first.');return end
 local index,crop;for i,c in ipairs(garden.Harvests)do if c.Id==offer.CropId then index=i;crop=c;break end end;if not crop then return end
 if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then return end
 -- No yield between inventory removal and persistent outbox staging.
 self.Busy[from]=true;self.Busy[to]=true
 local gift={RecipientId=to.UserId,Crop=clone(crop),State='Pending'}
 table.remove(garden.Harvests,index);garden.OutgoingGifts[id]=gift
 self.Data:MarkDirty(from);self.Data:_gardenChanged(from);self.Chests:SyncTools(from)
 self.Remote:FireClient(from,'Status','Saving your gift…')
 self.Data:WaitForSave(from,8)
 local saved=self.Data:Save(from,'GiftDebit',true)
 -- The saved outbox is authoritative even if the sender leaves during that save.
 -- Publish directly before releasing the lock; Recover intentionally skips departed players.
 local queued=false
 if saved then
  for attempt=1,3 do
   local inbox=self:QueueInbox(from.UserId,id,gift);if inbox and inbox[id]then queued=true;break end
   if attempt<3 then task.wait(attempt)end
  end
 end
 self.Busy[from]=nil;self.Busy[to]=nil
 if queued then self:Recover(from);self:Recover(to)else
  self.Remote:FireClient(from,'Status','Gift is pending a safe save. It will retry automatically.')
 end
end
function S:ChangeInbox(userId,change)
 local ok,value=pcall(self.Store.UpdateAsync,self.Store,tostring(userId),function(old)
  local inbox=type(old)=='table'and clone(old)or{};local changed=change(inbox)
  if changed==false then return nil end;return inbox
 end)
 return ok and type(value)=='table'and value or nil
end
function S:Save(p,reason)
 self.Data:WaitForSave(p,5);return self.Data:IsLoaded(p)and self.Data:Save(p,reason,true)
end
function S:QueueInbox(fromId,id,gift)
 return self:ChangeInbox(gift.RecipientId,function(box)
  if not box[id]then if count(box)>=128 then return false end;box[id]={State='Ready',From=fromId,Crop=clone(gift.Crop)}end
 end)
end
function S:Recover(p)
 if self.Working[p]or self.Busy[p]or not p.Parent or not self.Data:IsLoaded(p)or not self.Data.CanSave[p]then return end
 self.Working[p]=true
 local ok,err=pcall(function()
  local garden=self.Data.Gardens[p];garden.OutgoingGifts=garden.OutgoingGifts or{};garden.GiftReceipts=garden.GiftReceipts or{}
  -- Always persist the debit/ack state before it can change the recipient inbox.
  if next(garden.OutgoingGifts)and not self:Save(p,'GiftOutbox')then return end
  for id,gift in pairs(garden.OutgoingGifts)do
   if not p.Parent or self.Data.Gardens[p]~=garden then return end
   if gift.State=='Pending'then
    local inbox=self:QueueInbox(p.UserId,id,gift)
    if inbox and inbox[id]and(inbox[id].State=='Delivered'or inbox[id].State=='Final')then
     gift.State='Acked';self.Data:MarkDirty(p)
     if not self:Save(p,'GiftAcknowledged')then return end
    end
   end
   if gift.State=='Acked'then
    local inbox=self:ChangeInbox(gift.RecipientId,function(box)if box[id]then box[id].State='Final'end end)
    if inbox then garden.OutgoingGifts[id]=nil;self.Data:MarkDirty(p);if not self:Save(p,'GiftOutboxComplete')then return end end
   end
  end
  local read,inbox=pcall(self.Store.GetAsync,self.Store,tostring(p.UserId));if not read or type(inbox)~='table'then return end
  for id,gift in pairs(inbox)do
   if not p.Parent or self.Data.Gardens[p]~=garden or not self.Data:IsLoaded(p)then return end
   if gift.State=='Ready'then
    if gift.Crop and gift.Crop.PaidRandom and p:GetAttribute('PaidTradingAllowed')~=true then continue end
    if not garden.GiftReceipts[id]then
     if #garden.Harvests>=self.Data.Config.MaxSavedHarvests then continue end
     -- Verify the donated record with the same decoder used for a saved crop bag.
     local valid=self.Data:DecodeGarden({Version=self.Data.Config.GardenSchemaVersion,Plots={},Harvests={gift.Crop}})
     if not valid then warn('[R52] Invalid gift retained for review: '..id);continue end
     local already=false;for _,crop in ipairs(garden.Harvests)do if crop.Id==gift.Crop.Id then already=true end end
     if not already then table.insert(garden.Harvests,clone(gift.Crop))end
     self.Data:MarkAdultDiscovered(p,gift.Crop.SeedId)
     garden.GiftReceipts[id]=true;self.Data:MarkDirty(p);self.Data:_gardenChanged(p);self.Chests:SyncTools(p)
    end
    if not self:Save(p,'GiftReceived')then return end
    local saved=self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Ready'then box[id].State='Delivered'end end)
    if saved then self.Remote:FireClient(p,'Received','A gifted crop was added to your bag.')end
   elseif gift.State=='Final'then
    if garden.GiftReceipts[id]then garden.GiftReceipts[id]=nil;self.Data:MarkDirty(p)end
    -- A previous attempt may have cleared memory but failed to save it.
    if not self:Save(p,'GiftReceiptComplete')then return end
    self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Final'then box[id]=nil end end)
   end
  end
 end)
 self.Working[p]=nil;if not ok then warn('[R52] Gift recovery deferred: '..tostring(err))end
end
function S:Cleanup(p)
 self.Last[p]=nil
 for id,o in pairs(self.Offers)do if o.From==p or o.To==p then self.Offers[id]=nil end end
end
return S
