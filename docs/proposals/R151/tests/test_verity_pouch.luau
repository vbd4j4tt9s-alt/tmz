--!nocheck
-- R151 / R152 (owner: "verity pack is also not flat for some reason and there is some leftover design"): VerityPouch151 (the server makes a clean FLAT pouch at run time with
-- EditableMesh: AssetService:CreateEditableMesh -> AddVertex ... AddTriangle -> CreateDataModelContentAsync -> CreateMeshPartAsync -> ReplicatedStorage.VerityPouchTemplate151) and
-- VerityPackArt (the pouch pack, the sachet fallback) on the Roblox mock (/opt/luau/luau) with the REAL modules of this checkout, the REAL pack templates of the owner's place
-- (pack_templates.luau: Storm_02, one MeshPart, 1.97 x 2.06 x 1.004) and a mock of the EditableMesh routes with a switch for every failure (pouch_mock.luau).
--  1. the bake       the pouch is GENERATED (no asset id is loaded, the template is read only for its pouch part's Size / PackLocalFrame), every vertex colour is white when the mesh
--                    is baked, the EditableMesh is destroyed, the Model keeps the template's width, height and PackLocalFrame; a second server bake is a no-op
--  1b. the mesh      what was baked IS VerityPouch151.Generate: front and back are exactly two flat planes (within 1e-9) over the whole body, NOTHING stands out of them (no relief,
--                    no dent), the long edges are rounded, the ends pinch to a crimped zig-zag seal that closes in a knife edge, top and bottom mirror each other, the mesh is a closed
--                    outward-facing surface, the bounding box is the part's Size and centred, one white colour on every face, UVs on every face; odd sizes and a size that does not fit
--  2. failures       denied / no mesh memory / AddVertex fails / the bake or the MeshPart fails / another mesh size / a missing or incomplete template / a template with no frame /
--                    a template with extra parts (only the pouch is used): the folder says Failed + why, one warn, nothing leaked, and the pack is the R149 sachet, unchanged
--  3. the pouch pack every context (ground, held R15 + R6, CarryBag, opening copy, giant 15x / 25x, tiny .5x, Gold / Diamond): the same parts as the plain Standard pack of the stage
--                    (width, height, PackLocalFrame, pivot, Bounds, seal, strips; only the depth is the flat sachet's), the pouch pure yellow 255,255,0, the seal and strips the darker
--                    yellow, the picture as exactly two Decals on the pouch's Front and Back, NO leftover design (no appearance, texture, relief, extra part or Storm decal), no
--                    effect, welded to the carrier and following a 120-frame run, giants tagged; NEVER SHAPED (PackShapes151): every roll, flag and stale attribute builds the same flat pouch
--  4. pictures       the real ItemPictures: a client that asks before the bake is done waits (no sachet is cached), then draws the pouch (MeshPart in the ViewportFrame, both
--                    Decals), flagged or rolled or not; Gold / Diamond keep the Decals white; after a failed bake the picture is the sachet
--  5. states         still baking (a server uses the sachet, a client waits and gives up after LoadingSeconds), another design's pack, an attribute that arrives before the Model
--  6. nothing else   every other pack (78 stage x variant combinations incl. Void / Mech, sizes 1 / 25, coats None / Gold, ground + held) is identical whether the pouch is ready or not
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
W.module('PackShapes151').Config.Enabled=false -- (this suite is about the neutral pouch alone: the pack shape variations have test_pack_shapes.luau)
local Pouch=W.module('VerityPouch151');local Art=W.module('VerityPackArt');local Visuals=H.Visuals;local Rules=H.Rules;local Config=W.module('VerityConfig')
local VERITY,KEY,IMAGE=H.VERITY,'Storm_02','rbxassetid://102712963740896'
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
local function sameSig(a,b,ignoreClass,ignoreDepth)
 for k,x in pairs(a)do
  local y=b[k];if not y then return false,'missing '..k end
  local xs,ys=x.Size,y.Size;if k==ignoreDepth then xs=V3(xs.X,xs.Y,0);ys=V3(ys.X,ys.Y,0)end -- (the flat pouch is thinner than the standard one, by design)
  local d=math.max((xs-ys).Magnitude,(x.Pos-y.Pos).Magnitude,select(2,cfDelta(x.Frame,y.Frame))*.1)
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
local DEPTH=tpl.Size.Z*Pouch.DepthShare
check(Pouch.Key()==KEY and Pouch.State(KEY)=='Off','the design whose pouch Verity uses is '..KEY..' (VerityCatalog.PackStage + Variant); no folder: Off')
do
 local ok=Pouch.Prepare()
 check(ok==true,'Prepare on a server makes the pouch')
 local f=folder()
 check(f and f:GetAttribute('Finished')==true and f:GetAttribute('Ready')==true and f:GetAttribute('Failed')==false and f:GetAttribute('Key')==KEY and f:GetAttribute('Flat')==true and f:GetAttribute('MeshCount')==1 and f:GetAttribute('Revision')==152 and (f:GetAttribute('VertexCount')or 0)>1000 and (f:GetAttribute('TriangleCount')or 0)>2000,'the folder says Finished + Ready + Flat, Key = Storm_02, 1 mesh, revision 152, a few thousand vertices / triangles ('..tostring(f and f:GetAttribute('VertexCount'))..' / '..tostring(f and f:GetAttribute('TriangleCount'))..')')
 local neutral=f and f:FindFirstChild(KEY)
 check(neutral~=nil and neutral:IsA('Model')and neutral:GetAttribute('MeshCount')==1 and neutral:GetAttribute('MeshBakeVersion')==123 and neutral:GetAttribute('Neutral')==true and neutral:GetAttribute('Flat')==true,'the flat template is a Model like the place\'s (MeshCount 1, MeshBakeVersion 123, Flat)')
 local np=neutral and neutral:FindFirstChild('ApprovedMesh01')
 check(np~=nil and np:IsA('MeshPart')and #neutral:GetChildren()==1,'... holding ONE MeshPart, named like the template\'s')
 check(near(np.Size.X,tpl.Size.X)and near(np.Size.Y,tpl.Size.Y)and near(np.Size.Z,DEPTH,1e-9)and np.Size.Z<tpl.Size.Z,'the flat pouch has the template\'s width and height and the flat depth '..string.format('%.4f',DEPTH)..' ('..tostring(np.Size)..' vs '..tostring(tpl.Size)..')')
 local d,r=cfDelta(np:GetAttribute('PackLocalFrame'),tpl:GetAttribute('PackLocalFrame'))
 check(d<1e-9 and r<1e-9,'... and its PackLocalFrame (pivot and the 180 degree turn)')
 check(np.TextureID==''and np.Color.R==1 and np.Color.G==1 and np.Color.B==1 and np.Material.Name=='SmoothPlastic'and#np:GetChildren()==0,'... white, no texture, no appearance, no children')
 check(Mock.generated==1 and Mock.calls==1 and #Mock.uris==0,'the mesh is GENERATED (CreateEditableMesh once); no asset is loaded (no CreateEditableMeshAsync, no MeshId: '..#Mock.uris..' asked)')
 check(#Mock.colorsAtBake==1 and Mock.colorsAtBake[1]==0,'every vertex colour was white when the mesh was baked ('..tostring(Mock.colorsAtBake[1])..' were not)')
 check(Mock.created==1 and Mock.alive==0 and Mock.baked==1 and Mock.bakedAlive==1,'one EditableMesh, destroyed after the bake (alive '..Mock.alive..'); one MeshPart kept')
 check(Pouch.Template(KEY)==neutral and Pouch.Template('Forest_02')==nil and Pouch.State(KEY)=='Ready'and Pouch.State('Forest_02')=='Off','State / Template: Ready for Storm_02, Off for another design')
 local calls=Mock.calls;check(Pouch.Prepare()==true and Mock.calls==calls,'a second Prepare is a no-op (nothing baked twice)')
 -- the template's MeshId is NOT used: change it, bake again, nothing is asked for it
 dropFolder();Mock.reset();tpl.MeshId='rbxassetid://424242';check(Pouch.Prepare()==true and #Mock.uris==0,'the template\'s MeshId is never loaded (the pouch does not depend on the asset)')
 tpl.MeshId='rbxassetid://75504658868908'
 local src=W.B.VerityPouch151
 check(not src:find('rbxassetid',1,true)and not src:find('CreateEditableMeshAsync',1,true)and not src:find('GetColors',1,true)and not src:find('MeshId',1,true)and src:find('CreateEditableMesh()',1,true)and src:find('AddTriangle',1,true)and src:find('GetGeometry',1,true),'(source: VerityPouch151 names no asset id and never loads a mesh: it generates one with CreateEditableMesh / AddTriangle; it reads the template only for its Size and frame)')
 check(not W.B.VerityPackArt:find('CreateEditableMesh',1,true)and not W.B.VerityPackArt:find('rbxassetid',1,true)and not W.B.VerityPackArt:find('require(script.Parent.PackShapes151)',1,true)and not W.B.VerityPackArt:find('Shapes.ForBag',1,true)and not W.B.VerityPackArt:find('GetAttribute(\'PackShape\')',1,true)and not W.B.VerityPackArt:find('RequestPlain',1,true),'(source: VerityPackArt does no mesh work, names no asset id, does not require PackShapes151 and never reads a PackShape (the picture comes from VerityConfig))')
end

-- 1b. The mesh itself ---------------------------------------------------------------------------------------------------------------------------
-- audit(verts, faces, normals, W, H, D, label): the shape promises, on plain data. `verts` is a list of {x,y,z}.
local function audit(verts,faces,normals,W_,H_,D_,label,o)
 o=o or Pouch
 local half,body=D_/2,H_/2-o.CrimpHeight-o.TaperHeight;local rad=math.min(o.EdgeRadius,W_/4,half*.9);local eps=1e-9
 local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
 for _,p in ipairs(verts)do for i=1,3 do lo[i]=math.min(lo[i],p[i]);hi[i]=math.max(hi[i],p[i])end end
 check(near(hi[1],W_/2,eps)and near(hi[2],H_/2,eps)and near(hi[3],half,eps)and near(lo[1],-W_/2,eps)and near(lo[2],-H_/2,eps)and near(lo[3],-half,eps),label..': the bounding box is exactly '..W_..' x '..H_..' x '..D_..' and centred on the origin')
 -- the faces: two exactly flat planes over the whole body
 local zs,face,proud,dented=0,0,0,0;local seen={}
 for _,p in ipairs(verts)do
  if math.abs(p[2])<=body+eps and math.abs(p[1])<=W_/2-rad+eps then
   face+=1;local z=math.floor(p[3]*1e6+.5)
   if not seen[z]then seen[z]=true;zs+=1 end
   if math.abs(math.abs(p[3])-half)>eps then dented+=1 end
  end
  if math.abs(p[3])>half+eps then proud+=1 end
 end
 check(face>100 and zs==2 and dented==0,label..': front and back are exactly flat: '..face..' face vertices on '..zs..' planes (z = +-'..string.format('%.4f',half)..'), '..dented..' off them')
 check(proud==0,label..': nothing stands out of the faces (no relief): '..proud..' vertices beyond z = +-'..string.format('%.4f',half))
 -- the taper never bumps: along the centre column the front surface only goes down towards each end
 local col={};for _,p in ipairs(verts)do if math.abs(p[1])<eps and p[3]>0 and p[2]>=0 then col[#col+1]=p end end
 table.sort(col,function(a,b)return a[2]<b[2]end)
 local mono=#col>=o.TaperRows;for i=2,#col do if col[i][3]>col[i-1][3]+eps then mono=false end end
 check(mono,label..': the pinch to the seal is monotonic (no bump) along the centre ('..#col..' rows)')
 -- the seal band: thin, ridged, never thicker than its own half thickness + amplitude
 local seal,sealMax=0,0;for _,p in ipairs(verts)do if math.abs(p[2])>=H_/2-o.CrimpHeight-eps then seal+=1;sealMax=math.max(sealMax,math.abs(p[3]))end end
 check(seal>0 and sealMax<=math.min(o.CrimpHalf,half*.5)+o.CrimpAmplitude+eps,label..': the seal band is thin ('..seal..' vertices, thickest '..string.format('%.4f',sealMax)..')')
 -- top and bottom mirror each other
 local key=function(p)return string.format('%.6f,%.6f,%.6f',p[1],p[2],p[3])end
 local set={};for _,p in ipairs(verts)do set[key(p)]=true end
 local mirrored=true;for _,p in ipairs(verts)do if not set[key({p[1],-p[2],p[3]})]then mirrored=false;break end end
 check(mirrored,label..': the top and the bottom are mirror images')
 -- a closed, outward-facing surface
 local edges,degenerate,vol={},0,0
 for _,t in ipairs(faces)do
  local a,b,c=verts[t[1]],verts[t[2]],verts[t[3]]
  if not(a and b and c)or t[1]==t[2]or t[2]==t[3]or t[1]==t[3]then degenerate+=1
  else
   local ux,uy,uz=b[1]-a[1],b[2]-a[2],b[3]-a[3];local vx,vy,vz=c[1]-a[1],c[2]-a[2],c[3]-a[3]
   local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx;if nx*nx+ny*ny+nz*nz<1e-18 then degenerate+=1 end
   vol+=(a[1]*(b[2]*c[3]-b[3]*c[2])-a[2]*(b[1]*c[3]-b[3]*c[1])+a[3]*(b[1]*c[2]-b[2]*c[1]))/6
   for k=1,3 do local x,y=t[k],t[k%3+1];local e=math.min(x,y)..'_'..math.max(x,y);edges[e]=(edges[e]or 0)+1 end
  end
 end
 local bad=0;for _,c in pairs(edges)do if c~=2 then bad+=1 end end
 check(degenerate==0 and bad==0 and vol>0,label..': a closed surface (every edge in exactly two triangles: '..bad..' not), facing outward (volume '..string.format('%.3f',vol)..'), '..degenerate..' degenerate triangles')
 -- the vertex normals: unit, and straight out of the flat faces
 local unit,straight=true,true
 for i,n in ipairs(normals or{})do
  if math.abs(math.sqrt(n[1]*n[1]+n[2]*n[2]+n[3]*n[3])-1)>1e-6 then unit=false end
  local p=verts[i];if math.abs(p[2])<=body-.2 and math.abs(p[1])<=W_/2-rad-1e-6 and math.abs(math.abs(n[3])-1)>1e-6 then straight=false end
 end
 check(unit and #(normals or{})==#verts,label..': one unit normal per vertex')
 check(straight,label..': the face normals point straight out of the flat faces (+-Z)')
 -- the rounded long edges: the flat face stops short of the side, which is round (not a sharp corner)
 local round=false;for _,p in ipairs(verts)do if math.abs(p[2])<=body and math.abs(p[1])>W_/2-rad+1e-6 and math.abs(p[1])<W_/2-1e-6 and math.abs(p[3])<half-1e-6 and math.abs(p[3])>0 then round=true;break end end
 check(round,label..': the long edges are rounded (radius '..string.format('%.3f',rad)..')')
 return face
end
local function arrays(mesh)local v,n={},{};for i,p in ipairs(mesh._pos)do v[i]={p.X,p.Y,p.Z}end;for i,q in ipairs(mesh._normals)do n[i]={q.X,q.Y,q.Z}end;return v,n end
do
 dropFolder();Mock.reset();check(Pouch.Prepare()==true,'(the bake for the geometry checks)')
 local m=Mock.meshes[#Mock.meshes];local verts,normals=arrays(m)
 local W_,H_=tpl.Size.X,tpl.Size.Y
 local np=folder():FindFirstChild(KEY).ApprovedMesh01
 check(m.Generated and #verts==np:GetAttribute('VertexCount')and #m.F==np:GetAttribute('TriangleCount')and #m.FN==#m.F and #m.FC==#m.F and #m._normals==#verts,'the baked EditableMesh: '..#verts..' vertices, '..#m.F..' triangles, a normal id and a colour id on every face')
 audit(verts,m.F,normals,W_,H_,DEPTH,'baked mesh')
 -- what was baked IS the module's own Generate
 local g=Pouch.Generate(W_,H_,DEPTH);local same=#g.Vertices==#verts and #g.Faces==#m.F
 if same then for i,p in ipairs(g.Vertices)do local q=verts[i];if math.abs(p[1]-q[1])>1e-6 or math.abs(p[2]-q[2])>1e-6 or math.abs(p[3]-q[3])>1e-6 then same=false;break end end end
 if same then for i,t in ipairs(g.Faces)do local q=m.F[i];if t[1]~=q[1]or t[2]~=q[2]or t[3]~=q[3]then same=false;break end end end
 check(same,'... and it is exactly VerityPouch151.Generate (vertices and triangles, in order)')
 -- the ridges of the seal: Columns / 4 teeth on the front, a knife edge at each end (front and back share the end vertices)
 local ridges,knife=0,0;local top=H_/2-Pouch.EdgeBevel
 for _,p in ipairs(verts)do
  if math.abs(p[2]-top)<1e-9 and p[3]>0 and near(p[3],math.min(Pouch.CrimpHalf,DEPTH/4)+Pouch.CrimpAmplitude,1e-9)then ridges+=1 end
  if near(p[2],H_/2,1e-9)then knife+=1 end
 end
 check(ridges==Pouch.Columns/4,'the crimped seal has '..ridges..' zig-zag ridges on the front ('..Pouch.Columns/4 ..' expected)')
 check(knife==Pouch.Columns+1,'the top edge closes in a knife edge: front and back share its '..knife..' vertices ('..Pouch.Columns+1 ..' expected)')
 -- one white colour on every corner of every face; planar UVs on every face
 local whiteOnly=#m._colors==1 and m._colors[1].R==1 and m._colors[1].G==1 and m._colors[1].B==1 and m._alpha[1]==1
 for f=1,#m.F do local c=m.FC[f];if not(c and c[1]==1 and c[2]==1 and c[3]==1)then whiteOnly=false;break end end
 check(whiteOnly,'ONE white colour (alpha 1), on all three corners of every face')
 local uvOk=#m.FUV==#m.F and #m._uvs>0;for _,uv in ipairs(m._uvs)do if uv.X<-1e-9 or uv.X>1+1e-9 or uv.Y<-1e-9 or uv.Y>1+1e-9 then uvOk=false end end
 check(uvOk,'UVs: every face has them ('..#m._uvs..' UV coordinates, all inside 0..1), planar')
 local faceU={};for f,t in ipairs(m.F)do if m.FUV[f]then for k=1,3 do local p=verts[t[k]];if math.abs(p[2])<.8 and math.abs(math.abs(p[3])-DEPTH/2)<1e-9 and math.abs(p[1])<.05 then local uv=m._uvs[m.FUV[f][k]];faceU[p[3]>0 and'back'or'front']=uv.X end end end end
 check(faceU.front and faceU.back and math.abs(faceU.front-.5)<.03 and math.abs(faceU.back-.5)<.03,'... the face centre is the middle of the picture on the Front and on the Back')
 -- other sizes: the same promises (a wider, flatter pouch; a tall thin one); a size the shape does not fit is refused
 for _,sz in ipairs({{3,2.4,.4},{1.2,3.1,.9},{1.97,2.06,1.004}})do
  local d=Pouch.Generate(sz[1],sz[2],sz[3]);audit(d.Vertices,d.Faces,d.Normals,sz[1],sz[2],sz[3],('Generate %sx%sx%s'):format(sz[1],sz[2],sz[3]))
 end
 check(not pcall(Pouch.Generate,1.97,.5,.5),'a size the shape does not fit (a pouch shorter than its seal and taper) is refused')
 check(not pcall(Pouch.Generate,1.97,2.06,.5,{Columns=70,Corner=6,TaperRows=8,CrimpHalf=.02,CrimpAmplitude=.025,EdgeRadius=.14,TaperHeight=.26,CrimpHeight=.09,EdgeBevel=.012}),'a column count that is not a multiple of 4 (the seal\'s ridge period) is refused')
 -- pure and deterministic
 local g2=Pouch.Generate(W_,H_,DEPTH);local det=#g2.Vertices==#g.Vertices;if det then for i,p in ipairs(g.Vertices)do local q=g2.Vertices[i];if p[1]~=q[1]or p[2]~=q[2]or p[3]~=q[3]then det=false;break end end end
 check(det,'Generate is deterministic')
 -- the same with the UV API missing: the bake still succeeds (UVs are best effort)
 dropFolder();Mock.reset();Mock.mode='no_uv';check(Pouch.Prepare()==true and Mock.alive==0,'without AddUV / SetFaceUVs the pouch still bakes (UVs are best effort) and the EditableMesh is destroyed');Mock.reset()
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
failure('denied (EditableMesh is not allowed)',function()Mock.mode='denied'end,'not allowed')
failure('no mesh memory (CreateEditableMesh returns nil)',function()Mock.mode='nil_editable'end,'no EditableMesh')
failure('AddVertex fails halfway',function()Mock.mode='addvertex_error'end,'AddVertex')
failure('the bake does not succeed',function()Mock.mode='content_fails'end,'could not bake')
failure('CreateMeshPartAsync fails',function()Mock.mode='meshpart_fails'end,'out of mesh memory')
failure('another mesh size',function()Mock.mode='size_mismatch'end,'not the mesh generated')
failure('the template is not in the place',function()local m=assets[KEY];m.Name='Storm_02_gone';return function()m.Name=KEY end end,'is not in SeedPackMeshAssets')
failure('an incomplete template',function()local m=assets[KEY];m:SetAttribute('MeshCount',2);return function()m:SetAttribute('MeshCount',1)end end,'not a complete')
failure('a template whose pouch has no frame',function()local f0=tpl:GetAttribute('PackLocalFrame');tpl:SetAttribute('PackLocalFrame',nil);return function()tpl:SetAttribute('PackLocalFrame',f0)end end,'no PackLocalFrame')
failure('a template whose pouch has no size',function()local s0=tpl.Size;tpl.Size=V3(0,2,1);return function()tpl.Size=s0 end end,'has no size')
do -- a design with more parts than the pouch (like Storm_04's neon and metal): only the pouch is used
 dropFolder();Mock.reset()
 local m=assets[KEY];local extra=tpl:Clone();extra.Name='ApprovedMesh02';extra:SetAttribute('PackLocalFrame',tpl:GetAttribute('PackLocalFrame'));extra.Size=V3(1.7,1.9,.4);extra.Parent=m;m:SetAttribute('MeshCount',2)
 check(Pouch.Prepare()==true and Mock.created==1 and Mock.alive==0,'a template with a second part: the flat pouch is made from the first (ApprovedMesh01) alone; one EditableMesh, destroyed')
 local model=folder():FindFirstChild(KEY);check(model and #model:GetChildren()==1 and model:GetAttribute('MeshCount')==1 and model:FindFirstChild('ApprovedMesh02')==nil,'... and the Model has ONE part (nothing of the design\'s other parts comes with the Verity pack)')
 extra:Destroy();m:SetAttribute('MeshCount',1)
end
do -- a world WITHOUT the EditableMesh API: an expected fallback (the sachet), so it is quiet; the folder still says why
 dropFolder();Mock.reset();Mock.api(false);local w0=warns();local ok=Pouch.Prepare();local f=folder()
 check(ok==false and f:GetAttribute('Failed')==true and f:GetAttribute('Finished')==true and tostring(f:GetAttribute('Reason')):find('is not available in this environment',1,true)~=nil,'no EditableMesh API: Prepare says no; the folder says Failed + why ('..tostring(f:GetAttribute('Reason'))..')')
 check(warns()==w0,'... and NO warning: an environment without EditableMesh is an expected fallback ('..(warns()-w0)..')')
 check(#f:GetChildren()==0 and Mock.created==0 and Pouch.State(KEY)=='Off','... nothing made, nothing loaded, State Off')
 local pack=sachetPack();check(sameSig(sig(pack),sachetBase)and pack:GetAttribute('VerityPackDesign')==149 and pack:GetAttribute('VerityPouch')==nil,'... the Verity pack is the R149 sachet, unchanged');pack:Destroy()
 Mock.api(true)
end
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
 check(bag:GetAttribute('BagVariant')==VERITY and bag:GetAttribute('VerityPack')==true and bag:GetAttribute('VerityPouch')==true and bag:GetAttribute('VerityPackDesign')==152 and bag:GetAttribute('CompactPackReady')==true and bag:GetAttribute('EclipsePack')==nil,label..': a Verity pack built from the flat pouch (revision 152)')
 check(#parts==11 and bag:GetAttribute('CompactPackPartCount')==11,label..': 11 parts: the root, the seal, 8 tear strips and the one pouch MeshPart ('..#parts..')')
 local mesh=bag:FindFirstChild('ApprovedMesh01',true)
 check(mesh and mesh:IsA('MeshPart')and mesh.Parent.Name=='PackGeometry'and not bag:FindFirstChild('VerityFace',true),label..': the pouch is the flat template\'s MeshPart in PackGeometry (no plain-parts sachet)')
 local kids,decalKids,otherKids={},0,0;for _,v in ipairs(mesh:GetChildren())do if v:IsA('Decal')then decalKids+=1 elseif not v:IsA('WeldConstraint')then otherKids+=1 end end
 check(#mesh.Parent:GetChildren()==1 and decalKids==2 and otherKids==0 and mesh.MaterialVariant==''and mesh.TextureID=='',label..': PackGeometry holds the pouch and nothing else; the pouch holds its two Decals (and its weld) and nothing else (no appearance, texture or normal map, no part of the Storm design)')
 local known={VisualRoot=true,BottomSeal=true,ApprovedMesh01=true};local stray={};for _,p in ipairs(parts)do if not(known[p.Name]or p:GetAttribute('TearIndex'))then stray[#stray+1]=p.Name end end
 check(#stray==0,label..': every part is the root, the seal, a tear strip or the pouch ('..table.concat(stray,',')..')')
 -- the same pouch, part for part, as the plain pack of the same design
 local std=Visuals.Bag(opts.origin or CF(40,10,40),nil,1,nil,7,'Standard',1,size,'None')
 local same,why=sameSig(sig(bag),sig(std),false,'PackGeometry/ApprovedMesh01')
 check(same,label..': the same parts as the plain Standard pack: width, height, pivot, frame, seal and strips (only the pouch\'s depth is the flat one) ('..tostring(why)..')')
 local ratio=mesh.Size.Z/(std:FindFirstChild('ApprovedMesh01',true).Size.Z)
 check(near(mesh.Size.X,std:FindFirstChild('ApprovedMesh01',true).Size.X,1e-9)and near(mesh.Size.Y,std:FindFirstChild('ApprovedMesh01',true).Size.Y,1e-9)and near(ratio,Pouch.DepthShare,1e-9),label..': the pouch is the standard pouch\'s width and height and '..Pouch.DepthShare..' of its depth')
 check(near(scale,std:GetAttribute('VisualScale'),1e-9)and tostring(Visuals.Bounds(7,VERITY,size).Radius)==tostring(Visuals.Bounds(7,'Standard',size).Radius),label..': VisualScale and Bounds are the plain pack\'s')
 local d,r=cfDelta(inv(root.CFrame)*mesh.CFrame,tpl:GetAttribute('PackLocalFrame')*CF(0,0,0));local expect=tpl:GetAttribute('PackLocalFrame')
 check(near((inv(root.CFrame)*mesh.CFrame).Position.X,expect.Position.X*scale,1e-5)and near((inv(root.CFrame)*mesh.CFrame).Position.Y,expect.Position.Y*scale,1e-5)and near((inv(root.CFrame)*mesh.CFrame).Position.Z,expect.Position.Z*scale,1e-5),label..': the pouch sits at the template\'s PackLocalFrame (x scale)')
 std:Destroy()
 -- colour: pure yellow everywhere (None); the coat paints it like any pack (the Decals stay white)
 local c=Rules.PackMutations[coat]
 if coat=='None'then
  local pure,why2=0,''
  for _,p in ipairs(parts)do if p~=root then
   local want=p:IsA('MeshPart')and Art.Yellow or Art.Seal -- (the pouch is pure yellow, the seal and the 8 strips the slightly darker yellow)
   if rgb(p.Color)==rgb(want)and p.Material.Name=='SmoothPlastic'and p.Reflectance==0 and p.Transparency==0 and(not p:IsA('MeshPart')or p.TextureID=='')then pure+=1 else why2=why2..' '..p.Name end
  end end
  check(isYellow(mesh.Color)and rgb(Art.Seal)==230 and select(2,rgb(Art.Seal))==230 and select(3,rgb(Art.Seal))==0,label..': the pouch is exactly 255,255,0 and the seal yellow is 230,230,0 (a pure yellow, a little darker)')
  check(pure==#parts-1,label..': the pouch is 255,255,0 and the seal and strips the darker yellow, all SmoothPlastic, opaque, no texture ('..pure..'/'..(#parts-1)..why2..')')
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
-- 3b. NEVER SHAPED (the owner's pack shape variations, PackShapes151, never touch the Verity pack): one flat pouch whatever any roll, flag or stale attribute says -------------------
do
 local Shapes=W.module('PackShapes151');Shapes.Reset();Shapes.Config.Enabled=true;Shapes.SetMode('auto')
 check(Shapes.Applies(VERITY)==false and Shapes.Applies('Pack03')==true,'PackShapes151.Applies: the Verity pack takes no shape (an ordinary pack does)')
 local rolls=0;for k=1,60 do if Shapes.Roll(VERITY,k/61)~=nil then rolls+=1 end end;for _,mode in ipairs({1,3,6})do Shapes.SetMode(mode);if Shapes.Roll(VERITY)~=nil then rolls+=1 end end;Shapes.SetMode('auto')
 check(rolls==0,'a Verity pack never rolls a shape (60 dice, and every forced shape): '..rolls..' rolls')
 local calls0=Mock.calls
 local plain=H.ground(7,VERITY,1,'None');local plainSig=sig(plain);local base=plain:FindFirstChild('ApprovedMesh01',true)
 for shape=1,6 do
  local viaRecord=H.ground(7,VERITY,1,'None',nil,shape)            -- Visuals.Bag(...shape): gated by Applies
  check(viaRecord:GetAttribute('PackShape')==nil and viaRecord:GetAttribute('PackShapeShown')==nil and sameSig(sig(viaRecord),plainSig),'a Verity pack handed shape '..shape..' by its record is the same flat pouch, with no PackShape on it')
  local bag=Visuals.Bag(CF(0,0,0),nil,1,nil,7,'Standard',1,1,'None');bag:SetAttribute('BagVariant',VERITY)
  for _,d in ipairs(bag:GetChildren())do if d.Name=='PackGeometry'then d:Destroy()end end
  for _,a in ipairs({'CompactPackReady','CompactPackPartCount'})do bag:SetAttribute(a,nil)end
  bag:SetAttribute('PackShape',shape);Art.Build(bag,function()return true end)         -- a stale attribute on the bag itself
  check(bag:GetAttribute('VerityPouch')==true and bag:GetAttribute('PackShapeShown')==nil and sameSig(sig(bag),sig(Visuals.Bag(CF(0,0,0),nil,1,nil,7,VERITY,1,1,'None')),false),'a Verity bag that says PackShape '..shape..' is built as the same flat pouch (the attribute is ignored)')
  local flagged=H.picture(7,VERITY,1,'None',shape,true);check(flagged:GetAttribute('DefaultPackShape')==true and flagged:GetAttribute('PackShape')==nil and sameSig(sig(flagged),sig(H.picture(7,VERITY,1,'None')),false),'a picture flagged DefaultPackShape that rolled '..shape..' is the same flat pouch');flagged:Destroy()
  viaRecord:Destroy();bag:Destroy()
 end
 for _,rig in ipairs({'R15','R6'})do
  local held,char=H.held(7,VERITY,1,'None',rig,4);local plainHeld,char2=H.held(7,VERITY,1,'None',rig)
  check(held:GetAttribute('PackShape')==nil and held:GetAttribute('VerityPouch')==true and sameSig(sig(held),sig(plainHeld),false),'held '..rig..': handed shape 4 it is the same flat pouch, with no PackShape on it');held:Destroy();char:Destroy();plainHeld:Destroy();char2:Destroy()
 end
 local market=H.market(7,VERITY,5);local mkt=market:FindFirstChild('ApprovedMesh01',true);check(mkt and mkt:GetAttribute('Flat')~=false and market:GetAttribute('PackShape')==nil and #decalsOf(market)==2,'the market / shop / Index picture is the flat pouch with both Decals');market:Destroy()
 local mystery,holder=H.mystery(7,VERITY,false,3);check(mystery:GetAttribute('PackShape')==nil and mystery:GetAttribute('VerityPouch')==true,'the mystery pedestal\'s Ready Verity pack is the flat pouch');holder:Destroy()
 local vp,vf=H.viewport(7,VERITY,1,'None',nil,2);check(vp:GetAttribute('PackShape')==nil and vp:GetAttribute('VerityPouch')==true and #decalsOf(vp)==2,'a viewport preview of a Verity pack is the flat pouch with both Decals');vf:Destroy()
 check(Mock.calls==calls0 and Shapes.Status().Requested==0 and Shapes.Status().Baked==0,'nothing was baked for any shape: the asset route was never asked, PackShapes151 requested 0 pairs ('..tostring(Shapes.Status().Requested)..')')
 plain:Destroy()
 -- LEFTOVER DESIGN: whatever an (older / hand-edited) template Model carries besides the flat pouch never reaches the pack: an appearance, a Storm print Decal, an emblem part
 do
  local part=neutral.ApprovedMesh01;local sa=R.new('SurfaceAppearance');sa.Name='StormNormals';sa.Parent=part
  local print_=R.new('Decal');print_.Name='StormPrint';print_.Texture='rbxassetid://1';print_.Face=R.Enum.NormalId.Front;print_.Parent=part
  local tex=R.new('Texture');tex.Name='StormTexture';tex.Parent=part
  local emblem=part:Clone();emblem.Name='ApprovedMesh02';emblem.Color=R.Color3.fromRGB(10,10,80);emblem:SetAttribute('PackLocalFrame',part:GetAttribute('PackLocalFrame'));emblem.Parent=neutral;neutral:SetAttribute('MeshCount',2)
  local dirty=H.ground(7,VERITY,1,'None');local clean=plainSig
  local mesh=dirty:FindFirstChild('ApprovedMesh01',true)
  local strays=0;for _,d in ipairs(dirty:GetDescendants())do if d.Name:find('Storm',1,true)or d.Name=='ApprovedMesh02'or d._class=='SurfaceAppearance'or d._class=='Texture'then strays+=1 end end
  check(strays==0 and#decalsOf(dirty)==2 and mesh and mesh.Parent and#mesh.Parent:GetChildren()==1 and dirty:GetAttribute('CompactPackPartCount')==11,'a template that still carries an appearance, a Storm print Decal, a texture and an emblem part: none of it reaches the pack ('..strays..' stray; the pack is the pouch, the seal and the 8 strips: 11 parts)')
  check(sameSig(sig(dirty),clean,false),'... and the pack is exactly the clean one')
  dirty:Destroy();sa:Destroy();print_:Destroy();tex:Destroy();emblem:Destroy();neutral:SetAttribute('MeshCount',1)
 end
 -- an ordinary pack still takes its shape (the exclusion is the Verity pack alone)
 local ord=H.ground(7,'Pack06',1,'None',nil,3);check(ord:GetAttribute('PackShape')==3,'(control) an ordinary pack still carries its shape 3');ord:Destroy()
 Shapes.Reset();Shapes.Config.Enabled=false
end
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
  local meshes,pouchYellow,sealYellow,visible=0,0,0,0
  for _,d in ipairs(v:GetDescendants())do if d:IsA('BasePart')then
   if d:IsA('MeshPart')then meshes+=1 end
   if d.Transparency<1 then
    visible+=1
    if d.Material.Name=='SmoothPlastic'then if d:IsA('MeshPart')and isYellow(d.Color)then pouchYellow+=1 elseif not d:IsA('MeshPart')and rgb(d.Color)==rgb(Art.Seal)then sealYellow+=1 end end
   end
  end end
  return meshes,pouchYellow,sealYellow,visible
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
  local meshes,pouchYellow,sealYellow,visible=look(v);local ds=decalsOf(v)
  check(meshes==1 and pouchYellow==1 and sealYellow==9 and visible==10,('(b) the hotbar / Bag / Index picture is the flat pouch: %d MeshPart (%d pure yellow), %d visible parts, the seal and 8 strips the darker yellow (%d)'):format(meshes,pouchYellow,visible,sealYellow))
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
 -- (e) a Verity pack that carries a PackShape (an older record), or is flagged DefaultPackShape (the shop / Index / dialog / market pictures), draws the SAME flat pouch: never a shape
 client();local flat=neutral.ApprovedMesh01
 for i,kind in ipairs({'rolled','flagged'})do
  local t=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack '..kind)
  if kind=='rolled'then t:SetAttribute('PackShape',3)else t:SetAttribute('DefaultPackShape',true)end
  local h=holder(200+i*70);Pic.Show(h,t,1);for _=1,300 do W.frames(1)end
  local vv=view(h)
  if check(vv~=nil,'(e) a '..kind..' Verity picture draws')then
   local pm;for _,d in ipairs(vv:GetDescendants())do if d:IsA('MeshPart')then pm=d end end
   check(pm~=nil and pm.Baked==flat.Baked and#decalsOf(vv)==2 and select(1,look(vv))==1,'(e) ... it is the server\'s flat pouch with both Decals (one MeshPart), not a shape')
  end
 end
 server()
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
 -- a template that is not the flat pouch (no Flat mark: an old Model in the folder) is never used: the sachet
 neutral:SetAttribute('Flat',nil);local notFlat=sachetPack();check(notFlat:GetAttribute('VerityPouch')==nil and notFlat:FindFirstChild('VerityFace',true)~=nil,'a template without the Flat mark is not used: the Verity pack is the sachet');notFlat:Destroy();neutral:SetAttribute('Flat',true)
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
