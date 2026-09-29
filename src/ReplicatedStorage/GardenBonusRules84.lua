-- One source for the garden sign and planting bonuses. No cosmetic 3x claims.
local Fence=require(script.Parent.GardenFenceRules)
local R={}
function R.Read(tier,doubleGrowth)
 local size=Fence.Size(tier);local time=Fence.Time(tier);local growth=doubleGrowth and 2 or 1
 return {Size=size,Time=time/growth,FenceSize=size-1,FenceReduction=1-time,Growth=growth}
end
function R.Number(n)return string.format('%.3f',n):gsub('0+$',''):gsub('%.$','')end
return R
