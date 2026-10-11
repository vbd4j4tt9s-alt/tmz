--!nocheck
-- R158 (owner: "increase the size of the speed popups as they are too small right now"): the treadmill speed popups are 1.5x bigger (R154's 35 px text -> 53; with the bolt, the box and the outline)
-- on the Roblox mock, with the REAL SpeedPopupStyle, HudLayout and SpeedGainPopup client of this checkout. R154's own numbers are held here as literals (R154) and re-created by setting the style back
-- to them for a moment (asR154: sizes, fan and Fan.Keep = 0, which turns the new size share off), so every comparison "now vs R154" is made by the same code on both sides.
--  1. numbers      the new sizes are 1.5x R154's (to whole pixels, 2.4x R151's), the fan, the pooled field and the outline follow; everything else - the pop, fling, fade, life, Reduced Motion, the caps, the
--                  rate (10 a second, 12 per award event at most), the colours, font and bolt, the zoom's distances (31.25 / 36.46 studs), the zoom cap (1.3x), MaxDistance 100 - is what it was in R154
--  2. size share   S.SizeScale: 1 on a computer / tablet, 2/3 .. 1 on a phone (never smaller than R154's phone size, never bigger than the new default), the same for a bigger screen or a bigger
--                  window, the fan keeps 85% of its area wherever it can, bad numbers read as a computer
--  3. phone rule   the R153 rule at every computer and phone screen, new vs R154: every popup inside the screen, none over the menu / hotbar / controls, at most 5% touching the balance / status rows on
--                  a computer or a landscape phone (portrait: at most what R154 had + 30 points), the pile-up (the share of a popup under others) at most 1.2x R154's
--  4. the face     the head box (1.2 studs at the default 12.5 stud camera, 70 degrees): the share of the popups at rest (after their 0.4 s fling) that touch it is at most R154's + 1 point on any
--                  screen (the fan is 1.5x too, so on a computer it is far lower: 1.2% against 8.8% at 1080 p); while a popup is born the average share of the box under a "+60" is at most 40% and at most
--                  14 points more than R154's (the popups are born at the head, as the approved R151 look has them)
--  5. zoom         the size follows the camera distance (53 x unit x min(1.3, 12.5 / d)), the cutoffs are the R155 distances, MaxDistance is above them, the biggest popup box at the 1.3 cap is at most
--                  17% of a computer screen's height (1.55x R154's) and 24% of a phone's (1.1x R154's), and the pooled field (1500 x 1188) holds the biggest fan at the cap on every screen (4K included)
--  6. cost         SizeScale / FanScale / Layout / ZoomScale allocate nothing (numbers in, numbers out), and the client calls Layout once per popup at its birth (run_popups158.sh checks the call sites)
--  7. real client  the popups of the real client on 7 screens: settled size = 53 x unit x size share, Reduced Motion too, every frame of its life
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
local C=PW.boot({})
local Style,me,pg=C.Style,C.Me,C.PG
local Hud=W.module('HudLayout')
local rows={} -- report lines for the owner's notes (printed at the end)

-- R154, as it was (the numbers of the R154 release 8aa15fd) ---------------------------------------------------------------------------------------------------------------------------------
local R154={
 Size={Text=35,Icon=32,Box={240,58},IconBox=38,Gap=3,IconTilt=14,TextTilt=3},Stroke=4,
 Fan={Base=1.6,Max=2.4,Min=.6,HeadY=.36,Margin=12,PortraitTop=72,HalfWidth=89,HalfHeight=24,Keep=0,MinSize=1},
 Field={Width=1000,Height=792},
}
local function asR154(fn,...)
 local size,fan,stroke,field=Style.Size,Style.Fan,Style.StrokeThickness,Style.Field
 Style.Size,Style.Fan,Style.StrokeThickness=R154.Size,R154.Fan,R154.Stroke
 local ok,a,b,c,d,e,f,g=pcall(fn,...)
 Style.Size,Style.Fan,Style.StrokeThickness=size,fan,stroke
 if not ok then error(a,0)end
 return a,b,c,d,e,f,g
end

-- 1. numbers -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local sz=Style.Size
check(sz.Text==53 and sz.Icon==48 and sz.Box[1]==360 and sz.Box[2]==86 and sz.IconBox==58 and sz.Gap==5 and Style.StrokeThickness==6,'R158: text 53, bolt 48, box 360 x 86, bolt box 58, gap 5, outline 6')
local function ratio(a,b)return a/b end
check(near(ratio(sz.Text,R154.Size.Text),1.5,.02)and near(ratio(sz.Icon,R154.Size.Icon),1.5,.001)and near(ratio(sz.Box[1],R154.Size.Box[1]),1.5,.001)and near(ratio(sz.Box[2],R154.Size.Box[2]),1.5,.02)
 and near(ratio(sz.IconBox,R154.Size.IconBox),1.5,.03)and near(ratio(Style.StrokeThickness,R154.Stroke),1.5,.001),
 string.format('every size is 1.5x R154\'s to the pixel: text %.3f, bolt %.3f, box %.3f x %.3f, bolt box %.3f, outline %.3f',sz.Text/35,sz.Icon/32,sz.Box[1]/240,sz.Box[2]/58,sz.IconBox/38,Style.StrokeThickness/4))
check(sz.IconTilt==14 and sz.TextTilt==3,'(the random tilts are the same degrees)')
local f=Style.Fan
check(f.Base==2.4 and f.Max==3.6 and f.Min==.9 and f.HalfWidth==134 and f.HalfHeight==36 and f.HeadY==.36 and f.Margin==12 and f.PortraitTop==72,'the fan is 1.5x R154\'s: Base 2.4, Max 3.6, Min 0.9, the half popup 134 x 36 (the same head, margin and portrait top)')
check(near(f.Base/R154.Fan.Base,1.5)and near(f.Max/R154.Fan.Max,1.5)and near(f.Min/R154.Fan.Min,1.5)and near(f.HalfWidth/R154.Fan.HalfWidth,1.5,.01)and near(f.HalfHeight/R154.Fan.HalfHeight,1.5,.001),'... so the arrangement and the pile-up on a computer are the same as R154\'s')
check(Style.Field.Width==1500 and Style.Field.Height==1188 and Style.Field.Name=='SpeedGainField' and Style.Field.Spare==2 and Style.Field.FreeFields==4 and Style.Field.MaxFrames==24,'the pooled field is 1500 x 1188 (1.5x R154\'s 1000 x 792); its name and its pool limits are as before')
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
check(same(Style.Pop,{From=.45,Time=.28,Back=2})and same(Style.Fling,{Time=.4,Power=3,HalfAngle=75,Radius={44,104},Slots=7,SlotJitter=9})and same(Style.Fade,{Start=.5,Length=.15})and near(Style.Life,.65)
 and Style.RetireFade==.08 and same(Style.Spawn,{Lift=5,Jitter=6})and same(Style.Reduced,{FadeIn=.08,Rise=72,RiseTime=.7,FadeStart=.45,FadeLength=.25,Life=.7,Side=14}),'the motion and timing are R154\'s: the pop (.45 -> 1 in .28 s), the fling (.4 s, cubic, +-75 degrees, 44..104 px, 7 slots), the fade (.5 + .15 s), Reduced Motion')
check(same(Style.Cadence,{SplitTo=2,MaxShares=12,MaxTicks=10,MinInterval=.1,MaxInterval=1,MaxPending=36})and same(Style.Caps,{[3]={Own=8,Others=3},[2]={Own=8,Others=2},[1]={Own=8,Others=1}})
 and same(Style.ReducedCaps,{Own=4,Others=1})and Style.MaxDistance==100,'the rate (2 popups per 1/5 s tick = 10 a second, at most 12 per award event), the caps (own 8, others 3 / 2 / 1) and MaxDistance 100 are R154\'s')
check(same(Style.Colors,{Text={125,248,255},TextStroke={17,26,42},Icon={255,222,66},LegacyStroke={0,0,0}})and Style.Font=='FredokaOne'and Style.Icon=='\u{26A1}','the colours (125,248,255 / 17,26,42 / 255,222,66), FredokaOne and the bolt are R154\'s')
local z=Style.Zoom
check(z.Distance==12.5 and z.MaxScale==1.3 and z.FadeScale==.4 and near(z.HideScale,12/35,1e-12)and z.Epsilon==.004,'the zoom rule is R155\'s: 12.5 studs, 1.3x cap, fade from scale 0.4, gone at 12/35, epsilon 0.004')
do
 local sf,ff=Style.ZoomScale(12.5/.4);local sh,fh=Style.ZoomScale(12.5*35/12);local s1,f1=Style.ZoomScale(12.5)
 check(near(sf,.4,1e-12)and near(ff,1,1e-9)and near(sh,12/35,1e-12)and fh==0 and s1==1 and f1==1,string.format('the popups still start to fade at 31.25 studs and are gone at 36.46 (R155\'s distances; the text is %.1f px there at 1080 p, R155: 14 / 12)',53*sh))
 local _,fMid=Style.ZoomScale(34);check(fMid>0 and fMid<1,'... and fade linearly in between (34 studs: '..string.format('%.3f',fMid)..')')
 check(12.5*35/12<Style.MaxDistance and Style.MaxDistance==100,'the BillboardGui\'s MaxDistance (100 studs) is far beyond the 36.46 stud cutoff: the zoom, not the engine\'s distance cut, decides')
end

-- 2. the size share ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
local computers={{3840,2160},{2560,1440},{1920,1080},{1366,768},{1280,720},{1024,768},{960,540},{800,600},{768,1024},{820,1180},{600,800},{1000,520},{700,560}}
local allOne=true
for _,v in ipairs(computers)do if Style.SizeScale(v[1],v[2])~=1 then allOne=false;print('  size share '..v[1]..' x '..v[2]..' = '..Style.SizeScale(v[1],v[2]))end end
check(allOne,'a computer or a tablet (every screen from 800 x 600 / 600 x 800 up, 1000 x 520, 700 x 560) shows the full new size: size share exactly 1')
local phones={{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{320,568},{375,667},{390,844},{430,932},{360,740}}
local pins={['568x320']=.68,['667x375']=.80,['740x360']=.80,['844x390']=.87,['932x430']=.97,['320x568']=.67,['375x667']=.67,['390x844']=.76,['430x932']=.79}
local inRange,pinned=true,true
for _,v in ipairs(phones)do
 local k=Style.SizeScale(v[1],v[2])
 if k<2/3-1e-12 or k>1 then inRange=false end
 local pin=pins[v[1]..'x'..v[2]];if pin and not near(k,pin,.01)then pinned=false;print(string.format('  size share %d x %d = %.3f (pinned %.2f)',v[1],v[2],k,pin))end
end
check(inRange,'a phone: the size share is between 2/3 and 1 (never smaller than R154\'s phone popups, never above the new full size)')
check(pinned,'the shares of today\'s phones: 568 x 320 .68, 667 x 375 .80, 740 x 360 .80, 844 x 390 .87, 932 x 430 .97, 320 x 568 .67, 375 x 667 .67, 390 x 844 .76, 430 x 932 .79 (within .01)')
do
 -- never smaller than R154 anywhere (53 x share >= 35 for every share >= 2/3), a bigger screen never gets smaller popups, and where the share is above its floor the fan keeps its area
 local floorOk,mono,areaOk,n,minShare=true,true,true,0,1
 local want=Style.Fan.Keep*Style.Fan.Base*Style.Fan.Base
 local function share(w,h)return Style.SizeScale(w,h)end
 for h=280,1500,20 do for w=280,2400,20 do
  n+=1
  local k=share(w,h);minShare=math.min(minShare,k)
  if sz.Text*k<R154.Size.Text-1e-9 then floorOk=false end
  -- (the popup's px on the screen, Unit x share: a taller portrait screen has a bigger Unit and so a smaller share for the same px; a screen that turns from landscape to portrait gets
  -- the portrait phone's HUD stack to keep clear of, so that step is left out)
  local px=k*Style.Unit(h)
  -- (to within 0.1%: the share is found by a 12 step bisection, 8e-5 fine)
  local tol=px*1e-3
  if share(w+20,h)*Style.Unit(h)<px-tol or((h>w)==(h+20>w)and share(w,h+20)*Style.Unit(h+20)<px-tol)then mono=false;print('  mono',w,h)end
  if k>Style.Fan.MinSize+1e-6 then local x,y=Style.FanScale(w,h);if x*y<want-1e-3 then areaOk=false;if n<3000 then print('  area',w,h,k,x*y,want)end end end
 end end
 check(floorOk and minShare>=2/3-1e-12,string.format('on %d screens from 280 x 280 to 2400 x 1500 the text is never below R154\'s 35 px (smallest share %.3f)',n,minShare))
 check(mono,'a wider or a taller screen never gets smaller popups on the screen (Unit x share only grows with the screen, 20 px steps; a landscape screen that turns portrait is left out)')
 check(areaOk,'wherever the share is above its floor the fan keeps at least 85% of its area (X x Y >= 0.85 x 2.4 x 2.4)')
 check(Style.SizeScale(nil,nil)==1 and Style.SizeScale(0/0,0/0)==1 and Style.SizeScale('x',math.huge)==1 and Style.SizeScale(-5,-5)>=2/3,'bad numbers read as a computer (nil, NaN, a string, infinity: 1)')
 local u,x,y=Style.Layout(844,390);local u2=Style.Unit(390)*Style.SizeScale(844,390);local fx,fy=Style.FanScale(844,390)
 check(near(u,u2)and near(x,fx)and near(y,fy)and select(1,Style.Layout(nil,nil))==1 and select(2,Style.Layout(nil,nil))==Style.Fan.Base,'Layout(w, h) = the unit (Unit x size share) and the fan of FanScale: one call per popup gives both')
end

-- 3. the phone rule, now vs R154 ----------------------------------------------------------------------------------------------------------------------------------------------------------
local function controls(w,h)
 if math.min(w,h)<=500 then return{Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return{Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local function inter(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local function mkrng(seed)local s=seed;return function()s=(s*16807)%2147483647;return s/2147483647 end end
local function plans(n,seed)
 local r=mkrng(seed);local bag={};local out={}
 for i=1,n do local p=Style.Plan(r,bag,{});out[i]={Angle=p.Angle,Radius=p.Radius,StartX=p.StartX,StartY=p.StartY}end
 return out
end
local PLANS400,PLANS1500,PLANS600=plans(400,11),plans(1500,5),plans(600,5)
-- the rectangles of the biggest popup ("+999.5K") of a stream at the head's place on the screen, at the pop's peak, at rest and just before the fade
local function screenMetrics(w,h,touch)
 local u,fx,fy=Style.Layout(w,h);local Z=Style.Size
 local halfW=(Z.IconBox+Z.Gap+7*Z.Text*.55)/2*u;local halfH=Z.Text*.6*u
 local hx,hy=w/2,h*Style.Fan.HeadY
 local fp={}
 for _,plan in ipairs(PLANS400)do for _,age in ipairs({.16,.4,.55})do
  local px,py,sc=Style.Pose(plan,age,false);fp[#fp+1]={X=px*u*fx,Y=py*u*fy,HW=halfW*sc,HH=halfH*sc}
 end end
 local off,hud,soft,total=0,0,0,0
 for _,ctl in ipairs(touch and{false,true}or{false})do
  local m=Hud.Read({X=w,Y=h},touch,ctl and controls(w,h)or nil);local boxes=Hud.HudBoxes(m,w,h,false);local movedHub=(m.MenuShiftY or 0)<0
  for _,q in ipairs(fp)do
   local rect={X=hx+q.X-q.HW,Y=hy+q.Y-q.HH,W=q.HW*2,H=q.HH*2}
   if rect.X<0 or rect.Y<0 or rect.X+rect.W>w or rect.Y+rect.H>h then off+=1 end
   local s=false
   for _,b in ipairs(boxes)do if b.N~='OwnerTools'and inter(rect,b)then
    if b.N=='Status'or b.N:sub(1,6)=='Wallet'or(b.N=='Hub'and movedHub)then s=true else hud+=1 end
   end end
   if s then soft+=1 end;total+=1
  end
 end
 -- the pile-up of a "+72.5K" and of a "+999.5K": the mean share of each popup that the other living popups cover (10 a second, 0.65 s each)
 local function pile(chars)
  local bw=Z.IconBox+Z.Gap+chars*Z.Text*.55;local bh=Z.Text*1.2;local tot,cnt=0,0
  for i=20,1500 do
   local now=i*.1;local boxes={}
   for j=math.max(1,i-7),i do
    local age=now-j*.1
    if age>=0 and age<Style.Life then local x,y,sc=Style.Pose(PLANS1500[j],age,false);boxes[#boxes+1]={x=x*u*fx,y=y*u*fy,w=bw*sc*u,h=bh*sc*u}end
   end
   for p=1,#boxes do
    local a=boxes[p];local covered=0
    for q=1,#boxes do if q~=p then
     local b=boxes[q]
     covered+=math.max(0,math.min(a.x+a.w/2,b.x+b.w/2)-math.max(a.x-a.w/2,b.x-b.w/2))*math.max(0,math.min(a.y+a.h/2,b.y+b.h/2)-math.max(a.y-a.h/2,b.y-b.h/2))
    end end
    tot+=math.min(1,covered/(a.w*a.h));cnt+=1
   end
  end
  return tot/cnt
 end
 return {u=u,fx=fx,fy=fy,off=off,hud=hud,soft=soft/math.max(1,total),pile5=pile(5),pile7=pile(7),n=#fp*(touch and 2 or 1),textPx=Z.Text*u}
end
-- 4. the face: a head box (1.2 studs, an R15 head) at the default camera (12.5 studs, a 70 degree view): h / 17.5 px per stud. A "+60" is the owner's picture.
local function faceMetrics(w,h)
 local u,fx,fy=Style.Layout(w,h);local Z=Style.Size
 local half=0.6*h/17.5
 local bw=Z.IconBox+Z.Gap+3*Z.Text*.55;local bh=Z.Text*.8
 -- at rest: ages .4 .. .6 (after the 0.4 s fling, before the fade): how many popups touch the head box (the widest "+999.5K" too)
 local restTouch,restN=0,0
 for _,wide in ipairs({3,7})do
  local ww=Z.IconBox+Z.Gap+wide*Z.Text*.55
  for _,plan in ipairs(PLANS600)do for _,age in ipairs({.4,.45,.5,.55,.6})do
   local x,y,sc=Style.Pose(plan,age,false);local cx,cy,hw,hh=x*u*fx,y*u*fy,ww*sc*u/2,bh*sc*u/2
   restN+=1;if math.abs(cx)-hw<half and math.abs(cy)-hh<half then restTouch+=1 end
  end end
 end
 -- while they are born: the share of the head box under the popups of a stream (10 a second), averaged over time (a 10 x 10 grid over the box)
 local N,sum,count,peak=10,0,0,0
 for i=20,600 do
  local now=i*.1+.037*(i%7)/7;local rects={}
  for j=math.max(1,i-7),i do
   local age=now-j*.1
   if age>=0 and age<Style.Life then local x,y,sc=Style.Pose(PLANS600[j],age,false);rects[#rects+1]={x*u*fx,y*u*fy,bw*sc*u/2,bh*sc*u/2}end
  end
  local hit=0
  for gx=0,N-1 do for gy=0,N-1 do
   local px,py=-half+(gx+.5)/N*2*half,-half+(gy+.5)/N*2*half
   for _,q in ipairs(rects)do if math.abs(px-q[1])<=q[3]and math.abs(py-q[2])<=q[4]then hit+=1;break end end
  end end
  local fr=hit/(N*N);sum+=fr;count+=1;if fr>peak then peak=fr end
 end
 return {rest=restTouch,restN=restN,avg=sum/count,peak=peak,half=half}
end
local screens={{1920,1080},{1366,768},{1280,720},{1024,768},{800,600}}
for _,v in ipairs(phones)do screens[#screens+1]={v[1],v[2],true}end
local worstPile,worstPileAt,worstFaceUp,worstFaceAt,worstSoftUp,worstSoftAt=0,'',-1,'',-1,''
for _,sc in ipairs(screens)do
 local w,h,touch=sc[1],sc[2],sc[3]
 local old=asR154(screenMetrics,w,h,touch);local new=screenMetrics(w,h,touch)
 local oldF=asR154(faceMetrics,w,h);local newF=faceMetrics(w,h)
 local tag=w..' x '..h
 check(new.off==0,tag..': every popup stays inside the screen ('..new.off..' of '..new.n..' rectangles outside)')
 check(new.hud==0,tag..': no popup lies over the menu, the hotbar or the controls ('..new.hud..' hits)')
 local portrait=h>w and w<=500
 check(portrait and(new.soft<=1 and new.soft<=old.soft+.30)or(not portrait and new.soft<=.05),string.format('%s: %.1f%% of the popups touch the balances / status rows (R154 %.1f%%; at most %s)',tag,new.soft*100,old.soft*100,portrait and'R154 + 30 points'or'5%'))
 local r5,r7=new.pile5/old.pile5,new.pile7/old.pile7
 check(r5<=1.2 and r7<=1.2,string.format('%s: the popups cover %.0f%% of each other ("+72.5K"; R154 %.0f%%, %.2fx), %.0f%% for "+999.5K" (R154 %.0f%%, %.2fx): at most 1.2x R154',tag,new.pile5*100,old.pile5*100,r5,new.pile7*100,old.pile7*100,r7))
 if r5>worstPile then worstPile,worstPileAt=r5,tag end
 check(newF.rest/newF.restN<=oldF.rest/oldF.restN+.01,string.format('%s: %.1f%% of the popups at rest touch the head box (R154 %.1f%%; at most R154 + 1 point)',tag,newF.rest/newF.restN*100,oldF.rest/oldF.restN*100))
 check(newF.avg<=.40 and newF.avg<=oldF.avg+.14,string.format('%s: while popups are born, %.1f%% of the head box is under a "+60" on average (R154 %.1f%%; at most 40%% and R154 + 14 points), peak %.0f%% (R154 %.0f%%)',tag,newF.avg*100,oldF.avg*100,newF.peak*100,oldF.peak*100))
 if newF.avg-oldF.avg>worstFaceUp then worstFaceUp,worstFaceAt=newF.avg-oldF.avg,tag end
 if new.soft-old.soft>worstSoftUp then worstSoftUp,worstSoftAt=new.soft-old.soft,tag end
 rows[#rows+1]=string.format('%4d x %-4d unit %.3f share %.2f text %4.1f px (R154 %4.1f)  fan %.2f x %.2f (R154 %.2f x %.2f)  pile %2.0f%% (R154 %2.0f%%)  balances %5.1f%% (R154 %5.1f%%)  face %2.0f%% (R154 %2.0f%%)',
  w,h,new.u,Style.SizeScale(w,h),new.textPx,old.textPx,new.fx,new.fy,old.fx,old.fy,new.pile5*100,old.pile5*100,new.soft*100,old.soft*100,newF.avg*100,oldF.avg*100)
 rows[#rows]=rows[#rows]..string.format('  rest-touch %4.1f%% (R154 %4.1f%%)',newF.rest/newF.restN*100,oldF.rest/oldF.restN*100)
end
print(string.format('popups R158: worst pile-up vs R154 %.2fx (%s), face under a newborn popup at most +%.1f points (%s), balances / status touches at most +%.1f points (%s)',worstPile,worstPileAt,worstFaceUp*100,worstFaceAt,worstSoftUp*100,worstSoftAt))

-- 5. the zoom ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local ok,mono=true,true;local prev
 for _,sc in ipairs(screens)do
  local u=select(1,Style.Layout(sc[1],sc[2]))
  for _,d in ipairs({.3,3,6.25,9.6,12.5,18.75,25,31.25,36})do
   local s,fd=Style.ZoomScale(d);local px=sz.Text*u*s
   if not near(s,math.min(1.3,12.5/d),1e-12)then ok=false end
   if d==12.5 and not near(px,sz.Text*u,1e-9)then ok=false end
  end
 end
 check(ok,'the on-screen text is 53 x unit x min(1.3, 12.5 / distance) on every screen (2x the distance: half; closer than 9.6 studs and in first person: 1.3x)')
 -- the biggest popup box (the 360 x 86 frame at the pop's 1.075 peak) on the screen, at the 1.3 cap: a share of the screen height
 local function closeShares()
  local pc,phone,pcAt,phoneAt=0,0,'',''
  for _,sc in ipairs(screens)do
   local u=select(1,Style.Layout(sc[1],sc[2]));local share=Style.Size.Box[2]*u*1.075*Style.Zoom.MaxScale/sc[2]
   if sc[3]then if share>phone then phone,phoneAt=share,sc[1]..' x '..sc[2]end else if share>pc then pc,pcAt=share,sc[1]..' x '..sc[2]end end
  end
  return pc,phone,pcAt,phoneAt
 end
 local worstPc,worstPhone,pcAt,phoneAt=closeShares();local oldPc,oldPhone=asR154(closeShares)
 check(worstPc<=.17 and worstPc<=oldPc*1.55 and worstPhone<=.24 and worstPhone<=oldPhone*1.1,string.format('zoomed right in (the 1.3x cap) the biggest popup frame is %.1f%% of a computer screen\'s height (%s; R154 %.1f%%: at most 17%% and 1.55x that) and %.1f%% of a phone\'s (%s; R154 %.1f%%: at most 24%% and 1.1x that)',worstPc*100,pcAt,oldPc*100,worstPhone*100,phoneAt,oldPhone*100))
 -- the pooled field holds the biggest fan at the 1.3 cap, on every screen and on 4K (the biggest unit), the pop's overshoot included
 local worstX,worstY,wx,wy=0,0,'',''
 local all={{3840,2160},{2560,1440}}
 for _,sc in ipairs(screens)do all[#all+1]=sc end
 for _,sc in ipairs(all)do
  local u,fx,fy=Style.Layout(sc[1],sc[2])
  local halfW=(sz.IconBox+sz.Gap+7*sz.Text*.55)/2*u*1.07;local halfH=sz.Text*.6*u*1.07
  local reachX=((Style.Spawn.Jitter+math.sin(math.rad(Style.Fling.HalfAngle))*Style.Fling.Radius[2])*u*fx+halfW)*2*Style.Zoom.MaxScale
  local reachY=((Style.Spawn.Lift+Style.Fling.Radius[2])*u*fy+halfH)*2*Style.Zoom.MaxScale
  if reachX>worstX then worstX,wx=reachX,sc[1]..' x '..sc[2]end;if reachY>worstY then worstY,wy=reachY,sc[1]..' x '..sc[2]end
 end
 check(worstX<=Style.Field.Width and worstY<=Style.Field.Height,string.format('the pooled field (%d x %d) holds the biggest fan at the 1.3 cap on every screen: widest %.0f (%s), tallest %.0f (%s)',Style.Field.Width,Style.Field.Height,worstX,wx,worstY,wy))
end

-- 6. cost: nothing allocated ----------------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local function grow(fn)
  collectgarbage('collect');local a=collectgarbage('count');for i=1,20000 do fn(i)end;return collectgarbage('count')-a
 end
 local g1=grow(function(i)return Style.SizeScale(300+i%700,300+i%500)end)
 local g2=grow(function(i)return Style.FanScale(300+i%700,300+i%500)end)
 local g3=grow(function(i)return Style.Layout(300+i%700,300+i%500)end)
 local g4=grow(function(i)return Style.ZoomScale(i%100)end)
 check(g1<8 and g2<8 and g3<8 and g4<8,string.format('SizeScale, FanScale, Layout and ZoomScale allocate nothing in 20,000 calls each (heap growth %.2f / %.2f / %.2f / %.2f KB)',g1,g2,g3,g4))
 local t0=os.clock();for i=1,20000 do Style.Layout(300+i%700,300+i%500)end;local per=(os.clock()-t0)/20000*1e6
 print(string.format('popups R158: Layout (the size share by bisection, the fan) costs %.2f microseconds a call, once per popup at its birth (10 a second)',per))
 check(per<60,string.format('... and costs %.2f microseconds a call (at most 60)',per))
end

-- 7. the real client on seven screens ---------------------------------------------------------------------------------------------------------------------------------------------------------
do
 local camera=W.workspace.CurrentCamera
 local function head(p)return p.Character:FindFirstChild('Head')end
 local function settle()PW.seconds(1.7)end
 local function onScreen(w,h,reduced)
  camera.ViewportSize=R.Vector2.new(w,h);W.Gui.ReducedMotionEnabled=reduced==true
  local u=select(1,Style.Layout(w,h));local fx,fy=Style.FanScale(w,h)
  local bad,seen,settled,maxS=0,0,0,0
  for f=0,179 do
   if f%12==0 then C.fire(me,120,1,1/5)end
   PW.frames(1,1/60)
   local field=PW.fieldOf(pg,head(me))
   if field then for _,fr in ipairs(PW.visible(field))do
    local r=PW.read(fr);seen+=1
    local px=fr.Amount.TextSize*r.Scale;maxS=math.max(maxS,r.Scale)
    if fr.Amount.TextSize~=53 or fr.Lightning.TextSize~=48 or fr.Size.X.Offset~=360 or fr.Size.Y.Offset~=86 or fr.Amount.BoldOutline86.Thickness~=6 then bad+=1 end
    if r.Scale>1.075*u+1e-6 or r.Scale<Style.Pop.From*u-1e-6 then bad+=1 end
    if near(r.Scale,u,.0025*u)then settled+=1;if not near(px,53*u,.0025*53*u)then bad+=1 end end
   end end
  end
  settle();W.Gui.ReducedMotionEnabled=false
  return bad,seen,settled,u,fx,fy
 end
 for _,sc in ipairs({{1920,1080},{1280,720},{844,390},{932,430},{568,320},{390,844},{320,568}})do
  for _,red in ipairs({false,true})do
   local bad,seen,settled,u,fx,fy=onScreen(sc[1],sc[2],red)
   check(bad==0 and seen>=50 and settled>=20,string.format('real client, %d x %d%s: %d popup frames, %d settled at 53 px x %.3f = %.1f px text (bolt 48, box 360 x 86, outline 6 as built; scale between the pop\'s .45 and 1.075 of it), fan %.2f x %.2f (%d bad)',
    sc[1],sc[2],red and', Reduced Motion'or'',seen,settled,u,53*u,fx,fy,bad))
  end
 end
 camera.ViewportSize=R.Vector2.new(1920,1080)
end

print('popups R158, per screen (the owner\'s sizes; share = the size share, pile = "+72.5K" covered by others, balances = popups touching the balance / status rows, face = the head box under a "+60" while born, rest-touch = popups at rest touching the head box):')
for _,r in ipairs(rows)do print('  '..r)end
print(('test_popups158: %d checks, %d failed'):format(checks,fails))
if fails>0 then error('test_popups158 failed',0)end
