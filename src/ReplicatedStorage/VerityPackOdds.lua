-- R147 (owner): odds of the Verity pack (BagVariant 'VerityReliquary', Stage 7), the pack Verity hands back for a Void pack.
-- The Void pack's odds with every King removed, plus the Verity seed at 1%; the rest keeps the Void shape:
--   1%        the Verity seed (rarity King, Index category 9)
--   else 0.5% a Mech roll over the Mech seeds that are left (no Crowncore Tree), chances renormalised
--   else      Cosmic 1/20, Secret the rest (PackOdds137.VoidTierOdds without a King), a uniform seed of that tier.
-- Luck never changes this pack. Version independent: SeedPackRules calls this from its outermost wrapper (Void packs carry
-- OddsVersion 137 but roll the 112 path, so a version switch could not catch the Verity pack).
-- Expected %: Verity 1; each of the 5 Secret .99*.995*.95/5 = 18.71595; each of the 5 Cosmic .99*.995*.05/5 = .98505;
-- Mech .99*.005*Chance/99.5 (Plasma Pepper .238794, Holo Melon .129347, Prism Lotus .079598, Holo Apple Tree .034824,
-- Nebula Vine .012437). They add up to 100.
local Verity=require(script.Parent.VerityCatalog)
local Mech=require(script.Parent.MechCatalog)
local Void=require(script.Parent.VoidPackOdds85)
local O=require(script.Parent.PackOdds137)
local P={}
local cache=setmetatable({},{__mode='k'})
local function group(pool,rules)
 local byTier,present={},{}
 for _,seed in ipairs(pool)do
  local tier=rules.GetRarity(seed.Id);present[tier]=true
  byTier[tier]=byTier[tier]or{};table.insert(byTier[tier],seed)
 end
 return byTier,present
end
-- The Mech seeds this pack can give: no King (the Crowncore Tree). Chance is the Mech branch's own chance (percent of 100).
local function mechList(config)
 local list,total={},0
 for _,s in ipairs(Mech.Seeds)do
  local seed=config.GetSeedById(s.Id)
  if seed and s.Rarity~='King'then table.insert(list,{Seed=seed,Rarity=s.Rarity,Chance=s.Chance});total+=s.Chance end
 end
 return list,total
end
local function build(config,rules)
 local hit=cache[config];if hit then return hit end
 local direct={}
 for _,seed in ipairs((Void.Pools(config,rules)))do
  if rules.GetRarity(seed.Id)~='King'and not Verity.Is(seed.Id)then table.insert(direct,seed)end
 end
 local mech,mechTotal=mechList(config)
 local verity=config.GetSeedById(Verity.Id)
 local all={}
 if verity then table.insert(all,verity)end
 for _,seed in ipairs(direct)do table.insert(all,seed)end
 for _,m in ipairs(mech)do table.insert(all,m.Seed)end
 local byTier,present=group(direct,rules)
 hit={Verity=verity,Direct=direct,All=all,Mech=mech,MechTotal=mechTotal,ByTier=byTier,Tiers=O.VoidTierOdds(present)}
 cache[config]=hit;return hit
end
-- direct: the Void pack's direct seeds without the Kings; all: Verity seed, direct seeds, Mech seeds (the hold tooltip's order).
function P.Pools(config,rules)
 local hit=build(config,rules);return hit.Direct,hit.All
end
-- {seedId = percent}, adding up to 100.
function P.Odds(config,rules)
 local hit=build(config,rules);local out={}
 if not hit.Verity then return out end
 local rest=100*(1-Verity.VerityChance)
 out[Verity.Id]=100*Verity.VerityChance
 local direct=rest*(1-O.Void.MechChance)
 for tier,p in pairs(hit.Tiers)do
  local seeds=hit.ByTier[tier]or{};for _,seed in ipairs(seeds)do out[seed.Id]=(out[seed.Id]or 0)+direct*p/#seeds end
 end
 if hit.MechTotal>0 then
  for _,m in ipairs(hit.Mech)do out[m.Seed.Id]=(out[m.Seed.Id]or 0)+rest*O.Void.MechChance*m.Chance/hit.MechTotal end
 end
 return out
end
local function unit(draw)
 local u=draw();return type(u)=='number'and u==u and math.clamp(u,0,1-1e-12)or 0
end
-- draw: function returning a uniform number in [0,1) (a single number cannot roll 1 in 100 / 1 in 200 exactly). Returns seed, rarity.
function P.Roll(config,rules,draw)
 if type(draw)~='function'then return nil end
 local hit=build(config,rules);if not hit.Verity then return nil end
 if O.Chance(Verity.VerityChance,draw)then return hit.Verity,Verity.Rarity end
 if hit.MechTotal>0 and O.Chance(O.Void.MechChance,draw)then
  local ticket=unit(draw)*hit.MechTotal
  for _,m in ipairs(hit.Mech)do
   if ticket<m.Chance then return m.Seed,m.Rarity end;ticket-=m.Chance
  end
  local last=hit.Mech[#hit.Mech];return last.Seed,last.Rarity
 end
 local tier=O.RollTier(hit.Tiers,draw);local seeds=tier and hit.ByTier[tier]
 if not seeds or #seeds==0 then return nil end
 local index=math.clamp(math.floor(unit(draw)*#seeds)+1,1,#seeds)
 return seeds[index],tier
end
return P
