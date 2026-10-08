--!nocheck
-- R153, the way back: the profiles an R152 server loaded and wrote back (resaved.luau: RESAVED lines of test_clover_r152.luau, the stored profile after R152's own save) are read by an R153
-- server again: the Gem-bought pass is still owned (Later153 came through R152 untouched), the luck is x2, gift credits and a pending gift are back where the other passes keep theirs.
local E=require('./clover_env');local check,R=E.check,E.R
local resaved=require('./resaved')
local Catalog=E.W.module('GamePassCatalog')
check(#Catalog==3,'(this world is R153: three passes)')
local id=3000
local function load(name)
 id+=1;local d=E.newData();d.Store.Data[d:_getKey({UserId=id,Name=name})]=E.deep(resaved[name]);return E.makePlayer(id,name,d),d
end
local p,d=load('gem')
check(d:GetPremium(p).Entitlements.Clover==true and p:GetAttribute('CloverOwned')==true,'gem: after R153 -> R152 -> R153 the pass is still owned')
check(p:GetAttribute('ChestLuckMultiplier')==2,'... luck x2')
local again=d:_buildSaveData(p)
check(again.Premium.Entitlements.Clover==nil and again.Premium.Later153.Entitlements.Clover==true,'... and it is saved in Later153 again')
local plain,dp=load('plain')
check(plain:GetAttribute('CloverOwned')~=true and plain:GetAttribute('ChestLuckMultiplier')==1,'plain: no pass, luck x1')
local credits,dc=load('credits')
check(dc:GetPremium(credits).GiftCredits.Clover==2 and dc:GetPremium(credits).Entitlements.Clover==true,'credits: two gift credits are back in GiftCredits, the pass in Entitlements')
local gift,dg=load('gift')
local outbox=dg:GetPremium(gift).PassOutbox;local n=0;local row;for _,v in pairs(outbox)do n+=1;row=v end
check(n==1 and row.PassKey=='Clover'and row.State=='Pending','gift: the pending gift is back in PassOutbox, Pending, for the Clover')
check(dg:GetPremium(gift).Later153==nil,'... and Later153 holds nothing in memory (it was unpacked)')
E.finish('R153 clover (back from R152)')
