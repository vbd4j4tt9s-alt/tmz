-- R87 keeps existing illustration pixels and uploaded-ID overrides.
local Data=require(script.Parent.BiomeIconData)
local Runtime=require(script.Parent.ArtworkRuntime87)
local A={}
function A.Attach(parent,kind)
 local data=Data[kind];assert(data,'Unknown artwork')
 return Runtime.Attach(parent,kind,data,script:GetAttribute(kind..'ImageId'))
end
return A
