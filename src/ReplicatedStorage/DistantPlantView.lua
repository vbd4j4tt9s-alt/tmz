local RS=game:GetService('ReplicatedStorage');local Visuals=require(RS:WaitForChild('PlantVisuals'));local Rules=require(RS:WaitForChild('PlantRules'));local Catalog=require(RS:WaitForChild('PlantCatalog'))
local V={PartBudget=5000,ModelBudget=64,Range=3200}
function V.Cost(crop)
 local def=Catalog[crop.SeedId];local layout=Visuals.LeafLayout(crop.SeedId,crop);local cost=1
 for _,raw in ipairs(Visuals.Specs(crop.SeedId,crop))do
  if raw.g~=0 and def.Mode~='whole'then continue end
  local s=Visuals.LeafSpec(raw,crop,layout)
  if s then s=table.clone(s);s.tx=nil;if s.s=='Crystal'then s.s='Gem'elseif s.s=='LeafBlade'then s.s='ProxyBlade'end;cost+=Visuals.PartCost(s)end
 end
 if def.Mode~='whole'then for index=1,def.FruitCount do if not Rules.IsPicked(crop,index)then
  for _,s in ipairs(Visuals.Metadata(crop.SeedId,crop).Proxies[index])do cost+=Visuals.PartCost(s)end
 end end end
 if Rules.HasGrowingFruit(crop,def,workspace:GetServerTimeNow())then cost+=4+2*def.FruitCount end
 return cost
end
function V.Build(crop,origin,now,work)
 local def=Catalog[crop.SeedId];local model=Instance.new('Model');model.Name='DistantPlant';if work then work.Model(model)end
 local base=Instance.new('Folder');base.Name='Silhouette';base.Parent=model
 Visuals.Supports(crop.SeedId,origin,crop,4,base,work)
 if def.Mode~='whole'then for index=1,def.FruitCount do if not Rules.IsPicked(crop,index)then
  local fruit=Instance.new('Folder');fruit.Name='Harvest_'..index;fruit.Parent=model;Visuals.FruitProxy(fruit,crop.SeedId,crop,index,origin,work)
 end end end
 local pivot=Instance.new('Part');pivot.Name='ViewOrigin';pivot.Size=Vector3.new(.05,.05,.05);pivot.CFrame=origin;pivot.Transparency=1;pivot.Anchored=true;pivot.CanCollide=false;pivot.CanTouch=false;pivot.CanQuery=false;pivot.Parent=model;model.PrimaryPart=pivot
 for _,part in ipairs(model:GetDescendants())do if part:IsA('BasePart')then part.CanQuery=false;part.CanTouch=false;part.CanCollide=false end end
 local growing=now<(crop.MatureAt or 0)or Rules.HasGrowingFruit(crop,def,now)
 if growing then Visuals.BeginGrowth(model,crop.SeedId,crop,origin);Visuals.UpdateGrowth(model,crop,now)end
 return model,growing
end
function V.Select(entries)
 table.sort(entries,function(a,b)return a.Score<b.Score end)
 local cost,count=0,0
 for _,e in ipairs(entries)do e.Selected=false;if count<V.ModelBudget and cost+e.Cost<=V.PartBudget then e.Selected=true;cost+=e.Cost;count+=1 end end
 return cost,count
end
return V
