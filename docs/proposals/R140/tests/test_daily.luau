--!nocheck
-- R140 (owner: "daily login rewards, per week, at the end players get 1 mech pack", "daily quests like steal 3 packs,
-- that quest gives 5 gems", "speed boost for friends in the server", "the your plant is ready thing"), updated for the
-- owner's live numbers (R141 DailyRewards/DailyProgress: login days 1-4 = a random seed pack, day 5 = 2 Gems, day 6 =
-- 3 Gems, day 7 = 1 Mech pack; quests pay 2 Gems each, capped at 6 Gems a day, R140-era claims count 5): the real
-- PlayerDataService (DailyProgress, AddChest, GrantMechPacks, OpenSeedPack, save rows), ChestService.Bank,
-- SocialService (friend boost, the shared plant-ready queue, the day rollover), Config.GetPlayerWalkSpeed and the
-- owner's daily command. MemoryStore and the Open Cloud call are faked; mock time = os.time.
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
check(#D.Login==7 and D.Login[7].MechPack==1,'a week of 7 login rewards, day 7 = 1 Mech pack')
check(D.Login[1].SeedPack==1 and D.Login[2].SeedPack==1 and D.Login[3].SeedPack==1 and D.Login[4].SeedPack==1,'days 1-4 = a random seed pack each')
check(D.Login[5].Gems==2 and D.Login[6].Gems==3 and D.Login[5].SeedPack==nil and D.Login[6].MechPack==nil,'day 5 = 2 Gems, day 6 = 3 Gems')
local stagesOk=#D.SeedPackStages==7;for i=1,7 do if D.SeedPackStages[i]~=i then stagesOk=false end end
local variantsOk=true;for _,v in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'})do if D.SeedPackVariants[v]~=true then variantsOk=false end end
for k in pairs(D.SeedPackVariants)do if not table.find(Rules.VariantOrder,k)then variantsOk=false end end
check(stagesOk and variantsOk,'the seed pack pool: stages 1-7, variants Pack01-Pack06 only')
check(D.RewardText(D.Login[1])=='RANDOM PACK'and D.RewardText(D.Login[5])=='+2'and D.RewardText(D.Login[6])=='+3'and D.RewardText(D.Login[7])=='MECH PACK','card texts: RANDOM PACK, +2, +3, MECH PACK')
local k1,k2=D.QuestKeys(501,D.Day(R.clock)),D.QuestKeys(501,D.Day(R.clock)+1)
check(#k1==3 and k1[1]==1 and D.Quests[1].Key=='Steal'and D.Quests[1].Goal==3 and D.QuestGems==2,'3 quests a day, the first is always "Steal 3 packs", 2 Gems each')
check(D.QuestGemCap==6 and D.QuestsPerDay*D.QuestGems==D.QuestGemCap,'at most 6 Gems a day from quests (three 2-Gem quests fit exactly)')
check(k1[2]~=k1[3]and k1[2]~=1 and k1[3]~=1,'the other two are different quests')
local same=true;for i=1,3 do if D.QuestKeys(501,D.Day(R.clock))[i]~=k1[i]then same=false end end
check(same,'the same player gets the same quests all day')
local varied=false;for d=1,10 do local k=D.QuestKeys(501,D.Day(R.clock)+d);if k[2]~=k1[2]or k[3]~=k1[3]then varied=true end end
check(varied,'and other quests on other days')
-- 2. Login week (live: days 1-4 = a random seed pack, day 5 = 2 Gems, day 6 = 3 Gems, day 7 = 1 Mech pack).
local records=Data:GetChestRecords(A)
local addCalls,lastAdd,luckCalls=0,nil,0
local realAdd,realLuck=Data.AddChest,Data.RollPackLuck
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
check(isDailyPack(rec1),'the pack: stage 1-7, a Pack01-06 variant, a rolled size, no mutation, not a paid item ('..tostring(rec1 and rec1.Stage)..', '..tostring(rec1 and rec1.BagVariant)..', x'..tostring(rec1 and rec1.PackSize)..')')
check(addCalls==1 and lastAdd.Options==nil and luckCalls==0 and lastAdd.Chest.PackSize==rec1.PackSize,'no luck / pity roll: AddChest gets no options and the size is the plain roll')
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
local before=#Data:GetChestRecords(A)
local o7,m7,i7=Data:ClaimDailyLogin(A)
local mech;for _,r in ipairs(Data:GetChestRecords(A))do if r.BagVariant=='MechLimited'then mech=r end end
check(o7 and i7.Day==7 and #Data:GetChestRecords(A)==before+1 and mech and mech.Stage==8,'day 7: a Mech pack in the Bag ('..tostring(m7)..')')
check(mech and mech.PaidRandom==false,'a free pack (not a paid random item), so it opens for everyone')
nextDay();local o8,_,i8=Data:ClaimDailyLogin(A)
check(o8 and i8.Day==1 and isDailyPack(records[#records]),'the next day the week starts again at day 1 (a random seed pack)')
nextDay(3);local o9,_,i9=Data:ClaimDailyLogin(A)
check(o9 and i9.Day==2,'missing days only pauses the week (day 2 after a 2-day gap)')
Data.AddChest=nil;Data.RollPackLuck=nil
-- The random pool over many grants: every stage 1-7, only Pack01-06, only real pack sizes, never luck / paid / mutated.
do
 local stages,variants,sizes={},{},{};local bad=0;local n=700
 for _=1,n do
  local before2=#records;local rec,whyNot=Data:GrantDailyPack(A,false)
  if not isDailyPack(rec)or #records~=before2+1 then bad+=1 else
   stages[rec.Stage]=(stages[rec.Stage]or 0)+1;variants[rec.BagVariant]=(variants[rec.BagVariant]or 0)+1;sizes[rec.PackSize]=(sizes[rec.PackSize]or 0)+1
  end
  while #records>before2 do table.remove(records)end
 end
 local allStages=true;for st=1,7 do if(stages[st]or 0)<40 then allStages=false end end
 local onlySix=true;for v in pairs(variants)do if not D.SeedPackVariants[v]then onlySix=false end end
 check(bad==0,'700 random grants are all valid daily packs')
 check(allStages,'every stage 1-7 comes up (about 100 each: '..table.concat({stages[1]or 0,stages[2]or 0,stages[3]or 0,stages[4]or 0,stages[5]or 0,stages[6]or 0,stages[7]or 0},', ')..')')
 check(onlySix and (variants.Pack01 or 0)>250 and (variants.Pack01 or 0)<450 and (variants.Pack02 or 0)>100 and (variants.Pack03 or 0)>40 and(sizes[1]or 0)>400,'variants only Pack01-06 with Pack01 about half; size x1 most common (Pack01 '..(variants.Pack01 or 0)..', Pack02 '..(variants.Pack02 or 0)..', x1 '..(sizes[1]or 0)..')')
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
-- A full Bag holds a pack claim (nothing lost, the claim stays): the seed pack days and the Mech pack day.
local fill={};local cap=Config.MaxSavedChests
local saved=table.clone(records);while #records<cap do records[#records+1]={Id='filler'..#records,Kind='Seed',SeedId='SunflowerSeed',ChestNumber=1}end
Data:GetPremium(A).Daily.Login={Step=2,Day=D.Day(R.clock)-1}
local fullSeed,fullSeedWhy=Data:ClaimDailyLogin(A)
check(not fullSeed and tostring(fullSeedWhy):find('MAKE ROOM',1,true)and Data:DailyState(A).Login.Ready and Data:DailyState(A).Login.Next==3 and #records==cap,'a full Bag: the day 3 seed pack waits (claim still open): '..tostring(fullSeedWhy))
Data:GetPremium(A).Daily.Login={Step=6,Day=D.Day(R.clock)-1}
local full,fullWhy=Data:ClaimDailyLogin(A)
check(not full and Data:DailyState(A).Login.Ready and Data:DailyState(A).Login.Next==7,'a full Bag: the Mech pack waits (claim still open): '..tostring(fullWhy))
Data:GetPremium(A).Daily.Login={Step=4,Day=D.Day(R.clock)-1}
check((Data:ClaimDailyLogin(A))and Data:DailyState(A).Login.Claimed==5,'but the Gem days still pay with a full Bag')
Data:GetPremium(A).Daily.Login={Step=6,Day=D.Day(R.clock)-1}
table.clear(records);for _,r in ipairs(saved)do records[#records+1]=r end
check((Data:ClaimDailyLogin(A)),'and the Mech pack can be claimed after making room')
-- 3. Daily quests.
nextDay();Data:PublishDaily(A)
local st=Data:DailyState(A)
check(#st.Quests==3 and st.Quests[1].Text=='Steal 3 packs'and st.Quests[1].Progress==0 and st.Quests[1].Gems==2 and not st.Quests[1].Blocked and st.QuestGemsGranted==0 and st.QuestGemCap==6,'today (2 Gems each, 0 of 6 granted): '..st.Quests[1].Text..', '..st.Quests[2].Text..', '..st.Quests[3].Text)
local claimEarly=Data:ClaimDailyQuest(A,1);check(not claimEarly,'an unfinished quest cannot be claimed')
local Chests=server('ChestService');local synced=0
local fakeChests=setmetatable({PlayerData=Data,SyncTools=function()synced+=1 end},{__index=Chests})
local seed={Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion}
shown={}
for i=1,2 do Chests.Bank(fakeChests,A,seed)end
check(Data:DailyState(A).Quests[1].Progress==2 and A:GetAttribute('DailyQuestsReady')==0,'banking a stolen pack counts (2/3)')
Chests.Bank(fakeChests,A,seed)
check(Data:DailyState(A).Quests[1].Progress==3 and A:GetAttribute('DailyQuestsReady')==1,'3/3: the quest is ready to claim (badge 1)')
local done=false;for _,s in ipairs(shown)do if s.Text:find('QUEST DONE',1,true)and s.Text:find('Steal 3 packs',1,true)then done=true end end
check(done,'a notice says the quest is done')
Chests.Bank(fakeChests,A,seed);check(Data:DailyState(A).Quests[1].Progress==3,'progress stops at the goal')
local gemsBefore=#pendingGems(A)
local qok=Data:ClaimDailyQuest(A,1)
check(qok and #pendingGems(A)==gemsBefore+1 and pendingGems(A)[#pendingGems(A)]==2 and A:GetAttribute('DailyQuestsReady')==0,'claiming pays 2 Gems')
check(Data:DailyState(A).QuestGemsGranted==2 and Data:DailyState(A).Quests[1].Claimed,'and counts toward the daily cap (2 of 6)')
check(not Data:ClaimDailyQuest(A,1)and not Data:ClaimDailyQuest(A,9)and not Data:ClaimDailyQuest(A,'1'),'no second claim, no bad index')
-- The other hooks (each action counts where it really happens).
local calls={};local real=Data.QuestEvent
Data.QuestEvent=function(self,p,key,n)calls[#calls+1]=key..':'..tostring(n or 1);return real(self,p,key,n)end
local pack=Data:AddChest(A,seed);local opened,openWhy=Data:OpenSeedPack(A,pack.Id,function()return .5 end);if not opened then print('open failed:',openWhy)end
check(opened and table.find(calls,'Open:1'),'opening a pack counts for "Open 3 packs"')
local trackPack=Data:AddChest(A,seed);check(not table.find(calls,'Steal:1'),'packs that were not stolen (gifts, Mech, bonus) do not count as steals')
Data.QuestEvent=nil
local src=W.B.PlayerDataService
check(src:find("self:TutorialEvent(player,'Plant')\n\tself:QuestEvent(player,'Plant',1)",1,true)and src:find("self:QuestEvent(player,'Harvest',1)",1,true)
 and src:find("self:QuestEvent(player,'Sell',1)",1,true)and src:find("self:QuestEvent(player,'Sell',count)",1,true),'planting, picking and selling (one or all) count too')
-- Progress on another quest key goes to whichever of today's quests uses it.
local daily=Data:GetPremium(A).Daily;local qs=Data:DailyState(A).Quests
local key2=qs[2].Key;for i=1,qs[2].Goal do Data:QuestEvent(A,key2,1)end
check(Data:DailyState(A).Quests[2].Progress==qs[2].Goal and A:GetAttribute('DailyQuestsReady')==1,'quest 2 ('..qs[2].Text..') completes the same way')
-- The daily Gem cap: 6 Gems = exactly three of the 2-Gem quests.
do
 local q2ok=Data:ClaimDailyQuest(A,2)
 local key3=Data:DailyState(A).Quests[3];for i=1,key3.Goal do Data:QuestEvent(A,key3.Key,1)end
 check(q2ok and A:GetAttribute('DailyQuestsReady')==1,'quest 2 claimed (4 of 6), quest 3 completes: still claimable')
 local g0=#pendingGems(A);local q3ok=Data:ClaimDailyQuest(A,3);local fin=Data:DailyState(A)
 check(q3ok and #pendingGems(A)==g0+1 and pendingGems(A)[g0+1]==2 and fin.QuestGemsGranted==6 and fin.Quests[1].Claimed and fin.Quests[2].Claimed and fin.Quests[3].Claimed,'all three quests pay 2 Gems each: 6 of 6 Gems today')
 check(not fin.Quests[1].Blocked and not fin.Quests[2].Blocked and not fin.Quests[3].Blocked and A:GetAttribute('DailyQuestsReady')==0,'(claimed quests are DONE, not "limit reached")')
 local rv=Data:GetPremium(A).Daily.Quests
 check(rv.GemsGranted==6 and rv.RewardVersion==D.RewardVersion and D.QuestBlocked({GemsGranted=6}),'the saved state carries GemsGranted 6 and the reward version; one more claim would be blocked')
 -- R140-era saves: no reward version, every claimed quest was worth 5 Gems (one claim already uses 5 of the 6).
 local day=D.Day(R.clock)
 local function setQuests(t)t.Day=day;Data:GetPremium(A).Daily.Quests=t;Data:PublishDaily(A);return Data:DailyState(A)end
 local legacy=setQuests({Progress={3,3,3},Claimed={true,false,false}})
 check(legacy.QuestGemsGranted==5 and legacy.Quests[1].Claimed and not legacy.Quests[1].Blocked and legacy.Quests[2].Blocked and legacy.Quests[3].Blocked,'one R140 claim counts 5 Gems: the other quests are blocked ("DAILY LIMIT")')
 check(A:GetAttribute('DailyQuestsReady')==0,'and the badge does not count blocked quests')
 local g1=#pendingGems(A);local bq,bwhy=Data:ClaimDailyQuest(A,2)
 check(not bq and tostring(bwhy):find('LIMIT',1,true)and #pendingGems(A)==g1 and not Data:GetPremium(A).Daily.Quests.Claimed[2],'a blocked claim pays nothing and is not marked: '..tostring(bwhy))
 check(Data:GetPremium(A).Daily.Quests.GemsGranted==5 and Data:GetPremium(A).Daily.Quests.RewardVersion==D.RewardVersion,'the state is upgraded in place (GemsGranted 5, current reward version)')
 local two=setQuests({Progress={3,3,3},Claimed={true,true,false}});check(two.QuestGemsGranted==10 and two.Quests[3].Blocked,'two R140 claims: 10 Gems counted, nothing more today')
 -- Current-version saves count 2 per claim (and keep a larger stored total).
 local cur=setQuests({RewardVersion=D.RewardVersion,Progress={3,3,3},Claimed={true,false,false}})
 check(cur.QuestGemsGranted==2 and not cur.Quests[2].Blocked and A:GetAttribute('DailyQuestsReady')==2,'a current-version claim counts 2: two more quests are claimable')
 local c2ok=Data:ClaimDailyQuest(A,2);local c3ok=Data:ClaimDailyQuest(A,3)
 check(c2ok and c3ok and Data:DailyState(A).QuestGemsGranted==6,'and both pay (6 of 6)')
 local stored=setQuests({RewardVersion=D.RewardVersion,GemsGranted=5,Progress={3,3,3},Claimed={true,false,false}})
 check(stored.QuestGemsGranted==5 and stored.Quests[2].Blocked,'a stored total above the claims is kept (never lowered)')
 local stripped=setQuests({RewardVersion=D.RewardVersion,GemsGranted='x',Progress={3,3,3},Claimed={true,true,false}})
 check(stripped.QuestGemsGranted==4 and not stripped.Quests[3].Blocked,'a missing / broken total falls back to claims x 2 (4)')
 local bogus=setQuests({RewardVersion=D.RewardVersion,GemsGranted=-3,Progress={3,3,3},Claimed={false,false,false}})
 check(bogus.QuestGemsGranted==0 and not bogus.Quests[1].Blocked,'a negative total is ignored')
 local nextQ=D.ReadQuests({Day=day,Progress={3,3,3},Claimed={true,true,true}},day+1,501)
 check(nextQ.GemsGranted==0 and not nextQ.Claimed[1]and not D.QuestBlocked(nextQ),'a new UTC day starts at 0 of 6 again')
end
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
-- 6. Friend boost.
local Social=server('SocialService');local social=Social.new(Data,Notes)
local friends={['501:502']=true,['501:503']=true}
local function fr(a,b)local x,y=math.min(a,b),math.max(a,b);return friends[x..':'..y]==true end
local B=makePlayer(502,'Ben');local C=makePlayer(503,'Cai')
for _,p in ipairs({A,B,C})do function p.IsFriendsWith(self,id)return fr(self.UserId,id)end end
shown={}
social:Setup(A);social:Setup(B);social:Setup(C);R.advance(.1)
check(A:GetAttribute('FriendsInServer')==2 and math.abs(A:GetAttribute('FriendSpeedBoost')-1.2)<1e-9,'Ava has 2 friends here: +20% speed')
check(B:GetAttribute('FriendsInServer')==1 and math.abs(B:GetAttribute('FriendSpeedBoost')-1.1)<1e-9 and C:GetAttribute('FriendsInServer')==1,'Ben and Cai (not friends with each other): +10% each')
local told=false;for _,s in ipairs(shown)do if s.P==A and s.Text:find('Cai is here',1,true)and s.Text:find('+20%',1,true)then told=true end end
check(told,'Ava is told when a friend joins (+20%)')
local stat=Data:GetOrCreateSpeedValue(A).Value
local base=Config.GetWalkSpeed(stat)
check(math.abs(Config.GetPlayerWalkSpeed(A,stat)-base*1.2)<1e-6,('her walk speed is 1.2x (%.2f -> %.2f)'):format(base,Config.GetPlayerWalkSpeed(A,stat)))
A:SetAttribute('FriendSpeedBoost',5);check(math.abs(Config.GetPlayerWalkSpeed(A,stat)-base*D.MaxMultiplier())<1e-6,'never more than +30% whatever the attribute says')
A:SetAttribute('FriendSpeedBoost',0/0);check(Config.GetPlayerWalkSpeed(A,stat)==base,'a bad value means no boost')
check(math.abs(D.FriendMultiplier(9)-1.3)<1e-9 and D.FriendMultiplier(0)==1,'up to 3 friends count (+30%)')
local mg=W.B.MovementGuard;check(mg:find('GetPlayerWalkSpeed',1,true),'the movement guard uses the same boosted speed (no false alarms)')
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
check(ps:find("if action=='Daily'then",1,true)and ps:find("value=='ClaimLogin'",1,true)and ps:find('chests:SyncTools(p)',1,true)and ps:find('data.CanSave[p]',1,true),'PremiumRequest Daily: State / ClaimLogin (hotbar refresh for the Mech pack) / quest claims, only with a saving profile')
local Owner=server('OwnerUpdateCommands82')
local ctx={Data=Data,Chests=fakeChests,Chase={IsPlayerBusy=function()return false end},Map={MapRoot=R.new('Folder')},Config=Config}
local okc,out=Owner.Execute(ctx,A,'daily',{})
check(okc and out:find('login day',1,true),'daily: '..tostring(out))
Owner.Execute(ctx,A,'daily',{'done'});check(A:GetAttribute('DailyQuestsReady')>=1,'daily done finishes today\'s quests')
Owner.Execute(ctx,A,'daily',{'week'});local wk=Data:DailyState(A).Login;check(wk.Ready and wk.Next==7,'daily week: the next claim is the Mech pack')
Owner.Execute(ctx,A,'daily',{'reset'});local rs=Data:DailyState(A).Login;check(rs.Ready and rs.Next==1,'daily reset')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
