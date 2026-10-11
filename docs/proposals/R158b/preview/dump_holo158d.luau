--!nocheck
-- R158d Holo Melon / Holo Apple Tree rework, preview dump (not a test): `luau dump_holo158d.luau -a before|after`.
-- Builds the two Mech seeds with the REAL modules on the Roblox mock, one JSON scene per picture for render_holo158d.mjs.
--   before: run against the BASE commit's modules (the square wire melon, the box apple), no bake;
--   after : run against this checkout, the server bake (fruit_mesh_mock.luau records the EditableMesh calls) first; MESHDATA = the baked vertex data.
-- Scenes: item_<seed>_<form> (the hotbar / Bag / Index picture of a harvested fruit), plant_<seed> (the whole plant at full detail), zoom_<seed> (the apple tree's fruit).
-- Rows: INFO <scene> <visible parts>.
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
if mode=='after'then
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
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation');local Hologram=W.module('HologramProjection')
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
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size;local mesh=''
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local sm=c:FindFirstChildOfClass('SpecialMesh')
  if sm and enumName(sm.MeshType)=='Sphere'then shape='Ball';local m=sm.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  if c.ClassName=='MeshPart'and c.MeshContent then shape='Mesh';mesh=c.MeshContent.Id end
  table.insert(out,string.format('{"shape":"%s","mesh":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
   shape,mesh,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
 end
 return out
end
local fruitView='{"auto":true,"az":24,"el":18,"fov":30,"margin":1.06}' -- ItemPictures' fruit camera direction (.45,.35,-1)
local plantView='{"auto":true,"az":-28,"el":12,"fov":30,"margin":1.0}'
local function emit(name,model,view,extra)local list=dump(model);print(string.format('SCENE %s {"parts":[%s],"view":%s%s}',name,table.concat(list,','),view,extra or''));print('INFO\t'..name..'\t'..#list)end
local function crop(id,cid,cycle,states)
 local d=Catalog[id]
 return {Id=cid,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=cycle or 0,PickedMask=0,TraitVersion=1,FruitStates=states}
end
local function item(id,cid,cycle,idx)return Harvest.Build({SeedId=id,Mutation='None',Weather='None',VisualCrop={SourceCropId=cid,FruitIndex=idx or 1,HarvestCycle=cycle}})end
-- Holo Melon: harvest cycle 0 / 1 / 2 = Holo Melon / Holo Cantaloupe / Holo Pumpkin
local MELON='HoloMelonSeed'
for form=0,2 do
 local name=({'Holo Melon','Holo Cantaloupe','Holo Pumpkin'})[form+1]
 emit('item_melon_'..form,item(MELON,'h158',form,1),fruitView,',"tile":[320,320]')
 emit('plant_melon_'..form,Visuals.Build(MELON,CF(0,0,0),crop(MELON,'h158',form),4,math.huge),plantView,',"tile":[360,360],"plant":true')
 assert(Hologram.Name(crop(MELON,'h158',form),1)==name)
end
-- Holo Apple Tree: its four fruit cycle on their own: Holo Apple / Holo Pear / Holo Orange / Holo Apple
local TREE='HoloAppleTreeSeed'
local states={['1']={Cycle=0,ReadyAt=0},['2']={Cycle=1,ReadyAt=0},['3']={Cycle=2,ReadyAt=0},['4']={Cycle=0,ReadyAt=0}}
local tree=Visuals.Build(TREE,CF(0,0,0),crop(TREE,'t158',0,states),4,math.huge)
-- (the camera stands on the +Z side: three of the four apples hang on that side of the trunk)
emit('plant_tree',tree,'{"auto":true,"az":155,"el":10,"fov":30,"margin":1.0}',',"tile":[420,420],"plant":true')
emit('zoom_tree',tree,'{"target":[1.3,7.8,1.5],"dist":17,"az":158,"el":8,"fov":30}',',"tile":[420,420],"plant":true')
for form=0,2 do emit('item_tree_'..form,item(TREE,'t158',form,1),fruitView,',"tile":[320,320]')end
