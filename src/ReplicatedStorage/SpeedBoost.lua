-- R121: timed x2 training boost (developer product SpeedBoost10, sold by the SPEED banner).
-- The expiry is saved in the premium profile as server unix time (os.time) and mirrored to the
-- player attribute SpeedBoostEndsAt for the HUD. It multiplies with the permanent x2 Speed pass.
local S={Key='SpeedBoost10',Seconds=600,MaxSeconds=3600,Factor=2,Attribute='SpeedBoostEndsAt'}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function S.Remaining(endsAt,now)
 if not finite(endsAt)or not finite(now)then return 0 end
 return math.max(0,endsAt-now)
end
function S.FactorAt(endsAt,now)return S.Remaining(endsAt,now)>0 and S.Factor or 1 end
-- Buying for yourself stops at MaxSeconds; paid receipts and gifts always add their full time.
function S.CanStack(endsAt,now)return S.Remaining(endsAt,now)+S.Seconds<=S.MaxSeconds end
function S.Extend(endsAt,now)
 return math.floor(math.max(now,finite(endsAt)and endsAt or 0)+S.Seconds)
end
-- "9m 59s" / "45s" / "1h 0m" (the HUD timer style).
function S.Clock(seconds)
 seconds=math.max(0,math.ceil(finite(seconds)and seconds or 0))
 local h=seconds//3600;local m=(seconds%3600)//60;local s=seconds%60
 if h>0 then return string.format('%dh %dm',h,m)end
 if m>0 then return string.format('%dm %ds',m,s)end
 return string.format('%ds',s)
end
function S.PlayerRemaining(player,now)
 return S.Remaining(tonumber(player:GetAttribute(S.Attribute)),now or workspace:GetServerTimeNow())
end
function S.PlayerFactor(player,now)return S.PlayerRemaining(player,now)>0 and S.Factor or 1 end
return S
