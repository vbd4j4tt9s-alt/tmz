-- Called by the existing capped effects scheduler. No per-tree event connections or server motion.
local M={};local ids={StormSovereignSeed=true,PulsarStarfruitSeed=true,SolarStarfruitSeed=true,EmberEmperorSeed=true}
function M.Has(id)return ids[id]==true or require(script.Parent.MechCatalog).Is(id)end
function M.Capture(model,origin)
 local state={Parts={},Pulses={}}
 for _,p in ipairs(model:GetDescendants())do if p:IsA('BasePart')then
  local kind=p:GetAttribute('TreeMotion')
  if kind then table.insert(state.Parts,{Part=p,Home=origin:ToObjectSpace(p.CFrame),Pivot=origin:ToObjectSpace(p:GetAttribute('TreeMotionPivot')),Kind=kind,Phase=p:GetAttribute('TreePhase')or 0,Rate=p:GetAttribute('TreeRate')or .1,Scale=math.min(3,p:GetAttribute('TreeMotionScale')or 1),Color=p.Color})end
  local pulse=p:GetAttribute('TreeLightningAt')
  if pulse then table.insert(state.Pulses,{Part=p,At=pulse,Trail=p:GetAttribute('TreeLightningTrail')or 0,Alpha=p.Transparency})end
 end end
 return state
end
function M.Step(state,origin,time,identity,batch)
 local h=0;identity=tostring(identity or'');for i=1,#identity do h=(h*31+identity:byte(i))%997 end
 local t=time+h*.037
 for _,r in ipairs(state.Parts)do if r.Part.Parent then
  if r.Kind=='core'then r.Part.Color=r.Color:Lerp(Color3.fromRGB(255,205,104),.08+.055*math.sin(t*.8))
  else
   local motion
   if r.Kind=='cloud'then
    local p=r.Phase;local s=r.Scale
    motion=CFrame.new(math.sin(t*.35+p)*.18*s,math.sin(t*.43+p)*.10*s,math.cos(t*.30+p)*.15*s)*CFrame.Angles(0,math.sin(t*.2+p)*.05,0)
   elseif r.Kind=='mechZ'then motion=CFrame.Angles(0,0,t*r.Rate)
   elseif r.Kind=='mechX'then motion=CFrame.Angles(t*r.Rate,0,0)
   else motion=CFrame.Angles(0,t*r.Rate,0)end
   local frame=origin*r.Pivot*motion*r.Pivot:Inverse()*r.Home
   if batch then batch:Set(r.Part,frame)else r.Part.CFrame=frame end
  end
 end end
 for _,r in ipairs(state.Pulses)do if r.Part.Parent then
  local phase=((t+r.Trail*.13)%8-.6)/1.45
  local alpha=(phase>=r.At and phase<r.At+.22)and .04 or .96
  if r.Part.Transparency~=alpha then r.Part.Transparency=alpha end
 end end
end
function M.Reset(state,origin)
 for _,r in ipairs(state.Parts)do if r.Part.Parent then r.Part.CFrame=origin*r.Home;r.Part.Color=r.Color end end
 for _,r in ipairs(state.Pulses)do if r.Part.Parent then r.Part.Transparency=r.Alpha end end
end
return M
