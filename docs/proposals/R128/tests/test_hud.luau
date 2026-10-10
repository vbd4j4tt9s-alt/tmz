--!nocheck
-- R128: the hotbar shrinks a bit (never below 66 px, 60 on narrow windows) when that lets the balances, boosts and
-- timers sit at the bottom beside it. Real HudLayout.
-- R158 (on purpose): the computer HUD is ONE arrangement - the owner's 1920 x 1080 screenshot - laid out as a window of at least 1920 x 720 and drawn shrunk by m.Scale
-- (HudLayout.PcScales). R128's rule (the hotbar shrinks to 66 - 82 px so the balances sit beside it) and R127's 72 px / 5 slots on narrow windows are gone: the slots are 82 HUD px,
-- ten of them and the Bag, on every window, and the balances / boosts / timers always sit at the bottom beside the hotbar; what shrinks is the whole HUD (slot on screen = 82 x Scale).
local W=require('./world')
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local L=W.module('HudLayout')
local function read(w,h)return L.Read({X=w,Y=h},false,nil)end
local function besideBar(m)local bar=(m.Slots+1)*m.SlotSize+m.Slots*(m.SlotGap or 6);return(m.VW-bar)/2 end
for _,v in ipairs({{1920,1080},{1920,1017},{1680,1050},{1600,900},{1536,864},{1536,730},{1440,900},{1366,768},{1280,720},{1024,768},{800,600}})do
 local m=read(v[1],v[2]);local want=math.min(1,v[1]/1920,v[2]/720)
 check(m.SlotSize==82 and m.Slots==10 and m.Compact==false,('%dx%d: ten slots of 82 HUD px (got %d x %d)'):format(v[1],v[2],m.Slots,m.SlotSize))
 check(math.abs(m.Scale-want)<1e-12,('%dx%d: the HUD is drawn at %.4f (min(1, w / 1920, h / 720) = %.4f)'):format(v[1],v[2],m.Scale,want))
 check(math.abs(m.SlotSize*m.Scale-82*want)<1e-9,('%dx%d: a slot is %.1f px on the screen'):format(v[1],v[2],m.SlotSize*m.Scale))
 check(m.StatusBottom==16,('%dx%d timers and boosts sit at the bottom (StatusBottom %d)'):format(v[1],v[2],m.StatusBottom))
 -- the balances (290 + 12 px) and the boosts and timers (337 + 12 px) always fit beside the hotbar: the laid-out window is 1920 wide at the least
 check(besideBar(m)>=math.max(290+12,337+12)+8,('%dx%d: %.0f HUD px beside the hotbar for the balances and the timers'):format(v[1],v[2],besideBar(m)))
end
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
