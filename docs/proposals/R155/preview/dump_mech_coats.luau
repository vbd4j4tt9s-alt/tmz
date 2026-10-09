--!nocheck
-- R155 Mech pack coats, as BUILT: the REAL modules (SeedPackVisuals.Bag, MechPackArt153, MechPackFx153, PlantVisuals) on the owner's templates, on VerityPouch151's generated flat pouch
-- (baked on the EditableMesh mock), dumped as parts for render_mech_coats.py. For each coat (plain / Gold / Diamond):
--   PACK  the pack on the ground (what the hotbar / Bag / Index / shop picture is built from), every part in the root's frame at scale 1 + the pouch's own triangles
--   HELD  the pack held (CarryBag welded to an R15 torso), the carrier's torso / head / root as boxes in the same frame
--   OPEN  the opening copy (SeedPackClient's clone) driven by MechPackFx153 to the third wobble pulse of a Mythic reveal: bolts backed out, the scan line in the hint colour
-- and the plants of a Gold and a Diamond Mech seed with their coated fruit (PlantVisuals.Build, a saved crop; the fruit's coat is the crop's own 20% roll), and the loose seeds.
-- Output: "ITEM <json>" lines.
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
if R.Vector3.one==nil then R.Vector3.one=V3(1,1,1)end -- (the mock has no Vector3.one; the plant's ellipsoids set their mesh scale from it)
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='SpecialMesh'then o.Offset=V3(0,0,0);o.Scale=V3(1,1,1)end;if class=='Sound'then o.Play=function()end;o.Stop=function()end end;return o end end -- (a SpecialMesh's defaults and a Sound that can play, which the bare mock does not have)
W.Run.IsServer=function()return true end;W.Run.IsClient=function()return false end
local Pouch=W.module('VerityPouch151')
local tpl=W.RS.SeedPackMeshAssets['Storm_02'].ApprovedMesh01;tpl.MeshSize=tpl.Size
Mock.reset();assert(Pouch.Prepare()==true,'the pouch did not bake')
local function fresh()for _,c in ipairs(W.workspace:GetChildren())do if c.Name~='Camera'and c.Name~='Terrain'then c:Destroy()end end end
local function pouchOf(bag)
 local mesh=bag:FindFirstChild('ApprovedMesh01',true)
 local f=mesh:GetAttribute('PackLocalFrame');local s=mesh.Size
 local g=Pouch.Generate(tpl.Size.X,tpl.Size.Y,tpl.Size.Z*Pouch.DepthShare)
 local v={};for i,p in ipairs(g.Vertices)do local q=f*V3(p[1]*s.X/g.Extent[1],p[2]*s.Y/g.Extent[2],p[3]*s.Z/g.Extent[3]);v[i]={q.X,q.Y,q.Z}end
 local fa={};for i,t in ipairs(g.Faces)do fa[i]={t[1]-1,t[2]-1,t[3]-1}end
 local function c255(c)return{math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
 return{v=v,f=fa,color=c255(mesh.Color),material=H.enumName(mesh.Material),t=mesh.Transparency,refl=mesh.Reflectance}
end
local function emit(kind,coat,scene,extra)
 scene.kind=kind;scene.coat=coat
 for k,v in pairs(extra or{})do scene[k]=v end
 print('ITEM '..H.json(scene))
end
local function charParts(char,root)
 local out={};local rootInv=root.CFrame:Inverse()
 for _,d in ipairs(char:GetChildren())do if d:IsA('BasePart')then -- (the carrier's own parts; the pack hangs under the character too)
  local f=rootInv*d.CFrame;local r=f.R
  out[#out+1]={name=d.Name,size={d.Size.X,d.Size.Y,d.Size.Z},p={f.Position.X,f.Position.Y,f.Position.Z},r={{r[1][1],r[1][2],r[1][3]},{r[2][1],r[2][2],r[2][3]},{r[3][1],r[3][2],r[3][3]}}}
 end end
 return out
end
local L=W.module('RarePullRules');local Fx=W.module('MechPackFx153')
for _,coat in ipairs({'None','Gold','Diamond'})do
 fresh()
 local bag=H.Visuals.Bag(CF(0,0,0),W.workspace,1,nil,8,'MechLimited',1,1,coat,nil,true)
 assert(bag:GetAttribute('MechPouch')==true,'not on the flat pouch')
 emit('pack',coat,H.scene(bag,'Mech'..coat),{pouch=pouchOf(bag),count=#H.partsOf(bag,false)})
 bag:Destroy()
 -- held
 fresh()
 local held,char,hrp,torso=H.held(8,H.MECH,1,coat,'R15')
 local fx={}
 for _,d in ipairs(held:GetDescendants())do if d:IsA('Attachment')and(d.Name=='MechHum'or d.Name=='MechSparks')then
  local w=held.PrimaryPart.CFrame:Inverse()*(d.Parent.CFrame*d.CFrame);fx[#fx+1]={name=d.Name,p={w.Position.X,w.Position.Y,w.Position.Z}}
 end end
 emit('held',coat,H.scene(held,'MechHeld'..coat),{pouch=pouchOf(held),char=charParts(char,held.PrimaryPart),fx=fx})
 -- the opening copy at the third wobble pulse of a Mythic reveal
 fresh()
 local bag2=H.ground(8,H.MECH,1,coat)
 local copy=H.openingCopy(bag2);copy.Parent=W.workspace
 local burst=L.BurstAt(5,false)
 local record={RarityRank=5,Quick=false,BurstAt=burst,TearTicks=L.TearTicks(5,false),FlapFrames={},BagTransparency={},Effect=W.workspace,Bag=bag2,At=0}
 local o=assert(Fx.Opening(copy,record),'no Mech opening')
 local pulses=L.Pulses(5,false);local t=pulses[3]+Fx.Scan.Seconds*.45;local at=0 -- (mid-sweep of the third scan line)
 while at<t do at=math.min(t,at+1/30);o:Update(at,copy.PrimaryPart.CFrame)end
 -- the scan line (a part in the effects folder) and the copy in one model, in the copy's root frame
 local wrap=R.new('Model');wrap.Name='OpeningFrame';wrap.Parent=W.workspace
 local scans=0
 for _,d in ipairs(W.workspace:GetDescendants())do if d:IsA('BasePart')and d.Name=='MechScan'and d.Transparency<1 then d.Parent=wrap;scans+=1 end end
assert(scans>0 and not o.Failed,'the scan line is not up at this moment of the opening')
 copy.Parent=wrap;wrap.PrimaryPart=copy.PrimaryPart
 bag2.Parent=nil
 emit('open',coat,H.scene(wrap,'Opening'..coat),{pouch=pouchOf(copy),at=t,scans=scans,hint={L.Hint(5,math.clamp(t/burst,0,1)).R,L.Hint(5,math.clamp(t/burst,0,1)).G,L.Hint(5,math.clamp(t/burst,0,1)).B}})
 o:Destroy();copy:Destroy()
end
-- the plants and their fruit: a Gold and a Diamond Plasma Pepper (3 fruit each), the loose seeds
fresh()
local Catalog=W.module('MechCatalog');local PlantVisuals=W.module('PlantVisuals');local PlantRules=W.module('PlantRules');local MechArt=W.module('MechArt');local Config=W.module('PlantCatalog')
local function crop(id,seed,coat,k)
 return {Id='preview_'..id..'_'..k,SeedId=seed,PlantScale=1,SeedScale=1,Mutation=coat,Weather='None',HarvestCycle=0,PickedMask=0,ReadyAt=0,MatureAt=0,PlantedAt=-100,TraitVersion=1}
end
local function pickCrop(seed,coat,wantCoated)
 local def=Config[seed]
 for k=1,2000 do
  local c=crop(seed,seed,coat,k);local n=0
  for i=1,def.FruitCount do if PlantRules.Fruit(c,i,def).Mutation==coat then n+=1 end end
  if n==wantCoated then return c,n end
 end
end
local function plantItem(seed,coat,wantCoated)
 local c,n=pickCrop(seed,coat,wantCoated);assert(c,'no crop with '..wantCoated..' coated fruit')
 local plant=PlantVisuals.Build(seed,CF(0,0,0),c,4,1e9);plant.Parent=W.workspace
 local def=Config[seed];local groups={}
 for i=1,def.FruitCount do groups[#groups+1]=PlantRules.Fruit(c,i,def).Mutation end
 emit('plant',coat,H.scene(plant,'Plant'..seed..coat),{seed=seed,fruit=groups,height=def.Height})
 plant:Destroy()
end
plantItem('PlasmaPepperSeed','Gold',1)
plantItem('PlasmaPepperSeed','Diamond',1)
for _,e in ipairs({{'PlasmaPepperSeed','Gold'},{'PlasmaPepperSeed','Diamond'},{'PlasmaPepperSeed','None'}})do
 local m=MechArt.BuildNative(e[1],CF(0,0,0),W.workspace,1,nil,e[2]);m.Parent=W.workspace
 local root=m.PrimaryPart;local parts={}
 emit('seed',e[2],H.scene(m,'Seed'..e[1]..e[2]),{seed=e[1]})
 m:Destroy()
end
