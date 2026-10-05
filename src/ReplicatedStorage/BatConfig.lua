-- R43. A free utility bat: knockback, a short stun, and stolen-pack disarm.
return {
 AssetId=16428159315,SlapSoundId='rbxassetid://81700629330286',SlapVolume=.48,
 Windup=.30,Recovery=.44,Cooldown=1.0,
 -- R150: the swing "whoosh" (the existing 9120768742 file, its .44 s lead-in skipped by SoundTiming): it starts SwingSoundLead before contact so
 -- the swish builds through the strike and meets the hit at At+Windup. A miss is no longer silent. Tune by ear.
 SwingSoundVolume=.25,SwingSoundPitch=1.4,SwingSoundLead=.12,SwingSoundRange=150,HitboxSize=Vector3.new(16,10,14),AppearanceScale=1.5,
 SpawnGrace=3,RequireBiome=true,SafeLineMargin=4,
}
