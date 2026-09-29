-- V141: pure server-authoritative growth/fruit rules. Rolls depend on saved identity,
-- so previewing, failed placement, reconnecting and harvesting cannot reroll them.
local Weather=require(script.Parent.WeatherTraits)
local R={Version=141,SchemaVersion=7,MaxPlantScale=25,MaxFruitScale=25,MutationChance=require(script.Parent.BalanceRules).MutationInheritance}
local function finite(v)return type(v)=='number' and v==v and math.abs(v)<math.huge end
function R.Scale(v,max) return finite(v) and math.clamp(v,.35,max or 25) or 1 end
function R.Mutation(v)return (v=='Gold' or v=='Diamond')and v or 'None'end
function R.Roll(identity,salt)
 local h=104729
 local s=tostring(identity)..'/'..tostring(salt)
 for i=1,#s do h=(h*131+s:byte(i))%2147483647 end
 -- A final avalanche avoids correlated adjacent fruit/cycle identifiers.
 for _=1,4 do h=(h*48271)%2147483647 end
 return h/2147483647
end
function R.PlantScale(seedScale,unit)return require(script.Parent.BalanceRules).PlantScale(seedScale,unit)end
function R.NewCrop(seed,id,definition,now,x,z)
 local size=R.Scale(seed.SeedScale,25)
 return {Id=id,SeedId=seed.SeedId,PlantedAt=now,ReadyAt=now+definition.Seconds,
  MatureAt=now+definition.Seconds,Value=definition.Value,OffsetX=x,OffsetZ=z,
  PaidRandom=seed.PaidRandom==true,SeedScale=size,PlantScale=R.PlantScale(size,R.Roll(seed.Id,'plant-size')),
  Mutation=R.Mutation(seed.PackMutation),Weather=Weather.Key(seed.Weather),HarvestCycle=0,PickedMask=0,TraitVersion=1}
end
function R.Migrate(crop)
 if crop.TraitVersion==nil then
  crop.SeedScale=1;crop.PlantScale=1;crop.Mutation='None'
  crop.MatureAt=crop.ReadyAt;crop.HarvestCycle=0;crop.PickedMask=0;crop.TraitVersion=1
 end
 return crop
end
local function validFruitState(crop,count)
 if crop.FruitStates==nil then return true end
 if type(crop.FruitStates)~='table'or not finite(crop.MatureAt)then return false end
 for key,state in pairs(crop.FruitStates)do
  local index=type(key)=='string'and tonumber(key)
  if not index or index%1~=0 or index<1 or index>(count or 6)or tostring(index)~=key or type(state)~='table'then return false end
  if not finite(state.ReadyAt)or state.ReadyAt%1~=0 or state.ReadyAt<crop.MatureAt or state.ReadyAt>7258118400 then return false end
  if state.Duration~=nil and(not finite(state.Duration)or state.Duration%1~=0 or state.Duration<1 or state.Duration>86400)then return false end
  if not finite(state.Cycle)or state.Cycle%1~=0 or state.Cycle<0 or state.Cycle>1000000000 then return false end
 end
 for index=1,(count or 6)do if not crop.FruitStates[tostring(index)]then return false end end
 return true
end
function R.ValidTraits(crop,count)
 -- Old five-fruit Dune saves remain byte-preserved. Only slot 1 is now visible/harvestable.
 -- Validate the complete historical shape instead of discarding old readiness metadata.
 if crop.SeedId=='StarfruitSeed'and count==1 and ((type(crop.FruitStates)=='table'and crop.FruitStates['5']~=nil)or(type(crop.PickedMask)=='number'and crop.PickedMask>1))then count=5 end
 return Weather.ValidCrop(crop,count)and (crop.GrowthRate==nil or crop.GrowthRate==1 or crop.GrowthRate==2)and validFruitState(crop,count) and crop.TraitVersion==1 and finite(crop.SeedScale)and crop.SeedScale>=.35 and crop.SeedScale<=25
  and finite(crop.PlantScale)and crop.PlantScale>=.35 and crop.PlantScale<=50
  and R.Mutation(crop.Mutation)==crop.Mutation
  and finite(crop.MatureAt)and crop.MatureAt%1==0 and crop.MatureAt>crop.PlantedAt and crop.MatureAt<=crop.ReadyAt
  and finite(crop.HarvestCycle)and crop.HarvestCycle%1==0 and crop.HarvestCycle>=0 and crop.HarvestCycle<=1000000000
  and finite(crop.PickedMask)and crop.PickedMask%1==0 and crop.PickedMask>=0 and crop.PickedMask<2^(count or 6)
  and (crop.FruitScale==nil or(finite(crop.FruitScale)and crop.FruitScale>=.35 and crop.FruitScale<=50))
end
function R.IsPicked(crop,index)return bit32.band(crop.PickedMask or 0,bit32.lshift(1,index-1))~=0 end
-- Weak crop keys release automatically. Return fresh values so callers cannot poison the cache.
local fruitCache=setmetatable({},{__mode='k'})
function R.Fruit(crop,index,definition)
 local state=crop.FruitStates and crop.FruitStates[tostring(index)]
 local cycle=state and state.Cycle or crop.HarvestCycle or 0
 local weather=Weather.Fruit(crop,index,cycle)
 -- Current growing plants earn current rates; harvested inventory keeps its saved Value.
 local baseValue=definition.Value
 local records=fruitCache[crop];local cached=records and records[index]
 if cached and cached.Id==crop.Id and cached.Cycle==cycle and cached.Seed==crop.SeedScale and cached.Plant==crop.PlantScale and cached.Coat==crop.Mutation and cached.Mode==definition.Mode and cached.BaseValue==baseValue and cached.Weather==weather then
  return {Scale=cached.Scale,Mutation=cached.Mutation,Value=cached.Value,Weather=weather}
 end
 local salt=tostring(cycle)..':'..index
 local seed=R.Scale(crop.SeedScale,25);local plant=R.Scale(crop.PlantScale)
 local cap=math.min(25,math.max(.7,plant*1.25+seed*.3))
 local bias=math.min(2,1+seed*.025+math.sqrt(plant)*.025)
 local ticket=R.Roll(crop.Id,'fruit-size:'..salt)/bias
 local gain=ticket<.01 and 1.5 or ticket<.05 and 1.25 or .9+R.Roll(crop.Id,'fruit-base:'..salt)*.2
 -- Repeat harvests need a range wide enough to survive half-step rounding at 1x.
 -- The saved slot/cycle is the roll identity; viewing or rejoining cannot reroll it.
 if cycle>0 and definition.Regrows~=false and definition.Mode~='whole'then
  gain=ticket<.01 and 1.75 or ticket<.05 and 1.5 or .6+R.Roll(crop.Id,'fruit-base:'..salt)*.8
 end
 local scale=require(script.Parent.SizeNumbers).Half(math.clamp(plant*gain,.35,cap))
 local mutation=R.Mutation(crop.Mutation)
 if mutation~='None'and R.Roll(crop.Id,'fruit-mutation:'..salt)>=R.MutationChance then mutation='None'end
 if definition.Mode=="whole" then scale=plant;mutation=R.Mutation(crop.Mutation)end
 local value=Weather.Price(baseValue,mutation,require(script.Parent.BalanceRules).SizeCash(scale),weather)
 if not records then records={};fruitCache[crop]=records end
 records[index]={Id=crop.Id,Cycle=cycle,Seed=crop.SeedScale,Plant=crop.PlantScale,Coat=crop.Mutation,Mode=definition.Mode,BaseValue=baseValue,Scale=scale,Mutation=mutation,Value=value,Weather=weather}
 return {Scale=scale,Mutation=mutation,Value=value,Weather=weather}
end
function R.FruitReadyAt(crop,index)
 local state=crop.FruitStates and crop.FruitStates[tostring(index)];return state and state.ReadyAt or crop.ReadyAt or 0
end
function R.FruitCycle(crop,index)
 local state=crop.FruitStates and crop.FruitStates[tostring(index)];return state and state.Cycle or crop.HarvestCycle or 0
end
function R.FruitReady(crop,index,now)
 return now>=(crop.MatureAt or 0)and now>=R.FruitReadyAt(crop,index)and not R.IsPicked(crop,index)
end
function R.HasGrowingFruit(crop,definition,now)
 for index=1,definition.FruitCount do if not R.IsPicked(crop,index)and now<R.FruitReadyAt(crop,index)then return true end end
 return false
end
function R.EnableFruitRegrowth(crop,definition,now)
 if definition.Mode=='whole'or definition.Regrows==false or crop.FruitStates then return false end
 crop.FruitStates={}
 for index=1,definition.FruitCount do
  local picked=R.IsPicked(crop,index)
  crop.FruitStates[tostring(index)]={ReadyAt=picked and math.max(crop.MatureAt,now+definition.RegrowSeconds)or crop.ReadyAt,Cycle=(crop.HarvestCycle or 0)+(picked and 1 or 0)}
 end
 crop.PickedMask=0;return true
end
function R.FinishFruit(crop,definition,index,now,fenceTier)
 if definition.Mode=='whole'then return true end
 if definition.Regrows==false then
  crop.PickedMask=bit32.bor(crop.PickedMask or 0,bit32.lshift(1,index-1))
  return crop.PickedMask==2^definition.FruitCount-1
 end
 R.StartFruitRegrowth(crop,definition,index,now,fenceTier);return false
end
function R.StartFruitRegrowth(crop,definition,index,now,fenceTier)
 if definition.Regrows==false or definition.Mode=='whole'then return end
 R.EnableFruitRegrowth(crop,definition,now)
 local state=crop.FruitStates[tostring(index)];state.Duration=fenceTier and fenceTier>1 and require(game:GetService('ReplicatedStorage'):WaitForChild('GardenFenceRules')).Duration(definition.RegrowSeconds,fenceTier)or nil;state.Duration=math.max(1,math.ceil((state.Duration or definition.RegrowSeconds)/(crop.GrowthRate or 1)));state.ReadyAt=now+state.Duration;state.Cycle=(state.Cycle+1)%1000000000
 if crop.FruitWeather then crop.FruitWeather[tostring(index)]=nil end
 local earliest=math.huge;for _,fruit in pairs(crop.FruitStates)do earliest=math.min(earliest,fruit.ReadyAt)end
 crop.ReadyAt=earliest
end
function R.NextFruit(crop,definition,now)
 for i=1,definition.FruitCount do if not R.IsPicked(crop,i)and(not now or R.FruitReady(crop,i,now))then return i end end
 return nil
end
function R.Growth(crop,now)
 local endAt=crop.MatureAt or crop.ReadyAt
 local progress=math.clamp((now-crop.PlantedAt)/math.max(1,endAt-crop.PlantedAt),0,1)
 return progress,progress>=1 and 4 or progress>=.66 and 3 or progress>=.33 and 2 or 1,math.max(0,math.ceil(crop.ReadyAt-now))
end
return R
