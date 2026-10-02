-- R123: treadmill bonus rolls (final owner spec; rules, odds and biome mapping: ReplicatedStorage.TreadmillBonusRules).
-- Server-authoritative: only time inside BaseService.TrainingSessions (the server's own treadmill lock, which already
-- requires standing on your own belt with ground under you) counts. The client never reports time or results.
--  * Progress (seconds toward the next roll) is saved in the profile: Premium.TreadmillBonusProgress.
--  * READY rolls live in this server session only (max 2). At 2 the timer pauses; leaving the game drops them.
--  * TreadmillBonusRoll (RemoteFunction, no arguments): rate-limited (SecurityGate + 1 s), checks a READY roll and bag
--    room, rolls the pack, grants it with PlayerData:AddChest + ChestService:SyncTools (ChestService:Bank's path) and spends the roll in one non-yielding step, then
--    returns the result for the client to animate. A full bag refuses and keeps the roll READY.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Rules=require(RS:WaitForChild('TreadmillBonusRules'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
local S={};S.__index=S
function S.new(config,data,base,chests,notes)
 local self=setmetatable({Config=config,Data=data,Base=base,Chests=chests,Notes=notes,State={},Ready={},LastRoll={},Random=Random.new()},S)
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
function S:GetReady(player)return Rules.ReadyCount(self.Ready[player])end
function S:GetProgress(player)return Rules.Progress(self.Data:GetPremium(player).TreadmillBonusProgress)end
function S:_setProgress(player,seconds)self.Data:GetPremium(player).TreadmillBonusProgress=Rules.Progress(seconds)end
function S:_state(player)
 local st=self.State[player];if not st then st={Training=false,Unsaved=0};self.State[player]=st end;return st
end
function S:PoolStages(player)
 return Rules.PoolStages(self.Config.TreadmillTiers,self.Data:GetTreadmillData(player).Tier)
end
-- Attributes change only on start/stop/ready/claim/upgrade, never per frame; the client counts down from DueAt.
function S:_publish(player)
 local st=self:_state(player);local ready=self:GetReady(player);local left=Rules.IntervalSeconds-self:GetProgress(player)
 player:SetAttribute(Rules.Attr.Interval,Rules.IntervalSeconds)
 player:SetAttribute(Rules.Attr.Ready,ready)
 player:SetAttribute(Rules.Attr.Left,math.ceil(left))
 player:SetAttribute(Rules.Attr.DueAt,(st.Training and ready<Rules.MaxReady)and workspace:GetServerTimeNow()+left or nil)
 local pool=Rules.EncodePool(self:PoolStages(player));st.Tier=self.Data:GetTreadmillData(player).Tier
 player:SetAttribute(Rules.Attr.Pool,pool)
end
-- Called once the profile is loaded (publishes the saved progress and the pool).
function S:Setup(player)
 if not self.Data:IsLoaded(player)then return end
 self:_state(player);self:_publish(player)
end
function S:Cleanup(player)
 self.State[player]=nil;self.Ready[player]=nil;self.LastRoll[player]=nil
end
-- Public API (owner/test commands). All clamp to the normal rules and republish the attributes.
-- :GrantReady(player,n) adds n READY rolls (cap 2, session only); :SetProgress(player,seconds) sets saved progress
-- (0..Rules.IntervalSeconds); :Pool(player) -> {stage,...} for the best owned treadmill; :GetReady / :GetProgress read state.
function S:GrantReady(player,n)
 if not self.Data:IsLoaded(player)then return false end
 self.Ready[player]=Rules.ReadyCount(self:GetReady(player)+(tonumber(n)or 1));self:_publish(player);return true,self:GetReady(player)
end
function S:SetProgress(player,seconds)
 if not self.Data:IsLoaded(player)then return false end
 self:_setProgress(player,tonumber(seconds)or 0);self.Data:MarkDirty(player);self:_publish(player);return true,self:GetProgress(player)
end
function S:Pool(player)return self:PoolStages(player)end
function S:Step(dt)
 dt=math.max(0,tonumber(dt)or 0)
 for _,player in ipairs(Players:GetPlayers())do self:StepPlayer(player,dt)end
end
function S:StepPlayer(player,dt)
 if not self.Data:IsLoaded(player)then return end
 local st=self:_state(player)
 local training=self.Base.TrainingSessions[player]~=nil
 local changed=training~=st.Training
 st.Training=training
 if training and self:GetReady(player)<Rules.MaxReady then
  local progress=self:GetProgress(player)+dt
  if progress>=Rules.IntervalSeconds then
   progress=0 -- one roll per interval, even after a long server hitch
   self.Ready[player]=self:GetReady(player)+1;changed=true
   if self.Notes then self.Notes:Show(player,'🎁 Treadmill bonus roll ready!',Color3.fromRGB(255,215,90),3)end
  end
  self:_setProgress(player,progress);st.Unsaved+=dt
  if st.Unsaved>=Rules.SaveEvery or changed then st.Unsaved=0;self.Data:MarkDirty(player)end
 elseif changed and st.Unsaved>0 then
  st.Unsaved=0;self.Data:MarkDirty(player)
 end
 if not changed and st.Tier~=self.Data:GetTreadmillData(player).Tier then changed=true end -- treadmill upgraded
 if changed then self:_publish(player)end
end
function S:Roll(player)
 if not self.Data:IsLoaded(player)then return {Error='YOUR DATA IS STILL LOADING'}end
 local now=os.clock()
 if now-(self.LastRoll[player]or -math.huge)<Rules.RollCooldown then return {Error='Please wait a moment.'}end
 self.LastRoll[player]=now
 local ready=self:GetReady(player)
 if ready<1 then return {Error='No bonus roll ready yet.',Ready=0}end
 local room,why=self.Data:CanReceiveSeed(player)
 if not room then return {Error=why=='YOUR DATA IS STILL LOADING'and why or'SEED BAG FULL! Make room - your roll stays ready.',Ready=ready}end
 local stages=self:PoolStages(player)
 local pick=Rules.RollPack(stages,function()return self.Random:NextNumber()end)
 if not pick then return {Error='Bonus packs are unavailable right now.',Ready=ready}end
 -- The existing grant path (what ChestService:Bank does for a stolen pack): AddChest never yields, so the roll,
 -- the grant and spending the roll happen in one step; the Tool is synced afterwards.
 local size=PackRules.RollPackSize(self.Random:NextNumber()) -- R126: rolls a pack size like world packs
 local record,reason=self.Data:AddChest(player,{Stage=pick.Stage,BagVariant=pick.Variant,PackSize=size,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion})
 if not record then return {Error=reason or'PACK COULD NOT BE ADDED',Ready=ready}end
 self.Ready[player]=ready-1
 if self.Data.QueueGardenSave then self.Data:QueueGardenSave(player)end
 self:_publish(player)
 if self.Chests then
  local ok,err=pcall(function()self.Chests:SyncTools(player)end)
  if not ok then warn('[R123] Bonus pack Tool appears on the next sync: '..tostring(err))end
 end
 local rarity=Rules.Tier(pick.Variant)
 return {Ok=true,Stage=pick.Stage,Variant=pick.Variant,Rarity=rarity,Biome=pick.Variant==Rules.Void.Variant and Rules.Void.Label or PackRules.DesignBiomes[pick.Stage],
  Label=PackRules.PackLabel(pick.Stage,pick.Variant,size,'None'),Size=record.PackSize,Id=record.Id,Pool=Rules.EncodePool(stages),Ready=ready-1}
end
return S
