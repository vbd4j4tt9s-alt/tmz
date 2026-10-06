--!nocheck
-- R153 Mech pack, look B "Circuit Mech" (MechPackArt153): the art, on the Roblox mock with the REAL modules of this checkout and the REAL pack templates of the
-- owner's place (R151 pack_world.luau), the server's flat pouch baked on the EditableMesh mock (R151 pouch_mock.luau):
--  1. parts     the design's part count (today's R103 design had 174; look B may not have more), per face, per group
--  2. pouch     on the flat pouch: ONE MeshPart, the generated one (every vertex colour white), painted gunmetal; no Forest_01 mesh / print / texture anywhere
--  3. sachet    without it (not baked yet, no EditableMesh): plain parts with the same faces; no MeshPart at all; the design identical on either body
--  4. faces     both faces carry the design: every front part has its back twin, turned 180 degrees about the pouch's centre
--  5. features  the 4 hex corner bolts per face (3 blocks, 60 degrees apart, their pivot), the antenna + its blinking red LED, the hazard seal (yellow strips / seal,
--               a black stripe on each strip and each eighth of the seal), the MECH plate and its letters, the traces with their pulse, the reactor + turbine
--  6. contexts  ground, held (R15 / R6), picture, opening copy, market, viewport, at .5 / 1 / 25 and in the coats: the same parts at the same places; SCENE lines
--               for check_packs.py (floating parts, z-fighting: run_mech_pack.sh)
--  7. held      every part welded (the spinning ones on MechServo motors at their rest frame); the held fx are Attachments on the pack (a PointLight at the pouch's
--               centre, a ParticleEmitter at the LED), off when built; no orbiting scanner (MechFX false); the REAL SeedPackRender + ItemCosmetics for 3 s with the
--               pack held: the fx switched on once, never moved by a script (no CFrame / Position write on them), no scanner piece made; hidden on RevealAt
--  8. shapes    PackShapes151 never shapes the Mech pack (Applies / Roll); a bag given any PackShape or DefaultPackShape builds the identical pack
--  9. bounds    SeedPackVisuals.Bounds keeps every part (the antenna's LED included) and only MaxY grew: the carry layout (MinY / MaxZ), the pad and the pickup point
--               are what they were; the shop's LIMITED banner (PackViewport89) builds it and frames the LED; the rig (CaptureMotion) blinks, hums and resets
local H=require('./pack_world');local W,R=H.W,H.R;local V3,CF=R.Vector3.new,R.CFrame.new
local Mock=require('./pouch_mock')(W)
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Art=W.module('MechPackArt153');local Shared=W.module('SpecialPackArt89');local Pouch=W.module('VerityPouch151');local Shapes=W.module('PackShapes151')
local MECH=H.MECH
local function server(on)W.Run.IsServer=function()return on end;W.Run.IsClient=function()return not on end end
local function dropFolder()local f=W.RS:FindFirstChild(Pouch.Folder);if f then f:Destroy()end end
local function bake()server(true);dropFolder();Mock.reset();local tpl=W.RS.SeedPackMeshAssets.Storm_02.ApprovedMesh01;tpl.MeshSize=tpl.Size;local ok=Pouch.Prepare();server(false);return ok end
local function parts(bag)return H.partsOf(bag,false)end
local function byName(bag)local t={};for _,p in ipairs(H.partsOf(bag,true))do t[p.Name]=p end;return t end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local function cfNear(a,b,e)
 e=e or 1e-5;if(a.Position-b.Position).Magnitude>e then return false end
 for _,k in ipairs({'RightVector','UpVector','LookVector'})do if(a[k]-b[k]).Magnitude>e*10 then return false end end;return true
end
local C=Art.Colors
local FOREST=W.RS.SeedPackMeshAssets.Forest_01.ApprovedMesh01.MeshId
local TODAY_WHITE=R.Color3.fromRGB(231,237,239)
local function c255(c)return math.floor(c.R*255+.5)..','..math.floor(c.G*255+.5)..','..math.floor(c.B*255+.5)end

-- 1. parts --------------------------------------------------------------------------------------------------------------------------------
local specs=Art.Specs()
do
 check(#specs<=174,('look B has %d design parts (R103 today: 174; "about the same or fewer")'):format(#specs))
 local perFace=(#specs-19)/2
 check(perFace==math.floor(perFace)and perFace>=70,('both faces have the same number of parts (%s each, + 16 stripes + 3 antenna parts)'):format(tostring(perFace)))
 local want={Frame=8,Rivet=8,Bolt=24,ReactorHousing=2,ReactorInset=2,ReactorCore=2,ReactorEdge=32,CoreFacet=2,TurbineBlade=16,CounterGear=8,Trace=20,MechPlate=2,MechLetter=28,HazardStripe=8,HazardSeal=8,Antenna=3}
 local got={}
 for _,s in ipairs(specs)do for k in pairs(want)do if s.Name:sub(1,#k)==k then got[k]=(got[k]or 0)+1 end end end
 local bad={};for k,n in pairs(want)do if got[k]~=n then bad[#bad+1]=k..' '..tostring(got[k])..'/'..n end end
 check(#bad==0,'the design\'s groups: frame 4, rivets 4, bolts 4 x 3 blocks, the reactor (housing, inset, core, 16 ring edges, facet, 8 blades, 4 gears), 10 traces, the plate + 14 letters per face; 16 stripes, the antenna ('..table.concat(bad,'; ')..')')
 local b=H.ground(8,MECH,1,'None')
 print(('parts: look B %d design parts (%d a face, 16 stripes, the antenna); the built pack %d parts on the plain-parts body (+ the 10 of every pack: root, seal, 8 strips)'):format(#specs,perFace,#H.partsOf(b,true)))
 b:Destroy()
end

-- 2. on the flat pouch ----------------------------------------------------------------------------------------------------------------------
local contexts={
 {'ground',function(size,coat)return H.ground(8,MECH,size,coat)end},
 {'held15',function(size,coat)local b,c=H.held(8,MECH,size,coat,'R15');return b,c end},
 {'held6',function(size,coat)local b,c=H.held(8,MECH,size,coat,'R6');return b,c end},
 {'picture',function(size,coat)return H.picture(8,MECH,size,coat,nil,true)end},
 {'viewport',function(size,coat)local b,vf=H.viewport(8,MECH,size,coat,nil,nil,true);return b,vf end},
 {'market',function()return H.market(8,MECH)end},
}
local scenes={}
local function sceneOf(bag,label)scenes[#scenes+1]='SCENE '..H.json(H.scene(bag,label))end
check(bake()==true,'the server bakes its flat pouch (VerityPouch151, the EditableMesh mock)')
local generated=Mock.meshes[#Mock.meshes]
do
 local white=generated~=nil
 for _,c in ipairs(generated and generated._colors or{})do if not(c.R>.999 and c.G>.999 and c.B>.999)then white=false end end
 check(white and #(generated and generated._colors or{})>=1,'the pouch the Mech pack uses is the GENERATED flat one: every vertex colour white (no print can survive)')
end
local ref -- the ground pack's parts in its root's frame, for the contexts
local seen=0
for _,size in ipairs({1,.5,25})do for _,coat in ipairs({'None','Gold','Diamond'})do if size==1 or coat=='None'then for _,ctx in ipairs(contexts)do
 if not(ctx[1]=='market'and(size~=1 or coat~='None'))then
  local bag,extra=ctx[2](size,coat);seen+=1
  local label=('%s %s %s'):format(ctx[1],size,coat)
  local meshes,forest,textured,appearance={},0,0,0
  for _,d in ipairs(bag:GetDescendants())do
   if d:IsA('MeshPart')then meshes[#meshes+1]=d;if d.MeshId==FOREST then forest+=1 end;if(d.TextureID or'')~=''then textured+=1 end end
   if d:IsA('SurfaceAppearance')then appearance+=1 end
  end
  check(bag:GetAttribute('MechDesignRevision')==153 and bag:GetAttribute('MechPouch')==true,label..': look B on the flat pouch')
  check(#meshes==1 and forest==0 and textured==0 and appearance==0,label..(': one MeshPart (the flat pouch), no Forest_01 mesh, no texture, no SurfaceAppearance (%d / %d / %d / %d)'):format(#meshes,forest,textured,appearance))
  if coat=='None'and meshes[1]then check(meshes[1].Color==C.Body and meshes[1].Material==R.Enum.Material.Metal,label..': the pouch is gunmetal '..c255(meshes[1].Color))end
  local white=0;for _,p in ipairs(parts(bag))do if c255(p.Color)==c255(TODAY_WHITE)then white+=1 end end
  check(white==0,label..': nothing is R103\'s white (231,237,239) any more')
  if size==1 and coat=='None'and ctx[1]=='ground'then sceneOf(bag,'MechPouch');ref=bag else
   if ref and size==1 then
    -- the same parts at the same places (in the root's frame / scale) as the ground pack
    local a,b=byName(ref),byName(bag);local diff=0;local s1,s2=ref:GetAttribute('VisualScale'),bag:GetAttribute('VisualScale')
    for name,p in pairs(a)do local q=b[name]
     if p~=ref.PrimaryPart and q then
      local fa=ref.PrimaryPart.CFrame:Inverse()*p.CFrame;local fb=bag.PrimaryPart.CFrame:Inverse()*q.CFrame
      if not cfNear(CF(fa.Position/s1)*fa.Rotation,CF(fb.Position/s2)*fb.Rotation,1e-4)or(p.Size/s1-q.Size/s2).Magnitude>1e-5 then diff+=1 end
     elseif p~=ref.PrimaryPart and(p.Transparency<.95)then diff+=1 end
    end
    check(diff==0,label..(': the same parts at the same places as on the ground (%d differ)'):format(diff))
   end
   if ctx[1]=='held15'and size==1 and coat=='None'then sceneOf(bag,'MechPouchHeld')end
   if not(ref==bag)then bag:Destroy()end
  end
  if extra and extra.Destroy then extra:Destroy()end
 end
end end end end
print(('pouch: %d built packs in every context / size / coat, all on the flat pouch, no print'):format(seen))
-- what ItemPictures keeps of a picture (its sanitising: invisible parts, lights, emitters, attachments go): every visible part of the design
do local pic=H.sanitized(H.picture(8,MECH,1,'None',nil,true));local n=0;for _,d in ipairs(pic:GetDescendants())do if d:IsA('BasePart')then n+=1 end end
 local fx=0;for _,d in ipairs(pic:GetDescendants())do if d:IsA('Light')or d:IsA('ParticleEmitter')or d:IsA('Attachment')then fx+=1 end end
 check(n==#H.partsOf(ref,false)and fx==0,('the hotbar / Bag / Index / shop picture keeps every visible part (%d of %d) and no light / emitter'):format(n,#H.partsOf(ref,false)));pic:Destroy()end
-- the opening copy (SeedPackClient's clone) is the same pack
do local copy=H.openingCopy(ref);local a,b=byName(ref),byName(copy);local same=0;for n in pairs(a)do if b[n]then same+=1 end end
 check(same==#H.partsOf(ref,true),'the opening copy has every part of the pack');copy:Destroy()end

-- 3. the plain-parts body ---------------------------------------------------------------------------------------------------------------------
local refDesign
local function design(bag)local t={};for _,l in ipairs(H.lines(bag))do if not l:find('Sachet',1,true)and not l:find('ApprovedMesh',1,true)and not l:find('|MODEL|',1,true)and not l:find('MODEL|',1,true)then t[#t+1]=l end end;return table.concat(t,'\n')end
do
 refDesign=design(ref)
 dropFolder()
 for _,ctx in ipairs(contexts)do
  local bag,extra=ctx[2](1,'None');local meshes=0;for _,d in ipairs(bag:GetDescendants())do if d:IsA('MeshPart')then meshes+=1 end end
  check(bag:GetAttribute('MechPouch')==false and meshes==0 and bag:FindFirstChild('SachetCore',true)~=nil,ctx[1]..': without the flat pouch the body is plain parts (no MeshPart at all)')
  if ctx[1]=='ground'then
   check(design(bag)==refDesign,'the design on the plain-parts body is exactly the one on the pouch')
   local core=bag:FindFirstChild('SachetCore',true);local f=bag.PrimaryPart.CFrame:Inverse()*core.CFrame;local P=Art.Pouch
   check(near(f.Position.Z-core.Size.Z/2,P.Center.Z-P.Depth/2,1e-5)and near(f.Position.Z+core.Size.Z/2,P.Center.Z+P.Depth/2,1e-5),'the plain body\'s two faces are the flat pouch\'s two face planes')
   sceneOf(bag,'MechSachet')
  elseif ctx[1]=='held15'then sceneOf(bag,'MechSachetHeld')end
  if ctx[1]~='ground'then bag:Destroy()end
  if extra and extra.Destroy then extra:Destroy()end
 end
 for _,size in ipairs({.5,25})do local b=H.ground(8,MECH,size,'None');sceneOf(b,'MechSachet'..size);b:Destroy()end
 check(bake()==true,'(the pouch baked again)')
 for _,size in ipairs({.5,25})do local b=H.ground(8,MECH,size,'None');sceneOf(b,'MechPouch'..size);b:Destroy()end
 -- a client asking while the server still bakes gets the plain body at once (no error, no wait: the shop banner builds it once)
 local f=W.RS:FindFirstChild(Pouch.Folder);f:SetAttribute('Finished',false)
 local ok,b=pcall(H.ground,8,MECH,1,'None')
 check(ok and b and b:GetAttribute('MechPouch')==false,'while the pouch is still being made, a Mech pack builds at once on the plain-parts body');if ok and b then b:Destroy()end
 f:SetAttribute('Finished',true)
end

-- 4. both faces ---------------------------------------------------------------------------------------------------------------------------------
do
 local per=(#specs-19)/2;local P=Art.Pouch
 local turn=CF(0,0,P.Center.Z)*R.CFrame.Angles(0,math.pi,0)*CF(0,0,-P.Center.Z)
 local bad={}
 for i=1,per do
  local f,b=specs[i],specs[i+per]
  local okName=#f.Name==#b.Name;local d=0
  for k=1,#f.Name do local x,y=f.Name:sub(k,k),b.Name:sub(k,k);if x~=y then d+=1;if not(x=='F'and y=='B')then okName=false end end end
  okName=okName and d==1
  if not(okName and cfNear(turn*f.Frame,b.Frame,1e-5)and(f.Size-b.Size).Magnitude<1e-9 and f.Color==b.Color and f.Material==b.Material)then bad[#bad+1]=f.Name..'/'..b.Name end
 end
 check(#bad==0,('both faces carry the design: each of the %d front parts has its back twin, turned 180 degrees about the pouch\'s centre (%s)'):format(per,table.concat(bad,',',1,math.min(#bad,5))))
 local fr,bk=Art.FaceFrame(-1),Art.FaceFrame(1)
 check(near(fr.Position.Z,P.Center.Z-P.Depth/2)and near(bk.Position.Z,P.Center.Z+P.Depth/2)and fr.LookVector.Z>.99 and bk.LookVector.Z<-.99,'the face frames sit on the pouch\'s two flat faces, +Z out of each')
end

-- 5. the features -------------------------------------------------------------------------------------------------------------------------------
do
 local bag=ref;local all=parts(bag)
 local bolts={}
 for _,p in ipairs(all)do local i=p:GetAttribute('MechBolt');if i then local k=p:GetAttribute('MechFace')..':'..i;bolts[k]=bolts[k]or{};table.insert(bolts[k],p)end end
 local nb,hex=0,0
 for _,list in pairs(bolts)do
  nb+=1
  local piv=list[1]:GetAttribute('MechBoltPivot')
  local angles={}
  for _,p in ipairs(list)do local f=piv:Inverse()*p:GetAttribute('PackLocalFrame');angles[#angles+1]=math.deg(math.atan2(f.RightVector.Y,f.RightVector.X))%180;if not near(f.Position.X,0,1e-5)or not near(f.Position.Y,0,1e-5)then angles[#angles]=-999 end end
  table.sort(angles)
  if #list==3 and near(angles[1],0,.01)and near(angles[2],60,.01)and near(angles[3],120,.01)and near(list[1].Size.Y/list[1].Size.X,math.sqrt(3),1e-6)then hex+=1 end
 end
 check(nb==8 and hex==8,('4 hex corner bolts on each face (3 blocks 60 degrees apart, sqrt(3):1, on one pivot): %d bolts, %d hexagons'):format(nb,hex))
 local by=byName(bag)
 check(by.AntennaBase and by.AntennaMast and by.AntennaLED and by.AntennaLED.Material==R.Enum.Material.Neon and c255(by.AntennaLED.Color)==c255(C.Led)and by.AntennaLED:GetAttribute('MechBlink')>0,'the antenna: a base, a mast and a red neon LED that blinks (MechBlink)')
 local top=(bag.PrimaryPart.CFrame:Inverse()*by.AntennaLED.CFrame).Position.Y+by.AntennaLED.Size.Y/2
 check(near(top,Art.Antenna.Top,1e-4)and by.AntennaBase.Position.Y<by.AntennaLED.Position.Y,'the LED stands on top of the mast on the top crimp (its top at '..string.format('%.3f',top)..')')
 local seal,strips,stripeOn=0,0,0
 for _,p in ipairs(bag:GetChildren())do if p:IsA('BasePart')then
  if p.Name=='BottomSeal'and c255(p.Color)==c255(C.Hazard)then seal+=1 end
  if p:GetAttribute('TearIndex')and c255(p.Color)==c255(C.Hazard)then strips+=1
   local s=by['HazardStripe'..p:GetAttribute('TearIndex')]
   if s and s:GetAttribute('MechTear')==p:GetAttribute('TearIndex')and(s.Position-p.Position).Magnitude<1e-4 and c255(s.Color)==c255(C.Stripe)then stripeOn+=1 end
  end
 end end
 local sealStripes=0;for i=1,8 do if by['HazardSeal'..i]and c255(by['HazardSeal'..i].Color)==c255(C.Stripe)then sealStripes+=1 end end
 check(seal==1 and strips==8 and stripeOn==8 and sealStripes==8,('the hazard seal: the bottom seal and the 8 tear strips hazard yellow, a black diagonal stripe through each strip (%d) and each eighth of the seal (%d)'):format(stripeOn,sealStripes))
 local letters=0;for _,p in ipairs(all)do if p.Name:match('^MechLetter')and p.Material==R.Enum.Material.Neon then letters+=1 end end
 check(by.MechPlateF and by.MechPlateB and letters==28,'the MECH plate on each face with its 14 neon strokes ('..letters..')')
 local traces,pulse=0,0;for _,p in ipairs(all)do if p.Name:match('^Trace')then traces+=1;if p:GetAttribute('MechPulse')and p:GetAttribute('MechGlow')then pulse+=1 end end end
 check(traces==20 and pulse==20,'10 cyan traces per face, each with its pulse (MechPulse, phased so it runs outward) and the opening\'s glow ('..pulse..')')
 local spin=0;for _,p in ipairs(all)do if p:GetAttribute('MechMotion')=='Spin'then spin+=1 end end
 check(spin==26 and by.ReactorCoreF and by.ReactorCoreF:GetAttribute('MechPulse'),'R103\'s reactor + turbine kept: the facet, 8 blades and 4 counter-gears spin on each face (26), the core pulses')
 local rivets=0;for _,p in ipairs(all)do if p.Name:match('^Rivet')and p.Shape==R.Enum.PartType.Ball then rivets+=1 end end
 check(rivets==8 and by.FrameTopF and by.FrameSideF1,'the riveted steel frame on each face')
 check(c255(by.ReactorCoreF.Color)==c255(C.Cyan)and by.ReactorCoreF.Material==R.Enum.Material.Neon,'the core is today\'s cyan neon')
end

-- 7. held ------------------------------------------------------------------------------------------------------------------------------------
do
 local Players=W.service('Players');local player=Players.LocalPlayer
 local held,char,hrp,torso=H.held(8,MECH,1,'None','R15');player.Character=char
 local moving,servo,welded,loose=0,0,0,{}
 for _,p in ipairs(parts(held))do
  if p.Anchored then loose[#loose+1]=p.Name end
  if p:GetAttribute('MechMotion')then moving+=1;local j=p:FindFirstChild('MechServo');if j and j.Part0==held.PrimaryPart and j.Part1==p and cfNear(j.C0,p:GetAttribute('PackLocalFrame'),1e-9)then servo+=1 end
  elseif p:FindFirstChildOfClass('WeldConstraint')then welded+=1 end
 end
 check(#loose==0 and moving==26 and servo==26 and welded+moving==#parts(held),('held: nothing anchored, %d parts welded, the 26 spinning ones on MechServo motors at their rest frame'):format(welded))
 local fx={};for _,d in ipairs(held:GetDescendants())do if d:IsA('Attachment')and d.Name:match('^Mech')then fx[d.Name]=d end end
 local light=fx.MechHum and fx.MechHum:FindFirstChildOfClass('PointLight');local sparks=fx.MechSparks and fx.MechSparks:FindFirstChildOfClass('ParticleEmitter')
 check(fx.MechHum and fx.MechHum.Parent==held.PrimaryPart and fx.MechSparks and fx.MechSparks.Parent.Name=='AntennaLED','the held fx are Attachments ON the pack: the hum at the root (the pouch\'s centre), the sparks at the LED')
 check(light and sparks and light.Enabled==false and sparks.Enabled==false and light:GetAttribute('MechHeldFx')and sparks:GetAttribute('MechHeldFx'),'one PointLight (the hum) and one ParticleEmitter (the sparks), both off when built')
 check(sparks and sparks.Rate>=2 and sparks.Rate<=3,'the antenna gives 2 - 3 sparks a second')
 check(held.PrimaryPart:GetAttribute('MechFX')==false,'no orbiting scanner: MechFX is false on the pack (ItemVisualEffects\' 12 pieces are for the Mech plants only now)')
 -- the real client scripts with the pack held, every write to the fx recorded
 local watch={};for _,d in ipairs(held:GetDescendants())do if d:IsA('Attachment')or d:IsA('Light')or d:IsA('ParticleEmitter')then watch[d]=true end end
 local writes={};local meta=R.instMeta;local nidx=meta.__newindex
 meta.__newindex=function(o,k,v)if watch[o]then writes[k]=(writes[k]or 0)+1 end;return nidx(o,k,v)end
 local cam=W.workspace.CurrentCamera;cam.CFrame=CF(0,6,-12)*R.CFrame.Angles(0,math.pi,0)
 local s1=R.new('LocalScript');s1.Name='SeedPackRender';W.load('SeedPackRender',s1)
 local s2=R.new('LocalScript');s2.Name='ItemCosmetics';W.load('ItemCosmetics',s2)
 for k=1,180 do torso.CFrame=H.path(k,180);W.frames(1,1/60)end
 local scanner=0;for _,d in ipairs(W.workspace:GetDescendants())do if d.Name=='Mechanical scanner'then scanner+=1 end end
 check(light.Enabled==true and(writes.Enabled or 0)<=2,('the REAL SeedPackRender switches the hum (and the sparks) on for the held pack, once (%d Enabled writes in 3 s)'):format(writes.Enabled or 0))
 check((writes.CFrame or 0)==0 and(writes.Position or 0)==0 and(writes.WorldCFrame or 0)==0,('the held fx follow the pack by themselves: no CFrame / Position write on them in 180 frames (%d)'):format((writes.CFrame or 0)+(writes.Position or 0)))
 check(scanner==0,'the REAL ItemCosmetics makes no scanner piece for the Mech pack ('..scanner..')')
 local before=writes.Brightness or 0
 held:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 W.frames(2,1/60)
 check(light.Enabled==false and sparks.Enabled==false,'the hum and the sparks go off when the pack is opening (RevealAt: the pack is hidden)')
 print(('held: fx writes in 180 frames: Enabled %d, Brightness %d (the hum\'s pulse, the rig\'s Step), CFrame 0'):format(writes.Enabled or 0,before))
 meta.__newindex=nidx
 s1:Destroy();s2:Destroy();held:Destroy();char:Destroy();player.Character=nil
end

-- 8. shapes ---------------------------------------------------------------------------------------------------------------------------------
do
 check(not Shapes.Applies('MechLimited')and Shapes.Roll('MechLimited')==nil,'PackShapes151 never gives the Mech pack a chip-bag shape (Applies false, Roll nil), as before')
 local base=design(H.ground(8,MECH,1,'None'))
 local same=0
 for shape=0,6 do local b=H.ground(8,MECH,1,'None',nil,shape);if design(b)==base and b:GetAttribute('PackShape')==nil then same+=1 end;b:Destroy()end
 local d=H.picture(8,MECH,1,'None',3,true);d.Parent=W.workspace;if design(d)==base then same+=1 end;d:Destroy()
 check(same==8,'a Mech bag given PackShape 0..6, or a DefaultPackShape picture, builds the identical pack ('..same..'/8)')
end

-- 9. bounds, the shop banner, the rig -------------------------------------------------------------------------------------------------------
do
 local Visuals=H.Visuals;local b=Visuals.Bounds(8,MECH,1)
 -- R152's Mech bounds: the Forest_01 body's box + depth .075, radius .085, .04 above / below
 local body=Shared.BodyBounds()
 check(near(b.MinY,body.MinY-.04)and near(b.MinZ,body.MinZ-.075)and near(b.MaxZ,body.MaxZ+.075)and near(b.Radius,body.Radius+.085),'Bounds: MinY / MinZ / MaxZ / Radius are R152\'s (the carry layout, the pad and the pickup point do not move)')
 check(b.MaxY>=Art.Antenna.Top and near(b.MaxY,math.max(body.MaxY+.04,Art.Antenna.Top+.04)),('Bounds: MaxY %.3f takes the antenna\'s LED (top %.3f)'):format(b.MaxY,Art.Antenna.Top))
 local held,char=H.held(8,MECH,1,'None','R15')
 local L=W.module('PackCarryLayout');local _,_,_,info=L.Calculate(char,{MinY=b.MinY,MaxY=body.MaxY+.04,MinZ=b.MinZ,MaxZ=b.MaxZ,Radius=b.Radius},1)
 check(cfNear(held:GetAttribute('CarryRootOffset'),info.Offset,1e-9),'the pack is held exactly where R152 held it (PackCarryLayout with R152\'s bounds)')
 held:Destroy();char:Destroy()
 -- the LIMITED banner (PackViewport89): it builds the R153 pack and its camera sees the LED
 local holder=R.new('Frame');holder.Parent=W.workspace
 local ok,view=pcall(W.module('PackViewport89').Create,holder)
 local bag;if ok and view then for _,d in ipairs(view:GetDescendants())do if d.Name=='SeedPacket'then bag=d end end end
 check(ok and bag and bag:GetAttribute('MechDesignRevision')==153,'the shop\'s LIMITED banner builds the R153 Mech pack: '..tostring(ok and''or view))
 if bag then
  local cam=view.CurrentCamera;local led=bag:FindFirstChild('AntennaLED',true)
  local rel=cam.CFrame:Inverse()*led.CFrame.Position;local half=math.tan(math.rad(cam.FieldOfView/2))*(-rel.Z)
  check(rel.Z<0 and math.abs(rel.Y)+led.Size.Y/2<=half,('the banner\'s camera frames the LED (%.2f of the half height)'):format((math.abs(rel.Y)+led.Size.Y/2)/half))
 end
 holder:Destroy()
 -- the rig: the LED blinks, the hum pulses, Live switches the fx, Reset puts everything back
 local g=H.ground(8,MECH,1,'None');local m=Shared.CaptureMotion(g)
 local led=g:FindFirstChild('AntennaLED',true);local light=g:FindFirstChild('MechHumLight',true);local sp=g:FindFirstChild('MechAntennaSparks',true)
 m:Step(.1);local on=led.Color;m:Step(.6);local off=led.Color
 check(c255(on)==c255(C.Led)and c255(off)~=c255(C.Led),'the LED blinks (on for half of its .9 s, a dim red the other half)')
 m:Step(.3);local b1=light.Brightness;m:Step(1.5);local b2=light.Brightness
 check(math.abs(b1-b2)>.05 and b1<=.8*1.0001 and b2>=.8*.5-1e-6,'the hum light pulses softly around its brightness')
 m:Live(true,false);local both=light.Enabled and sp.Enabled;m:Live(true,true);local lowOnly=light.Enabled and not sp.Enabled;m:Live(false);local none=not light.Enabled and not sp.Enabled
 check(both and lowOnly and none,'Live: the hum and the sparks on, the sparks off on low quality, both off')
 m:Live(true);m:Reset()
 check(c255(led.Color)==c255(C.Led)and near(light.Brightness,.8)and not light.Enabled,'Reset: the LED, the hum and the fx back as built')
 g:Destroy()
end

for _,s in ipairs(scenes)do print(s)end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
