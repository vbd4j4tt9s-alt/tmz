-- R136 (owner: "for legendary and mythic polish the effects for seed pulling animations, add sound effects"):
-- the world part of a Legendary / Mythic seed pull, seen by everyone nearby.
--  Charge (until the seed bursts out): the bag's mouth glows brighter and motes swirl down into it.
--  Burst: a pillar of light, a shockwave ring (Mythic: two), a burst of sparkles, a flash of light and, for people
--  watching someone else's pull, a soft sparkle sound at the bag (the opener hears RarityRevealAudio instead).
-- Mythic is bigger: more motes, a taller pillar, a second ring and a helix of motes climbing the pillar.
-- R138 (owner: "add sound effects for getting common and uncommon, rare and very little minor animations"): Common,
-- Uncommon and Rare get a small version: no charge-up, pillar or helix; one small ring in the tier colour, a few
-- sparkles (Uncommon / Rare) and a little light (Rare). No world sound (the opener hears RarityRevealAudio).
-- R152 (owner: "polish ... the beam", one look for every tier): the Legendary / Mythic pillar is now a smaller version of the sky beam
-- (RarePullFx: core, glow and twisting streaks, textured, streaming), slamming down onto the bag's mouth on the burst; the charge motes walk
-- the pack's rarity hint (they showed gold / pink from the first frame, before the hint had even begun) and, when the pack's own seam glow
-- is there (PackSuspense, opts.Suspense), the flourish adds no second glow or light at the mouth (the two overlapped and flickered).
local F={};F.__index=F
local V,CF=Vector3.new,CFrame.new
local Fx=require(script.Parent.RarePullFx)
local Hint do local ok,R=pcall(require,script.Parent.RarePullRules);Hint=ok and R.Hint or nil end
F.Styles={
 [1]={Name='Common',Color=Color3.fromRGB(228,236,226),Accent=Color3.fromRGB(255,255,255),Minor=true,Motes=0,Rings=1,Pillar=0,Sparks=0,Helix=0,Flash=0,Radius=1.6},
 [2]={Name='Uncommon',Color=Color3.fromRGB(120,232,130),Accent=Color3.fromRGB(214,255,200),Minor=true,Motes=0,Rings=1,Pillar=0,Sparks=8,Helix=0,Flash=0,Radius=2},
 [3]={Name='Rare',Color=Color3.fromRGB(110,190,255),Accent=Color3.fromRGB(214,240,255),Minor=true,Motes=0,Rings=1,Pillar=0,Sparks=14,Helix=0,Flash=1.2,Radius=2.6},
 [4]={Name='Legendary',Color=Color3.fromRGB(255,207,89),Accent=Color3.fromRGB(255,244,190),Motes=10,Rings=1,Pillar=7,Sparks=28,Helix=0,Flash=3},
 [5]={Name='Mythic',Color=Color3.fromRGB(235,120,255),Accent=Color3.fromRGB(150,210,255),Motes=16,Rings=2,Pillar=9.5,Sparks=46,Helix=12,Flash=4},
}
F.BurstSeconds=1.15;F.MinorSeconds=.6
F.SoundId='rbxassetid://9120769331'
local SEGMENTS,MINOR_SEGMENTS=20,12
local function part(parent,name,size,color,shape)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.Neon;p.Anchored=true
 p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Transparency=1
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
-- rank 1..5 (Secret+ have their own reveal); parent = the reveal's effect model; scale = the bag's visual scale.
function F.Create(parent,rank,scale,opts)
 local style=F.Styles[rank];if not style then return nil end
 opts=opts or{}
 local self=setmetatable({Style=style,Rank=rank,Scale=math.clamp(tonumber(scale)or 1,.3,12),Motes={},Rings={},Helix={},Burst=false,Suspense=opts.Suspense==true},F)
 self.Cache=Fx.Cache.new();self.Set=self.Cache.Set -- (R152 perf: per-frame values are written only when they change; the pillar shares the cache)
 local folder=Instance.new('Folder');folder.Name='RevealFlourish';folder.Parent=parent;self.Folder=folder
 self.Glow=part(folder,'Mouth glow',V(1.5,.06,.5),style.Accent)
 self.Anchor=part(folder,'Flourish anchor',V(.05,.05,.05),style.Color)
 local light=Instance.new('PointLight');light.Name='Flourish light';light.Color=style.Color;light.Brightness=0;light.Range=10;light.Shadows=false;light.Parent=self.Anchor;self.Light=light
 for i=1,style.Motes do self.Motes[i]=part(folder,'Charge mote',V(.12,.12,.12),i%3==0 and style.Accent or style.Color,Enum.PartType.Ball)end
 if not style.Minor then
  -- (the small sky beam: lands on the mouth on the burst, holds .55 s, thins out; Update places it)
  local s=self.Scale
  self.Pillar=Fx.Beam({Parent=folder,Name='Light pillar',Ground=Vector3.zero,Height=style.Pillar*s*1.6,Width=(rank==5 and .95 or .8)*s,Color=style.Color,Glow=style.Accent,
   Land=0,Descent=.12,Hold=.55,Fade=.6,Impact=false,Light=false,Tier=opts.Tier,Cache=self.Cache})
 end
 for r=1,style.Rings do
  local ring={}
  for i=1,style.Minor and MINOR_SEGMENTS or SEGMENTS do ring[i]=part(folder,'Shockwave',V(.1,.08,.5),r==1 and style.Color or style.Accent)end
  self.Rings[r]=ring
 end
 for i=1,style.Helix do self.Helix[i]=part(folder,'Helix mote',V(.14,.14,.14),i%2==0 and style.Accent or style.Color,Enum.PartType.Ball)end
 if style.Sparks<=0 then return self end
 local sparks=Instance.new('ParticleEmitter');sparks.Name='Burst sparkles';sparks.Texture='rbxasset://textures/particles/sparkles_main.dds'
 sparks.Color=ColorSequence.new(style.Accent,style.Color);sparks.LightEmission=1;sparks.LightInfluence=0;sparks.Enabled=false
 sparks.Lifetime=NumberRange.new(.55,1.05);sparks.Speed=NumberRange.new(5*self.Scale,11*self.Scale);sparks.SpreadAngle=Vector2.new(180,180)
 sparks.Acceleration=V(0,-7*self.Scale,0);sparks.Drag=1.5;sparks.Rotation=NumberRange.new(0,360)
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.35*self.Scale),NumberSequenceKeypoint.new(1,0)})
 sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
 sparks.Parent=self.Anchor;self.Sparks=sparks
 return self
end
-- mouth: CFrame of the bag's open mouth; t: seconds since the reveal began; burstAt: when the seed bursts out.
-- heard: true to play the burst sound here (people watching someone else's pull).
function F:Update(mouth,t,burstAt,heard)
 if self.Destroyed then return end
 local style,s=self.Style,self.Scale
 local up=mouth.Position
 local S=self.Set
 S(self.Anchor,'CFrame',CF(up))
 if style.Minor then return self:_minor(mouth,t-burstAt)end
 if self.Pillar then self.Pillar:Update(t-burstAt,up)end
 if t<burstAt then
  -- Charge: glow builds and motes spiral down into the mouth (in the pack's walking rarity hint; with the pack's own seam glow there
  -- the flourish adds no glow / light of its own)
  local q=math.clamp(t/math.max(burstAt,.01),0,1)
  S(self.Glow,'CFrame',mouth);S(self.Glow,'Size',V(1.5*s,.06*s,.5*s));S(self.Glow,'Transparency',self.Suspense and 1 or 1-q*.85)
  S(self.Light,'Brightness',self.Suspense and 0 or q*q*style.Flash*.6);S(self.Light,'Range',(6+q*6)*s)
  local hint=Hint and Hint(self.Rank,q)
  for i,m in ipairs(self.Motes)do
   local k=(q*1.6+i/#self.Motes)%1;local a=i*2.39996+t*(3+i%3)
   local r=(.15+(1-k)*1.9)*s;local h=(.1+(1-k)*1.5)*s
   S(m,'Size',V(.12,.12,.12)*s);S(m,'CFrame',CF(up+V(math.cos(a)*r,h,math.sin(a)*r)));S(m,'Transparency',1-math.sin(k*math.pi)*q*.9)
   if hint then S(m,'Color',hint)end
  end
  return
 end
 local age=t-burstAt
 if not self.Burst then
  self.Burst=true;self.Sparks:Emit(style.Sparks)
  if heard then
   local sound=Instance.new('Sound');sound.Name='Seed burst';sound.SoundId=F.SoundId;sound.Volume=.22;sound.PlaybackSpeed=self.Rank==5 and 1.05 or 1.25
   -- R150: through SoundTiming (the file's .04 s lead-in is skipped, as it is for the opener) so the sound meets the pillar.
   sound.RollOffMinDistance=6;sound.RollOffMaxDistance=45;sound.Parent=self.Anchor;require(script.Parent.SoundTiming).Play(sound,nil,.25);self.Sound=sound
  end
 end
 for _,m in ipairs(self.Motes)do S(m,'Transparency',1)end
 local fade=math.clamp(age/F.BurstSeconds,0,1)
 S(self.Glow,'Transparency',self.Suspense and 1 or math.min(1,.15+fade*1.5))
 S(self.Light,'Brightness',style.Flash*math.max(0,1-age/.5));S(self.Light,'Range',14*s)
 -- Shockwave rings expanding flat around the mouth (the second starts a moment later), easing out (R152: they grew at a constant speed).
 for r,ring in ipairs(self.Rings)do
  local ra=age-(r-1)*.15;local k=math.clamp(ra/.65,0,1);local radius=(.5+(1-(1-k)^3)*(4+r))*s
  for i,seg in ipairs(ring)do
   local a=(i-.5)/#ring*math.pi*2;local len=2*math.pi*radius/#ring*1.05
   S(seg,'Size',V(len,.08*s,.16*s*(1-k*.6)))
   S(seg,'CFrame',CF(up+V(math.cos(a)*radius,.05*s+(r-1)*math.max(.05,.06*s),math.sin(a)*radius))*CFrame.Angles(0,-a+math.pi/2,0)) -- (R152 z-fighting: the second ring catches up with the first: its own layer, >= .05 stud above)
   S(seg,'Transparency',ra<0 and 1 or math.clamp(.1+k*.9,0,1))
  end
 end
 -- Mythic helix: motes climbing the pillar.
 for i,m in ipairs(self.Helix)do
  local k=math.clamp(age/.9-(i-1)/#self.Helix*.35,0,1);local a=i*math.pi*2/#self.Helix*2+age*7
  S(m,'Size',V(.14,.14,.14)*s);S(m,'CFrame',CF(up+V(math.cos(a)*.7*s,k*style.Pillar*.85*s,math.sin(a)*.7*s)));S(m,'Transparency',(k<=0 or k>=1)and 1 or .1+k*.6)
 end
 if age>F.BurstSeconds then self:Hide()end
end
-- R138: the small Common / Uncommon / Rare pop: one quick ring, a few sparkles, a short light for Rare.
function F:_minor(mouth,age)
 local style,s=self.Style,self.Scale;local up=mouth.Position
 local S=self.Set
 S(self.Anchor,'CFrame',CF(up))
 if age<0 then S(self.Light,'Brightness',0);return end
 if not self.Burst then self.Burst=true;if self.Sparks then self.Sparks:Emit(style.Sparks)end end
 local k=math.clamp(age/F.MinorSeconds,0,1);local rise=1-(1-k)^3
 S(self.Glow,'Transparency',1)
 S(self.Light,'Brightness',style.Flash*math.max(0,1-age/.35));S(self.Light,'Range',8*s)
 local radius=(.35+rise*style.Radius)*s
 for _,ring in ipairs(self.Rings)do
  for i,seg in ipairs(ring)do
   local a=(i-.5)/#ring*math.pi*2;local len=2*math.pi*radius/#ring*1.05
   S(seg,'Size',V(len,.06*s,.12*s*(1-k*.6)))
   S(seg,'CFrame',CF(up+V(math.cos(a)*radius,.05*s,math.sin(a)*radius))*CFrame.Angles(0,-a+math.pi/2,0))
   S(seg,'Transparency',math.clamp(.25+k*.75,0,1))
  end
 end
 if age>F.MinorSeconds then self:Hide()end
end
function F:Hide()
 local S=self.Set
 -- (R152 perf: the pieces are found once; Hide runs every frame once the flourish is over, and writes nothing that is already hidden)
 local list=self.HideList
 if not list then list={};for _,d in ipairs(self.Folder:GetDescendants())do if d:IsA('BasePart')or d:IsA('Beam')then list[#list+1]=d end end;self.HideList=list end
 for _,d in ipairs(list)do if d.Parent then if d:IsA('BasePart')then S(d,'Transparency',1)else S(d,'Enabled',false)end end end
 S(self.Light,'Brightness',0)
end
function F:Destroy()
 if self.Destroyed then return end
 self.Destroyed=true;self.Folder:Destroy()
end
return F
