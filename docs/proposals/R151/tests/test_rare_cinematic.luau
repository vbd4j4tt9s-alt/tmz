--!nocheck
-- R151 pull reveals, part 2: the REAL RarePullCinematic (director) with RarePullScenes, RarePullCard, RarePullAudio, RarePullRules and
-- AudioMixer / SoundTiming on the Roblox mock: each story scene played through frame by frame, every exit path, the variants.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local function noop()end
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Audio=W.module('RarePullAudio');local Sounds=W.module('RarePullSounds')
local Visuals=W.module('SeedPackVisuals')
local cam=W.workspace.CurrentCamera;local Run=W.Run
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local effects=Mixer.Group('Effects')
local function voices(slot)local out={};for _,s in ipairs(E.sounds)do if s.Name:match('^RarePull_'..(slot or''))and s.Parent then out[#out+1]=s end end;return out end
local function anyPlaying()for _,s in ipairs(voices())do if s.IsPlaying then return s.Name end end;return nil end
local baseCamera
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear()
 cam=W.workspace.CurrentCamera
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 X.player:SetAttribute('RarePullPreview',nil)
 R.advance(4) -- (the previous presentation ended long ago)
 baseCamera=X.camera()
end
local function packFor(rank,seedId)
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p'..rank,Stage=2},nil)
 local spec=W.module('SeedPackRules').SeedDesignById[seedId]
 tool.ToolTip='Desert Seed Pack\nSomething: 1/2\n'..(spec and spec.name or seedId)..': 1/'..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
 return bag,tool
end
local function start(rank,extra)
 local seedId=X.byRank[rank];local bag,tool=packFor(rank,seedId)
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Tool=tool,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info),bag
end
local function hudShown()return X.hud.Main.Enabled and X.hud.Hotbar.Enabled end
local function stage()return W.workspace:FindFirstChild('_RarePullStage')end
local function restoredAll(tag,opts)
 opts=opts or{}
 local c=X.camera()
 check(c.Type==baseCamera.Type and c.CFrame==baseCamera.CFrame and c.Fov==baseCamera.Fov and c.Subject==baseCamera.Subject and c.Focus==baseCamera.Focus,tag..': the camera is restored exactly (type, CFrame, focus, FieldOfView, subject)')
 check(hudShown()and X.hud.Menu.Enabled==false and X.hud.Touch.Enabled,tag..': the HUD is back; a GUI that was already off stays off; the touch controls were never touched')
 check(X.core.PlayerList==true and X.core.Chat==true and X.core.Backpack==false,tag..': Core GUI restored (and the Backpack, already off, left off)')
 check(X.controls.Enabled,tag..': movement is back')
 check(cam:FindFirstChild('RarePullGrade')==nil and cam:FindFirstChild('RarePullBlur')==nil,tag..': the colour grade and blur are gone')
 check(stage()==nil,tag..': the hidden stage is destroyed')
 check(X.pg:FindFirstChild('RarePullReveal')==nil,tag..': the reveal GUI is gone')
 check(W.rsBound[M.BindName]==nil and W.actions[M.SkipAction]==nil,tag..': no render step or skip binding left')
 check(X.player:GetAttribute('RarePullCinematic')==nil and X.player:GetAttribute('RarePullClimaxAt')==nil,tag..': the announcement attributes are cleared')
 if not opts.result then check(anyPlaying()==nil,tag..': every reveal sound is stopped ('..tostring(anyPlaying())..')')end
 local same,key=X.same(X.base,X.lighting());check(same,tag..': Lighting untouched ('..tostring(key)..')')
end
X.base=X.lighting()
local renderBefore=X.live(Run.RenderStepped)
-- 1. each story scene, start to end ------------------------------------------------------------------------------------------------------
local budgets={[6]=150,[7]=200,[8]=320} -- the stage incl. the pack, the seed and the seed's own rarity aura (backdrop budgets: test below)
for rank=6,8 do
 reset();E.resetPlays()
 local disables=X.controls.Disables
 local run,bag=start(rank)
 local tag=names[rank]..' Full'
 check(run and run.Kind=='Scene'and run.Variant=='Full',tag..': a safe player gets the full story scene')
 local tl=run.TL;local t0=R.clock
 local log={hudHidden=true,coreOff=true,controlsHeld=true,lightingSame=true,grade=false,switchAt=nil,backAt=nil,maxParts=0,nearStage=true,titleAt=nil,oddsFinalOk=nil,skipHint=nil,blurSeen=false}
 local final='1 in '..({'2','4','16','60','400','5K','83.3K','1.67B'})[rank]
 X.run(tl.Length+.4,1/30,function(now)
  local t=now-t0
  if not M.Active()then return end
  if t<tl.Back-.05 then
   if hudShown()then log.hudHidden=false end
   if X.core.PlayerList~=false then log.coreOff=false end
   if X.controls.Enabled then log.controlsHeld=false end
  end
  if cam:FindFirstChild('RarePullGrade')then log.grade=true end
  if cam:FindFirstChild('RarePullBlur')then log.blurSeen=true end
  if cam.CameraType==R.Enum.CameraType.Scriptable and not log.switchAt then log.switchAt=t end
  if log.switchAt and not log.backAt and cam.CameraType~=R.Enum.CameraType.Scriptable then log.backAt=t end
  if cam.CameraType==R.Enum.CameraType.Scriptable and(cam.CFrame.Position-L.StageOrigin).Magnitude>120 then log.nearStage=false end
  local st=stage();if st then local n=0;for _,d in ipairs(st:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;log.maxParts=math.max(log.maxParts,n)end
  local gui=X.pg:FindFirstChild('RarePullReveal');local title=gui and X.find(gui,'Title')
  if title and title.TextTransparency<.5 and not log.titleAt then log.titleAt=t end
  local odds=gui and X.find(gui,'Odds')
  if odds and t>tl.Odds+.05 and t<tl.FloatEnd-.1 and log.oddsFinalOk==nil then log.oddsFinalOk=odds.Text==final;log.oddsText=odds.Text end
  local hint=gui and X.find(gui,'Skip hint');if hint and hint.Visible and not log.skipHint then log.skipHint=t end
  -- the real seed model on screen near the end of its float: the share of the screen height its visible box takes, and where
  if not log.seedShot and t>=tl.FloatEnd-.1 and t<tl.FloatEnd then
   local st=stage();local sd=st and st:FindFirstChild('RarePullSeed')
   local c,size;if sd then c,size=L.VisibleBounds(sd)end
   if c then
    local eye=cam.CFrame.Position;local tgt=eye+cam.CFrame.LookVector*10;local lo,hi=1,0;local xs={}
    for _,k in ipairs({{-1,-1,-1},{1,-1,-1},{-1,1,-1},{1,1,-1},{-1,-1,1},{1,-1,1},{-1,1,1},{1,1,1}})do
     local _,y=L.Project(eye,tgt,cam.FieldOfView,1280/720,c+V3(size.X*k[1],size.Y*k[2],size.Z*k[3])*.5)
     if y then lo=math.min(lo,y);hi=math.max(hi,y)end
    end
    local x,y=L.Project(eye,tgt,cam.FieldOfView,1280/720,c)
    log.seedShot={Top=lo,Bottom=hi,X=x,Y=y}
   end
  end
  local same=X.same(X.base,X.lighting());if not same then log.lightingSame=false end
 end)
 check(M.Active()==nil,tag..': it ends by itself ('..string.format('%.1f',tl.Length)..' s)')
 check(log.hudHidden and log.coreOff and log.controlsHeld,tag..': HUD, Core GUI and movement are held for the whole scene')
 check(X.controls.Disables==disables+1,tag..': movement held once')
 check(log.grade and log.lightingSame,tag..': the colour grade lives on the Camera; Lighting is never written')
 check(log.blurSeen,tag..': a short blur on the fades (desktop)')
 check(log.switchAt and near(log.switchAt,tl.SceneIn-.05,.07),tag..': the camera cuts to the stage while the screen is black ('..tostring(log.switchAt)..' s)')
 check(log.backAt and near(log.backAt,tl.Back,.07),tag..': and back to the player at '..tostring(log.backAt)..' s')
 check(log.nearStage,tag..': the camera only looks at the hidden stage')
 check(log.maxParts>20 and log.maxParts<=budgets[rank],tag..': '..log.maxParts..' parts (budget '..budgets[rank]..')')
 check(log.titleAt and near(log.titleAt,tl.Climax,.1),tag..': the title appears on the hit ('..tostring(log.titleAt)..')')
 check(log.oddsFinalOk,tag..': "'..final..'" after its count-up ('..tostring(log.oddsText)..')')
 check(log.skipHint and log.skipHint>=tl.SkipFrom-.05,tag..': the skip hint appears from '..tl.SkipFrom..' s')
 do local sh=log.seedShot;local lay=L.Layout(false,false,rank)
  check(sh and sh.Bottom-sh.Top>=.30 and sh.Bottom-sh.Top<=.5,tag..': the real seed fills the end shot ('..(sh and string.format('%.0f%%',(sh.Bottom-sh.Top)*100)or'-')..' of the height, its visible box)')
  check(sh and math.abs(sh.X-.5)<.05 and math.abs(sh.Y-.5)<.06,tag..': centred ('..(sh and string.format('%.3f, %.3f',sh.X,sh.Y)or'-')..')')
  check(sh and sh.Top>=lay.Title.Y+lay.Title.H/2-.005 and sh.Bottom<=lay.Odds.Y-lay.Odds.H/2+.005,tag..': and clear of the title and "1 in N" ('..(sh and string.format('%.3f-%.3f',sh.Top,sh.Bottom)or'-')..' vs '..string.format('%.3f-%.3f',lay.Title.Y+lay.Title.H/2,lay.Odds.Y-lay.Odds.H/2)..')')
 end
 -- the sounds: routed to Effects, on the beat
 local vs=voices();local routed=#vs>0
 for _,v in ipairs(vs)do if v.SoundGroup~=effects then routed=false end end
 check(routed,tag..': '..#vs..' reveal voices, all on the Effects group')
 local hitSlot=rank==7 and'CosmicBoom_1'or'Impact_1' -- (Cosmic's big hit is its supernova boom)
 local impact=voices(hitSlot)[1];local hitAt=impact and impact.PlayLog[#impact.PlayLog]and impact.PlayLog[#impact.PlayLog].At
 check(hitAt and near(hitAt-t0,tl.Climax,.05),tag..': the big hit ('..hitSlot..') plays on the hit ('..tostring(hitAt and hitAt-t0)..' s)')
 local slam=voices('TitleSlam_1')[1];local slamAt=slam and slam.PlayLog[1]and slam.PlayLog[#slam.PlayLog].At
 check(slamAt and near(slamAt-t0,tl.Odds,.05),tag..': TitleSlam on the "1 in N" slam')
 local stacked=false;for _,v in ipairs(vs)do if v.Plays>(v.Stops or 0)+1 then stacked=true end end
 check(not stacked,tag..': no voice ever plays over itself (a replay stops it first)')
 restoredAll(tag)
 check(X.live(Run.RenderStepped)<=renderBefore+1,tag..': no per-frame work left after the end (RenderStepped listeners '..X.live(Run.RenderStepped)..', before '..renderBefore..'; +1 = the aura of the world module)')
 bag:Destroy()
end
-- backdrop budgets, desktop and phone / low quality
do local S=W.module('RarePullScenes')
 for rank=6,8 do for _,lite in ipairs({false,true})do
  local sc=S.Build(rank,{Lite=lite});local cap=({[6]={80,55},[7]={95,55},[8]={190,125}})[rank][lite and 2 or 1]
  check(sc.Count<=cap and sc.Lights<=4,names[rank]..(lite and' lite'or'')..': backdrop '..sc.Count..' parts (<= '..cap..'), '..sc.Lights..' lights')
  local cast=false;for _,d in ipairs(sc.Folder:GetDescendants())do if d:IsA('BasePart')and d.CastShadow then cast=true end end
  check(not cast,names[rank]..': no part casts a shadow');sc:Destroy()
 end end
end
-- 2. skip ----------------------------------------------------------------------------------------------------------------------------------
reset();E.resetPlays()
do
 local run=start(8);local tl=run.TL;local t0=R.clock
 X.run(1.0)
 check(M.Skip()==false,'King: no skip before '..tl.SkipFrom..' s')
 X.run(1.5)
 local button=X.find(X.pg,'Backdrop')
 check(button and button:GetAttribute('ButtonHighlight')==false and button:GetAttribute('ButtonSound')==false,'the tap-anywhere skip is silent and unhighlighted')
 button.Activated:Fire()
 X.run(.1)
 local t=run.Clock()
 check(near(t,tl.Climax,.12),'King: a tap after '..tl.SkipFrom..' s jumps straight to the hit ('..string.format('%.2f',t)..' s)')
 local impact=voices('Impact_1')[1]
 check(impact and impact.PlayLog[#impact.PlayLog]and R.clock-impact.PlayLog[#impact.PlayLog].At<.2,'King: the hit\'s Impact plays on the skip')
 X.run(.6)
 check(W.actions[M.SkipAction]~=nil,'Space / Enter / A / B skip too (bound while the scene runs)')
 W.actions[M.SkipAction](M.SkipAction,R.Enum.UserInputState.Begin)
 X.run(.05)
 check(near(run.Clock(),tl.FloatEnd,.1),'King: a second skip goes to the way out')
 X.run(tl.Length-tl.FloatEnd+.3)
 check(M.Active()==nil,'King: skipped run ends')
 restoredAll('after skip')
end
-- 3. every other exit path ----------------------------------------------------------------------------------------------------------------
local function midScene(rank,how,tag,expectResult)
 reset();E.resetPlays()
 local run=start(rank);local tl=run.TL
 X.run(tl.SceneIn+.6)
 check(cam.CameraType==R.Enum.CameraType.Scriptable,tag..': (in the scene)')
 how(run)
 X.run(.3)
 local active=M.Active()
 if expectResult then
  check(active and active.Kind=='Result',tag..': the player still sees what they got (a compact result card)')
  check(cam.CameraType==R.Enum.CameraType.Custom and hudShown()and X.controls.Enabled and stage()==nil,tag..': the world is back at once')
  X.run(3)
 else check(active==nil,tag..': it stops at once') end
 check(M.Active()==nil,tag..': nothing left running')
 restoredAll(tag)
end
midScene(7,function(run)run.Scene.Update=function()error('boom')end end,'error in a frame',true)
midScene(8,function()X.hum.Died:Fire()end,'death')
midScene(6,function()X.player.CharacterRemoving:Fire(X.char)end,'character removed')
midScene(7,function()X.root.CFrame=CF(0,3,140)end,'moved / teleported',true)
midScene(8,function()X.keeper(V3(10,3,170),{TargetUserId=7,GuardianBehavior='CHASING'})end,'a keeper starts chasing',true)
midScene(6,function()X.keeper(V3(20,3,100),{GuardianBehavior='GUARDING'})end,'a keeper walks up (20 studs)',true)
do -- a replaced camera: the old one is not written back over the new one
 reset();local run=start(7);X.run(run.TL.SceneIn+.5)
 local old=W.workspace.CurrentCamera;local new=R.new('Camera');new.CameraType=R.Enum.CameraType.Custom;new.FieldOfView=70;new.CFrame=CF(1,2,3);new.Parent=W.workspace
 W.workspace.CurrentCamera=new;X.run(.2)
 check(M.Active()==nil or M.Active().Kind=='Result','a replaced camera stops the scene')
 check(new.CFrame.Position==V3(1,2,3)and new.CameraType==R.Enum.CameraType.Custom,'the new camera is left alone')
 check(hudShown()and X.controls.Enabled and stage()==nil,'HUD, movement and stage restored after the camera change')
 X.run(3);W.workspace.CurrentCamera=old;old.CameraType=R.Enum.CameraType.Custom;new:Destroy()
end
do -- the script that started it is destroyed
 reset();local holder=R.new('LocalScript');holder.Name='PackOpeningFeedback';M.Bind(holder)
 local run=start(8);X.run(run.TL.SceneIn+.4)
 holder.Destroying:Fire();X.run(.1)
 check(M.Active()==nil,'script destroyed: the scene stops');restoredAll('script destroyed')
end
-- 4. the variants -------------------------------------------------------------------------------------------------------------------------
do -- ReducedMotion: the Calm scene - still shots (cuts only), no shake, no blur, shorter
 reset();W.Gui.ReducedMotionEnabled=true
 local run=start(8);local tl=run.TL;local t0=R.clock
 check(run.Kind=='Scene'and run.Variant=='Calm','ReducedMotion: the Calm scene')
 local moved,blur,lastPos,lastT=0,false,nil,nil
 local cuts={tl.SceneIn,tl.Climax}
 X.run(tl.Length+.3,1/30,function(now)
  local t=now-t0
  if cam:FindFirstChild('RarePullBlur')then blur=true end
  if cam.CameraType==R.Enum.CameraType.Scriptable then
   local p=cam.CFrame.Position
   if lastPos and(p-lastPos).Magnitude>1e-6 then local isCut=false;for _,c in ipairs(cuts)do if math.abs(t-c)<.07 then isCut=true end end;if not isCut then moved+=1 end end
   lastPos=p
  end
 end)
 check(moved==0,'ReducedMotion: the camera never moves inside a shot (cuts only; '..moved..' moving frames)')
 check(not blur,'ReducedMotion: no blur')
 check(tl.Length<L.Timeline(8,'Full').Length-2,'ReducedMotion: shorter ('..tl.Length..' s)')
 check(X.controls.Enabled and hudShown(),'ReducedMotion: restored');restoredAll('ReducedMotion')
end
do -- phone: lighter stage, gentle shake, no blur
 reset();W.UIS.TouchEnabled=true;W.UIS.KeyboardEnabled=false
 local run=start(8);local tl=run.TL
 check(run.Lite and run.Phone,'phone: the light version')
 local parts,blur=0,false
 X.run(tl.Length+.3,1/30,function()
  local st=stage();if st then local n=0;for _,d in ipairs(st:GetDescendants())do if d:IsA('BasePart')then n+=1 end end;parts=math.max(parts,n)end
  if cam:FindFirstChild('RarePullBlur')then blur=true end
 end)
 check(parts>20 and parts<=200,'phone: King stage '..parts..' parts (<= 200 with the pack, the seed and its aura)')
 check(not blur,'phone: no blur (no stacked post-processing)')
 restoredAll('phone')
end
do -- unsafe: the in-place version (no camera, no stage, HUD and movement untouched)
 local cases={{'a keeper is near',function()X.keeper(V3(25,3,100),{})end},{'on the track',function()
   local motion=W.RS:FindFirstChild('RunnerMotion');motion:SetAttribute('TrackBoundaryZ',50);motion:SetAttribute('TrackCenterX',0);motion:SetAttribute('TrackHalfWidth',90)end},
  {'a menu is open',function()X.pg:SetAttribute('SeedMenu','Bag')end},{'in the air',function()X.state=R.Enum.HumanoidStateType.Freefall end}}
 for _,case in ipairs(cases)do
  reset();case[2]()
  local writes=X.coreWrites;local disables=X.controls.Disables
  local run=start(7);local tl=run.TL
  check(run.Kind=='InPlace',case[1]..': the in-place version ('..tostring(run.Why)..')')
  local scriptable,hudOff,stageSeen,titleSeen,compactOk=false,false,false,false,true
  X.run(tl.Length+.3,1/30,function()
   if cam.CameraType==R.Enum.CameraType.Scriptable then scriptable=true end
   if not hudShown()then hudOff=true end
   if stage()then stageSeen=true end
   local gui=X.pg:FindFirstChild('RarePullReveal');local title=gui and X.find(gui,'Title')
   if title and title.TextTransparency<.5 then titleSeen=true;local _,y,_,h=X.rect(title,1280,720);if(y+h)/720>.5 then compactOk=false end end
  end)
  check(not scriptable and not hudOff and not stageSeen,case[1]..': no camera, HUD stays, no hidden stage')
  check(X.coreWrites==writes and X.controls.Disables==disables,case[1]..': Core GUI and movement untouched')
  check(titleSeen and compactOk,case[1]..': the compact title shows in the upper half')
  restoredAll(case[1])
  X.pg:SetAttribute('SeedMenu',nil);local motion=W.RS:FindFirstChild('RunnerMotion');if motion then motion:SetAttribute('TrackBoundaryZ',nil)end
 end
end
-- 5. the Common..Mythic seed card ---------------------------------------------------------------------------------------------------------
for rank=1,5 do
 reset();E.resetPlays()
 local run,bag=start(rank);local tl=run.TL;local t0=R.clock
 check(run.Kind=='Ladder'and not run.Quick,names[rank]..': the seed card (not quick)')
 local before,at,seedSeen,fovMin,final,edge=false,false,false,70,nil,nil
 X.run(tl.Length+.3,1/30,function(now)
  local t=now-t0;local gui=X.pg:FindFirstChild('RarePullReveal');local title=gui and X.find(gui,'Title')
  if title and t<tl.Burst-.03 and title.TextTransparency<.99 then before=true end
  if title and t>tl.Burst+.15 and t<tl.Out and title.TextTransparency<.2 then at=true end
  local view=gui and X.find(gui,'Seed');if view and view.Visible and view.ImageTransparency<.5 then seedSeen=true end
  fovMin=math.min(fovMin,cam.FieldOfView)
  local odds=gui and X.find(gui,'Odds');if odds and t>tl.Odds+.05 and t<tl.Out then final=odds.Text end
  local e=gui and X.find(gui,'Edge Top');if e and t>tl.Burst-.06 and t<tl.Burst-.01 then edge=e.BackgroundColor3 end
 end)
 check(not before and at,names[rank]..': the title waits for the burst, then shows')
 check(seedSeen,names[rank]..': the seed itself (its model) is the centre of the card')
 check(final=='1 in '..({'2','4','16','60','400'})[rank],names[rank]..': "1 in N" ('..tostring(final)..')')
 check((rank>=4)==(fovMin<69.9),names[rank]..': '..(rank>=4 and'a short camera push'or'no camera push')..' (FieldOfView down to '..string.format('%.1f',fovMin)..')')
 check(edge and math.abs(edge.R-L.Tiers[rank].Hint.R)<.02 and math.abs(edge.G-L.Tiers[rank].Hint.G)<.02,names[rank]..': the screen edges end the suspense in the tier colour')
 check(M.Active()==nil and near(cam.FieldOfView,70),names[rank]..': ends and the FieldOfView is back')
 restoredAll(names[rank]..' card')
 bag:Destroy()
end
do -- R153: packs opened back to back play in full every time (R151 made them quick); the short version is the player's own setting
 reset()
 local first,bag1=start(1);X.run(first.TL.Length+.2)
 local second,bag2=start(2)
 check(not second.Quick and not L.IsQuick(bag2)and second.TL.Length==L.CardTimeline(2).Length,'R153: a pack opened right after the last reveal plays in full (and the world pack knows it)')
 X.run(.5);local third,bag3=start(3)
 check(not third.Quick and third.TL.Length==L.CardTimeline(3).Length,'R153: one opened while the last card is still up plays in full too')
 X.run(third.TL.Length+.2);restoredAll('back to back')
 X.player:SetAttribute('SettingSkipCutscenes',true);reset()
 local fourth,bag4=start(2)
 check(fourth.Quick and L.IsQuick(bag4)and fourth.TL.Length<L.CardTimeline(2).Length,'R153: with "Skip pack animations" on: the short version ('..string.format('%.2f',fourth.TL.Length)..' s)')
 X.run(fourth.TL.Length+.2);restoredAll('skip pack animations')
 X.player:SetAttribute('SettingSkipCutscenes',nil)
 R.advance(5);local fifth,bag5=start(2);check(not fifth.Quick,'R153: and off again, the full suspense');M.Abort('test')
 for _,b in ipairs({bag1,bag2,bag3,bag4,bag5})do b:Destroy()end
 -- with the setting on, Secret / Cosmic / King: the result card in place, never the story scene
 X.player:SetAttribute('SettingSkipCutscenes',true);reset()
 local short,bag6=start(8)
 check(short.Kind=='InPlace'and short.Why=='skip pack animations is on','R153: with "Skip pack animations" on, King plays the in-place result card ('..tostring(short.Kind)..')')
 X.run(short.TL.Length+.2);restoredAll('King short');bag6:Destroy()
 X.player:SetAttribute('SettingSkipCutscenes',nil);reset()
 local preview=M.Start({Rank=8,SeedId=X.byRank[8],At=W.workspace:GetServerTimeNow(),Preview=true})
 check(preview and preview.Kind=='Scene','R153: an owner preview is the full scene ('..tostring(preview and preview.Kind)..')');M.Abort('test')
end
do -- R153: every card can be skipped by the player (R151 / R152: only the story scenes): the hint, the jump to the hit, the close
 for _,c in ipairs({{3,false},{5,false},{7,true}})do
  reset();if c[2]then X.keeper(V3(25,3,100),{})end
  local run,bag=start(c[1]);local tl=run.TL;local hit=tl.Climax or tl.Burst;local tag='R153 '..names[c[1]]..(c[2]and' in place'or' card')
  X.run(tl.SkipFrom-.1);check(M.Skip()==false,tag..': no skip before '..tl.SkipFrom..' s')
  X.run(.3)
  local hint=X.find(X.pg,'Skip hint')
  check(hint and hint.Visible and hint.TextTransparency<1,tag..': the skip hint shows')
  check(M.Skip()and near(run.Clock(),hit-.02,.01),tag..': a skip jumps straight to the hit')
  check(W.actions[M.SkipAction]==nil and X.find(X.pg,'Backdrop')==nil and X.controls.Enabled and hudShown(),tag..': nothing is taken from the player (no full-screen button, no bound keys, the HUD and movement stay)')
  X.run(L.ShownAt(tl)-run.Clock()+.1)
  check(M.Skip(),tag..': a second skip once the result is shown closes it')
  X.run(tl.Length-tl.FloatEnd+.2)
  check(M.Active()==nil,tag..': gone');restoredAll(tag);bag:Destroy()
 end
end
-- 6. owner previews and sound slots --------------------------------------------------------------------------------------------------------
do
 reset();local holder=R.new('LocalScript');M.Bind(holder)
 X.player:SetAttribute('RarePullPreview','rarepull:king:1');X.run(.1)
 local run=M.Active();check(run and run.Rank==8 and run.Info.Preview,'/test rarepull king plays the King reveal with a demo seed')
 M.Abort('test');X.run(.1)
 X.player:SetAttribute('RarePullPreview','raresound:Riser:2');X.run(.2)
 local riser=voices('Riser_1')[1];check(riser and riser.IsPlaying,'/test raresound Riser plays that slot')
 X.run(7);check(anyPlaying()==nil,'and stops by itself')
 holder.Destroying:Fire()
end
do -- the owner's uploads: on the beat, from their measured lead-in; a pending slot keeps its fallback; an id set later drops straight in
 reset();E.resetPlays()
 local run=start(8);local tl=run.TL;local t0=R.clock;X.run(tl.Climax+.2)
 local v=voices('Impact_1')[1];local log=v and v.PlayLog[#v.PlayLog]
 check(v and v.SoundId=='rbxassetid://133616032782359'and #Audio.Layers('Impact')==1,'Impact is the owner\'s "cinematic impact hit"')
 check(log and near(log.At-t0,tl.Climax,.05)and near(log.TimePosition,Sounds.Get('Impact').Hit-Audio.Attack,1e-3)and v.SoundGroup==effects,'it plays on the hit from just before its measured hit (R152: .100 s less the attack, on the frame of the hit), on Effects')
 local g=voices('GroundImpact_1')[1];local gl=g and g.PlayLog[#g.PlayLog]
 check(g and g.SoundId=='rbxassetid://130581466623902'and gl and near(gl.At-t0,tl.Climax,.05),'the owner\'s ground impact under it')
 local r=voices('Riser_1')[1];local rl=r and r.PlayLog[#r.PlayLog]
 local cueAt,cueUntil;for _,c in ipairs(L.SceneCues(8,tl))do if c.Slot=='Riser'then cueAt,cueUntil=c.At,c.Until end end
 check(r and r.SoundId=='rbxassetid://126242461105018'and rl and near(rl.TimePosition-(rl.At-t0-cueAt),.128+math.max(0,2.67-(cueUntil-cueAt)),.002),
  'the owner\'s riser is entered late so its peak lands ON the silence ('..string.format('%.2f',rl and rl.TimePosition or -1)..' s into the file)')
 check(r and not r.IsPlaying,'and is cut by the silence')
 M.Abort('test')
 check(#Audio.Layers('SecretDrone')==2,'a slot still waiting for its upload plays its layered fallback')
 W.RS:FindFirstChild('RarePullSounds'):SetAttribute('SecretDroneId',123456)
 local layers=Audio.Layers('SecretDrone');check(#layers==1 and layers[1].Id=='rbxassetid://123456','an id set by the owner (attribute SecretDroneId) replaces the fallback')
 E.resetPlays();run=start(6);tl=run.TL;t0=R.clock;X.run(.3)
 local b=voices('SecretDrone_1')[1];local bl=b and b.PlayLog[#b.PlayLog]
 check(b and b.SoundId=='rbxassetid://123456'and bl and near(bl.At-t0,0,.05)and b.Looped,'and plays on the same beat (a loop from the start)')
 M.Abort('test');W.RS:FindFirstChild('RarePullSounds'):SetAttribute('SecretDroneId',nil)
 check(#Audio.Layers('SecretDrone')==2,'clearing it brings the fallback back')
 -- Secret: the owner's glitch as short bursts on every glitch beat and a longer one on the hit; the vault door on the unlock, silent in the silence
 reset();E.resetPlays();run=start(6);tl=run.TL;t0=R.clock
 local glitchLen,vaultInSilence={},false
 local g=nil
 X.run(tl.Climax+1.5,1/30,function(now)
  local t=now-t0;g=g or voices('SecretGlitch_1')[1];local v=voices('SecretVault_1')[1]
  if v and v.IsPlaying and t>tl.Silence+.02 and t<tl.Climax-.01 then vaultInSilence=true end
  if g then local n=#g.PlayLog;if g.IsPlaying then glitchLen[n]=(glitchLen[n]or 0)+1/30 end end
 end)
 local starts={};for _,l in ipairs(g and g.PlayLog or{})do starts[#starts+1]=l.At-t0 end
 check(g and g.SoundId=='rbxassetid://84688488729958'and g.PlaybackRegionsEnabled and #starts==4 and near(starts[2],tl.Glitch1,.05)and near(starts[3],tl.Glitch2,.05)and near(starts[4],tl.Climax,.05),
  'Secret: the owner\'s glitch on .25 s, both glitch beats and the hit ('..#starts..' plays)')
 check((glitchLen[2]or 9)<=.5 and(glitchLen[3]or 9)<=.55 and(glitchLen[4]or 0)>=1.0,'each glitch beat is a short burst, the hit a longer one ('..string.format('%.2f / %.2f / %.2f s',glitchLen[2]or-1,glitchLen[3]or-1,glitchLen[4]or-1)..')')
 local vault=voices('SecretVault_1')[1];local vl=vault and vault.PlayLog[#vault.PlayLog]
 check(vault and vault.SoundId=='rbxassetid://102739931931289'and vl and near(vl.At-t0,tl.Unlock,.05)and near(vl.TimePosition,Sounds.Get('SecretVault').Hit-Audio.Attack,.002),'Secret: the owner\'s vault door on the unlock, its first clunk on the beat (R152: from its measured hit)')
 check(not vaultInSilence,'and it is silent in the silence before the hit')
 M.Abort('test')
 -- Cosmic: the owner's supernova boom is the hit (no Impact), its tail rings under the seed; the bed is a slice that leaves the silence clear
 reset();E.resetPlays();run=start(7);tl=run.TL;t0=R.clock
 local padInSilence=false
 X.run(tl.Climax+1.5,1/30,function(now)local t=now-t0;local pad=voices('CosmicPad_1')[1];if pad and pad.IsPlaying and t>tl.Silence+.02 and t<tl.Climax-.01 then padInSilence=true end end)
 local boom=voices('CosmicBoom_1')[1];local bl2=boom and boom.PlayLog[#boom.PlayLog];local imp=voices('Impact_1')[1]
 check(boom and boom.SoundId=='rbxassetid://75435110351652'and bl2 and near(bl2.At-t0,tl.Climax,.05)and boom.IsPlaying,'Cosmic: the owner\'s supernova on the hit, still ringing 1.5 s later')
 check(not imp or #imp.PlayLog==0,'Cosmic: no Impact on top of it')
 local pad=voices('CosmicPad_1')[1];check(pad and pad.SoundId=='rbxassetid://120548831466483'and pad.PlaybackRegionsEnabled and not padInSilence,'Cosmic: the music bed is a slice that drops out for the silence')
 local star=voices('CosmicStar_1')[1];check(star and star.SoundId=='rbxassetid://100732233406279'and #star.PlayLog>=3,'Cosmic: the owner\'s shine as the planets lock into line')
 M.Abort('test')
 local sp=W.module('RarePullSounds').Get('Sparkle');check(sp.Region and sp.Region[2]-sp.Region[1]<=1.6,'the long shimmer plays as a ~1.5 s slice (PlaybackRegion)')
 local spv=voices('Sparkle_1')[1];check(spv and spv.PlaybackRegionsEnabled==true and near(spv.PlaybackRegion.Min,sp.Region[1]),'its voice plays only that slice')
 -- King: the owner's fanfare as the crown lands (cut by the silence) and again on the hit; the bell as it settles; the choir as a slice
 reset();E.resetPlays()
 run=start(8);tl=run.TL;t0=R.clock
 local fan=nil;local inSilence=false
 X.run(tl.Climax+.3,1/30,function(now)
  local t=now-t0;fan=fan or voices('KingFanfare_1')[1]
  if fan and t>tl.Silence+.03 and t<tl.Climax-.01 and fan.IsPlaying then inSilence=true end
 end)
 local plays={};for _,l in ipairs(fan and fan.PlayLog or{})do plays[#plays+1]=l.At-t0 end
 check(fan and fan.SoundId=='rbxassetid://77199097157197'and #plays==2 and near(plays[1],tl.CrownOn,.05)and near(plays[2],tl.Climax,.05),
  'King: the owner\'s fanfare as the crown lands on the pack and again on the hit ('..table.concat((function()local o={};for _,p in ipairs(plays)do o[#o+1]=string.format('%.2f',p)end;return o end)(),', ')..')')
 check(not inSilence,'King: the fanfare drops out for the silence before the hit')
 local bell=voices('KingBell_1')[1];local bl=nil -- (R152: two voices per slot, the toll as the hall opens may still ring on the first)
 for _,v in ipairs(voices('KingBell_1'))do for _,l in ipairs(v.PlayLog)do if near(l.At-t0,tl.CrownOn,.05)then bl=l end end end
 check(bell and bell.SoundId=='rbxassetid://110440649150958'and bl,'King: the owner\'s church bell as the crown settles')
 local choir=voices('KingChoir_1')[1]
 check(choir and choir.SoundId=='rbxassetid://71607900050825'and choir.PlaybackRegionsEnabled and near(choir.PlaybackRegion.Max,6.0)and not choir.Looped,'King: the owner\'s choir plays a 6 s slice of its swell (not all 18 s, not looped)')
 M.Abort('test')
end
do -- Effects 0 mutes the reveal
 Mixer.Set('Effects',0);check(effects.Volume==0,'Effects 0: the group every reveal voice is on is silent');Mixer.Set('Effects',100)
end
do -- the bonus-roll hook: a Secret result's sting is one-shot and on Effects
 E.resetPlays();check(Audio.Sting(6)==true and Audio.Sting(5)==false,'the bonus roll Secret sting')
 local g=voices('SecretGlitch_1')[1];check(g and g.IsPlaying and g.SoundGroup==effects,'the sting plays on Effects');Audio.Stop()
end
-- 7. the pull announcement's timing: the server's PullAnnounceRules.RevealDelay against what this REAL cinematic shows the puller ---------------------------------------
-- The chat line about a pull must never reach the puller before THEIR reveal has shown the seed. The server waits RevealDelay(rarity) after the open (derived from RarePullRules);
-- here every presentation the client can pick is played frame by frame and the moments the puller really sees are read off the screen: the rarity title, the seed's name fully faded
-- in, and the cinematic's own RarePullClimaxAt attribute. All must come before the line (the margin is what is left).
do
 local Announce=W.module('PullAnnounceRules');local Packs=W.module('SeedPackRules')
 local margin=Announce.Setting('RevealMargin')
 local rows={}
 -- plays `seconds` of the presentation that `run` started at server time t0; returns {Title, Name, Climax} in seconds after the open (nil when never shown)
 local function watch(run,t0,seconds,during)
  local out={Climax=X.player:GetAttribute('RarePullClimaxAt')and X.player:GetAttribute('RarePullClimaxAt')-t0 or nil}
  X.run(seconds,1/30,function(now)
   local t=now-t0
   local gui=X.pg:FindFirstChild('RarePullReveal')
   if gui then
    local title,name=X.find(gui,'Title'),X.find(gui,'Seed name')
    if title and not out.Title and title.TextTransparency<.5 then out.Title=t end
    if name and not out.Name and name.TextTransparency<=.15 then out.Name=t end
   end
   if during then during(t)end
  end)
  return out
 end
 local function verify(tag,rank,out)
  local delay=Announce.RevealDelay(names[rank])
  check(out.Title~=nil and out.Name~=nil,tag..': the title and the seed\'s name were both shown')
  if out.Title and out.Name then
   check(out.Name<=delay-.1,tag..': the seed\'s name is fully in at '..string.format('%.2f',out.Name)..' s, the line comes at '..string.format('%.2f',delay)..' s (slack '..string.format('%.2f',delay-out.Name)..' s)')
   check(out.Title<out.Name+1e-9 and out.Title<delay-margin+1/30,tag..': the title ('..string.format('%.2f',out.Title)..' s) is shown well before it')
  end
  if out.Climax then check(out.Climax<=delay-margin+1e-6,tag..': the hit (RarePullClimaxAt) is at '..string.format('%.2f',out.Climax)..' s, at least the margin before the line') end
  rows[#rows+1]=string.format('%s/%s title %.2f name %.2f hit %s',names[rank],tag:match('%((.-)%)')or tag,out.Title or -1,out.Name or -1,out.Climax and string.format('%.2f',out.Climax)or'-')
 end
 -- the ladder (Common..Mythic), normal and quick (R153: quick = "Skip pack animations" on, after another pack)
 for rank=1,5 do
  reset();local run,bag=start(rank);local t0=R.clock
  check(run.Kind=='Ladder'and not run.Quick,names[rank]..' (card): a normal seed card')
  verify(names[rank]..' (card)',rank,watch(run,t0,run.TL.Length+.4));bag:Destroy()
  if rank>=2 then
   X.player:SetAttribute('SettingSkipCutscenes',true)
   reset();local first,bag1=start(1);X.run(first.TL.Length+.2)
   local second,bag2=start(rank);local t1=R.clock
   check(second.Quick,names[rank]..' (quick): a quick reveal')
   verify(names[rank]..' (quick)',rank,watch(second,t1,second.TL.Length+.4));bag1:Destroy();bag2:Destroy()
   X.player:SetAttribute('SettingSkipCutscenes',nil)
  end
 end
 -- the story scenes: every presentation
 for rank=6,8 do
  reset();local run=start(rank);local t0=R.clock
  check(run.Kind=='Scene'and run.Variant=='Full',names[rank]..' (Full): the full scene')
  verify(names[rank]..' (Full)',rank,watch(run,t0,run.TL.Length+.4))
  reset();W.Gui.ReducedMotionEnabled=true
  run=start(rank);t0=R.clock
  check(run.Kind=='Scene'and run.Variant=='Calm',names[rank]..' (Calm): the calm scene (ReducedMotion)')
  verify(names[rank]..' (Calm)',rank,watch(run,t0,run.TL.Length+.4))
  reset();X.keeper(V3(25,3,100),{})
  run=start(rank);t0=R.clock
  check(run.Kind=='InPlace',names[rank]..' (InPlace): the in-place version (a keeper is near)')
  verify(names[rank]..' (InPlace)',rank,watch(run,t0,run.TL.Length+.4))
  -- a scene cut short before its hit shows the result card at once: still before the line
  reset();run=start(rank);t0=R.clock;local tl=run.TL
  X.run(tl.SceneIn+.6)
  X.keeper(V3(10,3,170),{TargetUserId=7,GuardianBehavior='CHASING'})
  verify(names[rank]..' (Result)',rank,watch(run,t0,8))
  -- a skip at the first moment it is allowed, then the second skip to the way out: the seed is shown sooner, the line still comes later
  reset();run=start(rank);t0=R.clock;tl=run.TL
  local hitBefore=X.player:GetAttribute('RarePullClimaxAt')-t0
  local skipped,out_hit=false,nil
  local out=watch(run,t0,tl.Length+.4,function(t)
   if not skipped and t>=tl.SkipFrom+.05 then skipped=true;M.Skip();out_hit=X.player:GetAttribute('RarePullClimaxAt')-t0 end
  end)
  check(skipped and out_hit and out_hit<hitBefore and out_hit<=Announce.RevealDelay(names[rank])-margin,names[rank]..' (Skip): a skip moves the hit EARLIER ('..string.format('%.2f',hitBefore)..' -> '..string.format('%.2f',out_hit or -1)..' s), never later than the line')
  check(out.Name and out.Name<Announce.RevealDelay(names[rank])-1,names[rank]..' (Skip): a skipped puller has the seed on screen well before the line ('..string.format('%.2f',out.Name or -1)..' s vs '..string.format('%.2f',Announce.RevealDelay(names[rank]))..' s)')
 end
 reset()
 print('puller sees the seed (seconds after the open): '..table.concat(rows,' | '))
end
print(('R151 cinematic checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
