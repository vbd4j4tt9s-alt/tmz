-- R149 (owner: "sync verity's voice and cut the audio to only hello my name verity"): the numbers behind Verity's greeting, with no
-- instances in it, so the client (VerityClient: plays the cut, drives her mouth), the server (VerityService and the owner command
-- /test verityvoice) and the tests all use the same rules.
--  * Region: which part of the clip plays (VerityConfig.GreetingStart / GreetingEnd, or the owner's live override), made safe.
--  * Fade: the volume ramp over the last stretch of the cut, so stopping the sound does not click.
--  * NewLip / Begin / Step: lip sync. The smoothed, normalised loudness of the voice (0 = closed, 1 = wide open).
--  * MouthPose: size and place of her open mouth (a dark oval) on a ball of a given diameter.
local M={}
M.MinLength=.1      -- the shortest cut there can be (seconds)
M.MaxSeconds=60     -- the longest start / end the owner command accepts (the clip is far shorter)
M.Default={Start=0,Stop=1.9}

local function finite(v)return type(v)=='number'and v==v and v>-math.huge and v<math.huge end
M.Finite=finite

-- (start, stop) in seconds into the clip. A pair of numbers (the owner's live values) wins over the config; anything that is not a
-- pair of finite numbers falls back to VerityConfig.GreetingStart / GreetingEnd, and those fall back to 0 .. 1.9 if they are broken.
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

-- Lip sync -----------------------------------------------------------------------------------------------------------------------------
function M.NewLip(cfg)return{Level=0,Peak=cfg.Floor,Seen=false,Age=0}end
-- A new playing of the clip: forget what was heard last time (the mouth itself keeps its Level and closes smoothly).
function M.Begin(lip,cfg)lip.Peak=cfg.Floor;lip.Seen=false;lip.Age=0 end
-- One frame. loudness: the Sound's PlaybackLoudness (0..1000; nil / NaN read as 0). playing: the voice is being played right now.
-- Returns the new Level (also stored in lip.Level): 0 = mouth closed, 1 = wide open.
--  * Real loudness is normalised to the loudest syllable heard in this playing (never below cfg.Floor), gated and curved.
--  * Until any loudness has been heard, and for cfg.FallbackAfter seconds, the mouth stays shut; after that a talking rhythm runs (the
--    engine could not measure the sound: not loaded, muted by the platform...) for as long as `playing` lasts.
--  * Opening is fast (cfg.Attack a second), closing slower (cfg.Release); once the voice has stopped it closes smoothly and snaps to exactly
--    0 below .004, so whatever the Level drives goes back to rest exactly.
function M.Step(lip,cfg,loudness,dt,playing)
 dt=finite(dt)and math.clamp(dt,0,.1)or 1/60
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

-- Her open mouth on a ball of diameter D (any scale): a flat dark oval (a block Part with a Sphere SpecialMesh, so its three sizes are
-- independent) whose centre sits on the ball's surface at height cfg.Mouth.Y * D below her centre. level: 0..1 from Step.
-- Returns {W,H,D} (the oval's size) and {Y,Z} (its centre in the ball's own frame: her face looks along -Z), or nil when level is below
-- cfg.Mouth.Show (draw nothing: the smile picture is her closed mouth).
function M.MouthPose(cfg,diameter,level)
 local m=cfg.Mouth
 if not finite(level)or level<m.Show then return nil end
 level=math.min(level,1)
 local y=diameter*m.Y;local r=diameter/2
 local z=math.sqrt(math.max(r*r-y*y,0)) -- how far out the ball's surface is at that height
 return {W=diameter*m.Width*(1+m.Widen*level),H=diameter*m.Height*level,D=diameter*m.Depth,Y=y,Z=-z}
end

return M
