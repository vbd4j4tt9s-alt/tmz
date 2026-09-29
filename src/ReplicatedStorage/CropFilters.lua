local Catalog=require(script.Parent.PlantCatalog)
local Traits=require(script.Parent.ItemTraitNames)
local F={Rarities={'All rarities','Common','Uncommon','Rare','Epic','Legendary','Mythic','Secret','Cosmic','King'},Kinds={'All crops','Fruit','Flower','Tree','Other'},Sorts={'Value ↓','Value ↑','Name'}}
function F.Kind(item)
 local d=Catalog[item.SeedId]or{};local text=string.lower((d.Kind or'')..' '..(d.Form or'')..' '..(d.Name or'')..' '..(item.FruitName or''))
 if d.Tree then return'Tree'end
 if string.find(text,'flower',1,true)or string.find(text,'bloom',1,true)or string.find(text,'lily',1,true)or string.find(text,'rose',1,true)then return'Flower'end
 if d.Mode=='repeat' then return'Fruit'end
 if string.find(text,'tree',1,true)or string.find(text,'oak',1,true)then return'Tree'end
 return'Other'
end
function F.Apply(items,query,rarity,kind,mutated,sort)
 local out={};query=string.lower(query or'')
 for _,item in ipairs(items or{})do
  local def=Catalog[item.SeedId]or{};local traitText=Traits.Text(item);local name=(item.FruitName or item.Name or item.SeedId or'')..' '..traitText
  if (query==''or string.find(string.lower(name),query,1,true))and( not rarity or rarity=='All rarities'or(item.Rarity or def.Rarity)==rarity)and(not kind or kind=='All crops'or F.Kind(item)==kind)and(not mutated or traitText~='')then table.insert(out,item)end
 end
 table.sort(out,function(a,b)
  local av,bv=a.SellValue or 0,b.SellValue or 0
  if sort=='Name'then av,bv=a.FruitName or a.Name or'',b.FruitName or b.Name or''end
  if av==bv then return tostring(a.InventoryId)<tostring(b.InventoryId)end
  if sort=='Value ↑'or sort=='Name'then return av<bv end;return av>bv
 end)
 return out
end
return F
