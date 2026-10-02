-- R123: treadmill bonus rolls. Server-authoritative: training time comes from BaseService.TrainingSessions (the
-- server's own treadmill lock), never from the client. Rules, odds table and timings: ReplicatedStorage.TreadmillBonusRules.
--  * Every 10 min of training -> one READY roll (saved in the profile's Premium table as TreadmillBonusReady, max 5).
--  * Off the treadmill: progress pauses; back within 60 s keeps it, longer (or leaving the game) resets it.
--    Progress is session-only; READY rolls survive rejoin. At 5 READY rolls the timer stops until one is used.
--  * TreadmillBonusRoll (RemoteFunction): validates a READY roll and bag room, rolls the rarity (luck-free),
--    adds the pack to the bag and spends the roll in one non-yielding step, then returns the result to animate.
--    A full bag refuses the roll and keeps it READY.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Rules=require(RS:WaitForChild('TreadmillBonusRules'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
local S={};S.__index=S
function S.new(config,data,base,chests,notes)
 local self=setmetatable({Config=config,Data=data,Base=base,Chests=chests,Notes=notes,State={},LastRoll={},Clock=0,Random=Random.new()},S)
 local folder=RS:FindFirstChild('ChestChaseRemotes')
 if not folder then folder=Instance.new('Folder');folder.Name='ChestChaseRemotes';folder.Parent=RS end
 local remote=folder:FindFirstChild(Rules.RemoteName)
 if remote and not remote:IsA('RemoteFunction')then remote:Destroy();remote=nil end
 if not remote then remote=Instance.new('RemoteFunction');remote.Name=Rules.RemoteName;remote.Parent=folder end
 remote.OnServerInvoke=function(player,...)
  if select('#',...)>0 or not require(script.Parent.SecurityGate).Allow(player,'TreadmillBonusRoll')then return {Error='Please try again.'}end
  return self:Roll(player)
 end
 self.Remote=remote
 return self
end
function S:Start()
 if self.Connection then return end
 self.Connection=Run.Heartbeat:Connect(function(dt)self:Step(dt)end)
end
function S:GetReady(player)
 return Rules.ReadyCount(self.Data:GetPremium(player).TreadmillBonusReady)
end
function S:_setReady(player,n)
 self.Data:GetPremium(player).TreadmillBonusReady=Rules.ReadyCount(n)
 self.Data:MarkDirty(player)
 player:SetAttribute(Rules.Attr.Ready,Rules.ReadyCount(n))
end
function S:_state(player)
 local st=self.State[player];if not st then st={Progress=0,Training=false,Off=nil};self.State[player]=st end;return st
end
-- Attributes only change on start/stop/ready/reset, never per frame; the client counts down from DueAt.
function S:_publish(player)
 local st=self:_state(player);local ready=self:GetReady(player);local left=Rules.IntervalSeconds-st.Progress
 player:SetAttribute(Rules.Attr.Interval,Rules.IntervalSeconds)
 player:SetAttribute(Rules.Attr.Ready,ready)
 local running=st.Training and ready<Rules.MaxReady
 player:SetAttribute(Rules.Attr.DueAt,running and workspace:GetServerTimeNow()+left or nil)
 player:SetAttribute(Rules.Attr.Paused,(not st.Training and st.Progress>0)and math.ceil(left)or nil)
end
-- Called once the profile is loaded (publishes the saved READY count).
function S:Setup(player)
 if not self.Data:IsLoaded(player)then return end
 self:_state(player);self:_publish(player)
end
function S:Cleanup(player)
 self.State[player]=nil;self.LastRoll[player]=nil
end
function S:BonusStage(player)
 local tiers=self.Config.TreadmillTiers;local tier=tiers[self.Data:GetTreadmillData(player).Tier]or tiers[1]
 return tier.Stage,tier.Biome
end
function S:Step(dt)
 dt=math.max(0,tonumber(dt)or 0);self.Clock+=dt
 for _,player in ipairs(Players:GetPlayers())do self:StepPlayer(player,dt)end
end
function S:StepPlayer(player,dt)
 if not self.Data:IsLoaded(player)then return end
 local st=self:_state(player)
 local training=self.Base.TrainingSessions[player]~=nil
 if training then
  local changed=not st.Training
  st.Training=true;st.Off=nil
  local ready=self:GetReady(player)
  if ready<Rules.MaxReady then
   st.Progress+=dt
   if st.Progress>=Rules.IntervalSeconds then
    st.Progress-=Rules.IntervalSeconds
    if st.Progress>=Rules.IntervalSeconds then st.Progress=0 end -- one roll per interval, even after a long hitch
    self:_setReady(player,ready+1);changed=true
    if self.Notes then self.Notes:Show(player,'🎁 Treadmill bonus ready! Tap BONUS ROLL',Color3.fromRGB(255,215,90),3)end
   end
  end
  if changed then self:_publish(player)end
 else
  if st.Training then st.Training=false;st.Off=self.Clock;self:_publish(player)end
  if st.Off and self.Clock-st.Off>Rules.GraceSeconds then
   st.Off=nil
   if st.Progress>0 then st.Progress=0;self:_publish(player)end
  end
 end
end
function S:Roll(player)
 if not self.Data:IsLoaded(player)then return {Error='YOUR DATA IS STILL LOADING'}end
 local now=os.clock()
 if now-(self.LastRoll[player]or -math.huge)<Rules.RollCooldown then return {Error='Please wait a moment.'}end
 self.LastRoll[player]=now
 local ready=self:GetReady(player)
 if ready<1 then return {Error='No bonus roll ready yet.',Ready=0}end
 local room,why=self.Data:CanReceiveSeed(player)
 if not room then return {Error=why=='YOUR DATA IS STILL LOADING'and why or'SEED BAG FULL! Make room - your bonus roll is saved.',Ready=ready}end
 local stage,biome=self:BonusStage(player)
 local odds=Rules.PoolOdds(PackRules.ObtainablePool(self.Config,stage)or{},PackRules.GetRarity)
 if not odds then return {Error='Bonus packs are unavailable right now.',Ready=ready}end
 local tier=Rules.RollTier(odds,function()return self.Random:NextNumber()end)
 -- AddChest never yields: roll, grant and spend happen in one step (no duplicate or lost roll).
 local record,reason=self.Data:AddChest(player,{Stage=stage,BagVariant=Rules.Variants[tier],PackSize=1,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion})
 if not record then return {Error=reason or'PACK COULD NOT BE ADDED',Ready=ready}end
 record.BonusRarity=tier;record.ChestName='Treadmill Bonus Pack'
 self:_setReady(player,ready-1);self:_publish(player)
 if self.Data.QueueGardenSave then self.Data:QueueGardenSave(player)end
 if self.Chests then
  local ok,err=pcall(function()self.Chests:SyncTools(player)end)
  if not ok then warn('[R123] Bonus pack tool will appear on the next sync: '..tostring(err))end
 end
 local name=(self.Config.BiomeNames[stage]or biome or'Biome')
 return {Ok=true,Rarity=tier,Stage=stage,Biome=biome,BiomeName=name,Variant=Rules.Variants[tier],Id=record.Id,Odds=odds,Ready=ready-1}
end
return S
