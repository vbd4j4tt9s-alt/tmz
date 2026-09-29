local A={}
local Shared=require(script.Parent.SpecialPackArt89)
function A.Specs()return Shared.Specs('EclipseReliquary')end
function A.Bounds(scale)return Shared.Bounds('EclipseReliquary',scale)end
function A.Build(bag)return Shared.Build(bag,'EclipseReliquary')end
return A
