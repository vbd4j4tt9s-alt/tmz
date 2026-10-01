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
return A
