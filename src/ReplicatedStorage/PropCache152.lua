-- R152 performance patch: write a property only when its value changes. A per-frame animation (the seed opening's card, stages and effects) used
-- to set every property of every piece every frame, most of them to the value already there (a hidden ring's Transparency 1, a card edge's colour,
-- a beam that stays on): each of those is an engine call for nothing. A cache remembers the last value IT wrote to each instance's property and
-- skips the write when the new value is the same (Vector3 / Color3 / UDim2 / NumberSequence compare by value). The look is the same by
-- construction: every value that differs is written, in the same frame, in the same order.
-- Only for pieces one owner animates (nothing else writes those properties); a cache lives as long as its owner (a card, a stage, an effect).
--   local C=Cache.new();C.Set(o,'Transparency',v);C.Scale(o,'Position',x,y) (UDim2.fromScale, built only when x / y change)
local M={}
local function same(a,b)
 if a==b then return true end
 local t=typeof(a);if t~=typeof(b)then return false end
 if t=='UDim2'then return a.X.Scale==b.X.Scale and a.X.Offset==b.X.Offset and a.Y.Scale==b.Y.Scale and a.Y.Offset==b.Y.Offset end
 if t=='Color3'then return a.R==b.R and a.G==b.G and a.B==b.B end
 if t=='Vector3'then return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
 return false
end
M.Same=same
function M.new()
 local last=setmetatable({},{__mode='k'})      -- instance -> {property -> the value last written}
 local pairsOf=setmetatable({},{__mode='k'})   -- instance -> {property -> {x, y}} for Scale
 local C={}
 function C.Set(o,k,v)
  local c=last[o];if not c then c={};last[o]=c end
  local old=c[k]
  if old~=nil and same(old,v)then return end
  c[k]=v;o[k]=v
  local p=pairsOf[o];if p then p[k]=nil end
 end
 function C.Scale(o,k,x,y)
  local p=pairsOf[o];if not p then p={};pairsOf[o]=p end
  local q=p[k]
  if q then if q[1]==x and q[2]==y then return end;q[1],q[2]=x,y else p[k]={x,y}end
  o[k]=UDim2.fromScale(x,y)
  local c=last[o];if c then c[k]=nil end
 end
 -- forget what was written to an instance (another owner wrote it; the next Set writes again)
 function C.Forget(o)last[o]=nil;pairsOf[o]=nil end
 return C
end
return M
