-- R111: per-biome boot ground effects and their client budget. Cosmetic only; read by RunnerTrailEffects.
-- Print = footprint parts and how they age, Burst = particles kicked up on each print, Idle = aura while standing.
-- Ribbon = the R47 ground ribbon colours; slightly more transparent than R47 (.2) so the fresh prints show through.
-- Textures are Roblox built-ins (rbxasset://textures/particles/...), so nothing has to be uploaded.
-- R117: each tier adds effects on top of the one below (see the table in docs/proposals/boots_R117/NOTES.md):
-- Land = particles on landing (all tiers); Start = the landing moment also fires when sprinting off from standing;
-- Ring = an expanding ground ring of 8 segments; Strike = a lightning bolt from the sky (+ a brief light on high);
-- Sprint = emitters on the boot soles while running fast; Glint = emitters on named boot parts (gem glints, embers,
-- coil sparks); Coils = boot parts whose glow pulses up the leg; BootArc = arcs jumping between the two boots.
local S={}
local C,V=Color3.fromRGB,Vector3.new
local M=Enum.Material
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
S.StillSpeed=.8 -- studs/s; slower than this counts as standing
S.StillDelay=.6 -- seconds standing before the idle aura fades in
S.FadeIn=.8;S.FadeOut=.25
S.LandAir=.3 -- seconds airborne before touching down counts as a landing
S.StartRest=.35;S.StartSpeed=10 -- standing this long, then moving at least this fast, is a sprint start
S.SprintSpeed=30 -- studs/s; Sprint emitters run above this
S.Grace=1.5 -- seconds a runner may stay below full detail before its boot emitters are removed
local RAINBOW={C(255,150,214),C(140,230,255),C(255,226,140),C(170,255,200),C(178,112,255)}
S.Rainbow=RAINBOW
-- Emitter fields: Size/Alpha {start,end} or {start,middle,end}; Life/Speed/Spin {min,max}; Glow=LightEmission;
-- Light=LightInfluence; Shape/Style=ParticleEmitterShape/ShapeStyle on the idle part (disc at the wearer's soles).
-- Colors = a list of colours spread over the particle's life (rainbow); On = the boot part a Glint emitter sits in.
S.Themes={
 Desert={Tier=1,Ribbon={C(226,190,128),C(176,132,80)},RibbonAlpha=.5,RibbonGlow=0,
  Print={Kind='Sand',Life=2.6,Hold=.35,Alpha=.12,Color=C(168,126,80),Accent=C(138,100,62),Material=M.Sand},
  Burst={
   {Name='Dust puff',Texture=SMOKE,Color=C(222,192,142),Count=2,Size={.7,2.1},Life={.5,.9},Speed={1.5,3.5},Spread=70,Accel=V(0,-1,0),Drag=3,Alpha={.5,1},Glow=0,Light=1},
   {Name='Kicked sand',Texture=SPARK,Color=C(205,166,108),Count=3,Size={.15,.1},Life={.3,.6},Speed={3,6},Spread=50,Accel=V(0,-20,0),Alpha={.1,1},Glow=0,Light=.8},
  },
  Land={
   {Name='Landing dust',Texture=SMOKE,Color=C(222,192,142),Count=4,Size={.9,2.6},Life={.6,1},Speed={4,7},Spread=85,Accel=V(0,-1,0),Drag=4,Alpha={.45,1},Glow=0,Light=1},
  },
  Idle={Spin=2.4,Emitters={
   {Name='Swirling sand',Texture=SMOKE,Color=C(244,222,172),Rate=8,Size={1,2},Life={1.2,1.8},Speed={.2,.5},Alpha={.35,1},Glow=0,Light=1,Locked=true,Shape='Disc',Style='Surface'},
   {Name='Sand grains',Texture=SPARK,Color=C(160,120,72),Rate=14,Size={.17,.1},Life={1,1.6},Speed={.3,.8},Accel=V(0,.3,0),Alpha={.1,1},Glow=0,Light=.8,Locked=true,Shape='Disc'},
  }}},
 Snow={Tier=2,Ribbon={C(214,240,255),C(140,196,240)},RibbonAlpha=.42,RibbonGlow=.35,
  -- Prints start as clear ice, then crystallise into white frost with a small star before fading.
  Print={Kind='Frost',Life=3,Hold=.55,Alpha=.2,Turn=.3,Color=C(128,190,240),Material=M.Ice,Reflectance=.25,Color2=C(236,246,255),Material2=M.Snow,Accent=C(200,236,255)},
  Burst={
   {Name='Snow puff',Texture=SMOKE,Color=C(235,245,255),Count=2,Size={.6,1.7},Life={.5,.8},Speed={1.5,3},Spread=70,Drag=3,Alpha={.45,1},Glow=.1,Light=1},
   {Name='Snow flecks',Texture=SPARK,Color=C(245,250,255),Count=4,Size={.16,.1},Life={.4,.8},Speed={3,6},Spread=55,Accel=V(0,-12,0),Alpha={0,1},Glow=.4,Light=.6},
   {Name='Ice glitter',Texture=SPARK,Color=C(200,236,255),Count=2,Size={0,.26,0},Life={.3,.6},Speed={1,2.5},Spread=60,Alpha={0,.3},Glow=.8,Light=.2},
  },
  Land={
   {Name='Snow burst',Texture=SMOKE,Color=C(235,245,255),Count=4,Size={.8,2.4},Life={.6,1},Speed={4,7},Spread=85,Drag=4,Alpha={.4,1},Glow=.1,Light=1},
   {Name='Ice shards',Texture=SPARK,Color=C(210,240,255),Tail=C(128,200,250),Count=6,Size={.24,.1},Life={.4,.7},Speed={7,12},Spread=70,Accel=V(0,-24,0),Alpha={0,.6},Glow=.6,Light=.4},
  },
  Sprint={Emitters={
   {Name='Frost trail',Texture=SMOKE,Color=C(220,240,255),Rate=10,Size={.4,1.1},Life={.4,.7},Speed={.2,.6},Drag=2,Alpha={.55,1},Glow=.15,Light=1},
  }},
  -- Frost crystals creep over the ground around the feet while the wearer stands still.
  Idle={Patches={Count=6,Kind='Frost',Material=M.Ice,Color=C(140,200,250),Reflectance=.35,Alpha=.1,Size={.46,.28},Radius={.95,1.35}},Emitters={
   {Name='Frost mist',Texture=SMOKE,Color=C(186,220,248),Rate=3,Size={1.2,2.6},Life={2,3},Speed={.1,.3},Accel=V(0,-.1,0),Alpha={.55,1},Glow=.1,Light=1,Shape='Disc'},
   {Name='Snowflakes',Texture=SPARK,Color=C(250,252,255),Rate=9,Size={.2,.14},Life={1.6,2.4},Speed={1,1.6},Accel=V(0,-1.4,0),Alpha={.05,1},Glow=.7,Light=.4,Spin={-60,60},Shape='Disc'},
  }}},
 Lava={Tier=3,Start=true,Ribbon={C(255,140,53),C(195,62,35)},RibbonAlpha=.35,RibbonGlow=.65,
  -- Prints glow like fresh magma, cool through red to dark basalt, then fade.
  Print={Kind='Ember',Life=2.4,Hold=.55,Alpha=.05,Turn=.45,Turn2=.7,Color=C(255,200,90),Color2=C(226,68,24),Accent=C(255,236,160),Cool=C(58,42,36),Material2=M.Basalt},
  Burst={
   {Name='Magma sparks',Texture=SPARK,Color=C(255,160,60),Tail=C(255,70,20),Count=5,Size={.18,0},Life={.3,.6},Speed={6,12},Spread=45,Accel=V(0,-26,0),Alpha={0,.4},Glow=1,Light=0},
   {Name='Ash puff',Texture=SMOKE,Color=C(70,56,52),Count=1,Size={.6,1.6},Life={.6,1},Speed={1,2},Spread=40,Accel=V(0,2,0),Alpha={.6,1},Glow=0,Light=1},
   {Name='Flame lick',Texture=SMOKE,Color=C(255,190,80),Tail=C(255,70,20),Count=2,Size={.5,1.1,0},Life={.25,.4},Speed={2,4},Spread=25,Accel=V(0,6,0),Alpha={.2,1},Glow=1,Light=0},
  },
  Land={
   {Name='Magma splash',Texture=SPARK,Color=C(255,200,90),Tail=C(255,70,20),Count=10,Size={.26,0},Life={.4,.7},Speed={8,16},Spread=70,Accel=V(0,-30,0),Alpha={0,.4},Glow=1,Light=0},
   {Name='Ash cloud',Texture=SMOKE,Color=C(70,56,52),Count=2,Size={1,2.6},Life={.8,1.2},Speed={2,4},Spread=80,Accel=V(0,2,0),Drag=3,Alpha={.55,1},Glow=0,Light=1},
  },
  Ring={Colors={C(255,200,90),C(255,110,30)},Radius=2.6,Life=.4,Width=.16},
  Sprint={Emitters={
   {Name='Heel flames',Texture=SMOKE,Color=C(255,180,70),Tail=C(255,60,20),Rate=16,Size={.5,.9,0},Life={.2,.35},Speed={.5,1.5},Accel=V(0,5,0),Alpha={.15,1},Glow=1,Light=0},
   {Name='Trail embers',Texture=SPARK,Color=C(255,160,60),Tail=C(255,70,20),Rate=8,Size={.16,0},Life={.4,.8},Speed={1,3},Accel=V(0,3,0),Alpha={0,.3},Glow=1,Light=0},
  }},
  Glint={
   {Name='Ember wisps',On='Boot shaft',Texture=SPARK,Color=C(255,150,50),Tail=C(255,70,20),Rate=2.5,Size={.12,0},Life={.6,1.1},Speed={.5,1.2},Spread=30,Accel=V(0,1.5,0),Alpha={0,.3},Glow=1,Light=0},
  },
  -- Hot cracks glow in the ground around the feet.
  Idle={Patches={Count=6,Kind='Crack',Material=M.Neon,Color=C(255,110,30),Alpha=.1,Size={.09,.6},Radius={.85,1.25}},Emitters={
   {Name='Rising embers',Texture=SPARK,Color=C(255,150,50),Tail=C(255,70,20),Rate=12,Size={.24,0},Life={.9,1.6},Speed={1.2,2.6},Spread=25,Accel=V(.2,1.2,0),Alpha={0,.3},Glow=1,Light=0,Shape='Disc'},
   {Name='Heat haze',Texture=SMOKE,Color=C(120,70,50),Rate=2,Size={.8,2.2},Life={1,1.6},Speed={1.4,2.4},Spread=15,Alpha={.78,1},Glow=.2,Light=1,Shape='Disc'},
   {Name='Lava bubbles',Texture=SPARK,Color=C(255,220,120),Tail=C(255,90,20),Rate=4,Size={0,.45,0},Life={.4,.7},Speed={.1,.3},Alpha={0,.3},Glow=1,Light=0,Spin={0,0},Shape='Disc'},
  }}},
 Crystal={Tier=4,Start=true,Ribbon={C(193,152,250),C(115,178,237)},RibbonAlpha=.35,RibbonGlow=.65,
  -- Three small reflective shards poke out of each print; the centre one twinkles.
  -- R117: the glowing centre of each print takes the next rainbow colour.
  Print={Kind='Crystal',Life=2.6,Hold=.5,Alpha=.15,Color=C(222,204,255),Material=M.Glass,Reflectance=.5,Accent=C(178,112,255),Rainbow=RAINBOW},
  Burst={
   {Name='Crystal sparkles',Texture=SPARK,Color=C(232,212,255),Tail=C(170,110,255),Count=4,Size={0,.34,0},Life={.4,.8},Speed={1.5,3.5},Spread=60,Accel=V(0,-3,0),Alpha={0,.2},Glow=1,Light=0},
   {Name='Rainbow glints',Texture=SPARK,Colors=RAINBOW,Count=3,Size={0,.28,0},Life={.5,.9},Speed={2,4},Spread=70,Accel=V(0,-4,0),Alpha={0,.2},Glow=1,Light=0},
   {Name='Prism flash',Texture=SPARK,Color=C(255,255,255),Tail=C(214,180,255),Count=1,Size={0,1.2,0},Life={.15,.25},Speed={0},Alpha={0,.1},Glow=1,Light=0,Spin={0,0}},
  },
  Land={
   {Name='Prism burst',Texture=SPARK,Colors=RAINBOW,Count=12,Size={.3,0},Life={.5,.8},Speed={6,11},Spread=75,Accel=V(0,-8,0),Drag=1,Alpha={0,.2},Glow=1,Light=0},
   {Name='Prism flash',Texture=SPARK,Color=C(255,255,255),Tail=C(214,180,255),Count=1,Size={0,2.6,0},Life={.2,.3},Speed={0},Alpha={0,.1},Glow=1,Light=0,Spin={0,0}},
  },
  Ring={Colors=RAINBOW,Radius=3,Life=.45,Width=.14},
  Sprint={Emitters={
   {Name='Prism streak',Texture=SPARK,Colors=RAINBOW,Rate=14,Size={0,.3,0},Life={.35,.6},Speed={.2,.8},Drag=2,Alpha={0,.2},Glow=1,Light=0},
   {Name='Light streak',Texture=SPARK,Color=C(255,255,255),Tail=C(200,170,255),Rate=6,Size={.4,0},Life={.2,.35},Speed={0,.3},Alpha={.1,.4},Glow=1,Light=0,Spin={0,0}},
  }},
  -- Light catches the heel gem; rainbow sparkles drift off the glass shaft.
  Glint={
   {Name='Refraction glint',On='Heel gem',Texture=SPARK,Color=C(255,255,255),Tail=C(214,180,255),Rate=1.4,Size={0,.9,0},Life={.18,.3},Speed={0},Alpha={0,.1},Glow=1,Light=0,Spin={0,0}},
   {Name='Rainbow sparkle',On='Boot shaft',Texture=SPARK,Colors=RAINBOW,Rate=4,Size={0,.22,0},Life={.4,.8},Speed={.2,.6},Alpha={0,.2},Glow=1,Light=0},
  },
  -- Five prisms in rainbow glass orbit the feet over a ring of rainbow facets.
  Idle={Spin=.9,Shards=5,ShardColor=C(228,212,255),ShardGlow=C(170,96,255),ShardColors=RAINBOW,
   Patches={Count=6,Kind='Prism',Material=M.Glass,Colors=RAINBOW,Reflectance=.5,Alpha=.15,Size={.34,.34},Radius={.95,1.3}},Emitters={
   {Name='Crystal twinkles',Texture=SPARK,Color=C(236,220,255),Tail=C(180,120,255),Rate=10,Size={0,.5,0},Life={.5,.9},Speed={.4,1},Spread=40,Drag=1,Alpha={0,.2},Glow=1,Light=0,Shape='Disc'},
   {Name='Rainbow sparkle',Texture=SPARK,Colors=RAINBOW,Rate=8,Size={0,.3,0},Life={.8,1.4},Speed={.6,1.2},Spread=30,Drag=1,Alpha={0,.2},Glow=1,Light=0,Shape='Disc'},
   {Name='Refraction glints',Texture=SPARK,Color=C(255,255,255),Tail=C(214,180,255),Rate=1.5,Size={0,1.4,0},Life={.2,.3},Speed={.5,1},Alpha={0,.1},Glow=1,Light=0,Spin={0,0},Shape='Disc'},
  }}},
 Storm={Tier=5,Start=true,Ribbon={C(177,232,255),C(94,146,248)},RibbonAlpha=.35,RibbonGlow=.65,
  -- Zigzag prints flicker like a live wire, shift from white-cyan to blue and fade.
  Print={Kind='Lightning',Life=1.6,Hold=.4,Alpha=.08,Turn=.3,Color=C(200,244,255),Color2=C(70,140,255)},
  Arc=.45,ArcColor=C(190,240,255),
  BootArc={Every={.12,.3}}, -- arcs jump between the two boots while running
  Burst={
   {Name='Static sparks',Texture=SPARK,Color=C(170,235,255),Tail=C(80,150,255),Count=5,Size={.16,0},Life={.12,.3},Speed={8,15},Spread=80,Drag=6,Alpha={0,.2},Glow=1,Light=0},
   {Name='Plasma flash',Texture=SPARK,Color=C(235,250,255),Tail=C(90,190,255),Count=1,Size={0,1.4,0},Life={.1,.18},Speed={0},Alpha={0,.1},Glow=1,Light=0,Spin={0,0}},
   {Name='Bolt flecks',Texture=SPARK,Color=C(220,248,255),Tail=C(70,140,255),Count=3,Size={.12,0},Life={.4,.7},Speed={4,8},Spread=60,Accel=V(0,-18,0),Alpha={0,.3},Glow=1,Light=0},
  },
  -- Landing or sprinting off from standing calls a lightning bolt down onto the feet.
  Land={
   {Name='Strike sparks',Texture=SPARK,Color=C(200,244,255),Tail=C(70,140,255),Count=14,Size={.24,0},Life={.25,.5},Speed={10,20},Spread=80,Drag=5,Alpha={0,.2},Glow=1,Light=0},
   {Name='Plasma flash',Texture=SPARK,Color=C(235,250,255),Tail=C(90,190,255),Count=1,Size={0,3,0},Life={.15,.22},Speed={0},Alpha={0,.1},Glow=1,Light=0,Spin={0,0}},
   {Name='Scorch smoke',Texture=SMOKE,Color=C(60,70,96),Count=2,Size={.8,2.2},Life={.6,1},Speed={1,2},Spread=60,Accel=V(0,2,0),Alpha={.6,1},Glow=0,Light=1},
  },
  Ring={Colors={C(220,248,255),C(70,160,255)},Radius=3.4,Life=.35,Width=.12},
  Strike={Height=16,Color=C(235,250,255),Glow=C(90,190,255),Life=.3,Light=6,Range=18},
  Sprint={Emitters={
   {Name='Plasma streak',Texture=SPARK,Color=C(200,244,255),Tail=C(70,140,255),Rate=18,Size={.2,0},Life={.15,.3},Speed={1,3},Drag=4,Alpha={0,.2},Glow=1,Light=0},
   {Name='Static trail',Texture=SMOKE,Color=C(120,200,255),Tail=C(40,90,200),Rate=8,Size={.5,1.2},Life={.25,.45},Speed={0,.4},Alpha={.5,1},Glow=1,Light=0},
  }},
  Glint={
   {Name='Coil sparks',On='Volt coil',Texture=SPARK,Color=C(200,244,255),Tail=C(70,140,255),Rate=5,Size={.14,0},Life={.1,.25},Speed={2,5},Drag=5,Alpha={0,.2},Glow=1,Light=0},
   {Name='Spine sparks',On='Tesla spine',Texture=SPARK,Color=C(235,250,255),Tail=C(90,190,255),Rate=3,Size={.12,0},Life={.1,.2},Speed={3,6},Spread=50,Drag=5,Alpha={0,.2},Glow=1,Light=0},
  },
  -- The three coils on each shin glow brighter in turn, running up the leg (faster when running).
  Coils={Name='Volt coil',Hot=C(235,252,255),Speed=7},
  -- Electric field: a force-field dome, four charged nodes circling the feet, arcs between the boots, nodes and ground.
  Idle={ArcEvery={.25,.6},BootArcs=true,Spin=2.2,Shards=4,ShardMaterial=M.Neon,ShardColors={C(220,248,255),C(90,190,255)},Orbit={Radius=1.25,Height=.25,Size=.16},
   Dome={Material=M.ForceField,Color=C(110,200,255),Size=4.4,Alpha=0},
   Patches={Count=6,Kind='Crack',Material=M.Neon,Color=C(120,210,255),Alpha=.25,Size={.06,.5},Radius={1.1,1.5}},Emitters={
   {Name='Crackling sparks',Texture=SPARK,Color=C(160,230,255),Tail=C(90,160,255),Rate=18,Size={.22,0},Life={.15,.35},Speed={3,6},Spread=60,Drag=4,Alpha={0,.2},Glow=1,Light=0,Shape='Disc'},
   {Name='Static motes',Texture=SPARK,Color=C(220,248,255),Tail=C(90,160,255),Rate=6,Size={0,.2,0},Life={1,1.6},Speed={.3,.7},Spread=30,Accel=V(0,.6,0),Alpha={0,.3},Glow=1,Light=0,Shape='Disc'},
   {Name='Field glow',Texture=SMOKE,Color=C(90,180,255),Rate=2,Size={1.4,2.4},Life={.8,1.2},Speed={.1,.3},Alpha={.75,1},Glow=1,Light=0,Shape='Disc'},
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
 -- R117: Attach = other runners whose boots may carry emitters (the local wearer always may); Moments = pool of
 -- landing rings/lightning strikes (low: the local wearer only); Light = a brief PointLight with each strike.
 if tier==1 then b={Tier=1,Characters=4,LocalMarks=12,OtherMarks=6,Idle=1,Particles=40,Scale=.5,Near=45,Mid=45,Arcs=2,Attach=0,Moments=1,Light=false}
 elseif tier==2 then b={Tier=2,Characters=6,LocalMarks=18,OtherMarks=18,Idle=3,Particles=90,Scale=.75,Near=60,Mid=100,Arcs=4,Attach=1,Moments=2,Light=false}
 else b={Tier=3,Characters=8,LocalMarks=24,OtherMarks=36,Idle=5,Particles=160,Scale=1,Near=75,Mid=120,Arcs=6,Attach=3,Moments=4,Light=true}end
 b.Reduced=reduced==true
 -- Reduced Motion: half the particles, no arcs, rings, bolts, flashes, coil pulses or swirl.
 if b.Reduced then b.Scale*=.5;b.Arcs=0;b.Moments=0;b.Light=false end
 return b
end
-- Seconds between landing/start moments for one runner.
function S.MomentGap(isLocal)return isLocal and .5 or 1.5 end
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
 if kind=='Frost'then third={Size=V(.22,.02,.22)*k,Frame=CFrame.new(0,.012,0)*CFrame.Angles(0,.79,0),Tone=2}
 elseif kind=='Ember'then third={Size=V(.07*k,.03*k,.62*z),Frame=yaw*CFrame.new(0,.01,-.02*z)*CFrame.Angles(0,.5*mirror,0),Tone=2}
 else third={Size=V(.34*k,.035*k,.1*z),Frame=yaw*CFrame.new(0,.008,-.52*z),Tone=2}end
 return {
  {Size=V(.46*k,.03*k,.5*z),Frame=yaw*CFrame.new(0,.006,-.2*z),Tone=1},
  {Size=V(.36*k,.03*k,.3*z),Frame=yaw*CFrame.new(0,.006,.3*z),Tone=1},
  third,
 }
end
return S
