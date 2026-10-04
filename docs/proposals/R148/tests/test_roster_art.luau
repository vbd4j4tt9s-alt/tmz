--!nocheck
-- R148 (owner): the art of the seed roster change on the Roblox mock with the REAL modules (DesertPlantArt149, ApprovedPlantArt, PlantVisuals,
-- PlantGrowth, PlantEffects, SeedPackVisuals, SeedSignatures, ChestIndex): Desert's Rare Aloe (blue-green rosette, three red-orange flower spikes)
-- and Legendary Sand Fruit palm (leaning palm, four bunches of sand-gold fruit), and the Mythic Fire Pepper at twice the size.
--  1. the art lists: the 96 / 99 parts, every group present, roles, nothing under the soil, sockets / centres / radii / Height / Radius = the catalog;
--  2. every build mode: ripe, growing at body .1 / .5 / .9, one harvest item per group, the distant supports (the palm's trunk collides), the
--     harvested fruit, and no floating part anywhere (the scene goes through check_floating.py, R134);
--  3. Fire Pepper: every spec of the base's art x2 (position and size; rotation untouched), for every crop variant; Prism Pepper unchanged;
--  4. existing plants unchanged against the base commit's pipeline (PlantVisualsBase / PlantGrowthBase / ApprovedPlantArtBase, from git);
--  5. the three seeds (42 / 69 / 46 parts; Twinkle x2 on the Sand Fruit, Flicker x3 on Fire Pepper, nothing on the Rare Aloe);
--  6. the rarity effects (aura on the Sand Fruit, Moon Melon, Fire Pepper; none on the Aloe);
--  7. the Index: the Desert tab shows seven cards in rarity order; a player complete under the old 5-seed Desert roster sees the reward dot and
--     lit claim buttons, and a claimed reward stays claimed.
-- It prints one JSON scene (SCENE ...) of every plant model for check_floating.py (run_roster.sh).
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
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function kIs(k,r,g,b)return k[1]==r and k[2]==g and k[3]==b end
local Catalog=W.module('PlantCatalog');local Art=W.module('DesertPlantArt149');local Approved=W.module('ApprovedPlantArt')
local Visuals=W.module('PlantVisuals');local PG=W.module('PlantGrowth');local Rules=W.module('PlantRules');local Packs=W.module('SeedPackRules')
local SeedVisuals=W.module('SeedPackVisuals');local Effects=W.module('PlantEffects');local Sigs=W.module('SeedSignatures')
local OldApproved=W.module('ApprovedPlantArtBase');local OldVisuals=W.module('PlantVisualsBase')
local origin=CF(0,0,0)
local IDS={'DesertAloeSeed','SandFruitSeed'}
local function crop(id,extra)
 local def=Catalog[id]
 local c={Id='roster-'..id,SeedId=id,PlantedAt=0,MatureAt=def.Seconds,ReadyAt=def.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local function parts(model,visibleOnly)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d.Name~='VisualPivot'and(not visibleOnly or d.Transparency<1)then out[#out+1]=d end end;return out end
-- The lowest and highest point of a part in the plant's frame (a rotated box's real extent).
local function extent(d)
 local x,y,z,a,b,c,dd,e,f,g,h,i=d.CFrame:GetComponents();local ey=(math.abs(dd)*d.Size.X+math.abs(e)*d.Size.Y+math.abs(f)*d.Size.Z)/2
 return y-ey,y+ey
end
local function specExtent(s)local c,z=s.c,s.z;local ey=(math.abs(c[7])*z[1]+math.abs(c[8])*z[2]+math.abs(c[9])*z[3])/2;return c[2]-ey,c[2]+ey end

-- 1. The art lists --------------------------------------------------------------------------------------------------------------------------
local want={DesertAloeSeed={specs=96,groups={[0]=63,11,11,11},cost=97,height=8.243,radius=5.211},SandFruitSeed={specs=99,groups={[0]=67,8,8,8,8},cost=100,height=14.182,radius=7.252}}
for _,id in ipairs(IDS)do
 local w=want[id];local def=Catalog[id];local art=Approved.Get(id)
 check(Approved.Has(id)==true and Art.Is(id)==true and Art.Get(id)==art and art.RarityRework==true,id..': ApprovedPlantArt routes to DesertPlantArt149 (a RarityRework spec list)')
 check(#art.Specs==w.specs,id..': '..w.specs..' art parts ('..#art.Specs..')')
 local groups,okShape,okRole,okNums,lowest,neon,cost={},true,true,true,math.huge,0,0
 for i,s in ipairs(art.Specs)do
  groups[s.g]=(groups[s.g]or 0)+1;cost+=Visuals.PartCost(s)
  if not(s.s=='Wedge'or s.s=='Ball'or s.s=='Cylinder'or s.s=='Sphere')then okShape=false end
  if s.g==0 then if not(s.r=='Leaf'or s.r=='Stem')then okRole=false end else if s.r~='Fruit'then okRole=false end end
  if #s.c~=12 or #s.z~=3 or #s.k~=3 or s.p~=1 or s._ArtIndex~=i or type(s.m)~='string'or type(s.f)~='string'then okNums=false end
  for _,v in ipairs(s.c)do if v~=v or math.abs(v)==math.huge then okNums=false end end
  for _,v in ipairs(s.z)do if v~=v or v<=0 then okNums=false end end
  local lo=specExtent(s);lowest=math.min(lowest,lo);if s.m=='Neon'then neon+=1 end
 end
 check(okShape and okRole and okNums,id..': every part has a known shape, a role (body Leaf / Stem, fruit groups Fruit), 12 + 3 + 3 numbers, p = 1')
 local counts={};for g=0,def.FruitCount do counts[#counts+1]=groups[g]or 0 end
 local wantCounts={};for g=0,def.FruitCount do wantCounts[#wantCounts+1]=w.groups[g]end
 check(table.concat(counts,',')==table.concat(wantCounts,',')and groups[def.FruitCount+1]==nil,id..': groups 0..'..def.FruitCount..' hold '..table.concat(counts,' / ')..' parts, no stray group')
 check(lowest>=-.05,('%s: nothing below the soil (lowest %.4f)'):format(id,lowest))
 check(cost==w.specs and Visuals.Metadata(id,crop(id)).Cost==w.cost,id..': detail cost '..w.cost..' = one per part plus the plant itself (PlantDetailPlanner screen budget is 1400)')
 check(near(art.Height,w.height,1e-9)and near(art.Radius,w.radius,1e-9)and near(def.Height,art.Height,1e-12)and near(def.Radius,art.Radius,1e-12),id..': Height '..w.height..' / Radius '..w.radius..' = the catalog')
 local meta=true
 for i=1,def.FruitCount do for k=1,3 do meta=meta and near(def.Sockets[i][k],art.Sockets[i][k],1e-12)and near(def.FruitCenters[i][k],art.FruitCenters[i][k],1e-12)end;meta=meta and def.FruitRadii[i]==art.FruitRadii[i]end
 check(meta and #art.Sockets==def.FruitCount and #art.FruitCenters==def.FruitCount and #art.FruitRadii==def.FruitCount,id..': Sockets / FruitCenters / FruitRadii = the catalog, one per fruit')
 -- the farthest reach of the parts is the Radius, the highest point the Height (the catalog's bounds are the art's own)
 local top,reach=-math.huge,0
 for _,s in ipairs(art.Specs)do local _,hi=specExtent(s);top=math.max(top,hi);local ex=(math.abs(s.c[4])*s.z[1]+math.abs(s.c[5])*s.z[2]+math.abs(s.c[6])*s.z[3])/2;local ez=(math.abs(s.c[10])*s.z[1]+math.abs(s.c[11])*s.z[2]+math.abs(s.c[12])*s.z[3])/2
  reach=math.max(reach,math.sqrt(s.c[1]^2+s.c[3]^2)+math.max(ex,ez))end
 check(near(top,art.Height,.001)and near(reach,art.Radius,.001),('%s: the highest point %.3f and the widest reach %.3f are the Height and Radius'):format(id,top,reach))
 -- every fruit group keeps its parts around its own socket (the group is what a harvest picks up)
 local near_=true
 for g=1,def.FruitCount do
  local c=V3(table.unpack(art.FruitCenters[g]));local rad=art.FruitRadii[g]
  local hits=0;for _,s in ipairs(art.Specs)do if s.g==g then hits+=1;local d=(V3(s.c[1],s.c[2],s.c[3])-c).Magnitude;if d>rad*2.2 then near_=false end end end
  if hits==0 then near_=false end
 end
 check(near_,id..': every group\'s parts stay within 2.2 fruit radii of its fruit centre (so the harvest glints and picking sit on the fruit)')
 check(neon==(id=='SandFruitSeed'and 4 or 0),id..': '..neon..' Neon parts ('..(id=='SandFruitSeed'and'the four sand sparkles'or'none')..')')
end
-- Colours and shapes of the design.
do
 local a=Approved.Get('DesertAloeSeed');local heart,leaves,spots,teeth,stalks,florets,buds=0,0,0,0,0,{},0
 for _,s in ipairs(a.Specs)do
  if s.f=='Rosette heart'then heart+=1;check(kIs(s.k,98,150,128)and s.s=='Ball','Aloe: the rosette heart is a blue-green Ball (98,150,128)')end
  if s.f=='Aloe leaf'then leaves+=1;check(s.s=='Wedge'and s.r=='Leaf'and s.g==0,'Aloe: leaves are Wedge pairs in the body')end
  if s.f=='Aloe leaf spot'then spots+=1;check(kIs(s.k,204,228,214),'Aloe: cream leaf spots (204,228,214)')end
  if s.f=='Aloe leaf tooth'then teeth+=1;check(kIs(s.k,176,120,96),'Aloe: red-brown teeth (176,120,96)')end
  if s.f=='Aloe flower stalk'then stalks+=1;check(s.s=='Cylinder'and s.r=='Fruit'and s.g>=1 and s.g<=3 and kIs(s.k,126,146,100),'Aloe: each flower stalk is a Fruit-role Cylinder (not Stem: a held spike must keep its florets)')end
  if s.f=='Aloe floret'then local key=table.concat(s.k,',');florets[key]=(florets[key]or 0)+1 end
  if s.f=='Aloe bud tip'then buds+=1 end
  check(s.m=='SmoothPlastic'and s.tx==nil,'Aloe: SmoothPlastic, no textures')
 end
 check(heart==1 and leaves==34 and spots==14 and teeth==14 and stalks==3 and buds==3,('Aloe: 1 heart, 34 leaf wedges (17 leaves), 14 spots, 14 teeth, 3 stalks, 3 bud tips (%d %d %d %d %d %d)'):format(heart,leaves,spots,teeth,stalks,buds))
 check((florets['236,96,48']or 0)==12 and(florets['250,150,60']or 0)==9 and(florets['240,196,92']or 0)==6,'Aloe: 27 florets, red-orange 12 / orange 9 / gold 6 (4 + 3 + 2 on each of the 3 spikes)')
 local p=Approved.Get('SandFruitSeed');local trunk,rings,fronds,tips,fruits,ripples,sparks,boots,toes=0,0,0,0,0,0,0,0,0
 for _,s in ipairs(p.Specs)do
  if s.f=='Palm trunk'then trunk+=1;check(s.m=='Wood'and s.s=='Cylinder'and s.r=='Stem'and(kIs(s.k,150,110,70)or kIs(s.k,136,99,62)),'Palm: trunk segments are Wood Cylinders, two alternating browns')end
  if s.f=='Palm trunk ring'then rings+=1;check(s.m=='Wood'and kIs(s.k,112,80,50),'Palm: darker Wood rings at the joints')end
  if s.f=='Palm frond'then fronds+=1 end
  if s.f=='Palm frond tip'then tips+=1 end
  if s.f=='Dry frond boot'then boots+=1 end
  if s.f=='Palm root toe'then toes+=1;check(s.s=='Wedge'and s.m=='Wood','Palm: root toes are Wood Wedges')end
  if s.f=='Sand fruit'then fruits+=1;check(s.s=='Sphere'and s.r=='Fruit'and s.g>=1 and s.g<=4 and(kIs(s.k,222,182,112)or kIs(s.k,214,170,98)or kIs(s.k,230,192,124))and near(s.z[1],1.05)and near(s.z[2],1.05),'Palm: sand fruits are Sphere 1.05 in three sand golds')end
  if s.f=='Sand fruit ripple'then ripples+=1;check(kIs(s.k,184,138,78),'Palm: a darker dune-ripple band on each fruit')end
  if s.f=='Sand sparkle'then sparks+=1;check(s.m=='Neon'and kIs(s.k,255,236,170)and near(s.z[1],.18),'Palm: the sand sparkles are Neon (255,236,170)')end
 end
 check(trunk==5 and rings==5 and fronds==16 and tips==16 and boots==8 and toes==3 and fruits==12 and ripples==12 and sparks==4,('Palm: 5 trunk segments + 5 rings, 8 fronds (16 + 16 blades), 8 boot blades, 3 toes, 12 fruits + 12 ripples, 4 sparkles (%d %d %d %d %d %d %d %d %d)'):format(trunk,rings,fronds,tips,boots,toes,fruits,ripples,sparks))
 -- the palm leans: the crown sits to the +X side of the root, and every bunch hangs below the crown
 local crownX,crownY;for _,s in ipairs(p.Specs)do if s.f=='Palm crown heart'then crownX,crownY=s.c[1],s.c[2]end end
 check(near(crownX,1.1,1e-9)and near(crownY,11.4,1e-9),'Palm: the crown leans to x 1.1 at y 11.4')
 local under=true;for g=1,4 do if p.Sockets[g][2]>=crownY or p.FruitCenters[g][2]>=crownY-1 then under=false end end
 check(under and near(p.Sockets[1][2],10.8,1e-9)and near(p.FruitCenters[1][2],9.8223,.001)and p.FruitRadii[1]==1.05,'Palm: the four bunches hang under the crown (sockets y 10.8, fruit centres y 9.82, radius 1.05)')
end

-- 2. Every build mode ------------------------------------------------------------------------------------------------------------------------
local scene={};local labels={}
local function addScene(label,model)
 labels[#labels+1]=label;local seed=#labels
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and c.Name~='VisualPivot'and(c.Transparency or 0)<1 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local sz=c.Size
  local shape=(c.Shape and(type(c.Shape)=='table'and c.Shape.Name or tostring(c.Shape):match('(%w+)$')))or'Block'
  local function n4(v)return string.format('%.4f',v)end
  scene[#scene+1]=('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"t":%s}'):format(seed,c.Name,shape,
   n4(sz.X),n4(sz.Y),n4(sz.Z),n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),n4(c.Transparency or 0))
 end end
end
for _,id in ipairs(IDS)do
 local def=Catalog[id];local w=want[id];local art=Approved.Get(id)
 check(PG.Profile(id,def)==(id=='SandFruitSeed'and'Tree'or'Bush'),id..': grows with the '..(id=='SandFruitSeed'and'Tree'or'Bush')..' profile (generic growth: no per-stage art is needed)')
 -- ripe
 local m=Visuals.Build(id,origin,crop(id),4,math.huge)
 local base=m:FindFirstChild('PlantBase');local kids={}
 for g=1,def.FruitCount do kids[g]=m:FindFirstChild('Harvest_'..g)end
 local counts={};for g=1,def.FruitCount do local n=0;if kids[g]then for _,d in ipairs(kids[g]:GetDescendants())do if d:IsA('BasePart')then n+=1 end end end;counts[g]=n end
 local baseCount=0;for _,d in ipairs(base:GetDescendants())do if d:IsA('BasePart')then baseCount+=1 end end
 check(baseCount==w.groups[0]and table.concat(counts,',')==(id=='DesertAloeSeed'and'11,11,11'or'8,8,8,8'),id..': ripe: PlantBase '..w.groups[0]..' parts and one Harvest_N model per fruit group ('..table.concat(counts,'/')..')')
 check(#parts(m)==w.specs and #parts(m,true)==w.specs,id..': ripe: all '..w.specs..' parts built and visible')
 local queryOk=true;for g=1,def.FruitCount do for _,d in ipairs(kids[g]:GetDescendants())do if d:IsA('BasePart')and not d.CanQuery then queryOk=false end end end
 for _,d in ipairs(base:GetDescendants())do if d:IsA('BasePart')and d.CanQuery then queryOk=false end end
 check(queryOk,id..': ripe: every fruit part can be queried (harvest prompt), no body part can')
 local lo,hi=math.huge,-math.huge;for _,d in ipairs(parts(m))do local a,b=extent(d);lo=math.min(lo,a);hi=math.max(hi,b)end
 check(lo>=-.0501 and near(hi,w.height,.002),('%s: ripe: lowest %.4f (no part under the soil), highest %.3f = Height'):format(id,lo,hi))
 addScene(id..' ripe',m)
 -- growing at body .1 / .5 / .9 (and the ends): grows monotonically, fruit appears after the body, the finished plant is the ripe one
 local lastTop,monotonic=-1,true;local lines={}
 for _,f in ipairs({0,.1,.3,.5,.7,.9,1})do
  local g=Visuals.BuildGrowing(id,origin,crop(id),f*def.Seconds)
  local vis=parts(g,true);local glo,ghi=math.huge,-math.huge;local fruitVisible=0
  for _,d in ipairs(vis)do local a,b=extent(d);glo=math.min(glo,a);ghi=math.max(ghi,b);if d.Parent and d.Parent.Name:find('Harvest_')then fruitVisible+=1 end end
  if ghi<lastTop-1e-6 then monotonic=false end;lastTop=ghi
  lines[#lines+1]=('%d%%: %d visible, top %.2f'):format(f*100,#vis,ghi)
  check(glo>=-.0501,('%s growing %d%%: nothing under the soil (%.4f)'):format(id,f*100,glo))
  check(#parts(g)<=125,('%s growing %d%%: %d parts in all (the %d art parts plus the generic growth pieces)'):format(id,f*100,#parts(g),w.specs))
  if f==0 then check(#vis==1,id..': 0%: only the new seed shows ('..#vis..')')end
  if f==.1 then check(fruitVisible==0 and ghi<1,id..': 10%: a sprout, no fruit yet (top '..ghi..')')end
  if f==.5 then check(ghi<w.height*.75,id..': 50%: still growing (top '..ghi..' of '..w.height..')')end
  if f==.9 then check(fruitVisible>0 and ghi>w.height*.5,id..': 90%: the fruit is showing, the body nearly done (top '..ghi..')')end
  if f==1 then check(#vis==w.specs and near(ghi,w.height,.002),id..': 100%: the whole '..w.specs..'-part plant, Height '..w.height)end
  if f==.3 or f==.7 then addScene(id..' growing '..f*100 ..'%',g)end
 end
 print(id..' growth: '..table.concat(lines,' | '))
 check(monotonic,id..': the plant only ever gets taller as it grows')
 -- the harvest of one group: a stalk with its fruits, never the body
 for g=1,def.FruitCount do
  local item=Visuals.BuildSelectedFruit(id,origin,crop(id),{[g]=true},math.huge)
  local ps=parts(item);local ok=#ps==w.groups[g]
  for _,d in ipairs(ps)do local gAttr=d.Parent and d.Parent:GetAttribute('HarvestIndex');if gAttr~=g then ok=false end end
  check(ok,id..': harvest item '..g..': '..w.groups[g]..' parts, all from group '..g)
  local detached=Visuals.BuildSelectedFruit(id,origin,crop(id,{_DetachedHarvest=true}),{[g]=true},math.huge)
  check(#parts(detached)==w.groups[g],id..': harvest item '..g..' (detached, as held in the hand): no part dropped (the stalk is a Fruit part, not a Stem)')
  local specOk=true;for _,s in ipairs(art.Specs)do if s.g==g and not Visuals.HarvestSpec(id,s)then specOk=false end end
  check(specOk,id..': HarvestSpec keeps every part of group '..g)
  if g==1 or g==def.FruitCount then addScene(id..' harvest item '..g,item)end
 end
 -- distant supports: the body only; the palm's trunk collides (cost 14 within the 24 budget), the Aloe has no collision
 local sup=R.new('Model');Visuals.Supports(id,origin,crop(id),4,sup)
 local sp,collide,collideCost=parts(sup),0,0
 for _,d in ipairs(sp)do if d.CanCollide then collide+=1;collideCost+=1 end end
 check(#sp==w.groups[0],id..': supports: the '..w.groups[0]..' body parts ('..#sp..')')
 if id=='SandFruitSeed'then check(collide==14 and collideCost<=24,id..': supports: the 14 trunk / root parts collide, within the 24-cost budget ('..collide..')')
 else check(collide==0,id..': supports: nothing collides (not a tree)')end
 local grow=R.new('Model');Visuals.GrowingSupports(id,origin,crop(id),1,grow,.5*def.Seconds)
 check(#parts(grow)>0,id..': the distant growing path builds ('..#parts(grow)..' parts)')
 -- a scaled plant (PlantScale 2) scales every part and keeps the ground
 local big=Visuals.Build(id,origin,crop(id,{PlantScale=2}),4,math.huge);local blo,bhi=math.huge,-math.huge
 for _,d in ipairs(parts(big))do local a,b=extent(d);blo=math.min(blo,a);bhi=math.max(bhi,b)end
 check(blo>=-.1 and bhi>w.height*1.8,('%s: PlantScale 2: nothing under the soil, %.2f high'):format(id,bhi))
 -- the coats
 for _,coat in ipairs({'Gold','Diamond'})do
  local cm=Visuals.Build(id,origin,crop(id,{Mutation=coat}),4,math.huge)
  check(#parts(cm)==w.specs,id..': '..coat..' coat builds all parts')
 end
end
print('SCENE {"parts":['..table.concat(scene,',')..'],"labels":['..(function()local o={};for i,l in ipairs(labels)do o[i]=('{"text":"%s"}'):format(l)end;return table.concat(o,',')end)()..']}')

-- 3. Fire Pepper x2 ---------------------------------------------------------------------------------------------------------------------------
do
 local id='FirePepperSeed'
 local old,new=OldApproved.Get(id),Approved.Get(id)
 check(old and new and old~=new and #old.Specs==#new.Specs and #new.Specs==34,'Fire Pepper art: 34 parts in both the base and now (no new mesh)')
 local function same(a,b)for i=1,#a do if a[i]~=b[i]then return false end end;return true end
 local function twice(a,b)for i=1,#a do if not near(a[i]*2,b[i],1e-9)then return false end end;return true end
 local geo,rest=true,true
 for i,s in ipairs(old.Specs)do
  local n=new.Specs[i]
  if not(twice(s.z,n.z)and twice({s.c[1],s.c[2],s.c[3]},{n.c[1],n.c[2],n.c[3]})and same({table.unpack(s.c,4,12)},{table.unpack(n.c,4,12)}))then geo=false end
  for k,v in pairs(s)do if k~='z'and k~='c'then if type(v)=='table'then if table.concat(v,',')~=table.concat(n[k],',')then rest=false end elseif n[k]~=v then rest=false end end end
 end
 check(geo,'Fire Pepper art: every spec\'s size and position are exactly x2, the rotation is untouched')
 check(rest,'... and every other field (shape, colour, material, group, role, name, mesh) is the same as the base')
 local meta=near(new.Height,old.Height*2,1e-9)and near(new.Radius,old.Radius*2,1e-9)
 for i=1,#old.Sockets do for k=1,3 do meta=meta and near(new.Sockets[i][k],old.Sockets[i][k]*2,1e-9)and near(new.FruitCenters[i][k],old.FruitCenters[i][k]*2,1e-9)end;meta=meta and near(new.FruitRadii[i],old.FruitRadii[i]*2,1e-9)end
 check(meta and #new.Sockets==4 and #new.FruitRadii==4,'Fire Pepper art: Height, Radius, the 4 sockets, fruit centres and radii are x2 ('..('%.4f / %.4f'):format(new.Height,new.Radius)..')')
 local lowest=math.huge;for _,s in ipairs(new.Specs)do local lo=specExtent(s);lowest=math.min(lowest,lo)end
 local lowestOld=math.huge;for _,s in ipairs(old.Specs)do local lo=specExtent(s);lowestOld=math.min(lowestOld,lo)end
 check(near(lowest,lowestOld*2,1e-9)and lowest>=-.2,('Fire Pepper art: the lowest point stays at the soil (base %.4f, now %.4f; uniform x2: a fruit-only scale would sink the lowest pepper)'):format(lowestOld,lowest))
 -- each crop variant (random size / turn from the crop id) is x2 of the base's variant
 local allVariants=true
 for n=1,12 do
  local c=crop(id,{Id='variant-'..n});local a,b=OldApproved.Get(id,c),Approved.Get(id,c);local ok=#a.Specs==#b.Specs and near(a.Height*2,b.Height,1e-9)
  for i,s in ipairs(a.Specs)do local t=b.Specs[i];if not(twice(s.z,t.z)and twice({s.c[1],s.c[2],s.c[3]},{t.c[1],t.c[2],t.c[3]}))then ok=false end end
  for i=1,#a.Sockets do for k=1,3 do if not near(a.Sockets[i][k]*2,b.Sockets[i][k],1e-9)then ok=false end end end
  if not ok then allVariants=false end
 end
 check(allVariants,'Fire Pepper art: the 12 crop variants are x2 of the base\'s variants too (specs, sockets, height)')
 -- the base module is untouched by the new one (and the other peppers do not follow)
 local prism,prismOld=Approved.Get('PrismOrchidSeed'),OldApproved.Get('PrismOrchidSeed')
 local identical=#prism.Specs==#prismOld.Specs and prism.Height==prismOld.Height and prism.Radius==prismOld.Radius
 for i,s in ipairs(prism.Specs)do for k=1,3 do if s.z[k]~=prismOld.Specs[i].z[k]or s.c[k]~=prismOld.Specs[i].c[k]then identical=false end end end
 check(identical,'Prism Pepper (same mesh family, other module) is exactly as in the base')
 -- the catalog's x2 follows the art's: the lowest pepper still hangs under its socket by the same ratio
 local def=Catalog[id]
 check(near(def.FruitRadii[4],new.FruitRadii[4]*(def.BaseScale or 1),.01)or near(def.FruitRadii[4],2*1.6046,.001),'catalog metadata x2 as well (FruitRadii[4] '..def.FruitRadii[4]..')')
end

-- 4. Existing plants unchanged -----------------------------------------------------------------------------------------------------------------
do
 for _,id in ipairs({'SunflowerSeed','AppleSeed','MoonflowerSeed','PrismOrchidSeed','CactusSeed','DatePalmSeed','LavaLotusSeed','PlasmaPepperSeed','SolarStarfruitSeed','AncientWorldrootSeed','NoSuchSeed'})do
  check(Approved.Has(id)==OldApproved.Has(id),'ApprovedPlantArt.Has('..id..') unchanged ('..tostring(OldApproved.Has(id))..')')
 end
 local function fingerprint(model)
  local out={}
  for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then
   local p=d.CFrame.Position;local s=d.Size;local c=d.Color or{R=0,G=0,B=0}
   out[#out+1]=table.concat({d.ClassName,d.Name,d.Shape and d.Shape.Name or'-',('%.4f,%.4f,%.4f'):format(s.X,s.Y,s.Z),('%.4f,%.4f,%.4f'):format(p.X,p.Y,p.Z),
    ('%.3f,%.3f,%.3f'):format(c.R,c.G,c.B),d.Material and d.Material.Name or'-',('%.3f'):format(d.Transparency),('%.3f'):format(d.Reflectance or 0),tostring(d.CanQuery),
    tostring(d:GetAttribute('GrowthGroup')),tostring(d:GetAttribute('GrowthRole')),tostring(d:FindFirstChildOfClass('SpecialMesh')~=nil),tostring(d:FindFirstChildOfClass('Decal')~=nil)},'|')
  end end
  return out
 end
 local compared,total=0,0
 for _,id in ipairs({'SunflowerSeed','AppleSeed','MoonflowerSeed','PrismOrchidSeed','CactusSeed','DatePalmSeed','LavaLotusSeed','SolarStarfruitSeed','AncientWorldrootSeed'})do
  local d=Catalog[id]
  if d then
   local c={Id='old-'..id,SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1.3,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
   for _,variant in ipairs({{'growing',.6,nil},{'ripe',1,4}})do
    local now=d.Seconds*variant[2]
    local okN,a=pcall(function()return variant[3]and Visuals.Build(id,origin,c,4,math.huge)or Visuals.BuildGrowing(id,origin,c,now)end)
    local okO,b=pcall(function()return variant[3]and OldVisuals.Build(id,origin,c,4,math.huge)or OldVisuals.BuildGrowing(id,origin,c,now)end)
    if check(okN==okO,id..' '..variant[1]..': builds the same way before and after ('..tostring(okN)..'/'..tostring(okO)..')')and okN then
     local fa,fb=fingerprint(a),fingerprint(b);local same=#fa==#fb
     if same then for i=1,#fa do if fa[i]~=fb[i]then same=false;print('  first difference:\n   '..fa[i]..'\n   '..fb[i]);break end end end
     check(same and #fa>0,id..' '..variant[1]..': '..#fa..' parts, identical before and after')
     compared+=1;total+=#fa;print(('  existing plant %s (%s): %d parts identical before / after'):format(id,variant[1],#fa))
    end
   end
  end
 end
 check(compared>=14,'at least seven existing plants compared in both modes ('..compared..' comparisons, '..total..' parts)')
 -- Fire Pepper cannot be built here (its baked meshes live in ServerStorage); before and after fail the same way
 local fireN=pcall(function()return Visuals.Build('FirePepperSeed',origin,crop('FirePepperSeed'),4,math.huge)end)
 local fireO=pcall(function()return OldVisuals.Build('FirePepperSeed',origin,crop('FirePepperSeed'),4,math.huge)end)
 check(fireN==fireO,'Fire Pepper: builds (or fails for want of the baked meshes) exactly as in the base ('..tostring(fireN)..')')
end

-- 5. The seeds ----------------------------------------------------------------------------------------------------------------------------------
do
 local holder=R.new('Model');holder.Parent=W.workspace
 local function visible(m)local n=0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;return n end -- (every part, the invisible root included: the plan's 42 / 69 / 46)
 local function box(m)local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
  for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')and d.Transparency<1 then
   local x,y,z,a,b,c,dd,e,f,g,h,i=d.CFrame:GetComponents();local ex=(math.abs(a)*d.Size.X+math.abs(b)*d.Size.Y+math.abs(c)*d.Size.Z)/2;local ey=(math.abs(dd)*d.Size.X+math.abs(e)*d.Size.Y+math.abs(f)*d.Size.Z)/2;local ez=(math.abs(g)*d.Size.X+math.abs(h)*d.Size.Y+math.abs(i)*d.Size.Z)/2
   lo[1]=math.min(lo[1],x-ex);hi[1]=math.max(hi[1],x+ex);lo[2]=math.min(lo[2],y-ey);hi[2]=math.max(hi[2],y+ey);lo[3]=math.min(lo[3],z-ez);hi[3]=math.max(hi[3],z+ez)
  end end
  return hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]
 end
 local function anim(m,kind)local n=0;for _,d in ipairs(m:GetDescendants())do if d:IsA('BasePart')and d:GetAttribute('SeedAnim')==kind then n+=1 end end;return n end
 local expect={DesertAloeSeed={42,'Rare',0,0},SandFruitSeed={69,'Legendary',2,0},FirePepperSeed={46,'Mythic',0,3}}
 local fx=R.new('Folder');fx.Parent=W.workspace
 for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed'})do
  local e=expect[id]
  local ok,m=pcall(SeedVisuals.Seed,{Id=id},1,CF(0,0,0),holder,1,nil,'None')
  check(ok and m,id..': the seed builds ('..tostring(not ok and m or'')..')')
  if ok then
   check(visible(m)==e[1],id..': '..e[1]..' seed parts ('..visible(m)..')')
   check(m:GetAttribute('SeedId')==id and m:GetAttribute('Rarity')==e[2],id..': the seed model carries its id and its rarity ('..tostring(m:GetAttribute('Rarity'))..')')
   check(anim(m,'Twinkle')==e[3]and anim(m,'Flicker')==e[4]and anim(m,'Pulse')==0,id..': SeedAnim Twinkle x'..e[3]..', Flicker x'..e[4])
   local sx,sy,sz=box(m);check(sx<=3.5 and sy<=3.5 and sz<=3.5,('%s: the seed is %.2f x %.2f x %.2f studs (true extents of its visible parts; the existing seeds are up to 3.12 high, 2.5 on average)'):format(id,sx,sy,sz))
   local motion=SeedVisuals.CreateSeedMotion(m,fx,true)
   if id=='DesertAloeSeed'then check(motion==nil or #motion.Anim==0,'Aloe (Rare): static, nothing animates')
   else
    local kind=id=='SandFruitSeed'and'Twinkle'or'Flicker'
    check(motion and #motion.Anim==e[3]+e[4],id..': Legendary and rarer seeds animate their signature parts ('..tostring(motion and #motion.Anim)..')')
    local allKind=motion~=nil;if motion then for _,a in ipairs(motion.Anim)do if a.Kind~=kind then allKind=false end end end
    check(allKind,id..': the animated parts are all '..kind..'s')
    if motion then local part=motion.Anim[1].Part;local before=part.CFrame.Position;motion:Update(CF(0,0,0),2.3,1,1);check((part.CFrame.Position-before).Magnitude<1e-6,id..': animation changes colour only (a held seed is never moved)');motion:Destroy()end
   end
  end
 end
 check(Sigs.Shape('DesertAloeSeed')=='Pointed'and Sigs.Shape('SandFruitSeed')=='Round'and Sigs.Shape('FirePepperSeed')=='Bean','seed bodies: Aloe Pointed, Sand Fruit Round, Fire Pepper Bean (unchanged)')
 check(Sigs.Get('DesertAloeSeed')and Sigs.Get('SandFruitSeed')and Sigs.Get('SandFruitSeed').Pattern=='None'and Sigs.Get('FirePepperSeed'),'signatures: Aloe, Sand Fruit (its Stripes pattern is replaced by its ripple lines), Fire Pepper')
 -- coats and a held build
 for _,coat in ipairs({'Gold','Diamond'})do for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed'})do
  local ok=pcall(SeedVisuals.Seed,{Id=id},1,CF(0,0,0),holder,1,nil,coat);check(ok,id..': the '..coat..' coat builds')
 end end
 local hand=R.new('Part');hand.Anchored=false;hand.Parent=W.workspace
 for _,id in ipairs({'DesertAloeSeed','SandFruitSeed','FirePepperSeed'})do local ok=pcall(SeedVisuals.Seed,{Id=id},1,CF(0,0,0),holder,1,hand,'None');check(ok,id..': a held (welded) seed builds')end
end

-- 6. Rarity effects ---------------------------------------------------------------------------------------------------------------------------------
do

 R.clock=1e6 -- (workspace:GetServerTimeNow): every crop below is ripe
 local function effects(id)
  local def=Catalog[id];local c=crop(id);local item=R.new('Model');item:SetAttribute('FruitReady',true);item.Parent=W.workspace
  local visual=R.new('Model');visual.Parent=item;local r={Visual=visual,Origin=origin,Selection={}}
  local ok,err=pcall(Effects.Create,item,r,def,c,origin,'normal')
  return ok,err,r,Effects.Profile(def,id)
 end
 for _,id in ipairs({'SandFruitSeed','MoonflowerSeed','FirePepperSeed'})do
  local ok,err,r=effects(id)
  check(ok,id..': PlantEffects builds ('..tostring(err)..')')
  check(r.Aura~=nil and r.Effects and r.Effects:GetAttribute('AuraRank')==Packs.Rarities[Catalog[id].Rarity].Rank and Packs.Rarities[Catalog[id].Rarity].Rank>=4,id..': the rarity aura (rank '..tostring(r.Effects and r.Effects:GetAttribute('AuraRank'))..': '..Catalog[id].Rarity..')')
 end
 local _,_,rAloe=effects('DesertAloeSeed')
 check(rAloe.Aura==nil and rAloe.Effects==nil,'Aloe (Rare, no Desert profile): no aura and no effects, like Prickly Pear')
 local _,_,rPear=effects('CactusSeed');check(rPear.Effects==nil,'(Prickly Pear: none either)')
 check(Effects.Profile(Catalog.MoonflowerSeed,'MoonflowerSeed')=='Moon'and Effects.Profile(Catalog.FirePepperSeed,'FirePepperSeed')=='Ember'and Effects.Profile(Catalog.SandFruitSeed,'SandFruitSeed')==nil and Effects.Profile(Catalog.DesertAloeSeed,'DesertAloeSeed')==nil,
  'profiles: Moon Melon keeps its Moon motes, Fire Pepper its Lava embers, the Desert pair has none')
 local _,_,rFire=effects('FirePepperSeed');check(rFire.Effects:GetAttribute('EffectTheme')=='Ember','Fire Pepper: the Mythic aura plus the Lava embers')
end

-- 7. The Index ----------------------------------------------------------------------------------------------------------------------------------------
do
 local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=5;player.Parent=Players;Players.LocalPlayer=player
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 local remotes=R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 local catalog=R.new('Folder');catalog.Name='SeedCatalog';catalog.Parent=remotes
 local req=R.new('RemoteFunction');req.Name='PremiumRequest';req.Parent=remotes
 local calls={};function req.InvokeServer(_,action,value)calls[#calls+1]={action,value};return {Success=true,Message='Claimed!'}end
 local config={SeedCatalogByStage=Packs.BuildSeedCatalog()}
 local expectOdds={}
 for _,stage in ipairs({1,6,2,3,4,5,7})do
  local odds=Packs.SeedOdds(config,stage,'Pack01',1)
  for _,seed in ipairs(Packs.ObtainablePool(config,stage))do
   local slot;for i,s in ipairs(config.SeedCatalogByStage[Packs.ObtainableStage(seed.Id)or stage])do if s.Id==seed.Id then slot=i end end
   local e=R.new('Folder');e.Name=seed.Id
   e:SetAttribute('SeedId',seed.Id);e:SetAttribute('DisplayName',seed.Name);e:SetAttribute('Rarity',(Packs.GetRarity(seed.Id)))
   e:SetAttribute('Stage',stage);e:SetAttribute('SeedIndex',slot or 1);e:SetAttribute('BaseChance',odds[seed.Id]);e.Parent=catalog
   expectOdds[seed.Id]=W.module('OddsText85').Format(odds[seed.Id])
  end
 end
 local seeds=R.new('Folder');seeds.Name='DiscoveredSeeds';seeds.Parent=player
 local plants=R.new('Folder');plants.Name='DiscoveredPlants';plants.Parent=player
 local function found(folder,id)local v=R.new('BoolValue');v.Name=id;v.Value=true;v.Parent=folder end
 -- A player who completed the OLD five-seed Desert (every seed found and grown) and has claimed nothing.
 for _,id in ipairs({'CactusSeed','DatePalmSeed','MirageFigSeed','SolarStarfruitSeed','StarfruitSeed'})do found(seeds,id);found(plants,id)end
 local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
 W.frames(10)
 local gui=pg:FindFirstChild('ChestIndexGui');local toggle=pg:FindFirstChild('IndexButton',true)
 local desert=gui:FindFirstChild('Biome2',true);local forest=gui:FindFirstChild('Biome1',true)
 local function shown(b)return b and b.Visible and b.Count.Text or nil end
 check(desert and desert:FindFirstChild('RewardDot')and desert.RewardDot.Visible and not(forest:FindFirstChild('RewardDot')and forest.RewardDot.Visible),'old 5/5 Desert: the Desert tab has its reward dot (Forest has none)')
 check(shown(toggle:FindFirstChild('RewardBadge'))=='2','INDEX shows 2: the halfway gems and the completion gems of the old roster ('..tostring(shown(toggle:FindFirstChild('RewardBadge')))..')')
 pg:SetAttribute('SeedMenu','Index');W.frames(20)
 desert.Activated:Fire();W.frames(10)
 local list=gui:FindFirstChild('SeedCards',true)
 local cards={};for _,c in ipairs(list:GetChildren())do if c:IsA('TextButton')then cards[#cards+1]=c end end
 table.sort(cards,function(a,b)return a.LayoutOrder<b.LayoutOrder end)
 check(#cards==7,'the Desert tab shows seven cards ('..#cards..')')
 local order,sorted={},true
 for i,c in ipairs(cards)do local rar=catalog[c.Name]:GetAttribute('Rarity');order[i]=c.Name..':'..rar;if i>1 and Packs.Rarities[rar].Rank<Packs.Rarities[catalog[cards[i-1].Name]:GetAttribute('Rarity')].Rank then sorted=false end end
 check(sorted and cards[1].Name=='CactusSeed'and cards[2].Name=='DesertAloeSeed'and cards[3].Name=='SandFruitSeed'and cards[4].Name=='DatePalmSeed','cards run Uncommon, Rare, Legendary, Mythic ... King: '..table.concat(order,' '))
 local okOdds,okRarity=true,true
 for _,c in ipairs(cards)do
  local odds=c:FindFirstChild('OddsChip')and c.OddsChip:FindFirstChild('Odds');if not odds or odds.Text~=expectOdds[c.Name]then okOdds=false end
  local r=c:FindFirstChild('RarityChip')and c.RarityChip:FindFirstChild('Rarity');if not r or r.Text~=string.upper(catalog[c.Name]:GetAttribute('Rarity'))then okRarity=false end
 end
 check(okOdds and okRarity and list.DesertAloeSeed.OddsChip.Odds.Text=='1/8'and list.SandFruitSeed.OddsChip.Odds.Text=='1/90','every Desert card shows its rarity and its chance (Aloe 1/8, Sand Fruit 1/90)')
 check(list.DesertAloeSeed.RarityChip.Rarity.Text=='RARE'and list.SandFruitSeed.RarityChip.Rarity.Text=='LEGENDARY','Aloe RARE, Sand Fruit LEGENDARY')
 check(list.DesertAloeSeed:FindFirstChild('Name').Text=='???'and list.SandFruitSeed:FindFirstChild('Name').Text=='???','the new seeds start as ??? until found')
 local middle=gui:FindFirstChild('MiddleGem',true);local endGem=gui:FindFirstChild('GemReward',true)
 check(middle:GetAttribute('RewardReady')==true and middle.Active and endGem:GetAttribute('RewardReady')==true and endGem.Active,'old 5/5 Desert: both claim gems are lit and can be pressed (nothing is taken away)')
 check(gui:FindFirstChild('Progress',true)==nil or true,'(the bar counts the live roster: 5 of 7 seeds, 5 of 7 plants)')
 local progress;for _,d in ipairs(gui:GetDescendants())do if d:IsA('TextLabel')and d.Text:find('SEEDS')and d.Text:find('PLANTS')then progress=d.Text end end
 check(progress and progress:find('5/7 SEEDS',1,true)and progress:find('5/7 PLANTS',1,true),'the progress text reads the live roster: '..tostring(progress))
 middle.Activated:Fire();W.frames(3)
 check(calls[1]and calls[1][1]=='ClaimBiomeHalf'and calls[1][2]==2,'pressing the halfway gem claims category 2')
 player:SetAttribute('IndexBiomeHalfReward2',true);W.frames(5)
 check(shown(toggle.RewardBadge)=='1'and desert.RewardDot.Visible,'after the halfway claim: one reward left')
 endGem.Activated:Fire();W.frames(3)
 check(calls[2]and calls[2][1]=='ClaimBiome'and calls[2][2]==2,'pressing the completion gem claims category 2')
 player:SetAttribute('IndexBiomeReward2',true);W.frames(5)
 check(not toggle.RewardBadge.Visible and not desert.RewardDot.Visible and middle:GetAttribute('RewardClaimed')==true and endGem:GetAttribute('RewardClaimed')==true,'both claimed: no badge, no dot, both gems show claimed')
 -- A player who claimed before the update: found five of the old seeds, claimed both: nothing lights up.
 check(middle:GetAttribute('RewardReady')==false and endGem:GetAttribute('RewardReady')==false,'a claimed reward does not light up again (no duplicate claim) although 5 / 7 is not complete now')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
