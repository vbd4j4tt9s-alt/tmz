--!nocheck
-- Phone HUD preview (not a test): builds the REAL hotbar, wallet, world status, travel buttons and menu (with stand-in
-- menu toggles built like SettingsClient / ChestIndex / GamePassClient) under the mock at a phone size, and prints one
-- JSON dump of every ScreenGui (render_gui.py draws it). Stand-ins: the world backdrop, the thumbstick and the jump
-- button. Roblox's own top bar sits above this canvas (our GUIs use CoreUISafeInsets). Set W_,H_ (viewport) and EVENT (The Darkened active) before this file.
local W=require('./world');local F=require('./fixtures');local R=W.R;local dump=require('./dump_gui')
local RGB=R.Color3.fromRGB
local vw,vh=W_ or 844,H_ or 390
F.packAssets(W)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char;player.CharacterAdded=R.signal()
local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.CFrame=R.CFrame.new(0,5,50);hrp.Parent=char
W.UIS.TouchEnabled=true;W.UIS.MouseEnabled=false;W.UIS.KeyboardEnabled=false
function W.UIS.GetLastInputType()return R.Enum.UserInputType.Touch end
local camera=W.workspace.CurrentCamera;camera.ViewportSize=R.Vector2.new(vw,vh)
W.service('GuiService').GetInsetArea=function()return {Min=R.Vector2.new(0,0),Width=vw,Height=vh}end
-- Roblox touch controls (stand-ins at Roblox's small-screen positions) as HudLayout.Controls reports them.
local small=math.min(vw,vh)<=500
local jump=small and {X=vw-95,Y=vh-90,W=70,H=70}or {X=vw-170,Y=vh-210,W=120,H=120}
local stick=small and {X=20,Y=vh-110,W=90,H=90}or {X=60,Y=vh-180,W=120,H=120}
local L=W.module('HudLayout');L.Controls=function()return {Joystick=stick,Jump=jump}end
local realInstance=R.Instance.new
R.Instance.new=function(class,parent)local o=realInstance(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(vw,vh)end;return o end
-- World state for the HUD
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
for _,n in ipairs({'RequestBaseTeleport','RequestTrackTeleport','PremiumRequest'})do local e=R.new('RemoteEvent');e.Name=n;e.Parent=remotes end
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
map:SetAttribute('NextBiomeRefreshAt',R.clock+232);map:SetAttribute('BiomeStartZ_1',0);map:SetAttribute('BiomeEndZ_1',400)
if EVENT then map:SetAttribute('VeiledEventActive',true)else map:SetAttribute('VeiledNextAt',R.clock+560)end
W.RS:SetAttribute('GlobalWeather','Clear');W.RS:SetAttribute('NextWeatherAt',R.clock+242);W.RS:SetAttribute('WeatherEndsAt',R.clock-1)
player:SetAttribute('Gems',76);player:SetAttribute('TreadmillTier',6);player:SetAttribute('TreadmillMultiplier',60);player:SetAttribute('ChestLuckMultiplier',5e7)
local stats=R.new('Folder');stats.Name='ChestChaseStats';stats.Parent=player
local speed=R.new('StringValue');speed.Name='Speed';speed.Value='7600000';speed.Parent=stats
-- Inventory: shovel, bat, three packs, two seeds
F.shovel(W,bag);F.bat(W,bag);for _=1,3 do F.pack(W,bag,1,'Pack01',1,'None')end
F.seed(W,bag,'SunflowerSeed',1,'None');F.seed(W,bag,'ElderbloomSeed',1,'None')
-- Real HUD pieces
W.load('Hotbar',R.new('LocalScript'))
local econ=R.Instance.new('ScreenGui');econ.Name='GardenEconomy';econ.DisplayOrder=20;econ.ResetOnSpawn=false;econ.Parent=pg
local wallet=W.module('GardenWallet').new(econ);wallet:SetValue(8.1e12)
local status=W.module('WorldStatusHud').Create(pg,player)
W.load('TravelButtons',R.new('LocalScript'))
-- Menu toggles built like the real scripts (SettingsClient 1, ChestIndex 2, GamePassClient 3)
local Bright=W.module('BrightUI');local Art=W.module('HudArtwork');local Theme=W.module('GardenTheme')
local function toggle(guiName,name,color,caption,index,icon)
 local gui=R.Instance.new('ScreenGui');gui.Name=guiName;gui.ResetOnSpawn=false;gui.DisplayOrder=55;gui.Parent=pg
 local b=R.Instance.new('TextButton');b.Name=name;b.Text='';b.Size=R.UDim2.fromOffset(68,68);b.BorderSizePixel=0;b.Parent=gui;Bright.Button(b,color)
 if icon=='Gear'then
  local gear=R.Instance.new('Frame');gear.Name='Gear';gear.Size=R.UDim2.fromScale(.52,.52);gear.Position=R.UDim2.fromScale(.24,.12);gear.BackgroundTransparency=1;gear.Parent=b
  for i=0,7 do local tooth=R.Instance.new('Frame');tooth.Size=R.UDim2.fromScale(.24,.96);tooth.AnchorPoint=R.Vector2.new(.5,.5);tooth.Position=R.UDim2.fromScale(.5,.5);tooth.Rotation=i*45;tooth.BackgroundColor3=RGB(219,242,255);tooth.BorderSizePixel=0;tooth.Parent=gear;Theme.Corner(tooth,3)end
  local c=R.Instance.new('Frame');c.Size=R.UDim2.fromScale(.47,.47);c.Position=R.UDim2.fromScale(.265,.265);c.BackgroundColor3=RGB(60,91,137);c.BorderSizePixel=0;c.Parent=gear;Theme.Corner(c,30)
 else local a=Art.Attach(b,icon);a.Position=R.UDim2.fromOffset(5,0);a.Size=R.UDim2.new(1,-10,1,-11)end
 local t=R.Instance.new('TextLabel');t.Name='Caption';t.Text=caption;t.BackgroundTransparency=1;t.Position=R.UDim2.new(0,0,1,-19);t.Size=R.UDim2.new(1,0,0,18);Bright.Text(t,14);t.TextXAlignment=R.Enum.TextXAlignment.Center;t.Parent=b
 L.Navigation(b,index);return b
end
toggle('GardenSettings','SettingsButton',RGB(93,127,177),'SETTINGS',1,'Gear')
toggle('ChestIndexUI','IndexButton',RGB(80,208,255),'INDEX',2,'Index')
toggle('GamePasses','PassesButton',RGB(125,222,44),'SHOP',3,'RobuxShop')
-- Settle: layouts run on deferred tasks and heartbeats
for _=1,6 do W.frames(10,1/60)end
-- Stand-ins drawn under/over the HUD: world, Roblox top-left buttons, thumbstick, jump.
local function frame(parent,name,x,y,w,h,color,alpha,radius)
 local f=R.Instance.new('Frame');f.Name=name;f.Position=R.UDim2.fromOffset(x,y);f.Size=R.UDim2.fromOffset(w,h);f.BackgroundColor3=color;f.BackgroundTransparency=alpha or 0;f.BorderSizePixel=0;f.Parent=parent
 if radius then local c=R.Instance.new('UICorner');c.CornerRadius=R.UDim.new(0,radius);c.Parent=f end;return f
end
local world=R.Instance.new('ScreenGui');world.Name='_World';world.DisplayOrder=-100;world.Parent=pg
frame(world,'Sky',0,0,vw,vh*.36,RGB(98,170,236));frame(world,'Ground',0,vh*.36,vw,vh*.64,RGB(86,196,86))
frame(world,'Path',vw*.3,vh*.36,vw*.4,vh*.64,RGB(120,214,110))
frame(world,'Player',vw/2-14,vh*.52,28,52,RGB(40,40,60),0,4)
local core=R.Instance.new('ScreenGui');core.Name='_RobloxCore';core.DisplayOrder=1000;core.Parent=pg
frame(core,'Thumbstick',stick.X,stick.Y,stick.W,stick.H,RGB(255,255,255),.75,stick.W/2)
frame(core,'Jump',jump.X,jump.Y,jump.W,jump.H,RGB(255,255,255),.6,jump.W/2)
-- One dump, every ScreenGui in DisplayOrder
local guis={};for _,g in ipairs(pg:GetChildren())do if g.ClassName=='ScreenGui'and g.Enabled~=false then table.insert(guis,g)end end
table.sort(guis,function(a,b)return(a.DisplayOrder or 0)<(b.DisplayOrder or 0)end)
local items={}
for _,g in ipairs(guis)do local s=dump(g,vw,vh);local inner=s:match('"items":%[(.*)%]}$');if inner and inner~=''then table.insert(items,inner)end end
print('JSON {"canvas":['..vw..','..vh..'],"items":['..table.concat(items,',')..']}')
local m=L.Read({X=vw,Y=vh},true,L.Controls())
print(string.format('METRICS slot=%d slots=%d menu=%s',m.SlotSize,m.Slots,tostring(m.MenuMode)))
