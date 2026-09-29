--!nocheck
-- Minimal Roblox runtime mock for smoke-running client/server scripts under the Luau CLI.
local M={}
local function signal()
 local s={_c={}}
 function s:Connect(f)local c={Connected=true,_f=f};table.insert(self._c,c);function c:Disconnect()self.Connected=false end;return c end
 function s:Once(f)local c;c=self:Connect(function(...)c:Disconnect();f(...)end);return c end
 function s:Fire(...)for _,c in ipairs(table.clone(self._c))do if c.Connected then c._f(...)end end end
 function s:Wait()return end
 return s
end
M.signal=signal
-- Vector3 -----------------------------------------------------------------
local V3={};V3.__index=V3
local function v3(x,y,z)return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__type='Vector3'},V3)end
V3.__add=function(a,b)return v3(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
V3.__sub=function(a,b)return v3(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
V3.__mul=function(a,b)if type(a)=='number'then return v3(b.X*a,b.Y*a,b.Z*a)elseif type(b)=='number'then return v3(a.X*b,a.Y*b,a.Z*b)else return v3(a.X*b.X,a.Y*b.Y,a.Z*b.Z)end end
V3.__div=function(a,b)return v3(a.X/b,a.Y/b,a.Z/b)end
V3.__unm=function(a)return v3(-a.X,-a.Y,-a.Z)end
V3.__eq=function(a,b)return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
V3.__tostring=function(a)return string.format('%.2f, %.2f, %.2f',a.X,a.Y,a.Z)end
V3.__index=function(a,k)
 if k=='Magnitude'then return math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z)end
 if k=='Unit'then local m=math.sqrt(a.X*a.X+a.Y*a.Y+a.Z*a.Z);return m>0 and v3(a.X/m,a.Y/m,a.Z/m)or v3(0,0,0)end
 return rawget(V3,k)
end
function V3.Dot(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
function V3.Cross(a,b)return v3(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end
function V3.Lerp(a,b,t)return a+(b-a)*t end
M.Vector3={new=v3,zero=v3(0,0,0),one=v3(1,1,1),xAxis=v3(1,0,0),yAxis=v3(0,1,0),zAxis=v3(0,0,1)}
-- CFrame (rotation matrix rows r) ------------------------------------------
local CF={}
local function cf(p,r)return setmetatable({Position=p,R=r,__type='CFrame'},CF)end
local I={{1,0,0},{0,1,0},{0,0,1}}
local function mulR(a,b)local r={}for i=1,3 do r[i]={}for j=1,3 do r[i][j]=a[i][1]*b[1][j]+a[i][2]*b[2][j]+a[i][3]*b[3][j]end end;return r end
local function apply(r,v)return v3(r[1][1]*v.X+r[1][2]*v.Y+r[1][3]*v.Z,r[2][1]*v.X+r[2][2]*v.Y+r[2][3]*v.Z,r[3][1]*v.X+r[3][2]*v.Y+r[3][3]*v.Z)end
CF.__mul=function(a,b)
 if getmetatable(b)==CF then return cf(a.Position+apply(a.R,b.Position),mulR(a.R,b.R))end
 return a.Position+apply(a.R,b)
end
CF.__index=function(c,k)
 if k=='LookVector'then return v3(-c.R[1][3],-c.R[2][3],-c.R[3][3])end
 if k=='RightVector'then return v3(c.R[1][1],c.R[2][1],c.R[3][1])end
 if k=='UpVector'then return v3(c.R[1][2],c.R[2][2],c.R[3][2])end
 if k=='X'then return c.Position.X elseif k=='Y'then return c.Position.Y elseif k=='Z'then return c.Position.Z end
 return rawget(CF,k)
end
function CF.PointToWorldSpace(c,v)return c*v end
function CF.Inverse(c)local r={{c.R[1][1],c.R[2][1],c.R[3][1]},{c.R[1][2],c.R[2][2],c.R[3][2]},{c.R[1][3],c.R[2][3],c.R[3][3]}};return cf(-apply(r,c.Position),r)end
function CF.Lerp(a,b,t)return cf(a.Position:Lerp(b.Position,t),t<.5 and a.R or b.R)end
local function angles(x,y,z)
 local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
 local rx={{1,0,0},{0,cx,-sx},{0,sx,cx}};local ry={{cy,0,sy},{0,1,0},{-sy,0,cy}};local rz={{cz,-sz,0},{sz,cz,0},{0,0,1}}
 return cf(v3(),mulR(mulR(rx,ry),rz))
end
M.CFrame={new=function(x,y,z)if type(x)=='table'then return cf(x,I)end;return cf(v3(x,y,z),I)end,Angles=angles,fromEulerAnglesXYZ=angles,
 fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return cf(p,{{x.X,y.X,z.X},{x.Y,y.Y,z.Y},{x.Z,y.Z,z.Z}})end,
 lookAt=function(p,t)local f=(t-p).Unit;local r=f:Cross(v3(0,1,0)).Unit;local u=r:Cross(f);return cf(p,{{r.X,u.X,-f.X},{r.Y,u.Y,-f.Y},{r.Z,u.Z,-f.Z}})end,identity=cf(v3(),I)}
-- Small value types ------------------------------------------------------------
local function valueType(name,fields)return function(...)local a={...};local t={__type=name};for i,f in ipairs(fields)do t[f]=a[i]end;return t end end
local v2mt={};v2mt.__index=function(a,k)if k=='Magnitude'then return math.sqrt(a.X^2+a.Y^2)end end
v2mt.__sub=function(a,b)return M.Vector2.new(a.X-b.X,a.Y-b.Y)end;v2mt.__add=function(a,b)return M.Vector2.new(a.X+b.X,a.Y+b.Y)end
M.Vector2={new=function(x,y)return setmetatable({X=x or 0,Y=y or 0,__type='Vector2'},v2mt)end}
M.Vector2.zero=M.Vector2.new(0,0);M.Vector2.one=M.Vector2.new(1,1)
local function udim(s,o)return {Scale=s or 0,Offset=o or 0,__type='UDim'}end
M.UDim={new=udim}
M.UDim2={new=function(a,b,c,d)return {X=udim(a,b),Y=udim(c,d),__type='UDim2'}end,fromOffset=function(x,y)return {X=udim(0,x),Y=udim(0,y),__type='UDim2'}end,fromScale=function(x,y)return {X=udim(x,0),Y=udim(y,0),__type='UDim2'}end}
local c3mt={};c3mt.__index={Lerp=function(a,b,t)return M.Color3.new(a.R+(b.R-a.R)*t,a.G+(b.G-a.G)*t,a.B+(b.B-a.B)*t)end}
M.Color3={new=function(r,g,b)return setmetatable({R=r or 0,G=g or 0,B=b or 0,__type='Color3'},c3mt)end,fromRGB=function(r,g,b)return M.Color3.new(r/255,g/255,b/255)end,fromHSV=function()return M.Color3.new(1,1,1)end}
M.ColorSequence={new=valueType('ColorSequence',{'A','B'})};M.ColorSequenceKeypoint={new=valueType('ColorSequenceKeypoint',{'T','V'})}
M.NumberSequence={new=valueType('NumberSequence',{'A','B'})};M.NumberSequenceKeypoint={new=valueType('NumberSequenceKeypoint',{'T','V'})}
M.NumberRange={new=valueType('NumberRange',{'Min','Max'})};M.TweenInfo={new=valueType('TweenInfo',{'Time','Style','Dir'})}
M.PhysicalProperties={new=valueType('PhysicalProperties',{'D','F','E','FW','EW'})};M.Rect={new=valueType('Rect',{'Min','Max'})}
-- Enum: any path resolves to an item with Name; equality by identity.
local enumCache={}
M.Enum=setmetatable({},{__index=function(_,group)
 enumCache[group]=enumCache[group]or setmetatable({},{__index=function(t,name)local item={Name=name,EnumType=group,__type='EnumItem',Value=#name};rawset(t,name,item);return item end})
 return enumCache[group]
end})
-- Instances ------------------------------------------------------------------------
local Inst={};local instMeta={}
local classes={} -- class -> base list for IsA
local isa={Part={'BasePart','PVInstance'},MeshPart={'BasePart','PVInstance'},WedgePart={'BasePart','PVInstance'},TextLabel={'GuiObject','GuiBase2d'},TextButton={'GuiObject','GuiButton','GuiBase2d'},ImageLabel={'GuiObject','GuiBase2d'},ImageButton={'GuiObject','GuiButton','GuiBase2d'},Frame={'GuiObject','GuiBase2d'},CanvasGroup={'GuiObject','GuiBase2d'},ScrollingFrame={'GuiObject','GuiBase2d'},ScreenGui={'LayerCollector','GuiBase2d'},BillboardGui={'LayerCollector','GuiBase2d'},SurfaceGui={'LayerCollector','GuiBase2d'},Model={'PVInstance'},Tool={'BackpackItem'},LocalScript={'BaseScript','Script'},Script={'BaseScript'}}
M.created={}
local function new(class,props)
 local o={_class=class,_props={},_children={},_attrs={},_attrSignals={},_propSignals={},_parent=nil}
 o._props.Name=class;o.Destroying=signal();o.ChildAdded=signal();o.ChildRemoved=signal();o.DescendantAdded=signal();o.DescendantRemoving=signal();o.AncestryChanged=signal();o.Changed=signal();o.AttributeChanged=signal()
 if class:find('Button')then o.Activated=signal();o.MouseButton1Click=signal()end
 o.InputBegan=signal();o.InputEnded=signal();o.InputChanged=signal();o.MouseEnter=signal();o.MouseLeave=signal();o.Touched=signal();o.TouchEnded=signal()
 local defaults={Visible=true,Enabled=true,Transparency=0,BackgroundTransparency=0,TextTransparency=0,AbsoluteSize=M.Vector2.new(100,40),AbsolutePosition=M.Vector2.new(0,0),Size=class:find('Part')and v3(4,1,2)or M.UDim2.new(),Position=class:find('Part')and v3()or M.UDim2.new(),CFrame=M.CFrame.new(0,0,0),Text='',TextSize=14,Rotation=0,Scale=1,MaxVisibleGraphemes=-1,Anchored=false,CanCollide=true}
 for k,v in pairs(defaults)do o._props[k]=v end
 if props then for k,v in pairs(props)do o._props[k]=v end end
 M.created[#M.created+1]=o
 return setmetatable(o,instMeta)
end
local function fireProp(o,k)local s=o._propSignals[k];if s then s:Fire()end end
instMeta.__index=function(o,k)
 local m=Inst[k];if m then return m end
 local p=o._props[k];if p~=nil then return p end
 if k=='Parent'then return o._parent end
 if k=='ClassName'then return o._class end
 for _,c in ipairs(o._children)do if c._props.Name==k then return c end end
 if o._class=='Part'or o._class=='MeshPart'then if k=='Position'then return o._props.CFrame.Position end end
 return nil
end
instMeta.__newindex=function(o,k,v)
 if k=='Parent'then
  if o._parent then local list=o._parent._children;for i,c in ipairs(list)do if c==o then table.remove(list,i);break end end;o._parent.ChildRemoved:Fire(o)end
  o._parent=v;if v then table.insert(v._children,o);v.ChildAdded:Fire(o);local a=v;while a do a.DescendantAdded:Fire(o);a=a._parent end end
  fireProp(o,'Parent');o.AncestryChanged:Fire(o,v);return
 end
 if (o._class=='Part'or o._class=='MeshPart')and k=='Position'then o._props.CFrame=M.CFrame.new(v)*setmetatable({Position=v3(),R=o._props.CFrame.R},CF);o._props.Position=v;fireProp(o,k);return end
 if k=='CFrame'then o._props.Position=v.Position end
 o._props[k]=v;fireProp(o,k);o.Changed:Fire(k)
end
instMeta.__tostring=function(o)return o._props.Name end
function Inst:IsA(c)if self._class==c or c=='Instance'then return true end;for _,b in ipairs(isa[self._class]or{})do if b==c then return true end end;return false end
function Inst:FindFirstChild(n,rec)for _,c in ipairs(self._children)do if c._props.Name==n then return c end end;if rec then for _,c in ipairs(self._children)do local f=c:FindFirstChild(n,true);if f then return f end end end;return nil end
function Inst:WaitForChild(n)local c=self:FindFirstChild(n);if not c then error('WaitForChild would hang: '..tostring(self)..'.'..n)end;return c end
function Inst:FindFirstChildOfClass(c)for _,x in ipairs(self._children)do if x._class==c then return x end end;return nil end
function Inst:FindFirstChildWhichIsA(c)for _,x in ipairs(self._children)do if x:IsA(c)then return x end end;return nil end
function Inst:FindFirstAncestorOfClass(c)local p=self._parent;while p do if p._class==c then return p end;p=p._parent end;return nil end
function Inst:FindFirstAncestor(n)local p=self._parent;while p do if p._props.Name==n then return p end;p=p._parent end;return nil end
function Inst:IsDescendantOf(a)local p=self._parent;while p do if p==a then return true end;p=p._parent end;return false end
function Inst:GetChildren()return table.clone(self._children)end
function Inst:GetDescendants()local out={};local function w(o)for _,c in ipairs(o._children)do out[#out+1]=c;w(c)end end;w(self);return out end
function Inst:ClearAllChildren()for _,c in ipairs(table.clone(self._children))do c:Destroy()end end
function Inst:Destroy()if self._destroyed then return end;self._destroyed=true;self.Destroying:Fire();for _,c in ipairs(table.clone(self._children))do c:Destroy()end;self.Parent=nil end
function Inst:Clone()local c=new(self._class,table.clone(self._props));for _,ch in ipairs(self._children)do ch:Clone().Parent=c end;return c end
function Inst:GetAttribute(k)return self._attrs[k]end
function Inst:GetAttributes()return table.clone(self._attrs)end
function Inst:SetAttribute(k,v)if self._attrs[k]==v then return end;self._attrs[k]=v;local s=self._attrSignals[k];if s then s:Fire()end;self.AttributeChanged:Fire(k)end
function Inst:GetAttributeChangedSignal(k)self._attrSignals[k]=self._attrSignals[k]or signal();return self._attrSignals[k]end
function Inst:GetPropertyChangedSignal(k)self._propSignals[k]=self._propSignals[k]or signal();return self._propSignals[k]end
function Inst:GetFullName()local t={};local p=self;while p do table.insert(t,1,p._props.Name);p=p._parent end;return table.concat(t,'.')end
function Inst:PivotTo(c)self.CFrame=c end
function Inst:GetPivot()return self._props.CFrame end
function Inst:ApplyImpulse()end
function Inst:SetNetworkOwner()end
function Inst:GetNetworkOwner()return nil end
M.new=new
M.Instance={new=function(class,parent)local o=new(class);if parent then o.Parent=parent end;return o end}
M.typeof=function(v)if type(v)=='table'then if getmetatable(v)==instMeta then return'Instance'end;if v.__type then return v.__type end end;return type(v)end
M.instMeta=instMeta;M.Inst=Inst
-- Scheduler -----------------------------------------------------------------------------
M.clock=0;local queue={}
M.task={
 spawn=function(f,...)local co=type(f)=='thread'and f or coroutine.create(f);local ok,e=coroutine.resume(co,...);if not ok then error(e,0)end;return co end,
 defer=function(f,...)local a={...};table.insert(queue,{At=M.clock,F=f,A=a});return nil end,
 delay=function(t,f,...)local a={...};table.insert(queue,{At=M.clock+(t or 0),F=f,A=a});return nil end,
 wait=function(t)return t or 0 end,cancel=function()end,
}
function M.advance(dt)
 M.clock+=dt
 local due={};local keep={}
 for _,q in ipairs(queue)do if q.At<=M.clock then due[#due+1]=q else keep[#keep+1]=q end end
 queue=keep;for _,q in ipairs(due)do q.F(table.unpack(q.A))end
end
return M
