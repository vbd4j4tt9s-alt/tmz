-- R111: per-biome boot ground effects and their client budget. Cosmetic only; read by RunnerTrailEffects.
-- Print = footprint parts and how they age, Burst = particles kicked up on each print, Idle = aura while standing.
-- Ribbon = the R47 ground ribbon colours; slightly more transparent than R47 (.2) so the fresh prints show through.
-- Textures are Roblox built-ins (rbxasset://textures/particles/...), so nothing has to be uploaded.
local S={}
local C,V=Color3.fromRGB,Vector3.new
local M=Enum.Material
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
S.StillSpeed=.8 -- studs/s; slower than this counts as standing
S.StillDelay=.6 -- seconds standing before the idle aura fades in
S.FadeIn=.8;S.FadeOut=.25
-- Emitter fields: Size/Alpha {start,end} or {start,middle,end}; Life/Speed/Spin {min,max}; Glow=LightEmission;
-- Light=LightInfluence; Shape/Style=ParticleEmitterShape/ShapeStyle on the idle part (disc at the wearer's soles).
S.Themes={
 Desert={Ribbon={C(226,190,128),C(176,132,80)},RibbonAlpha=.5,RibbonGlow=0,
  Print={Kind='Sand',Life=2.6,Hold=.35,Alpha=.12,Color=C(168,126,80),Accent=C(138,100,62),Material=M.Sand},
  Burst={
   {Name='Dust puff',Texture=SMOKE,Color=C(222,192,142),Count=2,Size={.7,2.1},Life={.5,.9},Speed={1.5,3.5},Spread=70,Accel=V(0,-1,0),Drag=3,Alpha={.5,1},Glow=0,Light=1},
   {Name='Kicked sand',Texture=SPARK,Color=C(205,166,108),Count=3,Size={.15,.1},Life={.3,.6},Speed={3,6},Spread=50,Accel=V(0,-20,0),Alpha={.1,1},Glow=0,Light=.8},
  },
  Idle={Spin=2.4,Emitters={
   {Name='Swirling sand',Texture=SMOKE,Color=C(226,196,142),Rate=6,Size={.5,1.4},Life={1.2,1.8},Speed={.2,.5},Alpha={.6,1},Glow=0,Light=1,Locked=true,Shape='Disc',Style='Surface'},
   {Name='Sand grains',Texture=SPARK,Color=C(214,176,112),Rate=10,Size={.12,.08},Life={1,1.6},Speed={.3,.8},Accel=V(0,.3,0),Alpha={.2,1},Glow=0,Light=.8,Locked=true,Shape='Disc'},
  }}},
 Snow={Ribbon={C(214,240,255),C(140,196,240)},RibbonAlpha=.42,RibbonGlow=.35,
  -- Prints start as clear ice, then crystallise into white frost with a small star before fading.
  Print={Kind='Frost',Life=3,Hold=.55,Alpha=.25,Turn=.3,Color=C(150,204,242),Material=M.Ice,Reflectance=.25,Color2=C(236,246,255),Material2=M.Snow,Accent=C(200,236,255)},
  Burst={
   {Name='Snow puff',Texture=SMOKE,Color=C(235,245,255),Count=2,Size={.6,1.7},Life={.5,.8},Speed={1.5,3},Spread=70,Drag=3,Alpha={.45,1},Glow=.1,Light=1},
   {Name='Snow flecks',Texture=SPARK,Color=C(245,250,255),Count=4,Size={.16,.1},Life={.4,.8},Speed={3,6},Spread=55,Accel=V(0,-12,0),Alpha={0,1},Glow=.4,Light=.6},
  },
  Idle={Emitters={
   {Name='Frost mist',Texture=SMOKE,Color=C(210,232,250),Rate=3,Size={1.2,2.6},Life={2,3},Speed={.1,.3},Accel=V(0,-.1,0),Alpha={.72,1},Glow=.1,Light=1,Shape='Disc'},
   {Name='Snowflakes',Texture=SPARK,Color=C(250,252,255),Rate=6,Size={.18,.12},Life={1.6,2.4},Speed={1,1.6},Accel=V(0,-1.4,0),Alpha={.1,1},Glow=.5,Light=.5,Spin={-60,60},Shape='Disc'},
  }}},
 Lava={Ribbon={C(255,140,53),C(195,62,35)},RibbonAlpha=.35,RibbonGlow=.65,
  -- Prints glow like fresh magma, cool through red to dark basalt, then fade.
  Print={Kind='Ember',Life=2.4,Hold=.55,Alpha=.05,Turn=.45,Turn2=.7,Color=C(255,200,90),Color2=C(226,68,24),Accent=C(255,236,160),Cool=C(58,42,36),Material2=M.Basalt},
  Burst={
   {Name='Magma sparks',Texture=SPARK,Color=C(255,160,60),Tail=C(255,70,20),Count=5,Size={.18,0},Life={.3,.6},Speed={6,12},Spread=45,Accel=V(0,-26,0),Alpha={0,.4},Glow=1,Light=0},
   {Name='Ash puff',Texture=SMOKE,Color=C(70,56,52),Count=1,Size={.6,1.6},Life={.6,1},Speed={1,2},Spread=40,Accel=V(0,2,0),Alpha={.6,1},Glow=0,Light=1},
  },
  Idle={Emitters={
   {Name='Rising embers',Texture=SPARK,Color=C(255,150,50),Tail=C(255,70,20),Rate=8,Size={.16,0},Life={.9,1.6},Speed={1.2,2.6},Spread=25,Accel=V(.2,1.2,0),Alpha={0,.3},Glow=1,Light=0,Shape='Disc'},
   {Name='Heat haze',Texture=SMOKE,Color=C(120,70,50),Rate=2,Size={.8,2.2},Life={1,1.6},Speed={1.4,2.4},Spread=15,Alpha={.82,1},Glow=.2,Light=1,Shape='Disc'},
  }}},
 Crystal={Ribbon={C(193,152,250),C(115,178,237)},RibbonAlpha=.35,RibbonGlow=.65,
  -- Three small reflective shards poke out of each print; the centre one twinkles.
  Print={Kind='Crystal',Life=2.6,Hold=.5,Alpha=.15,Color=C(222,204,255),Material=M.Glass,Reflectance=.5,Accent=C(178,112,255)},
  Burst={
   {Name='Crystal sparkles',Texture=SPARK,Color=C(232,212,255),Tail=C(170,110,255),Count=4,Size={0,.34,0},Life={.4,.8},Speed={1.5,3.5},Spread=60,Accel=V(0,-3,0),Alpha={0,.2},Glow=1,Light=0},
  },
  Idle={Spin=.9,Shards=3,ShardColor=C(228,212,255),ShardGlow=C(170,96,255),Emitters={
   {Name='Crystal twinkles',Texture=SPARK,Color=C(236,220,255),Tail=C(180,120,255),Rate=7,Size={0,.4,0},Life={.5,.9},Speed={.4,1},Spread=40,Drag=1,Alpha={0,.2},Glow=1,Light=0,Shape='Disc'},
  }}},
 Storm={Ribbon={C(177,232,255),C(94,146,248)},RibbonAlpha=.35,RibbonGlow=.65,
  -- Zigzag prints flicker like a live wire, shift from white-cyan to blue and fade.
  Print={Kind='Lightning',Life=1.6,Hold=.4,Alpha=.08,Turn=.3,Color=C(200,244,255),Color2=C(70,140,255)},
  Arc=.3,ArcColor=C(190,240,255),
  Burst={
   {Name='Static sparks',Texture=SPARK,Color=C(170,235,255),Tail=C(80,150,255),Count=5,Size={.16,0},Life={.12,.3},Speed={8,15},Spread=80,Drag=6,Alpha={0,.2},Glow=1,Light=0},
  },
  Idle={ArcEvery={.35,.9},Emitters={
   {Name='Crackling sparks',Texture=SPARK,Color=C(160,230,255),Tail=C(90,160,255),Rate=9,Size={.18,0},Life={.1,.25},Speed={3,6},Spread=60,Drag=4,Alpha={0,.2},Glow=1,Light=0,Shape='Disc'},
  }}},
}
function S.Theme(name)return S.Themes[name]end
-- Boots on both feet pick the look; the older treadmill-gated BootGroundTheme still works as a fallback.
function S.ThemeName(folder)
 if not folder then return nil end
 local biome=folder:GetAttribute('BootBiome')
 if folder:GetAttribute('BootCount')==2 and S.Themes[biome]then return biome end
 local legacy=folder:GetAttribute('BootGroundTheme')
 return S.Themes[legacy]and legacy or nil
end
-- tier: ClientFxBudget.Get() (1 low .. 3 high); quality: UserGameSettings.SavedQualityLevel.Value (0 = automatic).
function S.Budget(tier,reduced,quality)
 tier=math.clamp(math.floor(tonumber(tier)or 3),1,3)
 if type(quality)=='number'and quality>=1 then if quality<=3 then tier=1 elseif quality<=6 then tier=math.min(tier,2)end end
 local b
 if tier==1 then b={Tier=1,Characters=4,LocalMarks=12,OtherMarks=6,Idle=1,Particles=40,Scale=.5,Near=45,Mid=45,Arcs=2}
 elseif tier==2 then b={Tier=2,Characters=6,LocalMarks=18,OtherMarks=18,Idle=3,Particles=90,Scale=.75,Near=60,Mid=100,Arcs=4}
 else b={Tier=3,Characters=8,LocalMarks=24,OtherMarks=36,Idle=5,Particles=160,Scale=1,Near=75,Mid=120,Arcs=6}end
 b.Reduced=reduced==true
 if b.Reduced then b.Scale*=.5;b.Arcs=0 end
 return b
end
-- 3 = prints, bursts and idle aura; 2 = prints only; 1 = ground ribbons only.
function S.Detail(isLocal,distance,onScreen,b)
 if isLocal then return 3 end
 if distance<=b.Near then return onScreen and 3 or 2 end
 if distance<=b.Mid and onScreen then return 2 end
 return 1
end
-- Stride grows with speed, so prints stay a few per second even at 500 studs/s.
function S.Spacing(speed)return math.clamp(speed*.12,2.2,60)end
function S.Interval(isLocal,b)return(isLocal and .11 or .16)*(b.Tier==1 and 1.5 or 1)end
function S.Stretch(speed)return 1+math.clamp((speed-40)/100,0,.8)end
function S.Life(theme,speed)return theme.Print.Life*(speed>150 and .7 or 1)end
function S.BurstScale(speed,b)return b.Scale*(speed>200 and .6 or 1)end
-- Footprint parts in the ground frame (X right, Y along the normal, -Z forward). Tone 1 = print, 2 = accent.
function S.PrintParts(kind,scale,stretch,mirror)
 local k,z=scale,scale*stretch;local yaw=CFrame.Angles(0,mirror*.08,0)
 if kind=='Crystal'then
  return {
   {Size=V(.2,.2,.2)*k,Frame=CFrame.new(-.14*k,.02*k,-.2*z)*CFrame.Angles(.5,.79,.3),Tone=1},
   {Size=V(.16,.16,.16)*k,Frame=CFrame.new(.16*k,.02*k,.16*z)*CFrame.Angles(-.4,.4,.5),Tone=1},
   {Size=V(.14,.14,.14)*k,Frame=CFrame.new(0,.03*k,-.02*z)*CFrame.Angles(.6,.79,0),Tone=2},
  }
 elseif kind=='Lightning'then
  local out={}
  for i=1,3 do
   local x0=({-.14,.18,-.18})[i];local x1=({.18,-.18,.14})[i];local z0=(i-2)*.32-.16;local z1=z0+.32
   local dx,dz=(x1-x0)*k,(z1-z0)*z
   table.insert(out,{Size=V(.11*k,.035*k,math.sqrt(dx*dx+dz*dz)),Frame=yaw*CFrame.new((x0+x1)*.5*k,.006,(z0+z1)*.5*z)*CFrame.Angles(0,math.atan2(dx,dz),0),Tone=1})
  end
  return out
 end
 -- Sole print: forefoot, heel and a third piece (toe dig, frost star or glowing crack).
 local third
 if kind=='Frost'then third={Size=V(.3,.02,.3)*k,Frame=CFrame.new(0,.012,0)*CFrame.Angles(0,.79,0),Tone=2}
 elseif kind=='Ember'then third={Size=V(.07*k,.03*k,.62*z),Frame=yaw*CFrame.new(0,.01,-.02*z)*CFrame.Angles(0,.5*mirror,0),Tone=2}
 else third={Size=V(.34*k,.035*k,.1*z),Frame=yaw*CFrame.new(0,.008,-.52*z),Tone=2}end
 return {
  {Size=V(.46*k,.03*k,.5*z),Frame=yaw*CFrame.new(0,.006,-.2*z),Tone=1},
  {Size=V(.36*k,.03*k,.3*z),Frame=yaw*CFrame.new(0,.006,.3*z),Tone=1},
  third,
 }
end
return S
