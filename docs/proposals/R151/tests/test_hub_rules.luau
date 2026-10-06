--!nocheck
-- R151 hub displays: the pure rules (HubDisplayRules, HubDisplayBoard) with the REAL game modules (SeedPackRules, ItemWeight, PlantCatalog, DailyRewards ...):
--  1. ranking: every tie-break of BEST PULL (rarity rank, then the smaller chance, then the heavier seed, then the earlier pull, then the user id, then the seed id) and of
--     BIGGEST FRUIT (kg, earlier, user id), strictness (never both ways), transitivity, and one winner whatever the order the records arrive in; the real game's ranks
--     (Common ... King, the Verity seed, the Mech seeds);
--  2. records: Clean* refuses bad fields, recomputes rank and weight, StorePull / CleanPull round-trip, names are short and printable;
--  3. the day: DailyRewards.Day / the midnight edge, countdown text, NextAt;
--  4. the fruit of the day: eligible list (harvestable, not retired, not limited-time, weighted), deterministic, any `n` consecutive days all different, never two days in a row,
--     period n (no repeat for n days), the step is coprime with n, a plant without a meaningful weight is skipped;
--  5. the board: slots, Offer results, remote merge, unsynced, day change;
--  6. texts and the words: notices, the plaque and label rows (champion / empty, both boards: the title, the winner, the seed / weight, the fruit of the day, the countdown), every
--     fruit title and every pull line fits its row at a readable size, the stand's numbers (a 25 stud avatar, the reserved corner).
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
local Rules=W.module('HubDisplayRules');local P=W.module('SeedPackRules');local Weight=W.module('ItemWeight');local Daily=W.module('DailyRewards')
local Catalog=W.module('PlantCatalog');local Verity=W.module('VerityCatalog');local Mech=W.module('MechCatalog');local Odds=W.module('OddsText85')
local Board=H.server('HubDisplayBoard') -- (a server module: the harness moved every one under ServerScriptService.ChestChaseServer)
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

-- 1. Ranking -------------------------------------------------------------------------------------------------------------------------------------------------
do
 local king=pull({Rarity='King',Id='SolarStarfruitSeed',Seed='Sunstar',Odds=10})            -- a very common King (1/10)
 local mythic=pull({Rarity='Mythic',Odds=1e-9})                                               -- an absurdly rare Mythic
 check(Rules.PullBetter(king,mythic)and not Rules.PullBetter(mythic,king),'a higher rarity rank wins whatever the odds (King 1/10 beats Mythic 1/100000000000)')
 local order={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
 local ok=true;for i=2,#order do
  local hi=pull({Rarity=order[i],Odds=90});local lo=pull({Rarity=order[i-1],Odds=1e-6})
  if not Rules.PullBetter(hi,lo)or Rules.PullBetter(lo,hi)then ok=false end
 end
 check(ok,'the rank order is Common < Uncommon < Rare < Legendary < Mythic < Secret < Cosmic < King (the game\'s own SeedPackRules.Rarities)')
 check(Rules.RankOf('Common')==1 and Rules.RankOf('Mythic')==5 and Rules.RankOf('King')==8 and Rules.RankOf('Bogus')==0,'RankOf reads the game\'s ranks')
 local rare=pull({Odds=.5});local rarer=pull({Odds=.05})
 check(Rules.PullBetter(rarer,rare)and not Rules.PullBetter(rare,rarer),'same rank: the smaller chance (the rarer pull) wins')
 local small=pull({Scale=1});local big=pull({Scale=3})
 check(Rules.PullBetter(big,small)and not Rules.PullBetter(small,big),'same rank and chance: the heavier (bigger) seed wins')
 check(near(big.Kg,Weight.Weight('Seed','FirePepperSeed',3))and big.Kg>small.Kg,'a pull\'s weight is ItemWeight\'s seed kg at its size')
 local early=pull({At=1000});local late=pull({At=1001})
 check(Rules.PullBetter(early,late)and not Rules.PullBetter(late,early),'same rank, chance and size: the earlier pull wins')
 local u1=pull({Uid=5});local u2=pull({Uid=9})
 check(Rules.PullBetter(u1,u2)and not Rules.PullBetter(u2,u1),'identical pulls at the same second: the smaller user id wins (every server picks the same one)')
 local s1=pull({Id='AAA',Seed='A'});local s2=pull({Id='BBB',Seed='B'})
 check(Rules.PullBetter(s1,s2)~=Rules.PullBetter(s2,s1),'even the same user at the same second with two different seeds has one winner')
 check(not Rules.PullBetter(early,pull({At=1000})),'the same pull twice is not better than itself')
 check(Rules.PullBetter(early,nil)and not Rules.PullBetter(nil,early)and not Rules.PullBetter(nil,nil),'anything beats nothing, nothing beats anything')
 local a=pull({Odds=.125});local b=pull({Odds=.125*(1+1e-12)})
 check(Rules.Better('Pull',a,b)==Rules.PullBetter(a,b)and Rules.Better('Fruit',a,b)==Rules.FruitBetter(a,b),'Better picks the kind\'s order')
 local a2=pull({Odds=.125,At=5});local b2=pull({Odds=.125*(1+1e-12),At=6})
 check(Rules.PullBetter(a2,b2)and not Rules.PullBetter(b2,a2),'chances equal within a rounding error count as equal (the earlier time decides)')
 -- the real game's seeds
 local verity=pull({Id='VeritySeed',Seed='Verity',Rarity='King',Odds=1})
 local kingNormal=pull({Id='SolarStarfruitSeed',Seed='Sunstar',Rarity='King',Odds=1e-10})
 check(verity.Rank==8 and Rules.PullBetter(verity,mythic)and Rules.PullBetter(kingNormal,verity),'the Verity seed is a King: it beats any Mythic, and a King from a normal pack (1/10 billion) beats it (1/100)')
 local mech=pull({Id='CrowncoreTreeSeed',Seed='Crowncore Tree',Rarity='King',Odds=.01})
 check(mech.Rank==8,'a Mech seed keeps the rarity the pack rolled')
 -- one winner, any order
 local pool={}
 local seedValue=151
 local rng={NextInteger=function(_,a,b)seedValue=(seedValue*1103515245+12345)%2147483648;return a+(seedValue//65536)%(b-a+1)end}
 for i=1,60 do
  pool[#pool+1]=pull({Uid=rng:NextInteger(1,6),Name='P'..i,Id='Seed'..rng:NextInteger(1,3),Seed='S',Rarity=order[rng:NextInteger(1,8)],Odds=({.1,.5,1,5})[rng:NextInteger(1,4)],Scale=({1,2})[rng:NextInteger(1,2)],At=rng:NextInteger(1,4)})
 end
 local function sorted(list)local c=table.clone(list);table.sort(c,Rules.PullBetter);return c end
 local first=sorted(pool)
 local same=true
 for _=1,12 do
  local shuffled=table.clone(pool)
  for i=#shuffled,2,-1 do local j=rng:NextInteger(1,i);shuffled[i],shuffled[j]=shuffled[j],shuffled[i]end
  local s=sorted(shuffled)
  for i=1,#s do if Rules.Key(s[i])~=Rules.Key(first[i])then same=false end end
 end
 check(same,'sorting 60 pulls (many ties) gives the same order from any arrival order: one champion on every server')
 local both,trans=false,true
 for i=1,#pool do for j=1,#pool do
  if i~=j and Rules.PullBetter(pool[i],pool[j])and Rules.PullBetter(pool[j],pool[i])and Rules.Key(pool[i])~=Rules.Key(pool[j])then both=true end
 end end
 for i=1,#pool do for j=1,#pool do for k=1,#pool do
  if Rules.PullBetter(pool[i],pool[j])and Rules.PullBetter(pool[j],pool[k])and not Rules.PullBetter(pool[i],pool[k])then trans=false end
 end end end
 check(not both and trans,'PullBetter is strict (never better both ways) and transitive over 60 random pulls')
 -- fruit
 local f1=fruit({Scale=2});local f2=fruit({Scale=3})
 check(Rules.FruitBetter(f2,f1)and not Rules.FruitBetter(f1,f2),'BIGGEST FRUIT: the heavier fruit wins')
 check(Rules.FruitBetter(fruit({At=5}),fruit({At=6}))and not Rules.FruitBetter(fruit({At=6}),fruit({At=5})),'the same weight: the earlier harvest wins')
 check(Rules.FruitBetter(fruit({Uid=2}),fruit({Uid=7}))and not Rules.FruitBetter(fruit({Uid=7}),fruit({Uid=2})),'the same weight and second: the smaller user id wins')
 check(Rules.FruitBetter(fruit({Coat='Diamond'}),fruit({Coat='Gold'}))~=Rules.FruitBetter(fruit({Coat='Gold'}),fruit({Coat='Diamond'})),'identical fruit with different coats still have one winner')
 check(near(f2.Kg,Weight.Weight('Fruit','SunflowerSeed',3))and near(f2.Kg,3*Weight.FruitBase('SunflowerSeed')),'a fruit\'s kg is ItemWeight\'s fruit weight at its size')
 check(Rules.FruitBetter(f1,nil)and not Rules.FruitBetter(nil,f1),'a fruit beats nothing')
end

-- 2. Records -------------------------------------------------------------------------------------------------------------------------------------------------
do
 local good=pull()
 check(good and good.Rank==5 and good.Kg>0 and good.Coat=='None'and good.Name=='A','a good pull cleans to itself, with the rank and weight computed')
 check(pull({Rarity='Bogus'})==nil and pull({Rarity=5})==nil and pull({Rarity=false})==nil,'an unknown rarity is refused')
 check(pull({Odds=0})==nil and pull({Odds=-1})==nil and pull({Odds=101})==nil and pull({Odds=0/0})==nil and pull({Odds=math.huge})==nil and pull({Odds='x'})==nil,'a chance outside (0, 100], NaN, infinite or a string is refused')
 check(pull({At=-1})==nil and pull({At=1.5})==nil and pull({At=0/0})==nil and pull({At='1'})==nil,'a bad time is refused')
 check(pull({Uid=1.5})==nil and pull({Uid='1'})==nil and pull({Uid=false})==nil,'a bad user id is refused')
 check(pull({Id=''})==nil and pull({Id=5})==nil and pull({Id=string.rep('x',61)})==nil,'a bad seed id is refused')
 check(Rules.CleanPull(nil)==nil and Rules.CleanPull('x')==nil and Rules.CleanPull(5)==nil,'a non-table is refused')
 check(pull({Scale=0/0}).Scale==1 and pull({Scale=1000}).Scale<=25 and pull({Scale=-5}).Scale>=.35,'a bad size is repaired (NaN = 1, clamped into the game\'s limits)')
 check(pull({Coat='Rainbow'}).Coat=='None'and pull({Coat='Gold'}).Coat=='Gold'and pull({Coat='Diamond'}).Coat=='Diamond','only the game\'s coats exist')
 local forged=Rules.CleanPull({Uid=1,Name='A',Id='FirePepperSeed',Seed='Fire Pepper',Rarity='Mythic',Odds=.125,Scale=1,At=1000,Rank=99,Kg=1e9})
 check(forged.Rank==5 and forged.Kg<100,'a stored rank / weight is never trusted: both are recomputed from the rarity and the size')
 check(pull({Name='  Bob\n\tthe\0Builder  '}).Name=='Bob the Builder','control characters and extra spaces are removed from a name')
 check(pull({Name=string.rep('W',60)}).Name==string.rep('W',24)and utf8.len(pull({Name=string.rep('é',40)}).Name)==24,'a name is at most 24 characters (counted as UTF-8)')
 check(pull({Name=''}).Name=='Player'and pull({Name=5}).Name=='Player'and pull({Name='\xff\xfe'}).Name=='Player','no usable name reads as "Player"')
 check(pull({Test=true}).Test==true and pull().Test==false,'the Test flag is kept as a boolean')
 local stored=Rules.StorePull(good)
 local keys=0;for _ in pairs(stored)do keys+=1 end
 check(keys==9 and stored.Rank==nil and stored.Kg==nil and stored.Test==nil,'what is stored is nine plain fields (no rank, no kg, no Test flag)')
 check(Rules.Key(Rules.CleanPull(stored))==Rules.Key(good),'a record survives the store round trip with the same key')
 local fr=fruit()
 check(fr and fr.Kg>0 and fr.Weather=='None','a good fruit cleans')
 check(fruit({Scale=0})==nil and fruit({Scale=0/0})==nil and fruit({Scale=-1})==nil and fruit({Scale='3'})==nil and fruit({Id=''})==nil and fruit({At='x'})==nil,'a bad fruit is refused')
 check(fruit({Scale=1e6}).Scale<=50 and fruit({Weather='Bogus'}).Weather=='None'and fruit({Weather='Drippy'}).Weather=='Drippy','a huge size is capped, an unknown weather reads as none')
 check(Rules.Key(Rules.CleanFruit(Rules.StoreFruit(fr)))==Rules.Key(fr),'a fruit survives the store round trip')
 local doc=Rules.StoreDoc({pull=good,fruit=fr})
 check(doc.v==1 and doc.pull and doc.fruit,'a document is {v, pull, fruit}')
 local clean=Rules.CleanDoc({v=1,pull={Rarity='Bogus'},fruit='junk'})
 check(next(clean)==nil and next(Rules.CleanDoc(nil))==nil and next(Rules.CleanDoc(5))==nil,'a document with unusable parts keeps none of them')
 local half=Rules.CleanDoc({v=1,pull=stored,fruit={Id='x'}})
 check(half.pull and not half.fruit,'a usable part stays when the other is junk')
end

-- 3. The day -------------------------------------------------------------------------------------------------------------------------------------------------
do
 check(Rules.Day(0)==0 and Rules.Day(86399)==0 and Rules.Day(86400)==1 and Rules.Day(20000*86400+86399)==20000 and Rules.Day(20001*86400)==20001,'the day number turns over at midnight UTC')
 local same=true;for _,t in ipairs({0,1,86399,86400,1.7e9,1.78e9,1.78e9+43200})do if Rules.Day(t)~=Daily.Day(t)then same=false end end
 check(same,'it is DailyRewards.Day (the same function the daily rewards and the mystery pedestal use)')
 check(Rules.SecondsLeft(86399)==1 and Rules.SecondsLeft(86400)==86400 and Rules.SecondsLeft(0)==86400 and Rules.SecondsLeft(43200)==43200,'seconds left in the day')
 check(Rules.NextAt(20000)==20001*86400 and Rules.NextAt(Rules.Day(20000*86400+5))-(20000*86400+5)==Rules.SecondsLeft(20000*86400+5),'NextAt is the next midnight, consistent with SecondsLeft')
 check(Rules.Countdown(18720)=='5h 12m'and Rules.Countdown(3600)=='1h 0m'and Rules.Countdown(3599)=='59m 59s'and Rules.Countdown(750)=='12m 30s'and Rules.Countdown(45)=='45s'and Rules.Countdown(0)=='0s','countdown text: 5h 12m, 12m 30s, 45s')
 check(Rules.Countdown(-5)=='0s'and Rules.Countdown(0/0)=='0s'and Rules.Countdown(nil)=='0s'and Rules.Countdown(86400)=='24h 0m','countdown text survives a negative, NaN or missing number')
end

-- 4. The fruit of the day --------------------------------------------------------------------------------------------------------------------------------------
local list=Rules.EligibleFruits()
do
 local n=#list
 check(n>=20 and n<=60,'the rotation has '..n..' fruit types')
 local seen={};local ok=true
 for i,id in ipairs(list)do
  local def=Catalog[id];local rank=Rules.RankOf(P.SeedRarityById[id])
  if seen[id]or not def or(def.FruitCount or 0)<1 or P.IsRetired(id)or Verity.Is(id)or Mech.Is(id)or rank<1 or rank>Rules.MaxFruitRank or not(Weight.Base('Fruit',id)>=Rules.MinFruitKg)then ok=false;print('  bad entry '..id)end
  seen[id]=true
  if i>1 and list[i-1]>=id then ok=false end
 end
 check(ok,'every fruit in the list is harvestable, not retired, not limited-time (Verity, the Mech plants), at most Mythic and weighs at least 0.5 kg; sorted, no repeats')
 local has={};for _,id in ipairs(list)do has[id]=true end
 check(has.SunflowerSeed and has.AshRoseSeed and has.AppleSeed and has.EmberBloomSeed and has.FirePepperSeed,'Watermelon, Ash Tomato, Apple, Ember Pumpkin and Fire Pepper are in it')
 check(not has.VeritySeed and not has.CrowncoreTreeSeed and not has.HoloMelonSeed and not has.AgaveSeed and not has.StrawberrySeed and not has.PolarStarbloomSeed and not has.SolarStarfruitSeed,'Verity, a Mech plant, retired plants and Secret / Cosmic / King plants are not')
 -- a plant without a meaningful weight, a retired one, a fruitless one, a bad one
 local fake={A={FruitCount=1},B={FruitCount=1},C={FruitCount=0},D={FruitCount=2},E={FruitCount=1},F='x'}
 local picked=Rules.EligibleFruits({Catalog=fake,IsRetired=function(id)return id=='E'end,Excluded=function()return false end,Rank=function()return 1 end,
  Base=function(id)return({A=5,B=.2,C=9,D=0/0,E=7})[id]or 1 end})
 check(table.concat(picked,',')=='A','a plant under 0.5 kg, a NaN weight, a fruitless plant, a retired one and a malformed entry are skipped (only A is left)')
 local empty=Rules.EligibleFruits({Catalog={},IsRetired=function()return false end,Excluded=function()return false end})
 check(#empty==0 and Rules.FruitForDay({},123)==nil,'an empty list has no fruit of the day (nil, no error)')
 -- rotation
 local day0=20727
 local a=Rules.FruitForDay(list,day0);local b=Rules.FruitForDay(list,day0)
 check(a and a==b and has[a],'the fruit of a day is deterministic and from the list')
 local reversed={};for i=#list,1,-1 do reversed[#reversed+1]=list[i]end
 check(Rules.FruitForDay(reversed,day0)==a and Rules.FruitForDay(reversed,day0+9)==Rules.FruitForDay(list,day0+9),'it does not depend on the order the list was built in')
 local distinct,never=true,true
 for start=day0,day0+200 do
  local seenWindow={}
  for d=start,start+n-1 do local id=Rules.FruitForDay(list,d);if seenWindow[id]then distinct=false end;seenWindow[id]=true end
  if Rules.FruitForDay(list,start)==Rules.FruitForDay(list,start+1)then never=false end
 end
 check(distinct,'any '..n..' consecutive days have '..n..' different fruit: nothing comes back until the whole list has been through')
 check(never,'two days in a row are never the same fruit')
 local periodic=true;for d=day0,day0+120 do if Rules.FruitForDay(list,d)~=Rules.FruitForDay(list,d+n)then periodic=false end end
 check(periodic,'the cycle is exactly '..n..' days (a fruit comes back on day + '..n..')')
 local cover={};for d=day0,day0+n-1 do cover[Rules.FruitForDay(list,d)]=true end
 local covered=0;for _ in pairs(cover)do covered+=1 end
 check(covered==n,'every fruit of the list is the fruit of one day in each cycle')
 local gaps=true;local last={}
 for d=day0,day0+4*n do local id=Rules.FruitForDay(list,d);if last[id]and d-last[id]<n then gaps=false end;last[id]=d end
 check(gaps,'the gap between two days of one fruit is never shorter than the list ('..n..' days)')
 local nonConsecutive=0;for d=day0,day0+n-2 do if Rules.FruitForDay(list,d)~=Rules.FruitForDay(list,d+1)then nonConsecutive+=1 end end
 local stepOk=true
 for len=1,80 do
  local step=Rules.FruitStep(len)
  local g=function(x,y)while y~=0 do x,y=y,x%y end;return x end
  if len>=7 and(g(step,len)~=1 or step<2 or step>len-2)then stepOk=false;print('  step '..step..' for '..len)end
  if len<7 and step~=1 and g(step,len)~=1 then stepOk=false end -- (a list of 6 or fewer has no step that is neither a neighbour nor shared: it walks one by one)
 end
 check(stepOk,'the walk\'s step is coprime with the list length (so every fruit comes up) and never a neighbour, for every length from 7 to 80 (shorter lists walk one by one)')
 local days={};for _,len in ipairs({1,2,3,4,7,25,32,33,60})do
  local l={};for i=1,len do l[i]='F'..i end
  local ok2=true;local seenL={}
  for d=1000,1000+len-1 do local id=Rules.FruitForDay(l,d);if seenL[id]then ok2=false end;seenL[id]=true end
  if not ok2 then days[#days+1]=len end
 end
 check(#days==0,'any list length from 1 to 60 visits every fruit once per cycle')
 check(Rules.FruitForDay(list,-5)~=nil and Rules.FruitForDay(list,0/0)==nil and Rules.FruitForDay(list,'x')==nil,'a negative day still works, a NaN or non-number day gives nil')
 -- today's list on this checkout: print a month
 local names={};for d=day0,day0+6 do names[#names+1]=Rules.FruitForDay(list,d):gsub('Seed$','')end
 print('  (a week of fruit: '..table.concat(names,', ')..')')
end

-- 5. The board -------------------------------------------------------------------------------------------------------------------------------------------------
do
 local b=Board.new()
 check(b:Best('Pull')==nil and not b:Unsynced('Pull')and b:Best('Bogus')==nil and b:Offer('Bogus',{})=='ignored','a new board is empty; an unknown kind is ignored')
 check(b:SetDay(100,'SunflowerSeed')and not b:SetDay(100,'SunflowerSeed')and b:SetDay(100,'AppleSeed')and b:SetDay(101,'AppleSeed'),'SetDay says whether the day or the fruit changed')
 local p1=pull({At=10})
 check(b:Offer('Pull',p1)=='took'and b:Best('Pull')==p1,'the first pull takes the spot')
 local source;_,source=b:Best('Pull');check(source=='Local','it came from this server')
 check(b:Unsynced('Pull'),'a Local record better than the shared one needs writing')
 local worse=pull({Rarity='Rare',Odds=5,At=11})
 check(b:Offer('Pull',worse)=='ignored','a worse pull than this server\'s own best is ignored')
 check(b:MergeRemote('Pull',pull({Rarity='Secret',Odds=.01,At=20,Uid=2}))and b:Best('Pull').Rarity=='Secret','a better shared record becomes the champion')
 _,source=b:Best('Pull');check(source=='Remote','and says it came from the store')
 check(not b:Unsynced('Pull'),'our record is not better than the shared one: nothing to write')
 check(b:Offer('Pull',pull({Rarity='Mythic',Odds=.1,At=30}))=='kept'and b:Best('Pull').Rarity=='Secret','a pull better than our own but worse than the shared one is "kept" (recorded), not shown')
 check(b:Offer('Pull',pull({Rarity='King',Odds=1e-9,At=31}))=='took'and b:Unsynced('Pull'),'a better one takes the spot again and needs writing')
 check(b:MergeRemote('Pull',b:Best('Pull'))==true,'a store answer that differs from the last one says so (the display refreshes)')
 local sameRemote=pull({Rarity='King',Odds=1e-9,At=31})
 check(b:MergeRemote('Pull',sameRemote)==false,'the same store answer again changes nothing (nothing to refresh)')
 check(not b:Unsynced('Pull'),'once the store holds an equal record there is nothing left to write')
 local t=pull({Rarity='King',Odds=1e-12,At=5,Test=true,Uid=3})
 check(b:Offer('Pull',t)=='took'and b:Best('Pull')==t,'an injected test pull shows')
 _,source=b:Best('Pull');check(source=='Test','from the Test slot')
 check(not b:Unsynced('Pull')or b:LocalBest('Pull')~=t,'and is never "unsynced": a test record is never written to the store')
 b:ClearLocal()
 check(b:Best('Pull').Rarity=='King'and b:LocalBest('Pull')==nil,'ClearLocal forgets this server\'s own and the test records; the store\'s stays')
 b:SetDay(102,'AppleSeed')
 check(b:Best('Pull')==nil and b:LocalBest('Pull')==nil,'a new day empties everything')
 -- fruit
 b:SetDay(103,'SunflowerSeed')
 check(b:Offer('Fruit',fruit({Id='AppleSeed'}))=='ignored','a fruit of another type than today\'s is ignored')
 check(b:Offer('Fruit',fruit({Scale=2}))=='took'and b:Offer('Fruit',fruit({Scale=1,At=2}))=='ignored'and b:Offer('Fruit',fruit({Scale=4,At=3}))=='took','heavier fruit takes the spot; lighter does not')
 check(not b:MergeRemote('Fruit',fruit({Id='AppleSeed',Scale=9}))and b:Best('Fruit').Kg==4*Weight.FruitBase('SunflowerSeed'),'a shared fruit of another type is not today\'s board')
 check(b:MergeRemote('Fruit',fruit({Scale=6,Uid=2}))and b:Best('Fruit').Scale==6,'a heavier shared fruit wins')
 check(not b:MergeRemote('Fruit',fruit({Scale=6,Uid=2})),'merging the same shared record changes nothing')
 check(b:MergeRemote('Fruit',nil)and b:Best('Fruit').Scale==4,'the shared record vanishing (an owner reset) leaves this server\'s own best')
 -- R152: the shared fruit is another list's (another type): this fruit board has nothing to write, and the BEST PULL board is not touched by it
 local c=Board.new();c:SetDay(104,'SunflowerSeed')
 c:Offer('Fruit',fruit({Scale=2}));c:Offer('Pull',pull({At=10}))
 check(c:Unsynced('Fruit')and c:Unsynced('Pull'),'(a local fruit and a local pull both need writing)')
 c:MergeRemote('Fruit',fruit({Id='AppleSeed',Scale=9}))
 check(c.Boards.Fruit.Foreign==true and not c:Unsynced('Fruit'),'the stored fruit is of another type: the fruit board is Foreign and needs no write (it used to stay "unsynced" for ever)')
 check(c:Unsynced('Pull')and c.Boards.Pull.Foreign==false,'the BEST PULL board is unaffected')
 c:MergeRemote('Fruit',nil);check(c.Boards.Fruit.Foreign==false and c:Unsynced('Fruit'),'when the other type is gone from the store the fruit board needs writing again')
 c:SetForeign('Fruit');check(not c:Unsynced('Fruit'),'the store saying "another list\'s fruit" does the same (SetForeign)');c:SetForeign('Pull');check(c:Unsynced('Pull'),'(only the fruit board can be Foreign)')
 c:MergeRemote('Fruit',fruit({Scale=1,Uid=2}));check(c.Boards.Fruit.Foreign==false,'a stored fruit of our type clears it')
 c:SetForeign('Fruit');c:SetDay(105,'SunflowerSeed');check(c.Boards.Fruit.Foreign==false,'a new day clears it')
end

-- 6. Texts and the sign --------------------------------------------------------------------------------------------------------------------------------------
do
 local rec=pull({Name='Jess',Seed='Fire Pepper',Rarity='Mythic',Odds=.125})
 check(Rules.PullName(rec)=='Mythic Fire Pepper','the line reads "Mythic Fire Pepper"')
 check(Rules.OddsText(.125)=='1/800'and Rules.OddsText(.125)==Odds.Format(.125),'the chance reads 1/800 (OddsText85, the game\'s format)')
 check(Rules.PullNotice==nil and Rules.FruitNotice==nil and Rules.NoticeMinRank==nil and Rules.NoticeGap==8,'the hub keeps no notice text and no notice rank of its own any more (the record line is PullAnnouncer\'s, in chat; only the 8 s gap between two lines of one board stays)')
 local fr=fruit({Name='Sam',Scale=2.5})
 check(Rules.KgText(12.4)=='12.4 kg'and Rules.KgText(.5)=='0.5 kg'and Rules.KgText(1250)=='1,250 kg'and Rules.KgText(999.96)=='1000.0 kg'and Rules.KgText(0)==''and Rules.KgText(0/0)=='','weights read "12.4 kg", "1,250 kg"')
 check(Rules.Emoji('SunflowerSeed')=='🍉'and Rules.Emoji('NoSuchSeed')=='🌱','🍉 for the watermelon, 🌱 for an unknown plant')
 local t=Rules.SignText('Pull',rec,nil,18720)
 check(t.State=='Champion'and t.Plaque.Title.Text=='BEST PULL TODAY'and t.Plaque.Name.Text=='Jess'and t.Plaque.Line.Text=='Mythic · 1/800'and t.Plaque.Footer.Text=='New board in 5h 12m',
  'the BEST PULL plaque: the title, the winner, "Mythic · 1/800", "New board in 5h 12m"')
 check(t.Label.Title.Text=='BEST PULL TODAY'and t.Label.Name.Text=='Jess'and t.Label.Info.Text=='Fire Pepper','the label over the seed: the title, the winner, "Fire Pepper"')
 local c=Rules.RarityColor('Mythic');local game=P.Rarities.Mythic.Color
 check(t.Accent[1]==c[1]and t.Accent[2]==c[2]and t.Accent[3]==c[3]and c[1]==math.floor(game.R*255+.5)and c[2]==math.floor(game.G*255+.5)and c[3]==math.floor(game.B*255+.5),'the accent is the rarity\'s own colour (SeedPackRules.Rarities)')
 check(t.Label.Info.Color[1]==c[1]and t.Plaque.Line.Color[1]==c[1],'the seed is written in it')
 local gold=Rules.SignText('Pull',pull({Coat='Gold'}),nil,60)
 check(gold.Plaque.Line.Text=='Mythic · 1/800 · Gold','a coat is told after the chance')
 local e=Rules.SignText('Pull',nil,nil,99)
 check(e.State=='Empty'and e.Label.Name.Text=='Nobody yet'and e.Plaque.Name.Text=='Nobody yet'and e.Plaque.Line.Text:find('Open a pack',1,true)and e.Label.Info.Text:find('Open a pack',1,true),'the empty BEST PULL invites the first pull')
 local f=Rules.SignText('Fruit',fr,'SunflowerSeed',3600,'Watermelon')
 check(f.State=='Champion'and f.Plaque.Title.Text=='BIGGEST FRUIT TODAY'and f.Plaque.Name.Text=='Sam'and f.Label.Name.Text=='Sam'and f.Label.Info.Text==Rules.KgText(fr.Kg)and f.Plaque.Footer.Text=='New fruit in 1h 0m','the BIGGEST FRUIT plaque and label: the title, the winner, the weight, a countdown')
 check(f.Plaque.Line.Text=='Today: 🍉 Watermelon','a short line under the winner tells the fruit of the day: "Today: 🍉 Watermelon"')
 local fe=Rules.SignText('Fruit',nil,'SunflowerSeed',60,'Watermelon')
 check(fe.State=='Empty'and fe.Plaque.Line.Text=='Today: 🍉 Watermelon'and fe.Label.Name.Text=='Nobody yet'and fe.Label.Info.Text:find('Pick',1,true),'the empty BIGGEST FRUIT still says the fruit of the day and invites a harvest')
 check(Rules.SignText('Fruit',Rules.CleanFruit({Uid=1,Name='G',Id='SunflowerSeed',Scale=2,Coat='Gold',Weather='Drippy',At=5}),'SunflowerSeed',60,'Watermelon').Label.Info.Text:find(' · Gold · Drippy',1,true),'a coat and a weather are told after the weight')
 check(Rules.SignText('Fruit',nil,'SunflowerSeed',60).Plaque.Line.Text:find('Today: ',1,true)==1,'a fruit with no name given is looked up (never an error)')
 -- the rows fit: the plaque's four rows are inside its canvas and one under another; the label's three rows inside the label
 local PL=Rules.Plaque;local rows=PL.Rows
 local inside,apart=true,true
 local keys={'Title','Name','Line','Footer'}
 for i,k in ipairs(keys)do
  local r=rows[k]
  if r.X<0 or r.Y<0 or r.X+r.W>PL.Canvas.W or r.Y+r.H>PL.Canvas.H then inside=false end
  if i>1 then local p=rows[keys[i-1]];if p.Y+p.H>r.Y then apart=false end end
 end
 check(inside and apart and PL.Canvas.W==PL.W*PL.PixelsPerStud and PL.Canvas.H==PL.H*PL.PixelsPerStud,'the plaque\'s four rows are inside its canvas, one under another, and the canvas is the plate\'s studs x pixels per stud')
 local LB=Rules.Label;local lkeys={'Title','Name','Info'};local linside,lapart=true,true
 for i,k in ipairs(lkeys)do
  local r=LB.Rows[k]
  if r.X<0 or r.Y<0 or r.X+r.W>LB.W+1e-9 or r.Y+r.H>LB.H+1e-9 then linside=false end
  if i>1 then local p=LB.Rows[lkeys[i-1]];if p.Y+p.H>r.Y+1e-9 then lapart=false end end
 end
 check(linside and lapart and LB.W==26 and LB.H==8,'the label\'s three rows are inside its 26 x 8 studs, one under another')
 local worst,worstText=1e9,''
 local function fits(text,row)local px=Rules.Fit(text,row);if px<worst then worst,worstText=px,text end;return px end
 local minTitle=1e9
 for _,id in ipairs(list)do
  local def=Catalog[id];local name=Rules.FruitLabel(id,def.HarvestName)
  local text=Rules.SignText('Fruit',nil,id,1,name)
  minTitle=math.min(minTitle,fits(text.Plaque.Title.Text,rows.Title),fits(text.Plaque.Line.Text,rows.Line))
 end
 check(minTitle>=20,'every fruit of the rotation has a title and a "Today: ..." line that fit the plaque at 20 px or more (the smallest is '..string.format('%.0f',minTitle)..' px, .4 stud)')
 local minPull,minLabel=1e9,1e9
 for _,spec in ipairs(P.SeedDesigns)do
  local r=pull({Id=spec.id,Seed=Rules.SeedLabel(spec.id,spec.name),Rarity=spec.rarity,Name=string.rep('W',24)})
  if r then
   local pt=Rules.SignText('Pull',r,nil,1)
   minPull=math.min(minPull,fits(pt.Plaque.Line.Text,rows.Line),fits(pt.Plaque.Name.Text,rows.Name))
   minLabel=math.min(minLabel,Rules.Fit(pt.Label.Info.Text,LB.Rows.Info),Rules.Fit(pt.Label.Name.Text,LB.Rows.Name))
  end
 end
 check(minPull>=20,'every seed\'s rarity line and a 24-letter name fit the plaque at 20 px or more (worst: '..string.format('%.0f',minPull)..' px for "'..worstText..'")')
 check(minLabel>=1.1,'every seed name and a 24-letter winner fit the label at 1.1 studs or more (worst '..string.format('%.2f',minLabel)..')')
 local minFruitLabel=1e9
 for _,id in ipairs(list)do
  local r=fruit({Id=id,Name=string.rep('W',24),Scale=50,Coat='Diamond',Weather='Drippy'})
  if r then minFruitLabel=math.min(minFruitLabel,Rules.Fit(Rules.SignText('Fruit',r,id,1,'x').Label.Info.Text,LB.Rows.Info))end
 end
 check(minFruitLabel>=1.1,'the heaviest, coated, weathered fruit\'s weight line fits the label ('..string.format('%.2f',minFruitLabel)..' studs)')
 check(Rules.Fit('x',rows.Title)==rows.Title.Max and Rules.Fit(string.rep('W',100),rows.Name)<30,'a short text gets the row\'s full size, a very long one shrinks')
 -- the numbers of the stand
 check(Rules.AvatarHeight>=22 and Rules.AvatarHeight<=28 and Rules.ItemHeight>=10 and Rules.ItemHeight<=14,'the avatar is 22 to 28 studs tall (4 to 5 times a normal one), the showcase item about 12')
 local L=Rules.Layout;local Kit=W.module('HubDecorKit151')
 check(L.Corner.X0==Kit.Reserved[1].X0 and L.Corner.X1==Kit.Reserved[1].X1 and L.Corner.Z0==Kit.Reserved[1].Z0 and L.Corner.Z1==Kit.Reserved[1].Z1,'the corner is the one HubDecorKit151 reserves (x 145 .. 335, z -618 .. -420; the other side is its mirror)')
 local reach=math.sqrt(L.Footprint.HalfX^2+L.Footprint.HalfZ^2)  -- (the footprint is turned toward the market: its diagonal is the most it can reach)
 check(L.Pull.Center.X-reach>=L.Corner.X0 and L.Pull.Center.X+reach<=L.Corner.X1 and L.Pull.Center.Z-reach>=L.Corner.Z0 and L.Pull.Center.Z+reach<=L.Corner.Z1,'the Pull stand\'s footprint, turned any way ('..string.format('%.0f',reach)..' studs from its centre), fits the corner')
 check(L.Footprint.HalfX>=30 and L.Footprint.HalfZ>=20,'and is big: a pedestal and the dancing giant side by side')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
