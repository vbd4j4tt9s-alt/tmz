-- R151 (owner: "best pull today" and "biggest fruit" displays in the hub's two empty corners, across all servers, with the champion's avatar beside a giant model):
-- the server half. R153 (owner: "make the best pull of the day refresh every 10 minutes and its a local server only thing to increase performance"): BEST PULL is this server's own
-- board now, emptied at every wall-clock 10-minute mark (:00, :10, :20 ...: HubDisplayRules.PullWindowIndex of os.time()); it never touches the shared store or any other server
-- (no MemoryStore, no saves, no MessagingService, nothing kept past the window). BIGGEST FRUIT is as it was: shared, daily. What it does:
--  * Counts every real thing the server decides: a pack opened (PlayerDataService:OpenSeedPack calls NotePull with the reward and the pack it came from) and a fruit
--    picked by hand (ChestService's garden Harvest calls NoteHarvest). Not counted: TEST packs (/test rarepacks), anything an owner command just gave that player
--    (NoteOwnerGrant: the rest of that session; R152: and for good, what carries TestGrant: packs, seeds and the plants grown from them, pulls with owner-given boots), the owner's injected test pulls / fruit (they only ever show on this server).
--  * Keeps this server's view of the two boards (HubDisplayBoard): the shared store's best (Remote: the fruit's only), this server's own best (Local) and an injected one (Test). The
--    displays always show the best of the three. Everything an event does here is instant and local; the FRUIT's shared store (HubDisplayStore, MemoryStore) is written about 3 s
--    later (compare-and-set: only if better) and read about once a minute (45 s + 0..15 s of jitter), so the other servers' champions arrive within a minute. If the store
--    fails the server keeps its own board and keeps trying (the store backs off; see HubDisplayStore). The PULL board has no Remote and no store: a pull is counted here, shown here, and
--    gone at the next window.
--  * Shows them: HubDisplayArt builds the two pedestals (the Fruit of the Hour's, bigger) in the hub's empty back corners; on a change this writes the words, the colours, a new showcase item
--    and the champion's avatar (HubDisplayAvatar: 25 studs tall, made ready to dance: Animate; R153: each client plays the dance), each built once per champion (a generation number drops a build
--    that a newer champion overtook; R153: a new record of the SAME champion keeps the avatar that stands there, so its dance goes on), and bumps the display's `Rev` attribute so every
--    client pops it. R153: each client tells how the dance went on its screen (ChestChaseRemotes.HubDisplayAvatarReport -> NoteReport), shown by the owner's `/test hubdisplays`. When someone takes the top spot in THIS server it is announced in CHAT, through PullAnnouncer.Announce({Kind='Record', ...}) (the owner: pull announcements
--    only in chat): who hears it is PullAnnounceRules.RecordScope (R153: a best pull Legendary or better in THIS server, never another one, lower nothing; a fruit record this server);
--    a record that comes from a pack open waits until the puller's reveal has shown the seed (AfterReveal), like the pull line; there is no notice banner of its own any more (it
--    would be a second message). The celebration chime (a Remote the client plays GemClaim for) goes out in step with the line. An owner's test (bestpull / bigfruit) is told to its
--    target only, and nothing is announced while previewing another day.
--  * UTC midnight (the daily rewards' day) clears the FRUIT board; the fruit of the day is HubDisplayRules.FruitForDay. R153: the wall-clock 10-minute mark clears the PULL board (Step /
--    NotePull look at os.time(); the loop wakes just after the mark, SleepSeconds): the display goes back to its empty state (the black silhouette, a mystery seed, 'Nobody yet') and the
--    champion's rig is destroyed with it, so every client drops its dance track (HubDisplayClient). A window that opens on an already empty board changes only the countdown.
-- No per-frame work: one loop wakes every 5 s (and once at each window mark), does a few integer comparisons, and only touches MemoryStore (the fruit's) when a timer is due.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage')
local Rules=require(RS:WaitForChild('HubDisplayRules'))
local PackRules=require(RS:WaitForChild('SeedPackRules'))
local Board=require(script.Parent.HubDisplayBoard)
local Store=require(script.Parent.HubDisplayStore)
local Art=require(script.Parent.HubDisplayArt)
local Avatar=require(script.Parent.HubDisplayAvatar)
local S={};S.__index=S
S.LoopSeconds=5
S.RemoteName='HubDisplayCelebrate'
local KINDS={'Pull','Fruit'}
local SHARED={'Fruit'} -- (R153: the boards that go through the shared store. BEST PULL is this server's alone.)
local function guard(label,fn,...)
 local ok,result=pcall(fn,...)
 if not ok then warn('[R151] '..label..': '..tostring(result))end
 return ok,result
end
-- opts (all optional; the tests pass fakes): Clock (seconds for timers, default os.clock), Time (Unix seconds, default os.time), Store, Avatars, Art, FruitList, Random,
-- Announce (function(spec) -> ok, seconds: default PullAnnouncer.Announce). `notes` (the notice feed) is kept for the signature only: nothing is shown through it any more.
function S.new(config,data,notes,map,opts)
 opts=opts or{}
 local clock=opts.Clock or os.clock
 local self=setmetatable({Config=config,Data=data,Notes=notes,Map=map,Clock=clock,Time=opts.Time or os.time,Opts=opts,Art=opts.Art or Art,
  Board=Board.new(),Store=opts.Store or Store.new({Clock=clock}),Avatars=opts.Avatars or Avatar.new({Clock=clock}),
  Displays={},DayOffset=0,Tainted=setmetatable({},{__mode='k'}),Shown={Pull=nil,Fruit=nil},Gen={Pull=0,Fruit=0},Rev={Pull=0,Fruit=0},
  NextPoll=0,NextWrite=0,Blocked={Fruit=0},LastNotice={Pull=-1e9,Fruit=-1e9},Events={Pull=0,Fruit=0},Dead=false,Built={Pull=nil,Fruit=nil},
  Random=opts.Random or Random.new()},S)
 self.Announce=opts.Announce or function(spec)
  local ok,announcer=pcall(require,script.Parent.PullAnnouncer)
  if not ok or type(announcer)~='table'then return false,'announcer'end
  return announcer.Announce(spec)
 end
 self.FruitList=opts.FruitList
 return self
end
-- Time ---------------------------------------------------------------------------------------------------------------------------------------------------
function S:Now()return math.floor(self.Time())+self.DayOffset*86400 end -- (whole seconds: records store integers)
function S:Day()return Rules.Day(self:Now())end
-- The fruit types in the rotation (once; the catalog never changes while a server runs).
function S:Fruits()
 if not self.FruitList then
  local ok,list=pcall(Rules.EligibleFruits)
  self.FruitList=ok and list or{}
 end
 return self.FruitList
end
function S:FruitId(day)return Rules.FruitForDay(self:Fruits(),day or self:Day())end
function S:FruitName(id)
 local def;pcall(function()def=require(RS:WaitForChild('PlantCatalog'))[id]end)
 return Rules.FruitLabel(id,def and def.HarvestName or id)
end
-- Day ------------------------------------------------------------------------------------------------------------------------------------------------------
-- Moves to today if the UTC day (or the preview offset) changed: the FRUIT board starts empty, the fruit of the day is picked. Returns true when it changed. (R153: the pull board is not
-- the day's: see _syncWindow.)
function S:_syncDay()
 local day=self:Day();local fruit=self:FruitId(day)
 if not self.Board:SetDay(day,fruit)then return false end
 self.Shown.Fruit=nil
 self.NextPoll=self.Clock() -- (read the shared board for the new day at the next step)
 self.Blocked={Fruit=0}
 self:_refresh('Fruit')
 return true
end
-- Window (R153) --------------------------------------------------------------------------------------------------------------------------------------------
-- BEST PULL's clock is the real wall clock (os.time(), never the previewed day): the window number is os.time() // PullWindow, so every server's windows start at the same :00 / :10 / :20.
function S:Window()return Rules.PullWindowIndex(self.Time())end
-- Moves to the current window if it changed: the pull board is emptied (all of it: this server's best and an injected test pull) and the display goes back to its empty state. A board
-- that was already empty has nothing to rebuild (no new rig, item or sign): only its countdown moves on. Returns true when the window changed.
function S:_syncWindow()
 if not self.Board:SetWindow(self:Window())then return false end
 if not self:_refresh('Pull')then self:_restamp('Pull')end
 return true
end
-- Seconds the loop sleeps: LoopSeconds, or less to wake just after the next window mark (PullSecondsLeft is at least 1, so never a busy loop).
function S:SleepSeconds()
 local left=Rules.PullSecondsLeft(self.Time())
 return math.min(S.LoopSeconds,left)
end
-- Showing --------------------------------------------------------------------------------------------------------------------------------------------------
-- The display of a board shows its champion (or the empty state). Does nothing when what it shows is already right. The words and colours change at once; the showcase item and
-- the avatar are built in a task of their own (yields: meshes, the avatar service, the dance loading) and dropped if a newer champion arrived meanwhile.
-- The clock of a display: seconds to its next board and the server time of it (what each client counts down to). R153: BEST PULL's is its window (real time, whatever day is being
-- previewed); BIGGEST FRUIT's is the UTC day, as ever.
function S:_clock(kind)
 if kind=='Pull'then
  local real=math.floor(self.Time())
  return Rules.PullSecondsLeft(real),Rules.PullWindowEnd(real)
 end
 local now=self:Now()
 return Rules.SecondsLeft(now),Rules.NextAt(self.Board.Day or Rules.Day(now))-self.DayOffset*86400
end
function S:_text(kind,rec)
 local fruitId=self.Board.FruitId
 local left=self:_clock(kind)
 local text=Rules.SignText(kind,rec,fruitId,left,kind=='Fruit'and fruitId and self:FruitName(fruitId)or nil)
 if kind=='Fruit'and fruitId then text.Accent=Rules.RarityColor(PackRules.SeedRarityById[fruitId]or'Common')end
 return text
end
-- The countdown's two attributes (the client counts down to NextAt, in the footer's words).
function S:_stamp(kind)
 local d=self.Displays[kind];if not d then return end
 local _,nextAt=self:_clock(kind)
 d.Model:SetAttribute('FooterPrefix',Rules.FooterPrefix(kind))
 d.Model:SetAttribute('NextAt',nextAt)
end
-- A new window on a board that is empty before and after: nothing to build, only the countdown (its attributes and the words the server wrote on the label). No Rev bump, no pop.
function S:_restamp(kind)
 local d=self.Displays[kind];if not d then return end
 guard('sign',self.Art.SetSign,d,self:_text(kind,self.Board:Best(kind)))
 self:_stamp(kind)
end
function S:_refresh(kind,force)
 local d=self.Displays[kind];if not d then return false end
 local rec=self.Board:Best(kind)
 local fruitId=self.Board.FruitId
 -- (R153: a pull's identity is the pull alone: not the day, not the window, so an empty board that stays empty across windows is not rebuilt)
 local key=kind=='Pull'and Rules.Key(rec)or(Rules.Key(rec)..'|'..tostring(fruitId or'')..'|'..tostring(self.Board.Day))
 if key==self.Shown[kind]and not force then return false end
 self.Shown[kind]=key
 self.Gen[kind]+=1;local gen=self.Gen[kind]
 local text=self:_text(kind,rec)
 guard('sign',self.Art.SetSign,d,text)
 local calm=kind=='Pull'and rec==nil
 guard('tint',self.Art.Tint,d,text.Accent,calm and'Empty'or'Ready')
 local m=d.Model
 self:_stamp(kind)
 m:SetAttribute('FruitId',fruitId);m:SetAttribute('Champion',rec and rec.Name or nil);m:SetAttribute('ChampionUserId',rec and rec.Uid or nil)
 m:SetAttribute('Rarity',rec and rec.Rarity or nil)
 self.Rev[kind]+=1;m:SetAttribute('Rev',self.Rev[kind]) -- (last: the client reads the rest when this changes)
 task.spawn(function()guard('visuals',self._visuals,self,kind,rec,gen,fruitId,text.Accent,calm)end)
 return true
end
function S:_stale(kind,gen)return self.Dead or self.Gen[kind]~=gen end
function S:_visuals(kind,rec,gen,fruitId,accent,calm)
 local d=self.Displays[kind];if not d then return end
 local spec
 if kind=='Pull'then spec={Kind='Seed',Id=rec and rec.Id or'SunflowerSeed',Coat=rec and rec.Coat or'None',Mystery=rec==nil,Accent=accent,Calm=calm}
 else spec={Kind='Fruit',Id=fruitId,Coat=rec and rec.Coat or'None',Accent=accent,Calm=calm}end
 if not spec.Id then self.Art.SetItem(d,nil);return end
 local model,info=self.Art.BuildItem(d,spec)
 if self:_stale(kind,gen)then if model then model:Destroy()end;return end
 self.Art.SetItem(d,model);self.Built[kind]=info
 -- the avatar: the champion's, or a black silhouette while nobody holds the spot. R153: the same champion with a better record keeps the avatar that stands there (no new rig: the dance
 -- every client is playing on it goes on, nothing is fetched again)
 self.AvatarShown=self.AvatarShown or{}
 local shown=self.AvatarShown[kind]
 if rec and shown and shown.Uid==rec.Uid and shown.Source=='avatar'and shown.Model and shown.Model.Parent then
  d.Model:SetAttribute('Built',(d.Model:GetAttribute('Built')or 0)+1)
  return
 end
 local avatar,source
 if rec then avatar,source=self.Avatars:Build(rec.Uid)else avatar,source=self.Avatars:Build(0,{Silhouette=true})end
 if self:_stale(kind,gen)then if avatar then avatar:Destroy()end;return end
 local mode='static'
 if avatar then
  local placed=self.Avatars:Place(avatar,d.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn)
  if placed then
   self.Art.SetAvatar(d,avatar)
   -- in the world now: ready to dance (R153: each client plays it; a rig that cannot dance gets the static pose instead). A stand-in Avatars may yield here, so look again afterwards.
   if self.Avatars.Animate then
    local okAnimate,result=pcall(self.Avatars.Animate,self.Avatars,avatar,rec and rec.Uid or 0)
    if okAnimate then mode=result else warn('[R151] avatar animation: '..tostring(result))end
   end
   if self:_stale(kind,gen)then return end
  else avatar:Destroy();self.Art.SetAvatar(d,nil);avatar=nil end
 end
 self.AvatarShown[kind]={Uid=rec and rec.Uid or 0,Source=source,Model=avatar}
 self.AvatarSource=self.AvatarSource or{};self.AvatarSource[kind]=source
 self.AvatarMode=self.AvatarMode or{};self.AvatarMode[kind]=mode
 self.DanceId=self.DanceId or{};self.DanceId[kind]=avatar and avatar:GetAttribute('DanceId')or nil
 d.Model:SetAttribute('Built',(d.Model:GetAttribute('Built')or 0)+1)
end
-- Client reports (R153) --------------------------------------------------------------------------------------------------------------------------------------
-- What the dance did on one player's screen (HubDisplayClient sends it when it changes): {Kind='Pull'|'Fruit', Mode='dance'|'loading'|'pose'|'static', Id=<one of DanceIds>, Loaded=bool,
-- Length=seconds, Tries=n, Paused=bool, User=<the rig's user id>}. Only for the owner's status line: checked field by field, at most ReportBurst a player in ReportWindow seconds, the last
-- one per display kept (players who left are forgotten with their Player). Returns true when it was kept.
S.ReportBurst=20;S.ReportWindow=10
local REPORT_MODES={dance=true,loading=true,pose=true,static=true}
function S:NoteReport(player,info)
 if typeof(player)~='Instance'or type(info)~='table'then return false end
 local kind=info.Kind;if kind~='Pull'and kind~='Fruit'then return false end
 if type(info.Mode)~='string'or not REPORT_MODES[info.Mode]then return false end
 self.Reports=self.Reports or setmetatable({},{__mode='k'})
 local r=self.Reports[player];local now=self.Clock()
 if not r then r={Count=0,Since=now};self.Reports[player]=r end
 if now-r.Since>=S.ReportWindow then r.Count=0;r.Since=now end
 if r.Count>=S.ReportBurst then return false end
 r.Count+=1
 local id=nil
 for _,known in ipairs(Rules.DanceIds)do if info.Id==known then id=known end end
 local length=tonumber(info.Length);if not length or length~=length or length<0 or length>600 then length=0 end
 local tries=tonumber(info.Tries);if not tries or tries~=tries or tries<0 or tries>99 then tries=0 end
 local user=tonumber(info.User);if not user or user~=user or user%1~=0 or math.abs(user)>2^53 then user=0 end
 r[kind]={Mode=info.Mode,Id=id,Loaded=info.Loaded==true,Length=math.floor(length*100+.5)/100,Tries=math.floor(tries),Paused=info.Paused==true,User=user,At=now}
 return true
end
-- The owner's words about one display's dance: the server's AvatarMode and dance id, then `player`'s own screen (when given) and how many other screens report what.
function S:_danceText(kind,player)
 local mode=self.AvatarMode and self.AvatarMode[kind]
 local id=self.DanceId and self.DanceId[kind]
 local out='AvatarMode '..tostring(mode or'-')..(id and(' '..(tostring(id):match('%d+')or id))or'')
 local function screen(r)
  if not r then return'no report yet'end
  local t=r.Mode
  if r.Mode=='dance'then t=t..string.format(': track loaded, Length %.2f s, %s%s',r.Length,r.Paused and'paused (reduced motion / low quality)'or'playing',r.Tries>1 and(', try '..r.Tries)or'')
  elseif r.Mode=='loading'then t=t..string.format(': try %d of %d, Length %.2f',r.Tries,Rules.DanceTries,r.Length)
  elseif r.Mode=='pose'and r.Tries>0 then t=t..string.format(': the dance did not load (%d tries, Length %.2f), posed on that screen',r.Tries,r.Length)end
  if r.Id and r.Id~=id then t=t..' (id '..(r.Id:match('%d+')or r.Id)..')'end
  return t
 end
 local shown=self.AvatarShown and self.AvatarShown[kind]
 if player then
  local r=self.Reports and self.Reports[player];r=r and r[kind]
  if r and shown and r.User~=shown.Uid then r=nil end -- (a report about an avatar that is gone)
  out=out..'; your screen: '..screen(r)
 end
 local counts={};local n=0
 for p,r in pairs(self.Reports or{})do local k=r[kind];if k and p~=player and(not shown or k.User==shown.Uid)then counts[k.Mode]=(counts[k.Mode]or 0)+1;n+=1 end end
 if n>0 then
  local parts={};for _,m in ipairs({'dance','loading','pose','static'})do if counts[m]then parts[#parts+1]=counts[m]..' '..m end end
  out=out..'; other screens: '..table.concat(parts,', ')
 end
 return out
end
-- Events -----------------------------------------------------------------------------------------------------------------------------------------------------
-- An owner command just gave this player packs / seeds / plants: what they open or pick for the rest of this session is not counted.
function S:NoteOwnerGrant(player)if player then self.Tainted[player]=true end end
local function wholeNumber(n)return type(n)=='number'and n==n and n%1==0 end
-- A pack was opened: reward = the record OpenSeedPack made (SeedId, SeedName, Rarity, SeedScale, PackMutation), info = {Stage, Variant, Version, Boost, Luck, PassLuck (R154), Test} of the PACK it
-- came from (Test = a guaranteed TEST reveal, an owner-made TestGrant pack, or luck from owner-given boots: R152). Never throws, never yields. Returns true when the pull was counted.
function S:NotePull(player,reward,info)
 if self.Dead or type(reward)~='table'or typeof(player)~='Instance'then return false end
 info=type(info)=='table'and info or{}
 if info.Test==true then return false,'test pack'end
 if self.Tainted[player]then return false,'owner-granted'end
 self:_syncWindow() -- (R153: a pull that comes right after a window mark is the new window's first, even before the loop has noticed the mark)
 local odds
 -- R155: a pack pity's lucky pack (info.Lucky) rolled with x1.5 luck and the x1.5 cap: its odds are read the same way (PackPity155.Scoped)
 local ok,table_=pcall(require(RS:WaitForChild('PackPity155')).Scoped,info.Lucky==true,PackRules.SeedOdds,self.Config,info.Stage,info.Variant,info.Luck,info.Version,info.Boost,info.PassLuck) -- R154: + the clover's luck (Void / Verity / Mech packs)
 if ok and type(table_)=='table'then odds=table_[reward.SeedId]end
 if type(odds)~='number'or odds~=odds or odds<=0 then local style=PackRules.Rarities[reward.Rarity];odds=style and style.Weight or nil end
 local rec=Rules.CleanPull({Uid=player.UserId,Name=player.DisplayName,Id=reward.SeedId,Seed=Rules.SeedLabel(reward.SeedId,reward.SeedName),Rarity=reward.Rarity,
  Odds=odds,Scale=reward.SeedScale,Coat=reward.PackMutation,At=self:Now()})
 if not rec then return false,'bad pull'end
 return self:_event('Pull',rec,{Player=player})
end
-- A fruit was picked by hand: harvest = the record HarvestPlant made (SeedId, FruitScale, Mutation, Weather).
function S:NoteHarvest(player,harvest)
 if self.Dead or type(harvest)~='table'or typeof(player)~='Instance'then return false end
 self:_syncDay()
 if harvest.SeedId~=self.Board.FruitId then return false,'not today\'s fruit'end -- (the common case: one string compare)
 if harvest.TestGrant==true then return false,'test seed'end -- R152: grown from a seed an owner command gave (it keeps the mark through planting, saving and harvesting)
 if self.Tainted[player]then return false,'owner-granted'end
 local rec=Rules.CleanFruit({Uid=player.UserId,Name=player.DisplayName,Id=harvest.SeedId,Scale=harvest.FruitScale or harvest.PlantScale or 1,Coat=harvest.Mutation,
  Weather=harvest.Weather,At=self:Now()})
 if not rec then return false,'bad fruit'end
 return self:_event('Fruit',rec,{Player=player})
end
-- who = {Player = whose it is, Injected = an owner's test (bestpull / bigfruit)}: only used to word and aim the announcement.
function S:_event(kind,rec,who)
 local result=self.Board:Offer(kind,rec)
 if result=='ignored'then return false end
 self.Events[kind]+=1
 if result=='took'then
  self:_refresh(kind)
  self:_announce(kind,rec,who)
 end
 return true,result
end
-- Someone took the top spot of a board in THIS server: ONE chat line through PullAnnouncer (and the celebration chime in step with it). Not announced:
--  * while previewing another day (nothing about a preview is real);
--  * a second record of the same board within NoticeGap seconds (the display still changes);
--  * a record PullAnnounceRules.RecordScope gives no scope (a pull below Legendary): PullAnnouncer says no, and so does this.
-- A real pull waits until the puller's reveal has shown the seed (AfterReveal; a harvest has no reveal); the scope (this server / every server) is the rules'. An owner's test is
-- private: only its target gets the line and the chime (To), never the server and never another server, whether it is shared or not.
function S:_announce(kind,rec,who)
 if self:_preview()then return false end
 local now=self.Clock()
 if now-self.LastNotice[kind]<Rules.NoticeGap then return false end
 local player=who and typeof(who.Player)=='Instance'and who.Player or nil
 local spec={Kind='Record',Record=kind=='Pull'and'BestPull'or'BiggestFruit',SeedId=PackRules.SeedDesignById[rec.Id]and rec.Id or nil}
 if player then spec.Player=player else spec.Name=rec.Name;spec.UserId=rec.Uid end
 local private=who~=nil and who.Injected==true
 if private then
  if not player then return false end
  spec.To=player
 elseif kind=='Pull'then spec.AfterReveal=true end
 local called,ok,wait=pcall(self.Announce,spec)
 if not called then warn('[R151] Hub record announcement: '..tostring(ok));return false end
 if not ok then return false end
 self.LastNotice[kind]=now
 self:_celebrate(kind,rec,wait,spec.To)
 return true
end
-- The chime: every player in this server (only `only` for a test), `wait` seconds from now (the line's own wait).
function S:_celebrate(kind,rec,wait,only)
 local remote=self.Remote;if not remote then return end
 local function fire()
  if self.Dead then return end
  for _,p in ipairs(Players:GetPlayers())do
   if not only or p==only then pcall(function()remote:FireClient(p,{Kind=kind,Name=rec.Name})end)end
  end
 end
 if type(wait)=='number'and wait>0 then task.delay(wait,fire)else fire()end
end
-- Shared store -----------------------------------------------------------------------------------------------------------------------------------------------
-- (R153: the shared store is BIGGEST FRUIT's alone: everything below reads, writes and merges the fruit. BEST PULL never comes through here.)
function S:_preview()return self.DayOffset~=0 end
-- Merges a store document into the board; refreshes what changed. Returns true when something did.
function S:_merge(doc)
 local changed=false
 if self.Board:MergeRemote('Fruit',doc.fruit)then changed=true end
 self:_refresh('Fruit')
 return changed
end
function S:_poll()
 if self:_preview()then return false end
 local now=self.Clock()
 self.NextPoll=now+Rules.PollSeconds+self.Random:NextNumber()*Rules.PollJitter
 local ok,doc=self.Store:Read(self.Board.Day)
 self.LastPoll={At=now,Ok=ok}
 if not ok then return false end
 self:_merge(doc)
 return true
end
function S:_needsWrite()
 local now=self.Clock()
 for _,kind in ipairs(SHARED)do if self.Board:Unsynced(kind)and now>=self.Blocked[kind]then return true end end
 return false
end
-- Writes this server's better records (one per shared board, compare-and-set) and takes in the answer.
function S:_push()
 if self:_preview()then return false end
 local now=self.Clock();self.NextWrite=now+Rules.WriteGap
 local wrote=false
 for _,kind in ipairs(SHARED)do
  if self.Board:Unsynced(kind)and now>=self.Blocked[kind]then
   local rec=self.Board:LocalBest(kind)
   local ok,doc,_,foreign=self.Store:Merge(self.Board.Day,kind,rec,self.Board.FruitId)
   if not ok then return wrote end -- (the store backs off; the record stays Unsynced and goes out when it can)
   wrote=true
   if foreign then self.Board:SetForeign(kind) -- (R152: the shared fruit is another plant list's: this board stays on this server, no read-back needed)
   elseif doc then self:_merge(doc)
   else -- someone else's record is better: read it (or, if that fails too, wait a poll before offering again)
    local readOk,fresh=self.Store:Read(self.Board.Day)
    if readOk then self:_merge(fresh)else self.Blocked[kind]=now+Rules.PollSeconds end
   end
   -- R152: a board that a write did not settle waits a poll before it tries again, so one board can never spend the request budget the other needs
   if self.Board:Unsynced(kind)then self.Blocked[kind]=now+Rules.PollSeconds end
  end
 end
 return wrote
end
-- One pass of the loop (the tests call it with a fake clock): the day, the pull window, a due write, a due read.
function S:Step()
 if self.Dead then return end
 self:_syncDay()
 self:_syncWindow() -- (R153: before the preview check: the pull board has nothing to do with a previewed day)
 if self:_preview()then return end
 local now=self.Clock()
 if now>=self.NextWrite and self:_needsWrite()then guard('write',self._push,self)end
 if now>=self.NextPoll then guard('poll',self._poll,self)end
end
-- Start ------------------------------------------------------------------------------------------------------------------------------------------------------
function S:_floorTop()
 local root=self.Map and self.Map.MapRoot
 local lobby=root and root:FindFirstChild('Lobby');local floor=lobby and lobby:FindFirstChild('LobbyFloor')
 if floor and floor:IsA('BasePart')then return floor.Position.Y+floor.Size.Y/2 end
 return Rules.Layout.FloorTop
end
function S:Start()
 if self.Started then return self end
 self.Started=true
 local root=self.Map and self.Map.MapRoot or workspace:FindFirstChild('ChestChaseMap')
 if not root then warn('[R151] Hub displays: the map is missing; nothing was built.');return self end
 local old=root:FindFirstChild('HubDisplays151');if old then old:Destroy()end
 local folder=Instance.new('Folder');folder.Name='HubDisplays151';folder.Parent=root
 self.Folder=folder
 local top=self:_floorTop()
 for _,kind in ipairs(KINDS)do
  local ok,d=pcall(self.Art.BuildFrame,folder,kind,Rules.Layout,top)
  if ok then self.Displays[kind]=d else warn('[R151] Hub display '..kind..' could not be built: '..tostring(d))end
 end
 local remotes=RS:FindFirstChild('ChestChaseRemotes')
 if remotes then
  local remote=remotes:FindFirstChild(S.RemoteName)
  if not remote then remote=Instance.new('RemoteEvent');remote.Name=S.RemoteName;remote.Parent=remotes end
  self.Remote=remote
  -- R153: the clients' dance reports (for the owner's status line only)
  local report=remotes:FindFirstChild(Rules.ReportRemote)
  if not report then report=Instance.new('RemoteEvent');report.Name=Rules.ReportRemote;report.Parent=remotes end
  self.ReportRemote=report
  pcall(function()self.ReportConnection=report.OnServerEvent:Connect(function(player,info)if not self.Dead then pcall(self.NoteReport,self,player,info)end end)end)
 end
 self.NextPoll=self.Clock()+Rules.FirstPollDelay
 self:_syncDay() -- (the first day: sets the fruit board up and shows its display)
 self:_syncWindow() -- (R153: the first window: shows the pull display, empty)
 if not self.Opts.NoLoop then
  -- R153 (review hardening): one bad value in a pass (the sleep, the day, the pull window, a display) is warned and the next pass still runs; the loop is what moves the BEST PULL window
  -- on and the shared boards, so it must never end. A failed pass waits a few seconds so a value that stays bad can't spin; the warning repeats now and then, not every pass.
  task.spawn(function()
   local failures=0
   while not self.Dead do
    local ok,err=pcall(function()
     task.wait(self:SleepSeconds())
     if self.Dead then return end
     self:Step()
    end)
    if not ok then
     failures+=1
     if failures==1 or failures%12==0 then warn('[R153] Hub displays: a loop pass failed ('..failures..' so far; it keeps going): '..tostring(err))end
     task.wait(5)
    end
   end
  end)
 end
 return self
end
function S:Destroy()
 self.Dead=true
 if self.ReportConnection then pcall(function()self.ReportConnection:Disconnect()end);self.ReportConnection=nil end
 if self.Folder then self.Folder:Destroy();self.Folder=nil end
end
-- Owner tools (OwnerUpdateCommands82) ------------------------------------------------------------------------------------------------------------------------
local function norm(s)return tostring(s or''):lower():gsub('[^%w]','')end
-- A seed by id or by name ("FirePepperSeed", "fire pepper"): its design, or nil.
function S:FindSeed(query)
 local q=norm(query);if q==''then return nil end
 local names=require(RS:WaitForChild('GardenDisplayNames'))
 for _,spec in ipairs(PackRules.SeedDesigns)do
  if norm(spec.id)==q or norm(spec.name)==q or norm(names.Plant(spec.id,spec.name))==q then return spec end
 end
 return nil
end
-- A test pull for `player` (nobody opened a pack): the seed's chance (which ranks it) is its odds in its biome's Pack03 (Verity: the Verity pack); the words say its fixed 1/N (R153). Shown on this
-- server only, and only until this window ends (R153: BEST PULL is never shared, so there is no `share` for it any more).
function S:InjectPull(player,seedQuery)
 local spec=self:FindSeed(seedQuery)
 if not spec then return false,'Unknown seed. Use a seed id or plant name (/test catalog lists them).'end
 self:_syncWindow()
 local rarity=PackRules.SeedRarityById[spec.id]or spec.rarity
 local odds
 pcall(function()
  local variant=spec.stage==9 and'VerityReliquary'or spec.stage==8 and'MechLimited'or'Pack03'
  local stage=spec.stage==9 and 7 or spec.stage
  odds=PackRules.SeedOdds(self.Config,stage,variant,1,PackRules.OddsVersion)[spec.id]
 end)
 if type(odds)~='number'or odds<=0 then local style=PackRules.Rarities[rarity];odds=style and style.Weight or 1 end
 local rec=Rules.CleanPull({Uid=player.UserId,Name=player.DisplayName,Id=spec.id,Seed=Rules.SeedLabel(spec.id,spec.name),Rarity=rarity,Odds=odds,Scale=1,Coat='None',At=self:Now(),Test=true})
 if not rec then return false,'Could not make that pull.'end
 local ok,result=self:_event('Pull',rec,{Player=player,Injected=true})
 if not ok then return false,'Not better than what this server already holds in this window.'end
 return true,('%s: %s %s, %s (this server only, until the board resets in %s)'):format(player.Name,rec.Rarity,rec.Seed,Rules.PullOddsText(rec),Rules.WindowCountdown(Rules.PullSecondsLeft(self.Time())))..(result=='took'and''or' - recorded, but someone\'s is better')
end
-- A test fruit of today's type weighing `kg` (the size is kg over the plant's base weight; the fruit size limit is 50). coat: 'Gold' | 'Diamond' | nil.
function S:InjectFruit(player,kg,coat,share)
 self:_syncDay()
 local id=self.Board.FruitId;if not id then return false,'There is no fruit of the day (the rotation list is empty).'end
 kg=tonumber(kg);if not kg or kg~=kg or kg<=0 or kg>1e6 then return false,'Use bigfruit <kg> (a number above 0).'end
 local base=require(RS:WaitForChild('ItemWeight')).Base('Fruit',id)
 local scale=math.clamp(kg/base,.35,50)
 local rec=Rules.CleanFruit({Uid=player.UserId,Name=player.DisplayName,Id=id,Scale=scale,Coat=coat or'None',Weather='None',At=self:Now(),Test=not share})
 if not rec then return false,'Could not make that fruit.'end
 local ok,result=self:_event('Fruit',rec,{Player=player,Injected=true})
 if not ok then return false,'Not heavier than what this server already holds for today.'end
 return true,('%s: %s %s, %s%s'):format(player.Name,rec.Coat~='None'and rec.Coat..' 'or'',self:FruitName(id),Rules.KgText(rec.Kg),share and' (shared)'or' (this server only)')..(result=='took'and''or' - recorded, but someone\'s is heavier')
end
-- Clears the boards on this server (R153: BEST PULL's is this server's alone, so that is all there is to it) and, unless previewing another day, the fruit's shared document (every other server
-- still holds its own best fruit and writes it back at its next step: reset them too, or restart them).
function S:Reset()
 self.Board:Clear();self.Shown={Pull=nil,Fruit=nil}
 self.Tainted=setmetatable({},{__mode='k'})
 local removed
 if not self:_preview()then removed=self.Store:Remove(self.Board.Day)end
 for _,kind in ipairs(KINDS)do self:_refresh(kind,true)end
 return removed
end
-- Previews another day on this server only: `offset` days from today (0 = back to today). No shared reads or writes while it is not 0.
function S:SetDayOffset(offset)
 self.DayOffset=math.clamp(math.floor(tonumber(offset)or 0),-400,400)
 self.Shown.Fruit=nil -- (R153: BEST PULL does not care which day is previewed: its board and its window stay)
 self.Board.Day=nil;self.Board.FruitId=nil
 self:_syncDay()
 return self.DayOffset
end
-- The state, for `/test hubdisplays` and the tests.
function S:Snapshot()
 local real=math.floor(self.Time())
 local out={Day=self.Board.Day,FruitId=self.Board.FruitId,DayOffset=self.DayOffset,Rev=table.clone(self.Rev),Store=self.Store:Status(),Window=self.Board.Window,PullSecondsLeft=Rules.PullSecondsLeft(real)}
 for _,kind in ipairs(KINDS)do
  local rec,source=self.Board:Best(kind)
  out[kind]={Record=rec,Source=source,Unsynced=self.Board:Unsynced(kind),Events=self.Events[kind]}
 end
 return out
end
function S:StatusText(player) -- (player: the owner who asked; their own screen's dance is told)
 local snap=self:Snapshot();local lines={}
 local fruit=snap.FruitId and self:FruitName(snap.FruitId)or'(none)'
 lines[#lines+1]=('Day %s%s | fruit of the day: %s | new fruit in %s'):format(tostring(snap.Day),snap.DayOffset~=0 and(' (preview '..string.format('%+d',snap.DayOffset)..')')or'',fruit,Rules.Countdown(Rules.SecondsLeft(self:Now())))
 local p=snap.Pull
 -- R153: BEST PULL is this server's alone and lasts one 10-minute window (the real clock, whatever day is previewed)
 local windowText=('this server only | new board in %s'):format(Rules.WindowCountdown(snap.PullSecondsLeft))
 lines[#lines+1]=p.Record and('BEST PULL: %s - %s %s, %s (%s) | %s'):format(p.Record.Name,p.Record.Rarity,p.Record.Seed,Rules.PullOddsText(p.Record),p.Source,windowText)or('BEST PULL: nobody yet | '..windowText)
 local f=snap.Fruit
 lines[#lines+1]=f.Record and('BIGGEST FRUIT: %s - %s%s (%s%s%s)'):format(f.Record.Name,Rules.KgText(f.Record.Kg),f.Record.Coat~='None'and(' '..f.Record.Coat)or'',f.Source,f.Unsynced and', not shared yet'or'',self.Board.Boards.Fruit.Foreign and', not shared: other servers have another fruit today'or'')or'BIGGEST FRUIT: nobody yet'
 local st=snap.Store
 lines[#lines+1]=self:_preview()and'Shared board: off while previewing another day'
  or('Shared board (BIGGEST FRUIT only): %s, %d request%s, %s'):format(st.Failures==0 and'ok'or('FAILING x'..st.Failures..(st.Throttled and' (throttled)'or'')),st.Requests,st.Requests==1 and''or's',st.LastError and('last error: '..st.LastError..'; retry in '..math.ceil(st.RetryIn)..' s')or(st.LastOk and'last ok'or'not read yet'))
 for _,kind in ipairs(KINDS)do
  local d=self.Displays[kind]
  if d then local n=self.Art.Counts(d);lines[#lines+1]=('%s display: %d pedestal parts, %d item parts, %d avatar parts (%s) | %s'):format(kind,n.Frame,n.Item,n.Avatar,tostring(self.AvatarSource and self.AvatarSource[kind]or'-'),self:_danceText(kind,typeof(player)=='Instance'and player or nil))end
 end
 return table.concat(lines,'\n')
end
return S
