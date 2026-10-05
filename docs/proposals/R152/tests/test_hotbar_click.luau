--!nocheck
-- R152 (owner: "regarding inventory there are some issues where i have to click twice"): the REAL Hotbar on the Roblox mock. One press is ONE action
-- (an equip / unequip, or a slot move), whatever order the engine delivers the events in, on a mouse and on a touch:
--  1. a clean click equips once; the next click unequips once (counted as Humanoid:EquipTool / UnequipTools calls).
--  2. a click that rolls / slides (moves over 12 px) but ends on its own slot is still a click: with Activated BEFORE the release, AFTER it, and with no
--     Activated at all (a wobbly tap) it is exactly one action. R112-R151 turned it into a drag that swallowed the click.
--  3. a click released a few px off the slot (in the gap) is rescued; a press dragged far away and released over nothing does nothing.
--  4. a slot move works on the FIRST try: onto an empty slot, onto a taken slot (swap), into the 6 px gap beside the target, a few px above / below it; a
--     drop never also equips; the next click right after a drop works at once (no lock-out); the shovel slot refuses a drop without side effects.
--  5. the Bag: a card click equips once (rolled too, with no Activated), but not when the grid scrolled under the finger; a card dragged onto a slot is
--     placed, not equipped; a number key equips while the Bag is open.
--  6. the whole thing is silent (no sound for any of it), the slots are ButtonSound=false, and the real ButtonHighlights adds no click either.
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
local acts,log=0,{}
do local eq,un=hum.EquipTool,hum.UnequipTools
 hum.EquipTool=function(self,tool)acts+=1;log[#log+1]='equip';return eq(self,tool)end
 hum.UnequipTools=function(self)acts+=1;log[#log+1]='unequip';return un(self)end
end
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
local function frames(n,dt)for _=1,n do local gui=pg:FindFirstChild('ChestToolHotbar');if gui then lay(gui,0,0,1280,720,0,0)end;W.frames(1,dt)end end
local scriptInst=R.new('LocalScript');scriptInst.Name='Hotbar'
local ok,err=pcall(W.load,'Hotbar',scriptInst);check(ok,'Hotbar loads: '..tostring(err))
frames(30)
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory
local function slotOf(tool)for i=1,10 do local s=dock['Slot'..i];if s.Visible and s.ItemName.Text==Names.Tool(tool,Catalog)then return s,i end end end
local function held()for _,t in ipairs(char:GetChildren())do if t:IsA('Tool')then return t end end end
local function harvest(seed,cropId)local t=F.fruit(W,nil,seed,1,'None',700,1);t:SetAttribute('SourceCropId',cropId);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0);return t end
local apple,plum,clover=harvest('AppleSeed','plant-1'),harvest('BluebellSeed','plant-2'),harvest('CloverSeed','plant-3')
for _,t in ipairs({apple,plum,clover})do t.Parent=bag end
frames(10)
local _,aSlot=slotOf(apple);local _,pSlot=slotOf(plum);local _,cSlot=slotOf(clover)
check(aSlot and pSlot and cSlot,'the fruits are on the hotbar (slots '..tostring(aSlot)..', '..tostring(pSlot)..', '..tostring(cSlot)..')')
local A,P,C=dock['Slot'..aSlot],dock['Slot'..pSlot],dock['Slot'..cSlot]
local gap=dock.Slot3.AbsolutePosition.X-dock.Slot2.AbsolutePosition.X-dock.Slot2.AbsoluteSize.X
check(gap==6,'(the gap between slots is 6 px: '..tostring(gap)..')')

-- gesture helpers ---------------------------------------------------------------------------------------------------------------------------------
-- order: 'activated first' (the engine fires Activated, then UserInputService.InputEnded), 'release first' (the other way round), 'none' (no Activated: a
-- tap the scroll frame kept, or the finger rolled off for the engine's own test). The engine only fires Activated when the release is on the button.
local MB,TOUCH,MOVE=R.Enum.UserInputType.MouseButton1,R.Enum.UserInputType.Touch,R.Enum.UserInputType.MouseMovement
local function at(b,dx,dy)return {X=b.AbsolutePosition.X+b.AbsoluteSize.X/2+(dx or 0),Y=b.AbsolutePosition.Y+b.AbsoluteSize.Y/2+(dy or 0)}end
local function inside(b,p)local a,z=b.AbsolutePosition,b.AbsoluteSize;return p.X>=a.X and p.Y>=a.Y and p.X<=a.X+z.X and p.Y<=a.Y+z.Y end
local function gesture(b,path,order,kind)
 -- path: list of {X,Y} points; the first is the press, the last the release; the points between are moves
 kind=kind or'mouse'
 if #path==2 and math.abs(path[1].X-path[2].X)+math.abs(path[1].Y-path[2].Y)>12 then path={path[1],{X=(path[1].X+path[2].X)/2,Y=(path[1].Y+path[2].Y)/2},path[2]}end -- (a real drag always reports a move on the way)
 local first,last=path[1],path[#path]
 local input={UserInputType=kind=='touch'and TOUCH or MB,Position=first}
 b.InputBegan:Fire(input)
 for i=2,#path-1 do
  if kind=='touch'then input.Position=path[i];W.UIS.InputChanged:Fire(input)else W.UIS.InputChanged:Fire({UserInputType=MOVE,Position=path[i]})end
 end
 if kind=='touch'then input.Position=last end
 local ended=kind=='touch'and input or{UserInputType=MB,Position=last}
 local activated=inside(b,last)
 if order=='activated first'then if activated then b.Activated:Fire()end;W.UIS.InputEnded:Fire(ended)
 elseif order=='release first'then W.UIS.InputEnded:Fire(ended);if activated then b.Activated:Fire()end
 else W.UIS.InputEnded:Fire(ended)end
 frames(2)
end
local ORDERS={'activated first','release first','none'}
local function reset()hum:UnequipTools();frames(2);acts=0;table.clear(log);rec.clear()end

-- 1. a clean click --------------------------------------------------------------------------------------------------------------------------------
for _,kind in ipairs({'mouse','touch'})do for _,order in ipairs({'activated first','release first'})do
 reset();gesture(A,{at(A)},order,kind)
 check(acts==1 and held()==apple,('clean %s click (%s): one equip (%d, %s)'):format(kind,order,acts,tostring(held()and held().Name)))
 acts=0;gesture(A,{at(A)},order,kind)
 check(acts==1 and held()==nil,('the next %s click (%s): one unequip (%d)'):format(kind,order,acts))
end end
reset();gesture(A,{at(A)},'none')
check(acts==1 and held()==apple,'a click whose Activated never comes still equips, once (the release does it)')

-- 2. rolled / slid clicks -------------------------------------------------------------------------------------------------------------------------
for _,kind in ipairs({'mouse','touch'})do for _,order in ipairs(ORDERS)do
 reset();gesture(A,{at(A,-6,-4),at(A,10,6),at(A,17,9)},order,kind)
 check(acts==1 and held()==apple,('rolled %s click, 25 px of wobble (%s): exactly one equip (%d)'):format(kind,order,acts))
 acts=0;gesture(A,{at(A,0,0),at(A,15,-12),at(A,-3,-3)},order,kind)
 check(acts==1 and held()==nil,('...and the same wobble again (%s %s): exactly one unequip (%d)'):format(kind,order,acts))
 check(slotOf(apple)==A,'(the apple is still on its slot after the wobble)')
end end

-- 3. just off the slot / far off the slot ---------------------------------------------------------------------------------------------------------
reset();gesture(A,{at(A),at(A,A.AbsoluteSize.X/2+3,0)},'none')
check(acts==1 and held()==apple,'released 3 px outside the slot: still the click it meant (the gap is not a hole)')
reset();gesture(A,{at(A),at(A,0,-300),at(A,0,-300)},'none')
check(acts==0 and held()==nil and slotOf(apple)==A,'pressed on a slot and let go far away: nothing happens (cancel), nothing moves')
reset();gesture(A,{at(A),at(A,0,-300),at(A,0,-300)},'activated first')
check(acts==0,'(and the engine fires no Activated there either)')

-- 4. moving items: first try ----------------------------------------------------------------------------------------------------------------------
local slot9,slot8=dock.Slot9,dock.Slot8
local function names()local out={};for i=1,10 do out[i]=dock['Slot'..i].ItemName.Text end;return out end
for _,kind in ipairs({'mouse','touch'})do for _,order in ipairs(ORDERS)do
 reset()
 local before=slotOf(apple)
 gesture(before,{at(before),at(before,40,0),at(slot9)},order,kind)
 check(slotOf(apple)==slot9,('drag onto an empty slot (%s %s): moved on the first try (slot %s)'):format(kind,order,tostring(select(2,slotOf(apple)))))
 check(acts==0,'...and a drop never equips ('..acts..')')
 gesture(slot9,{at(slot9),at(slot9,-30,0),at(before)},order,kind) -- back again
 check(slotOf(apple)==before,('and back (%s %s)'):format(kind,order))
end end
reset()
do -- onto a taken slot: they swap
 local ap,pl=slotOf(apple),slotOf(plum)
 gesture(ap,{at(ap),at(pl)},'activated first')
 check(slotOf(apple)==pl and slotOf(plum)==ap and acts==0,'drag onto a taken slot swaps the two, no equip')
 gesture(pl,{at(pl),at(ap)},'release first')
 check(slotOf(apple)==ap and slotOf(plum)==pl,'and swaps back')
end
do -- a drop that lands a few px off the target: in the gap beside it, above it, below it
 local ap=slotOf(apple);local half=slot9.AbsoluteSize.X/2;local halfY=slot9.AbsoluteSize.Y/2
 for name,p in pairs({gapLeft=at(slot9,-half-2,0),gapRight=at(slot9,half+2,0),above=at(slot9,0,-halfY-3),below=at(slot9,0,halfY+3)})do
  gesture(ap,{at(ap),at(ap,20,0),p},'release first')
  check(slotOf(apple)==slot9 and acts==0,('drop %s the target slot lands on it (slot %s)'):format(name,tostring(select(2,slotOf(apple)))))
  gesture(slot9,{at(slot9),at(slot9,-20,0),at(ap)},'release first')
 end
 gesture(ap,{at(ap),at(ap,20,0),at(slot9,0,-60)},'release first')
 check(slotOf(apple)==ap,'a drop 60 px above the bar lands nowhere: the item stays')
end
do -- no lock-out: a click right after a drop works at once
 reset();local ap,cl=slotOf(apple),slotOf(clover)
 gesture(ap,{at(ap),at(slot8)},'activated first')
 local c=slotOf(clover);gesture(c,{at(c)},'activated first')
 check(held()==clover and acts==1,'a click on another slot in the same frame as a drop equips ('..acts..')')
 gesture(slot8,{at(slot8),at(ap)},'release first')
 check(slotOf(apple)==ap,'(put back)')
end
do -- the shovel slot refuses a drop: nothing moves, nothing equips
 reset();local ap=slotOf(apple);local one=dock.Slot1;local shovelName=one.ItemName.Text
 gesture(ap,{at(ap),at(ap,10,0),at(one)},'release first')
 check(slotOf(apple)==ap and one.ItemName.Text==shovelName and acts==0,'a drop on the shovel slot changes nothing')
 gesture(one,{at(one),at(one,30,0),at(slot9)},'release first')
 check(slotOf(apple)==ap and acts==0 and slot9.ItemName.Text=='','the shovel cannot be dragged off its slot')
end
do -- a click on the shovel's own slot still equips it, once
 reset();local one=dock.Slot1
 gesture(one,{at(one,-5,0),at(one,12,5)},'none')
 check(acts==1 and held()~=nil and held():GetAttribute('GardenShovel')==true,'a rolled click on the shovel slot equips the shovel once')
end
do -- an empty slot: nothing, silent
 reset();gesture(slot9,{at(slot9)},'activated first');gesture(slot9,{at(slot9),at(slot9,15,15)},'none')
 check(acts==0,'clicking an empty slot does nothing')
end
do -- two quick clicks are two actions (equip, unequip), never one and never three
 reset();local ap=slotOf(apple)
 gesture(ap,{at(ap)},'activated first');gesture(ap,{at(ap)},'activated first')
 check(acts==2 and held()==nil,'two quick clicks: an equip and an unequip ('..acts..')')
 reset();gesture(ap,{at(ap)},'release first');gesture(ap,{at(ap,9,9),at(ap,18,2)},'release first');gesture(ap,{at(ap)},'none')
 check(acts==3 and held()==apple,'three clicks (clean, rolled, no Activated): three actions ('..acts..')')
end

-- 5. the Bag ------------------------------------------------------------------------------------------------------------------------------------
reset()
local open=dock.OpenInventory;open.Activated:Fire();frames(10)
check(panel.Visible,'(the Bag is open)')
local function cards()local out={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then out[#out+1]=c end end;table.sort(out,function(a,b)return a.AbsolutePosition.X<b.AbsolutePosition.X end);return out end
local function cardOf(tool)for _,c in ipairs(cards())do if c.ItemName.Text:find(Names.Tool(tool,Catalog),1,true)then return c end end end
local card=cardOf(plum)
check(card~=nil,'(the plum has a Bag card)')
if card then
 gesture(card,{at(card)},'activated first')
 check(acts==1 and held()==plum and not panel.Visible,'a Bag card click equips once and closes the Bag ('..acts..')')
 for _,order in ipairs(ORDERS)do
  reset();open.Activated:Fire();frames(10);card=cardOf(plum)
  gesture(card,{at(card,-8,-5),at(card,14,9),at(card,6,3)},order)
  check(acts==1 and held()==plum,('a rolled Bag-card click (%s): exactly one equip (%d)'):format(order,acts))
 end
 -- the grid scrolled under the finger: not a click
 reset();open.Activated:Fire();frames(10);card=cardOf(plum)
 local input={UserInputType=TOUCH,Position=at(card)};card.InputBegan:Fire(input)
 panel.Items.CanvasPosition=R.Vector2.new(0,panel.Items.CanvasPosition.Y+30)
 input.Position=at(card,0,2);W.UIS.InputEnded:Fire(input);frames(2)
 check(acts==0 and panel.Visible,'a drag that scrolled the grid is a scroll, not a click ('..acts..')')
 panel.Items.CanvasPosition=R.Vector2.new(0,0);frames(5)
 -- a card dragged onto a slot is placed, never equipped
 reset();card=cardOf(clover)
 local target=dock.Slot9
 gesture(card,{at(card),at(card,25,0),at(target)},'release first','touch')
 check(slotOf(clover)==target and acts==0 and held()==nil,'a Bag card dragged onto a slot is placed there, first try, not equipped ('..acts..')')
 -- a number key equips while the Bag is open (it did nothing until you closed the Bag)
 local _,slotNo=slotOf(plum);local NUM={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}
 W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[NUM[slotNo]],UserInputType=R.Enum.UserInputType.Keyboard},false);frames(2)
 check(acts==1 and held()==plum and not panel.Visible,'a number key with the Bag open equips once ('..acts..')')
 -- other menus still block the keys
 reset();pg:SetAttribute('SeedMenu','Settings');W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[NUM[slotNo]],UserInputType=R.Enum.UserInputType.Keyboard},false);frames(2)
 check(acts==0,'a number key while another menu is open still does nothing');pg:SetAttribute('SeedMenu',nil)
end
if panel.Visible then open.Activated:Fire();frames(5)end

-- 6. silence ------------------------------------------------------------------------------------------------------------------------------------
check(rec.count()==0 or rec.keys()=='','(the recorder is clear)')
for i=1,10 do check(dock['Slot'..i]:GetAttribute('ButtonSound')==false,'Slot'..i..' carries ButtonSound=false') end
-- the REAL ButtonHighlights bound to the hotbar: a click on a slot adds no Bubble04
do
 rec.clear()
 local okH,H=pcall(W.module,'ButtonHighlights')
 if okH and H and H.Start then
  local okS,stop=pcall(H.Start,pg)
  if okS then
   reset();gesture(A,{at(A)},'activated first');gesture(A,{at(A,12,3),at(A,19,5)},'release first');gesture(A,{at(A),at(slot9)},'release first')
   for i=2,10 do dock['Slot'..i].Activated:Fire()end
   check(rec.count()==0,'with ButtonHighlights running, slot clicks, rolled clicks and drops play nothing ('..rec.keys()..')')
   if type(stop)=='function'then stop()end
  else print('NOTE ButtonHighlights.Start not runnable on the mock: '..tostring(stop))end
 else print('NOTE ButtonHighlights not loadable on the mock')end
end
reset()
local nonSilent=rec.count()
for i=1,10 do local b=dock['Slot'..i];b.MouseEnter:Fire();b.MouseLeave:Fire();b.SelectionGained:Fire();b.SelectionLost:Fire()end
check(nonSilent==0 and rec.count()==0,'no sound for any hotbar gesture, hover or focus ('..rec.keys()..')')
-- no sound is made by the Hotbar itself either (a Sound instance parented anywhere by it)
local made=0;for _,s in ipairs(E.sounds)do if s.Plays>0 then made+=1 end end
check(made==0,'the Hotbar plays no Sound instance ('..made..')')

-- 7. one odd item or picture never freezes the hotbar ---------------------------------------------------------------------------------------------------
do
 local Arrival=W.module('HarvestArrival');local Pictures=W.module('ItemPictures')
 local realHolds,realShow,realPrefetch=Arrival.Holds,Pictures.Show,Pictures.Prefetch
 local warns,byLabel=0,{};local realWarn=W.env.warn;W.env.warn=function(msg)msg=tostring(msg);if msg:find('[R152] Hotbar',1,true)then warns+=1;byLabel[msg:match('Hotbar: (.-) skipped')or msg]=(byLabel[msg:match('Hotbar: (.-) skipped')or msg]or 0)+1 end end
 Arrival.Holds=function(tool)if tool.Name=='PoisonItem'then error('boom: an item whose hold check raises')end;return realHolds(tool)end
 Pictures.Show=function(parent,tool,size,...)if tool and tool.Name=='PoisonPic'then error('boom: a picture that raises')end;return realShow(parent,tool,size,...)end
 local prefetches=0;Pictures.Prefetch=function(...)prefetches+=1;if prefetches<=2 then error('boom: the picture cache')end;return realPrefetch(...)end
 reset();hum:UnequipTools();frames(3)
 local poison=harvest('PeachSeed','plant-P');poison.Name='PoisonItem';poison.Parent=bag
 local orange=harvest('OrangeSeed','plant-O');orange.Parent=bag;frames(10)
 local s,i=slotOf(orange)
 check(s~=nil,'an item whose check raises does not stop the next item from reaching the hotbar')
 if s then reset();gesture(s,{at(s)},'activated first');check(acts==1 and held()==orange,'... and that item equips on the first click ('..acts..')')end
 check(byLabel['an item']==1,'the failing item is warned once ('..tostring(byLabel['an item'])..')');local w0=warns
 for k=1,5 do local f=harvest('LimeSeed','plant-L'..k);f.Parent=bag;frames(3)end
 check(byLabel['an item']==1,'repeated refreshes do not repeat the warning ('..tostring(byLabel['an item'])..')')
 local pic=harvest('FigSeed','plant-F');pic.Name='PoisonPic';pic.Parent=bag
 local lemon=harvest('MangoSeed','plant-M');lemon.Parent=bag;frames(10)
 local s2=slotOf(lemon)
 check(s2~=nil,'a slot whose picture raises does not stop the other slots from updating')
 if s2 then reset();hum:UnequipTools();frames(2);reset();gesture(s2,{at(s2)},'release first');check(acts==1 and held()==lemon,'... and its item equips on the first click')end
 check(prefetches>=3 and byLabel['the picture cache']==1 and byLabel['a slot']==1,'(the picture cache raised twice and recovered, each kind of failure warned once: '..prefetches..' calls, '..tostring(byLabel['the picture cache'])..' / '..tostring(byLabel['a slot'])..')')
 Arrival.Holds,Pictures.Show,Pictures.Prefetch=realHolds,realShow,realPrefetch;W.env.warn=realWarn
 poison:Destroy();pic:Destroy();frames(5)
end

print(('R152 hotbar click checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
