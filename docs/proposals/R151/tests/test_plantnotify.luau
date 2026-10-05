--!nocheck
-- R151 (owner: "search for cases where the offline notifier or some things will just not function as intended and make sure
-- they are fixed"): the real SocialService "your plant is ready" queue + Open Cloud call, the real PlayerDataService and
-- Config, under a MemoryStore fake that behaves like Roblox's (shared by every SocialService = every server; TTLs; GetRangeAsync
-- with exclusive bounds and at most 200 items; UpdateAsync that runs the transform AGAIN when another server committed first;
-- injected throttling) and an HttpService fake (status codes, errors, secrets, HttpEnabled). One check per failure case in
-- docs/proposals/R151/offline_audit.md.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
W.game.GameId=4242
-- HttpService ---------------------------------------------------------------------------------------------------------------
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local requests={};local secrets={PlantReadyKey=true};Http.HttpEnabled=true
local function okResponse()return {Success=true,StatusCode=200,Body='{"path":"users/1/notifications/x","id":"x"}'}end
local respond=okResponse
function Http.GetSecret(_,name)if not secrets[name]then error("Can't find secret with given key",0)end;return {Secret=name}end
function Http.JSONEncode(_,t)return t end
function Http.RequestAsync(_,req)requests[#requests+1]=req;return respond(req)end
local warnings={}
W.env.warn=function(...)local t={};for i=1,select('#',...)do t[i]=tostring((select(i,...)))end;warnings[#warnings+1]=table.concat(t,' ')end
local function warned(pattern)for _,w in ipairs(warnings)do if w:find(pattern,1,true)then return true end end;return false end
-- DataStore (profiles) ------------------------------------------------------------------------------------------------------
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
-- MemoryStore, shared by every "server" ---------------------------------------------------------------------------------
local MS=W.service('MemoryStoreService');local maps={};local calls={}
local function deep(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=deep(x)end;return t end
local function before(a,b)-- (sortKey, key) order
 local sa,sb=a.sortKey,b.sortKey
 if sa~=sb then if sa==nil then return true end;if sb==nil then return false end;return sa<sb end
 return a.key<b.key
end
function MS.GetSortedMap(_,name)
 if maps[name]then return maps[name]end
 local m={Name=name,Items={},Fail={},Race={},Hold=nil}
 local function live(k)local it=m.Items[k];if it and it.Expires<=R.clock then m.Items[k]=nil;it=nil end;return it end
 local function call(method)calls[method]=(calls[method]or 0)+1;local n=m.Fail[method];if n and n>0 then m.Fail[method]=n-1;error('Request throttled: '..method,0)end end
 local function ttlOk(ttl)assert(type(ttl)=='number'and ttl>=1 and ttl<=45*86400,'bad expiration '..tostring(ttl))end
 function m.SetAsync(self,key,value,ttl,sortKey)call('SetAsync');ttlOk(ttl)
  if m.Hold then local hold=m.Hold;m.Hold=nil;hold(function()self.Items[key]={Value=deep(value),Sort=sortKey,Expires=R.clock+ttl}end);return true end
  self.Items[key]={Value=deep(value),Sort=sortKey,Expires=R.clock+ttl};return true end
 function m.GetAsync(self,key)call('GetAsync');local it=live(key);if it then return deep(it.Value),it.Sort end;return nil end
 function m.RemoveAsync(self,key)call('RemoveAsync');self.Items[key]=nil end
 function m.UpdateAsync(self,key,fn,ttl)call('UpdateAsync');ttlOk(ttl)
  local it=live(key);local v,s=fn(deep(it and it.Value),it and it.Sort)
  local race=m.Race[key]
  if race then m.Race[key]=nil;race();it=live(key);v,s=fn(deep(it and it.Value),it and it.Sort)end -- another server committed first: Roblox runs the transform again
  if v==nil then return nil end
  self.Items[key]={Value=deep(v),Sort=s,Expires=R.clock+ttl};return deep(v),s
 end
 function m.GetRangeAsync(self,dir,count,lower,upper)call('GetRangeAsync');assert(type(count)=='number'and count>=1 and count<=200,'count '..tostring(count))
  local out={}
  for k in pairs(self.Items)do local it=live(k)
   if it then local e={key=k,value=deep(it.Value),sortKey=it.Sort};local keep=true
    if lower then keep=before({key=lower.key or'',sortKey=lower.sortKey},e)end
    if keep and upper and upper.sortKey~=nil then keep=e.sortKey~=nil and e.sortKey<upper.sortKey end
    if keep then out[#out+1]=e end
   end
  end
  table.sort(out,before);while #out>count do table.remove(out)end;return out
 end
 maps[name]=m;return m
end
local function queue()return MS:GetSortedMap('PlantReady140')end
local function sentMap()return MS:GetSortedMap('PlantReadySent140')end
local function entry(id)local it=queue().Items[tostring(id)];return it and it.Expires>R.clock and it.Value or nil end
local function clearAll()for _,m in pairs(maps)do table.clear(m.Items);table.clear(m.Fail);table.clear(m.Race);m.Hold=nil end;table.clear(requests);table.clear(warnings)end
-- The game ---------------------------------------------------------------------------------------------------------------
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Notes={Show=function()end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
R.clock=20000*86400+3600
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 function p.IsFriendsWith()return false end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function plant(p,list)-- list = {{seed, seconds from now}, ...}
 local plots={};local now=math.floor(R.clock)
 for i,row in ipairs(list)do
  plots[tostring(i)]={{Id='crop-'..p.UserId..'-'..i,SeedId=row[1],ReadyAt=now+row[2],MatureAt=now+row[2],PlantedAt=now-10,PickedMask=0}}
 end
 Data.Gardens[p].Plots=plots
end
local Social=server('SocialService');local src=W.B.SocialService
folder.SocialService:SetAttribute('MessageId','  "5dd7024b-68e3-ac4d-8232-4217f86ca244"  ') -- pasted with spaces and quotes
local A=makePlayer(601,'Ana');local B=makePlayer(602,'Bo');local C=makePlayer(603,'Cy')
local server1=Social.new(Data,Notes)
local Names=W.module('GardenDisplayNames')
local melon=Names.Plant('SunflowerSeed',Config.GardenPlants.SunflowerSeed.Name);local pea=Names.Plant('CloverSeed',Config.GardenPlants.CloverSeed.Name)
local function leave(svc,p)svc:Leaving(p);present[p.UserId]=nil end
local function back(svc,p)present[p.UserId]=p;svc:Setup(p)end

local s1,s2=Social.new(Data,Notes),Social.new(Data,Notes)
-- Each case runs on its own: one that errors (e.g. against an older SocialService) counts as a failure and the rest still run.
local function section(name,fn)
 clearAll();present[601]=A;present[602]=B;present[603]=C
 local ok,why=pcall(fn)
 if not ok then check(false,name..' raised: '..tostring(why))end
 table.clear(requests);respond=okResponse;secrets.PlantReadyKey=true;Http.HttpEnabled=true;W.game.GameId=4242;if Data.Finalizing then table.clear(Data.Finalizing)end
 for _,m in pairs(maps)do table.clear(m.Fail);table.clear(m.Race);m.Hold=nil end
end
-- 0. The rules match Roblox: one notification per player per day; entries live at most 45 days.
section('0',function()
 check(Social.Cooldown==86400,'cooldown 24 h (Roblox delivers one notification per player per day; 12 h made the second one fail)')
 check(Social.MaxDelay<=45*86400 and Social.Stale==86400,'entries at most 45 days; a day-old ready time is stale')
 check(server1:Configured(),'a MessageId pasted with spaces and quotes still counts')
end)

-- 1. Leaving schedules the earliest plant ready at least 5 minutes out (a plant ready in 2 min no longer hides a later one).
section('1',function()
 plant(A,{{'SunflowerSeed',120},{'CloverSeed',7200}})
 local v=server1:Schedule(A)
 check(v and v.At==math.floor(R.clock)+7200 and v.Plant==pea and entry(601)and entry(601).At==v.At,'a plant ready in 2 min plus one in 2 h: queued for the 2 h one ('..tostring(v and v.Plant)..')')
 plant(A,{{'SunflowerSeed',120}});table.clear(queue().Items)
 check(server1:Schedule(A)==false and entry(601)==nil,'only a plant ready within 5 minutes: nothing queued')
 clearAll()
end)

-- 2. Server shutdown: the profile is already finalizing (IsLoaded false) when the players are queued.
section('2',function()
 plant(A,{{'SunflowerSeed',3600}});plant(B,{{'CloverSeed',5400}})
 Data.Finalizing=Data.Finalizing or{};Data.Finalizing[A]={Done=false};Data.Finalizing[B]={Done=false}
 check(not Data:IsLoaded(A),'(the closing profile reads as not loaded)')
 local shut=Social.new(Data,Notes);local sets0=calls.SetAsync or 0
 local flushed=shut:Shutdown({A,B})
 check(entry(601)and entry(601).Plant==melon and entry(602)and entry(602).Plant==pea,'a closing server still queues every player whose profile is finalizing')
 check(flushed==true and shut.Writes==0,'and waits for those writes before BindToClose returns')
 local sets1=calls.SetAsync or 0
 shut:Leaving(A);shut:Leaving(B)
 check((calls.SetAsync or 0)==sets1 and sets1-sets0==2,'PlayerRemoving after BindToClose does not write them a second time')
 check(shut:Deliver(math.floor(R.clock)+99999)==0,'a closing server sends nothing (a claim could be cut off mid-send)')
 -- A write still in flight when the flush time runs out: Shutdown gives up after FlushSeconds instead of hanging.
 plant(C,{{'CloverSeed',900}})
 local shut3=Social.new(Data,Notes);local pending,held
 queue().Hold=function(commit)pending=commit;held=coroutine.running();coroutine.yield()end
 shut3:Schedule(C)
 check(shut3.Writes==1 and held~=nil,'(a write is in flight)')
 check(shut3:Shutdown({})==false,'a write that never finishes: Shutdown returns after its flush time (BindToClose never hangs)')
 pending();coroutine.resume(held);check(shut3.Writes==0 and entry(603)~=nil,'(and the late write still lands)')
 Data.Finalizing[A]=nil;Data.Finalizing[B]=nil
 clearAll()
end)

-- 3. No server at the ready time; later one starts (the first player after a quiet spell).
section('3',function()
 local t0=math.floor(R.clock)
 plant(A,{{'SunflowerSeed',1800}});server1:Schedule(A);leave(server1,A)
 plant(B,{{'CloverSeed',3600}});server1:Schedule(B);leave(server1,B)
 R.clock=t0+5*3600 -- nobody played for 5 hours
 local late=Social.new(Data,Notes)
 check(late:Deliver()==2 and #requests==2,'a server that starts hours later sends what became due meanwhile')
 check(src:find('lastPoll=os.clock()-S.PollSeconds+S.FirstPoll',1,true)and Social.FirstPoll<=15,'and its first pass runs 15 s after it starts (not after a full minute)')
 local stale=math.floor(R.clock)-Social.Stale-100 -- (written with a long life, so the stale rule is what removes it)
 queue():SetAsync('603',{At=stale,Ready=stale,Plant=pea},3*86400,stale);present[603]=nil
 check(late:Deliver()==0 and #requests==2 and entry(603)==nil and late.Stats.Dropped==1,'an entry more than a day past its ready time is dropped, not sent')
 clearAll();present[601]=A;present[602]=B;present[603]=C
end)

-- 4. Two servers claim the same entry at once (UpdateAsync runs the transform again for the loser).
section('4',function()
 plant(A,{{'SunflowerSeed',600}});s1:Schedule(A);leave(s1,A);R.clock+=601
 -- Another server commits its claim while s1's UpdateAsync is in flight: Roblox runs s1's transform again, which now refuses.
 queue().Race['601']=function()local it=queue().Items['601'];it.Value.Claimed='other-server';it.Value.ClaimedAt=math.floor(R.clock)end
 local r1=s1:Deliver()
 check(#requests==0 and r1==0 and entry(601)and entry(601).Claimed=='other-server','two servers claiming at the same moment: the loser sends nothing (only the winner will: one notification, not two)')
 check(not src:find('claimed.Claimed==game.JobId',1,true),'(the winner is read from UpdateAsync\'s committed value, not a local set inside the transform)')
 -- A server dies after claiming: another one takes the entry over after ClaimSeconds.
 clearAll();present[601]=A
 plant(A,{{'SunflowerSeed',600}});s1:Schedule(A);leave(s1,A);R.clock+=601
 local now=math.floor(R.clock)
 queue():UpdateAsync('601',function(old,sk)old.Claimed='dead-server';old.ClaimedAt=now;return old,sk end,86400)
 check(s2:Deliver(now+60)==0 and #requests==0,'an entry claimed by another server a minute ago is left alone')
 check(s2:Deliver(now+Social.ClaimSeconds+1)==1 and #requests==1,'a claim older than '..Social.ClaimSeconds..' s (that server died mid-send) is taken over and sent')
 clearAll();present[601]=A
end)

-- 5. A busy game: hundreds due at once, two servers, reads are paged.
section('5',function()
 for i=1,250 do queue():SetAsync(tostring(10000+i),{At=math.floor(R.clock)-i,Ready=math.floor(R.clock)-i,Plant=melon},86400,math.floor(R.clock)-i)end
 queue():SetAsync('20000',{At=math.floor(R.clock)+3600,Plant=melon},86400,math.floor(R.clock)+3600) -- not due yet
 local g0=calls.GetRangeAsync or 0
 local d1=s1:Deliver();local d2=s2:Deliver()
 local ids={};local dup=false;for _,r in ipairs(requests)do local id=r.Url:match('users/(%d+)/');if ids[id]then dup=true end;ids[id]=true end
 check(d1+d2==250 and #requests==250 and not dup,'250 due entries: all sent in one pass of two servers, none twice ('..d1..' + '..d2..'; R140 read only the first 20 a minute)')
 check(entry(20000)~=nil and not ids['20000'],'an entry not due yet is left in the queue')
 check((calls.GetRangeAsync or 0)-g0>=4,'(read in pages of '..Social.PageSize..')')
 clearAll()
 queue():SetAsync('601',{At=math.floor(R.clock)-5,Plant=melon},86400,math.floor(R.clock)-5);present[601]=nil
 queue().Fail.GetRangeAsync=1
 check(s1:Deliver()==0,'MemoryStore throttled: the pass ends quietly')
 check(s1:Deliver()==1 and #requests==1,'and the next pass sends it')
 clearAll();present[601]=A
end)

-- 6. The daily limit: a second plant the same day waits for the cooldown (it was thrown away in R140).
section('6',function()
 plant(A,{{'SunflowerSeed',600}});s1:Schedule(A);leave(s1,A);R.clock+=601
 check(s1:Deliver()==1,'first notification sent')
 back(s2,A);plant(A,{{'CloverSeed',7200}});s2:Schedule(A);leave(s2,A) -- played again, left with a pea growing
 local readyAt=entry(601).At;R.clock=readyAt+1
 check(s2:Deliver()==0 and #requests==1 and entry(601)and entry(601).At>R.clock,'2 h later the pea is ready, but the 24 h limit is running: it waits ('..tostring(entry(601)and entry(601).At-R.clock)..' s)')
 check(sentMap().Items['601']~=nil,'(the cooldown is shared: another server reads the same row)')
 R.clock=entry(601).At+1
 check(s1:Deliver()==1 and #requests==2,'when the 24 h are over it is sent (by any server)')
 -- Roblox's own one-a-day refusal also starts the cooldown, and the entry waits instead of being retried every minute.
 clearAll();present[602]=B
 respond=function()return {Success=false,StatusCode=429,Body='{"code":"RESOURCE_EXHAUSTED","message":"Limit of 1 notification per recipient per day reached"}'}end
 plant(B,{{'CloverSeed',600}});s1:Schedule(B);leave(s1,B);R.clock+=601
 check(s1:Deliver()==0 and #requests==1 and sentMap().Items['602']~=nil and entry(602)==nil,'Roblox says "1 notification per recipient" (they were reminded today): the cooldown starts and it is not retried')
 s2:Deliver(math.floor(R.clock)+600);check(#requests==1,'(no other server tries again)')
 check(not warned('429'),'(and that is not an error in the console)')
 respond=okResponse;clearAll();present[602]=B
end)

-- 7. Passing failures are retried with backoff, then dropped; setup problems keep the queue and pause the server.
section('7',function()
 plant(B,{{'CloverSeed',600}});s1:Schedule(B);leave(s1,B);R.clock+=601
 respond=function()return {Success=false,StatusCode=503,Body='unavailable'}end
 check(s1:Deliver()==0 and #requests==1 and entry(602)and entry(602).Tries==1 and entry(602).At>=R.clock+120,'a 503: tried again 2 minutes later')
 R.clock=entry(602).At+1;s1:Deliver();check(#requests==2 and entry(602).Tries==2,'then 4 minutes later')
 respond=function()error('HttpError: Timedout',0)end
 R.clock=entry(602).At+1;s1:Deliver();check(#requests==3 and entry(602)and entry(602).Tries==3,'a network error counts as passing too')
 R.clock=entry(602).At+1;s1:Deliver();check(#requests==4 and entry(602)==nil and s1.Stats.Failed==1,'after '..Social.MaxTries..' tries it is dropped (and counted)')
 clearAll();present[602]=B
 respond=function()error('Http requests are not enabled. Enable via game settings',0)end
 plant(B,{{'CloverSeed',600}});s1:Schedule(B);leave(s1,B);R.clock+=601
 check(s1:Deliver()==0 and entry(602)~=nil and entry(602).Claimed==nil,'HTTP off: the entry is kept (released for any server)')
 check(warned('Plant notification not sent')and warned('Allow HTTP Requests'),'with a console line saying what to switch on')
 check(s1:Deliver()==0 and #requests==1,'and this server pauses (no request every minute)')
 respond=okResponse;R.clock+=Social.PauseSeconds+1
 check(s1:Deliver()==1 and #requests==2,'fixed: the waiting entry is sent')
 clearAll();present[602]=B
 secrets.PlantReadyKey=nil
 plant(B,{{'CloverSeed',600}});s2:Schedule(B);leave(s2,B);R.clock+=601
 check(s2:Deliver()==0 and entry(602)~=nil and warned("secret 'PlantReadyKey'"),'no secret: kept, and the console names the secret')
 secrets.PlantReadyKey=true;clearAll();present[602]=B
 local s3=Social.new(Data,Notes)
 respond=function()return {Success=false,StatusCode=403,Body='{"code":"PERMISSION_DENIED"}'}end
 plant(B,{{'CloverSeed',600}});s3:Schedule(B);leave(s3,B);R.clock+=601
 check(s3:Deliver()==0 and entry(602)~=nil and warned('user-notification write permission'),'key refused (403): kept, and the console says what the key needs')
 clearAll();present[602]=B
 local s4=Social.new(Data,Notes)
 respond=function()return {Success=false,StatusCode=400,Body='{"code":"INVALID_ARGUMENT"}'}end
 plant(B,{{'CloverSeed',600}});s4:Schedule(B);leave(s4,B);R.clock+=601
 check(s4:Deliver()==0 and entry(602)==nil and warned('check the MessageId'),'Roblox refuses one (400): dropped, the console points at the MessageId')
 respond=okResponse;clearAll();present[602]=B
end)

-- 8. Rejoining: the old server's write lands AFTER the new server cancelled (crash / quick rejoin).
section('8',function()
 local old,new=Social.new(Data,Notes),Social.new(Data,Notes)
 plant(C,{{'CloverSeed',3600}})
 local landing;queue().Hold=function(commit)landing=commit end
 old:Leaving(C) -- the write is still on its way
 back(new,C)    -- already playing in the new server, which cancels
 landing()
 check(entry(603)~=nil,'(the late write left an entry while Cy is playing)')
 check(new:Sweep()>=1 and entry(603)==nil,'the new server clears the entries of its players again (every '..Social.SweepSeconds..' s)')
 R.clock+=7200;check(new:Deliver()==0 and #requests==0,'so no notification while Cy plays')
 new.Ready[C]=nil;plant(C,{{'CloverSeed',3600}});new:Leaving(C)
 check(new:Sweep()==0 and entry(603)~=nil,'a player who is leaving is not swept (the new entry stays)')
 present[603]=C;clearAll()
end)

-- 9. The request matches Roblox's Open Cloud reference (UserNotification) and HttpService's limits.
section('9',function()
 plant(A,{{'SunflowerSeed',600}});s1:Schedule(A);leave(s1,A);R.clock+=601;s1:Deliver()
 local req=requests[1];local body=req and req.Body
 local headers=0;for k in pairs(req and req.Headers or{})do headers+=1;check(k:lower()=='content-type'or k:lower()=='x-api-key','only content-type and x-api-key headers ('..k..')')end
 check(req and req.Url=='https://apis.roblox.com/cloud/v2/users/601/notifications'and req.Method=='POST'and headers==2,'POST cloud/v2/users/{id}/notifications')
 check(req and type(req.Headers['x-api-key'])=='table'and req.Headers['x-api-key'].Secret=='PlantReadyKey','the key is the Secret from the secrets store (never a string)')
 check(body and body.source.universe=='universes/4242'and body.payload.messageId=='5dd7024b-68e3-ac4d-8232-4217f86ca244'and body.payload.type=='MOMENT','source.universe, payload.messageId (trimmed), payload.type MOMENT')
 check(body and body.payload.parameters.plantName.stringValue==melon and body.payload.joinExperience.launchData=='PlantReady'and #body.payload.joinExperience.launchData<=200
  and body.payload.analyticsData.category=='PlantReady','parameters.plantName.stringValue, joinExperience.launchData (<= 200 bytes), analyticsData.category')
 present[601]=A;clearAll()
 W.game.GameId=0
 local okSend,kind=s1:Send(601,melon);check(okSend==false and kind=='setup'and #requests==0,'an unpublished place (GameId 0) sends nothing and says why')
 W.game.GameId=4242
end)

-- 10. Owner status + test command, and the startup line.
section('10',function()
 Social.Current=s1
 local okc,text=Social.Command({},A,{})
 check(okc and text:find('Plant-ready notifications: ON',1,true)and text:find('Queue:',1,true)and text:find('You:',1,true),'plantnotify: status ('..tostring(text):gsub('\n',' / ')..')')
 Http.HttpEnabled=false;secrets.PlantReadyKey=nil
 local _,bad=Social.Command({},A,{'status'})
 check(bad:find('NOT WORKING',1,true)and bad:find('Allow HTTP Requests',1,true)and bad:find("'PlantReadyKey'",1,true),'status names what is missing (HTTP, secret)')
 check(#s1:CheckSetup()==2 and warned('cannot send'),'the server says so in the console when it starts')
 Http.HttpEnabled=true;secrets.PlantReadyKey=true
 local okSendCmd,sendText=Social.Command({},A,{'send'})
 check(okSendCmd and #requests==1 and requests[1].Url:find('/601/',1,true)and sentMap().Items['601']~=nil,'plantnotify send: one to you right now, even in the game ('..tostring(sendText)..')')
 local okReset=Social.Command({},A,{'reset'});check(okReset and sentMap().Items['601']==nil,'plantnotify reset clears your cooldown')
 check(not Social.Command({},A,{'nope'}),'plantnotify with a bad word: usage')
 local O=W.B.OwnerUpdateCommands82
 check(O:find('X.Actions.plantnotify=true',1,true)and O:find("if action=='plantnotify'then return require(script.Parent.SocialService).Command(ctx,p,a)end",1,true),'the owner command is wired (OwnerUpdateCommands82)')
 check(W.B.StudioTestHelp:find('/test plantnotify',1,true)~=nil,'and listed in help')
 folder.SocialService:SetAttribute('MessageId',nil)
 local _,offText=Social.Command({},A,{});check(offText:find('MessageId',1,true),'without a MessageId the status says to set it')
 folder.SocialService:SetAttribute('MessageId','5dd7024b-68e3-ac4d-8232-4217f86ca244')
end)

-- 11. Friend boost: a friend check that failed is tried again 30 s later (R140 waited for the next join).
section('11',function()
 local flaky=true
 function A.IsFriendsWith(_,id)if flaky then error('HTTP 500 (friends)',0)end;return id==602 end
 function B.IsFriendsWith(_,id)if flaky then error('HTTP 500 (friends)',0)end;return id==601 end
 present[601]=A;present[602]=B;present[603]=nil
 local fs=Social.new(Data,Notes);fs.Ready[A]=true;fs.Ready[B]=true
 fs:Recount(A);check(A:GetAttribute('FriendsInServer')==0 and fs.FriendRetryAt~=nil,'(the friends web call failed: no boost yet, a retry is set)')
 flaky=false;R.clock+=31;fs:Step(math.floor(R.clock))
 check(A:GetAttribute('FriendsInServer')==1 and B:GetAttribute('FriendsInServer')==1,'30 s later the check runs again and both get the boost')
end)

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
