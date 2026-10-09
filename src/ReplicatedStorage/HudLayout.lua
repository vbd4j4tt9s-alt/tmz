-- R110: larger menu wheel and hotbar slots on every screen; phones keep five slots when they fit.
local L={}
local function overlaps(a,b,pad)
 pad=pad or 0
 return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad
end
-- The HUD's boxes on a screen w x h (m: L.Read): the MENU button (and, with `wheel`, the options of the open wheel), the hotbar (its slots and the 44 px over them: the
-- pity bars' place since R157 - PityBars155.Reserved adds the bars and the held item's name rows above them), the balances, the status stack, a phone's thumb zones and
-- a computer's owner tools tile. (R157: R113's BASE / TRACK spot beside the MENU button, m.Travel, is gone: the real pair lives in the top bar row, TravelButtons.)
function L.HudBoxes(m,w,h,wheel)
 local b={};local shift=m.MenuShiftY or 0
 b[#b+1]={N='Hub',X=m.MenuX,Y=h/2+shift-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}
 if wheel then for i,o in ipairs(m.MenuOffsets)do b[#b+1]={N='Opt'..i,X=m.MenuX+(m.MenuSize-m.MenuOptionSize)/2+o.X,Y=h/2+shift-m.MenuOptionSize/2+o.Y,W=m.MenuOptionSize,H=m.MenuOptionSize}end end
 local bw=(m.Slots+1)*m.SlotSize+m.Slots*6;local detail=m.HotbarDetails~=false and 44 or 0
 b[#b+1]={N='Hotbar',X=w/2+(m.HotbarShiftX or 0)-bw/2,Y=h-m.HotbarBottom-m.SlotSize-detail,W=bw,H=m.SlotSize+detail}
 for _,k in ipairs({'Speed','Cash','Gem'})do b[#b+1]={N='Wallet'..k,X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight}end
 if m.PhoneWide then
  -- R129: landscape phones: the corner status stack (boosts, The Darkened, timers) and the jump button.
  b[#b+1]={N='Status',X=m.StatusBox.X,Y=m.StatusBox.Y,W=m.StatusBox.W,H=m.StatusBox.H}
  for _,z in ipairs(m.ThumbZones)do b[#b+1]={N='Jump',X=z.X,Y=z.Y,W=z.W,H=z.H}end
 elseif m.Phone then
  local sw=(m.StatusHorizontal and 388 or 190)*m.StatusScale;local sh=(m.StatusHorizontal and 39 or 82)*m.StatusScale
  b[#b+1]={N='Status',X=w-12-sw,Y=8,W=sw,H=sh}
  for i,z in ipairs(m.ThumbZones)do b[#b+1]={N=i==1 and'ThumbL'or'ThumbR',X=z.X,Y=z.Y,W=z.W,H=z.H}end
 else
  local sw=(m.StatusStacked and 190 or 337)*m.StatusScale;local sh=(m.StatusStacked and 211 or 125)*m.StatusScale
  b[#b+1]={N='Status',X=w-12-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh}
  b[#b+1]={N='OwnerTools',X=10,Y=8,W=48,H=48}
 end
 return b
end
-- R157 (owner: "daily and invite can also be put into the menu wheel ... readjust the menu wheel further up to make space for them"): the wheel holds FIVE options, the
-- right half of an arc round the MENU button: up, up-right, right (SETTINGS, INDEX, SHOP: where they always were), then down-right and down (DAILY, INVITE).
--  hub / optionSize: the MENU button's and the options' side (px); radius: the usual vertical radius (102, or 86 on a small hub); top / bottom: the band of the HUD area
--  (px from its top) the arc may use (the first and the last option stay inside it); centre: where the MENU button would sit (the middle of the screen); fixed: that centre may
--  not move (computers: the hub stays in the middle and the radius shrinks instead); w: the HUD area's width; avoid: HUD boxes no option may touch (balances, status, hotbar...).
-- It tries, in this order: the usual radius, a smaller one that fits the band, a flatter fan (the two diagonal options pulled in towards the MENU button, the arc up to 178 px
-- wide), then smaller options (56, 52, 48, 44). Every pair of option boxes keeps WheelGap px apart (their 2 px outlines never touch) and clears the MENU button and every `avoid`
-- box. The hub moves up (or down) only as far as the band needs. Where there is room, the two lower options sit a little lower than the mirror image (Low >= Radius) or the arc
-- a little wider, so DAILY's badge (it hangs WheelBadge px over the option's top-right corner) has clear air under SHOP. No answer at all (a canvas shorter than ~230 px): the old
-- three-option arc and DAILY / INVITE in a row beyond SHOP (Fallback = true).
local WheelGap,WheelMaxX,WheelSlots,WheelBadge,WheelX=8,178,5,14,10
local function wheelClear(offsets,hub,option)
 local near=(hub+option)/2+WheelGap;local apart=option+WheelGap
 for i,a in ipairs(offsets)do
  if math.abs(a.X)<near and math.abs(a.Y)<near then return false end
  for j=i+1,#offsets do local b=offsets[j];if math.abs(a.X-b.X)<apart and math.abs(a.Y-b.Y)<apart then return false end end
 end
 return true
end
local function wheelFree(offsets,y,hub,option,avoid)
 for _,o in ipairs(offsets)do
  local x0,y0=WheelX+(hub-option)/2+o.X,y-option/2+o.Y
  for _,b in ipairs(avoid or{})do if x0<b.X+b.W+4 and x0+option>b.X-4 and y0<b.Y+b.H+4 and y0+option>b.Y-4 then return false end end
 end
 return true
end
-- one candidate: the first three options on the arc (radius r, fan c, width rx), the lower pair as low as the badge wants and the band allows.
-- Returns the five offsets, the lower pair's radius and the hub's centre, or nil when two boxes, the hub or an avoided box would touch.
local function wheelFit(hub,option,r,c,rx,top,bottom,center,fixed,avoid)
 local function build(low)return {{X=0,Y=-r},{X=rx*c,Y=-r*c},{X=rx,Y=0},{X=rx*c,Y=low*c},{X=0,Y=low}}end
 local function place(low)return fixed and center or math.max(top+r+option/2,math.min(center,bottom-low-option/2))end
 local offsets,low=build(r),r
 if not(wheelClear(offsets,hub,option)and wheelFree(offsets,place(low),hub,option,avoid))then return nil end
 local room=fixed and math.floor(bottom-center-option/2)or(bottom-top-option-r)
 local want=math.min(room,math.ceil((option+WheelBadge)/c))
 if want>r then local test=build(want);if wheelClear(test,hub,option)and wheelFree(test,place(want),hub,option,avoid)then offsets,low=test,want end end
 return offsets,low,place(low)
end
-- DAILY's badge (top-right corner of option 4) hangs WheelBadge px out: clear of SHOP (option 3) when the two are that far apart sideways or up and down.
local function wheelBadgeClear(offsets,option)
 local a,b=offsets[3],offsets[4]
 return math.abs(a.X-b.X)>=option+WheelBadge or math.abs(a.Y-b.Y)>=option+WheelBadge
end
local function wheelArc(hub,optionSize,radius,top,bottom,center,fixed,w,avoid)
 for _,option in ipairs({optionSize,56,52,48,44})do
  if option<=optionSize then
   local lo=math.ceil((hub+option)/2+WheelGap)
   local hi=math.floor((bottom-top-option)/2)
   if fixed then hi=math.min(hi,math.floor(math.min(center-top,bottom-center)-option/2))end
   local maxX=math.min(WheelMaxX,math.floor(w-18-(hub-option)/2-option))
   local loose -- the first candidate whose boxes clear each other but whose badge touches SHOP: kept if no candidate of this option size gives the badge air
   for r=math.min(radius,hi),lo,-1 do
    for _,c in ipairs({.7071,.62,.55,.5})do
     for rx=r,maxX,2 do
      local offsets,low,y=wheelFit(hub,option,r,c,rx,top,bottom,center,fixed,avoid)
      if offsets then
       local found={Center=y,OptionSize=option,Radius=r,Low=low,RadiusX=rx,Offsets=offsets,Fan=c}
       if wheelBadgeClear(offsets,option)then return found end
       loose=loose or found
      end
     end
    end
   end
   if loose then return loose end
  end
 end
 local y=fixed and center or math.max(top+hub/2,math.min(center,bottom-hub/2))
 local s=optionSize+WheelGap
 local function ring(r,c,rx)return {{X=0,Y=-r},{X=rx*c,Y=-r*c},{X=rx,Y=0},{X=rx+s,Y=0},{X=rx+2*s,Y=0}}end
 local r=math.max(0,math.min(radius,y-top-hub/2));local rx,fan=r<72 and WheelMaxX or r,.7071
 -- (R157: the first radius, fan and width - as the arc above tries them - at which the second ring also clears the MENU button, every avoided box and the screen's
 -- right edge: a 640 x 360 window's first option then stays off the owner tools tile; nothing found: R156's ring as it was)
 local right=w-8-WheelX-(hub-optionSize)/2-optionSize-2*s
 local done=false
 for test=r,math.ceil((hub+optionSize)/2+WheelGap),-1 do
  for _,c in ipairs({.7071,.62,.55,.5})do
   for x=test,math.min(WheelMaxX,right),2 do
    local o=ring(test,c,x)
    if wheelClear(o,hub,optionSize)and wheelFree(o,y,hub,optionSize,avoid)then r,rx,fan,done=test,x,c,true;break end
   end
   if done then break end
  end
  if done then break end
 end
 return {Center=y,OptionSize=optionSize,Radius=r,Low=r,RadiusX=rx,Fallback=true,Fan=fan,Offsets=ring(r,fan,rx)}
end
-- R157 (pity bars v2, owner: "the pity bar is too high up and should be closer to the hot bar"): the pity bars sit just over the hotbar's slots and the held item's
-- name and traits rows (Hotbar.client: SelectedName / SelectedTraits) sit ABOVE them now. PityBars155 places the bars with these numbers (PityGap, PityBarHeight) and the
-- Hotbar puts the rows NameClear px over the bars' top edge, NameBand tall, at most NameWidth wide and centred on the hotbar (the text is centred; a narrower box keeps
-- clear of the wheel, the balances and the status stack on more screens). L.NameRows: where the rows go for a hotbar `bar` ({X, Y, W, H}: its slots) with the bars in
-- their usual place (side by side, not raised); the layouts below use it to tell whether the rows can show on a screen (HotbarDetails).
L.NameBand,L.NameWidth,L.NameClear=42,240,3
function L.PityBarHeight(phone,h)return phone and(h<380 and 18 or 20)or(h<560 and 20 or 24)end
-- (8 px on a computer: the held bar's 2 px rim and the selected slot's 2 px ring sit in it; 6 on a phone, 5 under a thin 16 px phone bar)
function L.PityGap(phone,barH)return phone and(barH<=16 and 5 or 6)or 8 end
function L.NameRows(bar,phone,h)
 local barH=L.PityBarHeight(phone,h);local lift=L.PityGap(phone,barH)+barH+L.NameClear;local width=math.min(bar.W,L.NameWidth)
 return {N='NameRows',X=bar.X+bar.W/2-width/2,Y=bar.Y-lift-L.NameBand,W=width,H=L.NameBand}
end
-- (the rows show when their box is 4 px clear of every box given: the balances, the status stack, the MENU button, the thumb zones and every option of the open wheel)
local function rowsClear(rows,boxes)for _,b in ipairs(boxes)do if overlaps(rows,b,4)then return false end end;return true end
local function wheelBoxes(arc,hub,center)
 local out={}
 for _,o in ipairs(arc.Offsets)do out[#out+1]={X=WheelX+(hub-arc.OptionSize)/2+o.X,Y=center-arc.OptionSize/2+o.Y,W=arc.OptionSize,H=arc.OptionSize}end
 return out
end
-- R129 (owner reference): landscape touch screens keep the HUD on the edges: the balances as text rows in the
-- bottom-left corner, boosts, The Darkened card and the timers stacked in the bottom-right corner just above the jump
-- button, the MENU button on the left middle and the hotbar centred at the bottom. BASE / TRACK stay centred in
-- Roblox's top bar row (TravelButtons).
local function wideLayout(w,h,controls)
 local small=math.min(w,h)<=500;local gap=6
 local jump=controls and controls.Jump;local stick=controls and controls.Joystick
 if not(jump and jump.W>0 and jump.H>0)then jump=small and{X=w-95,Y=h-90,W=70,H=70}or{X=w-170,Y=h-210,W=120,H=120}end
 if not(stick and stick.W>0 and stick.H>0)then stick=small and{X=20,Y=h-110,W=90,H=90}or{X=60,Y=h-180,W=120,H=120}end
 -- Balances: bottom-left text rows (Speed, Cash, Gems).
 local rowH=math.clamp(math.floor(h*.075),24,32);local rowGap=2;local walletW=math.clamp(math.floor(w*.18),130,190)
 local walletStack=rowH*3+rowGap*2;local walletX=10;local walletY=h-6-walletStack
 -- Boosts, The Darkened card and timers: bottom-right rows above the jump button; room for 2 boosts + event + 2 timers.
 local statusScale=math.clamp(math.min(rowH/39*1.05,w*.17/190),.5,.85);local statusW=190*statusScale
 local statusH=(5*43-4)*statusScale;local statusBottom=h-(jump.Y-8)
 local status={X=w-12-statusW,Y=h-statusBottom-statusH,W=statusW,H=statusH}
 -- Hotbar: centred on the screen between the balances and the jump button.
 local laneL,laneR=walletX+walletW+8,jump.X-8;local half=math.min(w/2-laneL,laneR-w/2);local side,slots=64,5
 while side>40 and(slots+1)*side+slots*gap>half*2 do side-=2 end
 if(slots+1)*side+slots*gap>half*2 then slots=math.max(1,math.floor((half*2+gap)/(side+gap))-1)end
 local barW=(slots+1)*side+slots*gap;local hotbarBottom=6;local bar={X=w/2-barW/2,Y=h-hotbarBottom-side,W=barW,H=side}
 -- MENU button on the left middle, above the balances; its wheel opens up and to the right.
 local menuSize=h<280 and 52 or 64;local menuHalf=menuSize/2
 -- R157: five options; the MENU button moves up until the last one (INVITE, straight under it) stands clear above the balances
 local arc=wheelArc(menuSize,menuSize,menuSize==64 and 102 or 86,8,walletY-8,h/2,false,w,
  {status,{X=bar.X,Y=bar.Y-44,W=bar.W,H=bar.H+44},{X=jump.X-6,Y=jump.Y-6,W=jump.W+12,H=jump.H+12}})
 local center,radius,radiusX,offsets=arc.Center,arc.Radius,arc.RadiusX,arc.Offsets
 -- R157: the held item's name rows sit above the pity bars (L.NameRows); they show when they clear the status stack, the balances, the MENU button and the open wheel
 local avoid={status,{X=walletX,Y=walletY,W=walletW,H=walletStack},{X=10,Y=center-menuHalf,W=menuSize,H=menuSize}}
 for _,o in ipairs(wheelBoxes(arc,menuSize,center))do avoid[#avoid+1]=o end
 local showDetails=rowsClear(L.NameRows(bar,true,h),avoid)
 local jumpZone={X=jump.X-6,Y=jump.Y-6,W=jump.W+12,H=jump.H+12}
 local m={Phone=true,PhoneWide=true,PhonePortrait=false,Slots=slots,SlotSize=side,HotbarBottom=hotbarBottom,HotbarShiftX=0,HotbarDetails=showDetails,
  NavSize=menuSize,NavWidth=menuSize,NavGap=6,NavX=10,NavY=center-menuHalf,NavHorizontal=false,
  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=arc.OptionSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  WalletWidth=walletW,WalletHeight=rowH,WalletX=walletX,WalletPlus=math.floor(rowH*.75),WalletIcon=rowH-2,WalletFont=math.floor(rowH*.8),
  WalletHorizontal=false,WalletCompactTap=false,WalletPassive=true,
  SpeedX=walletX,CashX=walletX,GemX=walletX,SpeedY=walletY,CashY=walletY+rowH+rowGap,GemY=walletY+(rowH+rowGap)*2,
  Short=h<480,Compact=true,StatusScale=statusScale,StatusCorner='BottomRight',StatusRight=12,StatusBottom=statusBottom,StatusPlain=true,
  StatusBox=status,StatusStacked=false,StatusHorizontal=false,StatusSideRight=0,
  HideOwnerTools=true,OwnerToolsSize=48,OwnerToolsX=10,OwnerToolsY=8,
  ThumbZones={jumpZone},Joystick=stick,Jump=jump}
 return m
end
local function phoneLayout(w,h,controls)
 if w>h then return wideLayout(w,h,controls)end
 local portrait=h>w;local side=64;local gap=6 -- R127 (owner): bigger hotbar slots (was 56); still shrinks to keep five slots
 local menuSize=(portrait and h<520 or not portrait and h<280)and 52 or 64
 local thumbWidth=math.min(160,math.max(120,math.floor(w*.32)))
 local thumbHeight=math.min(160,math.max(120,math.floor(h*.32)))
 local left={X=0,Y=h-thumbHeight,W=thumbWidth,H=thumbHeight}
 local right={X=w-thumbWidth,Y=h-thumbHeight,W=thumbWidth,H=thumbHeight}
 for name,zone in pairs({Joystick=left,Jump=right})do
  local actual=controls and controls[name]
  if actual and actual.W>0 and actual.H>0 then
   zone.Y=math.max(0,math.min(zone.Y,actual.Y-8));zone.H=h-zone.Y
   if name=='Joystick'then zone.W=math.min(w,math.max(zone.W,actual.X+actual.W+8))
   else zone.X=math.max(0,math.min(zone.X,actual.X-8));zone.W=w-zone.X end
  end
 end
 local lane=right.X-left.W-16
 -- R110: largest slot (64 down to 44 since R127) that still keeps five slots on screen.
 while side>44 and math.floor(((portrait and w-16 or lane)+gap)/(side+gap))-1<5 do side-=2 end
 local slots=math.clamp(math.floor(((portrait and w-16 or lane)+gap)/(side+gap))-1,1,5)
 local hotbarBottom=portrait and math.max(left.H,right.H)+8 or 12
 local barWidth=(slots+1)*side+slots*gap
 local barCenter=portrait and w/2 or(left.W+right.X)/2
 local bar={X=barCenter-barWidth/2,Y=h-hotbarBottom-side,W=barWidth,H=side}
 local menuHalf=menuSize/2;local menuClear=menuHalf+8
 if menuSize==64 and left.Y<150 then menuSize=52;menuHalf=26;menuClear=34 end
 local radiusX=menuSize==64 and 102 or 86 -- (R157: the wheel is placed below, once the balances and the timers are known)
 local statusScale=portrait and .72 or .63
 local statusHorizontal=not portrait and 8+82*statusScale+6+136>right.Y-6
 local statusWidth=(statusHorizontal and 388 or 190)*statusScale
 local timerHeight=(statusHorizontal and 39 or 82)*statusScale
 local walletHeight=44;local walletGap=2;local walletW=144
 local walletY=8+timerHeight+6
 -- Short landscape screens use a single tappable balance row below the timers.
 -- This keeps both native thumb controls clear without shrinking touch targets.
 local horizontal=not portrait and walletY+walletHeight*3+walletGap*2>right.Y-6
 if horizontal then walletW=math.min(120,math.floor((w-12-(10+radiusX+menuSize+8)-12)/3))end
 local walletWidth=horizontal and walletW*3+12 or walletW
 local walletX=w-12-walletWidth
 local wallet={X=walletX,Y=walletY,W=walletWidth,H=horizontal and walletHeight or walletHeight*3+walletGap*2}
 local status={X=w-12-statusWidth,Y=8,W=statusWidth,H=timerHeight}
 -- R157: five options; the last one (INVITE) stands above the pity bars and the held item's name row (78 px over the hotbar), clear of the balances and the timers
 local arc=wheelArc(menuSize,menuSize,menuSize==64 and 102 or 86,8,portrait and bar.Y-78 or left.Y-8,h/2,false,w,{wallet,status})
 local center,radius,offsets=arc.Center,arc.Radius,arc.Offsets;radiusX=arc.RadiusX
 local hub={X=10,Y=center-menuHalf,W=menuSize,H=menuSize}
 -- R157: the held item's name rows sit above the pity bars (L.NameRows); they show when they clear the balances, the timers, the MENU button, the thumb zones and the
 -- open wheel. Owner-approved (pity bars v2): the small 360 / 320 px wide portrait phones up to 780 px tall (360 x 640, 360 x 740; 320 x 568 as before) do not show them: the
 -- stack of the rows and the bars would crowd the moved-up wheel there, and the bars alone sit right over the slots.
 local avoid={wallet,status,hub,left,right}
 for _,o in ipairs(wheelBoxes(arc,menuSize,center))do avoid[#avoid+1]=o end
 local showDetails=rowsClear(L.NameRows(bar,true,h),avoid)and not(portrait and w<370 and h<780)
 local m={Phone=true,PhonePortrait=portrait,Slots=slots,SlotSize=side,HotbarBottom=hotbarBottom,HotbarShiftX=barCenter-w/2,HotbarDetails=showDetails,
  NavSize=menuSize,NavWidth=menuSize,NavGap=6,NavX=10,NavY=center-menuHalf,NavHorizontal=false,
  WalletWidth=walletW,WalletHeight=walletHeight,WalletX=walletX,WalletPlus=44,WalletIcon=horizontal and 22 or 26,WalletFont=20,
  WalletHorizontal=horizontal,WalletCompactTap=horizontal,
  SpeedX=walletX,CashX=walletX+(horizontal and walletW+6 or 0),GemX=walletX+(horizontal and (walletW+6)*2 or 0),
  SpeedY=walletY,CashY=walletY+(horizontal and 0 or walletHeight+walletGap),GemY=walletY+(horizontal and 0 or (walletHeight+walletGap)*2),
  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=arc.OptionSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  Short=h<480,Compact=true,StatusScale=statusScale,StatusTop=8,StatusBottom=h-8-timerHeight,StatusStacked=false,StatusHorizontal=statusHorizontal,StatusSideRight=math.min(0,statusWidth/statusScale-walletW/statusScale)-10,
  HideOwnerTools=true,OwnerToolsSize=48,OwnerToolsX=10,OwnerToolsY=8,
  ThumbZones={left,right}}
 return m
end
-- The layout of a screen w x h (already at least 240 x 150) with all its searching (wheelArc, barsClear below); L.Read memoizes it.
local function readLayout(w,h,touch,controls)
 if touch then return phoneLayout(w,h,controls)end
 local short=h<480;local compact=w<1050 or(touch and h<650)
 local slots=compact and 5 or 10
 -- R127 (owner): bigger hotbar slots on computers: 82 px (was 66), 72 px on narrow windows (was 60).
 local side=math.min(touch and(compact and 44 or 48)or(compact and 72 or 82),math.floor((w-32-slots*6)/(slots+1)))
 if h<300 then side=math.min(side,math.floor(h*.18))end
 local hotbarBottom=touch and w<500 and h>w and math.min(100,math.floor(h*.16))or(h<240 and 8 or 12)
 local nav=short and math.min(48,math.max(28,math.floor(h*.18)))or compact and 48 or 58
 local navWidth=short and nav or compact and(w<500 and 52 or 144)or 190
 local navGap=short and 6 or 8
 local gap=short and 4 or compact and 6 or 7
 local walletW=short and 144 or compact and 188 or 290
 if w<500 then walletW=math.min(170,math.floor((w-36)*.48))end
 local walletH=short and 30 or compact and 36 or 56
 local stacked=w<620
 local statusScale=short and .63 or compact and .76 or 1
 local statusWidth=stacked and 190 or 337
 statusScale=math.min(statusScale,math.max(1,w-walletW-36)/statusWidth)
 if short then nav=math.min(nav,math.floor((w-statusWidth*statusScale-32-navGap*2)/3));navWidth=nav end
 local barWidth=(slots+1)*side+slots*6
 local hudExtent=math.max(walletW,statusWidth*statusScale)+20
 -- R128 (owner): shrink the hotbar a bit (never below the pre-R127 66 / 60 px) when that lets the balances, boosts and
 -- timers sit at the bottom beside it instead of being lifted above it.
 local fitSide=math.floor((w-2*hudExtent-slots*6)/(slots+1))
 if(w-barWidth)/2<hudExtent and fitSide>=math.min(side,compact and 60 or 66)then side=math.min(side,fitSide);barWidth=(slots+1)*side+slots*6 end
 local bottom=(w-barWidth)/2<hudExtent and hotbarBottom+side+12 or 16
 if touch then bottom=math.max(bottom,math.min(160,math.floor(h*.32)))end
 -- Only the navigation dock becomes a compact row on shallow viewports. The balances stay left/bottom.
 local navY=8
 if short then walletH=math.min(walletH,math.floor((h-bottom-navY-nav-12-gap*2)/3))end
 walletH=math.max(16,walletH)
 local walletStack=walletH*3+gap*2
 local speedY=h-bottom-walletStack;local walletX=12
 -- The closed hub stays centered. Only resolve a real collision with the balances.
 local hubSize=h<280 and 52 or 64;local hubTop=(h-hubSize)/2
 if speedY<hubTop+hubSize+8 and h-bottom>hubTop-8 then
  local compactHeight=math.floor((h-bottom-hubTop-hubSize-12)/3)
  if compactHeight>=20 then walletH=math.min(walletH,compactHeight);gap=2;walletStack=walletH*3+gap*2;speedY=h-bottom-walletStack
  elseif 70+walletW+12<=w-12-statusWidth*statusScale and h-bottom<=h-hotbarBottom-side-4 then walletX=70
  else
   gap=h<200 and 0 or 2;walletH=math.min(walletH,math.max(16,math.floor((hubTop-12-gap*2)/3)))
   walletStack=walletH*3+gap*2;speedY=math.max(0,hubTop-4-walletStack)
  end
 end
 local cashY=speedY+walletH+gap;local gemY=cashY+walletH+gap
 if not short then navY=math.max(8,math.min(math.floor(h*.42-nav),speedY-(nav*3+navGap*2)-16))end
 -- Reserve the largest status state (both boosts plus an event) so transitions cannot clip.
 local ownerSize=short and nav or 48
 local statusHeight=stacked and 211 or 125
 statusScale=math.min(statusScale,math.max(1,h-bottom-8-(short and ownerSize+8 or 0))/statusHeight)
 local ownerY=short and 8 or math.max(8,math.min(h*.5-24,h-bottom-statusHeight*statusScale-ownerSize-8))
 local optionSize=h<224 and 44 or h<280 and 50 or 64
 -- R157: five options round the hub, which stays in the middle (the radius shrinks, the fan flattens, then the options shrink, never below 44 px), clear of the tools tile and the hotbar (with its item-name row)
 local margin=h<212 and 4 or 8
 local arc=wheelArc(hubSize,optionSize,hubSize==64 and 102 or 84,margin,h-margin,h/2,true,w,{{X=10,Y=8,W=48,H=48},{X=(w-barWidth)/2,Y=h-hotbarBottom-side-44,W=barWidth,H=side+44}})
 local radius,radiusX,offsets=arc.Radius,arc.RadiusX,arc.Offsets;optionSize=arc.OptionSize
 local boxes={{X=10,Y=(h-hubSize)/2,W=hubSize,H=hubSize},
  {X=w-12-statusWidth*statusScale,Y=h-bottom-statusHeight*statusScale,W=statusWidth*statusScale,H=statusHeight*statusScale},
  -- Owner Tools uses this top-left tile while the wheel is closed.
  {X=10,Y=8,W=48,H=48},
  {X=(w-barWidth)/2,Y=h-hotbarBottom-side,W=barWidth,H=side}}
 for _,at in ipairs(offsets)do boxes[#boxes+1]={X=10+(hubSize-optionSize)/2+at.X,Y=(h-optionSize)/2+at.Y,W=optionSize,H=optionSize}end
 -- R157: the five-option wheel reaches lower than the three-option one (INVITE straight under the MENU button): where its lowest options reach into the balances' corner
 -- (1366 x 768, 1280 x 720 ...), the three rows get shorter and stay in that corner, under the wheel, as R155 does for the closed MENU button (down to the HUD's 16 px rows:
 -- 800 x 600); only when even that does not fit do they move to the spots below (the R113 fallbacks).
 do
  local reach=nil
  for _,at in ipairs(offsets)do
   local x0=10+(hubSize-optionSize)/2+at.X
   if x0<walletX+walletW+4 and x0+optionSize>walletX-4 then reach=math.max(reach or 0,h/2+at.Y+optionSize/2)end
  end
  if reach and speedY<reach+8 then
   local compactHeight=math.floor((h-bottom-(reach+8)-4)/3)
   if compactHeight>=16 then walletH=math.min(walletH,compactHeight);gap=2;walletStack=walletH*3+gap*2;speedY=h-bottom-walletStack end
  end
 end
 local function fits(x,y,width,height)
  if x<0 or y<0 or x+width>w or y+height>h-bottom+.01 then return false end
  for _,box in ipairs(boxes)do if x<box.X+box.W+4 and x+width>box.X-4 and y<box.Y+box.H+4 and y+height>box.Y-4 then return false end end
  return true
 end
 local function metrics()
  cashY=speedY+walletH+gap;gemY=cashY+walletH+gap
  -- R157: the held item's name rows sit above the pity bars (L.NameRows); on a small window they hide when they would run into the balances, the MENU button or an
  -- option of the open wheel. A computer always showed them before; the reserved status box may touch the label's empty ends on a narrow window, as in R155 (its text is
  -- centred and short).
  local avoid={boxes[1],{X=walletX,Y=speedY,W=walletW,H=walletStack}}
  for _,b in ipairs(wheelBoxes(arc,hubSize,h/2))do avoid[#avoid+1]=b end
  local showDetails=rowsClear(L.NameRows({X=(w-barWidth)/2,Y=h-hotbarBottom-side,W=barWidth,H=side},false,h),avoid)
  return {Slots=slots,SlotSize=side,HotbarBottom=hotbarBottom,HotbarDetails=showDetails,NavSize=nav,NavWidth=navWidth,NavGap=navGap,NavX=10,NavY=navY,NavHorizontal=short,
   WalletWidth=walletW,WalletHeight=walletH,WalletX=walletX,MenuSize=hubSize,MenuX=10,MenuOptionSize=optionSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,SpeedY=speedY,CashY=cashY,GemY=gemY,Short=short,Compact=compact,
   StatusScale=statusScale,StatusBottom=bottom,StatusStacked=stacked,OwnerToolsSize=ownerSize,OwnerToolsY=ownerY}
 end
 -- R157: the balances' spot must also leave the pity bars a clear place over the hotbar (a small window: the wheel's lower options push the balances beside it).
 -- PityBars155.Place is asked once a layout is built; without that module (a partial test bundle) any spot that clears the boxes does, as before.
 local function barsClear(m)
  local ok,clear=pcall(function()return require(script.Parent.PityBars155).Place(w,h,m,nil).Clear end)
  return not ok or clear~=false
 end
 local m=metrics()
 if not fits(walletX,speedY,walletW,walletStack)or not barsClear(m)then
  local sideX=10+(hubSize-optionSize)/2+radiusX+optionSize+12
  local natural={walletX,speedY,walletH,gap,walletStack};local first
  for _,height in ipairs({walletH,math.max(20,math.min(walletH,24)),20})do
   local spacing=height==walletH and gap or 2;local stack=height*3+spacing*2
   for _,at in ipairs({{sideX,h-bottom-stack},{12,h-bottom-stack},{70,8},{sideX,8}})do
    if fits(at[1],at[2],walletW,stack)then
     walletX,speedY,walletH,gap,walletStack=at[1],at[2],height,spacing,stack
     local candidate=metrics();if barsClear(candidate)then return candidate end
     first=first or {at[1],at[2],height,spacing,stack}
    end
   end
  end
  -- (no spot leaves the bars clear: the first that clears the boxes, as before R157; none at all: where they were)
  walletX,speedY,walletH,gap,walletStack=table.unpack(first or natural)
  m=metrics()
 end
 return m
end
-- R157 review (performance): the search above is dear - up to ~80 ms on a short PC window (640 x 360), tens of ms on 1920 x 300 and 1280 x 320 - and L.Read is asked all the
-- time (WorldStatusHud every .25 s and every frame of the refresh 3-2-1, every reveal's RarePullCard.FitBand / SkipBoxes, every layout change). The layout is a pure function of
-- what is keyed below, so the last CacheSize answers are kept: the same screen again costs a few comparisons and allocates nothing, a new size searches once.
--  The key, in this order (KeyLength slots, every one compared by value):
--   1  w   2  h       the HUD area, clamped to 240 x 150 exactly as readLayout takes it (view = HudLayout.Viewport: the safe area, so the insets are in it)
--   3  touch          true / false (a phone's layout, or a computer's)
--   4 - 7  Joystick X, Y, W, H     8 - 11  Jump X, Y, W, H     the thumb controls (HudLayout.Controls: safe-area px); false when absent. Only a phone reads them,
--                                                              so a computer's key holds false here (its controls cannot change its layout)
--   12 - 14  L.NameBand, L.NameWidth, L.NameClear      15, 16  L.PityBarHeight, L.PityGap     what L.NameRows (the details rule) reads
--   17  PityBars155 (the module, or false: a partial bundle)   18  its Place   19  L.HudBoxes     what barsClear searches with (a computer only)
--  Nothing else is read: no attribute, no setting, no clock. The answer is shared and FROZEN (deeply: table.freeze) - callers read it, none writes into it (checked for every
--  caller in src), and a write would raise instead of changing what the next caller sees. The caller's `controls` rects are copied before the search, so the answer holds no
--  table of the caller's (m.Joystick / m.Jump of a landscape phone used to be the caller's own rects).
local CacheSize,KeyLength=8,19
local cache,cacheAt,cacheLast,probe={},0,0,{}
local function requireBars()return require(script.Parent.PityBars155)end
-- (equal by value; -0 is not +0 here, an input that differs in anything is a new key; NaN equals nothing, so it just searches again)
local function sameKey(a,b)
 for i=1,KeyLength do
  local x,y=a[i],b[i]
  if x~=y or(x==0 and 1/x~=1/y)then return false end
 end
 return true
end
local function freeze(t)
 if table.isfrozen(t)then return t end
 table.freeze(t)
 for _,v in pairs(t)do if type(v)=='table'then freeze(v)end end
 return t
end
local function rectOf(r)return r and{X=r.X,Y=r.Y,W=r.W,H=r.H}or nil end
-- view: a Vector2 (the HUD area); touch: TouchEnabled; controls: HudLayout.Controls(gui) or nil. Returns the metrics table (see HudBoxes) - shared, frozen, never to be written to.
function L.Read(view,touch,controls)
 local w,h=math.max(240,view.X),math.max(150,view.Y)
 touch=touch and true or false
 local ok,bars -- (first: a module that loads for the first time may run other code, none of which may find the probe half written)
 if not touch then ok,bars=pcall(requireBars)end
 local k=probe
 k[1],k[2],k[3]=w,h,touch
 if touch then
  local stick,jump=controls and controls.Joystick,controls and controls.Jump
  if stick then k[4],k[5],k[6],k[7]=stick.X,stick.Y,stick.W,stick.H else k[4],k[5],k[6],k[7]=false,false,false,false end
  if jump then k[8],k[9],k[10],k[11]=jump.X,jump.Y,jump.W,jump.H else k[8],k[9],k[10],k[11]=false,false,false,false end
  k[17],k[18],k[19]=false,false,false
 else
  k[4],k[5],k[6],k[7],k[8],k[9],k[10],k[11]=false,false,false,false,false,false,false,false
  k[17]=ok and bars or false;k[18]=ok and type(bars)=='table'and bars.Place or false;k[19]=L.HudBoxes
 end
 k[12],k[13],k[14],k[15],k[16]=L.NameBand,L.NameWidth,L.NameClear,L.PityBarHeight,L.PityGap
 local hit=cache[cacheLast]
 if not(hit and sameKey(hit.Key,k))then
  hit=nil
  for i=1,#cache do local entry=cache[i];if sameKey(entry.Key,k)then hit=entry;cacheLast=i;break end end
 end
 if hit then return hit.Layout end
 local key=table.clone(k) -- (before the search: a Read inside it would overwrite the probe)
 local m=freeze(readLayout(w,h,touch,touch and{Joystick=rectOf(controls and controls.Joystick),Jump=rectOf(controls and controls.Jump)}or nil))
 cacheAt=cacheAt%CacheSize+1;cacheLast=cacheAt;cache[cacheAt]={Key=key,Layout=m}
 return m
end
-- R157: the top bar row BASE / TRACK live in (TravelButtons): GuiService.TopbarInset's free part of Roblox's top bar - its left and right ends, top and height - or, when that
-- is not known, the whole width (`width`) and a 52 px row at the top; the pair is clamp(row - 8, 30, 44) px high, centred in the row. Returns left, right, top, row, height.
-- TravelButtons draws by it and L.TravelBottom measures by it, so the two cannot drift apart.
function L.TravelRow(inset,width)
 local left,right,top,row=0,width or 0,0,52
 local ok,x0,x1,y0,h,w=pcall(function()return inset.Min.X,inset.Max.X,inset.Min.Y,inset.Height,inset.Width end)
 if ok and type(y0)=='number'and type(h)=='number'and h>0 and(type(w)~='number'or w>0)then left,right,top,row=x0 or left,x1 or right,y0,h end
 return left,right,top,row,math.clamp(row-8,30,44)
end
-- R157 (the R156 reveal-fixes preview): the bottom edge (px of the full screen) of the BASE / TRACK pair, its drop shadow (3 px) included. The reveal cards
-- (RarePullCard.FitBand) stay below it. inset: GuiService.TopbarInset (a Rect) or nil.
function L.TravelBottom(inset)
 local _,_,top,row,height=L.TravelRow(inset)
 return top+row/2+height/2+3
end
function L.Viewport(gui)
 local root=gui and(gui:IsA('ScreenGui')and gui or gui:FindFirstAncestorOfClass('ScreenGui'))
 local size=root and root.AbsoluteSize
 if size and size.X>0 and size.Y>0 then return size end
 return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
end
function L.Controls(gui)
 local root=gui and(gui:IsA('ScreenGui')and gui or gui:FindFirstAncestorOfClass('ScreenGui'))
 local pg=root and root.Parent;local touch=pg and pg:FindFirstChild('TouchGui')
 if not touch or not touch.Enabled then return nil end
 local area=game:GetService('GuiService'):GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
 local origin=area.Min;local result={}
 for key,name in pairs({Joystick='ThumbstickFrame',Jump='JumpButton'})do
  local item=touch:FindFirstChild(name,true);local visible=item~=nil
  local p=item;while p and p~=touch do if p:IsA('GuiObject')and not p.Visible then visible=false;break end;p=p.Parent end
  if visible then
   local size,position=item.AbsoluteSize,item.AbsolutePosition
   if size.X>0 and size.Y>0 then result[key]={X=position.X-origin.X,Y=position.Y-origin.Y,W=size.X,H=size.Y}end
  end
 end
 return result
end
function L.Watch(gui,callback)
 local cameraConnection;local connections={};local controlConnections={};local stopped=false
 local function update()if not stopped then callback(L.Read(L.Viewport(gui),game:GetService('UserInputService').TouchEnabled,L.Controls(gui)))end end
 local function camera()if cameraConnection then cameraConnection:Disconnect()end;if workspace.CurrentCamera then cameraConnection=workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(update)end;update()end
 local root=gui:IsA('ScreenGui')and gui or gui:FindFirstAncestorOfClass('ScreenGui');if root then connections[#connections+1]=root:GetPropertyChangedSignal('AbsoluteSize'):Connect(update)end
 connections[#connections+1]=workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(camera)
 connections[#connections+1]=game:GetService('UserInputService'):GetPropertyChangedSignal('TouchEnabled'):Connect(update)
 local function stop()if stopped then return end;stopped=true;for _,c in ipairs(controlConnections)do c:Disconnect()end;if cameraConnection then cameraConnection:Disconnect()end;for _,c in ipairs(connections)do c:Disconnect()end end
 local pg=root and root.Parent
 local function watchControls()
  for _,c in ipairs(controlConnections)do c:Disconnect()end;table.clear(controlConnections)
  local touch=pg and pg:FindFirstChild('TouchGui')
  if touch then
   controlConnections[#controlConnections+1]=touch:GetPropertyChangedSignal('Enabled'):Connect(update)
   controlConnections[#controlConnections+1]=touch.DescendantAdded:Connect(function(item)if item.Name=='JumpButton'or item.Name=='ThumbstickFrame'then watchControls();update()end end)
   controlConnections[#controlConnections+1]=touch.DescendantRemoving:Connect(function(item)if item.Name=='JumpButton'or item.Name=='ThumbstickFrame'then task.defer(function()if not stopped then watchControls();update()end end)end end)
   for _,name in ipairs({'JumpButton','ThumbstickFrame'})do local item=touch:FindFirstChild(name,true);if item then
    for _,property in ipairs({'AbsoluteSize','AbsolutePosition','Visible'})do controlConnections[#controlConnections+1]=item:GetPropertyChangedSignal(property):Connect(update)end
   end end
  end
 end
 if pg then
  connections[#connections+1]=pg.ChildAdded:Connect(function(item)if item.Name=='TouchGui'then watchControls();update()end end)
  connections[#connections+1]=pg.ChildRemoved:Connect(function(item)if item.Name=='TouchGui'then watchControls();update()end end)
 end
 connections[#connections+1]=gui.Destroying:Connect(stop);watchControls();camera();return stop
end
local navigation
-- R151 (owner: the Index's red notification badge "cut out wrongly"): each wheel option sits in a CanvasGroup (MenuOption<i>), and a CanvasGroup clips everything
-- past its edge. The group used to be the button + 4 px on every side, but the badge on the INDEX button hangs 6 px past the button's corner (plus its ring): its top
-- and right were sliced off flat. The group now keeps NotifyBadge151.Margin around the button (which a badge's Extent never exceeds); the button itself does not move.
-- R153: the badges are 1.5x bigger, so the margin is 16 px (was 12).
local okBadge,NotifyBadge=pcall(function()return require(script.Parent.NotifyBadge151)end) -- (a partial bundle of a test may not have it: 16 is its Margin)
local PAD=okBadge and NotifyBadge.Margin or 16
L.ChipSize={X=44,Y=20,Gap=6} -- R157: the closed wheel's friend chip, right of the MENU button (Gap px from it)
local function menuPixels(value,size)return math.floor(value*size/48+.5)end
local function styleOption(button,size)
 local captionHeight=menuPixels(14,size);local captionFont=menuPixels(9,size)
 button.AnchorPoint=Vector2.zero;button.Position=UDim2.fromOffset(PAD,PAD);button.Size=UDim2.fromOffset(size,size)
 for _,child in ipairs(button:GetChildren())do
  if child.Name=='Caption'then
   child.Position=UDim2.new(0,0,1,-captionHeight);child.Size=UDim2.new(1,0,0,captionHeight);child.TextSize=captionFont;child.TextXAlignment=Enum.TextXAlignment.Center;child.ZIndex=5
   require(script.Parent.GardenTextFit).Attach(child,captionFont,menuPixels(7,size))
  elseif child.Name=='Gear'then local side=menuPixels(30,size);child.Size=UDim2.fromOffset(side,side);child.Position=UDim2.fromOffset(menuPixels(8,size),menuPixels(3,size))
  elseif child.Name=='GeneratedIndex'or child.Name=='GeneratedRobuxShop'then child.Position=UDim2.fromOffset(menuPixels(4,size),menuPixels(2,size));child.Size=UDim2.fromOffset(menuPixels(40,size),menuPixels(34,size))end
 end
end
local function createNavigation(pg)
 local old=pg:FindFirstChild('GardenNavigation');if old then old:Destroy()end
 local gui=Instance.new('ScreenGui');gui.Name='GardenNavigation';gui.ResetOnSpawn=false;gui.DisplayOrder=33;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=pg
 local hub=Instance.new('TextButton');hub.Name='MenuButton';hub.Text='';hub.BorderSizePixel=0;hub.ZIndex=10;hub:SetAttribute('ButtonSound',false);hub.Parent=gui
 require(script.Parent.BrightUI).Button(hub,Color3.fromRGB(74,125,184))
 local glyph=Instance.new('Frame');glyph.Name='MenuGlyph';glyph.AnchorPoint=Vector2.new(.5,.5);glyph.Position=UDim2.new(.5,0,0,18);glyph.Size=UDim2.fromOffset(22,22);glyph.BackgroundTransparency=1;glyph.ZIndex=14;glyph.Parent=hub
 for i=0,3 do
  local square=Instance.new('Frame');square.Name='Tile'..i;square.Size=UDim2.fromOffset(8,8);square.Position=UDim2.fromOffset(i%2*14,math.floor(i/2)*14);square.BackgroundColor3=Color3.fromRGB(235,248,255);square.BorderSizePixel=0;square.ZIndex=14;square.Parent=glyph
  local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,2);corner.Parent=square
 end
 local caption=Instance.new('TextLabel');caption.Name='Caption';caption.Text='MENU';caption.BackgroundTransparency=1;caption.Position=UDim2.new(0,0,1,-14);caption.Size=UDim2.new(1,0,0,14);caption.TextXAlignment=Enum.TextXAlignment.Center;caption.ZIndex=15;caption.Parent=hub
 require(script.Parent.BrightUI).Text(caption,10);require(script.Parent.GardenTextFit).Attach(caption,10,9)
 local state={Gui=gui,Hub=hub,Glyph=glyph,Caption=caption,Entries={},Connections={},Open=false,Serial=0,Dead=false,Tweens={}}
 local Tween=game:GetService('TweenService');local Gui=game:GetService('GuiService')
 local function cancel(record)
  if record.Completed then record.Completed:Disconnect();record.Completed=nil end
  for _,tween in ipairs(record.Tweens)do tween:Cancel()end;table.clear(record.Tweens)
 end
 local function position(entry,opened)
  local m=state.Metrics;local at=m.MenuOffsets[entry.Index];local x,y=at.X,at.Y
  return UDim2.new(0,m.MenuX+(m.MenuSize-m.MenuOptionSize)/2-PAD+(opened and x or 0),.5,(m.MenuShiftY or 0)-m.MenuOptionSize/2-PAD+(opened and y or 0))
 end
 local function animate(entry,instant)
  cancel(entry);local shown=state.Open and pg:GetAttribute('SeedMenu')==nil
  entry.Button.Visible=true;entry.Button.Active=shown;entry.Button.Interactable=shown
  local target={Position=position(entry,shown),GroupTransparency=shown and 0 or 1}
  local serial=state.Serial
  if instant or Gui.ReducedMotionEnabled then
   entry.Group.Position=target.Position;entry.Group.GroupTransparency=target.GroupTransparency;entry.Group.Visible=shown;return
  end
  if shown then entry.Group.Visible=true end
  local tween=Tween:Create(entry.Group,TweenInfo.new(shown and .2 or .15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),target);entry.Tweens[1]=tween
  entry.Completed=tween.Completed:Connect(function()
   if state.Dead or entry.Removed or serial~=state.Serial then return end
   entry.Group.Visible=shown;entry.Completed:Disconnect();entry.Completed=nil;table.clear(entry.Tweens)
  end);tween:Play()
 end
 -- R157: gamepad links. The wheel had none (Roblox picked by direction, a guess with five options in a half circle). While it is open: MENU up -> option 1, right -> option 3
 -- (SHOP), down -> option 5 (INVITE); the options chain clockwise on down / right (1 -> 2 -> 3 -> 4 -> 5) and back on up / left, the two ends back to MENU; SelectionOrder
 -- 1..5 (MENU 0). While it is closed the options are not on screen, so nothing links to them.
 local function links()
  local list={}
  for i=1,WheelSlots do local e=state.Entries[i];if e then list[#list+1]=e.Button;e.Button.SelectionOrder=i end end
  hub.SelectionOrder=0
  local open=state.Open and #list>0
  local function slot(i)local e=state.Entries[i];return open and e and e.Button or nil end
  hub.NextSelectionUp=open and(slot(1)or list[1])or nil;hub.NextSelectionRight=open and(slot(3)or list[math.min(#list,3)])or nil;hub.NextSelectionDown=open and(slot(5)or list[#list])or nil
  for k,b in ipairs(list)do
   local after=open and(list[k+1]or hub)or nil;local before=open and(list[k-1]or hub)or nil
   b.NextSelectionDown=after;b.NextSelectionRight=after;b.NextSelectionUp=before;b.NextSelectionLeft=before
  end
 end
 state.Links=links
 -- R157: the friend speed chip ("+20%": DailyRewardsClient's chip on the INVITE option) sits inside the closed wheel, so while the wheel is closed the MENU button carries a copy
 -- just right of it, centred on it (clear of the "!" on its top-right corner and of its caption). DailyRewardsClient publishes the words as the PlayerGui attribute
 -- MenuFriendBoost ('' or none: no friend here, no chip).
 local chip=Instance.new('TextLabel');chip.Name='FriendBoost';chip.AnchorPoint=Vector2.new(0,.5);chip.Position=UDim2.new(1,L.ChipSize.Gap,.5,0);chip.Size=UDim2.fromOffset(L.ChipSize.X,L.ChipSize.Y)
 chip.BackgroundColor3=Color3.fromRGB(110,226,96);chip.BorderSizePixel=0;chip.Font=Enum.Font.FredokaOne;chip.TextScaled=true;chip.TextColor3=Color3.fromRGB(16,30,40);chip.Text='';chip.Visible=false;chip.Active=false;chip.ZIndex=16;chip.Parent=hub
 do local c=Instance.new('UICorner');c.CornerRadius=UDim.new(.5,0);c.Parent=chip;local st=Instance.new('UIStroke');st.Color=Color3.new(1,1,1);st.Thickness=2;st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Parent=chip end
 local function boostChip()
  local text=pg:GetAttribute('MenuFriendBoost');text=type(text)=='string'and text or''
  chip.Text=text;chip.Visible=text~=''and not state.Open
 end
 state.BoostChip=boostChip
 function state:SetOpen(value,instant)
  if self.Dead then return end
  self.Serial+=1;self.Open=value==true and pg:GetAttribute('SeedMenu')==nil
  pg:SetAttribute('GardenMenuExpanded',self.Open)
  local available=pg:GetAttribute('SeedMenu')==nil;hub.Visible=available;hub.Active=available;hub.Interactable=available
  caption.Text=self.Open and'CLOSE'or'MENU';hub:SetAttribute('AccessibleLabel',self.Open and'Close menu'or'Open menu');hub:SetAttribute('Expanded',self.Open)
  cancel(self)
  local rotation=self.Open and 45 or 0
  if instant or Gui.ReducedMotionEnabled then glyph.Rotation=rotation else local tween=Tween:Create(glyph,TweenInfo.new(.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Rotation=rotation});self.Tweens[1]=tween;tween:Play()end
  for _,entry in pairs(self.Entries)do animate(entry,instant)end
  links();boostChip()
  -- (R157: closed while the pad was on an option: back to the MENU button, when it is on screen)
  if not self.Open then pcall(function()local sel=Gui.SelectedObject;if sel and sel~=hub and sel:IsDescendantOf(gui)then Gui.SelectedObject=hub.Visible and hub or nil end end)end
 end
 local function layout(m)
  if state.Dead then return end;state.Metrics=m
  hub.AnchorPoint=Vector2.zero;hub.Position=UDim2.new(0,m.MenuX,.5,(m.MenuShiftY or 0)-m.MenuSize/2);hub.Size=UDim2.fromOffset(m.MenuSize,m.MenuSize)
  local size=m.MenuSize;local captionHeight=menuPixels(14,size)
  glyph.Position=UDim2.new(.5,0,0,menuPixels(18,size));glyph.Size=UDim2.fromOffset(menuPixels(22,size),menuPixels(22,size))
  for i=0,3 do local tile=glyph:FindFirstChild('Tile'..i);tile.Size=UDim2.fromOffset(menuPixels(8,size),menuPixels(8,size));tile.Position=UDim2.fromOffset(menuPixels(i%2*14,size),menuPixels(math.floor(i/2)*14,size))end
  caption.Position=UDim2.new(0,0,1,-captionHeight);caption.Size=UDim2.new(1,0,0,captionHeight);caption.TextSize=menuPixels(10,size)
  require(script.Parent.GardenTextFit).Attach(caption,menuPixels(10,size),menuPixels(9,size))
  for _,entry in pairs(state.Entries)do entry.Group.Size=UDim2.fromOffset(m.MenuOptionSize+PAD*2,m.MenuOptionSize+PAD*2);styleOption(entry.Button,m.MenuOptionSize)end
  state:SetOpen(state.Open,true)
 end
 state.StopLayout=L.Watch(gui,layout)
 -- R157 (suggestion): ONE red "!" on the MENU button for everything waiting inside the wheel. ChestIndex (INDEX rewards) and DailyRewardsClient (DAILY rewards) publish how many
 -- are waiting as the PlayerGui attributes MenuAlertIndex / MenuAlertDaily; the badge is the hub's own (it was ChestIndex's: the same "IndexRewardAlert", Alert size and overhang).
 local alertTotal=0
 local function alerts()
  if state.Dead or not okBadge then return end
  local total=(tonumber(pg:GetAttribute('MenuAlertIndex'))or 0)+(tonumber(pg:GetAttribute('MenuAlertDaily'))or 0)
  NotifyBadge.Set(NotifyBadge.Make(hub,'IndexRewardAlert',NotifyBadge.Sizes.Alert,NotifyBadge.Overhang.Alert),'!',total>0,total>alertTotal);alertTotal=total
 end
 for _,key in ipairs({'MenuAlertIndex','MenuAlertDaily'})do state.Connections[#state.Connections+1]=pg:GetAttributeChangedSignal(key):Connect(alerts)end
 alerts()
 state.Connections[#state.Connections+1]=hub.Activated:Connect(function()
  if state.Dead or not hub.Active or pg:GetAttribute('SeedMenu')~=nil then return end
  local fromPad=Gui.SelectedObject==hub -- (R157: opened from the gamepad - the pad was on the MENU button: option 1 is selected)
  require(script.Parent.InteractionAudio).Play(state.Open and'MenuClose'or'MenuClick');state:SetOpen(not state.Open,false) -- R150: closing the wheel is MenuClose, like every other close
  if fromPad and state.Open then for i=1,WheelSlots do local e=state.Entries[i];if e then pcall(function()Gui.SelectedObject=e.Button end);break end end end
 end)
 state.Connections[#state.Connections+1]=pg:GetAttributeChangedSignal('MenuFriendBoost'):Connect(boostChip)
 state.Connections[#state.Connections+1]=pg:GetAttributeChangedSignal('SeedMenu'):Connect(function()state:SetOpen(false,true)end)
 state.Connections[#state.Connections+1]=Gui:GetPropertyChangedSignal('ReducedMotionEnabled'):Connect(function()state:SetOpen(state.Open,true)end)
 state.Connections[#state.Connections+1]=gui.Destroying:Connect(function()
  if state.Dead then return end;state.Dead=true;pg:SetAttribute('GardenMenuExpanded',false);state.StopLayout();cancel(state)
  for _,connection in ipairs(state.Connections)do connection:Disconnect()end
  for _,entry in pairs(state.Entries)do entry.Removed=true;cancel(entry);for _,connection in ipairs(entry.Connections)do connection:Disconnect()end end
  table.clear(state.Entries);if navigation==state then navigation=nil end
 end)
 return state
end
function L.Navigation(button,index)
 assert(index>=1 and index<=WheelSlots and index%1==0,'Invalid navigation slot')
 local owner=assert(button:FindFirstAncestorOfClass('ScreenGui'),'Navigation needs a ScreenGui');local pg=owner.Parent
 owner.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
 if not navigation or navigation.Dead or navigation.Gui.Parent~=pg then navigation=createNavigation(pg)end
 local state=navigation;local previous=state.Entries[index]
 if previous and previous.Button==button then return previous.Remove end
 if previous then previous.Remove(true)end
 local group=Instance.new('CanvasGroup');group.Name='MenuOption'..index;group.BackgroundTransparency=1;group.Size=UDim2.fromOffset(state.Metrics.MenuOptionSize+PAD*2,state.Metrics.MenuOptionSize+PAD*2);group.GroupTransparency=1;group.Visible=false;group.ZIndex=2+index;group.Parent=state.Gui
 local entry={Index=index,Button=button,Group=group,Connections={},Tweens={}};state.Entries[index]=entry;button:SetAttribute('ButtonSound',false);button.Parent=group
 function entry.Remove(replacing)
  if entry.Removed then return end;entry.Removed=true
  if entry.Completed then entry.Completed:Disconnect();entry.Completed=nil end
  for _,tween in ipairs(entry.Tweens)do tween:Cancel()end
  for _,connection in ipairs(entry.Connections)do connection:Disconnect()end
  if state.Entries[index]==entry then state.Entries[index]=nil end
  group:Destroy()
  if not state.Dead and state.Links then state.Links()end
  if not replacing and not state.Dead and not next(state.Entries)then state.Gui:Destroy()end
 end
 entry.Connections[1]=owner.Destroying:Connect(function()entry.Remove()end)
 entry.Connections[2]=button.Destroying:Connect(function()entry.Remove()end)
 entry.Connections[3]=button.Activated:Connect(function()if state.Open then require(script.Parent.InteractionAudio).Play('MenuClick');state:SetOpen(false,true)end end)
 styleOption(button,state.Metrics.MenuOptionSize);state:SetOpen(state.Open,true)
 return entry.Remove
end
return L
