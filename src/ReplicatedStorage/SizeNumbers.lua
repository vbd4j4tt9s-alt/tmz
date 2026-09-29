-- New rolled multipliers and player-facing sale traits use whole/half units.
local N={Max=25}
function N.Half(value)
 if type(value)~='number'or value~=value or math.abs(value)==math.huge then return 1 end
 return math.clamp(math.floor(value*2+.5)/2,.5,N.Max)
end
function N.Format(value)
 local n=type(value)=='number'and value==value and math.abs(value)<math.huge and math.max(.5,math.floor(value*2+.5)/2)or 1
 return n%1==0 and string.format('%.0f',n)or string.format('%.1f',n)
end
return N
