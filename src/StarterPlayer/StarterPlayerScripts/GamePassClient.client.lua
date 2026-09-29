-- R79: compact pack, pass, cash and speed pages; durable pass gifting.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Market=game:GetService('MarketplaceService');local Run=game:GetService('RunService')
local player=Players.LocalPlayer;local pg=player:WaitForChild('PlayerGui');local Theme=require(RS:WaitForChild('GardenTheme'));local Passes=require(RS:WaitForChild('GamePassCatalog'))
local Pricing=require(RS.PremiumPricing);local Catalog=require(RS:WaitForChild('MechCatalog'));local Cash=require(RS:WaitForChild('CashNumbers'));local Audio=require(RS:WaitForChild('InteractionAudio'))
local Bright=require(RS.BrightUI);local Preview=require(RS.CollectionViewport);local Artwork=require(RS.HudArtwork)
local request=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('PremiumRequest')
local old=pg:FindFirstChild('GardenPasses');if old then old:Destroy()end
local gui=Instance.new('ScreenGui');gui.Name='GardenPasses';gui.ResetOnSpawn=false;gui.DisplayOrder=34;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
local function label(parent,name,text,pos,size,font,color)
 local x=Instance.new('TextLabel');x.Name=name;x.Text=text;x.Position=pos;x.Size=size;x.BackgroundTransparency=1;x.TextXAlignment=Enum.TextXAlignment.Left;x.TextWrapped=true
 Bright.Text(x,font or 16,color or Theme.Colors.Text);x.Parent=parent;return x
end
local function button(parent,name,text,pos,size,color)
 local b=Instance.new('TextButton');b.Name=name;b.Text=text;b.Position=pos;b.Size=size;b.BorderSizePixel=0;b.BackgroundColor3=color or Theme.Colors.Mint
 b.TextSize=18;Bright.Button(b,color or Theme.Colors.Mint);b.Parent=parent;return b
end
local toggle=button(gui,'PassesButton','',UDim2.new(0,18,.5,42),UDim2.fromOffset(68,68),Color3.fromRGB(125,222,44));toggle.AnchorPoint=Vector2.new(0,.5);toggle.TextSize=12
local shopIcon=Artwork.Attach(toggle,'RobuxShop');shopIcon.Position=UDim2.fromOffset(5,0);shopIcon.Size=UDim2.new(1,-10,1,-11)
local caption=label(toggle,'Caption','SHOP',UDim2.new(0,0,1,-19),UDim2.new(1,0,0,18),14);caption.TextXAlignment=Enum.TextXAlignment.Center
require(RS.HudLayout).Navigation(toggle,3)
local shade=button(gui,'Shade','',UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.new());shade.BackgroundTransparency=.4;shade.Visible=false;shade:FindFirstChild('BrightFill'):Destroy();shade:FindFirstChild('BrightOutline'):Destroy()
require(RS.MenuBackdrop).Attach(gui,shade,false)
local panel=Instance.new('Frame');panel.Name='PremiumShop';panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.new(.94,0,.9,0);panel.BackgroundColor3=Theme.Colors.Panel;panel.BorderSizePixel=0;panel.Visible=false;panel.Parent=gui;Bright.Panel(panel)
local limit=Instance.new('UISizeConstraint');limit.MaxSize=Vector2.new(1050,800);limit.Parent=panel
local header=Instance.new('Frame');header.Name='Header';header.Size=UDim2.new(1,0,0,60);header.BorderSizePixel=0;header.Parent=panel;Bright.Header(header)
label(header,'Title','SHOP',UDim2.fromOffset(18,2),UDim2.new(1,-90,1,-4),36)
local close=button(header,'Close','X',UDim2.new(1,-54,0,8),UDim2.fromOffset(44,44),Color3.fromRGB(255,57,81))
local connections={};local reveals={};local giftDialog;local fitPanel
local Layout=require(RS.PremiumLayout)
local function watch(signal,fn)local c=signal:Connect(fn);table.insert(connections,c);return c end
local tabs,pages={},{};local selected='Packs';local busy=false;local state={};local refresh;local packInfos={};local packCount=1;local quantityButtons={}
for i,name in ipairs({'Packs','Passes','Cash','Speed','Gems'})do
 local tab=button(panel,name..'Tab',name:upper(),UDim2.new((i-1)/5,12,0,69),UDim2.new(1/5,-14,0,36),Theme.Colors.Card);tab.TextSize=16;require(RS.GardenTextFit).Attach(tab,16,11);tabs[name]=tab
 local page=Instance.new('ScrollingFrame');page.Name=name;page.BackgroundTransparency=1;page.BorderSizePixel=0;page.Position=UDim2.fromOffset(12,115);page.Size=UDim2.new(1,-24,1,-155);page.CanvasSize=UDim2.new();page.AutomaticCanvasSize=Enum.AutomaticSize.Y;page.ScrollBarThickness=4;page.Visible=false;page.Parent=panel;pages[name]=page
 local layout=Instance.new('UIListLayout');layout.Padding=UDim.new(0,12);layout.SortOrder=Enum.SortOrder.LayoutOrder;layout.Parent=page
 tab.Activated:Connect(function()pg:SetAttribute('PremiumPage',name)end)
end
local status=label(panel,'Status','',UDim2.new(0,14,1,-40),UDim2.new(1,-28,0,32),13,Theme.Colors.Mint)
local function selectPage(name)
 if name=='Perks'then name='Passes'end
 selected=pages[name]and name or'Packs'
 for key,page in pairs(pages)do page.Visible=key==selected;Bright.Button(tabs[key],key==selected and Theme.Colors.Mint or Color3.fromRGB(81,105,188));tabs[key].TextColor3=Theme.Colors.Text end
end
local function card(page,name,height)
 local f=Instance.new('Frame');f.Name=name;f.Size=UDim2.new(1,-6,0,height);f.BackgroundColor3=Theme.Colors.Card;f.BorderSizePixel=0;f.Parent=pages[page];Bright.Card(f,Color3.fromRGB(82,178,255),false);return f
end
local pack=card('Packs','LimitedMechPack',596)
Bright.Card(pack,Color3.fromRGB(46,220,255),true);pack.ClipsDescendants=true
require(RS.PackViewport89).DecorateCard(pack)
local banner=Instance.new('Frame');banner.Name='ChromaticBanner';banner.Size=UDim2.new(1,-20,0,5);banner.Position=UDim2.fromOffset(10,8);banner.BackgroundColor3=Color3.new(1,1,1);banner.BorderSizePixel=0;banner.Parent=pack
local rainbow=Instance.new('UIGradient');rainbow.Color=ColorSequence.new(Color3.fromRGB(94,229,243),Color3.fromRGB(248,187,84));rainbow.Parent=banner
local packTitle=label(pack,'Name','MECH PACK',UDim2.fromOffset(16,25),UDim2.new(1,-32,0,49),38);packTitle.TextXAlignment=Enum.TextXAlignment.Center;packTitle.TextWrapped=false;require(RS.GardenTextFit).Attach(packTitle,38,22)
require(RS.GuiShine).Attach(pack,false)
local limited=label(pack,'Contents','LIMITED',UDim2.fromOffset(16,78),UDim2.new(1,-32,0,27),19,Color3.fromRGB(255,206,111));limited.TextXAlignment=Enum.TextXAlignment.Center
require(RS.PackViewport89).Create(pack)
local outcomes=Instance.new('Frame');outcomes.Name='Outcomes';outcomes.Position=UDim2.fromOffset(14,282);outcomes.Size=UDim2.new(1,-28,0,278);outcomes.BackgroundTransparency=1;outcomes.Parent=pack
local outcomeGrid=Instance.new('UIGridLayout');outcomeGrid.CellPadding=UDim2.fromOffset(8,8);outcomeGrid.SortOrder=Enum.SortOrder.LayoutOrder;outcomeGrid.Parent=outcomes
for i,s in ipairs(Catalog.Seeds)do
 local item=Instance.new('TextButton');item.Text='';item.AutoButtonColor=false;item.Name=s.Id;item.LayoutOrder=i;item.BorderSizePixel=0;item.Parent=outcomes;Bright.Card(item,Theme.Rarity(s.Rarity).Accent,true)
 local view=Instance.new('ViewportFrame');view.Name='Plant';view.BackgroundTransparency=1;view.AnchorPoint=Vector2.new(.5,1);view.Position=UDim2.new(.5,0,1,-49);view.Size=UDim2.new(.65+i*.055,-8,.68+i*.02,-30);view.Ambient=Color3.fromRGB(224,225,242);view.LightColor=Color3.new(1,1,1);view.Parent=item
 table.insert(reveals,require(RS.ShopSeedReveal).Attach(item,view,s.Id,player))
 local name=label(item,'Name',s.Name,UDim2.fromOffset(3,2),UDim2.new(1,-6,0,39),16);name.TextXAlignment=Enum.TextXAlignment.Center
 local chance=label(item,'Chance',require(RS.OddsText85).Format(s.Chance),UDim2.new(0,4,1,-34),UDim2.new(1,-8,0,27),21,s.Rarity=='King'and Theme.Colors.Gold or Color3.new(1,1,1));chance.TextXAlignment=Enum.TextXAlignment.Center
end
local function gallerySize()
 local w=outcomes.AbsoluteSize.X>0 and outcomes.AbsoluteSize.X or 300;local cols=w>=700 and 6 or w>=420 and 3 or 2
 local height=cols==6 and 214 or 174;outcomeGrid.CellSize=UDim2.fromOffset(math.floor((w-(cols-1)*8)/cols),height)
 local rows=6/cols;local total=height*rows+(rows-1)*8;outcomes.Size=UDim2.new(1,-28,0,total);pack.Size=UDim2.new(1,-6,0,282+total+128)
end
watch(outcomes:GetPropertyChangedSignal('AbsoluteSize'),gallerySize);gallerySize()
local gemBuy=button(pack,'BuyWithGems',Catalog.GemPrice..' Gems',UDim2.new(0,14,1,-66),UDim2.new(.5,-20,0,49),Color3.fromRGB(44,197,255))
local robuxBuy=button(pack,'BuyWithRobux','Unavailable',UDim2.new(.5,6,1,-66),UDim2.new(.5,-20,0,49),Color3.fromRGB(130,244,60))
for i,offer in ipairs(Catalog.Offers)do
 local b=button(pack,'Quantity'..offer.Count,offer.Count==1 and'SINGLE'or offer.Count..' PACKS',UDim2.new((i-1)/3,14,1,-111),UDim2.new(1/3,-20,0,35),Theme.Colors.Card)
 b.TextSize=15;require(RS.GardenTextFit).Attach(b,15,11);quantityButtons[offer.Count]=b
 b.Activated:Connect(function()if busy then return end;packCount=offer.Count;refresh()end)
end
require(RS.GardenTextFit).Attach(gemBuy,18,12);require(RS.GardenTextFit).Attach(robuxBuy,18,12)
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
local passButtons={}
local boostRow=Instance.new('Frame');boostRow.Name='BoostCards';boostRow.BackgroundTransparency=1;boostRow.Size=UDim2.new(1,-6,0,300);boostRow.Parent=pages.Passes
local boostGrid=Instance.new('UIGridLayout');boostGrid.CellPadding=UDim2.fromOffset(14,14);boostGrid.SortOrder=Enum.SortOrder.LayoutOrder;boostGrid.Parent=boostRow
local boostArt=require(RS.PremiumBoostCard)
for i,pass in ipairs(Passes)do
 local c=boostArt.Create(boostRow,pass,i);local gem=c.GemPerk;local robux=c.RobuxPass
 passButtons[pass.Key]={Gem=gem,Robux=robux,Pass=pass}
 local id=Passes.Id(pass)
 marketplaceInfo(id,Enum.InfoType.GamePass,function(info)passButtons[pass.Key].Info=info end)
end
local function boostSize()
 local w=boostRow.AbsoluteSize.X>0 and boostRow.AbsoluteSize.X or 280;local cols=w>=740 and 2 or 1
 boostGrid.CellSize=UDim2.fromOffset(math.floor((w-(cols-1)*14)/cols),300)
 boostRow.Size=UDim2.new(1,-6,0,cols==2 and 300 or 614)
end
watch(boostRow:GetPropertyChangedSignal('AbsoluteSize'),boostSize);boostSize()
local bundleButtons={}
local BundleArt=require(RS.PremiumBundleCard)
for _,kind in ipairs({'Cash','Speed'})do
 local grid=Instance.new('Frame');grid.Name=kind..'Bundles';grid.BackgroundTransparency=1;grid.Size=UDim2.new(1,-6,0,584);grid.LayoutOrder=1;grid.Parent=pages[kind]
 local rows={}
 for _,row in ipairs(Pricing.Bundles)do if row.Kind==kind then
  local c=BundleArt.Create(grid,row,#rows+1);table.insert(rows,c)
  bundleButtons[row.Key]={Frame=c,Gem=c:FindFirstChild('GemBundle'),Robux=c.RobuxBundle,Row=row}
 end end
 local function layoutBundles()
  local boxes,height=Layout.Bundles(grid.AbsoluteSize.X>0 and grid.AbsoluteSize.X or 300,kind=='Speed'and 268 or 286)
  for i,c in ipairs(rows)do local box=boxes[i];c.Position=UDim2.fromOffset(box.X,box.Y);c.Size=UDim2.fromOffset(box.W,box.H)end
  local size=UDim2.new(1,-6,0,height);if grid.Size~=size then grid.Size=size end
 end
 watch(grid:GetPropertyChangedSignal('AbsoluteSize'),layoutBundles);layoutBundles()
end
local function productInfo(id,done)
 marketplaceInfo(id,Enum.InfoType.Product,done)
end
for _,offer in ipairs(Catalog.Offers)do productInfo(Catalog.ProductId(offer.Count),function(info)packInfos[offer.Count]=info end)end
for _,row in pairs(bundleButtons)do productInfo(Pricing.ProductId(row.Row),function(info)row.Info=info end)end
local gems=card('Gems','ConvertCash',305)
local gemIcon=require(RS.GemIcon).new(gems);gemIcon.Position=UDim2.fromOffset(15,15);gemIcon.Size=UDim2.fromOffset(52,52)
label(gems,'Heading','CASH TO GEMS',UDim2.fromOffset(80,16),UDim2.new(1,-95,0,40),22,Color3.fromRGB(116,222,255))
label(gems,'Rate',Cash.Compact(Catalog.CashPerGem)..' Cash = 1 Gem',UDim2.fromOffset(16,80),UDim2.new(1,-32,0,30),17)
label(gems,'QuantityLabel','How many Gems?',UDim2.fromOffset(16,118),UDim2.new(1,-32,0,24),14)
local quantity=Instance.new('TextBox');quantity.Name='GemQuantity';quantity.Text='1';quantity.ClearTextOnFocus=false;quantity.PlaceholderText='Whole number';quantity.Position=UDim2.fromOffset(16,151);quantity.Size=UDim2.new(1,-112,0,42);quantity.BackgroundColor3=Theme.Colors.Panel;quantity.BorderSizePixel=0;Bright.Text(quantity,20);Theme.Corner(quantity,8);quantity.Parent=gems
local maxButton=button(gems,'Maximum','MAX',UDim2.new(1,-84,0,151),UDim2.fromOffset(68,42))
local cost=label(gems,'Cost','Cost: '..Cash.Compact(Catalog.CashPerGem)..' Cash',UDim2.fromOffset(16,204),UDim2.new(1,-32,0,27),14)
local convert=button(gems,'Convert','CONVERT',UDim2.new(0,16,1,-55),UDim2.new(1,-32,0,42),Color3.fromRGB(98,211,255))
local ways=card('Gems','EarnGems',117)
label(ways,'Title','COMPLETE YOUR PLANT INDEX',UDim2.fromOffset(16,12),UDim2.new(1,-32,0,33),18,Theme.Colors.Gold)
label(ways,'Detail','Collect Gems from your plant index.',UDim2.fromOffset(16,48),UDim2.new(1,-32,0,57),14)
local function active(b,enabled)b.Interactable=enabled;b.Active=enabled;b.AutoButtonColor=enabled;b.BackgroundTransparency=enabled and 0 or .45 end
refresh=function()
 local offer=Catalog.Offer(packCount);local available=state.PackOffers and state.PackOffers[tostring(packCount)]or{}
 local gemLive=available.GemAvailable==true
 gemBuy.Text=state.OnSale==false and'Off sale'or(gemLive and offer.GemPrice..' Gems'or'Unavailable');active(gemBuy,gemLive and not busy)
 local packInfo=packInfos[packCount];local packPrice=packInfo and packInfo.PriceInRobux
 local packLive=available.RobuxAvailable==true and packPrice~=nil and packInfo.IsForSale~=false
 robuxBuy.Text=packLive and(packPrice..' Robux')or'Unavailable';active(robuxBuy,packLive and not busy)
 for count,b in pairs(quantityButtons)do Bright.Button(b,count==packCount and Color3.fromRGB(43,184,216)or Theme.Colors.Card);active(b,not busy)end
 for key,row in pairs(bundleButtons)do
  local quote=state.Bundles and state.Bundles[key]
  row.Quote=quote and quote.Amount and {Key=key,Amount=quote.Amount,GemPrice=quote.GemPrice}or nil
  if row.Gem then active(row.Gem,not busy and row.Quote~=nil);row.Gem.Text=(quote and quote.GemPrice or row.Row.GemPrice)..' Gems'end
  local amount=row.Frame:FindFirstChild('Amount')
  if amount then amount.Text=row.Row.Kind=='Cash'and row.Row.Name or Cash.Compact(row.Row.Amount)end
  local info=row.Info;local ready=quote and quote.Available==true and info and info.IsForSale~=false and info.PriceInRobux~=nil
  row.Robux.Text=ready and(info.PriceInRobux..' Robux')or'Unavailable';active(row.Robux,ready and not busy)
 end
 for _,row in pairs(passButtons)do
  local owned=player:GetAttribute(row.Pass.Attribute)==true
  local ownershipReady=player:GetAttribute(row.Pass.Key..'OwnershipReady')==true
  row.Gem.Text=owned and'Owned'or not ownershipReady and'Checking ownership…'or Catalog.PassGemPrices[row.Pass.Key]..' Gems';active(row.Gem,ownershipReady and not owned and not busy)
  local info=row.Info;row.Robux.Text=owned and'Owned'or info and info.IsForSale and info.PriceInRobux and(info.PriceInRobux..' Robux')or'Unavailable'
  active(row.Robux,not owned and not busy and info~=nil and info.IsForSale==true)
 end
 if giftDialog then giftDialog:Refresh()end
end
local pendingState=false
local function act(action,value,onDone)
 if busy then return end;busy=true;status.Text='';refresh()
 task.spawn(function()
  local okay,result=pcall(request.InvokeServer,request,action,value);busy=false
  if not gui.Parent then return end
  if okay and type(result)=='table'then if result.Gems~=nil then state=result end;status.Text=result.Message or'';if action~='State'and result.Success and action~='RobuxPack'and action~='RobuxBundle'and action~='RobuxGift'then Audio.Transaction('Buy')end
  else status.Text='Please try again.'end;refresh()
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
local giftInfos={}
for _,pass in ipairs(Passes)do productInfo(require(RS.PassGiftCatalog).ProductId(pass.Key),function(info)giftInfos[pass.Key]=info end)end
giftDialog=require(RS.PassGiftDialog).Create(panel,player,act,function()return state end,function(key)return giftInfos[key]end)
for _,row in pairs(passButtons)do
 row.Gem.Parent.GiftPass.Activated:Connect(function()giftDialog:Open(row.Pass)end)
 row.Gem.Activated:Connect(function()if row.Gem.Active then act('BuyPerk',row.Pass.Key)end end)
 row.Robux.Activated:Connect(function()if row.Robux.Active then pcall(Market.PromptGamePassPurchase,Market,player,Passes.Id(row.Pass))end end)
 watch(player:GetAttributeChangedSignal(row.Pass.Attribute),refresh)
 watch(player:GetAttributeChangedSignal(row.Pass.Key..'OwnershipReady'),refresh)
end
local function count()local n=tonumber(quantity.Text);return n and n==n and n%1==0 and n>=1 and n<=9000 and n or nil end
quantity:GetPropertyChangedSignal('Text'):Connect(function()local n=count();cost.Text=n and('Cost: '..Cash.Compact(n*Catalog.CashPerGem)..' Cash')or'Enter 1–9,000 Gems.'end)
maxButton.Activated:Connect(function()local stats=player:FindFirstChild('ChestChaseStats');local cash=stats and stats:FindFirstChild('Cash');quantity.Text=tostring(math.min(9000,math.floor((cash and cash.Value or 0)/Catalog.CashPerGem)))end)
convert.Activated:Connect(function()local n=count();if n then act('Convert',n)else status.Text='Enter a whole number of Gems.'end end)
local function focusBundle()
 local key=pg:GetAttribute('PremiumFocus');local row=bundleButtons[key]
 if not row then return end
 task.defer(function()
  if not gui.Parent or not panel.Visible or not pages[row.Row.Kind].Visible then return end
  local page=pages[row.Row.Kind];local y=row.Frame.AbsolutePosition.Y-page.AbsolutePosition.Y+page.CanvasPosition.Y
  page.CanvasPosition=Vector2.new(0,math.max(0,y-8));pg:SetAttribute('PremiumFocus',nil)
 end)
end
local function open(value)
 local changed=panel.Visible~=value;panel.Visible=value;shade.Visible=value
 if value then selectPage(pg:GetAttribute('PremiumPage')or'Packs');if pg:GetAttribute('SeedMenu')~='Passes'then pg:SetAttribute('SeedMenu','Passes')end;if changed then act('State')end;focusBundle()
 else if giftDialog then giftDialog:Close()end;if pg:GetAttribute('SeedMenu')=='Passes'then pg:SetAttribute('SeedMenu',nil)end end
 -- The shared navigation wheel owns its option visibility.
end
toggle.Activated:Connect(function()open(not panel.Visible)end)
close.Activated:Connect(function()open(false)end);shade.Activated:Connect(function()open(false)end)
watch(pg:GetAttributeChangedSignal('PremiumPage'),function()selectPage(pg:GetAttribute('PremiumPage'))end)
watch(pg:GetAttributeChangedSignal('SeedMenu'),function()open(pg:GetAttribute('SeedMenu')=='Passes')end)
watch(player:GetAttributeChangedSignal('PaidRandomAllowed'),function()if panel.Visible and not busy then act('State')end end)
local stateQueued=false
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
 if giftDialog and giftDialog:IsOpen()and not stateQueued then
  stateQueued=true;task.delay(.7,function()stateQueued=false;if gui.Parent and giftDialog:IsOpen()then if busy then pendingState=true else act('State')end end end)
 end
end)
local statusSerial=0
fitPanel=function()
 local page=pages[selected];local list=page:FindFirstChildOfClass('UIListLayout');local camera=workspace.CurrentCamera
 local viewport=camera and camera.ViewportSize.Y or 720;local height=list and list.AbsoluteContentSize.Y or 450
 local hasStatus=status.Text~='';local target=Layout.PanelHeight(height,viewport,hasStatus)
 local size=UDim2.new(.94,0,0,target);if panel.Size~=size then panel.Size=size end
 local pageSize=UDim2.new(1,-24,1,hasStatus and -155 or -127);if page.Size~=pageSize then page.Size=pageSize end
 status.Visible=hasStatus
end
for _,page in pairs(pages)do local list=page:FindFirstChildOfClass('UIListLayout');watch(list:GetPropertyChangedSignal('AbsoluteContentSize'),function()if page.Visible then fitPanel()end end)end
watch(panel:GetPropertyChangedSignal('AbsoluteSize'),fitPanel)
watch(status:GetPropertyChangedSignal('Text'),function()
 fitPanel();statusSerial+=1;local serial=statusSerial
 if status.Text~=''then task.delay(3,function()if gui.Parent and statusSerial==serial then status.Text=''end end)end
end)
watch(panel:GetPropertyChangedSignal('Visible'),fitPanel)
watch(pg:GetAttributeChangedSignal('PremiumPage'),fitPanel)
gui.Destroying:Connect(function()for _,r in ipairs(reveals)do r.Destroy()end;for _,c in ipairs(connections)do c:Disconnect()end end)
selectPage('Packs');refresh();fitPanel()
