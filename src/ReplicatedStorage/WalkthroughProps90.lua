-- R95: all base props and fence tiers are walk-through; plants and walking surfaces retain their physics.
local W={}
local mapProps={MythicLandmarks=true,EnvironmentPolishV127=true,PresentationV128=true,RouteSceneryV134=true,SparseRouteSceneryV136=true,GardenHubDesign=true,RouteDress84=true}
local biomeProps={PersonalityDecorV041=true,CustomScenery=true,GeneratedScenery=true,BiomeDesignV091=true}
local function planted(node)
 return node:GetAttribute('CropId')~=nil or node:GetAttribute('GardenPlant')==true or node:GetAttribute('GardenPlantV141')==true
end
local function surface(part)
 return part.Name=='Pad'or part.Name=='Spawn'or part.Name=='Treadmill'or part.Name:match('^DirtPlot_%d')~=nil or part:GetAttribute('TreadmillTrainingBelt')==true
end
function W.Policy(part,map)
 if not part:IsA('BasePart')then return nil end
 local node=part
 while node and node~=map do
  if planted(node)then return nil end
  local parent=node.Parent
  if parent==map and mapProps[node.Name]then return 'decor'end
  if parent==map and node.Name=='EconomyHub'then return 'decor'end
  if parent and parent.Name=='Bases'and parent.Parent==map then if surface(part)then return nil end;return 'decor'end
  if parent and parent.Parent and parent.Parent.Name=='Biomes'and biomeProps[node.Name]then return 'decor'end
  node=parent
 end
 return nil
end
local function set(part)
 part.CanCollide=false;part.CanTouch=false
 -- Retain query targets: planting, upgrade clicks and SurfaceGui input must still work.
end
function W.Model(model,_leaderboard)
 if not model then return 0 end
 local count=0
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
  local node=p;local crop=false
  while node and node~=model.Parent do if planted(node)then crop=true;break end;node=node.Parent end
  if not crop and not surface(p)then set(p);count+=1 end
 end end
 model:SetAttribute('WalkthroughRevision',95)
 return count
end
function W.Apply(map)
 if not map then return 0 end
 local count=0
 for _,part in ipairs(map:GetDescendants())do if W.Policy(part,map)then set(part);count+=1 end end
 return count
end
function W.Bind(map)
 local count=W.Apply(map);local queue={};local scheduled=false;local dead=false
 local connection=map.DescendantAdded:Connect(function(part)
  if not part:IsA('BasePart')then return end
  queue[part]=true;if scheduled then return end;scheduled=true
  task.defer(function()
   scheduled=false;if dead then return end
   local batch=queue;queue={}
   for p in pairs(batch)do if p.Parent and W.Policy(p,map)then set(p)end end
  end)
 end)
 local destroy;destroy=map.Destroying:Connect(function()dead=true;queue={};connection:Disconnect();destroy:Disconnect()end)
 return count
end
return W
