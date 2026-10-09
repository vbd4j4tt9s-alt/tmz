--!nocheck
-- R155: the hotbar layout model on its own (GardenInventoryState, the rules every press and every new item follow). The owner: "just make it function like the
-- normal inventory ... i can have a blank hot bar if i put everything in my bag".
--  1. new items: a stack joins its stack (on the hotbar or in the Bag); else the first FREE shown slot; else the Bag; never pushing an item off the hotbar.
--  2. nothing moves by itself: a slot freed by an item used up stays free; a Bag item never jumps onto it (R153 refilled it from the Bag).
--  3. blank slots: an item put in the Bag leaves its slot BLANK: new items skip it until the player puts something there; a fully blank hotbar holds.
--  4. Place: onto an empty slot (from a slot or the Bag); onto a taken slot = swap from a slot, the occupant to the Bag from the Bag; the shovel too.
--  5. respawn (Remember): every item back on its slot / in the Bag even when the server hands them back in another order with new instances; a new item meanwhile
--     does not take a slot that is waiting for its item.
--  6. rejoin: Serialize / Parse / Restore round trip; items arriving after join go back to their saved slots, everything else to the Bag; blank slots stay blank;
--     a saved slot whose item never comes frees up when the join ends (GoLive); a malformed string is refused.
--  7. a phone (5 shown slots): items on slots 6-10 are Bag items there; new items only take shown slots; Target (seed collect) agrees with where it lands.
--  8. random: 3000 random operations never put one key on two slots, never assign a slot to a missing item outside a respawn, and blank slots never fill by themselves.
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local S=W.module('GardenInventoryState');local Stacks=W.module('InventoryStacks155')
local now=0;local function clock()return now end
local order=0
local function item(key)order+=1;return {Tool={Name=key},Order=order,Count=1}end
local function set(keys)local t={};for _,k in ipairs(keys)do t[k]=item(k)end;return t end
local function with(items,...)local t=table.clone(items);for _,k in ipairs({...})do t[k]=item(k)end;return t end
local function without(items,...)local t=table.clone(items);for _,k in ipairs({...})do t[k]=nil end;return t end
local function slots(st)local out={};for i=1,10 do out[i]=st.Slots[i]or(st.Blank[i]and'#'or'.')end;return table.concat(out,' ')end
local function live(st)st:GoLive();return st end

-- 1. new items -----------------------------------------------------------------------------------------------------------------------------------------
do
 local st=live(S.new(clock));local items=set({'shovel','a','b','c'});items.shovel.Order=-1
 st:Reconcile(items)
 check(slots(st)=='shovel a b c . . . . . .','a fresh hotbar fills in arrival order, the shovel first ('..slots(st)..')')
 items=with(items,'d');st:Reconcile(items)
 check(st:SlotOf('d')==5,'a new item takes the first free slot ('..slots(st)..')')
 items.d.Count=2;st:Reconcile(items)
 check(st:SlotOf('d')==5,'another of the same stack joins it where it is')
 for k=1,6 do items=with(items,'n'..k)end;st:Reconcile(items)
 check(st:SlotOf('n5')==10 and st:SlotOf('n6')==nil and st:InBag('n6'),'once the hotbar is full a new item goes to the Bag ('..slots(st)..')')
 local before=slots(st);items=with(items,'n7');st:Reconcile(items)
 check(slots(st)==before and st:InBag('n7'),'... and never pushes anything off the hotbar')
 -- a stack in the Bag gets more: it stays in the Bag
 items.n6.Count=3;st:Reconcile(items);check(st:InBag('n6')and slots(st)==before,'a stack in the Bag that gains more stays in the Bag')
end
-- 2. nothing moves by itself ----------------------------------------------------------------------------------------------------------------------------
do
 local st=live(S.new(clock));local items={}
 for k=1,12 do items['k'..k]=item('k'..k)end;st:Reconcile(items)
 local bagged={};for k=1,12 do if st:InBag('k'..k)then bagged[#bagged+1]='k'..k end end
 check(#bagged==2,'(12 stacks: 10 on the hotbar, 2 in the Bag)')
 items=without(items,'k3');st:Reconcile(items)
 check(st.Slots[3]==nil and not st.Blank[3],'an item used up frees its slot ('..slots(st)..')')
 check(st:InBag(bagged[1])and st:InBag(bagged[2]),'and no Bag item jumps onto it (R153: "slots refilling by themselves")')
 for _=1,5 do st:Reconcile(items)end;check(st.Slots[3]==nil,'... across any number of refreshes')
 items=with(items,'fresh');st:Reconcile(items);check(st:SlotOf('fresh')==3,'the next NEW item takes it')
end
-- 3. blank slots ---------------------------------------------------------------------------------------------------------------------------------------
do
 local st=live(S.new(clock));local items=set({'shovel','a','b','c','d'});items.shovel.Order=-1;st:Reconcile(items)
 check(st:Stow('b')and st.Blank[3]and st:InBag('b'),'an item put in the Bag leaves its slot blank ('..slots(st)..')')
 items=with(items,'e');st:Reconcile(items)
 check(st:SlotOf('e')==6,'a new item skips the blank slot (takes 6, not 3: '..slots(st)..')')
 check(st:Place('e',3)and st.Slots[3]=='e'and not st.Blank[3]and st.Slots[6]==nil and not st.Blank[6],'putting something on a blank slot clears it; the slot it came from is just free')
 for _,k in ipairs({'shovel','a','c','d'})do st:Stow(k)end
 check(st.Slots[3]=='e'and st:FirstFree()==6,'with one item left on it, slots never emptied by the player still take new items (first free: '..tostring(st:FirstFree())..')')
 st:Stow('e')
 local blank=true;for i=1,10 do if st.Slots[i]or not st.Blank[i]then blank=false end end
 check(blank,'the last item put in the Bag: every slot is blank, a fully blank hotbar ('..slots(st)..')')
 items=with(items,'f','g');for _=1,3 do st:Reconcile(items)end
 check(st:InBag('f')and st:InBag('g')and st:FirstFree()==nil,'new items on a fully blank hotbar go to the Bag ('..slots(st)..')')
 check(st:Place('f',4)and st.Slots[4]=='f'and not st.Blank[4],'the player puts one item back: that slot is not blank any more')
 items=with(items,'h');st:Reconcile(items);check(st:InBag('h'),'the other slots stay blank: the next new item still goes to the Bag')
 items=without(items,'f');st:Reconcile(items);check(st.Slots[4]==nil and not st.Blank[4],'that item used up: its slot is free (not blank)')
 items=with(items,'i');st:Reconcile(items);check(st:SlotOf('i')==4,'and the next new item takes it')
end
-- 4. Place -------------------------------------------------------------------------------------------------------------------------------------------
do
 local st=live(S.new(clock));local items=set({'shovel','a','b','c'});items.shovel.Order=-1
 for k=1,8 do items['z'..k]=item('z'..k)end;st:Reconcile(items) -- (2 in the Bag)
 check(st:Place('a',2)==false,'placing on its own slot changes nothing')
 check(st:Place('a',4)and st.Slots[4]=='a'and st.Slots[2]=='c','slot to taken slot: they swap ('..slots(st)..')')
 local bagItem;for k=1,8 do if st:InBag('z'..k)then bagItem='z'..k;break end end
 local occupant=st.Slots[5]
 check(st:Place(bagItem,5)and st.Slots[5]==bagItem and st:InBag(occupant),'Bag to a taken slot: the item that was there goes to the Bag ('..tostring(occupant)..')')
 check(st:Place('shovel',9)and st.Slots[9]=='shovel'and st.Slots[1]~='shovel','the shovel moves like any item (R153 kept slot 1)')
 check(st:Place(st.Slots[2],1),'and any item can take slot 1')
 local seen,dup={},false;for i=1,10 do local k=st.Slots[i];if k then if seen[k]then dup=true end;seen[k]=true end end
 check(not dup,'never one key on two slots')
 check(st:Place('nothing',3)==false and st:Place('a',0)==false and st:Place('a',11)==false,'unknown keys and slots out of range are refused')
end
-- 5. respawn -------------------------------------------------------------------------------------------------------------------------------------------
do
 now=100;local st=live(S.new(clock));local items=set({'shovel','a','b','c','d'});items.shovel.Order=-1;st:Reconcile(items)
 for k=1,8 do items['y'..k]=item('y'..k)end;st:Reconcile(items)
 st:Place('d',8);st:Stow('a') -- a custom layout with a blank slot
 local before=slots(st);local bag={};for k in pairs(items)do if st:InBag(k)then bag[#bag+1]=k end end
 st:Remember();st:Reconcile({}) -- (the Backpack is gone)
 now+=.3;local back={};local keys={};for k in pairs(items)do keys[#keys+1]=k end;table.sort(keys,function(x,y)return x>y end) -- (handed back in another order)
 for i,k in ipairs(keys)do back[k]=item(k);if i==3 then items2=table.clone(back);st:Reconcile(items2)end end -- (part of them first)
 local extra=with(back,'brandnew');st:Reconcile(extra)
 check(slots(st):gsub(' brandnew',' .')~=nil,'(respawn)')
 local same=true;for i=1,10 do local want=before:split(' ')[i];local got=st.Slots[i]or(st.Blank[i]and'#'or'.');if want~=got and not(got=='brandnew'and want=='.')then same=false end end
 check(same,'after a respawn every item is back on its slot, blanks blank ('..before..' -> '..slots(st)..')')
 local ok=true;for _,k in ipairs(bag)do if not st:InBag(k)then ok=false end end
 check(ok,'... and every Bag item is back in the Bag ('..#bag..')')
 check(st:SlotOf('brandnew')~=nil and st.Blank[st:SlotOf('brandnew')]==nil,'a new item meanwhile takes a free slot, never a blank one or one waiting for its item')
 -- an item that came back and is then used up (still inside the window) frees its slot at once: its memory was used by the return
 local victim=st.Slots[3];local gone=without(extra,victim);now+=1;st:Reconcile(gone)
 check(victim and st.Slots[3]==nil and st:FirstFree()==3,'an item used up right after it came back frees its slot at once (no slot kept for a phantom: '..slots(st)..')')
 extra=gone
 now+=20;st:Reconcile(without(extra,'y1'))
 check(not st:SlotOf('y1'),'after the window an item still gone frees its slot')
end
-- 6. rejoin ---------------------------------------------------------------------------------------------------------------------------------------------
do
 now=500;local st=live(S.new(clock));local items=set({'shovel','a','b','c','d','e'});items.shovel.Order=-1;st:Reconcile(items)
 for k=1,9 do items['w'..k]=item('w'..k)end;st:Reconcile(items)
 st:Place('e',2);st:Stow('c');st:Place('w9',7);st:Stow('shovel')
 local text=st:Serialize();local before=slots(st)
 check(#text<=100 and text:match('^[0-9a-f,]*;%d+$')~=nil,'the saved layout is short ('..#text..' characters: '..text..')')
 local slotsP,blankP=S.Parse(text);check(slotsP~=nil and blankP[1]==true,'it parses back (blank slots kept)')
 for _,bad in ipairs({'nope','a,b;1','zzzzzzzz;0',(',,,,,,,,,,,'):rep(1)..';0','12345678;99999',string.rep('a',300)})do check(S.Parse(bad)==nil,'a malformed layout is refused: '..bad:sub(1,20))end
 -- a new session: the same items arrive in another order, a few at a time; one saved item never comes (sold elsewhere)
 local st2=S.new(clock);st2:Restore(text)
 local keys={};for k in pairs(items)do if k~='d'then keys[#keys+1]=k end end;table.sort(keys,function(x,y)return x>y end)
 local got={};for i,k in ipairs(keys)do got[k]=item(k);if i%4==0 then st2:Reconcile(table.clone(got))end end;st2:Reconcile(got)
 local same=true;for i=1,10 do local want=st.Slots[i];if want=='d'then want=nil end;if st2.Slots[i]~=want and not(st.Slots[i]=='d')then same=false end;if(st.Blank[i]or false)~=(st2.Blank[i]or false)then same=false end end
 check(same,'rejoin: every item back on its saved slot, blank slots blank ('..before..' -> '..slots(st2)..')')
 local dslot=st:SlotOf('d');check(dslot and st2.Slots[dslot]==nil and st2:FirstFree()~=dslot,'a saved slot whose item has not come is kept for it while joining')
 local inBag=true;for k in pairs(got)do if not st:SlotOf(k)and not st2:InBag(k)then inBag=false end end
 check(inBag,'... and every item that was in the Bag is in the Bag again (never on a free slot)')
 st2:GoLive();st2:Reconcile(got)
 check(st2.Slots[dslot]==nil and st2:FirstFree()==dslot,'when the join ends, a saved slot whose item never came is free')
 got=with(got,'gift');st2:Reconcile(got);check(st2:SlotOf('gift')==dslot,'and the next new item takes it')
 -- no saved layout (a new player, or the first R155 session): arrival order, like before
 local st3=S.new(clock);st3:Restore('');local first=set({'shovel','p','q'});first.shovel.Order=-1;st3:Reconcile(first)
 check(slots(st3)=='shovel p q . . . . . . .','no saved layout: the items fill the slots in arrival order ('..slots(st3)..')')
 check(st3:Restore(text)==true and st3.Phase=='join','(a layout that arrives late during the join is still applied)')
 st3:GoLive();check(st3:Restore(text)==false,'after the join a saved layout is never applied again')
end
-- 7. a phone shows 5 slots -----------------------------------------------------------------------------------------------------------------------------
do
 local st=live(S.new(clock));local items={};for k=1,8 do items['p'..k]=item('p'..k)end;st:Reconcile(items) -- (laid out on a PC: 8 slots)
 st.Visible=5
 check(st:Shown('p6')==nil and st:InBag('p6')and st:Shown('p5')==5,'on a phone an item on slot 6-10 is a Bag item')
 items=without(items,'p2');st:Reconcile(items);items=with(items,'new');st:Reconcile(items)
 check(st:SlotOf('new')==2,'a new item takes a free SHOWN slot')
 items=with(items,'new2');st:Reconcile(items)
 check(st:InBag('new2')and not st:SlotOf('new2'),'... else the Bag (never a hidden slot)')
 check(st:Place('p7',3)and st.Slots[3]=='p7'and st.Slots[7]==nil,'a hidden-slot item placed on a shown slot leaves its hidden slot (it was a Bag item here)')
 -- Target agrees with where a new item lands
 st:Stow('p1');local t=st:Target('incoming');items=with(items,'incoming');st:Reconcile(items)
 check(t==st:SlotOf('incoming')or(t==nil and st:InBag('incoming')),'Target = where a new item really lands ('..tostring(t)..' / '..tostring(st:SlotOf('incoming'))..')')
 check(st:Target('p7')==3 and st:Target('new2')==nil,'Target of an existing stack = its shown slot, or nil (the Bag)')
 local pk=st.Slots[4];items[pk].Count=1;check(st:Target(nil,pk)==4 or st:FirstFree()~=nil,'the opened pack\'s own slot counts as free when it was the last of its stack')
end
-- 8. random -------------------------------------------------------------------------------------------------------------------------------------------
do
 now=1000;local st=live(S.new(clock));local items={};local seed=155
 local function rnd(n)seed=(seed*16807)%2147483647;return seed%n+1 end
 local dup,ghost,filled=0,0,0
 for step=1,3000 do
  local r=rnd(10);now+=.05
  if r<=3 then local k='i'..rnd(40);if not items[k]then items=with(items,k)end
  elseif r==4 then local keys={};for k in pairs(items)do keys[#keys+1]=k end;if #keys>0 then items=without(items,keys[rnd(#keys)])end
  elseif r==5 then local keys={};for k in pairs(items)do keys[#keys+1]=k end;if #keys>0 then st:Place(keys[rnd(#keys)],rnd(10))end
  elseif r==6 then local i=rnd(10);if st.Slots[i]then st:Stow(st.Slots[i])end
  elseif r==7 then st.Visible=rnd(2)==1 and 10 or 5
  end
  local blankBefore={};for i=1,10 do blankBefore[i]=st.Blank[i]and not st.Slots[i]end
  st:Reconcile(items)
  local seen={};for i=1,10 do local k=st.Slots[i];if k then if seen[k]then dup+=1 end;seen[k]=true;if not items[k]then ghost+=1 end end end
  for i=1,10 do if blankBefore[i]and st.Slots[i]then filled+=1 end end
 end
 check(dup==0,'random: never one key on two slots ('..dup..')')
 check(ghost==0,'random: no slot points at a missing item outside a respawn ('..ghost..')')
 check(filled==0,'random: a blank slot never fills by itself ('..filled..')')
end
-- the hash the save uses
check(Stacks.Hash('stack|Seed|Apple Seed|AppleSeed|1|None|None|Common')==Stacks.Hash('stack|Seed|Apple Seed|AppleSeed|1|None|None|Common')and #Stacks.Hash('x')==8,'the layout hash is stable and 8 characters')
do local seen,clash={},0;for i=1,5000 do local h=Stacks.Hash('stack|Fruit|Fruit '..i..'|Seed'..(i%37)..'|1.'..i);if seen[h]then clash+=1 end;seen[h]=true end;check(clash==0,'5000 different keys, no hash clash ('..clash..')')end
print(('R155 layout model checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
