-- R158d (owner: "new players receive a [Verity] pack on spawn, every new player, and it's notified to them; the pack is guaranteed mythic or above"; "2 bonus rolls at the start"; "this will only last
-- till the Verity event ends"; notice: "Thanks for playing! Here's a gift"): the server half of the new-player gift. Rules, words and the floored roll: StarterVerityRules158d.
--  * WHO: a brand-new profile only (PlayerDataService:Load saw nothing saved before the join: data.FreshProfile[player]), and only while the Verity event runs (LimitedEvent.Active on the SERVER clock,
--    the same check VerityService:Give uses). An existing player is never owed it. After the event ended a new player gets nothing: no pack, no rolls, no notice, and the flag is NOT written.
--  * SAVED STATE (Premium.StarterVerity158d, an optional field: no ProfileVersion change; an older server keeps it as it is): the moment a brand-new profile loads while the event runs it is set to 'Owed'
--    (saved with the profile), so a gift whose grant was interrupted (a crash, a full Bag, a lost save) is still owed on the next join; the grant sets 'Given'.
--    Rule for an owed gift after the event ended: NOTHING is given ("only while the event is active"); 'Owed' just stays in the profile.
--  * WHEN: the grant waits for the finished tutorial (the player attribute TutorialDone, true after finishing OR skipping), the same moment the tutorial's own free Forest pack comes. Why: AddChest
--    tells the tutorial "a pack was added", which would tick off its "grab a pack" step, and its "open it" step would point at the wrong pack. After the tutorial nothing of that is left, and the
--    title screen and the tutorial card are gone, so the notice can be read. The grant is retried every 5 s (6 times) while a Bag is full or data cannot save, and on the next join.
--  * THE GRANT (Grant, never yields, one step like VoidGiveaway152:_grant): the flag is 'Owed', the event runs, the tutorial is done, the profile is loaded and can save (Studio may not), room in the Bag
--    (the 200 cap) -> AddChest (a REAL Verity pack, not TestGrant: it announces when opened; GiftLocked; Floor = 'Mythic') -> flag 'Given' + Premium.StarterRolls158d = 2 -> 2 READY treadmill bonus rolls
--    (TreadmillBonusService:GrantReady) -> MarkDirty + QueueGardenSave -> SyncTools -> ONE notice, a moment later. A profile gets at most one pack however many paths run: the flag check and the pack are one step.
--  * The 2 rolls are ordinary bonus rolls (normal odds). Ready rolls live in the session only; the unused ones are kept in Premium.StarterRolls158d and come back after a rejoin (TreadmillBonusService).
--  * Owner tool: /test starterverity @name (status), /test starterverity @name reset (Studio only: the profile is owed the gift again; the pack and rolls you already got stay).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('StarterVerityRules158d'));local Limited=require(RS:WaitForChild('LimitedEvent'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
local S={Version='158d'};S.__index=S
local GOLD=Color3.fromRGB(255,214,90)
-- config, data (PlayerDataService), chests (ChestService), notes (NotificationService), treadmill (TreadmillBonusService). opts (all optional; the tests pass fakes): Time (Unix seconds), Studio, Delay, NoWatch.
function S.new(config,data,chests,notes,treadmill,opts)
 opts=opts or{}
 local studio=opts.Studio;if studio==nil then local ok,v=pcall(function()return game:GetService('RunService'):IsStudio()end);studio=ok and v==true end
 local self=setmetatable({Config=config,Data=data,Chests=chests,Notes=notes,Treadmill=treadmill,Opts=opts,Time=opts.Time or os.time,Studio=studio==true,
  Delay=opts.Delay or function(seconds,fn)task.delay(seconds,fn)end,Told=setmetatable({},{__mode='k'}),Watching=setmetatable({},{__mode='k'}),Dead=false},S)
 S.Current=self
 return self
end
function S:_active()return Limited.Active(self.Time())end
function S:_premium(player)local ok,p=pcall(self.Data.GetPremium,self.Data,player);return ok and type(p)=='table'and p or nil end
function S:_fresh(player)local f=self.Data.FreshProfile;return f~=nil and f[player]==true end
function S:State(player)local p=self:_premium(player);return p and Rules.CleanState(p[Rules.Flag])or nil end
function S:_room(player)
 local data=self.Data
 return #data:GetChestRecords(player)<self.Config.MaxSavedChests and(type(data.RoomFor)~='function'or(data:RoomFor(player,1)))
end
-- The one notice. Shown once per player (Told), a moment after the grant.
function S:_notify(player)
 if self.Told[player]or not self.Notes then return end
 self.Told[player]=true
 self.Delay(Rules.NoticeDelay,function()
  if player.Parent then pcall(function()self.Notes:Show(player,Rules.Notice,GOLD,Rules.NoticeSeconds)end)end
 end)
end
-- Gives the gift. NEVER yields. Returns the pack record, or nil and why:
-- 'loading' / 'notowed' / 'given' / 'ended' (the event is over) / 'tutorial' / 'cannotsave' / 'room' / 'add'.
function S:Grant(player)
 local data=self.Data
 if not player or not player.Parent or not data:IsLoaded(player)then return nil,'loading'end
 local premium=self:_premium(player);if not premium then return nil,'loading'end
 local state=Rules.CleanState(premium[Rules.Flag])
 if state==Rules.Given then return nil,'given'end
 if state~=Rules.Owed then return nil,'notowed'end
 if not self:_active()then return nil,'ended'end
 if not Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))then return nil,'tutorial'end
 if not data.CanSave[player]and not self.Studio then return nil,'cannotsave'end
 if not self:_room(player)then return nil,'room'end
 local records=data:GetChestRecords(player);local before=#records
 local ok,record,why=pcall(function()return data:AddChest(player,Rules.Pack(PackRules))end) -- a real pack: no options (no TestGrant, no luck roll)
 local added=records[before+1]
 -- A hook that throws after AddChest committed still counts (the inventory is the commit point, as in VoidGiveaway152:_grant).
 if not(#records==before+1 and type(added)=='table'and added.Kind=='Pack'and Rules.PackFloor(added)==Rules.Floor)then
  if not ok then warn('[R158d] Starter gift: the pack could not be added: '..tostring(record))end
  return nil,why or'add'
 end
 premium[Rules.Flag]=Rules.Given;premium[Rules.RollsField]=Rules.Rolls
 data:MarkDirty(player);data:QueueGardenSave(player)
 if self.Treadmill and type(self.Treadmill.GrantReady)=='function'then
  local okRolls,err=pcall(self.Treadmill.GrantReady,self.Treadmill,player,Rules.Rolls)
  if not okRolls then warn('[R158d] Starter gift: the bonus rolls come back at the next join: '..tostring(err))end
 end
 pcall(function()self.Chests:SyncTools(player)end)
 self:_notify(player)
 return added
end
-- Tries the grant; a refusal that can pass (a full Bag, data that cannot save yet) is tried again a few times.
function S:_try(player,n)
 if self.Dead or not player.Parent then return end
 local record,why=self:Grant(player)
 if record or why=='given'or why=='ended'or why=='notowed'then return end
 if why=='tutorial'then return end -- (the attribute's own signal tries again)
 if n<Rules.Retries then self.Delay(Rules.RetryEvery,function()self:_try(player,n+1)end)end
end
-- A player whose profile is loaded: a brand-new one is marked 'Owed' (while the event runs); an owed one gets the gift when the tutorial is done.
function S:Setup(player)
 local premium=self:_premium(player);if not premium then return false end
 if premium[Rules.Flag]==nil and self:_fresh(player)and self:_active()then
  premium[Rules.Flag]=Rules.Owed;self.Data:MarkDirty(player)
 end
 if Rules.CleanState(premium[Rules.Flag])~=Rules.Owed then return false end
 if self.Watching[player]or self.Opts.NoWatch then return true end
 self.Watching[player]=player:GetAttributeChangedSignal(Rules.TutorialAttr):Connect(function()
  if Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))then self.Delay(.2,function()self:_try(player,0)end)end -- (a moment later: the tutorial's own free pack is given in the same request)
 end)
 if Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))then self:_try(player,0)end
 return true
end
-- Waits for a joined player's profile (it loads a moment after they join), then Setup.
function S:_await(player)
 for _=1,Rules.LoadTries do
  if self.Dead or not player.Parent then return end
  if self.Data:IsLoaded(player)then self:Setup(player);return end
  task.wait(Rules.LoadWait)
 end
end
function S:Start()
 if self.Started then return self end
 self.Started=true
 self.Joined=Players.PlayerAdded:Connect(function(player)task.spawn(self._await,self,player)end)
 self.Left=Players.PlayerRemoving:Connect(function(player)
  local c=self.Watching[player];if c then c:Disconnect();self.Watching[player]=nil end
  self.Told[player]=nil
 end)
 for _,player in ipairs(Players:GetPlayers())do task.spawn(self._await,self,player)end
 return self
end
function S:Destroy()
 self.Dead=true
 if self.Joined then self.Joined:Disconnect();self.Joined=nil end
 if self.Left then self.Left:Disconnect();self.Left=nil end
 for player,c in pairs(self.Watching)do c:Disconnect();self.Watching[player]=nil end
 if S.Current==self then S.Current=nil end
end
-- Owner tool ---------------------------------------------------------------------------------------------------------------------------------------------
function S:StatusText(player)
 local premium=self:_premium(player);if not premium then return'Wait for the player data to load.'end
 local state=Rules.CleanState(premium[Rules.Flag])
 local packs=0;for _,r in ipairs(self.Data:GetChestRecords(player))do if Rules.PackFloor(r)then packs+=1 end end
 local left=Limited.Left(self.Time())
 return string.format('Starter gift (R158d): %s. Event: %s. Tutorial: %s. Gift packs in the Bag: %d. Starter bonus rolls not used: %d. Fresh profile this session: %s.',
  state==Rules.Given and'GIVEN (flag Given)'or state==Rules.Owed and'OWED (waits for the finished tutorial and a running event)'or'not set (an older player, or a new one after the event ended)',
  self:_active()and('running ('..Limited.Text(left)..' left)')or'ENDED (new players get nothing)',
  Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))and'finished'or'not finished',packs,Rules.CleanRolls(premium[Rules.RollsField]),self:_fresh(player)and'yes'or'no')
end
function S:_command(player,a)
 local sub=a[1]and tostring(a[1]):lower()
 if sub==nil or sub=='status'then return true,self:StatusText(player)end
 if sub~='reset'or #a~=1 then return false,'Use starterverity @username (status) or starterverity @username reset.'end
 if not self.Studio then return false,'starterverity reset works in Studio only: a live server never changes the gift flag. Test it in Studio.'end
 local premium=self:_premium(player);if not premium then return false,'Wait for the player data to load.'end
 premium[Rules.Flag]=Rules.Owed;premium[Rules.RollsField]=nil;self.Told[player]=nil
 self.Data:MarkDirty(player)
 local record,why=self:Grant(player)
 if record then return true,'The flag was reset and the gift is given again (the pack and rolls you got before stay). '..self:StatusText(player)end
 self:Setup(player) -- (owed again: it waits for the finished tutorial)
 return true,'The flag was reset: the gift is owed ('..tostring(why)..'). '..self:StatusText(player)
end
-- OwnerUpdateCommands82 -> here (`starterverity @name [reset]`): the service running in this server.
function S.Command(_,player,a)
 local self=S.Current
 if not self then return false,'The starter gift is not running in this server.'end
 return self:_command(player,a or{})
end
return S
