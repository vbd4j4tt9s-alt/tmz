-- Harvest bag presentation shares plant geometry and effects without touching saved rewards.
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Rules=require(RS:WaitForChild('PlantRules'))
local Effects=require(RS:WaitForChild('PlantEffects'))
local Maw=require(RS:WaitForChild('ObsidianMawMotion'))
local Bells=require(RS:WaitForChild('FrostbellMotion'))
local Batch=require(RS:WaitForChild('PlantAnimationBatch'))
local H={};local entries={};local connection
function H.Build(item,options)
 local id=item.SeedId;local def=Catalog[id];if not def then return nil end
 local saved=item.VisualCrop or item
 local index=math.clamp(math.floor(saved.FruitIndex or 1),1,def.FruitCount)
 local crop={Id=saved.SourceCropId or saved.Id or item.InventoryId or 'preview',SeedId=id,PlantScale=1,SeedScale=1,Mutation=Rules.Mutation(item.Mutation),Weather=require(RS.WeatherTraits).Key(item.Weather),HarvestCycle=saved.HarvestCycle or 0,PickedMask=0,ReadyAt=0}
 local size=options and options.WorldSize and Rules.Scale(item.FruitScale)or 1
 if options and options.WorldSize and def.Mode=='whole'then crop.PlantScale=size end
 crop._VisualHarvest={Index=index,Scale=size,Mutation=crop.Mutation};crop._DetachedHarvest=true
 local model=Visuals.Build(id,CFrame.new(),crop,4,math.huge,index,options and options.Work)
 local center,bounds=require(RS:WaitForChild('HarvestGeometry')).Bounds(model);crop._HarvestCenter=center
 require(RS.ItemEffectAnchor).Set(model,crop.Weather,false,math.max(bounds.X,bounds.Z)*.5,bounds.Y)
 if model.PrimaryPart then model.PrimaryPart:SetAttribute('EffectOffset',model.PrimaryPart.CFrame:PointToObjectSpace(center))end
 model:SetAttribute('HarvestPresentation',true);model:SetAttribute('HarvestIndex',index)
 return model,crop,index
end
function H.Capture(model,crop,index)
 local at=model:GetPivot();local r={Visual=model,Crop=crop,Def=Catalog[crop.SeedId],Origin=at,OnlyFruit=index,Floating={},Container=Instance.new('Model')}
 r.Container.Name='HarvestPresentationEffects';r.Container:SetAttribute('FruitReady',true)
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')and p:GetAttribute('FloatingPetal')then
  local socket=at*CFrame.new(Visuals.FruitSocket(crop,r.Def,index))
  table.insert(r.Floating,{Part=p,Frame=p.CFrame,Center=socket,Local=socket:ToObjectSpace(p.CFrame)})
 end end
 if crop.SeedId=='ObsidianMawSeed'then r.Maw=Maw.Capture(model,at)end
 if crop.SeedId=='SilentFrostbellSeed'then r.Bells=Bells.Capture(model,at)end
 return r
end
function H.Start(r)
 if r.Started then return end;r.Started=true;r.Container.Parent=r.Visual.Parent
 Effects.Create(r.Container,r,r.Def,r.Crop,r.Origin,'normal')
 if r.Visual:FindFirstAncestorOfClass('WorldModel')and r.Crop.Weather~='None'then r.WeatherFX=require(RS.ItemVisualEffects).New(r.Container,r.Crop.Weather,false)end
end
function H.Step(r,t)
 H.Start(r)
 if r.WeatherFX then if not r.WeatherCenter then r.WeatherCenter,r.WeatherSize=require(RS.HarvestGeometry).Bounds(r.Visual)end;local center,size=r.WeatherCenter,r.WeatherSize;require(RS.ItemVisualEffects).Step(r.WeatherFX,CFrame.new(center),math.max(size.X,size.Z)*.5,size.Y,t,1)end
 if not r.Batch then
  local root=r.Visual:FindFirstAncestorOfClass('WorldModel')or workspace
  r.Batch=Batch.new(root)
 end
 local batch=r.Batch
 if r.Maw then Maw.Step(r.Maw,r.Origin,r.Crop.Id,t,batch)end
 if r.Bells then Bells.Step(r.Bells,r.Origin,r.Crop.Id,t,false,batch)end
 for i,p in ipairs(r.Floating)do if p.Part.Parent then
  batch:Set(p.Part,p.Center*CFrame.Angles(0,math.sin(t*.23)*.16,0)*CFrame.new(0,math.sin(t*.72+i)*.075,0)*p.Local)
 end end
 if r.Effects then Effects.Step(r,t,batch,r.Origin)end
 r.LastMoves,r.LastRequests=batch:Flush()
end
function H.Stop(r)
 if not r.Started then return end
 if r.Maw then Maw.Reset(r.Maw,r.Origin)end
 if r.Bells then Bells.Reset(r.Bells,r.Origin)end
 for _,p in ipairs(r.Floating)do if p.Part.Parent then p.Part.CFrame=p.Frame end end
 if r.WeatherFX then require(RS.ItemVisualEffects).Destroy(r.WeatherFX);r.WeatherFX=nil end
 Effects.Clear(r);r.Container.Parent=nil;r.Started=false
end
function H.Destroy(r)H.Stop(r);r.Container:Destroy()end
function H.Visible(viewport)
 if not viewport.Parent then return false end
 local lo=viewport.AbsolutePosition;local hi=lo+viewport.AbsoluteSize
 local p=viewport
 while p do
  if p:IsA('GuiObject')then
   if not p.Visible then return false end
   if p.ClipsDescendants then
    local a,b=p.AbsolutePosition,p.AbsolutePosition+p.AbsoluteSize
    if hi.X<=a.X or hi.Y<=a.Y or lo.X>=b.X or lo.Y>=b.Y then return false end
   end
  elseif p:IsA('LayerCollector')and not p.Enabled then return false end
  p=p.Parent
 end
 return true
end
function H.Update(t,maxModels)
 local models,cost=0,0;maxModels=maxModels or 8
 for _,e in ipairs(entries)do
  if H.Visible(e.Viewport)and models<maxModels and cost+e.Cost<=1000 then
   models+=1;cost+=e.Cost;H.Step(e.State,t)
  elseif e.State.Started then H.Stop(e.State)end
 end
 return models,cost
end
function H.Register(viewport,model,crop,index)
 local e={Viewport=viewport,State=H.Capture(model,crop,index),Cost=0}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then e.Cost+=1 end end
 table.insert(entries,e);local closed=false;local cleanupConnection
 local function cleanup()
  if closed then return end;closed=true
  if cleanupConnection then cleanupConnection:Disconnect()end
  local at=table.find(entries,e);if at then table.remove(entries,at)end;H.Destroy(e.State)
  if #entries==0 and connection then connection:Disconnect();connection=nil end
 end
 cleanupConnection=viewport.Destroying:Connect(cleanup)
 if not connection then
  -- R153 (owner: "fix all jittery type effects"): the previews' fruit motion and weather effects every rendered frame in RenderStepped (20 Hz before);
  -- 8 models / 1000 parts as before, 4 models on phones and below (tier 2 / 1: a preview redraws whenever it moves).
  connection=RunService.RenderStepped:Connect(function()
   local ok,tier=pcall(function()return require(RS.ClientFxBudget).Get()end)
   debug.profilebegin('Harvest animations');H.Update(workspace:GetServerTimeNow(),ok and type(tier)=='number'and tier<3 and 4 or 8);debug.profileend()
  end)
 end
 return cleanup
end
return H
