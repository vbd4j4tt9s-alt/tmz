local Fx=require(game:GetService('ReplicatedStorage'):WaitForChild('ClientFxBudget'))
local Hologram=require(game:GetService('ReplicatedStorage'):WaitForChild('HologramProjection'))
local hologramEntries={}
-- V149 revision 20: cached cosmetic poses, deduplicated moves and bounded construction.
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Rules=require(RS:WaitForChild('PlantRules'))
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Growth=require(RS:WaitForChild('PlantGrowth'))
local Maw=require(RS:WaitForChild('ObsidianMawMotion'))
local Bells=require(RS:WaitForChild('FrostbellMotion'))
local Effects=require(RS:WaitForChild('PlantEffects'))
local Trees=require(RS:WaitForChild('TreeReworkMotion'))
local Batch=require(RS:WaitForChild('PlantAnimationBatch'))
local animationBatch=Batch.new(workspace)
local Planner=require(RS:WaitForChild('PlantDetailPlanner'))
local PackRules=require(RS:WaitForChild('SeedPackRules'))
-- R112: dirt pile + sound when a crop is freshly planted, and a growth-point mark while it stands.
-- Cosmetic only: if it cannot start, plant visuals carry on without it.
local okPlanting,Planting=pcall(function()return require(RS:WaitForChild('PlantingEffects')).new()end)
if not okPlanting then warn('[R112] Planting effects off: '..tostring(Planting));Planting={Add=function()end,Remove=function()end,Destroy=function()end}end
script.Destroying:Connect(function()Planting:Destroy()end)
local meshWarnings={}
-- Keep existing animation caps. Only spare capacity reaches visible, readable distant models.
local function motionVisible(entry,near,far)
 return entry.OnScreen and(entry.Distance<near or(entry.Distance<far and entry.Pixels>=24))
end
local map=workspace:WaitForChild('ChestChaseMap');local tracked={};local ordered={}
local builds,fruitUpdates=0,0
local buildQueue={};local queueIndex=1
local activeBuild=nil
local lastBuildParts=0
local lastAnimationMoves,lastAnimationRequests,lastAnimationMs=0,0,0
local function resetPetals(r)
 if r.Floating then for _,entry in ipairs(r.Floating)do if entry.Part.Parent then entry.Part.CFrame=entry.Frame end end end
 r.Floating=nil;r.PetalsMoving=false
end
local function hidePart(p,hidden)
 -- R148: a Decal (Verity's face on her ball) ignores its part's modifier, so it is hidden with its part.
 if p:IsA('BasePart')or p:IsA('Decal')then p.LocalTransparencyModifier=hidden and 1 or 0 end
end
local function hideSupports(item,r,hidden)
 local key=hidden and(r.AppliedModeKey or'full')or'none'
 if r.HiddenKey==key then return end;r.HiddenKey=key;r.Hidden=hidden
 local full=hidden and not r.FruitOnly
 local solid=item:FindFirstChild('SolidPlant');if solid then for _,p in ipairs(solid:GetDescendants())do hidePart(p,full)end end
 local growing=item:FindFirstChild('GrowingFruit');if growing then for _,p in ipairs(growing:GetDescendants())do hidePart(p,full)end end
 local fruit=item:FindFirstChild('FruitPrompts');if fruit then for _,p in ipairs(fruit:GetDescendants())do
  if p:IsA('BasePart')or p:IsA('Decal')then -- R148: the Verity proxy ball's face Decals hide with it
   local index=p:GetAttribute('HarvestIndex');local group=p.Parent
   while not index and group and group~=fruit do index=group:GetAttribute('HarvestIndex')or tonumber(group.Name:match('^Harvest_(%d+)$'));group=group.Parent end
   hidePart(p,full or(hidden and r.Selection and r.Selection[index]==true))
  end
 end end
end
local clearEffects=Effects.Clear
local function clear(item,r,keepWork)
 if r.Maw then Maw.Reset(r.Maw,r.Origin);r.Maw=nil end
 if r.Build and not keepWork then r.Build.Cancelled=true end
 resetPetals(r)
 if r.Bells then Bells.Reset(r.Bells,r.Origin);r.Bells=nil end
 clearEffects(r)
 if r.Visual then r.Visual:Destroy();r.Visual=nil end
 r.Rig=nil;r.Pose=nil;r.QueuePose=false;r.Swaying=false;r.Key=nil;r.FruitKey=nil;r.FxKey=nil;hideSupports(item,r,false)
end
local function track(item,initial)
 if not item:IsA('Model')or not item:GetAttribute('GardenPlantV141')or tracked[item]then return end
 local r={};tracked[item]=r;Planting:Add(item,initial==true)
 r.Connection=item.DescendantAdded:Connect(function(p)
  -- Parent replication can arrive before FruitProxy/HarvestIndex attributes.
  -- Coalesce the whole support update instead of relying on those attributes at this event.
  local branch=p;while branch.Parent and branch.Parent~=item do branch=branch.Parent end
  if branch.Name=='SolidPlant'or branch.Name=='GrowingFruit'or branch.Name=='FruitPrompts'then r.SupportsDirty=true end
 end)
end
for _,item in ipairs(map:GetDescendants())do track(item,true)end
map.DescendantAdded:Connect(function(item)track(item,false)end)
map.DescendantRemoving:Connect(function(item)
 local r=tracked[item];if r then tracked[item]=nil;r.Connection:Disconnect();clear(item,r);Planting:Remove(item) end
end)
local function data(item)
 return require(RS.GardenViewState).Read(item)
end
-- Species effects and rarity auras are local, distance limited and tied to ripe harvests.
local function effectKey(item,r,stage)
 if not r.WantEffects or stage~=4 or(not item:GetAttribute('FruitReady')and not Trees.Has(item:GetAttribute('SeedId')))then return nil end
 return r.Mode..':'..tostring(item:GetAttribute('FruitRevision')or'')
end
local function syncFruit(item,r,crop,def,stage,at,work)
 local revision=item:GetAttribute('FruitRevision')or''
 if r.FruitKey==revision then return end
 resetPetals(r)
 if r.Bells then Bells.Reset(r.Bells,r.Origin);r.Bells=nil end
 if stage<4 then r.FruitKey=revision;return end
 local now=workspace:GetServerTimeNow();local ripe=item:GetAttribute('FruitReady')==true
 for index=1,def.FruitCount do
  local name='Harvest_'..index;local child=r.Visual:FindFirstChild(name)
  local visible=(not r.FruitOnly or r.Selection[index])and not Rules.IsPicked(crop,index)
  local ripe=Rules.FruitReady(crop,index,now);local cycle=Rules.FruitCycle(crop,index)
  if child and(not visible or child:GetAttribute('FruitCycle')~=cycle)then child:Destroy();child=nil end
  if visible and not child then
   local source=table.clone(crop);source.ReadyAt=0
   local art=Visuals.Build(crop.SeedId,at,source,4,math.huge,index,work)
   child=art:FindFirstChild(name);if child then
    child:SetAttribute('FruitCycle',cycle);child.Parent=r.Visual
    if not ripe then Visuals.BeginGrowth(child,crop.SeedId,crop,at);Visuals.UpdateGrowth(child,crop,now)end
   end
   art:Destroy();fruitUpdates+=1
  elseif child and ripe then Visuals.EndGrowth(child,crop,now)end
 end
 r.Cycle=crop.HarvestCycle;r.FruitKey=revision
end
local function updateEffects(item,r,def,crop,at,stage)
 local fxKey=effectKey(item,r,stage)
 if r.FxKey~=fxKey then
  clearEffects(r);r.FxKey=fxKey
  if fxKey then Effects.Create(item,r,def,crop,at,r.Mode)end
 end
end
local function show(item,r,work)
 if not r.WantDetail then clear(item,r);return end
 local crop=data(item);local def=Catalog[crop.SeedId];local anchor=item:FindFirstChild('CropAnchor')
 if not def or not anchor or crop.ReadyAt==nil then return end
 local stage=item:GetAttribute('GrowthStage')or 1
 local ready,meshKey,meshError=Visuals.DetailReady(crop.SeedId,crop,r.DetailMode=='fruit'and r.Selected or nil)
 if not ready then
  r.RetryAt=os.clock()+(meshError and 5 or .3)
  if meshError and not meshWarnings[meshKey]then
   meshWarnings[meshKey]=true;warn('[R50 plants] '..meshError)
  end
  -- Keep the server silhouette or previous complete detail until the needed template arrives.
  return
 end
 local key=table.concat({crop.SeedId,stage==4 and 'mature'or 'growing',crop.PlantScale,crop.Mutation,Visuals.AssetRevision(),r.DesiredModeKey},':')
 if r.Visual and r.Key==key and r.FruitKey==(item:GetAttribute('FruitRevision')or'')and not r.Growing and stage==4 and not item:GetAttribute('FruitGrowing')then
  updateEffects(item,r,def,crop,anchor.CFrame,stage);return
 end
 if r.Key~=key then
  local fruitOnly=r.DetailMode=='fruit';local selection=r.Selected;local modeKey=r.DesiredModeKey
  local okay,visual=pcall(function()
   if fruitOnly then return Visuals.BuildSelectedFruit(crop.SeedId,anchor.CFrame,crop,selection,workspace:GetServerTimeNow(),work)end
   return Visuals.Build(crop.SeedId,anchor.CFrame,crop,stage,workspace:GetServerTimeNow(),nil,work)
  end)
  if not okay then r.RetryAt=os.clock()+5;warn('[V142] Plant detail fallback: '..tostring(visual));return end
  -- Commit without yielding: keep the previous complete model until its replacement is ready.
  clear(item,r,true);r.FruitOnly=fruitOnly;r.Selection=selection;r.AppliedModeKey=modeKey
  visual.Name='LocalPlantArt';visual.Parent=item;r.Visual=visual;r.Key=key;r.AssetRevision=Visuals.AssetRevision();builds+=1
  r.Cycle=crop.HarvestCycle;r.FruitKey=nil;hideSupports(item,r,true)
 end
 if r.Rig then animationBatch:Pose(r.Rig,r.Origin);animationBatch:Flush();r.Swaying=false end
 if r.Maw then Maw.Reset(r.Maw,r.Origin);r.Maw=nil end
 if r.Bells then Bells.Reset(r.Bells,r.Origin);r.Bells=nil end
 r.Rig=nil;r.Pose=nil
 r.Crop=crop;r.Def=def;r.Origin=anchor.CFrame;r.Growing=stage<4 or not item:GetAttribute('FruitReady')or item:GetAttribute('FruitGrowing')==true
 syncFruit(item,r,crop,def,stage,anchor.CFrame,work)
 if not r.Growing and not r.FruitOnly then r.Rig=Batch.Capture(r.Visual,r.Origin)end
 r.Pose=r.Origin
 -- Camera selection never changes the art key or rebuilds the body.
 if (crop.SeedId=='OrbitLotusSeed'or crop.SeedId=='SupernovaBloomSeed')and not r.Growing and not r.Floating then
  r.Floating={}
  -- Use the crop anchor and saved fruit socket, never a drifting model pivot.
  local center=anchor.CFrame*CFrame.new(Visuals.FruitSocket(crop,def,1)*Rules.Scale(crop.PlantScale))
  for _,part in ipairs(r.Visual:GetDescendants())do
   if part:IsA('BasePart')and part:GetAttribute('FloatingPetal')then
    table.insert(r.Floating,{Part=part,Frame=part.CFrame,Center=center,Local=center:ToObjectSpace(part.CFrame),Scale=Rules.Fruit(crop,1,def).Scale})
   end
  end
 end
 updateEffects(item,r,def,crop,anchor.CFrame,stage)
end
-- One resumable job at a time. Partial models remain unparented, with the
-- server silhouette visible until a complete replacement is ready.
local function signature(item)
 local values={}
 for _,key in ipairs({'SeedId','CropId','PlantScale','Mutation','FruitRevision','ReadyAt','MatureAt','PlantedAt'})do table.insert(values,tostring(item:GetAttribute(key)))end
 table.insert(values,(item:GetAttribute('GrowthStage')or 1)==4 and 'mature'or 'growing')
 return table.concat(values,':')
end
local function finishJob(job)
 for _,model in ipairs(job.Models)do if not model.Parent then model:Destroy()end end
 if coroutine.status(job.Thread)~='dead'then coroutine.close(job.Thread)end
 job.Record.Build=nil;activeBuild=nil
end
local animateClock=0;local frameAverage=1/60
RunService.Heartbeat:Connect(function(dt)
 animateClock+=dt;frameAverage+=(math.min(dt,.1)-frameAverage)*.05
 for _,entry in ipairs(ordered)do local r=entry.Record
  if r.SupportsDirty then r.SupportsDirty=false;r.HiddenKey=nil;hideSupports(entry.Item,r,r.Hidden==true)end
 end
 if activeBuild and(activeBuild.Cancelled or not tracked[activeBuild.Item]or not activeBuild.Record.WantDetail or signature(activeBuild.Item)~=activeBuild.Signature or activeBuild.ModeKey~=activeBuild.Record.DesiredModeKey)then
  activeBuild.Record.Dirty=true;finishJob(activeBuild)
 end
 if not activeBuild then
  while queueIndex<=#buildQueue do
   local entry=buildQueue[queueIndex];queueIndex+=1
   local item,r=entry.Item,entry.Record
   if tracked[item]and r.WantDetail and r.Dirty and os.clock()>=(r.RetryAt or 0)then
    r.Dirty=false
    local job={Item=item,Record=r,Models={},Signature=signature(item),ModeKey=r.DesiredModeKey}
    local work={Model=function(model)table.insert(job.Models,model)end}
    work.BeforePart=function(cost)
     if job.Remaining<cost or os.clock()>=job.Deadline then coroutine.yield()end
     job.Remaining-=cost
    end
    job.Thread=coroutine.create(function()show(item,r,work)end)
    r.Build=job;activeBuild=job;break
   end
  end
 end
 lastBuildParts=0
 if activeBuild then
  local job=activeBuild;local limit=(Fx.Low()or frameAverage>1/40)and 12 or 32;job.Limit=limit;job.Remaining=limit;job.Deadline=os.clock()+(limit==12 and .00075 or .002)
  local okay,why=coroutine.resume(job.Thread);lastBuildParts=job.Limit-job.Remaining
  if not okay then
   job.Record.RetryAt=os.clock()+5;clear(job.Item,job.Record);warn('[V149] Plant detail fallback: '..tostring(why))
  end
  if not okay or coroutine.status(job.Thread)=='dead'then finishJob(job)end
 end
 if RunService:IsStudio()or player:GetAttribute('ChestChaseCommandsAllowed')then player:SetAttribute('PlantBuildInProgress',activeBuild~=nil)end
 if animateClock<(Fx.Low()and .1 or 1/20)then return end;animateClock=0
 debug.profilebegin('Plant animations');local animationStarted=os.clock()
 local t=workspace:GetServerTimeNow()
 for _,entry in ipairs(ordered)do
  local r=entry.Record;r.MotionDue=entry.Distance<75 or t>=(r.NextMotionAt or 0)
  if r.MotionDue then r.NextMotionAt=t+.1 end
 end
 do
  local now=t;local windParts,windModels=0,0
  for _,entry in ipairs(ordered)do
   local r=entry.Record
   if r.Visual and not r.Build and r.Crop and r.Origin then
    if r.Growing then
     -- R121: growth takes 70+ s. Plants within 75 studs keep the full 20 Hz; farther ones refresh at
     -- 10 Hz (MotionDue) on screen and 2 Hz off screen. Each refresh rewrites every part of the plant.
     if entry.Distance<75 or(r.MotionDue and(entry.OnScreen or now>=(r.NextGrowthAt or 0)))then
      r.NextGrowthAt=now+.5
      Visuals.UpdateGrowth(r.Visual,r.Crop,now)
      for index=1,r.Def.FruitCount do local child=r.Visual:FindFirstChild('Harvest_'..index);if child then Visuals.UpdateGrowth(child,r.Crop,now)end end
     end
    elseif not Hologram.Is(r.Crop.SeedId)and not r.FruitOnly and r.Crop.SeedId~='ObsidianMawSeed'and r.Mode=='normal'and motionVisible(entry,65,220) and windModels<6 and windParts+entry.Cost<=600 then
     windParts+=entry.Cost;windModels+=1
     if r.MotionDue then r.Pose=r.Origin*Growth.Sway(r.Crop.SeedId,r.Def,r.Crop,now);r.Rig=r.Rig or Batch.Capture(r.Visual,r.Origin);r.QueuePose=true;r.Swaying=true end
    elseif r.Swaying then r.Pose=r.Origin;r.QueuePose=true;r.Swaying=false end
   end
  end
 end
 local bellCount,petalModels,petalParts,mawCount=0,0,0,0
 for _,entry in ipairs(ordered)do
  local r=entry.Record
  if r.Visual and not r.Build and r.Crop and r.Crop.SeedId=='ObsidianMawSeed'and not r.Growing and r.Mode=='normal'and motionVisible(entry,65,180) and mawCount<2 then
   mawCount+=1;if not r.Maw then r.Maw=Maw.Capture(r.Visual,r.Origin)end;if r.MotionDue then Maw.Step(r.Maw,r.Origin,r.Crop.Id,t,animationBatch)end
  elseif r.Maw then Maw.Reset(r.Maw,r.Origin,animationBatch);r.Maw=nil end
  if r.Visual and not r.Build and r.Crop and r.Crop.SeedId=='SilentFrostbellSeed'and not r.Growing and r.Mode=='normal'and motionVisible(entry,45,160) and bellCount<2 then
   bellCount+=1
   if not r.Bells then
    local pose=r.Visual:GetPivot();r.Visual:PivotTo(r.Origin);r.Bells=Bells.Capture(r.Visual,r.Origin);r.Visual:PivotTo(pose)
   end
   if r.MotionDue then Bells.Step(r.Bells,r.Pose or r.Origin,r.Crop.Id,t,entry.Distance<32,animationBatch)end
  elseif r.Bells then Bells.Reset(r.Bells,r.Pose or r.Origin,animationBatch);r.Bells=nil end
  if r.Floating and not r.Build then
   local animate=r.Mode=='normal'and not r.Growing and motionVisible(entry,65,180) and petalModels<2 and petalParts+#r.Floating<=12
   if animate then
    r.PetalsMoving=true;petalModels+=1;petalParts+=#r.Floating
    if r.MotionDue then
    local transform=(r.Pose or r.Origin)*r.Origin:Inverse();local orbit=CFrame.Angles(0,math.sin(t*.23)*.16,0)
    for i,petal in ipairs(r.Floating)do if petal.Part.Parent then
     local bob=math.sin(t*.72+i)*.075*petal.Scale
     animationBatch:Set(petal.Part,transform*petal.Center*orbit*CFrame.new(0,bob,0)*petal.Local)
    end end
    end
   elseif r.PetalsMoving then
    for _,petal in ipairs(r.Floating)do if petal.Part.Parent then animationBatch:Set(petal.Part,(r.Pose or r.Origin)*r.Origin:Inverse()*petal.Frame) end end;r.PetalsMoving=false
   end
  end
  -- Overrides are queued first, so the body computes only the remaining part poses.
  if r.QueuePose then animationBatch:Pose(r.Rig,r.Pose,true);r.QueuePose=false end
  if r.Effects and r.Visual and r.MotionDue then Effects.Step(r,t,animationBatch,r.Pose or r.Origin)end

 end
 for _,entry in ipairs(hologramEntries)do
  if entry.Distance<75 or t>=(entry.HologramDue or 0)then
   entry.HologramDue=t+.1
   local at=entry.Record.Anchor and entry.Record.Anchor.CFrame
   if at and entry.ShapeCrop then
    Hologram.Apply(entry.Item,entry.ShapeCrop,at,t,animationBatch)
    Hologram.Prompts(entry.Item,entry.ShapeCrop,at,t,Visuals)
   end
  end
 end
 lastAnimationMoves,lastAnimationRequests=animationBatch:Flush();lastAnimationMs=(os.clock()-animationStarted)*1000
 debug.profileend()
end)
task.spawn(function()
 while script.Parent do
  local camera=workspace.CurrentCamera
  if camera then
   local projection=Planner.View(camera)
   local list={};local mode=player:GetAttribute('StudioPlantEffects')or'normal';mode=mode or'normal';if Fx.Low()and mode~='off'then mode='low'end
   for item,r in pairs(tracked)do
    local id=item:GetAttribute('SeedId');local def=Catalog[id]
    local anchor=r.Anchor;if not anchor or not anchor.Parent then anchor=item:FindFirstChild('CropAnchor');r.Anchor=anchor end
    if anchor and def then
     local scale=item:GetAttribute('PlantScale')or 1
     local q=anchor.CFrame:PointToObjectSpace(camera.CFrame.Position)
     local dx=math.max(0,math.abs(q.X)-def.Radius*scale);local dz=math.max(0,math.abs(q.Z)-def.Radius*scale)
     local dy=math.max(0,-q.Y,q.Y-def.Height*scale);local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
     -- Existing detail gets a small retention margin to prevent camera-boundary churn.
     if distance<Planner.FarRange then
      local entry=r.Entry
      if not entry or entry.SeedId~=id then entry={Item=item,Record=r,SeedId=id,FullCost=Visuals.DetailCost(id,data(item))+4+2*def.FruitCount};r.Entry=entry end
      entry.SortKey=tostring(item:GetAttribute('CropId')or id);entry.Distance=distance;entry.Radius=math.sqrt((def.Height*scale*.5)^2+(def.Radius*scale)^2)
      entry.OnScreen,entry.Pixels=Planner.Coverage(camera,anchor.CFrame*Vector3.new(0,def.Height*scale*.5,0),entry.Radius,projection)
      entry.Score=distance/math.max(1,entry.Pixels/90)+(entry.OnScreen and 0 or 180)-(r.Visual and 24 or 0)
      entry.Ripe=item:GetAttribute('FruitReady')==true and item:GetAttribute('GrowthStage')==4
      local shapeKey=tostring(item:GetAttribute('FruitRevision'))..':'..scale
      if entry.ShapeKey~=shapeKey then
       entry.ShapeKey=shapeKey;entry.Shapes={};entry.FruitPool={};local crop=data(item);entry.ShapeCrop=crop;local meta=Visuals.Metadata(id,crop)
       for index=1,def.FruitCount do if Rules.FruitReady(crop,index,workspace:GetServerTimeNow())then
        local trait=Rules.Fruit(crop,index,def);local cost=1
        for _,spec in ipairs(meta.Groups[index]or{})do cost+=Visuals.PartCost(spec)end
        table.insert(entry.Shapes,{Index=index,Center=anchor.CFrame:PointToWorldSpace(Visuals.FruitPosition(crop,def,index)),Radius=(def.FruitRadii[index]or .5)*trait.Scale,Cost=cost})
       end end
      end
      entry.Fruits=entry.Fruits or{};table.clear(entry.Fruits)
      for _,shape in ipairs(entry.Shapes)do
       if Hologram.Is(id)then shape.Center=anchor.CFrame:PointToWorldSpace(Visuals.FruitPosition(entry.ShapeCrop,def,shape.Index))end
       local visible,pixels=Planner.Coverage(camera,shape.Center,shape.Radius,projection)
       local fruit=entry.FruitPool[shape.Index]
       if not fruit then fruit={Index=shape.Index,Cost=shape.Cost};entry.FruitPool[shape.Index]=fruit end
       fruit.Visible=visible;fruit.Pixels=pixels;table.insert(entry.Fruits,fruit)
      end
      table.sort(entry.Fruits,function(a,b)return a.Pixels>b.Pixels end)
      table.insert(list,entry)
     else
      r.WantDetail=false;r.Dirty=false;if r.Visual or r.Build then clear(item,r)end
     end
    end
   end
   Planner.Select(list,Fx.Low())
   -- Detail selection still uses projected size; motion and build scheduling now prefer nearby entries.
   table.sort(list,function(a,b)if a.Distance~=b.Distance then return a.Distance<b.Distance end;if a.Score~=b.Score then return a.Score<b.Score end;return a.SortKey<b.SortKey end)
   local cost,count,fx,live,triangles=0,0,0,0,0
   local active,pending={},{}
   for _,entry in ipairs(list)do
    local item,r=entry.Item,entry.Record
    local detail=entry.DetailMode~=nil
    if detail then cost+=entry.Cost;count+=1;triangles+=Visuals.Metadata(item:GetAttribute('SeedId')).MeshTriangles end
    local mask=0;if entry.Selected then for index in pairs(entry.Selected)do mask+=2^(index-1)end end
    r.DetailMode=entry.DetailMode;r.Selected=entry.Selected;r.DesiredModeKey=(entry.DetailMode or'none')..':'..mask
    local def=Catalog[item:GetAttribute('SeedId')];local eligible=Effects.Profile(def,item:GetAttribute('SeedId'))~=nil or PackRules.Rarities[def.Rarity].Rank>=4 or item:GetAttribute('Mutation')~='None'
    local effects=detail and eligible and(item:GetAttribute('FruitReady')==true or(item:GetAttribute('GrowthStage')==4 and Trees.Has(item:GetAttribute('SeedId'))and entry.DetailMode~='fruit'))and mode~='off'and fx<(mode=='low'and 2 or 4)and(entry.Distance<75 or motionVisible(entry,75,160))
    if effects then fx+=1 end
    if r.Effects and(not effects or r.Mode~=mode)then clearEffects(r);r.FxKey=nil end
    r.WantDetail=detail;r.WantEffects=effects;r.Mode=mode
    if not detail and(r.Visual or r.Build)then clear(item,r);r.FxKey=nil end
    r.Dirty=detail and not r.Build and(not r.Visual or r.AssetRevision~=Visuals.AssetRevision()or r.FruitKey~=(item:GetAttribute('FruitRevision')or'')or r.FxKey~=effectKey(item,r,item:GetAttribute('GrowthStage')or 1)or r.Stage~=(item:GetAttribute('GrowthStage')or 1)or r.AppliedModeKey~=r.DesiredModeKey)
    r.Stage=item:GetAttribute('GrowthStage')or 1
    if detail then table.insert(active,entry);if r.Dirty then table.insert(pending,entry)end end
    if r.Visual then live+=1 end
   end
   ordered=active;buildQueue=pending;queueIndex=1
   hologramEntries={};local holoCost=0
   for _,entry in ipairs(list)do
    if Hologram.Is(entry.SeedId)and(entry.OnScreen or entry.Distance<75)and #hologramEntries<12 and holoCost+entry.FullCost*2<=5000 then
     holoCost+=entry.FullCost*2;table.insert(hologramEntries,entry)
    end
   end
   if RunService:IsStudio()or player:GetAttribute('ChestChaseCommandsAllowed')then
    player:SetAttribute('PlantAnimationMoves',lastAnimationMoves);player:SetAttribute('PlantAnimationRequests',lastAnimationRequests);player:SetAttribute('PlantAnimationStepMs',lastAnimationMs)
    player:SetAttribute('PlantMeshTriangles',triangles);player:SetAttribute('PlantDetailModels',live);player:SetAttribute('PlantDetailBudget',cost)
    player:SetAttribute('PlantBuildPartLimit',(Fx.Low()or frameAverage>1/40)and 12 or 32);player:SetAttribute('PlantBuildPartsLastStep',lastBuildParts)
    player:SetAttribute('PlantAnimationEntries',#active);player:SetAttribute('PlantBuildQueue',#pending);player:SetAttribute('PlantDetailRange',Planner.FarRange)
    player:SetAttribute('PlantEffectModels',fx);player:SetAttribute('PlantArtBuilds',builds);player:SetAttribute('PlantFruitUpdates',fruitUpdates)
   end
  end
  task.wait(.3)
 end
end)
