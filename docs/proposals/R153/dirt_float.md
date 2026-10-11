# R153 dirt float: the shovel holes that climbed into the sky

Owner: *"fix the bug where dirt piles would float up into the sky"* (a live R152 screenshot from the keyboard track, looking back at the hub: dark pits with brown crumbs hang over the
hub paths and the pastel lanes), then *"dirt piles as in the dugged holes"*.

## What the dirt was

The shovel holes (`TrackHoleService._build`): a dark pit (46,29,17), a lighter rim and 9 (R152) / 12 (R153) crumb cubes in three browns. Nothing else in the game builds that look
(the hub's soil is (104,74,52), the planting pile has no pit). In the screenshot the pits are 35 px wide for a 3.4 + .3 stud hole: they are about as near the camera as the first
keys, hanging some 40 studs above the track start, not on the hub ground 100 studs away. The crumbs over the pastel lanes (no pit among them) are crumbs of the same kind.

## Root cause

`KeyboardTrack.client.lua` lifts every hole part onto the key tops (the real floor is hidden, the keys stand 1.2 over it). It remembered "this part was lifted" in two weak
tables keyed by the **Instance** (`liftBase` / `liftSet`) and lifted with `d.Position = d.Position + LIFT` on every 4 Hz scan of the hole folder. Roblox gives a script a **new wrapper**
for an Instance it let go of, so a table keyed by the wrapper forgets the part and the next scan lifts it again: +1.26 studs per scan, ~5 studs a second, for the 180 s a hole lives.
Crumbs and pit are forgotten at different moments, so they climb separately (crumbs without their pit, as in the screenshot).

Evidence (the code is what a stable-identity mock cannot show):
* Reading every writer of a hole part's height: the server builds it once; `TrackHoleClient.grow` tweens a crumb to the frame it captured and a pit's size; the dirt burst parts are
  Debris'd; the only code that can move a part up without limit is that relative lift.
* On the mock with stable identity nothing climbs: 6,000 random events (digs, covers, parts and models streaming in again, teleports, tier changes, recycles) kept the highest part at 5.45.
* With every hole part a script gets from the folder re-wrapped (`GetChildren` / `GetDescendants` / `FindFirstChild` / `DescendantAdded`), the R152 code, with the real `TrackHoleClient` dig
  animation on a time-stepped tween, climbs: Y 5.4 at the dig, 10.3 after 1 s, 24.2 after 4 s, 43 after 8 s (the screenshot's ~40 studs), 62 after 12 s, 124 after 25 s, through a 450-row run
  (rows recycled), a return and teleports. The same run on the fixed code stays at 5.29 .. 5.43 (one lift) throughout.
That the live engine really drops the wrapper cannot be proven offline; the fix does not depend on it (below), and it covers any other way the memory could be lost.

## The fix

* `KeyboardTrack.client.lua`: the lift is **absolute and recorded on the part**: attribute `KbHoleBase` (client-local) = the part's height before the lift; every write is `record + HoleLift`.
  No table keyed by an Instance. A part with no record that already stands at or above the resting key top is never lifted (second net). A part more than `HoleCeiling` (1 stud, new in
  `KeyboardTrack.Config`) over the key tops is stranded in the air and goes back (to its record, or where the server heights plus the lift put it). Writes only when a height is wrong
  (R152 write-on-change: a hole at rest is never written to). Teardown restores the exact server height from the records. Models whose Pit has not streamed in are scanned too.
* `TrackHoleService`: `Sweep()` removes any `TrackHole_<id>` model no live hole owns, at every `ClearAll` (refresh) and every `SweepSeconds` (5); `_remove` destroys the model even if it lost
  its parent.
* `TrackHoleClient`: every dirt chunk in flight is listed; any that outlives its toss by 2 s (a tween or Debris that never finished) is destroyed.
* Hub trees and decor: checked, nothing there moves after it is built and nothing uses this look; unchanged.

## Client review findings on the same code (docs/proposals/R153/bug_review_client.md, 1, 2 and 4)

1. **Pit floating over a pressed key.** A hole 10 .. 14 studs from a small pack shares a key with the pack's platform; the platform held it down, the hole's pit floated 1.21 studs over the dip.
   The **hole wins**: `rebuildClearances` leaves keys under a hole out of the platform's held-down set (spacebars already did). Client side, so it holds for any pack size and any order of events.
2. **Crumbs hanging over a key that goes down.** The crumbs lie up to 4.1 studs from the centre, past `HoleReach` 3 (about 28% of holes). `HoleReach` 3 -> **4.6** = rim 3.0 + the crumb ring
   (`TrackHoleConfig.CrumbSpread` 1.1, new) + `CrumbSizeMax` (.5, new): the keys under every crumb stay up. The server draws the same crumbs (same ranges, now from the config).
3. **Landings of other players did not click.** Their feet are 1.2 .. 3 studs up for a frame or two on the way down: the key went down silently, the landing found it down. A runner who is
   not thrown and a little above the floor is now kind 5 (silent, remembered per key); when that same runner really steps on the key it clicks once. Flung / ragdolled bodies stay silent.

## Tests

* Keyboard suite (`R149/tests/test_keyboard.luau`, 687 checks): section 8b (the climb with re-wrapped instances, the real `TrackHoleClient`, 20 s + recycles + teleports; record lost; stranded dirt;
  write-on-change; a streamed-in rim), crumbs at the largest server radius (8 directions x 5 places on the grid), hole + platform sharing a key (9 offsets), another player's landing (10 start
  heights; a flung body stays silent). 8b fails on the R152 code with the Y at 163 after the run. `run_keyboard.sh` bundles `TrackHoleClient` and has 8 new mutations (10 of 10 hole mutations caught).
* Holes suite (`holes_R122/tests`): crumbs of 300 real `_build` holes inside the reach, orphan sweep (live holes and foreign objects stay, refresh clear, heartbeat, expiry); client: dirt that
  outlives its toss is removed.
* Also run, unchanged and passing: the R152 z-fight sweep, perf152 (look and sound identical), the load guard (73 client scripts, BackgroundMusic untouched).
