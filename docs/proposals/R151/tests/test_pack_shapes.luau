--!nocheck
-- R151 (owner: "make pack shape variations in blender; the pack shape will still be a chip shape but will be slightly different"): PackShapes151 on the Roblox
-- mock with the REAL modules of this checkout, the REAL pack templates of the owner's place (pack_templates.luau: 42 designs, 115 MeshParts) and a mock of the
-- EditableMesh route whose meshes are lattices that fill each template part's Size box (pouch_mock.luau: every way the real route can fail).
--  1. the field     PackShapes151.Field against the Blender design's samples (pack_shape_samples.luau, written by blender/pack_shapes.py), and what every field promises:
--                   y never moves, the crimps (|v| >= .94) are untouched, nothing grows by more than 5%, each variation is visible, the six differ, symmetric
--  2. assignment    one variation per design NAME: deterministic (golden table), neighbouring tiers of a biome differ, every biome and the game use all six
--  3. the bake      loads the template's own MeshId, moves every vertex by the field (y and the crimp rows exactly where they were, <= 5% outward, the mesh's centre
--                   where it was), keeps colours and UVs (never set), updates the normals, ONE EditableMesh at a time and each destroyed, the same design once;
--                   all 42 designs: every box within +5% of today's, y / pivot / PackLocalFrame identical, Bounds identical
--  4. contexts      ground, held R15 / R6, CarryBag, picture, opening copy, market, mystery pedestal, viewport; sizes 1 / 25; None / Gold / Diamond: the same shaped pouch
--                   part for part; seal and strips exactly where today's are; the Void, the Mech and the sachet never reshaped
--  5. fallbacks     denied / no vertices / no positions / bake or MeshPart fails / size mismatch / too many vertices / memory cap / missing or incomplete template /
--                   the 2nd mesh fails (the 1st is destroyed) / a bake that never returns: that design keeps today's mesh, exactly, one warning, nothing leaked,
--                   the status folder says why, the others still bake
--  6. switches      Config.Enabled, Config.Force, the owner's attributes (SetMode off / auto / 1-6), listeners told, caches of another variation dropped, the
--                   /test packshape command
--  7. waiting       a server waits (bounded) for a design's first bake so every pack is the same; a client never waits (ItemPictures retries "still loading")
--  8. pictures      the real ItemPictures: still loading -> no picture, then the shaped pouch in the ViewportFrame; a mode change redraws
--  9. Verity        the Verity pouch is Storm_02's shape (same vertices moved), unshaped if the variation cannot be applied, re-baked when the mode changes
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
server()
local Shapes=W.module('PackShapes151');local Visuals=H.Visuals;local Rules=H.Rules
local warns=function()return W.warns or 0 end
local function folder()return W.RS:FindFirstChild(Shapes.Folder)end
local function fresh()Shapes.Reset();Mock.reset();Shapes.Config.Enabled=true;Shapes.Config.Force=nil;local f=folder();if f then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)end end
local assets=W.RS.SeedPackMeshAssets
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do p.MeshSize=p.Size end end -- (the place's templates have a MeshSize; the generated ones do not)
-- every design of the game, in the order stage x tier
local DESIGNS={}
for stage=1,7 do for tier=1,6 do DESIGNS[#DESIGNS+1]={Key=Rules.DesignKey(stage,string.format('Pack%02d',tier)),Stage=stage,Variant=string.format('Pack%02d',tier),Tier=tier,Biome=Rules.DesignBiomes[stage]}end end
local function meshesOf(key)local l={};for _,p in ipairs(assets[key]:GetChildren())do if p:IsA('MeshPart')then l[#l+1]=p end end;table.sort(l,function(a,b)return a.Name<b.Name end);return l end
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
  out[(p.Parent==bag and''or'PackGeometry/')..p.Name]={Size=p.Size/scale,Pos=f.Position/scale,Frame=f,Class=p._class}
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
local function reasonOf(key)local _,why=Shapes.State(key);return tostring(why)end
local function pouchSize(bag)local m=bag:FindFirstChild('ApprovedMesh01',true);return m and m.Size/(bag:GetAttribute('VisualScale')or 1)end
local function todays(stage,variant,size,coat)fresh();Shapes.Config.Enabled=false;local b=H.ground(stage,variant,size,coat);local s=sig(b);b:Destroy();Shapes.Config.Enabled=true;Shapes.Reset();return s end

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
  local yFixed,crimp,out,maxGrow,maxShrink,sym=true,true,true,0,0,true;local seen=0
  for a=-40,40 do for b=-40,40 do for _,w in ipairs({-1,-.4,0,.4,1})do
   local u,v=a/40,b/40
   local x,y,z=Shapes.Field(id,u,v,w)
   if y~=v then yFixed=false end
   if math.abs(v)>=.94 and(x~=u or z~=w)then crimp=false end
   local sx=u~=0 and x/u or 1;local sz=w~=0 and z/w or 1
   maxGrow=math.max(maxGrow,sx-1,sz-1);maxShrink=math.max(maxShrink,1-sx,1-sz)
   local x2,_,z2=Shapes.Field(id,-u,v,-w);if x2~=-x or z2~=-z then sym=false end
   if math.abs(sx-1)>.001 or math.abs(sz-1)>.001 then seen+=1 end
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

-- 2. Assignment -----------------------------------------------------------------------------------------------------------------------------------
do
 local golden={Forest='123456',Desert='234561',Snow='345612',Lava='456123',Crystal='612345',Jungle='456123',Storm='561234'} -- (the shipped assignment: it must never change)
 local byBiome,used={},{}
 for _,d in ipairs(DESIGNS)do byBiome[d.Biome]=byBiome[d.Biome]or{};byBiome[d.Biome][d.Tier]=Shapes.Assign(d.Key);used[Shapes.Assign(d.Key)]=true end
 local lines={}
 for stage=1,7 do
  local biome=Rules.DesignBiomes[stage];local row=byBiome[biome]
  local text=table.concat(row,'');lines[#lines+1]=biome..' '..text
  check(text==golden[biome],biome..': tiers 1-6 have variations '..text..' (the golden table says '..golden[biome]..')')
  local neighbours=true;for t=1,5 do if row[t]==row[t+1]then neighbours=false end end
  check(neighbours,biome..': neighbouring tiers differ')
  local all={};for _,v in ipairs(row)do all[v]=true end
  check(#row==6 and all[1]and all[2]and all[3]and all[4]and all[5]and all[6],biome..': the six tiers use all six variations')
 end
 check(used[1]and used[2]and used[3]and used[4]and used[5]and used[6],'all six variations are in use across the 42 designs')
 local again=true;for _,d in ipairs(DESIGNS)do if Shapes.Assign(d.Key)~=Shapes.Assign(d.Key)then again=false end end
 check(again,'deterministic: the same name, the same variation, every call')
 check(Shapes.Assign('Forest_01')==1 and Shapes.Assign('Storm_02')==6,'Forest_01 is variation 1 and Storm_02 (the Verity pouch) variation 6')
 local odd=Shapes.Assign('Mystery');check(odd>=1 and odd<=6 and odd==Shapes.Assign('Mystery'),'a name that is not Biome_NN still gets one fixed variation ('..odd..')')
 check(Shapes.Assign(nil)>=1 and Shapes.Assign('')>=1,'nil / empty names do not error')
 print('assignment: '..table.concat(lines,' | '))
end

-- 3. The bake -------------------------------------------------------------------------------------------------------------------------------------
-- Checks one baked design against its template: `meshes` = the mock EditableMeshes of this design in bake order (the template's parts sorted by name).
local function geometry(key,id,meshes,label)
 local parts=meshesOf(key);local lo,hi=boxOf(parts);local c=(lo+hi)/2;local h=(hi-lo)/2
 local shaped={};for _,p in ipairs(Shapes.Template(key):GetChildren())do if p:IsA('MeshPart')then shaped[#shaped+1]=p end end;table.sort(shaped,function(a,b)return a.Name<b.Name end)
 local ok,why=true,''
 local moved,total=0,0;local worstOut=-1;local worstY=0;local worstCrimp=0;local worstMid=0;local normalsOk=true
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
   -- the normals: unit, and turned by a little
   local n0=(m._init[v]-mid);n0=n0.Magnitude>1e-9 and n0.Unit or V3(0,0,1)
   local n1=m._normals[v];if not(near(n1.Magnitude,1,1e-6)and n1:Dot(n0)>.5)then normalsOk=false end
  end
 end
 check(ok,label..': every mesh was loaded ('..why..')')
 check(worstY<2e-6,label..': no vertex moved in y (the pivot and the bottom line stay) ('..string.format('%.2g',worstY)..')')
 check(worstCrimp<2e-6,label..': the crimp rows (|v| >= .94) did not move at all, so the seal and the strips stay flush ('..string.format('%.2g',worstCrimp)..')')
 check(worstOut<=.05+1e-9,label..string.format(': nothing went outside the design\'s box by more than 5%% (%.3f)',worstOut))
 check(worstMid<2e-6,label..': each part\'s PackLocalFrame follows its mesh\'s bounding-box centre, so the vertices stay where the field put them ('..string.format('%.2g',worstMid)..')')
 check(moved/total>.1,label..string.format(': the field moved %d%% of the vertices',math.floor(moved/total*100)))
 check(normalsOk,label..': the normals are unit length and turned by less than 60 degrees')
end
local function templateChecks(key,id,label)
 local model=Shapes.Template(key);local parts=meshesOf(key)
 if not check(model~=nil and model:IsA('Model')and model.Parent==nil and model.Name==key,label..': the shaped template is a Model of the design, kept in memory (never parented)')then return end
 check(model:GetAttribute('PackShape')==id and model:GetAttribute('MeshCount')==#parts and model:GetAttribute('MeshBakeVersion')==123,label..': it says its variation ('..tostring(model:GetAttribute('PackShape'))..') and keeps the template\'s MeshCount / MeshBakeVersion')
 local got={};for _,p in ipairs(model:GetChildren())do if p:IsA('MeshPart')then got[#got+1]=p end end;table.sort(got,function(a,b)return a.Name<b.Name end)
 local lo0,hi0=boxOf(parts)
 local same=#got==#parts;local worst=0;local yEq=true;local frames=true
 for i,p in ipairs(got)do local s=parts[i]
  if p.Name~=s.Name then same=false else
   local ratio=V3(p.Size.X/s.Size.X,p.Size.Y/s.Size.Y,p.Size.Z/s.Size.Z)
   worst=math.max(worst,ratio.X-1,ratio.Z-1);if p.Size.Y~=s.Size.Y then yEq=false end
   local f1,f2=p:GetAttribute('PackLocalFrame'),s:GetAttribute('PackLocalFrame');local d,r=cfDelta(f1,f2)
   if math.abs(f1.Position.Y-f2.Position.Y)>1e-9 or r>1e-9 or d>.1 then frames=false end -- (same rotation; the centre moved sideways at most a little; never in y)
   -- (a small part off the box's middle can change size by more than 5% of ITSELF: what is bounded is how far it moves inside the box, 5%, checked by `geometry`)
   if p.Size.X-s.Size.X>.05*(hi0.X-lo0.X)+1e-9 or p.Size.Z-s.Size.Z>.05*(hi0.Z-lo0.Z)+1e-9 or ratio.X<.5 or ratio.Z<.5 then same=false;print('   '..label..' '..p.Name..' ratio '..tostring(ratio)) end
   if p.Anchored~=true or p.CanCollide~=false or p.MeshId==s.MeshId then same=false end
  end
 end
 check(same,label..': the same MeshParts (names), each Size within 5% (of the design\'s width / depth) of the template\'s, anchored, a baked mesh (not the template\'s MeshId)')
 check(yEq and frames,label..': Size.Y is exactly the template\'s and every PackLocalFrame keeps its rotation (the 180 degree turn) and its height (the bottom line)')
 local scaleOk=true
 for i,p in ipairs(got)do local s=parts[i];for _,a in ipairs({'X','Y','Z'})do if not near(p.Size[a]/p.MeshSize[a],s.Size[a]/s.MeshSize[a],1e-6)then scaleOk=false end end end
 check(scaleOk,label..': the studs per mesh unit are the template\'s (the reshaped mesh is not stretched)')
 -- Bounds: inside today's box +-5%
 local lo,hi=boxOf(parts);local lo2,hi2=boxOf(got)
 local ext,ext2=hi-lo,hi2-lo2
 check(ext2.Y==ext.Y and lo2.Y==lo.Y and hi2.Y==hi.Y and ext2.X<=ext.X*1.0501 and ext2.Z<=ext.Z*1.0501 and ext2.X>=ext.X*.79 and ext2.Z>=ext.Z*.79,label..string.format(': the design\'s box: height and bottom / top exactly today\'s, width %.3f and depth %.3f of today\'s',ext2.X/ext.X,ext2.Z/ext.Z))
end
do
 fresh()
 local key='Lava_02';local parts=meshesOf(key);local id=Shapes.Assign(key)
 check(#parts==2,'(Lava_02 has two MeshParts, to test a design with more than one mesh)')
 check(Shapes.State(key)=='Idle'and Shapes.Template(key)==nil,'before a request: Idle, no template')
 local calls=Mock.calls
 check(Shapes.Request(key)=='Ready','a request bakes the design (the mock answers at once): Ready')
 check(Mock.calls==calls+2 and Mock.created==2 and Mock.alive==0 and Mock.maxAlive==1 and Mock.baked==2 and Mock.bakedAlive==2,('two meshes loaded one after the other, both EditableMeshes destroyed (alive %d, most at once %d), both MeshParts kept'):format(Mock.alive,Mock.maxAlive))
 check(Mock.uris[1]==parts[1].MeshId and Mock.uris[2]==parts[2].MeshId,'the meshes loaded are the live template\'s own MeshIds, in part order ('..tostring(Mock.uris[1])..')')
 check(Mock.sets.Color==0 and Mock.sets.ColorAlpha==0 and Mock.sets.UV==0,'vertex colours and UVs are never set: the print stays')
 local intact=true;for _,m in ipairs(Mock.meshes)do for i,c in ipairs(m._colors)do if c.R~=R.Color3.fromRGB(20+(i*37)%200,15+(i*11)%120,30+(i*53)%220).R then intact=false end end end
 check(intact,'... and every vertex colour is what the print had')
 check(Mock.sets.Position==2*Mock.vertices and Mock.sets.Normal>0,('every vertex of both meshes got a position (%d), and normals were set (%d)'):format(Mock.sets.Position,Mock.sets.Normal))
 geometry(key,id,Mock.meshes,'Lava_02 / variation '..id)
 templateChecks(key,id,'Lava_02')
 local f=folder()
 check(f and f:GetAttribute('Ready')==true and f:GetAttribute('FailureCount')==0 and f:GetAttribute('BakedCount')==1 and f:GetAttribute('Requested')==1 and f:GetAttribute('Pending')==0 and f:GetAttribute('Vertices')==3600 and f:GetAttribute('Mode')=='auto','the status folder: Ready, FailureCount 0, BakedCount 1, Requested 1, Pending 0, 3600 vertices, mode auto')
 local c2=Mock.calls;Shapes.Request(key);Shapes.ForBuild(key);check(Mock.calls==c2,'a design is baked once')
 -- the id is READ from the template at run time, not written in the module
 local src=W.B.PackShapes151
 check(not src:find('rbxassetid',1,true)and src:find('CreateEditableMeshAsync',1,true)and src:find('SetPosition',1,true)and src:find('CreateMeshPartAsync',1,true),'(source: no asset id in PackShapes151; it loads the template\'s MeshId with CreateEditableMeshAsync, moves vertices with SetPosition, bakes with CreateMeshPartAsync)')
 check(not src:find('SetColor',1,true)and not src:find('SetUV',1,true)and not src:find(':SetColorAlpha',1,true),'(source: it never sets a colour or a UV)')
end
-- every design
do
 fresh();local bad=0;local firstBad
 local before=Mock.created
 for _,d in ipairs(DESIGNS)do
  local n=#meshesOf(d.Key);local startMesh=#Mock.meshes
  Shapes.Request(d.Key)
  if Shapes.State(d.Key)~='Ready'then bad+=1;firstBad=firstBad or d.Key end
  local mine={};for i=startMesh+1,#Mock.meshes do mine[#mine+1]=Mock.meshes[i]end
  geometry(d.Key,Shapes.Assign(d.Key),mine,d.Key)
  templateChecks(d.Key,Shapes.Assign(d.Key),d.Key)
 end
 check(bad==0,'all 42 designs bake ('..bad..' did not'..(firstBad and(', first '..firstBad)or'')..')')
 check(Mock.created==115 and Mock.alive==0 and Mock.maxAlive==1 and Mock.bakedAlive==115,('115 meshes for 42 designs, one EditableMesh alive at a time (most %d), none left (%d)'):format(Mock.maxAlive,Mock.alive))
 local f=folder();check(f:GetAttribute('BakedCount')==42 and f:GetAttribute('FailureCount')==0 and f:GetAttribute('Ready')==true and f:GetAttribute('Vertices')==115*1800,'status: BakedCount 42, FailureCount 0, Ready, '..tostring(f:GetAttribute('Vertices'))..' vertices')
 -- Bounds are today's (Visuals.Bounds reads the place's own template) and the shaped pouch is inside them +5%: radius, bottom, top, measured the way Visuals.Bounds does
 local function extent(parts)
  local r,minY,maxY=0,1e9,-1e9
  for _,p in ipairs(parts)do local fr=p:GetAttribute('PackLocalFrame')
   for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
    local v=fr*V3(p.Size.X*x,p.Size.Y*y,p.Size.Z*z);r=math.max(r,V3(v.X,0,v.Z).Magnitude);minY=math.min(minY,v.Y);maxY=math.max(maxY,v.Y)
   end end end
  end
  return r,minY,maxY
 end
 local holds,same,worst=true,true,0
 for _,d in ipairs(DESIGNS)do for _,size in ipairs({1,25})do
  local scale=Rules.GetVariant(d.Variant).BagScale*Rules.GetTheme(d.Stage).Scale*Rules.SanitizePackSize(size)
  local b=Visuals.Bounds(d.Stage,d.Variant,size)
  local sp={};for _,p in ipairs(Shapes.Template(d.Key):GetChildren())do if p:IsA('MeshPart')then sp[#sp+1]=p end end
  local r,minY,maxY=extent(sp);local r0,minY0,maxY0=extent(meshesOf(d.Key))
  if r*scale>b.Radius*1.0501 or minY*scale<b.MinY-1e-9 or maxY*scale>b.MaxY+1e-9 then holds=false;print(('   Bounds %s %sx: shaped radius %.4f / Bounds %.4f'):format(d.Key,size,r*scale,b.Radius))end
  if r>r0*1.0501 or minY~=minY0 or maxY~=maxY0 then same=false;print(('   %s: shaped radius %.4f, today %.4f; y %.4f..%.4f / %.4f..%.4f'):format(d.Key,r,r0,minY,maxY,minY0,maxY0))end
  worst=math.max(worst,r/r0)
 end end
 check(holds,'Visuals.Bounds of every design (sizes 1 and 25; it reads the place\'s own template, unchanged) holds the shaped pouch to within 5%: radius, bottom, top')
 check(same,('the shaped pouch\'s radius is at most 5%% over today\'s (worst %.3f) and its bottom and top are exactly today\'s'):format(worst))
end

-- 4. Contexts -------------------------------------------------------------------------------------------------------------------------------------
local function contexts(stage,variant,key,label)
 fresh();Shapes.Config.Enabled=false;local off=sig(H.ground(stage,variant,1,'None'));Shapes.Config.Enabled=true;Shapes.Reset()
 Shapes.Request(key);local id=Shapes.Assign(key);local shapedTpl=Shapes.Template(key);local calls=Mock.calls
 local reference
 local function compare(bag,name,ignoreScale)
  local s=sig(bag);reference=reference or s
  local same,why=sameSig(s,reference);check(same,label..' '..name..': the same parts, sizes and positions as the ground pack'..(why and(' ('..why..')')or''))
  return s
 end
 for _,coat in ipairs({'None','Gold','Diamond'})do for _,size in ipairs({1,25})do
  local g=H.ground(stage,variant,size,coat);local s=compare(g,'ground '..size..'x '..coat)
  local pouch=g:FindFirstChild('ApprovedMesh01',true)
  local want=shapedTpl.ApprovedMesh01.Size
  check(pouch and near(pouch.Size.X/(g:GetAttribute('VisualScale')),want.X,1e-6)and near(pouch.Size.Z/(g:GetAttribute('VisualScale')),want.Z,1e-6),label..' ground '..size..'x '..coat..': the pouch is the SHAPED mesh ('..tostring(pouch and pouch.Size/g:GetAttribute('VisualScale'))..')')
  check(not sameSig(s,off)or id==0,label..': the shaped pack is not today\'s pack')
  -- the seal and strips are exactly today's
  local flush=true;for k,v in pairs(off)do if k:find('Seal')or k:find('TearStrip')then local x=s[k];if not x or(x.Pos-v.Pos).Magnitude>1e-9 or(x.Size-v.Size).Magnitude>1e-9 then flush=false end end end
  check(flush,label..' ground '..size..'x '..coat..': the seal and the 8 tear strips are exactly where today\'s are')
  local c=Rules.PackMutations[coat];if c.Color then local painted=true;for _,p in ipairs(H.partsOf(g,false))do if p.Color~=c.Color then painted=false end end;check(painted,label..' '..coat..': the coat paints the shaped pouch like any')end
  if size>10 then local tagged=0;for _,p in ipairs(H.partsOf(g,false))do if W.CS:HasTag(p,'GiantVisualPart')then tagged+=1 end end;check(tagged==#H.partsOf(g,false),label..': a giant: every part tagged GiantVisualPart')end
  g:Destroy()
 end end
 for _,rig in ipairs({'R15','R6'})do
  local held,char=H.held(stage,variant,1,'None',rig);compare(held,'held '..rig);held:Destroy();char:Destroy()
 end
 do local char=H.character('R15');local carry=Visuals.CarryBag(char,stage,variant,1,1,'None');compare(carry,'CarryBag');carry:Destroy();char:Destroy()end
 do local p=H.picture(stage,variant,1,'None');compare(p,'picture');local sp=H.sanitized(p);compare(sp,'sanitized picture');p:Destroy()end
 do local held,char=H.held(stage,variant,1,'None','R15');local copy=H.openingCopy(held);compare(copy,'opening copy');copy:Destroy();held:Destroy();char:Destroy()end
 do local m=H.market(stage,variant);compare(m,'market display');m:Destroy()end
 do local m,holder=H.mystery(stage,variant,false);local scale=m:GetAttribute('VisualScale');local want=shapedTpl.ApprovedMesh01.Size
  local pouch=m:FindFirstChild('ApprovedMesh01',true);check(pouch and near(pouch.Size.X/scale,want.X,1e-6),label..' mystery pedestal (x1.7): the shaped pouch');compare(m,'mystery pedestal');holder:Destroy()end
 do local b,vf=H.viewport(stage,variant,1,'None');compare(b,'viewport');b:Destroy()end
 check(Mock.calls==calls,label..': building every context baked nothing more ('..(Mock.calls-calls)..' extra)')
 check(Mock.alive==0,label..': no EditableMesh left alive')
end
contexts(4,'Pack03','Lava_03','Lava_03 (variation '..Shapes.Assign('Lava_03')..')')
contexts(1,'Pack02','Forest_02','Forest_02 (variation '..Shapes.Assign('Forest_02')..')')
-- the multi-mesh design (two MeshParts + Snow's 16): every part
do
 fresh();local key='Snow_06';Shapes.Request(key);local bag=H.ground(3,'Pack06',1,'None')
 local n=0;for _,p in ipairs(H.partsOf(bag,false))do if p:IsA('MeshPart')then n+=1 end end
 check(n==16 and bag:GetAttribute('PackArtKey')==key and bag:GetAttribute('VerityPack')==nil,'Snow_06 (16 MeshParts) builds all 16 shaped meshes')
 local shapedParts=0;for _,p in ipairs(Shapes.Template(key):GetChildren())do if p:IsA('MeshPart')and p:GetAttribute('Variation')==Shapes.Assign(key)then shapedParts+=1 end end
 check(shapedParts==16,'... each baked part says its variation ('..shapedParts..'/16)')
 bag:Destroy()
end
-- the special packs are never reshaped
do
 local function build(label,stage,variant,size)Shapes.Config.Enabled=true;fresh();Shapes.Config.Enabled=true;local on=H.ground(stage,variant,size,'None');local s1=sig(on);local c1=Mock.calls
  Shapes.Reset();Mock.reset();Shapes.Config.Enabled=false;local off=H.ground(stage,variant,size,'None');local s2=sig(off);Shapes.Config.Enabled=true
  check(sameSig(s1,s2)and c1==0,label..': the same with the variations on and off, and no mesh loaded ('..c1..' calls)');on:Destroy();off:Destroy()end
 for _,size in ipairs({1,25})do
  build('Void pack '..size..'x',1,H.VOID,size);build('Void pack (Storm) '..size..'x',7,H.VOID,size);build('Mech pack '..size..'x',8,H.MECH,size)
 end
 build('Verity sachet (no pouch baked)',7,H.VERITY,1)
 -- the Void's pouch is the place's own Forest_01 mesh
 fresh();local v=H.ground(1,H.VOID,1,'None');local m=v:FindFirstChild('ApprovedMesh01',true);check(m and m.MeshId==assets.Forest_01.ApprovedMesh01.MeshId,'the Void pack\'s pouch is the place\'s own Forest_01 mesh (MeshId '..tostring(m and m.MeshId)..')');v:Destroy()
end

-- 5. Fallbacks ------------------------------------------------------------------------------------------------------------------------------------
local function fallback(label,key,stage,variant,setup,reasonPart)
 fresh();local today=todays(stage,variant,1,'None');fresh();local restore=setup and setup()
 local w0=warns()
 local bag=H.ground(stage,variant,1,'None');local f=folder()
 local same,why=sameSig(sig(bag),today)
 check(same,label..': the pack is today\'s, exactly'..(why and(' ('..why..')')or''))
 check(Shapes.State(key)=='Off'and Shapes.Template(key)==nil and reasonOf(key):find(reasonPart,1,true)~=nil,label..': State is Off and the reason names it ('..reasonOf(key)..')')
 check(Mock.alive==0 and Mock.bakedAlive==0,label..': nothing left over ('..Mock.alive..' EditableMesh, '..Mock.bakedAlive..' MeshPart)')
 check(warns()==w0+1,label..': exactly one warning ('..(warns()-w0)..')')
 check(f:GetAttribute('FailureCount')==1 and f:GetAttribute('Ready')==false and tostring(f:GetAttribute('LastFailure')):find(key,1,true)~=nil,label..': the status folder says FailureCount 1, not Ready, and which design ('..tostring(f:GetAttribute('LastFailure'))..')')
 local calls=Mock.calls;local again=H.ground(stage,variant,1,'None');check(Mock.calls==calls and warns()==w0+1,label..': a second pack does not try again, no second warning');again:Destroy()
 bag:Destroy()
 if restore then restore()end
end
fallback('denied (no permission on the asset)','Forest_02',1,'Pack02',function()Mock.mode='denied'end,'no permission')
fallback('a mesh with no vertices','Forest_02',1,'Pack02',function()Mock.mode='no_vertices'end,'no vertices')
fallback('GetPosition / SetPosition missing','Forest_02',1,'Pack02',function()Mock.mode='no_positions'end,'not available')
fallback('the bake does not succeed','Forest_02',1,'Pack02',function()Mock.mode='content_fails'end,'could not bake')
fallback('CreateMeshPartAsync fails','Forest_02',1,'Pack02',function()Mock.mode='meshpart_fails'end,'out of mesh memory')
fallback('another mesh size','Forest_02',1,'Pack02',function()Mock.mode='size_mismatch'end,'not the reshaped mesh')
fallback('too many vertices','Forest_02',1,'Pack02',function()Mock.vertices=Shapes.Config.MaxVertices+1 end,'vertices')
fallback('the memory cap','Forest_02',1,'Pack02',function()local old=Shapes.Config.MaxTotalVertices;Shapes.Config.MaxTotalVertices=1000;return function()Shapes.Config.MaxTotalVertices=old end end,'memory cap')
do -- (a design with no template has no pack to build either: checked at the module)
 fresh();local m=assets.Forest_02;m.Name='Forest_02_gone';Shapes.Request('Forest_02');m.Name='Forest_02'
 check(Shapes.State('Forest_02')=='Off'and reasonOf('Forest_02'):find('not in SeedPackMeshAssets',1,true)~=nil and Mock.created==0,'the template is not in the place: that design keeps today\'s mesh (nothing to reshape), nothing loaded')
end
fallback('the second mesh of a design fails (the first is destroyed)','Lava_02',4,'Pack02',function()Mock.mode='second_fails' end,'second mesh')
do -- an incomplete template and a template with no PackLocalFrame
 fresh();local m=assets.Forest_02;m:SetAttribute('MeshCount',2);Shapes.Request('Forest_02')
 check(Shapes.State('Forest_02')=='Off'and reasonOf('Forest_02'):find('not a complete',1,true)~=nil and Mock.created==0,'an incomplete template (MeshCount 2, one mesh): that design keeps today\'s mesh, nothing is loaded')
 m:SetAttribute('MeshCount',1)
 fresh();local p=assets.Forest_02.ApprovedMesh01;local frame=p:GetAttribute('PackLocalFrame');p:SetAttribute('PackLocalFrame',nil);Shapes.Request('Forest_02')
 check(Shapes.State('Forest_02')=='Off'and Mock.alive==0 and Mock.bakedAlive==0,'a mesh with no PackLocalFrame: today\'s mesh, nothing leaked');p:SetAttribute('PackLocalFrame',frame)
end
do -- one design failing does not stop the others
 fresh();Mock.mode='denied';Shapes.Request('Forest_02');Mock.mode='ok';Shapes.Request('Forest_03')
 check(Shapes.State('Forest_02')=='Off'and Shapes.State('Forest_03')=='Ready','a failed design does not stop the next one: Forest_02 Off, Forest_03 Ready')
 local f=folder();check(f:GetAttribute('FailureCount')==1 and f:GetAttribute('BakedCount')==1 and f:GetAttribute('Ready')==false,'status: 1 failure, 1 baked, not Ready')
end
do -- a bake that never returns: given up on after LoadingSeconds, the queue goes on
 fresh();Mock.mode='hang';local w0=warns();Shapes.Request('Forest_02');Shapes.Request('Forest_03')
 check(Shapes.State('Forest_02')=='Loading'and Shapes.State('Forest_03')=='Loading','a bake that never returns stays Loading (and the next design waits behind it)')
 R.advance(Shapes.Config.LoadingSeconds+1)
 check(Shapes.State('Forest_02')=='Off'and reasonOf('Forest_02'):find('did not finish',1,true)~=nil,'after '..Shapes.Config.LoadingSeconds..' s it is given up on: Off, "did not finish"')
 Mock.mode='ok';check(Shapes.State('Forest_03')=='Off','(the design queued behind it timed out too: it was asked at the same time)')
 Shapes.Request('Forest_04');check(Shapes.State('Forest_04')=='Ready','the queue is not blocked: the next design bakes ('..Shapes.State('Forest_04')..')')
 check(warns()==w0+1 or warns()==w0+2,'the timeouts warn once per session')
end

-- 6. Switches -------------------------------------------------------------------------------------------------------------------------------------
do
 fresh();Shapes.Config.Enabled=false
 local b=H.ground(1,'Pack02',1,'None');check(Mock.calls==0 and Shapes.State('Forest_02')=='Off'and Shapes.Mode()=='off','Config.Enabled = false: no mesh is loaded, every design keeps today\'s mesh, Mode off')
 b:Destroy();Shapes.Config.Enabled=true
 check(Shapes.Mode()=='auto','Config.Enabled = true: Mode auto')
 Shapes.Config.Force=3;check(Shapes.Mode()==3 and Shapes.VariationOf('Forest_02')==3 and Shapes.VariationOf('Storm_06')==3,'Config.Force = 3: every design takes variation 3');Shapes.Config.Force=nil
 Shapes.Config.Force=9;check(Shapes.Mode()=='auto','a Force outside 1-6 is ignored');Shapes.Config.Force=nil
 -- the owner's attributes
 local sigToday=todays(1,'Pack02',1,'None');fresh();server();local fired=0;local off=Shapes.OnChanged(function()fired+=1 end)
 check(Shapes.SetMode(3)==3 and folder():GetAttribute('Force')==3 and folder():GetAttribute('Off')==nil and Shapes.Mode()==3 and fired==1,'SetMode(3): the status folder says Force 3 (replicated to clients), Mode 3, the listeners were told once')
 Shapes.Request('Forest_02');local m=Shapes.Template('Forest_02')
 check(m and m:GetAttribute('PackShape')==3,'a forced variation is baked for any design (Forest_02 is variation 3 now, not '..Shapes.Assign('Forest_02')..')')
 local bag=H.ground(1,'Pack02',1,'None');local forced=sig(bag);bag:Destroy()
 Shapes.SetMode(5);check(fired==2 and Shapes.State('Forest_02')=='Idle'and m.Parent==nil and Mock.bakedAlive==Mock.baked-1,'SetMode(5): the variation-3 template is dropped (memory), the design is asked for again; listeners told')
 Shapes.Request('Forest_02');local bag5=H.ground(1,'Pack02',1,'None');check(not sameSig(sig(bag5),forced)and Shapes.Template('Forest_02'):GetAttribute('PackShape')==5,'variation 5 is a different shape from 3');bag5:Destroy()
 check(Shapes.SetMode('off')=='off'and folder():GetAttribute('Off')==true and folder():GetAttribute('Force')==nil and Shapes.State('Forest_02')=='Off'and fired==3,'SetMode(off): the status folder says Off, every design keeps today\'s mesh, listeners told')
 local calls=Mock.calls;local bagOff=H.ground(1,'Pack02',1,'None');check(sameSig(sig(bagOff),sigToday)and Mock.calls==calls,'... and a pack built now is today\'s pack, nothing loaded');bagOff:Destroy()
 check(Shapes.SetMode('auto')=='auto'and folder():GetAttribute('Off')==nil and folder():GetAttribute('Force')==nil and fired==4,'SetMode(auto): back to normal (a design its own variation)')
 check(Shapes.SetMode('on')=='auto','"on" is auto too')
 local ok1=pcall(Shapes.SetMode,7);local ok2=pcall(Shapes.SetMode,0);local ok3=pcall(Shapes.SetMode,'purple');local ok4=pcall(Shapes.SetMode,2.5)
 check(not ok1 and not ok2 and not ok3 and not ok4 and Shapes.Mode()=='auto','7, 0, 2.5 and "purple" are refused, the mode stays')
 client();local okc=pcall(Shapes.SetMode,3);check(not okc,'SetMode is a server call: a client is refused');server()
 off()
 -- a mode change in the same mode does not notify
 local n=0;local off2=Shapes.OnChanged(function()n+=1 end);Shapes.SetMode('auto');Shapes.SetMode('auto');check(n==0,'setting the mode it already has notifies nobody');off2()
 -- failures are forgotten when the mode changes (the owner fixed the permission)
 fresh();Mock.mode='denied';Shapes.Request('Forest_02');check(Shapes.State('Forest_02')=='Off','(denied)');Mock.mode='ok';Shapes.SetMode(2);Shapes.SetMode('auto')
 check(Shapes.State('Forest_02')=='Idle'and folder():GetAttribute('FailureCount')==0,'a mode change forgets old failures: the design may be tried again')
 Shapes.Request('Forest_02');check(Shapes.State('Forest_02')=='Ready','... and bakes')
end
do -- the owner's /test packshape command
 fresh()
 local X=W.module('PackShapeCommand151')
 local function run(...)return X.Execute({},{Name='Owner'},{...})end
 local ok,text=run();check(ok==true and text:find('on: each design',1,true)and text:find('Pillow',1,true),'/test packshape: the status ('..tostring(text):sub(1,60)..'...)')
 local rows=0;for _,biome in ipairs({'Forest','Desert','Snow','Lava','Crystal','Jungle','Storm'})do if text:find(biome..': %d %d %d %d %d %d')then rows+=1 end end
 check(rows==7,'... with the 6 variations of each of the 7 biomes ('..rows..' rows)')
 local ok3,t3=run('3');check(ok3 and t3:find('forced to variation 3 (Top-heavy)',1,true)==nil and t3:find('forced to variation 3',1,true)and Shapes.Mode()==3,'/test packshape 3: forced ('..tostring(t3):sub(1,50)..')')
 local okOff,tOff=run('off');check(okOff and tOff:find('OFF',1,true)and Shapes.Mode()=='off','/test packshape off')
 local okA,tA=run('auto');check(okA and Shapes.Mode()=='auto','/test packshape auto')
 local okU,tU=run('Auto');check(okU and Shapes.Mode()=='auto','(case does not matter)')
 for _,bad in ipairs({'0','7','2.5','purple','-1'})do local okB,tB=run(bad);check(okB==false and tB:find('Use packshape',1,true)and Shapes.Mode()=='auto','/test packshape '..bad..' is refused with the usage')end
 local okM,tM=run('1','2');check(okM==false,'two arguments are refused')
 local m1=X.Execute({},{Name='Owner'},{'2'});check(Shapes.Mode()==2,'(mode 2)');Shapes.SetMode('auto')
end

-- 7. Waiting --------------------------------------------------------------------------------------------------------------------------------------
do
 local realWait=R.task.wait
 local function pump()R.task.wait=function(t)Mock.resume();R.advance(t or .03);return t or .03 end end
 -- a SERVER building a pack waits for the design's first bake, so every pack of the design is the same shape
 fresh();Mock.slow=true;server();pump()
 local built
 local co=coroutine.create(function()built=H.ground(1,'Pack02',1,'None')end)
 local okc,err=coroutine.resume(co);if not okc then print('ERR',err)end
 check(built~=nil and coroutine.status(co)=='dead','a server pack build waits for the bake and finishes ('..tostring(err)..')')
 local sz=pouchSize(built);local want=assets.Forest_02.ApprovedMesh01.Size
 local shapedSize=Shapes.Template('Forest_02')and Shapes.Template('Forest_02').ApprovedMesh01.Size
 check(built~=nil and Shapes.State('Forest_02')=='Ready'and sz~=nil and shapedSize~=nil and near(sz.Z,shapedSize.Z,1e-6)and not near(sz.Z,want.Z,1e-6),'... and the pack is the shaped one (depth '..tostring(sz and sz.Z)..' vs today '..tostring(want.Z)..')')
 check(built and built:FindFirstChild('ApprovedMesh01',true).MeshId=='','... built from the baked mesh, not the template\'s MeshId')
 if built then built:Destroy()end
 -- two designs asked at once, truly interleaved (the builders yield whenever they wait, the downloads finish one at a time): one EditableMesh alive at a time, in the order asked
 fresh();Mock.slow=true;local builders={}
 R.task.wait=function(t)if builders[coroutine.running()]then coroutine.yield()end;return t or .03 end -- (only a pack builder yields at a wait; the bake's own periodic wait just goes on)
 local order={};local a,b
 local c1=coroutine.create(function()a=H.ground(1,'Pack02',1,'None');order[#order+1]='Forest_02'end)
 local c2=coroutine.create(function()b=H.ground(1,'Pack03',1,'None');order[#order+1]='Forest_03'end)
 builders[c1]=true;builders[c2]=true
 for _=1,300 do
  if coroutine.status(c1)=='suspended'then local ok,e=coroutine.resume(c1);if not ok then print('ERR c1',e)end end
  if coroutine.status(c2)=='suspended'then local ok,e=coroutine.resume(c2);if not ok then print('ERR c2',e)end end
  Mock.resume();R.advance(.03)
  if coroutine.status(c1)=='dead'and coroutine.status(c2)=='dead'then break end
 end
 check(a~=nil and b~=nil and Mock.created==2 and Mock.alive==0,('two designs asked at the same time: both built, nothing left alive (created %d, alive %d)'):format(Mock.created,Mock.alive))
 check(Mock.maxAlive==1,('... one EditableMesh alive at a time (most %d)'):format(Mock.maxAlive))
 check(order[1]=='Forest_02'and order[2]=='Forest_03','... in the order they were asked ('..table.concat(order,', ')..')')
 if a then a:Destroy()end;if b then b:Destroy()end
 pump()
 -- a bake that never returns: the server gives up waiting after WaitSeconds and builds today's pack
 local sigToday=todays(1,'Pack02',1,'None');local sigToday3=todays(1,'Pack03',1,'None');fresh();Mock.mode='hang';pump();local t0=R.clock;local late
 local c3=coroutine.create(function()late=H.ground(1,'Pack02',1,'None')end);coroutine.resume(c3)
 local waited=R.clock-t0
 check(late~=nil and sameSig(sig(late),sigToday)and waited>=Shapes.Config.WaitSeconds-.1 and waited<=Shapes.Config.WaitSeconds+1,('a bake that never returns: the server waited %.0f s (the limit is %d) and built today\'s pack'):format(waited,Shapes.Config.WaitSeconds))
 check(Shapes.State('Forest_02')=='Loading','(the design is still Loading: a later pack of it would be shaped once the bake finishes)')
 if late then late:Destroy()end
 -- ... and the packs after it do not each wait that long behind the stuck bake: nothing is waited for while the same bake is current
 local t3=R.clock;local after;local c4=coroutine.create(function()after=H.ground(1,'Pack03',1,'None')end);coroutine.resume(c4)
 check(after~=nil and R.clock==t3 and sameSig(sig(after),sigToday3),'a stuck bake does not stall every later pack: the next design\'s pack was built at once ('..string.format('%.1f',R.clock-t3)..' s), today\'s')
 if after then after:Destroy()end
 R.task.wait=realWait
 -- a CLIENT never waits: today's pack at once, and the bake goes on
 fresh();Mock.slow=true;client();R.task.wait=function(t)R.advance(t or .03);return t or .03 end -- (a client that waited would show in the clock)
 local t1=R.clock;local cb=H.ground(1,'Pack02',1,'None');local t2=R.clock
 check(t1==t2 and Shapes.State('Forest_02')=='Loading','a client building a pack does not wait: no time passed, the bake is running ('..Shapes.State('Forest_02')..')')
 check(cb:FindFirstChild('ApprovedMesh01',true).MeshId==assets.Forest_02.ApprovedMesh01.MeshId,'... the pack is built from the place\'s own mesh meanwhile')
 while Mock.resume()do end
 check(Shapes.State('Forest_02')=='Ready','the bake finishes by itself ('..Shapes.State('Forest_02')..')')
 cb:Destroy()
 R.task.wait=realWait
 server()
end

-- 8. Pictures (the real ItemPictures) -------------------------------------------------------------------------------------------------------------
do
 fresh();client();Mock.slow=true
 local Pic=W.module('ItemPictures')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=H.pg
 local function holder(x)local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(x,0);return h end
 local function view(h)return h:FindFirstChild('ItemViewport')end
 local function meshOf(v)for _,d in ipairs(v:GetDescendants())do if d:IsA('MeshPart')then return d end end end
 local scale=Rules.GetVariant('Pack02').BagScale*Rules.GetTheme(1).Scale
 local tool=F.pack(W,W.workspace,1,'Pack02',1,'None','Forest Pack');local h1=holder(0)
 Pic.Show(h1,tool,1);for _=1,150 do W.frames(1)end
 check(view(h1)==nil and Shapes.State('Forest_02')=='Loading','(a) while the client\'s bake runs the picture waits ("still loading", retried): no picture, and nothing is cached in the meantime')
 while Mock.resume()do end
 check(Shapes.State('Forest_02')=='Ready','(b) the bake finishes')
 for _=1,300 do W.frames(1)end
 local v=view(h1)
 if check(v~=nil,'(b) ... and the picture draws on its own retry')then
  local m=meshOf(v);local want=Shapes.Template('Forest_02').ApprovedMesh01.Size
  check(m and near(m.Size.X,want.X*scale,1e-6)and near(m.Size.Z,want.Z*scale,1e-6)and m.MeshId=='','(b) the hotbar / Bag / Index picture is the SHAPED pouch (a baked MeshPart of the shaped Size '..tostring(m and m.Size)..')')
 end
 -- an unrelated pack (the Void) draws at once, with no bake
 local calls=Mock.calls;local voidTool=F.pack(W,W.workspace,1,H.VOID,1,'None','Void Pack');local hv=holder(70);Pic.Show(hv,voidTool,1);for _=1,100 do W.frames(1)end
 check(view(hv)~=nil and Mock.calls==calls,'(c) a Void pack picture needs no bake and draws at once')
 -- a Gold picture of the same design: gold, same shape
 local goldTool=F.pack(W,W.workspace,1,'Pack02',1,'Gold','Gold Forest Pack');local hg=holder(140);Pic.Show(hg,goldTool,1);for _=1,100 do W.frames(1)end
 local gv=view(hg);local gm=gv and meshOf(gv)
 check(gm and near(gm.Size.X,Shapes.Template('Forest_02').ApprovedMesh01.Size.X*scale,1e-6)and gm.Color==Rules.PackMutations.Gold.Color,'(d) a Gold picture: the same shaped pouch, gold')
 -- (e) a failed bake: the picture is today's pouch
 fresh();Mock.mode='denied';client()
 local h5=holder(210);local tool3=F.pack(W,W.workspace,1,'Pack03',1,'None','Forest Pack 3');Pic.Show(h5,tool3,1);for _=1,400 do W.frames(1)end
 local v5=view(h5);local m5=v5 and meshOf(v5)
 check(m5 and m5.MeshId==assets.Forest_03.ApprovedMesh01.MeshId,'(e) after a failed bake the picture is today\'s pouch (the place\'s own mesh)')
 -- (f) a mode change redraws every picture (Forest_02 is variation 2, Hourglass: forced to 1, Pillow, its depth changes)
 fresh();Mock.reset();client();Pic.Reset()
 local h6=holder(280);Pic.Show(h6,tool,1);for _=1,300 do W.frames(1)end
 local first=view(h6)and meshOf(view(h6));local firstSize=first and first.Size
 server();Shapes.SetMode(1);client()
 for _=1,400 do W.frames(1)end
 local second=view(h6)and meshOf(view(h6))
 local want=Shapes.Template('Forest_02')
 check(first~=nil and second~=nil and second~=first and want and want:GetAttribute('PackShape')==1 and not near(second.Size.Z,firstSize.Z,1e-6)and near(second.Size.Z,want.ApprovedMesh01.Size.Z*scale,1e-6),'(f) /test packshape 1: every picture is drawn again, from the new variation (depth '..tostring(firstSize and firstSize.Z)..' -> '..tostring(second and second.Size.Z)..')')
 server();Shapes.SetMode('auto');Pic.Reset();gui:Destroy()
 Mock.slow=false
end

-- 9. Verity ---------------------------------------------------------------------------------------------------------------------------------------
do
 fresh();server()
 local Pouch=W.module('VerityPouch151');local KEY='Storm_02'
 local function vfolder()return W.RS:FindFirstChild(Pouch.Folder)end
 local function dropV()local f=vfolder();if f then f:Destroy()end end
 dropV();Pouch.Prepare()
 local id=Shapes.Assign(KEY)
 -- the plain Storm_02 pack for comparison
 Shapes.Request(KEY);local plainTpl=Shapes.Template(KEY);local f=vfolder();local neutral=f:FindFirstChild(KEY)
 check(f:GetAttribute('Ready')==true and neutral and neutral:GetAttribute('PackShape')==id and f:GetAttribute('PackShape')==id and f:GetAttribute('ShapeFailure')==nil,'the Verity pouch carries Storm_02\'s variation ('..tostring(neutral and neutral:GetAttribute('PackShape'))..' = '..id..')')
 local vp,pp=neutral.ApprovedMesh01,plainTpl.ApprovedMesh01
 check(nearV(vp.Size,pp.Size,1e-9),'... the same Size as the plain Storm_02 pouch ('..tostring(vp.Size)..' / '..tostring(pp.Size)..')')
 -- the same vertices: the mock meshes of the Verity bake (first) and of the plain bake (second)
 local a,b=Mock.meshes[1],Mock.meshes[#Mock.meshes];local worst=0
 for i=1,#a._pos do worst=math.max(worst,(a._pos[i]-b._pos[i]).Magnitude)end
 check(#Mock.meshes==2 and worst<1e-9,'... moved the same vertices the same way (worst '..string.format('%.2g',worst)..')')
 local white=true;for _,c in ipairs(a._colors)do if not(c.R>.999 and c.G>.999 and c.B>.999)then white=false end end
 check(white and Mock.alive==0,'... with every vertex colour white, and nothing leaked')
 -- the Verity pack is the plain Storm_02 pack part for part
 local verity=H.ground(7,H.VERITY,1,'None');local plain=H.ground(7,'Standard',1,'None')
 local same,why=sameSig(sig(verity),sig(plain))
 check(verity:GetAttribute('VerityPouch')==true and same,'the Verity pack is the plain Storm_02 pack part for part, shaped like it'..(why and(' ('..why..')')or''))
 verity:Destroy();plain:Destroy()
 -- the variation cannot be applied: the neutral pouch is still baked, unshaped (and so is the plain Storm_02 pack: both fell back)
 dropV();fresh();Mock.mode='no_positions';Pouch.Prepare()
 local f2=vfolder();local n2=f2:FindFirstChild(KEY)
 check(f2:GetAttribute('Ready')==true and n2 and n2:GetAttribute('PackShape')==0 and tostring(f2:GetAttribute('ShapeFailure')):find('not available',1,true)~=nil,'if the variation cannot be applied the Verity pouch is baked without it (PackShape 0, ShapeFailure: '..tostring(f2:GetAttribute('ShapeFailure'))..')')
 check(nearV(n2.ApprovedMesh01.Size,assets[KEY].ApprovedMesh01.Size,1e-9)and Mock.alive==0,'... exactly the template\'s Size, nothing leaked')
 -- a mode change re-bakes it
 dropV();fresh();Mock.reset();Pouch.Prepare();local before=vfolder():FindFirstChild(KEY):GetAttribute('PackShape')
 Shapes.SetMode(2)
 local f3=vfolder();local n3=f3:FindFirstChild(KEY)
 check(before==id and f3:GetAttribute('Ready')==true and n3 and n3:GetAttribute('PackShape')==2 and f3:GetAttribute('PackShape')==2,'/test packshape 2 re-bakes the Verity pouch with variation 2 (was '..tostring(before)..')')
 Shapes.SetMode('off');local n4=vfolder():FindFirstChild(KEY)
 check(n4 and n4:GetAttribute('PackShape')==0 and nearV(n4.ApprovedMesh01.Size,assets[KEY].ApprovedMesh01.Size,1e-9),'... and with the variations off, the template\'s own shape (PackShape 0)')
 Shapes.SetMode('auto')
 check(Mock.alive==0,'(no EditableMesh left alive)')
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
