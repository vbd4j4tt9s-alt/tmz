-- Stable hotbar assignment, independent of temporary Backpack/Character parenting.
-- R153 (owner: "players cant drag seeds and reorganise their hotbar"): the player's own order holds for the whole session. Nothing of the hotbar is saved
-- between sessions (there is no saved slot state), so a new session starts in arrival order again.
--  * Remember(): a respawn / new Backpack takes every item away for a moment; each one comes back to the slot it had (within Window s) and the slots of
--    the ones still on their way are kept free meanwhile. (An item used up or sold on its own frees its slot at once, as before.)
--  * renames {old=new} (Reconcile): an item whose key changes (a held pack that gains a weather) keeps its slot.
--  * Stow(key): an item dragged off the hotbar into the Bag stays off it until it is placed or held again.
local S={};S.__index=S
S.Window=15
function S.new(clock)return setmetatable({Slots={},Items={},Stowed={},Back={},Gone={},BackUntil=-math.huge,Clock=clock or os.clock},S)end
function S:Remember()
 local now=self.Clock();if now>self.BackUntil then table.clear(self.Back)end
 for i=1,10 do local k=self.Slots[i];if k then self.Back[k]=i end end;self.BackUntil=now+S.Window
end
function S:Reconcile(items,renames)
 self.Items=items
 for old,new in pairs(renames or{})do if not items[old]and items[new]then
  local at,taken;for i=1,10 do if self.Slots[i]==old then at=i elseif self.Slots[i]==new then taken=true end end
  if at and not taken then self.Slots[at]=new end
  if self.Stowed[old]then self.Stowed[old]=nil;self.Stowed[new]=true end
 end end
 local back=self.Clock()<=self.BackUntil and self.Back or nil;if not back then table.clear(self.Back)end
 for i=1,10 do if self.Slots[i]and not items[self.Slots[i]]then self.Slots[i]=nil end end
 for k in pairs(self.Stowed)do if not items[k]and not back then self.Stowed[k]=nil end end
 if items.shovel then self.Slots[1]='shovel'end
 local assigned={};for i=1,10 do local k=self.Slots[i];if k then assigned[k]=true end end
 local keys={};for key in pairs(items)do if not assigned[key]and not self.Stowed[key]then table.insert(keys,key)end end
 table.sort(keys,function(a,b)local x,y=items[a],items[b];return x.Order==y.Order and a<b or x.Order<y.Order end)
 local kept={} -- slots of items still on their way back (an item stays remembered until it has been gone and come back, or the window ends)
 if back then for k,i in pairs(back)do if items[k]then if assigned[k]and self.Gone[k]then back[k]=nil;self.Gone[k]=nil end else kept[i]=true;self.Gone[k]=true end end
 else table.clear(self.Gone)end
 local rest={}
 for _,key in ipairs(keys)do local i=back and back[key]
  if i and i>=2 and not self.Slots[i]then self.Slots[i]=key;back[key]=nil;self.Gone[key]=nil else table.insert(rest,key)end
 end
 for _,key in ipairs(rest)do
  local pick;for slot=2,10 do if not self.Slots[slot]and not kept[slot]then pick=slot;break end end
  if not pick then for slot=2,10 do if not self.Slots[slot]then pick=slot;break end end end
  if pick then self.Slots[pick]=key end;if back then back[key]=nil;self.Gone[key]=nil end
 end
end
function S:Place(key,slot)
 if not self.Items[key]or key=='shovel'or slot<2 or slot>10 then return false end
 local prior;for i=2,10 do if self.Slots[i]==key then prior=i;break end end
 if prior then self.Slots[prior]=self.Slots[slot]end;self.Slots[slot]=key;self.Stowed[key]=nil;table.clear(self.Back);table.clear(self.Gone);return true
end
function S:Stow(key)
 if not self.Items[key]or key=='shovel'then return false end
 local found=false;for i=2,10 do if self.Slots[i]==key then self.Slots[i]=nil;found=true end end
 self.Stowed[key]=true;table.clear(self.Back);table.clear(self.Gone);return found
end
function S:Ensure(key,visibleSlots)
 self.Stowed[key]=nil
 for i=1,visibleSlots do if self.Slots[i]==key then return i end end
 for i=2,visibleSlots do if not self.Slots[i]then self:Place(key,i);return i end end
 self:Place(key,visibleSlots);return visibleSlots
end
return S
