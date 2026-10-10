--!nocheck
-- R158 HUD tests: the HUD scene both R158 tests run, built from the REAL scripts of this checkout on the Roblox mock (tools/tests/roblox.luau + inventory_R113/tests/world.luau):
-- the Hotbar (Bat, Shovel, 8 seeds, the Bag button), GardenWallet (Speed / Cash / Gems), WorldStatusHud (luck rows, timers, THE DARKENED card), PityBars155, the menu wheel
-- (HudLayout.Navigation + SettingsClient, ChestIndex, GamePassClient, DailyRewardsClient) and TravelButtons, with a layout emulation (absolute rects from UDim2 + AnchorPoint +
-- UIScale, as Roblox does it) so a test can look at where a piece really is on the screen.
-- build(o): o.w, o.h = the HUD area (what HudLayout sees: the ScreenGuis with CoreUISafeInsets, under Roblox's top bar); o.touch; o.ix, o.iy = the safe area's corner (insets), and
-- o.vw, o.vh = the whole window (default w + 2 ix, h + iy); o.bar = the top bar row's height (default 52 on a computer, 44 on a phone). One scene per process (the mock is global).
-- Returns the scene S:  S.pg, S.player, S.W, S.R, S.Hud, S.Bars (PityBars155 module), S.Pity (the running bars), S.hub, S.frames(n), S.openWheel(bool), S.rect(obj) (the real rect of a
-- GuiObject: its UIScale and its ancestors' included), S.tree(gui) (a canonical text of a ScreenGui's numbers: class, name, Position, Size, AnchorPoint, Visible, TextSize, UIScale),
-- S.hash(text), S.ser(value) and the thumb controls S.controls (touch).
local W=require('./world');local R=W.R;local F=require('./fixtures')
local V2=R.Vector2.new
local fmt=string.format
local S={W=W,R=R}
local function num(v)return fmt('%.17g',v)end
local function ser(v)
 local t=type(v)
 if t=='number'then return num(v)end
 if t~='table'then return tostring(v)end
 local keys={}
 for k in pairs(v)do keys[#keys+1]=k end
 table.sort(keys,function(a,b)local ta,tb=type(a),type(b);if ta~=tb then return ta<tb end;return a<b end)
 local out={}
 for _,k in ipairs(keys)do out[#out+1]=(type(k)=='number'and'['..num(k)..']'or tostring(k))..'='..ser(v[k])end
 return'{'..table.concat(out,',')..'}'
end
local function hash(s)
 local h=2166136261
 for i=1,#s do h=bit32.bxor(h,s:byte(i));h=(bit32.lshift(h,24)+h*403)%4294967296 end
 return fmt('%08x',h)
end
S.ser,S.hash=ser,hash
-- the thumb controls the way Roblox puts them (as R155's tests do), in HUD-area pixels
function S.thumbs(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
-- a canonical text of a ScreenGui's GUI numbers, children in tree order (a different tree, a different number or a new UIScale all change it)
function S.tree(g)
 local out={}
 local function walk(o,depth)
  for _,c in ipairs(o:GetChildren())do
   local cls=c.ClassName
   if cls=='UIScale'then out[#out+1]=string.rep(' ',depth)..fmt('S|%s|%s',c.Name,num(c.Scale or 1));walk(c,depth+1)
   elseif c:IsA('GuiObject')then
    local p,s,a=c.Position,c.Size,c.AnchorPoint or V2(0,0)
    if c.Name=='Sweep'then p=R.UDim2.new()end -- (GuiShine's moving shine stripe: it is animated by the clock, not laid out)
    out[#out+1]=string.rep(' ',depth)..fmt('%s|%s|%s,%s,%s,%s|%s,%s,%s,%s|%s,%s|%s|%s',cls,c.Name,num(p.X.Scale),num(p.X.Offset),num(p.Y.Scale),num(p.Y.Offset),
     num(s.X.Scale),num(s.X.Offset),num(s.Y.Scale),num(s.Y.Offset),num(a.X),num(a.Y),tostring(c.Visible~=false),c.TextSize and num(c.TextSize)or'-')
    walk(c,depth+1)
   end
  end
 end
 walk(g,0)
 return table.concat(out,'\n')
end
function S.build(o)
 local SW,SH=o.w,o.h;local touch=o.touch==true;local ix,iy=o.ix or 0,o.iy or 0
 local VW,VH=o.vw or SW+2*ix,o.vh or SH+iy
 local TB=o.bar or(touch and 44 or 52)
 S.w,S.h,S.touch,S.vw,S.vh=SW,SH,touch,VW,VH
 W.UIS.TouchEnabled=touch;W.UIS.KeyboardEnabled=not touch;W.UIS.MouseEnabled=not touch;W.UIS.GamepadEnabled=false
 W.Gui.GetInsetArea=function()return{Min=V2(ix,iy),Width=SW,Height=SH}end
 W.Gui.TopbarInset={__type='Rect',Min=V2(ix+100,0),Max=V2(VW-ix-100,TB),Width=VW-2*ix-200,Height=TB}
 W.workspace.CurrentCamera.ViewportSize=V2(VW,VH)
 do local inner=R.Instance.new -- (every ScreenGui is born the size of the HUD area; the full-screen ones are fixed in sized())
  R.Instance.new=function(class,parent)local x=inner(class,parent);if class=='ScreenGui'then x.AbsoluteSize=V2(SW,SH);x.AbsolutePosition=V2(ix,iy)end;return x end
 end
 local Players=W.service('Players')
 local player=R.new('Player');player.Name='Ann';player.UserId=158;player.Parent=Players;Players.LocalPlayer=player;player.CharacterAdded=R.signal();function Players.GetPlayers()return {player}end
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
 local char=R.new('Model');char.Name='Ann';char.Parent=W.workspace;player.Character=char
 local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
 local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=R.CFrame.new(0,5,50);hrp.Parent=char
 S.pg,S.player=pg,player
 if touch then -- Roblox's thumb controls (TouchGui), in screen pixels: the safe area's corner + HudLayout's own numbers
  local c=S.thumbs(SW,SH);S.controls=c
  local t=R.new('ScreenGui');t.Name='TouchGui';t.Enabled=true;t.Parent=pg
  for key,name in pairs({Joystick='ThumbstickFrame',Jump='JumpButton'})do
   local f=R.new('Frame');f.Name=name;f.Parent=t;f.AbsolutePosition=V2(ix+c[key].X,iy+c[key].Y);f.AbsoluteSize=V2(c[key].W,c[key].H)
  end
 end
 -- server state ------------------------------------------------------------------------------------------------------------------------------------
 F.packAssets(W)
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 for _,n in ipairs({'RequestBaseTeleport','RequestTrackTeleport'})do local e=R.new('RemoteEvent');e.Name=n;e.Parent=remotes end
 local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
 local request=R.new('RemoteFunction');request.Name='PremiumRequest';request.Parent=remotes
 local Pricing=W.module('PremiumPricing');local Mech=W.module('MechCatalog')
 local function shop()
  local offers={};for _,x in ipairs(Mech.Offers)do offers[tostring(x.Count)]={Count=x.Count,GemPrice=x.GemPrice,GemAvailable=true,RobuxAvailable=true,RobuxPrice=x.TargetRobuxPrice}end
  local bundles={};for _,row in ipairs(Pricing.Bundles)do bundles[row.Key]={Available=true,Amount=row.Amount,GemPrice=row.GemPrice,RobuxAmount=row.Amount}end
  return {PackOffers=offers,Bundles=bundles,GiftProducts={Growth={Available=true},Speed={Available=true}},GiftCredits={},Gems=500,OnSale=true,Success=true,Message=''}
 end
 local quests={{Key='Steal',Text='Steal 3 packs',Icon='x',Goal=3,Progress=3,Claimed=false,Gems=2},{Key='Plant',Text='Plant 3 seeds',Icon='y',Goal=3,Progress=1,Claimed=false,Gems=2}}
 function request.InvokeServer(_,action)
  if action=='Daily'then return {Success=true,Login={Ready=true,Next=1,Claimed=0},Quests=quests,ResetIn=5*3600+12*60,Day=1}end
  if action=='SettingsState'then return {Success=true,Settings={Music=100,Chase=100,Ambience=100,Effects=100,Interface=100,Quality='Auto',GlobalAnnouncements=true}}end
  return shop()
 end
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
 -- the owner's numbers: 802.1M speed, $7T, 84 gems; luck x7.2K and x50M; 3/10 pity; THE DARKENED in 10m 25s; timers 08:40 / 00:15 -------------------------
 player:SetAttribute('Gems',84);player:SetAttribute('TutorialDone',true)
 player:SetAttribute('TreadmillTier',5);player:SetAttribute('TreadmillMultiplier',6);player:SetAttribute('DoubleSpeedOwned',true);player:SetAttribute('ChestLuckMultiplier',5e7)
 local stats=R.new('Folder');stats.Name='ChestChaseStats';stats.Parent=player
 local speed=R.new('StringValue');speed.Name='Speed';speed.Value='802100000';speed.Parent=stats
 local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
 W.RS:SetAttribute('GlobalWeather','Clear')
 F.bat(W,bag);F.shovel(W,bag)
 for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed','CocoaSeed','LanternFernSeed','PineappleSeed','CactusSeed'})do F.seed(W,bag,id,1,'None')end
 -- the layout emulation: absolute rects from UDim2 + AnchorPoint + UIScale (a child resolves against its parent's UNSCALED size; the scale pivots about the AnchorPoint) -----------
 local function set(x,k,v)local c=x._props[k];if not c or c.X~=v.X or c.Y~=v.Y then x[k]=v end end
 local function lay(x,px,py,pw,ph,ps)
  -- px, py, pw, ph: the parent's rect (real); ps: the parent's accumulated UIScale (its children are laid out unscaled inside it, then scaled as a whole)
  for _,c in ipairs(x._children)do if c:IsA('GuiObject')then
   local sz,pos=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or V2(0,0)
   if sz and pos then
    local ui=c:FindFirstChildOfClass('UIScale');local k=ui and(ui._props.Scale or 1)or 1
    local lw=sz.X.Scale*(pw/ps)+sz.X.Offset;local lh=sz.Y.Scale*(ph/ps)+sz.Y.Offset -- the local (unscaled) size
    local rw,rh=lw*ps*k,lh*ps*k
    local ax=px+(pos.X.Scale*(pw/ps)+pos.X.Offset)*ps-a.X*rw;local ay=py+(pos.Y.Scale*(ph/ps)+pos.Y.Offset)*ps-a.Y*rh
    set(c,'AbsoluteSize',V2(rw,rh));set(c,'AbsolutePosition',V2(ax,ay))
    lay(c,ax,ay,rw,rh,ps*k)
   end
  end end
 end
 local function sized()
  for _,g in ipairs(pg:GetChildren())do
   if g:IsA('ScreenGui')and g.Name~='TouchGui'then
    local full=g.Name=='TravelButtons'
    local gw,gh,gx,gy=SW,SH,ix,iy;if full then gw,gh,gx,gy=VW,VH,0,0 end
    if g.AbsoluteSize.X~=gw or g.AbsoluteSize.Y~=gh then g.AbsoluteSize=V2(gw,gh)end;g.AbsolutePosition=V2(gx,gy)
    lay(g,gx,gy,gw,gh,1)
   end
  end
 end
 local function frames(n)for _=1,n or 1 do sized();W.frames(1,1/60)end;sized()end
 S.frames=frames
 pg.ChildAdded:Connect(function(c)if c.ClassName=='ScreenGui'and c.Name~='TouchGui'then c.AbsoluteSize=V2(c.Name=='TravelButtons'and VW or SW,c.Name=='TravelButtons'and VH or SH)end end)
 local function load(name)local x=R.new('LocalScript');x.Name=name;local ok,err=pcall(W.load,name,x);if not ok then print('LOADFAIL '..name..': '..tostring(err))end end
 S.load=load
 load('SettingsClient');load('ChestIndex');load('GamePassClient');load('TravelButtons');load('DailyRewardsClient')
 frames(10)
 load('Hotbar')
 local econ=R.Instance.new('ScreenGui');econ.Name='ChestEconomyUI';econ.DisplayOrder=30;econ.ResetOnSpawn=false;econ.Parent=pg
 S.wallet=W.module('GardenWallet').new(econ);S.wallet:SetValue(7e12)
 S.status=W.module('WorldStatusHud').Create(pg,player)
 frames(10)
 S.Hud=W.module('HudLayout');S.Bars=W.module('PityBars155')
 S.Pity=S.Bars.Start(player,{});player:SetAttribute('PackPityNormal',3);player:SetAttribute('PackPityEvent',0)
 do local bg=pg:FindFirstChild(S.Bars.Name);if bg then bg.AbsoluteSize=V2(SW,SH)end end
 frames(30)
 W.Gui.ReducedMotionEnabled=true
 local clock=R.clock
 map:SetAttribute('VeiledNextAt',clock+625-.1);W.RS:SetAttribute('NextWeatherAt',clock+520-.1)
 frames(24)
 S.nav=pg:FindFirstChild('GardenNavigation');S.hub=S.nav and S.nav:FindFirstChild('MenuButton')
 function S.openWheel(open)
  if S.hub and(S.hub:GetAttribute('Expanded')==true)~=open then S.hub.Activated:Fire()end
  frames(12)
 end
 -- the real rect of a GuiObject on the screen (the layout emulation above, then relative to the HUD area's corner)
 function S.rect(x)
  local p,sz=x.AbsolutePosition,x.AbsoluteSize
  return {X=p.X-ix,Y=p.Y-iy,W=sz.X,H=sz.Y}
 end
 return S
end
return S
