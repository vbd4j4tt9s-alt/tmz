-- R149 (owner playtest of R148: "the keyboard tiles are way too small and not tall enough also there are rendering issues ... the same
-- result as the keyboard asmr game where the keyboard tiles are visible from a really long range and it has a really consistent look
-- overall"; "the keyboard is also not consistent with its noise and also keyboard colouring should match their biome").
-- R151 (owner playtest of R149 / R150: "it doesn't push down far enough and also the words are missing, they only appear if under my foot, and
-- also the forest, desert named tiles must also be parallel to the safe zone and horizontal"):
--  * PRESS: a resting key top stands RestRise 1.2 above the floor top, a pressed one PressedRise .05 above it: 1.15 studs of travel (was .47).
--    Runners and keepers stand on the real (hidden) floor at the floor top, so the key under their feet goes down to the floor and the feet
--    stay planted on it; a runner's footprint also reaches PressLead seconds ahead along his velocity, so the key in front is already down
--    when the foot gets there. Release springs back past rest (back-out) and settles.
--  * LETTERS: Roblox lays a SurfaceGui on a part's TOP face out with its x axis toward world -Z and its y axis (down) toward world +X (not
--    x -> +X, y -> +Z as R147 - R150 assumed). Every letter strip was therefore a canvas of (depth x width) = 131 x 1440 px whose labels sat at
--    x offsets up to 1374: only the one label inside the 131 px survived (column 11 / 22 of each row: the owner saw "S", "V" ... in a single
--    line of keys), every label was turned a quarter too far, and the spacebar's name ran ALONG the track. K.TopCanvas / K.TopPoint /
--    Legend.Rotation below are that frame; the letters turn by 270 degrees to read upright (left -> right) for a runner heading +Z.
-- R152 (owner playtest of R151: "keys behind also not rendering and its not loud enough"; his screenshot looked down the track: the far keys were bare
-- caps). Why: the keys of a tier reach 998 / 605 / 368 studs ahead but only 115 / 90 / 65 behind (a camera zoomed out to Roblox's 128 studs sees
-- below and behind its own feet), and the LETTERS stopped at 147 / 98 / 57 studs ahead and 16 / 25 / 16 behind (LegendAhead / LegendBehind rows
-- of full-size strips: 2 SurfaceGuis, 22 labels and 0.75 MB of canvas per row); the guis' own MaxDistance (420) would have cut them anyway. Now:
--  * Back (the keys behind the way the camera faces) is 327 / 229 / 180 studs: past the camera's reach on every tier. Near (14 / 11 / 8 rows,
--    dressed in the frame it is wanted) is what Back used to be; the near letters (LegendBehind / LegendAhead) are unchanged.
--  * FAR LETTERS: every row beyond the near letters, out to FarAhead / FarBehind rows (524 / 360 / 245 studs ahead, 229 / 180 / 147 behind),
--    gets ONE strip (a single SurfaceGui, FarPixelsPerStud 4 = 95 KB of canvas, the whole row's 22 labels) instead of two 16-px strips; the
--    last LegendFade rows fade out. Click: louder (ClickVolume .8 -> 1.8 = +7 dB, ~1.6x as loud) with a wider roll-off (16 .. 90 -> 28 .. 160).
-- Pure config + grid maths for the client script KeyboardTrack.client.lua: no instances, no Roblox services, no randomness (every colour,
-- letter and cell is a function of the grid position, so every client builds the same keyboard).
--
--  GRID   22 big keys across the 180-wide floor (pitch 180/22 = 8.18 studs, ~2.7x R148), column 1 on the +X edge so that a runner heading +Z
--         (+X is on his LEFT) reads Q W E R T Y ... left -> right. Rows run from the first biome's start to BiomeTrackEndZ - 120 (The
--         Darkened's arena keeps its ground). Every biome has its own grid: its first row starts exactly on its BiomeStartZ_n (row pitch =
--         its length / whole rows, 8.17 .. 8.23) and that first row is one cream spacebar with the biome's name.
--  LOOK   ONE look at every distance: every key is the same keycap (ReplicatedStorage.R142Keycap, kept at its own 10.55 x 6.39 proportions
--         so it stays a chunky keycap) in its biome's colours, standing 2.8 studs proud of a sunken bed of the biome's darker grout colour.
--         The pressed key tops sit just above the real floor (runners and keepers stand on them, nothing collides); the real track floor is
--         hidden for this client only (LocalTransparencyModifier), so nothing is ever coplanar with it. No coarse / flat far layers: the keys
--         are built in whole rows around the runner (up to ~1000 studs ahead on tier 3) and recycled. Only what nobody can see at that range
--         drops with distance: the letters (they fade out ~150 studs ahead) and the press animation (other runners / keepers far away).
--  SOUND  one click recording, one pitch band, the same volume rule for every key; every runner (you, each player, each keeper) gets his
--         own steady cadence (at most one click per ClickGap seconds) - no shared budget that starves some presses, no stacked bursts.
--         R153: only a player who really steps on a key sounds (K.Steps / K.Thrown): not a keeper, not a body ragdolled / flung / knocked up.
local K={Version=151}
local floor,ceil,max,min=math.floor,math.ceil,math.max,math.min
local C3=Color3.fromRGB

local REST=1.2                                                 -- resting key top above the floor top (the press travels REST - PressedRise)
K.Config={
 Pitch=180/22,Gap=.5,FieldWidth=180,CenterX=0,           -- 22 keys of 8.18 studs across the 180 floor; Gap = grout between two key boxes
 EndMargin=120,DefaultEndZ=1445,DefaultStartZ=-100,
 SpaceRows=1,                                             -- a biome's spacebar is its first row (one big key, full width)
 TemplateSize={10.55,6.39,10.55},                         -- the R142Keycap mesh's own size (its proportions are kept: KeyY = KeySize * 6.39 / 10.55)
 KeyY=(180/22-.5)*6.39/10.55,                             -- 4.65: the keycap's full height; the lower ~2.5 studs sit below the bed, out of sight
 FloorTop=4.0,RestRise=REST,PressedRise=.05,              -- key top above the floor: resting / pressed (feet stand at the floor top, so a pressed key is level with them)
 TopOffset=0,                                             -- studs added to a mesh key's centre height (mesh top alignment fudge, tune in Studio)
 UseKeycapMesh=true,                                      -- false = every key is a plain block (same size / colours) if the mesh costs too much on phones
 BedDepth=1.6,BedThickness=1,BedMaxLength=1024,           -- the grout bed's top is BedDepth below the floor top: resting keys stand 2.8 proud, pressed ones 1.65
 RimWidth=.65,RimInset=.05,RimDrop=.04,                   -- the frame closing the keyboard's sides / ends (its top .04 under the floor top: clear of the lobby / arena floor, R149 review part 2)
 PressSeconds=.06,ReleaseSeconds=.2,                      -- quad-out down (snappy), back-out up (springs ~10% of the travel past rest, then settles)
 PressLead=.06,PressLeadMax=4,                            -- the local runner's footprint also covers this many seconds of his velocity ahead (at most PressLeadMax studs): the key in front is down when the foot arrives
 HoleLift=REST+.06,                                       -- shovel-hole parts (authored a few hundredths above the floor) are lifted onto the key tops (+.06: the rim stays over the letter strips, R149 review part 2 / R151)
 HoleCeiling=1,                                           -- R153: a shovel-hole part more than this above the resting key tops is stranded in the air (a lifted part stands at most .6 + .2 + HoleLift over the floor): it is put back
 HoleReach=4.6,                                          -- keys within this many studs of a hole's Pit stay up (unpressable) while it exists (R153: 2 -> 3 = the bigger hole's rim radius, TrackHoleConfig Diameter/2 + RimWidth = 3.0; R153 review: 3 -> 4.6 = the farthest crumb of the ring as well, + TrackHoleConfig CrumbSpread 1.1 + CrumbSizeMax .5: a crumb over a key that could be pressed hung in the air)
 PlatformClearance=.3,                                    -- keys under a pack platform (radius + this) are held down: the platform shows on them
 PlayerFootprint=1.2,PlayerFeetReach=3,PlayerRootToFeet=3,-- half-size of a runner's footprint; others press while their feet are within 3 studs of the floor
 KeeperMinFootprint=1.5,KeeperMaxFootprint=6,KeeperFootprintShare=.3,
 PlayerSampleHz=30,
 StepReach=1.2,StepMaxRise=18,                            -- R153: a press SOUNDS only for a runner who really steps on a key: feet within StepReach of the floor top and not flying up faster than StepMaxRise studs/s (K.Steps), not ragdolled / flung / knocked back (K.Thrown)
 -- clicks: ONE recording (the first id; the other two R147 recordings are kept for reference only), a narrow pitch band, one volume
 -- rule (3D roll-off from the key) for every presser, and a steady per-presser cadence.
 ClickSoundIds={113108830240353,88838553648526,96591611478915},ClickSoundId=113108830240353,
 ClickPitches={.98,1.01,.99,1.02,1.0},                    -- each presser cycles through these (0.98 .. 1.02)
 KeeperPitch=.94,                                         -- keepers: the same click, a touch deeper
 -- R152 ("not loud enough"): volume .8 -> 1.8 (x2.25 = +7 dB, ~1.6x as loud), 3D roll-off 16 .. 90 -> 28 .. 160 studs (the camera trails the runner by
 -- 12 .. 128 studs, so his own click used to be past the full-volume radius; presses a little ahead are heard); a slight per-click gain keeps
 -- 12 overlapping voices from sounding like one flat block (never above ClickVolume: the peak is unchanged).
 ClickVolume=1.8,ClickRollOffMin=28,ClickRollOffMax=160,ClickRange=160,ClickVoices=12,ClickGains={1,.94,.97,.91},
 -- R152 (owner: "this audio is played for all keys which are as wide and big as the forest jungle keys so it goes for snow and lava and crystal and so on too"): by KEY
 -- KIND, not biome. Every normal letter key of every biome plays PressSound.Key; a spacebar (the one huge full-width key at the start of each biome) plays PressSound.Spacebar,
 -- the original click. A kind with no entry plays the click. PressSoundVolume = the peak volume of the Key sound (it starts at the click's: nobody could hear the asset when
 -- this was written, so TUNE IT BY EAR HERE); the spacebar's click plays at ClickVolume. PressSoundBiome = an optional per-biome override of the Key sound by biome NAME
 -- (K.BiomeNames; empty: e.g. {Desert='rbxassetid://123'}). Same 3D roll-off / range / cadence / gain cycle as the click; one pool of ClickVoices voices per sound.
 PressSound={Key='rbxassetid://73942179280083',Spacebar='rbxassetid://113108830240353'},
 PressSoundVolume=1.8,
 PressSoundBiome={},
 ClickGap=1/12,                                           -- per presser: at most one click every 1/12 s, evenly spaced while sprinting
 TierHoldSeconds=3,                                       -- a ClientFxBudget tier change applies after it has held this long
 TeleportBurst=4,                                         -- the far rows of a window whose rows around the runner were missing (a teleport) are
                                                          -- dressed at x this Bind; the near zone itself is always dressed at once (below)
 -- R151 (owner: "keys present on the right of the track but a large area ... shows flat floor with no keys"; on a phone "almost no keys around
 -- the player"): the window's long side used to follow only the camera's LookVector.Z with a +-0.25 dead zone that KEPT the old way - a camera
 -- looking across the track (or down at the runner, on a portrait phone) after a run back to base still had its long side behind it and only
 -- Back rows (5 .. 12 = 41 .. 98 studs) where it looked: bare bed beyond. Now the camera's HEADING (its look direction flattened) picks one of
 -- three ways: along the track +Z / -Z (heading within ~41 degrees of the axis: the long side that way) or ACROSS it (heading within ~57 degrees
 -- of sideways, or straight down: a symmetric window, Side rows each way). Between those bands the current way is kept (no flicker), and a
 -- change holds FacingHoldSeconds. Every way keeps the NEAR zone (Near rows each side of the runner) and the near zone is dressed in the same
 -- frame whatever the budget (a teleport, a respawn, a tier change); the far rows that are still being dressed show a flat stand-in in the
 -- biome's key colour (Filler) instead of bare bed.
 FacingAlong=.75,FacingAcross=.55,FacingHoldSeconds=.2,    -- |heading.Z| >= FacingAlong: along the track; <= FacingAcross: across it
 FillerDrop=.08,FillerSlabs=8,                            -- the stand-in's top lies FillerDrop under the resting key tops; at most this many slabs
 CameraAbove=.6,                                          -- the camera never sinks under (resting key top + this = 5.8): the real floor is hidden, so it no
                                                          -- longer stops the default camera (Popper) from dropping into the keys / under the bed
 -- letters: PixelsPerStud on every letter SurfaceGui (TextHeight * PixelsPerStud = TextSize <= 100), Margin = the strip's top above the VISIBLE top of
 -- a resting key (the client measures that top from the keycap template: Legend.MaxExtra caps what a measurement may add; R152 z-fighting: .05, not .04: a strip's face and a key's top
 -- overlap over the whole key, and the R149 depth rule wants .043 at 300 studs), Rotation = the label's
 -- turn on the Top-face canvas (270: upright, reading left -> right for a runner heading +Z), KeysPerStrip = letters per SurfaceGui (a half row),
 -- MaxDistance = the guis' own render limit, RowsPerFrame = rows of letters dressed per frame (4, so a camera turn spreads the letters over several
 -- frames). The spacebars' biome names are big: they get their own render limit.
 Legend={PixelsPerStud=16,TextHeight=4.6,Margin=.05,MaxExtra=1.5,Rotation=270,KeysPerStrip=11,MaxDistance=420,Font='FredokaOne',RowsPerFrame=4,
  FarPixelsPerStud=4,FarMaxDistance=800,                   -- R152: far letters, one strip (22 labels, 18 px text) per row at 4 px / stud, rendered out to 800 studs
  FarMaxDistanceByTier={[2]=500},                          -- R153 perf (lag audit D8): on tier 2 (phones) to 500 studs (a 4.6-stud letter is about 6 px tall there)
  PixelsPerStudByTier={[1]=12,[2]=12}},                    -- R154 (lag audit B3, owner-approved): the NEAR letters (strips and pressed-key letters) at 12 px / stud on tier 2, R155 (owner: tier 1 too) on tier 1 (16 on tier 3: PC unchanged); K.NearPPS
 SpacebarPixelsPerStud=10,SpacebarMaxDistance=800,
 GroundScanSeconds=2,
}
local C=K.Config
K.StageCount=7
-- Stable stage ids (not track order): Forest 1, Desert 2, Snow 3, Lava 4, Crystal 5, Jungle 6, Storm Peaks 7.
-- The map may override a name with a BiomeName_<id> attribute.
K.BiomeNames={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm Peaks'}
-- R149 (owner: "keyboard colouring should match their biome"): each biome's keys take that biome's own colours, four shades per biome;
-- a key's shade is a hash of its cell (never a per-row cycle). Sources (the biome data in this repo):
--  Forest  grass ground 82,180,87 (the map's BiomeGround_1, as sampled by the R143 keyboard), Trail Runner trim 106,195,101, pack trim 108,135,61
--  Jungle  ground 78,133,62, Vine Runner trim 51,190,127 (jungle teal), pack body 114,143,65: deep greens and lime
--  Desert  ground 224,188,103, pack stone 200,164,109, Dune Runner 251,202,130 / 232,141,90: sand and tan
--  Snow    ground 176,194,204 (BiomeVisuals), drifts 198,212,220, ice 111,171,192, Glacier Runner 135,203,234: white and ice blue
--  Lava    basalt ground 56,57,66 (BiomeVisuals), magma 223,66,13 / 246,119,28, channels 189,59,21, pack trim 177,66,42: dark red / orange
--  Crystal ground 94,78,123 (BiomeVisuals), prisms 113,76,166 .. 204,178,237, Prism Runner 217,181,250: purple / pink
--  Storm   slate ground 88,111,144, pack body 105,113,146, violet trim 173,150,220: dark grey / blue-violet
-- Bed = the grout between the keys (a darker tone of the same biome). Ink = the letter colour on a dark shade, InkLight on the others
-- (K.InkRGB picks whichever reads better on each shade; every pair is >= 3.5:1, most >= 4.5:1).
K.Zones={
 [1]={Name='Forest',Family='grass green',Shades={{96,186,90},{130,204,102},{74,156,72},{164,218,120}},Bed={46,104,46},Ink={16,48,20},InkLight={244,252,232}},
 [6]={Name='Jungle',Family='deep green / lime',Shades={{66,124,58},{98,156,66},{150,198,72},{44,146,100}},Bed={36,82,40},Ink={14,40,18},InkLight={240,252,224}},
 [2]={Name='Desert',Family='sand / tan',Shades={{228,192,112},{244,216,152},{206,164,100},{236,178,112}},Bed={150,112,64},Ink={84,50,20},InkLight={255,248,230}},
 [3]={Name='Snow',Family='white / ice blue',Shades={{238,244,248},{206,224,236},{170,208,232},{222,234,242}},Bed={124,154,176},Ink={40,72,104},InkLight={255,255,255}},
 [4]={Name='Lava',Family='dark red / orange',Shades={{150,36,28},{198,58,26},{236,108,34},{112,30,30}},Bed={62,42,44},Ink={54,14,8},InkLight={255,232,196}},
 [5]={Name='Crystal',Family='purple / pink',Shades={{150,108,208},{190,156,236},{118,80,170},{222,156,226}},Bed={80,58,118},Ink={46,22,78},InkLight={252,244,255}},
 [7]={Name='Storm Peaks',Family='storm grey / blue-violet',Shades={{84,98,128},{108,118,156},{130,122,178},{68,76,100}},Bed={46,52,68},Ink={18,20,34},InkLight={246,242,255}},
}
K.Fallback={Name='Track',Family='cream',Shades={{255,214,180},{255,226,200},{240,198,166},{250,208,176}},Bed={120,88,70},Ink={84,48,33},InkLight={255,250,240}}
K.Cream={255,250,236}                                -- the spacebar
K.CreamInk={84,48,33}
-- Legend rows: a runner reads each row left -> right in keyboard order (the string repeats across the columns).
K.LegendRows={'QWERTYUIOP','ASDFGHJKL','ZXCVBNM','1234567890'}
K.JitterAmount=.04

-- Easing (t in 0..1 -> 0..1; BackOut overshoots, then settles at 1).
K.Ease={
 Linear=function(t)return t end,
 QuadOut=function(t)return 1-(1-t)*(1-t)end,
 BackOut=function(t)local c1=1.70158;local c3=c1+1;local u=t-1;return 1+c3*u*u*u+c1*u*u end,
}

-- Per ClientFxBudget tier (3 best .. 1 lowest; phones start on 2, a slow device drops to 1). Rows of keys around the runner (all columns, all the
-- same keycap): Back / Ahead = key rows behind / ahead of the runner's row along the camera's way (R152: Back covers a camera zoomed out to
-- 128 studs: 327 / 229 / 180 studs, was 115 / 90 / 65; a camera looking across the track gets Side = (Back + Ahead) / 2 rows each way, the same
-- number of keys), Near = the rows each side of the runner that are dressed in the very frame they are wanted whatever the budget (R151: what
-- Back was), Hyst = extra rows kept before a row is recycled (no flicker at the window edge), Bind = keys dressed per frame (x min(2, dt * 60)).
-- Letters: LegendBehind / LegendAhead rows carry full-size letters (the near strips, two 16 px / stud SurfaceGuis a row, unchanged); beyond them
-- FarBehind / FarAhead rows (from the runner, the way the camera faces; across the track (FarSide) each way) carry the far letters, one 4 px / stud
-- strip a row, FarRows rows dressed per frame, the last LegendFade rows fading out; LegendRadius = the letters under and around the runner's feet
-- are always shown (other effects keep clear of that radius, e.g. the Snow-biome dust). PressRange = other runners / keepers farther than this
-- (along the track) press nothing. KeyLegends = pooled letters for keys that are down (a key's letter rides with it while it moves).
K.Tiers={
 [3]={Near=14,Back=40,Ahead=122,Hyst=4,Bind=264,LegendBehind=2,LegendAhead=18,FarBehind=28,FarAhead=64,FarRows=4,LegendFade=4,LegendRadius=24,PressRange=260,KeyLegends=48},
 [2]={Near=11,Back=28,Ahead=56,Hyst=2,Bind=198,LegendBehind=2,LegendAhead=12,FarBehind=22,FarAhead=44,FarRows=3,LegendFade=3,LegendRadius=20,PressRange=200,KeyLegends=32},
 [1]={Near=8,Back=22,Ahead=45,Hyst=1,Bind=132,LegendBehind=1,LegendAhead=7,FarBehind=18,FarAhead=30,FarRows=2,LegendFade=2,LegendRadius=16,PressRange=150,KeyLegends=16},
}
function K.Tier(tier)return K.Tiers[tier]or K.Tiers[3]end
-- R154 (lag audit B3, owner: "for the lag fixes we can implement B3 and B1"): phones (tier 2) carry 56 key rows ahead (74 before: the keys end ~460 studs ahead, not
-- ~600) and their near letters are drawn at 12 px / stud (16 before: a canvas 44% smaller, the letters a little softer); tier 3 (PC) is unchanged.
-- R155 (owner: "yes" to the lighter phone keyboard on the lowest graphics setting too): tier 1 draws its near letters at 12 px / stud as well. Its key rows ahead are 45, already
-- under tier 2's 56, so they stay.
-- K.NearPPS(tier) = the near letters' pixels a stud on a tier, K.NearText(pps) = their TextSize. The client reads both and re-applies them on a tier change
-- (K.RetuneLetters: every strip and pressed-key letter already made), the way R153's far-letter render limit (Legend.FarMaxDistanceByTier) is.
function K.NearPPS(tier)local by=C.Legend.PixelsPerStudByTier;return by and by[tier]or C.Legend.PixelsPerStud end
function K.NearText(pps)return min(100,floor(C.Legend.TextHeight*pps+.5))end
-- pools = {free strips by half row, their counts, rows with strips, strips by row, pooled pressed-key letters}: the client's own tables (it names them; this module
-- only reads them). A strip's label positions are canvas pixels (K.TopPoint), proportional to the pixels a stud, so they scale with it.
function K.RetuneLetters(pps,text,keyWidth,pools)
 local free,freeN,rows,of,keyLetters=pools[1],pools[2],pools[3],pools[4],pools[5]
 local function strip(st)
  local ratio=pps/st.Gui.PixelsPerStud
  if ratio==1 then return end
  st.Gui.PixelsPerStud=pps
  for i,l in ipairs(st.Labels)do
   l.TextSize=text;l.Size=UDim2.fromOffset(keyWidth*pps,keyWidth*pps)
   local px=st.PX[i]
   if px then px*=ratio;local py=st.PY[i]*ratio;st.PX[i]=px;st.PY[i]=py;l.Position=UDim2.fromOffset(px,py)end
  end
 end
 for k=1,#free do for i=1,freeN[k]do strip(free[k][i])end end
 for _,r in ipairs(rows)do for _,st in ipairs(of[r])do strip(st)end end
 for _,e in ipairs(keyLetters)do if e.Gui.PixelsPerStud~=pps then e.Gui.PixelsPerStud=pps;e.Label.TextSize=text end end
end

-- Deterministic integer hash (no randomness): three small non-negative integers -> 0 .. 2^32-1.
local function hash(a,b,c)
 local h=bit32.bxor(a*73856093,b*19349663)
 h=bit32.bxor(h,c*83492791)
 h=bit32.bxor(h,bit32.rshift(h,13));h=(h*1664525+1013904223)%4294967296;h=bit32.bxor(h,bit32.rshift(h,16))
 return h
end
K.Hash=hash

-- Colour maths (sRGB relative luminance and the WCAG contrast ratio).
local function lin(c)c=c/255;if c<=.04045 then return c/12.92 end;return((c+.055)/1.055)^2.4 end
function K.Luminance(rgb)return .2126*lin(rgb[1])+.7152*lin(rgb[2])+.0722*lin(rgb[3])end
function K.Contrast(a,b)local la,lb=K.Luminance(a),K.Luminance(b);if la<lb then la,lb=lb,la end;return(la+.05)/(lb+.05)end

-- Zone of a stage id; shade index 1..4 of a key (stage, row, column) - a hash of the cell, never the row alone.
function K.Zone(stage)return K.Zones[stage]or K.Fallback end
function K.ShadeIndex(stage,row,col,m)
 local z=K.Zone(stage)
 return hash(floor(row),floor(col),floor(m or 1)*8+(tonumber(stage)or 0))%#z.Shades+1
end
-- +-4% brightness on top of the shade (a second hash).
function K.Jitter(row,col,m)
 local h=hash(floor(col)+977,floor(row)+31,floor(m or 1)*8+5)
 return 1+(h/4294967295*2-1)*K.JitterAmount
end
function K.CellRGB(stage,row,col,m)
 local z=K.Zone(stage);local s=z.Shades[K.ShadeIndex(stage,row,col,m)];local j=K.Jitter(row,col,m)
 return min(255,floor(s[1]*j+.5)),min(255,floor(s[2]*j+.5)),min(255,floor(s[3]*j+.5))
end
function K.CellColor(stage,row,col,m)local r,g,b=K.CellRGB(stage,row,col,m);return C3(r,g,b)end
-- Letter ink for a shade: the zone's dark ink or its light ink, whichever contrasts more with that shade (cached per zone and shade).
local inkCache={}
function K.ShadeInk(stage,shade)
 local z=K.Zone(stage);local key=z
 local cache=inkCache[key];if not cache then cache={};inkCache[key]=cache end
 local ink=cache[shade]
 if not ink then
  local s=z.Shades[shade]or z.Shades[1]
  ink=K.Contrast(s,z.Ink)>=K.Contrast(s,z.InkLight)and z.Ink or z.InkLight
  cache[shade]=ink
 end
 return ink
end
function K.InkRGB(stage,row,col)
 local ink=K.ShadeInk(stage,row and col and K.ShadeIndex(stage,row,col,1)or 1)
 return ink[1],ink[2],ink[3]
end
function K.BedRGB(stage)local b=K.Zone(stage).Bed;return b[1],b[2],b[3]end
function K.CreamRGB()return K.Cream[1],K.Cream[2],K.Cream[3]end
-- The letter on a key, by fine row and column (column 1 is the +X edge = a heading-+Z runner's left): each keyboard row repeats
-- left -> right, and the start drifts every four rows so the letters do not line up in columns.
function K.Legend(row,col)
 local r=floor(row)
 local line=K.LegendRows[(r-1)%#K.LegendRows+1]
 local drift=((r-1)//#K.LegendRows*3)%#line
 local i=(floor(col)-1+drift)%#line+1
 return line:sub(i,i)
end

-- Heights: depth 0 = resting, 1 = pressed (BackOut may dip below 0 for a moment = the key springs past rest).
function K.KeyTop(depth)return C.FloorTop+C.RestRise-(C.RestRise-C.PressedRise)*depth end
function K.KeyCenterY(depth)return K.KeyTop(depth)-C.KeyY/2+C.TopOffset end
function K.PressTravel()return C.RestRise-C.PressedRise end
function K.BedTop()return C.FloorTop-C.BedDepth end

-- The Top-face SurfaceGui frame (R151, measured from the owner's live screenshots of R149): on a part with no rotation the canvas x axis (reading
-- direction of an unrotated label) points toward world -Z and the canvas y axis (down the canvas) toward world +X; the canvas is therefore
-- (Size.Z x Size.X) * PixelsPerStud, not (Size.X x Size.Z). A label turned by GuiObject.Rotation = a degrees (clockwise) reads along
-- (sin a, -cos a) in world (x, z) and has its up toward (-cos a, -sin a): a = 270 reads toward -X (a +Z runner's right) with its up toward +Z.
--   K.TopCanvas(sizeX, sizeZ, pps)               -> canvas width, height (pixels)
--   K.TopPoint(cx, cz, sizeX, sizeZ, pps, wx, wz) -> canvas x, y (pixels) of the world point (wx, wz) on the Top face of a part centred at (cx, cz)
--   K.TopWorld(cx, cz, sizeX, sizeZ, pps, px, py) -> the inverse: world x, z of canvas point (px, py)
--   K.TopReading(a)                              -> (x, z) world direction a label turned by a degrees reads along; K.TopUp(a) its up direction
function K.TopCanvas(sizeX,sizeZ,pps)return sizeZ*pps,sizeX*pps end
function K.TopPoint(cx,cz,sizeX,sizeZ,pps,wx,wz)return(cz+sizeZ/2-wz)*pps,(wx-(cx-sizeX/2))*pps end
function K.TopWorld(cx,cz,sizeX,sizeZ,pps,px,py)return cx-sizeX/2+py/pps,cz+sizeZ/2-px/pps end
function K.TopReading(a)local r=math.rad(a);return math.sin(r),-math.cos(r)end
function K.TopUp(a)local r=math.rad(a);return-math.cos(r),-math.sin(r)end

-- How far the VISIBLE top of a key stands above the configured one (studs, >= 0), from what the client could measure on a clone of the keycap
-- template sized like a key: sizeY = that clone's Size.Y (the engine may not give back what was asked), meshExtra = what a SpecialMesh child
-- adds above the part's top (its Offset.Y plus any scale above 1), hits = heights of downward ray hits on the clone's top (absolute Y, may be
-- empty) with probeTop = the configured top of the clone at the time. The biggest of the three wins, capped at Legend.MaxExtra: a bad
-- measurement can never fling the letters away.
function K.TopExtra(keyY,sizeY,meshExtra,probeTop,hits)
 local extra=0
 if type(sizeY)=='number'and sizeY==sizeY and sizeY>keyY then extra=max(extra,(sizeY-keyY)/2)end
 if type(meshExtra)=='number'and meshExtra==meshExtra then extra=max(extra,meshExtra)end
 if type(hits)=='table'and type(probeTop)=='number'then
  for _,y in ipairs(hits)do if type(y)=='number'and y==y then extra=max(extra,y-probeTop)end end
 end
 if extra<.005 then return 0 end
 return min(extra,C.Legend.MaxExtra)
end
function K.KeySize(pitch)return(pitch or C.Pitch)-C.Gap end
function K.KeeperFootprint(extentX,extentZ)
 return math.clamp(C.KeeperFootprintShare*min(extentX,extentZ),C.KeeperMinFootprint,C.KeeperMaxFootprint)
end

-- BiomeAt(z, attrs): the stage id (and its name) whose BiomeStartZ_n <= z < BiomeEndZ_n, else 0. attrs = the map's attributes.
function K.BiomeAt(z,attrs)
 if type(attrs)~='table'or type(z)~='number'then return 0,nil end
 for n=1,K.StageCount do
  local a,b=attrs['BiomeStartZ_'..n],attrs['BiomeEndZ_'..n]
  if type(a)=='number'and type(b)=='number'and z>=a and z<b then
   local name=attrs['BiomeName_'..n]
   return n,(type(name)=='string'and name~=''and name or K.BiomeNames[n])
  end
 end
 return 0,nil
end

-- R152 (owner: "for some areas on the track like this make sure that there is no keyboard tiles there": a desert oasis with keys inside and under the water): the
-- cells the keyboard leaves out are DATA, written once by the server (KeyboardSkip152.Apply scans the finished map for water / lava / ice pools, pits and props
-- standing on the floor) into the map attribute KeyboardSkip, so every client, key, letter and press agrees: "1|<cols>|<rows>|<centerX>|<row>:<a>-<b>,<c>;<row>:..."
-- (column runs per row). A string for another grid (other columns / rows / centre) is ignored: the keys are then everywhere, as before R152.
local skipMemo={Str=nil,Cols=0,NRows=0,X=0,Set=nil,Rows=nil,N=0}
function K.EncodeSkip(set,cols,rows,centerX)
 local byRow,rowList={},{}
 for key in pairs(set)do
  local r,c=key//64,key%64
  local l=byRow[r];if not l then l={};byRow[r]=l;rowList[#rowList+1]=r end
  l[#l+1]=c
 end
 table.sort(rowList)
 local out={}
 for _,r in ipairs(rowList)do
  local l=byRow[r];table.sort(l);local runs={};local a=l[1];local b=a
  for i=2,#l do if l[i]==b+1 then b=l[i]else runs[#runs+1]=a==b and tostring(a)or(a..'-'..b);a=l[i];b=a end end
  runs[#runs+1]=a==b and tostring(a)or(a..'-'..b)
  out[#out+1]=r..':'..table.concat(runs,',')
 end
 return string.format('1|%d|%d|%.3f|',cols,rows,centerX)..table.concat(out,';')
end
function K.DecodeSkip(str,cols,rows,centerX)
 if type(str)~='string'then return {},{},0 end
 if skipMemo.Str==str and skipMemo.Cols==cols and skipMemo.NRows==rows and skipMemo.X==centerX then return skipMemo.Set,skipMemo.Rows,skipMemo.N end
 local set,rc,n={},{},0
 local v,c0,r0,x0,body=str:match('^(%d+)|(%d+)|(%d+)|(-?[%d.]+)|(.*)$')
 if v=='1'and tonumber(c0)==cols and tonumber(r0)==rows and math.abs((tonumber(x0)or 1e9)-centerX)<.01 then
  for entry in body:gmatch('[^;]+')do
   local r,runs=entry:match('^(%d+):(.+)$');r=tonumber(r)
   if r and r>=1 and r<=rows then
    for run in runs:gmatch('[^,]+')do
     local a,b=run:match('^(%d+)-(%d+)$');if not a then a=run:match('^(%d+)$');b=a end
     a,b=tonumber(a),tonumber(b)
     if a and b then for col=max(1,a),min(cols,b)do if not set[r*64+col]then set[r*64+col]=true;rc[r]=(rc[r]or 0)+1;n+=1 end end end
    end
   end
  end
 end
 skipMemo.Str,skipMemo.Cols,skipMemo.NRows,skipMemo.X,skipMemo.Set,skipMemo.Rows,skipMemo.N=str,cols,rows,centerX,set,rc,n
 return set,rc,n
end

-- Geometry(attrs, centerX, fieldWidth): the whole grid for this map. Fields: Pitch (= fieldWidth / Cols exactly, so the keys run edge to
-- edge), Cols, HalfWidth, CenterX, Z0 (start of the first biome), KeyEndZ (BiomeTrackEndZ - 120), Rows (all rows, spacebars included),
-- Segs (one per biome, sorted by start: {Id, Name, StartZ, EndZ, Rows, FirstRow, LastRow, RowPitch, SpaceLast, KeyFirst}), RowSeg[row],
-- RowStage[row], Bars (one spacebar per biome: {Seg, Stage, Name, Row0, Row1, Z0, Z1}), BarOfRow[row], Skip / RowSkip / SkipCount (R152: the cells left out,
-- see K.EncodeSkip; Skipped(row, col)). Helpers (call with a dot):
-- ColCenter(col), ColOfX(x), RowZ(row) -> zmin,zmax, RowOfZ(z), CellCenter(row,col) -> x,z, CellRange(xmin,xmax,zmin,zmax) -> c1,c2,r1,r2
-- (no allocation; empty when c1>c2 or r1>r2), CellsInRect(...) -> list of {row=,col=}, BiomeAt(z).
function K.Geometry(attrs,centerX,fieldWidth)
 attrs=type(attrs)=='table'and attrs or {}
 centerX=type(centerX)=='number'and centerX or C.CenterX
 fieldWidth=type(fieldWidth)=='number'and fieldWidth>0 and fieldWidth or(type(attrs.FieldWidth)=='number'and attrs.FieldWidth>0 and attrs.FieldWidth or C.FieldWidth)
 local stages={}
 for n=1,K.StageCount do
  local a,b=attrs['BiomeStartZ_'..n],attrs['BiomeEndZ_'..n]
  if type(a)=='number'and type(b)=='number'and b>a then
   local name=attrs['BiomeName_'..n]
   stages[#stages+1]={Id=n,StartZ=a,EndZ=b,Name=type(name)=='string'and name~=''and name or K.BiomeNames[n]}
  end
 end
 table.sort(stages,function(p,q)return p.StartZ<q.StartZ end)
 local endZ=attrs.BiomeTrackEndZ
 if type(endZ)~='number'then endZ=#stages>0 and stages[#stages].EndZ or C.DefaultEndZ end
 local cols=max(1,floor(fieldWidth/C.Pitch+.5));local P=fieldWidth/cols;local half=fieldWidth/2
 local z0=#stages>0 and stages[1].StartZ or C.DefaultStartZ
 local keyEnd=endZ-C.EndMargin
 local g={Pitch=P,Cols=cols,HalfWidth=half,CenterX=centerX,Z0=z0,EndZ=endZ,KeyEndZ=keyEnd,Segs={},RowSeg={},RowStage={},Bars={},BarOfRow={}}
 local rows=0
 if #stages==0 then stages[1]={Id=0,StartZ=z0,EndZ=endZ,Name='Track'}end
 for i,s in ipairs(stages)do
  local a=s.StartZ;local b=stages[i+1]and stages[i+1].StartZ or keyEnd;b=min(b,keyEnd)
  if b-a>=P*(C.SpaceRows+1)*.75 then
   local n=max(C.SpaceRows+1,floor((b-a)/P+.5));local p=(b-a)/n
   local seg={Id=s.Id,Name=s.Name,StartZ=a,EndZ=b,Rows=n,FirstRow=rows+1,LastRow=rows+n,RowPitch=p,SpaceLast=rows+C.SpaceRows,KeyFirst=rows+C.SpaceRows+1}
   g.Segs[#g.Segs+1]=seg;local si=#g.Segs
   for r=seg.FirstRow,seg.LastRow do g.RowSeg[r]=si;g.RowStage[r]=s.Id end
   local bar={Seg=si,Stage=s.Id,Name=s.Name,Row0=seg.FirstRow,Row1=seg.SpaceLast,Z0=a,Z1=a+C.SpaceRows*p}
   g.Bars[#g.Bars+1]=bar
   for r=bar.Row0,bar.Row1 do g.BarOfRow[r]=#g.Bars end
   rows+=n
  end
 end
 g.Rows=rows
 -- R152: cells the keyboard leaves out (water, lava, pits, props: see KeyboardSkip152). Skip = set of row * 64 + col, RowSkip[row] = how many cells of that row, SkipCount.
 g.Skip,g.RowSkip,g.SkipCount=K.DecodeSkip(attrs.KeyboardSkip,cols,rows,centerX)
 function g.Skipped(row,col)return g.Skip[row*64+col]==true end
 local segs=g.Segs
 local left=centerX+half   -- column 1's outer edge (+X side)
 function g.ColCenter(col)return left-(col-.5)*P end
 -- (a 1e-10 row nudge: z = StartZ + k * RowPitch must land in row k + 1 although the division may round just below k)
 function g.ColOfX(x)return floor((left-x)/P+1e-10)+1 end
 function g.RowZ(row)
  local s=segs[g.RowSeg[row]];if not s then return nil end
  local a=s.StartZ+(row-s.FirstRow)*s.RowPitch;return a,a+s.RowPitch
 end
 function g.RowOfZ(z)
  if rows==0 or z<z0 then return 0 end
  for i=1,#segs do local s=segs[i];if z<s.EndZ then return s.FirstRow+floor((z-s.StartZ)/s.RowPitch+1e-10)end end
  return rows+1
 end
 function g.CellCenter(row,col)
  local a,b=g.RowZ(row);return left-(col-.5)*P,(a+b)/2
 end
 function g.CellRange(xmin,xmax,zmin,zmax)
  if xmin~=xmin or xmax~=xmax or zmin~=zmin or zmax~=zmax then return 1,0,1,0 end
  if xmax<xmin then xmin,xmax=xmax,xmin end
  if zmax<zmin then zmin,zmax=zmax,zmin end
  -- Open intervals: a rect that only touches a cell edge does not claim the neighbour (a degenerate rect = one point).
  local c1=floor((left-xmax)/P+1e-10)+1;local c2=xmax>xmin and ceil((left-xmin)/P-1e-10)or c1
  local r1=g.RowOfZ(zmin);local r2=zmax>zmin and g.RowOfZ(zmax-1e-9)or r1
  return max(c1,1),min(c2,cols),max(r1,1),min(r2,rows)
 end
 function g.CellsInRect(xmin,xmax,zmin,zmax)
  local out={};local c1,c2,r1,r2=g.CellRange(xmin,xmax,zmin,zmax)
  for r=r1,r2 do for c=c1,c2 do out[#out+1]={row=r,col=c}end end
  return out
 end
 function g.BiomeAt(z)
  for i=1,#segs do local s=segs[i];if z>=s.StartZ and z<s.EndZ then return s.Id,s.Name end end
  return 0,nil
 end
 return g
end

-- The rows of keys around a focus row (spacebar rows included: the bars are always drawn, the client skips them). facing = +1 when the
-- camera looks toward +Z (into the biomes), -1 toward -Z (back to base): Ahead rows lie that way, Back rows the other; 0 (R151) when it looks
-- across the track or straight down: Side rows each way. Returns ra, rb (rows wanted) and ka, kb (rows kept: a bound row outside ka .. kb is
-- recycled), all clamped to 1 .. Rows.
function K.Side(tier)local t=K.Tier(tier);return(t.Back+t.Ahead)//2 end
function K.Near(tier)local t=K.Tier(tier);return t.Near or t.Back end
function K.KeyWindow(geo,tier,focusRow,facing)
 local t=K.Tier(tier);local n=geo.Rows
 local f=max(1,min(n,focusRow))
 local lo,hi=t.Back,t.Ahead
 if facing==-1 then lo,hi=hi,lo elseif facing==0 then lo=K.Side(tier);hi=lo end
 return max(1,f-lo),min(n,f+hi),max(1,f-lo-t.Hyst),min(n,f+hi+t.Hyst)
end
-- Most keys a tier ever has bound at once: the kept window (wanted rows + hysteresis on both sides) times the columns.
function K.KeyCap(tier,cols)local t=K.Tier(tier);return(t.Back+t.Ahead+1+2*t.Hyst)*cols end
-- Rows whose letters are shown (facing as for KeyWindow; across the track: half the letter rows each way), and the letters' transparency at a
-- row d rows from the runner (d = row - focusRow, signed; 0 = solid; the farthest LegendFade rows fade out; behind the runner they stay
-- solid). Called with facing nil, d counts rows ahead in the window's way (R149 callers).
function K.LegendSide(tier)local t=K.Tier(tier);return max(t.LegendBehind,ceil((t.LegendBehind+t.LegendAhead)/2))end
function K.LegendWindow(geo,tier,focusRow,facing)
 local t=K.Tier(tier);local n=geo.Rows;local f=max(1,min(n,focusRow))
 local lo,hi=t.LegendBehind,t.LegendAhead
 if facing==-1 then lo,hi=hi,lo elseif facing==0 then lo=K.LegendSide(tier);hi=lo end
 return max(1,f-lo),min(n,f+hi)
end
-- Which way the window should face for the camera's look direction (lookZ, and lookX when known: its heading along the track is then
-- lookZ / |(lookX, lookZ)|; a camera looking straight down has no heading = across). Keeps `current` between the two bands.
function K.Facing(lookZ,current,lookX)
 if type(lookZ)~='number'or lookZ~=lookZ then return current or 1 end
 local h=lookZ
 if type(lookX)=='number'and lookX==lookX then
  local l=math.sqrt(lookX*lookX+lookZ*lookZ)
  if l<.1 then return 0 end
  h=lookZ/l
 end
 if h>=C.FacingAlong then return 1 elseif h<=-C.FacingAlong then return -1 end
 if math.abs(h)<=C.FacingAcross then return 0 end
 return current or 1
end
-- R152: the far letters' window (the rows that carry letters at all: the near letters' window lies inside it) and the fade of the far end.
function K.FarSide(tier)local t=K.Tier(tier);return max(t.FarBehind,ceil((t.FarBehind+t.FarAhead)/2))end
function K.FarLegendWindow(geo,tier,focusRow,facing)
 local t=K.Tier(tier);local n=geo.Rows;local f=max(1,min(n,focusRow))
 local lo,hi=t.FarBehind,t.FarAhead
 if facing==-1 then lo,hi=hi,lo elseif facing==0 then lo=K.FarSide(tier);hi=lo end
 return max(1,f-lo),min(n,f+hi)
end
-- Letters' transparency d rows from the runner (signed, in the window's way; 0 = solid): solid out to LegendFade rows short of the far end, fading
-- to gone over the last ones. The near letters (inside LegendAhead / LegendBehind) are always solid: the far letters carry on from them.
function K.LegendAlpha(tier,d,facing)
 local t=K.Tier(tier)
 local reach
 if facing==0 then d=math.abs(d);reach=K.FarSide(tier)
 else
  if facing then d*=facing end
  if d>=0 then reach=t.FarAhead else d=-d;reach=t.FarBehind end
 end
 local start=reach-t.LegendFade
 if d<=start then return 0 end
 if d>reach then return 1 end
 return(d-start)/(t.LegendFade+1)
end

-- Bed / rail segments: a length cut into pieces of at most BedMaxLength studs. Returns a list of {Z0=,Z1=,Centre=,Length=}.
function K.Segments(zFrom,zTo,maxLength)
 maxLength=maxLength or C.BedMaxLength
 local out={};local length=zTo-zFrom
 if length<=0 then return out end
 local count=ceil(length/maxLength);local span=length/count
 for i=1,count do
  local a=zFrom+(i-1)*span;local b=a+span
  out[i]={Z0=a,Z1=b,Centre=(a+b)/2,Length=span}
 end
 return out
end
-- Rect minus rect (axis aligned, {x0,x1,z0,z1}): up to four pieces of `a` outside `b` (front, back, then the two sides between them).
function K.RectMinus(a,b)
 local out={}
 local ax0,ax1,az0,az1=a[1],a[2],a[3],a[4];local bx0,bx1,bz0,bz1=b[1],b[2],b[3],b[4]
 if bx1<=ax0 or bx0>=ax1 or bz1<=az0 or bz0>=az1 then out[1]={ax0,ax1,az0,az1};return out end
 if bz0>az0 then out[#out+1]={ax0,ax1,az0,bz0}end
 if bz1<az1 then out[#out+1]={ax0,ax1,bz1,az1}end
 local mz0,mz1=max(az0,bz0),min(az1,bz1)
 if bx0>ax0 then out[#out+1]={ax0,bx0,mz0,mz1}end
 if bx1<ax1 then out[#out+1]={bx1,ax1,mz0,mz1}end
 return out
end

-- Click cadence, one gate per presser (you, each other player, each keeper): Allow(gate, now) is true at most once per ClickGap seconds.
-- While a presser keeps pressing (a sprint) the allowed clicks stay evenly spaced (the next slot is the last slot + gap, not "now + gap",
-- so frame timing does not make the rhythm drift or bunch); after a pause the gate opens at once.
function K.NewCadence(gap)return {Gap=gap or C.ClickGap,Next=-math.huge}end
function K.Allow(gate,now)
 if now+1e-9<gate.Next then return false end
 local slot=gate.Next+gate.Gap
 gate.Next=(now-gate.Next<gate.Gap)and slot or now+gate.Gap
 return true
end
-- The gain of a presser's n-th click (ClickGains, a short cycle that does not line up with ClickPitches): at most 1, so ClickVolume stays the peak.
function K.ClickGain(n)local list=C.ClickGains;return list[(n-1)%#list+1]end
-- R152: the sound a press plays: kind = 'Spacebar' (the huge full-width key) or anything else = a normal key; stage = the biome's stable id (only for the optional
-- PressSoundBiome override of a normal key). Returns an 'rbxassetid://' string (the configured sound of that kind, else the click) and, for K.PressVolume, its peak volume.
local function assetOf(id)
 if type(id)=='number'then return'rbxassetid://'..id end
 return type(id)=='string'and id or nil
end
function K.PressSoundId(kind,stage)
 if kind=='Spacebar'then return assetOf(C.PressSound.Spacebar)or'rbxassetid://'..tostring(C.ClickSoundId)end
 local name=stage and K.BiomeNames[stage]
 return(name and assetOf(C.PressSoundBiome[name]))or assetOf(C.PressSound.Key)or'rbxassetid://'..tostring(C.ClickSoundId)
end
function K.PressVolume(kind,stage)
 if kind=='Spacebar'then return C.ClickVolume end
 local name=stage and K.BiomeNames[stage]
 if(name and assetOf(C.PressSoundBiome[name]))or assetOf(C.PressSound.Key)then return C.PressSoundVolume or C.ClickVolume end
 return C.ClickVolume
end
-- R153 (owner playtest of R152: "when keepers knock players up the keyboard clicking sounds play, it should only play when players step on the keyboard"): a press
-- SOUNDS only when a runner really steps on a key. K.Steps(feet height, vertical speed, thrown) = feet within StepReach of the floor top, not rising faster than
-- StepMaxRise (a knock-up's first frames, a jump's take-off) and not thrown; K.Thrown(player, character, humanoid) = ragdolled / flung / knocked back, read from what
-- RagdollService sets (the player's GuardianRagdollActive / GuardianFlingActive, the character's ChestChaseRagdollActive, PlatformStand, the Physics / Ragdoll /
-- FallingDown states). Keepers never sound; a thrown body may still press keys down (silently) while it lies on them.
function K.Steps(feetY,velY,thrown)
 return not thrown and feetY<=C.FloorTop+C.StepReach and(velY or 0)<=C.StepMaxRise
end
local THROWN_STATES={}
if Enum then for _,n in ipairs({'Physics','Ragdoll','FallingDown','PlatformStanding','Flying'})do THROWN_STATES[Enum.HumanoidStateType[n]]=true end end
function K.Thrown(player,char,hum)
 if player and(player:GetAttribute('GuardianRagdollActive')==true or player:GetAttribute('GuardianFlingActive')==true)then return true end
 if char and char:GetAttribute('ChestChaseRagdollActive')==true then return true end
 if hum then
  if hum.PlatformStand==true then return true end
  local ok,state=pcall(hum.GetState,hum);if ok and THROWN_STATES[state]then return true end
 end
 return false
end
-- The pitch of a presser's n-th click: players cycle through ClickPitches, keepers use KeeperPitch.
function K.ClickPitch(kind,n)
 if kind==3 then return C.KeeperPitch end
 local list=C.ClickPitches;return list[(n-1)%#list+1]
end

return K
