-- V120 native render data wrapper for Snow_06.
local out={}
for _,component in ipairs(require(script.Parent.SeedPackArtSnow06A)) do out[#out+1]=component end
for _,component in ipairs(require(script.Parent.SeedPackArtSnow06B)) do out[#out+1]=component end
return {['Snow_06']=out}