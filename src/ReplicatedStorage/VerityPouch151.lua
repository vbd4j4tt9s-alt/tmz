-- R151 (owner: the Verity pack should be the standard chip-bag pouch, pure yellow, with Verity's face on it) / R152 (owner: "verity pack is also not flat for some reason and
-- there is some leftover design"). R151 copied the standard pouch's uploaded mesh (Storm_02) and whitened its vertex colours, but that mesh carries its print partly as
-- GEOMETRY (embossed relief at the corners and edges) and its belly is puffy, so the yellow pack still showed the leftover design and a Decal wrapped and bent round the curve.
-- R152 no longer copies the mesh. This module GENERATES a clean flat pouch at run time with EditableMesh (AssetService:CreateEditableMesh -> AddVertex / AddNormal / AddColor
-- / AddTriangle -> CreateDataModelContentAsync -> CreateMeshPartAsync, like FruitMeshes149 and ApprovedPlantMeshes), so there is no relief to flatten and no asset to load:
--  * Shape (Generate, pure data, tested): the template pouch's width and height (its MeshPart Size X / Y, so the outline and the seal / tear strips line up) and DepthShare of its
--    depth (a flat sachet: R149's was .56). Front and back are two exactly flat planes; the long edges are rounded (EdgeRadius); the top and bottom pinch in a smooth taper
--    (TaperHeight) to a crimped seal (CrimpHeight: a zig-zag, CrimpTeeth ridges, like a chip bag) that closes in a knife edge. Nothing else: no relief anywhere on the body.
--    The mesh is centred on its own origin with its bounding box exactly the pouch's Size, so the part sits on the template's PackLocalFrame like the standard pouch
--    (R153: its x / y and turn, but centred on the seam plane z = 0 where the seal and the strips are: SeamFrame below).
--  * Every vertex colour is white (one white colour on every face), so the part's Color (255,255,0) is the pack's colour. UVs are planar on each face (best effort); flat faces
--    are what make Verity's face Decals (VerityPackArt) projected on the Front and Back crisp and undistorted.
--  * Server, at start (ApprovedPlantsBootstrap): Prepare reads the Verity design's template from the live place (SeedPackRenderer.GetGeometry: Storm_02, the Standard design of
--    Verity's stage 7) only for its pouch part's Size and PackLocalFrame, generates and bakes the mesh, and puts ONE Model (a MeshPart named like the template's) in
--    ReplicatedStorage.VerityPouchTemplate151 (a Folder; attributes Finished / Ready / Failed / Reason / Key ...). The EditableMesh is destroyed on every path.
--  * Everyone: State() says whether the pack may use it. VerityPackArt builds the pack from it (exactly like a plain pack: same pouch width / height, frame, pivot, Bounds,
--    seal and strips; painted 255,255,0, Verity's face as Decals on the pouch) and falls back to the R149 plain-parts sachet (also flat) when the bake failed / was denied /
--    never ran / does not match the design. Whatever goes wrong is contained: every step is a pcall, a partial bake is destroyed, the result is a Failed folder with the reason
--    (one warn on the server), never an error in a pack build.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local M={Folder='VerityPouchTemplate151',Revision=152,
 LoadingSeconds=45,  -- a client waits this long (from its first question) for a bake that has not finished, then uses the sachet
 SizeTolerance=.02,  -- the baked mesh's own size may differ from the generated one by this share before the bake is refused
 -- the shape, in studs at scale 1
 DepthShare=.56,     -- thickness as a share of the template pouch's front-to-back size (flat: the R149 sachet was .56)
 EdgeRadius=.14,     -- the rounded long edges (never more than the half thickness)
 TaperHeight=.26,    -- where the body pinches in to the seal (a smooth S-curve), per end
 CrimpHeight=.09,    -- the crimped seal band at each end
 CrimpHalf=.02,      -- half the seal's thickness
 CrimpAmplitude=.025,-- how far the zig-zag ridges stand out of the seal's plane
 EdgeBevel=.012,     -- the last bit of each end closes in a knife edge
 Columns=72,         -- samples across the face (4 per ridge: CrimpTeeth = Columns / 4)
 Corner=6,           -- segments of each rounded corner
 TaperRows=8}        -- rows of the taper
-- R153 (owner: "parts are dislocated on packs": the yellow pouch held edge-on, its seal and tear strips off to one side and the top one stepped): the template's PackLocalFrame
-- is the centre of the STANDARD pouch mesh's bounding box, and that box is not centred on the pouch: its print stands out of the front (Storm_02: the coil relief reaches
-- z = -.549, the back print only .455), so the frame is .047 in front of the pouch's middle. Every design's pouch closes on the plane z = 0 of the pack (its crimp rows), and
-- the pack's BottomSeal and 8 TearStrips (SeedPackVisuals.Bag) are built on that plane. The generated pouch is symmetric, so it is centred THERE: the template's x / y and
-- turn, z = SeamZ. (Its knife edges then run into the seal and the strips, centred, as the standard pouch's crimps do.)
M.SeamZ=0
function M.SeamFrame(frame)return CFrame.new(frame.Position.X,frame.Position.Y,M.SeamZ)*frame.Rotation end
local WHITE=Color3.new(1,1,1)
local WAVE={[0]=0,1,0,-1} -- the seal's triangle wave, per column (period 4: neutral, ridge, neutral, groove)
local function ss(a,b,x)local t=math.clamp((x-a)/(b-a),0,1);return t*t*(3-2*t)end
-- The flat pouch as plain data, in studs, centred on its origin: {Vertices={{x,y,z}}, Normals={{x,y,z}} (one per vertex, smooth), Faces={{a,b,c}} (counter-clockwise from outside),
-- Extent={x,y,z} (the bounding box), Body (the half height up to which the faces are exactly flat planes at z = +-Half), Half (half the thickness), Rows}. `o`: shape constants to override (tests).
-- W / H / Dp: the pouch's width, height and thickness. Pure and deterministic.
function M.Generate(W,H,Dp,o)
 o=o and setmetatable(o,{__index=M})or M
 local a,h,h0=W/2,H/2,Dp/2
 local NX,NC,K=o.Columns,o.Corner,o.TaperRows
 local hc=math.min(o.CrimpHalf,h0*.5);local amp=o.CrimpAmplitude;local rc0=math.min(o.EdgeRadius,a*.5,h0*.9)
 local yEnd=h-o.CrimpHeight;local yb=yEnd-o.TaperHeight
 assert(NX%4==0 and NX>=8 and NC>=1 and K>=1 and yb>0,'[R152] the pouch shape does not fit its size')
 -- rows, bottom to top: {y, half thickness, ridge amplitude, welded (the closing knife edge: front and back are the same vertices)}
 local up={{yb,h0,0}}
 for k=1,K do local s=k/K;up[#up+1]={yb+o.TaperHeight*s,h0+(hc-h0)*ss(0,1,s),amp*ss(.2,1,s)}end
 up[#up+1]={h-o.EdgeBevel,hc,amp};up[#up+1]={h,0,amp,true}
 local rows={};for i=#up,1,-1 do local r=up[i];rows[#rows+1]={-r[1],r[2],r[3],r[4]}end;for _,r in ipairs(up)do rows[#rows+1]=r end
 local RING=2*NX+2+4*NC;local arcs,back,left=NX+2,NX+2+2*NC,2*NX+3+2*NC -- ring: front row (NX+1), front-right arc, back-right arc (NC each), back row (NX+1), back-left arc, front-left arc
 local V,ids={},{}
 local function ring(y,t,am,weld)
  local r=weld and 0 or math.min(rc0,t*.9);local xe=a-r;local pts={}
  local function arc(cx,cz,k0,k1,th0)for k=k0,k1 do local th=th0-k*math.pi/2/NC;pts[#pts+1]={cx+r*math.cos(th),y,cz+r*math.sin(th)}end end
  for i=0,NX do pts[#pts+1]={-xe+2*xe*i/NX,y,t+am*WAVE[i%4]}end
  arc(xe,t-r,1,NC,math.pi/2);arc(xe,-(t-r),0,NC-1,0)
  for j=0,NX do pts[#pts+1]={xe-2*xe*j/NX,y,-t+am*WAVE[(NX-j)%4]}end
  arc(-xe,-(t-r),1,NC,-math.pi/2);arc(-xe,t-r,0,NC-1,math.pi)
  return pts
 end
 for ri,row in ipairs(rows)do
  local pts=ring(row[1],row[2],row[3],row[4]);local id={}
  for p=1,RING do
   local at=p
   if row[4]then -- the knife edge: the back row, the corners and the walls reuse the front row's vertices
    if p>=left then at=1 elseif p>=back then at=NX+1-(p-back) elseif p>=arcs then at=NX+1 end
   end
   if at~=p then id[p]=id[at] else V[#V+1]=pts[p];id[p]=#V end
  end
  ids[ri]=id
 end
 local function pos(i)return V[i]end
 local F={}
 for ri=1,#rows-1 do for p=1,RING do
  local q=p%RING+1;local A,Bq,C,D=ids[ri][p],ids[ri][q],ids[ri+1][q],ids[ri+1][p]
  for _,t in ipairs({{A,Bq,C},{A,C,D}})do
   if t[1]~=t[2]and t[2]~=t[3]and t[1]~=t[3]then
    local x,y,z=pos(t[1]),pos(t[2]),pos(t[3])
    local ux,uy,uz=y[1]-x[1],y[2]-x[2],y[3]-x[3];local vx,vy,vz=z[1]-x[1],z[2]-x[2],z[3]-x[3]
    local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
    if nx*nx+ny*ny+nz*nz>1e-18 then F[#F+1]=t end
   end
  end
 end end
 -- smooth normals: the area-weighted mean of the faces round a vertex (exactly +-Z in the middle of a flat face)
 local N={};for i=1,#V do N[i]={0,0,0}end
 for _,t in ipairs(F)do
  local x,y,z=pos(t[1]),pos(t[2]),pos(t[3])
  local ux,uy,uz=y[1]-x[1],y[2]-x[2],y[3]-x[3];local vx,vy,vz=z[1]-x[1],z[2]-x[2],z[3]-x[3]
  local nx,ny,nz=uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx
  for _,i in ipairs(t)do local n=N[i];n[1]+=nx;n[2]+=ny;n[3]+=nz end
 end
 for i,n in ipairs(N)do local m=math.sqrt(n[1]*n[1]+n[2]*n[2]+n[3]*n[3]);if m>0 then N[i]={n[1]/m,n[2]/m,n[3]/m}else N[i]={0,1,0}end end
 return{Vertices=V,Normals=N,Faces=F,Extent={W,H,Dp},Body=yb,Half=h0,Rows=#rows,Width=W,Height=H,Radius=rc0,Teeth=NX/4}
end
local function folder()
 local f=RS:FindFirstChild(M.Folder)
 if not f and Run:IsServer()then f=Instance.new('Folder');f.Name=M.Folder;f:SetAttribute('Finished',false);f:SetAttribute('Ready',false);f.Parent=RS end
 return f
end
if Run:IsServer()then folder()end -- the folder tells clients this server makes the pouch (no folder: this server does not, the sachet is used)
-- The design whose pouch Verity uses: its stage-7 Standard design (VerityCatalog.PackStage, Variant -> SeedPackRules.DesignKey), e.g. 'Storm_02'. Only its pouch part's Size and PackLocalFrame are read.
function M.Key()
 local Cat=require(script.Parent.VerityCatalog);local Rules=require(script.Parent.SeedPackRules)
 return Rules.DesignKey(Cat.PackStage,Cat.Variant)
end
local asked
-- 'Ready' (the flat pouch of `key` is there), 'Loading' (the server is still making it), 'Off' (use the sachet) and why.
function M.State(key)
 local f=RS:FindFirstChild(M.Folder)
 if not f then return 'Off','this server does not make the Verity pouch'end
 if f:GetAttribute('Finished')==true then
  if f:GetAttribute('Ready')~=true then return 'Off',tostring(f:GetAttribute('Reason')or'the bake failed')end
  local name=f:GetAttribute('Key')
  if key~=nil and key~=name then return 'Off','only '..tostring(name)..' is made'end
  if not(typeof(name)=='string'and f:FindFirstChild(name))then
   -- (the attribute can reach a client before the Model does)
   asked=asked or os.clock();if os.clock()-asked>M.LoadingSeconds then return 'Off','the flat pouch did not replicate'end
   return 'Loading'
  end
  return 'Ready'
 end
 asked=asked or os.clock()
 if os.clock()-asked>M.LoadingSeconds then return 'Off','the bake did not finish in time'end
 return 'Loading'
end
-- The flat pouch Model of `key` (a Model like the design's template, ONE MeshPart), or nil.
function M.Template(key)
 if M.State(key)~='Ready'then return nil end
 local f=RS:FindFirstChild(M.Folder);return f and f:FindFirstChild(f:GetAttribute('Key'))
end
local function sizeOf(part)
 local ok,size=pcall(function()return part.MeshSize end)
 if ok and typeof(size)=='Vector3'and size.X>0 and size.Y>0 and size.Z>0 then return size end
 return nil
end
-- The flat pouch MeshPart from the template's pouch part `source` (its Size X / Y and PackLocalFrame). Errors (the caller pcalls) with a reason; destroys the EditableMesh on every path.
local function bake(source)
 local Assets=game:GetService('AssetService');local editable,part
 local ok,why=xpcall(function()
  -- the API itself missing (a world without EditableMesh) is an expected fallback: the sachet, quietly (the folder says why)
  local okApi,method=pcall(function()return Assets.CreateEditableMesh end)
  if Content==nil or not okApi or type(method)~='function'then error('EditableMesh is not available in this environment (AssetService:CreateEditableMesh or Content is missing)',0)end
  local frame=source:GetAttribute('PackLocalFrame');assert(typeof(frame)=='CFrame','template mesh '..source.Name..' has no PackLocalFrame')
  frame=M.SeamFrame(frame) -- R153: on the seam plane, where the seal and the 8 tear strips are (not the standard mesh's box centre)
  local size=source.Size;assert(size.X>0 and size.Y>0 and size.Z>0,'template mesh '..source.Name..' has no size')
  local data=M.Generate(size.X,size.Y,size.Z*M.DepthShare)
  editable=Assets:CreateEditableMesh();assert(editable,'no EditableMesh (mesh memory is unavailable)')
  local v,n,work={},{},0
  local function pace()work+=1;if work%256==0 then task.wait()end end
  for i,p in ipairs(data.Vertices)do local q=data.Normals[i];v[i]=editable:AddVertex(Vector3.new(p[1],p[2],p[3]));n[i]=editable:AddNormal(Vector3.new(q[1],q[2],q[3]));pace()end
  local white=editable:AddColor(WHITE,1) -- ONE white colour on every corner of every face: nothing of a print can survive
  -- planar UVs (best effort; the Decals are projected, so they do not need them): u runs along the face as it is read from outside (Front is the -Z face), v up
  local uvFront,uvBack,haveUv={},{},pcall(function()return editable.AddUV end)
  local function uv(i,back)
   local cache=back and uvBack or uvFront;local id=cache[i]
   if not id then local p=data.Vertices[i];local u=.5+p[1]/data.Width;id=editable:AddUV(Vector2.new(back and u or 1-u,.5+p[2]/data.Height));cache[i]=id end
   return id
  end
  for i,t in ipairs(data.Faces)do
   local face=editable:AddTriangle(v[t[1]],v[t[2]],v[t[3]])
   editable:SetFaceNormals(face,{n[t[1]],n[t[2]],n[t[3]]});editable:SetFaceColors(face,{white,white,white})
   if haveUv then pcall(function()
    local back=(data.Vertices[t[1]][3]+data.Vertices[t[2]][3]+data.Vertices[t[3]][3])>=0 -- the +Z half (Back)
    editable:SetFaceUVs(face,{uv(t[1],back),uv(t[2],back),uv(t[3],back)})
   end)end
   pace()
  end
  local result,content=Assets:CreateDataModelContentAsync(Content.fromObject(editable))
  assert(result==Enum.CreateContentResult.Success,'could not bake the flat pouch mesh: '..tostring(result))
  part=Assets:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
  assert(part,'no MeshPart for the flat pouch')
  -- the baked mesh must be the mesh generated: its own (unscaled) size has to match, or the Size below would stretch it
  local own=sizeOf(part)
  if own then
   for i,axis in ipairs({'X','Y','Z'})do assert(math.abs(own[axis]-data.Extent[i])<=M.SizeTolerance*data.Extent[i]+1e-4,'the baked pouch is not the mesh generated ('..axis..' '..own[axis]..' vs '..data.Extent[i]..')')end
  end
  part.Name=source.Name;part.Size=Vector3.new(data.Extent[1],data.Extent[2],data.Extent[3]);part.Color=WHITE;part.Material=Enum.Material.SmoothPlastic;part.TextureID=''
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part:SetAttribute('PackLocalFrame',frame);part:SetAttribute('Flat',true);part:SetAttribute('VertexCount',#data.Vertices);part:SetAttribute('TriangleCount',#data.Faces)
 end,debug.traceback)
 if editable then pcall(function()editable:Destroy()end)end
 if not ok then if part then pcall(function()part:Destroy()end)end;error(tostring(why),0)end
 return part
end
local preparing=false
-- Server only. Makes the Verity design's flat pouch once per server (later calls wait for the first and return its answer); returns true when ready.
function M.Prepare()
 assert(Run:IsServer(),'The Verity pouch is made on the server.')
 local f=folder()
 while preparing do task.wait()end
 if f:GetAttribute('Finished')==true then return f:GetAttribute('Ready')==true end
 preparing=true;local started=os.clock();local key=M.Key();local made={}
 local ok,why=pcall(function()
  local template=require(script.Parent.SeedPackRenderer).GetGeometry(key)
  assert(template,'the template '..key..' is not in SeedPackMeshAssets')
  local sources={};for _,p in ipairs(template:GetChildren())do if p:IsA('MeshPart')then sources[#sources+1]=p end end
  assert(#sources>0 and #sources==template:GetAttribute('MeshCount'),'the template '..key..' is not a complete pack template')
  table.sort(sources,function(x,y)return x.Name<y.Name end)
  -- the pouch is the template's first MeshPart (ApprovedMesh01, the pack's body); any further part of the design (Storm_02 has none) is NOT part of the Verity pack
  local model=Instance.new('Model');model.Name=key;made[#made+1]=model
  model:SetAttribute('MeshBakeVersion',template:GetAttribute('MeshBakeVersion'));model:SetAttribute('MeshCount',1)
  local part=bake(sources[1]);part.Parent=model
  model:SetAttribute('Neutral',true);model:SetAttribute('Flat',true)
  model.Parent=f -- the Model first, then the attributes that say it is ready: a client never sees Ready without it
  f:SetAttribute('Key',key);f:SetAttribute('VertexCount',part:GetAttribute('VertexCount'));f:SetAttribute('TriangleCount',part:GetAttribute('TriangleCount'));f:SetAttribute('MeshCount',1);f:SetAttribute('Flat',true);f:SetAttribute('Revision',M.Revision)
 end)
 f:SetAttribute('BakeSeconds',os.clock()-started)
 if ok then f:SetAttribute('Ready',true);f:SetAttribute('Failed',false);f:SetAttribute('Finished',true)
 else
  for _,m in ipairs(made)do pcall(function()m:Destroy()end)end
  f:SetAttribute('Ready',false);f:SetAttribute('Failed',true);f:SetAttribute('Reason','the flat Verity pouch could not be made: '..tostring(why):match('^[^\n]*'));f:SetAttribute('Finished',true)
  if not tostring(why):find('EditableMesh is not available in this environment',1,true)then warn('[R152 Verity pouch] the Verity pack keeps its plain-parts sachet. '..tostring(why):match('^[^\n]*'))end
 end
 preparing=false
 return ok
end
return M
