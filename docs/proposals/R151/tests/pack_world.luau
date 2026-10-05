--!nocheck
-- R151 pack-models audit: the shared mock world of test_packs.luau / dump_packs.luau.
--  * the Roblox mock (tools/tests/roblox.luau + inventory_R113/tests/world.luau) with the REAL ReplicatedStorage modules and client scripts of the
--    checkout (rs_bundle.luau, mkbundle_packs.py) and the REAL pack templates of the owner's place (pack_templates.luau: 42 designs, 115 MeshParts);
--  * every context a pack is built in, each exactly the way the game builds it (the call sites are named in the comments):
--      ground / dropped  SeedPackVisuals.Bag(origin, parent, 1, nil, ...)            ChestService.BuildSeedPacket (world slots), ChaseService (drops)
--      held / carried    SeedPackVisuals.CarryBag(character, ...)                     ChaseService._createCarriedChest, ChestService._holdPack
--      picture           SeedPackVisuals.Bag(Angles(0,.22,-.025), nil, ...) + the real ItemPictures sanitising / ViewportFrame   (hotbar, Bag, Index, shop)
--      opening copy      the held bag cloned, welds removed, parts anchored            SeedPackClient.beginReveal (read only here)
--      market display    SeedPackVisuals.Bag(CFrame.new(), nil, ...) + MarketLayout.settle (anchored, untagged, scaled / pivoted)
--      mystery pedestal  SeedPackVisuals.Bag(anchor, holder, 1.7, ...) + the Locked silhouette   MysteryPackService._look
--      title / mech preview  Bag(..., WorldModel, ...)                                TitleScreen104, PackViewport89
--  * an assembly solver for WeldConstraint / Motor6D (the mock has no physics): where every part of a bag ends up when its torso moves.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
-- Clone in the mock keeps neither a Model's attributes nor its PrimaryPart (Roblox's keeps both): deep clone that does.
function W.deepClone(inst)
 local c=inst:Clone()
 local function copy(a,b)
  for k,v in pairs(a:GetAttributes())do b:SetAttribute(k,v)end
  local ac,bc=a:GetChildren(),b:GetChildren()
  for i,x in ipairs(ac)do if bc[i]then copy(x,bc[i])end end
 end
 copy(inst,c)
 if inst.PrimaryPart then
  local list=inst:GetDescendants();local copyList=c:GetDescendants()
  for i,d in ipairs(list)do if d==inst.PrimaryPart then c.PrimaryPart=copyList[i]end end
 end
 return c
end
local templates=require('./pack_templates')(W) -- the REAL templates (replaces fixtures.packAssets)
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=151;player.Parent=Players;Players.LocalPlayer=player
local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
local H={W=W,R=R,F=F,templates=templates}
H.Visuals=W.module('SeedPackVisuals');H.Rules=W.module('SeedPackRules');H.Cat=W.module('VerityCatalog')
H.VERITY=H.Cat.Variant;H.VOID='EclipseReliquary';H.MECH='MechLimited'
H.CS=W.CS;H.pg=pg
-- Every build the game can ask for ---------------------------------------------------------------------------------------------------------------
H.STAGES={1,2,3,4,5,6,7} -- Forest, Desert, Snow, Lava, Crystal, Jungle, Storm (SeedPackRules.DesignBiomes)
H.BIOMES={'Forest','Desert','Snow','Lava','Crystal','Jungle','Storm'}
H.ORDINARY={'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06'}
H.LEGACY={'Small','Standard','Grand'} -- saved inventories may still hold these (they use designs 1 / 2 / 3)
H.SIZES={.5,1,1.5,2.5,3.5,5,7.5,10,15,20,25} -- BalanceRules.PackSizes, giants above 10
H.COATS={'None','Gold','Diamond'}
-- Characters -----------------------------------------------------------------------------------------------------------------------------------
-- A carrier: R15 (UpperTorso) or R6 (Torso), each with a HumanoidRootPart, in the workspace.
function H.character(kind,at)
 at=at or CF(0,5,0)
 local c=R.new('Model');c.Name='Carrier_'..kind;c.Parent=W.workspace
 local hrp=R.new('Part');hrp.Name='HumanoidRootPart';hrp.Size=V3(2,2,1);hrp.CFrame=at;hrp.Anchored=false;hrp.Parent=c
 local torso=R.new('Part');torso.Name=kind=='R6'and'Torso'or'UpperTorso';torso.Size=V3(2,kind=='R6'and 2 or 1.6,1);torso.CFrame=at*CF(0,kind=='R6'and 0 or .4,0);torso.Anchored=false;torso.Parent=c
 for _,n in ipairs({'Head'})do local p=R.new('Part');p.Name=n;p.Size=V3(2,1,1);p.CFrame=at*CF(0,1.5,0);p.Anchored=false;p.Parent=c end
 local w=R.new('WeldConstraint');w.Part0=hrp;w.Part1=torso;w.Parent=torso
 c.PrimaryPart=hrp
 return c,hrp,torso
end
-- Visible geometry helpers ---------------------------------------------------------------------------------------------------------------------
function H.partsOf(bag,includeRoot)
 local out={};for _,d in ipairs(bag:GetDescendants())do if d:IsA('BasePart')and(includeRoot or d~=bag.PrimaryPart)then out[#out+1]=d end end;return out
end
local function mulv(cf,v)return cf*v end
-- Contexts ---------------------------------------------------------------------------------------------------------------------------------------
local ground_n=0
-- on the ground (a world slot) / dropped: anchored, in the workspace.
function H.ground(stage,variant,size,coat,parent)
 ground_n+=1
 return H.Visuals.Bag(CF(10+ground_n%7*6,10,20+ground_n%5*6)*R.CFrame.Angles(0,.4,0),parent or W.workspace,1,nil,stage,variant,1,size,coat or'None')
end
-- held: CarryBag welded to the carrier's torso (what ChaseService / ChestService._holdPack build).
function H.held(stage,variant,size,coat,kind)
 local char,hrp,torso=H.character(kind or'R15')
 local bag=H.Visuals.CarryBag(char,stage,variant,1,size,coat or'None')
 return bag,char,hrp,torso
end
-- picture: what ItemPictures builds for a hotbar / Bag / Index / shop picture: a rotated, unparented bag.
function H.picture(stage,variant,size,coat)
 return H.Visuals.Bag(R.CFrame.Angles(0,.22,-.025),nil,1,nil,stage,variant,1,size,coat or'None')
end
-- the picture after ItemPictures' own sanitising (every tag removed, parts under .95 transparency destroyed, all anchored, joints destroyed):
-- the same function as ItemPictures' local `sanitize` (kept in step with it by test_packs.luau's source check).
function H.sanitized(model)
 local Tags=W.CS;local keep={DataModelMesh=true,SurfaceAppearance=true,Decal=true,Model=true,Folder=true}
 for _,tag in ipairs(Tags:GetTags(model))do Tags:RemoveTag(model,tag)end
 for _,item in ipairs(model:GetDescendants())do
  if item.Parent then
   for _,tag in ipairs(Tags:GetTags(item))do Tags:RemoveTag(item,tag)end
   if item:IsA('BasePart')then
    if item.Transparency>=.95 then item:Destroy()
    else item.Anchored=true;item.CanCollide=false;item.CanQuery=false;item.CanTouch=false;item.CastShadow=false end
   else
    local allowed=false;for class in pairs(keep)do if item:IsA(class)then allowed=true;break end end
    if not allowed then item:Destroy()end
   end
  end
 end
 return model
end
-- the opening copy: SeedPackClient.beginReveal's clone (welds / motors removed, every part anchored).
function H.openingCopy(bag)
 local copy=W.deepClone(bag);copy.Name='OpeningBag';copy:SetAttribute('RevealAt',nil)
 for _,item in ipairs(copy:GetDescendants())do
  if item:IsA('WeldConstraint')or item:IsA('Motor6D')then item:Destroy()
  elseif item:IsA('ParticleEmitter')or item:IsA('PointLight')then item.Enabled=false
  elseif item:IsA('BasePart')then item.Anchored=true;item.LocalTransparencyModifier=0 end
 end
 return copy
end
-- market display: MarketLayout.settle's treatment (anchored, collision off, tags removed) and a pivot; the scale is a pure ScaleTo (rigid), which
-- the checks apply as a factor.
function H.market(stage,variant)
 local m=H.Visuals.Bag(CF(0,0,0),nil,1,nil,stage,variant,1,1,'None')
 for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false end end
 for _,d in ipairs({m,table.unpack(m:GetDescendants())})do for _,tag in ipairs(W.CS:GetTags(d))do W.CS:RemoveTag(d,tag)end end
 return m
end
-- mystery pedestal: the pack at scale 1.7 on the anchor; Locked = black silhouette (MysteryPackService._look), Ready = the real pack.
local SILHOUETTE=R.Color3.fromRGB(8,8,12)
function H.mystery(stage,variant,locked)
 local holder=R.new('Model');holder.Name='MysteryPack';holder.Parent=W.workspace
 local pack=H.Visuals.Bag(CF(0,6,0),holder,1.7,nil,stage,locked and'Pack01'or variant,1,1,'None')
 W.CS:RemoveTag(pack,'BiomeSeedPackVisual');pack:SetAttribute('MysteryOrigin',CF(0,6,0))
 if locked then
  for _,d in ipairs(pack:GetDescendants())do
   if d:IsA('SurfaceAppearance')or d:IsA('Decal')or d:IsA('Texture')or d:IsA('ParticleEmitter')or d:IsA('Light')then d:Destroy()
   elseif d:IsA('BasePart')and d.Transparency<1 then
    d.Color=SILHOUETTE;d.Material=R.Enum.Material.SmoothPlastic;d.MaterialVariant='';d.Reflectance=0
    if d:IsA('MeshPart')then d.TextureID=''end
   end
  end
 end
 return pack,holder
end
-- title / mech preview: Bag(...) into a WorldModel of a ViewportFrame.
function H.viewport(stage,variant,size,coat,origin)
 local vf=R.new('ViewportFrame');local wm=R.new('WorldModel');wm.Parent=vf
 local bag=H.Visuals.Bag(origin or R.CFrame.Angles(0,.15,-.12),wm,1,nil,stage,variant,1,size or 1,coat or'None')
 W.CS:RemoveTag(bag,'BiomeSeedPackVisual');bag:SetAttribute('WorldPack',false)
 return bag,vf
end
-- Assembly solver ------------------------------------------------------------------------------------------------------------------------------
-- Roblox keeps a WeldConstraint's two parts at the offset they have when the weld is live (Part0, Part1 set and both in the workspace); a Motor6D
-- puts Part1 at Part0 * C0 * C1:Inverse(). `bind` records the weld offsets of a bag as it stands (call it once the bag is parented, as Roblox does) and
-- returns a graph; `pose` computes every part's CFrame when `moving` (a part) is at `at`, anchored parts staying where they are.
local function inv(c)return c:Inverse()end
function H.bind(models,extraParts)
 local g={parts={},edges={},adj={},anchored={},init={},motors={}}
 local function addPart(p)if not g.init[p]then g.parts[#g.parts+1]=p;g.init[p]=p.CFrame;g.adj[p]={};g.anchored[p]=p.Anchored end end
 for _,m in ipairs(models)do for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then addPart(d)end end end
 for _,p in ipairs(extraParts or{})do addPart(p)end
 local function edge(a,b,rel,why)
  if not a or not b then return end
  addPart(a);addPart(b)
  g.edges[#g.edges+1]={A=a,B=b,Rel=rel,Why=why}
  table.insert(g.adj[a],{To=b,Rel=rel});table.insert(g.adj[b],{To=a,Rel=inv(rel)})
 end
 local function scan(root)
  for _,d in ipairs(root:GetDescendants())do
   if d:IsA('WeldConstraint')then
    if d.Enabled~=false and d.Part0 and d.Part1 then edge(d.Part0,d.Part1,inv(d.Part0.CFrame)*d.Part1.CFrame,'weld')end
   elseif d:IsA('Motor6D')then
    if d.Enabled~=false and d.Part0 and d.Part1 then
     local rel=d.C0*inv(d.C1);edge(d.Part0,d.Part1,rel,'motor')
     g.motors[#g.motors+1]={Joint=d,Rel=rel,Actual=inv(d.Part0.CFrame)*d.Part1.CFrame}
    end
   end
  end
 end
 for _,m in ipairs(models)do scan(m)end
 for _,p in ipairs(extraParts or{})do local par=p.Parent;if par then scan(par)end end
 return g
end
function H.pose(g,moving,at)
 local out={};local seen={}
 local queue={moving};seen[moving]=true;out[moving]=at
 local head=1
 while head<=#queue do
  local p=queue[head];head+=1
  for _,e in ipairs(g.adj[p]or{})do
   if not seen[e.To]then seen[e.To]=true;out[e.To]=out[p]*e.Rel;queue[#queue+1]=e.To end
  end
 end
 for _,p in ipairs(g.parts)do if not out[p]then out[p]=g.init[p]end end
 return out,seen
end
-- biggest deviation of any part from "rigidly attached to `root`" after the root moved to `at`; position (studs) and rotation (radians of the 3 axes).
function H.deviation(g,root,poses,at,parts)
 local worstP,worstR,who=0,0,nil
 local rootInit=g.init[root]
 for _,p in ipairs(parts)do
  local want=at*inv(rootInit)*g.init[p]
  local got=poses[p]
  local dp=(want.Position-got.Position).Magnitude
  local dr=0
  for _,axis in ipairs({'RightVector','UpVector','LookVector'})do local a,b=want[axis],got[axis];dr=math.max(dr,math.acos(math.clamp(a:Dot(b),-1,1)))end
  if dp>worstP then worstP=dp;who=p end
  worstR=math.max(worstR,dr)
 end
 return worstP,worstR,who
end
-- a running / turning / jumping path for a torso (the same for every pack): frame k of n
function H.path(k,n)
 local t=k/n
 return CF(math.sin(t*6.2)*14,5+math.abs(math.sin(t*9))*2.2,-t*60)*R.CFrame.Angles(math.sin(t*5)*.25,t*3.1,math.sin(t*7)*.12)
end
-- JSON ------------------------------------------------------------------------------------------------------------------------------------------
local function num(v)if v~=v or v==math.huge or v==-math.huge then return'0'end;return string.format('%.6g',v)end
function H.json(v)
 local t=type(v)
 if t=='number'then return num(v)elseif t=='boolean'then return tostring(v)elseif t=='string'then return'"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'elseif v==nil then return'null'end
 if#v>0 or next(v)==nil then local o={};for _,x in ipairs(v)do o[#o+1]=H.json(x)end;return'['..table.concat(o,',')..']'end
 local keys={};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys)
 local o={};for _,k in ipairs(keys)do o[#o+1]=H.json(tostring(k))..':'..H.json(v[k])end
 return'{'..table.concat(o,',')..'}'
end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;return tostring(e)end
H.enumName=enumName
local function c255(c)return{math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)}end
-- A bag as a scene for the Python checkers: every BasePart in the ROOT's frame divided by the pack's scale (so scale 1 is the pouch's own units),
-- in zfight.py's part format (path, class, shape, size, p, r rows, color, material, t, ltm, faces) plus the joint facts the checks need.
function H.scene(bag,label,includeRoot)
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1;local rootInv=inv(root.CFrame)
 local parts={}
 for _,d in ipairs(bag:GetDescendants())do if d:IsA('BasePart')and(includeRoot or d~=root)then
  local f=rootInv*d.CFrame;local r=f.R
  local shape='Block'
  if d:IsA('MeshPart')then shape='Mesh'elseif d._class=='Part'and d.Shape then local s=enumName(d.Shape);if s=='Ball'or s=='Cylinder'or s=='Wedge'or s=='CornerWedge'then shape=s end end
  local mesh;for _,k in ipairs(d:GetChildren())do if k:IsA('SpecialMesh')then mesh={type=enumName(k.MeshType),scale={k.Scale.X,k.Scale.Y,k.Scale.Z},offset={k.Offset.X,k.Offset.Y,k.Offset.Z}}end end
  local faces={};for _,k in ipairs(d:GetChildren())do if k:IsA('Decal')then faces[#faces+1]={kind='Decal',face=enumName(k.Face),sig=tostring(k.Texture),t=k.Transparency,name=k.Name}end end
  local sx,sy,sz=d.Size.X/scale,d.Size.Y/scale,d.Size.Z/scale
  local p={path=label..'/'..(d.Parent==bag and''or d.Parent.Name..'/')..d.Name,name=d.Name,class=d._class,shape=shape,size={sx,sy,sz},p={f.Position.X/scale,f.Position.Y/scale,f.Position.Z/scale},
   r={{r[1][1],r[1][2],r[1][3]},{r[2][1],r[2][2],r[2][3]},{r[3][1],r[3][2],r[3][3]}},color=c255(d.Color),material=enumName(d.Material),t=d.Transparency,ltm=0,mesh=mesh,faces=#faces>0 and faces or nil,
   anchored=d.Anchored,fx=d:GetAttribute('VoidSpin')~=nil or d:GetAttribute('MechMotion')~=nil,giant=W.CS:HasTag(d,'GiantVisualPart'),refl=d.Reflectance or 0}
  parts[#parts+1]=p
 end end
 local paper=bag:GetAttribute('PaperColor')
 return{label=label,scale=scale,parts=parts,paper=paper and R.typeof(paper)=='Color3'and c255(paper)or nil,attrs={Stage=bag:GetAttribute('Stage'),Variant=bag:GetAttribute('BagVariant'),Key=bag:GetAttribute('PackArtKey'),Size=bag:GetAttribute('PackSize')}}
end
return H
