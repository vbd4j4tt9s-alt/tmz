-- R110: friendly guide copy, device wording and a card placement that never covers the HUD.
local G={Version=1,Bits={Begin=1,Pack=2,Seed=4,Train=8,Plant=16,Harvest=32,Sell=64,Cash=128}}
-- Sprout (the guide) talks to the player like a friend. {name}, {Tap}, {use}, {steal}, {Hover} are filled per device.
G.Steps={
 {Text="Hey {name}! 👋 I'm Sprout, your buddy. Follow the red arrows to a seed pack and {steal} it!",Target='Pack',Marker='STEAL!'},
 {Text="Yoink! 😆 Now RUN back to your base before the keeper catches you!",Target='Safety',Marker='SAFE ZONE'},
 {Text="Nice steal, {name}! {Tap} your pack in the hotbar to rip it open 🎁",Equipped="Ooh, shiny! {use} to rip it open 🎁"},
 {Text="A seed! 🌱 Follow the arrows to your garden and plant it in the dirt.",Target='Garden',Marker='YOUR GARDEN'},
 {Text="Now it grows... ⏳ Plants keep growing even while you go steal more packs!",Target='Garden',Marker='GROWING'},
 {Text="It's ready! 🍓 Go harvest your crop.",Target='Garden',Marker='HARVEST'},
 {Text="Take your crop to the market and cash in! 💰",Target='Market',Marker='MARKET'},
 {Text="{Hover} the cash to scoop it up. Ka-ching! 🤑"},
 {Text="Last tip: treadmills make you faster, and faster means rarer packs! Go get 'em, {name}! 🏃",Target='Treadmill',Marker='TREADMILL',Informational=true,Seconds=8},
}
G.Welcome={Title='Welcome to Chest Chase!',Text="Hey {name}! I'm Sprout 🌱 Steal seed packs, grow them, and get rich. I'll show you how. It only takes a minute!",Button="LET'S GO!"}
G.Waiting="All the nearby packs are taken. A fresh one pops up in a moment! ⏳"
G.Finished="You're all set, {name}! 🎉 Now go build the best garden ever!"
G.StepCount=#G.Steps
local words={
 Touch={Tap='Tap',use='Tap anywhere',steal='tap STEAL on',Hover='Tap'},
 Gamepad={Tap='Pick',use='Press R2',steal='press X to STEAL',Hover='Grab'},
 Mouse={Tap='Click',use='Click anywhere',steal='press E to STEAL',Hover='Hover over'},
}
-- Fills placeholders. The name is escaped because the label uses RichText.
function G.Format(text,device,name)
 local set=words[device]or words.Mouse
 local safe=tostring(name or'friend'):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
 return(tostring(text):gsub('{(%a+)}',function(key)
  if key=='name'then return'<font color="#FFE047">'..safe..'</font>'end
  return set[key]or('{'..key..'}')
 end))
end
function G.Plain(text)return(tostring(text):gsub('<[^>]->',''):gsub('&lt;','<'):gsub('&gt;','>'):gsub('&amp;','&'))end
local order={{'Pack',1},{'Seed',3},{'Plant',4},{'Harvest',5},{'Sell',7},{'Cash',8},{'Train',9}}
function G.Read(saved)
 if type(saved)~='table'then return {Version=1,Mask=1,Done=false}end
 local mask=saved.Mask
 if saved.Version~=1 or type(mask)~='number'or mask%1~=0 or mask<0 or mask>255 or type(saved.Done)~='boolean'then return nil end
 return {Version=1,Mask=bit32.bor(mask,1),Done=saved.Done}
end
function G.Step(state)
 if state.Done then return 0 end
 for _,row in ipairs(order)do if bit32.band(state.Mask,G.Bits[row[1]])==0 then return row[2]end end
 return 0
end
function G.Event(state,event)
 if event=='Train'then return false end
 local bit=G.Bits[event];if not bit or state.Done or bit32.band(state.Mask,bit)~=0 then return false end
 if event=='Cash'and bit32.band(state.Mask,G.Bits.Sell)==0 then return false end
 state.Mask=bit32.bor(state.Mask,bit)
 if G.Step(state)==0 then state.Done=true end
 return true
end
function G.Action(state,action)
 if action=='TreadmillInfo'and G.Step(state)==9 then state.Mask=bit32.bor(state.Mask,G.Bits.Train);state.Done=true;return true end
 if action=='Replay'then state.Mask=1;state.Done=false;return true end
 if action=='Skip'then state.Done=true;return true end
 return false
end
function G.Layout(w,h,step)
 local width=math.min(304,math.max(190,w-112));local compact=w<700
 return {X=w-width-12,Y=h<480 and 116 or 76,Width=width,Height=step==9 and(compact and 68 or 56)or(compact and 50 or 46),Font=compact and 17 or 20}
end
-- Screen boxes the tutorial card must never cover (mirrors how each HUD script positions itself).
function G.Obstacles(m,w,h,relaxed)
 local boxes={};local shift=m.MenuShiftY or 0
 -- Relaxed: the menu button draws above the tutorial (DisplayOrder 33 vs 25), so it may sit over the card edge.
 if not relaxed then boxes[#boxes+1]={X=m.MenuX,Y=h/2+shift-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}end
 -- The open menu wheel is not listed: the card hides while the wheel is open.
 local barWidth=(m.Slots+1)*m.SlotSize+m.Slots*6;local barY=h-m.HotbarBottom-m.SlotSize
 boxes[#boxes+1]={X=w/2+(m.HotbarShiftX or 0)-barWidth/2,Y=barY-(m.HotbarDetails~=false and 44 or 0),W=barWidth,H=m.SlotSize+(m.HotbarDetails~=false and 44 or 0)}
 for _,k in ipairs({'Speed','Cash','Gem'})do boxes[#boxes+1]={X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight}end
 if m.Phone then
  local sw=(m.StatusHorizontal and 388 or 190)*m.StatusScale;local sh=(m.StatusHorizontal and 39 or 82)*m.StatusScale
  boxes[#boxes+1]={X=w-12-sw,Y=8,W=sw,H=sh}
  for _,z in ipairs(m.ThumbZones or{})do boxes[#boxes+1]={X=z.X,Y=z.Y,W=z.W,H=z.H}end
 else
  local sw=(m.StatusStacked and 190 or 337)*m.StatusScale;local sh=(m.StatusStacked and 211 or 125)*m.StatusScale
  boxes[#boxes+1]={X=w-12-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh}
 end
 return boxes
end
function G.Font(m,w,h)return m.Phone and((h<400 or w<400)and 16 or 17)or(h<560 and 18 or 21)end
-- Bottom-centre card above the hotbar. Slides up and narrows until it clears every HUD box.
-- heightFor(width) returns the card height for that width (text wraps, so it depends on width).
function G.Card(w,h,m,heightFor,relaxed)
 local boxes=G.Obstacles(m,w,h,relaxed);local cx=w/2+(m.HotbarShiftX or 0)
 local start=h-m.HotbarBottom-m.SlotSize-(m.HotbarDetails~=false and 50 or 10)
 local widest=math.min(m.Phone and 460 or 540,w-24)
 local function clear(box)
  if box.X<8 or box.Y<8 or box.X+box.W>w-8 then return false end
  for _,b in ipairs(boxes)do if box.X<b.X+b.W+6 and box.X+box.W>b.X-6 and box.Y<b.Y+b.H+6 and box.Y+box.H>b.Y-6 then return false end end
  return true
 end
 local afterHub=relaxed and 8 or m.MenuX+m.MenuSize+10
 -- Never trade a low position for a tall, skinny card.
 local tallest=math.max(150,heightFor(widest)*1.6)
 for bottom=start,60,-6 do
  for width=widest,math.min(widest,220),-20 do
   local height=heightFor(width)
   if height>tallest then break end
   -- Centred on the hotbar first, then beside the menu button, then against the right edge.
   for _,x in ipairs({cx-width/2,afterHub,w-8-width})do
    local box={X=x,Y=bottom-height,W=width,H=height}
    if clear(box)then return {X=x+width/2,Bottom=bottom,Width=width,Height=height,Clear=true}end
   end
  end
 end
 return {X=w/2,Bottom=start,Width=widest,Height=heightFor(widest),Clear=false}
end
return G
