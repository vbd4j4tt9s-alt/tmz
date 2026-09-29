
local SOURCES={}
SOURCES['BalanceValues81']=[=[-- Approved exact R81 values; shared by server and displayed odds.
local T={["Version"]=81,["PointCurve"]={{0,24},{20000,30},{100000,45},{500000,75},{2000000,85.329949},{20000000,117.258883},{500000000,182.994924},{20000000000,305.076142},{1000000000000,511.675127},{20000000000000,774.619289},{100000000000000,1000.0}},["AnimationRateCurve"]={{0,0},{12,0.75},{24,1},{60,2},{150,4},{350,6},{650,8},{1000,10}},["MachineMultipliers"]={1,5,50,500,5000,50000,300000},["MachineCosts"]={0,20000000,250000000,5000000000,100000000000,2000000000000,8000000000000},["TrailMultipliers"]={["MintTrail"]=1.5,["ArcTrail"]=2,["SolarTrail"]=3,["AuroraTrail"]=4,["NebulaTrail"]=5,["RoyalTrail"]=6},["TrailCosts"]={["MintTrail"]=30000000,["ArcTrail"]=500000000,["SolarTrail"]=10000000000,["AuroraTrail"]=250000000000,["NebulaTrail"]=3000000000000,["RoyalTrail"]=9000000000000},["BootCosts"]={250000000,5000000000,100000000000,2000000000000,8000000000000},["FenceCosts"]={0,50000000,1000000000,25000000000,500000000000,4000000000000,9000000000000},["KeeperSpeeds"]={[1]={20,23,27},[6]={38,44,52},[2]={77.817259,80.634518,84.390863},[3]={102.233503,107.86802,117.258883},[4]={151.06599,166.091371,188.629442},[5]={248.730964,276.903553,323.857868},[7]={830.964467,887.309645,1037.563452}},["SpawnWeights"]={45,30,18,6.4,0.5,0.1},["SeedWeights"]={["Pack01"]={["Common"]=55,["Uncommon"]=26,["Rare"]=13,["Legendary"]=4,["Mythic"]=1.3,["Secret"]=0.5,["Cosmic"]=0.15,["King"]=0.05},["Pack02"]={["Common"]=25,["Uncommon"]=38,["Rare"]=25,["Legendary"]=8,["Mythic"]=2.5,["Secret"]=1,["Cosmic"]=0.4,["King"]=0.1},["Pack03"]={["Common"]=0,["Uncommon"]=25,["Rare"]=48,["Legendary"]=18,["Mythic"]=6,["Secret"]=2,["Cosmic"]=0.8,["King"]=0.2},["Pack04"]={["Common"]=0,["Uncommon"]=0,["Rare"]=45,["Legendary"]=32,["Mythic"]=15,["Secret"]=5,["Cosmic"]=2.3,["King"]=0.7},["Pack05"]={["Common"]=0,["Uncommon"]=0,["Rare"]=10,["Legendary"]=40,["Mythic"]=30,["Secret"]=12,["Cosmic"]=6,["King"]=2},["Pack06"]={["Common"]=0,["Uncommon"]=0,["Rare"]=0,["Legendary"]=20,["Mythic"]=45,["Secret"]=22,["Cosmic"]=10,["King"]=3}},["SeedValues"]={["AppleSeed"]=100000,["BluebellSeed"]=50000,["ElderbloomSeed"]=500000,["MooncapSeed"]=2400000,["SunflowerBloomSeed"]=6000000,["SunflowerSeed"]=50000,["AncientWorldrootSeed"]=1458334,["CocoaSeed"]=87500,["LanternFernSeed"]=350000,["PineappleSeed"]=700000,["TigerOrchidSeed"]=1166667,["VenomVineSeed"]=8400000,["CactusSeed"]=800000,["DatePalmSeed"]=180000000,["MirageFigSeed"]=54000000,["SolarStarfruitSeed"]=180000000,["StarfruitSeed"]=90000000,["CrystalLilySeed"]=112500000,["IceberrySeed"]=4500000,["PolarStarbloomSeed"]=1012500000,["SilentFrostbellSeed"]=112500000,["SnowdropSeed"]=4500000,["WinterCrownwoodSeed"]=562500000,["WinterPineSeed"]=270000000,["AshRoseSeed"]=18000000,["EmberBloomSeed"]=36000000,["EmberEmperorSeed"]=2250000000,["FirePepperSeed"]=18000000,["LavaLotusSeed"]=1080000000,["ObsidianMawSeed"]=8100000000,["SupernovaBloomSeed"]=4050000000,["AmethystSeed"]=75000000,["DiamondVineSeed"]=468750000,["HollowGeodeSeed"]=5625000000,["MoonflowerSeed"]=150000000,["OrbitLotusSeed"]=16875000000,["PrismMonarchSeed"]=9375000000,["PrismOrchidSeed"]=75000000,["BlackoutBloomSeed"]=22500000000,["PulsarStarfruitSeed"]=45000000000,["SparkReedSeed"]=400000000,["StormSovereignSeed"]=11250000000,["TempestLotusSeed"]=7500000000,["ThunderTulipSeed"]=400000000,["VoltOrchidSeed"]=1000000000,["CrowncoreTreeSeed"]=56250000000,["HoloAppleTreeSeed"]=1406250000,["HoloMelonSeed"]=1875000000,["NebulaVineSeed"]=5625000000,["PlasmaPepperSeed"]=250000000,["PrismLotusSeed"]=1875000000},["IndexFirst"]={["AppleSeed"]=200000,["BluebellSeed"]=100000,["ElderbloomSeed"]=1250000,["MooncapSeed"]=200000,["SunflowerBloomSeed"]=500000,["SunflowerSeed"]=50000,["AncientWorldrootSeed"]=4375000,["CocoaSeed"]=175000,["LanternFernSeed"]=700000,["PineappleSeed"]=350000,["TigerOrchidSeed"]=1750000,["VenomVineSeed"]=700000,["CactusSeed"]=1200000,["DatePalmSeed"]=15000000,["MirageFigSeed"]=135000000,["SolarStarfruitSeed"]=450000000,["StarfruitSeed"]=45000000,["CrystalLilySeed"]=56250000,["IceberrySeed"]=9000000,["PolarStarbloomSeed"]=506250000,["SilentFrostbellSeed"]=168750000,["SnowdropSeed"]=4500000,["WinterCrownwoodSeed"]=1687500000,["WinterPineSeed"]=22500000,["AshRoseSeed"]=36000000,["EmberBloomSeed"]=36000000,["EmberEmperorSeed"]=6750000000,["FirePepperSeed"]=36000000,["LavaLotusSeed"]=90000000,["ObsidianMawSeed"]=675000000,["SupernovaBloomSeed"]=2025000000,["AmethystSeed"]=150000000,["DiamondVineSeed"]=937500000,["HollowGeodeSeed"]=2812500000,["MoonflowerSeed"]=150000000,["OrbitLotusSeed"]=8437500000,["PrismMonarchSeed"]=28125000000,["PrismOrchidSeed"]=150000000,["BlackoutBloomSeed"]=11250000000,["PulsarStarfruitSeed"]=112500000000,["SparkReedSeed"]=600000000,["StormSovereignSeed"]=33750000000,["TempestLotusSeed"]=3750000000,["ThunderTulipSeed"]=600000000,["VoltOrchidSeed"]=1500000000,["CrowncoreTreeSeed"]=28125000000,["HoloAppleTreeSeed"]=2812500000,["HoloMelonSeed"]=937500000,["NebulaVineSeed"]=8437500000,["PlasmaPepperSeed"]=375000000,["PrismLotusSeed"]=937500000},["IndexRepeat"]={["AppleSeed"]=40000,["BluebellSeed"]=20000,["ElderbloomSeed"]=250000,["MooncapSeed"]=40000,["SunflowerBloomSeed"]=100000,["SunflowerSeed"]=10000,["AncientWorldrootSeed"]=875000,["CocoaSeed"]=35000,["LanternFernSeed"]=140000,["PineappleSeed"]=70000,["TigerOrchidSeed"]=350000,["VenomVineSeed"]=140000,["CactusSeed"]=240000,["DatePalmSeed"]=3000000,["MirageFigSeed"]=27000000,["SolarStarfruitSeed"]=90000000,["StarfruitSeed"]=9000000,["CrystalLilySeed"]=11250000,["IceberrySeed"]=1800000,["PolarStarbloomSeed"]=101250000,["SilentFrostbellSeed"]=33750000,["SnowdropSeed"]=900000,["WinterCrownwoodSeed"]=337500000,["WinterPineSeed"]=4500000,["AshRoseSeed"]=7200000,["EmberBloomSeed"]=7200000,["EmberEmperorSeed"]=1350000000,["FirePepperSeed"]=7200000,["LavaLotusSeed"]=18000000,["ObsidianMawSeed"]=135000000,["SupernovaBloomSeed"]=405000000,["AmethystSeed"]=30000000,["DiamondVineSeed"]=187500000,["HollowGeodeSeed"]=562500000,["MoonflowerSeed"]=30000000,["OrbitLotusSeed"]=1687500000,["PrismMonarchSeed"]=5625000000,["PrismOrchidSeed"]=30000000,["BlackoutBloomSeed"]=2250000000,["PulsarStarfruitSeed"]=22500000000,["SparkReedSeed"]=120000000,["StormSovereignSeed"]=6750000000,["TempestLotusSeed"]=750000000,["ThunderTulipSeed"]=120000000,["VoltOrchidSeed"]=300000000,["CrowncoreTreeSeed"]=5625000000,["HoloAppleTreeSeed"]=562500000,["HoloMelonSeed"]=187500000,["NebulaVineSeed"]=1687500000,["PlasmaPepperSeed"]=75000000,["PrismLotusSeed"]=187500000},["CompletionGems"]={[1]=5,[6]=10,[2]=15,[3]=20,[4]=25,[5]=30,[7]=40,[8]=50},["EventWeights"]={["Secret"]=80,["Cosmic"]=17,["King"]=3}}

local R=require(script.Parent.RouteBalance83)
T.KeeperSpeeds=R.KeeperSpeeds;T.SpawnWeights=R.SpawnWeights
-- R84: exact saved points are retained; new training takes longer at every tier.
T.SpeedTailPerDecade=.1 -- R88: 500 at 100B, only +0.1 per tenfold increase afterwards.
T.PointCurve={{0,24},{800,30},{3000,38},{10000,48},{50000,64},{300000,82},{2000000,110},{20000000,155},{500000000,215},{20000000000,350},{100000000000,500}}
T.MachineMultipliers={1,4,20,100,600,4000,30000}
T.BootLuck={1.15,1.3,1.5,1.75,2}
-- Early purchases now take a few normal harvests rather than hundreds.
T.MachineCosts={0,250000,5000000,150000000,10000000000,500000000000,8000000000000}
T.TrailCosts={MintTrail=200000,ArcTrail=4000000,SolarTrail=120000000,AuroraTrail=12000000000,NebulaTrail=800000000000,RoyalTrail=9000000000000}
T.BootCosts={750000,25000000,2000000000,250000000000,8000000000000}
T.FenceCosts={0,500000,15000000,1000000000,150000000000,4000000000000,9000000000000}
require(script.Parent.EconomyBalance90).Apply(T)
-- R104: independent index milestones; historical balances keep their original backpay.
T.LegacyCompletionGems=T.CompletionGems
T.HalfwayGems=10
T.CompletionGems={[1]=20,[6]=20,[2]=20,[3]=20,[4]=20,[5]=20,[7]=20,[8]=100}
T.Version=91
return T
]=]
SOURCES['PackOdds81']=[=[-- Pure odds allocation. Missing rarity moves upward before luck is applied.
local T=require(script.Parent.BalanceValues81)
local O={Order={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}}
function O.Weights(pool,getRarity,variant,luck)
 local source=variant=='EclipseReliquary'and T.EventWeights or T.SeedWeights[variant]
 if not source then return nil end
 local counts,allocated={},{}
 for _,seed in ipairs(pool)do local rarity=getRarity(seed.Id);counts[rarity]=(counts[rarity]or 0)+1 end
 for _,r in ipairs(O.Order)do allocated[r]=0 end
 local top
 for _,r in ipairs(O.Order)do if counts[r]then top=r end end
 if not top then return {},0 end
 for i,r in ipairs(O.Order)do
  local target
  for j=i,#O.Order do if counts[O.Order[j]]then target=O.Order[j];break end end
  target=target or top;allocated[target]+=(source[r]or 0)
 end
 luck=type(luck)=='number'and luck==luck and math.clamp(luck,1,3.5)or 1
 if variant~='EclipseReliquary'then
  for i,r in ipairs(O.Order)do allocated[r]*=i>=6 and luck or i>=4 and(1+.5*(luck-1))or 1 end
 end
 local weights,total={},0
 for i,seed in ipairs(pool)do local r=getRarity(seed.Id);local weight=allocated[r]/counts[r];weights[i]=weight;total+=weight end
 return weights,total
end
return O
]=]
SOURCES['EconomyBalance90']=[=[-- R90: approachable first purchases, long-term trillion-cost goals, restrained fruit income.
-- Prices are server-owned. This module contains no profile migration or paid-product changes.
local E={Version=90,MaxCash=900000000000000,MaxBaseFruitValue=10000000000}
local Scale=require(script.Parent.EconomyScaling91)
E.Version=91
E.MachineCosts=Scale.Curve(250000,60000000000000,6,true)
local trails=Scale.Curve(200000,75000000000000,6,false)
E.TrailCosts={};for i,id in ipairs({'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'})do E.TrailCosts[id]=trails[i]end
E.BootCosts=Scale.Curve(750000,40000000000000,5,false)
E.FenceCosts=Scale.Curve(500000,30000000000000,6,true)
-- Values per fruit, not per plant. Multi-fruit trees and regrowth timings are
-- considered together; a rare single-fruit plant can have the higher sticker value.
E.FruitValues={
 MooncapSeed=300000,VenomVineSeed=2000000,
 MirageFigSeed=40000000,SolarStarfruitSeed=70000000,StarfruitSeed=250000000,
 PolarStarbloomSeed=600000000,WinterCrownwoodSeed=150000000,
 LavaLotusSeed=900000000,ObsidianMawSeed=1000000000,SupernovaBloomSeed=1500000000,EmberEmperorSeed=400000000,
 DiamondVineSeed=350000000,HollowGeodeSeed=1500000000,OrbitLotusSeed=2500000000,PrismMonarchSeed=800000000,
 SparkReedSeed=200000000,ThunderTulipSeed=200000000,VoltOrchidSeed=650000000,TempestLotusSeed=3000000000,
 BlackoutBloomSeed=5000000000,StormSovereignSeed=1500000000,PulsarStarfruitSeed=2500000000,
 PlasmaPepperSeed=250000000,HoloMelonSeed=1500000000,PrismLotusSeed=2000000000,
 HoloAppleTreeSeed=1000000000,NebulaVineSeed=2500000000,CrowncoreTreeSeed=10000000000,
}
E.RegrowSeconds={CrowncoreTreeSeed=450}
function E.Apply(tuning)
 tuning.MachineCosts=E.MachineCosts;tuning.TrailCosts=E.TrailCosts;tuning.BootCosts=E.BootCosts;tuning.FenceCosts=E.FenceCosts
 for id,value in pairs(E.FruitValues)do
  local old=assert(tuning.SeedValues[id],'Unknown fruit tuning: '..id)
  -- Scale future index rewards with the species. Already-earned pending rewards stay intact.
  for _,field in ipairs({'IndexFirst','IndexRepeat'})do
   local prior=tuning[field][id]
   if prior then tuning[field][id]=math.max(1,math.floor(prior*value/old+.5))end
  end
  tuning.SeedValues[id]=value
 end
end
return E
]=]
SOURCES['EconomyScaling91']=[=[-- Shared geometric cash prices and server-calculated earned-currency bundle quotes.
-- No client balance, equipped bonus, crop size or mutation can inflate a quote.
local E={Version=91,BundleMinutes={2,5,12.5,31.25,78.125},BundleGemPrices={50,125,315,790,1975}}
function E.Round(value)
 if value<=0 then return 0 end
 local unit=math.max(5,10^(math.floor(math.log10(value))-2))
 return math.floor(value/unit+.5)*unit
end
function E.Curve(first,last,count,free)
 local prices=free and{0}or{}
 for i=0,count-1 do prices[#prices+1]=E.Round(first*(last/first)^(i/(count-1)))end
 prices[free and 2 or 1]=first;prices[#prices]=last
 return prices
end
function E.BaseIncome(def)
 if not def or type(def.Value)~='number'or def.Value<=0 then return 0 end
 local seconds=def.Regrows==false and def.Seconds or def.RegrowSeconds
 if type(seconds)~='number'or seconds<=0 then return 0 end
 return math.min(def.Value,10000000000)*math.clamp(def.FruitCount or 1,1,6)/seconds
end
function E.CashQuote(index,grown,catalog)
 if not E.BundleMinutes[index]then return nil end
 local rate=E.BaseIncome(catalog.SunflowerSeed)
 for id,owned in pairs(grown or{})do if owned==true then rate=math.max(rate,E.BaseIncome(catalog[id]))end end
 -- Eight base-size mature plants; exclude cash multipliers and growth passes.
 -- Never return enough Cash to buy back the Gems spent through Cash-to-Gems.
 local limit=E.BundleGemPrices[index]*1000000000*.8
 return math.max(5,math.min(E.Round(rate*8*60*E.BundleMinutes[index]),limit))
end
return E
]=]
SOURCES['RouteBalance83']=[=[-- Stable stage IDs; world distances are independent of saved progression.
local R={Order={1,6,2,3,4,5,7},Start=-100,OldLengths={[1]=225,[6]=270,[2]=292.5,[3]=315,[4]=360,[5]=405,[7]=450},
 Lengths={[1]=180,[6]=450,[2]=650,[3]=850,[4]=1050,[5]=1300,[7]=1600},
 KeeperSpeeds={[1]={20,22,25},[6]={29,34,40},[2]={48,56,64},[3]={72,84,98},[4]={115,140,170},[5]={220,270,320},[7]={400,450,520}},
 EventSpeed=600,EventReturnSpeed=600,SpawnWeights={38,25,15,7,10,5}}
R.OldStart={};R.NewStart={};local old,new=R.Start,R.Start
for _,id in ipairs(R.Order)do R.OldStart[id]=old;R.NewStart[id]=new;old+=R.OldLengths[id];new+=R.Lengths[id]end
R.OldEnd=old;R.End=new
function R.MapZ(z)
 if z<=R.Start then return z end
 for _,id in ipairs(R.Order)do local first=R.OldStart[id];local length=R.OldLengths[id]
  if z<=first+length then return R.NewStart[id]+(z-first)*R.Lengths[id]/length end
 end
 return R.End+(z-R.OldEnd)
end
function R.ApplyConfig(config)
 if config.RouteBalanceVersion==83 then return end
 for stage,e in ipairs(config.MythicEncounters)do
  local oldHome=e.Home[3];local delta=R.MapZ(oldHome)-oldHome;e.Home[3]+=delta
  for _,point in ipairs(e.Seeds)do point[3]+=delta end
  e.Landmark[3]=stage==4 and e.Landmark[3]+(R.MapZ(R.OldStart[4]+R.OldLengths[4]/2)-(R.OldStart[4]+R.OldLengths[4]/2))or R.MapZ(e.Landmark[3])
 end
 local e=config.MythicEncounters[1];local z=e.Home[3]
 for _,p in ipairs(e.Seeds)do p[1]=64-(p[1]-e.Home[1]);p[3]=0-(p[3]-z)end
 e.Home={64,8,0};e.Yaw=90
 config.RouteBalanceVersion=83
 config.BiomeRunLengths=table.clone(R.Lengths);config.BiomeTrackEndZ=R.End;config.BiomeRunLength=R.Lengths[1]
end
return R
]=]
SOURCES['BalanceRules']=[=[-- R67: one shared source for new rolls, movement and sale-preview multipliers.
local B={Version=84,MaxSize=25,SeedHoverSeconds=1,SeedSlideSeconds=.45,SeedRiseSeconds=.35}
local tuning=require(script.Parent.BalanceValues81)
B.SpeedMilestones=tuning.PointCurve
B.TrainingTiers=tuning.MachineMultipliers
B.TrailMultipliers=tuning.TrailMultipliers
B.KeeperOrder={1,6,2,3,4,5,7}
B.KeeperFloors={};B.KeeperCeilings={}
for stage,row in pairs(tuning.KeeperSpeeds)do B.KeeperFloors[stage]=row[1];B.KeeperCeilings[stage]=row[3]end
B.RarityWeights={Common=55,Uncommon=28,Rare=12,Legendary=3.8,Mythic=1,Secret=.16,Cosmic=.035,King=.005}
B.PackSizes={{Scale=.5,Weight=3},{Scale=1,Weight=80.799},{Scale=1.5,Weight=13},{Scale=2.5,Weight=2.8},{Scale=3.5,Weight=.35},{Scale=5,Weight=.04},{Scale=7.5,Weight=.008},{Scale=10,Weight=.002},{Scale=15,Weight=.0007},{Scale=20,Weight=.0002},{Scale=25,Weight=.0001}}
B.MutationWeights={None=95,Gold=4.5,Diamond=.5}
B.MutationInheritance=.20;B.WeatherInheritance=.20
B.WeatherPackChance=.02;B.WeatherFruitChance=.02;B.WeatherPlantChance=.02
local function finite(n,fallback)return type(n)=='number'and n==n and math.abs(n)<math.huge and n or fallback end
function B.Half(n)return math.floor(n*2+.5)/2 end
function B.Training(machine,trail,premium)
 return math.clamp(finite(machine,1),1,30000)*math.clamp(finite(trail,1),1,6)*(premium and 2 or 1)
end
function B.SizeCash(size)return B.Half(1+(math.sqrt(math.clamp(finite(size,1),.5,25))-1)*.5)end
function B.MutationCash(mutation)return mutation=='Diamond'and 3 or mutation=='Gold'and 2 or 1 end
function B.CashMultiplier(sizeBonus,mutation,weatherBonus)
 return B.Half(math.clamp(finite(sizeBonus,1),1,3)+B.MutationCash(mutation)-1+math.clamp(finite(weatherBonus,1),1,4)-1)
end
function B.PlantScale(seed,unit)
 seed=math.clamp(finite(seed,1),.5,25);unit=math.clamp(finite(unit,1),0,1)
 local ticket=unit/math.min(4,1+(seed-1)*.15)
 local gain=ticket<.000001 and 25 or ticket<.00001 and 10 or ticket<.00025 and 5 or ticket<.005 and 2.5 or ticket<.05 and 1.5 or 1
 return math.clamp(B.Half((.75+.25*math.sqrt(seed))*gain),.5,25)
end
function B.SeedPhase(age)
 local rise=math.clamp(age/B.SeedRiseSeconds,0,1)
 local slide=math.clamp((age-B.SeedRiseSeconds-B.SeedHoverSeconds)/B.SeedSlideSeconds,0,1)
 return rise,slide
end
return B
]=]
SOURCES['SeedPackRules']=[=[-- V119. Server rolls rewards; clients only render the published result.
local Rules = {}
Rules.Version = 139
Rules.MaxPackSize = 25
Rules.MaxSeedScale = 25
Rules.PacksPerBiome = 5
Rules.RefreshInterval = 300
Rules.RefreshClosedSeconds = 10
Rules.GuardianReturnMultiplier = 2.5
Rules.RevealSeconds = 3.5
Rules.TearSeconds = .10
Rules.OpenClicks = 5
Rules.ClickInterval = .065
Rules.TearSoundId = "rbxassetid://9125725227"
Rules.TearVolume = 0.45
Rules.TearSoundStart = 0.10
-- Soft built-in bell sample: no new external audio permission is needed.
Rules.RevealBellSoundId = "rbxasset://sounds/electronicpingshort.wav"
Rules.RevealBellVolume = .055
Rules.RevealAudioCooldown = 2.4
Rules.PackTiers = {
    {Name="Common",Color=Color3.fromRGB(220,230,235),Rate=1},
    {Name="Uncommon",Color=Color3.fromRGB(100,232,130),Rate=2},
    {Name="Rare",Color=Color3.fromRGB(95,172,255),Rate=3},
    {Name="Epic",Color=Color3.fromRGB(177,116,255),Rate=4},
    {Name="Legendary",Color=Color3.fromRGB(255,212,108),Rate=5},
    {Name="Mythic",Color=Color3.fromRGB(243,135,255),Rate=6},
}
function Rules.GetPackTier(key)
    if key=='EclipseReliquary'then return {Name='Secret+',Color=Color3.fromRGB(190,144,255),Rate=7},7 end
    if key=='MechLimited'then return {Name='Limited',Color=Color3.fromRGB(88,225,255),Rate=6},6 end
    local variant=Rules.Variants[key]
    local rank=variant and (variant.Design or ({Small=1,Standard=2,Grand=3})[key]) or 2
    for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.PackTiers[rank] or Rules.PackTiers[#Rules.PackTiers],rank
end
function Rules.GetRevealDuration(name)
 local rarity=Rules.Rarities[name]or Rules.Rarities.Common
 local b=require(script.Parent.BalanceRules)
 return require(script.Parent.RarityRevealSequence).SeedAt(rarity.Rank)+b.SeedRiseSeconds+b.SeedHoverSeconds+b.SeedSlideSeconds
end
-- One registry drives world spawns, saved identities, appearance and server odds.
-- Small/Standard/Grand are stable save keys; display names may change freely.
Rules.Variants = {
    Pack01 = {Name="Seed Pack", BagScale=.86, SeedScale=0.85, RareBias=1, SpawnWeight=50, Trim=1, Design=1, OddsLabel="Sealed biome pack"},
    Pack02 = {Name="Seed Pack", BagScale=.92, SeedScale=0.95, RareBias=1.05, SpawnWeight=27, Trim=2, Design=2, OddsLabel="Sealed biome pack"},
    Pack03 = {Name="Seed Pack", BagScale=1, SeedScale=1, RareBias=1.12, SpawnWeight=14, Trim=3, Design=3, OddsLabel="Sealed biome pack"},
    Pack04 = {Name="Seed Pack", BagScale=1.06, SeedScale=1.1, RareBias=1.22, SpawnWeight=6, Trim=4, Design=4, OddsLabel="Sealed biome pack"},
    Pack05 = {Name="Seed Pack", BagScale=.896, SeedScale=1.2, RareBias=1.35, SpawnWeight=2.5, Trim=5, Design=5, OddsLabel="Sealed biome pack"},
    Pack06 = {Name="Seed Pack", BagScale=.96, SeedScale=1.35, RareBias=1.5, SpawnWeight=.5, Trim=6, Design=6, OddsLabel="Sealed biome pack"},
    -- Preserve legacy saved pack keys and their already-promised reward rules.
    -- Only VariantOrder is eligible for new world spawns.
    Small = {Name="Small Sack", BagScale=.78, SeedScale=.72, RareBias=.65, SpawnWeight=30, Trim=1, OddsLabel="Common-focused"},
    Standard = {Name="Seed Sack", BagScale=1, SeedScale=1, RareBias=1, SpawnWeight=55, Trim=2, OddsLabel="Balanced odds"},
    Grand = {Name="Grand Sack", BagScale=1.25, SeedScale=1.38, RareBias=1.7, SpawnWeight=15, Trim=3, OddsLabel="Better rare odds"},
}
Rules.VariantOrder = {"Pack01","Pack02","Pack03","Pack04","Pack05","Pack06"}
Rules.DesignBiomes = {[1]="Forest",[2]="Desert",[3]="Snow",[4]="Lava",[5]="Crystal",[6]="Jungle",[7]="Storm"}
function Rules.DesignKey(stage,key)
    local legacy={Small=1,Standard=2,Grand=3}
    local variant=Rules.Variants[key]
    return (Rules.DesignBiomes[stage] or "Forest").."_"..string.format("%02d",variant and (variant.Design or legacy[key]) or 2)
end
Rules.BiomeThemes = {
    [1]={Body=Color3.fromRGB(179,138,85), Ink=Color3.fromRGB(57,103,48), Trim=Color3.fromRGB(108,135,61), Mark="Leaf", Scale=1},
    [6]={Body=Color3.fromRGB(114,143,65), Ink=Color3.fromRGB(35,83,50), Trim=Color3.fromRGB(220,182,78), Mark="Vine", Scale=1.02},
    [2]={Body=Color3.fromRGB(212,171,105), Ink=Color3.fromRGB(146,77,43), Trim=Color3.fromRGB(235,208,135), Mark="Sun", Scale=1.04},
    [3]={Body=Color3.fromRGB(185,210,218), Ink=Color3.fromRGB(57,108,144), Trim=Color3.fromRGB(230,239,236), Mark="Snowflake", Scale=1.06},
    [4]={Body=Color3.fromRGB(88,74,68), Ink=Color3.fromRGB(250,136,52), Trim=Color3.fromRGB(177,66,42), Mark="Flame", Scale=1.08},
    [5]={Body=Color3.fromRGB(137,117,171), Ink=Color3.fromRGB(227,211,250), Trim=Color3.fromRGB(101,189,191), Mark="Crystal", Scale=1.10},
    [7]={Body=Color3.fromRGB(105,113,146), Ink=Color3.fromRGB(237,212,128), Trim=Color3.fromRGB(173,150,220), Mark="Lightning", Scale=1.12},
}
function Rules.VariantKey(key)
    return type(key)=="string" and Rules.Variants[key] and key or "Standard"
end
function Rules.GetVariant(key) for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.Variants[Rules.VariantKey(key)] end
function Rules.GetTheme(stage) for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.BiomeThemes[stage] or Rules.BiomeThemes[1] end
function Rules.SanitizeSeedScale(value)
    if type(value)~="number" or value~=value or math.abs(value)==math.huge then return 1 end
    return math.floor(math.clamp(value,.35,Rules.MaxSeedScale)*1000+.5)/1000
end
-- Loose-seed appearance only: planting/growth/value do not read these size rules.
function Rules.SeedBaseScale(stage,key)
    for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.GetVariant(key).SeedScale*Rules.GetTheme(stage).Scale
end
function Rules.SeedSizeCap(stage,key,packSize)
    local size=Rules.SanitizePackSize(packSize)
    return math.min(Rules.MaxSeedScale,Rules.SeedBaseScale(stage,key)*(1.4+math.max(0,size-1)))
end
function Rules.NewSeedScale(stage,key,packSize)
    if key=='MechLimited'then return 1 end
    local size=Rules.SanitizePackSize(packSize)
    for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return require(script.Parent.SizeNumbers).Half(math.min(Rules.SeedBaseScale(stage,key)*size,Rules.SeedSizeCap(stage,key,size)))
end
function Rules.RollVariant(unitRoll)
    local total=0
    for _,key in ipairs(Rules.VariantOrder) do total+=Rules.Variants[key].SpawnWeight end
    local value=tonumber(unitRoll) or 0
    if value~=value then value=0 end
    local ticket=math.clamp(value,0,1-1e-12)*total
    for _,key in ipairs(Rules.VariantOrder) do
        ticket-=Rules.Variants[key].SpawnWeight
        if ticket<0 then return key end
    end
    return "Standard"
end
-- Add future rarities here and assign their names in SeedRarityById.
Rules.RarityOrder={"Common","Uncommon","Rare","Legendary","Mythic","Secret","Cosmic","King"}
Rules.Rarities = {
 Common={Rank=1,Weight=62,Color=Color3.fromRGB(223,236,242),Motion="Float",Duration=3.5},
 Uncommon={Rank=2,Weight=26,Color=Color3.fromRGB(98,235,130),Motion="Sprout",Duration=3.7},
 Rare={Rank=3,Weight=9,Color=Color3.fromRGB(91,173,255),Motion="Spiral",Duration=4.1},
 Legendary={Rank=4,Weight=2,Color=Color3.fromRGB(255,207,89),Motion="Sunburst",Duration=4.6},
 Mythic={Rank=5,Weight=.8,Color=Color3.fromRGB(230,125,255),Motion="DoubleHelix",Duration=5.0},
 Secret={Rank=6,Weight=.16,Color=Color3.fromRGB(255,119,160),Motion="Eclipse",Duration=5.3},
 Cosmic={Rank=7,Weight=.035,Color=Color3.fromRGB(159,178,255),Motion="Orbit",Duration=6.4},
 King={Rank=8,Weight=.005,Color=Color3.fromRGB(255,236,161),Motion="Coronation",Duration=7.6},
}
-- Shared approved V131 designs. Stable first-five IDs preserve old saves.
Rules.SeedDesigns={{["biome"]="Forest",["index"]=1,["name"]="Watermelon",["rarity"]="Common",["design"]="fresh green to pale mint, three dark wavy stripes",["pattern"]="Stripes",["top"]="74b967",["bottom"]="d7eea1",["ink"]="245434",["addition"]="none",["stage"]=1,["id"]="SunflowerSeed"},{["biome"]="Forest",["index"]=2,["name"]="Pea",["rarity"]="Common",["design"]="lime to butter yellow, three round pea dots",["pattern"]="Dots",["top"]="b8e878",["bottom"]="e9f5b7",["ink"]="598a36",["addition"]="none",["stage"]=1,["id"]="CloverSeed"},{["biome"]="Forest",["index"]=3,["name"]="Blueberry",["rarity"]="Uncommon",["design"]="indigo to cornflower, pale speckles and tiny leaf tuft",["pattern"]="Specks",["top"]="666dce",["bottom"]="acd1ff",["ink"]="d6efff",["addition"]="leaves",["stage"]=1,["id"]="BluebellSeed"},{["biome"]="Forest",["index"]=4,["name"]="Strawberry",["rarity"]="Uncommon",["design"]="red to rose, cream seed specks, leafy green cap",["pattern"]="Specks",["top"]="ee5366",["bottom"]="ffa9b1",["ink"]="ffebae",["addition"]="cap",["stage"]=1,["id"]="StrawberrySeed"},{["biome"]="Forest",["index"]=5,["name"]="Apple",["rarity"]="Rare",["design"]="ruby to warm peach, apple leaf emblem and a short brown stem",["pattern"]="Leaf",["top"]="c9384b",["bottom"]="ffc387",["ink"]="4b9f42",["addition"]="stem",["stage"]=1,["id"]="AppleSeed"},{["biome"]="Forest",["index"]=6,["name"]="Mooncap",["rarity"]="Rare",["design"]="lavender to midnight, crescent marking and two tiny pale mushrooms",["pattern"]="Dots",["top"]="b2a2e4",["bottom"]="393860",["ink"]="ecedff",["addition"]="mushrooms",["stage"]=1,["id"]="MooncapSeed"},{["biome"]="Forest",["index"]=7,["name"]="Sunflower",["rarity"]="Legendary",["design"]="amber to lemon, short petal collar like a little sun, gentle gold rays",["pattern"]="Star",["top"]="ffb94a",["bottom"]="fff0a0",["ink"]="fff6c7",["addition"]="petals",["stage"]=1,["id"]="SunflowerBloomSeed"},{["biome"]="Forest",["index"]=8,["name"]="Elderbloom",["rarity"]="Mythic",["design"]="deep emerald to jade, two branching wooden antlers, white blossom buds, mint wisps",["pattern"]="Leaf",["top"]="206e56",["bottom"]="8aefba",["ink"]="e9ffe8",["addition"]="antlers",["stage"]=1,["id"]="ElderbloomSeed"},{["biome"]="Jungle",["index"]=1,["name"]="Banana",["rarity"]="Common",["design"]="yellow to chartreuse, three curved lime stripes",["pattern"]="Stripes",["top"]="f2d556",["bottom"]="f6f2ab",["ink"]="769d30",["addition"]="none",["stage"]=6,["id"]="BananaSeed"},{["biome"]="Jungle",["index"]=2,["name"]="Cocoa",["rarity"]="Common",["design"]="copper to cocoa brown, three cream dots",["pattern"]="Dots",["top"]="b17a45",["bottom"]="513528",["ink"]="f1d391",["addition"]="none",["stage"]=6,["id"]="CocoaSeed"},{["biome"]="Jungle",["index"]=3,["name"]="Pineapple",["rarity"]="Uncommon",["design"]="amber to yellow, diamond specks, compact spiky green leaf tuft",["pattern"]="Specks",["top"]="dc9b27",["bottom"]="ffeaaa",["ink"]="926031",["addition"]="cap",["stage"]=6,["id"]="PineappleSeed"},{["biome"]="Jungle",["index"]=4,["name"]="Monstera",["rarity"]="Uncommon",["design"]="jade to lime, dark split-leaf emblem, one curled leaf on side",["pattern"]="Leaf",["top"]="26ad83",["bottom"]="b4eb70",["ink"]="146644",["addition"]="leaves",["stage"]=6,["id"]="MonsteraSeed"},{["biome"]="Jungle",["index"]=5,["name"]="Venom Vine",["rarity"]="Rare",["design"]="plum to acid green, thorn nubs and lime droplet dots",["pattern"]="Dots",["top"]="81388e",["bottom"]="b7ed57",["ink"]="d3ff72",["addition"]="thorns",["stage"]=6,["id"]="VenomVineSeed"},{["biome"]="Jungle",["index"]=6,["name"]="Lantern Fern",["rarity"]="Rare",["design"]="emerald to teal, two hanging amber lantern buds, leaf emblem",["pattern"]="Leaf",["top"]="168a65",["bottom"]="74dcb9",["ink"]="e6f395",["addition"]="lanterns",["stage"]=6,["id"]="LanternFernSeed"},{["biome"]="Jungle",["index"]=7,["name"]="Tiger Orchid",["rarity"]="Legendary",["design"]="orange to ivory, bold black tiger stripes and two orchid petal fins",["pattern"]="Stripes",["top"]="f09b39",["bottom"]="fff1c7",["ink"]="433236",["addition"]="petals",["stage"]=6,["id"]="TigerOrchidSeed"},{["biome"]="Jungle",["index"]=8,["name"]="Ancient Worldroot",["rarity"]="Mythic",["design"]="teal to deep jungle green, root antlers curling around core, amber resin gems",["pattern"]="Leaf",["top"]="27bca8",["bottom"]="164f3d",["ink"]="ffd27f",["addition"]="antlers",["stage"]=6,["id"]="AncientWorldrootSeed"},{["biome"]="Desert",["index"]=1,["name"]="Prickly Pear",["rarity"]="Common",["design"]="sage to lime, cream dotted areoles",["pattern"]="Dots",["top"]="8ba850",["bottom"]="daeca4",["ink"]="fff2c1",["addition"]="none",["stage"]=2,["id"]="CactusSeed"},{["biome"]="Desert",["index"]=2,["name"]="Aloe",["rarity"]="Uncommon",["design"]="turquoise to sage, single leaf emblem and two aloe blades",["pattern"]="Leaf",["top"]="4bada3",["bottom"]="b2dab2",["ink"]="24736a",["addition"]="leaves",["stage"]=2,["id"]="AloeSeed"},{["biome"]="Desert",["index"]=4,["name"]="Crown Cactus",["rarity"]="Legendary",["design"]="green to warm jade, gold spines and short golden flower crest",["pattern"]="Dots",["top"]="64a468",["bottom"]="cdeea5",["ink"]="ffd378",["addition"]="crest",["stage"]=2,["id"]="AgaveSeed"},{["biome"]="Desert",["index"]=5,["name"]="Dune Lotus",["rarity"]="Mythic",["design"]="terracotta to rose gold, layered sandy lotus petals and sun disc",["pattern"]="Star",["top"]="cc7749",["bottom"]="ffe1a4",["ink"]="fff2c7",["addition"]="petals",["stage"]=2,["id"]="DatePalmSeed"},{["biome"]="Desert",["index"]=6,["name"]="Mirage Fig",["rarity"]="Secret",["design"]="midnight blue to sand, one luminous slit, broken hovering amber halo",["pattern"]="Leaf",["top"]="27354f",["bottom"]="d0ad80",["ink"]="fff2b4",["addition"]="brokenHalo",["stage"]=2,["id"]="MirageFigSeed"},{["biome"]="Desert",["index"]=7,["name"]="Solar Starfruit",["rarity"]="Cosmic",["design"]="indigo to amber, little stars, tilted golden orbital ring and sun motes",["pattern"]="Star",["top"]="59417f",["bottom"]="ffd582",["ink"]="fff4c5",["addition"]="orbit",["stage"]=2,["id"]="SolarStarfruitSeed"},{["biome"]="Desert",["index"]=8,["name"]="Sun King Palm",["rarity"]="King",["design"]="ivory to gold, tall sun crown, two jade palm fronds and red central gem",["pattern"]="Star",["top"]="ffcf69",["bottom"]="fff5c8",["ink"]="fff7dd",["addition"]="crown",["stage"]=2,["id"]="SunKingPalmSeed"},{["biome"]="Snow",["index"]=1,["name"]="Snow Melon",["rarity"]="Common",["design"]="mint to snow white, thin icy stripes",["pattern"]="Stripes",["top"]="9bceca",["bottom"]="efffff",["ink"]="579baf",["addition"]="none",["stage"]=3,["id"]="SnowdropSeed"},{["biome"]="Snow",["index"]=2,["name"]="Frost Fern",["rarity"]="Uncommon",["design"]="teal to frost blue, two short frosted fern leaves",["pattern"]="Leaf",["top"]="59a8a0",["bottom"]="d4f8f7",["ink"]="efffff",["addition"]="leaves",["stage"]=3,["id"]="FrostFernSeed"},{["biome"]="Snow",["index"]=3,["name"]="Iceberry",["rarity"]="Rare",["design"]="azure to baby blue, tiny translucent blue ice cluster on one side",["pattern"]="Dots",["top"]="468dcc",["bottom"]="c0efff",["ink"]="eeffff",["addition"]="crystals",["stage"]=3,["id"]="IceberrySeed"},{["biome"]="Snow",["index"]=4,["name"]="Aurora Lily",["rarity"]="Legendary",["design"]="violet to mint, translucent petal collar, restrained aurora ribbons",["pattern"]="Star",["top"]="7f75d6",["bottom"]="a8ffd8",["ink"]="efffff",["addition"]="petals",["stage"]=3,["id"]="WinterPineSeed"},{["biome"]="Snow",["index"]=5,["name"]="Glacier Lotus",["rarity"]="Mythic",["design"]="deep glacial blue to white, tall transparent ice petal spikes",["pattern"]="Leaf",["top"]="2784b8",["bottom"]="e6ffff",["ink"]="abffff",["addition"]="crystals",["stage"]=3,["id"]="CrystalLilySeed"},{["biome"]="Snow",["index"]=6,["name"]="Silent Frostbell",["rarity"]="Secret",["design"]="navy to silver, frosted bell cap and detached broken ice halo",["pattern"]="Dots",["top"]="354864",["bottom"]="d4e5ef",["ink"]="d4ffff",["addition"]="brokenHalo",["stage"]=3,["id"]="SilentFrostbellSeed"},{["biome"]="Snow",["index"]=7,["name"]="Polar Starbloom",["rarity"]="Cosmic",["design"]="midnight indigo to icy cyan, tiny stars, tilted ice orbit, floating shards",["pattern"]="Star",["top"]="363c91",["bottom"]="99e9ff",["ink"]="edffff",["addition"]="orbit",["stage"]=3,["id"]="PolarStarbloomSeed"},{["biome"]="Snow",["index"]=8,["name"]="Winter Crownwood",["rarity"]="King",["design"]="ice blue to pearl, huge clear glacier crown, sapphire jewel, white frosty rays",["pattern"]="Star",["top"]="79bedb",["bottom"]="f1ffff",["ink"]="ddffff",["addition"]="crown",["stage"]=3,["id"]="WinterCrownwoodSeed"},{["biome"]="Lava",["index"]=1,["name"]="Fire Pepper",["rarity"]="Common",["design"]="red to orange, small cream pepper flecks",["pattern"]="Specks",["top"]="c63929",["bottom"]="ffb45b",["ink"]="ffedac",["addition"]="none",["stage"]=4,["id"]="FirePepperSeed"},{["biome"]="Lava",["index"]=2,["name"]="Ember Pumpkin",["rarity"]="Uncommon",["design"]="orange to amber, dark pumpkin stripes and burnt stem",["pattern"]="Stripes",["top"]="df6824",["bottom"]="ffca60",["ink"]="663722",["addition"]="stem",["stage"]=4,["id"]="EmberBloomSeed"},{["biome"]="Lava",["index"]=3,["name"]="Ash Tomato",["rarity"]="Rare",["design"]="charcoal to ash rose, small glowing orange crack pattern and obsidian spikes",["pattern"]="Specks",["top"]="574650",["bottom"]="bc7070",["ink"]="ffc16a",["addition"]="thorns",["stage"]=4,["id"]="AshRoseSeed"},{["biome"]="Lava",["index"]=4,["name"]="Lava Lotus",["rarity"]="Legendary",["design"]="orange to yellow, four chunky black petals with glowing edges",["pattern"]="Star",["top"]="f15b21",["bottom"]="ffd872",["ink"]="ffef91",["addition"]="petals",["stage"]=4,["id"]="LavaLotusSeed"},{["biome"]="Lava",["index"]=5,["name"]="Dragonfruit",["rarity"]="Mythic",["design"]="magenta to scarlet, two curled black dragon horns and green scales",["pattern"]="Specks",["top"]="c73577",["bottom"]="fc8b75",["ink"]="b5d55a",["addition"]="horns",["stage"]=4,["id"]="DragonfruitSeed"},{["biome"]="Lava",["index"]=6,["name"]="Obsidian Maw",["rarity"]="Secret",["design"]="near black to purple, glowing orange slit, jagged broken obsidian halo",["pattern"]="Leaf",["top"]="292232",["bottom"]="695178",["ink"]="ff9d38",["addition"]="brokenHalo",["stage"]=4,["id"]="ObsidianMawSeed"},{["biome"]="Lava",["index"]=7,["name"]="Supernova Bloom",["rarity"]="Cosmic",["design"]="indigo to hot pink, fiery tilted orbit, tiny orange stars",["pattern"]="Star",["top"]="574099",["bottom"]="ff8baf",["ink"]="ffd76b",["addition"]="orbit",["stage"]=4,["id"]="SupernovaBloomSeed"},{["biome"]="Lava",["index"]=8,["name"]="Ember Emperor",["rarity"]="King",["design"]="black to molten gold, large black crown with lava seams, orange ruby and great horns",["pattern"]="Star",["top"]="51312c",["bottom"]="ffb358",["ink"]="ffe38e",["addition"]="crownHorns",["stage"]=4,["id"]="EmberEmperorSeed"},{["biome"]="Crystal",["index"]=1,["name"]="Amethyst Grape",["rarity"]="Common",["design"]="violet to lavender, three pale grape dots",["pattern"]="Dots",["top"]="965ec2",["bottom"]="dbc1fb",["ink"]="f4e5ff",["addition"]="none",["stage"]=5,["id"]="AmethystSeed"},{["biome"]="Crystal",["index"]=2,["name"]="Prism Pepper",["rarity"]="Uncommon",["design"]="teal to lilac, tiny diamond flecks and short quartz point",["pattern"]="Specks",["top"]="6cbecd",["bottom"]="d5b5f2",["ink"]="f4ffff",["addition"]="crystals",["stage"]=5,["id"]="PrismOrchidSeed"},{["biome"]="Crystal",["index"]=3,["name"]="Moon Melon",["rarity"]="Rare",["design"]="lavender to pearl, moon mark and two small silver leaf fins",["pattern"]="Leaf",["top"]="a296c9",["bottom"]="f4eafa",["ink"]="e7fdff",["addition"]="leaves",["stage"]=5,["id"]="MoonflowerSeed"},{["biome"]="Crystal",["index"]=4,["name"]="Starfruit",["rarity"]="Legendary",["design"]="gold to pale yellow, broad crystal star crest and tiny gold sparkles",["pattern"]="Star",["top"]="eab956",["bottom"]="fff1ab",["ink"]="ffffdf",["addition"]="crest",["stage"]=5,["id"]="StarfruitSeed"},{["biome"]="Crystal",["index"]=5,["name"]="Diamond Vine",["rarity"]="Mythic",["design"]="azure to clear ice, long transparent diamond cluster and silver vine curl",["pattern"]="Leaf",["top"]="75b6db",["bottom"]="e4fbff",["ink"]="fcffff",["addition"]="crystals",["stage"]=5,["id"]="DiamondVineSeed"},{["biome"]="Crystal",["index"]=6,["name"]="Hollow Geode",["rarity"]="Secret",["design"]="graphite to violet, oval face geode seam with bright violet crystals, broken ring",["pattern"]="Dots",["top"]="514363",["bottom"]="aa7acf",["ink"]="ebbbff",["addition"]="brokenHalo",["stage"]=5,["id"]="HollowGeodeSeed"},{["biome"]="Crystal",["index"]=7,["name"]="Orbit Lotus",["rarity"]="Cosmic",["design"]="indigo to lilac, stars, two tilted lavender orbit rings, floating prism gems",["pattern"]="Star",["top"]="4b438e",["bottom"]="cbadf3",["ink"]="fbebff",["addition"]="orbit",["stage"]=5,["id"]="OrbitLotusSeed"},{["biome"]="Crystal",["index"]=8,["name"]="Prism Monarch",["rarity"]="King",["design"]="pearl to violet, massive asymmetrical quartz crown with gold setting and rainbow core",["pattern"]="Star",["top"]="b08be0",["bottom"]="fff2fb",["ink"]="c8ffff",["addition"]="crown",["stage"]=5,["id"]="PrismMonarchSeed"},{["biome"]="Storm",["index"]=1,["name"]="Static Grass",["rarity"]="Common",["design"]="slate blue to pale cyan, three yellow flecks",["pattern"]="Specks",["top"]="63889e",["bottom"]="c9e9ee",["ink"]="ffde69",["addition"]="none",["stage"]=7,["id"]="StaticGrassSeed"},{["biome"]="Storm",["index"]=2,["name"]="Spark Reed",["rarity"]="Uncommon",["design"]="teal to electric blue, two reed-like yellow antennae",["pattern"]="Stripes",["top"]="337a9e",["bottom"]="9feff1",["ink"]="ffe783",["addition"]="antennae",["stage"]=7,["id"]="SparkReedSeed"},{["biome"]="Storm",["index"]=3,["name"]="Thunder Tulip",["rarity"]="Rare",["design"]="blue to cyan, thick yellow lightning mark and short electric arc",["pattern"]="Star",["top"]="377bbc",["bottom"]="a0f6ff",["ink"]="fff06e",["addition"]="bolts",["stage"]=7,["id"]="ThunderTulipSeed"},{["biome"]="Storm",["index"]=4,["name"]="Volt Orchid",["rarity"]="Legendary",["design"]="violet to electric blue, thick bolt-shaped yellow petals, bright small arcs",["pattern"]="Star",["top"]="7861c4",["bottom"]="73d8f4",["ink"]="fff388",["addition"]="bolts",["stage"]=7,["id"]="VoltOrchidSeed"},{["biome"]="Storm",["index"]=5,["name"]="Tempest Lotus",["rarity"]="Mythic",["design"]="cobalt to white, three swept lightning fins and circular electric arc",["pattern"]="Star",["top"]="3d69c9",["bottom"]="d9fcff",["ink"]="ffec6e",["addition"]="bolts",["stage"]=7,["id"]="TempestLotusSeed"},{["biome"]="Storm",["index"]=6,["name"]="Blackout Bloom",["rarity"]="Secret",["design"]="black navy to purple, one white electric slit, broken violet electric halo",["pattern"]="Leaf",["top"]="242a48",["bottom"]="7771bc",["ink"]="eef1ff",["addition"]="brokenHalo",["stage"]=7,["id"]="BlackoutBloomSeed"},{["biome"]="Storm",["index"]=7,["name"]="Pulsar Starfruit",["rarity"]="Cosmic",["design"]="midnight blue to lavender, star flecks, yellow charged orbital ring and sparks",["pattern"]="Star",["top"]="343e89",["bottom"]="afc9ff",["ink"]="ffe970",["addition"]="orbit",["stage"]=7,["id"]="PulsarStarfruitSeed"},{["biome"]="Storm",["index"]=8,["name"]="Storm Sovereign",["rarity"]="King",["design"]="royal blue to pale cyan, tall thick lightning crown, central diamond and orbiting electric bolts",["pattern"]="Star",["top"]="326ad0",["bottom"]="c8fbff",["ink"]="fff36c",["addition"]="crownBolts",["stage"]=7,["id"]="StormSovereignSeed"}}
-- V139: preserve all eight identities per biome; promote the old lower entries.
-- Stage numbers are stable save IDs, not physical progression order.
Rules.MinimumSeedRarityByStage={[1]="Common",[6]="Common",[2]="Uncommon",[3]="Uncommon",[4]="Rare",[5]="Rare",[7]="Rare"}
function Rules.MinimumSeedRank(stage)
 for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.Rarities[Rules.MinimumSeedRarityByStage[stage]or "Common"].Rank
end
Rules.SeedMotion={Tag="ChestChaseLooseSeed",MaxDistance=120,DetailDistance=65,MaxActive=12,MaxDetailed=6,UpdateInterval=1/30,SelectionInterval=.25}
Rules.SeedRarityById={};Rules.SeedDesignById={}
for _,spec in ipairs(Rules.SeedDesigns)do
 if spec.id == "StaticGrassSeed" then spec.name = "Bolt Bean" end
 if Rules.Rarities[spec.rarity].Rank<Rules.MinimumSeedRank(spec.stage)then
  spec.rarity=Rules.MinimumSeedRarityByStage[spec.stage]
 end
 Rules.SeedRarityById[spec.id]=spec.rarity;Rules.SeedDesignById[spec.id]=spec
end
-- V149 final: hidden compatibility definition, excluded from obtainable designs.
Rules.RetiredSeedIds = {AgaveSeed=true,DragonfruitSeed=true,MonsteraSeed=true,AloeSeed=true,BananaSeed=true,StrawberrySeed=true,FrostFernSeed=true,DesertRoseSeed=true,CloverSeed=true,StaticGrassSeed=true,SunKingPalmSeed=true}
function Rules.IsRetired(id) for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
return Rules.RetiredSeedIds[id] == true end
local legacyPear = table.clone(Rules.SeedDesignById.CactusSeed)
legacyPear.id = "DesertRoseSeed"; legacyPear.index = 3; legacyPear.rarity = "Rare"
legacyPear.retired = true
Rules.SeedDesignById.DesertRoseSeed = legacyPear
Rules.SeedRarityById.DesertRoseSeed = "Rare"
-- Old saved bean IDs display existing crops; no pod art or bean collection entries remain.
for id,target in pairs({CloverSeed='StrawberrySeed',StaticGrassSeed='SparkReedSeed',SunKingPalmSeed='SolarStarfruitSeed'})do
 local old=Rules.SeedDesignById[id];local replacement=table.clone(Rules.SeedDesignById[target])
 replacement.id=id;replacement.index=old.index;replacement.stage=old.stage;replacement.biome=old.biome;replacement.rarity=old.rarity;replacement.retired=true
 Rules.SeedDesignById[id]=replacement
end
-- Keep original stage/index slots for old records and fallback lookups.
-- Acquisition is a separate map; moving a crop must never reinterpret an old save.
for _,spec in pairs(Rules.SeedDesignById)do spec.SaveStage=spec.stage end
for id,fields in pairs({DragonfruitSeed={stage=2,biome='Desert'},StarfruitSeed={stage=2,biome='Desert',name='Dune Starfruit'}})do
 local spec=Rules.SeedDesignById[id]
 for key,value in pairs(fields)do spec[key]=value end
end
-- R37: presentation and roll weights share the same rarity identity.
for id,rarity in pairs({SolarStarfruitSeed='King',MirageFigSeed='Cosmic',StarfruitSeed='Secret',PulsarStarfruitSeed='King',StormSovereignSeed='Cosmic'})do
 Rules.SeedRarityById[id]=rarity;Rules.SeedDesignById[id].rarity=rarity
end
function Rules.ObtainableStage(id)
 local spec=Rules.SeedDesignById[id];return spec and spec.stage
end
for i=#Rules.SeedDesigns,1,-1 do if Rules.IsRetired(Rules.SeedDesigns[i].id)then table.remove(Rules.SeedDesigns,i)end end
function Rules.BuildSeedCatalog()
 local catalog={{},{},{},{},{},{},{},{}}
 for id,spec in pairs(Rules.SeedDesignById)do
  local hex=spec.top
  catalog[spec.SaveStage][spec.index]={Id=id,Name=spec.name..' Seed',Emoji='🌱',Retired=Rules.IsRetired(id),ObtainStage=spec.stage,
   Color=Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))}
 end
 return catalog
end
local obtainableCache=setmetatable({},{__mode='k'})
function Rules.ObtainablePool(config,stage)
 local pools=obtainableCache[config]
 if not pools then
  pools={{},{},{},{},{},{},{},{}}
  for _,catalog in ipairs(config.SeedCatalogByStage)do for _,seed in ipairs(catalog)do
   if not Rules.IsRetired(seed.Id)then table.insert(pools[Rules.ObtainableStage(seed.Id)],seed)end
  end end
  obtainableCache[config]=pools
 end
 return pools[stage]
end
local styles = {
    SunflowerSeed = {{178,235,148},{30,110,51},"Stripes",{24,83,33}},
    CloverSeed = {{240,246,137},{115,165,35},"Dots",{62,122,32}},
    BluebellSeed = {{192,163,244},{47,70,156},"Star",{220,206,255}},
    StrawberrySeed = {{255,180,189},{186,36,60},"Specks",{255,237,187}},
    AppleSeed = {{255,221,130},{215,85,42},"Leaf",{255,240,189}},
}
function Rules.GetRarity(seedId)
    local name = Rules.SeedRarityById[seedId] or "Common"
    return name, Rules.Rarities[name] or Rules.Rarities.Common
end
function Rules.GetStyle(seed, index)
    local spec=Rules.SeedDesignById[seed.Id]
    if spec then
        local function rgb(h)return Color3.fromRGB(tonumber(h:sub(1,2),16),tonumber(h:sub(3,4),16),tonumber(h:sub(5,6),16))end
        return rgb(spec.top),rgb(spec.bottom),spec.pattern,rgb(spec.ink)
    end
    local preset = styles[seed.Id]
    if preset then
        return Color3.fromRGB(table.unpack(preset[1])), Color3.fromRGB(table.unpack(preset[2])),
            preset[3], Color3.fromRGB(table.unpack(preset[4]))
    end
    local patterns = {"Stripes","Dots","Star","Specks","Leaf"}
    return seed.Color:Lerp(Color3.new(1,1,1),0.48), seed.Color:Lerp(Color3.new(0,0,0),0.27),
        patterns[((index or 1)-1)%#patterns+1], Color3.fromRGB(255,238,194)
end
function Rules.SeedWeights(pool,stage,variant,luck)
    local weights,total,counts={},0,{}
    for _,seed in ipairs(pool)do
        if not Rules.IsRetired(seed.Id) then
            local name=Rules.GetRarity(seed.Id);counts[name]=(counts[name]or 0)+1
        end
    end
    for i, seed in ipairs(pool) do
        if Rules.IsRetired(seed.Id) then weights[i]=0; continue end
        local name, rarity = Rules.GetRarity(seed.Id)
        -- Rarity weights are shared by duplicate-rarity seeds, not multiplied by their count.
        local weight=rarity.Weight/counts[name]
        -- Luck improves the chances above this biome's minimum, including late biomes.
        weight=weight*(1+(variant.RareBias-1)*(rarity.Rank-1)/7)*(rarity.Rank>Rules.MinimumSeedRank(stage) and luck or 1)
        weights[i] = weight; total += weight
    end
    return weights,total
end
function Rules.SeedOdds(config,stage,variantKey,luck)
 local out={}
 if stage==8 then for _,s in ipairs(require(script.Parent.MechCatalog).Seeds)do out[s.Id]=s.Chance end;return out end
 local pool=Rules.ObtainablePool(config,stage)or{};local weights,total=Rules.SeedWeights(pool,stage,Rules.GetVariant(variantKey),math.clamp(tonumber(luck)or 1,1,5))
 if total>0 then for i,s in ipairs(pool)do out[s.Id]=weights[i]/total*100 end end;return out
end
function Rules.Roll(config, stage, unitRoll, luck, variantKey)
    if variantKey=='MechLimited'then
        if stage~=8 then return nil end
        local item=require(script.Parent.MechCatalog).Roll(unitRoll)
        return item and config.GetSeedById(item.Id),item and item.Rarity
    end
    if stage==8 then return nil end
    local pool = Rules.ObtainablePool(config,stage)
    if not pool or #pool == 0 then return nil end
    if type(unitRoll) ~= "number" or unitRoll ~= unitRoll then return nil end
    luck = tonumber(luck) or 1
    if luck ~= luck then luck = 1 end
    luck = math.clamp(luck,1,5)
    local variant = Rules.GetVariant(variantKey)
    local weights,total=Rules.SeedWeights(pool,stage,variant,luck)
    if total <= 0 then return nil end
    local ticket = math.clamp(unitRoll,0,1-1e-12) * total
    for i, weight in ipairs(weights) do
        if ticket < weight then return pool[i], Rules.GetRarity(pool[i].Id) end
        ticket -= weight
    end
    return nil
end
-- V126: independent cosmetic traits; seed rewards/economy remain unchanged.
Rules.PackSizes=require(script.Parent.BalanceRules).PackSizes
Rules.PackMutations={
    None={Weight=95},
    Gold={Weight=4.5,Color=Color3.fromRGB(255,201,70),Aura=Color3.fromRGB(255,210,79),Material=Enum.Material.Metal},
    Diamond={Weight=.5,Color=Color3.fromRGB(213,247,255),Aura=Color3.fromRGB(214,250,255),Material=Enum.Material.Glass},
}
Rules.MutationOrder={'None','Gold','Diamond'}
function Rules.SanitizePackSize(value)
    if type(value)~='number'or value~=value or math.abs(value)==math.huge then return 1 end
    return math.floor(math.clamp(value,.5,Rules.MaxPackSize)*1000+.5)/1000
end
-- Retired Wicked saves become ordinary packs; biome, tier, size and inventory ID survive.
function Rules.MutationKey(value)return type(value)=='string'and Rules.PackMutations[value]and value or 'None'end
local function ticket(value)
    return type(value)=='number'and value==value and math.clamp(value,0,1-1e-12)*100 or 0
end
function Rules.RollPackSize(value)
    local t=ticket(value)
    for _,entry in ipairs(Rules.PackSizes)do t-=entry.Weight;if t<0 then return entry.Scale end end
    return 1
end
function Rules.RollMutation(value)
    local t=ticket(value)
    for _,key in ipairs(Rules.MutationOrder)do t-=Rules.PackMutations[key].Weight;if t<0 then return key end end
    return 'None'
end
function Rules.PackLabel(stage,variant,size,mutation)
    if variant=='EclipseReliquary'then local m=Rules.MutationKey(mutation);return(m~='None'and m..' 'or'')..'Void Pack'end
    if variant=='MechLimited'then return 'Limited Mech Pack'end
    mutation=Rules.MutationKey(mutation)
    return (mutation~='None'and mutation..' 'or '')..
        (Rules.DesignBiomes[stage]or 'Biome')..' Seed Pack'
end

-- V138. Shared pure animation math; seed rarity, never pack tier, selects the reveal.
function Rules.RevealPose(rank,age,ease)
    local V,CF=Vector3.new,CFrame.new
    local y=.05*math.sin(age*2);local x,z,roll=0,0,0;local yaw=age*.45
    if rank==2 then y=math.abs(math.sin(age*2.5))*.15;yaw=age*.7;roll=math.sin(age*2)*.06
    elseif rank==3 then x=math.sin(age*2)*.16;z=math.cos(age*2)*.12;y=.12+math.sin(age*2)*.09;yaw=age*1.25
    elseif rank==4 then y=.28+math.sin(age*1.8)*.07;yaw=age*.55;roll=math.sin(age*1.5)*.06
    elseif rank==5 then x=math.sin(age*1.4)*.12;y=.4+math.sin(age*2)*.12;yaw=age*.85;roll=math.sin(age*1.7)*.09
    elseif rank==6 then y=.26+math.sin(age*1.2)*.06;yaw=math.sin(age*.8)*.32
    elseif rank==7 then x=math.sin(age)*.22;z=math.cos(age)*.14;y=.44+math.sin(age*1.7)*.12;yaw=age*.72;roll=math.sin(age)*.15
    elseif rank>=8 then y=.58+math.sin(age*1.3)*.04;yaw=.20*math.sin(age*.7) end
    return CF(V(x,y,z)*ease)*CFrame.Angles(0,yaw,roll)
end
function Rules.RevealAuraPoint(rank,index,count,age,radius)
    local V=Vector3.new
    local t=(index-1)*math.pi*2/count
    if rank==1 then return V(math.cos(t+age*.3)*radius,math.sin(t*2+age)*radius*.24,math.sin(t+age*.3)*radius),false
    elseif rank==2 then return V(math.cos(t-age*.65)*radius,math.sin(t+age)*radius*.45,math.sin(t-age*.65)*radius),false
    end
    -- Legacy callers also get drifting points, never the rejected short straight rays.
    local phase=(index-1)*2.39996+.4
    local life=(age*(.085+((index-1)%5)*.012)+((index-1)*.618034)%1)%1
    return V(math.cos(phase)*radius+math.sin(age*.48+phase)*radius*.12,
        (-.86+life*2.3)*radius,math.sin(phase)*radius*.8),false
end

for _,spec in ipairs(Rules.SeedDesigns)do if spec.id=='SupernovaBloomSeed'then spec.name='Boom Bloom'end end
local rarityTheme=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTheme'))
for name,style in pairs(Rules.Rarities)do if rarityTheme.Rarities[name]then style.Color=rarityTheme.Rarity(name).Color end end
-- Limited inventory category; excluded from world VariantOrder and StageCount.
local Mech=require(script.Parent.MechCatalog)
Rules.Variants.MechLimited={Name=Mech.Name,BagScale=1,SeedScale=1,RareBias=1,SpawnWeight=0,Trim=6,Design=1}
Rules.DesignBiomes[8]='Mech'
Rules.BiomeThemes[8]={Body=Color3.fromRGB(31,43,57),Ink=Color3.fromRGB(63,224,255),Trim=Color3.fromRGB(244,178,57),Mark='Mech',Scale=1}
for index,s in ipairs(Mech.Seeds)do
 local spec={id=s.Id,name=s.Name,rarity=s.Rarity,stage=8,SaveStage=8,biome='Mech',index=index,top='36a6ff',bottom='1f2b39',ink='60dbff',pattern='Leaf',addition='none'}
 table.insert(Rules.SeedDesigns,spec);Rules.SeedDesignById[s.Id]=spec;Rules.SeedRarityById[s.Id]=s.Rarity
end
for name,weight in pairs(require(script.Parent.BalanceRules).RarityWeights)do Rules.Rarities[name].Weight=weight;Rules.Rarities[name].Duration=Rules.GetRevealDuration(name)end

-- Versioned R81 world packs. Legacy unversioned and Small/Standard/Grand keep old Roll.
local oldRoll=Rules.Roll
local oldOdds=Rules.SeedOdds
local O=require(script.Parent.PackOdds81)
local approved=require(script.Parent.BalanceValues81)
for i,key in ipairs(Rules.VariantOrder)do Rules.Variants[key].SpawnWeight=approved.SpawnWeights[i]end
Rules.Variants.EclipseReliquary={Name='Void Pack',BagScale=.96,SeedScale=1.35,RareBias=1,SpawnWeight=0,Trim=7,Design=6,OddsLabel='All Secret / Cosmic / King seeds + 1/200 Mech roll'}
function Rules.RewardPool(config,stage,variant)
 if variant=='EclipseReliquary'then local _,all=require(script.Parent.VoidPackOdds85).Pools(config,Rules);return all end
 return Rules.ObtainablePool(config,stage)
end
function Rules.SeedOdds(config,stage,variantKey,luck,version)
 if variantKey=='EclipseReliquary'then return stage==7 and require(script.Parent.VoidPackOdds85).Odds(config,Rules)or{}end
 if stage==8 or(version~=nil and version~=81)or(not approved.SeedWeights[variantKey]and variantKey~='EclipseReliquary')then return oldOdds(config,stage,variantKey,luck)end
 if variantKey=='EclipseReliquary'and stage~=7 then return {}end
 local pool=Rules.ObtainablePool(config,stage)or{}
 local weights,total=O.Weights(pool,Rules.GetRarity,variantKey,luck)
 local out={};if total and total>0 then for i,seed in ipairs(pool)do out[seed.Id]=100*weights[i]/total end end
 return out
end
function Rules.Roll(config,stage,unitRoll,luck,variantKey,version)
 if variantKey=='EclipseReliquary'then
  if stage~=7 then return nil end
  return require(script.Parent.VoidPackOdds85).Roll(config,Rules,unitRoll)
 end
 if version~=81 or stage==8 or(not approved.SeedWeights[variantKey]and variantKey~='EclipseReliquary')then return oldRoll(config,stage,unitRoll,luck,variantKey)end
 if variantKey=='EclipseReliquary'and stage~=7 then return nil end
 if type(unitRoll)~='number'or unitRoll~=unitRoll or math.abs(unitRoll)==math.huge then return nil end
 local pool=Rules.ObtainablePool(config,stage)or{}
 local weights,total=O.Weights(pool,Rules.GetRarity,variantKey,luck)
 if not total or total<=0 then return nil end
 local ticket=math.clamp(unitRoll,0,1-1e-12)*total
 for i,weight in ipairs(weights)do if ticket<weight then return pool[i],Rules.GetRarity(pool[i].Id)end;ticket-=weight end
 return nil
end

return Rules
]=]
SOURCES['SpeedPoints']=[=[-- R81: exact, non-negative whole points. Decimal strings are authoritative.
local P={}
function P.Valid(v)
 return type(v)=='string' and #v>0 and v:match('^%d+$')~=nil
end
function P.Normalize(v)
 if P.Valid(v)then local s=v:gsub('^0+','');return s~=''and s or'0'end
 if type(v)=='number'and v==v and v>=0 and v<math.huge then return string.format('%.0f',math.floor(v+.5))end
 return '0'
end
function P.Compare(a,b)
 a=P.Normalize(a);b=P.Normalize(b)
 if #a~=#b then return #a<#b and -1 or 1 end
 return a==b and 0 or a<b and -1 or 1
end
function P.Add(a,b)
 a=P.Normalize(a);b=P.Normalize(b);local out={};local i,j,carry=#a,#b,0
 while i>0 or j>0 or carry>0 do
  local n=(i>0 and a:byte(i)-48 or 0)+(j>0 and b:byte(j)-48 or 0)+carry
  out[#out+1]=string.char(48+n%10);carry=math.floor(n/10);i-=1;j-=1
 end
 return #out>0 and table.concat(out):reverse()or'0'
end
function P.Log10(v)
 v=P.Normalize(v);if v=='0'then return 0 end
 local n=math.min(14,#v)
 return #v-n+math.log10(tonumber(v:sub(1,n)))
end
function P.Exact(v)
 local s=P.Normalize(v):reverse():gsub('(%d%d%d)','%1,'):reverse()
 return(s:gsub('^,',''))
end
function P.Compact(v)
 v=P.Normalize(v);if #v<7 then return v end
 local suffixes={'','K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc'}
 local group=math.floor((#v-1)/3);local first=#v-group*3
 local lead=tonumber(v:sub(1,first));local tenth=tonumber(v:sub(first+1,first+1))or 0
 local text=tostring(lead)..(tenth>0 and'.'..tenth or'')
 return text..(suffixes[group+1]or('e'..tostring(group*3)))
end
function P.LegacyNumber(v,limit)
 v=P.Normalize(v);limit=limit or 1000000000
 return P.Compare(v,limit)>0 and limit or tonumber(v)
end
return P
]=]
SOURCES['Progression81']=[=[-- R88: practical 500 speed ceiling; exact saved points continue without a designed cap.
local Points=require(script.Parent.SpeedPoints)
local T=require(script.Parent.BalanceValues81)
local R={}
-- Saved points keep their R81 meaning; only the physical pace changes in R82.
local migrationCurve={{0,24},{20000,30},{100000,45},{500000,75},{2000000,130},{20000000,300},{500000000,650},{20000000000,1300},{1000000000000,2400},{20000000000000,3800},{100000000000000,5000}}
local function curveSpeed(points,knots,tail,logarithmic)
 local s=Points.Normalize(points);local last=knots[#knots]
 if Points.Compare(s,Points.Normalize(last[1]))>0 then return last[2]+tail*(Points.Log10(s)-math.log10(last[1]))end
 local n=tonumber(s)
 for i=2,#knots do local a,b=knots[i-1],knots[i]
  if n<=b[1]then
   local t=logarithmic and a[1]>=2000000 and math.log(n/a[1])/math.log(b[1]/a[1])or(n-a[1])/(b[1]-a[1])
   return a[2]+(b[2]-a[2])*t
  end
 end
 return last[2]
end
function R.Speed(points)return curveSpeed(points,T.PointCurve,T.SpeedTailPerDecade,true)end
function R.PointsAt(speed)
 if speed<=24 then return '0'end
 for i=2,#migrationCurve do
  local a,b=migrationCurve[i-1],migrationCurve[i]
  if speed<=b[2]then return Points.Normalize(math.ceil(a[1]+(b[1]-a[1])*(speed-a[2])/(b[2]-a[2])))end
 end
 -- Migration only calls this with the old finite ceiling (5,000).
 return '100000000000000'
end
local old={{0,24},{1000,28},{5000,32},{15000,37},{35000,43},{75000,50},{150000,58},{300000,66},{600000,74},
 {2000000,125},{5000000,220},{15000000,500},{35000000,1000},{75000000,2000},{150000000,3000},{350000000,4000},{600000000,4500}}
function R.LegacySpeed(n)
 n=math.clamp(tonumber(n)or 0,0,1000000000)
 for i=2,#old do local a,b=old[i-1],old[i];if n<=b[1]then return a[2]+(b[2]-a[2])*(n-a[1])/(b[1]-a[1])end end
 return 4500+500*math.log(n/600000000)/math.log(1000000000/600000000)
end
function R.Migrate(oldPoints)
 local original=Points.Normalize(oldPoints);local converted=R.PointsAt(R.LegacySpeed(oldPoints))
 return Points.Compare(original,converted)>0 and original or converted
end
function R.LegacySave(points)
 local speed=curveSpeed(points,migrationCurve,100)
 for i=2,#old do local a,b=old[i-1],old[i];if speed<=b[2]then return math.ceil(a[1]+(b[1]-a[1])*(speed-a[2])/(b[2]-a[2]))end end
 return math.min(1000000000,math.ceil(600000000*(1000000000/600000000)^((math.min(speed,5000)-4500)/500)))
end
function R.Playback(speed)
 local knots=T.AnimationRateCurve
 for i=2,#knots do local a,b=knots[i-1],knots[i];if speed<=b[1]then return a[2]+(b[2]-a[2])*(math.max(0,speed)-a[1])/(b[1]-a[1])end end
 return 10
end
return R
]=]
SOURCES['PackSchedule81']=[=[-- One shared scheduled floor. Natural luck never restarts the counter.
local S={}
function S.Plan(cycle,variants,randomInteger)
 local reserved={};local result=table.clone(variants)
 local function ensure(tier)
  for i,key in ipairs(result)do if key==tier and not reserved[i]then reserved[i]=true;return end end
  local candidates,lowest={},math.huge
  for i,key in ipairs(result)do if not reserved[i]then
   local rank=tonumber(key:match('(%d+)$'))or 0
   if rank<lowest then lowest=rank;candidates={i}elseif rank==lowest then table.insert(candidates,i)end
  end end
  if #candidates==0 then return end
  local index=candidates[randomInteger(1,#candidates)];result[index]=tier;reserved[index]=true
 end
 if cycle>0 and cycle%5==0 then ensure('Pack05')end
 if cycle>0 and cycle%10==0 then ensure('Pack06')end
 return result
end
function S.Event(cycle)return cycle>0 and cycle%3==0 end
-- Exact marginal tier odds for a uniformly chosen slot after Plan's shared floors.
-- Floors replace the lowest unreserved tier; summing the removed order statistics
-- keeps announcements honest without changing any rolls or guaranteed spawns.
function S.Probabilities(cycle,count,weights)
 local n=math.max(0,math.floor(tonumber(count)or 0));local p,total={},0
 for i=1,6 do total+=math.max(0,tonumber(weights[i])or 0)end
 if total<=0 then return {}end
 for i=1,6 do p[i]=math.max(0,tonumber(weights[i])or 0)/total end
 if n==0 or cycle<=0 or cycle%5~=0 then return p end
 if n==1 then return {0,0,0,0,1,0}end
 local counts={};for i=1,6 do counts[i]=n*p[i]end
 local function tail(first,omit5,omit6)
  local sum=0;for i=first,6 do if not(omit5 and i==5)and not(omit6 and i==6)then sum+=p[i]end end;return sum
 end
 -- First floor: insert Pack05 only when absent, removing the minimum original tier.
 for j=1,6 do if j~=5 then local removed=tail(j,true,false)^n-tail(j+1,true,false)^n;counts[j]-=removed;counts[5]+=removed end end
 if cycle%10==0 then
  -- With no natural Pack06, the first floor either reserves a natural Pack05,
  -- or removes the first minimum. The second floor then removes the second minimum.
  local lowTotal=tail(1,true,true)
  local function secondTail(first)
   local q=tail(first,true,true);local below=math.max(0,lowTotal-q)
   return q^n+n*below*q^(n-1)
  end
  for j=1,4 do
   local natural=tail(j,false,true)^n-tail(j+1,false,true)^n
   local noFive=tail(j,true,true)^n-tail(j+1,true,true)^n
   local removed=natural-noFive+secondTail(j)-secondTail(j+1)
   counts[j]-=removed;counts[6]+=removed
  end
  local removed=p[5]^n;counts[5]-=removed;counts[6]+=removed
 end
 for i=1,6 do p[i]=math.clamp(counts[i]/n,0,1)end
 return p
end
return S
]=]
SOURCES['VoidPackOdds85']=[=[-- All regular obtainable Secret/Cosmic/King seeds, plus a nested normal Mech roll.
-- A single server random ticket selects both branches without rerolling rewards.
local Mech=require(script.Parent.MechCatalog)
local V={MechChance=.005,DirectChance=.995}
local cache=setmetatable({},{__mode='k'})
function V.Pools(config,rules)
 local hit=cache[config];if hit then return hit.Direct,hit.All end
 local direct,all,seen={},{},{}
 for _,spec in ipairs(rules.SeedDesigns)do
  local seed=config.GetSeedById(spec.id);local rarity=rules.GetRarity(spec.id)
  if seed and not Mech.Is(spec.id)and not rules.IsRetired(spec.id)and(rarity=='Secret'or rarity=='Cosmic'or rarity=='King')and not seen[seed.Id]then
   seen[seed.Id]=true;table.insert(direct,seed);table.insert(all,seed)
  end
 end
 for _,spec in ipairs(Mech.Seeds)do
  local seed=config.GetSeedById(spec.Id)
  if seed and not seen[seed.Id]then seen[seed.Id]=true;table.insert(all,seed)end
 end
 cache[config]={Direct=direct,All=all};return direct,all
end
function V.Odds(config,rules)
 local pool=V.Pools(config,rules)
 local weights,total=require(script.Parent.PackOdds81).Weights(pool,rules.GetRarity,'EclipseReliquary',1)
 local out={};if not total or total<=0 then return out end
 for i,seed in ipairs(pool)do out[seed.Id]=100*V.DirectChance*weights[i]/total end
 for _,seed in ipairs(Mech.Seeds)do
  if config.GetSeedById(seed.Id)then out[seed.Id]=(out[seed.Id]or 0)+V.MechChance*seed.Chance end
 end
 return out
end
function V.Roll(config,rules,unit)
 if type(unit)~='number'or unit~=unit or math.abs(unit)==math.huge then return nil end
 unit=math.clamp(unit,0,1-1e-12)
 if unit>=V.DirectChance then
  local item=Mech.Roll((unit-V.DirectChance)/V.MechChance)
  return item and config.GetSeedById(item.Id),item and item.Rarity
 end
 local pool=V.Pools(config,rules)
 local weights,total=require(script.Parent.PackOdds81).Weights(pool,rules.GetRarity,'EclipseReliquary',1)
 if not total or total<=0 then return nil end
 local ticket=unit/V.DirectChance*total
 for i,w in ipairs(weights)do
  if ticket<w then return pool[i],rules.GetRarity(pool[i].Id)end;ticket-=w
 end
 return nil
end
return V
]=]
SOURCES['MechCatalog']=[=[-- R57: independent limited pool. Stage 8 is an inventory/index category, not a new map biome.
local C={Stage=8,Variant='MechLimited',Name='Limited Mech Pack',GemPrice=80,TargetRobuxPrice=80,
 CashPerGem=1000000000000,BiomeGemReward=5,MaxGems=1000000,PassGemPrices={Growth=500,Speed=400},
 Seeds={{Id="PlasmaPepperSeed",Model="PlasmaPepper",Name="Plasma Pepper",Rarity="Legendary",Chance=48,Seconds=300,RegrowSeconds=150,Value=2200,FruitCount=3,Sockets={{-1.55,2.65,0.55},{1.48,3.8,0.55},{0.1,5.75,0.4}},FruitCenters={{-1.0757282170086793,2.483650295115767,0.48401375197001806},{1.1935696789565,3.7871071966575,0.5027232714765},{0.10211435939480645,5.550225416481371,0.41057506141071337}},FruitRadii={1.6608584659479688,1.7001043318119347,1.322119407900125},Height=6.616154722962742,Radius=2.4560985900000003,HarvestName="Plasma Pepper",Tree=false},{Id="HoloMelonSeed",Model="HoloMelon",Name="Holo Melon",Rarity="Mythic",Chance=26,Seconds=450,RegrowSeconds=240,Value=6200,FruitCount=1,Sockets={{0.0,3.65,0.0}},FruitCenters={{0.0,3.8185822497135002,0.0}},FruitRadii={2.9990342838621027},Height=5.5372384994270005,Radius=1.907275,HarvestName="Holo Melon",Tree=false},{Id="PrismLotusSeed",Model="PrismLotus",Name="Prism Lotus",Rarity="Mythic",Chance=16,Seconds=600,RegrowSeconds=300,Value=8500,FruitCount=1,Sockets={{0,2.1,0}},FruitCenters={{0.0,2.12,0.0}},FruitRadii={1.271706316486077},Height=3.724422,Radius=2.3000001208320002,HarvestName="Prism Lotus Core",Tree=false},{Id="HoloAppleTreeSeed",Model="HoloAppleTree",Name="Holo Apple Tree",Rarity="Secret",Chance=7,Seconds=900,RegrowSeconds=420,Value=15000,FruitCount=4,Sockets={{-2.784672,8.262243,2.710524},{1.30393,7.644601,3.110524},{5.051749,7.632096,1.110524},{-1.481048,8.188704,-2.789476}},FruitCenters={{-2.7846719999999996,8.248493641715,2.7000005},{1.30393,7.630850879215,3.1000004999999997},{5.051749,7.618345909215001,1.1000005},{-1.481048,8.174953866715,-2.7999995}},FruitRadii={2.16586497446425,2.3126894044636614,2.09609909083863,2.1350578224952574},Height=16.589552515069,Radius=7.313059001321499,HarvestName="Holo Apple",Tree=true},{Id="NebulaVineSeed",Model="NebulaVine",Name="Nebula Vine",Rarity="Cosmic",Chance=2.5,Seconds=1200,RegrowSeconds=600,Value=32000,FruitCount=3,Sockets={{-1.3,2.15,0.4},{1.43,4.45,0.3},{-0.65,6.58,0.4}},FruitCenters={{-0.7355104641499999,2.15,0.39999999999999997},{0.7782358609234998,4.45,0.3},{-0.48806668098975003,6.58,0.4}},FruitRadii={1.823059448641823,1.9601330668116077,1.4390673639266893},Height=7.529713980057,Radius=2.3598295599999997,HarvestName="Nebula Pod",Tree=false},{Id="CrowncoreTreeSeed",Model="CrowncoreTree",Name="Crowncore Tree",Rarity="King",Chance=0.5,Seconds=1800,RegrowSeconds=900,Value=90000,FruitCount=1,Sockets={{0,5.25,0.4}},FruitCenters={{0.0,5.305392865579,0.4}},FruitRadii={1.7498030241297566},Height=8.35,Radius=3.4146851255345005,HarvestName="Crowncore",Tree=true}}}
C.ById={};for _,s in ipairs(C.Seeds)do C.ById[s.Id]=s end
function C.Is(id)return C.ById[id]~=nil end
function C.Roll(unit)
 if type(unit)~='number'or unit~=unit or math.abs(unit)==math.huge then return nil end
 local ticket=math.clamp(unit,0,1-1e-12)*100
 for _,s in ipairs(C.Seeds)do if ticket<s.Chance then return s end;ticket-=s.Chance end
 return C.Seeds[#C.Seeds]
end
C.Offers={
 {Count=1,GemPrice=80,TargetRobuxPrice=80,Attribute='MechPackProductId'},
 {Count=5,GemPrice=375,TargetRobuxPrice=375,Attribute='MechPack5ProductId'},
 {Count=10,GemPrice=700,TargetRobuxPrice=700,Attribute='MechPack10ProductId'},
}
function C.Offer(count)
 if count==nil then count=1 end
 for _,offer in ipairs(C.Offers)do if count==offer.Count then return offer end end
 return nil
end
function C.ProductId(count)
 local offer=C.Offer(count);if not offer then return 0 end
 local id=tonumber(script:GetAttribute(offer.Attribute))
 return id and id>0 and id<9007199254740991 and id%1==0 and id or 0
end
function C.OnSale()
 local untilTime=tonumber(script:GetAttribute('SaleEndsAt'))or 0
 return script:GetAttribute('SaleEnabled')~=false and(untilTime==0 or os.time()<untilTime)
end
function C.ApplyPlants(catalog)
 for _,s in ipairs(C.Seeds)do
  local d=table.clone(s);d.Biome='Mech';d.Mode='repeat';d.BaseScale=1;d.AuthoredHeight=s.Height
  d.Mech=true;d.Rank=({Legendary=4,Mythic=5,Secret=6,Cosmic=7,King=8})[s.Rarity]
  d.HarvestMode='fruit';catalog[s.Id]=d
 end
end
return C
]=]
SOURCES['SizeNumbers']=[=[-- New rolled multipliers and player-facing sale traits use whole/half units.
local N={Max=25}
function N.Half(value)
 if type(value)~='number'or value~=value or math.abs(value)==math.huge then return 1 end
 return math.clamp(math.floor(value*2+.5)/2,.5,N.Max)
end
function N.Format(value)
 local n=type(value)=='number'and value==value and math.abs(value)<math.huge and math.max(.5,math.floor(value*2+.5)/2)or 1
 return n%1==0 and string.format('%.0f',n)or string.format('%.1f',n)
end
return N
]=]
SOURCES['RarityRevealSequence']=[=[-- R66: charge light at a fixed distance; a burst travels outward, never the emblem.
local R={}
function R.SeedAt(rank)return rank==8 and 3.35 or rank==7 and 2.45 or rank==6 and 1.35 or .1 end
function R.Sample(rank,t,reduced)
 local at=R.SeedAt(rank);local charge=math.clamp(t/at,0,1);local age=math.max(0,t-at)
 local burst=t>=at;local release=math.clamp(age/.75,0,1)
 return {Charge=charge,Rotation=reduced and 0 or t*28+charge^4*480,Scale=1,
  Flash=burst and math.clamp(1-math.max(0,age-.065)/.34,0,1)*(reduced and .3 or 1)or 0,
  Cover=rank>=6 and(1-math.clamp((age-.10)/.50,0,1))or 0,SeedVisible=burst,
  Burst=burst and age<.75,Done=burst and age>=.75,Expansion=1,
  BurstProgress=release,CoreVisible=not burst,CoreAlpha=.72-charge*.72,
  RaysAlpha=1-charge^2*.65,Age=age}
end
-- Tilted elliptical orbits, sampled with line segments instead of rounded rectangles.
function R.OrbitPoint(ring,theta,rotation)
 local radius=.205+ring*.044;local a=theta+math.rad(rotation)*(ring%2==0 and -1 or 1)
 local tilt=math.rad((ring-1)*57+12);local x=math.cos(a)*radius;local y=math.sin(a)*radius*(.29+ring*.055)
 return Vector2.new(.5+x*math.cos(tilt)-y*math.sin(tilt),.5+x*math.sin(tilt)+y*math.cos(tilt))
end
return R
]=]
SOURCES['KeeperPursuit']=[=[-- R80. Biome ceilings preserve progression; pursuit follows observed movement, not just earned points.
local Combat=require(script.Parent.KeeperCombat)
local Balance=require(script.Parent.BalanceRules)
local Motion=require(script.Parent.RunnerMotion)
local P={Rank={[1]=1,[6]=2,[2]=3,[3]=4,[4]=5,[5]=6,[7]=7}}
function P.Gap(stage)
    local rank=P.Rank[stage]or 1
    return Combat.Get(P.Rank[stage]and stage or 1).Reach+9-(rank-1)*.65
end
function P.AlarmDistance(stage)return Combat.Get(P.Rank[stage]and stage or 1).Reach+7 end
function P.Speed(_settings,_playerSpeed,distance,stage,_observedSpeed)
    local row=require(script.Parent.BalanceValues81).KeeperSpeeds[stage]or {20,23,27}
    local gap=Motion.Finite(distance)and math.max(0,distance)or 0
    if gap<=35 then return row[1]end
    if gap<=100 then return row[1]+(row[2]-row[1])*(gap-35)/65 end
    if gap<=250 then return row[2]+(row[3]-row[2])*(gap-100)/150 end
    return row[3]
end
function P.Smooth(current,target,dt)
    target=Motion.Finite(target)and math.max(0,target)or 0
    current=Motion.Finite(current)and math.max(0,current)or target
    dt=Motion.Finite(dt)and math.clamp(dt,0,.1)or 0
    return current+(target-current)*(1-math.exp(-dt/.15))
end

return P
]=]
SOURCES['KeeperCombat']=[=[-- R39. Shared attack timing; only the server decides a catch.
local M={Recovery=.30,HitHold=.07,MissCooldown=.35}
local stages={
 [1]={Windup=.30,Reach=9,Height=12},
 [2]={Windup=.22,Reach=12,Height=12},
 [3]={Windup=.24,Reach=10,Height=12},
 [4]={Windup=.32,Reach=16,Height=16},
 [5]={Windup=.32,Reach=14,Height=15},
 [6]={Windup=.28,Reach=9,Height=12},
 [7]={Windup=.34,Reach=16,Height=16},
}
function M.Get(stage)return assert(stages[stage],'Unknown keeper stage')end
function M.InReach(stage,keeperPosition,targetPosition,padding)
 local s=M.Get(stage);local delta=targetPosition-keeperPosition
 return Vector3.new(delta.X,0,delta.Z).Magnitude<=s.Reach+(padding or 0)and math.abs(delta.Y)<=s.Height
end
function M.HoldAfterHit(stage,now,started,lastHit)
 return type(started)=='number'and type(lastHit)=='number'and lastHit>=started
  and now<started+M.Get(stage).Windup+M.Recovery
end
local function smooth(t)t=math.clamp(t,0,1);return t*t*(3-2*t)end
function M.Pose(stage,now,started)
 if type(started)~='number'then return 0,0 end
 local elapsed=now-started;local windup=M.Get(stage).Windup
 if elapsed<0 or elapsed>windup+M.Recovery then return 0,0 end
 local load=smooth(elapsed/(windup*.70))
 local strike=smooth((elapsed-windup*.70)/(windup*.30))
 local fade=1-smooth((elapsed-windup-M.HitHold)/(M.Recovery-M.HitHold))
 return load*(1-strike),strike*fade
end
return M
]=]
SOURCES['RunnerMotion']=[=[-- R80. Horizontal movement math; the server owns the unlocked speed ceiling.
local M={Version=97,BaseSpeed=24,BaseAreaRatio=.4,TimeToTop=0,
    BrakeSeconds=.035,MinBraking=500,StoppingDistance=3,LateralStoppingDistance=3,
    AirControl=.35,Deadzone=.025,MaxStep=.1,CastLength=512,MaxCasts=16,Skin=.12}
local V=Vector3.new
function M.Finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function M.Cap(n)return M.Finite(n)and math.max(n,0)or M.BaseSpeed end
-- Earned speed remains separate from the temporary base-area movement limit.
function M.ZoneCap(earned,position,lineZ,centerX,halfWidth)
    earned=M.Cap(earned)
    if typeof(position)=='Vector3'and M.Finite(lineZ)and M.Finite(position.X)and M.Finite(position.Z)
        and position.Z>=lineZ and math.abs(position.X-(centerX or 0))<=(halfWidth or math.huge)then return earned end
    return earned*M.BaseAreaRatio
end
function M.AtPosition(earned,position)
    return M.ZoneCap(earned,position,script:GetAttribute('TrackBoundaryZ'),script:GetAttribute('TrackCenterX'),script:GetAttribute('TrackHalfWidth'))
end
-- The track is the intersection of the forward half-plane and its side edges.
-- Clip a segment against all three edges, including diagonal/lateral crossings.
local function trackInterval(from,to,lineZ,centerX,halfWidth)
    if typeof(from)~='Vector3'or typeof(to)~='Vector3'or not M.Finite(lineZ)
        or not M.Finite(from.X)or not M.Finite(from.Z)or not M.Finite(to.X)or not M.Finite(to.Z)then return nil end
    centerX=centerX or 0;halfWidth=halfWidth or math.huge
    if not M.Finite(centerX)or halfWidth~=halfWidth or halfWidth<0 then return nil end
    local lo,hi=0,1
    local function lower(start,delta,edge)
        if math.abs(delta)<1e-9 then return start>=edge end
        local t=(edge-start)/delta
        if delta>0 then lo=math.max(lo,t)else hi=math.min(hi,t)end
        return lo<=hi
    end
    local dx,dz=to.X-from.X,to.Z-from.Z
    if not lower(from.Z,dz,lineZ)then return nil end
    if halfWidth<math.huge then
        if not lower(from.X,dx,centerX-halfWidth)or not lower(-from.X,-dx,-centerX-halfWidth)then return nil end
    end
    if lo>1 or hi<0 then return nil end
    return math.clamp(lo,0,1),math.clamp(hi,0,1)
end
-- Allocate travel time across both zones, rather than granting an entire
-- high-speed sample whenever a packet happens to end on the track.
function M.TravelAllowance(earned,from,to,elapsed,lineZ,centerX,halfWidth)
    local b=M.ZoneCap(earned,to,lineZ,centerX,halfWidth)
    earned=M.Cap(earned)
    if earned==0 then return 0,b end
    local lo,hi=trackInterval(from,to,lineZ,centerX,halfWidth)
    local fractionInBase=lo and 1-(hi-lo)or 1
    local slow=earned*M.BaseAreaRatio
    local effective=1/(fractionInBase/slow+(1-fractionInBase)/earned)
    return M.Allowance(effective,elapsed),b
end
function M.BoundaryStep(velocity,position,earned,dt)
    local lineZ=script:GetAttribute('TrackBoundaryZ')
    local centerX,halfWidth=script:GetAttribute('TrackCenterX'),script:GetAttribute('TrackHalfWidth')
    if not M.Finite(lineZ)or typeof(position)~='Vector3'or not M.Finite(dt)or dt<=0
        or M.ZoneCap(earned,position,lineZ,centerX,halfWidth)~=M.Cap(earned)then return velocity end
    local projected=position+velocity*dt
    local lo,t=trackInterval(position,projected,lineZ,centerX,halfWidth)
    if not lo or t>=1 then return velocity end
    local ratio=M.BaseAreaRatio
    return velocity*(t+(1-t)*ratio)
end
function M.Flat(v)
    if typeof(v)~='Vector3'or not M.Finite(v.X)or not M.Finite(v.Y)or not M.Finite(v.Z)then return Vector3.zero end
    return V(v.X,0,v.Z)
end
-- Compatibility entry point: holding input no longer ramps movement speed.
function M.LaunchCap(cap,_held)return M.Cap(cap)end
function M.Braking(cap,speed,distance)
    cap=M.Cap(cap)
    -- Use the unlocked ceiling so braking does not weaken as we slow down.
    return math.max(M.MinBraking,cap/M.BrakeSeconds,cap*cap/(2*(distance or M.StoppingDistance)))
end
function M.Step(velocity,input,cap,dt,grounded,_held)
    cap=M.Cap(cap);dt=M.Finite(dt)and math.clamp(dt,0,M.MaxStep)or 0
    velocity=M.Flat(velocity);input=M.Flat(input)
    local speed=velocity.Magnitude
    if speed>cap then velocity=velocity*(cap/speed);speed=cap end
    if dt==0 then return velocity end
    local control=grounded and 1 or M.AirControl
    local magnitude=math.min(1,input.Magnitude)
    if magnitude<=M.Deadzone or cap==0 then
        if grounded or speed<.01 then return Vector3.zero end
        local nextSpeed=math.max(0,speed-M.Braking(cap,speed)*control*dt)
        return velocity*(nextSpeed/speed)
    end
    local direction=input.Unit
    -- Full input uses the earned ceiling on its first simulation step.
    -- A partial thumbstick still permits precise positioning; release brakes immediately.
    if not grounded and speed>.01 and velocity.Unit:Dot(direction)>-.95 then
        local blended=velocity.Unit:Lerp(direction,1-math.exp(-dt*control/.05))
        if blended.Magnitude>.001 then direction=blended.Unit end
    end
    return direction*(cap*magnitude*magnitude)

end
function M.Allowance(cap,dt)
    return M.Cap(cap)*math.max(0,M.Finite(dt)and dt or 0)*1.20
end
function M.Burst(cap)return 12+M.Cap(cap)*.20 end
return M
]=]
SOURCES['OddsText85']=[=[-- Display only: reduced fractions with whole-number numerators and denominators.
local F={}
function F.Format(percent)
 if type(percent)~='number'or percent~=percent or percent<=0 or percent==math.huge then return '—'end
 local p=math.min(percent,100)/100;local reciprocal=1/p;local unit=math.floor(reciprocal+.5)
 if unit<=1e15 and math.abs(reciprocal-unit)<=1e-10*math.max(1,unit)then return '1/'..string.format('%.0f',unit)end
 local x=p;local a0,a1,b0,b1=0,1,1,0
 for _=1,32 do
  local a=math.floor(x);local n,d=a*a1+a0,a*b1+b0
  if d>1e9 or n>1e15 then break end
  a0,a1,b0,b1=a1,n,b1,d
  if math.abs(n/d-p)<1e-12 then return string.format('%.0f/%.0f',n,d)end
  local f=x-a;if f<1e-14 then break end;x=1/f
 end
 if b1>0 then return '≈'..string.format('%.0f/%.0f',a1,b1)end
 return '≈1/'..string.format('%.0f',unit)
end
function F.Percent(percent)
 if percent==.5 then return '½%'elseif percent==2.5 then return '2½%'end
 return string.format('%.0f%%',percent)
end
return F
]=]
SOURCES['RarePackRules']=[=[-- R98: joint spawn outcome odds, strictly below 1%; no balance changes.
local P=require(script.Parent.SeedPackRules)
local W=require(script.Parent.WeatherTraits)
local R={Threshold=.01}
function R.TierProbabilities(cycle,count)
 local weights={};for i,key in ipairs(P.VariantOrder)do weights[i]=P.Variants[key].SpawnWeight end
 local values=require(script.Parent.PackSchedule81).Probabilities(cycle or 0,count,weights)
 local result={};for i,key in ipairs(P.VariantOrder)do result[key]=values[i]end;return result
end
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function R.Probability(variant,size,mutation,context)
 if variant=='MechLimited'or variant=='EclipseReliquary'or not table.find(P.VariantOrder,variant)then return nil end
 if not finite(size)or P.MutationKey(mutation)~=mutation then return nil end
 context=type(context)=='table'and context or{}
 local tier=context.TierProbability
 if tier==nil then local total=0;for _,key in ipairs(P.VariantOrder)do total+=P.Variants[key].SpawnWeight end;tier=P.Variants[variant].SpawnWeight/total end
 local sizeChance=0;for _,row in ipairs(P.PackSizes)do if row.Scale==size then sizeChance+=row.Weight/100 end end
 if context.ForcedSize then sizeChance=1 end
 local mutationChance=context.ForcedMutation and 1 or P.PackMutations[mutation].Weight/100
 local weather=context.WeatherProbability or 1
 if not finite(tier)or tier<=0 or tier>1 or not finite(weather)or weather<=0 or weather>1 or sizeChance<=0 then return nil end
 return tier*sizeChance*mutationChance*weather
end
function R.Qualifies(variant,size,mutation,context)
 local odds=R.Probability(variant,size,mutation,context)
 return odds~=nil and odds<R.Threshold
end
function R.Message(stage,variant,size,mutation,context)
 local odds=R.Probability(variant,size,mutation,context)
 if not odds or odds>=R.Threshold then return nil end
 local tier=P.GetPackTier(variant);local words={};local weather=W.Key(context and context.Weather)
 if weather~='None'then table.insert(words,W.Display(weather))end
 if mutation~='None'then table.insert(words,mutation)end
 if size~=1 then table.insert(words,tostring(size)..'x')end
 table.insert(words,tier.Name..' Pack')
 return {Text=table.concat(words,' '),Biome=P.DesignBiomes[stage]or'Biome',Stage=stage,Tier=tier.Name,Size=size,Mutation=mutation,Weather=weather,Probability=odds,Color=tier.Color}
end
return R
]=]
SOURCES['WeatherTraits']=[=[-- R98: weather layers stack independently of the Gold/Diamond material coat.
local B=require(script.Parent.BalanceRules)
local W={Interval=900,Duration=180,PackChance=B.WeatherPackChance,FruitChance=B.WeatherFruitChance,PlantChance=B.WeatherPlantChance,InheritanceChance=B.WeatherInheritance}
W.Order={'Drippy','Frosted','Charged'}
W.Traits={None={Rank=0,Multiplier=1},Drippy={Rank=1,Multiplier=1.5,Color=Color3.fromRGB(90,197,255)},Frosted={Rank=2,Multiplier=2,Color=Color3.fromRGB(202,241,255)},Charged={Rank=3,Multiplier=2.5,Color=Color3.fromRGB(177,144,255)}}
-- Keep indexed metadata compatible with every existing inventory, preview and sale path.
for mask=1,7 do
 local list={};local multiplier,rank,color=1,0,nil
 for index,key in ipairs(W.Order)do if bit32.band(mask,2^(index-1))~=0 then
  local trait=W.Traits[key];list[#list+1]=key;multiplier+=trait.Multiplier-1;rank=trait.Rank;color=trait.Color
 end end
 local key=table.concat(list,'+');if not W.Traits[key]then W.Traits[key]={Rank=rank,Multiplier=multiplier,Color=color}end
end
W.Events={Rain='Drippy',Thunderstorm='Charged',Blizzard='Frosted'}
local function canonical(value)
 if value==nil or value=='None'then return 'None'end
 if type(value)~='string'or #value>24 or value==''then return nil end
 if W.Traits[value]then return value end
 local seen={};for _,key in ipairs(string.split(value,'+'))do
  if not table.find(W.Order,key)or seen[key]then return nil end;seen[key]=true
 end
 local list={};for _,key in ipairs(W.Order)do if seen[key]then list[#list+1]=key end end
 return #list>0 and table.concat(list,'+')or nil
end
function W.Key(value)return canonical(value)or'None'end
function W.Valid(value)return canonical(value)~=nil end
function W.CheckedEvent(value)
 if type(value)~='string'or #value>24 then return nil end
 local raw,trait=value:match('^(-?%d+):(%a+)$');local cycle=tonumber(raw)
 if not cycle or raw=='-0' or cycle%1~=0 or math.abs(cycle)>1000000000 or tostring(cycle)~=raw or not table.find(W.Order,trait)then return nil end
 return value
end
function W.List(value)local key=W.Key(value);return key=='None'and{}or string.split(key,'+')end
function W.Count(value)return #W.List(value)end
function W.Display(value)return table.concat(W.List(value),' + ')end
function W.Has(value,trait)return table.find(W.List(value),trait)~=nil end
function W.Merge(a,b)
 local seen={};for _,key in ipairs(W.List(a))do seen[key]=true end;for _,key in ipairs(W.List(b))do seen[key]=true end
 local list={};for _,key in ipairs(W.Order)do if seen[key]then list[#list+1]=key end end
 return #list>0 and table.concat(list,'+')or'None'
end
function W.Roll(identity,salt)
 local h=104729;local s=tostring(identity)..'/'..tostring(salt)
 for i=1,#s do h=(h*131+s:byte(i))%2147483647 end
 for _=1,4 do h=(h*48271)%2147483647 end
 return h/2147483647
end
function W.Schedule(now)
 local cycle=math.floor(now/W.Interval);local start=cycle*W.Interval;local roll=W.Roll(cycle,'weather-event')
 local kind=roll<.4 and'Rain'or roll<.7 and'Thunderstorm'or'Blizzard'
 return now-start<W.Duration and kind or'Clear',cycle,start+W.Duration,start+W.Interval
end
local catalog
function W.Fruit(crop,index,cycle)
 if crop._DetachedHarvest then return W.Key(crop.Weather)end
 catalog=catalog or require(script.Parent.PlantCatalog)
 local def=catalog[crop.SeedId];local inherit='None';local traits=W.List(crop.Weather)
 if def and def.Mode=='whole'then
  -- The harvested plant is the same object, not a separately inherited fruit.
  inherit=W.Key(crop.Weather)
 else
  -- Preserve the original stable 20% inheritance roll for the parent's weather stack.
  if #traits>0 and W.Roll(crop.Id,'inherit-weather:'..cycle..':'..index)<W.InheritanceChance then inherit=W.Key(crop.Weather)end
 end
 local applied=crop.FruitWeather and crop.FruitWeather[tostring(index)]
 if applied and applied.Cycle==cycle then inherit=W.Merge(inherit,applied.Kind)end
 return inherit
end
function W.ValidCrop(crop,count)
 if not W.Valid(crop.Weather)then return false end
 if crop.FruitWeather==nil then return true end
 if type(crop.FruitWeather)~='table'then return false end
 for key,v in pairs(crop.FruitWeather)do
  local n=type(key)=='string'and tonumber(key)
  if not n or n%1~=0 or n<1 or n>(count or 6)or tostring(n)~=key or type(v)~='table'then return false end
  if not W.Valid(v.Kind)or v.Kind==nil or v.Kind=='None'or type(v.Cycle)~='number'or v.Cycle%1~=0 or v.Cycle<0 or v.Cycle>1000000000 then return false end
  if type(v.Event)~='number'or v.Event%1~=0 or math.abs(v.Event)>1000000000 then return false end
 end
 return true
end
function W.Price(base,mutation,size,weather)
 local multiplier=B.CashMultiplier(size,mutation,W.Traits[W.Key(weather)].Multiplier)
 return math.max(1,math.ceil(base*multiplier)),multiplier
end
return W
]=]
local function stub(name) return setmetatable({Name=name},{__index=function(t,k) return function() return stub(k) end end}) end
local C3={};C3.__index=C3
function C3:Lerp(o,a) return self end
Color3={fromRGB=function(r,g,b) return setmetatable({R=r,G=g,B=b},C3) end,new=function(r,g,b) return setmetatable({R=r,G=g,B=b},C3) end}
Enum=setmetatable({},{__index=function(t,k) return setmetatable({},{__index=function(_,m) return m end}) end})
Vector3={new=function(x,y,z) return {X=x,Y=y,Z=z} end,zero={X=0,Y=0,Z=0}}
typeof=type
local RS; local cache={}; local proxies={}
local function proxy(name)
 if proxies[name] then return proxies[name] end
 local p={Name=name,__module=true,Parent=nil,GetAttribute=function() return nil end,SetAttribute=function() end}
 proxies[name]=p; return p
end
RS=setmetatable({WaitForChild=function(self,n) return self[n] end,FindFirstChild=function(self,n) return SOURCES[n] and self[n] or nil end},
 {__index=function(t,k) local p=proxy(k); p.Parent=t; return p end})
local STUBS={GardenTheme={Rarities={},Rarity=function() return {} end}}
local realRequire=require
function require(p)
 if type(p)~='table' or not p.__module then return realRequire(p) end
 local n=p.Name
 if cache[n]~=nil then return cache[n] end
 if STUBS[n] then cache[n]=STUBS[n]; return STUBS[n] end
 local src=SOURCES[n]; assert(src,'no source for '..n)
 local f,err=loadstring(src,n); assert(f,err)
 local env=setmetatable({script=p},{__index=getfenv(1)})
 setfenv(f,env)
 local r=f(); cache[n]=r; return r
end
game={GetService=function(self,s) if s=='ReplicatedStorage' then return RS end
 if s=='RunService' then return {IsStudio=function() return false end,IsRunning=function() return false end} end
 return stub(s) end}
RS_MOD=function(n) return require(RS[n]) end

-- Dumps the LIVE odds by running the real SeedPackRules/PackOdds81/BalanceValues81 code.
local Rules=RS_MOD('SeedPackRules')
local T=RS_MOD('BalanceValues81')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
function config.GetSeedById(id) for _,c in ipairs(config.SeedCatalogByStage) do for _,s in ipairs(c) do if s.Id==id then return s end end end end
local order={1,6,2,3,4,5,7}
print('#POOL\tstage\tseedId\tname\trarity')
for _,st in ipairs(order) do
 for _,s in ipairs(Rules.ObtainablePool(config,st)) do print('POOL',st,s.Id,s.Name,(Rules.GetRarity(s.Id))) end
end
print('#SPAWN',table.concat(T.SpawnWeights,','))
print('#BOOT',table.concat(T.BootLuck,','),'costs',table.concat(T.BootCosts,','))
local lucks={1,1.15,1.3,1.5,1.75,2,3.5}
print('#ODDS\tstage\tpack\tluck\tseedId\trarity\tpercent')
for _,st in ipairs(order) do for _,pk in ipairs(Rules.VariantOrder) do for _,L in ipairs(lucks) do
 local odds=Rules.SeedOdds(config,st,pk,L,81)
 for _,s in ipairs(Rules.ObtainablePool(config,st)) do print('ODDS',st,pk,L,s.Id,(Rules.GetRarity(s.Id)),string.format('%.10g',odds[s.Id] or 0)) end
end end end
-- void pack
local v=Rules.SeedOdds(config,7,'EclipseReliquary',1,81)
for id,p in pairs(v) do print('VOID',id,(Rules.GetRarity(id)),string.format('%.10g',p)) end
-- speed curve
local P=RS_MOD('Progression81')
for _,pts in ipairs({0,800,3000,10000,50000,300000,2000000,20000000,500000000,20000000000,100000000000,1000000000000,1e15}) do print('SPEED',string.format('%.0f',pts),string.format('%.3f',P.Speed(string.format('%.0f',pts)))) end
print('#MACHINE',table.concat(T.MachineMultipliers,','),'costs',table.concat(T.MachineCosts,','))
local tc={};for _,k in ipairs({'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'}) do table.insert(tc,k..'='..T.TrailMultipliers[k]..'@'..T.TrailCosts[k]) end
print('#TRAIL',table.concat(tc,' '))
for _,st in ipairs(order) do print('KEEPER',st,table.concat(T.KeeperSpeeds[st],',')) end
print('#FENCE',table.concat(T.FenceCosts,','))
local B=RS_MOD('BalanceRules')
print('#RARITYWEIGHTS(legacy)',B.RarityWeights.Common,B.RarityWeights.King)
