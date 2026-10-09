--!nocheck
-- R154 (owner, after R153: "the numbers for speed also should be kept at a consistent size throughout, reduce the size of the speed notifier number by 20% and fix the glitchyness they have in them";
-- his screenshot: "+72K" popups of visibly different sizes over a treadmill, one half faded). The REAL SpeedGainPopup.client.lua + SpeedPopupStyle on the Roblox mock, frame by frame at 30 / 60 / 144 fps and
-- on every quality tier, with lag spikes and bursts:
--  1. size       35 / 32 px text and bolt, a 240 x 58 box, a 4 px outline: 0.8 of R153, on every pooled frame
--  2. constant   a popup is the same on-screen size from its first frame to its last: after the 0.28 s pop-in (0.45 -> 1.07 -> 1, the one allowed change) its UIScale is exactly the screen's unit, whatever
--                it is doing (flying, holding, fading, retired), whatever the frame rate, and a resize of the window in flight does not change a popup that is already flying; text size,
--                outline, box and tilt never change either. (R155: the camera distance does not reach a popup either - only the field's zoom container, section 5 - so every check of 1-4 runs
--                at the game's default camera zoom, 12.5 studs, where the popups are exactly what R154 drew)
--  3. no reuse   a frame that is showing is never taken for a new popup (it used to jump to the new popup's place and text when every frame was busy: a lag spike); nothing is cut short by the cap in
--                the normal stream at any tier (the own caps were 6 / 4 on phones / FastMode / a slow Studio, below the 7 popups the stream keeps alive), and in a burst a cut popup fades out
--  4. smooth     frame to frame every popup moves on a straight line, never backwards, never faster than its curve allows, decelerating (the cubic ease-out) with no speed-up or stall in between;
--                the number is opaque to the fade and then clears in steps no bigger than its curve; the z order is the spawn order and never changes during a life; the fan hangs on the root at the head's
--                height: a head bob does not move it
--  5. zoom       (R155, owner: "make the speed popups consistent in size so when zooming out they don't become bigger they stay consistent in their size when zooming out at a certain point it
--                can disappear it's ok") the popups are world-sized: at the default zoom (12.5 studs from the head) they are the R154 size, at 2x that distance half, at 4x a quarter (hidden), capped at
--                1.3x when the camera is close (first person included), faded over 31.25 .. 36.46 studs (text 14 -> 12 px at 1080 p) and hidden past; at any fixed zoom a popup's on-screen size is
--                steady for its whole life; a zoom change in flight moves the one container scale smoothly (no jump, nothing else changes, at most one write a frame, none while the camera rests);
--                every field is scaled by its own distance; nothing else in the PlayerGui is touched; the field holds the biggest fan at the cap
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local C=PW.boot({})
local Style,me,pg=C.Style,C.Me,C.PG
local function head(p)return p.Character:FindFirstChild('Head')end
local camera=W.workspace.CurrentCamera
-- (R155) the camera d studs from the head (PW.camera: straight behind it, at its height); the game's default zoom is 12.5 studs
local function setDistance(d)PW.camera(d)end
setDistance(PW.ZoomDistance)
local zoomWrites,zoomShows=0,0 -- property writes seen on the field's zoom container (its UIScale.Scale, its Visible), counted by listeners
local watched,posWatched,posWrites={},{},0 -- (posWrites: writes to the Position of any popup frame seen so far)

-- 1. size ---------------------------------------------------------------------------------------------------------------------------------------------
C.fire(me,72000,1,1/5);PW.frames(2,1/60)
local field=PW.fieldOf(pg,head(me))
local sz=Style.Size
check(sz.Text==35 and sz.Icon==32 and sz.Box[1]==240 and sz.Box[2]==58 and sz.IconBox==38 and sz.Gap==3 and Style.StrokeThickness==4,'R154: text 35, bolt 32, box 240 x 58, bolt box 38, gap 3, outline 4 (0.8 of R153)')
do
 local ok=true;local n=0
 for _,fr in ipairs(PW.frameList(field))do
  n+=1
  local icon,amt=fr.Lightning,fr.Amount
  if not(icon.TextSize==32 and amt.TextSize==35 and icon.Size.X.Offset==38 and icon.Size.Y.Offset==58 and fr.Size.X.Offset==240 and fr.Size.Y.Offset==58 and icon.BoldOutline86.Thickness==4 and amt.BoldOutline86.Thickness==4)then ok=false end
  if fr.Size.X.Scale~=0 or fr.Size.Y.Scale~=0 or icon.Size.X.Scale~=0 or icon.Size.Y.Scale~=0 or amt.Size.Y.Scale~=0 or amt.TextScaled==true then ok=false end
 end
 check(ok and n>=10,'every pooled popup ('..n..' frames) is built at those sizes, in pixels (no scale component, no TextScaled)')
end
PW.seconds(1.7)

-- the scenario runner: frame by frame, every popup traced from its first frame to its last ---------------------------------------------------------------
-- opts: tier, fps, seconds, hitch = {every = n frames, length = seconds}, burst = frame at which an award of 10 ticks arrives, distance (studs from the head, default 12.5 = the game's default zoom),
-- distanceAt = function(t) -> studs (the camera moves while it runs), reduced, resizeAt = frame, resizeTo = viewport height, bob = true
local function run(o)
 PW.Tier=o.tier or 3;me:SetAttribute('FastMode',o.fast or nil);W.Gui.ReducedMotionEnabled=o.reduced==true
 if o.view then PW.view(o.view)end
 local curD=o.distance or PW.ZoomDistance;setDistance(curD)
 local fps=o.fps or 60;local dt0=1/fps;local n=math.floor((o.seconds or 6)*fps+.5);local every=math.floor(fps/5+.5)
 local state={} -- frame instance -> {z, text, visible, pop = trace}
 local fires,times={},{} -- (every award: the time and what it is, every frame's time: to count what must be shown)
 local pops={};local t=0
 local out={Pops=pops,Reuse=0,Cut=0,CutOpaque=0,Spawned=0,MaxFrames=0,Unit=nil,ZDup=0,ZoomWriteFrames=0,MaxZoomWrites=0,ZoomWrites={},ZoomShowFlips=0}
 local seen,lastW,lastS=false,0,0;local pos0=posWrites
 local root=me.Character.HumanoidRootPart;local headPart=head(me);local rest=headPart.Position;local anchors={}
 for f=0,n-1 do
  if f%every==0 then C.fire(me,4200,1,1/5);fires[#fires+1]={At=R.clock,Amount=4200,Ticks=1}end
  if o.burst and f==o.burst then C.fire(me,90000,10,1/5);fires[#fires+1]={At=R.clock,Amount=90000,Ticks=10}end
  if o.resizeAt and f==o.resizeAt then PW.view(o.resizeTo)end
  local dt=dt0;if o.hitch and f%o.hitch.every==o.hitch.every-1 then dt=o.hitch.length end
  if o.bob then headPart.Position=rest+V3(math.sin(f*1.7)*.35,math.sin(f*2.3)*.4,math.cos(f*1.3)*.2)end
  if o.distanceAt then curD=o.distanceAt(t);setDistance(curD)end
  PW.frames(1,dt);t+=dt;times[#times+1]=R.clock
  local fl=PW.fieldOf(pg,head(me))
  local zf=fl and fl:FindFirstChild('Zoom');local zu=zf and zf:FindFirstChildOfClass('UIScale')
  if zu and not watched[zu]then -- (writes are counted from the frame after the field is first seen: its first scale is written when it is taken)
   watched[zu]=true;zu:GetPropertyChangedSignal('Scale'):Connect(function()zoomWrites+=1 end);zf:GetPropertyChangedSignal('Visible'):Connect(function()zoomShows+=1 end)
  end
  if zu then
   if seen then
    local w=zoomWrites-lastW;out.ZoomWrites[#out.ZoomWrites+1]={t=t,w=w};out.MaxZoomWrites=math.max(out.MaxZoomWrites,w);if w>0 then out.ZoomWriteFrames+=1 end
    out.ZoomShowFlips+=zoomShows-lastS
   end
   seen=true;lastW,lastS=zoomWrites,zoomShows
  end
  if fl then
   if o.bob then local a=fl.Adornee.Position+fl.StudsOffsetWorldSpace;anchors[#anchors+1]=a end
   local frames=PW.frameList(fl);out.MaxFrames=math.max(out.MaxFrames,#frames)
   local zs={}
   for _,fr in ipairs(frames)do
    local st=state[fr] or{visible=false};state[fr]=st
    if not posWatched[fr]then posWatched[fr]=true;fr:GetPropertyChangedSignal('Position'):Connect(function()posWrites+=1 end)end
    if fr.Visible then
     local r=PW.read(fr)
     if st.visible and(st.z~=r.ZIndex or st.text~=r.Text)then out.Reuse+=1;st.visible=false end -- a showing frame became another popup
     if not st.visible then
      out.Spawned+=1;st.visible=true;st.z=r.ZIndex;st.text=r.Text
      st.pop={Frame=fr,Z=r.ZIndex,Text=r.Text,T0=t,Samples={},LastSample=nil};pops[#pops+1]=st.pop
     end
     local p=st.pop;local s={t=t,dt=dt,X=r.X,Y=r.Y,Scale=r.Scale,Alpha=r.Alpha,Z=r.ZIndex,IconRot=r.IconRot,TextRot=r.TextRot,
      IconSize=fr.Lightning.TextSize,TextSize=fr.Amount.TextSize,BoxX=fr.Size.X.Offset,BoxY=fr.Size.Y.Offset,Stroke=fr.Amount.BoldOutline86.Thickness,
      Layout=fr.Lightning.Size.X.Offset,Zoom=zu.Scale,ZoomShown=zf.Visible,Dist=curD}
     p.Samples[#p.Samples+1]=s
     if r.Scale>0 then zs[r.ZIndex]=(zs[r.ZIndex]or 0)+1 end
    elseif st.visible then
     st.visible=false;local p=st.pop;p.T1=t
     local last=p.Samples[#p.Samples];local life=t-p.T0
     p.EndAlpha=last and last.Alpha or 0
     -- (a retired popup fades in 0.08 s; a frame longer than that - a lag spike - shows no fade at all, by the clock: only frames of at most 0.1 s are judged)
     if life<Style.Life-.03-dt then out.Cut+=1;p.Cut=true;if p.EndAlpha>.5 and dt<=.1 then out.CutOpaque+=1 end end
    end
   end
   for _,c in pairs(zs)do if c>1 then out.ZDup+=1 end end
  end
 end
 -- what must have been shown: every share of every award whose first frame (the first at or after its time) is less than a life later (an older one is skipped, as always)
 local expected=0;local split=Style.SplitFor(true,o.reduced==true)
 for _,fe in ipairs(fires)do
  local shares=Style.Shares(fe.Amount,fe.Ticks,split);local spacing=Style.Spacing(1/5,split,shares)
  for i=1,shares do
   local at=fe.At+(i-1)*spacing
   for _,T in ipairs(times)do if T>=at then if T-at<Style.Life then expected+=1 end;break end end
  end
 end
 out.Expected=expected
 out.Anchors=anchors;out.Unit=Style.Unit(camera.ViewportSize.Y);out.PosWrites=posWrites-pos0
 PW.camera();PW.seconds(1.7);W.Gui.ReducedMotionEnabled=false;me:SetAttribute('FastMode',nil);PW.view(1080);headPart.Position=rest
 return out
end
local function fanOf()local v=camera.ViewportSize;return Style.FanScale(v.X,v.Y)end

-- 2. constant size ----------------------------------------------------------------------------------------------------------------------------------
-- (scale 1 x unit from 0.28 s on: the samples whose age since the popup's first frame is at least 0.30 s are exactly the unit; every sample is inside the pop's 0.45 .. 1.07)
local function sizeChecks(tag,o,unit)
 local worstLate,worstPop,lateN,drift=0,0,0,0
 local lo,hi=Style.Pop.From*unit-.003,(1+.075)*unit+.003
 for _,p in ipairs(o.Pops)do
  local s0=p.Samples[1]
  for _,s in ipairs(p.Samples)do
   if s.Scale<lo or s.Scale>hi then worstPop=math.max(worstPop,math.max(lo-s.Scale,s.Scale-hi))end
   if s.t-p.T0>=.30 then lateN+=1;worstLate=math.max(worstLate,math.abs(s.Scale-unit))end
   if s.IconSize~=Style.Size.Icon or s.TextSize~=Style.Size.Text or s.BoxX~=Style.Size.Box[1] or s.BoxY~=Style.Size.Box[2] or s.Stroke~=Style.StrokeThickness or s.Layout~=Style.Size.IconBox then drift+=1 end
   if s.IconRot~=s0.IconRot or s.TextRot~=s0.TextRot then drift+=1 end
  end
 end
 check(#o.Pops>=38 and lateN>=100,tag..': '..#o.Pops..' popups, '..lateN..' samples after the pop')
 check(worstLate<=.0025*unit,string.format('%s: from 0.30 s on every popup is exactly %.3f x (the screen\'s unit) whatever it is doing: worst %.4f',tag,unit,worstLate))
 check(worstPop<=1e-9,tag..': at any time a popup is between 0.45 and 1.07 of that size (the pop-in is the only change)')
 check(drift==0,tag..': text size, bolt size, box, outline, bolt box and tilt never change during a life ('..drift..' changes)')
end
for _,fps in ipairs({30,60,144})do
 local o=run({fps=fps,seconds=5})
 sizeChecks(fps..' fps',o,1)
end
-- retired popups (a lower cap on the style table) keep their size while they fade out
do
 local saved=Style.Caps[1].Own;Style.Caps[1].Own=4
 local o=run({tier=1,fps=60,seconds=5});Style.Caps[1].Own=saved
 sizeChecks('retired by a cap of 4',o,1)
 check(o.Cut>=20,'(a cap of 4 does cut popups: '..o.Cut..' of '..#o.Pops..')')
end
-- other screens: the unit follows the screen height (once per popup, at its birth)
for _,h in ipairs({540,720,1440})do
 local o=run({fps=60,seconds=4,view=h});sizeChecks(h..' px high',o,Style.Unit(h))
end
PW.view(1080)
-- (the camera distance and the popups' zoom: section 5, after the rest; everything above and below runs at the default zoom, 12.5 studs)
-- a window resize while popups fly: the ones in flight keep their size and keep moving the same way (each takes the unit and fan at its birth)
do
 local o=run({fps=60,seconds=4,resizeAt=120,resizeTo=720,view=1080})
 local big,small=0,0;local jumps=0
 for _,p in ipairs(o.Pops)do
  for i,s in ipairs(p.Samples)do
   if i>1 then local a=p.Samples[i-1];if math.abs(s.Scale-a.Scale)>.12 and s.t-p.T0>.3 then jumps+=1 end end
   if s.t-p.T0>=.3 then if math.abs(s.Scale-1)<.003 then big+=1 elseif math.abs(s.Scale-.8)<.003 then small+=1 else jumps+=1 end end
  end
 end
 check(jumps==0 and big>0 and small>0,'a resize from 1080 to 720 px high in flight: popups born before keep 1.00, popups born after are 0.80 ('..big..' / '..small..' samples), none changes size after its pop ('..jumps..' jumps)')
end
PW.view(1080)

-- 3. no reuse of a live popup, nothing cut in the normal stream --------------------------------------------------------------------------------------------
for _,tier in ipairs({3,2,1})do
 for _,fps in ipairs({30,60,144})do
  local o=run({tier=tier,fps=fps,seconds=6})
  check(o.Reuse==0 and o.Cut==0 and o.Spawned==o.Expected,string.format('tier %d, %d fps, the normal stream: %d popups (%d due), none cut short by the cap (%d), no showing frame reused (%d), at most %d frames',tier,fps,o.Spawned,o.Expected,o.Cut,o.Reuse,o.MaxFrames))
 end
 -- lag spikes (a 0.35 s frame every 1.5 s) and an award of 10 ticks on top
 local o=run({tier=tier,fps=60,seconds=9,hitch={every=90,length=.35},burst=200})
 check(o.Reuse==0,string.format('tier %d with 0.35 s lag spikes and a burst: %d popups, a showing frame reused %d times (R153: 12 on tier 3)',tier,o.Spawned,o.Reuse))
 check(o.CutOpaque==0,string.format('... and every popup the cap cuts (%d) fades out first: none vanishes opaque (%d)',o.Cut,o.CutOpaque))
 check(o.Spawned==o.Expected,string.format('... and every award is shown: %d popups for %d shares due (none dropped when every frame is busy: the pool grows)',o.Spawned,o.Expected))
 check(o.MaxFrames<=(Style.Field.MaxFrames or 0),string.format('... the pool stays within %d frames (%d)',Style.Field.MaxFrames or 0,o.MaxFrames))
end
do
 local o=run({tier=1,fast=true,fps=60,seconds=6})
 check(o.Cut==0 and o.Reuse==0,'FastMode (always tier 1): the stream is not cut short ('..o.Cut..' of '..#o.Pops..')')
 local cut=run({tier=1,fps=60,seconds=6,burst=120})
 check(cut.Reuse==0,'a burst on tier 1: no reuse')
end
-- (every popup of a burst is shown once, with its own number: each text appears as many times as it was awarded)
do
 local o=run({tier=3,fps=60,seconds=6})
 local zs={};local ordered=true;local lastZ=-1
 table.sort(o.Pops,function(a,b)return a.T0<b.T0 or(a.T0==b.T0 and a.Z<b.Z)end)
 for _,p in ipairs(o.Pops)do if p.Z<=lastZ then ordered=false end;lastZ=p.Z end
 check(ordered and o.ZDup==0 and o.Reuse==0,'z order: the newest popup is on top (ZIndex rises with every spawn), no two showing popups share one, a popup\'s never changes while it shows ('..o.ZDup..' shared, '..o.Reuse..' changed)')
end

-- 4. smooth motion ---------------------------------------------------------------------------------------------------------------------------------------
local function motionChecks(tag,o,fanX,fanY,unit)
 local vmax=Style.Fling.Power*Style.Fling.Radius[2]/Style.Fling.Time*unit*math.max(fanX,fanY)*1.02 -- px / s at the first instant of the cubic ease-out, the biggest fan
 local backwards,toofast,speedup,n=0,0,0,0;local worstUp=0
 for _,p in ipairs(o.Pops)do
  local S=p.Samples
  for i=2,#S do
   local a,b=S[i-1],S[i];local dx,dy=b.X-a.X,b.Y-a.Y;local step=math.sqrt(dx*dx+dy*dy);n+=1
   if step>vmax*b.dt+.2 then toofast+=1 end
   if i>=3 then
    local pa=S[i-2];local px,py=a.X-pa.X,a.Y-pa.Y
    if px*dx+py*dy<-.01 then backwards+=1 end
    if pa.dt==a.dt and a.dt==b.dt and step>math.sqrt(px*px+py*py)+.35 and b.t-p.T0<=Style.Fling.Time+.05 then speedup+=1;worstUp=math.max(worstUp,step-math.sqrt(px*px+py*py))end
   end
  end
 end
 check(n>=300,tag..': '..n..' frame-to-frame moves measured')
 check(backwards==0,tag..': no popup ever moves backwards between two frames ('..backwards..')')
 check(toofast==0,string.format('%s: none moves faster than its curve (%.0f px/s at the first instant) allows ('..toofast..')',tag,vmax))
 check(speedup==0,string.format('%s: the flight decelerates frame by frame: no speed-up or stall in between (%d; worst +%.2f px)',tag,speedup,worstUp))
 -- the number is opaque until the fade and clears in steps no bigger than its curve; never brighter again
 local back,jump,opaqueLate=0,0,0
 for _,p in ipairs(o.Pops)do
  local S=p.Samples
  for i=2,#S do
   local a,b=S[i-1],S[i]
   if b.Alpha>a.Alpha+.004 then back+=1 end
   if a.Alpha-b.Alpha>b.dt/Style.RetireFade+.02 then jump+=1 end
   if b.t-p.T0<Style.Fade.Start-.03 and b.Alpha<.999 then opaqueLate+=1 end
  end
 end
 check(back==0 and opaqueLate==0,tag..': a popup is opaque until its fade and never gets brighter again ('..back..' / '..opaqueLate..')')
 check(jump==0,tag..': the number clears in steps no bigger than the fade\'s (the retire fade at the fastest) ('..jump..' bigger)')
end
for _,fps in ipairs({30,60,144})do
 local o=run({fps=fps,seconds=5});local fx,fy=fanOf();motionChecks(fps..' fps',o,fx,fy,1)
end
do local fx,fy=fanOf();local o=run({fps=60,seconds=6,tier=1});motionChecks('tier 1, 60 fps',o,fx,fy,1)end
-- at a phone's fan too
do
 PW.view(390);W.workspace.CurrentCamera.ViewportSize=R.Vector2.new(844,390);local fx,fy=fanOf()
 local o=run({fps=60,seconds=5});motionChecks('844 x 390 phone (fan '..string.format('%.2f x %.2f',fx,fy)..')',o,fx,fy,Style.Unit(390))
 PW.view(1080)
end
-- Reduced Motion: it rises, never backwards, never changes size
do
 local o=run({fps=60,seconds=5,reduced=true});local bad,scaleBad=0,0
 for _,p in ipairs(o.Pops)do for i=2,#p.Samples do local a,b=p.Samples[i-1],p.Samples[i];if b.Y>a.Y+.01 then bad+=1 end;if b.Scale~=1 then scaleBad+=1 end end end
 check(#o.Pops>=15 and bad==0 and scaleBad==0,'Reduced Motion: '..#o.Pops..' popups rise (never down) and keep their size ('..bad..' / '..scaleBad..')')
end
-- the same through lag spikes: positions are by the clock (a long frame moves a popup further, never back), sizes stay
do
 local o=run({fps=60,seconds=9,hitch={every=90,length=.35},burst=200})
 local back=0;local late=0
 for _,p in ipairs(o.Pops)do
  for i=3,#p.Samples do local a,b,c=p.Samples[i-2],p.Samples[i-1],p.Samples[i];if(b.X-a.X)*(c.X-b.X)+(b.Y-a.Y)*(c.Y-b.Y)<-.01 then back+=1 end end
  for _,s in ipairs(p.Samples)do if s.t-p.T0>=.3 and math.abs(s.Scale-1)>.0025 then late+=1 end end
 end
 check(back==0 and late==0,'through 0.35 s lag spikes and a burst: no popup moves backwards ('..back..') and none changes size after its pop ('..late..')')
end
-- the fan hangs on the root at the head's height: a head bob (the treadmill run) does not move it
do
 local o=run({fps=60,seconds=3,bob=true})
 local a0=o.Anchors[1];local worst=0
 for _,a in ipairs(o.Anchors)do worst=math.max(worst,(a-a0).Magnitude)end
 local root=me.Character.HumanoidRootPart
 check(#o.Anchors>=100 and worst<1e-9,'a head bob of +-0.4 stud every frame moves the fan by '..worst..' stud ('..#o.Anchors..' frames)')
 C.fire(me,4200,1,1/5);PW.frames(2,1/60);local fl=PW.fieldOf(pg,head(me))
 check(fl.Adornee==root and fl.StudsOffsetWorldSpace.Y>0,'the field is adorned to the HumanoidRootPart with a world offset up to the head')
 PW.seconds(1.7)
end


-- 5. the zoom (R155) ---------------------------------------------------------------------------------------------------------------------------------------
-- The owner's rule, as numbers: the popups behave like objects in the world. Roblox's default camera zoom is 12.5 studs (nothing in the game sets it; the place's StarterPlayer has Roblox's 0.5 / 128
-- and GiantVisualSafety caps it at 100): there the popups are exactly the R154 size (35 px text at 1080 p). Zoomed out they shrink in proportion to the camera's distance to the head
-- (25 studs: half, 50: a quarter), fade between the distance where the text is 14 px (31.25 studs) and 12 px (36.46) and are gone past it. Closer than 9.6 studs they stop growing at 1.3x.
-- The expected values below are written from those rules, not read from the code under test.
local Z=Style.Zoom
check(Z.Distance==12.5 and Z.MaxScale==1.3 and Z.FadeText==14 and Z.HideText==12 and Z.Epsilon<=.005 and Style.Size.Text==35,'R155 zoom numbers: default distance 12.5 studs, cap 1.3x, fade from 14 px text, hidden at 12 px')
local function expScale(d)return math.min(12.5/math.max(d,.05),1.3)end
local function expFade(d)local sc=expScale(d);return math.max(0,math.min(1,(sc-12/35)/(14/35-12/35)))end
local FADE_AT,HIDE_AT=12.5*35/14,12.5*35/12 -- 31.25 and 36.46 studs
-- (a) the pure curve ----------------------------------------------------------------------------------------------------------------------------------------
do
 local s1,f1=Style.ZoomScale(12.5);local s2,f2=Style.ZoomScale(25);local s4,f4=Style.ZoomScale(50);local sc,fc=Style.ZoomScale(12.5/1.3)
 check(s1==1 and f1==1,'ZoomScale(12.5) = 1, fully clear: the R154 size at the default zoom')
 check(math.abs(s2-.5)<1e-12 and f2==1 and math.abs(35*s2-17.5)<1e-9,'ZoomScale(25) = 0.5: twice as far, half the size (17.5 px text), still clear')
 check(math.abs(s4-.25)<1e-12 and f4==0,'ZoomScale(50) = 0.25 and gone (fade 0): four times as far')
 check(math.abs(sc-1.3)<1e-12,'the cap starts at 12.5 / 1.3 = 9.6 studs')
 local ok=true
 for _,d in ipairs({9,8,5,2,1,.5,.1,0,-3,-1e9})do local s0,f0=Style.ZoomScale(d);if s0~=1.3 or f0~=1 then ok=false end end
 check(ok,'closer than 9.6 studs, first person (0.5, 0.1, 0 studs) and nonsense below zero: capped at exactly 1.3, clear')
 local sn,fn=Style.ZoomScale(0/0);local sx,fx=Style.ZoomScale('far');local sm,fm=Style.ZoomScale(nil);local si,fi=Style.ZoomScale(math.huge)
 check(sn==1 and fn==1 and sx==1 and fx==1 and sm==1 and fm==1 and si==1 and fi==1,'bad numbers (NaN, infinity, a string, nil) read as the default distance: the popups are what R154 drew')
 local sh,fh=Style.ZoomScale(HIDE_AT);local sf,ff=Style.ZoomScale(FADE_AT)
 check(math.abs(35*sh-12)<1e-9 and fh==0 and math.abs(35*sf-14)<1e-9 and math.abs(ff-1)<1e-9,string.format('the cutoff: the text is 12.0 px at %.2f studs (gone), 14.0 px at %.2f (the fade starts)',HIDE_AT,FADE_AT))
 local mono,smooth,prevS,prevF=true,true,nil,nil
 for i=0,2400 do
  local d=i*.05;local s0,f0=Style.ZoomScale(d)
  if prevS and(s0>prevS+1e-12 or f0>prevF+1e-12)then mono=false end
  if prevF and math.abs(f0-prevF)>.02 then smooth=false end
  if f0<0 or f0>1 or s0>1.3+1e-12 then mono=false end
  prevS,prevF=s0,f0
 end
 check(mono and smooth,'0 .. 120 studs: scale and fade only ever fall with the distance, fade 0..1 in steps of at most 0.02 per 0.05 stud (no jump), scale never above 1.3')
end

-- (b) the real client at a fixed zoom: the on-screen size is the world-consistent one and steady ------------------------------------------------------------------
-- on-screen text px = TextSize x the popup's UIScale x the field container's UIScale (a BillboardGui sized in offsets draws one pixel per unit)
local function zoomChecks(tag,o,d,fadeToo)
 local unit=o.Unit;local want=35*unit*expScale(d);local worst,lo,hi,n,shown,hidden=0,math.huge,0,0,0,0
 local zoomWorst=0;local alphaWorst=0;local alphaN=0
 for _,p in ipairs(o.Pops)do
  for _,s in ipairs(p.Samples)do
   if s.ZoomShown then shown+=1 else hidden+=1 end
   zoomWorst=math.max(zoomWorst,math.abs(s.Zoom-expScale(d)))
   if s.t-p.T0>=.30 then
    local px=s.TextSize*s.Scale*s.Zoom;n+=1
    worst=math.max(worst,math.abs(px-want)/want);lo=math.min(lo,px);hi=math.max(hi,px)
    if fadeToo and s.t-p.T0<=Style.Fade.Start-.04 then alphaN+=1;alphaWorst=math.max(alphaWorst,math.abs(s.Alpha-expFade(d)))end
   end
  end
 end
 check(n>=100 and shown>0 and hidden==0,string.format('%s: %d popups, %d samples after the pop, the zoom container is shown',tag,#o.Pops,n))
 check(zoomWorst<=1e-9,string.format('%s: the container scale is exactly min(1.3, 12.5 / %.2f) = %.4f (off by %.1e)',tag,d,expScale(d),zoomWorst))
 check(worst<=Z.Epsilon/expScale(d)+1e-9 and(hi-lo)/want<1e-9,string.format('%s: on-screen text %.2f px = 35 x %.3f x unit, the same for every popup and every frame of its life (spread %.1e)',tag,want,expScale(d),(hi-lo)/want))
 if fadeToo then check(alphaN>=100 and alphaWorst<=.0045,string.format('%s: the fade: alpha %.3f while held (off by %.4f)',tag,expFade(d),alphaWorst))end
end
local zoomRun={}
for _,d in ipairs({.3,3,6.25,9.6,12.5,18.75,25,31})do
 local o=run({fps=60,seconds=4,distance=d});zoomRun[d]=o
 sizeChecks(string.format('zoom %.2f studs',d),o,1) -- (the popup itself: pop-in, then exactly the screen's unit, at every distance)
 zoomChecks(string.format('zoom %.2f studs',d),o,d,true)
 check(o.MaxZoomWrites==0,string.format('zoom %.2f studs, camera at rest: no write on the container after its first one (%d)',d,o.ZoomWriteFrames))
end
do
 local o=zoomRun[12.5];local exact=true
 for _,p in ipairs(o.Pops)do for _,s in ipairs(p.Samples)do if s.Zoom~=1 then exact=false end end end
 check(exact,'at the default zoom, 12.5 studs, the container scale is exactly 1: popups are what R154 drew (35 px text, 32 px bolt, 240 x 58 box at 1080 p)')
 local function late(o2)local v;for _,p in ipairs(o2.Pops)do for _,s in ipairs(p.Samples)do if s.t-p.T0>=.3 then v=v or s.TextSize*s.Scale*s.Zoom end end end return v end
 local t1,t2,t4=late(zoomRun[12.5]),late(zoomRun[25]),late(zoomRun[6.25])
 check(math.abs(t2/t1-.5)<=.004 and math.abs(t4/t1-1.3)<1e-9,string.format('twice the default distance (25 studs): %.2f px = %.3f of the default size %.2f px (half); half the distance (6.25): %.2f px, capped at 1.3',t2,t2/t1,t1,t4))
 local t3,t5,t6=late(zoomRun[18.75]),late(zoomRun[9.6]),late(zoomRun[3])
 check(math.abs(t3/t1-12.5/18.75)<=.004 and math.abs(t5/t1-1.3)<1e-9 and t6==t5 and late(zoomRun[.3])==t5,string.format('in between it is proportional (18.75 studs: %.3f of the default); 9.6, 3 and 0.3 studs (first person) are all the capped %.2f px',t3/t1,t5))
end
-- (c) the fade and the hiding ---------------------------------------------------------------------------------------------------------------------------------
do
 local last=2
 for _,d in ipairs({32,34,36})do
  local o=run({fps=60,seconds=4,distance=d})
  zoomChecks(string.format('zoom %.0f studs (fading)',d),o,d,true)
  local a=expFade(d);check(a<last and a>0,string.format('(%.0f studs: fade %.3f, text %.1f px)',d,a,35*expScale(d)));last=a
 end
 for _,d in ipairs({36.5,40,60,95})do
  local o=run({fps=60,seconds=3,distance=d});local shown,n=0,0
  for _,p in ipairs(o.Pops)do for _,s in ipairs(p.Samples)do n+=1;if s.ZoomShown then shown+=1 end end end
  check(n>=50 and shown==0,string.format('%.1f studs away: the zoom container is hidden for all %d samples of %d popups (nothing drawn)',d,n,#o.Pops))
  check(o.PosWrites==0,string.format('... and a hidden field is not moved: %d position writes on its popups (the first frame it shows again writes the whole pose)',o.PosWrites))
 end
end

-- (d) a zoom change in flight: smooth, one container scale, nothing else moves ----------------------------------------------------------------------------------------
do
 local function path(t)
  if t<1 then return 12.5 elseif t<2.5 then return 12.5+(25-12.5)*(t-1)/1.5 elseif t<3.5 then return 25 elseif t<5 then return 25-(25-12.5)*(t-3.5)/1.5 else return 12.5 end
 end
 local o=run({fps=60,seconds=6.5,distanceAt=path})
 sizeChecks('zoom 12.5 -> 25 -> 12.5 in flight',o,1)
 local stepMax,worstTrack,jumpPx,n=0,0,0,0
 local lastZoom
 for _,p in ipairs(o.Pops)do
  for i,s in ipairs(p.Samples)do
   worstTrack=math.max(worstTrack,math.abs(s.Zoom-expScale(s.Dist)))
   if i>1 and s.t-p.T0>=.3 then
    local a=p.Samples[i-1];local pa,pb=a.TextSize*a.Scale*a.Zoom,s.TextSize*s.Scale*s.Zoom;n+=1
    jumpPx=math.max(jumpPx,math.abs(pb-pa))
   end
  end
 end
 -- the camera moves 12.5 studs in 1.5 s = 0.139 stud a frame: the text changes by at most 35 x 12.5 / (12.5)^2 x 0.139 = 0.39 px a frame at the near end
 check(n>=300 and jumpPx<=.45,string.format('a zoom change in flight changes a popup\'s on-screen size by %.2f px a frame at most (%d steps): no jump',jumpPx,n))
 check(worstTrack<=Z.Epsilon+1e-9,string.format('the container scale follows min(1.3, 12.5 / distance) frame by frame to within the epsilon (%.4f)',worstTrack))
 local moving,rest,restFrames=0,0,0
 for _,w in ipairs(o.ZoomWrites)do
  local inRamp=(w.t>1.0 and w.t<=2.55)or(w.t>3.5 and w.t<=5.05)
  if inRamp then moving+=w.w elseif w.t>2.6 and w.t<3.45 or w.t>5.1 then rest+=w.w;restFrames+=1 end
 end
 check(o.MaxZoomWrites<=1 and moving>0 and rest==0 and restFrames>60,string.format('at most one write a frame on the container (%d), %d while the camera moves, %d in %d frames while it rests',o.MaxZoomWrites,moving,rest,restFrames))
 local fx,fy=fanOf();motionChecks('zoom 12.5 -> 25 -> 12.5',o,fx,fy,1) -- (the popups\' own motion in the container is not touched by the zoom: a straight, decelerating flight)
end
-- a camera that jumps (a teleport, a zoom key held: the very next frame is already at the new size, nothing eases late)
do
 local o=run({fps=60,seconds=4,distanceAt=function(t)return t<2 and 12.5 or 25 end})
 local before,after,flip=nil,nil,nil
 for _,p in ipairs(o.Pops)do for _,s in ipairs(p.Samples)do
  if s.Dist==12.5 then before=s.Zoom elseif not after then after=s.Zoom end
 end end
 local late=true
 for _,p in ipairs(o.Pops)do for _,s in ipairs(p.Samples)do if s.Dist==25 and math.abs(s.Zoom-.5)>1e-9 then late=false end end end
 check(before==1 and after==.5 and late,'a camera that jumps from 12.5 to 25 studs: every frame at 25 studs already has the half-size container (no lag, no easing)')
end
-- the camera wobbles by less than the epsilon (a runner's bob, a camera spring): nothing is written
do
 local o=run({fps=60,seconds=3,distanceAt=function(t)return 12.5+.012*math.sin(t*40)end})
 local all=0;for _,w in ipairs(o.ZoomWrites)do all+=w.w end
 check(all==0 and #o.ZoomWrites>100,string.format('a +-0.012 stud wobble of the camera (%.2f px of text) writes nothing in %d frames',35*(12.5/12.488-1),#o.ZoomWrites))
end

-- (e) out past the cutoff and back: hidden while far, the popups in flight come back at their true place ----------------------------------------------------------
do
 -- a trapezoid between the default zoom and 45 studs, 0.4 s each way, 0.25 s rest at the default zoom, 0.27 s far, period 1.37 s (not a multiple of the popups' 0.1 s: every phase of a flight is caught)
 local function tri(t)
  local u=t%1.37
  if u<.25 then return 12.5 elseif u<.65 then return 12.5+(45-12.5)*(u-.25)/.4 elseif u<.92 then return 45 elseif u<1.32 then return 45-(45-12.5)*(u-.92)/.4 else return 12.5 end
 end
 local o=run({fps=60,seconds=11,distanceAt=tri})
 local badShown,badAlpha,n,returns,stale=0,0,0,0,0
 for _,p in ipairs(o.Pops)do
  local S=p.Samples
  for i,s in ipairs(S)do
   n+=1
   if s.ZoomShown~=(expFade(s.Dist)>0)then badShown+=1 end
   if s.ZoomShown and s.t-p.T0>=.3 and s.t-p.T0<=Style.Fade.Start-.04 and math.abs(s.Alpha-expFade(s.Dist))>.0045 then badAlpha+=1 end
   -- a popup that comes back into view after its flight (0.4 s; it then rests until it is gone at 0.65 s) is already at its resting spot on the very first frame it shows again: no snap on the next frame
   if i>1 and i<#S and s.ZoomShown and not S[i-1].ZoomShown and s.t-p.T0>=.42 and S[i+1].ZoomShown and s.t-p.T0<Style.Fade.Start+.08 then
    returns+=1;if math.abs(S[i+1].X-s.X)>.06 or math.abs(S[i+1].Y-s.Y)>.06 then stale+=1 end
   end
  end
 end
 check(n>=300 and badShown==0,string.format('out to 45 studs and back 8 times: the container is shown exactly while the distance is under %.2f studs (%d wrong of %d samples)',HIDE_AT,badShown,n))
 check(badAlpha==0,'... and while shown, a held popup\'s alpha is the fade of its distance (the fade band is crossed in both directions) ('..badAlpha..' wrong)')
 check(returns>=6 and stale==0,string.format('... %d popups came back into view after their flight: each is already at its resting place on the first frame (%d snapped)',returns,stale))
 check(o.MaxZoomWrites<=1,'... at most one container write a frame ('..o.MaxZoomWrites..')')
 check(o.ZoomShowFlips==16,'... the container is shown / hidden only when it crosses the cutoff ('..o.ZoomShowFlips..' changes in 8 round trips)')
end

-- (f) Reduced Motion keeps the world size; a later run at the default zoom is back to exactly R154 -------------------------------------------------------------------
do
 local o=run({fps=60,seconds=4,distance=25,reduced=true});local ok,n=true,0
 for _,p in ipairs(o.Pops)do for _,s in ipairs(p.Samples)do if s.t-p.T0>=.3 then n+=1;if math.abs(s.TextSize*s.Scale*s.Zoom-17.5)>.15 then ok=false end end end end
 check(n>=50 and ok,'Reduced Motion at 25 studs: also half size (the zoom is the size of a thing in the world, not a motion)')
 local o2=run({fps=60,seconds=4});local back=true
 for _,p in ipairs(o2.Pops)do for _,s in ipairs(p.Samples)do if s.Zoom~=1 or not s.ZoomShown then back=false end end end
 check(back,'a field that was hidden or half size is back to scale 1 and shown when it is taken again at the default zoom')
end

-- (g) every field is scaled by its own distance --------------------------------------------------------------------------------------------------------------------
do
 PW.camera(12.5)
 local other=PW.newPlayer('FarRunner',{Pos=V3(0,3,20)}) -- 20 studs in front of the near runner: 32.5 studs from the camera
 local gone=PW.newPlayer('GoneRunner',{Pos=V3(0,3,40)}) -- 52.5 studs
 C.fire(me,4200,1,1/5);C.fire(other,4200,1,1/5);C.fire(gone,4200,1,1/5);PW.frames(4,1/60)
 local fMe,fOther,fGone=PW.fieldOf(pg,head(me)),PW.fieldOf(pg,head(other)),PW.fieldOf(pg,head(gone))
 local function zoomOf(f)local z=f:FindFirstChild('Zoom');return z:FindFirstChildOfClass('UIScale').Scale,z.Visible end
 check(fMe~=nil and fOther~=nil and fGone~=nil,'three runners with popups, three fields')
 local a,av=zoomOf(fMe);local b,bv=zoomOf(fOther);local c,cv=zoomOf(fGone)
 check(a==1 and av and math.abs(b-12.5/32.5)<1e-9 and bv and not cv,string.format('each field has its own scale: yours %.3f (12.5 studs), the one 32.5 studs away %.3f and shown (fading), the one 52.5 studs away hidden',a,b))
 local far=PW.visible(fOther)[1];local rf=far and PW.read(far)
 check(far~=nil and math.abs(rf.Alpha-expFade(32.5))<=.0045,string.format('... and the far runner\'s popup is faded to %.2f of its alpha (%.3f)',expFade(32.5),rf and rf.Alpha or -1))
 PW.seconds(1.2);PW.leave(other);PW.leave(gone)
 PW.seconds(.5)
end

-- (h) nothing else is touched; no new allocation; the field holds the biggest fan at the cap -----------------------------------------------------------------
do
 -- another BillboardGui of the game (a name tag): its size and its own UIScale are what they were after a stream with the camera moving all over the place
 run({fps=60,seconds=3}) -- (a stream first: the pooled field the next one takes is built whole)
 local tag=R.new('BillboardGui');tag.Name='NameTag';tag.Size=R.UDim2.fromOffset(120,30);tag.Parent=pg
 local tagScale=R.new('UIScale');tagScale.Scale=1;tagScale.Parent=tag
 local tagLabel=R.new('TextLabel');tagLabel.Text='Someone';tagLabel.TextSize=18;tagLabel.Parent=tag
 local snap={Size=tag.Size,Scale=tagScale.Scale,Text=tagLabel.Text,TextSize=tagLabel.TextSize,Visible=tagLabel.Visible,Enabled=tag.Enabled,MaxDistance=tag.MaxDistance}
 local writesBefore=0;for _,x in ipairs({tag,tagScale,tagLabel})do x.Changed:Connect(function()writesBefore+=1 end)end
 local created0=#R.created
 run({fps=60,seconds=4,distanceAt=function(t)return 12.5+30*math.abs(math.sin(t*1.3))end})
 check(writesBefore==0 and tag.Size==snap.Size and tagScale.Scale==snap.Scale and tagLabel.Text==snap.Text and tagLabel.TextSize==snap.TextSize and tag.Enabled==snap.Enabled and tag.MaxDistance==snap.MaxDistance,
  'another BillboardGui (a name tag) and its UIScale are not touched by the popups\' zoom ('..writesBefore..' writes)')
 check(#R.created==created0,'a stream with the camera moving 12.5 .. 42.5 studs creates no Instance ('..(#R.created-created0)..')')
 local fl;C.fire(me,4200,1,1/5);PW.frames(2,1/60);fl=PW.fieldOf(pg,head(me))
 local kids=fl:GetChildren()
 local z=fl:FindFirstChild('Zoom')
 check(#kids==1 and kids[1]==z and z.ClassName=='Frame' and z.AnchorPoint.X==.5 and z.AnchorPoint.Y==.5 and z.Position.X.Scale==.5 and z.Position.Y.Scale==.5 and z.Position.X.Offset==0
  and z.Size.X.Scale==1 and z.Size.Y.Scale==1 and z.Size.X.Offset==0 and z.Size.Y.Offset==0 and z.BackgroundTransparency==1 and z.ClipsDescendants~=true and #z:GetChildren()==1+#PW.frameList(fl)
  and z:FindFirstChildOfClass('UIScale')~=nil,'the field holds one container (centred, filling the billboard, clear, not clipping) with the UIScale and every popup frame in it')
 check(fl.AlwaysOnTop==true and fl.MaxDistance==100 and fl.Adornee~=nil and fl.Size.X.Scale==0 and fl.Size.Y.Scale==0 and fl.Size.X.Offset==Style.Field.Width and fl.Size.Y.Offset==Style.Field.Height,
  '(the billboard itself is as before: pixel-sized, always on top, gone past 100 studs, on the root)')
 PW.seconds(1.7)
 -- the pooled field holds the biggest fan (the 4K screen, X and Y at their biggest, the pop\'s overshoot) at the zoom cap too, so nothing is cut at the billboard\'s edge
 local sz=Style.Size;local u=Style.Unit(2160);local x,y=Style.FanScale(3840,2160)
 local halfW=(sz.IconBox+sz.Gap+7*sz.Text*.55)/2*u*1.07;local halfH=sz.Text*.6*u*1.07
 local reachX=(Style.Spawn.Jitter+math.sin(math.rad(Style.Fling.HalfAngle))*Style.Fling.Radius[2])*u*x+halfW
 local reachY=(Style.Spawn.Lift+Style.Fling.Radius[2])*u*y+halfH
 check(reachX*2*Z.MaxScale<=Style.Field.Width and reachY*2*Z.MaxScale<=Style.Field.Height,string.format('the field (%d x %d) holds the biggest fan on a 4K screen at the 1.3 cap (%.0f x %.0f)',Style.Field.Width,Style.Field.Height,reachX*2*Z.MaxScale,reachY*2*Z.MaxScale))
end

print(('test_popups154: %d checks, %d failed'):format(checks,fails))
if fails>0 then error('test_popups154 failed',0)end
