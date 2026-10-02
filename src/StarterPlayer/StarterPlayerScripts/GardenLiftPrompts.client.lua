local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Players=game:GetService('Players')
local Contact=require(RS:WaitForChild('GardenLiftContact'));local Catalog=require(RS:WaitForChild('PlantCatalog'));local Cache=require(RS:WaitForChild('PlantPartCache'))
local player=Players.LocalPlayer;local map=workspace:WaitForChild('ChestChaseMap');local records={};local connections={};local elapsed=0
-- R124 performance: plant ownership is cached per prompt; another player's prompt only gets the cheap "stay disabled"
-- check each tick and its ancestor/owner lookup every OwnerRecheck seconds (it was every tick for every plant).
local OwnerRecheck=2
local function add(p)if p:IsA('ProximityPrompt')and p.Name=='PlantTopPrompt'then records[p]={Check=0}end end
local function remove(p)local r=records[p];if r then if r.Cache then r.Cache:Destroy()end;records[p]=nil end end
for _,p in ipairs(map:GetDescendants())do add(p)end
connections[1]=map.DescendantAdded:Connect(add);connections[2]=map.DescendantRemoving:Connect(remove)
connections[3]=Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.15 then return end;elapsed=0
 local char=player.Character;local root=char and char:FindFirstChild('HumanoidRootPart');local hum=char and char:FindFirstChildOfClass('Humanoid')
 local ready=root and hum and hum.Health>0 and player:GetAttribute('DataStatus')=='Loaded'
 local nearest,point,best=nil,nil,math.huge;local now=os.clock()
 for prompt,r in pairs(records)do
  if not r.Mine and now<r.Check then continue end
  local attachment=prompt.Parent;local model=attachment and attachment:FindFirstAncestorOfClass('Model')
  r.Mine=model~=nil and model:GetAttribute('GardenOwnerId')==player.UserId;if not r.Mine then r.Check=now+OwnerRecheck end
  if ready and r.Mine then
   local def=Catalog[model:GetAttribute('SeedId')];local pivot=model.PrimaryPart;local solid=model:FindFirstChild('SolidPlant')
   if def and pivot and solid and(root.Position-pivot.Position).Magnitude<=def.Radius*(model:GetAttribute('PlantScale')or 1)*1.5+15 then
    if not r.Cache or r.Cache.Dead or r.Cache.Root~=solid then if r.Cache then r.Cache:Destroy()end;r.Cache=Cache.new(solid,Contact.IsStem)end
    local at=Contact.Find(model,root.Position,r.Cache:List())
    if at then local gap=(root.Position-at).Magnitude;if gap<best then nearest=prompt;point=at;best=gap end end
   end
  end
 end
 for prompt in pairs(records)do local enabled=prompt==nearest;if prompt.Enabled~=enabled then prompt.Enabled=enabled end end
 if nearest then
  local a=nearest.Parent;local frame=a.Parent.CFrame:ToObjectSpace(CFrame.new(point));if a.CFrame~=frame then a.CFrame=frame end
 end
end)
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end;for p in pairs(records)do remove(p)end end)
