--!nocheck
-- R151 (owner: the Verity pack should be the REAL standard chip-bag pouch in pure yellow, made at runtime; the sachet only as the fallback): VerityPouch151 +
-- VerityPackArt on the Roblox mock with the REAL modules of this checkout, the REAL pack templates of the owner's place (Storm_02: one MeshPart, MeshId
-- rbxassetid://75504658868908, 1.97 x 2.06 x 1.004) and a mock of the EditableMesh bake route (pouch_mock.luau: every way it can fail).
--  1. the bake       the live template's MeshId is what is loaded (never a literal), every vertex colour is white when the mesh is baked, the EditableMesh is destroyed,
--                    the neutral Model keeps the template's Size / PackLocalFrame; a second server bake is a no-op
--  2. failures       denied / no vertices / a colour that cannot be set / a colour that stays dark / the bake or the MeshPart fails / another mesh size / a missing
--                    or incomplete template / the 2nd mesh of a template fails (the 1st is destroyed): the folder says Failed + why, one warn, nothing leaked, and the
--                    pack is the R149 sachet, unchanged
--  3. the pouch pack every context (ground, held R15 + R6, CarryBag, opening copy, giant 15x / 25x, tiny .5x, Gold / Diamond): the same pouch part for part as
--                    the plain Standard pack of the stage (size, PackLocalFrame, pivot, Bounds, seal, strips), every part pure yellow 255,255,0 SmoothPlastic, the
--                    picture as exactly two Decals on the pouch's Front and Back, no effect, welded to the carrier and following a 120-frame run, giants tagged
--  4. pictures       the real ItemPictures: a client that asks before the bake is done waits (no sachet is cached), then draws the pouch (MeshPart in the
--                    ViewportFrame, both Decals); Gold / Diamond keep the Decals white; after a failed bake the picture is the sachet
--  5. states         still baking (a server uses the sachet, a client waits and gives up after LoadingSeconds), another design's pack, an attribute that arrives
--                    before the Model
--  6. nothing else   every other pack (78 stage x variant combinations incl. Void / Mech, sizes 1 / 25, coats None / Gold, ground + held) is identical whether the
--                    pouch is ready or not
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local typeof=R.typeof
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function inv(c)return c:Inverse()end
local function cfDelta(a,b)local d=(a.Position-b.Position).Magnitude;local r=0;for _,axis in ipairs({'RightVector','UpVector','LookVector'})do r=math.max(r,math.acos(math.clamp(a[axis]:Dot(b[axis]),-1,1)))end;return d,r end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function isYellow(c)local r,g,b=rgb(c);return r==255 and g==255 and b==0 end
local Run=W.Run
local function server()Run.IsServer=function()return true end;Run.IsClient=function()return false end end
local function client()Run.IsServer=function()return false end;Run.IsClient=function()return true end end
server() -- (before the first require of VerityPouch151: a server creates its folder when the module loads)
local Pouch=W.module('VerityPouch151');local Art=W.module('VerityPackArt');local Visuals=H.Visuals;local Rules=H.Rules;local Config=W.module('VerityConfig')
local VERITY,KEY,IMAGE=H.VERITY,'Storm_02','rbxassetid://102712963740896'
local ORIGINAL_ID='rbxassetid://75504658868908'
local assets=W.RS.SeedPackMeshAssets
local tpl=assets[KEY].ApprovedMesh01
tpl.MeshSize=tpl.Size -- (the mock's template has no MeshSize; the real one does)
local function folder()return W.RS:FindFirstChild(Pouch.Folder)end
local function dropFolder()local f=folder();if f then f:Destroy()end end
local function warns()return W.warns or 0 end
local function sig(bag)
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1;local out={}
 for _,p in ipairs(H.partsOf(bag,false))do
  local f=inv(root.CFrame)*p.CFrame
  out[(p.Parent==bag and''or'PackGeometry/')..p.Name]={Size=p.Size/scale,Pos=f.Position/scale,Frame=f,Class=p._class}
 end
 return out
end
local function sameSig(a,b,ignoreClass)
 for k,x in pairs(a)do
  local y=b[k];if not y then return false,'missing '..k end
  local d=math.max((x.Size-y.Size).Magnitude,(x.Pos-y.Pos).Magnitude,select(2,cfDelta(x.Frame,y.Frame))*.1)
  if d>1e-5 then return false,k..' differs by '..d end
  if not ignoreClass and x.Class~=y.Class then return false,k..' is a '..x.Class..' / '..y.Class end
 end
 for k in pairs(b)do if not a[k]then return false,'extra '..k end end
 return true
end
local function decalsOf(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
local BANNED={SurfaceAppearance=1,SurfaceGui=1,Texture=1,ParticleEmitter=1,PointLight=1,SpotLight=1,SurfaceLight=1,Highlight=1,Beam=1,Trail=1,Sparkles=1,Fire=1,Smoke=1,BillboardGui=1,ForceField=1,Explosion=1,ImageLabel=1,SpecialMesh=1}
local function sachetPack(size,coat)return H.ground(7,VERITY,size or 1,coat or'None')end

-- the base: the sachet while the pouch is not baked (the folder is there, not finished) and with no folder at all
local sachetBase
do
 local pre=sachetPack();sachetBase=sig(pre)
 check(pre:GetAttribute('VerityPackDesign')==149 and pre:FindFirstChild('VerityFace',true)~=nil and not pre:FindFirstChild('ApprovedMesh01',true),'before the bake (a server that is still baking) the Verity pack is the R149 sachet')
 pre:Destroy()
 local f=folder()
 check(f~=nil and f:GetAttribute('Finished')==false and f:GetAttribute('Ready')==false,'a server makes the folder at start: Finished = false, Ready = false')
 dropFolder()
 local none=sachetPack();check(sameSig(sig(none),sachetBase)and none:GetAttribute('VerityPackDesign')==149,'with no folder (a server that does not bake) it is the same sachet');none:Destroy()
end

-- 1. The bake -------------------------------------------------------------------------------------------------------------------------------------
Mock.reset()
check(Pouch.Key()==KEY and Pouch.State(KEY)=='Off','the design whose pouch Verity uses is '..KEY..' (VerityCatalog.PackStage + Variant); no folder: Off')
do
 local ok=Pouch.Prepare()
 check(ok==true,'Prepare on a server bakes the pouch')
 local f=folder()
 check(f and f:GetAttribute('Finished')==true and f:GetAttribute('Ready')==true and f:GetAttribute('Failed')==false and f:GetAttribute('Key')==KEY and f:GetAttribute('VertexCount')==1800 and f:GetAttribute('MeshCount')==1,'the folder says Finished + Ready, Key = Storm_02, 1800 vertices, 1 mesh')
 local neutral=f and f:FindFirstChild(KEY)
 check(neutral~=nil and neutral:IsA('Model')and neutral:GetAttribute('MeshCount')==1 and neutral:GetAttribute('MeshBakeVersion')==123 and neutral:GetAttribute('Neutral')==true,'the neutral template is a Model like the place\'s (MeshCount 1, MeshBakeVersion 123)')
 local np=neutral and neutral:FindFirstChild('ApprovedMesh01')
 check(np~=nil and np:IsA('MeshPart')and near(np.Size.X,tpl.Size.X)and near(np.Size.Y,tpl.Size.Y)and near(np.Size.Z,tpl.Size.Z),'the neutral MeshPart has the template\'s Size '..(np and tostring(np.Size)or'?'))
 local d,r=cfDelta(np:GetAttribute('PackLocalFrame'),tpl:GetAttribute('PackLocalFrame'))
 check(d<1e-9 and r<1e-9,'... and its PackLocalFrame (pivot and the 180 degree turn)')
 check(np.TextureID==''and np.Color.R==1 and np.Color.G==1 and np.Color.B==1 and np.Material.Name=='SmoothPlastic'and#np:GetChildren()==0,'... white, no texture, no appearance, no children')
 check(Mock.uris[1]==tpl.MeshId and Mock.uris[1]==ORIGINAL_ID and #Mock.uris==1,'the mesh loaded is the live template\'s MeshId ('..tostring(Mock.uris[1])..')')
 check(#Mock.colorsAtBake==1 and Mock.colorsAtBake[1]==0,'every vertex colour was white when the mesh was baked ('..tostring(Mock.colorsAtBake[1])..' of 1800 were not)')
 check(Mock.created==1 and Mock.alive==0 and Mock.baked==1 and Mock.bakedAlive==1,'one EditableMesh, destroyed after the bake (alive '..Mock.alive..'); one MeshPart kept')
 check(Pouch.Template(KEY)==neutral and Pouch.Template('Forest_02')==nil and Pouch.State(KEY)=='Ready'and Pouch.State('Forest_02')=='Off','State / Template: Ready for Storm_02, Off for another design')
 local calls=Mock.calls;check(Pouch.Prepare()==true and Mock.calls==calls,'a second Prepare is a no-op (nothing baked twice)')
 -- the id is READ from the template: change it, bake again
 dropFolder();Mock.reset();tpl.MeshId='rbxassetid://424242';check(Pouch.Prepare()==true and Mock.uris[1]=='rbxassetid://424242','the MeshId is read from the live template at run time, not written in the code')
 tpl.MeshId=ORIGINAL_ID
 local src=W.B.VerityPouch151
 check(not src:find('75504658868908',1,true)and not src:find('rbxassetid',1,true)and src:find('CreateEditableMeshAsync',1,true)and src:find('SetColor',1,true)and src:find('GetGeometry',1,true),'(source: no asset id in VerityPouch151; it loads the template\'s mesh with CreateEditableMeshAsync and sets the colours)')
 check(not W.B.VerityPackArt:find('CreateEditableMesh',1,true)and not W.B.VerityPackArt:find('rbxassetid',1,true),'(source: VerityPackArt does no mesh work and names no asset id (the picture comes from VerityConfig))')
end

-- 2. Failures -------------------------------------------------------------------------------------------------------------------------------------
local function failure(label,setup,reasonPart)
 dropFolder();Mock.reset();local restore=setup and setup()
 local w0=warns();local ok=Pouch.Prepare()
 local f=folder()
 check(ok==false and f and f:GetAttribute('Finished')==true and f:GetAttribute('Ready')==false and f:GetAttribute('Failed')==true,label..': Prepare says no; the folder says Finished + Failed')
 check(tostring(f:GetAttribute('Reason')or''):find(reasonPart,1,true)~=nil,label..': the reason names it ('..tostring(f:GetAttribute('Reason'))..')')
 check(#f:GetChildren()==0 and Mock.alive==0 and Mock.bakedAlive==0,label..': nothing left over (no Model, '..Mock.alive..' EditableMesh alive, '..Mock.bakedAlive..' MeshPart alive)')
 check(warns()==w0+1,label..': exactly one warning ('..(warns()-w0)..')')
 check(Pouch.State(KEY)=='Off'and Pouch.Template(KEY)==nil,label..': State is Off, no template')
 local calls=Mock.calls;check(Pouch.Prepare()==false and Mock.calls==calls,label..': a second Prepare answers the same without trying again')
 local pack=sachetPack();local same,why=sameSig(sig(pack),sachetBase)
 check(same and pack:GetAttribute('VerityPackDesign')==149 and pack:GetAttribute('VerityPouch')==nil and pack:FindFirstChild('VerityFace',true)~=nil,label..': the Verity pack is the R149 sachet, unchanged'..(why and(' ('..why..')')or''))
 pack:Destroy()
 if restore then restore()end
end
failure('denied (no permission on the asset)',function()Mock.mode='denied'end,'no permission')
failure('a mesh with no vertices',function()Mock.mode='no_vertices'end,'no vertices')
failure('a colour that cannot be set',function()Mock.mode='setcolor_error'end,'SetColor')
failure('a dark colour that survives',function()Mock.mode='color_stuck'end,'not white')
failure('the bake does not succeed',function()Mock.mode='content_fails'end,'could not bake')
failure('CreateMeshPartAsync fails',function()Mock.mode='meshpart_fails'end,'out of mesh memory')
failure('another mesh size',function()Mock.mode='size_mismatch'end,'not the original mesh')
failure('the template is not in the place',function()local m=assets[KEY];m.Name='Storm_02_gone';return function()m.Name=KEY end end,'is not in SeedPackMeshAssets')
failure('an incomplete template',function()local m=assets[KEY];m:SetAttribute('MeshCount',2);return function()m:SetAttribute('MeshCount',1)end end,'not a complete')
failure('the second mesh of a template fails (the first is destroyed)',function()
 local m=assets[KEY];local extra=tpl:Clone();extra.Name='ApprovedMesh02';extra:SetAttribute('PackLocalFrame',tpl:GetAttribute('PackLocalFrame'));extra.MeshSize=tpl.Size;extra.Parent=m;m:SetAttribute('MeshCount',2);Mock.mode='second_fails'
 return function()extra:Destroy();m:SetAttribute('MeshCount',1)end
end,'second mesh')
-- the good bake again for everything below
dropFolder();Mock.reset()
check(Pouch.Prepare()==true,'(the bake succeeds again with the mock back to normal)')
local neutral=folder():FindFirstChild(KEY)

-- 3. The pouch pack in every context --------------------------------------------------------------------------------------------------------------
local contexts=0
local function inspect(bag,label,size,coat,opts)
 opts=opts or{}
 contexts+=1
 local root=bag.PrimaryPart;local parts=H.partsOf(bag,true);local scale=bag:GetAttribute('VisualScale')or 1
 check(bag:GetAttribute('BagVariant')==VERITY and bag:GetAttribute('VerityPack')==true and bag:GetAttribute('VerityPouch')==true and bag:GetAttribute('VerityPackDesign')==151 and bag:GetAttribute('CompactPackReady')==true and bag:GetAttribute('EclipsePack')==nil,label..': a Verity pack built from the pouch (revision 151)')
 check(#parts==11 and bag:GetAttribute('CompactPackPartCount')==11,label..': 11 parts: the root, the seal, 8 tear strips and the one pouch MeshPart ('..#parts..')')
 local mesh=bag:FindFirstChild('ApprovedMesh01',true)
 check(mesh and mesh:IsA('MeshPart')and mesh.Parent.Name=='PackGeometry'and not bag:FindFirstChild('VerityFace',true),label..': the pouch is the template\'s MeshPart in PackGeometry (no plain-parts sachet)')
 -- the same pouch, part for part, as the plain pack of the same design
 local std=Visuals.Bag(opts.origin or CF(40,10,40),nil,1,nil,7,'Standard',1,size,'None')
 local same,why=sameSig(sig(bag),sig(std))
 check(same,label..': the same parts at the same size and pivot as the plain Standard pack ('..tostring(why)..')')
 check(near(scale,std:GetAttribute('VisualScale'),1e-9)and tostring(Visuals.Bounds(7,VERITY,size).Radius)==tostring(Visuals.Bounds(7,'Standard',size).Radius),label..': VisualScale and Bounds are the plain pack\'s')
 local d,r=cfDelta(inv(root.CFrame)*mesh.CFrame,tpl:GetAttribute('PackLocalFrame')*CF(0,0,0));local expect=tpl:GetAttribute('PackLocalFrame')
 check(near((inv(root.CFrame)*mesh.CFrame).Position.X,expect.Position.X*scale,1e-5)and near((inv(root.CFrame)*mesh.CFrame).Position.Y,expect.Position.Y*scale,1e-5)and near((inv(root.CFrame)*mesh.CFrame).Position.Z,expect.Position.Z*scale,1e-5),label..': the pouch sits at the template\'s PackLocalFrame (x scale)')
 std:Destroy()
 -- colour: pure yellow everywhere (None); the coat paints it like any pack (the Decals stay white)
 local c=Rules.PackMutations[coat]
 if coat=='None'then
  local pure=0;local why2=''
  for _,p in ipairs(parts)do if p~=root then
   if isYellow(p.Color)and p.Material.Name=='SmoothPlastic'and p.Reflectance==0 and p.Transparency==0 and(not p:IsA('MeshPart')or p.TextureID=='')then pure+=1 else why2=why2..' '..p.Name end
  end end
  check(pure==#parts-1,label..': every part, the pouch included, is exactly 255,255,0 SmoothPlastic, opaque, no texture ('..pure..'/'..(#parts-1)..why2..')')
 else
  local painted=true;for _,p in ipairs(parts)do if p~=root and(rgb(p.Color)~=rgb(c.Color)or p.Material~=c.Material)then painted=false end end
  check(painted,label..': the '..coat..' coat paints the whole pack, the pouch too, like any pack')
 end
 -- the picture: exactly two Decals, on the pouch, Front and Back, white
 local ds=decalsOf(bag);local faces={}
 for _,dd in ipairs(ds)do faces[dd.Face.Name]=(faces[dd.Face.Name]or 0)+1 end
 check(#ds==2 and #decalsOf(mesh)==2 and faces.Front==1 and faces.Back==1,label..': exactly two Decals, both on the pouch: one Front, one Back')
 for _,dd in ipairs(ds)do check(dd.Texture==IMAGE and dd.Transparency==0 and dd.Color3.R==1 and dd.Color3.G==1 and dd.Color3.B==1,label..': the '..dd.Face.Name..' Decal is Verity\'s picture, white, opaque, whatever the coat')end
 local banned={};for _,dd in ipairs(bag:GetDescendants())do if BANNED[dd._class]then banned[#banned+1]=dd._class end end
 check(#banned==0,label..': no emitter, light, highlight, beam, SurfaceGui, texture or appearance ('..table.concat(banned,',')..')')
 local ids=0;for _,dd in ipairs(bag:GetDescendants())do for _,k in ipairs({'TextureID','Texture','Image','MeshId'})do local v=dd._props[k];if type(v)=='string'and v~=''and v~=IMAGE then ids+=1 end end end
 check(ids==0,label..': no asset id on the pack but the picture\'s ('..ids..')')
 check(isYellow(bag:GetAttribute('PaperColor'))or coat~='None',label..': PaperColor is yellow')
 if size>10 then local tagged=0;for _,p in ipairs(parts)do if p~=root and W.CS:HasTag(p,'GiantVisualPart')then tagged+=1 end end;check(tagged==10,label..': a giant: the pouch, the seal and the 8 strips are all GiantVisualParts ('..tagged..')')end
end
local function connection(bag,label,char,torso)
 local parts=H.partsOf(bag,true);local g=H.bind({bag},{torso});local _,seen=H.pose(g,torso,torso.CFrame)
 local loose,anchored=0,0;for _,p in ipairs(parts)do if not seen[p]then loose+=1 end;if p.Anchored then anchored+=1 end end
 check(loose==0 and anchored==0,label..': every part (the pouch too) is welded to the carrier and none is anchored ('..loose..' loose, '..anchored..' anchored)')
 local dev=0;local root=bag.PrimaryPart
 for k=1,120 do local at=H.path(k,120);local poses=H.pose(g,torso,at);local d=H.deviation(g,root,poses,poses[root],parts);dev=math.max(dev,d)end
 check(dev<1e-6,label..': after 120 frames of running, turning and jumping nothing is left behind (worst '..string.format('%.2g',dev)..')')
end
server()
for _,size in ipairs({.5,1,2.5,10,15,25})do for _,coat in ipairs({'None','Gold','Diamond'})do
 local label=('ground %sx %s'):format(size,coat)
 local bag=H.ground(7,VERITY,size,coat);inspect(bag,label,size,coat,{giant=size>10})
 check(bag.PrimaryPart.Anchored and bag:FindFirstChild('ApprovedMesh01',true).Anchored and W.CS:HasTag(bag,'BiomeSeedPackVisual'),label..': anchored, tagged BiomeSeedPackVisual')
 bag:Destroy()
 for _,rig in ipairs({'R15','R6'})do
  local held,char,hrp,torso=H.held(7,VERITY,size,coat,rig);local l=('held %s %sx %s'):format(rig,size,coat)
  inspect(held,l,size,coat,{origin=hrp.CFrame});connection(held,l,char,torso)
  if rig=='R15'then
   -- the opening copy (SeedPackClient: welds removed, parts anchored): the pouch and both Decals come with it
   local copy=H.openingCopy(held);local ds=decalsOf(copy);local anch=true
   for _,p in ipairs(H.partsOf(copy,true))do if not p.Anchored then anch=false end end
   check(#ds==2 and copy:FindFirstChild('ApprovedMesh01',true)~=nil and anch,'opening copy '..size..'x '..coat..': the pouch with both Decals, every part anchored')
   copy:Destroy()
  end
  held:Destroy();char:Destroy()
 end
end end
do -- CarryBag (the same layout as a plain pack's)
 local char,hrp,torso=H.character('R15');local carry=Visuals.CarryBag(char,7,VERITY,1,1,'None');local plain=Visuals.CarryBag(char,7,'Standard',1,1,'None')
 check(carry and plain and carry.Name=='CarriedSeed'and carry:GetAttribute('VerityPouch')==true,'CarryBag builds the pouch pack')
 local a,b=carry:GetAttribute('CarryRootOffset'),plain:GetAttribute('CarryRootOffset')
 local d,r=cfDelta(a,b);check(d<1e-9 and r<1e-9 and near(carry:GetAttribute('CarryBackZ'),plain:GetAttribute('CarryBackZ')),'CarryBag: the carry layout is the plain pack\'s')
 carry:Destroy();plain:Destroy();char:Destroy()
end
print(('pouch pack: %d built packs inspected in every context (pouch %s, template %s)'):format(contexts,tostring(neutral.ApprovedMesh01.Size),tostring(tpl.Size)))

-- 4. Pictures (the real ItemPictures) -----------------------------------------------------------------------------------------------------------
do
 client()
 local Pic=W.module('ItemPictures')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=H.pg
 local function holder(x)local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(x,0);return h end
 local function view(h)return h:FindFirstChild('ItemViewport')end
 local function look(v)
  local meshes,yellow,visible,coat=0,0,0,0
  for _,d in ipairs(v:GetDescendants())do if d:IsA('BasePart')then
   if d:IsA('MeshPart')then meshes+=1 end
   if d.Transparency<1 then visible+=1;if isYellow(d.Color)and d.Material.Name=='SmoothPlastic'then yellow+=1 end end
  end end
  return meshes,yellow,visible
 end
 -- (a) a client asks while the server is still baking: nothing is drawn, nothing is cached
 dropFolder();local f=R.new('Folder');f.Name=Pouch.Folder;f:SetAttribute('Finished',false);f:SetAttribute('Ready',false);f.Parent=W.RS
 local tool=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack');local h1=holder(0)
 Pic.Show(h1,tool,1);for _=1,150 do W.frames(1)end
 check(view(h1)==nil,'(a) a client that asks while the server is still baking gets no picture yet (it is not cached as a sachet)')
 -- (b) the bake finishes: the picture is the real pouch
 dropFolder();server();Mock.reset();check(Pouch.Prepare()==true,'(b) the server finishes the bake');client()
 for _=1,300 do W.frames(1)end
 local v=view(h1)
 if check(v~=nil,'(b) ... and the picture draws on its own retry')then
  local meshes,yellow,visible=look(v);local ds=decalsOf(v)
  check(meshes==1 and yellow==visible and visible==10,('(b) the hotbar / Bag / Index picture is the pouch: %d MeshPart, %d visible parts, every one pure yellow (%d/%d)'):format(meshes,visible,yellow,visible))
  local okD=#ds==2;for _,dd in ipairs(ds)do if dd.Texture~=IMAGE or dd.Parent.Name~='ApprovedMesh01'or dd.Transparency~=0 then okD=false end end
  check(okD and ds[1].Face~=ds[2].Face,'(b) a MeshPart renders in a ViewportFrame, and both Decals are on it (Front + Back)')
 end
 -- (c) a Gold picture: gold pouch, white Decals
 local goldTool=F.pack(W,W.workspace,7,VERITY,1,'Gold','Gold Verity Pack');local h2=holder(70);Pic.Show(h2,goldTool,1);for _=1,200 do W.frames(1)end
 local gv=view(h2)
 if check(gv~=nil,'(c) a Gold Verity picture draws')then
  local meshes=look(gv);local gd=decalsOf(gv);local goldMesh;for _,d in ipairs(gv:GetDescendants())do if d:IsA('MeshPart')then goldMesh=d end end
  check(meshes==1 and goldMesh and rgb(goldMesh.Color)==rgb(Rules.PackMutations.Gold.Color)and#gd==2 and gd[1].Color3.R==1 and gd[2].Color3.R==1,'(c) the Gold picture is the gold pouch with both Decals white')
 end
 -- (d) the bake failed: the picture is the sachet
 dropFolder();server();Mock.reset();Mock.mode='denied';Pouch.Prepare();Mock.reset();client()
 local diaTool=F.pack(W,W.workspace,7,VERITY,1,'Diamond','Diamond Verity Pack');local h3=holder(140);Pic.Show(h3,diaTool,1);for _=1,200 do W.frames(1)end
 local dv=view(h3)
 if check(dv~=nil,'(d) after a failed bake the picture still draws')then
  local meshes=look(dv);local face;for _,d in ipairs(dv:GetDescendants())do if d.Name=='VerityFace'then face=d end end
  check(meshes==0 and face~=nil and#decalsOf(dv)==2,'(d) ... as the plain-parts sachet (no MeshPart, the face block with both Decals)')
 end
 -- the good bake again
 dropFolder();server();Mock.reset();check(Pouch.Prepare()==true,'(the bake succeeds again)');neutral=folder():FindFirstChild(KEY)
end

-- 5. States ---------------------------------------------------------------------------------------------------------------------------------------
do
 -- a client while the server is still baking: an error ItemPictures retries on; a server uses the sachet
 dropFolder();local f=R.new('Folder');f.Name=Pouch.Folder;f:SetAttribute('Finished',false);f:SetAttribute('Ready',false);f.Parent=W.RS
 client()
 check(Pouch.State(KEY)=='Loading','a client sees Loading while the server bakes')
 local ok,err=pcall(Visuals.Bag,CF(0,0,0),nil,1,nil,7,VERITY,1,1,'None')
 check(not ok and tostring(err):find('still loading',1,true)~=nil,'a client\'s build while Loading errors with "still loading" (ItemPictures retries those): '..tostring(err))
 server();local s=sachetPack();check(sameSig(sig(s),sachetBase)and s:GetAttribute('VerityPackDesign')==149,'a server that is still baking builds the sachet for that pack (it never waits or errors)');s:Destroy()
 -- ... and a client gives up after LoadingSeconds
 client();R.advance(Pouch.LoadingSeconds+1)
 check(Pouch.State(KEY)=='Off','a client stops waiting after '..Pouch.LoadingSeconds..' s: Off')
 local ok2,pack=pcall(Visuals.Bag,CF(0,0,0),nil,1,nil,7,VERITY,1,1,'None')
 check(ok2 and pack:FindFirstChild('VerityFace',true)~=nil,'... and builds the sachet');if ok2 then pack:Destroy()end
 -- the attribute reaching a client before the Model: Loading, then Ready when the Model arrives (a fresh question clock is not available, the timeout above has passed: Off is right)
 dropFolder();server();Mock.reset();Pouch.Prepare();neutral=folder():FindFirstChild(KEY)
 -- another design's pack: the sachet, even with the pouch ready
 local other=H.ground(1,VERITY,1,'None');check(other:GetAttribute('PackArtKey')=='Forest_02'and other:FindFirstChild('VerityFace',true)~=nil and other:GetAttribute('VerityPouch')==nil,'a Verity pack of another design (Forest_02) is the sachet: only Storm_02 is baked');other:Destroy()
 -- a pack that fails halfway through the pouch build is cleaned up and rebuilt as the sachet
 local real=Art.Build
 local bag=Visuals.Bag(CF(0,0,0),nil,1,nil,7,'Standard',1,1,'None');bag:SetAttribute('BagVariant',VERITY)
 for _,d in ipairs(bag:GetChildren())do if d.Name=='PackGeometry'then d:Destroy()end end;bag:SetAttribute('CompactPackReady',nil)
 neutral.ApprovedMesh01:SetAttribute('PackLocalFrame',nil) -- (a corrupt template: BuildStandard asserts)
 local ok3,built=pcall(Art.Build,bag,function()return true end)
 check(ok3 and built==true and bag:FindFirstChild('VerityFace',true)~=nil and bag:FindFirstChild('ApprovedMesh01',true)==nil and bag:GetAttribute('VerityPouch')==nil and bag:GetAttribute('VerityPackDesign')==149,'a pouch build that breaks halfway is cleaned up and the pack is built as the sachet: '..tostring(built))
 bag:Destroy()
 neutral.ApprovedMesh01:SetAttribute('PackLocalFrame',tpl:GetAttribute('PackLocalFrame'))
 -- an invalidated build returns false and leaves nothing
 local b2=Visuals.Bag(CF(0,0,0),nil,1,nil,7,'Standard',1,1,'None');b2:SetAttribute('BagVariant',VERITY)
 for _,d in ipairs(b2:GetChildren())do if d.Name=='PackGeometry'then d:Destroy()end end;b2:SetAttribute('CompactPackReady',nil)
 local gone=Art.Build(b2,function()return false end);check(gone==false and b2:FindFirstChild('PackGeometry')==nil,'an invalidated build (the picture was dropped) returns false and leaves no geometry');b2:Destroy()
 local n=#decalsOf(W.workspace);check(n==0,'(no Decal is left in the workspace: '..n..')')
end

-- 6. Everything else is identical whether the pouch is ready or not -----------------------------------------------------------------------------
do
 local function snapshot()
  local out={};local count=0
  for _,stage in ipairs(H.STAGES)do
   local variants={table.unpack(H.ORDINARY)};for _,v in ipairs(H.LEGACY)do variants[#variants+1]=v end;variants[#variants+1]=H.VOID
   for _,variant in ipairs(variants)do for _,size in ipairs({1,25})do for _,coat in ipairs({'None','Gold'})do
    local g=H.ground(stage,variant,size,coat);out[#out+1]=('ground %d %s %s %s\n'):format(stage,variant,size,coat)..table.concat(H.lines(g),'\n');g:Destroy();count+=1
    if stage==4 or stage==7 then local h,char=H.held(stage,variant,size,coat,'R15');out[#out+1]=('held %d %s %s %s\n'):format(stage,variant,size,coat)..table.concat(H.lines(h),'\n');h:Destroy();char:Destroy();count+=1 end
   end end end
  end
  for _,size in ipairs({1,25})do for _,coat in ipairs({'None','Gold'})do
   local g=H.ground(8,H.MECH,size,coat);out[#out+1]=('mech %s %s\n'):format(size,coat)..table.concat(H.lines(g),'\n');g:Destroy();count+=1
  end end
  return out,count
 end
 server();dropFolder();Mock.reset();Pouch.Prepare();local ready,n1=snapshot()
 dropFolder();local off,n2=snapshot()
 local different=0;local first
 for i=1,#ready do if ready[i]~=off[i]then different+=1;first=first or i end end
 if first then
  local a,b={},{};for l in ready[first]:gmatch('[^\n]+')do a[#a+1]=l end;for l in off[first]:gmatch('[^\n]+')do b[#b+1]=l end
  for i=1,math.max(#a,#b)do if a[i]~=b[i]then print('first difference ('..a[1]..'):\n  ready: '..tostring(a[i])..'\n  none : '..tostring(b[i]));break end end
 end
 check(n1==n2 and n1>300 and different==0,('%d other packs (every ordinary design, the legacy keys, the Void and the Mech; ground and held; sizes 1 / 25; None / Gold) are identical with the pouch ready and with none: %d differ'):format(n1,different))
 if different==0 then print(('nothing else: %d packs identical with and without the neutral pouch'):format(n1))end
 -- and the Verity pack alone differs
 Mock.reset();Pouch.Prepare();local a=H.ground(7,VERITY,1,'None');local aSig=sig(a);dropFolder();local b=sachetPack();local bSig=sig(b)
 check(a:GetAttribute('VerityPouch')==true and b:GetAttribute('VerityPouch')==nil and not sameSig(aSig,bSig),'the Verity pack itself is the pouch with it and the sachet without');a:Destroy();b:Destroy()
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
