--!nocheck
-- R151 pull announcements, part 2: the SERVER half on the Roblox mock with the REAL modules (PullAnnouncer, PullAnnounceRules, PlayerDataService, RarePackTests,
-- SeedPackRules, Config, OwnerUpdateCommands82, StudioTestHelp) and a MessagingService bus (announce_env.luau):
--  1. the hook: PlayerDataService:OpenSeedPack of a real pack announces a Legendary+ seed once the PULLER's reveal has shown the seed (PullAnnounceRules.RevealDelay, from
--     RarePullRules); a TEST pack (/test rarepacks), a given / granted seed, a Common pull and a changed threshold announce nothing; the odds are the seed's fixed chance (R153, SeedRarity153; they were the pack's own); the pull is
--     still announced when the puller has left (at once, there is no reveal left to spoil)
--  1a. timing per rarity: the line goes out at exactly that delay (to the puller and everybody else alike, never earlier), the publish to the other servers and the line the other
--     servers show come after it too; for every presentation the client can pick (Full / Calm / InPlace, quick) the delay is after the seed is shown; a leaving puller releases it
--  2. publishing: a Secret+ pull goes to the other servers; at most one publish per 5 s per server, pulls coalesce into one message under 1 kB, the pending list is
--     capped, a failed publish is retried (then dropped), a stale pull is never sent; Legendary / Mythic stay in the server
--  3. receiving: the origin server drops its own message (it shows the in-server version only), repeats, stale and future messages, an over-limit flood, malformed
--     messages and messages whose seed is unknown or below the threshold; the rarity is the local catalog's; only players with "Announcements from other servers" on
--  4. the subscription is retried with a growing wait until it works
--  5. records: PullAnnouncer.Announce({Kind='Record'...}): the scope (RecordScope: this server / nobody; R153: never another server, a Secret+ BestPull included, whatever Scope the caller
--     asks for), AfterReveal, To (private), the timing next to the pull line, what another (older) server's record message is worth here (nothing); owner commands: announce <seed>,
--     announce global <seed> [here], announce record
--  6. trust: no client -> server remote exists, nothing a player types is broadcast
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
-- The mock runs the tasks that are due at the END of a step, and a task started inside a step waits for the next one: long jumps are cut into quarter seconds, so a chain of
-- retries (publish, wait 5 s, publish ...) plays out the way it does in a running server.
do local raw=R.advance;R.advance=function(dt)local n=math.max(1,math.ceil(dt/.25-1e-9));for _=1,n do raw(dt/n)end end end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local Http=W.service('HttpService')
local httpMock=E.http();Http.JSONEncode=httpMock.JSONEncode;Http.JSONDecode=httpMock.JSONDecode;Http.GenerateGUID=httpMock.GenerateGUID
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return p~=nil end,Publish=function()return true end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Packs=W.module('SeedPackRules');local Rules=W.module('PullAnnounceRules');local Mod=W.RS.PullAnnounceRules
local Announcer=server('PullAnnouncer')
local function drawConstant(x)return function()return x end end
local function firstOf(rarity)for _,spec in ipairs(Packs.SeedDesigns)do if spec.id~='VeritySeed'and Packs.GetRarity(spec.id)==rarity then return spec end end end
local KING=firstOf('King');local kingKey=KING.name:lower():gsub('[^%w]','')
local function reset()for k in pairs(Rules.Defaults)do Mod:SetAttribute(k,nil)end end
R.clock=20000*86400+3600
local function unix()return 1700000000+math.floor(R.clock)end

-- helpers --------------------------------------------------------------------------------------------------------------------------------------------
local function remoteLog()
 local remote=R.new('RemoteEvent');remote.Name='PullAnnounce151';local log={}
 remote.FireClient=function(_,p,payload)log[#log+1]={Player=p,Payload=payload,At=R.clock}end
 return remote,log
end
local function newPlayer(id,name,parent)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=parent or Players;return p
end
local function ofKind(log,kind)local out={};for _,l in ipairs(log)do if l.Payload.Kind==kind then out[#out+1]=l end end;return out end
local function toPlayer(log,p)local out={};for _,l in ipairs(log)do if l.Player==p then out[#out+1]=l end end;return out end

-- 1. the hook: the real PlayerDataService:OpenSeedPack --------------------------------------------------------------------------------------------------
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local Notes={Show=function()end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
local function makePlayer(id,name,data)
 data=data or Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name..' D';p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p);assert(data:Load(p),'load '..name)
 return p
end
local function addPack(player,stage,variant,version)return Data:AddChest(player,{Stage=stage,BagVariant=variant,PackSize=1,PackMutation='None',OddsVersion=version or Packs.OddsVersion})end
-- A constant draw that rolls the wanted rarity from some real pack (the roll is the game's own; only the dice are fixed).
local found={}
local function findDraw(rarity)
 if found[rarity]then return table.unpack(found[rarity])end
 local variants={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','EclipseReliquary'}
 local draws={0,1e-12,1e-9,1e-6,1e-4,.001,.005,.01,.02,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,.95,.99,.999,.99999,.9999999}
 for _,stage in ipairs({7,4,5,3,2,6,1})do for _,variant in ipairs(variants)do for _,d in ipairs(draws)do
  local ok,seed,r=pcall(Packs.Roll,Config,stage,drawConstant(d),1,variant,Packs.OddsVersion)
  if ok and seed and r==rarity and(variant~='EclipseReliquary'or stage==7)then found[rarity]={stage,variant,d,seed.Id};return stage,variant,d,seed.Id end
 end end end
end
local order5={'Legendary','Mythic','Secret','Cosmic','King'}
local have={};for _,rarity in ipairs(order5)do local stage,variant,d,seed=findDraw(rarity);have[rarity]=stage~=nil end
check(have.Legendary and have.Mythic and have.Secret and have.Cosmic and have.King,'the roll finds a real pack and draw for every rarity from Legendary to King (the test opens REAL packs)')
local commonStage,commonVariant,commonDraw=1,'Pack01',.5
do local seed,rarity=Packs.Roll(Config,1,drawConstant(.5),1,'Pack01',Packs.OddsVersion);check(seed and rarity=='Common','a Common pack roll for the control ('..tostring(rarity)..')')end

local Sink,sinkLog=remoteLog()
local bus=E.bus(function()return R.clock end,unix)
local A=Announcer.new({Data=Data,Players=Players,Http=Http,Messaging=bus:Server('A'),Remote=Sink,Clock=function()return R.clock end,Time=unix,JobId='job-A-0000',Warn=function()end})
Announcer.Instance=A;A:Run()
local Ann=makePlayer(701,'Ann');local Bob=makePlayer(702,'Bob')
local function openReal(player,rarity)
 local stage,variant,d=findDraw(rarity)
 local pack=addPack(player,stage,variant)
 return Data:OpenSeedPack(player,pack.Id,drawConstant(d)),pack
end
local function settle(seconds)R.advance(seconds or 10)end
local Reveal=W.module('RarePullRules')
local function waitFor(rarity)return Rules.RevealDelay(rarity)end -- the line goes out this long after the open (the puller's reveal has shown the seed, plus the margin)
do
 -- a real Legendary open
 local reward,pack=openReal(Ann,'Legendary')
 check(reward and reward.Rarity=='Legendary','a real Legendary open: '..tostring(reward and reward.SeedId))
 check(#sinkLog==0,'nothing is shown at the moment of the open (the puller\'s reveal is just starting)')
 R.advance(waitFor('Legendary')-.2);check(#sinkLog==0,'... nor just before the puller\'s reveal has shown the seed ('..string.format('%.2f',waitFor('Legendary'))..' s)')
 R.advance(.3)
 local pulls=ofKind(sinkLog,'Pull')
 check(#pulls==2 and#toPlayer(sinkLog,Ann)==1 and#toPlayer(sinkLog,Bob)==1,'once it has ended every player in the server is sent one Pull (the puller and the other player)')
 local e=pulls[1]and pulls[1].Payload
 check(e and e.SeedId==reward.SeedId and e.UserId==701 and e.Name=='Ann D'and e.Id and e.Id:match('^jobA0000%-%d+$'),'the payload names the seed, the puller (display name, user id) and carries an id ('..tostring(e and e.Id)..')')
 local percent=Packs.SeedOdds(Config,pack.Stage,pack.BagVariant,Ann:GetAttribute('ChestLuckMultiplier'),pack.OddsVersion,pack.RateBoost)[reward.SeedId]
 local fixed=W.module('SeedRarity153').Canonical(reward.SeedId)
 check(e and fixed and math.abs(e.Odds-fixed)<1e-9*e.Odds,'R153: the odds are the seed\'s fixed chance: 1/'..tostring(e and e.Odds)..' (this pack\'s own chance for it was SeedOdds '..tostring(percent)..'%; test_seed_rarity.luau opens a real Void pack)')
 check(e and e.Size==nil and e.Mutation==nil and e.Rarity==nil,'the payload carries no size, no coat and no rarity (chat lines need none of them; the client reads its own catalog)')
 check(bus:Count('A')==0,'a Legendary pull is NOT sent to other servers (Secret and above only)')
 table.clear(sinkLog)
 -- a Mythic open the same way
 local mythic=openReal(Bob,'Mythic');settle(waitFor('Mythic')+.5)
 check(mythic.Rarity=='Mythic'and#ofKind(sinkLog,'Pull')==2 and bus:Count('A')==0,'a real Mythic open: shown to both players, not published')
 table.clear(sinkLog)
 -- Common: nothing at all
 local pc=addPack(Ann,commonStage,commonVariant);local rc=Data:OpenSeedPack(Ann,pc.Id,drawConstant(commonDraw));settle(15)
 check(rc.Rarity=='Common'and#sinkLog==0 and#A.Pending==0,'a Common open announces nothing')
 -- the reveal delay grows with the rarity (the puller\'s screen is busy until then)
 check(waitFor('Mythic')>waitFor('Legendary')and waitFor('King')>waitFor('Cosmic')and waitFor('Cosmic')>waitFor('Secret')and waitFor('Secret')>waitFor('Mythic'),'the wait follows the puller\'s reveal (Legendary '..string.format('%.2f',waitFor('Legendary'))..' s ... King '..string.format('%.2f',waitFor('King'))..' s)')
end

-- TEST packs and granted seeds never announce
do
 local counted=0;local realPulled=A.Pulled
 A.Pulled=function(self,...)counted+=1;return realPulled(self,...)end
 table.clear(sinkLog)
 local Tests=server('RarePackTests')
 for _,rarity in ipairs({'legendary','mythic','secret','cosmic','king'})do
  local ok,msg=Tests.Grant(Data,Ann,rarity,Ann);check(ok,'/test rarepacks '..rarity..' grants a TEST pack: '..tostring(msg))
 end
 local ok2=Tests.Grant(Data,Ann,'all',Ann);check(ok2,'/test rarepacks all')
 local opened,rarities=0,{}
 for _,r in ipairs(table.clone(Data:GetChestRecords(Ann)))do
  if r.Kind=='Pack'and Tests.Expected(Data,Ann,r.Id)then
   local reward=Data:OpenSeedPack(Ann,r.Id,drawConstant(.5));opened+=1;rarities[#rarities+1]=reward and reward.Rarity or'?'
  end
 end
 settle(30)
 check(opened>=10,'ten TEST packs opened ('..opened..'): '..table.concat(rarities,','))
 check(counted==opened,'the hook was asked about every one of them ('..counted..')')
 check(#sinkLog==0 and bus:Count('A')==0 and#A.Pending==0,'... and none of them was announced or published (TEST packs are excluded)')
 -- the same seeds given / granted outside a pack open never reach the hook
 counted=0
 local seedPack=addPack(Ann,2,'Pack01');Data:RemoveChest(Ann,seedPack.Id)
 local records=Data:GetChestRecords(Ann)
 table.insert(records,{Id='gift-1',Kind='Seed',ChestNumber=900,ChestName='Obsidian Maw Seed',Stage=3,SeedId='ObsidianMawSeed',SeedName='Obsidian Maw Seed',Rarity='Secret',SeedScale=1,BagVariant='Pack01',PackSize=1,PackMutation='None'})
 Data:MarkSeedDiscovered(Ann,'ObsidianMawSeed',true);settle(30)
 check(counted==0 and#sinkLog==0,'a seed that is granted / gifted (a record, MarkSeedDiscovered) is never a pack open: nothing announced')
 A.Pulled=realPulled
end
-- a real open still works right after the tests (the TEST override did not stick)
do
 table.clear(sinkLog)
 local reward=openReal(Ann,'Secret');settle(waitFor('Secret')+.5)
 check(reward.Rarity=='Secret'and#ofKind(sinkLog,'Pull')==2,'a real Secret open right after TEST packs is announced in the server')
 check(bus:Count('A')==1,'... and published once to the other servers')
 local m=bus.Log[#bus.Log]
 check(m and#m.Message<=1000 and m.Topic=='PullAnnounce151','... on topic PullAnnounce151, '..tostring(m and m.Bytes)..' bytes')
 local d=E.decode(m.Message)
 check(d.v==1 and d.j=='job-A-0000'and d.t>=1700000000 and d.t<=unix(),'... with the origin job id and the time it was sent')
 check(#d.p==1 and d.p[1].s==reward.SeedId and d.p[1].u==701 and d.p[1].n=='Ann D'and type(d.p[1].o)=='number','... and the pull: seed, user id, display name, odds')
 -- the puller leaves during the reveal: the pull is still announced
 table.clear(sinkLog)
 local reward2=openReal(Bob,'Legendary')
 present[Bob.UserId]=nil;Bob.Parent=nil
 settle(waitFor('Legendary')+.5)
 check(reward2.Rarity=='Legendary'and#ofKind(sinkLog,'Pull')==1 and sinkLog[1].Player==Ann,'a puller who leaves during the reveal is still announced (to the players that are left)')
 present[Bob.UserId]=Bob;Bob.Parent=Players
 -- a changed threshold
 table.clear(sinkLog);Mod:SetAttribute('InServerMinRarity','Mythic')
 openReal(Ann,'Legendary');settle(15)
 check(#sinkLog==0,'InServerMinRarity = Mythic: a Legendary open is not announced')
 openReal(Ann,'Mythic');settle(15)
 check(#ofKind(sinkLog,'Pull')==2,'... a Mythic one is');reset()
 -- a bad pack record / reward never throws
 check(A:Pulled(Ann,nil,nil,false)==false and A:Pulled(nil,{},{},false)==false and A:Pulled(Ann,{},{Rarity='Secret',SeedId='NoSuchSeed'},false)==false,'a missing or unknown pack / reward is refused quietly')
 check(select(2,A:Pulled(Ann,{Stage=1,BagVariant='Pack01'},{Rarity='Mythic',SeedId='SunflowerSeed'},false))=='rarity mismatch','a reward whose rarity differs from the catalog is not announced')
 check(select(2,A:Pulled(Ann,{},{Rarity='Secret',SeedId='ObsidianMawSeed'},true))=='test pack','wasTest = true: refused with the reason "test pack"')
 -- the module-level hook the data service calls
 check(Announcer.OnOpened(Ann,{},{Rarity='Common',SeedId='SunflowerSeed'},false)==false,'the module function OnOpened works through the running instance')
end

-- 1a. timing per rarity: the line goes out only after the PULLER's reveal has shown the seed ---------------------------------------------------------------------------
-- A second server (B) listens on the same bus: when it shows the other-server line is the cross-server timing. Every step below is .01 s, so the times are exact.
local zed=newPlayer(951,'Zed',nil)
local SinkB,logB=remoteLog()
local B=Announcer.new({Data=nil,Players={GetPlayers=function()return {zed}end},Http=Http,Messaging=bus:Server('B'),Remote=SinkB,Clock=function()return R.clock end,Time=unix,JobId='job-B-0000',Warn=function()end})
B:Run()
local timing={}
-- the latest moment ANY presentation the puller's client can pick shows the seed, read straight from the client's own tables (not through the function under test)
local function shownByTables(rank)
 if rank<=5 then local c=Reveal.CardTimeline(rank,false);return math.max(c.Burst,c.Odds)end
 local latest=0
 for _,tl in ipairs({Reveal.Scenes[rank].Full,Reveal.Scenes[rank].Calm,Reveal.InPlace(rank)})do latest=math.max(latest,tl.Climax,tl.Rise or 0,tl.Odds or 0)end
 return latest
end
local function runUntil(limit,fn)local n=0;while n<limit/.01 do R.advance(.01);n+=1;if fn()then return true end end;return false end
do
 for _,rarity in ipairs({'Legendary','Mythic','Secret','Cosmic','King'})do
  local rank=Packs.Rarities[rarity].Rank
  R.advance(30);table.clear(sinkLog);table.clear(logB)
  local published=bus:Count('A')
  local t0=R.clock
  local reward=openReal(Ann,rarity)
  check(reward and reward.Rarity==rarity,rarity..': a real open ('..tostring(reward and reward.SeedId)..')')
  local want=shownByTables(rank)+Rules.Defaults.RevealMargin
  runUntil(20,function()return#sinkLog>=2 end)
  local annAt,bobAt=toPlayer(sinkLog,Ann)[1],toPlayer(sinkLog,Bob)[1]
  local first=sinkLog[1]
  check(first and annAt and bobAt,rarity..': the puller and the other player both get the line')
  local at=first and first.At-t0 or -1
  timing[#timing+1]={rarity,at}
  check(math.abs(at-Rules.RevealDelay(rarity))<=.011,rarity..': the line goes out at exactly RevealDelay ('..string.format('%.2f',at)..' s after the open, RevealDelay '..string.format('%.2f',Rules.RevealDelay(rarity))..' s)')
  check(at>=want-1e-9 and at<=want+.011,rarity..': ... = the latest seed-shown moment of the client\'s tables + the margin ('..string.format('%.2f',want)..' s)')
  check(annAt and bobAt and annAt.At==bobAt.At and annAt.At>=t0+want-1e-9,rarity..': the puller and everybody else get it at the same moment, never before the puller\'s seed is shown')
  -- after the hit of every presentation the client can pick (the seed is already on the puller's screen), still while the scene / card is on screen
  local early=true
  if rank<=5 then
   for _,quick in ipairs({false,true})do local c=Reveal.CardTimeline(rank,quick);if at<c.Burst or at<c.Odds then early=false end end
   check(early and at<=Reveal.CardTimeline(rank,false).Length,rarity..': after the seed card\'s hit and "1 in N" (quick or not), before the card is gone ('..string.format('%.2f',Reveal.CardTimeline(rank,false).Length)..' s)')
  else
   for _,variant in ipairs({'Full','Calm','InPlace'})do local tl=Reveal.Timeline(rank,variant);if at<tl.Climax or at<tl.Odds or at<(tl.Rise or 0)then early=false end end
   local full=Reveal.Timeline(rank,'Full')
   check(early,rarity..': after the hit, the rise and the "1 in N" of the Full, Calm and InPlace scenes')
   check(at<=full.Back,rarity..': ... and before the Full scene hands the world back ('..string.format('%.2f',full.Back)..' s)')
   check(at>full.Climax+.35,rarity..': ... later than a cut-short scene\'s result card (a danger cut shows it before the hit, plus .35 s)')
  end
  -- the other servers
  if Rules.Qualifies('Global',rarity)then
   check(bus:Count('A')==published+1,rarity..': published once')
   local m=bus.Log[#bus.Log]
   check(m and math.abs((m.At-t0)-at)<=.011 and m.At-t0>=want-1e-9,rarity..': the publish is at the same moment, not before the puller\'s seed is shown ('..string.format('%.2f',m and m.At-t0 or -1)..' s)')
   check(#logB==1 and logB[1].Payload.Kind=='Global'and logB[1].At-t0>=want-1e-9,rarity..': server B shows its other-server line then, never earlier ('..string.format('%.2f',logB[1]and logB[1].At-t0 or -1)..' s)')
  else
   check(bus:Count('A')==published and#logB==0,rarity..': stays in this server: nothing published, nothing in B')
  end
 end
 local row={};for _,t in ipairs(timing)do row[#row+1]=t[1]..' '..string.format('%.2f',t[2])end
 print('timing (seconds after the open): '..table.concat(row,'  '))
end
-- every presentation the client can pick shows the seed before the line (a table check; the real cinematic is played in test_rare_cinematic)
do
 for rank=1,8 do
  local name=Packs.RarityOrder[rank]
  local at=Rules.RevealDelay(name)
  local ok=true
  if rank<=5 then for _,quick in ipairs({false,true})do if Reveal.SeedShown(rank,nil,quick)+Rules.Defaults.RevealMargin>at+1e-9 then ok=false end end
  else for _,variant in ipairs(Reveal.StoryVariants)do if Reveal.SeedShown(rank,variant)+Rules.Defaults.RevealMargin>at+1e-9 then ok=false end end end
  check(ok,name..': RevealDelay is not before the seed is shown in any presentation (+ the margin)')
 end
 -- a skip only brings the hit sooner: the server cannot hear of it and posts at the normal time, which is still after the skipped seed
 for rank=6,8 do
  local name=Packs.RarityOrder[rank];local tl=Reveal.Timeline(rank,'Full')
  local skipped=tl.SkipFrom+(tl.Odds-(tl.Climax-.02)) -- skipped at the first moment it is allowed: the "1 in N" lands this long after the skip
  check(skipped<Rules.RevealDelay(name),name..': a skipped scene shows the seed earlier ('..string.format('%.2f',skipped)..' s) than the line comes ('..string.format('%.2f',Rules.RevealDelay(name))..' s)')
 end
 -- the margin and the unknown-rarity fallbacks
 Mod:SetAttribute('RevealMargin',2);check(math.abs(Rules.RevealDelay('King')-(Reveal.LatestSeedShown(8)+2))<1e-9,'RevealMargin is a tunable');reset()
 Mod:SetAttribute('RevealMargin',99);check(Rules.Setting('RevealMargin')==.5,'a margin outside 0..5 s is ignored');reset()
 check(Rules.RevealDelay('Banana')==Rules.RevealDelay('Common')and Rules.RevealDelay(nil)==Rules.RevealDelay('Common')and Rules.RevealDelay(5)>0,'an unknown rarity still gets a delay (and is never announced anyway)')
 Packs.Rarities.Mythical={Rank=9,Weight=.001,Color=R.Color3.fromRGB(255,255,255)}
 check(Rules.RevealDelay('Mythical')==Rules.RevealDelay('King'),'a rarity above King waits like King (the longest scene)');Packs.Rarities.Mythical=nil
end
-- the puller leaves before the line is due: it goes out at once, once; another player leaving changes nothing
do
 for _,rarity in ipairs({'Legendary','Secret'})do
  R.advance(30);table.clear(sinkLog);table.clear(logB)
  local published=bus:Count('A');local t0=R.clock
  local reward=openReal(Bob,rarity)
  runUntil(.6,function()return false end)
  check(#sinkLog==0 and reward.Rarity==rarity,rarity..': 0.6 s into the reveal nothing has been said')
  present[Bob.UserId]=nil;Bob.Parent=nil;Players.PlayerRemoving:Fire(Bob)
  local leftAt=R.clock-t0
  local told=toPlayer(sinkLog,Ann)
  check(#told==1 and told[1].At-t0<=leftAt+1e-9 and told[1].Payload.Kind=='Pull'and told[1].Payload.UserId==702,rarity..': the puller leaves: the line goes out at once ('..string.format('%.2f',told[1]and told[1].At-t0 or -1)..' s, not at '..string.format('%.2f',waitFor(rarity))..' s)')
  if Rules.Qualifies('Global',rarity)then
   check(bus:Count('A')==published+1 and bus.Log[#bus.Log].At-t0<=leftAt+1e-9 and#logB==1,rarity..': ... and it is published to the other servers at once too')
  end
  local n=#sinkLog;R.advance(waitFor(rarity)+10)
  check(#sinkLog==n and bus:Count('A')==published+(Rules.Qualifies('Global',rarity)and 1 or 0),rarity..': ... and not said again at the normal time')
  present[Bob.UserId]=Bob;Bob.Parent=Players
 end
 -- someone ELSE leaves: the line still waits for the puller's reveal
 R.advance(30);table.clear(sinkLog);local t0=R.clock
 openReal(Ann,'Mythic');runUntil(.5,function()return false end)
 present[Bob.UserId]=nil;Bob.Parent=nil;Players.PlayerRemoving:Fire(Bob)
 check(#sinkLog==0,'another player leaving does not release the puller\'s line')
 runUntil(10,function()return#sinkLog>=1 end)
 check(#toPlayer(sinkLog,Ann)==1 and math.abs(sinkLog[1].At-t0-waitFor('Mythic'))<=.02,'... it goes out at the normal time ('..string.format('%.2f',sinkLog[1]and sinkLog[1].At-t0 or -1)..' s) to the players still there')
 present[Bob.UserId]=Bob;Bob.Parent=Players
 -- Destroy cancels what is waiting
 local SinkD,logD=remoteLog();local D=Announcer.new({Data=Data,Players=Players,Http=Http,Remote=SinkD,Clock=function()return R.clock end,Time=unix,JobId='job-D-0000',Warn=function()end});D:Run()
 local stage,variant,draw=findDraw('Mythic')
 local pack=addPack(Ann,stage,variant)
 local rw=Data:OpenSeedPack(Ann,pack.Id,drawConstant(draw))
 D:Pulled(Ann,pack,rw,false);D:Destroy();R.advance(20)
 check(rw~=nil and#logD==0,'an announcer that is destroyed while a line waits sends nothing')
end
B:Destroy()

-- 1b. packs an owner / admin command made are TEST packs (TestGrant on the record): never announced, in the server or to other servers; the same packs from real sources are -----
-- Every command goes through the REAL StudioTestCommands.Execute (what /test and F4 call), so the Normalize / Targeting / OwnerUpdateCommands82 routing is the game's own.
local TestPacks=server('OwnerTestPacks');local Studio=server('StudioTestCommands');local M=W.module('MysteryPackRules');local D=W.module('DailyRewards')
local DRAWS={0,1e-12,1e-9,1e-6,1e-4,.001,.005,.01,.02,.05,.1,.2,.3,.4,.5,.6,.7,.8,.9,.95,.99,.999,.99999,.9999999}
local function loud(pack,player) -- a draw that rolls a Legendary+ seed from this pack: an UNMARKED pack opened with it WOULD be announced
 for _,d in ipairs(DRAWS)do
  local ok,seed,r=pcall(Packs.Roll,Config,pack.Stage,drawConstant(d),player:GetAttribute('ChestLuckMultiplier'),pack.BagVariant,pack.OddsVersion,pack.RateBoost)
  if ok and seed and Rules.Qualifies('InServer',r)then return d,r end
 end
end
local function emptyBag(p)local records=Data:GetChestRecords(p);for i=#records,1,-1 do table.remove(records,i)end end
local function packsOf(p)local out={};for _,r in ipairs(Data:GetChestRecords(p))do if r.Kind=='Pack'then out[#out+1]=r end end;return out end
local spy
local function watch()spy={Calls=0,Reasons={},Published=bus:Count('A')};local real=A.Pulled;spy.Real=real
 A.Pulled=function(self,...)local ok,why=real(self,...);spy.Calls+=1;spy.Reasons[#spy.Reasons+1]=ok and'announced'or tostring(why);return ok,why end end
local function unwatch()A.Pulled=spy.Real end
local function count(list,value)local n=0;for _,x in ipairs(list)do if x==value then n+=1 end end;return n end
-- opens every pack in the bag with a Legendary+ draw where the pack has one; returns opened, loud
local function openAll(p)
 local opened,loudCount=0,0
 for _,r in ipairs(packsOf(p))do
  local d=loud(r,p);local reward=Data:OpenSeedPack(p,r.Id,drawConstant(d or .5));opened+=1
  if d and reward and Rules.Qualifies('InServer',reward.Rarity)then loudCount+=1 end
 end
 return opened,loudCount
end
local Notes2={Show=function()end}
local ctx2={Config=Config,Data=Data,Map={MapRoot={}},Bases={GetPlayerBase=function()return nil end},Chests={IsOpening=function()return false end,SyncTools=function()end},Chase={IsPlayerBusy=function()return false end}}
local Bonus=server('TreadmillBonusService').new(Config,Data,{TrainingSessions={}},ctx2.Chests,Notes2)
local Mystery=server('MysteryPackService').new(Config,Data,nil,ctx2.Chests,Notes2,nil)
ctx2.Chase.TreadmillBonus=Bonus;ctx2.Chase.Mystery=Mystery
local function command(p,text)return Studio.Execute(ctx2,p,text)end
do
 -- the unit: OwnerTestPacks
 check(TestPacks.Field=='TestGrant'and TestPacks.Mark({Kind='Pack'}).TestGrant==true and TestPacks.Mark({Kind='Seed'}).TestGrant==nil and TestPacks.Mark(nil)==nil,'OwnerTestPacks.Mark sets TestGrant on a pack record only')
 check(TestPacks.Is({TestGrant=true})and not TestPacks.Is({})and not TestPacks.Is({TestGrant='yes'})and not TestPacks.Is(nil),'OwnerTestPacks.Is is exactly "TestGrant == true"')
 local who={}
 check(TestPacks.Arm(who,'Mystery',1,100)and TestPacks.Armed(who,'Mystery',100)and not TestPacks.Armed(who,'Daily',100),'Arm is per player and per source')
 check(not TestPacks.Arm(who,'Nonsense')and not TestPacks.Arm(nil,'Mystery')and not TestPacks.Arm(who,'Mystery',0),'an unknown source, no player or a count of 0 arms nothing (and a 0 clears)')
 TestPacks.Arm(who,'Bonus',2,100)
 check(TestPacks.Take(who,'Bonus',101)and TestPacks.Take(who,'Bonus',102)and not TestPacks.Take(who,'Bonus',103),'an arm for 2 packs marks exactly 2')
 TestPacks.Arm(who,'Daily',1,100);check(not TestPacks.Take(who,'Daily',100+TestPacks.Seconds+1)and not TestPacks.Armed(who,'Daily',100),'an arm ends after '..TestPacks.Seconds..' s')
 TestPacks.Arm(who,'Daily',1,100);TestPacks.Disarm(who,'Daily');check(not TestPacks.Take(who,'Daily',101),'Disarm clears it')
 local rec={Kind='Pack'};TestPacks.Arm(who,'Mystery',1,R.clock)
 check(TestPacks.Claim(who,'Mystery',rec)==rec and rec.TestGrant==true,'Claim marks the record that was just made and uses the arm up')
 local rec2={Kind='Pack'};check(TestPacks.Claim(who,'Mystery',rec2)==rec2 and rec2.TestGrant==nil and TestPacks.Claim(who,'Mystery',nil)==nil,'... the next pack is a normal pack (and a nil record is harmless)')
 -- the pack record
 Ann:SetAttribute('PaidRandomAllowed',true) -- (a bought pack opens only where paid random items are allowed)
 local plain=Data:AddChest(Ann,{Stage=7,BagVariant='Pack06',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
 local marked=Data:AddChest(Ann,{Stage=7,BagVariant='Pack06',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{TestGrant=true})
 local lucky=Data:AddChest(Ann,{Stage=7,BagVariant='Pack06',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{Luck=true})
 check(plain.TestGrant==nil and lucky.TestGrant==nil and marked.TestGrant==true,'AddChest: TestGrant only with the option (a normal pack and a Luck pack carry nothing)')
 emptyBag(Ann)
end

do
 -- every direct command path: the packs it makes carry TestGrant, and opening them announces nothing
 local paths={
  {'/test pack storm 6','pack (one)'},{'/test pack lava 5 1 none 3','pack (three)'},{'/test packset storm','packset'},{'/test void 2','void'},{'/test eclipse 1','eclipse'},
  {'/test verity 2','verity'},{'/test rarepacks all','rarepacks all'},{'/test rarepacks verity','rarepacks verity'},{'/test rarepacks mech','rarepacks mech'},{'/test rarepacks roster','rarepacks roster'},
  {'/test rarepacks mythic','rarepacks mythic'},
 }
 for _,path in ipairs(paths)do
  emptyBag(Ann);table.clear(sinkLog);watch()
  local ok,msg=command(Ann,path[1]);check(ok==true,path[2]..': the command works ('..tostring(msg)..')')
  local packs=packsOf(Ann);local allMarked=#packs>0
  for _,r in ipairs(packs)do if r.TestGrant~=true then allMarked=false end end
  check(allMarked,path[2]..': all '..#packs..' packs it made carry TestGrant')
  local opened,loudCount=openAll(Ann);settle(30)
  check(opened==#packs and(loudCount>=1 or path[1]:find('rarepacks')),path[2]..': opened '..opened..', '..loudCount..' of them Legendary+ (an unmarked pack would have been announced)')
  check(#sinkLog==0 and bus:Count('A')==spy.Published and#A.Pending==0,path[2]..': nothing was announced in the server or published to other servers')
  check(spy.Calls==opened and count(spy.Reasons,'test pack')==opened and count(spy.Reasons,'announced')==0,path[2]..': the announcer was asked for every open and refused each one as a "test pack" ('..table.concat(spy.Reasons,',')..')')
  unwatch()
 end
 -- /test seed makes SEEDS (never opened): no mark on them
 emptyBag(Ann)
 local okSeed=command(Ann,'/test seed SunflowerSeed');local seeds=Data:GetChestRecords(Ann)
 check(okSeed==true and#seeds==1 and seeds[1].Kind=='Seed'and seeds[1].TestGrant==true,'/test seed makes a Seed record WITH the mark (R152: an owner-given seed is a TEST seed; R151 left it unmarked)')
 emptyBag(Ann)
end

-- a pack with a guaranteed-reveal override (StudioPackRewards, what /test rarepacks sets) is excluded even when its record carries no TestGrant: the hook's own wasTest flag
do
 emptyBag(Ann);table.clear(sinkLog);watch()
 local pack=Data:AddChest(Ann,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
 check(pack.TestGrant==nil,'(a normal Void pack, no mark)')
 Data.StudioPackRewards=Data.StudioPackRewards or setmetatable({},{__mode='k'})
 Data.StudioPackRewards[Ann]=Data.StudioPackRewards[Ann]or{};Data.StudioPackRewards[Ann][pack.Id]='ObsidianMawSeed'
 local reward=Data:OpenSeedPack(Ann,pack.Id,drawConstant(.5));settle(30)
 check(reward and reward.SeedId=='ObsidianMawSeed'and#sinkLog==0 and bus:Count('A')==spy.Published and spy.Reasons[1]=='test pack','a guaranteed-reveal pack without TestGrant is still a test pack (the hook passes wasTest): not announced, not published')
 unwatch();emptyBag(Ann)
end

-- a TestGrant pack is excluded even when nothing else marks it as a test (no StudioPackRewards override): the flag alone is enough
do
 table.clear(sinkLog);watch()
 local pack=Data:AddChest(Ann,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{TestGrant=true})
 local reward=Data:OpenSeedPack(Ann,pack.Id,drawConstant(.5));settle(30)
 check(reward and Rules.Qualifies('Global',reward.Rarity)and#sinkLog==0 and bus:Count('A')==spy.Published and spy.Reasons[1]=='test pack','a marked Void pack (a Secret+ seed) is not announced and not published: TestGrant alone is enough ('..tostring(reward and reward.Rarity)..')')
 unwatch()
end

-- the indirect commands: they only make a normal reward claimable, and arm that source for the player
do
 -- mystery ready: the pack that is then taken is a TEST pack
 emptyBag(Ann);table.clear(sinkLog);watch()
 Mystery.Random={NextNumber=function()return .9999999 end} -- the rarest mystery pack (the Void pack)
 local pedestal={}
 Mystery.Owner[Ann]=pedestal
 local ok=command(Ann,'/test mystery ready');check(ok==true and TestPacks.Armed(Ann,'Mystery'),'/test mystery ready arms the mystery source')
 local st=Mystery:State(Ann);Mystery:Unlock(Ann,st)
 check(M.Unlocked(st)and st.Variant=='EclipseReliquary','the mystery pack unlocks (Void pack, rarest)')
 check(Mystery:Claim(Ann,pedestal)==true,'... and is taken')
 local packs=packsOf(Ann)
 check(#packs==1 and packs[1].TestGrant==true and not TestPacks.Armed(Ann,'Mystery'),'the pack taken after "mystery ready" carries TestGrant and the arm is used up')
 openAll(Ann);settle(30)
 check(#sinkLog==0 and bus:Count('A')==spy.Published and spy.Reasons[1]=='test pack','... and opening it announces nothing')
 -- the next mystery pack (a new day, no command) is a normal pack and IS announced
 emptyBag(Ann);Data:GetPremium(Ann).Mystery=nil;R.clock+=86400*2;table.clear(sinkLog)
 local st2=Mystery:State(Ann);Mystery:Unlock(Ann,st2);Mystery:Claim(Ann,pedestal)
 local packs2=packsOf(Ann)
 check(#packs2==1 and packs2[1].TestGrant==nil,'a later mystery pack (no command) is a normal pack')
 local _,loudCount=openAll(Ann);settle(waitFor('King')+1)
 check(loudCount==1 and#ofKind(sinkLog,'Pull')>=1,'... and opening it IS announced')
 -- mystery next: a new day for the target; the arm must not survive for the new day's pack
 emptyBag(Ann);Data:GetPremium(Ann).Mystery=nil;R.clock+=86400*2;Mystery:State(Ann)
 command(Ann,'/test mystery next');check(not TestPacks.Armed(Ann,'Mystery'),'/test mystery next leaves nothing armed (a new day\'s pack is a normal one)')
 -- an arm that nobody used expires: a pack taken long after the command is a normal pack
 emptyBag(Ann);Data:GetPremium(Ann).Mystery=nil;R.clock+=86400*2
 command(Ann,'/test mystery ready');R.clock+=TestPacks.Seconds+60
 local st3=Mystery:State(Ann);Mystery:Unlock(Ann,st3);Mystery:Claim(Ann,pedestal)
 check(#packsOf(Ann)==1 and packsOf(Ann)[1].TestGrant==nil,'a "mystery ready" nobody used for '..TestPacks.Seconds..' s has expired: that pack is normal')
 Mystery.Owner[Ann]=nil;unwatch();emptyBag(Ann)
end
do
 -- daily week: the login pack (day 7 = a Void Pack since R153; it was a Mech pack) the target claims is a TEST pack; a later claim without a command is a normal Void pack
 emptyBag(Ann);table.clear(sinkLog);watch()
 local ok=command(Ann,'/test daily week');check(ok==true and TestPacks.Armed(Ann,'Daily'),'/test daily week arms the daily source')
 local claimed,msg=Data:ClaimDailyLogin(Ann);check(claimed==true,'the day 7 login claim works ('..tostring(msg)..')')
 local packs=packsOf(Ann)
 check(#packs==1 and packs[1].BagVariant=='EclipseReliquary'and packs[1].TestGrant==true and not TestPacks.Armed(Ann,'Daily'),'the Void pack from the claim carries TestGrant; the arm is used up')
 openAll(Ann);settle(30)
 check(#sinkLog==0 and bus:Count('A')==spy.Published and spy.Reasons[1]=='test pack','... and opening it announces nothing')
 emptyBag(Ann);table.clear(sinkLog)
 local day=D.Day(os.time());local daily=Data:DailyData(Ann);daily.Login={Step=#D.Login-1,Day=day-1}
 local claimed2=Data:ClaimDailyLogin(Ann);local packs2=packsOf(Ann)
 check(claimed2==true and#packs2==1 and packs2[1].BagVariant=='EclipseReliquary'and packs2[1].TestGrant==nil,'the next day 7 Void pack (no command) is a normal pack')
 local _,loudCount=openAll(Ann);settle(waitFor('King')+1)
 check(loudCount==1 and#ofKind(sinkLog,'Pull')>=1,'... and opening it IS announced (Void seeds are Secret and above)')
 -- daily done (finishes the quests): R153 review M1: the quest packs it makes claimable are TEST packs too, on their own arm (the login pack's 'Daily' arm is not touched)
 TestPacks.Disarm(Ann,'Daily');TestPacks.Disarm(Ann,'DailyQuest');emptyBag(Ann);command(Ann,'/test daily done')
 check(not TestPacks.Armed(Ann,'Daily')and TestPacks.Armed(Ann,'DailyQuest'),'/test daily done arms the quest packs (DailyQuest), not the login pack (Daily)')
 local q=Data:ClaimDailyQuest(Ann,1);local qp=packsOf(Ann)
 check(q==true and#qp==1 and qp[1].TestGrant==true,'... the quest pack it made claimable carries TestGrant')
 unwatch();emptyBag(Ann)
end
do
 -- bonus: roll / ready / progress
 emptyBag(Ann);table.clear(sinkLog);watch()
 Bonus:Setup(Ann);Bonus.Random={NextNumber=function()return .9999999 end}
 Bonus:GrantReady(Ann,1);R.advance(2) -- a NATURAL ready roll (no owner command gave it)
 local ok,msg=command(Ann,'/test bonus roll');check(ok==true,'/test bonus roll works ('..tostring(msg)..')')
 local packs=packsOf(Ann)
 check(#packs==1 and packs[1].TestGrant==true and not TestPacks.Armed(Ann,'Bonus'),'the pack of an owner "bonus roll" carries TestGrant and nothing stays armed')
 openAll(Ann);settle(30)
 check(#sinkLog==0 and bus:Count('A')==spy.Published and spy.Reasons[1]=='test pack','... and opening it announces nothing')
 -- bonus ready 2: the player rolls twice (test packs); a third, natural roll is a normal pack
 emptyBag(Ann);table.clear(sinkLog);spy.Reasons={}
 command(Ann,'/test bonus ready 2');check(TestPacks.Armed(Ann,'Bonus'),'/test bonus ready 2 arms the source')
 R.advance(2);local r1=Bonus:Roll(Ann);R.advance(2);local r2=Bonus:Roll(Ann)
 check(r1.Ok and r2.Ok and#packsOf(Ann)==2 and packsOf(Ann)[1].TestGrant==true and packsOf(Ann)[2].TestGrant==true and not TestPacks.Armed(Ann,'Bonus'),'the two rolls of "bonus ready 2" are TEST packs and the arm is used up')
 Bonus:GrantReady(Ann,1);R.advance(2);local r3=Bonus:Roll(Ann)
 check(r3.Ok and#packsOf(Ann)==3 and packsOf(Ann)[3].TestGrant==nil,'a third roll (a natural one) is a normal pack')
 local opened,loudCount=openAll(Ann);settle(waitFor('King')+1)
 check(opened==3 and count(spy.Reasons,'test pack')==2 and count(spy.Reasons,'announced')==1,'of the three opens two are refused as test packs and the normal one is announced ('..table.concat(spy.Reasons,',')..')')
 -- bonus progress: one roll afterwards
 emptyBag(Ann);command(Ann,'/test bonus progress 5:50');check(TestPacks.Armed(Ann,'Bonus'),'/test bonus progress arms the source for one roll')
 TestPacks.Disarm(Ann,'Bonus');unwatch();emptyBag(Ann)
end

-- real sources still announce: a Robux / gems Mech purchase, a normal track pack (ChestService:Bank), a Void pack turned into a Verity pack
do
 emptyBag(Ann);table.clear(sinkLog);watch()
 local packs=Data:GrantMechPacks(Ann,true,1)
 check(packs and#packs==1 and packs[1].TestGrant==nil and packs[1].PaidRandom==true,'a bought Mech pack (GrantMechPacks, the Robux / gems path) carries no mark')
 local reward=Data:OpenSeedPack(Ann,packs[1].Id,drawConstant(.5));settle(waitFor(reward.Rarity)+1)
 check(reward and#ofKind(sinkLog,'Pull')==2 and spy.Reasons[1]=='announced','... and opening it IS announced ('..tostring(reward and reward.Rarity)..')')
 -- a normal pack banked from the track
 emptyBag(Ann);table.clear(sinkLog);spy.Reasons={}
 local Chests=server('ChestService')
 local banked=Chests.Bank({PlayerData=Data,SyncTools=function()end},Ann,{Stage=7,BagVariant='Pack06',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
 local testBanked=Chests.Bank({PlayerData=Data,SyncTools=function()end},Ann,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion,TestGrant=true})
 check(banked and banked.TestGrant==nil and testBanked and testBanked.TestGrant==true,'ChestService:Bank: a normal world pack carries no mark; a world pack of an owner-forced event (TestGrant on the world pack) is a TEST pack')
 local d=loud(banked,Ann);Data:OpenSeedPack(Ann,banked.Id,drawConstant(d));settle(waitFor('King')+1)
 check(#ofKind(sinkLog,'Pull')>=1 and spy.Reasons[1]=='announced','a normal banked pack IS announced')
 table.clear(sinkLog);Data:OpenSeedPack(Ann,testBanked.Id,drawConstant(.5));settle(30)
 check(#sinkLog==0 and spy.Reasons[2]=='test pack','... the forced-event world pack is not')
 -- Void -> Verity conversion keeps the mark either way
 emptyBag(Ann);table.clear(sinkLog)
 local voidReal=Data:AddChest(Ann,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
 local voidTest=Data:AddChest(Ann,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{TestGrant=true})
 local vReal=Data:ConvertVoidPack(Ann,voidReal.Id);local vTest=Data:ConvertVoidPack(Ann,voidTest.Id)
 check(vReal and vReal.TestGrant==nil and vTest and vTest.TestGrant==true and vTest.BagVariant==vReal.BagVariant,'a Void pack turned into a Verity pack keeps its mark (marked stays marked, a normal one stays normal)')
 spy.Reasons={};Data:OpenSeedPack(Ann,vReal.Id,drawConstant(0));settle(waitFor('King')+1)
 check(#ofKind(sinkLog,'Pull')>=1 and spy.Reasons[1]=='announced','a normal Verity pack IS announced (the Verity seed)')
 table.clear(sinkLog);Data:OpenSeedPack(Ann,vTest.Id,drawConstant(0));settle(30)
 check(#sinkLog==0 and spy.Reasons[2]=='test pack','... a test Verity pack is not')
 unwatch();emptyBag(Ann)
end

-- the mark is saved with the pack, survives a reload and a gift, and costs nothing else
do
 local pack=Data:AddChest(Ann,{Stage=3,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{TestGrant=true})
 local normal=Data:AddChest(Ann,{Stage=3,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
 local row,rowN=Data:SerializeSeedRecord(pack),Data:SerializeSeedRecord(normal)
 check(row.TestGrant==true and rowN.TestGrant==nil,'the saved row of a test pack has TestGrant=true; a normal pack\'s row has no such key')
 local keysTest,keysNormal={},{};for k in pairs(row)do keysTest[k]=true end;for k in pairs(rowN)do keysNormal[k]=true end
 local extra={};for k in pairs(keysTest)do if not keysNormal[k]then extra[#extra+1]=k end end
 check(#extra==1 and extra[1]=='TestGrant','TestGrant is the ONLY difference between the two saved rows')
 local saved=Data:_buildSaveData(Ann)
 check(saved.Version==Config.ProfileVersion and Config.ProfileVersion==22,'a full save of a bag with a test pack: ProfileVersion is still 22')
 local DataB=server('PlayerDataService').new(Config,Map,Notes)
 DataB.Store.Data[DataB:_getKey({UserId=1701,Name='Back'})]=saved
 local back=makePlayer(1701,'Back',DataB)
 local loadedFlag,loadedNormal=0,0
 for _,r in ipairs(DataB:GetChestRecords(back))do if r.Kind=='Pack'then if r.TestGrant==true then loadedFlag+=1 else loadedNormal+=1 end end end
 check(loadedFlag>=1 and loadedNormal>=1,'after a save and a load the test pack is still marked and the normal pack is not ('..loadedFlag..' / '..loadedNormal..')')
 -- a gift keeps it
 local giftRow=Data:SerializeSeedRecord(pack);giftRow.RateBoost=nil
 local decoded=Data:DecodeGiftedSeed(Bob,giftRow);check(decoded and decoded.TestGrant==true,'a gifted test pack arrives marked')
 local decodedN=Data:DecodeGiftedSeed(Bob,Data:SerializeSeedRecord(normal));check(decodedN and decodedN.TestGrant==nil,'a gifted normal pack arrives unmarked')
 -- a Seed row carries the mark too (R152: an owner-given seed, or the seed of a TEST opening), and only exactly true
 local seedRow=Data:SerializeSeedRecord({Id='x1',Kind='Seed',ChestNumber=5,ChestName='A',Stage=1,SeedId='SunflowerSeed',SeedName='Sunflower',TestGrant=true,BagVariant='Pack01',PackSize=1,PackMutation='None',SeedScale=1})
 check(seedRow.TestGrant==true,'a marked Seed record serialises the mark (R152)')
 local plainRow=Data:SerializeSeedRecord({Id='x2',Kind='Seed',ChestNumber=6,ChestName='A',Stage=1,SeedId='SunflowerSeed',SeedName='Sunflower',BagVariant='Pack01',PackSize=1,PackMutation='None',SeedScale=1})
 check(plainRow.TestGrant==nil,'an unmarked Seed record serialises no such key (the saved row is exactly the R151 one)')
 local junkSeed=Data:_decodeSavedSeedRecord(Ann,{Id='j2',Kind='Seed',ChestNumber=9,ChestName='P',Stage=1,SeedId='SunflowerSeed',TestGrant='yes',BagVariant='Pack01',PackSize=1,PackMutation='None',SeedScale=1},9)
 local goodSeed=Data:DecodeGiftedSeed(Bob,seedRow)
 check(junkSeed.TestGrant==nil and goodSeed and goodSeed.TestGrant==true,'a saved Seed row reads back marked only when TestGrant is exactly true; a gifted marked seed arrives marked')
 local junk=Data:_decodeSavedSeedRecord(Ann,{Id='j',Kind='Pack',ChestNumber=9,ChestName='P',Stage=1,TestGrant='yes',BagVariant='Pack01',PackSize=1,PackMutation='None',SeedScale=1},9)
 check(junk.TestGrant==nil,'a saved TestGrant that is not exactly true reads as a normal pack')
 emptyBag(Ann)
end

-- an R150 server (the previous release, from the git history) loads and re-saves a bag with an R151 test pack: the pack is untouched, the mark is dropped, nothing else changes
do
 local old=RS:FindFirstChild('PlayerDataServiceR150')
 if not old then
  print('SKIP: the R150 PlayerDataService is not in the repository history, so the old-server save check did not run')
 else
  old.Parent=folder
  local OldData=W.require(old).new(Config,Map,Notes)
  local pack=Data:AddChest(Ann,{Stage=3,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{TestGrant=true})
  local keep=Data:AddChest(Ann,{Stage=4,BagVariant='Pack05',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
  local saved=Data:_buildSaveData(Ann)
  OldData.Store.Data[OldData:_getKey({UserId=1801,Name='Old'})]=saved
  local oldPlayer=makePlayer(1801,'Old',OldData)
  local found;for _,r in ipairs(OldData:GetChestRecords(oldPlayer))do if r.Id==pack.Id then found=r end end
  check(found~=nil and found.Kind=='Pack'and found.Stage==3 and found.BagVariant=='Pack03','an R150 server loads a save that has an R151 test pack: the pack is there, unchanged')
  check(found and found.TestGrant==nil,'... it does not know the field: the mark is dropped on load')
  local resaved=OldData:_buildSaveData(oldPlayer)
  local function rowOf(save,id)for _,row in ipairs(save.Seeds)do if row.Id==id then return row end end end
  local before,after=rowOf(saved,pack.Id),rowOf(resaved,pack.Id)
  check(before and before.TestGrant==true and after and after.TestGrant==nil,'the R150 server writes the pack back WITHOUT the field (before: marked, after: not)')
  local same=after~=nil
  -- (R151 pack shapes: PackShape is a second optional field of a pack record, rolled by AddChest; an R150 server drops it the same way, and the pack is the default shape there)
  if after then for k,v in pairs(before)do if k~='TestGrant'and k~='PackShape'and after[k]~=v then same=false;print('differs after an R150 save:',k,tostring(v),tostring(after[k]))end end
   for k in pairs(after)do if before[k]==nil then same=false;print('new key after an R150 save:',k)end end end
  check(same,'... and every other saved field of the pack is identical (but the chip-bag shape, the other optional field: PackShape)')
  check(before.PackShape~=nil and after.PackShape==nil,'... the R151 chip-bag shape is dropped the same way (before: '..tostring(before.PackShape)..', after: '..tostring(after.PackShape)..'): an older server shows the default shape')
  local keepBefore,keepAfter=rowOf(saved,keep.Id),rowOf(resaved,keep.Id)
  local keepSame=keepAfter~=nil;if keepAfter then for k,v in pairs(keepBefore)do if k~='PackShape'and keepAfter[k]~=v then keepSame=false end end end
  check(keepSame,'a normal pack is saved identically by both versions')
  check(resaved.Version==saved.Version and resaved.Version==22,'the profile version is the same in both saves (22)')
  -- and R151 reads what R150 wrote
  local DataC=server('PlayerDataService').new(Config,Map,Notes)
  DataC.Store.Data[DataC:_getKey({UserId=1802,Name='Again'})]=resaved
  local again=makePlayer(1802,'Again',DataC)
  local back;for _,r in ipairs(DataC:GetChestRecords(again))do if r.Id==pack.Id then back=r end end
  check(back~=nil and back.Kind=='Pack'and back.TestGrant==nil,'an R151 server reads the R150 save fine (the pack is a normal pack again; nothing breaks)')
  emptyBag(Ann)
 end
end

-- 1c. R152 (R151's known small issue: "owner-granted boots and seeds don't count as test"): boots an owner command gave (/test boots) make every pull with their luck a TEST pull -- never announced
-- (here or to other servers), never counted by the hub -- and seeds an owner gave carry the mark to the plants and fruit they grow. Real boots (bought) and normal seeds are untouched.
do
 local boots=Config.ShopCatalog.Accessories
 local Tess,Rae,Cyd,Dee=makePlayer(711,'Tess'),makePlayer(712,'Rae'),makePlayer(713,'Cyd'),makePlayer(714,'Dee')
 local seen
 Data.OnPackOpened=function(p,reward,info)seen={Player=p,Reward=reward,Info=info}end
 -- a REAL (unmarked) Void pack, opened with a draw that rolls a Legendary+ seed with this player's luck: an unmarked open of it is announced
 local function open(p)
  local pack=addPack(p,7,'EclipseReliquary');local d=loud(pack,p)
  table.clear(sinkLog);watch();seen=nil
  local reward=Data:OpenSeedPack(p,pack.Id,drawConstant(d or .5));settle(30)
  local result={Reward=reward,Reason=spy.Reasons[1],Lines=#sinkLog,Published=bus:Count('A')-spy.Published,Seen=seen,Loud=d~=nil}
  unwatch();return result
 end
 check(not Data:HasTestLuck(Tess)and not Data:HasTestLuck(Rae),'(nobody has test luck to begin with)')
 -- control: bought boots are real
 check(Data:AddBoost(Rae,boots[5].Id)and not Data:HasTestLuck(Rae),'a bought pair of Thunder Boots is not test luck')
 local real=open(Rae)
 check(real.Loud and real.Reward and real.Reason=='announced'and real.Lines>=1 and real.Seen.Info.Test==false and real.Reward.TestGrant==nil,'control: a pull with BOUGHT boots is announced and counted for the hub ('..tostring(real.Reason)..', '..real.Lines..' lines)')
 -- owner boots
 local okB,textB=command(Tess,'/test boots 5')
 check(okB==true and Data:OwnsBoost(Tess,boots[5].Id)and Data:HasTestLuck(Tess),'/test boots 5: Tess owns them and her luck is test luck ('..tostring(textB)..')')
 check(tostring(textB):find('TEST pulls',1,true)~=nil,'... and the command says so')
 check(Tess:GetAttribute('ChestLuckMultiplier')==Rae:GetAttribute('ChestLuckMultiplier'),'(the same luck as the bought pair: the boots work as before, only the pulls are marked)')
 local owner=open(Tess)
 check(owner.Loud and owner.Reward and owner.Reward.Rarity and Rules.Qualifies('InServer',owner.Reward.Rarity),'(the owner\'s pull is a Legendary+ one: unmarked it would be announced)')
 check(owner.Reason=='test pack'and owner.Lines==0 and owner.Published==0,'a pull with owner-given boots is not announced in the server or to other servers ('..tostring(owner.Reason)..', '..owner.Lines..' lines, '..owner.Published..' published)')
 check(owner.Seen and owner.Seen.Info.Test==true,'... and the hub\'s hook is told it is a TEST pull')
 check(owner.Reward.TestGrant==true,'... and the seed it made is a TEST seed')
 -- mixed boots
 Data:AddBoost(Cyd,boots[2].Id);command(Cyd,'/test boots 5')
 check(Data:HasTestLuck(Cyd)and Cyd:GetAttribute('ChestLuckMultiplier')>=Tess:GetAttribute('ChestLuckMultiplier'),'bought Frost Boots + owner Thunder Boots: the luck in use is the owner\'s: test luck')
 local mixed=open(Cyd);check(mixed.Reason=='test pack'and mixed.Lines==0,'... so that pull is a TEST pull')
 Data:AddBoost(Dee,boots[5].Id);command(Dee,'/test boots 1');command(Dee,'/test boots 5')
 check(not Data:HasTestLuck(Dee),'bought Thunder Boots + owner Sand Boots (lower) + owner Thunder Boots (already owned): the luck in use is the bought pair\'s: not test luck')
 local both=open(Dee);check(both.Reason=='announced'and both.Seen.Info.Test==false,'... so that pull is real: announced and counted')
 -- saved with the profile as an OPTIONAL list; a player without test boots saves exactly what R151 saved
 local saved=Data:_buildSaveData(Tess);local savedRae=Data:_buildSaveData(Rae)
 check(type(saved.TestBoosts)=='table'and#saved.TestBoosts==1 and saved.TestBoosts[1]==boots[5].Id and savedRae.TestBoosts==nil,'the save of Tess lists her owner boots (TestBoosts); Rae\'s save has no such key')
 check(saved.Version==Config.ProfileVersion and Config.ProfileVersion==22,'ProfileVersion is still 22 (the list is optional)')
 local DataB=server('PlayerDataService').new(Config,Map,Notes)
 DataB.Store.Data[DataB:_getKey({UserId=1711,Name='Back'})]=saved
 DataB.Store.Data[DataB:_getKey({UserId=1712,Name='Back2'})]=savedRae
 local back,back2=makePlayer(1711,'Back',DataB),makePlayer(1712,'Back2',DataB)
 check(DataB:HasTestLuck(back)and not DataB:HasTestLuck(back2)and back:GetAttribute('ChestLuckMultiplier')==Tess:GetAttribute('ChestLuckMultiplier'),'after a save and a load Tess still has test luck (same luck) and Rae still does not')
 check(DataB:_buildSaveData(back).TestBoosts[1]==boots[5].Id,'... and the next save keeps the list')
 -- a list that names boots the player does not own, or junk, is ignored
 do
  local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
  local forged=copy(savedRae);forged.TestBoosts={boots[1].Id,7,{},'NoSuchBoots'}
  DataB.Store.Data[DataB:_getKey({UserId=1714,Name='Back4'})]=forged
  local back4=makePlayer(1714,'Back4',DataB)
  check(not DataB:HasTestLuck(back4),'a TestBoosts list with boots the player does not own, numbers, tables and unknown ids is ignored')
 end
 -- seeds: an owner-given seed is marked; planted and harvested it keeps the mark
 emptyBag(Tess);emptyBag(Rae)
 check(command(Tess,'/test seed SunflowerSeed'),'/test seed')
 check(command(Tess,'give me sunflower seed'),'give me sunflower seed (the English form, OwnerPlayerCommands)')
 local given=Data:GetChestRecords(Tess)
 check(#given==2 and given[1].TestGrant==true and given[2].TestGrant==true,'both owner-given seeds carry the mark ('..#given..' seeds)')
 local Plant=W.module('PlantRules');local def=Config.GardenPlants.SunflowerSeed
 local crop=Plant.NewCrop(given[1],'c1',def,1000,0,0);local cropN=Plant.NewCrop({SeedId='SunflowerSeed',SeedScale=1,PackMutation='None'},'c2',def,1000,0,0)
 check(crop.TestGrant==true and cropN.TestGrant==nil,'a plant grown from a marked seed is marked (a normal seed\'s plant is not)')
 local now=os.time();local okPlant,planted=Data:PlantSeed(Tess,1,given[1].Id,{OffsetX=0,OffsetZ=0},now)
 check(okPlant and planted.TestGrant==true,'PlantSeed: the crop of a marked seed carries the mark ('..tostring(planted)..')')
 if okPlant then
  local okH,harvest=Data:HarvestPlant(Tess,1,planted.Id,planted.ReadyAt+5)
  check(okH and harvest.TestGrant==true,'HarvestPlant: the harvest carries it (the hub / announcements ignore it) ('..tostring(okH and harvest.TestGrant)..')')
  local savedGarden=Data:_buildSaveData(Tess).Garden
  local marked=false;for _,list in pairs(savedGarden.Harvests)do if list.TestGrant==true then marked=true end end
  check(marked,'and it is saved with the harvest (an optional key of the garden: an R151 server keeps unknown crop keys)')
 end
 -- a normal seed: no mark anywhere
 table.insert(Data:GetChestRecords(Rae),{Id='n1',Kind='Seed',ChestNumber=900,ChestName='Sunflower Seed',Stage=1,SeedId='SunflowerSeed',SeedName='Sunflower Seed',SeedEmoji='x',AccentColor=R.Color3.new(1,1,1),SeedScale=1,BagVariant='Pack01',PackSize=1,PackMutation='None'})
 local okN,plantedN=Data:PlantSeed(Rae,1,'n1',{OffsetX=0,OffsetZ=0},now)
 check(okN and plantedN.TestGrant==nil,'control: a normal seed makes an unmarked crop')
 Data.OnPackOpened=nil;emptyBag(Tess);emptyBag(Rae);emptyBag(Cyd);emptyBag(Dee)
end

-- 2. publishing ------------------------------------------------------------------------------------------------------------------------------------
local function fresh(name,opts)
 opts=opts or{}
 local remote,log=remoteLog();local list=opts.Players or{}
 local players=opts.PlayersService or {GetPlayers=function()return list end}
 local srv=Announcer.new({Data=opts.Data,Players=players,Http=Http,Messaging=opts.Bus and opts.Bus:Server(name)or nil,Remote=remote,Clock=function()return R.clock end,Time=unix,JobId=opts.JobId or('job-'..name),
  Warn=opts.Warn or function()end})
 return srv,log,list
end
local function pull(srv,seed,name,extra)
 local e=Rules.Event('Pull',{Name=name or'Zed',UserId=1,Id=srv:_id(),SeedId=seed or'ObsidianMawSeed',Odds=1000,At=unix()})
 return e
end
do
 local b2=E.bus(function()return R.clock end,unix)
 local srv=fresh('P',{Bus=b2});srv:Run()
 local t0=R.clock
 srv:_queue(pull(srv))
 check(b2:Count('P')==1,'the first Secret+ pull is published at once')
 for i=1,5 do R.advance(.5);srv:_queue(pull(srv,nil,'N'..i))end
 check(b2:Count('P')==1 and#srv.Pending==5,'five more within 2.5 s: still ONE publish; they wait together ('..#srv.Pending..' pending)')
 R.advance(2.6)
 check(b2:Count('P')==2,'at 5 s the waiting pulls go out in ONE message (not five)')
 local second=E.decode(b2.Log[2].Message)
 check(#second.p==5 and#b2.Log[2].Message<=900,'... it carries all five and stays under 900 bytes ('..#b2.Log[2].Message..')')
 R.advance(60)
 local gaps={};local worst=math.huge
 for i=2,#b2.Log do worst=math.min(worst,b2.Log[i].At-b2.Log[i-1].At)end
 check(worst>=5-1e-9,'never closer than 5 s between two publishes (smallest gap '..string.format('%.2f',worst)..' s)')
 -- steady stream: 1 pull per second for 60 s => at most 12 publishes (12 per minute)
 local b3=E.bus(function()return R.clock end,unix);local s3=fresh('Q',{Bus=b3});s3:Run()
 for _=1,60 do s3:_queue(pull(s3));R.advance(1)end;R.advance(10)
 check(b3:Count('Q')<=13 and b3:Count('Q')>=10,'60 pulls in 60 s: '..b3:Count('Q')..' publishes (at most one per 5 s)')
 local total=0;for _,e in ipairs(b3.Log)do total+=#E.decode(e.Message).p end
 check(total+s3.Stats.Dropped+#s3.Pending==60,'... and every pull is either sent, dropped on purpose or still waiting ('..total..' sent + '..s3.Stats.Dropped..' dropped + '..#s3.Pending..' waiting)')
 local over=0;for _,e in ipairs(b3.Log)do if e.Bytes>1000 then over+=1 end end
 check(over==0,'no message over 1,000 bytes')
 -- the pending list is capped
 local b4=E.bus(function()return R.clock end,unix);local s4=fresh('R',{Bus=b4});s4:Run()
 s4:_queue(pull(s4));for i=1,10 do s4:_queue(pull(s4,nil,'M'..i))end
 check(#s4.Pending==6 and s4.Stats.Dropped==4,'at most 6 pulls wait for the next publish (the oldest are dropped): '..#s4.Pending..' waiting, '..s4.Stats.Dropped..' dropped')
 -- long names: several messages, none over the limit, everything arrives
 local b5=E.bus(function()return R.clock end,unix);local s5=fresh('S',{Bus=b5});s5:Run()
 for i=1,6 do local e=Rules.Event('Pull',{Name=string.rep('é',24),UserId=1e9+i,Id=s5:_id(),SeedId='ObsidianMawSeed',Odds=1e12,At=unix()});s5:_queue(e)end
 R.advance(30)
 local sent=0;local biggest=0;for _,e in ipairs(b5.Log)do sent+=#E.decode(e.Message).p;biggest=math.max(biggest,e.Bytes)end
 check(sent==6 and biggest<=900,'six pulls with the longest names: all sent, the biggest message is '..biggest..' bytes ('..b5:Count('S')..' messages)')
 -- a stale pull is never sent
 local b6=E.bus(function()return R.clock end,unix);local s6=fresh('T',{Bus=b6});s6:Run()
 s6:_queue(pull(s6));check(b6:Count('T')==1,'(the first goes out at once)')
 s6:_queue(pull(s6,nil,'Late'));s6.Pending[1].At=unix()-100
 R.advance(6)
 check(b6:Count('T')==1 and#s6.Pending==0 and s6.Stats.Dropped==1,'a pull that waited over 60 s is dropped, not sent late ('..s6.Stats.Dropped..' dropped)')
 -- the same id queued twice is one pull
 local b7=E.bus(function()return R.clock end,unix);local s7=fresh('U',{Bus=b7});s7:Run()
 local e7=pull(s7);s7:_queue(e7);local e8=pull(s7);s7:_queue(e8);s7:_queue(e8);s7:_queue(e8);R.advance(10)
 local ids=0;for _,e in ipairs(b7.Log)do ids+=#E.decode(e.Message).p end
 check(ids==2,'the same pull queued three times is sent once ('..ids..' entries in total)')
 -- no MessagingService at all
 local s8=fresh('V',{});s8:_queue(pull(s8));R.advance(30)
 check(s8.Stats.PublishFailed>=1 and s8.Stats.Dropped>=1 and#s8.Pending==0,'without MessagingService nothing crashes; the pull is retried and then dropped')
end

-- failures and retries
do
 local warns={}
 local b=E.bus(function()return R.clock end,unix);local s=fresh('F',{Bus=b,Warn=function(m)warns[#warns+1]=m end});s:Run()
 b.FailPublish=1;s:_queue(pull(s))
 check(b:Count('F')==0 and s.Stats.PublishFailed==1 and#s.Pending==1,'a failed publish keeps the pull for another try')
 R.advance(4.9);check(b:Count('F')==0,'... not before the 5 s gap')
 R.advance(.2);check(b:Count('F')==1 and#s.Pending==0 and s.Stats.Published==1,'... the retry after 5 s works')
 check(#warns==1 and warns[1]:find('Could not publish',1,true),'one warning for the failure')
 b.FailPublish=10;s:_queue(pull(s,nil,'Doomed'));R.advance(60)
 check(s.Stats.PublishFailed==4 and#s.Pending==0 and s.Stats.Dropped==1,'a pull that keeps failing is tried 3 times and then dropped ('..s.Stats.PublishFailed..' failures)')
 local failsBefore=s.Stats.PublishFailed;R.advance(60);check(s.Stats.PublishFailed==failsBefore,'... and nothing keeps retrying in the background')
 b.FailPublish=0;s:_queue(pull(s,nil,'After'));R.advance(1)
 check(b:Count('F')==2,'a later pull publishes normally again')
 -- order is kept when a batch fails and goes back
 local b2=E.bus(function()return R.clock end,unix);local s2=fresh('G',{Bus=b2});s2:Run()
 b2.FailPublish=1;s2:_queue(pull(s2,nil,'first'))
 for i=1,3 do R.advance(.2);s2:_queue(pull(s2,nil,'n'..i))end
 R.advance(6)
 local names={};for _,e in ipairs(b2.Log)do if not e.Failed then for _,x in ipairs(E.decode(e.Message).p)do names[#names+1]=x.n end end end
 check(table.concat(names,',')=='first,n1,n2,n3'or table.concat(names,',')=='first,n1,n2,n3','pulls arrive in order: '..table.concat(names,','))
end

-- 3. receiving ------------------------------------------------------------------------------------------------------------------------------------
local function fakeData(settings)
 local d={}
 function d:IsLoaded(p)return settings[p]~=nil and settings[p]~='loading'end
 function d:GetPremium(p)local s=settings[p];return {Settings=type(s)=='table'and s or{}}end
 return d
end
do
 local b=E.bus(function()return R.clock end,unix)
 local sA,logA,listA=fresh('A1',{Bus=b,Data=fakeData({})})
 local pa1=newPlayer(801,'Origin',nil)
 listA[1]=pa1
 sA.Data=fakeData({[pa1]={}})
 local pb1,pb2,pb3,pb4=newPlayer(811,'On',nil),newPlayer(812,'Off',nil),newPlayer(813,'Loading',nil),newPlayer(814,'Default',nil)
 local sB,logB,listB=fresh('B1',{Bus=b})
 listB[1],listB[2],listB[3],listB[4]=pb1,pb2,pb3,pb4
 sB.Data=fakeData({[pb1]={GlobalAnnouncements=true},[pb2]={GlobalAnnouncements=false},[pb3]='loading',[pb4]={}})
 local sC,logC,listC=fresh('C1',{Bus=b});local pc1=newPlayer(821,'Cee',nil);listC[1]=pc1;sC.Data=fakeData({[pc1]={}})
 sA:Run();sB:Run();sC:Run()
 -- a full flow: a pull in server A (Secret): A shows its own in-server banner, B and C show the other-server version, A never shows the global one
 local Ob=Rules.Event('Pull',{Name='Pat',UserId=5,Id=sA:_id(),SeedId='ObsidianMawSeed',Odds=1000,At=unix()})
 sA:_broadcast(Ob);sA:_queue(Ob)
 check(#logA==1 and logA[1].Payload.Kind=='Pull','the origin server (A) shows ONE announcement, the in-server one ('..#logA..')')
 check(sA.Stats.Origin==1 and sA.Stats.Received==0,'... its own global message came back through the subscription and was dropped (origin)')
 check(#logB==2,'server B shows it to the two players who take announcements from other servers (on, default): '..#logB)
 local got={};for _,l in ipairs(logB)do got[l.Player]=l.Payload end
 check(got[pb1]and got[pb1].Kind=='Global'and got[pb1].SeedId=='ObsidianMawSeed'and got[pb1].Name=='Pat'and got[pb1].UserId==5,'... as Kind = Global with the seed and the puller\'s name')
 check(got[pb4]~=nil and got[pb2]==nil and got[pb3]==nil,'... the player with the setting OFF and the one whose data has not loaded get nothing')
 check(#logC==1 and logC[1].Payload.Kind=='Global','server C shows it too')
 check(got[pb1].Rarity==nil,'the payload sent to clients carries no rarity (the client reads its own catalog)')
 -- repeats: the same message delivered twice (at-least-once delivery) shows once
 local text=b.Log[#b.Log].Message
 local before=#logB
 sB:_onMessage({Data=text,Sent=unix()});sB:_onMessage({Data=text,Sent=unix()})
 check(#logB==before and sB.Stats.Repeat>=2,'the same message again (a repeat) shows nothing new')
 -- stale / future
 local function packet(entries,t,sent,jobId)return {Data=E.encode({v=1,j=jobId or'other',t=t,p=entries}),Sent=sent}end
 local function entry(id,seed,name)return {i=id,u=1,n=name or'Q',s=seed or'ObsidianMawSeed',o=1000}end
 local n0=#logB
 sB:_onMessage(packet({entry('s1')},unix()-61,unix()-61));sB:_onMessage(packet({entry('s2')},unix()-100,unix()));sB:_onMessage(packet({entry('s3')},unix(),unix()-90))
 check(#logB==n0 and sB.Stats.Stale==3,'a message older than 60 s is dropped (by its own time and by the service\'s time stamp): '..sB.Stats.Stale)
 sB:_onMessage(packet({entry('f1')},unix()+31,unix()+31))
 check(#logB==n0 and sB.Stats.Stale==4,'... and one from more than 30 s in the future')
 sB:_onMessage(packet({entry('g1')},unix()-59,unix()-59))
 check(#logB==n0+2,'a 59 s old message still shows (to the 2 players who take announcements)')
 -- unknown seed / below the threshold / a rarity claim for a Common seed
 local n1=#logB
 sB:_onMessage(packet({entry('u1','NoSuchSeed')},unix(),unix()));sB:_onMessage(packet({entry('u2','FirePepperSeed')},unix(),unix()));sB:_onMessage(packet({entry('u3','SunflowerSeed')},unix(),unix()))
 check(#logB==n1,'an unknown seed, a Mythic seed (under the global threshold) and a Common seed are all dropped')
 local liar=packet({{i='u4',u=1,n='Liar',s='SunflowerSeed',r='King',o=1}},unix(),unix())
 sB:_onMessage(liar);check(#logB==n1,'a message that CLAIMS King for a Common seed is dropped (the rarity is the local catalog\'s)')
 -- malformed
 local before2=sB.Stats.Bad
 for _,m in ipairs({5,'x',{},{Data=5},{Data='not json'},{Data='{"v":2}'},{Data=E.encode({v=1,j='o',t=unix(),p=5})},{Data=E.encode({v=1,j=5,t=unix(),p={}})},{Data=string.rep('x',1001)},{Data=E.encode({v=1,j='o',t='now',p={}})},
  {Data=E.encode({v=1,j='o',t=unix(),p={5,'x',{}}}),Sent=unix()}})do
  local ok=pcall(sB._onMessage,sB,m);check(ok,'a malformed message does not throw: '..tostring(type(m)=='table'and m.Data or m))
 end
 check(sB.Stats.Bad>=before2+8,'... and is counted ('..(sB.Stats.Bad-before2)..')')
 check(#logB==n1,'... and shows nothing')
 -- a name full of markup is cleaned before it is sent on
 local n2=#logB
 sB:_onMessage(packet({entry('m1','ObsidianMawSeed','<b>HAX</b> & "q"')},unix(),unix()))
 check(#logB==n2+2 and logB[#logB].Payload.Name=='bHAX/b q','a name with markup reaches clients without it ('..tostring(logB[#logB].Payload.Name)..')')
 -- more than 5 / 6 entries in a message: the rest is ignored
 local many={};for i=1,12 do many[i]=entry('mm'..i)end
 local n3=#logB;sB:_onMessage(packet(many,unix(),unix()))
 check(#logB-n3<=2*6 and#logB-n3>=2,'at most 6 pulls are read from one message ('..((#logB-n3)/2)..')')
 -- the receive limit: 10 per minute
 local b2=E.bus(function()return R.clock end,unix);local sR,logR,listR=fresh('R2',{Bus=b2});listR[1]=newPlayer(831,'R',nil)
 sR:Run()
 local shownCount=0
 for i=1,25 do sR:_onMessage(packet({entry('r'..i)},unix(),unix()));R.advance(.5)end
 shownCount=#logR
 check(shownCount==10 and sR.Stats.Limited==15,'25 distinct pulls within 12 s: 10 are shown, 15 dropped by the per-minute limit ('..shownCount..' / '..sR.Stats.Limited..')')
 R.advance(60);sR:_onMessage(packet({entry('r-late')},unix(),unix()))
 check(#logR==11,'a minute later the next one is shown again')
 -- the receive limit is per server, not per player (one entry = one send per wanting player)
 check(#logR==11,'(one pull = one payload per player, however many players)')
end

-- 4. the subscription ------------------------------------------------------------------------------------------------------------------------------
do
 local b=E.bus(function()return R.clock end,unix);b.FailSubscribe=3
 local warns={};local s=fresh('W',{Bus=b,Warn=function(m)warns[#warns+1]=m end});s:Run()
 check(s.Connection==nil and s.Stats.SubscribeFailed==1,'the first subscribe fails; the server keeps going')
 R.advance(4.9);check(s.Stats.SubscribeFailed==1,'... the next try waits 5 s')
 R.advance(.2);check(s.Stats.SubscribeFailed==2 and s.Connection==nil,'second try at 5 s fails')
 R.advance(9.9);check(s.Stats.SubscribeFailed==2,'... the wait grows (10 s)')
 R.advance(.2);check(s.Stats.SubscribeFailed==3,'third try at 15 s fails')
 R.advance(19.9);check(s.Connection==nil,'... 20 s more')
 R.advance(.2);check(s.Connection~=nil and s.Stats.SubscribeFailed==3,'the fourth try at 35 s works: subscribed')
 R.advance(1000);check(s.Stats.SubscribeFailed==3 and#b.Subs==1,'once subscribed nothing retries and there is one subscription')
 check(#warns>=1 and warns[1]:find('not listening',1,true),'a warning says other servers are not heard yet')
 -- the wait is capped (120 s)
 local b2=E.bus(function()return R.clock end,unix);b2.FailSubscribe=1000
 local s2=fresh('X',{Bus=b2});s2:Run();R.advance(2000)
 check(s2.Stats.SubscribeFailed>=18 and s2.Stats.SubscribeFailed<=24,'a service that stays down is tried about every 120 s ('..s2.Stats.SubscribeFailed..' tries in 2000 s)')
 s2:Destroy();local c=s2.Stats.SubscribeFailed;R.advance(500);check(s2.Stats.SubscribeFailed==c,'Destroy stops the retries')
 -- a message arriving after Destroy: the subscription is disconnected
 local b3=E.bus(function()return R.clock end,unix);local s3,log3,l3=fresh('Y',{Bus=b3});l3[1]=newPlayer(841,'Y',nil);s3:Run();s3:Destroy()
 local sender=fresh('Z',{Bus=b3});sender:Run();sender:_queue(pull(sender));R.advance(1)
 check(#log3==0,'a destroyed server hears nothing')
end

-- 5. records and owner commands -------------------------------------------------------------------------------------------------------------------------
do
 local srv,log,list=fresh('K',{});local p1,p2=newPlayer(901,'Kay',nil),newPlayer(902,'Lee',nil);list[1],list[2]=p1,p2
 p1.DisplayName='Kay Display'
 Announcer.Instance=srv
 check(Announcer.Announce({Kind='Record',Player=p1,Record='BestPull',SeedId=KING.id,Odds=5e6,Size=20})==true,'PullAnnouncer.Announce({Kind=Record, Player=..}) works through the module API')
 check(#log==2 and log[1].Payload.Kind=='Record'and log[1].Payload.Name=='Kay Display'and log[1].Payload.UserId==901 and log[1].Payload.Record=='BestPull'and log[1].Payload.SeedId==KING.id,'every player in the server gets it; the name is the display name')
 table.clear(log)
 check(Announcer.Announce({Kind='Record',Name='Hub Bot',UserId=0,Record='BiggestFruit'})==true and log[1].Payload.Record=='BiggestFruit','a record without a player object (a name and an id)')
 table.clear(log)
 check(Announcer.Announce({Kind='Record',Player=p2,Record='<b>Hack</b>'})==true and log[1].Payload.Record=='Record','a record key with markup becomes the plain "Record" (no free text is ever sent)')
 table.clear(log)
 check(Announcer.Announce({Kind='Record',Name='<script>',UserId=3,Record='BestPull'})==true and log[1].Payload.Name=='script','a name with markup is cleaned')
 local bad1,why1=Announcer.Announce({Kind='Global',Name='x'});local bad2=Announcer.Announce(nil);local bad3=Announcer.Announce({Kind='Record'})
 check(bad1==false and bad2==false and bad3==false,'a Global kind from other code, nil and a record without a name are refused ('..tostring(why1)..')')
 -- not started
 Announcer.Instance=nil
 check(Announcer.Announce({Kind='Record',Name='x'})==false and select(2,Announcer.Command({},p1,{'x'}))~=nil and Announcer.OnOpened(p1,{},{},false)==false,'before Start the module API refuses quietly')
 Announcer.Instance=srv
 -- commands
 local X=server('OwnerUpdateCommands82')
 check(X.Actions.announce==true,'announce is an update command (reached through /test and F4)')
 local ctx={Config=Config,Map={MapRoot={}},Chase={},Data=Data}
 table.clear(log)
 local ok,msg=X.Execute(ctx,p1,'announce',{'firepepper'})
 check(ok==true and#log==2 and log[1].Payload.Kind=='Pull'and log[1].Payload.SeedId=='FirePepperSeed'and log[1].Payload.Name=='Kay Display'and type(log[1].Payload.Odds)=='number','announce firepepper: a banner for everyone in the server ('..tostring(msg)..')')
 table.clear(log)
 check(select(1,X.Execute(ctx,p1,'announce',{'fire','pepper'}))==true and log[1].Payload.SeedId=='FirePepperSeed'and log[1].Payload.Mutation==nil and log[1].Payload.Size==nil,'announce fire pepper: the plant name in words (there is no coat any more)')
 table.clear(log);check(select(1,X.Execute(ctx,p1,'announce',{'firepepper','gold'}))==false and#log==0,'a coat word is not part of the command any more (it reads as an unknown seed)')
 table.clear(log)
 check(select(1,X.Execute(ctx,p1,'announce',{'SunflowerSeed'}))==true and log[1].Payload.SeedId=='SunflowerSeed','a Common seed works too (it is a test)')
 local _,common=X.Execute(ctx,p1,'announce',{'SunflowerSeed'});check(common:find('below the in-server threshold',1,true)~=nil,'... and the answer says a real pull would not show it')
 table.clear(log)
 local u1,um=X.Execute(ctx,p1,'announce',{'nonsense'});check(u1==false and um:find('Unknown seed',1,true)~=nil and#log==0,'an unknown seed is refused: '..tostring(um))
 local u2,um2=X.Execute(ctx,p1,'announce',{});check(u2==false and um2:find('announce global',1,true)~=nil,'no arguments: the usage line')
 -- announce global
 local b=E.bus(function()return R.clock end,unix);local gs,glog,glist=fresh('GL',{Bus=b});glist[1]=p1;gs:Run();Announcer.Instance=gs
 local g1,gm=X.Execute(ctx,p1,'announce',{'global','obsidianmaw'})
 check(g1==true and b:Count('GL')==1 and#glog==0 and gm:find('origin',1,true)~=nil,'announce global obsidianmaw: published to other servers, this server (the origin) shows nothing')
 local sent=E.decode(b.Log[1].Message);check(sent.p[1].s=='ObsidianMawSeed'and sent.p[1].n=='Kay Display'and sent.p[1].u==901,'... the message names the seed and the target player')
 R.advance(6)
 local g2,gm2=X.Execute(ctx,p1,'announce',{'global','obsidianmaw','here'})
 check(g2==true and#glog==1 and glog[1].Payload.Kind=='Global'and gm2:find('Shown here too',1,true)~=nil,'announce global obsidianmaw here: this server also shows the other-server banner')
 R.advance(6)
 check(select(1,X.Execute(ctx,p1,'announce',{'global','nonsense'}))==false and select(1,X.Execute(ctx,p1,'announce',{'global'}))==false,'announce global with a bad or missing seed is refused')
 -- announce record
 Announcer.Instance=srv;table.clear(log)
 local r1,rm=X.Execute(ctx,p1,'announce',{'record'});check(r1==true and log[1].Payload.Kind=='Record'and log[1].Payload.Record=='BestPull'and log[1].Payload.SeedId==nil,'announce record: BEST PULL, no seed ('..tostring(rm)..')')
 table.clear(log);X.Execute(ctx,p1,'announce',{'record','fruit','moonmelon'})
 check(log[1].Payload.Record=='BiggestFruit'and log[1].Payload.SeedId=='MoonflowerSeed','announce record fruit moonmelon: BIGGEST FRUIT TODAY with Moon Melon\'s picture')
 table.clear(log);local okK,msgK=X.Execute(ctx,p1,'announce',{'record','bestpull',kingKey})
 check(okK==true and log[1].Payload.Record=='BestPull'and log[1].Payload.SeedId==KING.id,'announce record bestpull '..kingKey..': '..tostring(msgK))
 check(select(1,X.Execute(ctx,p1,'announce',{'record','nonsense'}))==false,'announce record with an unknown seed is refused')
 -- the help rows and the docs
 local Help=W.module('StudioTestHelp');local rows=0;for _,row in ipairs(Help)do if row[1]:find('/test announce',1,true)then rows+=1 end end
 check(rows==3,'three /test announce rows in the in-game command list ('..rows..')')
end

-- 5b. hub records: who hears them (PullAnnounceRules.RecordScope), when (AfterReveal), private owner tests (To), what other servers accept -------------------------------------------
do
 local previousInstance=Announcer.Instance
 local b=E.bus(function()return R.clock end,unix)
 local sA,logA,listA=fresh('RA',{Bus=b});local sB,logB,listB=fresh('RB',{Bus=b})
 local pa,pa2,pb=newPlayer(961,'Rec',nil),newPlayer(963,'Rec2',nil),newPlayer(962,'Far',nil)
 listA[1],listA[2]=pa,pa2;listB[1]=pb;sA:Run();sB:Run()
 Announcer.Instance=sA
 local function ids(log)local out={};for _,l in ipairs(log)do out[#out+1]=l.Payload.Kind..':'..tostring(l.Payload.Record)end;return table.concat(out,',')end
 -- BestPull: the pull's own rarity decides, with the pull line's thresholds
 local expected={Common='nothing',Uncommon='nothing',Rare='nothing',Legendary='server',Mythic='server',Secret='server',Cosmic='server',King='server'} -- (R153: Secret and above used to be 'everywhere')
 for _,rarity in ipairs(Packs.RarityOrder)do
  R.advance(6);table.clear(logA);table.clear(logB);local published=b:Count('RA')
  local spec=firstOf(rarity)
  local ok,why=Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=spec.id})
  local want=expected[rarity]
  check(Rules.RecordScope('BestPull',rarity)==({nothing=nil,server='InServer',everywhere='Global'})[want],rarity..': RecordScope(BestPull) = '..want)
  if want=='nothing'then
   check(ok==false and why=='below the threshold'and#logA==0 and b:Count('RA')==published and next(sA.Waiting)==nil,rarity..': a BestPull record is not announced (below Legendary: the display changes, chat says nothing)')
  else
   check(ok==true and#logA==2 and logA[1].Payload.Kind=='Record'and logA[1].Payload.Record=='BestPull'and logA[1].Payload.SeedId==spec.id and logA[1].Payload.Name=='Rec','a '..rarity..' BestPull record: both players of this server get the record line now ('..ids(logA)..')')
   check(b:Count('RA')==published,rarity..': R153: not published (this server only: BEST PULL is each server\'s own board)')
   check(#logB==0,rarity..': nothing in the other server')
  end
 end
 -- every other record: this server, never the others (a fruit's weight has no pull rarity; a record that names no seed has none to judge)
 R.advance(6);table.clear(logA);table.clear(logB);local published=b:Count('RA')
 check(Announcer.Announce({Kind='Record',Player=pa,Record='BiggestFruit',SeedId=firstOf('Common').id})==true and#logA==2 and b:Count('RA')==published,'BiggestFruit with a Common seed: told in this server (never silent), never to the others')
 table.clear(logA);check(Announcer.Announce({Kind='Record',Player=pa,Record='BiggestFruit',SeedId=firstOf('King').id})==true and#logA==2 and b:Count('RA')==published and#logB==0,'... even with a King seed: a fruit record stays in this server')
 table.clear(logA);check(Announcer.Announce({Kind='Record',Player=pa,Record='BestPull'})==true and#logA==2 and b:Count('RA')==published,'a BestPull that names no seed: this server only')
 table.clear(logA);check(Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('King').id,Scope='InServer'})==true and#logA==2 and b:Count('RA')==published and#logB==0,'Scope = InServer keeps even a King record in this server (what the owner\'s `announce record` does)')
 table.clear(logA);check(Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('Rare').id,Scope='InServer'})==true and#logA==2,'... and an explicit scope overrides the threshold')
 -- R153: and asking for every server changes nothing for a BestPull: it is shown here and published nowhere (a guard in the announcer on top of RecordScope)
 R.advance(6);table.clear(logA);table.clear(logB);published=b:Count('RA')
 check(Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('King').id,Scope='Global'})==true and#logA==2 and b:Count('RA')==published and#logB==0,'R153: Scope = Global for a BestPull (even a King) is shown in this server and never published')
 R.advance(6);table.clear(logA);table.clear(logB);published=b:Count('RA')
 check(Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('King').id,Scope='Global',AfterReveal=true})==true,'(the same after a reveal)')
 R.advance(30)
 check(b:Count('RA')==published and#logB==0 and#logA==2,'R153: ... still nothing published or told to another server after the wait')
 -- an explicit Global scope for a record the rules keep at home is dropped by the receiver
 R.advance(6);table.clear(logA);table.clear(logB);local bad0=sB.Stats.Bad
 check(Announcer.Announce({Kind='Record',Player=pa,Record='BiggestFruit',SeedId=firstOf('Mythic').id,Scope='Global'})==true and#logA==2,'Scope = Global is honoured by the sender (this server shows it, and publishes)')
 check(#logB==0 and sB.Stats.Bad==bad0+1,'... but another server shows only records its own rules send everywhere: a BiggestFruit record is dropped there')
 -- private: To = the player (an owner's bestpull / bigfruit test): only that player, only this server, at once
 R.advance(6);table.clear(logA);table.clear(logB);published=b:Count('RA')
 local okTo,waitTo=Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('King').id,To=pa,AfterReveal=true})
 check(okTo==true and waitTo==0 and#logA==1 and logA[1].Player==pa and b:Count('RA')==published and#logB==0,'To = the player: only they get the line, at once (no wait), never another player, never another server')
 -- AfterReveal: a record that comes from a pack open waits for the puller's reveal, then goes out in this server (R153: and nowhere else)
 for _,rarity in ipairs({'Mythic','Secret','King'})do
  R.advance(30);table.clear(logA);table.clear(logB);published=b:Count('RA');local t0=R.clock
  local spec=firstOf(rarity)
  local ok,wait=Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=spec.id,AfterReveal=true})
  local lag=Rules.Defaults.RecordLag
  check(ok==true and math.abs(wait-(Rules.RevealDelay(rarity)+lag))<1e-9 and#logA==0 and b:Count('RA')==published,rarity..': AfterReveal: nothing at once; it waits RevealDelay + RecordLag ('..string.format('%.2f',wait or -1)..' s)')
  runUntil(20,function()return#logA>=2 end)
  check(#logA==2 and math.abs(logA[1].At-t0-wait)<=.011,rarity..': the record line goes out then ('..string.format('%.2f',logA[1]and logA[1].At-t0 or -1)..' s), after the pull line\'s time ('..string.format('%.2f',Rules.RevealDelay(rarity))..' s)')
  check(b:Count('RA')==published and#logB==0,rarity..': this server only (R153: a Secret\'s record line does not travel either)')
 end
 -- the puller leaves: released at once; a record below the threshold does not wait at all
 R.advance(30);table.clear(logA);table.clear(logB);published=b:Count('RA');local t0=R.clock
 Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('Secret').id,AfterReveal=true})
 runUntil(.7,function()return false end)
 check(#logA==0,'(0.7 s into the reveal: nothing yet)')
 table.remove(listA,1);sA:_released(pa) -- (pa is gone from the list; the real PlayerRemoving of the main announcer is tested in 1a)
 check(#logA==1 and logA[1].Player==pa2 and logA[1].At-t0<1 and b:Count('RA')==published and#logB==0,'the puller leaves: the record line goes out at once, in this server only')
 local n=#logA;R.advance(30);check(#logA==n and b:Count('RA')==published,'... and not again at the normal time')
 local rare=Announcer.Announce({Kind='Record',Player=pa,Record='BestPull',SeedId=firstOf('Rare').id,AfterReveal=true})
 check(rare==false and next(sA.Waiting)==nil,'a Rare record from a pull is refused at once: nothing is left waiting')
 -- what another server accepts
 local function packet(entry)return {Data=E.encode({v=1,j='far-away',t=unix(),p={entry}}),Sent=unix()}end
 local sC,logC,listC=fresh('RC',{Bus=nil});listC[1]=newPlayer(971,'Cee',nil);local bad1=sC.Stats.Bad
 local kingId,commonId=firstOf('King').id,firstOf('Common').id
 sC:_onMessage(packet({i='f1',u=1,n='Evil',s=commonId,k='BestPull'}))
 sC:_onMessage(packet({i='f2',u=1,n='Evil',s=kingId,k='BiggestFruit'}))
 sC:_onMessage(packet({i='f3',u=1,n='Evil',s=kingId,k='<b>x</b>'}))
 sC:_onMessage(packet({i='f4',u=1,n='Evil',k='BestPull'}))
 check(#logC==0 and sC.Stats.Bad==bad1+4,'forged records are dropped: a BestPull of a Common seed, a fruit record, a record key with markup, a record without a seed ('..(sC.Stats.Bad-bad1)..' counted)')
 local bad2=sC.Stats.Bad
 sC:_onMessage(packet({i='f5',u=1,n='Real',s=kingId,k='BestPull'}))
 check(#logC==0 and sC.Stats.Bad==bad2+1,'R153: a King BestPull record from another server (an older one that still publishes it) is NOT shown here: BEST PULL is each server\'s own ('..(sC.Stats.Bad-bad2)..' counted bad)')
 sC:_onMessage(packet({i='f6',u=1,n='Pat',s=kingId,k=5}))
 check(#logC==1 and logC[1].Payload.Kind=='Global','a record key that is not a string is no record: it reads as the pull it also could be')
 sC.Data={IsLoaded=function()return true end,GetPremium=function()return {Settings={GlobalAnnouncements=false}}end}
 sC:_onMessage(packet({i='f7',u=1,n='Pat2',s=kingId}))
 check(#logC==1,'a player who switched "Announcements from other servers" off does not get another server\'s pull line either (as before)')
 sA:Destroy();sB:Destroy();Announcer.Instance=previousInstance
end

-- 6. trust ---------------------------------------------------------------------------------------------------------------------------------------
do
 local clientEvents=0
 for _,child in ipairs(W.RS:GetDescendants())do if child:IsA('RemoteEvent')and child.Name==Rules.RemoteName then clientEvents+=1 end end
 local srv=Announcer.new({Data=nil,Players=Players,Http=Http,Messaging=nil,Remote=nil,JobId='trust',Warn=function()end})
 local remote=srv.Remote
 check(remote~=nil and remote.Name=='PullAnnounce151'and remote.Parent==remotes and remote:IsA('RemoteEvent'),'the remote is a RemoteEvent in ChestChaseRemotes (created by the server)')
 local listened=false
 -- the server never connects OnServerEvent: no player can ask for an announcement
 listened=#(remote.OnServerEvent and remote.OnServerEvent._c or{})>0
 check(not listened,'nothing listens to OnServerEvent: a client cannot start an announcement')
 check(Announcer.Usage:find('announce',1,true)~=nil,'(the owner usage text exists)')
end

reset()
print(('R151 server: %d checks, %d fails'):format(checks,fails))
if fails>0 then error('failures')end
print(('%d/%d checks passed'):format(checks-fails,checks))
