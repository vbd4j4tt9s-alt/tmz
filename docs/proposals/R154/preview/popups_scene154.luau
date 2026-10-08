--!nocheck
-- R154 preview data (not a test): the treadmill speed popups of the R153 style (ref_style.luau, 2x text 44) and this checkout's (0.8 of that, text 35) on two screens, one frame of the stream
-- (10 a second, 0.65 s each: the ones alive at one moment) with the HUD boxes of HudLayout.Read, and ONE popup at eight ages (its size over its life), as JSON for compose_r154.py.
-- Prints "POPUPS {...}".
local W=require('./world');local R=W.R
local Ref=require('./ref_style');local Style=W.module('SpeedPopupStyle');local Hud=W.module('HudLayout')
local function controls(w,h)
 if math.min(w,h)<=500 then return{Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return{Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
local function frames(S,w,h)
 local u=S.Unit(h);local fx,fy=1,1;if S.FanScale then fx,fy=S.FanScale(w,h)end
 local seed=3;local function rng()seed=(seed*16807)%2147483647;return seed/2147483647 end
 local bag={};local plans={}
 for i=1,40 do local p=S.Plan(rng,bag,{});plans[i]={Angle=p.Angle,Radius=p.Radius,StartX=p.StartX,StartY=p.StartY} end
 local now=3.95;local out={}
 local amounts={'+72K','+72K','+80K','+72K','+72K','+80K','+72K','+72K'}
 for j=39,1,-1 do
  local age=now-j*.1
  if age>=0 and age<S.Life then
   local x,y,sc,a=S.Pose(plans[j],age,false)
   out[#out+1]=string.format('{"x":%.2f,"y":%.2f,"s":%.3f,"a":%.3f,"text":"%s"}',x*u*fx,y*u*fy,sc*u,a,amounts[(j%#amounts)+1])
  end
 end
 return '['..table.concat(out,',')..']',u,fx,fy
end
local views={}
for _,v in ipairs({{1280,720,false},{844,390,true}})do
 local w,h,touch=v[1],v[2],v[3]
 local m=Hud.Read({X=w,Y=h},touch,touch and controls(w,h)or nil)
 local boxes={}
 for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do boxes[#boxes+1]=string.format('{"n":"%s","x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f}',b.N,b.X,b.Y,b.W,b.H)end
 local f1,u1=frames(Ref,w,h);local f2,u2,fx,fy=frames(Style,w,h)
 views[#views+1]=string.format('{"w":%d,"h":%d,"head":[%.1f,%.1f],"hud":[%s],"old":%s,"new":%s,"unit":%.3f,"fan":[%.3f,%.3f],"textOld":%d,"textNew":%d,"iconOld":%d,"iconNew":%d}',
  w,h,w/2,h*Style.Fan.HeadY,table.concat(boxes,','),f1,f2,u2,fx,fy,Ref.Size.Text,Style.Size.Text,Ref.Size.Icon,Style.Size.Icon)
end
-- one popup at eight ages: its scale (the pop) and alpha, R153 and R154 (the same curves: the size is what changed)
local ages={0,.05,.1,.2,.3,.4,.5,.6}
local life={}
for _,age in ipairs(ages)do
 local _,_,sc,a=Style.Pose({Angle=0,Radius=0,StartX=0,StartY=0},age,false)
 life[#life+1]=string.format('{"age":%.2f,"s":%.3f,"a":%.3f}',age,sc,a)
end
print('POPUPS {"views":['..table.concat(views,',')..'],"life":['..table.concat(life,',')..']}')
