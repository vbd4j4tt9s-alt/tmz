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
