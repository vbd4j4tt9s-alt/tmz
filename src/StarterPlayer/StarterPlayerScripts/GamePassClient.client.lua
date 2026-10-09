do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R120: one scrolling Robux shop (FEATURED, PASSES, SPEED, MONEY, GEMS) with a quick-jump column.
-- Products, prices and every purchase / gift / owned flow are unchanged from R79; only the look and layout moved.
-- R122 (owner): no gift buttons, no "DOUBLE Your SPEED" boost banner, and Robux buttons read "49 Robux" (no glyph).
-- The gift / boost server code stays in place but has no shop entry point.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Market=game:GetService('MarketplaceService')
local Tween=game:GetService('TweenService');local GuiService=game:GetService('GuiService');local UIS=game:GetService('UserInputService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local Theme=require(RS:WaitForChild('GardenTheme'));local Passes=require(RS:WaitForChild('GamePassCatalog'))
local Pricing=require(RS.PremiumPricing);local Catalog=require(RS:WaitForChild('MechCatalog'));local Cash=require(RS:WaitForChild('CashNumbers'));local Audio=require(RS:WaitForChild('InteractionAudio'))
local Bright=require(RS.BrightUI);local Artwork=require(RS.HudArtwork);local Art=require(RS.PremiumShopArt);local Layout=require(RS.PremiumLayout);local Hud=require(RS.HudLayout)
local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local C=Color3.fromRGB
local old=pg:FindFirstChild('GardenPasses');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='GardenPasses';gui.ResetOnSpawn=false;gui.DisplayOrder=34;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local function label(parent,name,text,pos,size,font,color)
 local x=Instance.new('TextLabel');x.Name=name;x.Text=text;x.Position=pos;x.Size=size;x.BackgroundTransparency=1;x.TextXAlignment=Enum.TextXAlignment.Left;x.TextWrapped=true
 Bright.Text(x,font or 16,color or Theme.Colors.Text);x.Parent=parent;return x
end
local function button(parent,name,text,pos,size,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.BackgroundColor3=color or Theme.Colors.Mint
 b.TextSize=18;b.ZIndex=5;Bright.Button(b,color or Theme.Colors.Mint);Art.Stroke(b,Art.Ink,2.5,'BrightOutline');b.Parent=parent;return b
end
local toggle=button(gui,'PassesButton','',UDim2.new(0,18,.5,42),UDim2.fromOffset(68,68),C(125,222,44));toggle.AnchorPoint=Vector2.new(0,.5);toggle.TextSize=12;toggle.ZIndex=1
local shopIcon=Artwork.Attach(toggle,'RobuxShop');shopIcon.Position=UDim2.fromOffset(5,0);shopIcon.Size=UDim2.new(1,-10,1,-11)
local caption=label(toggle,'Caption','SHOP',UDim2.new(0,0,1,-19),UDim2.new(1,0,0,18),14);caption.TextXAlignment=Enum.TextXAlignment.Center
Hud.Navigation(toggle,3)
local shade=button(gui,'Shade','',UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new());shade.ZIndex=1;shade.BackgroundTransparency=.4;shade.Visible=false;shade:FindFirstChild('BrightFill'):Destroy();shade:FindFirstChild('BrightOutline'):Destroy()
require(RS.MenuBackdrop).Attach(gui,shade,false)
-- Panel: green glossy header + dark studded body holding one vertical page.
local panel=Art.Frame(gui,'PremiumShop',C(40,42,52));panel.Visible=false;panel.Active=true;panel.ZIndex=2;Art.Corner(panel,10);Art.Stroke(panel,Art.Ink,4)
local header=Art.Frame(panel,'Header',Color3.new(1,1,1));header.ClipsDescendants=true;header.ZIndex=3;Art.Corner(header,8);Art.Stroke(header,C(22,96,24),2)
Art.Gradient(header,{C(150,255,90),C(84,230,58),C(52,196,40)},90)
Art.LPattern(header,28,2,C(40,150,30),.55);Art.Stripes(header)
local title=Art.Text(header,'Title','Shop',40);title.TextXAlignment=Enum.TextXAlignment.Left;title.ZIndex=4
local close=Instance.new('TextButton');close.Name='Close';close.Text='';close.AutoButtonColor=true;close.BorderSizePixel=0;close.ZIndex=6;close.Parent=header
close.BackgroundColor3=Art.Colors.Close;Art.Corner(close,4);Art.Stroke(close,C(90,6,10),3);Art.Gradient(close,{C(255,70,70),C(214,20,28)},90)
local closeX=Art.Text(close,'X','X',30);closeX.Size=UDim2.fromScale(1,1);closeX.ZIndex=7;close:SetAttribute('AccessibleLabel','Close shop')
local body=Art.Frame(panel,'Body',C(52,54,66));body.ClipsDescendants=true;body.ZIndex=2;Art.Corner(body,8)
Art.Studs(body,10,30,C(30,31,40),.25)
local page=Instance.new('ScrollingFrame');page.Name='Page';page.BackgroundTransparency=1;page.BorderSizePixel=0;page.ScrollBarThickness=6;page.ScrollBarImageColor3=C(200,204,220)
page.ScrollingDirection=Enum.ScrollingDirection.Y;page.CanvasSize=UDim2.new();page.AutomaticCanvasSize=Enum.AutomaticSize.None;page.ElasticBehavior=Enum.ElasticBehavior.WhenScrollable;page.ZIndex=3;page.Parent=body
local status=Art.Text(panel,'Status','',16,Theme.Colors.Mint);status.BackgroundTransparency=.15;status.BackgroundColor3=C(16,18,26);status.ZIndex=12;status.Visible=false;status.TextWrapped=true;Art.Corner(status,8)
-- R148 (owner: "remove this line when purchasing"): the dark strip is only for something worth reading. No message, an empty one or
-- a blank one (a prompt that merely opened has nothing to say) leaves it hidden, never an empty bar.
local function setStatus(text)
 text=type(text)=='string'and text or''
 if text:match('^%s*$')then text=''end
 status.Text=text;status.Visible=text~=''
end
-- Gem purchases the server announces (notice + chime + sparkles, PurchaseCelebration.client.lua): no KaChing on top of the chime.
local celebrated={BuyPack=true,BuyBundle=true,BuyPerk=true,Convert=true}
-- Quick-jump column outside the panel (a row above it in portrait).
local jumpRoot=Art.Frame(gui,'JumpButtons',nil,1);jumpRoot.Visible=false;jumpRoot.ZIndex=2
local SectionColor={Featured=C(255,170,40),Passes=C(255,226,40),Speed=C(70,222,255),Money=C(110,255,70),Gems=C(214,150,255)}
local jumpButtons={}
for i,s in ipairs(Layout.Sections)do
 local b=Instance.new('TextButton');b.Name='Jump'..s.Key;b.Text='';b.AutoButtonColor=false;b.BorderSizePixel=0;b.BackgroundColor3=C(18,20,30);b.BackgroundTransparency=.35;b.LayoutOrder=i;b.Parent=jumpRoot
 Art.Corner(b,10);local ring=Art.Stroke(b,SectionColor[s.Key],3,'Current');ring.Enabled=false
 b:SetAttribute('Section',s.Key);b:SetAttribute('AccessibleLabel','Jump to '..s.Label)
 local icon=Art.Frame(b,'Icon',nil,1);icon.ZIndex=2
 if s.Key=='Featured'then require(RS.PremiumEmblems).Draw(icon,'Featured') -- R125: own logo (was the Mech gem)
 elseif s.Key=='Passes'then require(RS.PremiumEmblems).Draw(icon,'Crown')
 elseif s.Key=='Speed'then require(RS.PremiumEmblems).Draw(icon,'Bolt')
 elseif s.Key=='Money'then require(RS.PremiumEmblems).Draw(icon,'Money')
 else require(RS.GemIcon).new(icon)end
 local name=Art.Text(b,'Label',s.Label,16,SectionColor[s.Key]);name.ZIndex=3
 local scale=Instance.new('UIScale');scale.Parent=b
 jumpButtons[s.Key]=b
end
local connections={};local reveals={}
local function watch(signal,fn)local c=signal:Connect(fn);table.insert(connections,c);return c end
local busy=false;local state:{[string]:any}={};local refresh;local packInfos={};local packCount=1;local quantityButtons={}
local relayout
-- Section titles "-- PASSES --".
local sectionHeaders={}
for _,s in ipairs(Layout.Sections)do if s.Key~='Featured'then
 local t=Art.Text(page,s.Key..'Header','-- '..s.Title..' --',30,SectionColor[s.Key]);t.ZIndex=4;sectionHeaders[s.Key]=t
end end
-- FEATURED: limited Mech pack banner (same products, quantity picker and buttons as before).
local pack=Art.Card(page,'LimitedMechPack',{C(255,196,60),C(255,96,44),C(196,34,74),C(110,30,150)})
pack.Fill.Rotation=100
local packTitle=Art.Text(pack,'PackTitle','LIMITED MECH PACK',34);packTitle.ZIndex=4;packTitle.TextXAlignment=Enum.TextXAlignment.Left
local limited=Art.Text(pack,'Contents',Catalog.Event.Live,20,C(255,236,90));limited.ZIndex=4;limited.TextXAlignment=Enum.TextXAlignment.Right
-- R155: the card's two small lines under the buttons: the coat's odds (next to the seed odds above them: "Gold 4.5% / Diamond 0.5% coat") and the limited event's live countdown to
-- LimitedEvent.EndsAt, in the Index LIMITED tab's format ("⏳ ENDS IN 27d 04h 12m 09s"), on the server's clock. After the end: "EVENT OVER!" / "THANKS FOR PLAYING!" and both buy buttons are off.
local coatNote=Art.Text(pack,'CoatNote',Catalog.CoatLine(),15,C(255,244,190));coatNote.ZIndex=4;coatNote.TextXAlignment=Enum.TextXAlignment.Left
local timerNote=Art.Text(pack,'EventTimer',Catalog.TimerText(workspace:GetServerTimeNow()),15,C(255,236,90));timerNote.ZIndex=4;timerNote.TextXAlignment=Enum.TextXAlignment.Right
local stage=Art.Frame(pack,'PreviewStage',C(20,12,40),.55);stage.ZIndex=2;Art.Corner(stage,10);Art.Stroke(stage,Art.Ink,2)
local packView=require(RS.PackViewport89).Create(stage)
local dock=stage:FindFirstChild('MechDockingBay');if dock then dock.Visible=false end
packView.AnchorPoint=Vector2.zero;packView.Position=UDim2.fromScale(0,0);packView.Size=UDim2.fromScale(1,1);packView.ZIndex=3
require(RS.GuiShine).Attach(pack,false)
-- R155 (owner): the pack pity is listed with the odds (the paid-random disclosure): a caption along the bottom of the pack preview
-- (wrapped and scaled by Roblox to the box, never cut: every word of it is the disclosure)
do local pity=Art.Text(stage,'PityRule',require(RS:WaitForChild('PackPity155')).EventDisclosure,13,C(236,222,255));pity.ZIndex=5;pity.TextWrapped=true;pity.TextScaled=true;pity.AnchorPoint=Vector2.new(.5,1);pity.Position=UDim2.new(.5,0,1,-3);pity.Size=UDim2.new(1,-10,.26,0);pity.BackgroundColor3=C(20,12,40);pity.BackgroundTransparency=.25;Art.Corner(pity,6)
 local fit=Instance.new('UITextSizeConstraint');fit.MinTextSize=7;fit.MaxTextSize=13;fit.Parent=pity;local pad=Instance.new('UIPadding');pad.PaddingLeft=UDim.new(0,4);pad.PaddingRight=UDim.new(0,4);pad.Parent=pity end
local outcomes=Art.Frame(pack,'Outcomes',nil,1);outcomes.ZIndex=3
for i,s in ipairs(Catalog.Seeds)do
 local item=Instance.new('TextButton');item.Text='';item.AutoButtonColor=false;item.Name=s.Id;item.LayoutOrder=i;item.BorderSizePixel=0;item.BackgroundColor3=Color3.new(1,1,1);item.ZIndex=3;item.Parent=outcomes
 local accent=Theme.Rarity(s.Rarity).Accent;Art.Corner(item,6);Art.Stroke(item,Art.Ink,2);Art.Gradient(item,{accent:Lerp(Color3.new(1,1,1),.25),accent:Lerp(C(20,10,40),.55)},90)
 local view=Instance.new('ViewportFrame');view.Name='Plant';view.BackgroundTransparency=1;view.Position=UDim2.fromScale(.04,.02);view.Size=UDim2.fromScale(.92,.8);view.Ambient=C(224,225,242);view.LightColor=Color3.new(1,1,1);view.ZIndex=4;view.Parent=item
 table.insert(reveals,require(RS.ShopSeedReveal).Attach(item,view,s.Id,player))
 local name=Art.Text(item,'SeedName',s.Name,12);name.ZIndex=5;name.TextWrapped=true
 local chance=Art.Text(item,'Chance',require(RS.OddsText85).Format(s.Chance),18,s.Rarity=='King'and Theme.Colors.Gold or Color3.new(1,1,1));chance.ZIndex=6;chance.TextXAlignment=Enum.TextXAlignment.Right
end
local BundleArt=require(RS.PremiumBundleCard)
local gemBuy=Art.Button(pack,'BuyWithGems',Art.Colors.Gem,'Gem')
local robuxBuy=Art.Button(pack,'BuyWithRobux',Art.Colors.Robux)
for _,offer in ipairs(Catalog.Offers)do
 local b=button(pack,'Quantity'..offer.Count,offer.Count==1 and'SINGLE'or offer.Count..' PACKS',UDim2.new(),UDim2.new(),C(70,74,96))
 b.TextSize=15;require(RS.GardenTextFit).Attach(b,15,10);quantityButtons[offer.Count]=b
 b.Activated:Connect(function()if busy then return end;packCount=offer.Count;refresh()end)
end
-- Retry transient metadata failures without displaying a made-up Robux price.
local function marketplaceInfo(id,kind,done)
 if id<=0 then return end
 task.spawn(function()
  for attempt=1,5 do
   if not gui.Parent then return end
   local okay,info=pcall(Market.GetProductInfoAsync,Market,id,kind)
   if not gui.Parent then return end
   if okay and type(info)=='table'and type(info.PriceInRobux)=='number'then
    done(info);if refresh then refresh()end;return
   end
   if attempt<5 then task.wait(2^(attempt-1))end
  end
 end)
end
-- PASSES: one card per pass; the Speed pass also gets the SPEED banner. Every view of a pass shares its state.
local passButtons={};local passViews={}
local boostArt=require(RS.PremiumBoostCard)
for i,pass in ipairs(Passes)do
 local c=boostArt.Create(page,pass,i)
 local row={Gem=c.GemPerk,Robux=c.RobuxPass,Pass=pass,Views={}}
 passButtons[pass.Key]=row
 table.insert(row.Views,{Card=c,Gem=c.GemPerk,Robux=c.RobuxPass})
 marketplaceInfo(Passes.Id(pass),Enum.InfoType.GamePass,function(info)passButtons[pass.Key].Info=info;if pass.Icon=='Clover'then pcall(function()require(RS.CloverIcon153).SetInfo(info)end)end end) -- R153: the pass's own icon (IconImageAssetId) is the clover's first choice
end
for _,row in pairs(passButtons)do for _,v in ipairs(row.Views)do table.insert(passViews,v)end end
-- SPEED and MONEY bundles.
local bundleButtons={};local bundleOrder={Speed={},Cash={}}
for _,kind in ipairs({'Speed','Cash'})do
 for _,row in ipairs(Pricing.Bundles)do if row.Kind==kind then
  local list=bundleOrder[kind];local c=BundleArt.Create(page,row,#list+1);table.insert(list,row.Key)
  bundleButtons[row.Key]={Frame=c,Gem=c:FindFirstChild('GemBundle'),Robux=c.RobuxBundle,Row=row}
 end end
end
local function productInfo(id,done)
 marketplaceInfo(id,Enum.InfoType.Product,done)
end
for _,offer in ipairs(Catalog.Offers)do productInfo(Catalog.ProductId(offer.Count),function(info)packInfos[offer.Count]=info end)end
for _,row in pairs(bundleButtons)do productInfo(Pricing.ProductId(row.Row),function(info)row.Info=info end)end
-- GEMS: cash -> gems converter (unchanged rules) and the index tip.
local gems=Art.Card(page,'ConvertCash',{C(120,226,255),C(70,140,250),C(110,70,230)})
local gemIcon=require(RS.GemIcon).new(gems);gemIcon.ZIndex=3
local gemHeading=Art.Text(gems,'Heading','CASH TO GEMS',26,C(190,246,255));gemHeading.ZIndex=4;gemHeading.TextXAlignment=Enum.TextXAlignment.Left
local rate=Art.Text(gems,'Rate',Cash.Compact(Catalog.CashPerGem)..' Cash = 1 Gem',18);rate.ZIndex=4;rate.TextXAlignment=Enum.TextXAlignment.Left
local quantityLabel=Art.Text(gems,'QuantityLabel','How many Gems?',15);quantityLabel.ZIndex=4;quantityLabel.TextXAlignment=Enum.TextXAlignment.Left
local quantity=Instance.new('TextBox');quantity.Name='GemQuantity';quantity.Text='1';quantity.ClearTextOnFocus=false;quantity.PlaceholderText='Type a number';quantity.BackgroundColor3=C(24,26,40);quantity.BorderSizePixel=0;quantity.ZIndex=5;Bright.Text(quantity,20);Theme.Corner(quantity,8);Art.Stroke(quantity,Art.Ink,2);quantity.Parent=gems
local maxButton=button(gems,'Maximum','MAX',UDim2.new(),UDim2.new(),C(255,196,52))
local cost=Art.Text(gems,'Cost','Cost: '..Cash.Compact(Catalog.CashPerGem)..' Cash',15);cost.ZIndex=4;cost.TextXAlignment=Enum.TextXAlignment.Left
local convert=button(gems,'Convert','CONVERT',UDim2.new(),UDim2.new(),C(98,211,255))
local ways=Art.Card(page,'EarnGems',{C(90,94,124),C(58,60,86)},false)
local waysTitle=Art.Text(ways,'Title','FILL UR PLANT INDEX',20,Theme.Colors.Gold);waysTitle.ZIndex=4;waysTitle.TextXAlignment=Enum.TextXAlignment.Left
local waysDetail=Art.Text(ways,'Detail','Grab Gems from ur plant index!',15);waysDetail.ZIndex=4;waysDetail.TextXAlignment=Enum.TextXAlignment.Left
local function active(b,enabled)b.Interactable=enabled;b.Active=enabled;b.AutoButtonColor=enabled;b.BackgroundTransparency=enabled and 0 or .45 end
local layoutKey;local content;local frame
local function setPrice(b,text,icon,color)Art.SetCaption(b,text,icon,color)end
-- R155: the limited event's clock (the server's) -> the card's words and its two buy buttons. Writes only a change; a flip (the event ending while the shop is open) refreshes the buttons.
local eventOver
local function updateEvent()
 local now=workspace:GetServerTimeNow();local over=Catalog.EventOver(now)
 local live=over and Catalog.Event.Over or Catalog.Event.Live;if limited.Text~=live then limited.Text=live end
 local text=Catalog.TimerText(now);if timerNote.Text~=text then timerNote.Text=text end
 timerNote.TextColor3=over and C(255,255,255)or C(255,236,90)
 if eventOver~=over then eventOver=over;if refresh then refresh()end end
end
refresh=function()
 local offer=Catalog.Offer(packCount);local available=state.PackOffers and state.PackOffers[tostring(packCount)]or{}
 local over=Catalog.EventOver(workspace:GetServerTimeNow());eventOver=over -- R155: after the end both buy buttons say "Event over" and are off (the server refuses a new purchase too)
 local gemLive=available.GemAvailable==true and not over
 setPrice(gemBuy,over and Catalog.Event.Button or state.OnSale==false and'Off sale'or(gemLive and tostring(offer.GemPrice)or'Unavailable'),gemLive);active(gemBuy,gemLive and not busy)
 local packInfo=packInfos[packCount];local packPrice=packInfo and packInfo.PriceInRobux
 local packLive=available.RobuxAvailable==true and packPrice~=nil and packInfo.IsForSale~=false and not over
 setPrice(robuxBuy,over and Catalog.Event.Button or packLive and Art.RobuxText(packPrice)or'Unavailable',packLive);active(robuxBuy,packLive and not busy)
 for count,b in pairs(quantityButtons)do Bright.Button(b,count==packCount and C(255,186,40)or C(70,74,96));Art.Stroke(b,Art.Ink,2.5,'BrightOutline');b:SetAttribute('Selected',count==packCount);active(b,not busy)end
 for key,row in pairs(bundleButtons)do
  local quote=state.Bundles and state.Bundles[key]
  row.Quote=quote and quote.Amount and {Key=key,Amount=quote.Amount,GemPrice=quote.GemPrice}or nil
  if row.Gem then active(row.Gem,not busy and row.Quote~=nil);setPrice(row.Gem,tostring(quote and quote.GemPrice or row.Row.GemPrice))end
  local amount=row.Frame:FindFirstChild('Amount')
  if amount then amount.Text=BundleArt.AmountText(row.Row)end
  local info=row.Info;local ready=quote and quote.Available==true and info and info.IsForSale~=false and info.PriceInRobux~=nil
  setPrice(row.Robux,ready and Art.RobuxText(info.PriceInRobux)or'Unavailable',ready==true);active(row.Robux,ready and not busy)
 end
 local reflow=false
 for _,row in pairs(passButtons)do
  local owned=player:GetAttribute(row.Pass.Attribute)==true
  local ownershipReady=player:GetAttribute(row.Pass.Key..'OwnershipReady')==true
  local info=row.Info;local forSale=info~=nil and info.IsForSale==true and info.PriceInRobux~=nil
  for _,v in ipairs(row.Views)do
   if v.Gem.Visible==owned then v.Gem.Visible=not owned;reflow=true end
   -- R153: a pass that is Gem-only until it has a Robux id (Passes.RobuxSoon) has no Robux button and says ROBUX SOON; once it is owned the button is back and reads OWNED, the tag PERMANENT
   local soon=Passes.RobuxSoon(row.Pass)and not owned
   if v.Robux.Visible==soon then v.Robux.Visible=not soon;reflow=true end
   local tag=v.Card:FindFirstChild('Permanent');local tagText=soon and'ROBUX SOON'or'PERMANENT'
   if tag and v.Card:GetAttribute('Tag')~=tagText and(soon or v.Card:GetAttribute('Tag')~=nil)then v.Card:SetAttribute('Tag',tagText);tag.Text=tagText end
   setPrice(v.Gem,owned and'Owned'or not ownershipReady and'Checking…'or tostring(Catalog.PassGemPrices[row.Pass.Key]),ownershipReady and not owned);active(v.Gem,ownershipReady and not owned and not busy)
   setPrice(v.Robux,owned and'OWNED'or forSale and Art.RobuxText(info.PriceInRobux)or'Unavailable',forSale and not owned,owned and Art.Colors.Owned or Art.Colors.Robux)
   active(v.Robux,not owned and not busy and info~=nil and info.IsForSale==true)
   v.Card:SetAttribute('Owned',owned)
  end
 end
 if reflow and relayout then relayout(true)end
end
local pendingState=false
local function act(action,value,onDone)
 if busy then return end;busy=true;setStatus('');refresh()
 task.spawn(function()
  local okay,result=pcall(request.InvokeServer,request,action,value);busy=false
  if not gui.Parent then return end
  if okay and type(result)=='table'then if result.Gems~=nil then state=result end;setStatus(result.Message);if action~='State'and result.Success==false then Audio.Play('Denied')end -- R150: a refused purchase
  if action~='State'and result.Success and action~='RobuxPack'and action~='RobuxBundle'and action~='RobuxGift'and not celebrated[action]then Audio.Transaction('Buy')end
  else setStatus('Try again in a sec!');if action~='State'then Audio.Play('Denied')end end;refresh()
  if onDone then onDone(okay and result or nil)end
  if pendingState and not busy then pendingState=false;if panel.Visible then act('State')end end
 end)
end
gemBuy.Activated:Connect(function()if gemBuy.Active then act('BuyPack',packCount)end end)
robuxBuy.Activated:Connect(function()if robuxBuy.Active then act('RobuxPack',packCount)end end)
for key,row in pairs(bundleButtons)do
 if row.Gem then row.Gem.Activated:Connect(function()if row.Gem.Active then act('BuyBundle',row.Quote)end end)end
 row.Robux.Activated:Connect(function()if row.Robux.Active then act('RobuxBundle',key)end end)
end
for _,row in pairs(passButtons)do
 for _,v in ipairs(row.Views)do
  v.Gem.Activated:Connect(function()if v.Gem.Active then act('BuyPerk',row.Pass.Key)end end)
  v.Robux.Activated:Connect(function()if v.Robux.Active then pcall(Market.PromptGamePassPurchase,Market,player,Passes.Id(row.Pass))end end)
 end
 watch(player:GetAttributeChangedSignal(row.Pass.Attribute),refresh)
 watch(player:GetAttributeChangedSignal(row.Pass.Key..'OwnershipReady'),refresh)
end
local function count()local n=tonumber(quantity.Text);return n and n==n and n%1==0 and n>=1 and n<=9000 and n or nil end
quantity:GetPropertyChangedSignal('Text'):Connect(function()local n=count();cost.Text=n and('Cost: '..Cash.Compact(n*Catalog.CashPerGem)..' Cash')or'Pick 1–9,000 Gems.'end)
maxButton.Activated:Connect(function()local stats=player:FindFirstChild('ChestChaseStats');local cash=stats and stats:FindFirstChild('Cash');quantity.Text=tostring(math.min(9000,math.floor((cash and cash.Value or 0)/Catalog.CashPerGem)))end)
convert.Activated:Connect(function()local n=count();if n then act('Convert',n)else setStatus('Type a whole number of Gems.')end end)
-- Layout ----------------------------------------------------------------------------------------
local function place(item,r,dx,dy)item.Position=UDim2.fromOffset(r.X+(dx or 0),r.Y+(dy or 0));item.Size=UDim2.fromOffset(r.W,r.H)end
local function viewport()
 local size=gui.AbsoluteSize
 if size and size.X>0 and size.Y>0 then return size end
 return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
end
local function layoutFeatured(f,k,button)
 local w=content.Cards.Featured.W
 local p=f.Pad
 if f.Wide then
  -- Title left, "LIMITED TIME!" right; the subtitle drops under the title when the row is too tight.
  local titleW=math.floor((w-p*2)*.64)
  place(packTitle,{X=p,Y=p,W=titleW,H=f.TitleH});Art.SetTextSize(packTitle,math.floor(f.TitleH/1.2),12)
  place(limited,{X=p+titleW,Y=p,W=w-p*2-titleW,H=f.TitleH});limited.TextXAlignment=Enum.TextXAlignment.Right
  Art.SetTextSize(limited,math.floor(f.TitleH*.5),10)
 else
  local h1=math.floor(f.TitleH*.58);local h2=f.TitleH-h1
  place(packTitle,{X=p,Y=p,W=w-p*2,H=h1});Art.SetTextSize(packTitle,math.floor((h1-2)/1.16),12)
  place(limited,{X=p,Y=p+h1,W=w-p*2,H=h2});limited.TextXAlignment=Enum.TextXAlignment.Left
  Art.SetTextSize(limited,math.floor((h2-2)/1.16),10)
 end
 place(coatNote,f.Coat);Art.SetTextSize(coatNote,math.floor(f.Coat.H*.78),9);place(timerNote,f.Timer);Art.SetTextSize(timerNote,math.floor(f.Timer.H*.78),9) -- R155
 if f.Wide then timerNote.TextXAlignment=Enum.TextXAlignment.Right else timerNote.TextXAlignment=Enum.TextXAlignment.Left end
 place(stage,f.Preview)
 local box={X=f.Tiles[1].X,Y=f.Tiles[1].Y,W=f.Tiles[#f.Tiles].X+f.Tiles[#f.Tiles].W-f.Tiles[1].X,H=f.Tiles[#f.Tiles].Y+f.Tiles[#f.Tiles].H-f.Tiles[1].Y}
 place(outcomes,box)
 for i,s in ipairs(Catalog.Seeds)do
  local t=f.Tiles[i];local item=outcomes:FindFirstChild(s.Id)
  if item and t then
   place(item,t,-box.X,-box.Y)
   local nameH=math.max(12,math.floor(math.min(t.H*.2,18*k+4)))
   item.SeedName.Position=UDim2.fromOffset(2,2);item.SeedName.Size=UDim2.fromOffset(t.W-4,nameH);Art.SetTextSize(item.SeedName,math.floor(nameH*.8),8)
   local cH=math.max(14,math.floor(math.min(t.H*.24,22*k+4)))
   item.Chance.Position=UDim2.fromOffset(2,t.H-cH-2);item.Chance.Size=UDim2.fromOffset(t.W-6,cH);Art.SetTextSize(item.Chance,math.floor(cH*.9),10)
   item.Plant.Position=UDim2.fromOffset(2,nameH);item.Plant.Size=UDim2.fromOffset(t.W-4,t.H-nameH-cH*.5)
  end
 end
 for i,offer in ipairs(Catalog.Offers)do local b=quantityButtons[offer.Count];if b and f.Chips[i]then place(b,f.Chips[i]);b.TextSize=math.max(10,math.floor(button*.4))end end
 place(gemBuy,f.Gem);place(robuxBuy,f.Robux);Art.Fit(gemBuy);Art.Fit(robuxBuy)
end
local function layoutGems(r,k,button)
 local p=math.max(6,math.floor(12*k));local w,h=r.W,r.H
 local icon=math.floor(math.min(56*k+8,h*.3))
 gemIcon.Position=UDim2.fromOffset(p,p);gemIcon.Size=UDim2.fromOffset(icon,icon)
 local headH=math.floor(math.max(20,30*k))
 if r.Wide then
  local left=w*.48
  place(gemHeading,{X=p*2+icon,Y=p,W=left-icon-p*2,H=headH});Art.SetTextSize(gemHeading,math.floor(headH*.85),12)
  place(rate,{X=p*2+icon,Y=p+headH,W=left-icon-p*2,H=headH*.75});Art.SetTextSize(rate,math.floor(headH*.6),10)
  place(cost,{X=p,Y=h-p-headH,W=left-p,H=headH*.8});Art.SetTextSize(cost,math.floor(headH*.55),10)
  local rx=left+p;local rw=w-rx-p
  place(quantityLabel,{X=rx,Y=p,W=rw,H=headH*.7});Art.SetTextSize(quantityLabel,math.floor(headH*.55),10)
  local boxY=p+headH*.75+4
  place(quantity,{X=rx,Y=boxY,W=rw-button*1.8-6,H=button});quantity.TextSize=math.max(14,math.floor(button*.5))
  place(maxButton,{X=rx+rw-button*1.8,Y=boxY,W=button*1.8,H=button})
  place(convert,{X=rx,Y=boxY+button+8,W=rw,H=button})
 else
  place(gemHeading,{X=p*2+icon,Y=p,W=w-icon-p*3,H=headH});Art.SetTextSize(gemHeading,math.floor(headH*.85),12)
  place(rate,{X=p*2+icon,Y=p+headH,W=w-icon-p*3,H=headH*.75});Art.SetTextSize(rate,math.floor(headH*.6),10)
  local y=p+math.max(icon,headH*1.75)+6
  place(quantityLabel,{X=p,Y=y,W=w-p*2,H=headH*.7});Art.SetTextSize(quantityLabel,math.floor(headH*.55),10);y+=headH*.7+2
  place(quantity,{X=p,Y=y,W=w-p*3-button*1.8,H=button});quantity.TextSize=math.max(14,math.floor(button*.5))
  place(maxButton,{X=w-p-button*1.8,Y=y,W=button*1.8,H=button});y+=button+4
  place(cost,{X=p,Y=y,W=w-p*2,H=headH*.7});Art.SetTextSize(cost,math.floor(headH*.55),10)
  place(convert,{X=p,Y=h-p-button,W=w-p*2,H=button})
 end
 maxButton.TextSize=math.max(12,math.floor(button*.45));convert.TextSize=math.max(12,math.floor(button*.45))
end
relayout=function(force)
 local size=viewport();local touch=UIS.TouchEnabled;local controls=Hud.Controls(gui)
 local key=string.format('%d:%d:%s',size.X,size.Y,tostring(touch))
 if controls then for name,c in pairs(controls)do key..=string.format(':%s%d,%d,%d,%d',name,c.X,c.Y,c.W,c.H)end end
 if key==layoutKey and not force then return end
 local previous=layoutKey;layoutKey=key
 frame=Layout.Frame(size.X,size.Y,touch,controls)
 local k=frame.K;local P=frame.Panel
 place(panel,P);header.Position=UDim2.fromOffset(0,0);header.Size=UDim2.fromOffset(P.W,frame.Header)
 local cs=frame.Header-12;close.Size=UDim2.fromOffset(cs,cs);close.Position=UDim2.fromOffset(P.W-cs-6,6);Art.SetTextSize(closeX,math.floor(cs*.75),14)
 title.Position=UDim2.fromOffset(14,0);title.Size=UDim2.fromOffset(P.W-cs-40,frame.Header);Art.SetTextSize(title,math.floor(frame.Header*.7),18)
 local inset=math.max(4,math.floor(6*k))
 body.Position=UDim2.fromOffset(inset,frame.Header+2);body.Size=UDim2.fromOffset(P.W-inset*2,P.H-frame.Header-2-inset)
 page.Position=UDim2.fromOffset(0,0);page.Size=UDim2.fromOffset(P.W-inset*2,P.H-frame.Header-2-inset)
 page.ScrollBarThickness=touch and 4 or 6
 local width=P.W-inset*2-page.ScrollBarThickness-2
 content=Layout.Content(width,k,{Passes=#Passes,Speed=#bundleOrder.Speed,Money=#bundleOrder.Cash})
 page.CanvasSize=UDim2.fromOffset(0,content.Height)
 local button=content.Button
 for key2,t in pairs(sectionHeaders)do local r=content.Cards[key2..'Header'];place(t,r);Art.SetTextSize(t,math.floor(r.H*.78),16)end
 place(pack,content.Cards.Featured);layoutFeatured(content.Featured,k,button)
 for i,pass in ipairs(Passes)do local row=passButtons[pass.Key];local r=content.PassCards[i]
  if row and r then local c=row.Views[1].Card;place(c,r);boostArt.Layout(c,r.W,r.H,button,k)end end
 for kind,list in pairs(bundleOrder)do
  local rects=content[(kind=='Cash'and'Money'or kind)..'Cards']
  for i,keyName in ipairs(list)do local row=bundleButtons[keyName];local r=rects[i];row.Rect=r;place(row.Frame,r);BundleArt.Layout(row.Frame,r.W,r.H,button,k)end
 end
 place(gems,content.Cards.Convert);layoutGems(content.Cards.Convert,k,button)
 local e=content.Cards.Earn;place(ways,e)
 local ep=math.max(6,math.floor(12*k))
 place(waysTitle,{X=ep,Y=ep*.6,W=e.W-ep*2,H=e.H*.45});Art.SetTextSize(waysTitle,math.floor(e.H*.32),11)
 place(waysDetail,{X=ep,Y=e.H*.52,W=e.W-ep*2,H=e.H*.36});Art.SetTextSize(waysDetail,math.floor(e.H*.24),10)
 -- Status toast along the bottom of the panel.
 local sh=math.max(26,math.floor(34*k));place(status,{X=inset*2,Y=P.H-sh-inset*2,W=P.W-inset*4,H=sh});Art.SetTextSize(status,math.floor(sh*.5),10)
 -- Jump buttons.
 jumpRoot.Position=UDim2.fromOffset(0,0);jumpRoot.Size=UDim2.fromScale(1,1)
 for i,s in ipairs(Layout.Sections)do
  local b=jumpButtons[s.Key];local r=frame.Buttons[i];place(b,r)
  local labelH=frame.Labels and math.max(12,math.floor(r.H*.28))or 0
  local iconSide=math.min(r.W,r.H-labelH)-8
  b.Icon.Position=UDim2.fromOffset((r.W-iconSide)/2,4);b.Icon.Size=UDim2.fromOffset(iconSide,iconSide)
  b.Label.Visible=frame.Labels;b.Label.Position=UDim2.fromOffset(0,r.H-labelH-2);b.Label.Size=UDim2.fromOffset(r.W,labelH);Art.SetTextSize(b.Label,labelH,9)
 end
 if previous and page.CanvasPosition.Y>math.max(0,content.Height-page.Size.Y.Offset)then page.CanvasPosition=Vector2.new(0,math.max(0,content.Height-page.Size.Y.Offset))end
end
-- Scrolling / jumping ---------------------------------------------------------------------------
local scrollTween;local pinned;local current
local function setCurrent(key)
 if current==key then return end;current=key
 for name,b in pairs(jumpButtons)do
  local on=name==key;b.Current.Enabled=on;b.BackgroundTransparency=on and .05 or .35;b.UIScale.Scale=on and 1.06 or 1;b:SetAttribute('Current',on)
 end
end
local function updateCurrent()
 if not content then return end
 setCurrent(Layout.Current(content,page.CanvasPosition.Y,page.Size.Y.Offset,pinned))
end
local function scrollTo(y,smooth)
 if scrollTween then scrollTween:Cancel();scrollTween=nil end
 y=math.max(0,math.min(y,math.max(0,content.Height-page.Size.Y.Offset)))
 local target=Vector2.new(0,y)
 if smooth and not GuiService.ReducedMotionEnabled and panel.Visible then
  scrollTween=Tween:Create(page,TweenInfo.new(.35,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{CanvasPosition=target});scrollTween:Play()
 else page.CanvasPosition=target end
 page:SetAttribute('TargetY',y)
end
local function goTo(pageName,smooth)
 relayout()
 local key=Layout.PageSection[pageName or'Packs']or'Featured'
 pinned=key;scrollTo(Layout.Target(content,key,page.Size.Y.Offset),smooth);setCurrent(key)
end
for _,s in ipairs(Layout.Sections)do
 jumpButtons[s.Key].Activated:Connect(function()
  if pg:GetAttribute('PremiumPage')==s.Page then goTo(s.Page,true)else pg:SetAttribute('PremiumPage',s.Page)end
 end)
end
watch(page:GetPropertyChangedSignal('CanvasPosition'),updateCurrent)
local function focusBundle()
 local key=pg:GetAttribute('PremiumFocus');local row=bundleButtons[key]
 if not row then return end
 task.defer(function()
  if not gui.Parent or not panel.Visible or not row.Rect then return end
  local headerH=content.Cards[(row.Row.Kind=='Cash'and'Money'or'Speed')..'Header'].H
  scrollTo(row.Rect.Y-headerH-content.Gap,false);pg:SetAttribute('PremiumFocus',nil)
 end)
end
-- R155: the countdown ticks every second while the shop is open (the Index LIMITED tab's way: a token ends the loop when the shop closes).
local tickToken=0
local function startTicking()
 tickToken+=1;local token=tickToken;updateEvent()
 local function tick()
  task.delay(1,function()
   if token~=tickToken or not gui.Parent or not panel.Visible then return end
   updateEvent();tick()
  end)
 end
 tick()
end
local function open(value)
 local changed=panel.Visible~=value
 if value then if changed then startTicking()end else tickToken+=1 end
 if value then relayout()end
 panel.Visible=value;shade.Visible=value;jumpRoot.Visible=value
 if value then pcall(function()require(RS.CloverIcon153).Ensure()end)end -- R153: the clover picture is drawn when the shop opens (once per client)
 if value then
  if changed then goTo(pg:GetAttribute('PremiumPage'),false)end
  if pg:GetAttribute('SeedMenu')~='Passes'then pg:SetAttribute('SeedMenu','Passes')end;if changed then act('State')end;focusBundle()
 else
  if scrollTween then scrollTween:Cancel();scrollTween=nil end
  if pg:GetAttribute('SeedMenu')=='Passes'then pg:SetAttribute('SeedMenu',nil)end
  -- Reopening from the SHOP button starts at the top; other scripts set PremiumPage before opening.
  if changed then pg:SetAttribute('PremiumPage',nil)end
 end
 -- The shared navigation wheel owns its option visibility.
end
toggle.Activated:Connect(function()open(not panel.Visible)end)
close.Activated:Connect(function()open(false)end);shade.Activated:Connect(function()open(false)end)
watch(pg:GetAttributeChangedSignal('PremiumPage'),function()if panel.Visible and pg:GetAttribute('PremiumPage')then goTo(pg:GetAttribute('PremiumPage'),true)end end)
watch(pg:GetAttributeChangedSignal('PremiumFocus'),function()if panel.Visible then focusBundle()end end)
watch(pg:GetAttributeChangedSignal('SeedMenu'),function()open(pg:GetAttribute('SeedMenu')=='Passes')end)
watch(player:GetAttributeChangedSignal('PaidRandomAllowed'),function()if panel.Visible and not busy then act('State')end end)
local productsQueued=false
watch(RS:GetAttributeChangedSignal('PremiumProductsRevision'),function()
 if not panel.Visible or productsQueued then return end
 productsQueued=true;task.delay(.7,function()
  productsQueued=false;if not gui.Parent or not panel.Visible then return end
  if busy then pendingState=true else act('State')end
 end)
end)
watch(player:GetAttributeChangedSignal('PremiumRevision'),function()
 for _,r in ipairs(reveals)do r.Refresh()end
end)
local statusSerial=0
watch(status:GetPropertyChangedSignal('Text'),function()
 status.Visible=status.Text~='';statusSerial+=1;local serial=statusSerial
 if status.Text~=''then task.delay(3,function()if gui.Parent and statusSerial==serial then status.Text=''end end)end
end)
-- Re-layout on viewport, touch and thumb-control changes (HudLayout watches all three).
local stopWatch=Hud.Watch(gui,function()if content then relayout()end end)
watch(GuiService:GetPropertyChangedSignal('ReducedMotionEnabled'),function()if scrollTween and GuiService.ReducedMotionEnabled then scrollTween:Cancel();scrollTween=nil;local y=page:GetAttribute('TargetY');if y then page.CanvasPosition=Vector2.new(0,y)end end end)
gui.Destroying:Connect(function()stopWatch();for _,r in ipairs(reveals)do r.Destroy()end;for _,c in ipairs(connections)do c:Disconnect()end end)
relayout(true);refresh();updateEvent();setCurrent('Featured')
