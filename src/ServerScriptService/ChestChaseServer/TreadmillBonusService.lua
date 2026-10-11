-- R123: treadmill bonus rolls (final owner spec; rules, odds and biome mapping: ReplicatedStorage.TreadmillBonusRules).
-- Server-authoritative: only time inside BaseService.TrainingSessions (the server's own treadmill lock, which already
-- requires standing on your own belt with ground under you) counts. The client never reports time or results.
--  * Progress (seconds toward the next roll) is saved in the profile: Premium.TreadmillBonusProgress.
--  * READY rolls live in this server session only (max 2). At 2 the timer pauses; leaving the game drops them.
--  * TreadmillBonusRoll (RemoteFunction, no arguments): rate-limited (SecurityGate + 1 s), checks a READY roll and bag
--    room, rolls the pack, grants it with PlayerData:AddChest + ChestService:SyncTools (ChestService:Bank's path) and spends the roll in one non-yielding step, then
--    returns the result for the client to animate. A full bag refuses and keeps the roll READY.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Rules=require(RS:WaitForChild('TreadmillBonusRules'));local PackRules=require(RS:WaitForChild('SeedPackRules'));local Starter=require(RS:WaitForChild('StarterVerityRules158d')) -- R158d: the new-player gift's 2 rolls
local S={};S.__index=S
-- R158i: the free roll of the tutorial (GrantGift) that did not fit because the player already held the most READY rolls waits here (session) and in Premium.BonusGiftPending158i (saved,
-- optional field: ProfileVersion stays 22) until a roll is spent: it then becomes ready at once. TreadmillBonusRolled counts the rolls this player spent this session (the tutorial's arrow
-- waits for it to grow: with a waiting roll the ready count does not drop when one is used).
local PENDING_FIELD='BonusGiftPending158i';local ROLLED_ATTR='TreadmillBonusRolled'
function S.new(config,data,base,chests,notes)
 local self=setmetatable({Config=config,Data=data,Base=base,Chests=chests,Notes=notes,State={},Ready={},Pending={},LastRoll={},Random=Random.new()},S)
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
function S:_creative(player)local ok,state=pcall(require,script.Parent.OwnerTestState82);return ok and type(state)=='table'and type(state.Creative)=='function'and state.Creative(player)==true end -- R158f: the owner's creative mode has no roll wait
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
 -- R158d: the new-player gift's bonus rolls that were not used yet (Premium.StarterRolls158d, 0 - 2) are ready again after a rejoin (ready rolls themselves live in the session only).
 local okOwed,owed=pcall(function()return Starter.CleanRolls(self.Data:GetPremium(player)[Starter.RollsField])end)
 if okOwed and owed>0 and self:GetReady(player)<owed then self.Ready[player]=Rules.ReadyCount(owed)end
 do local okWait,waiting=pcall(function()return self.Data:GetPremium(player)[PENDING_FIELD]==true end) -- R158i: a gift roll that was still waiting for room
  if okWait and waiting then self.Pending[player]=true;self:_promote(player)end
 end
 self:_state(player);self:_publish(player)
end
function S:Cleanup(player)
 self.State[player]=nil;self.Ready[player]=nil;self.Pending[player]=nil;self.LastRoll[player]=nil
end
-- R158i: a gift roll counts as a starter roll once it is READY (Premium.StarterRolls158d, 0 - 2), so a rejoin before it is used brings it back (ready rolls themselves live in the session only).
function S:_keepOwed(player)
 local premium=self.Data:GetPremium(player)
 premium[Starter.RollsField]=math.min(Starter.Rolls,Starter.CleanRolls(premium[Starter.RollsField])+1)
end
-- R158i: the waiting gift roll becomes ready the moment there is room (never yields; the caller publishes). Returns true when it did.
function S:_promote(player)
 if not self.Pending[player]or self:GetReady(player)>=Rules.MaxReady then return false end
 self.Pending[player]=nil;self.Data:GetPremium(player)[PENDING_FIELD]=nil
 self.Ready[player]=self:GetReady(player)+1;self:_keepOwed(player);self.Data:MarkDirty(player)
 return true
end
-- R158i (owner: the tutorial's free bonus roll "still" did not reach players): ONE gift roll, given by the SERVER (TutorialProgress, when the tutorial reaches its last step; nothing a client
-- sends). Room for it: a READY roll at once. Already holding the most ready rolls (new players hold the 2 of the starter gift): it waits (Pending, saved) and is ready as soon as one roll is
-- spent, so the player always gets one roll more than they could hold. Returns true and 'ready' / 'pending'; false when the profile is not loaded.
function S:GrantGift(player)
 if not self.Data:IsLoaded(player)then return false end
 if self:GetReady(player)<Rules.MaxReady then
  self.Ready[player]=self:GetReady(player)+1;self:_keepOwed(player);self.Data:MarkDirty(player);self:_publish(player)
  return true,'ready'
 end
 self.Pending[player]=true;self.Data:GetPremium(player)[PENDING_FIELD]=true;self.Data:MarkDirty(player);self:_publish(player)
 return true,'pending'
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
 if now-(self.LastRoll[player]or -math.huge)<Rules.RollCooldown and not self:_creative(player)then return {Error='Please wait a moment.'}end -- (R158f: no wait in the owner's creative mode)
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
 local record,reason=self.Data:AddChest(player,{Stage=pick.Stage,BagVariant=pick.Variant,PackSize=size,PackMutation='None',Weather='None',OddsVersion=PackRules.OddsVersion},{Luck=true}) -- R137: hidden size pity
 if not record then return {Error=reason or'PACK COULD NOT BE ADDED',Ready=ready}end
 pcall(function()require(script.Parent.OwnerTestPacks).Claim(player,'Bonus',record)end) -- R151: a roll that an owner "bonus" command made ready is a TEST pack (never announced)
 self.Ready[player]=ready-1
 player:SetAttribute(ROLLED_ATTR,(tonumber(player:GetAttribute(ROLLED_ATTR))or 0)+1) -- R158i: a roll was spent (the tutorial's arrow)
 do -- R158d: a roll spent takes a starter roll first (the saved count goes down with it: it never comes back after a rejoin)
  local premium=self.Data:GetPremium(player);local owed=Starter.CleanRolls(premium[Starter.RollsField])
  if owed>0 then premium[Starter.RollsField]=owed-1>0 and owed-1 or nil;self.Data:MarkDirty(player)end
 end
 self:_promote(player) -- R158i: a gift roll that was waiting for room is ready now (the ready count may stay the same)
 if self.Data.QueueGardenSave then self.Data:QueueGardenSave(player)end
 self:_publish(player)
 if self.Chests then
  local ok,err=pcall(function()self.Chests:SyncTools(player)end)
  if not ok then warn('[R123] Bonus pack Tool appears on the next sync: '..tostring(err))end
 end
 local rarity=Rules.Tier(pick.Variant)
 return {Ok=true,Stage=pick.Stage,Variant=pick.Variant,Rarity=rarity,Biome=pick.Variant==Rules.Void.Variant and Rules.Void.Label or PackRules.DesignBiomes[pick.Stage],
  Label=PackRules.PackLabel(pick.Stage,pick.Variant,record.PackSize,'None'),Size=record.PackSize,Id=record.Id,Pool=Rules.EncodePool(stages),Ready=self:GetReady(player)}
end
return S
