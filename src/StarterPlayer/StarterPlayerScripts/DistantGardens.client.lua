do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
local Hologram=require(game:GetService('ReplicatedStorage'):WaitForChild('HologramProjection'))
-- Streamed-out gardens use static client silhouettes from small replicated descriptions.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Players=game:GetService('Players')
local Views=require(RS:WaitForChild('DistantPlantView'));local State=require(RS:WaitForChild('GardenViewState'));local Planner=require(RS:WaitForChild('PlantDetailPlanner'));local Catalog=require(RS:WaitForChild('PlantCatalog'));local Visuals=require(RS:WaitForChild('PlantVisuals'))
local source=RS:WaitForChild('GardenViewDescriptions');local map=workspace:WaitForChild('ChestChaseMap');local player=Players.LocalPlayer
local root=Instance.new('Folder');root.Name='DistantGardenViews';root.Parent=workspace
local records,byKey,live,connections={},{},{},{};local job;local selected={};local elapsed=1;local growthElapsed=0;local hologramElapsed=0
local function clear(r)if r.Model then r.Model:Destroy();r.Model=nil end;r.Growing=false end
local function watch(item)
 if not item:IsA('Folder')or records[item]then return end
 local r={Snapshot=item};records[item]=r
 local function bind()
  if r.Key and byKey[r.Key]==r then byKey[r.Key]=nil end
  r.Key=item:GetAttribute('CropId')and State.Key(item)or nil
  if r.Key then byKey[r.Key]=r;if live[r.Key]then clear(r)end end
 end
 bind();r.KeyConnection=item:GetAttributeChangedSignal('CropId'):Connect(bind)
end
local function track(model)if model:IsA('Model')and model:GetAttribute('GardenPlantV141')then local key=State.Key(model);live[key]=model;local r=byKey[key];if r then clear(r)end end end
local function connect(signal,fn)table.insert(connections,signal:Connect(fn))end
for _,item in ipairs(source:GetChildren())do watch(item)end
for _,model in ipairs(map:GetDescendants())do track(model)end
connect(source.ChildAdded,watch);connect(source.ChildRemoved,function(item)local r=records[item];if r then clear(r);r.KeyConnection:Disconnect();if r.Key and byKey[r.Key]==r then byKey[r.Key]=nil end;records[item]=nil end end)
connect(map.DescendantAdded,track);connect(map.DescendantRemoving,function(model)if model:GetAttribute('GardenPlantV141')then local k=State.Key(model);if live[k]==model then live[k]=nil end end end)
local function cancel()
 if not job then return end
 if coroutine.status(job.Thread)~='dead'then coroutine.close(job.Thread)end
 for _,model in ipairs(job.Models)do if not model.Parent then model:Destroy()end end;job=nil
end
local function scan()
 local camera=workspace.CurrentCamera;if not camera then return end
 local entries={};local projection=Planner.View(camera)
 for item,r in pairs(records)do
  local key=r.Key;local streamed=key and live[key];local origin=item:GetAttribute('Origin');local def=Catalog[item:GetAttribute('SeedId')]
  if key and not streamed and origin and def and item:GetAttribute('FruitRevision')then
   local scale=item:GetAttribute('PlantScale')or 1;local radius=math.sqrt(def.Radius^2+(def.Height*.5)^2)*scale
   local center=origin*Vector3.new(0,def.Height*scale*.5,0);local visible,pixels=Planner.Coverage(camera,center,radius,projection);local distance=(center-camera.CFrame.Position).Magnitude-radius
   local visibleEnough=visible and pixels>=5 and distance<Views.Range
   if visibleEnough then r.LastVisible=os.clock()end
   local retained=r.Model and distance<Views.Range and os.clock()-(r.LastVisible or -math.huge)<2
   if visibleEnough or retained then
    local revision=item:GetAttribute('FruitRevision')..':'..tostring(item:GetAttribute('GrowthStage'))
    if r.Revision~=revision then r.Crop=State.Read(item);r.Cost=Views.Cost(r.Crop);r.Revision=revision end
    table.insert(entries,{Record=r,Cost=r.Cost,Score=distance/math.max(1,pixels/40)-(r.Model and 25 or 0)+(visibleEnough and 0 or 100000),Revision=revision,Origin=origin,Visible=visibleEnough})
   end
  end
 end
 local cost,count=Views.Select(entries);selected={}
 for _,e in ipairs(entries)do if e.Selected then selected[e.Record]=e end end
 for _,r in pairs(records)do if not selected[r]then clear(r)end end
 if Run:IsStudio()or player:GetAttribute('ChestChaseCommandsAllowed')then player:SetAttribute('DistantPlantBudget',cost);player:SetAttribute('DistantPlantModels',count)end
end
connect(Run.Heartbeat,function(dt)
 elapsed+=dt;growthElapsed+=dt;hologramElapsed+=dt
 if elapsed>=.4 then elapsed=0;scan()end
 if job and(not records[job.Record.Snapshot]or not selected[job.Record]or job.Record.Revision~=job.Revision)then cancel()end
 if not job then for r,e in pairs(selected)do if e.Visible and(not r.Model or r.Applied~=e.Revision)and os.clock()>=(r.Retry or 0)then
  local j={Record=r,Revision=e.Revision,Models={}};local work={Model=function(m)table.insert(j.Models,m)end}
  work.BeforePart=function(cost)if j.Parts<cost or os.clock()>=j.Deadline then coroutine.yield()end;j.Parts-=cost end
  j.Thread=coroutine.create(function()
   local model,growing=Views.Build(r.Crop,e.Origin,workspace:GetServerTimeNow(),work)
   if not selected[r]or live[r.Key]then model:Destroy();return end
   clear(r);model.Parent=root;r.Model=model;r.Growing=growing;r.Applied=e.Revision
  end);job=j;break
 end end end
 if job then
  job.Parts=32;job.Deadline=os.clock()+.001;local okay,why=coroutine.resume(job.Thread)
  if not okay then job.Record.Retry=os.clock()+5;warn('[V149] Distant plant view: '..tostring(why));cancel()
  elseif coroutine.status(job.Thread)=='dead'then job=nil end
 end
 if growthElapsed>=2 then
  growthElapsed=0;local now=workspace:GetServerTimeNow()
  for r in pairs(selected)do if r.Model and r.Growing then Visuals.UpdateGrowth(r.Model,r.Crop,now)end end
 end
 if hologramElapsed>=.1 then
  hologramElapsed=0;local now=workspace:GetServerTimeNow()
  for r,e in pairs(selected)do if r.Model then Hologram.Apply(r.Model,r.Crop,e.Origin,now)end end
 end
end)
script.Destroying:Connect(function()for _,c in ipairs(connections)do c:Disconnect()end;cancel();for _,r in pairs(records)do r.KeyConnection:Disconnect();clear(r)end;table.clear(byKey);root:Destroy()end)
