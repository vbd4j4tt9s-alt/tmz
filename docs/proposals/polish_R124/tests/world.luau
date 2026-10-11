--!nocheck
-- Mock world that loads real ReplicatedStorage modules lazily from rs_bundle.
local R=require('./roblox');local B=require('./rs_bundle')
local new,V3,CF=R.new,R.Vector3.new,R.CFrame.new
local W={R=R,B=B}
local game=new('DataModel');local services={}
local function service(name)local s=services[name];if not s then s=new(name);s.Name=name;s.Parent=game;services[name]=s end;return s end
function game.GetService(_,n)return service(n)end
game.FindService=game.GetService
W.game=game;W.service=service
local workspace=service('Workspace');W.workspace=workspace
local camera=new('Camera');camera.ViewportSize=R.Vector2.new(1280,720);camera.CFrame=CF(0,20,-30);camera.Parent=workspace;workspace.CurrentCamera=camera
function workspace.GetServerTimeNow()return R.clock end
function workspace.BulkMoveTo()end
local Run=service('RunService');Run.RenderStepped=R.signal();Run.Heartbeat=R.signal();Run.Stepped=R.signal();Run.PreSimulation=R.signal();Run.PostSimulation=R.signal()
Run.IsStudio=function()return false end;Run.IsClient=function()return true end;Run.IsServer=function()return false end;Run.IsRunning=function()return true end
local UIS=service('UserInputService');UIS.TouchEnabled=false;UIS.MouseEnabled=true;UIS.KeyboardEnabled=true;UIS.LastInputTypeChanged=R.signal()
UIS.InputBegan=R.signal();UIS.InputEnded=R.signal();UIS.InputChanged=R.signal();UIS.WindowFocusReleased=R.signal()
function UIS.GetFocusedTextBox()return nil end;function UIS.GetLastInputType()return R.Enum.UserInputType.MouseMovement end;function UIS.IsKeyDown()return false end
local Gui=service('GuiService');Gui.ReducedMotionEnabled=false;function Gui.GetInsetArea()return {Min=R.Vector2.new(0,0),Width=1280,Height=720}end;function Gui.GetGuiInset()return R.Vector2.new(0,0),R.Vector2.new(0,0)end
local SG=service('StarterGui');function SG.SetCoreGuiEnabled()end;function SG.SetCore()end
local CAS=service('ContextActionService');W.actions={};function CAS.BindAction(_,name,fn)W.actions[name]=fn end;function CAS.UnbindAction(_,name)W.actions[name]=nil end
local TextS=service('TextService');function TextS.GetTextSize(_,text,size,_,bounds)return R.Vector2.new(math.min(bounds.X,utf8.len(text)*size*.52),size*1.2)end
local Tween=service('TweenService');function Tween.Create(_,obj,_,props)return {Play=function()for k,v in pairs(props)do obj[k]=v end end,Cancel=function()end,Completed=R.signal()}end
-- CollectionService with tag tracking (only instances under game fire signals).
local CS=service('CollectionService');local tags={};local added={};local removed={}
local function tagSet(t)tags[t]=tags[t]or setmetatable({},{__mode='k'});return tags[t]end
function CS.AddTag(_,o,t)o._tags=o._tags or{};o._tags[t]=true;tagSet(t)[o]=true;if o:IsDescendantOf(game)and added[t]then added[t]:Fire(o)end end
function CS.RemoveTag(_,o,t)if o._tags then o._tags[t]=nil end;tagSet(t)[o]=nil;if removed[t]then removed[t]:Fire(o)end end
function CS.HasTag(_,o,t)return o._tags~=nil and o._tags[t]==true end
function CS.GetTags(_,o)local out={};for t in pairs(o._tags or{})do out[#out+1]=t end;return out end
function CS.GetTagged(_,t)local out={};for o in pairs(tagSet(t))do if o:IsDescendantOf(game)then out[#out+1]=o end end;return out end
function CS.GetInstanceAddedSignal(_,t)added[t]=added[t]or R.signal();return added[t]end
function CS.GetInstanceRemovedSignal(_,t)removed[t]=removed[t]or R.signal();return removed[t]end
W.tags=tags
-- CFrame helpers missing from the shared mock.
do
 local mt=getmetatable(R.CFrame.new(0,0,0));local base=mt.__index
 mt.__index=function(c,k)
  if k=='Rotation'then return setmetatable({Position=V3(0,0,0),R=c.R,__type='CFrame'},mt)end
  return base(c,k)
 end
 rawset(mt,'ToObjectSpace',function(a,b)return a:Inverse()*b end)
 rawset(mt,'PointToObjectSpace',function(a,v)return a:Inverse()*v end)
 rawset(mt,'VectorToWorldSpace',function(a,v)return (a*v)-a.Position end)
 rawset(mt,'VectorToObjectSpace',function(a,v)local i=a:Inverse();return (i*v)-i.Position end)
 rawset(mt,'GetComponents',function(c)local r=c.R;return c.Position.X,c.Position.Y,c.Position.Z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3]end)
 rawset(mt,'ToEulerAnglesXYZ',function()return 0,0,0 end)
 local ctor=R.CFrame.new
 R.CFrame.new=function(x,y,z,...)
  if select('#',...)>=9 then local m={...};return setmetatable({Position=V3(x,y,z),R={{m[1],m[2],m[3]},{m[4],m[5],m[6]},{m[7],m[8],m[9]}},__type='CFrame'},mt)end
  if x==nil then return ctor(0,0,0)end
  return ctor(x,y,z)
 end
 R.CFrame.fromAxisAngle=function()return ctor(0,0,0)end
end
-- Extra Instance API used by art modules.
local Inst=R.Inst
function Inst:GetBoundingBox()
 local lo,hi
 for _,p in ipairs(self:GetDescendants())do if p:IsA('BasePart')then
  local c=p._props.CFrame.Position;local s=p._props.Size or V3(1,1,1);local h=s*.5
  local a,b=c-h,c+h
  lo=lo and V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
  hi=hi and V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
 end end
 if not lo then return CF(0,0,0),V3(0,0,0)end
 return CF((lo+hi)*.5),hi-lo
end
function Inst:GetExtentsSize()local _,s=self:GetBoundingBox();return s end
function Inst:ScaleTo()end
function Inst:GetScale()return 1 end
function Inst:SetPrimaryPartCFrame(c)self.CFrame=c end
function Inst:FindFirstChildWhichIsA(c,rec)for _,x in ipairs(self._children)do if x:IsA(c)then return x end end;if rec then for _,x in ipairs(self._children)do local f=x:FindFirstChildWhichIsA(c,true);if f then return f end end end;return nil end
function Inst:FindFirstAncestorWhichIsA(c)local p=self._parent;while p do if p:IsA(c)then return p end;p=p._parent end;return nil end
function Inst:IsAncestorOf(o)return o:IsDescendantOf(self)end
function Inst:Emit()end;function Inst:Clear()end;function Inst:ReleaseFocus()end;function Inst:CaptureFocus()end
-- IsA for extra classes.
local extra={ViewportFrame={'GuiObject','GuiBase2d'},UIStroke={},UIGradient={},WorldModel={'Model','PVInstance'},SpecialMesh={'DataModelMesh','FileMesh'},BlockMesh={'DataModelMesh'},
 ParticleEmitter={},PointLight={'Light'},SpotLight={'Light'},SurfaceLight={'Light'},Beam={},Trail={},WeldConstraint={'JointInstance'},Weld={'JointInstance'},Motor6D={'JointInstance'},
 TextBox={'GuiObject','GuiBase2d'},UICorner={},UIListLayout={},UITextSizeConstraint={},UISizeConstraint={},UIAspectRatioConstraint={},UIPadding={},UIScale={},Highlight={},BillboardGui={'LayerCollector','GuiBase2d'},
 Decal={'FaceInstance'},Texture={'Decal','FaceInstance'},SurfaceAppearance={},Attachment={},Sound={},ModuleScript={'LuaSourceContainer'},LocalScript={'BaseScript','Script','LuaSourceContainer'},Script={'BaseScript','LuaSourceContainer'},
 Folder={},Camera={'PVInstance'},CornerWedgePart={'BasePart','PVInstance'},TrussPart={'BasePart','PVInstance'},UnionOperation={'BasePart','PVInstance'},Seat={'BasePart','PVInstance'}}
local rawIsA=Inst.IsA
function Inst:IsA(c)if rawIsA(self,c)then return true end;for _,b in ipairs(extra[self._class]or{})do if b==c then return true end end;return false end
-- Module loading.
local RS=service('ReplicatedStorage');W.RS=RS
local env;local loaded={};local stubs={}
W.loadedCount=0
local function load(name,scriptInst)
 local fn,err=loadstring(B[name],'='..name);if not fn then error(err)end
 local e=setmetatable({script=scriptInst},{__index=env});setfenv(fn,e);W.loadedCount+=1;return fn()
end
W.load=load
local function req(m)
 if type(m)~='table'then error('require of non-instance '..tostring(m))end
 if loaded[m]~=nil then return loaded[m]end
 if stubs[m._props.Name]~=nil and m._stubbed then loaded[m]=stubs[m._props.Name];return loaded[m]end
 if m._source then local v=load(m._source,m);loaded[m]=v;return v end
 error('require of unknown module '..tostring(m))
end
W.require=req
for name in pairs(B)do local m=new('ModuleScript');m.Name=name;m._source=name;m.Parent=RS end
function W.stub(name,value)
 local m=RS:FindFirstChild(name);if not m then m=new('ModuleScript');m.Name=name;m.Parent=RS end
 stubs[name]=value;m._stubbed=true;loaded[m]=value;return m
end
function W.module(name)return req(RS:FindFirstChild(name))end
local function clock()return R.clock end
env=setmetatable({game=game,workspace=workspace,Instance=R.Instance,Vector3=R.Vector3,Vector2=R.Vector2,CFrame=R.CFrame,UDim=R.UDim,UDim2=R.UDim2,Color3=R.Color3,ColorSequence=R.ColorSequence,
 ColorSequenceKeypoint=R.ColorSequenceKeypoint,NumberSequence=R.NumberSequence,NumberSequenceKeypoint=R.NumberSequenceKeypoint,NumberRange=R.NumberRange,TweenInfo=R.TweenInfo,PhysicalProperties=R.PhysicalProperties,Rect=R.Rect,
 Enum=R.Enum,RaycastParams={new=function()return {}end},OverlapParams={new=function()return {}end},typeof=R.typeof,task=R.task,require=req,
 os={clock=clock,time=function()return math.floor(R.clock)end,date=os.date},utf8=utf8,warn=function(...)W.warns=(W.warns or 0)+1;print('WARN',...)end,
 debug={profilebegin=function()end,profileend=function()end,traceback=debug.traceback,info=debug.info},tick=clock,DateTime={now=function()return {UnixTimestampMillis=R.clock*1000}end},
 Random={new=function(seed)local s=seed or 1;return {NextNumber=function(_,a,b)s=(s*1103515245+12345)%2147483648;local u=s/2147483648;if a then return a+(b-a)*u end;return u end,NextInteger=function(_,a,b)s=(s*1103515245+12345)%2147483648;return a+s%(b-a+1)end}end}},{__index=_G})
W.env=env
local rawNew=R.Instance.new
do local base=R.new;R.new=function(...)local o=base(...);o._props.SelectionGained=R.signal();o._props.SelectionLost=R.signal();o._props.FocusLost=R.signal();o._props.Focused=R.signal();if select(1,...)=="ScrollingFrame" then o._props.CanvasPosition=R.Vector2.new(0,0) end;o._props.AnchorPoint=R.Vector2.new(0,0);return o end;W.new=R.new
 local inew=R.Instance.new;rawNew=function(class,parent)local o=R.new(class);if parent then o.Parent=parent end;return o end end
R.Instance.new=function(class,parent)local o=rawNew(class,parent);if class=='ScreenGui'then o.AbsoluteSize=R.Vector2.new(1280,720);o.AbsolutePosition=R.Vector2.new(0,0)end;return o end
env.Instance=R.Instance
function W.frames(n,dt)for _=1,n do R.advance(dt or 1/60);Run.RenderStepped:Fire(dt or 1/60);Run.Heartbeat:Fire(dt or 1/60);Run.PreSimulation:Fire(dt or 1/60)end end
W.Run=Run;W.UIS=UIS;W.Gui=Gui;W.CS=CS
return W
