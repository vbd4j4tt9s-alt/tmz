-- One shared camera loop for collection cards and the premium outcome gallery.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Gui=game:GetService('GuiService')
local FX=require(RS.ItemVisualEffects)
local Geometry=require(RS.HarvestGeometry);local CachedVisible=require(RS.ShopViewport).CachedVisible
local V={};local entries={};local connection;local elapsed=0
local function silhouette(model)
 for _,p in ipairs(model:GetDescendants())do
  if p:IsA('BasePart')and p.Transparency<.95 then
   p.Color=Color3.fromRGB(9,14,29);p.Material=Enum.Material.SmoothPlastic;p.Transparency=0;p.Reflectance=0
   if p:IsA('MeshPart')then p.TextureID=''end
  elseif p:IsA('SpecialMesh')then p.TextureId=''
  elseif p:IsA('Decal')or p:IsA('Texture')or p:IsA('SurfaceAppearance')or p:IsA('ParticleEmitter')or p:IsA('Light')then p:Destroy()end
 end
end
local function build(id,adult)
 if not adult then
  local remotes=RS:FindFirstChild('ChestChaseRemotes');local library=remotes and remotes:FindFirstChild('SeedArt');local seeds=library and library:FindFirstChild('Seeds');local model=seeds and seeds:FindFirstChild(id)
  if model then return model:Clone()end
  if require(RS.MechCatalog).Is(id)then return require(RS.MechArt).BuildNative(id,CFrame.new(),nil,1)end
  return nil
 end
 local crop={Id='preview',SeedId=id,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,PlantedAt=0,MatureAt=1,ReadyAt=1}
 local visuals=require(RS.PlantVisuals)
 if visuals.DetailCost(id,crop)<=1500 and visuals.DetailReady(id,crop)then return visuals.Build(id,CFrame.new(),crop,4,math.huge)end
 return require(RS.DistantPlantView).Build(crop,CFrame.new(),math.huge)
end
local function pose(e,t)
 local size=e.View.AbsoluteSize;local aspect=math.max(.25,size.X/math.max(1,size.Y));local half=math.atan(math.tan(math.rad(16))*math.min(1,aspect))
 local angle=Gui.ReducedMotionEnabled and .22 or .22+math.sin(t*.45)*.18
 if e.Shake and not Gui.ReducedMotionEnabled then local age=t-e.Shake;angle+=math.sin(age*38)*.15*math.max(0,1-age/.3)end
 local direction=Vector3.new(math.sin(angle),.22,-math.cos(angle)).Unit
 e.Camera.CFrame=CFrame.lookAt(e.Center+direction*(e.Radius/math.sin(half)*1.05),e.Center)
end
function V.Attach(view,id,adult,known)
 -- Retain late-replication retries without adding replacement artwork.
 local world=Instance.new('WorldModel');world.Name='CollectionWorld';world.Parent=view
 local camera=Instance.new('Camera');camera.FieldOfView=32;camera.Parent=view;view.CurrentCamera=camera
 local e={View=view,World=world,Camera=camera,Center=Vector3.zero,Radius=1,Shake=os.clock(),Ready=false,RetryAt=0,Attempts=0,Busy=false}
 entries[e]=true;local dead=false;local destroy
 local function attempt()
  if dead or e.Busy or e.Ready then return end;e.Busy=true;e.Attempts+=1
  task.defer(function()
   if dead then e.Busy=false;return end
   local ok,model=pcall(build,id,adult)
   if dead then if ok and model then model:Destroy()end;e.Busy=false;return end
   if ok and model then
    local visible=false
    for _,part in ipairs(model:GetDescendants())do if part:IsA('BasePart')and part.Transparency<.95 then visible=true;break end end
    if visible then
     if not known then silhouette(model)end
     model.Parent=world;e.Center,e.Size=Geometry.Bounds(model);e.Radius=math.max(.1,e.Size.Magnitude/2);e.Ready=true
     pose(e,os.clock())
     if known and not adult and require(RS.MechCatalog).ById[id]then e.FX=FX.New(world,'None',true)end
    else model:Destroy()end
   end
   e.Busy=false;e.RetryAt=os.clock()+math.min(20,2^math.min(e.Attempts-1,5))
   view:SetAttribute('PreviewReady91',e.Ready)
  end)
 end
 e.Try=attempt
 local function cleanup()
  if dead then return end;dead=true;entries[e]=nil;if destroy then destroy:Disconnect()end
  if view.CurrentCamera==camera then view.CurrentCamera=nil end
  world:Destroy();camera:Destroy()
  if not next(entries)and connection then connection:Disconnect();connection=nil end
 end
 destroy=view.Destroying:Connect(cleanup)
 attempt()
 if not connection then connection=Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<1/20 then return end;elapsed=0;local count,retries=0,0;local t=os.clock();local player=game:GetService('Players').LocalPlayer;local budget=require(RS.CosmeticBudget).CollectionViews(player and player:GetAttribute('FastMode'))
  -- R121: cards stay attached after the Index closes; the cached hidden ancestor makes those checks cheap.
  for r in pairs(entries)do if count<budget and CachedVisible(r)then
   count+=1
   if r.Ready then pose(r,t);if r.FX then FX.Step(r.FX,CFrame.new(r.Center),math.max(r.Size.X,r.Size.Z)*.5,r.Size.Y,t,1)end
   elseif not r.Busy and t>=r.RetryAt and retries<2 then retries+=1;r.Try()end
  end end
 end)end
 return cleanup
end
return V
