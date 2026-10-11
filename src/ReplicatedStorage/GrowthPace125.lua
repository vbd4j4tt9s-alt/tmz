-- R125 (owner): plants above Uncommon grow much slower, up to 4 hours for King; beginner (every Forest seed),
-- Common and Uncommon plants keep their times. Paid Mech plants are left as bought.
-- Within each rarity the seeds keep their order: the fastest maps to the band's low end, the slowest to its top.
-- Regrowing fruit slows by the same factor. Fruit is worth more by half that factor (never less than before), so a
-- slowed plant keeps about half of its old income per hour (owner choice "half-way").
-- Applied once to the shared PlantCatalog (= Config.GardenPlants). Crops already planted keep their own timers.
local G={Version=125,Round=10}
-- A harvest record must stay <= 9e12 (PlayerDataService) after the x100 cash-multiplier cap (BalanceRules), so a base
-- fruit value never goes above 9e10 (only the top King plant reaches it).
G.MaxValue=9e10
G.Bands={Rare={900,1800},Epic={1800,2700},Legendary={2700,3600},Mythic={3600,5400},Secret={7200,9000},Cosmic={9000,10800},King={10800,14400}}
function G.Exempt(def)
 -- R147: the Verity plant (VerityCatalog) is final as written: 4 h, regrow 1500 s, 9e10 (the per-fruit cap).
 -- (R148: the plants of the roster change are final as written too, but not through this test: PlantCatalog applies Roster149 AFTER this
 -- pacing, which overwrites Fire Pepper's and Moon Melon's paced numbers and adds Aloe and Sand Fruit unpaced. That ordering is the safeguard.)
 return def.Stage==1 or def.Mech==true or def.Verity==true or G.Bands[def.Rarity]==nil
end
local function round(v,unit)return math.floor(v/unit+.5)*unit end
local applied=setmetatable({},{__mode='k'}) -- catalogs already paced (no marker key inside the catalog)
function G.Apply(catalog)
 if applied[catalog]then return catalog end;applied[catalog]=true
 local groups={}
 for id,def in pairs(catalog)do
  if type(def)=='table'and type(def.Seconds)=='number'and not G.Exempt(def)then
   local g=groups[def.Rarity];if not g then g={Min=math.huge,Max=-math.huge,List={}};groups[def.Rarity]=g end
   g.Min=math.min(g.Min,def.Seconds);g.Max=math.max(g.Max,def.Seconds);table.insert(g.List,def)
  end
 end
 for rarity,g in pairs(groups)do
  local lo,hi=G.Bands[rarity][1],G.Bands[rarity][2]
  for _,def in ipairs(g.List)do
   local t=g.Max>g.Min and(def.Seconds-g.Min)/(g.Max-g.Min)or 1
   local seconds=round(lo+(hi-lo)*t,G.Round)
   local factor=seconds/def.Seconds
   def.BaseSeconds=def.Seconds;def.Seconds=seconds;def.GrowthFactor=factor
   if type(def.RegrowSeconds)=='number'then def.RegrowSeconds=round(def.RegrowSeconds*factor,G.Round)end
   if type(def.Value)=='number'then def.Value=math.max(def.Value,math.min(G.MaxValue,math.floor(def.Value*math.max(1,factor/2)+.5)))end
  end
 end
 return catalog
end
return G
