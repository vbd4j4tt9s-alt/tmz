-- R62: presentation only; server attributes remain authoritative.
local RS=game:GetService('ReplicatedStorage');local W=require(RS.WeatherTraits);local Packs=require(RS.SeedPackRules)
local S={}
function S.Seconds(deadline,now)
 return type(deadline)=='number'and deadline==deadline and deadline<math.huge and math.max(0,math.ceil(deadline-now))or nil
end
function S.Clock(seconds)
 if not seconds then return '--:--'end
 return string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
end
function S.LocalWeather(map,point)
 if not map or not point or math.abs(point.X)>(tonumber(map:GetAttribute('FieldWidth'))or 180)/2 or point.Y< -10 or point.Y>150 then return 'Clear'end
 for _,entry in ipairs({{3,'Snow'},{7,'Rain'}})do
  local a,b=map:GetAttribute('BiomeStartZ_'..entry[1]),map:GetAttribute('BiomeEndZ_'..entry[1])
  if type(a)=='number'and type(b)=='number'and point.Z>=a and point.Z<b then return entry[2]end
 end
 return 'Clear'
end
function S.Read(storage,map,point,now)
 local global=storage:GetAttribute('GlobalWeather')or'Clear';if not W.Events[global]then global='Clear'end
 local kind=global~='Clear'and global or S.LocalWeather(map,point)
 local seconds=S.Seconds(storage:GetAttribute(global=='Clear'and'NextWeatherAt'or'WeatherEndsAt'),now)
 local weather={Kind=kind,Title=kind=='Clear'and'Clear skies'or kind,Caption=global=='Clear'and'Next weather'or'Ends in',Time=S.Clock(seconds),Progress=seconds and math.clamp(seconds/(global=='Clear'and W.Interval-W.Duration or W.Duration),0,1)or 0}
 local closed=map and map:GetAttribute('BiomesRefreshing')==true
 local nextReset=map and S.Seconds(map:GetAttribute('NextBiomeRefreshAt'),now)
 local left=closed and tonumber(map:GetAttribute('BiomeRefreshSeconds'))or nextReset
 if closed then
  -- R150: read the same server deadline the countdown beeps and the wall number use (and round up like they do), so this
  -- row changes on the beep. The server-written whole-second BiomeRefreshSeconds is only the fallback.
  local endsAt=tonumber(map:GetAttribute('BiomeRefreshEndsAt'))
  if endsAt and endsAt==endsAt and endsAt<math.huge then left=math.max(0,math.ceil(endsAt-now))end
  left=left and math.max(0,math.ceil(left))or 0
 end
 local track={Title=closed and 'Track refreshing'or'Track resets',Caption=closed and(left>0 and'Reopens in'or'Reopening…')or(nextReset and'New packs in'or'Syncing…'),Time=S.Clock(left),Progress=left and math.clamp(left/(closed and Packs.RefreshClosedSeconds or Packs.RefreshInterval),0,1)or 0,Closed=closed,Left=left}
 return weather,track
end
return S
