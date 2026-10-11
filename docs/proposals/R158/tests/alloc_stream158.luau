--!nocheck
-- R158: heap growth of the REAL speed popup client over a stream, to compare two builds (run_popups158.sh runs it for the client + style this round started from and for this checkout's, and wants the
-- new one to cost no more): a 1080 p computer and an 844 x 390 phone, 10 popups a second at 60 fps, 900 frames after the pool is warm. A collection first, none in between, so what grows is what the frames allocated.
-- Prints "ALLOC <screen> <KB over 900 frames>".
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local C=PW.boot({})
local camera=W.workspace.CurrentCamera
local ZERO=R.UDim2.fromOffset(0,0)
local newUDim2=R.UDim2.new
local function stream(w,h)
 camera.ViewportSize=R.Vector2.new(w,h)
 for f=0,239 do if f%12==0 then C.fire(C.Me,120,1,1/5)end;PW.frames(1,1/60)end -- (warm: the pool is built, every path has run once)
 PW.seconds(1.7)
 -- (a popup that moves further writes its Position on more frames: every write is one UDim2 the client builds, R154's own code. The 1.5x fan is the reason, not new work, so the UDim2s are taken
 -- out of the count: what is measured is everything else the frames allocate)
 R.UDim2.new=function()return ZERO end
 collectgarbage('collect');collectgarbage('collect')
 local a=collectgarbage('count')
 for f=0,899 do if f%12==0 then C.fire(C.Me,120,1,1/5)end;PW.frames(1,1/60)end
 local b=collectgarbage('count')
 PW.seconds(1.7)
 R.UDim2.new=newUDim2
 print(string.format('ALLOC %dx%d %.1f',w,h,b-a))
end
stream(1920,1080)
stream(844,390)
stream(390,844)
