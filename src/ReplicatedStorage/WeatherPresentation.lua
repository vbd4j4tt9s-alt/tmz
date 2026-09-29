-- R78: denser near-camera weather with a bounded live-particle envelope.
local W={}
function W.Profile(kind,tier,mobile)
 tier=math.clamp(math.floor(tonumber(tier)or 1),1,3)
 local snow=kind=='Blizzard';local low=tier==1
 local rate=(snow and {85,130,190}or {90,160,260})[tier]
 if mobile then rate=math.min(rate,90)end
 return {Rate=rate,Size=snow and .30 or .46,Life=snow and 2.8 or 1.05,
  Speed=snow and 22 or 66,Height=snow and 23 or 28,Width=low and 26 or 36,Depth=low and 24 or 32,
  Interval=low and .1 or .05,MaxLive=math.ceil(rate*(snow and 2.8 or 1.05))}
end
function W.CloudInterval(tier)return tier==1 and .25 or tier==2 and .16 or .10 end
return W
