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
-- (the mock's CFrame has no object-space helpers; KeeperFx152 places its attachments with them)
do local mt=getmetatable(CF(0,0,0))
 rawset(mt,'PointToObjectSpace',function(c,v)return c:Inverse()*v end)
 rawset(mt,'VectorToObjectSpace',function(c,v)local i=c:Inverse();return i*v-i.Position end)
end
-- (nor a Sound:Stop; KeeperSleep stops its sound when BeastAnimation drops a keeper, as on a body swap)
if not rawget(R.Inst,'Stop')then rawset(R.Inst,'Stop',function(self)self.Playing=false end)end
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
local S={awake=0,moving=0,cycle=0,urgency=0,speed=0,t=0,tier=3}
W.stub('KeeperAudio',{Voice=function()return nil,0,1 end});W.stub('SoundTiming',{Play=function()end})
W.stub('KeeperVoices',setmetatable({},{__index=function()return {Gap=6}end}))
W.stub('KeeperMotion',{new=function()return {}end,Update=function(_,frame)return {Frame=frame,Awake=S.awake,Time=S.t,Moving=S.moving,Cycle=S.cycle,Urgency=S.urgency,Speed=S.speed,Turn=0}end})
W.stub('KeeperRecoveryDash',{VisualFrame=function(_,_,f)return f end})
local surgeVariant
W.stub('KeeperSurge',{New=function(_,variant)surgeVariant=variant;return {}end,Step=function()end,Destroy=function()end})
W.stub('CosmeticBudget',{KeeperDue=function()return true end});W.stub('ClientFxBudget',{Low=function()return S.tier==1 end,Get=function()return S.tier end})
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

-- 8b. The new models' effects (the real KeeperFx152): on the right mesh parts, none on today's keepers, rates by tier and state, cleaned up --
local Fx152=W.module('KeeperFx152');local PARTICLES='rbxasset://textures/particles/'
local function fxList(container)
 local out={}
 for _,d in ipairs(container:GetDescendants())do local kind=d:GetAttribute('KeeperFxKind')
  if kind then local host=d.Parent;if host and host:IsA('Attachment')then host=host.Parent end;out[#out+1]={Inst=d,Kind=kind,Part=host and host.Name or'?',Host=host}end end
 return out
end
-- every instance KeeperFx152 makes: its attachments (KeeperFx152 / KeeperBolt152 / KeeperSlash152) and its emitters, beams, trails
local function fxMade(container)local n=0;for _,d in ipairs(container:GetDescendants())do if d.Name:find('152',1,true)and(d:IsA('Attachment')or d:GetAttribute('KeeperFxKind'))then n+=1 end end;return n end
local function fxKeys(container)local n={};for _,f in ipairs(fxList(container))do local k=f.Kind..'@'..f.Part;n[k]=(n[k]or 0)+1 end;return n end
local function wantKeys(stage)
 local cfg=stage==0 and C152.Stages[0]or C152.Get(stage);local n={}
 for _,s in ipairs(cfg.Fx or{})do local k=s.Kind..'@'..s.Part;n[k]=(n[k]or 0)+(s.Kind=='Bolt'and Fx152.Bolt.Kinks+1 or 1)end
 for _,x in ipairs(Fx152.Extra[stage]or{})do local k=(x.Trail or x.Look)..'@'..x.Part;n[k]=(n[k]or 0)+1 end
 return n
end
local function keyText(t)local o={};for k,v in pairs(t)do o[#o+1]=k..' x'..v end;table.sort(o);return table.concat(o,', ')end
local function sameKeys(a,b)return keyText(a)==keyText(b)end
-- one keeper's effects now: the total rate, the highest, emitters on, beams lit, trails on, the rates by kind
local function rates(container)
 local out={Total=0,On=0,Beams=0,Trails=0,Kinds={},Max=0}
 for _,f in ipairs(fxList(container))do local d=f.Inst
  if d:IsA('ParticleEmitter')then out.Total+=d.Rate;out.Max=math.max(out.Max,d.Rate);if d.Enabled then out.On+=1 end
   local k=out.Kinds[f.Kind]or{};out.Kinds[f.Kind]=k;k[#k+1]=d.Enabled and d.Rate or 0
  elseif d:IsA('Beam')then if d.Enabled then out.Beams+=1 end
  elseif d:IsA('Trail')then if d.Enabled then out.Trails+=1 end end
 end
 return out
end
local function lookAt(stage)camera.CFrame=CF(stage*60,20,-40)end
local function allSum(list)local t=0;for _,v in ipairs(list or{})do t+=v end;return t end
-- where they are: the sheets' anchors (KeeperRigConfig152 Fx) and the notes' extras, each on its mesh part, built-in textures only
local made0={}
for stage=1,7 do
 local body=guardians[stage].BeastBody;local got,want=fxKeys(body),wantKeys(stage);made0[stage]=fxMade(body)
 check(next(want)~=nil and sameKeys(got,want),'stage '..stage..': the effects on the new model: '..keyText(got)..(sameKeys(got,want)and''or' (want '..keyText(want)..')'))
 local bad,tex=0,0
 for _,f in ipairs(fxList(body))do
  if not(f.Host and f.Host:IsA('BasePart')and f.Host.Parent==body and f.Host:GetAttribute('BeastGroup')and moved[f.Host])then bad+=1 end
  if f.Inst:IsA('ParticleEmitter')and(type(f.Inst.Texture)~='string'or f.Inst.Texture:sub(1,#PARTICLES)~=PARTICLES or f.Inst.LockedToPart~=false)then tex+=1 end
  if(f.Inst:IsA('Beam')or f.Inst:IsA('Trail'))and(f.Inst.Texture or'')~=''then tex+=1 end
 end
 check(bad==0,'stage '..stage..': every effect sits in a mesh part of its rig (a BeastGroup part BeastAnimation poses), so it moves with that group ('..bad..' not)')
 check(tex==0,'stage '..stage..': built-in particle textures only (rbxasset://textures/particles/), plain beams and trails ('..tex..' not)')
 -- each emitter's attachment: at its sheet anchor (rig rest space) when it has one, and inside its part's box (1.5 studs: a flame on a spike tip)
 local off=0;local cfg=C152.Get(stage)
 for _,f in ipairs(fxList(body))do local att=f.Inst.Parent
  if f.Inst:IsA('ParticleEmitter')and att:IsA('Attachment')then
   local p=f.Host:GetAttribute('RestCFrame')*att.CFrame.Position;local best,anchored=1e9,false
   for _,s in ipairs(cfg.Fx or{})do if s.Kind==f.Kind and s.Part==f.Part then anchored=true;best=math.min(best,(p-V3(s.At[1],s.At[2],s.At[3])).Magnitude)end end
   local spec;for _,q in ipairs(cfg.Parts)do if q.Name==f.Part then spec=q end end
   local outside=0;local xyz={p.X,p.Y,p.Z};for a=1,3 do outside=math.max(outside,math.abs(xyz[a]-spec.Center[a])-spec.Size[a]/2)end
   if(anchored and best>1e-3)or outside>1.5 then off+=1 end
  end
 end
 check(off==0,'stage '..stage..': every emitter attachment at its anchor, inside its part ('..off..' off)')
end
do local d=fxKeys(guardians[4].BeastBody);check((d['Flame@Body']or 0)>=5 and d['Flame@Tail']==1 and d['Smoke@Head']==2,'the Lava Dragon: flames along its back spikes (Body), on its tail tip, smoke at both nostrils (Head)')end
do local c=fxKeys(guardians[7].BeastBody);local cfg=C152.Get(7);local head,cloud;for _,q in ipairs(cfg.Parts)do if q.Name=='Head'then head=q end;if q.Name=='Head_Cloud'then cloud=q end end
 local under=0;for _,s in ipairs(cfg.Fx)do if s.Part=='Head'and s.Kind=='Bolt'and math.min(s.At[2],s.To[2])>head.Center[2]and math.max(s.At[2],s.To[2])<cloud.Center[2]then under+=1 end end
 check(c['Bolt@Head']==3*(Fx152.Bolt.Kinks+1)and under==3,'the Storm Colossus: 3 lightning bolts between its head and its cloud crown ('..under..'), on the Head group')
 check((c['Bolt@LeftArm_Rock']or 0)>0 and(c['Bolt@RightArm_Fist']or 0)>0 and c['Rain@Head_Cloud']==1,'the Storm Colossus: bolts on its shoulder rocks and fists, rain from the cloud')
end
do local g=fxKeys(guardians[1].BeastBody);check(g['Leaves@Head_Canopy']==1 and g['Spores@Body']==1,'the golem: falling leaves from its canopy, drifting spores')end
do local k=fxKeys(guardians[5].BeastBody);check(k['Slash@Sword']==1,'the Crystal Knight: a slash trail on its sword')end
-- KeeperFx152.new makes nothing on a model that is not an R152 model (today's rig of each stage, a bare model)
do local none=0
 for stage=1,7 do local legacy=Models.Build(stage)
  if legacy and legacy:GetAttribute('KeeperMeshVariant')~='R152'and Fx152.new(legacy,stage)==nil and fxMade(legacy)==0 and Fx152.new(W.new('Model'),stage)==nil then none+=1 end
  if legacy then legacy:Destroy()end
 end
 check(none==7,'KeeperFx152.new makes nothing on today\'s rigs ('..none..' of 7 clean)')
end
-- rates by graphics tier (ClientFxBudget.Get) and state, one keeper at a time with the camera beside it
local cap,capK=Fx152.MaxRate,Fx152.MaxKeeperRate
local seen={}
for stage=1,7 do
 local m=guardians[stage];local body=m.BeastBody;lookAt(stage);seen[stage]={}
 for _,state in ipairs({'GUARDING','CHASING'})do m:SetAttribute('GuardianBehavior',state);S.awake=state=='CHASING'and 1 or 0
  for tier=1,3 do S.tier=tier;W.frames(2,1/60);local r=rates(body);seen[stage][state..tier]=r
   local t=Fx152.TierScale[tier]
   if tier==1 then check(r.Total==0 and r.On==0 and r.Trails==0,'stage '..stage..' '..state..', tier 1 (low graphics): no particles ('..r.Total..'/s, '..r.On..' on)')
   else check(r.Max<=cap*t+1e-9 and r.Total<=capK*t+1e-9,('stage %d %s, tier %d: each emitter <= %g/s (max %.2f), the keeper <= %g/s (%.2f)'):format(stage,state,tier,cap*t,r.Max,capK*t,r.Total))end
  end
 end
 local a2,a3=seen[stage].CHASING2,seen[stage].CHASING3
 if stage==5 then check(a3.Total==0 and a2.Total==0,'the Crystal Knight has no particles (its slash trail only)')
 else check(a3.Total>0 and math.abs(a2.Total*2-a3.Total)<=.02*#fxList(body),('stage %d: tier 2 runs half the particles of tier 3 (%.2f vs %.2f /s)'):format(stage,a2.Total,a3.Total))end
 check(seen[stage].GUARDING3.Total<=a3.Total+1e-9,('stage %d: asleep is never busier than awake (%.2f vs %.2f /s)'):format(stage,seen[stage].GUARDING3.Total,a3.Total))
 print(('INFO effects stage %d: %s; particles/s tier 3 awake %.1f, asleep %.1f, tier 2 awake %.1f'):format(stage,keyText(fxKeys(body)),a3.Total,seen[stage].GUARDING3.Total,a2.Total))
end
do local s,a=seen[4].GUARDING3,seen[4].CHASING3
 check(allSum(s.Kinds.Smoke)>0 and allSum(a.Kinds.Smoke)==0,'the Lava Dragon snorts smoke only in its sleep')
 check(allSum(s.Kinds.Flame)>0 and allSum(s.Kinds.Flame)<allSum(a.Kinds.Flame)*.5,('its back flames burn low asleep (%.2f vs %.2f /s), full awake'):format(allSum(s.Kinds.Flame),allSum(a.Kinds.Flame)))
end
do local s,a=seen[2].GUARDING3,seen[2].CHASING3
 check(allSum(s.Kinds.Swirl)==0 and allSum(s.Kinds.DustTrail)==0 and allSum(a.Kinds.Swirl)>0 and allSum(a.Kinds.DustTrail)>0,'the Sand Snake: sand swirl and dust trail only while awake and chasing')end
do local s,a=seen[1].GUARDING3,seen[1].CHASING3;check(allSum(s.Kinds.Leaves)>0 and allSum(a.Kinds.Leaves)>0,'the golem\'s leaves keep falling asleep (it sleeps as a tree) and awake')end
do local s,a=seen[7].GUARDING3,seen[7].CHASING3;check(allSum(s.Kinds.Rain)>0 and allSum(s.Kinds.Rain)<allSum(a.Kinds.Rain),'the colossus\'s rain falls lighter while it sleeps')end
-- the colossus's lightning flashes (on briefly, then off), less often asleep, never at tier 1 or out of range
do local m=guardians[7];local body=m.BeastBody;lookAt(7);local beams=0;for _,f in ipairs(fxList(body))do if f.Inst:IsA('Beam')then beams+=1 end end
 local function lit(n)local f=0;for _=1,n do W.frames(1,1/60);f+=rates(body).Beams end;return f/(n*beams)end
 S.tier=3;m:SetAttribute('GuardianBehavior','CHASING');local awake=lit(600)
 m:SetAttribute('GuardianBehavior','GUARDING');local asleep=lit(600)
 S.tier=1;local low=lit(120);S.tier=3;camera.CFrame=CF(7*60,20,-40-Fx152.Range-20);local far=lit(120);lookAt(7)
 check(awake>.02 and awake<.2,('the colossus\'s bolts flash briefly while awake (each lit %.1f %% of the time)'):format(awake*100))
 check(asleep>0 and asleep<.2,('and still flash in its sleep (%.1f %%)'):format(asleep*100))
 check(low==0 and far==0,'no lightning at tier 1 or beyond '..Fx152.Range..' studs')
end
-- the gap to the next flash: Every (0.9 - 2.6 s) awake, twice that asleep, twice again at tier 2 (KeeperFx152 alone, its bolts read back)
do local own=Fx152.new(guardians[7].BeastBody,7);local lo,hi={},{};local now0=R.clock+100
 for _,k in ipairs({{false,3},{true,3},{false,2}})do local key=tostring(k[1])..k[2];lo[key],hi[key]=1e9,-1e9
  local c={Asleep=k[1],Chasing=not k[1],Tier=k[2],Distance=10}
  for _=1,30 do now0+=20;c.Now=now0;Fx152.Step(own,c)
   for _,b in ipairs(own.Bolts)do local gap=b.NextAt-c.Now;lo[key]=math.min(lo[key],gap);hi[key]=math.max(hi[key],gap)end end
 end
 local E=Fx152.Bolt.Every
 check(#own.Bolts==9 and lo.false3>=E[1]-1e-9 and hi.false3<=E[2]+1e-9 and lo.true3>=2*E[1]-1e-9 and hi.true3<=2*E[2]+1e-9 and lo.false2>=2*E[1]-1e-9 and hi.false2<=2*E[2]+1e-9,
  ('the bolts\' next flash: awake %.2f - %.2f s, asleep %.2f - %.2f s, tier 2 %.2f - %.2f s'):format(lo.false3,hi.false3,lo.true3,hi.true3,lo.false2,hi.false2))
 Fx152.Destroy(own)
end
-- out of range: a keeper far from the camera runs nothing
do lookAt(1);S.tier=3;W.frames(2,1/60);local r=rates(guardians[7].BeastBody)
 check(r.Total==0 and r.On==0,'a keeper '..math.floor((guardians[7].HumanoidRootPart.Position-camera.CFrame.Position).Magnitude)..' studs away runs no particles')end
-- the knight's slash trail: only while it strikes
do local m=guardians[5];lookAt(5);m:SetAttribute('GuardianBehavior','CHASING');S.tier=3;W.frames(2,1/60)
 local before=rates(m.BeastBody).Trails
 m:SetAttribute('KeeperAttackAt',W.workspace:GetServerTimeNow());W.frames(3,1/60);local during=rates(m.BeastBody).Trails
 W.frames(90,1/60);local after=rates(m.BeastBody).Trails;m:SetAttribute('KeeperAttackAt',nil)
 check(before==0 and during==1 and after==0,'the Crystal Knight\'s slash trail shows only during its strike ('..before..', '..during..', '..after..')')
end
for stage=1,7 do guardians[stage]:SetAttribute('GuardianBehavior','GUARDING')end;S.awake=0;S.tier=3;camera.CFrame=CF(0,20,-40);W.frames(2,1/60)
-- KeeperFx152.Destroy removes exactly what it made (a second set on the dragon, then destroyed)
do local body=guardians[4].BeastBody;local n0=fxMade(body);local extra=Fx152.new(body,4)
 local n1=fxMade(body);Fx152.Destroy(extra);Fx152.Destroy(extra)
 check(n0>0 and n1==2*n0 and fxMade(body)==n0,'KeeperFx152.Destroy removes its own '..(n1-n0)..' instances (emitters, beams, attachments) and nothing else ('..fxMade(body)..' left of '..n0..')')
end
-- cleaned up with the keeper: back to today's model (keepermodels off) leaves no effect anywhere; the new model again gets one set
do local Cmd=W.module('KeeperMeshCommand152');local old={}
 for stage=1,7 do for _,f in ipairs(fxList(guardians[stage].BeastBody))do old[#old+1]=f.Inst end end
 Cmd.Execute({},nil,{'off'});W.frames(3,1/60)
 local legacy,stray=0,0
 for stage=1,7 do local m=guardians[stage];if m:GetAttribute('KeeperMeshVariant')=='Legacy'then legacy+=1 end;stray+=#fxList(m)+fxMade(m)end
 local alive=0;for _,d in ipairs(old)do if d:IsDescendantOf(W.workspace)then alive+=1 end end
 check(legacy==7 and stray==0 and alive==0,'today\'s keepers (KeeperModels off): no KeeperFx152 effect on any of the 7 ('..stray..'), the old '..#old..' gone with the old body ('..alive..' left)')
 Cmd.Execute({},nil,{'auto'});W.frames(3,1/60)
 local again=0;for stage=1,7 do local body=guardians[stage].BeastBody;if body:GetAttribute('KeeperMeshVariant')=='R152'and sameKeys(fxKeys(body),wantKeys(stage))and fxMade(body)==made0[stage]then again+=1 end end
 check(again==7,'back to the new models: each gets its effects once again ('..again..' of 7)')
 -- a keeper taken out of the world: BeastAnimation drops its record and destroys its effects (they are not left on the stored body)
 local m=guardians[6];local list=fxList(m);m.Parent=nil;W.frames(2,1/60)
 local left=0;for _,f in ipairs(list)do if f.Inst:IsDescendantOf(m)then left+=1 end end
 check(#list>0 and left==0,'a keeper taken out of the world: its '..#list..' effects are destroyed ('..left..' left)')
 -- back in (Roblox fires DescendantAdded for each descendant; the mock only for the model, so the body's is fired here)
 m.Parent=W.workspace;W.workspace.DescendantAdded:Fire(m.BeastBody);W.frames(3,1/60)
 check(sameKeys(fxKeys(m.BeastBody),wantKeys(6))and fxMade(m.BeastBody)==made0[6],'and back in the world, it gets them once again')
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

-- 9b. The Darkened's wisps: the real VeiledEventClient81 loop with KeeperFx152, on the new model only, by tier and sleep, cleaned up --------
do local Veiled=W.module('VeiledKeeper81')
 local remotes=RS:FindFirstChild('ChestChaseRemotes')or R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=RS
 if not remotes:FindFirstChild('VeiledArrival81')then local remote=R.new('RemoteEvent');remote.Name='VeiledArrival81';remote._props.OnClientEvent=R.signal();remote.Parent=remotes end
 if not W.workspace:FindFirstChild('ChestChaseMap')then local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace end
 local players=W.service('Players');if not players.LocalPlayer then local lp=R.new('Player');lp.Name='KeeperTester';players.LocalPlayer=lp end
 local d=Veiled.Build(CF(0,5,800),W.workspace,Meshes.DarkenedParts());local old=Veiled.Build(CF(40,5,800),W.workspace)
 camera.CFrame=CF(0,20,760);S.tier=3
 local sc=R.new('LocalScript');sc.Name='VeiledEventClient81';local ok,err=pcall(W.load,'VeiledEventClient81',sc)
 check(ok,'the real VeiledEventClient81 runs on the mock: '..tostring(err))
 W.frames(3,1/30)
 local got,want=fxKeys(d),wantKeys(0)
 check(sameKeys(got,want)and want['Wisp@Torso_Cloak']==4 and want['Wisp@LHand']==1 and want['Wisp@RHand']==1 and want['Wisp@LFoot']==1 and want['Wisp@RFoot']==1,
  'The Darkened: void wisps at its cloak hem (4), hands and feet: '..keyText(got))
 check(fxMade(old)==0 and old:GetAttribute('KeeperMeshVariant')=='Legacy','today\'s Darkened (its blocks) gets none')
 local bad,off=0,0
 for _,f in ipairs(fxList(d))do
  if not(f.Host and f.Host.Parent==d and f.Host:GetAttribute('VeiledGroup'))then bad+=1 end
  local p=f.Host:GetAttribute('VeiledFrame')*f.Inst.Parent.CFrame.Position;local best=1e9
  for _,s in ipairs(C152.Stages[0].Fx)do if s.Part==f.Part then best=math.min(best,(p-V3(s.At[1],s.At[2],s.At[3])).Magnitude)end end
  if best>1e-3 then off+=1 end
 end
 check(bad==0 and off==0,'each wisp at its anchor, on a mesh part of its pose group (VeiledGroup), so it moves with it ('..bad..', '..off..')')
 local asleep=rates(d) -- GUARDING
 d:SetAttribute('GuardianBehavior','CHASING');W.frames(3,1/30);local awake=rates(d)
 S.tier=2;W.frames(3,1/30);local mid=rates(d);S.tier=1;W.frames(3,1/30);local low=rates(d);S.tier=3
 check(awake.Total>0 and asleep.Total>0 and asleep.Total<awake.Total,('its wisps dim while it sleeps (%.2f vs %.2f /s)'):format(asleep.Total,awake.Total))
 print(('INFO effects The Darkened: %s; particles/s tier 3 awake %.1f, asleep %.1f, tier 2 awake %.1f'):format(keyText(got),awake.Total,asleep.Total,mid.Total))
 check(awake.Max<=Fx152.MaxRate and awake.Total<=Fx152.MaxKeeperRate and mid.Max<=Fx152.MaxRate*.5 and math.abs(mid.Total*2-awake.Total)<=.16 and low.Total==0 and low.On==0,
  ('tier 3 %.2f /s, tier 2 half (%.2f), tier 1 none (%.2f)'):format(awake.Total,mid.Total,low.Total))
 camera.CFrame=CF(0,20,760-Fx152.Range-40);W.frames(2,1/30);check(rates(d).Total==0,'none beyond '..Fx152.Range..' studs');camera.CFrame=CF(0,20,760)
 -- cleaned up: a Darkened leaving the world loses its effects; the script's end destroys the rest
 local list=fxList(d);d.Parent=nil;W.frames(2,1/30)
 local left=0;for _,f in ipairs(list)do if f.Inst:IsDescendantOf(d)then left+=1 end end
 check(#list==8 and left==0,'a Darkened leaving the world: its '..#list..' wisps are destroyed ('..left..' left)')
 local d2=Veiled.Build(CF(0,5,820),W.workspace,Meshes.DarkenedParts());W.frames(2,1/30);local n=fxMade(d2)
 sc.Destroying:Fire();check(n>0 and fxMade(d2)==0,'the client script ending destroys the wisps it made ('..n..' -> '..fxMade(d2)..')')
 d2:Destroy();old:Destroy()
end

-- 10. Gameplay values untouched ------------------------------------------------------------------------------------------------------------------
do local Combat=W.module('KeeperCombat');local base={[1]=.30,[2]=.22,[3]=.24,[4]=.32,[5]=.32,[6]=.28,[7]=.34}
 local same=true;for s,w in pairs(base)do if Combat.Get(s).Windup~=w then same=false end end
 check(same and Combat.Recovery==.30 and Combat.HitHold==.07,'strike timing (KeeperCombat) unchanged')
 for stage=1,7 do local a,b=C152.Get(stage),Cfg[stage];check(a.Motion==b.Motion and a.Pivots==b.Pivots and a.Scale==b.Scale and a.Name==b.Name,'stage '..stage..': same pivots, motion (stride / speed) and scale as today')end
end

-- 11. The decode is sliced: a keeper's base64 + inflate + checksum + parts took 13 - 38 ms in one go at server start (review fix) ----------------------------------------
do
 local function sameParts(a,b)
  if #a.Parts~=#b.Parts then return false end
  for i,p in ipairs(a.Parts)do
   local q=b.Parts[i];if #p.V~=#q.V or #p.T~=#q.T or(p.P==nil)~=(q.P==nil)then return false end
   for j=1,#p.V do if p.V[j]~=q.V[j]then return false end end
   for j=1,#p.T do if p.T[j]~=q.T[j]then return false end end
   if p.P then for j=1,#p.P do if p.P[j]~=q.P[j]then return false end end end
  end
  return true
 end
 local identical,sliced,minTotal,gapMax,tickSum=true,true,0,0,0
 for _,stage in ipairs(ORDER)do
  local spec=C152.Stages[stage];local data=W.module(spec.Module)
  local plain=Meshes.Decode(data);local ticks,last=0,os.clock()
  local cut=Meshes.Decode(data,function()ticks+=1;local c=os.clock();gapMax=math.max(gapMax,c-last);last=c end)
  tickSum+=ticks
  if not sameParts(plain,cut)then identical=false;print('FAIL: '..spec.Name..': the sliced decode differs from the one-go decode')end
  -- about one tick per 1 KB inflated (a match can overshoot by 258 bytes), one per 4 KB checksummed, one per 512 parsed numbers
  local parse=0;for _,p in ipairs(plain.Parts)do parse+=(#p.V//3//512)*3+#p.T//512 end
  local least=data.Bytes//1300+data.Bytes//4096+parse
  if ticks<least then sliced=false;print('FAIL: '..spec.Name..': '..ticks..' ticks, at least '..least..' expected')end
  minTotal+=least
  -- the inflate alone: ticks too, same bytes
  local raw=Meshes.Base64(table.concat(data.Data));local t2=0
  local a,b=Meshes.Inflate(raw,data.Bytes),Meshes.Inflate(raw,data.Bytes,function()t2+=1 end)
  if t2<data.Bytes//1300 then sliced=false;print('FAIL: '..spec.Name..': inflate ticked '..t2..' times')end
  for k=0,data.Bytes-1 do if buffer.readu8(a,k)~=buffer.readu8(b,k)then identical=false;print('FAIL: '..spec.Name..': a ticked inflate differs at byte '..k);break end end
 end
 check(identical,'a decode with a tick is identical to one without (every keeper: vertices, triangles, palette cells)')
 check(sliced,'every keeper\'s decode ticks (about every 1 KB of work; >= '..minTotal..' ticks for the 8)')
 print(('INFO decode: %d ticks for the 8 keepers, longest stretch between two ticks %.2f ms (a keeper was 13 - 38 ms in one go)'):format(tickSum,gapMax*1000))
 -- the real bake yields while it decodes: count the task.wait calls made before its first EditableMesh (SliceSeconds -1: the mock clock stands still, so every slice() call yields)
 local calls0,before,waitRaw=log.Calls,0,W.env.task.wait
 W.env.task.wait=function(...)if log.Calls==calls0 then before+=1 end;return waitRaw(...)end
 local sliceWas=Meshes.SliceSeconds;Meshes.SliceSeconds=-1
 local ok,model=pcall(Meshes._bakeKeeper,6)
 Meshes.SliceSeconds=sliceWas;W.env.task.wait=waitRaw
 local data6=W.module(C152.Stages[6].Module)
 check(ok and model~=nil,'a keeper can still be baked with a slice of -1 s (every slice yields) ('..tostring(model)..')')
 check(before>=data6.Bytes//1300,'the bake yields while it decodes: '..before..' yields before the first EditableMesh (>= '..(data6.Bytes//1300)..')')
 if ok and model then model:Destroy()end
end
check(log.Alive()==0,'no EditableMesh alive at the end')
print(('R152 keepers (%s): %d checks, %d failures'):format(SCENARIO,checks,fails))
if fails>0 then error('failures',0)end
