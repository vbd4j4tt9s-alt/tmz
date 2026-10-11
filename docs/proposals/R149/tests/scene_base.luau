--!nocheck
-- R149: the plants whose floating check run_fruit_models.sh compares with the base, built in whatever world it runs in (the BASE commit's modules
-- or this checkout's) with the same crop ids as test_fruit_models.luau, as one check_floating.py scene (R148's format: an ellipsoid is a box).
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals')
local scene,labels={},{}
local names={SunflowerSeed='Watermelon',SnowdropSeed='Snow Melon',AppleSeed='Apple',ElderbloomSeed='Elderbloom',EmberBloomSeed='Ember Pumpkin',CactusSeed='Prickly Pear',BluebellSeed='Blueberry',IceberrySeed='Iceberry'}
local function add(label,model)
 labels[#labels+1]=label;local seed=#labels
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and c.Name~='VisualPivot'and(c.Transparency or 0)<1 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local sz=c.Size
  local shape=(c.Shape and(type(c.Shape)=='table'and c.Shape.Name or tostring(c.Shape):match('(%w+)$')))or'Block'
  local function n4(v)return string.format('%.4f',v)end
  scene[#scene+1]=('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"t":%s}'):format(seed,c.Name,shape,
   n4(sz.X),n4(sz.Y),n4(sz.Z),n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),n4(c.Transparency or 0))
 end end
end
for id,name in pairs(names)do
 for _,cid in ipairs({'build-a','build-b'})do
  local d=Catalog[id];local c={Id=cid,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
  add(name..' '..cid,Visuals.Build(id,CF(0,0,0),c,4,math.huge))
 end
end
local function label()local o={};for i,l in ipairs(labels)do o[i]=('{"text":"%s"}'):format(l)end;return table.concat(o,',')end
print('SCENE {"parts":['..table.concat(scene,',')..'],"labels":['..label()..']}')
