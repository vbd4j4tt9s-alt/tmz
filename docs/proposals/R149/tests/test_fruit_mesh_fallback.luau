--!nocheck
-- R149 baked fruit meshes: what happens when a bake fails. Each scenario is its own world (FruitMeshes149 remembers a seed's final state):
--   luau test_fruit_mesh_fallback.luau -a neutral   the 8th EditableMesh (the Snow Melon's neutral twin; R158d: after the two hologram keys, 4 before) gets no memory: the Snow Melon goes back
--                                                   to its part-built fruit (both its templates dropped), the Watermelon and Ember Pumpkin keep
--                                                   their meshes; logged once; Prepare again changes nothing;
--   luau test_fruit_mesh_fallback.luau -a every     EditableMesh is not available at all: all three keep the R149 part-built fruit, one log line;
--   luau test_fruit_mesh_fallback.luau -a content   CreateDataModelContentAsync fails for the first mesh: the Ember Pumpkin falls back, the
--                                                   EditableMesh is still destroyed;
--   luau test_fruit_mesh_fallback.luau -a server    a server whose first build of a melon starts the bake and the bake fails in the middle of
--                                                   that build (the market at server start): that one build draws a plain ellipsoid in the
--                                                   melon's colour, never errors; later builds are part-built; then a server where it works:
--                                                   the first build bakes on demand and gets the mesh (-a serverok);
--   luau test_fruit_mesh_fallback.luau -a garden    the real GardenVisuals on a garden of the three: while the templates are still loading it keeps
--                                                   the server silhouette (no detail, no warning); once they arrive it builds the plants with
--                                                   their mesh bodies (needs GardenVisuals in the bundle).
local SCENARIO=...
local W=require('./world');local R=W.R;local V3=R.Vector3.new
W.env.CFrame=R.CFrame
local Mock=require('./fruit_mesh_mock')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local IDS={SunflowerSeed={Key='Watermelon149',Body='Melon body',Parts=11,Mesh=4,Tone={108,180,76},First='Melon rind'},
 SnowdropSeed={Key='SnowMelon149',Body='Snow melon body',Parts=12,Mesh=4,Tone={190,232,234},First='Snow melon rind'},
 EmberBloomSeed={Key='EmberPumpkin149',Body='Pumpkin body',Parts=24,Mesh=4,Tone={232,108,28},First='Pumpkin heart'}}
local ORDER={'SunflowerSeed','SnowdropSeed','EmberBloomSeed'}
local Harvest,Visuals,FM,Catalog
local function load()Catalog=W.module('PlantCatalog');Visuals=W.module('PlantVisuals');Harvest=W.module('HarvestPresentation');FM=W.module('FruitMeshes149')end
local function hotbar(id,mut)return Harvest.Build({SeedId=id,Mutation=mut or'None',Weather='None',VisualCrop={SourceCropId='fb-'..id,FruitIndex=1,HarvestCycle=0}})end
local function visible(m)local n,mesh=0,0;for _,p in ipairs(m:GetDescendants())do if p:IsA('BasePart')and p.Name~='VisualPivot'and p.Transparency<1 then n+=1;if p.ClassName=='MeshPart'then mesh+=1 end end end;return n,mesh end
local function crop(id)local d=Catalog[id];return {Id='fb-crop',SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}end
-- a seed on its part-built fruit: no mesh spec, the R149 pieces (first piece name), its R149 picture, nothing to wait for
local function partBuilt(id,label)
 local m=IDS[id];local mesh,first=0,false
 for _,s in ipairs(Visuals.Specs(id))do if s.mesh then mesh+=1 end;if s.g==1 and s.f==m.First then first=true end end
 local n,meshParts=visible(hotbar(id));local g,gm=visible(hotbar(id,'Gold'))
 check(FM.UsesMesh(id)==false and FM.Suffix(id)=='|parts'and mesh==0 and first and n==m.Parts and meshParts==0 and gm==0 and Visuals.DetailReady(id,crop(id))==true,
  label..': '..id..' shows its R149 part-built fruit ('..n..' parts, no mesh, nothing to wait for)')
end
local function meshBuilt(id,label)
 local n,meshParts=visible(hotbar(id));local g,gm=visible(hotbar(id,'Gold'))
 check(FM.UsesMesh(id)==true and n==IDS[id].Mesh and meshParts==1 and gm==1 and Visuals.DetailReady(id,crop(id))==true,label..': '..id..' keeps its baked mesh ('..n..' parts)')
end
local function failures(f)local t={};local list=f:FindFirstChild('Failures');for _,v in ipairs(list and list:GetChildren()or{})do t[v.Name]=v.Value end;return t end

if SCENARIO=='neutral'or SCENARIO=='every'or SCENARIO=='content'then
 local opts=({neutral={FailAt=8},every={Missing=true},content={ContentFail=1}})[SCENARIO]
 local log=Mock.install(W,opts);load()
 local ready,errors=Mock.prepare(W)
 local f=W.RS:FindFirstChild(FM.Folder);local fl=failures(f)
 local failed=({neutral={SnowMelon149=true},every={Watermelon149=true,SnowMelon149=true,EmberPumpkin149=true,HoloMelon158=true,HoloPumpkin158=true},content={EmberPumpkin149=true}})[SCENARIO]
 local nFailed=0;for _ in pairs(failed)do nFailed+=1 end
 check(ready==false and #errors==nFailed,SCENARIO..': Prepare reports '..nFailed..' failure(s): '..tostring(errors and errors[1]))
 check((W.warns or 0)==1,SCENARIO..': logged exactly once ('..tostring(W.warns)..' warning(s))')
 check(f:GetAttribute('Ready')==false and f:GetAttribute('FailureCount')==nFailed and f:GetAttribute('PreparationFinished')==true,SCENARIO..': the folder says not Ready, '..nFailed..' failure(s), finished')
 for _,id in ipairs(ORDER)do
  local key=IDS[id].Key
  if failed[key]then
   local a,why=FM.Status(key);local b=FM.Status(key,true)
   check(a=='Failed'and b=='Failed'and fl[key]~=nil and fl[key..'_Neutral']~=nil and f:FindFirstChild(key)==nil and f:FindFirstChild(key..'_Neutral')==nil and tostring(why):find(key,1,true)~=nil,
    SCENARIO..': '..key..' is Failed (normal and neutral, both templates dropped): '..tostring(why))
   partBuilt(id,SCENARIO)
  else
   check(FM.Status(key)=='Ready'and FM.Status(key,true)=='Ready'and fl[key]==nil,SCENARIO..': '..key..' baked')
   meshBuilt(id,SCENARIO)
  end
 end
 check(log.Destroyed==log.Editables,SCENARIO..': every EditableMesh made was destroyed, the failed bake\'s too ('..log.Destroyed..' / '..log.Editables..')')
 local calls,contents,warns=log.Calls,#log.Contents,W.warns
 check(Mock.prepare(W)==false and log.Calls==calls and#log.Contents==contents and W.warns==warns,SCENARIO..': Prepare again tries nothing and logs nothing')
 -- the fallen-back seed's whole plant (every build mode the regression diff covers is in run_fruit_models.sh's fallback dumps)
 for _,id in ipairs(ORDER)do if failed[IDS[id].Key]then
  local plant=Visuals.Build(id,R.CFrame.new(0,0,0),crop(id),4,math.huge);local _,mesh=visible(plant)
  local grow=Visuals.BuildGrowing(id,R.CFrame.new(0,0,0),crop(id),.9*Catalog[id].Seconds);local _,gmesh=visible(grow)
  check(mesh==0 and gmesh==0,SCENARIO..': '..id..'\'s plant and growing plant have no mesh part')
 end end
elseif SCENARIO=='server'then
 -- 1. the bake fails in the middle of the first build (EditableMesh missing)
 local log=Mock.install(W,{Missing=true})
 W.Run.IsServer=function()return true end;load()
 local f=W.RS:FindFirstChild(FM.Folder)
 check(f~=nil and f:GetAttribute('Ready')==false,'server: loading FruitMeshes149 makes the folder (clients then wait for the meshes instead of drawing the part-built fruit)')
 check(FM.UsesMesh('SunflowerSeed')==true,'server: the mesh build is chosen before the bake')
 local ok,model=pcall(hotbar,'SunflowerSeed')
 check(ok,'server: the build that starts the failing bake does not error: '..tostring(not ok and model or''))
 if ok then
  local body;for _,p in ipairs(model:GetDescendants())do if p.Name=='Melon body'then body=p end end
  local n,mesh=visible(model)
  check(body and body.ClassName=='Part'and body:FindFirstChildOfClass('SpecialMesh')~=nil and mesh==0 and n==4,'server: that one build draws the body as a plain ellipsoid ('..n..' parts)')
  check(body and math.floor(body.Color.R*255+.5)==108 and math.floor(body.Color.G*255+.5)==180 and math.floor(body.Color.B*255+.5)==76,'server: in the Watermelon\'s rind colour')
 end
 check((W.warns or 0)==1,'server: logged once ('..tostring(W.warns)..')')
 for _,id in ipairs(ORDER)do partBuilt(id,'server after the failure')end
 check(log.Calls==0 and W.warns==1,'server: nothing more is tried')
elseif SCENARIO=='garden'then
 local log=Mock.install(W);load()
 -- the scheduler's loop really waits here (the mock's task.wait returns at once), as in docs/proposals/R148/tests/test_roster_art.luau
 local waiting={};local realWait,realAdvance=R.task.wait,R.advance;local mainThread=coroutine.running()
 R.task.wait=function(t)if coroutine.running()==mainThread then return t or 0 end;table.insert(waiting,{At=R.clock+(t or 0),Co=coroutine.running()});return coroutine.yield()end
 R.advance=function(dt)realAdvance(dt);local due,keep={},{};for _,w in ipairs(waiting)do if w.At<=R.clock then due[#due+1]=w else keep[#keep+1]=w end end;waiting=keep;for _,w in ipairs(due)do local ok,e=coroutine.resume(w.Co,dt);if not ok then error(e,0)end end end
 local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 W.workspace.CurrentCamera.CFrame=R.CFrame.lookAt(V3(0,12,-30),V3(0,2,0))
 local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
 local crops={}
 for i,id in ipairs(ORDER)do
  local m=R.new('Model');m.Name='Crop_'..i;local now=math.floor(W.workspace:GetServerTimeNow())
  for k,v in pairs({GardenPlantV141=true,CropId='g'..i,SeedId=id,GrowthStage=4,PlantScale=1,SeedScale=1,Mutation='None',Weather='None',PlantedAt=now-100000,MatureAt=now-90000,ReadyAt=now-90000,HarvestCycle=0,PickedMask=0,FruitReady=true,FruitGrowing=false,FruitRevision=1})do m:SetAttribute(k,v)end
  local a=R.new('Part');a.Name='CropAnchor';a.CFrame=R.CFrame.new((i-2)*7,0,-8);a.Parent=m;m.Parent=map;crops[id]=m
 end
 -- the server has made the folder (FruitMeshes149 loaded there) but nothing is baked yet
 local f=R.new('Folder');f.Name=FM.Folder;f.Parent=W.RS
 local gv=R.new('LocalScript');gv.Name='GardenVisuals';gv.Parent=player
 local okGV,errGV=pcall(W.load,'GardenVisuals',gv)
 check(okGV,'garden: GardenVisuals loads ('..tostring(errGV)..')')
 W.frames(240)
 local none=true;for _,m in pairs(crops)do if m:FindFirstChild('LocalPlantArt')then none=false end end
 check(none and(W.warns or 0)==0,'garden: while the templates load, no detail is built (the server silhouette stays) and nothing is logged')
 -- the bake finishes (the templates replicate)
 check(Mock.prepare(W)==true,'garden: the server bake')
 W.frames(360)
 for _,id in ipairs(ORDER)do
  local art=crops[id]:FindFirstChild('LocalPlantArt');local mesh=0
  if art then for _,p in ipairs(art:GetDescendants())do if p.ClassName=='MeshPart'and p.Name==IDS[id].Body then mesh+=1 end end end
  check(art~=nil and mesh==Catalog[id].FruitCount,'garden: '..id..' is built in detail with its '..Catalog[id].FruitCount..' mesh bodies ('..mesh..')')
 end
 check((W.warns or 0)==0,'garden: no warning ('..tostring(W.warns)..')')
 R.task.wait=realWait;R.advance=realAdvance
else
 -- 2. a server where the bake works: the first build bakes on demand
 local log=Mock.install(W)
 W.Run.IsServer=function()return true end;load()
 local n,mesh=visible(hotbar('EmberBloomSeed'))
 check(n==4 and mesh==1 and #log.Contents==10 and(W.warns or 0)==0,'server ok: the first build (e.g. the market at server start) bakes every key on demand and gets its mesh ('..#log.Contents..' bakes)')
 check(FM.Prepare()==true and #log.Contents==10,'server ok: the bootstrap\'s Prepare afterwards bakes nothing more')
 for _,id in ipairs(ORDER)do meshBuilt(id,'server ok')end
 W.Run.IsServer=function()return false end
 local ok,why=pcall(FM.Prepare);check(not ok and tostring(why):find('server-only',1,true)~=nil,'a client cannot bake')
end
print(('R149 fruit mesh fallback (%s): %d checks, %d failures'):format(tostring(SCENARIO),checks,fails))
if fails>0 then error(fails..' checks failed')end
