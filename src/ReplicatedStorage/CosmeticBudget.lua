-- R63: only distant, settled and off-screen keepers may skip visual pose writes.
local B={};local Weather=require(script.Parent.WeatherTraits)
function B.KeeperDue(distance,asleep,awake,onScreen,now,last,low)
 if distance<=160 then return true end
 local interval
 if onScreen then interval=distance<=350 and(asleep and(low and .15 or .1)or(low and 1/20 or 1/30))or(low and .2 or .1)
 else interval=asleep and awake<=.02 and .5 or .15 end
 return not last or now-last+1e-5>=interval
end
function B.CollectionViews(low)return low and 6 or 18 end
-- R72: count actual cosmetic pieces, not just the number of items.
function B.SelectItems(entries,low)
 local chosen={};local used=0;local parts=low and 96 or 240;local count=low and 8 or 18
 for _,entry in ipairs(entries)do
  local cost=Weather.Count(entry.Weather)*8+(entry.Mech and 12 or 0)
  if cost>0 and used+cost<=parts and #chosen<count then
   used+=cost;table.insert(chosen,entry)
  end
 end
 return chosen,used
end
function B.PackDue(distance,visible,now,last,low)
 if not visible then return false end
 local interval=distance<=240 and(low and 1/20 or 1/30)or(low and 1 or .5)
 return not last or now-last+1e-5>=interval
end
return B
