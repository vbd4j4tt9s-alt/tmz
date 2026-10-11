--!nocheck
-- R158 preview data (not a test): the speed popups of the REAL client on several screens and camera distances, as the client's own tree has them after a 2 s stream of "+60" popups (10 a second at
-- 60 fps), plus the screen's HUD boxes of the real HudLayout. Run on the build this round started from ("before": 35 px text) and on this checkout ("after": 53 px text on a computer, a little
-- less on a small phone); both consume the random numbers the same way, so the fans are the same shape.
-- Prints "SHOT {...}" once per scenario for compose_popups158.py.
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local C=PW.boot({})
local Style,me,pg=C.Style,C.Me,C.PG
local Hud=W.module('HudLayout')
local camera=W.workspace.CurrentCamera
local function head(p)return p.Character:FindFirstChild('Head')end
local function controls(w,h)
 if math.min(w,h)<=500 then return{Joystick={X=20,Y=h-110,W=90,H=90},Jump={X=w-95,Y=h-90,W=70,H=70}}end
 return{Joystick={X=60,Y=h-180,W=120,H=120},Jump={X=w-170,Y=h-210,W=120,H=120}}
end
-- name, width, height, camera distance in studs, touch screen
local scenarios={
 {'pc',1920,1080,12.5,false},{'pc_far',1920,1080,25,false},{'pc_near',1920,1080,4,false},
 {'land',844,390,12.5,true},{'land_big',932,430,12.5,true},{'small',568,320,12.5,true},
 {'port',390,844,12.5,true},{'port_se',375,667,12.5,true},
}
for _,sc in ipairs(scenarios)do
 local name,w,h,d,touch=sc[1],sc[2],sc[3],sc[4],sc[5]
 camera.ViewportSize=R.Vector2.new(w,h);PW.camera(d)
 for f=0,119 do
  if f%12==0 then C.fire(me,120,1,1/5)end
  PW.frames(1,1/60)
 end
 local field=PW.fieldOf(pg,head(me))
 local zoom=field:FindFirstChild('Zoom')
 local zs,zv=1,true
 if zoom then zs=zoom:FindFirstChildOfClass('UIScale').Scale;zv=zoom.Visible end
 local pops={}
 for _,fr in ipairs(PW.visible(field))do
  local r=PW.read(fr)
  pops[#pops+1]=string.format('{"x":%.2f,"y":%.2f,"s":%.4f,"a":%.4f,"z":%d,"text":"%s","ir":%.1f,"tr":%.1f}',r.X,r.Y,r.Scale,r.Alpha,r.ZIndex,r.Text,r.IconRot,r.TextRot)
 end
 local m=Hud.Read({X=w,Y=h},touch,touch and controls(w,h)or nil)
 local boxes={}
 for _,b in ipairs(Hud.HudBoxes(m,w,h,false))do boxes[#boxes+1]=string.format('{"n":"%s","x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f}',b.N,b.X,b.Y,b.W,b.H)end
 local layout=Style.Layout and{Style.Layout(w,h)}or{Style.Unit(h),Style.FanScale(w,h)}
 print(string.format('SHOT {"name":"%s","w":%d,"h":%d,"d":%.2f,"zs":%.4f,"shown":%s,"unit":%.4f,"text":%d,"icon":%d,"stroke":%s,"box":[%d,%d],"fan":[%.3f,%.3f],"head":[%.1f,%.1f],"hud":[%s],"pops":[%s]}',
  name,w,h,d,zs,tostring(zv),layout[1],Style.Size.Text,Style.Size.Icon,tostring(Style.StrokeThickness),Style.Size.Box[1],Style.Size.Box[2],layout[2],layout[3],w/2,h*Style.Fan.HeadY,table.concat(boxes,','),table.concat(pops,',')))
 PW.seconds(1.7)
end
