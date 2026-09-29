-- Small replicated descriptions survive world streaming. They contain no player inventory.
local V={};V.Keys={'CropId','SeedId','GardenOwnerId','PlantScale','SeedScale','Mutation','Weather','PlantedAt','MatureAt','ReadyAt','HarvestCycle','PickedMask','FruitReady','FruitGrowing','GrowthStage','FruitRevision'}
function V.Read(snapshot)
 local crop={Id=snapshot:GetAttribute('CropId'),SeedId=snapshot:GetAttribute('SeedId'),FruitStates={}}
 for _,key in ipairs(V.Keys)do if key~='CropId'then crop[key]=snapshot:GetAttribute(key)end end
 for index=1,6 do local at=snapshot:GetAttribute('FruitReadyAt'..index);if at then crop.FruitStates[tostring(index)]={ReadyAt=at,Cycle=snapshot:GetAttribute('FruitCycle'..index)or crop.HarvestCycle or 0,Duration=snapshot:GetAttribute('FruitDuration'..index)}end end
 crop.FruitWeather={}
 for index=1,6 do local kind=snapshot:GetAttribute('FruitWeather'..index);if kind and kind~='None'then crop.FruitWeather[tostring(index)]={Kind=kind,Cycle=snapshot:GetAttribute('FruitCycle'..index)or crop.HarvestCycle or 0,Event=0}end end
 if not next(crop.FruitStates)then crop.FruitStates=nil end
 return crop
end
function V.Key(item)return tostring(item:GetAttribute('CropId'))end
return V
