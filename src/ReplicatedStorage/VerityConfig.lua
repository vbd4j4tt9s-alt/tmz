-- R147 (owner: "Verity NPC is a quest giver: it tells players to steal a pack from The Darkened one and give it to the
-- Verity NPC. The Verity NPC will be behind the market and it will be big."): the numbers and texts shared by
-- VerityService (server: builds her, takes the hand-in) and VerityClient (the card turning to you, the marker, the dialog).
--  * Reward (owner's choice): one Verity Pack for every Void Pack handed in. Repeatable, no daily cap.
--  * Where: (0, 4, -222), facing +Z. The market is centred at (0, 4, -269.3) scaled x1.7 (back wall z -253.6, back step to
--    z -247.7, roof ridge y 31.8); the spawn is at z -141. Nothing else stands within 60 studs of her.
--  * She is a big flat picture (a "card") on a stone and gold dais, like a standee. The owner's picture has an unknown
--    aspect: CardWidth / CardHeight / FootOffset are the three numbers to tune in Studio (the picture is drawn with
--    ScaleType Fit, so a different aspect only leaves empty margin inside the card; FootOffset lifts or sinks it).
local Catalog=require(script.Parent.VerityCatalog)
local C={Version=147}
C.Name='VERITY'
C.ModelName='VerityNPC'
C.Tag='VerityNPC'
C.RemoteName='VerityQuest'
C.Image='rbxassetid://102712963740896'
-- World ---------------------------------------------------------------------------------------------------------------
C.Position=Vector3.new(0,4,-222)   -- the floor under her (the dais sits on it)
C.Facing=Vector3.new(0,0,1)        -- +Z: toward the spawn, so players arriving from the lobby see her face
C.DaisDiameter=16;C.DaisHeight=1.2
C.CardWidth=24;C.CardHeight=34
C.FootOffset=0                     -- card bottom = floor + DaisHeight + FootOffset (negative sinks her feet into the dais)
C.CardThickness=.2
C.CardPixelsPerStud=30             -- the SurfaceGui canvas: 720 x 1020 for a 24 x 34 card
C.CollisionDiameter=7;C.CollisionHeight=14
C.RingDiameter=13;C.RingColor=Color3.fromRGB(255,206,64)
C.LightColor=Color3.fromRGB(255,222,140);C.LightRange=34;C.LightBrightness=1.4
C.NameHeight=3                     -- studs from the top of the card to the name sign
C.MarkerHeight=8                   -- studs from the top of the card to the quest marker (client)
C.MarkerMaxDistance=260
C.PromptActionText='Talk';C.PromptObjectText='Verity';C.PromptDistance=20;C.PromptHold=0
-- Security --------------------------------------------------------------------------------------------------------------
C.GiveDistance=30                  -- the server's own range check for the hand-in (the prompt itself reaches 20)
C.MaxDelivered=1e9                 -- saved counter ceiling (anything larger in a save is clamped)
C.VoidVariant='EclipseReliquary';C.VerityVariant=Catalog.Variant
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
}
return C
