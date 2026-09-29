-- R47: low-part-count footwear fitted to R6 legs and R15 feet; no collision or body-joint edits.
local A={}
local V,CF=Vector3.new,CFrame.new
local palettes={Forest={83,67,51},Jungle={49,82,60},Desert={135,102,64},Snow={92,128,157},Lava={66,47,43},Crystal={72,62,102},Storm={48,65,91}}
local trims={Forest={122,185,103},Jungle={142,187,74},Desert={233,192,113},Snow={190,233,251},Lava={255,140,53},Crystal={193,152,250},Storm={177,232,255}}
function A.Specs(size,r6,biome,accent)
 local w=math.clamp(size.X, .25,4);local d=math.clamp(size.Z,.35,5)
 local h=r6 and math.min(size.Y*.48,w*.92)or math.max(size.Y*.86,w*.62)
 local base=-size.Y*.5;local col=Color3.fromRGB(table.unpack(palettes[biome]or palettes.Forest));local trim=Color3.fromRGB(table.unpack(trims[biome]or trims.Forest))
 local dark=Color3.fromRGB(29,33,42);local specs={}
 local function part(name,z,c,k,mat,shape)table.insert(specs,{Name=name,Size=z,Frame=c,Color=k,Material=mat or Enum.Material.SmoothPlastic,Shape=shape})end
 part('Sole',V(w*1.15,w*.16,d*1.20),CF(0,base+w*.04,-d*.08),dark)
 part('Boot body',V(w*1.10,h*.67,d*1.10),CF(0,base+h*.37,-d*.08),col)
 part('Toe cap',V(w*1.13,h*.32,d*.50),CF(0,base+h*.31,-d*.50),col:Lerp(trim,.17),Enum.Material.Metal,'Wedge')
 part('Heel',V(w*1.12,h*.42,d*.27),CF(0,base+h*.27,d*.43),dark)
 part('Ankle cuff',V(w*1.13,h*.66,d*.64),CF(0,base+h*.88,d*.13),col:Lerp(trim,.25))
 part('Toe trim',V(w*.96,h*.075,d*.10),CF(0,base+h*.39,-d*.71),trim)
 part('Buckle',V(w*.25,h*.22,d*.08),CF(0,base+h*.90,-d*.21),accent or trim,Enum.Material.Metal)
 for _,side in ipairs({-1,1})do
  part('Sole piping',V(w*.06,w*.09,d*1.13),CF(side*w*.58,base+w*.12,-d*.10),trim)
 end
 return specs
end
function A.ShinSpecs(size,r6,biome,accent)
 local w,d=size.X,size.Z;local h=r6 and size.Y*.48 or size.Y*.94
 local y=r6 and(-size.Y*.5+size.Y*.49)or 0
 local col=Color3.fromRGB(table.unpack(palettes[biome]or palettes.Forest));local trim=Color3.fromRGB(table.unpack(trims[biome]or trims.Forest));local out={}
 local function p(name,z,c,k,mat)table.insert(out,{Name=name,Size=z,Frame=c,Color=k,Material=mat or Enum.Material.SmoothPlastic})end
 p('Tall boot shaft',V(w*1.10,h,d*1.08),CF(0,y,0),col)
 p('Shin guard',V(w*.87,h*.77,d*.15),CF(0,y,-d*.59),col:Lerp(trim,.22),Enum.Material.Metal)
 p('Upper cuff',V(w*1.16,h*.13,d*1.13),CF(0,y+h*.45,0),trim:Lerp(col,.6))
 for _,side in ipairs({-1,1})do p('Shin piping',V(w*.055,h*.75,d*.81),CF(side*w*.575,y,0),trim)end
 -- Each biome has its own silhouette, shared by the shop and wearable model.
 if biome=='Desert'then
  for _,step in ipairs({-.24,.22})do p('Sand leather wrap',V(w*1.14,h*.13,d*1.13),CF(0,y+h*step,0),trim:Lerp(col,.35))end
  p('Sandstone crest',V(w*.48,h*.38,d*.16),CF(0,y,-d*.72)*CFrame.Angles(0,0,.18),trim,Enum.Material.Sandstone)
 elseif biome=='Snow'then
  p('Frost fur cuff',V(w*1.30,h*.23,d*1.26),CF(0,y+h*.44,0),Color3.fromRGB(232,244,248),Enum.Material.Fabric)
  for _,side in ipairs({-1,1})do p('Ice fin',V(w*.16,h*.74,d*.36),CF(side*w*.58,y+h*.12,-d*.20)*CFrame.Angles(0,0,-side*.16),trim,Enum.Material.Glass)end
 elseif biome=='Lava'then
  for _,step in ipairs({-.26,0,.26})do p('Ember vent',V(w*.66,h*.065,d*.10),CF(0,y+h*step,-d*.72),trim,Enum.Material.Neon)end
  for _,side in ipairs({-1,1})do p('Volcanic plate',V(w*.22,h*.92,d*.85),CF(side*w*.61,y,0)*CFrame.Angles(0,0,side*.10),col,Enum.Material.Slate)end
 elseif biome=='Crystal'then
  for _,side in ipairs({-1,1})do
   p('Purple crystal fin',V(w*.23,h*.98,d*.42),CF(side*w*.62,y+h*.19,-d*.1)*CFrame.Angles(0,0,-side*.22),trim,Enum.Material.Neon)
  end
  p('Silver shin setting',V(w*.43,h*.77,d*.09),CF(0,y,-d*.72),Color3.fromRGB(197,205,221),Enum.Material.Metal)
  p('Crystal center',V(w*.22,h*.53,d*.10),CF(0,y,-d*.78),Color3.fromRGB(159,94,236),Enum.Material.Neon)
 elseif biome=='Storm'then
  for _,step in ipairs({-.27,.27})do p('Electric coil',V(w*1.26,h*.13,d*1.19),CF(0,y+h*step,0),trim,Enum.Material.Neon)end
  for i=1,3 do p('Lightning rail',V(w*.12,h*.26,d*.09),CF((i%2==0 and .07 or -.03)*w,y+(i-2)*h*.18,-d*.74)*CFrame.Angles(0,0,i%2==0 and -.7 or .6),Color3.fromRGB(222,253,255),Enum.Material.Neon)end
 end
 return out
end
function A.KneeSpecs(size,r6,biome,accent)
 local w,d=size.X,size.Z;local h=r6 and size.Y*.31 or math.max(size.Y*.34,w*.50)
 local y=r6 and(-size.Y*.5+size.Y*.65)or(-size.Y*.5+size.Y*.07)
 local col=Color3.fromRGB(table.unpack(palettes[biome]or palettes.Forest));local trim=Color3.fromRGB(table.unpack(trims[biome]or trims.Forest))
 return {
  {Name='Knee guard',Size=V(w*1.15,h,d*.25),Frame=CF(0,y,-d*.58),Color=col:Lerp(trim,.32),Material=Enum.Material.Metal},
  {Name='Knee crest',Size=V(w*.43,h*.44,d*.08),Frame=CF(0,y,-d*.745),Color=accent or trim,Material=Enum.Material.Metal},
 }
end
function A.Create(character,parent,biome,accent)
 local count=0
 for _,side in ipairs({'Left','Right'})do
  local foot=character:FindFirstChild(side..'Foot');local r6=false
  if not foot then foot=character:FindFirstChild(side..' Leg');r6=true end
  if foot and foot:IsA('BasePart')then
   local model=Instance.new('Model');model.Name=side..'RunnerBoot';model.Parent=parent
   local function build(target,specs)
   for _,s in ipairs(specs)do
    local p=Instance.new(s.Shape=='Wedge'and 'WedgePart'or 'Part');p.Name=s.Name;p.Size=s.Size;p.CFrame=target.CFrame*s.Frame;p.Color=s.Color;p.Material=s.Material
    p.Anchored=false;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=model
    local weld=Instance.new('WeldConstraint');weld.Part0=target;weld.Part1=p;weld.Parent=p
   end
   end
   build(foot,A.Specs(foot.Size,r6,biome,accent))
   local shin=r6 and foot or character:FindFirstChild(side..'LowerLeg')
   local knee=r6 and foot or character:FindFirstChild(side..'UpperLeg')
   if shin and shin:IsA('BasePart')then build(shin,A.ShinSpecs(shin.Size,r6,biome,accent))end
   if knee and knee:IsA('BasePart')then build(knee,A.KneeSpecs(knee.Size,r6,biome,accent))end
   count+=1
  end
 end
 return count
end
return A
