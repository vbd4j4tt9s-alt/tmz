--!nocheck
-- Fast-scroll fallback measurement. Usage: luau scroll_measure.luau -a <fixture: typical|worst> <speeds...>
-- Cost model (mock only): every Instance created or cloned advances os.clock by COST seconds, so the
-- module's time-sliced budgets (build seconds, clone seconds) behave like they would on a device.
local W=require('./world');local F=require('./fixtures');local R=W.R
local args={...};local fixture=args[1]or'typical';local cold=fixture:find('%-cold$')~=nil;fixture=fixture:gsub('%-cold$','');local speeds={}
for i=2,#args do speeds[#speeds+1]=tonumber(args[i])end;if #speeds==0 then speeds={40,80,160}end
local COST=8e-6
F.packAssets(W)
-- Approved plant meshes are baked on the server in the real game; hand the client a ready part.
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Name='Tester';char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
hum.EquipTool=function(_,tool)tool.Parent=char end;hum.UnequipTools=function()end
player.CharacterAdded=R.signal()
F.shovel(W,bag);F.bat(W,bag);F.loot(W,bag)
for i=1,3 do F.pack(W,bag,1,'Pack01',1,'None')end
F.pack(W,bag,2,'Pack05',2.5,'Gold');F.pack(W,bag,7,'EclipseReliquary',1,'None','Void Pack')
local all={'SunflowerSeed','CloverSeed','BluebellSeed','StrawberrySeed','AppleSeed','MooncapSeed','SunflowerBloomSeed','ElderbloomSeed','BananaSeed','CocoaSeed','PineappleSeed','MonsteraSeed','VenomVineSeed','LanternFernSeed','TigerOrchidSeed','AncientWorldrootSeed','CactusSeed','AloeSeed','DesertRoseSeed','AgaveSeed','DatePalmSeed','MirageFigSeed','SolarStarfruitSeed','SunKingPalmSeed','SnowdropSeed','FrostFernSeed','IceberrySeed','WinterPineSeed','CrystalLilySeed','SilentFrostbellSeed','PolarStarbloomSeed','WinterCrownwoodSeed','FirePepperSeed','EmberBloomSeed','AshRoseSeed','LavaLotusSeed','DragonfruitSeed','ObsidianMawSeed','SupernovaBloomSeed','EmberEmperorSeed','AmethystSeed','PrismOrchidSeed','MoonflowerSeed','StarfruitSeed','DiamondVineSeed','HollowGeodeSeed','OrbitLotusSeed','PrismMonarchSeed','StaticGrassSeed','SparkReedSeed','ThunderTulipSeed','VoltOrchidSeed','TempestLotusSeed','BlackoutBloomSeed','PulsarStarfruitSeed','StormSovereignSeed'}
if fixture=='typical'then
 local ids={'SunflowerSeed','BluebellSeed','AppleSeed','MooncapSeed','CocoaSeed','IceberrySeed','FirePepperSeed','SnowdropSeed'}
 for i=1,120 do F.fruit(W,bag,ids[i%#ids+1],1+i*.5,i%9==0 and'Gold'or'None',1000+i)end
elseif fixture=='heavy'then -- every species as fruit and as seed (112 looks + packs/tools)
 for _,id in ipairs(all)do F.fruit(W,bag,id,1.5,'None',1000)end
 for _,id in ipairs(all)do F.seed(W,bag,id,1,'None')end
else -- worst: every species x three mutations as fruit, plus a seed of every species (224 distinct looks)
 for m,mutation in ipairs({'None','Gold','Diamond'})do for _,id in ipairs(all)do F.fruit(W,bag,id,1.5,mutation,1000)end end
 for _,id in ipairs(all)do F.seed(W,bag,id,1,'None')end
end
local total=0;for _,t in ipairs(bag:GetChildren())do if t:IsA('Tool')then total+=1 end end
local function set(o,k,v)local c=o._props[k];if not c or c.X~=v.X or c.Y~=v.Y then o[k]=v end end
local function lay(o,px,py,pw,ph,cx,cy)
 for _,c in ipairs(o._children)do if c:IsA('GuiObject')then
  local s,p=c._props.Size,c._props.Position;local a=c._props.AnchorPoint or R.Vector2.new(0,0)
  local w=s.X.Scale*pw+s.X.Offset;local h=s.Y.Scale*ph+s.Y.Offset
  local x=px+p.X.Scale*pw+p.X.Offset-a.X*w-cx;local y=py+p.Y.Scale*ph+p.Y.Offset-a.Y*h-cy
  set(c,'AbsoluteSize',R.Vector2.new(w,h));set(c,'AbsolutePosition',R.Vector2.new(x,y))
  local ox,oy=0,0;if c._class=='ScrollingFrame'then local cp=c._props.CanvasPosition or R.Vector2.new(0,0);ox,oy=cp.X,cp.Y end
  lay(c,x,y,w,h,ox,oy)
 end end
end
local function layout()local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end end
local function frames(n)for _=1,n do layout();W.frames(1)end end
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
W.load('Hotbar',scriptInst)
-- Cost model on from here (Hotbar construction itself is not measured).
do local base=R.new;R.new=function(...)R.clock+=COST;return base(...)end end
frames(cold and 1 or 300) -- 5 s in the world before opening the bag (cold: open at once)
local gui=pg.ChestToolHotbar;local panel=gui.Inventory;local scroll=panel.Items
W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode.B,UserInputType=R.Enum.UserInputType.Keyboard},false);frames(60)
local function count()
 local a,z=scroll.AbsolutePosition,scroll.AbsolutePosition+scroll.AbsoluteSize
 local vis,flat,pending=0,0,0
 for _,c in ipairs(scroll:GetChildren())do if c.Name=='Item'and c.Visible then
  local p,q=c.AbsolutePosition,c.AbsolutePosition+c.AbsoluteSize
  if q.X>a.X and q.Y>a.Y and p.X<z.X and p.Y<z.Y then
   vis+=1
   if not c.Picture:FindFirstChild('ItemViewport')then
    local f=c.Picture:FindFirstChild('FlatIcon');if f and f.Visible then flat+=1 else pending+=1 end
   end
  end
 end end
 return vis,flat,pending
end
local P=W.module('ItemPictures')
local v0,f0,p0=count()
print(string.format((cold and'COLD 'or'')..'fixture=%s tools=%d  at rest after open: visible=%d fallback=%d (flat %d, blank %d) views=%d templates=%d',fixture,total,v0,f0+p0,f0,p0,P.Stats().Views,P.Stats().Templates))
for _,speed in ipairs(speeds)do
 -- Fling to the bottom and back at `speed` px per frame (60 fps).
 local canvas=scroll.CanvasSize.Y.Offset;local maxY=math.max(0,canvas-scroll.AbsoluteSize.Y)
 local fr,fallbackFrames,sum,peak,cardFrames,worst=0,0,0,0,0,0
 local function go(y)
  local t0=R.clock;scroll.CanvasPosition=R.Vector2.new(0,y);layout();W.frames(1);local work=R.clock-t0-1/60;worst=math.max(worst,work)
  local vis,flat,pending=count();local fb=flat+pending
  fr+=1;cardFrames+=vis;sum+=fb;peak=math.max(peak,fb);if fb>0 then fallbackFrames+=1 end
 end
 local y=0;while y<maxY do y=math.min(maxY,y+speed);go(y)end
 while y>0 do y=math.max(0,y-speed);go(y)end
 local _,flat,pending=count()
 print(string.format('  %4d px/frame: %3d frames, fallback cards/frame avg %.2f max %d, frames with any fallback %d (%.0f%%), fallback share %.1f%% of %d card-frames, worst sim work %.1f ms; settled: %d',
  speed,fr,sum/fr,peak,fallbackFrames,100*fallbackFrames/fr,100*sum/math.max(1,cardFrames),cardFrames,worst*1000,flat+pending))
 frames(30)
end
local s=P.Stats();print(string.format('  end: views=%d parts=%d templates=%d records=%d',s.Views,s.Parts,s.Templates,s.Records))
