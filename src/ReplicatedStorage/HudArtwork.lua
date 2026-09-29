-- R87 keeps existing illustration pixels and uploaded-ID overrides.
local Data=require(script.Parent.HudIconData)
local Runtime=require(script.Parent.ArtworkRuntime87)
local A={}
function A.Attach(parent,kind)
 local data=kind:sub(1,7)=='Weather'and require(script.Parent.WeatherArtworkData89)[kind]or kind=='Gem'and require(script.Parent.GemArtworkData85).Gem or(kind=='GardenSize'or kind=='GardenTime'or kind=='NebulaSpark'or kind=='RoyalSpark')and require(script.Parent.GardenArtworkData84)[kind]or kind=='Clover'and require(script.Parent.LuckCloverData)or kind=='Moon'and require(script.Parent.RefreshMoonData)or kind=='City'and require(script.Parent.ShopCityData).City or(kind=='Bolt'or kind=='Money')and require(script.Parent.PremiumIconData)[kind]or Data[kind];assert(data,'Unknown artwork')
 return Runtime.Attach(parent,kind,data,script:GetAttribute(kind..'ImageId'))
end
return A
