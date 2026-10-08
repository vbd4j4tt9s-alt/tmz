--!nocheck
-- R140 (owner: "daily login rewards, per week, at the end players get 1 mech pack", "daily quests like steal 3 packs",
-- "speed boost for friends in the server", "the your plant is ready thing"), updated for the owner's live numbers.
-- R153 (owner: "the rewards are all fixed to random packs, and after finishing all quests they get 2 gems"; "the random pack is based on the player's
-- treadmill ... the rolling luck will be same as the bonus roll"): login days 1-4 = a random pack, day 5 = 2 Gems, day 6 = 3 Gems, day 7 = 1 Void Pack (R153, owner:
-- "change the mech pack to void pack for day 7"; days 1-6 are as they were); each daily quest = ONE random pack (the treadmill bonus roll's own pool / odds / size pity, never a Void, Mech or Verity pack),
-- claiming all three = 2 Gems once (6 a day -> 2); full Bag, the R141 / R140 mid-day migration, the 2-Gem cap, the R152 money auto-collect. The real
-- PlayerDataService (DailyProgress, AddChest, GrantMechPacks, OpenSeedPack, save rows), ChestService.Bank,
-- SocialService (friend boost, the shared plant-ready queue, the day rollover), Config.GetPlayerWalkSpeed (R149: x1, the
-- boost now multiplies the speed gained in BaseService:_updateTrainingPlayer), MovementGuard and the owner's daily command. MemoryStore and the Open Cloud call are faked; mock time = os.time.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={};local order={}
function Players.GetPlayers()local out={};for _,p in ipairs(order)do if present[p.UserId]==p then out[#out+1]=p end end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local sentRequests={};local httpOk=true
function Http.GetSecret(_,name)return {Secret=name}end
function Http.JSONEncode(_,t)return t end -- (the test reads the table back)
function Http.RequestAsync(_,req)sentRequests[#sentRequests+1]=req;return {Success=httpOk,StatusCode=httpOk and 200 or 500,Body=httpOk and'{}'or'boom'}end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
-- A shared fake MemoryStore (every SocialService instance = another server).
local MS=W.service('MemoryStoreService');local maps={};local msCalls=0
function MS.GetSortedMap(_,name)
 if maps[name]then return maps[name]end
 local m={Items={}}
 function m.SetAsync(self,key,value,ttl,sortKey)msCalls+=1;self.Items[key]={Value=value,Sort=sortKey,Expires=R.clock+ttl};return true end
 function m.GetAsync(self,key)msCalls+=1;local it=self.Items[key];return it and it.Expires>R.clock and it.Value or nil end
 function m.RemoveAsync(self,key)msCalls+=1;self.Items[key]=nil end
 function m.UpdateAsync(self,key,fn,ttl)msCalls+=1;local it=self.Items[key];local v,s=fn(it and it.Value,it and it.Sort);if v==nil then return nil end;self.Items[key]={Value=v,Sort=s,Expires=R.clock+ttl};return v end
 function m.GetRangeAsync(self,dir,count,lower,upper)msCalls+=1
  local out={};for k,it in pairs(self.Items)do if it.Expires>R.clock and(not upper or upper.sortKey==nil or(it.Sort or 0)<upper.sortKey)then out[#out+1]={key=k,value=it.Value,sortKey=it.Sort}end end
  table.sort(out,function(a,b)return(a.sortKey or 0)<(b.sortKey or 0)end);while #out>count do table.remove(out)end;return out
 end
 maps[name]=m;return m
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local D=W.module('DailyRewards');local Rules=W.module('SeedPackRules')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local shown={}
local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
R.clock=20000*86400+3600 -- a Tuesday-ish UTC day, 01:00
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local function pendingGems(p)local t={};for _,r in ipairs(Data.Gardens[p].PendingSales or{})do if r.Currency=='Gems'then t[#t+1]=r.Amount end end;return t end
local function nextDay(n)R.clock+=86400*(n or 1)end
local A=makePlayer(501,'Ava')
-- 1. The rules.
check(#D.Login==7 and D.Login[7].VoidPack==1 and D.Login[7].MechPack==nil and D.Login[7].SeedPack==nil and D.Login[7].Gems==nil,'a week of 7 login rewards, day 7 = 1 Void Pack (R153; it was a Mech pack)')
check(D.Login[1].SeedPack==1 and D.Login[2].SeedPack==1 and D.Login[3].SeedPack==1 and D.Login[4].SeedPack==1,'days 1-4 = a random seed pack each')
check(D.Login[5].Gems==2 and D.Login[6].Gems==3 and D.Login[5].SeedPack==nil and D.Login[6].VoidPack==nil,'day 5 = 2 Gems, day 6 = 3 Gems')
local stagesOk=#D.SeedPackStages==7;for i=1,7 do if D.SeedPackStages[i]~=i then stagesOk=false end end
local variantsOk=true;for _,v in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'})do if D.SeedPackVariants[v]~=true then variantsOk=false end end
for k in pairs(D.SeedPackVariants)do if not table.find(Rules.VariantOrder,k)then variantsOk=false end end
check(stagesOk and variantsOk,'the seed pack pool: stages 1-7, variants Pack01-Pack06 only')
check(D.RewardText(D.Login[1])=='RANDOM PACK'and D.RewardText(D.Login[5])=='+2'and D.RewardText(D.Login[6])=='+3'and D.RewardText(D.Login[7])=='VOID PACK','card texts: RANDOM PACK, +2, +3, VOID PACK')
local k1,k2=D.QuestKeys(501,D.Day(R.clock)),D.QuestKeys(501,D.Day(R.clock)+1)
check(#k1==3 and k1[1]==1 and D.Quests[1].Key=='Steal'and D.Quests[1].Goal==3 and D.QuestPacks==1 and D.AllDoneGems==2 and D.QuestGems==nil,'R153: 3 quests a day, the first is always "Steal 3 packs", ONE pack each, a 2-Gem bonus for all three')
check(D.QuestGemCap==2 and D.AllDoneGems==D.QuestGemCap and D.RewardVersion==153,'at most 2 Gems a day from quests (the bonus is the only quest Gems; it was 6), reward version 153')
local loginWas={{SeedPack=1},{SeedPack=1},{SeedPack=1},{SeedPack=1},{Gems=2},{Gems=3},{VoidPack=1}};local loginSame=#D.Login==7
for d=1,7 do for k,v in pairs(loginWas[d])do if D.Login[d][k]~=v then loginSame=false end end;for k in pairs(D.Login[d])do if loginWas[d][k]==nil then loginSame=false end end end
check(loginSame and D.ResetIfMissed==false,'R153: the 7-day login track: days 1-6 exactly as they were (4 random packs, 2 Gems, 3 Gems), day 7 the Void Pack')
check(D.QuestRewardText()=='+1 PACK'and D.BonusRewardText()=='+2 💎','reward texts: +1 PACK per quest, +2 💎 for ALL DONE')
check(k1[2]~=k1[3]and k1[2]~=1 and k1[3]~=1,'the other two are different quests')
local same=true;for i=1,3 do if D.QuestKeys(501,D.Day(R.clock))[i]~=k1[i]then same=false end end
check(same,'the same player gets the same quests all day')
local varied=false;for d=1,10 do local k=D.QuestKeys(501,D.Day(R.clock)+d);if k[2]~=k1[2]or k[3]~=k1[3]then varied=true end end
check(varied,'and other quests on other days')
-- 2. Login week (live: days 1-4 = a random seed pack, day 5 = 2 Gems, day 6 = 3 Gems, day 7 = 1 Void Pack).
local records=Data:GetChestRecords(A)
local addCalls,lastAdd,luckCalls=0,nil,0
local realAdd,realLuck=Data.AddChest,Data.RollPackLuck
local BonusRules=W.module('TreadmillBonusRules');local realRoll=BonusRules.RollPack;local rolledPacks=0;BonusRules.RollPack=function(...)rolledPacks+=1;return realRoll(...)end
Data.AddChest=function(self,p,chest,options)addCalls+=1;lastAdd={Chest=chest,Options=options};return realAdd(self,p,chest,options)end
Data.RollPackLuck=function(...)luckCalls+=1;return realLuck(...)end
local sizeOk={};for _,e in ipairs(Rules.PackSizes)do sizeOk[e.Scale]=true end
local function isDailyPack(r)
 return type(r)=='table'and r.Kind=='Pack'and table.find(D.SeedPackStages,r.Stage)~=nil and D.SeedPackVariants[r.BagVariant]==true
  and sizeOk[r.PackSize]==true and r.PackMutation=='None'and not r.PaidRandom and r.RateBoost==nil
end
Data:PublishDaily(A)
check(A:GetAttribute('DailyLoginReady')==true and A:GetAttribute('DailyQuestsReady')==0,'a new player has day 1 waiting')
local bag0=#records
local ok,msg,info=Data:ClaimDailyLogin(A)
local rec1=records[bag0+1]
check(ok and info.Day==1 and info.Reward.SeedPack==1 and #records==bag0+1 and #pendingGems(A)==0,'day 1: a random seed pack in the Bag, no Gems: '..tostring(msg))
check(rec1 and rec1.OddsVersion==Rules.OddsVersion,'R147: the login pack opens with the current odds (OddsVersion '..tostring(rec1 and rec1.OddsVersion)..')')
check(isDailyPack(rec1),'the pack: stage 1-7, a Pack01-06 variant, a rolled size, no mutation, not a paid item ('..tostring(rec1 and rec1.Stage)..', '..tostring(rec1 and rec1.BagVariant)..', x'..tostring(rec1 and rec1.PackSize)..')')
check(addCalls==1 and lastAdd.Options~=nil and lastAdd.Options.Luck==true and luckCalls==1 and rolledPacks==1,'R153: the pack is rolled like the treadmill bonus roll: AddChest gets {Luck=true} (the size pity), one TreadmillBonusRules.RollPack call')
check(A:GetAttribute('DailyLoginReady')==false and A:GetAttribute('DailyLoginStep')==1,'the badge clears after claiming')
local again,why=Data:ClaimDailyLogin(A);check(not again and tostring(why):find('TOMORROW'),'only one claim a day: '..tostring(why))
check(#records==bag0+1 and addCalls==1,'(and nothing was granted twice)')
for d=2,4 do
 nextDay();local n0=#records;local o,_,i=Data:ClaimDailyLogin(A)
 check(o and i.Day==d and i.Reward.SeedPack==1 and #records==n0+1 and isDailyPack(records[n0+1])and #pendingGems(A)==0,'day '..d..': another random seed pack, no Gems')
end
nextDay();local o5,_,i5=Data:ClaimDailyLogin(A);local g5=pendingGems(A)
check(o5 and i5.Day==5 and #g5==1 and g5[1]==2,'day 5: 2 Gems (as collectable Gems, like Index rewards)')
nextDay();local o6,_,i6=Data:ClaimDailyLogin(A);local g6=pendingGems(A)
check(o6 and i6.Day==6 and #g6==2 and g6[2]==3,'day 6: 3 Gems')
check(#records==bag0+4,'days 5 and 6 add no pack')
nextDay()
local before=#Data:GetChestRecords(A);local rollsAtDay7=rolledPacks
local o7,m7,i7=Data:ClaimDailyLogin(A)
local voidPack;local voids,mechs=0,0;for _,r in ipairs(Data:GetChestRecords(A))do if r.BagVariant=='EclipseReliquary'then voidPack=r;voids+=1 elseif r.BagVariant=='MechLimited'then mechs+=1 end end
check(o7 and i7.Day==7 and i7.Reward.VoidPack==1 and #Data:GetChestRecords(A)==before+1 and voidPack and voids==1 and mechs==0 and voidPack.Stage==7,'day 7: exactly one Void Pack (stage 7) in the Bag, no Mech pack ('..tostring(m7)..')')
check(voidPack and not voidPack.PaidRandom and voidPack.GiftLocked==true and voidPack.TestGrant==nil and voidPack.PackMutation=='None'and voidPack.OddsVersion==Rules.OddsVersion and sizeOk[voidPack.PackSize]==true,'a real Void Pack: free, gift-locked (R153 review L4: DailyRewards.LockDay7Void), not a test pack, a rolled size, the current odds')
check(tostring(m7):find('VOID PACK',1,true)~=nil and rolledPacks==rollsAtDay7,'the claim says VOID PACK and rolls no random pack (no bonus-roll pick)')
local giveawayPack=W.module('VoidGiveawayRules152').Pack
check(voidPack.BagVariant==giveawayPack.BagVariant and voidPack.Stage==giveawayPack.Stage and voidPack.Kind=='Pack','it is the same pack the Void giveaway hands out (stage 7 EclipseReliquary), and, like it, gift-locked (R153 review L4)')
check(Data:CheckVoidPack(A,voidPack.Id)==voidPack,'it is a real Void Pack: Verity can take it (CheckVoidPack finds it)')
local conv=Data:ConvertVoidPack(A,voidPack.Id);check(conv and conv.BagVariant=='VerityReliquary'and conv.GiftLocked==true,'... and turns it into a Verity pack that keeps the lock')
check(#Data:GetChestRecords(A)==before+1,'(still one pack in the Bag)')
local again7,again7why=Data:ClaimDailyLogin(A);check(not again7 and tostring(again7why):find('TOMORROW',1,true)and #Data:GetChestRecords(A)==before+1,'a player who claimed day 7 keeps what they got: no second pack the same day ('..tostring(again7why)..')')
do local st7=D.ReadLogin({Step=7,Day=D.Day(R.clock)});local ls=D.LoginStatus(st7,D.Day(R.clock));local nx=D.LoginStatus(st7,D.Day(R.clock)+1)
 check(st7.Step==7 and not ls.Ready and ls.Claimed==7 and nx.Ready and nx.Next==1,'(a saved day 7 claim reads as before: claimed today, the week starts again tomorrow)')end
nextDay();local o8,_,i8=Data:ClaimDailyLogin(A)
check(o8 and i8.Day==1 and isDailyPack(records[#records]),'the next day the week starts again at day 1 (a random seed pack)')
nextDay(3);local o9,_,i9=Data:ClaimDailyLogin(A)
check(o9 and i9.Day==2,'missing days only pauses the week (day 2 after a 2-day gap)')
Data.AddChest=nil;Data.RollPackLuck=nil
-- The random pool over many grants (R153): the treadmill bonus roll's own pool for the player's best treadmill (Rules.PoolStages) and odds (Rules.RollPack); never a Void, Mech or Verity pack.
do
 local pools={}
 for tier=1,#Config.TreadmillTiers do
  Data:GetTreadmillData(A).Tier=tier
  local want=BonusRules.PoolStages(Config.TreadmillTiers,tier);local inPool={};for _,s in ipairs(want)do inPool[s]=true end
  local stages,variants,sizes={},{},{};local bad,n,rolls0=0,tier==#Config.TreadmillTiers and 900 or 300,rolledPacks
  for _=1,n do
   local before2=#records;local rec=Data:GrantDailyPack(A,false)
   if not isDailyPack(rec)or #records~=before2+1 or not inPool[rec.Stage]or not D.SeedPackVariants[rec.BagVariant]or rec.BagVariant=='EclipseReliquary'or rec.BagVariant=='MechLimited'or rec.BagVariant=='VerityReliquary'then bad+=1 else
    stages[rec.Stage]=(stages[rec.Stage]or 0)+1;variants[rec.BagVariant]=(variants[rec.BagVariant]or 0)+1;sizes[rec.PackSize]=(sizes[rec.PackSize]or 0)+1
   end
   while #records>before2 do table.remove(records)end
  end
  local all=true;for _,s in ipairs(want)do if(stages[s]or 0)<math.floor(n/#want*.4)then all=false end end
  check(bad==0,'treadmill tier '..tier..': '..n..' random grants are all valid packs from its pool ('..table.concat(want,',')..')')
  check(#want==tier and all and rolledPacks>=rolls0+n,'tier '..tier..': the pool is the first '..tier..' treadmill biomes and every one of them comes up ('..table.concat(want,',')..')')
  pools[tier]=want
 end
 local top={};for _,s in ipairs(pools[#Config.TreadmillTiers])do top[s]=true end;local topAll=true;for st=1,7 do if not top[st]then topAll=false end end
 check(#pools[#Config.TreadmillTiers]==7 and topAll,'the top treadmill (Thunder Runner, Storm Peaks) rolls every biome pack, stages 1-7 (in machine order: '..table.concat(pools[#Config.TreadmillTiers],',')..')')
 Data:GetTreadmillData(A).Tier=7
 local stages,variants,sizes={},{},{}
 for _=1,1500 do
  local before2=#records;local rec=Data:GrantDailyPack(A,false)
  variants[rec.BagVariant]=(variants[rec.BagVariant]or 0)+1;sizes[rec.PackSize]=(sizes[rec.PackSize]or 0)+1;stages[rec.Stage]=(stages[rec.Stage]or 0)+1
  while #records>before2 do table.remove(records)end
 end
 local onlySix=true;for v in pairs(variants)do if not D.SeedPackVariants[v]then onlySix=false end end
 check(onlySix and(variants.Pack01 or 0)>500 and(variants.Pack01 or 0)<800 and(variants.Pack02 or 0)>300 and(variants.Pack03 or 0)>150 and(sizes[1]or 0)>500,'variants only Pack01-Pack06, Pack01 the most (bonus roll odds); size x1 most common (Pack01 '..(variants.Pack01 or 0)..', Pack02 '..(variants.Pack02 or 0)..', x1 '..(sizes[1]or 0)..')')
 -- the roll happens on the server at claim time: reading the state or publishing it never rolls
 local r0=rolledPacks;Data:PublishDaily(A);Data:DailyState(A);check(rolledPacks==r0,'reading the DAILY state rolls nothing (the pack is rolled when it is claimed)')
end
-- The odds ARE the bonus roll's: the same draws give the same pick except that the Void Pack (0.1%) is rolled again (a fixed seed; the Mech and Verity packs are not in that roll at all).
do
 local DP=server('DailyProgress');local stages=BonusRules.PoolStages(Config.TreadmillTiers,#Config.TreadmillTiers)
 math.randomseed(153);local N=60000;local U={};for i=1,2*N+3000 do U[i]=math.random()end -- (a fixed seed, all drawn before anything else uses math.random)
 local function from(start)local at=start;return function()at+=1;return U[at]end,function()return at end end
 local p,voids,mismatch,counts,stageCounts,extra=0,0,0,{},{},0
 for _=1,N do
  local da=from(p);local db,ib=from(p)
  local bonus=BonusRules.RollPack(stages,da);local daily=DP.PickPack(stages,db)
  if bonus.Variant==BonusRules.Void.Variant then voids+=1;if daily.Variant==BonusRules.Void.Variant or ib()<=p+2 then mismatch+=1 end;extra+=ib()-p-2
  elseif daily.Stage~=bonus.Stage or daily.Variant~=bonus.Variant or ib()~=p+2 then mismatch+=1 end
  p=ib();counts[daily.Variant]=(counts[daily.Variant]or 0)+1;stageCounts[daily.Stage]=(stageCounts[daily.Stage]or 0)+1
 end
 check(mismatch==0 and voids>20 and extra>0,'PickPack = the bonus roll (RollPack) on the same draws; the '..voids..' Void rolls in '..N..' were rolled again, nothing else differs')
 local odds=BonusRules.VariantOdds();local keep=1-odds.EclipseReliquary;local close=true
 for _,k in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'})do if math.abs((counts[k]or 0)/N-odds[k]/keep)>.008 then close=false end end
 check(close and counts.EclipseReliquary==nil and counts.MechLimited==nil and counts.VerityReliquary==nil,'the distribution over '..N..' rolls is the bonus roll odds without the Void ('..table.concat({counts.Pack01 or 0,counts.Pack02 or 0,counts.Pack03 or 0,counts.Pack04 or 0,counts.Pack05 or 0,counts.Pack06 or 0},', ')..')')
 local flat=true;for _,s in ipairs(stages)do if math.abs((stageCounts[s]or 0)/N-1/#stages)>.008 then flat=false end end
 check(flat,'every biome of the pool is equally likely (the bonus roll\'s pool pick)')
 local script={.1,.9995,.3,.1};local at=0;local pick=DP.PickPack(stages,function()at+=1;return script[at]end)
 check(pick and pick.Variant=='Pack01'and pick.Stage==stages[math.floor(.3*#stages)+1]and at==4,'a Void roll is rolled again (the second pair of draws is used)')
 check(DP.PickPack(stages,function()return .9995 end)==nil and DP.PickPack({},function()return .5 end)==nil,'(and with nothing but Void rolls, or an empty pool, there is no pack)')
end
-- A claim needs a saving profile (data.CanSave), for the login week and for quests alike.
do
 Data:GetPremium(A).Daily.Login={Step=0,Day=D.Day(R.clock)-1}
 local n0,g0=#records,#pendingGems(A)
 Data.CanSave[A]=false
 local c1,w1=Data:ClaimDailyLogin(A);local c2,w2=Data:ClaimDailyQuest(A,1)
 check(not c1 and tostring(w1):find('CAN SAVE',1,true)and #records==n0 and Data:DailyState(A).Login.Ready,'login claim refused while the profile cannot save: '..tostring(w1))
 check(not c2 and tostring(w2):find('CAN SAVE',1,true)and #pendingGems(A)==g0,'quest claim refused while the profile cannot save: '..tostring(w2))
 Data:GetPremium(A).Daily.Login={Step=4,Day=D.Day(R.clock)-1}
 local c3=Data:ClaimDailyLogin(A);check(not c3 and #pendingGems(A)==g0 and Data:DailyState(A).Login.Next==5,'and the Gem days too (day 5 stays open)')
 Data.CanSave[A]=true
 check((Data:ClaimDailyLogin(A))and pendingGems(A)[g0+1]==2,'with a saving profile the claim goes through (day 5: 2 Gems)')
end
-- A full Bag holds a pack claim (nothing lost, the claim stays): the seed pack days and the Void Pack day.
local fill={};local cap=Config.MaxSavedChests
local saved=table.clone(records);while #records<cap do records[#records+1]={Id='filler'..#records,Kind='Seed',SeedId='SunflowerSeed',ChestNumber=1}end
Data:GetPremium(A).Daily.Login={Step=2,Day=D.Day(R.clock)-1}
local fullSeed,fullSeedWhy=Data:ClaimDailyLogin(A)
check(not fullSeed and tostring(fullSeedWhy):find('MAKE ROOM',1,true)and Data:DailyState(A).Login.Ready and Data:DailyState(A).Login.Next==3 and #records==cap,'a full Bag: the day 3 seed pack waits (claim still open): '..tostring(fullSeedWhy))
Data:GetPremium(A).Daily.Login={Step=6,Day=D.Day(R.clock)-1}
local full,fullWhy=Data:ClaimDailyLogin(A)
check(not full and Data:DailyState(A).Login.Ready and Data:DailyState(A).Login.Next==7,'a full Bag: the Void Pack waits (claim still open): '..tostring(fullWhy))
Data:GetPremium(A).Daily.Login={Step=4,Day=D.Day(R.clock)-1}
check((Data:ClaimDailyLogin(A))and Data:DailyState(A).Login.Claimed==5,'but the Gem days still pay with a full Bag')
Data:GetPremium(A).Daily.Login={Step=6,Day=D.Day(R.clock)-1}
table.clear(records);for _,r in ipairs(saved)do records[#records+1]=r end
check((Data:ClaimDailyLogin(A)),'and the Void Pack can be claimed after making room')
-- 3. Daily quests (R153: each quest = ONE random pack; claiming all three = 2 Gems once).
nextDay();Data:PublishDaily(A);Data:GetTreadmillData(A).Tier=7
local st=Data:DailyState(A)
check(#st.Quests==3 and st.Quests[1].Text=='Steal 3 packs'and st.Quests[1].Progress==0 and st.Quests[1].Packs==1 and st.Quests[1].Gems==nil and st.Quests[1].Blocked==nil and st.QuestGemsGranted==0 and st.QuestGemCap==2,'today (one pack each, 0 of 2 Gems granted): '..st.Quests[1].Text..', '..st.Quests[2].Text..', '..st.Quests[3].Text)
check(st.Bonus and st.Bonus.Gems==2 and st.Bonus.Done==0 and st.Bonus.Total==3 and st.Bonus.Ready==false and st.Bonus.Claimed==false and st.Bonus.Blocked==false,'the ALL DONE bonus: 2 Gems, 0 / 3 claimed, not ready')
local claimEarly=Data:ClaimDailyQuest(A,1);check(not claimEarly,'an unfinished quest cannot be claimed')
local bonusEarly,bonusEarlyWhy=Data:ClaimDailyBonus(A);check(not bonusEarly and tostring(bonusEarlyWhy):find('CLAIM ALL',1,true),'and the bonus is not claimable before every quest is claimed: '..tostring(bonusEarlyWhy))
local Chests=server('ChestService');local synced=0
local fakeChests=setmetatable({PlayerData=Data,SyncTools=function()synced+=1 end},{__index=Chests})
local seed={Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion}
shown={}
for i=1,2 do Chests.Bank(fakeChests,A,seed)end
check(Data:DailyState(A).Quests[1].Progress==2 and A:GetAttribute('DailyQuestsReady')==0,'banking a stolen pack counts (2/3)')
Chests.Bank(fakeChests,A,seed)
check(Data:DailyState(A).Quests[1].Progress==3 and A:GetAttribute('DailyQuestsReady')==1,'3/3: the quest is ready to claim (badge 1)')
local done=false;for _,s in ipairs(shown)do if s.Text:find('QUEST DONE',1,true)and s.Text:find('Steal 3 packs',1,true)and s.Text:find('pack',1,true)and not s.Text:find('💎',1,true)then done=true end end
check(done,'a notice says the quest is done (and points at the pack, not Gems)')
Chests.Bank(fakeChests,A,seed);check(Data:DailyState(A).Quests[1].Progress==3,'progress stops at the goal')
local gemsBefore=#pendingGems(A);local bagBefore=#records;local rollsBefore=rolledPacks
local qok,qmsg=Data:ClaimDailyQuest(A,1)
local qpack=records[bagBefore+1]
check(qok and #records==bagBefore+1 and isDailyPack(qpack)and #pendingGems(A)==gemsBefore and A:GetAttribute('DailyQuestsReady')==0,'claiming gives exactly ONE random pack in the Bag and no Gems: '..tostring(qmsg))
check(rolledPacks==rollsBefore+1 and qpack.OddsVersion==Rules.OddsVersion and not qpack.PaidRandom and qpack.PackMutation=='None'and qmsg:find('RANDOM',1,true)and qmsg:find('bag',1,true),'one bonus-roll pick at claim time, a normal current-odds pack, the message says check the bag: '..tostring(qmsg))
check(Data:DailyState(A).QuestGemsGranted==0 and Data:DailyState(A).Quests[1].Claimed and Data:DailyState(A).Bonus.Done==1 and not Data:DailyState(A).Bonus.Ready,'no Gems counted (0 of 2), 1 / 3 claimed, the bonus not ready')
check(not Data:ClaimDailyQuest(A,1)and not Data:ClaimDailyQuest(A,9)and not Data:ClaimDailyQuest(A,'1')and #records==bagBefore+1,'no second claim, no bad index (and no second pack)')
-- The other hooks (each action counts where it really happens).
local calls={};local real=Data.QuestEvent
Data.QuestEvent=function(self,p,key,n)calls[#calls+1]=key..':'..tostring(n or 1);return real(self,p,key,n)end
local pack=Data:AddChest(A,seed);local opened,openWhy=Data:OpenSeedPack(A,pack.Id,function()return .5 end);if not opened then print('open failed:',openWhy)end
check(opened and table.find(calls,'Open:1'),'opening a pack counts for "Open 3 packs"')
local trackPack=Data:AddChest(A,seed);check(not table.find(calls,'Steal:1'),'packs that were not stolen (gifts, Void, bonus) do not count as steals')
Data.QuestEvent=nil
local src=W.B.PlayerDataService
check(src:find("self:TutorialEvent(player,'Plant')\n\tself:QuestEvent(player,'Plant',1)",1,true)and src:find("self:QuestEvent(player,'Harvest',1)",1,true)
 and src:find("self:QuestEvent(player,'Sell',1)",1,true)and src:find("self:QuestEvent(player,'Sell',count)",1,true),'planting, picking and selling (one or all) count too')
-- Progress on another quest key goes to whichever of today's quests uses it.
local daily=Data:GetPremium(A).Daily;local qs=Data:DailyState(A).Quests
local key2=qs[2].Key;for i=1,qs[2].Goal do Data:QuestEvent(A,key2,1)end
check(Data:DailyState(A).Quests[2].Progress==qs[2].Goal and A:GetAttribute('DailyQuestsReady')==1,'quest 2 ('..qs[2].Text..') completes the same way')
-- The daily Gem cap: the ALL DONE bonus is the only quest Gems, 2 a day.
do
 local q2ok=Data:ClaimDailyQuest(A,2)
 local key3=Data:DailyState(A).Quests[3];for i=1,key3.Goal do Data:QuestEvent(A,key3.Key,1)end
 check(q2ok and A:GetAttribute('DailyQuestsReady')==1 and Data:DailyState(A).Bonus.Done==2 and not Data:DailyState(A).Bonus.Ready,'quest 2 claimed (a pack, 2 / 3), quest 3 completes: still claimable, the bonus is not ready yet')
 local g0=#pendingGems(A);local b0=#records
 check(not Data:ClaimDailyBonus(A)and #pendingGems(A)==g0,'the bonus before the last quest is claimed: refused, no Gems')
 local q3ok,q3msg=Data:ClaimDailyQuest(A,3);local fin=Data:DailyState(A)
 check(q3ok and #records==b0+1 and isDailyPack(records[b0+1])and #pendingGems(A)==g0 and fin.Quests[1].Claimed and fin.Quests[2].Claimed and fin.Quests[3].Claimed,'the third quest: one more pack (exactly one each: 3 packs in all), still no Gems')
 check(fin.Bonus.Ready and fin.Bonus.Done==3 and not fin.Bonus.Claimed and fin.QuestGemsGranted==0 and A:GetAttribute('DailyQuestsReady')==1 and tostring(q3msg):find('💎2',1,true),'all three claimed: the ALL DONE bonus is ready (badge 1) and the last claim says so: '..tostring(q3msg))
 local premium=Data:GetPremium(A);local gemsBank=premium.Gems
 local bok,bmsg=Data:ClaimDailyBonus(A);local gm=pendingGems(A)
 check(bok and #gm==g0+1 and gm[g0+1]==2 and #records==b0+1,'ALL DONE pays 2 Gems (collectable Gems, like Index rewards) and no pack: '..tostring(bmsg))
 local after=Data:DailyState(A)
 check(after.Bonus.Claimed and not after.Bonus.Ready and after.QuestGemsGranted==2 and A:GetAttribute('DailyQuestsReady')==0,'once: 2 of 2 counted, badge 0')
 check(not Data:ClaimDailyBonus(A)and #pendingGems(A)==g0+1 and not Data:ClaimDailyQuest(A,3),'a second bonus claim pays nothing')
 local rv=Data:GetPremium(A).Daily.Quests
 check(rv.GemsGranted==2 and rv.Bonus==true and rv.RewardVersion==D.RewardVersion and rv.RewardVersion==153 and D.BonusBlocked({GemsGranted=2,Bonus=false}),'saved: GemsGranted 2, Bonus true, reward version 153; any Gems beyond the 2 would be blocked')
 -- R152 money auto-collect (SaleMoneyEffects claims every receipt by itself through CollectSaleCash): the 2 Gems arrive, once.
 local receipt=Data.Gardens[A].PendingSales[#Data.Gardens[A].PendingSales]
 check(receipt and receipt.Currency=='Gems'and receipt.Amount==2,'the bonus is one Gems receipt of 2 (what the R152 money effect picks up)')
 local credited=0;for i=1,receipt.Count do local r=Data:CollectSaleCash(A,receipt.Id,i);if r.Success then credited+=r.Amount or 0 end end
 for i=1,receipt.Count do Data:CollectSaleCash(A,receipt.Id,i)end -- (a retry credits nothing)
 check(credited==2 and premium.Gems==gemsBank+2 and #pendingGems(A)==g0,'collecting it (R152 auto-collect) puts exactly 2 Gems in the balance ('..gemsBank..' -> '..premium.Gems..')')
 check(Data:DailyState(A).QuestGemsGranted==2,'(the quest Gems of the day stay 2)')
end
-- R153: a day's accounting helpers
local function setQuests(t)t.Day=D.Day(R.clock);Data:GetPremium(A).Daily.Quests=t;Data:PublishDaily(A);return Data:DailyState(A)end
local function clearGems()Data.Gardens[A].PendingSales={}end
local function gemTotal()local n=0;for _,g in ipairs(pendingGems(A))do n+=g end;return n end
local function claimAll()local oks=0;for i=1,3 do if(Data:ClaimDailyQuest(A,i))then oks+=1 end end;local b=Data:ClaimDailyBonus(A);return oks,b end
-- A full Bag: the quest pack waits (nothing is lost, the quest stays claimable); the Gems of the bonus do not need room.
do
 clearGems();local s0=setQuests({RewardVersion=D.RewardVersion,Progress={3,3,3},Claimed={false,false,false}})
 local keep=table.clone(records);local cap=Config.MaxSavedChests
 while #records<cap do records[#records+1]={Id='qfull'..#records,Kind='Seed',SeedId='SunflowerSeed',ChestNumber=1}end
 local realLuck2=Data.RollPackLuck;local l0=0;Data.RollPackLuck=function(...)l0+=1;return realLuck2(...)end
 local refused,why1=0,nil
 for i=1,3 do local ok,why=Data:ClaimDailyQuest(A,i);if not ok and tostring(why):find('MAKE ROOM',1,true)then refused+=1;why1=why end end
 local s1=Data:DailyState(A);local q=Data:GetPremium(A).Daily.Quests
 check(refused==3 and #records==cap and s1.Quests[1].Progress==3 and not s1.Quests[1].Claimed and not s1.Quests[2].Claimed and not s1.Quests[3].Claimed and not q.Claimed[1]and not q.Claimed[2]and not q.Claimed[3],'a full Bag: all three quest claims say "'..tostring(why1)..'" and nothing is marked or lost')
 check(A:GetAttribute('DailyQuestsReady')==3 and #pendingGems(A)==0 and s1.QuestGemsGranted==0,'(all three stay claimable, badge 3, no Gems given)')
 check(l0==0,'(and the refused claims did not touch the size pity)')
 local l1=l0
 table.remove(records);local ok1,m1=Data:ClaimDailyQuest(A,1)
 check(ok1 and #records==cap and Data:DailyState(A).Quests[1].Claimed and l0==1,'one free slot: quest 1 claims its pack (and rolls its size pity once)')
 local ok2=Data:ClaimDailyQuest(A,2);check(not ok2 and not Data:DailyState(A).Quests[2].Claimed and Data:DailyState(A).Bonus.Done==1,'full again: quest 2 waits')
 table.remove(records);table.remove(records);check((Data:ClaimDailyQuest(A,2))and(Data:ClaimDailyQuest(A,3))and Data:DailyState(A).Bonus.Ready,'room made: the other two claim, the bonus is ready')
 while #records<cap do records[#records+1]={Id='qfull2'..#records,Kind='Seed',SeedId='SunflowerSeed',ChestNumber=1}end
 local bok=Data:ClaimDailyBonus(A);check(bok and gemTotal()==2,'the bonus Gems come with a full Bag')
 Data.RollPackLuck=nil
 table.clear(records);for _,r in ipairs(keep)do records[#records+1]=r end
end
-- R153 migration: a player mid-day with old-style claims keeps what they were paid, loses nothing and gets nothing twice; the 2-Gem cap counts what the old claims paid.
do
 local p0=#records
 -- R141 (the live R152 build): one quest claimed (2 Gems paid), the others finished and waiting
 clearGems();local m1=setQuests({RewardVersion=141,GemsGranted=2,Progress={3,3,3},Claimed={true,false,false}})
 check(m1.Quests[1].Claimed and not m1.Quests[2].Claimed and m1.QuestGemsGranted==2 and m1.Bonus.Blocked and not m1.Bonus.Ready and m1.Bonus.Done==1 and A:GetAttribute('DailyQuestsReady')==2,'R141 mid-day, 1 claim (2 Gems paid): it stays claimed, 2 packs are waiting (badge 2), no bonus left (the 2 Gems were paid)')
 local b0=#records;local c1=Data:ClaimDailyQuest(A,1)
 check(not c1 and #records==b0,'(the old claim gives no pack: it was paid in Gems)')
 check((Data:ClaimDailyQuest(A,2))and(Data:ClaimDailyQuest(A,3))and #records==b0+2 and gemTotal()==0,'the other two give a pack each, no Gems')
 local mb,mwhy=Data:ClaimDailyBonus(A);local m1b=Data:DailyState(A)
 check(not mb and tostring(mwhy):find('ALREADY',1,true)and gemTotal()==0 and m1b.QuestGemsGranted==2 and m1b.Bonus.Blocked and not m1b.Bonus.Ready and A:GetAttribute('DailyQuestsReady')==0,'all claimed: the bonus is refused (2 Gems already today), still 2 of 2: '..tostring(mwhy))
 local sv=Data:GetPremium(A).Daily.Quests;check(sv.RewardVersion==153 and sv.GemsGranted==2 and sv.Bonus==false,'the saved day is upgraded in place (version 153, GemsGranted 2 kept)')
 check(Data:DailyState(A).QuestGemsGranted==2 and not select(1,Data:ClaimDailyBonus(A)),'(reading it again changes nothing)')
 -- R141, nothing claimed yet: the new rules in full
 clearGems();local b1=#records;local m2=setQuests({RewardVersion=141,GemsGranted=0,Progress={3,3,3},Claimed={false,false,false}})
 check(not m2.Bonus.Blocked and A:GetAttribute('DailyQuestsReady')==3,'R141 mid-day, nothing claimed: three packs waiting')
 local oks,bok=claimAll();check(oks==3 and bok and #records==b1+3 and gemTotal()==2 and Data:DailyState(A).QuestGemsGranted==2,'3 packs and the 2-Gem bonus, once')
 -- R141, all three claimed (6 Gems paid)
 clearGems();local b2=#records;local m3=setQuests({RewardVersion=141,GemsGranted=6,Progress={3,3,3},Claimed={true,true,true}})
 local oks3,bok3=claimAll();check(oks3==0 and not bok3 and #records==b2 and gemTotal()==0 and m3.Bonus.Blocked and m3.QuestGemsGranted==6 and A:GetAttribute('DailyQuestsReady')==0,'R141, all 3 claimed (6 Gems paid): no pack, no bonus, nothing twice (6 counted)')
 -- R140 (no version): one claim = 5 Gems
 clearGems();local b3=#records;local m4=setQuests({Progress={3,3,3},Claimed={false,true,false}})
 local oks4,bok4=claimAll();check(m4.QuestGemsGranted==5 and m4.Bonus.Blocked and oks4==2 and not bok4 and #records==b3+2 and gemTotal()==0,'R140 (no version), 1 claim (5 Gems): 2 packs, no bonus')
 -- a rollback that stripped the stored total
 clearGems();local m5=setQuests({RewardVersion=141,GemsGranted='x',Progress={3,3,3},Claimed={true,false,false}})
 check(m5.QuestGemsGranted==2 and m5.Bonus.Blocked,'a missing / broken total falls back to claims x 2 for R141 (2): no bonus')
 local m6=setQuests({RewardVersion=141,GemsGranted=-3,Progress={3,3,3},Claimed={false,false,false}})
 check(m6.QuestGemsGranted==0 and not m6.Bonus.Blocked,'a negative total is ignored')
 local m7=setQuests({RewardVersion=141,GemsGranted=4,Progress={3,3,3},Claimed={true,false,false}})
 check(m7.QuestGemsGranted==4 and m7.Bonus.Blocked,'a stored total above the claims is kept (never lowered)')
 -- current version: a pack claim is 0 Gems; the bonus flag keeps its 2 even if the total was stripped
 local m8=setQuests({RewardVersion=D.RewardVersion,Progress={3,3,3},Claimed={true,true,true}})
 check(m8.QuestGemsGranted==0 and m8.Bonus.Ready and not m8.Bonus.Blocked,'current version: pack claims count 0 Gems (the bonus is ready)')
 local m9=setQuests({RewardVersion=D.RewardVersion,Bonus=true,GemsGranted='x',Progress={3,3,3},Claimed={true,true,true}})
 clearGems();check(m9.QuestGemsGranted==2 and m9.Bonus.Claimed and not m9.Bonus.Ready and not Data:ClaimDailyBonus(A)and gemTotal()==0,'the bonus flag alone keeps the 2 Gems counted: it cannot be claimed twice')
 -- the same day read twice, and a new UTC day starts from 0 again
 local nextQ=D.ReadQuests({Day=D.Day(R.clock),RewardVersion=141,GemsGranted=6,Progress={3,3,3},Claimed={true,true,true},Bonus=true},D.Day(R.clock)+1,501)
 check(nextQ.GemsGranted==0 and not nextQ.Claimed[1]and not nextQ.Bonus and not D.BonusBlocked(nextQ)and not D.BonusReady(nextQ),'a new UTC day starts at 0 of 2 again, no claims, no bonus')
end
-- R153: whatever state a day is in, finishing it never pays more than the 2 quest Gems (counting what older claims paid), and a pack only for a quest not claimed before.
do
 local rng=W.env.Random.new(1531);local worstExtra,bad,trials=0,0,400
 for t=1,trials do
  local version=({false,141,153})[rng:NextInteger(1,3)];local claimed={rng:NextInteger(0,1)==1,rng:NextInteger(0,1)==1,rng:NextInteger(0,1)==1}
  local state={Progress={3,3,3},Claimed=claimed}
  if version then state.RewardVersion=version end
  if rng:NextInteger(1,3)==1 then state.GemsGranted=rng:NextInteger(0,8)end
  if version==153 and rng:NextInteger(1,3)==1 then state.Bonus=true end
  local unclaimed=0;for i=1,3 do if not claimed[i]then unclaimed+=1 end end
  clearGems();while #records>40 do table.remove(records)end
  local init=setQuests(state).QuestGemsGranted;local b0=#records
  local oks,bok=claimAll();local oks2,bok2=claimAll() -- (twice: a second pass gives nothing)
  local paid=gemTotal();local final=Data:DailyState(A).QuestGemsGranted
  local fine=oks==unclaimed and oks2==0 and not bok2 and #records==b0+unclaimed and paid<=math.max(0,2-init)and final<=math.max(init,2)and final==init+paid and(paid==0 or paid==2)and(bok==(paid==2))
  if not fine then bad+=1;if bad<4 then print(('  state v%s claims %d,%d,%d total %s bonus %s -> init %d paid %d final %d packs %d/%d'):format(tostring(version),claimed[1]and 1 or 0,claimed[2]and 1 or 0,claimed[3]and 1 or 0,tostring(state.GemsGranted),tostring(state.Bonus),init,paid,final,#records-b0,unclaimed))end end
  worstExtra=math.max(worstExtra,paid)
 end
 check(bad==0 and worstExtra<=2,trials..' random mid-day states (R140 / R141 / current, any claims and totals): the server pays at most 2 quest Gems a day (counting old claims), one pack per unclaimed quest, nothing on a second pass')
end
Data:GetTreadmillData(A).Tier=1 -- (the rest of the suite is on the first treadmill)
-- 4. A new day: fresh quests, the login claim back.
nextDay();local new=Data:DailyState(A)
check(new.Quests[1].Progress==0 and not new.Quests[1].Claimed and new.Login.Ready,'the next day: new quests from 0 and a login claim')
check(new.ResetIn>0 and new.ResetIn<=86400,'the panel gets the time until midnight UTC')
-- 5. Saved with the profile; a broken save never blocks loading.
Data:QuestEvent(A,'Steal',2)
local save=Data:_buildSaveData(A)
check(save.Premium and type(save.Premium.Daily)=='table'and save.Premium.Daily.Login.Step>=1 and save.Premium.Daily.Quests.Progress[1]==2,'login week and quest progress are saved')
local P=server('PremiumProgress')
local decoded=P.Decode(save.Premium);check(decoded and decoded.Daily and decoded.Daily.Quests.Progress[1]==2,'and load back')
check(save.Premium.Daily.Quests.RewardVersion==D.RewardVersion and save.Premium.Daily.Quests.GemsGranted==0 and decoded.Daily.Quests.GemsGranted==0 and decoded.Daily.Quests.RewardVersion==D.RewardVersion,'the daily Gem accounting (RewardVersion, GemsGranted) is saved and loads back')
local broken=table.clone(save.Premium);broken.Daily={Login={Step=99,Day='x'},Quests='nope'}
local bd=P.Decode(broken);check(bd~=nil,'a broken Daily entry does not stop the profile loading')
Data:GetPremium(A).Daily={Login={Step=99},Quests={Day=D.Day(R.clock),Progress={50,-1,'x'},Claimed={false,false,false}}}
local fixed=Data:DailyState(A)
check(fixed.Login.Claimed==0 and fixed.Quests[1].Progress==0 and not fixed.Quests[1].Claimed and fixed.Quests[2].Progress==0 and not fixed.Quests[2].Claimed,'impossible values are reset (never paid out)')
local g99=#pendingGems(A);check(not Data:ClaimDailyQuest(A,1)and not Data:ClaimDailyQuest(A,2)and not Data:ClaimDailyQuest(A,3)and #pendingGems(A)==g99,'(and none of those quests can be claimed)')
-- The live code never undoes a claim marker: claimed flags survive bad progress numbers, still without any payout.
Data:GetPremium(A).Daily={Login={Step=99},Quests={Day=D.Day(R.clock),Progress={50,-1,'x'},Claimed={true,true,true}}}
local kept=Data:DailyState(A)
check(kept.Quests[1].Progress==0 and kept.Quests[2].Progress==0 and kept.Quests[1].Claimed and kept.Quests[2].Claimed and kept.Quests[3].Claimed,'claim markers are kept (a claim is never undone), progress is reset')
check(not Data:ClaimDailyQuest(A,1)and #pendingGems(A)==g99 and kept.QuestGemsGranted==15,'no payout from them, and R140-era claims count 5 each (15) toward the cap')
-- 6. Friend boost (R149: it speeds up the speed GAINED from treadmill training, not the walk speed).
local Social=server('SocialService');local social=Social.new(Data,Notes)
local friends={['501:502']=true,['501:503']=true}
local function fr(a,b)local x,y=math.min(a,b),math.max(a,b);return friends[x..':'..y]==true end
local B=makePlayer(502,'Ben');local C=makePlayer(503,'Cai')
for _,p in ipairs({A,B,C})do function p.IsFriendsWith(self,id)return fr(self.UserId,id)end end
shown={}
social:Setup(A);social:Setup(B);social:Setup(C);R.advance(.1)
check(A:GetAttribute('FriendsInServer')==2 and math.abs(A:GetAttribute('FriendSpeedBoost')-1.2)<1e-9,'Ava has 2 friends here: +20% speed gain')
check(B:GetAttribute('FriendsInServer')==1 and math.abs(B:GetAttribute('FriendSpeedBoost')-1.1)<1e-9 and C:GetAttribute('FriendsInServer')==1,'Ben and Cai (not friends with each other): +10% each')
local told=false;for _,s in ipairs(shown)do if s.P==A and s.Text:find('Cai is here',1,true)and s.Text:find('+20% speed gain',1,true)then told=true end end
check(told,'Ava is told when a friend joins (+20% speed gain)')
local stat=Data:GetOrCreateSpeedValue(A).Value
local base=Config.GetWalkSpeed(stat)
-- R149 (owner: "the speed boost should only apply to the speed gain, not how fast the player goes"): the friend boost no longer
-- touches the walk speed at all; it multiplies the speed points EARNED from treadmill training (and nothing else).
check(Config.GetPlayerWalkSpeed(A,stat)==base,('with 2 friends her walk speed is unchanged, x1 (%.2f -> %.2f)'):format(base,Config.GetPlayerWalkSpeed(A,stat)))
A:SetAttribute('FriendSpeedBoost',5);check(Config.GetPlayerWalkSpeed(A,stat)==base,'whatever the attribute says, the walk speed stays x1')
A:SetAttribute('FriendSpeedBoost',0/0);check(Config.GetPlayerWalkSpeed(A,stat)==base,'(a bad value changes nothing either)')
A:SetAttribute('FriendSpeedBoost',1.2)
check(math.abs(D.FriendMultiplier(9)-1.3)<1e-9 and D.FriendMultiplier(0)==1,'up to 3 friends count (+30%)')
check(not W.B.Config:find('FriendSpeedBoost',1,true)and not W.B.MovementGuard:find('FriendSpeedBoost',1,true),'Config and MovementGuard no longer read the friend boost')
-- MovementGuard: its speed budget comes from the plain walk speed (the same number with or without friends).
do
 local MG=server('MovementGuard');MG.Config=Config;MG.Data=Data;MG.Bases={TrainingSessions={}}
 local Motion=W.module('RunnerMotion')
 local mc=R.new('Model');local mh=R.new('Humanoid');mh.Parent=mc;local mr=R.new('Part');mr.Name='HumanoidRootPart';mr.Parent=mc;A.Character=mc
 local budgets={}
 for _,boost in ipairs({1,1.2,1.3})do A:SetAttribute('FriendSpeedBoost',boost);MG.Reset(A);budgets[#budgets+1]=MG.Records[A]and MG.Records[A].Budget end
 check(budgets[1]~=nil and budgets[1]==Motion.Burst(Motion.AtPosition(base,mr.Position))and budgets[2]==budgets[1]and budgets[3]==budgets[1],'MovementGuard budgets from the plain speed ('..tostring(budgets[1])..' = '..tostring(budgets[2])..' = '..tostring(budgets[3])..')')
 MG.Records[A]=nil;A.Character=nil;A:SetAttribute('FriendSpeedBoost',1.2)
end
-- The treadmill: BaseService:_updateTrainingPlayer (real) with a stand-in "self" around the real PlayerDataService / Config.
do
 local Base=server('BaseService')
 local char=R.new('Model');local hum=R.new('Humanoid');hum.Parent=char;hum.Health=100;hum.Sit=false;hum.PlatformStand=false;hum.Jump=false;hum.WalkSpeed=16
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Parent=char;root.Anchored=true
 local belt=R.new('Part');belt.Name='Belt';belt.Parent=R.new('Folder')
 local record={Treadmill=belt};local fired={}
 local stand=setmetatable({Config=Config,PlayerData=Data,TrainingSessions={},TrainingTime={},TrainingGainRemainder={},TrainingMustLeave={},TrainingCooldown={},
  BusyChecker=function()return false end,GetPlayerBase=function()return record end,SpeedGainRemote={FireAllClients=function(_,...)fired[#fired+1]={...}end}},{__index=Base})
 A.Character=char
 local mult=stand:GetTreadmillMultiplier(A);local per=Config.TrainingPointsPerSecond
 local function session()return{Character=char,Humanoid=hum,Root=root,Treadmill=belt,Record=record,Target=root.CFrame,BeltCFrame=belt.CFrame,Connections={},TutorialTrained=true,AnimationSpeed=Config.TreadmillAnimationSpeed}end
 -- Train for `seconds` in one-tick steps from a clean slate with the attribute set to `boost`; returns the points gained.
 local function train(seconds,boost,step)
  A:SetAttribute('FriendSpeedBoost',boost);Data:GetOrCreateSpeedValue(A).Value=stat
  stand.TrainingSessions[A]=session();stand.TrainingTime[A]=0;stand.TrainingGainRemainder[A]=0;fired={}
  local dt=step or Config.TrainingInterval;local n=math.floor(seconds/dt+.5)
  for _=1,n do stand:_updateTrainingPlayer(A,dt)end
  stand.TrainingSessions[A]=nil
  return tonumber(Data:GetOrCreateSpeedValue(A).Value)-tonumber(stat)
 end
 local function expect(f,seconds)return math.floor(per*mult*f*seconds/5+1e-9)*5 end
 local g0=train(60,1);check(g0>0 and g0==expect(1,60),('no friends: 60 s of training = %d points (x%.2f machine, %d/s base)'):format(g0,mult,per))
 local g1=train(60,D.FriendMultiplier(1));check(g1==expect(1.1,60),'1 friend: the gain is x1.1 ('..g1..' vs '..g0..')')
 local g2=train(60,D.FriendMultiplier(2));check(g2==expect(1.2,60),'2 friends: the gain is x1.2 ('..g2..')')
 local g3=train(60,D.FriendMultiplier(3));check(g3==expect(1.3,60),'3 friends: the gain is x1.3 ('..g3..')')
 check(g1>g0 and g2>g1 and g3>g2 and g3%5==0 and g2%5==0 and g1%5==0,'(each friend gains more, always whole multiples of 5)')
 check(train(60,5)==g3,'capped at +30% whatever the attribute says (5 -> the 3-friend gain)')
 check(train(60,0/0)==g0 and train(60,.2)==g0 and train(60,-3)==g0 and train(60,math.huge)==g3 and train(60,'x')==g0,'a bad / below-1 attribute gives no boost')
 -- The remainder is exact: one tick at a time and a different step size give the same total, and fractions carry over.
 check(train(60,1.1,1/60)==g1,'splitting the time into smaller steps never changes the total (+10%)')
 -- (R151: whole training steps, whatever Config.TrainingInterval is: 0.5 s was 3 steps of 1/6 s; with 1/5 s it is 0.6 s = 3 steps)
 do local dt=Config.TrainingInterval;local half,one=math.floor(.5/dt+.5)*dt,math.floor(1/dt+.5)*dt
  check(train(half,1.3)==expect(1.3,half)and train(one,1.3)==expect(1.3,one),'short sessions keep the fraction (about 0.5 s and 1 s at +30%)')end
 do
  stand.TrainingSessions[A]=session();stand.TrainingTime[A]=0;stand.TrainingGainRemainder[A]=0;A:SetAttribute('FriendSpeedBoost',1.3);Data:GetOrCreateSpeedValue(A).Value=stat;fired={}
  local bad=0
  for i=1,36 do stand:_updateTrainingPlayer(A,Config.TrainingInterval)
   local paid=tonumber(Data:GetOrCreateSpeedValue(A).Value)-tonumber(stat);if paid~=expect(1.3,i*Config.TrainingInterval)then bad+=1 end end
  check(bad==0 and #fired>0,'tick by tick (36 ticks at +30%) the running total is always the whole 5s of the exact amount; the remainder carries over ('..bad..' off)')
  local popupSum=0;for _,f in ipairs(fired)do popupSum+=f[2]end
  check(popupSum==expect(1.3,36*Config.TrainingInterval),'the gain popups add up to what was paid ('..popupSum..')')
  stand.TrainingSessions[A]=nil
 end
 -- The HUD number and the popups.
 stand.TrainingSessions[A]=session();stand.TrainingTime[A]=0;stand.TrainingGainRemainder[A]=0;A:SetAttribute('FriendSpeedBoost',1.2)
 stand:_updateTrainingPlayer(A,Config.TrainingInterval)
 check(math.abs(A:GetAttribute('TreadmillGainPerSecond')-per*mult*1.2)<1e-6,'TreadmillGainPerSecond (the HUD) includes the friend boost: '..tostring(A:GetAttribute('TreadmillGainPerSecond')))
 check(A:GetAttribute('TreadmillAnimationRate')==nil or A:GetAttribute('TreadmillAnimationRate')==Config.TreadmillAnimationSpeed,'the treadmill animation speed is not boosted')
 check(stand:_getTreadmillAnimationSpeed(mult*1.3)==stand:_getTreadmillAnimationSpeed(mult)and stand.TrainingSessions[A].AnimationSpeed==Config.TreadmillAnimationSpeed,'(same animation speed with and without friends)')
 A:SetAttribute('FriendSpeedBoost',1);stand:_updateTrainingPlayer(A,Config.TrainingInterval)
 check(math.abs(A:GetAttribute('TreadmillGainPerSecond')-per*mult)<1e-6,'the HUD number drops back when the friend leaves')
 stand.TrainingSessions[A]=nil;A:SetAttribute('TreadmillGainPerSecond',nil)
 -- The owner's `training` readout shows the friend part and the real total (read-only; it changes nothing).
 do
  A:SetAttribute('FriendSpeedBoost',1.3)
  local okc,text=server('OwnerUpdateCommands82').Execute({Map={MapRoot={}},Chase={Event81={}},Data=Data,Config=Config,Bases=stand},A,'training',{})
  check(okc==true and type(text)=='string'and text:find('friends x1.3',1,true)and text:find('total '..(per*mult*1.3)..'/s',1,true),'owner "training" shows friends x1.3 and the total '..(per*mult*1.3)..'/s ('..tostring(text)..')')
 end
 -- Purchases are not boosted.
 A:SetAttribute('FriendSpeedBoost',D.MaxMultiplier());Data:GetOrCreateSpeedValue(A).Value=stat
 local row=W.module('PremiumPricing').Find('SpeedSmall')
 check(Data:GrantPremiumBundle(A,'SpeedSmall')and tonumber(Data:GetOrCreateSpeedValue(A).Value)-tonumber(stat)==row.Amount,'a bought Speed bundle pays exactly its amount even with 3 friends here ('..row.Amount..')')
 -- Walk speed from the points earned is still the plain curve.
 local earned=Data:GetOrCreateSpeedValue(A).Value;check(Config.GetPlayerWalkSpeed(A,earned)==Config.GetWalkSpeed(earned),'walk speed after training = the speed curve at the points, x1')
 Data:GetOrCreateSpeedValue(A).Value=stat;A:SetAttribute('FriendSpeedBoost',1.2);A.Character=nil;A:SetAttribute('PhysicalWalkSpeed',nil)
end
social:Leaving(B);present[502]=nil
check(A:GetAttribute('FriendsInServer')==1 and math.abs(A:GetAttribute('FriendSpeedBoost')-1.1)<1e-9,'Ben leaves: Ava drops to +10%')
-- 7. "Your plant is ready".
local now=math.floor(R.clock)
local crop={Id='crop-1',SeedId='SunflowerSeed',ReadyAt=now+1800,MatureAt=now+1800,PlantedAt=now,PickedMask=0}
Data.Gardens[A].Plots={['1']={crop}}
msCalls=0
check(social:Schedule(A)==false and msCalls==0,'nothing is queued until the owner sets the MessageId (and no MemoryStore use)')
check(A:GetAttribute('PlantReadyAlerts')==false,'the client is told notifications are off (no opt-in prompt)')
folder.SocialService:SetAttribute('MessageId','5dd7024b-68e3-ac4d-8232-4217f86ca244')
local value=social:Schedule(A);R.advance(.1)
local entry=maps.PlantReady140 and maps.PlantReady140.Items['501']
check(entry and entry.Value.At==now+1800 and entry.Sort==now+1800,'leaving with a plant growing queues its ready time')
check(entry and entry.Value.Plant==W.module('GardenDisplayNames').Plant('SunflowerSeed',Config.GardenPlants.SunflowerSeed.Name),'with the plant name ('..tostring(entry and entry.Value.Plant)..')')
present[501]=nil -- Ava is offline now
R.clock=now+600;check(social:Deliver()==0 and #sentRequests==0,'nothing is sent before it is ready')
local social2=Social.new(Data,Notes) -- a second server sharing the queue
R.clock=now+1801
local s1=social:Deliver();local s2=social2:Deliver()
check(s1+s2==1 and #sentRequests==1,'when ready, exactly one server sends it ('..s1..' + '..s2..')')
local req=sentRequests[1]
check(req and req.Url=='https://apis.roblox.com/cloud/v2/users/501/notifications'and req.Method=='POST','POST to the Open Cloud user notifications endpoint')
check(req and req.Headers['x-api-key'].Secret=='PlantReadyKey'and req.Headers['Content-Type']=='application/json','the API key comes from the experience secret PlantReadyKey')
local body=req and req.Body
check(body and body.payload.messageId=='5dd7024b-68e3-ac4d-8232-4217f86ca244'and body.payload.type=='MOMENT'and body.payload.parameters.plantName.stringValue==entry.Value.Plant and body.source.universe=='universes/'..tostring(W.env.game.GameId),'the payload: message id, MOMENT, {plantName}, the universe')
check(maps.PlantReady140.Items['501']==nil,'the entry is removed after sending')
-- Cooldown: at most one per 12 h.
present[501]=A;crop.ReadyAt=R.clock+900;crop.MatureAt=R.clock+900;social:Schedule(A);R.advance(.1);present[501]=nil
R.clock+=901;check(social:Deliver()==0 and #sentRequests==1,'a second one within 12 h is skipped')
-- Coming back cancels it.
present[501]=A;crop.ReadyAt=R.clock+86400;crop.MatureAt=crop.ReadyAt;social:Schedule(A);R.advance(.1)
check(maps.PlantReady140.Items['501']~=nil,'(queued again)')
social:Setup(A);R.advance(.1)
check(maps.PlantReady140.Items['501']==nil,'rejoining removes it (no notification while playing)')
check(A:GetAttribute('PlantReadyAlerts')==true,'with the MessageId set, the client may ask players to opt in')
-- Too soon / nothing growing.
crop.ReadyAt=R.clock+60;crop.MatureAt=crop.ReadyAt;check(social:Schedule(A)==false,'a plant ready within 5 minutes: no notification')
Data.Gardens[A].Plots={};check(social:Schedule(A)==false,'nothing growing: nothing queued')
-- A failed request warns and does not crash.
httpOk=false;local warns=W.warns or 0;check(social:Send(501,'Test')==false and(W.warns or 0)>warns,'a failed request is logged, not fatal')
httpOk=true
-- 8. The day rollover for players who stay online.
present[501]=A
Data:GetPremium(A).Daily.Login={Step=2,Day=D.Day(R.clock)};Data:PublishDaily(A)
check(A:GetAttribute('DailyLoginReady')==false,'(claimed today)')
social.Day=D.Day(R.clock);R.clock+=86400;social:Step(math.floor(R.clock))
check(A:GetAttribute('DailyLoginReady')==true and A:GetAttribute('DailyDay')==D.Day(R.clock),'at midnight UTC the badge lights up for online players')
-- 9. The remote (PremiumService) and the owner command.
local ps=W.B.PremiumService
check(ps:find("if action=='Daily'then",1,true)and ps:find("value=='ClaimLogin'",1,true)and ps:find('chests:SyncTools(p)',1,true)and ps:find('data.CanSave[p]',1,true)and ps:find("value=='ClaimBonus'",1,true)and ps:find('data:ClaimDailyBonus(p)',1,true),'PremiumRequest Daily: State / ClaimLogin (hotbar refresh for the Mech pack), ClaimBonus (the ALL DONE Gems) / quest claims, only with a saving profile')
local Owner=server('OwnerUpdateCommands82')
local ctx={Data=Data,Chests=fakeChests,Chase={IsPlayerBusy=function()return false end},Map={MapRoot=R.new('Folder')},Config=Config}
local okc,out=Owner.Execute(ctx,A,'daily',{})
check(okc and out:find('login day',1,true),'daily: '..tostring(out))
Owner.Execute(ctx,A,'daily',{'done'});check(A:GetAttribute('DailyQuestsReady')>=1,'daily done finishes today\'s quests')
Owner.Execute(ctx,A,'daily',{'next'});local nx=Data:DailyState(A);check(not nx.Quests[1].Claimed and nx.Bonus.Claimed==false and nx.QuestGemsGranted==0 and nx.Bonus.Done==0,'daily next: a fresh day (quests, bonus and the Gem count start over)')
Owner.Execute(ctx,A,'daily',{'week'});local wk=Data:DailyState(A).Login;check(wk.Ready and wk.Next==7,'daily week: the next claim is the Void Pack')
Owner.Execute(ctx,A,'daily',{'reset'});local rs=Data:DailyState(A).Login;check(rs.Ready and rs.Next==1,'daily reset')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
