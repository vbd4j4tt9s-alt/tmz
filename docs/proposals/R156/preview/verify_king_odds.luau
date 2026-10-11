--!nocheck
-- R156 preview helper (not a test): checks the tip "mythic packs give a higher chance of a king seed" on the REAL odds code under the Roblox mock.
-- For every biome and every pack tier (Pack01 Common .. Pack06 Mythic, SeedPackRules.PackTiers) it prints the chance (in %) of a King / Mythic / Secret / Cosmic seed
-- at luck 1, OddsVersion 149 (the current one). Run it from a scratch dir that holds roblox.luau, world.luau and rs_bundle.luau (run_title_tips156.sh sets that up).
local W=require('./world')
local Rules=W.module('SeedPackRules')
local catalog=Rules.BuildSeedCatalog();local byId={}
for _,list in ipairs(catalog)do for _,seed in ipairs(list)do byId[seed.Id]=seed end end
local config={SeedCatalogByStage={catalog[1],catalog[2],catalog[3],catalog[4],catalog[5],catalog[6],catalog[7],catalog[8],catalog[9]},GetSeedById=function(id)return byId[id]end}
local names={'Forest','Desert','Snow','Lava','Crystal','Jungle','Storm Peaks'}
local tiers={}
for i,t in ipairs(Rules.PackTiers)do tiers[i]=t.Name end
print('PACKS '..table.concat(tiers,' < '))
local allUp=true
for stage=1,7 do
 local line,prev,up={},-1,true;local hasKing=false
 for i,v in ipairs(Rules.VariantOrder)do
  local o=Rules.RawSeedOdds and Rules.SeedOdds(config,stage,v,1,149)or Rules.SeedOdds(config,stage,v,1,149)
  local sum={}
  for id,p in pairs(o)do local r=Rules.GetRarity(id);sum[r]=(sum[r]or 0)+p end
  local king=sum.King or 0
  local low,lowRank='-',99
  for r,pr in pairs(sum)do local rank=Rules.Rarities[r].Rank;if pr>0 and rank<lowRank then low,lowRank=r,rank end end
  if king>0 then hasKing=true end
  if king<=prev and hasKing then up=false end
  prev=king
  line[#line+1]=('%s King %.3g%% Mythic %.3g%% Secret %.3g%% worst seed %s'):format(Rules.GetPackTier(v).Name,king,sum.Mythic or 0,sum.Secret or 0,low)
 end
 print(('STAGE %d %s | %s | King rises with the tier: %s%s'):format(stage,names[stage],table.concat(line,' | '),tostring(up),hasKing and''or' (no King seed in this biome)'))
end
