--!nocheck
-- R152 performance patch: the speed popups over a treadmill runner, frame by frame. The REAL SpeedGainPopup client (R151 speed_popups_world.luau) at
-- TIER: awards to the local player (small, thousands, split over ticks) and to another player near by. Every frame is a stream frame (perf152_fp.luau)
-- of the PlayerGui and both characters.
local PW=require('./speed_popups_world');local W,R=PW.W,PW.R
local FP=require('./perf152_fp')(W)
math.randomseed(152)
local V3=R.Vector3.new
local C=PW.boot({tier=TIER or 3})
local other=PW.newPlayer('Other',{Id=2,Pos=V3(14,3,6)})
local st=FP.stream('popups t'..(TIER or 3))
local f=0
local function run(seconds,label)
 for _=1,math.floor(seconds*60+.5)do PW.frames(1,1/60);f+=1;st:frame(label..' f'..f,{C.PG,C.Me.Character,other.Character})end
end
run(.2,'idle')
C.fire(C.Me,25,1,1/5);run(.6,'small')
C.fire(C.Me,4200,5,1/5);run(1.4,'split')
C.fire(other,900,1,1/5);run(.8,'other')
C.fire(C.Me,1250000,1,1/5);C.fire(C.Me,75,1,1/5);run(2,'big')
print('PERF152 POPUPS DONE '..f)
