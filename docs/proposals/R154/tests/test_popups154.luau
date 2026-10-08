--!nocheck
-- R154 (owner, after R153: "the numbers for speed also should be kept at a consistent size throughout, reduce the size of the speed notifier number by 20% and fix the glitchyness they have in them";
-- his screenshot: "+72K" popups of visibly different sizes over a treadmill, one half faded). The REAL SpeedGainPopup.client.lua + SpeedPopupStyle on the Roblox mock, frame by frame at 30 / 60 / 144 fps and
-- on every quality tier, with lag spikes and bursts:
--  1. size       35 / 32 px text and bolt, a 240 x 58 box, a 4 px outline: 0.8 of R153, on every pooled frame
--  2. constant   a popup is the same on-screen size from its first frame to its last: after the 0.28 s pop-in (0.45 -> 1.07 -> 1, the one allowed change) its UIScale is exactly the screen's unit, whatever
--                it is doing (flying, holding, fading, retired), whatever the frame rate, at any camera distance (the field is a pixel-sized BillboardGui: no scale component anywhere, so the
--                distance never reaches its size), and a resize of the window in flight does not change a popup that is already flying; text size, outline, box and tilt never change either
--  3. no reuse   a frame that is showing is never taken for a new popup (it used to jump to the new popup's place and text when every frame was busy: a lag spike); nothing is cut short by the cap in
--                the normal stream at any tier (the own caps were 6 / 4 on phones / FastMode / a slow Studio, below the 7 popups the stream keeps alive), and in a burst a cut popup fades out
--  4. smooth     frame to frame every popup moves on a straight line, never backwards, never faster than its curve allows, decelerating (the cubic ease-out) with no speed-up or stall in between;
--                the number is opaque to the fade and then clears in steps no bigger than its curve; the z order is the spawn order and never changes during a life; the fan hangs on the root at the head's
--                height: a head bob does not move it
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local C=PW.boot({})
local Style,me,pg=C.Style,C.Me,C.PG
local function head(p)return p.Character:FindFirstChild('Head')end
local camera=W.workspace.CurrentCamera
local function setDistance(d)camera.CFrame=R.CFrame.new(0,3+4,-d)end
setDistance(30)
-- the BillboardGui model: a size in offsets is pixels at any distance, a size in scale is studs and shrinks with the distance (fov 70 degrees)
local function projection(d,vh)return vh/(2*d*math.tan(math.rad(70)/2))end
local function pixels(udim,d,vh)return udim.Offset+udim.Scale*projection(d,vh)end

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
-- opts: tier, fps, seconds, hitch = {every = n frames, length = seconds}, burst = frame at which an award of 10 ticks arrives, distance, reduced, resizeAt = frame, resizeTo = viewport height, bob = true
local function run(o)
 PW.Tier=o.tier or 3;me:SetAttribute('FastMode',o.fast or nil);W.Gui.ReducedMotionEnabled=o.reduced==true
 if o.view then PW.view(o.view)end
 setDistance(o.distance or 30)
 local fps=o.fps or 60;local dt0=1/fps;local n=math.floor((o.seconds or 6)*fps+.5);local every=math.floor(fps/5+.5)
 local state={} -- frame instance -> {z, text, visible, pop = trace}
 local fires,times={},{} -- (every award: the time and what it is, every frame's time: to count what must be shown)
 local pops={};local t=0
 local out={Pops=pops,Reuse=0,Cut=0,CutOpaque=0,Spawned=0,MaxFrames=0,Unit=nil,ZDup=0}
 local root=me.Character.HumanoidRootPart;local headPart=head(me);local rest=headPart.Position;local anchors={}
 for f=0,n-1 do
  if f%every==0 then C.fire(me,4200,1,1/5);fires[#fires+1]={At=R.clock,Amount=4200,Ticks=1}end
  if o.burst and f==o.burst then C.fire(me,90000,10,1/5);fires[#fires+1]={At=R.clock,Amount=90000,Ticks=10}end
  if o.resizeAt and f==o.resizeAt then PW.view(o.resizeTo)end
  local dt=dt0;if o.hitch and f%o.hitch.every==o.hitch.every-1 then dt=o.hitch.length end
  if o.bob then headPart.Position=rest+V3(math.sin(f*1.7)*.35,math.sin(f*2.3)*.4,math.cos(f*1.3)*.2)end
  PW.frames(1,dt);t+=dt;times[#times+1]=R.clock
  local fl=PW.fieldOf(pg,head(me))
  if fl then
   if o.bob then local a=fl.Adornee.Position+fl.StudsOffsetWorldSpace;anchors[#anchors+1]=a end
   local frames=PW.frameList(fl);out.MaxFrames=math.max(out.MaxFrames,#frames)
   local zs={}
   for _,fr in ipairs(frames)do
    local st=state[fr] or{visible=false};state[fr]=st
    if fr.Visible then
     local r=PW.read(fr)
     if st.visible and(st.z~=r.ZIndex or st.text~=r.Text)then out.Reuse+=1;st.visible=false end -- a showing frame became another popup
     if not st.visible then
      out.Spawned+=1;st.visible=true;st.z=r.ZIndex;st.text=r.Text
      st.pop={Frame=fr,Z=r.ZIndex,Text=r.Text,T0=t,Samples={},LastSample=nil};pops[#pops+1]=st.pop
     end
     local p=st.pop;local s={t=t,dt=dt,X=r.X,Y=r.Y,Scale=r.Scale,Alpha=r.Alpha,Z=r.ZIndex,IconRot=r.IconRot,TextRot=r.TextRot,
      IconSize=fr.Lightning.TextSize,TextSize=fr.Amount.TextSize,BoxX=fr.Size.X.Offset,BoxY=fr.Size.Y.Offset,Stroke=fr.Amount.BoldOutline86.Thickness,
      Layout=fr.Lightning.Size.X.Offset}
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
 out.Anchors=anchors;out.Unit=Style.Unit(camera.ViewportSize.Y)
 PW.seconds(1.7);W.Gui.ReducedMotionEnabled=false;me:SetAttribute('FastMode',nil);PW.view(1080);headPart.Position=rest
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
-- the camera distance never reaches the size: the same popups at 6, 30 and 95 studs from the head are the same size at the same ages, and the field is the same number of pixels
do
 local at={}
 for _,d in ipairs({6,30,95})do
  local o=run({fps=60,seconds=4,distance=d});at[d]=o
  sizeChecks('camera '..d..' studs away',o,1)
 end
 local same=#at[6].Pops==#at[30].Pops and #at[30].Pops==#at[95].Pops;local diff=0
 if same then for i=1,#at[6].Pops do
  local a,b,c=at[6].Pops[i].Samples,at[30].Pops[i].Samples,at[95].Pops[i].Samples
  if #a~=#b or #b~=#c then diff+=1 else for j=1,#a do if a[j].Scale~=b[j].Scale or b[j].Scale~=c[j].Scale then diff+=1 end end end
 end end
 check(same and diff==0,'the popups\' scale, frame by frame, is identical at 6, 30 and 95 studs ('..#at[30].Pops..' popups; '..diff..' differences)')
 C.fire(me,4200,1,1/5);PW.frames(2,1/60)
 local f=PW.fieldOf(pg,head(me));local vh=camera.ViewportSize.Y
 local w6,w30,w95=pixels(f.Size.X,6,vh),pixels(f.Size.X,30,vh),pixels(f.Size.X,95,vh)
 check(w6==w30 and w30==w95 and w6==Style.Field.Width and f.Size.X.Scale==0 and f.Size.Y.Scale==0,'the field is '..w6..' px wide at 6, 30 and 95 studs (offset sizes only: a size in scale would be '..string.format('%.0f / %.0f / %.0f',pixels(R.UDim.new(1,0),6,vh),pixels(R.UDim.new(1,0),30,vh),pixels(R.UDim.new(1,0),95,vh))..' px)')
 check(f.AlwaysOnTop==true and f.MaxDistance==100 and f.Adornee~=nil,'(the field is still the pixel-sized, always-on-top billboard, gone past 100 studs)')
 PW.seconds(1.7)
end
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

print(('test_popups154: %d checks, %d failed'):format(checks,fails))
if fails>0 then error('test_popups154 failed',0)end
