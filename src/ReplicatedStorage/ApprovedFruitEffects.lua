-- Approved fig/lava motion. The returned function cleans up and restores appearance.
-- GardenVisuals owns readiness, distance, harvest selection and lifetime.
local RunService=game:GetService('RunService')
local Effects={}
local function move(part,frame,batch)if batch then batch:Set(part,frame)else part.CFrame=frame end end
function Effects.Start(model,style,selected,low,options)
 assert(style=='FigMagic'or style=='EmberLava','Unknown review effect style.')
 local old=model:FindFirstChild('ApprovedFruitEffects');assert(not old,'Review effects already running.')
 local folder=Instance.new('Folder');folder.Name='ApprovedFruitEffects';folder.Parent=model
 local entries,restore={},{}
 local function coat(part,color)
  restore[part]={Color=part.Color,Material=part.Material}
  part.Material=Enum.Material.Neon;part.Color=color
 end
 local function orb(name,size,color,parent)
  local p=Instance.new('Part');p.Name=name;p.Shape=Enum.PartType.Block;p.Size=size;p.Color=color
  local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=Vector3.one;mesh.Parent=p
  p.Material=Enum.Material.Neon;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent
  return p
 end
 for _,group in ipairs(model:GetChildren())do
  if group:IsA('Model')and group.Name:match('^Harvest_%d+$')and(not selected or selected[tonumber(group.Name:match('%d+'))])then
   local core=group:FindFirstChild(style=='FigMagic'and'Fig pear body'or'Emberfruit core',true)
   if core then
    local mutation=group:GetAttribute('Mutation')or 'None'
    local scale=core.Size.X/(style=='FigMagic'and .94 or 1)
    local entry={Core=core,Scale=scale,Mutation=mutation,Index=tonumber(group.Name:match('%d+')),Wisps={},Flows={}}
    local anchor=orb('Effect anchor',Vector3.new(.03,.03,.03),Color3.new(1,1,1),folder);anchor.Transparency=1;entry.Anchor=anchor
    local emitter=Instance.new('ParticleEmitter');emitter.Name=style=='FigMagic'and 'Magic motes'or'Rising lava embers'
    emitter.Texture='rbxasset://textures/particles/sparkles_main.dds';emitter.LightEmission=.85;emitter.LightInfluence=.12
    emitter.Rate=low and .7 or(style=='FigMagic'and 2.0 or 2.8);emitter.Lifetime=NumberRange.new(.8,1.5)
    emitter.Speed=NumberRange.new(.10*scale,.26*scale);emitter.SpreadAngle=Vector2.new(40,40)
    emitter.Acceleration=Vector3.new(0,(style=='FigMagic'and .10 or .35)*scale,0)
    emitter.Color=ColorSequence.new(style=='FigMagic'and Color3.fromRGB(211,170,255)or Color3.fromRGB(255,157,49),style=='FigMagic'and Color3.fromRGB(172,239,255)or Color3.fromRGB(255,84,15))
    emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.035*scale),NumberSequenceKeypoint.new(.55,.025*scale),NumberSequenceKeypoint.new(1,0)})
    emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.18,.15),NumberSequenceKeypoint.new(1,1)})
    emitter.Rotation=NumberRange.new(0,360);emitter.RotSpeed=NumberRange.new(-25,25);emitter.Parent=anchor
    if style=='FigMagic'then
     entry.Window=group:FindFirstChild('Fig rosy window',true)
     if entry.Window and mutation=='None'then coat(entry.Window,Color3.fromRGB(198,107,255))end
     for j=1,(low and 1 or 2)do
      local wisp=orb('Magical orbit wisp',Vector3.new(.09,.16,.07)*scale,Color3.fromRGB(176,240,255),folder)
      wisp.Transparency=.12
      local a=Instance.new('Attachment');a.Position=Vector3.new(0,.022*scale,0);a.Parent=wisp
      local b=Instance.new('Attachment');b.Position=Vector3.new(0,-.022*scale,0);b.Parent=wisp
      local trail=Instance.new('Trail');trail.Name='Violet wisp trail';trail.Attachment0=a;trail.Attachment1=b
      trail.Lifetime=.32;trail.MinLength=.015;trail.FaceCamera=true;trail.LightEmission=.85
      trail.Color=ColorSequence.new(Color3.fromRGB(198,152,255));trail.Transparency=NumberSequence.new(.60,1);trail.Parent=wisp
      table.insert(entry.Wisps,wisp)
     end
    else
     if mutation=='None'then coat(core,Color3.fromRGB(255,100,10))end
     for j=1,(low and 1 or 3)do
      local flow=orb('Flowing lava glint',Vector3.new(.06,.16,.035)*scale,Color3.fromRGB(255,184,33),folder)
      flow.Transparency=.10;table.insert(entry.Flows,flow)
     end
    end
    table.insert(entries,entry)
   end
  end
 end
 local elapsed=0;local clock=0;local closed=false;local tickConnection,destroyConnection
 local function step(t,batch)
  for _,entry in ipairs(entries)do
   local core=entry.Core
   if core.Parent and not entry.Removed then
    local scale=entry.Scale;local coreFrame=batch and batch:Get(core)or core.CFrame;local center=coreFrame*(style=='FigMagic'and CFrame.new(0,.12*scale,0)or CFrame.new())
    if entry.LastCoreFrame~=coreFrame then move(entry.Anchor,center*CFrame.new(0,.22*scale,0),batch);entry.LastCoreFrame=coreFrame end
    if style=='FigMagic'then
     if entry.Mutation=='None'and entry.Window and entry.Window.Parent then entry.Window.Color=Color3.new(.73+.10*math.sin(t*1.4),.39+.08*math.sin(t*1.4),1)end
     for j,wisp in ipairs(entry.Wisps)do
      local a=t*.70+(j-1)*math.pi+entry.Index*.6
      move(wisp,center*CFrame.new(math.cos(a)*.74*scale,math.sin(a*1.35)*.24*scale,math.sin(a)*.63*scale),batch)
     end
    else
     local pulse=.5+.5*math.sin(t*1.7+entry.Index);if entry.Mutation=='None'then core.Color=Color3.new(1,.27+.17*pulse,.025+.02*pulse)end
     for j,flow in ipairs(entry.Flows)do
      local phase=(t*.21+(j-1)/3)%1;local y=.38-.76*phase;local a=(j-.5)*math.pi*2/5
      local r=math.sqrt(math.max(.1,1-(y/.495)^2))
      move(flow,center*CFrame.new(math.cos(a)*.504*r*scale,y*scale,math.sin(a)*.482*r*scale)*CFrame.Angles(0,-a,0),batch)
     end
    end
   elseif not entry.Removed then
    entry.Removed=true;entry.Anchor:Destroy()
    for _,part in ipairs(entry.Wisps)do part:Destroy()end
    for _,part in ipairs(entry.Flows)do part:Destroy()end
   end
  end
 end
 local function cleanup()
  if closed then return end;closed=true
  if tickConnection then tickConnection:Disconnect()end
  if destroyConnection then destroyConnection:Disconnect()end
  for part,saved in pairs(restore)do if part.Parent then part.Color=saved.Color;part.Material=saved.Material end end
  folder:Destroy();table.clear(entries);table.clear(restore)
 end
 step(0)
 if not(options and options.Manual)then tickConnection=RunService.Heartbeat:Connect(function(dt)
  if not model.Parent then cleanup();return end
  clock+=dt;elapsed+=dt;if elapsed<1/20 then return end;elapsed=0;step(clock)
 end)end
 destroyConnection=model.Destroying:Connect(cleanup)
 return cleanup,step
end
return Effects
