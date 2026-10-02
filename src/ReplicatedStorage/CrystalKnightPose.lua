-- R59: fixed-length arms solve to the sword grip; the weapon never slides through a hand.
local M={};local V,CF=Vector3.new,CFrame.new
local function author(x,y,z)return V(-x,y-4,-z)end
local function segment(a,b)
 local up=(a-b).Unit;local right=up:Cross(Vector3.zAxis)
 if right.Magnitude<.01 then right=up:Cross(Vector3.xAxis)end
 right=right.Unit;return CFrame.fromMatrix((a+b)*.5,right,up,right:Cross(up))
end
local function solve(a,target,restA,restB,restC,bend)
 local l1=(restA-restB).Magnitude;local l2=(restB-restC).Magnitude
 local delta=target-a;local d=math.clamp(delta.Magnitude,.1,l1+l2-.025);local axis=delta.Unit
 local hand=a+axis*d;local b=bend-axis*bend:Dot(axis)
 if b.Magnitude<.01 then b=axis:Cross(Vector3.yAxis)end;b=b.Unit
 local along=(l1*l1-l2*l2+d*d)/(2*d);local elbow=a+axis*along+b*math.sqrt(math.max(0,l1*l1-along*along))
 return segment(a,elbow)*segment(restA,restB):Inverse(),segment(elbow,hand)*segment(restB,restC):Inverse(),hand
end
local function direction(d)
 local up=-d.Unit;local right=Vector3.xAxis-up*up:Dot(Vector3.xAxis)
 if right.Magnitude<.01 then right=Vector3.zAxis-up*up:Dot(Vector3.zAxis)end
 right=right.Unit;return CFrame.fromMatrix(Vector3.zero,right,up,right:Cross(up))
end
-- R123: custom (client-only KeeperSignatureStrike) = {Twist=Vector3(pitch,yaw,0), Right=, Left= (author space), Rotation=CFrame}.
-- Server callers never pass it, so their frames are unchanged.
function M.Adapt(base,awake,moving,cycle,t,load,hit,custom)
 local out=table.clone(base);local a=math.clamp(awake or 1,0,1);a=a*a*(3-2*a)
 load=load or 0;hit=hit or 0;local body=base.Body
 if load>0 or hit>0 then
  local pivot=author(0,18,0)
  local twist=CF(pivot)*CFrame.Angles(-.07*load+.1*hit,.18*load-.32*hit,0)*CF(-pivot)
  body=twist*body;out.Body=body;out.Head=twist*base.Head
 end
 if custom then
  local pivot=author(0,18,0)
  local twist=CF(pivot)*CFrame.Angles(custom.Twist.X,custom.Twist.Y,0)*CF(-pivot)
  body=twist*body;out.Body=body;out.Head=twist*base.Head
 end
 local bob=math.sin(cycle or 0)*.35*(moving or 0)
 local rightTarget=author(0,11.58,5):Lerp(author(7.5,16.6+bob,5),a)
 local leftTarget=author(0,13.7,5):Lerp(author(-9.0,8.5-bob,1.8),a)
 rightTarget=rightTarget:Lerp(author(8.6,24,2.8),load):Lerp(author(-2.2,12.0,9.7),hit)
 leftTarget=leftTarget:Lerp(author(-7,15,3),load):Lerp(author(-7,13,5),hit)
 local blade=V(0,-1,0):Lerp(V(0,.88,-.48),a)
 blade=blade:Lerp(V(.20,.96,.22),load):Lerp(V(-.33,-.64,-.70),hit)
 -- Rotation interpolation avoids the zero direction at the idle-to-raised midpoint.
 local rotation=direction(V(0,-1,0)):Lerp(direction(V(0,.88,-.48)),a)
 rotation=rotation:Lerp(direction(V(.20,.96,.22)),load):Lerp(direction(V(-.33,-.64,-.70)),hit)
 if custom then
  rightTarget=author(custom.Right.X,custom.Right.Y,custom.Right.Z);leftTarget=author(custom.Left.X,custom.Left.Y,custom.Left.Z)
  rotation=custom.Rotation
 end
 local hand
 for _,side in ipairs({'Left','Right'})do
  local s=side=='Left'and -1 or 1
  local rA,rB,rC=author(s*9.1,22,0),author(s*9.1,13.8,.6),author(s*9.1,5.6,2.8)
  local upper,fore,wrist=solve(body*rA,body*(side=='Right'and rightTarget or leftTarget),rA,rB,rC,body:VectorToWorldSpace(V(-s,-.25,-.35)))
  out[side..'Arm']=upper;out[side..'Forearm']=fore
  if side=='Right'then hand=wrist end
 end
 local restGrip=author(9.1,5.6,2.8)
 out.Sword=CF(hand)*body.Rotation*rotation*CF(-restGrip)
 return out
end
M.Direction=direction
return M
