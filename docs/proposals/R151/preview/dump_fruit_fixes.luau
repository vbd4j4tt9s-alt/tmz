--!nocheck
-- R151 fruit fixes, preview dump (not a test): `luau dump_fruit_fixes.luau -a mesh`. Builds, with the REAL modules of whatever tree it runs in (the BASE commit for "before", this checkout for
-- "after") on the Roblox mock, one JSON scene per picture for render_fruit_models.mjs ("SCENE <name> <json>") and INFO rows for compose_fruit_fixes_png.py:
--   fruit_<id>       the hotbar / Bag / Index model of the fruit (HarvestPresentation.Build), seen from ItemPictures' direction (from -Z)
--   plant_<id>       the plant at full detail, on the ground (a garden plot), seen from a little to the side of its front
--   verity_item_front / verity_item_back    the Verity fruit as an item, seen from -Z (the cameras of the hotbar / Bag / Index) and from +Z
--   verity_path / verity_behind             the PLANTED Verity fruit seen from the path (+Z, the plot's front) and from behind (-Z)
-- The Baked meshes (Watermelon, Snow Melon, Ember Pumpkin) are drawn from the vertex data FruitMeshes149 generates (the bake runs on the mock: MESHDATA); every other baked plant mesh
-- (the cocoa pod, the peppers ...) is a stand-in ellipsoid here, because the meshes live in the place file and cannot be loaded offline. Verity's face is a Decal (a picture the renderer cannot
-- load): it is drawn as a small stand-in smiley of dark balls on the side the Decal is on, so you can see WHICH side(s) of the ball have a face.
-- INFO <id> <name> <fruit parts> <plant parts>.
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
if mode=='mesh'and W.RS:FindFirstChild('FruitMeshes149')then
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
local function partJson(shape,mesh,s,p,r,color,material,t,refl)
 return string.format('{"shape":"%s","mesh":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
  shape,mesh,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),color,material,n(t),n(refl))
end
-- the stand-in smiley of a Decal: two eyes and a smile of small dark balls on the ball's surface, on the side the Decal's Face names
local NORMAL={Front=V3(0,0,-1),Back=V3(0,0,1),Top=V3(0,1,0),Bottom=V3(0,-1,0),Left=V3(-1,0,0),Right=V3(1,0,0)}
local function smiley(ball,decal)
 local normal=NORMAL[enumName(decal.Face)];if not normal then return {}end
 local radius=ball.Size.X/2;local cf=ball.CFrame
 local up=math.abs(normal.Y)>.9 and V3(0,0,1)or V3(0,1,0)
 local x=up:Cross(normal).Unit;local y=normal:Cross(x)
 local out={}
 local function dot(u,v,d,color)
  local dir=(normal*math.sqrt(math.max(.04,1-u*u-v*v))+x*u+y*v).Unit
  local at=cf:PointToWorldSpace(dir*radius*1.002)
  local s=V3(d*radius,d*radius,d*radius*.4)
  local f=R.CFrame.fromMatrix(at,(x-dir*dir:Dot(x)).Unit,(y-dir*dir:Dot(y)).Unit,dir)
  local r=f.R
  table.insert(out,partJson('Ball','',s,at,r,color,'SmoothPlastic',0,0))
 end
 local ink='[30,30,36]'
 dot(-.26,.22,.13,ink);dot(.26,.22,.13,ink)
 for k=0,6 do local a=math.pi*(.15+.7*k/6);dot(.34*math.cos(a)*-1,-.06-.30*math.sin(a),.07,ink)end
 return out
end
local function dump(model,withFace)
 local out={}
 for _,c in ipairs(parts(model))do
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size;local mesh=''
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local sm=c:FindFirstChildOfClass('SpecialMesh')
  if sm and enumName(sm.MeshType)=='Sphere'then shape='Ball';local m=sm.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  if shape=='Sphere'then shape='Ball'end
  if c.ClassName=='MeshPart'and c.MeshContent then shape='Mesh';mesh=c.MeshContent.Id end
  table.insert(out,partJson(shape,mesh,s,p,r,c3(c.Color),enumName(c.Material),c.Transparency or 0,c.Reflectance or 0))
  if withFace then for _,d in ipairs(c:GetChildren())do if d:IsA('Decal')and(d.Transparency or 0)<1 then for _,m in ipairs(smiley(c,d))do table.insert(out,m)end end end end
 end
 return out
end
local fruitView='{"auto":true,"az":24,"el":18,"fov":30,"margin":1.06}'   -- ItemPictures' fruit camera direction (.45,.35,-1): from -Z
local plantView='{"auto":true,"az":-28,"el":12,"fov":30,"margin":1.0}'
local function emit(name,model,view,extra,withFace)print(string.format('SCENE %s {"parts":[%s],"view":%s%s}',name,table.concat(dump(model,withFace),','),view,extra or''))end
local function crop(id,cid)local d=Catalog[id];return {Id=cid,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}end
local function harvest(id,cid,idx)return Harvest.Build({SeedId=id,Mutation='None',Weather='None',VisualCrop={SourceCropId=cid,FruitIndex=idx or 1,HarvestCycle=0}})end
local CID='fixes-a'
local IDS={'SunflowerSeed','SnowdropSeed','EmberBloomSeed','AppleSeed','ElderbloomSeed','BluebellSeed','IceberrySeed','MoonflowerSeed'}
for _,id in ipairs(IDS)do
 local d=Catalog[id]
 local fruit=harvest(id,CID);local plant=Visuals.Build(id,CF(0,0,0),crop(id,CID),4,math.huge)
 emit('fruit_'..id,fruit,fruitView,',"tile":[300,300]');emit('plant_'..id,plant,plantView,',"tile":[360,360],"plant":true')
 print(table.concat({'INFO',id,d.Name,tostring(#parts(fruit)),tostring(#parts(plant))},'\t'))
end
-- Verity: the fruit as an item (from the front and from behind) and the planted fruit (from the path, +Z, and from behind, -Z)
do
 local id='VeritySeed'
 local item=harvest(id,CID);local plant=Visuals.BuildGrowing(id,CF(0,0,0),crop('VeritySeed','verity-garden-1'),Catalog[id].Seconds)
 emit('verity_item_front',item,'{"auto":true,"az":24,"el":18,"fov":30,"margin":1.06}',',"tile":[300,300]',true)
 emit('verity_item_back',item,'{"auto":true,"az":204,"el":18,"fov":30,"margin":1.06}',',"tile":[300,300]',true)
 emit('verity_path',plant,'{"auto":true,"az":160,"el":12,"fov":30,"margin":1.0}',',"tile":[360,360],"plant":true',true)
 emit('verity_behind',plant,'{"auto":true,"az":-20,"el":12,"fov":30,"margin":1.0}',',"tile":[360,360],"plant":true',true)
 print(table.concat({'INFO',id,Catalog[id].Name,tostring(#parts(item)),tostring(#parts(plant))},'\t'))
end
