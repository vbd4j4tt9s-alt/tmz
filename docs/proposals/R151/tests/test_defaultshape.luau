--!nocheck
-- R151 (owner: "... shapes for visual representation ... can just use the default pack shape", with the R151 shape variations in the game): the DEFAULT-pouch plumbing of the pack pictures on the Roblox mock with
-- the REAL ItemPictures, SeedPackVisuals, SeedPackRenderer, VerityPackArt, VerityPouch151 and PackShapes151, the REAL pack templates of the owner's place (42 designs, pack_templates.luau)
-- and the EditableMesh mock (pouch_mock.luau), with the shape variations ON (auto: every design has its own). A picture whose proxy carries the attribute DefaultPackShape (nothing in the
-- game sets it yet: a picture that must show the plain pouch, e.g. a catalogue or a shop, sets it) is the plain pouch; every other picture keeps its shape.
--  1. the 42 designs  a picture asked for with a DefaultPackShape proxy is built from the design's OWN mesh: every MeshPart has the template's MeshId and Size and is not a baked mesh, no
--                     variation was requested (PackShapes151 stays Idle for every design), no EditableMesh was created; the same design asked for as a hotbar / Bag picture IS reshaped (the control)
--  2. modes           the owner's /test packshape (off, auto, forced 1..6) changes nothing in such a picture; it changes the other pictures
--  3. the other packs the Void and the Mech pack share their one look with the hotbar (no second template)
--  4. Verity          the server's pouch carries Storm_02's variation; the client bakes its own plain copy for a flagged picture (once, waits like any picture, the EditableMesh destroyed, every vertex
--                     colour white, no vertex moved); with the variations off the server's pouch is already plain (no client bake); a denied bake falls back to the server's pouch; the world's pack
--                     and the hotbar's picture keep the shaped one
--  5. the build path  SeedPackVisuals.Bag(..., defaultShape) marks the bag; SeedPackRenderer never asks PackShapes151 for a marked bag; nothing else about a pack changes
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local Run=W.Run
local function server()Run.IsServer=function()return true end;Run.IsClient=function()return false end end
local function client()Run.IsServer=function()return false end;Run.IsClient=function()return true end end
server()
local Shapes=W.module('PackShapes151');local Pouch=W.module('VerityPouch151');local Rules=H.Rules;local Visuals=H.Visuals
local Pic=W.module('ItemPictures')
local assets=W.RS.SeedPackMeshAssets
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do p.MeshSize=p.Size end end -- (the place's templates have a MeshSize; the generated ones do not)
local function folder()return W.RS:FindFirstChild(Shapes.Folder)end
local function vfolder()return W.RS:FindFirstChild(Pouch.Folder)end
local function dropVerity()local f=vfolder();if f then f:Destroy()end end -- (a server that starts again: the folder is made anew, Prepare bakes again)
local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=H.pg
local holders={};local nextX=0
local function holder()local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(nextX%1200,math.floor(nextX/1200)*70);nextX+=70;holders[#holders+1]=h;return h end
-- a clean slate: no holder of an earlier part keeps asking ItemPictures for its picture, no cache, no bake, no plain copy
local function fresh()
 for _,h in ipairs(holders)do h:Destroy()end;holders={};nextX=0
 Pic.Reset();Shapes.Reset();Mock.reset();Pouch.ResetPlain();Shapes.Config.Enabled=true;Shapes.Config.Force=nil
 local f=folder();if f then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)end
end
local function view(h)return h:FindFirstChild('ItemViewport')end
local function meshes(v)local out={};for _,d in ipairs(v:GetDescendants())do if d:IsA('MeshPart')then out[#out+1]=d end end;table.sort(out,function(a,b)return a.Name<b.Name end);return out end
local function frames(n)for _=1,n do W.frames(1)end end
local function proxyOf(stage,variant,plain)
 local f=R.new('Folder');f:SetAttribute('SeedPackTool',true);f:SetAttribute('Stage',stage);f:SetAttribute('BagVariant',variant);f:SetAttribute('PackMutation','None')
 if plain then f:SetAttribute('DefaultPackShape',true)end
 return f
end
-- a picture that must show the default pouch: the ordinary proxy, flagged DefaultPackShape
local function indexProxy(stage,variant)return proxyOf(stage,variant,true)end
-- how many vertices a baked mesh has moved from where the template put them (0 = the plain pouch, > 0 = a shape variation was applied)
local function moved(mesh)if not mesh then return -1 end;local n=0;for i,p in ipairs(mesh._pos)do if(p-mesh._init[i]).Magnitude>1e-9 then n+=1 end end;return n end
local DESIGNS={}
for stage=1,7 do for tier=1,6 do local v=string.format('Pack%02d',tier);DESIGNS[#DESIGNS+1]={Stage=stage,Variant=v,Key=Rules.DesignKey(stage,v)}end end
local function scaleOf(d)return Rules.GetVariant(d.Variant).BagScale*Rules.GetTheme(d.Stage).Scale end
-- 1. the 42 designs, shape variations on --------------------------------------------------------------------------------------------------------------------
do
 fresh();client()
 check(Shapes.Mode()=='auto','the shape variations are ON (auto: every design has its own) while the flagged pictures are made')
 local byKey={}
 for _,d in ipairs(DESIGNS)do local h=holder();byKey[d.Key]=h;Pic.Show(h,indexProxy(d.Stage,d.Variant),2)end
 frames(400)
 local drawn,own,baked,requested=0,0,0,0
 for _,d in ipairs(DESIGNS)do
  local v=view(byKey[d.Key])
  if v then
   drawn+=1
   local tpl=assets[d.Key];local want={};for _,p in ipairs(tpl:GetChildren())do if p:IsA('MeshPart')then want[#want+1]=p end end;table.sort(want,function(a,b)return a.Name<b.Name end)
   local got=meshes(v);local same=#got==#want
   for i,p in ipairs(want)do
    local m=got[i];if not(m and m.MeshId==p.MeshId and near(m.Size.X,p.Size.X*scaleOf(d),1e-5)and near(m.Size.Y,p.Size.Y*scaleOf(d),1e-5)and near(m.Size.Z,p.Size.Z*scaleOf(d),1e-5))then same=false end
    if m and(m.Baked~=nil or m.MeshId=='')then baked+=1 end
   end
   if same then own+=1 end
  end
  if Shapes.State(d.Key)~='Idle'then requested+=1 end
 end
 check(drawn==42,'all 42 flagged pictures are drawn ('..drawn..')')
 check(own==42,'every one is built from the design\'s OWN mesh parts: the template\'s MeshId and Size x the pack scale, part for part ('..own..' of 42)')
 check(baked==0,'no picture part is a baked / reshaped mesh ('..baked..')')
 check(Mock.created==0 and Mock.calls==0 and Mock.baked==0,'no EditableMesh was created, none loaded, nothing baked ('..Mock.created..' / '..Mock.calls..' / '..Mock.baked..')')
 check(requested==0,'PackShapes151 was never asked for any of the 42 designs: every design is still Idle ('..requested..' asked)')
 local st=Shapes.Status();check(st.Requested==0 and st.Pending==0,'PackShapes151.Status: nothing requested, nothing pending ('..st.Requested..' / '..st.Pending..')')
 -- the control: the SAME design asked for as an ordinary (hotbar / Bag) picture is reshaped
 local before=Mock.created
 local c=holder();Pic.Show(c,proxyOf(1,'Pack02',false),2)
 frames(200);while Mock.resume()do end;frames(300)
 local cv=view(c);local cm=cv and meshes(cv)[1]
 check(Mock.created>before and Shapes.State('Forest_02')=='Ready'and cm and cm.MeshId==''and moved(cm.Baked)>0,'(control) a hotbar / Bag picture of Forest_02 IS reshaped: PackShapes151 baked it and moved '..moved(cm and cm.Baked)..' vertices')
 check(Pic.Key(proxyOf(1,'Pack02',true))~=Pic.Key(proxyOf(1,'Pack02',false)),'(and its look has its own cache key: |Plain)')
end
-- 2. modes ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local tpl=assets.Forest_03.ApprovedMesh01;local want=tpl.Size*scaleOf({Stage=1,Variant='Pack03'})
 for _,mode in ipairs({'off','auto',1,2,3,4,5,6})do
  fresh();server();Shapes.SetMode(mode);client()
  local base=Mock.created -- (the owner's command also re-bakes the Verity pouch: not ours)
  local h=holder();Pic.Show(h,indexProxy(1,'Pack03'),2);frames(150)
  local m=view(h)and meshes(view(h))[1]
  check(m and m.MeshId==tpl.MeshId and m.Baked==nil and near(m.Size.X,want.X,1e-5)and near(m.Size.Z,want.Z,1e-5),'/test packshape '..tostring(mode)..': the flagged Forest_03 is still the design\'s own mesh (MeshId '..tostring(m and m.MeshId)..')')
  check(Mock.created==base and Shapes.Status().Requested==0 and Shapes.Status().Pending==0,'... nothing was baked for it and PackShapes151 was not asked for the design ('..(Mock.created-base)..' baked, '..Shapes.Status().Requested..' asked)')
 end
 -- the other pictures do follow the mode (so the test above is not vacuous)
 fresh();server();Shapes.SetMode(2);client()
 local h=holder();Pic.Show(h,proxyOf(1,'Pack03',false),2);frames(150);while Mock.resume()do end;frames(300)
 local m=view(h)and meshes(view(h))[1]
 check(m and m.MeshId==''and moved(m.Baked)>0,'(control) with variation 2 forced, the ordinary picture of Forest_03 is the baked, reshaped pouch')
 fresh();server();Shapes.SetMode('auto');client()
end
-- 3. the other packs ----------------------------------------------------------------------------------------------------------------------------------------------
do
 fresh();client()
 local a,b,c,d=holder(),holder(),holder(),holder()
 Pic.Show(a,indexProxy(7,'EclipseReliquary'),2);Pic.Show(b,proxyOf(7,'EclipseReliquary',false),1);Pic.Show(c,indexProxy(8,'MechLimited'),2);Pic.Show(d,proxyOf(8,'MechLimited',false),1)
 frames(200)
 check(view(a)and view(b)and view(c)and view(d),'the Void and the Mech pack are drawn flagged and in the hotbar')
 check(Pic.Key(indexProxy(7,'EclipseReliquary'))==Pic.Key(proxyOf(7,'EclipseReliquary',false))and Pic.Key(indexProxy(8,'MechLimited'))==Pic.Key(proxyOf(8,'MechLimited',false)),'the Void and the Mech pack have no shape variation, so a flagged picture and the hotbar share ONE look (one template, not two)')
 check(Pic.Stats().Templates==2,'... two templates for the four pictures ('..Pic.Stats().Templates..')')
 check(Mock.created==0,'... and no mesh was baked for either')
end
-- 4. Verity -----------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local KEY='Storm_02';local VERITY=H.VERITY;local tpl=assets[KEY].ApprovedMesh01
 local function pouchOf(h)local v=view(h);if not v then return nil end;for _,m in ipairs(meshes(v))do if m.Name=='ApprovedMesh01'then return m end end end
 local function decals(m)local n=0;for _,d in ipairs(m:GetChildren())do if d:IsA('Decal')then n+=1 end end;return n end
 -- the server bakes the Verity pouch in Storm_02's variation
 fresh();server();dropVerity();Pouch.Prepare()
 local f=vfolder();local shaped=f and f:FindFirstChild(KEY)
 check(f and f:GetAttribute('Ready')==true and shaped and shaped:GetAttribute('PackShape')==Shapes.Assign(KEY)and Shapes.Assign(KEY)~=0,'(setup) the server\'s Verity pouch carries Storm_02\'s variation ('..tostring(shaped and shaped:GetAttribute('PackShape'))..')')
 local shapedMesh=Mock.meshes[#Mock.meshes];check(moved(shapedMesh)>0,'... its vertices were moved ('..moved(shapedMesh)..' of '..#shapedMesh._pos..')')
 local createdServer=Mock.created
 client();Mock.slow=true
 local h=holder();Pic.Show(h,indexProxy(7,VERITY),2);frames(150)
 check(view(h)==nil and Pouch.PlainState(KEY)=='Loading','the flagged Verity picture waits for the client\'s plain bake ("still loading", retried): no picture, nothing cached meanwhile')
 while Mock.resume()do end
 check(Pouch.PlainState(KEY)=='Ready','the plain bake finishes')
 frames(400)
 local plainMesh=Mock.meshes[#Mock.meshes]
 local m=pouchOf(h)
 check(m and m.Baked==plainMesh and plainMesh~=shapedMesh and moved(plainMesh)==0,'the flagged Verity pouch is the client\'s PLAIN mesh: no vertex moved ('..moved(plainMesh)..'), not the server\'s shaped one')
 check(m and decals(m)==2 and m.Color.R==1 and m.Color.G==1 and m.Color.B==0,'... pure yellow with Verity\'s face as two Decals, like the pack in the game')
 check(Mock.created==createdServer+1 and Mock.alive==0,'the client made ONE EditableMesh for it and destroyed it ('..(Mock.created-createdServer)..' made, '..Mock.alive..' alive)')
 local plainModel=Pouch.PlainTemplate(KEY);check(plainModel and plainModel:GetAttribute('PackShape')==0 and plainModel:GetAttribute('Neutral')==true and plainModel.Parent==nil,'the plain copy is a neutral model with PackShape 0, kept in memory (not in the world)')
 check(Mock.colorsAtBake[#Mock.colorsAtBake]==0,'every vertex colour was white when it was baked')
 check(Mock.uris[#Mock.uris]==tpl.MeshId,'the mesh loaded is the live template\'s MeshId (never a literal)')
 -- asked again: no second bake
 local calls=Mock.calls;local h2=holder();Pic.Show(h2,indexProxy(7,VERITY),2);frames(200)
 check(view(h2)and Mock.calls==calls,'a second Verity card asks again: no second bake')
 -- the world's Verity pack and the hotbar's picture keep the shaped pouch
 server();local bag=H.ground(7,VERITY,1,'None');client()
 local wp;for _,p in ipairs(bag:GetDescendants())do if p.Name=='ApprovedMesh01'and p:IsA('MeshPart')then wp=p end end
 check(wp and wp.Baked==shapedMesh,'the Verity pack in the world is still the server\'s shaped pouch (the flag touches no other pack)')
 local h3=holder();Pic.Show(h3,proxyOf(7,VERITY,false),1);frames(300)
 local hm=pouchOf(h3);check(hm and hm.Baked==shapedMesh,'the hotbar\'s Verity picture is the shaped pouch too')
 Mock.slow=false
 -- the variations off: the server's pouch is already plain, the client bakes nothing
 fresh();server();Shapes.Config.Enabled=false;dropVerity();Pouch.Prepare();client()
 local plainServer=Mock.meshes[#Mock.meshes];local before=Mock.created
 local h4=holder();Pic.Show(h4,indexProxy(7,VERITY),2);frames(300)
 local m4=pouchOf(h4)
 check(m4 and m4.Baked==plainServer and moved(plainServer)==0 and Mock.created==before and Pouch.PlainState(KEY)=='Ready','variations off: the server\'s pouch is plain already, the flagged picture uses it, no client bake')
 -- a denied client bake: a flagged picture keeps the server's pouch
 fresh();server();dropVerity();Pouch.Prepare();local shaped2=Mock.meshes[#Mock.meshes];client();Mock.mode='denied'
 local h5=holder();Pic.Show(h5,indexProxy(7,VERITY),2);frames(400)
 local m5=pouchOf(h5)
 check(Pouch.PlainState(KEY)=='Off'and m5 and m5.Baked==shaped2 and decals(m5)==2,'a denied bake: the plain state is Off and the flagged picture shows the server\'s own pouch (still the real pouch, not the sachet) ('..tostring(Pouch.PlainState(KEY))..', picture '..tostring(m5~=nil)..', same mesh '..tostring(m5 and m5.Baked==shaped2)..')')
 Mock.mode='ok'
 -- no server pouch at all: the sachet, as before
 fresh();server();dropVerity();client()
 local h6=holder();Pic.Show(h6,indexProxy(7,VERITY),2);frames(200)
 check(view(h6)and pouchOf(h6)==nil,'a server that bakes no pouch: the sachet, as for every Verity picture')
 fresh();server();dropVerity();Pouch.Prepare();client()
end
-- 5. the build path ---------------------------------------------------------------------------------------------------------------------------------------------------
do
 fresh();server()
 local calls=0;local base=Shapes.ForBuild
 Shapes.ForBuild=function(key)calls+=1;return base(key)end
 local marked=Visuals.Bag(CF(0,0,0),nil,1,nil,1,'Pack04',1,1,'None',nil,true)
 check(marked:GetAttribute('DefaultPackShape')==true and calls==0,'SeedPackVisuals.Bag(..., defaultShape) marks the bag and never asks PackShapes151 for a shape ('..calls..' calls)')
 local plainBag=Visuals.Bag(CF(0,0,0),nil,1,nil,1,'Pack04',1,1,'None')
 check(plainBag:GetAttribute('DefaultPackShape')==nil and calls==1,'an ordinary bag is not marked and does ask ('..calls..' call)')
 local f=Visuals.Bag(CF(0,0,0),nil,1,nil,1,'Pack04',1,1,'None',nil,false)
 check(f:GetAttribute('DefaultPackShape')==nil,'defaultShape false / nil: not marked')
 local mesh=function(b)local pg=b:FindFirstChild('PackGeometry');return pg and pg:FindFirstChild('ApprovedMesh01')end
 check(mesh(marked)and mesh(marked).MeshId==assets.Forest_04.ApprovedMesh01.MeshId and mesh(marked).Baked==nil,'the marked bag is the design\'s own mesh')
 Shapes.ForBuild=base
 -- the renderer's one door to the shape code
 local src=require('./rs_bundle')
 local _,n=src.SeedPackRenderer:gsub('PackShapes151','');check(n==2,'SeedPackRenderer still reaches PackShapes151 from the ordinary build only (the comment and the call: '..n..' mentions)')
end
gui:Destroy()
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
