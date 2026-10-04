--!nocheck
-- R149 (owner's change to #8: "the fruit floats into the player ... and appears in the player's inventory"): the REAL Hotbar script with the REAL HarvestArrival on
-- the Roblox mock. A harvested item is in the Backpack as soon as the server adds it (data is never delayed), but the Hotbar / Bag do not show it before the
-- fruit has arrived, and then flash its slot (or the Bag button when it has no slot):
--  1. held while the flight lasts, shown at the arrival with one flash; the stack count only grows at the arrival;
--  2. an item that nobody expected (a gift, a purchase) shows at once, without a flash; a failed request releases without a flash;
--  3. a hold always ends (the deadline); an item without a visible slot flashes the Bag button; the Bag card flashes while the Bag is open;
--  4. the flash is a short fade driven by ONE RenderStepped connection that goes away when it is over; nothing is left connected when the script is destroyed.
local W=require('./world');local F=require('./fixtures');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local bag=R.new('Backpack');bag.Name='Backpack';bag.Parent=player
local char=R.new('Model');char.Name='Tester';char.Parent=W.workspace;player.Character=char
local hum=R.new('Humanoid');hum.Health=100;hum.Parent=char
hum.EquipTool=function(_,tool)for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end;tool.Parent=char end
hum.UnequipTools=function()for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then t.Parent=bag end end end
player.CharacterAdded=R.signal()
local Arrival=W.module('HarvestArrival')
local shovel=F.shovel(W,bag)
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
local function frames(n,dt)for _=1,n do local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end;W.frames(1,dt)end end
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
local ok,err=pcall(W.load,'Hotbar',scriptInst);check(ok,'Hotbar loads: '..tostring(err))
frames(30)
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory
local function slotOf(tool)for i=1,10 do local s=dock['Slot'..i];if s.Visible and s.ItemName.Text==Names.Tool(tool,Catalog)then return s,i end end end
local function flashOf(b)return b and b:FindFirstChild('ArrivalFlash')end
local function connected(signal)local n=0;for _,c in ipairs(signal._c)do if c.Connected then n+=1 end end;return n end
-- a harvested fruit tool, as HarvestToolService makes it: the plant it came from and its fruit slot are on it
local n=0
local function harvest(seed,cropId,index,scale,value)
 n+=1
 local t=F.fruit(W,nil,seed,scale or 1,'None',value or 700,index or 1)
 t:SetAttribute('SourceCropId',cropId);t:SetAttribute('FruitIndex',index or 1);t:SetAttribute('HarvestCycle',0)
 return t
end
local renderBefore=connected(W.Run.RenderStepped)
-- 1. held while the fruit flies, shown at the arrival, one flash ------------------------------------------------------------------------------------------
local first=harvest('AppleSeed','plant-A',1)
first.Parent=bag;frames(10)
local slot1=slotOf(first);check(slot1~=nil and slot1.Count.Visible==false,'(an apple already in the bag: shown, no count)')
local second=harvest('AppleSeed','plant-A2',1) -- the same kind of fruit from another plant: it stacks as x2
Arrival.Expect('plant-A2',1)
second.Parent=bag
check(second.Parent==bag,'the item is in the Backpack at once (the data is never delayed)')
check(Arrival.Holds(second),'... and HarvestArrival holds its appearance')
frames(20)
slot1=slotOf(first);check(slot1~=nil and slot1.Count.Visible==false and slot1.Count.Text~='x2','while the fruit flies the slot does not count it yet')
check(flashOf(slot1)==nil or flashOf(slot1).BackgroundTransparency==1,'... and nothing flashes')
Arrival.Flying('plant-A2',1,.6);frames(40,1/60)
check(slotOf(first).Count.Visible==false,'0.7 s later and still in the air: still not shown')
-- the fruit arrives
Arrival.Land('plant-A2',1);frames(1)
slot1=slotOf(first)
check(slot1.Count.Visible==true and slot1.Count.Text=='x2','the fruit arrived: the stack counts it (x2)')
local f1=flashOf(slot1);check(f1~=nil and f1.BackgroundTransparency<.5,'... and the slot flashes ('..tostring(f1 and f1.BackgroundTransparency)..')')
check(connected(W.Run.RenderStepped)==renderBefore+1,'the flash is driven by one RenderStepped connection')
frames(8,1/60);local mid=flashOf(slot1).BackgroundTransparency
frames(40,1/60)
check(mid>.3 and mid<1 and flashOf(slot1).BackgroundTransparency==1,'it fades out (0.32 s)')
check(connected(W.Run.RenderStepped)==renderBefore,'... and the connection goes away when the flash is over')
-- 2. nobody expected it: at once, no flash; a failed request releases without a flash ------------------------------------------------------------------
local gift=harvest('BluebellSeed','plant-G',1);gift.Parent=bag;frames(5)
local gs=slotOf(gift);check(gs~=nil,'an item nobody expected (a gift) shows at once')
check(flashOf(gs)==nil or flashOf(gs).BackgroundTransparency==1,'... without a flash')
local failed=harvest('MooncapSeed','plant-F',1);Arrival.Expect('plant-F',1);failed.Parent=bag;frames(5)
check(slotOf(failed)==nil,'(held)');Arrival.Cancel('plant-F',1);frames(3)
local fs=slotOf(failed);check(fs~=nil and(flashOf(fs)==nil or flashOf(fs).BackgroundTransparency==1),'a request that failed releases the item without a flash')
-- 3. the deadline; no slot -> the Bag button; the Bag card ----------------------------------------------------------------------------------------------
local late=harvest('CocoaSeed','plant-L',1);Arrival.Expect('plant-L',1);late.Parent=bag;frames(20)
check(slotOf(late)==nil,'a hold that is never released ...')
frames(90,1/60) -- 1.5 s passed
local ls=slotOf(late);check(ls~=nil and flashOf(ls)~=nil,'... ends at its deadline: the item shows (and flashes)')
frames(40)
-- fill every slot, then a new fruit has no slot: the Bag button flashes
local kinds={'IceberrySeed','FirePepperSeed','SnowdropSeed','CloverSeed','SunflowerBloomSeed','ThunderTulipSeed','StrawberrySeed','BananaSeed','PineappleSeed','CactusSeed','AloeSeed'}
for i,k in ipairs(kinds)do local t=harvest(k,'plant-X'..i,1,1+i);t.Parent=bag end
frames(10)
local overflow=harvest('MonsteraSeed','plant-O',1);Arrival.Expect('plant-O',1);overflow.Parent=bag;frames(5);Arrival.Land('plant-O',1);frames(1)
local open=dock.OpenInventory
check(slotOf(overflow)==nil and flashOf(open)~=nil and flashOf(open).BackgroundTransparency<.5,'an item that has no visible slot flashes the Bag button')
frames(40)
-- the Bag open: the card flashes
open.Activated:Fire();frames(10)
check(panel.Visible,'(the Bag is open)')
local bagItem=harvest('DragonfruitSeed','plant-B',1);Arrival.Expect('plant-B',1);bagItem.Parent=bag;frames(5);Arrival.Land('plant-B',1);frames(2)
local flashing=0;for _,c in ipairs(panel.Items:GetChildren())do if flashOf(c)and flashOf(c).BackgroundTransparency<1 then flashing+=1 end end
check(flashing>=1,'with the Bag open the card of the arrived item flashes too ('..flashing..')')
frames(40);open.Activated:Fire();frames(5)
-- 4. clean up --------------------------------------------------------------------------------------------------------------------------------------
check(connected(W.Run.RenderStepped)==renderBefore,'no flash is left running')
local listeners=0;for _ in ipairs({})do end
scriptInst:Destroy();frames(2)
check(connected(W.Run.RenderStepped)<=renderBefore,'destroying the script leaves nothing connected')
Arrival.Land('nothing','1');check(true,'(a release after the Hotbar is gone is harmless)')
print(('growth hotbar: %d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
