local Guide=require(game:GetService('ReplicatedStorage').BeginnerGuide)
local Rules=require(game:GetService('ReplicatedStorage').PlantRules)
-- R158e: what the tutorial points at, for the step the save is on (BeginnerGuide.Kind). Positions are sent as Vector3 too: with StreamingEnabled the part may not exist on the client,
-- so the arrow points toward the known position. Also sent: Home (your base pad's CFrame and size: steps 5 - 10 are "at home"), the tutorial plant's next fruit time (ReadyAt / ReadyIn,
-- Ripe). A step that can't be done any more is moved on first (TutorialProgress.TutorialRepair).
local T={}
-- The plant the grow / harvest steps point at: the tutorial's 10-second plant if it is still there, else the plant whose next fruit is ready first. Returns crop, slot.
local function tutorialCrop(data,player,state)
 local garden=data.Gardens and data.Gardens[player];local best,slot,bestAt
 for key,crops in pairs(garden and garden.Plots or{})do for _,crop in ipairs(crops)do
  local definition=data.Config.GardenPlants[crop.SeedId]
  if definition then
   if state and state.FastCrop and crop.Id==state.FastCrop then return crop,tonumber(key)or 1,definition end
   local at=math.huge
   for index=1,definition.FruitCount or 1 do if not Rules.IsPicked(crop,index)then at=math.min(at,math.max(crop.MatureAt or 0,Rules.FruitReadyAt(crop,index)))end end
   if not bestAt or at<bestAt then best,slot,bestAt=crop,tonumber(key)or 1,at end
  end
 end end
 return best,slot,best and data.Config.GardenPlants[best.SeedId]
end
function T.State(data,chests,player)
 if type(data.TutorialRepair)=='function'then pcall(data.TutorialRepair,data,player)end
 local state=data:GetPremium(player).Tutorial
 local stage=state and Guide.Step(state)or 0
 local kind=Guide.Kind(stage,player:GetAttribute('ChestChaseSeedCarrying')==true)
 local target,part,readyAt,ripe
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
 elseif kind=='Sell'then
  local station=chests.Map.SellStation or chests.Map.BuyStation;target=station and station.Position
 elseif base then
  if kind=='Treadmill'and base.Treadmill then target=base.Treadmill.Position;part=base.Treadmill
  elseif kind=='Garden'or kind=='Crop'then
   local plots=base.Model:FindFirstChild('GardenPlots');local chosen,slot,definition=nil,1,nil
   if kind=='Crop'then chosen,slot,definition=tutorialCrop(data,player,state)end
   local soil=plots and plots:FindFirstChild('DirtPlot_'..slot)
   target=soil and soil:IsA('BasePart')and soil.Position or base.Spawn.Position
   if chosen and soil then target=soil.CFrame:PointToWorldSpace(Vector3.new(chosen.OffsetX or 0,2,chosen.OffsetZ or 0))end
   if chosen and definition then
    local now=os.time();readyAt=math.huge
    for index=1,definition.FruitCount or 1 do
     if Rules.FruitReady(chosen,index,now)then ripe=true end
     if not Rules.IsPicked(chosen,index)then readyAt=math.min(readyAt,math.max(chosen.MatureAt or 0,Rules.FruitReadyAt(chosen,index)))end
    end
    if readyAt==math.huge then readyAt=nil end
   end
  end
 end
 local pad=base and base.Pad
 local result={Success=true,Step=stage,Kind=kind,Target=target,TargetPart=part,WaitingForPack=kind=='Pack'and target==nil,
  HomeCFrame=pad and pad.CFrame or nil,HomeSize=pad and pad.Size or nil,ReadyAt=readyAt,Ripe=ripe==true}
 if readyAt then result.ReadyIn=math.max(0,readyAt-os.time())end
 return result
end
return T
