local N={WeatherDuration=2,RareDuration=6}
function N.WeatherName(kind)
 if kind=='Rain'or kind=='Thunderstorm'or kind=='Blizzard'then return kind end
end
function N.Transparency(age,duration)
 return math.max(1-math.clamp(age/.12,0,1),math.clamp((age-(duration-.35))/.35,0,1))
end
return N
