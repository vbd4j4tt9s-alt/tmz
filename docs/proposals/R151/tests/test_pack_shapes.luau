--!nocheck
-- R151 (owner: "make pack shape variations in blender", then "every pack can spawn with either of those variations ... shapes for visual representation in the index can just
-- use the default pack shape"): PackShapes151 and its builders on the Roblox mock with the REAL modules of this checkout, the REAL pack templates of the owner's place
-- (pack_templates.luau: 42 designs, 115 MeshParts) and a mock EditableMesh route whose meshes are lattices that fill each template part's Size box (pouch_mock.luau).
-- Every pack ROLLS one of the six variations when it is made (a per-pack-instance field, PackShape) and keeps it for life; the Index / catalogues / shops show the default.
--  1. the field      PackShapes151.Field against the Blender design's samples (pack_shape_samples.luau) and what every field promises (y fixed, crimps untouched, <= 5%)
--  2. the roll       which variants take a shape, Sanitize, the dice -> variation mapping, the distribution (uniform), forced / off, the variants that take none
--  3. the bake       one (design, variation) PAIR at a time: the template's own MeshId loaded, every vertex moved by the field (y and the crimp rows exactly where they
--                    were, <= 5% outward), colours / UVs never set, normals turned, ONE EditableMesh alive at a time, destroyed; all 252 pairs (42 designs x 6)
--  4. contexts       ground, held R15 / R6, CarryBag, picture, opening copy, market, mystery pedestal, viewport; sizes 1 / 25; None / Gold / Diamond: the same shaped pouch part
--                    for part; seal and strips exactly the default pack's; no shape (the Index, the catalogues), shape 0 and 'off' = the default pack; the Void / Mech ignore it
--  5. never yields   a build never waits: while a pair is being baked a server's pack is the default shape this once, a client's picture errors "still loading"; Settle keeps
--                    a new pack's roll only when its pair is baked, else 0 for life; Await is bounded
--  6. fallbacks      denied / no vertices / no positions / bake or MeshPart fails / size mismatch / too many vertices / missing or incomplete template / 2nd mesh fails / a bake
--                    that never returns: the default pack, exactly, one warning, nothing leaked, STICKY (a later success does not flip it), other pairs still bake
--  7. budget (LRU)   evicts the least recently used unpinned pair above the soft cap, honours the grace period and the pins, the idle sweep, the hard cap (a pair that does not
--                    fit fails for good: stable), a rebake gives the same pack, built packs outlive their template, the accounting
--  8. switches       off / auto / forced, the display flip drops the cache and tells the listeners, a forced number is only the roll of new packs, the status folder
--  9. pictures       the real ItemPictures: the key carries the shape, two shapes = two pictures, the Index / sample / proxy pictures are the default, still loading -> retry,
--                    a failed pair is a stable default picture, off / auto redraw
-- 10. Verity         (R152) NEVER shaped: Applies excludes it, it never rolls, carries or bakes a pair, and every context builds the one flat pouch of VerityPouch151 whatever a record, a flag or a stale attribute says
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local Samples=require('./pack_shape_samples')
local typeof=R.typeof
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function nearV(a,b,tol)return(a-b).Magnitude<=(tol or 1e-6)end
local function inv(c)return c:Inverse()end
local Run=W.Run
local function server()Run.IsServer=function()return true end;Run.IsClient=function()return false end end
local function client()Run.IsServer=function()return false end;Run.IsClient=function()return true end end
server() -- (before the first require of PackShapes151 / VerityPouch151: a server creates its folder when the module loads)
local Shapes=W.module('PackShapes151');local Pouch=W.module('VerityPouch151');local Visuals=H.Visuals;local Rules=H.Rules
local VERITY=H.VERITY
local warns=function()return W.warns or 0 end
local function folder()return W.RS:FindFirstChild(Shapes.Folder)end
local DEFAULTS={Enabled=true,Force=nil,LoadingSeconds=60,HoldWaitSeconds=2.5,MaxVertices=60000,MaxResidentVertices=400000,HardResidentVertices=600000,GraceSeconds=30,IdleSeconds=900,SweepSeconds=60}
local function fresh()
 Shapes.Reset();Mock.reset();for k,v in pairs(DEFAULTS)do Shapes.Config[k]=v end;Shapes.Config.Force=nil
 local f=folder();if f then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)end
 local v=W.RS:FindFirstChild(Pouch.Folder);if v then v:Destroy()end
end
local assets=W.RS.SeedPackMeshAssets
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do p.MeshSize=p.Size end end -- (the place's templates have a MeshSize; the generated ones do not)
-- every design of the game, in the order stage x tier
local DESIGNS={}
for stage=1,7 do for tier=1,6 do DESIGNS[#DESIGNS+1]={Key=Rules.DesignKey(stage,string.format('Pack%02d',tier)),Stage=stage,Variant=string.format('Pack%02d',tier),Tier=tier,Biome=Rules.DesignBiomes[stage]}end end
local function meshesOf(key)local l={};for _,p in ipairs(assets[key]:GetChildren())do if p:IsA('MeshPart')then l[#l+1]=p end end;table.sort(l,function(a,b)return a.Name<b.Name end);return l end
local SINGLE={};for _,d in ipairs(DESIGNS)do if #meshesOf(d.Key)==1 then SINGLE[#SINGLE+1]=d end end -- (one MeshPart: a pair is one mesh)
local function boxOf(parts)
 local lo,hi=V3(1e9,1e9,1e9),V3(-1e9,-1e9,-1e9)
 for _,p in ipairs(parts)do local f=p:GetAttribute('PackLocalFrame')
  for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
   local q=f*V3(p.Size.X*x,p.Size.Y*y,p.Size.Z*z);lo=V3(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=V3(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))
  end end end end
 return lo,hi
end
local function sig(bag)
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1;local out={}
 for _,p in ipairs(H.partsOf(bag,false))do
  local f=inv(root.CFrame)*p.CFrame
  out[(p.Parent==bag and''or'PackGeometry/')..p.Name]={Size=p.Size/scale,Pos=f.Position/scale,Frame=f,Class=p._class,MeshId=p._props.MeshId}
 end
 return out
end
local function cfDelta(a,b)local d=(a.Position-b.Position).Magnitude;local r=0;for _,axis in ipairs({'RightVector','UpVector','LookVector'})do r=math.max(r,math.acos(math.clamp(a[axis]:Dot(b[axis]),-1,1)))end;return d,r end
local function sameSig(a,b)
 for k,x in pairs(a)do
  local y=b[k];if not y then return false,'missing '..k end
  local d=math.max((x.Size-y.Size).Magnitude,(x.Pos-y.Pos).Magnitude,select(2,cfDelta(x.Frame,y.Frame))*.1)
  if d>1e-5 then return false,k..' differs by '..string.format('%.5f',d)end
  if x.Class~=y.Class then return false,k..' is a '..x.Class..' / '..y.Class end
 end
 for k in pairs(b)do if not a[k]then return false,'extra '..k end end
 return true
end
local function rgb(c)return math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)end
local function sameColor(a,b)local r1,g1,b1=rgb(a);local r2,g2,b2=rgb(b);return r1==r2 and g1==g2 and b1==b2 end
local function reasonOf(key,id,neutral)local _,why=Shapes.State(key,id,neutral);return tostring(why)end
local function pouchOf(bag)return bag:FindFirstChild('ApprovedMesh01',true)end
local function design(stage,variant)return Rules.DesignKey(stage,variant)end
-- the default pack of a stage / variant: no shape at all (what the Index builds)
local function defaultPack(stage,variant,size,coat)local b=H.ground(stage,variant,size or 1,coat or'None');local s=sig(b);b:Destroy();return s end
local function bakeNow(key,id,neutral)Shapes.Request(key,id,neutral);return Shapes.State(key,id,neutral)end

-- 1. The field ------------------------------------------------------------------------------------------------------------------------------------
do
 local worst=0
 for _,row in ipairs(Samples)do
  local id,u,v,w,a,b,c=table.unpack(row);local x,y,z=Shapes.Field(id,u,v,w)
  worst=math.max(worst,math.abs(x-a),math.abs(y-b),math.abs(z-c))
 end
 check(#Samples==1386 and worst<1e-9,('PackShapes151.Field equals the Blender design (blender/pack_shapes.py) at all %d lattice samples (worst %.2g)'):format(#Samples,worst))
 check(Shapes.Count==6 and #Shapes.Names==6,'six variations, each with a name: '..table.concat(Shapes.Names,', '))
 for id=1,6 do
  local yFixed,crimp,maxGrow,maxShrink,sym=true,true,0,0,true
  for a=-40,40 do for b=-40,40 do for _,w in ipairs({-1,-.4,0,.4,1})do
   local u,v=a/40,b/40
   local x,y,z=Shapes.Field(id,u,v,w)
   if y~=v then yFixed=false end
   if math.abs(v)>=.94 and(x~=u or z~=w)then crimp=false end
   local sx=u~=0 and x/u or 1;local sz=w~=0 and z/w or 1
   maxGrow=math.max(maxGrow,sx-1,sz-1);maxShrink=math.max(maxShrink,1-sx,1-sz)
   local x2,_,z2=Shapes.Field(id,-u,v,-w);if x2~=-x or z2~=-z then sym=false end
  end end end
  check(yFixed,'variation '..id..' ('..Shapes.Names[id]..'): y never moves (the pivot and the bottom line stay)')
  check(crimp,'variation '..id..': the crimps (|v| >= .94: the seal and the 8 tear strips) are untouched, exactly')
  check(maxGrow<=.05+1e-9,('variation %d: nothing grows by more than 5%% (%.3f)'):format(id,maxGrow))
  check(maxShrink>=.03 or maxGrow>=.04,('variation %d is visible (shrinks up to %.0f%%, grows up to %.0f%%)'):format(id,maxShrink*100,maxGrow*100))
  check(maxShrink<=.16,('variation %d stays gentle (shrinks at most %.0f%%)'):format(id,maxShrink*100))
  check(sym,'variation '..id..': symmetric in x and z (a bag has no handed side; the box centre stays)')
 end
 for a=1,6 do for b=a+1,6 do
  local diff=0;for i=-10,10 do for j=-10,10 do local x1,_,z1=Shapes.Field(a,i/10,j/10,.5);local x2,_,z2=Shapes.Field(b,i/10,j/10,.5);diff=math.max(diff,math.abs(x1-x2),math.abs(z1-z2))end end
  check(diff>=.02,'variations '..a..' and '..b..' are different shapes (they differ by '..string.format('%.3f',diff)..')')
 end end
end

-- 2. The roll -------------------------------------------------------------------------------------------------------------------------------------
do
 fresh()
 for _,k in ipairs({'Pack01','Pack02','Pack03','Pack04','Pack05','Pack06','Small','Standard','Grand'})do check(Shapes.Applies(k),k..' takes a shape (an ordinary biome pack, a legacy sack)')end
 for _,k in ipairs({'EclipseReliquary','MechLimited',VERITY,'Nope',''})do check(not Shapes.Applies(k),tostring(k)..' takes none (the Void, the Mech, the Verity pack (R152: its flat pouch), an unknown variant)')end
 check(not Shapes.Applies(nil)and not Shapes.Applies(3)and not Shapes.Applies({}),'nil / a number / a table take none')
 for _,v in ipairs({0,'3',2.5,7,-1,0/0,math.huge,true,{},false})do check(Shapes.Sanitize(v)==0,'Sanitize('..tostring(v)..') is 0 (the default shape)')end
 check(Shapes.Sanitize(nil)==0,'Sanitize(nil) is 0')
 for i=1,6 do check(Shapes.Sanitize(i)==i,'Sanitize('..i..') is '..i)end
 -- the dice
 for k=0,5 do check(Shapes.Roll('Pack03',(k+.5)/6)==k+1,'a draw of '..string.format('%.3f',(k+.5)/6)..' is variation '..(k+1))end
 check(Shapes.Roll('Pack01',0)==1 and Shapes.Roll('Pack01',1)==6 and Shapes.Roll('Pack01',1/6-1e-9)==1 and Shapes.Roll('Pack01',1/6)==2 and Shapes.Roll('Pack01',5/6-1e-9)==5 and Shapes.Roll('Pack01',5/6)==6,'the boundaries: 0 -> 1, 1/6 -> 2, 5/6 -> 6, 1 -> 6')
 check(Shapes.Roll('Pack01',-5)==1 and Shapes.Roll('Pack01',7)==6,'a draw outside 0..1 is clamped')
 -- the distribution: 120,000 low-discrepancy draws and 60,000 of the module's own dice
 local counts={0,0,0,0,0,0}
 for i=1,120000 do local id=Shapes.Roll('Pack04',(i*0.6180339887498949)%1);counts[id]+=1 end
 local worst=0;for i=1,6 do worst=math.max(worst,math.abs(counts[i]-20000))end
 check(worst<=30,'120,000 evenly spread draws fall 20,000 on each variation (worst off by '..worst..')')
 local function rolledSum()local s=0;for _,v in ipairs(Shapes.Status().Rolled)do s+=v end;return s end
 -- (the mock's Random is a small LCG: the dice are checked with a good generator behind the same Random.new() / NextNumber interface)
 local mockRandom=W.env.Random;math.randomseed(20151)
 W.env.Random={new=function()return{NextNumber=function()return math.random()end}end};Shapes.Reset()
 local own={0,0,0,0,0,0};local n=60000;local sum0=rolledSum()
 for _=1,n do local id=Shapes.Roll('Pack02');own[id]+=1 end
 local counted=rolledSum()-sum0
 W.env.Random=mockRandom;Shapes.Reset()
 local worst2,low=0,1e9;for i=1,6 do worst2=math.max(worst2,math.abs(own[i]-n/6));low=math.min(low,own[i])end
 check(low>0 and worst2<=420,('the roll\'s own dice: 60,000 rolls are uniform: %s (worst off by %d of %d expected; 4.6 sigma is 420)'):format(table.concat(own,' '),worst2,n/6))
 check(counted==n,'the status counts every roll ('..counted..' of '..n..')')
 -- not every variant, and the modes
 check(Shapes.Roll('EclipseReliquary')==nil and Shapes.Roll('MechLimited')==nil and Shapes.Roll('Nope')==nil and Shapes.Roll(nil)==nil,'the Void, the Mech and unknown variants roll nothing')
 server();Shapes.SetMode(4)
 local all4=true;for _=1,200 do if Shapes.Roll('Pack02')~=4 then all4=false end end
 check(all4 and Shapes.Roll('EclipseReliquary')==nil,'forced to 4: every new pack of a variant that takes one rolls 4; the Void still none')
 Shapes.SetMode('off');check(Shapes.Roll('Pack02')==nil and Shapes.Roll('Pack02',.5)==nil,'off: nothing is rolled')
 Shapes.SetMode('auto');check(Shapes.Roll('Pack02',.5)==4,'auto: dice again (.5 -> 4)')
 -- the roll does not depend on the design or the stage
 local per={}for _,k in ipairs({'Pack01','Pack06','Small'})do per[k]=Shapes.Roll(k,.3)end
 check(per.Pack01==2 and per.Pack06==2 and per.Small==2,'the same draw is the same variation for every variant')
end

-- 3. The bake of a pair ---------------------------------------------------------------------------------------------------------------------------
-- Checks one baked pair against its template: `meshes` = the mock EditableMeshes of this pair in bake order (the template's parts sorted by name).
local function geometry(key,id,meshes,label,neutral)
 local parts=meshesOf(key);local lo,hi=boxOf(parts);local c=(lo+hi)/2;local h=(hi-lo)/2
 local shaped={};for _,p in ipairs(Shapes.Template(key,id,neutral):GetChildren())do if p:IsA('MeshPart')then shaped[#shaped+1]=p end end;table.sort(shaped,function(a,b)return a.Name<b.Name end)
 local ok,why=true,''
 local moved,total=0,0;local worstOut=-1;local worstY=0;local worstCrimp=0;local worstMid=0;local normalsOk=true;local whiteOk=true
 for i,src in ipairs(parts)do
  local m=meshes[i];local frame=src:GetAttribute('PackLocalFrame')
  if not m then ok=false;why='no mesh '..i;break end
  local mid=Mock.offset;local lo1,hi1
  for _,p in ipairs(m._pos)do
   if not lo1 then lo1=V3(p.X,p.Y,p.Z);hi1=V3(p.X,p.Y,p.Z)else lo1=V3(math.min(lo1.X,p.X),math.min(lo1.Y,p.Y),math.min(lo1.Z,p.Z));hi1=V3(math.max(hi1.X,p.X),math.max(hi1.Y,p.Y),math.max(hi1.Z,p.Z))end
  end
  local mid1=(lo1+hi1)/2;local frame2=shaped[i]:GetAttribute('PackLocalFrame')
  worstMid=math.max(worstMid,((frame2*V3(0,0,0))-(frame*(mid1-mid))).Magnitude)  -- (the part sits on its mesh's bounding-box centre: the frame follows the centre)
  for v=1,#m._pos do
   local q0=frame*(m._init[v]-mid);local q1=frame2*(m._pos[v]-mid1)
   total+=1;if (q1-q0).Magnitude>1e-6 then moved+=1 end
   worstY=math.max(worstY,math.abs(q1.Y-q0.Y))
   local vn=(q0.Y-c.Y)/h.Y
   if math.abs(vn)>=.94 then worstCrimp=math.max(worstCrimp,math.abs(q1.X-q0.X),math.abs(q1.Z-q0.Z))end
   worstOut=math.max(worstOut,math.abs(q1.X-c.X)/h.X-1,math.abs(q1.Z-c.Z)/h.Z-1)
   local n0=(m._init[v]-mid);n0=n0.Magnitude>1e-9 and n0.Unit or V3(0,0,1)
   local n1=m._normals[v];if not(near(n1.Magnitude,1,1e-6)and n1:Dot(n0)>.5)then normalsOk=false end
   local col=m._colors[v];local isWhite=col.R>.999 and col.G>.999 and col.B>.999
   if neutral and not isWhite then whiteOk=false end
   if not neutral and col.R~=R.Color3.fromRGB(20+(v*37)%200,15+(v*11)%120,30+(v*53)%220).R then whiteOk=false end
  end
 end
 check(ok,label..': every mesh was loaded ('..why..')')
 check(worstY<2e-6,label..': no vertex moved in y (the pivot and the bottom line stay) ('..string.format('%.2g',worstY)..')')
 check(worstCrimp<2e-6,label..': the crimp rows (|v| >= .94) did not move at all, so the seal and the strips stay flush ('..string.format('%.2g',worstCrimp)..')')
 check(worstOut<=.05+1e-9,label..string.format(': nothing went outside the design\'s box by more than 5%% (%.3f)',worstOut))
 check(worstMid<2e-6,label..': each part\'s PackLocalFrame follows its mesh\'s bounding-box centre, so the vertices stay where the field put them ('..string.format('%.2g',worstMid)..')')
 check(moved/total>.1,label..string.format(': the field moved %d%% of the vertices',math.floor(moved/total*100)))
 check(normalsOk,label..': the normals are unit length and turned by less than 60 degrees')
 check(whiteOk,label..(neutral and': every vertex colour is white'or': every vertex colour is what the print had'))
end
local function templateChecks(key,id,label,neutral)
 local model=Shapes.Template(key,id,neutral);local parts=meshesOf(key)
 if not check(model~=nil and model:IsA('Model')and model.Parent==nil and model.Name==key,label..': the shaped template is a Model of the design, kept in memory (never parented)')then return end
 check(model:GetAttribute('PackShape')==id and model:GetAttribute('MeshCount')==#parts and model:GetAttribute('MeshBakeVersion')==123 and(model:GetAttribute('Neutral')==true)==(neutral==true),label..': it says its variation ('..tostring(model:GetAttribute('PackShape'))..') and keeps the template\'s MeshCount / MeshBakeVersion')
 local got={};for _,p in ipairs(model:GetChildren())do if p:IsA('MeshPart')then got[#got+1]=p end end;table.sort(got,function(a,b)return a.Name<b.Name end)
 local lo0,hi0=boxOf(parts)
 local same=#got==#parts;local yEq=true;local frames=true;local scaleOk=true
 for i,p in ipairs(got)do local s=parts[i]
  if p.Name~=s.Name then same=false else
   local ratio=V3(p.Size.X/s.Size.X,p.Size.Y/s.Size.Y,p.Size.Z/s.Size.Z)
   if p.Size.Y~=s.Size.Y then yEq=false end
   local f1,f2=p:GetAttribute('PackLocalFrame'),s:GetAttribute('PackLocalFrame');local d,r=cfDelta(f1,f2)
   if math.abs(f1.Position.Y-f2.Position.Y)>1e-9 or r>1e-9 or d>.1 then frames=false end
   -- (a small part off the box's middle can change size by more than 5% of ITSELF: what is bounded is how far it moves inside the box, 5%, checked by `geometry`)
   if p.Size.X-s.Size.X>.05*(hi0.X-lo0.X)+1e-9 or p.Size.Z-s.Size.Z>.05*(hi0.Z-lo0.Z)+1e-9 or ratio.X<.5 or ratio.Z<.5 then same=false end
   if p.Anchored~=true or p.CanCollide~=false or p.MeshId==s.MeshId then same=false end
   for _,a in ipairs({'X','Y','Z'})do if not near(p.Size[a]/p.MeshSize[a],s.Size[a]/s.MeshSize[a],1e-6)then scaleOk=false end end
   if neutral and not(p.Color.R==1 and p.Color.G==1 and p.Color.B==1 and p.Material.Name=='SmoothPlastic'and p.TextureID=='')then same=false end
  end
 end
 check(same,label..': the same MeshParts (names), each Size within 5% (of the design\'s width / depth) of the template\'s, anchored, a baked mesh (not the template\'s MeshId)')
 check(yEq and frames,label..': Size.Y is exactly the template\'s and every PackLocalFrame keeps its rotation (the 180 degree turn) and its height (the bottom line)')
 check(scaleOk,label..': the studs per mesh unit are the template\'s (the reshaped mesh is not stretched)')
 local lo,hi=boxOf(parts);local lo2,hi2=boxOf(got)
 local ext,ext2=hi-lo,hi2-lo2
 check(ext2.Y==ext.Y and lo2.Y==lo.Y and hi2.Y==hi.Y and ext2.X<=ext.X*1.0501 and ext2.Z<=ext.Z*1.0501 and ext2.X>=ext.X*.79 and ext2.Z>=ext.Z*.79,label..string.format(': the design\'s box: height and bottom / top exactly today\'s, width %.3f and depth %.3f of today\'s',ext2.X/ext.X,ext2.Z/ext.Z))
end
do
 fresh()
 local key='Lava_02';local parts=meshesOf(key);local id=3
 check(#parts==2,'(Lava_02 has two MeshParts, to test a design with more than one mesh)')
 check(Shapes.State(key,id)=='Idle'and Shapes.Template(key,id)==nil,'before a request: Idle, no template')
 check(Shapes.State(key,0)=='Off'and Shapes.State(key,nil)=='Off'and Shapes.State(key,9)=='Off','shape 0 / nil / 9 is the default: Off, nothing to bake')
 local calls=Mock.calls
 check(Shapes.Request(key,id)=='Ready','a request bakes the pair (the mock answers at once): Ready')
 check(Mock.calls==calls+2 and Mock.created==2 and Mock.alive==0 and Mock.maxAlive==1 and Mock.baked==2 and Mock.bakedAlive==2,('two meshes loaded one after the other, both EditableMeshes destroyed (alive %d, most at once %d), both MeshParts kept'):format(Mock.alive,Mock.maxAlive))
 check(Mock.uris[1]==parts[1].MeshId and Mock.uris[2]==parts[2].MeshId,'the meshes loaded are the live template\'s own MeshIds, in part order ('..tostring(Mock.uris[1])..')')
 check(Mock.sets.Color==0 and Mock.sets.ColorAlpha==0 and Mock.sets.UV==0,'vertex colours and UVs are never set for a printed pair: the print stays')
 check(Mock.sets.Position==2*Mock.vertices and Mock.sets.Normal>0,('every vertex of both meshes got a position (%d), and normals were set (%d)'):format(Mock.sets.Position,Mock.sets.Normal))
 geometry(key,id,Mock.meshes,'Lava_02 / variation '..id)
 templateChecks(key,id,'Lava_02 / '..id)
 local f=folder()
 check(f and f:GetAttribute('Ready')==true and f:GetAttribute('FailureCount')==0 and f:GetAttribute('BakedCount')==1 and f:GetAttribute('Requested')==1 and f:GetAttribute('Pending')==0 and f:GetAttribute('Pairs')==1 and f:GetAttribute('Vertices')==3600 and f:GetAttribute('Mode')=='auto','the status folder: Ready, FailureCount 0, BakedCount 1, Requested 1, Pending 0, 1 pair, 3600 vertices, mode auto')
 check(near(f:GetAttribute('Megabytes'),3600*48/1e6,.1),'... and an estimate of '..tostring(f:GetAttribute('Megabytes'))..' MB')
 local c2=Mock.calls;Shapes.Request(key,id);Shapes.ForBag(key,id);check(Mock.calls==c2,'a pair is baked once')
 check(Shapes.State(key,4)=='Idle','another variation of the same design is another pair')
 local src=W.B.PackShapes151
 check(not src:find('rbxassetid',1,true)and src:find('CreateEditableMeshAsync',1,true)and src:find('SetPosition',1,true)and src:find('CreateMeshPartAsync',1,true),'(source: no asset id in PackShapes151; it loads the template\'s MeshId with CreateEditableMeshAsync, moves vertices with SetPosition, bakes with CreateMeshPartAsync)')
 check(not src:find('SetUV',1,true),'(source: it never sets a UV)')
end
-- every pair of the game: 42 designs x 6 variations
do
 fresh();Mock.vertices=300;local bad=0;local firstBad;local count=0
 Shapes.Config.MaxResidentVertices=1e9;Shapes.Config.HardResidentVertices=1e9
 for _,d in ipairs(DESIGNS)do for id=1,6 do
  local startMesh=#Mock.meshes
  if bakeNow(d.Key,id)~='Ready'then bad+=1;firstBad=firstBad or d.Key..'/'..id end
  local mine={};for i=startMesh+1,#Mock.meshes do mine[#mine+1]=Mock.meshes[i]end
  geometry(d.Key,id,mine,d.Key..'/'..id);templateChecks(d.Key,id,d.Key..'/'..id);count+=1
 end end
 check(bad==0 and count==252,'all 252 pairs (42 designs x 6 variations) bake ('..bad..' did not'..(firstBad and(', first '..firstBad)or'')..')')
 check(Mock.created==115*6 and Mock.alive==0 and Mock.maxAlive==1 and Mock.bakedAlive==115*6,('690 meshes for 252 pairs, one EditableMesh alive at a time (most %d), none left (%d)'):format(Mock.maxAlive,Mock.alive))
 local f=folder();check(f:GetAttribute('BakedCount')==252 and f:GetAttribute('FailureCount')==0 and f:GetAttribute('Pairs')==252 and f:GetAttribute('Vertices')==690*300,'status: BakedCount 252, FailureCount 0, 252 pairs, '..tostring(f:GetAttribute('Vertices'))..' vertices')
 -- Bounds: Visuals.Bounds reads the place's own template and holds every shaped pouch to within 5%
 local function extent(list)
  local r,minY,maxY=0,1e9,-1e9
  for _,p in ipairs(list)do local fr=p:GetAttribute('PackLocalFrame')
   for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
    local v=fr*V3(p.Size.X*x,p.Size.Y*y,p.Size.Z*z);r=math.max(r,V3(v.X,0,v.Z).Magnitude);minY=math.min(minY,v.Y);maxY=math.max(maxY,v.Y)
   end end end
  end
  return r,minY,maxY
 end
 local holds,same,worst=true,true,0
 for _,d in ipairs(DESIGNS)do for id=1,6 do
  local scale=Rules.GetVariant(d.Variant).BagScale*Rules.GetTheme(d.Stage).Scale
  local b=Visuals.Bounds(d.Stage,d.Variant,1)
  local sp={};for _,p in ipairs(Shapes.Template(d.Key,id):GetChildren())do if p:IsA('MeshPart')then sp[#sp+1]=p end end
  local r,minY,maxY=extent(sp);local r0,minY0,maxY0=extent(meshesOf(d.Key))
  if r*scale>b.Radius*1.0501 or minY*scale<b.MinY-1e-9 or maxY*scale>b.MaxY+1e-9 then holds=false end
  if r>r0*1.0501 or minY~=minY0 or maxY~=maxY0 then same=false end
  worst=math.max(worst,r/r0)
 end end
 check(holds,'Visuals.Bounds of every design (it reads the place\'s own template, unchanged) holds every one of its six shaped pouches to within 5%: radius, bottom, top')
 check(same,('every shaped pouch\'s radius is at most 5%% over today\'s (worst %.3f) and its bottom and top are exactly today\'s'):format(worst))
end

-- 4. Contexts -------------------------------------------------------------------------------------------------------------------------------------
local function contexts(stage,variant,shape,label)
 fresh();local key=design(stage,variant)
 local off=defaultPack(stage,variant)
 check(bakeNow(key,shape)=='Ready','('..label..': the pair is baked)')
 local shapedTpl=Shapes.Template(key,shape);local calls=Mock.calls
 local reference
 local function compare(bag,name)
  local s=sig(bag);reference=reference or s
  local same,why=sameSig(s,reference);check(same,label..' '..name..': the same parts, sizes and positions as the ground pack'..(why and(' ('..why..')')or''))
  check(bag:GetAttribute('PackShape')==shape and bag:GetAttribute('PackShapeShown')==shape,label..' '..name..': says its shape (PackShape '..tostring(bag:GetAttribute('PackShape'))..', shown '..tostring(bag:GetAttribute('PackShapeShown'))..')')
  return s
 end
 for _,coat in ipairs({'None','Gold','Diamond'})do for _,size in ipairs({1,25})do
  local g=H.ground(stage,variant,size,coat,nil,shape);local s=compare(g,'ground '..size..'x '..coat)
  local pouch=pouchOf(g);local scale=g:GetAttribute('VisualScale');local want=shapedTpl.ApprovedMesh01.Size
  check(pouch and near(pouch.Size.X/scale,want.X,1e-6)and near(pouch.Size.Z/scale,want.Z,1e-6),label..' ground '..size..'x '..coat..': the pouch is the SHAPED mesh ('..tostring(pouch and pouch.Size/scale)..')')
  check(pouch and pouch.MeshId=='' and assets[key]:GetChildren()[1].MeshId~='','(the pouch of the shaped pack is a baked mesh, not the place\'s own: '..label..')')
  local flush=true;for k,v in pairs(off)do if k:find('Seal')or k:find('TearStrip')then local x=s[k];if not x or(x.Pos-v.Pos).Magnitude>1e-9 or(x.Size-v.Size).Magnitude>1e-9 then flush=false end end end
  check(flush,label..' ground '..size..'x '..coat..': the seal and the 8 tear strips are exactly where the default pack\'s are')
  local c=Rules.PackMutations[coat];if c.Color then local painted=true;for _,p in ipairs(H.partsOf(g,false))do if p.Color~=c.Color then painted=false end end;check(painted,label..' '..coat..': the coat paints the shaped pouch like any')end
  if size>10 then local tagged=0;for _,p in ipairs(H.partsOf(g,false))do if W.CS:HasTag(p,'GiantVisualPart')then tagged+=1 end end;check(tagged==#H.partsOf(g,false),label..': a giant: every part tagged GiantVisualPart')end
  g:Destroy()
 end end
 for _,rig in ipairs({'R15','R6'})do
  local held,char=H.held(stage,variant,1,'None',rig,shape);compare(held,'held '..rig);held:Destroy();char:Destroy()
 end
 do local char=H.character('R15');local carry=Visuals.CarryBag(char,stage,variant,1,1,'None',shape);compare(carry,'CarryBag');carry:Destroy();char:Destroy()end
 do local p=H.picture(stage,variant,1,'None',shape);compare(p,'picture');local sp=H.sanitized(p);compare(sp,'sanitized picture');p:Destroy()end
 do local held,char=H.held(stage,variant,1,'None','R15',shape);local copy=H.openingCopy(held);compare(copy,'opening copy');copy:Destroy();held:Destroy();char:Destroy()end
 -- a catalogue / shop / reward picture, a market stall and a shop viewport are flagged DefaultPackShape: the default pack whatever a pack rolled; the flag wins over a shape
 local function isDefault(b,what)check(b:GetAttribute('DefaultPackShape')==true and b:GetAttribute('PackShape')==nil and b:GetAttribute('PackShapeShown')==nil and sameSig(sig(b),off),label..' '..what..' (flagged DefaultPackShape, shape '..shape..' given): the default pack, no roll claimed')end
 do local m=H.market(stage,variant,shape);isDefault(m,'market stall');m:Destroy()end
 do local p=H.picture(stage,variant,1,'None',shape,true);isDefault(p,'catalogue / shop / reward picture');local sp=H.sanitized(p);check(sameSig(sig(sp),off),label..' ... and sanitised');p:Destroy()end
 do local b,vf=H.viewport(stage,variant,1,'None',nil,shape,true);isDefault(b,'shop viewport');b:Destroy()end
 do local m,holder=H.mystery(stage,variant,false,shape);local scale=m:GetAttribute('VisualScale');local want=shapedTpl.ApprovedMesh01.Size
  local pouch=pouchOf(m);check(pouch and near(pouch.Size.X/scale,want.X,1e-6),label..' mystery pedestal (x1.7): the shaped pouch');compare(m,'mystery pedestal');holder:Destroy()end
 do local b,vf=H.viewport(stage,variant,1,'None',nil,shape);compare(b,'viewport');b:Destroy()end
 -- the locked silhouette is always the default plain pack
 do local m,holder=H.mystery(stage,variant,true,shape);check(m:GetAttribute('PackShape')==nil,label..' mystery silhouette: no shape (every locked pedestal looks the same)');holder:Destroy()end
 -- no shape (the Index, the catalogues), 0 and an invalid value are the default pack
 for _,v in ipairs({0,9,'x'})do local b=H.ground(stage,variant,1,'None',nil,v);check(sameSig(sig(b),off),label..': a pack with shape '..tostring(v)..' is the default pack');b:Destroy()end
 local plain=H.ground(stage,variant,1,'None');check(plain:GetAttribute('PackShape')==nil and plain:GetAttribute('PackShapeShown')==nil and sameSig(sig(plain),off),label..': no shape at all (the Index, a catalogue, a shop) is the default pack and carries no shape attribute');plain:Destroy()
 check(Mock.calls==calls,label..': building every context baked nothing more ('..(Mock.calls-calls)..' extra)')
 check(Mock.alive==0,label..': no EditableMesh left alive')
end
do -- the flag wins: a bag flagged DefaultPackShape asks PackShapes151 for nothing, whatever shape it is given (or already carries); an unflagged one asks
 fresh();local asked=0;local base=Shapes.ForBag;Shapes.ForBag=function(...)asked+=1;return base(...)end
 Shapes.Request('Forest_04',3)
 local flagged=H.picture(1,'Pack04',1,'None',3,true)
 check(flagged:GetAttribute('DefaultPackShape')==true and flagged:GetAttribute('PackShape')==nil and asked==0 and pouchOf(flagged).MeshId==assets.Forest_04.ApprovedMesh01.MeshId,'SeedPackVisuals.Bag(..., defaultShape, shape 3): flagged, no PackShape claimed, PackShapes151.ForBag never asked, the design\'s own mesh ('..asked..' asks)')
 local free=H.picture(1,'Pack04',1,'None',3)
 check(free:GetAttribute('PackShape')==3 and asked==1 and pouchOf(free).MeshId=='','the same bag unflagged does ask, and is the baked shape (control: '..asked..' ask)')
 local both=H.picture(1,'Pack04',1,'None',nil,true);local pg=both:FindFirstChild('PackGeometry');pg:Destroy();both:SetAttribute('CompactPackReady',nil);both:SetAttribute('PackShape',3)
 W.module('SeedPackRenderer').Build(both,function()return true end)
 check(asked==1 and pouchOf(both)and pouchOf(both).MeshId==assets.Forest_04.ApprovedMesh01.MeshId,'SeedPackRenderer itself honours the flag: a flagged bag that also carries PackShape 3 is still built from the design\'s own mesh ('..asked..' asks)')
 Shapes.ForBag=base;flagged:Destroy();free:Destroy();both:Destroy()
 local fv=H.ground(1,'Pack02',1,'None',nil,3);check(fv:GetAttribute('DefaultPackShape')==nil,'an ordinary pack (the world, the hand) is never flagged');fv:Destroy()
end
contexts(4,'Pack03',3,'Lava_03 / 3')
contexts(1,'Pack02',5,'Forest_02 / 5')
contexts(7,'Pack06',6,'Storm_06 / 6')
-- a multi-mesh design builds every shaped mesh
do
 fresh();local key='Snow_06';bakeNow(key,2);local bag=H.ground(3,'Pack06',1,'None',nil,2)
 local n,shapedParts=0,0;for _,p in ipairs(H.partsOf(bag,false))do if p:IsA('MeshPart')then n+=1;if p.MeshId==''then shapedParts+=1 end end end
 check(n==16 and shapedParts==16 and bag:GetAttribute('PackArtKey')==key,'Snow_06 (16 MeshParts) builds all 16 shaped meshes ('..shapedParts..'/16 are baked meshes)')
 bag:Destroy()
end
-- the special packs ignore a shape
do
 for _,size in ipairs({1,25})do for _,spec in ipairs({{'Void',1,H.VOID},{'Void (Storm)',7,H.VOID},{'Mech',8,H.MECH}})do
  fresh();local a=H.ground(spec[2],spec[3],size,'None',nil,4);local sa=sig(a);local calls=Mock.calls
  local b=H.ground(spec[2],spec[3],size,'None');local sb=sig(b)
  check(sameSig(sa,sb)and calls==0 and a:GetAttribute('PackShape')==nil,spec[1]..' pack '..size..'x ignores a shape: the same as without, no mesh loaded, no PackShape attribute');a:Destroy();b:Destroy()
 end end
 fresh();local v=H.ground(1,H.VOID,1,'None');local m=pouchOf(v);check(m and m.MeshId==assets.Forest_01.ApprovedMesh01.MeshId,'the Void pack\'s pouch is the place\'s own Forest_01 mesh');v:Destroy()
end

-- 5. Never yields ---------------------------------------------------------------------------------------------------------------------------------
do
 local builders={};local realWait=R.task.wait
 R.task.wait=function(t)if builders[coroutine.running()]then error('a pack build must never wait',2)end;return t or .03 end
 local function build(fn)local out;local co=coroutine.create(function()out=fn()end);builders[co]=true;local ok,err=coroutine.resume(co);return ok,err,coroutine.status(co),out end
 -- a server, a pair that is slow to bake
 fresh();Mock.slow=true;server()
 local ok,err,status,bag=build(function()return H.ground(1,'Pack02',1,'None',nil,3)end)
 check(ok and status=='dead'and bag~=nil,'a server pack build never yields or errors while its pair is being baked ('..tostring(err)..')')
 check(bag:GetAttribute('PackShape')==3 and bag:GetAttribute('PackShapeShown')==0 and pouchOf(bag).MeshId==assets.Forest_02.ApprovedMesh01.MeshId,'... the pack is the default shape this once, and still says its roll (3)')
 check(Shapes.State('Forest_02',3)=='Loading'and #Mock.waiting==1,'... the pair is being baked (asked for by the build)')
 local ok2,_,st2,bag2=build(function()return H.ground(1,'Pack02',1,'None',nil,3)end)
 check(ok2 and st2=='dead'and bag2:GetAttribute('PackShapeShown')==0 and #Mock.waiting==1 and Mock.calls==1,'a second build while it loads: still the default, no second bake')
 while Mock.resume()do end
 check(Shapes.State('Forest_02',3)=='Ready','the bake finishes')
 local ok3,_,_,bag3=build(function()return H.ground(1,'Pack02',1,'None',nil,3)end)
 check(ok3 and bag3:GetAttribute('PackShapeShown')==3 and pouchOf(bag3).MeshId=='','the next build is the shaped pack (a baked mesh)')
 for _,b in ipairs({bag,bag2,bag3})do b:Destroy()end
 -- a client: the picture build errors "still loading" (ItemPictures retries) and draws nothing
 fresh();Mock.slow=true;client()
 local okc,errc=pcall(function()return H.picture(1,'Pack02',1,'None',3)end)
 check(not okc and tostring(errc):find('still loading',1,true)~=nil,'a client\'s picture build errors "still loading" while its pair is baked: '..tostring(errc))
 while Mock.resume()do end
 local okd,pic=pcall(function()return H.picture(1,'Pack02',1,'None',3)end)
 check(okd and pic:GetAttribute('PackShapeShown')==3,'... and draws the shaped pack once it is baked');if okd then pic:Destroy()end
 server()
 -- Settle: a new pack keeps its roll only when its pair is baked
 fresh();Mock.slow=true
 check(Shapes.Settle('Forest_02',3)==0,'Settle: a roll whose pair is cold is the default shape for life (0)')
 check(Shapes.Status().Demoted==1,'... counted as Demoted')
 check(Shapes.Settle('Forest_02',nil)==nil and Shapes.Settle('Forest_02',0)==0,'nil stays nil (a pack that takes none), 0 stays 0')
 while Mock.resume()do end
 check(Shapes.Settle('Forest_02',3)==3 and Shapes.Status().Demoted==1,'... and the roll once the pair is baked (the cold request started the bake)')
 fresh();Mock.slow=false
 check(Shapes.Settle('Forest_03',4)==4,'Settle with the mock answering at once: the roll is kept')
 -- several pairs asked at once: ONE bake at a time (one EditableMesh alive), in the order asked, an urgent one in front of the queue
 fresh();Mock.slow=true
 Shapes.Request('Forest_02',3);Shapes.Request('Forest_03',3);Shapes.Request('Forest_04',3,false,true)
 check(Shapes.State('Forest_02',3)=='Loading'and Shapes.State('Forest_03',3)=='Loading'and Shapes.State('Forest_04',3)=='Loading'and Shapes.Status().Pending==3,'three pairs asked at once: all Loading')
 local order,seen={},{}
 for _=1,60 do
  Mock.resume()
  for _,k in ipairs({'Forest_02','Forest_03','Forest_04'})do if not seen[k]and Shapes.State(k,3)=='Ready'then seen[k]=true;order[#order+1]=k end end
 end
 check(table.concat(order,',')=='Forest_02,Forest_04,Forest_03','they bake in the order asked, the urgent one in front of the queue ('..table.concat(order,',')..')')
 check(Mock.maxAlive==1 and Mock.created==3 and Mock.alive==0,('... one EditableMesh alive at a time (most %d), all destroyed'):format(Mock.maxAlive))
 Mock.slow=false
 -- Await: bounded, yields
 fresh();Mock.slow=true;server();R.task.wait=function(t)Mock.resume();R.advance(t or .03);return t or .03 end
 local t0=R.clock;local ready=Shapes.Await('Forest_02',3,false)
 check(ready==true and R.clock-t0<1,'Await waits for the bake and returns true when it is done ('..string.format('%.2f',R.clock-t0)..' s)')
 fresh();Mock.mode='hang';R.task.wait=function(t)R.advance(t or .03);return t or .03 end
 t0=R.clock;local ready2=Shapes.Await('Forest_02',3,false,1)
 check(ready2==false and R.clock-t0>=1-1e-6 and R.clock-t0<1.5,'Await of a bake that never returns gives up after the time it was given ('..string.format('%.2f',R.clock-t0)..' s)')
 check(Shapes.Await('Forest_02',0,false)==true,'Await of the default shape is immediate')
 R.task.wait=realWait
end

-- 6. Fallbacks ------------------------------------------------------------------------------------------------------------------------------------
local function fallback(label,stage,variant,shape,setup,reasonPart)
 fresh();local key=design(stage,variant);local def=defaultPack(stage,variant);fresh();local restore=setup and setup()
 local w0=warns()
 local bag=H.ground(stage,variant,1,'None',nil,shape)
 local same,why=sameSig(sig(bag),def)
 check(same,label..': the pack is the default pack, exactly'..(why and(' ('..why..')')or''))
 check(bag:GetAttribute('PackShape')==shape and bag:GetAttribute('PackShapeShown')==0,label..': it still says its roll; the shape shown is 0')
 local s,why2=Shapes.State(key,shape)
 check(s=='Off'and Shapes.Template(key,shape)==nil and tostring(why2):find(reasonPart,1,true)~=nil,label..': State is Off and the reason names it ('..tostring(why2)..')')
 check(Mock.alive==0 and Mock.bakedAlive==0,label..': nothing left over ('..Mock.alive..' EditableMesh, '..Mock.bakedAlive..' MeshPart)')
 check(warns()==w0+1,label..': exactly one warning ('..(warns()-w0)..')')
 local f=folder()
 check(f:GetAttribute('FailureCount')==1 and f:GetAttribute('Ready')==false and type(f:GetAttribute('LastFailure'))=='string',label..': the status folder says FailureCount 1, not Ready, and a kind of failure ('..tostring(f:GetAttribute('LastFailure'))..')')
 -- R152: the folder is replicated to every client: its LastFailure is a generic kind, never the design (it could hint the next rare pack); the full text stays server-side (Status, the owner's /test packshape)
 local shown=tostring(f:GetAttribute('LastFailure'))
 check(not shown:find(key,1,true)and not shown:find('|',1,true)and not shown:find(reasonPart,1,true)and(Shapes.Status().LastFailure or''):find(key,1,true)~=nil,label..': LastFailure in the replicated folder names no design ('..shown..'); Status().LastFailure (server only) still does')
 for name,value in pairs(f:GetAttributes())do check(not tostring(value):find(key,1,true),label..': no status attribute carries the design key ('..name..')')end
 local okX,textX=W.module('PackShapeCommand151').Execute({},{Name='Owner'},{})
 check(okX==true and textX:find('last failure: '..key,1,true)~=nil,label..': the owner\'s /test packshape still says which pair failed and why')
 local calls=Mock.calls;local again=H.ground(stage,variant,1,'None',nil,shape)
 check(Mock.calls==calls and warns()==w0+1 and sameSig(sig(again),def),label..': a second pack does not try again, no second warning, the same default pack');again:Destroy()
 -- STICKY: the cause is gone, the pair stays the default (a fallback never flips to a shape later)
 Mock.mode='ok';Mock.vertices=300
 local later=H.ground(stage,variant,1,'None',nil,shape)
 check(sameSig(sig(later),def)and Shapes.State(key,shape)=='Off','sticky: with the cause gone the pair still shows the default shape (no flip between shapes)');later:Destroy()
 -- ... other pairs still bake
 local other=shape%6+1;check(bakeNow(key,other)=='Ready',label..': another variation of the same design still bakes')
 -- ... and a switch off / on forgets it (the owner fixed the permission)
 server();Shapes.SetMode('off');Shapes.SetMode('auto')
 check(Shapes.State(key,shape)=='Idle'and folder():GetAttribute('FailureCount')==0,label..': off / auto forgets failures: the pair may be tried again')
 bag:Destroy()
 if restore then restore()end
end
fallback('denied (no permission on the asset)',1,'Pack02',3,function()Mock.mode='denied'end,'no permission')
fallback('a mesh with no vertices',1,'Pack02',3,function()Mock.mode='no_vertices'end,'no vertices')
fallback('GetPosition / SetPosition missing',1,'Pack02',3,function()Mock.mode='no_positions'end,'not available')
fallback('the bake does not succeed',1,'Pack02',3,function()Mock.mode='content_fails'end,'could not bake')
fallback('CreateMeshPartAsync fails',1,'Pack02',3,function()Mock.mode='meshpart_fails'end,'out of mesh memory')
fallback('another mesh size',1,'Pack02',3,function()Mock.mode='size_mismatch'end,'not the reshaped mesh')
fallback('too many vertices',1,'Pack02',3,function()Mock.vertices=Shapes.Config.MaxVertices+1 end,'vertices')
fallback('the second mesh of a pair fails (the first is destroyed)',4,'Pack02',2,function()Mock.mode='second_fails'end,'second mesh')
do -- a world WITHOUT the EditableMesh API (a test world, an old client): an expected fallback, so it is quiet; a real failure afterwards still warns once
 fresh();local def=defaultPack(1,'Pack02');Mock.api(false);local w0=warns()
 local bag=H.ground(1,'Pack02',1,'None',nil,3)
 check(sameSig(sig(bag),def)and bag:GetAttribute('PackShapeShown')==0 and bag:GetAttribute('PackShape')==3,'no EditableMesh API: the pack is the default pack (it still says its roll)')
 check(Shapes.State('Forest_02',3)=='Off'and reasonOf('Forest_02',3):find(Shapes.Unavailable,1,true)~=nil,'... State is Off, the reason says the API is not available ('..reasonOf('Forest_02',3)..')')
 check(warns()==w0,'... and NO warning: an environment without EditableMesh is an expected fallback ('..(warns()-w0)..')')
 check(folder():GetAttribute('FailureCount')==1 and folder():GetAttribute('Ready')==false and folder():GetAttribute('LastFailure')=='unavailable','... the status folder still says it, as a generic kind ('..tostring(folder():GetAttribute('LastFailure'))..')')
 for _=1,3 do local again=H.ground(1,'Pack02',1,'None',nil,3);again:Destroy();local pic=H.picture(1,'Pack03',1,'None',2);pic:Destroy()end
 check(warns()==w0 and Mock.created==0,'... building packs and pictures in it stays quiet and loads nothing ('..(warns()-w0)..' warnings)')
 Mock.api(true);Mock.mode='denied';Shapes.Request('Forest_04',3);Mock.mode='ok'
 check(warns()==w0+1 and Shapes.State('Forest_04',3)=='Off','a REAL failure (a denied asset) after that still warns, once ('..(warns()-w0)..')')
 local v=Shapes.Request('Forest_05',3,true);check(v=='Ready','the quiet failure was not about the API being switched on later: other pairs bake once it is there')
end
do -- a pair of a design with no template, an incomplete one, one with no PackLocalFrame
 fresh();local m=assets.Forest_02;m.Name='Forest_02_gone';Shapes.Request('Forest_02',3);m.Name='Forest_02'
 check(Shapes.State('Forest_02',3)=='Off'and reasonOf('Forest_02',3):find('not in SeedPackMeshAssets',1,true)~=nil and Mock.created==0,'the template is not in the place: that pair is the default shape, nothing loaded')
 fresh();m:SetAttribute('MeshCount',2);Shapes.Request('Forest_02',3)
 check(Shapes.State('Forest_02',3)=='Off'and reasonOf('Forest_02',3):find('not a complete',1,true)~=nil and Mock.created==0,'an incomplete template (MeshCount 2, one mesh): the default shape, nothing is loaded')
 m:SetAttribute('MeshCount',1)
 fresh();local p=assets.Forest_02.ApprovedMesh01;local frame=p:GetAttribute('PackLocalFrame');p:SetAttribute('PackLocalFrame',nil);Shapes.Request('Forest_02',3)
 check(Shapes.State('Forest_02',3)=='Off'and Mock.alive==0 and Mock.bakedAlive==0,'a mesh with no PackLocalFrame: the default shape, nothing leaked');p:SetAttribute('PackLocalFrame',frame)
end
do -- one pair failing does not stop the next one
 fresh();Mock.mode='denied';Shapes.Request('Forest_02',3);Mock.mode='ok';Shapes.Request('Forest_03',3)
 check(Shapes.State('Forest_02',3)=='Off'and Shapes.State('Forest_03',3)=='Ready','a failed pair does not stop the next one: Forest_02/3 Off, Forest_03/3 Ready')
 local f=folder();check(f:GetAttribute('FailureCount')==1 and f:GetAttribute('BakedCount')==1 and f:GetAttribute('Ready')==false,'status: 1 failure, 1 baked, not Ready')
end
do -- a bake that never returns: given up on after LoadingSeconds, for good; the queue goes on
 fresh();Mock.mode='hang';local w0=warns();Shapes.Request('Forest_02',3);Shapes.Request('Forest_03',3)
 check(Shapes.State('Forest_02',3)=='Loading'and Shapes.State('Forest_03',3)=='Loading','a bake that never returns stays Loading (the next pair waits behind it)')
 R.advance(Shapes.Config.LoadingSeconds+1)
 check(Shapes.State('Forest_02',3)=='Off'and reasonOf('Forest_02',3):find('did not finish',1,true)~=nil,'after '..Shapes.Config.LoadingSeconds..' s it is given up on: Off, "did not finish"')
 check(folder():GetAttribute('LastFailure')=='time-out'and Shapes.Status().LastFailure:find('Forest_02',1,true)~=nil,'R152: the replicated folder says only "time-out"; Status() (server) keeps the pair')
 Mock.mode='ok';check(Shapes.State('Forest_03',3)=='Off','(the pair queued behind it timed out too: it was asked at the same time)')
 Shapes.Request('Forest_04',3);check(Shapes.State('Forest_04',3)=='Ready','the queue is not blocked: the next pair bakes ('..Shapes.State('Forest_04',3)..')')
 check(Shapes.State('Forest_02',3)=='Off','... and the given-up pair stays the default: sticky')
 check(warns()==w0+1,'the failures warn once per session ('..(warns()-w0)..')')
end

-- 7. Budget (LRU) ---------------------------------------------------------------------------------------------------------------------------------
do
 local V=300;local function pairs3()return SINGLE[1],SINGLE[2],SINGLE[3],SINGLE[4],SINGLE[5],SINGLE[6]end
 local a,b,c,d,e,f=pairs3()
 local function budget(soft,hard,grace)fresh();Mock.vertices=V;Shapes.Config.MaxResidentVertices=soft*V;Shapes.Config.HardResidentVertices=hard*V;Shapes.Config.GraceSeconds=grace end
 local function state(x,id)return Shapes.State(x.Key,id or 1)end
 local function bakeAt(x,id)local s=bakeNow(x.Key,id or 1);R.advance(1);return s end
 -- LRU order (no grace)
 budget(3,10,0)
 bakeAt(a);bakeAt(b);bakeAt(c)
 check(state(a)=='Ready'and state(b)=='Ready'and state(c)=='Ready'and Shapes.Status().Vertices==3*V,'budget 3 pairs: three baked, '..Shapes.Status().Vertices..' vertices resident')
 bakeAt(d)
 check(state(a)=='Idle'and state(b)=='Ready'and state(c)=='Ready'and state(d)=='Ready','a fourth evicts the LEAST recently used (a): a Idle (not failed), b c d Ready')
 check(Shapes.Status().Vertices==3*V and Shapes.Status().Evicted==1 and Shapes.Status().Pairs==3,'... 3 pairs / '..Shapes.Status().Vertices..' vertices resident, 1 evicted')
 Shapes.Template(b.Key,1);R.advance(1) -- b is used: the oldest is now c
 bakeAt(e)
 check(state(c)=='Idle'and state(b)=='Ready'and state(d)=='Ready'and state(e)=='Ready','a use renews a pair: after b is used the next eviction is c, not b')
 check(Shapes.Status().Failures==0,'evictions are not failures')
 -- an evicted pair is rebaked on demand and builds the same pack
 budget(3,10,0)
 local sa=H.ground(a.Stage,a.Variant,1,'None',nil,1);local before=sig(sa);sa:Destroy()
 bakeAt(b);bakeAt(c);bakeAt(d)
 check(state(a)=='Idle','(a was evicted)')
 local meshesBefore=#Mock.meshes
 local sb=H.ground(a.Stage,a.Variant,1,'None',nil,1)
 check(sameSig(sig(sb),before)and sb:GetAttribute('PackShapeShown')==1 and #Mock.meshes==meshesBefore+1,'a pack of the evicted pair rebakes it (the mock answers at once) and is the same shaped pack as before the eviction')
 -- a built pack outlives its template
 local live=H.ground(b.Stage,b.Variant,1,'None',nil,1);local liveSig=sig(live);R.advance(1)
 bakeAt(SINGLE[7]);bakeAt(SINGLE[8]);bakeAt(SINGLE[9])
 check(state(b)=='Idle','(b was evicted: '..state(b)..')')
 check(sameSig(sig(live),liveSig)and pouchOf(live)~=nil and pouchOf(live).MeshId=='','a built pack keeps its mesh when its template is evicted (the pack and its pouch are unchanged: '..tostring(pouchOf(live)and pouchOf(live).MeshId)..' '..tostring(live:GetAttribute('PackShapeShown'))..')')
 live:Destroy();sb:Destroy()
 -- grace: a pair used within the grace period is not evicted by the soft cap; the cap is soft
 budget(3,10,30)
 bakeAt(a);bakeAt(b);bakeAt(c);bakeAt(d)
 check(state(a)=='Ready'and Shapes.Status().Vertices==4*V,'within the grace period nothing is evicted: the soft cap is exceeded (4 pairs resident)')
 R.advance(31);bakeAt(e)
 check(state(a)=='Idle'and state(b)=='Idle'and state(c)=='Ready'and state(d)=='Ready'and state(e)=='Ready'and Shapes.Status().Vertices==3*V,'after the grace period the least recently used go until there is room (a b evicted; c d e kept: '..Shapes.Status().Vertices..' vertices)')
 -- pins
 budget(3,10,0)
 local owner={};bakeAt(a);Shapes.Pin(owner,a.Key,1);bakeAt(b);bakeAt(c);bakeAt(d);bakeAt(e)
 check(state(a)=='Ready'and state(b)=='Idle'and state(c)=='Idle'and state(d)=='Ready'and state(e)=='Ready','a PINNED pair (the pair of a pack on the track) is never evicted, though it is the oldest: b and c go instead')
 Shapes.Unpin(owner);bakeAt(f)
 check(state(a)=='Idle','unpinned, it is evicted like any')
 local o1,o2={}, {};budget(3,10,0);bakeAt(a);Shapes.Pin(o1,a.Key,1);Shapes.Pin(o2,a.Key,1);Shapes.Unpin(o1);bakeAt(b);bakeAt(c);bakeAt(d);bakeAt(e)
 check(state(a)=='Ready','a pair pinned by two owners stays while either holds it');Shapes.Unpin(o2)
 local o3={};budget(3,10,0);bakeAt(a);Shapes.Pin(o3,a.Key,1);Shapes.Pin(o3,b.Key,1);bakeAt(b);bakeAt(c);bakeAt(d);bakeAt(e)
 check(state(a)=='Idle'and state(b)=='Ready','one owner holds one pair: pinning another moves the pin (a is free, b is held)')
 -- idle sweep
 budget(50,100,30)
 bakeAt(a);bakeAt(b);local o4={};Shapes.Pin(o4,b.Key,1)
 R.advance(Shapes.Config.IdleSeconds+Shapes.Config.SweepSeconds+1)
 check(state(a)=='Idle'and state(b)=='Ready','a pair unused for '..Shapes.Config.IdleSeconds..' s is evicted by the sweep even below the cap; a pinned one stays')
 check(Shapes.Status().Pairs==1 and Shapes.Status().Vertices==V and folder():GetAttribute('Pairs')==1 and folder():GetAttribute('Vertices')==V,'... the accounting and the status folder follow')
 Shapes.Unpin(o4);R.advance(Shapes.Config.IdleSeconds+Shapes.Config.SweepSeconds+1)
 check(Shapes.Status().Pairs==0 and Shapes.Status().Vertices==0,'unpinned and idle: everything is gone, 0 vertices')
 -- the hard cap: a pair that does not fit fails FOR GOOD (stable), the rest is untouched
 budget(2,3,30)
 local pins={};local function pin(x,id)local o={};pins[#pins+1]=o;Shapes.Pin(o,x.Key,id or 1)end
 bakeAt(a);pin(a);bakeAt(b);pin(b);bakeAt(c);pin(c)
 local w0=warns()
 check(Shapes.Request(d.Key,1)=='Off'and reasonOf(d.Key,1):find('over budget',1,true)~=nil,'at the hard cap with everything pinned a new pair does not fit: Off, "over budget" ('..reasonOf(d.Key,1)..')')
 check(folder():GetAttribute('LastFailure')=='over budget'and not tostring(folder():GetAttribute('LastFailure')):find(d.Key,1,true),'R152: ... and the replicated folder says only "over budget", no design')
 check(Mock.baked==3,'... refused by the pre-bake guard: no MeshPart was made for it ('..Mock.baked..' made for 3 pairs)')
 check(state(a)=='Ready'and state(b)=='Ready'and state(c)=='Ready'and Shapes.Status().Vertices==3*V and Mock.bakedAlive==3 and Mock.alive==0,'... the pinned pairs are untouched and nothing is left over (3 pairs, '..Shapes.Status().Vertices..' vertices, no stray mesh)')
 local pack=H.ground(d.Stage,d.Variant,1,'None',nil,1);check(sameSig(sig(pack),defaultPack(d.Stage,d.Variant))and pack:GetAttribute('PackShapeShown')==0,'... and a pack of that pair is the default pack');pack:Destroy()
 for _,o in ipairs(pins)do Shapes.Unpin(o)end
 check(Shapes.State(d.Key,1)=='Off','STABLE: with room available again the pair that did not fit stays the default (sticky), it does not appear later')
 check(bakeNow(e.Key,1)=='Ready'and state(a)=='Idle','... a different pair now bakes by evicting what is idle (least recently used first)')
 check(Shapes.Status().Failures==1 and warns()==w0+1,'one failure, one warning')
 -- a pair that only turns out too big AFTER its bake (the guard let it start): everything left is pinned, so it is dropped and fails for good
 budget(2,3.4,30)
 local pins2={};local function pin2(x)local o={};pins2[#pins2+1]=o;Shapes.Pin(o,x.Key,1)end
 bakeAt(a);pin2(a);bakeAt(b);pin2(b);bakeAt(c);pin2(c)
 check(Shapes.Request(d.Key,1)=='Off'and reasonOf(d.Key,1):find('would be resident',1,true)~=nil,'a pair that does not fit once baked (the guard had let it start) and nothing unpinned to evict: dropped, Off ('..reasonOf(d.Key,1)..')')
 check(state(a)=='Ready'and state(b)=='Ready'and state(c)=='Ready'and Shapes.Status().Vertices==3*V and Mock.bakedAlive==3 and Mock.alive==0 and Shapes.Status().Pairs==3,'... the three pinned pairs are untouched, the dropped pair left nothing behind ('..Shapes.Status().Vertices..' vertices, '..Mock.bakedAlive..' meshes)')
 for _,o in ipairs(pins2)do Shapes.Unpin(o)end
 -- the pre-bake guard evicts to make room (not a failure when something is evictable)
 budget(2,2,0)
 bakeAt(a);bakeAt(b)
 check(bakeNow(c.Key,1)=='Ready'and state(a)=='Idle','at the hard cap with an idle pair: the idle pair goes and the new one bakes (no failure)')
 -- accounting
 budget(5,6,0);for i=1,5 do bakeAt(SINGLE[i])end
 local sum=0;for i=1,5 do sum+=V end
 check(Shapes.Status().Vertices==sum and near(Shapes.Status().Megabytes,sum*48/1e6,1e-9),'the accounting: '..Shapes.Status().Vertices..' vertices = '..string.format('%.3f',Shapes.Status().Megabytes)..' MB estimated')
 -- a multi-mesh pair counts all its meshes
 budget(50,100,0);Mock.vertices=V;bakeNow('Lava_02',1);check(Shapes.Status().Vertices==2*V,'a two-mesh pair counts 2 x '..V..' vertices ('..Shapes.Status().Vertices..')')
 -- Reset gives everything back
 Shapes.Reset();check(Shapes.Status().Vertices==0 and Shapes.Status().Pairs==0 and Mock.bakedAlive==0,'Reset frees every template')
end

-- 8. Switches -------------------------------------------------------------------------------------------------------------------------------------
do
 fresh();server()
 local fired=0;local off=Shapes.OnChanged(function()fired+=1 end)
 check(Shapes.Mode()=='auto'and Shapes.Display(),'auto: the shapes show')
 Shapes.Config.Enabled=false;check(Shapes.Mode()=='off'and not Shapes.Display(),'Config.Enabled = false: Mode off');Shapes.Config.Enabled=true
 Shapes.Config.Force=3;check(Shapes.Mode()==3,'Config.Force = 3: Mode 3');Shapes.Config.Force=nil
 Shapes.Config.Force=9;check(Shapes.Mode()=='auto','a Force outside 1-6 is ignored');Shapes.Config.Force=nil
 -- a forced number is only the roll of NEW packs: nothing built changes, nobody is told
 bakeNow('Forest_02',3);local shaped=H.ground(1,'Pack02',1,'None',nil,3);local sSig=sig(shaped)
 check(Shapes.SetMode(5)==5 and folder():GetAttribute('Force')==5 and folder():GetAttribute('Off')==nil and Shapes.Mode()==5 and fired==0,'SetMode(5): the status folder says Force 5, Mode 5; the listeners are NOT told (nothing visible changes)')
 check(Shapes.Roll('Pack02')==5 and sameSig(sig(H.ground(1,'Pack02',1,'None',nil,3)),sSig)and Shapes.State('Forest_02',3)=='Ready','... new packs roll 5; a pack that rolled 3 is still 3 and its pair is still baked')
 -- off: every pack is the default, the cache is dropped, the listeners are told once
 check(Shapes.SetMode('off')=='off'and folder():GetAttribute('Off')==true and folder():GetAttribute('Force')==nil and fired==1,'SetMode(off): the status folder says Off, the listeners were told once')
 check(Shapes.Status().Pairs==0 and Shapes.Status().Vertices==0 and Mock.bakedAlive==0,'... every template is dropped (memory back to 0)')
 local calls=Mock.calls;local bagOff=H.ground(1,'Pack02',1,'None',nil,3)
 check(sameSig(sig(bagOff),defaultPack(1,'Pack02'))and bagOff:GetAttribute('PackShape')==3 and bagOff:GetAttribute('PackShapeShown')==0 and Mock.calls==calls,'off: a pack that rolled 3 is built in the default shape, nothing is loaded; it keeps its roll');bagOff:Destroy()
 check(Shapes.Roll('Pack02')==nil and Shapes.State('Forest_02',3)=='Off','off: nothing is rolled, State is Off')
 check(Shapes.Settle('Forest_02',3)==0,'off: Settle keeps nothing (the default shape for life)')
 check(Shapes.SetMode('auto')=='auto'and folder():GetAttribute('Off')==nil and fired==2,'SetMode(auto): back to normal; the listeners were told')
 local again=H.ground(1,'Pack02',1,'None',nil,3);check(again:GetAttribute('PackShapeShown')==3 and sameSig(sig(again),sSig),'auto again: the pack that rolled 3 is its shape again (the pair is baked on demand)');again:Destroy()
 check(Shapes.SetMode('on')=='auto','"on" is auto too')
 local ok1=pcall(Shapes.SetMode,7);local ok2=pcall(Shapes.SetMode,0);local ok3=pcall(Shapes.SetMode,'purple');local ok4=pcall(Shapes.SetMode,2.5)
 check(not ok1 and not ok2 and not ok3 and not ok4 and Shapes.Mode()=='auto','7, 0, 2.5 and "purple" are refused, the mode stays')
 client();local okc=pcall(Shapes.SetMode,3);check(not okc,'SetMode is a server call: a client is refused');server()
 local n=0;local off2=Shapes.OnChanged(function()n+=1 end);Shapes.SetMode('auto');Shapes.SetMode('auto');check(n==0,'setting the mode it already has notifies nobody');off2()
 -- failures are forgotten when shapes are switched off and on (the owner fixed the permission)
 fresh();Mock.mode='denied';Shapes.Request('Forest_02',3);check(Shapes.State('Forest_02',3)=='Off','(denied)');Mock.mode='ok';Shapes.SetMode('off');Shapes.SetMode('auto')
 check(Shapes.State('Forest_02',3)=='Idle'and folder():GetAttribute('FailureCount')==0,'off / auto forgets old failures: the pair may be tried again')
 Shapes.Request('Forest_02',3);check(Shapes.State('Forest_02',3)=='Ready','... and bakes')
 off()
 -- the status folder carries the new counters
 fresh();Shapes.Request('Forest_02',3);Shapes.Request('Forest_02',4);Shapes.Settle('Forest_03',2)
 local f=folder();check(f:GetAttribute('Pairs')==3 and f:GetAttribute('Evicted')==0 and f:GetAttribute('Demoted')==0 and f:GetAttribute('Mode')=='auto'and f:GetAttribute('Revision')==151,'the status folder: Pairs, Evicted, Demoted, Mode, Revision')
 -- the owner's /test packshape command
 fresh()
 local X=W.module('PackShapeCommand151')
 local function run(...)return X.Execute({},{Name='Owner'},{...})end
 local ok,text=run();check(ok==true and text:find('every new pack rolls one of the six',1,true)and text:find('Pillow',1,true)and text:find('Rolled this session',1,true),'/test packshape: the status ('..tostring(text):sub(1,60)..'...)')
 local ok3,t3=run('3');check(ok3 and t3:find('forced to variation 3 (Pear)',1,true)and Shapes.Mode()==3 and Shapes.Roll('Pack01')==3,'/test packshape 3: new packs are forced ('..tostring(t3):sub(1,60)..')')
 local okOff,tOff=run('off');check(okOff and tOff:find('OFF',1,true)and Shapes.Mode()=='off','/test packshape off')
 local okA,tA=run('auto');check(okA and Shapes.Mode()=='auto','/test packshape auto')
 local okU,tU=run('Auto');check(okU and Shapes.Mode()=='auto','(case does not matter)')
 for _,bad in ipairs({'0','7','2.5','purple','-1'})do local okB,tB=run(bad);check(okB==false and tB:find('Use packshape',1,true)and Shapes.Mode()=='auto','/test packshape '..bad..' is refused with the usage')end
 local okM=run('1','2');check(okM==false,'two arguments are refused')
 do local rolls={};for _=1,600 do rolls[#rolls+1]=Shapes.Roll('Pack03')end local _,t=run();check(t:find('Rolled this session: Pillow %d+, Hourglass %d+, Pear %d+, Top%-heavy %d+, Shoulders %d+, Flat %d+')~=nil,'the status lists how the rolls fell')end
end

-- 9. Pictures (the real ItemPictures) -------------------------------------------------------------------------------------------------------------
do
 fresh();client()
 local Pic=W.module('ItemPictures')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=H.pg
 local function holder(x)local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(x,0);return h end
 local function view(h)return h:FindFirstChild('ItemViewport')end
 local function meshOf(v)for _,d in ipairs(v:GetDescendants())do if d:IsA('MeshPart')then return d end end end
 local function settle(n)for _=1,n or 400 do W.frames(1)end end
 local function tool(stage,variant,coat,shape,name)local t=F.pack(W,W.workspace,stage,variant,1,coat or'None',name or'Pack');if shape then t:SetAttribute('PackShape',shape)end;return t end
 local scale=Rules.GetVariant('Pack02').BagScale*Rules.GetTheme(1).Scale
 -- the key and the spec
 local k0,s0=Pic.Key(tool(1,'Pack02'));local k3,s3=Pic.Key(tool(1,'Pack02','None',3));local k4=Pic.Key(tool(1,'Pack02','None',4));local k9,s9=Pic.Key(tool(1,'Pack02','None',9));local kz=Pic.Key(tool(1,'Pack02','None',0))
 check(k0=='Pack|1|Pack02|None'and s0.Shape==nil,'a tool without a shape: the old key and no Shape in its spec ('..k0..')')
 check(k3=='Pack|1|Pack02|None|3'and s3.Shape==3 and k4=='Pack|1|Pack02|None|4','a tool with PackShape 3 / 4: the key carries the shape ('..k3..' / '..k4..'): two shapes are two pictures')
 check(k9==k0 and kz==k0 and s9.Shape==nil,'PackShape 0 / 9 (invalid) is the default look: the same key as no shape')
 local ks=Pic.SampleKey('All');check(ks=='Pack|1|Standard|None','the sample picture of a category tab is the default shape ('..ks..')')
 -- (a) while the client's bake runs: nothing is drawn, nothing is cached
 Mock.slow=true
 local t1=tool(1,'Pack02','None',3);local h1=holder(0);Pic.Show(h1,t1,1);settle(150)
 check(view(h1)==nil and Shapes.State('Forest_02',3)=='Loading','(a) while the client\'s bake runs the picture waits ("still loading", retried): no picture, nothing cached')
 while Mock.resume()do end;settle(300)
 local v=view(h1)
 if check(v~=nil,'(b) the bake finishes and the picture draws on its own retry')then
  local m=meshOf(v);local want=Shapes.Template('Forest_02',3).ApprovedMesh01.Size
  check(m and near(m.Size.X,want.X*scale,1e-6)and near(m.Size.Z,want.Z*scale,1e-6)and m.MeshId=='','(b) the hotbar / Bag picture is the SHAPED pouch (a baked MeshPart of the shaped Size '..tostring(m and m.Size)..')')
 end
 Mock.slow=false
 -- (c) the same pack in another shape is another picture; a stack never mixes (the key differs)
 local t2=tool(1,'Pack02','None',6);local h2=holder(70);Pic.Show(h2,t2,1);settle(200)
 local m2=view(h2)and meshOf(view(h2));local m1=view(h1)and meshOf(view(h1))
 check(m1 and m2 and not near(m1.Size.Z,m2.Size.Z,1e-9)and near(m2.Size.Z,Shapes.Template('Forest_02',6).ApprovedMesh01.Size.Z*scale,1e-6),'(c) shape 6 (Flat) draws its own shape, a different depth from shape 3')
 -- (d) the Index / a sample / a proxy pack (no PackShape) is the default shape, even beside shaped ones
 local proxy=R.new('Folder');proxy:SetAttribute('SeedPackTool',true);proxy:SetAttribute('Stage',1);proxy:SetAttribute('BagVariant','Pack02');proxy:SetAttribute('PackMutation','None')
 local h3=holder(140);Pic.Show(h3,proxy,1);settle(200)
 local m3=view(h3)and meshOf(view(h3))
 check(m3 and m3.MeshId==assets.Forest_02.ApprovedMesh01.MeshId and near(m3.Size.X,assets.Forest_02.ApprovedMesh01.Size.X*scale,1e-6),'(d) a catalogue / Index / shop picture (a tool with no shape) is the default pouch, the place\'s own mesh')
 -- (d2) a proxy flagged DefaultPackShape (the catalogue, shop and reward pictures: VerityClient, DailyRewardsClient, TreadmillBonusClient) is the default pouch WHATEVER its PackShape says, has
 -- its own look (|Plain) for the designs the variations touch, and never asks PackShapes151 for anything; the Void and the Mech pack share the ordinary look
 do
  local calls0=Mock.calls;local req0=Shapes.Status().Requested
  local function flaggedProxy(stage,variant,shape)local f=R.new('Folder');f:SetAttribute('SeedPackTool',true);f:SetAttribute('Stage',stage);f:SetAttribute('BagVariant',variant);f:SetAttribute('PackMutation','None');f:SetAttribute('DefaultPackShape',true);if shape then f:SetAttribute('PackShape',shape)end;return f end
  local fp=flaggedProxy(1,'Pack02',3);local kf,sf=Pic.Key(fp)
  check(kf=='Pack|1|Pack02|None|Plain'and sf.Plain==true and sf.Shape==nil,'(d2) a flagged proxy that also says PackShape 3: the |Plain look, no Shape in its spec ('..kf..')')
  check(kf~=Pic.Key(tool(1,'Pack02','None',3))and kf~=Pic.Key(tool(1,'Pack02')),'(d2) ... not the look of the pack that rolled 3, and a look of its own beside the shapeless pack\'s')
  check(Pic.Key(flaggedProxy(7,'EclipseReliquary',2))=='Pack|7|EclipseReliquary|None'and Pic.Key(flaggedProxy(8,'MechLimited'))=='Pack|8|MechLimited|None','(d2) the Void and the Mech pack share the ordinary look (one template, not two)')
  check(Pic.Key(flaggedProxy(7,VERITY))=='Pack|7|'..VERITY..'|None|Plain','(d2) the Verity pack has its |Plain look')
  local hf=holder(560);Pic.Show(hf,fp,1);settle(200)
  local mf=view(hf)and meshOf(view(hf))
  check(mf and mf.MeshId==assets.Forest_02.ApprovedMesh01.MeshId and near(mf.Size.X,assets.Forest_02.ApprovedMesh01.Size.X*scale,1e-6),'(d2) the flagged picture is the default pouch, the place\'s own mesh, though the pair (Forest_02, 3) is baked and a hotbar picture of it is shaped')
  local hg=holder(630);Pic.Show(hg,flaggedProxy(2,'Pack03',4),1);settle(200)
  check(view(hg)~=nil and Shapes.State('Forest_03',4)=='Idle'and Mock.calls==calls0 and Shapes.Status().Requested==req0,'(d2) a flagged picture of a pair that is not baked asks for nothing: no bake, no request ('..(Mock.calls-calls0)..' loads, '..(Shapes.Status().Requested-req0)..' requests)')
 end
 local h4=holder(210);Pic.ShowSample(h4,'All',1);settle(200)
 check(view(h4)~=nil and meshOf(view(h4))and meshOf(view(h4)):GetAttribute('Variation')==nil,'(d) the sample picture of a category tab is the default shape')
 -- (e) Gold keeps the shape
 local tg=tool(1,'Pack02','Gold',3,'Gold Pack');local h5=holder(280);Pic.Show(h5,tg,1);settle(200)
 local gm=view(h5)and meshOf(view(h5))
 check(gm and near(gm.Size.X,Shapes.Template('Forest_02',3).ApprovedMesh01.Size.X*scale,1e-6)and sameColor(gm.Color,Rules.PackMutations.Gold.Color),'(e) a Gold picture: the same shaped pouch, gold')
 -- (f) a pair that cannot be baked: a STABLE default picture (the cause going away does not change it)
 fresh();Mock.mode='denied';client();Pic.Reset()
 local tf=tool(3,'Pack03','None',2,'Snow Pack');local h6=holder(350);Pic.Show(h6,tf,1);settle(400)
 local mf=view(h6)and meshOf(view(h6))
 local snowIds={};for _,p in ipairs(meshesOf('Snow_03'))do snowIds[p.MeshId]=true end
 check(mf and snowIds[mf.MeshId]==true,'(f) after a failed bake the picture is the default pouch (the place\'s own mesh)')
 Mock.mode='ok';Pic.Reset();local h7=holder(420);Pic.Show(h7,tf,1);settle(300)
 local mf2=view(h7)and meshOf(view(h7))
 check(mf2 and snowIds[mf2.MeshId]==true and Shapes.State('Snow_03',2)=='Off','(f) with the cause gone the picture is still the default: sticky, no flip between shapes')
 -- (g) off / auto redraw every picture
 fresh();Mock.reset();client();Pic.Reset()
 local h8=holder(490);Pic.Show(h8,t1,1);settle(300)
 local first=view(h8)and meshOf(view(h8));local firstMeshId=first and first.MeshId
 server();Shapes.SetMode('off');client();settle(300)
 local second=view(h8)and meshOf(view(h8))
 check(first and firstMeshId==''and second and second.MeshId==assets.Forest_02.ApprovedMesh01.MeshId,'(g) /test packshape off: the picture is drawn again in the default shape')
 server();Shapes.SetMode('auto');client();settle(300)
 local third=view(h8)and meshOf(view(h8))
 check(third and third.MeshId==''and near(third.Size.X,Shapes.Template('Forest_02',3).ApprovedMesh01.Size.X*scale,1e-6),'(g) /test packshape auto: shaped again')
 server();Pic.Reset();gui:Destroy();Mock.slow=false
end

-- 10. Verity: NEVER shaped (R152) -----------------------------------------------------------------------------------------------------------------------
-- The Verity pack is one clean FLAT pouch (VerityPouch151, generated), the same in every context: no roll, no record field, no baked pair, whatever any attribute says.
do
 fresh();server()
 local KEY='Storm_02'
 local function decals(inst)local out={};for _,d in ipairs(inst:GetDescendants())do if d:IsA('Decal')then out[#out+1]=d end end;return out end
 check(Pouch.Prepare()==true,'(the server\'s flat Verity pouch is made)')
 local made0=Mock.created;local calls0=Mock.calls
 local default=H.ground(7,VERITY,1,'None');local defSig=sig(default);local defMesh=pouchOf(default)
 check(default:GetAttribute('VerityPouch')==true and default:GetAttribute('PackShape')==nil and defMesh and defMesh:GetAttribute('Flat')~=false,'a Verity pack with no shape is the flat pouch')
 check(Shapes.Applies(VERITY)==false and Shapes.Applies('Pack06')==true and Shapes.Applies('Standard')==true,'PackShapes151.Applies: the Verity pack takes no shape; the ordinary packs do')
 -- the roll: never, in any mode, with any dice
 local rolled=0
 for k=0,100 do if Shapes.Roll(VERITY,k/100)~=nil then rolled+=1 end end
 for _,mode in ipairs({1,2,3,4,5,6,'auto'})do Shapes.SetMode(mode);if Shapes.Roll(VERITY)~=nil then rolled+=1 end;if Shapes.Roll(VERITY,.5)~=nil then rolled+=1 end end
 Shapes.SetMode('auto')
 check(rolled==0,'a Verity pack never rolls a shape (101 dice, every forced number, auto): '..rolled..' rolls')
 check(Shapes.Status().Rolled[1]+Shapes.Status().Rolled[2]+Shapes.Status().Rolled[3]+Shapes.Status().Rolled[4]+Shapes.Status().Rolled[5]+Shapes.Status().Rolled[6]==0,'... and the roll statistics never saw one')
 -- handed a shape anyway (an older record, a world pack, a hand, a picture, a market stall, the pedestal, a viewport): the same flat pouch, no PackShape on it
 for shape=1,6 do
  local viaBuilder=H.ground(7,VERITY,1,'None',nil,shape)
  check(viaBuilder:GetAttribute('PackShape')==nil and viaBuilder:GetAttribute('PackShapeShown')==nil and sameSig(sig(viaBuilder),defSig),'a Verity pack handed shape '..shape..' is the same flat pouch, with no PackShape')
  local stale=Visuals.Bag(CF(0,0,0),nil,1,nil,7,'Standard',1,1,'None');stale:SetAttribute('BagVariant',VERITY)
  for _,d in ipairs(stale:GetChildren())do if d.Name=='PackGeometry'then d:Destroy()end end
  for _,a in ipairs({'CompactPackReady','CompactPackPartCount'})do stale:SetAttribute(a,nil)end
  stale:SetAttribute('PackShape',shape);W.module('VerityPackArt').Build(stale,function()return true end)
  check(pouchOf(stale)and pouchOf(stale):GetAttribute('Flat')~=false and stale:GetAttribute('PackShapeShown')==nil and stale:GetAttribute('VerityPouch')==true and #decals(stale)==2,'a Verity bag that itself says PackShape '..shape..' (a stale attribute) is built as the flat pouch: ignored')
  local pic=H.picture(7,VERITY,1,'None',shape);check(pic:GetAttribute('PackShape')==nil and sameSig(sig(pic),sig(H.picture(7,VERITY,1,'None'))),'a hotbar / Bag picture of a Verity pack that rolled '..shape..' is the flat pouch');pic:Destroy()
  local flagged=H.picture(7,VERITY,1,'None',shape,true);check(flagged:GetAttribute('DefaultPackShape')==true and sameSig(sig(flagged),sig(H.picture(7,VERITY,1,'None'))),'a flagged (shop / Index / dialog) picture is the flat pouch too');flagged:Destroy()
  viaBuilder:Destroy();stale:Destroy()
 end
 for _,rig in ipairs({'R15','R6'})do
  local held,char=H.held(7,VERITY,1,'None',rig,3);local plainHeld,char2=H.held(7,VERITY,1,'None',rig)
  check(held:GetAttribute('PackShape')==nil and sameSig(sig(held),sig(plainHeld)),'held '..rig..': handed shape 3 it is the flat pouch');local copy=H.openingCopy(held);check(#decals(copy)==2 and pouchOf(copy)~=nil,'opening copy: the flat pouch with both Decals');copy:Destroy();held:Destroy();char:Destroy();plainHeld:Destroy();char2:Destroy()
 end
 local market=H.market(7,VERITY,5);check(pouchOf(market)~=nil and #decals(market)==2 and market:GetAttribute('PackShape')==nil,'the market / shop stall picture is the flat pouch with both Decals');market:Destroy()
 local mystery,holder=H.mystery(7,VERITY,false,3);check(mystery:GetAttribute('PackShape')==nil and mystery:GetAttribute('VerityPouch')==true,'the mystery pedestal\'s Ready Verity pack is the flat pouch');holder:Destroy()
 for _,coat in ipairs({'Gold','Diamond'})do local g=H.ground(7,VERITY,1,coat,nil,3);local c=Rules.PackMutations[coat];check(sameColor(pouchOf(g).Color,c.Color)and #decals(g)==2 and decals(g)[1].Color3.R==1,'a '..coat..' Verity pack handed shape 3: the coat paints the pouch, the Decals stay white');g:Destroy()end
 local giant=H.ground(7,VERITY,25,'None',nil,3);local tagged=0;for _,p in ipairs(H.partsOf(giant,false))do if W.CS:HasTag(p,'GiantVisualPart')then tagged+=1 end end
 check(tagged==10,'a 25x Verity pack handed shape 3: the pouch, the seal and the 8 strips are GiantVisualParts ('..tagged..')');giant:Destroy()
 -- nothing of PackShapes151 was ever used for it
 check(Shapes.Status().Requested==0 and Shapes.Status().Baked==0 and Shapes.Status().Pairs==0 and Shapes.State(KEY,3,true)=='Idle'and Shapes.State(KEY,5,false)=='Idle','PackShapes151 was never asked for a pair for any of it (0 requested, 0 baked)')
 check(Mock.created==made0 and Mock.calls==calls0,'no EditableMesh was made for any of it ('..(Mock.created-made0)..' made, '..(Mock.calls-calls0)..' calls)')
 -- never waits for a shape, never errors "still loading" because of one: a client picture of a Verity pack that rolled 2 draws at once
 client();local okc,errc=pcall(function()return H.picture(7,VERITY,1,'None',2)end)
 check(okc,'a client\'s Verity picture that carries a shape draws at once: no "still loading" for a shape that does not exist ('..tostring(errc)..')');if okc then errc:Destroy()end
 server()
 -- the switches change nothing for it
 Shapes.SetMode('off');local offBag=H.ground(7,VERITY,1,'None',nil,3);check(sameSig(sig(offBag),defSig),'/test packshape off: the same flat pouch');offBag:Destroy();Shapes.SetMode('auto')
 -- no flat pouch (a server that did not make it): the R149 sachet whatever it was handed; nothing is loaded
 fresh();server();local calls1=Mock.calls;local sachet=H.ground(7,VERITY,1,'None',nil,4)
 check(sachet:GetAttribute('VerityPackDesign')==149 and sachet:FindFirstChild('VerityFace',true)~=nil and Mock.calls==calls1,'with no flat pouch (a server that did not make it) the Verity pack is the R149 sachet whatever it was handed; nothing is loaded');sachet:Destroy()
 -- (control) an ordinary pack of the same stage still takes its shape
 local ord=H.ground(7,'Pack06',1,'None',nil,3);check(ord:GetAttribute('PackShape')==3,'(control) an ordinary pack still carries its shape');ord:Destroy()
 default:Destroy()
 check(Mock.alive==0,'(no EditableMesh left alive)')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
