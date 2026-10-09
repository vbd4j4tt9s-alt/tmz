--!nocheck
-- R153 (owner, in Studio, about the treadmill speed-gain popups: "numbers should also be bigger", then "2x bigger"): the popups' size, motion and screens against the R152
-- SpeedPopupStyle (ref_style.luau, the module as it was: the R151 look) on the Roblox mock with the REAL SpeedPopupStyle and HudLayout of this checkout.
--  1. size      R154 (owner: "reduce the size of the speed notifier number by 20%"): text 35, bolt 32, box 240 x 58, bolt box 38, gap 3, outline 4: 0.8 of R153's 44 / 40 / 300 x 72 / 48 / 4 / 5, so 1.6x the
--               reference (to whole pixels); the pooled field holds the biggest fan
--  2. unchanged the pop, fling, hold, fade and life numbers; the curves (Pose of the same plans at 200 ages, retired and Reduced Motion too); the plans; the cadence (10 a second:
--               SplitTo, Shares, Spacing, SplitFor, Split); the caps per tier; Unit; the colours, font, bolt and the 1K / 1M formatting
--  3. screens   FanScale: Base (R154: 1.6) x Base where there is room (the same fan as R151 at the popups' size, so they pile up exactly as much); where a direction has none (a landscape
--               phone above the head, a portrait phone at the sides) it takes what fits and the other direction more. On 12 phone and 5 computer screens the biggest popup
--               (a 7 character "+999.5K") stays inside the screen with the head where Roblox's camera puts it (HeadY of the way down) and clear of every HUD box (HudLayout.Read)
--  4. pile-up   the mean share of a popup that other living popups cover (10 popups a second) is at most 1.25x R151's (~46%) on a computer or a phone with room (the fan is as wide as
--               the room allows), 2x on the tightest screens (568 x 320, 667 x 375, portrait phones)
local W=require('./world');local R=W.R
local Ref=require('./ref_style');local Style=W.module('SpeedPopupStyle');local Hud=W.module('HudLayout')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-9)end
-- 1. size -------------------------------------------------------------------------------------------------------------------------------------------------
local sz,rz=Style.Size,Ref.Size
local function r16(v)return math.floor(v*1.6+.5)end -- (R154: 1.6x the R151 size, to whole pixels)
check(sz.Text==r16(rz.Text)and sz.Icon==r16(rz.Icon)and sz.IconBox==r16(rz.IconBox)and sz.Gap==r16(rz.Gap)and sz.Box[1]==r16(rz.Box[1])and sz.Box[2]==r16(rz.Box[2]),'text '..sz.Text..', bolt '..sz.Icon..', bolt box '..sz.IconBox..', gap '..sz.Gap..', box '..sz.Box[1]..' x '..sz.Box[2]..': every size is 1.6x the R151 one (0.8 of R153\'s 2x)')
check(sz.Text==35 and sz.Icon==32 and Style.StrokeThickness==4 and Ref.StrokeThickness==2.5 and math.abs(Style.StrokeThickness-Ref.StrokeThickness*1.6)<=.5,'35 / 32 px, a 4 px outline (R153: 44 / 40 / 5; R151: 22 / 20 / 2.5)')
check(sz.IconTilt==rz.IconTilt and sz.TextTilt==rz.TextTilt,'the random tilts are the same degrees')
-- 2. unchanged -------------------------------------------------------------------------------------------------------------------------------------------
local function same(a,b)
 if type(a)~=type(b)then return false end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not same(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
check(same(Style.Pop,Ref.Pop)and same(Style.Fling,Ref.Fling)and same(Style.Fade,Ref.Fade)and Style.Life==Ref.Life and same(Style.Reduced,Ref.Reduced)and same(Style.Spawn,Ref.Spawn)and Style.RetireFade==Ref.RetireFade,'the pop (.45 -> 1, back 2), the fling (.4 s, cubic, +-75 degrees, 44..104 px, 7 slots), the fade (.5 + .15 s), the life (.65 s), Reduced Motion and the spawn are the numbers they were')
local capsOk=same(Style.Cadence,Ref.Cadence)and same(Style.ReducedCaps,Ref.ReducedCaps)and Style.MaxDistance==Ref.MaxDistance
for tier=1,3 do capsOk=capsOk and Style.Caps[tier].Others==Ref.Caps[tier].Others and Style.Caps[tier].Own==8 end
check(capsOk,'the cadence (10 a second: SplitTo 2, 1/5 s ticks), the others\' caps (3 / 2 / 1) and Reduced Motion\'s are as they were; R154: own popups hold 8 at every tier (R151: 8 / 6 / 4, below the 7 the stream keeps alive)')
check(same(Style.Colors,Ref.Colors)and Style.Font==Ref.Font and Style.Icon==Ref.Icon,'our colours (125,248,255 / 17,26,42 / 255,222,66), FredokaOne and the bolt are as they were')
local seed=7;local function rng()seed=(seed*16807)%2147483647;return seed/2147483647 end
local seed2=7;local function rng2()seed2=(seed2*16807)%2147483647;return seed2/2147483647 end
local bag,bag2={},{};local worst=0;local n=0
for i=1,300 do
 local p,q=Style.Plan(rng,bag),Ref.Plan(rng2,bag2)
 for _,k in ipairs({'Angle','Radius','StartX','StartY','ReducedX','IconTilt','TextTilt'})do if not near(p[k],q[k])then worst+=1 end end
 for age=0,.7,.0035 do
  for _,mode in ipairs({{false},{true},{false,.3}})do
   local a={Style.Pose(p,age,mode[1],mode[2])};local b={Ref.Pose(q,age,mode[1],mode[2])}
   n+=1;for j=1,5 do if a[j]~=b[j]then worst+=1 end end
  end
 end
end
check(worst==0,'the plans and the curves are identical: '..n..' poses of 300 plans (flying, Reduced Motion, retired) equal the R151 ones')
local cad=true
for _,amount in ipairs({1,2,7,4200,72000,1e9})do for ticks=1,10 do for _,split in ipairs({1,2,3})do
 if Style.Shares(amount,ticks,split)~=Ref.Shares(amount,ticks,split)then cad=false end
 local a,b=Style.Split(amount,split),Ref.Split(amount,split);for i=1,math.max(#a,#b)do if a[i]~=b[i]then cad=false end end
 if Style.Spacing(1/5,split,Style.Shares(amount,ticks,split))~=Ref.Spacing(1/5,split,Ref.Shares(amount,ticks,split))then cad=false end
end end end
for _,own in ipairs({true,false})do for _,red in ipairs({true,false})do if Style.SplitFor(own,red)~=Ref.SplitFor(own,red)then cad=false end end end
for tier=1,3 do for _,own in ipairs({true,false})do
 if(not own)and Style.Cap(tier,own,false)~=Ref.Cap(tier,own,false)then cad=false end -- (R154: the own cap is 8 at every tier)
 if Style.Cap(tier,own,true)~=Ref.Cap(tier,own,true)then cad=false end
end end
for _,h in ipairs({200,390,720,1080,1500,2160})do if Style.Unit(h)~=Ref.Unit(h)then cad=false end end
for _,v in ipairs({0,.4,1,999,999.6,1000,1234,3500,12000,999950,1.5e6,999950000,4.2e12})do if Style.FormatGain(v)~=Ref.FormatGain(v)then cad=false end end
check(cad and Style.SplitFor(true,false)==2,'the rate (2 popups per 1/5 s tick = 10 a second), Split / Shares / Spacing, the others\' caps, Unit and the 1K / 1M formatting are identical to R151')
-- 3. screens ---------------------------------------------------------------------------------------------------------------------------------------------
local fx,fy=Style.FanScale(1920,1080)
local base=Style.Fan.Base
check(base==1.6 and fx==base and fy==base,'1920 x 1080: the fan is '..base..' x '..base..' (the R151 fan at the popups\' 1.6x size)')
check(select(1,Style.FanScale(nil,nil))==base and select(2,Style.FanScale(nil,nil))==base,'an unknown screen reads as a desktop ('..base..' x '..base..')')
local lx,ly=Style.FanScale(844,390)
check(lx>base and ly<base and ly>=base/2 and lx<=Style.Fan.Max,string.format('a landscape phone (844 x 390) has no room above the head: the fan is %.2f wide, %.2f tall',lx,ly))
local px,py=Style.FanScale(390,844)
check(px<base and px>=base/2 and py>base*.99 and py<=Style.Fan.Max,string.format('a portrait phone (390 x 844) has no room at the sides: the fan is %.2f wide, %.2f tall',px,py))
for _,v in ipairs({{844,390},{390,844},{360,640},{932,430},{1920,1080},{2560,1440},{3840,2160}})do
 local x,y=Style.FanScale(v[1],v[2]);check(x>=Style.Fan.Min and x<=Style.Fan.Max and y>=Style.Fan.Min and y<=Style.Fan.Max,'the fan stays within '..Style.Fan.Min..'..'..Style.Fan.Max..' at '..v[1]..' x '..v[2]..' ('..string.format('%.2f x %.2f',x,y)..')')
end
check(near(select(1,Style.FanScale(0/0,0/0)),base)and near(select(2,Style.FanScale('x',math.huge)),base),'bad numbers read as a desktop')
local function controls(w,h)
 if math.min(w,h)<=500 then return{Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return{Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
-- all popups of one stream on a screen: the rectangle of each (a 7 character "+999.5K") at rest and at the pop's peak, relative to the head
local function footprints(w,h,count,S)
 S=S or Style
 local u=S.Unit(h);local x,y=1,1;if S==Style then x,y=Style.FanScale(w,h)end
 local zz=S.Size;local halfW=(zz.IconBox+zz.Gap+7*zz.Text*.55)/2*u;local halfH=zz.Text*.6*u
 local s=11;local function r()s=(s*16807)%2147483647;return s/2147483647 end
 local bg={};local out={}
 for _=1,count do
  local plan=S.Plan(r,bg)
  for _,age in ipairs({.16,.4,.55})do
   local px,py,sc=S.Pose(plan,age,false)
   out[#out+1]={X=px*u*x,Y=py*u*y,HW=halfW*sc,HH=halfH*sc}
  end
 end
 return out
end
local function inter(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
local screens={{1920,1080,false},{1366,768,false},{1280,720,false},{1024,768,false},{800,600,false}}
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{320,568},{375,667},{390,844},{430,932},{360,740}})do screens[#screens+1]={v[1],v[2],true}end
local rows={}
for _,sc in ipairs(screens)do
 local w,h,touch=sc[1],sc[2],sc[3]
 local hx,hy=w/2,h*Style.Fan.HeadY
 local fp=footprints(w,h,400)
 local off,hudHits,softHits,total=0,0,0,0;local hudNames,softNames={}, {}
 local refSoft,refTotal=0,0
 for _,ctl in ipairs(touch and{false,true}or{false})do
  local m=Hud.Read({X=w,Y=h},touch,ctl and controls(w,h)or nil)
  local boxes=Hud.HudBoxes(m,w,h,false)
  for _,f in ipairs(fp)do
   local rect={X=hx+f.X-f.HW,Y=hy+f.Y-f.HH,W=f.HW*2,H=f.HH*2}
   if rect.X<0 or rect.Y<0 or rect.X+rect.W>w or rect.Y+rect.H>h then off+=1 end
   local soft=false
   -- (R157: the owner-approved five-option menu wheel moves the MENU button up on the small phones - 568 x 320, 375 x 667, 320 x 568 - to fit DAILY / INVITE above the
   -- bars, into the popups' fan around the head. The popups are a world-space BillboardGui, which Roblox draws under every ScreenGui: they pass BEHIND the MENU button,
   -- which stays whole and pressable. A moved-up MENU button counts as an info row there; where it sits as before - the middle of the left edge - it stays a control.)
   local movedHub=(m.MenuShiftY or 0)<0
   for _,b in ipairs(boxes)do if b.N~='OwnerTools'and inter(rect,b)then
    if b.N=='Status'or b.N:sub(1,6)=='Wallet'or(b.N=='Hub'and movedHub)then soft=true;softNames[b.N]=true else hudHits+=1;hudNames[b.N]=true end
   end end
   if soft then softHits+=1 end
   total+=1
   -- (the same count for the R151 popups: 1x text, 1x fan)
  end
  for _,f in ipairs(footprints(w,h,400,Ref))do
   local rect={X=hx+f.X-f.HW,Y=hy+f.Y-f.HH,W=f.HW*2,H=f.HH*2};local soft=false
   for _,b in ipairs(boxes)do if(b.N=='Status'or b.N:sub(1,6)=='Wallet')and inter(rect,b)then soft=true end end
   if soft then refSoft+=1 end;refTotal+=1
  end
 end
 local names={};for k in pairs(hudNames)do names[#names+1]=k end
 check(off==0,w..' x '..h..': every popup stays inside the screen ('..off..' of '..#fp..' rectangles outside)')
 -- the controls (the menu button, the hotbar, the jump button / thumb zones) are never covered; the info rows (the balances, the status stack) at most at the fan's far tips
 check(hudHits==0,w..' x '..h..': no popup lies over the menu, the hotbar or the controls ('..hudHits..' hits'..(#names>0 and(': '..table.concat(names,', '))or'')..')')
 local portrait=h>w and w<=500
 local share=softHits/math.max(1,total)
 -- (a portrait phone has no room for both: the balances stack sits in the upper right of the fan, 70 - 210 px down, so the right tips of the fan pass behind it - the popups are
 -- drawn under the HUD - and the status box above stays clear. Landscape phones and computers: at most the very tip.)
 local refShare=refSoft/math.max(1,refTotal)
 check(share<=(portrait and 1.0 or .05),string.format('%d x %d: %.1f%% of the popups touch the balances / status rows (R151: %.1f%%; at most %d%%)',w,h,share*100,refShare*100,portrait and 80 or 5))
 local gx,gy=Style.FanScale(w,h);rows[#rows+1]=string.format('%4d x %-4d fan %.2f x %.2f, %.1f%% of the popups touch a balance / status row (R151: %.1f%%)',w,h,gx,gy,share*100,refShare*100)
end
-- 4. pile-up --------------------------------------------------------------------------------------------------------------------------------------------------
-- popups every .1 s alive .65 s; a box is the bolt + the text of `chars` characters (.55 em each) x 1.2 em; the share of each box covered by the others, averaged
local function pileUp(S,w,h,chars,fanX,fanY)
 local u=S.Unit(h);local s=5;local function r()s=(s*16807)%2147483647;return s/2147483647 end
 local bag={};local plans={}
 for i=1,1500 do local p=S.Plan(r,bag,{});plans[i]={Angle=p.Angle,Radius=p.Radius,StartX=p.StartX,StartY=p.StartY} end
 local bw=(S.Size.IconBox+S.Size.Gap+chars*S.Size.Text*.55);local bh=S.Size.Text*1.2
 local total,count=0,0
 for i=20,1500 do
  local now=i*.1;local boxes={}
  for j=math.max(1,i-7),i do
   local age=now-j*.1
   if age>=0 and age<S.Life then local x,y,sc=S.Pose(plans[j],age,false);boxes[#boxes+1]={x=x*u*fanX,y=y*u*fanY,w=bw*sc*u,h=bh*sc*u}end
  end
  for p=1,#boxes do
   local a=boxes[p];local covered=0
   for q=1,#boxes do if q~=p then
    local b=boxes[q]
    local ox=math.max(0,math.min(a.x+a.w/2,b.x+b.w/2)-math.max(a.x-a.w/2,b.x-b.w/2))
    local oy=math.max(0,math.min(a.y+a.h/2,b.y+b.h/2)-math.max(a.y-a.h/2,b.y-b.h/2))
    covered+=ox*oy
   end end
   total+=math.min(1,covered/(a.w*a.h));count+=1
  end
 end
 return total/count
end
local worstRatio,worstAt=0,''
for _,sc in ipairs(screens)do
 local w,h=sc[1],sc[2];local x,y=Style.FanScale(w,h)
 for _,chars in ipairs({5,7})do
  local before=pileUp(Ref,w,h,chars,1,1);local after=pileUp(Style,w,h,chars,x,y)
  if after/before>worstRatio then worstRatio,worstAt=after/before,string.format('%d x %d, %d characters: %.2f vs %.2f',w,h,chars,after,before)end
  -- (a 2x popup on a screen with no room for a 2x fan - a 568 x 320 phone, a portrait phone's 90 px under the balances - cannot pile up as little as a 1x one: up to 2x R151's)
  local tight=w<740 or(h>w and w<=500)
  if chars==5 then rows.pile=rows.pile or{};rows.pile[w..'x'..h]={after,before}end
  check(after<=before*(tight and 2 or 1.25),string.format('%d x %d, "+%s": the popups cover %.0f%% of each other (R151: %.0f%%; allowed %.2fx%s)',w,h,chars==5 and'72.5K'or'999.5K',after*100,before*100,tight and 2 or 1.25,tight and', a tight screen'or''))
 end
end
-- the pooled field holds the biggest fan: the widest "+999.5K" at the biggest Unit, X and Y at their biggest, the pop's overshoot
do
 local u=Style.Unit(2160);local x,y=Style.FanScale(3840,2160)
 local halfW=(sz.IconBox+sz.Gap+7*sz.Text*.55)/2*u*1.07;local halfH=sz.Text*.6*u*1.07
 local reachX=(Style.Spawn.Jitter+math.sin(math.rad(Style.Fling.HalfAngle))*Style.Fling.Radius[2])*u*x+halfW
 local reachY=(Style.Spawn.Lift+Style.Fling.Radius[2])*u*y+halfH
 check(reachX*2<=Style.Field.Width and reachY*2<=Style.Field.Height,string.format('the field (%d x %d) holds the biggest fan on a 4K screen (%.0f x %.0f)',Style.Field.Width,Style.Field.Height,reachX*2,reachY*2))
 local mx,my=0,0
 for _,v in ipairs(screens)do local fx2,fy2=Style.FanScale(v[1],v[2]);local u2=Style.Unit(v[2])
  mx=math.max(mx,((Style.Spawn.Jitter+math.sin(math.rad(Style.Fling.HalfAngle))*Style.Fling.Radius[2])*fx2+(sz.IconBox+sz.Gap+7*sz.Text*.55)/2*1.07)*u2)
  my=math.max(my,((Style.Spawn.Lift+Style.Fling.Radius[2])*fy2+sz.Text*.6*1.07)*u2)
 end
 check(mx*2<=Style.Field.Width and my*2<=Style.Field.Height,string.format('... and on every screen above (%.0f x %.0f)',mx*2,my*2))
end
print(string.format('popups: worst pile-up vs R151 %.2f (%s)',worstRatio,worstAt))
for _,r in ipairs(rows)do print('  '..r)end
for _,sc in ipairs(screens)do local pr=rows.pile and rows.pile[sc[1]..'x'..sc[2]];if pr then print(string.format('  pile-up %4d x %-4d: %.0f%% of a "+72.5K" covered (R151 %.0f%%)',sc[1],sc[2],pr[1]*100,pr[2]*100))end end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
