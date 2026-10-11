-- R111: short steps, then done. R133: casual voice. R138: big icon, a few words, one key chip. R152: one idea per step, it moves on by itself.
-- R158e (owner: "also for tutorial we have to shorten it even more just make it so that there is a red arrow that points players towards the pack when they spawn, after that it
-- tells players to click on the track tp button, then after that they steal, then it tells them to click via the visual mouse indicator. then tp back to base using the tp button and
-- then after that it tells them to plant and after that make sure that the first fruit is always 10 seconds growth time after that it tells them to harvest and sell, and it ends with
-- letting them know the treadmill makes them run faster and every 6 mins gives them a bonus roll for more packs. EVERYTHING that i have described must be visual so no words all just
-- arrows and pointing"): ten steps, one at a time, each moves on by itself the moment you do it.
-- R158g (owner: "remove the box at the top from the tutorial entirely, and the big red arrow should only be used when necessary ... The tutorial should really just be arrows and that's
-- all"; "it's not that we can't have 2 arrows at a moment, but each arrow has to fulfil 1 purpose, not 2 fulfilling the same purpose"; "there will be no skip tutorial button"): the
-- tutorial is ONLY pointers: a red arrow over the goal (near), the big floating red 3D arrow (only when the goal is far and the arrow itself is in sight: the way), a red arrow at the
-- screen edge (only when neither fits: the goal is behind you), a red arrow + a pressing hand on a screen button, the pressing hand on your dirt, the R138 clicking hand, and the small
-- ring timer over the first plant. No card, no icons, no pictures, no step dots, no pops, no confetti, no skip. The steps, their pointers and the saved-progress rules live here (pure,
-- shared by BeginnerTutorial on the client and TutorialProgress / TutorialTargets on the server).
local G={Version=1,Bits={Begin=1,Pack=2,Seed=4,Train=8,Plant=16,Harvest=32,Sell=64,Cash=128}}
-- The ten steps, in order.
G.Steps={
 {Name='Spawn',Seconds=4},     -- 1 you spawn: a red arrow points at the pack to go get (for Seconds, then step 2)
 {Name='Track'},                -- 2 the TRACK teleport button (a red arrow + the pressing hand on it)
 {Name='Steal'},                -- 3 the pack: a red arrow to it; carrying it: the arrow points home
 {Name='Open'},                 -- 4 the R138 clicking hand on the pack in your hand (its hotbar slot first)
 {Name='Base'},                 -- 5 the BASE teleport button
 {Name='Plant'},                -- 6 a red arrow on your dirt + the pressing hand
 {Name='Grow'},                 -- 7 the first fruit grows in 10 s (a small ring timer over the plant)
 {Name='Harvest'},              -- 8 a red arrow on the ripe fruit
 {Name='Sell'},                 -- 9 the market (a red arrow), then its Sell crops / Sell all buttons
 {Name='Treadmill',Seconds=10}, -- 10 your treadmill (a red arrow: you run faster; done on it, or after Seconds), then the BONUS ROLL button (a red arrow: a bonus roll every 6 min) for BonusSeconds
}
G.StepCount=#G.Steps
-- One look per moment, and what it points at. World = the server target a red arrow goes to (TutorialTargets Kind): near it the arrow hovers over it, far away the big 3D "that way"
-- arrow floats in front of you, and behind you the arrow sits at the screen edge (one of the three at a time: never two arrows for the one goal); Hand = the pressing 👇 on the dirt;
-- Timer = the small ring timer over the plant (the arrow does not hover there: the timer marks it); Button = the screen button it points at (a red arrow and a pressing hand; NoPress =
-- just the arrow); Slot = the hotbar slot it points at ('Pack' / 'Seed'); Click = the R138 clicking hand by the pack in your hand.
G.Looks={
 Spawn={Step=1,World='Pack'},
 Track={Step=2,Button='TrackButton'},
 Grab={Step=3,World='Pack'},
 Waiting={Step=3},
 Carry={Step=3,World='Safety'},
 PickPack={Step=4,Slot='Pack'},
 Open={Step=4,Click=true},
 Base={Step=5,Button='BaseButton'},
 PickSeed={Step=6,Slot='Seed'},
 Plant={Step=6,World='Garden',Hand=true},
 Grow={Step=7,World='Crop',Timer=true},
 Harvest={Step=8,World='Crop'},
 Market={Step=9,World='Sell'},
 SellTab={Step=9,Button='SellMode'},
 SellAll={Step=9,Button='SellAll'},
 Treadmill={Step=10,World='Treadmill'},
 Bonus={Step=10,Button='BonusRollButton',NoPress=true},
}
for key,look in pairs(G.Looks)do look.Key=key end
G.IntroSeconds=G.Steps[1].Seconds;G.RevealSeconds=2.5;G.BonusSeconds=5
-- The only letters the tutorial ever draws, each alone in a key cap (the clicking hand's R2 on a gamepad).
G.KeyGlyphs={R2=true}
-- R138 (owner: "a clicking indicator to visually show players to keep clicking to open a pack"): the hand by the pack in your hand (no word; a gamepad shows its R2 key cap).
G.ClickHint={Mouse={Hand='🖱️'},Touch={Hand='👆'},Gamepad={Hand='🎮',Key='R2'}}
-- R138 (owner): finishing the tutorial gives one free Forest pack with 2x rates (server: TutorialProgress.GrantStarterPack). R139: named, announced and priced like any Forest pack.
-- (The notice is the game's own toast after the tutorial, not a tutorial word.)
G.StarterPack={Name='Seed Pack',Notice='🎁 FREE Forest pack!! check your Bag'}
-- R158e: the first fruit of the plant planted in the tutorial grows in this many seconds (once per player; TutorialProgress.TutorialFastCrop, server only).
G.FirstFruitSeconds=10
G.NearArrow=30   -- the red arrow hovers over a goal closer than this (studs); farther away the big arrow floats in front of you, pointing the way
G.HomeMargin=10  -- studs around your base pad that still count as home (steps 5 - 10)
function G.Plain(text)return(tostring(text):gsub('<[^>]->',''):gsub('&lt;','<'):gsub('&gt;','>'):gsub('&amp;','&'))end
-- R158e: a text the tutorial shows has no word in it: no letter at all, or exactly one key glyph (R2) in a key cap.
function G.Wordless(text,keyCap)
 text=G.Plain(text or'')
 if keyCap and G.KeyGlyphs[text]then return true end
 return text:find('%a')==nil
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
-- TreadmillInfo: step 10 is done (the client sends it when its BONUS ROLL arrow has shown for BonusSeconds). R158g: there is no Skip (the owner: "there will be no skip tutorial button"; the server refuses a 'Skip' request, TutorialProgress). Replay: plain data (TutorialProgress refuses it, R158c).
function G.Action(state,action)
 if action=='TreadmillInfo'and G.Step(state)==10 then state.Mask=bit32.bor(state.Mask,G.Bits.Train);state.Done=true;return true end
 if action=='Replay'then state.Mask=1;state.Done=false;return true end
 return false
end
-- What the server points at for a published step (carrying = holding a stolen pack): the TutorialTargets Kind.
function G.Kind(stage,carrying)
 if stage==1 then return carrying and'Safety'or'Pack'end
 return({[6]='Garden',[7]='Crop',[9]='Sell',[10]='Treadmill'})[stage]
end
-- The step and look you see now (pure; BeginnerTutorial passes what it sees): c = {Stage, Carrying, OnTrack (true / false / nil), IntroDone, Waiting, Home, PackInHand, SeedInHand,
-- Ripe, Menu ('Buy' / 'Sell' / nil: the market window), Bonus (step 10: on to the BONUS ROLL button)}. Returns step number, look key; 0, nil when there is nothing to show.
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
  if c.Bonus then return 10,'Bonus'end
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
return G
