-- R122: shovel holes on the biome track. One table for every limit, timing and look (server + client read it).
-- Dig: equip the Shovel on the track and click / tap / press R2 on the ground. Only seed-pack CARRIERS fall in.
-- A hole slot frees when: it traps a carrier, its owner covers it (use the shovel on your own hole), it expires
-- (LifetimeSeconds), the track refreshes, or its owner leaves the server. A 5th dig is refused, never replaces one.
return {
 -- Size (R153: 1.5x the radius, was 3.4 / .3 / 9). The trap circle IS the visible dark circle (the root must be over it); the server
 -- tests the whole path of a step against it (TrackHoleService.Cross), so a carrier is caught at any speed. KeyboardTrack.Config.HoleReach
 -- (3) must stay >= Diameter/2 + RimWidth: the keys under the rim stay up.
 Diameter=5.1,           -- studs, dark pit circle
 RimWidth=.45,           -- lighter-brown ring around the pit (visual only; never traps)
 CrumbCount=12,          -- loose dirt cubes scattered around the rim

 -- Limits (anti-grief)
 CooldownSeconds=3,      -- per player, between two digs (covering is not a dig). R124: 8 -> 3
 MaxPerPlayer=4,         -- active holes per player; the 5th dig is refused
 MaxPerServer=30,        -- active holes in the whole server
 LifetimeSeconds=180,    -- a hole closes by itself after 3 minutes
 ArmSeconds=1,           -- a fresh hole cannot trap anyone for this long
 RemoteRoute='TrackHole',-- SecurityGate budget (Rate 2/s, Burst 4)

 -- Trap
 RagdollSeconds=4,       -- a trapped carrier lies on the ground this long, then recovers normally
 FallHorizontal=8,       -- small stumble forward (studs/s) - a fall, not a launch
 FallVertical=4,
 TrapHeightMin=-1.5,     -- root height above the hole surface that counts as "standing on it" (R153: anywhere along the swept path)
 TrapHeightMax=7,        -- (a high jump clears it)
 TutorialSafeSteps={[1]=true,[2]=true}, -- tutorial players on these steps never fall in

 -- Where you may dig
 DigRange=12,            -- max flat distance from your root to the aimed spot (else you dig at your feet)
 CoverSnap=1,            -- aiming within (pit radius + this) of YOUR hole covers it instead of digging
 MinSpacing=8,           -- center to center between any two holes (R153: 6 -> 8, the same 2-stud gap between two rims)
 PackClearance=10,       -- from pack spawn pads and dropped packs
 KeeperCampClearance=18, -- from each keeper's home camp
 EntranceClearance=12,   -- past the track entrance / refresh wall line
 SurfaceTolerance=.6,    -- walkable top surface must be this close to the biome ground (thin overlays ok)

 Messages={
  Cooldown='%ds',          -- R124: only the time left
  Carrying="CAN'T DIG WITH A PACK!",
  Refreshing='TRACK IS REFRESHING',
  Ground='ONLY DIG ON THE TRACK!',
  Pack='TOO CLOSE TO A PACK',
  Camp='TOO CLOSE TO A KEEPER CAMP',
  Entrance='TOO CLOSE TO THE ENTRANCE',
  Spacing='TOO CLOSE TO ANOTHER HOLE',
  PlayerCap='%d HOLES MAX! COVER ONE OR WAIT',
  ServerCap='TOO MANY HOLES ON THE TRACK',
  Covered='HOLE COVERED',
  Trapped='U FELL IN A HOLE! PACK DROPPED',
  Tripped='%s FELL IN YOUR HOLE!',
 },
 -- R124: a short tip when the shovel comes out, then it fades (replaces the permanent hint line). R153 (owner): the shovel also removes plants,
 -- so the tip says both; it shows wherever the shovel is pulled out (garden or track), the first HintTimes pull-outs of a session.
 Hint='🕳️ dig holes on the track to trap players • tap a plant in ur garden to remove it', -- R125 (owner): 'players', not 'pack thieves'
 HintSeconds=5,
 HintTimes=3,          -- pull-outs per session that show it (then never again until the next join)
 HintRepeatSeconds=8,  -- a pull-out while the last tip is still on screen shows nothing and is not counted

 -- Dig / cover sound: one long recording with several digs, played as short variants (see DigSoundVariants and
 -- docs/proposals/holes_R122/DIG_SOUND.md). Variant source, first match wins:
 --  1. attribute DigSegments on this ModuleScript (JSON, written by the Studio tool DigSoundAnalyzer),
 --  2. Segments below ({Start=seconds,Length=seconds}, paste the tool's printout),
 --  3. fallback: the loaded sound's TimeLength split into FallbackVariants equal windows.
 DigSound={
  Id='rbxassetid://93793180254708',
  Volume=.5,PitchMin=.93,PitchMax=1.07, -- random pitch per play; never the same variant twice in a row
  CoverPitch=.86,                       -- covering a hole plays a variant a little lower
  RollOffMin=12,RollOffMax=150,         -- positional at the hole; nearby players hear it
  FallbackVariants=6,MaxLength=1.2,     -- fallback split; every variant is cut to at most MaxLength seconds
  LoadGrace=.5,                         -- skip a play whose sound took longer than this to load (stale)
  Attribute='DigSegments',
  Segments={},
  -- Studio analyzer defaults (DigSoundAnalyzer.Run(options) overrides any of these)
  Analyzer={Use='Peak',Threshold=nil,Sensitivity=.3,QuietGap=.12,Preroll=.03,Tail=.06,MinLength=.08,MaxLength=1.2},
 },
}
