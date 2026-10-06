--!nocheck
-- R152 seed opening, part 3: THE LOOK (owner: "the beam ... down from the sky, it should have textures", "planets have to look good by
-- texturing", "improve look on the beam and assets used in the animations", "animation must be smooth"). The real RarePullArt / RarePullFx /
-- RarePullScenes / RarePullCard / RarePullWorld / RevealFlourish / RarePullCinematic on the Roblox mock:
--  1. the images drawn on the client (RarePullArt): every one the right size, the same every time, see-through around the round ones,
--     seamless where it tiles; drawn a slice at a time; none on low quality
--  2. the story stages with the images and without them (not drawn yet, EditableImage off): every image has a dressed fallback, the part /
--     light budgets of R151 hold either way, nothing casts a shadow
--  3. every effect is anchored to its subject: beams, emitters, lights and images live in the stage, on parts / attachments that follow what
--     they belong to (the seed's halo behind the seed, the hit's burst at the pack, the King's carry beam on the pack as it glides in, the
--     crown beam on the throne); the sky beam's foot at the puller's feet as they walk
--  4. the sky beam: it slams down (its foot falls faster and faster) and lands ON the burst; dust and sparks once; the ground impact after
--     the landing only; its layers per ClientFxBudget tier; gone after Destroy
--  5. clean-up: skip, close (abort, death, the script destroyed) and a second pack leave no beam, emitter, light or image behind; a
--     flourish beam goes with its pack
--  6. smoothness, at 30 and 60 fps: the pack, the seed, the crown, the camera and the card's seed never jump (no pop) and never change speed
--     in one frame (no kink) at any phase boundary, and every one of them is in the same place at the same moment at 30 and at 60 fps
--  7. budgets per tier: beam layers, particles emitted per presentation
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Scenes=W.module('RarePullScenes')
local Fx=W.module('RarePullFx');local Art=W.module('RarePullArt');local World=W.module('RarePullWorld');local Flourish=W.module('RevealFlourish')
local Visuals=W.module('SeedPackVisuals')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local FXC={Beam=true,ParticleEmitter=true,PointLight=true,SpotLight=true,SurfaceLight=true,BillboardGui=true,SurfaceGui=true,Highlight=true,Decal=true,Texture=true,Trail=true}
local function reset()
 M.Abort('test');World.Clear()
 cam=W.workspace.CurrentCamera
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;X.lowFx=false
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 for _,c in ipairs(X.char:GetChildren())do if c.Name=='CarriedSeed'or c:IsA('Tool')then c:Destroy()end end
 R.advance(4)
end
local function start(rank,extra)
 local seedId=X.byRank[rank]
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info),bag
end
local function stage()return W.workspace:FindFirstChild('_RarePullStage')end
local function fxIn(root)local out={};for _,d in ipairs(root:GetDescendants())do if FXC[d.ClassName]then out[#out+1]=d end end;return out end
local function set(list)local s={};for _,d in ipairs(list)do s[d]=true end;return s end
local function count(root,name)local n=0;for _,d in ipairs(root:GetDescendants())do if d.Name==name then n+=1 end end;return n end
local function arts(root)local n=0;for _,d in ipairs(root:GetDescendants())do if d:GetAttribute('RarePullArt')then n+=1 end end;return n end
-- the image hooks: EditableImage and Content stand-ins (Create fails when `ok` is false: EditableImage off / out of memory)
local yields=0
local function hooks(ok)
 Art.Hooks.Spawn=function(fn)fn()end
 Art.Hooks.Wait=function()yields+=1 end
 Art.Hooks.Create=function(w,h,rgba)if not ok then error('EditableImage unavailable (test)')end;return {W=w,H=h,Data=rgba,Destroy=function()end}end
 Art.Hooks.Content=function(o)return 'rbxtemp://r152/'..o.W..'x'..o.H end
end
local function drawAll(ok)Art.Reset();hooks(ok);Art.Request(Art.Order)end
-- 1. the images ------------------------------------------------------------------------------------------------------------------------
do
 local round={planet_gas=true,planet_rock=true,planet_ring=true,glow=true,halo=true,runes=true,nebula_rose=true,nebula_blue=true}
 local tiles={carpet='V',damask='UV',starmap='UV'}
 local times={}
 for _,name in ipairs(Art.Order)do
  local t0=os.clock();local w,h,rgba=Art.Pattern(name);times[#times+1]=string.format('%s %.0f ms',name,(os.clock()-t0)*1000)
  local size=Art.Sizes[name]
  check(w==size[1]and h==size[2]and buffer.len(rgba)==w*h*4,name..': '..tostring(w)..' x '..tostring(h)..', RGBA')
  local _,_,again=Art.Pattern(name)
  check(buffer.tostring(again)==buffer.tostring(rgba),name..': drawn the same way every time (every client, the preview)')
  local function px(x,y)local i=(y*w+x)*4;return buffer.readu8(rgba,i),buffer.readu8(rgba,i+1),buffer.readu8(rgba,i+2),buffer.readu8(rgba,i+3)end
  local seen=0;for y=0,h-1,4 do for x=0,w-1,4 do local _,_,_,a=px(x,y);if a>8 then seen+=1 end end end
  check(seen>0,name..': not empty')
  if round[name]then
   local corner=0;for _,c in ipairs({{0,0},{w-1,0},{0,h-1},{w-1,h-1}})do local _,_,_,a=px(c[1],c[2]);corner=math.max(corner,a)end
   check(corner==0,name..': see-through around it (corner alpha '..corner..')')
  end
  if tiles[name]then
   -- seamless: the step from the last row (column) back to the first is no bigger than an ordinary step inside the image
   local function rowDiff(y0,y1)local s=0;for x=0,w-1 do local a={px(x,y0)};local b={px(x,y1)};for k=1,4 do s+=math.abs(a[k]-b[k])end end;return s/w end
   local function colDiff(x0,x1)local s=0;for y=0,h-1 do local a={px(x0,y)};local b={px(x1,y)};for k=1,4 do s+=math.abs(a[k]-b[k])end end;return s/h end
   local inner=0;for y=1,h-1 do inner=math.max(inner,rowDiff(y-1,y))end
   check(rowDiff(h-1,0)<=inner*1.05+2,name..': tiles seamlessly top to bottom ('..string.format('%.1f vs %.1f',rowDiff(h-1,0),inner)..')')
   if tiles[name]=='UV'then
    local innerC=0;for x=1,w-1 do innerC=math.max(innerC,colDiff(x-1,x))end
    check(colDiff(w-1,0)<=innerC*1.05+2,name..': and side to side ('..string.format('%.1f vs %.1f',colDiff(w-1,0),innerC)..')')
   end
  end
 end
 print('images (CLI, unsliced): '..table.concat(times,', '))
 -- (the mock's clock stands still inside a frame, so every point where the drawing may pause is counted: SliceSeconds < 0)
 local slice=Art.SliceSeconds;Art.SliceSeconds=-1;yields=0;drawAll(true);Art.SliceSeconds=slice
 local ready=0;for _,name in ipairs(Art.Order)do if Art.Get(name)=='ready'then ready+=1 end end
 check(ready==#Art.Order,'every image is ready after drawing ('..ready..' of '..#Art.Order..')')
 local rows=0;for _,name in ipairs(Art.Order)do rows+=Art.Sizes[name][2]end
 check(yields>=rows*.9 and Art.SliceSeconds<=.005,'drawn a slice at a time (it may pause every row: '..yields..' points for '..rows..' rows; '..(Art.SliceSeconds*1000)..' ms a slice): no frame hitch')
 drawAll(false)
 local failed=0;for _,name in ipairs(Art.Order)do if Art.Get(name)=='failed'then failed+=1 end end
 check(failed==#Art.Order,'without EditableImage every image is "failed" (and every user keeps its fallback): '..failed)
 X.lowFx=true;check(not Art.Allowed()and Art.Warm()==false,'low quality / FastMode: nothing is drawn');X.lowFx=false
end
-- 1b. review fixes B1 / B4: nothing is drawn that is never shown, nothing is drawn while a reveal runs, 2 ms slices on tier 2, a light warm-up once idle ----------------------
do
 local B=W.module('ClientFxBudget')
 local drawn,waits={},0
 local function record(onWait)
  Art.Reset();table.clear(drawn);waits=0
  Art.Hooks.Spawn=function(fn)fn()end
  Art.Hooks.Wait=function()waits+=1;if onWait then onWait()end end
  Art.Hooks.Create=function(w,h,rgba,name)drawn[#drawn+1]={Name=name,Running=L.RevealRunning==true};return {W=w,H=h,Data=rgba,Destroy=function()end}end
  Art.Hooks.Content=function(o)return 'rbxtemp://r152/'..o.W..'x'..o.H end
 end
 local function names_()local n={};for _,d in ipairs(drawn)do n[#n+1]=d.Name end;return table.concat(n,',')end
 -- B1: a scene built on low quality draws nothing (its images would never be shown); on tier 2 / 3 the scene asks for its own
 record();X.lowFx=true
 local sc=Scenes.Build(7,{});check(#drawn==0 and Art.Get('planet_gas')==nil and Art.Get('glow')==nil,'B1: low quality: building a story scene draws no image ('..#drawn..': '..names_()..')');sc:Destroy()
 X.lowFx=false
 sc=Scenes.Build(7,{});local want7=0;for _,n in ipairs(Scenes.ArtNames[7])do if Art.Get(n)=='ready'then want7+=1 end end
 check(want7==#Scenes.ArtNames[7],'B1: on normal quality the scene asks for its images (drawn for the next one): '..want7..' of '..#Scenes.ArtNames[7]);sc:Destroy()
 -- B1: no drawing WHILE a reveal runs (RarePullRules.RevealRunning): the worker waits, mid-image too, and goes on when the reveal is over
 local sliceWas=Art.SliceSeconds;Art.SliceSeconds=-1 -- (the mock's clock stands still: every step may pause)
 local started=0
 record(function()
  if L.RevealRunning then started+=1;if started>=400 then L.RevealRunning=false end -- (longer than the drawing of both images: a worker that carried on would finish them first)
  elseif #drawn==0 and waits==10 then L.RevealRunning=true end -- (a reveal begins 10 pauses into the first image)
 end)
 Art.Request({'glow','halo'})
 local during=0;for _,d in ipairs(drawn)do if d.Running then during+=1 end end
 check(#drawn==2 and during==0,'B1: nothing is drawn while a reveal runs (images finished: '..names_()..'; drawn during it: '..during..')')
 check(started>=400,'B1: the worker waited out the reveal ('..started..' pauses while it ran)')
 L.RevealRunning=false;Art.SliceSeconds=sliceWas
 -- a reveal already running when the request comes: the worker waits first
 record(function()if L.RevealRunning then started+=1;if started>=60 then L.RevealRunning=false end end end);started=0;L.RevealRunning=true
 Art.Request({'glow'});check(#drawn==1 and not drawn[1].Running and started>=30,'B1: a request made during a reveal is drawn after it ('..started..' pauses)')
 L.RevealRunning=false
 -- a reveal flag that never clears does not stop the drawing for ever
 record();L.RevealRunning=true;Art.Request({'glow'});check(#drawn==1,'B1: a stuck reveal flag is given up on after '..Art.MaxRevealWaits..' pauses (the image is drawn)');L.RevealRunning=false
 -- B1: the slice of work a frame: 4 ms, 2 ms on tier 2
 local get=B.Get
 B.Get=function()return 3 end;check(Art.Slice()==.004,'B1: tier 3: a 4 ms slice ('..Art.Slice()..')')
 B.Get=function()return 2 end;check(Art.Slice()==.002,'B1: tier 2: a 2 ms slice ('..Art.Slice()..')')
 B.Get=function()return 1 end;check(Art.Slice()==.004,'(tier 1 draws nothing at all; the slice is the default)')
 B.Get=get
 -- B4: the warm-up (15 s after the client starts) is the planets and the seed's halo, only once no reveal is running; the rest is drawn when a scene asks
 check(table.concat(Art.WarmOrder,',')=='glow,halo,planet_gas,planet_rock,planet_ring','B4: the warm-up list is the seed halo and the three planets ('..table.concat(Art.WarmOrder,',')..')')
 record();L.RevealRunning=true
 check(Art.Warm(1)==true,'B4: Warm schedules')
 R.advance(1.5);check(#drawn==0,'B4: a reveal is running when the warm-up is due: nothing is drawn')
 R.advance(Art.WarmRetry*2);check(#drawn==0,'B4: ... and it keeps waiting while the reveal runs')
 L.RevealRunning=false;R.advance(Art.WarmRetry+.5)
 local got={};for _,d in ipairs(drawn)do got[d.Name]=true end
 check(#drawn==5 and got.glow and got.halo and got.planet_gas and got.planet_rock and got.planet_ring,'B4: idle again: the warm-up draws the planets and the seed halo only ('..names_()..')')
 check(Art.Get('nebula_rose')==nil and Art.Get('starmap')==nil and Art.Get('runes')==nil and Art.Get('carpet')==nil,'B4: the nebulas, the star map, the runes and the palace art wait until a scene asks')
 sc=Scenes.Build(7,{});check(Art.Get('nebula_rose')=='ready'and Art.Get('starmap')=='ready','B4: ... and a story scene draws what it needs');sc:Destroy()
 -- B4: the warm-up does not start when quality dropped to low in the meantime
 record();Art.Warm(1);X.lowFx=true;R.advance(2);check(#drawn==0,'B4: low quality by the time it is due: nothing is drawn');X.lowFx=false
 Art.Reset();hooks(true)
end
-- 2. the stages with and without images -------------------------------------------------------------------------------------------------
local caps={[6]={80,55},[7]={95,55},[8]={190,125}}
local function stageChecks(withArt)
 local tag=withArt and'with images'or'without images'
 for rank=6,8 do for _,lite in ipairs({false,true})do
  local sc=Scenes.Build(rank,{Lite=lite});local cap=caps[rank][lite and 2 or 1];local t=names[rank]..(lite and' lite'or'')..' '..tag
  check(sc.Count<=cap and sc.Lights<=4,t..': '..sc.Count..' parts (<= '..cap..'), '..sc.Lights..' lights')
  local cast=false;for _,d in ipairs(sc.Folder:GetDescendants())do if d:IsA('BasePart')and d.CastShadow then cast=true end end
  check(not cast,t..': no part casts a shadow')
  local n=arts(sc.Folder)
  if withArt then check(n>0 and n==sc.Images,t..': '..n..' images') else check(n==0,t..': no image') end
  for _,d in ipairs(sc.Folder:GetDescendants())do
   if d:GetAttribute('RarePullArt')then
    local host=d.Parent;if host and(host:IsA('BillboardGui')or host:IsA('SurfaceGui'))then host=host.Parent end
    if not check(host and host:IsA('BasePart')and host:IsDescendantOf(sc.Folder),t..': image '..d.Name..' sits on a part of the stage')then break end
   end
  end
  if rank==6 then
   if withArt then check(sc.Runes and count(sc.Folder,'Rune circle')==1 and count(sc.Folder,'Floor seam')==0,t..': the rune circle under the pack (no seams)')
   else check(count(sc.Folder,'Rune circle')==0 and count(sc.Folder,'Floor seam')==(lite and 4 or 8),t..': the R151 neon seams instead') end
   local strips=0;for _,p in ipairs(sc.Plates)do if p:FindFirstChild('Plate inlay')then strips+=1 end end
   check(strips==(lite and 0 or #sc.Plates),t..': the lock plates\' inlays are on the plates ('..strips..')')
  elseif rank==7 then
   local textured=0;for _,p in ipairs(sc.Planets)do if p.Art then textured+=1 end end
   if withArt then
    check(textured==3 and count(sc.Folder,'Planet atmosphere')==0,t..': the three planets are textured spheres with atmospheres')
    local neb,onWall=0,true;for _,a in pairs(sc.NebulaArt)do neb+=1;local wall=a.Gui and a.Gui.Parent;if not(wall and wall.Name=='Wall back')then onWall=false end
     local img=a.Image;local top=img.Position.Y.Scale-img.Size.Y.Scale/2;local bottom=img.Position.Y.Scale+img.Size.Y.Scale/2;if top<0 or bottom>1 then onWall=false end end
    check(neb==(lite and 3 or 5)and #sc.Nebula==0,t..': every nebula is a cloud of gas ('..neb..'), no neon disc')
    check(onWall,t..': painted wholly on the far wall (a cloud cut by the floor or a wall showed a hard edge)')
   else
    check(textured==0 and count(sc.Folder,'Planet atmosphere')==3 and count(sc.Folder,'Planet ring')==1,t..': plain planets with an atmosphere shell, the third ringed')
    local mats={};for _,p in ipairs(sc.Planets)do mats[p.Body.Material.Name]=true end
    check(not mats.SmoothPlastic,t..': each of a material with its own texture (not plain plastic)')
   end
  else
   local carpet=sc.Folder:FindFirstChild('Carpet')
   if withArt then
    check(carpet and carpet:FindFirstChild('Art carpet')~=nil,t..': a woven carpet')
    check(count(sc.Folder,'Art banner')==count(sc.Folder,'Banner')and count(sc.Folder,'Art glass')==count(sc.Folder,'Window'),t..': every banner and window is dressed')
   end
   check(sc.CarryBeam and sc.CrownBeam and getmetatable(sc.CarryBeam)==Fx.BeamClass and sc.BeamLight==sc.CrownBeam.Light,t..': the carry / crown beams are the layered beam, the crown\'s has the light')
   check(count(sc.Folder,'Carry beam')==1 and sc.Folder:FindFirstChild('Crown beam')~=nil,t..': in the stage')
  end
  sc:Destroy()
  check(sc.Folder.Parent==nil,t..': destroyed')
 end end
end
drawAll(true);stageChecks(true)
drawAll(false);stageChecks(false)
do -- low quality: the images are not used even when ready
 drawAll(true);X.lowFx=true
 local sc=Scenes.Build(7,{Lite=true});check(arts(sc.Folder)==0,'low quality: plain planets even with the images ready');sc:Destroy();X.lowFx=false
end
-- 3. anchoring in the story scenes (with the images) -------------------------------------------------------------------------------------
drawAll(true)
local emitted={}
for rank=6,8 do
 reset()
 local base=set(fxIn(W.workspace))
 local run=start(rank);local tl=run.TL;local tag=names[rank]..' Full'
 local stray,unhooked,haloFar,haloFront,burstOff,carryOff,crownOff={}, {},0,0,nil,0,0
 local carryShown,crownShown,haloSeen,bursted=false,false,false,false
 local sc
 X.run(tl.Length+.3,1/60,function()
  local st=stage();sc=run.Scene or sc
  local t=run.Done and math.huge or run.Clock()
  for _,d in ipairs(fxIn(W.workspace))do
   if not base[d]then
    local okC=(st and d:IsDescendantOf(st))or d:IsDescendantOf(X.char)
    if not okC then stray[d.Name]=true end
    if d.ClassName=='Beam'then
     local a0,a1=d.Attachment0,d.Attachment1
     if not(a0 and a1 and a0.Parent and a0.Parent:IsA('BasePart')and a1.Parent and a1.Parent:IsA('BasePart')and st and a0:IsDescendantOf(st)and a1:IsDescendantOf(st))then unhooked[d.Name]=true end
    elseif d.ClassName=='ParticleEmitter'or d.ClassName=='PointLight'then
     local p=d.Parent;if not(p and(p:IsA('BasePart')or p.ClassName=='Attachment'))then unhooked[d.Name]=true end
    elseif d.ClassName=='BillboardGui'or d.ClassName=='SurfaceGui'then
     local host=d.Adornee or d.Parent
     if not(host and host:IsA('BasePart')and st and host:IsDescendantOf(st))then unhooked[d.Name]=true end
    end
   end
  end
  if not(st and sc and not sc.Destroyed)then return end
  local origin=sc.Origin
  -- the seed's halo: just behind the seed, from the camera
  if sc.HaloAnchor and sc.SeedHalo and t>=tl.Climax+.1 and t<tl.Back then
   local sd=st:FindFirstChild('RarePullSeed');local c=sd and L.VisibleBounds(sd)
   if c then
    haloSeen=true
    local h=sc.HaloAnchor.Position;haloFar=math.max(haloFar,math.abs((h-c).Magnitude-1.1))
    local eye=cam.CFrame.Position;if(h-eye).Magnitude<=(c-eye).Magnitude then haloFront+=1 end
   end
  end
  -- the burst at the pack, on the hit
  if t>=tl.Climax and not bursted then
   bursted=true
   local pack=(origin*sc.PackCF).Position
   burstOff=sc.Burst.Fired and sc.Burst.Attachment.Parent==sc.FlashPart and(sc.FlashPart.Position-pack).Magnitude or math.huge
  end
  if rank==8 then
   if t>=tl.SceneIn+.05 and t<tl.Glide then
    local pack=(origin*sc.PackCF).Position;local a=sc.CarryBeam.Anchor.Position
    carryOff=math.max(carryOff,math.abs(a.X-pack.X)+math.abs(a.Z-pack.Z));if sc.CarryBeam:Visible()then carryShown=true end
   end
   if t>=tl.CrownStart+.45 and t<tl.Climax then
    local throne=(origin*CF(L.Points[8].Pack)).Position;local a=sc.CrownBeam.Anchor.Position
    crownOff=math.max(crownOff,math.abs(a.X-throne.X)+math.abs(a.Z-throne.Z));if sc.CrownBeam:Visible()then crownShown=true end
   end
  end
 end)
 local function keys(s)local o={};for k in pairs(s)do o[#o+1]=k end;table.sort(o);return table.concat(o,', ')end
 check(next(stray)==nil,tag..': every effect is in the stage (strays: '..keys(stray)..')')
 check(next(unhooked)==nil,tag..': every beam / emitter / light / image hangs on a part or attachment of the stage ('..keys(unhooked)..')')
 check(haloSeen and haloFar<.3 and haloFront==0,tag..': the seed\'s halo follows it, just behind it ('..string.format('%.2f',haloFar)..' off, '..haloFront..' frames in front)')
 check(burstOff and burstOff<.05,tag..': the hit\'s burst (flash, sparks, smoke) fires at the pack on the hit ('..tostring(burstOff)..')')
 if rank==8 then
  check(carryShown and carryOff<.05,tag..': the gold carry beam shines on the pack as it glides in, its foot under the pack ('..string.format('%.3f',carryOff)..')')
  check(crownShown and crownOff<.05,tag..': the crown beam stands on the throne while the crown comes down')
 end
 check(sc and sc.Destroyed and sc.Folder.Parent==nil,tag..': the stage and its effects are gone at the end')
 local leftover=0;for _,d in ipairs(fxIn(W.workspace))do if not base[d]and not d:IsDescendantOf(X.char)then leftover+=1 end end
 check(leftover==0,tag..': no effect left behind ('..leftover..')')
 local n=0;for _,d in ipairs(sc.Folder:GetDescendants())do if d.ClassName=='ParticleEmitter'then n+=(d._emitted or 0)end end
 emitted[rank]=n
end
-- 4. the sky beam -------------------------------------------------------------------------------------------------------------------------
for tier=1,3 do
 local B=Fx.Budget[tier];local tag='sky beam, tier '..tier
 local folder=R.new('Folder');folder.Name='BeamTest';folder.Parent=W.workspace
 local b=Fx.Beam({Parent=folder,Name='Light beam',Ground=V3(10,0,20),Height=140,Width=2.5,Color=R.Color3.fromRGB(170,120,255),Land=1,Descent=.16,Hold=1.5,Fade=1,Tier=tier,Cracks=true})
 -- (the shockwaves: two smooth image rings from tier 2 when the halo image is drawn - it is, here; otherwise rings of segments)
 local ringsOk=(tier>=2 and b.RingArt~=nil and #b.RingArt==2 and #b.Ring==0)or(tier==1 and b.RingArt==nil and #b.Ring==B.Ring)
 check(#b.Streaks==B.Streaks and(b.Haze~=nil)==B.Haze and ringsOk and #b.Debris==B.Debris and #b.Cracks==B.Cracks,tag..': '..(3+B.Streaks-(B.Haze and 0 or 1))..' layers, '..(b.RingArt and'2 image rings'or(#b.Ring..' ring pieces'))..', '..#b.Debris..' debris, '..#b.Cracks..' cracks (its budget)')
 local beams=0;local ok=true
 for _,d in ipairs(folder:GetDescendants())do
  if d.ClassName=='Beam'then beams+=1;if not(d.Attachment0 and d.Attachment1 and d.Attachment0.Parent==b.Anchor and d.Attachment1.Parent==b.Anchor)then ok=false end
  elseif d.ClassName=='ParticleEmitter'or d.ClassName=='PointLight'then if not d:IsDescendantOf(b.Anchor)then ok=false end end
 end
 check(ok and beams==2+B.Streaks+(B.Haze and 1 or 0),tag..': every layer between attachments of its anchor, every emitter / light on it')
 local early,accel,lastFoot,lastSpeed,landedAt,ringEarly,ringSeen,impactAfter=false,true,nil,nil,nil,false,false,false
 local lastRing
 for i=0,math.floor(5*60)do
  local t=i/60;b:Update(t)
  local a=t-1
  if a<-.16-1e-6 and b:Visible()then early=true end
  if a>=-.16 and a<0 then
   local foot=b.Foot.Position.Y
   if lastFoot then local sp=lastFoot-foot;if sp<=0 or(lastSpeed and sp<lastSpeed-1e-6)then accel=false end;lastSpeed=sp end
   lastFoot=foot
  end
  if b.Landed and not landedAt then landedAt=t end
  local shown=b:RingShown()
  if shown and a<0 then ringEarly=true end
  if shown and a>=0 and a<.6 then ringSeen=true end
  if a>2.3 then local cf=(b.RingArt and b.RingArt[1].Part or b.Ring[1]).CFrame;if lastRing and lastRing~=cf then impactAfter=true end;lastRing=cf end
 end
 check(not early,tag..': nothing before it starts coming down')
 check(accel,tag..': its foot falls faster and faster (a slam, not a slide)')
 check(landedAt and landedAt>=1-1e-9 and landedAt<1+1/60+1e-9,tag..': it lands on its beat ('..tostring(landedAt)..' s)')
 check(b.Dust._emitted==B.Dust and b.Sparks._emitted==B.Sparks,tag..': dust and sparks kicked up once ('..tostring(b.Dust._emitted)..', '..tostring(b.Sparks._emitted)..')')
 check(not ringEarly and ringSeen,tag..': the shockwave rings come with the landing')
 check(not impactAfter,tag..': the ground pieces are no longer touched after the impact (no per-frame work)')
 check(not b:Visible()and not b.Core.Enabled and not b.GlowBeam.Enabled and not b.Embers.Enabled and b.Light.Brightness==0,tag..': gone after its fade')
 b:Destroy();check(folder:FindFirstChild('Light beam')==nil and pcall(b.Update,b,6),tag..': Destroy removes it all; an update after it does nothing')
 folder:Destroy()
end
do -- late landing (camera came near after it): no dust burst out of nowhere
 local folder=R.new('Folder');folder.Parent=W.workspace
 local b=Fx.Beam({Parent=folder,Ground=V3(0,0,0),Land=1,Tier=3});b:Update(1.8)
 check((b.Dust._emitted or 0)==0,'a beam first updated well after its landing kicks up no dust');b:Destroy();folder:Destroy()
end
do -- the world effect of someone else's pull: the beam stands at their feet as they walk
 local Players=W.service('Players')
 local p=R.new('Player');p.Name='Walker';p.UserId=301;p.Parent=Players
 local c=R.new('Model');c.Name='Walker';c.Parent=W.workspace;p.Character=c
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(20,3,90);root.Parent=c
 local t2=R.new('Part');t2.Name='UpperTorso';t2.Size=V3(2,2,1);t2.CFrame=CF(20,5,90);t2.Parent=c
 local hum=R.new('Humanoid');hum.Health=100;hum.HipHeight=2;hum.Parent=c
 for rank=6,8 do
  reset();cam.CFrame=CF(20,8,110)
  local e=World.Begin(p,c,rank,W.workspace:GetServerTimeNow());local beam=e.Beam
  local off,stray,shown=0,false,false
  X.run(e.TL.PillarEnd+.2,1/60,function(now)
   -- (where the puller stood this frame; then they walk on before the next)
   if e.Beam and not e.Beam.Destroyed then
    local g=World.Ground(c);off=math.max(off,(e.Beam.Anchor.Position-g).Magnitude)
    if e.Beam:Visible()then shown=true end
    for _,d in ipairs(fxIn(W.workspace))do if(d.ClassName=='Beam'or d.ClassName=='ParticleEmitter')and d:IsDescendantOf(W.workspace:FindFirstChild('_RarePullWorld'))and not d:IsDescendantOf(e.Folder)then stray=true end end
   end
   root.CFrame=CF(20+math.sin(now*2)*3,3,90+math.cos(now*2)*3)
  end)
  check(shown and off<1e-3,names[rank]..' onlooker: the sky beam stands at the puller\'s feet as they walk ('..string.format('%.4f',off)..')')
  check(not stray,names[rank]..' onlooker: all of it in that puller\'s effect')
  World.Stop(p)
  local left=0;for _,d in ipairs(fxIn(W.workspace))do if d:IsDescendantOf(W.workspace:FindFirstChild('_RarePullWorld')or W.workspace)and d.Name:match('^Beam')then left+=1 end end
  check(beam.Destroyed and e.Beam==nil and left==0,names[rank]..' onlooker: the beam is gone once it has faded (the afterglow stays), none left')
 end
 p.Parent=nil;c:Destroy()
end
-- 5. clean-up ---------------------------------------------------------------------------------------------------------------------------
for rank=6,8 do
 for _,when in ipairs({'skip early','skip late','abort','death','destroyed','second pack'})do
  reset()
  local base=set(fxIn(W.workspace))
  local run=start(rank);local tl=run.TL;local tag=names[rank]..' '..when
  local sc
  if when=='skip early'then X.run(tl.SkipFrom+.1);sc=run.Scene;M.Skip();X.run(tl.Length+.5)
  elseif when=='skip late'then X.run(tl.Rise+.2);sc=run.Scene;M.Skip();X.run(tl.Length+.5)
  elseif when=='abort'then X.run(tl.SceneIn+.6);sc=run.Scene;M.Abort('test')
  elseif when=='death'then X.run(tl.SceneIn+.6);sc=run.Scene;X.hum.Died:Fire();X.run(.1)
  elseif when=='destroyed'then X.run(tl.SceneIn+.6);sc=run.Scene;local holder=R.new('LocalScript');M.Bind(holder);holder.Destroying:Fire()
  else
   X.run(tl.SceneIn+1);sc=run.Scene
   local second=start(rank==8 and 7 or rank+1);X.run(.1)
   local stages=0;for _,c in ipairs(W.workspace:GetChildren())do if c.Name=='_RarePullStage'then stages+=1 end end
   check(stages<=1 and(sc==nil or sc.Destroyed),tag..': the first stage and its beams go at once ('..stages..' stages)')
   M.Abort('test')
  end
  X.run(.3)
  check(sc==nil or(sc.Destroyed and sc.Folder.Parent==nil),tag..': the stage is destroyed')
  if sc and sc.CarryBeam then check(sc.CarryBeam.Folder.Parent==nil and sc.CrownBeam.Folder.Parent==nil,tag..': with its beams')end
  local left={};for _,d in ipairs(fxIn(W.workspace))do if not base[d]and not d:IsDescendantOf(X.char)then left[#left+1]=d.Name end end
  check(#left==0,tag..': no beam / emitter / light / image left ('..table.concat(left,', ')..')')
 end
end
do -- a Legendary / Mythic flourish's beam goes with its pack
 for rank=4,5 do
  local holder=R.new('Model');holder.Parent=W.workspace
  local f=Flourish.Create(holder,rank,1,{Suspense=true})
  local early,shown=false,false
  for i=0,120 do local t=i/60;f:Update(CF(0,5,0),t,1,true);if t<1-.12-.03 and f.Pillar:Visible()then early=true end;if t>1.1 and t<1.5 and f.Pillar:Visible()then shown=true end end
  check(not early and shown,names[rank]..': the flourish\'s beam comes down onto the burst')
  check(f.Pillar.Anchor.Position.Y==5,names[rank]..': on the bag\'s mouth')
  f:Destroy();X.run(.05)
  check(#fxIn(holder)==0,names[rank]..': and is gone with its pack')
  holder:Destroy()
 end
end
-- 6. smoothness at 30 and 60 fps ---------------------------------------------------------------------------------------------------------
-- a pop: one frame's step much bigger than both neighbours' (and visible); a kink: one frame's change of velocity much bigger than both
-- neighbours' (a sudden start or stop of a moving thing)
local function mag(x)return type(x)=='number'and math.abs(x)or x.Magnitude end
local function spikes(series,floor,ratio)
 local out={}
 for i=2,#series-1 do
  local d0,d1,d2=series[i-1],series[i],series[i+1]
  if d1>floor and d1>ratio*math.max(d0,d2)then out[#out+1]=i end
 end
 return out
end
local function analyse(track,dt,popFloor,kinkFloor)
 -- track: list of segments, each a list of {T, P}; returns pops, kinks (times)
 local pops,kinks={},{}
 for _,seg in ipairs(track)do
  local steps,vel={},{}
  for i=2,#seg do steps[i-1]=mag(seg[i].P-seg[i-1].P);vel[i-1]=(seg[i].P-seg[i-1].P)/dt end
  for _,i in ipairs(spikes(steps,popFloor,3))do pops[#pops+1]=seg[i+1].T end
  local acc={};for i=2,#vel do acc[i-1]=mag(vel[i]-vel[i-1])end
  for _,i in ipairs(spikes(acc,kinkFloor,3))do kinks[#kinks+1]=seg[i+1].T end
 end
 return pops,kinks
end
local function tracker()
 local tr={Segs={},Open=nil}
 function tr.add(t,p)if p==nil then tr.Open=nil;return end;if not tr.Open then tr.Open={};tr.Segs[#tr.Segs+1]=tr.Open end;tr.Open[#tr.Open+1]={T=t,P=p}end
 function tr.at(t)for _,s in ipairs(tr.Segs)do for _,f in ipairs(s)do if math.abs(f.T-t)<1e-4 then return f.P end end end;return nil end
 return tr
end
local function fmt(list)local o={};for i=1,math.min(5,#list)do o[i]=string.format('%.3f',list[i])end;return table.concat(o,', ')..(#list>5 and' ...'or'')end
local recorded={}
local function record(p,dt)
 reset();drawAll(true)
 if p.Reduced then W.Gui.ReducedMotionEnabled=true end
 if p.Keeper then X.keeper(V3(10,3,100),{GuardianBehavior='WANDER'})end
 local run=start(p.Rank);local tl=run.TL
 local tr={Pack=tracker(),Seed=tracker(),Crown=tracker(),Eye=tracker(),Look=tracker(),Fov=tracker(),Card=tracker(),CardSize=tracker(),Halo=tracker()}
 local gui=X.pg:FindFirstChild('RarePullReveal');local view=gui and X.find(gui,'Seed');local scale=view and view:FindFirstChildOfClass('UIScale')
 local cutTimes={}
 if run.Kind=='Scene'then for _,k in ipairs(L.Shots[p.Rank][tl.Variant=='Calm'and'Calm'or'Full'])do if k.Cut then cutTimes[#cutTimes+1]=(tl[k.Beat]or 0)+(k.Offset or 0)end end end
 local function nearCut(t)for _,c in ipairs(cutTimes)do if t>=c-dt-1e-6 and t<c+dt+1e-6 then return true end end;return false end
 X.run(tl.Length+.2,dt,function()
  if run.Done then for _,x in pairs(tr)do x.add(0,nil)end;return end
  local t=run.Clock();local st=stage();local sc=run.Scene
  local inStage=st and sc and not sc.Destroyed and t>=tl.SceneIn and t<tl.Back
  -- the pack while it is whole (the Secret's glitches are meant to jump)
  local glitch=false;if p.Rank==6 then for _,g in ipairs({'Glitch1','Glitch2'})do local a=t-(tl[g]or -9);if a>=-dt and a<.22+dt then glitch=true end end end
  tr.Pack.add(t,(inStage and t<tl.Climax-dt and not glitch and sc.PackCF)and sc.PackCF.Position or nil)
  local sd=inStage and st:FindFirstChild('RarePullSeed')
  tr.Seed.add(t,(sd and t>=tl.Climax+.1)and sd:GetPivot().Position or nil)
  if p.Rank==8 and inStage and t>=tl.CrownStart and t<tl.Climax-dt then
   local sum,n=V3(0,0,0),0;for _,d in ipairs(st:GetChildren())do if d.Name=='Crown band'then sum=sum+d.CFrame.Position;n+=1 end end
   tr.Crown.add(t,n>0 and sum/n or nil)
  else tr.Crown.add(t,nil)end
  -- the camera in the stage (not across a cut; not in the hit's shake, which is meant to shake)
  local camOk=inStage and t>=tl.SceneIn and not nearCut(t)and not(t>=tl.Climax-dt and t<tl.Climax+.5+dt)
  tr.Eye.add(t,camOk and cam.CFrame.Position or nil);tr.Look.add(t,camOk and cam.CFrame.LookVector*10 or nil)
  tr.Fov.add(t,(camOk or(not inStage and(run.Kind=='Ladder'or t<(tl.SceneIn or math.huge)-.1)))and cam.FieldOfView or nil)
  -- the card's seed (screen heights)
  if view and view.Parent and view.Visible and t>=(tl.Burst or tl.Climax)+.21 then tr.Card.add(t,view.Position.Y.Scale);tr.CardSize.add(t,scale and scale.Scale or 1)
  else tr.Card.add(t,nil);tr.CardSize.add(t,nil)end
  local halo=gui and X.find(gui,'Seed halo')
  tr.Halo.add(t,(halo and halo.Visible)and halo.Position.Y.Scale or nil)
 end)
 return tr,tl
end
local presentations={}
for rank=1,5 do presentations[#presentations+1]={Rank=rank,Tag=names[rank]..' card'}end
for rank=6,8 do
 presentations[#presentations+1]={Rank=rank,Tag=names[rank]..' Full'}
 presentations[#presentations+1]={Rank=rank,Tag=names[rank]..' Calm',Reduced=true}
 presentations[#presentations+1]={Rank=rank,Tag=names[rank]..' InPlace',Keeper=true}
end
local floors={Pack={.03,1.5},Seed={.03,1.5},Crown={.03,1.5},Eye={.04,2},Look={.01,.6},Fov={.08,6},Card={.004,.25},CardSize={.01,.6},Halo={.004,.25}}
local smoothRuns=0
for _,p in ipairs(presentations)do
 local res={}
 for _,dt in ipairs({1/30,1/60})do
  local tr,tl=record(p,dt);res[dt]=tr
  local tag=p.Tag..' @'..math.floor(1/dt+.5)..'fps'
  for key,tk in pairs(tr)do
   local fl=floors[key];local pops,kinks=analyse(tk.Segs,dt,fl[1]*(dt*60),fl[2])
   local n=0;for _,s in ipairs(tk.Segs)do n+=#s end
   if n>2 then
    check(#pops==0,tag..': '..key..' never jumps ('..#pops..' pops at '..fmt(pops)..')')
    check(#kinks==0,tag..': '..key..' never starts or stops in one frame ('..#kinks..' kinks at '..fmt(kinks)..')')
   end
  end
  smoothRuns+=1
 end
 -- the same place at the same moment at 30 and at 60 fps (everything is driven by the one clock)
 local worst,what=0,''
 for key,tk in pairs(res[1/30])do
  for _,s in ipairs(tk.Segs)do for _,f in ipairs(s)do
   local q=res[1/60][key].at(f.T)
   if q then local d=mag(q-f.P);if d>worst then worst,what=d,key..string.format(' at %.3f',f.T)end end
  end end
 end
 check(worst<2e-3,p.Tag..': the same picture at 30 and 60 fps (largest difference '..string.format('%.5f',worst)..' '..what..')')
end
-- 7. budgets per tier -------------------------------------------------------------------------------------------------------------------
do
 local caps2={[6]=160,[7]=180,[8]=220}
 for rank=6,8 do check(emitted[rank]and emitted[rank]<=caps2[rank],names[rank]..': '..tostring(emitted[rank])..' particles emitted by the stage in one presentation (<= '..caps2[rank]..')')end
 for tier=1,3 do
  local B=Fx.Budget[tier]
  local layers=2+B.Streaks+(B.Haze and 1 or 0)
  check(layers<=({4,6,7})[tier]and B.Dust+B.Sparks<=({16,32,52})[tier],'tier '..tier..': '..layers..' beam layers, '..(B.Dust+B.Sparks)..' particles at a landing')
 end
 check(Fx.Budget[1].Streaks<Fx.Budget[3].Streaks and not Fx.Budget[1].Haze and Fx.Budget[1].Debris==0,'low quality drops the haze, the debris and two streaks')
end
print(('R152 look checks %d, fails %d (%d smoothness runs)'):format(checks,fails,smoothRuns))
if fails>0 then error('failures')end
