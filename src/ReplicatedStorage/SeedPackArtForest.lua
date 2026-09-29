-- V120 native render index for Forest.
local out={}
for key,value in pairs(require(script.Parent.SeedPackArtForest01)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtForest02)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtForest03)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtForest04)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtForest05)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtForest06)) do out[key]=value end
return out