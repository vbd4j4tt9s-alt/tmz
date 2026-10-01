--!nocheck
-- Exact-enough CFrame/Vector3 for offline pose checks (row-major rotation, Roblox conventions).
local M={}
local V3={};V3.__index=V3
local function v3(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__type='Vector3'},V3)end
V3.__add=function(a,b)return v3(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V3.__sub=function(a,b)return v3(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V3.__mul=function(a,b)if type(a)=='number'then return v3(b.X*a,b.Y*a,b.Z*a)elseif type(b)=='number'then return v3(a.X*b,a.Y*b,a.Z*b)else return v3(a.X*b.X,a.Y*b.Y,a.Z*b.Z)end end
V3.__div=function(a,b)if type(b)=='number'then return v3(a.X/b,a.Y/b,a.Z/b)end;return v3(a.X/b.X,a.Y/b.Y,a.Z/b.Z)end
V3.__unm=function(a)return v3(-a.X,-a.Y,-a.Z)end
V3.__eq=function(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
V3.__tostring=function(a)return string.format('%.3f, %.3f, %.3f',a.X,a.Y,a.Z)end
V3.__index=function(a,k)
 if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end
 if k=='Unit'then local m=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z);return m>0 and v3(a.X/m,a.Y/m,a.Z/m)or v3(0,0,0)end
 return rawget(V3,k)
end
function V3.Dot(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
function V3.Cross(a,b)return v3(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end
function V3.Lerp(a,b,t)return a+(b-a)*t end
function V3.Min(a,b)return v3(math.min(a.X,b.X),math.min(a.Y,b.Y),math.min(a.Z,b.Z))end
function V3.Max(a,b)return v3(math.max(a.X,b.X),math.max(a.Y,b.Y),math.max(a.Z,b.Z))end
function V3.Abs(a)return v3(math.abs(a.X),math.abs(a.Y),math.abs(a.Z))end
M.Vector3={new=v3,zero=v3(0,0,0),one=v3(1,1,1),xAxis=v3(1,0,0),yAxis=v3(0,1,0),zAxis=v3(0,0,1)}
local CF={}
local function cf(p,r)return setmetatable({Position=p,R=r,__type='CFrame'},CF)end
local I={{1,0,0},{0,1,0},{0,0,1}}
local function mulR(a,b)local r={}for i=1,3 do r[i]={}for j=1,3 do r[i][j]=a[i][1]*b[1][j]+a[i][2]*b[2][j]+a[i][3]*b[3][j]end end;return r end
local function apply(r,v)return v3(r[1][1]*v.X+r[1][2]*v.Y+r[1][3]*v.Z,r[2][1]*v.X+r[2][2]*v.Y+r[2][3]*v.Z,r[3][1]*v.X+r[3][2]*v.Y+r[3][3]*v.Z)end
local function tr(r)return {{r[1][1],r[2][1],r[3][1]},{r[1][2],r[2][2],r[3][2]},{r[1][3],r[2][3],r[3][3]}}end
CF.__mul=function(a,b)
 if getmetatable(b)==CF then return cf(a.Position+apply(a.R,b.Position),mulR(a.R,b.R))end
 return a.Position+apply(a.R,b)
end
CF.__add=function(a,v)return cf(a.Position+v,a.R)end
CF.__sub=function(a,v)return cf(a.Position-v,a.R)end
CF.__eq=function(a,b)for i=1,3 do for j=1,3 do if a.R[i][j]~=b.R[i][j]then return false end end end;return a.Position==b.Position end
CF.__index=function(c,k)
 if k=='LookVector'then return v3(-c.R[1][3],-c.R[2][3],-c.R[3][3])end
 if k=='RightVector'then return v3(c.R[1][1],c.R[2][1],c.R[3][1])end
 if k=='UpVector'then return v3(c.R[1][2],c.R[2][2],c.R[3][2])end
 if k=='XVector'then return v3(c.R[1][1],c.R[2][1],c.R[3][1])end
 if k=='YVector'then return v3(c.R[1][2],c.R[2][2],c.R[3][2])end
 if k=='ZVector'then return v3(c.R[1][3],c.R[2][3],c.R[3][3])end
 if k=='Rotation'then return cf(v3(),c.R)end
 if k=='X'then return c.Position.X elseif k=='Y'then return c.Position.Y elseif k=='Z'then return c.Position.Z end
 return rawget(CF,k)
end
CF.__tostring=function(c)return tostring(c.Position)end
function CF.Inverse(c)local r=tr(c.R);return cf(-apply(r,c.Position),r)end
function CF.PointToWorldSpace(c,v)return c*v end
function CF.PointToObjectSpace(c,v)return apply(tr(c.R),v-c.Position)end
function CF.VectorToWorldSpace(c,v)return apply(c.R,v)end
function CF.VectorToObjectSpace(c,v)return apply(tr(c.R),v)end
function CF.ToObjectSpace(a,b)return a:Inverse()*b end
function CF.ToWorldSpace(a,b)return a*b end
function CF.GetComponents(c)local r=c.R;return c.Position.X,c.Position.Y,c.Position.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3]end
-- quaternion helpers
local function toQ(r)
 local tr_=r[1][1]+r[2][2]+r[3][3];local w,x,y,z
 if tr_>0 then local s=math.sqrt(tr_+1)*2;w=.25*s;x=(r[3][2]-r[2][3])/s;y=(r[1][3]-r[3][1])/s;z=(r[2][1]-r[1][2])/s
 elseif r[1][1]>r[2][2]and r[1][1]>r[3][3]then local s=math.sqrt(1+r[1][1]-r[2][2]-r[3][3])*2;w=(r[3][2]-r[2][3])/s;x=.25*s;y=(r[1][2]+r[2][1])/s;z=(r[1][3]+r[3][1])/s
 elseif r[2][2]>r[3][3]then local s=math.sqrt(1+r[2][2]-r[1][1]-r[3][3])*2;w=(r[1][3]-r[3][1])/s;x=(r[1][2]+r[2][1])/s;y=.25*s;z=(r[2][3]+r[3][2])/s
 else local s=math.sqrt(1+r[3][3]-r[1][1]-r[2][2])*2;w=(r[2][1]-r[1][2])/s;x=(r[1][3]+r[3][1])/s;y=(r[2][3]+r[3][2])/s;z=.25*s end
 return {w,x,y,z}
end
local function fromQ(q)
 local w,x,y,z=q[1],q[2],q[3],q[4];local n=math.sqrt(w*w+x*x+y*y+z*z);w/=n;x/=n;y/=n;z/=n
 return {{1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)},{2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)},{2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)}}
end
local function slerp(a,b,t)
 local d=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4]
 if d<0 then b={-b[1],-b[2],-b[3],-b[4]};d=-d end
 if d>.9995 then return {a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t,a[4]+(b[4]-a[4])*t}end
 local th=math.acos(math.clamp(d,-1,1));local s=math.sin(th)
 local wa,wb=math.sin((1-t)*th)/s,math.sin(t*th)/s
 return {a[1]*wa+b[1]*wb,a[2]*wa+b[2]*wb,a[3]*wa+b[3]*wb,a[4]*wa+b[4]*wb}
end
function CF.Lerp(a,b,t)return cf(a.Position:Lerp(b.Position,t),fromQ(slerp(toQ(a.R),toQ(b.R),t)))end
function CF.ToEulerAnglesXYZ(c)
 local r=c.R;local y=math.asin(math.clamp(r[1][3],-1,1))
 local x=math.atan2(-r[2][3],r[3][3]);local z=math.atan2(-r[1][2],r[1][1]);return x,y,z
end
M.angleBetween=function(a,b)local d=0;local qa,qb=toQ(a.R),toQ(b.R);d=math.abs(qa[1]*qb[1]+qa[2]*qb[2]+qa[3]*qb[3]+qa[4]*qb[4]);return 2*math.acos(math.clamp(d,-1,1))end
local function angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local rx={{1,0,0},{0,cx,-sx},{0,sx,cx}};local ry={{cy,0,sy},{0,1,0},{-sy,0,cy}};local rz={{cz,-sz,0},{sz,cz,0},{0,0,1}}
 return cf(v3(),mulR(mulR(rx,ry),rz))
end
local function new(x,y,z,...)
 if x==nil then return cf(v3(),I)end
 if type(x)=='table'then
  if y~=nil then -- new(pos, lookAt)
   local f=(y-x).Unit;local r=f:Cross(v3(0,1,0)).Unit;local u=r:Cross(f);return cf(x,{{r.X,u.X,-f.X},{r.Y,u.Y,-f.Y},{r.Z,u.Z,-f.Z}})
  end
  return cf(x,I)
 end
 local rest={...}
 if #rest==9 then return cf(v3(x,y,z),{{rest[1],rest[2],rest[3]},{rest[4],rest[5],rest[6]},{rest[7],rest[8],rest[9]}})end
 return cf(v3(x,y,z),I)
end
M.CFrame={new=new,Angles=angles,fromEulerAnglesXYZ=angles,identity=cf(v3(),I),
 fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return cf(p,{{x.X,y.X,z.X},{x.Y,y.Y,z.Y},{x.Z,y.Z,z.Z}})end,
 fromAxisAngle=function(axis,a)local u=axis.Unit;local s=math.sin(a/2);return cf(v3(),fromQ({math.cos(a/2),u.X*s,u.Y*s,u.Z*s}))end,
 lookAt=function(p,t)return new(p,t)end}
M.isCF=function(c)return getmetatable(c)==CF end
M.rows=function(c)return c.R end
M.Color3={new=function(r,g,b)return {R=r,G=g,B=b,__type='Color3'}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255,__type='Color3'}end}
return M
