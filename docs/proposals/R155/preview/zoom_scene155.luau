--!nocheck
-- R155 preview data (not a test): the speed popups of the REAL client at camera distances 12.5 (the default zoom), 25, 50 and 4 studs (close-up), as the client's own tree has them after a
-- 2 s stream of 10 popups a second at 60 fps: every showing popup frame's offset, scale, alpha and text, and the field's zoom container (scale, shown) when the build has one.
-- Run on the R154 build (no container: the popups are the same size at every distance) and on this checkout; both consume the random numbers the same way, so the fans are the same.
-- Prints "ZOOM {...}" once per distance and "CURVE {...}" (this build's S.ZoomScale, when it has one) for compose_zoom155.py.
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local C=PW.boot({})
local Style,me,pg=C.Style,C.Me,C.PG
local function head(p)return p.Character:FindFirstChild('Head')end
local out={}
for _,d in ipairs({12.5,25,50,4})do
 PW.camera(d)
 for f=0,119 do
  if f%12==0 then C.fire(me,144000,1,1/5)end
  PW.frames(1,1/60)
 end
 local field=PW.fieldOf(pg,head(me))
 local zoom=field:FindFirstChild('Zoom')
 local zs,zv=1,true
 if zoom then zs=zoom:FindFirstChildOfClass('UIScale').Scale;zv=zoom.Visible end
 local pops={}
 for _,fr in ipairs(PW.visible(field))do
  local r=PW.read(fr)
  pops[#pops+1]=string.format('{"x":%.2f,"y":%.2f,"s":%.4f,"a":%.4f,"z":%d,"text":"%s"}',r.X,r.Y,r.Scale,r.Alpha,r.ZIndex,r.Text)
 end
 local v=W.workspace.CurrentCamera.ViewportSize
 print(string.format('ZOOM {"d":%.2f,"zs":%.4f,"shown":%s,"unit":%.3f,"text":%d,"icon":%d,"pops":[%s]}',d,zs,tostring(zv),Style.Unit(v.Y),Style.Size.Text,Style.Size.Icon,table.concat(pops,',')))
end
if Style.ZoomScale then
 local pts={}
 for i=0,120 do local d=i*.5;local s,f=Style.ZoomScale(d);pts[#pts+1]=string.format('[%.1f,%.4f,%.4f]',d,s,f)end
 print('CURVE {"text":'..Style.Size.Text..',"pts":['..table.concat(pts,',')..']}')
end
