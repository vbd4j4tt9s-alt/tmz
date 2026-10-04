--!nocheck
-- Index preview (not a test): the REAL ChestIndex client under the mock (MODE='old' loads the R147 script as ChestIndexBase, 'new' this checkout's),
-- a player who has found and grown all six Mech seeds (MECH 12 / 12 in the old Index; the half and the full reward are waiting) and not the Verity seed
-- yet (VERITY 0 / 2 in the old one). Opens the MECH tab (old) or LIMITED (new) and prints the GUI as JSON for render_index.py.
-- Needs MODE set by the caller (a line in front of this file) and dump_gui.luau next to it.
local W=require('./world');local R=W.R;local dump=require('./dump_gui')
local VW,VH=1420,800 -- (the panel stays 980 wide; the wider canvas lets the whole tab row show, which scrolls on screen)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local realNew=R.Instance.new
R.Instance.new=function(class,parent)local o=realNew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(VW,VH)end;return o end
W.env.Instance=R.Instance
local V3=R.Vector3.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
function req.InvokeServer()return {Success=true,Message='Claimed!'}end
local Rules=W.module('SeedPackRules')
local config={SeedCatalogByStage=Rules.BuildSeedCatalog()}
local index=0;local mech={}
for stage,defs in ipairs(config.SeedCatalogByStage)do for i,seed in ipairs(defs)do
 if not Rules.IsRetired(seed.Id)then
  local at=Rules.ObtainableStage(seed.Id)or stage
  local e=R.new('Folder');e.Name=seed.Id;index+=1
  e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Rules.GetRarity(seed.Id)))
  e:SetAttribute('Stage',at);e:SetAttribute('SeedIndex',index);e:SetAttribute('BaseChance',Rules.SeedOdds(config,at,'Pack01',1)[seed.Id]);e.Parent=catalog
  if at==8 then mech[#mech+1]=seed.Id end
 end
end end
local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
local function found(folder,id)local v=R.new('BoolValue');v.Name=id;v.Value=true;v.Parent=folder end
for _,id in ipairs(mech)do found(seeds,id);found(plants,id)end
for _,id in ipairs({'SunflowerSeed','BluebellSeed','AppleSeed'})do found(seeds,id)end;for _,id in ipairs({'SunflowerSeed'})do found(plants,id)end
local Event=W.module('LimitedEvent') -- (27 days, 4 h, 12 min and 9 s left, as in the owner's example)
W.workspace.GetServerTimeNow=function()return Event.EndsAt-(27*86400+4*3600+12*60+9)+R.clock end
W.stub('InteractionAudio',{Play=function()return true end,Preload=function()end})
local s=R.new('LocalScript');s.Name='ChestIndex';W.load(MODE=='old'and'ChestIndexBase'or'ChestIndex',s)
W.frames(5);pg:SetAttribute('SeedMenu','Index');W.frames(20)
local gui=pg:FindFirstChild('ChestIndexGui')
local function lay(o,px,py,pw,ph) -- (absolute rects for the text-fit code, as the tests do)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local sz,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  if sz and p then
   local w=sz.X.Scale*pw+sz.X.Offset;local h=sz.Y.Scale*ph+sz.Y.Offset
   local lim=c:FindFirstChildOfClass('UISizeConstraint');if lim and lim.MaxSize then w=math.min(w,lim.MaxSize.X);h=math.min(h,lim.MaxSize.Y)end
   local x=px+p.X.Scale*pw+p.X.Offset-a.X*w;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h
   c.AbsoluteSize=R.Vector2.new(w,h);c.AbsolutePosition=R.Vector2.new(x,y);lay(c,x,y,w,h)
  end
 end end
end
local tab=gui:FindFirstChild(MODE=='old'and'Biome8'or'BiomeLimited',true)
tab.Activated:Fire()
for _=1,6 do lay(gui,0,0,VW,VH);W.frames(1)end
print('JSON '..dump(gui,VW,VH))
