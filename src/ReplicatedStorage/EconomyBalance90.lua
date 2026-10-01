-- R90: approachable first purchases, long-term trillion-cost goals, restrained fruit income.
-- Prices are server-owned. This module contains no profile migration or paid-product changes.
local E={Version=90,MaxCash=900000000000000,MaxBaseFruitValue=100000000000}
local Scale=require(script.Parent.EconomyScaling91)
E.Version=91
E.MachineCosts=Scale.Curve(250000,60000000000000,6,true)
local trails=Scale.Curve(200000,75000000000000,6,false)
E.TrailCosts={};for i,id in ipairs({'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'})do E.TrailCosts[id]=trails[i]end
E.BootCosts=Scale.Curve(750000,40000000000000,5,false)
E.FenceCosts=Scale.Curve(500000,30000000000000,6,true)
-- R116: value order. Every plant's income comes from one rule: income per second = biome base x tier multiplier.
-- Regrowing plants: value per fruit = income x RegrowSeconds / FruitCount. Single-harvest plants: 10 minutes of income.
-- Tier: Common 1, Uncommon 1.6, Rare 2.5, Legendary 4, Mythic 7, Secret 20, Cosmic 60, King 500 (Mech: Cosmic 40, King 100).
-- So a higher tier always earns more than a lower tier, and a later biome more than the same tier in an earlier one.
-- Biome bases keep an average pack worth what it was before (shop prices unchanged). Dune Lotus is valued as a Rare:
-- Desert has no Rare/Legendary seed, so it is Desert's everyday pull. Base per biome (cash/s): Forest 3568, Jungle 6846, Desert 34760, Snow 60274, Lava 137578, Crystal 272073, Storm 651280.
E.FruitValues={
 -- Forest
 SunflowerSeed=58900,BluebellSeed=71400,AppleSeed=183000,MooncapSeed=419000,SunflowerBloomSeed=8560000,ElderbloomSeed=310000,
 -- Jungle
 CocoaSeed=123000,PineappleSeed=953000,VenomVineSeed=1760000,LanternFernSeed=441000,TigerOrchidSeed=1090000,AncientWorldrootSeed=1070000,
 -- Desert
 CactusSeed=1520000,DatePalmSeed=52100000,StarfruitSeed=367000000,MirageFigSeed=96400000,SolarStarfruitSeed=886000000,
 -- Snow
 SnowdropSeed=6360000,IceberrySeed=6220000,WinterPineSeed=145000000,CrystalLilySeed=83500000,SilentFrostbellSeed=125000000,PolarStarbloomSeed=1240000000,WinterCrownwoodSeed=1890000000,
 -- Lava
 FirePepperSeed=17000000,EmberBloomSeed=39700000,AshRoseSeed=22700000,LavaLotusSeed=330000000,ObsidianMawSeed=1080000000,SupernovaBloomSeed=3580000000,EmberEmperorSeed=5450000000,
 -- Crystal
 AmethystSeed=56100000,PrismOrchidSeed=67300000,MoonflowerSeed=157000000,DiamondVineSeed=314000000,HollowGeodeSeed=2580000000,OrbitLotusSeed=8540000000,PrismMonarchSeed=13000000000,
 -- Storm
 SparkReedSeed=206000000,ThunderTulipSeed=206000000,VoltOrchidSeed=380000000,TempestLotusSeed=2260000000,BlackoutBloomSeed=7220000000,StormSovereignSeed=4360000000,PulsarStarfruitSeed=39900000000,
 -- Mech
 PlasmaPepperSeed=130000000,HoloMelonSeed=1090000000,PrismLotusSeed=1370000000,HoloAppleTreeSeed=1370000000,NebulaVineSeed=5210000000,CrowncoreTreeSeed=29300000000,
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
