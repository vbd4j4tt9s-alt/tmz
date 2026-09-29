-- V120 native render index for Storm.
local out={}
for key,value in pairs(require(script.Parent.SeedPackArtStorm01)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtStorm02)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtStorm03)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtStorm04)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtStorm05)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtStorm06)) do out[key]=value end
return out