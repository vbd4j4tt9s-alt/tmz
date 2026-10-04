--!nocheck
-- R149 baked fruit meshes, preview dump (not a test): `luau dump_fruit_meshes.luau -a parts|mesh`. Builds the Watermelon, Snow Melon and
-- Ember Pumpkin with the REAL modules of this checkout on the Roblox mock, one JSON scene per picture for render_fruit_models.mjs.
--   parts: no fruit-mesh folder (FruitMeshes149 keeps the R149 part-built fruit: exactly what a server without the bake shows);
--   mesh : the server bake runs first (fruit_mesh_mock.luau records the EditableMesh calls) and the fruit get their baked mesh bodies.
-- Scenes: fruit_<id>_<n> (hotbar / Bag / Index picture of fruit n), plant_<id>, coat_<id>_<Gold|Diamond>, grow_<id> (75 %).
-- Rows: INFO <id> <name> <fruit 1 parts> <plant parts> <mesh triangles>; MESHDATA <json> (mesh mode: the baked vertex data, keyed like the
-- MeshParts' "mesh" field, for the renderer).
local mode=...
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
local tris=0
if mode=='mesh'then
 local Mock=require('./fruit_mesh_mock');local log=Mock.install(W);assert(Mock.prepare(W),'bake failed')
 local function n4(v)return string.format('%.5f',v)end
 local out={}
 for _,c in ipairs(log.Contents)do
  local v,n,k,f={},{},{},{}
  for i,p in ipairs(c.V)do v[i]='['..n4(p[1])..','..n4(p[2])..','..n4(p[3])..']'end
  for i,p in ipairs(c.N)do n[i]='['..n4(p[1])..','..n4(p[2])..','..n4(p[3])..']'end
  for i,p in ipairs(c.C)do k[i]='['..n4(p[1])..','..n4(p[2])..','..n4(p[3])..']'end
  for i,t in ipairs(c.F)do f[i]='['..t[1]..','..t[2]..','..t[3]..']'end
  table.insert(out,('"%s":{"v":[%s],"n":[%s],"c":[%s],"f":[%s]}'):format(c.Id,table.concat(v,','),table.concat(n,','),table.concat(k,','),table.concat(f,',')))
 end
 print('MESHDATA {'..table.concat(out,',')..'}')
end
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation')
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
local function parts(model)
 local out={}
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<.995 and c.Name~='VisualPivot'then table.insert(out,c)end end
 return out
end
local function dump(model)
 local out={};local t=0
 for _,c in ipairs(parts(model))do
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size;local mesh=''
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local sm=c:FindFirstChildOfClass('SpecialMesh')
  if sm and enumName(sm.MeshType)=='Sphere'then shape='Ball';local m=sm.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  if c.ClassName=='MeshPart'and c.MeshContent then shape='Mesh';mesh=c.MeshContent.Id;t+=#c.MeshContent.F end
  table.insert(out,string.format('{"shape":"%s","mesh":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
   shape,mesh,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
 end
 return out,t
end
local fruitView='{"auto":true,"az":24,"el":18,"fov":30,"margin":1.06}' -- ItemPictures' fruit camera direction (.45,.35,-1)
local plantView='{"auto":true,"az":-28,"el":12,"fov":30,"margin":1.0}'
local function emit(name,model,view,extra)local list,t=dump(model);print(string.format('SCENE %s {"parts":[%s],"view":%s%s}',name,table.concat(list,','),view,extra or''));return t end
local function crop(id,cid,mut)local d=Catalog[id];return {Id=cid,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation=mut or'None',HarvestCycle=0,PickedMask=0,TraitVersion=1}end
local function harvest(id,cid,mut,idx)return Harvest.Build({SeedId=id,Mutation=mut or'None',Weather='None',VisualCrop={SourceCropId=cid,FruitIndex=idx or 1,HarvestCycle=0}})end
local CID='built-a'
for _,id in ipairs({'SunflowerSeed','SnowdropSeed','EmberBloomSeed'})do
 local d=Catalog[id];local t=0
 for i=1,d.FruitCount do t=math.max(t,emit('fruit_'..id..'_'..i,harvest(id,CID,'None',i),fruitView,',"tile":[300,300]'))end
 local plant=Visuals.Build(id,CF(0,0,0),crop(id,CID),4,math.huge)
 emit('plant_'..id,plant,plantView,',"tile":[360,360],"plant":true')
 for _,m in ipairs({'Gold','Diamond'})do emit('coat_'..id..'_'..m,harvest(id,CID,m),fruitView,',"tile":[300,300]')end
 emit('grow_'..id,Visuals.BuildGrowing(id,CF(0,0,0),crop(id,CID),.75*d.Seconds),plantView,',"tile":[360,360],"plant":true')
 print(table.concat({'INFO',id,d.Name,tostring(#parts(harvest(id,CID))),tostring(#parts(plant)),tostring(t)},'\t'))
end
