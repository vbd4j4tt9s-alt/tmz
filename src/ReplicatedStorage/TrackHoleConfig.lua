-- R122: shovel holes on the biome track. One table for every limit, timing and look (server + client read it).
-- Dig: equip the Shovel on the track and click / tap / press R2 on the ground. Only seed-pack CARRIERS fall in.
-- A hole slot frees when: it traps a carrier, its owner covers it (use the shovel on your own hole), it expires
-- (LifetimeSeconds), the track refreshes, or its owner leaves the server. A 5th dig is refused, never replaces one.
return {
 -- Size: "one player big". The trap circle IS the visible dark circle (the root must be over it).
 Diameter=3.4,           -- studs, dark pit circle
 RimWidth=.3,            -- lighter-brown ring around the pit (visual only; never traps)
 CrumbCount=9,           -- loose dirt cubes scattered around the rim

 -- Limits (anti-grief)
 CooldownSeconds=8,      -- per player, between two digs (covering is not a dig)
 MaxPerPlayer=4,         -- active holes per player; the 5th dig is refused
 MaxPerServer=30,        -- active holes in the whole server
 LifetimeSeconds=180,    -- a hole closes by itself after 3 minutes
 ArmSeconds=1,           -- a fresh hole cannot trap anyone for this long
 RemoteRoute='TrackHole',-- SecurityGate budget (Rate 2/s, Burst 4)

 -- Trap
 RagdollSeconds=4,       -- a trapped carrier lies on the ground this long, then recovers normally
 FallHorizontal=8,       -- small stumble forward (studs/s) - a fall, not a launch
 FallVertical=4,
 TrapHeightMin=-1.5,     -- root height above the hole surface that counts as "standing on it"
 TrapHeightMax=7,        -- (a high jump clears it)
 TutorialSafeSteps={[1]=true,[2]=true}, -- tutorial players on these steps never fall in

 -- Where you may dig
 DigRange=12,            -- max flat distance from your root to the aimed spot (else you dig at your feet)
 CoverSnap=1,            -- aiming within (pit radius + this) of YOUR hole covers it instead of digging
 MinSpacing=6,           -- center to center between any two holes
 PackClearance=10,       -- from pack spawn pads and dropped packs
 KeeperCampClearance=18, -- from each keeper's home camp
 EntranceClearance=12,   -- past the track entrance / refresh wall line
 SurfaceTolerance=.6,    -- walkable top surface must be this close to the biome ground (thin overlays ok)

 Messages={
  Cooldown='SHOVEL READY IN %dS',
  Carrying="CAN'T DIG WHILE CARRYING A PACK",
  Refreshing='TRACK IS REFRESHING',
  Ground='DIG ON THE TRACK GROUND',
  Pack='TOO CLOSE TO A PACK',
  Camp='TOO CLOSE TO A KEEPER CAMP',
  Entrance='TOO CLOSE TO THE ENTRANCE',
  Spacing='TOO CLOSE TO ANOTHER HOLE',
  PlayerCap='%d HOLES MAX - COVER ONE OR WAIT FOR A TRAP',
  ServerCap='TOO MANY HOLES ON THE TRACK',
  Covered='HOLE COVERED',
  Trapped='YOU FELL IN A HOLE! PACK DROPPED',
  Tripped='%s FELL IN YOUR HOLE!',
 },
 Hint='Dig holes on the track: thieves carrying a pack fall in',
}
