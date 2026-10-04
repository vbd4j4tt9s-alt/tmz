--!nocheck
-- R148 preview dump (not a test): builds the roster change's seeds and plants with the REAL SeedPackVisuals / PlantVisuals / PlantGrowth /
-- DesertPlantArt149 / ApprovedPlantArt on the Roblox mock and prints one JSON scene per panel for render_seeds_new.mjs ("SCENE <name> <json>").
-- Panels: for the Aloe and the Sand Fruit the seed, the plant growing (50%), fully grown and one harvested fruit; for Fire Pepper the new Mythic
-- seed and the plant before (the base commit's art) and after (x2). Fire Pepper's baked meshes live in ServerStorage, not in this repo, so its
-- plant is drawn from the art specs (each "ApprovedMesh" as a stand-in ellipsoid of its bounding box): the SIZE is what the preview shows.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
-- Mock gaps (Roblox does these natively): a full lookAt with an up vector, CFrame.fromMatrix.
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local SeedVisuals=W.module('SeedPackVisuals');local Approved=W.module('ApprovedPlantArt')
local OldApproved=W.module('ApprovedPlantArtBase')
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
-- An art spec list (RarityRework / ApprovedMesh): every spec a part; a baked mesh becomes a stand-in "Mesh" (an ellipsoid of its bounding box).
-- Leaves whose colour is baked into their texture (white spec colour) are drawn green. `shift` moves the plant along X (before / after side by side).
local function specParts(specs,shift,out)
 for _,s in ipairs(specs)do
  local c=s.c;local k=s.k
  if s.s=='ApprovedMesh'and k[1]==255 and k[2]==255 and k[3]==255 then k=(s.f:lower():find('pepper')and not s.f:lower():find('sepal'))and{204,52,36}or{74,140,64}end
  local shape=s.s=='ApprovedMesh'and'Mesh'or s.s
  table.insert(out,string.format('{"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":[%d,%d,%d],"material":"%s","t":0,"refl":0}',
   s.f,shape,n(s.z[1]),n(s.z[2]),n(s.z[3]),n(c[1]+shift),n(c[2]),n(c[3]),n(c[4]),n(c[5]),n(c[6]),n(c[7]),n(c[8]),n(c[9]),n(c[10]),n(c[11]),n(c[12]),k[1],k[2],k[3],s.m or'SmoothPlastic'))
 end
end
local holder=R.new('Model');holder.Parent=W.workspace
local origin=CF(0,0,0)
local function crop(id,extra)
 local def=Catalog[id]
 local c={Id='preview-'..id,SeedId=id,PlantedAt=0,MatureAt=def.Seconds,ReadyAt=def.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local seedView='{"target":[0,1.1,0],"dist":9,"az":-28,"el":12,"fov":30}'
-- Aloe
emit('seed_aloe',SeedVisuals.Seed({Id='DesertAloeSeed'},1,CF(0,0,0),holder,1,nil,'None'),seedView)
local aloeView=function(y,d)return string.format('{"target":[0,%s,0],"dist":%s,"az":-28,"el":14,"fov":30}',y,d)end
emit('aloe_growing',Visuals.BuildGrowing('DesertAloeSeed',origin,crop('DesertAloeSeed'),.5*Catalog.DesertAloeSeed.Seconds),aloeView(4.2,34))
emit('aloe_grown',Visuals.Build('DesertAloeSeed',origin,crop('DesertAloeSeed'),4,math.huge),aloeView(4.2,34))
-- (a harvested fruit is built like the game's HarvestPresentation does: a detached item, which drops connectors such as the Sand Fruit's 'Fruit stem')
local aloeFruit=Visuals.Build('DesertAloeSeed',origin,crop('DesertAloeSeed',{_DetachedHarvest=true}),4,math.huge,1)
local ac=Catalog.DesertAloeSeed.FruitCenters[1]
emit('aloe_fruit',aloeFruit,string.format('{"target":[%s,%s,%s],"dist":15,"az":-28,"el":10,"fov":30}',ac[1],ac[2],ac[3]))
-- Sand Fruit
emit('seed_sand',SeedVisuals.Seed({Id='SandFruitSeed'},1,CF(0,0,0),holder,1,nil,'None'),seedView)
local cactusView=function(y,d)return string.format('{"target":[0,%s,0],"dist":%s,"az":-28,"el":14,"fov":30}',y,d)end
emit('sand_growing',Visuals.BuildGrowing('SandFruitSeed',origin,crop('SandFruitSeed'),.5*Catalog.SandFruitSeed.Seconds),cactusView(5.4,44))
emit('sand_grown',Visuals.Build('SandFruitSeed',origin,crop('SandFruitSeed'),4,math.huge),cactusView(5.4,44))
emit('sand_close',Visuals.Build('SandFruitSeed',origin,crop('SandFruitSeed'),4,math.huge),'{"target":[0,6.4,0],"dist":17,"az":-28,"el":24,"fov":30}') -- (a close-up of the shoulders and the fruit; not in the sheet)
local sandFruit=Visuals.Build('SandFruitSeed',origin,crop('SandFruitSeed',{_DetachedHarvest=true}),4,math.huge,1)
local sc=Catalog.SandFruitSeed.FruitCenters[1]
emit('sand_fruit',sandFruit,string.format('{"target":[%s,%s,%s],"dist":8,"az":-28,"el":8,"fov":30}',sc[1],sc[2],sc[3]))
-- Growth variations: the four designs of each plant side by side, fully grown (a crop gets its design from a hash of its crop id, ApprovedPlantArt). Each is a crop id
-- of that design with no size / turn jitter and plain-sized fruit, found through ApprovedPlantArt.Key itself. (The renderer mirrors X: design 1 is placed at +X so that it
-- appears on the left.)
local Rules=W.module('PlantRules')
local function designCrop(id,design)
 for n=1,20000 do
  local cid='pv'..n;local d,j=Approved.Key(id,{Id=cid}):match(':d(%d):(%d)$')
  if tonumber(d)==design and(tonumber(j)==4 or tonumber(j)==5)then
   local c=crop(id,{Id=cid});local plain=true;for g=1,Catalog[id].FruitCount do if Rules.Fruit(c,g,Catalog[id]).Scale~=1 then plain=false end end
   if plain then return c end
  end
 end
end
local function lineup(name,id,spacing,view)
 local out={}
 for d=1,4 do dumpModel(Visuals.Build(id,CF((2.5-d)*spacing,0,0),designCrop(id,d),4,math.huge),out)end
 print(string.format('SCENE %s {"parts":[%s],"view":%s,"size":[1200,330]}',name,table.concat(out,','),view))
end
lineup('aloe_variants','DesertAloeSeed',12,'{"target":[0,4.8,0],"dist":28,"az":-6,"el":11,"fov":30}')
lineup('sand_variants','SandFruitSeed',17.5,'{"target":[0,6.8,0],"dist":38,"az":-6,"el":11,"fov":30}')
-- Fire Pepper: the new Mythic seed, the plant before (base art) and after (x2), and both side by side to scale.
emit('seed_fire',SeedVisuals.Seed({Id='FirePepperSeed'},1,CF(0,0,0),holder,1,nil,'None'),seedView)
local function emitSpecs(name,specLists,view)
 local out={};for _,e in ipairs(specLists)do specParts(e[1],e[2],out)end
 print(string.format('SCENE %s {"parts":[%s],"view":%s}',name,table.concat(out,','),view))
end
local before,after=OldApproved.Get('FirePepperSeed'),Approved.Get('FirePepperSeed')
emitSpecs('fire_before',{{before.Specs,0}},'{"target":[0,3.1,0],"dist":21,"az":-28,"el":10,"fov":30}')
emitSpecs('fire_after',{{after.Specs,0}},'{"target":[0,6.2,0],"dist":42,"az":-28,"el":10,"fov":30}')
emitSpecs('fire_both',{{before.Specs,-7},{after.Specs,5}},'{"target":[-1,6.2,0],"dist":42,"az":-12,"el":8,"fov":30}')
print('INFO '..string.format('fire before H %.3f R %.3f, after H %.3f R %.3f; aloe H %.3f R %.3f; sand H %.3f R %.3f',before.Height,before.Radius,after.Height,after.Radius,Catalog.DesertAloeSeed.Height,Catalog.DesertAloeSeed.Radius,Catalog.SandFruitSeed.Height,Catalog.SandFruitSeed.Radius))
