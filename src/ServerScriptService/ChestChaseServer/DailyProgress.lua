-- R141: daily claims stay in the existing Premium.Daily profile. Grants and
-- claim markers commit without yielding, using existing inventory/currency APIs.
-- R140 claimed quests retain their flags and count as 5 gems for today's cap (R141: 2; see DailyRewards.ReadQuests).
-- R153: a quest claim grants ONE pack (GrantDailyPack) and the all-done bonus (ClaimDailyBonus) is the only quest Gems: 2 a day.
local RS=game:GetService('ReplicatedStorage')
local D=require(RS.DailyRewards)
local PackRules=require(RS.SeedPackRules)
local BonusRules=require(RS.TreadmillBonusRules)
local PackRandom=Random.new() -- server only; no client reward/roll input
local T={}
-- R153 (owner: the random pack "is based on the player's treadmill ... the rolling luck will be same as the bonus roll"): the treadmill bonus roll's own RollPack (its odds,
-- and the pool the caller takes from the best treadmill: Storm = every biome pack), except the Void Pack, which is rolled again. Mech and Verity packs are not in that roll at all.
-- Pack01-Pack06 only (D.SeedPackVariants). draw: uniform [0,1).
function T.PickPack(stages,draw)
 for _=1,32 do
  local pick=BonusRules.RollPack(stages,draw)
  if not pick then return nil end
  if D.SeedPackVariants[pick.Variant]then return pick end
 end
 return nil
end
function T.Attach(Data)
 local function today()return D.Day(os.time())end
 -- A downstream notification hook can throw after an existing grant API commits.
 -- Recognize the exact one appended reward so retry cannot duplicate that grant.
 -- Dependencies must remain non-yielding, like the existing R140 claim contract.
 function Data:QueueDailyGems(player,amount)
  local garden=self.Gardens[player]
  if not garden then return false,'UR GARDEN IS LOADING...'end
  local before=#(garden.PendingSales or{})
  local okay,result,why=pcall(self.QueueCurrency,self,player,amount,'Gems')
  local pending=garden.PendingSales or{};local receipt=pending[before+1]
  if #pending==before+1 and type(receipt)=='table'and type(receipt.Id)=='string'and receipt.Currency=='Gems'and receipt.Amount==amount then
   return true
  end
  if not okay then warn('[R141 daily gems] '..tostring(result));return false,'COULDN\'T ADD THE GEMS! TRY AGAIN'end
  return false,why or 'COULDN\'T ADD THE GEMS! TRY AGAIN'
 end
 -- kind: nil = a random pack (R153: the bonus roll's), 'Void' = the login week's day 7 (R153: a normal Void Pack), true / 'Mech' = a Mech pack (no daily reward gives one any more).
 function Data:GrantDailyPack(player,kind)
  local mech=kind==true or kind=='Mech';local void=kind=='Void'
  local records=self:GetChestRecords(player);local before=#records
  if before>=self.Config.MaxSavedChests then return nil,'MAKE ROOM FOR 1 PACK FIRST!'end
  local pack
  if void then
   -- R153 (owner: "change the mech pack to void pack for day 7"): a real Void Pack (stage 7 EclipseReliquary, as the Darkened's and the bonus roll's Void result): a rolled size with the
   -- size pity, a normal giftable pack (no GiftLocked: that is only the free giveaway's); the Bag room was checked above, like every claim.
   if type(self.Config.SeedCatalogByStage)~='table'or not self.Config.SeedCatalogByStage[BonusRules.Void.Stage]then return nil,'DAILY PACKS AREN\'T READY YET'end
   pack={Stage=BonusRules.Void.Stage,BagVariant=BonusRules.Void.Variant,PackSize=PackRules.RollPackSize(PackRandom:NextNumber()),PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion}
  elseif not mech then
   -- R153: the treadmill bonus roll's pool (the best treadmill's biomes) and odds, its size roll and its size pity (Luck), like TreadmillBonusService:Roll
   local stages=BonusRules.PoolStages(self.Config.TreadmillTiers,self:GetTreadmillData(player).Tier)
   local pick=T.PickPack(stages,function()return PackRandom:NextNumber()end)
   if not pick or type(self.Config.SeedCatalogByStage)~='table'or not self.Config.SeedCatalogByStage[pick.Stage]then return nil,'DAILY PACKS AREN\'T READY YET'end
   pack={Stage=pick.Stage,BagVariant=pick.Variant,PackSize=PackRules.RollPackSize(PackRandom:NextNumber()),PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion} -- R147: current odds (without it AddChest stored the legacy 81 table)
  end
  local okay,result,why=pcall(function()
   if mech then return self:GrantMechPacks(player,false,1)end
   return self:AddChest(player,pack,{Luck=true}) -- no paid flag; the size pity is the bonus roll's (R137)
  end)
  local added=records[before+1]
  local expectedStage=mech and 8 or pack.Stage
  local expectedVariant=mech and 'MechLimited'or pack.BagVariant
  if #records==before+1 and type(added)=='table'and type(added.Id)=='string'and added.Kind=='Pack'and added.Stage==expectedStage and added.BagVariant==expectedVariant then
   -- Inventory is the commit point, including a throw in a later display hook.
   pcall(function()require(script.Parent.OwnerTestPacks).Claim(player,'Daily',added)end) -- R151: a login pack that an owner "daily" command made claimable is a TEST pack (never announced)
   return added
  end
  if not okay then warn('[R141 daily pack] '..tostring(result));return nil,'COULDN\'T ADD THE PACK! TRY AGAIN'end
  return nil,why or 'COULDN\'T ADD THE PACK! TRY AGAIN'
 end
 function Data:DailyData(player)
  local premium=self:GetPremium(player)
  if type(premium.Daily)~='table'then premium.Daily={}end
  local daily=premium.Daily;local day=today()
  daily.Login=D.ReadLogin(daily.Login)
  local quests=D.ReadQuests(daily.Quests,day,player.UserId)
  daily.Quests={Day=quests.Day,Progress=quests.Progress,Claimed=quests.Claimed,RewardVersion=quests.RewardVersion,GemsGranted=quests.GemsGranted,Bonus=quests.Bonus}
  return daily,quests,day
 end
 -- Attributes the HUD badge and the panel read: a login claim waiting, quests ready to claim, the day they are for.
 function Data:PublishDaily(player)
  if not self:IsLoaded(player)then return end
  local daily,quests,day=self:DailyData(player);local login=D.LoginStatus(daily.Login,day)
  player:SetAttribute('DailyLoginReady',login.Ready);player:SetAttribute('DailyLoginStep',login.Claimed)
  player:SetAttribute('DailyQuestsReady',D.QuestsReady(quests));player:SetAttribute('DailyDay',day)
  player:SetAttribute('DailyRevision',(player:GetAttribute('DailyRevision')or 0)+1)
 end
 function Data:DailyState(player)
  if not self:IsLoaded(player)then return {Success=false,Message='HOLD ON, UR DATA IS LOADING!'}end
  local daily,quests,day=self:DailyData(player);local login=D.LoginStatus(daily.Login,day);local rows={}
  for i,q in ipairs(quests.Keys)do local spec=D.Quests[q]
   rows[i]={Key=spec.Key,Text=spec.Text,Icon=spec.Icon,Goal=spec.Goal,Progress=quests.Progress[i],Claimed=quests.Claimed[i],Packs=D.QuestPacks}
  end
  local claimed=0;for i=1,#quests.Keys do if quests.Claimed[i]then claimed+=1 end end
  -- Done / Total: quests claimed so far. Blocked: Gems from older-style claims already used today's 2 (no bonus left to give).
  local bonus={Gems=D.AllDoneGems,Done=claimed,Total=#quests.Keys,Claimed=quests.Bonus,Ready=D.BonusReady(quests),Blocked=D.BonusBlocked(quests)}
  return {Success=true,Login=login,Quests=rows,Bonus=bonus,ResetIn=D.SecondsLeft(os.time()),Day=day,QuestGemsGranted=quests.GemsGranted,QuestGemCap=D.QuestGemCap}
 end
 function Data:ClaimDailyLogin(player)
  if not self:IsLoaded(player)then return false,'HOLD ON, UR DATA IS LOADING!'end
  if not self.CanSave[player]then return false,'NO REWARDS UNTIL UR DATA CAN SAVE'end
  local daily,_,day=self:DailyData(player);local login=D.LoginStatus(daily.Login,day)
  if not login.Ready then return false,'COME BACK TOMORROW FOR DAY '..(login.Claimed%#D.Login+1)end
  local reward=D.Login[login.Next];local message
  if reward.SeedPack or reward.MechPack or reward.VoidPack then
   local record,why=self:GrantDailyPack(player,reward.VoidPack and'Void'or reward.MechPack and'Mech'or nil)
   if not record then return false,why end
   message=reward.VoidPack and '🌑 FREE VOID PACK! Check ur bag!'or reward.MechPack and '🤖 FREE MECH PACK! Check ur bag!'or '🎒 RANDOM SEED PACK! Check ur bag!'
  else
   local okay,why=self:QueueDailyGems(player,reward.Gems);if not okay then return false,why end
   message='Ur Gems are on the way!'
  end
  daily.Login={Step=login.Next,Day=day}
  self:MarkDirty(player);self:QueueGardenSave(player);self:PublishDaily(player)
  return true,message,{Day=login.Next,Reward=reward}
 end
 function Data:ClaimDailyQuest(player,index)
  if not self:IsLoaded(player)then return false,'HOLD ON, UR DATA IS LOADING!'end
  if not self.CanSave[player]then return false,'NO REWARDS UNTIL UR DATA CAN SAVE'end
  local daily,quests=self:DailyData(player)
  if type(index)~='number'or index%1~=0 or not quests.Keys[index]then return false,'TRY AGAIN!'end
  if quests.Claimed[index]then return false,'U ALREADY CLAIMED THIS!'end
  if quests.Progress[index]<D.Quests[quests.Keys[index]].Goal then return false,'FINISH THE QUEST FIRST'end
  -- R153: the reward is one random pack. A full Bag refuses it (nothing is lost, the quest stays claimable); the pack in the Bag is the commit point.
  local record,why=self:GrantDailyPack(player,false);if not record then return false,why end
  daily.Quests.Claimed[index]=true
  self:MarkDirty(player);self:QueueGardenSave(player);self:PublishDaily(player)
  if D.BonusReady(select(2,self:DailyData(player)))then return true,'🎒 RANDOM SEED PACK! Now grab ur 💎'..D.AllDoneGems..' bonus!'end
  return true,'🎒 RANDOM SEED PACK! Check ur bag!'
 end
 -- R153: claiming every quest of the day gives 2 Gems once. Its own marker (Bonus) is set only after the Gems are queued, so a refusal (the receipts are full, the Gems are maxed out)
 -- leaves it claimable. Today's quest Gems never go over D.QuestGemCap: a day with older-style claims (they paid Gems already) has no bonus left.
 function Data:ClaimDailyBonus(player)
  if not self:IsLoaded(player)then return false,'HOLD ON, UR DATA IS LOADING!'end
  if not self.CanSave[player]then return false,'NO REWARDS UNTIL UR DATA CAN SAVE'end
  local daily,quests=self:DailyData(player)
  if quests.Bonus then return false,'U ALREADY CLAIMED THIS!'end
  if not D.AllClaimed(quests)then return false,'CLAIM ALL THE QUESTS FIRST!'end
  if D.BonusBlocked(quests)then return false,'U ALREADY GOT UR DAILY 💎!'end
  local okay,why=self:QueueDailyGems(player,D.AllDoneGems);if not okay then return false,why end
  daily.Quests.Bonus=true
  daily.Quests.GemsGranted=quests.GemsGranted+D.AllDoneGems
  self:MarkDirty(player);self:QueueGardenSave(player);self:PublishDaily(player)
  return true,'🎉 ALL DONE! Ur Gems are on the way!'
 end
 -- Called where the action really happens (ChestService.Bank, OpenSeedPack, PlantSeed, HarvestPlant, selling).
 function Data:QuestEvent(player,key,count)
  if not self:IsLoaded(player)then return false end
  count=math.floor(tonumber(count)or 1);if count<1 then return false end
  if key=='Plant'then player:SetAttribute('SeedsPlanted',(player:GetAttribute('SeedsPlanted')or 0)+count)end -- (the notification opt-in waits for this)
  local daily,quests=self:DailyData(player);local finished,changed
  for i,q in ipairs(quests.Keys)do local spec=D.Quests[q]
   if spec.Key==key and quests.Progress[i]<spec.Goal then
    daily.Quests.Progress[i]=math.min(spec.Goal,quests.Progress[i]+count);changed=true
    if daily.Quests.Progress[i]>=spec.Goal then finished=spec end
   end
  end
  if not changed then return false end
  self:MarkDirty(player);self:PublishDaily(player)
  if finished and self.Notifications then
   pcall(function()self.Notifications:Show(player,'✅ QUEST DONE: '..finished.Text..'! Grab ur 🎒 pack in 🎁 DAILY',Color3.fromRGB(120,255,150),5)end)
  end
  return true
 end
end
return T
