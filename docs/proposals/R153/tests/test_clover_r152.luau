--!nocheck
-- R153, an R152 SERVER meets what an R153 server saved. This file runs in a world built from the R152 release (git archive of the release commit: the R152 PlayerDataService, PremiumProgress,
-- PassGiftState, GamePassCatalog (two passes), MechCatalog (two Gem prices), Config), with the saves of test_clover.luau (profiles.luau, written by the R153 world as PROFILE lines).
--  * plain (no pass), gem (the Gem-bought pass), gift (a pending gift), credits (gift credits): every one loads on R152 without a kick, the Gems / boots / everything else are there, R152 does not know
--    the pass (no Owned attribute, no luck), and its own next save keeps the optional field Premium.Later153 exactly as it was (so the R153 server that reads the profile next still sees the pass)
--  * naive: the shape the pass WOULD have if its Gem ownership were saved in Entitlements like the first two passes' (what a plain port would write): R152 refuses it ("needs a newer server": a kick):
--    the reason the R153 server saves it in Later153 instead
-- It prints RESAVED lines (what the R152 server wrote back) for test_clover_back.luau.
local E=require('./clover_env');local check,R=E.check,E.R
local Config=E.Config
local profiles=require('./profiles')
check(Config.ProfileVersion==22 and Config.Version=='V150 R152','(this world is the R152 release: Config.Version '..tostring(Config.Version)..', ProfileVersion '..tostring(Config.ProfileVersion)..')')
local Catalog=E.W.module('GamePassCatalog');local Mech=E.W.module('MechCatalog')
check(#Catalog==2 and Mech.PassGemPrices.Clover==nil and E.W.module('PassGiftCatalog').Pass('Clover')==nil,'(R152 has two passes and does not know the Clover)')
local resaved={}
local id=2000
local function load(name,opts)
 id+=1;local d=E.newData();local save=E.deep(profiles[name])
 d.Store.Data[d:_getKey({UserId=id,Name=name})]=save
 local p,why=E.makePlayer(id,name,d,opts)
 return p,d,why,save
end
for _,name in ipairs({'plain','gem','gift','credits'})do
 local p,d,why,save=load(name)
 check(p~=nil,'R152 loads the '..name..' save without a kick')
 if p then
  check(p:GetAttribute('DataStatus')=='Loaded'and d.CanSave[p]==true,'... '..name..': Loaded, and the save can be written')
  check(p:GetAttribute('CloverOwned')==nil and p:GetAttribute('ChestLuckMultiplier')==1,'... '..name..': R152 does not know the pass: no Owned attribute, luck x1')
  check(d:GetPremium(p).Gems==save.Premium.Gems,'... '..name..': the Gems are there ('..tostring(d:GetPremium(p).Gems)..')')
  check(d:GetPremium(p).Entitlements.Clover==nil,'... '..name..': nothing of the pass in Entitlements')
  local out=d:_buildSaveData(p)
  check(out.Version==22,'... '..name..': it writes ProfileVersion 22')
  if save.Premium.Later153 then
   check(E.ser(out.Premium.Later153)==E.ser(save.Premium.Later153),'... '..name..': its own save keeps Premium.Later153 exactly as it was (the pass is not lost)')
  else check(out.Premium.Later153==nil,'... '..name..': no Later153 appears out of nowhere')end
  check(E.count(out.Premium.PassOutbox)==0 and out.Premium.GiftCredits.Clover==nil and out.Premium.Entitlements.Clover==nil,'... '..name..': the pass is in none of the maps R152 checks')
  -- the real write path: UpdateAsync merges the save into the stored profile
  d:MarkDirty(p);check(d:Save(p,'test',true)==true,'... '..name..': R152 saves it to the store')
  local stored=d.Store.Data[d:_getKey(p)]
  check(stored and(save.Premium.Later153==nil and stored.Premium.Later153==nil or stored.Premium.Later153~=nil and E.ser(stored.Premium.Later153)==E.ser(save.Premium.Later153)),'... '..name..': the stored profile still has the field after R152\'s save')
  resaved[name]=stored
 end
end
-- the naive shape is refused (and the profile is left alone)
do
 local p,d,why=load('naive',{Kick=true})
 check(p==nil and why and why:find('newer server',1,true)~=nil,'R152 refuses an Entitlements.Clover with "needs a newer server" (a kick): '..tostring(why))
end
for name,save in pairs(resaved)do print('RESAVED '..name..' '..E.ser(save))end
E.finish('R153 clover (old R152 server)')
