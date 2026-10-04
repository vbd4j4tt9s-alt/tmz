--!nocheck
-- R149 (owner approved docs/proposals/R149/fruit_models.md: "they all work except for Lantern Fern ... and Tomato: make growth variations";
-- then "keep Amethyst Grape" and "Ash Tomato also keeps"): the part-based fruit redesigns of Phase 1 on the Roblox mock with the REAL modules
-- (PlantVisuals, ApprovedPlantArt, PlantArt*, TreeReworkData*, HarvestPresentation, ItemPictures, DistantPlantView, PlantGrowth ...).
-- Redesigned: Watermelon, Snow Melon, Apple, Elderbloom's elder apple, Ember Pumpkin, Prickly Pear, Blueberry, Iceberry.
-- Unchanged: Lantern Fern, Amethyst Grape and the Ash Tomato's look (it gains three variations of its current art).
--  1. each redesigned fruit: the spec list (names, counts, shapes, materials, colours, Neon, decor), the hotbar picture's part count, where the body sits
--     (the old body's centre), sockets / fruit centres / radii kept, connectors kept, canopy links of the berries, part budgets;
--  2. every build mode: ripe, every growth stage, one harvest item per fruit, held in the hand, Gold / Diamond coats (per plant and per fruit), weather
--     (the effect anchor and the real HarvestPresentation capture / step), the far proxy and DistantPlantView, the supports, Visuals.Part;
--  3. harvest prompts: position, reach and socket sit on / near the fruit; pictures: the real ItemPictures builds the hotbar / Bag picture of every
--     redesigned fruit, plain and coated;
--  4. Ash Tomato: 4 designs, the first byte for byte the base's, three variations that differ, same FruitCount, per-variant sockets, picked by hash of the crop
--     id (deterministic, all four used) and tied to Art.Key (the old key could not tell 3-4 designs apart); the jitter on top;
--  5. unchanged against the base commit: Lantern Fern, Amethyst Grape, every other art list and Art.Key (run_fruit_models.sh also diffs EVERY plant in the
--     catalog, every mode, against the base);
--  6. the scenes it prints (SCENE_PLANTS / SCENE_FRUIT) go through the R134 check_floating.py: 0 floating parts.
local W=require('./world');local F=require('./fixtures');local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
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
local function dist(a,b)return math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2)end
-- baked meshes live in ServerStorage: a stub (the redesigned fruit use none)
local Meshes=W.module('ApprovedPlantMeshes')
Meshes.Get=function(key)return {Clone=function()local p=R.new('Part');p:SetAttribute('ApprovedMesh',key);return p end}end
Meshes.Status=function()return 'Ready'end
local Catalog=W.module('PlantCatalog');local Visuals=W.module('PlantVisuals');local Harvest=W.module('HarvestPresentation');local Approved=W.module('ApprovedPlantArt')
local Rules=W.module('PlantRules');local Style=W.module('PlantSurfaceStyle');local Geometry=W.module('HarvestGeometry');local Distant=W.module('DistantPlantView')
local Weather=W.module('WeatherTraits')
local Base={Forest=W.module('PlantArtForestBase'),Snow=W.module('PlantArtSnowBase'),Lava=W.module('PlantArtLavaBase'),Crystal=W.module('PlantArtCrystalBase'),
 Apple=W.module('TreeReworkData2Base'),Elder=W.module('TreeReworkData4Base'),Lantern=W.module('ApprovedPlantArt2Base'),Ash=W.module('ApprovedPlantArt5Base'),Pear=W.module('ApprovedPlantArt6Base')}
local OldApproved=W.module('ApprovedPlantArtBase')
local origin=CF(0,0,0)
local function crop(id,cid,extra)
 local d=Catalog[id]
 local c={Id=cid or('r149-'..id),SeedId=id,PlantedAt=0,MatureAt=d.Seconds,ReadyAt=d.Seconds,PlantScale=1,SeedScale=1,Mutation='None',HarvestCycle=0,PickedMask=0,TraitVersion=1}
 for k,v in pairs(extra or{})do c[k]=v end;return c
end
local function parts(model,visible)local out={};for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d.Name~='VisualPivot'and(not visible or(d.Transparency or 0)<1)then out[#out+1]=d end end;return out end
local function countPred(model,pred)local n=0;for _,d in ipairs(parts(model))do if pred(d)then n+=1 end end;return n end
local function extent(d)
 local x,y,z,a,b,c,dd,e,f,g,h,i=d.CFrame:GetComponents();local ey=(math.abs(dd)*d.Size.X+math.abs(e)*d.Size.Y+math.abs(f)*d.Size.Z)/2
 if d:FindFirstChildOfClass('SpecialMesh')then -- a stretched sphere: the true ellipsoid extent, not its box
  local s=d.Size;ey=math.sqrt((dd*s.X/2)^2+(e*s.Y/2)^2+(f*s.Z/2)^2)
 end
 return y-ey,y+ey
end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function colourNear(c,k,tol)local r,g,b=rgb(c);return math.abs(r-k[1])<=tol and math.abs(g-k[2])<=tol and math.abs(b-k[3])<=tol end
local function kNear(a,k,tol)return math.abs(a[1]-k[1])<=tol and math.abs(a[2]-k[2])<=tol and math.abs(a[3]-k[3])<=tol end
local function tally(specs,g)local t={};for _,s in ipairs(specs)do if s.g==g then t[s.f]=(t[s.f]or 0)+1 end end;return t end
local function tallyText(t)local k={};for n in pairs(t)do k[#k+1]=n end;table.sort(k);local o={};for _,n in ipairs(k)do o[#o+1]=n..'='..t[n]end;return table.concat(o,' ')end
local function sameTally(a,b)return tallyText(a)==tallyText(b)end
local function deepEqual(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not deepEqual(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
local function specsOf(id,cid)return Visuals.Specs(id,cid and crop(id,cid)or nil)end

-- 1. The redesigned fruit ---------------------------------------------------------------------------------------------------------------------------
-- body = the spec that is the fruit's body; old = (module list, how to read the old body's centre and half height in final studs)
local FRUITS={
 {Id='SunflowerSeed',Name='Watermelon',Count=2,Body='Melon rind',Ground=true,Hotbar={12,12},Plant=104,
  Names={['Melon rind']=1,['Melon stripe band']=7,['Melon stem']=1,['Melon tendril']=1,['Melon leaf']=1,['Fruit gloss']=1,['Fruit stem']=1},Keep={'Fruit stem'},Neon={['Fruit gloss']=1},
  Colours={['Melon rind']={108,180,76},['Melon stripe band']={39,102,50},['Melon stem']={86,128,58},['Melon leaf']={80,150,62}},Style=true},
 {Id='SnowdropSeed',Name='Snow Melon',Count=2,Body='Snow melon rind',Ground=true,Hotbar={13,13},Plant=122,
  Names={['Snow melon rind']=1,['Snow melon stripe band']=7,['Snow melon stem']=1,['Snow melon tendril']=1,['Snow melon leaf']=1,['Snow cap']=1,['Fruit gloss']=1,['Fruit stem']=1},Keep={'Fruit stem'},Neon={['Fruit gloss']=1},
  Colours={['Snow melon rind']={190,232,234},['Snow melon stripe band']={64,134,164},['Snow cap']={250,254,255}},Translucent={['Snow cap']=.45},Style=true},
 {Id='AppleSeed',Name='Apple',Count=4,Body='Apple body',Hotbar={8,8,8,8},Plant=83,
  Names={['Apple body']=1,['Apple shoulder']=2,['Apple base tone']=1,['Apple dimple']=1,['Apple stem']=1,['Apple leaf']=1,['Fruit gloss']=1,['Apple hanging stem']=1},Keep={'Apple hanging stem'},Neon={['Fruit gloss']=1},
  Colours={['Apple body']={206,36,46},['Apple base tone']={226,72,52},['Apple stem']={104,74,44},['Apple leaf']={78,152,60}},Style=false},
 {Id='ElderbloomSeed',Name='Elderbloom',Count=5,Body='Elder apple body',Hotbar={10,10,10,10,10},Plant=137,
  Names={['Elder apple body']=1,['Elder apple shoulder']=2,['Elder apple base tone']=1,['Elder apple dimple']=1,['Elder apple stem']=1,['Elder apple leaf']=1,['Fruit gloss']=1,['Ancient apple rune']=1,['Ancient apple rune cross']=1},Keep={},
  Neon={['Fruit gloss']=1,['Ancient apple rune']=1,['Ancient apple rune cross']=1},Colours={['Elder apple body']={112,164,92},['Elder apple base tone']={214,190,104},['Ancient apple rune']={255,225,138}},Style=false},
 {Id='EmberBloomSeed',Name='Ember Pumpkin',Count=2,Body='Pumpkin heart',Ground=true,Hotbar={25,25},Plant=154,
  Names={['Pumpkin heart']=1,['Pumpkin rib']=10,['Ember groove']=10,['Pumpkin stem']=1,['Pumpkin stem curl']=1,['Pumpkin leaf']=1,['Fruit gloss']=1,['Fruit stem']=1},Keep={'Fruit stem'},Neon={['Fruit gloss']=1,['Ember groove']=10},
  Colours={['Pumpkin heart']={132,46,14},['Pumpkin rib']={226,100,25},['Ember groove']={255,150,40}},Style=true},
 {Id='CactusSeed',Name='Prickly Pear',Count=3,Body='Pear body',Hotbar={17,17,17},Plant=82,
  Names={['Pear body']=1,['Pear shoulder shade']=1,['Pear coral base']=1,['Pear navel']=1,['Pear navel scale']=5,['Pear areole']=6,['Fruit gloss']=1,['Upper surface fruit attachment']=1},Keep={'Upper surface fruit attachment'},Neon={['Fruit gloss']=1},
  Colours={['Pear body']={204,50,110},['Pear coral base']={232,96,96},['Pear navel']={104,28,62}},Style=true},
 {Id='BluebellSeed',Name='Blueberry',Count=4,Body='Berry',Hotbar={18,18,18,18},Plant=94,
  Names={['Berry']=3,['Berry bloom']=3,['Berry cap']=3,['Berry stalklet']=3,['Berry glint']=3,['Berry stem']=1,['Berry leaf']=2},Keep={},Neon={['Berry glint']=3},
  Colours={['Berry']={62,76,168},['Berry bloom']={152,170,224},['Berry cap']={30,36,90}},Translucent={['Berry bloom']=.5},Style=true},
 {Id='IceberrySeed',Name='Iceberry',Count=4,Body='Berry',Hotbar={18,18,18,18},Plant=94,
  Names={['Berry']=3,['Berry bloom']=3,['Berry cap']=3,['Berry stalklet']=3,['Berry glint']=3,['Berry stem']=1,['Berry leaf']=2},Keep={},Neon={['Berry glint']=3},
  Colours={['Berry']={118,196,232},['Berry bloom']={236,250,255},['Berry cap']={60,120,160}},Translucent={['Berry bloom']=.5},Style=true},
}
-- old art (base commit): the list the fruit's groups came from, and the old body's name
local function oldList(f)
 if f.Id=='SunflowerSeed'then return Base.Forest.SunflowerSeed elseif f.Id=='SnowdropSeed'then return Base.Snow.SnowdropSeed elseif f.Id=='EmberBloomSeed'then return Base.Lava.EmberBloomSeed
 elseif f.Id=='BluebellSeed'then return Base.Forest.BluebellSeed elseif f.Id=='IceberrySeed'then return Base.Snow.IceberrySeed elseif f.Id=='AppleSeed'then return Base.Apple.Specs
 elseif f.Id=='ElderbloomSeed'then return Base.Elder.Specs elseif f.Id=='CactusSeed'then return Base.Pear[1].Specs end
end
local OLDBODY={SunflowerSeed='Rind',SnowdropSeed='Rind',EmberBloomSeed='Pumpkin lobe',BluebellSeed='Berry',IceberrySeed='Berry',AppleSeed='Canopy apple',ElderbloomSeed='Elder apple',CactusSeed='Cactus pear'}
local function groupParts(model,g)
 local m=model:FindFirstChild('Harvest_'..g);return m and parts(m)or{}
end
local function bodyCentre(specs,g,name)
 local sum,n=V3(0,0,0),0
 for _,s in ipairs(specs)do if s.g==g and s.f==name then sum+=V3(s.c[1],s.c[2],s.c[3]);n+=1 end end
 return n>0 and sum/n or nil,n
end
local function hotbar(id,index,mut,weather,cid)
 return(Harvest.Build({SeedId=id,Mutation=mut or'None',Weather=weather or'None',VisualCrop={SourceCropId=cid or('r149-'..id),FruitIndex=index,HarvestCycle=0}}))
end
local MUT_GOLD,MUT_DIAMOND='Gold','Diamond'
for _,f in ipairs(FRUITS)do
 local id,def=f.Id,Catalog[f.Id];local specs=specsOf(id);local old=oldList(f);local name=f.Name
 check(def.FruitCount==f.Count,name..': FruitCount '..f.Count..' (saved crops keep loading)')
 -- 1a. the spec lists: names and counts per group, shapes, roles, materials
 local okNames,okShape,okRole,okMat,okTx,okNeon=true,true,true,true,true,true
 for g=1,f.Count do
  local t=tally(specs,g)
  if not sameTally(t,f.Names)then okNames=false;print('  '..name..' group '..g..': '..tallyText(t))end
  local neon={}
  for _,s in ipairs(specs)do if s.g==g then
   if not(s.s=='Ball'or s.s=='Cylinder'or(s.s=='Block'and s.m=='Neon')or s.f=='Upper surface fruit attachment'or s.f=='Fruit stem'or s.f=='Apple hanging stem')then okShape=false end
   if s.r~='Fruit'then okRole=false end
   if s.m=='Neon'then neon[s.f]=(neon[s.f]or 0)+1 elseif not(s.m=='SmoothPlastic'or(s.m=='Wood'and s.f=='Elder apple stem'))then okMat=false end
   if(s.s=='Ball'or s.s=='Block')and s.f~='Fruit stem'and s.tx~='smooth'then okTx=false end
  end end
  for n,c in pairs(f.Neon)do if neon[n]~=c then okNeon=false end end
  for n in pairs(neon)do if not f.Neon[n]then okNeon=false end end
 end
 check(okNames,name..': every fruit group holds exactly '..tallyText(f.Names))
 check(okShape,name..': fruit parts are Balls and Cylinders (no Block body; only the Elder apple\'s Neon rune and the kept connectors differ)')
 check(okRole,name..': every fruit part has the Fruit role (a Stem role would hide it from the hotbar picture)')
 check(okMat,name..': SmoothPlastic (the Elder apple stem Wood), Neon only where designed')
 check(okNeon,name..': Neon parts '..tallyText(f.Neon)..' per fruit')
 check(okTx,name..': every Ball / Block is tx=smooth (no surface marks, and PlantSurfaceStyle\'s grain / speckle rules skip it)')
 -- gloss patches and glints are decor (hidden on Gold / Diamond)
 local decorOk=true
 for _,s in ipairs(specs)do if s.g>0 then
  local should=s.f=='Fruit gloss'or s.f=='Berry glint'
  if(s.decor==true)~=should then decorOk=false end
 end end
 check(decorOk,name..': exactly the gloss patch / glints are decor')
 -- 1b. colours: the design's own (PlantSurfaceStyle shifts a part <= 6 %)
 local colOk=true
 for _,s in ipairs(specs)do if s.g>0 and f.Colours[s.f]then
  local tol=f.Style and 16 or 1
  local want=f.Colours[s.f]
  -- stripes / ribs alternate two tones 6 apart
  if not kNear(s.k,want,tol+(s.f:find('stripe')and 8 or s.f=='Pumpkin rib'and 8 or 0))then colOk=false;print('  '..name..' '..s.f..' '..table.concat(s.k,',')..' vs '..table.concat(want,','))end
 end end
 check(colOk,name..': colours are the design\'s')
 for n,a in pairs(f.Translucent or{})do
  local ok=true;local seen=0;for _,s in ipairs(specs)do if s.g>0 and s.f==n then seen+=1;if not near(s.t,a,1e-9)then ok=false end end end
  check(ok and seen>0,name..': '..n..' is translucent ('..a..')')
 end
 -- 1c. the old connector specs stay byte for byte
 local keepOk=true;local kept=0
 for _,kname in ipairs(f.Keep)do
  local before,after={},{}
  for _,s in ipairs(old)do if s.g>0 and s.f==kname then before[#before+1]=s end end
  local live=({AppleSeed=W.module('TreeReworkData2').Specs,CactusSeed=W.module('ApprovedPlantArt6')[1].Specs})[id]
  if not live then local m=({SunflowerSeed='PlantArtForest',SnowdropSeed='PlantArtSnow',EmberBloomSeed='PlantArtLava'})[id];live=W.module(m)[id]end
  for _,s in ipairs(live)do if s.g>0 and s.f==kname then after[#after+1]=s end end
  if #before~=#after or #before<f.Count then keepOk=false else for i=1,#before do if not deepEqual(before[i],after[i])then keepOk=false end;kept+=1 end end
 end
 check(keepOk,name..': the old connector specs ('..table.concat(f.Keep,', ')..') are unchanged ('..kept..' kept)')
 -- 1d. where the fruit sits: the old body's centre (ground fruit: its bottom on the old bottom), sockets / centres / radii as in the catalog
 local scale=(Approved.Get(id)and 1)or(def.BaseScale or 1)
 local live=Approved.Get(id)
 local socketsOk,centreOk,bottomOk=true,true,true
 for g=1,f.Count do
  local new,n=bodyCentre(specs,g,f.Body);check(n>=1,name..': group '..g..' has its body ('..n..')')
  local sock=def.Sockets[g];local cen=def.FruitCenters[g];local rad=def.FruitRadii[g]
  if live then sock=live.Sockets[g];cen=live.FruitCenters[g];rad=live.FruitRadii[g]end
  -- the old body centre in final studs
  local oc,on=bodyCentre(old,g,OLDBODY[id]);local oldC
  if f.Id=='CactusSeed'then
   local S=V3(table.unpack(Base.Pear[1].Sockets[g]));oldC=S*3+(oc-S)*2
  else oldC=oc*(Approved.Get(id)and 1 or(def.BaseScale or 1))end
  if f.Id=='SunflowerSeed'or f.Id=='SnowdropSeed'or f.Id=='EmberBloomSeed'or f.Id=='BluebellSeed'or f.Id=='IceberrySeed'then
   -- (PlantVisuals.Specs multiplies PlantArt* by the BaseScale: new and old are both compared in final studs)
  end
  if not(math.abs(new.X-oldC.X)<=.02 and math.abs(new.Z-oldC.Z)<=.02)then centreOk=false;print(('  %s group %d body at %.3f,%.3f,%.3f, old %.3f,%.3f,%.3f'):format(name,g,new.X,new.Y,new.Z,oldC.X,oldC.Y,oldC.Z))end
  if f.Ground then
   -- sits where the old body sat: bottoms meet
   local oldHalf
   if f.Id=='EmberBloomSeed'then for _,s in ipairs(old)do if s.g==g and s.f=='Pumpkin lobe'then oldHalf=s.z[2]*def.BaseScale/2 end end
   else for _,s in ipairs(old)do if s.g==g and s.f=='Rind'then oldHalf=s.z[2]*def.BaseScale/2 end end end
   local newHalf;for _,s in ipairs(specs)do if s.g==g and s.f==f.Body then newHalf=s.z[2]/2 end end
   if f.Id=='EmberBloomSeed'then newHalf=0;for _,s in ipairs(specs)do if s.g==g and s.f=='Pumpkin rib'then newHalf=math.max(newHalf,s.z[2]/2)end end end
   if not near(new.Y-newHalf,oldC.Y-oldHalf,.03)then bottomOk=false;print(('  %s group %d: body bottom %.3f, old %.3f'):format(name,g,new.Y-newHalf,oldC.Y-oldHalf))end
  end
  -- the fruit centre of the catalog is on (or just above) the fruit: within its radius of the body
  if(V3(cen[1],cen[2],cen[3])-new).Magnitude>rad*.55 then socketsOk=false;print(('  %s group %d: catalog centre %.2f from the body, radius %.2f'):format(name,g,(V3(cen[1],cen[2],cen[3])-new).Magnitude,rad))end
 end
 check(centreOk,name..': every body sits on the old body\'s centre (x / z)')
 if f.Ground then check(bottomOk,name..': a ground fruit keeps its bottom where the old body\'s was')end
 check(socketsOk,name..': the catalog\'s fruit centre is within .55 radius of the new body (harvest reach and the fruit picker stay)')
 -- sockets / centres / radii unchanged against the base: art-owned (Approved) plants read them from the art design, the others from the catalog
 if live then
  local ok=true
  if id=='CactusSeed'then
   for di=1,2 do local new,old=W.module('ApprovedPlantArt6')[di],Base.Pear[di];ok=ok and deepEqual(new.Sockets,old.Sockets)and deepEqual(new.FruitCenters,old.FruitCenters)and deepEqual(new.FruitRadii,old.FruitRadii)end
  else
   local oldArt=({AppleSeed=Base.Apple,ElderbloomSeed=Base.Elder})[id]
   ok=deepEqual(live.Sockets,oldArt.Sockets)and deepEqual(live.FruitCenters,oldArt.FruitCenters)and deepEqual(live.FruitRadii,oldArt.FruitRadii)
  end
  check(ok,name..': Sockets / FruitCenters / FruitRadii equal the base\'s art (every design)')
 end
 -- 1e. the hotbar / Bag / Index model: part counts, nothing under or beside it
 local counts={}
 for i=1,f.Count do
  local m=hotbar(id,i);local n=#parts(m,true);counts[i]=n
  check(n==f.Hotbar[i],name..': hotbar picture of fruit '..i..' has '..f.Hotbar[i]..' parts ('..n..')')
  check(#parts(m)==n,name..': fruit '..i..': every part of the picture is visible')
  check(m:GetAttribute('HarvestPresentation')==true and m:GetAttribute('HarvestIndex')==i,name..': the picture carries HarvestPresentation / HarvestIndex '..i)
 end
 -- 1f. the part budgets (proposal section 3): the plant at full detail
 local plant=Visuals.Build(id,origin,crop(id,'preview-'..id),4,math.huge)
 local total=#parts(plant)
 check(total==f.Plant,name..': the plant has '..f.Plant..' parts at full detail ('..total..')')
 check(Visuals.DetailCost(id,crop(id,'preview-'..id))==f.Plant+1,name..': PlantDetailPlanner cost = parts + 1')
end

-- Part counts before / after in the proposal's terms (hotbar picture of the first fruit, plant at full detail), measured above:
--   Watermelon 42 -> 12 (plant 152 -> 104); Snow Melon 34 -> 13; Apple 5 -> 8 (71 -> 83); Elderbloom 17 -> 10; Ember Pumpkin 28 -> 25 (148 -> 154);
--   Prickly Pear 24 -> 17 (97 -> 82); Blueberry / Iceberry 15 -> 18 (90 -> 94).
-- 2. Blueberry / Iceberry: the cluster rides with its shrub crown (canopy index + cd on the berry at the socket) -----------------------------------------
for _,id in ipairs({'BluebellSeed','IceberrySeed'})do
 local specs=specsOf(id);local old=oldList({Id=id})
 local ok=true
 for g=1,4 do
  local first,oldFirst
  for _,s in ipairs(specs)do if s.g==g and s.f=='Berry'and not first then first=s end end
  for _,s in ipairs(old)do if s.g==g and s.f=='Berry'and not oldFirst then oldFirst=s end end
  if not(first and first.canopy==oldFirst.canopy and deepEqual(first.cd,oldFirst.cd))then ok=false end
  local crown=specs[first.canopy];if not(crown and crown.s=='Shrub'and crown.g==0)then ok=false end
 end
 check(ok,id..': the first berry of each cluster keeps its canopy index and cd (FruitSocket rides on the shrub crown)')
 -- the berries sit at the old berries (a cluster of three where the three were), and the socket follows each crop's crown
 for _,cid in ipairs({'berry-1','berry-2','berry-3','berry-4'})do
  local c=crop(id,cid);local model=Visuals.Build(id,origin,c,4,math.huge);local good=true
  for g=1,4 do
   local socket=Visuals.FruitSocket(c,Catalog[id],g);local ps=groupParts(model,g)
   local near_=math.huge;for _,p in ipairs(ps)do near_=math.min(near_,(p.Position-socket).Magnitude)end
   if#ps~=18 or near_>1.2 then good=false end
  end
  check(good,id..' '..cid..': 18 parts per cluster, within 1.2 studs of its crown-following socket')
 end
end

-- 3. Every build mode, per redesigned fruit ----------------------------------------------------------------------------------------------------------
local scenePlants,sceneFruit,labelsP,labelsF={}, {}, {}, {}
local function addScene(list,labels,label,model,strict)
 labels[#labels+1]=label;local seed=#labels
 for _,c in ipairs(model:GetDescendants())do if c:IsA('BasePart')and c.Name~='VisualPivot'and(c.Transparency or 0)<1 then
  local cf=c.CFrame;local r=cf.R;local p=cf.Position;local sz=c.Size
  local shape=(c.Shape and(type(c.Shape)=='table'and c.Shape.Name or tostring(c.Shape):match('(%w+)$')))or'Block'
  local sm=c:FindFirstChildOfClass('SpecialMesh')
  if strict and sm and(type(sm.MeshType)=='table'and sm.MeshType.Name or tostring(sm.MeshType)):match('Sphere')then shape='Ball';sz=V3(sz.X*sm.Scale.X,sz.Y*sm.Scale.Y,sz.Z*sm.Scale.Z)end
  local function n4(v)return string.format('%.4f',v)end
  list[#list+1]=('{"seed":%d,"name":"%s","shape":"%s","size":[%s,%s,%s],"p":[%s,%s,%s],"r":[%s,%s,%s,%s,%s,%s,%s,%s,%s],"t":%s}'):format(seed,c.Name,shape,
   n4(sz.X),n4(sz.Y),n4(sz.Z),n4(p.X),n4(p.Y),n4(p.Z),n4(r[1][1]),n4(r[1][2]),n4(r[1][3]),n4(r[2][1]),n4(r[2][2]),n4(r[2][3]),n4(r[3][1]),n4(r[3][2]),n4(r[3][3]),n4(c.Transparency or 0))
 end end
end
local function isFruitGroup(p)return p.Parent and(p.Parent:GetAttribute('HarvestIndex')~=nil)end
for _,f in ipairs(FRUITS)do
 local id,def,name=f.Id,Catalog[f.Id],f.Name
 for ci,cid in ipairs({'build-a','build-b'})do
  local c=crop(id,cid)
  -- ripe
  local ripe=Visuals.Build(id,origin,c,4,math.huge)
  local lo=math.huge;for g=1,f.Count do for _,p in ipairs(groupParts(ripe,g))do local a=extent(p);lo=math.min(lo,a)end end
  check(lo>=-.05,('%s %s: no fruit part under the soil (lowest %.3f)'):format(name,cid,lo))
  local groups=0;for g=1,f.Count do if#groupParts(ripe,g)>0 then groups+=1 end end
  check(groups==f.Count,name..' '..cid..': every fruit group built ('..groups..')')
  addScene(scenePlants,labelsP,name..' '..cid,ripe,false)
  -- harvest query: every fruit part can be queried (the prompt), no body part can
  local qOk=true;for g=1,f.Count do for _,p in ipairs(groupParts(ripe,g))do if not p.CanQuery then qOk=false end end end
  for _,p in ipairs(parts(ripe:FindFirstChild('PlantBase')or R.new('Model')))do if p.CanQuery then qOk=false end end
  check(qOk,name..' '..cid..': fruit parts can be queried, body parts cannot')
  -- growth: every stage
  local seen,lastTop,monotonic={},-1,true
  for _,fr in ipairs({0,.1,.3,.5,.7,.9,1})do
   local ok,g=pcall(Visuals.BuildGrowing,id,origin,c,fr*def.Seconds)
   if check(ok,name..' '..cid..': growing at '..fr*100 ..'% builds ('..tostring(not ok and g or'')..')')then
    local vis=parts(g,true);local hi=-math.huge;local fruit=0
    for _,p in ipairs(vis)do local _,b=extent(p);hi=math.max(hi,b);if p.Parent and p.Parent.Name:find('Harvest_')then fruit+=1 end end
    if hi<lastTop-1e-6 then monotonic=false end;lastTop=hi;seen[fr]={#vis,fruit,hi}
    check(#parts(g)<=#parts(ripe)+4+2*f.Count+4,name..' '..cid..' '..fr*100 ..'%: the art parts plus the growth pieces only ('..#parts(g)..')')
    local lowest=math.huge;for _,p in ipairs(vis)do if p.Parent and p.Parent.Name:find('Harvest_')then local a=extent(p);lowest=math.min(lowest,a)end end
    check(lowest>=-.06,name..' '..cid..' '..fr*100 ..'%: no fruit part under the soil')
    if fr==1 then check(#vis==#parts(ripe,true),name..' '..cid..': 100% shows the whole ripe plant ('..#vis..' / '..#parts(ripe,true)..')')end
    if ci==1 and(fr==.5)then addScene(scenePlants,labelsP,name..' growing 50%',g,false)end
   end
  end
  check(monotonic,name..' '..cid..': the plant only ever gets taller as it grows')
  check(seen[.1]and seen[.1][2]==0,name..' '..cid..': 10%: a sprout, no fruit showing yet')
  check(seen[0]and seen[0][1]==1,name..' '..cid..': 0%: only the new seed shows ('..tostring(seen[0]and seen[0][1])..')')
  check(seen[.9]and seen[.9][2]>0,name..' '..cid..': 90%: fruit showing')
  -- the stage builds of Visuals.Build (1 - 3 go through BuildGrowing)
  for stage=1,3 do local ok=pcall(Visuals.Build,id,origin,crop(id,cid,{PlantedAt=0}),stage,.4*def.Seconds);check(ok,name..': Build stage '..stage..' works')end
  -- supports + the far plant
  local sup=R.new('Model');Visuals.Supports(id,origin,c,4,sup)
  check(#parts(sup)>0 and countPred(sup,function(p)return p.CanCollide end)==0 or def.Tree,name..' '..cid..': the distant supports build ('..#parts(sup)..')')
  local far,growing=Distant.Build(c,origin,def.Seconds+1)
  local proxies={};for _,p in ipairs(parts(far))do if p:GetAttribute('FruitProxy')then proxies[#proxies+1]=p end end
  local sumProxy=0;for g=1,f.Count do local pf=far:FindFirstChild('Harvest_'..g);local n=pf and#parts(pf)or 0;sumProxy+=n
   check(n==#groupParts(ripe,g),name..' '..cid..': the far proxy of fruit '..g..' has the same parts as the close fruit ('..n..' / '..#groupParts(ripe,g)..')')end
  check(#proxies==sumProxy,name..' '..cid..': every proxy part carries FruitProxy / HarvestIndex')
  check(Distant.Cost(c)>=#parts(sup)+sumProxy,name..' '..cid..': DistantPlantView.Cost covers the supports and every proxy ('..Distant.Cost(c)..')')
  -- coats: the plant and one fruit
  for _,coat in ipairs({MUT_GOLD,MUT_DIAMOND})do
   -- a coated PLANT coats its body; every fruit carries its own roll (Rules.Fruit), the harvest items below cover the fruit coats
   local m=Visuals.Build(id,origin,crop(id,cid,{Mutation=coat}),4,math.huge)
   local mat=coat==MUT_GOLD and'Metal'or'Glass';local matOk=true;local body=m:FindFirstChild('PlantBase')
   for _,p in ipairs(parts(body,true))do if p.Material.Name~=mat then matOk=false end end
   check(#parts(m)==#parts(ripe)and matOk,name..' '..cid..': '..coat..' coat: the same '..#parts(ripe)..' parts, the whole body is '..mat)
  end
 end
 -- harvest items: plain, Gold, Diamond; held in the hand; weather
 for i=1,f.Count do
  local plain=hotbar(id,i);local plainN=#parts(plain,true)
  for _,coat in ipairs({MUT_GOLD,MUT_DIAMOND})do
   local m=hotbar(id,i,coat);local decor=0;for _,p in ipairs(parts(m))do if p.Transparency>=1 then decor+=1 end end
   local expectDecor=0;for _,s in ipairs(specsOf(id))do if s.g==i and s.decor then expectDecor+=1 end end
   local mat=coat==MUT_GOLD and'Metal'or'Glass';local matOk=true
   for _,p in ipairs(parts(m,true))do if p.Material.Name~=mat then matOk=false end end
   check(decor==expectDecor and#parts(m,true)==plainN-expectDecor and matOk,name..' fruit '..i..' '..coat..': '..(plainN-expectDecor)..' '..mat..' parts, '..expectDecor..' decor hidden')
   if coat==MUT_GOLD then
    local goldOk=true;for _,p in ipairs(parts(m,true))do local r,g,b=rgb(p.Color);if not(r>=224 and g>=162 and b>=52 and b<=82)then goldOk=false end end
    check(goldOk,name..' fruit '..i..': the Gold coat is gold')
   end
  end
  -- held in the hand: the same fruit (HarvestSpec drops only the connectors)
  local item=Visuals.BuildSelectedFruit(id,origin,crop(id,'held',{_DetachedHarvest=true}),{[i]=true},math.huge)
  check(#parts(item)==plainN,name..' fruit '..i..': held in the hand = the hotbar picture ('..#parts(item)..' / '..plainN..')')
  local center,size=Geometry.Bounds(plain)
  check(size.X>.4 and size.Y>.4 and size.Z>.4 and size.X<12 and size.Y<12,('%s fruit %d: picture bounds %.2f x %.2f x %.2f'):format(name,i,size.X,size.Y,size.Z))
  local grip=Geometry.Grip(plain);local gripBody=(grip-center).Magnitude
  check(gripBody<=math.max(size.X,size.Y,size.Z)*.6,name..' fruit '..i..': the grip sits on the fruit')
  for _,w in ipairs({'Drippy','Frosted','Charged','Drippy+Frosted+Charged'})do
   local m=hotbar(id,i,'None',w);local p=m.PrimaryPart
   local c2,s2=Geometry.Bounds(m)
   check(p:GetAttribute('WeatherTrait')==Weather.Key(w)and near(p:GetAttribute('EffectRadius'),math.clamp(math.max(s2.X,s2.Z)*.5,.2,45),1e-6)and near(p:GetAttribute('EffectHeight'),math.clamp(s2.Y,.2,70),1e-6),name..' fruit '..i..' '..w..': the weather effect anchor sizes to the fruit')
   check(#parts(m,true)==plainN,name..' fruit '..i..' '..w..': weather adds no part to the fruit itself')
  end
 end
 -- the real harvest-presentation effects (weather highlight): capture, step, stop
 do
  local wm=R.new('WorldModel');wm.Parent=W.workspace;local good=true;local msg
  for i=1,f.Count do for _,w in ipairs({'Drippy','Frosted+Charged'})do
   local model,hc,index=Harvest.Build({SeedId=id,Mutation=i%2==0 and'Gold'or'None',Weather=w,VisualCrop={SourceCropId='fx-'..id,FruitIndex=i,HarvestCycle=0}})
   model.Parent=wm
   local ok,e=pcall(function()local r=Harvest.Capture(model,hc,index);Harvest.Step(r,1.0);Harvest.Step(r,1.3);Harvest.Stop(r);Harvest.Destroy(r)end)
   if not ok then good=false;msg=e end
  end end
  check(good,name..': HarvestPresentation capture / step / stop with weather works ('..tostring(msg or'ok')..')')
  wm:Destroy()
 end
 -- harvest prompt: position, reach and socket on the fruit
 local c=crop(id,'prompt-1');local plant=Visuals.Build(id,origin,c,4,math.huge);local promptOk,reachOk=true,true
 for g=1,f.Count do
  local pos=Visuals.FruitPosition(c,def,g,math.huge);local reach=Visuals.FruitReach(c,def,g)
  local ps=groupParts(plant,g);local lo,hi=V3(math.huge,math.huge,math.huge),V3(-math.huge,-math.huge,-math.huge)
  for _,p in ipairs(ps)do local q=p.Position;lo=V3(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=V3(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))end
  local mid=(lo+hi)*.5;local radius=(Approved.Get(id)and Approved.Get(id,c).FruitRadii or def.FruitRadii)[g]
  if(pos-mid).Magnitude>radius*1.05 then promptOk=false;print(('  %s fruit %d: prompt %.2f from the fruit, radius %.2f'):format(name,g,(pos-mid).Magnitude,radius))end
  local base=W.module('PlantAccessRules').HarvestDistance
  if not near(reach,base+radius*Rules.Fruit(c,g,def).Scale,1e-6)then reachOk=false end
 end
 check(promptOk,name..': every harvest prompt position is within the fruit\'s radius of its parts')
 check(reachOk,name..': the harvest reach is HarvestDistance + the fruit radius x its scale, as before')
end

-- 4. Pictures: the real ItemPictures builds the hotbar / Bag / Index picture of each redesigned fruit ----------------------------------------------------
do
 local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=9;player.Parent=Players;Players.LocalPlayer=player
 local pg=R.new('PlayerGui');pg.Name='PlayerGui';pg.Parent=player
 local P=W.module('ItemPictures')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=pg
 local tools=R.new('Folder');tools.Parent=W.workspace
 local holders,expect={},{}
 local n=0
 for _,f in ipairs(FRUITS)do for i=1,f.Count do for _,coat in ipairs({'None',MUT_GOLD,MUT_DIAMOND})do
  n+=1;local tool=F.fruit(W,tools,f.Id,1,coat,100,i)
  local h=R.new('Frame');h.Name='Holder'..n;h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new((n-1)%20*62,math.floor((n-1)/20)*62)
  P.Show(h,tool,1);holders[#holders+1]=h
  local built=hotbar(f.Id,i,coat,'None','crop-'..f.Id);local vis=0;for _,p in ipairs(parts(built))do if p.Transparency<.95 then vis+=1 end end
  expect[#holders]={f.Name..' fruit '..i..' '..coat,vis}
 end end end
 for _=1,400 do W.frames(1)end
 local filled,partsOk=0,0
 for k,h in ipairs(holders)do
  local view=h:FindFirstChild('ItemViewport')
  if view then
   filled+=1;local count=0;for _,d in ipairs(view:GetDescendants())do if d:IsA('BasePart')then count+=1 end end
   if count==expect[k][2]then partsOk+=1 else print('  '..expect[k][1]..': picture has '..count..' parts, the harvest model '..expect[k][2])end
  end
 end
 check(filled==#holders,'every redesigned fruit gets its real 3D picture: '..filled..' of '..#holders..' holders (8 fruits, every fruit slot, plain / Gold / Diamond)')
 check(partsOk==filled,'each picture holds exactly the harvest model\'s visible parts ('..partsOk..' of '..filled..')')
 local flat=0;for _,d in ipairs(pg:GetDescendants())do if d.Name=='FlatIcon'then flat+=1 end end
 check(flat==0,'no flat icon is ever made')
 -- the picture key follows the art key (the Ash Tomato's four designs would otherwise share one picture)
 local seenKeys={};local ashKeys=0
 for k=1,60 do
  local tool=F.fruit(W,tools,'AshRoseSeed',1,'None',100,1);tool:SetAttribute('SourceCropId','ash-pic-'..k)
  local key=P.Key(tool);if not seenKeys[key]then seenKeys[key]=true;ashKeys+=1 end
 end
 check(ashKeys>=8,'the Ash Tomato\'s picture key tells the crop variants apart ('..ashKeys..' keys over 60 crops: 4 designs x the jitter)')
end

-- 5. Ash Tomato: four designs (the first is the base's, byte for byte), picked per crop ------------------------------------------------------------------------
do
 local id='AshRoseSeed';local def=Catalog[id]
 local raw=W.module('ApprovedPlantArt5');local base=Base.Ash
 check(#raw==4 and#base==1,'ApprovedPlantArt5 holds 4 designs (the base had 1)')
 check(deepEqual(raw[1],base[1]),'design 1 is the base\'s Ash Tomato exactly: specs, sockets, centres, radii, Height, Radius')
 local function bodyOf(design,g)for _,s in ipairs(design.Specs)do if s.g==g and s.f=='Squared ash tomato'then return s end end end
 local seenColours,seenHeights,seenSockets={},{},{}
 for di,d in ipairs(raw)do
  check(#d.Sockets==4 and#d.FruitCenters==4 and#d.FruitRadii==4,'design '..di..': 4 sockets / centres / radii (the same FruitCount)')
  local okNames=true
  for g=1,4 do if not sameTally(tally(d.Specs,g),tally(base[1].Specs,g))then okNames=false end end
  check(okNames,'design '..di..': each tomato has exactly the base\'s 11 specs (names and counts)')
  local g0=0;local leaves=0;for _,s in ipairs(d.Specs)do if s.g==0 then g0+=1;if s.f=='Ash tomato leaf'then leaves+=1 end end end
  check(g0==({51,51,46,41})[di]and leaves==({32,32,28,24})[di],'design '..di..': '..g0..' body parts, '..leaves..' leaf wedges (leaves swing, a few drop)')
  local ok=true;for i,s in ipairs(d.Specs)do if s._ArtIndex~=i or#s.c~=12 or#s.z~=3 then ok=false end end
  check(ok,'design '..di..': _ArtIndex = list position, 12 + 3 numbers per spec')
  seenColours[table.concat(bodyOf(d,1).k,',')]=true;seenHeights[string.format('%.3f',d.Height)]=true
  seenSockets[string.format('%.3f,%.3f',d.Sockets[1][1],d.Sockets[1][2])]=true
  -- sockets vs centres: each tomato's centre hangs below its socket, its body on that centre
  local sc=true
  for g=1,4 do
   local so,ce=d.Sockets[g],d.FruitCenters[g];local body=bodyOf(d,g)
   if dist({body.c[1],body.c[2],body.c[3]},ce)>.2 then sc=false end
   if ce[2]>=so[2]then sc=false end
  end
  check(sc,'design '..di..': every tomato body sits on its fruit centre, below its socket')
  local fr=true;for g=1,4 do local ratio=d.FruitRadii[g]/base[1].FruitRadii[g];if ratio<.8 or ratio>1.13 then fr=false end end
  check(fr,'design '..di..': fruit radii stay within .8 - 1.13 x the base\'s (harvest reach)')
  check(d.Height<=base[1].Height*1.02 and d.Radius<=base[1].Radius*1.15,('design %d: Height %.3f <= the base\'s %.3f, Radius %.3f'):format(di,d.Height,base[1].Height,d.Radius))
 end
 local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
 check(count(seenColours)==4,'the four designs have four different tomato reds ('..count(seenColours)..')')
 check(count(seenHeights)==4 and count(seenSockets)==4,'four different heights and socket layouts')
 -- every pair of designs differs in its spec list, not just in a number
 local pairsOk=true
 for a=1,4 do for b=a+1,4 do
  if deepEqual(raw[a],raw[b])then pairsOk=false end
  local same=0;for i=1,math.min(#raw[a].Specs,#raw[b].Specs)do if deepEqual(raw[a].Specs[i].c,raw[b].Specs[i].c)then same+=1 end end
  if same>#raw[a].Specs*.3 then pairsOk=false end
 end end
 check(pairsOk,'every pair of designs differs in the position of most parts')
 -- picked per crop by hash(crop.Id) % 4, deterministic, all four used, the jitter on top
 local function identify(art)local s=bodyOf(art,1);for di,d in ipairs(raw)do if kNear(s.k,bodyOf(d,1).k,.01)then return di end end;return 0 end
 local used={0,0,0,0};local keyToDesign={};local consistent=true;local heights={}
 for k=1,400 do
  local c={Id='ash-'..k,SeedId=id};local art=Approved.Get(id,c);local di=identify(art)
  used[di]=(used[di]or 0)+1
  local key=Approved.Key(id,c)
  if keyToDesign[key]and keyToDesign[key]~=di then consistent=false end;keyToDesign[key]=di
  if Approved.Get(id,c)~=art or Approved.Key(id,{Id='ash-'..k})~=key then consistent=false end
  heights[di]=heights[di]or{};heights[di][string.format('%.3f',art.Height)]=true
  if#art.Specs~=#raw[di].Specs or#art.Sockets~=4 then consistent=false end
 end
 check(consistent,'the same crop always gets the same art, and one Art.Key never names two designs (400 crops, '..count(keyToDesign)..' keys)')
 check(used[1]>=60 and used[2]>=60 and used[3]>=60 and used[4]>=60,'all four designs are used: '..table.concat(used,' / ')..' of 400 crops')
 local jitter=true;for di=1,4 do if count(heights[di])<3 then jitter=false end end
 check(jitter,'the size / turn jitter still varies each design (>= 3 heights each)')
 -- the old key could not tell the designs apart: one cache entry would serve two designs
 local mixed=false;local oldMap={}
 for k=1,400 do local c={Id='ash-'..k,SeedId=id};local key=OldApproved.Key(id,c);local di=identify(Approved.Get(id,c));if oldMap[key]and oldMap[key]~=di then mixed=true end;oldMap[key]=di end
 check(mixed,'(why Art.Key changed: the old key h % 10 named two designs of 4)')
 -- every build mode for one crop of each design
 local reps={};for k=1,400 do local di=identify(Approved.Get(id,{Id='ash-'..k}));if not reps[di]then reps[di]='ash-'..k end end
 local fruitColours={}
 for di=1,4 do
  local cid=reps[di];local c=crop(id,cid);local ripe=Visuals.Build(id,origin,c,4,math.huge)
  local groups=0;for g=1,4 do if#groupParts(ripe,g)==14 then groups+=1 end end
  check(groups==4 and#parts(ripe)>=90,'design '..di..' ('..cid..'): '..#parts(ripe)..' parts, 4 fruit groups of 14 parts (11 specs + the grain marks)')
  for _,fr in ipairs({0,.1,.5,.9,1})do check(pcall(Visuals.BuildGrowing,id,origin,c,fr*def.Seconds),'design '..di..': growing at '..fr*100 ..'% builds')end
  for g=1,4 do
   local h=hotbar(id,g,'None','None',cid);check(#parts(h,true)==13,'design '..di..' fruit '..g..': hotbar picture of 13 parts (the tomato looks as before)')
   if g==1 then for _,p in ipairs(parts(h))do if p.Name=='Squared ash tomato'then fruitColours[di]={rgb(p.Color)}end end end
   for _,coat in ipairs({MUT_GOLD,MUT_DIAMOND})do check(#parts(hotbar(id,g,coat,'None',cid),true)==13,'design '..di..' fruit '..g..' '..coat..': 13 parts')end
  end
  local far=Distant.Build(c,origin,def.Seconds+1);check(#parts(far)>0,'design '..di..': the far plant builds')
  addScene(scenePlants,labelsP,'Ash Tomato design '..di..' '..cid,ripe,false)
  for g=1,4 do addScene(sceneFruit,labelsF,'Ash Tomato design '..di..' fruit '..g,Visuals.BuildSelectedFruit(id,origin,c,{[g]=true},math.huge),true)end
  -- prompts follow this design's sockets
  local art=Approved.Get(id,c)
  for g=1,4 do
   local pos=Visuals.FruitPosition(c,def,g,math.huge)
   check((pos-V3(table.unpack(art.Sockets[g]))).Magnitude<=art.FruitRadii[g],'design '..di..' fruit '..g..': the harvest prompt sits within the fruit radius of this design\'s socket')
  end
 end
 local distinct,seen=0,{};for di=1,4 do local k=fruitColours[di];if k then local key=k[1]..','..k[2]..','..k[3];if not seen[key]then seen[key]=true;distinct+=1 end end end
 check(distinct==4,'the four designs\' hotbar tomatoes are four different shades of red')
end

-- 6. Unchanged: Lantern Fern, Amethyst Grape, every other art list and key -------------------------------------------------------------------------------
do
 check(deepEqual(W.module('ApprovedPlantArt2'),Base.Lantern),'Lantern Fern\'s art (ApprovedPlantArt2) is exactly the base\'s')
 check(deepEqual(W.module('PlantArtCrystal').AmethystSeed,Base.Crystal.AmethystSeed),'Amethyst Grape\'s art (PlantArtCrystal.AmethystSeed) is exactly the base\'s')
 check(#parts(hotbar('LanternFernSeed',1),true)==24 and#parts(hotbar('AmethystSeed',1),true)==162,'Lantern Fern\'s hotbar picture is 24 parts, Amethyst Grape\'s 162, as before')
 check(#parts(Visuals.Build('AmethystSeed',origin,crop('AmethystSeed','preview-AmethystSeed'),4,math.huge))==726,'the Amethyst Grape plant is still 726 parts')
 check(#parts(Visuals.Build('LanternFernSeed',origin,crop('LanternFernSeed','preview-LanternFernSeed'),4,math.huge))==206,'the Lantern Fern plant is still 206 parts')
 -- the other art modules the redesign touched hold their other plants exactly as before
 local same,total=0,0
 for _,e in ipairs({{'PlantArtForest',Base.Forest,'SunflowerSeed','BluebellSeed'},{'PlantArtSnow',Base.Snow,'SnowdropSeed','IceberrySeed'},{'PlantArtLava',Base.Lava,'EmberBloomSeed'}})do
  local new,old=W.module(e[1]),e[2]
  for seed,list in pairs(old)do
   local skip=false;for k=3,#e do if e[k]==seed then skip=true end end
   if not skip then total+=1;if deepEqual(list,new[seed])then same+=1 else print('  '..e[1]..'.'..seed..' changed')end end
  end
 end
 check(same==total and total>=15,'every other plant in PlantArtForest / PlantArtSnow / PlantArtLava is exactly the base\'s ('..same..' of '..total..')')
 for _,e in ipairs({{'TreeReworkData2','Apple'},{'TreeReworkData4','Elder'}})do
  local new,old=W.module(e[1]),Base[e[2]]
  local ok=deepEqual(new.Sockets,old.Sockets)and deepEqual(new.FruitCenters,old.FruitCenters)and deepEqual(new.FruitRadii,old.FruitRadii)and new.Height==old.Height and new.Radius==old.Radius
  local liveBody,oldBody={},{}
  for _,s in ipairs(new.Specs)do if s.g==0 then liveBody[#liveBody+1]=s end end
  for _,s in ipairs(old.Specs)do if s.g==0 then oldBody[#oldBody+1]=s end end
  check(ok and deepEqual(liveBody,oldBody),e[1]..': sockets / centres / radii / Height / Radius and every body spec (index included) are the base\'s ('..#liveBody..' body specs)')
 end
 -- the cactus: both designs keep their body, sockets, centres and Height / Radius; only the three fruit groups changed
 do
  local ok=true
  for di=1,2 do
   local new,old=W.module('ApprovedPlantArt6')[di],Base.Pear[di]
   if not(deepEqual(new.Sockets,old.Sockets)and deepEqual(new.FruitCenters,old.FruitCenters)and deepEqual(new.FruitRadii,old.FruitRadii)and new.Height==old.Height and new.Radius==old.Radius)then ok=false end
   local a,b={},{};for _,s in ipairs(new.Specs)do if s.g==0 then a[#a+1]=s end end;for _,s in ipairs(old.Specs)do if s.g==0 then b[#b+1]=s end end
   if not deepEqual(a,b)then ok=false end
  end
  check(ok,'Prickly Pear: both designs keep the body, sockets, centres, radii, Height and Radius')
 end
 -- Art.Key: the same strings as before for every approved plant except the Ash Tomato
 local keysOk=true;local compared=0
 for id in pairs(W.module('ApprovedPlantIndex'))do
  for k=0,24 do
   local c=k==0 and{Id='preview'}or{Id='key-'..k,SeedId=id}
   local a,b=Approved.Key(id,c),OldApproved.Key(id,c);compared+=1
   if id=='AshRoseSeed'then if k~=0 and not(a:sub(1,#b)==b and a:find('d%d$'))then keysOk=false end elseif a~=b then keysOk=false;print('  key '..id..' '..tostring(a)..' vs '..tostring(b))end
  end
 end
 check(keysOk,'Art.Key is unchanged for every approved plant ('..compared..' keys); the Ash Tomato\'s gains a design suffix')
end

-- 7. Floating parts: the scenes go to check_floating.py (R134) ----------------------------------------------------------------------------------------------
do
 -- also the controls: the unchanged Lantern Fern and Amethyst Grape, and the Prickly Pear
 for _,cid in ipairs({'ctl-1','ctl-2'})do
  for _,id in ipairs({'LanternFernSeed','AmethystSeed','CactusSeed'})do addScene(scenePlants,labelsP,id..' '..cid,Visuals.Build(id,origin,crop(id,cid),4,math.huge),false)end
 end
 -- every redesigned fruit alone, strict (an ellipsoid is an ellipsoid): all of a fruit's parts hang together
 for _,f in ipairs(FRUITS)do for g=1,f.Count do
  addScene(sceneFruit,labelsF,f.Name..' fruit '..g,Visuals.BuildSelectedFruit(f.Id,origin,crop(f.Id,'fl-1'),{[g]=true},math.huge),true)
  addScene(sceneFruit,labelsF,f.Name..' fruit '..g..' (held)',Visuals.BuildSelectedFruit(f.Id,origin,crop(f.Id,'fl-1',{_DetachedHarvest=true}),{[g]=true},math.huge),true)
 end end
 local function label(labels)local o={};for i,l in ipairs(labels)do o[i]=('{"text":"%s"}'):format(l)end;return table.concat(o,',')end
 print('SCENE_PLANTS {"parts":['..table.concat(scenePlants,',')..'],"labels":['..label(labelsP)..']}')
 print('SCENE_FRUIT {"parts":['..table.concat(sceneFruit,',')..'],"labels":['..label(labelsF)..']}')
end

print(('R149 fruit models: %d checks, %d failures'):format(checks,fails))
if fails>0 then error(fails..' checks failed')end
