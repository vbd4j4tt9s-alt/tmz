-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity"): the numbers behind Verity's greeting, with no
-- instances in it, so the client (VerityClient: plays the cut, drives her swell and bounce), the server (VerityService and the owner command
-- /test verityvoice) and the tests all use the same rules.
--  * Region: which part of the clip plays (VerityConfig.GreetingStart / GreetingEnd, or the owner's live override), made safe.
--  * Fade: the volume ramp over the last stretch of the cut, so stopping the sound does not click.
--  * NewLip / Begin / Step: the smoothed, normalised loudness of the voice (0 = silent, 1 = the loudest syllable).
--  * Pose: her size and her rise on a ball of a given diameter at a given level: she swells (TalkPulse) and hops (TalkBounce).
-- R151 (owner: "the Verity mouth thing can be removed and the ball can just bounce"): the mouth oval (MouthPose) is gone; Pose is the bounce.
local M={}
M.MinLength=.1      -- the shortest cut there can be (seconds)
M.MaxSeconds=60     -- the longest start / end the owner command accepts (the clip is far shorter)
M.Default={Start=0,Stop=2.35}

local function finite(v)return type(v)=='number'and v==v and v>-math.huge and v<math.huge end
M.Finite=finite

-- (start, stop) in seconds into the clip. A pair of numbers (the owner's live values) wins over the config; anything that is not a
-- pair of finite numbers falls back to VerityConfig.GreetingStart / GreetingEnd, and those fall back to 0 .. 2.35 if they are broken.
-- length: the clip's TimeLength once it is known (0 / nil before it loads): the cut never runs past it.
function M.Region(config,a,b,length)
 local start,stop
 if finite(a)and finite(b)then start,stop=a,b else start,stop=config.GreetingStart,config.GreetingEnd end
 if not finite(start)or not finite(stop)then start,stop=M.Default.Start,M.Default.Stop end
 start=math.clamp(start,0,M.MaxSeconds);stop=math.clamp(stop,0,M.MaxSeconds)
 if finite(length)and length>0 then stop=math.min(stop,length);start=math.min(start,math.max(0,length-M.MinLength))end
 if stop-start<M.MinLength then stop=start+M.MinLength end
 return start,stop
end

-- Volume factor 0..1 at this position of the clip: 1 until `fade` seconds before the end of the cut, then a straight ramp to 0.
function M.Fade(position,stop,fade)
 if not finite(position)or not finite(stop)or not finite(fade)or fade<=0 then return 1 end
 return math.clamp((stop-position)/fade,0,1)
end

-- Voice level (named "lip" from the mouth it used to drive) -------------------------------------------------------------------------------
function M.NewLip(cfg)return{Level=0,Peak=cfg.Floor,Seen=false,Age=0}end
-- A new playing of the clip: forget what was heard last time (the level itself keeps its value and falls smoothly).
function M.Begin(lip,cfg)lip.Peak=cfg.Floor;lip.Seen=false;lip.Age=0 end
-- One frame. loudness: the Sound's PlaybackLoudness (0..1000; nil / NaN read as 0). playing: the voice is being played right now.
-- Returns the new Level (also stored in lip.Level): 0 = silent, 1 = the loudest syllable.
--  * Real loudness is normalised to the loudest syllable heard in this playing (never below cfg.Floor), gated and curved.
--  * Until any loudness has been heard, and for cfg.FallbackAfter seconds, the level stays 0; after that a talking rhythm runs (the
--    engine could not measure the sound: not loaded, muted by the platform...) for as long as `playing` lasts.
--  * Rising is fast (cfg.Attack a second), falling slower (cfg.Release); once the voice has stopped it falls smoothly and snaps to exactly
--    0 below .004, so whatever the Level drives goes back to rest exactly.
-- R153 (owner: "fix all jittery type effects"): Bounce, what her hop and swell follow, trails Level through a critically damped spring (M.BounceRate
-- a second going up, M.BounceFall coming down). PlaybackLoudness is a noisy reading that changes every few frames; the fast-rising Level jumped
-- with each reading and turned sharply at each peak, so her hop buzzed. Bounce's speed changes smoothly (no kinks), it trails Level by a frame
-- or so, never leaves the range Level went through (a weighted average of past levels) and settles exactly at 0 with Level.
M.BounceRate,M.BounceFall=120,200
local function follow(lip,dt)
 local x,v=lip.Bounce or 0,lip.BounceSpeed or 0;local w=lip.Level<x and M.BounceFall or M.BounceRate
 local e=x-lip.Level;local k=math.exp(-w*dt);local t=(v+w*e)*dt
 x=lip.Level+(e+t)*k;v=(v-w*t)*k
 if lip.Level==0 and x<.004 then x,v=0,0 end
 lip.Bounce,lip.BounceSpeed=math.clamp(x,0,1),v
end
-- The value her pose is drawn from (0..1), and whether anything about her still moves.
function M.Bounce(lip)return lip.Bounce or lip.Level end
function M.Moving(lip)return lip.Level>0 or(lip.Bounce or 0)>0 end
-- Back to rest at once (the voice was torn down).
function M.Rest(lip)lip.Level=0;lip.Bounce=0;lip.BounceSpeed=0 end
local function step(lip,cfg,loudness,dt,playing)
 if not playing then
  lip.Level=lip.Level*math.exp(-cfg.Release*dt)
  if lip.Level<.004 then lip.Level=0 end
  return lip.Level
 end
 lip.Age+=dt
 loudness=finite(loudness)and math.max(0,loudness)or 0
 if loudness>=cfg.Heard then lip.Seen=true end
 local target=0
 if lip.Seen then
  lip.Peak=math.max(cfg.Floor,lip.Peak*math.exp(-cfg.PeakDecay*dt),loudness)
  local x=math.clamp(loudness/lip.Peak,0,1)
  if x>cfg.Gate then target=((x-cfg.Gate)/(1-cfg.Gate))^cfg.Curve end
 elseif lip.Age>=cfg.FallbackAfter then
  -- One opening per syllable: the positive half of a sine (open for half of each period, shut for the other half, long enough for the
  -- slower closing to reach shut), a little different each time (syllables are not all equally loud).
  local wave=math.max(0,math.sin(2*math.pi*cfg.Rhythm*(lip.Age-cfg.FallbackAfter)))^.6
  target=wave*(.8+.2*math.sin(lip.Age*5.3+1))
 end
 local rate=target>lip.Level and cfg.Attack or cfg.Release
 lip.Level+=(target-lip.Level)*(1-math.exp(-rate*dt))
 if lip.Level<.004 and target==0 then lip.Level=0 end
 return lip.Level
end
function M.Step(lip,cfg,loudness,dt,playing)
 dt=finite(dt)and math.clamp(dt,0,.1)or 1/60
 local level=step(lip,cfg,loudness,dt,playing);follow(lip,dt)
 return level
end

-- Her body on a ball of diameter D (any scale) at voice level `level` (0..1 from Step; NaN / nil / negative read as 0, above 1 as 1):
-- Scale: 1 + cfg.TalkPulse * level; Size = D * Scale; Rise = how far her CENTRE stands above its rest height: she swells upward from where her
-- bottom rests (D * (Scale - 1) / 2) and hops by cfg.TalkBounce * D * level on top of that. Returns {Scale=, Size=, Rise=}.
function M.Pose(cfg,diameter,level)
 level=finite(level)and math.clamp(level,0,1)or 0
 local scale=1+cfg.TalkPulse*level
 return {Scale=scale,Size=diameter*scale,Rise=diameter*(scale-1)/2+diameter*cfg.TalkBounce*level}
end

return M
