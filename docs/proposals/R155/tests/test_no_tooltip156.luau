--!nocheck
-- R156 (owner, after seeing the panel on screen: "these descriptions can be removed from the game"): the item info panel is gone. R155's ItemTooltip155 drew Tool.ToolTip (a
-- pack's odds, the pity lines, the Mech coat line, "Common | Click or tap the soil to plant!") on hover, for a picked item, for a just-held pack and for the gamepad's
-- selection. This test replaces test_tooltip155.luau. The REAL Hotbar + InventoryPanel155 + the real pity bars through R153's engine model (engine153 with this view's screen),
-- in VIEW = 'pc' (1280 x 720, a mouse), 'phone' (844 x 390, touch) or 'portrait' (390 x 844, touch), with the same items as before (a Mech pack and a world pack with the
-- server's long ToolTip, a seed with a one-line ToolTip, one with none) and the same moves. Nothing may show an item's description, anywhere, ever:
--  1. gone           - the ItemTooltip155 module is not in the game; InventoryPanel155 has no Hover / Leave / Focus / Unfocus / TipRefresh / Tip; the Bag's hint no longer
--                      promises "hover for info" / "hold for info" (and keeps the rest of it)
--  2. no forwarding  - the Hotbar does not call any of those on MouseEnter / MouseLeave / SelectionGained / SelectionLost of a slot or a Bag card (stubs put on the module
--                      record every call: none), and a hover / selection creates not one Instance
--  3. never created  - after every move below no Instance that was ever created is named like a tooltip or carries a description text (the odds, the lucky line, the coat
--                      line, the pity rule, a one-line ToolTip): hover (mouse), a picked item / Bag card (touch hold, x button, Y), a pack just held (touch, gamepad A, mouse),
--                      a pack whose odds arrive late, a ToolTip that changes, an item that goes, a drag
--  4. the rest works - the Bag's other behaviour is the same (picked: the green ring, the pick bar says what to do, tap puts it down; the count; Trash): test_inventory155
--  (control) the scanner does catch a panel that is named like one / shows the odds
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
VIEW=VIEW or'pc'
local PHONE=VIEW~='pc'
local SW,SH=VIEW=='pc'and 1280 or VIEW=='phone'and 844 or 390,VIEW=='pc'and 720 or VIEW=='phone'and 390 or 844
F.packAssets(W);W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder()
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class:find('Button')then o.MouseButton2Click=R.signal()end;return o end end
-- a TextService that wraps (the shared mock measures one line only)
W.service('TextService').GetTextSize=function(_,text,size,_,bounds)
 local per=math.max(1,math.floor(bounds.X/(size*.5)));local lines,widest=0,0
 for l in(text..'\n'):gmatch('(.-)\n')do lines+=math.max(1,math.ceil(#l/per));widest=math.max(widest,#l)end
 return R.Vector2.new(math.min(bounds.X,widest*size*.5),lines*size*1.15)
end
W.UIS.TouchEnabled=PHONE;W.UIS.MouseEnabled=not PHONE;W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(SW,SH)
E.player('Tester')
local player,pg=E.Player,E.pg
local X=require('./engine155p')(W,E,F,{Variant='began',Order='activated first',Handoff='empty',Screen=R.Vector2.new(SW,SH),Inset=PHONE and 0 or 58})
local hum=E.hum
local bag=function()return player:FindFirstChildOfClass('Backpack')end
local char=function()return player.Character end
print(('no-tooltip test: %s %dx%d'):format(VIEW,SW,SH))
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local layoutRemote=R.new('RemoteEvent');layoutRemote.Name='HotbarLayout155';layoutRemote.Parent=remotes;layoutRemote.FireServer=function()end
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog');local Inv=W.module('InventoryPanel155')
local Mech=W.module('MechCatalog');local Pity=W.module('PackPity155');local Odds=W.module('OddsText85')

-- 1. gone ------------------------------------------------------------------------------------------------------------------------------------------------
check(W.RS:FindFirstChild('ItemTooltip155')==nil and not pcall(W.module,'ItemTooltip155'),'the ItemTooltip155 module is not in the game')
for _,k in ipairs({'Hover','Leave','Focus','Unfocus','TipRefresh','Tip'})do check(Inv[k]==nil,'InventoryPanel155 has no '..k..' any more')end
-- 2. stubs that record any call the Hotbar (or the Bag) still makes under the old names (put on the module BEFORE the Hotbar loads)
local forwarded={}
for _,k in ipairs({'Hover','Leave','Focus','Unfocus','TipRefresh'})do Inv[k]=function()forwarded[#forwarded+1]=k end end

-- the text ChestService:_holdPack still writes into a pack's ToolTip: the label, the lucky line, the odds, (the Mech coat line), the rule
local function serverTip(label,lucky,seeds,coat)
 local rows={label};if lucky then rows[#rows+1]=Pity.LuckyLine end
 for _,s in ipairs(seeds)do rows[#rows+1]=s.Name..': '..Odds.Format(s.Chance)end
 if coat then rows[#rows+1]=Mech.CoatLine()end
 rows[#rows+1]=Pity.Disclosure
 return table.concat(rows,'\n')
end
local worldSeeds={};for i=1,14 do worldSeeds[i]={Name='Test Seed '..i,Chance=100/(i*7+3)}end
-- the items: the shovel, a seed with a short tooltip, a seed with none, a Mech pack and a world pack with the long server tooltip, then fruit to fill the hotbar
local ONE='Common | Click or tap the soil to plant! Controller: RT'
local shovel=F.shovel(W,bag());shovel.ToolTip='Remove a plant • Dig holes on the track to trap players'
local apple=F.seed(W,bag(),'AppleSeed',1,'None');apple.ToolTip=ONE
local plain=F.seed(W,bag(),'CloverSeed',1,'None')
local mech=F.pack(W,bag(),8,'MechLimited',1,'Gold','Gold Limited Mech Pack');mech.ToolTip=serverTip('Gold Limited Mech Pack',true,Mech.Seeds,true)
local world=F.pack(W,bag(),2,'Pack03',1,'None');world.ToolTip=serverTip(world.Name,false,worldSeeds,false)
local fruit={}
for k,s in ipairs({'BluebellSeed','MangoSeed','PlumSeed','OrangeSeed','LimeSeed'})do
 local t=F.fruit(W,nil,s,1,'None',700,1);t:SetAttribute('SourceCropId','plant-'..k);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0);t.Parent=bag();fruit[k]=t
end
-- two more in the Bag: a Mech pack (long tooltip) and a plain fruit
local bagMech=F.pack(W,bag(),8,'MechLimited',1,'Diamond','Diamond Limited Mech Pack');bagMech.ToolTip=serverTip('Diamond Limited Mech Pack',false,Mech.Seeds,true)
local bagPlain=F.fruit(W,nil,'KiwiSeed',1,'None',700,1);bagPlain:SetAttribute('SourceCropId','plant-kiwi');bagPlain:SetAttribute('FruitIndex',1);bagPlain:SetAttribute('HarvestCycle',0);bagPlain.Parent=bag()
local sc=R.new('LocalScript');sc.Name='Hotbar';local okLoad,errLoad=pcall(W.load,'Hotbar',sc);check(okLoad,'Hotbar loads: '..tostring(errLoad))
X.frames(30)
-- the real pity bars above the hotbar
local Bars=W.module('PityBars155').Start(player)
player:SetAttribute('PackPityNormal',4);player:SetAttribute('PackPityEvent',9);X.wait(2)
local gui,dock,panel,open
local function grab()gui=pg.ChestToolHotbar;dock=gui.Dock;panel=gui.Inventory;open=dock.OpenInventory end;grab()
local function slot(i)return dock['Slot'..i]end
local function slotOf(tool)local n=Names.Tool(tool,Catalog);for i=1,10 do local s=slot(i);if s.Visible and s.ItemName.Text==n then return s,i end end end
local function cards()local out={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then out[#out+1]=c end end;return out end
local function cardOf(tool)local n=Names.Tool(tool,Catalog);for _,c in ipairs(cards())do if (c.ItemName.Text:gsub('%s+',' ')):sub(1,#n)==n then return c end end end -- (a long name wraps on the card)
local kind=PHONE and'touch'or'mouse'
local function openBag()if not panel.Visible then X.tap(kind,open);X.frames(5)end end
local function closeBag()if panel.Visible then X.tap(kind,panel.Close);X.frames(5)end end
local function settle()hum:UnequipTools();X.wait(.5)end
local function holdRelease(b)local p=X.center(b);X.down('touch',p);X.wait(.55);X.up(p);X.frames(3)end

-- The scanner: every Instance that was ever created (R.created keeps the destroyed ones too) is tested. `offending` says why one is (part of) an item info panel: it is
-- named like a tooltip, or it carries a description text. (A plain table with _class / _props is enough for the control below.)
local TEXTS={Pity.LuckyLine,Pity.Disclosure,Mech.CoatLine(),ONE,'Test Seed 1','Plasma Pepper: 1/','Click / tap / RT 5 times to open'}
local function offending(o)
 local p=o._props;local name=tostring(p.Name or'')
 if name:lower():find('tooltip',1,true)or name:lower():find('infopanel',1,true)then return'is named '..name end
 local t=p.Text
 if type(t)=='string'and t~=''then for _,s in ipairs(TEXTS)do if t:find(s,1,true)then return'shows "'..s..'"' end end end
 return nil
end
local function scan(label)
 local bad
 for _,o in ipairs(R.created)do local why=offending(o);if why then bad=(bad or'')..tostring(o._props.Name)..' ('..o._class..') '..why..'; ' end end
 return check(bad==nil,label..': no item info panel exists or ever existed'..(bad and' - '..bad or''))
end
-- a move that must create nothing at all
local function createsNothing(label,fire)
 X.frames(2);local n=#R.created;fire();X.frames(3)
 check(#R.created==n,label..': not one Instance is created ('..(#R.created-n)..' new)')
 scan(label)
end

-- (control) the scanner does see a panel: one named like the old one, one that shows the odds, a clean one
do
 check(offending({_class='Frame',_props={Name='ItemTooltip'}})~=nil,'(control) a Frame named ItemTooltip is caught')
 check(offending({_class='TextLabel',_props={Name='Row3',Text=Mech.CoatLine()}})~=nil and offending({_class='TextLabel',_props={Name='Row1',Text=Pity.Disclosure}})~=nil,'(control) a label with the coat line / the pity rule is caught')
 check(offending({_class='TextLabel',_props={Name='Row1',Text=ONE}})~=nil,'(control) a label with a one-line ToolTip is caught')
 check(offending({_class='TextLabel',_props={Name='ItemName',Text='Apple Seed'}})==nil,'(control) an item name is not a description')
end
scan('the game as it starts')
-- sanity: the items are really there, with their ToolTips still written (the server keeps writing them)
check(slotOf(mech)~=nil and slotOf(world)~=nil and slotOf(plain)~=nil and slotOf(apple)~=nil,'(the items are on the hotbar)')
check(mech.ToolTip:find(Pity.Disclosure,1,true)~=nil and apple.ToolTip==ONE,'(the ToolTips are still on the tools: only the panel is gone)')

-- 1b. the Bag's hint: nothing about info, the rest stays ------------------------------------------------------------------------------------------------------
do
 openBag()
 local hint=panel:FindFirstChild('Hint')
 check(hint~=nil,'(the Bag has its hint)')
 if hint then
  local t=(hint.Text:gsub('%s+',' ')) -- (a narrow sheet wraps the hint with a line break)
  check(not t:lower():find('info',1,true)and not t:lower():find('hover',1,true),'the hint no longer promises "hover for info" / "hold for info" ("'..t..'")')
  if PHONE then check(t=='Tap to hold • hold to move or discard','the phone hint keeps "tap to hold" and "hold to move or discard" ("'..t..'")')
  else check(t=='Click to hold • drag to move • right-click for more','the PC hint keeps "click to hold", "drag to move" and "right-click for more" ("'..t..'")')end
 end
 closeBag()
end

-- 2/3. hover (mouse; a MouseEnter that comes with a finger too) ---------------------------------------------------------------------------------------------
do
 for _,t in ipairs({mech,world,apple,plain,shovel})do
  local b=slotOf(t)
  if b then
   createsNothing('hovering '..t.Name,function()b.MouseEnter:Fire()end)
   createsNothing('leaving '..t.Name,function()b.MouseLeave:Fire()end)
  end
 end
 do local empty;for n=1,10 do if slot(n).ItemName.Text==''then empty=slot(n)end end
  if empty then createsNothing('hovering an empty slot',function()empty.MouseEnter:Fire()end);empty.MouseLeave:Fire()end end
 -- the text changes under a hover
 local b=slotOf(mech);b.MouseEnter:Fire()
 createsNothing('the pack\'s ToolTip changing under the cursor',function()mech.ToolTip=serverTip('Gold Limited Mech Pack',false,Mech.Seeds,true)end)
 mech.ToolTip=serverTip('Gold Limited Mech Pack',true,Mech.Seeds,true);b.MouseLeave:Fire();X.frames(2)
 -- the Bag
 openBag()
 local card=cardOf(bagMech)
 check(card~=nil,'(a Mech pack in the Bag)')
 if card then
  createsNothing('hovering a Bag card',function()card.MouseEnter:Fire()end)
  createsNothing('leaving a Bag card',function()card.MouseLeave:Fire()end)
 end
 local c2=cardOf(bagPlain)
 if c2 then createsNothing('hovering a plain Bag card',function()c2.MouseEnter:Fire()end);c2.MouseLeave:Fire()end
 local sb=slotOf(mech);if sb then createsNothing('hovering a hotbar slot with the Bag open',function()sb.MouseEnter:Fire()end);sb.MouseLeave:Fire()end
 -- scrolling the Bag grid (the Hotbar used to tell the panel to follow a card)
 panel.Items.CanvasPosition=R.Vector2.new(0,40);X.frames(3);scan('scrolling the Bag grid') -- (the rows are recycled, so Instances may be made: only the scan applies)
 panel.Items.CanvasPosition=R.Vector2.new(0,0);X.frames(2)
 closeBag()
 -- a drag in progress
 if not PHONE then
  local s=slotOf(mech);s.MouseEnter:Fire();local p=X.center(s);X.down('mouse',p);for k=1,6 do X.move(R.Vector2.new(p.X+k*6,p.Y-k*6));X.frames(1)end
  scan('a drag in progress')
  local q=R.Vector2.new(640,200);X.move(q);X.up(q);X.frames(3);s.MouseLeave:Fire()
  check(slotOf(mech)==s,'(the drag was let go in the world: nothing moved)')
 end
 -- an item that goes
 local a=slotOf(apple);if a then a.MouseEnter:Fire();apple.Parent=nil;X.frames(5);scan('the hovered item going (used up)');apple.Parent=bag();X.frames(5);a.MouseLeave:Fire()end
 check(#forwarded==0,'hover: the Hotbar forwards nothing to the Bag panel ('..#forwarded..' calls: '..table.concat(forwarded,',')..')')
end

-- 3. gamepad selection ---------------------------------------------------------------------------------------------------------------------------------------
do
 settle();closeBag()
 local s=slotOf(mech)
 createsNothing('gamepad: the selection onto a slot',function()W.Gui.SelectedObject=s;s.SelectionGained:Fire()end)
 createsNothing('gamepad: the selection off it',function()s.SelectionLost:Fire();W.Gui.SelectedObject=nil end)
 openBag();panel.Search.Text='diamond';X.frames(3);local card=cardOf(bagMech)
 if card then
  createsNothing('gamepad: the selection onto a Bag card',function()W.Gui.SelectedObject=card;card.SelectionGained:Fire()end)
  -- Y picks the focused item: no description either
  W.actions.GardenBagPick('GardenBagPick',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonY});X.frames(2)
  check(Inv.Picked()~=nil and Inv.Picked().Key~=nil,'gamepad: Y still picks the focused card')
  scan('gamepad: Y picked a card')
  W.actions.GardenBagPick('GardenBagPick',R.Enum.UserInputState.Begin,{KeyCode=R.Enum.KeyCode.ButtonY});X.frames(2)
  check(Inv.Picked()==nil,'... and Y again puts it down')
  card.SelectionLost:Fire();W.Gui.SelectedObject=nil;X.frames(1)
 end
 panel.Search.Text='';X.frames(2);closeBag()
 check(#forwarded==0,'gamepad: the Hotbar forwards nothing to the Bag panel ('..#forwarded..' calls: '..table.concat(forwarded,',')..')')
end

-- 4. a picked item (tap-tap) -----------------------------------------------------------------------------------------------------------------------------------
do
 settle();closeBag()
 local w=R.Vector2.new(SW*.5,SH*.3);X.down('touch',w);X.up(w);X.frames(2)
 local s=slotOf(mech)
 holdRelease(s)
 check(Inv.Picked()~=nil and panel.Visible,'(a held mech pack is picked: the Bag opened)')
 scan('a picked pack (hold 0.4 s and let go)')
 -- the Bag's other behaviour is the same: the ring, the pick bar says what to do, the count
 check(s:FindFirstChild('PickedRing')~=nil and s.PickedRing.Visible,'the picked slot has its green ring')
 local pick=panel.BagBar.PickBar
 check(pick.Visible and pick.PickName.Text:find('Moving',1,true)~=nil and pick.PickName.Text:find('Gold Limited Mech Pack',1,true)~=nil,'the pick bar says what is moving ("'..tostring(pick.PickName.Text)..'")')
 check(panel.BagBar:FindFirstChild('HeldCount')~=nil and panel.BagBar.HeldCount.Text:find('/200',1,true)~=nil,'the count is on the Bag bar ('..tostring(panel.BagBar.HeldCount.Text)..')')
 X.wait(6);scan('... and 6 s later')
 X.tap('touch',s);X.frames(3);check(Inv.Picked()==nil,'put down (a tap on it again)')
 scan('put down')
 -- the x button
 holdRelease(slotOf(mech));check(Inv.Picked()~=nil,'(picked again)');X.tap('touch',panel.BagBar.PickBar.PickCancel);X.frames(3);check(Inv.Picked()==nil,'the x puts it down')
 -- an item without a tooltip, a one-line one
 holdRelease(slotOf(plain));check(Inv.Picked()~=nil,'(picked: a seed with no ToolTip)');X.tap('touch',slotOf(plain));X.frames(3)
 holdRelease(slotOf(apple));check(Inv.Picked()~=nil,'(picked: a seed with a one-line ToolTip)');scan('a picked seed with a one-line ToolTip');X.tap('touch',slotOf(apple));X.frames(3)
 -- a Bag card (the search leaves only it)
 openBag();panel.Search.Text='diamond';X.frames(3);local card=cardOf(bagMech)
 if card then
  holdRelease(card)
  check(Inv.Picked()~=nil,'(a picked Bag card)')
  scan('a picked Bag card')
  X.tap('touch',card);X.frames(3)
 end
 panel.Search.Text='';X.frames(2)
 closeBag();X.frames(3)
 check(#forwarded==0,'picking: the Bag panel was never asked for a description ('..#forwarded..' calls)')
end

-- 5. a pack that is just held (touch / gamepad / mouse) ------------------------------------------------------------------------------------------------------
do
 settle();closeBag()
 local pack=world;local s=slotOf(pack)
 -- (touch) the pack already has its odds: a tap on the slot holds it and nothing shows
 X.tap(kind,s);X.wait(.4)
 check(char():FindFirstChildOfClass('Tool')==pack,'(a tap on the pack\'s slot holds it)')
 scan('a pack just held with its odds already written')
 X.wait(5.3);scan('... and 5.3 s later (the old panel went by itself about then)')
 settle()
 -- a pack that has only the short line yet (the server writes the odds when it is held)
 local fresh=F.pack(W,bag(),3,'Pack02',1,'None');fresh.ToolTip='Snow Seed Pack • Click / tap / RT 5 times to open';X.frames(5)
 local fs=slotOf(fresh)
 if fs then
  X.tap(kind,fs);X.wait(.5)
  check(char():FindFirstChildOfClass('Tool')==fresh,'(the fresh pack is held)')
  scan('a pack with only its short line, just held')
  fresh.ToolTip=serverTip('Snow Seed Pack',false,worldSeeds,false);X.wait(.4)
  scan('... the odds arrive (the server writes them on the hold)')
  X.wait(5.5);scan('... and 5.5 s later')
 end
 settle();if fresh then fresh:Destroy()end;X.frames(3)
 -- a seed, not a pack
 local as=slotOf(apple);if as then X.tap(kind,as);X.wait(.5);scan('a seed just held');settle()end
 -- a pack held with the gamepad
 local lastInput=W.UIS.GetLastInputType;W.UIS.GetLastInputType=function()return R.Enum.UserInputType.Gamepad1 end
 local ws=slotOf(world);ws.Activated:Fire({UserInputType=R.Enum.UserInputType.Gamepad1,KeyCode=R.Enum.KeyCode.ButtonA});X.wait(.5)
 check(char():FindFirstChildOfClass('Tool')==world,'(gamepad: A on the pack\'s slot holds it)')
 scan('gamepad: a pack just held')
 X.wait(5.5);scan('... and 5.5 s later')
 W.UIS.GetLastInputType=lastInput;settle()
 -- a pack held with a finger (the phone's touch input type)
 local lastInput2=W.UIS.GetLastInputType;W.UIS.GetLastInputType=function()return R.Enum.UserInputType.Touch end
 X.tap('touch',slotOf(mech));X.wait(.5)
 scan('touch input: a Mech pack just held')
 X.wait(5.5);scan('... and 5.5 s later')
 W.UIS.GetLastInputType=lastInput2;settle()
 check(#forwarded==0,'holding: the Bag panel was never asked for a description ('..#forwarded..' calls)')
end

-- the end: still nothing, and the Bag still opens, searches and closes -------------------------------------------------------------------------------------------
do
 settle();openBag();check(panel.Visible,'(the Bag opens)');panel.Search.Text='diamond';X.frames(3);check(cardOf(bagMech)~=nil and cardOf(bagPlain)==nil,'(search still filters the Bag)');panel.Search.Text='';X.frames(2);closeBag()
 scan('at the end')
 local named=0;for _,o in ipairs(R.created)do if tostring(o._props.Name):lower():find('tooltip',1,true)then named+=1 end end
 check(named==0,'not one Instance named like a tooltip was created in the whole run ('..named..')')
 check(#forwarded==0,'nothing ever called Hover / Leave / Focus / Unfocus / TipRefresh on the Bag panel ('..#forwarded..')')
end
print(('R156 no-tooltip checks %d, fails %d (%s)'):format(checks,fails,VIEW))
if fails>0 then error('failures')end
