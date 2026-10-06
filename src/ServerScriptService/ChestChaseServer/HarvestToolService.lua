-- Backpack tools carry identity, not hundreds of replicated fruit models.
local RS=game:GetService('ReplicatedStorage')
local Info=require(RS:WaitForChild('HarvestItemInfo'))
local Shovel=require(RS:WaitForChild('ShovelModel'))
local Service={};local watchers=setmetatable({},{__mode='k'})
local function handle(tool)
 local p=Instance.new('Part');p.Name='Handle';p.Size=Vector3.new(.2,.2,.2);p.Transparency=1
 p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Massless=true;p.Anchored=false;p.CastShadow=false;p.Parent=tool;return p
end
function Service.Sync(chests,player)
 if not player.Parent or not chests.PlayerData:IsLoaded(player)then return end
 local containers,backpack=chests:_getToolContainers(player);if not backpack then return end
 local garden=chests.PlayerData.Gardens[player];local items={};for _,crop in ipairs(garden and garden.Harvests or{})do items[crop.Id]=crop end
 local found={};local shovel
 for _,container in ipairs(containers)do for _,tool in ipairs(container:GetChildren())do if tool:IsA('Tool')then
  if tool:GetAttribute('GardenShovel')then if shovel then tool:Destroy()else shovel=tool end
  elseif tool:GetAttribute('HarvestItemTool')then
   local id=tool:GetAttribute('HarvestInventoryId');if not items[id]or found[id]then tool:Destroy()else found[id]=true end
  end
 end end end
 if not shovel then
  shovel=Instance.new('Tool');shovel.Name='Shovel';shovel.ToolTip='Remove a plant • Dig holes on the track to trap players';shovel.CanBeDropped=false;shovel.RequiresHandle=true;shovel.ManualActivationOnly=true
  shovel:SetAttribute('GardenShovel',true);shovel:SetAttribute('InventoryKey','shovel');shovel:SetAttribute('ShovelAssetId',Shovel.AssetId)
  local h=handle(shovel);local appearance
  shovel.Equipped:Connect(function()if appearance then appearance:Destroy()end;appearance=Shovel.Build(shovel,h)end)
  shovel.Unequipped:Connect(function()if appearance then appearance:Destroy();appearance=nil end end)
  shovel.Parent=backpack
 end
 for _,crop in ipairs(garden and garden.Harvests or{})do if not found[crop.Id]then
  local def=chests.Config.GardenPlants[crop.SeedId];if not def then continue end
  local item=Info.From(crop,def);local tool=Instance.new('Tool');tool.Name=item.Name
  tool.ToolTip=item.Name..' • $'..tostring(item.SellValue);tool.CanBeDropped=false;tool.RequiresHandle=true;tool.ManualActivationOnly=true
  tool:SetAttribute('HarvestItemTool',true);tool:SetAttribute('HarvestInventoryId',crop.Id);tool:SetAttribute('InventoryKey',crop.Id)
  for _,key in ipairs({'SeedId','Mutation','Weather','FruitScale','SellValue','FruitName'})do tool:SetAttribute(key,item[key])end
  for key,value in pairs(item.VisualCrop)do tool:SetAttribute(key,value)end
  tool:SetAttribute('Rarity',def.Rarity);handle(tool);tool.Parent=backpack
 end end
end
function Service.Install(Chests)
 local sync=Chests.SyncTools
 function Chests:SyncTools(player)
  sync(self,player);Service.Sync(self,player)
  if not watchers[player]and player.Parent then
   local queued=false;watchers[player]=player:GetAttributeChangedSignal('GardenRevision'):Connect(function()
    if queued then return end;queued=true;task.defer(function()queued=false;if player.Parent then self:SyncTools(player)end end)
   end)
  end
 end
 local cleanup=Chests.CleanupPlayer
 function Chests:CleanupPlayer(player)
  if watchers[player]then watchers[player]:Disconnect();watchers[player]=nil end
  return cleanup(self,player)
 end
end
return Service
