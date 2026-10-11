--!nocheck
-- R149 (owner: "add gear to the snow tiger, like silver sapphire gear, to the tiger model"): the Snow keeper (stage 3, Ice Fang, the tiger)
-- wears silver-and-sapphire armour. The real KeeperAccents (with the gear), BeastPose, KeeperSignatureStrike, KeeperAttackPose,
-- KeeperPolish and the real BeastAnimation client script on the Roblox mock:
--  * the gear exists only on the Snow keeper (38 parts); the other six keepers' accents are identical to the base commit's
--    (KeeperAccentsBase, from git), part for part, and so are their pose frames, and the tiger's own three ice spines too;
--  * every gear part follows the right limb: through sleep, idle, three gait phases and a pounce (windup, impact, recovery) the part keeps
--    its place in ONE limb's frame (gear = limb mesh part * limb rest^-1 * gear rest) and in no other limb's; left stays left;
--  * never collides / is queried / touched, anchored, massless, no shadow, no joints, nothing in the replicated rig (BeastBody still has
--    the 21 mesh parts; the gear lives in the client-only KeeperAccentsLocal folder);
--  * silver is Metal (200,205,215 / 132,142,160 with a cool reflectance), sapphire is Glass (30,80,200) with Neon facets (90,150,255);
--  * budget: <= 40 gear parts (3 ice spines + gear < 45), the placement stays on the tiger's rig bounds;
--  * scale: a rig built bigger / smaller carries the gear with it (sizes and positions), an unscaled rig is exactly unchanged;
--  * LOD: studs and facets are hidden beyond 140 studs (with hysteresis) and in low graphics, and are not moved while hidden;
--  * cleanup: removing the rig destroys the gear.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function cfNear(a,b,tol)
 tol=tol or 2e-3
 if (a.Position-b.Position).Magnitude>tol then return false end
 for i=1,3 do for j=1,3 do if math.abs(a.R[i][j]-b.R[i][j])>tol then return false end end end
 return true
end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function colorIs(c,r,g,b)local x,y,z=rgb(c);return x==r and y==g and z==b end
local function vEq(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local Cfg=W.module('KeeperRigConfig');local Pose=W.module('BeastPose');local Acc=W.module('KeeperAccents');local AccBase=W.module('KeeperAccentsBase')
local Sig=W.module('KeeperSignatureStrike');local Combat=W.module('KeeperCombat')
local TIGER=3
-- A keeper model with a BeastBody holding the stage's Body-group parts (the gear reads its rig scale from them).
local function bodyModel(stage,scale)
 local m=R.new('Model');local body=R.new('Model');body.Name='BeastBody';body.Parent=m
 for _,p in ipairs(Cfg[stage].Parts)do
  local part=R.new('Part');part.Name=p.Name;part.Size=V3(p.Size[1]*scale,p.Size[2]*scale,p.Size[3]*scale);part:SetAttribute('BeastGroup',p.Group);part.Parent=body
 end
 return m
end
local function gearParts(acc)
 local out={};for _,it in ipairs(acc.Items)do if it.Part:GetAttribute('KeeperGear')then table.insert(out,it)end end;return out
end
local function snap(p)
 return {Name=p.Name,Class=p._class,Size=p.Size,Color=p.Color,Material=p.Material.Name,Transparency=p.Transparency,Shape=p.Shape and p.Shape.Name or 'Block',
  Anchored=p.Anchored,CanCollide=p.CanCollide,CanQuery=p.CanQuery,CanTouch=p.CanTouch,CastShadow=p.CastShadow,Reflectance=p.Reflectance}
end
local function snapEq(a,b)
 for k,v in pairs(a)do
  if k=='Size'then if not vEq(v,b[k])then return false end
  elseif k=='Color'then if not(near(v.R,b[k].R)and near(v.G,b[k].G)and near(v.B,b[k].B))then return false end
  elseif v~=b[k]then return false end
 end
 return true
end

-- 1. The gear exists only on the Snow keeper ---------------------------------------------------------------------------------
local gearByStage={}
for stage=1,7 do
 local acc=Acc.new(bodyModel(stage,1),stage);local base=AccBase.new(bodyModel(stage,1),stage)
 gearByStage[stage]=acc and #gearParts(acc)or 0
 check(gearByStage[stage]==(stage==TIGER and 38 or 0),'stage '..stage..' gear parts: '..gearByStage[stage])
 check((acc==nil)==(base==nil),'stage '..stage..': accents exist exactly where they did in the base')
 if acc and stage~=TIGER then check(#acc.Items==#base.Items,'stage '..stage..': same number of accent parts as the base ('..#acc.Items..')')end
end
check(Acc.Gear[1]==nil and Acc.Gear[2]==nil and Acc.Gear[4]==nil and Acc.Gear[5]==nil and Acc.Gear[6]==nil and Acc.Gear[7]==nil,'A.Gear has the Snow keeper only')
check(Acc.ScaleRef[1]==nil and Acc.ScaleRef[2]==nil and Acc.ScaleRef[5]==nil and Acc.ScaleRef[7]==nil,'only the tiger reads a rig scale')

-- 2. Other keepers unchanged part for part (and the tiger's three ice spines) -----------------------------------------------------
do
 local function compare(stage,count,label)
  local a=Acc.new(bodyModel(stage,1),stage);local b=AccBase.new(bodyModel(stage,1),stage)
  if not(a and b)then check(a==nil and b==nil,label..': existence');return end
  check(#b.Items==count,label..': base has '..count..' accents, has '..#b.Items)
  local same=true
  for i=1,count do
   if not snapEq(snap(a.Items[i].Part),snap(b.Items[i].Part))then same=false;print('   accent '..i..' differs: '..a.Items[i].Part.Name)end
   if not cfNear(a.Items[i].Rest,b.Items[i].Rest,1e-9)then same=false;print('   accent '..i..' rest differs')end
  end
  check(same,label..': parts identical to the base (name, class, size, colour, material, transparency, shape, flags, rest)')
  -- the same poses give the same frames (incl. Rattle / Orbit / Drift and the tree hide) for the first `count` accents
  local posesOk=true
  for _,t in ipairs({.3,1.7,3.1})do for _,awake in ipairs({0,.6,1})do for _,hunting in ipairs({false,true})do
   local frames=Pose.Frames(stage,t,awake,hunting and 1 or 0,t*3,hunting and 1 or 0,hunting and 60 or 0,0)
   local root=CF(10,5,-20)*R.CFrame.Angles(0,.7,0)
   local pa,oa,pb,ob={},{},{},{}
   Acc.Pose(a,frames,root,awake,t*5,hunting,pa,oa);AccBase.Pose(b,frames,root,awake,t*5,hunting,pb,ob)
   if #ob~=count or #oa<count then posesOk=false else
    for i=1,count do if not cfNear(oa[i],ob[i],1e-9)or pa[i].Name~=pb[i].Name or pa[i].LocalTransparencyModifier~=pb[i].LocalTransparencyModifier then posesOk=false end end
   end
  end end end
  check(posesOk,label..': pose frames identical to the base for 18 pose / state combinations')
 end
 compare(1,3,'Timber Golem');compare(2,3,'Sand Snake');compare(3,3,'Snow tiger spines');compare(5,3,'Crystal Knight');compare(7,5,'Storm Colossus')
 check(Acc.new(bodyModel(4,1),4)==nil and Acc.new(bodyModel(6,1),6)==nil,'Lava Dragon and Jungle King still have no accents')
 -- the base specs of every stage are untouched in the new table
 for stage=1,7 do
  local a,b=Acc.Specs[stage],AccBase.Specs[stage]
  check((a==nil)==(b==nil)and(a==nil or #a==#b),'A.Specs['..stage..'] has the same number of entries as the base')
  if a and b then local ok=true;for i=1,#b do local x,y=a[i],b[i];if x.Group~=y.Group or not vEq(x.At,y.At)or not vEq(x.Size,y.Size)or x.Material~=y.Material or x.Shape~=y.Shape or x.Anim~=y.Anim or x.Tree~=y.Tree then ok=false end end
   check(ok,'A.Specs['..stage..'] entries are identical to the base')end
 end
end

-- 3. Properties of every gear part ----------------------------------------------------------------------------------------------
local tigerAcc=Acc.new(bodyModel(TIGER,1),TIGER)
local gear=gearParts(tigerAcc)
local silver,sapphire,facets,detail=0,0,0,0
local names={}
for _,it in ipairs(gear)do
 local p,s=it.Part,it.Spec
 local tag=p.Name
 check(p.Anchored==true and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false,tag..': anchored, no collide / query / touch')
 check(p.Massless==true and p.CastShadow==false,tag..': massless, no shadow')
 check(p.Parent==tigerAcc.Folder and p.Name:sub(1,11)=='KeeperGear_','named KeeperGear_*, in the client-only accent folder: '..tag)
 check(#p:GetChildren()==0,tag..': no children (no weld, motor, attachment, light)')
 check(p._class=='Part',tag..': a plain Part (no mesh, no union)')
 names[p.Name]=true
 local mat=p.Material.Name
 if mat=='Metal'then
  silver+=1
  local r,g,b=rgb(p.Color)
  check((r==200 and g==205 and b==215)or(r==132 and g==142 and b==160),tag..': silver is 200,205,215 or the 132,142,160 trim ('..r..','..g..','..b..')')
  check(p.Reflectance and p.Reflectance>=.15 and p.Reflectance<=.3 and p.Transparency==0,tag..': a subtle cool reflectance, opaque')
  check(not s.Detail,tag..': plates are never LOD detail')
 elseif mat=='Glass'then
  sapphire+=1
  check(colorIs(p.Color,30,80,200),tag..': sapphire is 30,80,200')
  check(p.Transparency>=.05 and p.Transparency<=.12,tag..': glassy')
 elseif mat=='Neon'then
  facets+=1
  check(colorIs(p.Color,90,150,255)and p.Transparency>0 and p.Transparency<=.3,tag..': facet is 90,150,255')
  check(s.Detail==true,tag..': facets are LOD detail')
 else check(false,tag..': unexpected material '..mat)end
 if s.Detail then detail+=1 end
 -- placement stays on the tiger: within 1.1 studs of its limb's bounds (box of the rig config)
 local b=Cfg[TIGER].Bounds[s.Group];local c=s.At
 if check(b~=nil,tag..': its limb group '..tostring(s.Group)..' exists in the rig config')then
  local dx=math.max(b[1][1]-c.X,0,c.X-b[2][1]);local dy=math.max(b[1][2]-c.Y,0,c.Y-b[2][2]);local dz=math.max(b[1][3]-c.Z,0,c.Z-b[2][3])
  check(math.sqrt(dx*dx+dy*dy+dz*dz)<=1.1,tag..': centre within 1.1 studs of the '..s.Group..' bounds')
 end
end
check(#gear==38 and #gear<=40,'gear budget: '..#gear..' parts (<= 40)')
check(#tigerAcc.Items==41 and #tigerAcc.Items<45,'tiger accents + gear: '..#tigerAcc.Items..' parts')
check(silver==22 and sapphire==14 and facets==2 and silver+sapphire+facets==38,'38 = 22 silver + 14 sapphire + 2 facets ('..silver..' / '..sapphire..' / '..facets..')')
check(detail==14,'14 LOD detail pieces (12 studs + 2 facets): '..detail)
check(sapphire>=10,'at least ten sapphires (brow, collar x3, saddle, cheeks x2, pauldrons x2, cuffs x4, tail)')
for _,n in ipairs({'HelmFront','HelmRear','BrowGem','BrowBladeL','BrowBladeR','CheekGuardL','CheekGuardR','ChinGuard','CollarTop','CollarBevelL','CollarBevelR','CollarStud',
 'SaddleA','SaddleB','SaddleC','SaddleGem','FlankL','FlankR','PauldronL','PauldronR','FrontCuffL','FrontCuffR','BackCuffL','BackCuffR','TailRing','TailRingStud'})do
 check(names['KeeperGear_'..n]==true,'the brief: '..n..' exists')
end
-- the three ice spines keep their place at the front of the list (names and order of the base)
check(tigerAcc.Items[1].Part.Name=='KeeperAccent1'and tigerAcc.Items[3].Part.Name=='KeeperAccent3'and tigerAcc.Items[4].Part.Name:sub(1,11)=='KeeperGear_','spines first, gear after')
for i=1,3 do check(tigerAcc.Items[i].Part.Material.Name=='Ice'and not tigerAcc.Items[i].Part:GetAttribute('KeeperGear'),'spine '..i..' is still ice, not gear')end

-- 4. Scale -------------------------------------------------------------------------------------------------------------------------
do
 local one=Acc.new(bodyModel(TIGER,1),TIGER);check(one.Scale==1,'scale 1 for the unscaled tiger')
 local function sameAs(k,label,expectK)
  local scaled=Acc.new(bodyModel(TIGER,k),TIGER)
  check(near(scaled.Scale,expectK,1e-6),label..': Scale '..tostring(scaled.Scale))
  local ok=true
  for i=1,#one.Items do
   local a,b=one.Items[i],scaled.Items[i]
   local want=a.Part.Size*expectK
   if not(near(b.Part.Size.X,want.X,1e-5)and near(b.Part.Size.Y,want.Y,1e-5)and near(b.Part.Size.Z,want.Z,1e-5))then ok=false end
   local wp=a.Rest.Position*expectK
   if not((b.Rest.Position-wp).Magnitude<1e-5)then ok=false end
   for r=1,3 do for c=1,3 do if not near(a.Rest.R[r][c],b.Rest.R[r][c],1e-6)then ok=false end end end
  end
  check(ok,label..': every size and position scaled by '..expectK..', rotations unchanged ('..#one.Items..' parts)')
 end
 sameAs(2,'rig x2',2);sameAs(.5,'rig x0.5',.5);sameAs(1.5,'rig x1.5',1.5)
 sameAs(1.01,'rig x1.01 (float noise)',1)
 check(Acc.new(bodyModel(TIGER,40),TIGER).Scale==8 and Acc.new(bodyModel(TIGER,.01),TIGER).Scale==.25,'scale clamped to .25 .. 8')
 -- exact equality at scale 1 (sizes are the spec's own vectors)
 local exact=true;for i=4,#one.Items do if not vEq(one.Items[i].Part.Size,Acc.Gear[TIGER][i-3].Size)then exact=false end end
 check(exact,'at scale 1 the gear sizes are exactly the spec sizes')
 -- a model with no BeastBody / no Body parts: scale 1
 local bare=R.new('Model');check(Acc.new(bare,TIGER).Scale==1,'no rig yet: scale 1')
 -- the pose carries the scale: the gear stays on its limb in the scaled rig
 local k=2;local frames=Pose.Frames(TIGER,1.3,1,1,2.1,1,60,0);local scaled=Acc.new(bodyModel(TIGER,k),TIGER)
 local parts,out={},{};Acc.Pose(scaled,frames,CF(0,0,0),1,0,true,parts,out)
 local ok=true
 for i,it in ipairs(scaled.Items)do local expect=frames[it.Spec.Group]*it.Rest;if not cfNear(out[i],expect,1e-6)then ok=false end end
 check(ok,'scaled gear: root * group frame * scaled rest')
end

-- 5. LOD: detail pieces hidden far away / in low graphics ---------------------------------------------------------------------
do
 local acc=Acc.new(bodyModel(TIGER,1),TIGER);local frames=Pose.Frames(TIGER,1,1,0,0,0,0,0)
 local function run(distance,low)local parts,out={},{};Acc.Pose(acc,frames,CF(0,0,0),1,0,false,parts,out,distance,low);return parts,out end
 local function hidden()local n=0;for _,it in ipairs(acc.Items)do if it.Part.LocalTransparencyModifier==1 then n+=1 end end;return n end
 local parts=run(30,false);check(#parts==41 and hidden()==0,'near: all 41 parts moved, none hidden')
 parts=run(nil,nil);check(#parts==41,'no distance given: all parts (old callers)')
 parts=run(200,false);check(#parts==41-14 and hidden()==14,'far (200): the 14 detail pieces are hidden and skipped ('..#parts..' moved, '..hidden()..' hidden)')
 local movedDetail=false;for _,p in ipairs(parts)do local it;for _,x in ipairs(acc.Items)do if x.Part==p then it=x end end;if it.Spec.Detail then movedDetail=true end end
 check(not movedDetail,'far: no detail piece in the move list')
 local silverFar=0;for _,p in ipairs(parts)do if p.Material.Name=='Metal'then silverFar+=1 end end
 check(silverFar==22,'far: all 22 silver plates still move ('..silverFar..')')
 local glassFar=0;for _,p in ipairs(parts)do if p.Material.Name=='Glass'then glassFar+=1 end end
 check(glassFar==2,'far: only the two large sapphires (brow, saddle) still move; the 12 studs are hidden (glass moved '..glassFar..')')
 parts=run(150,false);check(#parts==41-14,'hysteresis: still hidden at 150 (beyond 140)')
 parts=run(139,false);check(#parts==41 and hidden()==0,'back inside 140: shown again, transparency restored')
 parts=run(158,false);check(#parts==41,'hysteresis: still shown at 158 (inside 140 x 1.15)')
 parts=run(162,false);check(#parts==27,'hidden past 161')
 parts=run(10,true);check(#parts==27 and hidden()==14,'low graphics: detail hidden even up close')
 parts=run(10,false);check(#parts==41 and hidden()==0,'back to normal graphics: shown again')
 -- the old accents are never LOD pieces
 local a2=Acc.new(bodyModel(2,1),2);local pa,oa={},{};Acc.Pose(a2,Pose.Frames(2,1,1,0,0,0,0,0),CF(0,0,0),1,0,false,pa,oa,500,true);check(#pa==3,'the Sand Snake rattle is never hidden by distance / low graphics')
end

-- 6. Real BeastAnimation: the gear follows the limbs through the whole animation set ----------------------------------------------
local S={awake=0,moving=0,cycle=0,urgency=0,speed=0,t=0,low=false}
W.stub('KeeperAudio',{Voice=function()return nil,0,1 end});W.stub('SoundTiming',{Play=function()end})
W.stub('KeeperVoices',setmetatable({},{__index=function()return {Gap=6}end}))
W.stub('KeeperMotion',{new=function()return {}end,Update=function(_,frame)return {Frame=frame,Awake=S.awake,Time=S.t,Moving=S.moving,Cycle=S.cycle,Urgency=S.urgency,Speed=S.speed,Turn=0}end})
W.stub('KeeperRecoveryDash',{VisualFrame=function(_,_,f)return f end})
W.stub('KeeperSleep',{new=function()return {Update=function()end,Destroy=function()end}end})
W.stub('KeeperSurge',{New=function()return {}end,Step=function()end,Destroy=function()end})
W.stub('CosmeticBudget',{KeeperDue=function()return true end});W.stub('ClientFxBudget',{Low=function()return S.low end})
W.stub('KeeperFx',{new=function()return {}end,Step=function()end,Slam=function()end,Wake=function()end,Destroy=function()end})
local workspace=W.workspace;local camera=workspace.CurrentCamera
camera.WorldToViewportPoint=function()return V3(0,0,0),true end
local moved={};local moveCalls,moveParts=0,0
function workspace.BulkMoveTo(_,parts,frames)moveCalls+=1;moveParts+=#parts;for i,p in ipairs(parts)do p.CFrame=frames[i];moved[p]=true end end
local function keeper(stage,at)
 local model=R.new('Model');model.Name='Guardian_Stage'..stage
 model:SetAttribute('GardenerArtVersion',99);model:SetAttribute('CreatureStage',stage);model:SetAttribute('GuardianBehavior','GUARDING')
 local root=R.new('Part');root.Name='HumanoidRootPart';root.CFrame=at;root.Parent=model
 local body=R.new('Model');body.Name='BeastBody';body:SetAttribute('VisualVersion',(stage==1 or stage==5 or stage==7)and 59 or 99);body.Parent=model
 local rest={}
 for _,s in ipairs(Cfg[stage].Parts)do
  local p=R.new('Part');p.Name=s.Name;p.Size=V3(s.Size[1],s.Size[2],s.Size[3])
  local r=s.Rest and CF(table.unpack(s.Rest))or CF(s.Center[1],s.Center[2],s.Center[3])
  p:SetAttribute('RestCFrame',r);p:SetAttribute('BeastGroup',s.Group);p:SetAttribute('KeeperEyeGlow',s.EyeGlow);p.CFrame=at*r;p.Parent=body;rest[p]=r
 end
 model.Parent=workspace
 return model,root,body,rest
end
local sc=R.new('LocalScript');sc.Name='BeastAnimation'
local fn=assert(loadstring(W.B.BeastAnimation,'=BeastAnimation'));setfenv(fn,setmetatable({script=sc},{__index=W.env}))
-- three keepers in the world: the tiger, a Sand Snake and a Jungle King (the latter has no accents at all)
local rootCF=CF(0,5,0)
local tiger,tRoot,tBody,tRest=keeper(TIGER,rootCF)
local snake,sRoot,sBody=keeper(2,CF(300,5,0));local king,kRoot,kBody=keeper(6,CF(-300,5,0))
local childCountBefore=#tBody:GetChildren()
fn();R.advance(0)
local function folderOf(model)return model:FindFirstChild('KeeperAccentsLocal')end
local tFolder=folderOf(tiger)
check(tFolder~=nil and #tFolder:GetChildren()==41,'the tiger keeper binds: KeeperAccentsLocal holds 3 spines + 38 gear ('..(tFolder and #tFolder:GetChildren()or -1)..')')
check(folderOf(snake)~=nil and #folderOf(snake):GetChildren()==3,'the snake keeper still has its 3 rattle parts only')
check(folderOf(king)==nil,'the Jungle King has no accent folder')
check(#tBody:GetChildren()==childCountBefore and #tBody:GetChildren()==21,'BeastBody (the replicated rig) still holds exactly its 21 mesh parts')
check(tFolder.Parent==tiger and tFolder.Parent~=tBody,'the gear folder is a sibling of BeastBody (client only), never inside the rig')
do local joints=0;for _,d in ipairs(tiger:GetDescendants())do if d:IsA('JointInstance')or d:IsA('Constraint')then joints+=1 end end;check(joints==0,'no welds / joints / constraints anywhere in the keeper model')end
do local bad=0;for _,p in ipairs(tFolder:GetChildren())do if p.CanCollide or p.CanQuery or p.CanTouch or not p.Anchored then bad+=1 end end;check(bad==0,'every part of the accent folder is non-colliding, non-queryable, non-touchable and anchored')end
-- gear specs by part name and limb part lookup
local specByName={};for _,s in ipairs(Acc.Gear[TIGER])do specByName['KeeperGear_'..s.Name]=s end
local limbPart={};for p in pairs(tRest)do local g=p:GetAttribute('BeastGroup');if not limbPart[g]then limbPart[g]=p end end
local groups={'Head','Jaw','Body','LeftFrontLeg','RightFrontLeg','LeftBackLeg','RightBackLeg','Tail'}
local function gearRest(s)local c=CF(s.At.X,s.At.Y,s.At.Z);if s.Rot then c=c*R.CFrame.Angles(math.rad(s.Rot.X),math.rad(s.Rot.Y),math.rad(s.Rot.Z))end;return c end
-- Where each piece belongs, from the brief (independent of the spec's own Group field).
local EXPECT={HelmFront='Head',HelmRear='Head',BrowGem='Head',BrowGemFacet='Head',ChinGuard='Jaw',CollarTop='Body',CollarStud='Body',SaddleA='Body',SaddleB='Body',SaddleC='Body',
 SaddleGem='Body',SaddleGemFacet='Body',TailRing='Tail',TailRingStud='Tail'}
local PER_SIDE={Flank='Body',CollarBevel='Body',CollarBevelStud='Body',BrowBlade='Head',CheekGuard='Head',CheekStud='Head',Pauldron='FrontLeg',PauldronStud='FrontLeg',
 FrontCuff='FrontLeg',FrontCuffStud='FrontLeg',BackCuff='BackLeg',BackCuffStud='BackLeg'}
local function expectedGroup(name)
 if EXPECT[name]then return EXPECT[name]end
 local kind=PER_SIDE[name:sub(1,-2)];local side=name:sub(-1)
 if not kind then return nil end
 if kind:find('Leg')then return(side=='L'and'Left'or'Right')..kind end
 return kind
end
local candidates={} -- gear part -> set of groups it has followed in EVERY pose so far
local function observe(label)
 local limbMoved=0
 for _,g in ipairs(groups)do local lp=limbPart[g];local rel=lp.CFrame*tRest[lp]:Inverse();if(rel.Position-rootCF.Position).Magnitude>.05 or not cfNear(rel*tRest[lp],rootCF*tRest[lp],1e-3)then limbMoved+=1 end end
 for _,p in ipairs(tFolder:GetChildren())do
  local s=specByName[p.Name]
  if s and p.LocalTransparencyModifier~=1 then
   local set=candidates[p];if not set then set={};for _,g in ipairs(groups)do set[g]=true end;candidates[p]=set end
   for _,g in ipairs(groups)do
    local lp=limbPart[g]
    local expect=lp.CFrame*tRest[lp]:Inverse()*gearRest(s)
    if not cfNear(p.CFrame,expect,3e-3)then set[g]=nil end
   end
  end
 end
 return limbMoved
end
local function settle(frames)for _=1,frames or 3 do W.frames(1,1/60)end end
local posesSeen={};local snaps={}
local function pose(label,awake,moving,cycle,urgency,speed,state)
 S.awake,S.moving,S.cycle,S.urgency,S.speed=awake,moving,cycle,urgency,speed;S.t=R.clock;tiger:SetAttribute('GuardianBehavior',state);settle(4)
 local moved=observe(label);posesSeen[label]=moved;snaps[label]={limbPart.LeftFrontLeg.CFrame,limbPart.Tail.CFrame,limbPart.Head.CFrame}
end
camera.CFrame=CF(0,20,-60) -- 60 studs away: full detail
pose('sleep',0,0,0,0,0,'GUARDING')
pose('idle',1,0,0,0,0,'ALERTED')
pose('gait A',1,1,.9,1,70,'CHASING')
pose('gait B',1,1,2.4,1,70,'CHASING')
pose('gait C',1,1,4.1,1,70,'CHASING')
pose('walk',1,1,1.7,0,12,'CHASING')
-- a pounce: windup, impact, recovery (the real KeeperSignatureStrike frames)
local windup=Combat.Get(TIGER).Windup
S.awake,S.moving,S.cycle,S.urgency,S.speed=1,0,0,1,0;tiger:SetAttribute('GuardianBehavior','ATTACKING');tiger:SetAttribute('KeeperAttackAt',R.clock+.0001)
W.frames(1,.0002)
local attackAt=tiger:GetAttribute('KeeperAttackAt')
for i,e in ipairs({windup*.45,windup*.9,windup+.02,windup+.18})do
 local want=attackAt+e;local dt=want-R.clock;if dt>0 then W.frames(1,dt)else W.frames(1,1/240)end
 S.t=R.clock;local m=observe('strike '..i);posesSeen['strike '..i]=m
end
-- every gear part followed exactly its own limb in all of those poses
local wrong,total={},0
for _,p in ipairs(tFolder:GetChildren())do
 local s=specByName[p.Name]
 if s then
  total+=1;local set=candidates[p];local list={};for g in pairs(set or{})do table.insert(list,g)end;table.sort(list)
  local want=expectedGroup(s.Name)
  if not(#list==1 and list[1]==want)then table.insert(wrong,p.Name..' -> '..table.concat(list,'/')..' (expected '..tostring(want)..')')end
 end
end
check(total==38,'38 gear parts observed in the real animation ('..total..')')
check(#wrong==0,'every gear part follows exactly its own limb through sleep, idle, 3 gait phases, a walk and a pounce: '..table.concat(wrong,'; '))
for label,m in pairs(posesSeen)do check(m>=1,'pose "'..label..'" really moved limbs (the test is not vacuous): '..m..' limbs off rest')end
local function rotDiff(a,b)local m=0;for i=1,3 do for j=1,3 do m=math.max(m,math.abs(a.R[i][j]-b.R[i][j]))end end;return m end
for k,name in ipairs({'front leg','tail','head'})do
 check(rotDiff(snaps['sleep'][k],snaps['gait B'][k])>.05 and rotDiff(snaps['gait A'][k],snaps['gait C'][k])>.001,name..' really turns between sleep, idle and the gait (the follow check is not vacuous)')
end
check(rotDiff(snaps['sleep'][1],snaps['idle'][1])>.2,'the sleep curl folds the front leg by more than the idle pose')
-- the left/right assignment: left gear on the Left* groups at negative X, right gear on Right* at positive X
do local ok=true
 for _,s in ipairs(Acc.Gear[TIGER])do
  local left=s.Name:sub(-1)=='L'
  local right=s.Name:sub(-1)=='R'
  if left and not(s.At.X<0 and(s.Group:sub(1,4)=='Left'or not s.Group:find('Leg')))then ok=false;print('   left part on the wrong side: '..s.Name)end
  if right and not(s.At.X>0 and(s.Group:sub(1,5)=='Right'or not s.Group:find('Leg')))then ok=false;print('   right part on the wrong side: '..s.Name)end
  if s.Group:sub(1,4)=='Left' and s.At.X>=0 or s.Group:sub(1,5)=='Right' and s.At.X<=0 then ok=false;print('   leg gear on the wrong leg: '..s.Name)end
 end
 check(ok,'left gear is on the left (negative X, Left* limb), right gear on the right')
 local groupOk=true
 for _,s in ipairs(Acc.Gear[TIGER])do
  local want=expectedGroup(s.Name)
  if s.Group~=want then groupOk=false;print('   '..s.Name..' is on '..tostring(s.Group)..', brief says '..tostring(want))end
 end
 check(groupOk,'helm/brow/cheeks on the Head, chin guard on the Jaw, collar + saddle + flanks on the Body, pauldrons + front cuffs on the front legs, back cuffs on the back legs, ring on the Tail')
end
-- hitboxes: nothing server-visible changed (the keeper's own parts keep the exact sizes and the same names)
do local ok=true;for _,s in ipairs(Cfg[TIGER].Parts)do local p=tBody:FindFirstChild(s.Name);if not p or not near(p.Size.X,s.Size[1],1e-5)or not near(p.Size.Y,s.Size[2],1e-5)or not near(p.Size.Z,s.Size[3],1e-5)then ok=false end end
 check(ok,'the 21 rig parts keep their configured sizes (reach / contact shapes are the rig config + KeeperStrikeFrames, unchanged)') end
-- LOD through the real script: far camera hides the detail pieces, they stop being moved
do
 camera.CFrame=CF(0,20,260);settle(3)
 local hiddenN=0;for _,p in ipairs(tFolder:GetChildren())do if p.LocalTransparencyModifier==1 then hiddenN+=1 end end
 check(hiddenN==14,'camera 260 studs away: the 14 detail pieces are hidden by the real script ('..hiddenN..')')
 local before=moveParts;local c0=moveCalls;settle(3);local farPerFrame=(moveParts-before)/(moveCalls-c0)
 camera.CFrame=CF(0,20,-60);settle(3)
 before=moveParts;c0=moveCalls;settle(3);local nearPerFrame=(moveParts-before)/(moveCalls-c0)
 check(nearPerFrame-farPerFrame==14,'far: exactly the 14 detail pieces fewer in every BulkMoveTo call ('..nearPerFrame..' near, '..farPerFrame..' far)')
 local hiddenAfter=0;for _,p in ipairs(tFolder:GetChildren())do if p.LocalTransparencyModifier==1 then hiddenAfter+=1 end end
 check(hiddenAfter==0,'back near: everything shown again')
 S.low=true;settle(3);local lowHidden=0;for _,p in ipairs(tFolder:GetChildren())do if p.LocalTransparencyModifier==1 then lowHidden+=1 end end
 check(lowHidden==14,'low graphics: the 14 detail pieces hidden through the real script ('..lowHidden..')')
 S.low=false;settle(3)
end
-- cleanup: the keeper's rig goes -> its gear goes
tBody:Destroy();settle(2)
check(folderOf(tiger)==nil or folderOf(tiger)._destroyed==true,'removing the rig destroys the gear folder')
check(#(function()local l={};for p in pairs(candidates)do if p.Parent~=nil then table.insert(l,p)end end;return l end)()==0,'no gear part is left parented anywhere')

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
