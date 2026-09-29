-- R90: approachable first purchases, long-term trillion-cost goals, restrained fruit income.
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
