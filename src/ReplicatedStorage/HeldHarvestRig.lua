-- Rigid fruit follows Roblox's tool grip; only small joint groups animate in Lua.
local RS=game:GetService('ReplicatedStorage')
local Geometry=require(RS:WaitForChild('HarvestGeometry'))
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Visuals=require(RS:WaitForChild('PlantVisuals'))
local Maw=require(RS:WaitForChild('ObsidianMawMotion'))
local Bells=require(RS:WaitForChild('FrostbellMotion'))
local Effects=require(RS:WaitForChild('PlantEffects'))
local Packs=require(RS:WaitForChild('SeedPackRules'))
local Rig={}
function Rig.Create(model,crop,index,handle)
 local grip=Geometry.Grip(model);local offset=CFrame.new(0,0,-.04)*CFrame.new(-grip)
 local r={Visual=model,Crop=crop,Def=Catalog[crop.SeedId],OnlyFruit=index,Handle=handle,Offset=offset,Joints={},Origin=handle.CFrame*offset}
 local parts={};for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then table.insert(parts,p)end end
 local groups={}
 for _,p in ipairs(parts)do
  local kind=p:GetAttribute('MawJaw')and'Maw'or p:GetAttribute('BellIndex')and'Bell'or p:GetAttribute('FloatingPetal')and'Petal'
  local index0=p:GetAttribute('MawJaw')or p:GetAttribute('BellIndex')or(#r.Joints+1)
  local groupKey=kind and kind..':'..index0
  local g=groupKey and groups[groupKey]
  if kind and not g then
   local pivot=kind=='Maw'and p:GetAttribute('MawPivot')or kind=='Bell'and CFrame.new(p:GetAttribute('BellPivot'))or CFrame.new(Visuals.FruitSocket(crop,r.Def,index)*(crop.PlantScale or 1))
   local hub=Instance.new('Part');hub.Name='HarvestJoint';hub.Size=Vector3.new(.05,.05,.05);hub.Transparency=1;hub.Anchored=false;hub.CanCollide=false;hub.CanQuery=false;hub.CanTouch=false;hub.Massless=true;hub.CFrame=handle.CFrame*offset*pivot;hub.Parent=model
   local motor=Instance.new('Motor6D');motor.Name='Harvest'..kind;motor.Part0=handle;motor.Part1=hub;motor.C0=offset*pivot;motor.C1=CFrame.new();motor.Parent=hub
   g={Hub=hub,Motor=motor,Kind=kind,Index=index0,Side=p:GetAttribute('MawSide')or 1};groups[groupKey]=g;table.insert(r.Joints,g)
  end
  p.CFrame=handle.CFrame*offset*p.CFrame;p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
  local weld=Instance.new('WeldConstraint');weld.Name='HarvestWeld';weld.Part0=g and g.Hub or handle;weld.Part1=p;weld.Parent=p
 end
 model.Name='HeldHarvestArt';model.Parent=handle.Parent
 r.Container=Instance.new('Model');r.Container.Name='HeldHarvestEffects';r.Container:SetAttribute('FruitReady',true);r.Container.Parent=handle.Parent
 return r
end
function Rig.Step(r,t,wantEffects,audible)
 for _,g in ipairs(r.Joints)do
  if g.Kind=='Maw'then
   local a=Maw.Angle(r.Crop.Id,t,g.Index)
   if g.Angle~=a then g.Transform=CFrame.Angles(0,0,g.Side*a);g.Angle=a end
  elseif g.Kind=='Bell'then
   local phase=Bells.Phase(r.Crop.Id,t);local dt=math.max(0,phase-(g.Index-1)*.035)
   local a=phase<1.7 and math.sin(dt*16+g.Index*.35)*math.exp(-dt*2.5)*.13 or 0
   if g.Angle~=a then g.Transform=CFrame.Angles(0,0,a);g.Angle=a end
  else g.Transform=CFrame.Angles(0,math.sin(t*.23)*.16,0)*CFrame.new(0,math.sin(t*.72+g.Index)*.075*r.Crop._VisualHarvest.Scale,0)end
 end
 if r.Crop.SeedId=='SilentFrostbellSeed'then
  local phase,cycle=Bells.Phase(r.Crop.Id,t)
  if audible and r.LastCycle~=nil and cycle~=r.LastCycle and phase<.35 then
   if not r.Sound and r.Joints[1]then
    local sound=Instance.new('Sound');sound.Name='Frostbell jingle';sound.SoundId=Packs.RevealBellSoundId;sound.Volume=.08;sound.RollOffMinDistance=4;sound.RollOffMaxDistance=32;sound.PlaybackSpeed=1.35;sound.Parent=r.Joints[1].Hub;r.Sound=sound
   end
   if r.Sound then r.Sound:Play()end
  end
  r.LastCycle=cycle
 end
 if wantEffects then
  if not r.FxStarted then r.Origin=r.Handle.CFrame*r.Offset;Effects.Create(r.Container,r,r.Def,r.Crop,r.Origin,'normal');r.FxStarted=true end
  if r.Effects then Effects.Step(r,t,nil,r.Handle.CFrame*r.Offset)end
 elseif r.FxStarted then Effects.Clear(r);r.FxStarted=false end
end
-- R128: move a running effect set to the hand's current frame (no animation work, no new parts).
function Rig.Follow(r,t)if r.FxStarted and r.Effects and r.Handle.Parent then Effects.Step(r,t,nil,r.Handle.CFrame*r.Offset)end end
function Rig.Apply(r)for _,g in ipairs(r.Joints)do if g.Motor.Parent then g.Motor.Transform=g.Transform or CFrame.new()end end end
function Rig.Destroy(r)Effects.Clear(r);r.Container:Destroy();r.Visual:Destroy()end
return Rig
