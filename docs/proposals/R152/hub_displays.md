# R152 hub displays: a pedestal, a spinning showcase and a dancing giant

Owner feedback on R151's BEST PULL TODAY / BIGGEST FRUIT TODAY (back corners of the hub): the big black billboard on two posts, the grey slab with yellow trim, a normal-size avatar on a small pink disc and
a flat yellow glow disc BEHIND the seed were too much. "Make sure that the avatar is sized up and dancing while the seed rotates around and the effects are actually on the seed not behind ... a billboard
is not needed ... this follows the same format and look as the fruit of the hour type pedestal."

Picture: `hub_displays.png` (a champion and an empty display, wide from Base 4's / Base 3's spawn, close up, a three-quarter view of the pedestal, a scale view with a normal 5.3 stud player, a plan).
It is an approximate three.js render of the real built scene (the real `HubDisplayService` on the owner's place file, run on the Roblox mock): plain materials, no Roblox lighting, the avatar is the mock's
stand-in rig in ONE frame of a dance, the sparkles are a frozen frame. `docs/proposals/R151/preview/run_hub_preview.sh <scratch dir> [node_modules with three] [place.rbxl]` makes it again.

## What a display is now

- **The pedestal**: the market's Fruit of the Hour pedestal (`MarketLayout.Pedestal`: stone plinth with a gold trim and four studs, teal column with its inlays, gold band, stone capital, gold-deep top,
  four gold prongs; same shapes, same palette), built **3.2 times bigger**: plinth 19.8 studs wide, the capital 15.9 and the prong tips 20.8 studs up. 17 static parts, 4 of them solid. Copied, not called:
  `MarketLayout` is another agent's file, and the Fruit of the Hour's translucent projector tube (and its flat neon cradle glow) are left out.
- **The showcase**: the winning seed / fruit (the game's own art, about 12 studs, at most 150 parts) floats over the prongs and **turns slowly** (client side, `HubDisplayClient`: one BulkMoveTo about 20 times a
  second, 12 on phones' middle tier, only within 260 studs and when reduced motion is off). **Its effects are on it**: an invisible `ItemCore` part inside the item holds a PointLight in the champion's colour
  (server), and the client puts the sparkle emitter on that same core while it is near, so light and sparkles turn and bob with the seed. The halo disc and the lit rings are gone; an empty BEST PULL is calm
  (a black mystery seed, light off, no sparkles).
- **The words**, small, in the Fruit of the Hour's own format: a dark plaque with gold lettering on the pedestal column (title, winner, rarity and chance or the fruit of the day, the countdown) and a
  floating label over the item (title, winner, seed or weight), `HubDisplayRules.Plaque / Label / SignText`. No board.
- **The avatar**: the winner's own avatar, **25 studs tall (about 4.7 times a normal one)** with `Model:ScaleTo`, standing on the floor beside the pedestal, **dancing**: `HubDisplayAvatar:Animate` plays one of Roblox's
  default R15 dance emotes (`rbxassetid://507771019` / `507771955` / `507772104`, one per user id) looped on the rig's Animator once the rig is in the world. If that cannot happen (the dance does not load within
  5 s, does not play, the Animator throws) the avatar gets R151's static pose instead (and the client's small cheer); a blocky stand-in and the empty state's black silhouette stay static, at the same giant size.
  The client only pauses a dancing avatar (track speed 0) with reduced motion or the lowest quality tier.
- Gone: the sign board, its posts, crown and frame, the stage slab, apron and step, the avatar's plinth, the halo, the item's old R150 podium, the ring on a new champion.

## Where and how big

Centres unchanged: BEST PULL (236, 4, -516), BIGGEST FRUIT (-236, 4, -516), turned to the market. The stand is a 72 x 48 stud footprint (pedestal on the viewer's left, the dancing avatar's reach on the right);
it is inside `HubDecorKit151.K.Reserved` (x 145 .. 335, z -618 .. -420) with 70+ studs to the walls, the bases and the fences, and nothing overlaps the map. Height: the label ends 42 studs up (the walls
are 48). Parts: 17 pedestal + at most 150 item + about 22 avatar (BEST PULL 17 + 46 + 22 with the Fire Pepper, BIGGEST FRUIT 17 + 13 + 22), against 53 + 45 + 22 before.

## Tests (docs/proposals/R151/tests, `run_hub_displays.sh`)

No board / posts / slab / halo / disc / tube (names, shapes, translucency); the pedestal matches `MarketLayout.Pedestal` part by part at 3.2 times; no z-fighting (an in-suite face-by-face check on the pedestal, with
a checker that is shown to find a planted flicker, and the R149 detector on the finished hub); the avatar is 22 to 28 studs and `ScaleTo` about 4.7; a dance track plays (looped, one of the three ids, Animator
made when missing, falls back to the pose when it never loads / does not play / throws, the pose is not applied on top of a dance, started only after the avatar is in the display, a dance that is overtaken is dropped);
the item turns about its vertical axis and floats; the sparkles and the light are parented to the item's core; the stand is inside the reserved corner. 56 mutations (broken copies of src) are each caught.

## Doubts

- The dance cannot be played in this environment (the mock has an Animator that only records the track): the Animator path, the ids and `EvaluateStateMachine` being left on while dancing are written from the
  Roblox documentation and need one look in Studio. If a dance does not play, the avatar shows the static pose and the `hubdisplays` line says `pose`.
- The plaque is small by design (the Fruit of the Hour's format, 3.2 times bigger); the label over the item is what reads from the whole hub (it is drawn up to 420 studs, the plaque 300).
- A very tall hat on a champion adds to the 25 studs (the height is measured on the body); the label has 5 studs to spare under the walls.
