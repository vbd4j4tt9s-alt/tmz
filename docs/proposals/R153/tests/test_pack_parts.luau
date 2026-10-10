--!nocheck
-- R153 (owner, on R152: "parts are dislocated on packs"; the yellow Verity pouch held edge-on, its seal and tear strips off to one side and the top one stepped):
-- every pack's SEAL (BottomSeal) and 8 TEAR STRIPS against the real crimps of its pouch, in every context and every shape, on the Roblox mock with the REAL
-- modules of this checkout, the REAL pack templates of the owner's place (R151 pack_templates.luau) and the REAL pouch geometry:
--  * a pouch MeshPart's mesh is an uploaded asset, but each was made from its design's native render data (src/ReplicatedStorage/SeedPackArt<Biome><NN>.lua,
--    the pack's frame at scale 1; check_pack_parts.py proves the union of a design's components has exactly its template's box). The pouch (BagBody)
--    closes at its crimp rows, y = 1.02 (top) and -1.04 (bottom); that is what the strips and the seal must sit on.
--  * a shaped pouch (PackShapes151) is baked on the mock from THOSE vertices (CreateEditableMeshAsync answers with the BagBody's vertices, in the
--    template part's mesh space, plus the corners of its box so the mesh keeps the template's size), so the REAL Deform moves the real crimp rows.
--  * the Verity pack's flat pouch is VerityPouch151's own Generate, baked on the R151 pouch mock (pouch_mock.luau); its crimp band is the last
--    CrimpHeight of each end. The R149 sachet's crimp is where its four slanted slabs meet.
-- Measured in the pouch part's own frame (pack units: divided by the pack's scale), for the top crimp against the strips and the bottom crimp against the seal:
--    centred  the strips / seal mid-plane on the crimp's mid-plane (|dz| <= .004) and centred across (|dx| <= .004)
--    touching the strips' bottom edge on the crimp's top, the seal's top edge on the crimp's bottom (no gap > .004; an overlap only for the sachet's slabs)
--    covered  no strip / seal end sticks out past the crimp's ends (<= .005)
-- Packs: the Verity pouch (ground .5x / 1x / 2.5x / 25x x None / Gold / Diamond, held R15 / R6, CarryBag, picture, ItemPictures' sanitised picture, opening copy,
-- market, mystery pedestal, viewport, a stale shape) and its sachet fallback; the 42 designs x the default and the 6 shapes (ground, held, picture, opening copy;
-- the market / mystery / Index pictures use the default or the roll as the game does); 25x giants; the legacy Small / Standard / Grand; the Void and the Mech.
-- Every failed check names its KIND (seam / crimp / sachet / special / context / shape-applied) so run_pack_parts.sh can tell the R152 bugs from new ones.
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0;local byKind={}
local function check(c,kind,msg)checks+=1;if not c then fails+=1;byKind[kind]=(byKind[kind]or 0)+1;if (byKind[kind]or 0)<=25 then print('FAIL ['..kind..']: '..msg)end end;return c end
local Run=W.Run
local function server()Run.IsServer=function()return true end;Run.IsClient=function()return false end end
local function client()Run.IsServer=function()return false end;Run.IsClient=function()return true end end
server()
local Shapes=W.module('PackShapes151');local Pouch=W.module('VerityPouch151');local Art=W.module('VerityPackArt')
local Visuals,Rules=H.Visuals,H.Rules
local VERITY=H.VERITY
local assets=W.RS.SeedPackMeshAssets
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do p.MeshSize=p.Size end end

-- The real pouch of every design ----------------------------------------------------------------------------------------------------------------
local BIOME_OF={Forest=1,Desert=2,Snow=3,Lava=4,Crystal=5,Jungle=6,Storm=7}
local function artOf(key) -- the design's native render components (pack frame, scale 1)
 local biome,nn=key:match('^(%a+)_(%d%d)$')
 local data=W.module('SeedPackArt'..biome..nn)
 local list=data[key];assert(list,'no native data for '..key)
 return list
end
local function verts(s)local out={};local nums={};for n in s:gmatch('[^,]+')do nums[#nums+1]=tonumber(n)end;for i=1,#nums,3 do out[#out+1]=V3(nums[i]/1e4,nums[i+1]/1e4,nums[i+2]/1e4)end;return out end
local function meshesOf(key)local l={};for _,p in ipairs(assets[key]:GetChildren())do if p:IsA('MeshPart')then l[#l+1]=p end end;table.sort(l,function(a,b)return a.Name<b.Name end);return l end
local pouches={}
-- pouch(key) = {Key, Body (BagBody vertices, pack frame), Top / Bottom (indices of its crimp rows), Holder (the template MeshPart that holds the pouch), Frame0, Size0}
local function pouch(key)
 if pouches[key]then return pouches[key]end
 local body
 for _,c in ipairs(artOf(key))do if c.Name=='BagBody'then body=verts(c.V)end end
 assert(body,'no BagBody in '..key)
 local lo,hi=V3(1e9,1e9,1e9),V3(-1e9,-1e9,-1e9)
 for _,v in ipairs(body)do lo=V3(math.min(lo.X,v.X),math.min(lo.Y,v.Y),math.min(lo.Z,v.Z));hi=V3(math.max(hi.X,v.X),math.max(hi.Y,v.Y),math.max(hi.Z,v.Z))end
 local top,bottom={},{}
 for i,v in ipairs(body)do if math.abs(v.Y-hi.Y)<1e-9 then top[#top+1]=i elseif math.abs(v.Y-lo.Y)<1e-9 then bottom[#bottom+1]=i end end
 -- the template MeshPart whose box holds the pouch (its body mesh; for one-mesh designs the only one)
 local holder
 for _,p in ipairs(meshesOf(key))do
  local f=p:GetAttribute('PackLocalFrame');local inside=true
  for _,v in ipairs({lo,hi})do local q=f:Inverse()*v;if math.abs(q.X)>p.Size.X/2+1e-4 or math.abs(q.Y)>p.Size.Y/2+1e-4 or math.abs(q.Z)>p.Size.Z/2+1e-4 then inside=false end end
  if inside and not holder then holder=p end
 end
 assert(holder,'no template part of '..key..' holds its pouch')
 local e={Key=key,Body=body,Top=top,Bottom=bottom,Holder=holder.Name,Frame0=holder:GetAttribute('PackLocalFrame'),Size0=holder.Size,MeshId=holder.MeshId}
 pouches[key]=e;return e
end
-- The mock asset route answers with the REAL pouch: the template part that holds the pouch gets the BagBody (in its mesh space) + its box corners; any other part its box.
local byUri={}
for _,model in ipairs(assets:GetChildren())do for _,p in ipairs(model:GetChildren())do if p:IsA('MeshPart')then byUri[p.MeshId]={Key=model.Name,Part=p}end end end
local AS=W.service('AssetService')
local realMeshes=0
local function corners(size)local out={};for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do out[#out+1]=V3(size.X*x,size.Y*y,size.Z*z)end end end;return out end
local function realMesh(_,content)
 local at=byUri[content and content.Uri];assert(at,'unknown mesh '..tostring(content and content.Uri))
 local pos={}
 local e=pouch(at.Key)
 if at.Part.Name==e.Holder then local back=e.Frame0:Inverse();for i,v in ipairs(e.Body)do pos[i]=back*v end end
 local n=#pos;for _,c in ipairs(corners(at.Part.Size))do pos[#pos+1]=c end
 realMeshes+=1
 local m={_pos=pos,_colors={},_dead=false,BodyCount=n,Key=at.Key,Part=at.Part.Name}
 function m:GetVertices()local v={};for i=1,#self._pos do v[i]=i end;return v end
 function m:GetPosition(i)return self._pos[i]end
 function m:SetPosition(i,v)self._pos[i]=v end
 function m:GetColors()return{}end
 function m:Destroy()self._dead=true end
 return m
end
local function installReal()AS.CreateEditableMeshAsync=realMesh end -- (pouch_mock's reset puts its lattice back: call this after it)

-- Measuring a built pack ----------------------------------------------------------------------------------------------------------------------------
local function named(model,name)for _,d in ipairs(model:GetDescendants())do if d.Name==name and d:IsA('BasePart')then return d end end end
local function boxIn(P,s,part) -- the 8 corners of a part's box in frame P, divided by s: lo, hi
 local lo,hi=V3(1e9,1e9,1e9),V3(-1e9,-1e9,-1e9);local inv=P:Inverse()
 for _,c in ipairs(corners(part.Size))do local q=(inv*(part.CFrame*c))/s;lo=V3(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=V3(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))end
 return lo,hi
end
local function rangeOf(list)local lo,hi=V3(1e9,1e9,1e9),V3(-1e9,-1e9,-1e9);for _,q in ipairs(list)do lo=V3(math.min(lo.X,q.X),math.min(lo.Y,q.Y),math.min(lo.Z,q.Z));hi=V3(math.max(hi.X,q.X),math.max(hi.Y,q.Y),math.max(hi.Z,q.Z))end;return lo,hi end
-- the crimps of a built pack in the pouch part's frame, pack units: {Top={lo,hi}, Bottom={lo,hi}, P, s, kind}
local function crimpsOf(model,key)
 local verityPouch=named(model,'ApprovedMesh01');local face=named(model,'VerityFace')
 if face then -- the R149 sachet: the crimp is where the slanted slabs meet
  local P=CF(face.CFrame.Position)*face.CFrame.Rotation;local s=face.Size.Z/(Art.Layout(key)[1].Size.Z)
  local out={P=P,s=s,Kind='sachet'}
  for _,end_ in ipairs({'Top','Bottom'})do
   local pts={}
   for _,side in ipairs({'Front','Back'})do local slab=named(model,'VerityTaper'..end_..side);local lo,hi=boxIn(P,s,slab);local inv=P:Inverse()
    for _,c in ipairs(corners(slab.Size))do pts[#pts+1]=(inv*(slab.CFrame*c))/s end end
   table.sort(pts,function(a,b)return(end_=='Top'and a.Y>b.Y)or(end_=='Bottom'and a.Y<b.Y)end)
   local tip={};for i=1,8 do tip[i]=pts[i]end -- the 4 outer corners of each slab's far end (the meeting edge)
   local lo,hi=rangeOf(tip);out[end_]={lo,hi}
  end
  return out
 end
 if model:GetAttribute('VerityPouch')or(verityPouch and verityPouch.Baked and verityPouch.Baked.Generated)then -- the generated flat pouch: the crimp band of each end
  local part=verityPouch;local m=part.Baked;local ms=part.MeshSize
  local s=part.Size.Y/ms.Y;local P=part.CFrame
  local lo0,hi0=rangeOf(m._pos);local mid=(lo0+hi0)/2
  local top,bot={},{}
  for _,v in ipairs(m._pos)do
   local q=V3((v.X-mid.X)*part.Size.X/ms.X,(v.Y-mid.Y)*part.Size.Y/ms.Y,(v.Z-mid.Z)*part.Size.Z/ms.Z)/s
   if v.Y-mid.Y>=ms.Y/2-Pouch.CrimpHeight-1e-9 then top[#top+1]=q elseif v.Y-mid.Y<=-(ms.Y/2-Pouch.CrimpHeight)+1e-9 then bot[#bot+1]=q end
  end
  local a,b=rangeOf(top);local c,d=rangeOf(bot)
  return{P=P,s=s,Kind='verity',Top={a,b},Bottom={c,d}}
 end
 -- a template pouch (a clone of the place's, or a shaped one baked from the real vertices)
 local e=pouch(key);local part=named(model,e.Holder);assert(part,'no pouch part '..e.Holder..' in '..key)
 local P=part.CFrame;local s;local pts={}
 if part.Baked then
  local m=part.Baked;local ms=part.MeshSize;s=part.Size.Y/ms.Y
  local lo0,hi0=rangeOf(m._pos);local mid=(lo0+hi0)/2
  local function at(i)local v=m._pos[i];return V3((v.X-mid.X)*part.Size.X/ms.X,(v.Y-mid.Y)*part.Size.Y/ms.Y,(v.Z-mid.Z)*part.Size.Z/ms.Z)/s end
  local top,bot={},{};for _,i in ipairs(e.Top)do top[#top+1]=at(i)end;for _,i in ipairs(e.Bottom)do bot[#bot+1]=at(i)end
  local a,b=rangeOf(top);local c,d=rangeOf(bot)
  return{P=P,s=s,Kind='shaped',Top={a,b},Bottom={c,d}}
 end
 s=part.Size.Y/e.Size0.Y;local back=e.Frame0:Inverse()
 local function at(i)local q=back*e.Body[i];return V3(q.X*part.Size.X/e.Size0.X,q.Y*part.Size.Y/e.Size0.Y,q.Z*part.Size.Z/e.Size0.Z)/s end
 local top,bot={},{};for _,i in ipairs(e.Top)do top[#top+1]=at(i)end;for _,i in ipairs(e.Bottom)do bot[#bot+1]=at(i)end
 local a,b=rangeOf(top);local c,d=rangeOf(bot)
 return{P=P,s=s,Kind='default',Top={a,b},Bottom={c,d}}
end
local TOL_Z,TOL_X,TOL_Y,TOL_OVER=.004,.004,.004,.005
local worst={dz=0,dx=0,gap=0,over=0}
local measured=0
-- the strips / seal against the crimps; `kind` names the failure family
local function measure(model,key,label,kind)
 measured+=1
 local c=crimpsOf(model,key);local P,s=c.P,c.s
 local strips={};for i=1,8 do local st=named(model,'TearStrip'..i);if st then local lo,hi=boxIn(P,s,st);strips[#strips+1]=lo;strips[#strips+1]=hi end end
 local seal=named(model,'BottomSeal')
 if not check(#strips==16 and seal~=nil,kind,label..': the pack has its seal and 8 tear strips')then return end
 local slo,shi=rangeOf(strips);local blo,bhi=boxIn(P,s,seal)
 local rows={{'top crimp / tear strips',c.Top,slo,shi,true},{'bottom crimp / seal',c.Bottom,blo,bhi,false}}
 for _,r in ipairs(rows)do
  local what,cr,lo,hi,top=r[1],r[2],r[3],r[4],r[5]
  local clo,chi=cr[1],cr[2]
  local dz=math.abs((clo.Z+chi.Z)/2-(lo.Z+hi.Z)/2)
  local dx=math.abs((clo.X+chi.X)/2-(lo.X+hi.X)/2)
  local gap=top and(lo.Y-chi.Y)or(clo.Y-hi.Y)              -- > 0: a gap between them; < 0: they overlap
  local over=math.max(0,clo.X-lo.X,hi.X-chi.X)                -- how far the strips / seal stick out past the crimp's ends
  worst.dz=math.max(worst.dz,dz);worst.dx=math.max(worst.dx,dx);worst.gap=math.max(worst.gap,gap);if c.Kind~="sachet"then worst.over=math.max(worst.over,over)end
  local overlapOk=c.Kind=='sachet'and gap>=-(hi.Y-lo.Y)-1e-6 or gap>=-TOL_Y
  check(dz<=TOL_Z and dx<=TOL_X,kind,('%s: %s centred (off by %.4f in depth, %.4f across)'):format(label,what,dz,dx))
  check(gap<=TOL_Y and overlapOk,kind,('%s: %s touching (gap %.4f)'):format(label,what,gap))
  if c.Kind~='sachet'then check(over<=TOL_OVER,kind,('%s: %s: nothing sticks out past the crimp\'s ends (%.4f)'):format(label,what,over))end -- (the sachet's slabs are narrower than the strips by design: R149, its rounded edges finish the corners)
 end
end

-- 1. The Verity pack --------------------------------------------------------------------------------------------------------------------------------
Shapes.Config.Enabled=false
local KEY='Storm_02';local tpl=assets[KEY].ApprovedMesh01
do
 local f=W.RS:FindFirstChild(Pouch.Folder);if f then f:Destroy()end
 -- the sachet first (no pouch baked): the R149 fallback
 local s=H.ground(7,VERITY,1,'None');check(s:FindFirstChild('VerityFace',true)~=nil,'context','(the Verity pack before the bake is the R149 sachet)')
 measure(s,KEY,'Verity sachet ground 1x','sachet');s:Destroy()
 local h,char=H.held(7,VERITY,1,'None','R15');measure(h,KEY,'Verity sachet held R15','sachet');h:Destroy();char:Destroy()
 local f2=W.RS:FindFirstChild(Pouch.Folder);if f2 then f2:Destroy()end
 Mock.reset();assert(Pouch.Prepare()==true,'the Verity pouch did not bake on the mock')
end
local function verity(model,label)
 local mesh=named(model,'ApprovedMesh01')
 check(mesh~=nil and mesh.Baked~=nil and mesh.Baked.Generated==true and(model:GetAttribute('VerityPouch')==true or model:IsA('ViewportFrame')),'context',label..': the Verity pack is the flat pouch')
 measure(model,KEY,'Verity '..label,'seam')
end
for _,size in ipairs({.5,1,2.5,25})do for _,coat in ipairs({'None','Gold','Diamond'})do
 local g=H.ground(7,VERITY,size,coat);verity(g,('ground %sx %s'):format(size,coat));g:Destroy()
end end
for _,rig in ipairs({'R15','R6'})do for _,size in ipairs({1,25})do
 local h,char=H.held(7,VERITY,size,'None',rig);verity(h,('held %s %sx'):format(rig,size))
 local copy=H.openingCopy(h);verity(copy,('opening copy (%s %sx)'):format(rig,size));copy:Destroy()
 h:Destroy();char:Destroy()
end end
do
 local char=H.character('R15');local carry=Visuals.CarryBag(char,7,VERITY,1,1,'None');verity(carry,'CarryBag');carry:Destroy();char:Destroy()
 local p=H.picture(7,VERITY,1,'None');verity(p,'picture');local sp=H.sanitized(H.picture(7,VERITY,1,'Gold'));verity(sp,'sanitised Gold picture (hotbar / Bag / Index)');p:Destroy()
 local m=H.market(7,VERITY);verity(m,'market');m:Destroy()
 local my,holder=H.mystery(7,VERITY,false);verity(my,'mystery pedestal (Ready)');holder:Destroy()
 local vp,vf=H.viewport(7,VERITY,1,'None');verity(vp,'viewport (title / dialog preview)');vf:Destroy()
 local stale=H.ground(7,VERITY,1,'None',nil,4);verity(stale,'a record that still says shape 4');stale:Destroy()
end
-- the real ItemPictures (hotbar, Bag, Index, the Verity dialog's card all draw through it): the ViewportFrame's own copy
do
 client()
 local Pic=W.module('ItemPictures')
 local gui=R.Instance.new('ScreenGui');gui.Name='Pictures';gui.Parent=H.pg
 local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(0,0)
 local tool=F.pack(W,W.workspace,7,VERITY,1,'None','Verity Pack')
 Pic.Show(h,tool,1);for _=1,300 do W.frames(1)end
 local v=h:FindFirstChild('ItemViewport')
 if check(v~=nil,'context','ItemPictures draws the Verity pack')then verity(v,'ItemPictures viewport')end
 server()
end

-- 2. Every ordinary design, every shape -------------------------------------------------------------------------------------------------------------
Shapes.Reset();Mock.reset();installReal();Shapes.Config.Enabled=true;Shapes.Config.Force=nil;Shapes.Config.MaxResidentVertices=10^7;Shapes.Config.HardResidentVertices=2*10^7
do local f=W.RS:FindFirstChild(Shapes.Folder);if f then f:SetAttribute('Off',nil);f:SetAttribute('Force',nil)end end
local DESIGNS={}
for stage=1,7 do for tier=1,6 do local v=string.format('Pack%02d',tier);DESIGNS[#DESIGNS+1]={Key=Rules.DesignKey(stage,v),Stage=stage,Variant=v}end end
local designsMeasured,tall=0,{}
for _,d in ipairs(DESIGNS)do
 local e=pouch(d.Key)
 for shape=0,6 do
  local sh=shape>0 and shape or nil
  local g=H.ground(d.Stage,d.Variant,1,'None',nil,sh)
  if sh then check(g:GetAttribute('PackShapeShown')==shape,'shape-applied',d.Key..' ground: shape '..shape..' is the one built ('..tostring(g:GetAttribute('PackShapeShown'))..')')end
  local lab=('%s %s'):format(d.Key,shape==0 and'default'or Shapes.Names[shape])
  measure(g,d.Key,lab..' ground','crimp');g:Destroy()
  local h,char=H.held(d.Stage,d.Variant,1,'None','R15',sh);measure(h,d.Key,lab..' held R15','crimp')
  local copy=H.openingCopy(h);measure(copy,d.Key,lab..' opening copy','crimp');copy:Destroy();h:Destroy();char:Destroy()
  local p=H.picture(d.Stage,d.Variant,1,'None',sh);measure(p,d.Key,lab..' picture','crimp');p:Destroy()
 end
 designsMeasured+=1
end
-- the other contexts once per design (market and Index pictures are the default; the mystery pedestal and a 25x giant show the roll; R6 hands)
for i,d in ipairs(DESIGNS)do
 local sh=(i%6)+1
 local m=H.market(d.Stage,d.Variant,sh);measure(m,d.Key,d.Key..' market (default)','crimp');m:Destroy()
 local my,holder=H.mystery(d.Stage,d.Variant,false,sh);measure(my,d.Key,d.Key..' mystery '..Shapes.Names[sh],'crimp');holder:Destroy()
 local gi=H.ground(d.Stage,d.Variant,25,'Gold',nil,sh);measure(gi,d.Key,d.Key..' 25x Gold '..Shapes.Names[sh],'crimp');gi:Destroy()
 local h,char=H.held(d.Stage,d.Variant,2.5,'Diamond','R6',sh);measure(h,d.Key,d.Key..' held R6 2.5x Diamond '..Shapes.Names[sh],'crimp');h:Destroy();char:Destroy()
 local vp,vf=H.viewport(d.Stage,d.Variant,1,'None',nil,sh);measure(vp,d.Key,d.Key..' viewport '..Shapes.Names[sh],'crimp');vf:Destroy()
end
-- the legacy variants (designs 1 / 2 / 3)
for _,v in ipairs(H.LEGACY)do for stage=1,7 do local g=H.ground(stage,v,1,'None');measure(g,g:GetAttribute('PackArtKey'),('legacy %s stage %d'):format(v,stage),'crimp');g:Destroy()end end
-- a shaped picture through the real ItemPictures (the hotbar / Bag picture of a pack that rolled a shape)
do
 client();local Pic=W.module('ItemPictures')
 local gui=H.pg:FindFirstChild('Pictures')
 for i,case in ipairs({{5,'Pack05',2},{4,'Pack03',1},{7,'Pack06',6}})do
  local key=Rules.DesignKey(case[1],case[2])
  local h=R.new('Frame');h.Size=R.UDim2.fromOffset(60,60);h.Parent=gui;h.AbsoluteSize=R.Vector2.new(60,60);h.AbsolutePosition=R.Vector2.new(80*i,0)
  local tool=F.pack(W,W.workspace,case[1],case[2],1,'None','Pack '..i);tool:SetAttribute('PackShape',case[3])
  Pic.Show(h,tool,1);for _=1,300 do W.frames(1)end
  local v=h:FindFirstChild('ItemViewport')
  if check(v~=nil,'context','ItemPictures draws '..key..' shape '..case[3])then measure(v,key,'ItemPictures '..key..' '..Shapes.Names[case[3]],'crimp')end
 end
 server()
end

-- 3. The Void and the Mech (the Forest_01 crimp rows: the Void's pouch; the Mech's flat pouch / sachet has the same footprint; never shaped) ------------------------------------------------------------------------------------------
for _,v in ipairs({{H.VOID,7},{H.MECH,8}})do
 local key='Forest_01'
 local g=H.ground(v[2],v[1],1,'None');measure(g,key,v[1]..' ground','special');g:Destroy()
 local h,char=H.held(v[2],v[1],1,'None','R15');measure(h,key,v[1]..' held R15','special')
 local copy=H.openingCopy(h);measure(copy,key,v[1]..' opening copy','special');copy:Destroy();h:Destroy();char:Destroy()
 local p=H.picture(v[2],v[1],1,'None',3);measure(p,key,v[1]..' picture','special');p:Destroy()
end

local kinds={};for k,n in pairs(byKind)do kinds[#kinds+1]=k..'='..n end;table.sort(kinds)
print(('pack parts: %d packs measured (%d designs x 7 shapes in 4 contexts, + 5 more contexts each, legacy, Verity pouch / sachet, Void, Mech); %d real meshes baked'):format(measured,designsMeasured,realMeshes))
print(('worst: depth %.4f, across %.4f, gap %.4f, sticking out %.4f'):format(worst.dz,worst.dx,worst.gap,worst.over))
print(('failures by kind: %s'):format(#kinds>0 and table.concat(kinds,' ')or'none'))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('pack parts: '..fails..' failures',0)end
