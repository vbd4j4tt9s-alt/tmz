-- R57: saved earned Gems, game-local perks, index bonuses and receipt identities.
local RS=game:GetService('ReplicatedStorage');local Http=game:GetService('HttpService')
local Catalog=require(RS.MechCatalog);local PackRules=require(RS.SeedPackRules);local Receipts=require(RS.SaleReceiptRules)
local T=require(RS.BalanceValues81)
local P={}
-- R126 (owner): bought Mech packs roll a pack size like world packs (BalanceRules.PackSizes).
local SizeRandom=Random.new()
-- R155 (owner: "We can implement 1C"): every BOUGHT Mech pack rolls a Gold / Diamond coat exactly like a world pack (SeedPackRules.RollMutation: the world's own weights, None 95 /
-- Gold 4.5 / Diamond .5), one roll per pack. The coat is the record's existing PackMutation field (saved and loaded like every pack's), so the seed it opens keeps it, the plant draws
-- Gold / Diamond and its fruit get the coat's x3 / x6 at the usual 20% (PlantRules). A FREE Mech pack (a daily grant, paid == false) stays plain, as every free pack does (the daily
-- and bonus-roll packs, the starter pack, the giveaway: PackMutation 'None'); a test pack (/test) never comes through here. P.RollCoat is the one place the roll is drawn (tests replace it).
local CoatRandom=Random.new()
function P.RollCoat()return PackRules.RollMutation(CoatRandom:NextNumber())end
local function integer(n,lo,hi)return type(n)=='number'and n==n and n%1==0 and n>=lo and n<=hi end
local function copy(t)local out={};for k,v in pairs(t)do out[k]=type(v)=='table'and copy(v)or v end;return out end
-- R153: passes added after R152 (GamePassCatalog Late) keep their saved data apart, in the optional field Premium.Later153 = {Entitlements={Clover=true},GiftCredits={Clover=n},PassOutbox={[id]=gift}}:
-- an R152 server rejects an Entitlements / GiftCredits / PassOutbox key it does not know (UnsupportedPremium: it kicks the player, the save stays safe) but keeps an unknown Premium field as it
-- is, so there the field is simply ignored. In memory everything stays where the other passes are (Entitlements ...): Pack (on the copy that is being saved) moves the late keys out,
-- Unpack (Decode) moves them back. Keys of a pass this server does not know stay inside Later153 untouched, so a newer server's data survives an older server's save.
local function lateKeys()local set={};for _,p in ipairs(require(RS.GamePassCatalog))do if p.Late then set[p.Key]=true end end;return set end
function P.Pack(premium)
 local late=lateKeys();local out=type(premium.Later153)=='table'and premium.Later153 or{}
 for _,name in ipairs({'Entitlements','GiftCredits','PassOutbox'})do if type(out[name])~='table'then out[name]={}end end
 for key in pairs(late)do for _,name in ipairs({'Entitlements','GiftCredits'})do
  local map=premium[name];if type(map)=='table'and map[key]~=nil then out[name][key]=map[key];map[key]=nil end
 end end
 if type(premium.PassOutbox)=='table'then for id,gift in pairs(premium.PassOutbox)do if type(gift)=='table'and late[gift.PassKey]then out.PassOutbox[id]=gift;premium.PassOutbox[id]=nil end end end
 local any=false;for _,name in ipairs({'Entitlements','GiftCredits','PassOutbox'})do if next(out[name])~=nil then any=true end end
 premium.Later153=any and out or nil
 return premium
end
-- saved Premium -> a copy with the late keys back where the checks look (nil = the field is not what Pack writes).
function P.Unpack(saved)
 local result=copy(saved);local later=result.Later153;result.Later153=nil
 if later==nil then return result end
 if type(later)~='table'then return nil end
 local known=lateKeys();local rest={Entitlements={},GiftCredits={},PassOutbox={}}
 for _,name in ipairs({'Entitlements','GiftCredits','PassOutbox'})do
  local map=later[name];if map==nil then continue end
  if type(map)~='table'then return nil end
  result[name]=result[name]or{}
  if type(result[name])~='table'then return nil end
  for key,value in pairs(map)do
   if name=='PassOutbox'then
    if type(value)=='table'and known[value.PassKey]then result[name][key]=value else rest[name][key]=value end
   elseif known[key]then result[name][key]=value else rest[name][key]=value end
  end
 end
 for _,name in ipairs({'Entitlements','GiftCredits','PassOutbox'})do if next(rest[name])~=nil then result.Later153=rest;break end end
 return result
end
function P.Decode(saved)
 if saved==nil then return {Version=2,BalanceVersion81=81,IndexRewardVersion=104,BiomeBackpay81={},BiomeHalfRewards={},OldRoster148={},Gems=0,Entitlements={},Biomes={},Receipts={},Plants={},SeedRewards={},Settings=require(RS.SettingsConfig).Read()}end
 if type(saved)~='table'or (saved.Version~=1 and saved.Version~=2) or not integer(saved.Gems,0,Catalog.MaxGems)then return nil end
 saved=P.Unpack(saved);if not saved then return nil end -- R153: the late passes' saved data (Later153) goes back where the checks below look
 for _,key in ipairs({'Entitlements','Biomes','Receipts'})do
  if type(saved[key])~='table'then return nil end
  local n=0;for id,v in pairs(saved[key])do
   n+=1;if n>20000 or type(id)~='string'or #id<1 or #id>100 or v~=true then return nil end
   if key=='Entitlements'and not Catalog.PassGemPrices[id]then return nil end
   if key=='Biomes'and not integer(tonumber(id),1,9)then return nil end
  end
 end
 local result=copy(saved)
 if not require(script.Parent.PassGiftState).Valid(result)then return nil end
 if result.BiomeHalfRewards==nil then result.BiomeHalfRewards={}end
 if type(result.BiomeHalfRewards)~='table'then return nil end
 for key,value in pairs(result.BiomeHalfRewards)do
  local stage=type(key)=='string'and tonumber(key)
  if not integer(stage,1,9)or key~=tostring(stage)or value~=true then return nil end
 end
 if result.IndexRewardVersion~=nil and result.IndexRewardVersion~=104 then return nil end
 -- Pre-R104 full rewards included the midpoint. New claims are independent.
 if result.IndexRewardVersion~=104 then
  for key in pairs(result.Biomes)do result.BiomeHalfRewards[tostring(tonumber(key))]=true end
 end
 result.IndexRewardVersion=104
 result.Plants=result.Plants or{};result.SeedRewards=result.SeedRewards or{}
 local total=0
 for _,key in ipairs({'Plants','SeedRewards'})do
  if type(result[key])~='table'then return nil end
  local count=0
  for id,value in pairs(result[key])do
   count+=1;if count>256 or type(id)~='string'or #id<1 or #id>80 then return nil end
   if key=='Plants'then if value~=true then return nil end
   else if not integer(value,1,Receipts.MaxCash)then return nil end;total+=value end
  end
 end
 if total>Receipts.MaxCash then return nil end
 if result.Tutorial~=nil then result.Tutorial=require(RS.BeginnerGuide).Read(result.Tutorial);if not result.Tutorial then return nil end end
  result.BiomeBackpay81=result.BiomeBackpay81 or{}
  if type(result.BiomeBackpay81)~='table'then return nil end
  for key,value in pairs(result.BiomeBackpay81)do if not integer(tonumber(key),1,9)or not integer(value,0,50)then return nil end end
  if result.BalanceVersion81~=81 then
   for key in pairs(result.Biomes)do result.BiomeBackpay81[key]=math.max(0,(T.LegacyCompletionGems[tonumber(key)]or 5)-5)end
   result.BalanceVersion81=81
  end
  -- R148: the Index milestones (halfway / complete) a player had already reached under the roster before the Aloe and the Sand Fruit joined Desert's
  -- Index. Recorded once, on the first load after the roster change (nil until then); a new player starts with none. Anything unreadable counts as not
  -- recorded yet, and only the categories the roster change touched can hold a flag.
  if result.OldRoster148~=nil then
   local clean;if type(result.OldRoster148)=='table'then
    clean={Half={},Full={}}
    for _,kind in ipairs({'Half','Full'})do
     if type(result.OldRoster148[kind])=='table'then for key,value in pairs(result.OldRoster148[kind])do
      local stage=type(key)=='string'and tonumber(key)
      if value==true and integer(stage,1,9)and key==tostring(stage)and P.RosterChangeStages()[stage]then clean[kind][key]=true end
     end end
    end
   end
   result.OldRoster148=clean
  end
  result.Settings=require(RS.SettingsConfig).Read(result.Settings);result.Version=2;return result
end
-- R148: the Index categories whose roster grew (the stages of PackRules.NewInR149), as a set.
local rosterStages
function P.RosterChangeStages()
 if not rosterStages then rosterStages={};for id in pairs(PackRules.NewInR149)do local stage=PackRules.ObtainableStage(id);if stage then rosterStages[stage]=true end end end
 return rosterStages
end
function P.Attach(Data)
 function Data:GetPremium(player)
  self.Premium=self.Premium or{};if not self.Premium[player]then self.Premium[player]=P.Decode(nil)end
  require(script.Parent.PassGiftState).Initialize(self.Premium[player])
  return self.Premium[player]
 end
 function Data:PublishPremium(player)
  local state=self:GetPremium(player);player:SetAttribute('Gems',state.Gems)
  for _,pass in ipairs(require(RS.GamePassCatalog))do
   if state.Entitlements[pass.Key]then player:SetAttribute(pass.Attribute,true)end
  end
  for i=1,9 do local pending=(state.BiomeBackpay81 or{})[tostring(i)]or 0
   player:SetAttribute('IndexBiomeReward'..i,state.Biomes[tostring(i)]==true and pending==0)
   player:SetAttribute('IndexBiomeHalfReward'..i,(state.BiomeHalfRewards or{})[tostring(i)]==true)
   player:SetAttribute('IndexBiomeBackpay'..i,T.HalveGems(pending)) -- R153: a pending backpay pays half (shown = claimed)
   -- R148: the milestones already met under the old roster (ChestIndex ORs them with the live ones, as IndexMilestone does)
   local old=state.OldRoster148 or{}
   player:SetAttribute('IndexOldHalf'..i,(old.Half or{})[tostring(i)]==true)
   player:SetAttribute('IndexOldFull'..i,(old.Full or{})[tostring(i)]==true)
  end
  self:PublishIndex(player)
  player:SetAttribute('PremiumRevision',(player:GetAttribute('PremiumRevision')or 0)+1)
 end
 function Data:CurrencyReceipt(player,amount,currency)
  if not self:IsLoaded(player)or not integer(amount,1,Receipts.MaxCash)then return nil,'TRY AGAIN!'end
  if currency~='Cash'and currency~='Gems'then return nil,'TRY AGAIN!'end
  local garden=self.Gardens[player];if not garden then return nil,'YOUR GARDEN IS LOADING...'end
  local pending=garden.PendingSales or{};local limit=currency=='Gems'and Catalog.MaxGems or Receipts.MaxCash
  local balance=currency=='Gems'and self:GetPremium(player).Gems or self:GetCash(player)
  if #pending>=Receipts.MaxReceipts then return nil,'YOUR LAST REWARDS ARE STILL ARRIVING'end
  if balance+Receipts.Total(pending,currency)+amount>limit then return nil,'YOU\'RE MAXED OUT! SPEND SOME FIRST'end
  return {Id=Http:GenerateGUID(false),Currency=currency,Amount=amount,Count=currency=='Gems'and math.min(amount,math.random(3,5))or math.random(8,13),Claimed=0}
 end
 function Data:QueueCurrency(player,amount,currency)
  local receipt,why=self:CurrencyReceipt(player,amount,currency);if not receipt then return false,why end
  local garden=self.Gardens[player];garden.PendingSales=garden.PendingSales or{};table.insert(garden.PendingSales,receipt)
  self:_gardenChanged(player);self:QueueGardenSave(player);return true,receipt
 end
 function Data:ConvertGems(player,count)
  if not integer(count,1,9000)then return false,'TYPE A WHOLE NUMBER OF GEMS'end
  local cost=count*Catalog.CashPerGem
  if self:GetCash(player)<cost then return false,'NOT ENOUGH CASH'end
  local receipt,why=self:CurrencyReceipt(player,count,'Gems');if not receipt then return false,why end
  if not self:SpendCash(player,cost)then return false,'NOT ENOUGH CASH'end
  local garden=self.Gardens[player];garden.PendingSales=garden.PendingSales or{};table.insert(garden.PendingSales,receipt)
  self:_gardenChanged(player);self:QueueGardenSave(player);return true,'Your Gems are on the way!'
 end
 -- R155: the 200 cap (InventoryCap155.RoomFor) decides whether the shop offers the packs at all (gems and Robux). receipt = a paid Robux receipt being granted:
 -- the cap never refuses it (the purchase was only offered when it fitted; an item that arrived in between must not cost the buyer the packs), only the old
 -- storage ceiling (MaxSavedChests) can, and then the receipt waits (NotProcessedYet) as before.
 function Data:CanReceiveMechPacks(player,count,receipt)
  local offer=Catalog.Offer(count)
  if not offer or not self:IsLoaded(player)then return false,'HOLD ON, YOUR DATA IS LOADING!'end
  -- R157: a full Bag says one simple thing on every Mech path (the shop's state flag BagFull, a gem purchase, a Robux prompt): MechCatalog.BagFull.Notice
  if #self:GetChestRecords(player)+offer.Count>self.Config.MaxSavedChests then return false,Catalog.BagFull.Notice end
  if type(self.RoomFor)=='function'and not self:RoomFor(player,offer.Count,{Receipt=receipt==true})then return false,Catalog.BagFull.Notice end
  return true
 end
 function Data:GrantMechPacks(player,paid,count,receipt)
  local offer=Catalog.Offer(count);local okay,why=self:CanReceiveMechPacks(player,count,receipt)
  if not okay then return nil,why end
  -- AddChest never yields. Check the entire batch before starting; roll back any
  -- unexpected failure before another request or profile save can observe it.
  local records=self:GetChestRecords(player);local before=#records
  local serial=player:GetAttribute('ChestInventorySerial');local added={}
  local success,err=pcall(function()
   for _=1,offer.Count do
    local record,reason=self:AddChest(player,{Stage=8,BagVariant=Catalog.Variant,PackSize=PackRules.RollPackSize(SizeRandom:NextNumber()),PackMutation=paid==true and P.RollCoat()or'None'},receipt==true and{Receipt=true}or nil) -- R155: a bought pack rolls its coat; a paid receipt is never refused for the 200 cap
    assert(record,reason or 'PACK COULD NOT BE ADDED')
    record.PaidRandom=paid==true;record.ChestName=Catalog.Name;added[#added+1]=record
   end
  end)
  if not success then
   while #records>before do table.remove(records)end
   player:SetAttribute('ChestInventorySerial',serial);self:_notifySeedInventory(player)
   warn('[Mech batch] '..tostring(err));return nil,'COULDN\'T ADD THE PACKS! TRY AGAIN'
  end
  self:MarkDirty(player);self:QueueGardenSave(player);return added
 end
 function Data:GrantMechPack(player,paid)
  local records,why=self:GrantMechPacks(player,paid,1);return records and records[1],why
 end
 function Data:BuyMechPack(player,count)
  local offer=Catalog.Offer(count);if not offer then return false,'TRY AGAIN!'end
  if not self:IsLoaded(player)then return false,'HOLD ON, YOUR DATA IS LOADING!'end
  if player:GetAttribute('PaidRandomAllowed')~=true then return false,'CAN\'T BUY THIS PACK RIGHT NOW'end
  if Catalog.EventOver()then return false,Catalog.Event.Refused end -- R155: the limited event is over: nothing is charged, nothing is granted
  if not Catalog.OnSale()then return false,'THIS PACK IS OFF SALE'end
  local fits,full=self:CanReceiveMechPacks(player,offer.Count);if not fits then return false,full end -- R157: a full Bag is told first (before "not enough gems"), with the same words as the Robux path
  local state=self:GetPremium(player)
  if state.Gems<offer.GemPrice then return false,'NOT ENOUGH GEMS'end
  local packs,why=self:GrantMechPacks(player,true,offer.Count);if not packs then return false,why end
  state.Gems-=offer.GemPrice;self:PublishPremium(player);self:MarkDirty(player)
  return true,offer.Count==1 and'Mech pack is in your bag!'or offer.Count..' Mech packs are in your bag!',packs -- R155: the third result is the new records (their coats go in the "Bought" notice)
 end
 -- R123: the R121 timed x2 boost and product gifts were removed; old saved fields are kept untouched and unused.
 function Data:CanReceiveBundle(player,key)
  local row=require(RS.PremiumPricing).Find(key)
  if not row or not self:IsLoaded(player)then return false,'NOT AVAILABLE RIGHT NOW'end
  if row.Kind=='Cash'then
   local receipt,why=self:CurrencyReceipt(player,row.Amount,'Cash');return receipt~=nil,why
  end
  local value=self:GetOrCreateSpeedValue(player)
  return true
 end
 function Data:GrantPremiumBundle(player,key)
  local okay,why=self:CanReceiveBundle(player,key);if not okay then return false,why end
  local row=require(RS.PremiumPricing).Find(key)
  if row.Kind=='Cash'then return self:QueueCurrency(player,row.Amount,'Cash')end
  self:AddSpeed(player,row.Amount)
  self:MarkDirty(player);self:QueueGardenSave(player);return true
 end
 function Data:BundleQuote(player,key)
  local row=require(RS.PremiumPricing).Find(key)
  if not row or not self:IsLoaded(player)then return nil end
  local amount=row.Amount
  return {Key=key,Amount=amount,GemPrice=row.GemPrice,Kind=row.Kind}
 end
 function Data:BuyPremiumBundle(player,value)
  local key=type(value)=='table'and value.Key or value
  if type(key)~='string'then return false,'NOT AVAILABLE RIGHT NOW'end
  local quote=self:BundleQuote(player,key);if not quote then return false,'NOT AVAILABLE RIGHT NOW'end
  -- Reject stale displayed quotes; prices/rewards never come from the client.
  if type(value)=='table'and(value.Amount~=quote.Amount or value.GemPrice~=quote.GemPrice)then return false,'The offer changed! Check the new amount.'end
  local state=self:GetPremium(player);if state.Gems<quote.GemPrice then return false,'NOT ENOUGH GEMS'end
  local okay,why
  if quote.Kind=='Cash'then okay,why=self:QueueCurrency(player,quote.Amount,'Cash')
  else okay,why=self:GrantPremiumBundle(player,key)end
  if not okay then return false,why end
  state.Gems-=quote.GemPrice;self:PublishPremium(player);self:MarkDirty(player);self:QueueGardenSave(player)
  return true,quote.Kind=='Cash'and'Your Cash is on the way!'or'Speed added!'
 end
 function Data:BuyGemPerk(player,key)
  if not self:IsLoaded(player)or not self.CanSave[player]or type(key)~='string'then return false,'HOLD ON, YOUR DATA IS LOADING!'end
  local price=Catalog.PassGemPrices[key];if not price then return false,'TRY AGAIN!'end
  local state=self:GetPremium(player);local pass
  for _,p in ipairs(require(RS.GamePassCatalog))do if p.Key==key then pass=p;break end end
  if not pass or state.Entitlements[key]or player:GetAttribute(pass.Attribute)then return false,'YOU ALREADY HAVE THIS!'end
  if state.Gems<price then return false,'NOT ENOUGH GEMS'end
  if type(self.PassOwnership)~='function'then return false,'STILL CHECKING WHAT YOU OWN...'end
  local okay,owned=pcall(self.PassOwnership,player,key)
  if not player.Parent or not self:IsLoaded(player)or not self.CanSave[player]or self:GetPremium(player)~=state then return false,'HOLD ON, YOUR DATA IS LOADING!'end
  -- Recheck after the ownership request; a purchase or gift may have completed.
  if state.Entitlements[key]or player:GetAttribute(pass.Attribute)or owned==true then return false,'YOU ALREADY HAVE THIS!'end
  if not okay or owned~=false then return false,'STILL CHECKING WHAT YOU OWN...'end
  if state.Gems<price then return false,'NOT ENOUGH GEMS'end
  state.Gems-=price;state.Entitlements[key]=true;self:PublishPremium(player);self:MarkDirty(player);self:QueueGardenSave(player)
  return true,pass.Name..' unlocked!'
 end
 function Data:PublishIndex(player)
  local state=self:GetPremium(player);local plants=player:FindFirstChild('DiscoveredPlants')
  if not plants then plants=Instance.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player end
  for id in pairs(state.Plants)do
   if not plants:FindFirstChild(id)then local v=Instance.new('BoolValue');v.Name=id;v.Value=true;v.Parent=plants end
  end
  for _,v in ipairs(self:GetOrCreateDiscoveredSeeds(player):GetChildren())do v:SetAttribute('RewardCash',state.SeedRewards[v.Name]or 0)end
 end
 function Data:MarkAdultDiscovered(player,id)
  if not self:IsLoaded(player)or not self.Config.GardenPlants[id]then return false end
  local state=self:GetPremium(player);if state.Plants[id]then return false end
  state.Plants[id]=true;self:PublishPremium(player);self:MarkDirty(player);self:QueueGardenSave(player);return true
 end
 -- R148: beforeR149 = count the roster before Desert's Aloe and Sand Fruit (PackRules.NewInR149 left out).
 function Data:IndexProgress(player,stage,beforeR149)
  local pool=PackRules.ObtainablePool(self.Config,stage)or{};local folder=self:GetOrCreateDiscoveredSeeds(player);local state=self:GetPremium(player)
  local seeds,plants,total=0,0,0
  for _,seed in ipairs(pool)do
   if not(beforeR149 and PackRules.NewInR149[seed.Id])then
    total+=1;local v=folder:FindFirstChild(seed.Id);if v and v.Value then seeds+=1 end;if state.Plants[seed.Id]then plants+=1 end
   end
  end
  return seeds,plants,total
 end
 -- R148: Desert's Index grew from 5 to 7 seeds. A player who had ALREADY reached a halfway / completion milestone with the old roster keeps it
 -- (an unclaimed reward is never taken away): SettleOldRoster148 records those once, on the first load after the roster change, and a milestone is
 -- the live one OR that saved flag. Everyone else (new players, and old players who had not got there) needs the full seven. ChestIndex shows the
 -- same rule from the published IndexOldHalf<stage> / IndexOldFull<stage> attributes.
 function Data:SettleOldRoster148(player)
  local state=self:GetPremium(player);if state.OldRoster148~=nil then return false end
  local old={Half={},Full={}}
  for stage in pairs(P.RosterChangeStages())do
   local seeds,plants,total=self:IndexProgress(player,stage,true)
   if total>0 and seeds+plants>=total then old.Half[tostring(stage)]=true end
   if total>0 and seeds==total and plants==total then old.Full[tostring(stage)]=true end
  end
  state.OldRoster148=old;return true
 end
 function Data:IndexMilestone(player,stage,full)
  local seeds,plants,total=self:IndexProgress(player,stage)
  if total>0 and(full and seeds==total and plants==total or not full and seeds+plants>=total)then return true end
  local state=self:GetPremium(player)
  if state.OldRoster148==nil then self:SettleOldRoster148(player)end -- (the load already did; this only covers a state that never went through it)
  return((state.OldRoster148 or{})[full and'Full'or'Half']or{})[tostring(stage)]==true
 end
 function Data:BiomeComplete(player,stage)return self:IndexMilestone(player,stage,true)end
 function Data:RefreshBiomeRewards(player)
  -- Mature crops and owned harvests are evidence of an adult plant on migration/rejoin.
  if not self:IsLoaded(player)then return end
  local state=self:GetPremium(player);local garden=self.Gardens[player];local changed=false
  if garden then
   for _,crops in pairs(garden.Plots)do for _,crop in ipairs(crops)do
    if self.Config.GardenPlants[crop.SeedId]and os.time()>=(crop.MatureAt or crop.ReadyAt)and not state.Plants[crop.SeedId]then state.Plants[crop.SeedId]=true;changed=true end
   end end
   for _,crop in ipairs(garden.Harvests)do if self.Config.GardenPlants[crop.SeedId]and not state.Plants[crop.SeedId]then state.Plants[crop.SeedId]=true;changed=true end end
  end
  if changed then self:MarkDirty(player);self:QueueGardenSave(player);self:PublishPremium(player)end
 end
 function Data:SeedCollectReward(player,seedId)
  local _,rarity=PackRules.GetRarity(seedId);local stage=PackRules.ObtainableStage(seedId)or 1
  local discovered=self:GetOrCreateDiscoveredSeeds(player):FindFirstChild(seedId)
  local amount=(discovered and T.IndexRepeat[seedId]or T.IndexFirst[seedId])or 100*rarity.Rank*(self.Config.BiomeRank[stage]or stage);local total=amount
  for _,n in pairs(self:GetPremium(player).SeedRewards)do total+=n end
  if total>Receipts.MaxCash then return nil,'CLAIM YOUR INDEX REWARDS FIRST!'end
  return amount
 end
 function Data:CommitSeedReward(player,seedId,amount)
  local rewards=self:GetPremium(player).SeedRewards;rewards[seedId]=(rewards[seedId]or 0)+amount;self:PublishPremium(player)
 end
 function Data:ClaimIndexSeed(player,id)
  if not self:IsLoaded(player)or type(id)~='string'or #id>80 then return false,'TRY AGAIN!'end
  local state=self:GetPremium(player);local amount=state.SeedRewards[id]
  local v=self:GetOrCreateDiscoveredSeeds(player):FindFirstChild(id)
  if not amount or not v or not v.Value then return false,'NOTHING TO CLAIM YET'end
  -- Queueing and clearing the entitlement never yield; a replay cannot grant it twice.
  local okay,why=self:QueueCurrency(player,amount,'Cash');if not okay then return false,why end
  state.SeedRewards[id]=nil;self:PublishPremium(player);self:MarkDirty(player);self:QueueGardenSave(player)
  return true,'Your Cash is on the way!'
 end
 function Data:ClaimIndexBiomeHalf(player,stage)
  if not self:IsLoaded(player)or not integer(stage,1,9)then return false,'TRY AGAIN!'end
  local state=self:GetPremium(player);local key=tostring(stage)
  if(state.BiomeHalfRewards or{})[key]then return false,'YOU ALREADY CLAIMED THIS!'end
  if not self:IndexMilestone(player,stage,false)then return false,'FILL HALF OF THIS INDEX FIRST!'end
  local amount=T.HalfwayGems
  local okay,why=self:QueueCurrency(player,amount,'Gems');if not okay then return false,why end
  state.BiomeHalfRewards=state.BiomeHalfRewards or{};state.BiomeHalfRewards[key]=true
  self:PublishPremium(player);self:MarkDirty(player);self:QueueGardenSave(player);return true,'Your Gems are on the way!'
 end
 function Data:ClaimIndexBiome(player,stage)
  if not self:IsLoaded(player)or not integer(stage,1,9)then return false,'TRY AGAIN!'end
  local state=self:GetPremium(player);local key=tostring(stage)
  local backpay=(state.BiomeBackpay81 or{})[key]or 0
  if state.Biomes[key]and backpay==0 then return false,'YOU ALREADY CLAIMED THIS!'end
  if backpay==0 and not self:BiomeComplete(player,stage)then return false,'FIND EVERY SEED AND GROW EVERY PLANT!'end
  local amount=backpay>0 and T.HalveGems(backpay)or T.CompletionGems[stage] -- R153: Index gems are halved
  local okay,why=self:QueueCurrency(player,amount,'Gems');if not okay then return false,why end
  state.Biomes[key]=true
  state.BiomeBackpay81=state.BiomeBackpay81 or{};state.BiomeBackpay81[key]=nil;self:PublishPremium(player);self:MarkDirty(player);self:QueueGardenSave(player);return true,'Your Gems are on the way!'
 end
end
return P
