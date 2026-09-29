-- R84: every limb is a connected kinematic chain; the server uses these same frames.
local K={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local black,cloth,metal,glow=RGB(11,12,19),RGB(25,21,35),RGB(157,135,93),RGB(204,173,255)
local Combat=require(script.Parent.KeeperCombat)
-- Two-bone arms keep the curled hands and forearms connected to the shoulders.
local function downFrame(a,b,side)
 local down=(b-a).Unit;local back=V(0,0,1)
 if math.abs(down:Dot(back))>.97 then back=V(side,0,0)end
 local right=(-down):Cross(back).Unit;back=right:Cross(-down).Unit
 return CFrame.fromMatrix((a+b)*.5,right,-down,back)
end
local function curledArm(shoulder,wrist,side)
 local delta=wrist-shoulder;local length=math.clamp(delta.Magnitude,.21,8.59);local along=delta.Unit
 local alongLength=(4.4*4.4-4.2*4.2+length*length)/(2*length)
 local hint=V(side,-.05,-.40);local bend=(hint-along*hint:Dot(along)).Unit
 local elbow=shoulder+along*alongLength+bend*math.sqrt(math.max(0,4.4*4.4-alongLength*alongLength))
 return downFrame(shoulder,elbow,side),downFrame(elbow,wrist,side)
end
local function jointPose(t,sleep,move,speed,load,hit)
 local p={};local phase=t*math.pi*2*2.15
 local wave=math.sin(phase)*move;local breath=math.sin(t*1.25)*.035
 local bob=math.abs(math.cos(phase))*.13*move+breath*(1-move)
 p.Hip=CF(0,3.65-6.15*sleep+bob,.1+1.6*sleep)
 -- Long opposing strides and a low, forward-driving silhouette.
 local core=p.Hip*CF(0,1,0)*CFrame.Angles(-.08-.92*sleep-.38*move,math.sin(phase)*.055*move,0)
 p.Waist=core*CF(0,.9,0);p.Torso=core*CF(0,3,0)
 p.Neck=p.Torso*CF(0,2.15,0)
 p.Head=p.Neck*CF(0,1.55-.65*sleep,-.15-.3*sleep)*CFrame.Angles(-.12-.55*sleep+.20*move,0,0)
 for _,side in ipairs({-1,1})do
  local q=side<0 and'L'or'R';local swing=side*wave
  local shoulderBase=p.Torso*CF(side*2.65,.95,0)
  local pitch=swing*1.0;local elbow=-.25-.35*math.max(0,-swing)
  local roll=-side*.07
  -- One right-arm back-swing, then a direct forward swat; no overhead windmill.
  if side==1 then local attack=math.max(load,hit)
   pitch=pitch*(1-attack)-.70*load+1.55*hit;elbow=elbow*(1-attack)-.22*load-.12*hit
  end
  local shoulder=shoulderBase*CFrame.Angles(pitch,0,roll)
  local upper=shoulder*CF(0,-2.2,0)
  local bend=shoulder*CF(0,-4.4,0)*CFrame.Angles(elbow,0,0)
  local fore=bend*CF(0,-2.1,0)
  if sleep>0 then
   -- Wrists meet beneath the lowered mask; elbows tuck beside the raised knees.
   local wrist=p.Head.Position+V(-side*.60,-1.18,.10)
   local curledUpper,curledFore=curledArm(shoulderBase.Position,wrist,side)
   upper=upper:Lerp(curledUpper,sleep)
   upper=CF(shoulderBase.Position)*upper.Rotation*CF(0,-2.2,0)
   -- Interpolate orientation, then reconstruct the elbow endpoint exactly.
   fore=fore:Lerp(curledFore,sleep)
   local endpoint=(upper*CF(0,-2.2,0)).Position
   fore=CF(endpoint)*fore.Rotation*CF(0,-2.1,0)
  end
  p[q..'UpperArm']=upper;p[q..'Forearm']=fore
  p[q..'Hand']=fore*CF(0,-2.1-.55,0)
  local hip=p.Hip*CF(side*.95,-.65,0)*CFrame.Angles(2.10*sleep-swing*.95*(1-sleep),0,side*.04)
  p[q..'Thigh']=hip*CF(0,-2,0)
  local knee=hip*CF(0,-4,0)*CFrame.Angles(-2.10*sleep-(.18+math.max(0,swing)*1.05)*(1-sleep),0,0)
  p[q..'Shin']=knee*CF(0,-1.8,0);p[q..'Foot']=knee*CF(0,-3.6-.35,-.60)
 end
 return p
end
local cached=setmetatable({},{__mode='k'})
function K.Frames(model,now)
 if not model.PrimaryPart then return nil end
 local state=model:GetAttribute('GuardianBehavior')or'GUARDING'
 local asleep=state=='GUARDING'or state=='SLEEPING'
 local awake=asleep and 0 or math.clamp((now-(model:GetAttribute('VeiledAwakeAt')or now))/.85,0,1)
 awake=awake*awake*(3-2*awake)
 local moving=(state=='CHASING'or state=='RETURNING'or state=='DASHING')and awake or 0
 local load,hit=Combat.Pose(7,now,model:GetAttribute('KeeperAttackAt'))
 local localFrames=jointPose(now,1-awake,moving,model:GetAttribute('KeeperTravelSpeed')or 600,load,hit)
 local rootFrame=require(script.Parent.KeeperRecoveryDash).VisualFrame(model,now,model.PrimaryPart.CFrame)
 local out={};for key,f in pairs(localFrames)do out[key]=rootFrame*f end
 return out
end
function K.Apply(model,now)
 local frames=K.Frames(model,now);if not frames then return end
 local parts=cached[model]
 if not parts then
  parts={};for _,p in ipairs(model:GetChildren())do local group=p:GetAttribute('VeiledGroup');local cf=p:GetAttribute('VeiledFrame')
   if group and cf then parts[#parts+1]={Part=p,Group=group,Frame=cf}end
  end;cached[model]=parts
 end
 for _,v in ipairs(parts)do if v.Part.Parent then v.Part.CFrame=frames[v.Group]*v.Frame end end
end
function K.Build(home,parent)
 local m=Instance.new('Model');m.Name='TheVeiledOne';m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
 m:SetAttribute('KeeperClientAnimated',true);m:SetAttribute('VeiledKeeper81',true);m:SetAttribute('VeiledRigRevision',86);m:SetAttribute('GuardianBehavior','GUARDING');m:SetAttribute('Stage',7)
 local root=Instance.new('Part');root.Name='VeiledRoot';root.Size=V(2,2,2);root.Transparency=1;root.Anchored=true
 root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.CFrame=home;root.Parent=m;m.PrimaryPart=root
 local function part(name,group,size,frame,color,material,shape,cosmetic)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color or black;p.Material=material or Enum.Material.SmoothPlastic
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=not cosmetic;p.Massless=true
  if shape then p.Shape=shape end
  p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
  p:SetAttribute('VeiledGroup',group);p:SetAttribute('VeiledFrame',frame or CF());p:SetAttribute('VeiledCosmetic',cosmetic==true);p.Parent=m;return p
 end
 part('BroadChest','Torso',V(5.5,3.5,2.4),CF(),cloth)
 part('SlimWaist','Waist',V(2.35,3.4,1.65),CF(),cloth)
 part('SunkenCore','Torso',V(.15,2.7,.10),CF(0,0,-1.23),glow,Enum.Material.Neon,nil,true)
 part('Pelvis','Hip',V(2.7,2.0,1.8))
 part('Neck','Neck',V(1.1,1.4,1.1))
 part('VeiledMask','Head',V(2.0,3.0,1.48),CF(),black)
 part('CleftLight','Head',V(.085,1.95,.06),CF(.02,0,-.77),glow,Enum.Material.Neon,nil,true)
 for _,side in ipairs({-1,1})do
  local q=side<0 and'L'or'R'
  part(q..'Shoulder','Torso',V(1.6,1.6,1.8),CF(side*2.65,.95,0),cloth,nil,Enum.PartType.Ball)
  part(q..'UpperArm',q..'UpperArm',V(1.25,4.4,1.35))
  part(q..'Elbow',q..'Forearm',V(1.25,1.25,1.25),CF(0,2.1,0),black,nil,Enum.PartType.Ball)
  part(q..'Forearm',q..'Forearm',V(1.05,4.2,1.15))
  part(q..'Hand',q..'Hand',V(1.3,1.1,.85))
  part(q..'Wrist',q..'Hand',V(.95,.6,.9),CF(0,.55,0),black,nil,Enum.PartType.Ball)
  for i=1,3 do part(q..'LongFinger'..i,q..'Hand',V(.25,1.55,.3),CF((i-2)*.4,-1.12,0)*CFrame.Angles(-.06,0,(i-2)*.035))end
  part(q..'HipSocket','Hip',V(1.6,1.6,1.6),CF(side*.95,-.65,0),black,nil,Enum.PartType.Ball)
  part(q..'Thigh',q..'Thigh',V(1.4,4,1.55))
  part(q..'Knee',q..'Shin',V(1.3,1.3,1.3),CF(0,1.8,0),black,nil,Enum.PartType.Ball)
  part(q..'Shin',q..'Shin',V(1.1,3.6,1.2))
  part(q..'Foot',q..'Foot',V(1.4,.7,2.6))
  part(q..'WristBand',q..'Forearm',V(1.15,.16,1.25),CF(0,-1.7,0),metal,Enum.Material.Metal,nil,true)
  for rib=1,3 do part(q..'Rib'..rib,'Torso',V(2.1,.12,.1),CF(side*1.25,1.25-rib*.7,-1.23)*CFrame.Angles(0,0,side*.13),metal,Enum.Material.Metal,nil,true)end
 end

 K.Apply(m,workspace:GetServerTimeNow());m.Parent=parent;game:GetService('CollectionService'):AddTag(m,'VeiledKeeper81');return m
end
return K
