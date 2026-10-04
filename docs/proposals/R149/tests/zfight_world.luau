--!nocheck
-- R149 z-fighting: the owner's place (Workspace.ChestChaseMap from place_tree.luau, written by tools/rbxl_geom.py --tree) loaded into
-- the Roblox mock, plus the dump of every BasePart in the zfight.py scene format. Shared by zfight_scene.luau (the whole map after the
-- real startup builders) and test_zfight.luau.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Z={W=W,R=R}
-- Mock gaps used by the map builders: CFrame +/- Vector3, a full lookAt / fromAxisAngle / fromOrientation, Model pivots and ScaleTo,
-- Position on every part class, Vector3.FromNormalId, more BasePart classes.
do
 local mt=getmetatable(CF(0,0,0))
 local function mk(p,r)return setmetatable({Position=p,R=r,__type='CFrame'},mt)end
 mt.__add=function(a,b)return mk(a.Position+b,a.R)end
 mt.__sub=function(a,b)return mk(a.Position-b,a.R)end
 local function rows(r)return{{r[1][1],r[1][2],r[1][3]},{r[2][1],r[2][2],r[2][3]},{r[3][1],r[3][2],r[3][3]}}end
 R.CFrame.lookAt=function(p,t,up)
  local f=(t-p).Unit;local u0=up or V3(0,1,0)
  if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
  local r=f:Cross(u0).Unit;local u=r:Cross(f)
  return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
 end
 R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
 R.CFrame.fromAxisAngle=function(axis,a)
  local u=axis.Unit;local c,s=math.cos(a),math.sin(a);local t=1-c;local x,y,z=u.X,u.Y,u.Z
  return R.CFrame.new(0,0,0,t*x*x+c,t*x*y-s*z,t*x*z+s*y,t*x*y+s*z,t*y*y+c,t*y*z-s*x,t*x*z-s*y,t*y*z+s*x,t*z*z+c)
 end
 local function yxz(x,y,z)return R.CFrame.Angles(0,y,0)*R.CFrame.Angles(x,0,0)*R.CFrame.Angles(0,0,z)end
 R.CFrame.fromOrientation=yxz;R.CFrame.fromEulerAnglesYXZ=yxz;R.CFrame.Angles=R.CFrame.Angles
 W.env.CFrame=R.CFrame
 R.Vector3.FromNormalId=function(n)
  local name=type(n)=='table'and n.Name or tostring(n):match('(%a+)$')
  return({Front=V3(0,0,-1),Back=V3(0,0,1),Left=V3(-1,0,0),Right=V3(1,0,0),Top=V3(0,1,0),Bottom=V3(0,-1,0)})[name]
 end
 R.Vector3.fromNormalId=R.Vector3.FromNormalId
 W.env.Vector3=R.Vector3
 local Inst=R.Inst
 local partGet,partPivot=Inst.GetPivot,Inst.PivotTo
 local function box(self)
  local lo,hi
  for _,p in ipairs(self:GetDescendants())do if p:IsA('BasePart')then
   local c=p._props.CFrame;local s=p._props.Size or V3(1,1,1)
   local r=c.R;local e=V3((math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2,(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2,(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2)
   local a,b=c.Position-e,c.Position+e
   lo=lo and V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z))or a
   hi=hi and V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))or b
  end end
  if not lo then return CF(0,0,0),V3(0,0,0)end
  return CF((lo.X+hi.X)/2,(lo.Y+hi.Y)/2,(lo.Z+hi.Z)/2),hi-lo
 end
 Inst.GetBoundingBox=box
 function Inst:GetExtentsSize()local _,s=box(self);return s end
 function Inst:GetPivot()
  if self:IsA('BasePart')then return self._props.CFrame end
  local pp=self._props.PrimaryPart;if pp then return pp._props.CFrame end
  if self._pivot then return self._pivot end
  return(box(self))
 end
 function Inst:PivotTo(cf)
  if self:IsA('BasePart')then self.CFrame=cf;return end
  local delta=cf*self:GetPivot():Inverse()
  for _,d in ipairs(self:GetDescendants())do if d:IsA('BasePart')then d.CFrame=delta*d._props.CFrame end end
  if not self._props.PrimaryPart then self._pivot=cf end
 end
 function Inst:SetPrimaryPartCFrame(c)self:PivotTo(c)end
 function Inst:TranslateBy(v)self:PivotTo(self:GetPivot()+v)end
 function Inst:GetScale()return self._scale or 1 end
 function Inst:ScaleTo(k)
  local f=k/(self._scale or 1);self._scale=k;local pivot=self:GetPivot()
  for _,d in ipairs(self:GetDescendants())do if d:IsA('BasePart')then
   local rel=pivot:Inverse()*d._props.CFrame;d.Size=d._props.Size*f
   d.CFrame=pivot*CF(rel.Position.X*f,rel.Position.Y*f,rel.Position.Z*f)*rel.Rotation
  end end
 end
 local meta=R.instMeta;local idx,nidx=meta.__index,meta.__newindex
 meta.__index=function(o,k)
  if k=='Position'and o._props.CFrame and o._class:find('Part')or(k=='Position'and o._class=='SpawnLocation')then return o._props.CFrame.Position end
  if k=='Orientation'and o._props.CFrame then return V3(0,0,0)end
  return idx(o,k)
 end
 meta.__newindex=function(o,k,v)
  if k=='Position'and(o._class:find('Part')or o._class=='SpawnLocation')then
   local c=o._props.CFrame or CF(0,0,0);o._props.CFrame=mk(v,c.R);o._props.Position=v;o.Changed:Fire(k);return
  end
  return nidx(o,k,v)
 end
end
-- Place loading -------------------------------------------------------------------------------------------------------------------------
local function cframe(t)return R.CFrame.new(t[1],t[2],t[3],t[4],t[5],t[6],t[7],t[8],t[9],t[10],t[11],t[12])end
local function attr(v)
 if type(v)~='table'then return v end
 if v.V3 then return V3(v.V3[1],v.V3[2],v.V3[3])end
 if v.C3 then return R.Color3.new(v.C3[1],v.C3[2],v.C3[3])end
 if v.V2 then return R.Vector2.new(v.V2[1],v.V2[2])end
 if v.CF then return cframe(v.CF)end
 if v.NR then return R.NumberRange.new(v.NR[1],v.NR[2])end
 return nil
end
Z.cframe=cframe
local PART={Part=true,WedgePart=true,CornerWedgePart=true,MeshPart=true,TrussPart=true,SpawnLocation=true,UnionOperation=true,Seat=true}
function Z.loadPlace(nodes,parent)
 local made={}
 local E=R.Enum
 for i,n in ipairs(nodes)do
  local o=R.new(n.c);local p=o._props
  p.Name=n.n
  if n.cf then local c=cframe(n.cf);p.CFrame=c;p.Position=c.Position end
  if n.s then p.Size=V3(n.s[1],n.s[2],n.s[3])end
  if n.col then p.Color=R.Color3.fromRGB(n.col[1],n.col[2],n.col[3])end
  if n.c3 then p.Color3=R.Color3.new(n.c3[1],n.c3[2],n.c3[3])end
  if n.m then p.Material=E.Material[n.m]end
  if n.t then p.Transparency=n.t end
  if n.sh then p.Shape=E.PartType[n.sh]elseif n.c=='Part'then p.Shape=E.PartType.Block end
  if n.face then p.Face=E.NormalId[n.face]end
  if n.mt then p.MeshType=E.MeshType[n.mt]end
  if n.sc then p.Scale=V3(n.sc[1],n.sc[2],n.sc[3])end
  if n.off then p.Offset=V3(n.off[1],n.off[2],n.off[3])end
  for _,k in ipairs({'MeshId','TextureID','Texture','Text','Enabled','Anchored','CanCollide','AlwaysOnTop','CastShadow'})do if n[k]~=nil then p[k]=n[k]end end
  if PART[n.c]and n.c~='Part'and not n.sh then p.Shape=nil end
  if n.c=='ProximityPrompt'then o.Triggered=R.signal();o.PromptShown=R.signal();o.PromptHidden=R.signal();o.TriggerEnded=R.signal()end
  if n.a then for k,v in pairs(n.a)do o._attrs[k]=attr(v)end end
  made[i]=o;o._place={cf=n.cf,s=n.s} -- the saved (place file) CFrame / Size, for ZFightFix149's data
  if n.pivot then o._pivot=cframe(n.pivot)end
 end
 for i,n in ipairs(nodes)do
  local o=made[i];local par=n.p==0 and parent or made[n.p]
  o._parent=par;table.insert(par._children,o)
  if n.pp then o._props.PrimaryPart=made[n.pp]end
 end
 return made[1]
end
-- Dump ------------------------------------------------------------------------------------------------------------------------------------
local function n4(v)return string.format('%.5f',v)end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function enumName(e)if e==nil then return nil end;if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local function rgb(c)if not c then return'[163,162,165]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
function Z.path(o,stop)
 local t={};local x=o
 while x and x~=stop and x~=W.game do table.insert(t,1,x._props.Name);x=x._parent end
 return table.concat(t,'/')
end
-- Every visible BasePart under root (Transparency < 1, or see-through but carrying a SurfaceGui / Decal / Texture, which still draws)
-- with its face decorations; `area` is a label from areaOf(part) (or nil).
function Z.dump(root,areaOf,extra)
 local out={}
 local function walk(o)
  for _,c in ipairs(o._children)do
   local decorated=false
   for _,d in ipairs(c._children)do if(d._class=='SurfaceGui'and d._props.Enabled~=false)or d._class=='Decal'or d._class=='Texture'then decorated=true end end
   if c:IsA('BasePart')and((c._props.Transparency or 0)<1 or decorated)and c._props.CFrame and c._props.Size then
    local cf=c._props.CFrame;local r=cf.R;local p=cf.Position;local s=c._props.Size
    local cls=c._class;local shape='Block'
    if cls=='WedgePart'then shape='Wedge'elseif cls=='CornerWedgePart'then shape='CornerWedge'elseif cls=='MeshPart'or cls=='UnionOperation'then shape='Mesh'
    elseif c._props.Shape then shape=enumName(c._props.Shape)end
    local faces,mesh={},nil
    for _,d in ipairs(c._children)do
     if d._class=='Decal'or d._class=='Texture'then
      faces[#faces+1]=string.format('{"kind":%s,"face":%s,"sig":%s,"t":%s}',q(d._class),q(enumName(d._props.Face)or'Front'),q(d._props.Texture or''),n4(d._props.Transparency or 0))
     elseif d._class=='SurfaceGui'and d._props.Enabled~=false then
      faces[#faces+1]=string.format('{"kind":"SurfaceGui","face":%s,"sig":%s,"t":0,"alwaysOnTop":%s}',q(enumName(d._props.Face)or'Front'),q('gui:'..d._props.Name),d._props.AlwaysOnTop and'true'or'false')
     elseif d._class=='SpecialMesh'then
      local sc=d._props.Scale;if type(sc)~='table'then sc=V3(1,1,1)end;local off=d._props.Offset or V3(0,0,0)
      mesh=string.format('{"type":%s,"scale":[%s,%s,%s],"offset":[%s,%s,%s]}',q(enumName(d._props.MeshType)or'Brick'),n4(sc.X),n4(sc.Y),n4(sc.Z),n4(off.X),n4(off.Y),n4(off.Z))
     end
    end
    local area=areaOf and areaOf(c)or nil
    local saved=''
    if c._place and c._place.cf then
     local t={};for k,v in ipairs(c._place.cf)do t[k]=string.format('%.6g',v)end
     saved=string.format(',"saved":{"cf":[%s],"s":[%s,%s,%s]}',table.concat(t,','),string.format('%.6g',c._place.s[1]),string.format('%.6g',c._place.s[2]),string.format('%.6g',c._place.s[3]))
    end
    out[#out+1]=string.format('{"path":%s,"name":%s,"class":%s,"shape":%s,"size":[%s,%s,%s],"p":[%s,%s,%s],"r":[[%s,%s,%s],[%s,%s,%s],[%s,%s,%s]],"color":%s,"material":%s,"t":%s%s%s%s%s}',
     q(Z.path(c)),q(c._props.Name),q(cls),q(shape),n4(s.X),n4(s.Y),n4(s.Z),n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),
     rgb(c._props.Color),q(enumName(c._props.Material)or'Plastic'),n4(c._props.Transparency or 0),#faces>0 and(',"faces":['..table.concat(faces,',')..']')or'',mesh and(',"mesh":'..mesh)or'',area and(',"area":'..q(area))or'',saved)
   end
   walk(c)
  end
 end
 walk(root)
 return out
end
return Z
