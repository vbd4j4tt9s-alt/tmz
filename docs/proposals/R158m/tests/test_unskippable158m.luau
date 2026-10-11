--!nocheck
-- R158m (owner: "pack opening animations are still really skippable if clicking very fast make sure they always play and only way to skip them is the
-- bottom right button the click to collect for after the pack opens and the seed shows is still the same"): the REAL RarePullCinematic (director) with
-- RarePullScenes, RarePullCard, RarePullAudio and RarePullRules on the Roblox mock, every tier (1..8) and every presentation: the Common..Mythic seed
-- card (normal and Quick), the Secret / Cosmic / King story scene (Full and Calm), the compact card in place (a keeper near, and "Skip pack animations"),
-- and the result card of a scene that had to stop early.
--  * a burst of clicks / taps from the first frame to just before CollectFrom (the seed shown AND its float / the scene's tail played out) + CollectAfter
--    never collects and never moves the clock: through every route (the world, a touch released a frame later, TouchTapInWorld, the scene's full-screen
--    button and its Space / A keys, M.Tap, M.Collect), and Enter / B / R2 never skip a Common..Mythic card nor collect anything early;
--  * a press that BEGAN at or after CollectFrom + CollectAfter collects (a touch begun earlier and released later does not); M.Collect likewise (the same gate);
--  * Secret / Cosmic / King: the SKIP button (and Enter / B / R2, its keys) still jumps to the hit from SkipFrom; no SKIP button on Common..Mythic;
--  * the collect hint ("click to collect!") never shows while a press still does nothing, and shows once it lands;
--  * whatever takes the player away still collects at once (death right after the hit, in the animation's tail, a teleport, a chase, the next pack);
--    a menu opening before CollectFrom is ignored (the animation plays on, the result then waits for the click); one opening later collects as before;
--  * the next pack put in the hand while a reveal runs is held on that very frame, and its clicks never activate it (so cannot open it and replace the reveal).
-- (The teeth: run_unskippable158m.sh runs this same file against mutated copies of the source and against the commit before the fix: each must fail.)
local FAST=false -- (run_unskippable158m.sh sets it for the mutated copies: a handful of presentations that still reach every route)
local W=require('./world');local E=require('./sfx_env')(W);local F=require('./fixtures');local X=require('./rare_env')(W,E,F)
local R=W.R;local V3,CF=R.Vector3.new,R.CFrame.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local fmt=string.format
function R.Inst:Play()local own=rawget(self,'_props').Play;if own then return own(self)end end
function R.Inst:Stop()local own=rawget(self,'_props').Stop;if own then return own(self)end end
local Mixer=W.module('AudioMixer');Mixer.Start()
local M=W.module('RarePullCinematic');local L=W.module('RarePullRules');local Visuals=W.module('SeedPackVisuals')
local Collect=W.module('SeedCollect154')
local UT,KC,US=R.Enum.UserInputType,R.Enum.KeyCode,R.Enum.UserInputState
W.UIS.TouchTapInWorld=R.signal() -- (a tap on the world, as the engine gives it)
local names={'Common','Uncommon','Rare','Legendary','Mythic','Secret','Cosmic','King'}
local DT=1/60
local AFTER=.25 -- (the burst-of-clicks rule: a press this soon after the animation has played is still part of the burst; pinned here, not read from the module)
check(M.CollectAfter==AFTER,'CollectAfter is still 0.25 s (a burst of clicks never collects)')
local function frame()X.run(DT,DT)end
local function revealGui()return X.pg:FindFirstChild('RarePullReveal')end
local function reset()
 M.Abort('test');W.module('RarePullWorld').Clear();E.resetPlays()
 W.Gui.ReducedMotionEnabled=false;W.UIS.TouchEnabled=false;W.UIS.KeyboardEnabled=true
 local c=W.workspace.CurrentCamera
 c.CameraType=R.Enum.CameraType.Custom;c.FieldOfView=70;c.CFrame=CF(3,9,112);c.Focus=CF(0,3,100);c.CameraSubject=X.hum
 X.root.CFrame=CF(0,3,100);X.hum.Health=100;X.state=R.Enum.HumanoidStateType.Running
 for _,k in ipairs(W.CS:GetTagged('BiomeKeeper'))do k:Destroy()end
 X.player:SetAttribute('SettingSkipCutscenes',nil);X.player:SetAttribute('RarePullPreview',nil);X.pg:SetAttribute('SeedMenu',nil)
 for _,a in ipairs({'GuardianRagdollActive','GuardianFlingActive','ChestChaseRunActive','ChestChaseQueued','ChestChaseSeedCarrying'})do X.player:SetAttribute(a,nil)end
 R.advance(4) -- (the previous presentation ended long ago)
end
local nextPackId=0
local function packFor(rank,seedId)
 nextPackId+=1
 local bag=Visuals.CarryBag(X.char,2,'Pack06',1,1,'None');bag:SetAttribute('RevealSeedId',seedId);bag:SetAttribute('RevealAt',W.workspace:GetServerTimeNow())
 local tool=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='p'..rank..'_'..nextPackId,Stage=2},nil)
 return bag,tool
end
local function start(rank,extra)
 local seedId=X.byRank[rank];local bag,tool=packFor(rank,seedId)
 local info={Rank=rank,SeedId=seedId,At=W.workspace:GetServerTimeNow(),Bag=bag,Tool=tool,Mutation='None'}
 for k,v in pairs(extra or{})do info[k]=v end
 return M.Start(info),bag
end
-- the presentations: a Common..Mythic card (normal, Quick = "Skip pack animations"), a story scene (Full, Calm = Reduced Motion), the compact card in place
-- (a keeper near / the setting), the result card of a scene that had to stop early
local function begin(rank,kind)
 reset()
 local extra
 if kind=='Quick'or kind=='Setting'then X.player:SetAttribute('SettingSkipCutscenes',true)
 elseif kind=='Calm'then W.Gui.ReducedMotionEnabled=true
 elseif kind=='InPlace'then X.keeper(V3(25,3,100),{})
 elseif kind=='Result'then extra={Result=true}end
 local run,bag=start(rank,extra)
 return run,bag
end
local expectKind={Card='Ladder',Quick='Ladder',Full='Scene',Calm='Scene',InPlace='InPlace',Setting='InPlace',Result='Result'}
local variants={}
local function add(rank,kind)variants[#variants+1]={rank,kind}end
if FAST then
 add(1,'Card');add(3,'Quick');add(5,'Card');add(6,'Full');add(7,'Calm');add(8,'InPlace');add(6,'Setting');add(7,'Result')
else
 for rank=1,5 do add(rank,'Card');add(rank,'Quick')end
 for rank=6,8 do for _,k in ipairs({'Full','Calm','InPlace','Setting','Result'})do add(rank,k)end end
end
-- presses ----------------------------------------------------------------------------------------------------------------------------------
local mouse={UserInputType=UT.MouseButton1,KeyCode=KC.Unknown,Position=V3(400,300,0)}
local pending={}
-- every route of a click / tap anywhere (never a key that presses the SKIP button): the world, a touch (released a frame later), TouchTapInWorld, the
-- story scene's full-screen button and its Space / A keys, and the director's own M.Tap / M.Collect
local function clicks(run)
 W.UIS.InputBegan:Fire(mouse,false)
 for _,i in ipairs(pending)do W.UIS.InputEnded:Fire(i,false)end;table.clear(pending)
 local touch={UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(300,200,0)};W.UIS.InputBegan:Fire(touch,false);pending[1]=touch
 W.UIS.TouchTapInWorld:Fire(V3(300,200,0),false)
 if run.Kind=='Scene'then
  local b=X.find(X.pg,'Backdrop')
  if b then b.InputBegan:Fire({UserInputType=UT.MouseButton1});b.Activated:Fire()end
  local act=W.actions[M.SkipAction]
  if act then act(M.SkipAction,US.Begin,{KeyCode=KC.Space});act(M.SkipAction,US.Begin,{KeyCode=KC.ButtonA})end
 end
 M.Tap(R.clock);M.Tap() -- (the mock's clock: the director's os.clock)
end
-- Enter / B / R2: the SKIP button's keys (a scene binds them; a card listens to them)
local function keys(run)
 for _,k in ipairs({'Return','ButtonB','ButtonR2'})do
  if run.Kind=='Scene'then local act=W.actions[M.SkipAction];if act then act(M.SkipAction,US.Begin,{KeyCode=KC[k]})end
  else W.UIS.InputBegan:Fire({UserInputType=UT.Keyboard,KeyCode=KC[k],Position=V3(0,0,0)},false)end
 end
 M.Skip()
end
-- a real press that begins now (one the player makes): a scene's full-screen button, else a click on the world
local function realClick(run)
 if run.Kind=='Scene'then
  local b=X.find(X.pg,'Backdrop');if b then b.InputBegan:Fire({UserInputType=UT.MouseButton1});b.Activated:Fire()end
 else W.UIS.InputBegan:Fire(mouse,false)end
end
local function untilClock(run,t,each)
 local g=0
 while not run.Done and run.Clock()<t and g<4000 do frame();g+=1;if each then each()end end
end
-- frames with every press every frame until the run's clock reaches untilT: nothing may collect, end or move the clock (skips: the keys may skip)
local function storm(run,untilT,withKeys)
 local c0,r0=run.Clock(),R.clock;local n,bad=0,nil;local s0=run.Skipped
 while run.Clock()<untilT and n<4000 do
  clicks(run);if withKeys then keys(run)end
  if M.Collect()or M.Collect('press')then bad='M.Collect collected';break end
  frame();n+=1
  if run.Collected or run.Done or M.Active()~=run then bad=fmt('it ended after %d presses at %.2f s (%s)',n,run.Clock(),tostring(run.CollectWhy or run.Reason));break end
  if run.Skipped~=s0 then bad=fmt('it was skipped at %.2f s',run.Clock());break end
  if not near(run.Clock()-c0,R.clock-r0,1e-6)then bad=fmt('the clock moved (%.3f s in %.3f s)',run.Clock()-c0,R.clock-r0);break end
 end
 return n,bad
end
local function settleOut(run)
 local g=0;while(M.Active()or Collect.Flying()>0)and g<2000 do frame();g+=1 end
end
-- 1. every presentation: the burst, the boundary, the real press -------------------------------------------------------------------------------
local routes={'button','ButtonB','Return','ButtonR2'}
local function skipWith(run,route)
 if route=='button'then local b=X.find(X.pg,'Skip button');if b then b.Activated:Fire()end;return end
 if run.Kind=='Scene'then local act=W.actions[M.SkipAction];if act then act(M.SkipAction,US.Begin,{KeyCode=KC[route]})end
 else W.UIS.InputBegan:Fire({UserInputType=UT.Keyboard,KeyCode=KC[route],Position=V3(0,0,0)},false)end
end
local function press1(rank,kind,idx)
 local run,bag=begin(rank,kind)
 local tag=names[rank]..' '..kind
 if not check(run and run.Kind==expectKind[kind],tag..': starts as '..expectKind[kind]..' ('..tostring(run and run.Kind)..')')then reset();return end
 local tl=run.TL;local hit=tl.Climax or tl.Burst or 0
 -- (the expectation is worked out here from the timeline itself: when the seed is shown and when its animation ends)
 local shown=math.max(hit,tl.Rise or 0,tl.Odds or 0);local from=math.max(shown,tl.FloatEnd or 0);local thr=from+AFTER
 check(from>shown+.15 and thr>shown+.4,tag..fmt(': the animation outlasts the first showing of the seed (shown %.2f s, played out %.2f s)',shown,from))
 check(L.CollectFrom~=nil and near(L.CollectFrom(tl),from,1e-9),tag..': RarePullRules.CollectFrom is max(ShownAt, FloatEnd) of the real timeline')
 check(near(run.CollectFrom,from,1e-9)and run.Beats and near(run.Beats.CollectFrom,from,1e-9),tag..': the run and its waiting beats carry the real CollectFrom'..(run.Kind=='Scene'and' (its beats push FloatEnd to Forever)'or''))
 if run.Kind=='Scene'then check(run.Beats.FloatEnd==M.Forever,tag..': (a scene waits on beats whose FloatEnd is far away: the real timeline is what counts)')end
 local gui=revealGui();local skipBtn=X.find(gui,'Skip button')
 -- Common..Mythic: no SKIP button, Enter / B / R2 skip nothing; the others have it
 if tl.SkipFrom==nil then
  check(skipBtn==nil,tag..': no SKIP button on this presentation')
 else
  check(skipBtn~=nil,tag..': the SKIP button is there (Secret / Cosmic / King)')
 end
 -- (a) from the first frame to the hit: clicks never skip; Enter / B / R2 skip nothing before SkipFrom (nor at all on a card without one)
 local n,bad
 if hit>.05 then
  if tl.SkipFrom then
   n,bad=storm(run,tl.SkipFrom-.06,true)
   check(not bad and not run.Skipped,tag..': a burst of clicks / taps and Enter / B / R2 from the first frame until the SKIP button shows does nothing ('..n..' frames'..(bad and', '..bad or'')..')')
   local stopAt=math.min(tl.SkipFrom+.45,hit-.3)
   n,bad=storm(run,stopAt,false)
   check(not bad and not run.Skipped,tag..': and clicks / taps through the SKIP button\'s window never skip ('..n..' frames'..(bad and', '..bad or'')..')')
   local b=X.find(X.pg,'Skip button')
   check(b and b.Visible,tag..': the SKIP button shows at '..fmt('%.2f',run.Clock())..' s (SkipFrom '..tl.SkipFrom..')')
   -- the skip: the button itself / its keys, from the first frame it shows, straight to the hit; never a collect
   local route=routes[(idx+rank)%4+1];local before=run.Clock()
   skipWith(run,route)
   check(run.Skipped==1 and near(run.Clock(),hit-.02,.04)and not run.Collected,tag..fmt(': %s on the SKIP button jumps straight to the hit (%.2f -> %.2f s, the hit %.2f s)',route=='button'and'a press'or route,before,run.Clock(),hit))
  else
   n,bad=storm(run,hit-.03,true)
   check(not bad and not run.Skipped,tag..': R157: clicks / taps and Enter / B / R2 from the first frame to the hit skip nothing ('..n..' frames'..(bad and', '..bad or'')..')')
  end
 end
 -- (b) from the hit to just before the whole animation has played + CollectAfter: every press, every frame: nothing collects, ends or moves the clock
 n,bad=storm(run,thr-.15,true)
 check(not bad,tag..fmt(': a burst of every kind of press from the hit to %.2f s (the seed is shown from %.2f s, its animation ends %.2f s) never collects it (%d frames%s)',thr-.15,shown,from,n,bad and', '..bad or''))
 -- (c) the last stretch with the director's own calls (they skip ClaimPress's window): not before CollectFrom + CollectAfter, to the frame
 local early=false;local g=0
 while run.Clock()<thr-DT*.6 and not run.Done and g<600 do
  if M.Tap()or M.Skip()or M.Collect()or M.Collect('press')or run.Collected then early=true end
  frame();g+=1
 end
 check(not early and not run.Collected and M.Active()==run,tag..fmt(': nothing collects it up to the frame before %.2f s (CollectFrom %.2f + CollectAfter)',thr,from))
 untilClock(run,thr+.005)
 -- (d) a press that begins now collects
 realClick(run)
 check(run.Collected and run.CollectWhy=='press',tag..fmt(': a press that begins at %.2f s (CollectFrom + CollectAfter) collects it (%s)',run.Clock(),tostring(run.CollectWhy)))
 settleOut(run)
 check(M.Active()==nil,tag..': and it ends')
 reset();bag:Destroy()
end
-- 2. every presentation, nobody pressing: the hint, a menu opened before CollectFrom, a touch begun earlier -----------------------------------------
local function quiet1(rank,kind)
 local run,bag=begin(rank,kind)
 local tag=names[rank]..' '..kind..' (left alone)'
 if not check(run and run.Kind==expectKind[kind],tag..': starts as '..expectKind[kind])then reset();return end
 local tl=run.TL;local hit=tl.Climax or tl.Burst or 0
 local shown=math.max(hit,tl.Rise or 0,tl.Odds or 0);local from=math.max(shown,tl.FloatEnd or 0);local thr=from+AFTER
 local hintEarly,hintLate,menuAt=false,false,nil
 local function look()
  local h=X.find(revealGui(),'Skip hint')
  if h and h.Visible and run.Clock()<thr-.001 then hintEarly=true end
  if menuAt==nil and run.SawResult and not run.Collected then X.pg:SetAttribute('SeedMenu','Economy');menuAt=run.Clock()end -- (a menu OPENS while the animation plays: after the first check)
 end
 -- the player does not touch it; a menu opens just after the seed shows
 untilClock(run,thr+.1,look)
 check(menuAt~=nil and menuAt<from,tag..fmt(': (a menu opened at %.2f s, before the animation ended at %.2f s)',menuAt or -1,from))
 check(not hintEarly,tag..': the collect hint never shows while a click still does nothing (before '..fmt('%.2f',thr)..' s)')
 check(not run.Collected and not run.Done and M.Active()==run,tag..': R158m: a menu opening before the animation has played is ignored: it plays on, the result waits ('..tostring(run.CollectWhy)..')')
 untilClock(run,thr+.5,look)
 local h=X.find(revealGui(),'Skip hint')
 check(h and h.Visible and tostring(h.Text):match('collect')~=nil,tag..': once a press lands the hint says so ("'..tostring(h and h.Text)..'")')
 check(not run.Collected and M.Waiting(),tag..': and the result still waits for the click (the menu is open, as before)')
 -- a touch that began before CollectFrom + CollectAfter and is released after it does not collect; one that begins after does
 X.pg:SetAttribute('SeedMenu',nil);X.run(.3)
 if run.Kind~='Scene'then
  local began={UserInputType=UT.Touch,KeyCode=KC.Unknown,Position=V3(300,200,0)}
  -- (a press that began at CollectFrom + CollectAfter - .2 and ends .3 s later: handed to the director as the touch route does: M.Tap(began))
  local at=R.clock
  M.Tap(at-(run.Clock()-(thr-.2)))
  check(not run.Collected,tag..': a press that began 0.2 s before CollectFrom + CollectAfter and ended after it does not collect')
 else
  local b=X.find(X.pg,'Backdrop')
  if b then b.InputBegan:Fire({UserInputType=UT.MouseButton1})end
 end
 realClick(run)
 check(run.Collected and run.CollectWhy=='press',tag..': the next press collects it')
 settleOut(run);reset();bag:Destroy()
end
for i,v in ipairs(variants)do press1(v[1],v[2],i)end
for _,v in ipairs(variants)do quiet1(v[1],v[2])end
-- 3. M.Collect: a player's collect waits, the others do not -----------------------------------------------------------------------------------
do
 for _,c in ipairs({{4,'Card'},{6,'Full'}})do
  local run,bag=begin(c[1],c[2]);local tl=run.TL
  local shown=math.max(tl.Climax or tl.Burst,tl.Rise or 0,tl.Odds or 0);local from=math.max(shown,tl.FloatEnd or 0)
  local tag=names[c[1]]..' '..c[2]..': M.Collect'
  untilClock(run,shown+.1)
  check(run.SawResult and M.Collect()==false and M.Collect('press')==false and not run.Collected,tag..': the seed is shown but its animation goes on: a press-like collect answers false')
  untilClock(run,from+.1)
  check(M.Collect()==false and not run.Collected,tag..': it has just played out: CollectAfter still holds a press-like collect back')
  untilClock(run,from+AFTER+.02)
  check(M.Collect()==true and run.Collected and run.CollectWhy=='press',tag..': CollectAfter after it has played out it collects as a press')
  settleOut(run);reset();bag:Destroy()
  run,bag=begin(c[1],c[2])
  untilClock(run,shown+.1)
  check(M.Collect('bag')==true and run.Collected and run.CollectWhy=='bag',tag..'("bag"): any other reason (the player taken away from it) collects at once, as before')
  settleOut(run);reset();bag:Destroy()
 end
end
-- 4. what takes the player away still collects at once -----------------------------------------------------------------------------------------
do
 local function ends(rank,kind,name,when,how,why)
  local run,bag=begin(rank,kind);local tl=run.TL;local hit=tl.Climax or tl.Burst
  local shown=math.max(hit,tl.Rise or 0,tl.Odds or 0);local from=math.max(shown,tl.FloatEnd or 0)
  local at=when=='hit'and hit+.03 or shown+.12
  untilClock(run,at)
  local tag=names[rank]..' '..kind..': '..name..fmt(' at %.2f s (%s the animation ends at %.2f s)',run.Clock(),run.Clock()<from and'before'or'after',from)
  if not check(not run.Done and not run.Collected and run.Clock()<from,tag..': (still playing)')then reset();bag:Destroy();return end
  how(run)
  local g=0;while M.Active()==run and g<30 do frame();g+=1 end
  check(run.Collected and run.Done and(why==nil or run.CollectWhy==why or run.CollectWhy=='danger'and(why=='chase'or why=='ragdoll'or why=='teleport'or why=='death')or run.CollectWhy=='moved'and why=='teleport'),
   tag..' collects the result at once, the seed flies home ('..tostring(run.CollectWhy)..', '..g..' frames)')
  settleOut(run);reset();bag:Destroy()
 end
 for _,c in ipairs({{4,'Card'},{5,'Card'},{6,'Full'},{8,'Full'},{7,'InPlace'}})do
  ends(c[1],c[2],'death','hit',function()X.hum.Died:Fire();X.player.CharacterRemoving:Fire(X.char)end,'death')
  ends(c[1],c[2],'death (health 0)','tail',function()X.hum.Health=0 end,'death')
  ends(c[1],c[2],'a teleport','tail',function()X.root.CFrame=CF(0,3,400)end,'teleport')
  ends(c[1],c[2],'a chase starting','tail',function()X.player:SetAttribute('ChestChaseRunActive',true)end,'chase')
  ends(c[1],c[2],'the next pack','tail',function()local _,b2=start(2);b2:Destroy()end,'replaced')
 end
 -- a menu opening AFTER the animation has played still collects it, as before
 for _,c in ipairs({{4,'Card'},{6,'Full'}})do
  local run,bag=begin(c[1],c[2]);local tl=run.TL
  local shown=math.max(tl.Climax or tl.Burst,tl.Rise or 0,tl.Odds or 0);local from=math.max(shown,tl.FloatEnd or 0)
  untilClock(run,from+.4)
  X.pg:SetAttribute('SeedMenu','Economy')
  local g=0;while not run.Collected and g<40 do frame();g+=1 end
  check(run.Collected and run.CollectWhy=='menu',names[c[1]]..' '..c[2]..': a menu opening once the animation has played collects the waiting result, as before ('..tostring(run.CollectWhy)..')')
  settleOut(run);reset();bag:Destroy()
 end
end
-- 5. the next pack: held the moment it is put in the hand, its clicks never reach the server while a reveal runs --------------------------------
do
 for _,c in ipairs({{4,'Card'},{7,'Full'},{6,'InPlace'},{3,'Quick'}})do
  local run,bag=begin(c[1],c[2]);local tl=run.TL
  local tag=names[c[1]]..' '..c[2]..': the next pack in the hand'
  local shown=math.max(tl.Climax or tl.Burst,tl.Rise or 0,tl.Odds or 0);local from=math.max(shown,tl.FloatEnd or 0)
  local away=R.new('Folder');away.Name='Backpack';away.Parent=X.player
  local activations=0
  local nextPack=F.tool(W,'Seed Pack',{SeedPackTool=true,SeedInventoryId='next'..c[1],Stage=2},away)
  nextPack.ManualActivationOnly=false;nextPack.Enabled=true
  -- the engine: a click activates a tool in the hand unless it is ManualActivationOnly; the server opens a pack on its 5th activation
  local function engineClick()if nextPack.Parent==X.char and nextPack.Enabled~=false and not nextPack.ManualActivationOnly then activations+=1 end end
  local function equip()nextPack.Parent=X.char end
  local function putAway()nextPack.Parent=away end
  equip()
  check(nextPack.ManualActivationOnly==true,tag..': held on the very frame it is equipped (no gap until the next render step)')
  local reached=0
  for i=1,40 do engineClick();clicks(run);frame();if run.Collected or run.Done then break end;reached=i end
  check(activations==0 and reached==40,tag..': 40 clicks on it, a frame apart, never activate it ('..activations..' did; the server opens a pack on the 5th)')
  -- unequipped and equipped again, over and over: each equip is held at once, so no click of any cycle gets through
  local leaked=0
  for _=1,6 do
   putAway();frame();local freed=nextPack.ManualActivationOnly==false
   equip();engineClick();if activations>0 then leaked+=1 end
   frame();engineClick();if not freed then leaked+=1 end
  end
  check(leaked==0 and activations==0,tag..': 6 times put away and taken out again with a click each time: nothing gets through')
  -- until the animation has played out and the player collects: then the tool is theirs again
  untilClock(run,from+AFTER+.1)
  check(nextPack.ManualActivationOnly==true and not run.Collected,tag..': still held while the result waits')
  X.run(.2);realClick(run)
  check(run.Collected,tag..': (the player collects the result)')
  settleOut(run)
  check(nextPack.ManualActivationOnly==false,tag..': after the collect the pack is the player\'s again (its clicks count)')
  engineClick();check(activations==1,tag..': and a click on it activates it')
  nextPack:Destroy();away:Destroy();reset();bag:Destroy()
 end
end
print(('R158m unskippable checks %d, fails %d (%d presentations)'):format(checks,fails,#variants))
if fails>0 then error('failures')end
