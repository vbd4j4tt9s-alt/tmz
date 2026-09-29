local Rules=RS_MOD('SeedPackRules')
local T=RS_MOD('BalanceValues81')
local Cat=RS_MOD('PlantCatalog')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local order={1,6,2,3,4,5,7}
print('#PLANT\tstage\tseedId\trarity\tValue\tFruitCount\tSeconds\tRegrowSeconds\tRegrows\tIndexFirst\tIndexRepeat')
for _,st in ipairs(order) do for _,s in ipairs(Rules.ObtainablePool(config,st)) do
 local d=Cat[s.Id]
 print('PLANT',st,s.Id,(Rules.GetRarity(s.Id)),string.format('%.0f',d.Value),d.FruitCount,d.Seconds,d.RegrowSeconds,tostring(d.Regrows~=false),string.format('%.0f',T.IndexFirst[s.Id] or -1),string.format('%.0f',T.IndexRepeat[s.Id] or -1))
end end
