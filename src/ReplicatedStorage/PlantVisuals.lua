-- V149 revision 12: complete distant silhouettes, distinct flowers and bounded decorative motion.
local RS=game:GetService('ReplicatedStorage')
local Catalog=require(RS:WaitForChild('PlantCatalog'))
local Rules=require(RS:WaitForChild('PlantRules'))
local Hologram=require(RS:WaitForChild('HologramProjection'))
local PackRules=require(RS:WaitForChild('SeedPackRules'))
local Access=require(RS:WaitForChild('PlantAccessRules'))
local SupportArt=require(RS:WaitForChild('PlantSupportArt'))
local Growth=require(RS:WaitForChild('PlantGrowth'))
local Approved=require(RS:WaitForChild('ApprovedPlantArt'))
local ApprovedMeshes=require(RS:WaitForChild('ApprovedPlantMeshes'))
local SurfaceStyle=require(RS:WaitForChild('PlantSurfaceStyle'))
local styledApproved={}
local boundedOrders=setmetatable({},{__mode='k'})
local function remember(cache,key,value)
 local order=boundedOrders[cache];if not order then order={};boundedOrders[cache]=order end
 if not cache[key]then table.insert(order,key);if #order>64 then cache[table.remove(order,1)]=nil end end
 cache[key]=value;return value
end
local function styleKey(id,crop)return Approved.Key(id,crop)..SurfaceStyle.Key(id,crop)end
local function fruitTrait(crop,index,def)
 local item=crop._VisualHarvest
 if item and item.Index==index then return {Scale=item.Scale,Mutation=item.Mutation,Value=0}end
 return Rules.Fruit(crop,index,def)
end
local function approvedSpecs(id,crop)
 local art=Approved.Get(id,crop);if not art then return nil end
 if art.TreeRework or art.RarityRework or art.MechRework then return art.Specs end
 local key=styleKey(id,crop);if not styledApproved[key]then
  local def=table.clone(Catalog[id]);def.Sockets=art.Sockets;remember(styledApproved,key,SurfaceStyle.Apply(id,def,art.Specs,crop))
 end
 return styledApproved[key]
end
local growthStates={}
local V,CF=Vector3.new,CFrame.new
local Visuals={};local cache={};local prepared={};local sizedSpecs={}
local costs={Crystal=9,Shrub=3,ShrubProxy=1,Strawberry=7,Thunder=3,Canopy=3,Star=5,Bolt=2,Gem=4,Blade=4,TrapJaw=2,ProxyBlade=4,LeafBlade=7,Crown=22,Blob=1}
local surfaceCosts={grain=3,bark=2,foliage=3,vein=2,speckle=3,frost=3,ash=3,facet=3,cactus=15}
function Visuals.PartCost(s)return(costs[s.s]or 1)+(surfaceCosts[s.tx]or 0)end
local function growthHash(id,index)
 local h=173;local key=tostring(id or '')
 for i=1,#key do h=(h*33+string.byte(key,i))%2147483647 end
 return (h+index*104729)%2147483647
end
function Visuals.CrownVariant(cropId,index)
 local h=growthHash(cropId,index)
 local function unit(salt)return ((h*salt+7919)%65521)/65520 end
 return {X=.94+unit(31)*.12,Y=.89+unit(47)*.22,Z=.94+unit(71)*.12,Yaw=(unit(97)-.5)*.30,Tint=(unit(113)-.5)*.055,OffsetX=(unit(137)-.5)*.14,OffsetY=(unit(163)-.5)*.18,OffsetZ=(unit(191)-.5)*.14}
end
function Visuals.AssetRevision()return 46 end
local supportCache={}
function Visuals.SupportSpecs(id,crop)
 local art=approvedSpecs(id,crop);if art then return art end
 if SurfaceStyle.Key(id,crop)~=''then return Visuals.Specs(id,crop)end
 local key=styleKey(id,crop);if supportCache[key]then return supportCache[key]end
 local def=Catalog[id];local source=SupportArt[id]
 if not def or not source then return nil end
 local result={}
 for i,original in ipairs(source)do
  local spec=table.clone(original);spec._ArtIndex=i;spec.z=table.clone(original.z);spec.c=table.clone(original.c)
  for axis=1,3 do spec.z[axis]*=def.BaseScale;spec.c[axis]*=def.BaseScale end
  if spec.va then spec.va={spec.va[1]*def.BaseScale,spec.va[2]*def.BaseScale,spec.va[3]*def.BaseScale}end
  if spec.bp then spec.bp={spec.bp[1]*def.BaseScale,spec.bp[2]*def.BaseScale,spec.bp[3]*def.BaseScale}end
  result[i]=spec
 end
 result=SurfaceStyle.Apply(id,def,result,crop);return remember(supportCache,key,result)
end
function Visuals.Specs(id,crop)
 local art=approvedSpecs(id,crop);if art then return art end
 local def=Catalog[id];if not def then return nil end
 if not cache[def.ArtBiome or def.Biome]then cache[def.ArtBiome or def.Biome]=require(RS:WaitForChild('PlantArt'..(def.ArtBiome or def.Biome)))end
 local key=styleKey(id,crop);if sizedSpecs[key]then return sizedSpecs[key]end
 local source=cache[def.ArtBiome or def.Biome][id];if not source then return nil end
 local scale=def.BaseScale or 1;local result={}
 -- Scale each species once; saved PlantScale/FruitScale still apply independently.
 -- Keep raw authored descriptors immutable and preserve all grouping/materials.
 for index,original in ipairs(source)do
  local spec=table.clone(original);spec._ArtIndex=index;spec.z=table.clone(original.z);spec.c=table.clone(original.c)
  for axis=1,3 do spec.z[axis]*=scale;spec.c[axis]*=scale end
  if spec.va then spec.va={spec.va[1]*scale,spec.va[2]*scale,spec.va[3]*scale}end
  if spec.bp then spec.bp={spec.bp[1]*scale,spec.bp[2]*scale,spec.bp[3]*scale}end
  result[index]=spec
 end
 if id=='ElderbloomSeed'then
  result=require(RS:WaitForChild('ElderAppleArt')).Convert({Specs=result,Sockets=def.Sockets}).Specs
  for index,spec in ipairs(result)do spec._ArtIndex=index end
 end
 result=SurfaceStyle.Apply(id,def,result,crop);return remember(sizedSpecs,key,result)
end

local leafRanges={SunflowerSeed={6,9},SunflowerBloomSeed={2,4},BananaSeed={2,4},PineappleSeed={2,4},MonsteraSeed={2,4},LanternFernSeed={3,5},TigerOrchidSeed={2,4},AloeSeed={8,12},DatePalmSeed={5,7},SunKingPalmSeed={5,7},SnowdropSeed={6,9},FrostFernSeed={3,5},WinterPineSeed={2,4},CrystalLilySeed={5,7},SilentFrostbellSeed={2,4},PolarStarbloomSeed={2,4},FirePepperSeed={2,4},EmberBloomSeed={6,9},AshRoseSeed={6,9},LavaLotusSeed={5,7},SupernovaBloomSeed={2,4},AmethystSeed={2,4},PrismOrchidSeed={2,4},MoonflowerSeed={6,9},DiamondVineSeed={2,4},HollowGeodeSeed={7,10},OrbitLotusSeed={5,7},SparkReedSeed={2,4},ThunderTulipSeed={2,4},VoltOrchidSeed={2,4},TempestLotusSeed={5,7},BlackoutBloomSeed={2,4},StaticGrassSeed={2,4}}
local function leafRandom(cropId,index,salt)return ((growthHash(cropId,index)*salt+7919)%65521)/65520 end
function Visuals.LeafLayout(id,crop)
 if Approved.Has(id)then return nil end
 local range=leafRanges[id];if not range then return nil end
 local count=0;for _,s in ipairs(Visuals.Specs(id))do count=math.max(count,s.vg or 0)end
 local order={};for i=1,count do table.insert(order,i)end
 table.sort(order,function(a,b)return leafRandom(crop.Id,a,137)<leafRandom(crop.Id,b,137)end)
 local selected={};local n=range[1]+growthHash(crop.Id,13)%(range[2]-range[1]+1)
 for i=1,n do selected[order[i]]=true end
 return {Count=n,Selected=selected,Order=order}
end
function Visuals.LeafSpec(s,crop,layout)
 if not s.vg or not layout then return s end
 if not layout.Selected[s.vg]then return nil end
 if s.vf then return s end
 local i=s.vg;local anchor=V(table.unpack(s.va));local at=CF(table.unpack(s.c))
 local amount=.82+leafRandom(crop.Id,i,53)*.26
 local turn=CFrame.Angles((leafRandom(crop.Id,i,73)-.5)*.20,(leafRandom(crop.Id,i,97)-.5)*.70,(leafRandom(crop.Id,i,113)-.5)*.14)
 local position=anchor+turn:VectorToWorldSpace(at.Position-anchor)*amount
 local result=table.clone(s);result.c={ (CF(position)*turn*at.Rotation):GetComponents() }
 local width=(s.s=='LeafBlade'or s.s=='ProxyBlade')and(.80+leafRandom(crop.Id,i,151)*.36)or 1
 result.z={s.z[1]*amount*width,s.z[2]*amount,s.z[3]*amount*width}
 local tint=(leafRandom(crop.Id,i,181)-.5)*16;result.k={math.clamp(s.k[1]+tint,0,255),math.clamp(s.k[2]+tint,0,255),math.clamp(s.k[3]+tint*.55,0,255)}
 return result
end
-- Exact selected-leaf cost, cached by each client crop record.
function Visuals.DetailCost(id,crop)
 local layout=Visuals.LeafLayout(id,crop);local cost=1
 for _,s in ipairs(Visuals.Specs(id,crop)or{})do
  if not s.vg or not layout or layout.Selected[s.vg]then cost+=Visuals.PartCost(s)end
 end
 return cost
end
function Visuals.FruitSocket(crop,def,index)
 local socket=V(table.unpack(def.Sockets[index]or{0,1,0}))
 local id=crop.SeedId; if not id or Catalog[id]~=def then for candidate,d in pairs(Catalog)do if d==def then id=candidate;break end end end
 if not id then return socket end
 local art=Approved.Get(id,crop);if art then return V(table.unpack(art.Sockets[index]))end
 if id=='ElderbloomSeed'then
  -- Elder apples hang below their crown; the former flower socket hid them inside foliage.
  local crown;local distance=math.huge
  for _,s in ipairs(Visuals.Specs(id,crop))do if s.r=='Canopy'then
   local dx,dz=s.c[1]-socket.X,s.c[3]-socket.Z;local d=dx*dx+dz*dz
   if d<distance then crown=s;distance=d end
  end end
  if crown then
   local v=Visuals.CrownVariant(crop.Id,crown._ArtIndex);local z=V(table.unpack(crown.z))
   local at=CF(table.unpack(crown.c))*CF(z.X*v.OffsetX,z.Y*v.OffsetY,z.Z*v.OffsetZ)*CFrame.Angles(0,v.Yaw,0)
   return at:PointToWorldSpace(V(0,-z.Y*v.Y*.47,0))
  end
 end
 local body
 for _,s in ipairs(Visuals.Metadata(id).Groups[index]or{})do if s.canopy then body=s;break end end
 if not body then return socket end
 local crown=Visuals.Specs(id)[body.canopy];local v=Visuals.CrownVariant(crop.Id,crown._ArtIndex)
 local size=V(table.unpack(crown.z));local at=CF(table.unpack(crown.c))*CF(size.X*v.OffsetX,size.Y*v.OffsetY,size.Z*v.OffsetZ)*CFrame.Angles(0,v.Yaw,0)
 local d=body.cd;return at:PointToWorldSpace(V(size.X*v.X*d[1],size.Y*v.Y*d[2],size.Z*v.Z*d[3]))
end

-- Prepared once per seed, shared by every crop and harvest preview.
function Visuals.Metadata(id,crop)
 local key=styleKey(id,crop)
 if prepared[key]then return prepared[key]end
 local specs=Visuals.Specs(id,crop);if not specs then return nil end
 local meta={Cost=1,MeshTriangles=0,Groups={},Proxies={},ProxyLimit=(id=='SunflowerSeed'or id=='SnowdropSeed'or id=='MoonflowerSeed')and 20 or id=='StormSovereignSeed'and 8 or id=='BananaSeed'and 25 or id=='SilentFrostbellSeed'and 14 or(id=='FirePepperSeed'or id=='PrismOrchidSeed')and 7 or Catalog[id].Name=='Ember Pumpkin'and 11 or id=='StrawberrySeed'and 8 or id=='DragonfruitSeed'and 10 or id=='DesertRoseSeed'and 7 or 6}
 for _,s in ipairs(specs)do
  meta.Cost+=Visuals.PartCost(s)
  -- Native geometry only; imported mesh triangle cost is zero.
  meta.Groups[s.g]=meta.Groups[s.g]or{};table.insert(meta.Groups[s.g],s)
 end
 for index,list in pairs(meta.Groups)do
  local chosen={};local total=0
  for _,original in ipairs(list)do
   local simple=table.clone(original);simple.tx=nil
   if simple.s=='Crystal'then simple.s='Gem' end
   if simple.s=='LeafBlade'then simple.s='ProxyBlade'end
   table.insert(chosen,simple);total+=Visuals.PartCost(simple)
  end
  meta.Proxies[index]=chosen;meta.ProxyLimit=math.max(meta.ProxyLimit,total)
 end
 return remember(prepared,key,meta)
end
function Visuals.Coat(model,mutation)
 mutation=Rules.Mutation(mutation);model:SetAttribute('Mutation',mutation)
 if mutation=='None'then return end
 for i,p in ipairs(model:GetDescendants())do
  if p:IsA('BasePart')and p.Transparency<.95 then
   local variation=(i%4)/4
   p.Color=mutation=='Gold'and Color3.fromRGB(224+variation*23,162+variation*37,52+variation*25)or Color3.fromRGB(175+variation*65,224+variation*30,255)
   p.Material=mutation=='Gold'and Enum.Material.Metal or Enum.Material.Glass
   p.Reflectance=mutation=='Gold'and .20 or .16
   p.Transparency=mutation=='Diamond'and math.max(.15,math.min(p.Transparency,.3))or 0
  end
 end
end
local function frame(c,scale)
 return CF(c[1]*scale,c[2]*scale,c[3]*scale,c[4],c[5],c[6],c[7],c[8],c[9],c[10],c[11],c[12])
end
local function make(parent,name,size,cf,color,material,transparency,shape,solid)
 local part=Instance.new(shape=='Wedge'and 'WedgePart'or shape=='Corner'and 'CornerWedgePart'or 'Part');part.Name=name
 if shape=='Cylinder'then part.Shape=Enum.PartType.Cylinder end
 part.Size=V(math.max(.01,size.X),math.max(.01,size.Y),math.max(.01,size.Z));part.CFrame=cf
 part.Color=color;part.Material=material;part.Transparency=transparency
 part.Anchored=true;part.CanCollide=solid==true;part.CanTouch=false;part.CanQuery=solid==true
 part.TopSurface=Enum.SurfaceType.Smooth;part.BottomSurface=Enum.SurfaceType.Smooth
 if shape=='Ball'then
  -- PartType.Ball cannot represent a flattened petal or stretched rind band.
  -- The built-in Sphere mesh scales with the host block's size; no asset ID/upload.
  local mesh=Instance.new('SpecialMesh');mesh.Name='AuthoredEllipsoid';mesh.MeshType=Enum.MeshType.Sphere
  mesh.Scale=Vector3.one;mesh.Parent=part
 end
 part.CastShadow=false;part.Parent=parent;return part
end
function Visuals.Part(parent,s,origin,scale,solid,mutation,positionOverride,growthVariant)
 local size=V(table.unpack(s.z))*scale;local cf=origin*frame(s.c,scale)
 local shift=positionOverride and(positionOverride-cf.Position)or V(0,0,0)
 if positionOverride then cf=CF(positionOverride)*cf.Rotation end
 local color=Color3.fromRGB(table.unpack(s.k));local mat=Enum.Material[s.m]or Enum.Material.SmoothPlastic
 local alpha=s.t;mutation=Rules.Mutation(mutation)
 if mutation=='Gold'then color=Color3.fromRGB(232,172+(s.k[2]%22),57);mat=Enum.Material.Metal;alpha=0
 elseif mutation=='Diamond'then color=Color3.fromRGB(188+(s.k[1]%50),238,255);mat=Enum.Material.Glass;alpha=.18 end
 local first
 local function p(name,z,f,shape)
  local item
  if s.mesh then
   item=ApprovedMeshes.Get(s.mesh,mutation~='None'):Clone();item.Name=s.f or name;item.Size=z;item.CFrame=f;item.Color=color;item.Material=mat;item.Transparency=alpha
   item.Anchored=true;item.CanCollide=solid==true;item.CanQuery=solid==true;item.CanTouch=false;item.CastShadow=false;item.Parent=parent
  else item=make(parent,s.f or name,z,f,color,mat,alpha,shape,solid)end
  if scale>10 then game:GetService('CollectionService'):AddTag(item,'GiantVisualPart')end
  if s.shaded then item:SetAttribute('PlantSurfaceShading',true)end
  if s.hologram then item:SetAttribute('HologramFrame',origin:ToObjectSpace(f));item.CanCollide=false end
  if s.mech then item:SetAttribute('MechFixed',s.mechFixed==true);item:SetAttribute('MechGroup',s.mechGroup)end
  if s.tm then
   item:SetAttribute('TreeMotion',s.tm);item:SetAttribute('TreeMotionPivot',origin*CF(Vector3.new(table.unpack(s.tp))*scale));item:SetAttribute('TreeMotionScale',scale)
   item:SetAttribute('TreePhase',s.ph or 0);item:SetAttribute('TreeRate',s.rate or .1)
  end
  if s.pulse then item:SetAttribute('TreeLightningAt',s.pulse);item:SetAttribute('TreeLightningTrail',s.trail or 0)end
  if s.maw then item:SetAttribute('MawJaw',s.maw);item:SetAttribute('MawSide',s.mawSide);item:SetAttribute('MawPivot',CF(shift)*origin*frame(s.mawFrame,scale))end
  if s.bell then item:SetAttribute('BellIndex',s.bell);item:SetAttribute('BellPivot',origin:PointToWorldSpace(V(table.unpack(s.bp))*scale)+shift)end
  if s.vg then item:SetAttribute('LeafVariantGroup',s.vg)end
  if s.float then item:SetAttribute('FloatingPetal',true)end
  item:SetAttribute('GrowthGroup',s.g or 0);item:SetAttribute('GrowthRole',s.r or '');item:SetAttribute('GrowthForm',s.s)
  if s.f then item:SetAttribute('HarvestFeature',s.f)end
  if s._ArtIndex then item:SetAttribute('ArtSpecIndex',s._ArtIndex)end
  if mutation~='None'then item.Reflectance=mutation=='Gold'and .20 or .16 end
  first=first or item;return item
 end
 local function sculptedLeaf(z,at,name,distant)
  -- Pointed diamond outline with a folded ridge; native triangular solids on both sides.
  local shoulder=-z.Y*.10
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do
   local length=z.Y*(y==1 and .60 or .40)
   local turn=y==1 and(x==-1 and math.pi/2 or -math.pi/2)or(x==-1 and -math.pi/2 or math.pi/2)
   local facet=p(name,V(z.Z*.55,length,z.X*.50),at*CF(0,shoulder,0)*CFrame.Angles(0,x*.16,0)*CF(x*z.X*.25,y*length*.5,0)*CFrame.Angles(0,0,y==1 and 0 or math.pi)*CFrame.Angles(0,turn,0),'Wedge')
   if mutation=='None'and x==1 then facet.Color=color:Lerp(Color3.fromRGB(232,241,219),.13)end
  end end
  if not distant then
   local vein=p('Leaf midrib',V(math.max(.012,z.X*.045),z.Y*.78,math.max(.012,z.Z*.20)),at*CF(0,-z.Y*.02,z.Z*.24),'Block')
   for _,side in ipairs({-1,1})do
    local a=V(0,-z.Y*.06,z.Z*.24);local b=V(side*z.X*.27,z.Y*.12,z.Z*.24);local delta=b-a;local y=delta.Unit;local x=y:Cross(V(0,0,1)).Unit
    local branch=p('Leaf vein',V(z.X*.024,delta.Magnitude,z.Z*.12),at*CFrame.fromMatrix((a+b)*.5,x,y,x:Cross(y)),'Block')
    branch.Name='Leaf vein';branch:SetAttribute('PlantSurfaceDetail','vein');if mutation=='None'then branch.Color=color:Lerp(Color3.fromRGB(212,230,177),.22)end
   end
   vein.Name='Leaf midrib';vein:SetAttribute('PlantSurfaceDetail','vein')
   if mutation=='None'then vein.Color=color:Lerp(Color3.fromRGB(223,238,208),.30)end
  end
 end
 if s.s=='ApprovedMesh'then p(s.f,size,cf,'Block')
 elseif s.s=='CylinderX'then p(s.f,size,cf,'Cylinder')
 elseif s.s=='Corner'then p(s.f,size,cf,'Corner')
 elseif s.s=='LeafBlade'then sculptedLeaf(size,cf,s.f or 'Folded leaf')
 elseif s.s=='Crystal'then
  local shaft=p('Crystal prism',V(size.X,size.Y*.52,size.Z),cf*CF(0,-size.Y*.045,0),'Block')
  for _,endSign in ipairs({-1,1})do
   local height=size.Y*(endSign==1 and .285 or .195)
   local center=size.Y*(endSign==1 and .3575 or -.4025)
   for i=0,3 do
    local angle=i*math.pi/2;local turn=CFrame.Angles(0,angle,0)
    local width=i%2==0 and size.X or size.Z;local depth=i%2==0 and size.Z or size.X
    local at=cf*CF(0,center,0)*(endSign==-1 and CFrame.Angles(math.pi,0,0)or CF())*turn*CF(-width*.25,0,depth*.25)
    local tip=p('Crystal point',V(width*.5,height,depth*.5),at,'Corner')
    if mutation=='None'then tip.Color=color:Lerp(i%2==0 and Color3.fromRGB(246,255,255)or Color3.fromRGB(62,85,159),i%2==0 and .22 or .10)end
   end
  end
 elseif s.s=='Strawberry'then
  -- Twin rounded shoulders and an overlapping middle soften the pointed native taper.
  p('Strawberry shoulder',V(size.X*.62,size.Y*.54,size.Z*.88),cf*CF(-size.X*.19,size.Y*.20,0),'Ball')
  p('Strawberry shoulder',V(size.X*.62,size.Y*.54,size.Z*.88),cf*CF(size.X*.19,size.Y*.20,0),'Ball')
  p('Strawberry body',V(size.X*.94,size.Y*.70,size.Z*.88),cf*CF(0,size.Y*.02,0),'Ball')
  for i=0,3 do
   local turn=CFrame.Angles(0,i*math.pi/2,0);local width=i%2==0 and size.X or size.Z;local depth=i%2==0 and size.Z or size.X
   p('Strawberry taper',V(width*.16,size.Y*.22,depth*.16),cf*CF(0,-size.Y*.39,0)*CFrame.Angles(math.pi,0,0)*turn*CF(-width*.08,0,depth*.08),'Corner')
  end
 elseif s.s=='Shrub'or s.s=='ShrubProxy'then
  local v=growthVariant or{X=1,Y=1,Z=1,Yaw=0,Tint=0}
  local z=V(size.X*v.X,size.Y*v.Y,size.Z*v.Z)
  local at=cf*CF(size.X*(v.OffsetX or 0),size.Y*(v.OffsetY or 0),size.Z*(v.OffsetZ or 0))*CFrame.Angles(0,v.Yaw,0)
  if s.s=='ShrubProxy'then p('Leaf canopy',z,at,'Block')else
  local core=p('Leaf canopy',V(z.X*.92,z.Y*.80,z.Z*.96),at,'Block')
  local top=p('Canopy highlight',V(z.X*.62,z.Y*.32,z.Z*.68),at*CF(-z.X*.06,z.Y*.35,-z.Z*.03),'Block')
  local side=p('Canopy lobe',V(z.X*.38,z.Y*.59,z.Z*.71),at*CF(z.X*.33,-z.Y*.06,z.Z*.035),'Block')
  if mutation=='None'then
   core.Color=color:Lerp(v.Tint>0 and Color3.new(1,1,1)or Color3.new(0,0,0),math.abs(v.Tint))
   top.Color=core.Color:Lerp(Color3.fromRGB(240,240,218),.16);side.Color=core.Color:Lerp(Color3.fromRGB(21,29,38),.13)
  end
  end
 elseif s.s=='Blob'then
  local v=growthVariant or{X=1,Y=1,Z=1,Yaw=0,Tint=0}
  local z=V(size.X*v.X,size.Y*v.Y,size.Z*v.Z);local at=cf*CF(size.X*(v.OffsetX or 0),size.Y*(v.OffsetY or 0),size.Z*(v.OffsetZ or 0))*CFrame.Angles(0,v.Yaw,0)
  local body=p('Green crown',z,at,'Ball')
  if mutation=='None'then body.Color=color:Lerp(v.Tint>0 and Color3.new(1,1,1)or Color3.new(0,0,0),math.abs(v.Tint))end
 elseif s.s=='Crown'then
  -- A compact inner mass joins three broad overlapping leaf lobes.
  p('Leaf cluster core',V(size.X*.76,size.Y*.68,size.Z*.76),cf*CF(0,-size.Y*.08,0),'Ball')
  local span=math.max(size.X,size.Z)
  for i=0,2 do
   local angle=i*math.pi*2/3+.38
   local at=cf*CF(math.cos(angle)*size.X*.12,size.Y*.04,math.sin(angle)*size.Z*.12)*CFrame.Angles(0,-angle,0)*CFrame.Angles(math.pi/2-.32,0,0)
   sculptedLeaf(V(span*.60,span*.82,math.max(size.Y*.20,span*.075)),at,'Cluster leaf')
  end
 elseif s.s=='TrapJaw'then
  p('Trap jaw',V(size.X,size.Y*.84,size.Z),cf*CF(0,-size.Y*.08,0),'Ball')
  p('Trap jaw tip',V(size.X*.47,size.Y*.40,size.Z*.65),cf*CF(0,size.Y*.28,0),'Ball')
 elseif s.s=='Petal'then p(s.r,size,cf,'Ball')
 elseif s.s=='Cylinder'then p(s.r,V(size.Y,size.X,size.Z),cf*CFrame.Angles(0,0,math.pi/2),'Cylinder')
 elseif s.s=='Canopy'then
  -- Three clean stepped volumes: no intersecting wedge tips or raised corner shards.
  p('Leaf crown',V(size.X,size.Y*.65,size.Z),cf*CF(0,-size.Y*.125,0),'Block')
  p('Leaf top',V(size.X*.80,size.Y*.30,size.Z*.82),cf*CF(0,size.Y*.35,0),'Block')
  p('Leaf underside',V(size.X*.82,size.Y*.10,size.Z*.84),cf*CF(0,-size.Y*.45,0),'Block')
 elseif s.s=='Star'then
  for i=0,4 do
   local angle=i*math.pi*2/5
   local f=cf*CFrame.Angles(0,0,angle)
   p('Starfruit ridge',V(size.X*.34,size.Y*.55,size.Z),f*CF(0,size.Y*.19,0),'Wedge')
  end
 elseif s.s=='Thunder'then
  local function arm(a,b)
   local d=(b-a).Unit;local x=V(0,0,1);local z=x:Cross(d)
   p('Lightning arm',V(size.Z,(b-a).Magnitude,size.X*.32),cf*CFrame.fromMatrix((a+b)*.5,x,d,z),'Wedge')
  end
  arm(V(-size.X*.22,size.Y*.04,0),V(size.X*.26,size.Y*.46,0))
  p('Lightning bridge',V(size.X*.57,size.Y*.20,size.Z),cf*CF(0,size.Y*.04,0),'Block')
  arm(V(size.X*.22,size.Y*.04,0),V(-size.X*.22,-size.Y*.46,0))
 elseif s.s=='Bolt'then
  -- Wedge extrusion is local X; turn it so the lightning silhouette is in the XY plane.
  p('Electric bolt',V(size.Z,size.Y*.65,size.X*.9),cf*CF(-size.X*.05,size.Y*.175,0)*CFrame.Angles(0,math.pi/2,0),'Wedge')
  p('Electric bolt',V(size.Z,size.Y*.65,size.X*.9),cf*CF(size.X*.05,-size.Y*.175,0)*CFrame.Angles(0,0,math.pi)*CFrame.Angles(0,math.pi/2,0),'Wedge')
 elseif s.s=='ProxyGem'then
  -- One tipped solid preserves a distant crystal cluster instead of spending its budget on one gem.
  p('Distant crystal',size,cf,'Block')
 elseif s.s=='ProxyBlade'then
  sculptedLeaf(size,cf,s.f or 'Distant leaf',true)
 elseif s.s=='Gem'or s.s=='Blade'then
  -- Four triangular facets make a true diamond silhouette from the front.
  for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do
   local turn=y==1 and (x==-1 and math.pi/2 or -math.pi/2)or(x==-1 and -math.pi/2 or math.pi/2)
   p('Crystal facet',V(size.Z,size.Y*.5,size.X*.5),cf*CF(x*size.X*.25,y*size.Y*.25,0)*CFrame.Angles(0,0,y==1 and 0 or math.pi)*CFrame.Angles(0,turn,0),'Wedge')
  end end
 elseif s.s=='Wedge'then p(s.r,size,cf,'Wedge')
 else p(s.r,size,cf,(s.s=='Ball'or s.s=='Leaf')and 'Ball'or 'Block') end
 if first and s.tx and not solid then
  local z=first.Size;local at=first.CFrame;local surface=s.tx
  local function mark(name,sz,localFrame,tint,shape)
   local c=mutation=='None'and color:Lerp(tint,.23)or color
   local detail=make(parent,name,sz,at*localFrame,c,mat,alpha,shape or 'Ball',false)
   detail:SetAttribute('PlantSurfaceDetail',surface)
   if s.maw then detail:SetAttribute('MawJaw',s.maw);detail:SetAttribute('MawSide',s.mawSide);detail:SetAttribute('MawPivot',CF(shift)*origin*frame(s.mawFrame,scale))end
   detail:SetAttribute('GrowthGroup',s.g or 0);detail:SetAttribute('GrowthRole',s.r or '');detail:SetAttribute('GrowthForm',s.s)
   if s._ArtIndex then detail:SetAttribute('ArtSpecIndex',s._ArtIndex)end
   return detail
  end
  local round=first:FindFirstChildOfClass('SpecialMesh')~=nil
  local function surfacePoint(x,y,back)
   local depth=round and math.sqrt(math.max(.04,1-4*x*x-4*y*y))*.5 or .5
   return V(x*z.X,y*z.Y,(depth-.018)*z.Z*(back and -1 or 1))
  end
  local function tangentFrame(pt)
   if not round then return CF(pt)end
   local n=V(pt.X/(z.X*z.X),pt.Y/(z.Y*z.Y),pt.Z/(z.Z*z.Z)).Unit
   local x=V(0,1,0):Cross(n).Unit;local y=n:Cross(x)
   return CF(pt.X,pt.Y,pt.Z,x.X,y.X,n.X,x.Y,y.Y,n.Y,x.Z,y.Z,n.Z)
  end
  if surface=='bark'then
   for j=1,2 do
    local x=j==1 and -.18 or .20;local pt=surfacePoint(x,j==1 and -.08 or .14,false)
    mark('Bark grain groove',V(z.X*.045,z.Y*(j==1 and .59 or .43),math.max(.012,z.Z*.035)),tangentFrame(pt),Color3.fromRGB(17,19,29),'Block')
   end
  elseif surface=='cactus'then
   -- Curved inset ribs and areoles are actual geometry on the rounded pad.
   for col=-1,1 do
    local x=col*.20
    for row=0,1 do
     local a=surfacePoint(x,-.30+row*.30,false);local b=surfacePoint(x,row*.30,false)
     local d=b-a;local f=CF((a+b)*.5)*CFrame.Angles(math.atan2(d.Z,d.Y),0,0)
     mark('Cactus rib',V(z.X*.032,d.Magnitude+z.X*.02,z.Z*.045),f,Color3.fromRGB(172,210,116))
    end
   end
   for j=1,6 do
    local x=j%2==0 and -.22 or .22;local y=(math.ceil(j/2)-2)*.20;local pt=surfacePoint(x,y,false)
    mark('Cactus areole',V(z.X*.070,z.Y*.031,z.Z*.065),CF(pt),Color3.fromRGB(227,219,151))
    if j%2==0 then mark('Cactus short spine',V(z.X*.020,z.Y*.025,z.Z*.18),CF(pt+V(0,0,z.Z*.065))*CFrame.Angles(-.35,.22,0),Color3.fromRGB(242,236,194))end
   end
  else
   local count=surfaceCosts[surface]or 0
   for j=1,count do
    local x=({-.19,.14,.26})[j];local y=({.12,-.18,.19})[j]
    local pt=surfacePoint(x,y,j==3 and surface=='foliage')
    local tint=surface=='grain'and(j%2==0 and Color3.fromRGB(37,46,45)or Color3.fromRGB(226,233,203))or surface=='ash'and Color3.fromRGB(95,89,81)or surface=='frost'and Color3.fromRGB(226,249,255)or surface=='foliage'and Color3.fromRGB(148,196,101)or Color3.fromRGB(242,225,159)
    local w=surface=='grain'and .21 or surface=='foliage'and .14 or surface=='vein'and .30 or .065
    local h=surface=='grain'and .022 or surface=='foliage'and .065 or surface=='vein'and .025 or .045
    mark('Plant surface marking',V(z.X*w,z.Y*h,math.max(z.Z*.055,math.min(z.X,z.Y)*.012)),tangentFrame(pt)*CFrame.Angles(0,0,j*.63),tint)
   end
  end
 end
 return first
end
local function visible(crop,stage,group,now)
 return group==0 or(stage==4 and Rules.FruitReady(crop,group,now))
end
local connectors={['Heartfruit stem']=true,['Tomato stem']=true,['Lantern pedicel']=true,['Apple hanging stem']=true,['Pitcher climbing stem']=true,['Arched hanging stem']=true,['Fruit stem']=true,['Cocoa pedicel']=true,['Berry pedicel']=true,['Socket support']=true,['Frostbell hanger']=true,['Frostbell neck']=true,['Sunflower neck']=true,['Curved trap stem']=true,['Obsidian basal leaf']=true}
function Visuals.HarvestSpec(id,s)
 if connectors[s.f]then return false end
 if id=='ObsidianMawSeed'then return s.maw==3 or s.maw==4 or(s.f=='Joined trap hinge'and math.abs(s.c[1])<1)end
 if s.r=='Stem'and not s.maw and s.f~='Frostbell clapper thread'then return false end
 return true
end
-- Check only meshes used by this crop/selection before starting a resumable client build.
-- Growing art builds the complete sculpture then animates it, so regrowing fruit is included.
function Visuals.DetailReady(id,crop,selected)
 local def=Catalog[id];local specs=Visuals.Specs(id,crop)
 if not def or not specs then return true end
 local layout=Visuals.LeafLayout(id,crop);local checked={};local traits={}
 for _,original in ipairs(specs)do
  if not original.mesh or(selected and not selected[original.g])then continue end
  local spec=Visuals.LeafSpec(original,crop,layout);if not spec then continue end
  if crop._DetachedHarvest and not Visuals.HarvestSpec(id,spec)then continue end
  local mutation=crop.Mutation
  if spec.g>0 and def.Mode~='whole'then
   traits[spec.g]=traits[spec.g]or fruitTrait(crop,spec.g,def);mutation=traits[spec.g].Mutation
  end
  local neutral=Rules.Mutation(mutation)~='None';local key=spec.mesh..(neutral and'_Neutral'or'')
  if not checked[key]then
   checked[key]=true
   local state,message=ApprovedMeshes.Status(spec.mesh,neutral)
   if state~='Ready'then return false,key,message end
  end
 end
 return true
end
function Visuals.Build(id,origin,crop,stage,now,onlyFruit,work)
 if stage and stage<4 and not onlyFruit then return Visuals.BuildGrowing(id,origin,crop,now or os.time(),stage,work)end
 local def=Catalog[id];local specs=Visuals.Specs(id,crop);local model=Instance.new('Model');model.Name=onlyFruit and 'HarvestItem'or 'PlantArt'
 if work then work.Model(model)end
 if not specs then return model end
 crop=crop or {PlantScale=1,SeedScale=1,Id='preview',Mutation='None',HarvestCycle=0,PickedMask=0,ReadyAt=0}
 local scale=Rules.Scale(crop.PlantScale);stage=stage or 4;now=now or math.huge
 local groups={};local traits={};local any=false;local layout=Visuals.LeafLayout(id,crop)
 if layout then model:SetAttribute("LeafCount",layout.Count)end
 for _,original in ipairs(onlyFruit and Visuals.Metadata(id,crop).Groups[onlyFruit]or specs)do
  local s=Visuals.LeafSpec(original,crop,layout);if not s then continue end
  if onlyFruit and s.g~=onlyFruit then continue end
  if crop._DetachedHarvest and not Visuals.HarvestSpec(id,s)then continue end
  if stage<4 and s.r~='Stem'then continue end
  if not visible(crop,stage,s.g,now)then continue end
  local target=groups[s.g]
  if not target then target=Instance.new('Model');target.Name=s.g==0 and 'PlantBase'or 'Harvest_'..s.g;target:SetAttribute('HarvestIndex',s.g);target:SetAttribute('FruitCycle',Rules.FruitCycle(crop,s.g));target.Parent=model;groups[s.g]=target end
  local visualScale=scale;local mutation=crop.Mutation;local override=nil
  if s.g>0 and def.Mode~='whole'then
   local trait=traits[s.g]
   if not trait then trait=fruitTrait(crop,s.g,def);traits[s.g]=trait end
   visualScale=trait.Scale;mutation=trait.Mutation
   local authored=Visuals.AuthoredSocket(id,crop,s.g);local socket=Visuals.FruitSocket(crop,def,s.g);local pos=V(s.c[1],s.c[2],s.c[3]);override=origin:PointToWorldSpace(socket*scale+(pos-authored)*visualScale)
   target:SetAttribute('Mutation',mutation);target:SetAttribute('FruitScale',visualScale)
  end
  local grow=stage==4 and 1 or ({.32,.65,1})[stage]
  local variant=(s.s=='Blob'or s.s=='Shrub')and Visuals.CrownVariant(crop.Id,s._ArtIndex or 1)or nil
  if work then work.BeforePart(Visuals.PartCost(s))end
  Visuals.Part(target,s,origin,visualScale*grow,false,mutation,override,variant);any=true
 end
 if not any and stage<4 then
  make(model,'Growing stem',V(.22,stage*.65,.22)*scale,origin*CF(0,stage*.325*scale,0),Color3.fromRGB(81,135,75),Enum.Material.SmoothPlastic,0,'Cylinder',false)
 end
 for group,target in pairs(groups)do if group>0 then for _,part in ipairs(target:GetDescendants())do if part:IsA('BasePart')then part.CanQuery=true end end end end
 local pivot=Instance.new('Part');pivot.Name='VisualPivot';pivot.Size=V(.05,.05,.05);pivot.CFrame=origin
 pivot.Transparency=1;pivot.Anchored=true;pivot.CanCollide=false;pivot.CanQuery=false;pivot.CanTouch=false;pivot.Parent=model;model.PrimaryPart=pivot
 return model
end
function Visuals.BuildSelectedFruit(id,origin,crop,selected,now,work)
 local model=Instance.new('Model');model.Name='PlantArt';if work then work.Model(model)end
 for index=1,Catalog[id].FruitCount do if selected[index]then
  local art=Visuals.Build(id,origin,crop,4,now,index,work)
  local fruit=art:FindFirstChild('Harvest_'..index);if fruit then fruit.Parent=model end
  art:Destroy()
 end end
 local pivot=Instance.new('Part');pivot.Name='VisualPivot';pivot.Size=Vector3.new(.05,.05,.05);pivot.CFrame=origin
 pivot.Anchored=true;pivot.Transparency=1;pivot.CanCollide=false;pivot.CanQuery=false;pivot.CanTouch=false;pivot.Parent=model;model.PrimaryPart=pivot
 return model
end
function Visuals.Supports(id,origin,crop,stage,parent,work)
 if stage<4 then Visuals.GrowingSupports(id,origin,crop,stage,parent,os.time());return end
 local def=Catalog[id];local meta=Visuals.Metadata(id,crop);if not meta then return end
 local scale=Rules.Scale(crop.PlantScale);local solid=Access.IsSolid(def,scale);local collisionCost=0
 local layout=Visuals.LeafLayout(id,crop)
 for _,original in ipairs(Visuals.Specs(id,crop))do
  if original.g~=0 and def.Mode~='whole'then continue end
  local spec=Visuals.LeafSpec(original,crop,layout);if not spec then continue end
  spec=table.clone(spec);spec.tx=nil
  if spec.s=='Crystal'then spec.s='Gem'end
  if spec.s=='LeafBlade'then spec.s='ProxyBlade'end
  local cost=Visuals.PartCost(spec);local collision=solid and collisionCost+cost<=24 and spec.r~='Leaf'
  if collision then collisionCost+=cost end
  local variant=(spec.s=='Blob'or spec.s=='Shrub')and Visuals.CrownVariant(crop.Id,spec._ArtIndex or 1)or nil
  if work then work.BeforePart(cost)end
  local part=Visuals.Part(parent,spec,origin,scale,collision,crop.Mutation,nil,variant)
  if def.Mode=='whole'then part:SetAttribute('HarvestIndex',1);part.CanQuery=true end
 end
 if layout then parent:SetAttribute('LeafCount',layout.Count)end
end

function Visuals.AuthoredSocket(id,crop,index)
 local art=Approved.Get(id,crop);return V(table.unpack((art and art.Sockets or Catalog[id].Sockets)[index]))
end
function Visuals.FruitPosition(crop,def,index,now)
 local art=Approved.Get(crop.SeedId,crop)
 if art then
  local socket=V(table.unpack(art.Sockets[index]));local center=V(table.unpack(art.FruitCenters[index]))
  return Hologram.Point(crop,socket*Rules.Scale(crop.PlantScale)+(center-socket)*fruitTrait(crop,index,def).Scale,now)
 end
 local socket=Visuals.FruitSocket(crop,def,index);local authored=V(table.unpack(def.Sockets[index]or{0,1,0}))
 local center=V(table.unpack(def.FruitCenters[index]or def.Sockets[index]or{0,1,0}))
 local trait=fruitTrait(crop,index,def)
 return socket*Rules.Scale(crop.PlantScale)+(center-authored)*trait.Scale
end
function Visuals.FruitReach(crop,def,index)
 local art=Approved.Get(crop.SeedId,crop)
 return Access.HarvestDistance+((art and art.FruitRadii or def.FruitRadii)[index]or 0)*fruitTrait(crop,index,def).Scale
end
function Visuals.FruitProxy(parent,id,crop,index,origin,work)
 local def=Catalog[id];if not def then return end
 local list=Visuals.Metadata(id,crop).Proxies[index]or{}
 local trait=fruitTrait(crop,index,def);local authored=Visuals.AuthoredSocket(id,crop,index);local socket=Visuals.FruitSocket(crop,def,index);local scale=Rules.Scale(crop.PlantScale)
 local used=0
 for _,s in ipairs(list)do
  local cost=Visuals.PartCost(s)
  if used+cost>Visuals.Metadata(id,crop).ProxyLimit then continue end
  used+=cost
  local pos=V(s.c[1],s.c[2],s.c[3])
  if work then work.BeforePart(cost)end
  local part=Visuals.Part(parent,s,origin,trait.Scale,false,trait.Mutation,origin:PointToWorldSpace(socket*scale+(pos-authored)*trait.Scale))
  part:SetAttribute('FruitProxy',true)
 end
 -- Tag every wedge half/canopy piece so close detail can hide the complete proxy.
 for _,p in ipairs(parent:GetDescendants())do if p:IsA('BasePart')and p.Transparency<.95 then p:SetAttribute('FruitProxy',true);p:SetAttribute('HarvestIndex',index);p.CanQuery=true end end
end

function Visuals.BeginGrowth(model,id,crop,origin)
 Visuals.EndGrowth(model)
 local sockets={};for i=1,Catalog[id].FruitCount do sockets[i]=Visuals.FruitSocket(crop,Catalog[id],i)end
 local state=Growth.Capture(model,id,Catalog[id],crop,origin,sockets);growthStates[model]=state
 state.Connection=model.Destroying:Connect(function()growthStates[model]=nil end)
 return state
end
function Visuals.EndGrowth(model,crop,now)
 local state=growthStates[model];if not state then return end
 if crop then Growth.Apply(state,crop,math.max(now or 0,crop.ReadyAt or 0,crop.MatureAt or 0))end
 if state.Seed then state.Seed:Destroy()end;for _,p in ipairs(state.Sprout)do p:Destroy()end;for _,b in pairs(state.Buds)do b.Part:Destroy();b.Stem:Destroy()end
 if state.Connection then state.Connection:Disconnect()end;growthStates[model]=nil
end
function Visuals.UpdateGrowth(model,crop,now)
 local state=growthStates[model];if not state then return false end
 Growth.Apply(state,crop,now);return true
end
function Visuals.BuildGrowing(id,origin,crop,now,stage,work)
 local def=Catalog[id];crop=table.clone(crop or{Id='preview-'..id,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0})
 if not crop.PlantedAt then
  local fraction=({.015,.43,.78})[stage or 1]or .015;crop.PlantedAt=now-fraction*def.Seconds;crop.MatureAt=crop.PlantedAt+def.Seconds;crop.ReadyAt=crop.MatureAt
 end
 local ripe=table.clone(crop);ripe.ReadyAt=0
 local model=Visuals.Build(id,origin,ripe,4,math.huge,nil,work)
 Visuals.BeginGrowth(model,id,crop,origin);Visuals.UpdateGrowth(model,crop,now)
 return model
end
function Visuals.GrowingSupports(id,origin,crop,stage,parent,now)
 local def=Catalog[id];local ripe=table.clone(crop);ripe.ReadyAt=0
 Visuals.Supports(id,origin,ripe,4,parent)
 if def.Mode~='whole'then for index=1,def.FruitCount do
  if not Rules.IsPicked(crop,index)then
   local group=Instance.new('Folder');group.Name='GrowingHarvest_'..index;group.Parent=parent
   Visuals.FruitProxy(group,id,ripe,index,origin)
  end
 end end
 Visuals.BeginGrowth(parent,id,crop,origin);Visuals.UpdateGrowth(parent,crop,now)
end
function Visuals.GrowingFruitSupports(id,origin,crop,parent,now)
 local def=Catalog[id];local ripe=table.clone(crop);ripe.ReadyAt=0
 for index=1,def.FruitCount do if not Rules.FruitReady(crop,index,now)and not Rules.IsPicked(crop,index)then
  local group=Instance.new('Folder');group.Name='GrowingHarvest_'..index;group.Parent=parent
  Visuals.FruitProxy(group,id,ripe,index,origin)
 end end
 Visuals.BeginGrowth(parent,id,crop,origin);Visuals.UpdateGrowth(parent,crop,now)
end

-- Find an actual current sculpture surface from authored native bounds; never accept a client position.
function Visuals.TopSurface(id,crop,now)
 local def=Catalog[id];local specs=def and def.Tree and Visuals.SupportSpecs(id,crop)or Visuals.Specs(id,crop)
 if not def or not specs then return nil end
 local scale=Rules.Scale(crop.PlantScale);local best,bestHeight=nil,-math.huge
 for _,spec in ipairs(specs)do
  if spec.g>0 and not Rules.FruitReady(crop,spec.g,now)then continue end
  -- On trees the permanent crown is the landing target, so picking fruit cannot move it.
  if def.Tree and spec.g~=0 then continue end
  local factor=scale;local pos=V(spec.c[1],spec.c[2],spec.c[3])*scale
  if spec.g>0 and def.Mode~='whole'then
   factor=Rules.Fruit(crop,spec.g,def).Scale
   local socket=Visuals.AuthoredSocket(id,crop,spec.g)
   pos=socket*scale+(V(spec.c[1],spec.c[2],spec.c[3])-socket)*factor
  end
  local extent=(math.abs(spec.c[7])*spec.z[1]+math.abs(spec.c[8])*spec.z[2]+math.abs(spec.c[9])*spec.z[3])*factor/2
  local top=pos.Y+extent
  if top>bestHeight then bestHeight=top;best=V(pos.X,top,pos.Z)end
 end
 return best and Hologram.Point(crop,best,now)
end
return Visuals
