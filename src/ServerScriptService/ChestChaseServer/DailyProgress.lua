-- R140 (owner): weekly login rewards (day 7 = a Mech pack) and daily quests (Gems each: DailyRewards.QuestGems), saved in the premium
-- profile as Daily={Login={Step,Day},Quests={Day,Progress,Claimed}}. Every change here is a non-yielding profile
-- transaction, so a claim can never pay twice. The numbers live in ReplicatedStorage.DailyRewards.
local RS=game:GetService('ReplicatedStorage')
local D=require(RS.DailyRewards)
local T={}
function T.Attach(Data)
 local function today()return D.Day(os.time())end
 function Data:DailyData(player)
  local premium=self:GetPremium(player)
  if type(premium.Daily)~='table'then premium.Daily={}end
  local daily=premium.Daily;local day=today()
  daily.Login=D.ReadLogin(daily.Login)
  local quests=D.ReadQuests(daily.Quests,day,player.UserId)
  daily.Quests={Day=quests.Day,Progress=quests.Progress,Claimed=quests.Claimed}
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
  if not self:IsLoaded(player)then return {Success=false,Message='YOUR DATA IS LOADING'}end
  local daily,quests,day=self:DailyData(player);local login=D.LoginStatus(daily.Login,day);local rows={}
  for i,q in ipairs(quests.Keys)do local spec=D.Quests[q]
   rows[i]={Key=spec.Key,Text=spec.Text,Icon=spec.Icon,Goal=spec.Goal,Progress=quests.Progress[i],Claimed=quests.Claimed[i],Gems=D.QuestGems}
  end
  return {Success=true,Login=login,Quests=rows,ResetIn=D.SecondsLeft(os.time()),Day=day}
 end
 function Data:ClaimDailyLogin(player)
  if not self:IsLoaded(player)then return false,'YOUR DATA IS LOADING'end
  local daily,_,day=self:DailyData(player);local login=D.LoginStatus(daily.Login,day)
  if not login.Ready then return false,'COME BACK TOMORROW FOR DAY '..(login.Claimed%#D.Login+1)end
  local reward=D.Login[login.Next];local message
  if reward.MechPack then
   local records,why=self:GrantMechPacks(player,false,reward.MechPack)
   if not records then return false,why end
   message='🤖 FREE MECH PACK! Check your Bag!'
  elseif reward.Pack then
   -- R141: a random seed pack, rolled like a treadmill bonus roll (an earned pack: it goes through the size luck).
   local Bonus=require(RS.TreadmillBonusRules);local PackRules=require(RS.SeedPackRules)
   self.DailyRandom=self.DailyRandom or Random.new()
   local pick=Bonus.RollPack(Bonus.PoolStages(self.Config.TreadmillTiers,self:GetTreadmillData(player).Tier),function()return self.DailyRandom:NextNumber()end)
   if not pick then return false,'TRY AGAIN'end
   local record,why=self:AddChest(player,{Stage=pick.Stage,BagVariant=pick.Variant,PackSize=1,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion},{Luck=true})
   if not record then return false,why end
   local tier=PackRules.GetPackTier(pick.Variant)
   message='🎒 '..tier.Name..' '..PackRules.PackLabel(pick.Stage,pick.Variant,record.PackSize,'None')..'! Check your Bag!'
  else
   local okay,why=self:QueueCurrency(player,reward.Gems,'Gems');if not okay then return false,why end
   message='Collect your Gems.'
  end
  daily.Login={Step=login.Next,Day=day}
  self:MarkDirty(player);self:QueueGardenSave(player);self:PublishDaily(player)
  return true,message,{Day=login.Next,Reward=reward}
 end
 function Data:ClaimDailyQuest(player,index)
  if not self:IsLoaded(player)then return false,'YOUR DATA IS LOADING'end
  local daily,quests=self:DailyData(player)
  if type(index)~='number'or index%1~=0 or not quests.Keys[index]then return false,'INVALID QUEST'end
  if quests.Claimed[index]then return false,'ALREADY CLAIMED'end
  if quests.Progress[index]<D.Quests[quests.Keys[index]].Goal then return false,'FINISH THE QUEST FIRST'end
  local okay,why=self:QueueCurrency(player,D.QuestGems,'Gems');if not okay then return false,why end
  daily.Quests.Claimed[index]=true
  self:MarkDirty(player);self:QueueGardenSave(player);self:PublishDaily(player)
  return true,'Collect your Gems.'
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
   pcall(function()self.Notifications:Show(player,'✅ QUEST DONE: '..finished.Text..'! Claim 💎'..D.QuestGems..' in 🎁 DAILY',Color3.fromRGB(120,255,150),5)end)
  end
  return true
 end
end
return T
