--!nocheck
-- R152 performance patch: the hotbar UI, frame by frame. The REAL Hotbar client (test_hotbar_click.luau's world: the R150 sound recorder, a Backpack with
-- tools, the mock's GUI layout) through a short session: fruit, a pack and the shovel added, clicks that equip and unequip (mouse and touch), a slot move,
-- the Bag opened and a card clicked, a number key, items removed. Every frame is a stream frame (perf152_fp.luau) of the PlayerGui and the character.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local FP=require('./perf152_fp')(W)
math.randomseed(152)
F.packAssets(W)
W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder()
E.player('Tester')
local player,pg,bag,char,hum=E.Player,E.pg,E.bag,E.char,E.hum
F.shovel(W,bag)
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
local st=FP.stream('hotbar')
local f=0
local function frames(n,dt,label)
 for _=1,n do
  local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end
  W.frames(1,dt or 1/60);f+=1
  st:frame((label or'')..' f'..f,{pg,char})
 end
end
local sc=R.new('LocalScript');sc.Name='Hotbar';W.load('Hotbar',sc)
frames(30,nil,'boot')
local function harvest(seed,cropId)local t=F.fruit(W,nil,seed,1,'None',700,1);t:SetAttribute('SourceCropId',cropId);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0);return t end
local apple,plum,clover=harvest('AppleSeed','plant-1'),harvest('BluebellSeed','plant-2'),harvest('CloverSeed','plant-3')
for _,t in ipairs({apple,plum,clover})do t.Parent=bag end
local pack=F.pack(W,bag,2,'Pack06',1,'None','Seed Pack')
frames(12,nil,'items')
local gui=pg.ChestToolHotbar;local dock=gui.Dock
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local function slotOf(tool)for i=1,10 do local s=dock['Slot'..i];if s.Visible and s.ItemName.Text==Names.Tool(tool,Catalog)then return s,i end end end
local MB,TOUCH,MOVE=R.Enum.UserInputType.MouseButton1,R.Enum.UserInputType.Touch,R.Enum.UserInputType.MouseMovement
local function at(b,dx,dy)return {X=b.AbsolutePosition.X+b.AbsoluteSize.X/2+(dx or 0),Y=b.AbsolutePosition.Y+b.AbsoluteSize.Y/2+(dy or 0)}end
local function inside(b,p)local a,z=b.AbsolutePosition,b.AbsoluteSize;return p.X>=a.X and p.Y>=a.Y and p.X<=a.X+z.X and p.Y<=a.Y+z.Y end
local function gesture(b,path,kind,label)
 kind=kind or'mouse'
 if #path==2 and math.abs(path[1].X-path[2].X)+math.abs(path[1].Y-path[2].Y)>12 then path={path[1],{X=(path[1].X+path[2].X)/2,Y=(path[1].Y+path[2].Y)/2},path[2]}end
 local first,last=path[1],path[#path]
 local input={UserInputType=kind=='touch'and TOUCH or MB,Position=first}
 b.InputBegan:Fire(input);frames(1,nil,label)
 for i=2,#path-1 do
  if kind=='touch'then input.Position=path[i];W.UIS.InputChanged:Fire(input)else W.UIS.InputChanged:Fire({UserInputType=MOVE,Position=path[i]})end
  frames(1,nil,label)
 end
 if kind=='touch'then input.Position=last end
 if inside(b,last)then b.Activated:Fire()end
 W.UIS.InputEnded:Fire(kind=='touch'and input or{UserInputType=MB,Position=last})
 frames(8,nil,label)
end
local A=slotOf(apple);local P=slotOf(plum);local K=slotOf(pack)
gesture(A,{at(A)},'mouse','equip apple')
gesture(A,{at(A)},'mouse','unequip apple')
gesture(P,{at(P,-5,-3),at(P,9,5)},'touch','rolled tap plum')
if K then gesture(K,{at(K)},'mouse','equip pack')end
-- a slot move: the apple dragged onto the slot after the pack
local target=dock['Slot'..(select(2,slotOf(pack))or 6)+1]
if A and target then gesture(A,{at(A),at(target)},'mouse','move apple')end
-- the Bag: its button, then a card
local open=gui:FindFirstChild('BagButton',true)or gui:FindFirstChild('Backpack',true)
if open and open:IsA('GuiButton')then open.Activated:Fire();frames(15,nil,'bag open')end
-- a number key
W.UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.Keyboard,KeyCode=R.Enum.KeyCode.Two},false);frames(10,nil,'key 2')
-- items go
clover:Destroy();frames(10,nil,'clover gone')
pack:Destroy();frames(10,nil,'pack gone')
print('PERF152 HOTBAR DONE '..f)
