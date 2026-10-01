-- R122: client-only motion and effects for the Void Pack (EclipseReliquary) art from EclipsePackArt.
-- Budgeted by ClientFxBudget tier (FastMode = tier 1), GuiService.ReducedMotionEnabled and distance.
-- Every effect object lives in one local folder under workspace; nothing is parented into the
-- pack model, so cloned copies (opening reveal, tools) never inherit client effects.
local X={}
local V,CF=Vector3.new,CFrame.new
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
-- Per-tier limits. Tier 1 = FastMode / slow device, 3 = full quality.
X.Budget={
 Bags={[1]=1,[2]=2,[3]=4},      -- packs that may own effects at once (nearest first)
 Debris={[1]=2,[2]=4,[3]=6},    -- orbiting debris pieces per pack
 Comets={[1]=0,[2]=1,[3]=2},    -- trailed comets per pack
 Lights=1,                      -- one pulsing light in the whole scene (nearest pack, tier 3)
 EffectDistance=160,MotionDistance=850,SpinDistance=160,
}
local function isFinite(n)return type(n)=='number'and n==n and math.abs(n)<math.huge end
function X.Capture(bag)
 local root=bag.PrimaryPart
 if not root or not bag:GetAttribute('CompactPackReady')then return nil end
 local r={Bag=bag,Root=root,Scale=bag:GetAttribute('VisualScale')or 1,Origin=bag:GetAttribute('HoverOrigin')or root.CFrame,
  Parts={},Spinners=0,Pulsers={},Anchored=root.Anchored}
 for _,p in ipairs(bag:GetDescendants())do if p:IsA('BasePart')then
  local frame=p:GetAttribute('PackLocalFrame');if typeof(frame)~='CFrame'then frame=root.CFrame:ToObjectSpace(p.CFrame)end
  local e={Part=p,Frame=frame}
  local rate=p:GetAttribute('VoidSpin');local pivot=p:GetAttribute('VoidPivot')
  if isFinite(rate)and typeof(pivot)=='CFrame'then e.Spin=rate;e.Pivot=pivot;e.Offset=pivot:ToObjectSpace(frame);r.Spinners+=1 end
  local pulse=p:GetAttribute('VoidPulse')
  if isFinite(pulse)and pulse>0 then table.insert(r.Pulsers,{Part=p,Color=p.Color,Amount=math.clamp(pulse,0,.8),Phase=p:GetAttribute('VoidPhase')or 0})end
  table.insert(r.Parts,e)
 end end
 return r
end
-- Local frame of one captured part at time t (spin only when allowed).
function X.LocalFrame(e,t,spin)
 if spin and e.Spin then return e.Pivot*CFrame.Angles(0,0,(t*e.Spin)%(math.pi*2))*e.Offset end
 return e.Frame
end
-- World hover pose (same motion as before R122) plus galaxy / halo spin near the camera.
function X.Pose(r,now,parts,frames,spin)
 local frame=r.Origin*CF(0,math.sin(now*1.2)*.16,0)*CFrame.Angles(0,math.sin(now*.35)*.13,math.sin(now*.55)*.018)
 for _,e in ipairs(r.Parts)do if e.Part.Parent then
  parts[#parts+1]=e.Part;frames[#frames+1]=frame*X.LocalFrame(e,now,spin)
 end end
 return frame
end
-- Heartbeat glow on the eye, photon ring, stars and runes (colour only; restored on release).
function X.Pulse(r,now,reduced)
 for _,e in ipairs(r.Pulsers)do if e.Part.Parent then
  local wave=reduced and .5 or .5+.5*math.sin(now*(e.Amount>.5 and 3.1 or 1.7)+e.Phase)
  -- A double "heartbeat" on the pupil: two quick swells every ~2 s.
  if e.Amount>=.55 and not reduced then local beat=(now+e.Phase)%2.1;wave=math.max(wave*.5,math.exp(-((beat-.15)/.09)^2),math.exp(-((beat-.45)/.09)^2))end
  e.Part.Color=e.Color:Lerp(Color3.new(1,1,1),wave*e.Amount*.6)
 end end
end
function X.Restore(r)
 for _,e in ipairs(r.Pulsers)do if e.Part.Parent then e.Part.Color=e.Color end end
end
local function fxPart(folder,name,size,color,material,shape)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=material or Enum.Material.Neon
 if shape then p.Shape=shape end
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=folder;return p
end
local function emitter(parent,name,texture,colors,size,rate,life,speed,emission,alpha)
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Texture=texture;e.Color=ColorSequence.new(colors[1],colors[2])
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size[1]),NumberSequenceKeypoint.new(1,size[2])})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,alpha),NumberSequenceKeypoint.new(1,1)})
 e.Rate=rate;e.Lifetime=NumberRange.new(life[1],life[2]);e.Speed=NumberRange.new(speed[1],speed[2]);e.SpreadAngle=Vector2.new(180,180)
 e.LightEmission=emission;e.LightInfluence=emission>0 and 0 or .25;e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-35,35)
 e.Parent=parent;return e
end
-- Create (once) the effect set for one pack at the given tier.
function X.Create(r,tier)
 local s=r.Scale;local folder=Instance.new('Folder');folder.Name='_VoidPackFx122'
 local core=fxPart(folder,'VoidFxCore',V(.1,.1,.1),Color3.new(),Enum.Material.SmoothPlastic);core.Transparency=1
 local fx={Folder=folder,Core=core,Tier=tier,Debris={},Comets={}}
 local attach=Instance.new('Attachment');attach.Name='VoidFxEmit';attach.Parent=core
 -- Dark gravitational haze, a slow violet nebula swirl and falling star sparks.
 fx.Haze=emitter(attach,'VoidHaze',SMOKE,{Color3.fromRGB(6,3,14),Color3.fromRGB(40,18,66)},{.6*s,1.5*s},5,{.9,1.5},{.1,.35},0,.30)
 fx.Nebula=emitter(attach,'VoidNebulaSwirl',SMOKE,{Color3.fromRGB(255,90,210),Color3.fromRGB(80,170,255)},{.9*s,1.9*s},2.5,{1.6,2.4},{.05,.25},.7,.62)
 fx.Stars=emitter(attach,'VoidStarfall',SPARK,{Color3.fromRGB(255,255,255),Color3.fromRGB(150,232,255)},{.10*s,.03*s},4,{.6,1.1},{.2,.6},1,.15)
 for i=1,X.Budget.Debris[tier]or 0 do
  local size=(.10+.05*((i*37)%3))*s
  fx.Debris[i]=fxPart(folder,'VoidDebris',V(size,size*.8,size*.9),Color3.fromRGB(24,16,38),Enum.Material.Slate)
 end
 for i=1,X.Budget.Comets[tier]or 0 do
  local comet=fxPart(folder,'VoidComet',V(.12,.12,.12)*s,Color3.fromRGB(255,190,250),Enum.Material.Neon,Enum.PartType.Ball)
  local a0=Instance.new('Attachment');a0.Position=V(0,.05*s,0);a0.Parent=comet
  local a1=Instance.new('Attachment');a1.Position=V(0,-.05*s,0);a1.Parent=comet
  local trail=Instance.new('Trail');trail.Attachment0=a0;trail.Attachment1=a1;trail.Lifetime=.35;trail.LightEmission=1;trail.FaceCamera=true
  trail.Color=ColorSequence.new(Color3.fromRGB(255,160,240),Color3.fromRGB(120,90,255))
  trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)});trail.Parent=comet
  fx.Comets[i]={Part=comet,Trail=trail}
 end
 local h=Instance.new('Highlight');h.Name='VoidDistortion';h.Adornee=r.Bag;h.FillColor=Color3.fromRGB(20,6,40);h.FillTransparency=.88
 h.OutlineColor=Color3.fromRGB(150,80,230);h.OutlineTransparency=.35;h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=folder;fx.Highlight=h
 local light=Instance.new('PointLight');light.Name='VoidPulseLight';light.Color=Color3.fromRGB(170,90,255);light.Range=math.min(16,8*s);light.Brightness=0;light.Shadows=false;light.Enabled=false;light.Parent=core;fx.Light=light
 folder.Parent=workspace
 r.Fx=fx;return fx
end
function X.Clear(r)
 if r.Fx then r.Fx.Folder:Destroy();r.Fx=nil end
 X.Restore(r)
end
-- Moves effect parts in the same BulkMoveTo batch as the pack.
function X.Step(r,now,frame,tier,reduced,lit,parts,frames)
 local fx=r.Fx;if not fx then return end
 local s=r.Scale
 parts[#parts+1]=fx.Core;frames[#frames+1]=frame
 fx.Haze.Enabled=tier>1;fx.Haze.Rate=tier==3 and 5 or 2
 fx.Nebula.Enabled=tier>1 and not reduced
 fx.Stars.Enabled=tier==3
 fx.Light.Enabled=lit and tier==3
 if fx.Light.Enabled then fx.Light.Brightness=reduced and 1.4 or 1.4+.8*math.sin(now*2.2)end
 fx.Highlight.OutlineTransparency=reduced and .4 or .3+.12*math.sin(now*1.6)
 -- Orbiting debris on a tilted ring; frozen in place under Reduced Motion.
 local t=reduced and 0 or now
 local orbit=frame*CFrame.Angles(.35,0,.2)
 for i,p in ipairs(fx.Debris)do
  local a=t*.9+(i-1)*math.pi*2/#fx.Debris;local radius=(1.75+.12*(i%2))*s
  parts[#parts+1]=p;frames[#frames+1]=orbit*CF(math.cos(a)*radius,math.sin(a*2)*.12*s,math.sin(a)*radius)*CFrame.Angles(t*1.3+i,t*.7,i)
 end
 for i,c in ipairs(fx.Comets)do
  c.Trail.Enabled=not reduced
  local a=-t*2.2+(i-1)*math.pi;local radius=1.55*s
  parts[#parts+1]=c.Part;frames[#frames+1]=frame*CFrame.Angles(-.5+i*.4,0,.3)*CF(math.cos(a)*radius,0,math.sin(a)*radius)
 end
end
return X
