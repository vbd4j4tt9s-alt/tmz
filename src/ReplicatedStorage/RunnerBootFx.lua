-- R117: boot extras for RunnerTrailEffects, installed onto its class so they share its pools, budget and Destroy.
-- Attach: emitters inside the wearer's own boot parts (sprint trails on the soles, gem glints, ember wisps, coil
--   sparks) and the Thunder coil pulse. Only at full detail, the local wearer plus Budget.Attach others; removed after
--   Styles.Grace seconds below full detail, on release and on destroy. Coil colours are restored when detached.
-- Moments: a landing (or a sprint start from standing, tiers 3-5) fires the theme's Land particles, an expanding ring
--   of 8 ground segments and, for Thunder, a lightning bolt from the sky with a brief light. Pooled (Budget.Moments),
--   none under Reduced Motion, others' moments only on the mid/high budget.
-- BootArc: short arcs between the two boots (Thunder), through the shared arc pool.
-- Nothing here connects events or yields.
local Styles=require(script.Parent.RunnerTrailStyles)
local V,CF=Vector3.new,CFrame.new
local X={}
local RING=8 -- ring segments
local BOLT=6 -- main bolt segments; the branch adds 3
local function quiet(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Size=V(.1,.1,.1);p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Parent=parent;return p
end
-- The two boot models the server welded to this character (RunnerBootArt.Create).
local function boots(r)
 local out={}
 if not r.Cosmetics then return out end
 for _,m in ipairs(r.Cosmetics:GetChildren())do if m:IsA('Model')and(m.Name=='LeftRunnerBoot'or m.Name=='RightRunnerBoot')then table.insert(out,m)end end
 return out
end
X.Boots=boots
function X.Install(E,emitter)
 -- Attached emitters ------------------------------------------------------------------------------------------------
 function E:Attach(r)
  local theme=r.Theme;if not theme or r.Attach then return r.Attach end
  local a={Sprint={},Glint={},Coils={},Rates={},Away=0,Step=-1,Counted=not r.Local}
  for _,model in ipairs(boots(r))do
   local sole=model:FindFirstChild('Outsole')
   if theme.Sprint and sole then for _,spec in ipairs(theme.Sprint.Emitters)do table.insert(a.Sprint,{Emitter=emitter(sole,spec),Spec=spec})end end
   for _,spec in ipairs(theme.Glint or{})do
    local part=model:FindFirstChild(spec.On)
    if part and part:IsA('BasePart')then table.insert(a.Glint,{Emitter=emitter(part,spec),Spec=spec})end
   end
   if theme.Coils then
    local list={};for _,p in ipairs(model:GetChildren())do if p.Name==theme.Coils.Name and p:IsA('BasePart')then table.insert(list,p)end end
    table.sort(list,function(x,y)return x.CFrame.Position.Y<y.CFrame.Position.Y end) -- pulse runs up the leg
    for i,p in ipairs(list)do table.insert(a.Coils,{Part=p,Color=p.Color,Index=i})end
   end
  end
  if #a.Sprint==0 and#a.Glint==0 and#a.Coils==0 then return nil end
  r.Attach=a;if a.Counted then self.Attached+=1 end
  return a
 end
 function E:Detach(r)
  local a=r.Attach;if not a then return end
  r.Attach=nil;if a.Counted then self.Attached-=1 end
  for _,list in ipairs({a.Sprint,a.Glint})do for _,x in ipairs(list)do x.Emitter:Destroy()end end
  for _,c in ipairs(a.Coils)do if c.Part.Parent then c.Part.Color=c.Color end end
 end
 local function rate(a,i,x,value)
  if math.abs((a.Rates[i]or 0)-value)>=.25 or(value==0)~=((a.Rates[i]or 0)==0)then a.Rates[i]=value;x.Emitter.Rate=value;x.Emitter.Enabled=value>0 end
 end
 -- want = full detail for this runner; sprinting = running fast on the ground.
 function E:StepAttached(r,dt,now,want,sprinting,speed)
  local b=self.Budget;local a=r.Attach
  if want and not a and(r.Local or self.Attached<b.Attach)then a=self:Attach(r)end
  if not a then return end
  if want then a.Away=0 else a.Away+=dt;if a.Away>=Styles.Grace then self:Detach(r);return end end
  local i=0
  for _,x in ipairs(a.Sprint)do i+=1;rate(a,i,x,(want and sprinting)and x.Spec.Rate*b.Scale or 0)end
  for _,x in ipairs(a.Glint)do i+=1;rate(a,i,x,want and x.Spec.Rate*b.Scale or 0)end
  if #a.Coils>0 then
   local coil=r.Theme.Coils
   if want and not b.Reduced then
    -- Four brightness steps; colours are only written when a coil changes step.
    local phase=now*coil.Speed*(1+math.clamp(speed/120,0,1.5))
    for _,c in ipairs(a.Coils)do
     local k=math.floor(((math.sin(phase-c.Index*1.3)+1)*.5)^2*3+.5)
     if c.Step~=k then c.Step=k;c.Part.Color=c.Color:Lerp(coil.Hot,k/3*.85)end
    end
   else
    for _,c in ipairs(a.Coils)do if c.Step~=nil then c.Step=nil;c.Part.Color=c.Color end end
   end
  end
 end
 -- Moments: landing / sprint-start rings and lightning strikes ---------------------------------------------------------
 function E:TakeMoment(now)
  local b=self.Budget;if b.Moments<=0 then return nil end
  self.MomentCursor=self.MomentCursor%b.Moments+1
  local m=self.Moments[self.MomentCursor]
  if not m then m={Ring={},Bolt={}};self.Moments[self.MomentCursor]=m end
  self:EndMoment(m) -- reusing a busy slot cuts the old moment short
  return m
 end
 function E:EndMoment(m)
  m.Until=nil;m.Strike=nil
  for _,p in ipairs(m.Ring)do p.Transparency=1 end
  for _,p in ipairs(m.Bolt)do p.Transparency=1 end
  if m.Light then m.Light.Enabled=false end
 end
 function E:DestroyMoment(m)
  for _,p in ipairs(m.Ring)do p:Destroy()end;for _,p in ipairs(m.Bolt)do p:Destroy()end
  if m.Holder then m.Holder:Destroy()end
 end
 local function jag(m,top,bottom,spread)
  local points={top};local span=bottom-top
  local side=span:Cross(V(0,0,1));if side.Magnitude<.01 then side=V(1,0,0)end;side=side.Unit;local other=span:Cross(side).Unit
  for k=1,BOLT-1 do
   local f=k/BOLT;local j=spread*(1-f*.7)
   points[k+1]=top:Lerp(bottom,f)+side*((math.random()-.5)*2*j)+other*((math.random()-.5)*2*j)
  end
  points[BOLT+1]=bottom
  for k=1,BOLT do
   local p=m.Bolt[k];local s,e=points[k],points[k+1]
   p.Size=V(.22-.1*k/BOLT,.22-.1*k/BOLT,(e-s).Magnitude+.1);p.CFrame=CFrame.lookAt((s+e)*.5,e)
  end
  -- A branch forks off the second joint and dies out sideways.
  local from=points[3];local dir=(side*(math.random()<.5 and -1 or 1)+V(0,-1.1,0)).Unit
  for k=1,3 do
   local p=m.Bolt[BOLT+k];local to=from+dir*1.4+V((math.random()-.5)*.8,0,(math.random()-.5)*.8)
   p.Size=V(.09,.09,(to-from).Magnitude+.05);p.CFrame=CFrame.lookAt((from+to)*.5,to);from=to
  end
 end
 -- position = ground point under the feet. Returns the particles emitted (for tests and the per-second cap).
 function E:Moment(r,kind,position,now)
  local theme=r.Theme;local b=self.Budget
  if not theme or now<(r.NextMoment or 0)then return 0 end
  if kind=='Start'and not theme.Start then return 0 end
  r.NextMoment=now+Styles.MomentGap(r.Local)
  local frame=CF(position)
  local n=theme.Land and self:Burst(frame,theme,now,0,theme.Land)or 0
  if not(theme.Ring or theme.Strike)or(not r.Local and b.Tier<=1)then return n end
  local m=self:TakeMoment(now);if not m then return n end
  local scale=r.Scale or 1
  m.Center=position;m.Born=now;m.Theme=theme;m.Scale=scale;m.Kind=kind
  local life=theme.Ring and theme.Ring.Life or 0
  if theme.Ring then
   for i=#m.Ring+1,RING do m.Ring[i]=quiet(self.Folder,'Boot landing ring')end
   for i,p in ipairs(m.Ring)do local list=theme.Ring.Colors;p.Color=list[(i-1)%#list+1];p.Transparency=0 end
  end
  if theme.Strike then
   local s=theme.Strike;life=math.max(life,s.Life)
   for i=#m.Bolt+1,BOLT+3 do m.Bolt[i]=quiet(self.Folder,'Boot lightning')end
   m.Top=position+V((math.random()-.5)*4,s.Height,(math.random()-.5)*4);m.Strike=s;m.Flicked=false
   for i,p in ipairs(m.Bolt)do p.Color=i<=BOLT and s.Color or s.Glow;p.Transparency=0 end
   jag(m,m.Top,position,.9)
   if b.Light and s.Light then
    if not m.Holder then
     m.Holder=quiet(self.Folder,'Boot strike light');m.Light=Instance.new('PointLight');m.Light.Shadows=false;m.Light.Parent=m.Holder
    end
    m.Holder.CFrame=CF(position+V(0,2,0));m.Light.Color=s.Glow;m.Light.Range=s.Range;m.Light.Brightness=s.Light;m.Light.Enabled=true
   end
  end
  m.Until=now+life
  self:PlaceRing(m,0)
  return n
 end
 function E:PlaceRing(m,t)
  local ring=m.Theme.Ring;if not ring or not m.Ring[1]then return end
  local ease=1-(1-math.min(t/ring.Life,1))^3
  local radius=(.5+(ring.Radius-.5)*ease)*m.Scale;local width=ring.Width*(1-.5*ease)*m.Scale
  local length=2*radius*math.tan(math.pi/RING)+width
  local a=math.min(1,(t/ring.Life)^1.3)
  for i,p in ipairs(m.Ring)do
   local angle=(i-1)*2*math.pi/RING
   p.Size=V(width,.06,length);p.CFrame=CF(m.Center+V(math.cos(angle)*radius,.05,math.sin(angle)*radius))*CFrame.Angles(0,-angle,0)
   if math.abs(p.Transparency-a)>=.04 or a>=1 then p.Transparency=a end
  end
 end
 function E:StepMoments(now)
  for _,m in ipairs(self.Moments)do if m.Until then
   if now>=m.Until then self:EndMoment(m)
   else
    local t=now-m.Born;self:PlaceRing(m,t)
    local s=m.Strike
    if s then
     -- The bolt holds for a third of its life, re-forks once, then fades; the light fades with it.
     if not m.Flicked and t>=s.Life*.3 then m.Flicked=true;jag(m,m.Top,m.Center,.9)end
     local a=t<s.Life*.4 and 0 or math.min(1,(t-s.Life*.4)/(s.Life*.6))
     for _,p in ipairs(m.Bolt)do if math.abs(p.Transparency-a)>=.05 or a>=1 then p.Transparency=a end end
     if m.Light and m.Light.Enabled then m.Light.Brightness=s.Light*(1-math.min(1,t/s.Life))end
    end
   end
  end end
 end
 -- Arcs between the boots -----------------------------------------------------------------------------------------------
 function E:BootArc(r,now,left,right,scale)
  local every=r.Theme.BootArc and r.Theme.BootArc.Every or(r.Theme.Idle and r.Theme.Idle.BootArcs and r.Theme.Idle.ArcEvery)
  if not every or now<(r.NextBootArc or 0)then return nil end
  r.NextBootArc=now+every[1]+math.random()*(every[2]-every[1])
  local up=V(0,(.25+math.random()*.35)*scale,0)
  return self:Arc(left+up,right+up+V(0,(math.random()-.5)*.3*scale,0),now,r.Theme.ArcColor,.25*scale)
 end
end
return X
