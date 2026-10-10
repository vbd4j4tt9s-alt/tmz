-- R111: short steps, then done. R133: casual voice. R138: big icon, a few words, one key chip. R152: one idea per step, it moves on by itself.
-- R158e (owner: "also for tutorial we have to shorten it even more just make it so that there is a red arrow that points players towards the pack when they spawn, after that it
-- tells players to click on the track tp button, then after that they steal, then it tells them to click via the visual mouse indicator. then tp back to base using the tp button and
-- then after that it tells them to plant and after that make sure that the first fruit is always 10 seconds growth time after that it tells them to harvest and sell, and it ends with
-- letting them know the treadmill makes them run faster and every 6 mins gives them a bonus roll for more packs. EVERYTHING that i have described must be visual so no words all just
-- arrows and pointing"): ten steps, one at a time, each moves on by itself the moment you do it. NOTHING the tutorial shows is a word: big icons, red arrows (a 3D one in the world,
-- one at the screen edge, one at a screen button), rings, pressing hands, the R138 clicking hand, key glyphs drawn as key caps (E, X, R2: the only letters, as icons) and the
-- numbers of a timer. The steps, their looks and the saved-progress rules live here (pure, shared by BeginnerTutorial on the client and TutorialProgress / TutorialTargets on the server).
local G={Version=1,Bits={Begin=1,Pack=2,Seed=4,Train=8,Plant=16,Harvest=32,Sell=64,Cash=128}}
-- Optional: set a Roblox user id here to force whose avatar guides players (nil = the game's owner). The face only: no name tag (R158e: no words).
G.GuideUserId=nil
-- The ten steps, in order. The step row on the card shows one icon per step.
G.Steps={
 {Name='Spawn',Icon='🎯',Seconds=4},     -- 1 you spawn: a big red 3D arrow points at the pack to go get (for Seconds, then step 2)
 {Name='Track',Icon='🏃'},                -- 2 the TRACK teleport button (red arrow + pulsing ring + pressing hand on it)
 {Name='Steal',Icon='🎒'},                -- 3 the pack: red arrow over it + your steal key; carrying it: the arrow points home
 {Name='Open',Icon='🎁'},                 -- 4 the R138 clicking hand on the pack in your hand (its hotbar slot first)
 {Name='Base',Icon='🏠'},                 -- 5 the BASE teleport button
 {Name='Plant',Icon='🌱'},                -- 6 red arrow on your dirt + the pressing hand
 {Name='Grow',Icon='⏳'},                 -- 7 the first fruit grows in 10 s (a ring timer over the plant)
 {Name='Harvest',Icon='🍎'},              -- 8 red arrow on the ripe fruit + your pick key
 {Name='Sell',Icon='💰'},                 -- 9 the market (red arrow), then its Sell crops / Sell all buttons
 {Name='Treadmill',Icon='⚡',Seconds=10}, -- 10 the treadmill: you run faster + every 6 min a bonus roll (more packs); done on it, or after Seconds
}
G.StepCount=#G.Steps
G.Progress={};for i,step in ipairs(G.Steps)do G.Progress[i]=step.Icon end
-- One look per moment. Row = the picture line on the card, tiles left to right (Rows = two lines). A tile is an emoji, or:
--   {Act='Steal'|'Prompt'|'Open'|'Plant'|'Press'}: your device's glyph for it (G.Devices: a key cap E / X / R2, or 🖱️ / 👆 / 🎮); Hold=true rings it (hold it)
--   {Pill='Track'|'Base'}: the button's colour, no caption;  {Timer=true}: the seconds left (step 7);  {Clock=true}: the bonus-roll time (TreadmillBonusRules, 6:00)
-- World = the server target it points at (TutorialTargets Kind); Arrow3D = the big red 3D arrow; Trail = the red chevrons on the ground; Prompt = your key in a bubble over the goal
-- (Hold = it fills: hold it; PromptNear = only that close; else Marker, or the step icon, in a bubble); Hand = the pressing 👇 on the dirt; Timer = the ring timer over the plant; Button = the screen button it points at (a red arrow,
-- a pulsing ring and a pressing hand; NoPress = no hand: just look); Slot = the hotbar slot it rings ('Pack' / 'Seed'); Click = the R138 clicking hand by the pack in your hand.
G.Looks={
 Spawn={Step=1,Icon='🎯',Row={'🏃','➜','🎒'},World='Pack',Marker='🎒',Arrow3D=true,Trail=true},
 Track={Step=2,Icon='🏃',Row={{Act='Press'},'➜',{Pill='Track'}},World='Pack',Marker='🎒',Arrow3D=true,Button='TrackButton'},
 Grab={Step=3,Icon='🎒',Row={{Act='Steal',Hold=true},'➜','🎒'},World='Pack',Marker='🎒',Arrow3D=true,Trail=true,Prompt='Steal',Hold=true},
 Waiting={Step=3,Icon='⏳',Row={'🎒','⏳'}},
 Carry={Step=3,Icon='🏠',Row={'🎒','➜','🏠'},World='Safety',Arrow3D=true,Trail=true},
 PickPack={Step=4,Icon='🎁',Row={{Act='Press'},'➜','🎁'},Slot='Pack'},
 Open={Step=4,Icon='🎁',Row={{Act='Open'},'➜','🎁'},Click=true},
 Base={Step=5,Icon='🏠',Row={{Act='Press'},'➜',{Pill='Base'}},Button='BaseButton'},
 PickSeed={Step=6,Icon='🌱',Row={{Act='Press'},'➜','🌱'},Slot='Seed'},
 Plant={Step=6,Icon='🌱',Row={{Act='Plant'},'➜','🟫'},World='Garden',Arrow3D=true,Trail=true,Hand=true},
 Grow={Step=7,Icon='⏳',Row={'🌱','⏱️',{Timer=true}},World='Crop',Arrow3D=true,Trail=true,Timer=true},
 Harvest={Step=8,Icon='🍎',Row={{Act='Prompt'},'➜','🍎'},World='Crop',Arrow3D=true,Trail=true,Prompt='Prompt'},
 Market={Step=9,Icon='💰',Row={'🍎','➜','💰'},World='Sell',Arrow3D=true,Trail=true,Prompt='Prompt',PromptNear=18},
 SellTab={Step=9,Icon='💰',Row={{Act='Press'},'➜','💰'},Button='SellMode'},
 SellAll={Step=9,Icon='💰',Row={{Act='Press'},'➜','💵'},Button='SellAll'},
 Treadmill={Step=10,Icon='⚡',Rows={{'🏃','➜','⚡','⬆️'},{'🕒',{Clock=true},'➜','🎁'}},World='Treadmill',Arrow3D=true,Trail=true,Button='BonusRollButton',NoPress=true},
}
for key,look in pairs(G.Looks)do look.Key=key end
-- The pop between steps (a green ✓, no row) and the end (🏆 + 🎁 when the free pack comes, 🎉 otherwise; confetti).
G.Nice={Key='Nice',Icon='✓'}
G.Finished={Key='Finished',Icon='🏆',Row={'🎁'}};G.FinishedAgain={Key='FinishedAgain',Icon='🏆',Row={'🎉'}}
G.IntroSeconds=G.Steps[1].Seconds;G.NiceSeconds=.7;G.RevealSeconds=2.5;G.FinishSeconds=4
-- Your device's glyph for each action: a key cap (a key glyph drawn as an icon) or an emoji. The prompts (steal, pick, the market) are E / X; a pack opens and seeds are planted
-- with a click / tap / R2; a screen button is clicked / tapped / selected.
G.Devices={
 Mouse={Steal={Key='E'},Prompt={Key='E'},Open='🖱️',Plant='🖱️',Press='🖱️'},
 Touch={Steal='👆',Prompt='👆',Open='👆',Plant='👆',Press='👆'},
 Gamepad={Steal={Key='X'},Prompt={Key='X'},Open={Key='R2'},Plant={Key='R2'},Press='🎮'},
}
G.KeyGlyphs={E=true,X=true,R2=true} -- the only letters the tutorial ever draws, each alone in a key cap
function G.Act(device,act)local set=G.Devices[device]or G.Devices.Mouse;return set[act]end
-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack"): the hand by the pack in your hand (R158e: no word; a gamepad shows its R2 key cap).
G.ClickHint={Mouse={Hand='🖱️'},Touch={Hand='👆'},Gamepad={Hand='🎮',Key='R2'}}
-- R138 (owner): finishing the tutorial gives one free Forest pack with 2x rates (server: TutorialProgress.GrantStarterPack). R139: named, announced and priced like any Forest pack.
-- (The notice is the game's own toast after the tutorial, not a tutorial word.)
G.StarterPack={Name='Seed Pack',Notice='🎁 FREE Forest pack!! check your Bag'}
-- R158e: the first fruit of the plant planted in the tutorial grows in this many seconds (once per player; TutorialProgress.TutorialFastCrop, server only).
G.FirstFruitSeconds=10
G.NearArrow=30   -- the 3D arrow hovers over a goal closer than this (studs); farther away it floats in front of you, pointing the way
G.HomeMargin=10  -- studs around your base pad that still count as home (steps 5 - 10)
-- Fills the {name} placeholder (kept for older callers; R158e has no words to fill). The name is escaped because a label may use RichText.
function G.Format(text,device,name)
 local safe=tostring(name or'friend'):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
 return(tostring(text):gsub('{(%a+)}',function(key)
  if key=='name'then return'<font color="#FFE047">'..safe..'</font>'end
  return'{'..key..'}'
 end))
end
function G.Plain(text)return(tostring(text):gsub('<[^>]->',''):gsub('&lt;','<'):gsub('&gt;','>'):gsub('&amp;','&'))end
-- R158e: a text the tutorial shows has no word in it: no letter at all, or exactly one key glyph (E / X / R2) in a key cap.
function G.Wordless(text,keyCap)
 text=G.Plain(text or'')
 if keyCap and G.KeyGlyphs[text]then return true end
 return text:find('%a')==nil
end
-- The bonus-roll interval as a clock (360 -> 6:00): numbers only.
function G.Clock(seconds)
 seconds=math.max(0,math.floor(tonumber(seconds)or 0));return string.format('%d:%02d',math.floor(seconds/60),seconds%60)
end

-- Saved progress -------------------------------------------------------------------------------------------------------------------------------------------------------------
-- The save is {Version=1, Mask, Done} as since R111 (the same bits), plus two OPTIONAL fields (R158e; an older server drops them, ProfileVersion stays 22):
--   Fast = true once the 10-second first fruit was given (once per player, ever);  FastCrop = that plant's id (the grow / harvest steps point at it).
-- Only a pack stolen on the track ticks the steal step (a gift or any other grant never does); after it, opening ANY pack counts (owner: "the player can open ANY pack and it will
-- count"), and planting any seed counts.
-- The published TutorialStep is the first step the saved bits have not done: 1 (steal: the client shows 1, 2 or 3 by where you are), 4 (open: 4), 6 (plant: 5 or 6 by
-- where you are), 7 (grow / harvest: 7 or 8 by the fruit), 9 (sell), 10 (treadmill), 0 = done. Old saves land there too: an R152 player who had planted goes on at 7.
local order={{'Pack',1},{'Seed',4},{'Plant',6},{'Harvest',7},{'Sell',9},{'Train',10}}
-- R158e: an event counts only in its turn (a pack opened, a seed planted or a fruit picked or sold before its step is just playing): the bits it needs first.
G.Needs={Seed=2,Plant=6,Harvest=22,Sell=54}
function G.CleanId(v)return type(v)=='string'and #v>=1 and #v<=100 and v or nil end
function G.Read(saved)
 if type(saved)~='table'then return {Version=1,Mask=1,Done=false}end
 local mask=saved.Mask
 if saved.Version~=1 or type(mask)~='number'or mask%1~=0 or mask<0 or mask>255 or type(saved.Done)~='boolean'then return nil end
 return {Version=1,Mask=bit32.bor(mask,1),Done=saved.Done,Fast=saved.Fast==true or nil,FastCrop=G.CleanId(saved.FastCrop)}
end
function G.Step(state)
 if state.Done then return 0 end
 for _,row in ipairs(order)do if bit32.band(state.Mask,G.Bits[row[1]])==0 then return row[2]end end
 return 0
end
function G.Event(state,event)
 if event=='Train'then return false end -- (the client sends TreadmillInfo: step 10 is about seeing the treadmill, not 3 s on it)
 local bit=G.Bits[event];if not bit or state.Done or bit32.band(state.Mask,bit)~=0 then return false end
 if event=='Cash'and bit32.band(state.Mask,G.Bits.Sell)==0 then return false end
 local need=G.Needs[event];if need and bit32.band(state.Mask,need)~=need then return false end
 state.Mask=bit32.bor(state.Mask,bit)
 if G.Step(state)==0 then state.Done=true end
 return true
end
-- TreadmillInfo: step 10 is done (the client sends it when you step on the treadmill or after its Seconds). Skip ends it. Replay: plain data (TutorialProgress refuses it, R158c).
function G.Action(state,action)
 if action=='TreadmillInfo'and G.Step(state)==10 then state.Mask=bit32.bor(state.Mask,G.Bits.Train);state.Done=true;return true end
 if action=='Replay'then state.Mask=1;state.Done=false;return true end
 if action=='Skip'then state.Done=true;return true end
 return false
end
-- What the server points at for a published step (carrying = holding a stolen pack): the TutorialTargets Kind.
function G.Kind(stage,carrying)
 if stage==1 then return carrying and'Safety'or'Pack'end
 return({[6]='Garden',[7]='Crop',[9]='Sell',[10]='Treadmill'})[stage]
end
-- The step and look you see now (pure; BeginnerTutorial passes what it sees): c = {Stage, Carrying, OnTrack (true / false / nil), IntroDone, Waiting, Home, PackInHand, SeedInHand,
-- Ripe, Menu ('Buy' / 'Sell' / nil: the market window)}. Returns step number, look key; 0, nil when there is nothing to show.
function G.Resolve(c)
 local s=c.Stage
 if s==1 then
  if c.Carrying then return 3,'Carry'end
  if c.OnTrack==true then return 3,c.Waiting and'Waiting'or'Grab'end
  if not c.IntroDone then return 1,'Spawn'end
  return 2,'Track'
 elseif s==4 then return 4,c.PackInHand and'Open'or'PickPack'
 elseif s==6 then
  if not c.Home then return 5,'Base'end
  return 6,c.SeedInHand and'Plant'or'PickSeed'
 elseif s==7 then
  if not c.Home then return 7,'Base'end
  return(c.Ripe and 8 or 7),(c.Ripe and'Harvest'or'Grow')
 elseif s==9 then
  if c.Menu=='Sell'then return 9,'SellAll'end
  if c.Menu=='Buy'then return 9,'SellTab'end
  return 9,'Market'
 elseif s==10 then
  if not c.Home then return 10,'Base'end
  return 10,'Treadmill'
 end
 return 0,nil
end
-- R158e: the first fruit in 10 s (the server calls this for ONE plant: the one planted in the tutorial's plant step, once per player; see
-- TutorialProgress.TutorialFastCrop). Only the first fruit: the plant grows up in 10 s and fruit 1 is ripe then; a plant with more fruit grows the others in their normal time (they
-- regrow from the planting, as after a harvest: cycle 1, Duration), and every later harvest / regrow follows the normal rules. Returns true when it changed the crop.
function G.FastFruit(crop,def,now)
 if type(crop)~='table'or type(def)~='table'or type(now)~='number'or type(crop.MatureAt)~='number'then return false end
 local fast=now+G.FirstFruitSeconds
 if crop.MatureAt<=fast then return false end -- (already that quick)
 local normal=math.max(crop.MatureAt,tonumber(crop.ReadyAt)or crop.MatureAt)
 crop.MatureAt=fast;crop.ReadyAt=fast
 local count=math.max(1,math.floor(tonumber(def.FruitCount)or 1))
 if count>1 and def.Mode~='whole'and def.Regrows~=false then
  local states={}
  for i=1,count do states[tostring(i)]=i==1 and{ReadyAt=fast,Cycle=0}or{ReadyAt=normal,Cycle=1,Duration=math.clamp(normal-now,1,86400)}end
  crop.FruitStates=states
 end
 return true
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
