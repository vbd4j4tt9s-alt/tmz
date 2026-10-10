-- R148 (owner: "place a timer at the limited section for 27 days, hrs, mins, s; same for the event for Verity"): one end time
-- for the limited event, shared by the Index LIMITED tab and Verity's quest. UTC seconds; change EndsAt to extend or shorten it.
local L={EndsAt=1793491200} -- 2026-11-01 00:00:00 UTC
function L.Left(now)return math.max(0,L.EndsAt-math.floor(now or os.time()))end
function L.Active(now)return L.Left(now)>0 end
-- "27d 04h 12m 09s"
function L.Text(seconds)
 seconds=math.max(0,math.floor(tonumber(seconds)or 0))
 return string.format('%dd %02dh %02dm %02ds',seconds//86400,seconds%86400//3600,seconds%3600//60,seconds%60)
end
return L
