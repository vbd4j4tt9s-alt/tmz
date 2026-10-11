-- R127 (owner): when weather mutates a seed pack, that pack glows in the weather's colour for every player; when it
-- mutates a plant or fruit, its owner sees it outlined in rainbow neon with a label naming it, and the notice names the plant.
-- Shared by WeatherService (server), MutationHighlights (client) and NoticeCopy83.
local W=require(script.Parent.WeatherTraits)
local G={Version=127,Name='MutationGlow',Tag='MutationGlow',PackSeconds=20,PlantSeconds=12,FadeSeconds=1.2,MaxItems=16,MaxLocal=12,MaxFruits=6,MaxPackGlows=16}
function G.Color(trait)local row=W.Traits[W.Key(trait)];return row and row.Color or Color3.new(1,1,1)end
-- Rainbow neon: full saturation hues cycling about once every 2.5 s; the outline runs half a turn ahead.
function G.Rainbow(t,offset)return Color3.fromHSV(((t or 0)*.4+(offset or 0))%1,.9,1)end
-- Sanitise one owner notice item {CropId,SeedId,Plant,Fruits}; catalog is PlantCatalog. Returns a clean copy or nil.
function G.Item(item,catalog)
 if type(item)~='table'or type(item.CropId)~='string'or #item.CropId<1 or #item.CropId>80 then return nil end
 if type(item.SeedId)~='string'or #item.SeedId>80 or(catalog and not catalog[item.SeedId])then return nil end
 local fruits={}
 if type(item.Fruits)=='table'then for _,i in ipairs(item.Fruits)do
  if type(i)=='number'and i==i and i%1==0 and i>=1 and i<=G.MaxFruits and not table.find(fruits,i)then table.insert(fruits,i)end
  if #fruits>=G.MaxFruits then break end
 end end
 local plant=item.Plant==true
 if not plant and #fruits==0 then return nil end
 return {CropId=item.CropId,SeedId=item.SeedId,Plant=plant,Fruits=fruits}
end
function G.Items(list,catalog)
 local out={};if type(list)~='table'then return out end
 for _,item in ipairs(list)do local clean=G.Item(item,catalog);if clean then table.insert(out,clean)end;if #out>=G.MaxItems then break end end
 return out
end
return G
