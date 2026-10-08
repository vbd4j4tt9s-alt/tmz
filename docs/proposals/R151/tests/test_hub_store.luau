--!nocheck
-- R151 hub displays: HubDisplayStore (the MemoryStore half) against a MemoryStoreService mock that behaves like Roblox's:
--  * UpdateAsync is a compare-and-set (the transform runs AGAIN when another server wrote between its read and its commit); the mock lets a test interfere at exactly that
--    moment (backend.Race), so races between two servers are real here;
--  * keys expire, every request is counted, any call can fail with any message, GetHashMap itself can fail.
-- Checked: the key and the document, compare-and-set (a worse record never replaces a better one, a better one always wins, whoever commits first), errors never throw and back off
-- (5, 10, 20 ... up to 300 s; 90 s or more after a throttle), this server's own request budget, junk in the store, expiry (two days), removal, and that nothing but plain numbers /
-- strings / booleans is ever stored.
-- R153 (owner: the best pull is "a local server only thing"): the store is BIGGEST FRUIT's alone. A pull is refused before anything is counted or sent (no request, no map, no backoff), a
-- `pull` an older server left in the document is never read, kept or written back, and a fruit's compare-and-set is as it was (the same cases, now with fruit records).
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
 local ok2,doc2,took=a:Merge(DAY,'Fruit',fruit(),'SunflowerSeed')
 check(ok2 and took and doc2.fruit and doc2.fruit.Name=='A'and doc2.pull==nil,'the first fruit is stored')
 local stored=backend.peek(Rules.StoreName,KEY)
 local storedKeys=0;for _ in pairs(stored)do storedKeys+=1 end
 check(stored and stored.v==1 and stored.fruit.Name=='A'and stored.fruit.Scale==2 and stored.fruit.Kg==nil and stored.pull==nil and storedKeys==2,'the stored document is {v=1, fruit={plain fields}} (R153: no pull in it)')
 local entry=backend.Maps[Rules.StoreName][KEY]
 check(entry.Expires==clock.t+2*86400,'the key expires in two days')
 local plain=true
 local function walk(t)for k,v in pairs(t)do if type(v)=='table'then walk(v)elseif not(type(v)=='number'or type(v)=='string'or type(v)=='boolean')then plain=false end end end
 walk(stored)
 check(plain,'only numbers, strings and booleans are stored')
 local _,d4=a:Read(DAY)
 check(Rules.Key(d4.fruit)==Rules.Key(fruit())and d4.pull==nil,'reading gives the same fruit back')
 -- the store is by day
 local _,other=a:Read(DAY+1)
 check(next(other)==nil,'tomorrow\'s key is empty')
 -- expiry
 clock.advance(2*86400+1)
 local _,gone=a:Read(DAY)
 check(next(gone)==nil,'after two days the day\'s document is gone')
end

-- 1b. R153: a pull never goes through the store ----------------------------------------------------------------------------------------------------------------------
do
 local backend=HH.backend();local clock=HH.clock();backend.Now=function()return clock.t end
 local a=server(backend,clock)
 local ok,why,took,foreign=a:Merge(DAY,'Pull',pull(),'SunflowerSeed')
 check(ok==false and why=='local only'and took==nil and foreign==nil,'offering a pull is refused: false, "local only"')
 local calls=0;for _,n in pairs(backend.Calls)do calls+=n end
 check(calls==0 and backend.peek(Rules.StoreName,KEY)==nil,'nothing reached MemoryStore: no map fetched, no request, nothing written')
 local st=a:Status()
 check(st.Requests==0 and st.Failures==0 and st.RetryIn==0 and st.LastError==nil,'and it counts as no request and no failure (no budget used, no backoff)')
 a:Merge(DAY,'Bogus',pull());a:Merge(DAY,nil,pull());a:Merge(DAY,'pull',pull())
 calls=0;for _,n in pairs(backend.Calls)do calls+=n end
 check(calls==0 and a:Status().Requests==0,'so does any kind that is not the fruit (a nil, a misspelled one)')
 -- 60 offered pulls in a row (a busy server): still nothing, and the budget is still whole
 for i=1,60 do a:Merge(DAY,'Pull',pull({At=i}))end
 check(a:Status().Requests==0 and(backend.Calls.Update or 0)==0,'sixty more pulls: still not one request')
 local ok2=a:Read(DAY)
 check(ok2 and a:Status().Requests==1,'the whole budget is left for the fruit (the next read is the first request)')
 -- what an older server (R151 / R152) left in the document: a pull next to a fruit
 local svc=HH.memoryService(backend)
 svc:GetHashMap(Rules.StoreName):SetAsync(KEY,{v=1,pull={Uid=9,Name='Old',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='King',Odds=1e-9,Scale=1,Coat='None',At=5},
  fruit={Uid=2,Name='Fran',Id='SunflowerSeed',Scale=3,Coat='None',Weather='None',At=9}},100)
 local okR,docR=a:Read(DAY)
 check(okR and docR.pull==nil and docR.fruit and docR.fruit.Name=='Fran','a read gives the fruit and ignores the old pull (never read)')
 local okM,docM,tookM=a:Merge(DAY,'Fruit',fruit({Uid=3,Scale=5,Name='Gus'}),'SunflowerSeed')
 local after=backend.peek(Rules.StoreName,KEY)
 check(okM and tookM and docM.fruit.Name=='Gus'and docM.pull==nil and after.pull==nil and after.fruit.Name=='Gus','a fruit written over such a document keeps no old pull (not kept, not written back)')
 -- a document with ONLY an old pull: it reads as empty; a pull is not a reason to delete anything
 svc:GetHashMap(Rules.StoreName):SetAsync('d'..(DAY+1),{v=1,pull={Uid=9,Name='Old',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='King',Odds=1e-9,Scale=1,Coat='None',At=5}},100)
 local okO,docO=a:Read(DAY+1)
 check(okO and next(docO)==nil,'an old document with only a pull reads as empty (no migration)')
 check(backend.peek(Rules.StoreName,'d'..(DAY+1))~=nil and backend.peek(Rules.StoreName,'d'..(DAY+1)).pull~=nil,'and reading it deletes nothing: the old data is simply left alone to expire')
end

-- 2. Compare-and-set ------------------------------------------------------------------------------------------------------------------------------------------
-- (R153: with fruit records: a heavier fruit wins, as a higher rarity did. light < mid < secret < heavy < huge.)
do
 local backend=HH.backend();local clock=HH.clock();backend.Now=function()return clock.t end
 local a=server(backend,clock);local b=server(backend,clock)
 local light=fruit({Scale=1,Uid=1})
 local mid=fruit({Scale=2,Uid=2})
 local heavy=fruit({Scale=4,Uid=3})
 local _,_,took=a:Merge(DAY,'Fruit',mid)
 check(took,'A stores a 2x fruit')
 local ok,doc,took2=b:Merge(DAY,'Fruit',light)
 check(ok and doc==nil and took2==false,'B\'s lighter fruit is refused (cancelled): the stored one stays')
 check(backend.peek(Rules.StoreName,KEY).fruit.Scale==2,'the store still holds the 2x fruit')
 local _,doc3,took3=b:Merge(DAY,'Fruit',heavy)
 check(took3 and doc3.fruit.Scale==4,'B\'s 4x fruit replaces it')
 local _,doc4,took4=a:Merge(DAY,'Fruit',mid)
 check(took4==false and doc4==nil and backend.peek(Rules.StoreName,KEY).fruit.Scale==4,'A cannot put the 2x back')
 local _,doc5,took5=a:Merge(DAY,'Fruit',heavy)
 check(took5==false and doc5==nil,'the same record again is not "better": it is left as it is (no write)')
 -- the race: A reads the 2x, B writes the 4x before A commits: A's transform runs again and cancels
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 a:Merge(DAY,'Fruit',mid)
 local transforms=backend.Transforms
 backend.Race=function()b:Merge(DAY,'Fruit',heavy)end
 local between=fruit({Scale=3,Uid=4})
 local _,doc6,took6=a:Merge(DAY,'Fruit',between)
 check(took6==false and doc6==nil and backend.peek(Rules.StoreName,KEY).fruit.Scale==4,'a 3x fruit that loses a race against a 4x (written between its read and its commit) does not overwrite it')
 check(backend.Transforms-transforms>=3,'the transform ran again on the fresh value (the compare-and-set retry)')
 -- the race the other way: the interfering write is WORSE than ours: ours wins
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 a:Merge(DAY,'Fruit',light)
 backend.Race=function()b:Merge(DAY,'Fruit',fruit({Scale=1.5,Uid=9}))end
 local _,doc7,took7=a:Merge(DAY,'Fruit',mid)
 check(took7 and doc7.fruit.Scale==2 and backend.peek(Rules.StoreName,KEY).fruit.Scale==2,'a 2x fruit that races a 1.5x written meanwhile still wins')
 -- two servers finishing "at the same moment" with identical fruit: exactly one stays, deterministically
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 local fa=fruit({Uid=7,Name='Low'});local fb=fruit({Uid=3,Name='High'})
 backend.Race=function()b:Merge(DAY,'Fruit',fb)end
 local _,_,tookA=a:Merge(DAY,'Fruit',fa)
 check(backend.peek(Rules.StoreName,KEY).fruit.Uid==3 and tookA==false,'two identical fruits at the same second: the smaller user id stays, whoever commits first')
 -- an older server writes its pull into the document while our fruit lands: ours is written, the pull is not carried over
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 backend.Race=function()HH.memoryService(backend):GetHashMap(Rules.StoreName):SetAsync(KEY,{v=1,pull={Uid=2,Name='Old',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='King',Odds=1e-9,Scale=1,Coat='None',At=5}},100)end
 local _,doc8,took8=a:Merge(DAY,'Fruit',mid)
 check(took8 and doc8.fruit and doc8.pull==nil and backend.peek(Rules.StoreName,KEY).pull==nil,'a pull an older server writes while our fruit lands is not kept (the document holds the fruit only)')
 backend.Race=nil
 -- fruit: heavier wins, equal weight: earlier
 local _,_,f1=a:Merge(DAY,'Fruit',fruit({Uid=5,Scale=4}))
 local _,_,f2=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=3.5}))
 local _,_,f3=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=4,At=2000}))
 local _,_,f4=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=4,At=500}))
 check(f1 and not f2 and not f3 and f4 and backend.peek(Rules.StoreName,KEY).fruit.Uid==6,'fruit: a heavier one wins, a lighter or a later equal one does not, an earlier equal one does')
 -- R152: a stored fruit of ANOTHER type (a server on another plant list) is never compared and never replaced; the writer is told (Foreign) and nothing is written
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock);b=server(backend,clock)
 a:Merge(DAY,'Fruit',fruit({Uid=5,Scale=2}),'SunflowerSeed')
 local updates=backend.Calls.Update
 local okF,docF,tookF,foreignF=b:Merge(DAY,'Fruit',fruit({Uid=6,Id='AppleSeed',Scale=40}),'AppleSeed')
 check(okF and docF==nil and tookF==false and foreignF==true and backend.peek(Rules.StoreName,KEY).fruit.Uid==5,'another type of fruit, however heavy, does not replace the stored one: answered Foreign, nothing written')
 local okS,docS,tookS,foreignS=b:Merge(DAY,'Fruit',fruit({Uid=6,Scale=1}),'SunflowerSeed')
 check(okS and docS==nil and tookS==false and foreignS==false,'a lighter fruit of the SAME type is a plain "someone else is better" (not Foreign)')
 local okP,whyP=b:Merge(DAY,'Pull',pull(),'AppleSeed')
 check(okP==false and whyP=='local only'and backend.peek(Rules.StoreName,KEY).fruit.Uid==5,'R153: a pull is refused whatever fruit the document holds, and the fruit stays')
 check(backend.Calls.Update==updates+2,'(each of the two fruit answers was one request; the pull was none)')
 -- junk already in the store
 backend=HH.backend();backend.Now=function()return clock.t end
 a=server(backend,clock)
 HH.memoryService(backend):GetHashMap(Rules.StoreName):SetAsync(KEY,{v=1,pull={Rarity='Bogus'},fruit='junk'},100)
 local okJ,docJ=a:Read(DAY)
 check(okJ and next(docJ)==nil,'a document with unusable fields reads as empty')
 local _,docK,tookK=a:Merge(DAY,'Fruit',fruit())
 check(tookK and docK.fruit,'and is written over by a real record')
 HH.memoryService(backend):GetHashMap(Rules.StoreName):SetAsync(KEY,12345,100)
 local _,docL,tookL=a:Merge(DAY,'Fruit',fruit())
 check(tookL and docL.fruit,'even a stored number (not a table) is replaced, nothing throws')
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
 local okW,whyW=a:Merge(DAY,'Fruit',fruit())
 check(okW==false and a:Status().Failures==1,'a failed write returns false (the record stays Unsynced for the caller)')
 clock.advance(5);backend.Fail=nil
 local okW2,docW=a:Merge(DAY,'Fruit',fruit())
 check(okW2 and docW.fruit,'and goes in when the store is back')
 -- R153: a refused pull does not take part in the backoff: while the store backs off and after, it is the same refusal and costs nothing
 backend.Fail=function()return'HTTP 500'end;clock.advance(10);a:Read(DAY)
 local failures,calls=a:Status().Failures,backend.Calls.Get
 local okX,whyX=a:Merge(DAY,'Pull',pull())
 check(okX==false and whyX=='local only'and a:Status().Failures==failures and backend.Calls.Get==calls,'a pull offered while the store is backing off is refused as a pull (not "backoff"), and changes nothing')
 backend.Fail=nil;clock.advance(1000);a:Read(DAY)
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
