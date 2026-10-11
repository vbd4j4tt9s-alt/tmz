-- R122: "Void Pack" (EclipseReliquary) redesign - an ominous, space-themed pack.
-- Black-violet void body; on both faces a spinning spiral galaxy and nebula haze around a black
-- singularity, a white-hot photon ring and a tilted accretion disc, a crimson slit EYE, star field
-- and four rune sigils; around the whole pack a tilted, spinning event-horizon halo with debris.
-- Built only from Parts on the approved Forest_01 body (no uploaded ids). The same Build serves
-- world, carried, dropped, inventory pictures (ItemPictures), previews and the opening copy.
-- Motion hints are attributes only (VoidSpin/VoidPivot/VoidPulse/VoidPhase); VeiledEventClient81
-- animates them locally inside ClientFxBudget / ReducedMotion / distance limits. Static otherwise.
local A={Revision=122}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Shared=require(script.Parent.SpecialPackArt89)
local Renderer=require(script.Parent.SeedPackRenderer)
A.Palette={
 Body=RGB(9,5,20),Trim=RGB(48,26,82),Nebula=RGB(46,16,88),NebulaPink=RGB(122,28,98),NebulaBlue=RGB(22,50,122),
 ArmInner=RGB(255,110,220),ArmMid=RGB(150,90,255),ArmOuter=RGB(90,210,255),Void=RGB(0,0,0),
 PhotonHot=RGB(255,238,250),PhotonPink=RGB(255,120,214),PhotonViolet=RGB(190,130,255),Accretion=RGB(255,168,118),
 Pupil=RGB(255,30,70),Iris=RGB(196,18,58),Rune=RGB(168,58,255),Star=RGB(240,240,255),StarCyan=RGB(150,232,255),StarPink=RGB(255,170,230),
 Halo=RGB(176,104,255),HaloHot=RGB(255,214,250),Debris=RGB(26,18,40),
}
A.Budget={MaxParts=190}
-- R153 (owner: "parts are dislocated on packs"): the print's two sheets stand at the Forest_01 pouch's BOX faces, and the box's front is the tip of the pouch's raised leaf
-- print (z = -.574): the middle of each sheet rests on that leaf, but the pouch itself curves away to -.08 .. -.31 under the corners, so the corner details that do not lie
-- on the nebula (the four rune sigils, two of the stars, three of the specks) hung .16 - .46 off the pouch, touching nothing. They are SEATED on it now: each one's back sits
-- (a hair inside, SeatEmbed) on the highest point of the pouch under it, at the same x / y, size, turn and colour, so the front looks the same. Seats = how far out of the
-- pouch's middle plane its surface is under that detail (pack units at scale 1), baked from the approved Forest_01 pouch (its native render data, SeedPackArtForest01, which
-- is the uploaded mesh: the same box to 1e-4): docs/proposals/R153/tools/void_seats.py prints this table, and the R153 pack-parts suite checks it against the pouch.
-- F = the front face, B = the back; a detail that rests on the sheet (on a nebula disc or the accretion disc) has no seat and stays on the sheet.
A.Seats={
 F={Star={[1]=.244,[3]=.245},Speck={[2]=.252,[3]=.247,[4]=.221},Rune={[1]=.175,[2]=.184,[3]=.223,[4]=.225}},
 B={Star={[1]=.244,[3]=.245},Speck={[2]=.252,[3]=.247,[4]=.225},Rune={[1]=.175,[2]=.184,[3]=.225,[4]=.226}},
}
A.SeatEmbed=.004
local P=A.Palette
local function lerp(a,b,t)return a:Lerp(b,t)end
local specs
function A.Specs()
 if specs then return specs end
 local out={};local body=Shared.BodyBounds()
 local function add(name,size,frame,color,material,shape,alpha)
  local s={Name=name,Size=size,Frame=frame,Color=color,Material=material or Enum.Material.Neon,Shape=shape,Transparency=alpha or 0}
  out[#out+1]=s;return s
 end
 local function segment(name,base,p,q,width,depth,color,alpha)
  local d=q-p
  return add(name,V(d.Magnitude+.006,width,depth),base*CF((p+q)*.5)*CFrame.Angles(0,0,math.atan2(d.Y,d.X)),color,nil,nil,alpha)
 end
 local function disc(name,base,center,diameter,color,material,alpha)
  return add(name,V(.008,diameter,diameter),base*CF(center)*CFrame.Angles(0,math.pi/2,0),color,material,Enum.PartType.Cylinder,alpha)
 end
 local function spin(s,pivot,rate)s.Spin=rate;s.Pivot=pivot;return s end
 local function pulse(s,amount,phase)s.Pulse=amount;s.Phase=phase or 0;return s end
 for _,side in ipairs({-1,1})do
  local tag=side<0 and'F'or'B'
  local face=(side<0 and body.MinZ or body.MaxZ)+side*.02
  -- Local -Z points out of this face on both sides.
  local base=CF(0,-.02,face)*CFrame.Angles(0,side>0 and math.pi or 0,0)
  -- Nebula haze: three overlapping translucent clouds.
  disc('VoidNebula'..tag,base,V(0,0,0),1.30,P.Nebula,nil,.45)
  disc('VoidNebulaPink'..tag,base,V(.20,.30,-.004),.78,P.NebulaPink,nil,.55)
  disc('VoidNebulaBlue'..tag,base,V(-.24,-.36,-.004),.62,P.NebulaBlue,nil,.55)
  -- Two logarithmic spiral arms; they spin around the singularity.
  local pivot=base*CF(0,0,-.012)
  for arm=0,1 do
   local last
   for i=0,7 do
    local t=i/7;local theta=arm*math.pi+t*3.3;local r=.40*math.exp(.19*t*3.3)
    local point=V(math.cos(theta)*r,math.sin(theta)*r,0)
    if last then
     local color=t<.5 and lerp(P.ArmInner,P.ArmMid,t*2)or lerp(P.ArmMid,P.ArmOuter,(t-.5)*2)
     local s=segment('GalaxyArm'..tag..arm..'_'..i,pivot,last,point,.05-.032*t,.012,color,.05+.35*t)
     spin(s,pivot,.35)
    end
    last=point
   end
  end
  -- Event horizon: black singularity, white-hot photon ring and a tilted accretion disc.
  disc('VoidSingularity'..tag,base,V(0,0,-.018),.62,P.Void,Enum.Material.SmoothPlastic)
  for i=1,14 do
   local a,b=(i-1)*math.pi*2/14,i*math.pi*2/14
   local color=i%3==0 and P.PhotonHot or i%3==1 and P.PhotonPink or P.PhotonViolet
   pulse(segment('PhotonRing'..tag..i,base*CF(0,0,-.024),V(math.cos(a)*.34,math.sin(a)*.34,0),V(math.cos(b)*.34,math.sin(b)*.34,0),.045,.012,color),.35,i*.45)
  end
  local disk=base*CF(0,0,-.03)*CFrame.Angles(0,0,-.32)
  for i=1,14 do
   local a,b=(i-1)*math.pi*2/14,i*math.pi*2/14
   local front=math.sin((a+b)*.5)<0
   segment('AccretionDisc'..tag..i,disk,V(math.cos(a)*.60,math.sin(a)*.15,0),V(math.cos(b)*.60,math.sin(b)*.15,0),front and .034 or .022,.01,P.Accretion,front and 0 or .35)
  end
  -- The eye: a crimson slit pupil inside a thin iris; it pulses like a heartbeat.
  pulse(add('VoidPupil'..tag,V(.056,.40,.01),base*CF(0,0,-.042),P.Pupil),.55,0)
  for i=1,8 do
   local a,b=(i-1)*math.pi/4,i*math.pi/4
   pulse(segment('VoidIris'..tag..i,base*CF(0,0,-.036),V(math.cos(a)*.20,math.sin(a)*.20,0),V(math.cos(b)*.20,math.sin(b)*.20,0),.024,.01,P.Iris),.4,.2)
  end
  -- Star field: three four-point stars and four specks; they twinkle.
  -- R151: the stars, specks and rune strokes sat .031 in front of the pouch's front face (thin blocks .016 out, .01 deep, away from the nebula
  -- discs that reach to .016); they are backed now: the same front face (.021 out), but .026 deep, so they reach .015 from the pouch like the
  -- discs do (nothing floating off the surface; the front looks exactly as before).
  -- R153: a seated detail's local z (out of the face is -Z): its .026-deep back on the pouch's surface under it, SeatEmbed inside; -.008 (on the sheet) without a seat
  local seats=A.Seats[tag]
  local function depth(kind,i)local s=seats[kind][i];return s and math.abs(face)-s+A.SeatEmbed-.013 or -.008 end
  for i,star in ipairs({{-.66,.50,.13,P.Star},{.60,-.40,.11,P.StarCyan},{.12,.80,.09,P.StarPink}})do
   local at=base*CF(star[1],star[2],depth('Star',i))
   pulse(add('StarV'..tag..i,V(.022,star[3],.026),at,star[4]),.6,i*1.7)
   pulse(add('StarH'..tag..i,V(star[3]*.62,.022,.026),at,star[4]),.6,i*1.7)
  end
  for i,speck in ipairs({{-.42,-.58},{.70,.30},{-.74,-.12},{.36,-.80}})do
   pulse(add('StarSpeck'..tag..i,V(.035,.035,.026),base*CF(speck[1],speck[2],depth('Speck',i))*CFrame.Angles(0,0,math.pi/4),i%2==0 and P.StarCyan or P.Star),.7,i*2.3)
  end
  -- Four rune sigils in the corners (three strokes each); they flicker.
  local runes={
   {V(-.62,.84,0),{{V(0,-.09,0),V(0,.09,0)},{V(0,.03,0),V(.06,.09,0)},{V(0,.03,0),V(-.06,.09,0)}}},
   {V(.62,.84,0),{{V(-.06,-.08,0),V(0,.09,0)},{V(0,.09,0),V(.06,-.08,0)},{V(-.04,-.02,0),V(.04,-.02,0)}}},
   {V(-.60,-.80,0),{{V(-.06,.08,0),V(.06,-.08,0)},{V(-.06,-.08,0),V(.06,.08,0)},{V(0,-.09,0),V(0,.09,0)}}},
   {V(.60,-.80,0),{{V(-.05,.09,0),V(-.05,-.09,0)},{V(-.05,.09,0),V(.06,.02,0)},{V(.06,.02,0),V(-.05,-.02,0)}}},
  }
  for r,rune in ipairs(runes)do for k,stroke in ipairs(rune[2])do
   pulse(segment('RuneSigil'..tag..r..'_'..k,base*CF(rune[1]+V(0,0,depth('Rune',r))),stroke[1],stroke[2],.022,.026,P.Rune),.5,r*1.3)
  end end
 end
 -- Event-horizon halo around the whole pack: a tilted circle, so spinning never changes its outline.
 local halo=CF(0,-.04,0)*CFrame.Angles(.12,.32,0)
 local radius=1.34
 for i=1,26 do
  if i%7~=0 then -- gaps make the rotation readable
   local a,b=(i-1)*math.pi*2/26,i*math.pi*2/26
   local t=(math.sin(a*2)+1)*.5
   local s=segment('EventHorizon'..i,halo,V(math.cos(a)*radius,math.sin(a)*radius,0),V(math.cos(b)*radius,math.sin(b)*radius,0),.05,.03,lerp(P.Halo,P.HaloHot,t),.1+.25*(1-t))
   spin(s,halo,-.5)
  end
 end
 for i,a in ipairs({.6,2.7,4.6})do
  local size=({.16,.12,.10})[i]
  local s=add('HaloDebris'..i,V(size,size*.8,size*.9),halo*CF(math.cos(a)*radius,math.sin(a)*radius,0)*CFrame.Angles(a,a*1.7,a*.6),P.Debris,Enum.Material.Slate)
  spin(s,halo,-.5)
 end
 specs=out;return out
end
-- Conservative bounds: the body plus every part corner, with spinning parts swept around their pivot.
local unitBounds
function A.Bounds(scale)
 if not unitBounds then
  local b=table.clone(Shared.BodyBounds())
  local function include(q)
   b.Radius=math.max(b.Radius,V(q.X,0,q.Z).Magnitude);b.MinY=math.min(b.MinY,q.Y);b.MaxY=math.max(b.MaxY,q.Y)
   b.MinZ=math.min(b.MinZ,q.Z);b.MaxZ=math.max(b.MaxZ,q.Z)
  end
  for _,s in ipairs(A.Specs())do
   local steps=s.Spin and 16 or 1
   for k=0,steps-1 do
    local frame=s.Frame
    if s.Spin then frame=s.Pivot*CFrame.Angles(0,0,k*math.pi*2/steps)*s.Pivot:Inverse()*s.Frame end
    for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
     include(frame*V(s.Size.X*x,s.Size.Y*y,s.Size.Z*z))
    end end end
   end
  end
  b.Radius+=.04;b.MinY-=.04;b.MaxY+=.04;b.MinZ-=.02;b.MaxZ+=.02
  unitBounds=b
 end
 local out={};for k,v in pairs(unitBounds)do out[k]=v*(scale or 1)end;return out
end
function A.Build(bag)
 if bag:GetAttribute('SpecialPackDesign89')then return true end
 Renderer.BuildStandard(bag,Shared.TemplateKey)
 local root=bag.PrimaryPart;local folder=bag:FindFirstChild('PackGeometry');local scale=bag:GetAttribute('VisualScale')or 1
 for _,p in ipairs(folder:GetChildren())do if p:IsA('MeshPart')then
  p.TextureID='';p.MaterialVariant='';p.Material=Enum.Material.SmoothPlastic;p.Color=P.Body;p.Reflectance=0
  for _,v in ipairs(p:GetChildren())do if v:IsA('SurfaceAppearance')then v:Destroy()end end
 end end
 local giant=(bag:GetAttribute('PackSize')or 1)>10
 local count=bag:GetAttribute('CompactPackPartCount')or 10
 for _,s in ipairs(A.Specs())do
  local p=Instance.new('Part');p.Name=s.Name;p.Size=s.Size*scale
  local frame=CF(s.Frame.Position*scale)*s.Frame.Rotation;p.CFrame=root.CFrame*frame;p:SetAttribute('PackLocalFrame',frame)
  p.Color=s.Color;p.Material=s.Material;if s.Shape then p.Shape=s.Shape end;p.Transparency=s.Transparency or 0
  p.Reflectance=0;p.Anchored=root.Anchored;p.Massless=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  if s.Spin then p:SetAttribute('VoidSpin',s.Spin);p:SetAttribute('VoidPivot',CF(s.Pivot.Position*scale)*s.Pivot.Rotation)end
  if s.Pulse then p:SetAttribute('VoidPulse',s.Pulse);p:SetAttribute('VoidPhase',s.Phase or 0)end
  if not p.Anchored then local w=Instance.new('WeldConstraint');w.Part0=root;w.Part1=p;w.Parent=p end
  if giant then game:GetService('CollectionService'):AddTag(p,'GiantVisualPart')end
  p.Parent=folder;count+=1
 end
 for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')and(p.Name=='BottomSeal'or p:GetAttribute('TearIndex'))then p.Color=P.Trim;p.Material=Enum.Material.Metal;p.Reflectance=0 end end
 bag:SetAttribute('ApprovedShapeKey89',Shared.TemplateKey);bag:SetAttribute('SpecialPackDesign89',true);bag:SetAttribute('CompactPackPartCount',count)
 bag:SetAttribute('PaperColor',P.Body);bag:SetAttribute('PreserveTextStyle',true)
 bag:SetAttribute('EclipsePack',true);bag:SetAttribute('VoidDesignRevision',A.Revision)
 return true
end
return A
