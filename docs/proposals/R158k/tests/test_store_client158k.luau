--!nocheck
-- R158k (owner: "there are some bugs in the game where players can't purchase things in the store when their money is sufficient enough", then "if clicking
-- on something and players don't have enough money, it just tells the player not enough cash"): the CLIENT half, on the Roblox mock with the REAL scripts
-- (run from a folder with roblox.luau, world.luau (inventory_R113) and rs_bundle.luau holding every ReplicatedStorage module + EconomyClient + GamePassClient):
--  A. the shared rule (StoreMoney158k): equal money pays, one short does not, exact at any size (digit strings past 2^53, "1e+20"), a non-amount is "not known";
--     the words; the server's old and new refusals read as money; a balance is only known once the profile has loaded
--  B. the money on screen: the HUD wallet (GardenWallet) and the market's Cash line never read MORE than the player has, a price never reads LESS than it costs
--     (CashNumbers.Balance / Price): whenever the screen shows a balance at or over a price, that balance really pays it (every real price in the game)
--  C. the market (the real EconomyClient + ShopMenu): every Buy button reads its price and can be pressed; a press the cash cannot pay shows "Not enough cash!"
--     (the plain notice, the Denied click) and sends nothing; equal cash sends the purchase; the server's money refusal is the same notice (not the status line);
--     an older reply's Cash never overrides the live Cash stat; while the profile loads the server decides; other reasons ("Visit shop", owned) keep their words;
--     a double click sends one purchase; during the sale coins' flight the button follows the HUD
--  D. the shop (the real GamePassClient): the gem buttons (Mech pack, bundles, passes) and CONVERT say "Not enough gems!" / "Not enough cash!" for a press the
--     money cannot pay (nothing sent), send it at equal money, show the server's money refusal as the same notice; a full Bag is still told first; Robux is untouched
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local RS=W.RS
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local player=R.new('Player');player.Name='Buyer';player.DisplayName='Buyer';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
player.CharacterRemoving=R.signal();player.CharacterAdded=R.signal()
function Players.GetPlayers()return {player}end
function Players.GetPlayerFromCharacter()return nil end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
for _,k in ipairs({'Growth','Speed','Clover'})do player:SetAttribute(k..'OwnershipReady',true)end
-- the player's stats as the server publishes them: ChestChaseStats.Cash (an IntValue) and the Gems attribute
local stats=R.new('Folder');stats.Name='ChestChaseStats';stats.Parent=player
local cashValue=R.new('IntValue');cashValue.Name='Cash';cashValue.Value=0;cashValue.Parent=stats
local function setCash(n)cashValue.Value=n end
player:SetAttribute('DataStatus','Loaded')
-- what the player hears and sees: the Denied click, the plain notices
local played,notices={},{}
W.stub('InteractionAudio',{Transaction=function()end,Play=function(name)played[#played+1]=name end,Preload=function()end})
W.stub('NoticeFeed83',{Plain=function(text,color,seconds)notices[#notices+1]={Text=text,Color=color,Seconds=seconds}end,Preload=function()end,Push=function()end})
W.stub('ShopViewport',{Visible=function()return true end,CachedVisible=function()return true end,Attach=function()end})
W.stub('ShopSeedReveal',{Attach=function()return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)
 local halo=R.Instance.new('Frame');halo.Name='MechDockingBay';halo.Parent=parent
 local v=R.Instance.new('ViewportFrame');v.Name='MechPackPreview';v.Parent=parent;return v end})
local function noticed(text)for _,n in ipairs(notices)do if n.Text==text then return true end end;return false end
local function reset()played={};notices={};R.advance(1)end -- (a second notice of the same words waits .7 s)
local Red=W.module('SimpleGameText').Red
local Cash=W.module('CashNumbers')
local Balance,Price=Cash.Balance or Cash.Compact,Cash.Price or Cash.Compact -- (before R158k there was only Compact: the old code is measured with it)
local hasMoney,Money=pcall(W.module,'StoreMoney158k')
if not hasMoney then Money=nil end
check(Money~=nil,'A: the shared rule StoreMoney158k exists ('..tostring(hasMoney and''or Money)..')')

-- A. the shared rule -------------------------------------------------------------------------------------------------------------------------------------------
if Money then
 check(Money.Cash=='Not enough cash!'and Money.Gems=='Not enough gems!','A: the words are "Not enough cash!" / "Not enough gems!"')
 check(Money.CanAfford(10400000,10400000)==true and Money.CanAfford(10399999,10400000)==false and Money.CanAfford(10400001,10400000)==true,'A: equal money pays, one short does not')
 check(Money.CanAfford(0,0)==true and Money.CanAfford(0,1)==false,'A: 0 pays 0, not 1')
 check(Money.CanAfford(204000000000000,204000000000000)==true and Money.CanAfford(203999999999999,204000000000000)==false,'A: the Royal Trail (204T) at exactly 204T pays, one short does not')
 check(Money.CanAfford(9007199254740993,9007199254740992)==true,'A: numbers past 2^53 compare like the server (the same doubles)')
 check(Money.CanAfford('9007199254740993','9007199254740992')==true and Money.CanAfford('9007199254740992','9007199254740993')==false,'A: digit strings past 2^53 are exact (one apart)')
 check(Money.CanAfford('100000000000000000000000001','100000000000000000000000000')==true and Money.CanAfford('99999999999999999999999999','100000000000000000000000000')==false,'A: 27-digit strings are exact')
 check(Money.CanAfford('1e+20',100000000000000000000)==true and Money.CanAfford('1e+20','100000000000000000001')==false,'A: "1e+20" is 10^20 (equal pays, one more does not)')
 check(Money.CanAfford('000123',123)==true and Money.CanAfford(123,'00124')==false,'A: leading zeros do not change an amount, a string and a number compare as amounts (not as text)')
 check(Money.CanAfford(9,'10')==false and Money.CanAfford('9',10)==false and Money.CanAfford('10',9)==true,'A: "9" < "10" as amounts (text order would say otherwise)')
 check(Money.CanAfford(10.9,10)==true and Money.CanAfford(9.99,10)==false,'A: a fractional balance is floored (9.99 does not pay 10)')
 check(Money.CanAfford(nil,1)==nil and Money.CanAfford(0/0,1)==nil and Money.CanAfford(math.huge,1)==nil and Money.CanAfford(-5,1)==nil and Money.CanAfford('abc',1)==nil and Money.CanAfford(5,nil)==nil,'A: nil / NaN / inf / negative / a word are "not known" (nil)')
 check(Money.Whole(-0)=='0'and Money.Whole(0.5)=='0'and Money.Whole(1e20)=='100000000000000000000','A: Whole(-0) = "0", Whole(.5) = "0", Whole(1e20) exact')
 check(Money.Refusal('Not enough cash!')=='Cash'and Money.Refusal('NOT ENOUGH CASH')=='Cash'and Money.Refusal('Not enough gems!')=='Gems'and Money.Refusal('NOT ENOUGH GEMS')=='Gems'and Money.Refusal('Not enough Gems!')=='Gems','A: the money refusals (new and older words) read as money')
 check(Money.Refusal('BAG FULL! MAKE ROOM FIRST')==nil and Money.Refusal('YOU ALREADY OWN THIS')==nil and Money.Refusal('Fully upgraded!')==nil and Money.Refusal('TRY AGAIN IN A SEC!')==nil and Money.Refusal(nil)==nil,'A: other refusals (Bag full, owned, max level, wait) are not money')
 setCash(500);player:SetAttribute('Gems',7)
 check(Money.Balance(player,'Cash')==500 and Money.Balance(player,'Gems')==7,'A: the balance is the HUD\'s: the Cash stat and the Gems attribute')
 player:SetAttribute('DataStatus','Loading')
 check(Money.Balance(player,'Cash')==nil and Money.Balance(player,'Gems')==nil and Money.Short(player,'Cash',10^12)==false,'A: while the profile loads the balance is not known (the screen never says "not enough" then)')
 player:SetAttribute('DataStatus','Loaded')
 check(Money.Short(player,'Cash',501)==true and Money.Short(player,'Cash',500)==false and Money.Short(player,'Gems',8)==true and Money.Short(player,'Gems',7)==false,'A: Short = known and too small')
 reset();check(Money.Notice('Cash')==true and noticed('Not enough cash!')and notices[1].Color==Red and played[1]=='Denied','A: the notice is the plain red "Not enough cash!" with the Denied click')
 check(Money.Notice('Cash')==false and #notices==1 and #played==2,'A: a second press inside .7 s clicks Denied again but shows no second notice')
 reset();Money.Notice('Gems');check(noticed('Not enough gems!'),'A: "Not enough gems!" for gems')
end

-- B. the money on screen ---------------------------------------------------------------------------------------------------------------------------------------
local function parse(text) -- "$10.3M" / "Buy  $10.4M" / "Cash  $999.9B" -> the number it shows (exact: whole part and decimals apart)
 local s=text:gsub('[^%d%.MBTQa]','');local whole,frac,suffix=s:match('^(%d+)%.?(%d*)(%a*)$')
 if not whole then return nil end
 local mult=({['']=1,M=1e6,B=1e9,T=1e12,Qa=1e15})[suffix];if not mult then return nil end
 return tonumber(whole)*mult+(frac~=''and tonumber(frac)*mult/10^#frac or 0)
end
local function flat(text)return(tostring(text):gsub('%s+',' '))end -- (GardenTextFit re-wraps a label's words)
local E=W.module('EconomyBalance90')
local prices={}
local function add(list)for _,p in pairs(list)do if p>0 then prices[#prices+1]=p end end end
add(E.TrailCosts);add(E.BootCosts);add(E.MachineCosts);add(E.FenceCosts)
local Mech=W.module('MechCatalog');prices[#prices+1]=Mech.CashPerGem;prices[#prices+1]=Mech.CashPerGem*900
table.sort(prices)
local Wallet=W.module('GardenWallet')
local hud=R.new('ScreenGui');hud.Name='HudTest';hud.Parent=pg
local okWallet,wallet=pcall(Wallet.new,hud);check(okWallet,'B: the real GardenWallet builds ('..tostring(okWallet or wallet)..')')
local function walletShows(n)wallet:SetValue(n);return wallet.Amount.Text end
local badPairs,shownBad={},{}
local steps={1,2,49999,50000,50001,99999,4999999,5e9,49e9,2.5e10,5e10,2.5e11}
if okWallet then
 for _,p in ipairs(prices)do
  local priceText=Price(p)
  check(parse(priceText)==p,'B: the price '..p..' reads exactly ("'..priceText..'"; Compact said "'..Cash.Compact(p)..'")')
  for _,d in ipairs(steps)do local b=p-d;if b>=0 then
   local shown=walletShows(b)
   if parse(shown)>b then shownBad[#shownBad+1]=b..' reads '..shown end
   if parse(shown)>=parse(priceText)and b<p then badPairs[#badPairs+1]='$'..b..' reads "'..shown..'" beside the price "'..priceText..'" ('..p..')'end
  end end
  -- at exactly the price the HUD reads the price's own words; one short it reads less (above)
  check(walletShows(p)==('$'..priceText),'B: exactly '..p..' on the HUD reads the same as the price ("'..walletShows(p)..'" / "'..priceText..'")')
 end
 check(#shownBad==0,'B: the HUD never shows more cash than the player has ('..#shownBad..' cases, e.g. '..tostring(shownBad[1])..')')
 check(#badPairs==0,'B: the HUD never shows a balance at or over a price it cannot pay ('..#badPairs..' cases, e.g. '..tostring(badPairs[1])..')')
 check(walletShows(10350000)=='$10.3M','B: the owner\'s case: $10,350,000 reads "$10.3M" (it read "$10.4M" beside the $10.4M Arc Trail) ('..walletShows(10350000)..')')
 check(walletShows(999999999999)=='$999.9B','B: one short of a Gem (1T) reads "$999.9B", not "$1T" ('..walletShows(999999999999)..')')
 check(walletShows(1750000000000)=='$1.75T','B: $1.75T reads "$1.75T" beside the $1.8T Crystal Boots (it read "$1.8T") ('..walletShows(1750000000000)..')')
 check(walletShows(5479999999)=='$5.47B'and walletShows(5480000000)=='$5.48B'and Price(5480000000)=='5.48B','B: the Lava Boots ($5.48B): one short reads "$5.47B", exactly reads "$5.48B" like its button (Compact read both "5.5B")')
 check(walletShows(250000)=='$250000'and walletShows(0)=='$0'and walletShows(1000000)=='$1M','B: under a million the HUD is exact as before; $1,000,000 reads $1M')
 wallet.Gems:SetValue(999999);check(wallet.Gems.Amount.Text=='999999','B: Gems under a million are exact ('..wallet.Gems.Amount.Text..')')
 -- every price in the game keeps Compact's look, except the two that need a second decimal to read exactly ($5.48B was "5.5B", $1.56T was "1.6T")
 local changed={};for _,p in ipairs(prices)do if Price(p)~=Cash.Compact(p)then changed[#changed+1]=Price(p)end end
 table.sort(changed);check(table.concat(changed,' ')=='1.56T 5.48B','B: only $5.48B and $1.56T read differently from before (now exact) ('..table.concat(changed,' ')..')')
end
if Cash.Balance and Cash.Price then
 check(Cash.Balance('123456789012345678901234')=='123456789Qa'and Cash.Price('123456789012345678901234')=='123,456,789,012,345,678,901,234','B: digit strings: Balance rounds down, a price that is not short is written in full, exact at any size ('..Cash.Balance('123456789012345678901234')..' / '..Cash.Price('123456789012345678901234')..')')
 check(Cash.Price(999999999)=='999,999,999'and Cash.Balance(999999999)=='999.9M'and Cash.Price(10350001)=='10,350,001'and Cash.Price(999900000)=='999.9M'and Cash.Price(5480000000)=='5.48B','B: a price is never rounded: short only when exact ($999.9M, $5.48B), else in full ($999,999,999, $10,350,001)')
 check(Cash.Reads('11.9M',11900000)and Cash.Reads('250K',250000)and Cash.Reads('$1,200',1200)and Cash.Reads('5.48B',5480000000)and Cash.Reads('750000',750000)and not Cash.Reads('12M',11950000)and not Cash.Reads('11.9M',11900001)and not Cash.Reads('abc',1),'B: Reads tells an exact short price from a rounded one')
 check(Cash.Balance(-5)=='0'and Cash.Price(0/0)=='0'and Cash.Balance(10.9)=='10'and Cash.Price(10.1)=='11','B: odd input: negative / NaN read 0, a fractional balance rounds down and a fractional price up')
end

-- C. the market: the real EconomyClient + ShopMenu -------------------------------------------------------------------------------------------------------------
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local function rf(name)local r=R.new('RemoteFunction');r.Name=name;r.Parent=remotes;return r end
local function re(name)local r=R.new('RemoteEvent');r.Name=name;r.OnClientEvent=R.signal();r.Parent=remotes;return r end
do local f=R.new('Folder');f.Name='SeedArt';f.Parent=remotes end
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
local PPS=W.service('ProximityPromptService');PPS.PromptTriggered=R.signal()
local Http=W.service('HttpService');function Http.GenerateGUID()return 'g'end
W.service('ContextActionService').BindActionAtPriority=function()end
W.UIS.TouchTapInWorld=R.signal();function W.UIS.GetMouseLocation()return R.Vector2.new(0,0)end
-- (EconomyClient's two endless polling loops park after one pass: task.wait yields)
-- A thread that waits sleeps until pump() wakes it (one turn each); the main test thread never sleeps.
local MAIN=coroutine.running();local sleepers={}
W.env.task=setmetatable({wait=function(t)if coroutine.running()~=MAIN and coroutine.isyieldable()then sleepers[#sleepers+1]=coroutine.running();coroutine.yield()end;return t or 0 end},{__index=R.task})
local function pump()local list=sleepers;sleepers={};for _,co in ipairs(list)do if coroutine.status(co)=='suspended'then local ok,e=coroutine.resume(co);if not ok then print('WARN pump: '..tostring(e))end end end end
local products={}
local names={MintTrail='Mint Trail',ArcTrail='Arc Trail',SolarTrail='Solar Trail',AuroraTrail='Aurora',NebulaTrail='Nebula',RoyalTrail='Royal'}
for _,id in ipairs({'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'})do products[#products+1]={Id=id,Name=names[id],Type='Trail',Price=E.TrailCosts[id],SpeedMultiplier=2,Enabled=true,Owned=false,Equipped=false,Color={R=100,G=200,B=255}}end
local function product(id)for _,p in ipairs(products)do if p.Id==id then return p end end end
local snapshot=nil -- the Cash a scripted reply carries (nil: the live stat)
local purchases,shopReply={},nil
local function shopState(message)
 local list={};for i,p in ipairs(products)do list[i]=table.clone(p)end
 return {Success=true,Message=message,Cash=snapshot or cashValue.Value,Multiplier=1,LuckMultiplier=1,Products={Trails=list,Accessories={}},BootBiome='Forest',Harvests={},PendingSales={},CanSell=true}
end
local holdState,stateWaiter=false,nil -- (holdState: the next state request waits on the server until it is released)
rf('GetShopState').InvokeServer=function()if holdState then stateWaiter=coroutine.running();coroutine.yield()end;return shopState()end
local sentPrices={}
rf('PurchaseShopItem').InvokeServer=function(_,id,price)purchases[#purchases+1]=id;sentPrices[#sentPrices+1]=price;if shopReply then return shopReply(id)end;return shopState('PURCHASED '..id)end
rf('EquipShopItem').InvokeServer=function()return shopState('Equipped')end
rf('CollectSaleCash').InvokeServer=function()return {Success=true,Amount=0}end
rf('GetPendingSales').InvokeServer=function()return {}end
rf('GardenInteract').InvokeServer=function()return {Success=true}end
rf('SellHarvest').InvokeServer=function()return {Success=false,Message='NO CROPS TO SELL YET!'}end
local openUI=re('OpenEconomyUI')
setCash(10350000)
local okEcon,errEcon=pcall(W.load,'EconomyClient',R.new('LocalScript'))
check(okEcon,'C: the real EconomyClient loads on the mock ('..tostring(errEcon)..')')
local ui=pg:FindFirstChild('ChestEconomyUI');local panel=ui and ui:FindFirstChild('EconomyPanel')
if okEcon and panel then
 openUI.OnClientEvent:Fire('Trails')
 local rows=panel.ShopMenu.ProductRows
 local function button(id)local row=rows:FindFirstChild(id);return row and row:FindFirstChild('Purchase')end
 local function live(b)return b~=nil and b.Active==true and b.Interactable==true end
 local cashLine=panel:FindFirstChild('Cash')
 check(panel.Visible and button('ArcTrail')~=nil,'C: the market opens on Trails with a row per product')
 -- 1. the owner's case: $10,350,000 and the $10.4M Arc Trail
 local arc=button('ArcTrail')
 check(flat(cashLine.Text)=='Cash $10.3M','C: the market\'s Cash line never reads more than the player has ("'..cashLine.Text..'"; it read "Cash  $10.4M")')
 check(flat(arc.Text)=='Buy $10.4M','C: the Arc Trail\'s button reads its price "Buy  $10.4M" (not "Need $50000") ("'..arc.Text..'")')
 check(live(arc),'C: ... and it can be pressed (not greyed out and dead)')
 reset();purchases={};arc.Activated:Fire()
 check(#purchases==0,'C: a press the cash cannot pay sends nothing ('..#purchases..' sent)')
 check(noticed('Not enough cash!')and notices[1].Color==Red,'C: ... and shows the plain red notice "Not enough cash!"')
 check(table.find(played,'Denied')~=nil,'C: ... with the Denied click')
 check(panel.Status.Text=='','C: ... and nothing in the status line ("'..panel.Status.Text..'")')
 -- 2. exactly equal cash buys
 setCash(product('ArcTrail').Price);reset();purchases={}
 button('ArcTrail').Activated:Fire()
 check(#purchases==1 and purchases[1]=='ArcTrail'and not noticed('Not enough cash!'),'C: exactly $10,400,000 sends the purchase (equal money pays)')
 -- 3. the server's own money refusal (a balance that dropped meanwhile) is the same notice, never the status line
 for _,words in ipairs({'Not enough cash!','NOT ENOUGH CASH'})do
  shopReply=function()return {Success=false,Message=words}end;reset();purchases={}
  button('ArcTrail').Activated:Fire()
  check(#purchases==1 and noticed('Not enough cash!')and panel.Status.Text=='','C: the server says "'..words..'": the plain notice "Not enough cash!", not the status line ("'..panel.Status.Text..'")')
 end
 -- other refusals keep their own words
 shopReply=function()return {Success=false,Message='YOU ALREADY OWN THIS'}end;reset()
 button('ArcTrail').Activated:Fire()
 check(not noticed('Not enough cash!')and panel.Status.Text~='','C: "already own this" keeps its own words in the status line ("'..panel.Status.Text..'")')
 shopReply=nil
 -- 4. an older reply's Cash never overrides the live Cash stat (a coin that landed after the server read the balance)
 setCash(12000000);snapshot=5000000
 openUI.OnClientEvent:Fire('Trails') -- (the state is read again: the reply says $5M, the live stat says $12M)
 reset();purchases={}
 check(flat(cashLine.Text)=='Cash $12M','C: the Cash line follows the live stat, not the reply\'s older $5M ("'..cashLine.Text..'")')
 check(flat(button('ArcTrail').Text)=='Buy $10.4M'and live(button('ArcTrail')),'C: the Arc Trail still reads "Buy  $10.4M" and can be pressed ("'..button('ArcTrail').Text..'")')
 button('ArcTrail').Activated:Fire()
 check(#purchases==1 and not noticed('Not enough cash!'),'C: the press sends the purchase: $12M pays $10.4M whatever the old reply said')
 snapshot=nil
 -- 5. the sale coins' flight: the button follows the HUD's Cash (the server's), never anything else
 setCash(10000000);reset();purchases={}
 button('ArcTrail').Activated:Fire()
 check(#purchases==0 and noticed('Not enough cash!'),'C: coins still flying ($10M on the HUD): "Not enough cash!", nothing sent')
 setCash(10399999);setCash(10400000) -- (two coins land)
 reset();button('ArcTrail').Activated:Fire()
 check(#purchases==1 and not noticed('Not enough cash!'),'C: the coins landed ($10.4M on the HUD): the next press buys')
 check(flat(cashLine.Text)=='Cash $10.4M','C: ... and the Cash line follows each coin ("'..cashLine.Text..'")')
 -- 6. while the profile loads the screen does not decide: the server answers (here "LOADING")
 player:SetAttribute('DataStatus','Loading');setCash(0)
 shopReply=function()return {Success=false,Message='PLAYER DATA IS STILL LOADING'}end;reset();purchases={}
 button('RoyalTrail').Activated:Fire()
 check(#purchases==1 and not noticed('Not enough cash!'),'C: data still loading: the press goes to the server, no "Not enough cash!" for the wrong reason')
 check(panel.Status.Text~=''and not panel.Status.Text:find('CASH'),'C: ... and the server\'s loading words show ("'..panel.Status.Text..'")')
 player:SetAttribute('DataStatus','Loaded');shopReply=nil
 -- 7. a product the server says is not for this spot keeps its reason, greyed (not a money matter)
 product('SolarTrail').Enabled=false;product('SolarTrail').UnavailableReason='Visit shop';setCash(10^12)
 openUI.OnClientEvent:Fire('Trails')
 check(flat(button('SolarTrail').Text)=='Visit shop'and not live(button('SolarTrail')),'C: "Visit shop" keeps its words and stays off (not a money refusal)')
 product('SolarTrail').Enabled=true;product('SolarTrail').UnavailableReason=nil
 product('MintTrail').Owned=true;openUI.OnClientEvent:Fire('Trails')
 check(flat(button('MintTrail').Text)=='Equip'and live(button('MintTrail')),'C: an owned trail still reads Equip')
 -- 8. a double click sends one purchase
 openUI.OnClientEvent:Fire('Trails');reset();purchases={}
 -- (the first purchase waits on the server: InvokeServer yields until the reply, as on Roblox)
 local waiting
 shopReply=function(id)waiting=coroutine.running();coroutine.yield();return shopState('PURCHASED '..id)end
 local b=button('AuroraTrail');local first=coroutine.create(function()b.Activated:Fire()end);coroutine.resume(first)
 check(flat(b.Text)=='Wait a sec'and not live(b),'C: while the first purchase is on its way the button reads "Wait a sec" ("'..flat(b.Text)..'")')
 b.Activated:Fire();b.Activated:Fire()
 check(#purchases==1,'C: a double (triple) click sends one purchase ('..#purchases..')')
 shopReply=nil;coroutine.resume(waiting)
 check(coroutine.status(first)=='dead'and flat(b.Text)~='Wait a sec','C: ... and the reply frees the button')
 -- 10. a press made while the window's state refresh is on its way waits for it (it was dropped without a word)
 do
  for _,p in ipairs(products)do p.Owned=false end;setCash(10^9);openUI.OnClientEvent:Fire('Trails');reset();purchases={}
  holdState=true;local opener=coroutine.create(function()openUI.OnClientEvent:Fire('Trails')end);coroutine.resume(opener) -- the refresh is on its way
  holdState=false
  local clicker=coroutine.create(function()button('MintTrail').Activated:Fire()end);coroutine.resume(clicker)
  check(#purchases==0,'C: (the press waits while the refresh is on its way)')
  if stateWaiter then local w=stateWaiter;stateWaiter=nil;coroutine.resume(w)end -- the refresh comes back
  for _=1,3 do pump()end
  check(#purchases==1 and purchases[1]=='MintTrail','C: a press made during the state refresh is sent once the refresh is back, not dropped ('..#purchases..' sent)')
  check(coroutine.status(clicker)=='dead'and coroutine.status(opener)=='dead','C: ... and both finish')
 end
 -- 11. (owner: "make sure store prices are always the same") the press sends the very price its button shows; captions do not depend on the screen
 do
  for _,p in ipairs(products)do p.Owned=false end;setCash(10^15);openUI.OnClientEvent:Fire('Trails')
  local wrongPrice={}
  for _,p in ipairs(products)do
   purchases={};sentPrices={};R.advance(1);button(p.Id).Activated:Fire()
   local shownText=(flat(button(p.Id).Text):gsub('^Buy ',''))
   if not(#purchases==1 and sentPrices[1]==p.Price and parse(shownText)==p.Price)then wrongPrice[#wrongPrice+1]=p.Id..' shows '..flat(button(p.Id).Text)..' sends '..tostring(sentPrices[1])end
  end
  check(#wrongPrice==0,'C: every trail\'s button shows exactly its price and the press sends that same number ('..#wrongPrice..' wrong, e.g. '..tostring(wrongPrice[1])..')')
  local narrow={};for _,p in ipairs(products)do narrow[p.Id]=flat(button(p.Id).Text)end
  local list=panel.ShopMenu.ProductRows;list.AbsoluteSize=R.Vector2.new(700,500)
  local same=0;for _,p in ipairs(products)do if flat(button(p.Id).Text)==narrow[p.Id]then same+=1 end end
  check(same==#products,'C: a phone-narrow and a wide window show the same price words ('..same..'/'..#products..')')
  list.AbsoluteSize=R.Vector2.new(100,40)
  -- the server's price is not the one shown: refused with nothing charged, the notice, and the window shows the server's price at once
  local arcPrice=product('ArcTrail').Price
  shopReply=function()local st=shopState(nil);for _,q in ipairs(st.Products.Trails)do if q.Id=='ArcTrail'then q.Price=11000000 end end;st.Success=false;st.Message='The price changed! Check the new price.';return st end
  reset();purchases={};sentPrices={};button('ArcTrail').Activated:Fire()
  check(sentPrices[1]==arcPrice and noticed('The price changed! Check the new price.')and panel.Status.Text=='','C: a different server price: "The price changed! Check the new price." (the plain notice, no status line)')
  check(flat(button('ArcTrail').Text)=='Buy $11M','C: ... and the button shows the server\'s price at once ("'..flat(button('ArcTrail').Text)..'")')
  shopReply=nil;product('ArcTrail').Price=11000000;purchases={};sentPrices={};R.advance(1);button('ArcTrail').Activated:Fire()
  check(sentPrices[1]==11000000,'C: ... and the next press sends that price ('..tostring(sentPrices[1])..')')
  product('ArcTrail').Price=arcPrice;openUI.OnClientEvent:Fire('Trails')
 end
 -- 9. every trail at every balance around its price: the press sends the purchase exactly when the shared rule (the server's) says it pays
 local wrong={}
 for _,p in ipairs(products)do p.Owned=false end;openUI.OnClientEvent:Fire('Trails')
 for _,p in ipairs(products)do for _,d in ipairs({-1,0,1,-50000,50000})do
  local bal=p.Price+d;if bal>=0 then
   setCash(bal);purchases={};R.advance(1);button(p.Id).Activated:Fire()
   local sent=#purchases==1;local pays=bal>=p.Price
   if sent~=pays then wrong[#wrong+1]=p.Id..' at $'..bal end
  end
 end end
 check(#wrong==0,'C: every trail, balances price-50K..price+50K: the press goes to the server exactly when the money pays ('..#wrong..' wrong, e.g. '..tostring(wrong[1])..')')
end

-- D. the shop: the real GamePassClient --------------------------------------------------------------------------------------------------------------------------
local Passes=W.module('GamePassCatalog');local Pricing=W.module('PremiumPricing')
local robux={}
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102);RS.GamePassCatalog:SetAttribute('CloverPassId',103);robux[101]=467;robux[102]=399;robux[103]=999
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
local Market=W.service('MarketplaceService')
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptGamePassPurchase=function()end
local bagFull=false;local premiumReply=nil;local premiumCalls={};local serverPack,serverPass=nil,nil -- (serverPack / serverPass: the server's prices, when a test changes them)
local function premiumState()
 local offers={};for _,o in ipairs(Mech.Offers)do offers[tostring(o.Count)]={Count=o.Count,GemPrice=serverPack and serverPack[o.Count]or o.GemPrice,GemAvailable=not bagFull,RobuxAvailable=not bagFull,RobuxPrice=o.TargetRobuxPrice,BagFull=bagFull or nil}end
 local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
 return {PackOffers=offers,Bundles=bundles,GiftProducts={},GiftCredits={},Gems=player:GetAttribute('Gems')or 0,Cash=cashValue.Value,OnSale=true,Success=true,PassGemPrices=serverPass,CashPerGem=Mech.CashPerGem}
end
local premium=R.new('RemoteFunction');premium.Name='PremiumRequest';premium.Parent=remotes
premium.InvokeServer=function(_,action,value,shown)
 premiumCalls[#premiumCalls+1]={action,value,shown}
 local s=premiumState();if action~='State'and premiumReply then local r=premiumReply(action,value);for k,v in pairs(r)do s[k]=v end end;return s
end
W.UIS.TouchEnabled=false
local okShop,errShop=pcall(W.load,'GamePassClient',R.new('LocalScript'))
check(okShop,'D: the real GamePassClient loads ('..tostring(errShop)..')')
local shop=pg:FindFirstChild('GardenPasses')
if okShop and shop then
 local spanel=shop.PremiumShop;local page=spanel.Body.Page;local strip=spanel.Status
 local toggle=pg:FindFirstChild('PassesButton',true)
 toggle.Activated:Fire() -- open: State
 local pack=page.LimitedMechPack
 local function sent(action)local n=0;for _,c in ipairs(premiumCalls)do if c[1]==action then n+=1 end end;return n end
 local function press(b)premiumCalls={};reset();b.Activated:Fire()end
 -- the Mech pack (80 gems)
 player:SetAttribute('Gems',79);press(pack.Quantity1);press(pack.BuyWithGems)
 check(sent('BuyPack')==0 and noticed('Not enough gems!')and table.find(played,'Denied')~=nil,'D: 79 gems, the 80-gem Mech pack: "Not enough gems!" + Denied, nothing sent')
 check(strip.Text=='','D: ... and no dark strip ("'..strip.Text..'")')
 player:SetAttribute('Gems',80);press(pack.BuyWithGems)
 check(sent('BuyPack')==1 and not noticed('Not enough gems!'),'D: exactly 80 gems sends BuyPack')
 player:SetAttribute('Gems',374);press(pack.Quantity5);press(pack.BuyWithGems)
 check(sent('BuyPack')==0 and noticed('Not enough gems!'),'D: 374 gems, the 5-pack (375): "Not enough gems!"')
 player:SetAttribute('Gems',375);press(pack.BuyWithGems);check(sent('BuyPack')==1,'D: 375 gems buys the 5-pack')
 press(pack.Quantity1)
 -- the server's money refusal (gems spent elsewhere meanwhile) is the same notice
 for _,words in ipairs({'Not enough gems!','NOT ENOUGH GEMS'})do
  premiumReply=function()return {Success=false,Message=words}end;player:SetAttribute('Gems',80);press(pack.BuyWithGems)
  check(sent('BuyPack')==1 and noticed('Not enough gems!')and strip.Text=='','D: the server says "'..words..'": the plain notice, no strip ("'..strip.Text..'")')
 end
 premiumReply=nil
 -- a full Bag is told first (R157), whatever the gems
 bagFull=true;player:SetAttribute('Gems',0);toggle.Activated:Fire();toggle.Activated:Fire() -- (close / open: State again)
 press(pack.BuyWithGems)
 check(sent('BuyPack')==0 and noticed('BAG FULL! MAKE ROOM FIRST')and not noticed('Not enough gems!'),'D: a full Bag says "BAG FULL! MAKE ROOM FIRST" (not "not enough gems")')
 bagFull=false;toggle.Activated:Fire();toggle.Activated:Fire()
 -- bundles (gems)
 local small=page.CashSmallBundle.GemBundle;local smallPrice=Pricing.Find('CashSmall').GemPrice
 player:SetAttribute('Gems',smallPrice-1);press(small)
 check(sent('BuyBundle')==0 and noticed('Not enough gems!'),'D: a gem bundle one gem short: "Not enough gems!", nothing sent')
 player:SetAttribute('Gems',smallPrice);press(small);check(sent('BuyBundle')==1,'D: ... exactly its price sends BuyBundle')
 -- passes (gems)
 for _,pass in ipairs(Passes)do
  local price=Mech.PassGemPrices[pass.Key];local card=page:FindFirstChild(pass.Key)
  if card and card:FindFirstChild('GemPerk')then
   player:SetAttribute('Gems',price-1);press(card.GemPerk)
   check(sent('BuyPerk')==0 and noticed('Not enough gems!'),'D: the '..pass.Key..' pass one gem short: "Not enough gems!", nothing sent')
   player:SetAttribute('Gems',price);press(card.GemPerk);check(sent('BuyPerk')==1,'D: ... exactly '..price..' gems sends BuyPerk')
  end
 end
 -- Cash to Gems: 1 Gem = $1T
 local conv=page.ConvertCash
 setCash(999999999999);conv.GemQuantity.Text='1';press(conv.Convert)
 check(sent('Convert')==0 and noticed('Not enough cash!'),'D: CONVERT 1 Gem with $999,999,999,999: "Not enough cash!", nothing sent')
 setCash(1000000000000);press(conv.Convert);check(sent('Convert')==1,'D: exactly $1T converts')
 premiumReply=function()return {Success=false,Message='NOT ENOUGH CASH'}end;press(conv.Convert)
 check(noticed('Not enough cash!')and strip.Text=='','D: the server\'s money refusal for CONVERT is the notice, no strip')
 premiumReply=nil
 setCash(0);conv.GemQuantity.Text='5';press(conv.Maximum)
 check(conv.GemQuantity.Text=='1','D: MAX with less than $1T puts 1 (it put 0, and CONVERT then said "Type a whole number of Gems.") ("'..conv.GemQuantity.Text..'")')
 press(conv.Convert);check(sent('Convert')==0 and noticed('Not enough cash!'),'D: ... and CONVERT then says "Not enough cash!"')
 setCash(5*10^12);press(conv.Maximum);check(conv.GemQuantity.Text=='5','D: MAX with $5T puts 5')
 check(flat(conv.Cost.Text)=='Cost: 5T Cash','D: the cost line reads "Cost: 5T Cash" ("'..conv.Cost.Text..'")')
 -- while the profile loads the screen does not decide
 player:SetAttribute('DataStatus','Loading');player:SetAttribute('Gems',nil);press(pack.BuyWithGems)
 check(sent('BuyPack')==1 and not noticed('Not enough gems!'),'D: data still loading: the gem press goes to the server (no "not enough" for the wrong reason)')
 player:SetAttribute('DataStatus','Loaded')
 -- Robux is untouched: no money check, the prompt request as before
 player:SetAttribute('Gems',0);press(pack.BuyWithRobux)
 check(sent('RobuxPack')==1 and not noticed('Not enough gems!'),'D: the Robux button is untouched (0 gems: it still asks for the Robux prompt)')
 -- (owner: "make sure store prices are always the same") every gem press sends the price its button shows
 player:SetAttribute('Gems',10^5);setCash(10^15)
 local function last(action)for i=#premiumCalls,1,-1 do if premiumCalls[i][1]==action then return premiumCalls[i]end end end
 local function caption(b)return b:GetAttribute('Caption')end
 local offersShown={}
 for _,o in ipairs(Mech.Offers)do press(pack['Quantity'..o.Count]);press(pack.BuyWithGems);local c=last('BuyPack');offersShown[#offersShown+1]=tostring(c and c[3])..'/'..tostring(caption(pack.BuyWithGems))
  check(c and c[2]==o.Count and c[3]==o.GemPrice and caption(pack.BuyWithGems)==tostring(o.GemPrice),'D: the '..o.Count..'-pack button shows '..o.GemPrice..' and its press sends '..o.GemPrice..' ('..offersShown[#offersShown]..')')end
 press(pack.Quantity1)
 for _,pass in ipairs(Passes)do local card=page:FindFirstChild(pass.Key);if card and card:FindFirstChild('GemPerk')then
  press(card.GemPerk);local c=last('BuyPerk');local price=Mech.PassGemPrices[pass.Key]
  check(c and c[3]==price and caption(card.GemPerk)==tostring(price),'D: the '..pass.Key..' pass shows '..price..' and sends '..price)
 end end
 press(small);check(last('BuyBundle')and last('BuyBundle')[3]==smallPrice and caption(small)==tostring(smallPrice),'D: a bundle shows its quote and sends it')
 conv.GemQuantity.Text='3';press(conv.Convert);check(last('Convert')and last('Convert')[3]==3*Mech.CashPerGem and flat(conv.Cost.Text)=='Cost: 3T Cash','D: CONVERT 3 shows "Cost: 3T Cash" and sends $3T')
 -- the server's price is not the one shown: refused, the notice, and the buttons show the server's prices from its reply
 serverPack={[1]=90,[5]=375,[10]=700};serverPass={Growth=550,Speed=400,Clover=999}
 premiumReply=function()return {Success=false,Message='The price changed! Check the new price.'}end
 press(pack.BuyWithGems)
 check(last('BuyPack')[3]==Mech.Offer(1).GemPrice and noticed('The price changed! Check the new price.')and strip.Text=='','D: a different server price: "The price changed! Check the new price." (the plain notice, no strip)')
 check(caption(pack.BuyWithGems)=='90'and caption(page.Growth.GemPerk)=='550','D: ... and the buttons show the server\'s prices at once (pack '..tostring(caption(pack.BuyWithGems))..', Growth '..tostring(caption(page.Growth.GemPerk))..')')
 premiumReply=nil;press(pack.BuyWithGems);local packSent=last('BuyPack');press(page.Growth.GemPerk);local passSent=last('BuyPerk')
 check(packSent and packSent[3]==90 and passSent and passSent[3]==550,'D: ... and the next presses send those prices')
 serverPack,serverPass=nil,nil;toggle.Activated:Fire();toggle.Activated:Fire()
 check(caption(pack.BuyWithGems)==tostring(Mech.Offer(1).GemPrice),'D: (back to the catalog prices)')
 -- other refusals keep their words in the strip
 premiumReply=function()return {Success=false,Message='YOU ALREADY HAVE THIS!'}end;player:SetAttribute('Gems',10000)
 press(page.Growth.GemPerk)
 check(not noticed('Not enough gems!')and flat(strip.Text)=='YOU ALREADY HAVE THIS!','D: "YOU ALREADY HAVE THIS!" keeps its words in the strip ("'..flat(strip.Text)..'")')
 premiumReply=nil
end

print(('R158k store client: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
