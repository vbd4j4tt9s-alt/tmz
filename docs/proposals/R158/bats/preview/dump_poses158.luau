--!nocheck
-- R158 bats: sample the swing poses for the preview renders, on an EXACT CFrame (rotation matrices, quaternion slerp in Lerp).
-- TODAY = the REAL src/ReplicatedStorage/BatSwingPose.lua (+ BatConfig.lua); PROPOSED = BatSwingPose158.luau. Both go through BatClient's
-- overlay math: each joint = (the Animator's pose):Lerp(key, weight), in parent space (BatClient conjugates by the joint's C0 basis, which
-- gives the same parent-space result). The Animator's pose is the default tool hold (right arm raised 90 degrees forward), everything else
-- at rest (standing). Output: one JSON object per line: {sys, rig, t, joints = {name = {w,x,y,z}}}.
-- Usage (from a folder with pose_bundle.luau = BatConfig, BatSwingPose, BatSwingPose158): luau dump_poses158.luau -a <fps> <seconds>
local B=require('./pose_bundle')
local args={...};local FPS=tonumber(args[1])or 30;local SECONDS=tonumber(args[2])or .95
-- exact CFrame (rotation only matters here) ---------------------------------------------------------------------------------------------------
local CF={};CF.__index=CF
local function make(m)return setmetatable({m=m},CF)end
local function mul(a,b)
 local r={}
 for i=0,2 do for j=0,2 do r[i*3+j+1]=a[i*3+1]*b[j+1]+a[i*3+2]*b[3+j+1]+a[i*3+3]*b[6+j+1]end end
 return r
end
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
local function fromQuat(w,x,y,z)
 return {1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)}
end
function CF.Lerp(a,b,t)
 local aw,ax,ay,az=quat(a.m);local bw,bx,by,bz=quat(b.m)
 local d=aw*bw+ax*bx+ay*by+az*bz
 if d<0 then bw,bx,by,bz,d=-bw,-bx,-by,-bz,-d end -- shortest arc (assumed to match Roblox's CFrame:Lerp)
 local w,x,y,z
 if d>.9995 then w,x,y,z=aw+(bw-aw)*t,ax+(bx-ax)*t,ay+(by-ay)*t,az+(bz-az)*t
 else local th=math.acos(d);local s=math.sin(th);local p,q=math.sin((1-t)*th)/s,math.sin(t*th)/s
  w,x,y,z=aw*p+bw*q,ax*p+bx*q,ay*p+by*q,az*p+bz*q end
 local n=math.sqrt(w*w+x*x+y*y+z*z);return make(fromQuat(w/n,x/n,y/n,z/n))
end
CF.__index=function(c,k)if k=='Rotation'then return c end;return rawget(CF,k)end
local function rx(a)local c,s=math.cos(a),math.sin(a);return{1,0,0,0,c,-s,0,s,c}end
local function ry(a)local c,s=math.cos(a),math.sin(a);return{c,0,s,0,1,0,-s,0,c}end
local function rz(a)local c,s=math.cos(a),math.sin(a);return{c,-s,0,s,c,0,0,0,1}end
local CFrame={new=function()return make({1,0,0,0,1,0,0,0,1})end,Angles=function(x,y,z)return make(mul(mul(rx(x),ry(y)),rz(z)))end}
CFrame.fromEulerAnglesXYZ=CFrame.Angles
-- the modules ---------------------------------------------------------------------------------------------------------------------------------
local function load(name,env)
 local fn,err=loadstring(B[name],'='..name);if not fn then error(err)end
 env.CFrame=CFrame;env.Vector3={new=function(x,y,z)return{X=x,Y=y,Z=z}end}
 setfenv(fn,setmetatable(env,{__index=getfenv(1)}));return fn()
end
local Config=load('BatConfig',{})
local marker={}
local Today=load('BatSwingPose',{script={Parent={BatConfig=marker}},require=function(x)assert(x==marker);return Config end})
local Proposed=load('BatSwingPose158',{})
-- the Animator's pose under the swing (parent space): the default tool hold raises the right arm 90 degrees forward
local BASE={RightShoulder=CFrame.Angles(math.rad(90),0,0)}
local JOINTS={R15={'RightShoulder','RightElbow','RightWrist','LeftShoulder','LeftElbow','Waist'},R6={'RightShoulder','LeftShoulder','RootJoint'}}
local function emit(sys,module,rig,t)
 local parts={}
 for _,name in ipairs(JOINTS[rig])do
  local key,weight=module.Sample(name,t,0,rig=='R6')
  local base=BASE[name]or CFrame.new()
  local final=base:Lerp(key,weight)
  local w,x,y,z=quat(final.m)
  table.insert(parts,string.format('"%s":[%.6f,%.6f,%.6f,%.6f]',name,w,x,y,z))
 end
 print(string.format('{"sys":"%s","rig":"%s","t":%.4f,"joints":{%s}}',sys,rig,t,table.concat(parts,',')))
end
local total={today=Config.Windup+Config.Recovery,proposed=Proposed.Total}
for _,sys in ipairs({'today','proposed'})do
 local module=sys=='today'and Today or Proposed
 for _,rig in ipairs({'R15','R6'})do
  local n=math.floor(SECONDS*FPS+.5)
  for i=0,n do emit(sys,module,rig,i/FPS)end
 end
end
print(string.format('{"meta":true,"todayTotal":%.3f,"todayContact":%.3f,"proposedTotal":%.3f,"proposedContact":%.3f,"hitFrom":%.3f,"hitTo":%.3f}',
 total.today,Config.Windup,total.proposed,Proposed.Contact,Proposed.HitFrom,Proposed.HitTo))
