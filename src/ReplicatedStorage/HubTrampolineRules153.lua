-- R153 hub trampolines: the numbers and the pure rules, shared by the server's builder (ChestChaseServer.HubTrampoline153) and the client
-- (HubTrampoline153.client). Owner: "remove these benches at the corner just add a trampoline that boosts players up by a bit".
-- A trampoline stands in the middle of each garden nook (the brick plazas at the ends of the two garden walks). ONE number sets the bounce:
-- BounceHeight, the studs the feet rise above the mat (ReplicatedStorage.HubTrampolineRules153's BounceHeight attribute overrides it in Studio).
-- How it moves players: the client that owns the character sets the vertical speed of its own HumanoidRootPart (the way RunnerController already
-- owns the horizontal speed, and keeps the vertical one); MovementGuard's 25-stud rise allowance per sample covers the launch (checked by the tests).
local T={Version=153}
T.BounceHeight=30      -- studs the feet rise above the mat: a bit (25 - 35); the apex is about 35 over the floor, over the lamps and the trees
T.MinHeight,T.MaxHeight=12,40 -- whatever the attribute says, the bounce stays inside these (never a sky launch)
T.Cooldown=.45         -- seconds before the same player may bounce again (debounce)
T.MaxContactVy=20      -- studs/s: only a body that is coming down or standing bounces; a rising one (a bounce, a jump) is left alone, so nothing stacks
T.Gravity=196.2        -- Roblox's default; the client passes workspace.Gravity
T.FolderName='HubTrampolines153'
T.Floor=4              -- the lobby floor's top (HubDecorKit151.Floor): where players walk
-- The two garden nooks' centres (HubDecor151 "Garden nook": brick discs of radius 13 at the ends of the garden walks).
T.Spots={{X=312,Z=-269,Name='Desert'},{X=-312,Z=-269,Name='Lava'}}
-- Dims: Top = the walking surface over the floor (0.9: a player steps on from the ground like onto a kerb, the game's own runner clears 1.1);
-- Radius = the collider and the frame's outer edge; MatRadius = the bouncy mat.
T.Dims={Top=.9,Radius=6.05,MatRadius=4.15}
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
-- Is a body (dx, dz studs from a spot's centre, feet at feetY) on the mat's footprint and low enough to be standing or landing on it? (A body that
-- tunnelled into the collider in one fast step, feet down to the floor, still counts.)
function T.OnMat(dx,dz,feetY)
 local r=T.Dims.Radius+.2
 return dx*dx+dz*dz<=r*r and feetY<=T.Top()+.35 and feetY>=T.Floor-.6
end
-- One player's debounce state, and the rule: returns the upward speed to SET on the root (never added: bounces cannot stack), or nil.
function T.NewState()return{At=-math.huge}end
function T.Step(state,now,dx,dz,feetY,vy,gravity)
 if not T.OnMat(dx,dz,feetY)then return nil end
 if vy>T.MaxContactVy then return nil end
 if now-state.At<T.Cooldown then return nil end
 state.At=now
 return T.Velocity(gravity)
end
-- The new velocity: the horizontal speed stays, the vertical one is exactly `up`.
function T.Launch(velocity,up)return Vector3.new(velocity.X,up,velocity.Z)end
-- The mat's squash, 0 at rest: 1 at the moment of the bounce, a little rebound past 0, settled by SquashSeconds.
function T.Squash(t)
 if t<0 or t>=T.SquashSeconds then return 0 end
 return math.exp(-7*t)*math.cos(14*t)
end
return T
