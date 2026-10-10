-- R151 (owner: "serverwide messages saying who pulled what and so on and a in server announcement"; then: "pull announcement should only be said in chat"): pull announcements,
-- the SERVER half. They are CHAT LINES only (PullAnnouncerClient writes them; no banner). Only this module decides that something is announced; clients never ask for one
-- (the remote below is server -> client only), display names come from Roblox (already filtered, and cleaned again in PullAnnounceRules.Clean) and no player-typed text is
-- ever sent.
--  * A real pack open (PlayerDataService:OpenSeedPack calls OnOpened) whose seed is at least InServerMinRarity (Legendary) is sent to everyone in THIS server once the
--    PULLER's reveal has shown the seed (ALL players get it then: the puller's own line must not come before their reveal shows it, and one rule for everybody is simpler than
--    two). "Shown" is the climax / seed-landing of their cinematic plus a small margin: PullAnnounceRules.RevealDelay, derived from RarePullRules, the very tables the puller's
--    client plays (Secret / Cosmic / King story scenes, the Common..Mythic seed card), whichever presentation their client picks. A skipped reveal shows the seed sooner, so the
--    line still goes out at that normal time (clients never tell the server anything: a client-claimed skip would be input we cannot trust, and it could only make the line late
--    by a few seconds, never early). If the puller LEAVES before then, nobody's reveal is left to spoil: it goes out at once (a server closing with its last player keeps it).
--    Never announced: a pack an owner / admin command created (marked TestGrant=true on the pack record when it was made: /test pack, packset, void, verity,
--    rarepacks, and the packs that mystery / daily / bonus commands cause), a TEST guaranteed reveal (/test rarepacks), a seed that was given or granted and anything that
--    is not a pack open. Real purchases (Robux Mech / Verity packs) and normal gameplay packs are announced.
--  * At least GlobalMinRarity (Secret: Secret, Cosmic, King and above) it is also published to the OTHER servers through MessagingService (topic
--    PullAnnounce151), at the same moment (after the puller's reveal), never earlier. Publishing is limited to one message per PublishGapSeconds per server (pulls wait and travel together, 1 kB at most, a failed publish
--    is retried a few times while it is still fresh). A receiving server drops its own messages (the origin shows the in-server version), repeats, anything
--    older than StaleSeconds and anything over its per-minute limit, re-derives the rarity from its own seed catalog, and only sends it on to players who
--    have "Announcements from other servers" on (SettingsConfig.GlobalAnnouncements: it gates the 🌐 chat lines). The subscription is retried until it works.
--  * PullAnnouncer.Announce({Kind='Record', Player=player, Record='BestPull', SeedId=.., AfterReveal=true}) writes a record line ("🏆 Name took BEST PULL!"): the hook
--    HubDisplayService uses when someone takes over a hub board (its own notice is gone: one message, in chat). Record keys are letters only; the title comes from
--    PullAnnounceRules.Records. WHO hears it is PullAnnounceRules.RecordScope: this server (R153: never another one; BEST PULL is this server's own board, emptied every 10 minutes, so a
--    record line is this server's too: a BestPull of Legendary or above, Secret and up included; a lower one: nobody; BiggestFruit: this server), unless the caller passes Scope (a BestPull
--    cannot be sent to other servers whatever the caller says). AfterReveal=true (the record comes from a pack open) waits like the pull line does, plus RecordLag so the pull line
--    comes first. To=player makes the line private (the owner's bestpull / bigfruit tests: only their target sees it, never the server and never other servers).
--  * Owner test: /test announce <seed> [@name], /test announce global <seed> [here] and /test announce record [bestpull|biggestfruit] [seed] (these ARE announcements on
--    purpose: they exist to look at the chat lines, at once, and a record here stays in this server).
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Rules=require(RS:WaitForChild('PullAnnounceRules'))
local Packs=require(RS:WaitForChild('SeedPackRules'))
local Names=require(RS:WaitForChild('GardenDisplayNames'))
local A={};A.__index=A
A.MaxAttempts=3 -- publishes of one global pull (the first and two retries)
A.MaxLiveSubscribeFailures=1000

local function guid(http)
 local ok,id=pcall(function()return http:GenerateGUID(false)end)
 return ok and type(id)=='string'and id or tostring(os.time())..'-'..tostring(math.random(1,1e9))
end
-- opts (all optional, for tests): Data, Players, Http, Messaging, Remote, Clock (seconds, monotonic), Time (unix seconds), JobId, Warn.
function A.new(opts)
 opts=opts or{}
 local self=setmetatable({},A)
 self.Data=opts.Data;self.Players=opts.Players or Players
 self.Http=opts.Http or game:GetService('HttpService')
 self.Clock=opts.Clock or os.clock;self.Time=opts.Time or os.time
 self.Warn=opts.Warn or warn
 local job=opts.JobId or game.JobId
 self.JobId=(type(job)=='string'and job~='')and job or guid(self.Http) -- Studio has no JobId: a random one, so two test sessions can see each other
 self.Short=tostring(self.JobId):gsub('[^%w]',''):sub(1,8)
 self.Serial=0
 self.Pending={};self.LastPublish=-math.huge;self.Timer=false;self.Publishing=false
 self.Waiting={} -- lines waiting for a puller's reveal: {Player, Done, Go}
 self.Seen={};self.SeenOrder={};self.Received={}
 self.Stats={Published=0,PublishFailed=0,Dropped=0,Received=0,Shown=0,SubscribeFailed=0,Origin=0,Stale=0,Repeat=0,Limited=0,Bad=0}
 if opts.Remote then self.Remote=opts.Remote
 else
  local folder=RS:FindFirstChild('ChestChaseRemotes')
  if not folder then folder=Instance.new('Folder');folder.Name='ChestChaseRemotes';folder.Parent=RS end
  local remote=folder:FindFirstChild(Rules.RemoteName)
  if not remote then remote=Instance.new('RemoteEvent');remote.Name=Rules.RemoteName;remote.Parent=folder end
  self.Remote=remote
 end
 self.Messaging=opts.Messaging
 return self
end
function A:_id()self.Serial+=1;return self.Short..'-'..self.Serial end

-- Odds ----------------------------------------------------------------------------------------------------------------------------------------
-- The chance (the N of "1/N") shown for this seed. R153 (owner: a Cosmic from a Void pack must still read how rare it is): the seed's ONE fixed chance (SeedRarity153: its home
-- pack, no boots, no boost), the same in the Index, on the reveal card and on the hub plaque, never the pack it came from; nil when it cannot be told. (config, player and pack
-- stay in the signature for the callers and are not read.)
function A.OddsOf(config,player,pack,seedId)
 local ok,n=pcall(function()return require(RS:FindFirstChild('SeedRarity153')).Canonical(seedId)end) -- (never yields: the open that announces it must not wait)
 if not ok or type(n)~='number'or n~=n or n<1 then return nil end
 return n
end

-- Sending to this server's players -------------------------------------------------------------------------------------------------------------------
local function wire(e)
 return {Kind=e.Kind,Id=e.Id,UserId=e.UserId,Name=e.Name,SeedId=e.SeedId,Odds=e.Odds,Record=e.Record,At=e.At}
end
-- Everyone in this server (a pull here, a record). wants = optional per-player filter.
function A:_broadcast(e,wants)
 local payload=wire(e);local sent=0
 for _,p in ipairs(self.Players:GetPlayers())do
  if not wants or wants(p)then
   if pcall(self.Remote.FireClient,self.Remote,p,payload)then sent+=1 end
  end
 end
 self.Stats.Shown+=1
 return sent
end
-- True when this player takes announcements from other servers (the saved toggle; on by default; nobody is sent anything before their data loads).
function A:_wants(player)
 local data=self.Data;if not data then return true end
 local ok,wanted=pcall(function()
  if data.IsLoaded and not data:IsLoaded(player)then return false end
  local premium=data:GetPremium(player);local settings=premium and premium.Settings
  return not(type(settings)=='table'and settings.GlobalAnnouncements==false)
 end)
 return ok and wanted==true
end

-- Publishing ------------------------------------------------------------------------------------------------------------------------------------
function A:_messaging()
 if self.Messaging then return self.Messaging end
 local ok,service=pcall(function()return game:GetService('MessagingService')end)
 if ok then self.Messaging=service end
 return self.Messaging
end
-- Queues a pull for the other servers (it goes out with the next publish).
function A:_queue(e)
 for _,item in ipairs(self.Pending)do if item.Event.Id==e.Id then return end end
 if#self.Pending>=Rules.Setting('MaxPending')then table.remove(self.Pending,1);self.Stats.Dropped+=1 end
 table.insert(self.Pending,{Event=e,Attempts=0,At=self.Time()})
 self:_schedule()
end
function A:_schedule()
 if#self.Pending==0 or self.Timer or self.Publishing then return end
 local wait=Rules.Setting('PublishGapSeconds')-(self.Clock()-self.LastPublish)
 if wait<=0 then self:_flush()
 else self.Timer=true;task.delay(wait,function()self.Timer=false;self:_flush()end)end
end
function A:_flush()
 if self.Publishing then return end
 -- pulls that waited too long are not worth sending any more
 local now=self.Time();local stale=Rules.Setting('StaleSeconds')
 for i=#self.Pending,1,-1 do if now-self.Pending[i].At>stale then table.remove(self.Pending,i);self.Stats.Dropped+=1 end end
 if#self.Pending==0 then return end
 local service=self:_messaging()
 local events={};for i,item in ipairs(self.Pending)do events[i]=item.Event end
 local encode=function(t)return self.Http:JSONEncode(t)end
 local text,count=Rules.Batch(events,self.JobId,now,encode)
 if count==0 or not text then -- one pull alone does not fit: it can never be sent
  table.remove(self.Pending,1);self.Stats.Dropped+=1;return self:_schedule()
 end
 local batch={};for _=1,count do table.insert(batch,table.remove(self.Pending,1))end
 self.LastPublish=self.Clock();self.Publishing=true
 task.spawn(function()
  local ok,err=false,'MessagingService is not available'
  if service then ok,err=pcall(service.PublishAsync,service,Rules.Topic,text)end
  self.Publishing=false
  if ok then
   self.Stats.Published+=1
  else
   self.Stats.PublishFailed+=1
   if self.Stats.PublishFailed%10==1 then self.Warn('[R151] Could not publish a pull announcement: '..tostring(err))end
   for i=#batch,1,-1 do -- put them back (in order) for another try while there are attempts left
    local item=batch[i];item.Attempts+=1
    if item.Attempts<A.MaxAttempts then table.insert(self.Pending,1,item)else self.Stats.Dropped+=1 end
   end
  end
  self:_schedule()
 end)
end

-- Receiving ---------------------------------------------------------------------------------------------------------------------------------------
function A:_seen(id)
 if self.Seen[id]then return true end
 self.Seen[id]=self.Clock();table.insert(self.SeenOrder,id)
 local max=Rules.Setting('SeenMax')
 while#self.SeenOrder>max do self.Seen[table.remove(self.SeenOrder,1)]=nil end
 local ttl=Rules.Setting('SeenSeconds');local now=self.Clock()
 while#self.SeenOrder>0 and now-(self.Seen[self.SeenOrder[1]]or now)>ttl do self.Seen[table.remove(self.SeenOrder,1)]=nil end
 return false
end
function A:_room()
 local now=self.Clock();local log=self.Received
 for i=#log,1,-1 do if now-log[i]>60 then table.remove(log,i)end end
 if#log>=Rules.Setting('ReceiveMaxPerMinute')then return false end
 log[#log+1]=now;return true
end
-- message = {Data=<json text or table>, Sent=<unix seconds>} from MessagingService. Everything inside is untrusted. Returns how many pulls were shown.
function A:_onMessage(message)
 local shown=0
 local ok,err=pcall(function()
  if type(message)~='table'then self.Stats.Bad+=1;return end
  local data=message.Data
  if type(data)=='string'then
   if#data>1000 then self.Stats.Bad+=1;return end
   local decoded,value=pcall(function()return self.Http:JSONDecode(data)end);data=decoded and value or nil
  end
  if type(data)~='table'or data.v~=1 or type(data.j)~='string'or#data.j>64 or type(data.p)~='table'then self.Stats.Bad+=1;return end
  if data.j==self.JobId then self.Stats.Origin+=1;return end -- this server's own pull: it showed the in-server version
  local now=self.Time()
  if not Rules.Fresh(data.t,now)or(message.Sent~=nil and not Rules.Fresh(message.Sent,now))then self.Stats.Stale+=1;return end
  for index,entry in ipairs(data.p)do
   if index>6 then break end
   local fields=Rules.Expand(entry)
   local record=fields~=nil and fields.Record~=nil -- (a hub record carries its key; a pull does not. R153: no record is for every server now, so one from an older server is dropped below)
   local e=fields and Rules.Event(record and'Record'or'Global',fields)
   -- the rarity is the one of THIS server's catalog: an unknown seed is dropped, a seed below the global threshold is dropped, and so is a record that is not for every server
   local travels=e and(record and Rules.RecordScope(e.Record,e.Rarity)=='Global'or not record and Rules.Qualifies('Global',e.Rarity))
   if not e or not e.Id or not travels then self.Stats.Bad+=1
   elseif self:_seen(data.j..':'..e.Id)then self.Stats.Repeat+=1
   elseif not self:_room()then self.Stats.Limited+=1
   else
    if not record then e.Kind='Global'end
    self.Stats.Received+=1
    self:_broadcast(e,function(p)return self:_wants(p)end);shown+=1
   end
  end
 end)
 if not ok then self.Stats.Bad+=1;self.Warn('[R151] A pull announcement message could not be read: '..tostring(err))end
 return shown
end
-- Subscribes (retried with a growing wait until it works: MessagingService can refuse in Studio, or be down for a while).
function A:_subscribe(attempt)
 if self.Stopped or self.Connection then return end
 attempt=attempt or 1
 local service=self:_messaging()
 local ok,connection=false,'MessagingService is not available'
 if service then ok,connection=pcall(service.SubscribeAsync,service,Rules.Topic,function(message)self:_onMessage(message)end)end
 if ok then self.Connection=connection;return end
 self.Stats.SubscribeFailed+=1
 if attempt==1 or attempt%10==0 then self.Warn('[R151] Pull announcements from other servers are not listening yet ('..tostring(connection)..'); retrying.')end
 if attempt>=A.MaxLiveSubscribeFailures then return end
 local wait=math.min(Rules.Setting('SubscribeRetryMax'),Rules.Setting('SubscribeRetrySeconds')*2^math.min(attempt-1,10))
 task.delay(wait,function()self:_subscribe(attempt+1)end)
end
function A:Run()
 if self.Started then return self end;self.Started=true
 task.spawn(function()self:_subscribe(1)end)
 -- a puller who leaves has no reveal left to spoil: their waiting lines go out at once
 local ok,connection=pcall(function()return self.Players.PlayerRemoving:Connect(function(player)self:_released(player)end)end)
 if ok then self.LeaveConnection=connection end
 return self
end
function A:Destroy()
 self.Stopped=true
 if self.Connection then pcall(function()self.Connection:Disconnect()end);self.Connection=nil end
 if self.LeaveConnection then pcall(function()self.LeaveConnection:Disconnect()end);self.LeaveConnection=nil end
 for entry in pairs(self.Waiting)do entry.Done=true end
 table.clear(self.Waiting);table.clear(self.Pending)
end

-- Pulls --------------------------------------------------------------------------------------------------------------------------------------------
-- Called (through PullAnnouncer.OnOpened) by PlayerDataService:OpenSeedPack right after a pack was opened and its seed saved. pack = the pack record that was opened, reward = the seed
-- record, wasTest = an owner TEST guaranteed reveal (/test rarepacks). A pack that an owner / admin command created carries TestGrant=true on its record (set when the command made it,
-- saved with the pack, kept through gifts and the Void -> Verity conversion): it is never announced either. Returns true and the seconds the line waits when something was
-- scheduled, else false and the reason.
function A:Pulled(player,pack,reward,wasTest)
 if wasTest then return false,'test pack'end
 if type(reward)~='table'or type(pack)~='table'or not player then return false,'not a pack open'end
 if pack.TestGrant==true then return false,'test pack'end
 local rarity=reward.Rarity
 local inServer,global=Rules.Qualifies('InServer',rarity),Rules.Qualifies('Global',rarity)
 if not inServer and not global then return false,'below the threshold'end
 local config=self.Data and self.Data.Config
 local odds=config and A.OddsOf(config,player,pack,reward.SeedId)
 local name=player.DisplayName;if type(name)~='string'or name==''then name=player.Name end
 local e,why=Rules.Event('Pull',{Name=name,UserId=player.UserId,Id=self:_id(),SeedId=reward.SeedId,Odds=odds,At=self.Time()})
 if not e then return false,why end
 -- the rarity read from the catalog must be the rarity that was rolled (a seed whose catalog entry differs is not announced)
 if e.Rarity~=rarity then return false,'rarity mismatch'end
 -- after the puller's reveal has shown the seed, for everybody (in the server and, publishing, the other servers): their screen is still playing it until then
 local wait=self:_afterReveal(player,rarity,0,function()
  if inServer then self:_broadcast(e)end
  if global then self:_queue(e)end
 end)
 return true,wait
end

-- Waiting for a reveal --------------------------------------------------------------------------------------------------------------------------
-- Runs fn once the puller's reveal has shown the seed: PullAnnounceRules.RevealDelay(rarity) seconds from now (plus lag). A skip changes nothing here (see the header: the seed is
-- shown sooner, so this time is still after it). If the puller leaves first (PlayerRemoving, wired in Run) fn runs at once. Returns the seconds it waits.
function A:_afterReveal(player,rarity,lag,fn)
 local wait=Rules.RevealDelay(rarity)+(tonumber(lag)or 0)
 local entry={Player=player,Done=false}
 entry.Go=function()
  if entry.Done then return end
  entry.Done=true;self.Waiting[entry]=nil
  local ok,err=pcall(fn);if not ok then self.Warn('[R151] A pull announcement could not be sent: '..tostring(err))end
 end
 self.Waiting[entry]=true
 task.delay(wait,entry.Go)
 return wait
end
-- The player is leaving: whatever waited for their reveal goes out now.
function A:_released(player)
 local due={};for entry in pairs(self.Waiting)do if entry.Player==player then due[#due+1]=entry end end
 for _,entry in ipairs(due)do entry.Go()end
end

-- Public API for other server code (the hub displays): {Kind='Record', Player=player | Name=,UserId=, Record='BestPull', SeedId=?, Odds=?, AfterReveal=?, Scope=?, To=?}.
--  * Kind='Record' goes where PullAnnounceRules.RecordScope says (this server, every server, or nobody: then false, 'below the threshold') unless Scope = 'InServer' | 'Global'.
--  * AfterReveal=true: the line comes from a pack open whose reveal is playing on the puller's screen (SeedId = the seed): it waits like the pull line (PullAnnounceRules.RevealDelay,
--    a record plus RecordLag so the pull line comes first) and goes out at once if the puller (Player) leaves first. Without it the line goes out now.
--  * To=player: only that player is told, in this server only (an owner's bestpull / bigfruit test), now.
-- Returns true and the seconds until it goes out (0 = now), or false and the reason.
function A:Send(spec)
 if type(spec)~='table'then return false,'spec'end
 local kind=spec.Kind
 if kind~='Record'and kind~='Pull'then return false,'Kind must be Record or Pull'end
 local p=spec.Player
 local name=spec.Name;local uid=spec.UserId
 if p then name=(type(p.DisplayName)=='string'and p.DisplayName~='')and p.DisplayName or p.Name;uid=p.UserId end
 local fields={Name=name,UserId=uid,Id=self:_id(),SeedId=spec.SeedId,Odds=spec.Odds,Record=spec.Record,At=self.Time()}
 local e,why=Rules.Event(kind,fields);if not e then return false,why end
 local global=false
 if kind=='Record'then
  local scope=spec.Scope
  if scope~='InServer'and scope~='Global'then scope=Rules.RecordScope(e.Record,e.Rarity)end
  if scope==nil then return false,'below the threshold'end
  global=scope=='Global'and e.Record~='BestPull' -- (R153: BEST PULL is this server's own: its line never travels, whatever Scope was asked for)
 end
 local only=spec.To
 if only then global=false end
 local function deliver()
  self:_broadcast(e,only and function(player)return player==only end or nil)
  if global then self:_queue(e)end
 end
 if spec.AfterReveal==true and not only and e.Rarity then
  return true,self:_afterReveal(p,e.Rarity,kind=='Record'and Rules.Setting('RecordLag')or 0,deliver)
 end
 deliver();return true,0
end

-- Owner test commands -------------------------------------------------------------------------------------------------------------------------------
local function key(text)return tostring(text or''):lower():gsub('[^%w]','')end
local function findSeed(query)
 query=key(query);if query==''then return nil end
 for _,spec in ipairs(Packs.SeedDesigns)do
  local id=key(spec.id)
  if query==id or query==id:gsub('seed$','')or query==key(spec.name)or query==key(Names.Plant(spec.id,spec.name))then return spec end
 end
end
local function defaultOdds(config,spec)return A.OddsOf(config,nil,nil,spec.id)end -- R153: the seed's fixed chance, as a real pull shows it
A.Usage='Use announce <seed> (a chat line for this server), announce global <seed> [here] (publish to the other servers; here also shows it in this server as an other-server pull) or announce record [bestpull|biggestfruit] [seed].'
function A:RunCommand(ctx,p,a)
 local words={};for _,w in ipairs(a or{})do words[#words+1]=tostring(w)end
 local sub=(words[1]or''):lower()
 local name=(type(p.DisplayName)=='string'and p.DisplayName~='')and p.DisplayName or p.Name
 local mode='pull'
 if sub=='global'or sub=='record'then mode=sub;table.remove(words,1)end
 if mode=='record'then
  local record='BestPull';local first=(words[1]or''):lower()
  if first=='bestpull'or first=='best'then table.remove(words,1)
  elseif first=='biggestfruit'or first=='fruit'then record='BiggestFruit';table.remove(words,1)end
  local spec=#words>0 and findSeed(table.concat(words,' '))
  if#words>0 and not spec then return false,'Unknown seed. See /test catalog all.'end
  local ok,why=self:Send({Kind='Record',Player=p,Record=record,SeedId=spec and spec.id or nil,Odds=spec and ctx and ctx.Config and defaultOdds(ctx.Config,spec)or nil,Scope='InServer'})
  return ok,ok and('Record chat line sent to this server: '..name..' took '..Rules.RecordTitle(record)..'.')or('Not sent: '..tostring(why))
 end
 local here=false
 if#words>0 and words[#words]:lower()=='here'then here=true;table.remove(words)end
 if#words==0 then return false,A.Usage end
 local spec=findSeed(table.concat(words,' '))
 if not spec then return false,'Unknown seed. See /test catalog all (an id such as FirePepperSeed, or the plant name).'end
 local odds=ctx and ctx.Config and defaultOdds(ctx.Config,spec)or nil
 local fields={Name=name,UserId=p.UserId,Id=self:_id(),SeedId=spec.id,Odds=odds,At=self.Time()}
 if mode=='global'then
  local e,why=Rules.Event('Global',fields);if not e then return false,'Not sent: '..tostring(why)end
  self:_queue(e)
  local text='Queued for the other servers ('..Rules.Line(e)..'). It goes out within '..Rules.Setting('PublishGapSeconds')..' s; this server does not show it (it is the origin).'
  if here then self:_broadcast(e,function(player)return self:_wants(player)end);text=text..' Shown here too, as an other-server pull.'end
  return true,text
 end
 local e,why=Rules.Event('Pull',fields);if not e then return false,'Not sent: '..tostring(why)end
 local sent=self:_broadcast(e)
 return true,'Chat line sent to '..sent..' player'..(sent==1 and''or's')..' in this server: '..Rules.Line(e)..(Rules.Qualifies('InServer',e.Rarity)and''or' (below the in-server threshold, so a real pull would not show it)')
end

-- The one running instance (ChestChaseServerMain calls Start once) -------------------------------------------------------------------------------------
function A.Start(data)
 if A.Instance then return A.Instance end
 A.Instance=A.new({Data=data});A.Instance:Run()
 return A.Instance
end
function A.OnOpened(player,pack,reward,wasTest)
 local self=A.Instance;if not self then return false,'not running'end
 return self:Pulled(player,pack,reward,wasTest)
end
function A.Announce(spec)
 local self=A.Instance;if not self then return false,'Pull announcements are not running.'end
 return self:Send(spec)
end
function A.Command(ctx,p,a)
 local self=A.Instance;if not self then return false,'Pull announcements are not running.'end
 return self:RunCommand(ctx,p,a)
end
return A
