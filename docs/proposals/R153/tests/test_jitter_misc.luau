--!nocheck
-- R153 jitter, the rest, on the mock with the REAL scripts / modules:
--  1. VerityVoice: her hop follows a smoothed level (Bounce: a critically damped follower of Level). With a noisy PlaybackLoudness that changes
--     every few frames (what the engine gives), Bounce moves on every drawn frame at 30 / 60 / 144 fps with a far smaller frame-to-frame jolt than
--     Level, stays inside 0..1 and settles exactly at 0; VerityClient draws her body and her portrait from it;
--  2. HeldHarvests: a held fruit's joints and effects are stepped on every drawn frame (20 Hz before), from RenderStepped;
--  3. SeedPackClient: a loose / held seed's aura is updated on every drawn frame (30 Hz before), from RenderStepped;
--  4. GUI: GuiShine's sweep (20 Hz before), GardenCardMotion's rarity borders (12 Hz before), OfflineGrowthNotice's rainbow (30 Hz before), the
--     shop's product previews (ShopViewport: 30 Hz before; every frame within a count cap by tier) and the other previews' loops (static);
--  5. InteractionFeedback: the garden upgrade button's press is drawn on the client every frame (the server only stamps it);
--  6. static: the per-frame connection of every fixed script is RenderStepped (no Heartbeat / Stepped for drawing); the server sets no decorative
--     motion per frame (its Heartbeat users are the gameplay services) and tweens no part.
local J=require('./jitter_world');local W,R=J.W,J.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local me=J.player('Me',7,true);local char=J.character(me,V3(0,3,0))
J.look(V3(8,8,-12),V3(0,3,0))

-- 1. Verity's hop ------------------------------------------------------------------------------------------------------------------------------------------
do
 local Voice=W.module('VerityVoice');local C=W.module('VerityConfig')
 for _,fps in ipairs({30,60,144})do
  local lip=Voice.NewLip(C.Lip);local dt=1/fps;local bounces,levels={},{}
  local loud,nextRead=0,0
  for i=1,math.floor(1.6*fps)do
   local t=i*dt
   -- syllables of ~.2 s with ~.12 s pauses; the engine's reading changes about 40 times a second and is noisy
   if t>=nextRead then nextRead=t+1/40;local syl=(t%.32)<.2;loud=syl and(380+160*(((i*7919)%13)/12))or 0 end
   Voice.Step(lip,C.Lip,loud,dt,true)
   bounces[#bounces+1]=Voice.Bounce(lip);levels[#levels+1]=lip.Level
  end
  local stalls=0;for i=2,#bounces do if bounces[i]==bounces[i-1]and bounces[i]>0 then stalls+=1 end end
  local function jolt(list)local w=0;for i=3,#list do w=math.max(w,math.abs(list[i]-2*list[i-1]+list[i-2]))end;return w end -- (the sharpest change of speed: a kink)
  local inside=true;for _,b in ipairs(bounces)do if b<0 or b>1 then inside=false end end
  check(stalls==0,string.format('Verity at %d fps: her hop moves on every drawn frame while she talks (%d repeated)',fps,stalls))
  print(string.format('INFO Verity at %d fps: sharpest change of speed %.3f (hop) against %.3f (the level it used to follow)',fps,jolt(bounces),jolt(levels)))
  if fps>=60 then check(jolt(bounces)<=.7*jolt(levels),string.format('Verity at %d fps: the hop\'s sharpest frame-to-frame change of speed is %.3f against the level\'s %.3f (no kinks: the buzz is gone)',fps,jolt(bounces),jolt(levels)))end -- (at 30 fps a frame is longer than the smoothing)
  check(inside,'Verity at '..fps..' fps: the hop stays inside 0..1')
  local n=0;while Voice.Moving(lip)and n<fps*3 do Voice.Step(lip,C.Lip,500,dt,false);n+=1 end
  check(lip.Level==0 and Voice.Bounce(lip)==0,string.format('Verity at %d fps: when the voice stops she settles exactly back down (%.2f s)',fps,n*dt))
 end
 local src=W.B.VerityClient
 check(src:find('VerityVoice.Pose(C,e.Size,VerityVoice.Bounce(lip))',1,true)~=nil and src:find('local level=still and 0 or VerityVoice.Bounce(voice.Lip)',1,true)~=nil,
  'VerityClient draws her body and her portrait from the smoothed Bounce')
end

-- 2. HeldHarvests ---------------------------------------------------------------------------------------------------------------------------------------------
do
 local steps={};local stepped=0
 W.stub('HeldHarvestRig',{Create=function(model,crop,index,handle)return {Model=model}end,Step=function(r,t)stepped+=1;steps[#steps+1]=t end,Apply=function()end,Follow=function()end,Destroy=function()end})
 W.stub('HarvestPresentation',{Build=function(item,opts)local m=R.new('Model');m.Name='Fruit';return m,{SeedId=item.SeedId},1 end})
 local tool=R.new('Tool');tool.Name='Apple';tool:SetAttribute('HarvestItemTool',true);tool:SetAttribute('SeedId','AppleSeed');tool:SetAttribute('FruitIndex',1)
 tool:SetAttribute('HarvestInventoryId','inv-1');tool:SetAttribute('Mutation','Gold')
 local h=R.new('Part');h.Name='Handle';h.CFrame=char.HumanoidRootPart.CFrame*CF(1,0,-1);h.Parent=tool;tool.Parent=char
 local sc=R.new('LocalScript');sc.Name='HeldHarvests';W.load('HeldHarvests',sc)
 J.run(.6,60)
 check(stepped>0,'HeldHarvests: the held fruit is rigged and stepped')
 for _,fps in ipairs({30,60,144})do
  local before=stepped;local first=#steps+1
  J.run(.5,fps)
  local frames=math.floor(.5*fps+.5);local advancing=true
  for i=first+1,#steps do if steps[i]<=steps[i-1]then advancing=false end end
  check(stepped-before==frames and advancing,string.format('HeldHarvests at %d fps: the fruit\'s joints / effects step on every drawn frame (%d steps in %d frames; 20 Hz before)',fps,stepped-before,frames))
 end
 local before=stepped;J.physicsOnly(12);check(stepped==before,'HeldHarvests: nothing is stepped in the physics half of a frame (RenderStepped)')
 sc:Destroy();tool:Destroy()
end

-- 3. SeedPackClient: a seed's aura ------------------------------------------------------------------------------------------------------------------------
do
 local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules')
 local updates={};local raw=Visuals.CreateSeedMotion
 Visuals.CreateSeedMotion=function(seed,parent,detailed)return {Update=function(self,frame,age)updates[#updates+1]=age end,Destroy=function()end}end
 local remotes=W.RS:FindFirstChild('ChestChaseRemotes')or R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 for _,n in ipairs({'SeedArt','SeedCatalog'})do local f=R.new('Folder');f.Name=n;f.Parent=remotes end
 W.service('Debris').AddItem=function()end;W.service('ContentProvider').PreloadAsync=function()end
 local seed=R.new('Model');seed.Name='LooseSeed';local p=R.new('Part');p.Name='Root';p.CFrame=CF(3,2,4);p.Parent=seed;seed.PrimaryPart=p
 seed:SetAttribute('SeedId','AppleSeed');seed.Parent=W.workspace;W.CS:AddTag(seed,Rules.SeedMotion.Tag)
 local ok,err=pcall(function()local sc=R.new('LocalScript');sc.Name='SeedPackClient';W.load('SeedPackClient',sc)end)
 if check(ok,'SeedPackClient loads on the mock: '..tostring(err))then
  J.run(.6,60)
  check(#updates>0,'SeedPackClient: the loose seed\'s aura runs')
  for _,fps in ipairs({30,60,144})do
   local first=#updates;J.run(.5,fps);local frames=math.floor(.5*fps+.5)
   local advancing=true;for i=first+2,#updates do if updates[i]<=updates[i-1]then advancing=false end end
   check(#updates-first==frames and advancing,string.format('SeedPackClient at %d fps: the seed\'s aura is updated on every drawn frame (%d updates in %d frames; 30 Hz before)',fps,#updates-first,frames))
  end
  local n=#updates;J.physicsOnly(12);check(#updates==n,'SeedPackClient: the aura is updated in RenderStepped only')
 end
 Visuals.CreateSeedMotion=raw;seed:Destroy()
end

-- 4. GUI -------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local sg=R.Instance.new('ScreenGui');sg.Name='Shop';sg.Parent=me.PlayerGui
 local Shine=W.module('GuiShine')
 for _,fps in ipairs({30,60,144})do
  local b=R.Instance.new('Frame');b.Name='Button';b.Size=R.UDim2.fromOffset(200,60);b.AbsoluteSize=R.Vector2.new(200,60);b.Parent=sg
  Shine.Attach(b,false);J.frame(1/fps)
  local sweep=b.SubtleShine.Sweep;local list=J.sample(fps,math.floor(1.2*fps),function()return sweep.Position end)
  check(J.stalls(list)==0,string.format('GuiShine at %d fps: the sweep crosses the button on every drawn frame (%d repeated; 20 Hz before)',fps,J.stalls(list)))
  b:Destroy()
 end
 local Theme=W.module('GardenTheme')
 local card=R.Instance.new('Frame');card.Name='Card';card.Size=R.UDim2.fromOffset(104,104);card.AbsoluteSize=R.Vector2.new(104,104);card.Parent=sg
 Theme.Corner(card,8);Theme.CardBorder(card,'King')
 local glow=card.RarityBorder.Glow.Line;local shine=card.AnimatedBorder.BorderShine
 J.everyFrame(check,'a King card border\'s radiant glow (12 Hz before)',1,nil,function()return {glow.Transparency,shine.Rotation}end)
 W.Gui.MenuOpened=W.Gui.MenuOpened or R.signal();W.Gui.MenuClosed=W.Gui.MenuClosed or R.signal();W.Gui.MenuIsOpen=false
 local sc=R.new('LocalScript');sc.Name='OfflineGrowthNotice';W.load('OfflineGrowthNotice',sc);W.Gui.MenuOpened:Fire()
 local notice=me.PlayerGui:FindFirstChild('OfflineGrowthNotice')
 local rainbow=notice and notice:FindFirstChild('Rainbow',true)
 if check(rainbow~=nil,'OfflineGrowthNotice: the rainbow title shows with the menu')then
  J.everyFrame(check,'the offline notice\'s rainbow slides (30 Hz before)',1,nil,function()return rainbow.Color end,nil,1e-9)
 end
 sc:Destroy()
 -- the shop's turning product previews (ShopViewport): every frame on tier 3 (30 Hz before), 4 turn on phones (tier 2), none on tier 1
 local Shop=W.module('ShopViewport');local views={}
 for i=1,6 do local v=R.Instance.new('ViewportFrame');v.Name='Preview'..i;v.AbsoluteSize=R.Vector2.new(140,140);v.Parent=sg;views[i]=v
  Shop.Attach(v,{Id='AuroraTrail',Type='Trail',Color={R=200,G=200,B=200}},'Forest')end
 local function cams()local t={};for i,v in ipairs(views)do t[i]=v.CurrentCamera.CFrame end;return t end
 J.everyFrame(check,'the shop\'s product previews turn (tier 3)',1,nil,cams)
 for _,tier in ipairs({2,1})do
  J.tier=tier;local before=cams();J.run(.5,60);local after=cams();local turning=0
  for i=1,#views do if not J.same(before[i],after[i])then turning+=1 end end
  check(turning==(tier==2 and 4 or 0),string.format('ShopViewport tier %d: %d of 6 previews turn (%d expected: a preview redraws whenever it moves)',tier,turning,tier==2 and 4 or 0))
  if tier==2 then
   local list=J.sample(60,30,function()local t={};for i,v in ipairs(views)do t[i]=v.CurrentCamera.CFrame end;return t end)
   local moving=0;for i=1,#views do local s=0;for k=2,#list do if J.same(list[k][i],list[k-1][i])then s+=1 end end;if s==0 then moving+=1 end end
   check(moving==4,'ShopViewport tier 2: the 4 that turn do it on every drawn frame ('..moving..')')
  end
 end
 J.tier=3;for _,v in ipairs(views)do v:Destroy()end
 sg:Destroy()
end

-- 5. The upgrade button press, drawn on the client --------------------------------------------------------------------------------------------------------
do
 local remotes=W.RS:FindFirstChild('ChestChaseRemotes')or R.new('Folder');remotes.Name='ChestChaseRemotes';remotes.Parent=W.RS
 if not remotes:FindFirstChild('PackTaken')then local e=R.new('RemoteEvent');e.Name='PackTaken';e._props.OnClientEvent=R.signal();e.Parent=remotes end
 W.stub('InteractionAudio',{Play=function()end})
 local cap=R.new('Part');cap.Name='Treadmill button';cap.Size=V3(9.6,.55,9.6);local home=CF(0,1,20);cap.CFrame=home;cap:SetAttribute('PressHome153',home);cap.Parent=W.workspace
 W.CS:AddTag(cap,'GardenUpgradeCap153')
 local sc=R.new('LocalScript');sc.Name='InteractionFeedback';W.load('InteractionFeedback',sc)
 for _,fps in ipairs({30,60,144})do
  cap:SetAttribute('PressedAt153',R.clock)
  local ys=J.sample(fps,math.floor(.28*fps),function()return cap.CFrame.Position.Y end)
  local deepest=math.huge;for _,y in ipairs(ys)do deepest=math.min(deepest,y)end
  local stalls=0;for i=2,#ys do if ys[i]==ys[i-1]and not(math.abs(ys[i]-(1-.35))<1e-9)then stalls+=1 end end -- (it holds at the bottom from .10 s to .12 s by design)
  check(stalls==0 and math.abs(deepest-(1-.35))<1e-6,string.format('the upgrade button press at %d fps: sinks .35 studs and comes back on every drawn frame (%d repeated outside the hold)',fps,stalls))
  J.run(.1,fps);check(J.same(cap.CFrame,home),'... and is back home after the press ('..fps..' fps)')
 end
 sc:Destroy();cap:Destroy()
end

-- 6. Static: per-frame connection sites, the server ----------------------------------------------------------------------------------------------------
do
 local B=W.B
 local drawers={ItemCosmetics='Run.RenderStepped:Connect',RunnerTrailClient='RunService.RenderStepped:Connect',RunnerTrailAura='RunService.RenderStepped:Connect',
  HeldHarvests='Run.RenderStepped:Connect',HomeMarker='Run.RenderStepped:Connect',SeedPackClient='RunService.RenderStepped:Connect',GardenVisuals='RunService.RenderStepped:Connect',
  LavaFlow='Run.RenderStepped:Connect',VeiledEventClient81='watch(Run.RenderStepped',HubDisplayClient='Run.RenderStepped:Connect(step)',VoidGiveawayClient152='Run.RenderStepped:Connect(frame)',
  InteractionFeedback='Run.RenderStepped:Connect(pressStep)',BeastAnimation='Run.RenderStepped:Connect'}
 for name,site in pairs(drawers)do check(B[name]and B[name]:find(site,1,true)~=nil,name..' draws in RenderStepped')end
 check(B.ItemCosmetics:find('Heartbeat',1,true)==nil and B.RunnerTrailClient:find('Heartbeat',1,true)==nil and B.HeldHarvests:find('Run.Heartbeat',1,true)==nil
  and B.HomeMarker:find('Run.Heartbeat',1,true)==nil and B.RunnerTrailAura:find('Heartbeat:Connect',1,true)==nil,'the fixed followers have no Heartbeat connection left')
 check(B.HubDisplayClient:find('itemHz=ITEM_HZ ',1,true)~=nil,'HubDisplayClient: the showcase item turns every frame on every tier')
 check(B.VoidGiveawayClient152:find('or inView(entry)then',1,true)~=nil,'VoidGiveawayClient152: in view the pack steps every frame on every tier')
 check(B.GuiShine:find('Run.RenderStepped:Connect',1,true)~=nil and B.GardenCardMotion:find('Run.RenderStepped:Connect',1,true)~=nil,'GuiShine / GardenCardMotion draw in RenderStepped')
 check(B.CollectionViewport:find('connection=Run.RenderStepped:Connect',1,true)~=nil and B.CollectionViewport:find('elapsed',1,true)==nil,'CollectionViewport: the index cards\' seeds and weather effects every frame (20 Hz before)')
 check(B.HarvestPresentation:find('connection=RunService.RenderStepped:Connect',1,true)~=nil and B.HarvestPresentation:find('elapsed',1,true)==nil,'HarvestPresentation: the fruit previews every frame (20 Hz before)')
 check(B.PackViewport89:find('if clock<',1,true)==nil and B.HarvestViewport:find('Run.RenderStepped:Connect(step)',1,true)~=nil,'PackViewport89 / HarvestViewport: every frame in RenderStepped')
 check(B.KeeperSpeedLabels:find("entry.Gui.Adornee=Follow and Follow.Get(model)or root",1,true)~=nil,'KeeperSpeedLabels hangs the sign on the smoothed body\'s anchor')
 check(B.PlantGrowthFx:find('Tick%2',1,true)==nil,'PlantGrowthFx: a flying fruit\'s size is written every frame')
 check(B.RunnerTrailArt:find('colors[(i+1)%n+1]',1,true)~=nil,'RunnerTrailArt.Cycle flows into the next colour (the Aurora halo snapped)')
 -- the server: no part tweened, and per-frame (Heartbeat / Stepped) only in the gameplay services
 local S=B.GardenUpgradeService
 check(S:find('TweenService',1,true)==nil and S:find("cap:SetAttribute('PressedAt153'",1,true)~=nil,'GardenUpgradeService: the press is stamped, not tweened on the server')
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
