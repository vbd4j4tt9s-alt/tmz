--!nocheck
-- R151 hub displays: the champion's avatar (HubDisplayAvatar, HubAvatarPose) with a Players mock that hands out R15-shaped rigs (real joint names, accessories, a Humanoid,
-- an Animate script, a Humanoid with a name and health bar to switch off):
--  1. descriptions: asked for once per user id (cached, the oldest dropped past 12), a failure is remembered for a minute, a non-user id is never asked about;
--  2. the rig: stripped (no scripts, at most 10 accessories), inert (no collision, no touch, no query), anchored at its root only (the limbs hang off their joints, which is what
--     lets a client pose them), name and health bar off, the static pose in the joints' C0 (replicates), nothing else changed;
--  3. standing: scaled so the BODY is 10.5 studs tall whatever the avatar's own height scale and hats, soles on the plinth, turned toward the item, at the display's spot;
--  4. failures: no description / no rig / the services throwing -> a blocky stand-in of the same height and pose, never an error; the silhouette is black and asks nobody;
--  5. the pose maths: the static pose only touches joints a rig has, the cheer and the celebration stay within the limits for any time, boost and bad input.
local HH=require('./hub_harness');local H=HH.H;local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local Rules=W.module('HubDisplayRules');local Pose=W.module('HubAvatarPose')
local Avatar=H.server('HubDisplayAvatar')
HH.installPlayers()
local Players=W.service('Players')
local function new()return Avatar.new({Players=Players,Clock=HH.clock().now})end
local function reset()HH.avatars.Describe=0;HH.avatars.Create=0;HH.avatars.Mode='ok';HH.avatars.Accessories=3;HH.avatars.Scale=1 end
-- the angle of a rotation (from its trace) in radians
local function angle(cf)local r=cf.R;local tr=r[1][1]+r[2][2]+r[3][3];return math.acos(math.clamp((tr-1)/2,-1,1))end
local function bodyTopBottom(rig)
 local lo,hi
 for _,p in ipairs(rig:GetChildren())do if p:IsA('BasePart')and p.Name~='HumanoidRootPart'then
  local a,b=p.CFrame.Position.Y-p.Size.Y/2,p.CFrame.Position.Y+p.Size.Y/2
  lo=lo and math.min(lo,a)or a;hi=hi and math.max(hi,b)or b
 end end
 return lo,hi
end

-- 1. Descriptions --------------------------------------------------------------------------------------------------------------------------------------------------------
do
 reset();local A=new()
 local d1=A:Describe(1001);local d2=A:Describe(1001)
 check(d1 and d1==d2 and HH.avatars.Describe==1,'a user\'s description is fetched once and cached')
 for id=2000,2020 do A:Describe(id)end
 local calls=HH.avatars.Describe
 A:Describe(1001);check(HH.avatars.Describe==calls+1,'past 12 cached descriptions the oldest is dropped (the first user is fetched again)')
 A:Describe(2020);check(HH.avatars.Describe==calls+1,'the newest is still cached')
 local before=HH.avatars.Describe
 for _,bad in ipairs({0,-1,-5,1.5,0/0,'12','abc'})do local d,why=A:Describe(bad);if d~=nil or not why then check(false,'a non-user id ('..tostring(bad)..') is refused without asking')end end
 check(HH.avatars.Describe==before,'a Studio test player or a bad id is never sent to Roblox')
 HH.avatars.Mode='describe fails'
 local clock=HH.clock();local B=Avatar.new({Players=Players,Clock=clock.now})
 local d,why=B:Describe(3000)
 check(d==nil and tostring(why):find('404',1,true),'a failed lookup returns nil and why (no error)')
 local calls2=HH.avatars.Describe;B:Describe(3000);B:Describe(3000)
 check(HH.avatars.Describe==calls2,'a failure is remembered: asked again only after a minute')
 clock.advance(61);HH.avatars.Mode='ok';check(B:Describe(3000)~=nil and HH.avatars.Describe==calls2+1,'and then it tries again')
end

-- 2. The rig -------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 reset();HH.avatars.Accessories=25
 local A=new()
 local rig,source=A:Build(5001)
 check(source=='avatar'and rig and rig.Name=='ChampionAvatar'and rig:GetAttribute('UserId')==5001,'a real avatar: the rig from the user\'s description')
 check(HH.avatars.Last==rig and rig:GetAttribute('RigType')==tostring(R.Enum.HumanoidRigType.R15),'built as R15')
 local hats=0;for _,c in ipairs(rig:GetChildren())do if c:IsA('Accessory')then hats+=1 end end
 check(hats==Rules.AvatarAccessories and hats==10,'at most 10 accessories are worn (a 25-accessory avatar shows 10)')
 local scripts=0;for _,d in ipairs(rig:GetDescendants())do if d:IsA('LuaSourceContainer')then scripts+=1 end end
 check(scripts==0,'no scripts (the rig\'s Animate script is removed)')
 local bad={};for _,d in ipairs(rig:GetDescendants())do
  if d:IsA('BasePart')and(d.CanCollide or d.CanTouch or d.CanQuery)then bad[#bad+1]=d.Name end
 end
 check(#bad==0,'every part is non-collidable, non-touchable and not queryable'..(#bad>0 and(' ('..table.concat(bad,',')..')')or''))
 check(rig.HumanoidRootPart.Anchored==true,'the HumanoidRootPart is anchored')
 local loose=0;for _,p in ipairs(rig:GetChildren())do if p:IsA('BasePart')and p.Name~='HumanoidRootPart'and not p.Anchored then loose+=1 end end
 check(loose==15,'the 15 limb parts are not anchored: they hang off the root through their Motor6Ds (a client can pose them)')
 local hum=rig:FindFirstChildOfClass('Humanoid')
 check(hum.DisplayDistanceType==R.Enum.HumanoidDisplayDistanceType.None and hum.HealthDisplayType==R.Enum.HumanoidHealthDisplayType.AlwaysOff and hum.NameDisplayDistance==0 and hum.HealthDisplayDistance==0,'no name above its head, no health bar')
 check(hum.RequiresNeck==false and hum.BreakJointsOnDeath==false and hum.EvaluateStateMachine==false,'the humanoid is inert (no neck needed, no state machine)')
 -- the static pose
 local rs=Pose.Joint(rig,'RightShoulder');local ls=Pose.Joint(rig,'LeftShoulder');local hip=Pose.Joint(rig,'RightHip')
 check(rs and angle(rs.C0)>1.5 and angle(rs.C0)<2.3,'the right arm is raised out (its C0 turned about 110 degrees)')
 check(ls and angle(ls.C0)<.6 and angle(ls.C0)>0,'the left arm hangs a little out')
 check(hip and angle(hip.C0)==0,'the legs are not touched')
 local touched=0;for _,d in ipairs(rig:GetDescendants())do if d:IsA('Motor6D')and angle(d.C0)>1e-9 then touched+=1 end end
 check(touched==6,'exactly the six joints of the static pose moved ('..touched..')')
 check(Pose.Apply(R.new('Model'))==0 and Pose.Joint(rig,'NoSuchJoint')==nil,'a model without joints: the pose moves nothing and does not throw')
 -- the rig is not parented or placed by Build
 check(rig.Parent==nil,'Build returns an unparented model')
end

-- 3. Standing ------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 reset();local A=new()
 for _,scale in ipairs({1,1.2,.8})do
  HH.avatars.Scale=scale;HH.avatars.Accessories=4
  local rig=A:Build(6000)
  local feet=CF(100,10,-50)
  check(A:Place(rig,feet,Rules.AvatarHeight,-.4),'placed')
  local lo,hi=bodyTopBottom(rig)
  check(near(hi-lo,Rules.AvatarHeight,.05),'an avatar of height scale '..scale..' stands '..Rules.AvatarHeight..' studs tall (body only): '..string.format('%.2f',hi-lo))
  check(near(lo,10,.05),'its soles are at the plinth\'s height (y '..string.format('%.2f',lo)..')')
  local root=rig.HumanoidRootPart.CFrame.Position
  check(near(root.X,100,.05)and near(root.Z,-50,.05),'at the display\'s spot')
 end
 local rig=A:Build(6001);local feet=CF(0,0,0)*R.CFrame.Angles(0,math.pi/2,0)
 A:Place(rig,feet,Rules.AvatarHeight,-.4)
 local look=rig.HumanoidRootPart.CFrame.LookVector
 local want=(feet*R.CFrame.Angles(0,-.4,0)).LookVector
 check(near(look.X,want.X,1e-6)and near(look.Z,want.Z,1e-6),'it faces the way the display faces, turned a little toward the item')
 -- a hat that is much taller than the head does not shrink the body
 HH.avatars.Accessories=0
 local plain=A:Build(6002);A:Place(plain,CF(0,0,0),Rules.AvatarHeight,0)
 local hatted=A:Build(6003);local tall=R.new('Accessory');tall.Name='TopHat';local h=R.new('Part');h.Name='Handle';h.Size=V3(1,6,1);h.CFrame=CF(0,9,0);h.Parent=tall;tall.Parent=hatted
 A:Place(hatted,CF(0,0,0),Rules.AvatarHeight,0)
 local l1,h1=bodyTopBottom(plain);local l2,h2=bodyTopBottom(hatted)
 check(near(h1-l1,h2-l2,.05),'a tall hat does not shrink the body (the height is measured on the body parts alone)')
end

-- 4. Failures ------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 reset();local A=new()
 for _,mode in ipairs({'describe fails','create fails','throws'})do
  HH.avatars.Mode=mode;A=new()
  local ok,model,source=pcall(function()return A:Build(7000)end)
  local m,src=model,source
  check(ok and m and src=='fallback'and m:GetAttribute('Fallback')==true,'"'..mode..'": a blocky stand-in, no error')
 end
 HH.avatars.Mode='ok'
 local bad,src=A:Build(0)
 check(src=='fallback','a Studio test player (user id 0 / negative) gets the blocky stand-in at once')
 check(A:Build(-1)~=nil,'(negative ids too)')
 local stand=A:Fallback(false)
 local n=0;for _,p in ipairs(stand:GetChildren())do if p:IsA('BasePart')then n+=1 end end
 check(n==6 and stand.PrimaryPart~=nil,'the stand-in is six blocks: two legs, torso, head, two arms')
 local placed=A:Place(stand,CF(10,5,10),Rules.AvatarHeight,-.4)
 local lo,hi=1e9,-1e9;for _,p in ipairs(stand:GetChildren())do if p:IsA('BasePart')then lo=math.min(lo,p.CFrame.Position.Y-p.Size.Y/2);hi=math.max(hi,p.CFrame.Position.Y+p.Size.Y/2)end end
 check(placed and near(lo,5,.05)and hi-lo>Rules.AvatarHeight*.9 and hi-lo<Rules.AvatarHeight*1.15,'the stand-in stands on the same spot at about the same height ('..string.format('%.2f',hi-lo)..')')
 local armUp=false;for _,p in ipairs(stand:GetChildren())do if p.Name=='RightArm'and p.CFrame.Position.Y>stand.PrimaryPart.CFrame.Position.Y and math.abs(p.CFrame.Position.X-stand.PrimaryPart.CFrame.Position.X)>3 then armUp=true end end
 check(armUp,'its right arm is raised out like the real pose')
 local bads=0;for _,p in ipairs(stand:GetChildren())do if p:IsA('BasePart')and(p.CanCollide or p.CanTouch or p.CanQuery or not p.Anchored)then bads+=1 end end
 check(bads==0,'all anchored and inert')
 reset();local calls=HH.avatars.Describe
 local sil=A:Build(8000,{Silhouette=true})
 check(HH.avatars.Describe==calls and sil:GetAttribute('Fallback')and sil:GetAttribute('UserId')==nil,'the silhouette asks nobody and belongs to nobody')
 local dark=true;for _,p in ipairs(sil:GetChildren())do if p:IsA('BasePart')and(p.Color.R>.1 or p.Color.G>.1 or p.Color.B>.15)then dark=false end end
 check(dark,'and is black')
 -- the same champion again: the description is cached, a new rig is made
 reset();A=new();A:Build(9000);A:Build(9000)
 check(HH.avatars.Describe==1 and HH.avatars.Create==2,'a champion\'s description is fetched once; each build makes a fresh rig')
end

-- 5. The pose maths ------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local names={};for k in pairs(Pose.Static)do names[#names+1]=k end
 local rigJoints={}
 local rig=HH.rig(0)
 for _,d in ipairs(rig:GetDescendants())do if d:IsA('Motor6D')then rigJoints[d.Name]=true end end
 local allExist=true;for _,n in ipairs(names)do if not rigJoints[n]then allExist=false end end
 check(allExist,'every joint the static pose names is a real R15 joint')
 local cheerOk=true;local maxAngle=0
 for boost=0,1,.25 do for t=0,20,.013 do
  local pose=Pose.CheerAt(t,boost)
  for name,cf in pairs(pose)do
   local a=angle(cf);if a~=a or a>Pose.MaxAngle then cheerOk=false end;maxAngle=math.max(maxAngle,a)
   if not rigJoints[name]then cheerOk=false end
  end
 end end
 check(cheerOk,'the cheer only moves real joints and no joint turns more than '..Pose.MaxAngle..' rad (the most is '..string.format('%.2f',maxAngle)..')')
 local weird=true
 for _,v in ipairs({0/0,math.huge,-math.huge,'x',nil})do
  local ok,pose=pcall(Pose.CheerAt,v,v);if not ok or not pose.RightShoulder then weird=false end
 end
 check(weird,'a NaN, infinite, missing or non-number time / boost gives a valid pose')
 local idle=Pose.CheerAt(0,0);local celebrating=Pose.CheerAt(0,1)
 check(angle(celebrating.LeftShoulder)>1 and angle(idle.LeftShoulder)<1e-6,'a celebration lifts the left arm as well; idle leaves it')
 check(Pose.CelebrateAt(-1)==0 and Pose.CelebrateAt(0)==0 and Pose.CelebrateAt(Pose.Celebrate.Duration)==0 and Pose.CelebrateAt(0/0)==0 and Pose.CelebrateAt('x')==0,'no celebration before, after or for bad input')
 local peak,prev,rising,falling=0,0,true,false
 for age=0,Pose.Celebrate.Duration,.01 do
  local v=Pose.CelebrateAt(age);peak=math.max(peak,v)
  if v<prev-1e-9 then falling=true elseif falling and v>prev+1e-9 then rising=false end
  prev=v
 end
 check(near(peak,1,1e-6)and rising,'the celebration goes up to 1, holds, and comes down (never up again)')
 local a=Pose.CheerAt(0.4,0);local b=Pose.CheerAt(0.4,0)
 check(angle(a.RightShoulder)==angle(b.RightShoulder),'the cheer is a pure function of time')
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('FAILED')end
