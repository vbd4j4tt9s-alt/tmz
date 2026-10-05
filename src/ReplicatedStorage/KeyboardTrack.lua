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
 HoleReach=2,                                             -- keys within this many studs of a hole's Pit stay up (unpressable) while it exists
 PlatformClearance=.3,                                    -- keys under a pack platform (radius + this) are held down: the platform shows on them
 PlayerFootprint=1.2,PlayerFeetReach=3,PlayerRootToFeet=3,-- half-size of a runner's footprint; others press while their feet are within 3 studs of the floor
 KeeperMinFootprint=1.5,KeeperMaxFootprint=6,KeeperFootprintShare=.3,
 PlayerSampleHz=30,
 -- clicks: ONE recording (the first id; the other two R147 recordings are kept for reference only), a narrow pitch band, one volume
 -- rule (3D roll-off from the key) for every presser, and a steady per-presser cadence.
 ClickSoundIds={113108830240353,88838553648526,96591611478915},ClickSoundId=113108830240353,
 ClickPitches={.98,1.01,.99,1.02,1.0},                    -- each presser cycles through these (0.98 .. 1.02)
 KeeperPitch=.94,                                         -- keepers: the same click, a touch deeper
 ClickVolume=.8,ClickRollOffMin=16,ClickRollOffMax=90,ClickRange=90,ClickVoices=12,
 ClickGap=1/12,                                           -- per presser: at most one click every 1/12 s, evenly spaced while sprinting
 TierHoldSeconds=3,                                       -- a ClientFxBudget tier change applies after it has held this long
 TeleportBurst=4,                                         -- keys dressed (and released) in a frame where the rows around the runner are missing (a
                                                          -- teleport): x Bind. A camera turn gets no burst (it is spread over ~8 frames, R149 review)
 FacingThreshold=.25,FacingHoldSeconds=.2,                -- the long side of the window follows the camera along the track (runners carry packs back
                                                          -- to base facing -Z): it turns once the camera's LookVector.Z passes +-0.25 for 0.2 s
 CameraAbove=.6,                                          -- the camera never sinks under (resting key top + this = 5.8): the real floor is hidden, so it no
                                                          -- longer stops the default camera (Popper) from dropping into the keys / under the bed
 -- letters: PixelsPerStud on every letter SurfaceGui (TextHeight * PixelsPerStud = TextSize <= 100), Margin = the strip's top above the VISIBLE top of
 -- a resting key (the client measures that top from the keycap template: Legend.MaxExtra caps what a measurement may add), Rotation = the label's
 -- turn on the Top-face canvas (270: upright, reading left -> right for a runner heading +Z), KeysPerStrip = letters per SurfaceGui (a half row),
 -- MaxDistance = the guis' own render limit, RowsPerFrame = rows of letters dressed per frame (4, so a camera turn spreads the letters over several
 -- frames). The spacebars' biome names are big: they get their own render limit.
 Legend={PixelsPerStud=16,TextHeight=4.6,Margin=.04,MaxExtra=1.5,Rotation=270,KeysPerStrip=11,MaxDistance=420,Font='FredokaOne',RowsPerFrame=4},
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

-- Per ClientFxBudget tier (3 best .. 1 lowest; phones start on 2). Rows of keys around the runner (all columns, all the same keycap):
-- Back / Ahead = key rows behind / ahead of the runner's row, Hyst = extra rows kept before a row is recycled (no flicker at the window
-- edge), Bind = keys dressed per frame (x min(2, dt * 60)). Letters: LegendAhead / LegendBehind rows carry their letters, the farthest
-- LegendFade rows fade out; LegendRadius = the letters under and around the runner's feet are always shown (other effects keep clear of
-- that radius, e.g. the Snow-biome dust). PressRange = other runners / keepers farther than this (along the track) press nothing.
-- KeyLegends = pooled letters for keys that are down (a key's letter rides with it while it moves).
K.Tiers={
 [3]={Back=12,Ahead=122,Hyst=4,Bind=264,LegendBehind=2,LegendAhead=18,LegendFade=4,LegendRadius=24,PressRange=260,KeyLegends=48},
 [2]={Back=8,Ahead=76,Hyst=2,Bind=198,LegendBehind=2,LegendAhead=12,LegendFade=3,LegendRadius=20,PressRange=200,KeyLegends=32},
 [1]={Back=5,Ahead=46,Hyst=2,Bind=132,LegendBehind=1,LegendAhead=7,LegendFade=2,LegendRadius=16,PressRange=150,KeyLegends=16},
}
function K.Tier(tier)return K.Tiers[tier]or K.Tiers[3]end

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

-- Geometry(attrs, centerX, fieldWidth): the whole grid for this map. Fields: Pitch (= fieldWidth / Cols exactly, so the keys run edge to
-- edge), Cols, HalfWidth, CenterX, Z0 (start of the first biome), KeyEndZ (BiomeTrackEndZ - 120), Rows (all rows, spacebars included),
-- Segs (one per biome, sorted by start: {Id, Name, StartZ, EndZ, Rows, FirstRow, LastRow, RowPitch, SpaceLast, KeyFirst}), RowSeg[row],
-- RowStage[row], Bars (one spacebar per biome: {Seg, Stage, Name, Row0, Row1, Z0, Z1}), BarOfRow[row]. Helpers (call with a dot):
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
-- camera looks toward +Z (into the biomes), -1 toward -Z (back to base): Ahead rows lie that way, Back rows the other. Returns ra, rb (rows
-- wanted) and ka, kb (rows kept: a bound row outside ka .. kb is recycled), all clamped to 1 .. Rows.
function K.KeyWindow(geo,tier,focusRow,facing)
 local t=K.Tier(tier);local n=geo.Rows
 local f=max(1,min(n,focusRow))
 local lo,hi=t.Back,t.Ahead;if facing==-1 then lo,hi=hi,lo end
 return max(1,f-lo),min(n,f+hi),max(1,f-lo-t.Hyst),min(n,f+hi+t.Hyst)
end
-- Most keys a tier ever has bound at once: the kept window (wanted rows + hysteresis on both sides) times the columns.
function K.KeyCap(tier,cols)local t=K.Tier(tier);return(t.Back+t.Ahead+1+2*t.Hyst)*cols end
-- Rows whose letters are shown (facing as for KeyWindow), and the letters' transparency at a row d rows ahead of the runner in the
-- facing direction (0 = solid; the farthest LegendFade rows fade out; behind the runner they stay solid).
function K.LegendWindow(geo,tier,focusRow,facing)
 local t=K.Tier(tier);local n=geo.Rows;local f=max(1,min(n,focusRow))
 local lo,hi=t.LegendBehind,t.LegendAhead;if facing==-1 then lo,hi=hi,lo end
 return max(1,f-lo),min(n,f+hi)
end
-- Which way the window should face for a camera LookVector.Z (keeps `current` inside the dead zone).
function K.Facing(lookZ,current)
 if type(lookZ)~='number'or lookZ~=lookZ then return current or 1 end
 if lookZ>C.FacingThreshold then return 1 elseif lookZ< -C.FacingThreshold then return -1 end
 return current or 1
end
function K.LegendAlpha(tier,d)
 local t=K.Tier(tier)
 local start=t.LegendAhead-t.LegendFade
 if d<=start then return 0 end
 if d>t.LegendAhead then return 1 end
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
-- The pitch of a presser's n-th click: players cycle through ClickPitches, keepers use KeeperPitch.
function K.ClickPitch(kind,n)
 if kind==3 then return C.KeeperPitch end
 local list=C.ClickPitches;return list[(n-1)%#list+1]
end

return K
