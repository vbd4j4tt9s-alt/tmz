-- R158 the Lava biome's volcano (owner: "use this volcano to replace our current volcano" with his model, asset 5138892863 (one MeshPart, mesh 5138886694, texture 5138888007), and
-- "yes remove the streams entirely" / "and the lava pool"). Built by MapService.new after the map passes and BEFORE the keyboard's skip scan (so the keys fill the floor where lava was):
--  1. NO LAVA STREAMS, NO LAVA POOLS. Everything that flowed or pooled in the Lava biome goes: the three magma channels of the volcano (V129), its molten crater, the lava river that ran from
--     it to its pond (PresentationV128/ContinuousLavaRiver: 413 parts, a pond at its end) and the V127 irregular magma pools (the two side pools the channels fed) and the three rocks of the pond's "Pool shore" (a shore of nothing now). These were scenery only:
--     no script damages, slows or respawns anyone on them (the only code that touched them is the visual builders, the client's LavaFlow animation and the keyboard's skip list), so no
--     gameplay rule goes with them. The ground under them is the plain biome floor (they were thin plates lying on it). The old pass backups in ServerStorage are not touched.
--  2. THE VOLCANO. The owner's model (OuterTrackLoader158.Template: a model he put in ServerStorage.OuterTrackAssets158.LavaVolcano, else the mesh loaded by id with
--     AssetService:CreateMeshPartAsync, else asset 5138892863) replaces the old cone, in the background (task.spawn: the request may take long or hang, and MapService.new must not wait
--     for it), at the same spot: scaled evenly until it fits the old cone's footprint (so nothing on the track
--     moves; it stands taller than the old 28.5, as his model is), walk-through like the old one (CanCollide / CanTouch off, CanQuery as before), no shadow. The old model's embers, smoke
--     and light (CraterVent) move to the new mouth. The new model keeps the name Biome4_Landmark and VolcanoVersion 129 (the V129 undo still finds it). With no model at all the old
--     cone stays (without its streams and its molten crater) and one plain note says so.
local Loader=require(script.Parent.OuterTrackLoader158)
local Assets=require(script.Parent.OuterTrackAssets158)
local RS=game:GetService('ReplicatedStorage')
local T=require(RS:WaitForChild('HubStudTrees151'))
local M={Version=158,Name='LavaVolcano158'}
local V,CF=Vector3.new,CFrame.new
-- What counts as a lava stream or pool (by name, under the Lava biome's own folders only).
local STREAM_NAMES={'^VolcanoMagmaChannel','^MoltenCrater$','^ContinuousLavaRiver$','^IrregularMagmaPools$','^MainMagmaPool$','^LavaPool','^Lava pool$','^LavaRiver','^Pool shore$'}
local function isStream(name)for _,p in ipairs(STREAM_NAMES)do if name:match(p)then return true end end;return false end
local function countParts(m)local n=m:IsA('BasePart')and 1 or 0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;return n end
local function find(map,path)local node=map;for name in path:gmatch('[^/]+')do node=node and node:FindFirstChild(name)end;return node end

-- Removes every lava stream and pool. Returns {Parts=, Things={name=count}}.
function M.RemoveLava(map)
 local out={Parts=0,Things={}}
 local function kill(inst)
  out.Parts+=countParts(inst);out.Things[inst.Name]=(out.Things[inst.Name]or 0)+1
  inst:Destroy()
 end
 -- the places the lava builders put them
 for _,root in ipairs({find(map,'PresentationV128'),find(map,'EnvironmentPolishV127'),find(map,'MythicLandmarks/Biome4_Landmark')})do
  if root then for _,c in ipairs(root:GetChildren())do if isStream(c.Name)then kill(c)end end end
 end
 -- anything left in the Lava biome's own folders (a place that still has the saved pool or river parts)
 local obby=map:FindFirstChild('Obby');local biomes=obby and obby:FindFirstChild('Biomes')
 if biomes then for _,b in ipairs(biomes:GetChildren())do
  if b.Name:sub(1,8)=='Biome_4_'then
   for _,d in ipairs(b:GetDescendants())do if d:IsDescendantOf(map)and(d:IsA('BasePart')or d:IsA('Model'))and isStream(d.Name)then kill(d)end end
  end
 end end
 -- the folders the river and the pools lived in are left empty on purpose (nothing reads them)
 return out
end

-- The ground's top under the volcano (the Lava biome's floor).
local function groundTop(map)
 local obby=map:FindFirstChild('Obby');local biomes=obby and obby:FindFirstChild('Biomes')
 if biomes then for _,b in ipairs(biomes:GetChildren())do
  if b.Name:sub(1,8)=='Biome_4_'then local g=b:FindFirstChild('BiomeGround_4');if g and g:IsA('BasePart')then return g.Position.Y+g.Size.Y/2 end end
 end end
 return 4
end
-- The old cone's footprint: x0, x1, z0, z1 of its cone parts (slopes and crater lip), or nil.
local function footprint(old)
 local x0,x1,z0,z1
 for _,d in ipairs(old:GetChildren())do if d:IsA('BasePart')and(d.Name=='BasaltSlope'or d.Name=='CraterLip')then
  local c,s=d.CFrame,d.Size
  local ex=(math.abs(c.RightVector.X)*s.X+math.abs(c.UpVector.X)*s.Y+math.abs(c.LookVector.X)*s.Z)/2
  local ez=(math.abs(c.RightVector.Z)*s.X+math.abs(c.UpVector.Z)*s.Y+math.abs(c.LookVector.Z)*s.Z)/2
  local p=c.Position
  x0=x0 and math.min(x0,p.X-ex)or p.X-ex;x1=x1 and math.max(x1,p.X+ex)or p.X+ex
  z0=z0 and math.min(z0,p.Z-ez)or p.Z-ez;z1=z1 and math.max(z1,p.Z+ez)or p.Z+ez
 end end
 return x0,x1,z0,z1
end

-- The radius of the biggest circle round (cx, cz) that the old cone's parts cover completely (each part's footprint as the keyboard's skip scan reads it: KeyboardSkip152.Footprint), at most
-- rmax: the keys under a circle that lies wholly inside the old cone were left out for the old cone too. Parts that do not stand on the floor (the crater lip, up in the air) do not count,
-- as in the scan. Measured from the old cone's own parts, before they are destroyed.
local function coveredRadius(old,cx,cz,ground,rmax)
 local ok,Skip=pcall(function()return require(RS:WaitForChild('KeyboardSkip152'))end)
 if not ok or type(Skip)~='table'then return 0 end
 local fps={}
 for _,d in ipairs(old:GetDescendants())do if d:IsA('BasePart')and d.Transparency<.95 then
  local fp=Skip.Footprint(d)
  if fp and fp.Y0<=ground+1.2 and fp.Y1>=ground+.3 then fps[#fps+1]=fp end
 end end
 local function covered(x,z)for _,fp in ipairs(fps)do if Skip.Covers(fp,x,z)then return true end end;return false end
 local r=0
 while r<rmax do
  local nr=math.min(rmax,r+1)
  for k=0,31 do local a=k/32*2*math.pi;if not covered(cx+math.cos(a)*nr,cz+math.sin(a)*nr)then return r end end
  r=nr
 end
 return r
end

-- Removes the streams and pools at once (nothing in it waits), then swaps the volcano in the BACKGROUND: the model comes from a request that may take a while (or hang: up to
-- OuterTrackAssets158.LoadSeconds for the mesh and again for each asset form), so MapService.new never waits for it (the R153 boot rule: asset loads are spawned). The old cone stays
-- until the model is there; if it never comes the old cone stays for good. The keyboard's skip scan (KeyboardSkip152) runs on the boot thread right after this, on the old cone.
-- Returns {Removed=, Replaced=, Pending=, Why=, Scale=, Height=}: Pending is true until the background swap has answered (Replaced / Why are filled in then).
function M.Apply(map)
 local res={Removed=M.RemoveLava(map),Replaced=false}
 local landmarks=map:FindFirstChild('MythicLandmarks')
 local old=landmarks and landmarks:FindFirstChild('Biome4_Landmark')
 local removedText=string.format('removed %d lava stream / pool parts (%s)',res.Removed.Parts,(function()local t={};for k,v in pairs(res.Removed.Things)do t[#t+1]=k..' x'..v end;table.sort(t);return table.concat(t,', ')end)())
 if not old then res.Why='no volcano on the map';print('[R158 volcano] '..removedText..'; there is no volcano to replace');return res end
 if old:GetAttribute('Volcano158')then res.Replaced=true;res.Already=true;print('[R158 volcano] '..removedText..'; the owner\'s volcano is already there');return res end
 res.Pending=true
 task.spawn(function()
  local ok,err=pcall(M.Swap,map,old,res,removedText)
  res.Pending=false
  if not ok then res.Why=tostring(err);print('[R158 volcano] '..removedText..'; the volcano swap failed ('..tostring(err)..'): the old cone stays')end
 end)
 return res
end

-- The swap itself (runs in its own thread: the template request may wait). `old` = the old cone's model.
function M.Swap(map,old,res,removedText)
 local landmarks=map:FindFirstChild('MythicLandmarks')
 local tpl,why=Loader.Template(map,'LavaVolcano')
 if old.Parent~=landmarks or old:GetAttribute('Volcano158')then return end -- (the map was rebuilt, or another swap got there first, while the model loaded)
 if not tpl or tpl.Kind~='instance'then
  res.Why=why or'no model yet'
  print('[R158 volcano] '..removedText..'; the old cone stays (the owner\'s volcano: '..tostring(res.Why)..'; set OuterTrackAssets158.Ids.LavaVolcano or drag a model named LavaVolcano into ServerStorage.'..Assets.Folder..')')
  return
 end
 local x0,x1,z0,z1=footprint(old)
 if not x0 then res.Why='the old volcano has no cone parts';print('[R158 volcano] '..removedText..'; '..res.Why);return end
 local ground=groundTop(map)
 local slot={X=(x0+x1)/2,Z=(z0+z1)/2,Yaw=0,W=x1-x0,H=60,D=z1-z0,Y=ground}
 local disc=coveredRadius(old,slot.X,slot.Z,ground,math.min(x1-x0,z1-z0)/2)
 local ok,err=pcall(function()
  local placed,k=Loader.PlaceModel(tpl.Protos[1],slot,'Volcano')
  Loader.Finish(placed,slot)
  local new=Instance.new('Model');new.Name='Biome4_Landmark';new.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  new:SetAttribute('VolcanoVersion',129);new:SetAttribute('Volcano158',true)
  local centre,size=T.Box(placed)
  for _,d in ipairs(placed:GetDescendants())do if d:IsA('BasePart')then
   d.CanQuery=true;d.Parent=new -- (walk-through like the old one: CanCollide / CanTouch off, queryable)
   -- A mesh is ONE part whose box is the whole footprint's square: the keyboard's skip scan would leave out the keys under its square corners, where the old cone's slopes were
   -- not. It reads KeyboardDisc (KeyboardSkip152.Footprint) instead: the round footprint the old cone's own parts cover (measured above, before they are destroyed).
   if d:IsA('MeshPart')then d:SetAttribute('KeyboardDisc',math.max(.5,disc))end
  end end
  local root=Instance.new('Part');root.Name='VolcanoRoot';root.Size=V(.1,.1,.1);root.CFrame=CF(slot.X,ground,slot.Z);root.Transparency=1
  root.Anchored=true;root.CanCollide=false;root.CanTouch=false;root.CastShadow=false;root.Parent=new;new.PrimaryPart=root
  local vent=old:FindFirstChild('CraterVent')
  if vent and vent:IsA('BasePart')then local v=vent:Clone();v.CFrame=CF(slot.X,centre.Y+size.Y/2-.5,slot.Z);v.Parent=new end
  new:SetAttribute('Scale',k)
  res.Scale=k;res.Height=size.Y;res.Footprint={x0,x1,z0,z1}
  old:Destroy()
  new.Parent=landmarks
 end)
 if not ok then res.Why=tostring(err);print('[R158 volcano] '..removedText..'; the volcano swap failed ('..tostring(err)..'): the old cone stays');return end
 res.Replaced=true
 print(string.format('[R158 volcano] %s; the volcano is %s, scaled %.3f to the old footprint (%.0f x %.0f studs), %.1f tall',removedText,tpl.Source,res.Scale,x1-x0,z1-z0,res.Height))
end
return M
