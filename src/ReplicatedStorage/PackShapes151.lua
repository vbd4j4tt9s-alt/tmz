-- R151 (owner: "make pack shape variations in blender; the pack shape will still be a chip shape but will be slightly different", then "every pack can spawn
-- with either of those variations ... shapes for visual representation in the index can just use the default pack shape"): six gentle variations of the chip-bag
-- pouch, rolled PER PACK, applied to the owner's own pouch meshes at run time so every design keeps its print.
--  * The 42 designs' prints live in each pouch mesh's VERTEX COLOURS, so a brand-new uploaded mesh per shape would lose them. A variation is instead a smooth
--    deformation FIELD over the design's normalised box (u, v, w = x, y, z of the pack-local box, each -1..1; the same field is built and drawn in Blender:
--    docs/proposals/R151/blender/pack_shapes.py writes the samples tests/pack_shape_samples.luau, which the test compares with Field below). A field only
--    scales x and z by a factor that depends on (u, v, w); y never moves, and the top / bottom 6% (the crimps, where the seal and the 8 tear strips sit) are
--    untouched, so the pivot, the bottom line, the seal and the strips stay exactly where they are. Nothing grows by more than 5%.
--  * THE ROLL. Every ordinary pack rolls one of the six variations (uniformly) the moment it is made and keeps it for life: a track spawn (ChestService.
--    RefreshWorldPack), and every pack that goes straight into a Bag (PlayerDataService:AddChest: bonus rolls, daily rewards, the mystery pedestal, gifts, owner
--    commands; the Verity pack takes none since R152). It is stored as the attribute PackShape on the world pack and as the OPTIONAL field PackShape on the item record (like
--    TestGrant: ProfileVersion stays 22, an older server drops it). 0 / absent = the default shape (the place's own mesh): every record saved before this, the
--    Void, the Mech, the Verity and the special packs. A pack that is stolen, dropped, picked up, banked, put in the hotbar, held or opened keeps its roll, so every
--    context builds the same shape. THE DEFAULT SHAPE has ONE mechanism: a pack with no / 0 PackShape, and the flag DefaultPackShape (SeedPackVisuals.Bag's
--    `defaultShape`, ItemPictures' |Plain look, which wins over a roll): the Index, the catalogue, shop, reward and market pictures are flagged, so they are
--    the default pouch whatever a pack rolled and never ask this module for anything.
--  * BUILDS NEVER YIELD (a pack is built inside the track refresh, the steal's carry slot and the Bag's grant, none of which may wait). A build takes the baked
--    template of its (design, variation) PAIR when it is there, else today's mesh. A NEW pack is settled against that (Settle): its roll is kept when the pair is
--    baked, else it keeps the default for life (counted as Demoted), so a pack never changes shape between contexts. A pack that already has a roll (a record)
--    shows the default only until its pair is baked (the bake is asked for at once; a server waits for it briefly before it puts a pack in a hand): never back.
--  * The bake (per side, lazily, ONE EditableMesh at a time): AssetService:CreateEditableMeshAsync(the template's own MeshId) -> SetPosition of every vertex
--    (colours, UVs stay) -> CreateMeshPartAsync, then the EditableMesh is destroyed. The baked MeshPart replaces the template's inside a Model kept in memory (never
--    parented); SeedPackRenderer.Build clones it exactly like the place's own. `neutral` pairs (kept for the API; the Verity pack takes none since R152) set every vertex colour white first.
--  * BUDGET (per side). 42 designs x 6 variations are far more than any one side needs at once, so the cache is an LRU over
--    vertices: above Config.MaxResidentVertices the least recently used pairs that are not PINNED (the pairs of the packs on the track) and were not used in the
--    last GraceSeconds are evicted; a pair unused for IdleSeconds goes too; nothing is baked above Config.HardResidentVertices. A pair that cannot be baked
--    (no permission, no vertices, over budget, a time-out) is STICKY: that pair shows the default shape on that side until the mode changes, so a fallback
--    never flickers between shapes. Evicting a template frees nothing while a built pack or picture still uses its mesh: that is released when they go.
--  * Switches: Config.Enabled / Config.Force here, and the owner's /test packshape <1-6|off|auto> (attributes Off / Force on the status folder). OFF hides every
--    shape at once (the default everywhere, packs keep their roll); a forced number is the roll of NEW packs; auto is a uniform roll.
--  * Status (server, replicated): ReplicatedStorage.PackShapeTemplates151 attributes Ready (on and nothing failed), FailureCount, BakedCount, Requested, Pending,
--    Pairs, Vertices (resident), Megabytes (an estimate), Evicted, Demoted, Mode, LastFailure. A client keeps its own numbers with a Client suffix.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local WHITE=Color3.new(1,1,1)
local M={Folder='PackShapeTemplates151',Revision=151,Count=6,
 Unavailable='EditableMesh is not available in this environment', -- the reason of a pair when the EditableMesh API is not there at all (a test world, an old client): an expected fallback, never a warning
 Names={'Pillow','Hourglass','Pear','Top-heavy','Shoulders','Flat'},
 Config={
  Enabled=true,        -- false: every pack shows the default shape
  Force=nil,           -- 1..6: every NEW pack rolls that variation (testing)
  LoadingSeconds=60,   -- a bake that has not finished this long after it was asked for is given up on (that pair keeps the default shape)
  HoldWaitSeconds=2.5, -- a server waits at most this long for a pair before it puts a pack in a hand (Await)
  MaxVertices=60000,   -- a mesh with more vertices than this is not reshaped
  MaxResidentVertices=400000,  -- soft cap per side: above it the least recently used unpinned pairs are evicted
  HardResidentVertices=600000, -- nothing is baked above it
  GraceSeconds=30,     -- a pair used within this long is not evicted by the soft cap
  IdleSeconds=900,     -- a pair unused for this long is evicted even below the cap
  SweepSeconds=60,     -- how often the idle sweep runs (only while something is cached)
  BytesPerVertex=48,   -- the estimate behind Megabytes (position, normal, UV, colour, share of the index buffer)
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
-- Rolls and shapes -------------------------------------------------------------------------------------------------------------------------------
-- A stored shape as 0 (the default: the place's own mesh) or 1..6; anything else (nil, a string, 2.5, 7, NaN) is 0.
function M.Sanitize(v)
 if type(v)~='number'or v~=v or v%1~=0 or v<1 or v>M.Count then return 0 end
 return v
end
-- Whether a pack of this variant key can have a variation: the ordinary biome packs (also the legacy Small / Standard / Grand). The Void, the Mech, every special pack and, since
-- R152 (owner: the Verity pack must be a clean FLAT pouch), the Verity pack keep their own pouch: Verity never rolls, never carries and never builds a shape (every roll, record
-- field, world pack, picture and builder asks this first), so its flat pouch (VerityPouch151) is the same in every context.
function M.Applies(variantKey)
 if type(variantKey)~='string'or variantKey=='EclipseReliquary'or variantKey=='MechLimited'or variantKey==require(script.Parent.VerityCatalog).Variant then return false end
 return require(script.Parent.SeedPackRules).Variants[variantKey]~=nil
end
local stats={Baked=0,Failures=0,Requested=0,Evicted=0,Demoted=0,Last=nil,Rolled={0,0,0,0,0,0}}
local rng
local function draw()
 if Random then rng=rng or Random.new();return rng:NextNumber()end
 return math.random()
end
local listeners={}
local lastDisplay
-- 'off', 1..6 (forced: the roll of NEW packs) or 'auto': the status folder's attributes (the owner's command) over Config.
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
-- Whether any shape is shown (false: every pack builds the default shape, whatever it rolled).
function M.Display()return M.Mode()~='off'end
-- The roll of a NEW pack of `variantKey`: 1..6 (uniform; `unit`, 0..1, is the dice for tests; a forced mode answers its number), or nil when the variant
-- takes no variation or the variations are off.
function M.Roll(variantKey,unit)
 if not M.Applies(variantKey)then return nil end
 local mode=M.Mode()
 if mode=='off'then return nil end
 local id=mode
 if mode=='auto'then
  local u=type(unit)=='number'and unit==unit and unit or draw()
  id=math.min(M.Count,math.floor(math.clamp(u,0,1)*M.Count)+1)
 end
 stats.Rolled[id]+=1
 return id
end
-- Cache / queue ----------------------------------------------------------------------------------------------------------------------------------
local cache={}     -- [pair] = {Pair, Key, Id, Neutral, Model, Vertices, Last}
local failed={}    -- [pair] = {Reason}   (sticky until the mode changes)
local inflight={}  -- [pair] = {Pair, Key, Id, Neutral, At}
local queue={}
local pins={}      -- [pair] = how many owners hold it
local owners=setmetatable({},{__mode='k'}) -- [owner table] = pair
local resident=0
local current
local warned=false
local function pairOf(key,id,neutral)return tostring(key)..'|'..tostring(id)..(neutral and'|n'or'')end
local function folder()
 local f=RS:FindFirstChild(M.Folder)
 if not f and Run:IsServer()then f=Instance.new('Folder');f.Name=M.Folder;f.Parent=RS end
 return f
end
local function pending()local n=0;for _ in pairs(inflight)do n+=1 end;return n end
local function pairCount()local n=0;for _ in pairs(cache)do n+=1 end;return n end
local function publish()
 local f=RS:FindFirstChild(M.Folder);if not f then return end
 local p=Run:IsServer()and''or'Client'
 pcall(function()
  f:SetAttribute('Ready'..p,M.Display()and stats.Failures==0)
  f:SetAttribute('FailureCount'..p,stats.Failures);f:SetAttribute('BakedCount'..p,stats.Baked);f:SetAttribute('Requested'..p,stats.Requested)
  f:SetAttribute('Pending'..p,pending());f:SetAttribute('Pairs'..p,pairCount());f:SetAttribute('Vertices'..p,resident)
  f:SetAttribute('Megabytes'..p,math.floor(resident*M.Config.BytesPerVertex/1e5+.5)/10)
  f:SetAttribute('Evicted'..p,stats.Evicted);f:SetAttribute('Demoted'..p,stats.Demoted);f:SetAttribute('Mode'..p,tostring(M.Mode()))
  f:SetAttribute('Revision',M.Revision)
  if stats.Last then f:SetAttribute('LastFailure'..p,stats.Last)end
 end)
end
if Run:IsServer()then
 local f=folder();f:SetAttribute('Ready',true);f:SetAttribute('FailureCount',0);f:SetAttribute('BakedCount',0);f:SetAttribute('Requested',0);f:SetAttribute('Pending',0)
 f:SetAttribute('Pairs',0);f:SetAttribute('Vertices',0);f:SetAttribute('Megabytes',0);f:SetAttribute('Evicted',0);f:SetAttribute('Demoted',0);f:SetAttribute('Mode','auto');f:SetAttribute('Revision',M.Revision)
end
function M.Status()
 return{Mode=M.Mode(),Baked=stats.Baked,Failures=stats.Failures,Requested=stats.Requested,Pending=pending(),Pairs=pairCount(),Vertices=resident,
  Megabytes=resident*M.Config.BytesPerVertex/1e6,Evicted=stats.Evicted,Demoted=stats.Demoted,Rolled=table.clone(stats.Rolled),LastFailure=stats.Last,
  Ready=M.Display()and stats.Failures==0}
end
local function discard(model)if model then pcall(function()model:Destroy()end)end end
local function remove(pair)
 local e=cache[pair];if not e then return end
 cache[pair]=nil;resident-=e.Vertices;stats.Evicted+=1;discard(e.Model)
end
-- Evicts the least recently used unpinned pairs (never `keep`) until `limit` vertices are resident; a pair used within GraceSeconds only when `force`.
local function evictTo(limit,force,keep)
 local now=os.clock()
 while resident>limit do
  local oldest
  for pair,e in pairs(cache)do
   if pair~=keep and not pins[pair]and(force or now-e.Last>=M.Config.GraceSeconds)and(not oldest or e.Last<oldest.Last)then oldest=e end
  end
  if not oldest then return false end
  remove(oldest.Pair)
 end
 return true
end
local sweeping
local function sweep()
 sweeping=false
 local now=os.clock()
 for pair,e in pairs(cache)do if not pins[pair]and now-e.Last>=M.Config.IdleSeconds then remove(pair)end end
 publish()
 if next(cache)then sweeping=true;task.delay(M.Config.SweepSeconds,sweep)end
end
local function listen()for _,fn in ipairs(table.clone(listeners))do task.spawn(fn)end end
-- The display switch changed (the owner's command, a Config edit): off drops every template (memory) and every failure is forgotten; listeners (the item
-- pictures) are told. A forced number changes nothing that is already built: it is only the roll of new packs.
local function syncDisplay()
 local on=M.Display()
 if on==lastDisplay then return end
 local first=lastDisplay==nil;lastDisplay=on
 if not on then
  local evicted=stats.Evicted;for pair in pairs(cache)do remove(pair)end;stats.Evicted=evicted -- (switching off is not an eviction)
 end
 table.clear(failed);stats.Failures=0;stats.Last=nil
 publish()
 if not first then listen()end
end
function M.OnChanged(fn)
 table.insert(listeners,fn)
 return function()local i=table.find(listeners,fn);if i then table.remove(listeners,i)end end
end
local hooked,watching
local function hook()
 if hooked then return end
 local f=RS:FindFirstChild(M.Folder)
 if f then hooked=true;f:GetAttributeChangedSignal('Force'):Connect(syncDisplay);f:GetAttributeChangedSignal('Off'):Connect(syncDisplay);syncDisplay()
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
-- One reshaped MeshPart from one template MeshPart. Errors (the caller pcalls) with a reason; destroys the EditableMesh on every path. `neutral`: every vertex
-- colour is set white first (read back to be sure: a dark one would paint a dark patch under the Verity yellow).
local function bake(source,box,id,neutral)
 local Assets=game:GetService('AssetService');local editable,part
 local ok,why=xpcall(function()
  -- the API itself missing (a world without EditableMesh) is an expected fallback: the pair is the default shape, quietly (the status folder says why)
  local okApi,method=pcall(function()return Assets.CreateEditableMeshAsync end)
  if Content==nil or not okApi or type(method)~='function'then error(M.Unavailable..' (AssetService:CreateEditableMeshAsync or Content is missing)',0)end
  local meshId=source.MeshId
  assert(type(meshId)=='string'and meshId~='','template mesh '..source.Name..' has no MeshId')
  editable=Assets:CreateEditableMeshAsync(Content.fromUri(meshId))
  assert(editable,'no EditableMesh for '..meshId)
  local vertices=editable:GetVertices();assert(#vertices>0,'the pouch mesh has no vertices')
  assert(#vertices<=M.Config.MaxVertices,'the pouch mesh has '..#vertices..' vertices (the limit is '..M.Config.MaxVertices..')')
  assert(resident<M.Config.HardResidentVertices,'over budget: '..resident..' vertices are resident (the limit is '..M.Config.HardResidentVertices..')')
  local colors
  if neutral then
   colors=editable:GetColors()
   for _,c in ipairs(colors)do editable:SetColor(c,WHITE);editable:SetColorAlpha(c,1)end
   for _,c in ipairs(editable:GetColors())do
    local k=editable:GetColor(c)
    assert(k.R>.999 and k.G>.999 and k.B>.999,'a vertex colour is not white after the bake')
   end
  end
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
  if neutral then part.Color=WHITE;part.Material=Enum.Material.SmoothPlastic;part.TextureID=''end
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  for name,value in pairs(source:GetAttributes())do part:SetAttribute(name,value)end
  part:SetAttribute('PackLocalFrame',info.Frame);part:SetAttribute('ShapeOf',meshId);part:SetAttribute('Variation',id);part:SetAttribute('VertexCount',#vertices);part:SetAttribute('NormalsSet',info.Normals)
  part:SetAttribute('OutsideBox',info.Out)
  if neutral then part:SetAttribute('NeutralOf',meshId);part:SetAttribute('ColorCount',#colors)end
  for _,child in ipairs(source:GetChildren())do pcall(function()child:Clone().Parent=part end)end
 end,debug.traceback)
 if editable then pcall(function()editable:Destroy()end)end
 if not ok then if part then pcall(function()part:Destroy()end)end;error(tostring(why),0)end
 return part
end
-- A design's reshaped template: a Model like the place's own (same attributes), its MeshParts reshaped. Not parented anywhere.
local function bakeDesign(key,id,neutral)
 local template=require(script.Parent.SeedPackRenderer).GetGeometry(key)
 assert(template,'the template '..key..' is not in SeedPackMeshAssets')
 local sources=meshParts(template)
 assert(#sources>0 and #sources==template:GetAttribute('MeshCount'),'the template '..key..' is not a complete pack template')
 local box=M.DesignBox(sources)
 local model=Instance.new('Model');model.Name=key
 for name,value in pairs(template:GetAttributes())do model:SetAttribute(name,value)end
 local vertices=0;local ok,why=pcall(function()
  for _,source in ipairs(sources)do local part=bake(source,box,id,neutral);part.Parent=model;vertices+=part:GetAttribute('VertexCount')or 0 end
  for _,child in ipairs(template:GetChildren())do if not child:IsA('MeshPart')then pcall(function()child:Clone().Parent=model end)end end
 end)
 if not ok then pcall(function()model:Destroy()end);error(tostring(why),0)end
 model:SetAttribute('PackShape',id);if neutral then model:SetAttribute('Neutral',true)end
 return{Model=model,Vertices=vertices}
end
M._bakeDesign=bakeDesign
local function fail(pair,reason)
 reason=tostring(reason):match('^[^\n]*')or'?'
 failed[pair]={Reason=reason};stats.Failures+=1;stats.Last=pair..': '..reason
 -- one warning per session, and only for a REAL failure (a denied asset, a bad mesh, a time-out ...): a world without the API is an expected fallback, not logged
 if not warned and not reason:find(M.Unavailable,1,true)then warned=true;warn('[R151 pack shapes] '..pair..' keeps the default shape: '..reason..' (further failures are counted in '..M.Folder..')')end
end
local pump
-- A baked pair goes in the cache and the cache is trimmed; if it does not fit even after evicting everything unpinned it is dropped and the pair fails for good.
local function insert(job,result)
 local pair=job.Pair
 cache[pair]={Pair=pair,Key=job.Key,Id=job.Id,Neutral=job.Neutral,Model=result.Model,Vertices=result.Vertices,Last=os.clock()}
 resident+=result.Vertices;stats.Baked+=1
 evictTo(M.Config.MaxResidentVertices,false,pair)
 if resident>M.Config.HardResidentVertices then evictTo(M.Config.HardResidentVertices,true,pair)end
 if resident>M.Config.HardResidentVertices then
  local e=cache[pair];cache[pair]=nil;resident-=e.Vertices;stats.Baked-=1;discard(e.Model)
  fail(pair,'over budget: '..resident+result.Vertices..' vertices would be resident (the limit is '..M.Config.HardResidentVertices..'; the rest is in use)')
  return
 end
 if not sweeping then sweeping=true;task.delay(M.Config.SweepSeconds,sweep)end
end
local function finish(job,ok,result)
 if job.Cancelled then if ok and result then discard(result.Model)end;return end
 current=nil;inflight[job.Pair]=nil
 if ok and result then
  if M.Display()then insert(job,result)else discard(result.Model)end
 else fail(job.Pair,result)end
 publish();pump()
end
function pump()
 if current then return end
 local pair=table.remove(queue,1);if not pair then return end
 local entry=inflight[pair];if not entry then return pump()end
 -- room first: above the soft cap the idle unpinned pairs go; at the hard cap anything unpinned goes (least recently used first) before this pair is baked
 if resident>=M.Config.MaxResidentVertices then evictTo(M.Config.MaxResidentVertices-1,false)end
 if resident>=M.Config.HardResidentVertices then evictTo(M.Config.HardResidentVertices-1,true)end
 local job={Pair=pair,Key=entry.Key,Id=entry.Id,Neutral=entry.Neutral};current=job
 task.spawn(function()local ok,result=xpcall(bakeDesign,debug.traceback,job.Key,job.Id,job.Neutral);finish(job,ok,result)end)
end
-- API ----------------------------------------------------------------------------------------------------------------------------------------------
-- 'Ready' (the pair's template is in the cache), 'Loading' (asked for, being baked), 'Off' (the default shape: shape 0, the variations are off, or the pair
-- failed) or 'Idle' (nothing asked yet), and a reason for Off. `neutral` = the Verity pouch's white copy.
function M.State(key,id,neutral)
 hook();syncDisplay()
 id=M.Sanitize(id)
 if id==0 then return'Off','the default shape'end
 if not M.Display()then return'Off','pack shape variations are off'end
 local pair=pairOf(key,id,neutral)
 if cache[pair]then return'Ready'end
 local bad=failed[pair];if bad then return'Off',bad.Reason end
 local wait=inflight[pair]
 if wait then
  if os.clock()-wait.At>M.Config.LoadingSeconds then
   -- (a bake that never returns: give up on it for good, let the queue go on)
   inflight[pair]=nil;local i=table.find(queue,pair);if i then table.remove(queue,i)end
   if current and current.Pair==pair then current.Cancelled=true;current=nil end
   fail(pair,'the bake did not finish in '..M.Config.LoadingSeconds..' s');publish();pump()
   return'Off',failed[pair].Reason
  end
  return'Loading'
 end
 return'Idle'
end
-- Asks for the pair's template (once; urgent = in front of the queue); returns the State. Never yields.
function M.Request(key,id,neutral,urgent)
 id=M.Sanitize(id)
 local s,why=M.State(key,id,neutral)
 local pair=pairOf(key,id,neutral)
 if s=='Loading'then
  if urgent then local i=table.find(queue,pair);if i and i>1 then table.remove(queue,i);table.insert(queue,1,pair)end end
  return s
 end
 if s~='Idle'then return s,why end
 inflight[pair]={Pair=pair,Key=key,Id=id,Neutral=neutral==true,At=os.clock()};stats.Requested+=1
 if urgent then table.insert(queue,1,pair)else table.insert(queue,pair)end
 publish();pump()
 return M.State(key,id,neutral)
end
-- The pair's baked template Model if it is there (never starts a bake); counts as a use for the LRU.
function M.Template(key,id,neutral)
 if M.State(key,id,neutral)~='Ready'then return nil end
 local e=cache[pairOf(key,M.Sanitize(id),neutral)];e.Last=os.clock();return e.Model
end
-- For the pack builders (SeedPackRenderer.Build, VerityPackArt): the template Model of a pack's pair and the shape it shows, or nil and 0 (build the place's own
-- mesh). NEVER YIELDS and never errors, except that a CLIENT (a picture: ItemPictures retries a build that errors "still loading") errors while the pair is being
-- baked, so that a picture is never drawn in the default shape and then again in another. Asks for the bake when the pair has not been asked for.
function M.ForBag(key,shape,neutral)
 shape=M.Sanitize(shape)
 if shape==0 then return nil,0 end
 local s=M.Request(key,shape,neutral)
 if s=='Ready'then return M.Template(key,shape,neutral),shape end
 if s=='Loading'and Run:IsClient()and not Run:IsServer()then error('Pack shape is still loading',0)end
 return nil,0
end
-- A NEW pack's roll settled against the bake: the roll when its pair is baked (or the bake has just been asked for and the pair is Ready), else 0 for life (the
-- default shape; counted in Demoted). Server only; never yields. nil stays nil (a pack that takes no variation).
function M.Settle(key,shape,neutral)
 if shape==nil then return nil end
 shape=M.Sanitize(shape);if shape==0 then return 0 end
 if M.Request(key,shape,neutral,true)=='Ready'then return shape end
 stats.Demoted+=1;publish();return 0
end
-- Server: waits (yields) up to `seconds` for the pair's bake (Config.HoldWaitSeconds) so a pack put in a hand is already its own shape; true when Ready.
function M.Await(key,shape,neutral,seconds)
 shape=M.Sanitize(shape);if shape==0 then return true end
 M.Request(key,shape,neutral,true)
 local deadline=os.clock()+(seconds or M.Config.HoldWaitSeconds)
 while M.State(key,shape,neutral)=='Loading'and os.clock()<deadline do task.wait()end
 return M.State(key,shape,neutral)=='Ready'
end
-- Asks for the bakes of a list of {Key=, Id=, Neutral=} (in order, behind what is queued).
function M.Prefetch(list)
 for _,item in ipairs(list or{})do M.Request(item.Key,item.Id,item.Neutral,false)end
end
-- The pair is held by `owner` (a world pack's seed table) so the LRU never evicts it while that pack can be stolen, dropped and carried; one pair per owner.
function M.Pin(owner,key,id,neutral)
 M.Unpin(owner)
 id=M.Sanitize(id);if id==0 or owner==nil then return end
 local pair=pairOf(key,id,neutral);owners[owner]=pair;pins[pair]=(pins[pair]or 0)+1
end
function M.Unpin(owner)
 local pair=owners[owner];if not pair then return end
 owners[owner]=nil;pins[pair]=pins[pair]-1;if pins[pair]<=0 then pins[pair]=nil end
end
-- Owner command: 'off' | 'auto' | 1..6. Sets the status folder's attributes (replicated to every client), applies at once on this side.
function M.SetMode(mode)
 assert(Run:IsServer(),'The pack shape mode is set on the server.')
 local f=folder()
 if lastDisplay==nil then lastDisplay=M.Display()end -- (the state before this change: nobody asked yet, but a change is still a change to the listeners)
 mode=type(mode)=='string'and mode:lower()or mode
 if mode=='off'then f:SetAttribute('Off',true);f:SetAttribute('Force',nil)
 elseif mode=='auto'or mode=='on'then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)
 else
  local n=tonumber(mode);assert(n and n>=1 and n<=M.Count and n%1==0,'a pack shape is 1 to '..M.Count..', off or auto')
  f:SetAttribute('Off',nil);f:SetAttribute('Force',n)
 end
 hook();syncDisplay();publish()
 return M.Mode()
end
-- Tests / tools: forget everything this side baked, pinned, counted and failed.
function M.Reset()
 for _,e in pairs(cache)do discard(e.Model)end
 table.clear(cache);table.clear(failed);table.clear(inflight);table.clear(queue);table.clear(pins);table.clear(owners);resident=0;current=nil
 stats={Baked=0,Failures=0,Requested=0,Evicted=0,Demoted=0,Last=nil,Rolled={0,0,0,0,0,0}};warned=false;lastDisplay=nil;hooked=nil;sweeping=false
end
return M
