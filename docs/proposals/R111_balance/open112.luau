-- Runs the REAL ChestService:_activatePack -> PlayerDataService:OpenSeedPack -> SeedPackRules.Roll path under mocks
-- for every biome x pack x boot (OddsVersion 112), plus OddsVersion 81 / legacy / Void / Mech packs, and the real
-- PlayerDataService:RefreshBoostMultipliers luck clamp. Bundle: bundle.py open112.luau OUT ChestService=... PlayerDataService=... PlantRules=...
STUBS.SeedPackVisuals={};STUBS.ItemEffectAnchor={Set=function()end}
STUBS.GardenFenceData={Install=function()end};STUBS.PremiumProgress={Attach=function()end};STUBS.TutorialProgress={Attach=function()end}
STUBS.RarePackTests={Expected=function()return nil end}
STUBS.GardenPlantRuntime={Install=function()end};STUBS.HarvestToolService={Install=function()end}
workspace={GetServerTimeNow=function()return os.clock()end}
local delayed=0
task={delay=function()delayed+=1 end,spawn=function(f,...)f(...)end,defer=function()end,wait=function()end}
local Rules=RS_MOD('SeedPackRules')
local T=RS_MOD('BalanceValues81')
local PDS=RS_MOD('PlayerDataService')
local CS=RS_MOD('ChestService')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local byId={};for _,c in ipairs(config.SeedCatalogByStage)do for _,s in ipairs(c)do byId[s.Id]=s end end
function config.GetSeedById(id)return byId[id]end
local function attrs()
 local a={};return {Attrs=a,GetAttribute=function(_,k)return a[k]end,SetAttribute=function(_,k,v)a[k]=v end}
end
local player=attrs();player.UserId=1;player.Character={}
-- PlayerDataService instance: real methods, storage/garden side effects stubbed.
local records={}
local data=setmetatable({Config=config,StudioPackRewards={[player]={}}},{__index=PDS})
data.IsLoaded=function()return true end
data.GetChestRecords=function()return records end
data.SeedCollectReward=function()return 1 end
for _,k in ipairs({'_gardenChanged','MarkDirty','MarkSeedDiscovered','CommitSeedReward','_notifySeedInventory','QueueGardenSave','TutorialEvent'})do data[k]=function()end end
-- ChestService instance: real _activatePack, real PackRandom-style draw.
local rng={NextNumber=function()return math.random()end}
local chest=setmetatable({Config=config,PlayerData=data,Openings={},PackRandom=rng,Notifications={Show=function(_,_,msg)error('open failed: '..tostring(msg))end}},{__index=CS})
chest._canOpenPack=function()return true end
chest._finishOpening=function(self,p)self.Openings[p]=nil end
local serial=0
local function open(stage,variant,version,luck)
 serial+=1;local id='pack'..serial
 records[1]={Id=id,Kind='Pack',Stage=stage,BagVariant=variant,OddsVersion=version,PackSize=1,PackMutation='None',ChestNumber=serial}
 player.Attrs.ChestLuckMultiplier=luck
 local toolAttrs={SeedInventoryId=id};local tool={Enabled=true,GetAttribute=function(_,k)return toolAttrs[k]end}
 local bag=attrs()
 chest.Openings[player]={Tool=tool,Character=player.Character,Connections={},Committed=false,Clicks=Rules.OpenClicks-1,LastClick=-math.huge,Bag=bag}
 chest:_activatePack(player,tool)
 local r=records[1]
 assert(r.Kind=='Seed','pack not opened')
 assert(bag.Attrs.RevealSeedId==r.SeedId and bag.Attrs.Rarity==r.Rarity,'reveal mismatch')
 assert(r.OddsVersion==version,'OddsVersion not kept on the reward record')
 return r
end
math.randomseed(112)
local boots={{'none',1}};for i,n in ipairs({'Sand','Frost','Lava','Crystal','Electric'})do boots[#boots+1]={n,T.BootLuck[i]}end
local order={1,6,2,3,4,5,7}
local opened,bad,N=0,0,300
local tierCount={}
for _,st in ipairs(order)do
 local pool={};for _,s in ipairs(Rules.ObtainablePool(config,st))do pool[s.Id]=true end
 for _,pk in ipairs(Rules.VariantOrder)do for _,b in ipairs(boots)do
  local odds=Rules.SeedOdds(config,st,pk,b[2],112)
  for _=1,N do
   local r=open(st,pk,112,b[2]);opened+=1
   if not pool[r.SeedId]or not(odds[r.SeedId]and odds[r.SeedId]>0)or r.Rarity~=(Rules.GetRarity(r.SeedId))then bad+=1 end
   tierCount[r.Rarity]=(tierCount[r.Rarity]or 0)+1
  end
 end end
end
print(string.format('OddsVersion 112: opened %d packs through ChestService:_activatePack (7 biomes x 6 packs x 6 boots x %d): %d invalid rewards',opened,N,bad))
local line={};for _,t in ipairs(Rules.RarityOrder)do table.insert(line,t..'='..(tierCount[t]or 0))end;print('  tiers seen: '..table.concat(line,' '))
-- OddsVersion 81 packs keep the old odds (luck mapped back to the old boots): Storm Mythic pack, Electric boots.
local function share(st,pk,version,luck,n,tier)
 local hits=0;for _=1,n do if open(st,pk,version,luck).Rarity==tier then hits+=1 end end;return hits/n
end
for _,case in ipairs({{81,'King'},{112,'King'},{81,'Secret'},{112,'Secret'}})do
 local ver,tier=case[1],case[2];local n=20000
 local p=share(7,'Pack06',ver,T.MaxLuck,n,tier)
 local exp=0;for id,pct in pairs(Rules.SeedOdds(config,7,'Pack06',T.MaxLuck,ver))do if Rules.GetRarity(id)==tier then exp+=pct/100 end end
 print(string.format('Storm Mythic pack, Electric boots, OddsVersion %3d: %-6s observed %.4f expected %.4f (z=%+.2f)',ver,tier,p,exp,(p-exp)/math.sqrt(exp*(1-exp)/n)))
end
-- Legacy unversioned pack, Void (81 and 112), Mech pack: all still open.
local r=open(7,'Pack03',nil,T.MaxLuck);print('Legacy unversioned pack opened: '..r.SeedId..' ('..r.Rarity..')')
local voidTiers={}
for _,ver in ipairs({81,112})do
 local c={};for _=1,4000 do local x=open(7,'EclipseReliquary',ver,T.MaxLuck);c[x.Rarity]=(c[x.Rarity]or 0)+1 end
 voidTiers[ver]=c;print(string.format('Void pack v%d, 4000 opens: Secret %d Cosmic %d King %d other(Mech) %d',ver,c.Secret or 0,c.Cosmic or 0,c.King or 0,4000-(c.Secret or 0)-(c.Cosmic or 0)-(c.King or 0)))
end
local mech=0;for _=1,2000 do local x=open(8,'MechLimited',81,T.MaxLuck);if RS_MOD('MechCatalog').Is(x.SeedId)then mech+=1 end end
print('Mech pack (stage 8, gem product, unchanged): '..mech..'/2000 rewards are Mech seeds')
-- A plain number instead of a draw function: v112 refuses (no silent single-draw roll), v81 still works.
local ok112=Rules.Roll(config,7,.5,1,'Pack01',112);local ok81=Rules.Roll(config,7,.5,1,'Pack01',81)
print('Roll with one number: v112 -> '..tostring(ok112)..' (refused), v81 -> '..tostring(ok81 and ok81.Id))
-- Real RefreshBoostMultipliers: best owned boot, clamped at MaxLuck.
local shop={};for i,id in ipairs({'RunnerHalo','StormCrown','LavaBoots','CrystalBoots','MythicOrbit'})do shop[id]={Id=id,Type='Accessory',LuckMultiplier=T.BootLuck[i]}end
shop.Fake={Id='Fake',Type='Accessory',LuckMultiplier=1e9}
local owned={}
data.GetOwnedBoosts=function()return owned end
data._findShopProduct=function(_,id)return shop[id]end
local out={}
for _,id in ipairs({'RunnerHalo','StormCrown','LavaBoots','CrystalBoots','MythicOrbit','Fake'})do
 owned[id]=true;local _,luck=data:RefreshBoostMultipliers(player);table.insert(out,id..'='..luck)
 assert(player.Attrs.ChestLuckMultiplier==luck)
end
print('RefreshBoostMultipliers (best owned, cumulative): '..table.concat(out,' '))
owned={StormCrown=true};local _,l=data:RefreshBoostMultipliers(player);print('Only Frost boots owned -> luck '..l)
