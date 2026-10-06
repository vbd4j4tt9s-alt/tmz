-- R153 (owner: "make it fixed visibly so when players pull a cosmic seed from a void pack they are still reminded of how rare it is"): ONE rarity per seed, shown everywhere a
-- SEED is labelled (the Index, the reveal card's "1 in N", the chat lines, the hub plaque). Display only: nothing here rolls, saves or decides (the announcements still go by
-- rarity tier, never by this text).
--  * Canonical(seedId) = N of the seed's "1/N" in its HOME pack: the plain Common pack (Pack01) of the biome the seed is found in, at the current odds version, luck 1, no
--    boots / friend or starter boost, no pity, no size. The Verity seed: the Verity pack (1/100). The Mech seeds: the Limited Mech pack (their own Chance).
--  * Read from the existing odds code (SeedPackRules.SeedOdds) over the catalog the server's Config is built from (SeedPackRules.BuildSeedCatalog): no copied numbers, and
--    the client and the server get the same answer. Cached. A retired seed (nobody can pull it) has none (nil / '—').
--  * Text goes through OddsText85 like every chance (whole numbers under a million, 1/1.67B above).
-- A PACK's own tooltip (the held pack's rows) and the shop's Mech drop table keep that pack's real odds: they answer "what can THIS pack give".
local Rules=require(script.Parent.SeedPackRules)
local Verity=require(script.Parent.VerityCatalog)
local Odds=require(script.Parent.OddsText85)
local M={Version='R153',HomeVariant='Pack01'}
local config,cache=nil,{}
local function cfg()
 if config then return config end
 local catalog=Rules.BuildSeedCatalog();local byId={}
 for _,list in ipairs(catalog)do for _,seed in ipairs(list)do byId[seed.Id]=seed end end
 config={SeedCatalogByStage=catalog,GetSeedById=function(id)return byId[id]end}
 return config
end
local function idOf(seed)
 if type(seed)=='table'then seed=seed.Id or seed.id or seed.SeedId end
 return type(seed)=='string'and seed or nil
end
-- The seed's home pack: stage, variant (nil for a seed nobody can pull).
function M.Home(seed)
 local id=idOf(seed);local spec=id and Rules.SeedDesignById[id]
 if not spec or Rules.IsRetired(id)then return nil end
 if Verity.Is(id)then return Verity.PackStage,Verity.Variant end
 if spec.stage==8 then return 8,'MechLimited' end
 return spec.stage,M.HomeVariant
end
-- Percent (0 < p <= 100) of the seed in its home pack, or nil.
function M.Percent(seed)
 local id=idOf(seed);if not id then return nil end
 local hit=cache[id];if hit~=nil then return hit or nil end
 local p;local stage,variant=M.Home(id)
 if stage then
  local ok,odds=pcall(Rules.SeedOdds,cfg(),stage,variant,1,Rules.OddsVersion)
  local v=ok and type(odds)=='table'and odds[id]
  if type(v)=='number'and v==v and v>0 then p=math.min(v,100)end
 end
 cache[id]=p or false
 return p
end
-- N of "1/N" (not rounded: Count / Format round it for display), or nil.
function M.Canonical(seed)local p=M.Percent(seed);return p and 1/(p/100)or nil end
-- "1/N" exactly as the game prints a chance ('—' when the seed has none).
function M.Text(seed)return Odds.Format(M.Percent(seed))end
-- Just the N part as printed ("12K"), for "1 in N" and "(1/N)" texts; nil when the seed has none.
function M.Count(seed)local n=M.Canonical(seed);return n and Odds.Count(n)or nil end
-- Every pullable seed, in SeedPackRules.SeedDesigns order: {Id, Name, Rarity, Stage, Variant, Percent, N, Text}.
function M.All()
 local out={}
 for _,spec in ipairs(Rules.SeedDesigns)do
  local stage,variant=M.Home(spec.id)
  if stage then out[#out+1]={Id=spec.id,Name=spec.name,Rarity=Rules.GetRarity(spec.id),Stage=stage,Variant=variant,Percent=M.Percent(spec.id),N=M.Canonical(spec.id),Text=M.Text(spec.id)}end
 end
 return out
end
return M
