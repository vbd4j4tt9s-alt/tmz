--!nocheck
-- R153: every pack whose pouch is a template mesh, as a scene for check_pack_parts.py (R151's scene format: every part in the root's frame divided by the
-- pack's scale): the 42 designs (ground), the Void and the Mech on the ground and in an R15 hand, and a 25x giant. The pouch MeshParts are written too, so the
-- check can prove they sit on their template's PackLocalFrame (the frame the native render data is drawn in) before it reads the pouch's real surface.
local H=require('./pack_world');local W=H.W
W.module('PackShapes151').Config.Enabled=false -- (the default pouch: the shapes' crimps are test_pack_parts.luau's)
local function emit(label,bag,key)local sc=H.scene(bag,label);sc.attrs.Body=key;print('SCENE '..H.json(sc));bag:Destroy()end
for stage=1,7 do for i,variant in ipairs(H.ORDINARY)do
 local bag=H.ground(stage,variant,1,'None');emit(bag:GetAttribute('PackArtKey'),bag,bag:GetAttribute('PackArtKey'))
end end
emit('Giant25_Lava_06',H.ground(4,'Pack06',25,'Gold'),'Lava_06')
emit('Void',H.ground(7,H.VOID,1,'None'),'Forest_01')
local held,char=H.held(7,H.VOID,1,'None','R15');emit('Void_held',held,'Forest_01');char:Destroy()
emit('Void_25x',H.ground(7,H.VOID,25,'Diamond'),'Forest_01')
-- R153 (Mech look B, MechPackArt153): the Mech is measured on its OWN body, never Forest_01's: Body 'MechSachet' (the plain-parts sachet while no flat pouch
-- is baked: its Sachet* parts are the body) and Body 'MechPouch' (the server's generated flat pouch, VerityPouch151 baked on the EditableMesh mock: its
-- triangles, VerityPouch151.Generate placed on the pouch part's real frame, go with the scene as `pouch`). Ground, held R15 / R6, 25x. An older Mech (no
-- MechPouch attribute: the base side, R103's design) is on Forest_01 as before.
local function mech(label,bag)
 if bag:GetAttribute('MechPouch')==nil then emit(label,bag,'Forest_01');return false end
 local mesh=bag:GetAttribute('MechPouch')==true and bag:FindFirstChild('ApprovedMesh01',true)
 local sc=H.scene(bag,label);sc.attrs.Body=mesh and'MechPouch'or'MechSachet'
 if mesh then
  local scale=bag:GetAttribute('VisualScale')or 1;local rel=bag.PrimaryPart.CFrame:Inverse()*mesh.CFrame;local s=mesh.Size;local t=W.RS.SeedPackMeshAssets.Storm_02.ApprovedMesh01.Size
  local Pouch=W.module('VerityPouch151');local g=Pouch.Generate(t.X,t.Y,t.Z*Pouch.DepthShare);local v,f={},{}
  for i,p in ipairs(g.Vertices)do local q=rel*H.R.Vector3.new(p[1]*s.X/g.Extent[1],p[2]*s.Y/g.Extent[2],p[3]*s.Z/g.Extent[3]);v[i]={q.X/scale,q.Y/scale,q.Z/scale}end
  for i,tri in ipairs(g.Faces)do f[i]={tri[1]-1,tri[2]-1,tri[3]-1}end
  sc.pouch={v=v,f=f}
 end
 print('SCENE '..H.json(sc));bag:Destroy();return true
end
local function mechAll(tag)
 if not mech('Mech'..tag,H.ground(8,H.MECH,1,'None'))then return false end
 for _,kind in ipairs({'R15','R6'})do local b,c=H.held(8,H.MECH,1,'None',kind);mech('Mech'..tag..'_held'..kind,b);c:Destroy()end
 mech('Mech'..tag..'_25x',H.ground(8,H.MECH,25,'Diamond'))
 return true
end
if mechAll('')then
 local Mock=require('./pouch_mock')(W);local isS,isC=W.Run.IsServer,W.Run.IsClient
 W.Run.IsServer=function()return true end;W.Run.IsClient=function()return false end
 Mock.reset();local tpl=W.RS.SeedPackMeshAssets.Storm_02.ApprovedMesh01;tpl.MeshSize=tpl.Size
 local ok=W.module('VerityPouch151').Prepare();W.Run.IsServer,W.Run.IsClient=isS,isC
 assert(ok==true,'the flat pouch did not bake')
 mechAll('_pouch')
end
