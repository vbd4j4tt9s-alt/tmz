--!nocheck
-- R158 BUILT picture data (not a test): the PC HUD as the BUILT code draws it (HudLayout's scaled 1920 x 1080 arrangement, MENU a third of the way down with its 85% floor), from the
-- REAL scripts on the Roblox mock, printed as SCENE lines (nested GUI JSON, R153's dump_tree153) for render_gui155.mjs (headless Chromium), which knows UIScale and AnchorPoint:
--   the REAL Hotbar (Bat, Shovel, 8 seeds, Bag), GardenWallet (the three balances with their + buttons), WorldStatusHud (the luck rows, the two timers, THE DARKENED card),
--   PityBars155 (3/10 and 0/10), the wheel (HudLayout.Navigation with SettingsClient, ChestIndex, GamePassClient, DailyRewardsClient), TravelButtons (BASE / TRACK), and HudLayout.
-- Only Roblox's own top bar (a band with its round buttons) and the sky are stand-ins. APPROXIMATE: not a Studio screenshot.
-- Globals (lines in front of this file, run_built158.sh):  SW, SH = the HUD area (what HudLayout sees: the ScreenGuis with CoreUISafeInsets, i.e. UNDER the top bar),
--   TB = the top bar's height (52 on a PC), LEFT, RIGHT = the free part of the top bar row (TopbarInset), WHEEL = 'open' | 'closed' | 'both' (default both),
--   ONLY = which scenes to print, a comma list of all, hud, top (default all of them).
-- Prints  SCENE <name> <cropX> <cropY> <cropW> <cropH> <scale> <json>   (name = <closed|open>_<all|hud|top>:
--   all = the whole screen (the top bar band, then the HUD area under it), hud = only the HUD area (canvas SW x SH), top = only the top bar row with BASE / TRACK)
--   and  INFO <key> <value>  lines (the rectangles the sheet outlines and measures: HUD-area pixels).
local W=require('./world');local R=W.R;local F=require('./fixtures')
Color3=R.Color3 -- (dump_tree153 reads the global)
local dump=require('./dump_tree153')
local V2=R.Vector2.new;local RGB=R.Color3.fromRGB;local Enum=R.Enum
local SW,SH,TB,LEFT,RIGHT,WHEEL,ONLY=SW,SH,TB or 52,LEFT or 140,RIGHT or SW,WHEEL or'both',ONLY or'all,hud,top'
local FULLH=SH+TB
W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;W.UIS.MouseEnabled=true;W.UIS.GamepadEnabled=false
W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=SW,Height=SH}end
W.Gui.TopbarInset={__type='Rect',Min=V2(LEFT,0),Max=V2(RIGHT,TB),Width=RIGHT-LEFT,Height=TB}
W.workspace.CurrentCamera.ViewportSize=V2(SW,SH)
do local inner=R.Instance.new -- (every ScreenGui is born the size of the HUD area; the full-height ones are fixed below)
 R.Instance.new=function(class,parent)local o=inner(class,parent);if class=='ScreenGui'then o.AbsoluteSize=V2(SW,SH);o.AbsolutePosition=V2(0,0)end;return o end
end
local Players=W.service('Players')
local player=R.new('Player');player.Name='Ann';player.UserId=158;player.Parent=Players;Players.LocalPlayer=player;player.CharacterAdded=R.signal();function Players.GetPlayers()return {player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Name='Ann';char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=R.CFrame.new(0,5,50);hrp.Parent=char
-- server state --------------------------------------------------------------------------------------------------------------------------------------
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
for _,n in ipairs({'RequestBaseTeleport','RequestTrackTeleport'})do local e=R.new('RemoteEvent');e.Name=n;e.Parent=remotes end
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog')
local function shop()
 local offers={};for _,o in ipairs(Mech.Offers)do offers[tostring(o.Count)]={Count=o.Count,GemPrice=o.GemPrice,GemAvailable=true,RobuxAvailable=true,RobuxPrice=o.TargetRobuxPrice}end
 local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
 return {PackOffers=offers,Bundles=bundles,GiftProducts={Growth={Available=true},Speed={Available=true}},GiftCredits={},Gems=500,OnSale=true,Success=true,Message=''}
end
local quests={{Key='Steal',Text='Steal 3 packs',Icon='🎒',Goal=3,Progress=3,Claimed=false,Gems=2},{Key='Plant',Text='Plant 3 seeds',Icon='🌱',Goal=3,Progress=1,Claimed=false,Gems=2}}
function request.InvokeServer(_,action,value)
 if action=='Daily'then return {Success=true,Login={Ready=true,Next=1,Claimed=0},Quests=quests,ResetIn=5*3600+12*60,Day=1}end
 if action=='SettingsState'then return {Success=true,Settings={Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=true}}end
 return shop()
end
-- the Index: some seeds found, two rewards waiting (the INDEX button says 2) --------------------------------------------------------------------------
local Rules=W.module('SeedPackRules');local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0
for _,stage in ipairs({1,6,2,3,5,4,7})do
 local odds=Rules.SeedOdds(config,stage,'Pack01',1)
 for _,seed in ipairs(Rules.ObtainablePool(config,stage))do
  index+=1;local e=R.new('Folder');e.Name=seed.Id
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)));e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
 end
end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id,cash)local x=R.new('BoolValue');x.Name=id;x.Value=true;if cash then x:SetAttribute('RewardCash',cash)end;x.Parent=folder end
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do found(seeds,id,id=='MooncapSeed'and 240000 or nil)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do found(plants,id)end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end,Transaction=function()end,Asset=function()return nil end})
W.stub('RarityRevealAudio',{Preload=function()end,Play=function()return true end,Burst=function()end})
W.stub('ShopViewport',{Visible=function()return true end,CachedVisible=function()return true end})
W.stub('ShopSeedReveal',{Attach=function()return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)local x=R.Instance.new('ViewportFrame');x.Name='MechPackPreview';x.Parent=parent;return x end})
local Market=W.service('MarketplaceService');Market.GetProductInfoAsync=function()return{PriceInRobux=399,IsForSale=true}end
local Social=W.service('SocialService');function Social.CanSendGameInviteAsync()return true end;function Social.PromptGameInvite()end
local ENS=W.service('ExperienceNotificationService');function ENS.CanPromptOptInAsync()return true end;function ENS.PromptOptIn()end
W.service('SoundService')
-- the owner's numbers: 802.1M speed, $7T, 84 gems; luck x7.2K (machine 5 x trail 6 x the double pass) and x50M; 3/10 and 0/10 pity; THE DARKENED in 10m 25s; timers 08:40 / 00:15 ----
player:SetAttribute('Gems',84);player:SetAttribute('TutorialDone',true)
player:SetAttribute('TreadmillTier',5);player:SetAttribute('TreadmillMultiplier',6);player:SetAttribute('DoubleSpeedOwned',true);player:SetAttribute('ChestLuckMultiplier',5e7)
local stats=R.new('Folder');stats.Name='ChestChaseStats';stats.Parent=player
local speed=R.new('StringValue');speed.Name='Speed';speed.Value='802100000';speed.Parent=stats
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
W.RS:SetAttribute('GlobalWeather','Clear')
-- inventory: Bat, Shovel and 8 seeds (the Bag button is the eleventh slot)
F.bat(W,bag);F.shovel(W,bag)
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed','CocoaSeed','LanternFernSeed','PineappleSeed','CactusSeed'})do F.seed(W,bag,id,1,'None')end
-- the HUD scripts ----------------------------------------------------------------------------------------------------------------------------------
-- (R158 review: a layout emulation, as R158's tests have it (hud_world158.luau): every GuiObject gets its real AbsoluteSize / AbsolutePosition from its UDim2, AnchorPoint and the UIScales above
-- it, so GardenTextFit - which holds a label's smallest size in real px under a HudScale - sees the box the label really has; the mock's default 100 x 40 made every label look roomy)
local function setAbs(x,k,v)local c=x._props[k];if not c or c.X~=v.X or c.Y~=v.Y then x[k]=v end end
local function lay(x,px,py,pw,ph,ps)
 for _,c in ipairs(x._children)do if c:IsA('GuiObject')then
  local sz,pos=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or V2(0,0)
  if sz and pos then
   local ui=c:FindFirstChildOfClass('UIScale');local k=ui and(ui._props.Scale or 1)or 1
   local lw=sz.X.Scale*(pw/ps)+sz.X.Offset;local lh=sz.Y.Scale*(ph/ps)+sz.Y.Offset
   local rw,rh=lw*ps*k,lh*ps*k
   local ax=px+(pos.X.Scale*(pw/ps)+pos.X.Offset)*ps-a.X*rw;local ay=py+(pos.Y.Scale*(ph/ps)+pos.Y.Offset)*ps-a.Y*rh
   setAbs(c,'AbsoluteSize',V2(rw,rh));setAbs(c,'AbsolutePosition',V2(ax,ay))
   lay(c,ax,ay,rw,rh,ps*k)
  end
 end end
end
local function sized()
 for _,g in ipairs(pg:GetChildren())do
  if g:IsA('ScreenGui')then
   local full=g.Name=='TravelButtons'or g.Name=='RobloxTopBar';local gh=full and FULLH or SH
   g.AbsoluteSize=V2(SW,gh);g.AbsolutePosition=V2(0,0)
   if g.Name~='TouchGui'then lay(g,0,0,SW,gh,1)end
  end
 end
end
pg.ChildAdded:Connect(function(c)if c.ClassName=='ScreenGui'then c.AbsoluteSize=V2(SW,(c.Name=='TravelButtons')and FULLH or SH)end end)
local function load(name)local s=R.new('LocalScript');s.Name=name;local ok,err=pcall(W.load,name,s);if not ok then print('LOADFAIL '..name..': '..tostring(err))end end
load('SettingsClient');load('ChestIndex');load('GamePassClient');load('TravelButtons');load('DailyRewardsClient')
sized();W.frames(10,1/60)
load('Hotbar')
local econ=R.Instance.new('ScreenGui');econ.Name='ChestEconomyUI';econ.DisplayOrder=30;econ.ResetOnSpawn=false;econ.Parent=pg
local wallet=W.module('GardenWallet').new(econ);wallet:SetValue(7e12)
local status=W.module('WorldStatusHud').Create(pg,player)
sized();W.frames(10,1/60)
local Hud=W.module('HudLayout');local PityBars=W.module('PityBars155')
local m=Hud.Read(V2(SW,SH),false,nil)
local Bars=PityBars.Start(player,{});player:SetAttribute('PackPityNormal',3);player:SetAttribute('PackPityEvent',0)
-- Roblox's own top bar (stand-in) -------------------------------------------------------------------------------------------------------------------------
local top=R.Instance.new('ScreenGui');top.Name='RobloxTopBar';top.DisplayOrder=1;top.Parent=pg;top.AbsoluteSize=V2(SW,FULLH)
local function frame(parent,name,x,y,w,h,color,alpha,radius,text,size,tcolor)
 local f=R.Instance.new('Frame');f.Name=name;f.Position=R.UDim2.fromOffset(x,y);f.Size=R.UDim2.fromOffset(w,h);f.BackgroundColor3=color or RGB(24,30,52);f.BackgroundTransparency=alpha or .35;f.ZIndex=1;f.Parent=parent
 if radius then local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(0,radius);c.Parent=f end
 if text then
  local t=R.Instance.new('TextLabel');t.Name='Text';t.Size=R.UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.Text=text;t.TextSize=size or 12;t.Font=Enum.Font.FredokaOne
  t.TextColor3=tcolor or RGB(214,226,255);t.TextStrokeTransparency=.3;t.TextStrokeColor3=RGB(8,13,24);t.TextWrapped=true;t.ZIndex=2;t.Parent=f
 end
 return f
end
frame(top,'Band',0,0,SW,TB,RGB(14,18,30),.35,0)
local ic=TB-12
frame(top,'RobloxMenu',10,6,ic,ic,RGB(20,24,36),.25,ic/2,'R',math.floor(ic*.5),RGB(255,255,255))
frame(top,'Chat',10+ic+8,6,ic,ic,RGB(20,24,36),.25,ic/2,'...',math.floor(ic*.5),RGB(255,255,255))
for i=1,3 do frame(top,'RobloxRight'..i,SW-(ic+8)*3-4+(i-1)*(ic+8),6,ic,ic,RGB(20,24,36),.25,ic/2,'',12)end
-- settle -----------------------------------------------------------------------------------------------------------------------------------------------
local function frames(n)sized();W.frames(n,1/60)end
frames(30)
local bg=pg:FindFirstChild(PityBars.Name);if bg then bg.AbsoluteSize=V2(SW,SH)end
local tg=pg:FindFirstChild(PityBars.TagName);if tg then tg.AbsoluteSize=V2(SW,SH)end
-- (deadlines set just before the first dump; the status card reads them at its next .25 s tick)
local function clocks()
 local t=R.clock
 map:SetAttribute('VeiledNextAt',t+625-.1);map:SetAttribute('NextBiomeRefreshAt',t+15-.1);W.RS:SetAttribute('NextWeatherAt',t+520-.1)
end
-- numbers --------------------------------------------------------------------------------------------------------------------------------------------
local function info(k,val)print(('INFO %s %s'):format(k,tostring(val)))end
local function rect(name,x,y,w,h)print(('INFO rect.%s %.1f %.1f %.1f %.1f'):format(name,x,y,w,h))end
info('hud',SW..'x'..SH);info('topbar',TB)
local hs,ms=m.Scale or 1,m.MenuScale or 1
info('hudScale',string.format('%.4f',hs));info('menuScale',string.format('%.4f',ms));info('laidOut',string.format('%.0fx%.0f',m.VW or SW,m.VH or SH))
info('slots',m.Slots);info('slotSize',string.format('%.1f',m.SlotSize*hs));info('walletW',string.format('%.1f',m.WalletWidth*hs));info('walletH',string.format('%.1f',m.WalletHeight*hs))
info('menuSize',string.format('%.1f',m.MenuSize*ms));info('optionSize',string.format('%.1f',m.MenuOptionSize*ms))
info('radius',string.format('%.1f',m.MenuRadius*ms));info('radiusX',string.format('%.1f',m.MenuRadiusX*ms))
info('details',tostring(m.HotbarDetails))
local function geometry()
 -- (every rectangle is real screen px: HudLayout.HudBoxes with the wheel open; the bars' pair is PityBars155's real placement)
 local want={Hub='hub',Opt1='opt1',Opt2='opt2',Opt3='opt3',Opt4='opt4',Opt5='opt5',WalletSpeed='wallet_speed',WalletCash='wallet_cash',WalletGem='wallet_gem',Status='status',OwnerTools='tools'}
 for _,b in ipairs(Hud.HudBoxes(m,SW,SH,true))do
  if want[b.N]then rect(want[b.N],b.X,b.Y,b.W,b.H)end
 end
 local dock=PityBars.DefaultDock(m,SW,SH)
 rect('dock',dock.X,dock.Y,dock.W,dock.H)
 local pp=Bars.Placement and Bars.Placement.Pair;if pp then rect('pity',pp.X,pp.Y,pp.W,pp.H)end
 local rows=PityBars.NameRows(SW,SH,m,dock,Bars.Placement);if m.HotbarDetails~=false then rect('namerows',rows.X,rows.Y,rows.W,rows.H)end
end
geometry()
-- scene output ----------------------------------------------------------------------------------------------------------------------------------------
-- (the mock leaves a property nobody set at nil; Roblox's defaults: a grey Frame / button, black text and black text stroke)
local GUIKINDS={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,CanvasGroup=true,ViewportFrame=true}
local function fixText()
 for _,r in ipairs(pg:GetChildren())do for _,d in ipairs(r:GetDescendants())do
  if GUIKINDS[d.ClassName]and d.BackgroundColor3==nil then d.BackgroundColor3=RGB(163,162,165)end
  if d.ClassName=='TextLabel'or d.ClassName=='TextButton'then
   if d.TextStrokeColor3==nil then d.TextStrokeColor3=RGB(0,0,0)end;if d.TextColor3==nil then d.TextColor3=RGB(0,0,0)end end
 end end
end
-- (a CanvasGroup faded out is dumped hidden: the renderer does not know GroupTransparency)
local function dumpGui(g,gw,gh)
 local hidden={}
 for _,o in ipairs(g:GetDescendants())do if o._class=='CanvasGroup'and(o._props.GroupTransparency or 0)>=.99 and o._props.Visible~=false then hidden[#hidden+1]=o;o._props.Visible=false end end
 local out=dump(g,gw,gh)
 for _,o in ipairs(hidden)do o._props.Visible=true end
 return out
end
local function emit(name,which)
 fixText()
 local roots={}
 for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')and g.Enabled~=false then roots[#roots+1]=g end end
 table.sort(roots,function(a,b)return(a.DisplayOrder or 0)<(b.DisplayOrder or 0)end)
 local kids={}
 local canvasH=which=='hud'and SH or FULLH
 for i,g in ipairs(roots)do
  local full=g.Name=='TravelButtons'or g.Name=='RobloxTopBar'
  if(which=='all')or(which=='hud'and not full)or(which=='top'and full)then
   local gw,gh=SW,full and FULLH or SH
   local j=dumpGui(g,gw,gh);local inner=j:match('"kids":%[(.*)%]}$')
   if inner and inner~=''then
    kids[#kids+1]=('{"img":false,"n":"Gui_%s","k":"Frame","vis":true,"z":%d,"size":[0,%d,0,%d],"pos":[0,0,0,%d],"ap":[0,0],"rot":0,"bg":null,"bgA":1,"clip":false,"cr":null,"scale":1,"strokes":[],"grad":null,"text":null,"kids":[%s]}')
     :format(g.Name,g.DisplayOrder or i,gw,gh,(full or which=='hud')and 0 or TB,inner)
   end
  end
 end
 local crop=which=='top'and{0,0,SW,TB}or{0,0,SW,canvasH}
 print(('SCENE %s %d %d %d %d 1 {"canvas":[%d,%d],"kids":[%s]}'):format(name,crop[1],crop[2],crop[3],crop[4],SW,canvasH,table.concat(kids,',')))
end
W.Gui.ReducedMotionEnabled=true
local nav=pg:FindFirstChild('GardenNavigation');local hub=nav and nav:FindFirstChild('MenuButton')
local function both(prefix)for _,which in ipairs({'all','hud','top'})do if ONLY:find(which,1,true)then emit(prefix..'_'..which,which)end end end
local function settle()clocks();frames(24)end
if WHEEL~='open'then settle();both('closed')end
if WHEEL~='closed'then
 if hub then hub.Activated:Fire()end
 frames(10);settle();info('wheelOpen',pg:GetAttribute('GardenMenuExpanded'))
 both('open')
end
-- the wheel against every other box (the layout's own boxes, wheel open; the owner-only TOOLS square is not one: StudioTestClient hides it while the wheel is open)
do
 local boxes=Hud.HudBoxes(m,SW,SH,true);local clash={}
 local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
 for _,a in ipairs(boxes)do if a.N:sub(1,3)=='Opt'then
  if a.X<0 or a.Y<0 or a.X+a.W>SW or a.Y+a.H>SH then clash[#clash+1]=a.N..' off-screen'end
  for _,b in ipairs(boxes)do if b~=a and b.N~='Hub'and b.N~='OwnerTools'and b.N:sub(1,3)~='Opt'and ov(a,b,0)then clash[#clash+1]=a.N..' x '..b.N end end
  local pair=Bars.Placement and Bars.Placement.Pair;if pair and ov(a,pair,0)then clash[#clash+1]=a.N..' x PityBars'end
 end end
 info('wheelClashes',#clash==0 and'none'or table.concat(clash,'; '))
end
