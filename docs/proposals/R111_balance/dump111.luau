-- Dumps odds from the REAL SeedPackRules + PackOdds111 + PackOdds81 (edited src) for the Python cross-check (xcheck111.py).
local Rules=RS_MOD('SeedPackRules')
local T=RS_MOD('BalanceValues81')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
function config.GetSeedById(id) for _,c in ipairs(config.SeedCatalogByStage) do for _,s in ipairs(c) do if s.Id==id then return s end end end end
assert(Rules.OddsVersion==111,'OddsVersion')
print('#MAXLUCK',T.MaxLuck,'#BOOT',table.concat(T.BootLuck,','))
local order={1,6,2,3,4,5,7}
local lucks={1,1.5,2,5,10,50,300,2000,10000,100000,1000000,5000000,1e7}
for _,st in ipairs(order) do for _,pk in ipairs(Rules.VariantOrder) do for _,L in ipairs(lucks) do
 for _,ver in ipairs({111,81}) do
  local odds=Rules.SeedOdds(config,st,pk,L,ver)
  local total=0
  for _,s in ipairs(Rules.ObtainablePool(config,st)) do
   total+=odds[s.Id] or 0
   print('ODDS',ver,st,pk,string.format('%.17g',L),s.Id,(Rules.GetRarity(s.Id)),string.format('%.17g',odds[s.Id] or 0))
  end
  assert(math.abs(total-100)<1e-9,'sum '..total)
 end
end end end
-- nil version (index BaseChance) == current version
for _,st in ipairs(order) do
 local a,b=Rules.SeedOdds(config,st,'Pack01',1),Rules.SeedOdds(config,st,'Pack01',1,111)
 for id,v in pairs(b) do assert(a[id]==v,'nil version differs') end
end
for _,ver in ipairs({111,81}) do
 local v=Rules.SeedOdds(config,7,'EclipseReliquary',1,ver);local total=0
 for id,p in pairs(v) do total+=p;print('VOID',ver,id,(Rules.GetRarity(id)),string.format('%.17g',p)) end
 print('VOIDTOTAL',ver,string.format('%.17g',total))
end
