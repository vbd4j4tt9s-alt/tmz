local Rules=require(game:GetService('ReplicatedStorage'):WaitForChild('PlantRules'))
local Info={}
function Info.From(crop,def)
 local name=require(script.Parent.HologramProjection).Name(crop,crop.FruitIndex)or def.HarvestName
 local weather=require(script.Parent.WeatherTraits).Key(crop.Weather)
 local mutation=Rules.Mutation(crop.Mutation);local size=Rules.Scale(crop.FruitScale or crop.PlantScale)
 local mutationMultiplier=mutation=='Diamond'and 3 or mutation=='Gold'and 2 or 1
 return {InventoryId=crop.Id,SeedId=crop.SeedId,Name=require(script.Parent.ItemTraitNames).Name(name,{Mutation=mutation,Weather=weather}),
  Weather=weather,WeatherMultiplier=require(script.Parent.WeatherTraits).Traits[weather].Multiplier,FruitName=name,Rarity=def.Rarity,Count=1,Mutation=mutation,FruitScale=size,SellValue=crop.Value,BaseValue=def.Value,
  MutationMultiplier=mutationMultiplier,SizeMultiplier=require(script.Parent.BalanceRules).SizeCash(size),CashMultiplier=crop.Value/def.Value,
  VisualCrop={SourceCropId=crop.SourceCropId or crop.Id,FruitIndex=crop.FruitIndex or 1,HarvestCycle=crop.HarvestCycle or 0}}
end
function Info.Key(tool)
 if tool:GetAttribute('GardenShovel')then return 'shovel'end
 return tool:GetAttribute('HarvestInventoryId')or tool:GetAttribute('SeedInventoryId')or tool:GetAttribute('LootInstanceName')
end
return Info
