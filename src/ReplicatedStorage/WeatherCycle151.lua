-- R151 (owner, verbatim): "add a new weather effect where it alternated so th default weather is clear i want you to make the other default weather
-- cloudy where it just dims the lighting so that the lanterns around the map can create a warm ambience".
--
-- The default sky (no rain / thunder / blizzard going on) now alternates Clear <-> Cloudy. Cloudy is an AMBIENT sky, not an event: it adds no
-- particles, no notice, no sound, and it is NOT a mutation weather (WeatherTraits.Events and every weather trait are untouched; GlobalWeather
-- stays 'Clear' while it is cloudy, so the R98 / R131 mutation rolls, the R149 rain / snow tiles and the weather HUD's picture and timer never see it;
-- only the HUD row's accessibility label reads "Cloudy skies").
--
--  SCHEDULE  a pure function of server time, so every server and every player agrees without any state: segment n runs from Boundary(n) to
--            Boundary(n + 1); even n is Clear, odd n is Cloudy. Boundaries sit at multiples of the period (Clear + Cloudy seconds) plus the
--            Clear length for the odd ones, each moved by a hash-random amount of at most Spread x the shorter phase (so no two phases are
--            alike, and nothing needs remembering). Segment(t) is O(1) (looks at four boundaries).
--  FADE      every switch fades over Fade(n) seconds (20..40, hash-random per switch) with a smoothstep: Level(since, fade, from, now).
--  STATE     the SERVER (WeatherService:StepSky) publishes the current segment as ONE attribute, ReplicatedStorage.AmbientSkyState
--            "Kind|since|fade|from|endsAt" (one attribute = one atomic update; two attributes can arrive a frame apart). Clients read it with
--            Read(storage, now), a smooth level 0 (Clear) .. 1 (Cloudy) from the state and the server clock, so a player who joins in the
--            middle of a fade sees the right level, and a test command or a skip (a new state starting from the level it had reached) never
--            jumps. ReplicatedStorage.AmbientSky holds the plain kind for anything that only wants to know.
--  EVENTS    event weather takes priority and works exactly as before: while GlobalWeather is not 'Clear' the Cloudy look is not applied at
--            all (Effective() = 0, BiomeMood.Palette ignores it), the schedule keeps running underneath, and when the event ends the sky
--            returns to wherever the cycle is by then.
--  WHERE     like the storms (R129) it dims the BASE only: on the track each biome keeps its own mood (Config.Track = 0; the owner can raise it).
--            The R151 rare-pull story scenes (RarePullCinematic 'Scene') are lit as authored: while one runs the look eases out.
-- Pure: no Instances, no services, no randomness besides the hashes.
local C={Version=151}
local C3=Color3.fromRGB

-- ------------------------------------------------------------------------------------------------------------------------------------
-- What the owner can tune. (The look itself - brightness, ambient, haze, clouds - is BiomeMood.CloudyLook.)
-- ------------------------------------------------------------------------------------------------------------------------------------
C.Config={
 Clear={Seconds=480},      -- the default sky: about 8 minutes ...
 Cloudy={Seconds=360},     -- ... then about 6 minutes of cloud
 Spread=.1,                -- each switch lands up to this share of the SHORTER phase early or late: Clear runs 6.8 - 9.2 min, Cloudy 4.8 - 7.2 min
 Fade={20,40},             -- seconds a switch takes (a random value in between for every switch)
 TestHold=300,             -- /test weather clear | cloudy keep the sky this long, then the cycle goes on
 TestFade=6,               -- ... and bring it in this fast (so a test shows at once; /test weather cycle skip uses the real fade)
 Track=0,                  -- share of the Cloudy look on the track (0 = the base only, like the storms since R129; 1 = every biome too)
}
-- Lamps and lanterns (HubLife151.client; the market's warm lights follow Market).
C.Lamps={
 OnAt=.12,                 -- the lamps start to glow when the sky is this far into the fade (0..1), and are at full glow at 1
 Real={[3]=8,[2]=4,[1]=0}, -- real PointLights switched on by Cloudy, per device tier (3 desktop, 2 phone, 1 FastMode / low). The R151 hub has 8; The
                           -- Darkened and Rain / Thunderstorm switch on all of them at every tier exactly as before (they ask for the dark). Every
                           -- lamp HEAD glows warm at every tier whatever the lights are (neon: no light cost).
 HeadSteps={[3]=8,[2]=6,[1]=4}, -- the heads' colour is rewritten in this many steps over a fade (not every frame)
 Warm=C3(255,168,76),      -- the colour a neon head warms toward ...
 WarmShare=.8,             -- ... by this share at full glow (its own colour keeps the rest)
 Light=1,                  -- real lights at full Cloudy: this x their dark brightness
 Boost={Brightness=.5,Range=.3},    -- R154 (owner: "make each lamp brighter in its warmth during cloudy season too", with the tidy's fewer lamps): at full glow - full Cloudy, and the dark
                           -- (The Darkened, Rain, Thunderstorm) - a real light is this much brighter and further reaching than its base (x1.5 brightness, x1.3 range; the base itself
                           -- is HubLifeArt151.LampLight, 1.8 / 28, up from 1.4 / 22) ...
 LightWarm=C3(255,150,60),  -- ... and its colour warms toward this amber ...
 LightWarmShare=.85,        -- ... by this share at full glow
 Steps=24,                 -- the real lights' brightness is rewritten in this many steps over a fade
}
-- The market's warm lights (the two porch lanterns, the three ceiling lantern lights, the Fruit of the Hour light): always on; in Cloudy they warm
-- and strengthen (client only, tagged WarmLight151 by MarketLayout).
C.Market={Brightness=.8,Range=.25,Warm=C3(255,176,96),WarmShare=.5,Steps=12,Tag='WarmLight151'}

local floor,min,max,abs=math.floor,math.min,math.max,math.abs

-- ------------------------------------------------------------------------------------------------------------------------------------
-- Schedule
-- ------------------------------------------------------------------------------------------------------------------------------------
local function unit(n,salt)
 local h=bit32.bxor((n+100003)*73856093%4294967296,((salt or 0)+101)*83492791%4294967296)
 h=bit32.bxor(h,bit32.rshift(h,13));h=(h*1664525+1013904223)%4294967296;h=bit32.bxor(h,bit32.rshift(h,16))
 return h/4294967296
end
C.Unit=unit
local function period(cfg)return cfg.Clear.Seconds+cfg.Cloudy.Seconds end
C.Period=function(cfg)return period(cfg or C.Config)end
-- Sanity of a config: phases longer than their jitter and fade, a valid fade range. (Tests check the shipped one.)
function C.Check(cfg)
 cfg=cfg or C.Config
 local a,b=cfg.Clear.Seconds,cfg.Cloudy.Seconds
 if type(a)~='number'or type(b)~='number'or a<=0 or b<=0 then return false,'phase lengths'end
 local jitter=cfg.Spread*min(a,b)
 if cfg.Spread<0 or cfg.Spread>.4 then return false,'spread'end
 local f=cfg.Fade
 if type(f)~='table'or f[1]<=0 or f[2]<f[1]then return false,'fade range'end
 if min(a,b)-2*jitter<f[2]*2 then return false,'a phase is shorter than twice its fade'end
 return true
end
-- Server time the n-th segment starts (even n: Clear, odd n: Cloudy).
function C.Boundary(n,cfg)
 cfg=cfg or C.Config
 local p=period(cfg);local jitter=cfg.Spread*min(cfg.Clear.Seconds,cfg.Cloudy.Seconds)
 local at=(n//2)*p+(n%2==1 and cfg.Clear.Seconds or 0)
 return at+(unit(n,1)*2-1)*jitter
end
-- Seconds the switch INTO segment n takes.
function C.FadeSeconds(n,cfg)
 local f=(cfg or C.Config).Fade
 return f[1]+(f[2]-f[1])*unit(n,2)
end
function C.KindOf(n)return n%2==1 and'Cloudy'or'Clear'end
-- The segment at server time t: index, kind, start, end, fade seconds.
function C.Segment(t,cfg)
 cfg=cfg or C.Config
 local k=floor(t/period(cfg))
 for n=2*k+2,2*k-1,-1 do
  local start=C.Boundary(n,cfg)
  if start<=t then return n,C.KindOf(n),start,C.Boundary(n+1,cfg),C.FadeSeconds(n,cfg)end
 end
 local n=2*k-2 -- (unreachable with a checked config: the jitter is far below a phase)
 return n,C.KindOf(n),C.Boundary(n,cfg),C.Boundary(n+1,cfg),C.FadeSeconds(n,cfg)
end

-- ------------------------------------------------------------------------------------------------------------------------------------
-- Level: 0 = Clear .. 1 = Cloudy
-- ------------------------------------------------------------------------------------------------------------------------------------
function C.Smooth(k)k=max(0,min(1,k));return k*k*(3-2*k)end
-- The level of a state ("target kind since fade seconds, starting from level `from`") at `now`.
function C.LevelAt(kind,since,fade,from,now)
 local to=kind=='Cloudy'and 1 or 0
 if type(since)~='number'or type(now)~='number'or since~=since or now~=now then return to end
 if type(fade)~='number'or fade<=0 then return to end
 from=type(from)=='number'and max(0,min(1,from))or(1-to)
 return from+(to-from)*C.Smooth((now-since)/fade)
end
-- A state's level when the server begins a new one now (used by the server: it starts from where the old one got to).
function C.LevelOf(state,now)
 if not state then return 0 end
 return C.LevelAt(state.Kind,state.Since,state.Fade,state.From,now)
end

-- The state travels as one string attribute: "Cloudy|1788123456.250|31.5|0.0000|1788123900.000".
C.Attribute='AmbientSkyState'
C.KindAttribute='AmbientSky'
function C.Pack(kind,since,fade,from,ends)
 return string.format('%s|%.3f|%.3f|%.4f|%.3f',kind,since,fade,from,ends or 0)
end
function C.Unpack(s)
 if type(s)~='string'or #s>96 then return nil end
 local kind,a,b,c,d=s:match('^(%a+)|([%d%.%-]+)|([%d%.%-]+)|([%d%.%-]+)|([%d%.%-]+)$')
 if kind~='Clear'and kind~='Cloudy'then return nil end
 local since,fade,from,ends=tonumber(a),tonumber(b),tonumber(c),tonumber(d)
 if not since or not fade or not from or not ends then return nil end
 if since~=since or fade~=fade or from~=from or fade<=0 or fade>600 or from<0 or from>1 then return nil end
 return{Kind=kind,Since=since,Fade=fade,From=from,Ends=ends}
end
local cache={Raw=nil,State=nil}
-- Client: the level and kind from a storage's attribute (ReplicatedStorage) at server time `now`. No attribute / a damaged one: Clear.
function C.Read(storage,now)
 local raw=storage:GetAttribute(C.Attribute)
 if raw~=cache.Raw then cache.Raw=raw;cache.State=C.Unpack(raw)end
 local s=cache.State
 if not s then return 0,'Clear'end
 return C.LevelAt(s.Kind,s.Since,s.Fade,s.From,now),s.Kind
end

-- ------------------------------------------------------------------------------------------------------------------------------------
-- What a client does with the level
-- ------------------------------------------------------------------------------------------------------------------------------------
-- The level the SKY LIGHTING uses (BiomeMood.Palette's `cloud`): 0 during event weather, in a rare-pull story scene and (Config.Track) on the track.
function C.Effective(level,stage,weather,cinematic,cfg)
 if type(level)~='number'or level<=0 then return 0 end
 if weather~=nil and weather~='Clear'then return 0 end
 if cinematic=='Scene'then return 0 end
 if stage and stage~=0 then return level*max(0,min(1,(cfg or C.Config).Track or 0))end
 return level
end
-- The lamps' glow 0..1 for a (base) sky level: nothing until OnAt, then a smoothstep to full.
function C.LampStrength(level)
 if type(level)~='number'or level<=0 then return 0 end
 local on=C.Lamps.OnAt
 return C.Smooth((level-on)/(1-on))*C.Lamps.Light
end
-- Real lights Cloudy may switch on at a device tier.
function C.RealLights(tier)
 local t=C.Lamps.Real
 return t[floor(tonumber(tier)or 1)]or t[1]
end
function C.Quant(x,steps)return floor(max(0,min(1,x))*steps+.5)/steps end
return C
