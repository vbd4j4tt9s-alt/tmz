-- R151 (owner: "make pack shape variations in blender; the pack shape will still be a chip shape but will be slightly different"): six gentle variations of
-- the chip-bag pouch, applied to the owner's own pouch meshes at run time so every design keeps its print.
--  * The 42 designs' prints live in each pouch mesh's VERTEX COLOURS, so a brand-new uploaded mesh per shape would lose them. A variation is instead a smooth
--    deformation FIELD over the design's normalised box (u, v, w = x, y, z of the pack-local box, each -1..1; the same field is built and drawn in Blender:
--    docs/proposals/R151/blender/pack_shapes.py writes the samples tests/pack_shape_samples.luau, which the test compares with Field below). A field only
--    scales x and z by a factor that depends on (u, v, w); y never moves, and the top / bottom 6% (the crimps, where the seal and the 8 tear strips sit) are
--    untouched, so the pivot, the bottom line, the seal and the strips stay exactly where they are. Nothing grows by more than 5%.
--  * Each design gets ONE variation, by its name (Assign): the 6 tiers of a biome walk through the six variations from a per-biome start, so neighbouring
--    tiers always differ and every context (ground, held, hotbar / Bag / Index / shop pictures, opening copy, pedestal, viewports) builds the same one.
--  * The bake (per side, lazily, at the first pack of a design): AssetService:CreateEditableMeshAsync(the template's own MeshId) -> SetPosition of every
--    vertex (colours, UVs stay) -> CreateMeshPartAsync, then the EditableMesh is destroyed; ONE mesh at a time. The baked MeshPart replaces the template's
--    inside a Model kept in memory (never parented), SeedPackRenderer.Build clones it exactly like the place's own. Any failure (no permission, no vertices,
--    too many vertices, a size that is not the mesh's, a time-out) leaves that design on today's mesh, and says why in the status folder.
--  * Switches: Config.Enabled / Config.Force here, and the owner's /test packshape <1-6|off|auto> (attributes Off / Force on the status folder).
--  * Status (server, replicated): ReplicatedStorage.PackShapeTemplates151 attributes Ready (on and nothing failed), FailureCount, BakedCount, Requested,
--    Pending, Mode, Vertices, LastFailure. A client keeps the same numbers in M.Status().
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local M={Folder='PackShapeTemplates151',Revision=151,Count=6,
 Names={'Pillow','Hourglass','Pear','Top-heavy','Shoulders','Flat'},
 Config={
  Enabled=true,        -- false: every design keeps today's mesh
  Force=nil,           -- 1..6: every design takes that variation (testing)
  WaitSeconds=20,      -- a SERVER building a pack waits at most this long for the design's first bake (a client never waits: ItemPictures retries)
  LoadingSeconds=60,   -- a bake that has not finished this long after it was asked for is given up on (that design keeps today's mesh)
  MaxVertices=60000,   -- a mesh with more vertices than this is not reshaped
  MaxTotalVertices=1500000, -- memory cap: the reshaped meshes of one side never hold more vertices than this
  SizeTolerance=.02,   -- the baked mesh's own size may differ from the deformed vertices' by this share
 }}
-- The field --------------------------------------------------------------------------------------------------------------------------------------
local function clamp01(x)return x<0 and 0 or x>1 and 1 or x end
local function ss(a,b,x)local t=clamp01((x-a)/(b-a));return t*t*(3-2*t)end
local function bump(x,c,s)local d=(x-c)/s;return math.exp(-d*d)end
local function body(v)return 1-ss(.80,.94,math.abs(v))end                 -- 1 in the body, 0 in the crimps (|v| >= .94)
local function shoulder(v)return ss(.45,.80,math.abs(v))*body(v)end
-- x and z scale factors of each variation at (u, v, w): u' = u * sx, w' = w * sz, v' = v
local scales={
 function(u,v,w)local b=body(v)*(1-v*v);return 1-.04*b,1+.05*b end,                                  -- 1 Pillow: puffier, a little narrower
 function(u,v,w)local b=body(v);return 1-.09*b*bump(v,0,.5),1+.03*b*bump(v,0,.6) end,                -- 2 Hourglass: slimmer waist
 function(u,v,w)local g=body(v)*v;return 1-.05*g,1-.03*g end,                                        -- 3 Pear: fuller at the bottom
 function(u,v,w)local g=body(v)*v;return 1+.05*g,1+.03*g end,                                        -- 4 Top-heavy: fuller at the top
 function(u,v,w)return 1-.08*ss(.45,.85,math.abs(u))*shoulder(v),1 end,                              -- 5 Shoulders: the corners below each crimp rounded off
 function(u,v,w)local b=body(v);return 1+.02*b*(1-v*v),1-.15*b*bump(v,0,.75)*(1-.3*u*u) end,         -- 6 Flat: a flatter belly
}
function M.Scales(id,u,v,w)return scales[id](u,v,w)end
-- The moved point: (u', v', w') of (u, v, w) for variation `id`.
function M.Field(id,u,v,w)
 local sx,sz=scales[id](u,v,w)
 return u*sx,v,w*sz
end
-- Assignment: by the design's NAME (Biome_NN). Tiers 1..6 of a biome take consecutive variations (so neighbours differ) from a start that depends on the
-- biome's name; a name that is not Biome_NN takes the hash of the whole name.
local function hash(s)local h=11;for i=1,#s do h=(h*37+string.byte(s,i))%1000003 end;return h end
function M.Assign(key)
 key=tostring(key or'')
 local biome,tier=key:match('^(%a+)_(%d+)$')
 if biome then return((tonumber(tier)-1+hash(biome))%M.Count)+1 end
 return hash(key)%M.Count+1
end
-- Modes ------------------------------------------------------------------------------------------------------------------------------------------
local lastMode
local listeners={}
-- 'off', 1..6 (forced) or 'auto' (each design its own): the status folder's attributes (the owner's command) over Config.
function M.Mode()
 local off=M.Config.Enabled==false;local force=M.Config.Force
 local f=RS:FindFirstChild(M.Folder)
 if f then
  if f:GetAttribute('Off')==true then off=true end
  local n=f:GetAttribute('Force');if type(n)=='number'and n>=1 and n<=M.Count and n%1==0 then force=n end
 end
 if off then return'off'end
 if type(force)=='number'and force>=1 and force<=M.Count and force%1==0 then return force end
 return'auto'
end
function M.VariationOf(key)
 local mode=M.Mode()
 if mode=='off'then return nil end
 if mode=='auto'then return M.Assign(key)end
 return mode
end
-- Cache / queue ----------------------------------------------------------------------------------------------------------------------------------
local cache={}     -- [key] = {Id, Model, Vertices}
local failed={}    -- [key] = {Id, Reason}
local inflight={}  -- [key] = {Id, At}
local queue={}
local current
local stats={Baked=0,Failures=0,Requested=0,Vertices=0,Last=nil}
local warned=false
local function folder()
 local f=RS:FindFirstChild(M.Folder)
 if not f and Run:IsServer()then f=Instance.new('Folder');f.Name=M.Folder;f.Parent=RS end
 return f
end
local function pending()local n=0;for _ in pairs(inflight)do n+=1 end;return n end
local function publish()
 local f=RS:FindFirstChild(M.Folder);if not f then return end
 local server=Run:IsServer()
 local mode=M.Mode()
 local p=server and''or'Client'
 pcall(function()
  f:SetAttribute('Ready'..p,mode~='off'and stats.Failures==0)
  f:SetAttribute('FailureCount'..p,stats.Failures);f:SetAttribute('BakedCount'..p,stats.Baked);f:SetAttribute('Requested'..p,stats.Requested)
  f:SetAttribute('Pending'..p,pending());f:SetAttribute('Vertices'..p,stats.Vertices);f:SetAttribute('Mode'..p,tostring(mode))
  f:SetAttribute('Revision',M.Revision)
  if stats.Last then f:SetAttribute('LastFailure'..p,stats.Last)end
 end)
end
if Run:IsServer()then local f=folder();f:SetAttribute('Ready',true);f:SetAttribute('FailureCount',0);f:SetAttribute('BakedCount',0);f:SetAttribute('Requested',0);f:SetAttribute('Pending',0);f:SetAttribute('Mode','auto');f:SetAttribute('Revision',M.Revision)end
function M.Status()
 return{Mode=M.Mode(),Baked=stats.Baked,Failures=stats.Failures,Requested=stats.Requested,Pending=pending(),Vertices=stats.Vertices,LastFailure=stats.Last,Ready=M.Mode()~='off'and stats.Failures==0}
end
local function discard(entry)if entry and entry.Model then pcall(function()entry.Model:Destroy()end)end end
local function fire()for _,fn in ipairs(table.clone(listeners))do task.spawn(fn)end end
-- A mode change (the owner's command, a Config edit): reshaped templates of another variation are dropped, failures are forgotten, listeners (the item
-- pictures) are told.
local function syncMode()
 local mode=M.Mode()
 if mode==lastMode then return end
 local first=lastMode==nil;lastMode=mode
 for key,entry in pairs(cache)do if entry.Id~=M.VariationOf(key)then discard(entry);stats.Vertices-=entry.Vertices;cache[key]=nil end end
 table.clear(failed);stats.Failures=0;stats.Last=nil
 publish()
 if not first then fire()end
end
function M.OnChanged(fn)
 table.insert(listeners,fn)
 return function()local i=table.find(listeners,fn);if i then table.remove(listeners,i)end end
end
local hooked,watching
local function hook()
 if hooked then return end
 local f=RS:FindFirstChild(M.Folder)
 if f then hooked=true;f:GetAttributeChangedSignal('Force'):Connect(syncMode);f:GetAttributeChangedSignal('Off'):Connect(syncMode);syncMode()
 elseif not watching then watching=true;RS.ChildAdded:Connect(function(c)if c.Name==M.Folder then hook()end end)end
end
-- Geometry ---------------------------------------------------------------------------------------------------------------------------------------
local function meshParts(template)
 local list={};for _,p in ipairs(template:GetChildren())do if p:IsA('MeshPart')then list[#list+1]=p end end
 table.sort(list,function(a,b)return a.Name<b.Name end)
 return list
end
-- The design's box in the pack's frame: {Center, Half}, from every MeshPart's Size and PackLocalFrame.
function M.DesignBox(parts)
 local lo,hi=Vector3.new(math.huge,math.huge,math.huge),Vector3.new(-math.huge,-math.huge,-math.huge)
 for _,p in ipairs(parts)do
  local f=p:GetAttribute('PackLocalFrame');assert(typeof(f)=='CFrame','the mesh '..p.Name..' has no PackLocalFrame')
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=f*Vector3.new(p.Size.X*x,p.Size.Y*y,p.Size.Z*z)
   lo=Vector3.new(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=Vector3.new(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))
  end end end
 end
 assert(lo.X<hi.X and lo.Y<hi.Y and lo.Z<hi.Z,'the template has no volume')
 return{Center=Vector3.new((lo.X+hi.X)/2,(lo.Y+hi.Y)/2,(lo.Z+hi.Z)/2),Half=Vector3.new((hi.X-lo.X)/2,(hi.Y-lo.Y)/2,(hi.Z-lo.Z)/2)}
end
-- Moves every vertex of `editable` (vertex ids `vertices`, from the template mesh `source`) by variation `id` in the design's `box` and best-effort updates the
-- normals. Colours and UVs are not touched. A MeshPart sits on its mesh's bounding-box CENTRE, so when the field moves that centre (a part off the box's middle: its
-- bounding box shrinks towards it) the part's PackLocalFrame moves with it and the vertices stay exactly where the field put them. Returns {Size, Frame, Extent,
-- Moved, Normals, Out, Shift}: the new Size of the part (the studs per mesh unit stay what they were), the part's new PackLocalFrame (the template's own when the
-- centre did not move), the new extent of the mesh in mesh units, how many vertices moved, how many normals were set, the largest share any vertex went outside
-- the design's box and how far (studs) the part's centre moved.
function M.Deform(editable,vertices,source,box,id)
 local pos={};local lo,hi
 for i,vid in ipairs(vertices)do
  local p=editable:GetPosition(vid);pos[i]=p
  if not lo then lo=Vector3.new(p.X,p.Y,p.Z);hi=Vector3.new(p.X,p.Y,p.Z)
  else lo=Vector3.new(math.min(lo.X,p.X),math.min(lo.Y,p.Y),math.min(lo.Z,p.Z));hi=Vector3.new(math.max(hi.X,p.X),math.max(hi.Y,p.Y),math.max(hi.Z,p.Z))end
 end
 local ext=Vector3.new(hi.X-lo.X,hi.Y-lo.Y,hi.Z-lo.Z)
 assert(ext.X>0 and ext.Y>0 and ext.Z>0,'the mesh has no volume')
 local mid=Vector3.new((lo.X+hi.X)/2,(lo.Y+hi.Y)/2,(lo.Z+hi.Z)/2)
 local k=Vector3.new(source.Size.X/ext.X,source.Size.Y/ext.Y,source.Size.Z/ext.Z) -- studs per mesh unit
 local frame=source:GetAttribute('PackLocalFrame');local back=frame:Inverse()
 local c,h=box.Center,box.Half
 local function map(p) -- the deformed mesh-space point of a mesh-space point
  local q=frame*Vector3.new((p.X-mid.X)*k.X,(p.Y-mid.Y)*k.Y,(p.Z-mid.Z)*k.Z)
  local u2,_,w2=M.Field(id,(q.X-c.X)/h.X,(q.Y-c.Y)/h.Y,(q.Z-c.Z)/h.Z)
  local s=back*Vector3.new(c.X+u2*h.X,q.Y,c.Z+w2*h.Z)
  return Vector3.new(mid.X+s.X/k.X,mid.Y+s.Y/k.Y,mid.Z+s.Z/k.Z)
 end
 local new={};local nlo,nhi;local out=0
 for i,p in ipairs(pos)do
  local m=map(p);new[i]=m
  if not nlo then nlo=Vector3.new(m.X,m.Y,m.Z);nhi=Vector3.new(m.X,m.Y,m.Z)
  else nlo=Vector3.new(math.min(nlo.X,m.X),math.min(nlo.Y,m.Y),math.min(nlo.Z,m.Z));nhi=Vector3.new(math.max(nhi.X,m.X),math.max(nhi.Y,m.Y),math.max(nhi.Z,m.Z))end
  if i%1500==0 then task.wait()end
 end
 local nmid=Vector3.new((nlo.X+nhi.X)/2,(nlo.Y+nhi.Y)/2,(nlo.Z+nhi.Z)/2)
 for i,vid in ipairs(vertices)do
  local m=new[i];editable:SetPosition(vid,m)
  -- how far outside the design's box (in the pack's frame) the vertex ended up, as a share of the box's half size
  local q=frame*Vector3.new((m.X-mid.X)*k.X,(m.Y-mid.Y)*k.Y,(m.Z-mid.Z)*k.Z)
  out=math.max(out,(math.abs(q.X-c.X)/h.X)-1,(math.abs(q.Z-c.Z)/h.Z)-1)
  if i%1500==0 then task.wait()end
 end
 local ext2=Vector3.new(nhi.X-nlo.X,nhi.Y-nlo.Y,nhi.Z-nlo.Z)
 local d=Vector3.new((nmid.X-mid.X)*k.X,(nmid.Y-mid.Y)*k.Y,(nmid.Z-mid.Z)*k.Z) -- how far the bounding-box centre (the part's centre) moved, in the part's own studs
 local newFrame=d.Magnitude<1e-6 and frame or frame*CFrame.new(d.X,d.Y,d.Z)
 -- (a tiny float difference is not a change: the part keeps its exact Size)
 local function ratio(a,b)local r=a/b;return math.abs(r-1)<1e-9 and 1 or r end
 local r=Vector3.new(ratio(ext2.X,ext.X),ratio(ext2.Y,ext.Y),ratio(ext2.Z,ext.Z))
 -- normals: n' ~ J^-T n with J the field's Jacobian (central differences). Best effort: an API that is not there, or a surprise, leaves the normals as they were.
 local normals=0
 pcall(function()
  local at={};for i,vid in ipairs(vertices)do at[vid]=pos[i]end
  local step=math.max(ext.X,ext.Y,ext.Z)*1e-3;local done={}
  for _,face in ipairs(editable:GetFaces())do
   local vs,ns=editable:GetFaceVertices(face),editable:GetFaceNormals(face)
   for i,nid in ipairs(ns)do if not done[nid]and at[vs[i]]then
    done[nid]=true;local p=at[vs[i]];local n=editable:GetNormal(nid)
    local function d(dx,dy,dz)
     local a=map(Vector3.new(p.X+dx,p.Y+dy,p.Z+dz));local b=map(Vector3.new(p.X-dx,p.Y-dy,p.Z-dz))
     return Vector3.new((a.X-b.X)/(2*step),(a.Y-b.Y)/(2*step),(a.Z-b.Z)/(2*step))
    end
    local c0,c1,c2=d(step,0,0),d(0,step,0),d(0,0,step)
    local m1,m2,m0=c1:Cross(c2),c2:Cross(c0),c0:Cross(c1)
    local nn=Vector3.new(n.X*m1.X+n.Y*m2.X+n.Z*m0.X,n.X*m1.Y+n.Y*m2.Y+n.Z*m0.Y,n.X*m1.Z+n.Y*m2.Z+n.Z*m0.Z)
    if nn.Magnitude>1e-9 then nn=nn.Unit;if nn:Dot(n)>.5 then editable:SetNormal(nid,nn);normals+=1 end end
   end end
  end
 end)
 return{Size=Vector3.new(source.Size.X*r.X,source.Size.Y*r.Y,source.Size.Z*r.Z),Frame=newFrame,Extent=ext2,Moved=#vertices,Normals=normals,Out=out,Shift=d.Magnitude}
end
-- One reshaped MeshPart from one template MeshPart. Errors (the caller pcalls) with a reason; destroys the EditableMesh on every path.
local function bake(source,box,id)
 local Assets=game:GetService('AssetService');local editable,part
 local ok,why=xpcall(function()
  local meshId=source.MeshId
  assert(type(meshId)=='string'and meshId~='','template mesh '..source.Name..' has no MeshId')
  editable=Assets:CreateEditableMeshAsync(Content.fromUri(meshId))
  assert(editable,'no EditableMesh for '..meshId)
  local vertices=editable:GetVertices();assert(#vertices>0,'the pouch mesh has no vertices')
  assert(#vertices<=M.Config.MaxVertices,'the pouch mesh has '..#vertices..' vertices (the limit is '..M.Config.MaxVertices..')')
  assert(stats.Vertices+#vertices<=M.Config.MaxTotalVertices,'the reshaped meshes reached the memory cap')
  local info=M.Deform(editable,vertices,source,box,id)
  local result,content=Assets:CreateDataModelContentAsync(Content.fromObject(editable))
  assert(result==Enum.CreateContentResult.Success,'could not bake the reshaped mesh: '..tostring(result))
  part=Assets:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
  assert(part,'no MeshPart for the reshaped mesh')
  local okSize,size=pcall(function()return part.MeshSize end)
  if okSize and typeof(size)=='Vector3'and size.X>0 and size.Y>0 and size.Z>0 then
   for _,axis in ipairs({'X','Y','Z'})do
    assert(math.abs(size[axis]-info.Extent[axis])<=M.Config.SizeTolerance*info.Extent[axis]+1e-4,'the baked mesh is not the reshaped mesh ('..axis..' '..size[axis]..' vs '..info.Extent[axis]..')')
   end
  end
  part.Name=source.Name;part.Size=info.Size
  for _,prop in ipairs({'Color','Material','MaterialVariant','Reflectance','Transparency','TextureID','CastShadow'})do pcall(function()part[prop]=source[prop]end)end
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  for name,value in pairs(source:GetAttributes())do part:SetAttribute(name,value)end
  part:SetAttribute('PackLocalFrame',info.Frame);part:SetAttribute('ShapeOf',meshId);part:SetAttribute('Variation',id);part:SetAttribute('VertexCount',#vertices);part:SetAttribute('NormalsSet',info.Normals)
  part:SetAttribute('OutsideBox',info.Out)
  for _,child in ipairs(source:GetChildren())do pcall(function()child:Clone().Parent=part end)end
 end,debug.traceback)
 if editable then pcall(function()editable:Destroy()end)end
 if not ok then if part then pcall(function()part:Destroy()end)end;error(tostring(why),0)end
 return part
end
-- A design's reshaped template: a Model like the place's own (same attributes), its MeshParts reshaped. Not parented anywhere.
local function bakeDesign(key,id)
 local template=require(script.Parent.SeedPackRenderer).GetGeometry(key)
 assert(template,'the template '..key..' is not in SeedPackMeshAssets')
 local sources=meshParts(template)
 assert(#sources>0 and #sources==template:GetAttribute('MeshCount'),'the template '..key..' is not a complete pack template')
 local box=M.DesignBox(sources)
 local model=Instance.new('Model');model.Name=key
 for name,value in pairs(template:GetAttributes())do model:SetAttribute(name,value)end
 local vertices=0;local ok,why=pcall(function()
  for _,source in ipairs(sources)do local part=bake(source,box,id);part.Parent=model;vertices+=part:GetAttribute('VertexCount')or 0 end
  for _,child in ipairs(template:GetChildren())do if not child:IsA('MeshPart')then pcall(function()child:Clone().Parent=model end)end end
 end)
 if not ok then pcall(function()model:Destroy()end);error(tostring(why),0)end
 model:SetAttribute('PackShape',id)
 return{Id=id,Model=model,Vertices=vertices}
end
M._bakeDesign=bakeDesign
local function fail(key,id,reason)
 reason=tostring(reason):match('^[^\n]*')or'?'
 failed[key]={Id=id,Reason=reason};stats.Failures+=1;stats.Last=key..': '..reason
 if not warned then warned=true;warn('[R151 pack shapes] '..key..' keeps its original shape: '..reason..' (further failures are counted in '..M.Folder..')')end
end
local pump
local function finish(job,ok,result)
 if job.Cancelled then if ok and result then discard(result)end;return end
 current=nil;inflight[job.Key]=nil
 if ok and result then
  if M.VariationOf(job.Key)==job.Id then cache[job.Key]=result;stats.Baked+=1;stats.Vertices+=result.Vertices else discard(result)end
 else fail(job.Key,job.Id,result)end
 publish();pump()
end
function pump()
 if current then return end
 local key=table.remove(queue,1);if not key then return end
 local entry=inflight[key];if not entry then return pump()end
 local job={Key=key,Id=entry.Id};current=job
 task.spawn(function()local ok,result=xpcall(bakeDesign,debug.traceback,key,job.Id);finish(job,ok,result)end)
end
-- 'Ready' (the reshaped template is in the cache), 'Loading' (asked for, being baked), 'Off' (today's mesh: variations off, or this design failed) or 'Idle'
-- (nothing asked yet), and a reason for Off.
function M.State(key)
 hook();syncMode()
 local id=M.VariationOf(key)
 if not id then return'Off','pack shape variations are off'end
 local entry=cache[key];if entry and entry.Id==id then return'Ready'end
 local bad=failed[key];if bad and bad.Id==id then return'Off',bad.Reason end
 local wait=inflight[key]
 if wait and wait.Id==id then
  if os.clock()-wait.At>M.Config.LoadingSeconds then
   -- (a bake that never returns: give up on it, let the queue go on)
   inflight[key]=nil;local i=table.find(queue,key);if i then table.remove(queue,i)end
   if current and current.Key==key then current.Cancelled=true;current=nil end
   fail(key,id,'the bake did not finish in '..M.Config.LoadingSeconds..' s');publish();pump()
   return'Off',failed[key].Reason
  end
  return'Loading'
 end
 return'Idle'
end
-- Asks for the design's reshaped template (once); returns the State.
function M.Request(key)
 local s=M.State(key)
 if s~='Idle'then return s end
 inflight[key]={Id=M.VariationOf(key),At=os.clock()};stats.Requested+=1;table.insert(queue,key)
 publish();pump()
 return M.State(key)
end
function M.Await(key,seconds)
 local deadline=os.clock()+(seconds or M.Config.WaitSeconds)
 while M.State(key)=='Loading'and os.clock()<deadline do task.wait()end
 local state=M.State(key)
 -- a bake a builder had to give up waiting for does not make every later pack wait the full time behind it (ForBuild checks): the queue is stuck, not slow
 if state=='Loading'and current then current.WaiterGaveUp=true end
 return state=='Ready'
end
-- The ItemPictures gate: true while the design's reshaped template is still being baked (the picture build errors "still loading" and is retried).
function M.Pending(key)return M.Request(key)=='Loading'end
-- For SeedPackRenderer.Build: the design's reshaped template Model, or nil (build from the place's own). Never errors. A SERVER waits (up to Config.WaitSeconds)
-- for the design's first bake so every pack of a design is built the same; a client never waits (a picture is built after Pending says no).
function M.ForBuild(key)
 local ok,result=pcall(function()
  local s=M.Request(key)
  if s=='Loading'and Run:IsServer()and coroutine.isyieldable()and not(current and current.WaiterGaveUp)then M.Await(key);s=M.State(key)end
  if s=='Ready'then return cache[key].Model end
  return nil
 end)
 return ok and result or nil
end
-- The reshaped template if it is baked (never starts a bake): tests, tools.
function M.Template(key)
 if M.State(key)~='Ready'then return nil end
 return cache[key].Model
end
-- Owner command: 'off' | 'auto' | 1..6. Sets the status folder's attributes (replicated to every client), applies at once on this side.
function M.SetMode(mode)
 assert(Run:IsServer(),'The pack shape mode is set on the server.')
 local f=folder()
 if lastMode==nil then lastMode=M.Mode()end -- (the mode before this change: nobody asked yet, but a change is still a change to the listeners)
 mode=type(mode)=='string'and mode:lower()or mode
 if mode=='off'then f:SetAttribute('Off',true);f:SetAttribute('Force',nil)
 elseif mode=='auto'or mode=='on'then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)
 else
  local n=tonumber(mode);assert(n and n>=1 and n<=M.Count and n%1==0,'a pack shape is 1 to '..M.Count..', off or auto')
  f:SetAttribute('Off',nil);f:SetAttribute('Force',n)
 end
 hook();syncMode()
 return M.Mode()
end
-- Tests / tools: forget everything this side baked.
function M.Reset()
 for _,entry in pairs(cache)do discard(entry)end
 table.clear(cache);table.clear(failed);table.clear(inflight);table.clear(queue);current=nil;stats={Baked=0,Failures=0,Requested=0,Vertices=0,Last=nil};warned=false;lastMode=nil;hooked=nil
end
return M
