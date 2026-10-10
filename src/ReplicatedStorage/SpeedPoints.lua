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
-- R148 (owner: "the speed needed is in numbers, whole numbers and multiples of 5"): the keeper sign's number. `v` is
-- the exact points needed (a decimal string, or a number). RoundUp2 rounds it UP to 2 significant figures (so it is never
-- below the real need; values under 100 go up to the next multiple of 5), as exact decimal text of any size. NeedText
-- writes that whole, with thousands separators and the largest suffix that keeps the number whole (K M B T Qa ... Dc):
-- 3800 -> "3,800", 18000 -> "18K", 540000 -> "540K"; from a million up one decimal is allowed (R148): 1.2M, 16M, 2.6B, 22B;
-- "0" for nothing; "∞" from 10^36 on.
function P.RoundUp2(v)
 v=P.Normalize(v);local len=#v
 if len<=2 then return tostring(math.ceil(tonumber(v)/5)*5)end
 local lead=tonumber(v:sub(1,2));if v:sub(3):find('[1-9]')then lead+=1 end
 local zeros=len-2
 if lead>=100 then lead=10;zeros+=1 end
 return tostring(lead)..string.rep('0',zeros)
end
local NEED_SUFFIXES={'K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc'} -- 10^3 ... 10^33
local function withCommas(digits)return(digits:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))end
function P.NeedText(v)
 local r=P.RoundUp2(v);if #r>36 then return'∞'end
 if #r<=4 then return withCommas(r)end -- below 10,000: in full
 if #r>=7 then -- R148 (owner: "B or mil can have decimal points"): a million and up reads 1.2M, 16M, 2.6B, 22B
  local group=math.min(math.floor((#r-1)/3),#NEED_SUFFIXES);local first=#r-3*group
  local tenth=r:sub(first+1,first+1);return r:sub(1,first)..((tenth~=''and tenth~='0')and'.'..tenth or'')..NEED_SUFFIXES[group]
 end
 local zeros=#r-#(r:gsub('0+$',''))
 local group=math.min(math.floor(zeros/3),#NEED_SUFFIXES)
 return withCommas(r:sub(1,#r-3*group))..(NEED_SUFFIXES[group]or'')
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
