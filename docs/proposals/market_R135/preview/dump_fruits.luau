--!nocheck
-- Fruit lineup (not a test): every obtainable fruit, built with the REAL HarvestPresentation on the mock and stood
-- on its visible bottom like the market does, in a grid of cards. Prints one JSON scene (render with seeds.html) and
-- the fruits that could not be built in the mock (fruit made of approved meshes only exists in the place).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
require('./mockfix')(W)
local Hour=W.module('FruitOfHour');local HP=W.module('HarvestPresentation');local G=W.module('HarvestGeometry')
local Rules=W.module('SeedPackRules')
local holder=R.new('Model');holder.Name='Fruits';holder.Parent=W.workspace
local cols=COLS or 9;local gap=3.4;local labels={};local list=ONLY or Hour.Candidates()
local placed={}
for i,id in ipairs(list)do
 local c=(i-1)%cols;local r=math.floor((i-1)/cols)
 local ok,m=pcall(HP.Build,{SeedId=id,Mutation='None',Weather='None'})
 local spec=Rules.SeedDesignById[id]
 if ok and m then
  m.Parent=holder
  local center,b=G.Bounds(m);local k=1.9/math.max(b.X,b.Y,b.Z);local pivot=m:GetPivot().Position
  m:ScaleTo(k);center=pivot+(center-pivot)*k;b=b*k
  local p2=m:GetPivot();local spot=V3(-c*gap,-r*gap*1.25-.9,0)
  m:PivotTo(CF(spot+V3(0,b.Y/2,0))*R.CFrame.Angles(0,math.rad(-22),0)*CF(p2.Position-center)*p2.Rotation)
  m:SetAttribute('Index',i);placed[#placed+1]=m
 else print('SKIP',id,tostring(m))end
 table.insert(labels,string.format('{"text":"%s","rarity":"%s","p":[%.3f,%.3f,0]}',spec and spec.name or id,spec and spec.rarity or'Common',-c*gap,-r*gap*1.25-1.55))
end
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local parts={}
for _,m in ipairs(placed)do
 for _,c in ipairs(m:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<.95 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
  local shape=c.ClassName=='WedgePart'and'Wedge'or(c.Shape and enumName(c.Shape))or'Block'
  local mesh=c:FindFirstChildOfClass('SpecialMesh')
  if mesh and enumName(mesh.MeshType)=='Sphere'then shape='Ball';local k=mesh.Scale;s=V3(s.X*k.X,s.Y*k.Y,s.Z*k.Z)end
  table.insert(parts,string.format('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s}',
   m:GetAttribute('Index'),c.Name,shape,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
   c3(c.Color),enumName(c.Material),n(c.Transparency or 0)))
 end end
end
print(string.format('{"cols":%d,"rows":%d,"gap":%s,"parts":[%s],"labels":[%s]}',cols,math.ceil(#list/cols),n(gap),table.concat(parts,','),table.concat(labels,',')))
