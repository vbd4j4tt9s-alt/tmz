--!nocheck
-- R148 (owner: "remove this line when purchasing"): the real GamePassClient shop on the Roblox mock, with a scripted
-- PremiumRequest. A Robux prompt that merely opened now comes back with NO Message, and the dark strip across the shop cards
-- (panel.Status) must stay hidden for it: a nil, empty, blank or non-string message never leaves an empty bar. Real errors
-- ("Purchase could not open.", "THIS PURCHASE IS UNAVAILABLE", ...) and the "Gems on the way." hints still show for 3 s.
-- The gem purchases the server announces get the chime from PurchaseCelebration, so no KaChing on top of it here.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Tween=W.service('TweenService')
function Tween.Create(_,obj,_,props)return {Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end,Completed=R.signal()}end
-- Player / products ------------------------------------------------------------------------------------------
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local player=R.new('Player');player.Name='Buyer';player.DisplayName='Buyer';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return {player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
for _,k in ipairs({'Growth','Speed'})do player:SetAttribute(k..'OwnershipReady',true)end
local RS=W.RS
local Passes=W.module('GamePassCatalog');local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog')
local robux={}
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102);robux[101]=467;robux[102]=399
RS.GamePassCatalog:SetAttribute('CloverPassId',103);robux[103]=999 -- R153: the 4 Leaf Clover pass (a third card; its id has a code default, the attribute here overrides it)
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
local Market=W.service('MarketplaceService');local passPrompts=0
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptGamePassPurchase=function()passPrompts+=1 end
-- Scripted server --------------------------------------------------------------------------------------------------
local function serverState()
 local offers={};for _,o in ipairs(Mech.Offers)do offers[tostring(o.Count)]={Count=o.Count,GemPrice=o.GemPrice,GemAvailable=true,RobuxAvailable=true,RobuxPrice=o.TargetRobuxPrice}end
 local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
 return {PackOffers=offers,Bundles=bundles,GiftProducts={Growth={Available=true},Speed={Available=true}},GiftCredits={},Gems=5000,OnSale=true,Success=true}
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local remote=R.new('RemoteFunction');remote.Name='PremiumRequest';remote.Parent=remotes
local calls={};local reply={Message=nil};local failing=false;local successful=true
remote.InvokeServer=function(_,action,value)
 calls[#calls+1]={action,value}
 if failing then error('the server did not answer')end
 local s=serverState();s.Success=successful;if action~='State'then s.Message=reply.Message end;return s
end
local buys=0;local plays={}
W.stub('InteractionAudio',{Transaction=function(kind)if kind=='Buy'then buys+=1 end end,Play=function(key)plays[#plays+1]=key end,Preload=function()end})
W.stub('ShopViewport',{Visible=function()return true end,CachedVisible=function()return true end})
W.stub('ShopSeedReveal',{Attach=function()return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)
 local halo=R.Instance.new('Frame');halo.Name='MechDockingBay';halo.Parent=parent
 local v=R.Instance.new('ViewportFrame');v.Name='MechPackPreview';v.Parent=parent;return v end})
W.UIS.TouchEnabled=false
local okLoad,errLoad=pcall(W.load,'GamePassClient',R.new('LocalScript'));check(okLoad,'GamePassClient loads: '..tostring(errLoad))
local gui=pg.GardenPasses;local panel=gui.PremiumShop;local page=panel.Body.Page;local status=panel.Status
local function act(b)b.Activated:Fire()end
local function said()return (status.Text:gsub('\n',' '))end -- (GardenTextFit wraps the strip's text at spaces)
local function shut()return not status.Visible and status.Text==''end
act(pg:FindFirstChild('PassesButton',true))
check(panel.Visible and calls[1]and calls[1][1]=='State','the shop opens and asks for its State')
check(shut(),'no status strip when the shop opens')
local pack=page.LimitedMechPack
-- 1. A Robux prompt that opened: no Message -> no strip ---------------------------------------------------------------------
reply.Message=nil;calls={}
act(pack.BuyWithRobux);check(calls[#calls]and calls[#calls][1]=='RobuxPack'and calls[#calls][2]==1,'the Robux pack button asks for RobuxPack 1')
check(shut(),'RobuxPack: the prompt opened and there is NO status strip ('..tostring(status.Visible)..' / "'..status.Text..'")')
act(pack.Quantity5);act(pack.BuyWithRobux);check(calls[#calls][1]=='RobuxPack'and calls[#calls][2]==5 and shut(),'RobuxPack 5: no strip')
act(pack.Quantity10);act(pack.BuyWithRobux);check(calls[#calls][1]=='RobuxPack'and calls[#calls][2]==10 and shut(),'RobuxPack 10: no strip')
for _,row in ipairs(Pricing.Bundles)do
 local card=page:FindFirstChild(row.Key..'Bundle')
 act(card.RobuxBundle);check(calls[#calls][1]=='RobuxBundle'and calls[#calls][2]==row.Key and shut(),'RobuxBundle '..row.Key..': no strip')
end
check(said()~='Complete the Roblox purchase prompt.','the old "Complete the Roblox purchase prompt." text never shows')
local n=#calls;local prompts=passPrompts
for _,pass in ipairs(Passes)do act(page[pass.Key].RobuxPass)end
check(passPrompts==prompts+#Passes and#calls==n and shut(),'a game-pass Robux button opens the Roblox prompt directly and shows no strip')
-- 2. An empty / blank / non-string Message never leaves an empty bar ----------------------------------------------------------------
for _,case in ipairs({{'an empty string',''},{'a blank string','   '},{'a tab and newline','\t\n'},{'a number',5},{'a table',{}},{'true',true},{'false',false}})do
 reply.Message=case[2];local before=#calls;act(pack.BuyWithRobux)
 check(#calls==before+1,'Message = '..case[1]..': the button was pressed (the server was asked)')
 check(shut(),'Message = '..case[1]..': the strip stays hidden, no empty dark bar ('..tostring(status.Visible)..' / "'..status.Text..'")')
end
-- ...also right after a real error was showing
reply.Message='Couldn\'t open the purchase. Try again!';act(pack.BuyWithRobux)
check(status.Visible and said()=='Couldn\'t open the purchase. Try again!','a real error shows')
reply.Message=nil;act(pack.BuyWithRobux)
check(shut(),'the next action without a message clears the strip at once')
-- 3. Real errors and hints still show, for 3 seconds ----------------------------------------------------------------------------------
successful=false
for _,text in ipairs({'Couldn\'t open the purchase. Try again!','CAN\'T BUY THIS RIGHT NOW','CAN\'T GIFT THIS RIGHT NOW','NOT ENOUGH GEMS','NO PURCHASES UNTIL UR DATA CAN SAVE','TRY AGAIN IN A SEC!'})do
 plays={};reply.Message=text;act(pack.BuyWithRobux)
 check(plays[#plays]=='Denied','R150: the refused purchase "'..text..'" clicks Denied')
 check(status.Visible and said()==text,'"'..text..'" is shown')
 R.advance(2.9);check(status.Visible and said()==text,'"'..text..'" is still shown at 2.9 s')
 R.advance(.3);check(shut(),'"'..text..'" hides after 3 s')
end
successful=true
local gems_=page.ConvertCash;reply.Message='Ur Gems are on the way!';gems_.GemQuantity.Text='5';plays={};act(gems_.Convert)
check(not table.find(plays,'Denied'),'R150: a successful action (the Convert hint) never clicks Denied')
check(calls[#calls][1]=='Convert'and calls[#calls][2]==5 and status.Visible and said()=='Ur Gems are on the way!','Convert keeps its "Ur Gems are on the way!" hint')
R.advance(3.1);check(shut(),'...and it hides after 3 s')
gems_.GemQuantity.Text='abc';act(gems_.Convert)
check(status.Visible and said()=='Type a whole number of Gems.','a client-side input error shows')
R.advance(3.1);check(shut(),'...and hides after 3 s')
failing=true;reply.Message=nil;plays={};act(pack.BuyWithRobux)
check(status.Visible and said()=='Try again in a sec!','a server call that fails says "Try again in a sec!"')
check(plays[#plays]=='Denied','R150: ...and clicks Denied')
R.advance(3.1);check(shut(),'...and hides after 3 s')
failing=false
-- the same error twice in a row shows each time
reply.Message='Couldn\'t open the purchase. Try again!';act(pack.BuyWithRobux);R.advance(1);act(pack.BuyWithRobux)
check(status.Visible and said()=='Couldn\'t open the purchase. Try again!','the same error again is shown again')
R.advance(3.1);check(shut(),'...and hides')
-- 4. The gem purchases the server announces make no KaChing (the chime comes from PurchaseCelebration) ----------------------------------------
reply.Message=nil;buys=0;plays={}
act(pack.Quantity1);act(pack.BuyWithGems);check(calls[#calls][1]=='BuyPack'and shut(),'BuyPack: no strip when the server sends no message')
act(page.CashSmallBundle.GemBundle);check(calls[#calls][1]=='BuyBundle'and shut(),'BuyBundle: no strip')
act(page.Growth.GemPerk);check(calls[#calls][1]=='BuyPerk'and shut(),'BuyPerk: no strip')
gems_.GemQuantity.Text='3';act(gems_.Convert);check(calls[#calls][1]=='Convert'and shut(),'Convert: no strip')
check(buys==0 and#plays==0,'none of the four plays the old KaChing (the celebration brings the chime) ('..buys..')')
act(pack.BuyWithRobux);check(buys==0,'a Robux purchase prompt plays no sound from the shop either')
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
