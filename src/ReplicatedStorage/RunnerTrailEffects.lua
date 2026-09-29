-- R47: one client scheduler, two ground ribbons per eligible runner and a bounded reusable mark pool.
-- R111: every boot tier gets biome footprints that age (sand fades, frost crystallises, lava cools, crystal twinkles,
-- storm flickers), step bursts from one shared emitter set, and an idle aura while the wearer stands still.
-- Pools are capped by the RunnerTrailStyles budget. Nothing here connects events; Release/Destroy free everything.
local Rules=require(script.Parent.RunnerTrailRules)
local Styles=require(script.Parent.RunnerTrailStyles)
local E={};E.__index=E
local V,CF=Vector3.new,CFrame.new
local Mat=Enum.Material
local function cosmetic(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Size=V(.1,.1,.1);p.Transparency=1;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Material=Enum.Material.Neon;p.Parent=parent;return p
end
local function deactivate(trail,clear)
 trail.Enabled=false;if clear then trail:Clear()end
end
local function range(t)return NumberRange.new(t[1],t[2]or t[1])end
local function sequence(t)
 if #t>=3 then return NumberSequence.new({NumberSequenceKeypoint.new(0,t[1]),NumberSequenceKeypoint.new(.5,t[2]),NumberSequenceKeypoint.new(1,t[3])})end
 return NumberSequence.new({NumberSequenceKeypoint.new(0,t[1]),NumberSequenceKeypoint.new(1,t[2]or t[1])})
end
local SHAPES={Disc=Enum.ParticleEmitterShape.Disc,Cylinder=Enum.ParticleEmitterShape.Cylinder,Sphere=Enum.ParticleEmitterShape.Sphere,Box=Enum.ParticleEmitterShape.Box}
local function emitter(parent,spec)
 local e=Instance.new('ParticleEmitter');e.Name=spec.Name;e.Texture=spec.Texture
 e.Color=ColorSequence.new(spec.Color,spec.Tail or spec.Color);e.Size=sequence(spec.Size);e.Transparency=sequence(spec.Alpha or{0,1})
 e.Lifetime=range(spec.Life);e.Speed=range(spec.Speed or{0});e.SpreadAngle=Vector2.new(spec.Spread or 180,spec.Spread or 180)
 e.Acceleration=spec.Accel or Vector3.zero;e.Drag=spec.Drag or 0;e.LightEmission=spec.Glow or 0;e.LightInfluence=spec.Light or 1
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=range(spec.Spin or{-40,40});e.LockedToPart=spec.Locked==true;e.VelocityInheritance=0
 e.EmissionDirection=Enum.NormalId.Top
 if spec.Shape then e.Shape=SHAPES[spec.Shape]or Enum.ParticleEmitterShape.Box;e.ShapeStyle=spec.Style=='Surface'and Enum.ParticleEmitterShapeStyle.Surface or Enum.ParticleEmitterShapeStyle.Volume end
 e.Rate=0;e.Enabled=false;e.Parent=parent;return e
end
function E.new(parent)
 local old=(parent or workspace):FindFirstChild('RunnerGroundEffects');if old then old:Destroy()end
 local folder=Instance.new('Folder');folder.Name='RunnerGroundEffects';folder.Parent=parent or workspace
 return setmetatable({Folder=folder,Rings={Local={Marks={},Cursor=0},Others={Marks={},Cursor=0}},Records={},
  Bursts={},Arcs={},ArcCursor=0,IdleFree={},IdleRigs=0,IdleActive=0,Budget=Styles.Budget(3,false),Spent=0,SpentAt=-math.huge},E)
end
-- Budget changes shrink pools: idle marks/arcs above the new cap are destroyed, busy ones finish first.
function E:SetBudget(b)
 self.Budget=b
 for name,ring in pairs(self.Rings)do
  local limit=name=='Local'and b.LocalMarks or b.OtherMarks
  for i=#ring.Marks,limit+1,-1 do local m=ring.Marks[i];if m.Live then break end;for _,p in ipairs(m.Parts)do p:Destroy()end;ring.Marks[i]=nil end
  if ring.Cursor>limit then ring.Cursor=0 end
 end
 for i=#self.Arcs,b.Arcs+1,-1 do local a=self.Arcs[i];if a.Until then break end;for _,p in ipairs(a.Parts)do p:Destroy()end;self.Arcs[i]=nil end
 if self.ArcCursor>b.Arcs then self.ArcCursor=0 end
 for _,list in pairs(self.IdleFree)do
  while #list>0 and self.IdleRigs>b.Idle+1 do self:DestroyIdle(table.remove(list))end
 end
end
function E:Bind(character,cosmetics,isLocal)
 local players=game:GetService('Players')
 local r={Character=character,Cosmetics=cosmetics,Local=isLocal==true,Player=players:GetPlayerFromCharacter(character),Root=character:FindFirstChild('HumanoidRootPart'),Humanoid=character:FindFirstChildOfClass('Humanoid'),Body={},Ground={},LastStamp=-math.huge,Side=0,Still=0,Fade=0}
 self:RefreshBody(r)
 r.ThemeName=Styles.ThemeName(cosmetics);r.Theme=Styles.Theme(r.ThemeName)
 if r.Theme then
  local head,tail=r.Theme.Ribbon[1],r.Theme.Ribbon[2];local alpha=r.Theme.RibbonAlpha
  for i=1,2 do
   local p=cosmetic(self.Folder,'Ground ribbon anchor');local a=Instance.new('Attachment');a.Position=V(-.24,0,0);a.Parent=p
   local b=Instance.new('Attachment');b.Position=V(.24,0,0);b.Parent=p
   local t=Instance.new('Trail');t.Name='Boot ground ribbon';t.Attachment0=a;t.Attachment1=b;t.Color=ColorSequence.new(head,tail)
   t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,alpha),NumberSequenceKeypoint.new(.55,math.min(.9,alpha+.28)),NumberSequenceKeypoint.new(1,1)})
   t.WidthScale=NumberSequence.new(1,0);t.LightEmission=r.Theme.RibbonGlow;t.LightInfluence=.15;t.FaceCamera=false;t.MinLength=.09;t.Lifetime=.2;t.Enabled=false;t.Parent=p
   table.insert(r.Ground,{Part=p,Trail=t,A=a,B=b})
  end
 end
 self.Records[r]=true;return r
end
function E:RefreshBody(r)
 local body={}
 for _,p in ipairs(r.Cosmetics:GetDescendants())do if p:IsA('Trail')and p:GetAttribute('RunnerMovementTrail')then table.insert(body,p)end end
 r.Body=body
end
-- Compatibility for a still-running older trail client; creates no PNG effects.
function E:Premium(r,_on,_now)
 if r.Sprites then for _,s in ipairs(r.Sprites)do if s.Anchor then s.Anchor:Destroy()end end;r.Sprites=nil end
end
function E:Disable(r,clear)
 for _,t in ipairs(r.Body)do if t.Parent then deactivate(t,clear)end end
 for _,g in ipairs(r.Ground)do deactivate(g.Trail,clear)end
end
function E:Release(r)
 self:Premium(r,false,0)
 self:Disable(r,true)
 self:DropIdle(r,true)
 for _,g in ipairs(r.Ground)do g.Part:Destroy()end
 r.Ground={};self.Records[r]=nil
end
local function groundFrame(position,normal,forward)
 local along=forward-normal*forward:Dot(normal)
 if along.Magnitude<.001 then along=V(0,0,-1)-normal*V(0,0,-1):Dot(normal)end
 if along.Magnitude<.001 then return nil end
 along=along.Unit;local right=along:Cross(normal).Unit
 return CFrame.fromMatrix(position+normal*.035,right,normal,-along)
end
-- Footprints ------------------------------------------------------------------------------------------------
local function alpha(m,i,value)
 local p=m.Parts[i];if math.abs((m.Alpha[i]or -1)-value)>=.04 or(value>=1 and m.Alpha[i]~=1)then m.Alpha[i]=value;p.Transparency=value end
end
function E:Stamp(frame,theme,scale,now,ringName,speed,mirror)
 local b=self.Budget;local ring=self.Rings[ringName or'Local']or self.Rings.Local
 local limit=ring==self.Rings.Others and b.OtherMarks or b.LocalMarks
 if limit<=0 then return nil end
 ring.Cursor=ring.Cursor%limit+1
 local m=ring.Marks[ring.Cursor]
 if not m then
  m={Parts={}};for _=1,3 do table.insert(m.Parts,cosmetic(self.Folder,'Fading boot mark'))end;ring.Marks[ring.Cursor]=m
 end
 local P=theme.Print;speed=speed or 0
 m.Born=now;m.Life=Styles.Life(theme,speed);m.Live=true;m.Print=P;m.Stage=0;m.Step=nil;m.Alpha={};m.Seed=math.random()*6.28
 local shapes=Styles.PrintParts(P.Kind,scale,Styles.Stretch(speed),mirror or 1);m.Count=#shapes
 for i,p in ipairs(m.Parts)do
  local s=shapes[i]
  if s then
   p.Size=s.Size;p.CFrame=frame*s.Frame
   local accent=s.Tone==2
   if P.Kind=='Ember'or P.Kind=='Lightning'then p.Material=Mat.Neon;p.Color=accent and P.Accent or P.Color;p.Reflectance=0
   elseif P.Kind=='Crystal'then p.Material=accent and Mat.Neon or P.Material;p.Color=accent and P.Accent or P.Color;p.Reflectance=accent and 0 or P.Reflectance
   elseif P.Kind=='Frost'then p.Material=accent and Mat.Neon or P.Material;p.Color=accent and P.Accent or P.Color;p.Reflectance=accent and 0 or P.Reflectance
   else p.Material=P.Material;p.Color=accent and P.Accent or P.Color;p.Reflectance=0 end
   -- The frost star only appears once the print crystallises.
   alpha(m,i,(P.Kind=='Frost'and accent)and 1 or P.Alpha)
  else alpha(m,i,1)end
 end
 return m
end
local function fade(t,hold,a0)
 if t<=hold then return a0 end
 return a0+(1-a0)*((t-hold)/(1-hold))^1.5
end
function E:AgeMark(m,t,now,reduced)
 local P=m.Print;local kind=P.Kind;local a=fade(t,P.Hold or .35,P.Alpha)
 if kind=='Frost'then
  if m.Stage==0 and t>=P.Turn then
   m.Stage=1
   for i=1,2 do local p=m.Parts[i];p.Material=P.Material2;p.Color=P.Color2;p.Reflectance=0;p.Size=p.Size*V(1.08,1,1.08)end
  end
  alpha(m,1,a);alpha(m,2,a);alpha(m,3,m.Stage==0 and 1 or math.max(a,.2))
  return
 elseif kind=='Ember'then
  if m.Stage==0 then
   local step=math.floor(math.clamp(t/P.Turn,0,1)*4+.5)/4 -- five colour steps while the magma cools
   if step~=m.Step then m.Step=step;local c=P.Color:Lerp(P.Color2,step);m.Parts[1].Color=c;m.Parts[2].Color=c;m.Parts[3].Color=P.Accent:Lerp(P.Color2,step*.6)end
   if t>=P.Turn then m.Stage=1;for i=1,2 do m.Parts[i].Material=P.Material2;m.Parts[i].Color=P.Cool end end
  elseif m.Stage==1 and t>=P.Turn2 then m.Stage=2;m.Parts[3].Material=P.Material2;m.Parts[3].Color=P.Cool end
 elseif kind=='Crystal'then
  alpha(m,1,a);alpha(m,2,a)
  local twinkle=(not reduced and t<.6)and(.5+.5*math.sin(now*16+m.Seed))^2*.7 or 0
  alpha(m,3,math.max(a,twinkle))
  return
 elseif kind=='Lightning'then
  if m.Stage==0 and t>=P.Turn then m.Stage=1;for i=1,m.Count do m.Parts[i].Color=P.Color2 end end
  if not reduced and t<.4 then a=math.max(a,math.random()*.55)end -- live-wire flicker
 end
 for i=1,m.Count do alpha(m,i,a)end
end
function E:StepMarks(now)
 local reduced=self.Budget.Reduced
 for _,ring in pairs(self.Rings)do for _,m in ipairs(ring.Marks)do if m.Live then
  local t=math.clamp((now-m.Born)/m.Life,0,1)
  if t>=1 then m.Live=false;for i=1,3 do alpha(m,i,1)end else self:AgeMark(m,t,now,reduced)end
 end end end
 self:StepArcs(now)
end
-- Step bursts: one emitter set per look, moved to the print and emitted, capped per second ------------------
function E:Burst(frame,theme,now,speed)
 local b=self.Budget;if b.Scale<=0 or not theme.Burst then return 0 end
 if now-self.SpentAt>=1 then self.SpentAt=now;self.Spent=0 end
 local rig=self.Bursts[theme]
 if not rig then
  if not self.BurstHolder then self.BurstHolder=cosmetic(self.Folder,'Boot step bursts')end
  local a=Instance.new('Attachment');a.Name='Boot step burst';a.Parent=self.BurstHolder
  rig={Attachment=a,Emitters={}};for i,spec in ipairs(theme.Burst)do rig.Emitters[i]=emitter(a,spec)end;self.Bursts[theme]=rig
 end
 rig.Attachment.WorldCFrame=frame
 local k=Styles.BurstScale(speed,b);local total=0
 for i,spec in ipairs(theme.Burst)do
  local n=math.floor(spec.Count*k+.5);if i==1 then n=math.max(1,n)end
  if n>0 and self.Spent+n<=b.Particles then self.Spent+=n;total+=n;rig.Emitters[i]:Emit(n)end
 end
 return total
end
-- Static arcs (Storm): short jagged Neon lines from a small ring pool ---------------------------------------
function E:Arc(from,to,now,color,lift)
 local b=self.Budget;if b.Arcs<=0 or b.Reduced then return nil end
 self.ArcCursor=self.ArcCursor%b.Arcs+1
 local a=self.Arcs[self.ArcCursor]
 if not a then a={Parts={}};for _=1,3 do table.insert(a.Parts,cosmetic(self.Folder,'Boot static arc'))end;self.Arcs[self.ArcCursor]=a end
 local span=to-from;if span.Magnitude<.05 then return nil end
 local side=span:Cross(V(0,1,0));side=side.Magnitude>.001 and side.Unit or V(1,0,0)
 local points={from}
 for i=1,2 do points[i+1]=from:Lerp(to,i/3)+V(0,lift*(i==1 and .8 or .6),0)+side*((math.random()-.5)*.5*span.Magnitude)end
 points[4]=to
 for i=1,3 do
  local p=a.Parts[i];local s,e=points[i],points[i+1]
  p.Size=V(.06,.06,(e-s).Magnitude);p.CFrame=CFrame.lookAt((s+e)*.5,e);p.Color=color;p.Transparency=0
 end
 a.Until=now+.09;return a
end
function E:StepArcs(now)
 for _,a in ipairs(self.Arcs)do if a.Until and now>=a.Until then a.Until=nil;for _,p in ipairs(a.Parts)do p.Transparency=1 end end end
end
-- Idle aura: pooled rigs per look, faded in after standing still, out as soon as the wearer moves --------------
local function soles(r)
 local c=r.Character
 local left=c:FindFirstChild('LeftFoot')or c:FindFirstChild('Left Leg');local right=c:FindFirstChild('RightFoot')or c:FindFirstChild('Right Leg')
 if not(left and right and left:IsA('BasePart')and right:IsA('BasePart'))then return nil end
 local a=(left.CFrame*CF(0,-left.Size.Y*.5,0)).Position;local b=(right.CFrame*CF(0,-right.Size.Y*.5,0)).Position
 return a,b,math.clamp(left.Size.X,.4,2.5)
end
function E:TakeIdle(r)
 local b=self.Budget;local idle=r.Theme.Idle;if not idle or b.Idle<=0 then return nil end
 if self.IdleActive>=b.Idle+(r.Local and 1 or 0)then return nil end -- the local wearer may always have one
 local list=self.IdleFree[r.ThemeName];local rig=list and table.remove(list)
 if not rig then
  rig={Theme=r.ThemeName,Part=cosmetic(self.Folder,'Boot idle aura'),Emitters={},Shards={},Rates={},Angle=0,NextArc=0}
  rig.Part.Size=V(2.4,.2,2.4)
  for i,spec in ipairs(idle.Emitters)do rig.Emitters[i]=emitter(rig.Part,spec)end
  for i=1,idle.Shards or 0 do
   local s=cosmetic(self.Folder,'Boot idle shard');s.Material=i==1 and Mat.Neon or Mat.Glass;s.Color=i==1 and idle.ShardGlow or idle.ShardColor;s.Reflectance=i==1 and 0 or .5
   rig.Shards[i]=s
  end
  self.IdleRigs+=1
 end
 self.IdleActive+=1;r.Idle=rig;return rig
end
function E:DestroyIdle(rig)
 rig.Part:Destroy();for _,s in ipairs(rig.Shards)do s:Destroy()end;self.IdleRigs-=1
end
function E:DropIdle(r,clear)
 local rig=r.Idle;if not rig then return end
 r.Idle=nil;r.Fade=0;self.IdleActive-=1
 for i,e in ipairs(rig.Emitters)do e.Enabled=false;e.Rate=0;rig.Rates[i]=0;if clear then e:Clear()end end
 for _,s in ipairs(rig.Shards)do s.Transparency=1 end
 if self.IdleRigs>self.Budget.Idle+1 then self:DestroyIdle(rig);return end
 self.IdleFree[rig.Theme]=self.IdleFree[rig.Theme]or{};table.insert(self.IdleFree[rig.Theme],rig)
end
function E:StepIdle(r,dt,now,want)
 if want then r.Fade=math.min(1,r.Fade+dt/Styles.FadeIn)else r.Fade=math.max(0,r.Fade-dt/Styles.FadeOut)end
 if r.Fade<=0 then if r.Idle then self:DropIdle(r)end;return end
 local rig=r.Idle or self:TakeIdle(r);if not rig then r.Fade=0;return end
 local left,right,scale=soles(r);if not left then self:DropIdle(r,true);return end
 local b=self.Budget;local idle=r.Theme.Idle
 local center=(left+right)*.5;center=V(center.X,math.min(left.Y,right.Y)+.06,center.Z)
 local look=r.Root.CFrame.LookVector;local yaw=math.atan2(-look.X,-look.Z)
 if not b.Reduced then rig.Angle=(rig.Angle+dt*(idle.Spin or 0))%(2*math.pi)end
 rig.Part.Size=V(2.4*scale,.2,2.4*scale);rig.Part.CFrame=CF(center)*CFrame.Angles(0,yaw+rig.Angle,0)
 for i,e in ipairs(rig.Emitters)do
  local rate=idle.Emitters[i].Rate*r.Fade*b.Scale
  if math.abs(rate-(rig.Rates[i]or 0))>=.25 or(rate==0)~=((rig.Rates[i]or 0)==0)then rig.Rates[i]=rate;e.Rate=rate;e.Enabled=rate>0 end
 end
 for i,s in ipairs(rig.Shards)do
  local angle=rig.Angle+i*2.09;local bob=b.Reduced and 0 or math.sin(now*2+i)*.12
  s.Size=V(.18,.3,.18)*scale
  s.CFrame=CF(center+V(math.cos(angle)*1.15*scale,(.45+i*.12+bob)*scale,math.sin(angle)*1.15*scale))*CFrame.Angles(.4,b.Reduced and i or now*1.3+i,.3)
  local a=1-(i==1 and .9 or .85)*r.Fade;if math.abs(s.Transparency-a)>=.04 or a>=1 then s.Transparency=a end
 end
 if idle.ArcEvery and r.Fade>.5 and now>=rig.NextArc then
  rig.NextArc=now+idle.ArcEvery[1]+math.random()*(idle.ArcEvery[2]-idle.ArcEvery[1])
  self:Arc(left+V(0,.05,0),right+V(0,.05,0),now,r.Theme.ArcColor,.45*scale)
 end
end
-- Per-runner step ----------------------------------------------------------------------------------------------
-- detail: 3 = everything, 2 = prints (no bursts/aura), 1 = ground ribbons only. Defaults to 3.
function E:Step(r,dt,now,params,detail)
 detail=detail or 3
 r.Humanoid=r.Humanoid or r.Character:FindFirstChildOfClass('Humanoid')
 local root,h=r.Root,r.Humanoid
 if not root or not root.Parent or not h or not r.Cosmetics.Parent then self:Disable(r,true);self:DropIdle(r,true);return end
 local v=root.AssemblyLinearVelocity;local speed=V(v.X,0,v.Z).Magnitude
 local position=root.Position;local distance=r.LastPosition and(position-r.LastPosition).Magnitude or 0
 local discontinuous=Rules.Discontinuous(distance,dt,speed);r.LastPosition=position
 local blocked=discontinuous or r.Character:GetAttribute('ChestChaseRagdollActive')==true or h.Sit or h.PlatformStand
 local moving=Rules.Moving(speed,h.Health>0,blocked)
 for _,trail in ipairs(r.Body)do if trail.Parent then
  if blocked then deactivate(trail,true)else trail.Lifetime=Rules.Lifetime(speed);trail.Enabled=moving end
 end end
 local grounded=h.FloorMaterial~=Enum.Material.Air
 -- Treadmill training runs in place: show the idle aura there instead of stacking prints.
 local training=r.Player~=nil and r.Player:GetAttribute('TreadmillTraining')==true
 local still=r.Theme~=nil and h.Health>0 and grounded and not blocked and(training or speed<Styles.StillSpeed)
 r.Still=still and r.Still+dt or 0
 self:StepIdle(r,dt,now,still and r.Still>=Styles.StillDelay and detail>=3)
 if not r.Theme or training or not Rules.Ground(speed,grounded,h.Health>0,blocked)then
  for _,g in ipairs(r.Ground)do deactivate(g.Trail,blocked or not grounded)end
  r.StampPosition=nil;return
 end
 local hits={}
 for i,side in ipairs({'Left','Right'})do
  local foot=r.Character:FindFirstChild(side..'Foot')or r.Character:FindFirstChild(side..' Leg');local g=r.Ground[i]
  if foot and foot:IsA('BasePart')then
   local scale=math.clamp(foot.Size.X,.4,2.5)
   local sole=(foot.CFrame*CF(0,-foot.Size.Y*.5,0)).Position
   local hit=workspace:Raycast(sole+V(0,1.4*scale,0),V(0,-3.3*scale,0),params)
   local frame=hit and hit.Normal.Y>.5 and groundFrame(hit.Position,hit.Normal,root.CFrame.LookVector)
   if frame then
    g.Part.CFrame=frame;g.A.Position=V(-.24*scale,0,0);g.B.Position=V(.24*scale,0,0)
    g.Trail.Lifetime=math.clamp(5/math.max(speed,1),.04,.34);g.Trail.Enabled=true;hits[i]={Frame=frame,Scale=scale}
   else deactivate(g.Trail,false)end
  else deactivate(g.Trail,true)end
 end
 if detail<2 then return end
 if now-r.LastStamp>=Styles.Interval(r.Local,self.Budget)and(not r.StampPosition or(position-r.StampPosition).Magnitude>=Styles.Spacing(speed))then
  r.Side=r.Side%2+1;local hit=hits[r.Side]or hits[3-r.Side]
  if hit then
   self:Stamp(hit.Frame,r.Theme,hit.Scale,now,r.Local and'Local'or'Others',speed,r.Side==1 and -1 or 1)
   if detail>=3 then
    self:Burst(hit.Frame,r.Theme,now,speed)
    if r.Theme.Arc and math.random()<r.Theme.Arc then
     local up=hit.Frame.UpVector;local start=hit.Frame.Position;self:Arc(start,start+up*1.1*hit.Scale-hit.Frame.LookVector*.5,now,r.Theme.ArcColor,.2)
    end
   end
   r.LastStamp=now;r.StampPosition=position
  end
 end
end
function E:Destroy()
 for r in pairs(self.Records)do self:Release(r)end
 self.Records={};self.Rings={Local={Marks={},Cursor=0},Others={Marks={},Cursor=0}};self.Bursts={};self.Arcs={};self.IdleFree={};self.IdleRigs=0;self.IdleActive=0
 self.Folder:Destroy()
end
return E
