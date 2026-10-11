--!nocheck
-- R152 z-fighting, the Verity pack (not a test by itself; check_verity_zfight.py reads it): the generated flat pouch pack exactly as the game builds it (VerityPouch151.Prepare bakes the
-- pouch on the EditableMesh mock, VerityPackArt builds the pack on the REAL Storm_02 template of the owner's place) in every context it is drawn - ground, held (R15 / R6), in a
-- picture, the opening copy, the market display - at a normal size, a giant and a tiny one, plain and with a Gold / Diamond coat, dumped in the zfight.py scene format with the pouch's
-- real triangles (the mock records what was baked) so the check can look at the flat faces, the crimped seal and the strips, not at a bounding box.
-- Output: "SCENE <name> <json>" lines (parts, with "tris" for a baked mesh: world-space triangles) and a "FACES" line per pack: every Decal / Texture / SurfaceGui on a face.
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local Run=W.Run
Run.IsServer=function()return true end;Run.IsClient=function()return false end
W.module('PackShapes151').Config.Enabled=false
local Pouch=W.module('VerityPouch151');local Art=W.module('VerityPackArt')
local assets=W.RS.SeedPackMeshAssets;local tpl=assets['Storm_02'].ApprovedMesh01;tpl.MeshSize=tpl.Size
Mock.reset()
assert(Pouch.Prepare()==true,'the pouch did not bake')
local Z=require('./zfight_world')
local out={}
local function q(s)return string.format('%q',tostring(s))end
local function dumpScene(name,root)
 local list=Z.dump(root,function()return'verity'end)
 -- the baked triangles of every MeshPart (world space): the part's CFrame x its mesh vertices (centred on the part, scaled to its Size)
 local extra={}
 for _,d in ipairs(root:GetDescendants())do
  if d:IsA('MeshPart')and d._props.MeshContent then
   local c=d._props.MeshContent;local cf=d._props.CFrame;local s=d._props.Size
   local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
   for _,v in ipairs(c.V)do for a=1,3 do lo[a]=math.min(lo[a],v[a]);hi[a]=math.max(hi[a],v[a])end end
   local ms={hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]};local ctr={(lo[1]+hi[1])/2,(lo[2]+hi[2])/2,(lo[3]+hi[3])/2}
   local pts={}
   for i,v in ipairs(c.V)do
    local p=cf*V3((v[1]-ctr[1])/ms[1]*s.X,(v[2]-ctr[2])/ms[2]*s.Y,(v[3]-ctr[3])/ms[3]*s.Z)
    pts[i]=string.format('[%.5f,%.5f,%.5f]',p.X,p.Y,p.Z)
   end
   local tri={}
   for i,f in ipairs(c.F)do tri[i]=string.format('[%d,%d,%d]',f[1]-1,f[2]-1,f[3]-1)end
   extra[#extra+1]=string.format('{"path":%s,"v":[%s],"f":[%s]}',q(Z.path(d)),table.concat(pts,','),table.concat(tri,','))
  end
 end
 print('SCENE '..name..' {"parts":['..table.concat(list,',')..'],"meshes":['..table.concat(extra,',')..']}')
end
local function fresh()for _,c in ipairs(W.workspace:GetChildren())do if c.Name~='Camera'and c.Name~='Terrain'then c:Destroy()end end end
local contexts={
 {'ground',function(size,coat)return H.ground(7,H.VERITY,size,coat)end},
 {'held15',function(size,coat)local bag=H.held(7,H.VERITY,size,coat,'R15');return bag end},
 {'held6',function(size,coat)local bag=H.held(7,H.VERITY,size,coat,'R6');return bag end},
 {'picture',function(size,coat)local bag=H.picture(7,H.VERITY,size,coat);bag.Parent=W.workspace;return bag end},
}
for _,size in ipairs({1,25,.5})do for _,coat in ipairs({'None','Gold','Diamond'})do
 if size==1 or coat=='None'then
  for _,ctx in ipairs(contexts)do
   fresh()
   local bag=ctx[2](size,coat)
   if bag then
    assert(bag:GetAttribute('VerityPouch')==true,'the pack is not the pouch: '..ctx[1])
    dumpScene(string.format('%s_%s_%s',ctx[1],tostring(size),coat),W.workspace)
   end
  end
 end
end end
-- the fallback (the R149 sachet: plain parts, the face Decals on a block): used when the pouch could not be baked or is not ready yet
do
 local f=W.RS:FindFirstChild(Pouch.Folder);if f then f:Destroy()end
 for _,ctx in ipairs(contexts)do
  fresh()
  local bag=ctx[2](1,'None')
  assert(bag:GetAttribute('VerityPack')==true and bag:GetAttribute('VerityPouch')~=true,'the fallback is not the sachet: '..ctx[1])
  dumpScene('sachet_'..ctx[1],W.workspace)
 end
end
