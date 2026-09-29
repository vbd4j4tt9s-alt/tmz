local A={};local Tags=game:GetService('CollectionService')
function A.Set(model,weather,mech,radius,height)
 local p=model:IsA('BasePart')and model or model.PrimaryPart
 if not p then return end
 p:SetAttribute('WeatherTrait',require(script.Parent.WeatherTraits).Key(weather))
 if mech~=nil then p:SetAttribute('MechFX',mech==true)end
 p:SetAttribute('EffectRadius',math.clamp(radius or 1,.2,45));p:SetAttribute('EffectHeight',math.clamp(height or 2,.2,70))
 Tags:AddTag(p,'GardenItemFX')
end
return A
