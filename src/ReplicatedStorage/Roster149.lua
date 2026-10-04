-- R148 (owner): seed roster change. Desert gets a Rare (Aloe) and a Legendary (Sand Fruit, a round cactus); Fire Pepper
-- becomes Lava's Mythic (twice the size, far more cash per pepper); Moon Melon becomes Crystal's Legendary.
-- Shared constants. Nothing is required at load time (SeedPackRules, BalanceValues81 and PlantCatalog read it).
-- (The identifiers keep the "149" of the odds version this roster change introduced: OddsVersion 149.)
local R={Version=149}
-- Seeds added in this release: packs made before it (OddsVersion 137 / 112 / 81 / none) never roll them.
R.New={DesertAloeSeed=true,SandFruitSeed=true}
-- The promoted seeds and their rarity now. Owner decision (no windfall): packs made before this release (OddsVersion 137 / 112 / 81 / none)
-- cannot roll them at all: SeedPackRules takes them out of the banked pools, and the seeds that shared their old Rare tier absorb the share.
R.Promote={FirePepperSeed='Mythic',MoonflowerSeed='Legendary'}
-- SeedPackRules.SeedDesigns rows. Desert save slots 9 and 10 (slots 1-8 keep their ids, retired ones included).
R.Designs={
 {biome='Desert',index=9,name='Aloe',rarity='Rare',design='rich sea green to pale sage, cream leaf spots, three fleshy aloe blades and a bright red-orange flower spike',
  pattern='Dots',top='4a9e88',bottom='c3dcc0',ink='f2f6e6',addition='none',stage=2,id='DesertAloeSeed'},
 {biome='Desert',index=10,name='Sand Fruit',rarity='Legendary',design='sand gold to warm cream, sandy specks and grains, a tiny round cactus on top and twinkling sand sparkles',
  pattern='Specks',top='d6a35c',bottom='f6e3b4',ink='a8733c',addition='none',stage=2,id='SandFruitSeed'},
}
-- Final plant numbers, written after GrowthPace125 (PlantCatalog applies this module last, so the pacing never touches them).
-- Rule (EconomyBalance90 + GrowthPace125): income/s = biome base x tier, halved by the R125 pacing; value per fruit =
-- income x RegrowSeconds / FruitCount. Bases: Desert 34760, Lava 137578, Crystal 272073; tiers Rare 2.5, Legendary 4, Mythic 7.
-- Owner decision: the Rare Aloe out-earns the Uncommon Prickly Pear per hour, so its fruit is worth 1.0e7 (the rule alone gives
-- 7,680,000 = 1.56e8/h; 9.9e6 or more passes Prickly Pear's 2.0e8/h): 2.04e8/h, still below Iceberry (2.73e8) and Sand Fruit.
R.Plants={
 DesertAloeSeed={Name='Aloe',HarvestName='Aloe bloom',Rarity='Rare',Rank=3,Tree=false,FruitCount=3,Seconds=960,RegrowSeconds=530,Value=10000000},       -- 2.04e8/h
 SandFruitSeed={Name='Sand Fruit',HarvestName='Sand fruit',Rarity='Legendary',Rank=4,Tree=false,FruitCount=4,Seconds=2760,RegrowSeconds=1520,Value=26400000}, -- 2.50e8/h (a round cactus, not a tree: no trunk collision)
 FirePepperSeed={Rarity='Mythic',Rank=5,Seconds=4300,RegrowSeconds=2370,Value=285000000},  -- 1.73e9/h (FruitCount stays 4: saved crops depend on it)
 MoonflowerSeed={Rarity='Legendary',Rank=4,Seconds=3400,RegrowSeconds=1870,Value=509000000}, -- 1.96e9/h (FruitCount stays 2)
}
-- Index cash {first, repeat}. New seeds: one base fruit / a fifth of it. Promoted seeds: the old amounts x new / old fruit value
-- (the EconomyBalance90.Apply convention).
R.Index={DesertAloeSeed={10000000,2000000},SandFruitSeed={26400000,5280000},FirePepperSeed={360000000,72000000},MoonflowerSeed={475000000,95000000}}
R.FirePepperArtScale=2 -- the Fire Pepper plant and its peppers: art, sockets, fruit centres, radii and bounds
function R.ApplyBalance(T)
 for id,cash in pairs(R.Index)do T.IndexFirst[id]=cash[1];T.IndexRepeat[id]=cash[2]end
end
local function scaled(points,f)local out={};for i,p in ipairs(points)do out[i]={p[1]*f,p[2]*f,p[3]*f}end;return out end
function R.ApplyPlants(catalog)
 local Art=require(script.Parent.DesertPlantArt149)
 for _,spec in ipairs(R.Designs)do
  local n=R.Plants[spec.id];local art=Art.Get(spec.id)
  catalog[spec.id]={Id=spec.id,Name=n.Name,Biome='Desert',Stage=2,Rarity=n.Rarity,Rank=n.Rank,Tree=n.Tree,Mode='repeat',HarvestName=n.HarvestName,
   FruitCount=n.FruitCount,Roster149=true,Sockets=scaled(art.Sockets,1),FruitCenters=scaled(art.FruitCenters,1),FruitRadii=table.clone(art.FruitRadii),
   Height=art.Height,Radius=art.Radius,BaseScale=1,AuthoredHeight=art.Height,Seconds=n.Seconds,RegrowSeconds=n.RegrowSeconds,Value=n.Value}
 end
 for id in pairs(R.Promote)do
  local d,n=catalog[id],R.Plants[id]
  d.Rarity=n.Rarity;d.Rank=n.Rank;d.Seconds=n.Seconds;d.RegrowSeconds=n.RegrowSeconds;d.Value=n.Value
  d.Roster149=true;d.BaseSeconds=nil;d.GrowthFactor=nil
 end
 local d,f=catalog.FirePepperSeed,R.FirePepperArtScale
 d.Height*=f;d.Radius*=f;d.Sockets=scaled(d.Sockets,f);d.FruitCenters=scaled(d.FruitCenters,f)
 local radii={};for i,r in ipairs(d.FruitRadii)do radii[i]=r*f end;d.FruitRadii=radii
 -- The retired Uncommon AloeSeed (players may still hold one) gets its own display name; its id never changes.
 catalog.AloeSeed.Name='Aloe Sprout';catalog.AloeSeed.HarvestName='Aloe sprout'
end
return R
