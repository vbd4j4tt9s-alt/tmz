-- R151 (owner: the Verity pack should be the REAL standard chip-bag pouch, pure yellow, with Verity's face on it). The standard pack's pouch is an
-- uploaded mesh (the owner's own upload) whose print is in its VERTEX COLOURS, and a part's Color only multiplies them (R149: yellow x navy = black),
-- so no Color can make it pure yellow. This module makes the neutral copy at runtime, like FruitMeshes149's `_Neutral` fruit twins:
--  * Server, at start (ApprovedPlantsBootstrap): reads the Verity design's template from the live place (SeedPackRenderer.GetGeometry: Storm_02, the
--    Standard design of Verity's stage 7; the MeshId is READ from the template, never written here), loads each of its MeshParts with
--    AssetService:CreateEditableMeshAsync, sets EVERY vertex colour to white (alpha 1), bakes a MeshPart (CreateDataModelContentAsync +
--    CreateMeshPartAsync), copies the template's Size and PackLocalFrame onto it and destroys the EditableMesh. The result is one Model, a clone of the
--    template with neutral meshes, in ReplicatedStorage.VerityPouchTemplate151 (a Folder; attributes Finished / Ready / Failed / Reason / Key ...).
--  * Everyone: State() says whether the pack may use it. VerityPackArt builds the pack from it (exactly like a plain pack: same pouch size, frame, pivot,
--    Bounds, seal and strips; painted 255,255,0, Verity's face as Decals on the pouch) and falls back to the R149 plain-parts sachet when the bake
--    failed / was denied / never ran / does not match the design.
-- Whatever goes wrong is contained: every step is a pcall, a partial bake is destroyed, the EditableMesh is destroyed on every path, and the result is
-- a Failed folder with the reason (one warn on the server), never an error in a pack build.
local RS=game:GetService('ReplicatedStorage');local Run=game:GetService('RunService')
local M={Folder='VerityPouchTemplate151',Revision=151,
 LoadingSeconds=45,  -- a client waits this long (from its first question) for a bake that has not finished, then uses the sachet
 SizeTolerance=.02}  -- the baked mesh's own size may differ from the original's by this share before the bake is refused
local WHITE=Color3.new(1,1,1)
-- The design whose pouch Verity uses: its stage-7 Standard design (VerityCatalog.PackStage, Variant -> SeedPackRules.DesignKey), e.g. 'Storm_02'.
function M.Key()
 local Cat=require(script.Parent.VerityCatalog);local Rules=require(script.Parent.SeedPackRules)
 return Rules.DesignKey(Cat.PackStage,Cat.Variant)
end
local function folder()
 local f=RS:FindFirstChild(M.Folder)
 if not f and Run:IsServer()then f=Instance.new('Folder');f.Name=M.Folder;f:SetAttribute('Finished',false);f:SetAttribute('Ready',false);f.Parent=RS end
 return f
end
if Run:IsServer()then folder()end -- the folder tells clients this server bakes the pouch (no folder: this server does not, the sachet is used)
local asked
-- 'Ready' (the neutral pouch of `key` is there), 'Loading' (the server is still baking), 'Off' (use the sachet) and why.
function M.State(key)
 local f=RS:FindFirstChild(M.Folder)
 if not f then return 'Off','this server does not bake the Verity pouch'end
 if f:GetAttribute('Finished')==true then
  if f:GetAttribute('Ready')~=true then return 'Off',tostring(f:GetAttribute('Reason')or'the bake failed')end
  local name=f:GetAttribute('Key')
  if key~=nil and key~=name then return 'Off','only '..tostring(name)..' is baked'end
  if not(typeof(name)=='string'and f:FindFirstChild(name))then
   -- (the attribute can reach a client before the Model does)
   asked=asked or os.clock();if os.clock()-asked>M.LoadingSeconds then return 'Off','the neutral pouch did not replicate'end
   return 'Loading'
  end
  return 'Ready'
 end
 asked=asked or os.clock()
 if os.clock()-asked>M.LoadingSeconds then return 'Off','the bake did not finish in time'end
 return 'Loading'
end
-- The neutral template Model of `key` (a clone of the design's template, its MeshParts neutral), or nil.
function M.Template(key)
 if M.State(key)~='Ready'then return nil end
 local f=RS:FindFirstChild(M.Folder);return f and f:FindFirstChild(f:GetAttribute('Key'))
end
local function sizeOf(part)
 local ok,size=pcall(function()return part.MeshSize end)
 if ok and typeof(size)=='Vector3'and size.X>0 and size.Y>0 and size.Z>0 then return size end
 return nil
end
-- One neutral MeshPart from one template MeshPart. Errors (the caller pcalls) with a reason; destroys the EditableMesh on every path.
local function bake(source)
 local Assets=game:GetService('AssetService');local editable,part
 local ok,why=xpcall(function()
  local id=source.MeshId
  assert(type(id)=='string'and id~='','template mesh '..source.Name..' has no MeshId')
  editable=Assets:CreateEditableMeshAsync(Content.fromUri(id))
  assert(editable,'no EditableMesh for '..id)
  local vertices=editable:GetVertices();assert(#vertices>0,'the pouch mesh has no vertices')
  local colors=editable:GetColors()
  for _,c in ipairs(colors)do editable:SetColor(c,WHITE);editable:SetColorAlpha(c,1)end
  -- every vertex colour is white now: read them all back (a bake that left one dark would paint a dark patch yellow x dark)
  for _,c in ipairs(editable:GetColors())do
   local k=editable:GetColor(c)
   assert(k.R>.999 and k.G>.999 and k.B>.999,'a vertex colour is not white after the bake')
  end
  local result,content=Assets:CreateDataModelContentAsync(Content.fromObject(editable))
  assert(result==Enum.CreateContentResult.Success,'could not bake the pouch mesh: '..tostring(result))
  part=Assets:CreateMeshPartAsync(content,{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Precise})
  assert(part,'no MeshPart for the baked pouch')
  -- the baked mesh must be the same mesh: its own (unscaled) size has to match the original's, or the Size below would stretch it differently
  local a,b=sizeOf(part),sizeOf(source)
  if a and b then
   for _,axis in ipairs({'X','Y','Z'})do assert(math.abs(a[axis]-b[axis])<=M.SizeTolerance*b[axis]+1e-4,'the baked pouch is not the original mesh ('..axis..' '..a[axis]..' vs '..b[axis]..')')end
  end
  part.Name=source.Name;part.Size=source.Size;part.Color=WHITE;part.Material=Enum.Material.SmoothPlastic;part.TextureID=''
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  part:SetAttribute('PackLocalFrame',source:GetAttribute('PackLocalFrame'))
  part:SetAttribute('NeutralOf',id);part:SetAttribute('VertexCount',#vertices);part:SetAttribute('ColorCount',#colors)
 end,debug.traceback)
 if editable then pcall(function()editable:Destroy()end)end
 if not ok then if part then pcall(function()part:Destroy()end)end;error(tostring(why),0)end
 return part
end
local preparing=false
-- Server only. Bakes the Verity design's pouch once per server (later calls wait for the first and return its answer); returns true when ready.
function M.Prepare()
 assert(Run:IsServer(),'The Verity pouch is baked on the server.')
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
  local model=Instance.new('Model');model.Name=key;made[#made+1]=model
  model:SetAttribute('MeshBakeVersion',template:GetAttribute('MeshBakeVersion'));model:SetAttribute('MeshCount',#sources)
  local vertices=0
  for _,source in ipairs(sources)do
   local part=bake(source);part.Parent=model;vertices+=part:GetAttribute('VertexCount')or 0
  end
  model:SetAttribute('Neutral',true)
  model.Parent=f -- the Model first, then the attributes that say it is ready: a client never sees Ready without it
  f:SetAttribute('Key',key);f:SetAttribute('VertexCount',vertices);f:SetAttribute('MeshCount',#sources)
 end)
 f:SetAttribute('BakeSeconds',os.clock()-started)
 if ok then f:SetAttribute('Ready',true);f:SetAttribute('Failed',false);f:SetAttribute('Finished',true)
 else
  for _,m in ipairs(made)do pcall(function()m:Destroy()end)end
  f:SetAttribute('Ready',false);f:SetAttribute('Failed',true);f:SetAttribute('Reason','the neutral Verity pouch could not be made: '..tostring(why):match('^[^\n]*'));f:SetAttribute('Finished',true)
  warn('[R151 Verity pouch] the Verity pack keeps its plain-parts sachet. '..tostring(why):match('^[^\n]*'))
 end
 preparing=false
 return ok
end
return M
