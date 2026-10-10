--!nocheck
-- R158 outer track: the pure data (OuterTrackAssets158 = the keys, ids, spots; OuterTrackModels158 = the owner's part-built models as packed data; TrackWallSpecs158 = the ground slabs)
-- checked without a world. Prints "ok <name>" / "FAIL <name>: why"; errors at the end if anything failed.
--  1. every key has an id slot, a status and at least one spot; every spot belongs to a key; the ids the owner gave are in (9981304 pyramid, 5138892863 volcano); the order of the keys
--  2. every spot's box obeys the rules: all of it at |x| >= 100 (or behind the end wall), off the hub, on the ground
--  3. the owner's pyramid: 82 blocks of his file, the same box (128 x 84 x 140), scaled to the spot's box, every block above the ground, in the file's colour / material; the dark mountain:
--     280 of his 1,532 blocks (the cut is stated), welds / lights / meshes gone; yaw / mirror / scale move the parts the way they should; deterministic
--  4. the snow hills' data: 16 hills, the four mesh ids of the file; the ground slabs
local Assets=require('./OuterTrackAssets158');local Models=require('./OuterTrackModels158');local Specs=require('./TrackWallSpecs158')
local passed,failed=0,0
local function check(name,cond,why)if cond then passed+=1;print('ok '..name)else failed+=1;print('FAIL '..name..(why and(': '..tostring(why))or''))end end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end

-- 1. keys and ids ----------------------------------------------------------------------------------------------------------------------------------
local keys={};for i,k in ipairs(Assets.Keys)do keys[k.Key]=i end
local nKeys=#Assets.Keys
check('keys: '..nKeys..' keys, each once',nKeys==14 and(function()local n=0;for _ in pairs(keys)do n+=1 end;return n==nKeys end)())
-- (owner: "forest and jungle can just have large trees": the Jungle's temple and cliff are gone, keys, ids, spots and all)
local goneKeys=true;local goneSlots=true
for _,old in ipairs({'JungleTemple','JungleCliff','ForestOak'})do
 if keys[old]or Assets.Ids[old]~=nil or Assets.Game[old]~=nil then goneKeys=false end
 for _,s in ipairs(Assets.Slots)do if s.Key==old then goneSlots=false end end
end
check('keys: JungleTemple and JungleCliff are gone (no key, no id, no spot), and the old ForestOak key is ForestTree now',goneKeys and goneSlots and keys.ForestTree~=nil and keys.JungleTree~=nil)
local missingId,missingSlot,missingSource
for _,k in ipairs(Assets.Keys)do
 if type(Assets.Ids[k.Key])~='number'then missingId=k.Key end
 if #Assets.SlotsOf(k.Key)==0 then missingSlot=k.Key end
 if not(k.Source=='owner'or k.Source=='game'or k.Source=='waiting')then missingSource=k.Key end
end
check('keys: every key has an Ids entry (a number, 0 = not set), at least one spot and a status (owner / game / waiting)',missingId==nil and missingSlot==nil and missingSource==nil,tostring(missingId or missingSlot or missingSource))
local stray;for _,s in ipairs(Assets.Slots)do if not keys[s.Key]then stray=s.Key end end
check('keys: every spot belongs to a listed key',stray==nil,stray)
local extraIds;for k in pairs(Assets.Ids)do if not keys[k]then extraIds=k end end
check('keys: the Ids table has no key that is not listed',extraIds==nil,extraIds)
check('keys: the owner\'s ids are in: DesertPyramid 9981304, LavaVolcano 5138892863',Assets.Ids.DesertPyramid==9981304 and Assets.Ids.LavaVolcano==5138892863)
check('keys: the volcano\'s mesh and texture are the file\'s (5138886694 / 5138888007), size 69.97 x 52.65 x 59.82',Assets.Mesh.LavaVolcano.MeshId=='rbxassetid://5138886694'and Assets.Mesh.LavaVolcano.TextureId=='rbxassetid://5138888007'
 and near(Assets.Mesh.LavaVolcano.Size[1],69.97479248046875)and near(Assets.Mesh.LavaVolcano.Size[2],52.653690338134766)and near(Assets.Mesh.LavaVolcano.Size[3],59.81602096557617))
check('keys: the game-model sources name a biome folder and a model name each',(function()for k,g in pairs(Assets.Game)do if not(keys[k]and g.Biome and g.Name)then return false end end;return true end)())
check('keys: the outer track casts no shadow by default (the design)',Assets.Shadows==false)
local count={};for _,s in ipairs(Assets.Slots)do count[s.Key]=(count[s.Key]or 0)+1 end
check('keys: spots per key: ForestTree 14, JungleTree 29, DesertPyramid 1, SnowTree 8, SnowMountains 2, LavaVolcano 4, CrystalSpire 6, StormDarkMount 4',count.ForestTree==14 and count.JungleTree==29 and count.DesertPyramid==1 and count.SnowTree==8 and count.SnowMountains==2 and count.LavaVolcano==4 and count.CrystalSpire==6 and count.StormDarkMount==4)

-- 2. the rules for every spot ------------------------------------------------------------------------------------------------------------------------
local bad
for i,s in ipairs(Assets.Slots)do
 local b=Assets.Box(s)
 local behind=b[5]>5990
 if not behind and(b[1]<100 and b[2]>-100)then bad=bad or(i..' '..s.Key..' reaches inside |x| 100 (x '..b[1]..' .. '..b[2]..')')end
 if b[5]<-99 then bad=bad or(i..' '..s.Key..' is over the hub')end
 if s.W<=0 or s.H<=0 or s.D<=0 then bad=bad or(i..' '..s.Key..' has no size')end
 if(s.Y or Assets.Ground)<Assets.Ground-1e-9 then bad=bad or(i..' '..s.Key..' starts under the ground')end
end
check('spots: every box is at |x| >= 100 (or behind the end wall) and off the hub (z >= -99)',bad==nil,bad)
local ge=0;for _,s in ipairs(Assets.Slots)do if s.Key=='DesertPyramid'then ge=Assets.Box(s)[1]end end
check('spots: the great pyramid stands far right, clear of the R157 pyramid at x -62 (box starts at x '..string.format('%.0f',ge)..')',ge>200)
local variety=true
for _,key in ipairs({'ForestTree','JungleTree','SnowTree','CrystalSpire','LavaVolcano','StormDarkMount'})do
 local seen={};local n=0
 for _,s in ipairs(Assets.SlotsOf(key))do local sig=string.format('%.1f|%.1f|%s|%s',s.H,s.Yaw,tostring(s.Tint and s.Tint[1]),tostring(s.Scale));if not seen[sig]then seen[sig]=true;n+=1 end end
 if n<#Assets.SlotsOf(key)then variety=false end
end
check('spots: no two spots of one key are copies (height, turn, tint, scale differ)',variety)
local volcanoes=Assets.SlotsOf('LavaVolcano');local tilts,tints,glows=0,0,0
for _,s in ipairs(volcanoes)do if s.Tilt and s.Tilt~=0 then tilts+=1 end;if s.Tint then tints+=1 end;if s.Glow then glows+=1 end end
local minH,maxH=math.huge,0;for _,s in ipairs(volcanoes)do minH=math.min(minH,s.H);maxH=math.max(maxH,s.H)end
check('spots: the four outer volcanoes differ in scale ('..string.format('%.0f - %.0f',minH,maxH)..' tall: x'..string.format('%.1f',maxH/minH)..'), all tilted a little, all tinted, some glowing at the mouth',maxH/minH>=1.8 and tilts==4 and tints==4 and glows>=1 and glows<4)
local fits=true
for _,s in ipairs(volcanoes)do local v=Assets.Mesh.LavaVolcano.Size;local k=s.H/v[2];if not(near(s.W,v[1]*k,.2)and near(s.D,v[3]*k,.2))then fits=false end end
check('spots: a volcano spot\'s box keeps the file\'s proportions (70 : 52.65 : 59.8)',fits)

-- 2b. the Forest and Jungle trees (owner: "forest and jungle can just have large trees on the outside with our current game assets") ----------------------------------------------------
-- Only large trees, several different models per biome (the game's own: the map's oak / jungle tree, the hub's oak / poplar / palm), uneven heights, every turn, close tints, along the
-- whole length of the biome on both sides, a denser and taller back row, never over the hub, never inside |x| 100, never past the biome's own ends.
local biomeOf={};for _,b in ipairs(Specs.Biomes)do biomeOf[b.Name]=b end
local function meanSd(list)
 local n,sum=#list,0;for _,v in ipairs(list)do sum+=v end
 local mean=n>0 and sum/n or 0;local sq=0;for _,v in ipairs(list)do sq+=(v-mean)^2 end
 return mean,math.sqrt(sq/math.max(n,1))
end
local HUB_KINDS={Oak=true,Leafy=true,Poplar=true,Palm=true}
for _,def in ipairs({{Key='ForestTree',Biome='Forest'},{Key='JungleTree',Biome='Jungle'}})do
 local key,b=def.Key,biomeOf[def.Biome]
 local spots=Assets.SlotsOf(key);local n=#spots
 local z0,z1=math.max(b.Z0,-99),b.Z1
 local label=def.Biome..' trees'
 -- the models of the key: the map's (Max, plus the Also entries') then the hub's recipes
 local g=Assets.Game[key];local nModels=g.Max or 1
 for _,e in ipairs(g.Also or{})do nModels+=e.Max or 1 end
 local recipes,dupe,badKind={},nil,nil
 for _,r in ipairs(g.Hub or{})do
  local sig=table.concat({r.Kind,tostring(r.Arg),tostring(r.X),tostring(r.Z)},'|')
  if recipes[sig]then dupe=sig end;recipes[sig]=true
  if not HUB_KINDS[r.Kind]then badKind=r.Kind end
 end
 nModels+=#(g.Hub or{})
 check(label..': the key has '..nModels..' models (the map\'s and the hub\'s: no recipe twice, each a known kind)',nModels>=7 and dupe==nil and badKind==nil,tostring(dupe or badKind))
 local looks,hs,yaws,tints,tintSet,sides,badLook={},{}, {},{}, {},{[-1]=0,[1]=0},nil
 local outside,hub,inZ=nil,nil,nil
 local minEdge={[-1]=math.huge,[1]=math.huge}
 local zlo,zhi={[-1]=math.huge,[1]=math.huge},{[-1]=-math.huge,[1]=-math.huge}
 local front,back={},{}
 for i,s in ipairs(spots)do
  local box=Assets.Box(s)
  local side=s.X<0 and-1 or 1
  sides[side]+=1
  looks[s.Look or 0]=(looks[s.Look or 0]or 0)+1
  if type(s.Look)~='number'or s.Look<1 or s.Look>nModels or s.Look~=math.floor(s.Look)then badLook=badLook or i end
  hs[#hs+1]=s.H;yaws[#yaws+1]=s.Yaw
  tints[#tints+1]=s.Tint;tintSet[table.concat(s.Tint or{},',')]=true
  if box[1]<100 and box[2]>-100 then outside=outside or(label..' spot '..i..' reaches inside |x| 100')end
  if box[5]<-99 then hub=hub or(label..' spot '..i..' is over the hub')end
  if box[5]<z0-.01 or box[6]>z1+.01 then inZ=inZ or(label..' spot '..i..' (z '..string.format('%.0f',box[5])..' .. '..string.format('%.0f',box[6])..') leaves the biome ('..z0..' .. '..z1..')')end
  zlo[side]=math.min(zlo[side],box[5]);zhi[side]=math.max(zhi[side],box[6])
  local inner=side<0 and-box[2]or box[1]
  if inner<=125 then front[#front+1]=s elseif inner>=210 then back[#back+1]=s end
 end
 check(label..': every box is at |x| >= 100 and off the hub (z >= -99)',outside==nil and hub==nil,outside or hub)
 check(label..': every box stays inside the biome\'s own stretch (z '..z0..' .. '..z1..')',inZ==nil,inZ)
 check(label..': '..n..' spots, '..sides[-1]..' on the left and '..sides[1]..' on the right (a forest on both sides)',sides[-1]>=6 and sides[1]>=6 and math.abs(sides[-1]-sides[1])<=3 and n>=14)
 check(label..': along the WHOLE length on both sides (the first box starts within 25 studs of the biome\'s start, the last ends within 25 of its end)',
  zlo[-1]<=z0+25 and zlo[1]<=z0+25 and zhi[-1]>=z1-25 and zhi[1]>=z1-25,string.format('left %.0f .. %.0f, right %.0f .. %.0f',zlo[-1],zhi[-1],zlo[1],zhi[1]))
 local minH,maxH=math.huge,0;for _,h in ipairs(hs)do minH=math.min(minH,h);maxH=math.max(maxH,h)end
 local _,sdH=meanSd(hs)
 check(label..': only LARGE trees, heights uneven ('..string.format('%.0f - %.0f studs, spread %.0f',minH,maxH,sdH)..'): none under 75, the tallest over 140, a forest-like skyline',minH>=75 and maxH>=140 and maxH/minH>=1.5 and sdH>=15)
 local hSet,hDupe={},false
 for _,h in ipairs(hs)do local k=math.floor(h*2+.5);if hSet[k]then hDupe=true end;hSet[k]=true end
 check(label..': no two trees have the same height (no stamped copies)',not hDupe)
 local distinct=0;for lk,c in pairs(looks)do distinct+=1 end
 local maxShare=0;for _,c in pairs(looks)do maxShare=math.max(maxShare,c/n)end
 check(label..': '..distinct..' different models in use (at least 6), no one of them more than 40 % of the trees ('..string.format('%.0f %%',maxShare*100)..'), every Look is one of the key\'s models',distinct>=6 and maxShare<=.4 and badLook==nil,badLook)
 local yawSet,ylo,yhi={},math.huge,-math.huge;for _,y in ipairs(yaws)do yawSet[y]=true;ylo=math.min(ylo,y);yhi=math.max(yhi,y)end
 local ny=0;for _ in pairs(yawSet)do ny+=1 end
 check(label..': every tree its own turn ('..ny..' different of '..n..', from '..ylo..' to '..yhi..' degrees)',ny>=n-2 and yhi-ylo>=270)
 local nt=0;for _ in pairs(tintSet)do nt+=1 end
 local closeTints=true
 for i=1,n do for j=i+1,n do if spots[i].Look==spots[j].Look then for c=1,3 do if math.abs(spots[i].Tint[c]-spots[j].Tint[c])>14 then closeTints=false end end end end end
 check(label..': '..nt..' different tints, the trees of one model only a few shades apart (within 14 of 255)',nt>=n-2 and closeTints)
 local mf,mb=0,0
 do local a=0;for _,s in ipairs(front)do a+=s.H end;mf=#front>0 and a/#front or 0;a=0;for _,s in ipairs(back)do a+=s.H end;mb=#back>0 and a/#back or 0 end
 check(label..': a denser, taller back row ('..#back..' trees with their inner edge past x 210, mean height '..string.format('%.0f',mb)..'; the front row (inner edge by x 125): '..#front..' trees, mean '..string.format('%.0f',mf)..')',#back>=#front+1 and #front>=3 and mb>=mf+15)
 local closest=math.huge
 for i=1,n do for j=i+1,n do local dx,dz=spots[i].X-spots[j].X,spots[i].Z-spots[j].Z;closest=math.min(closest,math.sqrt(dx*dx+dz*dz))end end
 check(label..': no two trees stand on one another (the closest trunks are '..string.format('%.0f',closest)..' studs apart)',closest>=20)
 local rowOf={}
 -- a grid would repeat: the z gaps between neighbours in each row are not even
 local lanes={front={},mid={},back={}}
 for _,s in ipairs(spots)do
  local box=Assets.Box(s);local side=s.X<0 and-1 or 1;local inner=side<0 and-box[2]or box[1]
  local lane=inner<=125 and'front'or inner>=210 and'back'or'mid'
  local l=lanes[lane];l[side]=l[side]or{};table.insert(l[side],s.Z)
 end
 local evenLane
 for name,sidesZ in pairs(lanes)do for side,zs in pairs(sidesZ)do
  table.sort(zs)
  if #zs>=4 then local gaps={};for i=2,#zs do gaps[#gaps+1]=zs[i]-zs[i-1]end;local m,sd=meanSd(gaps);if sd/m<.12 then evenLane=evenLane or(name..' row, side '..side)end end
 end end
 check(label..': no row is evenly spaced (no grid)',evenLane==nil,evenLane)
end

-- 3. the owner's models as data ----------------------------------------------------------------------------------------------------------------------
local P=Models.Pyramid
check('pyramid: 82 blocks of the owner\'s file, box 128 x 84 x 140, Concrete 215,197,154 (asset 9981304)',P.Count==82 and #Models.Parts(P)==82 and near(P.Box[1],128,.01)and near(P.Box[2],84,.01)and near(P.Box[3],140,.01)and P.Material=='Concrete'and P.Color[1]==215 and P.Color[2]==197 and P.Color[3]==154)
local pspot=Assets.SlotsOf('DesertPyramid')[1]
local specs,k=Models.Specs(P,{X=pspot.X,Z=pspot.Z,Y=Assets.Ground,Fit={pspot.W,pspot.H,pspot.D},Yaw=pspot.Yaw,Group='x',Name='Pyramid'})
local lo,hi={1e9,1e9,1e9},{-1e9,-1e9,-1e9}
local below=0
for _,s in ipairs(specs)do local a,b=Specs.Extent(s);for i=1,3 do lo[i]=math.min(lo[i],a[i]);hi[i]=math.max(hi[i],b[i])end;if a[2]<Assets.Ground-1e-6 then below+=1 end end
check('pyramid: scaled evenly to the spot\'s box ('..string.format('x%.3f',k)..'): the model is '..string.format('%.1f x %.1f x %.1f',hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3])..', stands on the ground, centred on the spot',
 near(hi[1]-lo[1],P.Box[1]*k,.05)and near(hi[2]-lo[2],P.Box[2]*k,.05)and near(lo[2],Assets.Ground,.01)and below==0 and near((lo[1]+hi[1])/2,pspot.X,.05)and near((lo[3]+hi[3])/2,pspot.Z,.05)and hi[3]-lo[3]<=pspot.D+.1,
 string.format('%.2f %.2f %.2f',hi[1]-lo[1],hi[2]-lo[2],hi[3]-lo[3]))
check('pyramid: every spec is a block with the file\'s colour and material, no shadow (outer track), nothing transparent',(function()for _,s in ipairs(specs)do if not(s.Shape=='Block'and s.Material=='Concrete'and s.Color[1]==215 and s.Shadow==false and s.Transparency==0)then return false end end;return true end)())
local specs2=Models.Specs(P,{X=pspot.X,Z=pspot.Z,Y=Assets.Ground,Fit={pspot.W,pspot.H,pspot.D},Yaw=pspot.Yaw,Group='x',Name='Pyramid'})
local same=true;for i,s in ipairs(specs)do for j=1,12 do if s.CF[j]~=specs2[i].CF[j]then same=false end end end
check('pyramid: the same call gives the same parts (deterministic)',same)
-- the stacked slabs: no two same-facing faces of the model share a plane (the pyramid is a stack of slabs: the tops / bottoms of two slabs touch face to face, which is not a fight) -> checked
-- as geometry: no two blocks have the same size and place
local seen,dup={},0
for _,s in ipairs(specs)do local key=string.format('%.3f|%.3f|%.3f|%.3f|%.3f|%.3f',s.Size[1],s.Size[2],s.Size[3],s.CF[1],s.CF[2],s.CF[3]);if seen[key]then dup+=1 end;seen[key]=true end
check('pyramid: no two blocks are the same block twice',dup==0,dup)
local D=Models.DarkMount
check('dark mountain: '..D.Count..' of the file\'s '..D.Cut.Of..' blocks (172 "Steps" dropped, the silhouette overlap front '..string.format('%.1f',100*D.Cut.Iou[1])..' %, side '..string.format('%.1f',100*D.Cut.Iou[2])..' %, top '..string.format('%.1f',100*D.Cut.Iou[3])..' %), colour 27,42,53',
 D.Count==280 and #Models.Parts(D)==280 and D.Cut.Of==1532 and D.Cut.Steps==172 and D.Cut.Iou[1]>.97 and D.Cut.Iou[2]>.96 and D.Cut.Iou[3]>.99 and D.Color[1]==27 and D.Color[2]==42 and D.Color[3]==53)
local mspots=Assets.SlotsOf('StormDarkMount')
local sides={[-1]=0,[1]=0};for _,s in ipairs(mspots)do sides[s.X<0 and-1 or 1]+=1 end
check('dark mountain: two copies each side of the Storm Peaks track (at most 2 per side), each copy '..D.Count..' parts ('..(D.Count*#mspots)..' in all)',sides[-1]==2 and sides[1]==2)
local variants={}
for i,s in ipairs(mspots)do local sp=Models.Specs(D,{X=s.X,Z=s.Z,Y=Assets.Ground,Fit={s.W,s.H,s.D},Yaw=s.Yaw,Mirror=s.Mirror,Group='x',Name='Mount'});variants[i]=sp
 local a,b={1e9,1e9,1e9},{-1e9,-1e9,-1e9};for _,q in ipairs(sp)do local l,h=Specs.Extent(q);for j=1,3 do a[j]=math.min(a[j],l[j]);b[j]=math.max(b[j],h[j])end end
 local box=Assets.Box(s)
 check('dark mountain: copy '..i..' (scale '..tostring(s.Scale)..', turn '..s.Yaw..(s.Mirror and', mirrored'or'')..') lies inside its spot\'s box, at |x| >= 100',a[1]>=box[1]-.5 and b[1]<=box[2]+.5 and a[3]>=box[5]-.5 and b[3]<=box[6]+.5 and a[2]>=Assets.Ground-.01 and math.min(math.abs(a[1]),math.abs(b[1]))>=100,
  string.format('x %.0f..%.0f z %.0f..%.0f (box x %.0f..%.0f z %.0f..%.0f)',a[1],b[1],a[3],b[3],box[1],box[2],box[5],box[6]))
end
-- mirror really mirrors: the first copy mirrored has x -> -x
local m0=Models.Specs(D,{X=0,Z=0,Y=0,Scale=1,Group='x',Name='M'});local m1=Models.Specs(D,{X=0,Z=0,Y=0,Scale=1,Mirror=true,Group='x',Name='M'})
local mirrorOk=true;for i=1,#m0 do if not near(m0[i].CF[1],-m1[i].CF[1],1e-6)or not near(m0[i].CF[3],m1[i].CF[3],1e-6)or not near(m0[i].CF[2],m1[i].CF[2],1e-6)then mirrorOk=false end end
check('dark mountain: Mirror swaps left and right (x -> -x, same height and depth)',mirrorOk)
local y0=Models.Specs(D,{X=0,Z=0,Y=0,Scale=1,Yaw=90,Group='x',Name='M'})
local turnOk=true;for i=1,#m0 do if not near(y0[i].CF[1],m0[i].CF[3],1e-6)or not near(y0[i].CF[3],-m0[i].CF[1],1e-6)then turnOk=false end end
check('dark mountain: Yaw 90 turns every block a quarter turn about the base centre ((x, z) -> (z, -x))',turnOk)
local sizeOk=true;for i=1,#m0 do local a=Models.Specs(D,{X=0,Z=0,Y=0,Scale=2,Group='x',Name='M'});if not near(a[i].Size[1],m0[i].Size[1]*2,1e-6)or not near(a[i].CF[2],m0[i].CF[2]*2,1e-6)then sizeOk=false;break end end
check('dark mountain: Scale 2 doubles every block and every distance from the base centre',sizeOk)
local blocks=0;for _,s in ipairs(m0)do if s.Shape=='Block'and s.Material=='Grass'then blocks+=1 end end
check('dark mountain: all blocks, no welds / lights / meshes (the data holds only boxes)',blocks==#m0)
local rotOk=true
for _,s in ipairs(m0)do local c=s.CF;local r={{c[4],c[5],c[6]},{c[7],c[8],c[9]},{c[10],c[11],c[12]}}
 for i=1,3 do local n=0;for j=1,3 do n+=r[i][j]^2 end;if not near(n,1,1e-4)then rotOk=false end end
 local det=r[1][1]*(r[2][2]*r[3][3]-r[2][3]*r[3][2])-r[1][2]*(r[2][1]*r[3][3]-r[2][3]*r[3][1])+r[1][3]*(r[2][1]*r[3][2]-r[2][2]*r[3][1]);if not near(det,1,1e-4)then rotOk=false end end
check('dark mountain: every turn is a proper rotation (unit rows, determinant 1), also mirrored',rotOk)

-- 4. the hills and the ground --------------------------------------------------------------------------------------------------------------------------
local H=Models.SnowHills;local rows=0;for _ in string.gmatch(H.Packed,'[^;]+')do rows+=1 end
check('hills: 16 hills of the owner\'s file, the four mesh ids (5150938211 grass, 5150934668 stone, 5153142324 trunk, 5153169732 leaves), box 188 x 38.2 x 268.6',rows==16 and H.Mesh.Grass=='rbxassetid://5150938211'and H.Mesh.Stone=='rbxassetid://5150934668'and H.Mesh.Trunk=='rbxassetid://5153142324'and H.Mesh.Leaves=='rbxassetid://5153169732'and near(H.Box[1],188,.1)and near(H.Box[3],268.6,.1))
local g=Specs.Backdrops()
local onlyGround=true;for _,s in ipairs(g)do if s.Name~='Outer ground'then onlyGround=false end end
check('ground: the outer track builds ONLY ground slabs from parts ('..#g..'), no trees, mountains, dunes or spires of parts',onlyGround and #g==15)
local gr=true;for _,s in ipairs(g)do local a,b=Specs.Extent(s);if not near(b[2],Specs.Ground.Top,1e-6)or math.max(s.Size[1],s.Size[2],s.Size[3])>2048 or s.Shadow~=false then gr=false end end
check('ground: every slab\'s top is the ground height ('..Specs.Ground.Top..'), no slab is over 2,048 studs, none casts a shadow',gr)
print('R158 outer data: '..passed..' checks passed, '..failed..' failed')
if failed>0 then error('R158 outer data: '..failed..' checks failed')end
