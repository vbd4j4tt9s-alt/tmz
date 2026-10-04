-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."): the numbers and texts shared by
-- VerityService (server: builds her, takes the hand-in) and VerityClient (her turning to you, her voice, the marker, the dialog).
--  * Reward (owner's choice): one Verity Pack for every Void Pack handed in. Repeatable, no daily cap.
-- R148 (owner's play test: Verity was invisible, she must be behind the market, the dialog must show the packs; then "Verity
-- should be a big yellow sphere" and her greeting voice):
--  * She is the place's old Verity part made big: a solid YELLOW SPHERE (Color 255,255,0, SmoothPlastic, 22 studs across) with the
--    smiley picture (Image: a thin black line drawing, transparent background) as a Decal on its Front and Back faces, floating a
--    hair above a round stone-and-gold dais. Clients turn her to face the viewer, so the smiley always looks at you.
--  * Where: BEHIND the market, seen from the spawn: the market is centred at (0, 4, -269.3) scaled x1.7 with its porch, string
--    lights, produce stands and the Fruit of the Hour pedestal reaching z -293 / -302 on the far side (the side with the
--    big MARKET sign, where "SHOP" fast travel lands at z -296); the spawn is at (0, 4.1, -141) and the lobby floor runs to z -623.
--    Her dais (28 across) is centred at (0, 4, -340): 33 studs clear of the market's porch and 24 of the pedestal, 68 from the
--    next base, facing +Z (toward the market and the way players walk round it to reach her). Players come round the market's
--    sides (it is 54 studs wide; the lobby is 680 wide) and reach her from the market side.
--  * Tune in Studio: BodySize (the sphere's diameter), FootOffset, Position, DaisDiameter, Sign (its size and gap), light range / brightness.
local Catalog=require(script.Parent.VerityCatalog)
local Limited=require(script.Parent.LimitedEvent)
local C={Version=148}
C.Name='VERITY'
C.ModelName='VerityNPC'
C.Tag='VerityNPC'
C.RemoteName='VerityQuest'
C.Image='rbxassetid://102712963740896'
-- World ---------------------------------------------------------------------------------------------------------------
C.Position=Vector3.new(0,4,-340)   -- the floor under her (the dais sits on it)
C.Facing=Vector3.new(0,0,1)        -- +Z: toward the market and the path players walk to reach her
C.BodySize=22                      -- the sphere's diameter in studs (the market's ridge is 28 above the floor, its width 54)
C.BodyColor=Color3.fromRGB(255,255,0)
C.BodyFaces={'Front','Back'}       -- Decal faces (a ball: she turns to the viewer on clients, and shows her face from behind otherwise)
C.FootOffset=.25                   -- the sphere's bottom rests this high above the dais; clients bob her +-FootOffset around it
C.DaisDiameter=28;C.DaisHeight=1.2
C.RingDiameter=26.4;C.RingColor=Color3.fromRGB(255,206,64)
C.LightColor=Color3.fromRGB(255,235,140);C.LightRange=56;C.LightBrightness=1.2
C.LightHeight=5                    -- studs above the sphere's top
-- Her sign (one BillboardGui over her head, sized in STUDS so it scales with her): from the top, the quest marker ("!" / "?"), a
-- gap, her name, a small line with the event timer. Rows are in studs inside the sign (Top, Height); they cannot overlap, so
-- the marker, the name and the timer keep their gaps at every distance. The sign is offset in CAMERA space (StudsOffset, not
-- world space) so its bottom edge stays Gap studs above her top edge as seen from any camera angle.
C.Sign={W=32,H=15.5,Gap=1.6,
 Mark={Top=0,Height=7,Glyph=5.4,Bounce=1.6},   -- the "!" / "?" glyph rests at the bottom of its row and bounces up by Bounce
 Name={Top=8.2,Height=4.5},
 Timer={Top=13.3,Height=2.2}}
C.NameMaxDistance=300
C.PromptActionText='Talk';C.PromptObjectText='Verity';C.PromptDistance=26;C.PromptHold=0
C.PromptHeight=3                   -- studs above the dais (the prompt hangs inside the sphere's lower half)
-- Voice (owner: "123997993114202 is the audio id for Verity's greetings") -------------------------------------------------
C.GreetingSoundId='rbxassetid://123997993114202'
C.GreetingVolume=.8
C.GreetingRollOffMin=30;C.GreetingRollOffMax=140   -- studs: full volume inside the min, fading out (InverseTapered) to the max
C.GreetingDistance=30              -- studs from her: coming this close greets you...
C.GreetingCooldown=60              -- ...at most once a minute (a greeting from Talk counts as the last one)
C.TalkPulse=.06                    -- how much she swells (fraction of her size) while the voice plays
C.TalkPulseRate=18                 -- radians a second
-- Security --------------------------------------------------------------------------------------------------------------
-- The limited event (R148 owner: "place a timer ... 27 days, hrs, mins, s ... same for the event for Verity"): LimitedEvent.EndsAt
-- (UTC) is shared with the Index LIMITED tab. After it Verity takes nothing: the server refuses, the dialog says EVENT ENDED, the "!" is gone.
C.EventEndsAt=Limited.EndsAt
C.Event={Prefix='EVENT ENDS IN ',Ended='EVENT ENDED'}
C.EventColor=Color3.fromRGB(255,236,150)
C.GiveDistance=38                  -- the server's own range check for the hand-in (the prompt itself reaches 26)
C.MaxDelivered=1e9                 -- saved counter ceiling (anything larger in a save is clamped)
C.VoidVariant='EclipseReliquary';C.VerityVariant=Catalog.Variant;C.PackStage=Catalog.PackStage
C.PackName=Catalog.PackName
-- The player attributes that block a hand-in, with the reason said to the player (carrying a stolen pack, in a run, queued
-- for one, ragdolled / flung by a keeper). Checked in this order.
C.BusyAttributes={{'ChestChaseSeedCarrying','Busy'},{'ChestChaseRunActive','Busy'},{'ChestChaseQueued','Busy'},{'GuardianRagdollActive','Moment'},{'GuardianFlingActive','Moment'}}
-- Texts -----------------------------------------------------------------------------------------------------------------
C.Quest='Steal a Void Pack from The Darkened One at the end of Storm Peaks and bring it to me. I\'ll give you a '..Catalog.PackName..'!'
C.RewardText='1 VOID PACK = 1 '..Catalog.PackName:upper()
C.Thanks='Thank you! Here is your '..Catalog.PackName..'.'
C.Notice='🌟 Verity gave you a '..Catalog.PackName..'!'
C.Reasons={
 Loading='YOUR DATA IS STILL LOADING',
 CannotSave='YOUR DATA CANNOT SAVE RIGHT NOW',
 TooFar='COME CLOSER TO VERITY',
 Busy='FINISH YOUR RUN FIRST',
 Moment='WAIT A MOMENT AND TRY AGAIN',
 Opening='FINISH OPENING THAT PACK FIRST',
 NoVoid='YOU NEED A VOID PACK',
 NotReady='VERITY IS NOT READY',
 Failed='VERITY COULD NOT TAKE IT. TRY AGAIN',
 EventEnded='THE VERITY EVENT HAS ENDED',
}
return C
