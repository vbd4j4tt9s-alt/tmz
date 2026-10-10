--!nocheck
-- Seed design preview (not a test): builds seeds with the REAL seed builder and prints one JSON scene for
-- render_seeds.mjs / check_floating.py. Globals set by run.sh before this file:
--  WHICH   'old' = SeedPackVisuals (in the game now), 'v2' = SeedPackVisuals132 (the R132 proposal the owner saw),
--          'new' = SeedPackVisuals133 (this proposal).
--  ONLY    optional list of seed ids (in order) instead of every seed; COLS columns.
--  EFFECTS true: also build the client rarity effects (SeedMotion) at time AGE, as they look on a held seed.
--  GAP     cell size in studs (default 3.4).
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
do -- CFrame.fromMatrix (used by the effect rings) is missing from the mock.
 R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
end
local Rules=W.module('SeedPackRules')
local Visuals=W.module(which=='new'and'SeedPackVisuals133'or which=='v2'and'SeedPackVisuals132'or'SeedPackVisuals')
local holder=R.new('Model');holder.Name='Seeds';holder.Parent=W.workspace
local fx=R.new('Folder');fx.Name='Effects';fx.Parent=W.workspace
local cols=COLS or 9;local gap=GAP or 3.4
local labels={}
local order={}
if ONLY then for _,id in ipairs(ONLY)do table.insert(order,Rules.SeedDesignById[id])end
else
 for _,s in ipairs(Rules.SeedDesigns)do if s.stage~=8 then table.insert(order,s)end end -- Mech seeds are their own models
 table.sort(order,function(a,b)if a.stage~=b.stage then return a.stage<b.stage end;return(a.index or 0)<(b.index or 0)end)
end
local models={}
for i,s in ipairs(order)do
 local c=(i-1)%cols;local r=math.floor((i-1)/cols)
 local at=CF(-c*gap,-r*gap*1.25,0)*R.CFrame.Angles(0,math.rad(-22),0) -- the camera looks +Z, so columns run to -X
 local ok,m=pcall(Visuals.Seed,{Id=s.id},1,at,holder,1,nil,'None')
 if not ok then print('ERR',s.id,m)else models[i]=m end
 if ok and EFFECTS and Visuals.CreateSeedMotion then
  local motion=Visuals.CreateSeedMotion(m,fx,true)
  if motion then motion:Update(at,AGE or 2.2,1,1);motion.Folder.Name='Fx'..i end
 end
 table.insert(labels,string.format('{"text":"%s","rarity":"%s","p":[%.3f,%.3f,0]}',s.name,s.rarity,-c*gap,-r*gap*1.25-1.55))
end
local function n(v)return string.format('%.4f',v)end
local function c3(c)if not c then return'[163,162,165]'end;return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local parts,glows,beams={},{},{}
local function dumpPart(c,index)
 local cf=c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
 local shape=c.ClassName=='WedgePart'and'Wedge'or c.ClassName=='CornerWedgePart'and'Corner'or(c.Shape and enumName(c.Shape))or'Block'
 local mesh=c:FindFirstChildOfClass('SpecialMesh')
 if mesh and enumName(mesh.MeshType)=='Sphere'then shape='Ball';local m=mesh.Scale;s=V3(s.X*m.X,s.Y*m.Y,s.Z*m.Z)end
 table.insert(parts,string.format('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s}',
  index,c.Name,shape,n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),
  c3(c.Color),enumName(c.Material),n(c.Transparency or 0)))
end
for i,m in pairs(models)do
 for _,c in ipairs(m:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<1 then dumpPart(c,i)end end
end
-- Effects: neon parts, soft glows (billboard images) and beam rings, as the client shows them at time AGE.
for _,folder in ipairs(fx:GetChildren())do
 local i=tonumber(folder.Name:match('%d+'))or 0
 for _,c in ipairs(folder:GetDescendants())do
  if c:IsA('BasePart')and(c.Transparency or 0)<.99 then dumpPart(c,-i)
  elseif c.ClassName=='BillboardGui'and c.Adornee then
   local img=c:FindFirstChildOfClass('ImageLabel');local a=img and 1-(img.ImageTransparency or 1)or 0
   if a>.01 then local p=c.Adornee.CFrame.Position
    table.insert(glows,string.format('{"seed":%d,"p":[%s,%s,%s],"size":%s,"alpha":%s,"color":%s}',i,n(p.X),n(p.Y),n(p.Z),n(c.Size.X.Scale),n(a),c3(img.ImageColor3)))end
  elseif c.ClassName=='Beam'and c.Attachment0 and c.Attachment1 then
   local anchor=c.Attachment0.Parent;local f=anchor.CFrame
   local a0,a1=f*c.Attachment0.CFrame,f*c.Attachment1.CFrame
   local alpha=1-(c.Transparency and c.Transparency.Keypoints and c.Transparency.Keypoints[1].Value or c._alpha or .5)
   table.insert(beams,string.format('{"seed":%d,"a":[%s,%s,%s],"b":[%s,%s,%s],"ta":[%s,%s,%s],"tb":[%s,%s,%s],"c0":%s,"c1":%s,"w":%s,"alpha":%s,"color":%s}',i,
    n(a0.Position.X),n(a0.Position.Y),n(a0.Position.Z),n(a1.Position.X),n(a1.Position.Y),n(a1.Position.Z),
    n(a0.RightVector.X),n(a0.RightVector.Y),n(a0.RightVector.Z),n(a1.RightVector.X),n(a1.RightVector.Y),n(a1.RightVector.Z),
    n(c.CurveSize0 or 0),n(c.CurveSize1 or 0),n(c.Width0 or .05),n(alpha),c3(c.Color and c.Color.Keypoints and c.Color.Keypoints[1].Value or c._color)))
  end
 end
end
print(string.format('{"cols":%d,"rows":%d,"gap":%s,"parts":[%s],"glows":[%s],"beams":[%s],"labels":[%s]}',cols,math.ceil(#order/cols),n(gap),
 table.concat(parts,','),table.concat(glows,','),table.concat(beams,','),table.concat(labels,',')))
