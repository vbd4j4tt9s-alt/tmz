-- Pure odds allocation. Missing rarity moves upward before luck is applied.
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
