-- Display only: reduced fractions with whole-number numerators and denominators.
local F={}
-- R112: denominators from a million up read 1/1M, 1/16.7B, 1/1T (three significant figures).
function F.Count(n)
 if n<1e6 then return string.format('%.0f',n)end
 local suffix={'K','M','B','T','Qa'};local group=math.clamp(math.floor(math.log10(n)/3),2,5)
 local v=tonumber(string.format('%.3g',n/1000^group))or 0
 if v>=1000 and group<5 then group+=1;v/=1000 end
 return string.format('%g',v)..suffix[group]
end
function F.Format(percent)
 if type(percent)~='number'or percent~=percent or percent<=0 or percent==math.huge then return '—'end
 local p=math.min(percent,100)/100;local reciprocal=1/p;local unit=math.floor(reciprocal+.5)
 if unit<=1e15 and math.abs(reciprocal-unit)<=1e-10*math.max(1,unit)then return '1/'..F.Count(unit)end
 local x=p;local a0,a1,b0,b1=0,1,1,0
 for _=1,32 do
  local a=math.floor(x);local n,d=a*a1+a0,a*b1+b0
  if d>1e9 or n>1e15 then break end
  a0,a1,b0,b1=a1,n,b1,d
  if n>0 and math.abs(n/d-p)<1e-12 then return string.format('%.0f/%.0f',n,d)end
  local f=x-a;if f<1e-14 then break end;x=1/f
 end
 if b1>0 and a1>0 then return '≈'..string.format('%.0f/%.0f',a1,b1)end
 return '≈1/'..F.Count(unit)
end
function F.Percent(percent)
 if percent==.5 then return '½%'elseif percent==2.5 then return '2½%'end
 return string.format('%.0f%%',percent)
end
return F
