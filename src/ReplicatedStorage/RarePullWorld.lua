-- R151: what EVERYONE near a Secret / Cosmic / King pull sees in the world (the puller included, when the camera is back): client-side on
-- each viewer, through the onlooker path (SeedPackClient sees the reveal on the bag and calls Begin). Nobody but the puller sees the story
-- scene itself.
--  Charge (until the seed bursts out, RarityRevealSequence.SeedAt): motes spiral down into the pack's mouth in the tier colour.
--  Burst: a light pillar from the pack into the sky (bragging rights: seen from far away), a shockwave ring on the ground, sparkles, a flash.
--  Afterglow (15 / 20 / 25 s): a tier aura stays around the puller - Secret: shadowy purple wisps; Cosmic: two little orbiting planets and
--  star motes; King: a gold halo ring at the feet and rising gold sparkles - with a quiet hum (RarePullSounds.AuraHum, 3D).
-- One RenderStepped connection while any effect lives, none after (no per-frame work after the afterglow). Far away (160+ studs) nothing is
-- moved; phones / low quality use fewer pieces; ReducedMotion keeps the pillar and aura but nothing swings.
-- R152 (owner: "the beam ... should be more polished ..., the beam down from the sky, it should have textures"): the pillar is now the
-- layered sky beam of RarePullFx (a core, a glow, a smoky sleeve and twisting streaks, textured and streaming) that SLAMS DOWN on the burst
-- and lands with a flash, shockwave rings, dust, sparks, debris and glowing cracks, embers rising while it holds; a soft whoosh swells as it
-- lands (RarePullSounds.Flight, 3D). The charge motes walk the same rarity hint as the pack (they showed the tier colour from the start).
local Players=game:GetService('Players');local Run=game:GetService('RunService')
local Rules=require(script.Parent.RarePullRules)
local Fx=require(script.Parent.RarePullFx)
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
 if e.Beam then pcall(function()e.Beam:Destroy()end)end
 if e.Whoosh then pcall(function()e.Whoosh:Stop()end)end
 if e.Hum then pcall(function()e.Hum:Stop()end)end
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
 local e={Player=player,Character=character,Rank=rank,At=at,Tier=tier,TL=Rules.WorldTimeline(rank),Lite=isLite,Reduced=opts.Reduced or reduced(),Motes={},Planets={}}
 local f=Instance.new('Folder');f.Name='RarePull '..tier.Key;f.Parent=folder;e.Folder=f
 local color=tier.Theme or tier.Hint
 for i=1,(isLite and 6 or 10)do e.Motes[i]=part(f,'Charge mote',V(.16,.16,.16),Rules.Neutral,Enum.PartType.Ball)end
 -- the sky beam: lands on the burst, holds, thins out by PillarEnd (budget: ClientFxBudget tier; low quality = tier 1)
 local fxTier=isLite and math.min(2,Fx.Tier())or Fx.Tier()
 e.Beam=Fx.Beam({Parent=f,Name='Light beam',Ground=W.Ground(character),Height=140,Width=rank==8 and 2.9 or rank==7 and 2.7 or 2.5,Color=color,Glow=tier.Glow,
  Land=e.TL.Burst,Descent=.16,Hold=1.5,Fade=e.TL.PillarEnd-e.TL.Burst-1.5,Tier=fxTier,Reduced=e.Reduced,Cracks=true})
 effects[player]=e
 if not connection then connection=Run.RenderStepped:Connect(function()step()end)end
 return e
end
function W.SetMouth(player,cf)local e=effects[player];if e then e.Mouth=cf end end
-- where the beam lands: the ground under the puller (their feet)
function W.Ground(character)
 local root=character and character:FindFirstChild('HumanoidRootPart');if not root then return Vector3.zero end
 local hum=character:FindFirstChildOfClass('Humanoid');local hip=hum and tonumber(hum.HipHeight)or 2
 return root.Position-Vector3.new(0,(root.Size and root.Size.Y or 2)*.5+math.max(0,hip),0)
end
-- the beam's whoosh (onlookers; the puller is in the story scene then): its swell lands with the beam
W.WhooshPitch=1.15
local function whoosh(e,t)
 if e.WhooshDone then return end
 local ok,def=pcall(function()return require(script.Parent.RarePullSounds).Get('Flight')end)
 if not ok or not def or not def.Id or not def.Swell then e.WhooshDone=true;return end
 local bound=def.Region and def.Region[1]or def.Start or 0;local p=W.WhooshPitch
 local start=e.TL.Burst-.02-(def.Swell-bound)/p
 if t<start then return end
 e.WhooshDone=true
 if t-start>.2 or not e.Beam then return end
 local s=Instance.new('Sound');s.Name='Beam whoosh';s.SoundId=def.Id;s.PlaybackSpeed=p;s.Volume=def.Volume*.9;s.RollOffMinDistance=12;s.RollOffMaxDistance=140
 if def.Region then pcall(function()s.PlaybackRegionsEnabled=true;s.PlaybackRegion=NumberRange.new(def.Region[1],def.Region[2])end)end
 pcall(function()require(script.Parent.AudioMixer).Route(s,'Effects')end)
 s.Parent=e.Beam.Anchor;s.TimePosition=bound+(t-start)*p;s:Play();e.Whoosh=s;e.WhooshVolume=s.Volume
end
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
  for i,s in ipairs({{.5,C(255,160,120),2.3,'planet_gas'},{.36,C(130,190,255),2.9,'planet_rock'}})do
   local b=part(e.Folder,'Aura planet',V(s[1],s[1],s[1]),s[2],Enum.PartType.Ball,1);b.Material=Enum.Material.SmoothPlastic
   -- (R152: the same textured planets as the story scene, when they are drawn)
   local img
   local ok,Art=pcall(require,script.Parent.RarePullArt)
   if ok and Art then
    local state,content=Art.Get(s[4])
    if state=='ready'then
     local g=Instance.new('BillboardGui');g.Name='Art '..s[4];g.Size=UDim2.fromScale(s[1]/.74,s[1]/.74);g.LightInfluence=0;g.AlwaysOnTop=false
     local im=Instance.new('ImageLabel');im.BackgroundTransparency=1;im.Size=UDim2.fromScale(1,1);im.ImageTransparency=1
     if pcall(function()im.ImageContent=content end)then im.Parent=g;g.Parent=b;img=im else g:Destroy()end
    end
   end
   e.Planets[i]={Part=b,Radius=s[3],Speed=1.1-.25*i,Image=img}
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
-- one effect's frame (R152: each in its own protected call: one that fails skips that frame, three in a row and it is stopped; an error
-- used to end the frame for every other puller's effect too)
local function update(player,e,now,camera)
  local char=e.Character;local root=char and char.Parent and char:FindFirstChild('HumanoidRootPart')
  local humanoid=char and char:FindFirstChildOfClass('Humanoid')
  local t=now-e.At
  if not player.Parent or not root or(humanoid and humanoid.Health<=0)or t>e.TL.AuraEnd or player.Character~=char then stopEffect(player);return end
  local far=camera and(camera.CFrame.Position-root.Position).Magnitude>W.FarDistance
  if far and not e.Far then
   e.Far=true
   for _,d in ipairs(e.Folder:GetDescendants())do if d:IsA('BasePart')then d.Transparency=1 elseif d:IsA('Beam')or d:IsA('ParticleEmitter')then d.Enabled=false end end
   for _,em in ipairs(e.AuraEmitters or{})do em.Enabled=false end
   if e.Hum then e.Hum.Volume=0 end
  elseif not far then e.Far=false end
  if e.Far then return end
  local mouth=e.Mouth or root.CFrame*CF(0,1,-1)
  local up=mouth.Position
  local burst=e.TL.Burst
  -- charge motes, in the walking rarity hint (the pack's: RarePullRules.Hint)
  for i,m in ipairs(e.Motes)do
   if t<burst then
    local q=clamp01(t/burst);local k=(q*1.7+i/#e.Motes)%1;local a=i*2.39996+t*(e.Reduced and 0 or 3+i%3)
    local r=.2+(1-k)*2.6;local h=.1+(1-k)*2.2
    m.CFrame=CF(up+V(math.cos(a)*r,h,math.sin(a)*r));m.Transparency=1-math.sin(k*math.pi)*q*.9;m.Color=Rules.Hint(e.Rank,q)
   else m.Transparency=1 end
  end
  -- the sky beam (it follows the puller; gone once it has faded), and its whoosh
  local age=t-burst
  if e.Beam then
   if t>e.TL.PillarEnd+.1 then e.Beam:Destroy();e.Beam=nil else e.Beam:Update(t,W.Ground(char))end
  end
  whoosh(e,t)
  if e.Whoosh then e.Whoosh.Volume=e.WhooshVolume*clamp01(1-(age-.35)/.5);if age>.9 then e.Whoosh:Stop();e.Whoosh=nil end end -- (faded on the clock)
  -- afterglow aura
  if age>=0 then
   if not e.Attachment then buildAura(e,root)end
   local fadeIn=clamp01(age/.6);local fadeOut=clamp01((e.TL.AuraEnd-t)/2);local a=fadeIn*fadeOut
   for _,em in ipairs(e.AuraEmitters or{})do em.Enabled=a>.2 end
   if e.Hum then e.Hum.Volume=(e.HumVolume or .06)*a end
   local spin=e.Reduced and 0 or t
   for _,p in ipairs(e.Planets)do
    local ang=spin*p.Speed*2+p.Radius;p.Part.CFrame=CF(root.Position+V(math.cos(ang)*p.Radius,2.4+math.sin(ang*1.3)*.3,math.sin(ang)*p.Radius))
    if p.Image then p.Image.ImageTransparency=1-a else p.Part.Transparency=1-a end
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
step=function()
 local now=workspace:GetServerTimeNow()
 local camera=workspace.CurrentCamera
 for player,e in pairs(effects)do
  local ok,err=pcall(update,player,e,now,camera)
  if ok then e.Errors=nil
  else
   e.Errors=(e.Errors or 0)+1;if e.Errors==1 then warn('[RarePullWorld] '..tostring(err))end
   if e.Errors>=3 then stopEffect(player)end
  end
 end
end
-- (for tests / the owner command) every effect ends at once
function W.Clear()for p in pairs(effects)do stopEffect(p)end end
return W
