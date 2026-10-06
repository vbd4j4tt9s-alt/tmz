--!nocheck
-- R153 (owner, after R152: "players also cant seem to customise their hot bar so they cant drag seeds and reorganise their hotbar fix that, and hotbar also still
-- has issues where i need to put in inputs twice to equip something in the hotbar"). The REAL Hotbar (and the real HeldHarvests) driven through engine153.luau:
-- every event comes from a pointer at a screen point (hit test over every ScreenGui, MouseButton1Down / Up / Activated / InputBegan / UserInputService as the
-- engine gives them, in the variant and order the runner picks: globals VARIANT, ORDER, HANDOFF), and a server a round trip away holds packs only after their
-- shape is baked, sends refused packs back, hands the reward over after a reveal and rebuilds the tools after a respawn.
--  1. one input = one equip, for every kind (pack, seed, fruit, shovel, bat), tap / click / number key: a player who sees nothing in the hand after 0.5 s presses
--     again (as the owner did); the item must end up in the hand, shown.
--  2. drag to reorder on the hotbar (mouse, touch): onto an empty slot, onto a taken slot (swap); a drag never equips; a drag onto the shovel slot does nothing.
--  3. drag from the Bag onto the hotbar (mouse; touch straight out of the grid; touch with a 0.4 s hold inside the grid), and from the hotbar into the Bag.
--  4. the order holds: refreshes, a new item, a respawn (the server hands the tools back in another order), a held pack whose key changes (it gains a weather).
--  5. a pack pressed while another one is revealed / while knocked down is held when that is over; while carrying a stolen pack nothing flickers into the hand
--     (FINISH THAT FIRST!); an item chosen during a reveal stays in the hand after it (the server's hand-off).
--  6. a Bag card the grid re-sorts under the pointer (an item before it used up) still equips ITS item; ScreenGui stacking: an Active backdrop above a slot takes
--     the press (nothing happens), a label above one lets it through (one equip).
--  7. the debug aid: /test hotbar's HotbarLog shows the presses, what they did and what the server moved back.
local W=require('./world');local F=require('./fixtures');local E=require('./sfx_env')(W);local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
F.packAssets(W)
W.Run.IsStudio=function()return true end
local Meshes=W.module('ApprovedPlantMeshes');local meshCache={}
Meshes.Get=function(key)local p=meshCache[key];if not p then p=R.new('MeshPart');p.Name=key;p.Size=R.Vector3.new(1,1,1);meshCache[key]=p end;return p end
Meshes.Status=function()return'Ready'end
E.recorder()
E.player('Tester')
local player,pg=E.Player,E.pg
local X=require('./engine153')(W,E,F,{Variant=VARIANT or'began',Order=ORDER or'activated first',Handoff=HANDOFF or'empty'})
local hum=E.hum;local acts=0
local function wrap(h)
 local eq,un=h.EquipTool,h.UnequipTools
 h.EquipTool=function(self,tool)acts+=1;return eq(self,tool)end
 h.UnequipTools=function(self)acts+=1;return un(self)end
end
wrap(hum);X.onHumanoid=function(h)hum=h;wrap(h)end
local bag=function()return player:FindFirstChildOfClass('Backpack')end
local char=function()return player.Character end
print(('engine: %s, %s, hand-off %s'):format(X.Variant,X.Order,X.S.Handoff))
-- the items: the shovel, a seed, a fruit, the bat, two packs
local shovel=F.shovel(W,bag())
local function harvest(seed,crop)local t=F.fruit(W,nil,seed,1,'None',700,1);t:SetAttribute('SourceCropId',crop);t:SetAttribute('FruitIndex',1);t:SetAttribute('HarvestCycle',0);return t end
local seed=F.seed(W,bag(),'AppleSeed',1,'None');local fruit=harvest('BluebellSeed','plant-1');fruit.Parent=bag()
local bat=F.bat(W,bag());local packA=F.pack(W,bag(),2,'Pack06',1,'None');local packB=F.pack(W,bag(),3,'Pack02',1,'None')
local sc=R.new('LocalScript');sc.Name='Hotbar';local ok,err=pcall(W.load,'Hotbar',sc);check(ok,'Hotbar loads: '..tostring(err))
do local hs=R.new('LocalScript');hs.Name='HeldHarvests';local okH,errH=pcall(W.load,'HeldHarvests',hs);if not okH then print('NOTE HeldHarvests not runnable here: '..tostring(errH))else X.RealFruit=true end end
X.frames(30)
if DEBUGLOG then player:SetAttribute('HotbarLog',true)end
local Names=W.module('GardenDisplayNames');local Catalog=W.module('PlantCatalog')
local gui=pg.ChestToolHotbar;local dock=gui.Dock;local panel=gui.Inventory;local open=dock.OpenInventory
local function slotOf(tool)local n=Names.Tool(tool,Catalog);for i=1,10 do local s=dock['Slot'..i];if s.Visible and s.ItemName.Text==n then return s,i end end end
local function slot(i)return i and dock['Slot'..i]or nil end
local function at(tool)local _,i=slotOf(tool);return i end
local function held()return char():FindFirstChildOfClass('Tool')end
local function settle()hum:UnequipTools();X.wait(1);acts=0 end
local NUM={'One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Zero'}
local function key(i)W.UIS.InputBegan:Fire({KeyCode=R.Enum.KeyCode[NUM[i]],UserInputType=R.Enum.UserInputType.Keyboard,Position=R.Vector3.new(0,0,0)},false)X.frames(1)end
-- the owner's way: one press; nothing in the hand after 0.5 s? press again. Then wait for the server.
local function impatient(tool,how)
 local s,i=slotOf(tool);if not s then return false,0 end
 local presses=0
 local function go()presses+=1;if how=='key'then key(i)else X.tap(how,s)end end
 go();X.wait(.5);if not X.shown(tool)then go()end
 X.wait(3);return X.shown(tool),presses
end

-- 1. one input = one equip, every kind ------------------------------------------------------------------------------------------------------------------
for _,how in ipairs({'mouse','touch','key'})do
 for _,item in ipairs({{'seed',seed},{'fruit',fruit},{'shovel',shovel},{'bat',bat},{'pack',packA},{'pack',packB}})do
  settle();X.S.Baked={} -- (each pack's shape is not baked yet: its first hold waits 1.5 s on the server)
  local shown,presses=impatient(item[2],how)
  check(shown,('%s %s: one press puts it in the hand (%d press(es), in hand: %s)'):format(how,item[1],presses,tostring(held()and held().Name)))
 end
end
-- (how long a fruit takes to show in the hand after the click: the real HeldHarvests builds it; R152: a scan every 0.25 s, then 16 parts a frame)
if X.RealFruit then
 local worst=0
 for k=0,7 do -- (clicks at every phase of HeldHarvests' scan)
  settle();X.frames(k*2);X.tap('mouse',slotOf(fruit));local f=2;while not X.shown(fruit)and f<180 do X.frames(1);f+=1 end;worst=math.max(worst,f/60)
 end
 print(('the fruit is in the hand at most %.2f s after the click (8 clicks)'):format(worst))
 check(worst<=.15,('the fruit shows in the hand within 0.15 s of any click (worst %.2f s)'):format(worst))
end
-- (and a plain press of each, nobody pressing twice: exactly one equip call each)
for _,item in ipairs({seed,fruit,shovel,bat,packA})do
 settle();X.S.Baked={};local s=slotOf(item);X.tap('mouse',s);X.wait(3)
 check(acts==1 and X.shown(item),('a single click on %s: one equip call (%d), in the hand'):format(item.Name,acts))
end

-- 2. drag to reorder -------------------------------------------------------------------------------------------------------------------------------------
local function names()local out={};for i=1,10 do out[i]=slot(i).ItemName.Text end;return out end
for _,how in ipairs({'mouse','touch'})do
 settle()
 local from,fi=slotOf(seed);local empty;for i=10,2,-1 do if slot(i).ItemName.Text==''then empty=i;break end end
 X.drag(how,from,slot(empty))
 local _,now=slotOf(seed)
 check(now==empty and acts==0 and held()==nil,('%s drag: the seed moved from slot %s to the empty slot %s (now %s), nothing equipped (%d)'):format(how,tostring(fi),tostring(empty),tostring(now),acts))
 local fs,fj=slotOf(fruit);X.drag(how,slotOf(seed),fs)
 local _,s2=slotOf(seed);local _,f2=slotOf(fruit)
 check(s2==fj and f2==empty and acts==0,('%s drag onto a taken slot swaps them (seed %s, fruit %s)'):format(how,tostring(s2),tostring(f2)))
 X.drag(how,slotOf(seed),slot(fi));X.drag(how,slotOf(fruit),slot(fj)) -- back
 local before=names();X.drag(how,slotOf(fruit),slot(1))
 check(table.concat(names(),'|')==table.concat(before,'|')and acts==0,how..' drag onto the shovel slot changes nothing')
end
-- a quick flick (press, release on another slot, no move reported) moves too; a drag that comes back to its own slot is a click (R152)
settle();do local s,i=slotOf(bat);local t=slot(9);X.down('mouse',X.center(s));X.up(X.center(t));X.frames(2)
 check(at(bat)==9 and acts==0,'a flick onto slot 9 moves the bat ('..tostring(at(bat))..')');X.drag('mouse',slotOf(bat),slot(i))end

-- 3. the Bag and the hotbar ------------------------------------------------------------------------------------------------------------------------------
-- more stacks than slots: some live only in the Bag
local extra={};for k,s in ipairs({'CloverSeed','MangoSeed','PlumSeed','OrangeSeed','PeachSeed','LimeSeed'})do extra[k]=harvest(s,'plant-x'..k);extra[k].Parent=bag()end
X.frames(10)
local function bagOnly()for _,t in ipairs(extra)do if not slotOf(t)then return t end end end
local function cardOf(tool)local n=Names.Tool(tool,Catalog);for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible and c.ItemName.Text:sub(1,#n)==n then return c end end end
local function openBag()if not panel.Visible then X.tap('mouse',open);X.frames(10)end end
for _,mode in ipairs({'mouse','touch out','touch hold'})do
 settle();openBag()
 local t=bagOnly();local card=t and cardOf(t)
 check(t~=nil and card~=nil,mode..': (an item that is only in the Bag, and its card)')
 if card then
  local target=slot(5)
  if mode=='mouse'then X.drag('mouse',card,target)
  elseif mode=='touch out'then X.drag('touch',card,target)
  else -- hold 0.4 s, then a path that first runs down inside the grid
   local a=X.center(card);X.down('touch',a);X.wait(.5);X.move(R.Vector2.new(a.X,a.Y+40));X.frames(1);X.move(R.Vector2.new(a.X+10,a.Y+90));X.frames(1)
   local b=X.center(target);X.move(b);X.frames(1);X.up(b);X.frames(2)
  end
  check(at(t)==5 and acts==0,('%s: a Bag card dragged onto slot 5 lands there (slot %s), not equipped (%d)'):format(mode,tostring(at(t)),acts))
 end
end
-- from the hotbar into the Bag: dropped on the Bag's sheet (open) or on its button (closed); it stays off the hotbar until placed again
settle();openBag()
do local s,i=slotOf(fruit);X.drag('mouse',s,panel.Items);X.frames(5)
 check(slotOf(fruit)==nil,'a slot dragged onto the open Bag leaves the hotbar (was slot '..tostring(i)..')')
 X.tap('mouse',panel.Close);X.frames(5)
 local s2=slotOf(seed);X.drag('touch',s2,open);X.frames(5)
 check(slotOf(seed)==nil,'a slot dragged onto the Bag button leaves the hotbar')
 local filler=bagOnly();X.frames(30)
 check(slotOf(fruit)==nil and slotOf(seed)==nil,'and they stay off it across refreshes (the free slots fill with Bag items instead: '..tostring(filler and at(filler))..')')
 openBag();X.drag('mouse',cardOf(seed),slot(3));openBag();X.drag('mouse',cardOf(fruit),slot(4))
 check(at(seed)==3 and at(fruit)==4,'dragged back from the Bag, they are on the hotbar again')
 if panel.Visible then X.tap('mouse',panel.Close);X.frames(5)end
end
for k=6,4,-1 do extra[k]:Destroy();extra[k]=nil end;X.frames(10) -- (back to fewer stacks than slots: everything is on the hotbar again)
check(slotOf(packA)and slotOf(packB)and slotOf(bat)and slotOf(seed)and slotOf(fruit),'(every item is on the hotbar again)')

-- 4. the order holds -------------------------------------------------------------------------------------------------------------------------------------
settle()
X.drag('mouse',slotOf(bat),slot(8));X.drag('touch',slotOf(packA),slot(2))
local custom=names();X.frames(60)
check(table.concat(names(),'|')==table.concat(custom,'|'),'the custom order holds across refreshes')
local late=harvest('FigSeed','plant-late');late.Parent=bag();X.frames(10)
local same=true;for i=1,10 do if custom[i]~=''and names()[i]~=custom[i]then same=false end end
check(same,'a new item does not move anything')
late:Destroy();X.frames(5)
do -- a respawn: the server hands everything back, in reverse order, as new instances
 local list={};for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')then list[#list+1]=t end end
 local before=names()
 local spec={};for _,t in ipairs(list)do spec[#spec+1]={Kind=t:GetAttribute('GardenShovel')and'shovel'or t:GetAttribute('ChestChaseBat')and'bat'or t:GetAttribute('SeedPackTool')and'pack'or t:GetAttribute('GardenSeed')and'seed'or'fruit',Tool=t}end
 local fresh={}
 X.respawn(function(nb)
  for k=#spec,1,-1 do local s=spec[k];local t=s.Tool;local n
   if s.Kind=='shovel'then n=F.shovel(W,nb)elseif s.Kind=='bat'then n=F.bat(W,nb)
   elseif s.Kind=='pack'then n=F.pack(W,nb,t:GetAttribute('Stage'),t:GetAttribute('BagVariant'),1,'None')
   elseif s.Kind=='seed'then n=F.seed(W,nb,t:GetAttribute('SeedId'),1,'None')
   else n=harvest(t:GetAttribute('SeedId'),t:GetAttribute('SourceCropId'));n.Parent=nb end
   fresh[t]=n
  end
 end,function()shovel:SetAttribute('Weather','None');X.frames(5)end) -- (a refresh between CharacterRemoving and the new Backpack)
 X.frames(10)
 local after=names();local moved={}
 for i=1,10 do if before[i]~=after[i]then moved[#moved+1]=('%d: %s -> %s'):format(i,before[i],after[i])end end
 check(#moved==0,'after a respawn every item is back on its own slot ('..table.concat(moved,'; ')..')')
 seed,fruit,bat,packA,packB,shovel=fresh[seed]or seed,fresh[fruit]or fruit,fresh[bat]or bat,fresh[packA]or packA,fresh[packB]or packB,fresh[shovel]or shovel
 for k,t in ipairs(extra)do extra[k]=fresh[t]or t end
end
do -- a held pack gains a weather (its key changes): it keeps its slot
 settle();local s,i=slotOf(packA);X.tap('mouse',s);X.wait(3)
 packA:SetAttribute('Weather','Rain');X.frames(5)
 check(at(packA)==i,'a held pack that gains a weather keeps its slot ('..tostring(i)..' -> '..tostring(at(packA))..')')
end

-- 5. the server's own moves ---------------------------------------------------------------------------------------------------------------------------
do -- a pack pressed during another pack's reveal is held when it is over
 settle();X.S.Baked={};X.tap('mouse',slotOf(packA));X.wait(3)
 check(X.shown(packA),'(pack A is held)')
 local n=0;X.reveal(2,function()n+=1;return F.seed(W,nil,'CloverSeed',1,'None','Reward Seed '..n)end)
 X.wait(.3);X.tap('mouse',slotOf(packB));X.wait(.5)
 if not X.shown(packB)and at(packB)then X.tap('mouse',slotOf(packB))end -- (the owner presses again)
 X.wait(4.5)
 check(X.shown(packB),'a pack pressed while another is being revealed is in the hand once the reveal is over (in hand: '..tostring(held()and held().Name)..')')
 packA=nil
end
do -- an item chosen during a reveal stays in the hand after it
 settle();X.S.Baked={};X.tap('mouse',slotOf(packB));X.wait(3)
 check(X.shown(packB),'(pack B is held)')
 X.reveal(2,function()return F.seed(W,nil,'MangoSeed',1,'None','Reward Seed X')end)
 X.wait(.3);local f=extra[1];X.tap('mouse',slotOf(f)or slotOf(fruit));X.wait(4)
 check(held()==f or held()==fruit,'an item picked during the reveal is still in the hand after it (in hand: '..tostring(held()and held().Name)..')')
 packB=nil
end
do -- carrying a stolen pack: a pack press says so and nothing flickers into the hand
 local p=F.pack(W,bag(),4,'Pack03',1,'None','Lava Seed Pack');X.frames(10);settle()
 player:SetAttribute('ChestChaseSeedCarrying',true)
 local before=X.S.Refused;X.tap('mouse',slotOf(p));X.wait(1)
 check(acts==0 and X.S.Refused==before and held()==nil,'while carrying a stolen pack, a pack press sends nothing (no flicker, no refusal: '..acts..' calls, '..(X.S.Refused-before)..' refused)')
 player:SetAttribute('ChestChaseSeedCarrying',nil)
 X.S.Baked={};local shown=impatient(p,'mouse');check(shown,'after the chase the same press holds it')
 do -- knocked down: the press waits, the pack is held when the player is up again
  settle();player:SetAttribute('GuardianRagdollActive',true)
  X.tap('mouse',slotOf(seed));X.wait(1)
  player:SetAttribute('GuardianRagdollActive',nil);X.wait(1.5)
  check(X.shown(seed),'a press while knocked down holds the item once the player is up ('..tostring(held()and held().Name)..')')
 end
end

-- 6. buttons that change under the pointer; ScreenGui stacking --------------------------------------------------------------------------------------
do -- the Bag grid re-sorts between the press and the release (an item before the card is used up)
 settle();openBag()
 local cards={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then cards[#cards+1]=c end end
 table.sort(cards,function(a,b)if a.AbsolutePosition.Y~=b.AbsolutePosition.Y then return a.AbsolutePosition.Y<b.AbsolutePosition.Y end;return a.AbsolutePosition.X<b.AbsolutePosition.X end)
 local function toolOf(c)for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')and not t:GetAttribute('GardenShovel')and c.ItemName.Text:sub(1,#Names.Tool(t,Catalog))==Names.Tool(t,Catalog)then return t end end end
 local k=1;while cards[k]and not toolOf(cards[k])do k+=1 end
 local first=cards[k]and toolOf(cards[k]);local pressed=cards[k+2];local wantName=pressed and pressed.ItemName.Text
 if pressed and first then
  local p=X.center(pressed);X.down('mouse',p);X.frames(1)
  first:Destroy();X.frames(3) -- (the server took the first item away: the grid re-sorts while the button is held)
  X.up(p);X.frames(3)
  local h=held();local hn=h and Names.Tool(h,Catalog)
  check(acts==1 and hn~=nil and wantName:sub(1,#hn)==hn,('a card pressed while the grid re-sorts equips ITS item, once (%d calls, wanted %s, got %s)'):format(acts,tostring(wantName),tostring(hn)))
 else check(false,'(three cards and a first item to remove)')end
 if panel.Visible then X.tap('mouse',panel.Close);X.frames(5)end
end
do -- an Active backdrop above a slot takes the press; a plain label above a slot lets it through
 settle()
 local top=R.Instance.new('ScreenGui');top.Name='Overlay';top.DisplayOrder=40;top.Parent=pg
 local s3=slotOf(seed);local s4=slotOf(bat)
 if not(s3 and s4)then check(false,'(the seed and the bat are on the hotbar)');s3=s3 or slot(3);s4=s4 or slot(4)end
 local back=R.Instance.new('Frame');back.Name='Backdrop';back.Active=true;back.BackgroundTransparency=1;back.Size=R.UDim2.fromOffset(s3.AbsoluteSize.X+4,s3.AbsoluteSize.Y+4);back.Position=R.UDim2.fromOffset(s3.AbsolutePosition.X-2,s3.AbsolutePosition.Y-2);back.Parent=top
 local tag=R.Instance.new('TextLabel');tag.Name='Toast';tag.BackgroundTransparency=1;tag.Size=R.UDim2.fromOffset(s4.AbsoluteSize.X,s4.AbsoluteSize.Y);tag.Position=R.UDim2.fromOffset(s4.AbsolutePosition.X,s4.AbsolutePosition.Y);tag.Parent=top
 X.frames(2);X.tap('mouse',s3);X.wait(.5)
 check(acts==0 and held()==nil,'a press on a slot under an Active backdrop of another ScreenGui does nothing ('..acts..')')
 X.tap('touch',s4);X.wait(.5)
 check(acts==1 and held()==bat,'a press through a non-Active label of another ScreenGui equips once ('..acts..')')
 top:Destroy();X.frames(2)
end

-- 7. the debug aid ------------------------------------------------------------------------------------------------------------------------------------
do
 for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')and(t.Name:find('Reward Seed',1,true)or t.Name=='Lava Seed Pack')then t:Destroy()end end;X.frames(5) -- (room on the hotbar)
 settle();player:SetAttribute('HotbarLog',true);X.frames(3)
 local box=gui:FindFirstChild('HotbarLog')
 check(box~=nil and box.Visible,'/test hotbar (HotbarLog) shows the log box')
 local p=F.pack(W,bag(),5,'Pack04',1,'None','Crystal Seed Pack');X.frames(10);X.S.Revealing=true -- (the server will refuse it: a reveal it knows of)
 X.tap('mouse',slotOf(seed));X.wait(.5);X.tap('mouse',slotOf(p));X.wait(.5);X.S.Revealing=false
 local text=box and box.Lines.Text or''
 check(text:find('press slot',1,true)~=nil and text:find('equip',1,true)~=nil,'the log has the press and what it did')
 check(text:find('not by the hotbar',1,true)~=nil and text:find('opening',1,true)~=nil,'the log has the server sending the pack back, with its reason and timing')
 player:SetAttribute('HotbarLog',false);X.frames(2);check(box and not box.Visible,'and /test hotbar again hides it')
end

-- 8. a seeded random run on top: taps, drags, flicks, phone holds, keys, the Bag, in every mix; nothing may get stuck: every 8 steps a probe click on an item
--    that is not a pack must equip it with exactly one call, and the hotbar never shows one item twice ---------------------------------------------------
do
 player:SetAttribute('HotbarLog',nil)
 local st=SEED or 153;local function rnd(n)st=(st*16807)%2147483647;return st%n+1 end
 local function filled()local c={};for i=1,10 do if slot(i).ItemName.Text~=''then c[#c+1]=i end end;return c end
 local stuck,dup=0,0
 for step=1,STEPS or 160 do
  local f=filled();local i=f[rnd(#f)];local how=rnd(2)==1 and'mouse'or'touch';local r=rnd(10)
  if r<=3 then X.tap(how,slot(i),rnd(21)-11,rnd(21)-11)
  elseif r<=5 then X.drag(how,slot(i),slot(rnd(10)))
  elseif r==6 then key(rnd(10))
  elseif r==7 then X.down('mouse',X.center(slot(i)));X.up(X.center(slot(rnd(10))));X.frames(2)
  elseif r==8 then X.down('touch',X.center(slot(i)));X.wait(.5);X.up(X.center(slot(i),3,-2));X.frames(2)
  elseif r==9 then openBag();local cards={};for _,c in ipairs(panel.Items:GetChildren())do if c.Name=='Item'and c.Visible then cards[#cards+1]=c end end
   if #cards>0 then if rnd(2)==1 then X.tap(how,cards[rnd(#cards)])else X.drag(how,cards[rnd(#cards)],slot(rnd(9)+1))end end
   if panel.Visible then X.tap('mouse',panel.Close);X.frames(3)end
  else X.wait(.3)end
  local seen={};for _,n in ipairs(names())do if n~=''then if seen[n]then dup+=1 end;seen[n]=true end end
  if step%8==0 then
   if panel.Visible then X.tap('mouse',panel.Close);X.frames(3)end
   settle();local pick;for _,k in ipairs(filled())do local s=slot(k);local name=s.ItemName.Text
    for _,t in ipairs(bag():GetChildren())do if t:IsA('Tool')and not t:GetAttribute('SeedPackTool')and Names.Tool(t,Catalog)==name then pick={k,t}end end end
   if pick then X.tap(how,slot(pick[1]));X.wait(.4);if not(acts==1 and held()and Names.Tool(held(),Catalog)==Names.Tool(pick[2],Catalog))then stuck+=1;print(('probe at step %d: %d calls, in hand %s'):format(step,acts,tostring(held()and held().Name)))end end
  end
 end
 check(stuck==0,('random run: every probe click equips with one call (%d failed)'):format(stuck))
 check(dup==0,('random run: no item is ever on two slots (%d times)'):format(dup))
end

print(('R153 hotbar real-engine checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
