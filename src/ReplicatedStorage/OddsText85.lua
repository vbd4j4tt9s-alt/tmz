-- Display only: chances as 1/N.
local F={}
-- R112: denominators from a million up read 1/1M, 1/16.7B, 1/1T (three significant figures).
function F.Count(n)
 if n<1e6 then return string.format('%.0f',n)end
 local suffix={'K','M','B','T','Qa'};local group=math.clamp(math.floor(math.log10(n)/3),2,5)
 local v=tonumber(string.format('%.3g',n/1000^group))or 0
 if v>=1000 and group<5 then group+=1;v/=1000 end
 return string.format('%g',v)..suffix[group]
end
-- R136 (owner: "make it so that it's always a 1/... format"): every chance reads 1/N. N keeps one decimal below 10
-- (1/3.1), is a whole number up to a million (1/26, 1/30, 1/10000) and uses K/M/B/T above that (1/16.7B).
function F.Format(percent)
 if type(percent)~='number'or percent~=percent or percent<=0 or percent==math.huge then return '—'end
 local reciprocal=1/(math.min(percent,100)/100)
 if reciprocal<9.95 then
  local n=math.floor(reciprocal*10+.5)/10
  return '1/'..(n%1==0 and string.format('%d',n)or string.format('%.1f',n))
 end
 return '1/'..F.Count(math.floor(reciprocal+.5))
end
function F.Percent(percent)
 if percent==.5 then return '½%'elseif percent==2.5 then return '2½%'end
 return string.format('%.0f%%',percent)
end
return F
