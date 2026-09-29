-- Small additive tier bonuses. Prices are server-owned and never supplied by a client.
local R={}
R.Tiers={
 {Name='Woodland',Biome='Forest',Cost=0},
 {Name='Mossy Cobble',Biome='Jungle',Cost=500},
 {Name='Dune Stone',Biome='Desert',Cost=1800},
 {Name='Frostwall',Biome='Snow',Cost=5000},
 {Name='Prismwall',Biome='Crystal',Cost=14000},
 {Name='Emberwall',Biome='Lava',Cost=36000},
 {Name='Stormline',Biome='Storm',Cost=90000},
}
function R.Level(v)
 if type(v)~='number'or v~=v or v==math.huge or v==-math.huge then return 1 end
 return math.clamp(math.floor(v),1,#R.Tiers)
end
function R.Bonus(tier)return (R.Level(tier)-1)/(#R.Tiers-1)*.05 end
function R.Size(tier)return 1+R.Bonus(tier)end
function R.Time(tier)return 1-R.Bonus(tier)end
function R.Duration(seconds,tier)return math.max(1,math.ceil(seconds*R.Time(tier)))end
function R.ApplyPlant(crop,def,tier)
 tier=R.Level(tier);if tier==1 then return crop end
 -- Keep the 5% bonus: half-step rounding erased it on ordinary 1x plants.
 crop.PlantScale=math.min(25,math.floor(crop.PlantScale*R.Size(tier)*10000+.5)/10000)
 crop.FenceBonusVersion=84
 crop.FenceTier=tier;crop.MatureAt=crop.PlantedAt+R.Duration(def.Seconds,tier);crop.ReadyAt=crop.MatureAt
 return crop
end
for i,tier in ipairs(R.Tiers)do tier.Cost=require(script.Parent.BalanceValues81).FenceCosts[i]end
return R
