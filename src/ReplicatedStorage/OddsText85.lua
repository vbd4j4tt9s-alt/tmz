-- Display only: chances as 1/N.
local F={}
-- R148 (owner: "remove decimal points from the index; 1/6.3 is 1/6"): every number is whole, rounded to the nearest. From
-- 1,000 up it uses the largest of K/M/B/T/Qa that keeps it whole: 1/10K, $240K, 1/17B; under 10 of a unit it is written in
-- the unit below so it keeps 3 figures (1/1,250, 1/1,670M, $1,500K). Thousands separators inside the number.
local function commas(n)
 local s=string.format('%d',n);if #s<4 then return s end
 return(s:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))
end
local suffix={[0]='','K','M','B','T','Qa'}
function F.Count(n,floor)
 n=math.max(floor or 1,math.floor((tonumber(n)or 0)+.5))
 if n<1000 then return string.format('%d',n)end
 local group=math.clamp(math.floor(math.log10(n)/3),1,5)
 local v=n/1000^group
 if v<10 then group-=1;v=tonumber(string.format('%.3g',n/1000^group))or 0 end
 return commas(math.floor(v+.5))..suffix[group]
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
