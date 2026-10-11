--!nocheck
-- R153 server fixes, an R152 SERVER meets what an R153 server saved. This file runs in a world built from the R152 release (git archive of the release commit), with the save of
-- test_fixes_server.luau (profiles.luau, written by the R153 world as a PROFILE line): a profile with a GiftLocked pack, locked seeds, a locked plant and locked fruit.
--  * R152 loads it without a kick and keeps working (ProfileVersion 22; the lock is an optional field, so nothing is "newer")
--  * what R152 does with the new optional lock: it still knows the lock on a PACK, ignores it on a SEED (its own save writes the seed without it), and keeps it on the plant and the fruit
--    (the garden keeps fields it does not know). That is the one gap of the rollout window: publish, then shut down all servers, so no locked seed rests on an R152 server.
-- It prints RESAVED (what R152 wrote back) for the checks below.
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local function T(tag)return function(c,msg)return check(c,'['..tag..'] '..msg)end end
local t=T('M2')
local Config=E.Config
local profiles=require('./profiles')
t(Config.ProfileVersion==22 and Config.Version=='V150 R152','(this world is the R152 release: Config.Version '..tostring(Config.Version)..', ProfileVersion '..tostring(Config.ProfileVersion)..')')
local save=E.deep(profiles.locked)
local function rows(profile,pred)
 local out={}
 local function walk(v,depth)
  if type(v)~='table'or depth>6 then return end
  if pred(v)then out[#out+1]=v end
  for _,x in pairs(v)do walk(x,depth+1)end
 end
 walk(profile,0);return out
end
local lockedPacks=rows(save,function(r)return r.Kind=='Pack'and r.GiftLocked==true end)
local lockedSeeds=rows(save,function(r)return r.Kind=='Seed'and r.GiftLocked==true end)
local lockedCrops=rows(save,function(r)return r.SeedId and r.PlantedAt and r.GiftLocked==true end)
t(#lockedPacks>=1 and #lockedSeeds>=1 and #lockedCrops>=2,'(the R153 save has locked packs '..#lockedPacks..', seeds '..#lockedSeeds..', plants / fruit '..#lockedCrops..')')
local d=E.newData();d.Store.Data[d:_getKey({UserId=3001,Name='Old'})]=E.deep(save)
local p,why=E.makePlayer(3001,'Old',d,{Kick=true})
t(p~=nil,'R152 loads the R153 save without a kick ('..tostring(why)..')')
if p then
 t(p:GetAttribute('DataStatus')=='Loaded'and d.CanSave[p]==true,'... Loaded, and the save can be written')
 local mine=d:GetChestRecords(p)
 local packLocked,seedLocked,seeds=0,0,0
 for _,r in ipairs(mine)do
  if r.Kind=='Pack'and r.GiftLocked==true then packLocked+=1 end
  if r.Kind=='Seed'then seeds+=1;if r.GiftLocked==true then seedLocked+=1 end end
 end
 t(packLocked>=1,'R152 still knows the lock on a pack ('..packLocked..')')
 t(seeds>=1 and seedLocked==0,'R152 ignores the new lock on a seed (it loads them as ordinary seeds: '..seeds..' seeds, '..seedLocked..' locked)')
 local garden=d.Gardens[p]
 local plantLocked,fruitLocked=0,0
 for _,crops in pairs(garden.Plots)do for _,c in ipairs(crops)do if c.GiftLocked==true then plantLocked+=1 end end end
 for _,c in ipairs(garden.Harvests)do if c.GiftLocked==true then fruitLocked+=1 end end
 t(plantLocked>=1 and fruitLocked>=1,'R152 keeps the lock on the plant and the fruit (the garden keeps fields it does not know: '..plantLocked..' plants, '..fruitLocked..' fruit)')
 local out=d:_buildSaveData(p)
 t(out.Version==22,'its own save writes ProfileVersion 22')
 d:MarkDirty(p);t(d:Save(p,'test',true)==true,'R152 saves it')
 local stored=d.Store.Data[d:_getKey(p)]
 local storedPlants=#rows(stored,function(r)return r.SeedId and r.PlantedAt and r.GiftLocked==true end)
 t(storedPlants>=2,'the stored profile still has the lock on the plant and the fruit after R152\'s save ('..storedPlants..')')
 print('RESAVED locked '..E.ser(stored))
end
E.finish('R153 server fixes (old R152 server)')
