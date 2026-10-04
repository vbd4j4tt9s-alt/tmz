--!nocheck
-- R149 preview dump (not a test). Builds, with the REAL PlantCatalog / PlantVisuals / HarvestPresentation / ApprovedPlantArt of this
-- checkout on the Roblox mock, and prints one JSON scene per picture for render_fruit_models.mjs ("SCENE <name> <json>"):
--  * today_<SeedId>: every active fruit as the hotbar / sell viewport shows it (HarvestPresentation.Build: detached, stems hidden);
--  * ref_<x>_plant: the Cocoa tree, Fire Pepper, Prism Pepper and Plasma Pepper plants (the reference look);
--  * proto_<Key>: each FruitModels149 prototype, built part by part with PlantVisuals.Part (scratch module, not in the game);
--  * plant_before_<Key> / plant_after_<Key>: a few plants with today's fruit and with the prototype at the same fruit centres.
-- ApprovedPlantMeshes is stubbed (the baked meshes live in ServerStorage, not in the repo): a mesh part is printed as shape "Mesh"
-- with its key and drawn from extract_meshes.py's / gen_meshes.py's vertex data, or as a stand-in ellipsoid when there is none.
-- Also prints AUDIT rows (every active fruit) and INFO rows (prototype part counts) for fruit_models.md.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation')
local Pack=W.module('SeedPackRules');local Proto=W.module('FruitModels149')
local Rarity=W.module('RarityPlantArt');local Trees=W.module('TreeReworkArt');local Index=W.module('ApprovedPlantIndex')
local Desert=W.module('DesertPlantArt149');local MechArt=W.module('MechArt');local Verity=W.module('VerityCatalog')
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function parts(model)
 local out={}
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<.995 and c.Name~='VisualPivot'then table.insert(out,c)end end
 return out
end
local function dump(model)
 local out={}
 for _,c in ipairs(parts(model))do
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local sm=c:FindFirstChildOfClass('SpecialMesh')
  if sm and enumName(sm.MeshType)=='Sphere'then shape='Ball';local m=sm.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  local key=c:GetAttribute('ApprovedMesh');if key then shape='Mesh'end
  table.insert(out,string.format('{"shape":"%s","mesh":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
   shape,key or'',n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
 end
 return out
end
local fruitView='{"auto":true,"az":24,"el":18,"fov":30,"margin":1.06}' -- ItemPictures' fruit camera direction (.45,.35,-1)
local plantView='{"auto":true,"az":-28,"el":12,"fov":30,"margin":1.0}'
local function emit(name,model,view,extra)
 print(string.format('SCENE %s {"parts":[%s],"view":%s%s}',name,table.concat(dump(model),','),view,extra or''))
end
local function crop(id)local d=Catalog[id];return {Id='preview-'..id,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}end
local function harvest(id)return Harvest.Build({SeedId=id,Mutation='None',Weather='None',VisualCrop={SourceCropId='preview-'..id,FruitIndex=1,HarvestCycle=0}})end
local function source(id)
 if Verity.Is(id)then return 'VerityPlantArt'end
 if Desert.Is(id)then return 'DesertPlantArt149'end
 if MechArt.Get(id)then return 'MechArt'end
 if Rarity.Has(id)then return 'RarityPlantArt (Art45)'end
 if Trees.Has(id)then return 'TreeReworkArt'end
 if Index[id]then return Index[id]end
 return 'PlantArt'..(Catalog[id].ArtBiome or Catalog[id].Biome)
end
-- Active roster: every obtainable design (retired ids are already removed from SeedDesigns), Mech and Verity included.
local order={Forest=1,Jungle=2,Desert=3,Snow=4,Lava=5,Crystal=6,Storm=7,Mech=8,Verity=9}
local ids,seen={},{}
for _,s in ipairs(Pack.SeedDesigns)do if not seen[s.id]and Catalog[s.id]then seen[s.id]=true;table.insert(ids,s.id)end end
for _,s in ipairs(W.module('MechCatalog').Seeds)do if not seen[s.Id]then seen[s.Id]=true;table.insert(ids,s.Id)end end
if not seen[Verity.Id]then table.insert(ids,Verity.Id)end
local function rank(id)return Pack.Rarities[Catalog[id].Rarity]and Pack.Rarities[Catalog[id].Rarity].Rank or 0 end
table.sort(ids,function(a,b)local x,y=order[Catalog[a].Biome]or 10,order[Catalog[b].Biome]or 10;if x~=y then return x<y end;if rank(a)~=rank(b)then return rank(a)<rank(b)end;return Catalog[a].Name<Catalog[b].Name end)
local function specCost(list)local c=0;for _,s in ipairs(list)do c+=Visuals.PartCost(s)end;return c end
for _,id in ipairs(ids)do
 local d=Catalog[id];local model=Visuals.Build(id,CF(0,0,0),crop(id),4,math.huge)
 local h=harvest(id);local meshes=0;for _,p in ipairs(parts(model))do if p:GetAttribute('ApprovedMesh')then meshes+=1 end end
 local fruit={};local shapes={};for _,s in ipairs(Visuals.Specs(id,crop(id)))do if s.g==1 then table.insert(fruit,s);local k=s.s..(s.mesh and(':'..s.mesh)or'');shapes[k]=(shapes[k]or 0)+1 end end
 local sl={};for k,v in pairs(shapes)do table.insert(sl,k..'x'..v)end;table.sort(sl)
 print(table.concat({'AUDIT',id,d.Name,d.Biome,d.Rarity,d.FruitCount,source(id),#parts(model),meshes,#parts(h),specCost(fruit),table.concat(sl,' ')},'\t'))
 emit('today_'..id,h,fruitView,',"tile":[300,300]')
end
-- References: the plants whose look the owner wants carried over.
emit('ref_cocoa_plant',Visuals.Build('CocoaSeed',CF(0,0,0),crop('CocoaSeed'),4,math.huge),plantView,',"tile":[360,420],"plant":true')
emit('ref_fire_plant',Visuals.Build('FirePepperSeed',CF(0,0,0),crop('FirePepperSeed'),4,math.huge),plantView,',"tile":[360,420],"plant":true')
emit('ref_prism_plant',Visuals.Build('PrismOrchidSeed',CF(0,0,0),crop('PrismOrchidSeed'),4,math.huge),plantView,',"tile":[360,420],"plant":true')
emit('ref_plasma_plant',Visuals.Build('PlasmaPepperSeed',CF(0,0,0),crop('PlasmaPepperSeed'),4,math.huge),plantView,',"tile":[360,420],"plant":true')
-- Prototypes: every spec through the real PlantVisuals.Part.
local holder=R.new('Model');holder.Parent=W.workspace
local function build(list)
 local m=R.new('Model');m.Parent=holder
 for _,s in ipairs(list)do Visuals.Part(m,s,CF(0,0,0),1,false,'None',nil,nil)end
 return m
end
local function protoList(entries)
 for _,e in ipairs(entries)do
  local specs=Proto[e.Key]();local m=build(specs)
  local today=harvest(e.Id)
  print(table.concat({'INFO',e.Key,e.Id,Catalog[e.Id].Name,'specs',#specs,'parts',#parts(m),'cost',specCost(specs),'today parts',#parts(today),'budget',e.Budget},'\t'))
  emit('proto_'..e.Key,m,fruitView,',"tile":[360,360]')
 end
end
protoList(Proto.List);protoList(Proto.Mesh)
-- On the plant: today's fruit groups swapped for the prototype at the same centre (connectors that reach the vine / branch kept).
local realSpecs=Visuals.Specs
local function swapped(id,key,anchor)
 local base=realSpecs(id,crop(id));local names={};for _,a in ipairs(anchor)do names[a]=true end
 local centres={};local out={}
 for _,s in ipairs(base)do
  if s.g>0 and names[s.f]then local c=centres[s.g]or{0,0,0,0};c[1]+=s.c[1];c[2]+=s.c[2];c[3]+=s.c[3];c[4]+=1;centres[s.g]=c end
  if s.g==0 or not Visuals.HarvestSpec(id,s)then table.insert(out,s)end
 end
 for g,c in pairs(centres)do
  for _,p in ipairs(Proto[key]())do
   local q=table.clone(p);q.c=table.clone(p.c);q.c[1]+=c[1]/c[4];q.c[2]+=c[2]/c[4];q.c[3]+=c[3]/c[4];q.g=g;q._ArtIndex=#out+1;table.insert(out,q)
  end
 end
 return out,base
end
for _,e in ipairs({{'Watermelon','SunflowerSeed',{'Rind'}},{'Apple','AppleSeed',{'Canopy apple'}},{'EmberPumpkin','EmberBloomSeed',{'Pumpkin lobe'}},{'AmethystGrape','AmethystSeed',{'Harvest form'}},{'WatermelonMesh','SunflowerSeed',{'Rind'}}})do
 local key,id,anchor=e[1],e[2],e[3]
 local after,before=swapped(id,key,anchor)
 local b=Visuals.Build(id,CF(0,0,0),crop(id),4,math.huge)
 Visuals.Specs=function(i,c)if i==id then return after end;return realSpecs(i,c)end
 local a=Visuals.Build(id,CF(0,0,0),crop(id),4,math.huge)
 Visuals.Specs=realSpecs
 print(table.concat({'PLANT',key,id,'before parts',#parts(b),'cost',specCost(before)+1,'after parts',#parts(a),'cost',specCost(after)+1},'\t'))
 if key~='WatermelonMesh'then emit('plant_before_'..key,b,plantView,',"tile":[360,360],"plant":true')end
 emit('plant_after_'..key,a,plantView,',"tile":[360,360],"plant":true')
end
