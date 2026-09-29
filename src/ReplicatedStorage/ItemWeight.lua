-- R112: display-only item weights ("2.4kg"). Never feeds cash, saves, odds or rolled sizes.
-- weight = species/pack base (kg) x the item's saved size multiplier.
local RS=game:GetService('ReplicatedStorage')
local W={Version=1}
-- Fruit: 0.8 kg per squared stud of the species' average authored fruit radius
-- (Watermelon about 5 kg, a berry bunch under 1 kg, giant flowers a few hundred kg).
W.FruitPerRadius2=.8
-- Seeds: a small share of their fruit, 0.1 to 1 kg at size 1.
W.SeedShare=.1
-- Packs by tier rank (1 = common pack ... 6 = mythic/limited, 7 = Void).
W.PackBases={1,1.25,1.5,2,2.5,3,4}
local bases={}
local function finite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function W.FruitBase(id)
 local key='Fruit:'..tostring(id);local cached=bases[key];if cached then return cached end
 local ok,catalog=pcall(require,RS:WaitForChild('PlantCatalog'))
 local def=ok and type(catalog)=='table'and catalog[id];local total,count=0,0
 for _,r in ipairs(def and def.FruitRadii or{})do if finite(r)and r>0 then total+=r;count+=1 end end
 local radius=count>0 and total/count or 1.1
 local value=math.clamp(W.FruitPerRadius2*radius*radius,.05,500);bases[key]=value;return value
end
function W.SeedBase(id)
 local key='Seed:'..tostring(id);local cached=bases[key];if cached then return cached end
 local value=math.clamp(W.SeedShare*math.sqrt(W.FruitBase(id)),.1,1);bases[key]=value;return value
end
function W.PackBase(variant)
 local key='Pack:'..tostring(variant);local cached=bases[key];if cached then return cached end
 local rank=2
 local ok,rules=pcall(require,RS:WaitForChild('SeedPackRules'))
 if ok and type(rules)=='table'and rules.GetPackTier then local fine,_,r=pcall(rules.GetPackTier,variant);if fine and finite(r)then rank=r end end
 local value=W.PackBases[math.clamp(math.floor(rank),1,#W.PackBases)];bases[key]=value;return value
end
-- kind: 'Fruit' (or 'Plant'), 'Seed', 'Pack'. id: SeedId, or the pack's BagVariant.
function W.Base(kind,id)
 if kind=='Pack'then return W.PackBase(id)end
 if kind=='Seed'then return W.SeedBase(id)end
 return W.FruitBase(id)
end
function W.Weight(kind,id,size)
 size=finite(size)and size>0 and size or 1
 return W.Base(kind,id)*size
end
-- One decimal under 10 kg ("2.4kg", "5kg"), whole numbers above ("12kg", "1,250kg").
function W.Format(kg)
 if not finite(kg)or kg<=0 then return''end
 if kg<9.95 then
  local tenths=math.max(1,math.floor(kg*10+.5))
  local whole,rest=math.floor(tenths/10),tenths%10
  return(rest==0 and tostring(whole)or whole..'.'..rest)..'kg'
 end
 local text=tostring(math.floor(kg+.5))
 while true do local nextText,n=text:gsub('^(%d+)(%d%d%d)','%1,%2');text=nextText;if n==0 then break end end
 return text..'kg'
end
function W.Text(kind,id,size)return W.Format(W.Weight(kind,id,size))end
-- Reads the attributes the server already puts on inventory tools.
function W.Tool(tool)
 if not tool then return nil end
 if tool:GetAttribute('HarvestItemTool')then return 'Fruit',tool:GetAttribute('SeedId'),tool:GetAttribute('FruitScale')end
 if tool:GetAttribute('SeedPackTool')then return 'Pack',tool:GetAttribute('BagVariant'),tool:GetAttribute('PackSize')end
 if tool:GetAttribute('GardenSeed')then return 'Seed',tool:GetAttribute('SeedId'),tool:GetAttribute('SeedScale')end
 return nil
end
function W.ToolText(tool)
 local kind,id,size=W.Tool(tool)
 return kind and W.Text(kind,id,size)or''
end
return W
