-- Display only: chances as 1/N.
local F={}
-- R148 (owner: "remove decimal points from the index; 1/6.3 is 1/6" / "B or mil can have decimal points"): under a million
-- every number is whole, rounded to the nearest (1/6, 1/26, 1/1,250, 1/12K, $240K); from a million up M/B/T/Qa keep three
-- significant figures as before (1/1.67B, 1/16.7B, $1.5M). Thousands separators inside whole numbers.
local function commas(n)
 local s=string.format('%d',n);if #s<4 then return s end
 return(s:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))
end
function F.Count(n,floor)
 n=math.max(floor or 1,math.floor((tonumber(n)or 0)+.5))
 if n<1000 then return string.format('%d',n)end
 if n<1e4 then return commas(tonumber(string.format('%.3g',n)))end -- 1,250
 if math.floor(n/1000+.5)<1000 then return commas(math.floor(n/1000+.5))..'K'end -- 12K, 240K
 local suffix={'K','M','B','T','Qa'};local group=math.clamp(math.floor(math.log10(n)/3),2,5)
 local v=tonumber(string.format('%.3g',n/1000^group))or 0
 if v>=1000 and group<5 then group+=1;v/=1000 end
 return string.format('%g',v)..suffix[group]
end
function F.Whole(n)return F.Count(n,0)end
-- R136 (owner: "make it so that it's always a 1/... format"): every chance reads 1/N; R148: N is always whole (see Count).
function F.Format(percent)
 if type(percent)~='number'or percent~=percent or percent<=0 or percent==math.huge then return '—'end
 return '1/'..F.Count(1/(math.min(percent,100)/100))
end
function F.Percent(percent)
 if percent==.5 then return '½%'elseif percent==2.5 then return '2½%'end
 return string.format('%.0f%%',percent)
end
return F
