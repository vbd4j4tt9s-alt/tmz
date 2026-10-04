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
-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity and also change the picture of verity to its 3d model
-- talking and remove the event ends thing"):
--  * Her greeting plays only the part of the clip that says "Hello, my name is Verity": GreetingStart .. GreetingEnd (seconds into the
--    audio), as the Sound's PlaybackRegion, with a short fade at the end so the cut does not click. The two numbers below are GUESSES:
--    find the real end by ear in Studio / a live server with  /test verityvoice <end> [start]  (it plays the cut for you at once), then
--    write the numbers here.
--  * Her mouth follows the loudness of the voice (Lip, Mouth: see VerityVoice.lua), in the world and in the window's 3D portrait (Portrait).
--  * The dialog no longer shows "EVENT ENDS IN ..." (the event still ends: Event.Ended, EventEndsAt and the server's refusal are unchanged).
local Catalog=require(script.Parent.VerityCatalog)
local Limited=require(script.Parent.LimitedEvent)
local C={Version=149}
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
-- TUNE IN STUDIO: where "Hello, my name is Verity" starts and ends inside the clip, in seconds (the clip could not be listened to when
-- these were written: 0 .. 1.9 is a guess). Run  /test verityvoice <end> [start]  until it stops right after "Verity", then put the numbers here.
C.GreetingStart=0
C.GreetingEnd=1.9
C.GreetingFade=.08                 -- seconds: her volume ramps to 0 over the last stretch of the cut, so it does not click
C.GreetingRollOffMin=30;C.GreetingRollOffMax=140   -- studs: full volume inside the min, fading out (InverseTapered) to the max
C.GreetingDistance=30              -- studs from her: coming this close greets you...
C.GreetingCooldown=60              -- ...at most once a minute (a greeting from Talk counts as the last one)
C.AnimateDistance=300             -- clients beyond this many studs from her leave her body alone (no turn / bob / swell writes)
C.TalkPulse=.06                    -- how much she swells (fraction of her size) at the loudest moment of the voice
-- Lip sync (VerityVoice.Step): the client reads the greeting's PlaybackLoudness each frame while she talks, smooths it (fast opening, slower
-- closing) and drives her mouth and her swelling with it. Heard: raw loudness that counts as "the sound is really playing"; Floor: the
-- loudness (of 0..1000) that counts as fully open until a louder syllable is heard (the peak then adapts and decays by PeakDecay a second);
-- Gate: quieter than this fraction of the peak closes the mouth; Curve < 1 opens it a little wider on quiet vowels; Attack / Release: how fast
-- it opens / closes (per second). If no loudness is ever heard (a sound the engine cannot measure) a plain talking rhythm (Rhythm syllables a
-- second) runs for the length of the cut instead, starting FallbackAfter seconds in.
C.Lip={Heard=2,Floor=60,Gate=.08,Curve=.75,Attack=40,Release=14,PeakDecay=.5,FallbackAfter=.3,Rhythm=3.4}
-- Her open mouth: a dark oval on the front of the ball, sitting inside her smile. Sizes are fractions of her diameter; Y is how far below her
-- centre the oval is centred; Width / Height are at full open (Widen: it gets a little wider as it opens); Depth: how thick the dome is; Show: the
-- opening below which no mouth is drawn (the smile picture alone is her closed mouth). The defaults come from the owner's screenshot of the
-- smiley (taken in the window, where the picture is .86 of the ball; she wears it across the whole 22 stud face): the eyes are .18 .. .07 of her
-- diameter above her centre, the smile runs from .055 above it (its ends, +-.27 across) to .13 below it (its middle). TUNE IN STUDIO against her
-- real face (run /test verityvoice and look at her).
C.Mouth={Y=-.04,Width=.28,Height=.12,Depth=.035,Widen=.12,Show=.06,Color=Color3.fromRGB(34,8,14)}
-- The window's 3D portrait: a yellow ball with the same smiley in a ViewportFrame. Size: the ball's diameter in the viewport (studs, any scale);
-- Fov: the portrait camera's field of view; Fill: how much of the viewport the ball fills at rest (the rest is room for the swell and the bob);
-- Bob: how far it bobs (fraction of its size).
C.Portrait={Size=10,Fov=30,Fill=.88,Bob=.03}
-- Security --------------------------------------------------------------------------------------------------------------
-- The limited event (R148 owner: "place a timer ... 27 days, hrs, mins, s ... same for the event for Verity"): LimitedEvent.EndsAt
-- (UTC) is shared with the Index LIMITED tab. After it Verity takes nothing: the server refuses, the GIVE button says EVENT ENDED, the "!" is
-- gone and her sign says EVENT ENDED. (R149: the dialog has no countdown line any more; her sign and the Index LIMITED tab keep theirs.)
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
