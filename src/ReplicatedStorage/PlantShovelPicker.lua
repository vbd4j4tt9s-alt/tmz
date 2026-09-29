-- Shared hover/shovel visual picking: foliage can stay non-queryable for normal camera/harvest rays.
local RS=game:GetService('ReplicatedStorage');local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Rules=require(RS:WaitForChild('PlantRules'));local Visuals=require(RS:WaitForChild('PlantVisuals'))
local P={};P.__index=P;local axes={'X','Y','Z'}
function P.Plant(item)
 while item and item~=workspace do if item:GetAttribute('GardenPlantV141')then return item end;item=item.Parent end
end
function P.Box(origin,direction,frame,size,limit)
 local inv=frame:Inverse();local o=inv:PointToWorldSpace(origin);local d=inv:VectorToWorldSpace(direction);local half=size*.5;local near,far=0,limit
 for _,axis in ipairs(axes)do
  if math.abs(d[axis])<1e-8 then if math.abs(o[axis])>half[axis]then return nil end
  else
   local a,b=(-half[axis]-o[axis])/d[axis],(half[axis]-o[axis])/d[axis];if a>b then a,b=b,a end
   near=math.max(near,a);far=math.min(far,b);if near>far then return nil end
  end
 end
 return near
end
function P.Part(origin,direction,part,limit)
 local size=part:GetAttribute('ArtSize')or part.Size
 if part:IsA('Part')and part.Shape==Enum.PartType.Cylinder then size=part.Size end
 local distance=P.Box(origin,direction,part.CFrame,size,limit);if not distance then return nil end
 local mesh=part:FindFirstChildOfClass('SpecialMesh')
 if(part:IsA('Part')and part.Shape==Enum.PartType.Ball)or(mesh and mesh.MeshType==Enum.MeshType.Sphere)then
  local inv=part.CFrame:Inverse();local o=inv:PointToWorldSpace(origin);local d=inv:VectorToWorldSpace(direction);local h=size*.5
  local a,b,c=0,0,-1
  for _,axis in ipairs(axes)do local x,v=o[axis]/h[axis],d[axis]/h[axis];a+=v*v;b+=2*x*v;c+=x*x end
  if c<=0 then return 0 end
  local det=b*b-4*a*c;if det<0 or a<1e-12 then return nil end
  distance=(-b-math.sqrt(det))/(2*a);if distance<0 or distance>limit then return nil end
 end
 return distance
end
local function bounds(model,r)
 if r.Center then return model:GetPivot()*r.Center,r.Size end
 local id=model:GetAttribute('SeedId');local def=Catalog[id];if not def then return nil end
 local crop={SeedId=id,Id=model:GetAttribute('CropId')or id,PlantScale=model:GetAttribute('PlantScale')or 1,SeedScale=model:GetAttribute('SeedScale')or 1,Mutation=model:GetAttribute('Mutation')or'None',HarvestCycle=model:GetAttribute('HarvestCycle')or 0}
 crop.FruitStates={};for index=1,def.FruitCount do crop.FruitStates[tostring(index)]={ReadyAt=model:GetAttribute('FruitReadyAt'..index)or 0,Cycle=model:GetAttribute('FruitCycle'..index)or crop.HarvestCycle}end
 do
  local radius=def.Radius*crop.PlantScale*1.18+2;local height=def.Height*crop.PlantScale*1.18+2
  local lo,hi=Vector3.new(-radius,-radius,-radius),Vector3.new(radius,height,radius)
  for index=1,def.FruitCount do
   local c=Visuals.FruitPosition(crop,def,index);local z=(def.FruitRadii[index]or 1)*Rules.Fruit(crop,index,def).Scale*1.2+1
   lo=Vector3.new(math.min(lo.X,c.X-z),math.min(lo.Y,c.Y-z),math.min(lo.Z,c.Z-z));hi=Vector3.new(math.max(hi.X,c.X+z),math.max(hi.Y,c.Y+z),math.max(hi.Z,c.Z+z))
  end
  r.Center=CFrame.new((lo+hi)*.5);r.Size=hi-lo
 end
 return model:GetPivot()*r.Center,r.Size
end
function P.new(map)
 local self=setmetatable({Records={},Pending={},Connections={}},P)
 local function untrack(model)
  local pending=self.Pending[model];if pending then pending:Disconnect();self.Pending[model]=nil end
  local r=self.Records[model];if not r then return end
  for _,c in ipairs(r.Connections)do c:Disconnect()end;self.Records[model]=nil;self.Exclusions=nil
 end
 local function track(model)
  if not model:IsA('Model')or self.Records[model]then return end
  if not model:GetAttribute('GardenPlantV141')then
   if not self.Pending[model]then self.Pending[model]=model:GetAttributeChangedSignal('GardenPlantV141'):Connect(function()
    if model:GetAttribute('GardenPlantV141')then track(model)end
   end)end
   return
  end
  local pending=self.Pending[model];if pending then pending:Disconnect();self.Pending[model]=nil end
  local r={Parts={},Connections={}};self.Records[model]=r;self.Exclusions=nil
  local function add(part)if part:IsA('BasePart')and not part:FindFirstAncestor('PlantRarityEffects')then r.Parts[part]=true end end
  for _,part in ipairs(model:GetDescendants())do add(part)end
  table.insert(r.Connections,model.AttributeChanged:Connect(function(name)
   if name:sub(1,10)=='FruitCycle'or name=='SeedId'or name=='CropId'or name=='PlantScale'or name=='SeedScale'or name=='Mutation'or name=='HarvestCycle'then r.Center=nil end
  end))
  table.insert(r.Connections,model.DescendantAdded:Connect(add));table.insert(r.Connections,model.DescendantRemoving:Connect(function(part)r.Parts[part]=nil end))
 end
 for _,model in ipairs(map:GetDescendants())do track(model)end
 table.insert(self.Connections,map.DescendantAdded:Connect(track));table.insert(self.Connections,map.DescendantRemoving:Connect(untrack))
 return self
end
function P:RayExclusions(character)
 if not self.Exclusions or self.Character~=character then
  local list=character and{character}or{};for model in pairs(self.Records)do table.insert(list,model)end
  self.Exclusions=list;self.Character=character
 end
 return self.Exclusions
end
function P:Pick(origin,direction,limit,sceneHit)
 debug.profilebegin('Shovel target')
 local nearest,target,targetPart=limit,nil,nil;local native=sceneHit and sceneHit.Instance;local nativePlant=native and P.Plant(native)
 if native then
  local distance=sceneHit.Distance or(sceneHit.Position and(sceneHit.Position-origin).Magnitude)
  if distance and not nativePlant then nearest=math.min(nearest,distance+.03)
  elseif nativePlant and native.Transparency<.95 and native.LocalTransparencyModifier<.95 and distance then nearest=math.min(nearest,distance+.03);target=nativePlant;targetPart=native end
 end
 for model,r in pairs(self.Records)do if model.Parent then
  local frame,size=bounds(model,r)
  if frame and P.Box(origin,direction,frame,size,nearest)then
   for part in pairs(r.Parts)do if part.Parent and part.Transparency<.95 and part.LocalTransparencyModifier<.95 then
    local distance=P.Part(origin,direction,part,nearest)
    if distance and distance<=nearest then nearest=distance;target=model;targetPart=part end
   end end
  end
 end end
 debug.profileend();return target,targetPart
end
function P:WithinRange(model,position,limit)
 local r=self.Records[model];if not r then return false end
 local frame,size=bounds(model,r);if not frame then return false end
 local q=frame:PointToObjectSpace(position);local half=size*.5
 return Vector3.new(math.max(0,math.abs(q.X)-half.X),math.max(0,math.abs(q.Y)-half.Y),math.max(0,math.abs(q.Z)-half.Z)).Magnitude<=limit
end
function P:Destroy()
 for _,c in pairs(self.Pending)do c:Disconnect()end;table.clear(self.Pending)
 for _,c in ipairs(self.Connections)do c:Disconnect()end
 for _,r in pairs(self.Records)do for _,c in ipairs(r.Connections)do c:Disconnect()end end
 table.clear(self.Records);table.clear(self.Connections);self.Exclusions=nil;self.Character=nil
end
-- A single geometry index serves hover and shovel clients.
local shared=setmetatable({},{__mode='k'})
function P.Acquire(map)
 local entry=shared[map]
 if not entry then entry={Picker=P.new(map),Users=0};shared[map]=entry end
 entry.Users+=1;local released=false
 return entry.Picker,function()
  if released then return end;released=true;entry.Users-=1
  if entry.Users==0 then entry.Picker:Destroy();shared[map]=nil end
 end
end
return P
