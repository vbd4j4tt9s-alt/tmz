-- V120 native render index for Lava.
local out={}
for key,value in pairs(require(script.Parent.SeedPackArtLava01)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtLava02)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtLava03)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtLava04)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtLava05)) do out[key]=value end
for key,value in pairs(require(script.Parent.SeedPackArtLava06)) do out[key]=value end
return out