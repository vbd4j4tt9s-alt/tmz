--!nocheck
-- R147 (owner): the Verity pack and the Verity seed, data + server side, on the Roblox mock with the real modules
-- (SeedPackRules, VerityCatalog, VerityPackOdds, VoidPackOdds85, BalanceValues81, PlantCatalog, GrowthPace125, FruitOfHour,
-- Config, PlayerDataService, PremiumProgress, ChestService, OwnerUpdateCommands82, RarePackTests, StudioTestHelp):
--  1. the constants: pack variant / tier / label, the seed design (rarity King, Index category 9), the catalogs, the economy;
--  2. the Verity pack odds (the table, every odds version, the hold tooltip) and the Void pack's odds against a snapshot taken
--     from the UNMODIFIED code (the Void pack and every Void odds version stay exactly as they were);
--  3. 2M Monte Carlo rolls, forced draws, and no other pack ever gives the Verity seed;
--  4. PlayerDataService: ConvertVoidPack (same slot, new Id, size / coat / weather / paid flag kept; refusals change nothing),
--     save / load and gift round trips, opening a Verity pack (Stage 9 survives save / load and gifting), planting and
--     harvesting the Verity seed, King plants and every other plant unchanged, Fruit of the Hour still 51 candidates;
--  5. the Index category 9: BaseChance 1/100, first / repeat cash, half and completion Gems, saves;
--  6. ChestService.ConvertVoidPack (held tool / first Void pack, an opening in progress, a committed opening);
--  7. the owner commands (odds verity, verity N, rarepacks verity, indexinfo verity) and the help rows.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,rel)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(rel or 1e-12)*math.max(1,math.abs(b))end
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
W.stub('OwnerCommandAccess',{IsAllowed=function(p)return Run.IsStudio()and p~=nil end}) -- (allowed while the test says it is Studio)
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do if n~='OwnerCommandAccess'then RS[n].Parent=folder end end
RS.OwnerCommandAccess.Parent=folder
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal()end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local Config=server('Config');local Rules=W.module('SeedPackRules');local V=W.module('VerityCatalog');local VPO=W.module('VerityPackOdds')
local O137=W.module('PackOdds137');local Odds=W.module('OddsText85');local Void=W.module('VoidPackOdds85');local Mech=W.module('MechCatalog')
local T=W.module('BalanceValues81');local Pace=W.module('GrowthPace125');local Hour=W.module('FruitOfHour');local Weather=W.module('WeatherTraits')
local PlantRules=W.module('PlantRules')
-- Snapshot taken from the UNMODIFIED code (commit 5752986, before R147's Verity change) with the same Config/Rules.
local VoidBefore={
 ['nil']={BlackoutBloomSeed=18.9049999005,CrowncoreTreeSeed=0.0025,EmberEmperorSeed=9.95e-08,HollowGeodeSeed=18.9049999005,HoloAppleTreeSeed=0.035,HoloMelonSeed=0.13,MirageFigSeed=0.995,NebulaVineSeed=0.0125,ObsidianMawSeed=18.9049999005,OrbitLotusSeed=0.995,PlasmaPepperSeed=0.24,PolarStarbloomSeed=0.995,PrismLotusSeed=0.08,PrismMonarchSeed=9.95e-08,PulsarStarfruitSeed=9.95e-08,SilentFrostbellSeed=18.9049999005,SolarStarfruitSeed=9.95e-08,StarfruitSeed=18.9049999005,StormSovereignSeed=0.995,SupernovaBloomSeed=0.995,WinterCrownwoodSeed=9.95e-08},
 [0]={BlackoutBloomSeed=15.92,CrowncoreTreeSeed=0.0025,EmberEmperorSeed=0.597,HollowGeodeSeed=15.92,HoloAppleTreeSeed=0.035,HoloMelonSeed=0.13,MirageFigSeed=3.383,NebulaVineSeed=0.0125,ObsidianMawSeed=15.92,OrbitLotusSeed=3.383,PlasmaPepperSeed=0.24,PolarStarbloomSeed=3.383,PrismLotusSeed=0.08,PrismMonarchSeed=0.597,PulsarStarfruitSeed=0.597,SilentFrostbellSeed=15.92,SolarStarfruitSeed=0.597,StarfruitSeed=15.92,StormSovereignSeed=3.383,SupernovaBloomSeed=3.383,WinterCrownwoodSeed=0.597},
 [81]={BlackoutBloomSeed=15.92,CrowncoreTreeSeed=0.0025,EmberEmperorSeed=0.597,HollowGeodeSeed=15.92,HoloAppleTreeSeed=0.035,HoloMelonSeed=0.13,MirageFigSeed=3.383,NebulaVineSeed=0.0125,ObsidianMawSeed=15.92,OrbitLotusSeed=3.383,PlasmaPepperSeed=0.24,PolarStarbloomSeed=3.383,PrismLotusSeed=0.08,PrismMonarchSeed=0.597,PulsarStarfruitSeed=0.597,SilentFrostbellSeed=15.92,SolarStarfruitSeed=0.597,StarfruitSeed=15.92,StormSovereignSeed=3.383,SupernovaBloomSeed=3.383,WinterCrownwoodSeed=0.597},
 [112]={BlackoutBloomSeed=18.9049999005,CrowncoreTreeSeed=0.0025,EmberEmperorSeed=9.95e-08,HollowGeodeSeed=18.9049999005,HoloAppleTreeSeed=0.035,HoloMelonSeed=0.13,MirageFigSeed=0.995,NebulaVineSeed=0.0125,ObsidianMawSeed=18.9049999005,OrbitLotusSeed=0.995,PlasmaPepperSeed=0.24,PolarStarbloomSeed=0.995,PrismLotusSeed=0.08,PrismMonarchSeed=9.95e-08,PulsarStarfruitSeed=9.95e-08,SilentFrostbellSeed=18.9049999005,SolarStarfruitSeed=9.95e-08,StarfruitSeed=18.9049999005,StormSovereignSeed=0.995,SupernovaBloomSeed=0.995,WinterCrownwoodSeed=9.95e-08},
 [137]={BlackoutBloomSeed=18.9049999005,CrowncoreTreeSeed=0.0025,EmberEmperorSeed=9.95e-08,HollowGeodeSeed=18.9049999005,HoloAppleTreeSeed=0.035,HoloMelonSeed=0.13,MirageFigSeed=0.995,NebulaVineSeed=0.0125,ObsidianMawSeed=18.9049999005,OrbitLotusSeed=0.995,PlasmaPepperSeed=0.24,PolarStarbloomSeed=0.995,PrismLotusSeed=0.08,PrismMonarchSeed=9.95e-08,PulsarStarfruitSeed=9.95e-08,SilentFrostbellSeed=18.9049999005,SolarStarfruitSeed=9.95e-08,StarfruitSeed=18.9049999005,StormSovereignSeed=0.995,SupernovaBloomSeed=0.995,WinterCrownwoodSeed=9.95e-08},
}
local VoidDirectBefore='MirageFigSeed:Cosmic SolarStarfruitSeed:King SilentFrostbellSeed:Secret PolarStarbloomSeed:Cosmic WinterCrownwoodSeed:King ObsidianMawSeed:Secret SupernovaBloomSeed:Cosmic EmberEmperorSeed:King StarfruitSeed:Secret HollowGeodeSeed:Secret OrbitLotusSeed:Cosmic PrismMonarchSeed:King BlackoutBloomSeed:Secret PulsarStarfruitSeed:King StormSovereignSeed:Cosmic'
local VoidPoolBefore='MirageFigSeed SolarStarfruitSeed SilentFrostbellSeed PolarStarbloomSeed WinterCrownwoodSeed ObsidianMawSeed SupernovaBloomSeed EmberEmperorSeed StarfruitSeed HollowGeodeSeed OrbitLotusSeed PrismMonarchSeed BlackoutBloomSeed PulsarStarfruitSeed StormSovereignSeed PlasmaPepperSeed HoloMelonSeed PrismLotusSeed HoloAppleTreeSeed NebulaVineSeed CrowncoreTreeSeed'
local FohBefore='AmethystSeed,AncientWorldrootSeed,AppleSeed,AshRoseSeed,BlackoutBloomSeed,BluebellSeed,CactusSeed,CocoaSeed,CrowncoreTreeSeed,CrystalLilySeed,DatePalmSeed,DiamondVineSeed,ElderbloomSeed,EmberBloomSeed,EmberEmperorSeed,FirePepperSeed,HollowGeodeSeed,HoloAppleTreeSeed,HoloMelonSeed,IceberrySeed,LanternFernSeed,LavaLotusSeed,MirageFigSeed,MooncapSeed,MoonflowerSeed,NebulaVineSeed,ObsidianMawSeed,OrbitLotusSeed,PineappleSeed,PlasmaPepperSeed,PolarStarbloomSeed,PrismLotusSeed,PrismMonarchSeed,PrismOrchidSeed,PulsarStarfruitSeed,SilentFrostbellSeed,SnowdropSeed,SolarStarfruitSeed,SparkReedSeed,StarfruitSeed,StormSovereignSeed,SunflowerBloomSeed,SunflowerSeed,SupernovaBloomSeed,TempestLotusSeed,ThunderTulipSeed,TigerOrchidSeed,VenomVineSeed,VoltOrchidSeed,WinterCrownwoodSeed,WinterPineSeed'
local PlantsBefore=[[
AgaveSeed|2740|1510|1713|Legendary|2
AloeSeed|180|99|220|Uncommon|2
AmethystSeed|1470|810|68722500|Rare|5
AncientWorldrootSeed|3600|1980|7893443|Mythic|6
AppleSeed|150|82|183000|Rare|1
AshRoseSeed|1300|720|30739583|Rare|4
BananaSeed|130|72|82|Common|6
BlackoutBloomSeed|9000|4950|32232142857|Secret|7
BluebellSeed|90|50|71400|Uncommon|1
CactusSeed|150|82|1520000|Uncommon|2
CloverSeed|75|41|50|Common|1
CocoaSeed|130|72|123000|Common|6
CrowncoreTreeSeed|1800|450|29300000000|King|nil
CrystalLilySeed|3820|2100|443013889|Mythic|3
DatePalmSeed|3650|2000|352157407|Mythic|2
DesertRoseSeed|930|510|576|Rare|2
DiamondVineSeed|5400|2970|706500000|Mythic|5
DragonfruitSeed|4270|2350|7117|Mythic|2
ElderbloomSeed|113|62|310000|Mythic|1
EmberBloomSeed|1220|670|57659524|Rare|4
EmberEmperorSeed|13020|7160|41064236111|King|4
FirePepperSeed|1140|630|26916667|Rare|4
FrostFernSeed|270|148|520|Uncommon|3
HollowGeodeSeed|8400|4620|12585365854|Secret|5
HoloAppleTreeSeed|900|420|1370000000|Secret|nil
HoloMelonSeed|450|240|1090000000|Mythic|nil
IceberrySeed|1060|580|10988667|Rare|3
LanternFernSeed|900|500|1061230|Rare|6
LavaLotusSeed|3200|1760|977777778|Legendary|4
MirageFigSeed|9000|4950|1032857143|Cosmic|2
MonsteraSeed|159|87|108|Uncommon|6
MooncapSeed|86|47|419000|Rare|1
MoonflowerSeed|1800|990|168214286|Rare|5
NebulaVineSeed|1200|600|5210000000|Cosmic|nil
ObsidianMawSeed|7800|4290|5899159664|Secret|4
OrbitLotusSeed|10200|5610|45798107256|Cosmic|5
PineappleSeed|159|87|953000|Uncommon|6
PlasmaPepperSeed|300|150|130000000|Legendary|nil
PolarStarbloomSeed|9460|5200|9369329073|Cosmic|3
PrismLotusSeed|600|300|1370000000|Mythic|nil
PrismMonarchSeed|14000|7710|87415946206|King|5
PrismOrchidSeed|1630|900|76179861|Rare|5
PulsarStarfruitSeed|14400|7920|90000000000|King|7
SilentFrostbellSeed|7200|3960|793650794|Secret|3
SnowdropSeed|240|132|6360000|Uncommon|3
SolarStarfruitSeed|10800|5940|10311206897|King|2
SparkReedSeed|1590|870|237004342|Rare|7
StarfruitSeed|8800|4840|1682083333|Secret|2
StaticGrassSeed|1590|870|5602|Rare|7
StormSovereignSeed|10800|5940|19314191961|Cosmic|7
StrawberrySeed|120|66|90|Uncommon|1
SunKingPalmSeed|11040|6060|5922|King|2
SunflowerBloomSeed|100|55|8560000|Legendary|1
SunflowerSeed|60|33|58900|Common|1
SupernovaBloomSeed|9830|5410|22301267427|Cosmic|4
TempestLotusSeed|4840|2660|6063414634|Mythic|7
ThunderTulipSeed|1590|870|237004342|Rare|7
TigerOrchidSeed|2700|1490|6812500|Legendary|6
VenomVineSeed|900|500|4235294|Rare|6
VoltOrchidSeed|3600|1980|858218319|Legendary|7
WinterCrownwoodSeed|12030|6610|16571938776|King|3
WinterPineSeed|2880|1590|632727273|Legendary|3
]]
local function sum(t)local n=0;for _,v in pairs(t)do n+=v end;return n end
local function drawConstant(x)return function()return x end end

-- 1. The constants ------------------------------------------------------------------------------------------------
do
check(V.Variant=='VerityReliquary'and V.Id=='VeritySeed'and V.PackStage==7 and V.Stage==9 and V.Rarity=='King'and V.VerityChance==.01,'VerityCatalog constants')
check(Rules.VariantKey('VerityReliquary')=='VerityReliquary'and Rules.VariantKey('EclipseReliquary')=='EclipseReliquary'and Rules.VariantKey('Bogus')=='Standard',
 'the Verity variant is registered (an unknown BagVariant still becomes Standard)')
local pv=Rules.Variants.VerityReliquary
check(pv and pv.Name=='Verity Pack'and pv.BagScale==1 and pv.SeedScale==1.35 and pv.RareBias==1 and pv.SpawnWeight==0 and pv.Trim==7 and pv.Design==2
 and pv.OddsLabel=='Verity seed 1/100 + Secret / Cosmic / Mech','the Verity pack variant row')
check(#Rules.VariantOrder==6 and not table.find(Rules.VariantOrder,'VerityReliquary'),'world spawns still use Pack01-Pack06 only')
local tier,rank=Rules.GetPackTier('VerityReliquary')
check(tier.Name=='Verity'and tier.Rate==7 and rank==7 and near(tier.Color.R,1)and near(tier.Color.G,213/255)and near(tier.Color.B,46/255),'pack tier: Verity, rate 7, gold (255,213,46)')
check(Rules.GetPackTier('EclipseReliquary').Name=='Secret+'and Rules.GetPackTier('MechLimited').Name=='Limited','Void and Mech tiers unchanged')
check(Rules.PackLabel(7,'VerityReliquary',1,'None')=='Verity Pack'and Rules.PackLabel(7,'VerityReliquary',1,'Gold')=='Gold Verity Pack'
 and Rules.PackLabel(7,'VerityReliquary',1,'Diamond')=='Diamond Verity Pack'and Rules.PackLabel(7,'EclipseReliquary',1,'Gold')=='Gold Void Pack','pack labels')
local spec=Rules.SeedDesignById.VeritySeed
check(spec and spec.rarity=='King'and spec.stage==9 and spec.SaveStage==9 and spec.biome=='Verity'and spec.index==1 and spec.top=='ffd52e'and spec.bottom=='f0aa14'
 and spec.ink=='fff8d0'and spec.pattern=='None'and spec.addition=='none'and spec.name=='Verity','the seed design spec')
check(Rules.SeedDesigns[#Rules.SeedDesigns]==spec and Rules.GetRarity('VeritySeed')=='King'and not Rules.IsRetired('VeritySeed'),'it follows the Mech specs; rarity King; not retired')
local count=0;for _,s in ipairs(Rules.SeedDesigns)do if s.id=='VeritySeed'then count+=1 end end
check(count==1 and #Rules.SeedDesigns==54,'exactly one Verity design (54 designs = 47 biome + 6 Mech + Verity; R148 added Aloe and Sand Fruit)')
check(Rules.ObtainableStage('VeritySeed')==9,'obtain stage 9')
local seedDef,seedStage,seedIndex=Config.GetSeedById('VeritySeed')
check(seedDef and seedDef.Name=='Verity Seed'and seedStage==9 and seedIndex==1,'the catalog seed: Verity Seed at stage 9 index 1')
check(#Config.SeedCatalogByStage==9 and #Config.SeedCatalogByStage[9]==1 and #Config.SeedCatalogByStage[8]==6 and Config.StageCount==7,'catalog: 9 categories, stage 9 has one seed, Mech still 6, still 7 biomes')
check(Config.BiomeNames[9]=='Verity'and Config.BiomeRank[9]==9 and Config.BiomeNames[8]=='Mech'and Config.BiomeRank[8]==8,'BiomeNames[9] = Verity, BiomeRank[9] = 9')
check(pcall(Config.Validate),'Config.Validate passes (stage 9 has 1 seed, the plant has the Verity flag, Value <= 9e10)')
local pool9=Rules.ObtainablePool(Config,9)
check(pool9 and #pool9==1 and pool9[1].Id=='VeritySeed','ObtainablePool(9) = the Verity seed')
for stage=1,8 do for _,s in ipairs(Rules.ObtainablePool(Config,stage)or{})do if s.Id=='VeritySeed'then check(false,'Verity seed in pool '..stage)end end end
check(T.SeedValues.VeritySeed==9e10 and T.IndexFirst.VeritySeed==1e11 and T.IndexRepeat.VeritySeed==2e10 and T.CompletionGems[9]==100 and T.HalfwayGems==10,'balance: fruit 9e10, index 1e11 first / 2e10 repeat, 100 Gems, halfway 10')
local gemsOk=true;for _,k in ipairs({1,2,3,4,5,6,7})do if T.CompletionGems[k]~=20 then gemsOk=false end end
check(gemsOk and T.CompletionGems[8]==100,'completion Gems of categories 1-8 unchanged')
local vp=Config.GardenPlants.VeritySeed
check(vp and vp.Verity==true and vp.Mode=='repeat'and vp.FruitCount==1 and vp.Tree==false and vp.HarvestName=='Verity Fruit'and vp.Rarity=='King'and vp.Biome=='Verity'
 and vp.Seconds==14400 and vp.RegrowSeconds==1500 and vp.Value==9e10 and vp.BaseScale==1 and vp.Rank==8 and vp.HarvestMode=='fruit'and vp.Height==23.6 and vp.Radius==11.2
 and vp.Sockets[1][2]==1.6 and vp.FruitCenters[1][2]==12.6 and vp.FruitRadii[1]==11,'the Verity plant: one regrowing ball fruit, 4 h, regrow 1500 s, 9e10')
check(Pace.Exempt(vp)==true and vp.GrowthFactor==nil and vp.BaseSeconds==nil,'GrowthPace125 leaves it alone')
-- Every other plant keeps its growth time, regrow time and value (and King plants are unchanged).
local now0={};for line in PlantsBefore:gmatch('[^\n]+')do local id,sec,reg,val,rar=line:match('^([^|]+)|([^|]+)|([^|]+)|([^|]+)|([^|]+)|')now0[id]={tonumber(sec),tonumber(reg),tonumber(val),rar}end
local changed,total={},0
for id,row in pairs(now0)do total+=1;local d=Config.GardenPlants[id]
 if not d or d.Seconds~=row[1]or d.RegrowSeconds~=row[2]or d.Value~=row[3]or d.Rarity~=row[4]then changed[#changed+1]=id end end
table.sort(changed)
-- R148: the roster change promoted Fire Pepper (Rare -> Mythic) and Moon Melon (Rare -> Legendary): they, and only they, differ (test_roster.luau checks the new numbers)
check(total==62 and table.concat(changed,',')=='FirePepperSeed,MoonflowerSeed',('the 62 plants that existed before keep Seconds / RegrowSeconds / Value / Rarity, except the two promoted seeds (%s)'):format(table.concat(changed,', ')))
local nPlants=0;for _ in pairs(Config.GardenPlants)do nPlants+=1 end
check(nPlants==65,'65 plants: the 62 old ones, the Verity plant and (R148) Aloe and Sand Fruit')
local P2=Config.GardenPlants.PulsarStarfruitSeed;local S2=Config.GardenPlants.SolarStarfruitSeed;local M2=Config.GardenPlants.PrismMonarchSeed
check(P2.Seconds==14400 and P2.Value==9e10 and S2.Seconds==10800 and M2.Seconds==14000,'King plants: Pulsar 14400 s / 9e10, Solar 10800 s, Prism Monarch 14000 s')
local cands=Hour.Candidates();local plain=table.concat(cands,',')
local fohNow={};for id in FohBefore:gmatch('[^,]+')do fohNow[#fohNow+1]=id end;fohNow[#fohNow+1]='DesertAloeSeed';fohNow[#fohNow+1]='SandFruitSeed';table.sort(fohNow)
check(#cands==53 and plain==table.concat(fohNow,',')and not table.find(cands,'VeritySeed'),'Fruit of the Hour: the same candidates plus (R148) Aloe and Sand Fruit = 53 (no Verity)')
local seenVerity=false;for h=0,24*500 do if Hour.At(h*3600).SeedId=='VeritySeed'then seenVerity=true end end
check(not seenVerity,'and 500 days of hourly picks never choose the Verity fruit')

end
-- 2. Odds -----------------------------------------------------------------------------------------------------------
local expected={VeritySeed=1}
local secrets={'SilentFrostbellSeed','ObsidianMawSeed','StarfruitSeed','HollowGeodeSeed','BlackoutBloomSeed'}
local cosmics={'MirageFigSeed','PolarStarbloomSeed','SupernovaBloomSeed','OrbitLotusSeed','StormSovereignSeed'}
for _,id in ipairs(secrets)do expected[id]=18.715950 end;for _,id in ipairs(cosmics)do expected[id]=.985050 end
expected.PlasmaPepperSeed=.238794;expected.HoloMelonSeed=.129347;expected.PrismLotusSeed=.079598;expected.HoloAppleTreeSeed=.034824;expected.NebulaVineSeed=.012437
local exact={VeritySeed=1} -- the same odds from the formulas (not rounded to 6 digits): what the tooltip shows
for _,id in ipairs(secrets)do exact[id]=.99*.995*.95/5*100 end;for _,id in ipairs(cosmics)do exact[id]=.99*.995*.05/5*100 end
for _,m in ipairs(Mech.Seeds)do if m.Rarity~='King'then exact[m.Id]=.99*.005*m.Chance/99.5*100 end end
for _,id in ipairs(secrets)do check(Rules.GetRarity(id)=='Secret','(real module) '..id..' is Secret')end
for _,id in ipairs(cosmics)do check(Rules.GetRarity(id)=='Cosmic','(real module) '..id..' is Cosmic')end
local function oddsFor(version,luck)return Rules.SeedOdds(Config,7,'VerityReliquary',luck,version)end
local function matches(o)
 for id,p in pairs(expected)do if not o[id]or math.abs(o[id]-p)>6e-7 then return false,id end end
 for id in pairs(o)do if expected[id]==nil then return false,id end end
 return true
end
for _,version in ipairs({'none',0,81,112,137,99})do
 local o=oddsFor(version~='none'and version or nil,1)
 local ok,which=matches(o)
 check(ok and near(sum(o),100,1e-12),('Verity odds equal the table and add up to 100 for version %s (%s, total %.12f)'):format(tostring(version),tostring(which),sum(o)))
end
check(matches(oddsFor(137,50000000))and matches(oddsFor(137,nil))and matches(oddsFor(137,3.5)),'boots luck never changes the Verity pack')
local formula=.99*.995*.95/5*100
check(near(oddsFor(137)['SilentFrostbellSeed'],formula,1e-13)and near(oddsFor(137)['MirageFigSeed'],.99*.995*.05/5*100,1e-13)
 and near(oddsFor(137)['PlasmaPepperSeed'],.99*.005*48/99.5*100,1e-13)and oddsFor(137)['VeritySeed']==1,'exact formulas: Secret .99*.995*.95/5, Cosmic .99*.995*.05/5, Mech .99*.005*Chance/99.5, Verity 1')
check(oddsFor(137)['CrowncoreTreeSeed']==nil and oddsFor(137)['WinterCrownwoodSeed']==nil,'no Crowncore and no King but the Verity seed')
check(next(Rules.SeedOdds(Config,3,'VerityReliquary',1,137))==nil and next(Rules.SeedOdds(Config,8,'VerityReliquary',1,137))==nil,'a Verity pack outside stage 7 has no odds')
check(Odds.Format(oddsFor(137).VeritySeed)=='1/100','Verity reads 1/100')
-- The Void pack and its pool: exactly as before.
do
local function sameOdds(a,b)
 for id,p in pairs(a)do if not near(b[id],p,1e-12)then return false,id end end
 for id in pairs(b)do if a[id]==nil then return false,id end end
 return true
end
for _,key in ipairs({'nil',0,81,112,137})do
 local o=Rules.SeedOdds(Config,7,'EclipseReliquary',1,key~='nil'and key or nil)
 local ok,which=sameOdds(o,VoidBefore[key])
 local n=0;for _ in pairs(o)do n+=1 end
 check(ok and n==21 and o.VeritySeed==nil,('Void odds for version %s equal the snapshot of the unmodified code (21 seeds, no Verity) %s'):format(key,tostring(which or'')))
end
local direct,all=Void.Pools(Config,Rules)
local ids,dids={},{};for _,s in ipairs(all)do ids[#ids+1]=s.Id end;for _,s in ipairs(direct)do dids[#dids+1]=s.Id..':'..Rules.GetRarity(s.Id)end
check(table.concat(ids,' ')==VoidPoolBefore and table.concat(dids,' ')==VoidDirectBefore,'the Void pools are the snapshot lists, in the same order (no Verity)')
local rp={};for _,s in ipairs(Rules.RewardPool(Config,7,'EclipseReliquary'))do rp[#rp+1]=s.Id end
check(table.concat(rp,' ')==VoidPoolBefore,'Void RewardPool has no Verity')
-- Pools of the Verity pack.
local vdirect,vall=VPO.Pools(Config,Rules)
local names={};for _,s in ipairs(vall)do names[#names+1]=s.Id end
check(#vdirect==10 and #vall==16 and vall[1].Id=='VeritySeed'and not table.find(names,'CrowncoreTreeSeed'),'Verity pools: direct 10 (5 Secret + 5 Cosmic), all 16 (Verity seed first, no Crowncore)')
local kings=0;for _,s in ipairs(vall)do if Rules.GetRarity(s.Id)=='King'then kings+=1 end end
check(kings==1,'the only King in the Verity pack is the Verity seed')
local rpv=Rules.RewardPool(Config,7,'VerityReliquary');check(#rpv==16 and rpv[1].Id=='VeritySeed'and rpv[#rpv].Id=='NebulaVineSeed','Verity RewardPool = Verity seed, direct seeds, Mech seeds (tooltip order)')
check(Rules.RewardPool(Config,7,'Pack01')~=nil and #Rules.RewardPool(Config,8,'MechLimited')==6,'other pools untouched')

end
-- 3. Rolls ----------------------------------------------------------------------------------------------------------
do
local s0,r0=Rules.Roll(Config,7,drawConstant(0),1,'VerityReliquary',137)
check(s0 and s0.Id=='VeritySeed'and r0=='King','a forced draw (0) gives the Verity seed, rarity King')
local s1=Rules.Roll(Config,7,drawConstant(.0099),1,'VerityReliquary',137);local s2,r2=Rules.Roll(Config,7,drawConstant(.5),1,'VerityReliquary',112)
check(s1 and s1.Id=='VeritySeed'and s2 and s2.Id~='VeritySeed'and r2=='Secret','draw .0099 = Verity, draw .5 is not (Secret)')
local sHi,rHi=Rules.Roll(Config,7,drawConstant(.999999),1,'VerityReliquary',137)
check(sHi and sHi.Id=='BlackoutBloomSeed'and rHi=='Secret','the highest draw: the last Secret seed')
check(Rules.Roll(Config,7,.5,1,'VerityReliquary',137)==nil and Rules.Roll(Config,7,'x',1,'VerityReliquary',137)==nil and Rules.Roll(Config,7,nil,1,'VerityReliquary',137)==nil,'one number (not a draw function) rolls nothing')
check(Rules.Roll(Config,3,drawConstant(0),1,'VerityReliquary',137)==nil and Rules.Roll(Config,9,drawConstant(0),1,'VerityReliquary',137)==nil,'a Verity pack at another stage rolls nothing')
-- 2M rolls.
math.randomseed(147)
local rolls=2000000;local got={};local bad,nilCount=0,0
local draw=math.random
local calls=0;local counting=function()calls+=1;return draw()end
for _=1,rolls do
 local seed,rarity=Rules.Roll(Config,7,counting,1,'VerityReliquary',137)
 if not seed then nilCount+=1 else
  got[seed.Id]=(got[seed.Id]or 0)+1
  if expected[seed.Id]==nil or(Rules.GetRarity(seed.Id)=='King'and seed.Id~='VeritySeed')or rarity~=Rules.GetRarity(seed.Id)then bad+=1 end
 end
end
local pct=function(id)return(got[id]or 0)/rolls*100 end
check(nilCount==0 and bad==0 and got.CrowncoreTreeSeed==nil,'2M rolls: never nothing, never Crowncore, never a King but the Verity seed, only the 16 seeds, rarity as listed')
check(math.abs(pct('VeritySeed')-1)<=.05,('2M rolls: Verity %.4f%% (1 +- .05)'):format(pct('VeritySeed')))
local mechPct=0;for _,id in ipairs({'PlasmaPepperSeed','HoloMelonSeed','PrismLotusSeed','HoloAppleTreeSeed','NebulaVineSeed'})do mechPct+=pct(id)end
check(math.abs(mechPct-.495)<=.04,('2M rolls: Mech %.4f%% (~.495)'):format(mechPct))
local worst=0;for id,p in pairs(expected)do local err=math.abs(pct(id)-p);local tol=p>10 and .15 or(p>.5 and .05 or(p>.1 and .02 or .012));if err>tol then worst=worst+1;print('  off: '..id..' '..pct(id)..' vs '..p)end end
check(worst==0,'2M rolls: every seed within its tolerance of the table (Secret 18.716, Cosmic .985, Mech .239 .129 .080 .035 .012)')
print(('  2M rolls: Verity %.4f%% | Mech %.4f%% | Secret %.3f%% .. %.3f%% | Cosmic %.4f%% .. %.4f%% | %.2f draws per roll'):format(pct('VeritySeed'),mechPct,
 math.min(pct('SilentFrostbellSeed'),pct('ObsidianMawSeed'),pct('StarfruitSeed'),pct('HollowGeodeSeed'),pct('BlackoutBloomSeed')),math.max(pct('SilentFrostbellSeed'),pct('ObsidianMawSeed'),pct('StarfruitSeed'),pct('HollowGeodeSeed'),pct('BlackoutBloomSeed')),
 math.min(pct('MirageFigSeed'),pct('PolarStarbloomSeed'),pct('SupernovaBloomSeed'),pct('OrbitLotusSeed'),pct('StormSovereignSeed')),math.max(pct('MirageFigSeed'),pct('PolarStarbloomSeed'),pct('SupernovaBloomSeed'),pct('OrbitLotusSeed'),pct('StormSovereignSeed')),calls/rolls))
-- No other pack ever gives the Verity seed (and the Void pack stays Void).
local leaks=0
for _,variant in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do
 for stage=1,7 do for _=1,300 do local seed=Rules.Roll(Config,stage,draw,1,variant,137);if seed and seed.Id=='VeritySeed'then leaks+=1 end end
  for _=1,100 do local seed=Rules.Roll(Config,stage,draw,5,variant,112);if seed and seed.Id=='VeritySeed'then leaks+=1 end end
  for _=1,50 do local seed=Rules.Roll(Config,stage,draw(),1,variant,81);if seed and seed.Id=='VeritySeed'then leaks+=1 end end end
end
for _=1,300000 do local seed=Rules.Roll(Config,7,draw,1,'EclipseReliquary',137);if seed and seed.Id=='VeritySeed'then leaks+=1 end end
for _=1,20000 do local seed=Rules.Roll(Config,8,draw(),1,'MechLimited',81);if seed and seed.Id=='VeritySeed'then leaks+=1 end end
check(leaks==0 and Rules.Roll(Config,9,draw,1,'Pack01',137)==nil and Rules.Roll(Config,9,draw,1,'EclipseReliquary',137)==nil,'no world pack, Void pack or Mech pack ever gives the Verity seed')
local mechLast=Rules.Roll(Config,8,.999999,1,'MechLimited',81)
check(mechLast and mechLast.Id=='CrowncoreTreeSeed','the Mech pack still gives the Crowncore Tree')
local void0=Rules.Roll(Config,7,drawConstant(.5),1,'EclipseReliquary',137)
check(void0~=nil and void0.Id~='VeritySeed','a Void pack still rolls the Void pool')

end
-- 4. PlayerDataService --------------------------------------------------------------------------------------------
local Map={GetStageAccent=function(_,s)return R.Color3.new(.5,.5,s/10)end}
local shown={}
local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local PDS=server('PlayerDataService')
local Data=PDS.new(Config,Map,Notes)
R.clock=20000*86400+3600
local function makePlayer(id,name,data)
 data=data or Data
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p;order[#order+1]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 data:PreparePlayer(p);assert(data:Load(p),'load '..name)
 return p
end
local A=makePlayer(701,'Ava')
A:SetAttribute('PaidRandomAllowed',true) -- (the fixture Void pack is a paid random item; this account may open it)
local function find(player,id)for i,r in ipairs(Data:GetChestRecords(player))do if r.Id==id then return r,i end end end
local function snapshotBag()local t={};for i,r in ipairs(Data:GetChestRecords(A))do t[i]=r.Id..'|'..r.BagVariant..'|'..tostring(r.Kind)..'|'..tostring(r.ChestNumber)end;return table.concat(t,';')..'#'..tostring(A:GetAttribute('ChestInventorySerial'))..'#'..tostring(A:GetAttribute('SeedInventoryRevision'))end
local filler=Data:AddChest(A,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=137})
local void1=Data:AddChest(A,{Stage=7,BagVariant='EclipseReliquary',PackSize=3.5,PackMutation='Gold',Weather='Drippy+Frosted',WeatherCheckedEvent='12:Drippy',OddsVersion=137})
void1.PaidRandom=true
local pack6=Data:AddChest(A,{Stage=2,BagVariant='Pack06',PackSize=1,PackMutation='None',OddsVersion=137})
local void2=Data:AddChest(A,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=137})
local mechPack=Data:AddChest(A,{Stage=8,BagVariant='MechLimited',PackSize=1,PackMutation='None'})
check(void1.BagVariant=='EclipseReliquary'and void1.Weather=='Drippy+Frosted'and void1.WeatherCheckedEvent=='12:Drippy','fixture: a Gold 3.5x Void pack with weather')
local vp1=Data:AddChest(A,{Stage=7,BagVariant='VerityReliquary',PackSize=2,PackMutation='Diamond',OddsVersion=137})
check(vp1 and vp1.BagVariant=='VerityReliquary'and vp1.Stage==7 and vp1.OddsVersion==137 and vp1.SeedScale==Rules.NewSeedScale(7,'VerityReliquary',2),'AddChest keeps the Verity variant (not Standard)')
local serial0=A:GetAttribute('ChestInventorySerial');local count0=#Data:GetChestRecords(A)
local oldIndex=select(2,find(A,void1.Id));local oldId=void1.Id
Data.StudioPackRewards=setmetatable({[A]={[void1.Id]='SilentFrostbellSeed',[void2.Id]='StarfruitSeed'}},{__mode='k'})
local rev0=A:GetAttribute('SeedInventoryRevision')
local converted,why=Data:ConvertVoidPack(A,void1.Id)
local newIndex=converted and select(2,find(A,converted.Id))
check(converted~=nil,'Void -> Verity works ('..tostring(why)..')')
check(newIndex==oldIndex and #Data:GetChestRecords(A)==count0,'it takes the same slot in the bag ('..tostring(oldIndex)..' -> '..tostring(newIndex)..'); the bag count is unchanged')
check(converted.Id~=oldId and converted.Id==string.format('%d_%d',A.UserId,serial0+1)and converted.ChestNumber==serial0+1 and A:GetAttribute('ChestInventorySerial')==serial0+1,'a new Id from the serial ('..tostring(converted.Id)..'), serial +1')
check(find(A,oldId)==nil and Data:HasChest(A,converted.Id)and not Data:HasChest(A,oldId),'the old Id is gone')
check(converted.Kind=='Pack'and converted.BagVariant=='VerityReliquary'and converted.Stage==7 and converted.OddsVersion==Rules.OddsVersion,'a Verity pack: stage 7, odds version '..tostring(converted.OddsVersion))
check(converted.PackSize==3.5 and converted.PackMutation=='Gold'and converted.Weather=='Drippy+Frosted'and converted.WeatherCheckedEvent=='12:Drippy'and converted.PaidRandom==true,'size, coat, weather, weather check and the paid flag are kept')
check(converted.SeedScale==Rules.NewSeedScale(7,'VerityReliquary',3.5)and converted.AccentColor==void1.AccentColor and converted.RateBoost==nil,'seed scale from the Verity variant, accent colour kept, no rate boost')
check(Data.StudioPackRewards[A][oldId]==nil and Data.StudioPackRewards[A][void2.Id]=='StarfruitSeed','an owner-test guarantee on the old pack is cleared (and only that one)')
check(A:GetAttribute('SeedInventoryRevision')==rev0+1 and A:GetAttribute('SeedInventoryCount')==count0 and Data.Dirty[A]==true,'inventory notified (revision +1), save marked dirty')
check(find(A,void2.Id)==void2 and find(A,filler.Id)==filler and find(A,pack6.Id)==pack6,'other packs untouched')
-- Refusals change nothing.
do
local before=snapshotBag()
local refusals={pack6.Id,mechPack.Id,vp1.Id,converted.Id,filler.Id,'nope','',string.rep('x',200)}
local allRefused=true;local reasons={}
for _,id in ipairs(refusals)do local r,why2=Data:ConvertVoidPack(A,id);if r~=nil or type(why2)~='string'then allRefused=false end;reasons[#reasons+1]=tostring(why2)end
for _,bad in ipairs({5,true,{}})do local r=Data:ConvertVoidPack(A,bad);if r~=nil then allRefused=false end end
local r3=Data:ConvertVoidPack(A,nil);if r3~=nil then allRefused=false end
check(allRefused,'Pack06, Mech, Verity, unknown, empty and non-string ids are all refused with a reason ('..reasons[1]..' | '..reasons[3]..' | '..reasons[6]..')')
-- R152: the reasons are in Verity's voice (they reach her window as they are): not a Void pack / not in the bag any more / not an id at all
check(reasons[1]=='ONLY A VOID PACK WORKS FOR ME!'and reasons[2]=='ONLY A VOID PACK WORKS FOR ME!'and reasons[6]=='THAT PACK LEFT YOUR BAG! TRY AGAIN'and reasons[8]=='HMM, I CAN\'T USE THAT PACK','the reasons: "'..reasons[1]..'" / "'..reasons[6]..'" / "'..reasons[8]..'"')
check(snapshotBag()==before and find(A,pack6.Id)==pack6,'...and nothing changed (bag order, serial and revision all the same)')
local seedRec={Id='701_seedfix',Kind='Seed',BagVariant='EclipseReliquary',Stage=7,ChestNumber=900,SeedId='MirageFigSeed',SeedName='Mirage Fig Seed',SeedEmoji='x',ChestName='x',AccentColor=R.Color3.new(1,1,1),PackSize=1,PackMutation='None',SeedScale=1}
table.insert(Data:GetChestRecords(A),seedRec)
check(Data:ConvertVoidPack(A,seedRec.Id)==nil and seedRec.Kind=='Seed','an opened Void seed (no longer a pack) is refused')
table.remove(Data:GetChestRecords(A))
local odd=Data:AddChest(A,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=137});odd.Stage=3
check(Data:ConvertVoidPack(A,odd.Id)==nil and odd.BagVariant=='EclipseReliquary'and odd.Stage==3,'a "Void" record that is not stage 7 is refused')
Data:RemoveChest(A,odd.Id)
local B0=makePlayer(702,'Ben');Data.Loaded[B0]=nil
check(Data:ConvertVoidPack(B0,void2.Id)==nil and find(A,void2.Id)==void2,'a player whose data is not loaded gets nothing')
check(select(2,Data:ConvertVoidPack(B0,void2.Id))=='HOLD ON, YOUR DATA IS LOADING!','(R152: "HOLD ON, YOUR DATA IS LOADING!")');Data.Loaded[B0]=true
end
-- It works with a full bag.
do
 local C=makePlayer(703,'Cy');local full=Config.MaxSavedChests
 local firstVoid
 for i=1,full do local rec=Data:AddChest(C,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=137});if i==full then firstVoid=rec end end
 check(#Data:GetChestRecords(C)==full and not Data:AddChest(C,{Stage=1,BagVariant='Pack01'}),'(fixture: a full bag)')
 local ok=Data:ConvertVoidPack(C,firstVoid.Id)
 check(ok and #Data:GetChestRecords(C)==full,'converting works with a full bag (it replaces, it does not add)')
end
-- Save / load round trips.
do
local saved=Data:_buildSaveData(A)
local row;for _,r in ipairs(saved.Seeds)do if r.Id==converted.Id then row=r end end
check(row and row.BagVariant=='VerityReliquary'and row.Stage==7 and row.PackSize==3.5 and row.PackMutation=='Gold'and row.Weather=='Drippy+Frosted'and row.OddsVersion==Rules.OddsVersion and row.PaidRandom==true and row.Kind=='Pack','the saved row keeps the variant, size, coat, weather, odds version and paid flag')
local back=Data:_canonicalizeSeedRecord(Data:_decodeSavedSeedRecord(A,row,1))
check(back.BagVariant=='VerityReliquary'and back.Stage==7 and back.OddsVersion==Rules.OddsVersion and back.PackSize==3.5 and back.SeedScale==converted.SeedScale,'it decodes back as a Verity pack (not Standard)')
check(Data:Save(A,'test',true),'real save')
local Data2=PDS.new(Config,Map,Notes)
local A2=makePlayer(701,'Ava',Data2)
local reloaded;for _,r in ipairs(Data2:GetChestRecords(A2))do if r.Id==converted.Id then reloaded=r end end
local verityCount=0;for _,r in ipairs(Data2:GetChestRecords(A2))do if r.BagVariant=='VerityReliquary'then verityCount+=1 end end
check(reloaded and reloaded.BagVariant=='VerityReliquary'and reloaded.OddsVersion==Rules.OddsVersion and reloaded.PackMutation=='Gold'and reloaded.Weather=='Drippy+Frosted'and verityCount==2,'a real save and load keeps both Verity packs')
end
-- Gifts.
local Gifts=server('FruitGiftService')
local Bn=makePlayer(704,'Bea')
Bn:SetAttribute('PaidTradingAllowed',true);Bn:SetAttribute('PaidRandomAllowed',true)
local giftRow=Data:SerializeSeedRecord(converted)
local decoded=Data:DecodeGiftedSeed(Bn,giftRow)
check(decoded and decoded.BagVariant=='VerityReliquary'and decoded.Stage==7 and decoded.Kind=='Pack'and decoded.OddsVersion==Rules.OddsVersion and decoded.PackSize==3.5,'a gifted Verity pack decodes as a Verity pack')
local synced=0;local giver={Data=Data,Chests={SyncTools=function()synced+=1 end}}
local staged=table.clone(giftRow);staged.Id='gift-verity-pack'
local gotOk,res=pcall(Gifts._receiveSeed,giver,Bn,Data.Gardens[Bn]or{},{},'gift-v1',{Seed=staged})
local gotPack;for _,r in ipairs(Data:GetChestRecords(Bn))do if r.Id=='gift-verity-pack'then gotPack=r end end
check(gotOk and res==true and gotPack and gotPack.BagVariant=='VerityReliquary'and gotPack.PackMutation=='Gold','the recipient receives it as a Verity pack ('..tostring(res)..')')
local badStage=table.clone(giftRow);badStage.Stage=10
check(Data:DecodeGiftedSeed(Bn,badStage)==nil,'a gifted row with stage 10 is refused')
local clampRow=table.clone(giftRow);clampRow.BagVariant='Pack01';clampRow.Stage=9
local clamped=Data:DecodeGiftedSeed(Bn,clampRow)
check(clamped and clamped.Stage==7,'a gifted PACK claiming stage 9 is clamped to a real stage (7)')
-- Opening a Verity pack.
local open1,why1=Data:OpenSeedPack(A,converted.Id,drawConstant(0))
check(open1 and open1.Kind=='Seed'and open1.SeedId=='VeritySeed'and open1.Stage==9 and open1.Rarity=='King'and open1.Id==converted.Id and open1.BagVariant=='VerityReliquary','opening it with a forced draw gives the Verity seed at Stage 9 ('..tostring(why1)..')')
check(open1.PackSize==3.5 and open1.PackMutation=='Gold'and open1.Weather=='Drippy+Frosted'and open1.SeedScale==Rules.NewSeedScale(7,'VerityReliquary',3.5)and open1.SeedName=='Verity Seed','the seed keeps the pack size, coat, weather and seed size')
local discovered=Data:GetOrCreateDiscoveredSeeds(A):FindFirstChild('VeritySeed')
check(discovered and discovered.Value==true and Data:GetPremium(A).SeedRewards.VeritySeed==1e11,'discovered; the first-time index cash is 1e11')
local saved2=Data:_buildSaveData(A);local seedRow;for _,r in ipairs(saved2.Seeds)do if r.Id==open1.Id then seedRow=r end end
check(seedRow and seedRow.Stage==9 and seedRow.SeedId=='VeritySeed'and seedRow.Kind=='Seed','the saved row has Stage 9')
local seedBack=Data:_canonicalizeSeedRecord(Data:_decodeSavedSeedRecord(A,seedRow,1))
check(seedBack.Stage==9 and seedBack.SeedId=='VeritySeed'and seedBack.SeedName=='Verity Seed','it decodes back at Stage 9 (not clamped to 7)')
check(Data:Save(A,'test2',true),'real save (seed)')
local Data3=PDS.new(Config,Map,Notes);local A3=makePlayer(701,'Ava',Data3)
local seedLoaded;for _,r in ipairs(Data3:GetChestRecords(A3))do if r.Id==open1.Id then seedLoaded=r end end
check(seedLoaded and seedLoaded.Stage==9 and seedLoaded.SeedId=='VeritySeed'and seedLoaded.Kind=='Seed','a real save and load keeps Stage 9')
check(Data3:GetOrCreateDiscoveredSeeds(A3):FindFirstChild('VeritySeed')~=nil and Data3:GetPremium(A3).SeedRewards.VeritySeed==1e11,'and the discovery and the pending index cash')
local seedGift=Data:DecodeGiftedSeed(Bn,Data:SerializeSeedRecord(open1))
check(seedGift and seedGift.Stage==9 and seedGift.SeedId=='VeritySeed'and seedGift.Kind=='Seed','a gifted Verity seed keeps Stage 9')
local stagedSeed=Data:SerializeSeedRecord(open1);stagedSeed.Id='gift-verity-seed'
local ok2,res2=pcall(Gifts._receiveSeed,giver,Bn,Data.Gardens[Bn]or{},{},'gift-v2',{Seed=stagedSeed})
local gotSeed;for _,r in ipairs(Data:GetChestRecords(Bn))do if r.Id=='gift-verity-seed'then gotSeed=r end end
check(ok2 and res2==true and gotSeed and gotSeed.Stage==9 and gotSeed.SeedId=='VeritySeed'and Data:GetOrCreateDiscoveredSeeds(Bn):FindFirstChild('VeritySeed')~=nil,'the recipient gets the seed at Stage 9 and discovers it')
local inv=Data:GetSeedInventory(A);local group
for _,g in ipairs(inv)do if g.SeedId=='VeritySeed'then group=g end end
check(group and group.Stage==9 and group.BiomeName=='Verity'and group.Rarity=='King'and group.Plantable==true and group.GrowSeconds==14400,'the bag lists it: Verity category, King, plantable, 4 h')
-- A normal pack roll from the Verity pack (not forced) gives one of the 16 seeds.
local more=Data:AddChest(A,{Stage=7,BagVariant='VerityReliquary',PackSize=1,PackMutation='None',OddsVersion=137})
local open2=Data:OpenSeedPack(A,more.Id,drawConstant(.5))
check(open2 and open2.Kind=='Seed'and expected[open2.SeedId]~=nil and open2.SeedId~='VeritySeed'and open2.Stage==Rules.SeedDesignById[open2.SeedId].SaveStage,'an ordinary roll gives one of the 16 seeds at its own category ('..tostring(open2 and open2.SeedId)..' stage '..tostring(open2 and open2.Stage)..')')
local more2=Data:AddChest(A,{Stage=7,BagVariant='VerityReliquary',PackSize=1,PackMutation='None',OddsVersion=137})
local open3=Data:OpenSeedPack(A,more2.Id,drawConstant(0))
check(open3 and open3.SeedId=='VeritySeed'and Data:GetPremium(A).SeedRewards.VeritySeed==1e11+2e10,'a second Verity seed pays the repeat cash (2e10) on top ('..tostring(Data:GetPremium(A).SeedRewards.VeritySeed)..')')
-- The Void pack still gives Void seeds and a Mech seed at Stage 8.
local vopen=Data:OpenSeedPack(A,void2.Id,drawConstant(.5))
check(vopen and vopen.SeedId~='VeritySeed'and vopen.BagVariant=='EclipseReliquary'and vopen.Stage==Rules.SeedDesignById[vopen.SeedId].SaveStage,'a Void pack opens as before ('..tostring(vopen and vopen.SeedId)..')')
-- Planting and harvesting the Verity seed.
do
local nowT=math.floor(R.clock)
local planted,crop=Data:PlantSeed(A,1,open1.Id,{OffsetX=0,OffsetZ=0},nowT)
check(planted and crop.SeedId=='VeritySeed'and crop.ReadyAt-crop.PlantedAt==14400 and crop.Value==9e10,'planting works: ready in 14400 s, base value 9e10 ('..tostring(crop)..')')
check(find(A,open1.Id)==nil,'the seed left the bag')
local early,earlyWhy=Data:HarvestPlant(A,1,crop.Id,nowT+14399)
check(not early,'too early: '..tostring(earlyWhy))
local okH,fruit=Data:HarvestPlant(A,1,crop.Id,nowT+14400)
check(okH and fruit.SeedId=='VeritySeed'and fruit.Value>=4e10 and fruit.Value<=9e12,('harvesting works: one fruit worth %.4g (cap 9e12)'):format(tonumber(fruit and fruit.Value)or 0))
local growing=Data.Gardens[A].Plots['1'][1]
check(growing and growing.FruitStates and growing.FruitStates['1'].ReadyAt==nowT+14400+1500,'it regrows: the next fruit in 1500 s (ReadyAt +1500)')
local tooSoon=Data:HarvestPlant(A,1,crop.Id,nowT+14400+1499);local again,fruit2=Data:HarvestPlant(A,1,crop.Id,nowT+14400+1500)
check(not tooSoon and again and fruit2.SeedId=='VeritySeed','second fruit only after 1500 s')
check(Data:GetPremium(A).Plants.VeritySeed==true,'the adult plant is discovered (Index)')
local gardenSave=Data:CopyGarden(Data.Gardens[A]);local decodedGarden=Data:DecodeGarden(gardenSave)
check(decodedGarden~=nil and #decodedGarden.Harvests==2,'the garden with a Verity plant and fruit saves and loads')
local maxValue=0;for _,h in ipairs(Data.Gardens[A].Harvests)do maxValue=math.max(maxValue,h.Value)end
check(maxValue<=9e12,'harvest records stay within the 9e12 cap')
-- The Index category 9.
local seeds9,plants9,total9=Data:IndexProgress(A,9)
check(seeds9==1 and plants9==1 and total9==1 and Data:BiomeComplete(A,9),'Index 9: 1 seed, 1 plant, complete')
local baseChance=Rules.SeedOdds(Config,Rules.ObtainableStage('VeritySeed')or 9,'Pack01',1)['VeritySeed']
check(baseChance==1 and Odds.Format(baseChance)=='1/100','the catalog BaseChance of the Verity seed is 1 (percent) and the Index chip reads '..Odds.Format(baseChance))
local cs=W.B.ChestService
check(cs:find("PackRules.SeedOdds(config,PackRules.ObtainableStage(seed.Id)or stage,'Pack01',1)[seed.Id]",1,true)~=nil,'(ChestService builds BaseChance exactly that way)')
check(Rules.SeedOdds(Config,9,'Pack01',1,137).VeritySeed==1 and Rules.SeedOdds(Config,9,'Pack06',50,112).VeritySeed==1 and next(Rules.SeedOdds(Config,9,'Pack01',1,137),'VeritySeed')==nil,'stage 9 odds: only the Verity seed, 1%')
local c1,cWhy=Data:ClaimIndexBiomeHalf(A,9);local c2=Data:ClaimIndexBiomeHalf(A,9)
check(c1 and not c2,'half reward of category 9 claims once ('..tostring(cWhy)..')')
local fullOk,fullWhy=Data:ClaimIndexBiome(A,9);local fullAgain=Data:ClaimIndexBiome(A,9)
check(fullOk and not fullAgain and A:GetAttribute('IndexBiomeReward9')==true and A:GetAttribute('IndexBiomeHalfReward9')==true,'completion reward of category 9 claims once, the attributes follow ('..tostring(fullWhy)..')')
local gemAmounts={};for _,rc in ipairs(Data.Gardens[A].PendingSales or{})do if rc.Currency=='Gems'then gemAmounts[#gemAmounts+1]=rc.Amount end end
check(table.concat(gemAmounts,',')=='10,100','the Gems: 10 (half) and 100 (complete)')
check(not Data:ClaimIndexBiome(A,10)and not Data:ClaimIndexBiome(A,0)and not Data:ClaimIndexBiomeHalf(A,10)and not Data:ClaimIndexBiomeHalf(A,'9'),'categories outside 1-9 are refused')
local cashOk=Data:ClaimIndexSeed(A,'VeritySeed')
local cashAmounts={};for _,rc in ipairs(Data.Gardens[A].PendingSales or{})do if rc.Currency=='Cash'then cashAmounts[#cashAmounts+1]=rc.Amount end end
check(cashOk and cashAmounts[#cashAmounts]==1.2e11,'the Verity seed index cash (1e11 + 2e10) queues for collection')
local premiumSave=Data:_buildSaveData(A).Premium
check(premiumSave.Biomes['9']==true and premiumSave.BiomeHalfRewards['9']==true,'the claims are in the saved premium state')
local PP=server('PremiumProgress');local decPrem=PP.Decode(premiumSave)
check(decPrem~=nil and decPrem.Biomes['9']==true and decPrem.BiomeHalfRewards['9']==true,'and PremiumProgress.Decode accepts category 9')
local badPrem=table.clone(premiumSave);badPrem.Biomes=table.clone(premiumSave.Biomes);badPrem.Biomes['10']=true
local badPrem2=table.clone(premiumSave);badPrem2.BiomeBackpay81={['9']=5}
local badPrem3=table.clone(premiumSave);badPrem3.BiomeBackpay81={['10']=5}
check(PP.Decode(badPrem)==nil and PP.Decode(badPrem2)~=nil and PP.Decode(badPrem3)==nil,'category 10 is rejected, a category-9 backpay entry is accepted')
end
-- 5/6. ChestService.ConvertVoidPack ---------------------------------------------------------------------------------
local Chests=server('ChestService')
local fake=setmetatable({PlayerData=Data,Config=Config,Openings={}},{__index=Chests})
local D=makePlayer(710,'Dee')
local f1=Data:AddChest(D,{Stage=1,BagVariant='Pack01',PackSize=1,PackMutation='None',OddsVersion=137})
local dv1=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=2,PackMutation='Gold',Weather='Frosted',OddsVersion=137})
local d6=Data:AddChest(D,{Stage=3,BagVariant='Pack06',PackSize=1,PackMutation='None',OddsVersion=137})
local dv2=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=4,PackMutation='None',OddsVersion=137})
Chests.SyncTools(fake,D)
local function toolFor(player,id)
 for _,container in ipairs({player:FindFirstChildOfClass('Backpack'),player.Character})do if container then for _,t in ipairs(container:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedInventoryId')==id then return t end end end end
end
local backpack=D:FindFirstChildOfClass('Backpack')
local function packTools()local n=0;for _,t in ipairs(backpack:GetChildren())do if t:IsA('Tool')and t:GetAttribute('SeedPackTool')then n+=1 end end;return n end
check(toolFor(D,dv1.Id)and toolFor(D,dv1.Id):GetAttribute('BagVariant')=='EclipseReliquary'and packTools()==4,'(fixture: four pack tools, '..packTools()..')')
local r1,why1b=Chests.ConvertVoidPack(fake,D)
check(r1 and r1.BagVariant=='VerityReliquary'and r1.PackSize==2 and r1.PackMutation=='Gold'and select(2,find(D,r1.Id))==2 and find(D,dv2.Id)==dv2,'no id: the FIRST Void pack in the bag is converted ('..tostring(why1b)..')')
local nt=toolFor(D,r1.Id)
check(toolFor(D,dv1.Id)==nil and nt and nt:GetAttribute('BagVariant')=='VerityReliquary'and nt.Name=='Gold Verity Pack'and nt:GetAttribute('PackSize')==2 and packTools()==4,'the Tool is rebuilt for the Verity pack ('..tostring(nt and nt.Name)..'), the old one is gone')
-- A held Void pack is preferred.
local char=R.new('Model');char.Name='Dee';D.Character=char;char.Parent=R.new('Folder')
local heldTool=toolFor(D,dv2.Id);heldTool.Parent=char
local r2=Chests.ConvertVoidPack(fake,D)
check(r2 and r2.PackSize==4 and select(2,find(D,r2.Id))==4,'no id, a Void pack in the hand: that one is converted (not the first in the bag)')
check(toolFor(D,r2.Id)~=nil and toolFor(D,dv2.Id)==nil,'and its Tool is rebuilt')
local r3,why3=Chests.ConvertVoidPack(fake,D)
check(r3==nil and why3=='NO VOID PACK YET! GO STEAL ONE!','no Void pack left: refused, in Verity\'s voice ('..tostring(why3)..')') -- R152
-- With an id: the pack the NPC names.
local dv3=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='Diamond',OddsVersion=137})
local dv4=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=1.5,PackMutation='None',OddsVersion=137})
Chests.SyncTools(fake,D)
local bagBefore=snapshotBag()
local before2={};for i,r in ipairs(Data:GetChestRecords(D))do before2[i]=r.Id end
local rr,wwhy=Chests.ConvertVoidPack(fake,D,d6.Id)
local after2={};for i,r in ipairs(Data:GetChestRecords(D))do after2[i]=r.Id end
check(rr==nil and type(wwhy)=='string'and table.concat(before2,',')==table.concat(after2,',')and toolFor(D,d6.Id)~=nil,'a Pack06 id is refused, the bag and tools are unchanged ('..tostring(wwhy)..')')
check(Chests.ConvertVoidPack(fake,D,'nope')==nil and Chests.ConvertVoidPack(fake,D,r1.Id)==nil and Chests.ConvertVoidPack(fake,D,5)==nil,'an unknown id, an already converted pack and a non-string id are refused')
local rd=Chests.ConvertVoidPack(fake,D,dv4.Id)
check(rd and rd.PackSize==1.5 and find(D,dv3.Id)==dv3 and toolFor(D,dv3.Id)~=nil,'with an id, exactly that Void pack is converted')
-- An opening that has only been started is finished first.
local sub=toolFor(D,dv3.Id);sub.Parent=char
local bag=R.new('Model');local conn=sub.Equipped:Connect(function()end)
fake.Openings[D]={Tool=sub,Character=char,Connections={conn},Bag=bag,Committed=false,Clicks=2,LastClick=0}
local rUnc=Chests.ConvertVoidPack(fake,D,dv3.Id)
check(rUnc and rUnc.BagVariant=='VerityReliquary'and fake.Openings[D]==nil and bag._destroyed==true and conn.Connected==false,'an uncommitted opening of that pack is finished (bag removed, connections dropped), then it converts')
-- A committed opening of that pack is refused.
local dv5=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=137})
Chests.SyncTools(fake,D)
local committedTool=toolFor(D,dv5.Id);local bag2=R.new('Model')
local opening={Tool=committedTool,Character=char,Connections={},Bag=bag2,Committed=true,RewardId=dv5.Id}
fake.Openings[D]=opening
local rCom,whyCom=Chests.ConvertVoidPack(fake,D,dv5.Id)
check(rCom==nil and find(D,dv5.Id)==dv5 and dv5.BagVariant=='EclipseReliquary'and fake.Openings[D]==opening and not bag2._destroyed and committedTool.Parent~=nil,'a committed opening of that pack is refused and nothing changes ('..tostring(whyCom)..')')
check(whyCom=='PLEASE FINISH OPENING THAT PACK!','(R152: the reason is Verity\'s)')
local rCom2=Chests.ConvertVoidPack(fake,D)
check(rCom2==nil and find(D,dv5.Id)==dv5,'(also without an id: the committed pack is the one that would be picked)')
fake.Openings[D]=nil
-- A committed opening of ANOTHER pack does not block converting this one.
local dv6=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=137});Chests.SyncTools(fake,D)
fake.Openings[D]={Tool=toolFor(D,dv5.Id),Character=char,Connections={},Committed=true}
local rOther=Chests.ConvertVoidPack(fake,D,dv6.Id)
check(rOther and rOther.BagVariant=='VerityReliquary'and fake.Openings[D]~=nil and toolFor(D,dv5.Id)~=nil,'a reveal playing for another pack does not stop it (that Tool stays)')
fake.Openings[D]=nil
-- The hold tooltip of a Verity pack: the pack label, then every seed of the pool with its odds, in the pool's order.
local tip=toolFor(D,rOther.Id);fake.Openings[D]=true
Chests._holdPack(fake,D,tip);fake.Openings[D]=nil
local tipRows={};for line in tip.ToolTip:gmatch('[^\n]+')do tipRows[#tipRows+1]=line end
local _,poolAll=VPO.Pools(Config,Rules);local wantRows={Rules.PackLabel(7,'VerityReliquary',rOther.PackSize,rOther.PackMutation)}
for _,seed in ipairs(poolAll)do wantRows[#wantRows+1]=seed.Name..': '..Odds.Format(exact[seed.Id])end
check(tipRows[1]=='Verity Pack'and #tipRows==17,'the hold tooltip: "Verity Pack" and 16 seed rows ('..#tipRows..')')
check(table.concat(tipRows,'\n')==table.concat(wantRows,'\n'),'every row is "<seed>: <1/N>" from the table, in the pool order (Verity Seed first)')
check(tipRows[2]=='Verity Seed: 1/100'and tipRows[3]=='Mirage Fig Seed: '..Odds.Format(exact.MirageFigSeed)and tipRows[17]=='Nebula Vine Seed: '..Odds.Format(exact.NebulaVineSeed),'first rows: '..tostring(tipRows[2])..' | '..tostring(tipRows[3])..' ... '..tostring(tipRows[17]))
local text=tip.ToolTip
check(not text:find('Crowncore',1,true)and text:find('Plasma Pepper Seed: '..Odds.Format(exact.PlasmaPepperSeed),1,true)~=nil and text:find('Nebula Vine Seed: '..Odds.Format(exact.NebulaVineSeed),1,true)~=nil,'no Crowncore; Mech rows '..Odds.Format(exact.PlasmaPepperSeed)..' ... '..Odds.Format(exact.NebulaVineSeed))
local kingNames={};for _,id in ipairs({'SolarStarfruitSeed','WinterCrownwoodSeed','EmberEmperorSeed','PrismMonarchSeed','PulsarStarfruitSeed','CrowncoreTreeSeed'})do kingNames[#kingNames+1]=Config.GetSeedById(id).Name end
local anyKing=false;for _,n in ipairs(kingNames)do if text:find(n..':',1,true)then anyKing=true end end
check(not anyKing,'none of the six other King seeds is listed')
-- A Void pack's tooltip is as before (Kings and Crowncore included, no Verity).
local voidKeep=Data:AddChest(D,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=137});Chests.SyncTools(fake,D)
local vtool=toolFor(D,voidKeep.Id);Chests._holdPack(fake,D,vtool);local vrows={};for line in vtool.ToolTip:gmatch('[^\n]+')do vrows[#vrows+1]=line end
check(vrows[1]=='Void Pack'and #vrows==22 and vtool.ToolTip:find('Crowncore Tree Seed:',1,true)and not vtool.ToolTip:find('Verity',1,true),'a Void pack tooltip is unchanged: 21 seeds with the Kings and the Crowncore Tree, no Verity')
fake.Openings[D]=nil

-- 7. Owner commands --------------------------------------------------------------------------------------------------
do
local X=server('OwnerUpdateCommands82')
local ctx={Config=Config,Data=Data,Map={MapRoot=R.new('Folder')},Chase={IsPlayerBusy=function()return false end},Chests=setmetatable({IsOpening=function()return false end,SyncTools=function()end},{__index=Chests})}
check(X.Actions.verity==true and X.Actions.eclipse==true and X.Actions.void==true,'the verity command is registered (void / eclipse too)')
local okOdds,textOdds=X.Execute(ctx,D,'odds',{'verity'})
check(okOdds and textOdds:find('Verity Pack',1,true)and textOdds:find('Verity Seed: 1/100',1,true)and textOdds:find('Plasma Pepper Seed: '..Odds.Format(exact.PlasmaPepperSeed),1,true)and not textOdds:find('Crowncore Tree Seed',1,true),'odds verity shows the Verity pack odds')
local lineCount=0;for _ in textOdds:gmatch('[^\n]+')do lineCount+=1 end
check(lineCount==17,'odds verity: header + 16 seeds ('..lineCount..')')
local okOdds2,textOdds2=X.Execute(ctx,D,'odds',{'verity','50000'})
check(okOdds2 and select(2,textOdds2:gsub('Seed:',''))==16,'odds verity <luck> works and does not change anything')
check(not X.Execute(ctx,D,'odds',{'verity','1','2'})and not X.Execute(ctx,D,'odds',{'mech','mythic'}),'odds verity with too many words, and odds mech, are refused')
local okVoid,textVoid=X.Execute(ctx,D,'odds',{'event'})
check(okVoid and textVoid:find('Void Pack',1,true)and textVoid:find('Crowncore Tree Seed',1,true)and not textVoid:find('Verity',1,true),'odds event is still the Void pack')
local okSt,textSt=X.Execute(ctx,D,'odds',{'storm','verity'})
check(okSt and textSt:find('Verity Seed: 1/100',1,true),'odds <biome> verity also works (the Verity pack is a stage 7 pack)')
local nBag=#Data:GetChestRecords(D)
local okG,textG=X.Execute(ctx,D,'verity',{'3'})
local gv=0;for _,r in ipairs(Data:GetChestRecords(D))do if r.BagVariant=='VerityReliquary'and r.OddsVersion==Rules.OddsVersion and r.Stage==7 and r.Kind=='Pack'then gv+=1 end end
check(okG and #Data:GetChestRecords(D)==nBag+3 and gv>=3,'verity 3 adds three Verity packs ('..tostring(textG)..')')
check(not X.Execute(ctx,D,'verity',{'0'})and not X.Execute(ctx,D,'verity',{'21'})and not X.Execute(ctx,D,'verity',{'x'})and not X.Execute(ctx,D,'verity',{'1','2'})and #Data:GetChestRecords(D)==nBag+3,'verity 0, 21, x and two numbers are refused')
check(select(1,X.Execute(ctx,D,'verity',{}))and #Data:GetChestRecords(D)==nBag+4,'verity (no number) adds one')
local okE=X.Execute(ctx,D,'eclipse',{'2'});local ev=0;for _,r in ipairs(Data:GetChestRecords(D))do if r.BagVariant=='EclipseReliquary'and r.Kind=='Pack'then ev+=1 end end
check(okE and ev>=2 and select(1,X.Execute(ctx,D,'void',{'1'})),'void / eclipse still give Void packs')
check(not X.Execute(ctx,D,'packset',{'verity'})and not X.Execute(ctx,D,'packset',{'mech'}),'packset verity / mech are refused')
local okI,textI=X.Execute(ctx,D,'indexinfo',{'verity'})
check(okI and textI:find('Completion reward: 100 Gems',1,true),'indexinfo verity: the category-9 reward ('..tostring(textI)..')')
local okI2,textI2=X.Execute(ctx,D,'indexinfo',{'VeritySeed'})
check(okI2 and textI2:find('first 100000000000 Cash',1,true)~=nil and textI2:find('repeat 20000000000 Cash',1,true)~=nil,'indexinfo VeritySeed: first / repeat cash ('..tostring(textI2)..')')
-- rarepacks verity (Studio only).
local RPT=server('RarePackTests')
Run.IsStudio=function()return true end
local okR,textR=RPT.Grant(Data,D,'verity',D)
Run.IsStudio=function()return false end
local testPack;for _,r in ipairs(Data:GetChestRecords(D))do if r.Kind=='Pack'and RPT.Expected(Data,D,r.Id)=='VeritySeed'then testPack=r end end
check(okR and testPack and testPack.BagVariant=='VerityReliquary'and testPack.Stage==7,'rarepacks verity adds one TEST Verity pack ('..tostring(textR)..')')
local openTest=Data:OpenSeedPack(D,testPack.Id,drawConstant(.7))
check(openTest and openTest.SeedId=='VeritySeed'and openTest.Stage==9 and openTest.Rarity=='King'and RPT.Expected(Data,D,testPack.Id)==nil,'it reveals the Verity seed (Stage 9, King) and the guarantee is used up')
Run.IsStudio=function()return true end
local okR2=RPT.Grant(Data,D,'king',D);local okR3=RPT.Grant(Data,D,'nonsense',D)
Run.IsStudio=function()return false end
local kingTest;for _,r in ipairs(Data:GetChestRecords(D))do local e=RPT.Expected(Data,D,r.Id);if e and Rules.GetRarity(e)=='King'then kingTest=e end end
check(okR2 and kingTest~=nil and kingTest~='VeritySeed'and not okR3,'rarepacks king still picks the first King (not Verity); unknown selectors refused')
local Help=W.module('StudioTestHelp')
local helpHas={};for _,e in ipairs(Help)do if e[1]:find('/test verity',1,true)then helpHas.verity=true end;if e[1]:find('/test odds',1,true)and e[2]:find('odds verity',1,true)then helpHas.odds=true end
 if e[1]:find('/test rarepacks',1,true)and e[2]:find('rarepacks verity',1,true)then helpHas.rare=true end end
check(helpHas.verity and helpHas.odds and helpHas.rare,'StudioTestHelp has the verity, odds verity and rarepacks verity rows')
end
-- Sources: every stage table that Verity needs is 9 wide, and Void / world code did not change shape.
local pds=W.B.PlayerDataService;local pp=W.B.PremiumProgress
check(pp:find('1,8)',1,true)==nil and pp:find('for i=1,8 do',1,true)==nil and pp:find('1,9)',1,true)~=nil,'PremiumProgress: no 1..8 stage range left')
check(pds:find('saved.Stage > 8',1,true)==nil and pds:find('saved.Stage > 9',1,true)~=nil,'PlayerDataService gift stage limit is 9')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
