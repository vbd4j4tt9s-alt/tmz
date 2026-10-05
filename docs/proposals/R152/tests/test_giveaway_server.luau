--!nocheck
-- R152 Void Pack giveaway, the server: VoidGiveawayRules152 / VoidGiveawayStore152 / VoidGiveaway152 on the Roblox mock with a DataStore mock that is a real compare-and-set (two
-- "servers" share one backend and one MessagingService bus), a fake PlayerDataService and a fake clock. Covers:
--  1. the rule (Reserve) and the numbers;  2. a claim: ONE real Void Pack (not TestGrant), count + 1, the profile flag, the save, the notice, the stored value;
--  3. a second claim refused;  4. two servers racing at 499: only one gets the last pack;  5. at 500 every claim refused, prompt off, "ALL CLAIMED", for ever;
--  6. a full Bag: nothing reserved;  7. an interrupted grant: given again once, never twice;  8. a DataStore failure: no pack, retries with backoff, then "try again";
--  9. messaging: another server's claim lowers the number here;  10. polling (45-60 s, backoff, stops at the cap);  11. the Studio fallback (own store, in-memory counter, one warn);
--  12. the owner commands (voidgift, reset me, left N: Studio only);  13. guards (data, save, distance, busy, rate, leaving).
local G=require('./giveaway_harness');local H,W,R,E=G.H,G.W,G.R,G.E;local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=G.Rules;local CAP=Rules.Cap
local warns={};W.env.warn=function(...)local t={};for _,v in ipairs({...})do t[#t+1]=tostring(v)end;warns[#warns+1]=table.concat(t,' ')end
local function warnCount()return #warns end
local KEY='VoidGiveaway152/Claims';local STUDIO_KEY='VoidGiveaway152_Studio/Claims'
local function stored(b,key)return b.Data[key or KEY]end
local function seedStore(b,count,ids,key)
 local users={};for i,id in ipairs(ids or{})do users[tostring(id)]=1700000000+i end
 local n=0;for _ in pairs(users)do n+=1 end
 b.Data[key or KEY]={Count=count or n,Users=users};b.Version[key or KEY]=1
end
local function filler(from,n)local ids={};for i=1,n do ids[i]=from+i end;return ids end
local function new(b,bus,o)
 o=o or{};local s=G.server(b,bus,o);s.Svc:Start();return s
end
local function voidPacks(s,p)return s.Data:voidPacks(p)end
local function prompt(s)return s.Svc.Pedestal.Prompt end
local function attr(s,k)return s.Svc.Model:GetAttribute(k)end

-- 1. The rule and the numbers ------------------------------------------------------------------------------------------------------------------------------------
do
 check(Rules.Cap==500,'the cap is 500')
 check(Rules.StoreName=='VoidGiveaway152'and Rules.Key=='Claims'and Rules.Topic=='VoidGiveaway152','store VoidGiveaway152, key Claims, topic VoidGiveaway152')
 check(Rules.StudioStoreName~=Rules.StoreName,'Studio has its own store name (never the live key)')
 local v,o,cur=Rules.Reserve(nil,101,1700000000,CAP)
 check(o=='new'and v.Count==1 and v.Users['101']==1700000000 and cur==v,'the first user: new, Count 1, Users[\'101\'] = the time')
 local v2,o2,cur2=Rules.Reserve(v,101,1700000099,CAP)
 check(v2==nil and o2=='already'and cur2.Count==1 and cur2.Users['101']==1700000000,'the same user again: already, nothing to write, the time is not overwritten')
 local old={Count=499,Users=(function()local u={};for i=1,499 do u[tostring(1000+i)]=1 end;return u end)()}
 local v3,o3=Rules.Reserve(old,5,1,CAP);check(o3=='new'and v3.Count==500,'499 -> 500 is allowed')
 local v4,o4,cur4=Rules.Reserve(v3,6,1,CAP);check(v4==nil and o4=='full'and cur4.Count==500 and cur4.Users['6']==nil,'at 500: full, nothing added')
 local v5=Rules.Reserve({Count=3,Users={}},9,1,CAP);check(v5.Count==4,'Count 3 with no listed users: the next claim makes 4 (Count is the authority)')
 local clean=Rules.Clean({Count=-5,Users={['12']=5,['x']=1,['1.5']=2,['007']=3,['0']=4,[9]=5,['77']='t'}})
 check(clean.Count==1 and clean.Users['12']==5 and next(clean.Users,next(clean.Users))==nil,'junk in the store is cleaned: only canonical user ids with a time count; Count is at least the number of users')
 check(Rules.Clean('junk').Count==0 and Rules.Clean(nil).Count==0 and Rules.Clean(12).Count==0,'a value that is not a table reads as empty')
 check(Rules.Left(0)==500 and Rules.Left(13)==487 and Rules.Left(500)==0 and Rules.Left(9999)==0 and Rules.Left(-4)==500,'Left = 500 - Count, clamped')
 check(Rules.LeftText(487)=='487 / 500 LEFT'and Rules.LeftText(0)=='0 / 500 LEFT','the number reads "487 / 500 LEFT"')
 check(Rules.Pack.BagVariant=='EclipseReliquary'and Rules.Pack.Stage==7,'the pack is the Void Pack (EclipseReliquary, stage 7: what Verity takes)')
 local V=W.module('VerityConfig');check(V.VoidVariant==Rules.Pack.BagVariant,'... the same variant VerityConfig calls a Void Pack')
end

-- 2. A claim ------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 local s=new(b,bus);local p=G.player(s,101,'Ava')
 check(attr(s,'Count')==0 and attr(s,'Left')==500 and attr(s,'State')=='Open'and prompt(s).Enabled==true,'a fresh pedestal: Count 0, Left 500, Open, the prompt on')
 check(attr(s,'Cap')==500,'the model carries Cap')
 local ok,record=s.Svc:Claim(p)
 check(ok==true and record and record.Kind=='Pack'and record.BagVariant=='EclipseReliquary'and record.Stage==7,'the claim gives a Void Pack record (EclipseReliquary, stage 7)')
 check(voidPacks(s,p)==1 and #s.Data:GetChestRecords(p)==1,'exactly one pack is in the Bag')
 check(record.TestGrant==nil,'a REAL pack: not flagged TestGrant (it announces when opened like any pack)')
 check(record.PackSize==1 and record.PackMutation=='None','a plain 1x pack')
 check(s.Data:GetPremium(p).VoidGift152==true,'the profile flag Premium.VoidGift152 is set')
 check((s.Data.Dirty[p]or 0)>=1 and(s.Data.Saves[p]or 0)>=1,'saved the way other grants are (MarkDirty + QueueGardenSave)')
 check(s.Chests.Syncs==1,'the hotbar is synced (ChestService:SyncTools)')
 local v=stored(b)
 check(v and v.Count==1 and v.Users['101']==1760000000,'the shared value is {Count = 1, Users = {["101"] = unix time}}')
 check(b.Calls.Writes==1,'one write')
 check(attr(s,'Count')==1 and attr(s,'Left')==499,'the number is 499 / 500 now (Count 1)')
 check(p:GetAttribute('VoidGift152')=='Claimed'and type(p:GetAttribute('VoidGiftAt152'))=='number','the player is Claimed (and the claim moment is stamped for their client)')
 local n=s.Notes:last(p);check(n and n.Text:find('FREE VOID PACK',1,true)and n.Kind==nil,'the pack-received notice (the game\'s notice feed): "FREE VOID PACK! Check your Bag!"')
 check(prompt(s).Enabled==true,'the pedestal prompt stays on for everyone else')
 -- a second player
 local q=G.player(s,102,'Bo');s.Svc:Claim(q);check(stored(b).Count==2 and attr(s,'Left')==498,'a second player: Count 2, 498 left')
end

-- 3. A second claim is refused ----------------------------------------------------------------------------------------------------------------------------------
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 local s=new(b,bus);local p=G.player(s,101,'Ava');s.Svc:Claim(p)
 local writes,updates=b.Calls.Writes,b.Calls.Update
 local ok,why=s.Svc:Claim(p)
 check(ok==false and why=='claimed','a second claim is refused (flag)')
 check(voidPacks(s,p)==1 and b.Calls.Writes==writes and b.Calls.Update==updates,'no second pack, and the store was not even asked')
 local n=s.Notes:last(p);check(n and n.Text:find('already',1,true)and n.Kind=='Denied','"you already claimed" (a refusal click)')
 check(p:GetAttribute('VoidGift152')=='Claimed','still Claimed')
 -- rejoining on another server: the saved profile has the flag
 local s2=new(b,bus,{Name='B'});local again=G.player(s2,101,'Ava',{Flag=true})
 local ok2,why2=s2.Svc:Claim(again);check(not ok2 and why2=='claimed'and voidPacks(s2,again)==0 and b.Calls.Writes==writes,'on another server the flag stops it too: no pack, no write')
 s2.Svc:Step();check(again:GetAttribute('VoidGift152')=='Claimed','the flagged player is Claimed when the other server sees them')
 -- the global list alone also stops a second PROFILE from counting twice: a user already listed is never added again (Count stays)
 local q=G.player(s2,101,'Ava2',{});q.UserId=101
 local ok3=s2.Svc:Claim(q)
 check(stored(b).Count==1,'a user is in the shared list once, ever: Count is still 1')
end

-- 4. Two servers racing at 499: only one gets it ----------------------------------------------------------------------------------------------------------------
for round=1,2 do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 seedStore(b,499,filler(5000,499))
 local A=new(b,bus,{Name='A'});local B=new(b,bus,{Name='B'})
 local p1=G.player(A,201,'On A');local p2=G.player(B,202,'On B')
 check(attr(A,'Left')==1 and attr(B,'Left')==1,'round '..round..': both servers show 1 left')
 -- the first claimer's UpdateAsync has computed its new value; before it commits, the other server's claim lands
 local first,second,firstP,secondP=A,B,p1,p2;if round==2 then first,second,firstP,secondP=B,A,p2,p1 end
 local inner
 b.Race=function()inner={second.Svc:Claim(secondP)}end
 local ok,why=first.Svc:Claim(firstP)
 check(inner and inner[1]==true,'round '..round..': the claim that committed first got the pack')
 check(ok==false and why=='empty','round '..round..': the other one, whose transform ran again on the fresh value, was refused (full)')
 check(voidPacks(second,secondP)==1 and voidPacks(first,firstP)==0,'round '..round..': exactly one Void Pack was given')
 check(first.Data:GetPremium(firstP).VoidGift152==nil and second.Data:GetPremium(secondP).VoidGift152==true,'round '..round..': only the winner has the flag')
 local v=stored(b);check(v.Count==500 and v.Users[tostring(secondP.UserId)]~=nil and v.Users[tostring(firstP.UserId)]==nil,'round '..round..': the store is at 500 with the winner in it, not the loser')
 check(b.Calls.Transforms>=3,'round '..round..': the loser\'s transform ran again (a compare-and-set retry)')
 check(attr(first,'Left')==0 and attr(first,'State')=='Empty'and prompt(first).Enabled==false,'round '..round..': the loser\'s server shows 0 / ALL CLAIMED and its prompt is off')
 check(attr(second,'Left')==0 and prompt(second).Enabled==false,'round '..round..': so does the winner\'s')
 check(first.Notes:last(firstP).Text:find('claimed',1,true)~=nil,'round '..round..': the loser is told they are all claimed')
 check(firstP:GetAttribute('VoidGift152')=='Open','round '..round..': the loser may still be offered it never (state Open, nothing taken)')
end
-- many racers on one remaining slot: 8 players on 4 servers, each one's UpdateAsync interrupted by the next
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 seedStore(b,498,filler(7000,498))
 local servers,players={},{}
 for i=1,4 do servers[i]=new(b,bus,{Name='S'..i});players[#players+1]=G.player(servers[i],300+i,'P'..i);players[#players+1]=G.player(servers[i],310+i,'Q'..i)end
 local results={}
 for i,p in ipairs(players)do
  local s=servers[(i-1)//2+1]
  local ok=s.Svc:Claim(p);results[#results+1]=ok
 end
 local winners=0;for _,ok in ipairs(results)do if ok then winners+=1 end end
 local given=0;for i,p in ipairs(players)do given+=servers[(i-1)//2+1].Data:voidPacks(p)end
 check(winners==2 and given==2 and stored(b).Count==500,'8 claims for 2 places: exactly 2 packs, the store at exactly 500 (never more)')
end

-- 5. At 500 every claim is refused, the prompt is off, for ever -----------------------------------------------------------------------------------------------------
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 seedStore(b,500,filler(9000,500))
 local s=new(b,bus);local ps={}
 for i=1,5 do ps[i]=G.player(s,400+i,'P'..i)end
 check(attr(s,'Left')==0 and attr(s,'State')=='Empty','at 500 the pedestal shows Left 0 and State Empty')
 check(prompt(s).Enabled==false,'the prompt is disabled')
 local plaque=s.Svc.Pedestal.Plaques[1];check(plaque.Text=='ALL CLAIMED','the pedestal says ALL CLAIMED')
 local updates=b.Calls.Update
 for i,p in ipairs(ps)do local ok,why=s.Svc:Claim(p);check(not ok and why=='empty','player '..i..': refused (all claimed)')end
 check(b.Calls.Update==updates,'refusing costs no DataStore request at all')
 check(s.Data:voidPacks(ps[1])==0 and stored(b).Count==500,'no pack was given, the count is 500')
 check(s.Notes:last(ps[1]).Text:find('500',1,true)~=nil,'"All 500 free Void Packs have been claimed."')
 -- a server that does not know yet (stale count 400) still cannot go past 500: the store says full
 local b2=G.backend();seedStore(b2,500,filler(9000,500))
 local s2=G.server(b2,nil,{Name='C'});s2.Svc:Start()
 s2.Svc.Count=400;s2.Svc.ReadFull=false;s2.Svc:_show()
 local late=G.player(s2,450,'Late');local ok,why=s2.Svc:Claim(late)
 check(ok==false and why=='empty'and stored(b2).Count==500 and s2.Data:voidPacks(late)==0,'a server with a stale count (400): the store answers full, nothing is given, Count stays 500')
 check(attr(s2,'Left')==0 and prompt(s2).Enabled==false,'and it learns it: 0 left, prompt off')
 -- it stays like that for ever: lower counts never bring it back
 s.Svc:_onMessage({Data='v1:3'});check(attr(s,'Left')==0,'a message with a lower count changes nothing')
 b.Data[KEY]={Count=10,Users={}};b.Version[KEY]=9;s.Clock.advance(500);s.Svc.NextPoll=0;s.Svc.ReadFull=false;s.Svc:Step()
 check(attr(s,'Left')==0 and attr(s,'State')=='Empty'and prompt(s).Enabled==false,'even a store that was reset by hand does not reopen a running server (the highest count seen wins)')
 -- the 500th claim itself: 499 -> 500 turns the pedestal off here
 local b3=G.backend();local bus3=E.bus(function()return 0 end,function()return 0 end)
 seedStore(b3,499,filler(9000,499));local s3=new(b3,bus3);local last=G.player(s3,460,'Last')
 check(s3.Svc:Claim(last)==true and attr(s3,'Left')==0 and prompt(s3).Enabled==false and s3.Svc.Pedestal.Plaques[2].Text=='ALL CLAIMED','the 500th claim gives its pack and switches the pedestal to 0 / ALL CLAIMED / prompt off')
end

-- 6. A full Bag: nothing is reserved ------------------------------------------------------------------------------------------------------------------------------
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 local s=new(b,bus,{Config={MaxSavedChests=5}});local p=G.player(s,501,'Packrat',{Packs=5});s.Svc:Step()
 local ok,why=s.Svc:Claim(p)
 check(ok==false and why=='room','a full Bag: refused ("make room")')
 check(b.Calls.Update==0 and b.Calls.Writes==0 and stored(b)==nil,'NOTHING was reserved: no request, no write, no key')
 check(s.Data:voidPacks(p)==0 and s.Data:GetPremium(p).VoidGift152==nil,'no pack, no flag')
 local n=s.Notes:last(p);check(n and n.Text:lower():find('make room',1,true)and n.Kind=='Denied','the game\'s "make room" notice')
 check(p:GetAttribute('VoidGift152')=='Open','still Open')
 table.remove(s.Data:GetChestRecords(p));local ok2=s.Svc:Claim(p);check(ok2==true and stored(b).Count==1,'with one slot free it works (and then reserves)')
 -- the Bag fills during the reservation (UpdateAsync yields): the place is reserved, the pack waits, nothing is lost or doubled
 local b2=G.backend();local s2=new(b2,nil,{Config={MaxSavedChests=5}});local q=G.player(s2,502,'Quick',{Packs=4})
 b2.Race=function()s2.Data:AddChest(q,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',Weather='None'})end -- a pack lands while we wait for the store
 local ok3,why3=s2.Svc:Claim(q)
 check(ok3==false and why3=='room'and stored(b2).Count==1 and s2.Data:voidPacks(q)==0,'a Bag that filled during the wait: the reservation stands, no pack yet')
 check(s2.Notes:last(q).Text:lower():find('reserved',1,true)~=nil,'"your Void Pack is reserved! Make room"')
 table.remove(s2.Data:GetChestRecords(q),1);s2.Svc:Step()
 check(s2.Data:voidPacks(q)==1 and stored(b2).Count==1,'as soon as there is room the server gives it (once), without a second reservation')
 s2.Svc:Step();s2.Svc:Step();check(s2.Data:voidPacks(q)==1,'and never twice')
end

-- 7. An interrupted grant: given again once, never twice -------------------------------------------------------------------------------------------------------
do
 -- a) the reservation exists, the profile has no flag: the prompt gives the pack, the store is not written again
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 seedStore(b,7,filler(100,6));b.Data[KEY].Users['601']=1700000000;b.Data[KEY].Count=7
 local s=new(b,bus);local p=G.player(s,601,'Cut Off')
 local writes=b.Calls.Writes
 local ok=s.Svc:Claim(p)
 check(ok==true and voidPacks(s,p)==1 and s.Data:GetPremium(p).VoidGift152==true,'in the shared list, no flag: the claim gives the pack now')
 check(b.Calls.Writes==writes and stored(b).Count==7,'it is the same reservation: the store is not written, Count stays 7')
 check(s.Svc:Claim(p)==false and voidPacks(s,p)==1,'a second press gives nothing')
 -- b) no prompt needed: the server gives it when it sees the player (even at 0 left)
 local b2=G.backend();seedStore(b2,500,filler(200,499));b2.Data[KEY].Users['602']=1;b2.Data[KEY].Count=500
 local s2=new(b2,nil);local q=G.player(s2,602,'At Zero')
 check(prompt(s2).Enabled==false and attr(s2,'State')=='Empty','(the pedestal is at 0: prompt off)')
 s2.Svc:Step();check(voidPacks(s2,q)==1 and s2.Data:GetPremium(q).VoidGift152==true,'a player owed a pack at 0 left is given it by the server (no prompt: it is off)')
 s2.Svc:Step();s2.Svc:Step();check(voidPacks(s2,q)==1,'once')
 check(stored(b2).Count==500 and b2.Calls.Writes==0,'and nothing was written')
 -- c) the pack could not be added (AddChest throws): the reservation stands; the next step gives it, once
 local b3=G.backend();local s3=new(b3,nil);local r=G.player(s3,603,'Crash')
 s3.Data.ThrowAdd=true
 local ok3,why3=s3.Svc:Claim(r)
 check(ok3==false and why3=='add'and voidPacks(s3,r)==0 and s3.Data:GetPremium(r).VoidGift152==nil,'AddChest threw: no pack, no flag')
 check(stored(b3).Count==1 and stored(b3).Users['603']~=nil,'the reservation stands (the grant was interrupted)')
 s3.Data.ThrowAdd=false;s3.Svc:Step()
 check(voidPacks(s3,r)==1 and s3.Data:GetPremium(r).VoidGift152==true and stored(b3).Count==1,'the next step gives it: one pack, Count still 1')
 s3.Svc:Step();s3.Svc:Claim(r);check(voidPacks(s3,r)==1,'never twice')
 -- d) a hook that throws AFTER the pack was added still counts (the inventory is the commit point)
 local b4=G.backend();local s4=new(b4,nil);local t=G.player(s4,604,'Hooked');s4.Data.ThrowAfterAdd=true
 local ok4=s4.Svc:Claim(t);check(ok4==true and voidPacks(s4,t)==1 and s4.Data:GetPremium(t).VoidGift152==true,'a throw after AddChest committed: the pack counts, the flag is set')
 s4.Data.ThrowAfterAdd=false;s4.Svc:Step();s4.Svc:Claim(t);check(voidPacks(s4,t)==1,'and it is not given again')
 -- e) the player leaves while the store answers; a new session of the same user is given the pack once
 local b5=G.backend();local s5=new(b5,nil);local u=G.player(s5,605,'Gone')
 b5.Race=function()G.leave(u)end
 local ok5=s5.Svc:Claim(u);check(ok5==false and stored(b5).Users['605']~=nil and s5.Data:voidPacks(u)==0,'left during the reservation: reserved, no pack given to a player who is gone')
 local back=G.player(s5,605,'Gone (back)');s5.Svc:Step();check(voidPacks(s5,back)==1,'when they are back (a profile without the flag) the server gives it, once')
 s5.Svc:Step();check(voidPacks(s5,back)==1,'..once')
 -- f) a claim and the server's own recovery cannot both give the pack: the claim's reservation is read back by a poll while the claim is still waiting
 local b6=G.backend();local s6=new(b6,nil);local w=G.player(s6,606,'Racer')
 b6.Race=function()s6.Svc:Step()end -- (the loop runs while the claim waits for the store)
 s6.Svc:Claim(w);s6.Svc:Step()
 check(voidPacks(s6,w)==1,'a claim waiting on the store and the recovery loop running meanwhile: one pack')
 -- h) the profile gets its flag while the claim waits for the store (another path gave the pack): the claim never gives a second one
 local b8=G.backend();local s8=new(b8,nil);local y=G.player(s8,607,'Twice')
 b8.Race=function()s8.Data:AddChest(y,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',Weather='None'});s8.Data:GetPremium(y).VoidGift152=true end
 local ok8,why8=s8.Svc:Claim(y)
 check(ok8==false and why8=='claimed'and voidPacks(s8,y)==1,'a flag that appears while the claim waits: no second pack (the check and the grant are one step)')
 -- g) a player already flagged is never owed
 local b7=G.backend();seedStore(b7,2,{701,702});local s7=new(b7,nil);local x=G.player(s7,701,'Done',{Flag=true});s7.Svc:Step();s7.Svc:Step()
 check(voidPacks(s7,x)==0,'a flagged player in the list is not given another')
end

-- 8. A DataStore failure: no pack, retries with growing waits, then "try again" -------------------------------------------------------------------------------------
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 local s=new(b,bus);local p=G.player(s,801,'Unlucky')
 b.Fail=function(kind)if kind=='Update'then return '502: DataStore request was throttled'end end
 local ok,why=s.Svc:Claim(p)
 check(ok==false and why=='store','every try fails: refused')
 check(s.Data:voidPacks(p)==0 and s.Data:GetPremium(p).VoidGift152==nil,'NO pack without a successful reservation, no flag')
 check(b.Calls.Update==4,'four tries')
 check(#s.Clock.Waits==3 and s.Clock.Waits[1]<s.Clock.Waits[2]and s.Clock.Waits[2]<s.Clock.Waits[3]and s.Clock.Waits[1]>=.5,'with growing waits between them ('..table.concat(s.Clock.Waits,', ')..')')
 local n=s.Notes:last(p);check(n and n.Text:lower():find('try again',1,true)and n.Kind=='Denied','"try again" (a refusal)')
 check(stored(b)==nil and p:GetAttribute('VoidGift152')=='Open','nothing stored, the player is Open again')
 -- recovers on the third try: one pack, one count
 b.Fail=(function()local n=0;return function(kind)if kind=='Update'then n+=1;if n<=2 then return 'HTTP 500'end end end end)()
 b.Calls.Update=0
 local ok2=s.Svc:Claim(p);check(ok2==true and voidPacks(s,p)==1 and stored(b).Count==1 and b.Calls.Update==3,'two failures then success on the third try: one pack, Count 1')
 -- a failing store at start: the count is unknown, the prompt stays off, then it recovers by itself
 local b2=G.backend();b2.Fail=function()return 'HTTP 503'end
 local s2=new(b2,nil)
 check(s2.Svc.Count==nil and attr(s2,'State')=='Loading'and prompt(s2).Enabled==false,'the first read failed: Loading, the prompt is off')
 check(attr(s2,'Left')==nil,'(no number is shown for an unknown count)')
 b2.Fail=nil;s2.Clock.advance(6);s2.Svc:Step()
 check(s2.Svc.Count==0 and attr(s2,'State')=='Open'and prompt(s2).Enabled==true,'the store came back: the count and the prompt follow after the backoff')
 -- the live server never falls back to memory
 check(s2.Store.Mode=='DataStore'and s.Store.Mode=='DataStore','a live server never uses the in-memory counter')
 -- a transform that is cancelled does not need a second write; a throwing store never throws out of Claim
 local b3=G.backend();local s3=new(b3,nil);local q=G.player(s3,802,'Throw')
 b3.Fail=function()error({})end
 local okx,errx=pcall(s3.Svc.Claim,s3.Svc,q);check(okx and errx==false,'even an error that is not a string does not throw out of Claim')
end

-- 9. Messaging: another server's claim lowers the number here ---------------------------------------------------------------------------------------------------
do
 local clock=G.clock()
 local b=G.backend();local bus=E.bus(clock.now,clock.time)
 local A=new(b,bus,{Name='A',Clock=clock});local B=new(b,bus,{Name='B',Clock=clock})
 check(A.Svc.Subscribed==true and B.Svc.Subscribed==true,'both servers subscribed to the topic')
 check(attr(B,'Left')==500,'B shows 500')
 local p=G.player(A,901,'On A');A.Svc:Claim(p)
 check(bus:Count('A')==1 and bus.Log[#bus.Log].Topic=='VoidGiveaway152'and bus.Log[#bus.Log].Message=='v1:1','A published "v1:1" on the topic after the claim')
 check(attr(B,'Left')==499 and attr(B,'Count')==1,'B\'s number went down to 499 (without reading the store)')
 check(B.Svc.Source=='message'and b.Calls.Get<=2,'from the message (B\'s only reads were its start-up read)')
 -- the highest count wins: an old (lower) message arrives late
 B.Svc:_onMessage({Data='v1:0',Sent=1});check(attr(B,'Left')==499,'a late, lower message does not raise the number')
 local J=new(G.backend(),nil,{Name='J',Clock=clock})
 J.Svc:_onMessage({Data='v1:40'});check(attr(J,'Left')==460,'a higher one does (a server that had 0 shows 460)')
 for _,junk in ipairs({'',' v1:5','v1:-1','v1:501','v1:1.5','v2:5','v1:5;x','5',{Data=7},{Data={}},{},7,true,string.rep('9',200)})do J.Svc:_onMessage(junk)end
 check(attr(J,'Left')==460,'junk messages are ignored (not a string, wrong shape, negative, above the cap, too long)')
 -- coalescing: a burst of claims sends at most one message per 1.5 s, carrying the latest count
 local sent=bus:Count('A')
 local ps={};for i=1,6 do ps[i]=G.player(A,910+i,'Q'..i)end
 for i=1,6 do A.Svc:Claim(ps[i])end
 check(bus:Count('A')-sent<=2,'six claims in a row: at most 2 messages ('..(bus:Count('A')-sent)..')')
 clock.advance(2);R.advance(2);A.Svc:Step()
 check(bus.Log[#bus.Log].Message=='v1:7','the last message carries the latest count (v1:7)')
 check(attr(B,'Left')==493,'B follows to 493')
 -- the publisher hears itself: harmless
 check(attr(A,'Left')==493,'(A heard its own message: unchanged)')
 -- a message that reports the cap: read the store again for the final list
 B.Svc.ReadFull=false;B.Svc:_onMessage({Data='v1:500'});check(attr(B,'Left')==0 and attr(B,'State')=='Empty'and prompt(B).Enabled==false,'a message with 500: 0 left, ALL CLAIMED, prompt off')
 check(B.Svc.NextPoll==0 and B.Svc.ReadFull==false,'and the server reads the store once more soon (the final list of who is owed)')
 -- a failing publish is tried again by the loop
 local b2=G.backend();local bus2=E.bus(clock.now,clock.time);local C=new(b2,bus2,{Name='C',Clock=clock})
 bus2.FailPublish=1;local r=G.player(C,950,'Retry');C.Svc:Claim(r)
 check(bus2:Count('C')==0 and C.Svc.PublishPending==true,'a publish that fails stays pending')
 clock.advance(2);C.Svc:Step();check(bus2:Count('C')==1,'and the loop sends it again')
 -- subscribe fails: tried again later
 local bus3=E.bus(clock.now,clock.time);bus3.FailSubscribe=1;local D=new(G.backend(),bus3,{Name='D',Clock=clock})
 check(D.Svc.Subscribed==false,'a failed subscription is not claimed')
 clock.advance(31);D.Svc:Step();check(D.Svc.Subscribed==true,'it is tried again about 30 s later')
 -- no messaging service at all (the mock has none): the server runs on polls alone
 local E2=new(G.backend(),nil,{Name='E'});check(E2.Svc.Count==0,'without messages the server still works (polls only)')
end

-- 10. Polling ----------------------------------------------------------------------------------------------------------------------------------------------------
do
 local clock=G.clock();local b=G.backend();local bus=E.bus(clock.now,clock.time)
 local A=new(b,bus,{Name='A',Clock=clock});local B=new(b,bus,{Name='B',Clock=clock})
 local gets=b.Calls.Get
 check(A.Svc.NextPoll-clock.t>=45 and A.Svc.NextPoll-clock.t<=60,'the next read is 45-60 s away ('..(A.Svc.NextPoll-clock.t)..')')
 A.Svc:Step();check(b.Calls.Get==gets,'a step before it is due reads nothing')
 clock.advance(44);A.Svc:Step();check(b.Calls.Get==gets,'44 s: still nothing')
 clock.advance(2);A.Svc:Step();check(b.Calls.Get==gets+1,'at 46 s: one read')
 -- A claims on its own; B only polls (its messages are held back): B catches up by reading
 bus.Hold=true
 local p=G.player(A,1001,'Far');A.Svc:Claim(p)
 check(attr(B,'Left')==500,'(B has not heard: the message is held)')
 clock.advance(61);B.Svc:Step();check(attr(B,'Left')==499 and B.Svc.Source=='store','B read the store and shows 499')
 bus.Hold=false
 -- failures back off 5, 10, 20 ... 60 s
 b.Fail=function(k)if k=='Get'then return 'HTTP 500'end end
 clock.advance(100);local before=b.Calls.Get;B.Svc:Step()
 local t1=B.Svc.NextPoll-clock.t;check(b.Calls.Get==before+1 and t1>=5 and t1<=10,'a failed read: tried again in 5 s (got '..t1..')')
 clock.advance(t1+.1);B.Svc:Step();local t2=B.Svc.NextPoll-clock.t;check(t2>=10 and t2<=20,'then 10 s ('..t2..')')
 for _=1,6 do clock.advance(61);B.Svc:Step()end
 check(B.Store:Status().RetryIn<=60 and B.Store:Status().Failures>=7,'never longer than 60 s (failures '..B.Store:Status().Failures..')')
 check(attr(B,'Left')==499,'a failing store leaves the number as it was')
 b.Fail=nil;clock.advance(61);B.Svc:Step();check(B.Svc.PollError==nil,'and it recovers')
 -- once a read has seen the cap the value cannot change: no more reads
 local b2=G.backend();seedStore(b2,500,filler(1,500));local C=new(b2,nil,{Name='C',Clock=clock})
 local g2=b2.Calls.Get;for _=1,10 do clock.advance(61);C.Svc:Step()end
 check(b2.Calls.Get==g2 and C.Svc.ReadFull==true,'at the cap the polling stops (nothing can change any more)')
end

-- 11. The Studio fallback ------------------------------------------------------------------------------------------------------------------------------------------
do
 local b=G.backend();b.Fail=function()return '403: Studio access to APIs is not allowed. Enable it in Game Settings > Security.'end
 local w0=warnCount()
 local s=new(b,nil,{Studio=true,Name='S'})
 check(s.Store.Mode=='Memory','Studio without API access: the in-memory counter')
 check(warnCount()-w0==1 and warns[#warns]:find('in-memory',1,true)and warns[#warns]:find('Enable Studio Access',1,true),'ONE warn line that says how to turn the real store on')
 check(attr(s,'Left')==500 and prompt(s).Enabled==true,'the pedestal works: 500 left, the prompt on')
 local p=G.player(s,1101,'Owner');local ok=s.Svc:Claim(p)
 check(ok==true and voidPacks(s,p)==1 and attr(s,'Left')==499,'a claim works (and the profile flag is set in memory)')
 check(next(b.Data)==nil and b.Calls.Update==0 and b.Calls.Writes==0,'nothing is written to any DataStore')
 local q=G.player(s,1102,'Second');s.Svc:Claim(q);local again=s.Svc:Claim(p)
 check(attr(s,'Left')==498 and again==false,'the counter counts and a second claim is refused')
 s.Svc:Step();s.Svc:Step();check(warnCount()-w0==1,'(still just one warn)')
 s.Store:UseMemory('again');s.Store:UseMemory('and again');check(warnCount()-w0==1,'(asking for the fallback again does not warn again)')
 -- with API access: its own store, not the live key
 local b2=G.backend();local s2=new(b2,nil,{Studio=true,Name='T'});local r=G.player(s2,1103,'Tester');s2.Svc:Claim(r)
 check(s2.Store.Mode=='DataStore'and b2.Data[STUDIO_KEY]~=nil and b2.Data[KEY]==nil,'Studio with API access uses VoidGiveaway152_Studio, never the live VoidGiveaway152 key')
 local b3=G.backend();local s3=new(b3,nil,{Studio=false,Name='L'});local t=G.player(s3,1104,'Live');s3.Svc:Claim(t)
 check(b3.Data[KEY]~=nil and b3.Data[STUDIO_KEY]==nil,'a live server uses VoidGiveaway152 / Claims')
 -- Studio edits write the Studio store only; a live server cannot edit at all
 local ok4,why4=s3.Store:Edit(function(v)return v end);check(ok4==false,'a live store refuses every edit (Studio only)')
end

-- 12. The owner commands ------------------------------------------------------------------------------------------------------------------------------------------
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 local s=new(b,bus,{Studio=true,Name='O'});local p=G.player(s,1201,'Owner');local Cmd=G.Service.Command
 local ok,text=Cmd(nil,p,{})
 check(ok==true and text:find('0 claimed',1,true)and text:find('500 / 500 LEFT',1,true)and text:find('not claimed',1,true),'voidgift: count, left and your state (not claimed)')
 check(text:find('Studio DataStore',1,true)and text:find('VoidGiveaway152_Studio',1,true),'... and which store (the Studio test store)')
 s.Svc:Claim(p);ok,text=Cmd(nil,p,{})
 check(text:find('1 claimed',1,true)and text:find('499 / 500 LEFT',1,true)and text:find('CLAIMED',1,true)and text:find('profile flag: yes',1,true),'after a claim: 1 claimed, 499 left, CLAIMED, flag yes')
 ok,text=Cmd(nil,p,{'reset','me'})
 check(ok==true and text:find('500 / 500 LEFT',1,true),'voidgift reset me: cleared ('..tostring(text)..')')
 check(s.Data:GetPremium(p).VoidGift152==nil and stored(b,STUDIO_KEY).Count==0 and stored(b,STUDIO_KEY).Users['1201']==nil and p:GetAttribute('VoidGift152')=='Open'and attr(s,'Left')==500,'your flag and your place in the list are gone, the count is back to 0, the sign says 500')
 local again=s.Svc:Claim(p);check(again==true and voidPacks(s,p)==2,'and you can claim again (the first pack stayed in the Bag: the test grants a second)')
 ok,text=Cmd(nil,p,{'left','3'})
 check(ok==true and attr(s,'Left')==3 and stored(b,STUDIO_KEY).Count==497,'voidgift left 3: the pedestal shows 3 / 500 left (Count 497)')
 check(text:find('3 / 500 LEFT',1,true)~=nil,'... and says so')
 local q=G.player(s,1202,'Q');local r=G.player(s,1203,'R');local t=G.player(s,1204,'T');local u=G.player(s,1205,'U')
 s.Svc:Claim(q);s.Svc:Claim(r);check(attr(s,'Left')==1,'it counts down from there')
 s.Svc:Claim(t);check(attr(s,'Left')==0 and attr(s,'State')=='Empty'and prompt(s).Enabled==false,'0 left: Empty, prompt off')
 check(s.Svc:Claim(u)==false and voidPacks(s,u)==0,'and the next one is refused')
 ok,text=Cmd(nil,p,{'left','500'});check(ok==true and attr(s,'Left')<=499 and attr(s,'Left')>=490 and attr(s,'State')=='Open'and prompt(s).Enabled==true,'voidgift left 500 reopens it in Studio (players already listed keep their places: '..tostring(attr(s,'Left'))..' left)')
 check(Cmd(nil,p,{'left','501'})==false and Cmd(nil,p,{'left','-1'})==false and Cmd(nil,p,{'left','x'})==false and Cmd(nil,p,{'left'})==false and Cmd(nil,p,{'left','1.5'})==false,'left needs a whole number 0-500')
 check(Cmd(nil,p,{'reset'})==false and Cmd(nil,p,{'reset','all'})==false and Cmd(nil,p,{'bogus'})==false,'reset needs "me"; unknown words are refused')
 -- a LIVE server: status works, the edits are refused and change nothing
 local b2=G.backend();seedStore(b2,40,filler(1,40));local live=new(b2,nil,{Studio=false,Name='Live'});local o=G.player(live,1301,'Owner Live')
 ok,text=Cmd(nil,o,{});check(ok==true and text:find('40 claimed',1,true)and text:find('LIVE',1,true)and text:find('Studio-only tools are off',1,true),'live: status works, says LIVE')
 local before=stored(b2).Count
 local okr,tr=Cmd(nil,o,{'reset','me'});local okl,tl=Cmd(nil,o,{'left','0'})
 check(okr==false and okl==false and tr:find('^voidgift reset works in Studio only')and tl:find('^voidgift left works in Studio only'),'live: reset me and left are refused by the service itself ("works in Studio only")')
 check(stored(b2).Count==before and b2.Calls.Writes==0 and attr(live,'Left')==460,'live data was not touched')
 -- every owner flow goes through the real dispatcher table too
 local Targets=H.server('OwnerCommandTargets82');check(Targets.IsGlobal('voidgift reset me')and Targets.IsGlobal('/test voidgift left 3'),'voidgift is a server-wide command (no @name)')
end

-- 13. Guards --------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local b=G.backend();local s=new(b,nil)
 local loading=H.player(1401,'Loading');local ok,why=s.Svc:Claim(loading)
 check(not ok and why=='loading'and b.Calls.Update==0,'data not loaded: refused, nothing reserved')
 local nosave=G.player(s,1402,'NoSave',{CanSave=false});ok,why=s.Svc:Claim(nosave)
 check(not ok and why=='cannotsave'and b.Calls.Update==0 and s.Data:voidPacks(nosave)==0,'a live player whose data cannot save: refused, nothing reserved (a pack that cannot be saved would be lost)')
 local studio=new(G.backend(),nil,{Studio=true,Memory=true,Name='ST'});local t=G.player(studio,1403,'StudioNoSave',{CanSave=false})
 check(studio.Svc:Claim(t)==true,'in Studio a player who cannot save may still test it')
 local far=G.player(s,1404,'Far',{Dist=200});ok,why=s.Svc:Claim(far);check(not ok and why=='far'and b.Calls.Update==0,'not at the pedestal: refused, nothing reserved')
 local nochar=G.player(s,1405,'NoBody',{Stand=false});ok,why=s.Svc:Claim(nochar);check(not ok and why=='far','no character: refused')
 -- the prompt calls Claim
 local pp=G.player(s,1406,'Presser');prompt(s).Triggered:Fire(pp);check(voidPacks(s,pp)==1,'the pedestal\'s prompt (Triggered) makes the claim')
 check(prompt(s).ActionText=='Claim FREE Void Pack'and prompt(s).MaxActivationDistance>=10,'the prompt says "Claim FREE Void Pack"')
 -- busy: a second press while the first waits for the store
 local b2=G.backend();local s2=new(b2,nil);local q=G.player(s2,1407,'Double')
 local inner
 b2.Race=function()inner={s2.Svc:Claim(q)};check(q:GetAttribute('VoidGift152')=='Busy','while the claim waits the player is Busy')end
 s2.Svc:Claim(q);check(inner and inner[1]==false and inner[2]=='busy'and voidPacks(s2,q)==1,'a second press while the first waits: refused (busy), one pack')
 -- rate limit: a flood of presses is cut off
 local fl=G.player(s2,1408,'Flood');local refused=0
 for _=1,30 do local o2,w2=s2.Svc:Claim(fl);if w2=='rate'then refused+=1 end end
 check(refused>0,'a flood of presses is rate limited (SecurityGate)')
 -- leaving clears the player
 local lv=G.player(s2,1409,'Leaver');s2.Svc:Step();check(lv:GetAttribute('VoidGift152')=='Open','a loaded player is Open after the step')
 G.leave(lv);check(s2.Svc.Ready[lv]==nil and s2.Svc.Busy[lv]==nil,'a player who leaves is forgotten')
 -- the state of a loaded player shows after the first step (Claimed for a flagged profile)
 local fl2=G.player(s2,1410,'Flagged',{Flag=true});check(fl2:GetAttribute('VoidGift152')==nil,'before the step nothing is set');s2.Svc:Step();check(fl2:GetAttribute('VoidGift152')=='Claimed','after it a flagged profile is Claimed')
 -- teardown
 s2.Svc:Destroy();check(s2.Svc.Model==nil and G.Service.Current~=s2.Svc,'Destroy removes the pedestal')
end

print(string.format('giveaway server: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
