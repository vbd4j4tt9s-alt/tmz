-- R151: what EVERYONE near a Secret / Cosmic / King pull sees in the world (the puller included, when the camera is back): client-side on
-- each viewer, through the onlooker path (SeedPackClient sees the reveal on the bag and calls Begin). Nobody but the puller sees the story
-- scene itself.
--  Charge (until the seed bursts out, RarityRevealSequence.SeedAt): motes spiral down into the pack's mouth in the tier colour.
--  Burst: a light pillar from the pack into the sky (bragging rights: seen from far away), a shockwave ring on the ground, sparkles, a flash.
--  Afterglow (15 / 20 / 25 s): a tier aura stays around the puller - Secret: shadowy purple wisps; Cosmic: two little orbiting planets and
--  star motes; King: a gold halo ring at the feet and rising gold sparkles - with a quiet hum (RarePullSounds.AuraHum, 3D).
-- One RenderStepped connection while any effect lives, none after (no per-frame work after the afterglow). Far away (160+ studs) nothing is
-- moved; phones / low quality use fewer pieces; ReducedMotion keeps the pillar and aura but nothing swings.
local Players=game:GetService('Players');local Run=game:GetService('RunService')
local Rules=require(script.Parent.RarePullRules)
local W={}
local V,CF,ANG=Vector3.new,CFrame.new,CFrame.Angles
local C=Color3.fromRGB
local SPARK='rbxasset://textures/particles/sparkles_main.dds';local SMOKE='rbxasset://textures/particles/smoke_main.dds'
W.FarDistance=160
local effects={} -- [player] = effect
local connection,folder
local function clamp01(x)return math.clamp(x,0,1)end
local function part(parent,name,size,color,shape,trans)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Material=Enum.Material.Neon;p.Size=size;p.Color=color;p.Transparency=trans or 1;if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function emitter(parent,props)
 local e=Instance.new('ParticleEmitter');e.Texture=SPARK;e.LightEmission=1;e.LightInfluence=0;e.Enabled=false
 for k,v in pairs(props)do e[k]=v end;e.Parent=parent;return e
end
local function lite()
 local ok,B=pcall(require,script.Parent.ClientFxBudget);if ok and B then local ok2,low=pcall(B.Low);if ok2 and low then return true end end
 local UIS=game:GetService('UserInputService');return UIS.TouchEnabled and not UIS.KeyboardEnabled
end
local function reduced()local ok,v=pcall(function()return game:GetService('GuiService').ReducedMotionEnabled end);return ok and v==true end
local function stopEffect(player)
 local e=effects[player];if not e then return end
 effects[player]=nil
 if e.Folder then e.Folder:Destroy()end
 if e.Attachment then e.Attachment:Destroy()end
 if next(effects)==nil and connection then connection:Disconnect();connection=nil end
end
local step
-- player: whose pull; character: their character; rank 6..8; at: the reveal's RevealAt (server time).
function W.Begin(player,character,rank,at,opts)
 if rank<6 or not player or not character then return nil end
 local old=effects[player];if old and old.At==at then return old end
 if old then stopEffect(player)end
 opts=opts or{}
 if not folder or not folder.Parent then folder=Instance.new('Folder');folder.Name='_RarePullWorld';folder.Parent=workspace end
 local tier=Rules.Tier(rank);local isLite=opts.Lite;if isLite==nil then isLite=lite()end
 local e={Player=player,Character=character,Rank=rank,At=at,Tier=tier,TL=Rules.WorldTimeline(rank),Lite=isLite,Reduced=opts.Reduced or reduced(),Motes={},Ring={},Planets={}}
 local f=Instance.new('Folder');f.Name='RarePull '..tier.Key;f.Parent=folder;e.Folder=f
 local color=tier.Theme or tier.Hint
 for i=1,(isLite and 6 or 10)do e.Motes[i]=part(f,'Charge mote',V(.16,.16,.16),i%3==0 and tier.Glow or color,Enum.PartType.Ball)end
 e.Pillar=part(f,'Light pillar',V(1,1,1),tier.Glow,Enum.PartType.Cylinder)
 e.Core=part(f,'Pillar core',V(1,1,1),C(255,255,255),Enum.PartType.Cylinder)
 for i=1,(isLite and 12 or 18)do e.Ring[i]=part(f,'Shockwave',V(.4,.1,.3),color)end
 e.Anchor=part(f,'Burst anchor',V(.1,.1,.1),color)
 local light=Instance.new('PointLight');light.Color=color;light.Brightness=0;light.Range=16;light.Shadows=false;light.Parent=e.Anchor;e.Light=light
 e.Sparks=emitter(e.Anchor,{Color=ColorSequence.new(tier.Glow,color),Lifetime=NumberRange.new(.6,1.2),Speed=NumberRange.new(6,13),SpreadAngle=Vector2.new(180,180),
  Acceleration=V(0,-6,0),Drag=1.5,Size=NumberSequence.new(.45,0),Transparency=NumberSequence.new(0,1)})
 effects[player]=e
 if not connection then connection=Run.RenderStepped:Connect(function()step()end)end
 return e
end
function W.SetMouth(player,cf)local e=effects[player];if e then e.Mouth=cf end end
function W.Stop(player)stopEffect(player)end
function W.Count()local n=0;for _ in pairs(effects)do n+=1 end;return n end
function W.Connected()return connection~=nil end
function W.Get(player)return effects[player]end
local function buildAura(e,root)
 local tier=e.Tier;local att=Instance.new('Attachment');att.Name='RarePullAura';att.Parent=root;e.Attachment=att
 if e.Rank==6 then
  e.AuraEmitters={emitter(att,{Texture=SMOKE,LightEmission=.15,Color=ColorSequence.new(C(90,30,150),C(20,4,40)),Rate=e.Lite and 2.5 or 5,Lifetime=NumberRange.new(1.5,2.5),
   Speed=NumberRange.new(.3,.9),SpreadAngle=Vector2.new(40,40),Size=NumberSequence.new(1.4,2.8),EmissionDirection=Enum.NormalId.Top,
   Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.55),NumberSequenceKeypoint.new(1,1)})}),
   emitter(att,{Color=ColorSequence.new(C(200,150,255)),Rate=e.Lite and 1.5 or 3,Lifetime=NumberRange.new(.8,1.4),Speed=NumberRange.new(.2,.6),SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new(.2,0)})}
 elseif e.Rank==7 then
  e.AuraEmitters={emitter(att,{Color=ColorSequence.new(C(255,255,255),C(160,190,255)),Rate=e.Lite and 2 or 4,Lifetime=NumberRange.new(1,1.8),Speed=NumberRange.new(.2,.6),
   SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new(.22,0)})}
  for i,s in ipairs({{.5,C(255,160,120),2.3},{.36,C(130,190,255),2.9}})do
   local b=part(e.Folder,'Aura planet',V(s[1],s[1],s[1]),s[2],Enum.PartType.Ball,1);b.Material=Enum.Material.SmoothPlastic
   e.Planets[i]={Part=b,Radius=s[3],Speed=1.1-.25*i}
  end
  e.PlanetRing=part(e.Folder,'Aura planet ring',V(.04,1.05,1.05),C(255,220,190),Enum.PartType.Cylinder,1)
 else
  e.AuraEmitters={emitter(att,{Color=ColorSequence.new(C(255,244,200),C(255,200,72)),Rate=e.Lite and 3 or 6,Lifetime=NumberRange.new(1,1.8),Speed=NumberRange.new(1,2.2),
   SpreadAngle=Vector2.new(25,25),EmissionDirection=Enum.NormalId.Top,Size=NumberSequence.new(.25,0)})}
  e.Halo={}
  for i=1,(e.Lite and 10 or 14)do e.Halo[i]=part(e.Folder,'Gold halo',V(.5,.06,.12),C(255,206,90))end
 end
 local ok,Audio=pcall(require,script.Parent.RarePullAudio)
 if ok and Audio then local s,vol=Audio.AuraVoice(att);if s then e.Hum=s;e.HumVolume=vol;pcall(function()s:Play()end)end end
end
step=function()
 local now=workspace:GetServerTimeNow()
 local camera=workspace.CurrentCamera
 for player,e in pairs(effects)do
  local char=e.Character;local root=char and char.Parent and char:FindFirstChild('HumanoidRootPart')
  local humanoid=char and char:FindFirstChildOfClass('Humanoid')
  local t=now-e.At
  if not player.Parent or not root or(humanoid and humanoid.Health<=0)or t>e.TL.AuraEnd or player.Character~=char then stopEffect(player);continue end
  local far=camera and(camera.CFrame.Position-root.Position).Magnitude>W.FarDistance
  if far and not e.Far then
   e.Far=true
   for _,d in ipairs(e.Folder:GetDescendants())do if d:IsA('BasePart')then d.Transparency=1 end end
   for _,em in ipairs(e.AuraEmitters or{})do em.Enabled=false end
   if e.Hum then e.Hum.Volume=0 end
  elseif not far then e.Far=false end
  if e.Far then continue end
  local mouth=e.Mouth or root.CFrame*CF(0,1,-1)
  local up=mouth.Position;local color=e.Tier.Theme or e.Tier.Hint
  local burst=e.TL.Burst
  -- charge motes
  for i,m in ipairs(e.Motes)do
   if t<burst then
    local q=clamp01(t/burst);local k=(q*1.7+i/#e.Motes)%1;local a=i*2.39996+t*(e.Reduced and 0 or 3+i%3)
    local r=.2+(1-k)*2.6;local h=.1+(1-k)*2.2
    m.CFrame=CF(up+V(math.cos(a)*r,h,math.sin(a)*r));m.Transparency=1-math.sin(k*math.pi)*q*.9
   else m.Transparency=1 end
  end
  -- pillar, ring, light
  local age=t-burst
  if age>=0 and t<e.TL.PillarEnd then
   if not e.Bursted then e.Bursted=true;pcall(function()e.Sparks:Emit(e.Lite and 16 or 40)end)end
   local fade=clamp01(age/(e.TL.PillarEnd-burst))
   local grow=1-(1-clamp01(age/.25))^3;local height=140*grow;local width=math.max(.2,(2.4-2*fade))*(e.Reduced and .8 or 1)
   e.Pillar.Size=V(height,width,width);e.Pillar.CFrame=CF(up+V(0,height/2,0))*ANG(0,0,math.pi/2);e.Pillar.Transparency=.35+.65*fade
   e.Core.Size=V(height,width*.35,width*.35);e.Core.CFrame=e.Pillar.CFrame;e.Core.Transparency=.15+.85*fade
   local k=clamp01(age/1);local radius=1+k*(e.Reduced and 8 or 22)
   for i,seg in ipairs(e.Ring)do
    local a=(i-.5)/#e.Ring*math.pi*2;local len=2*math.pi*radius/#e.Ring*1.05
    seg.Size=V(len,.1,.35*(1-k)+.05);seg.CFrame=CF(root.Position+V(math.cos(a)*radius,-2.6,math.sin(a)*radius))*ANG(0,-a+math.pi/2,0)
    seg.Transparency=k>=1 and 1 or .1+.9*k
   end
   e.Anchor.CFrame=CF(up);e.Light.Brightness=5*math.max(0,1-age/.6)
  elseif e.Pillar.Transparency<1 then
   e.Pillar.Transparency=1;e.Core.Transparency=1;e.Light.Brightness=0
   for _,seg in ipairs(e.Ring)do seg.Transparency=1 end
  end
  -- afterglow aura
  if age>=0 then
   if not e.Attachment then buildAura(e,root)end
   local fadeIn=clamp01(age/.6);local fadeOut=clamp01((e.TL.AuraEnd-t)/2);local a=fadeIn*fadeOut
   for _,em in ipairs(e.AuraEmitters or{})do em.Enabled=a>.2 end
   if e.Hum then e.Hum.Volume=(e.HumVolume or .06)*a end
   local spin=e.Reduced and 0 or t
   for _,p in ipairs(e.Planets)do
    local ang=spin*p.Speed*2+p.Radius;p.Part.CFrame=CF(root.Position+V(math.cos(ang)*p.Radius,2.4+math.sin(ang*1.3)*.3,math.sin(ang)*p.Radius));p.Part.Transparency=1-a
   end
   if e.PlanetRing and e.Planets[1]then e.PlanetRing.CFrame=e.Planets[1].Part.CFrame*ANG(.5,0,math.pi/2);e.PlanetRing.Transparency=1-a*.6 end
   if e.Halo then
    local r=2.1+(e.Reduced and 0 or .12*math.sin(t*2))
    for i,seg in ipairs(e.Halo)do
     local ang=(i-.5)/#e.Halo*math.pi*2+spin*.4;local len=2*math.pi*r/#e.Halo*1.05
     seg.Size=V(len,.06,.14);seg.CFrame=CF(root.Position+V(math.cos(ang)*r,-2.85,math.sin(ang)*r))*ANG(0,-ang+math.pi/2,0);seg.Transparency=1-a*.7
    end
   end
  end
 end
end
-- (for tests / the owner command) every effect ends at once
function W.Clear()for p in pairs(effects)do stopEffect(p)end end
return W
