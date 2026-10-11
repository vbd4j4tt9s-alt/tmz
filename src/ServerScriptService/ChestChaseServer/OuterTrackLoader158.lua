-- R158 outer track: places the models of OuterTrackAssets158 (owner: "I will give you asset ids for the pyramids, volcanos and mountains and everything else, don't have to model
-- them yourself, just place the stuff"). Runs once per server, a moment after the map is built (TrackWalls158.Apply starts it with task.spawn), into
-- Workspace.ChestChaseMap.TrackBackdrops158/<Biome>/Models. For each KEY (OuterTrackAssets158.Keys) the model comes from the first of
--   1. hand    ServerStorage.OuterTrackAssets158: a model (or MeshPart / Part / Folder) named by the key (Key2, Key3 ... for more looks of the same thing)
--   2. owner   built in from the owner's files: DesertPyramid and StormDarkMount (part data, OuterTrackModels158), LavaVolcano and SnowMountains (his meshes, loaded by id with
--              AssetService:CreateMeshPartAsync, each in a pcall, given up after OuterTrackAssets158.LoadSeconds)
--   3. game    a model the game already has (the map's oak, jungle trees, ice trees, crystal clusters, copied from the map; and the hub's own trees, built with HubLifeArt151's
--              builders: OuterTrackAssets158.Game); a key with several models (the Forest's and the Jungle's trees) gives each spot one of them (the spot's Look)
--   4. id      OuterTrackAssets158.Ids[key] (0 = not set): AssetService:LoadAssetAsync, then InsertService:LoadAsset (as HubTreeLoader151 does for the hub's trees); Roblox only lets a
--              game load models its owner owns, a model by someone else fails with "not authorized" and that is ONE plain note, never a warning
-- A key with no model is skipped (one plain print, nothing part-built in its place).
-- Whatever arrives is made safe like the hub's tree templates (HubStudTrees151): every Script / LocalScript / ModuleScript and every non-geometry instance (sounds, lights, particles,
-- welds ...) removed, decals / textures / meshes kept; every part Anchored, CanCollide / CanTouch / CanQuery off (nothing can touch it, the camera goes through it), no shadow
-- (OuterTrackAssets158.Shadows: only parts 20+ studs long would cast one). It is scaled evenly until it fits the spot's box, stood on the ground, turned by the spot's Yaw (leaned by Tilt,
-- tinted by Tint, a small glow on top for Glow). Nothing is placed that would reach inside |x| 100 (or over the hub): the spot's box is checked once more here.
-- Idempotent: Run replaces the Models folders; a run for an older generation (the map was rebuilt meanwhile) stops. Streaming: plain parts in Models / Folders, nothing on a client.
local Assets=require(script.Parent.OuterTrackAssets158)
local Models=require(script.Parent.OuterTrackModels158)
local Specs=require(script.Parent.TrackWallSpecs158)
local Walls=require(script.Parent.TrackWalls158)
local RS=game:GetService('ReplicatedStorage')
local T=require(RS:WaitForChild('HubStudTrees151'))
local L={Version=158,Status={},Cache={}}
local V,CF=Vector3.new,CFrame.new
local MIN_X,HUB_Z=100,-99

local function short(e)local s=tostring(e or'?'):gsub('%s+',' ');return #s>140 and s:sub(1,140)..'...'or s end
local function note(text)print('[R158 outer track] '..text)end
-- Runs fn in its own thread and waits for it (at most `seconds`): ok, result. A hung request is given up (its late answer is dropped).
local function timed(fn,seconds)
 local done,ok,res=false,false,nil
 task.spawn(function()ok,res=pcall(fn);done=true end)
 local t0=os.clock();local limit=seconds or Assets.LoadSeconds
 while not done and os.clock()-t0<limit do task.wait(.1)end
 if not done then return false,'timed out after '..tostring(limit)..' s'end
 return ok,res
end
L.Timed=timed

-- Sources --------------------------------------------------------------------------------------------------------------------------------------
-- The owner's hand-placed models: ServerStorage.OuterTrackAssets158 children named Key, Key2, Key3 ...
function L.HandPlaced(key)
 local folder=game:GetService('ServerStorage'):FindFirstChild(Assets.Folder)
 local list={}
 if folder then for _,c in ipairs(folder:GetChildren())do
  local n=c.Name
  if n==key or n:match('^'..key..'_?%d+$')then list[#list+1]=c end
 end end
 table.sort(list,function(a,b)return a.Name<b.Name end)
 return list
end
local function countParts(m)local n=m:IsA('BasePart')and 1 or 0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;return n end
-- Models the map already has (OuterTrackAssets158.Game): the Models of the entry (and of each of its Also entries) whose Name (and, when given, whose parent's name) matches the
-- pattern, under the Obby.Biomes folders whose name starts with Biome; at most Max of them, in name order (the fewest parts first with Smallest). Returns {{Model=, Label=}}.
local function gather(biomes,prefix,entry)
 local keyed={}
 for _,b in ipairs(biomes:GetChildren())do
  if b.Name:sub(1,#prefix)==prefix then
   for _,d in ipairs(b:GetDescendants())do
    if d:IsA('Model')and d.Name:match(entry.Name)and(not entry.Parent or(d.Parent~=nil and d.Parent.Name:match(entry.Parent)))then
     keyed[#keyed+1]={Model=d,Name=d:GetFullName(),Parts=countParts(d)}
    end
   end
  end
 end
 table.sort(keyed,function(a,b)if entry.Smallest and a.Parts~=b.Parts then return a.Parts<b.Parts end;return a.Name<b.Name end)
 local out={}
 for i=1,math.min(entry.Max or 1,#keyed)do out[i]={Model=keyed[i].Model,Label=keyed[i].Model.Name}end
 return out
end
function L.GameModels(map,key)
 local g=Assets.Game[key];if not g then return{}end
 local obby=map:FindFirstChild('Obby');local biomes=obby and obby:FindFirstChild('Biomes')
 local out={}
 if biomes then
  local entries={g}
  for _,e in ipairs(g.Also or{})do entries[#entries+1]=e end
  for _,e in ipairs(entries)do for _,m in ipairs(gather(biomes,g.Biome,e))do out[#out+1]=m end end
 end
 return out
end
-- The hub's own trees (ReplicatedStorage.HubLifeArt151: the builders the hub's square draws its trees with) built into private Models of their own, with a tiny context that keeps the
-- core and detail parts (no 'fine' extras). Each recipe in Game[key].Hub is {Kind = 'Oak' | 'Leafy' | 'Poplar' | 'Palm', Arg = the size / tone the builder takes, X, Z = the builder's
-- seed}: the same recipe always gives the same tree, a different seed a different crown. Returns {{Model=, Label=}} (nothing, and why, when the builders are not there).
local HUB_FN={Oak='Oak',Leafy='LeafyTree',Poplar='Poplar',Palm='Palm'}
function L.HubModels(key)
 local g=Assets.Game[key];local recipes=g and g.Hub
 if not recipes or #recipes==0 then return{}end
 local ok,Art,K=pcall(function()return require(RS:WaitForChild('HubLifeArt151',5)),require(RS:WaitForChild('HubDecorKit151',5))end)
 if not ok or type(Art)~='table'or type(K)~='table'then return{},'the hub tree builders are not there'end
 local out={}
 for _,r in ipairs(recipes)do
  local fn=Art[HUB_FN[r.Kind]or'']
  if type(fn)=='function'then
   local built,m=pcall(function()
    local model=Instance.new('Model');model.Name='Hub '..r.Kind
    local ctx={Emitters={}}
    function ctx.Part(level,_,_,name,size,cf,color,mat,o)if level=='fine'then return nil end;return K.Part(model,name,size,cf,color,mat,o)end
    fn(ctx,r.X,r.Z,r.Arg)
    return model
   end)
   if built and m and #m:GetChildren()>0 then out[#out+1]={Model=m,Label='hub '..r.Kind:lower()..(r.Arg and(' '..tostring(r.Arg))or'')..' ('..tostring(r.X)..','..tostring(r.Z)..')'}end
  end
 end
 return out
end
-- A copy of the game's own model keeps no CollectionService tag and no attribute: Clone copies both, and the map's passes have marked their parts (HideBushes124 tags every big Bush
-- 'HideBush' with a HideBushId: a giant copy with them would turn its bushes see-through for the player hiding in a real bush and add parts to the hiding scan).
local function strip(o)
 local CS=game:GetService('CollectionService')
 for _,tag in ipairs(CS:GetTags(o))do CS:RemoveTag(o,tag)end
 for k in pairs(o:GetAttributes())do o:SetAttribute(k,nil)end
end
-- A private, safe, locked copy of a source model as {Model, Size} (nil, why when it cannot be used). Only a Model can be scaled and moved as one, so a part, a Folder or anything
-- else that is not a Model goes into a Model of its own.
local function prepare(src)
 if T.IsCode(src)then return nil,'it is a script'end
 local ok,res=pcall(function()
  local m=src:Clone()
  if not m:IsA('Model')then local w=Instance.new('Model');w.Name=src.Name;m.Parent=w;m=w end
  strip(m);for _,d in ipairs(m:GetDescendants())do strip(d)end
  local scripts,other=T.Sanitize(m)
  T.Lock(m)
  local centre,size=T.Box(m)
  if not centre or size.X<=0 or size.Y<=0 or size.Z<=0 then error('the model has no parts')end
  return{Model=m,Size=size,Scripts=scripts,Other=other,Parts=countParts(m)}
 end)
 if ok then return res end
 return nil,short(res)
end
L.Prepare=prepare
-- A model by asset id: the loaded container's only child (or the container).
function L.LoadId(id)
 local errs={}
 for _,svc in ipairs({{'AssetService','LoadAssetAsync'},{'InsertService','LoadAsset'}})do
  local ok,res=timed(function()return game:GetService(svc[1])[svc[2]](game:GetService(svc[1]),id)end)
  if ok and typeof(res)=='Instance'then
   local kids=res:GetChildren()
   if #kids==1 and(kids[1]:IsA('Model')or kids[1]:IsA('BasePart')or kids[1]:IsA('Folder'))then local m=kids[1];m.Parent=nil;res:Destroy();return m end
   return res
  end
  errs[#errs+1]=svc[1]..': '..short(ok and'nothing returned'or res)
 end
 return nil,table.concat(errs,'; ')
end
-- One of the owner's meshes as a MeshPart (an instance of its own, unparented): CreateMeshPartAsync, each form in a pcall. The mesh is asked for with the cheap fidelities (a box for
-- collision: nothing collides with it anyway; automatic rendering); an engine that does not know the options is asked again without them.
local function meshOptions()
 local ok,opts=pcall(function()return{CollisionFidelity=Enum.CollisionFidelity.Box,RenderFidelity=Enum.RenderFidelity.Automatic}end)
 return ok and opts or nil
end
local function askMesh(svc,arg)
 local opts=meshOptions()
 if opts then
  local ok,res=pcall(function()return svc:CreateMeshPartAsync(arg,opts)end)
  if ok then return res end
  local why=tostring(res):lower()
  if not(why:find('argument',1,true)or why:find('option',1,true)or why:find('expected',1,true)or why:find('cast',1,true))then error(res,0)end -- (a real failure is not asked twice)
 end
 return svc:CreateMeshPartAsync(arg)
end
function L.CreateMesh(meshId)
 local errs={}
 local tries={}
 local okC,content=pcall(function()return Content.fromUri(meshId)end)
 if okC and content~=nil then tries[#tries+1]={'AssetService',content}end
 tries[#tries+1]={'AssetService',meshId};tries[#tries+1]={'InsertService',meshId}
 for _,t in ipairs(tries)do
  local ok,res=timed(function()
   local svc=game:GetService(t[1])
   if svc.CreateMeshPartAsync==nil then error(t[1]..'.CreateMeshPartAsync does not exist')end
   return askMesh(svc,t[2])
  end)
  if ok and typeof(res)=='Instance'then return res end
  errs[#errs+1]=t[1]..': '..short(ok and'nothing returned'or res)
  if tostring(res):find('timed out',1,true)then break end -- (a hung request: not asked again)
 end
 return nil,table.concat(errs,'; ')
end

-- The owner's volcano as a template: a MeshPart of the file's size with its texture and colour.
local function volcanoTemplate()
 local def=Assets.Mesh.LavaVolcano
 local mp,why=L.CreateMesh(def.MeshId)
 if not mp then return nil,why end
 local ok,err=pcall(function()
  mp.TextureID=def.TextureId;mp.Size=V(def.Size[1],def.Size[2],def.Size[3]);mp.Color=Color3.fromRGB(def.Color[1],def.Color[2],def.Color[3]);mp.Name='Volcano'
  mp.Material=Enum.Material.Plastic
 end)
 if not ok then return nil,short(err)end
 return prepare(mp)
end
-- The key's template: {Kind='instance'|'specs'|'hills', Source=text, Protos=, Model=}, or nil and why. Cached per key (a rebuild reuses what was loaded).
local function build(map,key)
 local result,why
 local errs={}
 -- 1. hand-placed
 local hand=L.HandPlaced(key)
 if #hand>0 then
  local protos={}
  for _,src in ipairs(hand)do local p,e=prepare(src);if p then protos[#protos+1]=p else errs[#errs+1]=src.Name..': '..tostring(e)end end
  if #protos>0 then result={Kind='instance',Source='the model you put in ServerStorage.'..Assets.Folder,Protos=protos}end
 end
 -- 2. the owner's own files, built in
 if not result then
  if key=='DesertPyramid'then result={Kind='specs',Source='the owner\'s file (asset 9981304, '..Models.Pyramid.Count..' parts as data)',Model=Models.Pyramid}
  elseif key=='StormDarkMount'then result={Kind='specs',Source='the owner\'s dark mountain ('..Models.DarkMount.Count..' of '..Models.DarkMount.Cut.Of..' parts as data)',Model=Models.DarkMount}
  elseif key=='LavaVolcano'then
   local p,e=volcanoTemplate()
   if p then result={Kind='instance',Source='the owner\'s volcano (mesh '..Assets.Mesh.LavaVolcano.MeshId..', loaded by id)',Protos={p}}else errs[#errs+1]='mesh: '..tostring(e)end
  elseif key=='SnowMountains'then
   local meshes={};local ok=true
   for _,part in ipairs({'Grass','Stone','Trunk','Leaves'})do
    local mp,e=L.CreateMesh(Models.SnowHills.Mesh[part])
    if mp then meshes[part]=mp else ok=false;errs[#errs+1]='mesh '..part..': '..tostring(e);break end
   end
   if ok then result={Kind='hills',Source='the owner\'s Low Poly Island Hills (4 meshes loaded by id)',Meshes=meshes}end
  end
 end
 -- 3. the game's own models (its map's trees / crystals, and the hub's own trees)
 if not result then
  local sources=L.GameModels(map,key)
  local hub,hubWhy=L.HubModels(key)
  for _,e in ipairs(hub)do sources[#sources+1]=e end
  if hubWhy then errs[#errs+1]=hubWhy end
  local protos,labels={},{}
  for _,e in ipairs(sources)do
   local p,err=prepare(e.Model)
   if p then p.Label=e.Label;protos[#protos+1]=p;labels[#labels+1]=e.Label else errs[#errs+1]=e.Label..': '..tostring(err)end
  end
  if #protos>0 then result={Kind='instance',Source='the game\'s own model'..(#protos>1 and's'or'')..' ('..table.concat(labels,', ')..')',Protos=protos}end
 end
 -- 4. an asset id
 if not result then
  local id=Assets.Ids[key]
  if type(id)=='number'and id>0 then
   local m,e=L.LoadId(id)
   if m then local p,e2=prepare(m);if p then result={Kind='instance',Source='asset '..tostring(id),Protos={p}}else errs[#errs+1]='asset '..tostring(id)..': '..tostring(e2)end
   else
    if tostring(e):lower():find('not authorized',1,true)then errs[#errs+1]='asset '..tostring(id)..' can\'t be loaded (not your asset)'
    else errs[#errs+1]='asset '..tostring(id)..': '..tostring(e)end
   end
  end
 end
 if result then L.Cache[key]=result;return result end
 why=#errs>0 and table.concat(errs,'; ')or'no model yet'
 L.Cache[key]=false;L.Cache[key..'/why']=why
 return nil,why
end
-- One request at a time per key: while another thread is already loading this key (the volcano's swap in LavaVolcano158 and the background loader both want the owner's volcano), a
-- second caller waits for that answer (at most 5 x OuterTrackAssets158.LoadSeconds) instead of asking Roblox for the same mesh again.
L.Pending={}
function L.Template(map,key)
 local c=L.Cache[key]
 if c~=nil then if c==false then return nil,L.Cache[key..'/why']end;return c end
 if L.Pending[key]then
  local waited=0
  while L.Pending[key]and waited<Assets.LoadSeconds*5 do waited+=task.wait(.1)end
  c=L.Cache[key]
  if c==nil then return nil,'still loading'end
  if c==false then return nil,L.Cache[key..'/why']end
  return c
 end
 L.Pending[key]=true
 local ok,res,why=pcall(build,map,key)
 L.Pending[key]=nil
 if not ok then error(res,0)end
 return res,why
end
function L.Reset()L.Cache={}end

-- Placing -----------------------------------------------------------------------------------------------------------------------------------------
-- The spot's box once more (the data is checked by the tests; a model that would still reach the track or the hub is not placed).
function L.Allowed(slot)
 local b=Assets.Box(slot)
 if b[5]<HUB_Z then return false,'it would reach over the hub'end
 if b[5]>5990 then return true end -- behind the end wall
 if b[1]<MIN_X and b[2]>-MIN_X then return false,'it would reach inside |x| '..MIN_X end
 return true
end
function L.Finish(m,slot)
 local tint=slot.Tint
 for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then
  d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false
  d.CastShadow=Assets.Shadows==true and math.max(d.Size.X,d.Size.Y,d.Size.Z)>=20
  if tint then local c=d.Color;d.Color=Color3.new(math.min(1,c.R*tint[1]/255),math.min(1,c.G*tint[2]/255),math.min(1,c.B*tint[3]/255))end
 end end
end
-- Which of a key's models a spot gets: its Look (1, 2, 3 ... wrapping round the models there are), else the spot's number in its key (the models take turns).
function L.ProtoFor(tpl,slot,index)
 local n=#tpl.Protos
 return tpl.Protos[1+(((slot.Look or index)-1)%n)]
end
-- A clone of a prepared template, scaled to the spot's box, stood on the ground, turned and leaned (L.Finish then locks / tints it). Returns the Model (unparented).
function L.PlaceModel(proto,slot,name)
 local m=proto.Model:Clone();m.Parent=nil;m.Name=name
 local sz=proto.Size
 local k=math.min(slot.W/sz.X,slot.H/sz.Y,slot.D/sz.Z)
 m:ScaleTo(m:GetScale()*k)
 local centre,size=T.Box(m)
 local bottom=V(centre.X,centre.Y-size.Y/2,centre.Z)
 local tilt=math.rad(slot.Tilt or 0)
 local turn=CFrame.Angles(0,math.rad(slot.Yaw or 0),0)*CFrame.Angles(tilt,0,-tilt*.5)
 local sink=(slot.Sink or .3)+math.max(size.X,size.Z)/2*math.abs(math.sin(tilt)) -- (a leaning model is lowered so its high side still touches the ground)
 m:PivotTo(CF(slot.X,(slot.Y or Assets.Ground)-sink,slot.Z)*turn*CF(-bottom.X,-bottom.Y,-bottom.Z)*m:GetPivot())
 return m,k
end
-- The owner's part-built model (pyramid, dark mountain) as parts in a Model.
function L.PlaceSpecs(model,slot,name,group)
 local specs,k=Models.Specs(model,{X=slot.X,Z=slot.Z,Y=slot.Y or Assets.Ground,Fit={slot.W,slot.H,slot.D},Yaw=slot.Yaw,Mirror=slot.Mirror,Group=group,Name=name,Shadow=Assets.Shadows})
 local m=Instance.new('Model');m.Name=name
 for _,spec in ipairs(specs)do Walls.Make(spec).Parent=m end
 return m,k
end
-- The glow on a volcano's mouth: one small Neon ball (no lava stream).
local function addGlow(m,slot)
 local d=math.max(slot.W,slot.D)*.1
 local ball=Instance.new('Part');ball.Name='Crater glow';ball.Shape=Enum.PartType.Ball;ball.Size=V(d,d,d)
 ball.CFrame=CF(slot.X,(slot.Y or Assets.Ground)+slot.H*.96,slot.Z)
 ball.Color=Color3.fromRGB(255,120,44);ball.Material=Enum.Material.Neon
 ball.Anchored=true;ball.CanCollide=false;ball.CanTouch=false;ball.CanQuery=false;ball.CastShadow=false
 ball.Parent=m
end
-- The owner's snow hills: each hill a Grass cap and a Stone body (MeshParts cloned from the loaded meshes), the little trees re-placed UNEVENLY from a fixed seed per spot (some hills
-- bare, trees in clusters and on their own, sizes 0.7 - 1.45 x, a lean each) and mixed with the game's own snowy trees. Returns the Model (unparented).
function L.PlaceHills(tpl,slot,name,gameTrees,index)
 local H=Models.SnowHills
 local rng=Specs.Rng(158700+index*31)
 local k=slot.Scale or 1
 local m=Instance.new('Model');m.Name=name
 local ground=(slot.Y or Assets.Ground)-.3
 local origin=CF(slot.X,ground,slot.Z)*CFrame.Angles(0,math.rad(slot.Yaw or 0),0)
 local function mesh(kind,size,pos,color)
  local p=tpl.Meshes[kind]:Clone()
  p.Size=size;p.CFrame=origin*CF(pos);p.Color=Color3.fromRGB(color[1],color[2],color[3])
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Parent=m;return p
 end
 local trees=0
 for row in string.gmatch(H.Packed,'[^;]+')do
  local t={};for v in string.gmatch(row,'[^,]+')do t[#t+1]=tonumber(v)end
  local gs,gp=V(t[1],t[2],t[3])*k,V(t[4],t[5],t[6])*k
  local ss,sp=V(t[7],t[8],t[9])*k,V(t[10],t[11],t[12])*k
  mesh('Grass',gs,gp,H.Color.Grass);mesh('Stone',ss,sp,H.Color.Stone)
  -- trees: some hills bare, the others get a count by their size, in clusters or alone
  local top=gp.Y+gs.Y/2
  local area=(t[1]*t[3])
  local n=rng.chance(.28)and 0 or math.floor(area/rng.r(380,1000)+rng.r(0,1.2))
  local hx,hz=gs.X*.32,gs.Z*.32
  local placed={}
  while n>0 do
   local cx,cz=rng.r(-hx,hx),rng.r(-hz,hz)
   local group=rng.chance(.45)and math.min(n,rng.i(2,4))or 1
   for _=1,group do
    local px,pz=cx+(group>1 and rng.r(-5,5)*k or 0),cz+(group>1 and rng.r(-5,5)*k or 0)
    local ok=math.abs(px)<=hx*1.1 and math.abs(pz)<=hz*1.1
    for _,q in ipairs(placed)do if(q[1]-px)^2+(q[2]-pz)^2<(4.5*k)^2 then ok=false;break end end
    if ok then
     placed[#placed+1]={px,pz}
     local f=rng.r(.7,1.45)*k
     local lean=CFrame.Angles(math.rad(rng.r(-7,7)),math.rad(rng.r(0,360)),math.rad(rng.r(-7,7)))
     local base=CF(gp.X+px,top-.3*f,gp.Z+pz)*lean
     if gameTrees and #gameTrees>0 and rng.chance(.4)then
      -- one of the game's own snowy trees
      local proto=gameTrees[1+(trees%#gameTrees)]
      local h=rng.r(20,30)*f
      local tm=L.PlaceModel(proto,{X=0,Z=0,Y=0,Yaw=0,W=h*.55,H=h,D=h*.55,Sink=0},name..' tree',nil)
      tm:PivotTo(origin*base*tm:GetPivot())
      for _,d in ipairs(tm:GetDescendants())do if d:IsA('BasePart')then d.Parent=m end end
      tm:Destroy()
     else
      local trunk,leaves=H.Tree.Trunk,H.Tree.Leaves
      local p1=mesh('Trunk',V(trunk[1],trunk[2],trunk[3])*f,V(0,0,0),H.Color.Trunk)
      p1.CFrame=origin*base*CF(0,trunk[2]*f/2,0)
      local p2=mesh('Leaves',V(leaves[1],leaves[2],leaves[3])*f,V(0,0,0),H.Color.Leaves)
      p2.CFrame=origin*base*CF(H.Tree.LeafOffset[1]*f,trunk[2]*f/2+H.Tree.LeafOffset[2]*f,H.Tree.LeafOffset[3]*f)
     end
     trees+=1
    end
    n-=1
   end
  end
 end
 m:SetAttribute('Trees',trees)
 return m
end

-- Run ------------------------------------------------------------------------------------------------------------------------------------------------
local function backdropFolder(map,biome)
 local root=map:FindFirstChild(Walls.Folders.Backdrops);if not root then return nil end
 local f=root:FindFirstChild(biome)
 if not f then f=Instance.new('Folder');f.Name=biome;f.Parent=root end
 local models=f:FindFirstChild('Models')
 if not models then models=Instance.new('Folder');models.Name='Models';models.Parent=f end
 return models
end
-- Places every key's models. Returns the status table {Key = {Source=, Placed=, Parts=, Note=}}. (generation: Walls.Generation when the run was started; a rebuilt map stops an older run)
function L.Run(map,generation)
 generation=generation or Walls.Generation
 local root=map:FindFirstChild(Walls.Folders.Backdrops)
 if not root then return L.Status end
 for _,f in ipairs(root:GetChildren())do local old=f:FindFirstChild('Models');while old do old:Destroy();old=f:FindFirstChild('Models')end end
 L.Status={}
 local total=0
 for _,def in ipairs(Assets.Keys)do
  if Walls.Generation~=generation then return L.Status end
  local key=def.Key
  local st={Source=nil,Placed=0,Parts=0}
  L.Status[key]=st
  local tpl,why=L.Template(map,key)
  if Walls.Generation~=generation then return L.Status end
  if not tpl then
   st.Note=why
   if tostring(why):lower():find('not authorized',1,true)then note(key..': '..why..'; skipped')
   elseif why=='no model yet'then note(key..': no model yet (set OuterTrackAssets158.Ids.'..key..' or drag a model named '..key..' into ServerStorage.'..Assets.Folder..'); skipped')
   else note(key..': '..why..'; skipped (set OuterTrackAssets158.Ids.'..key..' or drag a model named '..key..' into ServerStorage.'..Assets.Folder..')')end
  else
   st.Source=tpl.Source
   local folder=backdropFolder(map,def.Biome)
   local slots=Assets.SlotsOf(key)
   local gameTrees
   if tpl.Kind=='hills'then
    local g=L.Template(map,'SnowTree');gameTrees=g and g.Protos
   end
   for i,slot in ipairs(slots)do
    local ok,reason=L.Allowed(slot)
    if not ok then st.Note=(st.Note and st.Note..'; 'or'')..'spot '..i..': '..reason
    else
     local name=key..' '..i
     local built,err=pcall(function()
      local m
      if tpl.Kind=='specs'then m=L.PlaceSpecs(tpl.Model,slot,name,'TrackBackdrops158/'..def.Biome)
      elseif tpl.Kind=='hills'then m=L.PlaceHills(tpl,slot,name,gameTrees,i)
      else
       local proto=L.ProtoFor(tpl,slot,i) -- (the spot's Look picks one of the key's models, else they take turns)
       m=L.PlaceModel(proto,slot,name)
       if proto.Label then m:SetAttribute('Model',proto.Label)end
       if slot.Glow then addGlow(m,slot)end
      end
      L.Finish(m,slot)
      m:SetAttribute('Key',key);m:SetAttribute('Spot',i)
      m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic -- (a tree, a mountain streams in whole: it never pops in half-built at the streaming edge)
      m.Parent=folder
      st.Placed+=1;st.Parts+=countParts(m)
     end)
     if not built then st.Note=(st.Note and st.Note..'; 'or'')..'spot '..i..': '..short(err)end
    end
   end
   total+=st.Parts
   note(string.format('%s: %d placed from %s (%d parts)%s',key,st.Placed,tpl.Source,st.Parts,st.Note and('; '..st.Note)or''))
  end
 end
 root:SetAttribute('ModelParts',total)
 root:SetAttribute('Ready',true)
 return L.Status
end
return L
