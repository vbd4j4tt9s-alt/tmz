-- R88: practical 500 speed ceiling; exact saved points continue without a designed cap.
local Points=require(script.Parent.SpeedPoints)
local T=require(script.Parent.BalanceValues81)
local R={}
-- Saved points keep their R81 meaning; only the physical pace changes in R82.
local migrationCurve={{0,24},{20000,30},{100000,45},{500000,75},{2000000,130},{20000000,300},{500000000,650},{20000000000,1300},{1000000000000,2400},{20000000000000,3800},{100000000000000,5000}}
local function curveSpeed(points,knots,tail,logarithmic)
 local s=Points.Normalize(points);local last=knots[#knots]
 if Points.Compare(s,Points.Normalize(last[1]))>0 then return last[2]+tail*(Points.Log10(s)-math.log10(last[1]))end
 local n=tonumber(s)
 for i=2,#knots do local a,b=knots[i-1],knots[i]
  if n<=b[1]then
   local t=logarithmic and a[1]>=2000000 and math.log(n/a[1])/math.log(b[1]/a[1])or(n-a[1])/(b[1]-a[1])
   return a[2]+(b[2]-a[2])*t
  end
 end
 return last[2]
end
function R.Speed(points)return curveSpeed(points,T.PointCurve,T.SpeedTailPerDecade,true)end
-- R141: the fewest Speed points whose walk speed reaches `speed` (the inverse of R.Speed), as a number.
function R.PointsFor(speed)
 local knots=T.PointCurve;speed=tonumber(speed)or 0
 if speed<=knots[1][2]then return 0 end
 local n
 for i=2,#knots do local a,b=knots[i-1],knots[i]
  if speed<=b[2]then
   local t=(speed-a[2])/(b[2]-a[2])
   n=math.ceil(a[1]>=2000000 and a[1]*(b[1]/a[1])^t or a[1]+(b[1]-a[1])*t);break
  end
 end
 if not n then local last=knots[#knots];n=math.ceil(last[1]*10^((speed-last[2])/T.SpeedTailPerDecade))end
 -- R147: the closed form can land a point off through floating-point noise (a whole 1118 points comes out as
 -- 1118.0000000000002 and rounds up to 1119). Settle it against R.Speed itself: Speed(n) >= speed > Speed(n-1).
 if n<2^52 then
  for _=1,4 do if R.Speed(n)<speed then n+=1 else break end end
  for _=1,4 do if n>0 and R.Speed(n-1)>=speed then n-=1 else break end end
 end
 return n
end
-- R147: the same as exact decimal text, also where the number is too big for a double (The Darkened's 600 would take
-- 10^1011 points; math.ceil gives inf). Feed it to SpeedPoints.Compact for the keeper label ("1e1011").
function R.PointsText(speed)
 local n=R.PointsFor(speed)
 if n<math.huge then return string.format('%.0f',n)end
 local last=T.PointCurve[#T.PointCurve]
 local e=math.log10(last[1])+((tonumber(speed)or 0)-last[2])/T.SpeedTailPerDecade -- log10 of the points
 local whole=math.floor(e+1e-9);local lead=math.floor(10^math.max(0,e-whole)*1e14+.5) -- 15 digits
 if lead>=1e15 then lead=1e14;whole+=1 end
 return string.format('%.0f',lead)..string.rep('0',whole-14)
end
function R.PointsAt(speed)
 if speed<=24 then return '0'end
 for i=2,#migrationCurve do
  local a,b=migrationCurve[i-1],migrationCurve[i]
  if speed<=b[2]then return Points.Normalize(math.ceil(a[1]+(b[1]-a[1])*(speed-a[2])/(b[2]-a[2])))end
 end
 -- Migration only calls this with the old finite ceiling (5,000).
 return '100000000000000'
end
local old={{0,24},{1000,28},{5000,32},{15000,37},{35000,43},{75000,50},{150000,58},{300000,66},{600000,74},
 {2000000,125},{5000000,220},{15000000,500},{35000000,1000},{75000000,2000},{150000000,3000},{350000000,4000},{600000000,4500}}
function R.LegacySpeed(n)
 n=math.clamp(tonumber(n)or 0,0,1000000000)
 for i=2,#old do local a,b=old[i-1],old[i];if n<=b[1]then return a[2]+(b[2]-a[2])*(n-a[1])/(b[1]-a[1])end end
 return 4500+500*math.log(n/600000000)/math.log(1000000000/600000000)
end
function R.Migrate(oldPoints)
 local original=Points.Normalize(oldPoints);local converted=R.PointsAt(R.LegacySpeed(oldPoints))
 return Points.Compare(original,converted)>0 and original or converted
end
function R.LegacySave(points)
 local speed=curveSpeed(points,migrationCurve,100)
 for i=2,#old do local a,b=old[i-1],old[i];if speed<=b[2]then return math.ceil(a[1]+(b[1]-a[1])*(speed-a[2])/(b[2]-a[2]))end end
 return math.min(1000000000,math.ceil(600000000*(1000000000/600000000)^((math.min(speed,5000)-4500)/500)))
end
function R.Playback(speed)
 local knots=T.AnimationRateCurve
 for i=2,#knots do local a,b=knots[i-1],knots[i];if speed<=b[1]then return a[2]+(b[2]-a[2])*(math.max(0,speed)-a[1])/(b[1]-a[1])end end
 return 10
end
return R
