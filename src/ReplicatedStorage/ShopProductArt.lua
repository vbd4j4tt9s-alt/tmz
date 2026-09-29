-- R48: native 3D store samples. Boots use the exact wearable geometry.
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
   local function boot(specs,frame)for _,s in ipairs(specs)do p(s.Name,s.Size,frame*s.Frame,s.Color,s.Material,s.Shape)end end
   boot(Boots.Specs(V(1,.7,1.8),false,biome or'Forest',accent),CF(x,.39,0))
   boot(Boots.ShinSpecs(V(1.05,1.45,1.05),false,biome or'Forest',accent),CF(x,1.475,0))
   boot(Boots.KneeSpecs(V(1.1,1.4,1.1),false,biome or'Forest',accent),CF(x,2.90,0))
  end
 elseif product.Type=='Trail'then
  p('Runner body',V(1.65,1.85,.8),CF(0,2.3,-.5),dark)
  p('Runner head',V(.85,.85,.85),CF(0,3.65,-.5),silver)
  for _,x in ipairs({-.48,.48})do p('Runner leg',V(.64,1.4,.7),CF(x,.67,-.5)*CFrame.Angles(x*.35,0,0),dark)end
  for _,x in ipairs({-1.08,1.08})do p('Runner arm',V(.45,1.6,.6),CF(x,2.35,-.5)*CFrame.Angles(-x*.35,0,0),silver)end
  p('Chest badge',V(.55,.28,.06),CF(0,2.55,-.93),accent)
  local function point(t)return V(math.sin(t*3.9)*.45,2.40+math.sin(t*4.2)*.22,.22+t*7.4)end
  for i=1,24 do
   local t=(i-.5)/24;local a,b=point((i-1)/24),point(i/24);local f=CFrame.lookAt((a+b)*.5,b);local width=math.max(.02,Ribbon.Width(t));local col=Ribbon.Color(accent,t,product.Id)
   p('Full ribbon',V(.045,1.52*width,(b-a).Magnitude+.012),f,col,Enum.Material.Neon)
   p('Ribbon volume',V(1.02*width,.045,(b-a).Magnitude+.012),f,col,Enum.Material.Neon)
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
  local p=Instance.new(s.Shape=='Wedge'and'WedgePart'or'Part');p.Name=s.Name;p.Size=s.Size;p.CFrame=s.Frame;p.Color=s.Color;p.Material=s.Material
  p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.CastShadow=false;p.Parent=model
 end
 return model
end
return A
