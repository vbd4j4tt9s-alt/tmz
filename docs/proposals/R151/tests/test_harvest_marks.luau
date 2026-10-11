--!nocheck
-- R151 (owner: "some plants and fruits dont float into the players inventory"): the mark a harvest that REMOVES the plant leaves, on the REAL PlayerDataService with the real
-- Config / PlantRules (the R123 world, the way test_hub_hooks.luau sets it up). GardenPlantRuntime reads it when it takes the plant's model out of the garden (the model stays
-- a beat, marked HarvestedBy / HarvestedIndex, so every client sees the fruit fly to the harvester: test_fruit_flight.luau runs the runtime and the client).
--  1. every seed of the catalog is planted and its ripe fruit picked through Data:HarvestPlant: a single-harvest plant (Mode 'whole') and the last fruit of a plant that does not
--     regrow remove the plant and leave exactly one mark {Index, By, At}; every plant that regrows stays and leaves none;
--  2. the shovel (RemovePlant) leaves no mark; the mark is for the plant's own id only; old marks are dropped (30 s);
--  3. the harvest item itself (SourceCropId / FruitIndex, what the Hotbar matches the flight with) is unchanged, and the full-bag refusal changes nothing and marks nothing.
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
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
W.stub('OwnerCommandAccess',{IsAllowed=function()return false end,Publish=function()return false end})
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Rules=W.module('SeedPackRules');local PDS=server('PlayerDataService');local PlantRules=W.module('PlantRules');local Catalog=W.module('PlantCatalog')
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local Notes={Show=function()end}
local Data=PDS.new(Config,Map,Notes)
R.clock=20727*86400+3600*5
local function makePlayer(id,name)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 return p
end
local A=makePlayer(201,'Ava')
local plot=0
-- a seed record like OpenSeedPack makes, planted in the next free plot slot
local function plant(player,seedId,x)
 local pack=Data:AddChest(player,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
 local records=Data:GetChestRecords(player);local idx;for i,r in ipairs(records)do if r.Id==pack.Id then idx=i end end
 local seed=Config.GetSeedById(seedId)
 records[idx]={Id=pack.Id,ChestNumber=pack.ChestNumber,ChestName=seed.Name,Kind='Seed',Stage=1,SeedId=seedId,SeedName=seed.Name,SeedEmoji=seed.Emoji,AccentColor=seed.Color,Rarity=seed.Rarity or'Common',SeedScale=1,
  PackMutation='None',BagVariant='Pack01',OddsVersion=Rules.OddsVersion,PackSize=1}
 local now=os.time()
 local ok,crop=Data:PlantSeed(player,1,pack.Id,{OffsetX=x,OffsetZ=0},now)
 return ok,crop
end
local ids={};for id,d in pairs(Catalog)do if type(d)=='table'and d.Seconds then ids[#ids+1]=id end end;table.sort(ids)
local picked,removedCount,regrowCount=0,0,0
local seeds={}
for _,id in ipairs(ids)do
 local d=Catalog[id]
 local gardenSeed=Config.GetSeedById(id)
 if gardenSeed and Config.GardenPlants[id]then
  local B=makePlayer(1000+#seeds,'P'..id)
  local ok,crop=plant(B,id,0)
  if ok and crop then
   seeds[#seeds+1]=id
   local now=os.time()+crop.ReadyAt+10
   local garden=Data.Gardens[B]
   local expectRemoved=d.Mode=='whole'or(d.Regrows==false and d.FruitCount==1)
   local index=d.FruitCount
   local pickedOk,harvest=Data:HarvestPlant(B,1,crop.Id,now,index)
   if check(pickedOk==true and type(harvest)=='table',id..': the ripe fruit is picked ('..tostring(harvest)..')')then
    picked+=1
    local still=false;for _,c in ipairs(garden.Plots['1']or{})do if c.Id==crop.Id then still=true end end
    local mark=Data.HarvestRemovals and Data.HarvestRemovals[crop.Id]
    check(harvest.SourceCropId==crop.Id and harvest.FruitIndex==index,id..': the harvest item carries SourceCropId / FruitIndex (what the Hotbar matches the flight with)')
    if expectRemoved then
     removedCount+=1
     check(not still and mark~=nil and mark.Index==index and mark.By==B.UserId and type(mark.At)=='number',id..': a harvest that removes the plant leaves a mark {Index='..index..', By=the harvester}')
    else
     regrowCount+=1
     check(still and mark==nil,id..': a plant that regrows stays and leaves no mark')
    end
   end
  end
 end
end
check(#seeds>=65,'every seed of the catalog was planted and picked ('..#seeds..')')
check(removedCount==10 and regrowCount==#seeds-10,'10 seeds remove the plant (6 whole + DatePalm, LavaLotus, SunflowerBloom, WinterPine), the rest regrow ('..removedCount..' / '..regrowCount..')')
-- the shovel and the stale marks
do
 local B=makePlayer(2000,'Shovel')
 local ok,crop=plant(B,'AppleSeed',0)
 local removed=Data:RemovePlant(B,1,crop.Id)
 check(ok and removed==true and not(Data.HarvestRemovals and Data.HarvestRemovals[crop.Id]),'RemovePlant (the shovel) leaves no mark')
 -- a mark is dropped after 30 s when the next one is written
 Data.HarvestRemovals=Data.HarvestRemovals or{};Data.HarvestRemovals['old-crop']={Index=1,By=1,At=os.clock()-31}
 local C=makePlayer(2001,'Next');local ok2,c2=plant(C,'MonsteraSeed',0)
 local okH=Data:HarvestPlant(C,1,c2.Id,os.time()+c2.ReadyAt+10,1)
 check(okH==true and Data.HarvestRemovals['old-crop']==nil and Data.HarvestRemovals[c2.Id]~=nil,'an old mark (31 s) is dropped when the next harvest writes its own')
 -- a refused harvest (still growing, bag full) changes nothing and marks nothing
 local E=makePlayer(2002,'Early');local ok3,c3=plant(E,'MonsteraSeed',0)
 local early,why=Data:HarvestPlant(E,1,c3.Id,os.time(),1)
 check(early==false and Data.HarvestRemovals[c3.Id]==nil,'a refused harvest ('..tostring(why)..') leaves no mark')
 local F=makePlayer(2003,'Full');local ok4,c4=plant(F,'MonsteraSeed',0)
 local g=Data.Gardens[F];for _=1,Config.MaxSavedHarvests do table.insert(g.Harvests,{Id='fill-'..#g.Harvests,SeedId='AppleSeed'})end
 local full,why2=Data:HarvestPlant(F,1,c4.Id,os.time()+c4.ReadyAt+10,1)
 check(full==false and tostring(why2):find('BAG FULL',1,true)~=nil and Data.HarvestRemovals[c4.Id]==nil,'a full bag: refused, the plant stays, nothing is marked ('..tostring(why2)..')')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
