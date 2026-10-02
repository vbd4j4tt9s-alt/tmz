--!nocheck
-- R123 BONUS ROLL button placement (TreadmillBonusRules.Place) over the 26 screens of tools/tests/hud_overlap_harness,
-- with and without on-screen touch controls: on screen, >=44 px tall, and clear (6 px) of every HudLayout box
-- (menu wheel open, hotbar + details, wallet, timers, thumb zones), the top-bar travel row and the Biome/Run/Feedback
-- notice rows (Banner/Shovel rows are rare, short-lived and not reserved).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local Rules=W.module('TreadmillBonusRules');local L=W.module('HudLayout');local Notice=W.module('HudNoticeLayout')
local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
local function controls(w,h)
 if math.min(w,h)<=500 then return {Joystick={X=20,Y=h-90-20,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return {Joystick={X=60,Y=h-60-120,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local views={}
for _,v in ipairs({{1920,1080},{1366,768},{1280,720},{1024,768},{800,600},{1280,540},{960,480},{700,400}})do views[#views+1]={v[1],v[2],false}end
for _,v in ipairs({{568,320},{667,375},{740,360},{812,375},{844,390},{896,414},{932,430},{800,360},{1024,768},{1180,820},{1366,1024},{320,568},{375,667},{390,844},{430,932},{360,740},{768,1024},{820,1180}})do views[#views+1]={v[1],v[2],true}end
local spots={}
for _,v in ipairs(views)do
 local w,h,touch=v[1],v[2],v[3]
 for _,ctl in ipairs(touch and{false,true}or{false})do
  local m=L.Read({X=w,Y=h},touch,ctl and controls(w,h)or nil)
  local boxes=L.HudBoxes(m,w,h,true)
  local rows=Notice.Calculate(w,h,36,Rules.NoticeFlags);local extra={}
  for name,row in pairs(rows)do if type(row)=='table'then extra[#extra+1]={N=name,X=row.X-row.Width/2,Y=row.Y,W=row.Width,H=row.Height}end end
  local r=Rules.Place(m,w,h,boxes,extra)
  local tag=string.format('%s %dx%d%s',touch and'TOUCH'or'PC',w,h,ctl and' ctl'or'')
  check(r.X>=8 and r.Y>=8 and r.X+r.W<=w-8 and r.Y+r.H<=h-8,tag..' on screen')
  check(r.H>=44 and r.W>=124,tag..' touch-sized')
  for _,b in ipairs(boxes)do check(not ov(r,b,6),tag..' clear of '..b.N)end
  check(not ov(r,{X=w/2-140,Y=0,W=280,H=60},0),tag..' clear of the top-bar travel row')
  for _,b in ipairs(extra)do check(not ov(r,b,0),tag..' clear of notice row '..b.N)end
  spots[#spots+1]=string.format('%-18s button %dx%d at (%d,%d)',tag,r.W,r.H,r.X,r.Y)
 end
end
print(table.concat(spots,'\n'))
print(string.format('%d/%d checks passed%s',checks-fails,checks,fails>0 and(' ('..fails..' FAILED)')or''))
if fails>0 then error('failures',0)end
