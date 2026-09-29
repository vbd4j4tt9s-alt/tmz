-- R83: distance-limited local animation and a shared small effect budget.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Tags=game:GetService('CollectionService')
local Art=require(RS:WaitForChild('VeiledKeeper81'));local Fx=require(RS.ClientFxBudget)
local Feed=require(RS.NoticeFeed83);local Copy=require(RS.NoticeCopy83)
local keepers,bags={},{};local connections={};local alive=true
local function watch(signal,fn)connections[#connections+1]=signal:Connect(fn)end
local function keeper(model)if model:IsA('Model')then keepers[model]={At=-100}end end
for _,m in ipairs(Tags:GetTagged('VeiledKeeper81'))do keeper(m)end
watch(Tags:GetInstanceAddedSignal('VeiledKeeper81'),keeper);watch(Tags:GetInstanceRemovedSignal('VeiledKeeper81'),function(m)keepers[m]=nil end)
local function track(bag)if bag:GetAttribute('BagVariant')=='EclipseReliquary'and not bags[bag]then bags[bag]={}end end
local function clearEffects(r)
 if r.Folder then r.Folder:Destroy();r.Folder=nil end
 if r.Mist then r.Mist:Destroy();r.Mist=nil end
 if r.Highlight then r.Highlight:Destroy();r.Highlight=nil end
 r.Orbits=nil;r.Effects=false
end
local function remove(bag)local r=bags[bag];if r then clearEffects(r)end;bags[bag]=nil end
for _,bag in ipairs(Tags:GetTagged('BiomeSeedPackVisual'))do track(bag)end
watch(Tags:GetInstanceAddedSignal('BiomeSeedPackVisual'),track);watch(Tags:GetInstanceRemovedSignal('BiomeSeedPackVisual'),remove)
local function geometry(bag,r)
 if not bag.PrimaryPart or not bag:GetAttribute('CompactPackReady')then return false end
 r.Root=bag.PrimaryPart;r.Scale=bag:GetAttribute('VisualScale')or 1;r.Origin=bag:GetAttribute('HoverOrigin')or r.Root.CFrame;r.Parts={}
 for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')then table.insert(r.Parts,{Part=p,Frame=p:GetAttribute('PackLocalFrame')or r.Root.CFrame:ToObjectSpace(p.CFrame),Alpha=p:GetAttribute('PackTransparency')or p.Transparency})end end
 r.Ready=true;return true
end
local function effects(bag,r)
 local folder=Instance.new('Folder');folder.Name='_VoidOrbit83';folder.Parent=workspace;r.Folder=folder;r.Orbits={}
 for i=1,3 do
  local orb=Instance.new('Part');orb.Name='OrbitingShadow';orb.Shape=Enum.PartType.Ball;orb.Size=Vector3.one*(.18*r.Scale)
  orb.Color=Color3.fromRGB(12,7,22);orb.Material=Enum.Material.SmoothPlastic;orb.Anchored=true;orb.CanCollide=false;orb.CanTouch=false;orb.CanQuery=false;orb.CastShadow=false;orb.Parent=folder;table.insert(r.Orbits,orb)
 end
 local mist=Instance.new('ParticleEmitter');mist.Name='VoidAura';mist.Texture='rbxasset://textures/particles/smoke_main.dds'
 mist.Color=ColorSequence.new(Color3.fromRGB(9,5,18),Color3.fromRGB(51,29,75));mist.LightEmission=0;mist.LightInfluence=.25
 mist.Rate=6;mist.Lifetime=NumberRange.new(.8,1.4);mist.Speed=NumberRange.new(.15,.45);mist.SpreadAngle=Vector2.new(180,180)
 mist.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.55*r.Scale),NumberSequenceKeypoint.new(1,1.2*r.Scale)})
 mist.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.35),NumberSequenceKeypoint.new(1,1)})
 mist.Parent=r.Root;r.Mist=mist
 local h=Instance.new('Highlight');h.Adornee=bag;h.FillTransparency=1;h.OutlineColor=Color3.fromRGB(136,89,196);h.OutlineTransparency=.35;h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=bag;r.Highlight=h;r.Effects=true
end
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('VeiledArrival81')
local function arrive(cycle,serial)Feed.Push(Copy.Arrival(),5,'veiled:'..tostring(serial or cycle),true)end
watch(remote.OnClientEvent,arrive)
local map=workspace:WaitForChild('ChestChaseMap');if map:GetAttribute('VeiledEventActive')then arrive(map:GetAttribute('VeiledEventCycle'),map:GetAttribute('VeiledArrivalSerial83'))end
local elapsed=0
watch(Run.RenderStepped,function(dt)
 elapsed+=dt;local tier=Fx.Get();local mode=Players.LocalPlayer:GetAttribute('StudioPlantEffects');if mode=='low'then tier=1 end;local interval=tier==1 and 1/15 or 1/30;local effectTick=elapsed>=interval;if effectTick then elapsed=0 end
 local camera=workspace.CurrentCamera;if not camera then return end;local now=workspace:GetServerTimeNow();local origin=camera.CFrame.Position
 for m,r in pairs(keepers)do
  local root=m.PrimaryPart;if not m.Parent or not root then keepers[m]=nil;continue end
  local distance=(root.Position-origin).Magnitude;local period=distance<350 and 0 or distance<900 and .15 or 1
  if now-r.At>=period then r.At=now;Art.Apply(m,now)end
 end
 if not effectTick then return end
 local near={}
 for bag,r in pairs(bags)do
  if not bag.Parent then remove(bag);continue end
  if not r.Ready and not geometry(bag,r)then continue end
  if not r.Root.Parent then remove(bag);continue end
  local visible=bag:IsDescendantOf(workspace)and bag:GetAttribute('PackVisible')~=false and bag:GetAttribute('RevealAt')==nil
  local distance=(r.Root.Position-origin).Magnitude
  if r.Effects and(not visible or distance>=160)then clearEffects(r)end
  if not visible then continue end
  if distance<160 then table.insert(near,{Bag=bag,Record=r,Distance=distance})end
  if bag:GetAttribute('WorldPack')and bag.Name~='OpeningBag'and distance<850 then
   local frame=r.Origin*CFrame.new(0,math.sin(now*1.2)*.16,0)*CFrame.Angles(0,math.sin(now*.35)*.13,math.sin(now*.55)*.018)
   for _,v in ipairs(r.Parts)do if v.Part.Parent then v.Part.CFrame=frame*v.Frame end end
  end
 end
 table.sort(near,function(a,b)return a.Distance<b.Distance end)
 local budget=mode=='off'and 0 or tier==1 and 1 or tier==2 and 2 or 4
 for i,item in ipairs(near)do
  local r=item.Record
  if i>budget then if r.Effects then clearEffects(r)end;continue end
  if not r.Effects then effects(item.Bag,r)end
  r.Mist.Enabled=tier>1;r.Mist.Rate=tier==3 and 6 or 3
  for j,orb in ipairs(r.Orbits)do
   local angle=now*1.8+(j-1)*math.pi*2/3
   orb.Transparency=tier==1 and j>1 and 1 or .12
   orb.CFrame=r.Root.CFrame*CFrame.new(math.cos(angle)*1.65*r.Scale,math.sin(angle*1.3)*.7*r.Scale,math.sin(angle)*1.65*r.Scale)
  end
 end
end)
script.Destroying:Connect(function()
 alive=false;for _,c in ipairs(connections)do c:Disconnect()end
 for _,r in pairs(bags)do clearEffects(r)end;table.clear(bags);table.clear(keepers)
end)
