-- Durable outbox / inbox transfer. A fruit leaves the saved sender profile before
-- delivery. Recipient receipts make retries idempotent; acknowledgements permit cleanup.
-- R122: seed packs and opened seeds use the same flow (hold it, click a nearby player) on their
-- own outbox, receipts and inbox store, so a server still running the fruit-only code never sees them.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService');local DS=game:GetService('DataStoreService')
local S={};S.__index=S
local function count(t)local n=0;for _ in pairs(t or{})do n+=1 end;return n end
local function clone(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=clone(x)end;return out end
-- R130 (owner): the receiver gets a notice naming the giver and the item ("Alice gave you Golden Apple!"). The held
-- Tool's name (the same name the hotbar shows) travels with the gift; older gifts without it use a generic name.
local function itemName(tool)
 local n=tool and tool.Name;if type(n)~='string'then return nil end
 n=n:gsub('%c',''):sub(1,60);return #n>0 and n or nil
end
local function body(p)local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart');return h and h.Health>0 and r end
-- Fruit keeps its original keys. Seeds/packs: separate outbox, receipts and DataStore.
local CHANNELS={
 {Name='Fruit',Out='OutgoingGifts',Receipts='GiftReceipts',Store='Store',Field='Crop'},
 {Name='Seed',Out='OutgoingSeedGifts',Receipts='SeedGiftReceipts',Store='SeedStore',Field='Seed'},
}
function S.new(data,chests,chase,notes)
 local folder=RS:WaitForChild('ChestChaseRemotes');local remote=Instance.new('RemoteEvent');remote.Name='FruitGift';remote.Parent=folder
 local suffix=game:GetService('RunService'):IsStudio()and'_Studio'or''
 local self=setmetatable({Data=data,Chests=chests,Chase=chase,Notes=notes,Remote=remote,Offers={},Busy={},Last={},Working={},Store=DS:GetDataStore('ChestChase_FruitInbox_v1'..suffix),SeedStore=DS:GetDataStore('ChestChase_SeedInbox_v1'..suffix)},S)
 remote.OnServerEvent:Connect(function(p,action,a,b)
  if not require(script.Parent.SecurityGate).Allow(p,'FruitGift',action,a,b)then return end
  if action=='Give'then self:Offer(p,a,b)
  elseif action=='GiveSeed'then self:OfferSeed(p,a,b)end
 end)
 -- R123: offers are swept every 15 s; inboxes (2 DataStore reads per player) only every 60 s. Join and each send still recover at once.
 task.spawn(function()local pass=0;while remote.Parent do task.wait(15);pass+=1;for id,o in pairs(self.Offers)do if os.clock()>o.Expires or not o.From.Parent or not o.To.Parent then self.Offers[id]=nil end end;if pass%4==0 then for _,p in ipairs(Players:GetPlayers())do task.spawn(function()self:Recover(p)end)end end end end)
 return self
end
function S:Available(p)
 return p and p.Parent and self.Data:IsLoaded(p)and self.Data.CanSave[p]and not self.Busy[p]and not self.Working[p]and not self.Chase:IsPlayerBusy(p)and not p:GetAttribute('GuardianRagdollActive')and body(p)
end
-- R131 fix (owner: "gifting doesn't seem to work"). Studio's test players (Player1, Player2…) have negative UserIds;
-- the old check refused every id <= 0, so no gift ever went through in a Studio test. Live ids are always positive.
local studio=game:GetService('RunService'):IsStudio()
function S.ValidUserId(id)
 return type(id)=='number'and id==id and id%1==0 and math.abs(id)<9007199254740991 and(id>0 or(studio and id<0))
end
function S.SetStudio(on)studio=on==true end -- tests
-- Why a gift between these two can't happen right now (nil = it can). Said to the giver instead of doing nothing.
function S:Refusal(from,to)
 local function who(p,me,other)
  if not p.Parent then return other end
  if not self.Data:IsLoaded(p)then return me and'Your data is still loading.'or p.DisplayName..'\'s data is still loading.'end
  if not self.Data.CanSave[p]then
   if studio then return'Gifts need saving: turn on Studio API access (Game Settings > Security) and test again.'end
   return me and'Your save is not ready, so gifts are off. Rejoin to fix it.'or p.DisplayName..'\'s save is not ready, so they can\'t receive gifts.'
  end
  if self.Busy[p]or self.Working[p]then return me and'Still saving your last gift. Try again in a moment.'or p.DisplayName..' is receiving another gift. Try again in a moment.'end
  if self.Chase:IsPlayerBusy(p)then return me and'Finish your run first.'or p.DisplayName..' is in a run right now.'end
  if p:GetAttribute('GuardianRagdollActive')or not body(p)then return'Try again in a moment.'end
  return nil
 end
 return who(from,true,'Try again in a moment.')or who(to,false,'They left the game.')
end
-- A gift save or inbox check takes a few seconds; wait it out instead of refusing the click.
function S:Settle(a,b)
 for _=1,32 do
  if not(self.Busy[a]or self.Working[a]or self.Busy[b]or self.Working[b])then return true end
  task.wait(.25)
 end
 return false
end
function S:CanStart(from,to)
 self:Settle(from,to)
 local why=self:Refusal(from,to)
 if why then self.Remote:FireClient(from,'Status',why);return false end
 return true
end
function S:Near(a,b)local ar,br=body(a),body(b);if not ar or not br or(ar.Position-br.Position).Magnitude>18 then return false end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={a.Character,b.Character};params.RespectCanCollide=true
 return workspace:Raycast(ar.Position,br.Position-ar.Position,params)==nil end
function S:Held(p,id)
 local c=p.Character;for _,t in ipairs(c and c:GetChildren()or{})do if t:IsA('Tool')and t:GetAttribute('HarvestItemTool')and t:GetAttribute('HarvestInventoryId')==id then return t end end;return nil
end
-- R130: a gift to a player who walked out of reach says so instead of doing nothing.
function S:TooFar(from,to)
 if self:Near(from,to)then return false end
 local a,b=body(from),body(to)
 if to and to.Parent and a and b then
  local close=(a.Position-b.Position).Magnitude<=18
  self.Remote:FireClient(from,'Status',close and('Something is between you and '..to.DisplayName..'. Move to where you can see them.')or('Get closer to '..to.DisplayName..' to give.'))
 end
 return true
end
function S:Offer(from,userId,cropId)
 local now=os.clock();if now-(self.Last[from]or -10)<2 then return end;self.Last[from]=now
 if not S.ValidUserId(userId)or type(cropId)~='string'or #cropId>100 then return end
 local to=Players:GetPlayerByUserId(userId)
 if not to or to==from or not require(script.Parent.MovementGuard).Check(from)or not self:CanStart(from,to)or self:TooFar(from,to)then return end
 if not self:Held(from,cropId)then self.Remote:FireClient(from,'Status','Hold the item you want to give.');return end
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
 if offer.Kind=='Seed'then self:AcceptSeed(to,id,offer);return end
 local from=offer.From
 if os.clock()>offer.Expires or not self:Available(from)or not self:Available(to)or not self:Near(from,to)or not self:Held(from,offer.CropId)then self.Remote:FireClient(to,'Status','Gift expired. Ask them to offer again.');return end
 local garden=self.Data.Gardens[from];garden.OutgoingGifts=garden.OutgoingGifts or{}
 if count(garden.OutgoingGifts)>=32 or #self.Data.Gardens[to].Harvests>=self.Data.Config.MaxSavedHarvests then self.Remote:FireClient(from,'Status','Finish pending gifts or clear bag space first.');return end
 local index,crop;for i,c in ipairs(garden.Harvests)do if c.Id==offer.CropId then index=i;crop=c;break end end;if not crop then return end
 if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then return end
 -- No yield between inventory removal and persistent outbox staging.
 self.Busy[from]=true;self.Busy[to]=true
 local gift={RecipientId=to.UserId,Crop=clone(crop),State='Pending',Name=itemName(self:Held(from,offer.CropId))}
 table.remove(garden.Harvests,index);garden.OutgoingGifts[id]=gift
 self.Data:MarkDirty(from);self.Data:_gardenChanged(from);self.Chests:SyncTools(from)
 self.Remote:FireClient(from,'Status','Saving your gift…')
 self:_deliver(from,to,id,gift,CHANNELS[1])
end
-- Shared tail of a debit: save the sender's outbox, then publish to the recipient's inbox.
function S:_deliver(from,to,id,gift,channel)
 self.Data:WaitForSave(from,8)
 local saved=self.Data:Save(from,'GiftDebit',true)
 -- The saved outbox is authoritative even if the sender leaves during that save.
 -- Publish directly before releasing the lock; Recover intentionally skips departed players.
 local queued=false
 if saved then
  for attempt=1,3 do
   local inbox=self:QueueInbox(from.UserId,id,gift,channel);if inbox and inbox[id]then queued=true;break end
   if attempt<3 then task.wait(attempt)end
  end
 end
 self.Busy[from]=nil;self.Busy[to]=nil
 if queued then
  self.Remote:FireClient(from,'Status','Gift sent to '..to.DisplayName..'!'..(gift.Name and(' ('..gift.Name..')')or''))
  self:Recover(from);self:Recover(to)
 else
  self.Remote:FireClient(from,'Status','Gift is pending a safe save. It will retry automatically.')
 end
 return queued
end

-- R122 seed packs / seeds -------------------------------------------------------------------------
-- Only inventory items (a Tool the giver is holding). Carried, stolen packs are a CarriedSeed model,
-- never a Tool, and every chase/carry/queue state blocks the giver outright.
function S:HeldSeed(p,id,kind)
 local c=p.Character
 for _,t in ipairs(c and c:GetChildren()or{})do
  if t:IsA('Tool')and t:GetAttribute('SeedInventoryId')==id
   and((kind=='Pack'and t:GetAttribute('SeedPackTool'))or(kind=='Seed'and t:GetAttribute('GardenSeed')))then return t end
 end
 return nil
end
function S:FindSeed(p,id)
 for i,r in ipairs(self.Data:GetChestRecords(p))do if r.Id==id then return r,i end end
 return nil
end
-- Why this giver cannot hand out a seed or pack right now (nil = allowed).
function S:SeedBlocked(p,id)
 if p:GetAttribute('ChestChaseSeedCarrying')or p:GetAttribute('ChestChaseRunActive')or p:GetAttribute('ChestChaseQueued')or p:GetAttribute('GuardianFlingActive')then
  return 'Bank your pack and finish the run first.'
 end
 local step=tonumber(p:GetAttribute('TutorialStep'))or 0
 if p:GetAttribute('TutorialDone')~=true and step>=1 and step<=4 then return 'Finish the tutorial first.'end
 local opening=self.Chests.Openings and self.Chests.Openings[p]
 if opening and(opening.Committed or(opening.Tool and opening.Tool:GetAttribute('SeedInventoryId')~=id))then return 'Wait for your pack to finish opening.'end
 return nil
end
function S:SeedPaidBlocked(record,from,to)
 if not record.PaidRandom then return false end
 if from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true then return true end
 -- An unopened purchased pack is useless (and unopenable) where paid random items are restricted.
 return record.Kind=='Pack'and to:GetAttribute('PaidRandomAllowed')~=true
end
function S:OfferSeed(from,userId,itemId)
 local now=os.clock();if now-(self.Last[from]or -10)<2 then return end;self.Last[from]=now
 if not S.ValidUserId(userId)or type(itemId)~='string'or #itemId<1 or #itemId>100 then return end
 local to=Players:GetPlayerByUserId(userId)
 if not to or to==from or not require(script.Parent.MovementGuard).Check(from)or not self:CanStart(from,to)or self:TooFar(from,to)then return end
 local record=self:FindSeed(from,itemId)
 if not record or(record.Kind~='Pack'and record.Kind~='Seed')or not self:HeldSeed(from,itemId,record.Kind)then return end
 local blocked=self:SeedBlocked(from,itemId);if blocked then self.Remote:FireClient(from,'Status',blocked);return end
 local noun=record.Kind=='Pack'and'pack'or'seed'
 if self:SeedPaidBlocked(record,from,to)then self.Remote:FireClient(from,'Status','This purchased '..noun..' cannot be gifted between these accounts.');return end
 if #self.Data:GetChestRecords(to)>=self.Data.Config.MaxSavedChests then self.Remote:FireClient(from,'Status','Their seed inventory is full.');return end
 for id,o in pairs(self.Offers)do if o.From==from or o.To==to then self.Offers[id]=nil end end
 local id=Http:GenerateGUID(false);self.Offers[id]={From=from,To=to,ItemId=itemId,Kind='Seed',Expires=now+25}
 self:Accept(to,id) -- same as fruit: the sender's click is the complete gift action
end
function S:AcceptSeed(to,id,offer)
 local from=offer.From
 local record=self:FindSeed(from,offer.ItemId)
 if os.clock()>offer.Expires or not record or not self:Available(from)or not self:Available(to)or not self:Near(from,to)or not self:HeldSeed(from,offer.ItemId,record.Kind)or self:SeedBlocked(from,offer.ItemId)then
  self.Remote:FireClient(to,'Status','Gift expired. Ask them to offer again.');return
 end
 local garden=self.Data.Gardens[from];garden.OutgoingSeedGifts=garden.OutgoingSeedGifts or{}
 if count(garden.OutgoingSeedGifts)>=32 or #self.Data:GetChestRecords(to)>=self.Data.Config.MaxSavedChests then self.Remote:FireClient(from,'Status','Finish pending gifts or make inventory room first.');return end
 if self:SeedPaidBlocked(record,from,to)then return end
 local row=self.Data:SerializeSeedRecord(record)
 row.RateBoost=nil -- R139 (owner: the free pack is "a 1 time thing"): its luck stays with the player who earned it
 if not self.Data:DecodeGiftedSeed(to,row)then self.Remote:FireClient(from,'Status','This item cannot be gifted.');return end
 local tool=self:HeldSeed(from,offer.ItemId,record.Kind)
 -- No yield between inventory removal and persistent outbox staging.
 self.Busy[from]=true;self.Busy[to]=true
 local _,index=self:FindSeed(from,offer.ItemId)
 local gift={RecipientId=to.UserId,Seed=row,State='Pending',Name=itemName(tool)}
 table.remove(self.Data:GetChestRecords(from),index);garden.OutgoingSeedGifts[id]=gift
 self.Data:_notifySeedInventory(from);self.Data:MarkDirty(from);self.Data:_gardenChanged(from)
 -- Unequip first so a held pack ends its (uncommitted) opening normally; SyncTools then removes the Tool.
 local humanoid=from.Character and from.Character:FindFirstChildOfClass('Humanoid')
 if humanoid and tool and tool.Parent==from.Character then humanoid:UnequipTools()end
 self.Chests:SyncTools(from)
 self.Remote:FireClient(from,'Status','Saving your gift…')
 return self:_deliver(from,to,id,gift,CHANNELS[2])
end
-- Recipient side of a seed/pack gift. Returns false to leave the inbox entry for a later retry.
function S:_receiveSeed(p,garden,receipts,id,gift)
 local row=gift.Seed
 if type(row)~='table'then warn('[R122] Invalid seed gift retained for review: '..id);return false end
 if row.PaidRandom==true and(p:GetAttribute('PaidTradingAllowed')~=true or(row.Kind=='Pack'and p:GetAttribute('PaidRandomAllowed')~=true))then return false end
 if receipts[id]then return true end
 local records=self.Data:GetChestRecords(p)
 if #records>=self.Data.Config.MaxSavedChests then return false end
 local record=self.Data:DecodeGiftedSeed(p,row)
 if not record then warn('[R122] Invalid seed gift retained for review: '..id);return false end
 local already=false;for _,r in ipairs(records)do if r.Id==record.Id then already=true end end
 if not already then
  local serial=(p:GetAttribute('ChestInventorySerial')or 0)+1;p:SetAttribute('ChestInventorySerial',serial)
  record.ChestNumber=serial;table.insert(records,record)
 end
 if record.Kind=='Seed'then self.Data:MarkSeedDiscovered(p,record.SeedId,true)end
 receipts[id]=true;self.Data:_notifySeedInventory(p);self.Data:MarkDirty(p);self.Data:_gardenChanged(p);self.Chests:SyncTools(p)
 return true
end
-- -------------------------------------------------------------------------------------------------
function S:ChangeInbox(userId,change,store)
 store=store or self.Store
 local ok,value=pcall(store.UpdateAsync,store,tostring(userId),function(old)
  local inbox=type(old)=='table'and clone(old)or{};local changed=change(inbox)
  if changed==false then return nil end;return inbox
 end)
 return ok and type(value)=='table'and value or nil
end
function S:Save(p,reason)
 self.Data:WaitForSave(p,5);return self.Data:IsLoaded(p)and self.Data:Save(p,reason,true)
end
function S:QueueInbox(fromId,id,gift,channel)
 channel=channel or CHANNELS[1]
 return self:ChangeInbox(gift.RecipientId,function(box)
  if not box[id]then if count(box)>=128 then return false end;box[id]={State='Ready',From=fromId,Name=gift.Name,[channel.Field]=clone(gift[channel.Field])}end
 end,self[channel.Store])
end
function S:Recover(p)
 if not p.Parent or not self.Data:IsLoaded(p)or not self.Data.CanSave[p]then return end
 -- R131: a gift that lands while this player's inbox check is running is picked up right after it, not 60 s later.
 if self.Working[p]or self.Busy[p]then self.Again=self.Again or{};self.Again[p]=true;return end
 self.Working[p]=true
 local ok,err=pcall(function()
  for _,channel in ipairs(CHANNELS)do
   if not self:_recoverChannel(p,channel)then return end
  end
 end)
 self.Working[p]=nil;if not ok then warn('[R52] Gift recovery deferred: '..tostring(err))end
 if self.Again and self.Again[p]then self.Again[p]=nil;task.defer(function()self:Recover(p)end)end
end
-- R131: inbox reads skip the 4 s DataStore read cache, so a gift queued a moment ago is seen.
local fresh
local function readInbox(store,key)
 if fresh==nil then fresh=false;pcall(function()local o=Instance.new('DataStoreGetOptions');o.UseCache=false;fresh=o end)end
 if fresh then return pcall(store.GetAsync,store,key,fresh)end
 return pcall(store.GetAsync,store,key)
end
-- Returns false when recovery must stop for this pass (a save failed or the player left).
function S:_recoverChannel(p,channel)
 local store=self[channel.Store]
 local garden=self.Data.Gardens[p];garden[channel.Out]=garden[channel.Out]or{};garden[channel.Receipts]=garden[channel.Receipts]or{}
 local outbox,receipts=garden[channel.Out],garden[channel.Receipts]
 -- Always persist the debit/ack state before it can change the recipient inbox.
 if next(outbox)and not self:Save(p,'GiftOutbox')then return false end
 for id,gift in pairs(outbox)do
  if not p.Parent or self.Data.Gardens[p]~=garden then return false end
  if gift.State=='Pending'then
   local inbox=self:QueueInbox(p.UserId,id,gift,channel)
   if inbox and inbox[id]and(inbox[id].State=='Delivered'or inbox[id].State=='Final')then
    gift.State='Acked';self.Data:MarkDirty(p)
    if not self:Save(p,'GiftAcknowledged')then return false end
   end
  end
  if gift.State=='Acked'then
   local inbox=self:ChangeInbox(gift.RecipientId,function(box)if box[id]then box[id].State='Final'end end,store)
   if inbox then outbox[id]=nil;self.Data:MarkDirty(p);if not self:Save(p,'GiftOutboxComplete')then return false end end
  end
 end
 local read,inbox=readInbox(store,tostring(p.UserId));if not read or type(inbox)~='table'then return true end
 for id,gift in pairs(inbox)do
  if not p.Parent or self.Data.Gardens[p]~=garden or not self.Data:IsLoaded(p)then return false end
  if gift.State=='Ready'then
   if channel.Name=='Seed'then
    if not self:_receiveSeed(p,garden,receipts,id,gift)then continue end
   else
    if gift.Crop and gift.Crop.PaidRandom and p:GetAttribute('PaidTradingAllowed')~=true then continue end
    if not receipts[id]then
     if #garden.Harvests>=self.Data.Config.MaxSavedHarvests then continue end
     -- Verify the donated record with the same decoder used for a saved crop bag.
     local valid=self.Data:DecodeGarden({Version=self.Data.Config.GardenSchemaVersion,Plots={},Harvests={gift.Crop}})
     if not valid then warn('[R52] Invalid gift retained for review: '..id);continue end
     local already=false;for _,crop in ipairs(garden.Harvests)do if crop.Id==gift.Crop.Id then already=true end end
     if not already then table.insert(garden.Harvests,clone(gift.Crop))end
     self.Data:MarkAdultDiscovered(p,gift.Crop.SeedId)
     receipts[id]=true;self.Data:MarkDirty(p);self.Data:_gardenChanged(p);self.Chests:SyncTools(p)
    end
   end
   if not self:Save(p,'GiftReceived')then return false end
   local saved=self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Ready'then box[id].State='Delivered'end end,store)
   if saved then
    -- R131: the receiver's client shows a gold notice with a reward sound (FruitGiftClient).
    local what,giver,item=self:ReceivedText(gift,channel)
    self.Remote:FireClient(p,'Received',what,{From=giver,Item=item})
   end
  elseif gift.State=='Final'then
   if receipts[id]then receipts[id]=nil;self.Data:MarkDirty(p)end
   -- A previous attempt may have cleared memory but failed to save it.
   if not self:Save(p,'GiftReceiptComplete')then return false end
   self:ChangeInbox(p.UserId,function(box)if box[id]and box[id].State=='Final'then box[id]=nil end end,store)
  end
 end
 return true
end
function S:ReceivedText(gift,channel)
 local giver=type(gift.From)=='number'and Players:GetPlayerByUserId(gift.From)
 local who=giver and giver.DisplayName
 if not who and type(gift.From)=='number'then local ok,n=pcall(Players.GetNameFromUserIdAsync,Players,gift.From);who=ok and type(n)=='string'and n or nil end
 local item=type(gift.Name)=='string'and itemName({Name=gift.Name})
 if not item then
  if channel.Name=='Seed'then item=(type(gift.Seed)=='table'and gift.Seed.Kind=='Pack')and'a seed pack'or'a seed'else item='a crop'end
 end
 who=who or'Someone'
 return '🎁 '..who..' gave you '..item..'!',who,item
end
function S:Cleanup(p)
 self.Last[p]=nil;if self.Again then self.Again[p]=nil end
 for id,o in pairs(self.Offers)do if o.From==p or o.To==p then self.Offers[id]=nil end end
end
return S
