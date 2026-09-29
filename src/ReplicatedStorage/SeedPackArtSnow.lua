-- V120 native render index for Snow.
local out={}
for key,value in pairs(require(script.Parent.SeedPackArtSnow01)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtSnow02)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtSnow03)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtSnow04)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtSnow05)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtSnow06)) do out[key]=value end
return out