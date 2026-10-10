--!nocheck
-- R158 bats, BUILT: the swing (src/ReplicatedStorage/BatSwingPose.lua) on an EXACT CFrame (rotation matrices, quaternion slerp in Lerp; the
-- preview's dump_poses158.luau maths):
--  1. timing: contact at BatConfig.Windup (.30 s, the server's hit time, unchanged), the whole swing .85 s (Windup + Recovery), the keys at
--     .07 / .22 / .26 / .30 / .335 / .52 (held to .60) / .72, the strike window .24-.36 around contact, the trail .21-.40 inside the swing
--  2. it IS the approved swing: every joint of R15 and R6 equals the owner-approved preview (docs/proposals/R158/bats/preview/BatSwingPose158.luau)
--     at every 1/240 s of the swing (and a late join, Lead)
--  3. upper body only: R15 moves RightShoulder / RightElbow / RightWrist / LeftShoulder / LeftElbow / Waist, R6 RightShoulder / LeftShoulder /
--     RootJoint; hips, knees, ankles, the root and the neck get nothing (weight 0)
--  4. R6: its RootJoint turns the whole body, so it gets 60 % of the R15 waist's twist and no lean (pure yaw)
--  5. smooth: no jump at any key (both sides of every key within a few degrees), weight 0 before and after, 1 from load to recovery; the load is fast
--     (ease-out), the strike accelerates into contact (the bat is fastest there), the follow-through slows down
-- Usage: luau test_bat_pose158.luau   (from a folder with pose_bundle.luau: BatConfig, BatSwingPose = the built one, BatSwingPose158 = the preview)
local B=require('./pose_bundle')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
-- exact CFrame (rotation only) -----------------------------------------------------------------------------------------------------------------------
local CF={};CF.__index=CF
local function make(m)return setmetatable({m=m},CF)end
local function mul(a,b)local r={};for i=0,2 do for j=0,2 do r[i*3+j+1]=a[i*3+1]*b[j+1]+a[i*3+2]*b[3+j+1]+a[i*3+3]*b[6+j+1]end end;return r end
CF.__mul=function(a,b)return make(mul(a.m,b.m))end
local function quat(m)
 local m00,m01,m02,m10,m11,m12,m20,m21,m22=m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8],m[9]
 local tr=m00+m11+m22;local w,x,y,z
 if tr>0 then local s=math.sqrt(tr+1)*2;w=s/4;x=(m21-m12)/s;y=(m02-m20)/s;z=(m10-m01)/s
 elseif m00>m11 and m00>m22 then local s=math.sqrt(1+m00-m11-m22)*2;w=(m21-m12)/s;x=s/4;y=(m01+m10)/s;z=(m02+m20)/s
 elseif m11>m22 then local s=math.sqrt(1+m11-m00-m22)*2;w=(m02-m20)/s;x=(m01+m10)/s;y=s/4;z=(m12+m21)/s
 else local s=math.sqrt(1+m22-m00-m11)*2;w=(m10-m01)/s;x=(m02+m20)/s;y=(m12+m21)/s;z=s/4 end
 return w,x,y,z
end
local function fromQuat(w,x,y,z)return {1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)}end
function CF.Lerp(a,b,t)
 local aw,ax,ay,az=quat(a.m);local bw,bx,by,bz=quat(b.m)
 local d=aw*bw+ax*bx+ay*by+az*bz
 if d<0 then bw,bx,by,bz,d=-bw,-bx,-by,-bz,-d end
 local w,x,y,z
 if d>.9995 then w,x,y,z=aw+(bw-aw)*t,ax+(bx-ax)*t,ay+(by-ay)*t,az+(bz-az)*t
 else local th=math.acos(d);local s=math.sin(th);local p,q=math.sin((1-t)*th)/s,math.sin(t*th)/s
  w,x,y,z=aw*p+bw*q,ax*p+bx*q,ay*p+by*q,az*p+bz*q end
 local n=math.sqrt(w*w+x*x+y*y+z*z);return make(fromQuat(w/n,x/n,y/n,z/n))
end
local function rx(a)local c,s=math.cos(a),math.sin(a);return{1,0,0,0,c,-s,0,s,c}end
local function ry(a)local c,s=math.cos(a),math.sin(a);return{c,0,s,0,1,0,-s,0,c}end
local function rz(a)local c,s=math.cos(a),math.sin(a);return{c,-s,0,s,c,0,0,0,1}end
local CFrame={new=function()return make({1,0,0,0,1,0,0,0,1})end,Angles=function(x,y,z)return make(mul(mul(rx(x),ry(y)),rz(z)))end}
-- the angle (degrees) between two rotations
local function angle(a,b)local aw,ax,ay,az=quat(a.m);local bw,bx,by,bz=quat(b.m);local d=math.abs(aw*bw+ax*bx+ay*by+az*bz);return math.deg(2*math.acos(math.min(1,d)))end
-- the modules ----------------------------------------------------------------------------------------------------------------------------------------
local function load(name,env)
 local fn,err=loadstring(B[name],'='..name);if not fn then error(err)end
 env.CFrame=CFrame;env.Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
 setfenv(fn,setmetatable(env,{__index=getfenv(1)}));return fn()
end
local C=load('BatConfig',{})
local marker={}
local Pose=load('BatSwingPose',{script={Parent={BatConfig=marker}},require=function(x)assert(x==marker);return C end})
local Approved=load('BatSwingPose158',{})
-- 1. timing ------------------------------------------------------------------------------------------------------------------------------------------
check(C.Windup==.30 and Pose.Contact==C.Windup and Pose.Keys.C==C.Windup,'contact at .30 s = BatConfig.Windup (the server\'s hit time does not move)')
check(Pose.Total==.85 and math.abs(C.Windup+C.Recovery-.85)<1e-9,'the whole swing is .85 s (Windup + Recovery)')
local K=Pose.Keys
check(K.A==.07 and K.A2==.22 and K.B==.26 and K.D==.335 and K.E==.52 and K.Hold==.60 and K.F==.72,'the keys: load .07, coil .22, B .26, contact .30, through .335, follow-through .52 held to .60, rising .72, rest .85')
check(C.HitFrom==.24 and C.HitTo==.36 and C.HitFrom<K.C and C.HitTo>K.C,'the strike window .24-.36 s is around contact')
check(C.TrailFrom<C.HitFrom and C.TrailTo>C.HitTo and C.TrailTo<Pose.Total,'the trail (.21-.40 s) covers the strike, inside the swing')
check(Approved.Total==Pose.Total and Approved.Contact==Pose.Contact and Approved.HitFrom==C.HitFrom and Approved.HitTo==C.HitTo and Approved.TrailFrom==C.TrailFrom and Approved.TrailTo==C.TrailTo,
 'the timing numbers are the approved preview\'s')
-- 2. the approved swing -------------------------------------------------------------------------------------------------------------------------------
local worst,where=0,''
for _,rig in ipairs({'R15','R6'})do for _,name in ipairs(Pose.Joints[rig])do for _,lead in ipairs({0,.03})do
 for i=-5,215 do
  local t=i/240
  local a,wa=Pose.Sample(name,t,lead,rig=='R6');local b,wb=Approved.Sample(name,t,lead,rig=='R6')
  local d=angle(a,b)+math.abs(wa-wb)*100
  if d>worst then worst=d;where=string.format('%s %s t=%.3f lead %.2f',rig,name,t,lead)end
 end
end end end
check(worst<1e-4,'every joint of R15 and R6 equals the owner-approved preview at every 1/240 s, within 0.0001 degrees (worst '..string.format('%.2g',worst)..' '..where..')')
-- 3. upper body only ------------------------------------------------------------------------------------------------------------------------------------
check(table.concat(Pose.Joints.R15,',')=='RightShoulder,RightElbow,RightWrist,LeftShoulder,LeftElbow,Waist'and table.concat(Pose.Joints.R6,',')=='RightShoulder,LeftShoulder,RootJoint','the joints: R15 right arm + left arm + waist, R6 both shoulders + RootJoint')
local legs=0
for _,name in ipairs({'RightHip','LeftHip','RightKnee','LeftKnee','RightAnkle','LeftAnkle','Root','Neck','LeftWrist','Right Hip','Left Hip'})do for i=0,85 do
 local _,w1=Pose.Sample(name,i/100,0,false);local _,w2=Pose.Sample(name,i/100,0,true);legs+=w1+w2
end end
check(legs==0,'legs, knees, ankles, the root and the neck get nothing (the Animator keeps running / jumping them)')
-- 4. R6: 60 % twist, no lean ----------------------------------------------------------------------------------------------------------------------------
local ratioOk,leanOk=true,true
for _,t in ipairs({K.A,K.A2,K.B,K.C,K.D,K.E,K.F})do
 local r15=Pose.Sample('Waist',t,0,false);local r6=Pose.Sample('RootJoint',t,0,true)
 local yaw15=math.deg(math.asin(math.clamp(r15.m[3],-1,1)));local yaw6=math.deg(math.asin(math.clamp(r6.m[3],-1,1)))
 if math.abs(yaw6-.6*yaw15)>1.5 then ratioOk=false;print(string.format('  t %.3f: R15 yaw %.1f, R6 %.1f',t,yaw15,yaw6))end
 if math.abs(r6.m[5]-1)>1e-9 or math.abs(r6.m[2])>1e-9 or math.abs(r6.m[8])>1e-9 then leanOk=false end
end
check(ratioOk,'R6\'s RootJoint (the whole body) turns 60 % of the R15 waist\'s twist at every key (within 1.5 degrees)')
check(leanOk,'R6: no lean (a pure turn about the vertical: the legs stay upright)')
-- 5. smooth ---------------------------------------------------------------------------------------------------------------------------------------------
local jump,jumpAt=0,''
for _,rig in ipairs({'R15','R6'})do for _,name in ipairs(Pose.Joints[rig])do for _,t in ipairs({K.A,K.A2,K.B,K.C,K.D,K.E,K.Hold,K.F})do
 local a=Pose.Sample(name,t-1e-4,0,rig=='R6');local b=Pose.Sample(name,t+1e-4,0,rig=='R6')
 local d=angle(a,b);if d>jump then jump=d;jumpAt=rig..' '..name..' '..t end
end end end
check(jump<3,'no jump at any key: both sides within '..string.format('%.2f',jump)..' degrees ('..jumpAt..')')
local _,w0=Pose.Sample('RightShoulder',-.01,0,false);local _,w1=Pose.Sample('RightShoulder',Pose.Total,0,false);local _,wm=Pose.Sample('RightShoulder',.5,0,false)
check(w0==0 and w1==0 and wm==1,'weight 0 before and after the swing, 1 in it')
local _,wl=Pose.Sample('RightShoulder',.035,0,false);check(wl>.7,'the load is fast: weight '..string.format('%.2f',wl)..' half way to .07 s (ease-out)')
local _,late=Pose.Sample('RightShoulder',.02,.02,false);check(late==0,'a swing joined late (Lead .02 s) starts its load from there (weight 0 at the join), as before')
-- the right arm turns fastest into contact and slower after (degrees per 1/120 s)
local function speed(t)return angle(Pose.Sample('RightShoulder',t,0,false),Pose.Sample('RightShoulder',t+1/120,0,false))*120 end
local before,coil,follow=speed(.29),speed(.15),speed(.45)
check(before>3*coil and before>2*follow,string.format('the strike accelerates into contact (%.0f deg/s just before, the coil %.0f, the follow-through %.0f)',before,coil,follow))
print(string.format('bat pose: %d checks, %d failed',checks,fails))
if fails>0 then error('bat pose test failed')end
