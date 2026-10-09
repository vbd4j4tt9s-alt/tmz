-- R155 (owner: "allow people to discard items"; "i have a lot of options to manage my inventory"): the server half of the Bag.
--  * Remote ChestChaseRemotes.DiscardItems (RemoteFunction). The client asks {Kind=<Pack | Seed | Fruit | Loot>, Id=<the inventory id of any item of the
--    stack>, Count=n}; the SERVER finds that item among the player's own Tools, its stack (InventoryStacks155.Key, the stack the client drew), checks
--    everything and deletes exactly n records of it from the saved data (PlayerDataService:DiscardRecords). Nothing comes back: no money, no item.
--    Refused (nothing changes, the reason in the owner's voice): data not loaded / not saving; the shovel, the bat or any non-item tool; an item that is
--    gone; more than the stack holds; carrying a stolen pack or in a chase; a gift being saved; the pack being opened (or any committed reveal's pack);
--    a reward seed still flying in on the opener's screen (SeedCollect154, ChestService.RecentRewards, RewardSeconds).
--    Each discard is written to the Output ("[R155 Discard] name (id): threw away 3x Apple Seed ...") and kept for /test hotbar (PlayerDataService:NoteDiscard),
--    so a "my seed vanished" report can be checked.
--  * Remote ChestChaseRemotes.HotbarLayout155 (RemoteEvent): the client's hotbar layout string (GardenInventoryState.Serialize), saved as the optional
--    Premium.Hotbar155 with the profile's next save (PlayerDataService:SetHotbarLayout).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Stacks=require(RS:WaitForChild('InventoryStacks155'))
local S={};S.__index=S
S.RewardSeconds=10 -- a reward seed handed over this recently may still be flying in on the opener's screen
S.LogIds=6 -- the discard log names up to this many record ids
S.Kinds={Pack=true,Seed=true,Fruit=true,Loot=true}
S.Text={Loading='HOLD ON, UR DATA IS LOADING!',Saving='UR DATA CAN\'T SAVE RIGHT NOW, TRY AGAIN LATER',NotItem='U CAN\'T THROW THAT AWAY',Gone='THAT ITEM IS ALREADY GONE!',
 Busy='FINISH UR STEAL FIRST!',Gift='WAIT FOR UR GIFT TO SEND FIRST!',Opening='WAIT FOR UR PACK TO FINISH OPENING!',Landing='WAIT FOR UR SEED TO LAND FIRST!',
 Amount='U DON\'T HAVE THAT MANY!',Invalid='TRY AGAIN!'}
function S.new(config,data,chests,gifts,notes)
 return setmetatable({Config=config,Data=data,Chests=chests,Gifts=gifts,Notes=notes},S)
end
local function containers(player)
 local out={};local b=player:FindFirstChildOfClass('Backpack');if b then out[#out+1]=b end
 if player.Character then out[#out+1]=player.Character end;return out
end
local function refuse(why)return {Ok=false,Message=why}end
-- the record ids that must not go right now: the pack being opened, a committed reveal's pack, a reward seed still landing
function S:_locked(player)
 local locked={}
 local opening=self.Chests and self.Chests.Openings and self.Chests.Openings[player]
 if type(opening)=='table'then
  local tool=opening.Tool;local id=tool and tool:GetAttribute('SeedInventoryId')
  if id and(opening.Committed or(tonumber(opening.Clicks)or 0)>0)then locked[id]='Opening'end
  if opening.RewardId then locked[opening.RewardId]='Opening'end
 end
 local recent=self.Chests and self.Chests.RecentRewards and self.Chests.RecentRewards[player]
 if recent then for id,at in pairs(recent)do if os.clock()-at<S.RewardSeconds then locked[id]=locked[id]or'Landing'else recent[id]=nil end end end
 return locked
end
function S:Discard(player,request)
 local data=self.Data
 if type(request)~='table'then return refuse(S.Text.Invalid)end
 local kind,id,count=request.Kind,request.Id,request.Count
 if type(id)~='string'or #id<1 or #id>100 or type(count)~='number'or count~=count or count%1~=0 or count<1 or count>1000 then return refuse(S.Text.Invalid)end
 if not S.Kinds[kind]then return refuse(S.Text.NotItem)end
 if not data:IsLoaded(player)then return refuse(S.Text.Loading)end
 if not data.CanSave[player]then return refuse(S.Text.Saving)end
 if player:GetAttribute('ChestChaseSeedCarrying')or player:GetAttribute('ChestChaseRunActive')or player:GetAttribute('ChestChaseQueued')then return refuse(S.Text.Busy)end
 if self.Gifts and self.Gifts.Busy and self.Gifts.Busy[player]then return refuse(S.Text.Gift)end
 -- the item, among the player's own Tools (built by the server from the saved records)
 local chosen
 for _,c in ipairs(containers(player))do for _,t in ipairs(c:GetChildren())do
  if t:IsA('Tool')and Stacks.Id(t)==id then chosen=t end
 end end
 if not chosen then return refuse(S.Text.Gone)end
 if not Stacks.Counts(chosen)then return refuse(S.Text.NotItem)end
 if Stacks.Kind(chosen)~=kind then return refuse(S.Text.Invalid)end
 local locked=self:_locked(player)
 if locked[id]then return refuse(S.Text[locked[id]])end
 -- its stack: every Tool of the same key (a loot item is a stack of its own); in hand last, then the newest first
 local key=Stacks.Key(chosen);local members={}
 for _,c in ipairs(containers(player))do for _,t in ipairs(c:GetChildren())do
  if t:IsA('Tool')and(t==chosen or(key~=nil and Stacks.Key(t)==key))then
   local tid=Stacks.Id(t);if tid and not locked[tid]then members[#members+1]={Tool=t,Id=tid,Held=t.Parent==player.Character}end
  end
 end end
 if count>#members then return refuse(S.Text.Amount)end
 local order={};for i,r in ipairs(data:GetChestRecords(player))do order[r.Id]=i end
 local garden=data.Gardens[player];for i,r in ipairs(garden and garden.Harvests or{})do order[r.Id]=i end
 table.sort(members,function(a,b)if a.Held~=b.Held then return b.Held end;return(order[a.Id]or 0)>(order[b.Id]or 0)end)
 local ids,picked={},{};local unequip=false
 for i=1,count do ids[members[i].Id]=true;picked[#picked+1]=members[i].Id;if members[i].Held then unequip=true end end
 local name=chosen.Name
 -- an item in the hand is put away first (a held pack ends its uncommitted opening normally, as a gift does)
 if unequip then local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid');if h then pcall(function()h:UnequipTools()end)end end
 local removed,gone=data:DiscardRecords(player,kind,ids)
 if removed<=0 then return refuse(S.Text.Gone)end
 -- (R155 review) the log names the records that REALLY went, in the order they went (the newest first, the one in hand last), not the id the client asked
 -- about: that one is the stack's representative (the oldest or the one in hand) and stays when fewer than all are thrown away
 local went={};for _,tid in ipairs(picked)do if gone[tid]then went[#went+1]=tid end end
 local shown=table.concat(went,', ',1,math.min(#went,S.LogIds));if #went>S.LogIds then shown..=' +'..(#went-S.LogIds)..' more' end
 data:NoteDiscard(player,('threw away %dx %s (%s %s%s)'):format(removed,name,kind,shown,gone[id]and''or'; asked about '..id..', kept'))
 if self.Chests then pcall(function()self.Chests:SyncTools(player)end)end
 return {Ok=true,Removed=removed,Name=name,Held=data:HeldItemCount(player),Message=removed==1 and('threw away '..name)or('threw away '..removed..'x '..name)}
end
function S:Start()
 if self.Started then return self end;self.Started=true
 local folder=RS:WaitForChild('ChestChaseRemotes')
 local discard=folder:FindFirstChild('DiscardItems')or Instance.new('RemoteFunction');discard.Name='DiscardItems';discard.Parent=folder
 discard.OnServerInvoke=function(player,request)
  if not require(script.Parent.SecurityGate).Allow(player,'Discard',request)then return refuse('SLOW DOWN!')end
  local ok,result=pcall(function()return self:Discard(player,request)end)
  if ok then return result end
  warn('[R155] Discard failed: '..tostring(result));return refuse(S.Text.Invalid)
 end
 local layout=folder:FindFirstChild('HotbarLayout155')or Instance.new('RemoteEvent');layout.Name='HotbarLayout155';layout.Parent=folder
 layout.OnServerEvent:Connect(function(player,text)
  if not require(script.Parent.SecurityGate).Allow(player,'HotbarLayout',text)then return end
  self.Data:SetHotbarLayout(player,text)
 end)
 self.DiscardRemote,self.LayoutRemote=discard,layout
 return self
end
return S
