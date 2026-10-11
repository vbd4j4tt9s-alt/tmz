-- Display only. Never round, abbreviate or replace the stored balance.
local Numbers = {}
local function balance(value)
    local n = tonumber(value) or 0
    if n ~= n or n == math.huge or n == -math.huge then return 0 end
    return math.floor(math.max(0, n))
end
function Numbers.Exact(value)
    if type(value)=='string'and require(script.Parent.SpeedPoints).Valid(value)then return require(script.Parent.SpeedPoints).Exact(value)end
    local text = string.format('%.0f', balance(value))
    local grouped = text:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return (grouped:gsub('^,', ''))
end
function Numbers.Compact(value)
    if type(value)=='string'and require(script.Parent.SpeedPoints).Valid(value)then return require(script.Parent.SpeedPoints).Compact(value)end
    local n = balance(value)
    if n < 1000000 then return string.format('%.0f', n) end
    if n>=1000000000000 then
        local divisor,suffix=n>=1000000000000000 and 1000000000000000 or 1000000000000,n>=1000000000000000 and 'Qa'or'T'
        return(string.format('%.1f',n/divisor):gsub('%.0$',''))..suffix
    end
    local suffix, divisor = 'M', 1000000
    if n >= 1000000000 then suffix, divisor = 'B', 1000000000 end
    local rounded = math.floor(n / divisor * 10 + .5) / 10
    if rounded >= 1000 then suffix, rounded = suffix=='M'and'B'or'T',1 end
    return (string.format('%.1f', rounded):gsub('%.0$', '')) .. suffix
end
-- R158k: Compact rounds to the nearest tenth both ways, so $10,350,000 read "$10.4M" beside a $10.4M price the player could not pay. A player's own
-- money is shown with Balance (rounded DOWN: never more than it is) and a price with Price (never rounded: see below), so a shown balance at
-- or over a shown price can always pay it. Compact's look: exact digits under a million, then M / B / T / Qa with one decimal, or two when the number
-- before the point is one digit ($5.48B, $1.56T), so every price in the game reads exactly and exactly that much money reads the same.
-- (owner: "make sure store prices are always the same") A price is never rounded at all: when the short form would not be exact it is written in
-- full ($10,350,001), so the price on a button is always the very number the server charges.
local SUFFIXES={'M','B','T','Qa'}
local function commas(digits)return(digits:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))end
local function rounded(value,up)
    local digits
    if type(value)=='string'and require(script.Parent.SpeedPoints).Valid(value)then digits=require(script.Parent.SpeedPoints).Normalize(value)
    else
        local n=tonumber(value)or 0
        if n~=n or n==math.huge or n==-math.huge or n<=0 then n=0 end
        digits=string.format('%.0f',up and math.ceil(n)or math.floor(n))
    end
    if #digits<=6 then return digits end
    local group=math.min(#SUFFIXES,math.floor((#digits-1)/3)-1) -- 1 = M (millions) ... 4 = Qa (and Qa above it, as Compact)
    local cut=#digits-3*(group+1)
    local places=cut==1 and 2 or 1
    local scaled=tonumber(digits:sub(1,cut+places))
    if up and digits:sub(cut+places+1):find('[1-9]')then return commas(digits)end -- (a price the short form cannot write exactly: in full)
    local unit=10^places;local whole,frac=math.floor(scaled/unit),scaled%unit
    if whole>=1000 and group<#SUFFIXES then group+=1;whole,frac=1,0 end
    return tostring(whole)..(frac>0 and'.'..(string.format('%0'..places..'d',frac):gsub('0+$',''))or'')..SUFFIXES[group]
end
function Numbers.Balance(value)return rounded(value,false)end
function Numbers.Price(value)return rounded(value,true)end
-- R158k: true when a short money text ("11.9M", "250K", "6.1T", "5.48B", "$1,200", "750000") reads exactly `value` (whole), e.g. a sign's price before it is shown.
local EXP={K=3,M=6,B=9,T=12,Qa=15}
function Numbers.Reads(text,value)
    if type(text)~='string'then return false end
    local whole,frac,suffix=text:gsub('[%$,%s]',''):match('^(%d+)%.?(%d*)(%a*)$')
    local exp=suffix==''and 0 or EXP[suffix]
    if not whole or not exp or #frac>exp then return false end
    local shown=(whole..frac..string.rep('0',exp-#frac)):gsub('^0+','');if shown==''then shown='0'end
    local n=tonumber(value)
    local real=type(value)=='string'and require(script.Parent.SpeedPoints).Valid(value)and require(script.Parent.SpeedPoints).Normalize(value)
        or(n and n==n and n>=0 and n<math.huge and n%1==0 and string.format('%.0f',n))
    return real==shown
end
-- Only for Roblox's narrow PlayerList cells. Gameplay and wallet text use the
-- untouched exact value and formatters above, never these rounded strings.
function Numbers.PlayerList(value)
    local points=require(script.Parent.SpeedPoints)
    local digits=type(value)=='string'and points.Valid(value)and points.Normalize(value)
        or string.format('%.0f',balance(value))
    if #digits<=3 then return digits end
    local suffixes={'','K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc'}
    local group=math.floor((#digits-1)/3)
    if group<#suffixes then
        local head=#digits-group*3
        local tenths=tonumber(digits:sub(1,head))*10+(tonumber(digits:sub(head+1,head+1))or 0)
        if(tonumber(digits:sub(head+2,head+2))or 0)>=5 then tenths+=1 end
        if tenths>=10000 then group+=1;tenths=10 end
        if group<#suffixes then
            return tostring(math.floor(tenths/10))..(tenths%10>0 and'.'..tostring(tenths%10)or'')..suffixes[group+1]
        end
    end
    local exponent=#digits-1
    if exponent>=10000 then return '>1e9999'end
    local tenths=tonumber(digits:sub(1,2))or 10
    if(tonumber(digits:sub(3,3))or 0)>=5 then tenths+=1 end
    if tenths>=100 then tenths=10;exponent+=1 end
    if exponent>=10000 then return '>1e9999'end
    local lead=tostring(math.floor(tenths/10))
    if tenths%10>0 and #tostring(exponent)<=3 then lead..='.'..tostring(tenths%10)end
    return lead..'e'..tostring(exponent)
end
return Numbers
