-- R152 (owner: "add a pedestal in the middle that gives a player 1 void pack. it will be a limited time for 500 players only and its in every server so basically once serverwide 500
-- claims have been done it will go to 0 and will not be claimable any more. there is a number above that shows how many is left"): the server half.
--  * ONE count for every server: a DataStore key (VoidGiveawayStore152) {Count, Users = {[userId] = time}} changed only by UpdateAsync (atomic per key), so two servers racing at 499
--    can never both give the last pack and 500 is a hard cap. A player is in Users once, ever (and has the profile flag Premium.VoidGift152 once their pack is in).
--  * The claim (Claim), in this order, each step refusing without side effects:
--      1 the player's data is loaded and can save (Studio without API access may not)   2 not flagged already   3 not at the cap (unless they hold an earlier reservation)
--      4 standing at the pedestal   5 room in the Bag for one pack (the game's own limit, Config.MaxSavedChests): "make room", NOTHING reserved
--      6 RESERVE (UpdateAsync; a few tries with growing waits, then "try again"; no pack is ever given without a successful reservation)
--      7 give ONE real Void Pack (AddChest: not TestGrant, so it announces when opened like any pack), set the profile flag, save the way other grants do (MarkDirty + QueueGardenSave),
--        sync the hotbar, tell the player. Step 7 never yields: the flag check, the pack and the flag are one step, so a profile gets at most one pack however many paths run.
--    A player who is in Users but has no flag (the grant was interrupted: a crash, a full Bag after the reservation, a lost save) is "owed": they are given the pack as soon as this
--    server sees them (every 2 s, and after each read), or when they press the prompt; the reservation is the same one (idempotent), so it never counts twice.
--  * What clients see: the pedestal model's attributes Cap / Count / Left / State (Loading, Open, Empty). The highest Count ever seen wins (a read, a reserve, a MessagingService
--    message from another server's claim): it only goes up, so at 0 the pedestal stays "ALL CLAIMED" for ever (the prompt is disabled; no reset in a live server). Fresh across
--    servers: a claim is published (topic VoidGiveaway152, at most one message every 1.5 s, the latest count) and every server reads the key about once a minute (45 - 60 s),
--    until it has seen the cap (the value cannot change after that, so it stops).
--  * Studio: its own store (VoidGiveaway152_Studio); with no DataStore access an in-memory counter and one warn line (VoidGiveawayStore152). Owner tools: /test voidgift (status),
--    voidgift reset me and voidgift left <n> (both Studio only: a live server never writes the shared count from a command).
--  * Fixes after review (R152): the pack is saved GiftLocked (a free pack can't be gifted: alts claimed it for a main account; FruitGiftService refuses, Verity keeps the lock);
--    Rules.MinAccountAgeDays (0 = off) can refuse young accounts; claims honour the store's backoff (refused at once, "try again in N s", no request) and a player waits 10 s
--    after a store failure; the loop's retries of an owed pack tell the player once and back off after a failure instead of every 2 s.
--  * R158c (owner: "for the void pack there isn't a 20 minute lock anymore and requirement is just finishing the tutorial"): Claim has one refusal, next to the account-age one and before any
--    reservation: the player's attribute TutorialDone (TutorialProgress; true also after a skip, as in TrackHoleService / PremiumService / FruitGiftService) must be true, or the claim is refused
--    with no side effect (no store request, no state change): "finish the tutorial to get your free void pack!". A player who is owed a pack (reserved before) is never held up by it. The R157
--    20-minute play-time rule is gone; its counter (Premium.PlaySeconds157, counted in Step) and /test playtime stay, but nothing is refused for play time.
-- Builds: VoidGiveawayArt152 (the stone and the prompt). Client: VoidGiveawayClient152 (the pack, the number, the prompt for the one who already claimed).
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('VoidGiveawayRules152'));local PackRules=require(RS:WaitForChild('SeedPackRules'))
local Art=require(script.Parent.VoidGiveawayArt152);local Store=require(script.Parent.VoidGiveawayStore152);local Gate=require(script.Parent.SecurityGate)
local S={Version=152};S.__index=S
local RGB=Color3.fromRGB
local VIOLET,AMBER=RGB(190,144,255),RGB(255,190,90)
S.LoopSeconds=2;S.PollSeconds=45;S.PollJitter=15;S.PublishGap=1.5;S.MaxDistance=48
S.StoreCooldown=10 -- seconds a player waits after a store failure; S.FailBase/FailMax: the wait before the loop retries a pack that could not be added (5, 10, 20 .. 60 s)
S.FailBase,S.FailMax=5,60
S.PlayMaxStep=5;S.PlaySaveEvery=30;S.PlaySaveDone=300;S.PlayMark=1200 -- R157 counter: a look counts at most 5 s (a hitch or a paused Studio is not play); the field is marked dirty every 30 s (every 5 min once 20 min (PlayMark) are in)
-- config, data (PlayerDataService), chests (ChestService), notes (NotificationService), map (MapService). opts (all optional; the tests pass fakes): Store, Clock (seconds), Time (Unix
-- seconds), Messaging, Random, Studio, Art, NoLoop.
function S.new(config,data,chests,notes,map,opts)
 opts=opts or{}
 local clock=opts.Clock or os.clock
 local studio=opts.Studio;if studio==nil then local ok,v=pcall(function()return game:GetService('RunService'):IsStudio()end);studio=ok and v==true end
 local self=setmetatable({Config=config,Data=data,Chests=chests,Notes=notes,Map=map,Opts=opts,Clock=clock,Time=opts.Time or os.time,Studio=studio==true,Art=opts.Art or Art,
  Random=opts.Random or Random.new(),Messaging=opts.Messaging,Count=nil,Users={},Reserved={},Busy=setmetatable({},{__mode='k'}),Ready=setmetatable({},{__mode='k'}),
  Told=setmetatable({},{__mode='k'}),Cool=setmetatable({},{__mode='k'}),Failed=setmetatable({},{__mode='k'}),NextPoll=0,NextSubscribe=0,PublishedAt=-1e9,PublishPending=false,PublishTries=0,Subscribed=false,ReadFull=false,Sent=0,Received=0,Dead=false},S)
 self.Store=opts.Store or Store.new({Clock=clock,Time=opts.Time,Studio=studio})
 self.PlayAt,self.PlayFrac,self.PlayUnsaved=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'}) -- R157: per player: the last look, the part of a second not counted yet, the seconds not marked dirty yet
 S.Current=self
 return self
end
-- Time and numbers ------------------------------------------------------------------------------------------------------------------------------------
function S:Left()return self.Count and Rules.Left(self.Count)or nil end
function S:Full()return self.Count~=nil and self.Count>=Rules.Cap end
-- What the pedestal says (model attributes, the prompt, the lettering). Called after every change of the count.
function S:_show()
 local m=self.Model;if not m or not m.Parent then return end
 local left=self:Left();local state=self.Count==nil and'Loading'or left>0 and'Open'or'Empty'
 local function set(k,v)if m:GetAttribute(k)~=v then m:SetAttribute(k,v)end end
 set(Rules.Attr.Cap,Rules.Cap);set(Rules.Attr.Count,self.Count);set(Rules.Attr.Left,left);set(Rules.Attr.State,state)
 local prompt=self.Pedestal and self.Pedestal.Prompt;if prompt and prompt.Enabled~=(state=='Open')then prompt.Enabled=state=='Open'end
 if self.Pedestal then self.Art.SetPlaque(self.Pedestal,state=='Empty')end
end
-- The highest count seen wins (it only goes up: at the cap it stays there). Returns true when it changed.
function S:_raise(count,source)
 count=Rules.Whole(count)
 if self.Count~=nil and count<=self.Count then return false end
 self.Count=count;self.Source=source;self:_show();return true
end
-- A value the store gave (a read, or the answer of a reservation): its users are this server's picture of the shared list; its count may raise ours.
function S:_take(value,source)
 self.Users=value.Users;self.ReadAt=self.Clock()
 if value.Count>=Rules.Cap then self.ReadFull=true end -- (a read that saw the cap saw the final list: nothing changes after it)
 return self:_raise(value.Count,source)
end
-- Owner tools (Studio): sets the count whatever it was (the only way down).
function S:_force(count,users)
 self.Count=Rules.Whole(count);if users then self.Users=users end;self.ReadFull=false;self:_show()
end
-- Players -----------------------------------------------------------------------------------------------------------------------------------------------
function S:_flag(player)return self.Data:GetPremium(player)[Rules.Flag]==true end
function S:_state(player,state)if player.Parent and player:GetAttribute(Rules.Attr.Player)~=state then player:SetAttribute(Rules.Attr.Player,state)end end
-- In the shared list (this server's picture of it) or reserved here, with no pack yet.
function S:_owed(player)
 if self:_flag(player)then return false end
 return self.Users[tostring(player.UserId)]~=nil or self.Reserved[player.UserId]==true
end
function S:_room(player)return #self.Data:GetChestRecords(player)<self.Config.MaxSavedChests and(type(self.Data.RoomFor)~='function'or(self.Data:RoomFor(player,1)))end -- R155: the 200 cap
function S:_near(player)
 local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');if not root or not self.Center then return false end
 return(root.Position-self.Center).Magnitude<=S.MaxDistance
end
function S:_say(player,text,ok)
 if not self.Notes then return end
 pcall(function()
  if ok then self.Notes:Show(player,text,VIOLET,5)else self.Notes:Show(player,text,AMBER,4,'Denied')end
 end)
end
-- A player whose profile is loaded: their state attribute (what their client shows), and the pack they are owed, if any.
function S:_setup(player)
 self.Ready[player]=true;self.PlayAt[player]=self.Clock()
 self:_state(player,self:_flag(player)and'Claimed'or'Open')
end
-- The play time counter (R157; kept, no rule uses it) -----------------------------------------------------------------------------------------------------------------------------------
-- Whole seconds this player has played (Premium.PlaySeconds157; no field = 0), or nil when the counter is not ready (the profile is not loaded, or it cannot be read): never a number then.
function S:_played(player)
 local data=self.Data;if not data:IsLoaded(player)then return nil end
 local ok,premium=pcall(data.GetPremium,data,player);if not ok or type(premium)~='table'then return nil end
 return Rules.CleanPlayed(premium[Rules.PlayField])
end
-- One look at one player whose profile is loaded (called from Step): the time since the last look (at most S.PlayMaxStep) is added; whole seconds go into the profile, the rest waits here.
-- Saved like other progress: MarkDirty now and then (the autosave and the final save on leaving write it), MarkDirty + QueueGardenSave when 20 minutes are reached (as before).
function S:_tickPlay(player,now)
 local last=self.PlayAt[player];self.PlayAt[player]=now
 if not last then return end
 local ok,premium=pcall(self.Data.GetPremium,self.Data,player);if not ok or type(premium)~='table'then return end -- (not ready: nothing is counted, nothing is said)
 local have=Rules.CleanPlayed(premium[Rules.PlayField])
 if have>=Rules.PlayCap then self.PlayFrac[player]=nil;return end
 local acc=(self.PlayFrac[player]or 0)+math.clamp(now-last,0,S.PlayMaxStep);local whole=math.floor(acc)
 self.PlayFrac[player]=acc-whole
 if whole<1 then return end
 local total=math.min(Rules.PlayCap,have+whole);premium[Rules.PlayField]=total
 local unsaved=(self.PlayUnsaved[player]or 0)+whole
 if have<S.PlayMark and total>=S.PlayMark then
  self.PlayUnsaved[player]=0;self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
 elseif unsaved>=(total>=S.PlayMark and S.PlaySaveDone or S.PlaySaveEvery)then self.PlayUnsaved[player]=0;self.Data:MarkDirty(player)
 else self.PlayUnsaved[player]=unsaved end
end
-- Gives the pack. NEVER yields. Returns the record, or nil and why ('claimed' = this profile already had it, 'room', 'add').
function S:_grant(player)
 local data=self.Data;local premium=data:GetPremium(player)
 if premium[Rules.Flag]==true then return nil,'claimed'end
 local records=data:GetChestRecords(player);local before=#records
 if before>=self.Config.MaxSavedChests then return nil,'room'end
 if type(data.RoomFor)=='function'and not data:RoomFor(player,1)then return nil,'room'end -- R155: the 200 cap (InventoryCap155)
 local pack=table.clone(Rules.Pack);pack.OddsVersion=PackRules.OddsVersion;pack.GiftLocked=true -- (a free pack can't be gifted: saved as the optional record field GiftLocked)
 local ok,record,why=pcall(function()return data:AddChest(player,pack)end) -- a real pack: no options (no TestGrant, no luck roll: a plain 1x Void Pack)
 local added=records[before+1]
 -- A hook that throws after AddChest committed still counts (the inventory is the commit point, as in GrantDailyPack).
 if not(#records==before+1 and type(added)=='table'and added.Kind=='Pack'and added.BagVariant==Rules.Pack.BagVariant and added.Stage==Rules.Pack.Stage)then
  if not ok then warn('[R152] Void giveaway: the pack could not be added: '..tostring(record))end
  return nil,why or'add'
 end
 premium[Rules.Flag]=true
 data:MarkDirty(player);data:QueueGardenSave(player)
 pcall(function()self.Chests:SyncTools(player)end)
 player:SetAttribute(Rules.Attr.At,workspace:GetServerTimeNow());self:_state(player,'Claimed')
 self:_say(player,'🌑 FREE VOID PACK! Check your bag!',true)
 return added
end
-- Seconds until this player may ask the store again: their own cooldown (after a store failure) or the store's backoff, whichever is later. 0 = now.
function S:_wait(player)
 local t=math.max(self.Cool[player]or 0,self.Store.Mode=='Memory'and 0 or self.Store.NextTryAt or 0);local now=self.Clock()
 return t>now and math.ceil(t-now)or 0
end
-- A failure the loop's retry (auto) hit: the player is told once (their own press always is), and the loop waits 5, 10, 20 .. 60 s before the next try.
function S:_failed(player,text,auto)
 local f=self.Failed[player];if not f then f={N=0};self.Failed[player]=f end
 f.N+=1;f.Until=self.Clock()+math.min(S.FailMax,S.FailBase*2^(f.N-1))
 if not auto or not f.Told then f.Told=true;self:_say(player,text)end
end
-- The yielding part of a claim: reserve, then give. auto = the loop giving a pack the player is owed.
function S:_run(player,owed,auto)
 if not owed then
  local ok,outcome,value=self.Store:Reserve(player.UserId)
  if not ok then
   if outcome~='backoff'then self.Cool[player]=self.Clock()+S.StoreCooldown end -- (a real failure: this player waits before pressing again)
   self:_say(player,'⚠ Can\'t reach the giveaway. Try again in '..math.max(1,self:_wait(player))..' s.');return false,outcome=='backoff'and'backoff'or'store'
  end
  self:_take(value,'claim')
  if outcome=='full'then self:_say(player,'🌑 All '..Rules.Cap..' free Void Packs are gone!');return false,'empty'end
  self.Reserved[player.UserId]=true
  if outcome=='new'then self:_queuePublish()end
 end
 if not player.Parent or not self.Data:IsLoaded(player)then return false,'gone'end -- (left meanwhile: the reservation stays, the pack is given when they are back)
 local record,why=self:_grant(player)
 if record then self.Failed[player]=nil;return true,record end
 if why=='claimed'then return false,'claimed'end
 if why=='room'then self:_say(player,'🎒 Your Void Pack is saved for you! Make room in your bag, then claim again.');return false,'room'end
 self:_failed(player,'⚠ Couldn\'t add the pack. Try again in a sec!',auto);return false,'add'
end
-- A player presses the prompt (auto = this server giving a pack the player is owed: quiet, no distance check). Returns true, record or false, reason.
function S:Claim(player,auto)
 if not player or not player.Parent then return false,'gone'end
 if not auto and not Gate.Allow(player,'VoidGiveaway152')then return false,'rate'end
 if self.Busy[player]then return false,'busy'end
 local fail=auto and self.Failed[player];if fail and self.Clock()<fail.Until then return false,'backoff'end -- (the loop backs off after a pack that could not be added)
 local data=self.Data;local function refuse(text,why)if not auto then self:_say(player,text)end;return false,why end
 if not data:IsLoaded(player)then return refuse('YOUR DATA IS STILL LOADING','loading')end
 if not data.CanSave[player]and not self.Studio then return refuse('NO REWARDS UNTIL YOUR DATA CAN SAVE','cannotsave')end -- (Studio without API access cannot save: the test goes on)
 if self:_flag(player)then self:_state(player,'Claimed');return refuse('✅ You already grabbed your free Void Pack!','claimed')end
 local owed=self:_owed(player)
 if not owed and self:Full()then return refuse('🌑 All '..Rules.Cap..' free Void Packs are gone!','empty')end
 local minAge=Rules.MinAccountAgeDays -- (0 = off; a reserved player is owed their pack whatever the rule says now)
 if not owed and minAge>0 and(tonumber(player.AccountAge)or 0)<minAge then return refuse('🌑 The free Void Pack is for accounts '..minAge..' days old or more. Come back in '..math.ceil(minAge-(tonumber(player.AccountAge)or 0))..' day(s)!','young')end
 -- R158c: the tutorial rule, refused before anything is reserved (no store request, no state change, no cooldown). TutorialDone is the player attribute TutorialProgress sets (true after finishing OR
 -- skipping); anything else, a missing attribute included, is "not finished". A player who already claimed was answered above; a reserved player is owed their pack whatever this rule says.
 if not owed and not Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))then return refuse(Rules.TutorialRefusal,'tutorial')end
 if not auto and not self:_near(player)then return false,'far'end
 if not self:_room(player)then
  if not auto or not self.Told[player]then self.Told[player]=true;self:_say(player,owed and'🎒 Your Void Pack is saved for you! Make room in your bag.'or'🎒 Make room in your bag first! (nothing got used)')end
  return false,'room'
 end
 if not owed then local wait=self:_wait(player);if wait>0 then return refuse('⚠ Can\'t reach the giveaway. Try again in '..wait..' s.','wait')end end -- (the store's backoff / this player's cooldown: no request)
 self.Busy[player]=true;self:_state(player,'Busy')
 local ok,done,result=pcall(self._run,self,player,owed,auto)
 self.Busy[player]=nil
 if not ok then
  warn('[R152] Void giveaway claim failed: '..tostring(done));self:_failed(player,'⚠ Couldn\'t claim it. Try again in a sec!',auto)
  done,result=false,'error'
 end
 if not done and player.Parent then self:_state(player,self:_flag(player)and'Claimed'or'Open')end
 return done,result
end
-- Messages and reads -------------------------------------------------------------------------------------------------------------------------------------
function S:_queuePublish()
 if self.Store.Mode=='Memory'then return end
 self.PublishPending=true;self.PublishTries=0
 local wait=S.PublishGap-(self.Clock()-self.PublishedAt)
 if wait<=0 then task.spawn(self._publish,self)else task.delay(wait,function()if self.PublishPending and not self.Dead then self:_publish()end end)end
end
function S:_publish()
 if not self.PublishPending or self.Count==nil then return end
 self.PublishPending=false;self.PublishedAt=self.Clock()
 local svc=self.Messaging or(function()local ok,s=pcall(function()return game:GetService('MessagingService')end);return ok and s or nil end)()
 if not svc then return end
 local ok,err=pcall(function()svc:PublishAsync(Rules.Topic,string.format('v1:%d',self.Count))end)
 if ok then self.Sent+=1
 else
  self.PublishError=tostring(err):sub(1,100);self.PublishTries+=1
  if self.PublishTries<4 then self.PublishPending=true end -- (the loop sends it again; the poll covers a message that never goes)
 end
end
function S:_onMessage(message)
 local data=type(message)=='table'and message.Data or message
 if type(data)~='string'or#data>64 then return end
 local n=data:match('^v1:(%d+)$');local count=n and tonumber(n)
 if not count or count>Rules.Cap then return end
 self.Received+=1
 if self:_raise(count,'message')and count>=Rules.Cap then self.ReadFull=false;self.NextPoll=0 end -- (read once more: the final list, for the players it owes)
end
function S:_subscribe()
 if self.Subscribed or self.Subscribing or self.Store.Mode=='Memory'then return end
 self.Subscribing=true
 local svc=self.Messaging or(function()local ok,s=pcall(function()return game:GetService('MessagingService')end);return ok and s or nil end)()
 if not svc then self.NextSubscribe=self.Clock()+30;self.Subscribing=false;return end
 local ok,err=pcall(function()svc:SubscribeAsync(Rules.Topic,function(m)self:_onMessage(m)end)end)
 if ok then self.Subscribed=true;self.SubscribeError=nil else self.SubscribeError=tostring(err):sub(1,100);self.NextSubscribe=self.Clock()+30 end
 self.Subscribing=false
end
-- One read of the shared key (the poll). A failure leaves the count as it was and tries again after the store's backoff.
function S:Poll()
 if self.Polling then return false end
 self.Polling=true
 local now=self.Clock();local result=false
 local okCall,err=pcall(function()
  local ok,value=self.Store:Read()
  if ok then self:_take(value,'store');self.NextPoll=now+S.PollSeconds+self.Random:NextNumber()*S.PollJitter;self.PollError=nil
  else self.PollError=tostring(value);self.NextPoll=now+math.max(Store.RetryBase,self.Store.NextTryAt-now)end
  result=ok
 end)
 if not okCall then self.PollError=tostring(err);self.NextPoll=now+Store.RetryBase end
 self.Polling=false
 return result
end
-- The loop ---------------------------------------------------------------------------------------------------------------------------------------------------
-- Every few seconds: players whose profile just loaded, the subscription, the poll, a message waiting to go, and the packs owed to players here.
function S:Step()
 if self.Dead then return end
 local now=self.Clock()
 for _,player in ipairs(Players:GetPlayers())do
  if self.Data:IsLoaded(player)then
   if not self.Ready[player]then self:_setup(player)else self:_tickPlay(player,now)end -- (R157: the play time is counted here, once per look)
  end
 end
 if self.Store.Mode=='DataStore'then
  if not self.Subscribed and now>=self.NextSubscribe then task.spawn(self._subscribe,self)end
  if now>=self.NextPoll and not self.ReadFull then task.spawn(self.Poll,self)end
 end
 if self.PublishPending and now-self.PublishedAt>=S.PublishGap then task.spawn(self._publish,self)end
 for _,player in ipairs(Players:GetPlayers())do
  if self.Ready[player]and not self.Busy[player]and self.Data:IsLoaded(player)and self:_owed(player)then task.spawn(self.Claim,self,player,true)end
 end
end
function S:_boot()
 self.Store:Probe()
 if self.Store.Mode=='Memory'then self:_take(Rules.Clean(self.Store.Mem),'memory')else self:Poll()end
 self:_subscribe()
end
function S:_top()
 local root=self.Map and self.Map.MapRoot or workspace:FindFirstChild('ChestChaseMap')
 local lobby=root and root:FindFirstChild('Lobby');local floor=lobby and lobby:FindFirstChild('LobbyFloor')
 local base=(floor and floor:IsA('BasePart'))and floor.Position.Y+floor.Size.Y/2 or Rules.FloorTop
 return base+Rules.PlazaRise
end
function S:Start()
 if self.Started then return self end
 self.Started=true
 local root=self.Map and self.Map.MapRoot or workspace:FindFirstChild('ChestChaseMap')
 if not root then warn('[R152] Void giveaway: the map is missing; the pedestal was not built.');return self end
 local top=self:_top()
 self.Pedestal=self.Art.Build(root,top);self.Model=self.Pedestal.Model
 self.Center=Vector3.new(Rules.Center.X,top,Rules.Center.Z)
 self.Pedestal.Prompt.Triggered:Connect(function(player)self:Claim(player)end)
 self:_show() -- (Loading: the prompt is off until the first read says how many are left)
 self.Leaving=Players.PlayerRemoving:Connect(function(player)self.Busy[player]=nil;self.Ready[player]=nil;self.Told[player]=nil;self.Cool[player]=nil;self.Failed[player]=nil;self.PlayAt[player]=nil;self.PlayFrac[player]=nil;self.PlayUnsaved[player]=nil end)
 task.spawn(function()self:_boot()end)
 if not self.Opts.NoLoop then
  task.spawn(function()
   while not self.Dead do
    task.wait(S.LoopSeconds)
    if self.Dead then break end
    local ok,err=pcall(self.Step,self);if not ok then warn('[R152] Void giveaway step: '..tostring(err))end
   end
  end)
 end
 return self
end
function S:Destroy()
 self.Dead=true
 if self.Leaving then self.Leaving:Disconnect();self.Leaving=nil end
 if self.Model then self.Model:Destroy();self.Model=nil end
 if S.Current==self then S.Current=nil end
end
-- Owner tools -----------------------------------------------------------------------------------------------------------------------------------------------
local function ago(self,t)return t and string.format('%d s ago',math.max(0,math.floor(self.Clock()-t)))or'never'end
function S:Status()
 local st=self.Store:Status()
 return{Count=self.Count,Left=self:Left(),Cap=Rules.Cap,Source=self.Source,Mode=st.Mode,Store=st.Store,Key=st.Key,Studio=self.Studio,Failures=st.Failures,LastError=st.LastError,Why=st.Why,
  ReadAt=self.ReadAt,Subscribed=self.Subscribed,Sent=self.Sent,Received=self.Received,Full=self:Full(),Settled=self.ReadFull,PollError=self.PollError,Users=self.Users}
end
-- "12 min 30 s" (whole seconds).
local function minSec(seconds)seconds=Rules.CleanPlayed(seconds);return string.format('%d min %d s',seconds//60,seconds%60)end
-- The play time line of voidgift: how long this player has played (a counter only: the claim never waits for it).
function S:PlayText(player)
 local played=self:_played(player)
 if played==nil then return'Play time: not loaded yet (it is only a counter: the claim does not use it).'end
 return string.format('Play time: %s played (saved in Premium.%s%s; the claim does not use it).',minSec(played),Rules.PlayField,self.Data.CanSave[player]==false and', but this profile cannot save: kept in memory'or'')
end
-- The tutorial line of voidgift: the claim needs a finished (or skipped) tutorial.
function S:TutorialText(player)
 local done=Rules.TutorialDone(player:GetAttribute(Rules.TutorialAttr))
 return'Tutorial: '..(done and'finished (the claim is open for you)'or'NOT finished (the claim says "'..Rules.TutorialRefusal..'")')..'.'
end
function S:StatusText(player)
 local s=self:Status();local lines={}
 lines[#lines+1]=s.Count and string.format('Void giveaway: %d claimed, %d / %d LEFT%s (count from: %s, store read %s).',s.Count,s.Left,s.Cap,s.Full and' - ALL CLAIMED, for ever'or'',tostring(s.Source),ago(self,s.ReadAt))
  or'Void giveaway: the count is not known yet (the first read has not come back).'
 local flag=player and self:_flag(player);local listed=player and self.Users[tostring(player.UserId)]~=nil or(player and self.Reserved[player.UserId]==true)
 if player then lines[#lines+1]=string.format('You: %s (profile flag: %s, in the shared list: %s, state: %s).',flag and'CLAIMED'or listed and'RESERVED, pack owed'or'not claimed',flag and'yes'or'no',listed and'yes'or'no',tostring(player:GetAttribute(Rules.Attr.Player)))end
 local where=s.Mode=='Memory'and('in-memory counter (Studio, no DataStore access: '..tostring(s.Why)..')')
  or s.Studio and("Studio DataStore '"..s.Store.."' key '"..s.Key.."' (a separate test store, not the live count)")
  or("DataStore '"..s.Store.."' key '"..s.Key.."' (LIVE)")
 lines[#lines+1]='Store: '..where..'; failures '..s.Failures..(s.LastError and('; last error: '..s.LastError)or'')..(s.PollError and('; poll: '..s.PollError)or'')..'.'
 lines[#lines+1]=string.format('Messages: %s; sent %d, received %d.',s.Subscribed and'subscribed'or(s.Mode=='Memory'and'off (memory mode)'or'NOT subscribed'),s.Sent,s.Received)
 if player then lines[#lines+1]=self:TutorialText(player);lines[#lines+1]=self:PlayText(player)end
 local prompt=self.Pedestal and self.Pedestal.Prompt
 lines[#lines+1]='Pedestal: '..(self.Model and tostring(self.Model:GetAttribute(Rules.Attr.State))or'not built')..'; prompt '..(prompt and prompt.Enabled and'on'or'off')..'.'
 lines[#lines+1]=self.Studio and'Studio tools: voidgift reset me (clears your claim and flag), voidgift left <0-'..Rules.Cap..'> (sets how many are left).'or'A live server never resets or edits the shared count (the Studio-only tools are off here).'
 return table.concat(lines,'\n')
end
function S:_command(player,a)
 local sub=a[1]and tostring(a[1]):lower()
 if sub==nil or sub=='status'then return true,self:StatusText(player)end
 if sub~='reset'and sub~='left'then return false,'Use voidgift, voidgift reset me, or voidgift left <0-'..Rules.Cap..'>.'end
 if not self.Studio then return false,'voidgift '..sub..' works in Studio only: a live server never changes the shared count. Test it in Studio (its own store, or an in-memory counter).'end
 if sub=='reset'then
  if #a~=2 or tostring(a[2]):lower()~='me'then return false,'Use voidgift reset me (it clears YOUR claim and flag; the pack you got stays in your Bag).'end
  local uid=player.UserId;local key=tostring(uid)
  local ok,value=self.Store:Edit(function(v)if v.Users[key]~=nil then v.Users[key]=nil;v.Count=math.max(0,v.Count-1)end;return v end)
  if not ok then return false,'The store could not be edited: '..tostring(value)end
  self.Reserved[uid]=nil;self.Told[player]=nil;self.Data:GetPremium(player)[Rules.Flag]=nil
  self.Data:MarkDirty(player);self:_force(value.Count,value.Users);self:_state(player,'Open')
  return true,'Your giveaway claim is cleared: '..(Rules.Left(value.Count))..' / '..Rules.Cap..' LEFT. You can claim again.'
 end
 local n=tonumber(a[2])
 if #a~=2 or not n or n~=n or n%1~=0 or n<0 or n>Rules.Cap then return false,'Use voidgift left <0-'..Rules.Cap..'> (how many packs the pedestal shows as left).'end
 local ok,value=self.Store:Edit(function(v)v.Count=Rules.Cap-n;return v end)
 if not ok then return false,'The store could not be edited: '..tostring(value)end
 self:_force(value.Count,value.Users)
 local left=Rules.Left(value.Count)
 return true,'The Studio counter now shows '..left..' / '..Rules.Cap..' LEFT'..(left~=n and(' (the '..#self:_userList()..' players already in the list keep their places)')or'')..'.'
end
function S:_userList()local out={};for k in pairs(self.Users)do out[#out+1]=k end;return out end
-- R157 counter: playtime [<minutes>] (per player: /test playtime @name <minutes>). No number = shows the player's play time. A number sets it (Studio only, like the voidgift edits: a live server never
-- changes a player's play time): the profile field, saved the usual way, the half second not counted yet forgotten. It is a counter only: no claim waits for it (R158c).
function S:_playtime(player,a)
 local played=self:_played(player)
 if played==nil then return false,'Wait for the player data to load.'end
 if #a==0 then return true,self:PlayText(player)end
 if not self.Studio then return false,'playtime <minutes> works in Studio only: a live server never changes play time. Test it in Studio.'end
 local minutes=#a==1 and tonumber(a[1])
 if not minutes or minutes~=minutes or minutes<0 or minutes*60>Rules.PlayCap then return false,'Use playtime <minutes> @username (0 to '..Rules.PlayCap//60 ..' minutes), or playtime @username to see it.'end
 local seconds=Rules.CleanPlayed(math.floor(minutes*60+.5))
 self.Data:GetPremium(player)[Rules.PlayField]=seconds
 self.PlayFrac[player]=nil;self.PlayUnsaved[player]=0
 self.Data:MarkDirty(player);self.Data:QueueGardenSave(player)
 return true,'Play time set. '..self:PlayText(player)
end
function S.PlaytimeCommand(_,player,a)
 local self=S.Current
 if not self then return false,'The Void giveaway is not running in this server.'end
 return self:_playtime(player,a or{})
end
-- OwnerUpdateCommands82 -> here (`voidgift`): the service running in this server.
function S.Command(_,player,a)
 local self=S.Current
 if not self then return false,'The Void giveaway is not running in this server.'end
 return self:_command(player,a or{})
end
return S
