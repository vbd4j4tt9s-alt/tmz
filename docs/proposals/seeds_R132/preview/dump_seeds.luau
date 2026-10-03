--!nocheck
-- Seed design preview (not a test): builds every obtainable seed with the REAL seed builder (WHICH='old': current
-- SeedPackVisuals; WHICH='new': SeedPackVisuals132 + SeedSignatures132) in a grid and prints a JSON scene for
-- render_seeds.mjs, plus one label per cell. Seeds are turned a little to the right like the Bag pictures.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local which=WHICH or'new'
-- The shared mock's lookAt ignores the up vector and breaks on vertical lines; use a full one (as Roblox does).
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
W.env.CFrame=R.CFrame
local Rules=W.module('SeedPackRules')
local Visuals=W.module(which=='new'and'SeedPackVisuals132'or'SeedPackVisuals')
local holder=R.new('Model');holder.Name='Seeds';holder.Parent=W.workspace
local cols=9;local gap=3.4
local labels={}
local order={}
for _,s in ipairs(Rules.SeedDesigns)do if s.stage~=8 then table.insert(order,s)end end -- Mech seeds are their own models
table.sort(order,function(a,b)if a.stage~=b.stage then return a.stage<b.stage end;return(a.index or 0)<(b.index or 0)end)
for i,s in ipairs(order)do
 local c=(i-1)%cols;local r=math.floor((i-1)/cols)
 local at=CF(-c*gap,-r*gap*1.25,0)*R.CFrame.Angles(0,math.rad(-22),0) -- the camera looks +Z, so columns run to -X
 local ok,err=pcall(Visuals.Seed,{Id=s.id},1,at,holder,1,nil,'None')
 if not ok then print('ERR',s.id,err)end
 table.insert(labels,string.format('{"text":"%s","rarity":"%s","p":[%.3f,%.3f,0]}',s.name,s.rarity,-c*gap,-r*gap*1.25-1.55))
end
local function n(v)return string.format('%.4f',v)end
local function c3(c)if not c then return'[163,162,165]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local parts={}
for _,c in ipairs(holder:GetDescendants())do
 if c:IsA('BasePart')and(c.Transparency or 0)<1 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
  local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
  local mesh=c:FindFirstChildOfClass('SpecialMesh')
  if mesh and enumName(mesh.MeshType)=='Sphere'then shape='Ball';local m=mesh.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
  table.insert(parts,string.format('{"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s,"guis":[]}',
   c.Name,shape,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0)))
 end
end
print(string.format('{"cols":%d,"rows":%d,"gap":%s,"parts":[%s],"labels":[%s]}',cols,math.ceil(#order/cols),n(gap),table.concat(parts,','),table.concat(labels,',')))
