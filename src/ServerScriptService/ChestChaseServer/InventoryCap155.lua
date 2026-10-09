-- R155 (owner: "make the max amount of items a person can hold 200"): ONE cap on everything a player holds, attached to PlayerDataService.
--  * Held = packs + seeds (the seed records) + fruit (the harvest bag) + legacy loot items. Plants in the garden and owned gear (boots, trails, the
--    shovel, the bat) do not count. A stack of N counts N: the save holds N separate records (each with its own id, size, weight and traits, each opened,
--    planted, gifted or sold on its own); a stack is only how the Hotbar / Bag draws identical records (InventoryStacks155).
--  * The cap is InventoryStacks155.Cap (200), shared with the client's Bag; Config.lua is left untouched (older suites keep it byte-identical); a
--    Config.MaxHeldItems, if the owner ever adds one, overrides it.
--  * RoomFor(player, n [, opts]) is the check every grant path makes (PlayerDataService:CanReceiveSeed -> AddChest, HarvestPlant, gifts, the Mech offers,
--    the daily / Void / owner grants). While a player carries a stolen pack home (ChestChaseSeedCarrying) its place is kept: every other grant counts it,
--    so a full bag never eats a stolen pack. opts.Banked: this IS that pack (ChestService:Bank passes it; ConcurrentKeeperService clears the carry flag just
--    before it banks): never refused for the cap, because its place was kept at the pickup (a paid receipt, which skips the cap, may have taken that place
--    meanwhile: 199 + a carried pack + a receipt = 200, and the bank must still land). opts.Receipt: a paid Robux receipt, never refused for the cap. For both
--    only the old storage ceiling, Config.MaxSavedChests (CanReceiveSeed), still applies; the shop never offers a purchase that does not fit, see
--    PremiumProgress.CanReceiveMechPacks).
--  * Nothing above the cap is ever deleted or truncated: a player who already holds more keeps all of it and simply receives nothing until under 200.
--    The save validators keep their old storage ceilings (MaxSavedChests 1000, MaxSavedHarvests 500), so every older save still loads.
--  * HeldItemCount / HeldItemCap are published on the Player (attributes) for the Bag's "143/200".
--  * The hotbar layout (GardenInventoryState.Serialize, ~100 characters) is saved as the optional Premium.Hotbar155 (an older server keeps an unknown
--    Premium field as it is), handed to the client at join as the attribute HotbarLayout155 ('' = none saved).
--  * DiscardRecords removes exactly the given records (InventoryService155 decides which, after its checks).
local M={}
M.Default=require(game:GetService('ReplicatedStorage'):WaitForChild('InventoryStacks155')).Cap -- 200 (a Config.MaxHeldItems would override it)
M.FullText='BAG FULL - MAKE ROOM IN YOUR BAG FIRST'
M.HarvestFullText='BAG FULL - SELL OR PLANT SOMETHING FIRST'
M.LogSize=20
function M.ValidLayout(text)
 if type(text)~='string'or #text>200 then return false end
 local ok,slots=pcall(function()return require(game:GetService('ReplicatedStorage'):WaitForChild('GardenInventoryState')).Parse(text)end)
 return ok and slots~=nil
end
function M.Attach(Data)
 function Data:HeldItemCap()return tonumber(self.Config and self.Config.MaxHeldItems)or M.Default end
 function Data:HeldItemCount(player)
  local n=#self:GetChestRecords(player)
  local garden=self.Gardens and self.Gardens[player];if garden and type(garden.Harvests)=='table'then n+=#garden.Harvests end
  local loot=player:FindFirstChild('LootInventory')
  if loot then for _,v in ipairs(loot:GetChildren())do if v:IsA('StringValue')then n+=1 end end end
  return n
 end
 function Data:RoomFor(player,count,opts)
  count=tonumber(count)or 1
  if not self:IsLoaded(player)then return false,'YOUR DATA IS STILL LOADING'end
  opts=type(opts)=='table'and opts or{}
  if opts.Receipt or opts.Banked then return true end
  local held=self:HeldItemCount(player)
  if player:GetAttribute('ChestChaseSeedCarrying')==true then held+=1 end -- (the pack being carried home has its place kept)
  if held+count>self:HeldItemCap()then return false,M.FullText end
  return true
 end
 function Data:PublishHeld(player)
  if not player or not player.Parent then return end
  local n=self:HeldItemCount(player)
  if player:GetAttribute('HeldItemCount')~=n then player:SetAttribute('HeldItemCount',n)end
  local cap=self:HeldItemCap();if player:GetAttribute('HeldItemCap')~=cap then player:SetAttribute('HeldItemCap',cap)end
 end
 -- The hotbar layout --------------------------------------------------------------------------------------------------------------------------
 function Data:LoadHotbarLayout(player)
  local premium=self.Premium and self.Premium[player]
  local text=premium and premium.Hotbar155
  if text~=nil and not M.ValidLayout(text)then premium.Hotbar155=nil;text=nil end -- (anything odd is dropped, never a reason to refuse a save)
  player:SetAttribute('HotbarLayout155',text or'')
 end
 function Data:SetHotbarLayout(player,text)
  if not self:IsLoaded(player)or not M.ValidLayout(text)then return false end
  local premium=self.Premium and self.Premium[player];if not premium then return false end
  if premium.Hotbar155==text then return true end
  premium.Hotbar155=text;self:MarkDirty(player);return true
 end
 -- Discarding: exactly these records, nothing else. kind 'Pack' | 'Seed' | 'Fruit' | 'Loot'; ids = {id=true}. Never yields. Returns how many went, and the
 -- set {id=true} of the records that really went (the discard log names these, not the id the client asked about).
 function Data:DiscardRecords(player,kind,ids)
  if not self:IsLoaded(player)or type(ids)~='table'then return 0,{} end
  local removed,gone=0,{}
  if kind=='Pack'or kind=='Seed'then
   local records=self:GetChestRecords(player)
   for i=#records,1,-1 do local r=records[i]
    if ids[r.Id]and((kind=='Pack')==(r.Kind=='Pack'))then
     table.remove(records,i);removed+=1;gone[r.Id]=true
     local tests=self.StudioPackRewards and self.StudioPackRewards[player];if tests then tests[r.Id]=nil end
    end
   end
   if removed>0 then self:_notifySeedInventory(player);self:MarkDirty(player);self:_gardenChanged(player)end
  elseif kind=='Fruit'then
   local garden=self.Gardens[player];local list=garden and garden.Harvests or{}
   for i=#list,1,-1 do if ids[list[i].Id]then gone[list[i].Id]=true;table.remove(list,i);removed+=1 end end
   if removed>0 then self:_gardenChanged(player)end
  elseif kind=='Loot'then
   local loot=player:FindFirstChild('LootInventory')
   for _,v in ipairs(loot and loot:GetChildren()or{})do if v:IsA('StringValue')and ids[v.Name]then gone[v.Name]=true;v:Destroy();removed+=1 end end
   if removed>0 then self:MarkDirty(player);self:PublishHeld(player)end
  end
  if removed>0 and self.QueueGardenSave then self:QueueGardenSave(player)end
  return removed,gone
 end
 -- a legacy loot item handed back (the old pedestal) changes the count too
 local award=Data.AwardLoot
 function Data:AwardLoot(player,...)local value=award(self,player,...);self:PublishHeld(player);return value end
 -- what /test hotbar prints: the last discards of this player (and the server's Output line for each)
 function Data:NoteDiscard(player,text)
  self.DiscardLog=self.DiscardLog or setmetatable({},{__mode='k'})
  local log=self.DiscardLog[player]or{};self.DiscardLog[player]=log
  log[#log+1]=os.date('!%H:%M:%S')..' '..text;if #log>M.LogSize then table.remove(log,1)end
  print('[R155 Discard] '..player.Name..' ('..tostring(player.UserId)..'): '..text)
 end
end
return M
