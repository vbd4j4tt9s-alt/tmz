--!nocheck
-- R151 treadmill look PROPOSAL - a preview prototype, NOT game code (nothing in src/ uses it; the previews load it on the Roblox mock).
-- Owner: "keep the shape of the treadmills that we hve but just see what we can improve and addd from the references above".
-- It runs AFTER the real BiomeVisuals.BuildTreadmillV131 and only ADDS small elements onto the existing machine (the frame, rails, fronts,
-- console, chevrons, belt collider, prompt and badge are untouched; their parts keep their size, place and colour):
--  * an animated belt: tiled Textures (textures/*.png) on the existing "Track surface" top face that scroll (OffsetStudsV) with the chevrons, 1-3 layers by
--    level, plus two flowing light Beams (TextureSpeed) along the belt edges from the mid levels; the old per-part "flow" belt pieces (sand
--    ripples, molten currents, prism glints, travelling lightning, frost reflections: moved part by part every frame) are retired;
--  * glowing neon trims: a rim line round the chassis, and (mid / top) a glow line along each side bumper;
--  * studs: chunky studs along the top of both side bumpers, and studded plinths under the corner accents;
--  * small corner accents at the entry end (lamp posts, torches, braziers, frost / prism lamps; Lava and Storm already have pylons there,
--    which get studded plinths), each with one subtle themed particle near the camera;
--  * real light: an entry glow (and a deck underglow from the mid levels), capped per level;
--  * a "+N/step" label floating just above the existing front (hidden for the runner while they train);
--  * D.Sign: a small studded upgrade sign beside the existing floor button, in the next level's colours (the button itself is unchanged).
-- Everything new is anchored, CanCollide / CanQuery / CanTouch false, and carries the R117 TreadmillFx attributes, so the client turns the
-- lights, particles and beams on only near the camera (as today); the texture scroll would be one more TreadmillFx list.
local RS=game:GetService('ReplicatedStorage')
local Palette=require(RS:WaitForChild('MysteryPackRules')).Palette -- the treadmill theme colours by biome Stage (same as the R150 pedestal)
local D={Version=1}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local function c3(t)return RGB(t[1],t[2],t[3])end
D.Grid='rbxassetid://6372755229' -- the place's own baseplate grid texture (already on every pad / floor): the no-upload fallback
-- level -> biome (Config.TreadmillTiers order) and grade
D.Biome={'Forest','Jungle','Desert','Snow','Lava','Crystal','Storm'}
D.Stage={1,6,2,3,4,5,7}
D.Grade={'low','low','mid','mid','mid','top','top'}
-- Per-grade config. Layers = belt texture layers; EdgeBeams / BumperLines / Underglow / Pulse = which extras the grade gets;
-- StudPitch = studs apart on the bumpers; Cap = the most real lights the whole machine (old + new) may have (all are client-enabled
-- within 110 studs, quality 2+); Budget = the most NEW parts (net of retired belt pieces).
D.Grades={
 low={Layers=1,EdgeBeams=false,BumperLines=false,StudPitch=2.0,Underglow=false,Pulse=false,Cap=3,Budget=48},
 mid={Layers=2,EdgeBeams=true,BumperLines=true,StudPitch=1.6,Underglow=true,Pulse=false,Cap=5,Budget=48},
 top={Layers=3,EdgeBeams=true,BumperLines=true,StudPitch=1.6,Underglow=true,Pulse=true,Cap=6,Budget=48},
}
-- The five belt images (docs/proposals/R151/treadmills/textures/*.png, made by make_belt_textures.py): white on transparent, tinted per
-- biome by Texture.Color3. They are the only new uploads; until they are uploaded the belt falls back to the place's own grid (D.Grid).
D.Images={slats='',circuit='',crust='',veins='',stream=''}
-- Per-biome config. Belt layers: {image, Color, T (transparency), U, V (studs per tile), Rate (scroll speed x the chevrons')}.
--  Slats = the moving belt surface (every level); Glow = brighter light lines (mid +); Stream = a fast third layer (top).
--  Beam = the edge light flow (colour, built-in particle texture). Neon = the trim colour. Accent = the corner accent kind; Mote = its particle.
D.Biomes={
 Forest={Slats={'slats',RGB(178,225,140),.4,9.2,1.6,1},Neon=RGB(150,230,110),Accent='Lantern',Mote={RGB(214,255,120),'sparkles'},Lamp=RGB(255,214,120)},
 Jungle={Slats={'slats',RGB(140,230,170),.4,9.2,1.4,1},Neon=RGB(90,225,150),Accent='Torch',Mote={RGB(255,190,90),'sparkles'},Lamp=RGB(255,160,60)},
 Desert={Slats={'slats',RGB(150,92,48),.3,9.2,1.6,1},Glow={'veins',RGB(255,240,170),.35,4.6,4.6,1.6},Beam={RGB(255,226,140),'sparkles'},
  Neon=RGB(255,196,90),Accent='Brazier',Mote={RGB(255,200,90),'sparkles'},Lamp=RGB(255,170,70)},
 Snow={Slats={'slats',RGB(70,150,215),.35,9.2,1.6,1},Glow={'circuit',RGB(130,245,255),.12,4.6,4.6,1.6},Beam={RGB(150,240,255),'sparkles'},
  Neon=RGB(110,230,255),Accent='Frost',Mote={RGB(235,250,255),'sparkles'},Lamp=RGB(150,235,255)},
 Lava={Slats={'crust',RGB(56,26,24),.04,4.6,4.6,1},Glow={'veins',RGB(255,226,110),.3,4.6,5.12,1.6},Beam={RGB(255,150,50),'fire'},
  Neon=RGB(255,120,40),Accent='Plinth'},
 Crystal={Slats={'slats',RGB(255,205,250),.35,9.2,1.6,1},Glow={'circuit',RGB(140,255,240),.15,4.6,4.6,1.6},Stream={'veins',RGB(255,255,255),.45,3.07,5.12,2.4},
  Beam={RGB(255,200,250),'sparkles'},Neon=RGB(150,250,240),Accent='Prism',Mote={RGB(255,190,250),'sparkles'},Lamp=RGB(150,250,240)},
 Storm={Slats={'slats',RGB(110,170,255),.3,9.2,1.4,1},Glow={'circuit',RGB(255,236,120),.15,4.6,4.6,1.6},Stream={'stream',RGB(170,225,255),.1,2.3,4.6,2.4},
  Beam={RGB(150,205,255),'sparkles'},Neon=RGB(120,190,255),Accent='Plinth'},
}
-- "+N/step": what one training step (Config.TrainingInterval) of this machine level gives (Config.TrainingPointsPerSecond x the machine
-- multiplier x the interval), formatted like the speed popups.
function D.Format(n)
 for _,u in ipairs({{1e12,'T'},{1e9,'B'},{1e6,'M'},{1e3,'K'}})do
  if n>=u[1]then return(string.format('%.1f',n/u[1]):gsub('%.0$',''))..u[2]end
 end
 return string.format('%.0f',n)
end
function D.StepGain(config,level)
 local tier=config.TreadmillTiers[level];if not tier then return nil end
 return config.TrainingPointsPerSecond*config.TrainingInterval*(tier.Multiplier or 1)
end
function D.Label(config,level)return'+'..D.Format(D.StepGain(config,level))..'/step'end

local function newPart(parent,name,size,frame,color,material,class)
 local p=Instance.new(class or'Part');p.Name=name;p.Size=size;p.CFrame=frame;p.Color=color;p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function seq(a,b)return b and ColorSequence.new(a,b)or ColorSequence.new(a)end
-- TreadmillFx (R117) roles: lights / particles / ribbons are created disabled and enabled by the client near the camera.
local function fxLight(parent,name,color,brightness,range,quality)
 local l=Instance.new('PointLight');l.Name=name;l.Enabled=false;l.Shadows=false;l.Color=color;l.Brightness=brightness;l.Range=range
 l:SetAttribute('TreadmillFx','Light');l:SetAttribute('TreadmillFxQuality',quality or 2);l:SetAttribute('TreadmillFxBrightness',brightness)
 l:SetAttribute('TreadmillFlicker',false);l.Parent=parent;return l
end
local function fxMote(parent,name,color,texture,rate,o)
 o=o or{}
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Enabled=false
 e.Texture='rbxasset://textures/particles/'..(texture or'sparkles')..'_main.dds'
 e.Color=seq(color);e.Rate=rate;e.Lifetime=NumberRange.new(o.Life and o.Life[1]or 1.2,o.Life and o.Life[2]or 2.2)
 e.Speed=NumberRange.new(o.Speed and o.Speed[1]or .3,o.Speed and o.Speed[2]or .9);e.SpreadAngle=Vector2.new(o.Spread or 60,o.Spread or 60)
 e.Acceleration=o.Accel or V(0,.25,0);e.Drag=o.Drag or .8;e.LightEmission=o.Light or .8;e.LightInfluence=.1
 e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-30,30)
 local s=o.Size or .16
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s*.4),NumberSequenceKeypoint.new(.35,s),NumberSequenceKeypoint.new(1,s*.1)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,.15),NumberSequenceKeypoint.new(1,1)})
 e:SetAttribute('TreadmillFx','Ambient');e:SetAttribute('TreadmillFxQuality',o.Quality or 2);e:SetAttribute('TreadmillFxRate',rate)
 e:SetAttribute('TreadmillFxBurst',0);e.Parent=parent;return e
end
local function pulse(v,amp,speed,phase)
 v:SetAttribute('TreadmillPulse',amp);v:SetAttribute('TreadmillPulseSpeed',speed);v:SetAttribute('TreadmillPulsePhase',phase or 0)
 v:SetAttribute('TreadmillPulseBase',v.Transparency);return v
end

-- Axis-aligned bounds (origin space) of the machine's existing parts, to keep new studs out of rails, pillars and roots.
local function boundsOf(origin,p)
 local cf=origin:ToObjectSpace(p.CFrame);local s=p.Size;local r={cf.RightVector,cf.UpVector,-cf.LookVector}
 local e={0,0,0}
 for i,axis in ipairs({'X','Y','Z'})do e[i]=(math.abs(r[1][axis])*s.X+math.abs(r[2][axis])*s.Y+math.abs(r[3][axis])*s.Z)/2 end
 local c=cf.Position
 return{c.X-e[1],c.Y-e[2],c.Z-e[3]},{c.X+e[1],c.Y+e[2],c.Z+e[3]}
end

-- base: a base Model already holding Treadmill + TreadmillArtV131 (BuildTreadmillV131(base, level)). Returns a summary.
function D.Apply(base,level,config)
 level=math.clamp(math.floor(tonumber(level)or 1),1,7)
 local belt=assert(base:FindFirstChild('Treadmill'),'needs the treadmill');local m=assert(base:FindFirstChild('TreadmillArtV131'),'needs the art')
 local origin=belt.CFrame
 local biome=D.Biome[level];local B=D.Biomes[biome];local G=D.Grades[D.Grade[level]];local pal=Palette[D.Stage[level]]
 local body,trim,glow,ink=c3(pal.Body),c3(pal.Trim),c3(pal.Glow),c3(pal.Ink)
 local bodyMaterial=Enum.Material[pal.Material]or Enum.Material.SmoothPlastic
 local summary={Level=level,Biome=biome,Grade=D.Grade[level],Retired=0,Parts=0,Lights=0,Emitters=0,Beams=0,Textures=0}
 local old=m:FindFirstChild('TreadmillDress');if old then old:Destroy()end
 local dm=Instance.new('Model');dm.Name='TreadmillDress';dm:SetAttribute('DressVersion',D.Version);dm:SetAttribute('DressLevel',level)
 local function P(name,size,frame,color,material,class)return newPart(dm,name,size,origin*frame,color,material,class)end
 local function stud(name,x,y,z,d,h,color,material)
  local s=P(name,V(h,d,d),CF(x,y,z)*CFrame.Angles(0,0,math.pi/2),color,material);s.Shape=Enum.PartType.Cylinder;return s
 end
 local function ball(name,size,frame,color,material)local b=P(name,size,frame,color,material);b.Shape=Enum.PartType.Ball;return b end
 local surface=assert(m:FindFirstChild('Track surface'),'needs the track surface')

 -- 1. Belt. Retire the per-part flow pieces (the chevrons stay: they are the forward arrows), add scrolling texture layers.
 for _,v in ipairs(m:GetChildren())do
  if v:IsA('BasePart')and v:GetAttribute('TrackMotion')=='Flow'then v:Destroy();summary.Retired+=1 end
 end
 local layers={{'BeltSlats',B.Slats},{'BeltGlowLines',B.Glow},{'BeltStream',B.Stream}}
 for i=1,G.Layers do
  local spec=layers[i][2]
  if spec then
   local t=Instance.new('Texture');t.Name=layers[i][1];t.Face=Enum.NormalId.Top
   local image=D.Images[spec[1]];t.Texture=(image and image~='')and image or D.Grid;t:SetAttribute('BeltImage',spec[1])
   t.Color3=spec[2];t.Transparency=spec[3];t.StudsPerTileU=spec[4];t.StudsPerTileV=spec[5];t.OffsetStudsU=0;t.OffsetStudsV=0;t.ZIndex=i
   t:SetAttribute('TreadmillScroll',spec[6]) -- client: OffsetStudsV follows the belt travel x this (with the chevrons; 0 with Reduced Motion)
   t.Parent=surface;summary.Textures+=1
  end
 end
 if G.EdgeBeams and B.Beam then
  for side=-1,1,2 do
   local a0=Instance.new('Attachment');a0.Name='Edge flow back';a0.Position=V(side*4.42,.1,7.5);a0.Parent=surface
   local a1=Instance.new('Attachment');a1.Name='Edge flow front';a1.Position=V(side*4.42,.1,-7.5);a1.Parent=surface
   local b=Instance.new('Beam');b.Name='Edge light flow';b.Enabled=false;b.Attachment0=a0;b.Attachment1=a1;b.FaceCamera=true;b.Segments=1
   b.Width0=.32;b.Width1=.32;b.Color=seq(B.Beam[1]);b.LightEmission=1;b.LightInfluence=0
   b.Texture='rbxasset://textures/particles/'..B.Beam[2]..'_main.dds';b.TextureMode=Enum.TextureMode.Static;b.TextureLength=2.2
   b.TextureSpeed=1.2;b.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.12,.25),NumberSequenceKeypoint.new(.88,.25),NumberSequenceKeypoint.new(1,1)})
   b:SetAttribute('TreadmillFx','Ribbon');b:SetAttribute('TreadmillFxQuality',2);b.Parent=surface;summary.Beams+=1
  end
 end

 -- 2. Neon trims: a rim line round the chassis (every level), a glow line on each side bumper (mid / top).
 local rim=B.Neon
 for side=-1,1,2 do
  local r=P('Rim glow line',V(.08,.18,16.6),CF(side*6.24,-.38,0),rim,Enum.Material.Neon)
  if G.Pulse then pulse(r,.25,1.2,side)end
  local e=P('Rim glow line',V(9.4,.18,.08),CF(0,-.38,side*9.88),rim,Enum.Material.Neon)
  if G.Pulse then pulse(e,.25,1.2,side+1)end
  if G.BumperLines then P('Bumper glow line',V(.07,.12,13.6),CF(side*6.015,.22,0),rim,Enum.Material.Neon)end
 end

 -- 3. Studs along the top of both side bumpers (skipping any spot where a rail, pillar or root of the machine already is).
 local blockers={}
 for _,v in ipairs(m:GetDescendants())do
  if v:IsA('BasePart')and not v:IsDescendantOf(dm)and not v.Name:find('Soft side bumper',1,true)and v.Transparency<1 then
   local lo,hi=boundsOf(origin,v);if hi[2]>.55 and lo[2]<.9 and hi[1]>5 then blockers[#blockers+1]={lo,hi}end
  end
 end
 local studColor=c3(pal.Trim):Lerp(Color3.new(1,1,1),.18)
 local n=math.floor(14.4/G.StudPitch+.5)
 for side=-1,1,2 do
  for k=0,n do
   local z=-7.2+k*14.4/n;local x=side*5.55
   local free=true
   for _,b in ipairs(blockers)do
    if x+.3>b[1][1]and x-.3<b[2][1]and z+.3>b[1][3]and z-.3<b[2][3]then free=false;break end
   end
   if free then stud('Bumper stud',x,.72,z,.5,.22,studColor)end
  end
 end

 -- 4. Corner accents at the entry end (the runner steps on at +Z). Lava / Storm: their pylons / capacitor banks get studded plinths.
 local accentLight
 local function studdedPlinth(x,z,size,height,color,material)
  local top=-.76+height
  P('Accent plinth',V(size,height,size),CF(x,-.76+height/2,z),color,material)
  P('Accent plinth glow band',V(size+.06,.08,size+.06),CF(x,top-.09,z),rim,Enum.Material.Neon)
  local o=size/2-.3
  for _,dx in ipairs({-o,o})do for _,dz in ipairs({-o,o})do stud('Plinth stud',x+dx,top+.05,z+dz,.34,.14,color:Lerp(Color3.new(1,1,1),.12),material)end end
  return top
 end
 if B.Accent=='Plinth'then
  for side=-1,1,2 do studdedPlinth(side*6.1,8.64,1.7,.55,ink,Enum.Material.Slate)end
 else
  for side=-1,1,2 do
   local x,z=side*6.95,9.05
   local top=studdedPlinth(x,z,1.3,.6,ink,Enum.Material.Slate)
   local lamp
   if B.Accent=='Lantern'then
    local sh=P('Lantern post',V(2.4,.42,.42),CF(x,top+1.2,z)*CFrame.Angles(0,0,math.pi/2),body,Enum.Material.Wood);sh.Shape=Enum.PartType.Cylinder
    P('Lantern post arm',V(.16,.16,.9),CF(x,top+2.3,z-.32),ink,Enum.Material.Wood)
    P('Lantern cap',V(.66,.14,.66),CF(x,top+2.47,z),ink,Enum.Material.Wood)
    lamp=P('Lantern glow',V(.46,.56,.46),CF(x,top+2.12,z),B.Lamp,Enum.Material.Neon)
    P('Lantern base',V(.6,.12,.6),CF(x,top+1.78,z),ink,Enum.Material.Wood)
   elseif B.Accent=='Torch'then
    local sh=P('Bamboo torch',V(2.5,.36,.36),CF(x,top+1.25,z)*CFrame.Angles(0,0,math.pi/2),body,Enum.Material.Wood);sh.Shape=Enum.PartType.Cylinder
    for _,y in ipairs({.7,1.6})do stud('Bamboo band',x,top+y,z,.44,.12,trim,Enum.Material.Wood)end
    stud('Torch bowl',x,top+2.62,z,.78,.28,ink,Enum.Material.Wood)
    lamp=ball('Torch flame',V(.5,.78,.5),CF(x,top+3.05,z),B.Lamp,Enum.Material.Neon)
   elseif B.Accent=='Brazier'then
    P('Brazier column',V(.78,1.7,.78),CF(x,top+.85,z),body,bodyMaterial)
    P('Brazier collar',V(1.0,.2,1.0),CF(x,top+1.8,z),trim,Enum.Material.Metal)
    stud('Brazier bowl',x,top+2.07,z,1.12,.34,RGB(232,186,92),Enum.Material.Metal)
    lamp=ball('Brazier flame',V(.62,.82,.62),CF(x,top+2.55,z),B.Lamp,Enum.Material.Neon)
   elseif B.Accent=='Frost'then
    local sh=P('Frost lamp column',V(.56,1.9,.56),CF(x,top+.95,z),body,Enum.Material.Ice);sh.Transparency=.2
    P('Frost lamp snow cap',V(.84,.18,.84),CF(x,top+1.99,z),RGB(245,252,255),Enum.Material.Snow)
    lamp=ball('Frost crystal',V(.62,.9,.62),CF(x,top+2.55,z),B.Lamp,Enum.Material.Neon)
   elseif B.Accent=='Prism'then
    local sh=P('Prism lamp column',V(.56,1.9,.56),CF(x,top+.95,z),body,Enum.Material.Glass);sh.Transparency=.15
    P('Prism lamp collar',V(.84,.16,.84),CF(x,top+1.98,z),trim,Enum.Material.Metal)
    lamp=P('Prism shard',V(.46,1.1,.46),CF(x,top+2.62,z)*CFrame.Angles(0,math.pi/4,0),B.Lamp,Enum.Material.Neon)
    P('Prism shard small',V(.28,.62,.28),CF(x-side*.32,top+2.3,z+.1)*CFrame.Angles(0,math.pi/4,side*.45),RGB(255,180,245),Enum.Material.Neon)
   end
   if lamp then
    if G.Pulse then pulse(lamp,.2,1.6,side)end
    local a=Instance.new('Attachment');a.Name='Accent mote';a.Parent=lamp
    fxMote(a,'Accent motes',B.Mote[1],B.Mote[2],B.Accent=='Torch'and 3 or 1.5,{Size=B.Accent=='Torch'and .14 or .18,Quality=2,Accel=V(0,B.Accent=='Frost'and-.2 or .4,0)})
    summary.Emitters+=1
   end
  end
 end
 -- 5. Real light, capped: an entry glow between the accents (every level), a deck underglow (mid / top, unless the machine has one).
 local existing=0
 for _,v in ipairs(m:GetDescendants())do if v:IsA('Light')and not v:IsDescendantOf(dm)then existing+=1 end end
 local room=G.Cap-existing
 local function addLight(name,pos,color,brightness,range,quality)
  if room<=0 then return end
  local a=Instance.new('Attachment');a.Name=name;a.Position=pos;a.Parent=surface
  fxLight(a,name,color,brightness,range,quality);room-=1;summary.Lights+=1
 end
 if B.Accent~='Plinth'then addLight('Entry glow',V(0,1.6,9.2),B.Lamp,1,14,2)end
 local hasUnder=false
 for _,v in ipairs(m:GetDescendants())do if v:IsA('Light')and v.Name:find('nderglow',1,true)then hasUnder=true end end
 if G.Underglow and not hasUnder then addLight('Deck underglow',V(0,-.75,0),B.Neon,1.1,15,3)end

 -- 6. "+N/step" over the front: a BillboardGui on an attachment of the tier plaque (never under the belt: training blanks its labels).
 local plaque=m:FindFirstChild('Tier plaque')
 if plaque and config then
  local top=-math.huge
  for _,v in ipairs(m:GetDescendants())do
   if v:IsA('BasePart')and not v:IsDescendantOf(dm)and v.Transparency<.9 and not v:GetAttribute('TreadmillSpin')then
    local lo,hi=boundsOf(origin,v);if hi[3]<-4 or v.Name:find('Storm cloud',1,true)then top=math.max(top,hi[2])end
   end
  end
  local a=Instance.new('Attachment');a.Name='Step label anchor'
  a.Position=plaque.CFrame:PointToObjectSpace((origin*CF(0,top+1.5,origin:PointToObjectSpace(plaque.Position).Z)).Position);a.Parent=plaque
  local g=Instance.new('BillboardGui');g.Name='StepLabel';g.Size=UDim2.fromScale(8,2);g.LightInfluence=0;g.MaxDistance=90;g.AlwaysOnTop=false
  g:SetAttribute('HideWhileOwnerTrains',true);g.Parent=a
  local t=Instance.new('TextLabel');t.Name='Gain';t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.TextScaled=true;t.Font=Enum.Font.FredokaOne
  t.Text=D.Label(config,level);t.TextColor3=glow;t.TextStrokeColor3=ink;t.TextStrokeTransparency=0;t.Parent=g
  local s=Instance.new('UIStroke');s.Color=ink:Lerp(Color3.new(0,0,0),.35);s.Thickness=3;s.Parent=t
  summary.Label=t.Text
 end
 dm.Parent=m
 for _,v in ipairs(dm:GetDescendants())do if v:IsA('BasePart')then summary.Parts+=1 end end
 summary.Net=summary.Parts-summary.Retired
 return summary
end

-- The upgrade sign: beside the existing floor button (GardenUpgradeButtons / "Treadmill housing", which is unchanged), on the far side from
-- the treadmill, facing it. Shows the NEXT level in its colours: "UPGRADE", "LV 3 > LV 4", "+333 > +1.7K /step" and the price, or MAX LEVEL.
-- Plus a neon rim round that button's housing, in the treadmill's trim colour.
function D.Sign(base,level,config,format)
 local buttons=base:FindFirstChild('GardenUpgradeButtons');local housing=buttons and buttons:FindFirstChild('Treadmill housing')
 if not housing then return nil end
 local old=base:FindFirstChild('TreadmillUpgradeSign');if old then old:Destroy()end
 local nextLevel=config.TreadmillTiers[level+1]and level+1 or nil
 local show=nextLevel or level
 local pal=Palette[D.Stage[show]];local now=D.Biomes[D.Biome[level]]
 local ink,trim,glow=c3(pal.Ink),c3(pal.Trim),c3(pal.Glow)
 local s=Instance.new('Model');s.Name='TreadmillUpgradeSign'
 -- housing space: centre of the 10.4 x 1.5 x 10.4 housing; the treadmill is towards +X; the pad top is at y -0.75
 local h=housing.CFrame
 local function P(name,size,frame,color,material,class)return newPart(s,name,size,h*frame,color,material,class)end
 local x=-6.1
 for _,z in ipairs({-3.15,3.15})do P('Sign post',V(.5,4.6,.5),CF(x,-.75+2.3,z),ink,Enum.Material.Slate)end
 local board=P('Sign board',V(.36,2.7,6.9),CF(x,2.55,0),ink:Lerp(Color3.new(0,0,0),.25),Enum.Material.SmoothPlastic)
 P('Sign top beam',V(.7,.42,7.5),CF(x,4.11,0),ink,Enum.Material.Slate)
 for k=-2,2 do
  local st=P('Sign stud',V(.16,.42,.42),CF(x,4.4,k*1.45)*CFrame.Angles(0,0,math.pi/2),ink:Lerp(Color3.new(1,1,1),.12),Enum.Material.Slate);st.Shape=Enum.PartType.Cylinder
 end
 for _,z in ipairs({-3.5,3.5})do P('Sign glow edge',V(.1,2.7,.1),CF(x+.24,2.55,z),trim,Enum.Material.Neon)end
 P('Sign glow edge',V(.1,.1,7.1),CF(x+.24,1.15,0),trim,Enum.Material.Neon)
 -- the floor button's housing gets a neon rim in the treadmill's own trim colour (current level)
 for _,side in ipairs({-1,1})do
  P('Button rim glow',V(10.48,.12,.06),CF(0,.18,side*5.23),now.Neon,Enum.Material.Neon)
  P('Button rim glow',V(.06,.12,10.48),CF(side*5.23,.18,0),now.Neon,Enum.Material.Neon)
 end
 local gui=Instance.new('SurfaceGui');gui.Name='UpgradeSign';gui.Face=Enum.NormalId.Right;gui.CanvasSize=Vector2.new(690,270);gui.LightInfluence=0;gui.MaxDistance=80;gui.Parent=board
 local function text(name,value,y,hgt,color)
  local t=Instance.new('TextLabel');t.Name=name;t.BackgroundTransparency=1;t.Position=UDim2.new(0,20,0,y);t.Size=UDim2.new(1,-40,0,hgt)
  t.Text=value;t.TextScaled=true;t.Font=Enum.Font.FredokaOne;t.TextColor3=color;t.TextStrokeColor3=Color3.new(0,0,0);t.TextStrokeTransparency=.3;t.Parent=gui;return t
 end
 if nextLevel then
  text('Title','UPGRADE',12,62,Color3.new(1,1,1))
  text('Levels','LV '..level..'  >  LV '..nextLevel,80,58,glow)
  text('Gain',D.Label(config,level):gsub('/step','')..'  >  '..D.Label(config,nextLevel),142,50,trim)
  local price=Instance.new('TextLabel');price.Name='Price';price.Position=UDim2.new(.5,-130,0,200);price.Size=UDim2.new(0,260,0,56)
  price.BackgroundColor3=RGB(232,62,62);price.Text=(format or D.Format)(config.TreadmillTiers[nextLevel].Cost);price.TextScaled=true
  price.Font=Enum.Font.FredokaOne;price.TextColor3=Color3.new(1,1,1);price.TextStrokeTransparency=.4;price.Parent=gui
  local c=Instance.new('UICorner');c.CornerRadius=UDim.new(0,14);c.Parent=price
 else
  text('Title','MAX LEVEL',30,80,glow)
  text('Gain',D.Label(config,level),140,70,trim)
 end
 s.Parent=base
 local parts=0;for _,v in ipairs(s:GetDescendants())do if v:IsA('BasePart')then parts+=1 end end
 return{Parts=parts}
end
return D
