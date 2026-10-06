--!nocheck
-- R151 speed popups on the Roblox mock with the REAL SpeedGainPopup.client.lua + SpeedPopupStyle (+ the V134 belt arrows that share the script):
--  pooling and the one updater, the curves at sample times (pop, fling, hold, fade, life), the per-tier caps (own / others, FastMode = tier 1), splitting an award
--  (the sum is exact, 10 a second at the server's 1/5 s step), Reduced Motion, other players (range, caps, not split), a player leaving or resetting, hostile events, the units, our colours /
--  font / bolt unchanged, no leak after 10,000 awards, and the belt arrows still working.
-- Run from a scratch folder holding roblox.luau, world.luau (R123), speed_popups_world.luau and rs_bundle.luau (run_speed_popups.sh does it).
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local V3=R.Vector3.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
local amounts={}
local C=PW.boot({beforeLoad=function(c)
 local fmt=c.Style.FormatGain
 c.Style.FormatGain=function(a)amounts[#amounts+1]=a;return fmt(a)end -- every amount the client puts on a popup
end})
local Style,me,pg,Run=C.Style,C.Me,C.PG,W.Run
local function head(p)return p.Character:FindFirstChild('Head')end
local function settle()PW.seconds(1.7)end
local function maxFrames(field)return #PW.frameList(field)end
local function sum(list,from)local s=0;for i=from or 1,#list do s+=list[i]end;return s end
local pose0={Angle=0,Radius=0,StartX=0,StartY=0}
local poolSize=Style.Cap(3,true,false)+Style.Field.Spare -- own cap 8 at tier 3 + 2 spare
-- R153: the fan's size on the current screen (SpeedPopupStyle.FanScale: 2 x 2 on a desktop; the offsets of a popup are its design px x unit x these)
local function fan()local v=W.workspace.CurrentCamera.ViewportSize;return Style.FanScale(v.X,v.Y)end

-- 0. boot: nothing built, nothing running ----------------------------------------------------------------------------------------------------------------
check(PW.live(Run.RenderStepped)==0,'idle: no per-frame updater before the first award ('..PW.live(Run.RenderStepped)..')')
check(PW.live(Run.Heartbeat)==1,'the only Heartbeat listener of the script is the belt arrows block (1)')
check(#PW.fields(pg)==0,'nothing is built before the first popup (no field, no frame)')
local created0=#R.created

-- 1. the first award --------------------------------------------------------------------------------------------------------------------------------------
C.fire(me,4200,1,1/5)
check(PW.live(Run.RenderStepped)==1,'an award connects the one updater')
check(PW.visibleAll(pg)==0,'nothing shows before the first frame')
PW.frames(1,0)
local field=PW.fields(pg)[1]
check(#PW.fields(pg)==1 and field.Enabled==true and field.Adornee==head(me),'one field, on, adorned to the head')
check(field.AlwaysOnTop==true and field.MaxDistance==100 and field.LightInfluence==0 and field.ResetOnSpawn==false and field.Active==false,'field: AlwaysOnTop, 100 studs, no light, no reset on spawn')
check(field.Size.X.Scale==0 and field.Size.Y.Scale==0 and field.Size.X.Offset==Style.Field.Width and field.Size.Y.Offset==Style.Field.Height,'field: a fixed pixel size (no scale: the same on screen at any camera distance)')
check(field.StudsOffset==nil or field.StudsOffset==V3(0,0,0),'field: centred on the head (no studs offset)')
local vis=PW.visible(field)
check(#vis==1,'first frame: the first share shows ('..#vis..')')
local r=PW.read(vis[1])
check(r.Text=='+2.1K','an award of 4200 is shown as two shares of 2.1K ('..r.Text..')')
check(near(r.Scale,0.45,1e-6) and r.Alpha==1,'born at 0.45 size, opaque ('..r.Scale..')')
local fx,fy=fan()
check(math.abs(r.X)<=Style.Spawn.Jitter*fx+1e-6 and near(r.Y,-Style.Spawn.Lift*fy,1e-6),'born at the head (within '..Style.Spawn.Jitter*fx..' px, '..Style.Spawn.Lift*fy..' px up, the 2x fan '..fx..' x '..fy..'): '..r.X..', '..r.Y)
PW.frames(4,1/120)
check(#PW.visible(field)==1,'the second share is not there before 1/10 s')
PW.frames(10,1/120)
check(#PW.visible(field)==2,'the second share shows after 1/10 s (10 a second)')
check(#amounts==2 and amounts[1]==2100 and amounts[2]==2100 and sum(amounts)==4200,'the two shares add up to the award')
settle()
check(PW.visibleAll(pg)==0 and PW.live(Run.RenderStepped)==0,'done: all popups hidden, the updater disconnected')
check(field.Enabled==false and field.Adornee==nil,'done: the field is parked (off, no adornee)')
check(#PW.fields(pg)==1 and #PW.frameList(field)==poolSize,'done: the field and its frames are kept for the next run')
check(#PW.frameList(field)==poolSize and #R.created-created0==1+7*poolSize,'the pool is built whole at first use: 1 field + '..poolSize..' popups (cap 8 + 2 spare) of 7 Instances ('..(#R.created-created0)..')')

-- 2. the curves at sample times ----------------------------------------------------------------------------------------------------------------------------
do
 for i=#amounts,1,-1 do amounts[i]=nil end
 C.fire(me,4200,1,1/5)
 PW.frames(1,0)
 local f=PW.fields(pg)[1];local A=PW.visible(f)[1]
 local rows={};local secondAt
 for k=0,90 do
  local t=k/120
  local row={t=t,visible=A.Visible}
  if A.Visible then row.r=PW.read(A)end
  rows[k]=row
  if not secondAt and #PW.visible(f)==2 then secondAt=t end
  PW.frames(1,1/120)
 end
 local p0=rows[0].r;local pEnd=rows[60].r
 local D=math.sqrt((pEnd.X-p0.X)^2+(pEnd.Y-p0.Y)^2)
 local fx,fy=fan()
 check(D>=40*math.min(fx,fy) and D<=120*math.max(fx,fy),'fling: the resting spot is 44..104 px (x the screen\'s fan '..fx..' x '..fy..') from the head (+ start offset): '..D)
 local worstScale,worstAlpha,worstPos,worstIcon,worstStroke,peak,peakAt=0,0,0,0,0,0,0
 local holdMove=0
 for k=0,90 do
  local row=rows[k];local t=row.t
  if math.abs(t-Style.Life)>0.012 then
   check(row.visible==(t<Style.Life),'life: visible exactly until 0.65 s (t='..t..' visible='..tostring(row.visible)..')')
  end
  if row.visible then
   local r=row.r
   local _,_,scale,alpha=Style.Pose(pose0,t,false)
   worstScale=math.max(worstScale,math.abs(r.Scale-scale))
   worstAlpha=math.max(worstAlpha,math.abs(r.Alpha-alpha))
   worstIcon=math.max(worstIcon,math.abs(r.IconAlpha-r.Alpha));worstStroke=math.max(worstStroke,math.abs(r.StrokeAlpha-r.Alpha))
   if r.Scale>peak then peak,peakAt=r.Scale,t end
   if t>0 and t<=0.5 then
    local frac=math.sqrt((r.X-p0.X)^2+(r.Y-p0.Y)^2)/D
    worstPos=math.max(worstPos,math.abs(frac-Style.EaseOut(t/Style.Fling.Time,Style.Fling.Power)))
   end
   if t>=0.4 and t<=0.5 then holdMove=math.max(holdMove,math.abs(r.X-pEnd.X)+math.abs(r.Y-pEnd.Y))end
  end
 end
 check(worstScale<=0.0025,'pop: the size follows the back-out curve at every sample (worst '..worstScale..')')
 check(worstAlpha<=0.0045,'fade: opaque to 0.5 s, linear to clear at 0.65 s at every sample (worst '..worstAlpha..')')
 check(worstIcon<=1e-9 and worstStroke<=1e-9,'fade: the bolt, the number and both outlines fade together')
 check(worstPos<=0.01,'fling: the flight is a cubic ease-out over 0.4 s at every sample (worst '..worstPos..' of the trip)')
 check(holdMove<=0.06,'hold: it rests from 0.4 s to 0.5 s ('..holdMove..' px)')
 check(peak>1.05 and peak<1.10 and peakAt>=0.12 and peakAt<=0.2,'pop: peaks at '..string.format('%.3f',peak)..' at '..string.format('%.3f',peakAt)..' s (the clip: ~1.06 at ~0.13 s)')
 check(near(rows[0].r.Scale,0.45) and near(rows[34].r.Scale,1,0.0025) and near(rows[70].r.Scale,1,0.0025),'size: 0.45 at birth, back to 1 from 0.28 s')
 check(secondAt and secondAt>=0.09 and secondAt<=0.12,'the second share is born at 1/10 s ('..tostring(secondAt)..')')
 check(rows[10].r.Alpha==1 and rows[76].visible==true and rows[76].r.Alpha<0.3 and rows[76].r.Alpha>0,'it is still there, nearly clear, just before 0.65 s')
 settle()
end

-- 3. units: the sizes follow the screen height ---------------------------------------------------------------------------------------------------------------
for _,case in ipairs({{360,0.8},{720,0.8},{1080,1},{1296,1.2},{2160,1.35}})do
 PW.view(case[1]);C.fire(me,1000,1,1/5);PW.frames(1,0)
 local f=PW.fields(pg)[1];local r=PW.read(PW.visible(f)[1])
 local _,fy=fan()
 check(near(r.Scale,0.45*case[2],1e-6) and near(r.Y,-Style.Spawn.Lift*case[2]*fy,1e-6),'unit at '..case[1]..' px high: '..case[2]..' (size '..r.Scale..', offset '..r.Y..', fan Y '..fy..')')
 settle()
end
PW.view(1080)

-- 4. caps per tier: own (split, 10 a second) and others (not split, 5 a second) at the server's 1/5 s step; FastMode is tier 1 ---------------------------------------------------------
local other=PW.newPlayer('Other',{Pos=V3(12,3,8)})
local lastAlphaOfHidden={}
local function stream(player,seconds,cap)
 local n=math.floor(seconds*60+.5);local maxVisible,maxPool=0,0;local prev={};local worstVanish=0;local opaqueMax=0
 local f0=nil
 for f=0,n-1 do
  if f%12==0 then C.fire(player,4200,1,1/5)end
  PW.frames(1,1/60)
  local field=PW.fieldOf(pg,head(player))
  if field then
   f0=field
   local v=PW.visible(field)
   if f>=100 then maxVisible=math.max(maxVisible,#v)end
   maxPool=math.max(maxPool,maxFrames(field))
   local opaque=0
   for _,fr in ipairs(PW.frameList(field))do
    local was=prev[fr];local rd=PW.read(fr)
    if fr.Visible then
     prev[fr]=rd.Alpha
     if rd.Alpha>=0.999 then opaque+=1 end
    else
     if was~=nil then worstVanish=math.max(worstVanish,was);prev[fr]=nil end
    end
   end
   if f>=100 then opaqueMax=math.max(opaqueMax,opaque)end
  end
 end
 return maxVisible,maxPool,worstVanish,opaqueMax,f0
end
local before
for _,case in ipairs({{1,4,1},{2,6,2},{3,8,3}})do
 local tier,ownCap,otherCap=case[1],case[2],case[3]
 -- own
 PW.Tier=tier;before=#amounts
 local maxVisible,maxPool,worstVanish,opaqueMax=stream(me,4,ownCap)
 check(maxPool<=poolSize,'tier '..tier..' own: the pooled field holds at most '..poolSize..' frames, never more ('..maxPool..')')
 local cap=Style.Cap(tier,true,false)
 if tier<3 then check(maxVisible>=cap and maxVisible<=cap+Style.Field.Spare,'tier '..tier..' own: the cap binds, '..cap..' alive (+ the ones fading out): '..maxVisible)
 else check(maxVisible>=6 and maxVisible<=cap+Style.Field.Spare,'tier 3 own: about 6.5 alive at 10 a second, at most '..(cap+2)..': '..maxVisible)end
 check(opaqueMax<=cap+1,'tier '..tier..' own: never more than cap (+1 on the frame that replaces one) fully opaque: '..opaqueMax)
 check(worstVanish<=0.45,'tier '..tier..' own: nothing vanishes while opaque, the cap fades the oldest in 0.08 s (last alpha seen '..string.format('%.2f',worstVanish)..')')
 check(#amounts-before>=38 and #amounts-before<=42,'tier '..tier..' own: 10 popups a second (2 per 1/5 s tick): '..(#amounts-before)..' in 4 s')
 settle()
 -- others
 before=#amounts
 local mv,mp,wv=stream(other,4,otherCap)
 local ocap=Style.Cap(tier,false,false)
 check(ocap==otherCap and mp<=Style.Cap(3,true,false)+Style.Field.Spare,'tier '..tier..' other: the field (a pooled one, maybe built for the local player) never holds more than '..(Style.Cap(3,true,false)+Style.Field.Spare)..' frames ('..mp..')')
 check(mv>=ocap and mv<=ocap+Style.Field.Spare,'tier '..tier..' other: '..ocap..' alive (+ fading): '..mv)
 check(#amounts-before>=18 and #amounts-before<=22,'tier '..tier..' other: NOT split, 5 popups a second: '..(#amounts-before)..' in 4 s')
 settle()
end
-- FastMode is tier 1 whatever the governor says
PW.Tier=3;me:SetAttribute('FastMode',true)
do
 local mv,mp=stream(me,3,4)
 check(mv<=4+Style.Field.Spare and mp<=10,'FastMode: own cap 4 even with tier 3 from the governor ('..mv..')')
 check(mv>=4,'FastMode: and it still shows 4')
 settle()
 local ov=stream(other,3,1)
 check(ov<=1+Style.Field.Spare,'FastMode: others cap 1 ('..ov..')')
 settle()
end
me:SetAttribute('FastMode',nil)
-- the pool never grew past the largest cap + 2
do
 local biggest=0;for _,fl in ipairs(PW.fields(pg))do biggest=math.max(biggest,maxFrames(fl))end
 check(biggest<=Style.Cap(3,true,false)+Style.Field.Spare,'the biggest field holds at most '..(Style.Cap(3,true,false)+Style.Field.Spare)..' frames ('..biggest..')')
end

-- 5. splitting an award: the sum is exact, every share at least 1 -------------------------------------------------------------------------------------------
PW.Tier=3
local function shown(player,amount,ticks,interval)
 for i=#amounts,1,-1 do amounts[i]=nil end
 C.fire(player,amount,ticks,interval)
 PW.seconds(1.6,1/120)
 local list=table.clone(amounts)
 settle()
 return list
end
for _,case in ipairs({{1,1},{2,1},{3,1},{4200,1},{100001,1},{5,3},{3,5},{123457,10},{7,10},{999999999,1},{1000000000,1},{4200,2},{4200,1,0.1},{4200,1,1},{9,1,0.5}})do
 local amount,ticks,interval=case[1],case[2],case[3]
 local list=shown(me,amount,ticks,interval or 1/5)
 local expect=math.max(1,math.min(amount,(ticks)*2,12))
 local minShare=math.huge;for _,v in ipairs(list)do minShare=math.min(minShare,v)end
 check(sum(list)==amount and #list==expect and minShare>=1,'own '..amount..' x'..ticks..' ticks: '..#list..' shares (expected '..expect..') add up to '..sum(list)..', smallest '..tostring(minShare))
end
for _,case in ipairs({{4200,1},{5,3},{123457,10},{1,1}})do
 local list=shown(other,case[1],case[2],1/5)
 local expect=math.max(1,math.min(case[1],case[2],12))
 check(sum(list)==case[1] and #list==expect,'other '..case[1]..' x'..case[2]..' ticks: not split, '..#list..' popups (expected '..expect..'), sum '..sum(list))
end
check(#shown(me,0.5,1,1/5)==0 and #shown(me,0,1,1/5)==0 and #shown(me,-3,1,1/5)==0,'less than 1 point: nothing')
do local list=shown(me,4200.9,1,1/5);check(sum(list)==4200,'a fractional award counts its whole points')end

-- 6. the stream is even: a popup every 1/10 s -------------------------------------------------------------------------------------------------------------------
do
 for i=#amounts,1,-1 do amounts[i]=nil end
 local birth={}
 for f=0,119 do
  if f%12==0 then C.fire(me,4200,1,1/5)end
  PW.frames(1,1/60)
  birth[#birth+1]=#amounts
 end
 check(birth[#birth]==20,'two seconds: 20 popups spawned, 10 a second ('..birth[#birth]..')')
 local evenGaps=true
 local prevCount=0
 for f=1,#birth do
  local d=birth[f]-prevCount
  if d>1 then evenGaps=false end -- never two in one 1/60 s frame (they are 1/10 s apart)
  prevCount=birth[f]
 end
 check(evenGaps,'never two popups born in the same frame (they are 1/10 s apart)')
 settle()
end

-- 7. z order: the newest is drawn on top ---------------------------------------------------------------------------------------------------------------------------
do
 C.fire(me,4200,1,1/5);PW.frames(1,0)
 local older=PW.visible(PW.fieldOf(pg,head(me)))[1]
 PW.seconds(0.3,1/120)
 local list=PW.visible(PW.fieldOf(pg,head(me)))
 check(#list==2 and older~=nil,'two popups visible for the z-order check ('..#list..')')
 local newer;for _,fr in ipairs(list)do if fr~=older then newer=fr end end
 check(newer~=nil and newer.ZIndex>older.ZIndex,'the newer popup has the higher ZIndex ('..tostring(newer and newer.ZIndex)..' > '..older.ZIndex..')')
 settle()
end

-- 8. Reduced Motion -------------------------------------------------------------------------------------------------------------------------------------------
W.Gui.ReducedMotionEnabled=true
do
 for i=#amounts,1,-1 do amounts[i]=nil end
 C.fire(me,4200,1,1/5);PW.frames(1,0)
 local f=PW.fieldOf(pg,head(me));local A=PW.visible(f)[1]
 check(A~=nil and #amounts==1 and amounts[1]==4200,'reduced: one popup per award, with the whole number (no split): '..#amounts)
 local rows={};local x0
 for k=0,90 do
  local t=k/120;rows[k]={t=t,v=A.Visible,r=A.Visible and PW.read(A)or nil};PW.frames(1,1/120)
 end
 local worstY,worstA,xs,scaleOk,rotOk=0,0,{},true,true
 for k=0,90 do
  local row=rows[k]
  if math.abs(row.t-Style.Reduced.Life)>0.012 then check(row.v==(row.t<Style.Reduced.Life),'reduced: visible until 0.7 s (t='..row.t..')')end
  if row.v then
   local r=row.r
   local _,y,_,alpha=Style.Pose({StartY=-Style.Spawn.Lift,ReducedX=14},row.t,true)
   local fx,fy=fan();y*=fy
   worstY=math.max(worstY,math.abs(r.Y-y));worstA=math.max(worstA,math.abs(r.Alpha-alpha))
   xs[#xs+1]=r.X;if not near(r.Scale,1,1e-9)then scaleOk=false end
   if r.IconRot~=0 or r.TextRot~=0 then rotOk=false end
  end
 end
 local fx0=fan();local sameX=true;for _,x in ipairs(xs)do if not near(math.abs(x),14*fx0,1e-6) or not near(x,xs[1],1e-6)then sameX=false end end
 check(worstY<=0.06,'reduced: rises 72 px with an ease-out, no fling (worst '..worstY..' px)')
 check(worstA<=0.0045,'reduced: fades in and out (worst '..worstA..')')
 check(sameX and scaleOk and rotOk,'reduced: stays on its side, never changes size, no tilt')
 local first=rows[0].r
 check(first.Alpha==0 and first.Scale==1,'reduced: born clear at full size (no pop)')
 check(near(rows[40].r.Alpha,1,1e-6) and rows[78].v==true and rows[78].r.Alpha<0.5,'reduced: fully opaque from 0.08 s, fading from 0.45 s')
 settle()
 -- caps: own 4 / others 1 at any tier, 5 popups a second
 before=#amounts
 local mv=stream(me,4,4)
 check(mv<=4+Style.Field.Spare and mv>=3,'reduced: own cap 4 ('..mv..')')
 check(#amounts-before>=18 and #amounts-before<=22,'reduced: 5 a second, not split ('..(#amounts-before)..')')
 settle()
 local ov=stream(other,3,1)
 check(ov<=1+Style.Field.Spare,'reduced: others cap 1 ('..ov..')')
 settle()
 -- alternate sides
 local sides={}
 for i=1,4 do
  C.fire(me,100,1,1/5);PW.frames(1,0)
  local newest;for _,fr in ipairs(PW.visible(PW.fieldOf(pg,head(me))))do if not newest or fr.ZIndex>newest.ZIndex then newest=fr end end
  sides[#sides+1]=PW.read(newest).X;PW.seconds(0.2,1/60)
 end
 check(sides[1]*sides[2]<0 and sides[2]*sides[3]<0 and sides[3]*sides[4]<0,'reduced: consecutive popups alternate left and right')
 settle()
end
W.Gui.ReducedMotionEnabled=false

-- 9. other players: range, training, hidden when far ----------------------------------------------------------------------------------------------------
do
 local far=PW.newPlayer('Far',{Pos=V3(0,3,300)})
 C.fire(far,4200,1,1/5);PW.seconds(0.5,1/60)
 check(PW.fieldOf(pg,head(far))==nil and PW.visibleAll(pg)==0,'another player 330 studs away: nothing is drawn or built')
 local near1=PW.newPlayer('Near',{Pos=V3(0,3,60)})
 C.fire(near1,4200,1,1/5);PW.frames(2,1/60)
 local f=PW.fieldOf(pg,head(near1))
 check(f~=nil and #PW.visible(f)==1,'another player in range: one popup per award')
 settle()
 -- cutoff: camera at (0,20,-30); a head 100 studs away or more is not shown
 local edge=PW.newPlayer('Edge',{Pos=V3(0,3,68)}) -- head at (0,4.5,68): 99.2 from the camera
 local edgeDist=(W.workspace.CurrentCamera.CFrame.Position-head(edge).Position).Magnitude
 C.fire(edge,4200,1,1/5);PW.frames(2,1/60)
 check(edgeDist<100 and PW.fieldOf(pg,head(edge))~=nil,'a head '..string.format('%.1f',edgeDist)..' studs away is shown')
 settle()
 local past=PW.newPlayer('Past',{Pos=V3(0,3,72)}) -- 103.2
 local pastDist=(W.workspace.CurrentCamera.CFrame.Position-head(past).Position).Magnitude
 C.fire(past,4200,1,1/5);PW.frames(2,1/60)
 check(pastDist>100 and PW.fieldOf(pg,head(past))==nil,'a head '..string.format('%.1f',pastDist)..' studs away is not')
 -- not on the treadmill (any more): not shown
 near1:SetAttribute('TreadmillTraining',false)
 C.fire(near1,4200,1,1/5);PW.seconds(0.4,1/60)
 check(PW.fieldOf(pg,head(near1))==nil,'a player that is not training shows nothing')
 near1:SetAttribute('TreadmillTraining',true)
 -- the camera moves away: an award is dropped; the billboard also hides itself past 100 studs (MaxDistance)
 W.workspace.CurrentCamera.CFrame=R.CFrame.new(0,20,-200)
 C.fire(other,4200,1,1/5);PW.seconds(0.4,1/60)
 check(PW.fieldOf(pg,head(other))==nil,'the camera is far from the head: dropped at once')
 C.fire(me,4200,1,1/5);PW.seconds(0.4,1/60)
 check(PW.fieldOf(pg,head(me))==nil,'(the same rule for the local player: nothing is drawn 200 studs away)')
 W.workspace.CurrentCamera.CFrame=R.CFrame.new(0,20,-30)
 settle()
 for _,p in ipairs({far,near1,edge,past})do PW.leave(p)end
end

-- 10. a player leaves or resets -------------------------------------------------------------------------------------------------------------------------------
do
 local leaver=PW.newPlayer('Leaver',{Pos=V3(6,3,6)})
 for f=0,29 do if f%12==0 then C.fire(leaver,4200,1,1/5)end;PW.frames(1,1/60)end
 local lf=PW.fieldOf(pg,head(leaver))
 check(lf~=nil and #PW.visible(lf)>=2,'leaver: popups are showing')
 local enabledBefore=PW.enabledFields(pg)
 PW.leave(leaver)
 check(#PW.visible(lf)==0 and lf.Enabled==false and lf.Adornee==nil,'leaver: at the moment of leaving every popup is hidden and the field is parked')
 check(PW.enabledFields(pg)==enabledBefore-1,'leaver: no field of theirs is left on')
 local created=#R.created
 C.fire(leaver,4200,1,1/5);PW.seconds(0.4,1/60)
 check(PW.fieldOf(pg,head(leaver))==nil and #R.created==created,'leaver: a late award for a player who left builds nothing')
 settle()
 -- a reset: the old character is replaced
 local resetter=PW.newPlayer('Resetter',{Pos=V3(-6,3,6)})
 local oldChar=resetter.Character
 for f=0,29 do if f%12==0 then C.fire(resetter,4200,1,1/5)end;PW.frames(1,1/60)end
 local rf=PW.fieldOf(pg,head(resetter))
 check(rf~=nil and #PW.visible(rf)>=2,'reset: popups are showing before the reset')
 local newChar,newHead=PW.spawnCharacter(resetter,V3(-6,3,6))
 PW.frames(1,1/60)
 check(#PW.visible(rf)==0 and rf.Enabled==false,'reset: the next frame hides the old character\'s popups and parks the field')
 C.fire(resetter,4200,1,1/5,oldChar);PW.seconds(0.4,1/60)
 check(PW.visibleAll(pg)==0,'reset: an award earned by the OLD character shows nothing')
 C.fire(resetter,4200,1,1/5,newChar);PW.frames(2,1/60)
 local nf=PW.fieldOf(pg,newHead)
 check(nf~=nil and #PW.visible(nf)==1 and nf.Adornee==newHead,'reset: the new character\'s award shows on the new head')
 -- the old character is still around for a moment after a reset (Roblox removes it later): its award shows nothing either
 do
  local stale=PW.newPlayer('Stale',{Pos=V3(4,3,4)})
  local oldModel=stale.Character
  local replacement=R.new('Model');replacement.Parent=W.workspace
  local rh=R.new('Part');rh.Name='Head';rh.Position=V3(4,4.5,4);rh.Parent=replacement
  stale.Character=replacement -- oldModel is intact, with its Head, still in the workspace
  C.fire(stale,4200,1,1/5,oldModel);PW.seconds(0.4,1/60)
  check(PW.fieldOf(pg,oldModel:FindFirstChild('Head'))==nil and PW.fieldOf(pg,rh)==nil,'reset: an award earned by the old character (still in the world) shows nothing')
  C.fire(stale,4200,1,1/5,replacement);PW.frames(2,1/60)
  check(PW.fieldOf(pg,rh)~=nil,'reset: the replacement character\'s award does')
  settle();PW.leave(stale)
 end
 -- the head is destroyed (the character dies): at once gone
 PW.seconds(0.2,1/60)
 newHead:Destroy()
 PW.frames(1,1/60)
 check(PW.visibleAll(pg)==0 and PW.enabledFields(pg)==0,'dying: a destroyed head takes its popups with it')
 settle()
 PW.leave(resetter)
 -- training stops in the middle of a burst: the queued shares are dropped, the shown ones finish
 for i=#amounts,1,-1 do amounts[i]=nil end
 C.fire(me,100000,10,1/5) -- 12 shares over a second
 PW.seconds(0.2,1/60)
 local sofar=#amounts
 me:SetAttribute('TreadmillTraining',false)
 PW.seconds(1.2,1/60)
 check(sofar>=2 and #amounts==sofar and #amounts<12,'stopping: the queued shares are dropped ('..sofar..' shown of 12, none after)')
 check(PW.visibleAll(pg)==0 and PW.live(Run.RenderStepped)==0,'stopping: the shown ones finished and the updater is off')
 me:SetAttribute('TreadmillTraining',true)
 -- a burst of 10 ticks: 12 popups over a second, every share counted, the cap respected
 local list=shown(me,100000,10,1/5)
 check(#list==12 and sum(list)==100000,'a lag burst of 10 ticks: 12 popups, sum exact')
 -- the player's own character reset
 local c0=me.Character
 C.fire(me,4200,1,1/5);PW.seconds(0.2,1/60)
 local mf=PW.fieldOf(pg,head(me));check(mf~=nil and #PW.visible(mf)>=1,'own reset: popups are showing')
 local nc,nh=PW.spawnCharacter(me,V3(0,3,0));PW.frames(1,1/60)
 check(PW.visibleAll(pg)==0,'own reset: gone with the old character')
 C.fire(me,4200,1,1/5,c0);PW.seconds(0.3,1/60);check(PW.visibleAll(pg)==0,'own reset: an old-character award shows nothing')
 C.fire(me,4200,1,1/5,nc);PW.frames(2,1/60);check(PW.visibleAll(pg)>=1 and PW.fieldOf(pg,nh)~=nil,'own reset: the new character\'s award shows')
 settle()
end

-- 11. hostile or broken events: nothing shows, nothing errors -----------------------------------------------------------------------------------------------
do
 local ok=true
 local part=R.new('Part')
 local bad={{nil,100},{'Me',100},{part,100},{me,'100'},{me,nil},{me,-5},{me,0},{me,0/0},{me,math.huge},{me,1000000001},{me,{}},{me,true},{me,0.9}}
 for _,b in ipairs(bad)do
  local good,err=pcall(C.fire,b[1],b[2],1,1/5)
  if not good then ok=false;print('error: '..tostring(err))end
 end
 PW.seconds(0.5,1/60)
 check(ok,'bad arguments raise no error')
 check(PW.visibleAll(pg)==0,'bad arguments show nothing')
 for _,t in ipairs({{1e9,'x',nil},{1e9,0/0,1/5},{1e9,1/0,1/5},{1e9,-5,1/5},{1e9,1,'x'},{1e9,1,0/0},{1e9,1,-1},{1e9,1,1/0},{1e9,{},{}}})do
  for i=#amounts,1,-1 do amounts[i]=nil end
  local good,err=pcall(C.fire,me,1000000000,t[2],t[3])
  PW.seconds(1.6,1/60)
  check(good and sum(amounts)==1000000000 and #amounts>=1 and #amounts<=12,'odd ticks / interval ('..tostring(t[2])..', '..tostring(t[3])..'): '..#amounts..' popups, sum '..sum(amounts))
  settle()
 end
 local stranger=R.new('Player');stranger.Name='NoCharacter'
 check(pcall(C.fire,stranger,100,1,1/5) and pcall(C.fire,me,100,1,1/5,'not a model') and pcall(C.fire,me,100,1,1/5,part),'a player without a character, a string or a part as the character: no error')
 PW.seconds(0.4,1/60)
 check(PW.visibleAll(pg)==0,'... and nothing shows')
 -- a character without a head
 local headless=PW.newPlayer('Headless',{Pos=V3(3,3,3)})
 headless.Character:FindFirstChild('Head'):Destroy()
 C.fire(headless,4200,1,1/5);PW.seconds(0.4,1/60)
 check(PW.visibleAll(pg)==0,'a character without a head shows nothing')
 PW.leave(headless)
 settle()
end

-- 12. our colours, font and bolt: unchanged -------------------------------------------------------------------------------------------------------------
do
 C.fire(me,4200,1,1/5);PW.seconds(0.2,1/60)
 local frames=0;local ok={Bolt=true,Text=true,Stroke=true,Misc=true}
 local function rgb(c,r,g,b)return near(c.R,r/255,1e-9) and near(c.G,g/255,1e-9) and near(c.B,b/255,1e-9)end
 for _,field in ipairs(PW.fields(pg))do for _,fr in ipairs(PW.frameList(field))do
  frames+=1
  local icon,amt=fr.Lightning,fr.Amount
  if not(icon.Text=='\u{26A1}' and rgb(icon.TextColor3,255,222,66))then ok.Bolt=false end
  if not rgb(amt.TextColor3,125,248,255)then ok.Text=false end
  for _,label in ipairs({icon,amt})do
   local st=label.BoldOutline86
   if not(rgb(st.Color,17,26,42) and st.Thickness==Style.StrokeThickness and st.ApplyStrokeMode.Name=='Contextual' and rgb(label.TextStrokeColor3,0,0,0) and label.TextStrokeTransparency<=1 and label.Font.Name=='FredokaOne')then ok.Stroke=false end
  end
  if not(icon.TextSize==Style.Size.Icon and amt.TextSize==Style.Size.Text and icon.BackgroundTransparency==1 and amt.BackgroundTransparency==1 and (amt.Text==''or amt.Text:sub(1,1)=='+'))then ok.Misc=false end
 end end
 check(frames>=poolSize,'colour check ran over '..frames..' pooled frames')
 check(ok.Bolt,'the bolt is still the yellow (255,222,66) ⚡')
 check(ok.Text,'the amount is still (125,248,255), the pale cyan the owner calls white')
 check(ok.Stroke,'the outlines are still navy (17,26,42) (R153: 5 px on the 2x text), the legacy stroke black, FredokaOne, Contextual')
 check(ok.Misc and Style.Size.Icon==40 and Style.Size.Text==44,'R153: the sizes are 2x the approved 20 / 22 (40 / 44), no background')
 local lf=PW.visible(PW.fieldOf(pg,head(me)))[1]
 if lf then
  check(lf.Amount.AutomaticSize.Name=='X' and lf.Amount.TextXAlignment.Name=='Center','the number sizes itself and sits next to the bolt')
  local layout=lf:FindFirstChildOfClass('UIListLayout')
  check(layout~=nil and layout.HorizontalAlignment.Name=='Center' and layout.VerticalAlignment.Name=='Center' and layout.FillDirection.Name=='Horizontal','the bolt and the number are laid out together, centred')
 end
 settle()
end

-- 13. the belt arrows (V134 block of the same script) still work -----------------------------------------------------------------------------------------------
do
 local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
 local bases=R.new('Folder');bases.Name='Bases';bases.Parent=map
 local base=R.new('Model');base.Name='Base1';base.Parent=bases
 local belt=R.new('Part');belt.Name='Treadmill';belt.Position=V3(0,0,0);belt.Parent=base;belt:SetAttribute('TreadmillTrainingBelt',true)
 local art=R.new('Folder');art.Name='TreadmillArtV131';art.Parent=base;art:SetAttribute('TreadmillTrackVersion',133)
 local arrow=R.new('Part');arrow.Name='Arrow';arrow.Parent=art
 arrow:SetAttribute('TrackMotion',true);arrow:SetAttribute('TrackRest',R.CFrame.new(0,1,0));arrow:SetAttribute('TrackPhase',0.25);arrow:SetAttribute('TrackRate',1);arrow:SetAttribute('TrackTravel',10.8);arrow:SetAttribute('TrackAlpha',0.5)
 local moved,lastParts=0,nil
 W.workspace.BulkMoveTo=function(_,parts,frames)moved+=1;lastParts=parts end
 PW.seconds(2.5,1/60)
 check(moved>0 and lastParts and lastParts[1]==arrow,'belt arrows: the track part is moved every other frame ('..moved..' moves)')
 check(PW.live(Run.Heartbeat)==1,'belt arrows: still one Heartbeat listener')
 local stops=PW.stops
 me:SetAttribute('TreadmillTraining',true)
 W.UIS.JumpRequest:Fire()
 check(PW.stops==stops+1,'belt arrows: a jump while training asks the server to stop')
 W.UIS.JumpRequest:Fire();check(PW.stops==stops+1,'belt arrows: a second jump within 0.2 s is ignored')
 PW.seconds(0.3,1/60);W.UIS.JumpRequest:Fire();check(PW.stops==stops+2,'belt arrows: and one after 0.2 s is accepted')
 me:SetAttribute('TreadmillTraining',nil);PW.seconds(0.3,1/60);W.UIS.JumpRequest:Fire();check(PW.stops==stops+2,'belt arrows: not training: no stop request')
 me:SetAttribute('TreadmillTraining',true)
end

-- 14. no leak, no churn: 10,000 awards for two players --------------------------------------------------------------------------------------------------------
do
 -- warm up: the pools are built (own + other, full caps)
 PW.Tier=3
 for f=0,299 do if f%12==0 then C.fire(me,4200,1,1/5);C.fire(other,4200,1,1/5)end;PW.frames(1,1/60)end
 settle()
 local created1,destroyed1,tweens1,scheduled1=#R.created,PW.destroyed,PW.tweens,PW.scheduled
 collectgarbage();collectgarbage()
 local mem1=collectgarbage('count');local mem2
 local seenFrames={};local maxOwn,maxOther,maxRender=0,0,0
 local N=10000
 for award=1,N do
  C.fire(me,4200,1,1/5);C.fire(other,4200,1,1/5)
  for i=#amounts,1,-1 do amounts[i]=nil end -- (the test's own record)
  for f=1,12 do
   PW.frames(1,1/60)
   maxRender=math.max(maxRender,PW.live(Run.RenderStepped))
  end
  if award%500==0 then
   maxOwn=math.max(maxOwn,#PW.visible(PW.fieldOf(pg,head(me))));maxOther=math.max(maxOther,#PW.visible(PW.fieldOf(pg,head(other))))
  end
  if award==2000 then collectgarbage();collectgarbage();mem2=collectgarbage('count')end
 end
 collectgarbage();collectgarbage()
 local mem3=collectgarbage('count')
 check(#R.created==created1,'10,000 awards: not one Instance created ('..(#R.created-created1)..')')
 check(PW.destroyed==destroyed1,'10,000 awards: not one Instance destroyed ('..(PW.destroyed-destroyed1)..')')
 check(PW.tweens==0 and PW.tweens==tweens1,'no TweenService tween, ever ('..PW.tweens..')')
 check(PW.scheduled==0 and PW.scheduled==scheduled1,'no task.delay / defer / spawn, ever ('..PW.scheduled..')')
 check(maxRender==1,'one updater for everybody: never more than 1 RenderStepped listener ('..maxRender..')')
 check(PW.live(Run.Heartbeat)==1,'... and no popup Heartbeat listener (1 = the belt arrows)')
 check(maxOwn<=Style.Cap(3,true,false)+Style.Field.Spare and maxOther<=Style.Cap(3,false,false)+Style.Field.Spare,'caps held for 10,000 awards (own '..maxOwn..', other '..maxOther..')')
 check(mem3-mem2<150,'memory after 10,000 awards is flat: +'..string.format('%.0f',mem3-mem2)..' KB since award 2,000 ('..string.format('%.0f',mem2)..' -> '..string.format('%.0f',mem3)..')')
 local meField=PW.fieldOf(pg,head(me));local otherField=PW.fieldOf(pg,head(other))
 check(meField and otherField and maxFrames(meField)<=poolSize and maxFrames(otherField)<=poolSize,'the pools stay at '..maxFrames(meField)..' / '..maxFrames(otherField)..' frames (at most '..poolSize..')')
 settle()
 check(PW.visibleAll(pg)==0 and PW.enabledFields(pg)==0 and PW.live(Run.RenderStepped)==0,'afterwards: everything hidden, every field parked, the updater off')
 check(#PW.fields(pg)<=Style.Field.FreeFields+1,'fields kept: '..#PW.fields(pg)..' (<= '..(Style.Field.FreeFields)..' idle ones)')
 -- start / stop 200 times: still no churn
 local c2,d2=#R.created,PW.destroyed
 for i=1,200 do C.fire(me,4200,1,1/5);PW.seconds(0.9,1/30)end
 check(#R.created==c2 and PW.destroyed==d2,'200 runs started and stopped: no Instance built or destroyed')
 check(PW.live(Run.RenderStepped)==0,'... and the updater is off again')
end

print(string.format('test_speed_popups_client: %d checks, %d failed',checks,fails))
if fails>0 then error('test_speed_popups_client failed',0)end
