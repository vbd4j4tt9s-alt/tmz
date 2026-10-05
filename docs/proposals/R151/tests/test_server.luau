--!nocheck
-- R151 pull announcements, part 2: the SERVER half on the Roblox mock with the REAL modules (PullAnnouncer, PullAnnounceRules, PlayerDataService, RarePackTests,
-- SeedPackRules, Config, OwnerUpdateCommands82, StudioTestHelp) and a MessagingService bus (announce_env.luau):
--  1. the hook: PlayerDataService:OpenSeedPack of a real pack announces a Legendary+ seed AFTER its reveal; a TEST pack (/test rarepacks), a given / granted seed,
--     a Common pull and a changed threshold announce nothing; the odds are the pack's own; the pull is still announced when the puller has left
--  2. publishing: a Secret+ pull goes to the other servers; at most one publish per 5 s per server, pulls coalesce into one message under 1 kB, the pending list is
--     capped, a failed publish is retried (then dropped), a stale pull is never sent; Legendary / Mythic stay in the server
--  3. receiving: the origin server drops its own message (it shows the in-server version only), repeats, stale and future messages, an over-limit flood, malformed
--     messages and messages whose seed is unknown or below the threshold; the rarity is the local catalog's; only players with "Announcements from other servers" on
--  4. the subscription is retried with a growing wait until it works
--  5. records: PullAnnouncer.Announce({Kind='Record'...}); owner commands: announce <seed>, announce global <seed> [here], announce record
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
local function duration(rarity)return Packs.GetRevealDuration(rarity)end
do
 -- a real Legendary open
 local reward,pack=openReal(Ann,'Legendary')
 check(reward and reward.Rarity=='Legendary','a real Legendary open: '..tostring(reward and reward.SeedId))
 check(#sinkLog==0,'nothing is shown at the moment of the open (the reveal is still playing)')
 R.advance(duration('Legendary')-.2);check(#sinkLog==0,'... nor just before the reveal ends ('..string.format('%.2f',duration('Legendary'))..' s)')
 R.advance(.3)
 local pulls=ofKind(sinkLog,'Pull')
 check(#pulls==2 and#toPlayer(sinkLog,Ann)==1 and#toPlayer(sinkLog,Bob)==1,'once it has ended every player in the server is sent one Pull (the puller and the other player)')
 local e=pulls[1]and pulls[1].Payload
 check(e and e.SeedId==reward.SeedId and e.UserId==701 and e.Name=='Ann D'and e.Id and e.Id:match('^jobA0000%-%d+$'),'the payload names the seed, the puller (display name, user id) and carries an id ('..tostring(e and e.Id)..')')
 local percent=Packs.SeedOdds(Config,pack.Stage,pack.BagVariant,Ann:GetAttribute('ChestLuckMultiplier'),pack.OddsVersion,pack.RateBoost)[reward.SeedId]
 check(e and percent and math.abs(e.Odds-100/percent)<1e-9*e.Odds,'the odds are the pack\'s own chance for that seed: 1/'..tostring(e and e.Odds)..' (SeedOdds '..tostring(percent)..'%)')
 check(e and e.Size==reward.SeedScale and e.Mutation==reward.PackMutation,'size and coat come from the reward')
 check(bus:Count('A')==0,'a Legendary pull is NOT sent to other servers (Secret and above only)')
 table.clear(sinkLog)
 -- a Mythic open the same way
 local mythic=openReal(Bob,'Mythic');settle(duration('Mythic')+.5)
 check(mythic.Rarity=='Mythic'and#ofKind(sinkLog,'Pull')==2 and bus:Count('A')==0,'a real Mythic open: shown to both players, not published')
 table.clear(sinkLog)
 -- Common: nothing at all
 local pc=addPack(Ann,commonStage,commonVariant);local rc=Data:OpenSeedPack(Ann,pc.Id,drawConstant(commonDraw));settle(15)
 check(rc.Rarity=='Common'and#sinkLog==0 and#A.Pending==0,'a Common open announces nothing')
 -- the reveal delay grows with the rarity (the puller\'s screen is busy until then)
 check(duration('Mythic')>duration('Legendary')and duration('King')>duration('Secret'),'the wait follows the reveal length (Legendary '..string.format('%.1f',duration('Legendary'))..' s ... King '..string.format('%.1f',duration('King'))..' s)')
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
 local reward=openReal(Ann,'Secret');settle(duration('Secret')+.5)
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
 settle(duration('Legendary')+.5)
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
 for i=1,6 do local e=Rules.Event('Pull',{Name=string.rep('é',24),UserId=1e9+i,Id=s5:_id(),SeedId='ObsidianMawSeed',Odds=1e12,Size=123.456,Mutation='Diamond',At=unix()});s5:_queue(e)end
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
 check(select(1,X.Execute(ctx,p1,'announce',{'fire','pepper','gold'}))==true and log[1].Payload.SeedId=='FirePepperSeed'and log[1].Payload.Mutation=='Gold','announce fire pepper gold: the plant name in words and a coat')
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
 local r1,rm=X.Execute(ctx,p1,'announce',{'record'});check(r1==true and log[1].Payload.Kind=='Record'and log[1].Payload.Record=='BestPull'and log[1].Payload.SeedId==nil,'announce record: BEST PULL TODAY, no seed ('..tostring(rm)..')')
 table.clear(log);X.Execute(ctx,p1,'announce',{'record','fruit','moonmelon'})
 check(log[1].Payload.Record=='BiggestFruit'and log[1].Payload.SeedId=='MoonflowerSeed','announce record fruit moonmelon: BIGGEST FRUIT TODAY with Moon Melon\'s picture')
 table.clear(log);local okK,msgK=X.Execute(ctx,p1,'announce',{'record','bestpull',kingKey})
 check(okK==true and log[1].Payload.Record=='BestPull'and log[1].Payload.SeedId==KING.id,'announce record bestpull '..kingKey..': '..tostring(msgK))
 check(select(1,X.Execute(ctx,p1,'announce',{'record','nonsense'}))==false,'announce record with an unknown seed is refused')
 -- the help rows and the docs
 local Help=W.module('StudioTestHelp');local rows=0;for _,row in ipairs(Help)do if row[1]:find('/test announce',1,true)then rows+=1 end end
 check(rows==3,'three /test announce rows in the in-game command list ('..rows..')')
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
