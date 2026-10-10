--!nocheck
-- R158 preview (not a test): HudLayout on many PC screen sizes - this checkout's ("cur") or a patched copy (A / B, make_variants158.py): where the MENU button goes, the wheel's
-- option size, whether the five-option arc was found (a "FALLBACK" = DAILY / INVITE in a row past SHOP: no half circle fit), how far the open wheel is from the balances and from the
-- top bar, the balance rows' height (shortened = the R157 rule), and whether any option touches another HUD box (balances, hotbar with its name rows, status stack) or leaves the screen.
-- Needs roblox.luau + world.luau + rs_bundle.luau (run_hud_lock158.sh builds them, one folder per layout). Prints one TSV row per size; LABEL (a global) names the layout.
local W=require('./world');local R=W.R
local Hud=W.module('HudLayout');local V2=R.Vector2.new
local SIZES={
 {1920,1080},{1920,1200},{2560,1440},{1680,1050},{1600,900},{1536,864},{1440,900},{1366,768},{1280,720},{1280,800},{1024,768},{800,600},{720,480},{640,360},{1920,300},{1280,320},
 {1920,1440}, -- (what an 800 x 600 window is laid out as when the HUD is shrunk to fit: 1920 wide, 4:3)
 {1920,720},{2304,720},{1920,900}, -- (the shortest windows the shrunk layout is ever read at: height 720, 1920 or more wide)
}
local function ov(a,b)return a.X<b.X+b.W and a.X+a.W>b.X and a.Y<b.Y+b.H and a.Y+a.H>b.Y end
print('layout\tsize\tMENU centre y\toption px\tradius\tfallback\twheel top\twheel bottom\tgap to balances\trow h\tname rows\tproblems')
for _,s in ipairs(SIZES)do
 local w,h=s[1],s[2]
 local m=Hud.Read(V2(w,h),false,nil)
 local o=m.MenuOffsets;local shift=m.MenuShiftY or 0;local centre=h/2+shift;local size=m.MenuOptionSize
 local lo,hi=0,0;for _,q in ipairs(o)do lo=math.min(lo,q.Y);hi=math.max(hi,q.Y)end
 local top,bottom=centre+lo-size/2,centre+hi+size/2
 local boxes=Hud.HudBoxes(m,w,h,true)
 local problems={};local wallet=math.huge
 for _,b in ipairs(boxes)do if b.N:sub(1,6)=='Wallet'then wallet=math.min(wallet,b.Y)end end
 for _,a in ipairs(boxes)do if a.N:sub(1,3)=='Opt'then
  if a.X<0 or a.Y<0 or a.X+a.W>w or a.Y+a.H>h then problems[#problems+1]=a.N..' off screen'end
  for _,b in ipairs(boxes)do if b.N~='Hub'and b.N~='OwnerTools'and b.N:sub(1,3)~='Opt'and ov(a,b)then problems[#problems+1]=a.N..' over '..b.N end end
 end end
 print(string.format('%s\t%dx%d\t%.0f\t%d\t%.0f\t%s\t%.0f\t%.0f\t%.0f\t%d\t%s\t%s',LABEL or'?',w,h,centre,size,m.MenuRadius,o[4].X>o[3].X and'FALLBACK'or'no',top,bottom,wallet-bottom,m.WalletHeight,m.HotbarDetails~=false and'shown'or'hidden',#problems==0 and'-'or table.concat(problems,'; ')))
end
