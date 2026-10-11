--!nocheck
-- R156 preview (not a test): the PROPOSED HudLayout (make_variant156.py) on many screen sizes: where the MENU button goes, the wheel's radii, the option size, whether the arc is a circle or a
-- flatter fan, and whether any option touches another HUD box or leaves the screen. Prints one TSV row per screen (the table in menu_wheel_daily.md is this output).
-- Needs roblox.luau + world.luau + rs_bundle.luau (run_menu_wheel156.sh builds them). TOUCH screens use HudLayout's phone branches (landscape = wideLayout, portrait = phoneLayout).
local W=require('./world');local R=W.R
local Hud=W.module('HudLayout');local V2=R.Vector2.new
local SCREENS={
 {'PC 1920x1080',1920,1080,false},{'PC 1366x768',1366,768,false},{'PC 1280x720',1280,720,false},{'PC 1024x768',1024,768,false},{'PC 800x600',800,600,false},{'PC 640x360',640,360,false},
 {'Phone landscape 932x430',932,430,true},{'Phone landscape 844x390',844,390,true},{'Phone landscape 740x360',740,360,true},{'Phone landscape 667x375',667,375,true},
 {'Phone landscape 750x311 (844x390 with safe-area insets)',750,311,true},{'Phone landscape 568x320',568,320,true},{'Phone landscape 640x280',640,280,true},{'Phone landscape 600x250',600,250,true},{'Phone landscape 560x220',560,220,true},
 {'Phone portrait 430x932',430,932,true},{'Phone portrait 390x844',390,844,true},{'Phone portrait 375x667',375,667,true},{'Phone portrait 360x640',360,640,true},{'Phone portrait 320x568',320,568,true},
}
local function ov(a,b,pad)return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad end
print('screen\thub centre y (shift)\toption px\tradius up / low\tarc width\tshape\tfirst / last option top / bottom\tproblems')
for _,s in ipairs(SCREENS)do
 local name,w,h,touch=s[1],s[2],s[3],s[4]
 local m=Hud.Read(V2(w,h),touch,nil)
 local o=m.MenuOffsets;local shift=m.MenuShiftY or 0;local centre=h/2+shift;local size=m.MenuOptionSize
 local up,low=-o[1].Y,o[5].Y;local lo,hi=0,0;for _,q in ipairs(o)do lo=math.min(lo,q.Y);hi=math.max(hi,q.Y)end
 local fan=o[4].X>o[3].X and'fallback: DAILY / INVITE in a row beyond SHOP'or(math.abs(o[2].X/o[3].X-.7071)<.01 and'circle'or string.format('fan %.2f',o[2].X/o[3].X))
 local problems={}
 local boxes=Hud.HudBoxes(m,w,h,true)
 for _,a in ipairs(boxes)do if a.N:sub(1,3)=='Opt'then
  if a.X<0 or a.Y<0 or a.X+a.W>w or a.Y+a.H>h then problems[#problems+1]=a.N..' off screen'end
  for _,b in ipairs(boxes)do if b.N~='Hub'and b.N:sub(1,3)~='Opt'and ov(a,b,0)then problems[#problems+1]=a.N..' over '..b.N end end
  for _,b in ipairs(boxes)do if b~=a and b.N:sub(1,3)=='Opt'and b.N>a.N and ov(a,b,0)then problems[#problems+1]=a.N..' over '..b.N end end
 end end
 for _,b in ipairs(boxes)do if b.N:sub(1,3)=='Opt'and b.N~='Hub'and ov(b,boxes[1],0)then problems[#problems+1]=b.N..' over the hub'end end
 print(string.format('%s\t%.0f (%+.0f)\t%d\t%.0f / %.0f\t%.0f\t%s\t%.0f / %.0f\t%s',name,centre,shift,size,up,low,o[3].X,fan,centre+lo-size/2,centre+hi+size/2,#problems==0 and'-'or table.concat(problems,'; ')))
end
