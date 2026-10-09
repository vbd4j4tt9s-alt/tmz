--!nocheck
-- R153, the 4 Leaf Clover pass (2x luck on every pack), SERVER half, on the Roblox mock with the REAL PlayerDataService, PremiumService, GamePassService, PassGiftService, PremiumProgress,
-- PurchaseAnnouncer, GamePassCatalog, MechCatalog, SeedPackRules and Config of this checkout.
--  1. the pass: one catalog row, Gem price 999, the id (code default, the CloverPassId attribute wins, 0 = off)
--  2. luck: 1x without the pass, 2x with it, whichever way it was got (Gems, Robux ownership, a purchase in the game, a gift); on every pack opening; stacked with the boots (the best pair x2),
--     owner test boots stay TEST luck, the one cap (MaxLuck) is respected, the friend boost (a SPEED gain) is not luck and is not touched
--  3. the Gem purchase: 999 off, the pass granted, a second purchase refused, too few Gems refused, id 0 still sells for Gems, never for a pass the Robux check already gave
--  4. Robux: UserOwnsGamePassAsync grants it; a purchase while playing (PromptGamePassPurchaseFinished) grants it at once, with the notice / PurchaseDone; a cancelled prompt, another pass's id do not
--  5. saved: profile version 22, the Gem ownership in the optional Premium.Later153 (never in Entitlements), nothing extra for a player without it, round trip, junk is refused
--  6. gifting: a Gem gift, a gift credit (receipt) and its use, the recipient gets the pass and the luck
-- It prints PROFILE lines (R153 saves) that run_clover.sh feeds to the R152 world (test_clover_r152.luau).
local E=require('./clover_env');local W,R,check=E.W,E.R,E.check
local RS=E.RS;local Config=E.Config;local Data=E.Data;local Market=E.Market
local Catalog=W.module('GamePassCatalog');local Mech=W.module('MechCatalog');local Balance=W.module('BalanceValues81');local Packs=W.module('SeedPackRules')
local boots=Config.ShopCatalog.Accessories
local row;for _,p in ipairs(Catalog)do if p.Key=='Clover'then row=p end end
-- 1. the pass --------------------------------------------------------------------------------------------------------------------------------------
check(row~=nil and #Catalog==3 and Catalog[3]==row,'the catalog has the 4 Leaf Clover as its third pass')
check(row.Name=='4 Leaf Clover'and row.Attribute=='CloverOwned'and row.IdAttribute=='CloverPassId'and row.Luck==2,'Key Clover, Name "4 Leaf Clover", Attribute CloverOwned, IdAttribute CloverPassId, Luck 2')
check(row.Description=='x2 luck on EVERY pack u open! 🍀','the description is in the owner\'s voice: '..tostring(row.Description))
check(Mech.PassGemPrices.Clover==999 and Mech.PassGemPrices.Growth==500 and Mech.PassGemPrices.Speed==400,'the Gem price is 999 (the other two are untouched)')
check(type(row.DefaultId)=='number'and row.DefaultId>=0 and row.DefaultId%1==0,'DefaultId is a whole number (0 = not on sale): '..tostring(row.DefaultId))
do
 local defaults={};for _,p in ipairs(Catalog)do defaults[p.Key]=p.DefaultId end
 check(defaults.Growth==nil and defaults.Speed==nil,'the other two passes have no DefaultId: they read their attribute as before')
 check(Catalog.Id(Catalog[1])==0 and Catalog.Id(Catalog[2])==0,'Growth / Speed without their attribute: id 0, as before')
 check(Catalog.Id(row)==row.DefaultId,'no attribute: the id is the code default ('..Catalog.Id(row)..')')
 RS.GamePassCatalog:SetAttribute('CloverPassId',4242);check(Catalog.Id(row)==4242,'the CloverPassId attribute wins over the default')
 RS.GamePassCatalog:SetAttribute('CloverPassId',0);check(Catalog.Id(row)==0,'... also when it is 0 (switched off)')
 for _,junk in ipairs({-5,1.5,'abc',true,1e300})do RS.GamePassCatalog:SetAttribute('CloverPassId',junk);check(Catalog.Id(row)==0,'a junk attribute ('..tostring(junk)..') is id 0, not the default')end
 RS.GamePassCatalog:SetAttribute('CloverPassId','777');check(Catalog.Id(row)==777,'a numeric string attribute reads as that number')
 RS.GamePassCatalog:SetAttribute('CloverPassId',nil);check(Catalog.Id(row)==row.DefaultId,'removing the attribute brings the default back')
 check(Catalog.LuckOf('Clover')==2 and Catalog.LuckOf('Growth')==1 and Catalog.LuckOf('Speed')==1 and Catalog.LuckOf('Nope')==1,'LuckOf: Clover 2, the others 1')
end
local PASS_ID=9001 -- a fixed id of this test (the attribute overrides the code default)
RS.GamePassCatalog:SetAttribute('CloverPassId',PASS_ID)
local owners={} -- userId -> {[passId]=true}: what UserOwnsGamePassAsync says
local ownsCalls=0
Market.UserOwnsGamePassAsync=function(_,uid,id)ownsCalls+=1;return owners[uid]~=nil and owners[uid][id]==true end
-- the services ---------------------------------------------------------------------------------------------------------------------------------
local chests={SyncTools=function()end,RenderGarden=function()end}
local bases={RefreshTreadmill=function()end,GetPlayerBase=function()return nil end}
local Passes=E.server('GamePassService').new(Data,bases,chests)
local Service=E.server('PremiumService').new(Data,chests,Passes)
local remote=RS.ChestChaseRemotes.PremiumRequest
local function invoke(p,action,value)E.advance(1);return remote.OnServerInvoke(p,action,value)end
local function gems(p)return Data:GetPremium(p).Gems end
local function setGems(p,n)Data:GetPremium(p).Gems=n;Data:PublishPremium(p)end
local function luck(p)return p:GetAttribute('ChestLuckMultiplier')end
local MAX=Balance.MaxLuck
check(MAX==25000000 and boots[5].LuckMultiplier==MAX and boots[1].LuckMultiplier==25 and boots[4].LuckMultiplier==500000,'(the boots\' cap is MaxLuck = 25,000,000 and Thunder Boots, the best pair, are exactly that; R155: every boot halved, was 50,000,000)')
-- R154 (owner: "the 2x luck is universal"): the pass doubles the cap too: LuckCeiling = MaxLuck x 2
check(Balance.LuckCeiling==2*MAX and Balance.LuckCeiling==50000000 and Balance.PassLuckCeiling==2,'R154: LuckCeiling = MaxLuck x the clover = 50,000,000 (R155; was 100,000,000), PassLuckCeiling 2')
-- 2. luck, without the pass --------------------------------------------------------------------------------------------------------------------
local Ann=E.makePlayer(1001,'Ann')
check(luck(Ann)==1 and Ann:GetAttribute('CloverOwned')~=true,'a new player: luck x1 and no pass')
check(not Data:HasTestLuck(Ann),'... and no test luck')
Data:AddBoost(Ann,boots[1].Id);check(luck(Ann)==25,'Sand Boots without the pass: x25 (R155: halved, was x50)')
local Cy=E.makePlayer(1002,'Cy')
-- 3. the Gem purchase --------------------------------------------------------------------------------------------------------------------------
setGems(Ann,5000)
local state=invoke(Ann,'State');check(state.Success==true,'(the shop state answers)')
local r=invoke(Ann,'BuyPerk','Clover')
check(r.Success==true and gems(Ann)==5000-999,'BuyPerk Clover: Success, 999 Gems off ('..tostring(gems(Ann))..' left; '..tostring(r.Message)..')')
check(Data:GetPremium(Ann).Entitlements.Clover==true,'... the pass is granted (the saved entitlement)')
check(Ann:GetAttribute('CloverOwned')==true,'... and the Owned attribute is on (the shop shows OWNED)')
check(luck(Ann)==50,'... and the luck is 2 x the boots at once: Sand Boots x25 -> x50 ('..tostring(luck(Ann))..')')
check(r.Message==nil,'... no message line (the notice below says it, as for the other Gem purchases: R148)')
local noteText;for _,n in ipairs(E.notes)do if n.P==Ann and n.Text:find('Bought',1,true)then noteText=n.Text end end
check(noteText=='✅ Bought: 🍀 4 Leaf Clover Pass!','the buyer gets the notice with the clover: '..tostring(noteText))
local done;for _,s in ipairs(E.sent)do if s.Remote=='PurchaseDone'and s.P==Ann then done=s.Args[1]end end
check(done and done.Kind=='Pass'and done.Name=='4 Leaf Clover Pass'and done.Icon=='Clover','PurchaseDone {Kind Pass, Name "4 Leaf Clover Pass", Icon Clover} goes to the buyer')
local again=invoke(Ann,'BuyPerk','Clover')
check(again.Success==false and gems(Ann)==5000-999,'a second purchase is refused and costs nothing ('..tostring(again.Message)..')')
check(again.Message=='U ALREADY HAVE THIS!','... "U ALREADY HAVE THIS!"')
local other=invoke(Ann,'BuyPerk','Growth');check(other.Success==true and gems(Ann)==5000-999-500,'(the other passes still sell: Growth 500)')
-- too few Gems
setGems(Cy,998);local poor=invoke(Cy,'BuyPerk','Clover')
check(poor.Success==false and gems(Cy)==998 and Data:GetPremium(Cy).Entitlements.Clover==nil and luck(Cy)==1,'998 Gems: refused, nothing taken, no pass, luck x1 ('..tostring(poor.Message)..')')
setGems(Cy,999);local exact=invoke(Cy,'BuyPerk','Clover')
check(exact.Success==true and gems(Cy)==0 and luck(Cy)==2,'999 Gems: bought, 0 left, luck x2 (no boots: 1 x 2)')
-- luck, with the pass: the boots ----------------------------------------------------------------------------------------------------------------
local Dee=E.makePlayer(1003,'Dee');setGems(Dee,2000);invoke(Dee,'BuyPerk','Clover')
check(luck(Dee)==2,'the pass alone: x2')
local expect={50,500,20000,1000000,2*MAX}
for i=1,5 do
 Data:AddBoost(Dee,boots[i].Id);local want=boots[i].LuckMultiplier*2 -- R154: never capped below the clover's x2
 check(luck(Dee)==want,'boots '..i..' (x'..boots[i].LuckMultiplier..') + the pass: x'..want..' ('..tostring(luck(Dee))..')')
end
check(luck(Dee)==2*MAX and boots[5].LuckMultiplier*2==Balance.LuckCeiling,'THE CAP (R154, R155 halved): Thunder Boots x25M x2 = x50M: a clover owner\'s cap is doubled, so the pass adds its x2 on top of the best boots too')
for i=1,4 do check(boots[i].LuckMultiplier*2<=MAX,'boots '..i..' x2 stays under the cap')end
-- the best pair counts, not the sum; the pass multiplies that
local Eve=E.makePlayer(1004,'Eve');Data:AddBoost(Eve,boots[2].Id);Data:AddBoost(Eve,boots[1].Id);check(luck(Eve)==250,'(boots do not add up: the best pair, x250)')
setGems(Eve,999);invoke(Eve,'BuyPerk','Clover');check(luck(Eve)==500,'... and the pass doubles that: x500')
-- the friend boost is a SPEED gain, not luck: untouched both ways
do
 local Fay=E.makePlayer(1005,'Fay');Fay:SetAttribute('FriendsInServer',3);Fay:SetAttribute('FriendSpeedBoost',1.3)
 check(luck(Fay)==1,'friends in the server do not change the luck (the friend boost is a speed gain)')
 setGems(Fay,999);invoke(Fay,'BuyPerk','Clover')
 check(luck(Fay)==2 and Fay:GetAttribute('FriendSpeedBoost')==1.3 and Fay:GetAttribute('FriendsInServer')==3 and Fay:GetAttribute('TreadmillMultiplier')==1,'the pass doubles the luck and leaves the friend boost and the treadmill speed alone')
 Fay:SetAttribute('FriendSpeedBoost',1.1);check(luck(Fay)==2,'... and a changing friend boost does not move the luck')
end
-- a pack opening uses it: every pack
do
 local seen={}
 Data.OnPackOpened=function(p,reward,info)seen[p]={Reward=reward,Info=info}end
 local function open(p)
  local pack=Data:AddChest(p,{Stage=3,BagVariant='Pack03',PackSize=1,PackMutation='None',OddsVersion=Packs.OddsVersion})
  return Data:OpenSeedPack(p,pack.Id,function()return .5 end)
 end
 local plain=E.makePlayer(1006,'Plain');open(plain);check(seen[plain]and seen[plain].Info.Luck==1,'a pack opened without the pass rolls with luck 1 (the hook sees '..tostring(seen[plain]and seen[plain].Info.Luck)..')')
 open(Cy);check(seen[Cy]and seen[Cy].Info.Luck==2,'a pack opened with the pass rolls with luck 2 ('..tostring(seen[Cy]and seen[Cy].Info.Luck)..')')
 open(Cy);open(Cy);check(seen[Cy].Info.Luck==2,'... every pack')
 local base=Packs.SeedOdds(Config,3,'Pack03',1,Packs.OddsVersion);local rarest,least;for id,pct in pairs(base)do if not least or pct<least then rarest,least=id,pct end end
 local boosted=Packs.SeedOdds(Config,3,'Pack03',2,Packs.OddsVersion)
 check(rarest~=nil and boosted[rarest]>base[rarest],'the odds of the rarest seed of a pack grow with luck 2 ('..tostring(rarest)..': '..string.format('%.5f',base[rarest])..'% -> '..string.format('%.5f',boosted[rarest])..'%)')
 Data.OnPackOpened=nil
end
-- owner test boots stay TEST luck (R152) -----------------------------------------------------------------------------------------------------------
do
 local Gus=E.makePlayer(1007,'Gus');local ok=false
 Data:AddBoost(Gus,boots[5].Id,{TestGrant=true});Data:EquipBoost(Gus,boots[5].Id);Data:RefreshBoostMultipliers(Gus)
 check(Data:HasTestLuck(Gus)and luck(Gus)==MAX,'owner test boots: test luck, x25M')
 setGems(Gus,999);invoke(Gus,'BuyPerk','Clover')
 check(Data:HasTestLuck(Gus)and luck(Gus)==2*MAX,'+ the pass (bought): still TEST luck (the boots in use are the owner\'s), x50M (R154: the cap doubles with the pass)')
 local Hal=E.makePlayer(1008,'Hal');Data:AddBoost(Hal,boots[1].Id,{TestGrant=true});setGems(Hal,999);invoke(Hal,'BuyPerk','Clover')
 check(Data:HasTestLuck(Hal)and luck(Hal)==50,'owner Sand Boots + the pass: x50 and still test luck')
 local Ian=E.makePlayer(1009,'Ian');setGems(Ian,999);invoke(Ian,'BuyPerk','Clover')
 check(not Data:HasTestLuck(Ian)and luck(Ian)==2,'the pass alone is real luck, not test luck')
 Data:AddBoost(Ian,boots[2].Id);check(not Data:HasTestLuck(Ian)and luck(Ian)==500,'bought boots + the pass: real luck')
 Data:AddBoost(Ian,boots[5].Id,{TestGrant=true});check(Data:HasTestLuck(Ian)and luck(Ian)==2*MAX,'... then owner Thunder Boots on top: test luck again (as in R152), x50M with the pass (R154)')
end
-- 4. Robux ownership -----------------------------------------------------------------------------------------------------------------------------
do
 local Jo=E.makePlayer(1010,'Jo');owners[1010]={[PASS_ID]=true}
 check(luck(Jo)==1,'(Jo owns the pass on Roblox but the server has not asked yet)')
 Passes:Refresh(Jo)
 check(Jo:GetAttribute('CloverOwned')==true and Jo:GetAttribute('CloverOwnershipReady')==true,'Robux ownership (UserOwnsGamePassAsync) grants the pass')
 check(luck(Jo)==2,'... and the luck is x2 ('..tostring(luck(Jo))..')')
 check(Data:GetPremium(Jo).Entitlements.Clover==nil,'... nothing is saved for it (Roblox is asked on every join)')
 local no=invoke(Jo,'BuyPerk','Clover');check(no.Success==false and no.Message=='U ALREADY HAVE THIS!','a player who owns it with Robux cannot buy it with Gems too')
 Data:AddBoost(Jo,boots[3].Id);check(luck(Jo)==20000,'Robux pass + Lava Boots: x20000 (R155: Lava x10K, halved)')
 -- the other passes do not give luck
 local Kim=E.makePlayer(1011,'Kim');owners[1011]={[101]=true,[102]=true};RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102)
 Passes:Refresh(Kim);check(Kim:GetAttribute('DoubleGrowthOwned')==true and Kim:GetAttribute('DoubleSpeedOwned')==true and luck(Kim)==1 and Kim:GetAttribute('CloverOwned')~=true,'Growth + Speed pass: no luck, no clover')
 RS.GamePassCatalog:SetAttribute('GrowthPassId',nil);RS.GamePassCatalog:SetAttribute('SpeedPassId',nil)
 -- a purchase while in the game
 local Lu=E.makePlayer(1012,'Lu');Passes:Refresh(Lu);check(luck(Lu)==1,'(Lu does not own it yet)')
 E.sent={};E.notes={}
 Market.PromptGamePassPurchaseFinished:Fire(Lu,PASS_ID,false);check(luck(Lu)==1 and Lu:GetAttribute('CloverOwned')~=true and#E.sent==0,'a cancelled prompt grants nothing')
 Market.PromptGamePassPurchaseFinished:Fire(Lu,PASS_ID+1,true);check(luck(Lu)==1 and Lu:GetAttribute('CloverOwned')~=true,'a purchase of another id grants nothing')
 owners[1012]={[PASS_ID]=true}
 Market.PromptGamePassPurchaseFinished:Fire(Lu,PASS_ID,true)
 check(Lu:GetAttribute('CloverOwned')==true and luck(Lu)==2,'PromptGamePassPurchaseFinished (purchased): the pass is on at once and the luck is x2 ('..tostring(luck(Lu))..')')
 local pd;for _,s in ipairs(E.sent)do if s.Remote=='PurchaseDone'and s.P==Lu then pd=s.Args[1]end end
 check(pd and pd.Icon=='Clover'and pd.Name=='4 Leaf Clover Pass','... and the buyer is told (PurchaseDone with the clover icon)')
 -- with the id switched off: no Robux route, Gems still work
 RS.GamePassCatalog:SetAttribute('CloverPassId',0)
 local Mo=E.makePlayer(1013,'Mo');local before=ownsCalls;Passes:Refresh(Mo)
 check(Mo:GetAttribute('CloverOwnershipReady')==true and Mo:GetAttribute('CloverOwned')~=true and luck(Mo)==1,'id 0: nobody owns it by Robux, the ownership check is "ready" without asking Roblox about it')
 setGems(Mo,2000);local viaGems=invoke(Mo,'BuyPerk','Clover');check(viaGems.Success==true and gems(Mo)==1001 and luck(Mo)==2,'id 0: the Gem purchase still works (999 off, luck x2)')
 Market.PromptGamePassPurchaseFinished:Fire(Mo,0,true);check(luck(Mo)==2,'(a finished prompt for id 0 changes nothing)')
 RS.GamePassCatalog:SetAttribute('CloverPassId',PASS_ID)
end
-- 5. saved ---------------------------------------------------------------------------------------------------------------------------------------
local profiles={}
local function newPlayerFrom(save,id,name,d)
 d=d or E.newData();d.Store.Data[d:_getKey({UserId=id,Name=name})]=E.deep(save)
 return E.makePlayer(id,name,d),d
end
do
 local saved=Data:_buildSaveData(Cy)
 check(saved.Version==22 and Config.ProfileVersion==22,'a save with the pass: ProfileVersion is still 22')
 local premium=saved.Premium
 check(premium.Entitlements.Clover==nil,'the Gem-bought pass is NOT in Entitlements (an R152 server rejects an unknown key there)')
 check(type(premium.Later153)=='table'and premium.Later153.Entitlements.Clover==true,'it is in the optional Premium.Later153.Entitlements.Clover')
 check(E.count(premium.Later153.GiftCredits)==0 and E.count(premium.Later153.PassOutbox)==0,'(nothing else in there)')
 check(premium.Gems==0,'(the saved Gems are what was left: 0)')
 local back,d2=newPlayerFrom(saved,1101,'Back')
 check(d2:GetPremium(back).Entitlements.Clover==true and back:GetAttribute('CloverOwned')==true,'after a save and a load: the pass is owned (Entitlements.Clover in memory, the attribute on)')
 check(luck(back)==2,'... and the luck is x2 straight after the load ('..tostring(luck(back))..')')
 check(d2:GetPremium(back).Later153==nil,'... Later153 is unpacked in memory (nothing left there)')
 local again=d2:_buildSaveData(back)
 check(E.ser(again.Premium.Later153)==E.ser(premium.Later153)and again.Premium.Entitlements.Clover==nil,'... and the next save writes the same Later153 again')
 -- with boots too
 local dEve=Data:_buildSaveData(Eve);local backEve=newPlayerFrom(dEve,1102,'BackEve')
 check(luck(backEve)==500,'boots + pass after a load: x500')
 -- a player without the pass saves exactly what R152 saved: no Later153 key
 local plainSave=Data:_buildSaveData(Ann.Parent and E.makePlayer(1103,'Plain2')or Ann)
 check(plainSave.Premium.Later153==nil and plainSave.Premium.Entitlements.Clover==nil,'a player without the pass: no Later153 key at all (the save is the R152 one)')
 -- Robux-only ownership is not saved
 local joSave=Data:_buildSaveData(E.makePlayer(1104,'Pat'))
 check(joSave.Premium.Later153==nil,'(Robux-only owners have nothing saved)')
 -- junk
 local function junk(name,fn)
  local bad=E.deep(saved);fn(bad.Premium)
  local p,why=nil,nil
  local d=E.newData();d.Store.Data[d:_getKey({UserId=1110,Name=name})]=bad
  local pl,why2=E.makePlayer(1110,name,d,{Kick=true})
  check(pl==nil and why2 and why2:find('newer server',1,true)~=nil,'junk Later153 ('..name..') is refused like any bad Premium (the save stays safe): '..tostring(why2))
 end
 junk('NotATable',function(p)p.Later153=5 end)
 junk('BadFlag',function(p)p.Later153.Entitlements.Clover='yes' end)
 junk('BadMap',function(p)p.Later153.GiftCredits=7 end)
 junk('BadCredit',function(p)p.Later153.GiftCredits={Clover=-3}end)
 -- an unknown pass in Later153 (a newer server's) is kept, not lost
 do
  local future=E.deep(saved);future.Premium.Later153.Entitlements.Moonbeam=true
  local f,d3=newPlayerFrom(future,1120,'Future')
  check(d3:GetPremium(f).Entitlements.Clover==true and d3:GetPremium(f).Entitlements.Moonbeam==nil and d3:GetPremium(f).Later153.Entitlements.Moonbeam==true,'a key of a pass this server does not know stays in Later153 (a newer pass of a later release)')
  local resave=d3:_buildSaveData(f)
  check(resave.Premium.Later153.Entitlements.Moonbeam==true and resave.Premium.Later153.Entitlements.Clover==true,'... and this server writes both back (nothing of the newer server\'s is lost)')
 end
 profiles.gem=saved;profiles.plain=plainSave
 -- control for the R152 test: what the saved shape WOULD be without the split
 local naive=E.deep(saved);naive.Premium.Entitlements.Clover=true;naive.Premium.Later153=nil;profiles.naive=naive
 -- this server reads the naive shape too (nothing writes it; it must not break anything)
 local nv=newPlayerFrom(naive,1130,'Naive');check(nv:GetAttribute('CloverOwned')==true and luck(nv)==2,'(an Entitlements.Clover inside Premium, which nothing writes, is read fine)')
end
-- 6. gifting ---------------------------------------------------------------------------------------------------------------------------------------
do
 local Gifts=Service.Gifts
 local Sam=E.makePlayer(1201,'Sam');local Tia=E.makePlayer(1202,'Tia');setGems(Sam,3000)
 local ok,msg=Gifts:Send(Sam,'Clover',Tia.UserId,'Gems')
 check(ok==true,'a Gem gift of the pass is sent ('..tostring(msg)..')')
 check(gems(Sam)==3000-999,'... 999 Gems off the sender ('..gems(Sam)..')')
 E.advance(2)
 check(Tia:GetAttribute('CloverOwned')==true and Data:GetPremium(Tia).Entitlements.Clover==true,'the recipient got the pass (the saved entitlement)')
 check(luck(Tia)==2,'... and the luck x2')
 check(next(Data:GetPremium(Sam).PassOutbox)~=nil,'(the sender\'s outbox row stays until the next recovery round)')
 E.advance(130)
 check(next(Data:GetPremium(Sam).PassOutbox)==nil,'the sender\'s outbox is empty again once the recovery round has run')
 local save=Data:_buildSaveData(Tia);check(save.Premium.Later153 and save.Premium.Later153.Entitlements.Clover==true and save.Premium.Entitlements.Clover==nil,'the gifted pass is saved apart too (Later153)')
 local again=Gifts:Send(Sam,'Clover',Tia.UserId,'Gems');check(again==false,'a pass the recipient already has cannot be gifted again')
 -- a gift credit (a bought gift): the receipt, then the send
 local GID=7777;RS.PassGiftCatalog:SetAttribute('CloverGiftProductId',GID)
 check(W.module('PassGiftCatalog').ProductId('Clover')==GID and W.module('PassGiftCatalog').ProductKey(GID)=='Clover','the gift product id attribute works for the pass (CloverGiftProductId)')
 local Uma=E.makePlayer(1203,'Uma');local Vic=E.makePlayer(1204,'Vic')
 local decision=Market.ProcessReceipt({ProductId=GID,PurchaseId='gift-1',PlayerId=Uma.UserId})
 check(decision==R.Enum.ProductPurchaseDecision.PurchaseGranted,'a gift product receipt is granted')
 check(Data:GetPremium(Uma).GiftCredits.Clover==1,'... one gift credit')
 local saveU=Data:_buildSaveData(Uma)
 check(saveU.Premium.GiftCredits.Clover==nil and saveU.Premium.Later153.GiftCredits.Clover==1,'the credit is saved in Later153.GiftCredits (not in GiftCredits: R152 would reject the key)')
 local backU,dU=newPlayerFrom(saveU,1205,'BackU');check(dU:GetPremium(backU).GiftCredits.Clover==1,'after a load the gift credit is back in GiftCredits')
 local okc,msgc=Gifts:Send(Uma,'Clover',Vic.UserId,'Credit');E.advance(2)
 check(okc==true and Vic:GetAttribute('CloverOwned')==true and luck(Vic)==2 and(Data:GetPremium(Uma).GiftCredits.Clover or 0)==0,'sending the credit gives Vic the pass and the luck, and uses the credit ('..tostring(msgc)..')')
 -- an in-flight gift (the outbox) is saved apart too
 local Wes=E.makePlayer(1206,'Wes');local Xan=E.makePlayer(1207,'Xan');setGems(Wes,2000)
 local realSave=Data.Save;Data.Save=function()return false end -- the debit cannot be saved: the gift stays pending in the outbox
 local okp=Gifts:Send(Wes,'Clover',Xan.UserId,'Gems')
 Data.Save=realSave
 local pending=Data:GetPremium(Wes).PassOutbox
 check(okp==true and E.count(pending)==1,'a gift whose first save failed waits in the outbox')
 local saveW=Data:_buildSaveData(Wes)
 check(E.count(saveW.Premium.PassOutbox)==0 and E.count(saveW.Premium.Later153.PassOutbox)==1,'... and is saved in Later153.PassOutbox (an R152 server would reject a PassOutbox row for a pass it does not know)')
 local backW,dW=newPlayerFrom(saveW,1208,'BackW');check(E.count(dW:GetPremium(backW).PassOutbox)==1 and dW:GetPremium(backW).Later153==nil,'after a load the pending gift is back in PassOutbox')
 profiles.gift=saveW
 local gift2=E.deep(save);gift2.Premium.Later153.GiftCredits={Clover=2};profiles.credits=gift2
end
-- profiles for the R152 world -------------------------------------------------------------------------------------------------------------------
for _,name in ipairs({'plain','gem','naive','gift','credits'})do print('PROFILE '..name..' '..E.ser(profiles[name]))end
E.finish('R153 clover (server)')
