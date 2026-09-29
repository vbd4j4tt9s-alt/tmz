-- V120 native render index for Crystal.
local out={}
for key,value in pairs(require(script.Parent.SeedPackArtCrystal01)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtCrystal02)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtCrystal03)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtCrystal04)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtCrystal05)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtCrystal06)) do out[key]=value end
return out