-- R110: larger menu wheel and hotbar slots on every screen; phones keep five slots when they fit.
local L={}
local function overlaps(a,b,pad)
 pad=pad or 0
 return a.X<b.X+b.W+pad and a.X+a.W>b.X-pad and a.Y<b.Y+b.H+pad and a.Y+a.H>b.Y-pad
end
-- R113: BASE/TRACK travel pair. First candidate that clears every HUD box by 6px wins; a spot to the
-- right of the hub is only used with Travel.UnderWheel=true (the pair hides while the wheel is open).
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
local function travel(m,w,h)
 local hubY=h/2+(m.MenuShiftY or 0)-m.MenuSize/2;local gap=8
 local near={L.HudBoxes(m,w,h,true),L.HudBoxes(m,w,h,false)}
 local function clear(x,y,bw,bh,boxes)
  if x<8 or y<8 or x+bw>w-8 or y+bh>h-8 then return false end
  for _,b in ipairs(boxes)do if overlaps({X=x,Y=y,W=bw,H=bh},b,6)then return false end end
  return true
 end
 for _,size in ipairs({m.Phone and 52 or 56,48,44})do
  local below=hubY+m.MenuSize+10
  local spots={{m.MenuX,below,true,false},{m.MenuX+(m.MenuSize-size)/2,below,false,false},
   {m.MenuX+m.MenuSize+10,hubY+(m.MenuSize-size)/2,true,true},{m.MenuX+m.MenuSize+10,hubY+m.MenuSize/2-size-gap/2,false,true}}
  for _,s in ipairs(spots)do
   local bw=s[3]and size*2+gap or size;local bh=s[3]and size or size*2+gap
   if clear(s[1],s[2],bw,bh,near[s[4]and 2 or 1])then
    return {X=s[1],Y=s[2],W=bw,H=bh,Size=size,Gap=gap,Horizontal=s[3],UnderWheel=s[4]}
   end
  end
 end
 return nil
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
 local menuSize=h<280 and 52 or 64;local menuHalf=menuSize/2;local menuClear=menuHalf+8
 local center=math.max(menuClear,math.min(h/2,walletY-10-menuHalf))
 local radius=math.max(0,math.min(menuSize==64 and 102 or 86,center-menuClear))
 local radiusX=radius<72 and 178 or radius
 local offsets={{X=0,Y=-radius},{X=radiusX/math.sqrt(2),Y=-radius/math.sqrt(2)},{X=radiusX,Y=0}}
 local details={X=bar.X,Y=bar.Y-44,W=bar.W,H=44};local showDetails=true
 for _,b in ipairs({status,{X=walletX,Y=walletY,W=walletW,H=walletStack},{X=10,Y=center-menuHalf,W=menuSize,H=menuSize}})do if overlaps(details,b,4)then showDetails=false end end
 local jumpZone={X=jump.X-6,Y=jump.Y-6,W=jump.W+12,H=jump.H+12}
 local m={Phone=true,PhoneWide=true,PhonePortrait=false,Slots=slots,SlotSize=side,HotbarBottom=hotbarBottom,HotbarShiftX=0,HotbarDetails=showDetails,
  NavSize=menuSize,NavWidth=menuSize,NavGap=6,NavX=10,NavY=center-menuHalf,NavHorizontal=false,
  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=menuSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  WalletWidth=walletW,WalletHeight=rowH,WalletX=walletX,WalletPlus=math.floor(rowH*.75),WalletIcon=rowH-2,WalletFont=math.floor(rowH*.8),
  WalletHorizontal=false,WalletCompactTap=false,WalletPassive=true,
  SpeedX=walletX,CashX=walletX,GemX=walletX,SpeedY=walletY,CashY=walletY+rowH+rowGap,GemY=walletY+(rowH+rowGap)*2,
  Short=h<480,Compact=true,StatusScale=statusScale,StatusCorner='BottomRight',StatusRight=12,StatusBottom=statusBottom,StatusPlain=true,
  StatusBox=status,StatusStacked=false,StatusHorizontal=false,StatusSideRight=0,
  HideOwnerTools=true,OwnerToolsSize=48,OwnerToolsX=10,OwnerToolsY=8,
  ThumbZones={jumpZone},Joystick=stick,Jump=jump}
 m.Travel=travel(m,w,h);return m
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
 local center=math.max(menuClear,math.min(h/2,(portrait and bar.Y or left.Y)-menuClear))
 local radius=math.max(0,math.min(menuSize==64 and 102 or 86,center-menuClear))
 local radiusX=radius<72 and 178 or menuSize==64 and 102 or 86
 local offsets={{X=0,Y=-radius},{X=radiusX/math.sqrt(2),Y=-radius/math.sqrt(2)},{X=radiusX,Y=0}}
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
 local hub={X=10,Y=center-menuHalf,W=menuSize,H=menuSize}
 local details={X=bar.X,Y=bar.Y-44,W=bar.W,H=44}
 local showDetails=not(overlaps(details,wallet,4)or overlaps(details,status,4)or overlaps(details,hub,4)or overlaps(details,left,4)or overlaps(details,right,4))
 for _,o in ipairs(offsets)do
  if overlaps(details,{X=10+o.X,Y=center-menuHalf+o.Y,W=menuSize,H=menuSize},4)then showDetails=false end
 end
 local m={Phone=true,PhonePortrait=portrait,Slots=slots,SlotSize=side,HotbarBottom=hotbarBottom,HotbarShiftX=barCenter-w/2,HotbarDetails=showDetails,
  NavSize=menuSize,NavWidth=menuSize,NavGap=6,NavX=10,NavY=center-menuHalf,NavHorizontal=false,
  WalletWidth=walletW,WalletHeight=walletHeight,WalletX=walletX,WalletPlus=44,WalletIcon=horizontal and 22 or 26,WalletFont=20,
  WalletHorizontal=horizontal,WalletCompactTap=horizontal,
  SpeedX=walletX,CashX=walletX+(horizontal and walletW+6 or 0),GemX=walletX+(horizontal and (walletW+6)*2 or 0),
  SpeedY=walletY,CashY=walletY+(horizontal and 0 or walletHeight+walletGap),GemY=walletY+(horizontal and 0 or (walletHeight+walletGap)*2),
  MenuSize=menuSize,MenuX=10,MenuShiftY=center-h/2,MenuOptionSize=menuSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,
  Short=h<480,Compact=true,StatusScale=statusScale,StatusTop=8,StatusBottom=h-8-timerHeight,StatusStacked=false,StatusHorizontal=statusHorizontal,StatusSideRight=math.min(0,statusWidth/statusScale-walletW/statusScale)-10,
  HideOwnerTools=true,OwnerToolsSize=48,OwnerToolsX=10,OwnerToolsY=8,
  ThumbZones={left,right}}
 m.Travel=travel(m,w,h);return m
end
function L.Read(view,touch,controls)
 local w,h=math.max(240,view.X),math.max(150,view.Y)
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
 local radius=math.min(hubSize==64 and 102 or 84,h/2-optionSize/2-(h<212 and 4 or 8))
 -- Exceptionally short canvases widen the upper arc; targets never shrink below44px.
 local radiusX=radius<76 and math.min(178,w-10-(hubSize-optionSize)/2-optionSize-6)or radius
 local offsets={{X=0,Y=-radius},{X=radiusX/math.sqrt(2),Y=-radius/math.sqrt(2)},{X=radiusX,Y=0}}
 local boxes={{X=10,Y=(h-hubSize)/2,W=hubSize,H=hubSize},
  {X=w-12-statusWidth*statusScale,Y=h-bottom-statusHeight*statusScale,W=statusWidth*statusScale,H=statusHeight*statusScale},
  -- Owner Tools uses this top-left tile while the wheel is closed.
  {X=10,Y=8,W=48,H=48},
  {X=(w-barWidth)/2,Y=h-hotbarBottom-side,W=barWidth,H=side}}
 for _,at in ipairs(offsets)do boxes[#boxes+1]={X=10+(hubSize-optionSize)/2+at.X,Y=(h-optionSize)/2+at.Y,W=optionSize,H=optionSize}end
 local function fits(x,y,width,height)
  if x<0 or y<0 or x+width>w or y+height>h-bottom+.01 then return false end
  for _,box in ipairs(boxes)do if x<box.X+box.W+4 and x+width>box.X-4 and y<box.Y+box.H+4 and y+height>box.Y-4 then return false end end
  return true
 end
 if not fits(walletX,speedY,walletW,walletStack)then
  local sideX=10+(hubSize-optionSize)/2+radiusX+optionSize+12
  local placed=false
  for _,height in ipairs({walletH,math.max(20,math.min(walletH,24)),20})do
   local spacing=height==walletH and gap or 2;local stack=height*3+spacing*2
   for _,at in ipairs({{sideX,h-bottom-stack},{12,h-bottom-stack},{70,8},{sideX,8}})do
    if fits(at[1],at[2],walletW,stack)then walletX,speedY,walletH,gap,walletStack=at[1],at[2],height,spacing,stack;placed=true;break end
   end
   if placed then break end
  end
 end
 cashY=speedY+walletH+gap;gemY=cashY+walletH+gap

 local m={Slots=slots,SlotSize=side,HotbarBottom=hotbarBottom,NavSize=nav,NavWidth=navWidth,NavGap=navGap,NavX=10,NavY=navY,NavHorizontal=short,
  WalletWidth=walletW,WalletHeight=walletH,WalletX=walletX,MenuSize=hubSize,MenuX=10,MenuOptionSize=optionSize,MenuOffsets=offsets,MenuRadius=radius,MenuRadiusX=radiusX,SpeedY=speedY,CashY=cashY,GemY=gemY,Short=short,Compact=compact,
  StatusScale=statusScale,StatusBottom=bottom,StatusStacked=stacked,OwnerToolsSize=ownerSize,OwnerToolsY=ownerY}
 m.Travel=travel(m,w,h);return m
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
local function menuPixels(value,size)return math.floor(value*size/48+.5)end
local function styleOption(button,size)
 local captionHeight=menuPixels(14,size);local captionFont=menuPixels(9,size)
 button.AnchorPoint=Vector2.zero;button.Position=UDim2.fromOffset(4,4);button.Size=UDim2.fromOffset(size,size)
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
  return UDim2.new(0,m.MenuX+(m.MenuSize-m.MenuOptionSize)/2-4+(opened and x or 0),.5,(m.MenuShiftY or 0)-m.MenuOptionSize/2-4+(opened and y or 0))
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
 end
 local function layout(m)
  if state.Dead then return end;state.Metrics=m
  hub.AnchorPoint=Vector2.zero;hub.Position=UDim2.new(0,m.MenuX,.5,(m.MenuShiftY or 0)-m.MenuSize/2);hub.Size=UDim2.fromOffset(m.MenuSize,m.MenuSize)
  local size=m.MenuSize;local captionHeight=menuPixels(14,size)
  glyph.Position=UDim2.new(.5,0,0,menuPixels(18,size));glyph.Size=UDim2.fromOffset(menuPixels(22,size),menuPixels(22,size))
  for i=0,3 do local tile=glyph:FindFirstChild('Tile'..i);tile.Size=UDim2.fromOffset(menuPixels(8,size),menuPixels(8,size));tile.Position=UDim2.fromOffset(menuPixels(i%2*14,size),menuPixels(math.floor(i/2)*14,size))end
  caption.Position=UDim2.new(0,0,1,-captionHeight);caption.Size=UDim2.new(1,0,0,captionHeight);caption.TextSize=menuPixels(10,size)
  require(script.Parent.GardenTextFit).Attach(caption,menuPixels(10,size),menuPixels(9,size))
  for _,entry in pairs(state.Entries)do entry.Group.Size=UDim2.fromOffset(m.MenuOptionSize+8,m.MenuOptionSize+8);styleOption(entry.Button,m.MenuOptionSize)end
  state:SetOpen(state.Open,true)
 end
 state.StopLayout=L.Watch(gui,layout)
 state.Connections[#state.Connections+1]=hub.Activated:Connect(function()if state.Dead or not hub.Active or pg:GetAttribute('SeedMenu')~=nil then return end;require(script.Parent.InteractionAudio).Play(state.Open and'MenuClose'or'MenuClick');state:SetOpen(not state.Open,false)end) -- R150: closing the wheel is MenuClose, like every other close
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
 assert(index>=1 and index<=3 and index%1==0,'Invalid navigation slot')
 local owner=assert(button:FindFirstAncestorOfClass('ScreenGui'),'Navigation needs a ScreenGui');local pg=owner.Parent
 owner.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
 if not navigation or navigation.Dead or navigation.Gui.Parent~=pg then navigation=createNavigation(pg)end
 local state=navigation;local previous=state.Entries[index]
 if previous and previous.Button==button then return previous.Remove end
 if previous then previous.Remove(true)end
 local group=Instance.new('CanvasGroup');group.Name='MenuOption'..index;group.BackgroundTransparency=1;group.Size=UDim2.fromOffset(state.Metrics.MenuOptionSize+8,state.Metrics.MenuOptionSize+8);group.GroupTransparency=1;group.Visible=false;group.ZIndex=2;group.Parent=state.Gui
 local entry={Index=index,Button=button,Group=group,Connections={},Tweens={}};state.Entries[index]=entry;button:SetAttribute('ButtonSound',false);button.Parent=group
 function entry.Remove(replacing)
  if entry.Removed then return end;entry.Removed=true
  if entry.Completed then entry.Completed:Disconnect();entry.Completed=nil end
  for _,tween in ipairs(entry.Tweens)do tween:Cancel()end
  for _,connection in ipairs(entry.Connections)do connection:Disconnect()end
  if state.Entries[index]==entry then state.Entries[index]=nil end
  group:Destroy()
  if not replacing and not state.Dead and not next(state.Entries)then state.Gui:Destroy()end
 end
 entry.Connections[1]=owner.Destroying:Connect(function()entry.Remove()end)
 entry.Connections[2]=button.Destroying:Connect(function()entry.Remove()end)
 entry.Connections[3]=button.Activated:Connect(function()if state.Open then require(script.Parent.InteractionAudio).Play('MenuClick');state:SetOpen(false,true)end end)
 styleOption(button,state.Metrics.MenuOptionSize);state:SetOpen(state.Open,true)
 return entry.Remove
end
return L
