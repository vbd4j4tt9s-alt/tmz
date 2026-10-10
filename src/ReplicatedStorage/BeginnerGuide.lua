-- R111: short steps, then done. R133: casual voice. R138: big icon, a few words, one key chip.
-- R152 (owner: "make tutorial understandable in 5 seconds for new players see player know instantly", every text "like how I
-- talk"): one idea per step, a big icon, a title of at most 4 words + a chip of at most 3, the key / button for your device,
-- and a beam + ring + path (or a pressing hand) on the exact thing. Steps move on by themselves; no welcome page, no slides.
-- The guide is the game owner's avatar (the client picks it). Game name: Steal A Pack.
local G={Version=1,Bits={Begin=1,Pack=2,Seed=4,Train=8,Plant=16,Harvest=32,Sell=64,Cash=128}}
-- Optional: set a Roblox user id here to force whose avatar guides players (nil = the game's owner).
G.GuideUserId=nil
-- Name on the guide's tag (nil = that account's username).
G.GuideName='TMZ'
-- One look = {Icon, Title, Chip={Key, KeyStyle, Arrow, Label}}. {name} and the device words below are filled per device.
-- Target = what the server points the beam at (TutorialTargets); Marker = the icon over it; Hand = a pressing hand on it.
G.Steps={
 {Icon='🎒',Title='GRAB A PACK!',Chip={Key='{StealKey}',Label='{HoldIt}'},Target='Pack',Marker='🎒'},
 {Icon='🏠',Title='RUN HOME!!',Chip={Arrow=true,Label='to your base'},Target='Safety',Marker='🏠'},
 {Icon='🎁',Title='OPEN IT!',Chip={Key='{PickKey}',Label='your pack'},Pick='Pack',
  EquippedTitle='KEEP {OpenVerb}!!',EquippedChip={Key='{OpenKey}',Label='open it'}},
 {Icon='🌱',Title='PLANT IT!',Chip={Key='{PlantKey}',Label='the dirt'},Target='Garden',Hand=true,Home=true},
 -- R152: step 5 is the treadmill (it was 3 tip slides): done when you step on it, or after Seconds anyway.
 {Icon='⚡',Title='GET FASTER!',Chip={Arrow=true,Label='hop on it'},Target='Treadmill',Marker='⚡',Home=true,Seconds=40},
}
G.StepCount=#G.Steps
-- Step 1 while you're off the track: the TRACK button (ringed, with a pressing hand) and a path to the track gate.
G.TravelTrack={Icon='🏃',Title='GO TO THE TRACK!',Chip={Key='TRACK',KeyStyle='Track',Label='{TapIt}'},Button='TrackButton',Marker='🏃'}
-- Steps 4-5 (Home=true) while you're on the track: the BASE button.
G.TravelBase={Icon='🏠',Title='GO HOME!',Chip={Key='BASE',KeyStyle='Base',Label='{TapIt}'},Button='BaseButton'}
-- Step 4 while the seed is not in your hand: its hotbar slot.
G.PickSeed={Icon='🌱',Title='PLANT IT!',Chip={Key='{PickKey}',Label='your seed'}}
G.Waiting={Icon='⏳',Title='PACKS COMING!',Chip={Label='hang tight'}}
-- The tiny pop between steps.
G.Nice={Icon='✓',Title='NICE!!'}
G.NiceSeconds=.7;G.RevealSeconds=2.5;G.FinishSeconds=4
G.Finished={Icon='🏆',Title='YOU GOT THIS!!',Chip={Label='🎁 FREE PACK!'}}
G.FinishedAgain={Label='have fun {name}!'} -- the chip when the free pack was already given (a replay)
-- R138 (owner): finishing the tutorial gives one free Forest pack with 2x rates (server: TutorialProgress.GrantStarterPack).
-- R139 (owner: "make it so that players dont know that the pack is 2x luck"): it is named, announced and shows its odds
-- exactly like any Forest pack; only the server knows.
G.StarterPack={Name='Seed Pack',Notice='🎁 FREE Forest pack!! check your Bag'}
-- The step row on the card: one icon per step.
G.Progress={'🎒','🏠','🎁','🌱','⚡'}
-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack").
G.ClickHint={Mouse={Hand='🖱️',Word='CLICK!'},Touch={Hand='👆',Word='TAP!'},Gamepad={Hand='🎮',Word='R2!'}}
-- On-screen word budget (tested): title <= 4 words, chip label <= 3, both together <= 6.
G.MaxTitleWords,G.MaxChipWords,G.MaxWords=4,3,6
function G.Copy(spec,key)return spec[key]end
local words={
 Touch={StealKey='👆',HoldIt='hold it',PickKey='TAP',OpenKey='TAP',OpenVerb='TAPPING',PlantKey='TAP',TapIt='tap it'},
 Gamepad={StealKey='X',HoldIt='hold',PickKey='R1',OpenKey='R2',OpenVerb='PRESSING',PlantKey='R2',TapIt='select it'},
 Mouse={StealKey='E',HoldIt='hold',PickKey='CLICK',OpenKey='CLICK',OpenVerb='CLICKING',PlantKey='CLICK',TapIt='click it'},
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
function G.Words(text)local n=0;for _ in G.Plain(text or''):gmatch('%S+')do n+=1 end;return n end
-- Saved progress (unchanged since R111): Harvest/Sell/Cash still record progress but no longer hold the tutorial open.
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
-- TreadmillInfo: step 5 is done (R152: the client sends it when you step on the treadmill).
function G.Action(state,action)
 if action=='TreadmillInfo'and G.Step(state)==5 then state.Mask=bit32.bor(state.Mask,G.Bits.Train);state.Done=true;return true end
 if action=='Replay'then state.Mask=1;state.Done=false;return true end
 if action=='Skip'then state.Done=true;return true end
 return false
end
-- R157: how far above the hotbar's slots its stack reaches: the held item's name rows sit above the pity bars now (HudLayout.NameRows: 71 - 77 px; R155: 44 px, the rows
-- right over the slots); 0 where this screen hides the rows (the bars alone, which dim under the card, as in R155).
-- R158: m as HudLayout.Read gives it; a computer's HUD is laid out in HUD px and drawn at m.Scale, so the rows are measured on the laid-out window (m.VH) and the answer, in screen px, is
-- times the scale (1 on a phone and on a window of 1920 x 720 or more: unchanged).
function G.HotbarDetail(m,h)
 if m.HotbarDetails==false then return 0 end
 local s=m.Scale or 1;if s~=1 then h=m.VH end
 local ok,rows=pcall(function()
  local Hud=require(script.Parent.HudLayout);local side=m.SlotSize
  return Hud.NameRows({X=0,Y=0,W=(m.Slots+1)*side+m.Slots*6,H=side},m.Phone==true,h)
 end)
 return(ok and type(rows)=='table'and math.max(44,math.ceil(-rows.Y))or 44)*s
end
-- (the layout in screen px: a computer's scaled layout as HudLayout.Real gives it, a phone's as it is)
local function real(m)
 local ok,Hud=pcall(function()return require(script.Parent.HudLayout)end)
 return ok and type(Hud)=='table'and Hud.Real and Hud.Real(m)or m
end
-- Screen boxes the tutorial card must never cover (mirrors how each HUD script positions itself).
-- The default camera keeps the character in the middle of the screen, head near the centre, feet below it,
-- so that area is reserved too: the card must never hide the player or the start of the arrow trail.
function G.Obstacles(m,w,h,relaxed)
 local layout=m;m=real(m) -- (R158: the boxes are in screen px; HotbarDetail takes the layout as it came)
 local boxes={};local shift=m.MenuShiftY or 0
 if m.PhoneWide then
  -- R129: landscape phones: MENU button, both corners, hotbar and the jump button.
  if not relaxed then boxes[#boxes+1]={X=m.MenuX,Y=h/2+shift-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}end
  local barWidth=(m.Slots+1)*m.SlotSize+m.Slots*(m.SlotGap or 6);local barY=h-m.HotbarBottom-m.SlotSize;local detail=G.HotbarDetail(layout,h)
  boxes[#boxes+1]={X=w/2+(m.HotbarShiftX or 0)-barWidth/2,Y=barY-detail,W=barWidth,H=m.SlotSize+detail}
  for _,k in ipairs({'Speed','Cash','Gem'})do boxes[#boxes+1]={X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight}end
  boxes[#boxes+1]={X=m.StatusBox.X,Y=m.StatusBox.Y,W=m.StatusBox.W,H=m.StatusBox.H}
  for _,z in ipairs(m.ThumbZones or{})do boxes[#boxes+1]={X=z.X,Y=z.Y,W=z.W,H=z.H}end
  local half=math.max(50,h*.09);local from=relaxed==1 and h*.5 or h*.42
  if relaxed~=2 then boxes[#boxes+1]={X=w/2-half,Y=from,W=half*2,H=h*.8-from,Character=true}end
  return boxes
 end
 -- Relaxed: the menu button draws above the tutorial (DisplayOrder 33 vs 25), so it may sit over the card edge.
 if not relaxed then boxes[#boxes+1]={X=m.MenuX,Y=h/2+shift-m.MenuSize/2,W=m.MenuSize,H=m.MenuSize}end
 -- The open menu wheel is not listed: the card hides while the wheel is open.
 local barWidth=(m.Slots+1)*m.SlotSize+m.Slots*(m.SlotGap or 6);local barY=h-m.HotbarBottom-m.SlotSize;local detail=G.HotbarDetail(layout,h)
 boxes[#boxes+1]={X=w/2+(m.HotbarShiftX or 0)-barWidth/2,Y=barY-detail,W=barWidth,H=m.SlotSize+detail}
 for _,k in ipairs({'Speed','Cash','Gem'})do boxes[#boxes+1]={X=m[k..'X']or m.WalletX,Y=m[k..'Y'],W=m.WalletWidth,H=m.WalletHeight}end
 if m.Phone then
  local sw=(m.StatusHorizontal and 388 or 190)*m.StatusScale;local sh=(m.StatusHorizontal and 39 or 82)*m.StatusScale
  boxes[#boxes+1]={X=w-12-sw,Y=8,W=sw,H=sh}
  for _,z in ipairs(m.ThumbZones or{})do boxes[#boxes+1]={X=z.X,Y=z.Y,W=z.W,H=z.H}end
 else
  local sw=(m.StatusStacked and 190 or 337)*m.StatusScale;local sh=(m.StatusStacked and 211 or 125)*m.StatusScale
  boxes[#boxes+1]={X=w-(m.StatusRight or 12)-sw,Y=h-m.StatusBottom-sh,W=sw,H=sh}
 end
 -- relaxed 1 lets the card reach the head (small phones); relaxed 2 drops the reservation (tiniest screens).
 local half=math.max(50,h*.09);local from=relaxed==1 and h*.5 or h*.42
 if relaxed~=2 then boxes[#boxes+1]={X=w/2-half,Y=from,W=half*2,H=h*.8-from,Character=true}end
 return boxes
end
function G.Font(m,w,h)return m.Phone and((h<400 or w<400)and 16 or 17)or(h<560 and 18 or 21)end
-- Objective card at the top centre (where Roblox players look for goals). It slides down, narrows or
-- shifts until it clears every HUD box and the character. heightFor(width) gives the card height at a width.
-- R152: top = where to start looking (below a ringed top-bar button); want = the width its words need (it hugs them).
function G.Card(w,h,m,heightFor,relaxed,top,want)
 local boxes=G.Obstacles(m,w,h,relaxed);top=math.max(8,top or 8)
 m=real(m)
 local widest=math.min(want or 9999,m.Phone and 460 or 540,w-24)
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
