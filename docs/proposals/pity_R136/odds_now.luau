--!nocheck
-- Today's Legendary..King odds per biome and pack from the real PackOdds112 (luck 1), as JSON for sim.py.
-- Run: copy tools/tests/roblox.luau + docs/proposals/inventory_R113/tests/world.luau next to it, build rs_bundle.luau
-- with docs/proposals/inventory_R113/tests/mkbundle.py, then: luau odds_now.luau > odds_now.json
local W=require('./world')
local Rules=W.module('SeedPackRules');local N=W.module('PackOdds112')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local names={[1]='Forest',[6]='Jungle',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[7]='Storm Peaks'}
local out={}
for _,stage in ipairs({1,6,2,3,4,5,7})do
 local pool=Rules.ObtainablePool(config,stage)
 local count={};for _,s in ipairs(pool)do local r=Rules.GetRarity(s.Id);count[r]=(count[r]or 0)+1 end
 local cs={};for _,t in ipairs(N.Order)do cs[#cs+1]=('"%s":%d'):format(t,count[t]or 0)end
 local packs={}
 for _,pack in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'})do
  local odds=Rules.SeedOdds(config,stage,pack,1)
  local tier={};for id,p in pairs(odds)do local r=Rules.GetRarity(id);tier[r]=(tier[r]or 0)+p end
  local ts={};for _,t in ipairs(N.Order)do ts[#ts+1]=('"%s":%.10g'):format(t,tier[t]or 0)end
  packs[#packs+1]=('"%s":{%s}'):format(pack,table.concat(ts,','))
 end
 out[#out+1]=('{"stage":%d,"name":"%s","count":{%s},"packs":{%s}}'):format(stage,names[stage],table.concat(cs,','),table.concat(packs,','))
end
print('['..table.concat(out,',')..']')
