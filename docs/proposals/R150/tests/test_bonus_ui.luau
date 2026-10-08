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
local button,overlay,hud=C.Button,C.Overlay,C.Hud
local face=button.Face
local function frames(n)UW.frames(n,1/60)end
-- R150 review: how often the Denied cue was asked for since C.Played had `from` entries (every flashMessage = one refusal; nothing else plays Denied here)
local function denied(from)local n=0;for i=from+1,#C.Played do if C.Played[i]=='Denied'then n+=1 end end;return n end
local function secs(s)UW.seconds(s,1/60)end
UW.frames(3,1/60)
local baseHud,baseOverlay=UW.count(hud),UW.count(overlay)
local function training(on)me:SetAttribute('TreadmillTraining',on or nil)end
-- 0. Idle: nothing runs ----------------------------------------------------------------------------------------------
local d0=UW.delays
secs(30)
check(button.Visible==false and overlay.Enabled==false and UW.made.BillboardGui==nil,'idle: no button, no roll window, no head billboard')
check(UW.frameListeners()==0,'idle: not a single per-frame listener ('..UW.frameListeners()..')')
check((C.RevealPreloads or 0)>=1,'the reveal / cue voices are preloaded at script start')
check(UW.delays==d0,'idle: no scheduled work at all in 30 s ('..(UW.delays-d0)..')')
-- 1. Button: charging -------------------------------------------------------------------------------------------------
C.set('Interval',360);C.set('Ready',0)
C.set('DueAt',R.clock+222);C.set('Left',222);training(true)
frames(20)
check(button.Visible==true,'charging: the button shows while standing on the treadmill')
check(face.Title.Text=='BONUS ROLL' and face.Sub.Text=='NEXT 3:42','charging: second line counts down: '..face.Sub.Text)
check(face.FillClip.Visible==true and near(face.FillClip.Fill.Size.X.Scale,1-221.67/360,.01),'charging: the face fills with progress ('..face.FillClip.Fill.Size.X.Scale..')')
check(face.Meter.Visible==false and button.CountBadge.Visible==false,'charging: no meter strip, no badge')
local calmLip=button.Lip.BackgroundColor3
check(button:GetAttribute('AccessibleLabel')=='Treadmill bonus roll, charging','charging: accessibility label says so')
check(face.Icon.Visible==true and face.Icon.Picture~=nil and face.Icon:GetChildren()~=nil,'charging: the pack icon shows (R153: the owner\'s pack picture, no gift)')
local f1=face.FillClip.Fill.Size.X.Scale
secs(10)
check(face.Sub.Text=='NEXT 3:32' and face.FillClip.Fill.Size.X.Scale>f1,'charging: ten seconds later the clock and the fill moved ('..face.Sub.Text..')')
C.set('DueAt',R.clock+24);frames(20)
check(face.Title.Text=='ALMOST THERE!' and face.Sub.Text:find('^0:')~=nil,'last 30 s: '..face.Title.Text..' / '..face.Sub.Text)
C.set('DueAt',R.clock+31);frames(20)
check(face.Title.Text=='BONUS ROLL' and face.Sub.Text:find('^NEXT 0:')~=nil,'31 s left is still NEXT')
-- tapping while charging asks nothing of the server
local before=C.Invoked
C.set('DueAt',R.clock+200);frames(20)
local d1=#C.Played
button.Activated:Fire()
check(C.Invoked==before and overlay.Enabled==false,'charging: a tap does not call the server and opens nothing')
check(denied(d1)==1,'R150 review: charging: the tap that says "NEXT IN m:ss" clicks Denied once ('..denied(d1)..')')
check(face.Sub.Text:find('^NEXT IN 3:')~=nil,'charging: a tap says when: '..face.Sub.Text)
check(UW.frameListeners()>=1,'the little "no" nudge runs for a moment')
secs(3);check(face.Sub.Text:find('^NEXT 3:')~=nil and face.Position.X.Offset==0 and face.Position.Y.Offset==0,'the message clears after ~2.5 s and the face is back in place')
-- 2. Button: ready, count, pops ----------------------------------------------------------------------------------------
secs(2)
UW.frames(1,1/60)
local hudFx=hud.Fx
C.set('DueAt',R.clock+250);C.set('Left',250)
C.set('Ready',1);frames(2)
check(button.Visible==true and face.Title.Text=='BONUS READY!' and face.Sub.Text=='OPEN IT!' and face.FillClip.Visible==false,'ready: a roll completing says BONUS READY! / OPEN IT!, no charging fill')
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
check(face.Title.Text=='BONUS ROLL' and face.Sub.Text=='READY!','ready: after BONUS READY! / OPEN IT! it says BONUS ROLL / READY!')
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
check(button.Visible==false,'off the treadmill with nothing ready: no button')
d0=UW.delays;secs(10);check(UW.delays==d0 and UW.frameListeners()==0,'...and nothing scheduled (idle again)')
-- refusal on the button
C.set('Ready',1);frames(2)
C.Reply={Error='SEED BAG FULL! Make room - your roll stays ready.',Ready=1}
local d2=#C.Played
button.Activated:Fire()
check(denied(d2)==1,'R150 review: a server refusal ("SEED BAG FULL!") clicks Denied once ('..denied(d2)..')')
check(face.Sub.Text=='BAG FULL!' and #face.Sub.Text<=15,'refusal: short copy on the button ('..face.Sub.Text..')')
check(button:GetAttribute('AccessibleLabel'):find('SEED BAG FULL')~=nil,'refusal: the full text goes to the accessibility label')
check(overlay.Enabled==false,'refusal: no roll window')
secs(3.6)
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
-- 3. R153: the gift pill over the player's head is gone; the BONUS ROLL button carries its phases ---------------------------------------------------------------------
-- (owner: "remove the NEXT ROLL billboard above the head" and "the almost ready also must be displayed on that bonus roll button")
do
 local function titleSub()return face.Title.Text,face.Sub.Text end
 check(UW.made.BillboardGui==nil and pg:FindFirstChild('TreadmillBonusProgress')==nil,'R153: no BillboardGui is ever made (the head pill is not built at all)')
 for _,d in ipairs(pg:GetDescendants())do check(d._class~='BillboardGui','R153: nothing in PlayerGui is a BillboardGui ('..d.Name..')')end
 for _,d in ipairs(C.Root.Parent:GetDescendants())do check(d._class~='BillboardGui','R153: nothing on the character is a BillboardGui ('..d.Name..')')end
 C.set('Ready',0);C.set('Interval',360);C.set('DueAt',R.clock+341);C.set('Left',341);training(true);frames(20)
 local t,s=titleSub()
 check(button.Visible and t=='BONUS ROLL' and s:find('^NEXT 5:4')~=nil,'R153: charging, 5:41 to go: '..t..' / '..s)
 check(button:GetAttribute('AccessibleLabel')=='Treadmill bonus roll, charging','R153: accessibility label: charging')
 -- the phases, with the gift pill's own threshold: the last 30 s
 for _,case in ipairs({{300,'BONUS ROLL','NEXT'},{60,'BONUS ROLL','NEXT'},{31,'BONUS ROLL','NEXT'},{29,'ALMOST THERE!',''},{12,'ALMOST THERE!',''},{2,'ALMOST THERE!',''}})do
  C.set('DueAt',R.clock+case[1]);frames(20);t,s=titleSub()
  local okClock=(case[3]=='NEXT'and s:find('^NEXT ')~=nil)or(case[3]==''and s:find('^0:')~=nil)
  check(t==case[2]and okClock,'R153: '..case[1]..' s left: '..t..' / '..s)
 end
 check(button:GetAttribute('AccessibleLabel')=='Treadmill bonus roll, almost ready','R153: accessibility label: almost ready')
 C.set('DueAt',R.clock+2);frames(20)
 t,s=titleSub();check(t=='ALMOST THERE!' and s:find('^0:0[12]$')~=nil,'R153: the owner\'s example: ALMOST THERE! / 0:02 ('..t..' / '..s..')')
 -- colours: the fill is yellow while it charges and orange / red in the last 30 s; the text stays white with a dark green stroke
 local fillGradient=face.FillClip.Fill:FindFirstChildOfClass('UIGradient')
 local function near3(c,r,g,b)return math.abs(c.R*255-r)<1.5 and math.abs(c.G*255-g)<1.5 and math.abs(c.B*255-b)<1.5 end
 check(near3(fillGradient.Color.A,255,132,70)and near3(fillGradient.Color.B,222,60,34),'R153: ALMOST THERE!: the fill is orange / red')
 C.set('DueAt',R.clock+200);frames(20)
 check(near3(fillGradient.Color.A,252,220,41)and near3(fillGradient.Color.B,231,152,2),'R153: charging: the fill is the pack\'s yellow')
 check(face.Title.TextColor3.R==1 and face.Title.TextColor3.G==1 and face.Title.TextColor3.B==1 and face.Sub.TextColor3.R==1,'R153: the text is white')
 check(near3(face.Title.TextStrokeColor3,8,58,20)and face.Title.TextStrokeTransparency==0 and near3(face.Sub.TextStrokeColor3,8,58,20),'R153: ... with a dark green stroke')
 -- the emphasis: the gift icon wiggles and the button pulses in short bursts every Style.AlmostPeriod s, nothing runs in between
 C.set('DueAt',R.clock+25);frames(5)
 local maxRot,maxScale=0,1;local bursts,idle,lastWas,total=0,0,0,60*9
 local starts={}
 for i=1,total do
  UW.frames(1,1/60)
  maxRot=math.max(maxRot,math.abs(face.Icon.Rotation));maxScale=math.max(maxScale,button.Pulse.Scale)
  local n=UW.frameListeners();if n>0 and lastWas==0 then bursts+=1;starts[#starts+1]=i/60 end;if n==0 then idle+=1 end;lastWas=n
 end
 check(maxRot>6 and maxRot<=12.5,'R153: almost: the pack wiggles ('..maxRot..' deg)')
 check(maxScale>1.03 and maxScale<=1.07,'R153: almost: the button pulses (max scale '..maxScale..')')
 check(bursts>=3 and bursts<=5,'R153: almost: a pulse about every '..Style.AlmostPeriod..' s ('..bursts..' in 9 s)')
 check(idle>=total*.6,'R153: almost: nothing per frame between the pulses ('..idle..' of '..total..' frames idle)')
 check(near(face.Icon.Rotation,0,12.5),'R153: the wiggle stays in range')
 secs(1);check(near(button.Pulse.Scale,1,.001) or UW.frameListeners()>0,'R153: the pulse settles at 1')
 -- ReducedMotion: the words and the colours are there, nothing moves
 W.Gui.ReducedMotionEnabled=true
 C.set('DueAt',R.clock+10);training(false);training(true);frames(10)
 t,s=titleSub();check(t=='ALMOST THERE!','R153: ReducedMotion: still says ALMOST THERE! ('..t..')')
 local moved=0;for i=1,60*6 do UW.frames(1,1/60);if UW.frameListeners()>0 or face.Icon.Rotation~=0 or button.Pulse.Scale~=1 then moved+=1 end end
 check(moved==0,'R153: ReducedMotion: the almost button never moves or runs a listener in 6 s ('..moved..')')
 W.Gui.ReducedMotionEnabled=false
 -- R153 client bug review, finding 10: a roll completes in the middle of an ALMOST THERE! wiggle. The wiggle stops and puts the rotation and the scale back at once, so the ready
 -- pop (the button grows from .72 to 1) is what the player sees; before, the wiggle kept writing the icon's rotation and the button's scale for the rest of its 0.75 s over the pop.
 do
  C.set('Ready',0);C.set('Interval',360);C.set('DueAt',R.clock+25);C.set('Left',25);training(true);frames(5)
  local inBurst=false
  for _=1,60*6 do UW.frames(1,1/60);if math.abs(face.Icon.Rotation)>3 and UW.frameListeners()>0 then inBurst=true;break end end
  check(inBurst,'R153 review (10): the ALMOST THERE! wiggle is running ('..face.Icon.Rotation..' deg)')
  C.set('Ready',1);UW.frames(1,1/60)
  check(face.Icon.Rotation==0,'R153 review (10): the roll completing stops the wiggle at once: the icon is back at 0 deg ('..face.Icon.Rotation..')')
  local worstRot,topScale,lowScale=0,0,math.huge
  for _=1,12 do
   UW.frames(1,1/60)
   worstRot=math.max(worstRot,math.abs(face.Icon.Rotation));topScale=math.max(topScale,button.Pulse.Scale);lowScale=math.min(lowScale,button.Pulse.Scale)
  end
  check(worstRot==0,'R153 review (10): the icon does not wiggle again over the ready pop ('..worstRot..' deg in the next 12 frames)')
  check(topScale<=1.0001 and lowScale<.95,'R153 review (10): the ready pop is what the button shows: it grows up from .72, never pulsed above 1 by the wiggle (low '..string.format('%.3f',lowScale)..', high '..string.format('%.3f',topScale)..')')
  secs(1);check(button.Pulse.Scale>.98 and button.Pulse.Scale<1.05 and face.Icon.Rotation==0 and UW.frameListeners()<=1,'R153 review (10): the pop settles at 1, nothing left running ('..button.Pulse.Scale..')')
  C.set('Ready',0);training(false);frames(5);secs(4);C.set('DueAt',R.clock+360);C.set('Left',360);training(true);frames(5)
 end
 -- the ready state: a roll completing says BONUS READY! / OPEN IT! for Style.ReadyHold seconds, then READY!; the pop, the sparkles and the cue are the button's
 C.set('DueAt',R.clock+360);C.set('Left',360);frames(5)
 local fxBefore=#hud.Fx:GetChildren()
 C.set('Ready',1);frames(1)
 t,s=titleSub();check(t=='BONUS READY!' and s=='OPEN IT!','R153: a roll completing: BONUS READY! / OPEN IT! ('..t..' / '..s..')')
 check(face.FillClip.Visible==false,'R153: ready: no charging fill (the thin meter shows the next roll)')
 check(#hud.Fx:GetChildren()==fxBefore+8,'R153: the sparkles pop on the button (8) ('..(#hud.Fx:GetChildren()-fxBefore)..')')
 secs(Style.ReadyHold-.5);t,s=titleSub();check(t=='BONUS READY!','R153: still BONUS READY! just before '..Style.ReadyHold..' s')
 secs(1);t,s=titleSub();check(t=='BONUS ROLL' and s=='READY!','R153: then BONUS ROLL / READY! ('..t..' / '..s..')')
 -- at the cap
 C.set('DueAt',nil);C.set('Ready',2);frames(1);secs(Style.ReadyHold+.5)
 t,s=titleSub();check(t=='BONUS ROLL' and s=='2 ROLLS READY!' and button.CountBadge.Visible,'R153: at the cap: 2 ROLLS READY! and the count badge ('..t..' / '..s..')')
 -- the ticker still ticks only while on the treadmill
 d0=UW.delays;secs(5);check(UW.delays-d0>=15 and UW.delays-d0<=25,'R153: the button\'s clock ticks about 4 times a second while on the treadmill, nothing per frame ('..(UW.delays-d0)..' in 5 s)')
 check(UW.frameListeners()==0,'R153: no per-frame listener while it just counts')
 training(false);C.set('Ready',0);frames(5);secs(4)
 check(button.Visible==false and UW.made.BillboardGui==nil,'R153: off the treadmill with nothing ready: no button, still no billboard')
end
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
 local dRoll=#C.Played
 openRoll(case,0)
 local tag=case.Rarity
 check(overlay.Enabled==true and C.Invoked>0,tag..': the roll window opens')
 check(panel.Status.Visible==true and panel.Word.Visible==false and panel.Status.Text==Style.SpinLines[1],tag..': spinning: playful status line '..panel.Status.Text)
 check(panel.Result.Visible==false and panel.Result.Text=='',tag..': R153: spinning: nothing under the status line (no "already in ur bag" line)')
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
 local fxCount=#panel.Fx:GetChildren()
 check(fxCount==style.Sparkles+style.Confetti,tag..': sparkles '..style.Sparkles..' + confetti '..style.Confetti..' = '..fxCount)
 check(winner:FindFirstChild('ShinePane')~=nil,tag..': a soft shine sweeps the winner')
 if special then check(winner:FindFirstChild('BorderGlow')~=nil,tag..': special: border light-up still there')else check(winner:FindFirstChild('BorderGlow')==nil,tag..': no border light-up for '..tag)end
 -- rays turn
 local r1=rays and rays.Rotation or 0;secs(.5);local r2=rays and rays.Rotation or 0
 check(r2~=r1,tag..': the rays turn slowly ('..r1..' -> '..r2..')')
 secs(2)
 check(#panel.Fx:GetChildren()==0,tag..': confetti and sparkles are gone after ~2 s')
 check(winner:FindFirstChild('ShinePane')==nil,tag..': the shine pane is removed after its sweep')
 check(UW.frameListeners()==1,tag..': after the reveal only the ambient animator runs ('..UW.frameListeners()..')')
 check(denied(dRoll)==0,tag..': R150 review: a roll that starts, spins and reveals never clicks Denied ('..denied(dRoll)..')')
 panel.Actions.Close.Activated:Fire()
 check(overlay.Enabled==false and UW.frameListeners()==0,tag..': closed: no listener left')
 check(UW.count(overlay)==ovBase,tag..': closed: the overlay is back to its bare size ('..UW.count(overlay)..' vs '..ovBase..')')
 secs(2);check(UW.activeTweens()<=1,tag..': no tween left running ('..UW.activeTweens()..')')
end
-- Skip, roll again, close mid-way ----------------------------------------------------------------------------------------
local dAgain=#C.Played
openRoll(cases[5],1)
frames(30);panel.Actions.Skip.Activated:Fire()
check(panel.Actions.Close.Visible and panel.Word.Text=='LEGENDARY!' and panel.Actions.Again.Visible,'Skip jumps to the reveal; ROLL AGAIN shows with one ready')
check(panel.Actions.Again.Face.Label.Text=='ROLL AGAIN (1)','roll again caption carries the count: '..panel.Actions.Again.Face.Label.Text)
C.Reply={Ok=true,Stage=1,Variant='Pack01',Rarity='Common',Label='Forest Seed Pack',Pool='1',Ready=0}
local invokedBefore=C.Invoked
panel.Actions.Again.Activated:Fire()
check(C.Invoked==invokedBefore+1 and overlay.Enabled==true and panel.Word.Visible==false and panel.Status.Visible==true and #panel.Fx:GetChildren()==0,'ROLL AGAIN: closes, asks once, a fresh spin with a clean screen')
check(panel.Result.Visible==false and panel.Result.Text==''and panel:FindFirstChild('Pop')~=nil and panel.StripWindow.Strip:FindFirstChild('Rays')==nil,'ROLL AGAIN: no leftovers from the last reveal (the result line is hidden again)')
spinOut();panel.Actions.Close.Activated:Fire()
check(denied(dAgain)==0,'R150 review: Skip, a second roll and ROLL AGAIN never click Denied ('..denied(dAgain)..')')
-- ReducedMotion roll ---------------------------------------------------------------------------------------------------------
W.Gui.ReducedMotionEnabled=true
openRoll(cases[5],0)
check(panel.Pop.Scale==1,'ReducedMotion: the panel does not pop in')
local movedPointer=false;local y0=panel.PointerTop.Position.Y.Offset
local took2=0;while panel.Actions.Skip.Visible and took2<600 do UW.frames(1,1/60);took2+=1;if panel.PointerTop.Position.Y.Offset~=y0 then movedPointer=true end end
check(took2/60<=Rules.Strip.ReducedDuration+.1,'ReducedMotion: short spin ('..took2/60 ..' s)')
check(not movedPointer and UW.frameListeners()==0,'ReducedMotion: no ambient motion and no listener after the stop ('..UW.frameListeners()..')')
check(panel.Word.Visible and panel.Word.Pop.Scale==1 and #panel.Fx:GetChildren()==0,'ReducedMotion: the word shows without a pop, no confetti, no sparkles')
local rays2=panel.StripWindow.Strip:FindFirstChild('Rays')
check(rays2~=nil,'ReducedMotion: the rays still show (still)')
secs(2);check(rays2.Rotation==0 and panel.StripWindow.Strip['Card'..Rules.Strip.Win]:FindFirstChild('ShinePane')==nil,'ReducedMotion: rays do not turn, no shine sweep')
check(panel.StripWindow.Strip['Card'..Rules.Strip.Win]:FindFirstChild('BorderGlow')~=nil,'ReducedMotion: the border light-up stays')
panel.Actions.Close.Activated:Fire();W.Gui.ReducedMotionEnabled=false
-- low quality roll -------------------------------------------------------------------------------------------------------------
me:SetAttribute('FastMode',true)
openRoll(cases[5],0);spinOut()
local lstrip=panel.StripWindow.Strip
check(#panel.Fx:GetChildren()==3+math.floor(Style.Reveal('Legendary').Confetti*.3),'FastMode: fewer pieces ('..#panel.Fx:GetChildren()..')')
check(lstrip['Card'..Rules.Strip.Win]:FindFirstChild('ShinePane')==nil,'FastMode: no shine sweep')
local lr=lstrip:FindFirstChild('Rays');secs(1);check(lr~=nil and lr.Rotation==0,'FastMode: rays stay still')
local tw1=panel.Twinkle1.BackgroundTransparency;secs(.5);check(panel.Twinkle1.BackgroundTransparency==tw1,'FastMode: no twinkle updates')
panel.Actions.Close.Activated:Fire();me:SetAttribute('FastMode',nil)
-- ClientFxBudget tier 1 counts as low as well
C.Tier=1;openRoll(cases[6],0);spinOut()
check(#panel.Fx:GetChildren()==3+math.floor(Style.Reveal('Mythic').Confetti*.3),'low tier 1: fewer pieces ('..#panel.Fx:GetChildren()..')')
panel.Actions.Close.Activated:Fire();C.Tier=3
-- unchanged result handling: malformed replies do nothing
C.set('Ready',1);C.Reply={Ok=true,Stage=99,Variant=nil};secs(2)
local d3=#C.Played;button.Activated:Fire()
check(overlay.Enabled==false,'a malformed reply opens nothing')
check(denied(d3)==1,'R150 review: a malformed reply clicks Denied once ('..denied(d3)..')')
C.Reply=nil;secs(3);d3=#C.Played;button.Activated:Fire();check(overlay.Enabled==false,'no reply opens nothing')
check(denied(d3)==1,'R150 review: no reply at all clicks Denied once ('..denied(d3)..')')
do -- the server call itself fails (a network error): the same refusal
 secs(3);local realInvoke=C.Remote.InvokeServer;C.Remote.InvokeServer=function()error('network down')end
 d3=#C.Played;button.Activated:Fire();check(overlay.Enabled==false,'a failed call opens nothing')
 check(denied(d3)==1,'R150 review: a failed call clicks Denied once ('..denied(d3)..')');C.Remote.InvokeServer=realInvoke
end
secs(3);C.set('Ready',0);frames(2)
-- 5. No leaks over repeated rolls -------------------------------------------------------------------------------------------------
local soundCount=#W.service('SoundService'):GetChildren()
local hudCount=UW.count(hud)
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
check(UW.count(hud)==hudCount,'24 rolls: the HUD button never grows')
check(#W.service('SoundService'):GetChildren()==soundCount and soundCount>=4,'24 rolls: the tick sound pool stays at its 4 sounds ('..#W.service('SoundService'):GetChildren()..')')
check(UW.frameListeners()==0 and UW.activeTweens()==0,'24 rolls: nothing running afterwards')
check(#panel.Fx:GetChildren()==0 and #hud.Fx:GetChildren()==0,'24 rolls: no pieces left in any effect layer')
-- 5b. R150 review fixes ---------------------------------------------------------------------------------------------------------------------------
-- The reveal confetti never crosses the ribbon header, the reveal word and the HUD button pop about their centres, the roll screen builds fewer instances,
-- the gloss is for the special cards only, no twinkle sits on the fine print, the gift timer's shadow follows its pop and shake.
C.set('Ready',0);training(false);frames(3);secs(1)
local VIEWS={{1280,720,false,'desktop'},{844,390,true,'phone'}}
local function setView(v)W.UIS.TouchEnabled=v[3];C.size(v[1],v[2]);frames(2)end
local PANEL='TreadmillBonusRoll.Panel.'
local function stripTags(text)return(text:gsub('<[^>]+>',''))end
-- Where the text of a label really is (centred, scaled to the box like TextScaled): not the whole label box.
local function textRect(e)
 local label=e.Obj;local text=label.RichText and stripTags(label.Text)or label.Text
 local _,size,lines=UW.fit(label,{W=e.RW,H=e.RH})
 local tw=lines>1 and e.RW or math.min(e.RW,UW.width(text,size));local th=math.min(e.RH,lines*size*1.12)
 return {X=e.RX+(e.RW-tw)/2,Y=e.RY+(e.RH-th)/2,W=tw,H=th}
end
-- (a) the confetti and the sparkles are drawn under the ribbon header ----------------------------------------------------------------------------------
do
 local overlapFrames,pieceFrames,underHeader,aboveStrip,aboveWord,bad,badStrip=0,0,0,0,0,0,0
 for _,v in ipairs(VIEWS)do
  setView(v);local w,h=v[1],v[2]
  for _,case in ipairs({cases[5],cases[6],cases[7],cases[1]})do
   openRoll(case,0);frames(25);panel.Actions.Skip.Activated:Fire()
   for _=1,100 do
    frames(1)
    local list,by=UW.rects(overlay,w,h)
    local ribbon,title,window,word=by[PANEL..'Ribbon'],by[PANEL..'Ribbon.Title'],by[PANEL..'StripWindow'],by[PANEL..'Word']
    local words=textRect(title)
    for _,e in ipairs(list)do
     if e.Visible and e.Path:sub(1,#PANEL+3)==PANEL..'Fx.'then
      pieceFrames+=1
      if UW.overlap(e,ribbon)then overlapFrames+=1 end
      if UW.overlap(e,words)or UW.overlap(e,ribbon)then
       underHeader+=1
       if not(UW.drawsAbove(ribbon.Obj,e.Obj)and UW.drawsAbove(title.Obj,e.Obj))then bad+=1 end
      end
      if UW.overlap(e,window)then aboveStrip+=1;if not UW.drawsAbove(e.Obj,window.Obj)then badStrip+=1 end end
      if word.Visible and UW.overlap(e,word)then aboveWord+=1;if not UW.drawsAbove(e.Obj,word.Obj)then badStrip+=1 end end
     end
    end
   end
   panel.Actions.Close.Activated:Fire();secs(2)
  end
 end
 check(pieceFrames>=1000,'R150 review: the confetti test saw plenty of pieces ('..pieceFrames..' piece-frames, desktop and phone)')
 check(overlapFrames>=60 and underHeader>=60,'R150 review: ... and many of them fly right across the header ('..overlapFrames..' piece-frames on the ribbon)')
 check(bad==0,'R150 review: no confetti or sparkle piece is ever drawn over the ribbon header or its text, desktop and phone, Common / Legendary / Mythic / Secret ('..bad..' of '..underHeader..' piece-frames over it)')
 check(aboveStrip>=60 and aboveWord>=1 and badStrip==0,'R150 review: ... while they still fly over the strip window and the reveal word ('..aboveStrip..' / '..aboveWord..' piece-frames, '..badStrip..' hidden behind them)')
 -- the layer: inside the panel, over the strip window (3), under the ribbon (5), the pointers (9) and the bow (10); it never takes a click
 openRoll(cases[5],0)
 local fxLayer=panel:FindFirstChild('Fx')
 check(fxLayer~=nil and fxLayer.Parent==panel and overlay:FindFirstChild('Fx')==nil,'R150 review: the reveal layer lives in the panel, not on the screen')
 check(fxLayer.ZIndex>panel.StripWindow.ZIndex and fxLayer.ZIndex<panel.Ribbon.ZIndex and fxLayer.ZIndex<panel.PointerTop.ZIndex and fxLayer.ZIndex<panel.Bow.ZIndex,'R150 review: ... over the strip window ('..panel.StripWindow.ZIndex..'), under the ribbon ('..panel.Ribbon.ZIndex..'), the pointers and the bow')
 check(fxLayer.Active==false and fxLayer.BackgroundTransparency==1,'R150 review: ... and it is invisible and takes no clicks')
 panel.Actions.Close.Activated:Fire();secs(2)
end
-- (b) the reveal word pops about its centre ------------------------------------------------------------------------------------------------------------
do
 local worst,shrunk,count=0,0,0
 for _,v in ipairs(VIEWS)do
  setView(v);local w,h=v[1],v[2]
  for _,case in ipairs(cases)do
   openRoll(case,0);frames(25);panel.Actions.Skip.Activated:Fire()
   local xs,ys,ws={},{},{}
   for i=1,70 do
    local _,by=UW.rects(overlay,w,h);local e=by[PANEL..'Word'];local pe=by['TreadmillBonusRoll.Panel']
    xs[i]=e.X+e.W/2;ys[i]=e.Y+e.H/2;ws[i]=e.W
    if i==1 then
     check(math.abs(xs[1]-(pe.X+pe.W/2))<=.01,v[4]..' '..case.Rarity..': the word starts at the middle of the panel ('..xs[1]..' vs '..pe.X+pe.W/2 ..')')
    end
    frames(1)
   end
   local restX,restY,restW=xs[70],ys[70],ws[70]
   local lo=math.huge
   for i=1,70 do worst=math.max(worst,math.abs(xs[i]-restX),math.abs(ys[i]-restY));lo=math.min(lo,ws[i])end
   count+=1;if lo<restW*.95 then shrunk+=1 end
   panel.Actions.Close.Activated:Fire();secs(2)
  end
 end
 check(worst<=.01,'R150 review: the word\'s centre does not move during the pop, on any rarity, desktop and phone (worst drift '..worst..' px; a top-left pivot slid it ~250 px)')
 check(shrunk==count,'R150 review: ... and the pop really scales it ('..shrunk..' of '..count..' reveals start smaller)')
end
-- (c) no twinkle sits on the fine print or the status / result lines -----------------------------------------------------------------------------------
do
 for _,v in ipairs(VIEWS)do
  setView(v);local w,h=v[1],v[2]
  openRoll(cases[1],0);frames(25)
  local _,by=UW.rects(overlay,w,h);local hits,n={},0
  for i=1,12 do
   local t=by[PANEL..'Twinkle'..i]
   if t then
    n+=1
    for _,name in ipairs({'Odds','Result','Status'})do
     local row=by[PANEL..name];local r=textRect(row)
     if UW.overlap(t,r,1)then hits[#hits+1]='Twinkle'..i..' on '..name end -- (1 px of slack: a line box has air above its glyphs)
    end
    if UW.overlap(t,by[PANEL..'Actions.Skip'])then hits[#hits+1]='Twinkle'..i..' on SKIP' end
   end
  end
  check(n==8,v[4]..': eight twinkles are left (the four along the bottom edge are gone) ('..n..')')
  check(#hits==0,'R150 review: '..v[4]..': no twinkle sits on the odds line, the status / result text or the buttons ('..table.concat(hits,', ')..')')
  local odds=by[PANEL..'Odds'];local lowest=0
  for i=1,12 do local t=by[PANEL..'Twinkle'..i];if t and t.Y+t.H>lowest and t.Y<odds.Y+odds.H then lowest=math.max(lowest,t.Y+t.H)end end
  check(lowest<=odds.Y+1,'R150 review: '..v[4]..': no twinkle reaches into the odds row\'s height ('..lowest..' vs row top '..odds.Y..')')
  panel.Actions.Skip.Activated:Fire();panel.Actions.Close.Activated:Fire();secs(2)
 end
end
-- (d) the HUD button pops and pulses about its centre ---------------------------------------------------------------------------------------------------
do
 setView(VIEWS[1]);local w,h=1280,720
 local function rectOf(path)local _,by=UW.rects(hud,w,h);return by['TreadmillBonusHud.BonusRollButton'..path]end
 check(button.AnchorPoint.X==.5 and button.AnchorPoint.Y==.5,'R150 review: the HUD button is anchored at its centre (the pop and the pulse scale about the AnchorPoint)')
 C.set('Ready',1);secs(3)
 local rest=rectOf('');local gift=rectOf('.Face.Icon')
 local cx0,cy0=rest.RX+rest.RW/2,rest.RY+rest.RH/2
 -- the pulse: ~14 s of the attention loop (a wiggle and a pulse every 4.2 s)
 local drift,widest=0,rest.W
 for _=1,60*14 do
  frames(1);local b=rectOf('');drift=math.max(drift,math.abs(b.X+b.W/2-cx0),math.abs(b.Y+b.H/2-cy0));widest=math.max(widest,b.W)
 end
 check(widest>rest.W*1.02,'R150 review: the attention pulse was measured (the button grows to '..string.format('%.3f',widest/rest.W)..' x)')
 check(drift<=.01,'R150 review: the attention pulse keeps the button\'s centre in place ('..drift..' px drift)')
 -- the ready pop: gone, then back
 C.set('Ready',0);frames(3);secs(1)
 C.set('Ready',1)
 local sparks=hud.Fx:GetChildren()
 check(#sparks==8,'R150 review: the sparkle burst is there at once ('..#sparks..')')
 local near2=true
 for _,sp in ipairs(sparks)do
  if math.abs(sp.Position.X.Offset-(gift.X+gift.W/2))>1.5 or math.abs(sp.Position.Y.Offset-(gift.Y+gift.H/2))>1.5 then near2=false end
 end
 check(near2 and #sparks>0,'R150 review: ... starting on the gift icon (buttonCenter follows the new anchor): icon centre '..string.format('%.1f,%.1f',gift.X+gift.W/2,gift.Y+gift.H/2)..' vs '..string.format('%.1f,%.1f',sparks[1].Position.X.Offset,sparks[1].Position.Y.Offset))
 local pdrift,smallest=0,rest.W
 for _=1,40 do
  local b=rectOf('');pdrift=math.max(pdrift,math.abs(b.X+b.W/2-cx0),math.abs(b.Y+b.H/2-cy0));smallest=math.min(smallest,b.W);frames(1)
 end
 check(smallest<rest.W*.8,'R150 review: the ready pop was measured (it starts at '..string.format('%.2f',smallest/rest.W)..' x)')
 check(pdrift<=.01,'R150 review: the ready pop keeps the button\'s centre in place ('..pdrift..' px drift; a top-left pivot moved it ~30 px)')
 local after=rectOf('')
 check(math.abs(after.RX-rest.RX)<.01 and math.abs(after.RY-rest.RY)<.01 and after.RW==rest.RW,'R150 review: the button comes back to the same place')
 C.set('Ready',0);secs(1)
end
-- (e) instance counts: the roll opens with fewer, the gloss is for the special cards only ------------------------------------------------------------------
do
 setView(VIEWS[1])
 local made=0
 do local inew=R.Instance.new;R.Instance.new=function(...)made+=1;return inew(...)end end
 local worstOpen,worstReveal=0,0;local glossOk,glossCount,specialCount=true,0,0
 for _,case in ipairs(cases)do
  C.Reply={Ok=true,Stage=case.Stage,Variant=case.Variant,Rarity=case.Rarity,Label=case.Label,Pool='1,6,2,3,4,5,7',Ready=0}
  C.set('Ready',1);frames(1)
  made=0;button.Activated:Fire();worstOpen=math.max(worstOpen,made)
  panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset)
  if case.Rarity=='Common'or case.Rarity=='Secret'then
   for _,card in ipairs(panel.StripWindow.Strip:GetChildren())do
    local isSpecial=card:FindFirstChild('Design')~=nil;if isSpecial then specialCount+=1 end
    local hasGloss=card:FindFirstChild('Gloss')~=nil;if hasGloss then glossCount+=1 end
    if hasGloss~=isSpecial then glossOk=false end
   end
  end
  frames(10);made=0;panel.Actions.Skip.Activated:Fire();worstReveal=math.max(worstReveal,made)
  panel.Actions.Close.Activated:Fire();secs(2)
 end
 check(glossOk and glossCount==specialCount and glossCount>=1,'R150 review: only the special cards (Legendary / Mythic / Secret) carry the gloss ('..glossCount..' gloss frames on '..specialCount..' special cards)')
 check(worstOpen<=530,'R150 review: opening a roll builds at most 530 instances in the one frame (first cut 598-625, R149 368-395; R150 490 at most; R153: the Secret tease card is ~29 more, 519 at most): '..worstOpen)
 check(worstReveal<=100,'R150 review: the reveal frame builds at most 100 (first cut 41 / 120 / 142 / 160; R149 4-5): '..worstReveal)
 -- a sparkle is one instance: a Secret reveal's pieces are exactly its count
 openRoll(cases[7],0);frames(10);panel.Actions.Skip.Activated:Fire()
 local st=Style.Reveal('Secret');local bare=0
 for _,pc in ipairs(panel.Fx:GetChildren())do if #pc:GetChildren()==0 then bare+=1 end end
 check(bare==#panel.Fx:GetChildren() and #panel.Fx:GetChildren()==st.Sparkles+st.Confetti,'R150 review: every sparkle and confetti piece is one bare Frame ('..bare..' of '..#panel.Fx:GetChildren()..')')
 panel.Actions.Close.Activated:Fire();secs(2)
end
-- (g) R153: no "already in ur bag" line; the spin text is centred; a Secret card flies by on every reel; the reel always stops on the server's result ------------
do
 local SECRET=string.upper(Rules.Tier(Rules.Void.Variant));local WIN,CW=Rules.Strip.Win,Rules.Strip.CardWidth
 local function cardsOf()local out={};for _,c in ipairs(panel.StripWindow.Strip:GetChildren())do local n=tonumber(c.Name:match('^Card(%d+)$'));if n then out[n]=c end end;return out end
 local function isSecret(c)return c.Rarity.Text==SECRET and c.Biome.Text==Rules.Void.Label end
 local function secretSlots()local out={};for i,c in pairs(cardsOf())do if isSecret(c)then out[#out+1]=i end end;table.sort(out);return out end
 local function mid()return panel.StripWindow.AbsoluteSize.X/2 end
 local function centreOf(c)return panel.StripWindow.Strip.Position.X.Offset+c.Position.X.Offset+CW/2 end
 local function biomeLabel(case)return case.Variant==Rules.Void.Variant and Rules.Void.Label or W.module('SeedPackRules').DesignBiomes[case.Stage]end
 local pools={'1,6,2,3,4,5,7','7','1','3,4',''}
 local function openPool(case,pool)
  C.Reply={Ok=true,Stage=case.Stage,Variant=case.Variant,Rarity=case.Rarity,Label=case.Label,Pool=pool,Ready=0}
  C.set('Ready',1);frames(1);button.Activated:Fire()
  panel.StripWindow.AbsoluteSize=R.Vector2.new(panel.Size.X.Offset-28,panel.StripWindow.Size.Y.Offset)
 end
 -- (1) no line about the bag anywhere on the roll screen, spinning or revealed, every rarity, desktop / phone / ReducedMotion
 local function bagLines(w,h)
  local list=UW.rects(overlay,w,h);local hits={}
  for _,e in ipairs(list)do
   local o=e.Obj
   if e.Visible and(o:IsA('TextLabel')or o:IsA('TextButton'))and type(o.Text)=='string'and o.Text~=''then
    local low=string.lower(o.Text);if low:find('bag',1,true)or low:find('already',1,true)then hits[#hits+1]=e.Path..': '..o.Text end
   end
  end
  return hits
 end
 local scans,hits=0,{}
 for _,mode in ipairs({{VIEWS[1],false},{VIEWS[2],false},{VIEWS[1],true}})do
  W.Gui.ReducedMotionEnabled=mode[2];setView(mode[1]);local w,h=mode[1][1],mode[1][2]
  for _,case in ipairs(cases)do
   openPool(case,pools[1]);frames(30)
   for _,t in ipairs(bagLines(w,h))do hits[#hits+1]=case.Rarity..' spinning: '..t end;scans+=1
   check(panel.Result.Visible==false and panel.Result.Text=='','R153: '..case.Rarity..' spinning: the result row is empty and hidden')
   spinOut();frames(2)
   for _,t in ipairs(bagLines(w,h))do hits[#hits+1]=case.Rarity..' revealed: '..t end;scans+=1
   check(panel.Result.Visible==true and panel.Result.Text:find(case.Label,1,true)~=nil,'R153: '..case.Rarity..' revealed: the result line shows (and names the pack)')
   panel.Actions.Close.Activated:Fire();secs(1)
  end
 end
 W.Gui.ReducedMotionEnabled=false
 check(scans==42 and #hits==0,'R153: no text on the roll screen mentions the bag ("Ur pack is already in ur bag!" is gone), '..scans..' screens scanned'..(hits[1]and(' - '..hits[1])or''))
 -- (2) the spin text is centred between the strip and the buttons, and the rows around it did not move
 for _,v in ipairs(VIEWS)do
  setView(v);local w,h=v[1],v[2]
  openPool(cases[1],pools[1]);frames(40)
  local _,by=UW.rects(overlay,w,h)
  local st,win,act,res=by[PANEL..'Status'],by[PANEL..'StripWindow'],by[PANEL..'Actions'],by[PANEL..'Result']
  local gapMid=(win.RY+win.RH+act.RY)/2
  check(st.Visible and math.abs(st.RY+st.RH/2-gapMid)<=1,v[4]..': R153: the spin text sits in the middle of the gap between the strip and the buttons ('..string.format('%.1f vs %.1f',st.RY+st.RH/2,gapMid)..')')
  check(not res.Visible and st.RY+st.RH<=act.RY and st.RY>=win.RY+win.RH,v[4]..': R153: its box stays between the strip and the buttons')
  panel.Actions.Skip.Activated:Fire();frames(2)
  local _,by2=UW.rects(overlay,w,h);local word,res2,act2=by2[PANEL..'Word'],by2[PANEL..'Result'],by2[PANEL..'Actions']
  check(word.Visible and res2.Visible and word.RY+word.RH<=res2.RY+.01 and res2.RY+res2.RH<=act2.RY,v[4]..': R153: the reveal still has its word above the result line above the buttons')
  check(math.abs(act2.RY-act.RY)<.01,v[4]..': R153: the buttons are where they were (the panel does not jump at the reveal)')
  panel.Actions.Close.Activated:Fire();secs(1)
 end
 -- (3) the Secret pack flies by on every roll; (4) the reel always stops on the server's result
 local rolls,teased,anySecret,landed,wrongLanding,starSeen,underMarker,inViewOk,restFar,secretWins,watched=0,0,0,0,0,0,0,0,0,0,0
 local noTease={}
 for mi,mode in ipairs({{VIEWS[1],false,'desktop'},{VIEWS[2],false,'phone'},{VIEWS[1],true,'reduced'}})do
  W.Gui.ReducedMotionEnabled=mode[2];setView(mode[1])
  for rep=1,3 do
   for ci,case in ipairs(cases)do
    local pool=pools[(rep+ci+mi)%#pools+1]
    openPool(case,pool);rolls+=1
    local all=cardsOf();local slots=secretSlots()
    local n=0;for _ in pairs(all)do n+=1 end
    check(n==Rules.Strip.Count,mode[3]..' '..case.Rarity..': the reel keeps its '..Rules.Strip.Count..' cards ('..n..')')
    local back1,back2=WIN-Style.TeaseBack[1],WIN-Style.TeaseBack[2]
    local tease=(table.find(slots,back1)and back1)or(table.find(slots,back2)and back2)
    if tease then teased+=1 else noTease[#noTease+1]=mode[3]..' '..case.Rarity end
    if #slots>=1 then anySecret+=1 end
    local winCard=all[WIN]
    check(winCard.Rarity.Text==string.upper(case.Rarity)and winCard.Biome.Text==biomeLabel(case),mode[3]..' '..case.Rarity..': the card in the winning slot is the server\'s pack ('..winCard.Rarity.Text..' / '..winCard.Biome.Text..')')
    if case.Rarity=='Secret'then
     secretWins+=1;check(table.find(slots,WIN)~=nil and #slots>=2,mode[3]..': a Secret result keeps its card and the tease flies by too ('..#slots..' Secret cards)')
    else check(table.find(slots,WIN)==nil,mode[3]..' '..case.Rarity..': the winning slot is never a Secret card unless the server rolled it')end
    -- watch the tease card fly by (every frame); on the second pass of each mode the roll is skipped part-way
    local skipAt=(rep==2)and(15+37*ci)or nil
    local tc=tease and all[tease];local minDist,inView=math.huge,0
    local star0=tc and tc.Design.Star1.BackgroundTransparency;local starMoved,starMovedOffscreen=false,false
    local f=0
    while panel.Actions.Skip.Visible and f<2000 do
     UW.frames(1,1/60);f+=1
     if tc and panel.Actions.Skip.Visible then
      local c=centreOf(tc);local W_=panel.StripWindow.AbsoluteSize.X
      minDist=math.min(minDist,math.abs(c-mid()))
      if c-CW/2>=0 and c+CW/2<=W_ then inView+=1 end
      local star=tc.Design.Star1.BackgroundTransparency
      if star~=star0 then if c+CW/2>0 and c-CW/2<W_ then starMoved=true else starMovedOffscreen=true end;star0=star end
     end
     if skipAt and f==skipAt then panel.Actions.Skip.Activated:Fire()end
    end
    if tc and not skipAt then
     watched+=1
     if minDist<=CW/2 then underMarker+=1 end
     if inView>=(mode[2]and 10 or 15)then inViewOk+=1 end
     if mode[2]or(starMoved and not starMovedOffscreen)then starSeen+=1 end -- (ReducedMotion has no ambient animation at all)
    end
    -- the stop: the server's card is the one under the marker
    local cards2=cardsOf();local best,bestD=nil,math.huge
    for i,c in pairs(cards2)do local d=math.abs(centreOf(c)-mid());if d<bestD then best,bestD=i,d end end
    local landedCard=cards2[best]
    if best==WIN and bestD<=CW/2 and landedCard.Rarity.Text==string.upper(case.Rarity)and landedCard.Biome.Text==biomeLabel(case)and isSecret(landedCard)==(case.Rarity=='Secret')then landed+=1 else wrongLanding+=1 end
    if tease and math.abs(centreOf(cards2[tease])-mid())>CW then restFar+=1 end
    check(panel.Word.Text==Style.Reveal(case.Rarity).Word,mode[3]..' '..case.Rarity..': the reveal names the server\'s rarity')
    panel.Actions.Close.Activated:Fire();secs(1)
   end
  end
 end
 W.Gui.ReducedMotionEnabled=false
 check(rolls==63 and teased==rolls and anySecret==rolls,'R153: the Secret pack is on the reel of every roll, '..Style.TeaseBack[1]..' or '..Style.TeaseBack[2]..' cards before the winner ('..teased..' of '..rolls..' rolls; none: '..table.concat(noTease,', ')..')')
 check(watched>=40 and underMarker==watched,'R153: the Secret card passes under the pointer on every watched roll, desktop / phone / ReducedMotion ('..underMarker..' of '..watched..')')
 check(inViewOk==watched,'R153: ... and is fully inside the window for a good stretch of the spin ('..inViewOk..' of '..watched..')')
 check(landed==rolls and wrongLanding==0,'R153: every reel stops on the server\'s result, Skip included, desktop / phone / ReducedMotion, any pool ('..landed..' of '..rolls..' rolls, '..wrongLanding..' wrong)')
 check(restFar==rolls,'R153: ... and the Secret tease is not near the pointer at the stop ('..restFar..' of '..rolls..')')
 check(secretWins==9,'R153: the Secret result itself was tested ('..secretWins..' rolls)')
 check(starSeen==watched,'R153: a special card is only animated while it is inside the window: the off-screen tease holds still, then moves once in view ('..starSeen..' of '..watched..')')
 -- a roll the server answered with Common .. Mythic never has a Secret card in the winning slot
 local landSecret=0
 for i=1,60 do
  local case=cases[(i-1)%6+1]
  openPool(case,pools[i%#pools+1]);if isSecret(cardsOf()[WIN])then landSecret+=1 end
  panel.Actions.Skip.Activated:Fire();panel.Actions.Close.Activated:Fire()
 end
 check(landSecret==0,'R153: a roll the server answered with Common .. Mythic never has a Secret card in the winning slot (60 rolls)')
 secs(2)
end
setView(VIEWS[1])
-- 6. Teardown ---------------------------------------------------------------------------------------------------------------------------
training(true);C.set('DueAt',R.clock+100);C.set('Ready',0);frames(20)
C.set('Ready',1);frames(2) -- billboard pop + button pop in flight
openRoll(cases[5],0);frames(40) -- a roll mid-spin
check(UW.frameListeners()>=1,'before teardown: things are running')
C.Script.Destroying:Fire()
check(hud._destroyed and overlay._destroyed,'teardown: the two GUIs are destroyed')
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
check(huds==1 and pg:FindFirstChild('TreadmillBonusRoll')~=nil and pg:FindFirstChild('TreadmillBonusProgress')==nil,'a re-run builds one fresh set of GUIs (and still no head pill)')
second.Destroying:Fire()
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
