--!nocheck
-- R156 preview data (not a test): the REAL wheel scripts (HudLayout.Navigation, SettingsClient, ChestIndex, GamePassClient), the REAL DailyRewardsClient / TravelButtons and the REAL NotifyBadge151 on the
-- Roblox mock, in the owner's states, printed as SCENE lines (nested GUI JSON, R153's dump_tree153) for render_gui155.mjs (headless Chromium). Run once with this checkout's sources ("current", R155) and
-- once with the patched copies of make_variant156.py ("proposed"): the SAME scene code, only the bundled scripts differ.
-- The rest of the HUD (hotbar slots, balances with their + buttons, status card, jump button / stick, Roblox's own top bar buttons) is a STAND-IN drawn from HudLayout's metrics.
-- Globals (a line in front of this file, run_menu_wheel156.sh): VIEW = 'pc' | 'land' | 'port' | 'tiny'.
-- Prints: SCENE <name> <cropX> <cropY> <cropW> <cropH> <scale> <json>   and   INFO <view> <key> <value> lines (the numbers the .md quotes).
local W=require('./world');local R=W.R
Color3=R.Color3 -- (dump_tree153 reads the global)
local dump=require('./dump_tree153')
local V2=R.Vector2.new;local RGB=R.Color3.fromRGB;local Enum=R.Enum
-- HUD area (what HudLayout sees: the ScreenGuis with CoreUISafeInsets), touch?, Roblox top bar row height (TravelButtons' row), free part of the row (TopbarInset: left, right)
-- tiny = an 844 x 390 phone with the safe-area figures of docs/proposals/shop_R120/tests (47 / 58 / 47 / 21): 750 x 311 left for the HUD.
local VIEWS={pc={1920,1080,false,52,140,1920},land={844,390,true,44,150,800},port={390,844,true,44,110,390},tiny={750,311,true,44,150,706}}
local v=VIEWS[VIEW or'pc'];local SW,SH,TOUCH,TB,LEFT,RIGHT=v[1],v[2],v[3],v[4],v[5],v[6]
local FULLH=SH+TB
W.UIS.TouchEnabled=TOUCH;W.UIS.KeyboardEnabled=not TOUCH;W.UIS.MouseEnabled=not TOUCH;W.UIS.GamepadEnabled=false
W.Gui.GetInsetArea=function()return{Min=V2(0,0),Width=SW,Height=SH}end
W.Gui.TopbarInset={__type='Rect',Min=V2(LEFT,0),Max=V2(RIGHT,TB),Width=RIGHT-LEFT,Height=TB}
W.workspace.CurrentCamera.ViewportSize=V2(SW,SH)
local Players=W.service('Players')
local player=R.new('Player');player.Name='Ann';player.UserId=156;player.Parent=Players;Players.LocalPlayer=player;player.CharacterAdded=R.signal();function Players.GetPlayers()return {player}end
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local char=R.new('Model');char.Name='Ann';player.Character=char
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
local function indexRewards(on)
 for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do if not seeds:FindFirstChild(id)then found(seeds,id,on and id=='MooncapSeed'and 240000 or nil)end end
 for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do if not plants:FindFirstChild(id)then found(plants,id)end end
end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end,Transaction=function()end,Asset=function()return nil end})
W.stub('RarityRevealAudio',{Preload=function()end,Play=function()return true end,Burst=function()end})
W.stub('ShopViewport',{Visible=function()return true end,CachedVisible=function()return true end})
W.stub('ShopSeedReveal',{Attach=function()return {Refresh=function()end,Destroy=function()end}end})
W.stub('PackViewport89',{DecorateCard=function()end,Create=function(parent)local x=R.Instance.new('ViewportFrame');x.Name='MechPackPreview';x.Parent=parent;return x end})
local Market=W.service('MarketplaceService');Market.GetProductInfoAsync=function()return{PriceInRobux=399,IsForSale=true}end
local Social=W.service('SocialService');function Social.CanSendGameInviteAsync()return true end;function Social.PromptGameInvite()end
local ENS=W.service('ExperienceNotificationService');function ENS.CanPromptOptInAsync()return true end;function ENS.PromptOptIn()end
W.service('SoundService')
-- the wheel scripts, in their own order (SETTINGS 1, INDEX 2, SHOP 3 as the game loads them), then BASE / TRACK and DAILY / INVITE ------------------------------------------------------------------
indexRewards(true)
player:SetAttribute('TutorialDone',false)
local function load(name)local s=R.new('LocalScript');s.Name=name;local ok,err=pcall(W.load,name,s);if not ok then print('LOADFAIL '..name..': '..tostring(err))end end
local function sized()
 for _,g in ipairs(pg:GetChildren())do
  if g:IsA('ScreenGui')then local full=g.Name=='TravelButtons'or g.Name=='RobloxTopBar';g.AbsoluteSize=V2(SW,full and FULLH or SH);g.AbsolutePosition=V2(0,0)end
 end
end
pg.ChildAdded:Connect(function(c)if c.ClassName=='ScreenGui'then c.AbsoluteSize=V2(SW,(c.Name=='TravelButtons')and FULLH or SH)end end)
load('SettingsClient');load('ChestIndex');load('GamePassClient');load('TravelButtons');load('DailyRewardsClient')
sized();W.frames(10,1/60)
local Hud=W.module('HudLayout');local Badge=W.module('NotifyBadge151')
local m=Hud.Read(V2(SW,SH),TOUCH,nil)
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
-- (Roblox's right-hand buttons: they end where TopbarInset ends, so the free part of the row is LEFT..RIGHT)
local rightIcons=math.max(1,math.floor((SW-RIGHT)/(ic+8)))
if RIGHT>=SW then rightIcons=3 end
for i=1,rightIcons do frame(top,'RobloxRight'..i,(RIGHT<SW and RIGHT+4 or SW-(ic+8)*rightIcons-4)+(i-1)*(ic+8),6,ic,ic,RGB(20,24,36),.25,ic/2,'',12)end
-- the stand-in HUD (the boxes the HUD scripts place themselves by) ---------------------------------------------------------------------------------------
local ctx=R.Instance.new('ScreenGui');ctx.Name='HudStandIn';ctx.DisplayOrder=20;ctx.Parent=pg;ctx.AbsoluteSize=V2(SW,SH)
local function box(name,x,y,w,h,color,alpha,radius,text,size,tcolor)local f=frame(ctx,name,x,y,w,h,color,alpha,radius or 8,text,size,tcolor)
 local s=R.Instance.new('UIStroke');s.Color=RGB(12,17,38);s.Thickness=2;s.Transparency=.3;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=f;return f end
local PityBars=W.module('PityBars155');local dock=PityBars.DefaultDock(m,SW,SH)
local slotNames={'Desert Common','Lava Rare','Limited Mech','Void Pack','Shovel','Bat','Fire Pepper','Aloe','Ember Rose','Sand Fruit'}
local side=m.SlotSize
for i=1,m.Slots do box('Slot'..i,dock.X+(i-1)*(side+6),dock.Y,side,side,RGB(48,54,106),.15,8,slotNames[i],math.max(9,math.floor(side*.16)))end
box('Bag',dock.X+m.Slots*(side+6),dock.Y,side,side,RGB(48,54,106),.15,8,'Bag',14)
-- balances: the rows, each with its + button at the right end
local labels={Speed='Speed  12.4K',Cash='Money  $3.2M',Gem='Gems  250'}
if m.WalletWidth<200 then labels={Speed='⚡ 12.4K',Cash='💰 3.2M',Gem='💎 250'}end -- (a narrow row holds the icon and the number)
for _,k in ipairs({'Speed','Cash','Gem'})do
 local x,y,w,h=m[k..'X']or m.WalletX,m[k..'Y'],m.WalletWidth,m.WalletHeight
 box('Wallet'..k,x,y,w,h,RGB(20,26,48),.3,6,labels[k],math.max(10,math.floor(h*.42)))
 local pb=math.min(h-6,m.WalletPlus or h-6);box('Plus'..k,x+w-pb-3,y+(h-pb)/2,pb,pb,RGB(86,200,90),.05,6,'+',math.max(12,math.floor(pb*.8)),RGB(255,255,255))
end
for _,b in ipairs(Hud.HudBoxes(m,SW,SH,false))do
 if b.N=='Status'then box('Status',b.X,b.Y,b.W,b.H,RGB(20,26,48),.45,8,'timers / boosts',11)
 elseif b.N=='OwnerTools'then box('Tools',b.X,b.Y,b.W,b.H,RGB(40,46,80),.3,8,'TOOLS',10)
 elseif b.N=='Jump'or b.N=='ThumbR'then box('Jump',b.X+b.W/2-35,b.Y+b.H/2-35,70,70,RGB(255,255,255),.75,35,'jump',12)
 elseif b.N=='ThumbL'then box('Stick',b.X+b.W/2-45,b.Y+b.H/2-45,90,90,RGB(255,255,255),.82,45,'',12)end
end
-- the real pity bars (always on the HUD since R155): 3/10 each
local Bars=PityBars.Start(player,{});player:SetAttribute('PackPityNormal',3);player:SetAttribute('PackPityEvent',3)
local function frames(n)sized();W.frames(n,1/60)end
frames(30)
local bg=pg:FindFirstChild(PityBars.Name);if bg then bg.AbsoluteSize=V2(SW,SH)end
local tg=pg:FindFirstChild(PityBars.TagName);if tg then tg.AbsoluteSize=V2(SW,SH)end
-- numbers for the .md --------------------------------------------------------------------------------------------------------------------------------
local function info(k,val)print(('INFO %s %s %s'):format(VIEW or'pc',k,tostring(val)))end
info('hud',SW..'x'..SH)
info('menuShiftY',string.format('%.1f',m.MenuShiftY or 0))
info('hubCenterY',string.format('%.1f',SH/2+(m.MenuShiftY or 0)))
info('menuSize',m.MenuSize);info('optionSize',m.MenuOptionSize);info('radius',string.format('%.1f',m.MenuRadius));info('radiusX',string.format('%.1f',m.MenuRadiusX))
for i,o in ipairs(m.MenuOffsets)do info('offset'..i,string.format('%.1f,%.1f',o.X,o.Y))end
-- wheel option rects vs every other HUD box (the proposed layout must clear them all)
do
 local boxes=Hud.HudBoxes(m,SW,SH,true);local clash={}
 local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
 for _,a in ipairs(boxes)do if a.N:sub(1,3)=='Opt'then
  if a.X<0 or a.Y<0 or a.X+a.W>SW or a.Y+a.H>SH then clash[#clash+1]=a.N..' off-screen'end
  for _,b in ipairs(boxes)do if b~=a and b.N~='Hub'and b.N:sub(1,3)~='Opt'and ov(a,b,0)then clash[#clash+1]=a.N..' x '..b.N end end
  local pair=Bars.Placement and Bars.Placement.Pair;if pair and ov(a,pair,4)then clash[#clash+1]=a.N..' x PityBars'end
 end end
 info('wheelClashes',#clash==0 and'none'or table.concat(clash,'; '))
 local pp=Bars.Placement and Bars.Placement.Pair;info('pityPair',pp and('%d,%d %dx%d'):format(pp.X,pp.Y,pp.W,pp.H)or'MISSING')
 if m.Travel then local t=m.Travel;local hit={};for _,a in ipairs(boxes)do if a.N:sub(1,3)=='Opt'and ov(a,{X=t.X,Y=t.Y,W=t.W,H=t.H},0)then hit[#hit+1]=a.N end end
  info('staleTravelSpot',('%d,%d %dx%d under-wheel=%s overlaps %s'):format(t.X,t.Y,t.W,t.H,tostring(t.UnderWheel),#hit==0 and'none'or table.concat(hit,',')))end
end
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
local function emit(name,crop,scale,hideTravel)
 fixText()
 local roots={}
 for _,g in ipairs(pg:GetChildren())do if g:IsA('ScreenGui')and g.Enabled~=false then roots[#roots+1]=g end end
 table.sort(roots,function(a,b)return(a.DisplayOrder or 0)<(b.DisplayOrder or 0)end)
 local kids={}
 for i,g in ipairs(roots)do
  local full=g.Name=='TravelButtons'or g.Name=='RobloxTopBar'
  local gw,gh=SW,full and FULLH or SH
  local j=dump(g,gw,gh);local inner=j:match('"kids":%[(.*)%]}$')
  if inner and inner~=''and not(hideTravel and g.Name=='TravelButtons')then
   kids[#kids+1]=('{"img":false,"n":"Gui_%s","k":"Frame","vis":true,"z":%d,"size":[0,%d,0,%d],"pos":[0,0,0,%d],"ap":[0,0],"rot":0,"bg":null,"bgA":1,"clip":false,"cr":null,"scale":1,"strokes":[],"grad":null,"text":null,"kids":[%s]}')
    :format(g.Name,g.DisplayOrder or i,gw,gh,full and 0 or TB,inner)
  end
 end
 crop=crop or{0,0,SW,FULLH}
 print(('SCENE %s %d %d %d %d %s {"canvas":[%d,%d],"kids":[%s]}'):format(name,crop[1],crop[2],crop[3],crop[4],tostring(scale or 1),SW,FULLH,table.concat(kids,',')))
end
local nav=pg:FindFirstChild('GardenNavigation');local hub=nav and nav:FindFirstChild('MenuButton')
-- 1. wheel CLOSED, a daily reward waiting, nothing in the Index: where does the player see it?
local function waitingDailyOnly()
 for _,x in ipairs(seeds:GetChildren())do x:Destroy()end;for _,x in ipairs(plants:GetChildren())do x:Destroy()end
 player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',0);frames(12)
end
-- 2. the Index has 2 rewards waiting as well
local function waitingBoth()indexRewards(true);player:SetAttribute('DailyLoginReady',true);player:SetAttribute('DailyQuestsReady',0);frames(12)end
W.Gui.ReducedMotionEnabled=true
waitingDailyOnly();frames(4)
emit('closed',nil,1)
waitingBoth();frames(4)
hub.Activated:Fire();frames(10)
info('wheelOpen',pg:GetAttribute('GardenMenuExpanded'))
emit('open',nil,1)
-- where everything is, in canvas pixels (the HUD area starts TB px down): the sheet outlines and zooms with these
local function rect(name,x,y,w,h)print(('INFO %s rect.%s %d %d %d %d'):format(VIEW or'pc',name,math.floor(x+.5),math.floor(y+.5),math.floor(w+.5),math.floor(h+.5)))end
local cy=SH/2+(m.MenuShiftY or 0)
rect('hub',10,TB+cy-m.MenuSize/2,m.MenuSize,m.MenuSize)
for i,o in ipairs(m.MenuOffsets)do rect('opt'..i,10+(m.MenuSize-m.MenuOptionSize)/2+o.X,TB+cy-m.MenuOptionSize/2+o.Y,m.MenuOptionSize,m.MenuOptionSize)end
local tb=pg:FindFirstChild('TravelButtons')
if tb then
 local pair=tb:FindFirstChild('TravelPair')
 if pair then rect('pair',pair.Position.X.Offset-pair.Size.X.Offset/2,pair.Position.Y.Offset-pair.Size.Y.Offset/2,pair.Size.X.Offset,pair.Size.Y.Offset)end
 local icons=tb:FindFirstChild('TopIcons')
 if icons then for _,n in ipairs({'Daily','Invite'})do local slot=icons:FindFirstChild(n)
  rect('top'..n,icons.Position.X.Offset+slot.Position.X.Offset,icons.Position.Y.Offset+slot.Position.Y.Offset,slot.Size.X.Offset,slot.Size.Y.Offset)end end
end
local entry=nil
if nav then for _,g in ipairs(nav:GetChildren())do local b=g:FindFirstChild('DailyButton');if b then entry=g end end end
info('dailyInWheel',entry~=nil)
for _,g in ipairs(nav and nav:GetChildren()or{})do if g.Name:sub(1,10)=='MenuOption'then local b=g:GetChildren()[1];info(g.Name,b and b.Name or'?')end end
-- smoke test of the proposed wiring: tapping DAILY in the open wheel closes the wheel and opens the DAILY window; INVITE closes the wheel
if entry then
 local db=entry:FindFirstChild('DailyButton');db.Activated:Fire();frames(4)
 info('tapDaily',('SeedMenu=%s wheelOpen=%s'):format(tostring(pg:GetAttribute('SeedMenu')),tostring(pg:GetAttribute('GardenMenuExpanded'))))
 pg:SetAttribute('SeedMenu',nil);frames(2);hub.Activated:Fire();frames(4)
 for _,g in ipairs(nav:GetChildren())do local b=g:FindFirstChild('InviteButton');if b then b.Activated:Fire()end end;frames(4)
 info('tapInvite',('wheelOpen=%s'):format(tostring(pg:GetAttribute('GardenMenuExpanded'))))
end
