-- R154: two owner answers, pure rules (SeedPackRules' outermost wrapper calls them; nothing here saves or yields).
-- 1. "the 2x luck is universal": the Void, Verity and Limited Mech packs had fixed odds (no luck at all). They now take the 4 Leaf Clover's x2 and ONLY that
--    (passLuck: the luck passes a player owns; boots never change these packs), the way a biome pack takes luck: each tier above the pack's lowest gets its
--    chance x luck^Power (PackOdds137.Power: Mythic ^.16, Secret ^.28, Cosmic ^.40, King ^1 ...), the lowest tier gives it up (keeping at least 40% of its own
--    share, never reached at x2). No Cap: these packs only ever see x1 or x2. A pack's branches keep their size: the Void pack's 1/200 Mech roll is a Mech
--    pack roll (with the same luck), the Verity seed is the Verity pack's King (1/100 -> 1/50).
-- 2. "the elderbloom only pack is not supposed to be intentional": the 80% rule (Shape), the last step of every roll of a live pack. When one seed would
--    take more than 80% of a pack's rolls: 1% goes to an UPGRADE (the seeds of the next tier above that seed in the pack, split evenly; when nothing is rarer,
--    the pack's rarest seeds) and comes off the top seed; the top seed keeps at most 80%; whatever is left goes to the other seeds in proportion to their own
--    share (so they hold at least 19% between them, plus the 1%). A pack at 80% or less is returned untouched (the same table).
-- Tables are {seedId = chance} on any scale (SeedPackRules uses percent); rarityOf(seedId) -> rarity name.
local O=require(script.Parent.PackOdds137)
local Void=require(script.Parent.PackOdds112)
local VoidPools=require(script.Parent.VoidPackOdds85)
local Mech=require(script.Parent.MechCatalog)
local Verity=require(script.Parent.VerityCatalog)
local T=require(script.Parent.BalanceValues81)
local L={Version=154,Limit=.8,Upgrade=.01,Slack=1e-9} -- Slack: a seed at exactly 80% (a starter-boosted Snow Rare pack: 1/2.5 x2) is not over it, whatever the rounding
local function rank(rarityOf,id)return O.Rank[(rarityOf(id))]or 0 end
local function positive(p)return type(p)=='number'and p==p and p>0 and p<math.huge end
-- The luck passes' luck: a number from 1 to the passes' ceiling (x2 with the clover); anything else is 1.
function L.PassLuck(value)
 if not positive(value)then return 1 end
 return math.clamp(value,1,T.PassLuckCeiling or 2)
end
-- The 80% rule. Returns the table to roll and true, or the SAME table and false when no seed is over Limit (or the pack has fewer than 2 seeds).
function L.Shape(odds,rarityOf)
 if type(odds)~='table'then return odds,false end
 local total,count,top,topP=0,0,nil,0
 for id,p in pairs(odds)do
  if positive(p)then
   total+=p;count+=1
   if p>topP or(p==topP and top~=nil and id<top)then top,topP=id,p end
  end
 end
 if count<2 or not(total>0)or topP/total<=L.Limit+L.Slack then return odds,false end
 local topRank=rank(rarityOf,top);local nextRank,rarest=math.huge,-1
 for id,p in pairs(odds)do if positive(p)then
  local r=rank(rarityOf,id)
  if r>topRank and r<nextRank then nextRank=r end
  if r>rarest then rarest=r end
 end end
 local target=nextRank<math.huge and nextRank or rarest
 local ups={};for id,p in pairs(odds)do if positive(p)and rank(rarityOf,id)==target then ups[#ups+1]=id end end
 table.sort(ups)
 local share=topP/total;local out={}
 for id,p in pairs(odds)do out[id]=positive(p)and p/total or p end
 for _,id in ipairs(ups)do out[id]+=L.Upgrade/#ups end
 out[top]-=L.Upgrade
 local excess=out[top]-L.Limit
 if excess>0 then
  out[top]=L.Limit
  for id,p in pairs(odds)do if id~=top and positive(p)then out[id]+=excess*(p/total)/(1-share)end end
 end
 for id,v in pairs(out)do if positive(odds[id])then out[id]=v*total end end
 return out,true,{Top=top,Upgrade=ups}
end
-- A table's tiers shifted by luck the biome-pack way (see 1. above). Returns a new table on the same scale.
function L.Shift(odds,rarityOf,luck)
 luck=positive(luck)and math.max(luck,1)or 1
 local sum,low={},nil
 for id,p in pairs(odds)do if positive(p)then
  local tier=(rarityOf(id));sum[tier]=(sum[tier]or 0)+p
  if not low or(O.Rank[tier]or 0)<(O.Rank[low]or 0)then low=tier end
 end end
 local out={};if not low then for id,p in pairs(odds)do out[id]=p end;return out end
 local total,above,raised=0,0,0;local scale={}
 for tier,v in pairs(sum)do
  total+=v
  if tier~=low then scale[tier]=luck^(O.Power[tier]or 0);above+=v;raised+=v*scale[tier]end
 end
 local keep=O.FloorKeep*sum[low]
 if total-raised<keep and raised>above then -- (never at x2) the gains shrink so the lowest tier keeps 40% of its share
  local k=(total-keep-above)/(raised-above)
  for tier in pairs(scale)do scale[tier]=1+(scale[tier]-1)*k end
  raised=total-keep
 end
 scale[low]=(total-raised)/sum[low]
 for id,p in pairs(odds)do out[id]=positive(p)and p*scale[(rarityOf(id))]or p end
 return out
end
-- Mech seeds {id = Chance} (percent of the Mech roll), every one of them or none of the King.
local function mechTable(config,noKing)
 local out={}
 for _,s in ipairs(Mech.Seeds)do if config.GetSeedById(s.Id)and not(noKing and s.Rarity=='King')then out[s.Id]=s.Chance end end
 return out
end
local function scaled(into,odds,factor)for id,p in pairs(odds)do into[id]=(into[id]or 0)+p*factor end end
local function normal(odds)local t=0;for _,p in pairs(odds)do t+=p end;local out={};if t>0 then for id,p in pairs(odds)do out[id]=p/t end end;return out end
-- The direct (non-Mech) Secret / Cosmic / King part of a Void-shaped pack as {id = fraction}: the Void pack's tiers, a uniform seed in a tier.
local function voidDirect(seeds,rules,tiers)
 local byTier={}
 for _,seed in ipairs(seeds)do local t=rules.GetRarity(seed.Id);byTier[t]=byTier[t]or{};table.insert(byTier[t],seed.Id)end
 local present={};for t in pairs(byTier)do present[t]=true end
 local out={}
 for tier,p in pairs(tiers(present))do local ids=byTier[tier]or{};for _,id in ipairs(ids)do out[id]=p/#ids end end
 return out
end
-- {seedId = percent} of a fixed-odds pack at this pass luck: kind = 'Mech' (the Limited Mech pack), 'Void' (the current Void pack), 'Verity'.
-- At luck 1 these are the packs' own tables (SeedPackRules, VoidPackOdds85, VerityPackOdds), which the R154 tests check.
function L.FixedOdds(kind,config,rules,luck)
 luck=L.PassLuck(luck)
 local out={}
 if kind=='Mech'then
  scaled(out,L.Shift(mechTable(config,false),rules.GetRarity,luck),1)
 elseif kind=='Void'then
  local direct=VoidPools.Pools(config,rules)
  scaled(out,L.Shift(voidDirect(direct,rules,Void.VoidTierOdds),rules.GetRarity,luck),100*(1-Void.Void.MechChance))
  scaled(out,L.Shift(mechTable(config,false),rules.GetRarity,luck),Void.Void.MechChance)
 elseif kind=='Verity'then
  local verity=config.GetSeedById(Verity.Id);if not verity then return out end
  local chance=math.min(Verity.VerityChance*luck^O.Power.King,1)
  local rest=100*(1-chance);out[Verity.Id]=100*chance
  local direct={}
  for _,seed in ipairs((VoidPools.Pools(config,rules)))do if rules.GetRarity(seed.Id)~='King'and not Verity.Is(seed.Id)then table.insert(direct,seed)end end
  scaled(out,L.Shift(voidDirect(direct,rules,O.VoidTierOdds),rules.GetRarity,luck),rest*(1-O.Void.MechChance))
  scaled(out,L.Shift(normal(mechTable(config,true)),rules.GetRarity,luck),rest*O.Void.MechChance)
 end
 return out
end
-- An exact roll of a {seedId = chance} table (any scale): rarest seed first, each tested with its chance given that no rarer one hit (PackOdds137.Chance:
-- exact even at 1 in a trillion). draw: uniform [0,1). Returns seed, rarity.
function L.Roll(config,odds,rarityOf,draw)
 if type(draw)~='function'or type(odds)~='table'then return nil end
 local rows,total={},0
 for id,p in pairs(odds)do if positive(p)then rows[#rows+1]={Id=id,P=p,Rank=rank(rarityOf,id)};total+=p end end
 if #rows==0 then return nil end
 table.sort(rows,function(a,b)
  if a.Rank~=b.Rank then return a.Rank>b.Rank end
  if a.P~=b.P then return a.P<b.P end
  return a.Id<b.Id
 end)
 local remaining,pick=1,rows[#rows]
 for i,row in ipairs(rows)do
  local p=row.P/total
  if i==#rows or remaining<=p or O.Chance(p/remaining,draw)then pick=row;break end
  remaining-=p
 end
 local seed=config.GetSeedById(pick.Id)
 if not seed then return nil end
 local rarity=rarityOf(pick.Id)
 return seed,rarity
end
return L
