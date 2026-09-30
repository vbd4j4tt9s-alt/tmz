-- R113: dumps the LIVE (R112) economy by running the real ReplicatedStorage modules (see bundle.py).
-- Output rows (TSV): COST, BOOT, TRAIL, MACHINE, PLANT, ODDS, MULT, BUNDLE, MISC.
local Rules=RS_MOD('SeedPackRules')
local T=RS_MOD('BalanceValues81')
local E=RS_MOD('EconomyBalance90')
local Cat=RS_MOD('PlantCatalog')
local PR=RS_MOD('PlantRules')
local B=RS_MOD('BalanceRules')
local Fence=RS_MOD('GardenFenceRules')
local Mech=RS_MOD('MechCatalog')
local Prem=RS_MOD('PremiumPricing')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
function config.GetSeedById(id) for _,c in ipairs(config.SeedCatalogByStage) do for _,s in ipairs(c) do if s.Id==id then return s end end end end
local function g(x) return string.format('%.17g',x) end
print('MISC','OddsVersion',Rules.OddsVersion,'MaxCash',g(E.MaxCash),'MaxBaseFruitValue',g(E.MaxBaseFruitValue),'CashPerGem',g(Mech.CashPerGem),'MechGemPrice',Mech.GemPrice)
for i,c in ipairs(T.MachineCosts) do print('MACHINE',i,g(c),g(T.MachineMultipliers[i])) end
for _,id in ipairs({'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'}) do print('TRAIL',id,g(T.TrailCosts[id]),g(T.TrailMultipliers[id])) end
for i,c in ipairs(T.BootCosts) do print('BOOT',i,g(c),g(T.BootLuck[i])) end
for i,tier in ipairs(Fence.Tiers) do print('FENCE',i,tier.Name,g(tier.Cost),g(Fence.Size(i)),g(Fence.Time(i))) end
for i,k in ipairs(T.PointCurve) do print('CURVE',i,g(k[1]),g(k[2])) end
for _,row in ipairs(Prem.Bundles) do print('BUNDLE',row.Key,row.Kind,g(row.Amount),row.GemPrice,row.RobuxPrice) end
local order={1,6,2,3,4,5,7}
local seen={}
local function plant(st,id)
 local d=Cat[id]
 print('PLANT',st,id,d.Name,(Rules.GetRarity(id)) or d.Rarity,g(d.Value),d.FruitCount,g(d.Seconds),g(d.RegrowSeconds or 0),tostring(d.Regrows~=false),tostring(d.Mode),
  g(T.IndexFirst[id] or -1),g(T.IndexRepeat[id] or -1))
end
for _,st in ipairs(order) do for _,s in ipairs(Rules.ObtainablePool(config,st)) do plant(st,s.Id); seen[s.Id]=true end end
for _,s in ipairs(Mech.Seeds) do plant(8,s.Id); print('MECHCHANCE',s.Id,s.Rarity,g(s.Chance)) end
-- live R112 odds: every biome x pack x boot (no boots + 5 boots)
local lucks={1}; for _,v in ipairs(T.BootLuck) do lucks[#lucks+1]=v end
for _,st in ipairs(order) do for _,pk in ipairs(Rules.VariantOrder) do for bi,L in ipairs(lucks) do
 local odds=Rules.SeedOdds(config,st,pk,L)
 for _,s in ipairs(Rules.ObtainablePool(config,st)) do
  local p=odds[s.Id] or 0
  if p>0 then print('ODDS',st,pk,bi-1,s.Id,g(p/100)) end
 end
end end end
-- Average sale multiplier (size + Gold/Diamond + weather) for a fruit, using the real PlantRules.Fruit.
-- Seed: pack size roll -> NewSeedScale (Pack01..06 by mix), pack mutation 95/4.5/.5, weather 2% on the pack (Drippy/Frosted/Charged 1/3 each).
local rng=Random and Random.new and Random.new(7) or nil
math.randomseed(7)
local function U() return math.random() end
local packs=Rules.VariantOrder
for _,mode in ipairs({'repeat','whole','single'}) do
 local def={Value=1000000,FruitCount=1,Regrows=(mode=='repeat'),Mode=(mode=='whole' and 'whole' or 'repeat'),RegrowSeconds=60,Seconds=60,SeedId='X'}
 local n,sum,sum0,sumsq=0,0,0,0
 for i=1,40000 do
  local pk=packs[1+math.floor(U()*#packs)]
  local size=Rules.RollPackSize(U())
  local seedScale=Rules.NewSeedScale(4,pk,size)
  local mut=Rules.RollMutation(U())
  local wr=U(); local weather=wr<.02/3 and 'Drippy' or wr<.04/3 and 'Frosted' or wr<.02 and 'Charged' or 'None'
  local crop=PR.NewCrop({SeedId='X',SeedScale=seedScale,Id='seed'..i,PackMutation=mut,Weather=weather},'crop'..i,def,0,0,0)
  for cycle=0,4 do
   crop.HarvestCycle=cycle
   local f=PR.Fruit(crop,1,def)
   local m=f.Value/def.Value
   n+=1; sum+=m; sumsq+=m*m; if cycle==0 then sum0+=m end
  end
 end
 print('MULT',mode,g(sum/n),g(sum0/40000))
end
