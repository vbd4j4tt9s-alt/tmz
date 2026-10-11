-- Stable hotbar assignment, independent of temporary Backpack/Character parenting.
-- R155 (owner: "hot bar and inventory management is still not fixed just make it function like the normal inventory ... i can have a blank hot bar if
-- i put everything in my bag"): the hotbar works like Roblox's own Backpack. Slots[1..10] hold the stack key shown there; every item that is not on a
-- shown slot is in the Bag. Nothing ever moves by itself:
--  * a NEW item joins its stack wherever that is; else it takes the first FREE shown slot (1, 2, 3 ...); else it goes to the Bag. It never pushes an
--    item off the hotbar, and an item already in the Bag never jumps onto a slot that frees up (R153 refilled free slots from the Bag: "items jumping").
--  * a BLANK slot is one the player emptied by putting its item in the Bag (Stow). It stays empty until the player puts something there; new items
--    skip it. Putting the LAST item of the hotbar in the Bag makes every slot blank (a fully blank hotbar stays blank). A slot that empties any other way
--    (the item used up, sold, gifted, planted, or moved to another slot) is free: the next new item may take it.
--  * Place(key, slot): onto an empty slot = moved there; onto a taken slot = swap (from another slot the two trade places; from the Bag the item that was
--    there goes to the Bag). Stow(key): off the hotbar into the Bag, its slot blank.
--  * Remember(): a respawn takes every item away for a moment; each one comes back to where it was (its slot, or the Bag) within Window s, and the slots
--    of the ones still on their way stay free meanwhile (R153).
--  * renames {old=new} (Reconcile): an item whose key changes (a held pack that gains a weather) keeps its slot.
--  * The layout is saved between sessions (Serialize / Restore: the hash of each slot's key and the blank slots; PlayerDataService keeps it as the optional
--    field Hotbar155). While the player's items arrive after joining (Phase 'join'), each goes back to its saved slot and everything else to the Bag; with no
--    saved layout (a new player, or the first R155 session) they fill the slots in arrival order, the shovel first. GoLive() ends that phase.
local S={};S.__index=S
S.Window=15
S.Count=10
local Stacks
local function hash(key)Stacks=Stacks or require(script.Parent.InventoryStacks155);return Stacks.Hash(key)end
function S.new(clock)
 return setmetatable({Slots={},Items={},Blank={},Back={},Gone={},BackUntil=-math.huge,Clock=clock or os.clock,Visible=S.Count,Phase='join',SavedSlots=nil,Version=0},S)
end
function S:SlotOf(key)for i=1,S.Count do if self.Slots[i]==key then return i end end;return nil end
-- The slot a key is SHOWN on (nil = it is in the Bag).
function S:Shown(key)local i=self:SlotOf(key);if i and i<=self.Visible then return i end;return nil end
function S:InBag(key)return self.Items[key]~=nil and self:Shown(key)==nil end
local function bump(self)self.Version+=1 end
local function signature(self)local out={};for i=1,S.Count do out[i]=self.Slots[i]or''end;return table.concat(out,'\1')..'|'..self.Visible end
function S:Remember()
 local now=self.Clock();if now>self.BackUntil then table.clear(self.Back)end;table.clear(self.Gone)
 for key in pairs(self.Items)do self.Back[key]=self:SlotOf(key)or'bag'end
 for i=1,S.Count do local k=self.Slots[i];if k then self.Back[k]=i end end
 self.BackUntil=now+S.Window
end
-- the slots kept for an item still on its way back (a respawn) or, while joining, for a saved slot whose item has not arrived
local function reserved(self,i)
 local k=self.Slots[i];if k and not self.Items[k]then return true end
 if self.Phase=='join'and self.SavedSlots and self.SavedSlots[i]then return true end
 return false
end
function S:FirstFree(skipKey)
 for i=1,math.min(self.Visible,S.Count)do
  local k=self.Slots[i]
  if(k==nil or k==skipKey)and not self.Blank[i]and not(k==nil and reserved(self,i))then return i end
 end
 return nil
end
function S:Reconcile(items,renames)
 local prev=self.Items;self.Items=items;local before=signature(self)
 local known={}
 for old,new in pairs(renames or{})do if not items[old]and items[new]then
  local at=self:SlotOf(old);if at and not self:SlotOf(new)then self.Slots[at]=new end
  if self.Back[old]~=nil then self.Back[new]=self.Back[old];self.Back[old]=nil end
  known[new]=true
 end end
 local back=self.Clock()<=self.BackUntil and self.Back or nil;if not back then table.clear(self.Back);table.clear(self.Gone)end
 if back then for k in pairs(back)do if not items[k]then self.Gone[k]=true end end end -- (on its way back)
 -- a slot whose item is gone: kept while it may come back (respawn), else free (not blank: it emptied by itself)
 for i=1,S.Count do local k=self.Slots[i];if k and not items[k]and not(back and back[k]==i)then self.Slots[i]=nil end end
 -- joining: an item goes back to its saved slot
 local saved=self.Phase=='join'and self.SavedSlots or nil
 local new={}
 for key,e in pairs(items)do if not self:SlotOf(key)then
  local b=back and back[key]
  if b~=nil then
   if type(b)=='number'and not self.Slots[b]then self.Slots[b]=key end -- (else it stays in the Bag)
  elseif saved then
   local h=hash(key);local at
   for i=1,S.Count do if saved[i]==h then at=i;break end end
   if at then saved[at]=nil;if not self.Slots[at]then self.Slots[at]=key;self.Blank[at]=nil end end -- (no saved slot: the Bag)
  elseif not prev[key]and not known[key]then new[#new+1]=key end -- (an item already here and not on a slot stays in the Bag)
 end end
 -- an item that has come back has used its memory: if it goes again (used up), its slot frees at once
 if back then for k in pairs(self.Gone)do if items[k]then back[k]=nil;self.Gone[k]=nil end end end
 table.sort(new,function(a,b)local x,y=items[a],items[b];if x.Order==y.Order then return a<b end;return x.Order<y.Order end)
 for _,key in ipairs(new)do local i=self:FirstFree();if i then self.Slots[i]=key end end
 if signature(self)~=before then bump(self)end
end
function S:Place(key,slot)
 if not self.Items[key]or type(slot)~='number'or slot<1 or slot>S.Count then return false end
 local prior=self:SlotOf(key);if prior==slot then return false end
 self.Touched=true -- (the player arranged something: a saved layout that arrives later must not undo it)
 if prior and prior>self.Visible then self.Slots[prior]=nil;prior=nil end -- (on a slot this screen does not show: it is a Bag item here)
 local occupant=self.Slots[slot];if occupant and not self.Items[occupant]then occupant=nil end
 if prior then self.Slots[prior]=occupant end -- (a swap; with nothing there the old slot is just free)
 self.Slots[slot]=key;self.Blank[slot]=nil
 table.clear(self.Back);table.clear(self.Gone);bump(self);return true
end
function S:Stow(key)
 if not self.Items[key]then return false end
 local found=false;for i=1,S.Count do if self.Slots[i]==key then self.Slots[i]=nil;self.Blank[i]=true;found=true end end
 -- the last item off the hotbar: the player wants it blank, so every slot is blank (new items go to the Bag until something is put on it)
 if found then self.Touched=true;local any=false;for i=1,S.Count do if self.Slots[i]and self.Items[self.Slots[i]]then any=true end end;if not any then for i=1,S.Count do self.Blank[i]=true end end end
 table.clear(self.Back);table.clear(self.Gone);if found then bump(self)end;return found
end
-- Where a new item with this key would land now: its stack's shown slot, else (its stack is in the Bag) nil; a key not here yet: the first free slot
-- (freeing = the key of an item about to go, e.g. the pack being opened when it is the last of its stack), else nil (the Bag).
function S:Target(key,freeing)
 if key and self.Items[key]then return self:Shown(key)end
 return self:FirstFree(freeing)
end
-- true while a slot is kept for an item on its way back (a respawn): the layout is not saved meanwhile
function S:Waiting()for i=1,S.Count do local k=self.Slots[i];if k and not self.Items[k]then return true end end;return false end
function S:GoLive()
 if self.Phase=='live'then return false end
 self.Phase='live';self.SavedSlots=nil;bump(self);return true
end
function S:Serialize()
 local out={};local mask=0
 for i=1,S.Count do local k=self.Slots[i];out[i]=k and self.Items[k]and hash(k)or'';if self.Blank[i]and not self.Slots[i]then mask+=2^(i-1)end end
 return table.concat(out,',')..';'..mask
end
-- The saved layout (Serialize's string). Only while joining; false when it is not one.
function S.Parse(text)
 if type(text)~='string'or #text>200 then return nil end
 local list,mask=text:match('^([0-9a-f,]*);(%d+)$');if not list then return nil end
 mask=tonumber(mask);if not mask or mask<0 or mask>=2^S.Count then return nil end
 local slots,blank,i={},{},0
 for part in(list..','):gmatch('([^,]*),')do i+=1;if i>S.Count then return nil end;if part~=''then if not part:match('^[0-9a-f]+$')or #part~=8 then return nil end;slots[i]=part end end
 for b=1,S.Count do if math.floor(mask/2^(b-1))%2==1 then blank[b]=true end end
 return slots,blank
end
function S:Restore(text)
 if self.Phase~='join'then return false end
 local slots,blank=S.Parse(text);if not slots then return false end
 table.clear(self.Slots);table.clear(self.Blank);for i in pairs(blank)do self.Blank[i]=true end
 self.SavedSlots=slots;local items=self.Items;self.Items={};self:Reconcile(items);bump(self);return true
end
return S
