--!nocheck
-- R151 pack-models audit (owner: "look into refining and loosing the packs that we currently have; ensure there aren't any dislocated parts; the
-- packs are all using the same mesh and shape and so on; make sure everything is connected for the packs"), on the Roblox mock with the REAL
-- SeedPackVisuals / SeedPackRenderer / SeedPackRules / EclipsePackArt / SpecialPackArt89 / VerityPackArt / ItemPictures / SeedPackRender /
-- GiantVisualSafety of this checkout and the REAL pack templates of the owner's place (pack_templates.luau: 42 designs, 115 MeshParts).
-- Every pack the game can build is built in every context (ground / dropped, held R15 + R6, hotbar / Bag picture, opening copy, market display, mystery
-- pedestal, title / mech viewport) at the sizes .5 .. 25, in all three coats, with every weather trait; then:
--   1. REGISTRY   every (stage, variant) resolves to a real template; every part of a template is a MeshPart with its PackLocalFrame
--   2. STRUCTURE  one root (VisualRoot, invisible), the part count the renderers wait for, no collision / touch / query on any part, every part where
--                 the builder says it is (PackLocalFrame = its real frame in the root's frame), no stray part
--   3. CONNECTION anchored packs: every part anchored; held packs: every part reaches the carrier's torso through WeldConstraint / Motor6D (no part
--                 anchored, none unwelded, no weld to a foreign part, a Motor6D's C0 reproduces the part's resting place), and the carried pack
--                 follows a 120-frame run / turn / jump of the torso with no part left behind (max deviation < 1e-6 stud)
--   4. WORLD MOTION  the REAL SeedPackRender hovers / turns / bobs the anchored packs for 120 frames: every part keeps its place on the root
--   5. CONTEXTS   the same parts at the same size and pivot in every context (ground = held = picture = opening copy = market = mystery (x1.7))
--   6. GIANT      every visible part of a giant (> 10x) is a GiantVisualPart, so the camera fade takes the whole pack, not the pouch alone
--   7. WEATHER    a weather trait changes no part of the pack
--   8. SPECIAL    the Void / Mech / Verity packs: their parts, welds, motors, tags
-- The geometry checks (floating parts, z-fighting) are check_packs.py on dump_packs.luau's scenes (run_packs.sh runs both).
local H=require('./pack_world');local W,R,F=H.W,H.R,H.F;local V3,CF=R.Vector3.new,R.CFrame.new
local Rules,Visuals=H.Rules,H.Visuals
local fails,checks=0,0;local typeof=R.typeof
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function inv(c)return c:Inverse()end
local function cfDelta(a,b)local d=(a.Position-b.Position).Magnitude;local r=0;for _,axis in ipairs({'RightVector','UpVector','LookVector'})do r=math.max(r,math.acos(math.clamp(a[axis]:Dot(b[axis]),-1,1)))end;return d,r end
local function name(stage,variant,size,coat)return string.format('stage %s %s %sx %s',tostring(stage),tostring(variant),tostring(size),tostring(coat))end
local function allParts(bag,includeRoot)return H.partsOf(bag,includeRoot)end
local TOL=1e-5
local QUICK=(pcall(require,'./quick_mode')) -- the mutation runs (run_packs.sh --mutations) put a quick_mode.luau next to the test: a reduced matrix (a few stages and sizes)
local contexts,builds=0,0
local failuresByKind=setmetatable({},{__index=function()return 0 end})
local function kind(k,ok,msg)if not check(ok,msg)then failuresByKind[k]+=1 end;return ok end

-- 1. Registry ------------------------------------------------------------------------------------------------------------------------------------
local folder=W.RS.SeedPackMeshAssets
local designs={}
for _,m in ipairs(folder:GetChildren())do designs[m.Name]=m end
local nDesigns=0;for _ in pairs(designs)do nDesigns+=1 end
check(nDesigns==42,'42 templates (7 biomes x 6 designs) in SeedPackMeshAssets: '..nDesigns)
local meshParts=0
for key,m in pairs(designs)do
 local n=0
 for _,p in ipairs(m:GetChildren())do
  n+=1;meshParts+=1
  check(p:IsA('MeshPart')and typeof(p:GetAttribute('PackLocalFrame'))=='CFrame'and p.MeshId~=''and p.TextureID=='','template '..key..'/'..p.Name..': a MeshPart with a MeshId, no TextureID and its PackLocalFrame')
 end
 check(n>0 and m:GetAttribute('MeshCount')==n and m:GetAttribute('MeshBakeVersion')==123 and m:FindFirstChild('ApprovedMesh01'),'template '..key..': MeshCount '..tostring(m:GetAttribute('MeshCount'))..' = '..n..', bake 123, a main pouch ApprovedMesh01')
end
check(meshParts==115,'115 template MeshParts: '..meshParts)
-- Every variant x stage the game can ask for resolves to a template (the Void / Mech packs name Forest_01 themselves).
H.ALL={}
for _,stage in ipairs(H.STAGES)do
 for _,v in ipairs(H.ORDINARY)do H.ALL[#H.ALL+1]={stage,v}end
 for _,v in ipairs(H.LEGACY)do H.ALL[#H.ALL+1]={stage,v}end
 H.ALL[#H.ALL+1]={stage,H.VOID};H.ALL[#H.ALL+1]={stage,H.VERITY}
end
H.ALL[#H.ALL+1]={8,H.MECH}
for _,e in ipairs(H.ALL)do
 local key=Rules.DesignKey(e[1],e[2])
 if e[1]<=7 then check(designs[key]~=nil,name(e[1],e[2])..': design key '..key..' has a template')end
end

-- 2 / 3. Structure and connection of every build --------------------------------------------------------------------------------------------------
local function structure(bag,label,ctx)
 local root=bag.PrimaryPart
 local ok=kind('structure',root~=nil and root.Name=='VisualRoot'and root.Transparency==1 and root:IsDescendantOf(bag),label..': one invisible VisualRoot is the PrimaryPart')
 if not root then return end
 local parts=allParts(bag,true);local scale=bag:GetAttribute('VisualScale')or 0
 kind('structure',scale>0 and bag:GetAttribute('CompactPackReady')==true and bag:GetAttribute('CompactPackPartCount')==#parts,label..': CompactPackReady and the part count the renderers wait for ('..tostring(bag:GetAttribute('CompactPackPartCount'))..' vs '..#parts..')')
 local bad={}
 for _,p in ipairs(parts)do
  if p.CanCollide or p.CanTouch or p.CanQuery or not p.Massless then bad[#bad+1]=p.Name end
 end
 kind('structure',#bad==0,label..': no part collides, touches, is queried, or has mass ('..table.concat(bad,',')..')')
 local stray={}
 for _,p in ipairs(parts)do local par=p.Parent;if not(par==bag or par.Name=='PackGeometry'and par.Parent==bag)then stray[#stray+1]=p.Name end end
 kind('structure',#stray==0,label..': every part is a child of the pack or of its PackGeometry folder ('..table.concat(stray,',')..')')
 -- PackLocalFrame is the part's rest frame in the root's frame (SeedPackRender / VoidPackFx / the Mech rig put it back with it)
 local off=0
 for _,p in ipairs(parts)do
  local f=p:GetAttribute('PackLocalFrame')
  if typeof(f)=='CFrame'then local d,r=cfDelta(inv(root.CFrame)*p.CFrame,f);off=math.max(off,d/scale,r*.1)end -- (rotation: the Mech panels' baked matrices are rounded to 10 digits, 1.4e-5 rad off orthonormal; 1e-4 rad allowed)
 end
 kind('structure',off<TOL,label..': every PackLocalFrame is the part\'s real frame in the root\'s (worst '..string.format('%.2g',off)..')')
 -- every part inside SeedPackVisuals.Bounds (the carry layout, the platform, the pickup point and the picture framing are computed from it)
 if ctx~='mystery'then
  local b=Visuals.Bounds(bag:GetAttribute('Stage'),bag:GetAttribute('BagVariant'),bag:GetAttribute('PackSize'));local worst=0
  for _,p in ipairs(allParts(bag,false))do
   local f=inv(root.CFrame)*p.CFrame;local h=p.Size*.5
   for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do
    local q=f*V3(h.X*x,h.Y*y,h.Z*z);local r=math.sqrt(q.X*q.X+q.Z*q.Z)
    worst=math.max(worst,r-b.Radius,q.Y-b.MaxY,b.MinY-q.Y,q.Z-b.MaxZ,b.MinZ-q.Z)
   end end end
  end
  kind('bounds',worst<=1e-3*math.max(1,scale),label..(': every part is inside SeedPackVisuals.Bounds (worst overshoot %.4f)'):format(worst))
 end
 local seal,strips=0,0
 for _,p in ipairs(bag:GetChildren())do if p.Name=='BottomSeal'then seal+=1 elseif p:GetAttribute('TearIndex')then strips+=1 end end
 kind('structure',seal==1 and strips==8,label..': the seal and the 8 tear strips are there')
end
-- connection of a built bag. carrier = the torso part when held, nil when the pack is a world / picture pack (anchored).
local function connection(bag,label,carrierTorso,char)
 local root=bag.PrimaryPart;local parts=allParts(bag,true)
 if carrierTorso then
  local loose,anchored={},{}
  local g=H.bind({bag},{carrierTorso})
  local _,seen=H.pose(g,carrierTorso,carrierTorso.CFrame)
  for _,p in ipairs(parts)do if p.Anchored then anchored[#anchored+1]=p.Name end;if not seen[p]then loose[#loose+1]=p.Name end end
  kind('anchored',#anchored==0,label..': no part of a held pack is anchored ('..table.concat(anchored,',')..')')
  kind('connection',#loose==0,label..': every part reaches the torso through its welds ('..#loose..' of '..#parts..' do not: '..table.concat(loose,',')..')')
  -- the whole pack stays ahead of the carry layout's body-clearance plane (PackCarryLayout: CarryBackZ, in the HumanoidRootPart's frame; -Z is forward)
  local hrpPart=char:FindFirstChild('HumanoidRootPart');local backZ=bag:GetAttribute('CarryBackZ');local nearest=-1e9
  for _,p in ipairs(allParts(bag,false))do
   local f=inv(hrpPart.CFrame)*p.CFrame;local h=p.Size*.5
   for _,x in ipairs({-1,1})do for _,y in ipairs({-1,1})do for _,z in ipairs({-1,1})do nearest=math.max(nearest,(f*V3(h.X*x,h.Y*y,h.Z*z)).Z)end end end
  end
  local scale=bag:GetAttribute('VisualScale')or 1
  kind('carry',type(backZ)=='number'and nearest<=backZ+1e-3*scale,label..(': every part is ahead of the body-clearance plane (nearest %.3f, plane %.3f)'):format(nearest,tonumber(backZ)or 0/0))
  -- joints: no weld to a part outside this pack + carrier; both ends exist
  local foreign={}
  for _,d in ipairs(bag:GetDescendants())do
   if d:IsA('WeldConstraint')or d:IsA('Motor6D')then
    local a,b=d.Part0,d.Part1
    if not a or not b or not(a:IsDescendantOf(char))or not(b:IsDescendantOf(char))or d.Enabled==false then foreign[#foreign+1]=d.Parent.Name end
   end
  end
  kind('connection',#foreign==0,label..': every joint joins two parts of this pack (or the torso) and is enabled ('..table.concat(foreign,',')..')')
  local worst=0
  for _,m in ipairs(g.motors)do local d,r=cfDelta(m.Rel,m.Actual);worst=math.max(worst,d,r)end
  kind('connection',worst<1e-4,label..': a Motor6D\'s C0 reproduces its part\'s resting place (worst '..string.format('%.2g',worst)..')')
  -- 120 frames of a run / turn / jump of the torso: no part is left behind
  local rootInit=root.CFrame;local maxDev,maxRot=0,0
  for k=1,120 do
   local at=H.path(k,120)
   local poses=H.pose(g,carrierTorso,at)
   -- the root's own frame follows the torso with the weld offset; every other part must keep its offset to the root
   local rootAt=poses[root]
   local d,r=H.deviation(g,root,poses,rootAt,parts)
   maxDev=math.max(maxDev,d);maxRot=math.max(maxRot,r)
  end
  kind('motion',maxDev<1e-6 and maxRot<1e-4,label..(': after 120 frames of running, turning and jumping no part is left behind (worst %.2g studs, %.2g rad)'):format(maxDev,maxRot))
 else
  local loose={}
  for _,p in ipairs(parts)do if not p.Anchored then loose[#loose+1]=p.Name end end
  kind('anchored',#loose==0,label..': every part of a world / picture pack is anchored ('..table.concat(loose,',')..')')
  local welds=0;for _,d in ipairs(bag:GetDescendants())do if d:IsA('WeldConstraint')or d:IsA('Motor6D')then welds+=1 end end
  kind('anchored',welds==0,label..': an anchored pack carries no joints ('..welds..')')
 end
end
-- the sizes of the full matrix (the geometry is a pure scale of the unit pack, so five sizes cover the range: tiny, standard, large, giant, largest)
local FULL_SIZES=QUICK and{1,25}or{.5,1,2.5,10,25}
local FULL_COATS=QUICK and{'None','Gold'}or H.COATS
for _,e in ipairs(H.ALL)do
 local stage,variant=e[1],e[2]
 if not QUICK or stage==1 or stage==4 or stage==7 or stage==8 then
 for _,size in ipairs(FULL_SIZES)do for _,coat in ipairs(FULL_COATS)do
  local label=name(stage,variant,size,coat)
  local ok,bag=pcall(H.ground,stage,variant,size,coat)
  if kind('build',ok and bag~=nil,label..' builds on the ground: '..tostring(bag))then
   builds+=1;contexts+=1
   structure(bag,'ground '..label);connection(bag,'ground '..label,nil,nil)
   bag:Destroy()
  end
  if stage==1 or stage==4 or stage==7 or stage==8 then -- held: both rig types for three biomes (the carry layout is the same code for all)
   for _,rig in ipairs({'R15','R6'})do
    local ok2,bag2,char,hrp,torso=pcall(H.held,stage,variant,size,coat,rig)
    if kind('build',ok2 and bag2~=nil,label..' builds held ('..rig..'): '..tostring(bag2))then
     builds+=1;contexts+=1
     structure(bag2,'held '..rig..' '..label);connection(bag2,'held '..rig..' '..label,torso,char)
     bag2:Destroy();char:Destroy()
    end
   end
  end
 end end
 end
end
print(('structure / connection: %d packs built on the ground and held, in %d (stage, variant) combinations x %d sizes x 3 coats'):format(builds,#H.ALL,#FULL_SIZES))

-- 4. World motion with the REAL SeedPackRender -----------------------------------------------------------------------------------------------------
do
 local moved={}
 function W.workspace.BulkMoveTo(_,list,frames)for i,p in ipairs(list)do p.CFrame=frames[i];moved[p]=true end end
 local cam=W.workspace.CurrentCamera;cam.CFrame=R.CFrame.lookAt(V3(0,12,-14),V3(8,10,2))
 local sc=R.new('LocalScript');sc.Name='SeedPackRender'
 local bags={}
 local list={{1,'Pack01'},{3,'Pack04'},{4,'Pack06'},{5,'Pack05'},{7,'Pack03'},{4,'Pack03'},{2,'Pack06'},{6,'Pack05'}}
 for i,e in ipairs(list)do
  local bag=Visuals.Bag(CF(i*2,10,2)*R.CFrame.Angles(0,.3*i,0),W.workspace,1,nil,e[1],e[2],1,i==3 and 10 or 1,'None');bags[#bags+1]=bag
 end
 local ok,err=pcall(W.load,'SeedPackRender',sc)
 if check(ok,'the real SeedPackRender loads on the mock: '..tostring(err))then
  local rest={}
  for _,bag in ipairs(bags)do local root=bag.PrimaryPart;rest[bag]={};for _,p in ipairs(allParts(bag,true))do rest[bag][p]=inv(root.CFrame)*p.CFrame end end
  local worst,worstRot,anyMoved=0,0,0
  for frame=1,120 do
   cam.CFrame=R.CFrame.lookAt(V3(math.sin(frame/20)*8,12,-14-frame*.05),V3(8,10,2))
   W.frames(1,1/30)
   for _,bag in ipairs(bags)do
    local root=bag.PrimaryPart
    for _,p in ipairs(allParts(bag,true))do
     local d,r=cfDelta(inv(root.CFrame)*p.CFrame,rest[bag][p]);worst=math.max(worst,d/(bag:GetAttribute('VisualScale')or 1));worstRot=math.max(worstRot,r)
    end
   end
  end
  for _,bag in ipairs(bags)do if moved[bag.PrimaryPart]then anyMoved+=1 end end
  check(anyMoved>=#bags-1,'(the real SeedPackRender hovered '..anyMoved..' of '..#bags..' world packs)')
  kind('motion',worst<1e-4 and worstRot<1e-4,('world packs: after 120 frames of the real hover / turn / bob every part keeps its place on the root (worst %.2g pack units, %.2g rad)'):format(worst,worstRot))
 end
 sc.Destroying:Fire()
 for _,b in ipairs(bags)do b:Destroy()end
 function W.workspace.BulkMoveTo()end
end

-- 5. The same pack in every context ---------------------------------------------------------------------------------------------------------------
local function signature(bag)
 -- name -> {size, frame} in the root's frame divided by the pack's scale
 local root=bag.PrimaryPart;local scale=bag:GetAttribute('VisualScale')or 1;local out={}
 for _,p in ipairs(allParts(bag,false))do
  local f=inv(root.CFrame)*p.CFrame
  out[(p.Parent==bag and''or'PackGeometry/')..p.Name]={Size=p.Size/scale,Pos=f.Position/scale,Frame=f}
 end
 return out
end
local function sameSignature(a,b)
 local n=0;local worst=0;local why
 for k,x in pairs(a)do n+=1
  local y=b[k]
  if not y then return false,'missing '..k end
  worst=math.max(worst,(x.Size-y.Size).Magnitude,(x.Pos-y.Pos).Magnitude,select(2,cfDelta(x.Frame,y.Frame))*.1)
 end
 for k in pairs(b)do if not a[k]then return false,'extra '..k end end
 return worst<TOL,('worst %.2g'):format(worst),n
end
local CASES={{1,'Pack01'},{1,'Pack05'},{1,'Pack06'},{2,'Pack06'},{3,'Pack03'},{3,'Pack06'},{4,'Pack03'},{4,'Pack06'},{5,'Pack05'},{5,'Pack06'},{6,'Pack05'},{7,'Pack06'},{7,'Standard'},{7,H.VOID},{7,H.VERITY},{8,H.MECH}}
local ctxChecked=0
for _,e in ipairs(CASES)do for _,size in ipairs({1,2.5}) do
 local stage,variant=e[1],e[2];local label=name(stage,variant,size,'None')
 local ground=H.ground(stage,variant,size)
 local base=signature(ground)
 local held,char=H.held(stage,variant,size,'None')
 local pic=H.picture(stage,variant,size)
 local copy=H.openingCopy(held)
 local market=H.market(stage,variant)
 local ctx={held=held,picture=pic,['opening copy']=copy}
 for cname,bag in pairs(ctx)do
  local ok,why,n=sameSignature(base,signature(bag))
  kind('context',ok,label..': '..cname..' = the ground pack part for part ('..tostring(why)..')')
  kind('context',near(bag:GetAttribute('VisualScale'),ground:GetAttribute('VisualScale'),1e-9),label..': '..cname..' has the ground pack\'s VisualScale')
  ctxChecked+=1
 end
 -- the market pack is built at size 1: same parts, a different scale only
 if size==1 then local ok,why=sameSignature(base,signature(market));kind('context',ok,label..': market display = the ground pack part for part ('..why..')');ctxChecked+=1 end
 -- the picture after ItemPictures' sanitising: the visible parts are where they were, all anchored
 local before=signature(pic);local keepNames={};for _,p in ipairs(allParts(pic,false))do if p.Transparency<.95 then keepNames[#keepNames+1]=p end end
 local pos={};for _,p in ipairs(keepNames)do pos[p]=p.CFrame end
 H.sanitized(pic)
 local moved=0;for _,p in ipairs(keepNames)do if not p.Parent or not p.Anchored or(p.CFrame.Position-pos[p].Position).Magnitude>1e-9 then moved+=1 end end
 kind('context',moved==0,label..': the sanitised hotbar / Bag picture keeps every visible part in place and anchored ('..moved..' did not)')
 -- mystery: pack x 1.7, unlocked = the real design, locked = the plain design as a black silhouette with the same parts
 local extra={ground,held,pic,copy,market,char}
 if stage<=7 then -- (the mystery pedestal only ever shows the seven biomes' packs)
  local ready,holder=H.mystery(stage,variant,false);local locked,holder2=H.mystery(stage,variant,true)
  local ok,why=sameSignature(signature(ready),signature(H.ground(stage,variant,1)))
  -- (1.7 is the pedestal's scale parameter: VisualScale is 1.7x, the signature divides it out)
  kind('context',ok,label..': mystery pedestal pack (x1.7) = the ground pack part for part ('..tostring(why)..')');ctxChecked+=1
  local ok2,why2=sameSignature(signature(locked),signature(H.ground(stage,'Pack01',1)));kind('context',ok2,label..': the locked silhouette = the stage\'s Pack01 part for part ('..tostring(why2)..')');ctxChecked+=1
  table.insert(extra,ready);table.insert(extra,locked);table.insert(extra,holder);table.insert(extra,holder2)
 end
 for _,b in ipairs(extra)do pcall(function()b:Destroy()end)end
end end
print(('contexts: %d context / pack comparisons part by part'):format(ctxChecked))

-- 6. Giants ----------------------------------------------------------------------------------------------------------------------------------------
do
 local tagged=0;local total=0
 for _,e in ipairs(H.ALL)do
  for _,size in ipairs({5,10,15,25})do
   local bag=H.ground(e[1],e[2],size,'None')
   local giant=size>10;local missing={}
   for _,p in ipairs(allParts(bag,false))do
    local has=W.CS:HasTag(p,'GiantVisualPart')
    if giant and p.Transparency<1 and not has then missing[#missing+1]=p.Name end
    if not giant and has then missing[#missing+1]='(tagged but not giant) '..p.Name end
    if giant and has then tagged+=1 end;total+=1
   end
   kind('giant',#missing==0,('%s: %s (%d parts)'):format(name(e[1],e[2],size,'None'),giant and'every visible part of a giant pack is a GiantVisualPart'or'only giants carry the tag',#missing)..(#missing>0 and(' - '..table.concat(missing,','))or''))
   bag:Destroy()
  end
 end
 print(('giants: %d parts of packs >= 5x checked, %d tagged GiantVisualPart'):format(total,tagged))
end

-- 7. Weather -----------------------------------------------------------------------------------------------------------------------------------------
do
 local Weather=W.module('WeatherTraits');local FX=W.module('ItemEffectAnchor')
 local keys={'None','Drippy','Frosted','Charged','Drippy+Frosted','Drippy+Charged','Frosted+Charged','Drippy+Frosted+Charged'}
 local n=0
 for _,e in ipairs({{1,'Pack03'},{4,'Pack06'},{7,H.VOID},{7,H.VERITY},{8,H.MECH},{3,'Pack04'}})do
  local plain=H.ground(e[1],e[2],1,'None');local base=signature(plain)
  for _,key in ipairs(keys)do
   local bag=H.ground(e[1],e[2],1,'None');FX.Set(bag,key,nil,1,2)
   local ok,why=sameSignature(base,signature(bag))
   kind('weather',ok and bag.PrimaryPart:GetAttribute('WeatherTrait')==Weather.Key(key)and W.CS:HasTag(bag.PrimaryPart,'GardenItemFX'),name(e[1],e[2],1,'None')..' with weather '..key..': the same parts, the trait on the root ('..tostring(why)..')');n+=1
   bag:Destroy()
  end
  plain:Destroy()
 end
 print(('weather: %d weathered packs compared part by part'):format(n))
end

-- 8. The pad under a world pack (SeedPackVisuals.Platform: "on the ground / track pad") --------------------------------------------------------------
do
 local n=0
 for _,stage in ipairs(H.STAGES)do for _,variant in ipairs({'Pack01','Pack06',H.VOID})do for _,size in ipairs(QUICK and{1,25}or{.5,1,10,25})do
  local origin=CF(0,10,0)
  local d=Visuals.PlatformDimensions(stage,variant,size);local b=Visuals.Bounds(stage,variant,size)
  local pad=Visuals.Platform(origin,stage,variant,size);pad.Parent=W.workspace;n+=1
  local label=('pad stage %d %s %sx'):format(stage,variant,size)
  local parts=allParts(pad,true);local loose,joints={},0
  for _,p in ipairs(parts)do if not p.Anchored then loose[#loose+1]=p.Name end end
  for _,x in ipairs(pad:GetDescendants())do if x:IsA('WeldConstraint')or x:IsA('Motor6D')then joints+=1 end end
  kind('pad',#loose==0 and joints==0 and pad.PrimaryPart~=nil and pad.PrimaryPart.Name=='BiomeStone',label..': an anchored model on its BiomeStone ('..#parts..' parts, no joints)')
  kind('pad',d.Radius>=b.Radius-1e-9 and d.Radius>=.86,label..(': the pad (radius %.3f) reaches past the pack\'s footprint (%.3f)'):format(d.Radius,b.Radius))
  -- the pad's top is under the pack's lowest point with a hover gap
  local top=-1e9;for _,p in ipairs(parts)do if p.Name=='BiomeStone'or p.Name=='TopBevel'then top=math.max(top,p.Position.Y+(p.Name=='TopBevel'and p.Size.X/2 or p.Size.X/2))end end
  local packBottom=origin.Position.Y+b.MinY
  kind('pad',top<packBottom and packBottom-top<=.6+1e-6,label..(': the pack hovers %.3f over its pad (0 .. .6)'):format(packBottom-top))
  pad:Destroy()
 end end end
 print(('pads: %d pads checked (anchored, on the stone, under the pack)'):format(n))
end

-- 9. The special packs --------------------------------------------------------------------------------------------------------------------------
do
 local Void=W.module('EclipsePackArt');local Mech=W.module('SpecialPackArt89');local Verity=W.module('VerityPackArt')
 -- Void: every spin / pulse part keeps its PackLocalFrame and a pivot; the part budget; held = every part welded, and the spinning halo is welded too
 local specs=Void.Specs()
 kind('special',#specs<=Void.Budget.MaxParts,'Void: '..#specs..' design parts within the budget '..Void.Budget.MaxParts)
 local bag=H.ground(7,H.VOID,1,'None');local spinners=0;local bad=0
 for _,p in ipairs(allParts(bag,false))do
  if p:GetAttribute('VoidSpin')then spinners+=1;if typeof(p:GetAttribute('VoidPivot'))~='CFrame'or typeof(p:GetAttribute('PackLocalFrame'))~='CFrame'then bad+=1 end end
 end
 kind('special',spinners>=20 and bad==0,'Void: '..spinners..' spinning halo / debris parts, each with its pivot and rest frame ('..bad..' without)')
 -- the Void and the Mech pack use the standard pouch mesh (the Forest_01 template's main pouch), painted
 local forest=designs.Forest_01:FindFirstChild('ApprovedMesh01')
 for _,e in ipairs({{7,H.VOID},{8,H.MECH}})do
  local b=H.ground(e[1],e[2],1,'None');local body=b:FindFirstChild('ApprovedMesh01',true)
  kind('special',body~=nil and body.MeshId==forest.MeshId,name(e[1],e[2],1,'None')..': its body is the Forest_01 pouch mesh ('..tostring(body and body.MeshId)..')')
  b:Destroy()
 end
 bag:Destroy()
 local held,char,_,torso=H.held(7,H.VOID,1,'None');connection(held,'held Void',torso,char);held:Destroy();char:Destroy()
 -- Mech: every moving part of a held pack has its MechServo (Motor6D Part0 = root, C0 = rest, C1 = identity); a world pack has none
 local held2,char2,_,torso2=H.held(8,H.MECH,1,'None')
 local moving,servos,okServo=0,0,0
 for _,p in ipairs(allParts(held2,false))do
  if p:GetAttribute('MechMotion')then
   moving+=1;local j=p:FindFirstChild('MechServo')
   if j then servos+=1;if j:IsA('Motor6D')and j.Part0==held2.PrimaryPart and j.Part1==p then
    local d,r=cfDelta(j.C0,p:GetAttribute('PackLocalFrame'));local d1,r1=cfDelta(j.C1,R.CFrame.new(0,0,0));if d<1e-9 and r<1e-6 and d1<1e-9 and r1<1e-6 then okServo+=1 end
   end end
  end
 end
 kind('special',moving>=20 and servos==moving and okServo==moving,'Mech held: '..moving..' moving parts, '..servos..' MechServo motors, '..okServo..' with C0 = the rest frame')
 held2:Destroy();char2:Destroy()
 local world=H.ground(8,H.MECH,1,'None');local anyServo=false
 for _,d in ipairs(world:GetDescendants())do if d:IsA('Motor6D')then anyServo=true end end
 kind('special',not anyServo,'Mech on the ground: anchored, no servo motors')
 world:Destroy()
 -- Verity: the sachet is parts + two Decals on its face block; every part welded when held; the picture framing stays the plain pack's
 local vh,vc,_,vt=H.held(7,H.VERITY,1,'None');connection(vh,'held Verity',vt,vc)
 local meshes=0;for _,p in ipairs(allParts(vh,false))do if p:IsA('MeshPart')then meshes+=1 end end
 kind('special',meshes==0,'Verity: no MeshPart (the sachet is plain parts, see packs_audit.md)')
 vh:Destroy();vc:Destroy()
end

-- 10. The templates: which designs are the standard pouch ------------------------------------------------------------------------------------------
do
 -- the plain pack's seal sits at -1.12 and its tear strips at 1.11 (pack units): they are flush with a pouch that spans -1.04 .. 1.02
 local STD_BOTTOM,STD_TOP=-1.04,1.02
 local tall,lowBottom,wide={},{},{}
 for key,m in pairs(designs)do
  local body=m:FindFirstChild('ApprovedMesh01');local f=body:GetAttribute('PackLocalFrame')
  local top=f.Position.Y+body.Size.Y/2;local bottom=f.Position.Y-body.Size.Y/2
  if top>STD_TOP+.05 then tall[#tall+1]=key end
  if bottom<STD_BOTTOM-.03 then lowBottom[#lowBottom+1]=key end
  if body.Size.X>2.05 then wide[#wide+1]=key end
 end
 table.sort(tall);table.sort(lowBottom);table.sort(wide)
 print('designs whose pouch rises above the standard top (the tear strips sit inside it): '..table.concat(tall,' '))
 print('designs whose pouch reaches below the standard bottom (the seal overlaps it): '..table.concat(lowBottom,' '))
 print('designs wider than the standard pouch (> 2.05): '..table.concat(wide,' '))
 check(#tall==11 and #lowBottom==2 and #wide==5,'the templates are the 42 designs the audit was written for: 11 taller than the standard pouch, 2 lower, 5 wider (a new template needs a new look at packs_audit.md)')
end
print(('%d checks, %d failures'):format(checks,fails))
local kinds={};for k,v in pairs(failuresByKind)do kinds[#kinds+1]=k..'='..v end;table.sort(kinds)
if #kinds>0 then print('failures by kind: '..table.concat(kinds,', '))end
if fails>0 then error('FAILED')end
