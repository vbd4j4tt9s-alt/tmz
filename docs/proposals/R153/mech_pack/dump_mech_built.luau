--!nocheck
-- R153 Mech pack, as BUILT (look B): every part of the real pack the game builds (MechPackArt153 through SeedPackVisuals.Bag, on the REAL Forest_01 /
-- Storm_02 templates of the owner's place) on the server's generated flat pouch (VerityPouch151.Prepare, baked on the EditableMesh mock), in the root's
-- frame at scale 1, plus the pouch's own triangles (VerityPouch151.Generate, the same mesh the bake uploads) for render_mech_built.py.
-- Output: one "BUILT <json>" line {parts=[...] (R151 pack_world scene format), pouch={v=[[x,y,z]...], f=[[a,b,c]...]} (root frame, 0-based), held={...}}.
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
W.Run.IsServer=function()return true end;W.Run.IsClient=function()return false end
local Pouch=W.module('VerityPouch151')
local tpl=W.RS.SeedPackMeshAssets['Storm_02'].ApprovedMesh01;tpl.MeshSize=tpl.Size
Mock.reset();assert(Pouch.Prepare()==true,'the pouch did not bake')
local bag=H.Visuals.Bag(CF(0,0,0),W.workspace,1,nil,8,'MechLimited',1,1,'None',nil,true)
assert(bag:GetAttribute('MechPouch')==true,'not on the flat pouch')
local scene=H.scene(bag,'Mech')
-- the pouch's triangles: the generated mesh (its own origin = its centre) placed on the pouch part's PackLocalFrame
local mesh=bag:FindFirstChild('ApprovedMesh01',true)
local f=mesh:GetAttribute('PackLocalFrame');local s=mesh.Size
local g=Pouch.Generate(tpl.Size.X,tpl.Size.Y,tpl.Size.Z*Pouch.DepthShare)
local v={};for i,p in ipairs(g.Vertices)do local q=f*V3(p[1]*s.X/g.Extent[1],p[2]*s.Y/g.Extent[2],p[3]*s.Z/g.Extent[3]);v[i]={q.X,q.Y,q.Z}end
local fa={};for i,t in ipairs(g.Faces)do fa[i]={t[1]-1,t[2]-1,t[3]-1}end
-- the held fx (where the hum light and the antenna's sparks are: attachments on the pack)
local fx={}
for _,d in ipairs(bag:GetDescendants())do if d:IsA('Attachment')and(d.Name=='MechHum'or d.Name=='MechSparks')then
 local w=bag.PrimaryPart.CFrame:Inverse()*(d.Parent.CFrame*d.CFrame);fx[#fx+1]={name=d.Name,p={w.Position.X,w.Position.Y,w.Position.Z}}
end end
scene.pouch={v=v,f=fa,color={58,64,74}};scene.fx=fx;scene.count=#H.partsOf(bag,false)
print('BUILT '..H.json(scene))
