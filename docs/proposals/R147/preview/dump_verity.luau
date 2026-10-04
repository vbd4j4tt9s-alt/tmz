--!nocheck
-- R147 preview dump (not a test): builds the Verity seed and plant with the REAL SeedPackVisuals / PlantVisuals /
-- PlantGrowth / VerityGrowth on the Roblox mock and prints one JSON scene per panel for render_verity.mjs
-- ("SCENE <name> <json>"). Panels: the seed, the plant at several growth stages, and the Gold / Diamond coats.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Catalog=W.module('PlantCatalog')
-- The catalog entry another coder adds (SeedPackRules / PlantCatalog / Config): stand-in with the agreed fields.
Catalog.VeritySeed=Catalog.VeritySeed or {Name='Verity',Biome='Verity',Stage=9,Rarity='King',Rank=8,Tree=false,Mode='repeat',HarvestName='Verity Fruit',FruitCount=1,Verity=true,
 Sockets={{0,1.6,0}},FruitCenters={{0,12.6,0}},FruitRadii={11},Height=23.6,AuthoredHeight=23.6,Radius=11.2,BaseScale=1,Seconds=14400,RegrowSeconds=1500,Value=9e10}
local Visuals=W.module('PlantVisuals');local SeedVisuals=W.module('SeedPackVisuals')
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function dumpModel(model,out)
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<.995 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local mesh=c:FindFirstChildOfClass('SpecialMesh')
  if mesh and enumName(mesh.MeshType)=='Sphere'then shape='Ball';local m=mesh.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  table.insert(out,string.format('{"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
   c.Name,shape,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
 end end
end
local function emit(name,model,view)
 local parts={};dumpModel(model,parts)
 print(string.format('SCENE %s {"parts":[%s],"view":%s}',name,table.concat(parts,','),view))
end
local holder=R.new('Model');holder.Parent=W.workspace
-- Seeds (a close-up).
for _,coat in ipairs({'None','Gold','Diamond'})do
 local seed=SeedVisuals.Seed({Id='VeritySeed'},1,CF(0,0,0),holder,1,nil,coat)
 emit('seed_'..coat,seed,'{"target":[0,0,0],"dist":6,"az":-28,"el":14,"fov":30}')
end
local function crop(extra)
 local c={Id='verity-preview',SeedId='VeritySeed',PlantedAt=0,MatureAt=14400,ReadyAt=14400,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1,
  _VisualHarvest={Index=1,Scale=1,Mutation='None'}}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local view='{"target":[0,11.2,0],"dist":84,"az":-28,"el":10,"fov":30}'
for _,f in ipairs({0,.1,.2,.33,.45,.66,.85,1})do
 local m=Visuals.BuildGrowing('VeritySeed',CF(0,0,0),crop(),f*14400)
 emit(string.format('plant_%03d',math.floor(f*100+.5)),m,view)
end
emit('plant_100_side',Visuals.BuildGrowing('VeritySeed',CF(0,0,0),crop(),14400),'{"target":[0,11.2,0],"dist":84,"az":-28,"el":2,"fov":30}')
emit('plant_100_top',Visuals.BuildGrowing('VeritySeed',CF(0,0,0),crop(),14400),'{"target":[0,6,0],"dist":84,"az":-28,"el":42,"fov":30}')
emit('plant_045_top',Visuals.BuildGrowing('VeritySeed',CF(0,0,0),crop(),.45*14400),'{"target":[0,4,0],"dist":40,"az":-28,"el":30,"fov":30}')
for _,coat in ipairs({'Gold','Diamond'})do
 local m=Visuals.BuildGrowing('VeritySeed',CF(0,0,0),crop({Mutation=coat,_VisualHarvest={Index=1,Scale=1,Mutation=coat}}),14400)
 emit('plant_'..coat,m,view)
end
