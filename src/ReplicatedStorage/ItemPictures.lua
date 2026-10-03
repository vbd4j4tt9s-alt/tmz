-- R112: pictures for inventory cards and hotbar slots, built from the game's own art modules.
-- One template per item look (LRU); only visible holders clone it into a ViewportFrame, within a
-- view/part budget and a few clones per frame.
-- R113: released views are parked per look and reused (no rebuild while scrolling); holders just outside a
-- scroll window stay warm; list looks are prefetched; clones are time-budgeted and hurry while scrolling.
-- R137 (owner: "sometimes the lower icon versions of the packs and seeds show up [in the hotbar and spinning things]
-- remove those from the game ... they don't get replaced with the low render versions at all"): the flat 2D icons are
-- gone. A picture on screen is always the real 3D model: no view/part cap, no Low-graphics swap. While a look is still
-- being built the holder stays empty (builds now run several per frame while something on screen waits, and
-- P.Warm builds a set of looks ahead, e.g. the bonus reel). The caps only limit off-screen (warm/parked) views.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Players=game:GetService('Players');local Tags=game:GetService('CollectionService')
local P={MaxTemplates=160,MaxViews=60,MaxParts=9000,MaxWarm=36,WarmParts=4000,WaitBuildSeconds=.008,WarmMargin=240,MaxSpare=48,SpareParts=4000,GuessParts=60,
 CloneSeconds=.0015,HurryCloneSeconds=.004,HurrySeconds=.4,BuildSeconds=.002,HurryBuildSeconds=.004,BuildParts=24,SweepSeconds=.2,Grace=3,RetrySeconds=15,LoadingRetrySeconds=2}
local RGB=Color3.fromRGB
local records=setmetatable({},{__mode='k'});local templates={};local templateCount=0
local queue={};local queued={};local failed={};local fills={};local job;local connection;local sweepClock=0;local dirty=false
local spare={};local spareCount,spareParts=0,0;local listed={};local warned={};local hurryUntil=0;local cloneSpent=0
local function mutationKey(value)return(value=='Gold'or value=='Diamond')and value or'None'end
-- Same crop identity HarvestPresentation.Build uses, so the key matches what it draws.
local function harvestCrop(tool,id)
 return {Id=tool:GetAttribute('SourceCropId')or tool:GetAttribute('HarvestInventoryId')or'preview',SeedId=id,PlantScale=1,SeedScale=1,
  Mutation=mutationKey(tool:GetAttribute('Mutation')),Weather='None',HarvestCycle=tool:GetAttribute('HarvestCycle')or 0,PickedMask=0,ReadyAt=0}
end
local function fruitKey(id,index,crop)
 local art=''
 local ok,value=pcall(function()return require(RS.ApprovedPlantArt).Key(id,crop)..require(RS.PlantSurfaceStyle).Key(id,crop)end)
 if ok and type(value)=='string'then art=value end
 return table.concat({'Fruit',id,index,crop.Mutation,art},'|'),{Kind='Fruit',Id=id,Index=index,Mutation=crop.Mutation,Crop=crop}
end
function P.Key(tool)
 if not tool then return nil end
 if tool:GetAttribute('SeedPackTool')then
  local stage=tonumber(tool:GetAttribute('Stage'))or 1;local variant=tool:GetAttribute('BagVariant')or'Standard';local mutation=mutationKey(tool:GetAttribute('PackMutation'))
  return table.concat({'Pack',stage,variant,mutation},'|'),{Kind='Pack',Stage=stage,Variant=variant,Mutation=mutation}
 end
 if tool:GetAttribute('GardenSeed')then
  local id=tool:GetAttribute('SeedId')or'';local mutation=mutationKey(tool:GetAttribute('Mutation'))
  return table.concat({'Seed',id,mutation},'|'),{Kind='Seed',Id=id,Mutation=mutation}
 end
 if tool:GetAttribute('HarvestItemTool')then
  local id=tool:GetAttribute('SeedId')or'';local index=math.max(1,math.floor(tonumber(tool:GetAttribute('FruitIndex'))or 1))
  return fruitKey(id,index,harvestCrop(tool,id))
 end
 local name='Tool:'..tool.Name
 if tool:GetAttribute('GardenShovel')then name='Shovel'
 elseif tool:GetAttribute('ChestChaseBat')then name='Bat:'..tostring(tool:GetAttribute('BatAppearanceAssetId'))..':'..tostring(tool:GetAttribute('BatAppearanceVersion'))
 elseif tool:GetAttribute('LootItemTool')then name='Loot:'..tostring(tool:GetAttribute('LootName')or tool.Name)end
 return 'Tool|'..name,{Kind='Tool',Tool=tool,Shovel=tool:GetAttribute('GardenShovel')==true}
end
-- R113: representative looks for the inventory category tabs (same templates as real items).
function P.SampleKey(name)
 if name=='All'then return 'Pack|1|Standard|None',{Kind='Pack',Stage=1,Variant='Standard',Mutation='None'}end
 if name=='Seeds'then return 'Seed|SunflowerSeed|None',{Kind='Seed',Id='SunflowerSeed',Mutation='None'}end
 if name=='Fruit'then
  return fruitKey('AppleSeed',1,{Id='preview',SeedId='AppleSeed',PlantScale=1,SeedScale=1,Mutation='None',Weather='None',HarvestCycle=0,PickedMask=0,ReadyAt=0})
 end
 return 'Tool|Shovel',{Kind='Tool',Shovel=true}
end
-- Static geometry only: no scripts, effects, lights, sounds, joints or CollectionService tags.
local keep={DataModelMesh=true,SurfaceAppearance=true,Decal=true,Model=true,Folder=true}
local function sanitize(model)
 for _,tag in ipairs(Tags:GetTags(model))do Tags:RemoveTag(model,tag)end
 for _,item in ipairs(model:GetDescendants())do
  if item.Parent then
   for _,tag in ipairs(Tags:GetTags(item))do Tags:RemoveTag(item,tag)end
   if item:IsA('BasePart')then
    if item.Transparency>=.95 then item:Destroy()
    else item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false end
   else
    local allowed=false;for class in pairs(keep)do if item:IsA(class)then allowed=true;break end end
    if not allowed then item:Destroy()end
   end
  end
 end
 local parts=0;for _,item in ipairs(model:GetDescendants())do if item:IsA('BasePart')then parts+=1 end end
 return parts
end
local views={Pack=Vector3.new(0,.1,-1),Seed=Vector3.new(.35,.22,-1),Fruit=Vector3.new(.45,.35,-1),Tool=Vector3.new(.3,.2,-1)}
local function aim(model,kind)
 local center,size=require(RS:WaitForChild('HarvestGeometry')).Bounds(model)
 local direction=(views[kind]or views.Tool).Unit;local fov=30
 local frame=CFrame.lookAt(center+direction,center);local hx,hy,hz=0,0,0
 for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
  local v=Vector3.new(size.X*x,size.Y*y,size.Z*z)
  hx=math.max(hx,math.abs(v:Dot(frame.RightVector)));hy=math.max(hy,math.abs(v:Dot(frame.UpVector)));hz=math.max(hz,math.abs(v:Dot(direction)))
 end end end
 local distance=math.max(hx,hy,.05)/math.tan(math.rad(fov/2))*1.14+hz
 return CFrame.lookAt(center+direction*distance,center),fov
end
local function toolModel(spec,work)
 local model=Instance.new('Model');model.Name='ToolPicture'
 if spec.Shovel then
  local holder=Instance.new('Folder');local handle=Instance.new('Part');handle.CFrame=CFrame.new()
  local built=require(RS:WaitForChild('ShovelModel')).Build(holder,handle);built.Parent=model;holder:Destroy();handle:Destroy()
 else
  local tool=spec.Tool
  for _,part in ipairs(tool and tool:GetDescendants()or{})do
   if part:IsA('BasePart')and part.Transparency<.95 then work.BeforePart(1);local copy=part:Clone();copy.Parent=model end
  end
 end
 -- Long gear (bats, shovels) reads better on the diagonal of a square card.
 local center,size=require(RS:WaitForChild('HarvestGeometry')).Bounds(model)
 if size.Y>math.max(size.X,size.Z)*1.6 then
  local turn=CFrame.new(center)*CFrame.Angles(0,0,-math.pi/4)*CFrame.new(-center)
  for _,part in ipairs(model:GetDescendants())do if part:IsA('BasePart')then part.CFrame=turn*part.CFrame end end
 end
 return model
end
local function build(spec,work)
 if spec.Kind=='Pack'then
  return require(RS:WaitForChild('SeedPackVisuals')).Bag(CFrame.Angles(0,.22,-.025),nil,1,nil,spec.Stage,spec.Variant,1,1,spec.Mutation)
 elseif spec.Kind=='Seed'then
  local ok,model=pcall(require(RS:WaitForChild('SeedPackVisuals')).Seed,{Id=spec.Id},nil,CFrame.new(),nil,1,nil,spec.Mutation)
  if ok and model then return model end
  local remotes=RS:FindFirstChild('ChestChaseRemotes');local library=remotes and remotes:FindFirstChild('SeedArt')
  local seeds=library and library:FindFirstChild('Seeds');local source=seeds and seeds:FindFirstChild(spec.Id)
  if not source then error(model)end
  local copy=source:Clone();require(RS:WaitForChild('PlantVisuals')).Coat(copy,spec.Mutation);return copy
 elseif spec.Kind=='Fruit'then
  local c=spec.Crop
  return(require(RS:WaitForChild('HarvestPresentation')).Build({SeedId=spec.Id,Mutation=spec.Mutation,Weather='None',
   VisualCrop={SourceCropId=c.Id,FruitIndex=spec.Index,HarvestCycle=c.HarvestCycle}},{Work=work}))
 end
 return toolModel(spec,work)
end
local function dropSpare(key)
 for _,e in ipairs(spare[key]or{})do spareCount-=1;spareParts-=e.Parts;e.View:Destroy()end;spare[key]=nil
end
-- Looks on screen are never evicted; looks outside the current list go before listed ones.
local function evict()
 if templateCount<=P.MaxTemplates then return end
 local inUse={};for _,r in pairs(records)do if r.Key then inUse[r.Key]=true end end
 while templateCount>P.MaxTemplates do
  local oldest,at
  for key,t in pairs(templates)do if not inUse[key]then local score=t.Used+(listed[key]and 1e6 or 0);if not at or score<at then oldest,at=key,score end end end
  if not oldest then return end
  templates[oldest].Model:Destroy();templates[oldest]=nil;templateCount-=1;dropSpare(oldest)
 end
end
-- R137: pictures never switch to a lower look; kept for callers, always false.
function P.Low()return false end
-- 'shown' inside every clip; 'near' just outside a scroll window (kept warm for scrolling in).
local function visible(holder)
 if not holder.Parent or holder.AbsoluteSize.X<=0 or holder.AbsoluteSize.Y<=0 then return false end
 local lo=holder.AbsolutePosition;local hi=lo+holder.AbsoluteSize;local node=holder;local near=false
 while node do
  if node:IsA('GuiObject')then
   if not node.Visible then return false end
   if node.ClipsDescendants or node:IsA('ScrollingFrame')then
    local a,b=node.AbsolutePosition,node.AbsolutePosition+node.AbsoluteSize
    if hi.X<=a.X or hi.Y<=a.Y or lo.X>=b.X or lo.Y>=b.Y then
     local m=node:IsA('ScrollingFrame')and P.WarmMargin or 0
     if m==0 or hi.X<=a.X-m or hi.Y<=a.Y-m or lo.X>=b.X+m or lo.Y>=b.Y+m then return false end
     near=true
    end
   end
  elseif node:IsA('LayerCollector')then
   if not node.Enabled or not node:IsDescendantOf(game)then return false end
   return near and'near'or'shown'
  end
  node=node.Parent
 end
 return false
end
local viewCount=0;local waiting=false
-- A released view is parked under its look (unparented, so it does not render) and reattached later for free.
local function park(key,view,parts)
 local list=spare[key];if not list then list={};spare[key]=list end
 table.insert(list,{View=view,Parts=parts,At=os.clock()});spareCount+=1;spareParts+=parts
 while spareCount>P.MaxSpare or spareParts>P.SpareParts do
  local worstKey,worstIndex,worst
  for k,l in pairs(spare)do for i,e in ipairs(l)do local score=e.At+(listed[k]and 1e6 or 0);if not worst or score<worst then worstKey,worstIndex,worst=k,i,score end end end
  if not worstKey then break end
  local e=table.remove(spare[worstKey],worstIndex);if #spare[worstKey]==0 then spare[worstKey]=nil end
  spareCount-=1;spareParts-=e.Parts;e.View:Destroy()
 end
end
local function release(r)
 if r.View then
  local view=r.View;r.View=nil;viewCount-=1
  if templates[r.ViewKey]then view.Parent=nil;park(r.ViewKey,view,r.Parts)else view:Destroy()end
  r.ViewKey=nil;r.Parts=0
 end
 fills[r]=nil
end
local function budget()return os.clock()<hurryUntil and P.HurryCloneSeconds or P.CloneSeconds end
-- Attach a parked view of this look, or clone the template while this frame's clone budget lasts.
local function fill(r,force)
 local t=templates[r.Key];if not t or r.View or not r.Holder.Parent then return false end
 local list=spare[r.Key];local view
 if list then
  local e=table.remove(list);if #list==0 then spare[r.Key]=nil end;spareCount-=1;spareParts-=e.Parts;view=e.View
 else
  if not force and cloneSpent>=budget()then return false end
  local started=os.clock()
  view=Instance.new('ViewportFrame');view.Name='ItemViewport';view.BackgroundTransparency=1;view.BorderSizePixel=0;view.Size=UDim2.fromScale(1,1)
  view.Ambient=RGB(195,195,185);view.LightColor=RGB(255,247,228);view.LightDirection=Vector3.new(-.45,-.8,1)
  local camera=Instance.new('Camera');camera.FieldOfView=t.Fov;camera.CFrame=t.Camera;camera.Parent=view;view.CurrentCamera=camera
  t.Model:Clone().Parent=view
  cloneSpent+=os.clock()-started
 end
 t.Used=os.clock();view.ZIndex=r.Holder.ZIndex;view.Parent=r.Holder
 r.View=view;r.ViewKey=r.Key;r.Parts=t.Parts;viewCount+=1;fills[r]=nil
 return true
end
local function request(key,spec,urgent)
 if templates[key]or(job and job.Key==key)then return end
 if failed[key]and os.clock()<failed[key]then return end
 if queued[key]then
  if urgent then for i,k in ipairs(queue)do if k==key then table.remove(queue,i);break end end;table.insert(queue,1,key)end
  return
 end
 queued[key]=spec;if urgent then table.insert(queue,1,key)else table.insert(queue,key)end
end
local function stepBuild()
 if not job then
  while #queue>0 do
   local key=table.remove(queue,1);local spec=queued[key];queued[key]=nil
   if spec and not templates[key]then
    local current={Key=key,Models={},Parts=0,Deadline=0}
    local work={Model=function(m)table.insert(current.Models,m)end}
    work.BeforePart=function(cost)if current.Parts<cost or os.clock()>current.Deadline then coroutine.yield()end;current.Parts-=cost end
    current.Thread=coroutine.create(function()
     local model=build(spec,work);if not model then error('no model')end
     local parts=sanitize(model);if parts==0 then model:Destroy();error('no visible parts')end
     local camera,fov=aim(model,spec.Kind)
     templates[key]={Model=model,Parts=parts,Camera=camera,Fov=fov,Used=os.clock()};templateCount+=1;evict();dirty=true
    end)
    job=current;break
   end
  end
 end
 if job then
  job.Parts=P.BuildParts;job.Deadline=os.clock()+(os.clock()<hurryUntil and P.HurryBuildSeconds or P.BuildSeconds)
  local ok,why=coroutine.resume(job.Thread)
  if not ok then
   -- Meshes that are still replicating come back quickly; real failures wait longer.
   failed[job.Key]=os.clock()+(tostring(why):find('still loading',1,true)and P.LoadingRetrySeconds or P.RetrySeconds)
   for _,m in ipairs(job.Models)do if not m.Parent then m:Destroy()end end
   if Run:IsStudio()and not warned[job.Key]then warned[job.Key]=true;warn('[R112] Item picture fallback '..job.Key..': '..tostring(why))end
   job=nil
  elseif coroutine.status(job.Thread)=='dead'then job=nil end
 end
end
local function sweep()
 local now=os.clock();local shown,near,held={},{},{}
 waiting=false
 for holder,r in pairs(records)do
  if r.Key then
   local state=visible(holder);r.Visible=state=='shown'
   if state then r.Seen=now;table.insert(state=='shown'and shown or near,r)elseif r.View then table.insert(held,r)end
  end
 end
 local function order(a,b)
  if a.Priority~=b.Priority then return a.Priority<b.Priority end
  local p,q=a.Holder.AbsolutePosition,b.Holder.AbsolutePosition
  if p.Y~=q.Y then return p.Y<q.Y end;return p.X<q.X
 end
 table.sort(shown,order);table.sort(near,order)
 local count,parts=0,0
 local function admit(r,cost,views,partLimit)if count<views and parts+cost<=partLimit then count+=1;parts+=cost;return true end;return false end
 -- R137: everything on screen gets its real picture (never capped); a look whose meshes are still loading
 -- retries soon and the holder stays empty meanwhile.
 for _,r in ipairs(shown)do
  local t=templates[r.Key];count+=1;parts+=t and t.Parts or P.GuessParts
  if not t then
   waiting=true
   if not(failed[r.Key]and now<failed[r.Key])then request(r.Key,r.Spec,true)end
  elseif not r.View then fills[r]=1 end
 end
 local function place(list,views,partLimit,rank)
  for _,r in ipairs(list)do
   local t=templates[r.Key]
   if failed[r.Key]and now<failed[r.Key]then release(r)
   elseif admit(r,t and t.Parts or P.GuessParts,views,partLimit)then
    if not t then request(r.Key,r.Spec,rank==1)elseif not r.View then fills[r]=rank end
   else release(r)end
  end
 end
 -- Holders just outside the scroll window keep (or get) a picture, so scrolling reveals finished cards.
 place(near,P.MaxViews+P.MaxWarm,P.MaxParts+P.WarmParts,2)
 -- Recently hidden pictures stay briefly (scroll back, reopen) but never exceed the budget.
 for _,r in ipairs(held)do if now-r.Seen>P.Grace or not admit(r,r.Parts or 0,P.MaxViews+P.MaxWarm,P.MaxParts+P.WarmParts)then release(r)end end
end
local function active()
 if job or #queue>0 or next(fills)then return true end
 for _,r in pairs(records)do if r.Key then return true end end
 return false
end
local function step(dt)
 sweepClock+=dt
 if dirty or sweepClock>=P.SweepSeconds or os.clock()<hurryUntil then sweepClock=0;dirty=false;sweep()end
 -- R137: while a picture on screen waits for its look, several looks build per frame (within a small budget).
 local started=os.clock();local limit=waiting and P.WaitBuildSeconds or 0
 repeat stepBuild() until not waiting or(not job and #queue==0)or os.clock()-started>=limit
 if waiting and not job and #queue==0 then dirty=true end
 -- Visible holders first, then warm ones; at least one clone per frame, more while the clone budget lasts.
 local list={};for r in pairs(fills)do table.insert(list,r)end
 table.sort(list,function(a,b)return fills[a]<fills[b]end)
 local made=0
 for _,r in ipairs(list)do
  if r.Key and not r.View and templates[r.Key]then if fill(r,made==0)then made+=1 end else fills[r]=nil end
 end
 cloneSpent=0
 if not active()and connection then connection:Disconnect();connection=nil end
end
local function wake()dirty=true;if not connection then connection=Run.Heartbeat:Connect(step)end end
local function showKey(holder,key,spec,priority)
 local r=records[holder]
 if not r then
  r={Holder=holder,Priority=priority or 2,Seen=0,Parts=0};records[holder]=r
  r.Destroying=holder.Destroying:Connect(function()r.Key=nil;release(r);r.Destroying:Disconnect();records[holder]=nil end)
 end
 r.Priority=priority or r.Priority
 if key==r.Key then if key then r.Spec=spec end;return end
 r.Key=nil;if r.View then release(r)end
 r.Key=key;r.Spec=spec
 if not key then return end
 -- R113: a ready look attaches at once (parked view or budgeted clone); R137: otherwise its build is put first.
 if templates[key]then if fill(r,true)then r.Seen=os.clock()end else request(key,spec,true)end
 wake()
end
-- priority: 0 category tabs, 1 hotbar, 2 inventory grid. Passing nil clears the holder.
function P.Show(holder,tool,priority)local key,spec=P.Key(tool);showKey(holder,key,spec,priority)end
function P.ShowSample(holder,name,priority)local key,spec=P.SampleKey(name);showKey(holder,key,spec,priority or 0)end
function P.Clear(holder)if records[holder]then showKey(holder,nil,nil)end end
-- R113: the looks of a whole list (in order) are built ahead of time and kept before other looks.
function P.Prefetch(tools)
 table.clear(listed)
 local count=0
 for _,tool in ipairs(tools)do
  local key,spec=P.Key(tool)
  if key and not listed[key]then listed[key]=true;count+=1;if count<=P.MaxTemplates then request(key,spec,false)end end
 end
 if count>0 then wake()end
end
-- R137: build these looks ahead (e.g. every card of the bonus reel before it spins), without touching the list order.
function P.Warm(tools)
 local count=0
 for _,tool in ipairs(tools)do local key,spec=P.Key(tool);if key and not templates[key]then request(key,spec,false);count+=1 end end
 if count>0 then hurryUntil=os.clock()+P.HurrySeconds;wake()end
end
-- R113: called while a list scrolls; sweeps every frame and raises the clone budget for a moment.
function P.Hurry()hurryUntil=os.clock()+P.HurrySeconds;wake()end
function P.Stats()
 local views,parts,count=0,0,0
 for _,r in pairs(records)do count+=1;if r.View then views+=1;parts+=r.Parts or 0 end end
 return {Records=count,Views=views,Parts=parts,Templates=templateCount,Queue=#queue,Building=job~=nil,Connected=connection~=nil,Spare=spareCount,SpareParts=spareParts}
end
function P.Reset()
 for _,r in pairs(records)do local key=r.Key;r.Key=nil;release(r);r.Key=key end
 for key in pairs(spare)do dropSpare(key)end
 for _,t in pairs(templates)do t.Model:Destroy()end
 table.clear(templates);templateCount=0;table.clear(queue);table.clear(queued);table.clear(failed);table.clear(listed);job=nil
end
return P
