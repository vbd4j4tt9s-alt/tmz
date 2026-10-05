--!nocheck
-- R151 hub displays: HubDisplayStore (the MemoryStore half) against a MemoryStoreService mock that behaves like Roblox's:
--  * UpdateAsync is a compare-and-set (the transform runs AGAIN when another server wrote between its read and its commit); the mock lets a test interfere at exactly that
--    moment (backend.Race), so races between two servers are real here;
--  * keys expire, every request is counted, any call can fail with any message, GetHashMap itself can fail.
-- Checked: the key and the document, compare-and-set (a worse record never replaces a better one, a better one always wins, whoever commits first), both kinds in one
-- document without clobbering each other, errors never throw and back off (5, 10, 20 ... up to 300 s; 90 s or more after a throttle), this server's own request budget,
-- junk in the store, expiry (two days), removal, and that nothing but plain numbers / strings / booleans is ever stored.
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('HubDisplayRules');local Store=H.server('HubDisplayStore')
local function pull(over)
 local base={Uid=1,Name='A',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='Mythic',Odds=.125,Scale=1,Coat='None',At=1000}
 for k,v in pairs(over or{})do base[k]=v end
 return Rules.CleanPull(base)
end
local function fruit(over)
 local base={Uid=1,Name='A',Id='SunflowerSeed',Scale=2,Coat='None',Weather='None',At=1000}
 for k,v in pairs(over or{})do base[k]=v end
 return Rules.CleanFruit(base)
end
local DAY=20727;local KEY='d'..DAY
-- a server: a store on the shared backend with its own clock
local function server(backend,clock)
 local svc=HH.memoryService(backend)
 return Store.new({Service=svc,Clock=clock.now}),svc
end

-- 1. Reading and writing -------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local clock=HH.clock();backend.Now=function()return clock.t end
 local a=server(backend,clock)
 check(Store.Key(DAY)=='d20727'and Store.Key(20727.9)=='d20727','one key per UTC day: d20727')
 local ok,doc=a:Read(DAY)
 check(ok and next(doc)==nil,'a day with nothing in it reads as an empty document')
 check(backend.Calls.GetMap==1 and backend.Calls.Get==1,'one read is one GetAsync (and the hash map is fetched once)')
 a:Read(DAY);check(backend.Calls.GetMap==1,'the hash map object is kept')
 local ok2,doc2,took=a:Merge(DAY,'Pull',pull(),'SunflowerSeed')
 check(ok2 and took and doc2.pull and doc2.pull.Rarity=='Mythic'and doc2.fruit==nil,'the first pull is stored')
 local stored=backend.peek(Rules.StoreName,KEY)
 check(stored and stored.v==1 and stored.pull.Name=='A'and stored.pull.Odds==.125 and stored.pull.Rank==nil and stored.pull.Kg==nil,'the stored document is {v=1, pull={nine plain fields}}')
 local entry=backend.Maps[Rules.StoreName][KEY]
 check(entry.Expires==clock.t+2*86400,'the key expires in two days')
 local plain=true
 local function walk(t)for k,v in pairs(t)do if type(v)=='table'then walk(v)elseif not(type(v)=='number'or type(v)=='string'or type(v)=='boolean')then plain=false end end end
 walk(stored)
 check(plain,'only numbers, strings and booleans are stored')
 local _,d3=a:Merge(DAY,'Fruit',fruit(),'SunflowerSeed')
 check(d3.pull and d3.fruit,'the fruit goes into the same document (one read gets both)')
 local _,d4=a:Read(DAY)
 check(Rules.Key(d4.pull)==Rules.Key(pull())and Rules.Key(d4.fruit)==Rules.Key(fruit()),'reading gives the same records back')
 -- the store is by day
 local _,other=a:Read(DAY+1)
 check(next(other)==nil,'tomorrow\'s key is empty')
 -- expiry
 clock.advance(2*86400+1)
 local _,gone=a:Read(DAY)
 check(next(gone)==nil,'after two days the day\'s document is gone')
end

-- 2. Compare-and-set ------------------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local clock=HH.clock();backend.Now=function()return clock.t end
 local a=server(backend,clock);local b=server(backend,clock)
 local common=pull({Rarity='Common',Odds=40,Uid=1})
 local mythic=pull({Rarity='Mythic',Odds=.1,Uid=2})
 local king=pull({Rarity='King',Odds=1e-9,Uid=3})
 local _,_,took=a:Merge(DAY,'Pull',mythic)
 check(took,'A stores a Mythic')
 local ok,doc,took2=b:Merge(DAY,'Pull',common)
 check(ok and doc==nil and took2==false,'B\'s Common is refused (cancelled): the stored Mythic stays')
 check(backend.peek(Rules.StoreName,KEY).pull.Rarity=='Mythic','the store still holds the Mythic')
 local _,doc3,took3=b:Merge(DAY,'Pull',king)
 check(took3 and doc3.pull.Rarity=='King','B\'s King replaces it')
 local _,doc4,took4=a:Merge(DAY,'Pull',mythic)
 check(took4==false and doc4==nil and backend.peek(Rules.StoreName,KEY).pull.Rarity=='King','A cannot put the Mythic back')
 local _,doc5,took5=a:Merge(DAY,'Pull',king)
 check(took5==false and doc5==nil,'the same record again is not "better": it is left as it is (no write)')
 -- the race: A reads the Mythic, B writes the King before A commits: A's transform runs again and cancels
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 a:Merge(DAY,'Pull',mythic)
 local transforms=backend.Transforms
 backend.Race=function()b:Merge(DAY,'Pull',king)end
 local secret=pull({Rarity='Secret',Odds=.01,Uid=4})
 local _,doc6,took6=a:Merge(DAY,'Pull',secret)
 check(took6==false and doc6==nil and backend.peek(Rules.StoreName,KEY).pull.Rarity=='King','a Secret that loses a race against a King (written between its read and its commit) does not overwrite it')
 check(backend.Transforms-transforms>=3,'the transform ran again on the fresh value (the compare-and-set retry)')
 -- the race the other way: the interfering write is WORSE than ours: ours wins
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 a:Merge(DAY,'Pull',common)
 backend.Race=function()b:Merge(DAY,'Pull',pull({Rarity='Rare',Odds=5,Uid=9}))end
 local _,doc7,took7=a:Merge(DAY,'Pull',mythic)
 check(took7 and doc7.pull.Rarity=='Mythic'and backend.peek(Rules.StoreName,KEY).pull.Rarity=='Mythic','a Mythic that races a Rare written meanwhile still wins')
 -- two servers finishing "at the same moment" with identical records: exactly one stays, deterministically
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 local pa=pull({Uid=7,Name='Low'});local pb=pull({Uid=3,Name='High'})
 backend.Race=function()b:Merge(DAY,'Pull',pb)end
 local _,_,tookA=a:Merge(DAY,'Pull',pa)
 check(backend.peek(Rules.StoreName,KEY).pull.Uid==3 and tookA==false,'two identical pulls at the same second: the smaller user id stays, whoever commits first')
 -- the two kinds do not clobber each other
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 backend.Race=function()b:Merge(DAY,'Fruit',fruit({Uid=2,Scale=3}))end
 local _,doc8,took8=a:Merge(DAY,'Pull',mythic)
 check(took8 and doc8.pull and doc8.fruit and doc8.fruit.Uid==2,'a pull written while a fruit lands keeps the fruit (the transform sees the fresh document)')
 local stored=backend.peek(Rules.StoreName,KEY)
 check(stored.pull and stored.fruit,'both records are in the store')
 -- fruit: heavier wins, equal weight: earlier
 local _,_,f1=a:Merge(DAY,'Fruit',fruit({Uid=5,Scale=4}))
 local _,_,f2=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=3.5}))
 local _,_,f3=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=4,At=2000}))
 local _,_,f4=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=4,At=500}))
 check(f1 and not f2 and not f3 and f4 and backend.peek(Rules.StoreName,KEY).fruit.Uid==6,'fruit: a heavier one wins, a lighter or a later equal one does not, an earlier equal one does')
 -- junk already in the store
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock)
 HH.memoryService(backend):GetHashMap(Rules.StoreName):SetAsync(KEY,{v=1,pull={Rarity='Bogus'},fruit='junk'},100)
 local okJ,docJ=a:Read(DAY)
 check(okJ and next(docJ)==nil,'a document with unusable fields reads as empty')
 local _,docK,tookK=a:Merge(DAY,'Pull',pull())
 check(tookK and docK.pull,'and is written over by a real record')
 HH.memoryService(backend):GetHashMap(Rules.StoreName):SetAsync(KEY,12345,100)
 local _,docL,tookL=a:Merge(DAY,'Pull',pull())
 check(tookL and docL.pull,'even a stored number (not a table) is replaced, nothing throws')
end

-- 3. Failures never throw and back off ---------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local clock=HH.clock();backend.Now=function()return clock.t end
 local a,svc=server(backend,clock)
 backend.Fail=function()return'HTTP 500 InternalServerError'end
 local ok,why=a:Read(DAY)
 check(ok==false and type(why)=='string'and why:find('500',1,true),'a failed read returns false and why (no throw)')
 local st=a:Status()
 check(st.Failures==1 and st.RetryIn==5 and st.LastError and not st.Throttled,'the first failure waits 5 s')
 local calls=backend.Calls.Get
 local ok2,why2=a:Read(DAY)
 check(ok2==false and why2=='backoff'and backend.Calls.Get==calls,'during the wait nothing is sent to MemoryStore')
 clock.advance(5);a:Read(DAY)
 check(a:Status().Failures==2 and a:Status().RetryIn==10,'the second failure waits 10 s')
 clock.advance(10);a:Read(DAY);check(a:Status().RetryIn==20,'then 20 s')
 for _=1,10 do clock.advance(a:Status().RetryIn);a:Read(DAY)end
 check(a:Status().RetryIn==300,'and never more than 300 s')
 backend.Fail=nil;clock.advance(300)
 local ok3=a:Read(DAY)
 check(ok3 and a:Status().Failures==0 and a:Status().LastError==nil and a:Status().RetryIn==0,'the first success clears the failures')
 -- throttled
 backend.Fail=function()return'429: Too many requests, throttled'end
 a:Read(DAY)
 check(a:Status().Throttled and a:Status().RetryIn>=90,'after a throttle the wait is at least 90 s')
 clock.advance(120);backend.Fail=nil;check(a:Read(DAY)and not a:Status().Throttled,'and it recovers')
 backend.Fail=function()return'RequestsOverLimit: quota exceeded for this universe'end
 a:Read(DAY);check(a:Status().Throttled,'a quota message counts as a throttle too')
 clock.advance(1000);backend.Fail=nil;a:Read(DAY)
 -- a write that fails
 backend.Fail=function(op)if op=='Update'then return'HTTP 503'end end
 local okW,whyW=a:Merge(DAY,'Pull',pull())
 check(okW==false and a:Status().Failures==1,'a failed write returns false (the record stays Unsynced for the caller)')
 clock.advance(5);backend.Fail=nil
 local okW2,docW=a:Merge(DAY,'Pull',pull())
 check(okW2 and docW.pull,'and goes in when the store is back')
 -- GetHashMap itself fails
 local backend2=HH.backend();backend2.FailGetMap='MemoryStoreService is unavailable'
 local clock2=HH.clock();backend2.Now=function()return clock2.t end
 local c=server(backend2,clock2)
 local okM,whyM=c:Read(DAY)
 check(okM==false and tostring(whyM):find('unavailable',1,true)and c:Status().Failures==1,'a service that cannot hand out the map is a failure like any other')
 backend2.FailGetMap=nil;clock2.advance(5)
 check(c:Read(DAY),'and the map is asked for again later')
 -- no service at all
 local d=Store.new({Service=setmetatable({},{__index=function()error('no such service')end}),Clock=clock.now})
 local okN=d:Read(DAY)
 check(okN==false,'a missing MemoryStoreService is a failed request, not an error')
 check(Store.new({Disabled=true}):Read(DAY)==false,'a disabled store refuses everything')
 local rm=Store.new({Service=svc,Clock=clock.now});check(rm:Remove(DAY),'Remove works (the owner\'s reset)')
end

-- 4. This server's request budget ------------------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local clock=HH.clock();backend.Now=function()return clock.t end
 local a=server(backend,clock)
 local allowed=0;local refused
 for i=1,30 do local ok,why=a:Read(DAY);if ok then allowed+=1 else refused=why end;clock.advance(1)end
 check(allowed==Rules.RequestsPerMinute and refused=='budget','at most '..Rules.RequestsPerMinute..' requests in a minute leave this server (the 13th is refused: "budget"), '..allowed..' went')
 check(backend.Calls.Get==allowed,'a refused request never reaches MemoryStore')
 check(a:Status().Failures==0,'running out of budget is not a failure (no backoff)')
 clock.advance(60);check(a:Read(DAY),'a minute later requests flow again')
 local per=Rules.RequestsPerMinute
 check(per<=30,'the cap is far below the experience quota (1000 + 100 per player a minute)')
 -- steady state: a poll every ~50 s and a write now and then
 local backend2=HH.backend();local clock2=HH.clock();backend2.Now=function()return clock2.t end
 local b=server(backend2,clock2)
 for _=1,60 do b:Read(DAY);clock2.advance(Rules.PollSeconds+Rules.PollJitter/2)end
 check(backend2.Calls.Get==60 and b:Status().Failures==0,'a poll every 52 s for an hour all go through ('..backend2.Calls.Get..' reads, about 1.2 a minute)')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
