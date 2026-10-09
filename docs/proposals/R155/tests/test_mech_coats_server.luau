--!nocheck
-- R155 Mech pack coats (owner: "We can implement 1C", docs/proposals/R153/mech_pack.md section 2) + the limited event's end (owner: the shop card's "LIMITED TIME!" gets a real end,
-- the same as Verity's event). The SERVER half on the Roblox mock with the REAL PlayerDataService, PremiumProgress, PremiumService, PurchaseAnnouncer, GamePassService, MechCatalog,
-- SeedPackRules, PlantRules, BalanceRules, OwnerTestPacks / RarePackTests:
--  1. the purchase roll   every BOUGHT Mech pack (gems or Robux, 1 / 5 / 10) rolls its own coat with the world packs' own constants (SeedPackRules.PackMutations: None 95 / Gold 4.5 /
--                         Diamond .5): one draw per pack, in order, each pack on its own; the rates over 30,000 packs and the spread of coats inside a 10-pack are within tolerance and the coat
--                         does not depend on the pack's size; a FREE Mech pack (paid == false) and a /test rarepacks Mech pack stay plain
--  2. saved data          the coat is the record's existing PackMutation (saved, loaded, gifted like any pack's); no new key in the saved row, ProfileVersion still 22; an old Mech pack row
--                         (plain, or with no PackMutation at all) loads plain; the pack's name / label carries the coat
--  3. the reveal          opening a coated Mech pack gives a seed of the same coat (OpenSeedPack's reward record, the Bag's seed group, the saved seed row), for every Mech seed
--  4. plant and fruit     the seed's plant is Gold / Diamond (PlantRules.NewCrop), its fruit inherit the coat at the usual 20% and a coated fruit is worth x3 (Gold) / x6 (Diamond)
--  5. the notice          the "Bought" notice (one line, one PurchaseDone) names the coats of a coated purchase (gems and Robux receipts) and is the plain line when nothing is coated
--  6. the event's end     MechCatalog.OnSale / TimerText at a few times and the switch at EndsAt; State / buttons; a gem purchase after the end is refused with nothing charged and nothing granted;
--                         a Robux prompt after the end is refused (no prompt); a receipt for a prompt opened BEFORE the end is granted normally AFTER it; a pack the player owns still opens
local W=require('./world');local R=W.R;local E=require('./announce_env')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=tol end
local RS=W.RS
-- A scheduler where task.wait really yields (PassGiftService runs a `while task.wait(15)` loop, which would never end on the mock's instant wait).
local sleeping={}
local task2=table.clone(R.task)
task2.spawn=function(f,...)local co=type(f)=='thread'and f or coroutine.create(f);local ok,e=coroutine.resume(co,...);if not ok then error(debug.traceback(co,tostring(e)),0)end;return co end
task2.wait=function(t)
 t=t or 0
 if not coroutine.isyieldable()then return t end
 table.insert(sleeping,{At=R.clock+t,Co=coroutine.running()});coroutine.yield();return t
end
W.env.task=task2
-- Roblox's Random.new() is seeded from the clock, so two generators never repeat each other; the mock's is seeded 1 every time (the same stream twice). A Lehmer generator seeded
-- from a counter gives every Random.new() its own stream, the way the engine does (modules take Random from this table when they load).
local streams=0
W.env.Random={new=function(seed)
 streams+=1;local s=((seed or streams*7919+104729)*48271)%2147483647;if s==0 then s=1 end
 local function nextUnit()s=(s*48271)%2147483647;return(s-1)/2147483646 end
 return {NextNumber=function(_,a,b)local u=nextUnit();if a then return a+(b-a)*u end;return u end,NextInteger=function(_,a,b)return a+math.floor(nextUnit()*(b-a+1))end}
end}
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
W.service('PolicyService').GetPolicyInfoForPlayerAsync=function()return {ArePaidRandomItemsRestricted=false,IsPaidItemTradingAllowed=true}end
local Market=W.service('MarketplaceService');local prompts={};local robux={}
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptProductPurchase=function(_,p,id)prompts[#prompts+1]={p,id}end
Market.GetUsersPriceLevelsAsync=function(_,ids)local out={};for _,id in ipairs(ids)do out[#out+1]={UserId=id,PriceLevel=100}end;return out end
Market.UserOwnsGamePassAsync=function()return false end
Market.PromptGamePassPurchaseFinished=R.signal()
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
-- every RemoteEvent fired at a client is recorded
local sent={}
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function(self,p,...)sent[#sent+1]={Remote=self.Name,P=p,Args={...}}end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return p~=nil end,Publish=function()return true end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
-- the clock: os.time() is the mock's floor(R.clock); the limited event ends at LimitedEvent.EndsAt
local Limited=W.module('LimitedEvent');local ENDS=Limited.EndsAt
R.clock=ENDS-40*86400
local Config=server('Config');local Packs=W.module('SeedPackRules');local Catalog=W.module('MechCatalog');local Balance=W.module('BalanceRules');local PlantRules=W.module('PlantRules')
local Pricing=W.module('PremiumPricing')
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Catalog.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102)
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local notes={}
local Notes={Show=function(_,p,msg,color,seconds)notes[#notes+1]={P=p,Text=msg,Color=color,Seconds=seconds}end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
local function makePlayer(id,name,data)
 data=data or Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 p:SetAttribute('PaidRandomAllowed',true)
 data:PreparePlayer(p);assert(data:Load(p),'load '..name)
 return p
end
local Ann=makePlayer(801,'Ann');local Bob=makePlayer(802,'Bob')
local function emptyBag(p,data)local records=(data or Data):GetChestRecords(p);for i=#records,1,-1 do table.remove(records,i)end end
local function packsOf(p,data)local out={};for _,r in ipairs((data or Data):GetChestRecords(p))do if r.Kind=='Pack'then out[#out+1]=r end end;return out end
local function constant(x)return function()return x end end
local Progress=server('PremiumProgress')
local realRoll=Progress.RollCoat

-- 0. the numbers: the world packs' own, and the disclosure line ---------------------------------------------------------------------------------------------
do
 local M=Packs.PackMutations
 check(M.None.Weight==95 and M.Gold.Weight==4.5 and M.Diamond.Weight==.5,'the world constants are None 95 / Gold 4.5 / Diamond .5 (SeedPackRules.PackMutations)')
 check(Catalog.CoatLine()=='Gold 4.5% / Diamond 0.5% coat','the disclosure line is exactly "Gold 4.5% / Diamond 0.5% coat" ('..Catalog.CoatLine()..')')
 check(Packs.RollMutation(0)=='None'and Packs.RollMutation(.9499)=='None'and Packs.RollMutation(.9501)=='Gold'and Packs.RollMutation(.9949)=='Gold'and Packs.RollMutation(.9951)=='Diamond'and Packs.RollMutation(.99999)=='Diamond',
  'the roll the Mech pack uses (RollMutation) cuts at .95 / .995, like the world packs')
 check(Packs.PackLabel(8,'MechLimited',1,'None')=='Limited Mech Pack'and Packs.PackLabel(8,'MechLimited',1,'Gold')=='Gold Limited Mech Pack'and Packs.PackLabel(8,'MechLimited',1,'Diamond')=='Diamond Limited Mech Pack'
  and Packs.PackLabel(8,'MechLimited',1,'Wicked')=='Limited Mech Pack'and Packs.PackLabel(8,'MechLimited',1,nil)=='Limited Mech Pack','the pack\'s name carries the coat like a world pack\'s ("Gold Limited Mech Pack"), an unknown coat is plain')
 check(Packs.PackLabel(2,'Pack03',1,'Gold')=='Gold Desert Seed Pack','(control) a world pack\'s name is "Gold Desert Seed Pack"')
 check(Catalog.Offer(1).GemPrice==80 and Catalog.Offer(5).GemPrice==375 and Catalog.Offer(10).GemPrice==700,'prices are unchanged: 80 / 375 / 700')
 local chances={};for _,s in ipairs(Catalog.Seeds)do chances[#chances+1]=s.Chance end
 check(table.concat(chances,',')=='48,26,16,7,2.5,0.5','the seed odds shown are unchanged: 48 / 26 / 16 / 7 / 2.5 / 0.5')
end

-- 1. the purchase roll ----------------------------------------------------------------------------------------------------------------------------------------
do
 -- one draw per pack, in order, each pack its own coat
 local calls=0;local script={'Gold','None','Diamond','None','None','Gold','Gold','None','Diamond','None'}
 Progress.RollCoat=function()calls+=1;return script[(calls-1)%#script+1]end
 for _,count in ipairs({1,5,10})do
  emptyBag(Ann);calls=0
  local packs=Data:GrantMechPacks(Ann,true,count)
  check(packs and#packs==count and calls==count,'a bought '..count..'-pack rolls one coat per pack ('..calls..' draws)')
  local ok=packs~=nil
  for i,r in ipairs(packs or{})do ok=ok and r.PackMutation==script[i]and r.BagVariant=='MechLimited'and r.Stage==8 and r.PaidRandom==true end
  check(ok,'... pack i gets draw i, in order, whatever the others got ('..count..'-pack)')
 end
 -- 80 / 375 / 700 gems buy through BuyMechPack: the same
 emptyBag(Ann);Data:GetPremium(Ann).Gems=100000;calls=0
 local okBuy,msg,records=Data:BuyMechPack(Ann,10)
 check(okBuy==true and records and#records==10 and calls==10 and records[1].PackMutation=='Gold'and records[3].PackMutation=='Diamond','BuyMechPack(10): ten draws, the packs it returns carry them')
 check(Data:GetPremium(Ann).Gems==100000-700,'... and charges 700 Gems once')
 -- a free grant (a daily Mech pack) never rolls: the coat of a free pack is plain, like every free pack
 emptyBag(Ann);calls=0
 local free=Data:GrantMechPacks(Ann,false,1)
 check(free and free[1].PackMutation=='None'and free[1].PaidRandom==false and calls==0,'a FREE Mech pack (paid == false: a daily grant) stays plain and draws nothing')
 emptyBag(Ann);calls=0
 local daily=Data:GrantDailyPack(Ann,'Mech','Daily')
 check(daily and daily.PackMutation=='None'and calls==0,'GrantDailyPack(Mech): plain, no draw')
 -- /test rarepacks mech: TEST packs, plain
 emptyBag(Ann);calls=0
 local okTest=server('RarePackTests').Grant(Data,Ann,'mech',Ann)
 local test=packsOf(Ann);local allPlain=#test>0
 for _,r in ipairs(test)do allPlain=allPlain and r.PackMutation=='None'and r.TestGrant==true and r.BagVariant=='MechLimited'end
 check(okTest and allPlain and calls==0,'/test rarepacks mech: '..#test..' TEST packs, all plain, no draw')
 -- /test rarepacks mech gold|diamond (the owner's way to SEE a coated Mech pack): TEST packs in that coat, never rolled
 for _,coat in ipairs({'Gold','Diamond'})do
  emptyBag(Ann);calls=0
  local okCoat=server('RarePackTests').Grant(Data,Ann,'mech',Ann,coat)
  local coated=packsOf(Ann);local allCoat=#coated==6
  for _,r in ipairs(coated)do allCoat=allCoat and r.PackMutation==coat and r.TestGrant==true and r.BagVariant=='MechLimited'end
  check(okCoat and allCoat and calls==0,'/test rarepacks mech '..coat..': six TEST Mech packs, all '..coat..' (no draw)')
 end
 emptyBag(Ann);calls=0;server('RarePackTests').Grant(Data,Ann,'mech',Ann,'Wicked')
 local junkCoat=packsOf(Ann);local plainJunk=#junkCoat==6;for _,r in ipairs(junkCoat)do plainJunk=plainJunk and r.PackMutation=='None'end
 check(plainJunk,'an unknown coat word gives plain TEST packs (the command refuses it before this)')
 -- a failing grant draws nothing that survives: the bag is as it was
 emptyBag(Ann);local before=#Data:GetChestRecords(Ann)
 Progress.RollCoat=function()error('boom')end;local oldWarn=W.env.warn;W.env.warn=function()end
 local none,why=Data:GrantMechPacks(Ann,true,5)
 W.env.warn=oldWarn
 check(none==nil and why=='COULDN\'T ADD THE PACKS! TRY AGAIN'and#Data:GetChestRecords(Ann)==before,'a roll that throws adds no pack (the batch is rolled back)')
 Progress.RollCoat=realRoll
end

-- the real roll: rates over many packs --------------------------------------------------------------------------------------------------------------------
do
 emptyBag(Ann);Data:GetPremium(Ann).Gems=900000
 local N=3000;local gold,diamond,total=0,0,0;local inBatch={};local sizes={}
 local bySize={}
 for _=1,N do
  emptyBag(Ann)
  local packs=assert(Data:GrantMechPacks(Ann,true,10))
  local coated=0
  for _,r in ipairs(packs)do
   total+=1
   if r.PackMutation=='Gold'then gold+=1;coated+=1 elseif r.PackMutation=='Diamond'then diamond+=1;coated+=1 end
   local key=r.PackSize==1 and'one'or'other';bySize[key]=bySize[key]or{N=0,C=0};bySize[key].N+=1;if r.PackMutation~='None'then bySize[key].C+=1 end
  end
  inBatch[coated]=(inBatch[coated]or 0)+1
 end
 local g,d=gold/total*100,diamond/total*100
 print(string.format('rates: %d bought packs: Gold %.2f%%, Diamond %.3f%%, plain %.2f%%',total,g,d,100-g-d))
 check(near(g,4.5,.45),string.format('over %d bought packs Gold is %.2f%% (world: 4.5%%, tolerance .45)',total,g))
 check(near(d,.5,.15),string.format('... Diamond is %.3f%% (world: 0.5%%, tolerance .15)',d))
 -- each pack on its own: the number of coated packs in a 10-pack follows Binomial(10, .05): P(0) .599, P(1) .315, P(2+) .086
 local p0,p1=(inBatch[0]or 0)/N,(inBatch[1]or 0)/N;local p2=1-p0-p1
 check(near(p0,.5987,.04)and near(p1,.3151,.04)and near(p2,.0862,.025),string.format('a 10-pack has 0 / 1 / 2+ coated packs in %.1f%% / %.1f%% / %.1f%% of batches (independent packs: 59.9 / 31.5 / 8.6)',p0*100,p1*100,p2*100))
 check((inBatch[10]or 0)==0 and(inBatch[9]or 0)==0,'... and never a whole batch coated (the coats are not one shared roll)')
 -- the coat does not depend on the pack's size (the size roll is its own draw)
 local one=bySize.one and bySize.one.C/bySize.one.N*100;local other=bySize.other and bySize.other.N>400 and bySize.other.C/bySize.other.N*100
 check(one and near(one,5,.5)and(not other or near(other,5,2.5)),string.format('the coat rate is the same for 1x packs (%.2f%%) and bigger ones (%s%%): independent of the size',one or-1,other and string.format('%.2f',other)or'too few'))
 emptyBag(Ann)
end

-- 2. saved data -----------------------------------------------------------------------------------------------------------------------------------------------
local goldPack,diamondPack,plainPack
do
 emptyBag(Ann)
 local script={'Gold','Diamond','None'};local i=0
 Progress.RollCoat=function()i+=1;return script[i]end
 local packs=assert(Data:GrantMechPacks(Ann,true,5))
 Progress.RollCoat=function()return'None'end
 goldPack,diamondPack,plainPack=packs[1],packs[2],packs[3]
 local rowG,rowD,rowP=Data:SerializeSeedRecord(goldPack),Data:SerializeSeedRecord(diamondPack),Data:SerializeSeedRecord(plainPack)
 check(rowG.PackMutation=='Gold'and rowD.PackMutation=='Diamond'and rowP.PackMutation=='None','the saved row carries the coat in the existing PackMutation field')
 local function keys(t)local out={};for k in pairs(t)do out[#out+1]=k end;table.sort(out);return table.concat(out,',')end
 check(keys(rowG)==keys(rowP)and keys(rowD)==keys(rowP),'... and nothing else: a coated Mech row has exactly the keys of a plain one ('..keys(rowG)..')')
 local saved=Data:_buildSaveData(Ann)
 check(saved.Version==Config.ProfileVersion and Config.ProfileVersion==22,'a full save with coated Mech packs: ProfileVersion is still 22')
 local DataB=PDS.new(Config,Map,Notes)
 DataB.Store.Data[DataB:_getKey({UserId=1801,Name='Back'})]=saved
 local back=makePlayer(1801,'Back',DataB)
 local byId={};for _,r in ipairs(DataB:GetChestRecords(back))do byId[r.Id]=r end
 check(byId[goldPack.Id]and byId[goldPack.Id].PackMutation=='Gold'and byId[diamondPack.Id]and byId[diamondPack.Id].PackMutation=='Diamond'and byId[plainPack.Id]and byId[plainPack.Id].PackMutation=='None',
  'after a save and a load each Mech pack still has its coat (Gold / Diamond / None)')
 local g=byId[goldPack.Id]
 check(g.BagVariant=='MechLimited'and g.Stage==8 and g.PaidRandom==true,'... and is still a bought Mech pack')
 -- an old Mech pack (R153 / R154: saved plain) and a row with no PackMutation at all load plain
 local old=table.clone(rowP);old.PackMutation=nil;old.Id='old_1';local oldRec=Data:_decodeSavedSeedRecord(Ann,old,50)
 check(oldRec and oldRec.PackMutation=='None'and oldRec.BagVariant=='MechLimited','an old Mech row with no PackMutation loads PLAIN')
 local odd=table.clone(rowP);odd.PackMutation='Wicked';odd.Id='old_2';local oddRec=Data:_decodeSavedSeedRecord(Ann,odd,51);check(oddRec and oddRec.PackMutation=='None','... and a coat the game does not know loads plain too')
 -- a gift keeps the coat as it keeps a world pack's
 local giftRow=Data:SerializeSeedRecord(goldPack);giftRow.RateBoost=nil
 local gifted=Data:DecodeGiftedSeed(Bob,giftRow);check(gifted and gifted.PackMutation=='Gold','a gifted Gold Mech pack arrives Gold (as a world pack does)')
end

-- 3. the reveal keeps the coat -------------------------------------------------------------------------------------------------------------------------------
local revealed={}
do
 emptyBag(Ann);Data:GetPremium(Ann).Gems=900000
 local order={{'Gold',.001,'PlasmaPepperSeed'},{'Gold',.5,'HoloMelonSeed'},{'Gold',.75,'PrismLotusSeed'},{'Diamond',.93,'HoloAppleTreeSeed'},{'Diamond',.98,'NebulaVineSeed'},{'Diamond',.9975,'CrowncoreTreeSeed'}}
 local i=0;Progress.RollCoat=function()i+=1;return order[i][1]end
 local packs=assert(Data:GrantMechPacks(Ann,true,5));local sixth=assert(Data:GrantMechPacks(Ann,true,1))[1]
 Progress.RollCoat=function()return'None'end
 packs[#packs+1]=sixth
 for k,pack in ipairs(packs)do
  local want=order[k]
  local reward=Data:OpenSeedPack(Ann,pack.Id,constant(want[2]))
  check(reward and reward.SeedId==want[3]and reward.PackMutation==want[1]and reward.Kind=='Seed','opening a '..want[1]..' Mech pack with the draw for '..want[3]..' gives that seed with the '..want[1]..' coat ('..tostring(reward and reward.SeedId)..' / '..tostring(reward and reward.PackMutation)..')')
  revealed[#revealed+1]=reward
 end
 local inv=Data:GetSeedInventory(Ann);local groups={}
 for _,g in ipairs(inv)do groups[g.SeedId]=g end
 check(groups.PlasmaPepperSeed and groups.PlasmaPepperSeed.Mutation=='Gold'and groups.PlasmaPepperSeed.Name=='Gold Plasma Pepper Seed','the Bag shows "Gold Plasma Pepper Seed" ('..tostring(groups.PlasmaPepperSeed and groups.PlasmaPepperSeed.Name)..')')
 check(groups.CrowncoreTreeSeed and groups.CrowncoreTreeSeed.Mutation=='Diamond'and groups.CrowncoreTreeSeed.Name=='Diamond Crowncore Tree Seed','... and "Diamond Crowncore Tree Seed"')
 local saved=Data:_buildSaveData(Ann)
 local DataB=PDS.new(Config,Map,Notes);DataB.Store.Data[DataB:_getKey({UserId=1802,Name='Back2'})]=saved
 local back=makePlayer(1802,'Back2',DataB);local seeds={}
 for _,r in ipairs(DataB:GetChestRecords(back))do if r.Kind=='Seed'then seeds[r.SeedId]=r end end
 check(seeds.HoloMelonSeed and seeds.HoloMelonSeed.PackMutation=='Gold'and seeds.NebulaVineSeed and seeds.NebulaVineSeed.PackMutation=='Diamond','the revealed seeds keep their coat through a save and a load')
 -- a plain pack gives a plain seed (control)
 local plain=assert(Data:GrantMechPacks(Ann,false,1))[1];local rp=Data:OpenSeedPack(Ann,plain.Id,constant(.001))
 check(rp and rp.PackMutation=='None','(control) a plain Mech pack gives a plain seed')
 emptyBag(Ann)
end

-- 4. plant and fruit ----------------------------------------------------------------------------------------------------------------------------------------------
do
 local ids={'PlasmaPepperSeed','HoloMelonSeed','PrismLotusSeed','HoloAppleTreeSeed','NebulaVineSeed','CrowncoreTreeSeed'}
 for _,id in ipairs(ids)do
  local def=Config.GardenPlants[id];check(def~=nil,'the plant definition of '..id..' exists')
  for _,coat in ipairs({'Gold','Diamond'})do
   local seed;for _,r in ipairs(revealed)do if r.SeedId==id and r.PackMutation==coat then seed=r end end
   if not seed then seed={Id='s_'..id,SeedId=id,SeedScale=1,PackMutation=coat}end
   local crop=PlantRules.NewCrop(seed,'crop_'..id..coat,def,1000,0,0)
   check(crop.Mutation==coat,id..': the plant of a '..coat..' seed is '..coat..' ('..tostring(crop.Mutation)..')')
  end
 end
 -- the fruit: 20% inherit the coat; a coated fruit is worth x3 (Gold) / x6 (Diamond) of the same fruit uncoated
 check(PlantRules.MutationChance==.20 and Balance.MutationInheritance==.20,'the usual inheritance is 20%')
 check(Balance.MutationMultipliers.Gold==3 and Balance.MutationMultipliers.Diamond==6,'the fruit multipliers are x3 / x6')
 for _,coat in ipairs({'Gold','Diamond'})do
  local mult=Balance.MutationMultipliers[coat]
  for _,id in ipairs({'PlasmaPepperSeed','CrowncoreTreeSeed'})do
   local def=Config.GardenPlants[id];local hits,N=0,6000;local ratioOk=true;local shown=0
   for k=1,N do
    local plainCrop=PlantRules.NewCrop({Id='p'..k,SeedId=id,SeedScale=1,PackMutation='None'},'fruitcrop'..k,def,1000,0,0)
    local coatCrop=PlantRules.NewCrop({Id='p'..k,SeedId=id,SeedScale=1,PackMutation=coat},'fruitcrop'..k,def,1000,0,0)
    local a,b=PlantRules.Fruit(plainCrop,1,def),PlantRules.Fruit(coatCrop,1,def)
    if b.Mutation==coat then
     hits+=1
     if not(a.Mutation=='None'and a.Scale==b.Scale and near(b.Value/a.Value,mult,mult*1e-6))then ratioOk=false end
    else
     if not(b.Mutation=='None'and b.Value==a.Value)then ratioOk=false end
    end
   end
   print(string.format('fruit: %s %s: %.1f%% of %d fruit carry the coat',id,coat,hits/N*100,N))
   check(near(hits/N,.20,.025),string.format('%s %s: %.1f%% of fruit carry the coat (20%%)',id,coat,hits/N*100))
   check(ratioOk,id..' '..coat..': a coated fruit pays exactly x'..mult..' of the same fruit uncoated; the others pay the same as plain')
  end
 end
 -- every fruit slot of the Mech plants goes through the same rule (the multi-fruit trees)
 local def=Config.GardenPlants.HoloAppleTreeSeed;local perSlot={0,0,0,0};local T=2000
 for k=1,T do
  local crop=PlantRules.NewCrop({Id='tree'..k,SeedId='HoloAppleTreeSeed',SeedScale=1,PackMutation='Diamond'},'treecrop'..k,def,1000,0,0)
  for index=1,4 do if PlantRules.Fruit(crop,index,def).Mutation=='Diamond'then perSlot[index]+=1 end end
 end
 local slotsOk=true;for index=1,4 do if not near(perSlot[index]/T,.20,.035)then slotsOk=false end end
 check(slotsOk,'the Holo Apple Tree has 4 fruit slots, each rolled on its own at 20% ('..table.concat(perSlot,' / ')..' of '..T..')')
end

-- 5. the notice + 6. the event's end: the real PremiumService ----------------------------------------------------------------------------------------------------
local chests={SyncTools=function()end}
local bases={RefreshTreadmill=function()end,GetPlayerBase=function()return nil end}
local Passes_=server('GamePassService').new(Data,bases,chests)
local Service=server('PremiumService').new(Data,chests,Passes_)
local remote=RS.ChestChaseRemotes.PremiumRequest
local function invoke(p,action,value)R.clock+=1;return remote.OnServerInvoke(p,action,value)end
local purchaseN=0
local function receipt(p,id,purchaseId)
 if not purchaseId then purchaseN+=1;purchaseId='mech-purchase-'..purchaseN end
 R.clock+=1;return Market.ProcessReceipt({ProductId=id,PurchaseId=purchaseId,PlayerId=p.UserId}),purchaseId
end
local Granted=R.Enum.ProductPurchaseDecision.PurchaseGranted;local Later=R.Enum.ProductPurchaseDecision.NotProcessedYet
local function mark()return {Sent=#sent,Notes=#notes}end
local function doneSince(m)local out={};for i=m.Sent+1,#sent do if sent[i].Remote=='PurchaseDone'then out[#out+1]=sent[i]end end;return out end
local function notesSince(m)local out={};for i=m.Notes+1,#notes do out[#out+1]=notes[i]end;return out end
-- (the products load at once: Marketplace answers without waiting; no sleeper is resumed after this, so the clock can be set freely below)
do
 local Announcer=server('PurchaseAnnouncer')
 local function rec(...)local out={};for _,c in ipairs({...})do out[#out+1]={PackMutation=c}end;return out end
 check(Announcer.CoatText(rec('None'))==''and Announcer.CoatText(rec('None','None','None'))==''and Announcer.CoatText(nil)==''and Announcer.CoatText({})=='','CoatText: nothing coated says nothing')
 check(Announcer.CoatText(rec('Gold'))==' ✨ GOLD MECH PACK!'and Announcer.CoatText(rec('Diamond'))==' 💎 DIAMOND MECH PACK!','CoatText: one coated single pack is "GOLD MECH PACK!" / "DIAMOND MECH PACK!"')
 check(Announcer.CoatText(rec('None','Gold','None','None','None'))==' ✨ 1 GOLD!'and Announcer.CoatText(rec('Gold','Gold','Diamond','None'))==' ✨ 2 GOLD + 💎 1 DIAMOND!'and Announcer.CoatText(rec('Diamond','None'))==' 💎 1 DIAMOND!',
  'CoatText: several packs are counted ("1 GOLD", "2 GOLD + 1 DIAMOND")')
 check(Announcer.CoatText(rec('Wicked'))==''and Announcer.CoatText({'Gold'})==''and Announcer.CoatText('Gold')=='','CoatText: junk says nothing')
 -- a gem purchase: one notice, one PurchaseDone, with the coats in the same line
 emptyBag(Ann);Data:GetPremium(Ann).Gems=100000
 local script={'None','Gold','None','None','Diamond'};local i=0
 Progress.RollCoat=function()i+=1;return script[i]end
 local m=mark();local r=invoke(Ann,'BuyPack',5)
 local ns,done=notesSince(m),doneSince(m)
 check(r.Success==true and#ns==1 and ns[1].P==Ann and ns[1].Text=='✅ Bought: 5 Mech Packs! ✨ 1 GOLD + 💎 1 DIAMOND!','BuyPack 5 with a Gold and a Diamond: ONE notice "✅ Bought: 5 Mech Packs! ✨ 1 GOLD + 💎 1 DIAMOND!" ('..tostring(ns[1]and ns[1].Text)..')')
 check(#done==1 and done[1].P==Ann and done[1].Args[1].Kind=='Pack'and done[1].Args[1].Name=='5 Mech Packs','... and ONE PurchaseDone {Pack, "5 Mech Packs"} as before')
 emptyBag(Ann);i=0;script={'Gold'}
 m=mark();r=invoke(Ann,'BuyPack',1);ns=notesSince(m)
 check(r.Success==true and#ns==1 and ns[1].Text=='✅ Bought: 1 Mech Pack! ✨ GOLD MECH PACK!','BuyPack 1 that comes Gold: "✅ Bought: 1 Mech Pack! ✨ GOLD MECH PACK!"')
 emptyBag(Ann);i=0;script={'None','None','None','None','None','None','None','None','None','None'}
 m=mark();r=invoke(Ann,'BuyPack',10);ns=notesSince(m)
 check(r.Success==true and#ns==1 and ns[1].Text=='✅ Bought: 10 Mech Packs!','BuyPack 10 with no coat: the plain notice "✅ Bought: 10 Mech Packs!"')
 -- a Robux receipt (all three sizes), the same
 emptyBag(Ann);i=0;script={'Diamond','None','None','None','None','None','None','None','None','None'}
 m=mark();local d=receipt(Ann,301+1) -- 5 packs: product 302
 ns=notesSince(m)
 check(d==Granted and#ns==1 and ns[1].Text=='✅ Bought: 5 Mech Packs! 💎 1 DIAMOND!','a Robux receipt for 5 packs with a Diamond: "✅ Bought: 5 Mech Packs! 💎 1 DIAMOND!" ('..tostring(ns[1]and ns[1].Text)..')')
 local coated=0;for _,r2 in ipairs(packsOf(Ann))do if r2.PackMutation=='Diamond'then coated+=1 end end
 check(coated==1,'... and the Diamond pack is in the Bag')
 -- the same receipt again: granted again as a duplicate? no: PurchaseId already seen -> no second grant, no second notice
 m=mark();local before=#packsOf(Ann);local dup=Market.ProcessReceipt({ProductId=302,PurchaseId='mech-purchase-'..purchaseN,PlayerId=Ann.UserId})
 check(dup==Granted and#packsOf(Ann)==before and#notesSince(m)==0,'a repeated receipt grants and announces nothing more')
 Progress.RollCoat=realRoll
end

-- 6. the event's end ------------------------------------------------------------------------------------------------------------------------------------------------
do
 local function at(offset)R.clock=ENDS+offset end
 -- the countdown text, in the Index LIMITED tab's format
 check(Catalog.TimerText(ENDS-(27*86400+4*3600+12*60+9))=='⏳ ENDS IN 27d 04h 12m 09s','TimerText 27d 04h 12m 09s before the end: "⏳ ENDS IN 27d 04h 12m 09s"')
 check(Catalog.TimerText(ENDS-3600)=='⏳ ENDS IN 0d 01h 00m 00s'and Catalog.TimerText(ENDS-1)=='⏳ ENDS IN 0d 00h 00m 01s','... 1 h left and 1 s left')
 check(Catalog.TimerText(ENDS)=='THANKS FOR PLAYING!'and Catalog.TimerText(ENDS+86400)=='THANKS FOR PLAYING!','at EndsAt and after it the timer reads THANKS FOR PLAYING!')
 check(Catalog.EventOver(ENDS-1)==false and Catalog.EventOver(ENDS)==true and Catalog.EventOver(ENDS+1)==true,'EventOver flips exactly at EndsAt')
 check(Catalog.OnSale(ENDS-1)==true and Catalog.OnSale(ENDS)==false and Catalog.OnSale(ENDS+5)==false,'OnSale is true until EndsAt and false from it')
 check(Catalog.Event.Live=='LIMITED TIME!'and Catalog.Event.Over=='EVENT OVER!'and Catalog.Event.Refused=='EVENT\'S OVER! THANKS FOR PLAYING!','the words: LIMITED TIME! / EVENT OVER! / EVENT\'S OVER! THANKS FOR PLAYING!')
 -- the owner's own switches still work before the end
 RS.MechCatalog:SetAttribute('SaleEnabled',false);check(Catalog.OnSale(ENDS-100)==false,'SaleEnabled=false still takes the pack off sale before the end')
 RS.MechCatalog:SetAttribute('SaleEnabled',nil)
 RS.MechCatalog:SetAttribute('SaleEndsAt',ENDS-50);check(Catalog.OnSale(ENDS-60)==true and Catalog.OnSale(ENDS-50)==false,'SaleEndsAt still ends the sale before the event does');RS.MechCatalog:SetAttribute('SaleEndsAt',nil)

 -- (control) a minute before the end a gem purchase works and charges 80
 emptyBag(Ann);Data:GetPremium(Ann).Gems=1000;Data:GetPremium(Ann).Receipts={};Progress.RollCoat=function()return'None'end
 at(-60);local rc=invoke(Ann,'BuyPack',1)
 check(rc.Success==true and#packsOf(Ann)==1 and Data:GetPremium(Ann).Gems==920,'(control) 60 s before the end a gem purchase works and charges 80 ('..tostring(rc.Success)..' / '..tostring(rc.Message)..' / '..#packsOf(Ann)..' packs / '..Data:GetPremium(Ann).Gems..' Gems)')
 Progress.RollCoat=realRoll
 -- a Robux prompt is opened BEFORE the end (the player is still in the Roblox dialog when the event ends)
 emptyBag(Ann);Data:GetPremium(Ann).Gems=100000
 at(-30);prompts={}
 local st=invoke(Ann,'State')
 check(st.OnSale==true and st.PackOffers['1'].GemAvailable==true and st.PackOffers['1'].RobuxAvailable==true,'30 s before the end: on sale, gems and Robux available')
 local r=invoke(Ann,'RobuxPack',1)
 check(r.Success==true and#prompts==1 and prompts[1][2]==301,'30 s before the end: the Robux prompt opens (product 301)')
 -- the event ends
 at(2);prompts={}
 st=invoke(Ann,'State')
 check(st.OnSale==false and st.PackOffers['1'].GemAvailable==false and st.PackOffers['5'].GemAvailable==false and st.PackOffers['10'].GemAvailable==false,'after the end: State says off sale and every gem offer is unavailable')
 check(st.PackOffers['1'].RobuxAvailable==false and st.PackOffers['5'].RobuxAvailable==false and st.PackOffers['10'].RobuxAvailable==false and st.RobuxAvailable==false and st.GemPackAvailable==false,'... and every Robux offer too')
 -- a gem purchase after the end: refused, nothing charged, nothing granted
 local gems=Data:GetPremium(Ann).Gems;local before=#packsOf(Ann);local m=mark()
 for _,count in ipairs({1,5,10})do
  r=invoke(Ann,'BuyPack',count)
  check(r.Success==false and r.Message==Catalog.Event.Refused,'a gem purchase of '..count..' after the end is refused: "'..tostring(r.Message)..'"')
 end
 check(Data:GetPremium(Ann).Gems==gems and#packsOf(Ann)==before,'... nothing was charged ('..Data:GetPremium(Ann).Gems..' Gems) and nothing was granted ('..#packsOf(Ann)..' packs)')
 check(#doneSince(m)==0 and#notesSince(m)==0,'... and nothing was announced')
 local direct,why=Data:BuyMechPack(Ann,1);check(direct==false and why==Catalog.Event.Refused and Data:GetPremium(Ann).Gems==gems,'Data:BuyMechPack itself refuses after the end, with nothing charged')
 -- a Robux prompt after the end: refused, no prompt
 for _,count in ipairs({1,5,10})do
  prompts={};r=invoke(Ann,'RobuxPack',count)
  check(r.Success==false and r.Message==Catalog.Event.Refused and#prompts==0,'a Robux prompt for '..count..' packs after the end is refused with no prompt: "'..tostring(r.Message)..'"')
 end
 -- the receipt of the prompt opened before the end arrives now: granted normally (never take Robux without granting)
 Progress.RollCoat=function()return'Gold'end
 m=mark();local packsBefore=#packsOf(Ann)
 local d=receipt(Ann,301)
 check(d==Granted,'a Robux receipt that arrives AFTER the end is granted (PurchaseGranted)')
 check(#packsOf(Ann)==packsBefore+1,'... and the pack is in the Bag')
 local ns=notesSince(m);check(#ns==1 and ns[1].Text=='✅ Bought: 1 Mech Pack! ✨ GOLD MECH PACK!'and#doneSince(m)==1,'... with its "Bought" notice and PurchaseDone, coat included')
 for _,count in ipairs({5,10})do
  packsBefore=#packsOf(Ann);emptyBag(Ann);local dd=receipt(Ann,300+(count==5 and 2 or 3))
  check(dd==Granted and#packsOf(Ann)==count,'a late receipt for '..count..' packs is granted too ('..#packsOf(Ann)..' packs)')
 end
 Progress.RollCoat=realRoll
 -- a late receipt with a full Bag keeps its old behaviour: not processed yet (retried), never a lost purchase
 -- (R155 inventory: normal grants stop at the 200 cap; a receipt grant skips it, so the Bag is filled to the 1000 saved ceiling the receipt way)
 emptyBag(Ann);for _=1,Config.MaxSavedChests do Data:AddChest(Ann,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion},{Receipt=true})end
 check(#Data:GetChestRecords(Ann)>=Config.MaxSavedChests,'(setup) the Bag is at the '..Config.MaxSavedChests..' saved ceiling ('..#Data:GetChestRecords(Ann)..')')
 local dFull=receipt(Ann,301);check(dFull==Later,'(unchanged) a late receipt with a full Bag is NotProcessedYet and retried, never refused')
 emptyBag(Ann);local dAgain,pid=receipt(Ann,301)
 check(dAgain==Granted,'... and is granted once there is room')
 -- packs the player already owns work as before: opening still works after the end
 emptyBag(Ann);Progress.RollCoat=function()return'Diamond'end
 local mine=assert(Data:GrantMechPacks(Ann,true,1))[1];Progress.RollCoat=realRoll
 local reward=Data:OpenSeedPack(Ann,mine.Id,constant(.5))
 check(reward and reward.Kind=='Seed'and reward.PackMutation=='Diamond','after the end a Mech pack the player owns still opens, and keeps its coat')
end

-- 7. the hold tooltip: the Mech pack's odds, then the coat line (a world pack has none) ------------------------------------------------------------------
do
 local Chests=server('ChestService')
 local host=setmetatable({PlayerData=Data,Config=Config,Openings={}},{__index=Chests})
 local function tooltip(pack)
  local tool=R.new('Tool');tool:SetAttribute('SeedInventoryId',pack.Id);tool:SetAttribute('Stage',pack.Stage);tool:SetAttribute('BagVariant',pack.BagVariant)
  pcall(Chests._holdPack,host,Ann,tool) -- (it sets the tooltip, then goes on to the opening, which this bare host cannot do)
  return tool.ToolTip
 end
 emptyBag(Ann)
 local script={'Gold','None','Diamond','None','None'};local i=0;Progress.RollCoat=function()i+=1;return script[i]end
 local packs=assert(Data:GrantMechPacks(Ann,true,5));Progress.RollCoat=function()return'None'end
 local world=assert(Data:AddChest(Ann,{Stage=2,BagVariant='Pack03',PackSize=1,PackMutation='Gold',OddsVersion=Packs.OddsVersion}))
 local gold,plain,diamond=tooltip(packs[1]),tooltip(packs[2]),tooltip(packs[3]);local worldTip=tooltip(world)
 local function lines(t)local out={};for l in(t..'\n'):gmatch('(.-)\n')do out[#out+1]=l end;return out end
 local g,p,d,w=lines(gold),lines(plain),lines(diamond),lines(worldTip)
 check(g[1]=='Gold Limited Mech Pack'and p[1]=='Limited Mech Pack'and d[1]=='Diamond Limited Mech Pack','the hold tooltip names the coat: "'..g[1]..'" / "'..p[1]..'" / "'..d[1]..'"')
 check(g[8]=='Gold 4.5% / Diamond 0.5% coat'and g[8]==p[8]and g[8]==d[8]and #g==#p and #g==#d,'... the six seed odds, then the line "Gold 4.5% / Diamond 0.5% coat" (line 8 of '..#g..'; "'..tostring(g[8])..'"; R155 pity: its rule line may follow)')
 for k=9,#g do check(not g[k]:find('coat',1,true),'... nothing after the coat line is another coat line ("'..g[k]..'")')end
 check(g[2]:match('Plasma Pepper')and g[7]:match('Crowncore'),'... the seed lines keep their order (the Mech pool: Plasma Pepper first, Crowncore last)')
 check(#w==#lines(worldTip)and not worldTip:find('coat',1,true),'(control) a world pack\'s tooltip has no coat line')
end

print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
