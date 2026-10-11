-- R158 track walls (owner approved docs/proposals/R158/design/: "look into designing each of the track walls and also the outer track designs can be added and so on and also polish up the
-- base walls especially the top"; base walls: option A, stone caps). Built ONCE at start-up by MapService.new (after HubDecor151), from the part data in TrackWallSpecs158:
--   1. TRACK WALLS   Workspace.ChestChaseMap.TrackWalls158/<Biome>: the walls' dressing, a different one in each of the 7 biomes (a log fort, temple ruins, a sandstone temple, ice bricks,
--                    volcano rock, crystal stone, a slate fort) + the 6 border towers where two biomes meet. Every part stands INSIDE the wall's own outline (the walls keep their size, height
--                    and collision: the saved wall parts under Obby.BiomeWalls are only recoloured / given a new material, 15 parts, nothing else about them changes).
--   2. OUTER GROUND  Workspace.ChestChaseMap.TrackBackdrops158/<Biome>: a flat ground outside the walls (today there is none: just sky). The backdrop OBJECTS (trees, mountains, volcanoes,
--                    the pyramid ...) are the owner's models, placed by OuterTrackLoader158 into this same folder (nothing is part-built for them).
--   3. BASE WALLS    Workspace.ChestChaseMap.BaseWalls158: option A, a stone cap on every merlon of the hub wall (in a few close shades) and a stone coping along the whole wall top.
-- Every part: Anchored, CanCollide / CanTouch / CanQuery off (players, keepers, packs, the runner sweep, the camera and the pack placement all pass through), CastShadow only on parts
-- 20+ studs long (and not on thin flat bands). No scripts, no per-frame work. Plain Folders (not Models): under StreamingEnabled every part streams in and out on its own, nothing on
-- the client looks for them. The only moving part is the refresh: the pieces standing over the refresh cover's roof (above Y 55) are made invisible while the track refreshes (one
-- attribute listener, a few hundred property writes per refresh) so the black cover is a clean box.
-- Idempotent: Apply replaces its three folders (a rebuild is identical: fixed seeds) and puts the walls' own look back first.
local Specs=require(script.Parent.TrackWallSpecs158)
local M={Version=158,Name='TrackWalls158',Lite=false}
M.Folders={Walls='TrackWalls158',Backdrops='TrackBackdrops158',Base='BaseWalls158'}
M.High={}          -- the parts hidden during a refresh: {Part=, Original=}
M.Generation=0     -- bumped by every Apply (a model load that finishes late checks it)
local V,CF=Vector3.new,CFrame.new

local function material(name)
 local ok,m=pcall(function()return Enum.Material[name]end)
 return ok and m or Enum.Material.SmoothPlastic
end
-- One spec -> one part (parented by the caller).
function M.Make(spec)
 local p=Instance.new(spec.Shape=='Wedge'and'WedgePart'or'Part')
 p.Name=spec.Name
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=spec.Shadow~=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Size=V(spec.Size[1],spec.Size[2],spec.Size[3])
 if spec.Shape=='Cylinder'then p.Shape=Enum.PartType.Cylinder elseif spec.Shape=='Ball'then p.Shape=Enum.PartType.Ball end
 p.CFrame=CF(table.unpack(spec.CF))
 p.Color=Color3.fromRGB(spec.Color[1],spec.Color[2],spec.Color[3]);p.Material=material(spec.Material)
 if(spec.Transparency or 0)>0 then p.Transparency=spec.Transparency end
 if spec.Mesh=='Sphere'then local m=Instance.new('SpecialMesh');m.MeshType=Enum.MeshType.Sphere;m.Parent=p end
 return p
end
-- The folder for a spec's group ('TrackWalls158/Forest' -> root > Forest), made once.
local function folderOf(root,cache,group)
 local path=group:match('^[^/]+/(.+)$')
 if not path then return root end
 local f=cache[path]
 if not f then f=Instance.new('Folder');f.Name=path;f.Parent=root;cache[path]=f end
 return f
end
local function buildList(map,rootName,list,hideHigh)
 local root=Instance.new('Folder');root.Name=rootName;root:SetAttribute('Version',M.Version)
 local cache={}
 for _,spec in ipairs(list)do
  local p=M.Make(spec);p.Parent=folderOf(root,cache,spec.Group)
  if hideHigh and Specs.OverCover(spec)then M.High[#M.High+1]={Part=p,Original=p.Transparency}end
 end
 root:SetAttribute('Parts',#list)
 root.Parent=map
 return root
end

-- The saved wall parts keep their size, position and collision; only Color / Material change (the old look is kept in attributes so a rebuild or M.Remove can put it back).
local function find(map,path)
 local node=map
 for name in path:gmatch('[^/]+')do node=node and node:FindFirstChild(name)end
 return node
end
function M.Restyle(map)
 local n=0
 for path,look in pairs(Specs.Restyle())do
  local w=find(map,path)
  if w and w:IsA('BasePart')then
   if w:GetAttribute('R158OldMaterial')==nil then w:SetAttribute('R158OldColor',w.Color);w:SetAttribute('R158OldMaterial',w.Material.Name)end
   w.Color=Color3.fromRGB(look.Color[1],look.Color[2],look.Color[3]);w.Material=material(look.Material);n+=1
  end
 end
 return n
end
function M.Unstyle(map)
 local n=0
 for path in pairs(Specs.Restyle())do
  local w=find(map,path)
  if w and w:IsA('BasePart')and w:GetAttribute('R158OldMaterial')~=nil then
   w.Color=w:GetAttribute('R158OldColor');w.Material=material(w:GetAttribute('R158OldMaterial'))
   w:SetAttribute('R158OldColor',nil);w:SetAttribute('R158OldMaterial',nil);n+=1
  end
 end
 return n
end

-- The refresh: the cover is a black box up to Y 55; pieces over it are hidden for the refresh's length.
local function setRefreshing(on)
 for _,h in ipairs(M.High)do if h.Part.Parent then h.Part.Transparency=on and 1 or h.Original end end
end
function M.WatchRefresh(map)
 if M.Connection then M.Connection:Disconnect();M.Connection=nil end
 local ok,signal=pcall(function()return map:GetAttributeChangedSignal('BiomesRefreshing')end)
 if ok and signal then M.Connection=signal:Connect(function()setRefreshing(map:GetAttribute('BiomesRefreshing')==true)end)end
 setRefreshing(map:GetAttribute('BiomesRefreshing')==true)
end

-- Removes everything this module built and puts the walls' look back (for the tests and the owner's undo); returns how many folders went.
function M.Remove(map)
 M.Generation+=1
 if M.Connection then M.Connection:Disconnect();M.Connection=nil end
 M.High={}
 local n=0
 for _,name in pairs(M.Folders)do local old=map:FindFirstChild(name);while old do old:Destroy();n+=1;old=map:FindFirstChild(name)end end
 M.Unstyle(map)
 return n
end

-- Builds the walls, the outer ground and the base wall caps in `map` (Workspace.ChestChaseMap). opt.Outer = false: no backdrop models (the offline tests). Every part of the build
-- is independent: one that fails is reported and the rest still stands. Returns {Walls=, Ground=, Base=, Restyled=, High=}.
function M.Apply(map,opt)
 assert(map,'TrackWalls158: no map')
 opt=opt or{}
 M.Remove(map)
 local made={}
 local function step(name,fn)
  local ok,res=pcall(fn)
  if ok then made[name]=res else warn('[R158] '..name..' skipped: '..tostring(res))end
 end
 step('Restyled',function()return M.Restyle(map)end)
 step('Walls',function()local list=Specs.TrackWalls({Lite=M.Lite});buildList(map,M.Folders.Walls,list,true);return #list end)
 step('Ground',function()local list=Specs.Backdrops();buildList(map,M.Folders.Backdrops,list);return #list end)
 step('Base',function()local list=Specs.BaseWalls('A');buildList(map,M.Folders.Base,list);return #list end)
 made.High=#M.High
 step('Refresh',function()M.WatchRefresh(map)end)
 -- the owner's backdrop models (async: they load while the server starts; a late finish checks M.Generation)
 if opt.Outer~=false then
  local generation=M.Generation
  task.spawn(function()
   local ok,err=pcall(function()return require(script.Parent.OuterTrackLoader158).Run(map,generation)end)
   if not ok then print('[R158 outer track] the backdrop models were skipped: '..tostring(err))end
  end)
 end
 return made
end
return M
