-- V120 native render index for Desert.
local out={}
for key,value in pairs(require(script.Parent.SeedPackArtDesert01)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtDesert02)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtDesert03)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtDesert04)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtDesert05)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtDesert06)) do out[key]=value end
return out