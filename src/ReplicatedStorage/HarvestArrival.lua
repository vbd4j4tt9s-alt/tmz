-- R149 (owner: "when harvesting ... the fruit floats into the player and disappears after and appears in the player's inventory"): the link between
-- the fruit that flies to the harvester (PlantGrowthFx, from GardenVisuals) and the inventory (Hotbar). Client-only and cosmetic: the harvested item
-- is in the Backpack as soon as the server adds it (nothing here touches data); the Hotbar just does not SHOW it until the fruit has arrived.
--  Expect   the harvester's client sent a Harvest request (EconomyClient): its fruit will arrive. Held until `start` seconds pass (no flight begins).
--  Flying   the flight began: the hold now lasts as long as the flight (+ a little).
--  Land     the fruit arrived (or the flight was skipped, dropped or never started): the hold ends and the listeners (the Hotbar) fire.
--  Holds    true while a Backpack tool must stay out of the inventory view.
-- A hold always ends: by Land, Cancel, LandCrop (the plant went away) or at its deadline.
local A={}
local pending={};local listeners={}
A.Tuning={Start=1.5,Margin=.15}
local function key(cropId,index)return tostring(cropId)..':'..tostring(index or 1)end
A.Key=key
-- The key of a harvested item's Backpack tool (the tool carries the plant it came from and its fruit slot).
function A.ToolKey(tool)
 local id=tool:GetAttribute('SourceCropId');if id==nil or not tool:GetAttribute('HarvestItemTool')then return nil end
 return key(id,tool:GetAttribute('FruitIndex'))
end
local function fire(k,cue)
 for _,fn in ipairs(table.clone(listeners))do fn(k,cue)end
end
local function release(k,cue)
 if pending[k]==nil then return false end
 pending[k]=nil;fire(k,cue);return true
end
local function watch(k,entry,seconds)
 task.delay(seconds,function()
  if pending[k]~=entry then return end
  local left=entry.Due-os.clock()
  if left>.01 then watch(k,entry,left)else release(k,true)end
 end)
end
function A.Expect(cropId,index,start)
 start=start or A.Tuning.Start
 local k=key(cropId,index);local entry={Due=os.clock()+start,Flying=false};pending[k]=entry;watch(k,entry,start)
 return k
end
function A.Flying(cropId,index,seconds)
 local k=key(cropId,index);local entry=pending[k];if not entry then return end
 entry.Flying=true;entry.Due=os.clock()+seconds+A.Tuning.Margin
end
function A.Land(cropId,index)return release(key(cropId,index),true)end
function A.Cancel(cropId,index)return release(key(cropId,index),false)end
-- The plant is gone (a whole-plant harvest removes it): nothing will fly for it.
function A.LandCrop(cropId)
 local prefix=tostring(cropId)..':';local list={}
 for k in pairs(pending)do if string.sub(k,1,#prefix)==prefix then table.insert(list,k)end end
 for _,k in ipairs(list)do release(k,true)end
end
function A.Holds(tool)
 if next(pending)==nil then return false end -- (nearly always: nothing to look up)
 local k=A.ToolKey(tool);local entry=k and pending[k]
 return entry~=nil and os.clock()<entry.Due
end
function A.Pending(cropId,index)return pending[key(cropId,index)]~=nil end
-- fn(key, cue): a hold ended; cue is false only for a failed request. Returns a connection with :Disconnect().
function A.OnRelease(fn)
 table.insert(listeners,fn)
 return {Disconnect=function()local at=table.find(listeners,fn);if at then table.remove(listeners,at)end end}
end
function A.Reset()table.clear(pending);table.clear(listeners)end
return A
