-- R98: weather layers stack independently of the Gold/Diamond material coat.
local B=require(script.Parent.BalanceRules)
local W={Interval=900,Duration=180,PackChance=B.WeatherPackChance,FruitChance=B.WeatherFruitChance,PlantChance=B.WeatherPlantChance,InheritanceChance=B.WeatherInheritance}
W.Order={'Drippy','Frosted','Charged'}
-- R118: Drippy x2, Frosted x3, Charged x5; stacked weathers multiply (Drippy+Frosted+Charged = x30).
W.Traits={None={Rank=0,Multiplier=1},Drippy={Rank=1,Multiplier=2,Color=Color3.fromRGB(90,197,255)},Frosted={Rank=2,Multiplier=3,Color=Color3.fromRGB(202,241,255)},Charged={Rank=3,Multiplier=5,Color=Color3.fromRGB(177,144,255)}}
-- Keep indexed metadata compatible with every existing inventory, preview and sale path.
for mask=1,7 do
 local list={};local multiplier,rank,color=1,0,nil
 for index,key in ipairs(W.Order)do if bit32.band(mask,2^(index-1))~=0 then
  local trait=W.Traits[key];list[#list+1]=key;multiplier*=trait.Multiplier;rank=trait.Rank;color=trait.Color
 end end
 local key=table.concat(list,'+');if not W.Traits[key]then W.Traits[key]={Rank=rank,Multiplier=multiplier,Color=color}end
end
W.Events={Rain='Drippy',Thunderstorm='Charged',Blizzard='Frosted'}
local function canonical(value)
 if value==nil or value=='None'then return 'None'end
 if type(value)~='string'or #value>24 or value==''then return nil end
 if W.Traits[value]then return value end
 local seen={};for _,key in ipairs(string.split(value,'+'))do
  if not table.find(W.Order,key)or seen[key]then return nil end;seen[key]=true
 end
 local list={};for _,key in ipairs(W.Order)do if seen[key]then list[#list+1]=key end end
 return #list>0 and table.concat(list,'+')or nil
end
function W.Key(value)return canonical(value)or'None'end
function W.Valid(value)return canonical(value)~=nil end
function W.CheckedEvent(value)
 if type(value)~='string'or #value>24 then return nil end
 local raw,trait=value:match('^(-?%d+):(%a+)$');local cycle=tonumber(raw)
 if not cycle or raw=='-0' or cycle%1~=0 or math.abs(cycle)>1000000000 or tostring(cycle)~=raw or not table.find(W.Order,trait)then return nil end
 return value
end
function W.List(value)local key=W.Key(value);return key=='None'and{}or string.split(key,'+')end
function W.Count(value)return #W.List(value)end
function W.Display(value)return table.concat(W.List(value),' + ')end
function W.Has(value,trait)return table.find(W.List(value),trait)~=nil end
function W.Merge(a,b)
 local seen={};for _,key in ipairs(W.List(a))do seen[key]=true end;for _,key in ipairs(W.List(b))do seen[key]=true end
 local list={};for _,key in ipairs(W.Order)do if seen[key]then list[#list+1]=key end end
 return #list>0 and table.concat(list,'+')or'None'
end
function W.Roll(identity,salt)
 local h=104729;local s=tostring(identity)..'/'..tostring(salt)
 for i=1,#s do h=(h*131+s:byte(i))%2147483647 end
 for _=1,4 do h=(h*48271)%2147483647 end
 return h/2147483647
end
function W.Schedule(now)
 local cycle=math.floor(now/W.Interval);local start=cycle*W.Interval;local roll=W.Roll(cycle,'weather-event')
 local kind=roll<.4 and'Rain'or roll<.7 and'Thunderstorm'or'Blizzard'
 return now-start<W.Duration and kind or'Clear',cycle,start+W.Duration,start+W.Interval
end
local catalog
function W.Fruit(crop,index,cycle)
 if crop._DetachedHarvest then return W.Key(crop.Weather)end
 catalog=catalog or require(script.Parent.PlantCatalog)
 local def=catalog[crop.SeedId];local inherit='None';local traits=W.List(crop.Weather)
 if def and def.Mode=='whole'then
  -- The harvested plant is the same object, not a separately inherited fruit.
  inherit=W.Key(crop.Weather)
 else
  -- Preserve the original stable 20% inheritance roll for the parent's weather stack.
  if #traits>0 and W.Roll(crop.Id,'inherit-weather:'..cycle..':'..index)<W.InheritanceChance then inherit=W.Key(crop.Weather)end
 end
 local applied=crop.FruitWeather and crop.FruitWeather[tostring(index)]
 if applied and applied.Cycle==cycle then inherit=W.Merge(inherit,applied.Kind)end
 return inherit
end
function W.ValidCrop(crop,count)
 if not W.Valid(crop.Weather)then return false end
 if crop.FruitWeather==nil then return true end
 if type(crop.FruitWeather)~='table'then return false end
 for key,v in pairs(crop.FruitWeather)do
  local n=type(key)=='string'and tonumber(key)
  if not n or n%1~=0 or n<1 or n>(count or 6)or tostring(n)~=key or type(v)~='table'then return false end
  if not W.Valid(v.Kind)or v.Kind==nil or v.Kind=='None'or type(v.Cycle)~='number'or v.Cycle%1~=0 or v.Cycle<0 or v.Cycle>1000000000 then return false end
  if type(v.Event)~='number'or v.Event%1~=0 or math.abs(v.Event)>1000000000 then return false end
 end
 return true
end
function W.Price(base,mutation,size,weather)
 local multiplier=B.CashMultiplier(size,mutation,W.Traits[W.Key(weather)].Multiplier)
 return math.max(1,math.ceil(base*multiplier)),multiplier
end
return W
