-- R141: daily claims stay in the existing Premium.Daily profile. Grants and
-- claim markers commit without yielding, using existing inventory/currency APIs.
-- R140 claimed quests retain their flags and count as 5 gems for today's cap.
local RS=game:GetService('ReplicatedStorage')
local D=require(RS.DailyRewards)
local PackRules=require(RS.SeedPackRules)
local PackRandom=Random.new() -- server only; no client reward/roll input
local T={}
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
 function Data:GrantDailyPack(player,mech)
  local records=self:GetChestRecords(player);local before=#records
  if before>=self.Config.MaxSavedChests then return nil,'MAKE ROOM FOR 1 PACK FIRST!'end
  local pack
  if not mech then
   local stage=D.SeedPackStages[PackRandom:NextInteger(1,#D.SeedPackStages)]
   local variant=PackRules.RollVariant(PackRandom:NextNumber())
   if not D.SeedPackVariants[variant]or type(self.Config.SeedCatalogByStage)~='table'or not self.Config.SeedCatalogByStage[stage]then return nil,'DAILY PACKS AREN\'T READY YET'end
   pack={Stage=stage,BagVariant=variant,PackSize=PackRules.RollPackSize(PackRandom:NextNumber()),PackMutation='None',OddsVersion=PackRules.OddsVersion} -- R147: current odds (without it AddChest stored the legacy 81 table)
  end
  local okay,result,why=pcall(function()
   if mech then return self:GrantMechPacks(player,false,1)end
   return self:AddChest(player,pack) -- no paid flag, no added luck/pity roll
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
  daily.Quests={Day=quests.Day,Progress=quests.Progress,Claimed=quests.Claimed,RewardVersion=quests.RewardVersion,GemsGranted=quests.GemsGranted}
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
   rows[i]={Key=spec.Key,Text=spec.Text,Icon=spec.Icon,Goal=spec.Goal,Progress=quests.Progress[i],Claimed=quests.Claimed[i],Gems=D.QuestGems,Blocked=not quests.Claimed[i]and D.QuestBlocked(quests)}
  end
  return {Success=true,Login=login,Quests=rows,ResetIn=D.SecondsLeft(os.time()),Day=day,QuestGemsGranted=quests.GemsGranted,QuestGemCap=D.QuestGemCap}
 end
 function Data:ClaimDailyLogin(player)
  if not self:IsLoaded(player)then return false,'HOLD ON, UR DATA IS LOADING!'end
  if not self.CanSave[player]then return false,'NO REWARDS UNTIL UR DATA CAN SAVE'end
  local daily,_,day=self:DailyData(player);local login=D.LoginStatus(daily.Login,day)
  if not login.Ready then return false,'COME BACK TOMORROW FOR DAY '..(login.Claimed%#D.Login+1)end
  local reward=D.Login[login.Next];local message
  if reward.SeedPack or reward.MechPack then
   local record,why=self:GrantDailyPack(player,reward.MechPack~=nil)
   if not record then return false,why end
   message=reward.MechPack and '🤖 FREE MECH PACK! Check ur bag!'or '🎒 RANDOM SEED PACK! Check ur bag!'
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
  if D.QuestBlocked(quests)then return false,'DAILY QUEST GEM LIMIT HIT! COME BACK AFTER THE UTC RESET'end
  local okay,why=self:QueueDailyGems(player,D.QuestGems);if not okay then return false,why end
  daily.Quests.Claimed[index]=true
  daily.Quests.GemsGranted=quests.GemsGranted+D.QuestGems
  self:MarkDirty(player);self:QueueGardenSave(player);self:PublishDaily(player)
  return true,'Ur Gems are on the way!'
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
   pcall(function()self.Notifications:Show(player,'✅ QUEST DONE: '..finished.Text..'! Grab ur 💎'..D.QuestGems..' in 🎁 DAILY',Color3.fromRGB(120,255,150),5)end)
  end
  return true
 end
end
return T
