-- R48: native 3D store samples. Boots use the exact wearable geometry (R111: with glass/ice transparency and reflectance).
local RS=game:GetService('ReplicatedStorage');local Boots=require(RS:WaitForChild('RunnerBootArt'));local Ribbon=require(RS:WaitForChild('RunnerTrailArt'))
local A={};local V,CF=Vector3.new,CFrame.new
function A.Color(product)
 local c=product.Color or{};return Color3.fromRGB(c.R or 152,c.G or 220,c.B or 180)
end
function A.Specs(product,biome)
 local out={};local accent=A.Color(product);local dark=Color3.fromRGB(38,48,57);local silver=Color3.fromRGB(194,208,213)
 local function p(name,size,frame,color,material,shape)
  table.insert(out,{Name=name,Size=size,Frame=frame,Color=color,Material=material or Enum.Material.SmoothPlastic,Shape=shape})
 end
 if product.Type=='Accessory'then
  biome=product.Biome or biome or'Desert'
  for _,x in ipairs({-.65,.65})do
   local function boot(specs,frame)for _,s in ipairs(specs)do p(s.Name,s.Size,frame*s.Frame,s.Color,s.Material,s.Shape);out[#out].Transparency=s.Transparency;out[#out].Reflectance=s.Reflectance end end
   boot(Boots.Specs(V(1,.7,1.8),false,biome or'Forest',accent),CF(x,.39,0))
   boot(Boots.ShinSpecs(V(1.05,1.45,1.05),false,biome or'Forest',accent),CF(x,1.475,0))
   boot(Boots.KneeSpecs(V(1.1,1.4,1.1),false,biome or'Forest',accent),CF(x,2.90,0))
  end
 elseif product.Type=='Trail'then
  -- R117: the preview shows each tier's live look: layered ribbon + core, then sparks (Arc), embers and a flare
  -- (Solar), an aurora veil (Aurora), a star swirl (Nebula) and Royal's gold/purple double helix, gold trim,
  -- jewels, glitter and footstep glints; R118: plus the head piece (crown, space dust, halo).
  -- Blocks only (static ViewportFrame; particles do not render there).
  local look=Ribbon.Look and Ribbon.Look(product.Id);local tier=look and look.Tier or 0;local id=product.Id
  p('Runner body',V(1.65,1.85,.8),CF(0,2.3,-.5),dark)
  p('Runner head',V(.85,.85,.85),CF(0,3.65,-.5),silver)
  for _,x in ipairs({-.48,.48})do p('Runner leg',V(.64,1.4,.7),CF(x,.67,-.5)*CFrame.Angles(x*.35,0,0),dark)end
  for _,x in ipairs({-1.08,1.08})do p('Runner arm',V(.45,1.6,.6),CF(x,2.35,-.5)*CFrame.Angles(-x*.35,0,0),silver)end
  p('Chest badge',V(.55,.28,.06),CF(0,2.55,-.93),accent)
  local neon=Enum.Material.Neon
  local function point(t)return V(math.sin(t*3.9)*.45,2.40+math.sin(t*4.2)*.22,.22+t*7.4)end
  local function seg(name,a,b,thick,height,color,alpha)
   if(b-a).Magnitude<1e-3 then return end
   p(name,V(thick,height,(b-a).Magnitude+.012),CFrame.lookAt((a+b)*.5,b),color,neon);if alpha then out[#out].Transparency=alpha end
  end
  local function hash(i,k)local x=math.sin(i*12.9898+k*78.233)*43758.5453;return x-math.floor(x)end
  local function dot(name,pos,size,color,alpha,spin)
   p(name,V(size,size,size),CF(pos)*CFrame.Angles(spin or 0,0,math.pi/4),color,neon);if alpha then out[#out].Transparency=alpha end
  end
  local widthScale=look and look.Width or 1
  for i=1,24 do
   local t=(i-.5)/24;local a,b=point((i-1)/24),point(i/24);local width=math.max(.02,Ribbon.Width(t))*widthScale;local col=Ribbon.Color(accent,t,id)
   seg('Full ribbon',a,b,.045,1.52*width,col)
   seg('Ribbon volume',a,b,1.02*width,.045,col)
   if look then seg('Ribbon core',a,b,.075,1.52*width*(look.CoreWidth+.08),Ribbon.Sample(look.Core,t),.15)end
  end
  local function motes(name,count,colors,spreadY,size)
   for i=1,count do
    local t=.08+.84*hash(i,1);local c=point(t)+V((hash(i,2)-.5)*1.4,(hash(i,3)-.5)*spreadY,0)
    dot(name,c,size*(1-t*.5),Ribbon.Sample(colors,hash(i,4)),.1,hash(i,5)*3)
   end
  end
  if tier>=1 then motes('Ribbon mote',2+tier*2,look.Core,2.2,.13)end
  if tier==2 then
   for i=1,6 do
    local t=.1+i*.12;local c=point(t);local side=i%2==1 and 1 or -1;local a=c+V(.15*side,.55*side,0);local b=a+V(.35*side,.28*side,.3)
    seg('Arc spark',a,b,.05,.05,Color3.fromRGB(230,248,255));seg('Arc spark',b,b+V(-.2*side,.32*side,.25),.05,.05,Color3.fromRGB(120,190,255))
   end
  elseif tier==3 then
   for i=1,9 do
    local t=.1+.8*hash(i,7);dot('Solar ember',point(t)+V((hash(i,8)-.5)*.9,.7+hash(i,9)*1.1,0),.14,Ribbon.Sample(look.Colors,hash(i,6)),.05)
   end
   p('Solar flare',V(.85,.85,.06),CF(0,2.45,.12)*CFrame.Angles(0,0,math.pi/4),Color3.fromRGB(255,226,120),neon);out[#out].Transparency=.3
   p('Solar flare',V(1.25,.12,.05),CF(0,2.45,.14),Color3.fromRGB(255,250,210),neon);out[#out].Transparency=.2
  elseif tier==4 then
   for i=1,16 do
    local t0,t1=(i-1)/16*.85,i/16*.85;local lift=function(t)return point(t)+V(0,1.15+math.sin(t*9)*.18,.15)end
    seg('Aurora veil',lift(t0),lift(t1),.04,.9*(1-t0*.7),Ribbon.Sample(look.Colors,(t0+.5)%1,.35),.45)
   end
  elseif tier==5 then
   local prev
   for i=0,28 do
    local t=i/28*.9;local ang=t*12;local c=point(t)+V(math.cos(ang)*1.0*(1-t*.4),math.sin(ang)*1.0*(1-t*.4),0)
    if prev then seg('Nebula swirl',prev,c,.07,.07,Ribbon.Sample({Color3.fromRGB(255,206,255),Color3.fromRGB(150,90,255),Color3.fromRGB(90,210,255)},t))end;prev=c
   end
   for i=1,6 do
    local c=point(.1+.8*hash(i,11))+V((hash(i,12)-.5)*1.8,(hash(i,13)-.5)*2.2,0);local size=.32+hash(i,14)*.2
    p('Nebula star',V(size,.05,.05),CF(c),Color3.fromRGB(255,244,255),neon);p('Nebula star',V(.05,size,.05),CF(c),Color3.fromRGB(255,170,245),neon)
   end
   for i=1,4 do
    local c=point(.2+.18*i)+V((hash(i,15)-.5)*.6,(hash(i,16)-.5)*.8,0)
    p('Nebula cloud',V(.9,.7,.5),CF(c)*CFrame.Angles(hash(i,17),hash(i,18),0),Ribbon.Sample(look.Colors,hash(i,19)),neon);out[#out].Transparency=.72
   end
  elseif tier>=6 then
   local gold,purple=Color3.fromRGB(255,206,64),Color3.fromRGB(150,60,230)
   for _,phase in ipairs({0,math.pi})do
    local prev
    for i=0,28 do
     local t=i/28*.9;local ang=t*11+phase;local r=1.0*(1-t*.35);local c=point(t)+V(math.cos(ang)*r,math.sin(ang)*r,0)
     if prev then seg(phase==0 and'Royal gold helix'or'Royal purple helix',prev,c,.08,.08,phase==0 and gold:Lerp(Color3.fromRGB(255,250,210),(1-t)*.5)or purple)end;prev=c
    end
   end
   for i=1,12 do
    local t0,t1=(i-1)/12,i/12;local w0,w1=Ribbon.Width(t0)*widthScale*.76,Ribbon.Width(t1)*widthScale*.76
    for _,side in ipairs({1,-1})do seg('Royal trim',point(t0)+V(0,w0*side,0),point(t1)+V(0,w1*side,0),.07,.07,gold)end
   end
   for i=1,5 do
    local t=.12+i*.15;local c=point(t)+V((hash(i,21)-.5)*1.2,(hash(i,22)-.5)*1.6,0)
    p('Royal jewel',V(.16,.26,.16),CF(c)*CFrame.Angles(0,hash(i,23)*3,math.pi/4),Ribbon.Sample({Color3.fromRGB(206,96,255),Color3.fromRGB(255,80,170),Color3.fromRGB(120,60,255)},hash(i,24)),neon)
   end
   for i=1,14 do dot('Royal glitter',point(.05+.9*hash(i,25))+V((hash(i,26)-.5)*1.6,(hash(i,27)-.5)*2.4,0),.07,Color3.fromRGB(255,232,140))end
   for _,x in ipairs({-.48,.48})do
    local c=V(x,.04,-.2);p('Step glint',V(.34,.05,.05),CF(c),Color3.fromRGB(255,240,170),neon);p('Step glint',V(.05,.05,.34),CF(c),Color3.fromRGB(255,240,170),neon)
   end
   p('Royal flare',V(.95,.95,.06),CF(0,2.45,.12)*CFrame.Angles(0,0,math.pi/4),Color3.fromRGB(255,226,140),neon);out[#out].Transparency=.35
  end
  -- R118: the head piece worn in game (Royal crown, Nebula space dust, Aurora halo), same geometry as the live one.
  local head=Ribbon.HeadPiece and Ribbon.HeadPiece(id,.85,.85,false)
  if head then
   local headFrame=CF(0,3.65,-.5)
   for _,sp in ipairs(head.Parts)do
    local ring=head.Rings[sp.Ring]or head.Rings[1]
    p(sp.Name,sp.Size,headFrame*CF(0,ring.Y,0)*sp.Offset,sp.Color,sp.Material);out[#out].Transparency=sp.Transparency;out[#out].Reflectance=sp.Reflectance
   end
  end
 elseif product.Id=='TreasureMagnet'then
  p('Magnet bridge',V(1.7,.55,.65),CF(0,0,0),accent,Enum.Material.Metal)
  for _,x in ipairs({-.7,.7})do
   p('Magnet arm',V(.45,1.35,.65),CF(x,.78,0),accent,Enum.Material.Metal)
   p('Silver pole',V(.48,.45,.69),CF(x,1.58,0),silver,Enum.Material.Metal)
   p('Pole stripe',V(.5,.09,.71),CF(x,1.40,0),dark)
  end
 elseif product.Id=='RunnerShield'then
  p('Shield rim',V(1.9,2.25,.3),CF(0,1.25,0),silver,Enum.Material.Metal)
  p('Shield plate',V(1.63,1.96,.35),CF(0,1.25,-.05),dark,Enum.Material.Metal)
  p('Shield crest',V(.72,.95,.15),CF(0,1.3,-.29)*CFrame.Angles(0,0,math.pi/4),accent,Enum.Material.Neon)
  for _,x in ipairs({-.66,.66})do for _,y in ipairs({.52,1.96})do p('Shield rivet',V(.13,.13,.13),CF(x,y,-.3),silver)end end
  p('Shield grip',V(.24,1,.35),CF(0,1.2,.36),dark)
 else
  p('Lantern base',V(1.3,.22,1.1),CF(0,.1,0),dark,Enum.Material.Metal)
  p('Lantern light',V(.72,1.25,.62),CF(0,.85,0),accent,Enum.Material.Neon)
  p('Lantern cap',V(1.3,.25,1.1),CF(0,1.59,0),dark,Enum.Material.Metal)
  for _,x in ipairs({-.51,.51})do for _,z in ipairs({-.42,.42})do p('Lantern frame',V(.12,1.4,.12),CF(x,.83,z),silver,Enum.Material.Metal)end end
  for _,x in ipairs({-.34,.34})do p('Handle side',V(.10,.58,.13),CF(x,1.99,0),silver,Enum.Material.Metal)end
  p('Handle top',V(.78,.1,.13),CF(0,2.25,0),silver,Enum.Material.Metal)
 end
 return out
end
function A.Build(product,biome)
 local model=Instance.new('Model');model.Name=product.Name or'Shop product'
 for _,s in ipairs(A.Specs(product,biome))do
  local p=Instance.new(s.Shape=='Wedge'and'WedgePart'or s.Shape=='CornerWedge'and'CornerWedgePart'or'Part');p.Name=s.Name;p.Size=s.Size;p.CFrame=s.Frame;p.Color=s.Color;p.Material=s.Material
  if s.Transparency then p.Transparency=s.Transparency end;if s.Reflectance then p.Reflectance=s.Reflectance end
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=model
 end
 return model
end
return A
