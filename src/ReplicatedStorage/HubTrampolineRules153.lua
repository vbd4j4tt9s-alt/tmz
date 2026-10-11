-- R153 hub trampolines: the numbers and the pure rules, shared by the server's builder (ChestChaseServer.HubTrampoline153) and the client
-- (HubTrampoline153.client). Owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit".
-- A trampoline fills each nook (the brick plazas at the ends of the two garden walks and of the back lane). ONE number sets the bounce:
-- BounceHeight, the studs the feet rise above the mat (ReplicatedStorage.HubTrampolineRules153's BounceHeight attribute overrides it in Studio).
-- How it moves players: the client that owns the character sets the vertical speed of its own HumanoidRootPart (the way RunnerController already
-- owns the horizontal speed, and keeps the vertical one); MovementGuard's 25-stud rise allowance per sample covers the launch (checked by the tests). A launch seen late (a network hitch) is covered by T.LaunchRise (below).
local T={Version=153}
T.BounceHeight=30      -- studs the feet rise above the mat: a bit (25 - 35); the apex is about 35 over the floor, over the lamps and the trees
T.MinHeight,T.MaxHeight=12,40 -- whatever the attribute says, the bounce stays inside these (never a sky launch)
T.Cooldown=.45         -- seconds before the same player may bounce again (debounce)
T.MaxContactVy=20      -- studs/s: only a body that is coming down or standing bounces; a rising one (a bounce, a jump) is left alone, so nothing stacks
T.Gravity=196.2        -- Roblox's default; the client passes workspace.Gravity
T.FolderName='HubTrampolines153'
T.Floor=4              -- the lobby floor's top (HubDecorKit151.Floor): where players walk
-- The three nooks' centres: brick discs at the ends of the two garden walks (HubDecor151 "Garden nook", radius 13) and of the back lane ("Lane nook", radius 10).
-- Owner: "it should fit the whole circle": each trampoline's frame reaches to Inset studs inside its disc's rim, so the brick shows as a thin ring.
-- Dims: Top = the walking surface over the floor (0.9, a kerb: the ramp ring below walks a body up onto it); Inset = how far inside the disc's rim the frame's outer edge
-- stands; MatShare = the built mat's radius as a share of the frame's; Run = the ramp ring's run (2.5 studs per stud of rise, the garden skirt's 22 degrees).
T.Dims={Top=.9,Inset=.4,MatShare=4.15/6.05,Run=2.25}
local function spot(x,z,name,disc)
 local r=disc-T.Dims.Inset
 -- Radius = the collider and the frame's outer edge (a 16-gon's corners); MatRadius = the bouncy mat (the built look's; a loaded look has its own)
 return{X=x,Z=z,Name=name,Disc=disc,Radius=r,MatRadius=r*T.Dims.MatShare}
end
T.Spots={spot(312,-269,'Desert',13),spot(-312,-269,'Lava',13),spot(0,-596,'Lane',10)}
-- The look (the server's HubTrampoline153): the owner's trampoline model from the Creator Store, "trampoline can just use this asset 12088629887". The server tries a
-- model the owner dropped into ReplicatedStorage.HubTrampolineTemplates153 first, then InsertService:LoadAsset(AssetId); with neither the built trampoline stays.
T.AssetId=12088629887
T.TemplateFolder='HubTrampolineTemplates153'
T.AssetMaxParts=400    -- a look with more parts per trampoline is not used (the built one stays; /test trampoline says so)
T.LoadTimeout=15       -- seconds one load route may take before it counts as failed
T.MaxPartSize=600      -- a part of any side above this (or not a number) is "absurd" and dropped from a loaded look
T.SquashSeconds=.6     -- the mat's squash-and-recover animation
T.SquashDepth=.2       -- studs the mat's top dips at the deepest squash (the mat's top stays over the dark gap's, 4.62, so it never disappears)

function T.Height()
 local h=tonumber(script:GetAttribute('BounceHeight'))
 if not h or h~=h then h=T.BounceHeight end
 return math.clamp(h,T.MinHeight,T.MaxHeight)
end
-- The upward speed (studs/s) that lifts the feet Height() studs under this gravity.
function T.Velocity(gravity)
 local g=tonumber(gravity)
 if not g or g~=g or g<=0 then g=T.Gravity end
 return math.sqrt(2*g*T.Height())
end
function T.Apex(velocity,gravity)return velocity*velocity/(2*(gravity or T.Gravity))end
function T.Top()return T.Floor+T.Dims.Top end
-- Where a character's feet are (root centre minus the root's half height and the hip height; an R6 body adds its leg).
function T.FeetY(rootY,rootSizeY,hipHeight,legY)return rootY-(rootSizeY/2+(hipHeight or 0)+(legY or 0))end
-- Is a body (dx, dz studs from a spot's centre, feet at feetY) on the mat's footprint (`radius`: the spot's Radius, the frame's outer edge: the whole circle bounces)
-- and low enough to be standing or landing on it? (A body that tunnelled into the collider in one fast step, feet down to the floor, still counts.)
function T.OnMat(dx,dz,feetY,radius)
 local r=(radius or T.Spots[1].Radius)+.2
 return dx*dx+dz*dz<=r*r and feetY<=T.Top()+.35 and feetY>=T.Floor-.6
end
-- One player's debounce state, and the rule: returns the upward speed to SET on the root (never added: bounces cannot stack), or nil.
function T.NewState()return{At=-math.huge}end
function T.Step(state,now,dx,dz,feetY,vy,gravity,radius)
 if not T.OnMat(dx,dz,feetY,radius)then return nil end
 if vy>T.MaxContactVy then return nil end
 if now-state.At<T.Cooldown then return nil end
 state.At=now
 return T.Velocity(gravity)
end
-- The new velocity: the horizontal speed stays, the vertical one is exactly `up`.
function T.Launch(velocity,up)return Vector3.new(velocity.X,up,velocity.Z)end
-- R153 client bug review (finding 6): MovementGuard's rise allowance (about 25 studs per .1 s check) is smaller than a launch seen late. The bounce rises 108 studs/s
-- (30 studs) and a network hitch of ~.35 s at the launch hands the server the whole rise in ONE check (26 studs): the player was put back on the mat. The server (MovementGuard)
-- now allows, for ONE check, the rise of a launch (T.LaunchRise): the last accepted frame was on or over a trampoline's collider, it is no older than the debounce window,
-- the feet end no higher than the bounce can lift them (the apex over the walking top, plus a margin), and no launch was allowed in the last Cooldown seconds. Nothing
-- else is relaxed: the sideways distance is still checked, and so is every rise that does not start on a mat.
T.GuardMargin=6        -- studs over the bounce's apex that the server still accepts (the body's wobble, a rounded sample)
T.GuardWindow=T.Cooldown+.15 -- seconds: the longest a launch may be seen after the last accepted frame on the mat (the debounce window plus one check)
-- Is a body (dx, dz studs from a spot's centre, feet at feetY) on, or above, a trampoline's collider? (the footprint of the collider, not under the floor)
function T.OverMat(dx,dz,feetY,radius)
 local r=(radius or T.Spots[1].Radius)+.2
 return dx*dx+dz*dz<=r*r and feetY>=T.Floor-.6
end
-- spots: {{X=,Z=,Radius=}, ...} the colliders that exist (Radius: the collider's, from the server's attribute); (fx, fz, fromFeetY): the last accepted frame; toFeetY: the feet now; elapsed: seconds since that frame;
-- sinceLaunch: seconds since the last rise this allowed (math.huge for none). True when the rise from the first frame to the second is a trampoline launch.
function T.LaunchRise(spots,fx,fz,fromFeetY,toFeetY,elapsed,sinceLaunch)
 if elapsed>T.GuardWindow or sinceLaunch<T.Cooldown then return false end
 if toFeetY>T.Top()+.35+T.Height()+T.GuardMargin then return false end
 for _,s in ipairs(spots)do if T.OverMat(fx-s.X,fz-s.Z,fromFeetY,s.Radius)then return true end end
 return false
end
-- The mat's squash, 0 at rest: 1 at the moment of the bounce, a little rebound past 0, settled by SquashSeconds.
function T.Squash(t)
 if t<0 or t>=T.SquashSeconds then return 0 end
 return math.exp(-7*t)*math.cos(14*t)
end
return T
