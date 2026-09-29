local RP=RS_MOD('RarePackRules')
local Rules=RS_MOD('SeedPackRules')
local acc={0,0,0,0,0,0}
for cycle=1,10 do local p=RP.TierProbabilities(cycle,35)
 local row={} for i,k in ipairs(Rules.VariantOrder) do acc[i]+=p[k]/10; row[i]=string.format('%.5f',p[k]) end
 print('MIX',cycle,table.concat(row,','))
end
local row={} for i=1,6 do row[i]=string.format('%.6f',acc[i]) end
print('MIXAVG',table.concat(row,','))
