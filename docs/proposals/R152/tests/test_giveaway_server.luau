--!nocheck
-- R152 Void Pack giveaway, the server: VoidGiveawayRules152 / VoidGiveawayStore152 / VoidGiveaway152 on the Roblox mock with a DataStore mock that is a real compare-and-set (two
-- "servers" share one backend and one MessagingService bus), a fake PlayerDataService and a fake clock. Covers:
--  1. the rule (Reserve) and the numbers;  2. a claim: ONE real Void Pack (not TestGrant), count + 1, the profile flag, the save, the notice, the stored value;
--  3. a second claim refused;  4. two servers racing at 499: only one gets the last pack;  5. at 500 every claim refused, prompt off, "ALL CLAIMED", for ever;
--  6. a full Bag: nothing reserved;  7. an interrupted grant: given again once, never twice;  8. a DataStore failure: no pack, retries with backoff, then "try again";
--  9. messaging: another server's claim lowers the number here;  10. polling (45-60 s, backoff, stops at the cap);  11. the Studio fallback (own store, in-memory counter, one warn);
--  12. the owner commands (voidgift, reset me, left N: Studio only);  13. guards (data, save, distance, busy, rate, leaving);
--  14. review fixes: the pack is GiftLocked, MinAccountAgeDays (0 = off), claims honour the store's backoff and a 10 s cooldown, the loop's retries tell once and back off.
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
 check(first.Notes:last(firstP).Text:find('gone',1,true)~=nil,'round '..round..': the loser is told they are all claimed')
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
 check(s2.Notes:last(q).Text:lower():find('saved for you',1,true)~=nil,'"your Void Pack is reserved! Make room"')
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
 s3.Data.ThrowAdd=false;s3.Clock.advance(6);s3.Svc:Step() -- (the loop waits 5 s after a pack could not be added)
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
 b.Calls.Update=0;s.Clock.advance(61) -- (the store's backoff after the failures above has run out)
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
 check(prompt(s).ActionText=='Grab your FREE Void Pack'and prompt(s).MaxActivationDistance>=10,'the prompt says "Grab your FREE Void Pack"')
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

-- 14. Review fixes ------------------------------------------------------------------------------------------------------------------------------------------------
local function said(s,p,needle)local n=0;for _,x in ipairs(s.Notes.Log)do if x.P==p and x.Text:find(needle,1,true)then n+=1 end end;return n end
-- A1: the pack is GiftLocked (FruitGiftService refuses it; the real record round trip is in test_giveaway_real); MinAccountAgeDays = 0 (off) by default
do
 local b=G.backend();local s=new(b,nil);local p=G.player(s,1501,'Alt')
 local ok,record=s.Svc:Claim(p)
 check(ok==true and record.GiftLocked==true,'A1: the giveaway pack is a GiftLocked record (a free pack can\'t be gifted)')
 check(Rules.MinAccountAgeDays==0,'A1: MinAccountAgeDays is 0 (off: the owner decides)')
 local q=G.player(s,1502,'Brand new');q.AccountAge=0;check(s.Svc:Claim(q)==true,'A1: with the rule off a day-0 account can claim')
 -- the rule on: a young account is refused with a friendly line, nothing reserved, no request
 Rules.MinAccountAgeDays=7
 local young=G.player(s,1503,'Young');young.AccountAge=3;local before=b.Calls.Update
 local oky,why=s.Svc:Claim(young)
 check(oky==false and why=='young'and b.Calls.Update==before and s.Data:voidPacks(young)==0,'A1: MinAccountAgeDays 7: a 3-day-old account is refused, nothing reserved, no store request')
 local n=s.Notes:last(young);check(n and n.Text:find('7 days',1,true)and n.Text:find('4 day',1,true)and n.Kind=='Denied','A1: ... with a friendly line that says how long to wait ("'..tostring(n and n.Text)..'")')
 check(young:GetAttribute('VoidGift152')~='Claimed'and not stored(b).Users['1503'],'A1: ... not Claimed, not in the shared list')
 local unknown=G.player(s,1504,'Unknown');check(s.Svc:Claim(unknown)==false,'A1: an account whose age is unknown is refused while the rule is on')
 local seven=G.player(s,1505,'Seven');seven.AccountAge=7;check(s.Svc:Claim(seven)==true and s.Data:voidPacks(seven)==1,'A1: a 7-day-old account may claim')
 -- a player already in the shared list (reserved before the rule) is owed their pack whatever the rule says
 b.Data[KEY].Users['1506']=1700000000;b.Data[KEY].Count+=1;s.Svc:Poll()
 local owed=G.player(s,1506,'Owed');owed.AccountAge=1;s.Svc:Step()
 check(s.Data:voidPacks(owed)==1,'A1: a player reserved earlier is still given their pack when the rule is turned on')
 Rules.MinAccountAgeDays=0
end

-- A2: claims honour the store's backoff and a per-player cooldown after a store failure
do
 local b=G.backend();local s=new(b,nil);local p=G.player(s,1601,'First')
 b.Fail=function(kind)if kind=='Update'then return '429: DataStore request was throttled'end end
 local ok,why=s.Svc:Claim(p);local used=b.Calls.Update
 check(ok==false and why=='store'and used==4,'A2: the first claim tries the store (4 tries) and fails')
 check(s.Notes:last(p).Text:find('Try again in 40 s',1,true)~=nil,'A2: the failed player is told "try again in 40 s" ('..s.Notes:last(p).Text..')')
 -- 20 more players press over the next 30 s while the backoff runs: no UpdateAsync at all
 local refused,told=0,0
 for i=1,20 do
  s.Clock.advance(1.5);local q=G.player(s,1610+i,'P'..i);local _,whyq=s.Svc:Claim(q)
  if whyq=='wait'then refused+=1 end
  local t=s.Notes:last(q);if t and t.Text:find('Try again in',1,true)and t.Text:find(' s.',1,true)then told+=1 end
 end
 check(b.Calls.Update==used and refused==20,'A2: 20 claims during the backoff are refused at once, 0 more UpdateAsync calls ('..(b.Calls.Update-used)..' made)')
 check(told==20,'A2: ... each told "try again in N s"')
 -- the store's own gate: Reserve called directly during the backoff makes no request
 local before=b.Calls.Update;local okr,reason,secs=s.Store:Reserve(1650)
 check(okr==false and reason=='backoff'and type(secs)=='number'and secs>=1 and b.Calls.Update==before,'A2: Store:Reserve refuses at once while NextTryAt is in the future (backoff, '..tostring(secs)..' s left)')
 -- once the backoff has run out the store is asked again (and a recovered store works)
 b.Fail=nil;s.Clock.advance(60)
 local r=G.player(s,1651,'After');check(s.Svc:Claim(r)==true and s.Data:voidPacks(r)==1,'A2: after the backoff the store is asked again')
 -- the per-player cooldown: after a store failure the same player waits ~10 s, even when the store is back at once (a good read clears the backoff)
 local c=G.player(s,1652,'Cool');b.Fail=function(kind)if kind=='Update'then return 'HTTP 500'end end
 local okC,whyC=s.Svc:Claim(c);check(okC==false and whyC=='store','A2: a failing store: refused')
 b.Fail=nil;s.Store:_ok()
 local u=b.Calls.Update;local again,whyAgain=s.Svc:Claim(c)
 check(again==false and whyAgain=='wait'and b.Calls.Update==u,'A2: the same player pressing again at once is held back by their cooldown (no request)')
 local other=G.player(s,1653,'Other');check(s.Svc:Claim(other)==true,'A2: another player is not held back')
 s.Clock.advance(9);check(s.Svc:Claim(c)==false,'A2: 9 s later the cooldown still holds')
 s.Clock.advance(2);check(s.Svc:Claim(c)==true and s.Data:voidPacks(c)==1,'A2: after ~10 s the player may claim')
 check(G.Service.StoreCooldown==10,'A2: the cooldown is 10 s')
 -- memory mode (Studio without API access) has no backoff to honour
 local m=new(G.backend(),nil,{Studio=true,Memory=true,Name='M'});local mp=G.player(m,1660,'Mem');check(m.Svc:Claim(mp)==true,'A2: the in-memory counter is never held back')
end

-- A3: the loop's retries of a pack the player is owed: told once, backing off after an 'add' failure
do
 local b=G.backend();seedStore(b,1,{1701});local s=new(b,nil);local p=G.player(s,1701,'Owed')
 s.Data.ThrowAdd=true
 local adds0=s.Data.AddCalls
 for _=1,30 do s.Svc:Step();s.Clock.advance(2)end -- 60 s of the 2 s loop
 check(said(s,p,'add the pack')==1,'A3: 30 loop steps of a pack that cannot be added: the player is told once ('..said(s,p,'add the pack')..')')
 local tries=s.Data.AddCalls-adds0
 check(tries>=3 and tries<=6,'A3: ... and the loop backed off (5, 10, 20 .. s) instead of trying every 2 s: '..tries..' tries in 60 s (was 30)')
 check(s.Data:voidPacks(p)==0 and stored(b).Users['1701']~=nil,'A3: nothing was given, the reservation stands')
 -- a press of the player's own always gets an answer and tries at once
 local n0=said(s,p,'add the pack');local okp,whyp=s.Svc:Claim(p)
 check(okp==false and whyp=='add'and said(s,p,'add the pack')==n0+1,'A3: the player\'s own press tries at once and says so')
 -- it works again: the next try after the backoff gives the pack, once, and the retry state is forgotten
 s.Data.ThrowAdd=false
 for _=1,40 do s.Svc:Step();s.Clock.advance(2)end
 check(s.Data:voidPacks(p)==1 and s.Data:GetPremium(p).VoidGift152==true,'A3: when AddChest works again the next retry gives the pack')
 check(s.Svc.Failed[p]==nil,'A3: ... and the failure record is cleared')
 s.Svc:Step();check(s.Data:voidPacks(p)==1,'A3: never twice')
 -- _run is told whether it is the loop (auto): the loop's failure is quiet after the first line, a press is not
 local b2=G.backend();seedStore(b2,1,{1702});local s2=new(b2,nil);local q=G.player(s2,1702,'Direct');s2.Data.ThrowAdd=true
 s2.Svc:_run(q,true,true);s2.Svc:_run(q,true,true);s2.Svc:_run(q,true,true)
 check(said(s2,q,'add the pack')==1,'A3: _run(player, owed, auto) tells an auto retry once')
 s2.Svc:_run(q,true,false);check(said(s2,q,'add the pack')==2,'A3: ... and a non-auto run always tells')
 -- an error thrown out of a claim is handled the same way (once, then the backoff)
 local b3=G.backend();seedStore(b3,1,{1703});local s3=new(b3,nil);local r=G.player(s3,1703,'Throws')
 s3.Svc._run=function()error('boom')end
 for _=1,10 do s3.Svc:Step();s3.Clock.advance(2)end
 check(said(s3,r,'claim it')==1,'A3: a claim that throws is announced once by the loop ('..said(s3,r,'claim it')..')')
end

-- 15. R158c (owner: "for the void pack there isn't a 20 minute lock anymore and requirement is just finishing the tutorial"): the tutorial rule replaces R157's play time rule -------------
-- (every player the harness loads has finished the tutorial unless a test says Tutorial=false, or 'unset' = the attribute was never published; Played = the R157 counter, which no rule uses now)
local REFUSAL='finish the tutorial to get your free void pack!'
local function field(s,p)return s.Data:GetPremium(p)[Rules.PlayField]end
local function wordsOk(t)local padded=' '..t:lower()..' ';return padded:find('%f[%a]ur%f[%A]')==nil and padded:find('%f[%a]u%f[%A]')==nil end
local function tick(s,seconds,every)every=every or 2;for _=1,math.floor(seconds/every+.5)do s.Clock.advance(every);s.Svc:Step()end end
-- A. the rule and the words
do
 check(Rules.MinPlaySeconds==nil and Rules.PlayRefusal==nil and Rules.PlayHint==nil and Rules.PlayLoading==nil and Rules.Attr.PlayLeft==nil,'R158c A: the 20 minute rule is gone from the rules (no minimum, no play-time texts, no VoidPlayLeft157 attribute)')
 check(Rules.PlayWait==nil and Rules.PlayMinutes==nil and Rules.PlayShown==nil and Rules.PlayRefusalText==nil and Rules.PlayHintText==nil,'R158c A: ... and no wait / minutes helpers either')
 check(Rules.TutorialAttr=='TutorialDone','R158c A: the rule reads the player attribute TutorialDone (the one TutorialProgress sets)')
 check(Rules.TutorialRefusal==REFUSAL,'R158c A: the refusal reads "finish the tutorial to get your free void pack!"')
 check(Rules.TutorialHint=='finish the tutorial to claim','R158c A: the sign\'s line reads "finish the tutorial to claim"')
 check(Rules.TutorialDone(true)==true and Rules.TutorialDone(false)==false and Rules.TutorialDone(nil)==false and Rules.TutorialDone(1)==false and Rules.TutorialDone('true')==false and Rules.TutorialDone({})==false,'R158c A: done = the attribute is exactly true (the way TrackHoleService / PremiumService / FruitGiftService read it); false, missing, 1, "true": not done')
 check(Rules.PlayField=='PlaySeconds157'and Rules.PlayCap==3*3600,'R158c A: the play-time counter is kept: the optional Premium field PlaySeconds157, up to 3 h (saved data stays compatible)')
 check(Rules.CleanPlayed(nil)==0 and Rules.CleanPlayed('9')==0 and Rules.CleanPlayed(0/0)==0 and Rules.CleanPlayed(-5)==0 and Rules.CleanPlayed({})==0 and Rules.CleanPlayed(true)==0,'R158c A: no field (an old save), a string, NaN, a negative number, a table: all read as 0 seconds played')
 check(Rules.CleanPlayed(61.9)==61 and Rules.CleanPlayed(1e12)==Rules.PlayCap and Rules.CleanPlayed(math.huge)==Rules.PlayCap and Rules.CleanPlayed(-math.huge)==0,'R158c A: whole seconds, never above the cap')
 for _,t in ipairs({Rules.TutorialRefusal,Rules.TutorialHint})do
  check(wordsOk(t)and not t:lower():find('cla[u]de')and not t:lower():find('op[u]s')and not t:lower():find('sonn[e]t')and not t:lower():find('haik[u]'),'R158c A: the new text "'..t..'" has no "u" / "ur" and no model name')
 end
 check(Rules.TutorialRefusal:find('your free void pack',1,true)~=nil,'R158c A: ... and says "your" in full')
end
-- B. tutorial NOT finished: refused, and NOTHING happens (no reservation, no store request, no state change), whatever the play time
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end);local s=new(b,bus)
 local p=G.player(s,1801,'Fresh',{Tutorial=false});s.Svc:Step() -- (set up: the player is Open)
 local g0,u0,w0,t0=b.Calls.Get,b.Calls.Update,b.Calls.Writes,b.Calls.Transforms;local dirty0,saves0,syncs0=s.Data.Dirty[p]or 0,s.Data.Saves[p]or 0,s.Chests.Syncs
 local ok,why=s.Svc:Claim(p)
 check(ok==false and why=='tutorial','R158c B: the tutorial is not finished: the claim is refused (tutorial)')
 local n=s.Notes:last(p);check(n and n.Text==REFUSAL and n.Kind=='Denied','R158c B: ... "finish the tutorial to get your free void pack!" (a refusal click)')
 check(b.Calls.Get==g0 and b.Calls.Update==u0 and b.Calls.Writes==w0 and b.Calls.Transforms==t0 and b.Data[KEY]==nil and next(b.Data)==nil,'R158c B: no store request of any kind, nothing written (no reservation)')
 check(voidPacks(s,p)==0 and s.Data.AddCalls==0 and s.Data:GetPremium(p).VoidGift152==nil and s.Chests.Syncs==syncs0,'R158c B: no pack, no flag, no hotbar sync')
 check((s.Data.Dirty[p]or 0)==dirty0 and(s.Data.Saves[p]or 0)==saves0,'R158c B: nothing marked dirty, no save queued')
 check(s.Svc.Reserved[p.UserId]==nil and s.Svc.Busy[p]==nil and s.Svc.Cool[p]==nil and s.Svc.Failed[p]==nil and s.Svc.Told[p]==nil,'R158c B: no reservation here, not busy, no cooldown, nothing remembered')
 check(p:GetAttribute('VoidGift152')=='Open'and attr(s,'Count')==0 and attr(s,'Left')==500 and prompt(s).Enabled==true,'R158c B: the player is still Open, the pedestal still says 500 left and its prompt stays on for everyone')
 -- the prompt makes the same claim
 local q=G.player(s,1802,'Presser',{Tutorial=false});prompt(s).Triggered:Fire(q)
 check(voidPacks(s,q)==0 and s.Notes:last(q).Text==REFUSAL and b.Calls.Update==u0,'R158c B: the prompt (Triggered) is refused the same way')
 -- a lot of play time does not open it (3 hours played, tutorial not finished), and none is the same
 local long=G.player(s,1803,'Long play',{Tutorial=false,Played=Rules.PlayCap});local okL,whyL=s.Svc:Claim(long)
 check(okL==false and whyL=='tutorial'and s.Notes:last(long).Text==REFUSAL and voidPacks(s,long)==0,'R158c B: 3 hours of play time and no finished tutorial: refused (play time never opens it)')
 local none=G.player(s,1804,'No time',{Tutorial=false,Played=false});local okN,whyN=s.Svc:Claim(none)
 check(okN==false and whyN=='tutorial'and s.Notes:last(none).Text==REFUSAL,'R158c B: an old save with no play time and no finished tutorial: the same refusal')
 -- an attribute that was never published is "not done" (the same test as the other systems: exactly true)
 local unset=G.player(s,1805,'Unset',{Tutorial='unset'});check(unset:GetAttribute('TutorialDone')==nil,'(no attribute)')
 local okU,whyU=s.Svc:Claim(unset);check(okU==false and whyU=='tutorial'and s.Notes:last(unset).Text==REFUSAL,'R158c B: no TutorialDone attribute at all: not finished, refused')
 check(b.Calls.Update==u0 and next(b.Data)==nil and attr(s,'Count')==0,'R158c B: five refusals in all, still no store request and no claim counted')
 -- far from the pedestal and not finished: the tutorial refusal comes first (as the old play-time refusal did): the player is told
 local far=G.player(s,1806,'Far',{Tutorial=false,Dist=200});local okF,whyF=s.Svc:Claim(far);check(okF==false and whyF=='tutorial'and s.Notes:last(far).Text==REFUSAL,'R158c B: far away and not finished: still told to finish the tutorial')
 -- the loop (Step) never gives a pack to a player who is not owed one and has not finished the tutorial
 s.Svc:Step();s.Svc:Step();check(voidPacks(s,p)==0 and voidPacks(s,q)==0 and next(b.Data)==nil,'R158c B: the server loop gives nothing to them')
end
-- C. tutorial finished (or skipped: the same attribute): the claim goes through; play time never refuses
do
 local b=G.backend();local s=new(b,nil)
 for i,row in ipairs({{'no play time field',false},{'0 s played',0},{'1 s played',1},{'19 min 59 s played',1199},{'20 min played',1200},{'3 h played',Rules.PlayCap}})do
  local id=1900+i;local p=G.player(s,id,'T'..i,{Played=row[2]});s.Svc:Step()
  local ok,rec=s.Svc:Claim(p)
  check(ok==true and rec.BagVariant=='EclipseReliquary'and voidPacks(s,p)==1 and stored(b).Users[tostring(id)]~=nil and s.Data:GetPremium(p).VoidGift152==true and said(s,p,'finish the tutorial')==0,'R158c C: finished tutorial, '..row[1]..': the claim goes through (one Void Pack, reserved, flag set, no "finish the tutorial")')
 end
 check(stored(b).Count==6 and attr(s,'Count')==6,'R158c C: six players, six packs, Count 6')
 -- play time is never a reason ("play N more min" is nowhere)
 local anyPlay=false;for _,x in ipairs(s.Notes.Log)do if x.Text:lower():find('more min',1,true)or x.Text:lower():find('play ',1,true)then anyPlay=true end end
 check(not anyPlay,'R158c C: nobody was ever told "play N more min"')
 -- live: the attribute changes while the player stands there. not finished -> finished -> claim
 local late=G.player(s,1950,'Late',{Tutorial=false});s.Svc:Step()
 check(s.Svc:Claim(late)==false and voidPacks(s,late)==0 and stored(b).Users['1950']==nil,'R158c C: not finished: refused')
 late:SetAttribute('TutorialDone',true)
 local ok2,rec2=s.Svc:Claim(late);check(ok2==true and rec2.BagVariant=='EclipseReliquary'and voidPacks(s,late)==1,'R158c C: the tutorial gets finished (or skipped): the very next claim goes through')
 -- the server reads the attribute fresh at every claim: false again (nothing sets it any more, but a stale yes is never kept) -> refused, true -> allowed
 local again=G.player(s,1951,'Flip');s.Svc:Step();again:SetAttribute('TutorialDone',false)
 local ok3,why3=s.Svc:Claim(again);check(ok3==false and why3=='tutorial'and voidPacks(s,again)==0,'R158c C: TutorialDone false again: refused (the answer is never remembered)')
 again:SetAttribute('TutorialDone',true);check(s.Svc:Claim(again)==true and voidPacks(s,again)==1,'R158c C: ... and allowed once it is true')
 -- the account-age rule and the tutorial rule stand side by side (the tutorial rule is checked after it, before any reservation)
 Rules.MinAccountAgeDays=7
 local young=G.player(s,1960,'YoungNew',{Tutorial=false});young.AccountAge=1;local okY,whyY=s.Svc:Claim(young)
 check(okY==false and whyY=='young','R158c C: with both rules on, a young account that has not finished the tutorial is told about the account age first (the order: age, then tutorial)')
 Rules.MinAccountAgeDays=0
 check(s.Svc:Claim(young)==false and s.Notes:last(young).Text==REFUSAL,'R158c C: with the age rule off it is the tutorial rule')
end
-- D. a player who is already owed a pack (reserved before) is NOT held up by the rule
do
 -- in the shared list, no flag, tutorial not finished: the press gives the pack, and the server gives it by itself
 local b=G.backend();seedStore(b,3,{2001,2002,2003});local s=new(b,nil)
 local a=G.player(s,2001,'Owed press',{Tutorial=false});local w0=b.Calls.Writes
 local ok=s.Svc:Claim(a);check(ok==true and voidPacks(s,a)==1 and s.Data:GetPremium(a).VoidGift152==true,'R158c D: reserved earlier, tutorial not finished: the press gives the pack')
 check(b.Calls.Writes==w0 and stored(b).Count==3 and said(s,a,'finish the tutorial')==0,'R158c D: the same reservation (nothing written), and no "finish the tutorial" line')
 local c=G.player(s,2002,'Owed loop',{Tutorial=false});s.Svc:Step()
 check(voidPacks(s,c)==1 and said(s,c,'finish the tutorial')==0,'R158c D: reserved earlier, tutorial not finished: the server gives the pack by itself')
 local c2=G.player(s,2003,'Owed unset',{Tutorial='unset'});s.Svc:Step()
 check(voidPacks(s,c2)==1,'R158c D: ... also with no TutorialDone attribute at all')
 -- reserved on THIS server (the grant failed), then the attribute is not true: still given
 local b2=G.backend();local s2=new(b2,nil);local r=G.player(s2,2010,'Crash');s2.Data.ThrowAdd=true
 local ok2,why2=s2.Svc:Claim(r);check(ok2==false and why2=='add'and s2.Svc.Reserved[2010]==true,'(reserved, the pack could not be added)')
 r:SetAttribute('TutorialDone',false);s2.Data.ThrowAdd=false;s2.Clock.advance(6);s2.Svc:Step()
 check(voidPacks(s2,r)==1,'R158c D: reserved here, TutorialDone false since: the pack is still given')
 -- and a player who is NOT owed, with an unfinished tutorial, is refused (it is the reservation that decides)
 local d=G.player(s,2020,'Not owed',{Tutorial=false});check(s.Svc:Claim(d)==false and voidPacks(s,d)==0,'R158c D: a player who is not in the list is still refused')
 -- at 0 left an owed player is still given it (as before)
 local b3=G.backend();seedStore(b3,500,filler(2100,499));b3.Data[KEY].Users['2099']=1;b3.Data[KEY].Count=500
 local s3=new(b3,nil);local z=G.player(s3,2099,'Owed at zero',{Tutorial=false});s3.Svc:Step()
 check(voidPacks(s3,z)==1,'R158c D: owed at 0 left and tutorial not finished: given')
end
-- D2. ONE pack per player (owner: "it is still one Void Pack per player"): unchanged by the new rule
do
 local b=G.backend();local s=new(b,nil);local p=G.player(s,2300,'Once');s.Svc:Step()
 local ok,rec=s.Svc:Claim(p);check(ok==true and rec and voidPacks(s,p)==1 and attr(s,'Count')==1 and p:GetAttribute('VoidGift152')=='Claimed','R158c D2: finished the tutorial and claimed: one pack, Count 1, CLAIMED')
 local u0,w0,g0=b.Calls.Update,b.Calls.Writes,b.Calls.Get
 local ok2,why2=s.Svc:Claim(p)
 check(ok2==false and why2=='claimed'and voidPacks(s,p)==1 and attr(s,'Count')==1,'R158c D2: a second claim is refused (claimed): still one pack, Count 1')
 check(s.Notes:last(p).Text:find('already grabbed',1,true)~=nil and said(s,p,'finish the tutorial')==0,'R158c D2: ... it says "already grabbed", never "finish the tutorial"')
 check(b.Calls.Update==u0 and b.Calls.Writes==w0 and b.Calls.Get==g0 and stored(b).Count==1,'R158c D2: ... and the store was not asked')
 prompt(s).Triggered:Fire(p);s.Svc:Step();s.Svc:Step()
 check(voidPacks(s,p)==1 and p:GetAttribute('VoidGift152')=='Claimed','R158c D2: the prompt and the server loop do not give a second pack (the sign stays on CLAIMED)')
 -- TutorialDone false after the claim: the answer is still "claimed", the state stays Claimed, no second pack
 p:SetAttribute('TutorialDone',false);local ok3,why3=s.Svc:Claim(p)
 check(ok3==false and why3=='claimed'and voidPacks(s,p)==1 and p:GetAttribute('VoidGift152')=='Claimed'and s.Notes:last(p).Text:find('already grabbed',1,true)~=nil,'R158c D2: TutorialDone false after claiming: still "claimed", one pack, state Claimed')
 p:SetAttribute('TutorialDone',true);check(s.Svc:Claim(p)==false and voidPacks(s,p)==1 and attr(s,'Count')==1,'R158c D2: and true again gives nothing more')
 -- the global count is as before: another player counts once, the cap rule is untouched
 local q=G.player(s,2301,'Second');s.Svc:Step();check(s.Svc:Claim(q)==true and attr(s,'Count')==2 and attr(s,'Left')==498,'R158c D2: a different player: Count 2, 498 left (the global count is as before)')
end
-- E. the play-time counter (R157, kept; no rule uses it): the server's loop (Step) counts whole seconds into the profile and saves the way other progress is saved
do
 local b=G.backend();local s=new(b,nil);local p=G.player(s,2201,'Counter',{Played=false});local q=G.player(s,2202,'Other',{Played=300})
 check(p:GetAttribute('VoidPlayLeft157')==nil,'R158c E: before the player is set up there is no play-time attribute (and there never is one now)')
 s.Svc:Step()
 check(p:GetAttribute('VoidPlayLeft157')==nil and q:GetAttribute('VoidPlayLeft157')==nil,'R158c E: set up: still no VoidPlayLeft157 attribute (nothing is published for a rule that is gone)')
 check(field(s,p)==nil,'R158c E: nothing is counted at the first look (an old save keeps no field yet)')
 local dirty0,saves0=s.Data.Dirty[p]or 0,s.Data.Saves[p]or 0
 tick(s,60)
 check(field(s,p)==60 and field(s,q)==360,'R158c E: 60 s later: 60 s played (and 360 for the other player), whole seconds')
 check((s.Data.Dirty[p]or 0)-dirty0==2 and(s.Data.Saves[p]or 0)==saves0,'R158c E: marked dirty every 30 s (2 times in 60 s), no save queued yet')
 -- a pause is not play: a look 60 s after the last counts at most 5 s
 s.Clock.advance(60);s.Svc:Step();check(field(s,p)==65,'R158c E: a 60 s gap between two looks (a hitch, a paused Studio) counts at most 5 s ('..tostring(field(s,p))..')')
 -- a fraction of a second is kept until it is a whole one
 local f0=field(s,p);for _=1,3 do s.Clock.advance(.4);s.Svc:Step()end
 check(field(s,p)==f0+1,'R158c E: 3 looks of .4 s: 1 whole second counted, .2 s kept ('..tostring(field(s,p)-f0)..')')
 for _=1,3 do s.Clock.advance(.4);s.Svc:Step()end;check(field(s,p)==f0+2,'R158c E: and counted when it adds up')
 -- not loaded: nothing is counted, nothing is said
 local w0=warnCount();s.Data.Loaded[p]=false;local before=field(s,p);tick(s,20);check(field(s,p)==before,'R158c E: a player whose data is not loaded (leaving, loading) is not counted')
 s.Data.Loaded[p]=true;tick(s,2);check(field(s,p)==before+G.Service.PlayMaxStep and G.Service.PlayMaxStep==5,'R158c E: and counting goes on when it is (the first look after the gap counts at most 5 s)')
 check(warnCount()==w0,'R158c E: no warn on the way')
 -- up to 20 minutes: the save is queued once (the counter is saved, never lost), and nothing about the claim changes
 local saves1=s.Data.Saves[p]or 0
 tick(s,G.Service.PlayMark-field(s,p)-2);check(field(s,p)==1198 and(s.Data.Saves[p]or 0)==saves1,'R158c E: 1198 s: no save queued yet')
 tick(s,2);check(field(s,p)==1200 and(s.Data.Saves[p]or 0)==saves1+1,'R158c E: 1200 s: a save is queued (QueueGardenSave) so the counter is never lost')
 check(s.Svc:Claim(p)==true and voidPacks(s,p)==1,'R158c E: the claim does not care (a finished tutorial is all it needs)')
 -- after that: still counted, up to the cap, marked dirty far less often
 local d1=s.Data.Dirty[p];tick(s,600);check((s.Data.Dirty[p]-d1)<=2 and field(s,p)==1800,'R158c E: after 20 minutes the field is marked dirty every 5 minutes, not every 30 s ('..(s.Data.Dirty[p]-d1)..' in 10 min)')
 tick(s,Rules.PlayCap+600);check(field(s,p)==Rules.PlayCap,'R158c E: counted up to the cap (3 h) and no further')
 local dirtyCap=s.Data.Dirty[p];tick(s,60);check(s.Data.Dirty[p]==dirtyCap and field(s,p)==Rules.PlayCap,'R158c E: at the cap nothing is written any more')
 -- a malformed saved value heals itself; the counter of a player who leaves is forgotten
 local bad=G.player(s,2203,'Bad field',{Played=false});s.Data:GetPremium(bad)[Rules.PlayField]='abc';s.Svc:Step()
 check(s.Svc:_played(bad)==0,'R158c E: a field that is not a number reads as 0')
 tick(s,2);check(field(s,bad)==2,'R158c E: ... and is written over with a number by the next count')
 G.leave(bad);check(s.Svc.PlayAt[bad]==nil and s.Svc.PlayFrac[bad]==nil and s.Svc.PlayUnsaved[bad]==nil,'R158c E: a player who leaves is forgotten (no leftovers)')
end
-- F. "not ready yet" is never an error; the in-memory Studio case
do
 local b=G.backend();local s=new(b,nil);local w0=warnCount()
 local loading=H.player(2301,'Still loading');local ok,why=s.Svc:Claim(loading)
 check(ok==false and why=='loading'and s.Svc:_played(loading)==nil,'R158c F: data not loaded: "loading", no counter (nil)')
 check(s.Notes:last(loading)==nil or(not s.Notes:last(loading).Text:find('tutorial',1,true)and not s.Notes:last(loading).Text:find('play ',1,true)),'R158c F: ... and never told about the tutorial or play time (the data comes first)')
 s.Svc:Step();check(s.Svc.PlayAt[loading]==nil and loading:GetAttribute('VoidPlayLeft157')==nil,'R158c F: a Step does not count or publish for it')
 -- what _played says for each state
 local p=G.player(s,2302,'Unready');local data=s.Data;local rawPremium=data.GetPremium
 data.GetPremium=function()error('premium exploded')end;check(s.Svc:_played(p)==nil,'R158c F: a premium table that throws is "not ready" (nil), not an error')
 data.GetPremium=function()return nil end;check(s.Svc:_played(p)==nil,'R158c F: so is no table at all')
 data.GetPremium=rawPremium;check(s.Svc:_played(p)==0,'R158c F: and a normal profile with no field is 0')
 data.GetPremium=function()error('premium exploded')end;s.Svc:_tickPlay(p,s.Clock.now()+2);data.GetPremium=rawPremium
 check(warnCount()==w0,'R158c F: counting with an unreadable profile throws nothing and warns nothing')
 -- Studio without DataStore access: the counter lives in memory (the profile cannot save); the claim needs the tutorial and nothing else
 local backend=G.backend();local st=new(backend,nil,{Studio=true,Memory=true,Name='ST157'});local w1=warnCount()
 local t=G.player(st,2303,'StudioNoApi',{CanSave=false,Tutorial=false});st.Svc:Step()
 tick(st,60);check(field(st,t)==60 and st.Svc:Claim(t)==false and st.Notes:last(t).Text==REFUSAL,'R158c F: Studio without API access: it counts in memory (60 s), and an unfinished tutorial is refused')
 t:SetAttribute('TutorialDone',true);local okS=st.Svc:Claim(t)
 check(okS==true and st.Data:voidPacks(t)==1 and next(backend.Data)==nil,'R158c F: finished: the claim goes through at once with 1 minute played (nothing is written to a DataStore)')
 check(warnCount()==w1,'R158c F: ... with no warn for any of it ('..(warnCount()-w1)..')')
end
-- G. the owner's tools: voidgift status prints the tutorial and the play time; playtime shows / sets the counter (Studio only); the command is wired and parses
do
 local b=G.backend();local bus=E.bus(function()return 0 end,function()return 0 end)
 local s=new(b,bus,{Studio=true,Name='O157'});local p=G.player(s,2401,'Owner',{Played=false});s.Svc:Step();local Cmd=G.Service.Command;local PT=G.Service.PlaytimeCommand
 local ok,text=Cmd(nil,p,{})
 check(ok==true and text:find('Play time: 0 min 0 s played',1,true)and text:find('the claim does not use it',1,true)and not text:find('needs 20',1,true)and not text:find('to go',1,true)and text:find('Premium.PlaySeconds157',1,true),'R158c G: voidgift status prints the play time as a counter ("'..tostring(text:match('Play time:[^\n]*'))..'")')
 check(text:find('Tutorial: finished',1,true)~=nil,'R158c G: ... and the tutorial line ("'..tostring(text:match('Tutorial:[^\n]*'))..'")')
 local nf=G.player(s,2404,'Unfinished',{Tutorial=false});ok,text=Cmd(nil,nf,{});check(text:find('Tutorial: NOT finished',1,true)and text:find(REFUSAL,1,true),'R158c G: an unfinished tutorial is said so in voidgift ("'..tostring(text:match('Tutorial:[^\n]*'))..'")')
 tick(s,90);ok,text=Cmd(nil,p,{});check(text:find('Play time: 1 min 30 s played',1,true)~=nil,'R158c G: the play time moves with the counting ("'..tostring(text:match('Play time:[^\n]*'))..'")')
 s.Data.CanSave[p]=false;ok,text=Cmd(nil,p,{});check(text:find('cannot save: kept in memory',1,true)~=nil,'R158c G: a profile that cannot save says the time is kept in memory');s.Data.CanSave[p]=true
 -- playtime: show
 ok,text=PT(nil,p,{});check(ok==true and text:find('1 min 30 s played',1,true)~=nil,'R158c G: playtime (no number) shows it')
 -- playtime 12: sets, saves; nothing is published for a claim
 local dirty0,saves0=s.Data.Dirty[p]or 0,s.Data.Saves[p]or 0
 ok,text=PT(nil,p,{'12'})
 check(ok==true and field(s,p)==720 and text:find('12 min 0 s played',1,true)~=nil,'R158c G: playtime 12 sets 720 s ("'..tostring(text)..'")')
 check(p:GetAttribute('VoidPlayLeft157')==nil,'R158c G: ... and publishes no attribute')
 check((s.Data.Dirty[p]or 0)>dirty0 and(s.Data.Saves[p]or 0)==saves0+1,'R158c G: ... saved the usual way (MarkDirty + QueueGardenSave)')
 ok,text=PT(nil,p,{'19.5'});check(ok==true and field(s,p)==1170,'R158c G: playtime 19.5 = 1170 s')
 ok,text=PT(nil,p,{'20'});check(ok==true and field(s,p)==1200,'R158c G: playtime 20 = 1200 s')
 ok,text=PT(nil,p,{'0'});check(ok==true and field(s,p)==0,'R158c G: playtime 0 starts again')
 check(s.Svc:Claim(p)==true and voidPacks(s,p)==1,'R158c G: ... and with 0 minutes played the claim still works (a finished tutorial is all it needs)')
 ok=PT(nil,p,{'180'});check(ok==true and field(s,p)==10800,'R158c G: 180 minutes is the largest (the cap)')
 local f=field(s,p)
 check(PT(nil,p,{'-1'})==false and PT(nil,p,{'x'})==false and PT(nil,p,{'181'})==false and PT(nil,p,{'1','2'})==false and PT(nil,p,{'nan'})==false and PT(nil,p,{'inf'})==false and PT(nil,p,{'1e9'})==false and field(s,p)==f,'R158c G: a negative, a word, more than 180, two numbers, nan / inf: refused, nothing changed')
 check(PT(nil,nf,{'180'})==true and s.Svc:Claim(nf)==false and s.Notes:last(nf).Text==REFUSAL,'R158c G: 180 minutes of play time does not open the claim for an unfinished tutorial')
 -- the whole owner path (StudioTestCommands.Execute: access, @name, the parser, the dispatcher): /test playtime @name <minutes>
 do
  local rawStudio=W.Run.IsStudio;W.Run.IsStudio=function()return true end
  local SC=H.server('StudioTestCommands');local bob=G.player(s,2403,'Bobby',{Played=false});local ctx={Data=s.Data,Config=s.Data.Config}
  local o1,m1=SC.Execute(ctx,p,'/test playtime @Bobby 12')
  check(o1==true and field(s,bob)==720 and m1:find('@Bobby',1,true)and m1:find('12 min 0 s played',1,true),'R158c G: "/test playtime @Bobby 12" sets Bobby to 12 minutes, saved ('..tostring(m1)..')')
  o1,m1=SC.Execute(ctx,p,'/test playtime 7 @Bobby');check(o1==true and field(s,bob)==420,'R158c G: "/test playtime 7 @Bobby" (the usual order) works too')
  o1,m1=SC.Execute(ctx,p,'playtime @Bobby 19.5');check(o1==true and field(s,bob)==1170,'R158c G: ... and so does the F4 box form ("playtime @Bobby 19.5")')
  o1,m1=SC.Execute(ctx,p,'/test playtime @Bobby');check(o1==true and field(s,bob)==1170 and m1:find('19 min 30 s played',1,true),'R158c G: "/test playtime @Bobby" shows it and changes nothing')
  o1,m1=SC.Execute(ctx,p,'/test playtime @Nobody 5');check(o1==false and field(s,bob)==1170,'R158c G: an unknown name is refused')
  o1,m1=SC.Execute(ctx,p,'/test playtime @Bobby soon');check(o1==false and field(s,bob)==1170,'R158c G: a word instead of the minutes is refused')
  o1,m1=SC.Execute(ctx,p,'/test playtime @me 4');check(o1==true and field(s,p)==240,'R158c G: "@me" is the owner')
  W.Run.IsStudio=rawStudio
 end
 -- a LIVE server: shows, refuses to set, changes nothing
 local live=new(G.backend(),nil,{Studio=false,Name='L157'});local o=G.player(live,2402,'Live owner',{Played=300})
 local okL,tL=G.Service.PlaytimeCommand(nil,o,{});check(okL==true and tL:find('5 min 0 s played',1,true),'R158c G: live: playtime shows the time')
 local d0,s0=live.Data.Dirty[o]or 0,live.Data.Saves[o]or 0
 local okS,tS=G.Service.PlaytimeCommand(nil,o,{'30'});check(okS==false and tS:find('works in Studio only',1,true)and field(live,o)==300 and(live.Data.Dirty[o]or 0)==d0 and(live.Data.Saves[o]or 0)==s0,'R158c G: live: playtime 30 is refused ("works in Studio only"), nothing changed, nothing saved')
 local okV,tV=G.Service.Command(nil,o,{});check(okV==true and tV:find('Play time: 5 min 0 s played',1,true),'R158c G: live: voidgift status still prints it')
 -- wiring: the owner's dispatcher, the parser, the help and the docs
 local U=H.server('OwnerUpdateCommands82');check(U.Actions.playtime==true,'R158c G: playtime is an owner action (OwnerUpdateCommands82.Actions)')
 local Targets=H.server('OwnerCommandTargets82')
 local b1,t1=Targets.Split('/test playtime @Bob 12');local b2,t2=Targets.Split('playtime @Bob 12');local b3,t3=Targets.Split('/test playtime 12 @Bob');local b4,t4=Targets.Split('playtime @me')
 check(b1=='/test playtime 12'and t1=='Bob'and b2=='playtime 12'and t2=='Bob'and b3=='/test playtime 12'and t3=='Bob'and b4=='playtime'and t4=='me','R158c G: "playtime @name 12" and "playtime 12 @name" both parse to the minutes and the target')
 local b5,t5,w5=Targets.Split('cash @Bob 5');check(b5==nil and w5:find('at the end',1,true),'R158c G: every other command still needs the name at the end')
 check(not Targets.IsGlobal('playtime 12')and not Targets.IsGlobal('/test playtime')and Targets.IsGlobal('voidgift'),'R158c G: playtime is a per-player command (takes @name); voidgift stays server-wide')
 local Help=W.module('StudioTestHelp');local helped,gift=false,false
 for _,row in ipairs(Help)do
  if row[1]:find('/test playtime',1,true)then helped=true;check(wordsOk(row[2])and not row[2]:find('after 20 minutes',1,true),'R158c G: help row "'..row[1]..'" has no "u" / "ur" and no "after 20 minutes"')end
  if row[1]=='/test voidgift'then gift=true;check(row[2]:find('tutorial',1,true)~=nil,'R158c G: the voidgift help row mentions the tutorial')end
 end
 check(helped and gift,'R158c G: /test playtime and /test voidgift are in the F4 help')
end
-- H. cost: nothing per frame, nothing allocated per look beyond numbers, no attribute written for play time
do
 local function connected(sig)local n=0;for _,c in ipairs(sig._c or{})do if c.Connected then n+=1 end end;return n end
 local function frameConnections()return connected(W.Run.Heartbeat),connected(W.Run.RenderStepped),W.Run.Stepped and connected(W.Run.Stepped)or 0 end
 local h0,r0,s0=frameConnections()
 local b=G.backend();local s=new(b,nil);local players={}
 for i=1,12 do players[i]=G.player(s,2500+i,'C'..i,{Played=false})end
 s.Svc:Step()
 local h1,r1,s1=frameConnections()
 check(h1==h0 and r1==r0 and s1==s0,'R158c H: counting adds no Heartbeat / RenderStepped / Stepped connection (it rides the giveaway\'s existing 2 s loop)')
 -- 300 looks (10 minutes) of 12 players: no Instance is created, no play-time attribute is written, saves are marked every 30 s
 local made=0;local inew=R.Instance.new;R.Instance.new=function(...)made+=1;return inew(...)end
 local writes=0;local rawSet=R.Inst.SetAttribute;function R.Inst.SetAttribute(self,k,v)if k=='VoidPlayLeft157'then writes+=1 end;return rawSet(self,k,v)end
 local dirty0=0;for _,pl in ipairs(players)do dirty0+=s.Data.Dirty[pl]or 0 end
 tick(s,600)
 R.Instance.new=inew;R.Inst.SetAttribute=rawSet
 local dirty=0;for _,pl in ipairs(players)do dirty+=(s.Data.Dirty[pl]or 0)end;dirty-=dirty0
 check(made==0,'R158c H: 300 looks of 12 players create no Instance ('..made..')')
 check(writes==0,'R158c H: ... and write no play-time attribute at all ('..writes..')')
 check(dirty==12*20,'R158c H: ... and mark the profile dirty every 30 s (240 in 10 minutes: '..dirty..')')
 local counted=true;for _,pl in ipairs(players)do if field(s,pl)~=600 then counted=false end end;check(counted,'R158c H: all 12 counted exactly 600 s')
 -- the loop that counts is the existing one: S.LoopSeconds is still 2 s and there is no new loop
 check(G.Service.LoopSeconds==2,'R158c H: the loop is the giveaway\'s own, every 2 s (unchanged)')
 -- heap: a thousand more looks leave nothing behind
 collectgarbage();collectgarbage();local m0=collectgarbage('count');tick(s,2000);collectgarbage();collectgarbage();local m1=collectgarbage('count')
 check(m1-m0<64,string.format('R158c H: 1000 more looks keep nothing (heap %.0f -> %.0f KB)',m0,m1))
end

print(string.format('giveaway server: %d checks, %d failed',checks,fails))
if fails>0 then error('FAILED '..fails)end
print('OK '..checks..' checks')
