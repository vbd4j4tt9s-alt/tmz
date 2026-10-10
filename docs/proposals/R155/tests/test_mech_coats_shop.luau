--!nocheck
-- R155 (owner: the Mech pack card's "LIMITED TIME!" gets a real end, like Verity's event; Mech packs roll Gold / Diamond coats): the real GamePassClient shop on the Roblox mock with a scripted
-- PremiumRequest and a server clock set near LimitedEvent.EndsAt.
--  1. the card says it   under the buy buttons: the coat line "Gold 4.5% / Diamond 0.5% coat" and, next to it, the live countdown in the Index LIMITED tab's format
--                        ("⏳ ENDS IN 27d 04h 12m 09s", the server's clock); "LIMITED TIME!" stays on the title row; both buy buttons are on
--  2. it ticks           once a second while the shop is open (and not at all while it is shut)
--  3. the end            the second the clock reaches EndsAt (the shop open): "EVENT OVER!" on the title row, "THANKS FOR PLAYING!" under the buttons, the gem and Robux buttons
--                        say "Event over" and are off (a click sends nothing to the server); the quantity chips still work; opening the shop after the end shows the same at once
--  4. the server says no a purchase the server refuses shows its message (the server refuses a gem purchase / a Robux prompt after the end by itself: test_mech_coats_server.luau)
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Tween=W.service('TweenService')
function Tween.Create(_,obj,_,props)return {Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end,Completed=R.signal()}end
local Players=W.service('Players');Players.PlayerAdded=R.signal();Players.PlayerRemoving=R.signal()
local player=R.new('Player');player.Name='Buyer';player.DisplayName='Buyer';player.UserId=1;player.Parent=Players;Players.LocalPlayer=player
function Players.GetPlayers()return {player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
for _,k in ipairs({'Growth','Speed','Clover'})do player:SetAttribute(k..'OwnershipReady',true)end
local RS=W.RS
local Passes=W.module('GamePassCatalog');local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog');local Limited=W.module('LimitedEvent')
local ENDS=Limited.EndsAt
local robux={}
RS.GamePassCatalog:SetAttribute('GrowthPassId',101);RS.GamePassCatalog:SetAttribute('SpeedPassId',102);robux[101]=467;robux[102]=399
RS.GamePassCatalog:SetAttribute('CloverPassId',103);robux[103]=999
for i,row in ipairs(Pricing.Bundles)do RS.PremiumPricing:SetAttribute(row.IdAttribute,200+i);robux[200+i]=row.RobuxPrice end
for i,offer in ipairs(Mech.Offers)do RS.MechCatalog:SetAttribute(offer.Attribute,300+i);robux[300+i]=offer.TargetRobuxPrice end
local Market=W.service('MarketplaceService')
Market.GetProductInfoAsync=function(_,id)return robux[id]and{PriceInRobux=robux[id],IsForSale=true}or nil end
Market.PromptGamePassPurchase=function()end
local prompted=0;Market.PromptProductPurchase=function()prompted+=1 end
-- the server's clock: ENDS - 27d 04h 12m 09s at mock time 0, then one second per second
local LEFT0=27*86400+4*3600+12*60+9
local serverClock=function()return ENDS-LEFT0+R.clock end
W.workspace.GetServerTimeNow=function()return serverClock()end
local function jumpTo(left)R.clock=LEFT0-left end -- (the mock clock to the moment `left` seconds remain)
-- scripted server: everything on sale (the CLIENT must turn the buttons off by the clock)
-- (R157) mode.BagFull: the server says the Bag is full (BagFull = true, both buy flags false); mode.Stale: ... and, wrongly, still says the buy flags are on; mode.Unavailable: off for another reason
-- (R157b review) mode.FullFor = {[count]=true}: the Bag is full for those quantities only (195 items: the 1-pack fits, the 5- and 10-pack do not); mode.Hook = a function run once inside the next request
local mode={BagFull=false,Stale=false,Unavailable=false,FullFor=nil,Hook=nil}
local function serverState()
 local offers={};for _,o in ipairs(Mech.Offers)do
  local full=mode.BagFull or(mode.FullFor~=nil and mode.FullFor[o.Count]==true)
  local on=not full and not mode.Unavailable or mode.Stale
  offers[tostring(o.Count)]={Count=o.Count,GemPrice=o.GemPrice,GemAvailable=on,RobuxAvailable=on,RobuxPrice=o.TargetRobuxPrice,BagFull=full and true or nil}
 end
 local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
 return {PackOffers=offers,Bundles=bundles,GiftProducts={Growth={Available=true},Speed={Available=true}},GiftCredits={},Gems=5000,OnSale=true,Success=true}
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
local remote=R.new('RemoteFunction');remote.Name='PremiumRequest';remote.Parent=remotes
local calls={};local reply={Message=nil,OnSale=true}
remote.InvokeServer=function(_,action,value)
 calls[#calls+1]={action,value,R.clock}
 if mode.Hook then local h=mode.Hook;mode.Hook=nil;h()end
 local s=serverState();s.OnSale=reply.OnSale;if action~='State'then s.Message=reply.Message end;return s
end
local played={};local function plays(name)local n=0;for _,v in ipairs(played)do if v==name then n+=1 end end;return n end
W.stub('InteractionAudio',{Transaction=function()end,Play=function(name)played[#played+1]=name end,Preload=function()end})
-- (R157) the game's notice stack: what the shop puts on it
local notices={}
W.stub('NoticeFeed83',{Plain=function(text,color,seconds,key,deny)notices[#notices+1]={Text=text,Color=color,Seconds=seconds,Key=key,Deny=deny}end,Preload=function()end})
W.stub('ShopViewport',{Visible=function()return true end,CachedVisible=function()return true end})
W.stub('ShopSeedReveal',{Attach=function()return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)
 local halo=R.Instance.new('Frame');halo.Name='MechDockingBay';halo.Parent=parent
 local v=R.Instance.new('ViewportFrame');v.Name='MechPackPreview';v.Parent=parent;return v end})
W.UIS.TouchEnabled=false
local okLoad,errLoad=pcall(W.load,'GamePassClient',R.new('LocalScript'));check(okLoad,'GamePassClient loads: '..tostring(errLoad))
local gui=pg.GardenPasses;local panel=gui.PremiumShop;local page=panel.Body.Page
local pack=page.LimitedMechPack
local function act(b)b.Activated:Fire()end
local function caption(b)return b:GetAttribute('Caption')end
local function live(b)return b.Active==true and b.Interactable~=false end
local function stateCalls()local n=0;for _,c in ipairs(calls)do if c[1]=='BuyPack'or c[1]=='RobuxPack'then n+=1 end end;return n end
local toggle=pg:FindFirstChild('PassesButton',true)
local function txt(l)return(l.Text:gsub('\n',' '))end -- (GardenTextFit wraps a label at spaces on the mock, which has no text metrics here)
local function timerAt(left)return'⏳ ENDS IN '..Limited.Text(left)end

-- 0. the card's layout (PremiumLayout.Content is pure): the coat line and the countdown fit in every mode (wide >= 640, medium >= 300, narrow below), under every other part of the card
do
 local L=W.module('PremiumLayout')
 local function overlaps(a,b)return a.X<b.X+b.W and b.X<a.X+a.W and a.Y<b.Y+b.H and b.Y<a.Y+a.H end
 local bad,rows,modes={},0,{}
 for _,width in ipairs({240,280,299,300,330,420,560,639,640,760,1000,1400})do for _,k in ipairs({.55,.8,1,1.3})do
  local out=L.Content(width,k,{Passes=3,Speed=5,Money=5});local f=out.Featured;rows+=1;modes[f.Mode]=true
  local others={f.Preview,f.Gem,f.Robux,table.unpack(f.Tiles)};for _,c in ipairs(f.Chips)do others[#others+1]=c end
  for _,r in ipairs({f.Coat,f.Timer})do
   if not r or r.W<60 or r.H<15 or r.X<0 or r.Y<0 or r.X+r.W>out.Inner or r.Y+r.H>f.H then bad[#bad+1]=('%d/%.2f out of the card'):format(width,k) end
   for _,o in ipairs(others)do if overlaps(r,o)then bad[#bad+1]=('%d/%.2f overlaps'):format(width,k)end end
  end
  if overlaps(f.Coat,f.Timer)then bad[#bad+1]=('%d/%.2f coat / timer overlap'):format(width,k)end
  if out.Cards.Featured.H~=f.H or f.H<f.Timer.Y+f.Timer.H+f.Pad then bad[#bad+1]=('%d/%.2f card height'):format(width,k)end
  if f.Mode=='Narrow'then if f.Timer.Y<f.Coat.Y+f.Coat.H then bad[#bad+1]=('%d/%.2f narrow rows not stacked'):format(width,k)end
  elseif f.Timer.X<f.Coat.X+f.Coat.W or f.Timer.Y~=f.Coat.Y then bad[#bad+1]=('%d/%.2f wide / medium not side by side'):format(width,k)end
 end end
 check(#bad==0 and modes.Wide and modes.Medium and modes.Narrow,('PremiumLayout: the coat line and the countdown are inside the card, clear of the preview, tiles, chips and buy buttons, side by side (wide / medium) or stacked (narrow), in %d sizes of all three modes (%s)'):format(rows,table.concat(bad,'; ',1,math.min(#bad,3))))
end

-- 1. the card says it ----------------------------------------------------------------------------------------------------------------------------------
check(pack:FindFirstChild('CoatNote')~=nil and pack:FindFirstChild('EventTimer')~=nil and pack:FindFirstChild('Contents')~=nil,'the card has its coat line, its countdown and its LIMITED TIME label')
act(toggle)
check(panel.Visible and calls[1]and calls[1][1]=='State','the shop opens and asks for its State')
check(txt(pack.CoatNote)=='Gold 4.5% / Diamond 0.5% coat','the coat line reads "Gold 4.5% / Diamond 0.5% coat" ('..txt(pack.CoatNote)..')')
check(txt(pack.CoatNote)==Mech.CoatLine(),'... exactly MechCatalog.CoatLine(), the line the hold tooltip and /test mechshop show')
check(txt(pack.EventTimer)=='⏳ ENDS IN 27d 04h 12m 09s','the countdown reads "⏳ ENDS IN 27d 04h 12m 09s" ('..txt(pack.EventTimer)..')')
check(txt(pack.Contents)=='LIMITED TIME!','"LIMITED TIME!" stays on the title row with the countdown')
check(caption(pack.BuyWithGems)=='80'and live(pack.BuyWithGems)and caption(pack.BuyWithRobux)=='80 Robux'and live(pack.BuyWithRobux),'both buy buttons are on (80 / 80 Robux)')

-- 2. it ticks, once a second, only while the shop is open ------------------------------------------------------------------------------------------------
-- (the shop reads the server's clock on every tick: the text shown is the time left at the tick, which is at most a second before "now")
local function ticks(label,left)
 local now=Limited.Left(serverClock())
 local shown=txt(pack.EventTimer)
 check(shown==timerAt(now)or shown==timerAt(now+1),label..': "'..shown..'" is the time left (now '..Limited.Text(now)..')')
 return shown
end
R.advance(1);ticks('one second later')
local a=txt(pack.EventTimer);R.advance(1);local b=txt(pack.EventTimer);check(a~=b,'the countdown changes every second ("'..a..'" -> "'..b..'")')
local steps={}
for n=1,12 do R.advance(1);steps[#steps+1]=txt(pack.EventTimer)end
local distinct={};for _,t in ipairs(steps)do distinct[t]=true end;local n=0;for _ in pairs(distinct)do n+=1 end
check(n==12,'12 seconds, 12 different readings ('..n..')')
for _,left in ipairs({27*86400+4*3600+12*60+9,3*86400,3600+1,61,1+60*60*24*7})do
 act(panel.Header.Close);jumpTo(left);act(toggle);R.advance(1);R.advance(1);ticks('with '..left..' s left') -- (a jump back in time: the shop is shut and reopened, so the old tick chain is gone)
end
check(panel.Visible,'(the shop is open)');act(panel.Header.Close);check(not panel.Visible,'the shop closes')
local frozen=txt(pack.EventTimer);R.advance(30);check(txt(pack.EventTimer)==frozen,'a shut shop does not tick')
-- it comes back on opening, with the right time at once
jumpTo(5000);act(toggle);R.advance(.001);check(panel.Visible and txt(pack.EventTimer)==timerAt(5000),'opening the shop shows the time left at once ('..txt(pack.EventTimer)..')')

-- 3. the end, with the shop open -----------------------------------------------------------------------------------------------------------------------------
-- a sweep from 4 s before EndsAt to 4 s after it, in half seconds: the card is on while the event runs and ended at the latest a second (one tick) after it ended
jumpTo(4)
local sawLive,sawOver=false,false;local firstOver
for _=1,16 do
 R.advance(.5)
 local now=serverClock();local active=Limited.Active(now);local over=txt(pack.Contents)=='EVENT OVER!'
 local offs=not live(pack.BuyWithGems)and not live(pack.BuyWithRobux)
 if active then
  sawLive=true
  check(not over and not offs and txt(pack.Contents)=='LIMITED TIME!','while the event runs ('..Limited.Left(now)..' s left): LIMITED TIME!, both buttons on')
 elseif not Limited.Active(now-1.001)then
  sawOver=true;firstOver=firstOver or now
  check(over and offs and txt(pack.EventTimer)=='THANKS FOR PLAYING!','a second after the end: EVENT OVER!, THANKS FOR PLAYING!, both buttons off')
 end
end
check(sawLive and sawOver,'the sweep saw both the running and the ended card')
check(serverClock()>=ENDS+3,'(the sweep ran to 3 s after EndsAt)')
check(txt(pack.EventTimer)=='THANKS FOR PLAYING!'and txt(pack.Contents)=='EVENT OVER!','at EndsAt the countdown line says "THANKS FOR PLAYING!" and the title row "EVENT OVER!"')
check(not live(pack.BuyWithGems)and not live(pack.BuyWithRobux),'... and both buy buttons are OFF')
check(caption(pack.BuyWithGems)=='Event over'and caption(pack.BuyWithRobux)=='Event over','... saying "Event over" ('..tostring(caption(pack.BuyWithGems))..' / '..tostring(caption(pack.BuyWithRobux))..')')
act(pack.BuyWithGems);act(pack.BuyWithRobux)
check(stateCalls()==0,'a click on a dead buy button sends nothing to the server')
for _,count in ipairs({1,5,10})do act(pack['Quantity'..count]);check(not live(pack.BuyWithGems)and not live(pack.BuyWithRobux),'with the '..count..'-pack picked the buy buttons stay off')end
check(live(pack.Quantity5)and txt(pack.Quantity5)=='5 PACKS','the quantity chips still work')
R.advance(5);check(txt(pack.EventTimer)=='THANKS FOR PLAYING!'and txt(pack.Contents)=='EVENT OVER!','it stays ended as time goes on')
-- the server's own State (it says on sale: a stale answer) does not turn the buttons back on
act(panel.Header.Close);act(toggle);R.advance(1)
check(panel.Visible and not live(pack.BuyWithGems)and not live(pack.BuyWithRobux)and txt(pack.EventTimer)=='THANKS FOR PLAYING!','reopening the shop after the end: ended at once, whatever State says')
local ended=#calls;R.advance(10);check(#calls==ended,'no request goes out on its own while it is ended (the countdown is the client\'s clock)')

-- 4. a purchase the server refuses shows its message ----------------------------------------------------------------------------------------------------------
jumpTo(100000);act(panel.Header.Close);act(toggle);R.advance(1);R.advance(1)
check(live(pack.BuyWithGems)and live(pack.BuyWithRobux)and txt(pack.Contents)=='LIMITED TIME!','(back in time) the buttons are on again and the card says LIMITED TIME!')
reply.Message="EVENT'S OVER! THANKS FOR PLAYING!"
act(pack.BuyWithGems)
check(calls[#calls][1]=='BuyPack'and panel.Status.Visible and(panel.Status.Text:gsub('\n',' '))=="EVENT'S OVER! THANKS FOR PLAYING!",'a purchase the server refuses shows its message: '..tostring(panel.Status.Text))

-- 5. R157 (owner: "if bag is full and player tries to buy a pack or get a pack via the rolls it says bag full"): a full Bag is not "Unavailable" -----------------------------------------
-- The server flags it (BagFull = true on the offer; both buy flags false). Both buttons read "Bag full" in the dim look of "Unavailable" / "Off sale" but can be pressed: a press shows the game's
-- red notice "BAG FULL! MAKE ROOM FIRST" with the Denied click, sends nothing, opens no prompt. Event over and Off sale come first. With room the buttons are what they were.
-- (R157b review) the notice names the quantity that does not fit ("BAG FULL! MAKE ROOM FOR 10 PACKS FIRST": the Bag is full per quantity), and when the Bag gains room while the shop is open the buttons come back.
do
 local Text=W.module('SimpleGameText')
 local function reopen()jumpTo(100000);act(panel.Header.Close);act(toggle);R.advance(1);R.advance(1)end
 local function sends()local n=0;for _,c in ipairs(calls)do if c[1]=='BuyPack'or c[1]=='RobuxPack'then n+=1 end end;return n end
 reply.Message=nil;reply.OnSale=true
 -- the "Unavailable" look, for comparison (the server turned the offer off for another reason)
 mode.Unavailable=true;reopen()
 check(caption(pack.BuyWithGems)=='Unavailable'and caption(pack.BuyWithRobux)=='Unavailable'and not live(pack.BuyWithGems)and not live(pack.BuyWithRobux),'(control) another reason: both buttons read "Unavailable" and are off')
 local dimGem,dimRobux=pack.BuyWithGems.BackgroundTransparency,pack.BuyWithRobux.BackgroundTransparency
 mode.Unavailable=false
 -- the Bag is full
 mode.BagFull=true;reopen();act(pack.Quantity1) -- (the chip picked in the sections above is still 10)
 check(caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','a full Bag: both Mech buy buttons read "Bag full" ('..tostring(caption(pack.BuyWithGems))..' / '..tostring(caption(pack.BuyWithRobux))..')')
 check(caption(pack.BuyWithGems)==Mech.BagFull.Button,'... the words come from MechCatalog.BagFull.Button')
 check(pack.BuyWithGems.BackgroundTransparency==dimGem and pack.BuyWithRobux.BackgroundTransparency==dimRobux and dimGem>0,'... in the same dim button style as "Unavailable" / "Off sale" ('..tostring(pack.BuyWithGems.BackgroundTransparency)..')')
 check(live(pack.BuyWithGems)and live(pack.BuyWithRobux),'... and they can be pressed (only to show the message)')
 local sent0,notes0,deny0,prompts0=sends(),#notices,plays('Denied'),prompted
 act(pack.BuyWithGems)
 check(#notices==notes0+1 and notices[#notices].Text=='BAG FULL! MAKE ROOM FIRST','a press on the gem button shows the notice "BAG FULL! MAKE ROOM FIRST" ('..tostring(notices[#notices]and notices[#notices].Text)..')')
 check(notices[#notices].Color==Text.Red and notices[#notices].Key==nil,'... in the game\'s red, with no key (so the next press shows it again)')
 check(plays('Denied')==deny0+1,'... and plays the Denied click ('..(plays('Denied')-deny0)..')')
 check(sends()==sent0 and prompted==prompts0,'... nothing is sent to the server and no purchase prompt opens')
 check(Text.Format('BAG FULL! MAKE ROOM FIRST')=='BAG FULL! MAKE ROOM FIRST'and select(2,Text.Format('BAG FULL! MAKE ROOM FIRST'))==Text.Red,'(SimpleGameText keeps the words as they are, in red)')
 check(Text.Format(Mech.BagFullNotice(10))=='BAG FULL! MAKE ROOM FOR 10 PACKS FIRST'and select(2,Text.Format(Mech.BagFullNotice(10)))==Text.Red and select(2,Text.Format(Mech.BagFullNotice(5)))==Text.Red,'(and the words for 5 and 10 packs, also in red)')
 R.advance(1);notes0,deny0=#notices,plays('Denied')
 act(pack.BuyWithRobux)
 check(#notices==notes0+1 and notices[#notices].Text=='BAG FULL! MAKE ROOM FIRST'and plays('Denied')==deny0+1 and sends()==sent0 and prompted==prompts0,'the Robux button does the same: notice, Denied, nothing sent, no prompt')
 notes0,deny0=#notices,plays('Denied');act(pack.BuyWithRobux);act(pack.BuyWithGems)
 check(#notices==notes0 and plays('Denied')==deny0+2,'presses in the same instant show the notice once (no pile-up) but every press clicks Denied')
 for _,count in ipairs({5,10})do act(pack['Quantity'..count])
  check(caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','the '..count..'-pack picked: still "Bag full"')
  local want='BAG FULL! MAKE ROOM FOR '..count..' PACKS FIRST'
  R.advance(1);notes0,deny0=#notices,plays('Denied');act(pack.BuyWithGems)
  check(#notices==notes0+1 and notices[#notices].Text==want and notices[#notices].Text==Mech.BagFullNotice(count)and notices[#notices].Color==Text.Red and plays('Denied')==deny0+1 and sends()==sent0 and prompted==prompts0,'... a gem press says "'..want..'" (the real count), red, Denied, nothing sent ('..tostring(notices[#notices]and notices[#notices].Text)..')')
  R.advance(1);notes0=#notices;act(pack.BuyWithRobux)
  check(#notices==notes0+1 and notices[#notices].Text==want and sends()==sent0 and prompted==prompts0,'... and so does the Robux press')
 end
 -- a server that wrongly still says the buy flags are on: the client never lets a purchase start
 mode.Stale=true;reopen()
 act(pack.Quantity1)
 check(caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','(defensive) BagFull wins over buy flags that are still on: both read "Bag full"')
 R.advance(1);sent0,prompts0=sends(),prompted;act(pack.BuyWithGems);R.advance(1);act(pack.BuyWithRobux)
 check(sends()==sent0 and prompted==prompts0,'... and a press sends nothing')
 mode.Stale=false
 -- Off sale and Event over come first
 reply.OnSale=false;reopen()
 check(caption(pack.BuyWithGems)=='Off sale'and caption(pack.BuyWithRobux)=='Unavailable','Off sale (the flag still set): the gem button says "Off sale", the Robux one "Unavailable" - never "Bag full"')
 reply.OnSale=true
 jumpTo(-3);act(panel.Header.Close);act(toggle);R.advance(1);R.advance(1)
 check(caption(pack.BuyWithGems)=='Event over'and caption(pack.BuyWithRobux)=='Event over'and not live(pack.BuyWithGems)and not live(pack.BuyWithRobux),'Event over (the flag still set): both read "Event over" and are off')
 notes0=#notices;act(pack.BuyWithGems);act(pack.BuyWithRobux)
 check(#notices==notes0 and sends()==sent0,'... and a press shows no bag notice and sends nothing')
 -- room again: back to normal
 mode.BagFull=false;reopen()
 check(caption(pack.BuyWithGems)=='80'and caption(pack.BuyWithRobux)=='80 Robux'and live(pack.BuyWithGems)and live(pack.BuyWithRobux)and pack.BuyWithGems.BackgroundTransparency==0,'with room: the buttons are what they were (80 / 80 Robux, on, full colour)')
 notes0,sent0=#notices,sends();act(pack.BuyWithGems)
 check(sends()==sent0+1 and calls[#calls][1]=='BuyPack'and #notices==notes0,'... a press buys (BuyPack goes to the server) and shows no bag notice')

 -- R157b review: the Bag is full PER QUANTITY. At 195 of 200 the 1-pack and the 5-pack fit and the 10-pack does not: the button reads "Bag full" for the 10-pack only, and its notice names the 10 packs
 local later=0
 local function reopenLater()later+=1;jumpTo(100000-later*5000);act(panel.Header.Close);act(toggle);R.advance(1);R.advance(1)end -- (always later than the sections above: the notice's 0.7 s guard reads the clock)
 mode.FullFor={[10]=true};reopenLater();act(pack.Quantity1)
 check(caption(pack.BuyWithGems)=='80'and caption(pack.BuyWithRobux)=='80 Robux'and live(pack.BuyWithGems)and live(pack.BuyWithRobux),'195 of 200, the 1-pack picked: both buttons are on (80 / 80 Robux)')
 act(pack.Quantity5);check(caption(pack.BuyWithGems)~='Bag full'and caption(pack.BuyWithRobux)~='Bag full'and live(pack.BuyWithGems)and live(pack.BuyWithRobux),'... the 5-pack picked: still on (it fits)')
 act(pack.Quantity10);R.advance(1)
 check(caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','... the 10-pack picked: both read "Bag full" (the button text is the same for any quantity)')
 notes0,sent0=#notices,sends();act(pack.BuyWithGems)
 check(#notices==notes0+1 and notices[#notices].Text=='BAG FULL! MAKE ROOM FOR 10 PACKS FIRST','... and the notice is exact: "BAG FULL! MAKE ROOM FOR 10 PACKS FIRST" ('..tostring(notices[#notices]and notices[#notices].Text)..')')
 act(pack.Quantity1);R.advance(1);notes0,sent0=#notices,sends();act(pack.BuyWithGems)
 check(sends()==sent0+1 and calls[#calls][1]=='BuyPack'and calls[#calls][2]==1 and #notices==notes0,'... back on the single pack a press buys it, with no bag notice')
 mode.FullFor=nil

 -- R157b review: a "Bag full" press never asks the server, so room made in the Bag while the shop is open must reach the buttons by itself. The 200 cap publishes HeldItemCount / HeldItemCap on the
 -- player (the Bag's "143/200"): the shop reads State again when they change (at most once every 0.5 s, never while shut, after a request in flight when one is running)
 local function stateReads(from)local n=0;for i=from+1,#calls do if calls[i][1]=='State'then n+=1 end end;return n end
 act(panel.Header.Close);player:SetAttribute('HeldItemCount',200);player:SetAttribute('HeldItemCap',200)
 mode.BagFull=true;reopenLater()
 check(caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','200 of 200 with the shop open: both read "Bag full"')
 local c0=#calls
 mode.BagFull=false;player:SetAttribute('HeldItemCount',199);R.advance(.01)
 check(stateReads(c0)==1,'room is made while the shop is open (HeldItemCount 200 -> 199): the shop reads State again by itself ('..stateReads(c0)..')')
 check(caption(pack.BuyWithGems)=='80'and caption(pack.BuyWithRobux)=='80 Robux'and live(pack.BuyWithGems)and live(pack.BuyWithRobux)and not pack.BuyWithGems:GetAttribute('BagFull'),'... and both buttons are back on (80 / 80 Robux), no longer "Bag full"')
 notes0,sent0=#notices,sends();R.advance(1);act(pack.BuyWithGems)
 check(sends()==sent0+1 and calls[#calls][1]=='BuyPack'and #notices==notes0,'... a press now buys instead of showing the notice')
 -- the other way: the Bag fills while the shop is open, the buttons read "Bag full" without a press
 R.advance(1);c0=#calls;mode.BagFull=true;player:SetAttribute('HeldItemCount',200);R.advance(.01)
 check(stateReads(c0)==1 and caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','the Bag fills (199 -> 200): the buttons read "Bag full" at once')
 -- the cap changing counts too, and so does a carried pack (it keeps its place in the Bag: Data:RoomFor counts it)
 R.advance(1);c0=#calls;mode.BagFull=false;player:SetAttribute('HeldItemCap',250);R.advance(.01)
 check(stateReads(c0)==1 and caption(pack.BuyWithGems)=='80','HeldItemCap changes (200 -> 250): read again ('..stateReads(c0)..')')
 R.advance(1);c0=#calls;player:SetAttribute('ChestChaseSeedCarrying',true);R.advance(.01)
 check(stateReads(c0)==1,'a pack carried home (ChestChaseSeedCarrying) is read too ('..stateReads(c0)..')')
 player:SetAttribute('ChestChaseSeedCarrying',nil)
 -- throttled: 20 changes in one second are read at most once every half second, and the last one is not lost
 R.advance(1);c0=#calls
 for i=1,20 do player:SetAttribute('HeldItemCount',100+i);R.advance(.05)end
 R.advance(1)
 local reads,last,gapsOk=stateReads(c0),nil,true
 for i=c0+1,#calls do if calls[i][1]=='State'then if last and calls[i][3]-last<.5-1e-6 then gapsOk=false end;last=calls[i][3]end end
 check(reads>=2 and reads<=3,'20 changes in one second: 2 or 3 reads ('..reads..'), not 20')
 check(gapsOk,'... never two reads less than half a second apart')
 R.advance(1);mode.BagFull=false;player:SetAttribute('HeldItemCount',150);R.advance(.01) -- (a read now)
 mode.BagFull=true;player:SetAttribute('HeldItemCount',200);R.advance(.1)
 check(caption(pack.BuyWithGems)~='Bag full','a change right after a read waits (the half second is not over)')
 R.advance(.5)
 check(caption(pack.BuyWithGems)=='Bag full'and caption(pack.BuyWithRobux)=='Bag full','... and is read when the half second is over (the last change is not lost)')
 -- a shut shop reads nothing
 mode.BagFull=false;act(panel.Header.Close);R.advance(1);c0=#calls
 player:SetAttribute('HeldItemCount',10);player:SetAttribute('HeldItemCap',200);player:SetAttribute('ChestChaseSeedCarrying',true);R.advance(2)
 check(stateReads(c0)==0,'a shut shop reads nothing when the Bag changes ('..stateReads(c0)..')')
 player:SetAttribute('ChestChaseSeedCarrying',nil);R.advance(1)
 -- a change while a request is in flight is read when that request is done (once), not dropped and not doubled
 c0=#calls;mode.Hook=function()player:SetAttribute('HeldItemCount',77);R.advance(1)end
 act(toggle);R.advance(.01)
 check(panel.Visible and stateReads(c0)==2,'a change in the middle of a request is read right after it (2 reads: the opening one and the follow-up) ('..stateReads(c0)..')')
 check(caption(pack.BuyWithGems)=='80'and live(pack.BuyWithGems),'... and the shop is as the last State says')
 player:SetAttribute('HeldItemCount',nil);player:SetAttribute('HeldItemCap',nil)
end

print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
