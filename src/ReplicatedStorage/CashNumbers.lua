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
