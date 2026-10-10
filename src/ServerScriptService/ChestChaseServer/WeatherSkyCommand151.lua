-- R151: the owner's test commands for the default sky (WeatherCycle151: Clear <-> Cloudy), dispatched from OwnerUpdateCommands82's `weather`:
--   weather cloudy            the sky goes Cloudy for Config.TestHold seconds (no event weather meanwhile), arriving in Config.TestFade seconds
--   weather clear             (handled there, then HoldSky here) the sky goes Clear for the same time, like the old command plus the default sky
--   weather cycle             what the cycle is doing: the sky, its fade, when it changes, the event weather
--   weather cycle skip        end the current phase now: the other sky starts, with its real 20 - 40 s fade (see the fade), the cycle goes on from there
--   weather cycle auto        back to the real schedule (also what happens by itself when a hold runs out)
-- Event weather commands (rain / thunder / blizzard [all]) are unchanged: the event takes priority and the cycle runs underneath.
local RS=game:GetService('ReplicatedStorage')
local X={}
X.Usage='Use weather cloudy, weather clear, weather cycle [skip|auto], or weather rain/thunder/blizzard [all].'
local function eventClear(service,now,W,Cycle)
 -- the same override `weather clear` uses (no event weather), kept as long as the sky is held so a scheduled storm cannot hide the test
 service.TestSerial=(service.TestSerial or 0)+1
 service.Override={Kind='Clear',Cycle=-service.TestSerial,Until=now+math.max(W.Duration,Cycle.Config.TestHold),All=false};service:Step(now)
end
function X.Execute(ctx,p,a)
 local service=ctx.Chests and ctx.Chests.Weather;if not service or not service.HoldSky then return false,'Weather is loading.'end
 local W=require(RS.WeatherTraits);local Cycle=require(RS.WeatherCycle151)
 local now=workspace:GetServerTimeNow()
 local sub=a[1]
 if sub=='cloudy'then
  if #a~=1 then return false,X.Usage end
  eventClear(service,now,W,Cycle);service:HoldSky('Cloudy',now)
  return true,string.format('Server sky: Cloudy for %d minutes, arriving over %d s (dim, cool light; the lamps and lanterns warm up in the base). No event weather meanwhile; weather cycle auto returns to the cycle.',math.floor(Cycle.Config.TestHold/60+.5),Cycle.Config.TestFade)
 elseif sub=='cycle'then
  local what=a[2]
  if what==nil then
   service:StepSky(now);return true,table.concat(service:SkyReport(now),'\n')
  elseif what=='skip'or what=='next'then
   if #a~=2 then return false,X.Usage end
   local s=service:SkipSky(now)
   return true,string.format('Cycle skipped: the sky goes %s now over %.0f s (the real fade), then the cycle goes on from there. weather cycle shows it; weather cycle auto restores the real schedule.',s.Kind,s.Fade)
  elseif what=='auto'or what=='reset'then
   if #a~=2 then return false,X.Usage end
   local s=service:ReleaseSky(now)
   return true,string.format('Back to the real schedule: the sky is %s.',s and s.Kind or'Clear')
  end
  return false,X.Usage
 end
 return false,X.Usage
end
return X
