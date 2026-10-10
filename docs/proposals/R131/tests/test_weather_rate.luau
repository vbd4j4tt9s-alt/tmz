--!nocheck
-- R131 (owner): weather mutations are 0.2% per minute of weather for packs, plants and fruits (was one 2% roll per
-- 3-minute event). Real WeatherService + WeatherTraits on the mock, thousands of objects through a whole event.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local Traits=W.module('WeatherTraits');local Rules=W.module('PlantRules');local Catalog=W.module('PlantCatalog')
check(Traits.PackChance==.002 and Traits.PlantChance==.002 and Traits.FruitChance==.002,'0.2% per roll for packs, plants and fruits')
local seeds={}
local Data={Gardens={},IsLoaded=function()return true end,_gardenChanged=function()end,_notifySeedInventory=function()end,
 MarkDirty=function()end,QueueGardenSave=function()end,GetChestRecords=function()return{}end}
local Chests={Config={RemoteFolderName='ChestChaseRemotes'},Map={Chests=seeds},Openings={},Bases={GetPlayerBase=function()end},RenderGarden=function()end}
local Service=W.load('WeatherService',R.new('ModuleScript'))
local svc=Service.new(Data,Chests)
-- Minutes count down from the event's end: a 3-minute event has minutes 2, 1, 0.
local now=1000;svc.Override={Kind='Rain',Cycle=77,Until=now+180}
check(svc:Minute(now)==2 and svc:Minute(now+59)==2 and svc:Minute(now+61)==1 and svc:Minute(now+125)==0 and svc:Minute(now+179)==0,'three one-minute rounds per 3-minute event')
-- Packs
local N=30000;local holder=R.new('Folder');holder.Parent=W.workspace
for i=1,N do local m=R.new('Model');m.Name='Pack_'..i;m.Parent=holder;seeds[i]={Available=true,Model=m,Stage=1+i%7,Generation=1,PackSize=1,Weather='None'}end
local function adopted()local n=0;for _,s in ipairs(seeds)do if s.Weather~='None'then n+=1 end end;return n end
local perMinute={}
for _,minute in ipairs({2,1,0})do
 local before=adopted();for _,s in ipairs(seeds)do svc:ApplyPack(s,'Rain',77,minute)end;perMinute[#perMinute+1]=adopted()-before
end
local total=adopted();local p=1-(1-.002)^3;local mean,sd=N*p,math.sqrt(N*p*(1-p))
check(math.abs(total-mean)<5*sd,('packs over one event: %d of %d (%.2f%%, expected %.2f%%; was 2%%)'):format(total,N,total/N*100,p*100))
for i,c in ipairs(perMinute)do check(math.abs(c-N*.002)<5*math.sqrt(N*.002),('minute %d: %d new (expected ~%d)'):format(3-i,c,N*.002))end
local again=adopted();for _,s in ipairs(seeds)do svc:ApplyPack(s,'Rain',77,0)end
check(adopted()==again,'no second roll in the same minute')
-- A new event rolls afresh; a pack never gets the same weather twice.
local rained=0;for _,s in ipairs(seeds)do if s.Weather~='None'then rained+=1 end end
for _,minute in ipairs({2,1,0})do for _,s in ipairs(seeds)do svc:ApplyPack(s,'Rain',78,minute)end end
local twice=0;for _,s in ipairs(seeds)do if s.Weather:find('Wet.*Wet')or s.Weather:find('Drippy.*Drippy')then twice+=1 end end
check(twice==0,'same weather never stacks twice')
-- Plants and fruits
local crops={};local M=12000
for i=1,M do crops[i]=Rules.NewCrop({SeedId='SunflowerSeed',SeedScale=1,Id='s'..i,PackMutation='None',Weather='None'},'c'..i,Catalog.SunflowerSeed,0,0,0)end
local plants,fruits=0,0
for _,minute in ipairs({2,1,0})do for _,c in ipairs(crops)do
 local changed,counts=svc:ApplyCrop(c,'Rain',90,minute);if changed then plants+=counts.Plants;fruits+=counts.Fruits end
end end
local pm,ps=M*p,math.sqrt(M*p*(1-p))
check(math.abs(plants-pm)<5*ps,('plants over one event: %d of %d (%.2f%%, expected %.2f%%)'):format(plants,M,plants/M*100,p*100))
local def=Catalog.SunflowerSeed
if def.Mode~='whole'then
 local slots=M*def.FruitCount;local fm,fs=slots*p,math.sqrt(slots*p*(1-p))
 check(math.abs(fruits-fm)<5*fs,('fruits over one event: %d of %d (%.2f%%, expected %.2f%%)'):format(fruits,slots,fruits/slots*100,p*100))
else check(fruits==0,'whole-plant harvest: no separate fruit rolls')end
-- The owner test 'weather rain all' still changes everything at once.
svc.ForceAll=true;local fresh={Available=true,Model=R.new('Model'),Stage=1,Generation=1,PackSize=1,Weather='None'};fresh.Model.Name='Fresh';fresh.Model.Parent=holder
svc:ApplyPack(fresh,'Rain',99,2);check(fresh.Weather~='None','weather <kind> all still forces the change')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
