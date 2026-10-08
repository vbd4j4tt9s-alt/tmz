--!nocheck
-- R153 jitter checks: the R149 zfight_world mock (world.luau with Model pivots, full CFrames, bounding boxes) plus what the effect scripts need, and a
-- frame driver that runs a frame the way Roblox does (bound render steps, RenderStepped, then Heartbeat / PreSimulation) and lets a test read what is
-- DRAWN: the state right after RenderStepped, before the physics half of the frame. Frame rates: any dt (the checks use 30 / 60 / 144 fps).
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local J={W=W,R=R,Z=Z,tier=3}
local Run=W.service('RunService');Run.PreAnimation=Run.PreAnimation or R.signal();Run.PreRender=Run.PreRender or R.signal()
-- A real CFrame inverse (the mock's is a transpose: a model moved every frame would drift; as R150's pedestal harness).
do
 local mt=getmetatable(CF(0,0,0))
 rawset(mt,'Inverse',function(c)
  local m=c.R;local a,b,cc,d,e,f,g,h,i=m[1][1],m[1][2],m[1][3],m[2][1],m[2][2],m[2][3],m[3][1],m[3][2],m[3][3]
  local det=a*(e*i-f*h)-b*(d*i-f*g)+cc*(d*h-e*g)
  local r11,r12,r13=(e*i-f*h)/det,(cc*h-b*i)/det,(b*f-cc*e)/det
  local r21,r22,r23=(f*g-d*i)/det,(a*i-cc*g)/det,(cc*d-a*f)/det
  local r31,r32,r33=(d*h-e*g)/det,(b*g-a*h)/det,(a*e-b*d)/det
  local p=c.Position
  return R.CFrame.new(-(r11*p.X+r12*p.Y+r13*p.Z),-(r21*p.X+r22*p.Y+r23*p.Z),-(r31*p.X+r32*p.Y+r33*p.Z),r11,r12,r13,r21,r22,r23,r31,r32,r33)
 end)
 rawset(mt,'ToObjectSpace',function(a,b)return a:Inverse()*b end)
 rawset(mt,'PointToObjectSpace',function(a,v)return a:Inverse()*v end)
 rawset(mt,'Lerp',function(a,b,t)
  -- position lerp; rotation: the nearer one (enough here: every check measures movement, not the exact turn in between)
  return setmetatable({Position=a.Position:Lerp(b.Position,t),R=t<.5 and a.R or b.R,__type='CFrame'},mt)
 end)
 local eq=mt.__eq
 mt.__eq=eq or function(a,b)
  if a.Position~=b.Position then return false end
  for i=1,3 do for j=1,3 do if a.R[i][j]~=b.R[i][j]then return false end end end
  return true
 end
end
-- Color3: real HSV, value equality.
do
 local c3=getmetatable(R.Color3.new(0,0,0))
 c3.__eq=function(a,b)return a.R==b.R and a.G==b.G and a.B==b.B end
 R.Color3.fromHSV=function(h,s,v)
  h=(h%1)*6;local i=math.floor(h)%6;local f=h-math.floor(h);local p,q,t=v*(1-s),v*(1-s*f),v*(1-s*(1-f))
  local r=({{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}})[i+1]
  return R.Color3.new(r[1],r[2],r[3])
 end
 W.env.Color3=R.Color3
end
-- workspace: BulkMoveTo really moves; a flat floor at y = J.ground for Raycast.
J.ground=0
function W.workspace.BulkMoveTo(_,parts,frames)for i,p in ipairs(parts)do if p.Parent then p.CFrame=frames[i]end end end
function W.workspace.Raycast(_,origin,dir)
 local y0,y1=origin.Y,origin.Y+dir.Y
 if y0>=J.ground and y1<=J.ground and dir.Y~=0 then local k=(origin.Y-J.ground)/-dir.Y;return {Position=origin+dir*k,Normal=V3(0,1,0),Instance=W.workspace,Material=R.Enum.Material.Plastic}end
 return nil
end
-- The camera: a vertical field of view, ViewportPointToRay and WorldToViewportPoint like Roblox's default camera.
local cam=W.workspace.CurrentCamera;cam.FieldOfView=70;cam.ViewportSize=R.Vector2.new(1280,720)
cam.ViewportPointToRay=function(self,x,y)
 local vs=self.ViewportSize;local tv=math.tan(math.rad(self.FieldOfView)/2);local th=tv*vs.X/vs.Y
 local dx,dy=(2*x/vs.X-1)*th,(1-2*y/vs.Y)*tv;local cf=self.CFrame
 return {Origin=cf.Position,Direction=(cf.RightVector*dx+cf.UpVector*dy+cf.LookVector).Unit}
end
cam.WorldToViewportPoint=function(self,p)
 local rel=self.CFrame:Inverse()*p;local vs=self.ViewportSize;local tv=math.tan(math.rad(self.FieldOfView)/2);local th=tv*vs.X/vs.Y
 if rel.Z>=0 then return V3(0,0,rel.Z),false end
 local x,y=rel.X/(-rel.Z)/th,rel.Y/(-rel.Z)/tv
 return V3((x+1)/2*vs.X,(1-y)/2*vs.Y,-rel.Z),math.abs(x)<=1 and math.abs(y)<=1
end
cam.WorldToScreenPoint=cam.WorldToViewportPoint
function J.look(from,at)cam.CFrame=R.CFrame.lookAt(from,at);cam.Focus=CF(at.X,at.Y,at.Z)end
-- Players and characters.
local Players=W.service('Players');Players.PlayerAdded=Players.PlayerAdded or R.signal();Players.PlayerRemoving=Players.PlayerRemoving or R.signal()
J.players={}
function Players.GetPlayers()return table.clone(J.players)end
function Players.GetPlayerFromCharacter(_,c)for _,p in ipairs(J.players)do if p.Character==c then return p end end;return nil end
function Players.GetPlayerByUserId(_,id)for _,p in ipairs(J.players)do if p.UserId==id then return p end end;return nil end
function J.player(name,id,isLocal)
 local p=R.new('Player');p.Name=name;p.UserId=id;p.DisplayName=name;p.Parent=Players
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=p
 local bp=R.new('Backpack');bp.Name='Backpack';bp.Parent=p
 p.CharacterAdded=R.signal();p.CharacterRemoving=R.signal()
 J.players[#J.players+1]=p
 if isLocal then Players.LocalPlayer=p end
 return p
end
-- A small R15-shaped character at `pos` (its HumanoidRootPart's centre), standing on the floor.
function J.character(p,pos)
 local c=R.new('Model');c.Name=p.Name
 local function part(name,size,off)local x=R.new('Part');x.Name=name;x.Size=size;x.CFrame=CF(pos.X+off.X,pos.Y+off.Y,pos.Z+off.Z);x.Anchored=false;x.Parent=c;return x end
 local root=part('HumanoidRootPart',V3(2,2,1),V3(0,0,0));c.PrimaryPart=root;root.AssemblyLinearVelocity=V3(0,0,0)
 part('UpperTorso',V3(2,1.6,1),V3(0,.6,0));part('Head',V3(1.2,1.2,1.2),V3(0,1.5,0))
 part('LeftFoot',V3(1,.3,1),V3(-.5,-2.85,0));part('RightFoot',V3(1,.3,1),V3(.5,-2.85,0))
 part('LeftLowerLeg',V3(1,1.2,1),V3(-.5,-2.1,0));part('RightLowerLeg',V3(1,1.2,1),V3(.5,-2.1,0));part('LeftUpperLeg',V3(1,1.2,1),V3(-.5,-1.1,0));part('RightUpperLeg',V3(1,1.2,1),V3(.5,-1.1,0))
 local h=R.new('Humanoid');h.Health=100;h.MaxHealth=100;h.HipHeight=2;h.WalkSpeed=16;h.DisplayName=p.Name;h.FloorMaterial=R.Enum.Material.Plastic
 h.MoveDirection=V3(0,0,0);h.Sit=false;h.PlatformStand=false;h.NameDisplayDistance=100;h.Died=R.signal();h.Parent=c
 c.Parent=W.workspace;p.Character=c;p.CharacterAdded:Fire(c)
 return c
end
-- Moves a whole character by `delta` (every part), with the root's velocity set for scripts that read it.
function J.move(c,delta,dt)
 for _,d in ipairs(c:GetDescendants())do if d:IsA('BasePart')then d.CFrame=d.CFrame+delta end end
 local root=c:FindFirstChild('HumanoidRootPart');if root and dt and dt>0 then root.AssemblyLinearVelocity=delta/dt end
end
-- UserSettings (graphics level) and the quality governor at a fixed tier (J.tier).
W.env.UserSettings=function()return {GetService=function()return {SavedQualityLevel={Value=10}}end}end
W.stub('ClientFxBudget',{Get=function()return J.tier end,Low=function()return J.tier==1 end,New=function()return {Tier=J.tier}end,Step=function()return J.tier end})
-- The frame driver ------------------------------------------------------------------------------------------------------------------------------------------
-- One frame of dt: bound render steps (priority order), RenderStepped, then `drawn` (what the screen shows), then Heartbeat / PreSimulation / PostSimulation.
function J.frame(dt,drawn)
 R.advance(dt)
 if #W.rsOrder>0 then
  local list=table.clone(W.rsOrder);table.sort(list,function(a,b)local pa,pb=W.rsBound[a].Prio,W.rsBound[b].Prio;if pa~=pb then return pa<pb end;return table.find(W.rsOrder,a)<table.find(W.rsOrder,b)end)
  for _,name in ipairs(list)do local b=W.rsBound[name];if b then b.Fn(dt)end end
 end
 Run.RenderStepped:Fire(dt)
 if drawn then drawn()end
 Run.PreAnimation:Fire(dt);Run.Heartbeat:Fire(dt);Run.PreSimulation:Fire(dt);if Run.PostSimulation then Run.PostSimulation:Fire(dt)end
end
function J.run(seconds,fps,each)local dt=1/(fps or 60);for _=1,math.floor(seconds*(fps or 60)+.5)do J.frame(dt,each)end end
-- Only the physics half of frames (no RenderStepped): what a script draws from Heartbeat / Stepped would still move here.
function J.physicsOnly(n,dt)dt=dt or 1/60;for _=1,n do R.advance(dt);Run.PreAnimation:Fire(dt);Run.Heartbeat:Fire(dt);Run.PreSimulation:Fire(dt);if Run.Stepped then Run.Stepped:Fire(0,dt)end end end
-- Samples a value after RenderStepped every frame for `frames` frames at `fps` (before = a hook run before each frame, e.g. to move a runner).
function J.sample(fps,frames,read,before)
 local out={};local dt=1/fps
 for i=1,frames do if before then before(i,dt)end;J.frame(dt,function()out[#out+1]=read()end)end
 return out
end
-- How many consecutive drawn frames show the same value (a stall: the screen repeats a frame while the thing should be moving).
local function same(a,b,eps)
 eps=eps or 1e-7
 local t=R.typeof(a)
 if t=='Vector3'then return(a-b).Magnitude<=eps end
 if t=='CFrame'then
  if(a.Position-b.Position).Magnitude>eps then return false end
  for i=1,3 do for j=1,3 do if math.abs(a.R[i][j]-b.R[i][j])>eps then return false end end end;return true
 end
 if t=='Color3'then return math.abs(a.R-b.R)<=eps and math.abs(a.G-b.G)<=eps and math.abs(a.B-b.B)<=eps end
 if t=='UDim2'then return math.abs(a.X.Scale-b.X.Scale)<=eps and math.abs(a.X.Offset-b.X.Offset)<=eps and math.abs(a.Y.Scale-b.Y.Scale)<=eps and math.abs(a.Y.Offset-b.Y.Offset)<=eps end
 if type(a)=='number'and type(b)=='number'then return math.abs(a-b)<=eps end
 if type(a)=='table'and type(b)=='table'then for k,v in pairs(a)do if not same(v,b[k],eps)then return false end end;return true end
 return a==b
end
J.same=same
function J.stalls(list,eps)local n=0;for i=2,#list do if same(list[i],list[i-1],eps)then n+=1 end end;return n end
-- The standard check: at 30, 60 and 144 fps the value advances on every drawn frame (no repeated frame), over `seconds`.
-- setup(fps) runs before each rate (place the camera, reset), read() returns the drawn value, before(i, dt) runs before each frame.
function J.everyFrame(check,label,seconds,setup,read,before,eps)
 for _,fps in ipairs({30,60,144})do
  if setup then setup(fps)end
  local frames=math.floor(seconds*fps+.5)
  local list=J.sample(fps,frames,read,before)
  local stalls=J.stalls(list,eps)
  check(#list==frames and stalls==0,string.format('%s: advances on every drawn frame at %d fps (%d frames, %d repeated)',label,fps,#list,stalls))
 end
end
-- Connections of a signal that are live (to see which per-frame signal a script uses).
function J.live(signal)local n=0;for _,c in ipairs(signal._c)do if c.Connected then n+=1 end end;return n end
J.Run=Run;J.Players=Players;J.cam=cam
return J
