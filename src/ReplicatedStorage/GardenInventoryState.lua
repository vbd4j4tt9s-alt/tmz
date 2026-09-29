-- Stable hotbar assignment, independent of temporary Backpack/Character parenting.
local S={};S.__index=S
function S.new()return setmetatable({Slots={},Items={}},S)end
function S:Reconcile(items)
 self.Items=items
 for i=1,10 do if self.Slots[i]and not items[self.Slots[i]]then self.Slots[i]=nil end end
 if items.shovel then self.Slots[1]='shovel'end
 local assigned={};for _,key in pairs(self.Slots)do assigned[key]=true end
 local keys={};for key in pairs(items)do if not assigned[key]then table.insert(keys,key)end end
 table.sort(keys,function(a,b)local x,y=items[a],items[b];return x.Order==y.Order and a<b or x.Order<y.Order end)
 for _,key in ipairs(keys)do for slot=2,10 do if not self.Slots[slot]then self.Slots[slot]=key;break end end end
end
function S:Place(key,slot)
 if not self.Items[key]or key=='shovel'or slot<2 or slot>10 then return false end
 local prior;for i=2,10 do if self.Slots[i]==key then prior=i;break end end
 if prior then self.Slots[prior]=self.Slots[slot]end;self.Slots[slot]=key;return true
end
function S:Ensure(key,visibleSlots)
 for i=1,visibleSlots do if self.Slots[i]==key then return i end end
 for i=2,visibleSlots do if not self.Slots[i]then self:Place(key,i);return i end end
 self:Place(key,visibleSlots);return visibleSlots
end
return S
