--!nocheck
-- R151 badge preview (not a test): the REAL ChestIndex under the Roblox mock (this checkout's, or the R150 ChestIndex + HudLayout when the caller bundled them as ChestIndex / HudLayout),
-- laid out by layout_badges.luau, printed as JSON for the R137 renderer (dump_gui.luau + render_index.py). Needs the globals VW, VH (the screen) set by the caller (a line in front of this file).
-- Prints JSON_NAV <the wheel + MENU button> and JSON_GUI <the Index with its tab row>, both with the clipping of the CanvasGroup and the ScrollingFrame switched on for the drawing (the Roblox
-- engine clips them always; the mock does not draw).
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3=R.Vector3.new
local dump=require('./dump_gui');local L=require('./layout_badges')(R)
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Vector2=R.Vector2
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=151;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
function req.InvokeServer()return {Success=true,Message='Claimed!'}end
local Rules=W.module('SeedPackRules')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0
for _,stage in ipairs({1,6,2,3,5,4,7})do
 local odds=Rules.SeedOdds(config,stage,'Pack01',1)
 for _,seed in ipairs(Rules.ObtainablePool(config,stage))do
  index+=1;local e=R.new('Folder');e.Name=seed.Id
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)))
  e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
 end
end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id,cash)local v=R.new('BoolValue');v.Name=id;v.Value=true;if cash then v:SetAttribute('RewardCash',cash)end;v.Parent=folder end
-- two rewards waiting (Mooncap's cash + Forest's half-way gems): the INDEX button says 2, the MENU button "!", the Forest tab has a dot
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed'})do found(seeds,id,id=='MooncapSeed'and 240000 or nil)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed'})do found(plants,id)end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end})
local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
W.frames(10)
local gui=pg:FindFirstChild('ChestIndexGui');local nav=pg:FindFirstChild('GardenNavigation')
local function relay()L.lay(nav,VW,VH);L.lay(gui,VW,VH);W.frames(1);L.lay(gui,VW,VH)end
local function frames(n)for _=1,n do relay()end end
frames(4)
-- the wheel open (the INDEX button and its CanvasGroup), the Index open (the tab row)
local hub=nav:FindFirstChild('MenuButton');hub.Activated:Fire();frames(8)
W.Gui.ReducedMotionEnabled=true;frames(2)
for _,o in ipairs(nav:GetDescendants())do if o._class=='CanvasGroup'then o.ClipsDescendants=true end end
print('JSON_NAV '..dump(nav,VW,VH))
-- the Index with its panel open: the wheel closes when a menu opens
hub.Activated:Fire();frames(2);pg:SetAttribute('SeedMenu','Index');frames(10)
for _,o in ipairs(gui:GetDescendants())do if o._class=='ScrollingFrame'then o.ClipsDescendants=true end end
print('JSON_GUI '..dump(gui,VW,VH))
