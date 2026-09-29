-- R112: pictures for inventory cards and hotbar slots, built from the game's own art modules.
-- One template per item look (LRU); only visible holders clone it into a ViewportFrame, within a
-- view/part budget and a few clones per frame. Everything else, and low graphics, shows a flat icon.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local Players=game:GetService('Players');local Tags=game:GetService('CollectionService')
local P={MaxTemplates=48,MaxViews=34,MaxParts=6000,GuessParts=60,ClonesPerFrame=3,BuildSeconds=.002,BuildParts=24,SweepSeconds=.2,Grace=3,RetrySeconds=15}
local RGB=Color3.fromRGB
local records=setmetatable({},{__mode='k'});local templates={};local templateCount=0
local queue={};local queued={};local failed={};local fills={};local job;local connection;local sweepClock=0;local dirty=false
local function mutationKey(value)return(value=='Gold'or value=='Diamond')and value or'None'end
local function hex(value,fallback)
 if type(value)~='string'or#value~=6 then return fallback end
 local r,g,b=tonumber(value:sub(1,2),16),tonumber(value:sub(3,4),16),tonumber(value:sub(5,6),16)
 return r and g and b and RGB(r,g,b)or fallback
end
local function packRules()return require(RS:WaitForChild('SeedPackRules'))end
-- Same crop identity HarvestPresentation.Build uses, so the key matches what it draws.
local function harvestCrop(tool,id)
 return {Id=tool:GetAttribute('SourceCropId')or tool:GetAttribute('HarvestInventoryId')or'preview',SeedId=id,PlantScale=1,SeedScale=1,
  Mutation=mutationKey(tool:GetAttribute('Mutation')),Weather='None',HarvestCycle=tool:GetAttribute('HarvestCycle')or 0,PickedMask=0,ReadyAt=0}
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
  local crop=harvestCrop(tool,id);local art=''
  local ok,value=pcall(function()return require(RS.ApprovedPlantArt).Key(id,crop)..require(RS.PlantSurfaceStyle).Key(id,crop)end)
  if ok and type(value)=='string'then art=value end
  return table.concat({'Fruit',id,index,crop.Mutation,art},'|'),{Kind='Fruit',Id=id,Index=index,Mutation=crop.Mutation,Crop=crop}
 end
 local name='Tool:'..tool.Name
 if tool:GetAttribute('GardenShovel')then name='Shovel'
 elseif tool:GetAttribute('ChestChaseBat')then name='Bat:'..tostring(tool:GetAttribute('BatAppearanceAssetId'))..':'..tostring(tool:GetAttribute('BatAppearanceVersion'))
 elseif tool:GetAttribute('LootItemTool')then name='Loot:'..tostring(tool:GetAttribute('LootName')or tool.Name)end
 return 'Tool|'..name,{Kind='Tool',Tool=tool,Shovel=tool:GetAttribute('GardenShovel')==true}
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
local function evict()
 while templateCount>P.MaxTemplates do
  local oldest,at
  for key,t in pairs(templates)do if not at or t.Used<at then oldest,at=key,t.Used end end
  if not oldest then return end
  templates[oldest].Model:Destroy();templates[oldest]=nil;templateCount-=1
 end
end
function P.Low()
 local player=Players.LocalPlayer
 local mode=player and player:GetAttribute('StudioPlantEffects')
 if mode=='off'or mode=='low'or(player and player:GetAttribute('FastMode')==true)then return true end
 local ok,low=pcall(function()return require(RS:WaitForChild('ClientFxBudget')).Low()end)
 return ok and low==true
end
local function visible(holder)
 if not holder.Parent or holder.AbsoluteSize.X<=0 or holder.AbsoluteSize.Y<=0 then return false end
 local lo=holder.AbsolutePosition;local hi=lo+holder.AbsoluteSize;local node=holder
 while node do
  if node:IsA('GuiObject')then
   if not node.Visible then return false end
   if node.ClipsDescendants or node:IsA('ScrollingFrame')then
    local a,b=node.AbsolutePosition,node.AbsolutePosition+node.AbsoluteSize
    if hi.X<=a.X or hi.Y<=a.Y or lo.X>=b.X or lo.Y>=b.Y then return false end
   end
  elseif node:IsA('LayerCollector')then
   if not node.Enabled then return false end
   return node:IsDescendantOf(game)
  end
  node=node.Parent
 end
 return false
end
-- Flat icons: a few native frames, coloured from the same art data.
local function shape(parent,name,x,y,w,h,color,round,rotation)
 local f=Instance.new('Frame');f.Name=name;f.Position=UDim2.fromScale(x,y);f.Size=UDim2.fromScale(w,h);f.BorderSizePixel=0;f.BackgroundColor3=color;f.Rotation=rotation or 0;f.Active=false;f.Parent=parent
 if round then local c=Instance.new('UICorner');c.CornerRadius=UDim.new(round,0);c.Parent=f end
 return f
end
local coats={Gold=RGB(255,201,70),Diamond=RGB(213,247,255)}
local function flat(holder,spec)
 local root=Instance.new('Frame');root.Name='FlatIcon';root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1);root.Active=false;root.ZIndex=holder.ZIndex;root.Parent=holder
 local ok,rules=pcall(packRules);if not ok then rules=nil end
 if spec.Kind=='Pack'then
  local theme=rules and rules.BiomeThemes[spec.Stage]or{Body=RGB(179,138,85),Ink=RGB(57,103,48),Trim=RGB(108,135,61)}
  local tier=rules and rules.GetPackTier(spec.Variant);local body=coats[spec.Mutation]or theme.Body
  shape(root,'Pouch',.22,.12,.56,.78,body,.18);shape(root,'Seal',.22,.12,.56,.11,theme.Ink,.3)
  shape(root,'TierBand',.22,.62,.56,.08,tier and tier.Color or theme.Trim,nil);shape(root,'Mark',.41,.32,.18,.18,theme.Ink,1)
 elseif spec.Kind=='Seed'or spec.Kind=='Fruit'then
  local design=rules and rules.SeedDesignById[spec.Id]
  local top,bottom,ink=hex(design and design.top,RGB(116,185,103)),hex(design and design.bottom,RGB(215,238,161)),hex(design and design.ink,RGB(36,84,52))
  if coats[spec.Mutation]then top=coats[spec.Mutation];bottom=top:Lerp(RGB(255,255,255),.45)end
  if spec.Kind=='Seed'then
   local body=shape(root,'Seed',.3,.14,.4,.72,top,1);local g=Instance.new('UIGradient');g.Rotation=90;g.Color=ColorSequence.new(top,bottom);g.Parent=body
   shape(root,'Speck',.44,.34,.1,.12,ink,1);shape(root,'Speck',.47,.58,.08,.1,ink,1)
  else
   shape(root,'Fruit',.16,.22,.68,.68,top,1);shape(root,'Shine',.3,.34,.16,.16,bottom,1);shape(root,'Leaf',.5,.1,.26,.14,RGB(107,196,86),1,-30)
  end
 else
  local icon=require(RS:WaitForChild('GardenTheme')).ControlIcon(root,'Tools');icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5);icon.Size=UDim2.fromScale(.62,.62)
 end
 return root
end
local function release(r)
 if r.View then r.View:Destroy();r.View=nil;r.ViewKey=nil;r.Parts=0 end
 fills[r]=nil
 if r.Flat then r.Flat.Visible=true end
end
local function fill(r)
 local t=templates[r.Key];if not t or not r.Holder.Parent then return end
 t.Used=os.clock()
 local view=Instance.new('ViewportFrame');view.Name='ItemViewport';view.BackgroundTransparency=1;view.BorderSizePixel=0;view.Size=UDim2.fromScale(1,1)
 view.Ambient=RGB(195,195,185);view.LightColor=RGB(255,247,228);view.LightDirection=Vector3.new(-.45,-.8,1);view.ZIndex=r.Holder.ZIndex
 local camera=Instance.new('Camera');camera.FieldOfView=t.Fov;camera.CFrame=t.Camera;camera.Parent=view;view.CurrentCamera=camera
 t.Model:Clone().Parent=view;view.Parent=r.Holder
 r.View=view;r.ViewKey=r.Key;r.Parts=t.Parts
 if r.Flat then r.Flat.Visible=false end
end
local function request(key,spec)
 if templates[key]or queued[key]or(job and job.Key==key)then return end
 if failed[key]and os.clock()<failed[key]then return end
 queued[key]=spec;table.insert(queue,key)
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
  job.Parts=P.BuildParts;job.Deadline=os.clock()+P.BuildSeconds
  local ok,why=coroutine.resume(job.Thread)
  if not ok then
   failed[job.Key]=os.clock()+P.RetrySeconds
   for _,m in ipairs(job.Models)do if not m.Parent then m:Destroy()end end
   if Run:IsStudio()then warn('[R112] Item picture fallback '..job.Key..': '..tostring(why))end
   job=nil
  elseif coroutine.status(job.Thread)=='dead'then job=nil end
 end
end
local function sweep()
 local now=os.clock();local shown={};local held={}
 for holder,r in pairs(records)do
  if r.Key then
   r.Visible=visible(holder);if r.Visible then r.Seen=now;table.insert(shown,r)elseif r.View then table.insert(held,r)end
  end
 end
 table.sort(shown,function(a,b)
  if a.Priority~=b.Priority then return a.Priority<b.Priority end
  local p,q=a.Holder.AbsolutePosition,b.Holder.AbsolutePosition
  if p.Y~=q.Y then return p.Y<q.Y end;return p.X<q.X
 end)
 local limit=P.Low()and 0 or P.MaxViews;local count,parts=0,0
 local function admit(r,cost)if count<limit and parts+cost<=P.MaxParts then count+=1;parts+=cost;return true end;return false end
 for _,r in ipairs(shown)do
  local t=templates[r.Key]
  if failed[r.Key]and now<failed[r.Key]then release(r)
  elseif admit(r,t and t.Parts or P.GuessParts)then
   if not t then request(r.Key,r.Spec)elseif not r.View then fills[r]=true end
  else release(r)end
 end
 -- Recently hidden pictures stay briefly (scroll back, reopen) but never exceed the budget.
 for _,r in ipairs(held)do if now-r.Seen>P.Grace or not admit(r,r.Parts or 0)then release(r)end end
end
local function active()
 if job or #queue>0 or next(fills)then return true end
 for _,r in pairs(records)do if r.Key then return true end end
 return false
end
local function step(dt)
 sweepClock+=dt
 if dirty or sweepClock>=P.SweepSeconds then sweepClock=0;dirty=false;sweep()end
 stepBuild()
 local made=0
 for r in pairs(fills)do
  fills[r]=nil
  if r.Key and r.Visible and not r.View and templates[r.Key]then fill(r);made+=1 end
  if made>=P.ClonesPerFrame then break end
 end
 if not active()and connection then connection:Disconnect();connection=nil end
end
local function wake()dirty=true;if not connection then connection=Run.Heartbeat:Connect(step)end end
-- priority: 1 hotbar, 2 inventory grid. Passing nil clears the holder.
function P.Show(holder,tool,priority)
 local r=records[holder]
 if not r then
  r={Holder=holder,Priority=priority or 2,Seen=0,Parts=0};records[holder]=r
  r.Destroying=holder.Destroying:Connect(function()release(r);r.Destroying:Disconnect();records[holder]=nil end)
 end
 r.Priority=priority or r.Priority
 local key,spec=P.Key(tool)
 if key==r.Key then if key then r.Spec=spec end;return end
 r.Key=key;r.Spec=spec
 if r.View and r.ViewKey~=key then release(r)end
 if r.Flat then r.Flat:Destroy();r.Flat=nil end
 if spec then r.Flat=flat(holder,spec);r.Flat.Visible=r.View==nil;wake()end
end
function P.Clear(holder)if records[holder]then P.Show(holder,nil)end end
function P.Stats()
 local views,parts,count=0,0,0
 for _,r in pairs(records)do count+=1;if r.View then views+=1;parts+=r.Parts or 0 end end
 return {Records=count,Views=views,Parts=parts,Templates=templateCount,Queue=#queue,Building=job~=nil,Connected=connection~=nil}
end
function P.Reset()
 for _,r in pairs(records)do release(r)end
 for _,t in pairs(templates)do t.Model:Destroy()end
 table.clear(templates);templateCount=0;table.clear(queue);table.clear(queued);table.clear(failed);job=nil
end
return P
