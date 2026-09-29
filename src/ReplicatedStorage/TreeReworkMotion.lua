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
   elseif r.Kind=='pupil'then
    -- R111: the Ember King's crust is its pupil. It darts to a random spot on the molten dome, holds, then darts again.
    -- The dome is the 14.8 x 6.6 x 14.8 heart around the pivot; spots stay within 2 studs of its centre so the crust never slides off.
    local s,seed=r.Scale,r.Phase+h*.013
    local function spot(k)
     if (math.sin(k*7.137+seed*3.1)*9631.7)%1<.3 then k-=1 end -- sometimes keep staring
     local u,v=(math.sin(k*12.9898+seed*78.233)*43758.5453)%1,(math.sin(k*39.346+seed*11.135)*24634.6345)%1
     local a,d=u*math.pi*2,math.sqrt(v)*2*s
     return math.cos(a)*d,math.sin(a)*d
    end
    local function dome(x,z)return 3.3*s*math.sqrt(math.max(0,1-(x*x+z*z)/(7.4*s)^2))end
    local period=1.35;local k=math.floor(t/period);local w=math.clamp((t-k*period)/.22,0,1);w=w*w*(3-2*w)
    local x0,z0=spot(k-1);local x1,z1=spot(k)
    local x,z=x0+(x1-x0)*w,z0+(z1-z0)*w
    local hx,hz=r.Home.X-r.Pivot.X,r.Home.Z-r.Pivot.Z
    local frame=origin*CFrame.new(x-hx,dome(x,z)-dome(hx,hz),z-hz)*r.Home
    if batch then batch:Set(r.Part,frame)else r.Part.CFrame=frame end
   elseif r.Kind=='mechZ'then motion=CFrame.Angles(0,0,t*r.Rate)
   elseif r.Kind=='mechX'then motion=CFrame.Angles(t*r.Rate,0,0)
   else motion=CFrame.Angles(0,t*r.Rate,0)end
   if motion then
    local frame=origin*r.Pivot*motion*r.Pivot:Inverse()*r.Home
    if batch then batch:Set(r.Part,frame)else r.Part.CFrame=frame end
   end
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
