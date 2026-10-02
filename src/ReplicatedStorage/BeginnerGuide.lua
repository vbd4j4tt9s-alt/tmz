-- R111: five short steps that end right after planting, then quick tips. Simple words (about grade 3).
-- The guide is the game owner's avatar (the client picks it). Game name: Steal A Pack.
local G={Version=1,Bits={Begin=1,Pack=2,Seed=4,Train=8,Plant=16,Harvest=32,Sell=64,Cash=128}}
-- Optional: set a Roblox user id here to force whose avatar guides players (nil = the game's owner).
G.GuideUserId=nil
-- Name on the guide's tag (nil = that account's username).
G.GuideName='TMZ'
-- {name}, {Steal}, {Tap}, {Use} are filled per device.
G.Steps={
 {Text="Hi {name}! 👋 Follow the red arrows. {Steal} a seed pack!",Target='Pack',Marker='STEAL!'},
 {Text="You got it! 😆 Run home fast. Don't get caught!",Target='Safety',Marker='HOME'},
 {Text="{Tap} your pack to open it! 🎁",Equipped="{Use} to open it! 🎁"},
 {Text="You got a seed! 🌱 Plant it in your garden.",Target='Garden',Marker='PLANT HERE'},
 {Text="",Tips=true,Informational=true},
}
-- Step 5 shows these one at a time, then the tutorial is done. No waiting for the plant to grow.
G.Tips={
 "Your plant grows by itself, even when you're offline! 🌱",
 "Pick the fruit when it is ready. 🍎",
 "Sell fruit at the market for cash! 💰",
 "{TapBase} at the top to zoom home! 🏠",
 "{TapTrack} to zoom back to the track! 🏃",
 "Get faster to steal better packs! 🏃",
}
-- R125 (owner): the BASE / TRACK top-bar buttons are taught. Tip index -> the button the tutorial highlights.
G.TipButtons={[4]='BaseButton',[5]='TrackButton'}
-- Step 1 while the player is not on the track yet (presentation only; saved progress is unchanged).
G.TravelTrack="{TapTrack} at the top to zoom to the track! 🏃"
G.TipSeconds=3.5
G.Steps[5].Seconds=#G.Tips*G.TipSeconds
G.Welcome={Title='Welcome to Steal A Pack!',Text="Hi {name}! 👋 Let's steal your first seed pack!",Button="LET'S GO!"}
G.Waiting="No packs right now. One comes soon! ⏳"
G.Finished="You're ready, {name}! Have fun! 🎉"
function G.Copy(spec,key)return spec[key]end
G.StepCount=#G.Steps
local words={
 Touch={Steal='Hold STEAL to grab',Tap='Tap',Use='Tap',TapTrack='Tap TRACK',TapBase='Tap BASE'},
 Gamepad={Steal='Hold X to steal',Tap='Pick',Use='Press R2',TapTrack='Select TRACK',TapBase='Select BASE'},
 Mouse={Steal='Hold E to steal',Tap='Click',Use='Click',TapTrack='Click TRACK',TapBase='Click BASE'},
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
-- Harvest/Sell/Cash still record progress but no longer hold the tutorial open.
local order={{'Pack',1},{'Seed',3},{'Plant',4},{'Train',5}}
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
 if action=='TreadmillInfo'and G.Step(state)==5 then state.Mask=bit32.bor(state.Mask,G.Bits.Train);state.Done=true;return true end
 if action=='Replay'then state.Mask=1;state.Done=false;return true end
 if action=='Skip'then state.Done=true;return true end
 return false
end
function G.Layout(w,h,step)
 local width=math.min(304,math.max(190,w-112));local compact=w<700
 return {X=w-width-12,Y=h<480 and 116 or 76,Width=width,Height=step==9 and(compact and 68 or 56)or(compact and 50 or 46),Font=compact and 17 or 20}
end
-- Screen boxes the tutorial card must never cover (mirrors how each HUD script positions itself).
-- The default camera keeps the character in the middle of the screen, head near the centre, feet below it,
-- so that area is reserved too: the card must never hide the player or the start of the arrow trail.
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
 -- relaxed 1 lets the card reach the head (small phones); relaxed 2 drops the reservation (tiniest screens).
 local half=math.max(50,h*.09);local from=relaxed==1 and h*.5 or h*.42
 if relaxed~=2 then boxes[#boxes+1]={X=w/2-half,Y=from,W=half*2,H=h*.8-from,Character=true}end
 return boxes
end
function G.Font(m,w,h)return m.Phone and((h<400 or w<400)and 16 or 17)or(h<560 and 18 or 21)end
-- Objective card at the top centre (where Roblox players look for goals). It slides down, narrows or
-- shifts until it clears every HUD box and the character. heightFor(width) gives the card height at a width.
function G.Card(w,h,m,heightFor,relaxed,top)
 local boxes=G.Obstacles(m,w,h,relaxed);top=math.max(8,top or 8)
 local widest=math.min(m.Phone and 460 or 540,w-24)
 local tallest=math.max(150,heightFor(widest)*1.6)
 local function clear(box)
  if box.X<8 or box.Y<8 or box.X+box.W>w-8 or box.Y+box.H>h-8 then return false end
  for _,b in ipairs(boxes)do if box.X<b.X+b.W+6 and box.X+box.W>b.X-6 and box.Y<b.Y+b.H+6 and box.Y+box.H>b.Y-6 then return false end end
  return true
 end
 local afterHub=relaxed and 8 or m.MenuX+m.MenuSize+10
 for y=top,h*.6,6 do
  for width=widest,math.min(widest,220),-20 do
   local height=heightFor(width)
   if height>tallest then break end
   for _,x in ipairs({w/2-width/2,afterHub,w-8-width})do
    local box={X=x,Y=y,W=width,H=height}
    if clear(box)then return {X=x+width/2,Top=y,Width=width,Height=height,Clear=true}end
   end
  end
 end
 return {X=w/2,Top=top,Width=widest,Height=heightFor(widest),Clear=false}
end
return G
