-- R58. A shared server clock keeps projection poses and harvest reach in agreement.
local Rules=require(script.Parent.PlantRules)
local Cache=require(script.Parent.PlantPartCache)
local H={};local caches=setmetatable({},{__mode='k'})
local names={HoloMelonSeed={'Holo Melon','Holo Cantaloupe','Holo Pumpkin'},HoloAppleTreeSeed={'Holo Apple','Holo Pear','Holo Orange'}}
function H.Is(id)return names[id]~=nil end
function H.Form(crop,index)return Rules.FruitCycle(crop or{},index or 1)%3 end
function H.Name(crop,index)local list=names[crop.SeedId];return list and list[H.Form(crop,index)+1]end
function H.Key(id,crop)
 if not H.Is(id)then return ''end
 local keys={id};for i=1,id=='HoloMelonSeed'and 1 or 4 do keys[#keys+1]=tostring(H.Form(crop,i))end
 return table.concat(keys,':')
end
function H.Turn(crop,now)
 if not H.Is(crop.SeedId)or crop._DetachedHarvest then return CFrame.new()end
 local period=crop.SeedId=='HoloMelonSeed'and 48 or 90
 -- Modulo avoids large-angle precision loss; planted time preserves rotation across rebuilds/rejoins.
 local t=((now or workspace:GetServerTimeNow())-(crop.PlantedAt or 0))%period
 return CFrame.Angles(0,t/period*math.pi*2,0)
end
function H.Point(crop,point,now)return H.Turn(crop,now):PointToWorldSpace(point)end
function H.Apply(model,crop,origin,now,batch)
 if not model or not model.Parent or not H.Is(crop.SeedId)or crop._DetachedHarvest then return 0 end
 local cache=caches[model]
 if not cache or cache.Dead then cache=Cache.new(model,function(p)return p:GetAttribute('HologramFrame')~=nil end);caches[model]=cache end
 local pose=origin*H.Turn(crop,now);local count=0
 for _,p in ipairs(cache:List())do if p.Parent and p.Transparency<1 and(p.LocalTransparencyModifier or 0)<1 then
  local home=p:GetAttribute('HologramFrame');if home then
   local cf=pose*home;if batch then batch:Set(p,cf)else p.CFrame=cf end;count+=1
  end
 end end
 return count
end
function H.Prompts(model,crop,origin,now,visuals)
 local groups=model and model:FindFirstChild('FruitPrompts');if not groups or not H.Is(crop.SeedId)then return end
 local def=require(script.Parent.PlantCatalog)[crop.SeedId]
 for _,g in ipairs(groups:GetChildren())do
  local index=g:GetAttribute('HarvestIndex');local p=index and g:FindFirstChild('Fruit_'..index)
  if p then p.CFrame=origin*CFrame.new(visuals.FruitPosition(crop,def,index,now))end
 end
end
return H
