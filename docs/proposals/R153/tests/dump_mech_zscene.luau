--!nocheck
-- R153 z-fighting, the Mech pack (look B; not a test by itself: check_zfight_sweep.py mech reads it). The pack exactly as the game builds it on the REAL
-- templates of the owner's place: on the server's generated flat pouch (VerityPouch151.Prepare baked on the EditableMesh mock, its real triangles dumped) in
-- every context it is drawn - ground, held (R15 / R6), a picture - at a normal, a giant and a tiny size, plain and Gold / Diamond; on its plain-parts body
-- (no pouch made; R155: plain, Gold, Diamond); and its opening copy (MechPackFx153) with the bolts backed out, a scan line sweeping and the steam up, at five moments of a Mythic reveal
-- (R155: plain, Gold and Diamond).
-- Output: "SCENE <name> <json>" lines in the zfight.py scene format (parts, "meshes": the baked pouch's world-space triangles).
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local Run=W.Run
Run.IsServer=function()return true end;Run.IsClient=function()return false end
W.module('PackShapes151').Config.Enabled=false
local Pouch=W.module('VerityPouch151')
local assets=W.RS.SeedPackMeshAssets;local tpl=assets['Storm_02'].ApprovedMesh01;tpl.MeshSize=tpl.Size
Mock.reset()
assert(Pouch.Prepare()==true,'the pouch did not bake')
local Z=require('./zfight_world')
-- R155: the opening's hiss is a Sound the bare mock cannot play: MechPackFx153 would stop at its first tear group (Failed, by design: one bad frame stops only the Mech touch) and
-- every "opening" frame below would be an unmoved copy. A Sound that can play lets the bolts, the turbine, the stripes and the scan line really move through the frames.
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='Sound'then o.Play=function()end;o.Stop=function()end end;return o end end
local function q(s)return string.format('%q',tostring(s))end
local function dumpScene(name,root)
 local list=Z.dump(root,function()return'mech'end)
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
   local tri={};for i,f in ipairs(c.F)do tri[i]=string.format('[%d,%d,%d]',f[1]-1,f[2]-1,f[3]-1)end
   extra[#extra+1]=string.format('{"path":%s,"v":[%s],"f":[%s]}',q(Z.path(d)),table.concat(pts,','),table.concat(tri,','))
  end
 end
 print('SCENE '..name..' {"parts":['..table.concat(list,',')..'],"meshes":['..table.concat(extra,',')..']}')
end
local function fresh()for _,c in ipairs(W.workspace:GetChildren())do if c.Name~='Camera'and c.Name~='Terrain'then c:Destroy()end end end
local contexts={
 {'ground',function(size,coat)return H.ground(8,H.MECH,size,coat)end},
 {'held15',function(size,coat)return(H.held(8,H.MECH,size,coat,'R15'))end},
 {'held6',function(size,coat)return(H.held(8,H.MECH,size,coat,'R6'))end},
 {'picture',function(size,coat)local bag=H.picture(8,H.MECH,size,coat);bag.Parent=W.workspace;return bag end},
}
for _,size in ipairs({1,25,.5})do for _,coat in ipairs({'None','Gold','Diamond'})do
 if size==1 or coat=='None'then
  for _,ctx in ipairs(contexts)do
   fresh()
   local bag=ctx[2](size,coat)
   assert(bag:GetAttribute('MechPouch')==true,'the Mech pack is not on the flat pouch: '..ctx[1])
   dumpScene(string.format('%s_%s_%s',ctx[1],tostring(size),coat),W.workspace)
  end
 end
end end
-- the opening copy (SeedPackClient's clone: welds gone, every part anchored) driven by MechPackFx153 through a Mythic reveal: bolts out, the turbine turning,
-- the scan line on a pulse, the stripes with their strips, the steam ring. R155: also in the Gold and the Diamond coat (a coated Mech pack is opened the same way)
for _,openingCoat in ipairs({'None','Gold','Diamond'})do
 local L=W.module('RarePullRules');local Fx=W.module('MechPackFx153')
 fresh();local bag=H.ground(8,H.MECH,1,openingCoat)
 local copy=H.openingCopy(bag);copy.Parent=W.workspace
 local burst=L.BurstAt(5,false)
 local record={RarityRank=5,Quick=false,BurstAt=burst,TearTicks=L.TearTicks(5,false),FlapFrames={},BagTransparency={},Effect=W.workspace,Bag=bag,At=0}
 local o=assert(Fx.Opening(copy,record),'no Mech opening')
 local pulses=L.Pulses(5,false)
 local times={.05,pulses[1]+.12,pulses[3]+.05,burst-.05,burst+.1}
 local frames={}
 for _,t in ipairs(times)do
  -- frames run in order up to t (the cues fire on their beats)
  local at=frames[#frames]or 0
  while at<t do at=math.min(t,at+1/30);o:Update(at,copy.PrimaryPart.CFrame)end
  assert(not o.Failed,'the Mech opening failed at t='..t)
  frames[#frames+1]=t
  bag.Parent=nil
  dumpScene(string.format('opening_%.2f%s',t,openingCoat=='None'and''or'_'..openingCoat),W.workspace)
  bag.Parent=W.workspace
 end
 o:Destroy();copy:Destroy();bag:Destroy()
end
-- the plain-parts body (no flat pouch: a server still baking, a world without EditableMesh); R155: plain, Gold and Diamond
do
 local f=W.RS:FindFirstChild(Pouch.Folder);if f then f:Destroy()end
 for _,coat in ipairs({'None','Gold','Diamond'})do
  for _,ctx in ipairs(contexts)do
   fresh()
   local bag=ctx[2](1,coat)
   assert(bag:GetAttribute('MechPouch')==false,'the fallback is not the sachet: '..ctx[1])
   dumpScene('sachet_'..ctx[1]..(coat=='None'and''or'_'..coat),W.workspace)
  end
  for _,size in ipairs({25,.5})do fresh();H.ground(8,H.MECH,size,coat);dumpScene('sachet_ground_'..size..(coat=='None'and''or'_'..coat),W.workspace)end
 end
end
