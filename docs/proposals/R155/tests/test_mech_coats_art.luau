--!nocheck
-- R155 Mech pack coats: the LOOK of a Gold and a Diamond Mech pack (owner: "We can implement 1C"; docs/proposals/R153/mech_pack.md section 2: "plus a gold / glass version of the pack art"),
-- on the Roblox mock with the REAL modules of this checkout and the REAL pack templates of the owner's place (R151 pack_world.luau; the server's flat pouch baked on the EditableMesh mock):
--  1. the treatment   a coated Mech pack gets exactly what a coated WORLD pack gets (SeedPackVisuals.Bag): the coat's colour, Metal / Glass, reflectance (.38 / .28), a Diamond's
--                     transparency (.20 on the pouch mesh, .10 on parts), no texture / appearance override left, PaperColor = the coat's colour
--  2. readable        the parts that make it a machine keep their own colour (MechCoatKeep): the cyan traces, the core, its facet and cyan ring, the MECH letters on their dark plate, the
--                     teal inset, the antenna's red LED and the black hazard stripes: the same colours and materials as the plain pack; every other part takes the coat; each lit part is a
--                     clear colour away from the coat (CIE76 distance), the hazard stripes stay black on the coated seal
--  3. every context   ground (1x / .5x / 25x), held R15 / R6, picture (Bag / hotbar / Index, default and plain shape), the shop's viewport, the opening copy, and the plain-parts body: the same
--                     treatment, the same kept parts, the same parts at the same places as the plain pack
--  4. hotbar          ItemPictures keys a Gold / Diamond Mech pack apart from a plain one (its own picture); the sanitised picture keeps every visible part and the kept colours
--  5. the rig         the pulse (traces / core), the LED's blink and Reset still work on a coated pack, in the coated colours; the held fx (hum light, antenna sparks) are as before
--  6. plain stays     a plain Mech pack is built exactly as before (no MechCoatKeep effect: the loop never runs)
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Art=W.module('MechPackArt153');local Shared=W.module('SpecialPackArt89');local Pouch=W.module('VerityPouch151');local Rules=W.module('SeedPackRules')
local MECH=H.MECH
local function server(on)W.Run.IsServer=function()return on end;W.Run.IsClient=function()return not on end end
local function dropFolder()local f=W.RS:FindFirstChild(Pouch.Folder);if f then f:Destroy()end end
local function bake()server(true);dropFolder();Mock.reset();local tpl=W.RS.SeedPackMeshAssets.Storm_02.ApprovedMesh01;tpl.MeshSize=tpl.Size;local ok=Pouch.Prepare();server(false);return ok end
local function byName(bag)local t={};for _,p in ipairs(H.partsOf(bag,true))do t[p.Name]=p end;return t end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local function c255(c)return math.floor(c.R*255+.5)..','..math.floor(c.G*255+.5)..','..math.floor(c.B*255+.5)end
local function sameColor(a,b)return c255(a)==c255(b)end
-- CIE76 colour distance (a plain, well known measure of "clearly a different colour")
local function lab(c)
 local function lin(u)u=u>.04045 and((u+.055)/1.055)^2.4 or u/12.92;return u end
 local r,g,b=lin(c.R),lin(c.G),lin(c.B)
 local x=(.4124*r+.3576*g+.1805*b)/.95047;local y=.2126*r+.7152*g+.0722*b;local z=(.0193*r+.1192*g+.9505*b)/1.08883
 local function f(t)return t>.008856 and t^(1/3)or 7.787*t+16/116 end
 return 116*f(y)-16,500*(f(x)-f(y)),200*(f(y)-f(z))
end
local function deltaE(a,b)local l1,a1,b1=lab(a);local l2,a2,b2=lab(b);return math.sqrt((l1-l2)^2+(a1-a2)^2+(b1-b2)^2)end
local Enum=R.Enum
local COAT={Gold=Rules.PackMutations.Gold,Diamond=Rules.PackMutations.Diamond}
local REFLECT={Gold=.38,Diamond=.28}
check(bake()==true,'the server bakes its flat pouch')

-- which parts keep their look: by name (the design's lit parts and stripes) ---------------------------------------------------------------------------------
local function keepName(n)
 return n:find('^Trace')or n:find('^ReactorCore')or n:find('^CoreFacet')or n:find('^ReactorInset')or n:find('^MechLetter')or n:find('^MechPlate')or n:find('^AntennaLED')
  or n:find('^HazardStripe')or n:find('^HazardSeal')or(n:find('^ReactorEdge')and n:match('^ReactorEdge[FB]2_'))
end
local plain=H.ground(8,MECH,1,'None');local plainBy=byName(plain)
local keepCount=0;for n,p in pairs(plainBy)do if keepName(n)then keepCount+=1 end end
-- 20 traces, 2 cores, 2 facets, 2 insets, 28 letters, 2 plates, 1 LED, 16 stripes, 16 cyan ring edges (ring 2: 8 a face)
check(keepCount==20+2+2+2+28+2+1+16+16,'the kept parts of the design: 20 traces, 2 cores, 2 facets, 2 insets, 28 letters, 2 plates, the LED, 16 hazard stripes, 16 cyan ring edges ('..keepCount..')')
local flagged=0;local mismatch={}
for n,p in pairs(plainBy)do
 local want=keepName(n)and true or false
 if(p:GetAttribute('MechCoatKeep')==true)~=want then mismatch[#mismatch+1]=n end
 if p:GetAttribute('MechCoatKeep')==true then flagged+=1 end
end
check(flagged==keepCount and#mismatch==0,'exactly those parts carry MechCoatKeep ('..flagged..' flagged; mismatches: '..table.concat(mismatch,',',1,math.min(#mismatch,4))..')')
for _,p in ipairs(H.partsOf(plain,false))do
 if p:IsA('MeshPart')then check(p:GetAttribute('MechCoatKeep')~=true,'the pouch itself is never kept') end
end
for _,n in ipairs({'BottomSeal','TearStrip1','TearStrip8'})do check(plainBy[n]and plainBy[n]:GetAttribute('MechCoatKeep')~=true,n..' (the seal and the strips) take the coat')end

-- 1-3. the treatment, in every context ---------------------------------------------------------------------------------------------------------------------
local function checkBag(bag,label,coat,pl)
 local c=COAT[coat];local by=byName(bag);local bad={}
 local kept,coated=0,0;local worldMeshT=coat=='Diamond'and .20 or 0
 for _,p in ipairs(H.partsOf(bag,false))do
  do
   local keep=p:GetAttribute('MechCoatKeep')==true
   local q=pl and pl[p.Name]
   if keep then
    kept+=1
    if q and not(sameColor(p.Color,q.Color)and p.Material==q.Material and p.Transparency==q.Transparency and p.Reflectance==q.Reflectance)then bad[#bad+1]='kept '..p.Name end
   elseif p.Name~='VisualRoot'then
    coated+=1
    local wantT=coat=='Diamond'and(p:IsA('MeshPart')and .20 or .10)or 0
    if not(sameColor(p.Color,c.Color)and p.Material==c.Material and near(p.Reflectance,REFLECT[coat],1e-6)and near(p.Transparency,wantT,1e-6))then bad[#bad+1]='coat '..p.Name end
    if p:IsA('MeshPart')and(p.TextureID or'')~=''then bad[#bad+1]='texture '..p.Name end
   end
  end
 end
 check(#bad==0 and kept==keepCount and coated>=60,label..(': %d parts take the coat exactly as a world pack\'s, %d keep their own colour (%s)'):format(coated,kept,table.concat(bad,',',1,math.min(#bad,4))))
 check(sameColor(bag:GetAttribute('PaperColor'),c.Color),label..': PaperColor is the coat\'s colour (the opening\'s paper)')
 check(bag:GetAttribute('PackMutation')==coat,label..': the bag says '..coat)
 return by
end
-- a WORLD pack of the same coat: the numbers the Mech pack must match
local world=H.ground(2,'Pack03',1,'Gold');local worldD=H.ground(2,'Pack03',1,'Diamond')
do
 local function sample(bag)local mesh,part;for _,p in ipairs(H.partsOf(bag,false))do if p:IsA('MeshPart')and not mesh then mesh=p elseif not p:IsA('MeshPart')and not part then part=p end end;return mesh,part end
 for coat,w in pairs({Gold=world,Diamond=worldD})do
  local mesh,part=sample(w);local c=COAT[coat]
  check(mesh and sameColor(mesh.Color,c.Color)and mesh.Material==c.Material and near(mesh.Reflectance,REFLECT[coat])and near(mesh.Transparency,coat=='Diamond'and .20 or 0),'(control) a world '..coat..' pack\'s pouch: '..c255(mesh.Color)..' / '..tostring(mesh.Material)..' / reflectance '..mesh.Reflectance..' / transparency '..mesh.Transparency)
  if part then check(sameColor(part.Color,c.Color)and part.Material==c.Material and near(part.Transparency,coat=='Diamond'and .10 or 0),'(control) ... and its seal parts: '..c255(part.Color)..' / '..tostring(part.Material)..' / transparency '..part.Transparency)end
 end
end
local scenes=0
for _,coat in ipairs({'Gold','Diamond'})do
 local c=COAT[coat]
 -- the pouch of the Mech pack is the one MeshPart, in the coat like a world pack's
 local bag=H.ground(8,MECH,1,coat);scenes+=1
 local meshes={};for _,p in ipairs(H.partsOf(bag,false))do if p:IsA('MeshPart')then meshes[#meshes+1]=p end end
 check(#meshes==1 and sameColor(meshes[1].Color,c.Color)and meshes[1].Material==c.Material and near(meshes[1].Reflectance,REFLECT[coat])and near(meshes[1].Transparency,coat=='Diamond'and .20 or 0),coat..': the Mech pouch (one MeshPart) is a coated world pouch\'s: '..c255(meshes[1].Color)..' / '..tostring(meshes[1].Material)..' / '..meshes[1].Reflectance)
 local by=checkBag(bag,'ground '..coat,coat,plainBy)
 -- readable: each lit part is a clear colour away from what it sits ON (the coat for the traces, the ring's cyan edges, the inset and the LED; the dark inset for the core; the core for
 -- its facet; the dark plate for the letters); the hazard stripes are black on the coated seal
 local backdrop=function(n)
  if n:find('^ReactorCore')then return by['ReactorInset'..n:sub(-1)].Color end
  if n:find('^CoreFacet')then return by['ReactorCore'..n:sub(-1)].Color end
  if n:find('^MechLetter')then return by['MechPlate'..n:match('^MechLetter([FB])')].Color end
  return c.Color
 end
 local worst,who=1e9,''
 for n,p in pairs(by)do if keepName(n)and not n:find('^HazardStripe')and not n:find('^HazardSeal')and not n:find('^MechPlate')and not n:find('^CoreFacet')then -- (the facet is the plain design's own light cyan on the cyan core, a coat does not change it)
  local d=deltaE(p.Color,backdrop(n));if d<worst then worst=d;who=n end
 end end
 check(worst>=25,('%s: every lit part (traces, core, facet, cyan ring, letters, inset, LED) is a clear colour from what it sits on: the closest is %s at CIE76 %.0f (>= 25)'):format(coat,who,worst))
 check(sameColor(by.AntennaLED.Color,Art.Colors.Led)and by.AntennaLED.Material==Enum.Material.Neon and by.AntennaLED:GetAttribute('MechBlink')>0,coat..': the antenna LED is still red neon and still blinks')
 check(sameColor(by.TraceF1_0.Color,Art.Colors.Cyan)and by.TraceF1_0.Material==Enum.Material.Neon and by.TraceF1_0:GetAttribute('MechPulse')>0,coat..': the traces are still cyan neon and still pulse')
 check(sameColor(by.ReactorCoreF.Color,Art.Colors.Cyan)and by.ReactorCoreF.Material==Enum.Material.Neon,coat..': the reactor core is still cyan neon')
 check(sameColor(by.HazardStripe1.Color,Art.Colors.Stripe)and sameColor(by.HazardSeal3.Color,Art.Colors.Stripe)and sameColor(by.TearStrip1.Color,c.Color)and sameColor(by.BottomSeal.Color,c.Color),coat..': the hazard stripes stay black on the coated seal and strips (the strips are '..c255(by.TearStrip1.Color)..')')
 check(sameColor(by.MechPlateF.Color,Art.Colors.Plate)and sameColor(by.MechLetterF1_1.Color,Art.Colors.Cyan),coat..': the MECH letters stay cyan on their dark plate')
 check(not sameColor(by.ReactorHousingF.Color,Art.Colors.Housing)and sameColor(by.ReactorHousingF.Color,c.Color)and sameColor(by.FrameTopF.Color,c.Color)and sameColor(by.BoltF1_0.Color,c.Color),coat..': the frame, the bolts and the reactor housing take the coat')
 -- sizes
 local half=H.ground(8,MECH,.5,coat);checkBag(half,'ground .5x '..coat,coat,plainBy);half:Destroy()
 local giant=H.ground(8,MECH,25,coat);checkBag(giant,'ground 25x '..coat,coat,plainBy);giant:Destroy()
 -- held R15 / R6
 for _,kind in ipairs({'R15','R6'})do
  local held,char=H.held(8,MECH,1,coat,kind);checkBag(held,'held '..kind..' '..coat,coat,plainBy)
  local fx=0;for _,d in ipairs(held:GetDescendants())do if d:IsA('PointLight')or d:IsA('ParticleEmitter')then fx+=1 end end
  check(fx==2,'held '..kind..' '..coat..': the hum light and the antenna sparks are still on the pack ('..fx..')')
  held:Destroy();char:Destroy()
 end
 -- pictures (Bag / hotbar / Index / shop): default shape or not
 for _,default in ipairs({true,false})do local pic=H.picture(8,MECH,1,coat,nil,default);checkBag(pic,'picture '..coat..(default and' (default shape)'or''),coat,plainBy);pic:Destroy()end
 local sanitized=H.sanitized(H.picture(8,MECH,1,coat,nil,true))
 do local n,keptN=0,0;for _,d in ipairs(sanitized:GetDescendants())do if d:IsA('BasePart')then n+=1;if d:GetAttribute('MechCoatKeep')==true then keptN+=1 end end end
  check(n==#H.partsOf(plain,false)and keptN==keepCount,coat..': the sanitised hotbar picture keeps every visible part ('..n..') and the '..keptN..' lit parts in their own colour')end
 sanitized:Destroy()
 -- the shop's viewport
 local vbag,vf=H.viewport(8,MECH,1,coat,nil,nil,true);checkBag(vbag,'viewport '..coat,coat,plainBy);vf:Destroy()
 -- the opening copy
 local copy=H.openingCopy(bag);checkBag(copy,'opening copy '..coat,coat,plainBy);copy:Destroy()
 bag:Destroy()
end

-- the plain-parts body (no flat pouch) ---------------------------------------------------------------------------------------------------------------------
do
 dropFolder()
 local plainS=H.ground(8,MECH,1,'None');local plainSBy=byName(plainS)
 for _,coat in ipairs({'Gold','Diamond'})do
  local bag=H.ground(8,MECH,1,coat);local c=COAT[coat]
  check(bag:GetAttribute('MechPouch')==false,'without the flat pouch the body is the plain parts ('..coat..')')
  checkBag(bag,'plain-parts body '..coat,coat,plainSBy)
  local core=bag:FindFirstChild('SachetCore',true)
  check(core and sameColor(core.Color,c.Color)and core.Material==c.Material,'plain-parts body '..coat..': the body is coated too ('..c255(core.Color)..')')
  bag:Destroy()
 end
 plainS:Destroy()
 check(bake()==true,'(the pouch baked again)')
end

-- 4. ItemPictures: its own picture for a coated Mech pack ----------------------------------------------------------------------------------------------------
do
 local ok,P=pcall(W.module,'ItemPictures')
 if ok and type(P)=='table'and P.Key then
  local function tool(coat)
   local t=R.new('Tool');t:SetAttribute('SeedPackTool',true);t:SetAttribute('Stage',8);t:SetAttribute('BagVariant',MECH);t:SetAttribute('PackMutation',coat);return t
  end
  local kn,kg,kd=P.Key(tool('None')),P.Key(tool('Gold')),P.Key(tool('Diamond'))
  check(kn~=kg and kg~=kd and kn~=kd,'ItemPictures: a plain / Gold / Diamond Mech pack are three different pictures ('..kn..' | '..kg..' | '..kd..')')
  check(kg:find('Gold',1,true)and kd:find('Diamond',1,true),'... keyed by the coat')
  local _,spec=P.Key(tool('Gold'));check(spec and spec.Mutation=='Gold'and spec.Variant==MECH and spec.Stage==8,'the picture is built with the coat (Mutation = Gold)')
  -- the picture it builds is the Gold pack
  local pic=H.Visuals.Bag(R.CFrame.Angles(0,.22,-.025),nil,1,nil,spec.Stage,spec.Variant,1,1,spec.Mutation,nil,spec.Plain,spec.Shape)
  local gold=0;for _,p in ipairs(H.partsOf(pic,false))do if p:IsA('MeshPart')and sameColor(p.Color,COAT.Gold.Color)then gold+=1 end end
  check(gold==1,'... and a Gold picture shows the gold pouch');pic:Destroy()
 else print('SKIP: ItemPictures did not load on the mock ('..tostring(P)..')')end
end

-- 5. the rig: pulse, blink and reset on a coated pack ---------------------------------------------------------------------------------------------------------
for _,coat in ipairs({'Gold','Diamond'})do
 local held,char=H.held(8,MECH,1,coat,'R15')
 local state=Shared.CaptureMotion(held)
 check(#state.Colors==20+2 and#state.Blinks==1 and#state.Lights==1 and#state.Fx==2,coat..': the rig captures the pulse (20 traces + 2 cores), the LED blink, the hum light and the 2 held fx ('..#state.Colors..' / '..#state.Blinks..' / '..#state.Lights..' / '..#state.Fx..')')
 local by=byName(held);local trace,core,led=by.TraceF1_0,by.ReactorCoreF,by.AntennaLED
 local rest={trace=trace.Color,core=core.Color,led=led.Color,pouch=nil}
 local pouch;for _,p in ipairs(H.partsOf(held,false))do if p:IsA('MeshPart')then pouch=p end end
 local pouchRest=pouch.Color;local moved=false
 for t=0,5.9,.3 do state:Step(t,held.PrimaryPart.CFrame);if not sameColor(trace.Color,rest.trace)then moved=true end end
 check(moved,coat..': the traces still pulse (their colour moves toward white and back)')
 state:Step(1.5,held.PrimaryPart.CFrame)
 local on,off;for t=0,1.7,.05 do state:Step(t,held.PrimaryPart.CFrame);if sameColor(led.Color,rest.led)then on=true else off=true end end
 check(on and off,coat..': the LED still blinks (on, then dim)')
 check(sameColor(pouch.Color,pouchRest)and sameColor(by.BottomSeal.Color,COAT[coat].Color),coat..': the rig never touches the coated pouch or seal')
 state:Reset()
 check(sameColor(trace.Color,rest.trace)and sameColor(core.Color,rest.core)and sameColor(led.Color,rest.led),coat..': Reset puts the traces, the core and the LED back to their own colours')
 state:Live(true,false);local enabled=0;for _,f in ipairs(state.Fx)do if f.Enabled then enabled+=1 end end
 check(enabled==2,coat..': the held fx switch on as before');state:Live(false)
 held:Destroy();char:Destroy()
end

-- 6. a plain pack is built as before ---------------------------------------------------------------------------------------------------------------------------
do
 local a=H.ground(8,MECH,1,'None');local b=H.ground(8,MECH,1,'None',nil,0)
 local pa,pb=byName(a),byName(b);local diff=0
 for n,p in pairs(pa)do local q=pb[n];if not q or not(sameColor(p.Color,q.Color)and p.Material==q.Material and p.Transparency==q.Transparency)then diff+=1 end end
 local meshes=0;for _,p in ipairs(H.partsOf(a,false))do if p:IsA('MeshPart')then meshes+=1;check(sameColor(p.Color,Art.Colors.Body)and p.Material==Enum.Material.Metal and p.Transparency==0,'a plain Mech pouch is still gunmetal metal')end end
 check(diff==0 and meshes==1,'a plain Mech pack is built the same every time (gunmetal pouch, yellow seal, the design in its own colours)')
 local seal=pa.BottomSeal;check(sameColor(seal.Color,Art.Colors.Hazard),'a plain Mech pack\'s seal is still hazard yellow')
 a:Destroy();b:Destroy()
end
-- 7. the seed, the plant and the fruit of a coated Mech pack: Gold / Diamond (MechArt.BuildNative, PlantVisuals) -----------------------------------------------------
do
 local Catalog=W.module('MechCatalog');local PlantVisuals=W.module('PlantVisuals');local PlantRules=W.module('PlantRules');local MechArt=W.module('MechArt')
 local want={Gold=Enum.Material.Metal,Diamond=Enum.Material.Glass}
 for _,coat in ipairs({'Gold','Diamond'})do
  for _,seed in ipairs(Catalog.Seeds)do
   -- the loose seed (the Bag's / the hand's / the reveal's model): every part is the coat
   local model=MechArt.BuildNative(seed.Id,CF(0,0,0),nil,1,nil,coat);local n,ok=0,0
   for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')and d.Transparency<.95 and d.Name~='VisualRoot'then n+=1;if d.Material==want[coat]then ok+=1 end end end
   check(n>0 and ok==n,seed.Id..': the seed of a '..coat..' pack is '..coat..' (BuildNative: '..ok..' of '..n..' parts)')
   model:Destroy()
   -- the planted plant: its base takes the crop's coat; a fruit takes its own (the 20% roll), through the same builder as every plant
   local crop={Id='c_'..seed.Id,SeedId=seed.Id,PlantScale=1,SeedScale=1,Mutation=coat,Weather='None',HarvestCycle=0,PickedMask=0,ReadyAt=0,MatureAt=0,PlantedAt=-100,TraitVersion=1}
   local ok2,plant=pcall(PlantVisuals.Build,seed.Id,CF(0,0,0),crop,4,1e9)
   if ok2 and plant then
    local base=plant:FindFirstChild('PlantBase');local bn,bok=0,0
    for _,d in ipairs(base and base:GetDescendants()or{})do if d:IsA('BasePart')and d.Transparency<.95 then bn+=1;if d.Material==want[coat]then bok+=1 end end end
    check(bn>0 and bok==bn,seed.Id..': the planted '..coat..' plant is '..coat..' (PlantVisuals.Build: '..bok..' of '..bn..' base parts)')
    -- the fruit: every fruit group marked with the coat is that coat in every part; a group without it is as a plain plant's
    local coatedGroups,plainGroups,badGroup=0,0,0
    for _,g in ipairs(plant:GetChildren())do if g.Name:match('^Harvest_')then
     local m=g:GetAttribute('Mutation')
     local gn,gok=0,0;for _,d in ipairs(g:GetDescendants())do if d:IsA('BasePart')and d.Transparency<.95 then gn+=1;if d.Material==want[coat]then gok+=1 end end end
     if m==coat then coatedGroups+=1;if gok~=gn then badGroup+=1 end else plainGroups+=1 end
    end end
    check(badGroup==0 and coatedGroups+plainGroups==seed.FruitCount,seed.Id..(': %d fruit groups on the plant; the ones the 20%% roll coated (%d) are %s in every part'):format(coatedGroups+plainGroups,coatedGroups,coat))
    plant:Destroy()
   else check(false,seed.Id..': PlantVisuals.Build did not build the '..coat..' plant: '..tostring(plant))end
  end
 end
 -- a fruit whose roll comes up coated is coated: search crop ids for one (the roll is saved identity, not luck)
 local def=W.module('PlantCatalog')['PlasmaPepperSeed']
 local found
 for k=1,400 do
  local crop={Id='fruit_'..k,SeedId='PlasmaPepperSeed',PlantScale=1,SeedScale=1,Mutation='Gold',Weather='None',HarvestCycle=0,PickedMask=0,ReadyAt=0,MatureAt=0,PlantedAt=-100,TraitVersion=1}
  if PlantRules.Fruit(crop,1,def).Mutation=='Gold'then found=crop;break end
 end
 if check(found~=nil,'a Gold Plasma Pepper plant has a fruit that comes up Gold within 400 plants (20%)')then
  local plant=PlantVisuals.Build('PlasmaPepperSeed',CF(0,0,0),found,4,1e9)
  local g=plant:FindFirstChild('Harvest_1');local gn,gok=0,0
  for _,d in ipairs(g and g:GetDescendants()or{})do if d:IsA('BasePart')and d.Transparency<.95 then gn+=1;if d.Material==Enum.Material.Metal and d.Color.R>=.85 then gok+=1 end end end
  check(g and g:GetAttribute('Mutation')=='Gold'and gn>0 and gok==gn,'... and that fruit is drawn Gold ('..gok..' of '..gn..' parts Gold metal)')
  plant:Destroy()
 end
end
print(string.format('%d checks, %d failures',checks,fails))
if fails>0 then error('test failed')end
