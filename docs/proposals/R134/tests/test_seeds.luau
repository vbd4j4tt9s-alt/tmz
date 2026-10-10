--!nocheck
-- R134 (owner approved the seeds preview): the real SeedPackVisuals + SeedSignatures + SeedShapes on the mock.
--  * every seed builds; no "winged" side shards on any seed;
--  * the five redesigns and Prism Monarch's crystal cluster (different sizes and colours, no round wings);
--  * client effects: Legendary+ animate their signature parts (colour only, restored after), King adds rays,
--    Rare stays minor;
--  * part counts against R133 (SeedPackVisualsR133 from git);
--  * prints one JSON scene of every seed for check_floating.py (run.sh): nothing may float.
local W=require('./world');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
-- Mock gaps (Roblox does these natively): a full lookAt with an up vector, CFrame.fromMatrix.
R.CFrame.lookAt=function(p,t,up)
 local f=(t-p).Unit;local u0=up or V3(0,1,0)
 if math.abs(f.X*u0.X+f.Y*u0.Y+f.Z*u0.Z)>.999 then u0=math.abs(f.Y)>.9 and V3(0,0,1)or V3(0,1,0)end
 local r=f:Cross(u0).Unit;local u=r:Cross(f)
 return R.CFrame.new(p.X,p.Y,p.Z,r.X,u.X,-f.X,r.Y,u.Y,-f.Y,r.Z,u.Z,-f.Z)
end
R.CFrame.fromMatrix=function(p,x,y,z)z=z or x:Cross(y);return R.CFrame.new(p.X,p.Y,p.Z,x.X,y.X,z.X,x.Y,y.Y,z.Y,x.Z,y.Z,z.Z)end
W.env.CFrame=R.CFrame
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function same(a,b)return math.abs(a.R-b.R)<1e-4 and math.abs(a.G-b.G)<1e-4 and math.abs(a.B-b.B)<1e-4 end
local Rules=W.module('SeedPackRules');local Visuals=W.module('SeedPackVisuals');local Old=W.module('SeedPackVisualsR133')
local Shapes=W.module('SeedShapes');local Sigs=W.module('SeedSignatures')
local holder=R.new('Model');holder.Name='Seeds';holder.Parent=W.workspace
local order={}
for _,s in ipairs(Rules.SeedDesigns)do if s.stage~=8 then table.insert(order,s)end end
table.sort(order,function(a,b)if a.stage~=b.stage then return a.stage<b.stage end;return(a.index or 0)<(b.index or 0)end)
local built,models,oldParts,newParts,biggest={},{},0,0,{0,''}
local function parts(m)local n=0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')and d.Transparency<1 then n+=1 end end;return n end
for i,s in ipairs(order)do
 local at=CF(-((i-1)%9)*3.4,-math.floor((i-1)/9)*4.25,0)
 local ok,m=pcall(Visuals.Seed,{Id=s.id},1,at,holder,1,nil,'None')
 if check(ok,'builds: '..s.name..' '..tostring(not ok and m or''))then
  built[#built+1]=s;models[s.id]={Model=m,At=at,Spec=s}
  local n=parts(m);newParts+=n;if n>biggest[1]then biggest={n,s.name}end
  local okOld,om=pcall(Old.Seed,{Id=s.id},1,at*CF(0,0,50),holder,1,nil,'None');if okOld then oldParts+=parts(om);om:Destroy()end
 end
end
check(#built==#order and #order>=45,('every seed builds (%d/%d)'):format(#built,#order))
print(('parts per seed: R133 %.1f, R134 %.1f on average; most: %s with %d'):format(oldParts/#order,newParts/#order,biggest[2],biggest[1]))
check(newParts<=oldParts*1.35 and biggest[1]<=200,'part counts stay reasonable')
-- No winged side shards: no crystal sits beside the body below its top on any seed (Prism Monarch's cluster is
-- rooted in its lower facets and checked separately).
local winged={}
for id,e in pairs(models)do if id~='PrismMonarchSeed'then
 local body=Shapes.Body(Sigs.Shape(id));local top=Shapes.Extent(body)
 for _,d in ipairs(e.Model:GetDescendants())do if d:IsA('BasePart')and(d.Name=='Crystal'or d.Name=='Crystal tip')then
  local l=e.At:PointToObjectSpace(d.Position);local _,hw=Shapes.Span(body,l.Y)
  if l.Y<top-.25 and math.abs(l.X)>hw+.05 then winged[#winged+1]=e.Spec.name;break end
 end end
end end
check(#winged==0,'no winged side shards ('..table.concat(winged,', ')..')')
-- The five redesigns carry their new pieces.
local function names(id)local out={};for _,d in ipairs(models[id].Model:GetDescendants())do if d:IsA('BasePart')then out[d.Name]=(out[d.Name]or 0)+1 end end;return out end
local n=names('DiamondVineSeed');check((n['Vine']or 0)>=20 and(n['Diamond leaf']or 0)>=3 and n['Diamond bud']==1,'Diamond Vine: vine, diamond leaves and bud')
n=names('PrismOrchidSeed');check(n['Pepper lobe']==3 and(n['Crystal calyx']or 0)==5 and n['Crystal stem']==1 and(n['Prism glint']or 0)>=12,'Prism Pepper: lobes, crystal calyx and stem, rainbow glint')
n=names('AshRoseSeed');check(n['Sepal']==5 and n['Stem']==1 and(n['Ember crack']or 0)>=6,'Ash Tomato: sepals, stem, ember cracks')
n=names('IceberrySeed');check((n['Crystal']or 0)==6 and(n['Frost swirl']or 0)>=12 and n['Icicle']==1,'Iceberry: ice calyx, frost swirls, icicle')
n=names('VenomVineSeed');check((n['Vine']or 0)>=20 and n['Vine leaf']==2 and n['Venom drop']==1,'Venom Vine: vine, leaves, venom drop')
check(Sigs.Shape('PrismOrchidSeed')=='Pepper','Prism Pepper has its own pepper body')
-- Prism Monarch: no round wings; a cluster of small crystals in different sizes and colours; the crown stays.
n=names('PrismMonarchSeed');check(not n['Prism wing'],'Prism Monarch: the round wings are gone')
local colours,lengths={},{}
for _,d in ipairs(models.PrismMonarchSeed.Model:GetDescendants())do if d:IsA('BasePart')and d.Name=='Crystal'then
 colours[('%.2f,%.2f,%.2f'):format(d.Color.R,d.Color.G,d.Color.B)]=true;lengths[('%.2f'):format(d.Size.Z)]=true
end end
local nc,nl=0,0;for _ in pairs(colours)do nc+=1 end;for _ in pairs(lengths)do nl+=1 end
check((n['Crystal']or 0)>=8 and nc>=5 and nl>=4,('Prism Monarch: %d crystals, %d colours, %d sizes'):format(n['Crystal']or 0,nc,nl))
check((n['Crown rim']or 0)==7 and n['Royal gem']==1,'Prism Monarch keeps its crown')
-- Client effects ------------------------------------------------------------------------------------------------
local fx=R.new('Folder');fx.Parent=W.workspace
local function motion(id)local e=models[id];local mo=Visuals.CreateSeedMotion(e.Model,fx,true);return mo,e end
local rare=motion('IceberrySeed');check(rare and #rare.Anim==0 and not rare.Rays,'Rare: minor effects only (no part animation, no rays)')
local lava,le=motion('LavaLotusSeed')
check(lava and #lava.Anim>=7,'Legendary: the flames animate ('..(lava and #lava.Anim or 0)..')')
local flame=lava.Anim[1].Part;local base=flame.Color
local seen={}
for i=1,12 do lava:Update(le.At,i*.37,1,1);seen[('%.3f'):format(flame.Color.R+flame.Color.G+flame.Color.B)]=true end
local distinct=0;for _ in pairs(seen)do distinct+=1 end
check(distinct>=6,'flames flicker over time ('..distinct..' shades)')
local pos=flame.CFrame.Position;lava:Update(le.At,9,1,1);check((flame.CFrame.Position-pos).Magnitude<1e-6,'animation never moves parts (safe on welded held seeds)')
lava:Destroy();check(same(flame.Color,base),'colours restored when the effect stops')
local king,ke=motion('PrismMonarchSeed')
local rays=0;for _,d in ipairs(king.Folder:GetDescendants())do if d.Name=='Royal ray'then rays+=1 end end
check(king.Rays and rays==8,'King: eight golden rays behind the seed')
king:Update(ke.At,1,1,1);local r1=nil;for _,d in ipairs(king.Folder:GetDescendants())do if d.Name=='Royal ray'then r1=d.CFrame.Position;break end end
king:Update(ke.At,3,1,1);local r2=nil;for _,d in ipairs(king.Folder:GetDescendants())do if d.Name=='Royal ray'then r2=d.CFrame.Position;break end end
check(r1 and r2 and(r1-r2).Magnitude>.05,'the rays turn slowly')
check(#king.Anim>=4,'King crystals twinkle ('..#king.Anim..')')
local far=Visuals.CreateSeedMotion(models.LavaLotusSeed.Model,fx,false)
check(far and #far.Anim==0,'far away (not detailed): no part animation')
-- Scene for the floating-part check
local function n4(v)return string.format('%.4f',v)end
local out={}
for i,s in ipairs(built)do
 for _,c in ipairs(models[s.id].Model:GetDescendants())do if c:IsA('BasePart')and(c.Transparency or 0)<1 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local sz=c.Size
  local shape=(c.Shape and(type(c.Shape)=='table'and c.Shape.Name or tostring(c.Shape):match('(%w+)$')))or'Block'
  local mesh=c:FindFirstChildOfClass('SpecialMesh');if mesh then shape='Ball';local k=mesh.Scale;sz=V3(sz.X*k.X,sz.Y*k.Y,sz.Z*k.Z)end
  out[#out+1]=('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"t":%s}'):format(i,c.Name,shape,
   n4(sz.X),n4(sz.Y),n4(sz.Z),n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),n4(c.Transparency or 0))
 end end
end
local labels={};for i,s in ipairs(built)do labels[i]=('{"text":"%s"}'):format(s.name)end
print('SCENE {"parts":['..table.concat(out,',')..'],"labels":['..table.concat(labels,',')..']}')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
