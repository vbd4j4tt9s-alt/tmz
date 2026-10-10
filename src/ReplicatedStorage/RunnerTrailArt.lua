-- R48: shared broad ribbon silhouette for live trails and shop models.
-- R117: per-tier ribbon looks. Each tier has a multi-stop gradient, a brighter core ribbon, its own glow,
-- transparency ripples (Aurora curtains, Nebula clouds, Royal silk) and a longer reach. Used by the server
-- (Configure), the client aura (Sequence for colour shifts) and the shop preview (Color/Look). No image assets.
local A={}
A.WidthKeys={{0,.82},{.16,1},{.53,.95},{.76,.60},{.90,.25},{1,0}}
function A.Width(t)
 for i=2,#A.WidthKeys do local a,b=A.WidthKeys[i-1],A.WidthKeys[i];if t<=b[1]then return a[2]+(b[2]-a[2])*math.clamp((t-a[1])/(b[1]-a[1]),0,1)end end
 return 0
end
function A.BodyRange(character,root)
 local lo,hi=math.huge,-math.huge
 for _,p in ipairs(character:GetChildren())do
  if p:IsA('BasePart')and p~=root and(p.Name=='Head'or p.Name:find('Torso')or p.Name:find('Leg')or p.Name:find('Foot')or p.Name:find(' Arm'))then
   local y=root.CFrame:PointToObjectSpace(p.Position).Y
   lo=math.min(lo,y-p.Size.Y/2);hi=math.max(hi,y+p.Size.Y/2)
  end
 end
 if lo==math.huge then return -2.6,2.6 end
 return lo+.10,hi-.10
end
function A.Attachments(rootSize,layer,lo,hi)
 local scale=math.clamp(rootSize.Y/2,.5,3);local back=rootSize.Z*.5+.10*scale;local y=.22*scale
 if lo and hi then local x=layer==1 and 0 or .18*scale;return Vector3.new(x,hi,back),Vector3.new(x,lo,back)end
 if layer==1 then return Vector3.new(0,y+.76*scale,back),Vector3.new(0,y-.76*scale,back)end
 return Vector3.new(-.51*scale,y,back),Vector3.new(.51*scale,y,back)
end
local C=Color3.fromRGB
A.Order={'MintTrail','ArcTrail','SolarTrail','AuroraTrail','NebulaTrail','RoyalTrail'}
-- Colors: head -> tail stops. Core: the thin inner ribbon. Glow: LightEmission. Alpha: head/body/tail of the
-- broad ribbon. Ripples/Depth: soft transparency bands along the length. Reach: MaxLength. Sheen: a moving
-- highlight band the client sweeps along the ribbon (Royal); Shift: how far the client drifts the gradient.
A.Looks={
 MintTrail={Tier=1,Colors={C(30,200,130),C(70,236,166),C(160,255,216),C(52,220,166),C(22,150,110)},
  Core={C(225,255,242),C(150,255,214),C(80,226,170)},Glow=.32,CoreGlow=.5,Alpha={.26,.32,.62},Ripples=0,Depth=0,
  Width=.86,CoreWidth=.14,Reach=40,Shift=0},
 ArcTrail={Tier=2,Colors={C(36,86,255),C(62,170,255),C(180,240,255),C(74,142,255),C(44,64,222)},
  Core={C(240,252,255),C(170,236,255),C(90,160,255)},Glow=.46,CoreGlow=.75,Alpha={.22,.28,.58},Ripples=2,Depth=.05,
  Width=.90,CoreWidth=.17,Reach=46,Shift=0},
 SolarTrail={Tier=3,Colors={C(255,244,170),C(255,206,70),C(255,150,40),C(255,104,30),C(214,62,26)},
  Core={C(255,255,232),C(255,236,140),C(255,170,60)},Glow=.6,CoreGlow=.9,Alpha={.16,.24,.54},Ripples=2,Depth=.07,
  Width=.95,CoreWidth=.22,Reach=52,Shift=0},
 AuroraTrail={Tier=4,Colors={C(48,236,170),C(96,255,206),C(104,198,255),C(176,108,255),C(255,128,214)},
  Core={C(236,255,250),C(190,240,255),C(230,190,255)},Glow=.68,CoreGlow=.95,Alpha={.14,.22,.52},Ripples=3,Depth=.12,
  Width=1,CoreWidth=.2,Reach=58,Shift=.35},
 NebulaTrail={Tier=5,Colors={C(255,120,236),C(150,72,255),C(84,40,190),C(90,200,255),C(170,90,255),C(54,30,140)},
  Core={C(255,236,255),C(196,170,255),C(130,220,255)},Glow=.78,CoreGlow=1,Alpha={.1,.2,.5},Ripples=4,Depth=.12,
  Width=1.02,CoreWidth=.24,Reach=64,Shift=.22},
 RoyalTrail={Tier=6,Colors={C(255,236,150),C(255,196,48),C(150,52,220),C(98,28,170),C(255,190,40),C(122,38,190)},
  Core={C(255,250,214),C(255,214,90),C(232,160,30)},Glow=.86,CoreGlow=1,Alpha={.06,.14,.46},Ripples=2,Depth=.06,
  Width=1.06,CoreWidth=.3,Reach=72,Shift=0,Sheen=C(255,252,230)},
}
-- Older 3-colour palettes (head/middle/tail) kept for callers that read them.
A.Palettes={};A.Profiles={}
for id,look in pairs(A.Looks)do
 local c=look.Colors;A.Palettes[id]={c[1],c[math.ceil(#c/2)],c[#c]}
 local w=look.Width;A.Profiles[id]={{0,.8*w},{.12,w},{.55,.84*w},{.82,.42*w},{1,0}}
end
function A.Look(id)return A.Looks[id]end
function A.Tier(id)local look=A.Looks[id];return look and look.Tier or 0 end
-- Samples the gradient at t (0 head .. 1 tail). phase drifts the colours (cyclic) for the client shimmer.
local function sample(colors,t,phase)
 local n=#colors
 if not phase or phase==0 then
  local x=math.clamp(t,0,1)*(n-1);local i=math.min(n-2,math.floor(x))
  return colors[i+1]:Lerp(colors[i+2],x-i)
 end
 local u=(math.clamp(t,0,1)*(n-1)/n+phase)%1*n;local i=math.floor(u)%n
 return colors[i+1]:Lerp(colors[(i+1)%n+1],u-math.floor(u))
end
A.Sample=sample
function A.Color(color,t,id)
 local look=A.Looks[id];if not look then return color end
 return sample(look.Colors,t)
end
-- Colour sequence for the broad ribbon (layer 1) or the core (layer 2). phase in [0,1): 0 = the base look.
function A.Sequence(id,layer,phase)
 local look=A.Looks[id];phase=phase or 0
 if not look then return nil end
 local colors=layer==1 and look.Colors or look.Core
 local keys={};local count=layer==1 and 9 or 5
 local drift=(look.Shift or 0)*phase;local sweep=look.Sheen and phase>0 and phase*1.4-.2
 for i=0,count-1 do
  local t=i/(count-1);local c=sample(colors,t,drift)
  if sweep then local w=math.max(0,1-math.abs(t-sweep)/.16);if w>0 then c=c:Lerp(look.Sheen,w*(layer==1 and .7 or .9))end end
  table.insert(keys,ColorSequenceKeypoint.new(t,c))
 end
 return ColorSequence.new(keys)
end
function A.Transparency(id,layer)
 local look=A.Looks[id]or A.Looks.MintTrail
 local a=look.Alpha;local keys={}
 if layer~=1 then
  local base=math.max(0,a[1]+.12)
  return NumberSequence.new({NumberSequenceKeypoint.new(0,base),NumberSequenceKeypoint.new(.5,base+.06),NumberSequenceKeypoint.new(.8,.62),NumberSequenceKeypoint.new(1,1)})
 end
 for i=0,10 do
  local t=i/10;local v
  if t<=.6 then v=a[1]+(a[2]-a[1])*(t/.6)elseif t<.86 then v=a[2]+(a[3]-a[2])*((t-.6)/.26)else v=a[3]+(1-a[3])*((t-.86)/.14)end
  if look.Ripples>0 and t>0 and t<1 then v+=look.Depth*(.5+.5*math.sin(t*look.Ripples*2*math.pi))end
  table.insert(keys,NumberSequenceKeypoint.new(t,math.clamp(v,0,1)))
 end
 return NumberSequence.new(keys)
end
function A.Configure(trail,color,layer,id)
 local look=A.Looks[id];local profile=A.Profiles[id]or A.WidthKeys;local keys={}
 local core=look and look.CoreWidth or .20
 for _,k in ipairs(profile)do table.insert(keys,NumberSequenceKeypoint.new(k[1],k[2]*(layer==1 and 1 or core)))end
 trail.WidthScale=NumberSequence.new(keys);trail.Texture=''
 if look then
  trail.Color=A.Sequence(id,layer,0);trail.Transparency=A.Transparency(id,layer)
  trail.LightEmission=layer==1 and look.Glow or look.CoreGlow;trail.MaxLength=look.Reach
  pcall(function()trail.Brightness=1+look.Tier*(layer==1 and .12 or .25)end)
  trail:SetAttribute('TrailTier',look.Tier);trail:SetAttribute('TrailLayer117',layer)
 else
  trail.Color=ColorSequence.new(color or Color3.new(1,1,1))
  local alpha=layer==1 and .20 or .45
  trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,alpha),NumberSequenceKeypoint.new(.60,alpha+.08),NumberSequenceKeypoint.new(.84,.6),NumberSequenceKeypoint.new(1,1)})
  trail.LightEmission=.35;trail.MaxLength=52
 end
 trail.FaceCamera=true;trail.LightInfluence=0;trail.MinLength=.06;trail.Lifetime=1.4;trail.Enabled=false
 trail:SetAttribute('PlainColourTrail91',true)
end
-- R118: head pieces worn by the top trails: Royal's glowing crown, Nebula's orbiting space dust and Aurora's halo.
-- Built in head space (origin = Head centre, -Z = face, +Y = up) from the visible head size, so the live client
-- (RunnerTrailAuraFx, welded to the Head) and the shop preview (ShopProductArt) share one geometry. Parts hang off
-- "rings" (pivots): ring 1 is static, Nebula's rings 2/3 spin. Shimmer tags drive the client's gentle animation.
A.HeadKinds={AuroraTrail='Halo',NebulaTrail='Dust',RoyalTrail='Crown'}
function A.HeadKind(id)return A.HeadKinds[id]end
-- Visible head size (width, height). Classic R6 heads are 2x1x1 parts drawn through a 1.25-scaled head mesh;
-- R15/mesh heads are their part size.
function A.HeadSize(head)
 local s=head.Size;local w,h=math.min(s.X,s.Z),s.Y
 local mesh=head:FindFirstChildOfClass('SpecialMesh')
 if mesh and mesh.Scale then w=math.min(s.X*mesh.Scale.X,s.Z*mesh.Scale.Z);h=s.Y*mesh.Scale.Y end
 return math.clamp(w,.5,4),math.clamp(h,.5,4)
end
A.HeadColors={
 Gold=C(255,200,52),Rim=C(255,236,160),Point=C(255,214,70),Sheen=C(255,252,232),Purple=C(176,56,255),Red=C(236,36,92),
 Dust={C(236,220,255),C(168,96,255),C(104,182,255),C(255,150,236),C(126,70,230)},Star=C(255,246,255),StarTint=C(214,180,255),
}
-- Cyclic palette sample (x wraps): used for the aurora halo's colour flow.
-- (R153: it blended a colour with ITSELF, colors[i % n + 1], so the Aurora halo held each colour and then snapped to the next every 2.2 s;
-- it now flows into the next one. At a whole step, e.g. the build's i / n, it is exactly colors[i + 1] as before.)
function A.Cycle(colors,x)local n=#colors;local u=(x%1)*n;local i=math.floor(u)%n;return colors[i+1]:Lerp(colors[(i+1)%n+1],u-math.floor(u))end
local function hash(i,k)local x=math.sin(i*12.9898+k*78.233)*43758.5453;return x-math.floor(x)end
-- Returns {Kind,Rings={{Y,Speed,Bob}},Parts={{Name,Size,Offset,Ring,Color,Material,Transparency,Reflectance,Shimmer}},
-- Points={name=head-space Vector3},Orbits={{Key,Center,Radius,Speed,Phase,Lift}}} or nil. simple = low-quality version.
function A.HeadPiece(id,w,h,simple)
 local kind=A.HeadKinds[id];if not kind then return nil end
 local V,CF,ang=Vector3.new,CFrame.new,CFrame.Angles;local u=w;local top=h/2;local HC=A.HeadColors
 local neon,metal=Enum.Material.Neon,Enum.Material.Metal
 local out={Kind=kind,Rings={},Parts={},Points={},Orbits={}}
 local function part(name,size,offset,color,material,alpha,ring,shimmer)
  local t={Name=name,Size=size,Offset=offset,Color=color,Material=material,Transparency=alpha or 0,Ring=ring or 1,Shimmer=shimmer}
  table.insert(out.Parts,t);return t
 end
 local function around(a,r,y)return V(math.sin(a)*r,y,-math.cos(a)*r)end
 if kind=='Crown'then
  -- Worn like a hat: the band wraps the top of the head, five points rise above it, jewels on band and tips.
  local r=.53*u;local bandH=.2*u;local y0=top-.04*u;out.Rings[1]={Y=y0,Speed=0}
  local seg=2*r*math.sin(math.pi/10)+.02*u
  for i=0,9 do
   local a=(i+.5)/10*2*math.pi
   local band=part('Crown band',V(seg,bandH,.07*u),CF(around(a,r,0))*ang(0,-a,0),HC.Gold,metal);band.Reflectance=.2
   if not simple then part('Crown rim',V(seg,.045*u,.09*u),CF(around(a,r+.005*u,bandH/2))*ang(0,-a,0),HC.Rim,neon,0,1,{Kind='Gold',T=(i+.5)/10})end
  end
  local py=bandH/2+.1*u;local tipY=py+.22*u*.7071+.035*u
  for i=0,4 do
   local a=i/5*2*math.pi
   part('Crown point',V(.22*u,.22*u,.05*u),CF(around(a,r,py))*ang(0,-a,0)*ang(0,0,math.pi/4),HC.Point,neon,0,1,{Kind='Gold',T=i/5})
   local gem=i%2==0 and HC.Purple or HC.Red
   if not simple then
    part('Crown gem',V(.09*u,.09*u,.09*u),CF(around(a,r,tipY))*ang(.6,-a,math.pi/4),gem,neon)
    part('Crown jewel',V((i==0 and .15 or .11)*u,(i==0 and .15 or .11)*u,.04*u),CF(around(a,r+.045*u,0))*ang(0,-a,0)*ang(0,0,math.pi/4),gem,neon)
   elseif i==0 then
    part('Crown jewel',V(.15*u,.15*u,.04*u),CF(around(a,r+.045*u,0))*ang(0,-a,0)*ang(0,0,math.pi/4),gem,neon)
   end
   out.Points['Tip'..(i+1)]=around(a,r,y0+tipY)
  end
  out.Points.CrownTop=V(0,y0+bandH/2+.15*u,0)
 elseif kind=='Halo'then
  -- A shimmering aurora ring floating just above the head, with a soft wider glow band.
  local r=.44*u;local y0=top+.24*u;out.Rings[1]={Y=y0,Speed=.5,Bob=.035*u}
  local n=12;local seg=2*r*math.sin(math.pi/n)+.02*u;local colors=A.Looks.AuroraTrail.Colors
  for i=0,n-1 do
   local a=(i+.5)/n*2*math.pi;local c=A.Cycle(colors,i/n)
   part('Aurora halo',V(seg,.07*u,.07*u),CF(around(a,r,0))*ang(0,-a,0),c,neon,.18,1,{Kind='Cycle',T=i/n})
   if not simple then part('Aurora halo glow',V(seg*1.1,.03*u,.2*u),CF(around(a,r,0))*ang(0,-a,0),c,neon,.62,1,{Kind='Cycle',T=i/n})end
  end
  out.Points.HaloC=V(0,y0,0)
 else
  -- Space dust: specks and a few four-point stars on two counter-rotating rings close around the head.
  local cy=top*.45;out.Rings[1]={Y=cy,Speed=0};out.Rings[2]={Y=cy,Speed=1.2};out.Rings[3]={Y=cy,Speed=-.75}
  local function speck(i,ring,r0)
   local a=i*2.399+hash(i,1);local r=(r0+.1*hash(i,2))*u;local y=(hash(i,3)-.45)*.55*u;local s=(.06+.05*hash(i,4))*u
   part('Space dust',V(s,s,s),CF(around(a,r,y))*ang(hash(i,5)*3,a,math.pi/4),HC.Dust[(i-1)%#HC.Dust+1],neon,.12+.2*hash(i,6),ring,{Kind='Twinkle',T=hash(i,7)})
  end
  for i=1,simple and 5 or 9 do speck(i,2,.64)end
  if not simple then for i=10,13 do speck(i,3,.72)end end
  for i=1,simple and 2 or 3 do
   local a=i/3*2*math.pi+.4;local p=around(a,.74*u,(i==2 and -.12 or .18+.06*i)*u);local s=(.24+.04*i)*u
   local face=CF(p)*ang(0,-a,0)
   part('Dust star',V(s,.035*u,.035*u),face*ang(0,0,math.pi/4),HC.Star,neon,0,3,{Kind='Twinkle',T=i/3})
   part('Dust star',V(.035*u,s,.035*u),face*ang(0,0,math.pi/4),HC.StarTint,neon,0,3,{Kind='Twinkle',T=i/3})
  end
  local c=V(0,cy,0);out.Points.DustC=c
  out.Orbits={{Key='Dust1',Center=c,Radius=.7*u,Speed=1.6,Phase=0,Lift=.18*u},{Key='Dust2',Center=c,Radius=.74*u,Speed=1.6,Phase=math.pi,Lift=.18*u}}
  for _,o in ipairs(out.Orbits)do out.Points[o.Key]=c+V(math.sin(o.Phase)*o.Radius,0,-math.cos(o.Phase)*o.Radius)end
 end
 return out
end
return A
