--!nocheck
-- R150 treadmill bonus UI behaviour under the Roblox mock (real TreadmillBonusClient + TreadmillBonusStyle + BonusGiftArt + rules).
-- A stepping TweenService (ui_world) lets pops settle over the mock clock; scheduled work is counted through task.delay.
local UW=require('./ui_world');local W,R=UW.W,UW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local C=UW.boot({})
local Rules,me,pg=C.Rules,C.Me,C.PG
local Style=W.module('TreadmillBonusStyle')
local button,bar,overlay,hud=C.Button,C.Bar,C.Overlay,C.Hud
local face=button.Face
local function frames(n)UW.frames(n,1/60)end
local function secs(s)UW.seconds(s,1/60)end
UW.frames(3,1/60)
local baseHud,baseOverlay,baseBar=UW.count(hud),UW.count(overlay),UW.count(bar)
local function training(on)me:SetAttribute('TreadmillTraining',on or nil)end
-- 0. Idle: nothing runs ----------------------------------------------------------------------------------------------
local d0=UW.delays
secs(30)
check(button.Visible==false and bar.Enabled==false and overlay.Enabled==false,'idle: no button, no gift timer, no roll window')
check(UW.frameListeners()==0,'idle: not a single per-frame listener ('..UW.frameListeners()..')')
check((C.RevealPreloads or 0)>=1,'the reveal / cue voices are preloaded at script start')
check(UW.delays==d0,'idle: no scheduled work at all in 30 s ('..(UW.delays-d0)..')')
check(bar.ClipsDescendants==false and bar.AlwaysOnTop==true and bar.MaxDistance==80 and bar.Size.X.Offset>=240 and bar.Size.Y.Offset>=110,'gift timer billboard: not clipped, room for the pop')
-- 1. Button: charging -------------------------------------------------------------------------------------------------
C.set('Interval',360);C.set('Ready',0)
C.set('DueAt',R.clock+222);C.set('Left',222);training(true)
frames(20)
check(button.Visible==true,'charging: the button shows while standing on the treadmill')
check(face.Title.Text=='BONUS ROLL' and face.Sub.Text=='NEXT 3:42','charging: second line counts down: '..face.Sub.Text)
check(face.Fill.Visible==true and near(face.Fill.Size.X.Scale,1-221.67/360,.01),'charging: the face fills with progress ('..face.Fill.Size.X.Scale..')')
check(face.Meter.Visible==false and button.CountBadge.Visible==false,'charging: no meter strip, no badge')
local calmLip=button.Lip.BackgroundColor3
check(button:GetAttribute('AccessibleLabel')=='Treadmill bonus roll, charging','charging: accessibility label says so')
check(face.Icon.Visible==true and face.Icon.Body.Fill.Color.A~=nil,'charging: the gift icon fills up with the progress')
local f1=face.Fill.Size.X.Scale
secs(10)
check(face.Sub.Text=='NEXT 3:32' and face.Fill.Size.X.Scale>f1,'charging: ten seconds later the clock and the fill moved ('..face.Sub.Text..')')
C.set('DueAt',R.clock+24);frames(20)
check(face.Sub.Text:find('^ALMOST! 0:')~=nil,'last 30 s: ALMOST! '..face.Sub.Text)
C.set('DueAt',R.clock+31);frames(20)
check(face.Sub.Text:find('^NEXT 0:')~=nil,'31 s left is still NEXT')
-- tapping while charging asks nothing of the server
local before=C.Invoked
C.set('DueAt',R.clock+200);frames(20)
button.Activated:Fire()
check(C.Invoked==before and overlay.Enabled==false,'charging: a tap does not call the server and opens nothing')
check(face.Sub.Text:find('^NEXT IN 3:')~=nil,'charging: a tap says when: '..face.Sub.Text)
check(UW.frameListeners()>=1,'the little "no" nudge runs for a moment')
secs(3);check(face.Sub.Text:find('^NEXT 3:')~=nil and face.Position.X.Offset==0 and face.Position.Y.Offset==0,'the message clears after ~2.5 s and the face is back in place')
-- 2. Button: ready, count, pops ----------------------------------------------------------------------------------------
secs(2)
UW.frames(1,1/60)
local hudFx=hud.Fx
C.set('DueAt',R.clock+250);C.set('Left',250)
C.set('Ready',1);frames(2)
check(button.Visible==true and face.Sub.Text=='READY!' and face.Fill.Visible==false,'ready: READY!, no charging fill')
check(button.Lip.BackgroundColor3~=calmLip,'ready: the lip took the cheerful colour')
check(face.Meter.Visible==true and face.Meter.Bar.Size.X.Scale>0,'ready with the next one charging: a thin meter shows it')
check(button.CountBadge.Visible==false,'ready (1): no count badge')
check(button:GetAttribute('AccessibleLabel')=='Treadmill bonus roll, ready','ready: accessibility label')
check(#hudFx:GetChildren()==8 and button.Pulse.Scale<1,'a roll becoming ready: sparkle burst (8) and the button pops in ('..#hudFx:GetChildren()..', '..button.Pulse.Scale..')')
secs(.6);check(near(button.Pulse.Scale,1,.001),'the pop settles at 1')
secs(1);check(#hudFx:GetChildren()==0,'the sparkles are gone after ~1 s (nothing left behind)')
-- the attention loop: a wiggle burst every ~4.2 s, nothing per frame in between
local maxRot=0;local shineSeen=false;local scaleMax=1
local t0=R.clock;local at={}
for step=1,60*14 do
 UW.frames(1,1/60)
 local clock=R.clock-t0
 local n=UW.frameListeners()
 at[#at+1]={clock,n}
 maxRot=math.max(maxRot,math.abs(face.Icon.Rotation))
 scaleMax=math.max(scaleMax,button.Pulse.Scale)
 if face.ShinePane.Sweep.Visible then shineSeen=true end
end
local bursts,idleFrames,lastWas=0,0,0
for _,s in ipairs(at)do
 if s[2]>0 and lastWas==0 then bursts+=1 end
 if s[2]==0 then idleFrames+=1 end
 lastWas=s[2]
end
check(maxRot>6 and maxRot<=12.5,'ready: the gift wiggles ('..maxRot..' deg at most)')
check(shineSeen,'ready: a shine sweeps across')
check(scaleMax>1.02 and scaleMax<=1.06,'ready: a small bounce (max scale '..scaleMax..')')
check(bursts>=3 and bursts<=4,'ready: one attention burst about every 4.2 s ('..bursts..' in 14 s)')
check(idleFrames>=60*14*.65,'ready: no per-frame listener between the bursts ('..idleFrames..' of '..(60*14)..' frames idle)')
check(near(face.Icon.Rotation,0,1e-6) and face.ShinePane.Sweep.Visible==false and near(button.Pulse.Scale,1,1e-6),'everything rests at neutral between bursts')
-- count 2: badge
C.set('Ready',2);frames(2)
check(button.CountBadge.Visible==true and button.CountBadge.Count.Text=='2','two ready: the count badge shows 2')
check(face.Meter.Visible==false,'two ready: no meter (the timer is paused at the cap)')
check(button.CountBadge.Pop.Scale>1.2,'the badge pops when the count changes ('..button.CountBadge.Pop.Scale..')')
secs(.5);check(near(button.CountBadge.Pop.Scale,1,.001),'the badge pop settles')
check(button.CountBadge.Position.X.Offset<face.Title.Position.X.Offset,'two ready: the badge sits on the gift icon, left of the title')
-- one used: badge gone, no pop on a decrease
local fxBefore=#hudFx:GetChildren()
C.set('Ready',1);frames(2)
check(button.CountBadge.Visible==false and #hudFx:GetChildren()==fxBefore,'a roll used: badge hides, no celebration on a decrease')
-- press feedback
local MB=R.Enum.UserInputType.MouseButton1
button.InputBegan:Fire({UserInputType=MB})
check(face.Position.Y.Offset==3,'pressed: the face sinks onto the lip')
button.InputEnded:Fire({UserInputType=MB})
check(face.Position.Y.Offset==0,'released: the face rises')
button.InputBegan:Fire({UserInputType=R.Enum.UserInputType.Touch});button.MouseLeave:Fire()
check(face.Position.Y.Offset==0,'finger slides off: the face rises')
button.InputBegan:Fire({UserInputType=R.Enum.UserInputType.Keyboard})
check(face.Position.Y.Offset==0,'other input does not press it')
-- title screen hides it
pg:SetAttribute('TitleActive',true);frames(1);check(button.Visible==false,'the title screen hides the button');pg:SetAttribute('TitleActive',nil);frames(1);check(button.Visible==true,'and it comes back')
-- off the treadmill with nothing ready: hidden, and the ticker stops
C.set('Ready',0);training(false);frames(2)
check(button.Visible==false and bar.Enabled==false,'off the treadmill with nothing ready: no button, no timer')
d0=UW.delays;secs(10);check(UW.delays==d0 and UW.frameListeners()==0,'...and nothing scheduled (idle again)')
-- refusal on the button
C.set('Ready',1);frames(2)
C.Reply={Error='SEED BAG FULL! Make room - your roll stays ready.',Ready=1}
button.Activated:Fire()
check(face.Sub.Text=='BAG FULL!' and #face.Sub.Text<=15,'refusal: short copy on the button ('..face.Sub.Text..')')
check(button:GetAttribute('AccessibleLabel'):find('SEED BAG FULL')~=nil,'refusal: the full text goes to the accessibility label')
check(overlay.Enabled==false,'refusal: no roll window')
secs(3)
check(button:GetAttribute('AccessibleLabel')=='Treadmill bonus roll, ready' and face.Sub.Text=='READY!','after the message the accessibility label and the status line are back to normal')
C.set('Ready',0);frames(2)
-- ReducedMotion: the button shows and says everything, nothing moves
W.Gui.ReducedMotionEnabled=true
d0=UW.delays
C.set('Ready',1);frames(2)
check(button.Visible==true and button.Pulse.Scale==1 and #hudFx:GetChildren()==0,'ReducedMotion: ready shows, no pop, no sparkles')
local movers=0;for i=1,60*10 do UW.frames(1,1/60);if UW.frameListeners()>0 or face.Icon.Rotation~=0 or button.Pulse.Scale~=1 then movers+=1 end end
check(movers==0,'ReducedMotion: the ready button never moves or runs a listener in 10 s ('..movers..')')
C.set('Ready',2);frames(2);check(button.CountBadge.Pop.Scale==1,'ReducedMotion: no badge pop')
W.Gui.ReducedMotionEnabled=false
C.set('Ready',0);frames(2)
-- low quality (FastMode): fewer sparkles, no sweep
me:SetAttribute('FastMode',true)
C.set('Ready',1);frames(2)
check(#hudFx:GetChildren()==3,'FastMode: a small sparkle burst (3) ('..#hudFx:GetChildren()..')')
local sweeps=false;for i=1,60*6 do UW.frames(1,1/60);if face.ShinePane.Sweep.Visible then sweeps=true end end
check(sweeps==false,'FastMode: no shine sweep')
me:SetAttribute('FastMode',nil);C.set('Ready',0);frames(2);secs(2)
-- 3. Gift timer ----------------------------------------------------------------------------------------------------
local back=bar.Back
local function barText()return back.Caption.Text,back.Track.Label.Text end
C.set('Ready',0);C.set('Interval',360);C.set('DueAt',R.clock+222);C.set('Left',222);training(true);frames(20)
check(bar.Enabled==true and bar.Adornee==C.Root,'timer shows over the player while training')
local cap,clock=barText()
check(cap=='NEXT ROLL' and clock:find('^3:4')~=nil,'timer: caption + countdown ('..cap..' / '..clock..')')
local px=back.Track.Fill.Size.X.Offset
check(near(px,math.floor((1-221.67/360)*120+.5),1.1),'timer: fill = progress ('..px..' of 120)')
check(back.Chip.Visible==false,'timer: no count chip with nothing ready')
check(bar.StudsOffsetWorldSpace.Y>5,'timer: above the head, clear of speed popups')
local before1=px;secs(30);check(back.Track.Fill.Size.X.Offset>before1,'timer: the fill grows with time')
-- almost there
C.set('DueAt',R.clock+20);frames(20)
cap,clock=barText()
check(cap=='ALMOST THERE!' and clock:find('^0:')~=nil,'timer, last 30 s: '..cap..' '..clock)
local rotMax=0;for i=1,60*5 do UW.frames(1,1/60);rotMax=math.max(rotMax,math.abs(back.Icon.Rotation))end
check(rotMax>6 and rotMax<=12.5,'timer, almost there: the gift wiggles ('..rotMax..')')
check(near(back.Icon.Rotation,0,12.5),'timer: wiggle in range')
-- a roll completes while the timer is showing: pop
local fxBar=bar.Fx
C.set('DueAt',R.clock+360);C.set('Left',360)
C.set('Ready',1);frames(1)
cap,clock=barText()
check(cap:find('BONUS READY!')~=nil and clock=='OPEN IT!','timer: a roll completing says BONUS READY! / OPEN IT!')
check(back.Pop.Scale>1.1 and back.Pop.Scale<=1.18,'timer: the pill pops ('..back.Pop.Scale..')')
local shakeMax=0;local sparkMax=#fxBar:GetChildren()
for i=1,40 do UW.frames(1,1/60);shakeMax=math.max(shakeMax,math.abs(back.Rotation));sparkMax=math.max(sparkMax,#fxBar:GetChildren())end
check(shakeMax>2 and shakeMax<=6.01,'timer: a small shake ('..shakeMax..' deg)')
check(sparkMax==8,'timer: sparkles pop (8) ('..sparkMax..')')
check(near(back.Pop.Scale,1,.001) and back.Rotation==0,'timer: pop and shake settle')
check(back.Chip.Visible==true and back.Chip.Count.Text=='1','timer: a chip shows 1 ready')
secs(1);check(#fxBar:GetChildren()==0,'timer: sparkles removed')
secs(2.6)
cap,clock=barText()
check(cap=='NEXT ROLL' and clock:find('^[56]:')~=nil,'timer: after ~3 s it goes back to counting ('..cap..' '..clock..')')
-- at the cap
C.set('DueAt',nil);C.set('Ready',2);frames(1)
secs(3.5)
cap,clock=barText()
check(cap=='2 ROLLS READY!' and clock=='TAP BONUS ROLL' and back.Track.Fill.Size.X.Offset==120,'timer at the cap: says so, full ('..cap..')')
check(back.Chip.Count.Text=='2','timer at the cap: chip 2')
d0=UW.delays;secs(5);check(UW.delays-d0>=15 and UW.delays-d0<=25,'timer: ticks about 4 times a second while on the treadmill, nothing per frame ('..(UW.delays-d0)..' in 5 s)')
check(UW.frameListeners()==0,'timer: no per-frame listener while it just counts')
-- off the treadmill
training(false);frames(2);check(bar.Enabled==false,'timer hides off the treadmill')
C.set('Ready',1);frames(2);check(#fxBar:GetChildren()==0,'no pop while the timer is hidden')
C.set('Ready',0);frames(2);secs(2)
-- ReducedMotion on the timer
W.Gui.ReducedMotionEnabled=true
C.set('DueAt',R.clock+10);training(true);frames(5)
check(barText()=='ALMOST THERE!','reduced: still says almost there')
rotMax=0;for i=1,60*5 do UW.frames(1,1/60);rotMax=math.max(rotMax,math.abs(back.Icon.Rotation))end
check(rotMax==0 and UW.frameListeners()==0,'ReducedMotion: the timer gift does not wiggle')
C.set('Ready',1);frames(2)
check(barText()=='BONUS READY! 🎁' and back.Pop.Scale==1 and #fxBar:GetChildren()==0,'ReducedMotion: the ready line shows, no pop, no sparkles')
W.Gui.ReducedMotionEnabled=false
training(false);C.set('Ready',0);frames(5);secs(4)
-- 4. Roll screen flow, all seven rarities --------------------------------------------------------------------------------
local panel=overlay.Panel
local cases={
 {Rarity='Common',Variant='Pack01',Stage=1,Label='Forest Seed Pack'},{Rarity='Uncommon',Variant='Pack02',Stage=6,Label='Jungle Seed Pack'},
 {Rarity='Rare',Variant='Pack03',Stage=2,Label='Desert Seed Pack'},{Rarity='Epic',Variant='Pack04',Stage=3,Label='Snow Seed Pack'},
 {Rarity='Legendary',Variant='Pack05',Stage=4,Label='Lava Seed Pack'},{Rarity='Mythic',Variant='Pack06',Stage=5,Label='Crystal Seed Pack'},
 {Rarity='Secret',Variant='EclipseReliquary',Stage=7,Label='Void Pack'},
}
local function sameColor(a,b)return near(a.R,b.R,.002)and near(a.G,b.G,.002)and near(a.B,b.B,.002)end
local function openRoll(case,readyAfter)
 C.Reply={Ok=true,Stage=case.Stage,Variant=case.Variant,Rarity=case.Rarity,Label=case.Label,Pool='1,6,2,3,4,5,7',Ready=readyAfter or 0}
 C.set('Ready',1);frames(1)
 button.Activated:Fire()
 panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset)
end
local function spinOut(maxFrames)
 local n=0;while panel.Actions.Skip.Visible and n<(maxFrames or 2000)do UW.frames(1,1/60);n+=1 end
 return n/60
end
local ovBase=UW.count(overlay)
for _,case in ipairs(cases)do
 local style=Style.Reveal(case.Rarity);local tierName,tierColor=Rules.Tier(case.Variant)
 local special=Rules.Special[case.Rarity]==true
 openRoll(case,0)
 local tag=case.Rarity
 check(overlay.Enabled==true and C.Invoked>0,tag..': the roll window opens')
 check(panel.Status.Visible==true and panel.Word.Visible==false and panel.Status.Text==Style.SpinLines[1],tag..': spinning: playful status line '..panel.Status.Text)
 check(panel.Result.Text==Style.SpinHint,tag..': spinning: reassurance line under it')
 check(panel.Actions.Skip.Visible and not panel.Actions.Close.Visible,tag..': SKIP while spinning')
 check(panel.Pop.Scale<1,tag..': the panel pops in ('..panel.Pop.Scale..')')
 check(UW.frameListeners()==2,tag..': while it spins: the spin and the one animator listener ('..UW.frameListeners()..')')
 -- status lines in order over the spin
 local seen,order={},{}
 local pointerYs={}
 local took=0
 while panel.Actions.Skip.Visible and took<2000 do
  UW.frames(1,1/60);took+=1
  local text=panel.Status.Text
  if not seen[text]and panel.Status.Visible then seen[text]=true;order[#order+1]=text end
  pointerYs[#pointerYs+1]=panel.PointerTop.Position.Y.Offset
 end
 check(took/60>=Rules.Strip.Duration-.1 and took/60<=Rules.Strip.Duration+.15,tag..': the spin still takes '..Rules.Strip.Duration..' s ('..took/60 ..')')
 local inOrder=#order==4;for i=1,#order do if order[i]~=Style.SpinLines[i]then inOrder=false end end
 check(inOrder,tag..': all four status lines appeared in order ('..#order..')')
 local lo,hi=math.huge,-math.huge;for _,y in ipairs(pointerYs)do lo=math.min(lo,y);hi=math.max(hi,y)end
 check(hi-lo>=3 and hi-lo<=12,tag..': the pointers bounce / flick ('..(hi-lo)..' px)')
 -- the reveal
 check(panel.Actions.Close.Visible and not panel.Actions.Skip.Visible,tag..': CLOSE after the stop')
 check(panel.Word.Visible and panel.Word.Text==style.Word and not panel.Status.Visible,tag..': reveal word '..style.Word)
 check(sameColor(panel.Word.TextColor3,tierColor),tag..': the word takes the rarity colour')
 check(panel.Result.Text:find(string.upper(case.Rarity))~=nil and panel.Result.Text:find(case.Label,1,true)~=nil,tag..': result sentence names it: '..panel.Result.Text)
 check(panel.Actions.Close.Face.Label.Text==style.Close,tag..': close caption '..style.Close)
 check(panel.Word.Pop.Scale<1 or UW.activeTweens()>0,tag..': the word pops (a tween is running)')
 local strip=panel.StripWindow.Strip
 local winner=strip['Card'..Rules.Strip.Win]
 local rays=strip:FindFirstChild('Rays')
 check(rays~=nil and #rays:GetChildren()==style.Beams,tag..': '..style.Beams..' light beams behind the winner')
 if rays then
  local beam=rays:GetChildren()[1]
  check(near(beam.BackgroundTransparency,style.Alpha,1e-6) and beam.Core~=nil,tag..': rays strength follows the rarity')
  check(rays.ZIndex>5 and rays.ZIndex<winner.ZIndex and winner.ZIndex==8,tag..': rays sit above the other cards and below the winner')
  check(near(rays.Position.X.Offset,(Rules.Strip.Win-1)*Rules.Strip.Pitch+Rules.Strip.CardWidth/2),tag..': rays centred on the winning card')
 end
 local fxCount=#overlay.Fx:GetChildren()
 check(fxCount==style.Sparkles+style.Confetti,tag..': sparkles '..style.Sparkles..' + confetti '..style.Confetti..' = '..fxCount)
 check(winner:FindFirstChild('ShinePane')~=nil,tag..': a soft shine sweeps the winner')
 if special then check(winner:FindFirstChild('BorderGlow')~=nil,tag..': special: border light-up still there')else check(winner:FindFirstChild('BorderGlow')==nil,tag..': no border light-up for '..tag)end
 -- rays turn
 local r1=rays and rays.Rotation or 0;secs(.5);local r2=rays and rays.Rotation or 0
 check(r2~=r1,tag..': the rays turn slowly ('..r1..' -> '..r2..')')
 secs(2)
 check(#overlay.Fx:GetChildren()==0,tag..': confetti and sparkles are gone after ~2 s')
 check(winner:FindFirstChild('ShinePane')==nil,tag..': the shine pane is removed after its sweep')
 check(UW.frameListeners()==1,tag..': after the reveal only the ambient animator runs ('..UW.frameListeners()..')')
 panel.Actions.Close.Activated:Fire()
 check(overlay.Enabled==false and UW.frameListeners()==0,tag..': closed: no listener left')
 check(UW.count(overlay)==ovBase,tag..': closed: the overlay is back to its bare size ('..UW.count(overlay)..' vs '..ovBase..')')
 secs(2);check(UW.activeTweens()<=1,tag..': no tween left running ('..UW.activeTweens()..')')
end
-- Skip, roll again, close mid-way ----------------------------------------------------------------------------------------
openRoll(cases[5],1)
frames(30);panel.Actions.Skip.Activated:Fire()
check(panel.Actions.Close.Visible and panel.Word.Text=='LEGENDARY!' and panel.Actions.Again.Visible,'Skip jumps to the reveal; ROLL AGAIN shows with one ready')
check(panel.Actions.Again.Face.Label.Text=='ROLL AGAIN (1)','roll again caption carries the count: '..panel.Actions.Again.Face.Label.Text)
C.Reply={Ok=true,Stage=1,Variant='Pack01',Rarity='Common',Label='Forest Seed Pack',Pool='1',Ready=0}
local invokedBefore=C.Invoked
panel.Actions.Again.Activated:Fire()
check(C.Invoked==invokedBefore+1 and overlay.Enabled==true and panel.Word.Visible==false and panel.Status.Visible==true and #overlay.Fx:GetChildren()==0,'ROLL AGAIN: closes, asks once, a fresh spin with a clean screen')
check(panel.Result.Text==Style.SpinHint and panel:FindFirstChild('Pop')~=nil and panel.StripWindow.Strip:FindFirstChild('Rays')==nil,'ROLL AGAIN: no leftovers from the last reveal')
spinOut();panel.Actions.Close.Activated:Fire()
-- ReducedMotion roll ---------------------------------------------------------------------------------------------------------
W.Gui.ReducedMotionEnabled=true
openRoll(cases[5],0)
check(panel.Pop.Scale==1,'ReducedMotion: the panel does not pop in')
local movedPointer=false;local y0=panel.PointerTop.Position.Y.Offset
local took2=0;while panel.Actions.Skip.Visible and took2<600 do UW.frames(1,1/60);took2+=1;if panel.PointerTop.Position.Y.Offset~=y0 then movedPointer=true end end
check(took2/60<=Rules.Strip.ReducedDuration+.1,'ReducedMotion: short spin ('..took2/60 ..' s)')
check(not movedPointer and UW.frameListeners()==0,'ReducedMotion: no ambient motion and no listener after the stop ('..UW.frameListeners()..')')
check(panel.Word.Visible and panel.Word.Pop.Scale==1 and #overlay.Fx:GetChildren()==0,'ReducedMotion: the word shows without a pop, no confetti, no sparkles')
local rays2=panel.StripWindow.Strip:FindFirstChild('Rays')
check(rays2~=nil,'ReducedMotion: the rays still show (still)')
secs(2);check(rays2.Rotation==0 and panel.StripWindow.Strip['Card'..Rules.Strip.Win]:FindFirstChild('ShinePane')==nil,'ReducedMotion: rays do not turn, no shine sweep')
check(panel.StripWindow.Strip['Card'..Rules.Strip.Win]:FindFirstChild('BorderGlow')~=nil,'ReducedMotion: the border light-up stays')
panel.Actions.Close.Activated:Fire();W.Gui.ReducedMotionEnabled=false
-- low quality roll -------------------------------------------------------------------------------------------------------------
me:SetAttribute('FastMode',true)
openRoll(cases[5],0);spinOut()
local lstrip=panel.StripWindow.Strip
check(#overlay.Fx:GetChildren()==3+math.floor(Style.Reveal('Legendary').Confetti*.3),'FastMode: fewer pieces ('..#overlay.Fx:GetChildren()..')')
check(lstrip['Card'..Rules.Strip.Win]:FindFirstChild('ShinePane')==nil,'FastMode: no shine sweep')
local lr=lstrip:FindFirstChild('Rays');secs(1);check(lr~=nil and lr.Rotation==0,'FastMode: rays stay still')
local tw1=panel.Twinkle1.BackgroundTransparency;secs(.5);check(panel.Twinkle1.BackgroundTransparency==tw1,'FastMode: no twinkle updates')
panel.Actions.Close.Activated:Fire();me:SetAttribute('FastMode',nil)
-- ClientFxBudget tier 1 counts as low as well
C.Tier=1;openRoll(cases[6],0);spinOut()
check(#overlay.Fx:GetChildren()==3+math.floor(Style.Reveal('Mythic').Confetti*.3),'low tier 1: fewer pieces ('..#overlay.Fx:GetChildren()..')')
panel.Actions.Close.Activated:Fire();C.Tier=3
-- unchanged result handling: malformed replies do nothing
C.set('Ready',1);C.Reply={Ok=true,Stage=99,Variant=nil};secs(2);button.Activated:Fire()
check(overlay.Enabled==false,'a malformed reply opens nothing')
C.Reply=nil;secs(3);button.Activated:Fire();check(overlay.Enabled==false,'no reply opens nothing')
secs(3);C.set('Ready',0);frames(2)
-- 5. No leaks over repeated rolls -------------------------------------------------------------------------------------------------
local soundCount=#W.service('SoundService'):GetChildren()
local hudCount,barCount=UW.count(hud),UW.count(bar)
local worst=0
for i=1,24 do
 local case=cases[(i-1)%#cases+1]
 openRoll(case,0)
 if i%3==0 then frames(20);panel.Actions.Skip.Activated:Fire()else spinOut()end
 if i%4==0 then secs(.3)end
 panel.Actions.Close.Activated:Fire()
 worst=math.max(worst,math.abs(UW.count(overlay)-ovBase))
end
secs(3)
check(worst==0,'24 rolls: the overlay never grows (worst difference '..worst..')')
check(UW.count(hud)==hudCount and UW.count(bar)==barCount,'24 rolls: the HUD button and the timer never grow')
check(#W.service('SoundService'):GetChildren()==soundCount and soundCount>=4,'24 rolls: the tick sound pool stays at its 4 sounds ('..#W.service('SoundService'):GetChildren()..')')
check(UW.frameListeners()==0 and UW.activeTweens()==0,'24 rolls: nothing running afterwards')
check(#overlay.Fx:GetChildren()==0 and #hud.Fx:GetChildren()==0 and #bar.Fx:GetChildren()==0,'24 rolls: no pieces left in any effect layer')
-- 6. Teardown ---------------------------------------------------------------------------------------------------------------------------
training(true);C.set('DueAt',R.clock+100);C.set('Ready',0);frames(20)
C.set('Ready',1);frames(2) -- billboard pop + button pop in flight
openRoll(cases[5],0);frames(40) -- a roll mid-spin
check(UW.frameListeners()>=1,'before teardown: things are running')
C.Script.Destroying:Fire()
check(hud._destroyed and overlay._destroyed and bar._destroyed,'teardown: the three GUIs are destroyed')
check(UW.frameListeners()==0,'teardown: every listener is disconnected ('..UW.frameListeners()..')')
local ticksLeft=0;for _,s in ipairs(W.service('SoundService'):GetChildren())do if s.Name:find('Interaction_BonusTick')then ticksLeft+=1 end end
check(ticksLeft==0,'teardown: the tick sounds are removed')
secs(2);d0=UW.delays
C.set('Ready',2);training(false);training(true);me:SetAttribute('TreadmillBonusDueAt',R.clock+5);secs(20)
check(UW.delays-d0==0 and UW.frameListeners()==0,'teardown: nothing is scheduled any more and attribute changes do nothing ('..(UW.delays-d0)..')')
-- a second copy of the script (re-run in Studio) replaces the first one's GUIs
local second=R.new('LocalScript');second.Name='TreadmillBonusClient'
W.load('TreadmillBonusClient',second)
local huds=0;for _,g in ipairs(pg:GetChildren())do if g.Name=='TreadmillBonusHud'and not g._destroyed then huds+=1 end end
check(huds==1 and pg:FindFirstChild('TreadmillBonusRoll')~=nil and pg:FindFirstChild('TreadmillBonusProgress')~=nil,'a re-run builds one fresh set of GUIs')
second.Destroying:Fire()
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
