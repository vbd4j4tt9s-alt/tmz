--!nocheck
-- R150 SFX fix round, part 2: the REAL Hotbar (with the real HarvestArrival) on the Roblox mock, InteractionAudio replaced by a recorder.
--  1. Equip: keys 1-0, gamepad L1 / R1, a slot click and a Bag card click all sound the Equip cue, once, on the frame the tool changes hands
--     (and the unequip too); the slot / card carry ButtonSound=false so the click is not two sounds; an empty slot keeps a plain click.
--  2. Equipping from the Bag closes the Bag quietly (MenuClose muted for a moment): one sound, not two. Closing the Bag by itself is left to
--     ButtonFeedback's SeedMenu rule (the Hotbar plays nothing for it).
--  3. Dragging a slot onto another clicks.
--  4. Harvest landing in the bag: the Bubble06 cue plays on the flash frame (HarvestArrival.Land), not when the server replies / the tool
--     arrives; a failed request, a gift and a flight that is still in the air stay silent.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
local rec=E.recorder()
E.player('Tester')
local player,pg,bag,char,hum=E.Player,E.pg,E.bag,E.char,E.hum
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
local n=0
local function harvest(seed,cropId,index,scale,value)
 n+=1
 local t=F.fruit(W,nil,seed,scale or 1,'None',value or 700,index or 1)
 t:SetAttribute('SourceCropId',cropId);t:SetAttribute('FruitIndex',index or 1);t:SetAttribute('HarvestCycle',0)
 return t
end
local function key(code)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[code],UserInputType=R.Enum.UserInputType.Keyboard},false)end
local function held()for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then return t end end end
-- items: three fruits (slots 2, 3, 4 after the shovel in slot 1)
local apple=harvest('AppleSeed','plant-1',1);local plum=harvest('BluebellSeed','plant-2',1);local clover=harvest('CloverSeed','plant-3',1)
for _,t in ipairs({apple,plum,clover})do t.Parent=bag end
frames(10)
local _,appleSlot=slotOf(apple);local _,plumSlot=slotOf(plum)
check(appleSlot and plumSlot,'the fruits are on the hotbar (slots '..tostring(appleSlot)..', '..tostring(plumSlot)..')')
local NUM={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}

-- 1. equip sounds ---------------------------------------------------------------------------------------------------------------------------------
rec.clear();R.advance(1)
key(NUM[appleSlot]);frames(1)
check(held()==apple,'(the key equipped the apple)')
check(rec.keys()=='Equip','key '..appleSlot..': one Equip cue ('..rec.keys()..')')
rec.clear();key(NUM[appleSlot]);frames(1)
check(held()==nil and rec.keys()=='Equip','the same key again (unequip): one Equip cue too ('..rec.keys()..')')
rec.clear();key(NUM[plumSlot]);frames(1);check(held()==plum and rec.keys()=='Equip','another slot: Equip')
rec.clear();key(NUM[plumSlot]);frames(1)
-- gamepad L1 / R1 (ContextActionService)
local cycle=W.actions['GardenHotbarCycle'];check(cycle~=nil,'the L1 / R1 action is bound')
rec.clear();cycle('GardenHotbarCycle',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonR1});frames(1)
check(held()~=nil and rec.keys()=='Equip','R1: one Equip cue ('..rec.keys()..')')
rec.clear();cycle('GardenHotbarCycle',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonL1});frames(1)
check(rec.keys()=='Equip','L1: one Equip cue ('..rec.keys()..')')
rec.clear();cycle('GardenHotbarCycle',R.Enum.UserInputState.End,{KeyCode=R.Enum.KeyCode.ButtonL1})
check(rec.count()==0,'releasing the shoulder button is silent')
hum:UnequipTools();frames(1);rec.clear()
-- keys while a menu is open do nothing (and sound nothing)
pg:SetAttribute('SeedMenu','Settings');key(NUM[appleSlot]);frames(1);check(rec.count()==0 and held()==nil,'a number key while another menu is open: nothing, silent');pg:SetAttribute('SeedMenu',nil)
-- a key for an empty slot
rec.clear();key('Zero');frames(1);check(rec.count()==0,'a number key with nothing in that slot: silent (nothing happened)')
-- slot click
local s=dock['Slot'..appleSlot]
check(s:GetAttribute('ButtonSound')==false,'a slot carries ButtonSound=false (the click is the Equip cue, not Bubble04 + Equip)')
rec.clear();s.Activated:Fire();frames(1)
check(held()==apple and rec.keys()=='Equip','slot click: one Equip cue ('..rec.keys()..')')
rec.clear();s.Activated:Fire();frames(1)
check(held()==nil and rec.keys()=='Equip','slot click on the held item (unequip): one Equip cue')
rec.clear();dock['Slot10'].Activated:Fire();frames(1);check(rec.keys()=='Bubble04','an empty slot keeps the plain click ('..rec.keys()..')')

-- 2. the Bag -----------------------------------------------------------------------------------------------------------------------------------------
local open=dock.OpenInventory
check(open:GetAttribute('ButtonSound')==false,'the Bag button is silent itself: ButtonFeedback plays MenuClick / MenuClose for SeedMenu')
rec.clear();open.Activated:Fire();frames(10)
check(panel.Visible and pg:GetAttribute('SeedMenu')=='Inventory','(the Bag is open)')
check(rec.count()==0,'opening the Bag: the Hotbar itself plays nothing (the SeedMenu rule does)')
local cards={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then cards[#cards+1]=c end end
check(#cards>=3 and cards[1]:GetAttribute('ButtonSound')==false,'Bag cards carry ButtonSound=false too ('..#cards..' cards)')
rec.clear();cards[1].Activated:Fire();frames(2)
check(rec.keys()=='Equip' and rec.Muted.MenuClose==1,'equipping from the Bag: one Equip, and the Bag\'s own close is muted ('..rec.keys()..', muted '..tostring(rec.Muted.MenuClose)..')')
check(not panel.Visible,'(the Bag closed)')
rec.clear();hum:UnequipTools();frames(1)
open.Activated:Fire();frames(5);rec.clear();key('Escape');frames(1)
check(not panel.Visible and rec.count()==0,'Esc closes the Bag: the Hotbar adds no sound of its own (MenuClose comes from the SeedMenu rule)')
open.Activated:Fire();frames(5);rec.clear();key('B');frames(1)
check(not panel.Visible and rec.count()==0,'B closes it, silently the same way')
open.Activated:Fire();frames(5)
rec.clear();panel.Close.Activated:Fire();frames(1)
check(not panel.Visible and rec.count()==0,'the Bag\'s X: the Hotbar adds nothing (its Close button is named Close: MenuClose through ButtonHighlights)')

-- 3. drag ------------------------------------------------------------------------------------------------------------------------------------------
do
 local from,to=dock['Slot'..appleSlot],dock['Slot9']
 local fp=from.AbsolutePosition+R.Vector2.new(10,10);local tp=to.AbsolutePosition+R.Vector2.new(10,10)
 rec.clear();R.advance(1)
 from.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position={X=fp.X,Y=fp.Y}})
 W.UIS.InputChanged:Fire({UserInputType=R.Enum.UserInputType.MouseMovement,Position={X=tp.X,Y=tp.Y}})
 W.UIS.InputEnded:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position={X=tp.X,Y=tp.Y}});frames(2)
 check(rec.keys()=='Bubble04','dragging an item onto another slot clicks once ('..rec.keys()..')')
 rec.clear();R.advance(1)
 from.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position={X=fp.X,Y=fp.Y}})
 W.UIS.InputEnded:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,Position={X=fp.X,Y=fp.Y}});frames(1)
 check(rec.count()==0,'a press that never moved is not a drag (the click is the Activated event)')
end

-- 4. the harvest cue belongs to the arrival flash ------------------------------------------------------------------------------------------------------
do
 hum:UnequipTools();frames(2);rec.clear()
 local mango=harvest('MangoSeed','plant-M',1)
 Arrival.Expect('plant-M',1)  -- EconomyClient: the Harvest request was sent
 R.advance(.3)                -- ... the server replied; the item is in the Backpack, the fruit is in the air
 mango.Parent=bag;frames(5)
 check(rec.count('Bubble06')==0,'the server reply / the tool arriving plays no pickup cue (the fruit has not landed)')
 Arrival.Flying('plant-M',1,.6);frames(36,1/60)
 check(rec.count('Bubble06')==0,'still silent while the fruit is in the air')
 rec.clear();Arrival.Land('plant-M',1);frames(1)
 check(rec.count('Bubble06')==1 and rec.keys()=='Bubble06','the fruit lands: one Bubble06 on the frame the slot flashes ('..rec.keys()..')')
 local flash=slotOf(mango):FindFirstChild('ArrivalFlash')
 check(flash and flash.BackgroundTransparency<.5,'(and that is the frame the flash starts)')
 frames(60);check(rec.count('Bubble06')==1,'and only once')
 -- a failed request: no flash, no cue
 local fail=harvest('PlumSeed','plant-F',1);Arrival.Expect('plant-F',1);fail.Parent=bag;frames(3);rec.clear();Arrival.Cancel('plant-F',1);frames(3)
 check(rec.count('Bubble06')==0,'a failed request stays silent')
 -- a gift / purchase nobody expected: shown at once, no cue
 local gift=harvest('OrangeSeed','plant-G',1);rec.clear();gift.Parent=bag;frames(5)
 check(rec.count('Bubble06')==0,'an item nobody expected (a gift) appears without the pickup cue')
 -- the deadline when no flight ever starts: the flash (and its cue) come together at 1.5 s
 local late=harvest('PeachSeed','plant-L',1);Arrival.Expect('plant-L',1);late.Parent=bag;rec.clear();frames(60,1/60)
 check(rec.count('Bubble06')==0,'(held for 1 s, silent)')
 frames(40,1/60);check(rec.count('Bubble06')==1,'the hold ends at its deadline: the flash and the cue together')
 -- two fruits landing together: one cue per flash batch, rate-limited by the cue's own gap
 local a=harvest('LimeSeed','plant-A1',1);local b=harvest('FigSeed','plant-A2',1)
 Arrival.Expect('plant-A1',1);Arrival.Expect('plant-A2',1);a.Parent=bag;b.Parent=bag;frames(3);rec.clear()
 Arrival.Land('plant-A1',1);Arrival.Land('plant-A2',1);frames(2)
 check(rec.count('Bubble06')>=1 and rec.count('Bubble06')<=2,'fruit landing together: at most one cue per refresh ('..rec.count('Bubble06')..')')
end

-- the EconomyClient no longer plays it at the server reply
local eco=W.B.EconomyClient or''
check(eco~=''and eco:find("Bubble06",1,true)==nil,'EconomyClient has no Bubble06 any more (the harvest cue moved to the arrival flash)')

print(('R150 hotbar checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
