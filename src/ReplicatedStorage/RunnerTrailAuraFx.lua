-- R117: client-only trail auras on top of the server's back ribbons (RunnerTrailArt). Each trail tier adds layers:
-- motes, sparks, glows, a start burst, secondary ribbons (Aurora veil, Nebula swirl, Royal gold/purple double helix),
-- main-ribbon colour shimmer, Royal crown glints and footstep sparkles, and an idle shimmer on Nebula and Royal.
-- Built-in particle textures only. Rigs are pooled per trail; nothing here connects events (the client script owns
-- the RenderStepped (R153, was Heartbeat) and PlayerRemoving connections), and Release/Destroy free everything a rig made.
-- R118: head pieces (RunnerTrailArt.HeadPiece): Royal wears a glowing crown, Nebula a ring of orbiting space dust and
-- Aurora a shimmering halo. Client-only parts welded to the Head (massless, no collision/query/touch/shadow), following
-- the Head's LocalTransparencyModifier (hidden in first person). Layers marked Head=true live on Head attachments
-- (crown glints, halo motes, orbiting dust) and only run while the head piece is shown.
local Art=require(script.Parent.RunnerTrailArt)
local F={};F.__index=F
local V,C=Vector3.new,Color3.fromRGB
local SPARK='rbxasset://textures/particles/sparkles_main.dds'
local SMOKE='rbxasset://textures/particles/smoke_main.dds'
local FLARE='rbxasset://textures/particles/flare_main.dds'
F.Textures={SPARK,SMOKE,FLARE}
F.Prefix='TrailAura_'
-- Layer kinds: Emit (continuous, When Move/Idle), Burst (on starting to run), Pulse (timed glints at points),
-- Ribbon (secondary Trail; Veil sways, Helix orbits), Shift (main ribbon colour drift/sheen), Light (local runner).
-- MinDetail: 1 = always (motes), 2 = near/on-screen, 3 = full detail only. Motion layers are off for Reduced Motion.
-- When='Always': runs moving or standing. Head=true: attached to the Head (head-space points from Art.HeadPiece).
local TIPS={'Tip1','Tip2','Tip3','Tip4','Tip5'}
F.Specs={
 MintTrail={Tier=1,Layers={
  {Name='Motes',Kind='Emit',When='Move',At='Mid',MinDetail=1,Texture=SPARK,Colors={C(214,255,238),C(96,238,172),C(40,190,130)},Size={.32,.2,0},Alpha={.15,.35,1},Life={.45,.85},Speed={.8,2.2},Rate=9,Drag=2.5,Glow=.6},
  {Name='Burst',Kind='Burst',At='Mid',MinDetail=2,Motion=true,Texture=SMOKE,Colors={C(206,255,232),C(80,230,170)},Size={.5,1.8},Alpha={.55,1},Life={.3,.45},Speed={5,8},Count=8,Drag=6,Glow=.45},
 }},
 ArcTrail={Tier=2,Layers={
  {Name='Motes',Kind='Emit',When='Move',At='Mid',MinDetail=1,Texture=SPARK,Colors={C(228,248,255),C(110,190,255),C(50,90,255)},Size={.3,.2,0},Alpha={.1,.3,1},Life={.45,.85},Speed={.8,2.2},Rate=11,Drag=2.5,Glow=.8},
  {Name='Sparks',Kind='Emit',When='Move',At='Mid',MinDetail=2,Texture=SPARK,Colors={C(244,252,255),C(90,170,255)},Size={.24,.1},Alpha={0,1},Life={.12,.22},Speed={9,15},Rate=12,Glow=1,Bright=1.6,Orient='VelocityParallel',Squash={2.2}},
  {Name='Burst',Kind='Burst',At='Mid',MinDetail=2,Motion=true,Texture=SPARK,Colors={C(255,255,255),C(80,160,255)},Size={.45,0},Alpha={0,1},Life={.2,.32},Speed={14,20},Count=14,Glow=1,Orient='VelocityParallel',Squash={2}},
 }},
 SolarTrail={Tier=3,Layers={
  {Name='Embers',Kind='Emit',When='Move',At='Mid',MinDetail=1,Texture=SPARK,Colors={C(255,242,176),C(255,140,40),C(200,50,20)},Size={.24,.16,0},Alpha={0,.25,1},Life={.6,1.1},Speed={1,3},Rate=14,Accel=V(0,5,0),Drag=1.5,Glow=1,Bright=1.4},
  {Name='Glints',Kind='Emit',When='Move',At='High',MinDetail=2,Texture=SPARK,Colors={C(255,255,222),C(255,214,90)},Size={.42,0},Alpha={0,1},Life={.25,.45},Speed={.3,1},Rate=7,Spin={-180,180},Glow=1,Bright=1.6},
  {Name='Glow',Kind='Emit',When='Move',At='Mid',MinDetail=2,Texture=FLARE,Colors={C(255,214,110),C(255,130,40)},Size={2.6,3.4},Alpha={.72,1},Life={.18,.28},Speed={0},Rate=9,Glow=1,Locked=true},
  {Name='Burst',Kind='Burst',At='Mid',MinDetail=2,Motion=true,Texture=SPARK,Colors={C(255,250,210),C(255,150,40),C(220,60,20)},Size={.5,.2,0},Alpha={0,.2,1},Life={.3,.5},Speed={10,16},Count=18,Drag=4,Glow=1,Bright=1.6},
 }},
 AuroraTrail={Tier=4,Layers={
  {Name='Motes',Kind='Emit',When='Move',At='Mid',MinDetail=1,Texture=SPARK,Colors={C(150,255,222),C(130,200,255),C(232,150,255)},Size={.3,.2,0},Alpha={0,.3,1},Life={.6,1.1},Speed={.8,2},Rate=12,Spin={-90,90},Drag=2,Glow=1,Bright=1.4},
  {Name='Wisps',Kind='Emit',When='Move',At='High',MinDetail=2,Texture=SMOKE,Colors={C(80,255,200),C(140,140,255),C(255,140,220)},Size={.8,2.2},Alpha={.82,.88,1},Life={.8,1.3},Speed={.3,.8},Rate=5,Accel=V(0,1.6,0),Spin={-20,20},Glow=1},
  {Name='Glow',Kind='Emit',When='Move',At='Mid',MinDetail=2,Texture=FLARE,Colors={C(110,255,214),C(150,140,255),C(255,140,220)},Size={2.4,3.2},Alpha={.76,1},Life={.2,.3},Speed={0},Rate=7,Glow=1,Locked=true},
  {Name='Veil',Kind='Ribbon',Mode='Veil',MinDetail=2,Palette='AuroraTrail',Cycle=.22,Alpha={.5,.68,1},Width={1,.75,0},Glow=1,Life=.9},
  {Name='Shimmer',Kind='Shift',MinDetail=3,Motion=true,Speed=.12},
  {Name='Burst',Kind='Burst',At='Mid',MinDetail=2,Motion=true,Texture=SPARK,Colors={C(150,255,222),C(130,200,255),C(255,140,220)},Size={.5,.2,0},Alpha={0,.2,1},Life={.4,.65},Speed={8,12},Count=16,Drag=3,Spin={-180,180},Glow=1,Bright=1.6},
  {Name='HaloMotes',Kind='Emit',When='Always',At='HaloC',Head=true,MinDetail=3,Texture=SPARK,Colors={C(170,255,226),C(140,200,255),C(240,160,255)},Size={0,.16,0},Alpha={0,.2,1},Life={.6,1},Speed={.5,.8},Rate=5,Drag=1.5,Accel=V(0,.4,0),Spin={-90,90},Glow=1,Bright=1.6,Locked=true},
 }},
 NebulaTrail={Tier=5,Layers={
  {Name='Stardust',Kind='Emit',When='Move',At='Mid',MinDetail=1,Texture=SPARK,Colors={C(255,255,255),C(190,160,255),C(110,200,255)},Size={.16,.1,0},Alpha={0,.2,1},Life={.9,1.6},Speed={.5,1.6},Rate=22,Drag=1.2,Glow=1,Bright=1.5},
  {Name='Stars',Kind='Emit',When='Move',At='High',MinDetail=2,Texture=SPARK,Colors={C(255,242,255),C(255,140,240)},Size={0,.6,0},Alpha={0,0,1},Life={.5,.9},Speed={.2,.6},Rate=4,Spin={-120,120},Glow=1,Bright=2.2},
  {Name='Cloud',Kind='Emit',When='Move',At='Mid',MinDetail=2,Texture=SMOKE,Colors={C(140,60,255),C(80,140,255),C(40,20,120)},Size={1,2.8},Alpha={.78,.86,1},Life={.9,1.5},Speed={.2,.6},Rate=6,Spin={-20,20},Glow=1},
  {Name='Swirl',Kind='Ribbon',Mode='Helix',MinDetail=2,Radius=1,Speed=5.2,Phase=0,Gap=.3,Colors={C(255,206,255),C(150,90,255),C(90,210,255)},Alpha={.2,.45,1},Width={1,.7,0},Glow=1,Life=.7},
  {Name='Pulse',Kind='Shift',MinDetail=3,Motion=true,Speed=.1},
  {Name='Light',Kind='Light',At='Mid',MinDetail=3,LocalOnly=true,Color=C(170,110,255),Brightness=.9,Range=9},
  {Name='Burst',Kind='Burst',At='Mid',MinDetail=2,Motion=true,Texture=SPARK,Colors={C(255,255,255),C(200,140,255),C(100,200,255)},Size={.5,.2,0},Alpha={0,.2,1},Life={.4,.7},Speed={10,16},Count=22,Drag=3,Glow=1,Bright=2},
  {Name='Idle',Kind='Emit',When='Idle',At='Mid',MinDetail=3,Texture=SPARK,Colors={C(255,255,255),C(180,140,255)},Size={0,.32,0},Alpha={0,.1,1},Life={1,1.6},Speed={.3,.6},Rate=5,Spin={-60,60},Glow=1,Bright=1.8,Locked=true},
  {Name='HeadDust',Kind='Emit',When='Always',At='Dust1',Head=true,MinDetail=3,Texture=SPARK,Colors={C(240,228,255),C(170,110,255),C(96,176,255)},Size={.12,.08,0},Alpha={0,.25,1},Life={1,1.6},Speed={.05,.2},Rate=14,Drag=1,Spin={-60,60},Glow=1,Bright=1.6,Locked=true},
  {Name='HeadStars',Kind='Emit',When='Always',At='Dust2',Head=true,MinDetail=3,Texture=SPARK,Colors={C(255,246,255),C(200,170,255)},Size={0,.26,0},Alpha={0,0,1},Life={.5,.9},Speed={.1,.3},Rate=3,Drag=1,Spin={-90,90},Glow=1,Bright=2.2,Locked=true},
 }},
 RoyalTrail={Tier=6,Layers={
  {Name='Glitter',Kind='Emit',When='Move',At='Mid',MinDetail=1,Texture=SPARK,Colors={C(255,252,222),C(255,214,80),C(230,160,30)},Size={.2,.12,0},Alpha={0,.15,1},Life={.7,1.2},Speed={.6,2},Rate=26,Accel=V(0,-4,0),Drag=1,Spin={-200,200},Glow=1,Bright=2},
  {Name='Jewels',Kind='Emit',When='Move',At='High',MinDetail=2,Texture=FLARE,Colors={C(206,96,255),C(255,80,170),C(120,60,255)},Size={.45,.3,0},Alpha={0,.2,1},Life={.5,.8},Speed={.5,1.4},Rate=5,Accel=V(0,-2,0),Spin={0,0},Squash={1.6},Glow=1,Bright=1.8},
  {Name='GoldHelix',Kind='Ribbon',Mode='Helix',MinDetail=2,Radius=1.05,Speed=4.4,Phase=0,Gap=.26,Colors={C(255,250,212),C(255,206,64),C(220,150,20)},Alpha={.1,.35,1},Width={1,.75,0},Glow=1,Life=.8},
  {Name='PurpleHelix',Kind='Ribbon',Mode='Helix',MinDetail=2,Radius=1.05,Speed=4.4,Phase=math.pi,Gap=.26,Colors={C(232,172,255),C(150,60,230),C(90,30,170)},Alpha={.15,.4,1},Width={1,.75,0},Glow=.9,Life=.8},
  {Name='Sheen',Kind='Shift',MinDetail=3,Motion=true,Speed=.45},
  {Name='Crown',Kind='Pulse',At=TIPS,Head=true,MinDetail=3,Every=.9,IdleEvery=1.6,OnBurst=true,Count=1,Texture=SPARK,Colors={C(255,250,214),C(255,206,64)},Jewel={C(255,190,255),C(170,60,255)},Size={0,.75,0},Alpha={0,0,1},Life={.45,.6},Speed={0},Glow=1,Bright=2.5,Locked=true},
  {Name='Steps',Kind='Pulse',At={'FootL','FootR'},MinDetail=3,Stride=true,Ground=true,Count=3,Texture=SPARK,Colors={C(255,252,222),C(255,200,60)},Size={.35,0},Alpha={0,1},Life={.25,.4},Speed={1,2.5},Spread=50,Glow=1,Bright=2},
  {Name='Glow',Kind='Emit',When='Move',At='Mid',MinDetail=2,Texture=FLARE,Colors={C(255,226,140),C(190,90,255)},Size={3,3.8},Alpha={.7,1},Life={.2,.3},Speed={0},Rate=9,Glow=1,Locked=true},
  {Name='Light',Kind='Light',At='Mid',MinDetail=3,LocalOnly=true,Color=C(255,200,120),Brightness=1,Range=10},
  {Name='Burst',Kind='Burst',At='Mid',MinDetail=2,Motion=true,Texture=SPARK,Colors={C(255,255,230),C(255,200,60),C(170,70,255)},Size={.6,.25,0},Alpha={0,.2,1},Life={.45,.75},Speed={12,18},Count=30,Drag=3,Spin={-180,180},Glow=1,Bright=2.2},
  {Name='Idle',Kind='Emit',When='Idle',At='CrownTop',Head=true,MinDetail=3,Texture=SPARK,Colors={C(255,250,214),C(255,200,60)},Size={.22,.12,0},Alpha={0,.15,1},Life={1,1.5},Speed={.2,.5},Rate=6,Accel=V(0,-1.6,0),Spin={-120,120},Glow=1,Bright=1.8},
 }},
}
function F.LayerCount(id)local s=F.Specs[id];return s and #s.Layers or 0 end
function F.HasHeadPiece(id)return Art.HeadKind(id)~=nil end
-- Budget ------------------------------------------------------------------------------------------------------------
-- quality: ClientFxBudget tier (1 = low / FastMode). graphics: Roblox graphics level 1-10 (optional).
-- Heads: how many other runners may show a head piece (near/on-screen ones only); the local runner always does.
function F.Budget(quality,reduced,graphics)
 local tier=math.clamp(math.floor(tonumber(quality)or 3),1,3)
 if type(graphics)=='number'and graphics>=1 then if graphics<=3 then tier=1 elseif graphics<=6 then tier=math.min(tier,2)end end
 local b
 if tier==1 then b={Tier=1,Characters=1,Full=0,Near=0,Range=0,Rate=.4,MaxDetail=1,Scale=.5,Heads=0}
 elseif tier==2 then b={Tier=2,Characters=4,Full=1,Near=40,Range=90,Rate=.6,MaxDetail=3,Scale=.75,Heads=2}
 else b={Tier=3,Characters=8,Full=3,Near=60,Range=140,Rate=1,MaxDetail=3,Scale=1,Heads=5}end
 b.Reduced=reduced==true;b.Motion=not b.Reduced
 if b.Reduced then b.MaxDetail=math.min(b.MaxDetail,2);b.Rate*=.5;b.Scale*=.5 end
 return b
end
-- 3 = every layer, 2 = no crown/steps/idle/shimmer/light, 1 = motes only, 0 = parked (off-screen or too far).
function F.Detail(isLocal,distance,onScreen,rank,b)
 if isLocal then return b.MaxDetail end
 if not onScreen or distance>b.Range then return 0 end
 if rank<=b.Full and distance<=b.Near then return math.min(3,b.MaxDetail)end
 if distance<=b.Near*1.75 then return math.min(2,b.MaxDetail)end
 return 1
end
local DETAIL_RATE={[1]=.45,[2]=.7,[3]=1}
-- Geometry (root space). lo/hi: the body range the server stored on the cosmetics folder.
function F.Points(rootSize,lo,hi)
 local scale=math.clamp(rootSize.Y/2,.5,3);local back=rootSize.Z*.5+.10*scale;local mid=(lo+hi)/2
 local p={Mid=V(0,mid,back+.05),High=V(0,hi-.2*scale,back+.1),Low=V(0,lo+.3*scale,back+.1),
  FootL=V(-.45*scale,lo+.05,0),FootR=V(.45*scale,lo+.05,0),CrownC=V(0,hi+.42*scale,0),
  Swirl=V(0,mid,back+.35*scale),VeilTop=V(0,hi+.95*scale,back+.3*scale),VeilBottom=V(0,mid+.2*scale,back+.3*scale),Scale=scale}
 return p
end
-- Instances ------------------------------------------------------------------------------------------------------------
local function seq(t)
 if #t>=3 then return NumberSequence.new({NumberSequenceKeypoint.new(0,t[1]),NumberSequenceKeypoint.new(.5,t[2]),NumberSequenceKeypoint.new(1,t[3])})end
 return NumberSequence.new({NumberSequenceKeypoint.new(0,t[1]),NumberSequenceKeypoint.new(1,t[2]or t[1])})
end
local function colors(list)
 if #list==1 then return ColorSequence.new(list[1])end
 local keys={};for i,c in ipairs(list)do table.insert(keys,ColorSequenceKeypoint.new((i-1)/(#list-1),c))end
 return ColorSequence.new(keys)
end
local function range(t)return NumberRange.new(t[1],t[2]or t[1])end
local function emitter(spec,list)
 local e=Instance.new('ParticleEmitter');e.Name=F.Prefix..spec.Name;e.Texture=spec.Texture
 e.Color=colors(list or spec.Colors);e.Size=seq(spec.Size);e.Transparency=seq(spec.Alpha or{0,1})
 e.Lifetime=range(spec.Life);e.Speed=range(spec.Speed or{0});local spread=spec.Spread or 180;e.SpreadAngle=Vector2.new(spread,spread)
 e.Acceleration=spec.Accel or Vector3.zero;e.Drag=spec.Drag or 0;e.LightEmission=spec.Glow or 0;e.LightInfluence=0
 local spin=spec.Spin;e.Rotation=spin and spin[1]==0 and spin[2]==0 and NumberRange.new(0,0)or NumberRange.new(0,360);e.RotSpeed=range(spin or{-40,40})
 e.LockedToPart=spec.Locked==true;e.VelocityInheritance=0;e.EmissionDirection=Enum.NormalId.Top
 if spec.Orient=='VelocityParallel'then e.Orientation=Enum.ParticleOrientation.VelocityParallel end
 if spec.Squash then e.Squash=seq(spec.Squash)end
 if spec.Bright then pcall(function()e.Brightness=spec.Bright end)end
 e.Rate=0;e.Enabled=false;return e
end
local function newAttachment(name,parentAtt)
 local a=Instance.new('Attachment');a.Name=F.Prefix..name;if parentAtt then a.Parent=parentAtt end;return a
end
function F.new()
 return setmetatable({Records={},Free={},Pool=0,PoolMax=1,Built=0,PiecesBuilt=0,Budget=F.Budget(3,false),Clock=0},F)
end
function F:_build(id)
 local spec=F.Specs[id];local rig={Id=id,Spec=spec,Atts={},Layers={},All={},HeadKeys={},Home={}}
 local function att(key)
  local a=rig.Atts[key];if not a then a=newAttachment(key);rig.Atts[key]=a;table.insert(rig.All,a)end;return a
 end
 for _,layer in ipairs(spec.Layers)do
  local L={Spec=layer,Emitters={},Next=0,Side=0}
  if layer.Head then for _,key in ipairs(type(layer.At)=='table'and layer.At or{layer.At})do rig.HeadKeys[key]=true end end
  if layer.Kind=='Emit'or layer.Kind=='Burst'then
   local e=emitter(layer);e.Parent=att(layer.At);table.insert(L.Emitters,e)
  elseif layer.Kind=='Pulse'then
   for i,key in ipairs(layer.At)do local e=emitter(layer,i==1 and layer.Jewel or nil);e.Parent=att(key);table.insert(L.Emitters,e)end
  elseif layer.Kind=='Ribbon'then
   local a0,a1=att(layer.Name..'0'),att(layer.Name..'1')
   local t=Instance.new('Trail');t.Name=F.Prefix..layer.Name;t.Attachment0=a0;t.Attachment1=a1;t.FaceCamera=true;t.Texture=''
   local list=layer.Colors or Art.Look(layer.Palette).Colors
   t.Color=colors(layer.Colors or{list[1],list[3],list[5]or list[#list]});t.Transparency=seq(layer.Alpha);t.WidthScale=seq(layer.Width or{1,0})
   t.LightEmission=layer.Glow or 1;t.LightInfluence=0;t.MinLength=.06;t.MaxLength=48;t.Lifetime=.8;t.Enabled=false;t.Parent=a0
   L.Trail=t;L.A0=a0;L.A1=a1
  elseif layer.Kind=='Light'then
   local l=Instance.new('PointLight');l.Name=F.Prefix..layer.Name;l.Color=layer.Color;l.Brightness=layer.Brightness;l.Range=layer.Range;l.Shadows=false;l.Enabled=false;l.Parent=att(layer.At)
   L.Light=l
  end
  table.insert(rig.Layers,L)
 end
 self.Built+=1
 return rig
end
function F:_destroyRig(rig)
 for _,a in ipairs(rig.All)do pcall(function()a:Destroy()end)end
 rig.All={};rig.Dead=true
end
-- Moves a pooled rig onto a root (and its Head layers onto the head). Returns false if Roblox refuses the reparent
-- (destroyed instances). Without a head, head attachments wait on the root above the body (their layers stay off).
function F:_attach(rig,root,lo,hi,head)
 local p=F.Points(root.Size,lo,hi);rig.Points=p;rig.Root=root;rig.Head=head;rig.Home={}
 local piece=head and Art.HeadPiece(rig.Id,Art.HeadSize(head))
 rig.HeadPoints=piece and piece.Points;rig.Orbits=piece and piece.Orbits or{}
 for key,a in pairs(rig.Atts)do
  local pos=p[key];rig.Home[a]=root
  if rig.HeadKeys[key]then
   pos=rig.HeadPoints and rig.HeadPoints[key];if pos then rig.Home[a]=head else pos=p.CrownC end
  elseif not pos then
   local base=key:sub(-1);local name=key:sub(1,-2)
   for _,L in ipairs(rig.Layers)do if L.Spec.Name==name then pos=self:_ribbonPoint(L,p,base=='0'and -1 or 1,0,false)end end
  end
  a.Position=pos or p.Mid
 end
 local ok=pcall(function()for _,a in ipairs(rig.All)do a.Parent=rig.Home[a]end end)
 return ok
end
function F:_ribbonPoint(L,p,side,now,animate)
 local s=L.Spec;local scale=p.Scale
 if s.Mode=='Veil'then
  local sway=animate and math.sin(now*1.7)*.3*scale or 0
  return side<0 and p.VeilTop+V(sway,0,0)or p.VeilBottom+V(sway*.4,0,0)
 end
 local angle=(animate and now*s.Speed or 0)+s.Phase+math.pi/2
 local dir=V(math.cos(angle),math.sin(angle),0);local r=s.Radius*scale;local half=(s.Gap or .3)*scale/2
 return p.Swirl+dir*(r+side*half)
end
function F:_park(rig,clear)
 for _,L in ipairs(rig.Layers)do
  for _,e in ipairs(L.Emitters)do if e.Enabled then e.Enabled=false end;if clear then pcall(function()e:Clear()end)end end
  if L.Trail then L.Trail.Enabled=false;if clear then pcall(function()L.Trail:Clear()end)end end
  if L.Light then L.Light.Enabled=false end
  L.Rate=nil;L.On=nil
 end
end
function F:_acquire(id)
 local list=self.Free[id]
 if list and #list>0 then local rig=table.remove(list);self.Pool-=1;return rig end
 return self:_build(id)
end
function F:_recycle(rig)
 self:_park(rig,true)
 -- A respawn may already have destroyed the old root (and our attachments with it): never pool those.
 local ok=not rig.Dead
 if ok then for _,a in ipairs(rig.All)do if a.Parent==nil or a.Parent~=rig.Home[a]then ok=false;break end end end
 ok=ok and pcall(function()for _,a in ipairs(rig.All)do a.Parent=nil end end)
 rig.Root=nil;rig.Head=nil;rig.Home={}
 if not ok or self.Pool>=self.PoolMax*#Art.Order then self:_destroyRig(rig);return end
 local list=self.Free[rig.Id]or{};self.Free[rig.Id]=list
 if #list>=self.PoolMax then self:_destroyRig(rig);return end
 table.insert(list,rig);self.Pool+=1
end
-- Head pieces ----------------------------------------------------------------------------------------------------------
-- One Model under the Head: invisible pivot parts welded to the Head (one per ring), visible parts welded to a pivot.
local function piecePart(name,size,color,material,alpha)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Material=material;p.Transparency=alpha or 0
 p.Anchored=false;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Massless=true
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 pcall(function()p.EnableFluidForces=false end)
 return p
end
local function weld(part0,part1,c0)
 local w=Instance.new('Weld');w.Name=F.Prefix..'Weld';w.Part0=part0;w.Part1=part1;w.C0=c0;w.Parent=part1;return w
end
function F:_buildPiece(id,head,simple)
 local w,h=Art.HeadSize(head);local spec=Art.HeadPiece(id,w,h,simple);if not spec then return nil end
 local model=Instance.new('Model');model.Name=F.Prefix..'HeadPiece'
 local piece={Id=id,Spec=spec,Simple=simple,Model=model,Head=head,Size=head.Size,Parts={},Pivots={},Shimmer={},LTM=-1,Animated=false}
 local base=head.CFrame
 for i,ring in ipairs(spec.Rings)do
  local pv=piecePart(F.Prefix..'Pivot',V(.05,.05,.05),C(255,255,255),Enum.Material.SmoothPlastic,1)
  local c0=CFrame.new(0,ring.Y,0);pv.CFrame=base*c0;pv.Parent=model
  piece.Pivots[i]={Part=pv,Weld=weld(head,pv,c0),Base=c0,Y=ring.Y,Speed=ring.Speed or 0,Bob=ring.Bob}
 end
 for _,sp in ipairs(spec.Parts)do
  local pv=piece.Pivots[sp.Ring]or piece.Pivots[1]
  local part=piecePart(sp.Name,sp.Size,sp.Color,sp.Material,sp.Transparency);if sp.Reflectance then part.Reflectance=sp.Reflectance end
  part.CFrame=pv.Part.CFrame*sp.Offset;part.Parent=model;weld(pv.Part,part,sp.Offset)
  table.insert(piece.Parts,part)
  if sp.Shimmer then table.insert(piece.Shimmer,{Part=part,Kind=sp.Shimmer.Kind,T=sp.Shimmer.T,Color=sp.Color,Alpha=sp.Transparency or 0})end
 end
 local ok=pcall(function()model.Parent=head end)
 if not ok then pcall(function()model:Destroy()end);return nil end
 self.PiecesBuilt+=1
 return piece
end
local function dropPiece(rec)
 local pc=rec.Piece;if not pc then return end
 rec.Piece=nil;rec.HeadHidden=false;pcall(function()pc.Model:Destroy()end)
end
-- want: show a head piece; simple: the low-quality version. An unwanted piece is stashed (unparented) for a moment
-- so runners hovering at a budget edge do not rebuild it every scan, then destroyed.
function F:_piece(rec,want,simple)
 local pc=rec.Piece
 -- Rebuilt when the quality version or the head changes (respawn, avatar rescale) or Roblox removed the model.
 if pc and(pc.Simple~=simple or pc.Head~=rec.Head or(rec.Head and pc.Size~=rec.Head.Size)or(not pc.Stashed and pc.Model.Parent~=rec.Head))then dropPiece(rec);pc=nil end
 if want then
  if not pc then rec.Piece=self:_buildPiece(rec.Id,rec.Head,simple)
  elseif pc.Stashed then if pcall(function()pc.Model.Parent=rec.Head end)then pc.Stashed=nil else dropPiece(rec)end end
 elseif pc then
  if not pc.Stashed then pc.Stashed=self.Clock;rec.HeadHidden=false;pcall(function()pc.Model.Parent=nil end)
  elseif self.Clock-pc.Stashed>=1.5 then dropPiece(rec)end
 end
end
-- First person: the camera fades the Head through LocalTransparencyModifier; the head piece copies it.
local function syncPiece(rec)
 local pc=rec.Piece;if not pc or pc.Stashed then rec.HeadHidden=false;return end
 local head=rec.Head;local l=head and head.Parent and tonumber(head.LocalTransparencyModifier)or 0
 if l~=pc.LTM then pc.LTM=l;for _,p in ipairs(pc.Parts)do p.LocalTransparencyModifier=l end end
 rec.HeadHidden=l>=.5
end
F.SyncPiece=syncPiece
local SHEEN=Art.HeadColors.Sheen
local function shimmerAt(pc,now)
 for _,sh in ipairs(pc.Shimmer)do
  if sh.Kind=='Gold'then
   local d=math.abs((sh.T-now*.32+.5)%1-.5);local w=math.max(0,1-d/.14)
   sh.Part.Color=sh.Color:Lerp(SHEEN,w*.85)
  elseif sh.Kind=='Cycle'then
   sh.Part.Color=Art.Cycle(Art.Looks.AuroraTrail.Colors,sh.T+now*.09)
  elseif sh.Kind=='Twinkle'then
   local k=math.max(0,math.sin(now*2.6+sh.T*6.283))^6;sh.Part.Transparency=sh.Alpha+(1-sh.Alpha)*.8*k
  end
 end
end
local function settlePiece(pc)
 if not pc.Animated then return end;pc.Animated=false
 for _,pv in ipairs(pc.Pivots)do pv.Weld.C0=pv.Base end
 for _,sh in ipairs(pc.Shimmer)do sh.Part.Color=sh.Color;sh.Part.Transparency=sh.Alpha end
end
-- Orbiting/bobbing rings, crown sheen, halo colour flow, star twinkle and the orbiting dust emitters.
function F:_animatePiece(rec,now)
 local pc=rec.Piece;local t=now+rec.Phase*3;pc.Animated=true
 for _,pv in ipairs(pc.Pivots)do
  if pv.Speed~=0 or pv.Bob then pv.Weld.C0=CFrame.new(0,pv.Y+(pv.Bob and math.sin(t*1.8)*pv.Bob or 0),0)*CFrame.Angles(0,t*pv.Speed,0)end
 end
 local rig=rec.Rig
 if rig and rig.Head==rec.Head then
  for _,o in ipairs(rig.Orbits or{})do
   local a=rig.Atts[o.Key]
   if a and a.Parent==rec.Head then local q=o.Phase+t*o.Speed;a.Position=o.Center+V(math.sin(q)*o.Radius,math.sin(q*1.7)*o.Lift,-math.cos(q)*o.Radius)end
  end
 end
 shimmerAt(pc,t) -- (R153: every frame, was 12.5 Hz: the crown's sheen and the halo's colour flow moved in steps)
end
local function restoreShift(rec)
 if not rec.Shifted then return end;rec.Shifted=false
 for _,t in ipairs(rec.Body)do if t.Parent then local layer=t:GetAttribute('TrailLayer117')or(t.Name:sub(-1)=='2'and 2 or 1);t.Color=Art.Sequence(rec.Id,layer,0)end end
end
function F:Release(player)
 local rec=self.Records[player];if not rec then return end
 self.Records[player]=nil;restoreShift(rec);dropPiece(rec)
 if rec.Rig then self:_recycle(rec.Rig);rec.Rig=nil end
end
local function bodyTrails(folder)
 local out={};for _,t in ipairs(folder:GetChildren())do if t:IsA('Trail')and t:GetAttribute('RunnerMovementTrail')then table.insert(out,t)end end;return out
end
-- Scan: pick runners, assign detail, bind/rebind/release rigs. Cheap; the client runs it ~4x a second.
function F:Scan(players,localPlayer,camera,budget)
 self.Budget=budget
 local eye=camera and camera.CFrame.Position;local candidates={}
 for _,player in ipairs(players)do
  local character=player.Character;local folder=character and character:FindFirstChild('ChestChaseCosmetics')
  local root=character and character:FindFirstChild('HumanoidRootPart');local id=folder and folder:GetAttribute('TrailId84')
  if root and id and F.Specs[id]then
   local isLocal=player==localPlayer;local distance=isLocal and -1 or(eye and(root.Position-eye).Magnitude or math.huge)
   local head=character:FindFirstChild('Head');if head and not head:IsA('BasePart')then head=nil end
   if isLocal or distance<=budget.Range then table.insert(candidates,{Player=player,Character=character,Folder=folder,Root=root,Head=head,Id=id,Distance=distance,Local=isLocal})end
  end
 end
 table.sort(candidates,function(a,b)return a.Distance<b.Distance end)
 local wanted={};local rank=0;local heads=0
 for i=1,math.min(budget.Characters,#candidates)do
  local c=candidates[i];local onScreen=true
  if not c.Local then
   rank+=1
   if camera then local ok,_,visible=pcall(function()return camera:WorldToViewportPoint(c.Root.Position)end);onScreen=not ok or visible==true end
  end
  local detail=F.Detail(c.Local,c.Distance,onScreen,rank,budget)
  local rec=self.Records[c.Player]
  if rec and(rec.Character~=c.Character or rec.Folder~=c.Folder or rec.Id~=c.Id or rec.Root~=c.Root or rec.Head~=c.Head or(c.Head and rec.HeadSize~=c.Head.Size))then self:Release(c.Player);rec=nil end
  if not rec then
   rec={Player=c.Player,Character=c.Character,Folder=c.Folder,Root=c.Root,Head=c.Head,HeadSize=c.Head and c.Head.Size,Id=c.Id,Local=c.Local,Still=0,Moving=false,LastBurst=-math.huge,Logic=0,ShiftAt=0,Phase=math.random(),Shifted=false,Body={}}
   self.Records[c.Player]=rec
  end
  rec.Body=bodyTrails(c.Folder);rec.Humanoid=c.Character:FindFirstChildOfClass('Humanoid')
  if detail>0 and not rec.Rig then
   local rig=self:_acquire(c.Id)
   local lo=tonumber(c.Folder:GetAttribute('TrailLow84'));local hi=tonumber(c.Folder:GetAttribute('TrailHigh84'))
   if not lo or not hi then lo,hi=Art.BodyRange(c.Character,c.Root)end
   if self:_attach(rig,c.Root,lo,hi,c.Head)then rec.Rig=rig else self:_destroyRig(rig)end
  end
  -- Head piece: always for the local runner (simplified on low quality), for others only near/on-screen, capped.
  local wantPiece=c.Head~=nil and F.HasHeadPiece(c.Id)and(c.Local or(detail>=2 and heads<(budget.Heads or 0)))
  if wantPiece and not c.Local then heads+=1 end
  self:_piece(rec,wantPiece,detail<=1)
  if detail==0 and rec.Rig and rec.Detail~=0 then self:_park(rec.Rig,false);restoreShift(rec)end
  if detail<3 then restoreShift(rec)end
  rec.Detail=detail;wanted[c.Player]=true
 end
 for player in pairs(self.Records)do if not wanted[player]then self:Release(player)end end
end
local function moving(rec,speed)
 local h=rec.Humanoid;if not h or h.Health<=0 or h.Sit or h.PlatformStand then return false,false end
 if rec.Character:GetAttribute('ChestChaseRagdollActive')==true then return false,false end
 return speed>3.5,true
end
function F:_layerOn(rec,L)
 local s,b=L.Spec,self.Budget
 if rec.Detail<(s.MinDetail or 1)then return false end
 if s.LocalOnly and not rec.Local then return false end
 if s.Motion and not b.Motion then return false end
 if s.Head and(not rec.Piece or rec.Piece.Stashed or rec.HeadHidden or rec.Rig.Head~=rec.Head)then return false end
 return true
end
local function setRate(L,e,rate)
 if not L.Rate or math.abs(L.Rate-rate)>math.max(.5,L.Rate*.08)then L.Rate=rate;e.Rate=rate end
end
-- Per-runner logic at ~20 Hz.
function F:_logic(rec,dt,now)
 local rig=rec.Rig;local root=rec.Root;local b=self.Budget
 if not root.Parent or not rec.Folder.Parent then self:_park(rig,true);return end
 local v=root.AssemblyLinearVelocity or Vector3.zero;local speed=V(v.X,0,v.Z).Magnitude
 local pos=root.Position;local jump=rec.LastPos and(pos-rec.LastPos).Magnitude or 0;rec.LastPos=pos
 local discontinuous=dt>.3 or jump>math.max(18,speed*dt*2+7)
 local training=rec.Player:GetAttribute('TreadmillTraining')==true
 local run,alive=moving(rec,speed);run=run and not training and not discontinuous
 local grounded=rec.Humanoid and rec.Humanoid.FloorMaterial~=Enum.Material.Air
 local still=alive and not run and(training or(speed<1.5 and grounded))
 rec.Still=still and rec.Still+dt or 0
 if rec.Still>=.4 then rec.StillAt=now end
 local idle=rec.Still>=.6
 -- A start burst: running again within a moment of having stood still (ramps through walking speed are fine).
 local started=run and not rec.Moving and now-(rec.StillAt or -math.huge)<=.35 and now-rec.LastBurst>=1.5
 rec.Moving=run
 if discontinuous then for _,L in ipairs(rig.Layers)do if L.Trail then L.Trail.Enabled=false;pcall(function()L.Trail:Clear()end)end end end
 local speedRate=math.clamp(speed/30,.7,2.2);local detailRate=DETAIL_RATE[rec.Detail]or .45
 if started then rec.LastBurst=now end
 for _,L in ipairs(rig.Layers)do
  local s=L.Spec;local on=self:_layerOn(rec,L)
  if s.Kind=='Emit'then
   local active=on and((s.When=='Move'and run)or(s.When=='Idle'and idle)or(s.When=='Always'and alive))
   local e=L.Emitters[1]
   if active then setRate(L,e,s.Rate*b.Rate*detailRate*(s.When=='Move'and speedRate or 1))end
   if e.Enabled~=active then e.Enabled=active end
  elseif s.Kind=='Burst'then
   if on and started then L.Emitters[1]:Emit(math.max(1,math.floor(s.Count*b.Scale+.5)))end
  elseif s.Kind=='Pulse'then
   if on and started and s.OnBurst then for _,e in ipairs(L.Emitters)do e:Emit(s.Count+1)end;L.Next=now+(s.Every or .5)end
   local due=on and now>=L.Next
   if due and s.Stride then
    if run and grounded then
     L.Side=L.Side%#L.Emitters+1;L.Emitters[L.Side]:Emit(s.Count);L.Next=now+math.clamp(3.2/math.max(speed,1),.14,.4)
    end
   elseif due and(run or(idle and s.IdleEvery))then
    for _,e in ipairs(L.Emitters)do e:Emit(s.Count)end;L.Next=now+(run and s.Every or s.IdleEvery)
   end
  elseif s.Kind=='Ribbon'then
   local active=on and run
   if active then local life=math.clamp(48/math.max(1,speed),.045,1.8)*(s.Life or .8);if not L.Life or math.abs(L.Life-life)>.02 then L.Life=life;L.Trail.Lifetime=life end end
   if L.Trail.Enabled~=active then L.Trail.Enabled=active end
  elseif s.Kind=='Light'then
   local active=on and(run or idle)
   if L.Light.Enabled~=active then L.Light.Enabled=active end
  end
 end
end
-- Per-frame motion (swirls, veil sway, colour shimmer). Only full-detail rigs with motion allowed.
-- R153 (owner: "fix all jittery type effects"): the veil's palette flow and the main ribbon's sheen / pulse are written every frame (were 10 Hz:
-- the sheen visibly stepped along the ribbon); only full-detail rigs (the local runner and near, on-screen ones) run this.
function F:_animate(rec,now)
 local rig=rec.Rig;local b=self.Budget
 if rec.Detail<3 or not b.Motion then return end
 for _,L in ipairs(rig.Layers)do
  local s=L.Spec
  if s.Kind=='Ribbon'and L.Trail.Enabled then
   L.A0.Position=self:_ribbonPoint(L,rig.Points,-1,now+rec.Phase*3,true);L.A1.Position=self:_ribbonPoint(L,rig.Points,1,now+rec.Phase*3,true)
   if s.Cycle then
    local look=Art.Look(s.Palette);local keys={};local phase=(now*s.Cycle+rec.Phase)%1
    for i=0,4 do keys[#keys+1]=ColorSequenceKeypoint.new(i/4,Art.Sample(look.Colors,i/4,phase))end
    L.Trail.Color=ColorSequence.new(keys)
   end
  elseif s.Kind=='Shift'and(rec.Moving or rec.Still>=.6)then
   rec.Shifted=true;local phase=(now*s.Speed+rec.Phase)%1
   for _,t in ipairs(rec.Body)do if t.Parent then local layer=t:GetAttribute('TrailLayer117')or(t.Name:sub(-1)=='2'and 2 or 1);t.Color=Art.Sequence(rec.Id,layer,phase)end end
  end
 end
end
function F:Step(dt,now)
 self.Clock+=dt
 for _,rec in pairs(self.Records)do
  local pc=rec.Piece
  if pc and not pc.Stashed then
   syncPiece(rec)
   if rec.Detail>=3 and self.Budget.Motion and not rec.HeadHidden and rec.Head.Parent then self:_animatePiece(rec,now)else settlePiece(pc)end
  end
  if rec.Rig and rec.Detail>0 then
   rec.Logic+=dt
   local every=rec.Detail>=2 and .05 or .1
   if rec.Logic>=every then local step=rec.Logic;rec.Logic=0;self:_logic(rec,step,now)end
   if rec.Root.Parent then self:_animate(rec,now)end
  end
 end
end
function F:Stats()
 local s={Records=0,Rigs=0,Pooled=self.Pool,Emitting=0,Ribbons=0,Lights=0,Built=self.Built,Pieces=0,PieceParts=0}
 for _,rec in pairs(self.Records)do
  s.Records+=1
  if rec.Piece and not rec.Piece.Stashed then s.Pieces+=1;s.PieceParts+=#rec.Piece.Parts end
  if rec.Rig then s.Rigs+=1
   for _,L in ipairs(rec.Rig.Layers)do
    for _,e in ipairs(L.Emitters)do if e.Enabled then s.Emitting+=1 end end
    if L.Trail and L.Trail.Enabled then s.Ribbons+=1 end;if L.Light and L.Light.Enabled then s.Lights+=1 end
   end
  end
 end
 return s
end
function F:Destroy()
 for player in pairs(self.Records)do self:Release(player)end
 for _,list in pairs(self.Free)do for _,rig in ipairs(list)do self:_destroyRig(rig)end end
 self.Free={};self.Pool=0
end
return F
