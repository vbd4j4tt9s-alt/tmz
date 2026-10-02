-- R132 (owner): the Fruit of the Hour sells for 1.5x to 3x more for one hour. The pick follows the server clock
-- (workspace:GetServerTimeNow), so every server and client agrees without any messages: the hour picks one of the
-- obtainable fruits (not the same fruit as the hour before) and a bonus from x1.5 to x3.0 in 0.1 steps.
local RS=game:GetService('ReplicatedStorage')
local F={Seconds=3600,Min=1.5,Max=3.0}
local candidates
function F.Candidates()
 if candidates then return candidates end
 local Rules=require(RS:WaitForChild('SeedPackRules'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
 local out={}
 for _,spec in ipairs(Rules.SeedDesigns)do
  if Catalog[spec.id]and not Rules.IsRetired(spec.id)then table.insert(out,spec.id)end
 end
 table.sort(out);candidates=out;return out
end
-- Exact 32-bit multiply (plain doubles lose precision past 2^53), then a 32-bit integer mix -> [0, 1).
local function mul32(a,b)
 local lo,hi=a%65536,math.floor(a/65536)
 return(lo*b+(hi*b%65536)*65536)%4294967296
end
local function mix(n,salt)
 local x=(mul32(n%4294967296,2654435761)+salt*40503+12345)%4294967296
 x=bit32.bxor(x,bit32.rshift(x,15));x=mul32(x,2246822519)
 x=bit32.bxor(x,bit32.rshift(x,13));x=mul32(x,3266489917)
 x=bit32.bxor(x,bit32.rshift(x,16))
 return x/4294967296
end
local function pick(hour)
 local list=F.Candidates();local n=#list;if n==0 then return nil end
 -- Walk forward from a few hours back so a repeat is moved on (and the move itself never repeats the hour before).
 local last
 for h=hour-6,hour do
  local i=math.floor(mix(h,7)*n)+1
  if n>1 and i==last then i=i%n+1 end
  last=i
 end
 return list[last]
end
function F.Name(id)
 local spec=require(RS:WaitForChild('SeedPackRules')).SeedDesignById[id]
 return spec and spec.name or'Fruit'
end
-- Owner test (/test fruithour): ReplicatedStorage attribute FruitOfHourTest = 'SeedId:multiplier:endsAt' replaces the
-- pick until endsAt. It replicates, so clients show the same fruit the server pays for.
F.TestAttribute='FruitOfHourTest'
local function test(now)
 local raw=RS:GetAttribute(F.TestAttribute);if type(raw)~='string'then return nil end
 local id,m,ends=raw:match('^([%w_]+):([%d%.]+):(%d+)$');m=tonumber(m);ends=tonumber(ends)
 if not id or not m or not ends or now>=ends or not table.find(F.Candidates(),id)then return nil end
 return {SeedId=id,Multiplier=math.clamp(math.floor(m*10+.5)/10,F.Min,F.Max),Hour=math.floor(now/F.Seconds),StartsAt=now,EndsAt=ends,Name=F.Name(id),Test=true}
end
function F.SetTest(seedId,multiplier,now,seconds)
 if not seedId then RS:SetAttribute(F.TestAttribute,nil);return end
 RS:SetAttribute(F.TestAttribute,('%s:%.1f:%d'):format(seedId,multiplier,math.floor(now+(seconds or 600))))
end
-- The hour that contains `now` (server time, seconds).
function F.At(now)
 now=tonumber(now)or 0
 local forced=test(now);if forced then return forced end
 local hour=math.floor(now/F.Seconds)
 local id=pick(hour)
 local steps=math.floor((F.Max-F.Min)*10+.5)
 local multiplier=F.Min+math.floor(mix(hour,11)*(steps+1))/10
 return {SeedId=id,Multiplier=math.min(F.Max,multiplier),Hour=hour,StartsAt=hour*F.Seconds,EndsAt=(hour+1)*F.Seconds,Name=id and F.Name(id)or nil}
end
function F.Multiplier(seedId,now)
 local current=F.At(now);return current.SeedId==seedId and current.Multiplier or 1
end
-- What a harvest of this fruit sells for right now (whole cash).
function F.SaleValue(seedId,value,now)
 local m=F.Multiplier(seedId,now);if m==1 then return value end
 return math.floor(value*m+.5)
end
return F
