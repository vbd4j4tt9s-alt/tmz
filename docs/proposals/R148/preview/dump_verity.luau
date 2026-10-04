--!nocheck
-- Verity preview (not a test): runs the REAL builders on the mock (the real MarketLayout market and the real VerityService
-- with VerityConfig) and prints one JSON scene for render_verity.mjs. Same scene format as market_R132/preview/dump_market.luau,
-- plus Decals on parts ("decals") and the name sign ("signs").
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
-- Mock gaps: Model scale (Roblox scales every part about the pivot), a full lookAt and Vector3.FromNormalId.
do local Inst=R.Inst
 local partPivot,partGet=Inst.PivotTo,Inst.GetPivot
 function Inst:GetPivot()
  if self._class=='Model'then local pp=self._props.PrimaryPart;if pp then return pp.CFrame end;if self._pivot then return self._pivot end;return(self:GetBoundingBox())end
  return partGet(self)
 end
 function Inst:PivotTo(cf)
  if self._class~='Model'then return partPivot(self,cf)end
  local delta=cf*self:GetPivot():Inverse()
  for _,d in ipairs(self:GetDescendants())do if d:IsA('BasePart')then d.CFrame=delta*d.CFrame end end
  if not self._props.PrimaryPart then self._pivot=cf end
 end
 function Inst:GetScale()return self._scale or 1 end
 function Inst:ScaleTo(k)
  local f=k/(self._scale or 1);self._scale=k;local pivot=self:GetPivot()
  for _,d in ipairs(self:GetDescendants())do if d:IsA('BasePart')then
   local rel=pivot:Inverse()*d.CFrame;d.Size=d.Size*f
   d.CFrame=pivot*R.CFrame.new(rel.Position.X*f,rel.Position.Y*f,rel.Position.Z*f)*rel.Rotation
  end end
 end
 R.CFrame.lookAt=function(p,t,up)
  local f=(t-p).Unit;local u0=up or V3(0,1,0)
  if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
  local r=f:Cross(u0).Unit;local u=r:Cross(f)
  return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
 end
 W.env.CFrame=R.CFrame
 R.Vector3.FromNormalId=R.Vector3.FromNormalId or function(n)
  local name=type(n)=='table'and n.Name or tostring(n):match('(%a+)$')
  return({Front=V3(0,0,-1),Back=V3(0,0,1),Left=V3(-1,0,0),Right=V3(1,0,0),Top=V3(0,1,0),Bottom=V3(0,-1,0)})[name]
 end
 W.env.Vector3=R.Vector3
 local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='ProximityPrompt'then o.Triggered=R.signal()end;if class=='RemoteEvent'then o.OnServerEvent=R.signal()end;return o end
end
local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=W.workspace
local hub=R.new('Folder');hub.Name='EconomyHub';hub.Parent=map
for _,n in ipairs({'BuyStation','SellStation'})do local s=R.new('Part');s.Name=n;s.Parent=hub end
local realWarn=W.env.warn;W.env.warn=function()end
local Market=W.module('MarketLayout');Market.Apply(map);R.advance(.1)
W.env.warn=realWarn
local Verity=W.module('VerityService').new({},{},{},{},{EconomyHub=hub,MapRoot=map}):Start()
local C=W.module('VerityConfig')
-- Dump --------------------------------------------------------------------------------------------------------
local function n(v)return string.format('%.4f',v)end
local function c3(c)if not c then return"[163,162,165]"end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function q(s)return'"'..tostring(s):gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n')..'"'end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local parts,lights,signs={},{},{}
local id=0
local function walk(o)
 for _,c in ipairs(o:GetChildren())do
  if c:IsA('BasePart')then
   id+=1;local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
   local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
   local mesh=c:FindFirstChildOfClass('SpecialMesh')
   if mesh and enumName(mesh.MeshType)=='Sphere'then local k=mesh.Scale or V3(1,1,1);shape='Ball';s=V3(s.X*k.X,s.Y*k.Y,s.Z*k.Z)end
   local guis,decals={},{}
   for _,g in ipairs(c:GetChildren())do
    if g.ClassName=='SurfaceGui'then
     local lines={}
     for _,t in ipairs(g:GetChildren())do if t.ClassName=='TextLabel'then
      local pos,size=t.Position,t.Size
      table.insert(lines,string.format('{"text":%s,"color":%s,"x":%s,"y":%s,"w":%s,"h":%s,"stroke":%s}',q(t.Text),c3(t.TextColor3),n(pos.X.Scale),n(pos.Y.Scale),n(size.X.Scale),n(size.Y.Scale),(t.TextStrokeTransparency or 1)<1 and'true'or'false'))
     end end
     local cs=g.CanvasSize or R.Vector2.new(800,200)
     table.insert(guis,string.format('{"face":%s,"canvas":[%s,%s],"lines":[%s]}',q(enumName(g.Face)),n(cs.X),n(cs.Y),table.concat(lines,',')))
    elseif g.ClassName=='Decal'then
     table.insert(decals,string.format('{"face":%s,"texture":%s}',q(enumName(g.Face)),q(g.Texture)))
    elseif g.ClassName=='BillboardGui'then
     local o2=g.StudsOffsetWorldSpace or V3(0,0,0);local lines={}
     for _,t in ipairs(g:GetChildren())do if t.ClassName=='TextLabel'then table.insert(lines,string.format('{"text":%s,"color":%s}',q(t.Text),c3(t.TextColor3)))end end
     table.insert(signs,string.format('{"p":[%s,%s,%s],"lines":[%s],"mark":"!"}',n(p.X+o2.X),n(p.Y+o2.Y),n(p.Z+o2.Z),table.concat(lines,',')))
    end
   end
   for _,l in ipairs(c:GetChildren())do if l.ClassName=='PointLight'then table.insert(lights,string.format('{"p":[%s,%s,%s],"color":%s,"range":%s}',n(p.X),n(p.Y),n(p.Z),c3(l.Color),n(l.Range or 10)))end end
   local group=0;local a=c;while a and a.Parent do if a.Parent.Name=='MarketShowcase'then group=table.find(a.Parent:GetChildren(),a)or 0;break end;if a.Parent.Name=='VerityNPC'then group=-2;break end;a=a.Parent end
   table.insert(parts,string.format('{"group":%d,"name":%s,"shape":%s,"size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":%s,"t":%s,"guis":[%s],"decals":[%s]}',
    group,q(c.Name),q(shape),n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
    c3(c.Color),q(enumName(c.Material)),n(c.Transparency or 0),table.concat(guis,','),table.concat(decals,',')))
  end
  walk(c)
 end
end
walk(W.workspace)
-- The scene is centred between the market and Verity; views are given as absolute Roblox coordinates by render_verity.mjs.
local center=V3(0,4,-300)
print(string.format('{"center":[%s,%s,%s],"verity":[%s,%s,%s],"parts":[%s],"lights":[%s],"signs":[%s]}',n(center.X),n(center.Y),n(center.Z),n(C.Position.X),n(C.Position.Y),n(C.Position.Z),table.concat(parts,','),table.concat(lights,','),table.concat(signs,',')))
