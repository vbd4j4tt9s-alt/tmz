"""R156 menu-wheel preview: writes the PROPOSED scripts into OUT_DIR as patched copies of this checkout's src/ (src/ itself is never touched):
  HudLayout.lua                  five wheel options (wheelArc), the MENU button moved up where the arc needs it, Navigation slots 1..5, the hub's one red "!" for everything waiting inside
  TravelButtons.client.lua       BASE / TRACK alone in the top bar row (the DAILY / INVITE squares and their slots are gone)
  DailyRewardsClient.client.lua  DAILY = wheel slot 4, INVITE = wheel slot 5; the DAILY badge on its button's top-right corner like the INDEX badge; tells the hub how many rewards wait
  ChestIndex.client.lua          tells the hub how many Index rewards wait (the hub badge itself is HudLayout's now)
Every replacement must match exactly once, so a changed source stops the script instead of silently previewing something else.
Usage: python3 make_variant156.py SRC_DIR OUT_DIR"""
import os
import sys

SRC, OUT = os.path.normpath(sys.argv[1]), sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def read(*p):
    return open(os.path.join(SRC, *p), encoding='utf-8').read()


def rep(text, old, new, label):
    n = text.count(old)
    if n != 1:
        sys.exit('make_variant156: %s: expected exactly one match, found %d' % (label, n))
    return text.replace(old, new)


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# HudLayout
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
H = read('ReplicatedStorage', 'HudLayout.lua')

ARC = r'''-- R156 (owner: "daily and invite can also be put into the menu wheel ... readjust the menu wheel further up to make space for them"): the wheel holds FIVE options, the
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
 local r=math.max(0,math.min(radius,y-top-hub/2));local rx=r<72 and WheelMaxX or r;local s=optionSize+WheelGap
 return {Center=y,OptionSize=optionSize,Radius=r,Low=r,RadiusX=rx,Fallback=true,Fan=.7071,
  Offsets={{X=0,Y=-r},{X=rx*.7071,Y=-r*.7071},{X=rx,Y=0},{X=rx+s,Y=0},{X=rx+2*s,Y=0}}}
end
'''
H = rep(H, "-- R129 (owner reference): landscape touch screens keep the HUD on the edges:", ARC + "-- R129 (owner reference): landscape touch screens keep the HUD on the edges:", 'HudLayout: arc helper')

# landscape phones
H = rep(H, ''' local menuSize=h<280 and 52 or 64;local menuHalf=menuSize/2;local menuClear=menuHalf+8
 local center=math.max(menuClear,math.min(h/2,walletY-10-menuHalf))
 local radius=math.max(0,math.min(menuSize==64 and 102 or 86,center-menuClear))
 local radiusX=radius<72 and 178 or radius
 local offsets={{X=0,Y=-radius},{X=radiusX/math.sqrt(2),Y=-radius/math.sqrt(2)},{X=radiusX,Y=0}}
''', ''' local menuSize=h<280 and 52 or 64;local menuHalf=menuSize/2
 -- R156: five options; the MENU button moves up until the last one (INVITE, straight under it) stands clear above the balances
 local arc=wheelArc(menuSize,menuSize,menuSize==64 and 102 or 86,8,walletY-8,h/2,false,w,
  {status,{X=bar.X,Y=bar.Y-44,W=bar.W,H=bar.H+44},{X=jump.X-6,Y=jump.Y-6,W=jump.W+12,H=jump.H+12}})
 local center,radius,radiusX,offsets=arc.Center,arc.Radius,arc.RadiusX,arc.Offsets
''', 'HudLayout: wide arc')
H = rep(H, '''  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=menuSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  WalletWidth=walletW,WalletHeight=rowH,''', '''  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=arc.OptionSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  WalletWidth=walletW,WalletHeight=rowH,''', 'HudLayout: wide metrics')

# portrait phones: the balances and the timers (top right) are known only after the old arc block, so the arc is computed after them
H = rep(H, ''' local center=math.max(menuClear,math.min(h/2,(portrait and bar.Y or left.Y)-menuClear))
 local radius=math.max(0,math.min(menuSize==64 and 102 or 86,center-menuClear))
 local radiusX=radius<72 and 178 or menuSize==64 and 102 or 86
 local offsets={{X=0,Y=-radius},{X=radiusX/math.sqrt(2),Y=-radius/math.sqrt(2)},{X=radiusX,Y=0}}
''', ''' local radiusX=menuSize==64 and 102 or 86 -- (R156: the wheel is placed below, once the balances and the timers are known)
''', 'HudLayout: phone arc moved')
H = rep(H, ''' local status={X=w-12-statusWidth,Y=8,W=statusWidth,H=timerHeight}
 local hub={X=10,Y=center-menuHalf,W=menuSize,H=menuSize}
''', ''' local status={X=w-12-statusWidth,Y=8,W=statusWidth,H=timerHeight}
 -- R156: five options; the last one (INVITE) stands above the pity bars and the held item's name row (78 px over the hotbar), clear of the balances and the timers
 local arc=wheelArc(menuSize,menuSize,menuSize==64 and 102 or 86,8,portrait and bar.Y-78 or left.Y-8,h/2,false,w,{wallet,status})
 local center,radius,offsets=arc.Center,arc.Radius,arc.Offsets;radiusX=arc.RadiusX
 local hub={X=10,Y=center-menuHalf,W=menuSize,H=menuSize}
''', 'HudLayout: phone arc')
H = rep(H, '''  if overlaps(details,{X=10+o.X,Y=center-menuHalf+o.Y,W=menuSize,H=menuSize},4)then showDetails=false end''',
        '''  if overlaps(details,{X=10+(menuSize-arc.OptionSize)/2+o.X,Y=center-arc.OptionSize/2+o.Y,W=arc.OptionSize,H=arc.OptionSize},4)then showDetails=false end''', 'HudLayout: phone details')
H = rep(H, '''  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=menuSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  Short=h<480,Compact=true,StatusScale=statusScale,StatusTop=8,''', '''  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=arc.OptionSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  Short=h<480,Compact=true,StatusScale=statusScale,StatusTop=8,''', 'HudLayout: phone metrics')

# computers: the hub stays in the middle
H = rep(H, ''' local radius=math.min(hubSize==64 and 102 or 84,h/2-optionSize/2-(h<212 and 4 or 8))
 -- Exceptionally short canvases widen the upper arc; targets never shrink below44px.
 local radiusX=radius<76 and math.min(178,w-10-(hubSize-optionSize)/2-optionSize-6)or radius
 local offsets={{X=0,Y=-radius},{X=radiusX/math.sqrt(2),Y=-radius/math.sqrt(2)},{X=radiusX,Y=0}}
''', ''' -- R156: five options round the hub, which stays in the middle (the radius shrinks, the fan flattens, then the options shrink, never below 44 px), clear of the tools tile and the hotbar (with its item-name row)
 local margin=h<212 and 4 or 8
 local arc=wheelArc(hubSize,optionSize,hubSize==64 and 102 or 84,margin,h-margin,h/2,true,w,{{X=10,Y=8,W=48,H=48},{X=(w-barWidth)/2,Y=h-hotbarBottom-side-44,W=barWidth,H=side+44}})
 local radius,radiusX,offsets=arc.Radius,arc.RadiusX,arc.Offsets;optionSize=arc.OptionSize
''', 'HudLayout: PC arc')

# Navigation: five slots, later options draw over earlier ones (the badge on DAILY's corner may touch SHOP's edge)
H = rep(H, "assert(index>=1 and index<=3 and index%1==0,'Invalid navigation slot')", "assert(index>=1 and index<=WheelSlots and index%1==0,'Invalid navigation slot')", 'HudLayout: slots')
H = rep(H, "group.BackgroundTransparency=1;group.Size=UDim2.fromOffset(state.Metrics.MenuOptionSize+PAD*2,state.Metrics.MenuOptionSize+PAD*2);group.GroupTransparency=1;group.Visible=false;group.ZIndex=2;group.Parent=state.Gui",
        "group.BackgroundTransparency=1;group.Size=UDim2.fromOffset(state.Metrics.MenuOptionSize+PAD*2,state.Metrics.MenuOptionSize+PAD*2);group.GroupTransparency=1;group.Visible=false;group.ZIndex=2+index;group.Parent=state.Gui", 'HudLayout: group order')

# the hub's one badge
H = rep(H, "\n state.StopLayout=L.Watch(gui,layout)\n", '''
 state.StopLayout=L.Watch(gui,layout)
 -- R156 (suggestion): ONE red "!" on the MENU button for everything waiting inside the wheel. ChestIndex (INDEX rewards) and DailyRewardsClient (DAILY rewards) publish how many
 -- are waiting as the PlayerGui attributes MenuAlertIndex / MenuAlertDaily; the badge is the hub's own (it was ChestIndex's: the same "IndexRewardAlert", Alert size and overhang).
 local alertTotal=0
 local function alerts()
  if state.Dead or not okBadge then return end
  local total=(tonumber(pg:GetAttribute('MenuAlertIndex'))or 0)+(tonumber(pg:GetAttribute('MenuAlertDaily'))or 0)
  NotifyBadge.Set(NotifyBadge.Make(hub,'IndexRewardAlert',NotifyBadge.Sizes.Alert,NotifyBadge.Overhang.Alert),'!',total>0,total>alertTotal);alertTotal=total
 end
 for _,key in ipairs({'MenuAlertIndex','MenuAlertDaily'})do state.Connections[#state.Connections+1]=pg:GetAttributeChangedSignal(key):Connect(alerts)end
 alerts()
''', 'HudLayout: hub alert')
open(os.path.join(OUT, 'HudLayout.lua'), 'w', encoding='utf-8').write(H)

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# TravelButtons: BASE / TRACK only
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
T = read('StarterPlayer', 'StarterPlayerScripts', 'TravelButtons.client.lua')
T = rep(T, '''-- R140: two square slots in the same row, right of TRACK, for the 🎁 DAILY and 👥 INVITE buttons (DailyRewardsClient
-- builds them inside these frames). They show and hide with the pair.
local icons=Instance.new('Frame');icons.Name='TopIcons';icons.BackgroundTransparency=1;icons.Visible=false;icons.Parent=gui
for i,name in ipairs({'Daily','Invite'})do local slot=Instance.new('Frame');slot.Name=name;slot.BackgroundTransparency=1;slot.LayoutOrder=i;slot.Parent=icons end
''', '-- R156: DAILY and INVITE live in the menu wheel (HudLayout.Navigation 4 and 5); this row holds BASE / TRACK alone.\n', 'TravelButtons: slots')
T = rep(T, ";icons.Visible=holder.Visible\nend", "\nend", 'TravelButtons: refresh')
lines = T.split('\n')
a = next(i for i, l in enumerate(lines) if l.startswith(" -- R140: the DAILY / INVITE squares go right of TRACK."))
b = next(i for i, l in enumerate(lines) if l.startswith(" for i,name in ipairs({'Daily','Invite'})do local slot=icons[name]"))
assert a < b and b - a < 14, 'TravelButtons: layout block moved'
del lines[a:b + 1]
T = '\n'.join(lines)
open(os.path.join(OUT, 'TravelButtons.client.lua'), 'w', encoding='utf-8').write(T)

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# DailyRewardsClient: DAILY / INVITE are wheel options
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
D = read('StarterPlayer', 'StarterPlayerScripts', 'DailyRewardsClient.client.lua')
D = rep(D, "local b=new('TextButton',{Name=name,Text='',Size=UDim2.fromScale(1,1),BorderSizePixel=0,ZIndex=10,AutoButtonColor=true},nil)",
        "local b=new('TextButton',{Name=name,Text='',Size=UDim2.fromOffset(64,64),BorderSizePixel=0,ZIndex=10,AutoButtonColor=true},nil) -- R156: a wheel option (HudLayout.Navigation sizes it)", 'Daily: button')
lines = D.split('\n')
a = next(i for i, l in enumerate(lines) if l.startswith('local function mount()'))
b = next(i for i, l in enumerate(lines) if l.startswith('task.defer(mount)'))
assert a < b and b - a < 14, 'Daily: mount block moved'
lines[a:b + 1] = ["-- R156 (owner): DAILY and INVITE are options of the menu wheel (slots 4 and 5), no longer squares next to BASE / TRACK in the top bar row.",
                  "local Hud=require(RS.HudLayout);dailyButton.Parent=gui;inviteButton.Parent=gui;Hud.Navigation(dailyButton,4);Hud.Navigation(inviteButton,5) -- (Navigation reparents each into its option frame)"]
D = '\n'.join(lines)
D = rep(D, ''' -- (the DAILY button sits 4 px under the top of the screen, which cuts off whatever hangs past it: R153's 30 px badge sits inside the corner, Overhang.Daily)
 local b=Badge.Make(dailyButton,'RewardBadge',Badge.Sizes.Daily,Badge.Overhang.Daily,false,Badge.OverhangTop and Badge.OverhangTop.Daily);local before=b.Visible and tonumber(b.Count.Text)or 0
 Badge.Set(b,Badge.Text(n),n>0,n>before)
''', ''' -- R156: the DAILY button is a wheel option now, so its badge sits on the top-right corner exactly like the INDEX badge (Sizes.Count / Overhang.Count): the wheel's CanvasGroup keeps
 -- NotifyBadge151.Margin round the button, nothing is above it any more. Sizes.Daily / Overhang.Daily / OverhangTop.Daily are not used.
 local b=Badge.Make(dailyButton,'RewardBadge',Badge.Sizes.Count,Badge.Overhang.Count);local before=b.Visible and tonumber(b.Count.Text)or 0
 Badge.Set(b,Badge.Text(n),n>0,n>before)
 pg:SetAttribute('MenuAlertDaily',n) -- the MENU button's "!" while the wheel is closed (HudLayout)
''', 'Daily: badge')
open(os.path.join(OUT, 'DailyRewardsClient.client.lua'), 'w', encoding='utf-8').write(D)

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
# ChestIndex: the hub badge is HudLayout's
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------
C = read('StarterPlayer', 'StarterPlayerScripts', 'ChestIndex.client.lua')
C = rep(C, ''' local nav=pg:FindFirstChild('GardenNavigation');local hub=nav and nav:FindFirstChild('MenuButton')
 if hub then Badge.Set(Badge.Make(hub,'IndexRewardAlert',Badge.Sizes.Alert,Badge.Overhang.Alert),'!',total>0,grew)end
''', ''' pg:SetAttribute('MenuAlertIndex',total) -- R156: HudLayout draws the MENU button's "!" for the Index and DAILY rewards together
''', 'ChestIndex: hub alert')
open(os.path.join(OUT, 'ChestIndex.client.lua'), 'w', encoding='utf-8').write(C)
print('variant written to', OUT)
