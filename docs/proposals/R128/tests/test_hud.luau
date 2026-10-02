--!nocheck
-- R128: the hotbar shrinks a bit (never below 66 px, 60 on narrow windows) when that lets the balances, boosts and
-- timers sit at the bottom beside it. Real HudLayout.
local W=require('./world')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local L=W.module('HudLayout')
local function read(w,h)return L.Read({X=w,Y=h},false,nil)end
local function besideBar(m,w)local bar=(m.Slots+1)*m.SlotSize+m.Slots*6;return(w-bar)/2 end
for _,v in ipairs({{1920,1080,82},{1920,1017,82},{1680,1050,82},{1600,900,75},{1536,864,69},{1536,730,69}})do
 local m=read(v[1],v[2])
 check(m.SlotSize==v[3],('%dx%d slot %d (want %d)'):format(v[1],v[2],m.SlotSize,v[3]))
 check(m.StatusBottom==16,('%dx%d timers and boosts sit at the bottom (StatusBottom %d)'):format(v[1],v[2],m.StatusBottom))
 check(m.SlotSize>=66,('%dx%d never smaller than the pre-R127 66 px'):format(v[1],v[2]))
end
-- Too narrow to fit even at 66 px: unchanged from R127 (big slots, side HUD above the bar, as before R127 too).
for _,v in ipairs({{1440,900},{1366,768},{1280,720}})do
 local m=read(v[1],v[2]);check(m.SlotSize==82,('%dx%d keeps 82 px (cannot fit beside at 66)'):format(v[1],v[2]))
end
check(read(1024,768).SlotSize==72,'narrow window 1024 keeps 72 px')
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
