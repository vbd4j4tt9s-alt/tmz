--!nocheck
-- R149 built-preview dump (not a test). Builds, with the REAL modules of whatever tree it runs in (the base commit for "before", this checkout for
-- "after") on the Roblox mock, one JSON scene per picture for render_fruit_models.mjs ("SCENE <name> <json>") and INFO rows for make_built_sheet.py:
--   fruit_<id>      the hotbar / Bag / Index model of fruit 1 (HarvestPresentation.Build: detached, stems hidden)
--   plant_<id>      the plant at full detail
--   coat_<id>_<m>   fruit 1 with a Gold / Diamond coat (after only: the same build with every coat)
--   grow_<id>_<n>   the plant growing at 30 / 60 / 90 % (BuildGrowing)
--   ash_<n>         the Ash Tomato plant, one crop of each of its designs (after: 4 designs; before: 1)
--   unch_<id>       Lantern Fern and Amethyst Grape, built in both trees: they must be the same picture
-- INFO <id> <fruit parts> <plant parts> and ASH <design> <crop id> <plant parts>.
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
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation');local Art=W.module('ApprovedPlantArt')
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
  table.insert(out,string.format('{"shape":"%s","mesh":"","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"refl":%s}',
   shape,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0),n(c.Reflectance or 0)))
 end
 return out
end
local fruitView='{"auto":true,"az":24,"el":18,"fov":30,"margin":1.06}' -- ItemPictures' fruit camera direction (.45,.35,-1)
local plantView='{"auto":true,"az":-28,"el":12,"fov":30,"margin":1.0}'
local function emit(name,model,view,extra)print(string.format('SCENE %s {"parts":[%s],"view":%s%s}',name,table.concat(dump(model),','),view,extra or''))end
local function crop(id,cid,mut)local d=Catalog[id];return {Id=cid,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation=mut or'None',HarvestCycle=0,PickedMask=0,TraitVersion=1}end
local function harvest(id,cid,mut,idx)return Harvest.Build({SeedId=id,Mutation=mut or'None',Weather='None',VisualCrop={SourceCropId=cid,FruitIndex=idx or 1,HarvestCycle=0}})end
local IDS={'SunflowerSeed','SnowdropSeed','AppleSeed','ElderbloomSeed','EmberBloomSeed','CactusSeed','BluebellSeed','IceberrySeed'}
local CID='built-a'
for _,id in ipairs(IDS)do
 local fruit=harvest(id,CID);local plant=Visuals.Build(id,CF(0,0,0),crop(id,CID),4,math.huge)
 emit('fruit_'..id,fruit,fruitView,',"tile":[300,300]');emit('plant_'..id,plant,plantView,',"tile":[360,360],"plant":true')
 print(table.concat({'INFO',id,Catalog[id].Name,tostring(#parts(fruit)),tostring(#parts(plant))},'\t'))
 for _,m in ipairs({'Gold','Diamond'})do emit('coat_'..id..'_'..m,harvest(id,CID,m),fruitView,',"tile":[300,300]')end
 local d=Catalog[id]
 for k,f in ipairs({.3,.6,.9})do emit('grow_'..id..'_'..k,Visuals.BuildGrowing(id,CF(0,0,0),crop(id,CID),f*d.Seconds),plantView,',"tile":[360,360],"plant":true')end
end
-- the Ash Tomato: one crop of each design (the key's d<n> suffix) and its base design
local found={}
for k=1,400 do
 local id='ash-'..k;local key=Art.Key('AshRoseSeed',{Id=id});local d=key:match('d(%d)$')or'0'
 if not found[d]then found[d]=id end
end
for d=0,3 do
 local cid=found[tostring(d)]
 if cid then
  local plant=Visuals.Build('AshRoseSeed',CF(0,0,0),crop('AshRoseSeed',cid),4,math.huge)
  emit('ash_'..(d+1),plant,plantView,',"tile":[360,360],"plant":true');emit('ashfruit_'..(d+1),harvest('AshRoseSeed',cid),fruitView,',"tile":[300,300]')
  print(table.concat({'ASH',tostring(d+1),cid,tostring(#parts(plant))},'\t'))
 end
end
for _,id in ipairs({'LanternFernSeed','AmethystSeed'})do
 local fruit=harvest(id,CID);local plant=Visuals.Build(id,CF(0,0,0),crop(id,CID),4,math.huge)
 emit('unch_fruit_'..id,fruit,fruitView,',"tile":[300,300]');emit('unch_plant_'..id,plant,plantView,',"tile":[360,360],"plant":true')
 print(table.concat({'INFO',id,Catalog[id].Name,tostring(#parts(fruit)),tostring(#parts(plant))},'\t'))
end
