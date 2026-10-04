-- All regular obtainable Secret/Cosmic/King seeds, plus a nested normal Mech roll.
-- A single server random ticket selects both branches without rerolling rewards.
-- R147: the Verity seed (also a King) is never in the Void pack; the Verity pack gives it (VerityPackOdds).
local Mech=require(script.Parent.MechCatalog)
local Verity=require(script.Parent.VerityCatalog)
local V={MechChance=.005,DirectChance=.995}
local cache=setmetatable({},{__mode='k'})
function V.Pools(config,rules)
 local hit=cache[config];if hit then return hit.Direct,hit.All end
 local direct,all,seen={},{},{}
 for _,spec in ipairs(rules.SeedDesigns)do
  local seed=config.GetSeedById(spec.id);local rarity=rules.GetRarity(spec.id)
  if seed and not Mech.Is(spec.id)and not Verity.Is(spec.id)and not rules.IsRetired(spec.id)and(rarity=='Secret'or rarity=='Cosmic'or rarity=='King')and not seen[seed.Id]then
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
