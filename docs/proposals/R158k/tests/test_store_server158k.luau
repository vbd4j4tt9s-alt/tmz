--!nocheck
-- R158k (owner: "players can't purchase things in the store when their money is sufficient enough" / "it just tells the player not enough cash"): the SERVER half,
-- the source of truth, on the Roblox mock with the REAL Config, PlayerDataService (+ PremiumProgress, GardenFenceData), EconomyService, GardenUpgradeService and
-- StoreMoney158k (the R123 world: run from a folder with roblox.luau, world.luau, rs_bundle.luau and srv_names.luau from treadmill_bonus_R123/tests/mkbundle.py):
--  1. one rule: for every cash price in the game (trails, boots, treadmills, fences, a Gem) and balances one under / equal / one over, SpendCash takes the money
--     exactly when StoreMoney158k.CanAfford (the screens' check) says it pays, and takes it once; the 900T cap pays the 204T Royal Trail
--  2. the market (EconomyService): one cash short = "Not enough cash!" and nothing charged; equal cash buys; buying it again = "YOU ALREADY OWN THIS", charged once;
--     away from the shop / data loading keep their own words
--  3. gems (PremiumProgress): the Mech pack / bundle / pass one gem short = "Not enough gems!" and nothing charged or granted; equal gems buy; Cash to Gems one cash
--     short = "Not enough cash!"; a full Bag is told before the gems ("BAG FULL! MAKE ROOM FIRST")
--  4. the treadmill / fence pads (GardenUpgradeService): one short = the pad's "Not enough cash!", the plain red notice (Denied) and the refused click, nothing
--     charged, the level unchanged; equal cash = green and bought; a double press buys once; max level keeps "Fully upgraded!" (no money notice); the pad and
--     the sign show exactly the cost the press charges
--  5. (owner: "make sure store prices are always the same") a press pays the price its button showed or nothing: the market (EconomyService) and the REAL
--     PremiumService remote (Mech pack, pass, Cash to Gems, bundle) refuse a different shown price with "The price changed! Check the new price.", charge
--     nothing and reply with the server's prices; the right price buys; an older client that sends no price still buys at the server's price
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local present={}
function Players.GetPlayers()local out={};for _,p in pairs(present)do out[#out+1]=p end;return out end
function Players.GetPlayerByUserId(_,id)return present[id]end
local guid=0;local Http=W.service('HttpService');function Http.GenerateGUID()guid+=1;return 'guid-'..guid end
local DS=W.service('DataStoreService');local stores={}
local function dsCopy(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=dsCopy(x)end;return o end
function DS.GetDataStore(_,name)
 stores[name]=stores[name]or{Data={},UpdateAsync=function(self,key,fn)local v=fn(dsCopy(self.Data[key]),nil);if v~=nil then self.Data[key]=dsCopy(v)end;return dsCopy(self.Data[key])end,
  GetAsync=function(self,key)return dsCopy(self.Data[key])end,SetAsync=function(self,key,v)self.Data[key]=dsCopy(v)end}
 return stores[name]
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
W.env.bit32=bit32
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent)
 if class=='RemoteEvent'then o.OnServerEvent=R.signal();o.OnClientEvent=R.signal();o.FireClient=function()end end
 if class=='ClickDetector'then o.MouseClick=R.signal()end
 if class=='ProximityPrompt'then o.Triggered=R.signal()end
 return o end end
R.clock=20727*86400+3600*5
local Config=server('Config')
local hasMoney,Money=pcall(W.module,'StoreMoney158k');if not hasMoney then Money=nil end
check(Money~=nil,'0: StoreMoney158k exists')
local CASH,GEMS,PRICE='Not enough cash!','Not enough gems!','The price changed! Check the new price.'
local MAIN=coroutine.running()
local Red=W.module('SimpleGameText').Red
local Map={GetStageAccent=function()return R.Color3.new(.5,.5,.5)end}
local notes={}
local Notes={Show=function(_,p,msg,color,seconds,kind)notes[#notes+1]={P=p,Text=msg,Color=color,Seconds=seconds,Kind=kind}end}
local Data=server('PlayerDataService').new(Config,Map,Notes)
local ids=500
local function makePlayer(name)
 ids+=1;local p=R.new('Player');p.Name=name;p.DisplayName=name;p.UserId=ids;p.Parent=Players;present[ids]=p
 function p.Kick(_,why)error('kicked '..name..': '..tostring(why),0)end
 R.new('Backpack').Parent=p;p:SetAttribute('PaidRandomAllowed',true)
 Data:PreparePlayer(p);assert(Data:Load(p),'load '..name)
 local char=R.new('Model');char.Name=name;char.Parent=W.workspace;p.Character=char
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=R.CFrame.new(0,3,0);root.Parent=char
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
 return p,root
end
local function cash(p)return Data:GetCash(p)end
local function setCash(p,n)Data:GetOrCreateCashValue(p).Value=n end
local E=W.module('EconomyBalance90');local Mech=W.module('MechCatalog')

-- 1. one rule ------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local P=makePlayer('Rule')
 local prices={Mech.CashPerGem}
 for _,list in ipairs({E.TrailCosts,E.BootCosts,E.MachineCosts,E.FenceCosts})do for _,v in pairs(list)do if v>0 then prices[#prices+1]=v end end end
 for _,t in ipairs(Config.TreadmillTiers)do if t.Cost>0 then prices[#prices+1]=t.Cost end end
 for _,c in ipairs(Config.ShopCatalog.Trails)do prices[#prices+1]=c.Price end;for _,c in ipairs(Config.ShopCatalog.Accessories)do prices[#prices+1]=c.Price end
 local disagree,wrongCharge=0,0
 for _,price in ipairs(prices)do for _,d in ipairs({-1,0,1})do
  local balance=price+d;setCash(P,balance)
  local took=Data:SpendCash(P,price)
  local says=Money and Money.CanAfford(balance,price)or not Money and balance>=price -- (before R158k the screens' rule was cash >= price: the old code is measured with it)
  if took~=says then disagree+=1;print('  disagree: balance '..balance..' price '..price..' server '..tostring(took)..' rule '..tostring(says))end
  if cash(P)~=(took and balance-price or balance)then wrongCharge+=1 end
 end end
 check(disagree==0,'1: the server takes the money exactly when the screens\' rule says it pays ('..#prices..' prices x 3 balances; '..disagree..' disagree)')
 check(wrongCharge==0,'1: ... and takes it once, exactly the price ('..wrongCharge..' wrong)')
 setCash(P,E.MaxCash);check(Data:SpendCash(P,E.TrailCosts.RoyalTrail)and cash(P)==E.MaxCash-E.TrailCosts.RoyalTrail,'1: the 900T cap pays the 204T Royal Trail, exact')
 setCash(P,5);check(Data:SpendCash(P,0)==false and Data:SpendCash(P,-3)==false and Data:SpendCash(P,0/0)==false and cash(P)==5,'1: a price of 0 / negative / NaN is never "bought"')
end

-- 2. the market --------------------------------------------------------------------------------------------------------------------------------------------------
do
 local station=R.new('Part');station.Name='BuyStation';station.CFrame=R.CFrame.new(0,3,0);station.Parent=W.workspace
 local sell=R.new('Part');sell.Name='SellStation';sell.CFrame=R.CFrame.new(0,3,0);sell.Parent=W.workspace
 local MapE={BuyStation=station,SellStation=sell,BuyPrompt={Triggered=R.signal()},SellPrompt={Triggered=R.signal()},BaseRecords={}}
 local econ=server('EconomyService').new(Config,MapE,Data,{GetPlayerBase=function()return nil end},{},{IsPlayerBusy=function()return false end},Notes)
 econ.ApplyCosmetics=function()end -- (the trail art is not what is tested here)
 local P,root=makePlayer('Buyer')
 local arc;for _,c in ipairs(Config.ShopCatalog.Trails)do if c.Id=='ArcTrail'then arc=c end end
 setCash(P,arc.Price-1)
 local r=econ:_purchase(P,'ArcTrail')
 check(r.Success==false and r.Message==CASH,'2: one cash short of the Arc Trail: "Not enough cash!" ('..tostring(r.Message)..')')
 check(cash(P)==arc.Price-1 and not Data:OwnsBoost(P,'ArcTrail'),'2: ... nothing charged, not owned')
 setCash(P,arc.Price);r=econ:_purchase(P,'ArcTrail')
 check(r.Success==true and cash(P)==0 and Data:OwnsBoost(P,'ArcTrail'),'2: exactly its price buys it (cash 0, owned)')
 setCash(P,arc.Price);r=econ:_purchase(P,'ArcTrail')
 check(r.Success==false and r.Message=='YOU ALREADY OWN THIS'and cash(P)==arc.Price,'2: buying it again (a replayed click) = "YOU ALREADY OWN THIS", charged once ('..tostring(r.Message)..')')
 root.CFrame=R.CFrame.new(0,3,100);setCash(P,0)
 r=econ:_purchase(P,'SolarTrail')
 check(r.Success==false and r.Message=='VISIT THE BUY STATION FIRST','2: away from the shop keeps its own words, even with no cash ('..tostring(r.Message)..')')
 root.CFrame=R.CFrame.new(0,3,0)
 Data.Loaded[P]=false;r=econ:_purchase(P,'SolarTrail');Data.Loaded[P]=true
 check(r.Success==false and r.Message=='PLAYER DATA IS STILL LOADING','2: data loading keeps its own words ('..tostring(r.Message)..')')
 -- the price shown: the press pays it or nothing
 local solar;for _,c in ipairs(Config.ShopCatalog.Trails)do if c.Id=='SolarTrail'then solar=c end end
 setCash(P,solar.Price);r=econ:_purchase(P,'SolarTrail',solar.Price-1)
 local listed;for _,q in ipairs(type(r.Products)=='table'and r.Products.Trails or{})do if q.Id=='SolarTrail'then listed=q.Price end end
 check(r.Success==false and r.Message==PRICE and cash(P)==solar.Price and not Data:OwnsBoost(P,'SolarTrail'),'2: a press showing another price: "The price changed! Check the new price.", nothing charged ('..tostring(r.Message)..')')
 check(listed==solar.Price,'2: ... and the reply carries the shop\'s price for the window ('..tostring(listed)..')')
 r=econ:_purchase(P,'SolarTrail',solar.Price);check(r.Success==true and cash(P)==0,'2: a press showing the right price buys it for exactly that')
 -- the boots: the $5.48B pair at exactly its price
 local boots=Config.ShopCatalog.Accessories[3];setCash(P,boots.Price)
 r=econ:_purchase(P,boots.Id);check(r.Success==true and cash(P)==0,'2: '..boots.Name..' at exactly $'..boots.Price..' buys')
end

-- 3. gems ----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local P=makePlayer('Gemmy');local state=Data:GetPremium(P)
 local function packs()local n=0;for _,r in ipairs(Data:GetChestRecords(P))do if r.Stage==8 then n+=1 end end;return n end
 local price=Mech.Offer(1).GemPrice
 state.Gems=price-1;local ok,msg=Data:BuyMechPack(P,1)
 check(ok==false and msg==GEMS and state.Gems==price-1 and packs()==0,'3: one gem short of the Mech pack: "Not enough gems!", nothing charged or granted ('..tostring(msg)..')')
 state.Gems=price;ok,msg=Data:BuyMechPack(P,1)
 check(ok==true and state.Gems==0 and packs()==1,'3: exactly '..price..' gems buys it')
 local bundle=W.module('PremiumPricing').Find('SpeedSmall')
 state.Gems=bundle.GemPrice-1;ok,msg=Data:BuyPremiumBundle(P,'SpeedSmall')
 check(ok==false and msg==GEMS and state.Gems==bundle.GemPrice-1,'3: one gem short of a bundle: "Not enough gems!" ('..tostring(msg)..')')
 state.Gems=bundle.GemPrice;ok,msg=Data:BuyPremiumBundle(P,'SpeedSmall');check(ok==true and state.Gems==0,'3: exactly its price buys the bundle')
 Data.PassOwnership=function()return false end -- (Roblox says the player does not own it)
 local pp=Mech.PassGemPrices.Growth
 state.Gems=pp-1;ok,msg=Data:BuyGemPerk(P,'Growth')
 check(ok==false and msg==GEMS and state.Gems==pp-1 and not state.Entitlements.Growth,'3: one gem short of a pass: "Not enough gems!" ('..tostring(msg)..')')
 state.Gems=pp;ok,msg=Data:BuyGemPerk(P,'Growth');check(ok==true and state.Gems==0 and state.Entitlements.Growth==true,'3: exactly its price buys the pass')
 setCash(P,Mech.CashPerGem-1);ok,msg=Data:ConvertGems(P,1)
 check(ok==false and msg==CASH and cash(P)==Mech.CashPerGem-1,'3: Cash to Gems one cash short: "Not enough cash!", nothing charged ('..tostring(msg)..')')
 setCash(P,Mech.CashPerGem);ok,msg=Data:ConvertGems(P,1);check(ok==true and cash(P)==0,'3: exactly $1T converts 1 Gem')
 ok,msg=Data:ConvertGems(P,1);check(ok==false and msg==CASH and cash(P)==0,'3: converting again (a replayed click) with $0: "Not enough cash!", charged once')
 -- a full Bag is told first
 local cap=Data.HeldItemCap;Data.HeldItemCap=function()return 0 end
 state.Gems=0;ok,msg=Data:BuyMechPack(P,1);Data.HeldItemCap=cap
 check(ok==false and msg=='BAG FULL! MAKE ROOM FIRST','3: a full Bag says "BAG FULL! MAKE ROOM FIRST" before the gems ('..tostring(msg)..')')
end

-- 4. the treadmill / fence pads -----------------------------------------------------------------------------------------------------------------------------------
do
 local U=server('GardenUpgradeService');local Fence=W.module('GardenFenceRules')
 local P,root=makePlayer('Upgrader')
 local baseModel=R.new('Model');baseModel.Name='Base1';baseModel.Parent=W.workspace
 local pad=R.new('Part');pad.Name='Pad';pad.Size=R.Vector3.new(40,1,40);pad.CFrame=R.CFrame.new(0,0,0);pad.Parent=baseModel
 local record={Index=1,Model=baseModel}
 local base={GardenUpgradeRecords={},BaseOwners={P},Config=Config,BusyChecker=function()return false end,GetPlayerBase=function()return record end,RefreshTreadmill=function()end,PlayerData=Data,Notifications=Notes}
 local ok,err=pcall(U.Refresh,base,P);check(ok,'4: the pads build on the mock ('..tostring(err)..')')
 local function row(kind)return base.GardenUpgradeRecords[1].Buttons[kind]end
 local function press(kind)
  R.advance(1) -- (past the .65 s press limit and the .34 s settle)
  local b=row(kind);root.CFrame=R.CFrame.new(b.Cap.Position.X,b.Cap.Position.Y+3,b.Cap.Position.Z)
  notes={};local before=P:GetAttribute('UpgradeRefusedSerial')or 0
  b.Prompt.Triggered:Fire(P)
  return (P:GetAttribute('UpgradeRefusedSerial')or 0)-before
 end
 for _,kind in ipairs({'Treadmill','Fence'})do
  local function level()return kind=='Fence'and Data:GetFenceTier(P)or Data:GetTreadmillData(P).Tier end
  local cost=kind=='Fence'and Fence.Tiers[level()+1].Cost or Config.TreadmillTiers[level()+1].Cost
  setCash(P,cost-1)
  check(row(kind).Cap:GetAttribute('Affordable')==false,'4: '..kind..': one short, the pad is red (Affordable false)')
  local refused=press(kind)
  check(refused==1 and level()==1 and cash(P)==cost-1,'4: '..kind..': one short: refused (the Denied click), level 1, nothing charged')
  check(row(kind).Note.Text==CASH and row(kind).Note.Visible,'4: '..kind..': the pad says "Not enough cash!" ('..tostring(row(kind).Note.Text)..')')
  check(#notes==1 and notes[1].P==P and notes[1].Text==CASH and notes[1].Color==Red and notes[1].Kind=='Denied','4: '..kind..': ... and the plain red notice "Not enough cash!" (the one every store shows) ('..tostring(notes[1]and notes[1].Text)..')')
  setCash(P,cost)
  check(row(kind).Cap:GetAttribute('Affordable')==true,'4: '..kind..': exactly its price, the pad turns green (the server\'s own rule)')
  refused=press(kind)
  check(refused==0 and level()==2 and cash(P)==0 and #notes==0,'4: '..kind..': exactly $'..cost..' buys level 2 (cash 0, no notice)')
  -- a double press: the second inside .65 s does nothing; the second level is charged once
  local cost3=kind=='Fence'and Fence.Tiers[3].Cost or Config.TreadmillTiers[3].Cost
  setCash(P,cost3*2);R.advance(1);local b=row(kind);b.Prompt.Triggered:Fire(P);b.Prompt.Triggered:Fire(P)
  check(level()==3 and cash(P)==cost3,'4: '..kind..': a double press buys one level, charged once ('..level()..', $'..cash(P)..')')
 end
 -- the pad and the sign show exactly the cost the press charges (every level)
 local signs={}
 for level=1,#Config.TreadmillTiers-1 do
  local t=Data:GetTreadmillData(P);t.Tier=level;Data:PublishTreadmillData(P);R.advance(1);pcall(U.Refresh,base,P)
  local cost=Config.TreadmillTiers[level+1].Cost;local st=base.GardenUpgradeRecords[1]
  local signText=st.Sign and st.Sign.Text.Price.Text
  if not(W.module('CashNumbers').Reads(row('Treadmill').Price.Text,cost)and(signText==nil or W.module('CashNumbers').Reads(signText,cost)))then signs[#signs+1]=level..': '..row('Treadmill').Price.Text..' / '..tostring(signText)end
 end
 check(#signs==0,'4: every treadmill level: the pad and the sign show exactly the next cost ('..#signs..' wrong, e.g. '..tostring(signs[1])..')')
 do -- a cost the sign's short form cannot write (11,950,000 would read "12M"): the sign writes it in full
  local t=Data:GetTreadmillData(P);t.Tier=2;Data:PublishTreadmillData(P);local keep=Config.TreadmillTiers[3].Cost;Config.TreadmillTiers[3].Cost=11950000
  R.advance(1);pcall(U.Refresh,base,P);local st=base.GardenUpgradeRecords[1];local signText=st.Sign and st.Sign.Text.Price.Text
  check(signText=='$11,950,000'and row('Treadmill').Price.Text=='$11,950,000','4: a cost that is not short reads in full on the sign and the pad ('..tostring(signText)..' / '..row('Treadmill').Price.Text..')')
  Config.TreadmillTiers[3].Cost=keep
 end
 -- max level: its own words, no money notice
 local t=Data:GetTreadmillData(P);t.Tier=#Config.TreadmillTiers;Data:PublishTreadmillData(P);setCash(P,0)
 R.advance(1);pcall(U.Refresh,base,P)
 press('Treadmill')
 check(row('Treadmill').Note.Text=='Fully upgraded!'and #notes==0,'4: max level keeps "Fully upgraded!" and shows no money notice ('..tostring(row('Treadmill').Note.Text)..')')
end

-- 5. a press pays the price its button showed or nothing (the REAL PremiumService remote) -------------------------------------------------------------------------
do
 -- (PremiumService starts loops that wait: a waiting thread parks, the test thread never waits)
 W.env.task=setmetatable({wait=function(t)if coroutine.running()~=MAIN and coroutine.isyieldable()then coroutine.yield()end;return t or 0 end},{__index=R.task})
 local Market=W.service('MarketplaceService');Market.GetProductInfoAsync=function()return nil end;Market.UserOwnsGamePassAsync=function()return false end
 local ok,svc=pcall(function()return server('PremiumService').new(Data,{SyncTools=function()end},{Refresh=function()end})end)
 check(ok,'5: the real PremiumService builds on the mock ('..tostring(ok or svc)..')')
 if ok then
  local P=makePlayer('Shown');local st=Data:GetPremium(P);st.Gems=100000;Data.PassOwnership=function()return false end
  local function invoke(action,value,shown)R.advance(1);return svc.Remote.OnServerInvoke(P,action,value,shown)end
  local g=st.Gems
  local r=invoke('BuyPack',1,79)
  check(r.Success==false and r.Message==PRICE and st.Gems==g and r.PackOffers['1'].GemPrice==80,'5: a Mech pack press showing 79 (the server charges 80): refused, nothing charged, the reply carries 80 ('..tostring(r.Message)..')')
  r=invoke('BuyPack',1,80);check(r.Success==true and st.Gems==g-80,'5: showing 80: bought for 80')
  r=invoke('BuyPack',1);check(r.Success==true and st.Gems==g-160,'5: an older client that sends no price still buys, at the server\'s price')
  r=invoke('BuyPerk','Speed',399)
  check(r.Success==false and r.Message==PRICE and not st.Entitlements.Speed and type(r.PassGemPrices)=='table'and r.PassGemPrices.Speed==400,'5: a pass showing 399 (it is 400): refused, the reply carries the pass prices')
  r=invoke('BuyPerk','Speed',400);check(r.Success==true and st.Entitlements.Speed==true,'5: showing 400: bought')
  setCash(P,5*Mech.CashPerGem);r=invoke('Convert',2,2*Mech.CashPerGem-1)
  check(r.Success==false and r.Message==PRICE and cash(P)==5*Mech.CashPerGem,'5: CONVERT showing another cost: refused, nothing charged')
  r=invoke('Convert',2,2*Mech.CashPerGem);check(r.Success==true and cash(P)==3*Mech.CashPerGem,'5: CONVERT showing $2T: converted for exactly $2T')
  local quote=Data:BundleQuote(P,'SpeedSmall');g=st.Gems
  r=invoke('BuyBundle',{Key='SpeedSmall',Amount=quote.Amount,GemPrice=quote.GemPrice},quote.GemPrice+1)
  check(r.Success==false and r.Message==PRICE and st.Gems==g,'5: a bundle press showing another price: refused, nothing charged')
  r=invoke('BuyBundle',{Key='SpeedSmall',Amount=quote.Amount,GemPrice=quote.GemPrice},quote.GemPrice);check(r.Success==true and st.Gems==g-quote.GemPrice,'5: showing its quote: bought for it')
  -- the price is the same for every player and every request: one server, one catalog
  local Q=makePlayer('Other');local a=invoke('State');local b=svc.Remote.OnServerInvoke(Q,'State')
  local same=a.PackOffers['1'].GemPrice==b.PackOffers['1'].GemPrice and a.PassGemPrices==b.PassGemPrices and a.CashPerGem==b.CashPerGem
  check(same,'5: two players are shown the same prices')
 end
 W.env.task=R.task
end

print(('R158k store server: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
