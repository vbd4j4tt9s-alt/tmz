-- R43. A free utility bat: knockback, a short stun, and stolen-pack disarm.
-- R158 (owner: "improve hitbox consistency especially with fast moving players", and the reference video for the swing): the swing starts on the
-- swinger's screen at the click; the swinger's client sweeps the strike on what its screen shows and names the victim; the server re-checks that
-- claim against a short history of everyone's positions (BatLagComp). Contact stays at Windup (.30 s); the swing is now .85 s (Windup + Recovery).
return {
 AssetId=16428159315,SlapSoundId='rbxassetid://81700629330286',SlapVolume=.48,
 Windup=.30,Recovery=.55,Cooldown=1.0,
 -- R158b (owner: "remove the sound effect for swinging a bat, there is only a sound effect for hitting someone"): the R150 swing whoosh and its sound
 -- settings are gone; a swing is silent, only a hit has a sound (SlapSoundId). TrailRange: a swing is drawn with its white trail only this close to the camera.
 TrailRange=150,AppearanceScale=1.5,
 SpawnGrace=3,RequireBiome=true,SafeLineMargin=4,
 -- R158 the hit (docs/proposals/R158/bats/hitbox.md 4.2-4.5). The strike: HitFrom..HitTo seconds after the swing starts (contact at Windup).
 -- Where: a flat sector in front, Reach studs, HalfAngle degrees each side, +-Height up / down, plus an Inner circle all round (someone inside you).
 -- Paths, not points: a target's path since the last frame is tested in sub-steps of Step studs (at most MaxSubSteps per frame).
 HitFrom=.24,HitTo=.36,Reach=14,HalfAngle=75,Inner=4,Height=5,Step=2,MaxSubSteps=32,
 -- The server's history: every player's root and flat facing, HistoryHz samples a second, HistorySize samples (~1.07 s), reused ring buffers.
 -- A step between two samples faster than JumpSpeed studs/s is a teleport / respawn, never a path (nothing is swept along it).
 HistoryHz=30,HistorySize=32,JumpSpeed=1200,
 -- The server's check of a claim: the swing's Start is taken from the client within [receipt - Lag (below; at most StartBack), receipt + StartAhead]; a
 -- claim's time must be in the strike +- StrikeSlack, not later than the server clock + FutureSlack, and arrive within MaxClaimDelay (and Lag + FrameSlack,
 -- below). The swinger's claimed spot must lie within OwnSlack
 -- studs of its own server path (ViewTime - OwnBack .. now, + OwnAhead s along its newest velocity), its facing within LookSlack degrees of one the server
 -- saw. The victim is looked up at ViewTime - min(MaxRewind, the claim's travel time + Buffer) +- TimeSlack (Buffer = the client's interpolation
 -- delay: measure it in Studio, hitbox.md 5). Reach grows by BonusPerSpeed per stud/s of relative speed (at most MaxBonus); AngleSlack widens the sector.
 StartBack=.50,StartAhead=.02,StrikeSlack=.05,FutureSlack=.02,MaxClaimDelay=.50,OwnSlack=4,OwnBack=.20,OwnAhead=.10,LookSlack=45,
 Buffer=.10,MaxRewind=.30,TimeSlack=.08,AngleSlack=15,BonusPerSpeed=.02,MaxBonus=6,
 -- R158 review (hitbox.md "Review fixes"): the swinger's lag as the SERVER measures it, Lag = max(PingFloor, Player:GetNetworkPing()) + PingSlack (at most
 -- StartBack), bounds what the client says about time: the swing's Start is taken no earlier than receipt - Lag, a claim may travel at most Lag + FrameSlack
 -- (its moment can be one slow frame older than the packet), the rewind counts at most Lag of travel, and the victim is never looked up more than
 -- min(MaxRewind + RewindSlack, 2 x Lag + Buffer) before now. Velocities are measured over VelocityWindow s (a 20 Hz character stream repeats samples);
 -- the swinger's own extrapolation (OwnAhead) is never faster than its earned walk speed x SpeedSlack (the server lets a runner reach 1.15 x).
 PingFloor=.05,PingSlack=.05,FrameSlack=.10,RewindSlack=.10,VelocityWindow=.10,SpeedSlack=1.2,
 -- The server's cooldown is the same 1.0 s, on the swing's own start times; receipts may come up to CooldownSlack early (network jitter), and so may a start
 -- the server had to hold to its window (a client clock a little ahead / behind); the cooldown still averages 1.0 s.
 CooldownSlack=.15,
 -- R158 effects (animation.md 4; owner: a white trail, no camera shake for the hitter, no "SMACK!" word). The trail is on from TrailFrom to TrailTo s of
 -- the swing only; HitStop = the hitter's own swing pauses this long at its hit (its screen only; the server's timing does not move).
 TrailFrom=.21,TrailTo=.40,TrailLifetime=.12,TrailRGB={255,255,255},TrailLightEmission=.6,TrailWidth=1,HitStop=.05,
}
