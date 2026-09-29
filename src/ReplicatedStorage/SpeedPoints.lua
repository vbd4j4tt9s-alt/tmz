-- R81: exact, non-negative whole points. Decimal strings are authoritative.
local P={}
function P.Valid(v)
 return type(v)=='string' and #v>0 and v:match('^%d+$')~=nil
end
function P.Normalize(v)
 if P.Valid(v)then local s=v:gsub('^0+','');return s~=''and s or'0'end
 if type(v)=='number'and v==v and v>=0 and v<math.huge then return string.format('%.0f',math.floor(v+.5))end
 return '0'
end
function P.Compare(a,b)
 a=P.Normalize(a);b=P.Normalize(b)
 if #a~=#b then return #a<#b and -1 or 1 end
 return a==b and 0 or a<b and -1 or 1
end
function P.Add(a,b)
 a=P.Normalize(a);b=P.Normalize(b);local out={};local i,j,carry=#a,#b,0
 while i>0 or j>0 or carry>0 do
  local n=(i>0 and a:byte(i)-48 or 0)+(j>0 and b:byte(j)-48 or 0)+carry
  out[#out+1]=string.char(48+n%10);carry=math.floor(n/10);i-=1;j-=1
 end
 return #out>0 and table.concat(out):reverse()or'0'
end
function P.Log10(v)
 v=P.Normalize(v);if v=='0'then return 0 end
 local n=math.min(14,#v)
 return #v-n+math.log10(tonumber(v:sub(1,n)))
end
function P.Exact(v)
 local s=P.Normalize(v):reverse():gsub('(%d%d%d)','%1,'):reverse()
 return(s:gsub('^,',''))
end
function P.Compact(v)
 v=P.Normalize(v);if #v<7 then return v end
 local suffixes={'','K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc'}
 local group=math.floor((#v-1)/3);local first=#v-group*3
 local lead=tonumber(v:sub(1,first));local tenth=tonumber(v:sub(first+1,first+1))or 0
 local text=tostring(lead)..(tenth>0 and'.'..tenth or'')
 return text..(suffixes[group+1]or('e'..tostring(group*3)))
end
function P.LegacyNumber(v,limit)
 v=P.Normalize(v);limit=limit or 1000000000
 return P.Compare(v,limit)>0 and limit or tonumber(v)
end
return P
