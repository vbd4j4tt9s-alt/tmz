-- R140 (owner: "speed boost for friends in the server and an invite button", "the your plant is ready thing"):
--  * Friend boost: every Roblox friend in the same server adds DailyRewards.FriendBoostPerFriend to the speed GAINED
--    from treadmill training (up to FriendBoostMaxFriends). The server sets FriendsInServer / FriendSpeedBoost;
--    BaseService:GetFriendGainMultiplier applies it (R148: it no longer touches the walk speed).
--  * "Your plant is ready": when a player leaves with a plant still growing, the time its first fruit is ready goes
--    into a MemoryStore queue shared by every server; whichever server is running then sends the Roblox experience
--    notification. Nothing happens until the owner sets this module's MessageId attribute (the notification string's
--    asset id from the Creator Dashboard) and adds the Open Cloud API key as the experience secret named by SecretName
--    (default 'PlantReadyKey'). Roblox only delivers to players 13+ who opted in (the client asks after a planting).
--  * Daily quests roll over at midnight UTC for players who stay online.
-- R151 (owner: "search for cases where the offline notifier or some things will just not function as intended and make sure
-- they are fixed"; docs/proposals/R151/offline_audit.md):
--  * a server shutting down (update, "shut down all servers") still queues every player's plant (BindToClose -> Shutdown),
--    even though the profile is already finalizing, and waits for those writes;
--  * the claim that makes one server send each entry reads UpdateAsync's committed result (a retried transform could make
--    two servers both think they had it); a claim left by a server that died mid-send is taken over after ClaimSeconds;
--  * the whole due part of the queue is read in pages (not only the first 20 entries a minute);
--  * Roblox allows one notification per player per day: the cooldown is 24 h, and an entry that falls inside it waits for
--    the end of the cooldown instead of being thrown away; Roblox's own "1 per recipient" 429 starts the cooldown too;
--  * a failed send is retried with backoff (429 / 5xx / network); setup problems (HTTP off, no secret, key refused) keep the
--    entries and pause sending on that server instead of eating the queue; a plant ready within 5 minutes no longer hides
--    a later one; players online here have their entry cleared again every 2 minutes (a late write from the server they
--    just left); a server that just started delivers after 15 s;
--  * the owner gets a clear console line for a missing setup piece and `/test plantnotify [status|send|reset]`;
--  * a friend check that failed (web hiccup) is tried again 30 s later instead of only on the next join.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Http=game:GetService('HttpService');local MemoryStore=game:GetService('MemoryStoreService')
local D=require(RS.DailyRewards);local PlantRules=require(RS.PlantRules);local Names=require(RS.GardenDisplayNames)
local S={};S.__index=S
S.MinDelay=5*60          -- a plant ready sooner than this after leaving is not worth a notification
S.MaxDelay=45*86400      -- MemoryStore entries live at most 45 days
S.Cooldown=24*3600       -- R151: Roblox delivers at most one notification per player per day from an experience
S.Stale=24*3600          -- R151: an entry more than a day past its ready time (no server ran meanwhile) is dropped
S.PollSeconds=60
S.FirstPoll=15           -- R151: a server that just started (the first player after a quiet spell) delivers after 15 s
S.PageSize=100;S.MaxPerPass=300 -- R151: every due entry is read, a page at a time
S.ClaimSeconds=300       -- R151: a claim older than this (its server died mid-send) can be taken over
S.MaxTries=4             -- R151: a send that failed for a passing reason (429, 5xx, network) is tried again 2, 4, 8 min later
S.SweepSeconds=120       -- R151: players in this server have their queue entry cleared again every 2 minutes
S.PauseSeconds=600       -- R151: a setup problem pauses sending on this server for 10 minutes (the entries wait)
S.FlushSeconds=8         -- R151: how long a closing server waits for its queue writes
S.FriendRetrySeconds=30
local QUEUE,SENT='PlantReady140','PlantReadySent140'
function S.new(data,notifications)
 local okToken,token=pcall(function()return Http:GenerateGUID(false)end)
 local self=setmetatable({Data=data,Notifications=notifications,Friends={},Day=D.Day(os.time()),Connections={},Dead=false,
  Token=okToken and type(token)=='string'and token or(tostring(game.JobId)..':'..tostring(os.clock())),Writes=0,Ready={},ClosedFor={},
  Stats={Sent=0,Deferred=0,Retried=0,Dropped=0,Failed=0},Warned={}},S)
 return self
end
local function messageId()
 local id=script:GetAttribute('MessageId')
 if type(id)~='string'then return nil end
 id=(id:gsub('^[%s"\']+',''):gsub('[%s"\']+$','')) -- (a pasted id may carry spaces or quotes)
 return #id>=8 and #id<=80 and id or nil
end
local function secretName()
 local name=script:GetAttribute('SecretName');if type(name)~='string'or name==''then name='PlantReadyKey'end;return name
end
function S:Configured()return messageId()~=nil end
function S:_queue()if not self.Queue then self.Queue=MemoryStore:GetSortedMap(QUEUE)end;return self.Queue end
function S:_sent()if not self.Sent then self.Sent=MemoryStore:GetSortedMap(SENT)end;return self.Sent end
-- One warning per kind per server and hour (a broken setup must not flood the console).
function S:_warn(kind,text)
 local now=os.clock();local last=self.Warned[kind]
 if last and now-last<3600 then return end;self.Warned[kind]=now;warn(text)
end
-- Friend boost ------------------------------------------------------------------------------------------------------
local function pairKey(a,b)return a<b and a..':'..b or b..':'..a end
function S:_isFriend(a,b)
 local key=pairKey(a.UserId,b.UserId);local known=self.Friends[key]
 if known~=nil then return known end
 local ok,result=pcall(a.IsFriendsWith,a,b.UserId)
 if not ok then self.FriendRetryAt=self.FriendRetryAt or os.clock()+S.FriendRetrySeconds;return false end -- (not cached: tried again soon)
 self.Friends[key]=result==true;return result==true
end
function S:Recount(player)
 if not player.Parent then return 0 end
 local n=0
 for _,other in ipairs(Players:GetPlayers())do if other~=player and other.Parent and self:_isFriend(player,other)then n+=1 end end
 player:SetAttribute('FriendsInServer',n);player:SetAttribute('FriendSpeedBoost',D.FriendMultiplier(n))
 return n
end
function S:FriendJoined(player)
 local mine=self:Recount(player)
 for _,other in ipairs(Players:GetPlayers())do
  if other~=player and self:_isFriend(other,player)then
   local n=self:Recount(other)
   if self.Notifications then pcall(function()
    self.Notifications:Show(other,'👥 '..player.DisplayName..' is here! Friend boost: +'..math.floor((D.FriendMultiplier(n)-1)*100+.5)..'% speed gain',Color3.fromRGB(120,220,255),5)
   end)end
  end
 end
 if mine>0 and self.Notifications then pcall(function()
  self.Notifications:Show(player,'👥 '..mine..(mine==1 and' friend'or' friends')..' here! Friend boost: +'..math.floor((D.FriendMultiplier(mine)-1)*100+.5)..'% speed gain',Color3.fromRGB(120,220,255),5)
 end)end
end
function S:FriendLeft(player)
 for _,other in ipairs(Players:GetPlayers())do if other~=player and(self.Friends[pairKey(other.UserId,player.UserId)])then
  -- Recount without the leaving player (it is still in the list while PlayerRemoving runs).
  local n=0
  for _,q in ipairs(Players:GetPlayers())do if q~=other and q~=player and self.Friends[pairKey(other.UserId,q.UserId)]then n+=1 end end
  other:SetAttribute('FriendsInServer',n);other:SetAttribute('FriendSpeedBoost',D.FriendMultiplier(n))
 end end
 for key in pairs(self.Friends)do local a,b=key:match('^(%-?%d+):(%-?%d+)$')
  if tonumber(a)==player.UserId or tonumber(b)==player.UserId then self.Friends[key]=nil end
 end
end
-- Plant ready -------------------------------------------------------------------------------------------------------
-- The first moment, after now (R151: at or after minAt when given), that a fruit in this player's garden becomes ready,
-- and that plant's name.
function S:NextReady(player,now,minAt)
 local garden=self.Data.Gardens and self.Data.Gardens[player];if not garden then return nil end
 local plants=self.Data.Config and self.Data.Config.GardenPlants or{}
 local best,name
 for _,crops in pairs(garden.Plots or{})do for _,crop in ipairs(crops)do
  local def=plants[crop.SeedId]
  if def then for i=1,def.FruitCount or 1 do
   if not PlantRules.IsPicked(crop,i)then
    local at=math.max(crop.MatureAt or 0,PlantRules.FruitReadyAt(crop,i))
    if at>now and at>=(minAt or at)and(not best or at<best)then best=at;name=Names.Plant(crop.SeedId,def.Name or crop.SeedName or'plant')end
   end
  end end
 end end
 return best,name
end
-- R151: while a server shuts down the profile is already finalizing (IsLoaded is false) but the garden is still here.
function S:_canRead(player)
 local data=self.Data
 return data:IsLoaded(player)or(type(data.Loaded)=='table'and data.Loaded[player]==true)
end
-- Runs one MemoryStore write in its own thread (never yields the caller), tried twice; Shutdown waits for these.
function S:_write(fn)
 self.Writes+=1
 task.spawn(function()
  local ok,why
  for attempt=1,2 do
   ok,why=pcall(function()fn(self:_queue())end)
   if ok then break end
   if attempt==1 then task.wait(1)end
  end
  self.Writes-=1
  if not ok then self:_warn('write','[R140] Plant notification queue write failed: '..tostring(why))end
 end)
end
function S:Schedule(player)
 if not self:Configured()or not self:_canRead(player)then return false end
 local now=os.time();local at,name=self:NextReady(player,now,now+S.MinDelay)
 if not at or at-now>S.MaxDelay then return false end
 local value={At=math.floor(at),Ready=math.floor(at),Plant=tostring(name):sub(1,40)};local key=tostring(player.UserId)
 local ttl=math.max(60,math.min(S.MaxDelay,math.floor(at-now)+S.Stale))
 -- Never yield here: this runs inside PlayerRemoving, before the profile is finalized.
 self:_write(function(queue)queue:SetAsync(key,value,ttl,value.At)end)
 return value
end
function S:Cancel(player)
 if not self:Configured()then return end
 local key=tostring(player.UserId)
 self:_write(function(queue)queue:RemoveAsync(key)end)
end
-- R151: the player's server may write its entry a moment AFTER the player already joined here (a crash / quick rejoin is
-- seen late there), so the entries of everyone playing here are cleared again now and then.
function S:Sweep()
 if not self:Configured()or self.Closing then return 0 end
 local n=0
 for _,player in ipairs(Players:GetPlayers())do if player.Parent and self.Ready[player]then n+=1;self:Cancel(player)end end
 return n
end
-- Sends one notification now. Returns ok plus, when it failed, how: 'throttled' (Roblox's one-a-day limit for this player),
-- 'retry' (a passing problem), 'setup' (HTTP off, no secret, key refused, unpublished place) or 'bad' (Roblox refused this one).
function S:Send(userId,plant)
 local id=messageId();if not id then return false,'setup','no MessageId attribute on SocialService'end
 if game.GameId==0 then self:_warn('setup','[R140] Plant notification not sent: this place is not published (GameId 0).');return false,'setup','the place is not published'end
 local body={source={universe='universes/'..tostring(game.GameId)},payload={messageId=id,type='MOMENT',
  parameters={plantName={stringValue=tostring(plant or'plant'):sub(1,40)}},joinExperience={launchData='PlantReady'},analyticsData={category='PlantReady'}}}
 local ok,result=pcall(function()
  return Http:RequestAsync({Url='https://apis.roblox.com/cloud/v2/users/'..tostring(userId)..'/notifications',Method='POST',
   Headers={['Content-Type']='application/json',['x-api-key']=Http:GetSecret(secretName())},Body=Http:JSONEncode(body)})
 end)
 if not ok then
  local text=tostring(result);local low=text:lower()
  local hint=low:find('not enabled',1,true)and' (turn on Game Settings -> Security -> Allow HTTP Requests)'
   or low:find('secret',1,true)and(' (add the Open Cloud API key as the experience secret \''..secretName()..'\': Creator Dashboard -> Secrets, domain apis.roblox.com; in Studio: Local Secrets)')
   or low:find('not allowed',1,true)and' (Roblox refused this call from a game server: see docs/proposals/R151/offline_audit.md, "if game servers cannot call the API")'
  local kind=hint and'setup'or'retry'
  self:_warn(kind,'[R140] Plant notification not sent: '..text..(hint or''))
  return false,kind,text
 end
 if type(result)~='table'then self:_warn('retry','[R140] Plant notification not sent: no response');return false,'retry','no response'end
 if result.Success then return true,'sent',tostring(result.StatusCode or 200)end
 local code=tonumber(result.StatusCode)or 0;local text=tostring(result.Body or''):sub(1,300);local low=text:lower()
 local kind
 if code==429 and(low:find('per recipient',1,true)or low:find('per user',1,true))then kind='throttled'
 elseif code==401 or code==403 then kind='setup'
 elseif code==429 or code==408 or code>=500 or code==0 then kind='retry'
 else kind='bad'end
 local hint=kind=='setup'and' (the API key is wrong or expired, lacks the user-notification write permission for this experience, or its IP list blocks game servers)'
  or kind=='bad'and code==400 and' (check the MessageId: the notification string\'s asset id, and that its only parameter is {plantName})'or''
 if kind~='throttled'then self:_warn(kind..code,'[R140] Plant notification not sent: '..code..' '..text..hint)end
 return false,kind,code..' '..text
end
-- R151: puts a claimed entry back (new time, try count), unless the player left again meanwhile and a newer entry replaced it.
function S:_requeue(key,at,tries,now)
 at=math.floor(at)
 pcall(function()
  self:_queue():UpdateAsync(key,function(old)
   if type(old)~='table'or old.Claimed~=self.Token then return nil end
   return {At=at,Ready=old.Ready or old.At,Plant=old.Plant,Tries=tries},at
  end,math.max(60,math.min(S.MaxDelay,at-now+S.Stale)))
 end)
end
function S:_remove(key)pcall(function()self:_queue():RemoveAsync(key)end)end
-- The cooldown row is just the time it ends (small: the MemoryStore size quota grows with players ONLINE, these rows with players notified).
function S:_cooldown(key,now)pcall(function()self:_sent():SetAsync(key,now+S.Cooldown,S.Cooldown)end)end
local function cooldownEnd(row,now)return type(row)=='number'and row or type(row)=='table'and tonumber(row.Until)or(row~=nil and now+3600)or nil end -- (R140 rows were plain true)
-- Claims one due entry (only one server wins it) and handles it. Returns 'sent', 'deferred', 'retry', 'dropped', 'stop' or 'skip'.
function S:_deliverOne(key,now)
 local token=self.Token
 local ok,value=pcall(function()
  return self:_queue():UpdateAsync(key,function(old,sortKey)
   if type(old)~='table'or(tonumber(old.At)or 0)>now then return nil end
   if old.Claimed and(tonumber(old.ClaimedAt)or 0)>now-S.ClaimSeconds then return nil end
   return {At=old.At,Ready=old.Ready,Plant=old.Plant,Tries=old.Tries,Claimed=token,ClaimedAt=now},sortKey
  end,S.Stale)
 end)
 -- The committed value says who won (a transform that ran, lost a race and ran again must not count as a win).
 if not ok or type(value)~='table'or value.Claimed~=token then return'skip'end
 local stats=self.Stats
 local userId=tonumber(key);local ready=tonumber(value.Ready)or tonumber(value.At)or now
 if not userId or now-ready>S.Stale or Players:GetPlayerByUserId(userId)then self:_remove(key);stats.Dropped+=1;return'dropped'end
 local okCool,recent=pcall(function()return self:_sent():GetAsync(key)end)
 local untilAt=okCool and cooldownEnd(recent,now)or nil
 if untilAt and untilAt>now then
  if untilAt-ready>S.Stale then self:_remove(key);stats.Dropped+=1;return'dropped'end
  self:_requeue(key,untilAt,value.Tries,now);stats.Deferred+=1;return'deferred'
 end
 local sent,kind,detail=self:Send(userId,value.Plant or'plant')
 self.Last={At=now,Ok=sent,Kind=kind,Detail=detail,UserId=userId}
 if sent then self:_cooldown(key,now);self:_remove(key);stats.Sent+=1;return'sent'end
 if kind=='throttled'then
  -- Roblox says this player already had today's notification from the game: they were reminded today. The cooldown starts
  -- (so other servers stop trying) and this one is dropped (a day later it would be past S.Stale anyway).
  self:_cooldown(key,now);self:_remove(key);stats.Dropped+=1;return'dropped'
 elseif kind=='retry'then
  local tries=(tonumber(value.Tries)or 0)+1
  if tries>=S.MaxTries then self:_remove(key);stats.Failed+=1;return'dropped'end
  self:_requeue(key,now+60*2^tries,tries,now);stats.Retried+=1;return'retry'
 elseif kind=='setup'then
  self:_requeue(key,value.At,value.Tries,now) -- (released, same time: sent once the setup is fixed)
  self.PausedUntil=now+S.PauseSeconds;return'stop'
 end
 self:_remove(key);stats.Failed+=1;return'dropped'
end
-- One pass over the shared queue: every entry that is due, a page at a time, each claimed before it is sent.
function S:Deliver(now)
 if not self:Configured()or self.Closing then return 0 end
 now=now or os.time()
 if self.PausedUntil and now<self.PausedUntil then return 0 end
 local sent,seen,lower=0,0,nil
 while seen<S.MaxPerPass do
  local ok,page=pcall(function()return self:_queue():GetRangeAsync(Enum.SortDirection.Ascending,S.PageSize,lower,{sortKey=now+1})end)
  if not ok or type(page)~='table'or #page==0 then break end
  -- Servers read the same page: each walks it from a random start, so they mostly claim different entries.
  local start=math.random(1,#page)
  for i=0,#page-1 do
   if self.Closing then return sent end -- (the server started closing during this pass)
   local item=page[(start+i-1)%#page+1];seen+=1
   local result=type(item)=='table'and type(item.key)=='string'and self:_deliverOne(item.key,now)or'skip'
   if result=='sent'then sent+=1 elseif result=='stop'then return sent end
  end
  if #page<S.PageSize then break end
  local last=page[#page];lower={key=last.key,sortKey=last.sortKey}
 end
 return sent
end
-- Setup / status ----------------------------------------------------------------------------------------------------------
function S:SetupProblems()
 local problems={}
 if not self:Configured()then problems[1]='the MessageId attribute on ServerScriptService.ChestChaseServer.SocialService is not set (the notification string\'s asset id)';return problems end
 local okHttp,enabled=pcall(function()return Http.HttpEnabled end)
 if okHttp and enabled==false then problems[#problems+1]='Allow HTTP Requests is off (Game Settings -> Security)'end
 if not pcall(function()return Http:GetSecret(secretName())end)then
  problems[#problems+1]='the secret \''..secretName()..'\' is missing (Creator Dashboard -> your experience -> Secrets, domain apis.roblox.com; for Studio: File -> Experience Settings -> Security -> Local Secrets)'
 end
 if game.GameId==0 then problems[#problems+1]='this place is not published'end
 return problems
end
function S:CheckSetup()
 local problems=self:SetupProblems()
 if not self:Configured()then
  if Run:IsStudio()then print('[R140] "Your plant is ready" notifications are OFF: '..problems[1]..'. Setup: docs/releases/R140.md.')end
  return problems
 end
 if #problems>0 then warn('[R140] "Your plant is ready" notifications are set up but cannot send: '..table.concat(problems,'; ')..'. Try /test plantnotify.')
 elseif Run:IsStudio()then print('[R140] "Your plant is ready" notifications: setup found (MessageId, secret, HTTP). /test plantnotify send sends you one now.')end
 return problems
end
local function clockText(t)t=tonumber(t);return t and('%02d:%02d UTC'):format(math.floor(t/3600)%24,math.floor(t/60)%60)or'?'end
function S:StatusText(player,now)
 now=now or os.time()
 local lines={}
 local problems=self:SetupProblems()
 lines[1]=(#problems==0 and'Plant-ready notifications: ON'or'Plant-ready notifications: NOT WORKING - '..table.concat(problems,'; '))
  ..(messageId()and(' | MessageId '..messageId():sub(1,8)..'...')or'')..' | secret '..secretName()
 if not self:Configured()then return table.concat(lines,'\n')end
 local okRange,page=pcall(function()return self:_queue():GetRangeAsync(Enum.SortDirection.Ascending,200)end)
 if okRange and type(page)=='table'then
  local due=0;for _,item in ipairs(page)do if(tonumber(item.sortKey)or 0)<=now then due+=1 end end
  lines[#lines+1]=('Queue: %d due now, %d waiting%s'):format(due,#page-due,#page>=200 and' (first 200 read)'or'')
 else lines[#lines+1]='Queue: could not be read ('..tostring(page)..')'end
 if player then
  local key=tostring(player.UserId)
  local okMine,mine=pcall(function()return self:_queue():GetAsync(key)end)
  local okCool,cool=pcall(function()return self:_sent():GetAsync(key)end)
  lines[#lines+1]='You: '..(okMine and type(mine)=='table'and('queued for '..clockText(tonumber(mine.At))..' ('..tostring(mine.Plant)..')')or'nothing queued (you are in the game)')
   ..' | cooldown: '..(okCool and(cooldownEnd(cool,now)or 0)>now and('until '..clockText(cooldownEnd(cool,now)))or'none')
 end
 local st=self.Stats
 lines[#lines+1]=('This server: %d sent, %d waiting for the 24 h limit, %d retried, %d dropped, %d failed%s'):format(st.Sent,st.Deferred,st.Retried,st.Dropped,st.Failed,
  self.Last and(' | last: '..(self.Last.Ok and'sent'or tostring(self.Last.Kind))..' '..tostring(self.Last.Detail or''):sub(1,80)..' at '..clockText(self.Last.At))or'')
  ..(self.PausedUntil and now<self.PausedUntil and(' | PAUSED until '..clockText(self.PausedUntil))or'')
 return table.concat(lines,'\n')
end
-- Owner command (OwnerUpdateCommands82): plantnotify [status|send|reset].
function S.Command(_,player,args)
 local self=S.Current;if not self then return false,'Plant notifications are not running on this server.'end
 local sub=tostring(args and args[1]or''):lower()
 if #(args or{})>1 or(sub~=''and sub~='status'and sub~='send'and sub~='reset')then return false,'Use plantnotify [status|send|reset].'end
 if sub==''or sub=='status'then return true,self:StatusText(player)end
 if not self:Configured()then return false,'Set the MessageId attribute first. '..self:StatusText(player)end
 local key=tostring(player.UserId)
 if sub=='reset'then
  pcall(function()self:_sent():RemoveAsync(key)end);self:_remove(key);self.PausedUntil=nil
  return true,'Your plant-notification cooldown and queue entry are cleared (Roblox\'s own one-a-day limit still applies).'
 end
 local now=os.time();local _,name=self:NextReady(player,now)
 local ok,kind,detail=self:Send(player.UserId,name or'Sunflower')
 if ok then self:_cooldown(key,now)
  return true,'Sent to you now ('..tostring(name or'Sunflower')..'): check the Roblox notifications on your account. Only delivered if you opted in for this experience and are 13+.'end
 return false,'Not sent ('..tostring(kind)..'): '..tostring(detail)..(kind=='throttled'and' - Roblox allows one a day per player.'or'')
end
-- Players ---------------------------------------------------------------------------------------------------------------
function S:Setup(player)
 if not player.Parent then return end
 player:SetAttribute('PlantReadyAlerts',self:Configured())
 self.Data:PublishDaily(player)
 self.Ready[player]=true
 self:Cancel(player) -- back in the game: no "your plant is ready" while playing
 task.spawn(function()self:FriendJoined(player)end)
end
function S:Leaving(player)
 self.Ready[player]=nil
 if not self.ClosedFor[player]then pcall(function()self:Schedule(player)end)end -- (Shutdown already queued it)
 self.ClosedFor[player]=nil
 self:FriendLeft(player)
end
-- R151 (BindToClose): the server is closing. Queue everyone still here while their garden is readable, stop sending (a claim
-- could be cut off mid-send) and wait a few seconds for the writes.
function S:Shutdown(players)
 self.Closing=true;self.Dead=true
 for _,player in ipairs(players or Players:GetPlayers())do
  if not self.ClosedFor[player]then self.ClosedFor[player]=true;self.Ready[player]=nil;pcall(function()self:Schedule(player)end)end
 end
 for _=1,S.FlushSeconds*10 do if self.Writes<=0 then break end;task.wait(.1)end
 return self.Writes<=0
end
function S:Step(now)
 now=now or os.time();local day=D.Day(now)
 if day~=self.Day then
  self.Day=day
  for _,player in ipairs(Players:GetPlayers())do if self.Data:IsLoaded(player)then self.Data:PublishDaily(player)end end
 end
 if self.FriendRetryAt and os.clock()>=self.FriendRetryAt then
  self.FriendRetryAt=nil
  for _,player in ipairs(Players:GetPlayers())do if self.Ready[player]then self:Recount(player)end end
 end
end
function S:Start()
 if self.Started then return self end;self.Started=true;S.Current=self
 task.spawn(function()pcall(function()self:CheckSetup()end)end)
 task.spawn(function()
  local lastPoll=os.clock()-S.PollSeconds+S.FirstPoll;local lastSweep=os.clock()
  while not self.Dead do
   task.wait(5)
   if self.Dead then break end
   self:Step(os.time())
   local clock=os.clock()
   if clock-lastPoll>=S.PollSeconds then lastPoll=clock;pcall(function()self:Deliver(os.time())end)end
   if clock-lastSweep>=S.SweepSeconds then lastSweep=clock;pcall(function()self:Sweep()end)end
  end
 end)
 return self
end
return S
