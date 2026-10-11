-- R112: odds for OddsVersion 112 packs. Keep this table frozen once shipped; banked packs keep the version they spawned with.
-- Each tier above a pack's lowest tier has a 1 in N chance. Boots multiply it by luck^Power (full on King, partial below),
-- never above Cap unless the pack's own chance is higher. The lowest tier gets the rest and keeps at least 40% of its
-- no-boot share: Legendary, Mythic, then Secret give chance back first (each keeps half), Cosmic and King are never touched.
-- Missing tiers: Common..Mythic pass their share up to the next tier that exists (never into Secret+); Secret+ are not rolled.
local T=require(script.Parent.BalanceValues81)
local Pity=require(script.Parent.PackPity155) -- R155: the pack pity's lucky roll (its clamps take x1.5 more, for that roll only)
local O={Version=112,Gate=1e-5}
O.Order={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
O.Rank={};for i,t in ipairs(O.Order)do O.Rank[t]=i end
O.PackFloor={Pack01='Common',Pack02='Common',Pack03='Uncommon',Pack04='Rare',Pack05='Rare',Pack06='Legendary'}
-- Common pack: Secret 1/10K, Cosmic 1/1M, King 1/1T. Better packs divide these by their built-in luck.
O.TopOneIn={Secret=1e4,Cosmic=1e6,King=1e12}
O.PackTopLuck={Pack01=1,Pack02=2.5,Pack03=6,Pack04=20,Pack05=60,Pack06=200}
O.MidOneIn={
 Pack01={Uncommon=4,Rare=8,Legendary=30,Mythic=200},
 Pack02={Uncommon=3,Rare=5,Legendary=15,Mythic=80},
 Pack03={Rare=2.5,Legendary=7,Mythic=30},
 Pack04={Legendary=3,Mythic=10},
 Pack05={Legendary=2.5,Mythic=4},
 Pack06={Mythic=2.5},
}
O.Power={Uncommon=0,Rare=0,Legendary=.08,Mythic=.16,Secret=.28,Cosmic=.40,King=1}
O.Cap={Uncommon=1,Rare=1,Legendary=.5,Mythic=.45,Secret=.25,Cosmic=.05,King=.01}
-- R112b: a fixed Rare share gives way first, so at x50M luck a better pack never gives less Legendary+.
O.Giveback={'Rare','Legendary','Mythic','Secret'}
O.FloorKeep,O.GivebackKeep=.4,.5
-- Void (event) pack: luck-free, 1/200 Mech branch, then King 1/200M and Cosmic 1/20; Secret is the rest.
O.Void={MechChance=.005,OneIn={King=2e8,Cosmic=20}}
-- Packs banked before R112 keep the old boots' luck (x1.15..x2), matched by the best boot the new luck reaches.
O.LegacyBootLuck={1.15,1.3,1.5,1.75,2}
local function legacyLuck(luck)
 local old=1
 if type(luck)=='number'and luck==luck then
  for i,value in ipairs(T.BootLuck)do if luck>=value then old=O.LegacyBootLuck[i]or old end end
 end
 return old
end
-- R155: a lucky roll (PackPity155) maps its luck before the x1.5 and gives the old multiplier the x1.5 once (x1 -> x1.5 ... x2 -> x3); any other roll as before.
function O.LegacyLuck(luck)return Pity.Legacy(legacyLuck,luck)end
-- R154 (owner: "the 2x luck is universal"): the clamp is LuckCeiling (the boots' cap x the luck passes: a 4 Leaf Clover owner's x2 also applies at
-- Thunder Boots' x25M: R155 halved every boot, so that is x50M with the clover). The server caps each player at MaxLuck x their own passes, so luck without a pass is exactly as before.
-- R155 (owner: "a 1.5x luck boost at the 10th pack"): while the pack pity's LUCKY roll is worked out (PackPity155.Scoped) the clamp is x1.5 higher (x75M:
-- LuckyLuckCeiling), so its x1.5 always counts; every other roll clamps exactly as before.
function O.Luck(luck)
 if Pity.Lucky()then return type(luck)=='number'and luck==luck and math.clamp(luck,1,Pity.Ceiling(T.LuckCeiling or T.MaxLuck))or 1 end
 return type(luck)=='number'and luck==luck and math.clamp(luck,1,T.LuckCeiling or T.MaxLuck)or 1
end
local function oneIn(pack,tier)
 return O.MidOneIn[pack][tier]or O.TopOneIn[tier]/O.PackTopLuck[pack]
end
-- present: set of tiers with at least one seed here. Returns {tier = probability}, summing to 1.
function O.TierOdds(present,biomeFloor,pack,luck)
 if not O.PackFloor[pack]then return nil end
 luck=O.Luck(luck)
 local floorRank=math.max(O.Rank[O.PackFloor[pack]],O.Rank[biomeFloor]or 1)
 local floor
 for i=floorRank,#O.Order do if present[O.Order[i]]then floor=O.Order[i];break end end
 if not floor then return nil end
 local out={}
 for i=O.Rank[floor]+1,#O.Order do
  local t=O.Order[i];local base=1/oneIn(pack,t)
  local p=math.min(math.max(base,O.Cap[t]),base*luck^O.Power[t])
  if present[t]then out[t]=(out[t]or 0)+p
  elseif i<=O.Rank.Mythic then
   for j=i+1,O.Rank.Mythic do local up=O.Order[j];if present[up]then out[up]=(out[up]or 0)+p;break end end
  end
 end
 if luck>1 then
  local base=O.TierOdds(present,biomeFloor,pack,1)
  local total=0;for _,v in pairs(out)do total+=v end
  local need=total-(1-O.FloorKeep*base[floor])
  for _,t in ipairs(O.Giveback)do
   if need<=0 then break end
   if out[t]then local give=math.min(need,out[t]-O.GivebackKeep*(base[t]or 0));out[t]-=give;need-=give end
  end
 end
 local total=0;for _,v in pairs(out)do total+=v end
 out[floor]=(out[floor]or 0)+1-total
 return out
end
function O.VoidTierOdds(present)
 local out={};local total=0
 for tier,n in pairs(O.Void.OneIn)do if present[tier]then out[tier]=1/n;total+=1/n end end
 if present.Secret then out.Secret=1-total end
 return out
end
local function group(pool,getRarity)
 local byTier={};local present={}
 for _,seed in ipairs(pool)do
  local tier=getRarity(seed.Id);present[tier]=true
  byTier[tier]=byTier[tier]or{};table.insert(byTier[tier],seed)
 end
 return byTier,present
end
-- Same-tier seeds split their tier evenly. Returns {seedId = probability} or nil.
function O.SeedOdds(pool,getRarity,biomeFloor,pack,luck)
 local byTier,present=group(pool,getRarity)
 local tiers=pack=='EclipseReliquary'and O.VoidTierOdds(present)or O.TierOdds(present,biomeFloor,pack,luck)
 if not tiers then return nil end
 local out={}
 for tier,p in pairs(tiers)do local seeds=byTier[tier]or{};for _,seed in ipairs(seeds)do out[seed.Id]=p/#seeds end end
 return out
end
-- Exact Bernoulli(p) even when one draw has only ~32 random bits: a tiny p is tested in gates of O.Gate.
function O.Chance(p,draw)
 if p>=1 then return true end
 if not(p>0)then return false end
 while p<O.Gate do
  if draw()>=O.Gate then return false end
  p/=O.Gate
 end
 return draw()<p
end
-- Rarest tier first, each tested with its chance given that no rarer tier hit, so the result follows `odds` exactly.
function O.RollTier(odds,draw)
 local remaining,lowest=1,nil
 for i=#O.Order,1,-1 do
  local t=O.Order[i];local p=odds[t]
  if p and p>0 then
   lowest=t
   if remaining<=p or O.Chance(p/remaining,draw)then return t end
   remaining-=p
  end
 end
 return lowest
end
-- draw: function returning a uniform number in [0,1). Returns seed, tier.
function O.Roll(pool,getRarity,biomeFloor,pack,luck,draw)
 local byTier,present=group(pool,getRarity)
 local tiers=pack=='EclipseReliquary'and O.VoidTierOdds(present)or O.TierOdds(present,biomeFloor,pack,luck)
 if not tiers then return nil end
 local tier=O.RollTier(tiers,draw);local seeds=tier and byTier[tier]
 if not seeds or #seeds==0 then return nil end
 local unit=draw()
 local index=type(unit)=='number'and unit==unit and math.clamp(math.floor(unit*#seeds)+1,1,#seeds)or 1
 return seeds[index],tier
end
return O
