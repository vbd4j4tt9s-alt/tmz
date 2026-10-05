--!nocheck
-- R152 baked keeper models on the Roblox mock, with the REAL modules of this checkout: KeeperMeshes152 (+ its 8 mesh data modules),
-- KeeperRigConfig152, BeastModels, KeeperUpgradeArt, KeeperContact, KeeperMeshCommand152, VeiledKeeper81, BeastPose, KeeperUpgradePose,
-- KeeperStrikeFrames, KeeperSignatureStrike, KeeperAccents, KeeperSleep and the BeastAnimation client script.
-- Scenario (luau test_keepers.luau -a <scenario>):
--   main     the bake of all 8 keepers (what each EditableMesh received, the templates, no EditableMesh alive), the spawn path never waits
--            for it (keepers dressed before it show today's model, then swap when idle, a chasing keeper only after its chase), part counts
--            match KeeperRigConfig152, the two faces swap on sleep / wake (BeastAnimation), the golem's tree disguise, KeeperContact skips
--            face parts and the knight's Sword_Point, retired accents, the new sleep Z, grounding of the new meshes, the Darkened, the owner
--            command, gameplay values untouched.
--   throw    CreateEditableMesh errors ("Allow Mesh / Image APIs" off): every keeper keeps today's model, one warning.
--   missing  no CreateEditableMesh at all: the same, quietly reported as unavailable.
--   failat   the 20th CreateEditableMesh returns nil mid-keeper: that keeper keeps today's model, the others are baked.
--   content  the 50th CreateDataModelContentAsync fails: the same for that keeper.
--   nomodule KeeperMeshes152 is not installed (a broken install): BeastModels dresses every keeper with today's model.
local SCENARIO=...or'main'
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./keeper_mesh_mock')
local checks,fails=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local opts={}
if SCENARIO=='throw'then opts.Throw=true elseif SCENARIO=='missing'then opts.Missing=true elseif SCENARIO=='failat'then opts.FailAt=20 elseif SCENARIO=='content'then opts.ContentFail=50 end
local log=Mock.install(W,opts)
W.Run.IsServer=function()return true end -- the bake and the dressing are server code (BeastAnimation does not ask)
local RS=W.RS;local SS=W.service('ServerStorage');local CS=W.service('CollectionService')
local Cfg=W.module('KeeperRigConfig');local C152=W.module('KeeperRigConfig152')
-- today's imported mesh templates for stages 2, 3, 4, 6 (ServerStorage.KeeperTemplatesV100), stand-ins from KeeperRigConfig's parts
do local tf=R.new('Folder');tf.Name='KeeperTemplatesV100';tf.Parent=SS
 for _,stage in ipairs({2,3,4,6})do
  local m=R.new('Model');m.Name='Stage'..stage;m:SetAttribute('VisualVersion',99)
  for _,s in ipairs(Cfg[stage].Parts)do
   local p=R.new('MeshPart');p.Name=s.Name;p.Size=V3(s.Size[1],s.Size[2],s.Size[3]);local rest=CF(s.Center[1],s.Center[2],s.Center[3]);p.CFrame=rest
   p:SetAttribute('RestCFrame',rest);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.Parent=m
  end
  -- (Roblox's Clone keeps attributes; the plain mock Clone drops them)
  rawset(m,'Clone',function(self)
   local c=R.new('Model');for k,v in pairs(self._props)do c._props[k]=v end;for k,v in pairs(self._attrs)do c._attrs[k]=v end
   for _,ch in ipairs(self._children)do local q=R.Inst.Clone(ch);for k,v in pairs(ch._attrs)do q._attrs[k]=v end;q.Parent=c end
   return c
  end)
  m.Parent=tf
 end
end
local ORDER={1,6,2,3,4,5,7,0}
local function keeperModel(stage,at)
 local m=R.new('Model');m.Name='Guardian_Stage'..stage;local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=at;root.Parent=m;m.PrimaryPart=root
 m:SetAttribute('GuardianBehavior','GUARDING');m:SetAttribute('GuardianLeaseToken',0);m.Parent=W.workspace;CS:AddTag(m,'BiomeKeeper');return m
end
if SCENARIO=='nomodule'then
 -- a broken install (KeeperMeshes152 missing): BeastModels still dresses every keeper, with today's model, and says so once
 RS:FindFirstChild('KeeperMeshes152').Name='KeeperMeshes152Missing'
 local Models=W.module('BeastModels')
 for stage=1,7 do local m=keeperModel(stage,CF(stage*60,6,0));local ok=pcall(Models.Dress,m,stage)
  check(ok and m:GetAttribute('KeeperMeshVariant')=='Legacy'and #m.BeastBody:GetChildren()==#Cfg[stage].Parts,'stage '..stage..': without the mesh module the keeper is today\'s')end
 R.advance(2.1);check(W.warns==1,'one warning ('..tostring(W.warns)..')')
 print(('R152 keepers (%s): %d checks, %d failures'):format(SCENARIO,checks,fails))
 if fails>0 then error('failures',0)end
 return
end
local Meshes=W.module('KeeperMeshes152');local Models=W.module('BeastModels');local Contact=W.module('KeeperContact')
-- 1. The spawn path: keepers dressed at server start never wait for the bake ----------------------------------------------------------------
local guardians={}
local yields0=log.Yields
for stage=1,7 do
 local m=keeperModel(stage,CF(stage*60,6,0))
 local before=log.Yields;Models.Dress(m,stage)
 check(log.Yields==before,'stage '..stage..': BeastModels.Dress never yields (task.wait) while the bake is pending')
 check(m:GetAttribute('KeeperMeshVariant')=='Legacy'and m.BeastBody:GetAttribute('KeeperMeshVariant')==nil,'stage '..stage..': dressed before the bake: today\'s model')
 check(#m.BeastBody:GetChildren()==#Cfg[stage].Parts,'stage '..stage..': today\'s rig has today\'s '..#Cfg[stage].Parts..' parts')
 guardians[stage]=m
end
local status=RS:FindFirstChild('KeeperMeshStatus152')
check(status~=nil and status:GetAttribute('PreparationFinished')==false and log.Editables==0 and log.Calls==0,'Dress started the bake but did not run it inline (deferred: no EditableMesh made yet)')
check(log.Yields==yields0,'no task.wait anywhere in the spawn path')
-- a chase is on for the Lava Dragon while the bake finishes: it must not be swapped mid-chase
guardians[4]:SetAttribute('GuardianBehavior','CHASING');guardians[4]:SetAttribute('GuardianLeaseToken',7)
R.advance(0) -- runs the deferred bake (the mock's task.wait does not yield, so it completes here)
local finished=status:GetAttribute('PreparationFinished')
check(finished==true,'the deferred bake ran and finished')
local Wanted={};for _,stage in ipairs(ORDER)do Wanted[stage]=Meshes.Wanted(stage)end
check(log.Alive()==0 and log.Editables==log.Destroyed,'no EditableMesh is left alive ('..log.Editables..' made, '..log.Destroyed..' destroyed)')

if SCENARIO~='main'then
 -- 2F. Fallback scenarios -----------------------------------------------------------------------------------------------------------------
 local failed={};for _,stage in ipairs(ORDER)do if Meshes.State(stage)=='Failed'then failed[#failed+1]=stage end end
 local expectAll=SCENARIO=='throw'or SCENARIO=='missing'
 if expectAll then
  check(#failed==8 and status:GetAttribute('Ready')==false and status:GetAttribute('FailureCount')==8 and status:GetAttribute('BakedCount')==0,'every keeper failed ('..#failed..') and the status says so')
  check(log.Editables==0,'no EditableMesh was made')
  local _,why=Meshes.State(1)
  if SCENARIO=='missing'then check(why and why:find(Meshes.Unavailable,1,true)~=nil,'the reason says the API is unavailable: '..tostring(why))
  else check(why and why:find('does not allow',1,true)~=nil,'the reason carries the engine error: '..tostring(why))end
 else
  check(#failed==1 and status:GetAttribute('Ready')==false and status:GetAttribute('BakedCount')==7,'exactly one keeper failed ('..#failed..'), the other 7 are baked')
  local t=SS:FindFirstChild('KeeperMeshTemplates152');local stray=0;local stageOf={}
  for _,stage in ipairs(ORDER)do stageOf[C152.Stages[stage].Key]=stage end
  for _,m in ipairs(t:GetChildren())do if Meshes.State(stageOf[m.Name])~='Ready'then stray+=1 end end
  check(#t:GetChildren()==7 and stray==0,'only the 7 baked keepers have a template (no half-built model left)')
 end
 check(W.warns==1,'one warning for the whole bake ('..tostring(W.warns)..')')
 for _,stage in ipairs(failed)do check(Wanted[stage]==nil,'stage '..stage..' failed: Wanted is nil (today\'s model)')end
 R.advance(2.1) -- BeastModels' idle check
 for stage=1,7 do
  local m=guardians[stage];local f=table.find(failed,stage)~=nil
  if f then check(m:GetAttribute('KeeperMeshVariant')=='Legacy'and #m.BeastBody:GetChildren()==#Cfg[stage].Parts,'stage '..stage..': keeps today\'s keeper ('..#m.BeastBody:GetChildren()..' parts)')end
 end
 -- a fresh keeper of a failed stage is dressed with today's model too
 local fresh=keeperModel(failed[1],CF(0,6,300));Models.Dress(fresh,failed[1])
 check(fresh:GetAttribute('KeeperMeshVariant')=='Legacy','a keeper spawned after the failed bake is today\'s keeper')
 local Veiled=W.module('VeiledKeeper81')
 if table.find(failed,0)then
  check(Meshes.DarkenedParts()==nil or Wanted[0]==nil,'The Darkened has no new parts to build from');local d=Veiled.Build(CF(0,5,0),W.workspace,Wanted[0]and Meshes.DarkenedParts()or nil)
  check(d:GetAttribute('KeeperMeshVariant')=='Legacy'and d:FindFirstChild('VeiledMask')~=nil,'The Darkened spawns as today\'s blocks')
 end
 check(log.Alive()==0,'no EditableMesh alive after the failures')
 print(('R152 keepers (%s): %d checks, %d failures'):format(SCENARIO,checks,fails))
 if fails>0 then error('failures',0)end
 return
end

-- 2. The bake --------------------------------------------------------------------------------------------------------------------------------
check(status:GetAttribute('Ready')==true and status:GetAttribute('BakedCount')==8 and status:GetAttribute('FailureCount')==0,'all 8 keepers baked (Ready, 8 baked, 0 failed)')
-- the decoded triangles with an area (the baker leaves out zero-area slivers: collapsed bevel corners, 168 of 47,504, they draw nothing)
local function keptTris(dp)
 local k={};local V,T=dp.V,dp.T
 for t=1,#T//3 do
  local a,b,c=T[t*3-2],T[t*3-1],T[t*3];local ux,uy,uz=V[b*3-2]-V[a*3-2],V[b*3-1]-V[a*3-1],V[b*3]-V[a*3];local wx,wy,wz=V[c*3-2]-V[a*3-2],V[c*3-1]-V[a*3-1],V[c*3]-V[a*3]
  local nx,ny,nz=uy*wz-uz*wy,uz*wx-ux*wz,ux*wy-uy*wx;if math.sqrt(nx*nx+ny*ny+nz*nz)>1e-12 then k[#k+1]=t end
 end
 return k
end
local totalTris,totalParts,designTris,slivers=0,0,0,0
for _,stage in ipairs(ORDER)do
 local d=Meshes.Decode(W.module(C152.Stages[stage].Module))
 for i,s in ipairs(C152.Stages[stage].Parts)do local n=#keptTris(d.Parts[i]);totalTris+=n;designTris+=s.Triangles;slivers+=s.Triangles-n end
 totalParts+=#C152.Stages[stage].Parts
end
check(status:GetAttribute('Triangles')==totalTris and status:GetAttribute('MeshParts')==totalParts,'status: '..totalParts..' mesh parts, '..totalTris..' triangles')
check(slivers<=200,'only '..slivers..' zero-area slivers of '..designTris..' triangles are left out')
print(('INFO bake: %d mesh parts, %d triangles baked (%d designed, %d zero-area slivers left out)'):format(totalParts,totalTris,designTris,slivers))
check(#log.Contents==totalParts and log.Editables==totalParts,'one EditableMesh and one content per part ('..#log.Contents..')')
local templates=SS:FindFirstChild('KeeperMeshTemplates152')
check(templates~=nil and #templates:GetChildren()==8,'ServerStorage.KeeperMeshTemplates152 holds 8 keeper templates')
check(RS:FindFirstChild('KeeperMeshTemplates152')==nil,'the templates are not replicated (clients only see the keepers built from them)')
local ci=0;local badNormal,badColour,maxPartTris=0,0,0
for _,stage in ipairs(ORDER)do
 local spec=C152.Stages[stage];local tpl=templates:FindFirstChild(spec.Key);local data=W.module(spec.Module)
 check(tpl~=nil and #tpl:GetChildren()==#spec.Parts,spec.Name..': the template has the config\'s '..#spec.Parts..' parts')
 local decoded=Meshes.Decode(data);local verts=0
 for i,s in ipairs(spec.Parts)do
  ci+=1;local rec=log.Contents[ci];local part=tpl and tpl:GetChildren()[i];local kept=keptTris(decoded.Parts[i])
  verts+=#rec.V;maxPartTris=math.max(maxPartTris,#rec.F)
  check(part and part.Name==s.Name and part.ClassName=='MeshPart','  '..s.Name..': a MeshPart in config order')
  check(#decoded.Parts[i].T//3==s.Triangles and #rec.F==#kept and #rec.V==#decoded.Parts[i].V//3,'  '..s.Name..': '..#rec.F..' of its '..s.Triangles..' triangles (the rest zero-area), '..#rec.V..' vertices baked')
  local same=0;for f=1,#rec.F,11 do local t=kept[f];local dt=decoded.Parts[i].T;if rec.F[f][1]==dt[t*3-2]and rec.F[f][2]==dt[t*3-1]and rec.F[f][3]==dt[t*3]then same+=1 end end
  check(same==math.ceil(#rec.F/11),'  '..s.Name..': the baked triangles are the decoded ones, in order and winding')
  local faceN,faceC=0,0;for f=1,#rec.F do if rec.FN[f]then faceN+=1 end;if rec.FC[f]then faceC+=1 end end
  local coloured=s.Kind=='main'or s.Kind=='face'
  check(faceN==#rec.F and faceC==(coloured and #rec.F or 0),'  '..s.Name..': every face has its normals'..(coloured and' and colours'or', no colours (a Neon part)'))
  for _,n in ipairs(rec.N)do if math.abs(math.sqrt(n[1]^2+n[2]^2+n[3]^2)-1)>1e-6 then badNormal+=1 end end
  check(#rec.N<=#rec.F,'  '..s.Name..': at most one normal per triangle ('..#rec.N..')')
  -- flat faces: each face's normal is its own (winding) normal
  for f=1,#rec.F,37 do
   local t=rec.F[f];local a,b,c=rec.V[t[1]],rec.V[t[2]],rec.V[t[3]];local n=rec.N[rec.FN[f][1]]
   local u={b[1]-a[1],b[2]-a[2],b[3]-a[3]};local w={c[1]-a[1],c[2]-a[2],c[3]-a[3]};local x={u[2]*w[3]-u[3]*w[2],u[3]*w[1]-u[1]*w[3],u[1]*w[2]-u[2]*w[1]}
   local m=math.sqrt(x[1]^2+x[2]^2+x[3]^2);if m>1e-9 and(x[1]*n[1]+x[2]*n[2]+x[3]*n[3])/m<.999 then badNormal+=1 end
  end
  -- colours: the palette colour of the face times the height shade, per corner
  if coloured then
   local P=decoded.Parts[i].P;local Vd=decoded.Parts[i].V
   for f=1,#rec.F,29 do
    for k=1,3 do
     local vi=rec.F[f][k];local col=rec.C[rec.FC[f][k]];local rgb=data.Palette[P[kept[f]]+1]
     local sh=.80+.26*math.clamp((Vd[vi*3-1]-data.Y0)/(data.Y1-data.Y0),0,1)
     if not(near(col[1],math.min(1,rgb[1]*sh),1e-6)and near(col[2],math.min(1,rgb[2]*sh),1e-6)and near(col[3],math.min(1,rgb[3]*sh),1e-6))then badColour+=1 end
    end
   end
  end
  local mc=part and rawget(part,'_meshCentre')or rawget(part and part._source or{},'_meshCentre')
  check(part and near(part.Size.X,s.Size[1],2e-3)and near(part.Size.Y,s.Size[2],2e-3)and near(part.Size.Z,s.Size[3],2e-3),'  '..s.Name..': size '..tostring(part and part.Size)..' = the config\'s')
  local o=part and rawget(part,'_options')
  local hit=s.Kind=='main'and not s.Cosmetic
  check(o and o.CollisionFidelity==R.Enum.CollisionFidelity[hit and'Hull'or'Box']and o.RenderFidelity==R.Enum.RenderFidelity.Precise,'  '..s.Name..': collision '..(hit and'Hull (a hit shape)'or'Box (never hits)')..', render Precise')
  local neon=s.Kind=='eyes'or s.Kind=='glow'
  check(part and part.Material==R.Enum.Material[neon and'Neon'or'SmoothPlastic']and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,'  '..s.Name..': '..(neon and'Neon'or'SmoothPlastic')..', anchored, no collide / touch / query')
  if neon then check(part and near(part.Color.R,s.Color[1])and near(part.Color.G,s.Color[2])and near(part.Color.B,s.Color[3]),'  '..s.Name..': its glow colour')
  else check(part and part.Color.R==1 and part.Color.G==1 and part.Color.B==1,'  '..s.Name..': white, so its vertex colours show')end
 end
 check(verts==data.Vertices,spec.Name..': '..data.Vertices..' vertices in all')
 check(spec.TrianglesOnScreen<10000,spec.Name..': '..spec.TrianglesOnScreen..' triangles on screen (< 10,000, keepers.md section 7)')
end
check(badNormal==0,'every normal is unit length and is its face\'s own normal ('..badNormal..' bad)')
check(badColour==0,'every sampled corner colour = palette colour x height shade ('..badColour..' bad)')
check(maxPartTris<=2124,'the largest single mesh has '..maxPartTris..' triangles (Roblox allows 20,000)')
check(log.Yields>0,'the bake yields between keepers (it runs in slices)')
-- the vertices of every mesh are centred on its bounding box (a MeshPart sits on its mesh's bounding-box centre)
do local off=0;for _,rec in ipairs(log.Contents)do local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9};for _,v in ipairs(rec.V)do for a=1,3 do lo[a]=math.min(lo[a],v[a]);hi[a]=math.max(hi[a],v[a])end end
 for a=1,3 do off=math.max(off,math.abs(lo[a]+hi[a])/2)end end
 check(off<1e-6,'every baked mesh is centred on its bounding box (worst offset '..off..')')end
-- a second Prepare does nothing
do local e=log.Editables;local ok=Meshes.Prepare();check(ok==true and log.Editables==e,'Prepare again: nothing baked twice')end

-- 3. Keepers built from the templates ------------------------------------------------------------------------------------------------------
for stage=1,7 do
 local rig=Meshes.BuildRig(stage);local cfg=C152.Get(stage)
 check(rig and #rig:GetChildren()==#cfg.Parts and rig:GetAttribute('VisualVersion')==152 and rig:GetAttribute('KeeperMeshVariant')=='R152','stage '..stage..': BuildRig makes '..#cfg.Parts..' parts (VisualVersion 152, R152)')
 local bad=0
 for i,p in ipairs(rig:GetChildren())do
  local s=cfg.Parts[i]
  if p.Name~=s.Name or p:GetAttribute('BeastGroup')~=s.Group or not p:GetAttribute('RestCFrame')or(p:GetAttribute('KeeperFaceState')~=s.FaceState)or(p:GetAttribute('KeeperEyeGlow')~=(s.EyeGlow==true))
   or(p:GetAttribute('KeeperCosmetic')==true)~=(s.Cosmetic==true)or(stage==1)~=(p:GetAttribute('TreeRestCFrame')~=nil)or cfg.Pivots[s.Group]==nil then bad+=1 end
  local rest=p:GetAttribute('RestCFrame');if rest and(rest.Position-V3(s.Center[1],s.Center[2],s.Center[3])).Magnitude>1e-3 then bad+=1 end
 end
 check(bad==0,'stage '..stage..': every part has its group (a pivot of today\'s rig), rest, face, eye, cosmetic and tree attributes ('..bad..' bad)')
 rig:Destroy()
end
do local knight=C152.Get(5);local point,glowPoint
 for _,s in ipairs(knight.Parts)do if s.Name=='Sword_Point'then point=s end;if s.Name=='Sword_Glow_Point'then glowPoint=s end end
 check(point and point.Cosmetic and point.Group=='Sword'and glowPoint and glowPoint.Cosmetic,'the Crystal Knight\'s Sword_Point (and its glow) are cosmetic pieces of the Sword group')
 local dragon=C152.Get(4);check(dragon.WingScale==1 and Cfg[4].WingScale==1.35,'the new dragon has no x1.35 wing stretch (today\'s keeps it)')
 local wing;for _,s in ipairs(dragon.Parts)do if s.Name=='LeftWing'then wing=s end end
 check(wing and near(wing.Size[1],15.44,.02),'the dragon\'s wing is exported at in-game size ('..(wing and wing.Size[1]or 0)..' studs wide)')
end

-- 4. Swapping keepers dressed before the bake ----------------------------------------------------------------------------------------------
local y=log.Yields
R.advance(2.1) -- BeastModels' idle check (KeepSeconds)
check(log.Yields==y,'the idle swap never yields')
for stage=1,7 do
 local m=guardians[stage]
 if stage==4 then check(m:GetAttribute('KeeperMeshVariant')=='Legacy'and m.BeastBody:GetAttribute('VisualVersion')==99,'the chasing Lava Dragon keeps its body until the chase ends')
 else check(m:GetAttribute('KeeperMeshVariant')=='R152'and m.BeastBody:GetAttribute('KeeperMeshVariant')=='R152'and #m.BeastBody:GetChildren()==#C152.Stages[stage].Parts,'stage '..stage..': idle keeper swapped to the new model') end
 check(m:FindFirstChild('HumanoidRootPart')~=nil and m:GetAttribute('GardenerArtVersion')==99 and m:GetAttribute('KeeperClientAnimated')==true and CS:HasTag(m,'BiomeKeeper'),'stage '..stage..': root, attributes and tag kept')
end
guardians[4]:SetAttribute('GuardianBehavior','RETURNING');guardians[4]:SetAttribute('GuardianLeaseToken',0);R.advance(2.1)
check(guardians[4]:GetAttribute('KeeperMeshVariant')=='Legacy','RETURNING is not idle yet: still today\'s dragon')
guardians[4]:SetAttribute('GuardianBehavior','GUARDING');R.advance(2.1)
check(guardians[4]:GetAttribute('KeeperMeshVariant')=='R152','back to guarding: the dragon is swapped')
-- a keeper dressed after the bake gets the new model straight away, and a second Dress keeps it
do local m=keeperModel(3,CF(0,6,500));Models.Dress(m,3);local body=m.BeastBody
 check(m:GetAttribute('KeeperMeshVariant')=='R152'and body:GetAttribute('VisualVersion')==152,'a keeper dressed after the bake is built from the template')
 Models.Dress(m,3);check(m.BeastBody==body,'Dress again keeps the same new body')
 local cf0=body:GetChildren()[1].CFrame;local rest=body:GetChildren()[1]:GetAttribute('RestCFrame')
 check((cf0.Position-(m.HumanoidRootPart.CFrame*rest).Position).Magnitude<1e-6,'parts are placed at root * rest')
 m:Destroy()end

-- 5. Contact: face parts and the knight's Sword_Point never hit ------------------------------------------------------------------------------
for stage=1,7 do
 local names={};for _,p in ipairs(Contact.Parts(guardians[stage]))do names[p.Name]=true end
 local bad=0;local want=0
 for _,s in ipairs(C152.Stages[stage].Parts)do
  local should=not s.FaceState and not s.Cosmetic
  if should then want+=1 end
  if(names[s.Name]==true)~=should then bad+=1 end
 end
 check(bad==0,'stage '..stage..': KeeperContact uses the '..want..' non-face, non-cosmetic parts only')
end
do local names={};for _,p in ipairs(Contact.Parts(guardians[5]))do names[p.Name]=true end
 check(names.Sword and not names.Sword_Point and not names.Sword_Glow_Point and not names.Head_Eyes_Chase and not names.Head_Eyes_Asleep,'the knight: Sword hits, Sword_Point / its glow / both eye sets do not')end
-- the contact list follows a swap (KeeperModels: off -> today's parts)
do local before=#Contact.Parts(guardians[6]);local Cmd=W.module('KeeperMeshCommand152')
 local ok,text=Cmd.Execute({},nil,{})
 check(ok and text:find('all 8 baked',1,true)~=nil and text:find('Jungle King: Ready',1,true)~=nil,'/test keepermodels reports the bake:\n'..tostring(text))
 ok,text=Cmd.Execute({},nil,{'off'})
 check(ok and text:find('OFF',1,true)~=nil and guardians[6]:GetAttribute('KeeperMeshVariant')=='Legacy','keepermodels off: idle keepers go back to today\'s model at once')
 local legacy=0;for _,p in ipairs(guardians[6].BeastBody:GetChildren())do if p.Size.Magnitude>.15 then legacy+=1 end end
 check(#Contact.Parts(guardians[6])==legacy and legacy~=before and Contact.Parts(guardians[6])[1].Parent==guardians[6].BeastBody,'the contact parts follow the swap (now today\'s '..legacy..' parts, were '..before..')')
 local okBad=Cmd.Execute({},nil,{'sideways'});check(okBad==false,'keepermodels rejects an unknown word')
 ok,text=Cmd.Execute({},nil,{'auto'})
 check(ok and guardians[6]:GetAttribute('KeeperMeshVariant')=='R152','keepermodels auto: back to the new models')
end

-- 6. Server hit frames: the new variant only changes the grounding (its own floor samples); the strike moves and timeline are the same --------
-- The idle pose under the strike is today's pose lifted as one; the strike layers (KeeperAttackPose) then turn the limbs about the same rig
-- points, so a different lift shifts the struck limbs a little (stage 7: its new feet stand 0.8 studs higher than today's hull says).
do local Strike=W.module('KeeperStrikeFrames');local Combat=W.module('KeeperCombat');local Pose=W.module('BeastPose')
 for stage=1,7 do
  local worst,lift,strikeWorst=0,nil,0
  for _,t in ipairs({0,.6,1.9})do
   local a,b=Pose.Frames(stage,t,1,0,0,0,0,0),Pose.Frames(stage,t,1,0,0,0,0,0,'R152');local ref=a.Body and'Body'or'Segment1';local dy=(b[ref].Position-a[ref].Position).Y
   lift=lift or dy
   for g,f in pairs(a)do
    local d=b[g].Position-f.Position
    worst=math.max(worst,math.abs(d.X),math.abs(d.Z),math.abs(d.Y-dy))
    for i=1,3 do for j=1,3 do worst=math.max(worst,math.abs(f.R[i][j]-b[g].R[i][j]))end end
   end
  end
  local w=Combat.Get(stage).Windup
  for e=0,w+Combat.Recovery,.05 do
   local a,b=Strike.Frames(stage,10+e,10),Strike.Frames(stage,10+e,10,nil,'R152')
   for g,f in pairs(a)do local d=b[g].Position-f.Position;strikeWorst=math.max(strikeWorst,math.abs(d.X),math.abs(d.Z),math.abs(d.Y-lift))end
  end
  -- the knight's arms solve to fixed grip targets (CrystalKnightPose): a different lift bends them a hair; every other keeper moves as one
  check(worst<=(stage==5 and .05 or 1e-6),('stage %d: the idle pose with the new model = today\'s lifted %.3f studs as one (worst %.2g)'):format(stage,lift,worst))
  check(strikeWorst<=math.max(.05,math.abs(lift)*.2),('stage %d: the server\'s strike frames differ only by that lift, give or take %.3f studs at the limbs'):format(stage,strikeWorst))
  print(('INFO stage %d: new floor samples lift the keeper %+.3f studs vs today\'s hull; strike limbs within %.3f studs'):format(stage,lift,strikeWorst))
 end
end

-- 7. Grounding: the new meshes stand on the floor (y = -4) in the game's own poses -------------------------------------------------------------
do local Pose=W.module('BeastPose');local worst=0;local who=''
 for stage=1,7 do
  local spec=C152.Stages[stage];local decoded=Meshes.Decode(W.module(spec.Module));local floorGroups=spec.FloorSamples
  for _,args in ipairs({{1,1,0,0,0,0,0},{1,0,0,0,0,0,0},{2,1,1,1.3,1,60,0},{2,1,1,4.4,1,60,0},{3.3,.5,.5,2,0,20,1},{5,1,1,.4,1,40,-1}})do
   local frames=Pose.Frames(stage,args[1],args[2],args[3],args[4],args[5],args[6],args[7],'R152');local low=math.huge
   for i,s in ipairs(spec.Parts)do
    if s.Kind=='main'and not s.Cosmetic and floorGroups[s.Group]then
     local f=frames[s.Group];local V=decoded.Parts[i].V
     for j=1,#V//3 do if V[j*3-1]>=-4.1 then local p=f*V3(V[j*3-2],V[j*3-1],V[j*3]);if p.Y<low then low=p.Y end end end
    end
   end
   if math.abs(low+4)>worst then worst=math.abs(low+4);who=spec.Name end
  end
 end
 check(worst<.05,'the new keepers stand on the floor in the game\'s poses (worst gap '..string.format('%.3f',worst)..' studs, '..who..')')
 print(('INFO grounding: the new meshes touch the floor within %.3f studs in the sampled poses (%s)'):format(worst,who))
end

-- 8. The client: two faces, the golem's tree, accents, the sleep Z (real BeastAnimation) ------------------------------------------------------------
local S={awake=0,moving=0,cycle=0,urgency=0,speed=0,t=0}
W.stub('KeeperAudio',{Voice=function()return nil,0,1 end});W.stub('SoundTiming',{Play=function()end})
W.stub('KeeperVoices',setmetatable({},{__index=function()return {Gap=6}end}))
W.stub('KeeperMotion',{new=function()return {}end,Update=function(_,frame)return {Frame=frame,Awake=S.awake,Time=S.t,Moving=S.moving,Cycle=S.cycle,Urgency=S.urgency,Speed=S.speed,Turn=0}end})
W.stub('KeeperRecoveryDash',{VisualFrame=function(_,_,f)return f end})
local surgeVariant
W.stub('KeeperSurge',{New=function(_,variant)surgeVariant=variant;return {}end,Step=function()end,Destroy=function()end})
W.stub('CosmeticBudget',{KeeperDue=function()return true end});W.stub('ClientFxBudget',{Low=function()return false end})
local fxConfigs={}
W.stub('KeeperFx',{new=function(_,stage,config)fxConfigs[stage]=config;return {}end,Step=function()end,Slam=function()end,Wake=function()end,Destroy=function()end})
local camera=W.workspace.CurrentCamera;camera.WorldToViewportPoint=function()return V3(0,0,0),true end;camera.CFrame=CF(0,20,-40)
local moved={};function W.workspace.BulkMoveTo(_,parts,frames)for i,p in ipairs(parts)do p.CFrame=frames[i];moved[p]=true end end
local sc=R.new('LocalScript');sc.Name='BeastAnimation'
local fn=assert(loadstring(W.B.BeastAnimation,'=BeastAnimation'));setfenv(fn,setmetatable({script=sc},{__index=W.env}))
fn();R.advance(0);W.frames(2,1/60)
local function faceState(stage)
 local shown,hidden,bad={},{},0
 for _,p in ipairs(guardians[stage].BeastBody:GetChildren())do
  local f=p:GetAttribute('KeeperFaceState');if f then if p.LocalTransparencyModifier==1 then hidden[f]=(hidden[f]or 0)+1 else shown[f]=(shown[f]or 0)+1 end end
 end
 return shown,hidden
end
for stage=1,7 do
 local body=guardians[stage].BeastBody;local n=0;for _,p in ipairs(body:GetChildren())do if moved[p]then n+=1 end end
 check(n==#body:GetChildren(),'stage '..stage..': BeastAnimation binds the new rig and moves all '..#body:GetChildren()..' parts ('..n..')')
 local shown,hidden=faceState(stage)
 check((shown.Chase or 0)==0 and(hidden.Asleep or 0)==0 and(shown.Asleep or 0)>=1 and(hidden.Chase or 0)>=1,'stage '..stage..': asleep (GUARDING): the Asleep face shows, the Chase face is hidden')
 check(fxConfigs[stage]and fxConfigs[stage].Parts==C152.Stages[stage].Parts,'stage '..stage..': KeeperFx gets the new model\'s config')
end
check(surgeVariant=='R152','the colossus\'s lightning uses the new model\'s paths')
for stage=1,7 do guardians[stage]:SetAttribute('GuardianBehavior','CHASING')end;S.awake=1;S.moving=1;W.frames(2,1/60)
for stage=1,7 do local shown,hidden=faceState(stage)
 check((shown.Asleep or 0)==0 and(hidden.Chase or 0)==0 and(shown.Chase or 0)>=1,'stage '..stage..': awake (CHASING): the Chase face shows, the Asleep face is hidden')end
for stage=1,7 do guardians[stage]:SetAttribute('GuardianBehavior','SLEEPING')end;S.awake=0;S.moving=0;W.frames(2,1/60)
for stage=1,7 do local shown=faceState(stage);check((shown.Chase or 0)==0,'stage '..stage..': back asleep: the Chase face hides again')end
for stage=1,7 do guardians[stage]:SetAttribute('GuardianBehavior','ALERTED')end;S.awake=.5;W.frames(2,1/60)
for stage=1,7 do local shown=faceState(stage);check((shown.Asleep or 0)==0,'stage '..stage..': ALERTED counts as awake: Chase face')end
-- the golem's tree: asleep it is today's tree (every piece at its TreeRest, tree size); its glow and awake eyes are hidden
for stage=1,7 do guardians[stage]:SetAttribute('GuardianBehavior','GUARDING')end;S.awake=0;S.moving=0;W.frames(2,1/60)
do local body=guardians[1].BeastBody;local root=guardians[1].HumanoidRootPart;local bad,hiddenGlow=0,0
 for _,p in ipairs(body:GetChildren())do
  local tree=p:GetAttribute('TreeRestCFrame');local size=p:GetAttribute('TreeRestSize')
  if not tree or(p.CFrame.Position-(root.CFrame*tree).Position).Magnitude>1e-4 or(p.Size-size).Magnitude>1e-4 then bad+=1 end
  if p:GetAttribute('KeeperMeshKind')=='glow'or p.Name=='Head_Eyes_Chase'then if p.LocalTransparencyModifier==1 then hiddenGlow+=1 end end
 end
 check(bad==0,'the sleeping golem: every piece at its tree pose and tree size ('..bad..' off)')
 check(hiddenGlow==2,'the sleeping golem hides its rune glow and its glowing slits ('..hiddenGlow..')')
 check(body.Head_Face_Asleep.LocalTransparencyModifier==0,'the sleeping golem shows its asleep face (dim slits) inside the tree')
 -- the tree is today's tree: the pieces' tree poses fill today's tree bounding box (KeeperUpgradeData TreeRest / TreeSize)
 local Up=W.module('KeeperUpgradeData')[1];local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 for _,s in ipairs(Up.Parts)do local c=CF(table.unpack(s.TreeRest));local h=V3(s.TreeSize[1],s.TreeSize[2],s.TreeSize[3])*.5
  for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do for _,sz in ipairs({-1,1})do local q=c*V3(h.X*sx,h.Y*sy,h.Z*sz);lo[1]=math.min(lo[1],q.X);lo[2]=math.min(lo[2],q.Y);lo[3]=math.min(lo[3],q.Z);hi[1]=math.max(hi[1],q.X);hi[2]=math.max(hi[2],q.Y);hi[3]=math.max(hi[3],q.Z)end end end end
 local nlo,nhi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 for _,p in ipairs(body:GetChildren())do local c=root.CFrame:Inverse()*p.CFrame;local h=p.Size*.5
  for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do for _,sz in ipairs({-1,1})do local q=c*V3(h.X*sx,h.Y*sy,h.Z*sz);nlo[1]=math.min(nlo[1],q.X);nlo[2]=math.min(nlo[2],q.Y);nlo[3]=math.min(nlo[3],q.Z);nhi[1]=math.max(nhi[1],q.X);nhi[2]=math.max(nhi[2],q.Y);nhi[3]=math.max(nhi[3],q.Z)end end end end
 local d=0;for a=1,3 do d=math.max(d,math.abs(lo[a]-nlo[a]),math.abs(hi[a]-nhi[a]))end
 check(d<3.5,'the golem\'s tree has today\'s tree size and place (largest box difference '..string.format('%.2f',d)..' studs: the bird\'s nest, moss)')
end
S.awake=1;guardians[1]:SetAttribute('GuardianBehavior','CHASING');W.frames(2,1/60)
do local body=guardians[1].BeastBody;local bad=0
 for _,p in ipairs(body:GetChildren())do local rest=p:GetAttribute('RestCFrame');local s;for _,q in ipairs(C152.Stages[1].Parts)do if q.Name==p.Name then s=q end end
  if (p.Size-V3(s.Size[1],s.Size[2],s.Size[3])).Magnitude>2e-3 then bad+=1 end end
 check(bad==0 and body.Body_Glow.LocalTransparencyModifier==0 and body.Head_Eyes_Chase.LocalTransparencyModifier==0,'the awake golem: full size, rune and slits lit')
end
do local eyes=guardians[5].BeastBody.Head_Eyes_Asleep
 guardians[5]:SetAttribute('GuardianBehavior','CHASING');S.awake=1;W.frames(2,1/60)
 check(eyes.Material==R.Enum.Material.Neon and near(eyes.Color.R,.4)and eyes.LocalTransparencyModifier==1,'the knight awake: its dim asleep eyes are hidden')
 guardians[5]:SetAttribute('GuardianBehavior','GUARDING');S.awake=0;W.frames(2,1/60)
 check(eyes.LocalTransparencyModifier==0 and eyes.Material==R.Enum.Material.Neon and near(eyes.Color.R,.4),'the knight asleep: its asleep eyes glow dimly (Neon, their own colour)')
end
-- the runes, seams and storm cracks pulse gently on the client (70 - 100 % of their Neon colour)
do local g=guardians[7].BeastBody.Body_Glow;local base
 for _,s in ipairs(C152.Stages[7].Parts)do if s.Name=='Body_Glow'then base=s.Color end end
 local seen={}
 for _=1,6 do W.frames(9,1/60);seen[#seen+1]=g.Color.B end
 local lo,hi=math.min(table.unpack(seen)),math.max(table.unpack(seen))
 check(hi-lo>.01 and hi<=base[3]+1e-6 and lo>=base[3]*.7-1e-6 and g.Material==R.Enum.Material.Neon,('the colossus\'s storm cracks pulse (blue %.3f .. %.3f of %.3f)'):format(lo,hi,base[3]))
end
-- accents: only the snake's rattle stays
for stage=1,7 do
 local f=guardians[stage]:FindFirstChild('KeeperAccentsLocal')
 if stage==2 then check(f~=nil and #f:GetChildren()==3,'the Sand Snake keeps its 3 rattle accents')
 else check(f==nil,'stage '..stage..': no client accents (the rune / mushrooms, spines / armour, shards and cloud are in the mesh)')end
end
-- the sleep marker: the new big Z (not on the golem, which sleeps as a tree)
for stage=1,7 do
 local att=guardians[stage].HumanoidRootPart:FindFirstChild('KeeperSleepLocal');local gui=att and att:FindFirstChild('KeeperZzzLocal')
 if stage==1 then check(gui==nil,'the golem has no sleep Z')
 else
  local z=gui and gui:FindFirstChild('Z1');local small=gui and gui:FindFirstChild('Z2')
  check(z and z.Text=='Z'and small and small.Text=='z'and z.TextColor3.B>.95 and z.TextColor3.R<.4 and z:FindFirstChildOfClass('UIStroke')~=nil,'stage '..stage..': the new sleep marker (a big cyan Z with a dark outline and a small z)')
 end
end

-- 9. The Darkened ------------------------------------------------------------------------------------------------------------------------------
do local Veiled=W.module('VeiledKeeper81');local spec=C152.Stages[0]
 local parts=Meshes.DarkenedParts();check(parts and #parts==#spec.Parts,'The Darkened: '..#spec.Parts..' baked parts')
 local d=Veiled.Build(CF(10,5,10),W.workspace,parts)
 local meshParts={};for _,p in ipairs(d:GetChildren())do if p:GetAttribute('VeiledGroup')then meshParts[#meshParts+1]=p end end
 check(d:GetAttribute('KeeperMeshVariant')=='R152'and #meshParts==#spec.Parts and d.PrimaryPart.Name=='VeiledRoot','The Darkened is built from its template (same root, '..#meshParts..' parts)')
 local frames=Veiled.Frames(d,R.clock);local bad=0
 for _,p in ipairs(meshParts)do if(p.CFrame.Position-(frames[p:GetAttribute('VeiledGroup')]*p:GetAttribute('VeiledFrame')).Position).Magnitude>1e-4 then bad+=1 end end
 check(bad==0,'every part sits at its group frame * VeiledFrame (today\'s joint chain)')
 local names={};for _,p in ipairs(Contact.Parts(d))do names[p.Name]=true end
 local wrong=0;for _,s in ipairs(spec.Parts)do if(names[s.Name]==true)==(s.Cosmetic==true)then wrong+=1 end end
 check(wrong==0 and not names.Head_Eyes_Chase and not names.Torso_Cloak and names.Torso,'The Darkened: cloak, claws, cores, glow and faces never hit; the body parts do')
 local legacyGroups={};for _,p in ipairs(Veiled.Build(CF(0,5,0),W.workspace):GetChildren())do local g=p:GetAttribute('VeiledGroup');if g then legacyGroups[g]=true end end
 local newGroups={};for _,s in ipairs(spec.Parts)do newGroups[s.Group]=true end
 local same=true;for g in pairs(legacyGroups)do if not newGroups[g]then same=false end end;for g in pairs(newGroups)do if not legacyGroups[g]then same=false end end
 check(same,'The Darkened uses today\'s 17 groups (joint chain unchanged)')
end

-- 10. Gameplay values untouched ------------------------------------------------------------------------------------------------------------------
do local Combat=W.module('KeeperCombat');local base={[1]=.30,[2]=.22,[3]=.24,[4]=.32,[5]=.32,[6]=.28,[7]=.34}
 local same=true;for s,w in pairs(base)do if Combat.Get(s).Windup~=w then same=false end end
 check(same and Combat.Recovery==.30 and Combat.HitHold==.07,'strike timing (KeeperCombat) unchanged')
 for stage=1,7 do local a,b=C152.Get(stage),Cfg[stage];check(a.Motion==b.Motion and a.Pivots==b.Pivots and a.Scale==b.Scale and a.Name==b.Name,'stage '..stage..': same pivots, motion (stride / speed) and scale as today')end
end
check(log.Alive()==0,'no EditableMesh alive at the end')
print(('R152 keepers (%s): %d checks, %d failures'):format(SCENARIO,checks,fails))
if fails>0 then error('failures',0)end
