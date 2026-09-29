local R={}
-- Remaining time is adjusted once when the entitlement improves, never on every join.
function R.Apply(crop,rate,now)
 local previous=crop.GrowthRate or 1;rate=rate==2 and 2 or 1
 if rate<=previous then return false end
 local function shorten(at)return at>now and now+math.max(1,math.ceil((at-now)*previous/rate))or at end
 crop.MatureAt=shorten(crop.MatureAt or crop.ReadyAt)
 crop.ReadyAt=math.max(crop.MatureAt,shorten(crop.ReadyAt))
 for _,fruit in pairs(crop.FruitStates or{})do
  fruit.ReadyAt=math.max(crop.MatureAt,shorten(fruit.ReadyAt))
  if fruit.Duration then fruit.Duration=math.max(1,math.ceil(fruit.Duration*previous/rate))end
 end
 crop.GrowthRate=rate;return true
end
return R
