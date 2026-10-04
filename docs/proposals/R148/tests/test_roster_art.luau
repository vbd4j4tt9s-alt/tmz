--!nocheck
-- R148 (owner): the art of the seed roster change on the Roblox mock with the REAL modules (DesertPlantArt149, ApprovedPlantArt, PlantVisuals,
-- PlantGrowth, PlantEffects, SeedPackVisuals, SeedSignatures, ChestIndex): Desert's Rare Aloe (blue-green rosette, three red-orange flower spikes)
-- and Legendary Sand Fruit (a ROUND barrel cactus built from the game's own cactus pieces, four lumpy Enum.Material.Sand fruits growing out of
-- its shoulders), the Mythic Fire Pepper at twice the size, and the growth variations: the Aloe and the Sand Fruit each have FOUR designs, picked per
-- crop by a hash of its id (ApprovedPlantArt) plus the usual size / turn jitter, like the approved plants (Fire Pepper keeps its own, at x2).
--  1. the art lists, for each of the 4 designs of both plants: the part counts (Aloe 127 / 128 / 126 / 124, Sand Fruit 95 / 88 / 100 / 94), every group present, roles, nothing under the soil, sockets / centres / radii / Height / Radius = the catalog;
--  2. every build mode: ripe, growing at body .1 / .5 / .9, one harvest item per group, the distant supports (no collision: a cactus is not a tree), the
--     harvested fruit, and no floating part anywhere (the scene goes through check_floating.py, R134);
--  3. Fire Pepper: every spec of the base's art x2 (position and size; rotation untouched), for every crop variant; Prism Pepper unchanged;
--  4. existing plants unchanged against the base commit's pipeline (PlantVisualsBase / PlantGrowthBase / ApprovedPlantArtBase, from git);
--  5. the three seeds (48 / 58 / 46 parts; Twinkle x2 on the Sand Fruit, Flicker x3 on Fire Pepper, nothing on the Rare Aloe);
--  6. the rarity effects (aura on the Sand Fruit, Moon Melon, Fire Pepper; none on the Aloe);
--  7. the Index: the Desert tab shows seven cards in rarity order; the old 5-seed roster counts ONLY through the server's saved flags
--     (IndexOldHalf2 / IndexOldFull2): without them five of seven is halfway and not complete, with them an old completer sees the reward dot and
--     lit claim buttons, and a claimed reward stays claimed;
--  2b. the variants per crop: determinism (the same crop id always shows the same design, everywhere), the spread over many crop ids, the jitter, the
--     catalog's bounds, harvest positions, regrow of every fruit of every design at several fractions, and Fire Pepper's x2 variants;
--  8. the effect slots (every plant of rank 4+ wears a Highlight aura; Roblox draws 31 in all): by rarity rank first, then distance.
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
-- Which design / size jitter a crop id gets is decided by ApprovedPlantArt.Key (":d<design>:<jitter digit>"); the tests look crop ids up through it.
local function keyOf(id,cid)local d,j=Approved.Key(id,{Id=cid}):match(':d(%d):(%d)$');return tonumber(d),tonumber(j)end
local picked={}
-- a crop id of design `design` whose jitter digit is `jitter` (4 and 5 mean no size change and no turn) and whose fruits are all at the plain size (the fruit size is a
-- per-crop trait, PlantRules.Fruit: a lucky crop's fruits are bigger, which would move the highest point)
local function pick(id,design,jitter)
 local slot=id..'/'..design..'/'..tostring(jitter);if picked[slot]then return picked[slot]end
 for n=1,20000 do local cid='pick'..n;local d,j=keyOf(id,cid)
  if d==design and(jitter==nil or j==jitter)then
   local plain=true;local c=crop(id,{Id=cid});for g=1,Catalog[id].FruitCount do if Rules.Fruit(c,g,Catalog[id]).Scale~=1 then plain=false end end
   if plain then picked[slot]=cid;return cid end
  end
 end
 error('no crop id for '..slot)
end
local function parts(model,visibleOnly)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d.Name~='VisualPivot'and(not visibleOnly or d.Transparency<1)then out[#out+1]=d end end;return out end
-- The lowest and highest point of a part in the plant's frame (a rotated box's real extent).
local function extent(d)
 local x,y,z,a,b,c,dd,e,f,g,h,i=d.CFrame:GetComponents();local ey=(math.abs(dd)*d.Size.X+math.abs(e)*d.Size.Y+math.abs(f)*d.Size.Z)/2
 return y-ey,y+ey
end
local function specExtent(s)local c,z=s.c,s.z;local ey=(math.abs(c[7])*z[1]+math.abs(c[8])*z[2]+math.abs(c[9])*z[3])/2;return c[2]-ey,c[2]+ey end

-- 1. The art lists --------------------------------------------------------------------------------------------------------------------------
local want={
 DesertAloeSeed={{specs=127,groups={[0]=49,26,26,26},height=8.261,radius=5.211},{specs=128,groups={[0]=47,27,27,27},height=9.822,radius=5.485},
  {specs=126,groups={[0]=57,23,23,23},height=7.096,radius=5.169},{specs=124,groups={[0]=49,25,25,25},height=8.742,radius=5.271}},
 SandFruitSeed={{specs=95,groups={[0]=79,4,4,4,4},height=10.607,radius=6.777},{specs=88,groups={[0]=72,4,4,4,4},height=13.979,radius=5.417},
  {specs=100,groups={[0]=84,4,4,4,4},height=9.079,radius=8.075},{specs=94,groups={[0]=78,4,4,4,4},height=12.238,radius=6.614}}}
for _,id in ipairs(IDS)do for d=1,4 do want[id][d].cost=want[id][d].specs+1 end end
local function digestOf(art)
 local out={}
 for _,s in ipairs(art.Specs)do out[#out+1]=table.concat({s.s,s.f,s.g,s.r,s.m,table.concat(s.k,','),string.format('%.4f,%.4f,%.4f',s.z[1],s.z[2],s.z[3]),string.format('%.4f,%.4f,%.4f',s.c[1],s.c[2],s.c[3])},'|')end
 return table.concat(out,'\n')
end
for _,id in ipairs(IDS)do
 local def=Catalog[id];local designs=Art.Designs(id);local digests={}
 check(#designs==4 and Art.DesignCount==4 and Approved.Has(id)==true and Art.Is(id)==true and Art.Get(id)==designs[1]and Approved.Get(id)==designs[1]and Approved.Design(id)==1,
  id..': four designs; ApprovedPlantArt routes to DesertPlantArt149; design 1 is the base design (what a preview / a crop without an id shows)')
 for d=1,4 do
  local w=want[id][d];local art=designs[d];local tag=id..' design '..d
  check(art.RarityRework==true,tag..': a RarityRework spec list')
  check(#art.Specs==w.specs and #art.Specs<=130,tag..': '..w.specs..' art parts, at most 130 ('..#art.Specs..')')
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
  check(okShape and okRole and okNums,tag..': every part has a known shape, a role (body Leaf / Stem, fruit groups Fruit), 12 + 3 + 3 numbers, p = 1')
  local counts={};for g=0,def.FruitCount do counts[#counts+1]=groups[g]or 0 end
  local wantCounts={};for g=0,def.FruitCount do wantCounts[#wantCounts+1]=w.groups[g]end
  check(table.concat(counts,',')==table.concat(wantCounts,',')and groups[def.FruitCount+1]==nil,tag..': groups 0..'..def.FruitCount..' hold '..table.concat(counts,' / ')..' parts: FruitCount '..def.FruitCount..' kept, no stray group')
  check(lowest>=-.05,('%s: nothing below the soil (lowest %.4f)'):format(tag,lowest))
  check(cost==w.specs and Visuals.Metadata(id,crop(id,{Id=pick(id,d,4)})).Cost==w.cost,tag..': detail cost '..w.cost..' = one per part plus the plant itself (PlantDetailPlanner screen budget is 1400)')
  check(near(art.Height,w.height,1e-9)and near(art.Radius,w.radius,1e-9),tag..': Height '..w.height..' / Radius '..w.radius)
  check(#art.Sockets==def.FruitCount and #art.FruitCenters==def.FruitCount and #art.FruitRadii==def.FruitCount,tag..': its own Sockets / FruitCenters / FruitRadii, one per fruit')
  -- the farthest reach of the parts is the Radius, the highest point the Height (each design's bounds are its own)
  local top,reach=-math.huge,0
  for _,s in ipairs(art.Specs)do local _,hi=specExtent(s);top=math.max(top,hi);local ex=(math.abs(s.c[4])*s.z[1]+math.abs(s.c[5])*s.z[2]+math.abs(s.c[6])*s.z[3])/2;local ez=(math.abs(s.c[10])*s.z[1]+math.abs(s.c[11])*s.z[2]+math.abs(s.c[12])*s.z[3])/2
   reach=math.max(reach,math.sqrt(s.c[1]^2+s.c[3]^2)+math.max(ex,ez))end
  check(near(top,art.Height,.001)and near(reach,art.Radius,.001),('%s: the highest point %.3f and the widest reach %.3f are the Height and Radius'):format(tag,top,reach))
  -- every fruit group keeps its parts around its own fruit centre (the group is what a harvest picks up)
  local near_=true
  for g=1,def.FruitCount do
   local c=V3(table.unpack(art.FruitCenters[g]));local rad=art.FruitRadii[g]
   local hits=0;for _,s in ipairs(art.Specs)do if s.g==g then hits+=1;local dd=(V3(s.c[1],s.c[2],s.c[3])-c).Magnitude;if dd>rad*2.2 then near_=false end end end
   if hits==0 then near_=false end
  end
  check(near_,tag..': every group\'s parts stay within 2.2 fruit radii of its fruit centre (so the harvest glints and picking sit on the fruit)')
  check(neon==0,tag..': no Neon part (the sand fruit is textured by Enum.Material.Sand, the aloe is plain)')
  digests[#digests+1]=digestOf(art)
 end
 local distinct=true;for a=1,4 do for b=a+1,4 do if digests[a]==digests[b]then distinct=false end end end
 check(distinct,id..': the four designs are different (no two share a part list)')
 -- the catalog: the sockets are design 1's; the bounds are the biggest design's with the approved plants' 5% margin (Fire Pepper: 6.009 x 1.05 x 2)
 local maxH,maxR=0,0;for _,a in ipairs(designs)do maxH=math.max(maxH,a.Height);maxR=math.max(maxR,a.Radius)end
 check(near(def.Height,maxH*1.05,1e-9)and near(def.Radius,maxR*1.05,1e-9)and def.AuthoredHeight==def.Height,('%s: catalog Height %.3f / Radius %.3f = the biggest design x 1.05 (%.3f / %.3f)'):format(id,def.Height,def.Radius,maxH,maxR))
 local meta=true;local art=designs[1]
 for i=1,def.FruitCount do for k=1,3 do meta=meta and near(def.Sockets[i][k],art.Sockets[i][k],1e-12)and near(def.FruitCenters[i][k],art.FruitCenters[i][k],1e-12)end;meta=meta and def.FruitRadii[i]==art.FruitRadii[i]end
 check(meta and #def.Sockets==def.FruitCount,id..': the catalog\'s Sockets / FruitCenters / FruitRadii are design 1\'s, one per fruit')
end
-- Colours and shapes of the design.
-- The existing pieces the cactus is built from, read from the game's own art (so the test follows them if they change).
local function piece(art,name)for _,sp in ipairs(art.Specs or art[1]and art[1].Specs or{})do if sp.f==name then return sp end end end
local ExistingStem=piece(W.module('ApprovedPlantArt6'),'Rectangular cactus stem');local ExistingRib=piece(W.module('AgaveSeedArt45'),'Cactus rib')
local ExistingSpine=piece(W.module('AgaveSeedArt45'),'Ivory spine');local ExistingAttach=piece(W.module('ApprovedPlantArt6'),'Upper surface fruit attachment')
do
 check(ExistingStem and ExistingRib and ExistingSpine and ExistingAttach,'(the existing cactus art is there: the Prickly Pear stem, the Crown Cactus rib and ivory spine, the Prickly Pear fruit attachment)')
 local a=Approved.Get('DesertAloeSeed');local heart,leaves,spots,teeth,stalks,buds=0,0,0,0,0,0;local perSpike={};local leafColours={}
 for _,s in ipairs(a.Specs)do
  if s.f=='Rosette heart'then heart+=1;check(kIs(s.k,48,134,114)and s.s=='Ball','Aloe: the rosette heart is a rich blue-green Ball (48,134,114)')end
  if s.f=='Aloe leaf'then leaves+=1;leafColours[table.concat(s.k,',')]=true;check(s.s=='Wedge'and s.r=='Leaf'and s.g==0,'Aloe: leaves are Wedge pairs in the body')end
  if s.f=='Aloe leaf spot'then spots+=1;check(kIs(s.k,214,236,222),'Aloe: cream leaf spots (214,236,222)')end
  if s.f=='Aloe leaf tooth'then teeth+=1;check(kIs(s.k,200,92,60),'Aloe: red-brown teeth (200,92,60)')end
  if s.f=='Aloe flower stalk'then stalks+=1;check(s.s=='Cylinder'and s.r=='Fruit'and s.g>=1 and s.g<=3 and kIs(s.k,112,150,92),'Aloe: each flower stalk is a Fruit-role Cylinder (not Stem: a held spike must keep its florets)')end
  if s.f=='Aloe floret'then perSpike[s.g]=perSpike[s.g]or{};table.insert(perSpike[s.g],s.k)end
  if s.f=='Aloe bud tip'then buds+=1 end
  check(s.m=='SmoothPlastic'and s.tx==nil,'Aloe: SmoothPlastic, no textures')
 end
 check(heart==1 and leaves==34 and spots==7 and teeth==7 and stalks==3 and buds==3,('Aloe: 1 heart, 34 leaf wedges (17 leaves), 7 spots, 7 teeth, 3 stalks, 3 bud tips (%d %d %d %d %d %d)'):format(heart,leaves,spots,teeth,stalks,buds))
 check(leafColours['42,124,110']and leafColours['56,142,124']and leafColours['64,160,138']and leafColours['80,178,152'],'Aloe: richer blue-green leaves (42,124,110 ... 80,178,152)')
 -- OWNER (R148 feedback): many more florets on each spike, full and vibrant: 24 per spike (it was 9), red at the bottom grading to yellow at the tip
 local dense=true
 for g=1,3 do
  local list=perSpike[g]or{};if #list~=24 then dense=false;continue end
  local lo,hi=list[1],list[#list]
  check(lo[1]>=220 and lo[2]<=60 and lo[3]<=40,'Aloe spike '..g..': the lowest floret is a deep red ('..table.concat(lo,',')..')')
  check(hi[1]==255 and hi[2]>=215 and hi[3]>=80,'Aloe spike '..g..': the top floret is yellow ('..table.concat(hi,',')..')')
  local warm,graded=true,true
  for i,k in ipairs(list)do if k[1]<220 or k[3]>110 then warm=false end;if i>1 and k[2]<list[i-1][2]then graded=false end end
  check(warm and graded,'Aloe spike '..g..': every floret is saturated (red >= 220, blue <= 110) and the green only rises up the spike')
 end
 check(dense,'Aloe: 24 florets on every one of the three spikes (72 in all)')
 local p=Approved.Get('SandFruitSeed');local count={}
 for _,s in ipairs(p.Specs)do
  count[s.f]=(count[s.f]or 0)+1
  if s.f=='Cactus body'then check(s.s=='Ball'and s.r=='Stem'and s.g==0 and kIs(s.k,ExistingStem.k[1],ExistingStem.k[2],ExistingStem.k[3])and s.m==ExistingStem.m and near(s.z[1],10.8)and near(s.z[2],9.4)and near(s.z[3],10.8)and near(s.c[2],4.7),'Cactus: a round Ball body 10.8 x 9.4 x 10.8 standing on the soil, in the Prickly Pear\'s own stem green')end
  if s.f=='Cactus pup'then check(s.s=='Ball'and kIs(s.k,ExistingStem.k[1],ExistingStem.k[2],ExistingStem.k[3]),'Cactus: the pups are round too, the same green')end
  if s.f=='Cactus rib'then check(s.s=='Cylinder'and s.r=='Stem'and s.g==0 and kIs(s.k,ExistingRib.k[1],ExistingRib.k[2],ExistingRib.k[3])and s.m==ExistingRib.m,'Cactus: ribs are the Crown Cactus\' rib colour and material')end
  if s.f=='Ivory spine'then check(s.s=='Wedge'and s.r=='Stem'and kIs(s.k,ExistingSpine.k[1],ExistingSpine.k[2],ExistingSpine.k[3])and s.m==ExistingSpine.m and near(s.z[1],ExistingSpine.z[1]*1.5)and near(s.z[2],ExistingSpine.z[2]*1.5),'Cactus: ivory spines are the Crown Cactus\' Wedge (colour, material, shape), 1.5x for this body')end
  if s.f=='Fruit stem'then check(s.s=='Cylinder'and s.r=='Fruit'and s.g>=1 and s.g<=4 and kIs(s.k,ExistingAttach.k[1],ExistingAttach.k[2],ExistingAttach.k[3]),'Cactus: each fruit hangs on the Prickly Pear\'s fruit-attachment green')end
  if s.f=='Sand fruit'then check(s.s=='Ball'and s.r=='Fruit'and s.g>=1 and s.g<=4 and s.m=='Sand'and s.k[1]>=210 and s.k[2]>=175 and s.k[3]>=105 and s.k[3]<=150 and(s.z[1]~=s.z[2]or s.z[2]~=s.z[3])and s.z[2]<s.z[1],'Sand fruit: a squashed Ball in Enum.Material.Sand and a sand colour ('..table.concat(s.k,',')..')')end
  if s.f=='Sand fruit lump'or s.f=='Sand fruit nub'then check(s.s=='Ball'and s.r=='Fruit'and s.m=='Sand','Sand fruit: the lump and the nub are Sand too')end
 end
 check(count['Cactus body']==1 and count['Cactus pup']==2 and count['Cactus rib']==40 and count['Ivory spine']==36 and count['Fruit stem']==4 and count['Sand fruit']==4 and count['Sand fruit lump']==4 and count['Sand fruit nub']==4,
  ('Cactus: 1 body, 2 pups, 40 ribs (8 x 5), 36 ivory spines, and 4 x (stem, sand fruit, lump, nub) (%s)'):format(table.concat((function()local o={};for k,v in pairs(count)do o[#o+1]=k..'='..v end;table.sort(o);return o end)(),' ')))
 -- the fruits grow out of the shoulders: sockets on the body's surface, centres just outside it on the upper half, between the ribs
 local onSurface,onShoulder=true,true
 for g=1,4 do
  local so,ce=p.Sockets[g],p.FruitCenters[g]
  local e=(so[1]/5.4)^2+((so[2]-4.7)/4.7)^2+(so[3]/5.4)^2
  if math.abs(e-1)>1e-6 then onSurface=false end
  local d=math.sqrt((ce[1]-so[1])^2+(ce[2]-so[2])^2+(ce[3]-so[3])^2)
  if not(near(d,.92,.01)and ce[2]>4.7+2.5)then onShoulder=false end
 end
 check(onSurface and onShoulder and p.FruitRadii[1]==1.15,'Cactus: the four sockets are on the body\'s surface, the fruit centres .92 outside it on the upper half, radius 1.15')
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
for _,id in ipairs(IDS)do for d=1,4 do
 local def=Catalog[id];local w=want[id][d];local art=Art.Designs(id)[d];local cid=pick(id,d,4);local tag=id..' design '..d
 local crop=function(i,extra)local e=table.clone(extra or{});e.Id=e.Id or cid;return crop(i,e)end -- (this design's crop: no size change, no turn)
 check(PG.Profile(id,def)=='Bush',tag..': grows with the Bush profile (generic growth: no per-stage art is needed)')
 -- ripe
 local m=Visuals.Build(id,origin,crop(id),4,math.huge)
 local base=m:FindFirstChild('PlantBase');local kids={}
 for g=1,def.FruitCount do kids[g]=m:FindFirstChild('Harvest_'..g)end
 local counts={};for g=1,def.FruitCount do local n=0;if kids[g]then for _,d in ipairs(kids[g]:GetDescendants())do if d:IsA('BasePart')then n+=1 end end end;counts[g]=n end
 local baseCount=0;for _,d in ipairs(base:GetDescendants())do if d:IsA('BasePart')then baseCount+=1 end end
 check(baseCount==w.groups[0]and table.concat(counts,',')==(id=='DesertAloeSeed'and(w.groups[1]..','..w.groups[2]..','..w.groups[3])or'4,4,4,4'),tag..': ripe: PlantBase '..w.groups[0]..' parts and one Harvest_N model per fruit group ('..table.concat(counts,'/')..')')
 check(#parts(m)==w.specs and #parts(m,true)==w.specs,tag..': ripe: all '..w.specs..' parts built and visible')
 local queryOk=true;for g=1,def.FruitCount do for _,d in ipairs(kids[g]:GetDescendants())do if d:IsA('BasePart')and not d.CanQuery then queryOk=false end end end
 for _,d in ipairs(base:GetDescendants())do if d:IsA('BasePart')and d.CanQuery then queryOk=false end end
 check(queryOk,tag..': ripe: every fruit part can be queried (harvest prompt), no body part can')
 local lo,hi=math.huge,-math.huge;for _,d in ipairs(parts(m))do local a,b=extent(d);lo=math.min(lo,a);hi=math.max(hi,b)end
 check(lo>=-.0501 and near(hi,w.height,.002),('%s: ripe: lowest %.4f (no part under the soil), highest %.3f = Height'):format(tag,lo,hi))
 addScene(tag..' ripe',m)
 -- growing at body .1 / .5 / .9 (and the ends): grows monotonically, fruit appears after the body, the finished plant is the ripe one
 local lastTop,monotonic=-1,true;local lines={}
 for _,f in ipairs({0,.1,.3,.5,.7,.9,1})do
  local g=Visuals.BuildGrowing(id,origin,crop(id),f*def.Seconds)
  local vis=parts(g,true);local glo,ghi=math.huge,-math.huge;local fruitVisible=0
  for _,d in ipairs(vis)do local a,b=extent(d);glo=math.min(glo,a);ghi=math.max(ghi,b);if d.Parent and d.Parent.Name:find('Harvest_')then fruitVisible+=1 end end
  if ghi<lastTop-1e-6 then monotonic=false end;lastTop=ghi
  lines[#lines+1]=('%d%%: %d visible, top %.2f'):format(f*100,#vis,ghi)
  check(glo>=-.0501,('%s growing %d%%: nothing under the soil (%.4f)'):format(tag,f*100,glo))
  check(#parts(g)<=w.specs+20,('%s growing %d%%: %d parts in all (the %d art parts plus the generic growth pieces)'):format(tag,f*100,#parts(g),w.specs))
  if f==0 then check(#vis==1,tag..': 0%: only the new seed shows ('..#vis..')')end
  if f==.1 then check(fruitVisible==0 and ghi<1,tag..': 10%: a sprout, no fruit yet (top '..ghi..')')end
  if f==.5 then check(ghi<w.height*.75,tag..': 50%: still growing (top '..ghi..' of '..w.height..')')end
  if f==.9 then check(fruitVisible>0 and ghi>w.height*.5,tag..': 90%: the fruit is showing, the body nearly done (top '..ghi..')')end
  if f==1 then check(#vis==w.specs and near(ghi,w.height,.002),tag..': 100%: the whole '..w.specs..'-part plant, Height '..w.height)end
  if f==.3 or f==.7 then addScene(tag..' growing '..f*100 ..'%',g)end
 end
 print(tag..' growth: '..table.concat(lines,' | '))
 check(monotonic,tag..': the plant only ever gets taller as it grows')
 -- the harvest of one group: a stalk with its fruits, never the body
 for g=1,def.FruitCount do
  local item=Visuals.BuildSelectedFruit(id,origin,crop(id),{[g]=true},math.huge)
  local ps=parts(item);local ok=#ps==w.groups[g]
  for _,d in ipairs(ps)do local gAttr=d.Parent and d.Parent:GetAttribute('HarvestIndex');if gAttr~=g then ok=false end end
  check(ok,tag..': harvest item '..g..': '..w.groups[g]..' parts, all from group '..g)
  local detached=Visuals.BuildSelectedFruit(id,origin,crop(id,{_DetachedHarvest=true}),{[g]=true},math.huge)
  -- held in the hand: the Aloe keeps its whole spike (its stalk is a Fruit part, not a Stem); the sand fruit drops only its green attachment
  -- ('Fruit stem' is one of the game's connector names), leaving the sand ball with its lump and nub: "harvested fruit = that sand ball"
  local keep=id=='SandFruitSeed'and w.groups[g]-1 or w.groups[g]
  check(#parts(detached)==keep,tag..': harvest item '..g..' (detached, as held in the hand): '..keep..' parts'..(id=='SandFruitSeed'and' (the sand ball, its lump and its nub)'or' (nothing dropped)'))
  local specOk=true;for _,s in ipairs(art.Specs)do if s.g==g and not Visuals.HarvestSpec(id,s)and s.f~='Fruit stem'then specOk=false end end
  check(specOk,tag..': HarvestSpec keeps every part of group '..g..(id=='SandFruitSeed'and' except the attachment'or''))
  if g==1 or g==def.FruitCount then addScene(tag..' harvest item '..g,item);addScene(tag..' held item '..g,detached)end
 end
 -- distant supports: the body only; nothing collides (neither is a tree: a cactus never blocks planting)
 local sup=R.new('Model');Visuals.Supports(id,origin,crop(id),4,sup)
 local sp,collide,collideCost=parts(sup),0,0
 for _,d in ipairs(sp)do if d.CanCollide then collide+=1;collideCost+=1 end end
 check(#sp==w.groups[0],tag..': supports: the '..w.groups[0]..' body parts ('..#sp..')')
 check(collide==0 and Catalog[id].Tree==false,tag..': supports: nothing collides (not a tree)')
 local grow=R.new('Model');Visuals.GrowingSupports(id,origin,crop(id),1,grow,.5*def.Seconds)
 check(#parts(grow)>0,tag..': the distant growing path builds ('..#parts(grow)..' parts)')
 -- a scaled plant (PlantScale 2) scales every part and keeps the ground
 local big=Visuals.Build(id,origin,crop(id,{PlantScale=2}),4,math.huge);local blo,bhi=math.huge,-math.huge
 for _,d in ipairs(parts(big))do local a,b=extent(d);blo=math.min(blo,a);bhi=math.max(bhi,b)end
 check(blo>=-.1 and bhi>w.height*1.8,('%s: PlantScale 2: nothing under the soil, %.2f high'):format(tag,bhi))
 -- the coats
 for _,coat in ipairs({'Gold','Diamond'})do
  local cm=Visuals.Build(id,origin,crop(id,{Mutation=coat}),4,math.huge)
  check(#parts(cm)==w.specs,tag..': '..coat..' coat builds all parts')
 end
end end
-- 2b. The variants per crop -----------------------------------------------------------------------------------------------------------------------
-- Owner: "make growth variations in all of them". Like the approved plants, ApprovedPlantArt gives every crop one of the designs by a hash of its crop id and
-- then a small size / turn jitter (+-2%, +-4.6 degrees); Fire Pepper has one design (at x2) and the same ten jitters.
do
 local designs={DesertAloeSeed=Art.Designs('DesertAloeSeed'),SandFruitSeed=Art.Designs('SandFruitSeed')}
 local function count(art,name)local n=0;for _,s in ipairs(art.Specs)do if s.f==name then n+=1 end end;return n end
 local function same(list,want,tol)if #list~=#want then return false end;for i=1,#want do if math.abs(list[i]-want[i])>(tol or 1e-6)then return false end end;return true end
 -- (a) what differs between the Aloe's designs: leaves, spots and teeth, spikes (florets, height, lean, where they stand), colour balance
 local aloe={}
 for d,art in ipairs(designs.DesertAloeSeed)do
  local f={leaves=count(art,'Aloe leaf')/2,spots=count(art,'Aloe leaf spot'),teeth=count(art,'Aloe leaf tooth'),florets={0,0,0},stalks={},lean={},yaw={},greens=0,n=0}
  for _,s in ipairs(art.Specs)do
   if s.f=='Aloe floret'then f.florets[s.g]+=1;f.greens+=s.k[2];f.n+=1 end
   if s.f=='Aloe flower stalk'then f.stalks[s.g]=s.z[2];f.lean[s.g]=math.deg(math.acos(s.c[8]))end
   if s.f=='Rosette heart'then f.heart=table.concat(s.k,',')end
  end
  f.meanGreen=f.greens/f.n
  for g=1,3 do local so=art.Sockets[g];f.yaw[g]=math.deg(math.atan2(so[3],so[1]))%360 end
  aloe[d]=f
 end
 check(aloe[1].leaves==17 and aloe[2].leaves==14 and aloe[3].leaves==20 and aloe[4].leaves==15,'Aloe designs: 17 / 14 / 20 / 15 leaves (the rosette\'s fullness)')
 check(aloe[1].spots==7 and aloe[2].spots==12 and aloe[3].spots==8 and aloe[4].spots==12 and aloe[1].teeth==7 and aloe[2].teeth==6 and aloe[3].teeth==8 and aloe[4].teeth==6,'Aloe designs: the leaf spot / tooth patterns differ (7+7, 12+6, 8+8, 12+6)')
 local densities={24,25,21,23};local denseOk=true
 for d=1,4 do for g=1,3 do if aloe[d].florets[g]~=densities[d]then denseOk=false end end end
 check(denseOk,'Aloe designs: 24 / 25 / 21 / 23 florets on every spike (floret density)')
 check(same(aloe[1].stalks,{6.9,6.0,5.25})and same(aloe[2].stalks,{8.4,7.35,6.45})and same(aloe[3].stalks,{5.4,4.8,5.85})and same(aloe[4].stalks,{7.5,4.8,6.3}),'Aloe designs: the three spikes have different heights in each design')
 check(same(aloe[1].lean,{10,10,10},.01)and same(aloe[2].lean,{5,7,4},.01)and same(aloe[3].lean,{20,22,16},.01)and same(aloe[4].lean,{14,24,8},.01),'Aloe designs: the spikes lean 10 / 5-7 / 16-22 / 8-24 degrees')
 local function gaps(y)local a={y[1],y[2],y[3]};table.sort(a);return{a[2]-a[1],a[3]-a[2],360-a[3]+a[1]}end
 local g1,g4=gaps(aloe[1].yaw),gaps(aloe[4].yaw);table.sort(g4)
 check(same(gaps(aloe[1].yaw),{120,120,120},.01)and same(gaps(aloe[2].yaw),{120,120,120},.01)and g4[1]<60 and g4[3]>150,'Aloe designs: the spikes stand evenly round the heart in designs 1-3 and bunched to one side in design 4')
 check(aloe[3].meanGreen<aloe[1].meanGreen and aloe[1].meanGreen<aloe[2].meanGreen and aloe[2].meanGreen<aloe[4].meanGreen,('Aloe designs: the colour balance runs ember (%.0f) < red-to-yellow (%.0f) < sunset (%.0f) < golden (%.0f) by the mean green of the florets'):format(aloe[3].meanGreen,aloe[1].meanGreen,aloe[2].meanGreen,aloe[4].meanGreen))
 local hearts={};for d=1,4 do hearts[aloe[d].heart]=true end;local nh=0;for _ in pairs(hearts)do nh+=1 end
 check(nh==4,'Aloe designs: four different heart colours')
 -- (b) the Sand Fruit's designs: barrel height / width, 7-9 ribs, spine density, 0-3 pups, the fruits' positions and sizes
 local sand={}
 for d,art in ipairs(designs.SandFruitSeed)do
  local f={ribs=count(art,'Cactus rib')/5,spines=count(art,'Ivory spine'),pups=count(art,'Cactus pup'),sizes={},lats={}}
  for _,s in ipairs(art.Specs)do if s.f=='Cactus body'then f.RX=s.z[1]/2;f.RY=s.z[2]/2 end end
  for g=1,4 do
   for _,s in ipairs(art.Specs)do if s.f=='Sand fruit'and s.g==g then f.sizes[g]=s.z[1]/2.4 end end
   local so=art.Sockets[g];f.lats[g]=math.deg(math.asin((so[2]-f.RY)/f.RY))
  end
  sand[d]=f
 end
 check(same({sand[1].RX,sand[2].RX,sand[3].RX,sand[4].RX},{5.4,4.4,6.4,5.0})and same({sand[1].RY,sand[2].RY,sand[3].RY,sand[4].RY},{4.7,6.2,3.9,5.4}),'Sand Fruit designs: the barrel is 5.4 x 4.7 / 4.4 x 6.2 (tall) / 6.4 x 3.9 (squat) / 5.0 x 5.4')
 check(sand[1].ribs==8 and sand[2].ribs==9 and sand[3].ribs==7 and sand[4].ribs==9,'Sand Fruit designs: 8 / 9 / 7 / 9 ribs (7 to 9)')
 check(sand[1].spines==36 and sand[2].spines==25 and sand[3].spines==45 and sand[4].spines==32,'Sand Fruit designs: 36 / 25 / 45 / 32 ivory spines (sparse to dense)')
 check(sand[1].pups==2 and sand[2].pups==1 and sand[3].pups==3 and sand[4].pups==0,'Sand Fruit designs: 2 / 1 / 3 / 0 pups (0 to 3)')
 check(same(sand[1].sizes,{1,1,1,1})and same(sand[2].sizes,{1,.9,1.05,.85})and same(sand[3].sizes,{1.1,1.1,1.1,1.1})and same(sand[4].sizes,{1.1,.9,1,.85}),'Sand Fruit designs: the four fruits\' sizes differ (even, graded, big, uneven)')
 check(same(sand[1].lats,{46,38,46,38},.01)and same(sand[2].lats,{58,50,58,50},.01)and same(sand[3].lats,{34,40,34,40},.01)and same(sand[4].lats,{40,56,36,64},.01),'Sand Fruit designs: the fruits sit at latitude 46/38, 58/50, 34/40 and 40/56/36/64 degrees (shoulders to near the top)')
 -- every design's fruits grow out of ITS body: sockets on the body's own surface, between its ribs, centres .92 x size outside it, radius 1.15 x size
 for d,art in ipairs(designs.SandFruitSeed)do
  local f=sand[d];local onSurface,between,offset=true,true,true;local spacing=360/f.ribs
  for g=1,4 do
   local so,ce=art.Sockets[g],art.FruitCenters[g]
   local e=(so[1]/f.RX)^2+((so[2]-f.RY)/f.RY)^2+(so[3]/f.RX)^2
   if math.abs(e-1)>1e-6 then onSurface=false end
   local yaw=math.deg(math.atan2(so[3],so[1]))%360;local into=(yaw/spacing)%1
   if math.abs(into-.5)>.01 then between=false end
   local dist=math.sqrt((ce[1]-so[1])^2+(ce[2]-so[2])^2+(ce[3]-so[3])^2)
   if not(near(dist,.92*f.sizes[g],.01)and near(art.FruitRadii[g],1.15*f.sizes[g],1e-9))then offset=false end
  end
  check(onSurface and between and offset,'Sand Fruit design '..d..': the four sockets are on its own body\'s surface, between two ribs, with centres .92 x size outside and radius 1.15 x size')
 end
 for d,art in ipairs(designs.DesertAloeSeed)do
  local ok=true
  for g=1,3 do
   local so=art.Sockets[g]
   if not(near(so[2],1.05,1e-9)and math.sqrt(so[1]^2+so[3]^2)<=.34)then ok=false end -- (on top of the heart, within .22 x 1.5 of its axis)
   local ce=art.FruitCenters[g];local stalk;for _,s in ipairs(art.Specs)do if s.f=='Aloe flower stalk'and s.g==g then stalk=s end end
   local axis=V3(stalk.c[5],stalk.c[8],stalk.c[11]);local along=(V3(ce[1]-so[1],ce[2]-so[2],ce[3]-so[3]))
   if along.Magnitude<.5*stalk.z[2]or(along.Unit-axis).Magnitude>1e-6 or not near(art.FruitRadii[g],.3*stalk.z[2],1e-9)then ok=false end
  end
  check(ok,'Aloe design '..d..': each spike\'s socket is on top of the heart and its fruit centre on the spike, 70% up, radius .3 x its length')
 end

 -- (c) determinism: the design and jitter come from the crop id alone, by a pure hash (so the server, every client, the far proxy and the harvest prompts agree)
 local function hash(id)local h=137;for i=1,#id do h=(h*33+string.byte(id,i))%2147483647 end;return h end
 local ids={};for n=1,4000 do ids[n]=('%d_%d'):format(100000+n*37%9973,n)end
 for _,id in ipairs(IDS)do
  local pure,stable=true,true
  for _,cid in ipairs(ids)do
   local d,j=keyOf(id,cid);local h=hash(cid)
   if d~=math.floor(h/10)%4+1 or j~=h%10 or Approved.Design(id,{Id=cid})~=d then pure=false end
  end
  for n=1,300 do
   local cid=ids[n];local a=Approved.Get(id,{Id=cid})
   local b=Approved.Get(id,crop(id,{Id=cid,PlantScale=1.7,SeedScale=.6,Mutation='Gold',PickedMask=3,HarvestCycle=2,Weather='None'}));local c=Approved.Get(id,{Id=cid})
   if a~=b or a~=c or Approved.Key(id,{Id=cid})~=Approved.Key(id,crop(id,{Id=cid,PlantScale=1.7,Mutation='Gold'}))then stable=false end
  end
  check(pure,id..': 4000 crop ids: the design is hash(id) // 10 % 4 + 1 and the jitter hash(id) % 10, nothing else (a pure function of the id)')
  check(stable,id..': the same crop id always gets the same art whatever the crop\'s size, coat, picks, cycle or weather')
  -- (d) spread: every design about a quarter, every design / jitter pair used
  local per,pairsSeen,np={0,0,0,0},{},0
  for _,cid in ipairs(ids)do local d,j=keyOf(id,cid);per[d]+=1;if not pairsSeen[d..'/'..j]then pairsSeen[d..'/'..j]=true;np+=1 end end
  check(per[1]>=900 and per[1]<=1100 and per[2]>=900 and per[2]<=1100 and per[3]>=900 and per[3]<=1100 and per[4]>=900 and per[4]<=1100,id..': 4000 crop ids spread over the designs '..table.concat(per,' / ')..' (each about a quarter)')
  check(np==40,id..': all 4 designs x 10 sizes / turns are used ('..np..' of 40 art keys)')
  -- no id, a preview or an unknown crop shape: the base design, so nothing that already exists breaks
  check(Approved.Get(id)==Art.Designs(id)[1]and Approved.Get(id,{})==Art.Designs(id)[1]and Approved.Get(id,{Id='preview'})==Art.Designs(id)[1]and Approved.Key(id)==id..':base'and Approved.Get(id,{Id=''})~=nil and Approved.Get(id,{Id=12345})~=nil,
   id..': a call with no crop, no crop id or a preview shows design 1; an empty or a numeric id still works')
 end
 -- (e) the size / turn jitter: +-2% size, +-4.6 degrees turn about the vertical, the plant's own numbers scaled with it
 for _,id in ipairs(IDS)do
  local def=Catalog[id];local okJit=true;local maxHeight,maxRadius=0,0
  for d=1,4 do
   local base=Art.Designs(id)[d]
   for j=0,9 do
    local cid=pick(id,d,j);local art=Approved.Get(id,{Id=cid});local amount=1+(math.floor(j/2)-2)*.01
    local ok=near(art.Height,base.Height*amount,1e-9)and near(art.Radius,base.Radius*amount,1e-9)and #art.Specs==#base.Specs and art.RarityRework==true and #art.Sockets==def.FruitCount
    for g=1,def.FruitCount do
     local a,b=base.Sockets[g],art.Sockets[g]
     if not near(math.sqrt(b[1]^2+b[2]^2+b[3]^2),amount*math.sqrt(a[1]^2+a[2]^2+a[3]^2),1e-9)or not near(b[2],a[2]*amount,1e-9)then ok=false end
     if not near(art.FruitRadii[g],base.FruitRadii[g]*amount,1e-9)then ok=false end
    end
    if not ok then okJit=false end
    maxHeight=math.max(maxHeight,art.Height);maxRadius=math.max(maxRadius,art.Radius)
   end
  end
  check(okJit,id..': every design x every jitter (40 art keys): size x 0.98..1.02, sockets / fruit radii / bounds follow, the part list is the design\'s')
  check(maxHeight<=def.Height and maxRadius<=def.Radius,('%s: the catalog\'s Height %.3f / Radius %.3f cover every crop (largest %.3f / %.3f)'):format(id,def.Height,def.Radius,maxHeight,maxRadius))
 end

 -- (f) per design (and a few jitters): harvest positions, reach, the far proxies and the growing fruit
 for _,id in ipairs(IDS)do
  local def=Catalog[id]
  for d=1,4 do for _,j in ipairs({4,0,9})do
   local cid=pick(id,d,j);local tag=id..' design '..d..' jitter '..j;local art=Approved.Get(id,{Id=cid})
   local cr=crop(id,{Id=cid})
   local ok,reachOk=true,true;local reach0
   for g=1,def.FruitCount do
    local trait=Rules.Fruit(cr,g,def);local so,ce=V3(table.unpack(art.Sockets[g])),V3(table.unpack(art.FruitCenters[g]))
    local want=so+(ce-so)*trait.Scale;local got=Visuals.FruitPosition(cr,def,g)
    if(got-want).Magnitude>1e-9 or(Visuals.AuthoredSocket(id,cr,g)-so).Magnitude>1e-9 or(Visuals.FruitSocket(cr,def,g)-so).Magnitude>1e-9 then ok=false end
    local extra=Visuals.FruitReach(cr,def,g)-art.FruitRadii[g]*trait.Scale
    if reach0==nil then reach0=extra elseif math.abs(extra-reach0)>1e-9 then reachOk=false end
   end
   check(ok and reachOk,tag..': the harvest position, authored socket and reach come from this crop\'s own design (what the server and the prompts use)')
   -- the distant fruit proxies: each fruit's group, whole
   local meta=Visuals.Metadata(id,cr);local proxyOk=true
   for g=1,def.FruitCount do
    local group=R.new('Folder');Visuals.FruitProxy(group,id,cr,g,origin)
    local n=0;for _,x in ipairs(group:GetDescendants())do if x:IsA('BasePart')then n+=1 end end
    if n~=#(meta.Groups[g]or{})or n~=want[id][d].groups[g]then proxyOk=false end
   end
   check(proxyOk,tag..': the far proxy of every fruit has all the fruit\'s parts ('..want[id][d].groups[1]..' / ...)')
  end end
  -- growing fruit (regrow) of every fruit of every design, at several fractions: nothing appears before the bud, the fruit grows out of ITS socket to the full size
  for d=1,4 do
   local cid=pick(id,d,4);local art=Art.Designs(id)[d];local now=5e6;local duration=def.RegrowSeconds
   for g=1,def.FruitCount do
    local lastVisible,monotonic,lastReach=-1,true,-1;local ends={}
    for _,f in ipairs({0,.05,.1,.3,.5,.7,.9,1})do
     local cr=crop(id,{Id=cid,PlantedAt=now-def.Seconds*3,MatureAt=now-def.Seconds*2,ReadyAt=now-def.Seconds*2,HarvestCycle=1})
     cr.FruitStates={};for i=1,def.FruitCount do cr.FruitStates[tostring(i)]={ReadyAt=now+(i==g and duration*(1-f)or-5),Cycle=1,Duration=duration}end
     local source=table.clone(cr);source.ReadyAt=0
     local item=Visuals.Build(id,origin,source,4,math.huge,g);local child=item:FindFirstChild('Harvest_'..g)
     Visuals.BeginGrowth(child,id,cr,origin);Visuals.UpdateGrowth(child,cr,now)
     local visible,reach=0,0;local so=V3(table.unpack(art.Sockets[g]))
     for _,x in ipairs(child:GetDescendants())do if x:IsA('BasePart')and x.Transparency<1 and not x:GetAttribute('GrowthTemporary')then visible+=1;reach=math.max(reach,(x.CFrame.Position-so).Magnitude)end end
     if visible<lastVisible then monotonic=false end;lastVisible=visible
     if reach<lastReach-1e-6 then monotonic=false end;lastReach=reach
     ends[f]={visible=visible,reach=reach};if f==1 then ends.scale=Rules.Fruit(cr,g,def).Scale end -- (the fruit's own size trait of this crop and cycle)
     Visuals.EndGrowth(child,cr,now+duration)
    end
    local full=0;local sockets=V3(table.unpack(art.Sockets[g]))
    for _,s in ipairs(art.Specs)do if s.g==g then full=math.max(full,(V3(s.c[1],s.c[2],s.c[3])-sockets).Magnitude)end end
    full*=ends.scale
    check(ends[0].visible==0 and ends[1].visible==want[id][d].groups[g]and monotonic and ends[.5].reach<ends[1].reach and near(ends[1].reach,full,1e-5),
     ('%s design %d fruit %d regrow: 0 parts at 0%%, %d at 100%%, never fewer or farther out as it grows, the full size reaches the design\'s own parts (reach %.2f at 50%%, %.2f at 100%%)'):format(id,d,g,ends[1].visible,ends[.5].reach,ends[1].reach))
   end
  end
 end
 -- the whole plant at the extreme jitters, in the floating check's scene as well (ripe, growing, and one harvest item)
 for _,id in ipairs(IDS)do for d=1,4 do for _,j in ipairs({0,9})do
  local cid=pick(id,d,j);local def=Catalog[id]
  local m=Visuals.Build(id,origin,crop(id,{Id=cid}),4,math.huge)
  check(#parts(m)==want[id][d].specs,id..' design '..d..' jitter '..j..': ripe, all '..want[id][d].specs..' parts built')
  addScene(id..' design '..d..' jitter '..j..' ripe',m)
  addScene(id..' design '..d..' jitter '..j..' growing',Visuals.BuildGrowing(id,origin,crop(id,{Id=cid}),.6*def.Seconds))
  addScene(id..' design '..d..' jitter '..j..' harvest item 2',Visuals.BuildSelectedFruit(id,origin,crop(id,{Id=cid,_DetachedHarvest=true}),{[2]=true},math.huge))
 end end end

 -- (g) Fire Pepper: one design (at x2) and the ten size / turn jitters, as before
 do
  local id='FirePepperSeed';local keys,nk={},0
  for _,cid in ipairs(ids)do local k=Approved.Key(id,{Id=cid});if not keys[k]then keys[k]=true;nk+=1 end end
  local twice=true
  for n=1,200 do
   local c=crop(id,{Id=ids[n]});local a,b=OldApproved.Get(id,c),Approved.Get(id,c)
   if #a.Specs~=#b.Specs or not near(a.Height*2,b.Height,1e-9)or not near(a.Radius*2,b.Radius,1e-9)then twice=false end
   for i,s in ipairs(a.Specs)do local t=b.Specs[i];for k=1,3 do if not near(s.z[k]*2,t.z[k],1e-9)or not near(s.c[k]*2,t.c[k],1e-9)then twice=false end end end
   for i=1,#a.Sockets do for k=1,3 do if not near(a.Sockets[i][k]*2,b.Sockets[i][k],1e-9)or not near(a.FruitCenters[i][k]*2,b.FruitCenters[i][k],1e-9)then twice=false end end;if not near(a.FruitRadii[i]*2,b.FruitRadii[i],1e-9)then twice=false end end
  end
  check(nk==10 and twice,'Fire Pepper: 4000 crop ids give 10 art keys (one design, ten size / turn jitters), and for 200 of them every spec, socket, centre, radius and bound is exactly x2 of the base\'s variant')
  check(Approved.Design(id,{Id=ids[1]})==1,'Fire Pepper: one design')
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
 local expect={DesertAloeSeed={48,'Rare',0,0},SandFruitSeed={58,'Legendary',2,0},FirePepperSeed={46,'Mythic',0,3}}
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
 check(Sigs.Get('DesertAloeSeed')and Sigs.Get('SandFruitSeed')and Sigs.Get('SandFruitSeed').Pattern==nil and Sigs.Get('FirePepperSeed'),'signatures: Aloe, Sand Fruit (sandy Specks pattern + grains), Fire Pepper')
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
 -- A player with the five seeds of the OLD Desert found and grown, who has claimed nothing. What the old roster counts for is the server's call: a new
 -- player, or an old one who had not got there, has no IndexOldHalf2 / IndexOldFull2; an old completer has both (set below).
 for _,id in ipairs({'CactusSeed','DatePalmSeed','MirageFigSeed','SolarStarfruitSeed','StarfruitSeed'})do found(seeds,id);found(plants,id)end
 local s=R.new('LocalScript');s.Name='ChestIndex';W.load('ChestIndex',s)
 W.frames(10)
 local gui=pg:FindFirstChild('ChestIndexGui');local toggle=pg:FindFirstChild('IndexButton',true)
 local desert=gui:FindFirstChild('Biome2',true);local forest=gui:FindFirstChild('Biome1',true)
 local function shown(b)return b and b.Visible and b.Count.Text or nil end
 check(desert and desert:FindFirstChild('RewardDot')and desert.RewardDot.Visible and not(forest:FindFirstChild('RewardDot')and forest.RewardDot.Visible),'5 of 7 Desert seeds (no old-roster flags): the Desert tab has its reward dot for the halfway reward (Forest has none)')
 check(shown(toggle:FindFirstChild('RewardBadge'))=='1','INDEX shows 1: the halfway gems only, NOT the completion (a player without the server\'s flag needs all seven) ('..tostring(shown(toggle:FindFirstChild('RewardBadge')))..')')
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
 check(middle:GetAttribute('RewardReady')==true and middle.Active and endGem:GetAttribute('RewardReady')==false and not endGem.Active,'5 of 7, no flags: the halfway gem is lit, the completion gem is not')
 -- The server records an old completer (it had reached both milestones with the old roster, before the update) and publishes the flags.
 player:SetAttribute('IndexOldHalf2',true);W.frames(5)
 check(shown(toggle.RewardBadge)=='1'and endGem:GetAttribute('RewardReady')==false,'IndexOldHalf2 alone adds nothing here (the halfway reward is already lit by the live count)')
 player:SetAttribute('IndexOldFull2',true);W.frames(5)
 check(shown(toggle.RewardBadge)=='2'and desert.RewardDot.Visible,'an old completer (IndexOldHalf2 + IndexOldFull2): INDEX shows 2 ('..tostring(shown(toggle.RewardBadge))..')')
 check(middle:GetAttribute('RewardReady')==true and middle.Active and endGem:GetAttribute('RewardReady')==true and endGem.Active,'old 5/5 Desert, recorded by the server: both claim gems are lit and can be pressed (nothing is taken away)')
 player:SetAttribute('IndexOldFull2',false);W.frames(5)
 check(shown(toggle.RewardBadge)=='1'and endGem:GetAttribute('RewardReady')==false,'the completion flag withdrawn: the completion gem goes dark again (the flag, not the old roster, decides)')
 player:SetAttribute('IndexOldFull2',true);W.frames(5)
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

-- 8. Effect slots ---------------------------------------------------------------------------------------------------------------------------------
-- Every plant of rank 4+ (Legendary and up) wears a Highlight as its rarity aura, and Roblox draws at most 31 Highlights in all. GardenVisuals lets four
-- plants carry effects (two in low mode, which makes no aura): by rarity rank first, then distance, so a King / Cosmic / Secret plant is never crowded
-- out by nearer Legendary or Mythic ones (it used to be nearest-first).
do
 local function slot(key,rank,distance)return{SortKey=key,FxRank=rank,Distance=distance}end
 local function granted(list,cap)local n=Effects.GrantSlots(list,cap);local got={};for _,e in ipairs(list)do if e.FxGranted then got[#got+1]=e.SortKey end end;table.sort(got);return n,table.concat(got,',')end
 local function mixed()return{slot('a',4,5),slot('b',5,6),slot('c',4,7),slot('d',5,8),slot('e',8,60),slot('f',7,50),slot('g',6,70),slot('h',4,1)}end
 local n,got=granted(mixed(),4)
 check(n==4 and got=='b,e,f,g','GrantSlots, 4 slots: King, Cosmic and Secret first (however far), then the nearest Mythic; the nearer Legendary and Mythic plants wait ('..got..')')
 n,got=granted(mixed(),2);check(n==2 and got=='e,f','GrantSlots, 2 slots (low mode): King and Cosmic ('..got..')')
 n,got=granted({slot('x',5,10),slot('w',5,10)},1);check(n==1 and got=='w','GrantSlots: equal rank and distance, the stable key decides')
 n,got=granted({slot('a',4,9),slot('b',4,3)},4);check(n==2 and got=='a,b','GrantSlots: fewer plants than slots, all granted')
 n,got=granted({slot('a',4,9),slot('b',4,3),slot('c',4,6)},1);check(n==1 and got=='b','GrantSlots: the same rank goes nearest first')
 n,got=granted({},4);check(n==0 and got=='','GrantSlots: no plants, nothing granted')
 -- The real scheduler (GardenVisuals) on a garden: five Legendary plants near the camera, a King, a Cosmic and a Secret plant further off.
 local waiting={}
 local realWait,realAdvance=R.task.wait,R.advance
 local mainThread=coroutine.running()
 R.task.wait=function(t)if coroutine.running()==mainThread then return t or 0 end;table.insert(waiting,{At=R.clock+(t or 0),Co=coroutine.running()});return coroutine.yield()end -- (the mock's returns at once; here a spawned loop really waits)
 R.advance=function(dt)realAdvance(dt);local due,keep={},{};for _,w in ipairs(waiting)do if w.At<=R.clock then due[#due+1]=w else keep[#keep+1]=w end end;waiting=keep;for _,w in ipairs(due)do local ok,e=coroutine.resume(w.Co,dt);if not ok then error(e,0)end end end
 local Players=W.service('Players');local player=Players.LocalPlayer
 player:SetAttribute('ChestChaseCommandsAllowed',true)
 local camera=W.workspace.CurrentCamera;camera.CFrame=R.CFrame.lookAt(V3(0,12,-30),V3(0,4,0))
 local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
 local made=0
 local function plant(id,x,z)
  made+=1;local m=R.new('Model');m.Name='Crop_'..made;local now=math.floor(W.workspace:GetServerTimeNow())
  for k,v in pairs({GardenPlantV141=true,CropId='c'..made,SeedId=id,GrowthStage=4,PlantScale=1,SeedScale=1,Mutation='None',Weather='None',PlantedAt=now-100000,MatureAt=now-90000,ReadyAt=now-90000,HarvestCycle=0,PickedMask=0,FruitReady=true,FruitGrowing=false,FruitRevision=1})do m:SetAttribute(k,v)end
  local a=R.new('Part');a.Name='CropAnchor';a.CFrame=CF(x,0,z);a.Parent=m;m.Parent=map;return m
 end
 local near={};for i,at in ipairs({{0,-14},{5,-6},{-5,2},{6,10},{-6,18}})do near[i]=plant('SunflowerBloomSeed',at[1],at[2])end -- (the camera stands at z = -30, looking in +z)
 local king,cosmic,secret=plant('SolarStarfruitSeed',-25,28),plant('StormSovereignSeed',25,30),plant('StarfruitSeed',0,40)
 check(Catalog.SunflowerBloomSeed.Rank==4 and Catalog.SolarStarfruitSeed.Rank==8 and Catalog.StormSovereignSeed.Rank==7 and Catalog.StarfruitSeed.Rank==6,'(the scene: Legendary x5 near, King, Cosmic and Secret further away)')
 local gv=R.new('LocalScript');gv.Name='GardenVisuals';gv.Parent=player
 local okGV,errGV=pcall(W.load,'GardenVisuals',gv)
 check(okGV,'GardenVisuals loads in the test world ('..tostring(errGV)..')')
 W.frames(240)
 local function aura(m)local fx=m:FindFirstChild('PlantRarityEffects');return fx and fx:FindFirstChild('Rarity aura')end
 local function effects(m)return m:FindFirstChild('PlantRarityEffects')end
 local function highlights()local c=0;for _,d in ipairs(map:GetDescendants())do if d.Name=='Rarity aura'and d:IsA('Highlight')then c+=1 end end;return c end
 local builtAll=true;for _,m in ipairs({near[1],near[2],near[3],near[4],near[5],king,cosmic,secret})do if not m:FindFirstChild('LocalPlantArt')then builtAll=false end end
 check(builtAll,'all eight plants are built in detail')
 check(aura(king)and aura(cosmic)and aura(secret)and effects(king):GetAttribute('AuraRank')==8 and effects(cosmic):GetAttribute('AuraRank')==7 and effects(secret):GetAttribute('AuraRank')==6,
  'King, Cosmic and Secret (further from the camera) all wear their aura although five nearer Legendary plants are on screen')
 local nearHave=0;for _,m in ipairs(near)do if aura(m)then nearHave+=1 end end
 check(nearHave==1 and aura(near[1]),'... and the fourth slot goes to the NEAREST Legendary plant, the other four wait ('..nearHave..' of 5)')
 check(player:GetAttribute('PlantEffectModels')==4 and highlights()==4,'four effect plants and four Highlights in all, well under the 31 Roblox draws ('..tostring(player:GetAttribute('PlantEffectModels'))..' / '..highlights()..')')
 -- Low mode: two slots, no aura at all; the two highest ranks keep theirs.
 player:SetAttribute('StudioPlantEffects','low');W.frames(120)
 check(player:GetAttribute('PlantEffectModels')==2 and effects(king)and effects(cosmic)and not effects(secret)and highlights()==0,'low mode: two effect plants, King and Cosmic, and no Highlight ('..tostring(player:GetAttribute('PlantEffectModels'))..' / '..highlights()..')')
 player:SetAttribute('StudioPlantEffects','off');W.frames(120)
 check(player:GetAttribute('PlantEffectModels')==0 and highlights()==0 and not effects(king),'effects off: none')
 player:SetAttribute('StudioPlantEffects','normal');W.frames(240)
 check(aura(king)and aura(cosmic)and aura(secret)and highlights()==4,'back to normal: the same four auras')
 -- A King plant that only comes into range later still takes a slot from the Legendary plant that had it.
 local late=plant('PulsarStarfruitSeed',20,35);W.frames(240)
 check(aura(late)and effects(late):GetAttribute('AuraRank')==8 and not aura(near[1])and highlights()==4,'a second King plant that appears later takes the slot of the nearest Legendary plant ('..tostring(highlights())..' Highlights)')
 R.task.wait=realWait;R.advance=realAdvance
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
