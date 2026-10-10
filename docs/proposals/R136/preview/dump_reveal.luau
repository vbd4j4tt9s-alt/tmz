--!nocheck
-- Reveal preview (not a test): a Legendary (Lava Lotus) and a Mythic (Diamond Vine) pull side by side at time T,
-- built with the real RevealFlourish and seed builder. A brown block stands in for the pack (pack meshes only exist
-- in the place). Prints one JSON scene for seeds.html.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local F=W.module('RevealFlourish');local Seq=W.module('RarityRevealSequence');local Visuals=W.module('SeedPackVisuals')
local Rules=W.module('SeedPackRules');local B=W.module('BalanceRules')
local scene=R.new('Model');scene.Parent=W.workspace
local labels={}
for col,spec in ipairs({{4,'LavaLotusSeed','Legendary pull'},{5,'DiamondVineSeed','Mythic pull'}})do
 local rank,id=spec[1],spec[2];local x=-(col-1)*12;local at=Seq.SeedAt(rank);local t=T
 local bagTop=CF(x,-3,0)
 local fade=math.clamp((t-.1-.42)/.7,0,1)
 local bag=R.new('Part');bag.Name='Pack stand-in';bag.Size=V3(1.9,2.2,.5);bag.CFrame=bagTop*CF(0,-1.1,0);bag.Color=R.Color3.fromRGB(150,110,70);bag.Transparency=fade;bag.Parent=scene
 local f=F.Create(scene,rank,1);f:Update(bagTop,t,at,false)
 if t>=at then
  local age=t-at;local rise,slide=B.SeedPhase(age);local ease=1-(1-rise)^3
  local frame=bagTop*CF(0,-1.1*(1-ease)+ease*(1.1+.8),0)*Rules.RevealPose(rank,age,ease)*R.CFrame.Angles(0,math.rad(-22),0)
  local ok,m=pcall(Visuals.Seed,{Id=id},1,frame,scene,1,nil,'None')
  local motion=ok and Visuals.CreateSeedMotion(m,scene,true);if motion then motion:Update(frame,age,1,ease)end
 end
 labels[#labels+1]=('{"text":"%s","rarity":"%s","p":[%.3f,%.3f,0]}'):format(spec[3],rank==4 and'Legendary'or'Mythic',x,-1.55)
end
local function n(v)return string.format('%.4f',v)end
local function c3(c)return string.format('[%d,%d,%d]',math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))end
local function enumName(e)if type(e)=='table'and e.Name then return e.Name end;local s=tostring(e);return s:match('([%w_]+)$')or s end
local parts,glows,beams={},{},{}
local tilt=R.CFrame.Angles(math.rad(22),0,0)
local function tiltP(p)return tilt*p end
for _,c in ipairs(scene:GetDescendants())do
 if c:IsA('BasePart')and(c.Transparency or 0)<.99 then
  local cf=tilt*c.CFrame;local r=cf.R;local p=cf.Position;local s=c.Size
  local shape=(c.Shape and enumName(c.Shape))or'Block'
  local mesh=c:FindFirstChildOfClass('SpecialMesh');if mesh then shape='Ball';local k=mesh.Scale;s=V3(s.X*k.X,s.Y*k.Y,s.Z*k.Z)end
  parts[#parts+1]=('{"seed":1,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"color":%s,"material":"%s","t":%s}'):format(c.Name,shape,
   n(s.X),n(s.Y),n(s.Z),n(p.X),n(p.Y),n(p.Z),n(r[1][1]),n(r[1][2]),n(r[1][3]),n(r[2][1]),n(r[2][2]),n(r[2][3]),n(r[3][1]),n(r[3][2]),n(r[3][3]),c3(c.Color),enumName(c.Material),n(c.Transparency or 0))
 elseif c.ClassName=='BillboardGui'and c.Adornee then
  local img=c:FindFirstChildOfClass('ImageLabel');local a=img and 1-(img.ImageTransparency or 1)or 0
  if a>.01 then local p=tiltP(c.Adornee.CFrame.Position);glows[#glows+1]=('{"p":[%s,%s,%s],"size":%s,"alpha":%s,"color":%s}'):format(n(p.X),n(p.Y),n(p.Z),n(c.Size.X.Scale),n(a),c3(img.ImageColor3))end
 elseif c:IsA('PointLight')and c.Brightness>.05 and c.Parent and c.Parent:IsA('BasePart')then
  local p=tiltP(c.Parent.Position);glows[#glows+1]=('{"p":[%s,%s,%s],"size":%s,"alpha":%s,"color":%s}'):format(n(p.X),n(p.Y),n(p.Z),n(c.Range*.35),n(math.min(.8,c.Brightness/5)),c3(c.Color))
 end
end
print(('{"cols":2,"rows":1,"gap":12,"parts":[%s],"glows":[%s],"beams":[],"labels":[%s]}'):format(table.concat(parts,','),table.concat(glows,','),table.concat(labels,',')))
