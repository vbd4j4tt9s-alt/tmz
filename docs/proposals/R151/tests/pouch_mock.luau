--!nocheck
-- R151: a mock of the EditableMesh bake route VerityPouch151 and PackShapes151 use (AssetService:CreateEditableMeshAsync / CreateDataModelContentAsync /
-- CreateMeshPartAsync, Content.fromUri / fromObject, Enum.CreateContentResult) on the Roblox mock, with switches for every way the real thing can fail.
--   local P=require('./pouch_mock')(W)
--   P.mode = 'ok' | 'denied' (CreateEditableMeshAsync errors: no permission) | 'no_vertices' | 'setcolor_error' | 'color_stuck' (SetColor does nothing: a
--            dark colour survives) | 'content_fails' (CreateDataModelContentAsync does not succeed) | 'meshpart_fails' | 'size_mismatch' (the baked mesh is
--            another size) | 'second_fails' (the 2nd mesh of a template cannot be loaded) | 'no_positions' (GetPosition / SetPosition are not there) |
--            'no_normals' (the face / normal API is not there) | 'hang' (CreateEditableMeshAsync never returns)
--   P.api(false) removes AssetService:CreateEditableMeshAsync AND CreateEditableMesh altogether (a world without EditableMesh: an expected fallback, never a warning); P.api(true) puts it back (P.reset does)
--   P.slow       true: CreateEditableMeshAsync and CreateDataModelContentAsync yield until P.resume() (a real download / bake); P.waiting = the yielded threads
--   P.uris       the Content URIs asked for, in order            P.alive    EditableMeshes created and not yet destroyed (a leak if > 0 when idle)
--   P.maxAlive   the most EditableMeshes alive at once            P.created  EditableMeshes created      P.baked  MeshParts made (P.bakedAlive: not destroyed)
--   P.colorsAtBake  for each CreateDataModelContentAsync: the number of vertex colours that were NOT white (must be 0 for the Verity bake)
--   R152: the GENERATED route (VerityPouch151: AssetService:CreateEditableMesh() -> AddVertex / AddNormal / AddColor / AddUV / AddTriangle / SetFaceNormals / SetFaceColors / SetFaceUVs, no asset loaded) records
--            every call on the mesh (_pos positions, _normals, _colors, _uvs, F triangles, FN / FC / FUV per face); extra modes: 'nil_editable' (CreateEditableMesh returns nil: no mesh memory),
--            'addvertex_error' (AddVertex fails), 'no_uv' (AddUV / SetFaceUVs are not there). P.generated = the number of generated meshes made; mode 'denied' makes CreateEditableMesh error too.
--   P.vertices   vertices per mesh (a 10 x 15 x n lattice filling the template part's Size box, offset by P.offset: the mesh's own origin is not its centre)
--   P.meshes     every EditableMesh made (their positions / colours / normals stay readable after Destroy)       P.sets  {Position, Normal, Color, ColorAlpha, UV}
return function(W)
 local R=W.R
 local V3=R.Vector3.new
 local P={mode='ok',slow=false,waiting={},uris={},alive=0,maxAlive=0,created=0,baked=0,bakedAlive=0,colorsAtBake={},vertices=1800,calls=0,meshes={},
  sets={Position=0,Normal=0,Color=0,ColorAlpha=0,UV=0},offset=V3(.21,-.13,.07)}
 local AS=W.service('AssetService')
 local function sizeOf(uri)
  local assets=W.RS:FindFirstChild('SeedPackMeshAssets')
  for _,model in ipairs(assets and assets:GetChildren()or{})do for _,part in ipairs(model:GetChildren())do if part.MeshId==uri and part.Size then return part.Size end end end
  return V3(1.97,2.06,1.004)
 end
 local function mesh(uri)
  local size=sizeOf(uri);local n=P.vertices
  local colors,pos,alpha,normals,init={},{},{},{},{}
  local nx,ny=10,15;local nz=math.max(2,math.ceil(n/(nx*ny)))
  for i=1,n do
   local ix=(i-1)%nx;local iy=math.floor((i-1)/nx)%ny;local iz=math.floor((i-1)/(nx*ny))
   pos[i]=V3(size.X*(ix/(nx-1)-.5)+P.offset.X,size.Y*(iy/(ny-1)-.5)+P.offset.Y,size.Z*(iz/(nz-1)-.5)+P.offset.Z)
   init[i]=pos[i]
   colors[i]=R.Color3.fromRGB(20+(i*37)%200,15+(i*11)%120,30+(i*53)%220) -- the print: dark navy, orange, crimps
   alpha[i]=1
   local d=pos[i]-P.offset;normals[i]=d.Magnitude>1e-9 and d.Unit or V3(0,0,1)
  end
  local m={_colors=colors,_pos=pos,_init=init,_alpha=alpha,_normals=normals,_dead=false,Uri=uri,Size=size}
  function m:GetVertices()local v={};if P.mode=='no_vertices'then return v end;for i=1,#self._pos do v[i]=i end;return v end
  function m:GetColors()local c={};for i=1,#self._colors do c[i]=i end;return c end
  function m:GetColor(i)return self._colors[i]end
  function m:SetColor(i,c)
   if P.mode=='setcolor_error'then error('EditableMesh:SetColor is not available',2)end
   P.sets.Color+=1
   if P.mode=='color_stuck'and i%7==0 then return end
   self._colors[i]=c
  end
  function m:SetColorAlpha(i,a)P.sets.ColorAlpha+=1;self._alpha[i]=a end
  function m:GetPosition(i)
   if P.mode=='no_positions'then error('EditableMesh:GetPosition is not available',2)end
   return self._pos[i]
  end
  function m:SetPosition(i,v)
   if P.mode=='no_positions'then error('EditableMesh:SetPosition is not available',2)end
   P.sets.Position+=1;self._pos[i]=v
  end
  if P.mode~='no_normals'then
   function m:GetFaces()local f={};for i=1,math.floor(#self._pos/3)do f[i]=i end;return f end
   function m:GetFaceVertices(f)return{3*f-2,3*f-1,3*f}end
   function m:GetFaceNormals(f)return{3*f-2,3*f-1,3*f}end
   function m:GetNormal(id)return self._normals[id]end
   function m:SetNormal(id,v)P.sets.Normal+=1;self._normals[id]=v end
  end
  function m:Destroy()if not self._dead then self._dead=true;P.alive-=1 end end
  P.created+=1;P.alive+=1;P.maxAlive=math.max(P.maxAlive,P.alive);P.meshes[#P.meshes+1]=m;return m
 end

 -- R152: the generated route
 P.generated=0
 local function generated()
  local m={Generated=true,_pos={},_normals={},_colors={},_alpha={},_uvs={},F={},FN={},FC={},FUV={},_dead=false}
  function m:AddVertex(p)if P.mode=='addvertex_error'then error('EditableMesh:AddVertex failed',2)end;self._pos[#self._pos+1]=p;return #self._pos end
  function m:AddNormal(n)self._normals[#self._normals+1]=n;return #self._normals end
  function m:AddColor(c,a)P.sets.Color+=1;self._colors[#self._colors+1]=c;self._alpha[#self._alpha+1]=a;return #self._colors end
  if P.mode~='no_uv'then
   function m:AddUV(uv)self._uvs[#self._uvs+1]=uv;P.sets.UV+=1;return #self._uvs end
   function m:SetFaceUVs(f,ids)self.FUV[f]=ids end
  end
  function m:AddTriangle(a,b,c)self.F[#self.F+1]={a,b,c};return #self.F end
  function m:SetFaceNormals(f,ids)self.FN[f]=ids end
  function m:SetFaceColors(f,ids)self.FC[f]=ids end
  function m:Destroy()if not self._dead then self._dead=true;P.alive-=1 end end
  P.generated+=1;P.created+=1;P.alive+=1;P.maxAlive=math.max(P.maxAlive,P.alive);P.meshes[#P.meshes+1]=m;return m
 end
 function AS.CreateEditableMesh(_)
  P.calls+=1
  if P.mode=='denied'then error('EditableMesh creation is not allowed in this experience',2)end
  if P.mode=='nil_editable'then return nil end
  return generated()
 end
 local createGenerated=AS.CreateEditableMesh
 function AS.CreateEditableMeshAsync(_,content)
  P.calls+=1
  P.uris[#P.uris+1]=content and content.Uri
  if P.mode=='denied'then error('Failed to load mesh: no permission to read '..tostring(content and content.Uri)..' as an EditableMesh',2)end
  if P.mode=='second_fails'and P.calls>=2 then error('second mesh not available',2)end
  if P.mode=='hang'then coroutine.yield();return nil end
  if P.slow then P.waiting[#P.waiting+1]=coroutine.running();coroutine.yield()end
  return mesh(content.Uri)
 end
 local createEditable=AS.CreateEditableMeshAsync
 function P.api(on)AS.CreateEditableMeshAsync=on and createEditable or nil;AS.CreateEditableMesh=on and createGenerated or nil end
 function P.resume()
  local co=table.remove(P.waiting,1);if co then local ok,e=coroutine.resume(co);if not ok then error(e,0)end;return true end
  return false
 end
 function AS.CreateDataModelContentAsync(_,content)
  if P.slow then P.waiting[#P.waiting+1]=coroutine.running();coroutine.yield()end -- (turning an EditableMesh into content yields too: the mesh is alive meanwhile)
  local m=content.Object;local dark=0
  if m.Generated then -- (a face corner with no colour, or a colour that is not white, would show in the baked mesh)
   for f=1,#m.F do local ids=m.FC[f];if not ids or #ids~=3 then dark+=1 else for _,id in ipairs(ids)do local c=m._colors[id];if not(c and c.R>.999 and c.G>.999 and c.B>.999)then dark+=1 end end end end
  else
   for _,c in ipairs(m._colors)do if not(c.R>.999 and c.G>.999 and c.B>.999)then dark+=1 end end
  end
  P.colorsAtBake[#P.colorsAtBake+1]=dark
  if P.mode=='content_fails'then return R.Enum.CreateContentResult.Failure,nil end
  return R.Enum.CreateContentResult.Success,{__type='Content',Baked=m}
 end
 function AS.CreateMeshPartAsync(_,content)
  if P.mode=='meshpart_fails'then error('CreateMeshPartAsync failed: out of mesh memory',2)end
  local part=R.new('MeshPart');P.baked+=1;P.bakedAlive+=1
  -- the mesh's own size: the bounding box of its vertices (what the engine reports as MeshSize)
  local m=content.Baked;local lo,hi
  for _,p in ipairs(m._pos)do
   if not lo then lo=V3(p.X,p.Y,p.Z);hi=V3(p.X,p.Y,p.Z)
   else lo=V3(math.min(lo.X,p.X),math.min(lo.Y,p.Y),math.min(lo.Z,p.Z));hi=V3(math.max(hi.X,p.X),math.max(hi.Y,p.Y),math.max(hi.Z,p.Z))end
  end
  part.MeshSize=(hi-lo)*(P.mode=='size_mismatch'and 1.1 or 1)
  part.MeshId='';part.Baked=m
  part.Destroying:Connect(function()P.bakedAlive-=1 end) -- (Instance:Destroy fires Destroying once)
  return part
 end
 -- Content / Enum for the module's globals
 W.env.Content={fromUri=function(u)return{__type='Content',Uri=u}end,fromAssetId=function(i)return{__type='Content',Uri='rbxassetid://'..tostring(i)}end,fromObject=function(o)return{__type='Content',Object=o}end}
 function P.reset()
  P.api(true);P.mode='ok';P.slow=false;P.waiting={};P.uris={};P.alive=0;P.maxAlive=0;P.created=0;P.baked=0;P.bakedAlive=0;P.colorsAtBake={};P.calls=0;P.vertices=1800;P.meshes={};P.generated=0
  P.sets={Position=0,Normal=0,Color=0,ColorAlpha=0,UV=0}
 end
 return P
end
