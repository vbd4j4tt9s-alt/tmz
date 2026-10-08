--!nocheck
-- R153 seed opening: EVERY opening plays in full, skipping is the player's choice (owner: "pack animations should play all the time and
-- shouldn't stop after 2/3 times. they can skip if they want or we can add a skip cutscene option in the settings"). The REAL SeedPackClient,
-- PackOpeningFeedback (with RarePullCinematic, the card, the scenes, the sounds, the sky beam) and PullAnnouncerClient on the Roblox mock;
-- the server driven the way ChestService drives it (the carried pack, its clicks, RevealSeedId / RevealDuration / RevealAt, the pack
-- destroyed when the server ends the opening, never earlier than RevealDuration):
--  1. "Skip pack animations" is OFF by default: no attribute, full presentations
--  2. back to back: packs opened 0.1 s, 1 s and 3 s after the last presentation (and the server's opening) ended, 24 in a row each, and a
--     pack opened while the last card is still up: every one plays its FULL timeline to its end (the full card / story scene, its whole cue
--     sheet, the pack in the world on the full suspense); R151's "quick" reveal from the 2nd / 3rd pack on is gone
--  3. no session cap: those 73 openings are one session: every Secret / Cosmic / King is its full story scene, every time
--  4. skip by choice: a click / tap on the world, Enter, the gamepad's B or R2 (cards), the full-screen button and the bound keys (the story
--     scene) jump to the hit; the result shows; a later press closes it. The pack in the world bursts with the card and its sky beam lands
--     with it; the seed still flies into the hand when the server ends the opening (not earlier). Presses that are not a choice never skip:
--     the run of clicks that opened the pack, a press the game used (a HUD button), a drag, a long press, the jump keys
--  5. the puller's chat line, held for their reveal, goes out at the SKIPPED result (not at the unskipped time), never before the seed
--  6. "Skip pack animations" ON: the short version every time (the quick card and quick pack; Secret / Cosmic / King: the result card in
--     place, no story scene, no camera); OFF again: full
-- R154 (owner: "... the seed stays on the player's screen until they click and the seed goes to their inventory"): every presentation above
-- now ends with its result WAITING; the press after it COLLECTS it (the seed flies home: SeedCollect154) where it used to close it. So "plays
-- to its end" = its whole timeline played and then it waits (still there after its Length) until the press, which collects it; the opener's
-- own world seed never flies into the hand while the result waits (it fades where it hovers) nor after the collect (it went with the card).
-- The full collect / wait / edge-case checks: test_seed_collect.luau.
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local Y=require('./rare152_env')(W,E,F,X)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local noop=function()end
W.Run.PreAnimation=R.signal()
W.stub('SeedCarryPose',{new=function()return{Reset=noop,IsReady=function()return true end,Apply=noop}end})
local Mixer=W.module('AudioMixer');Mixer.Start()
do -- Debris as on Roblox (the mock's does nothing)
 local queue={}
 W.service('Debris').AddItem=function(_,item,ttl)queue[#queue+1]={Item=item,At=R.clock+(tonumber(ttl)or 10)}end
 W.Run.Heartbeat:Connect(function()for i=#queue,1,-1 do if R.clock>=queue[i].At then local d=table.remove(queue,i);pcall(function()d.Item:Destroy()end)end end end)
end
local Players=W.service('Players')
function Players.GetPlayers()return {X.player}end
function Players.GetPlayerFromCharacter(_,c)if c==X.char then return X.player end;return nil end
local Visuals=W.module('SeedPackVisuals');local Rules=W.module('SeedPackRules');local L=W.module('RarePullRules')
local World=W.module('RarePullWorld');local M=W.module('RarePullCinematic');local Audio=W.module('RarePullAudio')
local Settings=W.module('SettingsConfig');local Art=W.module('RarePullArt');local Announce=W.module('PullAnnounceRules');local Collect=W.module('SeedCollect154')
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local cam=W.workspace.CurrentCamera
local SS=W.service('SoundService')
local ATTR=Settings.ToggleAttributes.SkipCutscenes
-- images drawn at once (the client's background drawing), so the stages use them
Art.Hooks.Spawn=function(fn)fn()end;Art.Hooks.Wait=noop
Art.Hooks.Create=function(w,h)return {W=w,H=h,Destroy=noop}end;Art.Hooks.Content=function(o)return 'rbxtemp://r153/'..o.W end
Art.Request(Art.Order)
-- the keys a story scene binds (the mock keeps only the function)
local boundKeys={}
do local CAS=W.service('ContextActionService');local orig=CAS.BindActionAtPriority
 CAS.BindActionAtPriority=function(self,name,fn,touch,priority,...)boundKeys[name]={...};return orig(self,name,fn,touch,priority,...)end end
-- the hand the seed flies into
local hand=R.new('Part');hand.Name='RightHand';hand.Size=V3(1,1,1);hand.CFrame=CF(1.5,4,100);hand.Parent=X.char
-- the chat (PullAnnouncerClient writes RBXGeneral)
local remotes=W.RS:FindFirstChild('ChestChaseRemotes')
local chatRemote=R.Instance.new('RemoteEvent');chatRemote.Name=Announce.RemoteName;chatRemote.Parent=remotes
local chat={}
do local TCS=W.service('TextChatService');local channels=R.new('Folder');channels.Name='TextChannels';channels.Parent=TCS
 local general=R.new('TextChannel');general.Name='RBXGeneral';general.Parent=channels
 general.DisplaySystemMessage=function(_,text)chat[#chat+1]={At=W.workspace:GetServerTimeNow(),Text=text}end end
-- the real client scripts
for _,n in ipairs({'SeedPackClient','PackOpeningFeedback','PullAnnouncerClient'})do
 local s=R.new('LocalScript');s.Name=n;local ok,err=pcall(W.load,n,s);check(ok,'the real '..n..' loads: '..tostring(err))
end
-- what is on screen / in the world ----------------------------------------------------------------------------------------------------------
local function effects()return W.workspace:FindFirstChild('_LocalSeedPackEffects')end
local function worldReveals()local n=0;local e=effects();if e then for _,c in ipairs(e:GetChildren())do if c.Name=='SeedReveal'then n+=1 end end end;return n end
local function worldSeed()
 local e=effects();if not e then return nil end
 for _,r in ipairs(e:GetChildren())do local s=r.Name=='SeedReveal'and r:FindFirstChild('RewardSeed');if s then return s end end
 return nil
end
local function seedOut()
 local s=worldSeed();if not s then return false end
 for _,d in ipairs(s:GetDescendants())do if d:IsA('BasePart')and d.LocalTransparencyModifier<1 and d.Transparency<1 then return true end end
 return false
end
local function revealGui()return X.pg:FindFirstChild('RarePullReveal')end
local function titleShown()local g=revealGui();local t=g and X.find(g,'Title');return t~=nil and t.Visible~=false and t.TextTransparency<.5 end
local function oddsFinal(run)local g=revealGui();local o=g and X.find(g,'Odds');return o~=nil and run.Odds~=nil and o.TextTransparency<.05 and o.Text==L.OddsPrefix..run.Odds end
local function rarePlaying()local n={};for _,s in ipairs(Y.sounds)do if s.IsPlaying and s.Parent and s.Name:match('^RarePull_')and s.Name~='RarePull_AuraHum'then n[#n+1]=s.Name end end;return n end
local function ducks()local n=0;for _,d in ipairs(SS:GetDescendants())do if d.Name=='RarePullDuck'then n+=1 end end;return n end
local function clean(tag)
 check(M.Active()==nil and W.workspace:FindFirstChild('_RarePullStage')==nil and revealGui()==nil,tag..': no presentation, stage or reveal GUI left')
 check(#rarePlaying()==0 and ducks()==0 and not Audio.Running(),tag..': no reveal sound, duck or sound sheet left ('..table.concat(rarePlaying(),',')..')')
 check(W.rsBound[M.BindName]==nil and W.actions[M.SkipAction]==nil,tag..': no render step or skip binding left')
 check(cam.CameraType==R.Enum.CameraType.Custom and math.abs(cam.FieldOfView-70)<1e-6 and X.controls.Enabled and X.hud.Main.Enabled and X.hud.Hotbar.Enabled,tag..': the camera, movement and the HUD are the player\'s')
 check(worldReveals()==0,tag..': no world reveal left')
 check(Collect.Flying()==0 and X.pg:FindFirstChild('SeedCollectFly')==nil,tag..': no seed left flying (R154)')
end
local function reset()
 M.Abort('test');World.Clear()
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 cam.CameraType=R.Enum.CameraType.Custom;cam.FieldOfView=70;cam.CFrame=CF(3,9,112);cam.Focus=CF(0,3,100);cam.CameraSubject=X.hum
 X.root.CFrame=CF(0,3,100);X.state=R.Enum.HumanoidStateType.Running;X.hum.Health=100
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true;X.lowFx=false
 X.player:SetAttribute(ATTR,nil)
 X.run(1)
end
-- the server -----------------------------------------------------------------------------------------------------------------------------
-- open: the pack in the hand, its five clicks, then the server commits (RevealSeedId / RevealDuration (the FULL one, every time) / RevealAt)
local opened=0
local function open(rank)
 opened+=1
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='c'..opened,Stage=2},nil);tool.Activated=R.signal();tool.Enabled=true;tool.Parent=X.char
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('PackClicksRequired',Rules.OpenClicks);bag:SetAttribute('PackClickCount',Rules.OpenClicks)
 W.frames(1,1/30)
 local seedId=X.byRank[rank];local rarity=Rules.GetRarity(seedId);local dur=Rules.GetRevealDuration(rarity)
 bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('Rarity',rarity);bag:SetAttribute('RevealDuration',dur)
 local at=W.workspace:GetServerTimeNow();bag:SetAttribute('RevealAt',at)
 W.frames(1,1/30)
 return {Bag=bag,Tool=tool,Rank=rank,At=at,Duration=dur,SeedId=seedId,Run=M.Active()}
end
-- one frame; the server ends the opening at RevealDuration (the pack goes, the seed is in the hand)
-- (o.Track: where the world seed is each frame, against the hand it flies into: {T = seconds after RevealAt, D = studs from the hand})
local function step(o,dt)
 W.frames(1,dt or 1/30)
 if o.Track and o.Bag.Parent then
  local s=worldSeed();if s and s.PrimaryPart then o.Track[#o.Track+1]={T=W.workspace:GetServerTimeNow()-o.At,D=(s:GetPivot().Position-(hand.CFrame*CF(0,-.5,0)).Position).Magnitude}end
 end
 if o.Bag.Parent and W.workspace:GetServerTimeNow()-o.At>=o.Duration then o.Bag:Destroy();o.Tool:Destroy();o.EndedAt=W.workspace:GetServerTimeNow()end
end
-- frames until the run's own clock reaches t
local function untilClock(o,run,t,each)local g=0;while not run.Done and run.Clock()<t and g<3000 do step(o);g+=1;if each then each()end end end
-- frames until the presentation and the server's opening have both ended. R154: a presentation that has played its whole timeline waits for
-- the player: then it is collected (a click; the story scene's full-screen button) and the seed flies home.
local collected={} -- run -> its clock when it was collected (and it was waiting then)
local function finish(o,each)
 local g=0
 while(M.Active()~=nil or o.Bag.Parent or Collect.Flying()>0)and g<3000 do
  local run=M.Active()
  if run and not run.Done and not run.Collected and run.SawResult and run.Clock()>=math.max(run.TL.Length,L.ShownAt(run.TL)+M.CollectAfter)+.05 then
   collected[run]={At=run.Clock(),Waiting=M.Waiting()}
   if run.Kind=='Scene'then local b=X.find(revealGui(),'Backdrop');if b then b.Activated:Fire()end else W.UIS.InputBegan:Fire({UserInputType=R.Enum.UserInputType.MouseButton1,KeyCode=R.Enum.KeyCode.Unknown,Position=V3(400,300,0)},false)end
  end
  step(o);g+=1;if each then each()end
 end
 X.run(.1)
end
-- played its whole timeline, waited, and the press collected it (its story scene then went out by itself)
local function playedOut(run)local c=collected[run];return run.Done and run.Collected and c~=nil and c.Waiting and c.At>=run.TL.Length-.05 end
-- presses ---------------------------------------------------------------------------------------------------------------------------------
local UT,KC=R.Enum.UserInputType,R.Enum.KeyCode
local function click(processed)W.UIS.InputBegan:Fire({UserInputType=UT.MouseButton1,KeyCode=KC.Unknown,Position=V3(400,300,0)},processed==true)end
local function key(k)W.UIS.InputBegan:Fire({UserInputType=UT.Keyboard,KeyCode=KC[k],Position=V3(0,0,0)},false)end
local function pad(k)W.UIS.InputBegan:Fire({UserInputType=UT.Gamepad1,KeyCode=KC[k],Position=V3(0,0,0)},false)end
local function touch(o,hold,move)
 local input={UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(300,200,0)}
 W.UIS.InputBegan:Fire(input,false)
 local t0=R.clock;while R.clock-t0<hold-1e-9 do step(o)end
 input.Position=V3(300+(move or 0),200,0);W.UIS.InputEnded:Fire(input,false)
end
local function press(o,how)
 if how=='click'then click()elseif how=='tap'then touch(o,0,2)elseif how=='Return'then key('Return')
 elseif how=='ButtonB'or how=='ButtonR2'then pad(how)
 elseif how=='button'then local b=X.find(revealGui(),'Backdrop');if b then b.Activated:Fire()end
 elseif how=='R2 key'then local fn=W.actions[M.SkipAction];if fn then fn(M.SkipAction,R.Enum.UserInputState.Begin)end end
end

-- 1. off by default ---------------------------------------------------------------------------------------------------------------------------
reset()
check(Settings.Defaults.SkipCutscenes==false and Settings.Toggles.SkipCutscenes==true,'"Skip pack animations" is a saved on / off setting, OFF by default')
check(X.player:GetAttribute(ATTR)==nil and L.SkipAnimations()==false,'no setting published: the reveal reads OFF')
X.player:SetAttribute(ATTR,false);check(L.SkipAnimations()==false,'published OFF: OFF');X.player:SetAttribute(ATTR,true);check(L.SkipAnimations()==true,'published ON: ON');X.player:SetAttribute(ATTR,nil)
check(L.Decide({Alive=true,KeeperDistance=500,CameraType='Custom',Grounded=true})=='Full','a safe player gets the full story scene')
check(L.Decide({Alive=true,KeeperDistance=500,CameraType='Custom',Grounded=true,SkipCutscenes=true})=='InPlace','with the setting on: the in-place result card')
check(L.QuickWindow==nil and L.LastRevealEnd==nil,'R151\'s quick window (packs opened within 3 s of the last reveal) is gone')

-- 2 / 3. back to back, no session cap ------------------------------------------------------------------------------------------------------
local fullScenes={0,0,0,0,0,0,0,0};local total=0
local function fullTimeline(run,rank)
 if rank<=5 then local tl=L.CardTimeline(rank,false);return run.Kind=='Ladder'and not run.Quick and run.TL.Length==tl.Length and run.TL.Burst==tl.Burst and #run.Cues==#L.LadderCues(rank,false)end
 local tl=L.Timeline(rank,'Full');return run.Kind=='Scene'and run.Variant=='Full'and run.TL.Length==tl.Length and run.TL.Climax==tl.Climax and #run.Cues==#L.SceneCues(rank,tl)
end
-- one opening played through: the run, its clock's furthest point, when the world seed came out, the sounds of its hit and slam
local function playFull(rank,tag)
 local o=open(rank);local run=o.Run;local t0=R.clock;total+=1
 if not check(run~=nil and run.Rank==rank,tag..': the opener\'s presentation starts')then finish(o);return o end
 check(fullTimeline(run,rank),tag..': the FULL timeline ('..tostring(run.Kind)..' '..tostring(run.Variant or'')..(run.Quick and' quick'or'')..', '..string.format('%.2f',run.TL.Length)..' s, '..#run.Cues..' cues)')
 check(not L.IsQuick(o.Bag),tag..': and the pack in the world is told the same (full suspense)')
 local maxT,seedAt,titled=-1,nil,false
 finish(o,function()
  if M.Active()==run then maxT=math.max(maxT,run.Clock())end
  if not seedAt and seedOut()then seedAt=W.workspace:GetServerTimeNow()-o.At end
  if titleShown()then titled=true end
 end)
 check(playedOut(run)and maxT>=run.TL.Length-.05,tag..': it plays to its end and waits for the player, who collects it ('..tostring(run.Reason)..' at '..string.format('%.2f',maxT)..' of '..string.format('%.2f',run.TL.Length)..' s)')
 check(titled,tag..': the result is shown')
 check(seedAt and seedAt>=L.BurstAt(rank,false)-1e-6 and seedAt<=L.BurstAt(rank,false)+.1,tag..': the seed comes out of the pack in the world after the full suspense ('..string.format('%.2f',seedAt or -1)..' s, full '..L.BurstAt(rank,false)..')')
 local hits=0;for _,p in ipairs(Y.plays(t0))do if p.Slot=='PackBurst'or p.Slot=='TitleSlam'then hits+=1 end end
 check(hits>=2,tag..': its burst and its "1 in N" slam are heard ('..hits..')')
 if rank>=6 and run.Kind=='Scene'and playedOut(run)then fullScenes[rank]+=1 end
 return o,run
end
reset()
for _,gap in ipairs({.1,1,3})do
 for i=1,24 do
  local rank=(i-1)%8+1
  X.run(gap) -- (the last opening and its presentation have both ended: the next pack this long after)
  playFull(rank,string.format('back to back (%.1f s) #%d %s',gap,i,names[rank]))
 end
end
do -- a pack opened while the last card is still up (Mythic: its card outlasts the server's opening): the new one is full too
 local o1=open(5);local first=o1.Run
 local g=0;while o1.Bag.Parent and g<300 do step(o1);g+=1 end
 X.run(.1)
 check(M.Active()==first and not first.Done,'card still up: the Mythic card is still on screen when its pack\'s opening has ended')
 local shownBefore=first.Clock()>=L.ShownAt(first.TL)
 local o2,second=playFull(4,'opened while the last card is up: Legendary')
 check(first.Done and first.Reason=='replaced'and first.Collected and shownBefore,'card still up: the first card had shown its result and hands over to the new pack (the player opened it); R154: its seed flew in first')
 check(second and second~=first,'card still up: the new pack has its own full presentation')
end
check(total==73,'one session: '..total..' openings')
check(fullScenes[6]==9 and fullScenes[7]==9 and fullScenes[8]==9,'no session cap: every Secret / Cosmic / King story scene played in full, every time ('..table.concat(fullScenes,'/',6,8)..' of 9 each)')
X.run(30);World.Clear();X.run(.2);clean('after 73 openings')

-- 4. skip by choice -----------------------------------------------------------------------------------------------------------------------
-- variant: Ladder | Full | InPlace (a keeper near); how / close: the press that skips and the one that closes
local function skipCase(rank,variant,how,close)
 reset()
 if variant=='InPlace'then X.keeper(V3(25,3,100),{})end
 local o=open(rank);local run=o.Run;o.Track={}
 local tag=names[rank]..' '..variant..' skipped ('..how..', closed with '..close..')'
 local kind=variant=='Full'and'Scene'or variant
 if not check(run and run.Kind==kind,tag..': starts as '..kind..' ('..tostring(run and run.Kind)..')')then finish(o);return end
 local tl=run.TL;local hit=tl.Climax or tl.Burst;local shownAt=L.ShownAt(tl)
 local shownAttr=X.player:GetAttribute('RarePullSeedShownAt')
 if variant=='Full'then check(table.find(boundKeys[M.SkipAction]or{},KC.ButtonR2)~=nil and table.find(boundKeys[M.SkipAction],KC.ButtonB)~=nil,tag..': the gamepad\'s R2 and B are bound while the story scene runs')end
 untilClock(o,run,tl.SkipFrom+.1)
 local hint=X.find(revealGui(),'Skip hint');step(o);step(o);step(o)
 check(hint and hint.Visible and hint.TextTransparency<.9,tag..': the skip hint shows')
 local t0=W.workspace:GetServerTimeNow();local before=run.Clock()
 press(o,how)
 check(run.Skipped==1 and near(run.Clock(),hit-.02,.03),tag..': straight to the hit ('..string.format('%.2f -> %.2f, hit %.2f',before,run.Clock(),hit)..')')
 check(X.player:GetAttribute('RarePullSeedShownAt')<=shownAttr-(run.Clock()-before)+1e-3,tag..': the moment the seed is shown moved earlier by the jump (the puller\'s chat line waits for it)')
 if variant~='Full'then check(near(L.Shift(o.Bag),run.Offset,1e-6)and L.Shift(o.Bag)>0,tag..': the pack in the world is told the jump ('..string.format('%.2f',L.Shift(o.Bag))..' s)')end
 local titleAt,seedAt,hitHeard,inWindow,beamAt=nil,nil,nil,nil,nil
 local hitSlot=rank<=3 and'PackBurst'or rank==7 and'CosmicBoom'or rank>=5 and'Impact'or'GroundImpact'
 local playsFrom=R.clock-1e-6
 untilClock(o,run,shownAt+M.CollectAfter+.05,function()
  local now=W.workspace:GetServerTimeNow()
  if not titleAt and titleShown()and oddsFinal(run)then titleAt=now end
  if not seedAt and seedOut()then seedAt=now end
  if not beamAt then local e=World.Get(X.player);if e and e.Beam and e.Beam.Landed then beamAt=now end end
  if not hitHeard then for _,p in ipairs(Y.plays(playsFrom))do if p.Slot==hitSlot then hitHeard=p.At end end end
  if inWindow==nil and run.Clock()>hit+.05 and run.Clock()<shownAt-.05 then local off=run.Offset;inWindow=M.Skip()==false and run.Offset==off end
 end)
 check(hitHeard and hitHeard-t0<=.1,tag..': the hit ('..hitSlot..') is heard right away ('..string.format('%.2f',(hitHeard or 99)-t0)..' s)')
 check(titleAt and titleAt-t0<=shownAt-hit+.15,tag..': the result card is up: title, seed, "1 in N" ('..string.format('%.2f',(titleAt or 99)-t0)..' s after the press)')
 if inWindow~=nil then check(inWindow,tag..': a press between the hit and the result does nothing (the result is on its way)')end
 if variant~='Full'then
  check(seedAt and seedAt-t0<=.15,tag..': the pack in the world bursts with the card ('..string.format('%.2f',(seedAt or 99)-t0)..' s after the press)')
  if rank>=6 then
   local e=World.Get(X.player)
   check(e and near(e.Shift,L.Shift(o.Bag),1e-6)and near(W.workspace:GetServerTimeNow()-e.At+e.Shift,run.Clock(),.05),tag..': its sky beam keeps the card\'s clock')
   check(beamAt and beamAt-t0<=.15,tag..': and lands with the card ('..string.format('%.2f',(beamAt or 99)-t0)..' s after the press)')
  end
 end
 -- R154: the second press once the result is shown COLLECTS it (R153 closed it): the seed flies home
 local pressAt=R.clock
 press(o,close)
 check(run.Skipped==1 and run.Collected,tag..': a second press collects the result (the seed flies home)')
 local g=0;while M.Active()==run and g<200 do step(o);g+=1 end
 local fade=variant=='Full'and M.SceneExit+(tl.Length-tl.Back)or M.FadeSeconds
 check(run.Done and R.clock-pressAt<=fade+.1,tag..': it is gone after its fade ('..string.format('%.2f',R.clock-pressAt)..' s)')
 -- the server's end: the opener's world seed never flies into the hand (it was collected: it went home with the card)
 local after=nil;local g2=0
 while o.Bag.Parent and g2<400 do step(o);g2+=1;if after==nil and R.clock-pressAt>.3 then after=seedOut()end end
 local closest=math.huge;for _,p in ipairs(o.Track)do if p.T>=pressAt-o.At+.3 then closest=math.min(closest,p.D)end end
 check((after==false or after==nil)and closest>.3,tag..': the world seed fades out once it is collected, never reaching the hand (R154: no second arrival; closest '..string.format('%.2f',closest)..' studs)')
 check(o.EndedAt and near(o.EndedAt-o.At,o.Duration,.05),tag..': the server ended the opening at its full RevealDuration ('..string.format('%.2f',o.Duration)..' s): the skip and the collect ask nothing of it')
 local gf=0;while Collect.Flying()>0 and gf<200 do step(o);gf+=1 end
 X.run(.3);World.Clear();X.run(.1);clean(tag)
end
for rank=1,5 do skipCase(rank,'Ladder',rank%2==0 and'tap'or'click',rank==5 and'ButtonR2'or'click')end
for rank=6,8 do skipCase(rank,'Full','button',rank==8 and'R2 key'or'button')end
for rank=6,8 do skipCase(rank,'InPlace',rank==7 and'ButtonB'or'Return','ButtonB')end
-- presses that are not the player's choice to skip
do
 reset()
 local o=open(5);local run=o.Run
 -- the clicks that opened the pack go on for a moment (a run of clicks .1 s apart through SkipFrom): never a skip
 for _=1,6 do click();step(o);step(o);step(o)end
 check(run.Clock()>=L.CardSkipFrom and not run.Skipped,'a run of clicks (the opening clicks going on past SkipFrom) never skips')
 untilClock(o,run,run.Clock()+.3)
 click(true);check(not run.Skipped,'a click the game used (a HUD button) does not skip')
 touch(o,.1,60);check(not run.Skipped,'a drag (turning the camera) does not skip')
 key('Space');pad('ButtonA');key('W');check(not run.Skipped,'the jump keys and movement do not skip')
 touch(o,.05,3);check(run.Skipped==1,'a tap does')
 finish(o);clean('presses')
 reset()
 local o2=open(4);local run2=o2.Run
 untilClock(o2,run2,L.CardSkipFrom+.05);touch(o2,.6,0)
 check(not run2.Skipped,'a long press (held .6 s) does not skip')
 finish(o2);clean('long press')
end

-- 5. the chat line ---------------------------------------------------------------------------------------------------------------------------
do
 local margin=Announce.Setting('RevealMargin');local n=0
 local function trial(rank,variant,skip)
  reset();table.clear(chat)
  if variant=='InPlace'then X.keeper(V3(25,3,100),{})end
  local o=open(rank);local run=o.Run
  local tag='chat '..names[rank]..' '..variant..(skip and' skipped'or'')
  -- the line reaches this client while its reveal is still going (a slow device): it is held for the puller's own reveal
  n+=1;chatRemote.OnClientEvent:Fire({Kind='Pull',Name=X.player.Name,UserId=X.player.UserId,Id='r153-'..n,SeedId=o.SeedId,Odds=100})
  check(#chat==0,tag..': held while the reveal is going')
  local unskipped=X.player:GetAttribute('RarePullSeedShownAt')
  local seen;local skippedAt
  finish(o,function()
   if skip and not run.Skipped and not run.Done and run.Clock()>=run.TL.SkipFrom+.05 then press(o,variant=='Full'and'button'or'click');skippedAt=W.workspace:GetServerTimeNow()end
   if not seen and titleShown()and oddsFinal(run)then seen=W.workspace:GetServerTimeNow()end
  end)
  check(#chat==1,tag..': one line ('..#chat..')')
  local at=chat[1]and chat[1].At
  check(seen and at and at>=seen-1e-6,tag..': after the puller has seen the seed (line '..string.format('%.2f',(at or 0)-o.At)..' s, seed '..string.format('%.2f',(seen or 0)-o.At)..' s)')
  if skip then
   check(at and seen and at<=seen+margin+.1,tag..': it goes out at the skipped result (+ the margin), '..string.format('%.2f',at and seen and at-seen or -1)..' s after the seed')
   check(at and at<unskipped+margin-.3,tag..': well before the unskipped time ('..string.format('%.2f',at and at-o.At or -1)..' s vs '..string.format('%.2f',unskipped+margin-o.At)..' s)')
  else
   check(at and near(at,unskipped+margin,.1),tag..': it waits for the full reveal\'s seed ('..string.format('%.2f',at and at-o.At or -1)..' s)')
  end
 end
 for _,rank in ipairs({4,5})do trial(rank,'Ladder',false);trial(rank,'Ladder',true)end
 for _,rank in ipairs({6,8})do trial(rank,'Full',false);trial(rank,'Full',true);trial(rank,'InPlace',true)end
 reset();clean('chat')
end

-- 6. "Skip pack animations" ON: the short version, every time ------------------------------------------------------------------------------
do
 reset();X.player:SetAttribute(ATTR,true)
 for round=1,2 do
  for rank=1,8 do
   X.run(.1)
   local o=open(rank);local run=o.Run;local tag='setting on #'..round..' '..names[rank]
   if not check(run~=nil,tag..': a presentation starts')then finish(o)
   else
    local scripted,staged,seedAt,titled=false,false,nil,false
    finish(o,function()
     if cam.CameraType==R.Enum.CameraType.Scriptable then scripted=true end
     if W.workspace:FindFirstChild('_RarePullStage')then staged=true end
     if titleShown()then titled=true end
     if not seedAt and seedOut()then seedAt=W.workspace:GetServerTimeNow()-o.At end
    end)
    if rank<=5 then
     local tl=L.CardTimeline(rank,true)
     check(run.Kind=='Ladder'and run.Quick and run.TL.Length==tl.Length and L.IsQuick(o.Bag),tag..': the short card ('..string.format('%.2f',run.TL.Length)..' s instead of '..string.format('%.2f',L.CardTimeline(rank,false).Length)..')')
     check(seedAt and near(seedAt,L.BurstAt(rank,true),.1),tag..': and the short suspense in the world ('..string.format('%.2f',seedAt or -1)..' s)')
    else
     check(run.Kind=='InPlace'and run.Why=='skip pack animations is on'and not scripted and not staged,tag..': no story scene: the result card in place (no camera, no stage)')
     check(run.TL.Length<L.Timeline(rank,'Full').Length,tag..': shorter than the story scene ('..string.format('%.2f',run.TL.Length)..' s)')
    end
    check(titled and playedOut(run),tag..': the result card is shown and waits for the player (R154), who collects it')
   end
  end
 end
 X.player:SetAttribute(ATTR,false)
 X.run(.5);playFull(6,'setting off again: Secret')
 X.run(.5);playFull(2,'setting off again: Uncommon')
 X.run(30);World.Clear();X.run(.2);clean('setting')
end
print(('R153 choice checks %d, fails %d'):format(checks,fails))
if fails>0 then error('failures')end
