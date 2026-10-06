-- R151 (owner: "best pull today" and "biggest fruit" displays in the hub's two empty corners, across all servers, with the champion's avatar beside a giant model):
-- the server half. What it does:
--  * Counts every real thing the server decides: a pack opened (PlayerDataService:OpenSeedPack calls NotePull with the reward and the pack it came from) and a fruit
--    picked by hand (ChestService's garden Harvest calls NoteHarvest). Not counted: TEST packs (/test rarepacks), anything an owner command just gave that player
--    (NoteOwnerGrant: the rest of that session; R152: and for good, what carries TestGrant: packs, seeds and the plants grown from them, pulls with owner-given boots), the owner's injected test pulls / fruit (they only ever show on this server).
--  * Keeps this server's view of today's two boards (HubDisplayBoard): the shared store's best (Remote), this server's own best (Local) and an injected one (Test). The
--    displays always show the best of the three. Everything an event does here is instant and local; the shared store (HubDisplayStore, MemoryStore) is written about 3 s
--    later (compare-and-set: only if better) and read about once a minute (45 s + 0..15 s of jitter), so the other servers' champions arrive within a minute. If the store
--    fails the server keeps its own board and keeps trying (the store backs off; see HubDisplayStore).
--  * Shows them: HubDisplayArt builds the two pedestals (the Fruit of the Hour's, bigger) in the hub's empty back corners; on a change this writes the words, the colours, a new showcase item
--    and the champion's avatar (HubDisplayAvatar: 25 studs tall, dancing: Animate), each built once per champion (a generation number drops a build that a newer champion overtook), and bumps the display's `Rev` attribute so every
--    client pops it. When someone takes the top spot in THIS server it is announced in CHAT, through PullAnnouncer.Announce({Kind='Record', ...}) (the owner: pull announcements
--    only in chat): who hears it is PullAnnounceRules.RecordScope (a Secret+ best pull every server, Legendary / Mythic this server, lower nothing; a fruit record this server);
--    a record that comes from a pack open waits until the puller's reveal has shown the seed (AfterReveal), like the pull line; there is no notice banner of its own any more (it
--    would be a second message). The celebration chime (a Remote the client plays GemClaim for) goes out in step with the line. An owner's test (bestpull / bigfruit) is told to its
--    target only, and nothing is announced while previewing another day.
--  * UTC midnight (the daily rewards' day) clears both boards; the fruit of the day is HubDisplayRules.FruitForDay.
-- No per-frame work: one loop wakes every 5 s, does a few integer comparisons, and only touches MemoryStore when a timer is due.
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
  NextPoll=0,NextWrite=0,Blocked={Pull=0,Fruit=0},LastNotice={Pull=-1e9,Fruit=-1e9},Events={Pull=0,Fruit=0},Dead=false,Built={Pull=nil,Fruit=nil},
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
-- Moves to today if the UTC day (or the preview offset) changed: both boards start empty, the fruit of the day is picked. Returns true when it changed.
function S:_syncDay()
 local day=self:Day();local fruit=self:FruitId(day)
 if not self.Board:SetDay(day,fruit)then return false end
 self.Shown={Pull=nil,Fruit=nil}
 self.NextPoll=self.Clock() -- (read the shared board for the new day at the next step)
 self.Blocked={Pull=0,Fruit=0}
 for _,kind in ipairs(KINDS)do self:_refresh(kind)end
 return true
end
-- Showing --------------------------------------------------------------------------------------------------------------------------------------------------
-- The display of a board shows its champion (or the empty state). Does nothing when what it shows is already right. The words and colours change at once; the showcase item and
-- the avatar are built in a task of their own (yields: meshes, the avatar service, the dance loading) and dropped if a newer champion arrived meanwhile.
function S:_refresh(kind,force)
 local d=self.Displays[kind];if not d then return false end
 local rec=self.Board:Best(kind)
 local fruitId=self.Board.FruitId
 local key=Rules.Key(rec)..'|'..tostring(kind=='Fruit'and fruitId or'')..'|'..tostring(self.Board.Day)
 if key==self.Shown[kind]and not force then return false end
 self.Shown[kind]=key
 self.Gen[kind]+=1;local gen=self.Gen[kind]
 local now=self:Now()
 local text=Rules.SignText(kind,rec,fruitId,Rules.SecondsLeft(now),kind=='Fruit'and fruitId and self:FruitName(fruitId)or nil)
 if kind=='Fruit'and fruitId then text.Accent=Rules.RarityColor(PackRules.SeedRarityById[fruitId]or'Common')end
 guard('sign',self.Art.SetSign,d,text)
 local calm=kind=='Pull'and rec==nil
 guard('tint',self.Art.Tint,d,text.Accent,calm and'Empty'or'Ready')
 local m=d.Model
 m:SetAttribute('FooterPrefix',kind=='Pull'and'New board in 'or'New fruit in ')
 m:SetAttribute('NextAt',Rules.NextAt(self.Board.Day or Rules.Day(now))-self.DayOffset*86400)
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
 -- the avatar: the champion's, or a black silhouette while nobody holds the spot
 local avatar,source
 if rec then avatar,source=self.Avatars:Build(rec.Uid)else avatar,source=self.Avatars:Build(0,{Silhouette=true})end
 if self:_stale(kind,gen)then if avatar then avatar:Destroy()end;return end
 local mode='static'
 if avatar then
  local placed=self.Avatars:Place(avatar,d.FeetAt,Rules.AvatarHeight,Rules.AvatarTurn)
  if placed then
   self.Art.SetAvatar(d,avatar)
   -- in the world now: dance (the rig's Animator plays a default R15 dance; if it cannot, the static pose goes on instead). This waits for the dance to load, so look again afterwards.
   if self.Avatars.Animate then
    local okAnimate,result=pcall(self.Avatars.Animate,self.Avatars,avatar,rec and rec.Uid or 0)
    if okAnimate then mode=result else warn('[R151] avatar animation: '..tostring(result))end
   end
   if self:_stale(kind,gen)then return end
  else avatar:Destroy();self.Art.SetAvatar(d,nil)end
 end
 self.AvatarSource=self.AvatarSource or{};self.AvatarSource[kind]=source
 self.AvatarMode=self.AvatarMode or{};self.AvatarMode[kind]=mode
 d.Model:SetAttribute('Built',(d.Model:GetAttribute('Built')or 0)+1)
end
-- Events -----------------------------------------------------------------------------------------------------------------------------------------------------
-- An owner command just gave this player packs / seeds / plants: what they open or pick for the rest of this session is not counted.
function S:NoteOwnerGrant(player)if player then self.Tainted[player]=true end end
local function wholeNumber(n)return type(n)=='number'and n==n and n%1==0 end
-- A pack was opened: reward = the record OpenSeedPack made (SeedId, SeedName, Rarity, SeedScale, PackMutation), info = {Stage, Variant, Version, Boost, Luck, Test} of the PACK it
-- came from (Test = a guaranteed TEST reveal, an owner-made TestGrant pack, or luck from owner-given boots: R152). Never throws, never yields. Returns true when the pull was counted.
function S:NotePull(player,reward,info)
 if self.Dead or type(reward)~='table'or typeof(player)~='Instance'then return false end
 info=type(info)=='table'and info or{}
 if info.Test==true then return false,'test pack'end
 if self.Tainted[player]then return false,'owner-granted'end
 self:_syncDay()
 local odds
 local ok,table_=pcall(PackRules.SeedOdds,self.Config,info.Stage,info.Variant,info.Luck,info.Version,info.Boost)
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
function S:_preview()return self.DayOffset~=0 end
-- Merges a store document into the board; refreshes what changed. Returns true when something did.
function S:_merge(doc)
 local changed=false
 if self.Board:MergeRemote('Pull',doc.pull)then changed=true end
 if self.Board:MergeRemote('Fruit',doc.fruit)then changed=true end
 for _,kind in ipairs(KINDS)do self:_refresh(kind)end
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
 for _,kind in ipairs(KINDS)do if self.Board:Unsynced(kind)and now>=self.Blocked[kind]then return true end end
 return false
end
-- Writes this server's better records (one per board, compare-and-set) and takes in the answer.
function S:_push()
 if self:_preview()then return false end
 local now=self.Clock();self.NextWrite=now+Rules.WriteGap
 local wrote=false
 for _,kind in ipairs(KINDS)do
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
-- One pass of the loop (the tests call it with a fake clock): the day, a due write, a due read.
function S:Step()
 if self.Dead then return end
 self:_syncDay()
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
 end
 self.NextPoll=self.Clock()+Rules.FirstPollDelay
 self:_syncDay() -- (the first day: sets the boards up and shows both displays)
 if not self.Opts.NoLoop then
  task.spawn(function()
   while not self.Dead do
    task.wait(S.LoopSeconds)
    if self.Dead then break end
    self:Step()
   end
  end)
 end
 return self
end
function S:Destroy()
 self.Dead=true
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
-- A test pull for `player` (nobody opened a pack): the seed's chance is its odds in its biome's Pack03 (Verity: the Verity pack). Shown on this server only unless
-- share = true (then it is written to the shared store like a real one: use it to test MemoryStore, and `hubdisplays reset` afterwards).
function S:InjectPull(player,seedQuery,share)
 local spec=self:FindSeed(seedQuery)
 if not spec then return false,'Unknown seed. Use a seed id or plant name (/test catalog lists them).'end
 self:_syncDay()
 local rarity=PackRules.SeedRarityById[spec.id]or spec.rarity
 local odds
 pcall(function()
  local variant=spec.stage==9 and'VerityReliquary'or spec.stage==8 and'MechLimited'or'Pack03'
  local stage=spec.stage==9 and 7 or spec.stage
  odds=PackRules.SeedOdds(self.Config,stage,variant,1,PackRules.OddsVersion)[spec.id]
 end)
 if type(odds)~='number'or odds<=0 then local style=PackRules.Rarities[rarity];odds=style and style.Weight or 1 end
 local rec=Rules.CleanPull({Uid=player.UserId,Name=player.DisplayName,Id=spec.id,Seed=Rules.SeedLabel(spec.id,spec.name),Rarity=rarity,Odds=odds,Scale=1,Coat='None',At=self:Now(),Test=not share})
 if not rec then return false,'Could not make that pull.'end
 local ok,result=self:_event('Pull',rec,{Player=player,Injected=true})
 if not ok then return false,'Not better than what this server already holds for today.'end
 return true,('%s: %s %s, %s%s'):format(player.Name,rec.Rarity,rec.Seed,Rules.OddsText(rec.Odds),share and' (shared)'or' (this server only)')..(result=='took'and''or' - recorded, but someone\'s is better')
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
-- Clears today's boards on this server and, unless previewing another day, the shared document (every other server still holds its own best and writes it back at its next
-- step: reset them too, or restart them).
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
 self.Shown={Pull=nil,Fruit=nil}
 self.Board.Day=nil;self.Board.FruitId=nil
 self:_syncDay()
 return self.DayOffset
end
-- The state, for `/test hubdisplays` and the tests.
function S:Snapshot()
 local out={Day=self.Board.Day,FruitId=self.Board.FruitId,DayOffset=self.DayOffset,Rev=table.clone(self.Rev),Store=self.Store:Status()}
 for _,kind in ipairs(KINDS)do
  local rec,source=self.Board:Best(kind)
  out[kind]={Record=rec,Source=source,Unsynced=self.Board:Unsynced(kind),Events=self.Events[kind]}
 end
 return out
end
function S:StatusText()
 local snap=self:Snapshot();local lines={}
 local fruit=snap.FruitId and self:FruitName(snap.FruitId)or'(none)'
 lines[#lines+1]=('Day %s%s | fruit of the day: %s | new board in %s'):format(tostring(snap.Day),snap.DayOffset~=0 and(' (preview '..string.format('%+d',snap.DayOffset)..')')or'',fruit,Rules.Countdown(Rules.SecondsLeft(self:Now())))
 local p=snap.Pull
 lines[#lines+1]=p.Record and('BEST PULL: %s - %s %s, %s (%s%s)'):format(p.Record.Name,p.Record.Rarity,p.Record.Seed,Rules.OddsText(p.Record.Odds),p.Source,p.Unsynced and', not shared yet'or'')or'BEST PULL: nobody yet'
 local f=snap.Fruit
 lines[#lines+1]=f.Record and('BIGGEST FRUIT: %s - %s%s (%s%s%s)'):format(f.Record.Name,Rules.KgText(f.Record.Kg),f.Record.Coat~='None'and(' '..f.Record.Coat)or'',f.Source,f.Unsynced and', not shared yet'or'',self.Board.Boards.Fruit.Foreign and', not shared: other servers have another fruit today'or'')or'BIGGEST FRUIT: nobody yet'
 local st=snap.Store
 lines[#lines+1]=self:_preview()and'Shared board: off while previewing another day'
  or('Shared board: %s, %d request%s, %s'):format(st.Failures==0 and'ok'or('FAILING x'..st.Failures..(st.Throttled and' (throttled)'or'')),st.Requests,st.Requests==1 and''or's',st.LastError and('last error: '..st.LastError..'; retry in '..math.ceil(st.RetryIn)..' s')or(st.LastOk and'last ok'or'not read yet'))
 for _,kind in ipairs(KINDS)do
  local d=self.Displays[kind]
  if d then local n=self.Art.Counts(d);lines[#lines+1]=('%s display: %d pedestal parts, %d item parts, %d avatar parts (%s, %s)'):format(kind,n.Frame,n.Item,n.Avatar,tostring(self.AvatarSource and self.AvatarSource[kind]or'-'),tostring(self.AvatarMode and self.AvatarMode[kind]or'-'))end
 end
 return table.concat(lines,'\n')
end
return S
