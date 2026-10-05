-- R151: THE ONE PLACE for the pull-reveal sound slots (owner: "I'll upload proper sounds and paste the ids later").
-- Every slot is {Id=nil|number, Volume, Pitch, Start}:
--   Id      nil = the slot plays its layered design made of sounds the game already has (RarePullAudio.Fallback).
--           a number (an uploaded asset id) = that one sound plays instead, on exactly the same beat.
--   Volume  0..1 for the uploaded sound (the Effects slider still scales it; Effects 0 mutes everything).
--   Pitch   PlaybackSpeed for the uploaded sound (1 = as uploaded).
--   Start   seconds of silence at the front of the uploaded file to skip (its lead-in), so the hit lands on the frame.
--           nil = SoundTiming's table / its Start_<id> attribute (0 when the id was never measured).
--   Length  (optional) seconds of sound after Start. With AlignEnd=true the file is entered late so that it ENDS on its cue's end
--           (a riser / reverse whoosh peaks exactly on the silence before the hit, however long the build of that tier is).
--   Region  (optional) {from, to} seconds: play only that slice of a long file (PlaybackRegion); a loop loops that slice.
-- Loop slots (Loop=true) keep playing until their cue ends (they fade out); one-shots play once per cue.
-- Studio: /test raresound <Slot> plays one slot, /test rarepull secret|cosmic|king plays a whole tier (nothing is granted).
-- When / how long each slot plays: docs/proposals/R151/rare_pull.md, "Sound slots".
local S={}
S.Slots={
 -- shared ---------------------------------------------------------------------------------------------------------------------
 -- (R151 owner uploads, measured offline from the owner's files: Start = the lead-in silence; volumes set from their peak / mean loudness)
 Riser={Id=126242461105018,Volume=.45,Pitch=1,Start=.128,Length=2.67,AlignEnd=true}, -- "popular riser metallic" 2.80 s: the build, peaking ON the silence
 SuckIn={Id=115669680103388,Volume=.85,Pitch=1,Start=.100,Length=.61,AlignEnd=true}, -- "backwards whoosh" .71 s (quiet, so a high Volume): into the silence
 Impact={Id=133616032782359,Volume=.55,Pitch=1,Start=.106}, -- "cinematic impact hit" 3.05 s: the big hit (Secret / King; Mythic, the top of the ladder; Cosmic hits with CosmicBoom)
 GroundImpact={Id=130581466623902,Volume=.45,Pitch=1,Start=.082}, -- "ground impact" 1.44 s: the smaller hit (Legendary; under the big hit higher up)
 TitleSlam={Id=100663216159686,Volume=.35,Pitch=1,Start=.049}, -- "punch impact hit" 1.59 s: "1 in N" slamming in (every tier)
 Sparkle={Id=103090716252123,Volume=3,Pitch=1,Start=.048,Region={.048,1.548}}, -- "shimmering object" (42.6 s, very quiet, so a high Volume): a
                                                                  -- ~1.5 s slice (PlaybackRegion; move Region onto its brightest part in Studio) as the seed floats down
 PackShake={Id=104885054288395,Volume=.7,Pitch=1,Start=.189}, -- "pill shake" 1.06 s (quiet): each wobble of the pack while it builds
 PackBurst={Id=120422004598250,Volume=.3,Pitch=1,Start=.044}, -- "splat / thud" .86 s (loud peak, so a little lower): the pack bursting open (every tier)
 Heartbeat={Id=nil,Volume=.35,Pitch=1,Start=nil},    -- (no upload yet: the game's heartbeat) the suspense pulse before the reveal (one beat per cue; <.5 s)
 AuraHum={Id=103090716252123,Volume=1.2,Pitch=1,Start=.048,Loop=true}, -- the same shimmer, looped quietly: the afterglow around a Secret+ puller (3D)
 -- King ------------------------------------------------------------------------------------------------------------------------
 -- (R151 owner uploads, measured from the owner's files)
 KingChoir={Id=71607900050825,Volume=.18,Pitch=1,Start=.023,Region={.023,6.0}}, -- "angel choir" 18.3 s, LOUD: a 6 s slice of its swell, once per cue
                                                     -- (the build into the silence; again, softer, under the seed), cut / faded by its cue
 KingFanfare={Id=77199097157197,Volume=.45,Pitch=1,Start=.056,Region={.056,5.0}}, -- "medieval fanfare" 7.8 s: as the crown lands on the pack
                                                     -- (cut by the silence), then again on the hit, ringing under the seed until the way out
 KingBell={Id=110440649150958,Volume=.8,Pitch=1,Start=.088}, -- "single church bell" 3.6 s (quiet, so louder): the scene opens (low) and the crown settles
 -- Cosmic ----------------------------------------------------------------------------------------------------------------------
 -- (R151 owner uploads, measured from the owner's files)
 CosmicPad={Id=120548831466483,Volume=.3,Pitch=1,Start=.332,Region={.332,6.0}}, -- "leap motiv" music bed 27.5 s: a ~5.7 s slice under the build
                                                     -- (fades in, fades out into the silence; again, softer, under the seed)
 CosmicWhoosh={Id=119158277815268,Volume=.4,Pitch=1,Start=.201,Region={.201,3.2}}, -- "deep strange whoosh" 5.9 s: the pack spinning up; the
                                                     -- falling star (a 3 s slice, faded on its beat)
 CosmicBoom={Id=75435110351652,Volume=.5,Pitch=1,Start=.088}, -- "large underwater explosion" 6.6 s: the supernova (instead of Impact for Cosmic),
                                                     -- its tail rings under the seed and fades on the way out
 CosmicStar={Id=100732233406279,Volume=2.5,Pitch=1,Start=.064}, -- "shine" 4.1 s (very quiet, so a high Volume): planets lock into line
                                                     -- (short twinkles), the falling star resolving into the seed (rings under it)
 -- Secret ----------------------------------------------------------------------------------------------------------------------
 SecretDrone={Id=nil,Volume=.3,Pitch=1,Start=nil,Loop=true}, -- the low drone / heartbeat of the void (loop)
 SecretGlitch={Id=nil,Volume=.35,Pitch=1,Start=nil}, -- the pack glitching (digital stutter; <.4 s)
 SecretVault={Id=nil,Volume=.5,Pitch=1,Start=nil},   -- the lock turning and the pack cracking open like a vault (ideal 1-1.5 s)
 SecretWhisper={Id=nil,Volume=.2,Pitch=1,Start=nil,Loop=true}, -- optional eerie whisper / wind under the void (loop)
}
S.Order={'Riser','SuckIn','Impact','GroundImpact','TitleSlam','Sparkle','PackShake','PackBurst','Heartbeat','AuraHum','KingChoir','KingFanfare','KingBell',
 'CosmicPad','CosmicWhoosh','CosmicBoom','CosmicStar','SecretDrone','SecretGlitch','SecretVault','SecretWhisper'}
-- An uploaded id can also be set without a code change: a number attribute <Slot>Id on this ModuleScript (e.g. KingFanfareId).
function S.Get(name)
 local slot=S.Slots[name];if not slot then return nil end
 local id=script:GetAttribute(name..'Id')
 if type(id)~='number'or id<=0 or id%1~=0 then id=slot.Id end
 if type(id)~='number'or id<=0 or id%1~=0 then id=nil end
 local region=type(slot.Region)=='table'and tonumber(slot.Region[1])and tonumber(slot.Region[2])and{slot.Region[1],slot.Region[2]}or nil
 return {Id=id and('rbxassetid://'..string.format('%.0f',id))or nil,Volume=tonumber(slot.Volume)or .3,Pitch=tonumber(slot.Pitch)or 1,Start=tonumber(slot.Start),Loop=slot.Loop==true,
  Length=tonumber(slot.Length),AlignEnd=slot.AlignEnd==true,Region=region}
end
return S
