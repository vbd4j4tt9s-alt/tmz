local Guide=require(game:GetService('ReplicatedStorage').BeginnerGuide)
local Rules=require(game:GetService('ReplicatedStorage').PlantRules)
local T={}
function T.State(data,chests,player)
 local state=data:GetPremium(player).Tutorial
 local step=state and Guide.Step(state)or 0
 if step==1 and player:GetAttribute('ChestChaseSeedCarrying')then step=2 end
 local spec=Guide.Steps[step];local kind=spec and spec.Target;local target,part
 local base=chests.Bases:GetPlayerBase(player)
 if kind=='Pack'then
  local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart');local nearest=math.huge
  if not chests.Map.Refreshing then for _,seed in ipairs(chests.Map.Chests or{})do
   if seed.Stage==1 and seed.Available and seed.Body and seed.Body.Parent and seed.Prompt and seed.Prompt.Enabled then
    local position=chests:GetPackPickupPosition(seed.Prompt,seed.Body.Position)
    local distance=root and(position-root.Position).Magnitude or position.Z
    if distance<nearest then nearest=distance;target=position;part=seed.Body end
   end
  end end
 elseif kind=='Safety'then
  local line=chests.Map.BaseBoundaryLine
  target=line and line.Position+Vector3.new(0,3,-12)or(base and base.Spawn.Position)
 elseif kind=='Market'then target=chests.Map.BuyStation.Position
 elseif base then
  if kind=='Treadmill'and base.Treadmill then target=base.Treadmill.Position;part=base.Treadmill
  elseif kind=='Garden'then
   local plots=base.Model:FindFirstChild('GardenPlots');local slot=1;local chosen
   if step==5 then
    local garden=data.Gardens[player]
    for key,crops in pairs(garden and garden.Plots or{})do for _,crop in ipairs(crops)do
     local definition=data.Config.GardenPlants[crop.SeedId]
     if definition then
      local ready
      -- All modes use the same server fruit readiness rules as harvesting.
      if not ready then for index=1,definition.FruitCount or 1 do if Rules.FruitReady(crop,index,os.time())then ready=index;break end end end
      if not chosen or ready then chosen=crop;slot=tonumber(key)or 1 end
      if ready then step=6;break end
     end
    end;if step==6 then break end end
   end
   local soil=plots and plots:FindFirstChild('DirtPlot_'..slot)
   target=soil and soil:IsA('BasePart')and soil.Position or base.Spawn.Position
   if chosen and soil then target=soil.CFrame:PointToWorldSpace(Vector3.new(chosen.OffsetX or 0,2,chosen.OffsetZ or 0))end
  end
 end
 return {Success=true,Step=step,Kind=kind,Target=target,TargetPart=part,WaitingForPack=step==1 and target==nil}
end
return T
