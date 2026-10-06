do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived (a module missing on join used to break the client scripts)
-- R83: distance-limited local animation and a shared small effect budget.
-- R122: Void Pack motion/effects via VoidPackFx (budgeted); arrival sound + lights-out via VeiledArrivalFx.
local Players=game:GetService('Players');local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService');local Tags=game:GetService('CollectionService')
local Gui=game:GetService('GuiService')
local Art=require(RS:WaitForChild('VeiledKeeper81'));local Fx=require(RS.ClientFxBudget)
local Feed=require(RS.NoticeFeed83);local Copy=require(RS.NoticeCopy83)
local PackFx=require(RS:WaitForChild('VoidPackFx'));local Arrival=require(RS:WaitForChild('VeiledArrivalFx'))
-- R123: client-only spectral lunge (Art.ClientFrames) and a small impact accent; the server pose is unchanged.
local KFx=require(RS:WaitForChild('KeeperFx'));local Combat=require(RS:WaitForChild('KeeperCombat'))
local keepers,bags={},{};local connections={};local alive=true
local function watch(signal,fn)connections[#connections+1]=signal:Connect(fn)end
local function keeper(model)if model:IsA('Model')then keepers[model]={At=-100}end end
for _,m in ipairs(Tags:GetTagged('VeiledKeeper81'))do keeper(m)end
local Fx152 -- (R152: KeeperFx152, required with the first new-model Darkened)
watch(Tags:GetInstanceAddedSignal('VeiledKeeper81'),keeper);watch(Tags:GetInstanceRemovedSignal('VeiledKeeper81'),function(m)local r=keepers[m];if r and r.Fx152 then Fx152.Destroy(r.Fx152)end;keepers[m]=nil end)
-- R149 (owner: the Verity pack is just pure yellow with her face, "that's the only design needed"): only the Void pack has local motion and fx; the Verity pack (R147 / R148 gave it gold sparkles and a light here) has none.
local function track(bag)if bag:GetAttribute('BagVariant')=='EclipseReliquary'and not bags[bag]then bags[bag]={}end end
local function remove(bag)local r=bags[bag];if r and r.Capture then PackFx.Clear(r.Capture)end;bags[bag]=nil end
for _,bag in ipairs(Tags:GetTagged('BiomeSeedPackVisual'))do track(bag)end
watch(Tags:GetInstanceAddedSignal('BiomeSeedPackVisual'),track);watch(Tags:GetInstanceRemovedSignal('BiomeSeedPackVisual'),remove)
Arrival.Preload()
local remote=RS:WaitForChild('ChestChaseRemotes'):WaitForChild('VeiledArrival81')
local function arrive(cycle,serial,at)
 Feed.Push(Copy.Arrival(),5,'veiled:'..tostring(serial or cycle),true)
 -- Only a fresh server-stamped spawn plays the sound and the lights-out (never on join).
 if type(serial)=='number'and type(at)=='number'then Arrival.Arrive(serial,at)end
end
watch(remote.OnClientEvent,arrive)
local map=workspace:WaitForChild('ChestChaseMap');if map:GetAttribute('VeiledEventActive')then arrive(map:GetAttribute('VeiledEventCycle'),map:GetAttribute('VeiledArrivalSerial83'))end
watch(map:GetAttributeChangedSignal('VeiledRerollSerial'),function()
 if map:GetAttribute('VeiledEventActive')then Feed.Push(Copy.VoidShift(),4,'voidshift:'..tostring(map:GetAttribute('VeiledRerollSerial')),false)end
end)
local elapsed=0;local parts,frames={},{}
watch(Run.RenderStepped,function(dt)
 elapsed+=dt;local tier=Fx.Get();local mode=Players.LocalPlayer:GetAttribute('StudioPlantEffects');if mode=='low'then tier=1 end;local interval=tier==1 and 1/15 or 1/30;local effectTick=elapsed>=interval;if effectTick then elapsed=0 end
 local camera=workspace.CurrentCamera;if not camera then return end;local now=workspace:GetServerTimeNow();local origin=camera.CFrame.Position
 for m,r in pairs(keepers)do
  local root=m.PrimaryPart;if not m.Parent or not root then if r.Fx152 then Fx152.Destroy(r.Fx152)end;keepers[m]=nil;continue end
  local distance=(root.Position-origin).Magnitude;local period=distance<350 and 0 or distance<900 and .15 or 1
  -- R152: the baked Darkened's two faces (its glowing line): Asleep while it sleeps (GUARDING / SLEEPING), Chase otherwise.
  local state=m:GetAttribute('GuardianBehavior')or'GUARDING';local asleep=state=='GUARDING'or state=='SLEEPING'
  if r.FaceAsleep~=asleep and m:GetAttribute('KeeperMeshVariant')=='R152'then
   r.FaceAsleep=asleep
   for _,p in ipairs(m:GetChildren())do local face=p:GetAttribute('KeeperFaceState');if face and p:IsA('BasePart')then p.LocalTransparencyModifier=(face=='Asleep')~=asleep and 1 or 0 end end
  end
  -- R152: its void wisps at the cloak hem, hands and feet (KeeperFx152), by state and graphics tier
  if r.Fx152==nil and m:GetAttribute('KeeperMeshVariant')=='R152'then
   local mod=not Fx152 and RS:FindFirstChild('KeeperFx152');if mod then Fx152=require(mod)end
   r.Fx152=Fx152 and Fx152.new(m,0)or false
  end
  if r.Fx152 then local c=r.Fx152Ctx or{};r.Fx152Ctx=c;c.Now=now;c.Asleep=asleep;c.Chasing=not asleep;c.Striking=false;c.Distance=distance;c.Tier=tier;Fx152.Step(r.Fx152,c)end
  -- R112-style lead: a late-seen attack plays its wind-up from where this client first saw it.
  local attackAt=m:GetAttribute('KeeperAttackAt');if attackAt~=r.AttackAt then r.AttackAt=attackAt;r.Seen=now end
  local striking=type(attackAt)=='number'and now>=attackAt and now-attackAt<Combat.Get(7).Windup+Combat.Recovery
  if striking or now-r.At>=period then r.At=now;Art.Apply(m,now,Art.ClientFrames(m,now,r.Seen and r.Seen-(attackAt or now)))end
  local impact=type(attackAt)=='number'and attackAt+Combat.Get(7).Windup
  if impact and now>=impact and r.ImpactFor~=attackAt then
   r.ImpactFor=attackAt;if now-impact<.2 and distance<KFx.DustDistance then KFx.Accent('Spectral',root.CFrame*CFrame.new(0,-4,-6),root.CFrame,Fx.Get()==1)end
  end
 end
 -- R128 (owner): a carried Void Pack's rings and debris follow it every frame (they trailed behind at 30 Hz).
 if not effectTick then
  local reducedNow=Gui.ReducedMotionEnabled==true;table.clear(parts);table.clear(frames)
  for bag,r in pairs(bags)do local c=r.Capture
   if r.Carried and c and c.Fx and c.Root.Parent then PackFx.Step(c,now,c.Root.CFrame,tier,reducedNow,r.Lit,parts,frames)end
  end
  if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
  return
 end
 local reduced=Gui.ReducedMotionEnabled==true
 local B=PackFx.Budget
 table.clear(parts);table.clear(frames)
 local near={}
 for bag,r in pairs(bags)do
  if not bag.Parent then remove(bag);continue end
  if not r.Capture then r.Capture=PackFx.Capture(bag);if not r.Capture then continue end end
  local c=r.Capture
  if not c.Root.Parent then remove(bag);continue end
  local visible=bag:IsDescendantOf(workspace)and bag:GetAttribute('PackVisible')~=false and bag:GetAttribute('RevealAt')==nil
  local distance=(c.Root.Position-origin).Magnitude
  if c.Fx and(not visible or distance>=B.EffectDistance)then PackFx.Clear(c)end
  if not visible then continue end
  local frame=c.Root.CFrame
  if bag:GetAttribute('WorldPack')and bag.Name~='OpeningBag'and c.Anchored and distance<B.MotionDistance then
   frame=PackFx.Pose(c,now,parts,frames,not reduced and distance<B.SpinDistance)
  end
  r.Carried=not bag:GetAttribute('WorldPack')or bag.Name=='OpeningBag'
  if distance<B.EffectDistance then table.insert(near,{Capture=c,Distance=distance,Frame=frame,Record=r})end
 end
 table.sort(near,function(a,b)return a.Distance<b.Distance end)
 local budget=mode=='off'and 0 or B.Bags[tier]or 1
 for i,item in ipairs(near)do
  local c=item.Capture
  item.Record.Lit=i<=B.Lights
  if i>budget then if c.Fx then PackFx.Clear(c)end;continue end
  if c.Fx and c.Fx.Tier~=tier then PackFx.Clear(c)end
  if not c.Fx then PackFx.Create(c,tier)end
  PackFx.Pulse(c,now,reduced)
  PackFx.Step(c,now,item.Frame,tier,reduced,i<=B.Lights,parts,frames)
 end
 if #parts>0 then workspace:BulkMoveTo(parts,frames,Enum.BulkMoveMode.FireCFrameChanged)end
end)
script.Destroying:Connect(function()
 alive=false;for _,c in ipairs(connections)do c:Disconnect()end
 for _,r in pairs(bags)do if r.Capture then PackFx.Clear(r.Capture)end end;table.clear(bags)
 for _,r in pairs(keepers)do if r.Fx152 then Fx152.Destroy(r.Fx152)end end;table.clear(keepers)
 Arrival.Stop()
end)
