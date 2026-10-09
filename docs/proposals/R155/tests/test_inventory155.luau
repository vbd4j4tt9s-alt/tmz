--!nocheck
-- R155 (owner: "hot bar and inventory management is still not fixed just make it function like the normal inventory (not look like) it should feel responsive
-- and i have a lot of options to manage my inventory i can have a blank hot bar if i put everything in my bag additionally make the max amount of items a person
-- can hold 200", then "allow people to discard items"). The REAL Hotbar + InventoryPanel155 + DiscardDialog155 + GardenInventoryState driven through R153's
-- engine model (engine153.luau: every event derived from a pointer at a screen point, in the variant / order the runner picks: VARIANT, ORDER).
--  1. new items: a stack joins its stack; else the first free slot; else the Bag; nothing jumps onto a slot that frees up; the Bag lists only what is not on the hotbar.
--  2. every drag: slot -> empty slot / taken slot (swap), slot -> the open Bag / the Bag button (the slot stays BLANK), Bag -> empty slot / taken slot (the item there
--     goes to the Bag), Bag -> Bag (nothing), mouse and touch (a touch from a slot after the 0.4 s hold), the shovel too; no drag ever equips.
--  3. a fully blank hotbar: everything into the Bag; new items then go to the Bag; it stays blank across refreshes and a respawn.
--  4. tap-tap: a touch held and let go in place picks the item (the Bag opens, its ring, every slot outlined, the bar says what to do); then a tap on a slot / a Bag
--     card / To Bag / the Bag button / the Trash / itself / the world; right-click picks (mouse) and a number key puts it there; gamepad Y picks, A places.
--  5. instant equip: the slot (and a Bag card) shows as held on the very frame the press ends (before any server reply); equipping from the Bag leaves it in the Bag.
--  6. search filters the Bag and dims the hotbar slots that do not match; backtick (`) and B open / close the Bag.
--  7. the count: "143/200" (white), amber from 180, "200/200 FULL" in red with FULL on the Bag button; with no count from the server it counts the items it sees.
--  8. discard: a stack dropped on the Trash (1 / a number / All), a single item via tap-tap, a rare item needs the 1 s hold (a tap or a short press does nothing),
--     the shovel can't be thrown away, a server refusal is shown and the popup stays, Keep it sends nothing.
--  9. the layout survives a respawn and a REJOIN (a new Hotbar with the layout the first one sent to the server, the items handed over in another order).
-- 10. the seed collect target (R154) is the slot the seed will really take, or the Bag button when every free slot is blank.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder()
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class:find('Button')then o.MouseButton2Click=R.signal()end;return o end end -- (right-click)
E.player('Tester')
local player,pg=E.Player,E.pg
local X=require('./engine153')(W,E,F,{Variant=VARIANT or'began',Order=ORDER or'activated first',Handoff='empty'})
local hum=E.hum;local acts=0
local function wrap(h)local eq,un=h.EquipTool,h.UnequipTools;h.EquipTool=function(self,tool)acts+=1;return eq(self,tool)end;h.UnequipTools=function(self)acts+=1;return un(self)end end
wrap(hum);X.onHumanoid=function(h)hum=h;wrap(h)end
local bag=function()return player:FindFirstChildOfClass('Backpack')end
local char=function()return player.Character end
print(('engine: %s, %s'):format(X.Variant,X.Order))
-- the server side the Bag talks to: DiscardItems (removes the stack's tools) and HotbarLayout155 (records what is sent)
local Stacks=W.module('InventoryStacks155')
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local discardRemote=R.new('RemoteFunction');discardRemote.Name='DiscardItems';discardRemote.Parent=remotes
local layoutRemote=R.new('RemoteEvent');layoutRemote.Name='HotbarLayout155';layoutRemote.Parent=remotes
local requests,sent={},{};local refuseWith=nil
discardRemote.InvokeServer=function(_,req)
 requests[#requests+1]=req
 if refuseWith then return {Ok=false,Message=refuseWith}end
 local chosen;for _,c in ipairs({bag(),char()})do for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')and Stacks.Id(t)==req.Id then chosen=t end end end
 if not chosen then return {Ok=false,Message='THAT ITEM IS ALREADY GONE!'}end
 local key=Stacks.Key(chosen);local list={}
 for _,c in ipairs({bag(),char()})do for _,t in ipairs(c:GetChildren())do if t:IsA('Tool')and(t==chosen or key and Stacks.Key(t)==key)then list[#list+1]=t end end end
 if req.Count>#list then return {Ok=false,Message='U DON\'T HAVE THAT MANY!'}end
 for i=1,req.Count do list[i]:Destroy()end
 return {Ok=true,Removed=req.Count,Message='threw away '..req.Count..'x '..chosen.Name}
end
layoutRemote.FireServer=function(_,text)sent[#sent+1]=text end
-- the items
local shovel=F.shovel(W,bag())
local function harvest(seed,crop,n)local t=F.fruit(W,nil,seed,1,'None',700,1);t:SetAttribute('SourceCropId',crop);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0);return t end
local apple=F.seed(W,bag(),'AppleSeed',1,'None');local blue=harvest('BluebellSeed','plant-1');blue.Parent=bag()
local bat=F.bat(W,bag());local packA=F.pack(W,bag(),2,'Pack06',1,'None');local packB=F.pack(W,bag(),3,'Pack02',1,'None')
local sc=R.new('LocalScript');sc.Name='Hotbar';local ok,err=pcall(W.load,'Hotbar',sc);check(ok,'Hotbar loads: '..tostring(err))
X.frames(30)
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog');local Inv=W.module('InventoryPanel155');local Dialog=W.module('DiscardDialog155')
local gui,dock,panel,open
local function grab()gui=pg.ChestToolHotbar;dock=gui.Dock;panel=gui.Inventory;open=dock.OpenInventory end;grab()
local function slot(i)return dock['Slot'..i]end
local function slotOf(tool)local n=Names.Tool(tool,Catalog);for i=1,10 do local s=slot(i);if s.Visible and s.ItemName.Text==n then return s,i end end end
local function at(tool)local _,i=slotOf(tool);return i end
local function names()local out={};for i=1,10 do out[i]=slot(i).ItemName.Text end;return out end
local function filledCount()local n=0;for i=1,10 do if slot(i).ItemName.Text~=''then n+=1 end end;return n end
local function held()return char():FindFirstChildOfClass('Tool')end
local function settle()hum:UnequipTools();X.wait(.5);acts=0 end
local function cards()local out={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then out[#out+1]=c end end;return out end
local function cardOf(tool)local n=Names.Tool(tool,Catalog);for _,c in ipairs(cards())do if c.ItemName.Text:sub(1,#n)==n then return c end end end
local function openBag()if not panel.Visible then X.tap('mouse',open);X.frames(5)end end
local function closeBag()if panel.Visible then X.tap('mouse',panel.Close);X.frames(5)end end
local NUM={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}
local function key(code)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[code],UserInputType=R.Enum.UserInputType.Keyboard,Position=R.Vector3.new(0,0,0)},false);X.frames(1)end
local function holdRelease(b)local p=X.center(b);X.down('touch',p);X.wait(.55);X.up(p);X.frames(3)end
local function blankSlots()local n=0;for i=1,10 do local s=slot(i);if s.ItemName.Text==''then n+=1 end end;return n end
local function copyTool(t,parent) -- (a new instance of the same item, as the server hands it back after a respawn / a rejoin)
 local c=R.new('Tool');c.Name=t.Name;for k,v in pairs(t._attrs)do c:SetAttribute(k,v)end;local h=R.new('Part');h.Name='Handle';h.Parent=c;c.Parent=parent;return c
end

-- 1. new items ----------------------------------------------------------------------------------------------------------------------------------------
do
 check(at(shovel)==1 and at(apple)==2 and at(blue)==3 and at(bat)==4 and at(packA)==5 and at(packB)==6,'a fresh hotbar in arrival order, the shovel first ('..table.concat(names(),'|')..')')
 local apple2=F.seed(W,bag(),'AppleSeed',1,'None');X.frames(5)
 check(slot(2).Count.Visible and slot(2).Count.Text=='x2'and filledCount()==6,'a second Apple Seed joins its stack on slot 2 (x2)')
 local fig=harvest('FigSeed','plant-f');fig.Parent=bag();X.frames(5)
 check(at(fig)==7,'a new kind of item takes the first free slot (7)')
 local more={};for k,s in ipairs({'KiwiSeed','PearSeed','GrapeSeed','CherrySeed','LemonSeed'})do more[k]=harvest(s,'plant-m'..k);more[k].Parent=bag()end;X.frames(5)
 check(filledCount()==10 and slotOf(more[4])==nil and slotOf(more[5])==nil,'the hotbar full: the next ones go to the Bag ('..filledCount()..')')
 openBag();check(cardOf(more[4])~=nil and cardOf(more[5])~=nil and cardOf(apple)==nil and cardOf(shovel)==nil,'the Bag lists only what is not on the hotbar ('..#cards()..' cards)');closeBag()
 local before=table.concat(names(),'|');fig:Destroy();X.frames(10)
 check(slot(7).ItemName.Text==''and slotOf(more[4])==nil and slotOf(more[5])==nil,'an item used up frees its slot; no Bag item jumps onto it')
 for _=1,3 do X.frames(20)end;check(slot(7).ItemName.Text=='','... across refreshes')
 local late=harvest('MelonSeed','plant-late');late.Parent=bag();X.frames(5)
 check(at(late)==7,'the next new item takes the freed slot')
 late:Destroy();more[4]:Destroy();more[5]:Destroy();for k=1,3 do more[k]:Destroy()end;apple2:Destroy();X.frames(10)
end

-- 2. drags --------------------------------------------------------------------------------------------------------------------------------------------
for _,how in ipairs({'mouse','touch'})do
 settle()
 local function drag(from,to)if how=='touch'then X.drag('touch',from,to,.5)else X.drag('mouse',from,to)end end -- (a phone holds 0.4 s first)
 do -- while an item is lifted every other slot is outlined (clear drop targets, a phone's hold-drag too); the outlines go when it is let go
  local function outlined()local n,own=0,false;local _,a=slotOf(apple);for i=1,10 do local h=slot(i):FindFirstChild('DropHint');if h and h.Visible then if i==a then own=true else n+=1 end end end;return n,own end
  local shown=0;for i=1,10 do if slot(i).Visible then shown+=1 end end
  local _,a=slotOf(apple);local p,q=X.center(slot(a)),X.center(slot(9));X.down(how,p);if how=='touch'then X.wait(.5)end
  for i=1,3 do X.move(R.Vector2.new(p.X+(q.X-p.X)*i/6,p.Y+(q.Y-p.Y)*i/6));X.frames(1)end
  local n,own=outlined();check(n==shown-1 and not own,how..': mid-drag every other slot is outlined as a drop target ('..n..' of '..(shown-1)..')')
  local w=R.Vector2.new(640,200);X.move(w);X.frames(1);X.up(w);X.frames(3)
  n=outlined();check(n==0 and at(apple)==a and acts==0,how..': ... the outlines go when it is let go (in the world: nothing moved, nothing equipped)')
 end
 local _,a=slotOf(apple);drag(slotOf(apple),slot(9))
 check(at(apple)==9 and slot(a).ItemName.Text==''and acts==0,how..': slot -> empty slot moves it, nothing equipped')
 drag(slotOf(apple),slotOf(blue));check(at(apple)==3 and at(blue)==9 and acts==0,how..': slot -> taken slot swaps them ('..tostring(at(apple))..','..tostring(at(blue))..')')
 drag(slotOf(apple),slot(2));drag(slotOf(blue),slot(3))
 check(at(apple)==2 and at(blue)==3,how..': (back)')
 drag(slotOf(shovel),slot(8));check(at(shovel)==8 and slot(1).ItemName.Text=='',how..': the shovel moves like any item (R153 kept slot 1)')
 drag(slotOf(shovel),slot(1));check(at(shovel)==1,how..': (back)')
 -- into the Bag: the slot stays blank
 openBag();drag(slotOf(bat),panel.Items);X.frames(3)
 check(slotOf(bat)==nil and cardOf(bat)~=nil and acts==0,how..': slot -> the open Bag: it is a Bag card now')
 closeBag();drag(slotOf(packB),open);X.frames(3)
 check(slotOf(packB)==nil and slot(4).ItemName.Text==''and slot(6).ItemName.Text=='',how..': slot -> the Bag button: off the hotbar, the slots stay blank')
 local newOne=harvest('PlumSeed','plant-p');newOne.Parent=bag();X.frames(5)
 check(at(newOne)==7,how..': a new item skips the blank slots 4 and 6 (takes '..tostring(at(newOne))..')')
 -- from the Bag: onto an empty (blank) slot, onto a taken slot (the item there goes to the Bag), within the Bag (nothing)
 openBag();drag(cardOf(bat),slot(4));X.frames(3)
 check(at(bat)==4 and acts==0,how..': Bag -> blank slot: placed ('..tostring(at(bat))..')')
 openBag();drag(cardOf(packB),slotOf(newOne));X.frames(3)
 check(at(packB)==7 and slotOf(newOne)==nil and(openBag()or true)and cardOf(newOne)~=nil and acts==0,how..': Bag -> taken slot: swapped, the item that was there is in the Bag now')
 openBag();local c=cards();if #c>=2 then local list=table.concat(names(),'|');drag(c[1],c[2]);check(table.concat(names(),'|')==list and acts==0,how..': Bag -> Bag changes nothing')end
 closeBag();newOne:Destroy();X.frames(5)
 openBag();if not slotOf(packB)then drag(cardOf(packB),slot(6))end;closeBag()
 drag(slotOf(packB),slot(6));X.frames(3)
end
check(at(shovel)==1 and at(apple)==2 and at(blue)==3 and at(bat)==4 and at(packA)==5 and at(packB)==6,'(the layout back: '..table.concat(names(),'|')..')')

-- 5. instant equip (before section 3: the items are on the hotbar) ------------------------------------------------------------------------------------
do
 for _,t in ipairs({apple,blue,packA})do
  settle();local s=slotOf(t);local p=X.center(s);X.down('mouse',p);X.up(p)
  check(s:GetAttribute('Selected')==true,('%s: the slot shows as held on the frame the click ends (before the server answers)'):format(t.Name))
  check(gui.Dock.SelectedName.Text~='','... and its name shows above the hotbar at once')
  X.frames(2);X.up(p)
 end
 settle();local moreFruit=harvest('KiwiSeed','plant-k');moreFruit.Parent=bag();X.frames(3);openBag()
 X.drag('mouse',slotOf(moreFruit),panel.Items);X.frames(3)
 local card=cardOf(moreFruit);check(card~=nil,'(an item in the Bag)')
 if card then local p=X.center(card);X.down('mouse',p);X.up(p)
  check(held()==moreFruit,'a Bag card click holds the item at once ('..tostring(held()and held().Name)..')');X.frames(3)
  check(slotOf(moreFruit)==nil,'equipping from the Bag leaves it in the Bag (nothing is pushed off the hotbar)')
  openBag();local c2=cardOf(moreFruit);check(c2 and c2:GetAttribute('Selected')==true,'... and its card shows it is held');closeBag()
 end
 moreFruit:Destroy();X.frames(5)
end

-- 6. search, keys ----------------------------------------------------------------------------------------------------------------------------------
do
 settle();local extra={};for k,s in ipairs({'KiwiSeed','PearSeed'})do extra[k]=harvest(s,'plant-s'..k);extra[k].Parent=bag()end;X.frames(3)
 for _,t in ipairs(extra)do if slotOf(t)then openBag();X.drag('mouse',slotOf(t),panel.Items);X.frames(2)end end
 openBag();panel.Search.Text='pear';X.frames(3)
 local list=cards();check(#list==1 and cardOf(extra[2])~=nil,'search filters the Bag ('..#list..' cards)')
 local dimmed=0;for i=1,10 do local d=slot(i):FindFirstChild('SearchDim');if d and d.Visible then dimmed+=1 end end
 check(dimmed>=6,'and dims the hotbar slots that do not match ('..dimmed..')')
 panel.Search.Text='apple';X.frames(3)
 check(not(slot(2):FindFirstChild('SearchDim')and slot(2).SearchDim.Visible),'a hotbar slot that matches is not dimmed')
 panel.Search.Text='';X.frames(3);dimmed=0;for i=1,10 do local d=slot(i):FindFirstChild('SearchDim');if d and d.Visible then dimmed+=1 end end
 check(dimmed==0,'clearing the search undims them')
 closeBag();key('Backquote');check(panel.Visible,'backtick opens the Bag (like Roblox)');key('Backquote');check(not panel.Visible,'and closes it')
 key('B');check(panel.Visible,'B too');key('B')
 for _,t in ipairs(extra)do t:Destroy()end;X.frames(5)
end

-- 4. tap-tap ------------------------------------------------------------------------------------------------------------------------------------------
do
 settle()
 holdRelease(slotOf(apple))
 local p=Inv.Picked();local s2=slot(2)
 check(p~=nil and panel.Visible and s2:FindFirstChild('PickedRing')and s2.PickedRing.Visible and acts==0,'a touch held 0.4 s and let go in place picks it (the Bag opens, its ring; nothing equipped)')
 local hinted=0;for i=1,10 do local h=slot(i):FindFirstChild('DropHint');if h and h.Visible then hinted+=1 end end
 check(hinted==9,'every other slot is outlined as a place it can go ('..hinted..')')
 check(panel.BagBar.PickBar.Visible and panel.BagBar.PickBar.PickName.Text:find('Apple',1,true)~=nil,'the Bag bar says what is picked and what to do')
 X.tap('touch',slot(9));X.frames(3)
 check(at(apple)==9 and Inv.Picked()==nil and acts==0,'then a tap on an empty slot puts it there ('..tostring(at(apple))..')')
 holdRelease(slotOf(apple));X.tap('touch',slotOf(blue));X.frames(3)
 check(at(apple)==3 and at(blue)==9,'a tap on a taken slot swaps them')
 holdRelease(slotOf(apple));X.tap('touch',panel.BagBar.PickBar.PickStash);X.frames(3)
 check(slotOf(apple)==nil and cardOf(apple)~=nil and slot(3).ItemName.Text=='','"To Bag": into the Bag, its slot blank')
 -- from the Bag: hold its card, tap a taken slot -> the card's item there, that slot's item to the Bag
 openBag();holdRelease(cardOf(apple))
 check(Inv.Picked()~=nil and acts==0,'a Bag card held and let go is picked too')
 X.tap('touch',slotOf(blue));X.frames(3)
 check(at(apple)==9 and slotOf(blue)==nil and cardOf(blue)~=nil,'tap a taken slot: placed, the item that was there into the Bag')
 holdRelease(cardOf(blue));X.tap('touch',slot(3));X.frames(3);check(at(blue)==3,'(and the other one back on a blank slot)')
 -- picked from the hotbar, tap a Bag card: into the Bag
 holdRelease(slotOf(blue));openBag();local someCard=cards()[1]
 if someCard then X.tap('touch',someCard);X.frames(3);check(slotOf(blue)==nil and cardOf(blue)~=nil,'picked from the hotbar, a tap on the Bag: it goes in the Bag')end
 openBag();holdRelease(cardOf(blue));X.tap('touch',slot(3));X.frames(3)
 -- put down: a tap on itself, the X, a tap in the world, closing the Bag
 settle();holdRelease(slotOf(apple));X.tap('touch',slotOf(apple));X.frames(2);check(Inv.Picked()==nil and at(apple)==9 and acts==0,'a tap on the picked item puts it down (no equip: '..acts..', picked '..tostring(Inv.Picked()~=nil)..', slot '..tostring(at(apple))..')')
 holdRelease(slotOf(apple));X.tap('touch',panel.BagBar.PickBar.PickCancel);X.frames(2);check(Inv.Picked()==nil,'the X puts it down')
 holdRelease(slotOf(apple));X.down('touch',R.Vector2.new(640,200));X.up(R.Vector2.new(640,200));X.frames(2);check(Inv.Picked()==nil,'a tap in the world puts it down')
 holdRelease(slotOf(apple));closeBag();check(Inv.Picked()==nil,'closing the Bag puts it down')
 -- "Hold" holds it
 holdRelease(slotOf(apple));X.tap('touch',panel.BagBar.PickBar.PickHold);X.frames(3);check(held()==apple and not panel.Visible,'"Hold" holds it (and closes the Bag)')
 settle()
 -- mouse: right-click picks, a number key puts it there; the Bag button takes it
 slotOf(apple).MouseButton2Click:Fire();X.frames(2);check(Inv.Picked()~=nil and panel.Visible,'right-click picks (mouse)')
 key('Seven');check(at(apple)==7 and Inv.Picked()==nil,'and a number key puts it on that slot ('..tostring(at(apple))..')')
 slotOf(apple).MouseButton2Click:Fire();X.frames(2);closeBag();slotOf(apple).MouseButton2Click:Fire();X.frames(2)
 check(Inv.Picked()~=nil,'(picked again)');X.tap('mouse',open);X.frames(3)
 check(slotOf(apple)==nil and Inv.Picked()==nil,'with a hotbar item picked the Bag button takes it into the Bag')
 -- gamepad: Y on the focused card picks it, A on a slot places it
 openBag();W.Gui.SelectedObject=cardOf(apple);W.actions.GardenBagPick('GardenBagPick',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonY});X.frames(2)
 check(Inv.Picked()~=nil,'gamepad: Y on the focused Bag card picks it')
 W.Gui.SelectedObject=slot(9);slot(9).Activated:Fire({UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonA});X.frames(3)
 check(at(apple)==9 and acts==0,'gamepad: A on a slot puts it there ('..tostring(at(apple))..')')
 W.Gui.SelectedObject=nil
 W.actions.GardenBagToggle('GardenBagToggle',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.DPadUp});X.frames(2)
 check(not panel.Visible,'gamepad: DPad-Up closes the Bag');W.actions.GardenBagToggle('GardenBagToggle',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.DPadUp});X.frames(2)
 check(panel.Visible,'... and opens it');closeBag()
 X.drag('mouse',slotOf(apple),slot(2));X.drag('mouse',slotOf(blue),slot(3));closeBag()
 check(at(apple)==2 and at(blue)==3,'(the layout back)')
end

-- 7. the count -------------------------------------------------------------------------------------------------------------------------------------------
do
 openBag();local label=panel.BagBar.HeldCount
 local items=0;for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')and Stacks.Counts(t)then items+=1 end end
 for _,t in ipairs(char():GetChildren())do if t:IsA('Tool')and Stacks.Counts(t)then items+=1 end end
 check(label.Text==items..'/200','with no count from the server it counts what it sees ('..label.Text..', '..items..' items: the shovel and the bat do not count)')
 player:SetAttribute('HeldItemCap',200);player:SetAttribute('HeldItemCount',143);X.frames(1)
 check(label.Text=='143/200'and label.TextColor3.R>.9 and label.TextColor3.G>.9,'"143/200" in white')
 player:SetAttribute('HeldItemCount',185);X.frames(1)
 check(label.Text=='185/200'and label.TextColor3.G<.85 and label.TextColor3.R>.9,'from 180: amber ('..label.Text..')')
 player:SetAttribute('HeldItemCount',200);X.frames(1)
 check(label.Text=='200/200 FULL'and label.TextColor3.G<.5 and open.FullBadge.Visible,'200: "200/200 FULL" in red, and FULL on the Bag button')
 player:SetAttribute('HeldItemCount',230);X.frames(1);check(label.Text=='230/200 FULL','an old save above 200 shows as it is ('..label.Text..')')
 player:SetAttribute('HeldItemCount',12);X.frames(1);check(not open.FullBadge.Visible,'under the cap: no FULL badge')
 closeBag()
end

-- 8. discard -----------------------------------------------------------------------------------------------------------------------------------------
do
 settle()
 local stack={F.seed(W,bag(),'CloverSeed',1,'None'),F.seed(W,bag(),'CloverSeed',1,'None'),F.seed(W,bag(),'CloverSeed',1,'None')};X.frames(5)
 local s,i=slotOf(stack[1]);check(s and s.Count.Text=='x3','(a stack of 3 on slot '..tostring(i)..')')
 openBag();X.drag('mouse',s,panel.BagBar.Trash);X.frames(3)
 local ui=Dialog.UI();check(Dialog.IsOpen()and ui.Row.Visible and ui.Warning.Text:find("gone forever",1,true)~=nil,'a stack dropped on the Trash: "u sure? it\'s gone forever" with 1 / - n + / All')
 check(ui.Name.Text==Names.Tool(stack[1],Catalog),'the popup names the item ('..ui.Name.Text..')')
 X.tap('mouse',ui.Row.More);X.tap('mouse',ui.Row.More);X.tap('mouse',ui.Row.More);check(ui.Row.Count.Text=='3','+ stops at the stack size (3)')
 X.tap('mouse',ui.Row.One);check(ui.Row.Count.Text=='1','1')
 ui.Row.Count.Text='2';ui.Row.Count.FocusLost:Fire();X.frames(1);check(ui.Row.Count.Text=='2','a typed number')
 X.tap('mouse',ui.Confirm);X.frames(3)
 check(#requests==1 and requests[1].Count==2 and requests[1].Kind=='Seed'and not Dialog.IsOpen(),'Discard: the server is asked for exactly 2 of that stack; the popup closes')
 X.frames(5);local s2=slotOf(stack[3])or slotOf(stack[1])or slotOf(stack[2])
 check(s2 and s2.Count.Visible==false,'one left on its slot')
 -- the last one, by tap-tap: hold, then the Trash; one item asks no amount
 holdRelease(s2);X.tap('touch',panel.BagBar.Trash);X.frames(2)
 check(Dialog.IsOpen()and not ui.Row.Visible,'tap-tap: picked, then the Trash: the popup (one item: no amount)')
 X.tap('touch',ui.Confirm);X.frames(5)
 check(#requests==2 and requests[2].Count==1,'and Discard sends 1')
 local freed=true;for _,t in ipairs(stack)do if t.Parent then freed=false end end;check(freed,'(all three are gone)')
 -- Keep it: nothing is sent
 openBag();X.drag('mouse',slotOf(blue),panel.BagBar.Trash);X.frames(2);X.tap('mouse',ui.Keep);X.frames(2)
 check(not Dialog.IsOpen()and #requests==2 and blue.Parent~=nil,'Keep it: nothing is sent, the item stays')
 -- a refusal: shown in the popup, which stays
 refuseWith='WAIT FOR UR PACK TO FINISH OPENING!'
 openBag();X.drag('mouse',slotOf(blue),panel.BagBar.Trash);X.frames(2);X.tap('mouse',ui.Confirm);X.frames(3)
 check(Dialog.IsOpen()and ui.Status.Visible and ui.Status.Text:find('finish opening',1,true)~=nil and blue.Parent~=nil,'a server refusal is shown and the popup stays ('..ui.Status.Text..')')
 refuseWith=nil;X.tap('mouse',ui.Keep);X.frames(2)
 -- a rare item: a tap does nothing, a short press does nothing, a 1 s hold throws it away
 local gold=F.seed(W,bag(),'CloverSeed',1,'Gold');X.frames(5)
 openBag();X.drag('mouse',slotOf(gold)or cardOf(gold),panel.BagBar.Trash);X.frames(2)
 check(Dialog.IsOpen()and ui.Confirm.Text:lower():find('hold',1,true)~=nil,'a Gold (mutated) item: the button says hold to discard')
 local n0=#requests;X.tap('mouse',ui.Confirm);X.frames(3);check(#requests==n0,'a tap does not throw a rare item away')
 local p=X.center(ui.Confirm);X.down('mouse',p);X.wait(.4);X.up(p);X.frames(3);check(#requests==n0 and Dialog.IsOpen(),'a short press does not either (the bar starts again)')
 X.down('touch',p);X.wait(1.15);X.up(p);X.frames(3)
 check(#requests==n0+1 and gold.Parent==nil,'held for 1 s: thrown away')
 -- a Secret seed and a Mech / Verity / Void pack need the hold too; plain ones do not
 local secret=F.seed(W,bag(),'CloverSeed',1,'None');secret:SetAttribute('Rarity','Secret')
 check(Stacks.Rare(secret)and Stacks.Rare(F.pack(W,nil,7,'EclipseReliquary',1,'None'))and Stacks.Rare(F.pack(W,nil,8,'MechLimited',1,'None'))and Stacks.Rare(F.pack(W,nil,7,'VerityReliquary',1,'None')),'Secret / Cosmic / King, Void / Mech / Verity packs: the hold')
 check(not Stacks.Rare(apple)and not Stacks.Rare(packA),'a plain seed or pack: no hold')
 secret:Destroy()
 -- the shovel can't be thrown away
 openBag();local nD=#requests;X.drag('mouse',slotOf(shovel),panel.BagBar.Trash);X.frames(3)
 check(not Dialog.IsOpen()and #requests==nD and shovel.Parent~=nil,'the shovel can\'t be thrown away (no popup, nothing sent)')
 closeBag()
end

-- 3. a fully blank hotbar -----------------------------------------------------------------------------------------------------------------------------
local layoutBefore,rejoinGift
do
 settle();openBag()
 for i=1,10 do local s=slot(i);if s.ItemName.Text~=''then X.drag('mouse',s,panel.Items);X.frames(2)end end
 closeBag();check(blankSlots()==10,'everything into the Bag: a fully blank hotbar ('..blankSlots()..' blank)')
 local newbie=harvest('MangoSeed','plant-n');newbie.Parent=bag();X.frames(5)
 check(blankSlots()==10 and slotOf(newbie)==nil,'a new item on a blank hotbar goes to the Bag')
 X.frames(60);check(blankSlots()==10,'it stays blank across refreshes')
 -- a respawn: still blank, everything back in the Bag
 local spec={};for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')then spec[#spec+1]=t end end
 X.respawn(function(nb)for k=#spec,1,-1 do copyTool(spec[k],nb)end end)
 X.frames(10);check(blankSlots()==10,'... and across a respawn ('..blankSlots()..' blank)')
 -- put a few back for the next sections
 local function find(name)for _,t in ipairs(bag():GetChildren())do if t.Name==name then return t end end end
 shovel,apple,blue,bat,packA,packB=find('Shovel'),find(apple.Name),find(blue.Name),find('Bat'),find(packA.Name),find(packB.Name)
 openBag();for k,t in ipairs({shovel,apple,blue,bat})do X.drag('mouse',cardOf(t),slot(k));openBag()end
 X.drag('mouse',cardOf(packA),slot(7));closeBag();newbie=find(newbie.Name);if newbie then newbie:Destroy()end;X.frames(5)
 check(at(shovel)==1 and at(apple)==2 and at(blue)==3 and at(bat)==4 and at(packA)==7 and blankSlots()==5,'(a layout with blank slots: '..table.concat(names(),'|')..')')
 layoutBefore=table.concat(names(),'|')
end

-- 9. the layout survives a respawn and a rejoin --------------------------------------------------------------------------------------------------
do
 X.wait(Inv.JoinFallback+1) -- (no server here: the join ends by itself)
 X.drag('mouse',slotOf(packA),slot(6));X.drag('mouse',slotOf(packA),slot(7));X.wait(3)
 check(#sent>=1,'the layout is sent to the server a moment after it changes ('..#sent..' sends)')
 local saved=sent[#sent]
 check(saved and #saved<=100,'(what was sent: '..tostring(saved)..')')
 -- a respawn
 local spec={};for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')then spec[#spec+1]=t end end
 X.respawn(function(nb)for k=#spec,1,-1 do copyTool(spec[k],nb)end end);X.frames(10)
 check(table.concat(names(),'|')==layoutBefore and blankSlots()==5,'after a respawn: the same layout, blank slots blank')
 -- a rejoin: the Hotbar starts again with the layout it sent; the items arrive in another order (new instances), then the server says they are all there
 local tools={};for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')then tools[#tools+1]=t end end
 sc:Destroy();X.frames(2)
 check(pg:FindFirstChild('ChestToolHotbar')==nil,'(the old Hotbar is gone)')
 local nb=bag();for _,t in ipairs(tools)do t.Parent=nil end
 player:SetAttribute('HotbarLayout155',saved);player:SetAttribute('InventorySynced155',false)
 local sc2=R.new('LocalScript');sc2.Name='Hotbar';local ok2,err2=pcall(W.load,'Hotbar',sc2);check(ok2,'the Hotbar starts again: '..tostring(err2))
 grab();X.frames(5)
 for k=#tools,1,-1 do copyTool(tools[k],nb);if k%3==0 then X.frames(2)end end
 X.frames(5);player:SetAttribute('InventorySynced155',true);X.wait(2)
 check(table.concat(names(),'|')==layoutBefore,'after a rejoin: every item on its saved slot ('..table.concat(names(),'|')..')')
 check(blankSlots()==5,'and the blank slots are still blank')
 -- (slot 6 is FREE, not blank: the pack moved away from it to 7; 5, 8, 9 and 10 are blank since the hotbar was emptied)
 local gift=harvest('LimeSeed','plant-g');gift.Parent=bag();X.frames(5)
 check(at(gift)==6,'a new item after the join takes the free slot 6, never a blank one ('..tostring(at(gift))..')')
 rejoinGift=gift
 sc=sc2
end

-- 10. the seed collect target -----------------------------------------------------------------------------------------------------------------------
do
 local Collect=W.module('SeedCollect154')
 local b=Collect.Target('not-here-yet',{SeedId='OrangeSeed',SeedScale=1,Mutation='None',Weather='None'})
 -- (the free slots of this layout are all blank: the seed would go to the Bag)
 check(b==open,'every free slot is blank: a pulled seed flies to the Bag button ('..tostring(b and b.Name)..')')
 -- free a slot that is not blank: an item used up
 local tSlot=rejoinGift and at(rejoinGift)
 if tSlot then rejoinGift:Destroy();X.frames(5)
  local b2=Collect.Target('not-here-yet',{SeedId='OrangeSeed',SeedScale=1,Mutation='None',Weather='None'})
  check(b2==slot(tSlot),'a free (not blank) slot: the seed flies to it ('..tostring(b2 and b2.Name)..', slot '..tSlot..')')
  local seed=F.seed(W,bag(),'OrangeSeed',1,'None');X.frames(5)
  check(at(seed)==tSlot,'and that is where it lands')
  local b3=Collect.Target('another',{SeedId='OrangeSeed',SeedScale=1,Mutation='None',Weather='None'})
  check(b3==slot(tSlot),'another of the same stack flies to that stack\'s slot')
 else check(false,'(a free slot for the temp item)')end
end
print(('R155 inventory checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
