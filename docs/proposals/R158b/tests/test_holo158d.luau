--!nocheck
-- R158d (owner: "do a mini rework on the holo melon and holo tree: make sure they use the updated melon and pumpkin meshes for the holo melon, and for the tree it uses the updated apples"):
-- the Mech hologram fruit on the Roblox mock with the REAL modules (HologramForms, HologramProjection, FruitMeshes149, MechArt, PlantVisuals, HarvestPresentation, ApprovedPlantArt, PlantGrowth ...).
-- Scenarios (-a mesh | parts | fail | loading; run_holo158d.sh runs all four, each in its own world):
--  mesh    the server bake ran: A the two hologram keys are the Watermelon's / Ember Pumpkin's mesh again (same vertices, normals, triangles) with grey brightness colours, baked and kept like the
--          other keys (10 templates), B the Holo Melon's forms (the mesh body at the real fruit's size, the real stem / tendril / leaf where they sit on the real fruit, scan rings, no wire boxes,
--          Neon + translucent + HologramFrame so the spin and the growth work, the plant base untouched), C every build: plant, harvest item, coats (the neutral twin), growth, DetailReady,
--          the per-harvest cycle and the names, D the Holo Apple Tree (the real apple's parts, scan rings, the stem to the crown kept, the pear / orange stretch, centres and radii as before),
--          E part budgets: fewer parts than before everywhere;
--  parts   no bake folder: the Holo Melon keeps its R57 wire forms (36 / 42 / 36 parts), the Holo Apple Tree is the same as with the bake (it needs no mesh);
--  fail    one hologram key fails to bake: its seed keeps the wire forms, the real fruit meshes are not touched, one warning;
--  loading the folder exists but nothing is baked yet: the mesh forms, DetailReady false.
local scenario=...;scenario=scenario or'mesh'
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Mock=require('./fruit_mesh_mock');local bakeLog=Mock.install(W,scenario=='fail'and{FailAt=3}or nil)
local FM=W.module('FruitMeshes149')
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation');local Approved=W.module('ApprovedPlantArt')
local Rules=W.module('PlantRules');local Hologram=W.module('HologramProjection');local Forms=W.module('HologramForms');local MechArt=W.module('MechArt');local Trees=W.module('TreeReworkArt')
local origin=CF(0,0,0)
local MELON,TREE='HoloMelonSeed','HoloAppleTreeSeed'
if scenario=='mesh'or scenario=='fail'then assert(Mock.prepare(W)~=nil,'prepare')end
if scenario=='loading'then local f=R.new('Folder');f.Name=FM.Folder;f.Parent=W.RS end
local function crop(id,cid,cycle,states,extra)
 local d=Catalog[id]
 local c={Id=cid or'h158d',SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=cycle or 0,PickedMask=0,TraitVersion=1,FruitStates=states}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local function parts(model,visible)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d.Name~='VisualPivot'and(not visible or(d.Transparency or 0)<1)then out[#out+1]=d end end;return out end
local function group(art,g)local out={};for _,s in ipairs(art.Specs)do if s.g==g then out[#out+1]=s end end;return out end
local function byName(list,name)local out={};for _,s in ipairs(list)do if s.f==name then out[#out+1]=s end end;return out end
local function cfOf(s)return CF(table.unpack(s.c))end
local function dist3(a,b)return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)end
local function same(a,b,tol)if#a~=#b then return false end;for i=1,#a do if not near(a[i],b[i],tol or 1e-9)then return false end end;return true end
local function item(id,cycle,idx)return Harvest.Build({SeedId=id,Mutation='None',Weather='None',VisualCrop={SourceCropId='h158d',FruitIndex=idx or 1,HarvestCycle=cycle}})end
local base=MechArt.Get(MELON);local baseTree=MechArt.Get(TREE)
local NAMES={'Holo Melon','Holo Cantaloupe','Holo Pumpkin'}
local WIRE={36,42,36};local WIRE_TREE=22
local USE=scenario=='mesh'or scenario=='loading'

-- the names, the per-harvest cycle and the keys do not change ---------------------------------------------------------------------------------------------------------------
for form=0,2 do
 check(Hologram.Name(crop(MELON,nil,form),1)==NAMES[form+1],'the Holo Melon form '..form..' keeps its name: '..NAMES[form+1])
 check(Hologram.Form(crop(MELON,nil,form),1)==form,'harvest cycle '..form..' is form '..form)
 check(Hologram.Key(MELON,crop(MELON,nil,form))==MELON..':'..form,'the art key is as before')
end
check(Hologram.Name(crop(TREE,nil,0,{['1']={Cycle=0},['2']={Cycle=1},['3']={Cycle=2},['4']={Cycle=0}}),2)=='Holo Pear','the Holo Apple Tree keeps its fruit names')

if scenario=='mesh'then
 -- A. the generator and the bake ------------------------------------------------------------------------------------------------------------------------------------------
 local want={'EmberPumpkin149','HoloMelon158','HoloPumpkin158','SnowMelon149','Watermelon149'}
 check(table.concat(FM.Keys,',')==table.concat(want,','),'FruitMeshes149 has the three real keys and the two hologram keys')
 check(FM.Owns('HoloMelon158')and FM.Owns('HoloPumpkin158')and FM.Owns('Watermelon149')and not FM.Owns('HoloMelon158_Neutral'),'it owns its keys (not the neutral names)')
 for _,pair in ipairs({{'HoloMelon158','Watermelon149'},{'HoloPumpkin158','EmberPumpkin149'}})do
  local h,r=FM.Generate(pair[1]),FM.Generate(pair[2])
  check(#h.Vertices==#r.Vertices and#h.Faces==#r.Faces and#h.Colors==#r.Colors and#h.Normals==#r.Normals,pair[1]..' has the real mesh\'s vertex, normal and triangle counts ('..#h.Vertices..' / '..#h.Faces..')')
  local geo=true;for i,v in ipairs(r.Vertices)do if not same(v,h.Vertices[i])or not same(r.Normals[i],h.Normals[i])then geo=false;break end end
  for i,f in ipairs(r.Faces)do if not same(f,h.Faces[i])then geo=false;break end end
  check(geo,pair[1]..' is the real mesh: every vertex, normal and triangle is the same as '..pair[2]..'\'s')
  local lo,hi,grey,distinct=math.huge,-math.huge,true,{}
  for _,c in ipairs(h.Colors)do lo=math.min(lo,c[1]);hi=math.max(hi,c[1]);if not(near(c[1],c[2])and near(c[2],c[3]))then grey=false end;distinct[string.format('%.3f',c[1])]=true end
  local n=0;for _ in pairs(distinct)do n+=1 end
  check(grey and near(lo,.3,1e-9)and near(hi,1,1e-9)and n>=6,pair[1]..': grey brightness .3 .. 1 ('..string.format('%.3f .. %.3f',lo,hi)..', '..n..' levels): the real stripes / grooves stay visible as bands')
  local coloured=false;for _,c in ipairs(r.Colors)do if not near(c[1],c[2],.01)then coloured=true;break end end
  check(coloured,pair[2]..' keeps its own colours (the real fruit is untouched)')
 end
 check(bakeLog.Editables==10 and#bakeLog.Contents==10 and bakeLog.Destroyed==10,'10 bakes (5 keys x normal / neutral), every EditableMesh destroyed ('..#bakeLog.Contents..')')
 local folder=W.RS:FindFirstChild(FM.Folder)
 check(folder and#folder:GetChildren()==10 and folder:GetAttribute('Ready')==true and folder:GetAttribute('FailureCount')==0,'the folder: 10 templates, Ready, 0 failures')
 for _,k in ipairs({'HoloMelon158','HoloPumpkin158'})do
  check(folder:FindFirstChild(k)and folder:FindFirstChild(k..'_Neutral')and folder:FindFirstChild(k):GetAttribute('ApprovedMesh')==k,k..' and its _Neutral twin are baked')
  check(FM.Status(k)=='Ready'and FM.Status(k,true)=='Ready','Status Ready for '..k)
 end
 check(FM.UsesMesh(MELON)==true and FM.Suffix(MELON)==''and FM.UsesMesh(TREE)==false and FM.Suffix(TREE)=='','UsesMesh / Suffix answer for the Holo Melon, and the apple tree needs no mesh')
 check(FM.UsesMesh('SunflowerSeed')==true and FM.Suffix('SunflowerSeed')=='','the real Watermelon is exactly as before')
 -- the real fruit (R149 art, after the bake) the forms are read off
 local realMelon=Visuals.Specs('SunflowerSeed',crop('SunflowerSeed','r'));local realPumpkin=Visuals.Specs('EmberBloomSeed',crop('EmberBloomSeed','r'))
 local rm,rp=group({Specs=realMelon},1),group({Specs=realPumpkin},1)
 local mBody=byName(rm,'Melon body')[1];local pBody=byName(rp,'Pumpkin body')[1]
 check(mBody and mBody.mesh==FM.Seeds.SunflowerSeed.Key and pBody and pBody.mesh==FM.Seeds.EmberBloomSeed.Key,'the real Watermelon / Ember Pumpkin draw Watermelon149 / EmberPumpkin149')
 local function rel(body,s)return cfOf(body):ToObjectSpace(cfOf(s))end
 -- B. the forms ---------------------------------------------------------------------------------------------------------------------------------------------------------
 local P={{96,219,255},{96,248,225},{160,166,255}}
 local COUNT={7,9,7};local KEY={'HoloMelon158','HoloMelon158','HoloPumpkin158'}
 for form=0,2 do
  local art=Approved.Get(MELON,crop(MELON,nil,form));local g1=group(art,1);local g0=group(art,0)
  check(#g1==COUNT[form+1],NAMES[form+1]..': '..#g1..' parts a fruit (expected '..COUNT[form+1]..', was '..WIRE[form+1]..')')
  local meshes={};for _,s in ipairs(g1)do if s.s=='ApprovedMesh'then meshes[#meshes+1]=s end end
  check(#meshes==1 and meshes[1].mesh==KEY[form+1],NAMES[form+1]..': one mesh body, '..KEY[form+1])
  local body=meshes[1]
  if form==0 then check(near(body.z[1],mBody.z[1],1e-3)and near(body.z[2],mBody.z[2],1e-3)and near(body.z[3],mBody.z[3],1e-3),'the melon body is the real Watermelon rind\'s size ('..string.format('%.4f %.4f %.4f',body.z[1],body.z[2],body.z[3])..')')
  elseif form==1 then check(body.z[1]<mBody.z[1]and body.z[2]>mBody.z[2]and near(body.z[2],body.z[3]),'the cantaloupe is the melon mesh, rounder ('..string.format('%.2f x %.2f x %.2f',body.z[1],body.z[2],body.z[3])..')')
  else check(near(body.z[1],pBody.z[1]*.9,1e-3)and near(body.z[2],pBody.z[2]*.9,1e-3)and near(body.z[3],pBody.z[3]*.9,1e-3),'the pumpkin body is the real Ember Pumpkin\'s size x .9') end
  check(near(cfOf(body).Position.X,0)and near(cfOf(body).Position.Y,base.Sockets[1][2])and near(cfOf(body).Position.Z,0),'the body sits on the socket, where the wire box was')
  local mat,alpha,pal,holo,fruit=true,true,true,true,true
  for _,s in ipairs(g1)do
   if s.m~='Neon'then mat=false end;if not(s.t>0 and s.t<1)then alpha=false end;if s.hologram~=true then holo=false end;if not(s.g==1 and s.r=='Fruit'and s.mech==true)then fruit=false end
  end
  check(mat and alpha and holo and fruit,NAMES[form+1]..': Neon, translucent, hologram, in group 1')
  local k=body.k;check(k[1]>=P[form+1][1]and k[2]>=P[form+1][2]-1 and k[3]>=P[form+1][3]-1 and k[1]-P[form+1][1]<=.1*(255-P[form+1][1])+1,NAMES[form+1]..': the body is the form\'s own colour (cyan / teal / violet)')
  local wire=false;for _,s in ipairs(g1)do if s.f:find('Square',1,true)or s.f=='Hologram stripe'or s.f=='Cantaloupe cross scan'or s.f=='Pumpkin projection rib'then wire=true end end
  check(not wire,NAMES[form+1]..': no wire box, stripe or cross scan left')
  local rings=byName(g1,'Hologram scan ring')
  check(#rings==(form==1 and 5 or 3),NAMES[form+1]..': '..#rings..' scan rings')
  -- the real stem, tendril and leaf sit where they do on the real fruit
  local real=form==2 and rp or rm;local realBody=form==2 and pBody or mBody;local factor=form==2 and .9 or 1
  local names=form==2 and{'Pumpkin stem','Pumpkin stem curl','Pumpkin leaf'}or{'Melon stem','Melon tendril','Melon leaf'}
  local fx,fy=body.z[1]/realBody.z[1],body.z[2]/realBody.z[2]
  for _,name in ipairs(names)do
   local mine,theirs=byName(g1,name)[1],byName(real,name)[1]
   if check(mine and theirs,NAMES[form+1]..': has the real '..name)then
    local want=rel(realBody,theirs);local got=cfOf(body):ToObjectSpace(cfOf(mine))
    check(near(got.Position.X,want.Position.X*fx,2e-3)and near(got.Position.Y,want.Position.Y*fy,2e-3)and near(got.Position.Z,want.Position.Z*fy,2e-3),NAMES[form+1]..': the '..name..' sits where the real one does')
    local small=math.min(fx,fy,body.z[3]/realBody.z[3])
    check(near(mine.z[1],theirs.z[1]*small,2e-3)and near(mine.z[2],theirs.z[2]*small,2e-3)and near(mine.z[3],theirs.z[3]*small,2e-3),NAMES[form+1]..': the '..name..' has the real one\'s size')
    check(mine.s==theirs.s,NAMES[form+1]..': the '..name..' is the real shape ('..theirs.s..')')
   end
  end
  -- the plant base, the sockets, the centres and the radii are exactly the Mech art's
  check(#g0==#group(base,0),NAMES[form+1]..': the plant base is the same '..#g0..' parts')
  local baseSame=true;for i,s in ipairs(group(base,0))do local m=g0[i];if m.f~=s.f or not same(m.z,s.z)or not same(m.c,s.c)or m.s~=s.s or m.mechFixed~=s.mechFixed then baseSame=false end end
  check(baseSame,NAMES[form+1]..': every base part is the Mech art\'s (same name, size, frame, fixed flag)')
  check(same(art.FruitCenters[1],base.FruitCenters[1])and near(art.FruitRadii[1],base.FruitRadii[1])and same(art.Sockets[1],base.Sockets[1]),NAMES[form+1]..': the fruit centre, radius and socket are as before (harvest reach unchanged)')
  local idx={};local unique=true;for _,s in ipairs(art.Specs)do if idx[s._ArtIndex]then unique=false end;idx[s._ArtIndex]=true end
  check(unique,NAMES[form+1]..': every _ArtIndex is unique')
 end
 -- the real Watermelon's stem / tendril / leaf numbers are the ones in HologramForms (the table is pinned by the checks above: form 0 compares every one at scale 1)
 -- C. every build ---------------------------------------------------------------------------------------------------------------------------------------------------------
 for form=0,2 do
  local c=crop(MELON,nil,form)
  local plant=Visuals.Build(MELON,origin,c,4,math.huge)
  local expect=#group(base,0)+COUNT[form+1]
  check(#parts(plant)==expect,NAMES[form+1]..': the plant builds '..#parts(plant)..' parts (expected '..expect..', was '..(#group(base,0)+WIRE[form+1])..')')
  local meshParts={};for _,p in ipairs(parts(plant))do if p:GetAttribute('ApprovedMesh')then meshParts[#meshParts+1]=p end end
  check(#meshParts==1 and meshParts[1]:GetAttribute('ApprovedMesh')==KEY[form+1]and meshParts[1].Material==R.Enum.Material.Neon and meshParts[1].Transparency>0,NAMES[form+1]..': one baked MeshPart, '..KEY[form+1]..', Neon, translucent')
  local framed=0;for _,p in ipairs(parts(plant))do if p:GetAttribute('HologramFrame')~=nil then framed+=1 end end
  local rays=0;for _,s in ipairs(group(base,0))do if not s.mechFixed then rays+=1 end end
  check(framed==COUNT[form+1]+rays,NAMES[form+1]..': the fruit parts (and the '..rays..' projection rays, as before) carry a HologramFrame ('..framed..'): they spin')
  plant.Parent=W.workspace
  local n=Hologram.Apply(plant,c,origin,10);check(n==framed,NAMES[form+1]..': Hologram.Apply poses '..n..' hologram parts')
  local moved=false;for _,p in ipairs(parts(plant))do if p:GetAttribute('ApprovedMesh')then moved=moved or(p.CFrame.Position-origin:PointToWorldSpace(V3(0,base.Sockets[1][2],0))).Magnitude<1e-6 end end
  check(moved,NAMES[form+1]..': the mesh body turns about the socket (it stays on it)')
  local ok,why=Visuals.DetailReady(MELON,c);check(ok==true,NAMES[form+1]..': DetailReady with the templates baked ('..tostring(why)..')')
  local it=item(MELON,form);check(#parts(it)==COUNT[form+1],NAMES[form+1]..': the harvested fruit (hotbar / Bag / Index picture) is '..#parts(it)..' parts')
  local gold=Harvest.Build({SeedId=MELON,Mutation='Gold',Weather='None',VisualCrop={SourceCropId='h158d',FruitIndex=1,HarvestCycle=form}})
  local goldMesh;for _,p in ipairs(parts(gold))do if p:GetAttribute('ApprovedMesh')then goldMesh=p end end
  check(goldMesh and goldMesh:GetAttribute('ApprovedMesh')==KEY[form+1]..'_Neutral'and goldMesh.Material==R.Enum.Material.Metal,NAMES[form+1]..': a Gold coat draws the white _Neutral twin in Metal')
  local dm=Harvest.Build({SeedId=MELON,Mutation='Diamond',Weather='None',VisualCrop={SourceCropId='h158d',FruitIndex=1,HarvestCycle=form}})
  local dmesh;for _,p in ipairs(parts(dm))do if p:GetAttribute('ApprovedMesh')then dmesh=p end end
  check(dmesh and dmesh:GetAttribute('ApprovedMesh')==KEY[form+1]..'_Neutral'and dmesh.Material==R.Enum.Material.Glass,NAMES[form+1]..': a Diamond coat draws the _Neutral twin in Glass')
 end
 -- growth: the fruit grows from its socket like any Mech fruit and the mesh part shows when ripe
 local gc=crop(MELON,nil,0)
 local grown=Visuals.BuildGrowing(MELON,origin,gc,.75*Catalog[MELON].Seconds)
 check(#parts(grown)==#group(base,0)+7,'a plant at 75 % growth builds the same parts')
 local meshPart;for _,p in ipairs(parts(grown))do if p:GetAttribute('ApprovedMesh')then meshPart=p end end
 check(meshPart~=nil,'the growing plant has its mesh body')
 Visuals.EndGrowth(grown,gc,Catalog[MELON].Seconds)
 check(meshPart and meshPart.Transparency<1,'a grown Holo Melon shows its mesh body')
 -- a mixed harvest: the second harvest of the same plant is the next form
 local cyc={};for h=0,5 do cyc[#cyc+1]=Hologram.Form(crop(MELON,nil,h),1)end
 check(table.concat(cyc,',')=='0,1,2,0,1,2','the form still cycles per harvest (melon, cantaloupe, pumpkin, ...)')

 -- D. the Holo Apple Tree ---------------------------------------------------------------------------------------------------------------------------------------------
 local states={['1']={Cycle=0,ReadyAt=0},['2']={Cycle=1,ReadyAt=0},['3']={Cycle=2,ReadyAt=0},['4']={Cycle=0,ReadyAt=0}}
 local tc=crop(TREE,'t158d',0,states);local art=Approved.Get(TREE,tc)
 local realApple=group({Specs=Trees.Base('AppleSeed').Specs},1)
 local aBody=byName(realApple,'Apple body')[1]
 local FORMNAME={'Apple','Pear','Orange'};local formOf={0,1,2,0}
 check(#art.Specs==#baseTree.Specs-(88-40),'the tree has '..#art.Specs..' parts (was '..#baseTree.Specs..'): 4 fruit x (22 -> 10)')
 for g=1,4 do
  local form=formOf[g];local list=group(art,g);local nm=FORMNAME[form+1]
  check(#list==10,'fruit '..g..' ('..nm..'): '..#list..' parts (was 22)')
  local realNames={['Apple body']=1,['Apple shoulder']=2,['Apple base tone']=1,['Apple dimple']=1,['Apple stem']=1,['Apple leaf']=1}
  local ok=true
  for name,count in pairs(realNames)do local n2=name:gsub('Apple',nm);if#byName(list,n2)~=count then ok=false end end
  check(ok,'fruit '..g..': the real apple\'s parts (body, 2 shoulders, base tone, dimple, stem, leaf) under the name "'..nm..'"')
  check(#byName(list,'Hologram scan ring')==2,'fruit '..g..': 2 scan rings')
  local stems=0;for _,s in ipairs(list)do if s.f:find('hanging stem',1,true)then stems+=1 end end
  check(stems==1,'fruit '..g..': the stem that joins it to the crown is kept ('..stems..')')
  local mat,holo=true,true;for _,s in ipairs(list)do if s.m~='Neon'or not(s.t>0 and s.t<1)then mat=false end;if s.hologram~=true then holo=false end end
  check(mat and holo,'fruit '..g..': Neon, translucent, hologram')
  local body=byName(list,nm..' body')[1]
  check(body.s=='Ball','the '..nm..' body is the real apple\'s ellipsoid')
  local canopy;for _,s in ipairs(group(baseTree,g))do if s.f:find('Canopy apple',1,true)then canopy=s end end
  if form==0 then
   check(near(body.z[1],aBody.z[1],1e-4)and near(body.z[2],aBody.z[2],1e-4)and near(body.z[3],aBody.z[3],1e-4),'the apple body is the real apple\'s size '..string.format('%.3f x %.3f x %.3f',body.z[1],body.z[2],body.z[3]))
   check(dist3(body.c,canopy.c)<1e-4,'the apple sits where the old box did')
  else
   local ratio=body.z[2]/aBody.z[2]
   check(form==1 and ratio>1.1 and body.z[1]<aBody.z[1]*.9 or form==2 and ratio<.95 and body.z[1]>aBody.z[1],nm..': stretched like the old '..nm:lower()..' ('..string.format('%.2f x %.2f',body.z[1],body.z[2])..')')
  end
  local shoulders=byName(list,nm..' shoulder')
  if form==0 then
   local rl=cfOf(body):ToObjectSpace(cfOf(shoulders[1]))
   check(near(math.abs(rl.Position.X),.4085,2e-3)and near(rl.Position.Y,.4182,2e-3),'the shoulders sit where the real apple\'s do')
  end
  check(near(art.FruitRadii[g],baseTree.FruitRadii[g]*(form==1 and 1.16 or form==2 and 1.04 or 1),1e-6),'fruit '..g..': the radius is as before ('..nm..')')
  check(form~=0 or same(art.FruitCenters[g],baseTree.FruitCenters[g],1e-6),'fruit '..g..': the apple\'s centre is as before')
 end
 local treeSame=true;for i,s in ipairs(group(baseTree,0))do local m=group(art,0)[i];if m.f~=s.f or not same(m.z,s.z)or not same(m.c,s.c)then treeSame=false end end
 check(treeSame and#group(art,0)==#group(baseTree,0),'the tree itself (339 parts) is the Mech art\'s')
 local tree=Visuals.Build(TREE,origin,tc,4,math.huge);tree.Parent=W.workspace
 check(#parts(tree)==#art.Specs,'the tree builds '..#parts(tree)..' parts')
 local framed=0;for _,p in ipairs(parts(tree))do if p:GetAttribute('HologramFrame')~=nil then framed+=1 end end
 check(Hologram.Apply(tree,tc,origin,10)==framed and framed>=40,'the tree spins its '..framed..' hologram parts')
 for form=0,2 do check(#parts(item(TREE,form,1))==10,'the harvested '..FORMNAME[form+1]..' (hotbar picture) is 10 parts')end
 -- E. part budgets: fewer parts per fruit and per plant everywhere
 for form=0,2 do check(COUNT[form+1]<WIRE[form+1]/3,NAMES[form+1]..': '..COUNT[form+1]..' parts a fruit against '..WIRE[form+1]..' before')end
 check(10<WIRE_TREE/2,'an apple: 10 parts against 22 before')
 print(('INFO Holo Melon / Cantaloupe / Pumpkin: %d / %d / %d parts a fruit (was %d / %d / %d); Holo Apple Tree: 10 a fruit (was 22), %d in all (was %d)'):format(COUNT[1],COUNT[2],COUNT[3],WIRE[1],WIRE[2],WIRE[3],#art.Specs,#baseTree.Specs))
end

if scenario=='parts'or scenario=='fail'then
 check(FM.UsesMesh(MELON)==false and FM.Suffix(MELON)=='|parts','the Holo Melon does not use the meshes ('..scenario..'): Suffix is |parts so the spec cache never mixes')
 for form=0,2 do
  local art=Approved.Get(MELON,crop(MELON,nil,form));local g1=group(art,1)
  check(#g1==WIRE[form+1],NAMES[form+1]..': keeps its wire form, '..#g1..' parts')
  local edge=form==0 and'Square melon edge'or form==1 and'Square cantaloupe edge'or'Square pumpkin edge'
  check(#byName(g1,edge)==12,NAMES[form+1]..': the 12 wire edges ('..edge..')')
  check(#byName(g1,'Cantaloupe cross scan')==(form==1 and 6 or 0),NAMES[form+1]..': the cantaloupe\'s cross scans only for the cantaloupe')
  local meshes=0;for _,s in ipairs(g1)do if s.mesh then meshes+=1 end end
  check(meshes==0,NAMES[form+1]..': no mesh spec')
  local plant=Visuals.Build(MELON,origin,crop(MELON,nil,form),4,math.huge)
  check(#parts(plant)==#group(base,0)+WIRE[form+1],NAMES[form+1]..': the plant builds the old part count')
  check(select(1,Visuals.DetailReady(MELON,crop(MELON,nil,form)))==true,NAMES[form+1]..': DetailReady (no mesh to wait for)')
 end
 -- a wire form is exactly the R57 palette: cantaloupe / pear teal, pumpkin / orange violet
 local c1=group(Approved.Get(MELON,crop(MELON,nil,1)),1);local c2=group(Approved.Get(MELON,crop(MELON,nil,2)),1)
 check(same(byName(c1,'Square cantaloupe edge')[1].k,{96,248,225})and same(byName(c2,'Square pumpkin edge')[1].k,{160,166,255}),'the wire forms keep their palettes')
 -- the apple tree needs no mesh: the same new fruit
 local states={['1']={Cycle=0,ReadyAt=0},['2']={Cycle=1,ReadyAt=0},['3']={Cycle=2,ReadyAt=0},['4']={Cycle=0,ReadyAt=0}}
 local art=Approved.Get(TREE,crop(TREE,'t158d',0,states))
 check(#group(art,1)==10 and#group(art,2)==10,'the Holo Apple Tree is the new apple fruit with or without the bake')
 check(select(1,Visuals.DetailReady(TREE,crop(TREE,'t158d',0,states)))==true,'the Holo Apple Tree never waits for a mesh')
 if scenario=='fail'then
  check(FM.Status('HoloMelon158')=='Failed'and FM.Status('HoloMelon158',true)=='Failed','HoloMelon158 is marked Failed (both templates)')
  check(FM.UsesMesh('SunflowerSeed')==true and FM.UsesMesh('EmberBloomSeed')==true and FM.Status('Watermelon149')=='Ready','the real Watermelon / Ember Pumpkin meshes are not touched by the failure')
  check((W.warns or 0)==1,'one warning for the failed bake ('..(W.warns or 0)..')')
 end
end

if scenario=='loading'then
 check(FM.UsesMesh(MELON)==true and FM.Suffix(MELON)=='','a folder with nothing baked: the Holo Melon uses the meshes (Loading)')
 check(FM.Status('HoloMelon158')=='Loading','the template is Loading')
 for form=0,2 do
  local ok,key=Visuals.DetailReady(MELON,crop(MELON,nil,form))
  check(ok==false and key==(form==2 and'HoloPumpkin158'or'HoloMelon158'),NAMES[form+1]..': DetailReady is false while '..tostring(key)..' loads (the garden keeps the silhouette)')
  check(#group(Approved.Get(MELON,crop(MELON,nil,form)),1)==({7,9,7})[form+1],NAMES[form+1]..': the mesh form is the art meanwhile')
 end
 local okBuild,why=pcall(Visuals.Build,MELON,origin,crop(MELON,nil,0),4,math.huge)
 check(not okBuild and tostring(why):find('still loading',1,true)~=nil,'a build while the template loads says "still loading" (ItemPictures retries)')
 local ok2=select(1,Visuals.DetailReady(TREE,crop(TREE,'t158d',0)));check(ok2==true,'the apple tree is ready at once')
end

print(('%s: %d checks, %d failures'):format(scenario,checks,fails))
if fails>0 then error(fails..' failure(s)',0)end
