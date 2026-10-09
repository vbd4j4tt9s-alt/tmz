--!nocheck
-- R155, the server (owner: "make the max amount of items a person can hold 200", "allow people to discard items"). The REAL PlayerDataService (+ InventoryCap155,
-- DailyProgress, PremiumProgress, TutorialProgress), ChestService.Bank, TreadmillBonusService, MysteryPackService, VoidGiveaway152, FruitGiftService, PremiumService,
-- RarePackTests and InventoryService155 on the Roblox mock (DataStores faked).
--  1. what counts: packs + seeds + fruit + loot items, a stack of N = N; plants and gear do not; HeldItemCount / HeldItemCap on the Player.
--  2. the cap on EVERY grant path, at 200 (and the old messages): a stolen pack banked (and the carried pack's place kept: a full bag never eats a stolen
--     pack, every other grant counts it), the steal / pick-up start, the bonus roll (the roll stays ready), the daily login / quest pack, the mystery pedestal,
--     the free Void Pack, Verity (a swap: works when full), the Mech pack for Gems (the shop does not offer it, gems kept), a Mech Robux receipt (never lost:
--     granted even over 200; only the old 1000 ceiling makes it wait), gifts in (seed and fruit: left waiting in the inbox) and out ("Their bag is full."),
--     harvesting, the tutorial's starter pack, owner test grants.
--  3. an old save above 200 (350 packs / seeds + 300 fruit) loads WHOLE (nothing cut, the validators keep their old ceilings), receives nothing, saves whole;
--     after selling / discarding below 200 it receives again.
--  4. discarding (InventoryService155): every refusal (loading, not saving, a bad request, the shovel / a non-item, gone, too many, carrying / a chase, a gift
--     being saved, the pack being opened, a reward seed still landing); a stack (in hand last), fruit, a loot item; the count drops; the Output / /test hotbar
--     line; nothing comes back; after a rejoin the items are still gone; the remotes and their rate limit.
--  5. the saved hotbar layout: validated, kept in Premium.Hotbar155, handed back at join as HotbarLayout155, a broken one is dropped (the save still loads).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end;Run.IsStudio=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
function Players.GetNameFromUserIdAsync(_,id)return 'User'..id end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(self.Data[key],nil);if v~=nil then self.Data[key]=v end;return self.Data[key]end,
  GetAsync=function(self,key)return self.Data[key]end,SetAsync=function(self,key,v)self.Data[key]=v end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function()end;o.FireAllClients=function()end end
 if class=='Tool'then for _,e in ipairs({'Equipped','Unequipped','Activated','Destroying'})do if o[e]==nil then o[e]=R.signal()end end end
 return o end end
local printed={};W.env.print=function(...)local t={};for i=1,select('#',...)do t[i]=tostring(select(i,...))end;printed[#printed+1]=table.concat(t,' ');print(...)end
local Config=server('Config');local Rules=W.module('SeedPackRules');local Stacks=W.module('InventoryStacks155')
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local shown={};local Notes={Show=function(_,p,text)shown[#shown+1]={P=p,Text=text}end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
local synced=0;local Chests={Openings={},PlayerData=Data};function Chests:SyncTools(p)synced+=1;if self.Rebuild then self.Rebuild(p)end end;function Chests:IsOpening()return false end
R.clock=20000*86400+3600
local function makePlayer(id,name,keep)
 local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=id;p.Parent=Players;present[id]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p
 local c=R.new('Model');c.Name=name;c.Parent=W.workspace;p.Character=c;local h=R.Instance.new('Humanoid');h.Health=100;h.Parent=c
 h.UnequipTools=function()for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')then t.Parent=p:FindFirstChildOfClass('Backpack')end end end
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name);Data.CanSave[p]=true
 return p
end
local function pack(stage,variant)return {Stage=stage or 1,BagVariant=variant or'Pack01',PackSize=1,PackMutation='None',Weather='None',OddsVersion=Rules.OddsVersion}end
local serial=0
local function seedRow(p,seedId)serial+=1;local s=Config.GetSeedById(seedId or'SunflowerSeed');return {Id=p.UserId..'_s'..serial,ChestNumber=900000+serial,ChestName=s.Name,Kind='Seed',Stage=1,SeedId=s.Id,SeedName=s.Name,SeedEmoji=s.Emoji,AccentColor=s.Color,Rarity='Common',SeedScale=1,PackMutation='None',BagVariant='Pack01',OddsVersion=Rules.OddsVersion,PackSize=1}end
local function fillTo(p,n)local r=Data:GetChestRecords(p);while Data:HeldItemCount(p)<n do r[#r+1]=seedRow(p)end;while Data:HeldItemCount(p)>n and #r>0 do table.remove(r)end;Data:_notifySeedInventory(p)end
local function held(p)return Data:HeldItemCount(p)end
local FULL='BAG FULL - MAKE ROOM IN UR BAG FIRST'

-- 0 / 1. the numbers, what counts -----------------------------------------------------------------------------------------------------------------
check(Data:HeldItemCap()==200 and W.module('InventoryStacks155').Cap==200 and Config.MaxHeldItems==nil and Config.MaxSavedChests==1000 and Config.MaxSavedHarvests==500,'the cap is 200 (InventoryStacks155.Cap; Config.lua untouched); the old storage ceilings (1000 / 500) stay for the save validators')
local A=makePlayer(601,'Ava')
check(held(A)==0 and A:GetAttribute('HeldItemCount')==0 and A:GetAttribute('HeldItemCap')==200,'a new player holds 0 of 200 (published on the Player)')
Data:AddChest(A,pack());for _=1,4 do table.insert(Data:GetChestRecords(A),seedRow(A))end;Data:_notifySeedInventory(A)
local g=Data.Gardens[A];for i=1,3 do g.Harvests[#g.Harvests+1]={Id='fruit-'..i,SeedId='SunflowerSeed'}end;Data:_gardenChanged(A)
local loot=Data:AwardLoot(A,1,'Rare','Golden Idol')
g.Plots['1']={{Id='plant-x',SeedId='SunflowerSeed'}} -- (a plant)
Data.OwnedBoosts[A]['boots-1']=true -- (gear)
check(held(A)==9 and A:GetAttribute('HeldItemCount')==9,'1 pack + 4 seeds (a stack of 4 = 4) + 3 fruit + 1 loot item = 9; the plant and the gear do not count ('..held(A)..')')
g.Plots['1']={};loot:Destroy();table.clear(g.Harvests);Data:_gardenChanged(A)

-- 2. every grant path at the cap -----------------------------------------------------------------------------------------------------------------------
-- a stolen pack banked (ChestService:Bank), the steal / pick-up start (CanReceiveSeed)
local Chest=server('ChestService')
local bankSelf={PlayerData=Data,SyncTools=function()end}
fillTo(A,199);check((Chest.Bank(bankSelf,A,pack()))~=nil and held(A)==200,'199: a stolen pack is banked (200)')
local r2,why2=Chest.Bank(bankSelf,A,pack());check(r2==nil and why2==FULL and held(A)==200,'200: banking is refused with "'..tostring(why2)..'"')
local okStart,whyStart=Data:CanReceiveSeed(A);check(okStart==false and whyStart==FULL,'200: a steal / pick-up does not start (CanReceiveSeed: '..tostring(whyStart)..')')
fillTo(A,199);A:SetAttribute('ChestChaseSeedCarrying',true)
check(not Data:CanReceiveSeed(A)and not Data:RoomFor(A,1),'199 while carrying a pack home: its place is kept, so every other grant sees a full bag')
-- (ConcurrentKeeperService clears the carry flag right before it banks the pack: the kept place becomes the pack)
do local src=W.B.ConcurrentKeeperService or'';local clear=src:find('run.Player:SetAttribute("ChestChaseSeedCarrying", false)',1,true);local bank=src:find('self.Chests:Bank(run.Player, run.Chest)',1,true)
 check(clear and bank and clear<bank,'(the keeper run clears ChestChaseSeedCarrying before it banks the pack)')end
A:SetAttribute('ChestChaseSeedCarrying',false)
check((Chest.Bank(bankSelf,A,pack()))~=nil and held(A)==200,'... and the carried pack itself is banked (a full bag never eats a stolen pack)')
A:SetAttribute('ChestChaseSeedCarrying',nil)
-- the bonus roll
local Base={TrainingSessions={}}
local Bonus=server('TreadmillBonusService').new(Config,Data,Base,Chests,Notes)
fillTo(A,200);Bonus.Ready[A]=1;Bonus.LastRoll[A]=nil
local roll=Bonus:Roll(A);check(roll.Error and roll.Error:find('FULL',1,true)and Bonus:GetReady(A)==1 and held(A)==200,'the bonus roll at 200: refused, the roll stays ready ('..tostring(roll.Error)..')')
fillTo(A,199);Bonus.LastRoll[A]=nil;R.advance(5);roll=Bonus:Roll(A);check(roll.Ok and held(A)==200,'at 199 it rolls (200)')
-- the daily login / quest pack
fillTo(A,200);local d,dwhy=Data:GrantDailyPack(A);check(d==nil and dwhy=='MAKE ROOM FOR 1 PACK FIRST!','the daily login / quest pack at 200: "'..tostring(dwhy)..'"')
fillTo(A,199);check((Data:GrantDailyPack(A))~=nil and held(A)==200,'at 199 it is given')
-- the mystery pedestal
local Mystery=server('MysteryPackService')
fillTo(A,200);local m,mwhy=Mystery._give({Data=Data,Shapes={}},A,{Stage=1,Variant='Pack02',Day=1});check(m==nil and mwhy==FULL,'the mystery pedestal at 200: '..tostring(mwhy))
fillTo(A,199);check((Mystery._give({Data=Data,Shapes={}},A,{Stage=1,Variant='Pack02',Day=1}))~=nil,'at 199 it is given')
-- the free Void Pack
local VG=server('VoidGiveaway152');local vg=setmetatable({Data=Data,Config=Config,Chests=Chests},{__index=VG})
fillTo(A,200);local v,vwhy=vg:_grant(A);check(v==nil and vwhy=='room'and vg:_room(A)==false,'the free Void Pack at 200: no room, nothing reserved ('..tostring(vwhy)..')')
fillTo(A,199);check(vg:_room(A)and(vg:_grant(A))~=nil and held(A)==200,'at 199 it is given')
-- Verity: a swap (one Void Pack for one Verity Pack), so a full bag is fine
fillTo(A,199);local void=Data:AddChest(A,{Stage=7,BagVariant='EclipseReliquary',PackSize=1,PackMutation='None',OddsVersion=Rules.OddsVersion})
check(void and held(A)==200,'(a Void Pack: 200)')
local verity=Data:ConvertVoidPack(A,void.Id);check(verity and verity.BagVariant=='VerityReliquary'and held(A)==200,'Verity at 200: the Void Pack becomes a Verity Pack (a swap, not a new item)')
-- Mech: for Gems (refused, gems kept) and a Robux receipt (never lost)
A:SetAttribute('PaidRandomAllowed',true);Data:GetPremium(A).Gems=900
fillTo(A,200);local okM,whyM=Data:BuyMechPack(A,1)
check(okM==false and whyM=='MAKE ROOM FOR 1 PACKS FIRST!'and Data:GetPremium(A).Gems==900 and held(A)==200,'a Mech pack for Gems at 200: refused, no gems taken ('..tostring(whyM)..')')
check(not Data:CanReceiveMechPacks(A,1)and not Data:CanReceiveMechPacks(A,10),'the shop does not offer Mech packs (Gems or Robux) that do not fit')
fillTo(A,195);check(Data:CanReceiveMechPacks(A,5)and not Data:CanReceiveMechPacks(A,10),'195: a 5-pack fits, a 10-pack does not')
RS.MechCatalog:SetAttribute('MechPackProductId',777001)
local Premium=server('PremiumService');local svc=setmetatable({Data=Data,Busy={},Unannounced={},Chests=Chests},{__index=Premium})
fillTo(A,200) -- (the purchase was offered at 199; an item arrived before the receipt)
local decision=Premium.ProcessReceipt(svc,{ProductId=777001,PurchaseId='buy-1',PlayerId=601})
check(decision==R.Enum.ProductPurchaseDecision.PurchaseGranted and held(A)==201 and Data:GetPremium(A).Receipts['buy-1']==true,'a paid Robux receipt at 200 is never lost: granted (201) and saved')
check(Premium.ProcessReceipt(svc,{ProductId=777001,PurchaseId='buy-1',PlayerId=601})==R.Enum.ProductPurchaseDecision.PurchaseGranted and held(A)==201,'(the same receipt again grants nothing more)')
do local r=Data:GetChestRecords(A);while #r<Config.MaxSavedChests do r[#r+1]=seedRow(A)end
 check(Premium.ProcessReceipt(svc,{ProductId=777001,PurchaseId='buy-2',PlayerId=601})==R.Enum.ProductPurchaseDecision.NotProcessedYet,'only the old storage ceiling (1000 records) makes a receipt wait (NotProcessedYet: Roblox asks again, nothing lost)')
end
-- gifts in: a seed / pack and a fruit wait in the inbox while the bag is full
local B=makePlayer(602,'Bo')
local Gifts=server('FruitGiftService');local giftSelf=setmetatable({Data=Data,Chests=Chests,Remote={FireClient=function()end},Busy={},Working={},Offers={},Last={}},{__index=Gifts})
local giftRow=Data:SerializeSeedRecord(Data:AddChest(B,pack()))
fillTo(A,200);local garden=Data.Gardens[A];local receipts={}
check(Gifts._receiveSeed(giftSelf,A,garden,receipts,'gift-1',{Seed=giftRow})==false and held(A)==200 and not receipts['gift-1'],'a gifted pack at 200 stays in the inbox (tried again later)')
check(Gifts.Room(giftSelf,A)==false and Gifts.Room(giftSelf,B)==true,'the giver is told "Their bag is full." (the same room check)')
fillTo(A,199);check(Gifts._receiveSeed(giftSelf,A,garden,receipts,'gift-1',{Seed=giftRow})==true and held(A)==200,'at 199 it arrives')
-- a fruit gift through the inbox (FruitGiftService:_recoverChannel)
local function plant(p,seedId)
 local rec=Data:AddChest(p,pack());local records=Data:GetChestRecords(p);local idx;for i,r in ipairs(records)do if r.Id==rec.Id then idx=i end end
 local row=seedRow(p,seedId);row.Id=rec.Id;records[idx]=row
 return Data:PlantSeed(p,1,rec.Id,{OffsetX=0,OffsetZ=0},os.time())
end
local okP,crop=plant(B,'SunflowerSeed');check(okP,'(a plant)')
local okH,harvested=Data:HarvestPlant(B,1,crop.Id,crop.ReadyAt+5,1);check(okH,'(a real harvest record to gift)')
do
 local store={Data={}};function store:GetAsync(k)return self.Data[k]end;function store:UpdateAsync(k,fn)local v=fn(self.Data[k]);if v~=nil then self.Data[k]=v end;return self.Data[k]end
 local cropRow=table.clone(harvested);cropRow.Id='gift-fruit-1'
 store.Data[tostring(A.UserId)]={['f-1']={State='Ready',From=602,Name='Sunflower',Crop=cropRow}}
 giftSelf.Store=store;local ch={Name='Fruit',Out='OutgoingGifts',Receipts='GiftReceipts',Store='Store',Field='Crop'}
 fillTo(A,200);local before=#Data.Gardens[A].Harvests
 Gifts._recoverChannel(giftSelf,A,ch)
 check(#Data.Gardens[A].Harvests==before and store.Data[tostring(A.UserId)]['f-1'].State=='Ready','a gifted fruit at 200 stays in the inbox')
 fillTo(A,199);Gifts._recoverChannel(giftSelf,A,ch)
 check(#Data.Gardens[A].Harvests==before+1 and held(A)==200,'at 199 it arrives ('..held(A)..')')
end
-- harvesting
do
 fillTo(A,150);local okP2,crop2=plant(A,'SunflowerSeed');fillTo(A,200)
 local okH2,whyH=Data:HarvestPlant(A,1,crop2.Id,crop2.ReadyAt+5,1)
 check(okH2==false and whyH=='BAG FULL - SELL OR PLANT SOMETHING FIRST'and held(A)==200,'harvesting at 200: "'..tostring(whyH)..'", the fruit stays on the plant')
 fillTo(A,199);check((Data:HarvestPlant(A,1,crop2.Id,crop2.ReadyAt+5,1))==true and held(A)==200,'at 199 it is picked')
end
-- the tutorial's starter pack
do local premium=Data:GetPremium(A);premium.StarterPack=nil;premium.Tutorial={Version=1,Mask=0xFFFF,Done=true}
 fillTo(A,200);check(Data:GrantStarterPack(A)==nil and premium.StarterPack~=true,'the starter pack at 200 is not given (tried again later)')
 fillTo(A,199);check(Data:GrantStarterPack(A)~=nil and premium.StarterPack==true,'at 199 it is')
end
-- owner test grants
folder.OwnerCommandAccess:SetAttribute('AdminUserIds','601')
do local Tests=server('RarePackTests')
 fillTo(A,199);local okT,whyT=Tests.Grant(Data,A,'all',A)
 check(okT==false and tostring(whyT):find('200 items max',1,true)~=nil and held(A)==199,'owner test grants count too ('..tostring(whyT)..')')
 check((Data:AddChest(A,pack(),{TestGrant=true}))~=nil and held(A)==200 and Data:AddChest(A,pack(),{TestGrant=true})==nil,'an owner-made pack: 199 -> 200, then refused')
end

-- 3. an old save above 200 loads whole ------------------------------------------------------------------------------------------------------------
do
 local Old=R.new('Player');Old.Name='Oldtimer';Old.DisplayName='Oldtimer';Old.UserId=603;Old.Parent=Players;present[603]=Old;function Old.Kick(_,why)error('kicked: '..tostring(why),0)end;R.new('Backpack').Parent=Old
 local rows={};for i=1,350 do local r=seedRow(Old);if i%2==0 then r.Kind='Pack';r.SeedId=nil;r.ChestName='Seed Pack'end;rows[i]=Data:SerializeSeedRecord(r)end
 local harvests={};for i=1,300 do local h=table.clone(harvested);h.Id='old-fruit-'..i;harvests[i]=h end
 local store=Data.Store;store.Data['Player_603']={Version=Config.ProfileVersion,Seeds=rows,Garden={Version=Config.GardenSchemaVersion,Plots={},Harvests=harvests},Cash=5,SeedInventorySerial=990000,Premium=nil}
 Data:PreparePlayer(Old);local okL=Data:Load(Old);Data.CanSave[Old]=true
 check(okL and #Data:GetChestRecords(Old)==350 and #Data.Gardens[Old].Harvests==300,'a save with 350 packs / seeds and 300 fruit loads whole ('..#Data:GetChestRecords(Old)..' + '..#Data.Gardens[Old].Harvests..')')
 check(Old:GetAttribute('HeldItemCount')==650 and not Data:RoomFor(Old,1),'it holds 650 of 200: nothing is cut, it just receives nothing')
 check(Data:AddChest(Old,pack())==nil and(Chest.Bank(bankSelf,Old,pack()))==nil,'(no pack, no steal)')
 local saved=Data:_buildSaveData(Old);check(#saved.Seeds==350 and #saved.Garden.Harvests==300,'and it saves whole')
 check(Data:DecodeGarden(saved.Garden)~=nil,'the save validator accepts its 300 fruit (old ceiling 500)')
 local okSell,total,count=Data:SellAllHarvests(Old);check(okSell and count==300 and held(Old)==350,'selling the fruit: 350 left')
 Data.Gardens[Old].PendingSales={}
 local r=Data:GetChestRecords(Old);while #r>199 do table.remove(r)end;Data:_notifySeedInventory(Old)
 check(Data:RoomFor(Old,1)and(Data:AddChest(Old,pack()))~=nil and held(Old)==200,'under 200 it receives again (199 -> 200)')
end

-- 4. discarding ---------------------------------------------------------------------------------------------------------------------------------------
local Inventory=server('InventoryService155')
local giftsFake={Busy={}}
local svc155=Inventory.new(Config,Data,Chests,giftsFake,Notes):Start()
local discardRemote=remotes:FindFirstChild('DiscardItems');local layoutRemote=remotes:FindFirstChild('HotbarLayout155')
check(discardRemote and discardRemote:IsA('RemoteFunction')and layoutRemote and layoutRemote:IsA('RemoteEvent'),'the remotes: ChestChaseRemotes.DiscardItems (RemoteFunction), HotbarLayout155 (RemoteEvent)')
local C=makePlayer(604,'Cy')
-- the player's Tools, built from the records the way the server builds them (the attributes the stack key reads)
local function rebuild(p)
 local bp=p:FindFirstChildOfClass('Backpack');local have={}
 for _,c in ipairs({bp,p.Character})do for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')then local id=Stacks.Id(t);local kind=Stacks.Kind(t)
  local alive=false
  if kind=='Pack'or kind=='Seed'then for _,r in ipairs(Data:GetChestRecords(p))do if r.Id==id then alive=true end end
  elseif kind=='Fruit'then for _,h in ipairs(Data.Gardens[p].Harvests)do if h.Id==id then alive=true end end
  elseif kind=='Loot'then alive=p.LootInventory:FindFirstChild(id)~=nil else alive=true end
  if alive then have[id or t]=true else t:Destroy()end end end end
 for _,r in ipairs(Data:GetChestRecords(p))do if not have[r.Id]then
  local t=R.Instance.new('Tool');t.Name=r.Kind=='Pack'and'Forest Seed Pack'or r.ChestName
  if r.Kind=='Pack'then t:SetAttribute('SeedPackTool',true);for _,k in ipairs({'Stage','BagVariant','PackSize','PackMutation','Weather','SeedScale'})do t:SetAttribute(k,r[k])end
  else t:SetAttribute('GardenSeed',true);t:SetAttribute('SeedId',r.SeedId);t:SetAttribute('SeedScale',r.SeedScale);t:SetAttribute('Mutation',r.PackMutation);t:SetAttribute('Weather',r.Weather or'None');t:SetAttribute('Rarity',r.Rarity)end
  t:SetAttribute('SeedInventoryId',r.Id);t.Parent=bp end end
 for _,h in ipairs(Data.Gardens[p].Harvests)do if not have[h.Id]then local t=R.Instance.new('Tool');t.Name='Sunflower';t:SetAttribute('HarvestItemTool',true);t:SetAttribute('HarvestInventoryId',h.Id);t:SetAttribute('SeedId',h.SeedId);t.Parent=bp end end
 for _,v in ipairs(p.LootInventory:GetChildren())do if not have[v.Name]then local t=R.Instance.new('Tool');t.Name=v.Value;t:SetAttribute('LootItemTool',true);t:SetAttribute('LootInstanceName',v.Name);t.Parent=bp end end
end
Chests.Rebuild=rebuild
local shovel=R.Instance.new('Tool');shovel.Name='Shovel';shovel:SetAttribute('GardenShovel',true);shovel:SetAttribute('InventoryKey','shovel');shovel.Parent=C.Backpack
local batT=R.Instance.new('Tool');batT.Name='Bat';batT:SetAttribute('ChestChaseBat',true);batT.Parent=C.Backpack
for _=1,5 do table.insert(Data:GetChestRecords(C),seedRow(C,'SunflowerSeed'))end
local packs={};for i=1,3 do packs[i]=Data:AddChest(C,pack())end
Data:_notifySeedInventory(C);local okP3,crop3=plant(C,'SunflowerSeed');local _,fruit=Data:HarvestPlant(C,1,crop3.Id,crop3.ReadyAt+5,1)
local lootV=Data:AwardLoot(C,1,'Rare','Golden Idol')
rebuild(C)
local function toolOf(id)for _,c in ipairs({C.Backpack,C.Character})do for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')and Stacks.Id(t)==id then return t end end end end
local seedIds={};for _,r in ipairs(Data:GetChestRecords(C))do if r.Kind=='Seed'then seedIds[#seedIds+1]=r.Id end end
local function ask(req)return svc155:Discard(C,req)end
local h0=held(C)
check(h0==10 and C:GetAttribute('HeldItemCount')==10,'(5 seeds + 3 packs + 1 fruit + 1 loot item = 10: '..h0..')')
-- refusals
Data.Loaded[C]=false;local res=ask({Kind='Seed',Id=seedIds[1],Count=1});Data.Loaded[C]=true
check(not res.Ok and res.Message=='HOLD ON, UR DATA IS LOADING!','refused while the data loads')
Data.CanSave[C]=false;res=ask({Kind='Seed',Id=seedIds[1],Count=1});Data.CanSave[C]=true
check(not res.Ok and res.Message:find("CAN'T SAVE",1,true),'refused while the profile can not save')
for _,bad in ipairs({{Kind='Seed',Id=seedIds[1],Count=0},{Kind='Seed',Id=seedIds[1],Count=1.5},{Kind='Seed',Id=string.rep('x',200),Count=1},{Kind='Seed',Count=1},'nope'})do
 res=ask(bad);check(not res.Ok and res.Message=='TRY AGAIN!','a malformed request is refused ('..tostring(type(bad)=='table'and bad.Count or bad)..')')
end
res=ask({Kind='Shovel',Id='shovel',Count=1});check(not res.Ok and res.Message=="U CAN'T THROW THAT AWAY"and shovel.Parent~=nil,'the shovel can not be thrown away')
res=ask({Kind='Tool',Id='Bat',Count=1});check(not res.Ok and res.Message=="U CAN'T THROW THAT AWAY"and batT.Parent~=nil,'nor the bat (gear)')
res=ask({Kind='Seed',Id='C-not-mine',Count=1});check(not res.Ok and res.Message=='THAT ITEM IS ALREADY GONE!','an id the player does not hold: gone')
res=ask({Kind='Pack',Id=seedIds[1],Count=1});check(not res.Ok and res.Message=='TRY AGAIN!','the wrong kind for an id: refused')
C:SetAttribute('ChestChaseSeedCarrying',true);res=ask({Kind='Seed',Id=seedIds[1],Count=1});C:SetAttribute('ChestChaseSeedCarrying',nil)
check(not res.Ok and res.Message=='FINISH UR STEAL FIRST!','refused while carrying a stolen pack')
C:SetAttribute('ChestChaseRunActive',true);res=ask({Kind='Seed',Id=seedIds[1],Count=1});C:SetAttribute('ChestChaseRunActive',nil);check(not res.Ok,'... and in a chase')
giftsFake.Busy[C]=true;res=ask({Kind='Seed',Id=seedIds[1],Count=1});giftsFake.Busy[C]=nil
check(not res.Ok and res.Message=='WAIT FOR UR GIFT TO SEND FIRST!','refused while a gift is being saved')
Chests.Openings[C]={Tool=toolOf(packs[1].Id),Clicks=2};res=ask({Kind='Pack',Id=packs[1].Id,Count=1})
check(not res.Ok and res.Message=='WAIT FOR UR PACK TO FINISH OPENING!','the pack being opened can not be thrown away')
res=ask({Kind='Pack',Id=packs[2].Id,Count=3})
check(not res.Ok and res.Message=="U DON'T HAVE THAT MANY!",'and it does not count in its stack meanwhile (all 3 asked, 2 may go: '..tostring(res.Message)..')')
Chests.Openings[C]={Tool=toolOf(packs[1].Id),Clicks=0} -- (only held: it may go)
Chests.RecentRewards={[C]={[seedIds[5]]=R.clock}} -- (the server's clock)
res=ask({Kind='Seed',Id=seedIds[5],Count=1});check(not res.Ok and res.Message=='WAIT FOR UR SEED TO LAND FIRST!','a reward seed still flying in can not be thrown away')
res=ask({Kind='Seed',Id=seedIds[1],Count=5});check(not res.Ok and res.Message=="U DON'T HAVE THAT MANY!",'... nor counted in its stack (5 asked, 4 may go)')
check(held(C)==h0 and synced>=0,'(every refusal changed nothing: '..held(C)..')')
-- a stack: 3 of the 5 seeds, the one in hand last
R.advance(11)
local inHand=toolOf(seedIds[2]);inHand.Parent=C.Character
res=ask({Kind='Seed',Id=seedIds[2],Count=3})
check(res.Ok and res.Removed==3 and held(C)==h0-3 and C:GetAttribute('HeldItemCount')==h0-3,'3 of a stack of 5: exactly 3 records go, the count drops ('..held(C)..')')
check(inHand.Parent==C.Character and toolOf(seedIds[2])==inHand,'the one in hand is kept while others are left')
local seedsLeft=0;for _,r in ipairs(Data:GetChestRecords(C))do if r.Kind=='Seed'then seedsLeft+=1 end end;check(seedsLeft==2,'2 seeds left')
res=ask({Kind='Seed',Id=seedIds[2],Count=2});check(res.Ok and inHand.Parent==nil,'all of them: the one in hand goes too (put away first)')
-- a pack held but not opened, fruit, a loot item
res=ask({Kind='Pack',Id=packs[1].Id,Count=3});check(res.Ok and res.Removed==3,'the 3 packs (one only held, not opened)')
res=ask({Kind='Fruit',Id=fruit.Id,Count=1});check(res.Ok and #Data.Gardens[C].Harvests==0,'a fruit')
res=ask({Kind='Loot',Id=lootV.Name,Count=1});check(res.Ok and C.LootInventory:FindFirstChild(lootV.Name)==nil,'a loot item')
check(held(C)==0 and C:GetAttribute('HeldItemCount')==0,'nothing left, the count says 0')
check(Data:GetCash(C)==0 and #(Data.Gardens[C].PendingSales or{})==0,'nothing comes back (no cash, no receipt)')
local log=Data.DiscardLog and Data.DiscardLog[C];local outputLine=false;for _,l in ipairs(printed)do if l:find('[R155 Discard] Cy (604): threw away 3x',1,true)then outputLine=true end end
check(log and #log==5 and log[1]:find('threw away 3x',1,true)and outputLine,'each discard is in the Output and kept for /test hotbar ('..(log and #log or 0)..' lines)')
-- after a rejoin they are still gone
do local saved=Data:_buildSaveData(C);Data.Store.Data['Player_604']=saved
 Data:CleanupPlayer(C);present[604]=nil;C.Parent=nil
 local C2=R.new('Player');C2.Name='Cy';C2.UserId=604;C2.Parent=Players;present[604]=C2;R.new('Backpack').Parent=C2;function C2.Kick(_,w)error(w)end
 Data:PreparePlayer(C2);assert(Data:Load(C2))
 check(#Data:GetChestRecords(C2)==0 and #Data.Gardens[C2].Harvests==0 and C2:GetAttribute('HeldItemCount')==0,'after a rejoin the thrown-away items are still gone')
end
-- the remote: the server asks the SecurityGate (rate limit) and answers
do local D=makePlayer(605,'Dee');for _=1,3 do table.insert(Data:GetChestRecords(D),seedRow(D))end;Data:_notifySeedInventory(D)
 local tools={};local function rb()local bp=D.Backpack;for _,r in ipairs(Data:GetChestRecords(D))do if not tools[r.Id]then local t=R.Instance.new('Tool');t.Name=r.ChestName;t:SetAttribute('GardenSeed',true);t:SetAttribute('SeedId',r.SeedId);t:SetAttribute('SeedScale',1);t:SetAttribute('Mutation','None');t:SetAttribute('Weather','None');t:SetAttribute('Rarity','Common');t:SetAttribute('SeedInventoryId',r.Id);t.Parent=bp;tools[r.Id]=t end end end
 rb();local id=Data:GetChestRecords(D)[1].Id
 local reply=discardRemote.OnServerInvoke(D,{Kind='Seed',Id=id,Count=1})
 check(type(reply)=='table'and reply.Ok and held(D)==2,'through the remote: thrown away ('..tostring(reply and reply.Message)..')')
 local refused=0;for _=1,12 do local r=discardRemote.OnServerInvoke(D,{Kind='Seed',Id=id,Count=1});if r.Message=='SLOW DOWN!'then refused+=1 end end
 check(refused>0,'a flood of requests is rate limited ('..refused..' of 12 told to slow down)')
end

-- 5. the saved hotbar layout --------------------------------------------------------------------------------------------------------------------------
do
 local E=makePlayer(606,'Eve')
 check(E:GetAttribute('HotbarLayout155')=='','a player with no saved layout: HotbarLayout155 is "" (the client fills the slots in arrival order)')
 local good='0123abcd,,89abcdef,,,,,,,;3';local GIS=W.module('GardenInventoryState')
 check(GIS.Parse(good)~=nil,'(a valid layout)')
 check(Data:SetHotbarLayout(E,'not a layout')==false and Data:GetPremium(E).Hotbar155==nil,'a malformed layout is refused')
 check(Data:SetHotbarLayout(E,string.rep('a',300))==false,'... and an oversized one')
 Data.Dirty[E]=false;check(Data:SetHotbarLayout(E,good)and Data:GetPremium(E).Hotbar155==good and Data.Dirty[E]==true,'a valid one is kept in Premium.Hotbar155 (saved with the profile)')
 layoutRemote.OnServerEvent:Fire(E,'0123abcd,,,,,,,,,;0');check(Data:GetPremium(E).Hotbar155=='0123abcd,,,,,,,,,;0','through the remote too')
 local saved=Data:_buildSaveData(E);check(type(saved.Premium)=='table'and saved.Premium.Hotbar155=='0123abcd,,,,,,,,,;0','it is in the saved Premium')
 Data.Store.Data['Player_606']=saved;Data:CleanupPlayer(E);present[606]=nil;E.Parent=nil
 local E2=R.new('Player');E2.Name='Eve';E2.UserId=606;E2.Parent=Players;present[606]=E2;R.new('Backpack').Parent=E2;function E2.Kick(_,w)error(w)end
 Data:PreparePlayer(E2);assert(Data:Load(E2))
 check(E2:GetAttribute('HotbarLayout155')=='0123abcd,,,,,,,,,;0','after a rejoin the client gets it back (HotbarLayout155)')
 saved=Data:_buildSaveData(E2);saved.Premium.Hotbar155={broken=true};Data.Store.Data['Player_606']=saved;Data:CleanupPlayer(E2);E2.Parent=nil;present[606]=nil
 local E3=R.new('Player');E3.Name='Eve';E3.UserId=606;E3.Parent=Players;present[606]=E3;R.new('Backpack').Parent=E3;function E3.Kick(_,w)error('kicked: '..tostring(w))end
 Data:PreparePlayer(E3);local okLoad,errLoad=pcall(Data.Load,Data,E3)
 check(okLoad and errLoad==true and E3:GetAttribute('HotbarLayout155')==''and Data:GetPremium(E3).Hotbar155==nil,'a broken saved layout is dropped, never a reason to refuse the save ('..tostring(errLoad)..')')
end
print(('R155 cap / discard / layout server checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
