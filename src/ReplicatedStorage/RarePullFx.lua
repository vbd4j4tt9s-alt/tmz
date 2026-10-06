-- R152 (owner: "the beam also shouldn't be like one hollow beam it should be more polished like beams from other games ..., the beam down
-- from the sky, it should have textures and it should actually feel like a well made beam from the sky"; "better VFX throughout").
-- ONE light-beam system for every pull: the sky beam around a Secret / Cosmic / King puller (RarePullWorld), the smaller beam of a
-- Legendary / Mythic pull (RevealFlourish) and the King's carry / crown beams in the throne room (RarePullScenes), scaled by tier.
--  Layers (Beams between attachments, textures that ship with every client, already used by the game):
--   core    a narrow white-hot beam (no texture), fading out toward the sky
--   glow    a wider soft beam (flare texture) in the tier colour, streaming down (half light, half colour: a fully additive beam is a white
--           line in daylight)
--   haze    a wide smoky sleeve (smoke texture) drifting down slowly (not on low quality)
--   streaks 1-3 thin sparkle streaks that twist around the core (their attachments orbit), streaming fast
--  Arrival: it SLAMS DOWN from the sky (its foot drops from the top to the ground in Descent seconds, accelerating) and lands on Land, then
--  holds (the core breathing), then thins out and fades. Landing on the ground: a flash (PointLight), two shockwave rings (smooth: the
--  client-drawn halo image on a flat part, white and tier colour; rings of segments without it / on low quality), dust kicked out,
--  sparks, debris, glowing cracks (Secret+), embers rising inside the beam while it holds. A beam that "fades" in (the King's) has no slam.
--  Everything sits under one anchor part that follows its subject (Update(t, ground)), and is gone with Destroy(). Budgets per
--  ClientFxBudget tier: Fx.Budget. Driven by its owner's clock: Update(t) every frame, no task.delay, nothing runs after Destroy().
--  opts.Strength dims the layers (the King's beams: the crown is the star, not the light).
local Fx={}
local Art do local ok,m=pcall(require,script.Parent.RarePullArt);Art=ok and m or nil end
-- R152 perf: per-frame values are written only when they change (PropCache152; without it, every write as before)
local Cache do local ok,m=pcall(require,script.Parent.PropCache152);Cache=ok and m or{new=function()return{Set=function(o,k,v)o[k]=v end}end}end
Fx.Cache=Cache
local V,CF,ANG=Vector3.new,CFrame.new,CFrame.Angles
local C=Color3.fromRGB
Fx.SPARK='rbxasset://textures/particles/sparkles_main.dds';Fx.SMOKE='rbxasset://textures/particles/smoke_main.dds';Fx.FLARE='rbxasset://textures/particles/flare_main.dds'
-- per ClientFxBudget tier (3 desktop, 2 phone, 1 low quality / FastMode)
Fx.Budget={[3]={Streaks=3,Haze=true,Embers=14,Dust=24,Sparks=26,Debris=10,Cracks=8,Ring=20},
 [2]={Streaks=2,Haze=true,Embers=8,Dust=14,Sparks=16,Debris=6,Cracks=6,Ring=16},
 [1]={Streaks=1,Haze=false,Embers=4,Dust=6,Sparks=8,Debris=0,Cracks=4,Ring=12}}
local function clamp01(x)return math.clamp(x,0,1)end
local function smooth(x)x=clamp01(x);return x*x*(3-2*x)end
local function easeOut(x)x=clamp01(x);return 1-(1-x)^3 end
function Fx.Tier()
 local ok,B=pcall(require,script.Parent.ClientFxBudget)
 if ok and B then local ok2,t=pcall(B.Get);if ok2 and type(t)=='number'then return math.clamp(math.floor(t),1,3)end end
 return 3
end
local function part(parent,name,size,color,mat,shape)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Size=size;p.Color=color;p.Material=mat or Enum.Material.Neon;p.Transparency=1;if shape then p.Shape=shape end;p.Parent=parent;return p
end
local function attachment(parent,name)local a=Instance.new('Attachment');a.Name=name;a.Parent=parent;return a end
local function seq(a,b,c)return NumberSequence.new({NumberSequenceKeypoint.new(0,a),NumberSequenceKeypoint.new(.3,b),NumberSequenceKeypoint.new(1,c)})end
local function beam(parent,name,a0,a1,props)
 local b=Instance.new('Beam');b.Name=name;b.Attachment0=a0;b.Attachment1=a1;b.FaceCamera=true;b.LightInfluence=0;b.Segments=12;b.Enabled=false
 for k,v in pairs(props)do b[k]=v end
 b.Parent=parent;return b
end
local function emitter(parent,name,props)
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Enabled=false;e.LightInfluence=0;for k,v in pairs(props)do e[k]=v end;e.Parent=parent;return e
end
local Beam={};Beam.__index=Beam
-- opts: {Parent, Name, Ground (Vector3), Height, Width, Color, Glow, Land, Descent, Hold, Fade, Tier, Reduced, Impact (ground effects),
--        Cracks, Arrive ('slam' | 'fade'), Light (default true), Dust (Color3), Strength (0..1: how bright its layers are, default 1)}
function Fx.Beam(opts)
 local tier=math.clamp(opts.Tier or Fx.Tier(),1,3);local budget=Fx.Budget[tier]
 local W=opts.Width or 2;local H=opts.Height or 120
 local self=setmetatable({Opts=opts,Tier=tier,Budget=budget,W=W,H=H,Land=opts.Land or 0,Descent=opts.Descent or .16,Hold=opts.Hold or 1.4,Fade=opts.Fade or 1,
  Color=opts.Color or C(255,255,255),Glow=opts.Glow or C(255,255,255),Reduced=opts.Reduced==true,Arrive=opts.Arrive or'slam',Strength=math.clamp(opts.Strength or 1,0,1),ImpactHidden=true,Streaks={},Ring={},Ring2={},Debris={},Cracks={},Cache={}},Beam)
 self.Set=(opts.Cache or Cache.new()).Set -- (opts.Cache: the owner's cache, when the owner also writes these pieces)
 local folder=Instance.new('Folder');folder.Name=opts.Name or'Sky beam';folder.Parent=opts.Parent;self.Folder=folder
 local anchor=part(folder,'Beam anchor',V(.2,.2,.2),self.Color);self.Anchor=anchor
 anchor.CFrame=CF(opts.Ground or Vector3.zero)
 self.Top=attachment(anchor,'Top');self.Foot=attachment(anchor,'Foot')
 local white=C(255,255,255)
 self.Core=beam(folder,'Beam core',self.Top,self.Foot,{Color=ColorSequence.new(self.Glow:Lerp(white,.6),white),LightEmission=1,Width0=W*.22,Width1=W*.34,Texture='',TextureLength=1})
 -- (the glow and the haze half add light, half paint their colour: in daylight a fully additive beam washes out to a white line)
 self.GlowBeam=beam(folder,'Beam glow',self.Top,self.Foot,{Color=ColorSequence.new(self.Color,self.Color:Lerp(self.Glow,.5)),LightEmission=.6,Width0=W*1.0,Width1=W*1.35,
  Texture=Fx.FLARE,TextureMode=Enum.TextureMode.Wrap,TextureLength=math.max(4,H/7),TextureSpeed=self.Reduced and .4 or 1.6})
 if budget.Haze then
  self.Haze=beam(folder,'Beam haze',self.Top,self.Foot,{Color=ColorSequence.new(self.Color:Lerp(white,.15),self.Color),LightEmission=.15,Width0=W*2.6,Width1=W*2.2,
   Texture=Fx.SMOKE,TextureMode=Enum.TextureMode.Wrap,TextureLength=math.max(6,H/4),TextureSpeed=self.Reduced and .1 or .35})
 end
 self.Layers={self.Core,self.GlowBeam,self.Haze}
 for i=1,budget.Streaks do
  local a0,a1=attachment(anchor,'Streak top '..i),attachment(anchor,'Streak foot '..i)
  local b=beam(folder,'Beam streak '..i,a0,a1,{Color=ColorSequence.new(white,self.Glow),LightEmission=1,Width0=W*.12,Width1=W*.28,
   Texture=Fx.SPARK,TextureMode=Enum.TextureMode.Wrap,TextureLength=math.max(3,H/12),TextureSpeed=self.Reduced and 1 or 3.2+.6*i,CurveSize0=W*.9,CurveSize1=-W*.9})
  self.Streaks[i]={Beam=b,Top=a0,Foot=a1,Phase=(i-1)/budget.Streaks*math.pi*2}
 end
 local ground=attachment(anchor,'Ground')
 self.Embers=emitter(ground,'Beam embers',{Texture=Fx.SPARK,LightEmission=1,Color=ColorSequence.new(white,self.Glow),Rate=budget.Embers,
  Lifetime=NumberRange.new(1,1.9),Speed=NumberRange.new(W*3,W*6),SpreadAngle=Vector2.new(9,9),EmissionDirection=Enum.NormalId.Top,
  Acceleration=V(0,W*1.2,0),Drag=.4,Size=NumberSequence.new({NumberSequenceKeypoint.new(0,W*.16),NumberSequenceKeypoint.new(1,0)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.7,.35),NumberSequenceKeypoint.new(1,1)})})
 if opts.Light~=false then local l=Instance.new('PointLight');l.Name='Beam light';l.Color=self.Glow;l.Brightness=0;l.Range=math.min(60,W*9);l.Shadows=false;l.Parent=anchor;self.Light=l end
 if opts.Impact~=false then
  local dust=opts.Dust or self.Color:Lerp(C(150,138,122),.55)
  self.Dust=emitter(ground,'Impact dust',{Texture=Fx.SMOKE,LightEmission=.05,LightInfluence=.6,Color=ColorSequence.new(dust),Lifetime=NumberRange.new(1,1.7),
   Speed=NumberRange.new(W*3.5,W*6.5),SpreadAngle=Vector2.new(78,78),EmissionDirection=Enum.NormalId.Top,Drag=3,Acceleration=V(0,W*.6,0),
   Size=NumberSequence.new({NumberSequenceKeypoint.new(0,W*.6),NumberSequenceKeypoint.new(1,W*2)}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),NumberSequenceKeypoint.new(1,1)}),
   Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-40,40)})
  self.Sparks=emitter(ground,'Impact sparks',{Texture=Fx.SPARK,LightEmission=1,Color=ColorSequence.new(white,self.Glow),Lifetime=NumberRange.new(.45,.9),
   Speed=NumberRange.new(W*5,W*10),SpreadAngle=Vector2.new(70,70),EmissionDirection=Enum.NormalId.Top,Drag=2,Acceleration=V(0,-W*4,0),
   Size=NumberSequence.new({NumberSequenceKeypoint.new(0,W*.2),NumberSequenceKeypoint.new(1,0)})})
  -- the shockwaves: two smooth rings on the ground (the client-drawn halo image on a flat part, unlit: one white, one in the tier colour);
  -- without the image (not drawn yet, low quality), rings of short segments
  local halo=tier>=2 and Art and Art.Allowed()and(function()local st,ct=Art.Get('halo');return st=='ready'and ct or nil end)()
  if halo then
   self.RingArt={}
   for i,c in ipairs({white,self.Color})do
    local p=part(folder,i==1 and'Shockwave'or'Shockwave glow',V(1,.05,1),c)
    local g=Instance.new('SurfaceGui');g.Name='Shockwave image';g.Face=Enum.NormalId.Top;g.LightInfluence=0;g.AlwaysOnTop=false;g.CanvasSize=Vector2.new(256,256)
    local img=Instance.new('ImageLabel');img.BackgroundTransparency=1;img.Size=UDim2.fromScale(1,1);img.ImageColor3=c;img.ImageTransparency=1
    if pcall(function()img.ImageContent=halo end)then img.Parent=g;g.Parent=p;self.RingArt[i]={Part=p,Image=img}else g:Destroy();p:Destroy();self.RingArt=nil;break end
   end
  end
  if not self.RingArt then
   for i=1,budget.Ring do self.Ring[i]=part(folder,'Shockwave',V(.4,.08,.3),white)end
   for i=1,math.max(8,math.floor(budget.Ring*.75))do self.Ring2[i]=part(folder,'Shockwave glow',V(.4,.05,.6),self.Color)end
  end
  for i=1,budget.Debris do
   local d=part(folder,'Debris',V(.22,.16,.2)*math.max(.6,W*.35),C(92,86,80),Enum.Material.Slate)
   local a=i*2.399+.4;self.Debris[i]={Part=d,Dir=V(math.cos(a),0,math.sin(a)),Speed=W*(2.6+1.6*((i*7)%5)/5),Up=W*(3+2*((i*3)%4)/4),Spin=V(3+i%3,2+i%4,1+i%5)}
  end
  if opts.Cracks then for i=1,budget.Cracks do local a=(i-.5)/budget.Cracks*math.pi*2+((i*5)%3)*.21;self.Cracks[i]={Part=part(folder,'Ground crack',V(.1,.06,1),self.Color:Lerp(self.Glow,.4)),A=a,L=W*(1.6+((i*11)%7)/7*1.8)}end end
 end
 return self
end
-- the transparency of a layer, cached per 1/32 step (a NumberSequence is not built every frame)
function Beam:_alpha(b,base,top,alpha)
 local q=math.floor(alpha*32+.5)/32
 local key=b.Name..q;local s=self.Cache[key]
 if not s then s=seq(1,1-(1-top)*q,1-(1-base)*q);self.Cache[key]=s end
 self.Set(b,'Transparency',s)
end
local function placeRing(S,segs,centre,radius,width,trans)
 local n=#segs
 for i,seg in ipairs(segs)do
  local a=(i-.5)/n*math.pi*2;local len=2*math.pi*radius/n*1.06
  S(seg,'Size',V(math.max(.05,len),seg.Size.Y,width));S(seg,'CFrame',CF(centre+V(math.cos(a)*radius,0,math.sin(a)*radius))*ANG(0,-a+math.pi/2,0));S(seg,'Transparency',trans)
 end
end
-- t: the owner's clock; ground (optional): where its foot is now (it follows its subject)
function Beam:Update(t,ground)
 if self.Destroyed then return end
 local S=self.Set
 if ground then S(self.Anchor,'CFrame',CF(ground))end
 local g=self.Anchor.CFrame.Position
 local a=t-self.Land;local W,H=self.W,self.H
 local endAt=self.Hold+self.Fade
 local on,footY,width,alpha=false,0,0,0
 if self.Arrive=='fade'then
  if a>=-.4 and a<endAt then on=true;alpha=a<0 and smooth((a+.4)/.4)or 1;width=1 end
 elseif a>=-self.Descent and a<endAt then
  on=true
  if a<0 then local k=(a+self.Descent)/self.Descent;footY=H*(1-k*k);width=.55+.45*k;alpha=.6+.4*k -- accelerating down: k^2
  else width=1+.35*math.exp(-a*7);alpha=1 end
 end
 if on and a>=self.Hold then local k=smooth((a-self.Hold)/self.Fade);width*=1-.85*k;alpha*=1-k end
 if on and not self.Reduced and a>=0 then width*=1+.05*math.sin(t*9)end
 local shade=alpha*self.Strength -- (a softer beam: the King's, which must not outshine the crown)
 local lit=on and alpha>.01
 for _,b in ipairs(self.Layers)do S(b,'Enabled',lit)end
 S(self.Top,'Position',V(0,H,0));S(self.Foot,'Position',V(0,footY,0))
 if on then
  S(self.Core,'Width0',W*.22*width);S(self.Core,'Width1',W*.34*width);self:_alpha(self.Core,.02,.25,shade)
  S(self.GlowBeam,'Width0',W*1.0*width);S(self.GlowBeam,'Width1',W*1.35*width);self:_alpha(self.GlowBeam,.2,.5,shade)
  if self.Haze then S(self.Haze,'Width0',W*2.6*width);S(self.Haze,'Width1',W*2.2*width);self:_alpha(self.Haze,.5,.78,shade)end
 end
 local spin=self.Reduced and 0 or t*1.1
 for i,s in ipairs(self.Streaks)do
  S(s.Beam,'Enabled',lit)
  if on then
   local th=s.Phase+spin;local r=W*.45*width
   S(s.Top,'Position',V(math.cos(th+1.6)*r*.5,H,math.sin(th+1.6)*r*.5));S(s.Foot,'Position',V(math.cos(th)*r,footY,math.sin(th)*r))
   S(s.Beam,'Width0',W*.12*width);S(s.Beam,'Width1',W*.28*width);self:_alpha(s.Beam,.15,.5,shade)
  end
 end
 local holding=on and a>=0 and a<self.Hold
 S(self.Embers,'Enabled',holding and alpha>.3)
 if self.Light then S(self.Light,'Brightness',on and(self.Arrive=='fade'and 1.4*alpha or a<0 and 0 or 5*math.exp(-a*4)+.9*alpha)or 0)end
 -- the landing
 if self.Arrive=='slam'and a>=0 and not self.Landed then
  self.Landed=true
  if a<.3 then -- (first seen well after its landing - the camera came near later - it kicks up nothing)
   if self.Dust then pcall(function()self.Dust:Emit(self.Budget.Dust)end)end
   if self.Sparks then pcall(function()self.Sparks:Emit(self.Budget.Sparks)end)end
  end
 end
 -- the ground pieces move only while the impact plays (and are hidden once after it: no per-frame work for them otherwise)
 local impact=self.Arrive=='slam'and a>=0 and a<2.2
 if impact or not self.ImpactHidden then self.ImpactHidden=not impact;self:_impact(a,g)end
 self.On=on;self.Alpha=on and alpha or 0
end
function Beam:_impact(a,g)
 local S=self.Set
 local W=self.W;local k1=clamp01(a/.6);local k2=clamp01((a-.08)/1.1)
 if self.RingArt then
  -- (the halo image's ring sits at .72 of its half size: the part is sized so the bright ring is at the radius)
  local show=self.Arrive=='slam'and a>=0
  for i,r in ipairs(self.RingArt)do
   local radius=i==1 and W*(.5+(self.Reduced and 3 or 7)*easeOut(k1))or W*(.4+(self.Reduced and 2.2 or 4.6)*easeOut(k2))
   local d=2*radius/.72;S(r.Part,'Size',V(d,.05,d));S(r.Part,'CFrame',CF(g+V(0,.025+.05*i,0))) -- (R152 z-fighting: tops at .10 / .15 over the ground, the cracks' tops at .05: every layer .05 apart, the R149 depth rule wants .043)
   S(r.Image,'ImageTransparency',i==1 and(show and k1<1 and .05+.95*k1 or 1)or(show and a>=.08 and k2<1 and .35+.65*k2 or 1))
  end
 elseif #self.Ring>0 then
  local show=self.Arrive=='slam'and a>=0
  placeRing(S,self.Ring,g+V(0,.06,0),W*(.5+(self.Reduced and 3 or 7)*easeOut(k1)),W*(.22*(1-k1)+.04),show and k1<1 and .05+.95*k1 or 1)
  placeRing(S,self.Ring2,g+V(0,.125,0),W*(.4+(self.Reduced and 2.2 or 4.6)*easeOut(k2)),W*(.6*(1-k2)+.1),show and a>=.08 and k2<1 and .55+.45*k2 or 1)
 end
 for _,d in ipairs(self.Debris)do
  local s=a;local show=self.Arrive=='slam'and s>=0 and s<1
  if show then
   local p=g+d.Dir*d.Speed*s+V(0,math.max(0,d.Up*s-9*s*s),0)
   S(d.Part,'CFrame',CF(p)*ANG(d.Spin.X*s,d.Spin.Y*s,d.Spin.Z*s));S(d.Part,'Transparency',clamp01((s-.6)/.4))
  else S(d.Part,'Transparency',1)end
 end
 for _,c in ipairs(self.Cracks)do
  local show=self.Arrive=='slam'and a>=0 and a<2.2
  if show then
   local len=c.L*easeOut(a/.14)
   S(c.Part,'Size',V(math.max(.04,self.W*.07),.04,math.max(.05,len)))
   S(c.Part,'CFrame',CF(g+V(math.cos(c.A)*len*.5,.03,math.sin(c.A)*len*.5))*ANG(0,-c.A+math.pi/2,0))
   S(c.Part,'Transparency',.3+.7*clamp01((a-.5)/1.5))
  else S(c.Part,'Transparency',1)end
 end
end
function Beam:Visible()return self.On==true and self.Alpha>.01 end
-- whether a shockwave ring shows now (either kind)
function Beam:RingShown()
 for _,r in ipairs(self.RingArt or{})do if r.Image.ImageTransparency<1 then return true end end
 for _,s in ipairs(self.Ring)do if s.Transparency<1 then return true end end
 return false
end
function Beam:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true;self.Folder:Destroy()
end
Fx.BeamClass=Beam
-- A burst of light where something bursts open (the story scenes' hit, the ladder's pop): a flash, sparks and a puff of smoke, layered.
-- opts: {Parent, Color, Glow, Size, Tier, Host (a part already following the subject: the burst sits on it, no part of its own)}; :Fire(cframe) once, :Destroy()
local Burst={};Burst.__index=Burst
function Fx.Burst(opts)
 local tier=math.clamp(opts.Tier or Fx.Tier(),1,3);local budget=Fx.Budget[tier];local s=opts.Size or 1
 local self=setmetatable({Size=s,Budget=budget},Burst)
 local folder=Instance.new('Folder');folder.Name=opts.Name or'Burst';folder.Parent=opts.Parent;self.Folder=folder
 local anchor=opts.Host or part(folder,'Burst anchor',V(.1,.1,.1),opts.Color or C(255,255,255));self.Anchor=anchor;self.Hosted=opts.Host~=nil
 local white=C(255,255,255);local glow=opts.Glow or white
 local at=attachment(anchor,'Burst');self.Attachment=at
 self.Core=emitter(at,'Burst core',{Texture=Fx.FLARE,LightEmission=1,Color=ColorSequence.new(white,glow),Lifetime=NumberRange.new(.25,.35),Speed=NumberRange.new(0,0),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s*2.5),NumberSequenceKeypoint.new(1,s*6)}),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})})
 self.Sparks=emitter(at,'Burst sparks',{Texture=Fx.SPARK,LightEmission=1,Color=ColorSequence.new(white,glow),Lifetime=NumberRange.new(.5,1.1),Speed=NumberRange.new(s*7,s*15),
  SpreadAngle=Vector2.new(180,180),Drag=2.2,Acceleration=V(0,-s*3,0),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s*.28),NumberSequenceKeypoint.new(1,0)})})
 self.Smoke=emitter(at,'Burst smoke',{Texture=Fx.SMOKE,LightEmission=.25,Color=ColorSequence.new(opts.Color or glow),Lifetime=NumberRange.new(.9,1.5),Speed=NumberRange.new(s*1.5,s*4),
  SpreadAngle=Vector2.new(180,180),Drag=2.5,Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s*1.2),NumberSequenceKeypoint.new(1,s*3.4)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,1)}),Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-60,60)})
 return self
end
function Burst:Fire(cf)
 if self.Destroyed or self.Fired then return end
 self.Fired=true;if not self.Hosted then self.Anchor.CFrame=cf end
 pcall(function()self.Core:Emit(2)end);pcall(function()self.Sparks:Emit(self.Budget.Sparks)end);pcall(function()self.Smoke:Emit(math.max(4,math.floor(self.Budget.Dust*.5)))end)
end
function Burst:Place(cf)if not self.Destroyed and not self.Hosted then self.Anchor.CFrame=cf end end
function Burst:Destroy()if self.Destroyed then return end;self.Destroyed=true;self.Attachment:Destroy();self.Folder:Destroy()end
return Fx
