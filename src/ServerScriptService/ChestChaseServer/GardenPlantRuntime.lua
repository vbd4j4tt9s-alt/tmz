-- V149 revision 9: saved-time growth; mature collision and harvest authority remain server-owned.
local RS=game:GetService('ReplicatedStorage')
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Rules=require(RS:WaitForChild('PlantRules'))
local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Access=require(RS:WaitForChild('PlantAccessRules'))
local Weather=require(RS.WeatherTraits);local FX=require(RS.ItemEffectAnchor)
local Hologram=require(RS.HologramProjection)
local Runtime={}
local ViewState=require(RS:WaitForChild('GardenViewState'))
local counters={CropChecks=0,CropRefreshes=0,UnchangedSkipped=0,DescriptionUpdates=0}
function Runtime.PerformanceStats()return table.clone(counters)end
local snapshotFields={'Id','SeedId','PlantScale','SeedScale','Mutation','Weather','PlantedAt','MatureAt','ReadyAt','HarvestCycle','PickedMask','OffsetX','OffsetZ'}
local function unchanged(record,crop,ownerId,now,def)
 local snapshot=record and record.Snapshot
 if not snapshot or record.OwnerId~=ownerId or not record.Model.Parent or now<record.LastRefresh or now>=record.NextRefresh then return false end
 for _,key in ipairs(snapshotFields)do if snapshot[key]~=crop[key]then return false end end
 for index=1,def.FruitCount do
  if snapshot.Ready[index]~=Rules.FruitReadyAt(crop,index)or snapshot.Cycles[index]~=Rules.FruitCycle(crop,index)or snapshot.FruitWeather[index]~=Weather.Fruit(crop,index,Rules.FruitCycle(crop,index))then return false end
 end
 return snapshot.HasFruitStates==(crop.FruitStates~=nil)
end
local function remember(record,crop,ownerId,now,def,stage,regrowing)
 local snapshot={Ready={},Cycles={},FruitWeather={},HasFruitStates=crop.FruitStates~=nil}
 for _,key in ipairs(snapshotFields)do snapshot[key]=crop[key]end
 local deadline=(stage<4 or Hologram.Is(crop.SeedId))and now+1 or math.huge
 for index=1,def.FruitCount do
  local at=Rules.FruitReadyAt(crop,index);snapshot.Ready[index]=at;snapshot.Cycles[index]=Rules.FruitCycle(crop,index);snapshot.FruitWeather[index]=Weather.Fruit(crop,index,Rules.FruitCycle(crop,index))
  if at>now and not Rules.IsPicked(crop,index)then deadline=math.min(deadline,at)end
 end
 if regrowing then
  local interval=math.max(.5,(def.RegrowSeconds or def.Seconds)/32)
  deadline=math.min(deadline,(math.floor(now/interval)+1)*interval)
 end
 record.Snapshot=snapshot;record.OwnerId=ownerId;record.LastRefresh=now;record.NextRefresh=deadline
end
local function origin(plot,crop)return plot.CFrame*CFrame.new(crop.OffsetX,plot.Size.Y/2+.025,crop.OffsetZ)end
function Runtime.Install(Service)
 local descriptions=RS:FindFirstChild('GardenViewDescriptions')
 if not descriptions then descriptions=Instance.new('Folder');descriptions.Name='GardenViewDescriptions';descriptions.Parent=RS end
 local function describe(model,record,key)
  local node=record.Description
  if node and node.Parent==descriptions and record.DescriptionKey==key then return end
  counters.DescriptionUpdates+=1;record.DescriptionKey=key
  if not node then
   node=Instance.new('Folder');node.Name=tostring(model:GetAttribute('GardenOwnerId'))..':'..tostring(model:GetAttribute('CropId'));record.Description=node
   model.Destroying:Connect(function()node:Destroy()end)
  end
  for _,key in ipairs(ViewState.Keys)do if key~='FruitRevision'then node:SetAttribute(key,model:GetAttribute(key))end end
  for index=1,6 do node:SetAttribute('FruitReadyAt'..index,model:GetAttribute('FruitReadyAt'..index));node:SetAttribute('FruitCycle'..index,model:GetAttribute('FruitCycle'..index));node:SetAttribute('FruitDuration'..index,model:GetAttribute('FruitDuration'..index));node:SetAttribute('FruitWeather'..index,model:GetAttribute('FruitWeather'..index))end
  node:SetAttribute('Origin',model.PrimaryPart.CFrame);node:SetAttribute('FruitRevision',model:GetAttribute('FruitRevision'))
  if not node.Parent then node.Parent=descriptions end
 end
 function Service:BuildPlantAt(id,stage,at)return Visuals.Build(id,at,nil,stage)end
 function Service:BuildArtLibrary()
  local old=self.Remotes:FindFirstChild('SeedArt');if old then old:Destroy()end
  local library=Instance.new('Folder');library.Name='SeedArt'
  local plants=Instance.new('Folder');plants.Name='Plants';plants.Parent=library
  local harvests=Instance.new('Folder');harvests.Name='Harvests';harvests.Parent=library
  local seeds=Instance.new('Folder');seeds.Name='Seeds';seeds.Parent=library
  -- Keep compatibility with the previous client during Studio hot reload.
  local stages=Instance.new('Folder');stages.Name='GrowthStages';stages.Parent=library
  for id in pairs(Catalog)do
   -- Plant/harvest viewport art is built locally on demand.
   local packet=self:BuildLooseSeed(id,CFrame.new(),seeds);packet.Name=id
  end
  library:SetAttribute("Version",142);library:SetAttribute("Ready",true)
  library.Parent=self.Remotes;self.ArtLibrary=library
 end
 function Service:BuildGrowthModel(plot,crop,stage)
  local model=Instance.new('Model');model.Name='Crop_'..crop.Id
  model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  model:SetAttribute('GardenGenerated',true);model:SetAttribute('GardenPlantV141',true)
  for key,value in pairs({CropId=crop.Id,SeedId=crop.SeedId,GrowthStage=stage,OffsetX=crop.OffsetX,OffsetZ=crop.OffsetZ,
   PlantScale=crop.PlantScale,SeedScale=crop.SeedScale,Mutation=crop.Mutation,Weather=Weather.Key(crop.Weather),PlantedAt=crop.PlantedAt,MatureAt=crop.MatureAt})do model:SetAttribute(key,value)end
  local pivot=Instance.new('Part');pivot.Name='CropAnchor';pivot.Size=Vector3.new(.1,.1,.1);pivot.CFrame=origin(plot,crop)
  pivot.Transparency=1;pivot.Anchored=true;pivot.CanCollide=false;pivot.CanTouch=false;pivot.CanQuery=false;pivot.Parent=model;model.PrimaryPart=pivot
  local supports=Instance.new('Folder');supports.Name='SolidPlant';supports.Parent=model
  Visuals.Supports(crop.SeedId,pivot.CFrame,crop,stage,supports)
  local def=Catalog[crop.SeedId]
  FX.Set(pivot,crop.Weather,false,def.Radius*Rules.Scale(crop.PlantScale),def.Height*Rules.Scale(crop.PlantScale))
  pivot:SetAttribute('EffectOffset',Vector3.new(0,def.Height*Rules.Scale(crop.PlantScale)*.45,0))
  if stage==4 and Access.IsGiant(def,Rules.Scale(crop.PlantScale))then
   local prompt=Instance.new('ProximityPrompt');prompt.Name='PlantTopPrompt';prompt.ActionText='GO TO TOP';prompt.ObjectText=def.Name
   prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.GamepadKeyCode=Enum.KeyCode.ButtonY
   prompt.HoldDuration=0;prompt.ClickablePrompt=true;prompt.MaxActivationDistance=Access.TeleportDistance;prompt.RequiresLineOfSight=false
   prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton;prompt.UIOffset=Vector2.new(0,65)
   prompt:SetAttribute('GardenPrompt',true);prompt:SetAttribute('GardenAction','PlantTop')
   prompt:SetAttribute('GardenCropId',crop.Id);prompt:SetAttribute('GardenStage',4)
   local attachment=Instance.new('Attachment');attachment.Name='LiftContact';attachment.Parent=pivot;prompt.Parent=attachment
  end
  model.Parent=plot;return model
 end
 function Service:GardenFruitPoint(plot,crop,index)
  local def=Catalog[crop.SeedId];local at=origin(plot,crop)
  if not def then return at.Position end
  return at:PointToWorldSpace(Visuals.FruitPosition(crop,def,index or Rules.NextFruit(crop,def)or 1))
 end
 function Service:GardenFruitReach(crop,index)
  local def=Catalog[crop.SeedId];return def and math.max(self.Config.GardenInteractionDistance,Visuals.FruitReach(crop,def,index or Rules.NextFruit(crop,def)or 1))or self.Config.GardenInteractionDistance
 end
 function Service:TeleportGardenPlant(player,info,crop,root)
  local function reject(message)return {Success=false,Message=message}end
  local def=Catalog[crop.SeedId];local _,stage=Rules.Growth(crop,os.time())
  if stage~=4 or not Access.IsGiant(def,Rules.Scale(crop.PlantScale))then return reject('THIS PLANT DOES NOT NEED A LIFT')end
  local at=origin(info.Part,crop)

  self.GardenTopCooldowns=self.GardenTopCooldowns or setmetatable({},{__mode='k'})
  if os.clock()-(self.GardenTopCooldowns[player]or -math.huge)<Access.TeleportCooldown then return reject('WAIT A MOMENT BEFORE GOING UP AGAIN')end
  local record=info.Rendered[crop.Id];local model=record and record.Model
  if not model or model.Parent~=info.Part or not model:GetAttribute('GardenPlantV141')or model:GetAttribute('CropId')~=crop.Id
   or model:GetAttribute('GardenOwnerId')~=player.UserId or model:GetAttribute('GrowthStage')~=4 then return reject('THIS PLANT HAS CHANGED — TRY AGAIN')end
  if not require(RS:WaitForChild('GardenLiftContact')).Find(model,root.Position)then return reject('MOVE NEXT TO THE STEM')end
  local localTop=Visuals.TopSurface(crop.SeedId,crop,os.time());if not localTop then return reject('PLANT TOP IS NOT READY')end
  local surface=at:PointToWorldSpace(localTop)+Vector3.new(0,.15,0)
  local character=player.Character;local humanoid=character:FindFirstChildOfClass('Humanoid')
  local leg=character:FindFirstChild('Left Leg')or character:FindFirstChild('Right Leg')
  local feet=root.Size.Y/2+(leg and leg.Size.Y or humanoid.HipHeight)
  local width=math.max(4,root.Size.X*2.3);local height=math.max(7,feet+root.Size.Y*1.8)
  surface=require(game:GetService('ReplicatedStorage'):WaitForChild('GardenTopLanding')).Find(workspace,surface,width,height,{character,model})
  if not surface then return reject('')end
  -- A small top-only landing keeps walk-through flowers usable after the lift.
  -- It is created only for this server-owned crop and removed with the crop model.
  local landing=model:FindFirstChild('PlantTopLanding')
  if not landing then landing=Instance.new('Part');landing.Name='PlantTopLanding';landing:SetAttribute('PlantLanding',true);landing.Parent=model end
  landing.Size=Vector3.new(width+2,.3,width+2);landing.CFrame=CFrame.new(surface-Vector3.new(0,.15,0))
  landing.Transparency=1;landing.Anchored=true;landing.CanCollide=true;landing.CanQuery=false;landing.CanTouch=false;landing.CastShadow=false
  local target=CFrame.new(surface+Vector3.new(0,feet+.35,0))*root.CFrame.Rotation
  character:PivotTo(target*root.CFrame:Inverse()*character:GetPivot());require(script.Parent.MovementGuard).Reset(player)
  root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero;humanoid.Sit=false
  self.GardenTopCooldowns[player]=os.clock()
  return {Success=true,Message=''}
 end
 function Service:RenderGarden(base,owner,onlySlot)
  if not base then return end
  local infos=self.GardenPlots[base.Index];if not infos then return end
  local garden=owner and self.PlayerData:IsLoaded(owner)and self.PlayerData.Gardens[owner]
  local now=os.time();local ownerId=owner and owner.UserId or 0
  -- Garden profiler hotfix: no profiling scope across model preparation.
  for slot,info in ipairs(infos)do
   if onlySlot and slot~=onlySlot then continue end
   local crops=garden and garden.Plots[tostring(slot)]or{};local seen={}
   for _,crop in ipairs(crops)do
    seen[crop.Id]=true;local def=Catalog[crop.SeedId];local record=info.Rendered[crop.Id]
    counters.CropChecks+=1
    if unchanged(record,crop,ownerId,now,def)then counters.UnchangedSkipped+=1;continue end
    counters.CropRefreshes+=1
    local _,stage=Rules.Growth(crop,now)
    if stage==4 and owner then self.PlayerData:MarkAdultDiscovered(owner,crop.SeedId)end
    local key=table.concat({ownerId,crop.Id,stage==4 and 'mature'or 'growing',crop.PlantScale or 1,crop.Mutation,Weather.Key(crop.Weather),crop.PlantedAt,crop.MatureAt},':')
    if not record or record.Key~=key or not record.Model.Parent then
     local model=self:BuildGrowthModel(info.Part,crop,stage)
     if record then record.Model:Destroy()end
     record={Key=key,Model=model};info.Rendered[crop.Id]=record
    end
    local model=record.Model;model:SetAttribute('GardenOwnerId',ownerId);model:SetAttribute('GrowthStage',stage)
    -- Quantize replicated fallback growth; local art still interpolates saved time.
    if stage<4 then
     local step=math.floor(math.clamp((now-crop.PlantedAt)/math.max(1,crop.MatureAt-crop.PlantedAt),0,1)*32)
     if record.BodyStep~=step then Visuals.UpdateGrowth(model:FindFirstChild('SolidPlant'),crop,now);record.BodyStep=step end
    end
    local topPrompt=model.PrimaryPart:FindFirstChild('PlantTopPrompt',true);if topPrompt then topPrompt:SetAttribute('GardenOwnerId',ownerId)end
    if Rules.EnableFruitRegrowth(crop,def,now)and self.PlayerData and self.PlayerData.MarkDirty then self.PlayerData:MarkDirty(owner)end
    local ready=stage==4 and Rules.NextFruit(crop,def,now)~=nil
    local fruitKeys={tostring(crop.HarvestCycle),tostring(crop.PickedMask)}
    for index=1,def.FruitCount do
     local at=Rules.FruitReadyAt(crop,index);local cycle=Rules.FruitCycle(crop,index)
     model:SetAttribute('FruitReadyAt'..index,at);model:SetAttribute('FruitCycle'..index,cycle)
     local weather=Weather.Fruit(crop,index,cycle);model:SetAttribute('FruitWeather'..index,weather)
     local state=crop.FruitStates and crop.FruitStates[tostring(index)];local duration=state and state.Duration
     if model:GetAttribute('FruitDuration'..index)~=duration then model:SetAttribute('FruitDuration'..index,duration)end
     table.insert(fruitKeys,weather..':'..tostring(cycle)..':'..at..':'..tostring(Rules.FruitReady(crop,index,now)))
    end
    local fruitKey=table.concat(fruitKeys,'|')
    local regrowing=stage==4 and Rules.HasGrowingFruit(crop,def,now)
    model:SetAttribute('FruitGrowing',regrowing)
    local growingFruit=model:FindFirstChild('GrowingFruit')
    if regrowing and def.Mode~='whole'then
     if not growingFruit or record.GrowthCycle~=fruitKey then
      if growingFruit then growingFruit:Destroy()end
      growingFruit=Instance.new('Folder');growingFruit.Name='GrowingFruit'
      Visuals.GrowingFruitSupports(crop.SeedId,origin(info.Part,crop),crop,growingFruit,now);growingFruit.Parent=model
      record.GrowthCycle=fruitKey;record.FruitStep=nil
     end
     local step=math.floor(now/math.max(.5,(def.RegrowSeconds or def.Seconds)/32))
     if record.FruitStep~=step then Visuals.UpdateGrowth(growingFruit,crop,now);record.FruitStep=step end
    elseif growingFruit then growingFruit:Destroy()end
    if record.FruitKey~=fruitKey then
     local prompts=model:FindFirstChild('FruitPrompts')
     if not prompts then prompts=Instance.new('Folder');prompts.Name='FruitPrompts';prompts.Parent=model end
     if record.Cycle~=crop.HarvestCycle then prompts:ClearAllChildren();record.Cycle=crop.HarvestCycle end
     model:SetAttribute('ReadyAt',crop.ReadyAt);model:SetAttribute('HarvestCycle',crop.HarvestCycle)
     model:SetAttribute('PickedMask',crop.PickedMask);model:SetAttribute('FruitReady',ready)
     for index=1,def and def.FruitCount or 0 do
      local name='Harvest_'..index;local existing=prompts:FindFirstChild(name)
      local visible=stage==4 and Rules.FruitReady(crop,index,now)
      if existing and (existing:GetAttribute('FruitCycle')~=Rules.FruitCycle(crop,index)or existing:GetAttribute('Weather')~=Weather.Fruit(crop,index,Rules.FruitCycle(crop,index)))then existing:Destroy();existing=nil end
      if not visible and existing then existing:Destroy()
      elseif visible and not existing then
       local group=Instance.new('Model');group.Name=name;group.ModelStreamingMode=Enum.ModelStreamingMode.Atomic;group:SetAttribute('HarvestIndex',index);group:SetAttribute('FruitCycle',Rules.FruitCycle(crop,index))
       local at=self:GardenFruitPoint(info.Part,crop,index)
       local anchor=Instance.new('Part');anchor.Name='Fruit_'..index;anchor.Size=Vector3.new(.1,.1,.1);anchor.CFrame=CFrame.new(at)
       anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false;anchor.Parent=group
       local trait=Rules.Fruit(crop,index,def)
       group:SetAttribute('Weather',trait.Weather);FX.Set(anchor,trait.Weather,false,math.min(35,(def.FruitRadii[index]or 1)*trait.Scale),math.min(60,(def.FruitRadii[index]or 1)*trait.Scale*1.4))
       if def.Mode~='whole'then Visuals.FruitProxy(group,crop.SeedId,crop,index,origin(info.Part,crop))end
       local prompt=Instance.new('ProximityPrompt');prompt.Name='HarvestPrompt';prompt.ActionText='Harvest';prompt.Style=Enum.ProximityPromptStyle.Custom;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
       prompt.ObjectText=(trait.Weather~='None'and Weather.Display(trait.Weather)..' 'or'')..(trait.Mutation~='None'and trait.Mutation..' 'or'')..(Hologram.Name(crop,index)or def.HarvestName)
       prompt.HoldDuration=0;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.ClickablePrompt=true;prompt.MaxActivationDistance=math.max(self.Config.GardenInteractionDistance,Visuals.FruitReach(crop,def,index));prompt.RequiresLineOfSight=false
       prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
       prompt:SetAttribute('GardenPrompt',true);prompt:SetAttribute('GardenOwnerId',ownerId);prompt:SetAttribute('GardenCropId',crop.Id)
       prompt:SetAttribute('GardenStage',4);prompt:SetAttribute('GardenFruitIndex',index);prompt.Parent=anchor
       group.Parent=prompts
      end
     end
     model:SetAttribute('FruitRevision',fruitKey);record.FruitKey=fruitKey
    end
    Hologram.Prompts(model,crop,origin(info.Part,crop),workspace:GetServerTimeNow(),Visuals)
    describe(model,record,record.Key..':'..stage..':'..fruitKey..':'..tostring(regrowing))
    remember(record,crop,ownerId,now,def,stage,regrowing)
   end
   for id,record in pairs(info.Rendered)do if not seen[id]then record.Model:Destroy();info.Rendered[id]=nil end end
   info.Part:SetAttribute('GardenOwnerId',ownerId);info.Part:SetAttribute('GardenPlantCount',#crops)
  end
  -- End garden refresh.
 end
end
return Runtime
