-- R153 (owner picked look B "Circuit Mech", docs/proposals/R153/mech_pack.md): the Limited Mech Pack is a gunmetal chip-bag pouch with a riveted steel frame,
-- cyan circuit traces running out of R103's reactor + turbine (a soft pulse runs out along them: MechPulse), 4 hex corner bolts, a hazard-stripe seal, a small
-- antenna with a blinking red LED on the top crimp and a MECH plate, on both faces. It replaces R103's armour panels / pistons on the Forest_01 pouch painted white
-- (the R151 audit: Forest_01's print showed through the white).
--  * The pouch: VerityPouch151's GENERATED flat pouch (every vertex colour white, so the gunmetal is the real colour and no print can survive; Storm_02's
--    1.97 x 2.06 footprint, the same as Forest_01's). The server's one bake serves both packs. While it is not there (a server still baking, a world without
--    EditableMesh) the body is plain parts with exactly the same faces (SachetSpecs), so the design sits the same either way. Never shaped
--    (PackShapes151.Applies excludes the Mech): one look in every context.
--  * Every design part sits ON a flat face or on the part under it, and every face stacked over another stands A.Layer (.046) off it: over .02 even on a .5x
--    pack (the R152 z-fighting rule: tools/zfight.py's near band). The seal and the 8 tear strips stand on the middle of the body's crimps (the flat pouch is
--    centred .047 in front of the root, where the plain pack's strips are not), and the design follows the body where it really is (Build).
--  * Held: a soft cyan hum light and a few sparks from the antenna (one PointLight, one ParticleEmitter, in Attachments on the pack: they follow it with no
--    per-frame writes). Both start off; SeedPackRender switches them on for a pack it details (SpecialPackArt89.CaptureMotion:Live). No orbiting scanner.
local A={Revision=153,TemplateKey='Forest_01',Layer=.046}
local V,CF,RGB,ANG=Vector3.new,CFrame.new,Color3.fromRGB,CFrame.Angles
local PI=math.pi
local Renderer=require(script.Parent.SeedPackRenderer)
-- the flat pouch in the pack's root frame at scale 1 (VerityPouch151.Generate of Storm_02: Size X / Y, DepthShare .56 x Size Z, centred on its PackLocalFrame,
-- which sits on the seal plane z = 0 since the R153 pack-parts fix; the sachet is centred there too. Build follows the pouch part wherever it really is)
A.Pouch={Width=1.97,Height=2.06,Depth=1.004*.56,Center=V(0,-.01,0),Tolerance=.02}
A.Flat={U=.845,V=.68} -- the exactly flat part of each face (EdgeRadius .14 in from the sides; TaperHeight + CrimpHeight in from the ends)
A.Colors={Body=RGB(58,64,74),Steel=RGB(150,160,172),Rivet=RGB(204,211,220),Bolt=RGB(190,198,208),Plate=RGB(30,36,46),Housing=RGB(104,116,130),
 Inset=RGB(20,123,152),Cyan=RGB(34,231,255),Facet=RGB(143,251,255),Silver=RGB(180,197,207),Graphite=RGB(53,66,79),Gold=RGB(242,180,65),
 Hazard=RGB(250,196,32),Stripe=RGB(26,26,30),Mast=RGB(44,52,62),Led=RGB(255,48,48)}
A.Antenna={X=-.7125,Top=1.39} -- on the top crimp between tear strips 1 and 2 (and their stripes): the front's top right; Top = the LED's top (SpecialPackArt89.Bounds)
-- side -1 = the front (-Z, the reactor side the shop camera sees), 1 = the back. In a face's frame +X reads right and +Y up from outside, +Z points out.
function A.FaceFrame(side)
 local P=A.Pouch;local z=P.Center.Z+side*P.Depth/2
 return side<0 and CF(0,P.Center.Y,z)*ANG(0,PI,0)or CF(0,P.Center.Y,z)
end
-- The design at scale 1 in the root's frame: {Name,Size,Frame,Color,Material,Shape?,Motion?,Pivot?,Rate?,Pulse?,Phase?,Glow?,Bolt?,Face?,Tear?,Blink?}.
local specs
function A.Specs()
 if specs then return specs end
 local out={};local C=A.Colors;local M=Enum.Material
 local function add(name,size,frame,color,material,shape)local s={Name=name,Size=size,Frame=frame,Color=color,Material=material or M.SmoothPlastic,Shape=shape};out[#out+1]=s;return s end
 local cyl=ANG(0,PI/2,0) -- a Cylinder runs along its X: this points it out of the face
 local G=A.Layer -- one layer's depth
 for _,side in ipairs({-1,1})do
  local F=A.FaceFrame(side);local tag=side<0 and'F'or'B'
  -- the riveted steel frame (top / bottom bars full width, the sides between them: no two overlap)
  local U0,V0,bw,fd=.80,.64,.075,G
  add('FrameTop'..tag,V(2*U0,bw,fd),F*CF(0,V0-bw/2,fd/2),C.Steel,M.Metal)
  add('FrameBottom'..tag,V(2*U0,bw,fd),F*CF(0,-V0+bw/2,fd/2),C.Steel,M.Metal)
  for _,u in ipairs({-1,1})do
   add('FrameSide'..tag..u,V(bw,2*(V0-bw),fd),F*CF(u*(U0-bw/2),0,fd/2),C.Steel,M.Metal)
   for k,v in ipairs({-.30,.30})do add('Rivet'..tag..u..'_'..k,V(.032,.032,.032),F*CF(u*(U0-bw/2),v,fd),C.Rivet,M.Metal,Enum.PartType.Ball)end
  end
  -- 4 hex corner bolts (three blocks at 0 / 60 / 120 degrees make the hexagon); the opening's clicks 1-4 back them out one by one (MechPackFx153)
  local R,bh=.052,G
  for i,c in ipairs({{-1,1},{1,1},{1,-1},{-1,-1}})do -- top-left, top-right, bottom-right, bottom-left as seen from outside
   local pivot=F*CF(c[1]*(U0-bw/2),c[2]*(V0-bw/2),fd)
   for k=0,2 do local s=add('Bolt'..tag..i..'_'..k,V(R,math.sqrt(3)*R,bh),pivot*ANG(0,0,k*PI/3)*CF(0,0,bh/2),C.Bolt,M.Metal);s.Bolt=i;s.Face=side;s.BoltPivot=pivot end
  end
  -- R103's reactor and turbine, restacked a layer each (housing; inset + outer ring; core + inner ring + gears; facet; the blades, two deep), a little above the middle
  local base=F*CF(0,.03,0)
  add('ReactorHousing'..tag,V(G,.93,.93),base*CF(0,0,G/2)*cyl,C.Housing,M.Metal,Enum.PartType.Cylinder)
  add('ReactorInset'..tag,V(G,.66,.66),base*CF(0,0,G*1.5)*cyl,C.Inset,nil,Enum.PartType.Cylinder)
  local core=add('ReactorCore'..tag,V(G,.49,.49),base*CF(0,0,G*2.5)*cyl,C.Cyan,M.Neon,Enum.PartType.Cylinder);core.Pulse=.10;core.Glow=true
  for ring,radius in ipairs({.43,.31})do for i=1,8 do
   local a,b=(i-1)*PI/4,i*PI/4
   local p,q=V(math.cos(a)*radius,math.sin(a)*radius,0),V(math.cos(b)*radius,math.sin(b)*radius,0);local d=q-p
   local s=add('ReactorEdge'..tag..ring..'_'..i,V(d.Magnitude+.009,ring==1 and .055 or .022,G),base*CF((p+q)*.5+V(0,0,ring==1 and G*1.5 or G*2.5))*ANG(0,0,math.atan2(d.Y,d.X)),
    ring==1 and C.Silver or C.Cyan,ring==1 and M.Metal or M.Neon)
   if ring==2 then s.Glow=true end
  end end
  local function spin(s,pivot,rate)s.Motion='Spin';s.Pivot=pivot;s.Rate=rate;return s end
  local facetPivot=base*CF(0,0,G*3.5)
  spin(add('CoreFacet'..tag,V(.19,.19,G),facetPivot*ANG(0,0,PI/4),C.Facet,M.Neon),facetPivot,PI*2/3)
  local bladePivot=base*CF(0,0,G*4)
  for i=1,8 do local a=(i-1)*PI/4;spin(add('TurbineBlade'..tag..'_'..i,V(.12,.035,2*G),bladePivot*CF(math.cos(a)*.175,math.sin(a)*.175,0)*ANG(0,0,a+.50),i%2==0 and C.Graphite or C.Silver),bladePivot,PI*2/3)end
  local gearPivot=base*CF(0,0,G*2.5)
  for i=1,4 do local a=(i-1)*PI/2;spin(add('CounterGear'..tag..'_'..i,V(.080,.047,G),gearPivot*CF(math.cos(a)*.39,math.sin(a)*.39,0)*ANG(0,0,a),C.Gold,M.Metal),gearPivot,-PI/3)end
  -- cyan circuit traces out of the reactor (each starts just off the housing's rim; the corner square belongs to the second leg: nothing overlaps)
  local tw=.024
  for _,u in ipairs({-1,1})do
   local mid=add('Trace'..tag..u..'_0',V(.69-.47,tw,G),F*CF(u*(.47+.69)/2,.03,G/2),C.Cyan,M.Neon);mid.Pulse=.18;mid.Phase=-1.2;mid.Glow=true
   for n,t in ipairs({{.25,.48},{-.17,-.42}})do
    local v0,v1=t[1],t[2];local dv=v0-.03;local edge=math.sqrt(.465^2-dv*dv)+.005;local corner=.60
    local a=add('Trace'..tag..u..'_'..n..'a',V(corner-tw/2-edge,tw,G),F*CF(u*(edge+corner-tw/2)/2,v0,G/2),C.Cyan,M.Neon);a.Pulse=.18;a.Phase=-1.2;a.Glow=true
    local lo,hi=math.min(v0-tw/2*math.sign(v1-v0),v1),math.max(v0-tw/2*math.sign(v1-v0),v1)
    local b=add('Trace'..tag..u..'_'..n..'b',V(tw,hi-lo,G),F*CF(u*corner,(lo+hi)/2,G/2),C.Cyan,M.Neon);b.Pulse=.18;b.Phase=-2.4;b.Glow=true
   end
  end
  -- the MECH plate under the reactor, its letters in cyan (blocks: a ViewportFrame shows them, a SurfaceGui it would not)
  add('MechPlate'..tag,V(.36,.075,G),F*CF(0,-.50,G/2),C.Plate)
  local lh,st,lw,gap=.045,.011,.055,.022
  local strokes={
   {{-lw/2+st/2,0,st,lh},{lw/2-st/2,0,st,lh},{0,lh/2-st/2,lw-2*st,st},{0,(lh/2-st)/2,st,lh/2-st}}, -- M
   {{-lw/2+st/2,0,st,lh},{st/2,lh/2-st/2,lw-st,st},{st/2-.006,0,lw-st-.012,st},{st/2,-lh/2+st/2,lw-st,st}}, -- E
   {{-lw/2+st/2,0,st,lh},{st/2,lh/2-st/2,lw-st,st},{st/2,-lh/2+st/2,lw-st,st}}, -- C
   {{-lw/2+st/2,0,st,lh},{lw/2-st/2,0,st,lh},{0,0,lw-2*st,st}}} -- H
  for k,letter in ipairs(strokes)do
   local cu=-(4*lw+3*gap)/2+lw/2+(k-1)*(lw+gap)
   for j,s in ipairs(letter)do add('MechLetter'..tag..k..'_'..j,V(s[3],s[4],G),F*CF(cu+s[1],-.50+s[2],G*1.5),C.Cyan,M.Neon)end
  end
 end
 -- the hazard-stripe seal: one black diagonal stripe through each tear strip (it follows its strip open: MechPackFx153) and each eighth of the bottom seal,
 -- standing a layer proud of both their faces (the strips and the seal themselves are painted yellow by Build)
 local zc=A.Pouch.Center.Z -- (Build seats the seal and the strips on this plane, the middle of the crimps, and each stripe on its own strip as built)
 for i=1,8 do
  local x=-.95+(i-.5)*1.9/8
  add('HazardStripe'..i,V(.17,.07,.035+2*G),CF(x,1.11,zc)*ANG(0,0,PI/4),C.Stripe).Tear=i
  add('HazardSeal'..i,V(.155,.07,.035+2*G),CF(x,-1.12,zc)*ANG(0,0,PI/4),C.Stripe).Seal=x
 end
 -- the antenna: its base on the top crimp, the mast and the LED just in front of the strips (clear of them and of their stripes)
 local x=A.Antenna.X
 add('AntennaBase',V(.10,.06,.09),CF(x,.985,zc),C.Mast,M.Metal)
 add('AntennaMast',V(.33,.022,.022),CF(x,1.18,zc-.03)*ANG(0,0,PI/2),C.Steel,M.Metal,Enum.PartType.Cylinder)
 add('AntennaLED',V(.05,.05,.05),CF(x,1.365,zc-.03),C.Led,M.Neon,Enum.PartType.Ball).Blink=.9
 specs=out;return out
end
-- The plain-parts body (no flat pouch yet): the same width, height, faces, rounded long edges, tapered ends and crimps as the generated pouch.
local sachet
function A.SachetSpecs()
 if sachet then return sachet end
 local P=A.Pouch;local c=P.Center;local W,D=P.Width,P.Depth;local h0,r=D/2,.14;local xe,yb=W/2-r,A.Flat.V;local crimp=.09;local taper=P.Height/2-crimp-yb
 local out={};local body=A.Colors.Body
 local function add(name,size,frame,shape,class)out[#out+1]={Name=name,Size=size,Frame=frame,Color=body,Material=Enum.Material.Metal,Shape=shape,Class=class}end
 add('SachetCore',V(2*xe,2*yb,D),CF(c))
 for _,s in ipairs({-1,1})do
  add('SachetSide'..s,V(r,2*yb,D-2*r),CF(c+V(s*(xe+r/2),0,0)))
  for _,z in ipairs({-1,1})do add('SachetEdge'..s..z,V(2*yb,2*r,2*r),CF(c+V(s*xe,0,z*(h0-r)))*ANG(0,0,PI/2),Enum.PartType.Cylinder)end
 end
 -- the tapers (a wedge per end and face: its slope from the face's edge to the middle of the crimp) and the crimps
 for _,up in ipairs({1,-1})do
  for _,z in ipairs({-1,1})do
   local turn=up>0 and(z<0 and CF()or ANG(0,PI,0))or(z<0 and ANG(0,0,PI)or ANG(PI,0,0))
   add('SachetTaper'..(up>0 and'Top'or'Bottom')..(z<0 and'Front'or'Back'),V(W,taper,h0),CF(c+V(0,up*(yb+taper/2),z*h0/2))*turn,nil,'WedgePart')
  end
  add('SachetCrimp'..(up>0 and'Top'or'Bottom'),V(W,crimp,.04),CF(c+V(0,up*(yb+taper+crimp/2),0)))
 end
 sachet=out;return out
end
-- The server's flat pouch when it is ready and is the pouch these faces were drawn for, else nil (the sachet).
function A.PouchTemplate()
 local ok,t=pcall(function()
  local Pouch=require(script.Parent.VerityPouch151)
  if Pouch.State()~='Ready'then return nil end
  local m=Pouch.Template();if not(m and m:GetAttribute('Flat')==true)then return nil end
  local mesh;for _,p in ipairs(m:GetChildren())do if p:IsA('MeshPart')then if mesh then return nil end;mesh=p end end
  local f=mesh and mesh:GetAttribute('PackLocalFrame');local P=A.Pouch;local tol=P.Tolerance
  -- (its depth position may differ: the design follows the pouch where it is, Build)
  if typeof(f)~='CFrame'or math.abs(mesh.Size.X-P.Width)>tol or math.abs(mesh.Size.Y-P.Height)>tol or math.abs(mesh.Size.Z-P.Depth)>tol
   or math.abs(f.Position.X-P.Center.X)>tol or math.abs(f.Position.Y-P.Center.Y)>tol then return nil end
  return m
 end)
 return ok and t or nil
end
function A.Count()return #A.Specs()end
function A.Build(bag)
 if bag:GetAttribute('SpecialPackDesign89')then return true end
 local root=assert(bag.PrimaryPart,'[R153] The Mech pack needs its root part.')
 local scale=bag:GetAttribute('VisualScale')or 1;local giant=(bag:GetAttribute('PackSize')or 1)>10
 local Tags=game:GetService('CollectionService');local C=A.Colors
 local folder,pouch;local count=10 -- (the root, the seal and the 8 tear strips)
 local template=A.PouchTemplate()
 if template then
  local ok=pcall(function()
   assert(Renderer.BuildStandard(bag,A.TemplateKey,nil,template),'the pouch was not built')
   folder=assert(bag:FindFirstChild('PackGeometry'),'no PackGeometry')
   for _,p in ipairs(folder:GetChildren())do if p:IsA('MeshPart')and not pouch then pouch=p else p:Destroy()end end
   assert(pouch,'the flat pouch template has no MeshPart')
  end)
  if not ok then local f=bag:FindFirstChild('PackGeometry');if f then f:Destroy()end;folder,pouch=nil,nil;bag:SetAttribute('CompactPackReady',nil);bag:SetAttribute('CompactPackPartCount',nil)end
 end
 local shift=CF() -- (the body's real depth position against the one the design was drawn on: the design and the seal follow it)
 if pouch then
  pouch.Color=C.Body;pouch.Material=Enum.Material.Metal;pouch.MaterialVariant='';pouch.TextureID='';pouch.Reflectance=0;pouch.Transparency=0
  for _,v in ipairs(pouch:GetChildren())do if not v:IsA('WeldConstraint')then v:Destroy()end end
  local f=pouch:GetAttribute('PackLocalFrame');if typeof(f)=='CFrame'then shift=CF(0,0,f.Position.Z/scale-A.Pouch.Center.Z)end
  count+=1
 else folder=Instance.new('Folder');folder.Name='PackGeometry' end
 local mid=(A.Pouch.Center.Z+shift.Position.Z)*scale
 -- the seal and the 8 tear strips stand on the middle of the body's crimps (flush with its knife edges), whatever depth they were made at
 local strips={}
 for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')and(p.Name=='BottomSeal'or p:GetAttribute('TearIndex'))then
  local f=root.CFrame:ToObjectSpace(p.CFrame);p.CFrame=root.CFrame*CF(f.Position.X,f.Position.Y,mid)*f.Rotation
  strips[p.Name=='BottomSeal'and'Seal'or p:GetAttribute('TearIndex')]=p
 end end
 local placed={}
 local function place(s)
  local p=Instance.new(s.Class or'Part');p.Name=s.Name;if s.Shape then p.Shape=s.Shape end;p.Size=s.Size*scale
  local at=shift*s.Frame -- (identity on the plain-parts body: it is drawn where the design was)
  if s.Tear and strips[s.Tear]then at=CF(root.CFrame:ToObjectSpace(strips[s.Tear].CFrame).Position/scale)*s.Frame.Rotation -- (on its strip, as built)
  elseif s.Seal and strips.Seal then at=CF(root.CFrame:ToObjectSpace(strips.Seal.CFrame).Position/scale+V(s.Seal,0,0))*s.Frame.Rotation end
  local frame=CF(at.Position*scale)*at.Rotation;p.CFrame=root.CFrame*frame;p:SetAttribute('PackLocalFrame',frame)
  p.Color=s.Color;p.Material=s.Material;p.Reflectance=0;p.Transparency=0
  p.Anchored=root.Anchored;p.Massless=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if s.Motion then
   p:SetAttribute('MechMotion',s.Motion);p:SetAttribute('MechMotionRate',s.Rate);p:SetAttribute('MechMotionAmplitude',0);p:SetAttribute('MechMotionPhase',s.Phase or 0)
   local pv=shift*s.Pivot;p:SetAttribute('MechMotionPivot',CF(pv.Position*scale)*pv.Rotation)
  end
  if s.Pulse then p:SetAttribute('MechPulse',s.Pulse);p:SetAttribute('MechMotionPhase',s.Phase or 0)end
  if s.Glow then p:SetAttribute('MechGlow',true)end
  if s.Blink then p:SetAttribute('MechBlink',s.Blink)end
  if s.Tear then p:SetAttribute('MechTear',s.Tear)end
  if s.Bolt then local bp=shift*s.BoltPivot;p:SetAttribute('MechBolt',s.Bolt);p:SetAttribute('MechFace',s.Face);p:SetAttribute('MechBoltPivot',CF(bp.Position*scale)*bp.Rotation)end
  if not p.Anchored then
   if s.Motion then local joint=Instance.new('Motor6D');joint.Name='MechServo';joint.Part0=root;joint.Part1=p;joint.C0=frame;joint.C1=CF();joint.Parent=p
   else local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end
  end
  if giant then Tags:AddTag(p,'GiantVisualPart')end
  p.Parent=folder;count+=1;placed[s.Name]=p;return p
 end
 if not pouch then for _,s in ipairs(A.SachetSpecs())do place(s)end end
 for _,s in ipairs(A.Specs())do place(s)end
 -- the seal and the 8 tear strips of the ordinary pack: hazard yellow under their black stripes
 for _,p in pairs(strips)do p.Color=C.Hazard;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0 end
 -- held fx: the hum at the pouch's centre, the sparks at the LED (off until SeedPackRender details the pack)
 local hum=Instance.new('Attachment');hum.Name='MechHum';hum.CFrame=CF((A.Pouch.Center+shift.Position)*scale);hum.Parent=root
 local light=Instance.new('PointLight');light.Name='MechHumLight';light.Color=RGB(70,225,255);light.Brightness=.8;light.Range=math.min(60,5*scale);light.Shadows=false;light.Enabled=false
 light:SetAttribute('MechHum',.8);light:SetAttribute('MechHeldFx',true);light.Parent=hum
 local tip=Instance.new('Attachment');tip.Name='MechSparks';tip.Parent=placed.AntennaLED
 local e=Instance.new('ParticleEmitter');e.Name='MechAntennaSparks';e.Texture='rbxasset://textures/particles/sparkles_main.dds'
 e.Color=ColorSequence.new(RGB(255,255,255),RGB(110,235,255));e.LightEmission=1;e.LightInfluence=0;e.Rate=2.5;e.Lifetime=NumberRange.new(.25,.45)
 e.Speed=NumberRange.new(1.2*scale,2.2*scale);e.SpreadAngle=Vector2.new(60,60);e.EmissionDirection=Enum.NormalId.Top;e.Acceleration=V(0,-6*scale,0);e.Drag=3
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.045*scale),NumberSequenceKeypoint.new(1,0)});e.Transparency=NumberSequence.new(.1);e.Enabled=false
 e:SetAttribute('MechHeldFx',true);e.Parent=tip
 if not pouch then folder.Parent=bag end
 bag:SetAttribute('ApprovedShapeKey89',A.TemplateKey);bag:SetAttribute('SpecialPackDesign89',true);bag:SetAttribute('CompactPackPartCount',count);bag:SetAttribute('CompactPackReady',true)
 bag:SetAttribute('PaperColor',C.Body);bag:SetAttribute('PreserveTextStyle',true);bag:SetAttribute('MechDesignRevision',A.Revision);bag:SetAttribute('MechPouch',pouch~=nil);bag:SetAttribute('MechBodyZ',shift.Position.Z)
 -- (no orbiting scanner any more: MechFX false; the weather trait's own effect, if any, as before)
 require(script.Parent.ItemEffectAnchor).Set(bag,bag:GetAttribute('Weather'),false,scale*1.05,scale*2.2)
 return true
end
return A
