-- R77: use the approved biome pack artwork without the added sun/jewel medallions.
-- Keep this shared entry point for world, held, dropped and opening pack renderers.
local E={}
function E.Specs(_key,_template)return {}end
function E.Build(_folder,_root,_key,_template,_scale)return 0 end
return E
