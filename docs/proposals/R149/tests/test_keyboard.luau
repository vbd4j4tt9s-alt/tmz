--!nocheck
-- R149 keyboard suite. Part 1: ReplicatedStorage.KeyboardTrack (pure grid, biome palettes, letters, windows, click cadence). Part 2: the real
-- StarterPlayerScripts/KeyboardTrack.client.lua on the mock world (client only, no remotes).
--
-- What happened to the R148 checks (docs/proposals/R147/tests/test_keyboard.luau, 293 checks; the owner asked for bigger / taller keys, one
-- consistent look to long range, rendering fixes, consistent clicks and biome colours):
--  KEPT (same meaning, new numbers): config heights / timings, deterministic geometry, biome grids starting exactly on BiomeStartZ, row pitch
--   band (now 8.17 .. 8.23), column 1 = +X edge, ColOfX inverse, CellCenter, TrackCenterX / FieldWidth, CellsInRect / CellRange edge cases,
--   RowOfZ joins, one spacebar per biome (now its FIRST row, not three), BiomeAt + BiomeName_n, zones / four shades / +-4% jitter / all shades
--   used / no single-colour rows / no row bands, legend order QWERTY left -> right with drift, easing, keeper footprint, bed segments,
--   no remotes, never writes CollisionFidelity / RenderFidelity, every part anchored + no collide / query / touch / shadow, coverage of the
--   whole floor around the runner (now: every cell of the window has exactly one key), legends upright on the Top face in keyboard order
--   with the zone ink, spacebar label, presses / release / back-out / air / dead / spacebar / reduced motion, Effects volume 0, keepers
--   (footprint, dash frame, Veiled keeper, destroyed), other players (press, jump, feet height, walk off, > 90 studs silent), holes (lifted
--   per part, streamed-in parts, crumb tween, rebuilt models), platforms, tier hold 3 s, tier caps, trips without leaks, teleports with
--   bounded work and no bare keys near the runner, teardown, no template, template still loading, partly described map.
--  CHANGED (owner request): pitch 3 -> 8.18 (22 columns), keys 2.72 x 1.3 -> 7.68 x 4.65 (template proportions) standing 2.15 studs proud
--   of a SUNKEN bed (was a bed 0.1 above the floor); the real floor is now hidden for this client (was "untouched") and restored on
--   teardown; the arena floor is drawn by a local copy; bed = each biome's darker colour (was one dark chocolate); palettes = each biome's
--   own colours (were candy mint / pistachio / caramel / vanilla / strawberry / pink / chocolate); per-shade ink (contrast >= 3.5);
--   holes no longer clear keys: the keys stay up and the hole lies on them (the R148 "keys within 2 studs are left out" / "bar hidden"
--   checks became "keys stay up and unpressable" / "bar stays, unpressable"); platforms hold their keys down (were cleared);
--   clicks: ONE recording (was three alternating), pitch 0.98 .. 1.02 (was 0.96 .. 1.06), keepers 0.94 (was 0.7), a steady cadence PER
--   PRESSER (was a sliding 12/s own + 8/s shared by all others, which starved runners in a crowd and let bursts through): the corner of
--   4 keys now gives ONE click (was 4 stacked), 12 runners each get their own clicks (was 8/s for all of them together).
--  REMOVED (the layered design is gone): K.Hierarchy / K.Windows / K.WindowCount / K.NearestOrd checks, plain / 2x2 .. 16x16 block layers,
--   "finer block higher" overlap ordering, per-layer bind budgets, "676 keycaps in a 26 x 26 window", "2000+ studs of coarse blocks";
--   replaced by: one key representation everywhere, row windows per tier (~1000 / 620 / 380 studs ahead), caps, nearest-first binding.
-- CHANGED by R151 (owner playtest of R149 / R150: "doesn't push down far enough", "the words are missing, they only appear if under my foot",
--  spacebar names "parallel to the safe zone and horizontal"): resting tops 1.2 above the floor, pressed .05 (1.15 of travel, was .47); a runner's
--  footprint reaches PressLead seconds ahead; the Top-face SurfaceGui frame is canvas x -> world -Z, canvas y -> world +X (R149 assumed x -> +X: only
--  one label per strip was inside its canvas, every letter a quarter turn off, the spacebar name along the track) so every label sits at (row
--  centre, key centre) of the real canvas and turns 270 degrees; strips / pressed-key letters follow the key top MEASURED from the keycap template
--  (a taller-than-configured mesh); the old strip checks were rewritten on that frame (section 1d adds: every key of a bound row has a visible
--  label over it, in every biome, both half rows, with the plain-block fallback too, and the spacebar name across the track).
-- ADDED by the R149 performance patch (docs/proposals/R149/review_part1.md, fix round A): the camera clamp (1b), the hide-last start-up (1c, 15), no
-- turn burst on a phone with the measured worst frame (5c), unchanged letter values / single key Transparency writes / parked strips off (4c), the
-- stripped template (before 'parts:'), the connection list (11b), the swapPass fallback (13b), the failing start-up / frame step (15).
local W=require('./world');local R=W.R
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return a~=nil and b~=nil and math.abs(a-b)<=(e or 1e-6)end
local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS;local workspace=W.workspace
local function frames(n,dt)W.frames(n,dt)end
local floor,abs,max,min,sqrt=math.floor,math.abs,math.max,math.min,math.sqrt

-- ======================================================================================================================
-- Part 1: KeyboardTrack.lua
-- ======================================================================================================================
local K=W.module('KeyboardTrack');local C=K.Config
local ATTR={BiomeTrackEndZ=5980,BiomeStartZ_1=-100,BiomeEndZ_1=80,BiomeStartZ_6=80,BiomeEndZ_6=530,BiomeStartZ_2=530,BiomeEndZ_2=1180,
 BiomeStartZ_3=1180,BiomeEndZ_3=2030,BiomeStartZ_4=2030,BiomeEndZ_4=3080,BiomeStartZ_5=3080,BiomeEndZ_5=4380,BiomeStartZ_7=4380,BiomeEndZ_7=5980}
local F=C.FloorTop
local KW=K.KeySize()
check(near(C.Pitch,180/22)and C.FieldWidth==180 and C.Gap==.5 and C.SpaceRows==1,'config: 22 keys across the 180 floor (pitch 8.18, 2.7x R148), grout gap .5, the spacebar is one row')
check(near(KW,7.6818,1e-3)and near(C.KeyY/KW,6.39/10.55,1e-6),'keys are 7.68 studs square and keep the R142Keycap proportions (height / width = 6.39 / 10.55: KeyY '..string.format('%.2f',C.KeyY)..')')
check(near(K.KeyTop(0),F+1.2)and near(K.KeyTop(1),F+.05)and near(K.BedTop(),F-1.6),'heights: resting tops 1.2 above the floor, pressed .05 above it (feet stand at the floor top), the grout bed 1.6 below it')
check(near(K.PressTravel(),1.15)and K.PressTravel()>=1 and K.PressTravel()<=1.2,'a press travels 1.15 studs (owner R151: "it doesn\'t push down far enough"; the reference game ~1 - 1.2; was .47)')
check(near(K.KeyTop(0)-K.BedTop(),2.8)and near(K.KeyTop(1)-K.BedTop(),1.65)and K.KeyTop(1)-K.BedTop()>=1.5,'a resting key stands 2.8 studs proud of the bed, a pressed one still 1.65 (it stays a visible key, not a hole)')
check(K.KeyTop(0)-C.KeyY<K.BedTop()-1 and K.KeyTop(1.15)-C.KeyY<K.BedTop()-1,'a key\'s bottom stays well under the bed even pressed past its travel (its foot never shows)')
check(C.PressSeconds==.06 and C.ReleaseSeconds==.2 and near(C.HoleLift,C.RestRise+.06),'press .06 s (snappy), release .2 s with a back-out spring; hole parts are lifted onto the resting key tops (+.06: the rim stays over the letter strips)')
check(near(C.PressLead,.06)and C.PressLeadMax>=3 and C.PressLeadMax<=6,'the runner\'s footprint reaches .06 s of his velocity ahead, at most '..C.PressLeadMax..' studs')
check(C.ClickSoundId==113108830240353 and C.ClickSoundIds[1]==C.ClickSoundId and near(C.ClickGap,1/12)and C.KeeperPitch>=.9 and C.KeeperPitch<1 and C.ClickVoices>=10,'clicks: one recording, at most one click per 1/12 s per presser, keepers a touch deeper (0.94), a pool of '..C.ClickVoices..' voices')
local pitchOk=#C.ClickPitches>=3;for _,p in ipairs(C.ClickPitches)do if p<.98 or p>1.02 then pitchOk=false end end
check(pitchOk,'click pitch varies only a little: 0.98 .. 1.02')
-- R152 (owner: "its not loud enough"): was volume .8, roll-off 16 .. 90, range 90 (the camera trails the runner by 12 .. 128 studs: his own click was already past the full-volume radius).
-- Now volume 1.8 (x2.25 = +7.0 dB = about 1.6x as loud; +6 dB is x1.5, +10 dB is x2), roll-off 28 .. 160, range 160. The Effects group (AudioMixer, default 100) does not pull it down.
do
 local OLD={Volume=.8,Min=16,Max=90}
 local dB=20*math.log10(C.ClickVolume/OLD.Volume);local perceived=2^(dB/10)
 check(C.ClickRollOffMin>=24 and C.ClickRollOffMax==C.ClickRange and C.ClickRange>=150 and C.ClickRollOffMin<C.ClickRollOffMax,('one volume rule for every click: 3D roll-off %d .. %d studs, range %d (was 16 .. 90, 90)'):format(C.ClickRollOffMin,C.ClickRollOffMax,C.ClickRange))
 check(C.ClickVolume>=1.5 and C.ClickVolume<=2.5 and perceived>=1.5 and perceived<=2.1,('click volume %.2f (was .8): +%.1f dB = about %.2fx as loud (the aim: 1.5 .. 2x)'):format(C.ClickVolume,dB,perceived))
 -- Roblox's InverseTapered roll-off, approximated as min / d inverse falloff times a linear taper to zero at the max distance: what the player hears at 14 (default camera), 30, 60 and 100 studs
 local function heard(vol,min,max,d)if d<=min then return vol end;if d>=max then return 0 end;return vol*(min/d)*(1-(d-min)/(max-min))end
 local line={}
 for _,d in ipairs({14,30,60,100})do
  local a,b=heard(OLD.Volume,OLD.Min,OLD.Max,d),heard(C.ClickVolume,C.ClickRollOffMin,C.ClickRollOffMax,d)
  line[#line+1]=('%d studs: %.2f -> %.2f'):format(d,a,b)
  check(b>=a*(d==14 and 2 or 3) and(a>0 or b>0),('the click is clearly louder %d studs from the camera (about %.2f before, %.2f now)'):format(d,a,b))
 end
 print('click: '..table.concat(line,' | ')..' (approximate heard gain: volume x roll-off)')
 check(C.ClickVoices==12 and #C.ClickGains>=3 and K.ClickGain(1)==1,'the voice pool keeps its cap ('..C.ClickVoices..' voices per sound) and the first click of a presser plays at full volume')
 local gainOk=true;for _,gn in ipairs(C.ClickGains)do if gn>1 or gn<.85 then gainOk=false end end
 check(gainOk and #C.ClickGains~=#C.ClickPitches,'a slight per-click gain (.85 .. 1 of the volume: the peak never rises) on a cycle that does not line up with the pitches')
 do local KEY,CLK='rbxassetid://73942179280083','rbxassetid://113108830240353';local ok=K.PressSoundId('Key')==KEY and K.PressSoundId('Spacebar')==CLK and K.PressSoundId('Key',nil)==KEY
  for stage=1,7 do if K.PressSoundId('Key',stage)~=KEY or K.PressSoundId('Spacebar',stage)~=CLK then ok=false end end
  check(ok and C.PressSound.Key==KEY and C.PressSound.Spacebar==CLK and next(C.PressSoundBiome)==nil,'R152 (owner: the sound is for every key as big as the Forest / Jungle ones): by key KIND, not biome: a normal key of EVERY biome (1 .. 7) plays 73942179280083, a spacebar the original click 113108830240353; the optional per-biome override (PressSoundBiome) is empty')
  check(K.PressVolume('Key')==C.PressSoundVolume and C.PressSoundVolume==C.ClickVolume and type(C.PressSoundVolume)=='number'and K.PressVolume('Spacebar')==C.ClickVolume,'R152: ONE volume knob for the key sound (Config.PressSoundVolume, starting at the click\'s '..C.ClickVolume..': tune it by ear there); the spacebar\'s click plays at ClickVolume')
 end
end
local LT=C.Legend
check(LT.Margin>=.05-1e-9 and LT.Margin<=.06 and LT.Rotation==270 and LT.MaxExtra>=1,'letter strips stand .05 - .06 above the measured resting key top (Margin '..LT.Margin..': R152 z-fighting, the strip and the key top overlap over the whole key, so the gap must clear the R149 depth rule, .043 at 300 studs), labels turn 270 degrees')
check(LT.TextHeight*LT.PixelsPerStud<=100 and LT.TextHeight>=4 and LT.KeysPerStrip==11,'letters 4.6 studs tall (TextSize '..LT.TextHeight*LT.PixelsPerStud..' <= 100), 11 per SurfaceGui (half a row)')

local g=K.Geometry(ATTR,0)
local function dist2(a,b)return (a[1]-b[1])^2+(a[2]-b[2])^2+(a[3]-b[3])^2 end
do
check(near(g.Pitch,180/22)and g.Cols==22 and g.HalfWidth==90 and g.Z0==-100 and g.KeyEndZ==5860,'geometry: 22 columns across x -90..90, rows from -100 (the first biome start) to EndZ-120 = 5860')
check(g.Rows==728 and #g.Segs==7,'geometry: 728 rows in 7 biome grids (got '..g.Rows..')')
check(K.Geometry(ATTR).Rows==728 and K.Geometry({BiomeTrackEndZ=1445},0).Rows>=1,'geometry is deterministic')
local wantSegRows={22,55,79,104,128,159,181};local wantIds={1,6,2,3,4,5,7};local rowsOk=true
for i,s in ipairs(g.Segs)do if s.Rows~=wantSegRows[i]or s.Id~=wantIds[i]then rowsOk=false end end
check(rowsOk,'biome grids: Forest 22, Jungle 55, Desert 79, Snow 104, Lava 128, Crystal 159, Storm Peaks 181 rows')
local startOk,pitchBand=true,true
for _,s in ipairs(g.Segs)do
 local z0=g.RowZ(s.FirstRow)
 if not near(z0,s.StartZ,1e-6)then startOk=false end
 if s.RowPitch<8.16 or s.RowPitch>8.24 then pitchBand=false end
 local z2=select(2,g.RowZ(s.LastRow));if not near(z2,s.EndZ,1e-6)then startOk=false end
end
check(startOk,'every biome grid starts exactly on its BiomeStartZ_n (rows tile the biome with no remainder)')
check(pitchBand and near(select(2,g.RowZ(g.Rows)),5860,1e-6),'row pitch of every biome is about the column pitch (8.16 .. 8.24) and the last row ends at 5860')
local P=g.Pitch
check(near(g.ColCenter(1),90-P/2)and near(g.ColCenter(22),-90+P/2)and g.ColCenter(1)>g.ColCenter(2),'column 1 is the +X edge (a heading-+Z runner reads columns left -> right)')
check(g.ColOfX(g.ColCenter(1))==1 and g.ColOfX(g.ColCenter(22))==22 and g.ColOfX(0.01)==11 and g.ColOfX(-0.01)==12,'ColOfX is the inverse of ColCenter')
local x1,z1c=g.CellCenter(1,1);local x6,z6=g.CellCenter(g.Rows,22)
check(near(x1,90-P/2)and near(z1c,-100+P/2)and near(x6,-90+P/2)and near(z6,5860-g.Segs[7].RowPitch/2),'CellCenter: (1,1) = (85.9, first row), last cell at the track end')
local gShift=K.Geometry(ATTR,12);check(near(gShift.ColCenter(1),102-P/2)and near(gShift.ColCenter(22),-78+P/2),'columns follow TrackCenterX')
local g210=K.Geometry(ATTR,0,210);check(g210.Cols==26 and near(g210.Pitch*26,210),'the floor width comes from FieldWidth when given (210 -> 26 columns, edge to edge)')
local function ids(list)local t={};for _,c in ipairs(list)do t[#t+1]=c.row..':'..c.col end;table.sort(t);return table.concat(t,',')end
local za,zb=g.RowZ(5)
check(ids(g.CellsInRect(0,P,za,zb))=='5:11','CellsInRect: a rect that exactly fills one cell is that cell only (got '..ids(g.CellsInRect(0,P,za,zb))..')')
check(ids(g.CellsInRect(-1.2,1.2,zb-1.2,zb+1.2))=='5:11,5:12,6:11,6:12','CellsInRect: a footprint on a cell corner claims 4 cells')
check(ids(g.CellsInRect(0,0,za+1,za+1))=='5:12','CellsInRect: a point on a column line belongs to the cell on its -X side')
check(#g.CellsInRect(90.5,100,0,10)==0 and #g.CellsInRect(-100,-90.5,0,10)==0,'CellsInRect: outside the floor in x is empty')
check(#g.CellsInRect(-5,5,-120,-100)==0 and #g.CellsInRect(-5,5,5860,5900)==0,'CellsInRect: touching or beyond the first / last row edge is empty')
check(ids(g.CellsInRect(-1,1,5858,5859.5))=='728:11,728:12','CellsInRect: the last row is reachable')
check(#g.CellsInRect(-1000,1000,-1000,9000)==22*728,'CellsInRect: a huge rect clamps to the 22 x 728 grid')
check(#g.CellsInRect(5,-5,10,-10)==#g.CellsInRect(-5,5,-10,10),'CellsInRect: reversed bounds are accepted')
local c1,c2,r1,r2=g.CellRange(-1.2,1.2,zb-1.2,zb+1.2);check(c1==11 and c2==12 and r1==5 and r2==6,'CellRange: the allocation-free form agrees')
local nan=0/0;local e1,e2=g.CellRange(nan,1,0,1);check(e1>e2,'CellRange: NaN gives an empty range')
check(g.RowOfZ(-100.1)==0 and g.RowOfZ(-100)==1 and g.RowOfZ(5860)==729 and g.RowOfZ(79.99)==22 and g.RowOfZ(80)==23,'RowOfZ: biome grids join exactly (row 23 starts at z 80)')
-- biomes and spacebars
local want={{1,'Forest',1,22},{6,'Jungle',23,77},{2,'Desert',78,156},{3,'Snow',157,260},{4,'Lava',261,388},{5,'Crystal',389,547},{7,'Storm Peaks',548,728}}
for i,w in ipairs(want)do
 local s=g.Segs[i];local bar=g.Bars[i]
 check(s and s.Id==w[1]and s.Name==w[2]and s.FirstRow==w[3]and s.LastRow==w[4],'biome '..w[2]..' rows '..w[3]..'-'..w[4]..' (got '..tostring(s and s.FirstRow)..'-'..tostring(s and s.LastRow)..')')
 check(bar and bar.Name==w[2]and bar.Row0==w[3]and bar.Row1==w[3]and near(bar.Z0,s.StartZ)and near(bar.Z1-bar.Z0,s.RowPitch),'one spacebar at the start of '..w[2]..' (its first row, from its BiomeStartZ)')
 check(g.BarOfRow[w[3]]==i and g.BarOfRow[w[3]+1]==nil and g.RowStage[w[3]]==w[1]and g.RowStage[w[4]]==w[1],'rows of '..w[2]..' belong to stage '..w[1])
end
local id,name=K.BiomeAt(-100,ATTR);check(id==1 and name=='Forest','BiomeAt: the start of the track is Forest')
id,name=K.BiomeAt(80,ATTR);check(id==6 and name=='Jungle','BiomeAt: 80 is Jungle (stage ids are not track order)')
id=K.BiomeAt(5980,ATTR);check(id==0 and K.BiomeAt(-101,ATTR)==0 and K.BiomeAt(10,nil)==0,'BiomeAt: outside the biomes is 0')
local named=table.clone(ATTR);named.BiomeName_6='Rainforest';id,name=K.BiomeAt(100,named);check(name=='Rainforest','BiomeAt: BiomeName_n attribute overrides the name')
check(K.Geometry(named,0).Bars[2].Name=='Rainforest','the spacebar uses the BiomeName_n attribute too')

-- zones: each biome's own colours (owner: "keyboard colouring should match their biome")
local zoneOk=true
for _,stage in ipairs({1,2,3,4,5,6,7})do local z=K.Zone(stage);if not z or #z.Shades~=4 or not z.Family or not z.Ink or not z.InkLight or not z.Bed then zoneOk=false end end
check(zoneOk,'seven zones, four shades each, a family name, a dark and a light letter ink, a grout (bed) colour')
-- hue / saturation / value of an RGB triple (h in degrees)
local function hsv(c)
 local r,g2,b=c[1]/255,c[2]/255,c[3]/255;local mx,mn=max(r,g2,b),min(r,g2,b);local d=mx-mn;local h=0
 if d>0 then if mx==r then h=60*(((g2-b)/d)%6)elseif mx==g2 then h=60*((b-r)/d+2)else h=60*((r-g2)/d+4)end end
 return h,mx>0 and d/mx or 0,mx
end
local function hueIn(h,a,b)if a<=b then return h>=a and h<=b end;return h>=a or h<=b end
-- the biome's own colours in this repo (BiomeVisuals overrides, the map ground as the R143 keyboard sampled it, runner / pack themes)
local REF={
 [1]={{82,180,87},{106,195,101},{108,135,61}},                 -- Forest: grass ground, Trail Runner trim, pack trim
 [6]={{78,133,62},{51,190,127},{114,143,65}},                  -- Jungle: ground, Vine Runner trim, pack body
 [2]={{224,188,103},{200,164,109},{251,202,130}},              -- Desert: ground, pack stone, Dune Runner
 [3]={{176,194,204},{198,212,220},{135,203,234}},              -- Snow: ground, drifts, Glacier Runner
 [4]={{223,66,13},{189,59,21},{177,66,42}},                    -- Lava: magma, channels, pack trim (the basalt ground is the grout)
 [5]={{147,105,204},{187,152,233},{113,76,166}},               -- Crystal: prisms
 [7]={{88,111,144},{105,113,146},{173,150,220}},               -- Storm Peaks: slate ground, pack body, violet trim
}
local HUE={[1]={85,135},[6]={80,165},[2]={25,50},[3]={185,220},[4]={0,30},[5]={255,315},[7]={210,260}}
local hueOk,classOk,detail=true,true,{}
local function mean(list)local s={0,0,0};for _,c in ipairs(list)do for i=1,3 do s[i]+=c[i]/#list end end;return s end
for stage,range in pairs(HUE)do
 local z=K.Zone(stage)
 for _,sh in ipairs(z.Shades)do
  local h,s,v=hsv(sh)
  if stage==3 then if not(s<.3 and v>.8 and(s<.05 or hueIn(h,range[1],range[2])))then hueOk=false;detail[#detail+1]='Snow '..table.concat(sh,',')end
  elseif stage==7 then if not(s<.45 and v<.75 and hueIn(h,range[1],range[2]))then hueOk=false;detail[#detail+1]='Storm '..table.concat(sh,',')end
  elseif not hueIn(h,range[1],range[2])then hueOk=false;detail[#detail+1]=z.Name..' '..table.concat(sh,',')..string.format(' h%.0f',h)end
 end
 -- the zone's mean colour is nearest to its own biome's reference colours
 local m=mean(z.Shades);local best,bestStage=1e18,0
 for st,refs in pairs(REF)do local d=dist2(m,mean(refs));if d<best then best,bestStage=d,st end end
 if bestStage~=stage then classOk=false;detail[#detail+1]=z.Name..' looks like stage '..bestStage end
end
check(hueOk,'every shade is in its biome\'s colour family: Forest greens, Jungle deep green / lime, Desert sand / tan, Snow white / ice blue, Lava dark red / orange, Crystal purple / pink, Storm grey / blue-violet '..table.concat(detail,'; '))
check(classOk,'each zone\'s mean colour is nearest to its own biome\'s colours (ground, scenery, runner / pack themes) of all seven')
-- neighbours along the track differ clearly, so the change at a biome boundary is clean (the spacebar marks it)
local order={1,6,2,3,4,5,7};local apart=true;local minGap=1e9
for i=1,#order-1 do local d=sqrt(dist2(mean(K.Zone(order[i]).Shades),mean(K.Zone(order[i+1]).Shades)));minGap=min(minGap,d);if d<45 then apart=false end end
check(apart,('consecutive biomes have clearly different keys (mean colour distance >= 45, smallest %.0f)'):format(minGap))
-- readable letters: per-shade ink with enough contrast
local inkOk,worst=true,99
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local z=K.Zone(stage)
 for i,sh in ipairs(z.Shades)do
  local ink=K.ShadeInk(stage,i);local cr=K.Contrast(sh,ink);worst=min(worst,cr)
  if cr<3.5 or(ink~=z.Ink and ink~=z.InkLight)then inkOk=false end
  -- the worst-case key brightness jitter (+-4%) keeps it readable too
  local dark={sh[1]*.96,sh[2]*.96,sh[3]*.96};local light={min(255,sh[1]*1.04),min(255,sh[2]*1.04),min(255,sh[3]*1.04)}
  if K.Contrast(dark,ink)<3.3 or K.Contrast(light,ink)<3.3 then inkOk=false end
 end
end
check(inkOk,('letters read on every shade: the better of the zone\'s two inks, contrast >= 3.5:1 (worst %.2f)'):format(worst))
check(K.Contrast(K.Cream,K.CreamInk)>=7,'spacebar label: chocolate on cream, contrast >= 7:1')
check(near(K.Contrast({255,255,255},{0,0,0}),21,1e-6)and near(K.Contrast({0,0,0},{0,0,0}),1),'contrast ratio maths (WCAG): white / black 21, equal colours 1')
local bedOk=true
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local z=K.Zone(stage);local lb=K.Luminance(z.Bed)
 for _,sh in ipairs(z.Shades)do if K.Luminance(sh)<=lb then bedOk=false end end
 if K.Luminance(z.Bed)<.004 then bedOk=false end
end
check(bedOk,'every biome\'s grout is darker than all its keys but not black (no dark-gap look)')
local allShades,jitterOk=true,true
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local z=K.Zone(stage);local used={}
 for r=1,160 do for c=1,22 do
  local rr,gg,bb=K.CellRGB(stage,r,c,1);local best,bi=1e9,0
  for i,sh in ipairs(z.Shades)do local d=dist2({rr,gg,bb},sh);if d<best then best,bi=d,i end end
  used[bi]=(used[bi]or 0)+1
  local sh=z.Shades[K.ShadeIndex(stage,r,c,1)]
  if abs(rr-sh[1])>sh[1]*.045+1 or abs(gg-sh[2])>sh[2]*.045+1 or abs(bb-sh[3])>sh[3]*.045+1 then jitterOk=false end
 end end
 for i=1,4 do if(used[i]or 0)<3520*.15 or(used[i]or 0)>3520*.40 then allShades=false end end
end
check(jitterOk,'a key colour is its zone shade within +-4%')
check(allShades,'all four shades of a zone are used, each by roughly a quarter of the keys')
local bandOk,singleOk=true,true
for _,stage in ipairs({1,2,3,4,5,6,7})do
 local rowSum,rowSq,keySum,keySq,keyN=0,0,0,0,0
 for r=1,160 do
  local seen={};local sum=0
  for c=1,22 do local rr,gg,bb=K.CellRGB(stage,r,c,1);local l=rr+gg+bb;sum+=l;keySum+=l;keySq+=l*l;keyN+=1;seen[K.ShadeIndex(stage,r,c,1)]=true end
  local kinds=0;for _ in pairs(seen)do kinds+=1 end;if kinds<3 then singleOk=false end
  rowSum+=sum/22;rowSq+=(sum/22)^2
 end
 local keyStd=sqrt(keySq/keyN-(keySum/keyN)^2);local rowStd=sqrt(max(0,rowSq/160-(rowSum/160)^2))
 if rowStd>keyStd*.35 then bandOk=false end
end
check(singleOk,'no row is one colour: every row of every zone mixes at least 3 of the 4 shades')
check(bandOk,'no bands: row-to-row differences of the mean colour are small next to the key-to-key spread in every zone (std ratio <= 0.35 with 22 keys a row)')
check(K.CellRGB(1,5,7,1)==K.CellRGB(1,5,7,1)and K.Jitter(5,7,1)==K.Jitter(5,7,1)and K.ShadeIndex(3,100,13,1)==K.ShadeIndex(3,100,13,1),'colours are deterministic (no randomness)')
local jmin,jmax=2,0;for r=1,200 do for c=1,22 do local j=K.Jitter(r,c,1);jmin=min(jmin,j);jmax=max(jmax,j)end end
check(jmin>=.96-1e-9 and jmax<=1.04+1e-9 and jmax-jmin>.05,'brightness jitter stays within +-4% and really varies')
-- legends read left -> right in keyboard order (columns ascend toward the runner's right)
local function legendRow(row)local t={};for c=1,22 do t[#t+1]=K.Legend(row,c)end;return table.concat(t)end
check(K.Legend(1,1)=='Q' and legendRow(1):sub(1,10)=='QWERTYUIOP' and legendRow(2):sub(1,9)=='ASDFGHJKL' and legendRow(3):sub(1,7)=='ZXCVBNM' and legendRow(4):sub(1,10)=='1234567890','legends read QWERTYUIOP / ASDFGHJKL / ZXCVBNM / 1234567890 from column 1 on')
check(legendRow(1):sub(11,20)=='QWERTYUIOP' and legendRow(5):sub(1,3)=='RTY' and legendRow(5)~=legendRow(1),'a keyboard row repeats across the 22 columns; every four rows the start drifts')
local seqOk=true
for r=1,200 do local line=K.LegendRows[(r-1)%4+1];if not line:rep(8):find(legendRow(r),1,true)then seqOk=false end end
check(seqOk,'every row reads as a contiguous stretch of its keyboard row, left -> right')
-- easing and helpers
check(K.Ease.QuadOut(0)==0 and K.Ease.QuadOut(1)==1 and K.Ease.QuadOut(.5)==.75 and K.Ease.Linear(.3)==.3,'ease: quad-out and linear')
local peak=0;for i=0,100 do peak=max(peak,K.Ease.BackOut(i/100))end
check(near(K.Ease.BackOut(0),0)and near(K.Ease.BackOut(1),1)and peak>1.05 and peak<1.2,'ease: back-out overshoots a little and settles at 1 (peak '..string.format('%.3f',peak)..')')
check(near(K.KeyCenterY(0),F+1.2-C.KeyY/2),'KeyCenterY = resting top - half the key height')
check(K.KeeperFootprint(2,2)==1.5 and K.KeeperFootprint(10,12)==3 and K.KeeperFootprint(60,80)==6,'keeper footprint = clamp(0.3 * min extent, 1.5, 6)')
local segs=K.Segments(g.Z0,g.KeyEndZ,1024);local contiguous=true;local total=0
for i,s in ipairs(segs)do total+=s.Length;if s.Length>1024+1e-9 or(i>1 and not near(s.Z0,segs[i-1].Z1))then contiguous=false end end
check(#segs==6 and contiguous and near(total,5960)and near(segs[1].Z0,-100),'segments: 6 contiguous pieces of at most 1024 studs covering the whole key area')
local sums=K.Segments(0,10,1024);check(#sums==1 and near(sums[1].Length,10),'a short segment is one piece')
local rm=K.RectMinus({-90,90,4380,5980},{-90,90,-100,5860})
check(#rm==1 and rm[1][3]==5860 and rm[1][4]==5980 and rm[1][1]==-90 and rm[1][2]==90,'RectMinus: the arena part of the Storm floor (z 5860 .. 5980) is what the keyboard leaves uncovered')
local rm2=K.RectMinus({-100,100,0,100},{-90,90,20,80});local area=0;for _,r in ipairs(rm2)do area+=(r[2]-r[1])*(r[4]-r[3])end
check(#rm2==4 and near(area,200*100-180*60),'RectMinus: a wider, longer floor leaves front, back and two sides (area adds up)')
check(#K.RectMinus({0,10,0,10},{20,30,0,10})==1 and #K.RectMinus({0,10,0,10},{-5,15,-5,15})==0,'RectMinus: disjoint = whole rect, covered = nothing')
-- windows per tier: one representation, long range, caps
local capOk=true
for tier,want in pairs({[3]={990,3800,500},[2]={600,2400,340},[1]={365,1600,230}})do
 local t=K.Tier(tier)
 if t.Ahead*P<want[1]or K.KeyCap(tier,22)>want[2]or t.FarAhead*P<want[3]or t.LegendAhead*P<140*(tier==3 and 1 or tier==2 and .68 or .39)then capOk=false end
 local ra,rb,ka,kb=K.KeyWindow(g,tier,300)
 if ra~=300-t.Back or rb~=300+t.Ahead or ka~=ra-t.Hyst or kb~=rb+t.Hyst then capOk=false end
 if K.KeyCap(tier,22)~=(t.Back+t.Ahead+1+2*t.Hyst)*22 then capOk=false end
end
check(capOk,'tiers: keys reach >= 990 / 600 / 365 studs ahead (tier 3 / 2 / 1) with at most 3800 / 2400 / 1600 keys (R152: Back is larger); the near letters >= 140 / 95 / 55 studs ahead, letters (far ones included) >= 500 / 340 / 230')
-- R151: the near zone (Back rows) is at least 60 studs each side on every tier (it was 41 on tier 1, 65 on tier 2)
check(K.Near(3)*P>=110 and K.Near(2)*P>=85 and K.Near(1)*P>=60 and K.Near(1)==K.Tier(1).Near and K.Near(3)==K.Tier(3).Near,('R151 near zone: %.0f / %.0f / %.0f studs each side (tier 3 / 2 / 1), unchanged by R152'):format(K.Near(3)*P,K.Near(2)*P,K.Near(1)*P))
-- R152 (owner: "keys behind also not rendering"): Back, the keys behind the way the camera faces, covers a camera zoomed out to Roblox's 128 studs (it sees below and behind its own feet) on every tier
check(K.Tier(3).Back*P>=320 and K.Tier(2).Back*P>=225 and K.Tier(1).Back*P>=175 and K.Tier(1).Back*P>=128+40,('R152 keys behind: %.0f / %.0f / %.0f studs (tier 3 / 2 / 1; was 115 / 90 / 65)'):format(K.Tier(3).Back*P,K.Tier(2).Back*P,K.Tier(1).Back*P))
do local ok=true;for t=1,3 do local tt=K.Tier(t);if tt.FarBehind>tt.Back or tt.FarAhead>tt.Ahead or tt.FarBehind<tt.LegendBehind or tt.FarAhead<=tt.LegendAhead+tt.LegendFade or K.FarSide(t)>K.Side(t)or tt.Near>tt.Back then ok=false end end
 check(ok,'R152 letter reach lies inside the key window and beyond the near letters on every tier (FarBehind <= Back, FarAhead <= Ahead, past LegendAhead + the fade, FarSide <= Side, Near <= Back)')end
do local ok=true;for t=1,3 do local a,b=K.KeyWindow(g,t,300,0);local s=K.Side(t);if a~=300-s or b~=300+s or 2*s>K.Tier(t).Back+K.Tier(t).Ahead or s<K.Near(t)then ok=false end end
 check(ok,'R151 KeyWindow across the track (facing 0): Side rows each way, never more keys than along it, never less than the near zone')end
local a1,b1=K.KeyWindow(g,3,1);local a2,b2=K.KeyWindow(g,3,728);check(a1==1 and b2==728 and b1==123 and a2==728-K.Tier(3).Back,'KeyWindow clamps to the track')
do
 local t=K.Tier(3);local ra,rb,ka,kb=K.KeyWindow(g,3,400,-1)
 check(ra==400-t.Ahead and rb==400+t.Back and ka==ra-t.Hyst and kb==rb+t.Hyst,'KeyWindow facing -Z (a runner carrying a pack back to base): the long side lies toward -Z')
 local la,lb=K.LegendWindow(g,3,400,-1);check(la==400-t.LegendAhead and lb==400+t.LegendBehind,'LegendWindow follows the facing too')
 -- R151: three ways - along +Z, along -Z, across (sideways or straight down: symmetric); between the bands the current way is kept
check(K.Facing(.9,1)==1 and K.Facing(-.9,1)==-1 and K.Facing(.1,-1)==0 and K.Facing(-.1,1)==0 and K.Facing(0/0,-1)==-1 and K.Facing(.65,-1)==-1 and K.Facing(.65,0)==0
 and K.Facing(.8,0)==1 and K.Facing(0,1,0)==0 and K.Facing(-.3,1,.05)==-1 and K.Facing(.3,-1,.9)==0,
 'Facing (R151): along the track by the camera\'s heading (+-41 deg), across it within +-57 deg of sideways or looking straight down; between, the current way')
end
-- R152: the near letters (LegendAhead 18 rows) are never faded: the far letters carry on from them and fade over their last LegendFade rows (tier 3: solid to 60 rows ahead, gone after 64; behind: solid to 24, gone after 28)
check(K.LegendAlpha(3,0)==0 and K.LegendAlpha(3,-2)==0 and K.LegendAlpha(3,18)==0 and K.LegendAlpha(3,19)==0 and K.LegendAlpha(3,60)==0 and K.LegendAlpha(3,61)>0 and K.LegendAlpha(3,64)<1 and K.LegendAlpha(3,65)==1,'letters fade over the last 4 rows of the far reach (tier 3: solid to 60 rows ahead, gone after 64), the near rows never fade')
check(K.LegendAlpha(3,-24)==0 and K.LegendAlpha(3,-25)>0 and K.LegendAlpha(3,-29)==1 and K.LegendAlpha(3,-20,-1)==0 and K.LegendAlpha(3,20,-1)==0 and K.LegendAlpha(3,-61,-1)>0 and K.LegendAlpha(3,40,0)==0 and K.LegendAlpha(3,-60,0)==1,'...behind the runner too (24 .. 28 rows), the long side turns with the facing, across the track it is symmetric (FarSide 46)')
local fadeUp=true;for d=60,64 do if K.LegendAlpha(3,d+1)<K.LegendAlpha(3,d)then fadeUp=false end end;check(fadeUp,'...monotonically')
do local fw=K.FarLegendWindow(g,3,300,1);local _,fb=K.FarLegendWindow(g,3,300,1);local a2,b2=K.FarLegendWindow(g,3,300,-1);local a3,b3=K.FarLegendWindow(g,3,300,0)
 check(fw==300-28 and fb==300+64 and a2==300-64 and b2==300+28 and a3==300-46 and b3==300+46 and K.FarLegendWindow(g,3,1,1)==1 and select(2,K.FarLegendWindow(g,3,728,1))==728,'FarLegendWindow: 28 behind / 64 ahead (tier 3), mirrored facing -Z, 46 each way across the track, clamped to the track') end
check(K.Tier(3).LegendRadius>=20 and K.Tier(2).LegendRadius>=16 and K.Tier(1).LegendRadius>=12,'LegendRadius (the letters around the runner\'s feet other effects keep clear of) is set for every tier')
-- click cadence: per presser, evenly spaced, independent
do
 local gate=K.NewCadence(1/12);local times={}
 for i=0,599 do local t=i/60;if K.Allow(gate,t)then times[#times+1]=t end end
 local minGap,maxGap=1e9,0;for i=2,#times do local d=times[i]-times[i-1];minGap=min(minGap,d);maxGap=max(maxGap,d)end
 check(#times>=118 and #times<=121,'cadence: pressing every frame for 10 s gives 12 clicks a second ('..#times..')')
 check(minGap>=1/12-1e-6 and maxGap<=1/12+1/60+1e-6,('cadence: evenly spaced, never closer than 1/12 s nor further than 1/12 s + one frame (%.3f .. %.3f)'):format(minGap,maxGap))
 local g1,g2=K.NewCadence(1/12),K.NewCadence(1/12);local n1,n2=0,0
 for i=0,119 do local t=i/60;if K.Allow(g1,t)then n1+=1 end;if K.Allow(g2,t)then n2+=1 end end
 check(n1==n2 and n1>=23,'two pressers each keep their own full cadence (no shared budget): '..n1..' and '..n2..' clicks in 2 s')
 local g3=K.NewCadence(1/12);check(K.Allow(g3,5)and not K.Allow(g3,5)and not K.Allow(g3,5.05)and K.Allow(g3,5.0834)and K.Allow(g3,9),'cadence: the first press after a pause clicks at once; a second in the same instant never does (no stacked burst)')
 local slow=K.NewCadence(1/12);local ns=0;for i=0,9 do if K.Allow(slow,i*.3)then ns+=1 end end
 check(ns==10,'a runner pressing a new key every 0.3 s gets every click (no drop-outs below the cadence)')
 check(K.ClickPitch(3,5)==C.KeeperPitch and K.ClickPitch(1,1)==C.ClickPitches[1]and K.ClickPitch(2,#C.ClickPitches+1)==C.ClickPitches[1],'click pitch: players cycle the narrow band, keepers use their pitch')
end
-- R151: the Top-face SurfaceGui frame (canvas x -> world -Z, canvas y -> world +X; measured from the owner's live screenshots of R149) and the measured key top
do
 local cw,ch=K.TopCanvas(90,8.18,16)
 check(near(cw,8.18*16)and near(ch,90*16),'K.TopCanvas: a Top-face canvas is (Size.Z x Size.X) * PixelsPerStud: a 90 x 8.18 strip is 131 x 1440 px, not 1440 x 131')
 local px,py=K.TopPoint(10,100,90,8.18,16,10-45+4.09,100)
 check(near(px,4.09*16,1e-6)and near(py,4.09*16,1e-6),'K.TopPoint: the key centre at the strip\'s -X end is canvas (65, 65): x = half the row depth, y = half a key from the top')
 px,py=K.TopPoint(10,100,90,8.18,16,10+45-4.09,100)
 check(near(px,4.09*16,1e-6)and near(py,(90-4.09)*16,1e-6),'...and at its +X end canvas y runs to 1374 (a label there is inside a 1440 px tall canvas, but was far outside a 131 px wide one)')
 local wx,wz=K.TopWorld(10,100,90,8.18,16,px,py);check(near(wx,10+45-4.09,1e-9)and near(wz,100,1e-9),'K.TopWorld is the inverse of K.TopPoint')
 local rx,rz=K.TopReading(0);local ux,uz=K.TopUp(0)
 check(near(rx,0,1e-9)and near(rz,-1,1e-9)and near(ux,-1,1e-9)and near(uz,0,1e-9),'an unrotated label reads toward -Z with its up toward -X (the owner saw the spacebar name running along the track)')
 rx,rz=K.TopReading(C.Legend.Rotation);ux,uz=K.TopUp(C.Legend.Rotation)
 check(C.Legend.Rotation==270 and near(rx,-1,1e-9)and near(rz,0,1e-9)and near(ux,0,1e-9)and near(uz,1,1e-9),'Legend.Rotation 270: reads toward -X (a runner heading +Z has +X on his left, so this is left -> right) with its up toward +Z (upright)')
 -- the measured key top
 check(K.TopExtra(C.KeyY,C.KeyY,0,5,{})==0 and K.TopExtra(C.KeyY,nil,nil,nil,nil)==0 and K.TopExtra(C.KeyY,0/0,0/0,5,{0/0})==0,'TopExtra: nothing measured, or nothing above the configured top = 0 (NaN / nil are safe)')
 check(near(K.TopExtra(C.KeyY,C.KeyY+.6,0,5,{}),.3,1e-9)and near(K.TopExtra(C.KeyY,C.KeyY,.25,5,{}),.25,1e-9)and near(K.TopExtra(C.KeyY,C.KeyY,0,5,{5.1,5.35,4.9}),.35,1e-9),'TopExtra: a bigger Size.Y reading (half the difference), a mesh offset, a ray hit above the configured top: the biggest wins')
 check(K.TopExtra(C.KeyY,C.KeyY,0,5,{4.8,4.5})==0 and K.TopExtra(C.KeyY,C.KeyY,0,5,{5.003})==0,'TopExtra: hits below the configured top (a dished top, the middle of a dome) or within .005 add nothing')
 check(K.TopExtra(C.KeyY,C.KeyY,0,5,{9})==C.Legend.MaxExtra and C.Legend.MaxExtra==1.5,'TopExtra: capped at Legend.MaxExtra (1.5): a bad measurement cannot fling the letters away')
end
end
-- ======================================================================================================================
-- Part 2: the client script
-- ======================================================================================================================
local SRC=W.B.KeyboardTrackClient
check(not SRC:find('RemoteEvent',1,true)and not SRC:find('FireServer',1,true)and not SRC:find('InvokeServer',1,true)
 and not SRC:find('CollisionFidelity',1,true)and not SRC:find('RenderFidelity',1,true),'client source: no remote use, never writes CollisionFidelity / RenderFidelity')
check(not SRC:find('math.random',1,true)and not SRC:find('Random.new',1,true),'client source: no randomness (every client draws the same keyboard)')
local Players=W.service('Players');local player=R.new('Player');player.Name='Tester';player.UserId=77;player.Parent=Players;Players.LocalPlayer=player
local others={}
function Players.GetPlayers()local t={player};for _,p in ipairs(others)do t[#t+1]=p end;return t end
-- Mock gaps filled here: real BulkMoveTo, Sound:Play/Stop, ContentProvider, a controllable ClientFxBudget.
local bulkCalls,inBulk,bulkParts=0,false,0
local bulkBreak=false
function workspace.BulkMoveTo(_,parts,cfs)
 if bulkBreak then error('BulkMoveTo: injected failure')end
 bulkCalls+=1;bulkParts+=#parts;assert(#parts==#cfs,'BulkMoveTo lists must match')
 inBulk=true;for i,p in ipairs(parts)do p.CFrame=cfs[i]end;inBulk=false
end
local plays={}
-- R150: a click goes through SoundTiming.Play, which reads IsLoaded / Loaded / TimeLength like the engine's Sound has.
do local inew=R.Instance.new;R.Instance.new=function(class,parent)local o=inew(class,parent);if class=='Sound'then o.IsLoaded=true;o.Loaded=R.signal();o.TimeLength=1 end;return o end end
function R.Inst.Play(self)
 local anchor=self.Parent;self.Playing=true
 plays[#plays+1]={Id=self.SoundId,Speed=self.PlaybackSpeed,Volume=self.Volume,T=R.clock,TimePosition=self.TimePosition,Pos=anchor and anchor._props.CFrame and anchor._props.CFrame.Position,Group=self.SoundGroup,
  Min=self.RollOffMinDistance,Max=self.RollOffMaxDistance,Mode=self.RollOffMode,Sound=self}
end
function R.Inst.Stop(self)self.Playing=false end
local contentCalls=0
W.service('ContentProvider').PreloadAsync=function()contentCalls+=1 end
-- the shared mock's Clone copies an instance's tag set by reference; Roblox gives the clone its own copy of the tags
do local clone=R.Inst.Clone;R.Inst.Clone=function(self)local c=clone(self);local t=rawget(c._props,'_tags');if t then c._props._tags=table.clone(t)end;return c end end
local fxTier=3
W.stub('ClientFxBudget',{Get=function()return fxTier end,Low=function()return fxTier==1 end})
-- count writes per frame: Color on keys (= keys dressed), CFrame on keys outside BulkMoveTo. While `measure` is on, every property write on an
-- instance under the keyboard folder (visRoot) is counted too (all = everything but Parent; the rest by kind), and a part whose Transparency is
-- written twice in one frame is counted (tpTwice). cam = CFrame writes on the camera.
local writes={key=0,all=0,tp=0,tpTwice=0,pos=0,text=0,ink=0,vis=0,alpha=0,gui=0,strip=0,cam=0,fpos=0,ftext=0,fink=0,fvis=0,falpha=0,fstrip=0};local cframeWrites=0 -- (f... = the R152 far letters' strips)
local measure,visRoot,tpAt=false,nil,{}
-- what already existed when the real floor was hidden for the first time after `hideSeen` was reset (the end of start())
local hideSeen=nil
local function snapshot()local t={Bed=0,Spacebar=0,KeyClick=0,Key=0};for _,o in ipairs(R.created)do local n=o._props.Name;if t[n]~=nil and o._parent~=nil then t[n]+=1 end end;return t end
local function underKeyboard(o)local p=o._parent;while p do if p==visRoot then return true end;p=p._parent end;return false end
local origNew=R.instMeta.__newindex
R.instMeta.__newindex=function(o,k,v)
 local name=o._props.Name
 if k=='Color'and name=='Key'then writes.key+=1 end
 if k=='CFrame'and name=='Key'and not inBulk then cframeWrites+=1 end
 if k=='CFrame'and o==workspace.CurrentCamera then writes.cam+=1 end
 if k=='LocalTransparencyModifier'and v==1 and hideSeen==nil and name:match('^BiomeGround_')then hideSeen=snapshot()end
 if measure and k~='Parent'and visRoot and underKeyboard(o)then
  writes.all+=1
  if name=='Key'then
   if k=='Transparency'then writes.tp+=1;if tpAt[o]==R.clock then writes.tpTwice+=1 end;tpAt[o]=R.clock end
  elseif name=='Letter'then
   local far=o._parent and o._parent._props.Name=='FarLetters'
   if k=='Position'then if far then writes.fpos+=1 else writes.pos+=1 end elseif k=='Text'then if far then writes.ftext+=1 else writes.text+=1 end elseif k=='TextColor3'then if far then writes.fink+=1 else writes.ink+=1 end
   elseif k=='Visible'then if far then writes.fvis+=1 else writes.vis+=1 end elseif k=='TextTransparency'then if far then writes.falpha+=1 else writes.alpha+=1 end end
  elseif name=='LegendStrip'then
   if k=='CFrame'and v.Position.Y>0 then writes.strip+=1 end
  elseif name=='LegendFar'then
   if k=='CFrame'and v.Position.Y>0 then writes.fstrip+=1 end
  elseif k=='Enabled'then writes.gui+=1 end
 end
 return origNew(o,k,v)
end
local function resetWrites()writes.key=0 end
local function resetAll()for k in pairs(writes)do writes[k]=0 end;bulkParts=0 end

-- the world: map without the biome attributes yet; Obby/Biomes/<biome>/BiomeGround_n floors (top at y 4, the Storm floor running into
-- The Darkened's arena), a lobby floor before the track, the keycap template
local map=R.new('Model');map.Name='ChestChaseMap';map.Parent=workspace
local obby=R.new('Folder');obby.Name='Obby';obby.Parent=map
local biomesF=R.new('Folder');biomesF.Name='Biomes';biomesF.Parent=obby
local floors={}
for id=1,7 do
 local a,b=ATTR['BiomeStartZ_'..id],ATTR['BiomeEndZ_'..id]
 local m=R.new('Model');m.Name='Biome'..id;m:SetAttribute('Stage',id);m.Parent=biomesF
 local gp=R.new('Part');gp.Name='BiomeGround_'..id;gp.Size=V3(180,4,b-a);gp.CFrame=CF(0,2,(a+b)/2);gp.Anchored=true;gp.CanCollide=true;gp.Archivable=true
 gp.Color=R.Color3.fromRGB(80+id,150,90);gp.Material=R.Enum.Material.Grass;gp.Parent=m
 local edge=R.new('Part');edge.Name='LeftBiomeEdge';edge.Size=V3(4,1,b-a);edge.CFrame=CF(92,4.5,(a+b)/2);edge.Parent=m
 floors[id]=gp
end
local grassTex=R.new('Texture');grassTex.Name='Grass';grassTex.Parent=floors[1]
W.CS:AddTag(floors[7],'TrackFloor');floors[7]:SetAttribute('FloorKind','track')
local lobby=R.new('Part');lobby.Name='LobbyFloor';lobby.Size=V3(300,4,200);lobby.CFrame=CF(0,2,-200);lobby.Parent=map
local camps=R.new('Folder');camps.Name='GuardianEncounters';camps.Parent=map
local runtime=R.new('Folder');runtime.Name='_GameplayRuntime';runtime.Parent=map
local seeds=R.new('Folder');seeds.Name='Seeds';seeds.Parent=map
local template=R.new('MeshPart');template.Name='R142Keycap';template.Size=V3(10.55,6.39,10.55);template:SetAttribute('MeshId','rbxassetid://8837613273');template.Archivable=true
local tgui=R.new('SurfaceGui');tgui.Name='SurfaceGui';tgui.Face=R.Enum.NormalId.Top;tgui.Parent=template
local tlabel=R.new('TextLabel');tlabel.Name='TextLabel';tlabel.Text='A';tlabel.Parent=tgui
local tscript=R.new('Script');tscript.Name='StrayScript';tscript.Parent=template
template.Parent=RS
local function makeCharacter(name,x,z)
 local model=R.new('Model');model.Name=name
 local root=R.new('Part');root.Name='HumanoidRootPart';root.Size=V3(2,2,1);root.CFrame=CF(x,F+3,z);root.Parent=model
 local hum=R.new('Humanoid');hum.Health=100;hum.FloorMaterial=R.Enum.Material.Plastic;hum.HipHeight=2;hum.Parent=model
 model.PrimaryPart=root;model.Parent=workspace
 return model,root,hum
end
local keepPitRef=nil -- a hole left in place for the teardown check
local BR=60 -- the test row: deep inside Jungle, far from every biome edge
local P=g.Pitch
local function cx(col)return g.ColCenter(col)end
local function cz(row)local a,b=g.RowZ(row);return (a+b)/2 end
local char,root,hum=makeCharacter('Tester',cx(11),cz(BR));player.Character=char
local camera=workspace.CurrentCamera
local function look(dz,dx)camera.CFrame=R.CFrame.lookAt(V3(0,20,0),V3(dx or 0,20,dz))end
look(100) -- the camera looks down the track (+Z)
local PLASTIC,AIR=R.Enum.Material.Plastic,R.Enum.Material.Air
hum.FloorMaterial=AIR -- in the air: presses nothing until a test lands
local function put(x,y,z)root.CFrame=CF(x,y or F+3,z)end
local sc=R.new('LocalScript');sc.Name='KeyboardTrack'
local okLoad,errLoad=pcall(W.load,'KeyboardTrackClient',sc);check(okLoad,'client loads: '..tostring(errLoad))
frames(5)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil and floors[1].LocalTransparencyModifier~=1,'without the biome attributes nothing is built or hidden yet (it waits for them)')
for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
frames(60)
local vis=workspace:FindFirstChild('KeyboardTrackVisuals');visRoot=vis
check(vis~=nil,'the visuals folder appears once the attributes exist')
local keysF,bedF,legF,groundF=vis:FindFirstChild('Keys'),vis:FindFirstChild('Bed'),vis:FindFirstChild('Legends'),vis:FindFirstChild('Ground')
check(keysF and bedF and legF and groundF and vis:FindFirstChild('Sounds')and not vis:FindFirstChild('Blocks2'),'sub folders Bed / Keys / Legends / Sounds / Ground; no coarse block layers any more')
local function keyParts()local t={};for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'and p.Transparency==0 then t[#t+1]=p end end;return t end
local function top(p)return p.CFrame.Position.Y+p.Size.Y/2-((p.Name=='Key'and p._class=='MeshPart')and C.TopOffset or 0)end
-- index of the visible keys by cell: idx[row*64+col] = {count, part}; also reports keys not centred on a cell
local function keyIndex()
 local idx,off={},0
 for _,p in ipairs(keyParts())do
  local pos=p.CFrame.Position;local col,row=g.ColOfX(pos.X),g.RowOfZ(pos.Z)
  local x,z=g.CellCenter(row,col)
  if not x or abs(x-pos.X)>1e-6 or abs(z-pos.Z)>1e-6 then off+=1 end
  local k=row*64+col;local e=idx[k];if e then e[1]+=1 else idx[k]={1,p}end
 end
 return idx,off
end
local function keyAt(row,col)local idx=keyIndex();local e=idx[row*64+col];return e and e[1]==1 and e[2]or nil end
local function topOf(row,col)local p=keyAt(row,col);return p and top(p)end
local function barPart(i)for _,p in ipairs(keysF:GetChildren())do if p.Name=='Spacebar'and near(p.CFrame.Position.Z,(g.Bars[i].Z0+g.Bars[i].Z1)/2,.01)then return p end end;return nil end
local function nonRemote()
 for _,o in ipairs(R.created)do if o._class=='RemoteEvent'or o._class=='RemoteFunction'or o._class=='UnreliableRemoteEvent'then return false end end
 return true
end
check(nonRemote(),'no RemoteEvent / RemoteFunction was created')
-- every cell of rows ra .. rb (spacebar rows excepted) has exactly one key, centred, and no key lies outside them
local function coverage(ra,rb,label)
 local idx,off=keyIndex();local bare,dbl=0,0
 for r=max(1,ra),min(g.Rows,rb)do if not g.BarOfRow[r]then for c=1,22 do local e=idx[r*64+c];if not e then bare+=1 elseif e[1]>1 then dbl+=1 end end end end
 check(bare==0 and dbl==0 and off==0,('%s: every key cell of rows %d .. %d holds exactly one key, centred on its cell (%d bare, %d doubled, %d off-centre)'):format(label,ra,rb,bare,dbl,off))
 return bare,dbl
end
local function windowRows(z,tier)local fr=max(1,min(g.Rows,g.RowOfZ(z)));local a,b=K.KeyWindow(g,tier or 3,fr);return a,b,fr end

-- The Top-face SurfaceGui frame on Roblox, written out here independently of the module (R151, measured from the owner's live screenshots of R149:
-- the "S" and "V" he saw were the labels of column 11 = the one label per strip inside its canvas, and the spacebar name ran along the track):
-- canvas x -> world -Z, canvas y -> world +X, so a Top-face canvas in PixelsPerStud mode is (Size.Z x Size.X) * pps. An unrotated label reads along
-- -Z with its up toward -X; GuiObject.Rotation turns it clockwise.
local function canvasOf(part,pps)return part.Size.Z*pps,part.Size.X*pps end
local function worldOf(part,px,py,pps)local p=part.CFrame.Position;return p.X-part.Size.X/2+py/pps,p.Z+part.Size.Z/2-px/pps end
local function readsAlong(deg)local r=math.rad(deg);return math.sin(r),-math.cos(r)end
local function upOf(deg)local r=math.rad(deg);return -math.cos(r),-math.sin(r)end
-- R151: every key of every row that carries letters has exactly ONE visible label over it: the label lies completely inside its strip's canvas, sits on
-- the key's centre, reads upright (toward -X, up toward +Z), is that key's legend, and its strip's top stands above the key's top by at least
-- `extra` (the measured excess of the mesh over the configured top) + Legend.Margin. Returns the numbers for the message.
local function labelAudit(legendFolder,keysFolder,extra,label,minRows)
 local keyTop={}
 for _,p in ipairs(keysFolder:GetChildren())do
  if p.Name=='Key'and p.Transparency==0 then
   local pos=p.CFrame.Position;keyTop[g.RowOfZ(pos.Z)*64+g.ColOfX(pos.X)]=pos.Y+p.Size.Y/2 -- the key's visible top (a mesh key's centre carries TopOffset)
  end
 end
 local perRow,bad,labels,off,stripsN={}, {pos=0,canvas=0,text=0,upright=0,above=0,nokey=0,gui=0},0,0,0
 for _,st in ipairs(legendFolder:GetChildren())do
  if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 then
   stripsN+=1
   local gui=st:FindFirstChildWhichIsA('SurfaceGui');local cw,ch=canvasOf(st,LT.PixelsPerStud)
   if gui.Enabled==false or gui.Face~=R.Enum.NormalId.Top or gui.AlwaysOnTop~=false or gui.LightInfluence~=0 then bad.gui+=1 end
   for _,l in ipairs(gui:GetChildren())do
    if l._class=='TextLabel'then
     if not l.Visible then off+=1 else
      labels+=1
      local px,py=l.Position.X.Offset,l.Position.Y.Offset;local hw,hh=l.Size.X.Offset/2,l.Size.Y.Offset/2
      local wx,wz=worldOf(st,px,py,LT.PixelsPerStud);local row,col=g.RowOfZ(wz),g.ColOfX(wx);local cxk,czk=g.CellCenter(row,col)
      perRow[row]=perRow[row]or{};perRow[row][col]=(perRow[row][col]or 0)+1
      if px-hw<-1e-6 or px+hw>cw+1e-6 or py-hh<-1e-6 or py+hh>ch+1e-6 then bad.canvas+=1 end
      if not cxk or abs(cxk-wx)>1e-6 or abs(czk-wz)>1e-6 then bad.pos+=1 end
      if l.Text~=K.Legend(row,col)then bad.text+=1 end
      local rx,rz=readsAlong(l.Rotation);local ux,uz=upOf(l.Rotation)
      if not(near(rx,-1,1e-9)and near(rz,0,1e-9)and near(ux,0,1e-9)and near(uz,1,1e-9))then bad.upright+=1 end
      local kt=keyTop[row*64+col]
      if not kt then bad.nokey+=1 elseif st.CFrame.Position.Y+st.Size.Y/2<kt+extra+LT.Margin-1e-6 then bad.above+=1 end
     end
    end
   end
  end
 end
 local rowsN,missing=0,0
 for _,cols in pairs(perRow)do rowsN+=1;for c=1,22 do if cols[c]~=1 then missing+=1 end end end
 local ok=rowsN>=(minRows or 15)and missing==0 and labels==rowsN*22 and off==0
 for _,v in pairs(bad)do if v~=0 then ok=false end end
 check(ok,('%s: every key of %d letter rows (%d strips) has exactly one visible label over it (%d labels, %d missing / doubled, %d hidden; off-canvas %d, off-centre %d, wrong legend %d, not upright %d, not above the key top %d, no key %d, gui settings %d)'):format(
  label,rowsN,stripsN,labels,missing,off,bad.canvas,bad.pos,bad.text,bad.upright,bad.above,bad.nokey,bad.gui))
 return rowsN,labels
end

-- 1. what was built
do
local badParts,partCount=0,0
for _,o in ipairs(vis:GetDescendants())do
 if o:IsA('BasePart')then partCount+=1
  if o.Anchored~=true or o.CanCollide~=false or o.CanQuery~=false or o.CanTouch~=false or o.CastShadow~=false then badParts+=1 end
 end
end
check(partCount>2500 and badParts==0,'every keyboard part is Anchored, CanCollide / CanQuery / CanTouch / CastShadow false ('..partCount..' parts, '..badParts..' bad)')
-- the real floor: hidden for this client only, gameplay untouched
local allHidden=true;for _,fp in ipairs(floors)do if fp.LocalTransparencyModifier~=1 or fp.Transparency~=0 or fp.CanCollide~=true or fp.Parent==nil then allHidden=false end end
check(allHidden,'the real track floor (BiomeGround_1 .. 7) is hidden for this client only (LocalTransparencyModifier 1); Transparency / collision untouched')
check(grassTex.LocalTransparencyModifier==1,'...and so are its textures / decals')
local lateDecal=R.new('Decal');lateDecal.Name='Late';lateDecal.Parent=floors[2];frames(1)
check(lateDecal.LocalTransparencyModifier==1,'a decal that streams in after its floor was hidden is hidden at once (a Decal ignores its part\'s modifier)')
check(lobby.LocalTransparencyModifier~=1 and floors[1].Size.X==180 and floors[1].CFrame.Position.Y==2,'the lobby floor (not under the keyboard) is untouched; the floor parts are not moved or resized')
local patches=groundF:GetChildren()
local arena=patches[1]
check(#patches==1 and arena.Name=='GroundPatch'and near(arena.CFrame.Position.Z-arena.Size.Z/2,5860)and near(arena.CFrame.Position.Z+arena.Size.Z/2,5980)
 and near(arena.CFrame.Position.Y+arena.Size.Y/2,F)and near(arena.Size.X,180)and arena.LocalTransparencyModifier==0,'The Darkened\'s arena keeps its ground: a local copy of the Storm floor covers z 5860 .. 5980 at the floor height ('..#patches..' patches)')
check(arena.Color==floors[7].Color and arena.Material==floors[7].Material and arena.CanCollide==false and arena.CanQuery==false,'...same colour / material, not collidable or queryable (the real floor still is)')
check(not W.CS:HasTag(arena,'TrackFloor')and next(arena:GetAttributes())==nil and W.CS:HasTag(floors[7],'TrackFloor'),'...and it does not pass for the floor: no copied tags or attributes (the real floor keeps its own)')
-- keys: one representation, the same keycap everywhere
local keys=keyParts();local sizeOk,clsOk,scripts=true,true,0
for _,p in ipairs(keys)do
 if p._class~='MeshPart'then clsOk=false end
 if not near(p.Size.X,KW)or not near(p.Size.Z,KW)or not near(p.Size.Y,C.KeyY)then sizeOk=false end
 for _,d in ipairs(p:GetDescendants())do if d:IsA('BaseScript')then scripts+=1 end end
end
local ra,rb,fr=windowRows(cz(BR))
local wantKeys=0;for r=ra,rb do if not g.BarOfRow[r]then wantKeys+=22 end end
check(#keys==wantKeys,('tier 3: rows %d .. %d (12 behind, 122 ahead) are dressed: %d keys (got %d)'):format(ra,rb,wantKeys,#keys))
check(clsOk and sizeOk and scripts==0,'every key at every distance is a clone of the R142Keycap MeshPart at 7.68 x 4.65 x 7.68, scripts stripped (one look, no far blocks)')
local zFar=0;for _,p in ipairs(keys)do zFar=max(zFar,p.CFrame.Position.Z)end
check(zFar-cz(BR)>=990,('keys reach %.0f studs ahead of the runner (>= 990) with the same look'):format(zFar-cz(BR)))
coverage(ra,rb,'start')
local colourOk=true
for _,p in ipairs(keys)do local pos=p.CFrame.Position;local col,row=g.ColOfX(pos.X),g.RowOfZ(pos.Z);local want=K.CellColor(g.RowStage[row],row,col,1)
 if abs(p.Color.R-want.R)>1e-9 or abs(p.Color.G-want.G)>1e-9 or abs(p.Color.B-want.B)>1e-9 then colourOk=false end end
check(colourOk,'every key has its cell\'s biome colour (K.CellColor), near and far alike')
local restOk=true;for _,p in ipairs(keys)do if not near(top(p),K.KeyTop(0),1e-6)then restOk=false end end
check(restOk,'every resting key top is at the floor + 1.2 (near and far alike)')
-- effects authored at floor level (Storm lightning rings, shovel dirt: test_keyboard_fx.luau) read the key tops through KeyboardSurface149
do
 local KS=W.module('KeyboardSurface149');local kp=keys[#keys//2];local kpx,kpz=kp.CFrame.Position.X,kp.CFrame.Position.Z
 W.fxProbe={X=kpx,Z=kpz}
 check(near(KS.TopY(kpx,kpz),top(kp))and near(KS.Lift(kpx,kpz,F),top(kp)-F)and near(KS.Lift(kpx,kpz,F),C.RestRise),'effects: the helper\'s key-top height at a key is that key\'s top, a floor-level effect is lifted by the rest rise')
 local x0,x1,z0,z1=KS.Rect()
 check(near(x0,g.CenterX-g.HalfWidth)and near(x1,g.CenterX+g.HalfWidth)and near(z0,g.Z0)and near(z1,g.KeyEndZ),'effects: the helper covers the rectangle the keys cover (x '..tostring(x0)..' .. '..tostring(x1)..', z '..tostring(z0)..' .. '..tostring(z1)..')')
 check(KS.Lift(x1+1,kpz,F)==0 and KS.Lift(kpx,g.KeyEndZ+5,F)==0 and KS.Lift(kpx,g.Z0-5,F)==0 and KS.Lift(kpx,kpz,K.KeyTop(0)+1)==0,'effects: no lift beside the keys, in the arena, before the first biome, or for a surface already above the key tops')
 check(near(KS.Lift(kpx,kpz,F),C.HoleLift-.06),'effects: the same rise the shovel holes are lifted by (HoleLift - .06: the authored clearance and the lift that keeps the hole rim over the letters)')
end
-- bed and rims: each biome's grout colour, sunken
local bedParts,bedLen,bedOk,rimOk,rims,ends={},0,true,true,0,0
for _,p in ipairs(bedF:GetChildren())do
 local pos=p.CFrame.Position
 if p.Name=='Bed'then
  bedParts[#bedParts+1]=p;bedLen+=p.Size.Z
  local stage=g.BiomeAt(pos.Z);local r,gg,b=K.BedRGB(stage)
  if p.Size.Z>1024+1e-6 or not near(p.Size.X,180)or not near(pos.X,0)or not near(pos.Y+p.Size.Y/2,K.BedTop())then bedOk=false end
  if abs(p.Color.R*255-r)>.5 or abs(p.Color.G*255-gg)>.5 or abs(p.Color.B*255-b)>.5 then bedOk=false end
 elseif p.Name=='Rim'then rims+=1
  if not near(pos.Y+p.Size.Y/2,F-C.RimDrop)or abs(pos.X)-p.Size.X/2<89.9 or abs(pos.X)-p.Size.X/2>90 or pos.Y-p.Size.Y/2>K.BedTop()-C.BedThickness then rimOk=false end
 elseif p.Name=='RimEnd'then ends+=1
  if not near(pos.Y+p.Size.Y/2,F-C.RimDrop)then rimOk=false end
 end
end
local zLo,zHi=1e9,-1e9;for _,p in ipairs(bedParts)do zLo=min(zLo,p.CFrame.Position.Z-p.Size.Z/2);zHi=max(zHi,p.CFrame.Position.Z+p.Size.Z/2)end
check(bedOk and near(bedLen,5960)and near(zLo,-100,1e-6)and near(zHi,5860,1e-6),'the grout bed: per biome, in its own darker colour, pieces <= 1024 studs, 180 wide, 1.6 below the floor, from the track start to the arena ('..#bedParts..' pieces)')
check(rimOk and rims==2*#bedParts and ends==2,'a rim closes both sides (from under the bed to just below the floor top) and both ends of the keyboard')
check(C.RimDrop>=.04-1e-9 and near(F-.04-(F-C.RimDrop),C.RimDrop-.04)and 4.0-(F-C.RimDrop)>=.04-1e-9,'z-fighting (review part 2): the rim top is at least .04 under the floor top, so the end rims clear the lobby floor and the arena ground patch (both top at 4.00)')
-- no z-fighting: every horizontal surface the keyboard shows is clear of the (hidden) floor plane and of every other one it touches
local planes={}
for _,p in ipairs(vis:GetDescendants())do
 if p:IsA('BasePart')and p.Transparency<1 and p.Name~='GroundPatch'then local t=floor((p.CFrame.Position.Y+p.Size.Y/2)*1000+.5)/1000;planes[t]=(planes[t]or 0)+1 end
end
local nearFloor=0;local list={};for y in pairs(planes)do list[#list+1]=y;if abs(y-F)<.015 then nearFloor+=1 end end
table.sort(list)
check(nearFloor==0 and #list>=3,'no visible keyboard surface lies within 0.015 of the floor plane (planes: '..table.concat(list,', ')..')')
check(planes[floor(K.KeyTop(0)*1000+.5)/1000]and planes[floor(K.BedTop()*1000+.5)/1000]and K.KeyTop(0)-F>=1 and F-K.BedTop()>=1.5,'key tops 1.2 above and the bed 1.6 below the floor: nothing is coplanar with it')
-- neighbouring keys never overlap (no shared faces): gaps of >= 0.45 between key boxes in both directions
local gapOk=true;local z1,z2=cz(BR),cz(BR+1)
local kA,kB,kC=keyAt(BR,5),keyAt(BR,6),keyAt(BR+1,5)
if not(kA and kB and kC)then gapOk=false else
 if abs(kA.CFrame.Position.X-kB.CFrame.Position.X)-KW<.45 or abs(kA.CFrame.Position.Z-kC.CFrame.Position.Z)-KW<.45 then gapOk=false end end
check(gapOk,'neighbouring keys are 0.5 apart: no overlapping or touching faces')
-- letters on strips
local strips={};for _,p in ipairs(legF:GetChildren())do if p.Name=='LegendStrip'and p.CFrame.Position.Y>0 then strips[#strips+1]=p end end
local la,lb=K.LegendWindow(g,3,fr);local letterRows=0;for r=la,lb do if not g.BarOfRow[r]then letterRows+=1 end end
check(#strips==2*letterRows,('letters: two strips (11 letters each) per row from %d behind to %d ahead (%d strips for %d rows)'):format(fr-la,lb-fr,#strips,letterRows))
local stripOk,orderOk,inkOk2,posOk,yOk,inCanvas,faceOk,shownN=true,true,true,true,true,true,true,0
local rowsSeen={}
for _,st in ipairs(strips)do
 local gui=st:FindFirstChildWhichIsA('SurfaceGui');local pos=st.CFrame.Position
 -- the SurfaceGui settings of a strip: Top face, PixelsPerStud sizing at 16, no lighting, never on top of everything, a render limit, on while bound
 if not gui or gui.Face~=R.Enum.NormalId.Top or gui.SizingMode~=R.Enum.SurfaceGuiSizingMode.PixelsPerStud or gui.PixelsPerStud~=LT.PixelsPerStud or st.Transparency~=1 then stripOk=false end
 if not gui or gui.LightInfluence~=0 or gui.AlwaysOnTop~=false or gui.MaxDistance~=LT.MaxDistance or gui.Enabled==false then faceOk=false end
 if not near(pos.Y+st.Size.Y/2,K.KeyTop(0)+LT.Margin,1e-6)then yOk=false end
 local row=g.RowOfZ(pos.Z);rowsSeen[row]=(rowsSeen[row]or 0)+1
 local cw,ch=canvasOf(st,LT.PixelsPerStud)
 for _,l in ipairs(gui:GetChildren())do
  if l._class=='TextLabel'and l.Visible then
   shownN+=1
   local px,py=l.Position.X.Offset,l.Position.Y.Offset;local hw,hh=l.Size.X.Offset/2,l.Size.Y.Offset/2
   -- the label's whole box lies inside the canvas (a label outside the canvas is not drawn: R149's bug)
   if px-hw<-1e-6 or px+hw>cw+1e-6 or py-hh<-1e-6 or py+hh>ch+1e-6 then inCanvas=false end
   local wx,wz=worldOf(st,px,py,LT.PixelsPerStud)
   local col=g.ColOfX(wx);local x,z=g.CellCenter(row,col)
   if abs(x-wx)>1e-6 or abs(z-wz)>1e-6 then posOk=false end
   local rx,rz=readsAlong(l.Rotation);local ux,uz=upOf(l.Rotation)
   if l.Text~=K.Legend(row,col)or not(near(rx,-1,1e-9)and near(rz,0,1e-9)and near(ux,0,1e-9)and near(uz,1,1e-9))or l.AnchorPoint.X~=.5 or l.TextSize~=floor(LT.TextHeight*LT.PixelsPerStud+.5)then orderOk=false end
   local ink=K.ShadeInk(g.RowStage[row],K.ShadeIndex(g.RowStage[row],row,col,1))
   if abs(l.TextColor3.R*255-ink[1])>.5 or abs(l.TextColor3.G*255-ink[2])>.5 then inkOk2=false end
  end
 end
end
check(stripOk and yOk,'strips: invisible parts whose top stands .04 above the resting key tops, a Top-face SurfaceGui at 16 px / stud each')
check(faceOk,'strip SurfaceGuis: LightInfluence 0, AlwaysOnTop false (the keys in front hide the letters behind them), MaxDistance 420, Enabled while bound')
check(shownN==#strips*11,'every label of every bound strip is visible ('..shownN..' of '..(#strips*11)..')')
check(inCanvas,'every label lies completely inside its strip\'s Top-face canvas (depth x width in pixels: x toward -Z, y toward +X): none is left off the canvas')
check(posOk,'every letter sits exactly on its key\'s centre (canvas x = half the row depth, canvas y = the key\'s distance from the strip\'s -X end)')
check(orderOk,'every letter is its key\'s legend, turned 270 degrees about its centre (reads toward -X = a +Z runner\'s right, its up toward +Z), 4.6 studs tall')
check(inkOk2,'every letter has its key shade\'s ink')
-- a runner reads his row left -> right in keyboard order
local function lettersInRow(row)
 local out={}
 for _,st in ipairs(strips)do if g.RowOfZ(st.CFrame.Position.Z)==row then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui')
  for _,l in ipairs(gui:GetChildren())do if l._class=='TextLabel'and l.Visible then out[#out+1]={X=(worldOf(st,l.Position.X.Offset,l.Position.Y.Offset,LT.PixelsPerStud)),T=l.Text}end end
 end end
 table.sort(out,function(a,b)return a.X>b.X end) -- +X is a +Z runner's left: descending x = left -> right
 local t={};for _,e in ipairs(out)do t[#t+1]=e.T end;return table.concat(t)
end
local seqText=lettersInRow(BR+2)
check(#seqText==22 and K.LegendRows[(BR+2-1)%4+1]:rep(8):find(seqText,1,true)~=nil,'a +Z runner reads a row left -> right in keyboard order: '..seqText)
-- fading: solid near, fading over the last rows, none beyond
local alphaOk=true
for _,st in ipairs(strips)do
 local row=g.RowOfZ(st.CFrame.Position.Z);local want=K.LegendAlpha(3,row-fr)
 for _,l in ipairs(st:FindFirstChildWhichIsA('SurfaceGui'):GetChildren())do if l._class=='TextLabel'and not near(l.TextTransparency,want)then alphaOk=false end end
end
check(alphaOk,'letters are solid near the runner and fade over the farthest rows (TextTransparency = K.LegendAlpha)')
-- the spacebar of the biome ahead
put(cx(11),nil,g.Segs[3].StartZ-14);frames(30)
local bar3=barPart(3)
check(bar3~=nil and near(bar3.Size.X,180-C.Gap,.001)and bar3.Transparency==0,'the Desert spacebar spans the whole floor (180 - gap)')
check(bar3 and near(bar3.CFrame.Position.Z-bar3.Size.Z/2-C.Gap/2,530,1e-6)and near(bar3.Size.Z+C.Gap,g.Segs[3].RowPitch,1e-6)and near(bar3.Size.Y,C.KeyY),'...parallel to the entrance: it starts exactly at z 530, one row deep, as tall as the keys')
local bgui=bar3 and bar3:FindFirstChildWhichIsA('SurfaceGui');local blabel=bgui and bgui:FindFirstChildWhichIsA('TextLabel',true)
check(blabel and blabel.Text=='DESERT'and blabel.Rotation==270 and blabel.AnchorPoint.X==.5 and bgui.Face==R.Enum.NormalId.Top and bgui.Enabled~=false,'its label reads DESERT on the Top face, turned 270 degrees like every letter')
do -- R151 (owner: "the forest, desert named tiles must also be parallel to the safe zone and horizontal"): the name runs ACROSS the track
 local bpps=C.SpacebarPixelsPerStud;local cw,ch=canvasOf(bar3,bpps)
 local lw=blabel.Size.X.Scale*cw+blabel.Size.X.Offset;local lh=blabel.Size.Y.Scale*ch+blabel.Size.Y.Offset
 local rx,rz=readsAlong(blabel.Rotation);local ux,uz=upOf(blabel.Rotation)
 check(near(rx,-1,1e-9)and near(rz,0,1e-9),'the spacebar name reads along X (across the track, parallel to the SAFE ZONE line), toward -X = a runner heading +Z\'s right')
 check(near(ux,0,1e-9)and near(uz,1,1e-9),'...with its up toward +Z: upright for a runner approaching from the start')
 -- the label\'s own width runs along the canvas\' long side (world X after the turn), its height along the short one (world Z): the canvas is depth x width
 check(near(cw,bar3.Size.Z*bpps)and near(ch,bar3.Size.X*bpps)and ch>cw*10,'the spacebar canvas is '..string.format('%.0f x %.0f',cw,ch)..' px: 7.7 studs deep, 179.5 wide')
 check(lw>=ch*.8 and lw<=ch and lh>=cw*.8 and lh<=cw,('the label fills the bar after the turn: %.0f px along the bar (of %.0f), %.0f px across it (of %.0f)'):format(lw,ch,lh,cw))
 check(blabel.TextScaled==true and near(blabel.Position.X.Scale,.5)and near(blabel.Position.Y.Scale,.5)and blabel.AnchorPoint.Y==.5,'...centred on the bar, TextScaled to the bar\'s depth')
 local cx0,cz0=worldOf(bar3,cw/2,ch/2,bpps);check(near(cx0,bar3.CFrame.Position.X,1e-6)and near(cz0,bar3.CFrame.Position.Z,1e-6),'the canvas centre is the bar\'s centre (the name sits in the middle of the track)')
end
check(bar3 and abs(bar3.Color.R*255-K.Cream[1])<.5 and abs(bar3.Color.G*255-K.Cream[2])<.5 and near(top(bar3),K.KeyTop(0),1e-6),'the spacebar is cream at rest height')
local barsAll=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Spacebar'and p.Transparency==0 then barsAll+=1 end end
check(barsAll==7,'all seven spacebars are always there (biome names readable on arrival from any distance)')
-- colours in the world: four shades per biome, no bands
put(cx(11),nil,300);frames(40)
local jungle={};for _,p in ipairs(keyParts())do local z=p.CFrame.Position.Z;if z>100 and z<520 then jungle[#jungle+1]=p end end
local jz=K.Zone(6);local seen,inZone={},true
for _,p in ipairs(jungle)do
 local rgb={p.Color.R*255,p.Color.G*255,p.Color.B*255};local best,bi=1e9,0
 for i,sh in ipairs(jz.Shades)do local d=dist2(rgb,sh);if d<best then best,bi=d,i end end
 seen[bi]=true;local sh=jz.Shades[bi]
 if abs(rgb[1]-sh[1])>sh[1]*.045+1.5 or abs(rgb[2]-sh[2])>sh[2]*.045+1.5 or abs(rgb[3]-sh[3])>sh[3]*.045+1.5 then inZone=false end
end
local nSeen=0;for _ in pairs(seen)do nSeen+=1 end
check(#jungle>500 and inZone and nSeen==4,'Jungle keys are all deep green / lime: the four zone shades only ('..#jungle..' keys, '..nSeen..' shades)')
local byRow={};for _,p in ipairs(jungle)do local k=string.format('%.2f',p.CFrame.Position.Z);byRow[k]=byRow[k]or{};byRow[k][string.format('%.3f%.3f%.3f',p.Color.R,p.Color.G,p.Color.B)]=true end
local mono,rowsN=0,0;for _,set in pairs(byRow)do rowsN+=1;local n=0;for _ in pairs(set)do n+=1 end;if n<3 then mono+=1 end end
check(rowsN>=40 and mono==0,'no flat colour rows in the world ('..rowsN..' rows, '..mono..' flat)')
put(cx(11),nil,cz(BR));frames(40)
local keyN=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'then keyN+=1 end end
check(cframeWrites==keyN,'keys are parked by script once each and moved with BulkMoveTo only ('..cframeWrites..' direct writes on '..keyN..' keys)')
check(bulkCalls>0,'keys are positioned with BulkMoveTo')
local routed,ids,voices=0,{},0
for _,o in ipairs(R.created)do if o._class=='Sound'and o._props.Name=='KeyClickSound'then voices+=1;ids[o.SoundId]=(ids[o.SoundId]or 0)+1;if o.SoundGroup~=nil then routed+=1 end end end
local nIds=0;for _ in pairs(ids)do nIds+=1 end
check(voices==2*C.ClickVoices and routed==voices,'R152: a pool of '..C.ClickVoices..' voices for each of the two sounds (the click and the Forest / Jungle sound), routed through AudioMixer (Effects group) ('..voices..' voices, '..routed..' routed)')
check(nIds==2 and ids['rbxassetid://113108830240353']==C.ClickVoices and ids['rbxassetid://73942179280083']==C.ClickVoices,'every voice of a pool plays the same recording (the click 113108830240353; the Forest / Jungle sound 73942179280083)')
check(contentCalls>=1,'the click is preloaded')
-- the toolbox keycap template carries a SurfaceGui / TextLabel / Script; it is stripped ONCE and the keys are clones of the stripped copy: the
-- ~3,000 clones copy none of those children (R149 review part 1, finding 12: they were cloned and destroyed again for every pooled key)
do
 local scripts,guis,labels=0,0,0
 for _,o in ipairs(R.created)do if o._class=='Script'then scripts+=1 elseif o._class=='SurfaceGui'and o._props.Name=='SurfaceGui'then guis+=1 elseif o._class=='TextLabel'and o._props.Name=='TextLabel'then labels+=1 end end
 check(scripts<=2 and guis<=2 and labels<=2,('the template\'s own children are cloned at most twice in all (%d scripts, %d guis, %d labels), not once per key'):format(scripts,guis,labels))
 check(tscript.Parent==template and tgui.Parent==template and tlabel.Parent==tgui and RS:FindFirstChild('R142Keycap')==template,'...and the real template in ReplicatedStorage is left as it was')
 local kcs=keyParts();local bare=true;for _,pt in ipairs(kcs)do if #pt:GetChildren()~=0 then bare=false end end
 check(bare and #kcs>2500,'every key is a bare keycap (no child at all)')
end
print(('parts: %d keys (%d dressed), %d bed / rim parts, %d letter strips (%d letters), %d ground patches, 7 spacebars'):format(keyN,#keyParts(),#bedF:GetChildren(),#strips,#strips*11,#groundF:GetChildren()))
local c0=#R.created;frames(60);check(#R.created==c0,'standing still: no instance is created frame to frame ('..(#R.created-c0)..' in 60 frames)')
end

-- 1b. R149 review part 1, finding 1: the real floor is hidden (LocalTransparencyModifier 1), so it no longer stops the default camera from
-- sinking into the keys / under the bed. A render step right after the camera module lifts a low camera over the keyboard (or the arena
-- copy) to the key tops + 0.6 by translation (the look direction stays), and leaves Scriptable cameras, first person and everything off the
-- keyboard alone.
do
 local Run=W.Run;local CAM=R.Enum.CameraType
 local bound=W.rsBound['KeyboardCameraFloor']
 check(bound~=nil and bound.Prio==R.Enum.RenderPriority.Camera.Value+1,'the camera clamp is a render step bound right after the camera module (priority Camera + 1) once the keyboard is built')
 local MINY=K.KeyTop(0)+C.CameraAbove
 check(near(C.CameraAbove,.6)and near(MINY,5.8),'the clamp keeps the camera at least 0.6 above the resting key tops (5.8)')
 camera.CameraType=CAM.Custom;camera.Focus=nil
 local function aim(x,y,z)camera.CFrame=R.CFrame.lookAt(V3(x,y,z),V3(x+7,y+30,z+60))end
 local function sample(x,y,z,focus)aim(x,y,z);camera.Focus=focus;local look=camera.CFrame.LookVector;frames(1);local p=camera.CFrame.Position;return p,look,camera.CFrame.LookVector end
 local zk=cz(BR)
 local p,l0,l1=sample(0,2.5,zk,CF(0,10,zk+10))
 check(near(p.Y,MINY,1e-9)and near(p.X,0,1e-9)and near(p.Z,zk,1e-9),'a camera that sank between the keys (y 2.5) is lifted to 0.6 above the key tops (5.8), x / z untouched')
 check(near(l1.X,l0.X,1e-9)and near(l1.Y,l0.Y,1e-9)and near(l1.Z,l0.Z,1e-9),'...by translation only: its look direction is the same')
 p=sample(30,.5,zk,CF(30,10,zk+10))
 check(near(p.Y,MINY,1e-9),'a camera under the bed (y 0.5, looking up at its underside) is lifted too')
 resetAll();p=sample(0,MINY,zk,CF(0,12,zk));local atRest=writes.cam
 p=sample(0,MINY+.01,zk,CF(0,12,zk));p=sample(0,10,zk,CF(0,12,zk));p=sample(0,20,zk,CF(0,22,zk))
 check(atRest==1 and writes.cam==4,'a camera at or above 5.8 is never written (only the test\'s own CFrame writes: '..writes.cam..')')
 check(sample(0,3,5900,CF(0,12,5890)).Y==MINY or near(sample(0,3,5900,CF(0,12,5890)).Y,MINY,1e-9),'the arena copy (z 5860 .. 5980, no keys) has the same floor for the camera')
 check(near(sample(200,2,zk,CF(200,12,zk)).Y,2,1e-9)and near(sample(-91.5,2,zk,CF(0,12,zk)).Y,MINY,1e-9),'beside the field (x 200) the camera is left alone; 1.5 studs off the edge it is still lifted')
 check(near(sample(0,2,-300,CF(0,12,-300)).Y,2,1e-9)and near(sample(0,2,6100,CF(0,12,6100)).Y,2,1e-9),'before the first biome (the lobby) and past the arena the camera is left alone')
 camera.CameraType=CAM.Scriptable
 check(near(sample(0,2.5,zk,CF(0,10,zk+10)).Y,2.5,1e-9),'a Scriptable camera (the pack opening, cut-scenes) is never moved')
 camera.CameraType=CAM.Custom
 check(near(sample(0,2.5,zk,CF(0,3,zk)).Y,2.5,1e-9),'first person (the camera within a stud of its focus) is left alone')
 check(near(sample(0,2.5,zk,CF(0,5,zk)).Y,MINY,1e-9),'...a third person camera 2.5 studs from its focus is not first person')
 -- it runs AFTER the camera module: a camera module that sinks every frame is lifted every frame (not one frame late)
 Run:BindToRenderStep('FakeCameraModule',R.Enum.RenderPriority.Camera.Value,function()aim(5,2,zk);camera.Focus=CF(5,10,zk+10)end)
 local always=true;for _=1,5 do frames(1);if not near(camera.CFrame.Position.Y,MINY,1e-9)then always=false end end
 Run:UnbindFromRenderStep('FakeCameraModule')
 check(always,'the clamp runs after the camera module in the same frame (priority 201 after the camera at 200)')
 look(100);camera.Focus=nil;frames(2)
 resetAll();frames(30);check(writes.cam==0,'with the camera up where it belongs the clamp writes nothing, frame after frame')
 check(W.rsBound['KeyboardCameraFloor']~=nil and W.rsOrder[1]=='KeyboardCameraFloor'and #W.rsOrder==1,'one render step is bound (no duplicates)')
end
-- 1c. the real floor is hidden last (finding 9): at the end of start(), after everything that can fail, not before the keys / bed / sounds exist
check(hideSeen~=nil and hideSeen.Bed>0 and hideSeen.Spacebar==7 and hideSeen.KeyClick==2*C.ClickVoices,('the real floor is hidden at the very end of start(): the bed (%d pieces), 7 spacebars and %d click voices already existed'):format(hideSeen and hideSeen.Bed or 0,hideSeen and hideSeen.KeyClick or 0))

-- 1d. R151 (owner: "the words are missing, they only appear if under my foot"): in EVERY biome, at the start of its keys and in its middle, every key of every
-- row that carries letters has a visible label over it, in both half rows (columns 1 .. 11 and 12 .. 22), not just the one column that happened to sit
-- inside the canvas; and the mesh keys' tops are where the strips expect them.
do
 for _,seg in ipairs(g.Segs)do
  for _,off in ipairs({22,seg.Rows//2})do
   local z=select(1,g.RowZ(seg.FirstRow+min(off,seg.Rows-1)))+1
   put(cx(11),nil,z);frames(45)
   labelAudit(legF,keysF,0,seg.Name..' (row '..(seg.FirstRow+min(off,seg.Rows-1))..')')
  end
 end
 put(cx(11),nil,cz(BR));frames(45)
 -- the tiers: fewer rows, the same completeness (tier 1: a phone)
 fxTier=1;frames(60*4);labelAudit(legF,keysF,0,'tier 1',8);fxTier=3;frames(60*4)
 -- the key-top measurement is published for Studio's Explorer
 check(vis:GetAttribute('KeyTopConfigured')==K.KeyTop(0)and vis:GetAttribute('KeyTopExtra')==0 and near(vis:GetAttribute('LegendTop'),K.KeyTop(0)+LT.Margin,1e-9),'the keyboard folder publishes KeyTopConfigured / KeyTopExtra (0: nothing to add for a mesh whose top is the configured one) / LegendTop for Studio\'s Explorer')
end

-- 2. a runner presses a key and releases it
local R10,C20=BR,9
local function pressVol(p,stage,kind)local v=K.PressVolume(kind or'Key',stage);local lo=1;for _,gn in ipairs(C.ClickGains)do lo=min(lo,gn)end;return p~=nil and p.Volume<=v+1e-9 and p.Volume>=v*lo-1e-9 end
do
plays={};hum.FloorMaterial=PLASTIC;put(cx(C20),nil,cz(R10));frames(3)
check(topOf(R10,C20)and topOf(R10,C20)<K.KeyTop(0)-.1,'a key goes down under the runner (mid-press)')
frames(8)
check(near(topOf(R10,C20),K.KeyTop(1),1e-6),'...to the pressed height (top = floor + 0.05: level with his feet, got '..tostring(topOf(R10,C20))..')')
check(near(topOf(R10,C20+1),K.KeyTop(0),1e-6)and near(topOf(R10+1,C20),K.KeyTop(0),1e-6)and near(topOf(R10-1,C20),K.KeyTop(0),1e-6),'its neighbours stay up')
do -- R151: the press is clearly visible (>= 1 stud of travel) and the feet stay planted
 local feetY=root.CFrame.Position.Y-C.PlayerRootToFeet
 check(K.KeyTop(0)-topOf(R10,C20)>=1.1 and K.KeyTop(0)-topOf(R10,C20)<=1.2,'the key travels 1.15 studs under his foot ('..string.format('%.3f',K.KeyTop(0)-topOf(R10,C20))..'; was .47)')
 check(topOf(R10,C20)>=feetY-1e-9 and topOf(R10,C20)-feetY<=.1,'feet stay planted: the pressed key top is level with the soles (the real floor top, +'..string.format('%.2f',topOf(R10,C20)-feetY)..'), never under them (no hovering) nor above them (no sinking)')
 check(K.KeyTop(0)-feetY>=1.1,'the keys around him stand 1.2 above his soles at rest: a pressed key is a clear dent in the keyboard')
end
check(#plays==1 and plays[1].Id=='rbxassetid://73942179280083','one sound played for the one key, in a Jungle row (R152: the key sound 73942179280083, not the click) ('..#plays..')')
check(plays[1]and plays[1].Speed>=.98 and plays[1].Speed<=1.02 and pressVol(plays[1],g.RowStage[R10]),'own press: pitch within 0.98 .. 1.02, volume 1.8 x the click-to-click gain (.91 .. 1)')
check(plays[1]and plays[1].Group and plays[1].Group.Name=='GardenEffects','clicks go through the Effects sound group (AudioMixer.Route)')
check(plays[1]and near(plays[1].Pos.X,cx(C20),.01)and near(plays[1].Pos.Z,cz(R10),.01)and plays[1].Min==C.ClickRollOffMin and plays[1].Max==C.ClickRollOffMax,'the click is played at the key, with the one roll-off rule')
-- the pressed key carries its letter; the strip's label for it is hidden meanwhile
local kp=keyAt(R10,C20);local kgui=kp and kp:FindFirstChildWhichIsA('SurfaceGui');local klabel=kgui and kgui:FindFirstChildWhichIsA('TextLabel')
check(kgui and kgui.Face==R.Enum.NormalId.Top and klabel and klabel.Text==K.Legend(R10,C20)and klabel.Rotation==270 and klabel.TextSize==floor(LT.TextHeight*LT.PixelsPerStud+.5),'a key that is down carries its own letter (same size, turned 270 degrees = upright for a +Z runner) while it moves')
local function stripLabel(row,col)
 for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 and g.RowOfZ(st.CFrame.Position.Z)==row then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui')
  for _,l in ipairs(gui:GetChildren())do
   if l._class=='TextLabel'and l.Text~=''then
    local wx=worldOf(st,l.Position.X.Offset,l.Position.Y.Offset,LT.PixelsPerStud)
    if g.ColOfX(wx)==col and wx<st.CFrame.Position.X+st.Size.X/2 and wx>st.CFrame.Position.X-st.Size.X/2 then return l end
   end
  end
 end end
end
local sl=stripLabel(R10,C20)
check(sl and sl.Visible==false,'...and its letter on the strip is hidden meanwhile (no doubled letter)')
put(cx(C20)+20,nil,cz(R10));frames(14)
check(near(topOf(R10,C20),K.KeyTop(0),1e-6),'the key comes back up when the runner leaves')
check(kp:FindFirstChildWhichIsA('SurfaceGui')==nil and sl.Visible==true,'back at rest it gives its letter back to the strip')
local Mixer=W.module('AudioMixer');Mixer.Set('Effects',0);plays={}
put(cx(C20),nil,cz(R10+3));frames(12);put(cx(C20)+20,nil,cz(R10));frames(12)
check(#plays==0,'Effects volume 0 (Settings): the keys still move but nothing is played')
Mixer.Set('Effects',100);plays={}
put(cx(C20),nil,cz(R10));frames(12)
check(#plays==1,'...and clicks are back with the volume')
-- R150: the click starts at SoundTiming's lead-in for its file (the one shared table: 0 until the owner measures it), not a hard-coded 0.
check(plays[1]and near(plays[1].TimePosition,0,1e-9),'R150: the click starts at SoundTiming\'s lead-in for its file (0 until measured) ('..tostring(plays[1]and plays[1].TimePosition)..')')
do
 local ts=W.RS:FindFirstChild('SoundTiming');ts:SetAttribute('Start_73942179280083',.07)
 put(cx(C20)+20,nil,cz(R10));frames(14);plays={}
 put(cx(C20),nil,cz(R10));frames(12)
 check(plays[1]and near(plays[1].TimePosition,.07,1e-9),'R150: Start_<id> on SoundTiming moves the sound (tuned in Studio, no code change; here the Jungle sound) ('..tostring(plays[1]and plays[1].TimePosition)..')')
 ts:SetAttribute('Start_73942179280083',nil)
end
put(cx(C20)+20,nil,cz(R10));frames(14);plays={}
-- standing on a corner shared by 4 keys presses all 4 - with ONE click (owner: no stacked bursts)
local zc=select(2,g.RowZ(R10))
put(cx(C20)-P/2,nil,zc);frames(12)
local cornerDown=0;for _,cc in ipairs({C20,C20+1})do for _,rr in ipairs({R10,R10+1})do if near(topOf(rr,cc),K.KeyTop(1),1e-6)then cornerDown+=1 end end end
check(cornerDown==4 and #plays==1,'standing on a corner presses the 4 keys under the +-1.2 footprint with one click, not four stacked ('..cornerDown..' down, '..#plays..' clicks)')
put(cx(C20)+20,nil,cz(R10))
local maxTop=0
for _=1,15 do frames(1);local t=topOf(R10,C20);if t then maxTop=max(maxTop,t)end end
check(maxTop-K.KeyTop(0)>=.06 and maxTop-K.KeyTop(0)<=.3,'release springs a little past rest (back-out: +'..string.format('%.3f',maxTop-K.KeyTop(0))..' of the 1.15 travel)')
frames(10);check(near(topOf(R10,C20),K.KeyTop(0),1e-6),'...and settles at rest')
do -- R151: the key ahead is down when the foot gets there (the footprint covers PressLead seconds of the runner's velocity in front of it)
 local zEdge=select(2,g.RowZ(R10))
 local function downRows(v)
  put(cx(C20)+30,nil,cz(R10));root.AssemblyLinearVelocity=V3(0,0,0);frames(14) -- everything up
  put(cx(C20),nil,zEdge-1.6);root.AssemblyLinearVelocity=v;frames(12)
  local t={};for dr=-1,3 do t[dr]=near(topOf(R10+dr,C20),K.KeyTop(1),1e-6)end
  return t
 end
 local still=downRows(V3(0,0,0))
 check(still[0]and not still[1]and not still[-1],'standing 1.6 studs short of the next row: only his own key is down (the +-1.2 footprint does not reach it)')
 local fast=downRows(V3(0,0,40))
 check(fast[0]and fast[1]and not fast[2]and not fast[-1],'running at 40 studs/s (+2.4 studs of lead) the key in front goes down early, the key behind is not extended')
 local faster=downRows(V3(0,0,1000))
 check(faster[1]and not faster[2]and not faster[3],'at 1000 studs/s the lead is capped at '..C.PressLeadMax..' studs: no run of keys goes down ahead of him')
 local side=downRows(V3(300,0,0))
 check(side[0]and not side[1],'the lead follows the velocity: sideways speed presses the neighbouring column, not the next row')
 root.AssemblyLinearVelocity=V3(0,0,0);put(cx(C20)+30,nil,cz(R10));frames(14)
end
put(cx(C20),nil,cz(R10));frames(10);check(near(topOf(R10,C20),K.KeyTop(1),1e-6),'back on a key: pressed')
hum.FloorMaterial=AIR;put(cx(C20),F+7,cz(R10));frames(14)
check(near(topOf(R10,C20),K.KeyTop(0),1e-6),'in the air the key is up (FloorMaterial == Air)')
hum.FloorMaterial=PLASTIC;put(cx(C20),nil,cz(R10));frames(10)
check(near(topOf(R10,C20),K.KeyTop(1),1e-6),'landing presses it again')
hum.Health=0;frames(14);check(near(topOf(R10,C20),K.KeyTop(0),1e-6),'a dead character presses nothing');hum.Health=100
-- walking at a normal pace: every new key clicks (no random drop-outs)
put(cx(C20),nil,cz(R10+20));frames(20);plays={}
local z=cz(R10+20);local stepsKeys={}
for f=1,180 do z+=24/60;put(cx(C20),nil,z);frames(1);stepsKeys[g.RowOfZ(z)]=true end
local newKeys=0;for _ in pairs(stepsKeys)do newKeys+=1 end
check(#plays==newKeys-1 or #plays==newKeys,'walking at 24 studs/s every key stepped on clicks once ('..#plays..' clicks for '..newKeys..' keys)')
-- spacebar: the whole bar goes down
put(cx(8),nil,g.Segs[1].StartZ+2);frames(30)
local bar1=barPart(1)
check(bar1~=nil and near(top(bar1),K.KeyTop(1),1e-6),'stepping anywhere on a spacebar presses the whole bar')
put(cx(8),nil,60);frames(20);check(near(top(bar1),K.KeyTop(0),1e-6),'...and it comes back up')
end
-- 3. reduced motion
do
W.Gui.ReducedMotionEnabled=true
put(cx(C20),nil,cz(R10+5));frames(1)
check(near(topOf(R10+5,C20),K.KeyTop(1),1e-6),'reduced motion: the key is pressed at once')
put(cx(C20),nil,cz(R10));local overshoot=false;local firstUp=nil
for i=1,3 do frames(1);local t=topOf(R10+5,C20);if i==1 then firstUp=t end;if t and t>K.KeyTop(0)+1e-6 then overshoot=true end end
check(near(firstUp,K.KeyTop(0),1e-6)and not overshoot,'reduced motion: released at once, no bounce')
W.Gui.ReducedMotionEnabled=false
frames(5)
end
-- 4. sprinting: steady clicks, bounded work, keys always there around the runner
do
hum.FloorMaterial=PLASTIC;put(cx(11),nil,cz(BR));frames(60);plays={};resetWrites()
local worst=0;local z=cz(BR);local createdMax=0
for f=1,300 do
 z+=1000/60;put(cx(11),nil,z)
 resetWrites();local createdN=#R.created
 frames(1)
 worst=max(worst,writes.key);createdMax=max(createdMax,#R.created-createdN)
end
check(worst<=K.Tier(3).Bind,('1000 studs/s: at most the per-frame budget of keys dressed in a frame (%d / %d)'):format(worst,K.Tier(3).Bind))
local gaps,minGap,maxGap={},1e9,0
for i=2,#plays do local d=plays[i].T-plays[i-1].T;gaps[#gaps+1]=d;minGap=min(minGap,d);maxGap=max(maxGap,d)end
check(#plays>=55 and #plays<=61,'sprinting at 1000 studs/s for 5 s: a steady 12 clicks a second ('..#plays..')')
check(minGap>=1/12-1e-6 and maxGap<=1/12+1/60+1e-6,('...evenly spaced: every gap between 1/12 s and 1/12 s + one frame (%.3f .. %.3f s), no bursts, no holes'):format(minGap,maxGap))
local pitchSet={};for _,p in ipairs(plays)do pitchSet[p.Speed]=true end;local distinct=0;for _ in pairs(pitchSet)do distinct+=1 end
check(distinct>=3 and distinct<=#C.ClickPitches,'own click pitch varies a little between steps ('..distinct..' pitches, all in 0.98 .. 1.02)')
frames(40);local a,b=windowRows(z);coverage(a,b,'after the sprint')
end
-- 4b. fast runners never see missing keys around them: rows are dressed nearest first, the per-frame budget covers 1000 studs/s
do
 local summary={}
 for _,cfg in ipairs({{300,60},{500,45},{1000,60},{1000,30}})do
  local speed,fps=cfg[1],cfg[2]
  hum.FloorMaterial=PLASTIC;put(cx(11),nil,cz(BR));frames(80)
  local z=cz(BR);local bare,probes,over,peak=0,0,0,0
  local scale=min(2,max(1,60/fps))
  for f=1,fps*3 do
   z+=speed/fps;put(cx(11),nil,z);resetWrites()
   frames(1,1/fps)
   if writes.key>floor(K.Tier(3).Bind*scale)then over+=1 end
   if f%3==0 then
    local idx=keyIndex();local fr=g.RowOfZ(z)
    -- every key cell from 45 studs behind to 300 studs ahead
    for r=max(1,fr-5),min(g.Rows,fr+36)do if not g.BarOfRow[r]then for c=1,22,3 do probes+=1;local e=idx[r*64+c];if not e or e[1]~=1 then bare+=1 end end end end
    local n=0;for _ in pairs(idx)do n+=1 end;peak=max(peak,n)
   end
  end
  summary[#summary+1]=('%d@%d: %d missing / %d probes, peak %d keys'):format(speed,fps,bare,probes,peak)
  check(bare==0,('%d studs/s at %d fps: every key from 45 behind to 300 ahead of the runner is there in every frame (%d probes, %d missing)'):format(speed,fps,probes,bare))
  check(over==0,('%d studs/s at %d fps: the keys dressed per frame stay within the budget x min(2, dt * 60)'):format(speed,fps))
  check(peak<=K.KeyCap(3,22),('%d studs/s at %d fps: the cap holds (%d <= %d)'):format(speed,fps,peak,K.KeyCap(3,22)))
 end
 print('sprints: '..table.concat(summary,' | '))
end
-- 4c. R149 review part 1 (findings 7 and 8): what a sprint writes. Inside the Snow biome (one row pitch, so a letter strip rebound on another row
-- keeps its label positions) at 1000 studs/s on tier 3. Unchanged label values are not written; a recycled key is written once, not hidden and shown
-- again in the same frame; a parked letter strip is switched off (its SurfaceGui is not rendered), a bound one is on.
do
 hum.FloorMaterial=PLASTIC;put(cx(11),nil,1300);frames(80)
 local made=0;for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'then made+=1 end end
 local farBefore=0;for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendFar'then farBefore+=1 end end
 measure=true;visRoot=workspace.KeyboardTrackVisuals;resetAll()
 local z=1300;local n=36
 for f=1,n do z+=1000/60;put(cx(11),nil,z);frames(1)end
 measure=false
 local rowsDressed=writes.key/22;local stripsBound=writes.strip
 local naive=stripsBound*11
  print(('sprint writes: 1000 studs/s for %d frames (tier 3, %d letter strips made): %d property writes in all = %.0f a frame; %d near strips bound; near labels: Position %d, Text %d, TextColor3 %d, Visible %d, TextTransparency %d of %d each if every label were rewritten; far strips bound %d (labels: Position %d, Text %d, TextColor3 %d, Visible %d, TextTransparency %d); strip guis switched %d times; keys dressed %d, key Transparency writes %d (twice in one frame: %d)'):format(
  n,made,writes.all,writes.all/n,stripsBound,writes.pos,writes.text,writes.ink,writes.vis,writes.alpha,naive,writes.fstrip,writes.fpos,writes.ftext,writes.fink,writes.fvis,writes.falpha,writes.gui,writes.key,writes.tp,writes.tpTwice))
 -- R152: the far strips keep their label positions too: a Position is only written when a strip is made (22 labels), never when it is bound to another row
 local farAfter=0;for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendFar'then farAfter+=1 end end
 check(writes.fstrip>=40 and writes.fpos<=farAfter*22 and writes.fpos<writes.fstrip*22*.5,('R152 far letters: %d far strips bound by the sprint, %d Position writes (a strip of the pool only writes its 22 positions once, when it first serves a row of this biome; %d strips in the pool; %d made during the sprint)'):format(writes.fstrip,writes.fpos,farAfter,farAfter-farBefore))
 check(writes.fvis<=writes.fstrip*22*.1,('...and %d Visible writes for %d far strips bound (a label is only shown / hidden when its key goes down / up)'):format(writes.fvis,writes.fstrip))
 check(stripsBound>=40 and writes.key>=22*40,('the sprint dressed %d rows of keys and %d strips'):format(rowsDressed,stripsBound))
 check(writes.pos<=naive*.25,('letter labels keep their positions: %d Position writes (a rewrite of every bound label would be %d)'):format(writes.pos,naive))
 check(writes.vis<=naive*.1,('...and their Visible flag: %d writes (%d if every label were rewritten)'):format(writes.vis,naive))
 check(writes.tp<=writes.key*.1,('a recycled key is not hidden and shown again: %d Transparency writes for %d keys dressed (one write for a key that is dressed again in the same pass)'):format(writes.tp,writes.key))
 check(writes.tpTwice==0,'no key has its Transparency written twice in one frame')
 -- parked strips are off, bound strips are on
 local on,off,onParked,offBound=0,0,0,0
 for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui');local active=st.CFrame.Position.Y>0
  if active then if gui.Enabled==true then on+=1 else offBound+=1 end else if gui.Enabled==false then off+=1 else onParked+=1 end end
 end end
 check(on>=40 and offBound==0 and onParked==0,('bound letter strips have their SurfaceGui on (%d), parked ones have it off (%d parked, %d parked ones still on, %d bound ones off)'):format(on,off,onParked,offBound))
 check(off>=0,'(parked strips: '..off..')')
 -- a teleport away leaves every strip of the old place parked and disabled, and the new place's strips enabled again
 put(cx(11),nil,3000);frames(60)
 local act,parked,bad=0,0,0
 for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui');local active=st.CFrame.Position.Y>0
  if active then act+=1;if gui.Enabled~=true then bad+=1 end else parked+=1;if gui.Enabled~=false then bad+=1 end end
 end end
 check(act>=40 and parked>=1 and bad==0,('after a 1,700-stud teleport: %d strips bound and on, %d parked and off, %d wrong'):format(act,parked,bad))
 -- the guis' look is unchanged: 16 px per stud, the same render limit; the spacebars have one too
 local lookOk=true
 for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'then local gui=st:FindFirstChildWhichIsA('SurfaceGui');if gui.PixelsPerStud~=16 or gui.MaxDistance~=LT.MaxDistance then lookOk=false end end end
 check(lookOk and LT.PixelsPerStud==16,'letter strips are still 16 px per stud with MaxDistance '..LT.MaxDistance)
 local barsOk=0
 for _,p in ipairs(keysF:GetChildren())do if p.Name=='Spacebar'then local gui=p:FindFirstChildWhichIsA('SurfaceGui');if gui and gui.MaxDistance==C.SpacebarMaxDistance and C.SpacebarMaxDistance>=LT.MaxDistance then barsOk+=1 end end end
 check(barsOk==7,'the seven spacebar labels have a render limit too ('..C.SpacebarMaxDistance..' studs, at least the strips\' '..LT.MaxDistance..')')
 put(cx(11),nil,cz(BR));frames(80)
end
-- 5. trips of 1000+ studs and back: nothing leaks, nothing exceeds the caps
do
put(cx(11),nil,cz(BR));frames(60)
local function trip()
 for _,zz in ipairs({600,1500,2600,4000,5500,5850,3000,1000,-80})do
  put(cx(11),nil,zz);frames(40)
  local n=#keyParts()
  check(n<=K.KeyCap(3,22),('tier 3 cap holds at z %d (%d keys)'):format(zz,n))
  local a,b=windowRows(zz);local bare=coverage(a,b,'trip z '..zz)
 end
 put(cx(11),nil,cz(BR));frames(40)
end
local n0=#vis:GetDescendants()
trip();local n1=#vis:GetDescendants()
trip();local n2=#vis:GetDescendants()
check(n2<=n1 and n1<=n0+600,'after trips of 1000+ studs and back the instance count does not grow (start '..n0..', after one trip '..n1..', after two '..n2..')')
local keyTotal=0;for _,p in ipairs(keysF:GetChildren())do if p.Name=='Key'then keyTotal+=1 end end
check(keyTotal<=K.KeyCap(3,22),'the key pool never grows past the tier-3 cap ('..keyTotal..' parts made, cap '..K.KeyCap(3,22)..')')
print(('counts: %d instances under the keyboard folder, %d key parts in the pool'):format(n2,keyTotal))
end
-- a teleport (respawn, a teleport pad): the keys around the runner are there at once, the rest follows within a few frames
do
 local summary={};local worstNear,worstSettle,over=0,0,0
 for _,jump in ipairs({260,700,1500,-700,-1500})do
  hum.FloorMaterial=PLASTIC;put(cx(11),nil,2400);frames(80)
  local z1=2400+jump;put(cx(11),nil,z1)
  local settled=nil
  for f=1,20 do
   resetWrites();frames(1)
   if writes.key>K.Tier(3).Bind*C.TeleportBurst then over+=1 end
   local idx=keyIndex();local fr=g.RowOfZ(z1);local missingNear,missingAll=0,0
   local a,b=K.KeyWindow(g,3,fr)
   for r=a,b do if not g.BarOfRow[r]then for c=1,22,3 do local e=idx[r*64+c];if not e or e[1]~=1 then missingAll+=1;if r>=fr-5 and r<=fr+12 then missingNear+=1 end end end end end
   if f==1 then worstNear=max(worstNear,missingNear)end
   if missingAll==0 and not settled then settled=f end
  end
  worstSettle=max(worstSettle,settled or 99)
  summary[#summary+1]=('%+d: whole window after %s frames'):format(jump,tostring(settled))
 end
 print('teleports: '..table.concat(summary,' | '))
 check(worstNear==0,'teleports of 260 .. 1500 studs: the keys from 45 behind to 100 ahead are there on the very first frame')
 check(worstSettle<=15,'teleports: the whole ~1000-stud window is dressed within 15 frames ('..worstSettle..')')
 check(over==0,'teleports: the keys dressed per frame stay within the budget (x'..C.TeleportBurst..' while the rows around the runner are missing)')
 -- teleport pads back to back: a jump every frame
 local seq={900,2900,1500,3600,600,2400,4100,1200,3300,2000,500,3900};local peak=0
 for i=1,#seq*2 do put(cx(11),nil,seq[(i-1)%#seq+1]);frames(1);peak=max(peak,#keyParts())end
 check(peak<=K.KeyCap(3,22),'twenty-four teleports one frame apart: the cap holds ('..peak..')')
 frames(40);local a,b=windowRows(seq[(#seq*2-1)%#seq+1]);coverage(a,b,'after twenty-four teleports')
end
-- 5b. turning round (a runner carrying a pack back to base looks toward -Z): the long side of the window follows the camera
do
 hum.FloorMaterial=AIR;put(cx(11),F+9,2400);frames(60)
 local function reach()local lo,hi=1e9,-1e9;for _,p in ipairs(keyParts())do local z=p.CFrame.Position.Z;lo=min(lo,z);hi=max(hi,z)end;return 2400-lo,hi-2400 end
 local behind,ahead=reach()
 local B3=K.Tier(3).Back;local S3=K.Side(3)
 check(ahead>=990 and behind<=B3*P+4*P+P,('facing +Z: keys reach %.0f studs ahead, %.0f behind'):format(ahead,behind))
 look(0,100);frames(30);local b2,a2=reach()
 check(b2>=S3*P-P and a2>=S3*P-P and b2<=(S3+5)*P and a2<=(S3+5)*P,('R151: looking across the track: keys reach %.0f / %.0f studs each way (Side %d rows)'):format(b2,a2,S3))
 look(-100);frames(6);local b3,a3=reach()
 check(near(b3,b2,1e-6)and near(a3,a2,1e-6),'a glance back shorter than the hold (0.2 s) changes nothing')
 look(100);frames(30);look(-100)
 local over,settled=0,nil;resetWrites()
 for f=1,60 do
  resetWrites();frames(1)
  if writes.key>K.Tier(3).Bind then over+=1 end
  local bb,aa=reach();if not settled and bb>=990 then settled=f end
 end
 local bk,ak=reach()
 check(bk>=990 and ak<=B3*P+4*P+P,('after turning round (camera toward -Z): keys reach %.0f studs toward -Z, %.0f toward +Z'):format(bk,ak))
 -- R149 review part 1: a turn is not a burst any more (it was 4x the budget in two frames); it is dressed nearest first at the normal rate
 local holdFrames=math.ceil(C.FacingHoldSeconds*60)+1;local rowsPerFrame=floor(K.Tier(3).Bind/22)
 check(settled and settled<=holdFrames+math.ceil(K.Tier(3).Ahead/rowsPerFrame)+2,('...the long side is rebuilt within the 0.2 s hold + %d rows a frame (%s frames)'):format(rowsPerFrame,tostring(settled)))
 check(over==0,'...never more than the normal per-frame budget of keys dressed (no turn burst)')
 local a,b=K.KeyWindow(g,3,g.RowOfZ(2400),-1);coverage(a,b,'facing -Z')
 local stripsZ={};for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 then stripsZ[#stripsZ+1]=st.CFrame.Position.Z end end
 local lo,hi=1e9,-1e9;for _,z in ipairs(stripsZ)do lo=min(lo,z);hi=max(hi,z)end
 check(2400-lo>=140 and hi-2400<=3*P+P,('letters follow the facing too: %.0f studs toward -Z, %.0f toward +Z'):format(2400-lo,hi-2400))
 do -- R152: the far letters follow the facing too: strips toward -Z (long side) and a short side toward +Z
  local flo,fhi=1e9,-1e9;for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendFar'and st.CFrame.Position.Y>0 then local z=st.CFrame.Position.Z;flo=min(flo,z);fhi=max(fhi,z)end end
  check(2400-flo>=480 and fhi-2400>=200 and fhi-2400<=31*P,('R152 far letters facing -Z: letters reach %.0f studs toward -Z (tier 3: 64 rows) and %.0f toward +Z (28 rows)'):format(2400-flo,fhi-2400))
 end
 look(100);frames(40)
 local _,aBack=reach();check(aBack>=990,'turning back to +Z restores the long side ahead')
end
-- 5c. R149 review part 1 (finding 2): the camera swings round on a PHONE (tier 2: the Follow camera turns on every pack carry). The window of
-- ~68 rows swaps its long side; this used to be 4x the budget in two frames (the review measured 4,802 property writes + 792 BulkMoveTo parts in
-- the first frame, then 2,340 + 704) and released every row at 16x. Now no burst: nearest rows first at the normal rate (9 rows a frame on tier 2),
-- rows released at the same rate, letters 4 rows a frame - a few cheap frames instead of two heavy ones.
do
 hum.FloorMaterial=AIR;fxTier=2;put(cx(11),F+9,2400);look(100);frames(60*5)
 local t2=K.Tier(2)
 look(-100)
 measure=true;visRoot=workspace.KeyboardTrackVisuals;resetAll()
 local worstW,worstM,worstKeys,worstStrips,worstTp,firstF,lastF,sumW,sumM=0,0,0,0,0,nil,nil,0,0
 local perFrame={}
 for f=1,120 do
  resetAll();frames(1)
  worstW=max(worstW,writes.all);worstM=max(worstM,bulkParts);worstKeys=max(worstKeys,writes.key);worstStrips=max(worstStrips,writes.strip);worstTp=max(worstTp,writes.tp)
  sumW+=writes.all;sumM+=bulkParts
  if writes.all>0 or bulkParts>0 then firstF=firstF or f;lastF=f;perFrame[#perFrame+1]=writes.all end
 end
 measure=false
 local settle=lastF and lastF-firstF+1 or 0
 print(('turn (tier 2, camera swings from +Z to -Z): worst frame %d property writes + %d BulkMoveTo parts (%d keys dressed, %d letter strips bound, %d key Transparency writes); %d frames to settle, %d writes + %d parts in all; first frames: %s'):format(
  worstW,worstM,worstKeys,worstStrips,worstTp,settle,sumW,sumM,table.concat(perFrame,' ',1,min(#perFrame,10))))
 check(worstM<=t2.Bind,('no burst on a turn: at most %d keys moved in a frame (%d) - the review measured 792 then 704'):format(t2.Bind,worstM))
 check(worstKeys<=t2.Bind,('...and at most %d keys dressed in a frame (%d)'):format(t2.Bind,worstKeys))
 check(worstW<=2000,('...worst frame %d property writes (the review measured 4,802 then 2,340, 1,722 with its proposed fix)'):format(worstW))
 check(worstStrips<=2*C.Legend.RowsPerFrame and C.Legend.RowsPerFrame==4,('...letters %d rows a frame at most (RowsPerFrame 4: %d strips in a frame)'):format(C.Legend.RowsPerFrame,worstStrips))
 check(settle>=3 and settle<=16,('...the window is rebuilt within %d frames (a handful of cheap frames, not two heavy ones)'):format(settle))
 local a,b=K.KeyWindow(g,2,g.RowOfZ(2400),-1);coverage(a,b,'tier 2, facing -Z after the turn')
 look(100);frames(60*2);local a2,b2=K.KeyWindow(g,2,g.RowOfZ(2400),1);coverage(a2,b2,'tier 2, turned back')
 fxTier=3;frames(60*5)
end

-- 5d. R151 (owner: "keys present on the right of the track but a large area on the left near the player shows flat floor with no keys"; on a phone
-- "almost no keys around the player"). The keys of the NEAR zone (K.Near rows each side of the runner, every column) must be there EVERY frame:
-- sprints up to 2,000 studs/s, teleports into every biome, phones (tier 2) and FastMode (tier 1) at 30 fps, the camera looking along, across or
-- straight down; and every other row of the wanted window holds its keys or the flat stand-in (KeyFiller), never bare bed.
do
 local function nearMissing(fr,tierN)
  local idx=keyIndex();local n=0;local nz=K.Near(tierN)
  for r=max(1,fr-nz),min(g.Rows,fr+nz)do if not g.BarOfRow[r]then for c=1,22 do local e=idx[r*64+c];if not e or e[1]~=1 then n+=1 end end end end
  return n
 end
 local function fillers()
  local t={};for _,p in ipairs(keysF:GetChildren())do if p.Name=='KeyFiller'and p.Transparency==0 then local z,h=p.CFrame.Position.Z,p.Size.Z/2;t[#t+1]={z-h,z+h,p}end end;return t
 end
 -- rows of a..b with neither keys (all 22) nor a stand-in over them
 local function bare(a,b)
  local idx=keyIndex();local f=fillers();local n=0
  for r=max(1,a),min(g.Rows,b)do if not g.BarOfRow[r]then
   local keys=0;for c=1,22,7 do local e=idx[r*64+c];if e and e[1]==1 then keys+=1 end end
   if keys<4 then
    local za,zb=g.RowZ(r);local covered=false
    for _,s in ipairs(f)do if s[1]<=za+1e-6 and s[2]>=zb-1e-6 then covered=true end end
    if not covered then n+=1 end
   end
  end end
  return n
 end
 local heads={{'+Z',function(z)look(100)end},{'-Z',function(z)look(-100)end},{'across +X',function(z)look(0,100)end},{'across -X',function(z)look(0,-100)end},
  {'down',function(z)camera.CFrame=R.CFrame.lookAt(V3(0,60,z),V3(0,0,z+.01))end},{'shallow +Z after a run back',function(z)look(-100);frames(20);camera.CFrame=R.CFrame.lookAt(V3(-40,20,z),V3(60,14,z+30))end}}
 local worstNear,worstBare,cases,frameAudits=0,0,0,0
 local lines={}
 for _,tierN in ipairs({3,2,1})do
  fxTier=tierN;hum.FloorMaterial=AIR;put(cx(11),F+9,2400);look(100);frames(60*4) -- (the tier change holds 3 s)
  for _,fps in ipairs({60,30})do
   local dt=1/fps
   for _,h in ipairs(heads)do
    -- teleport into the middle of every biome: the near zone is complete on the very first frame
    for _,seg in ipairs(g.Segs)do
     local z=(seg.StartZ+seg.EndZ)/2;put(cx(11),F+9,z);h[2](z);frames(1,dt)
     local m=nearMissing(g.RowOfZ(z),tierN);worstNear=max(worstNear,m);cases+=1
     if m>0 then lines[#lines+1]=('tier %d %d fps %s teleport to %s: %d near keys missing'):format(tierN,fps,h[1],seg.Name,m)end
    end
    -- sprint: 141 (Lava speeds), 500, 1,000 and 2,000 studs/s for a second each, auditing every frame; after the hold, every wanted row
    -- carries keys or a stand-in
    local z=1300
    for _,speed in ipairs({141,500,1000,2000})do
     for f=1,fps do
      z+=speed*dt;if z>5600 then z=-60 end
      put(cx(11),F+9,z);if h[1]=='down'then h[2](z)end;frames(1,dt)
      local fr=g.RowOfZ(z);local m=nearMissing(fr,tierN);worstNear=max(worstNear,m);frameAudits+=1
      if m>0 and #lines<12 then lines[#lines+1]=('tier %d %d fps %s %d studs/s: %d near keys missing'):format(tierN,fps,h[1],speed,m)end
     end
    end
    frames(math.ceil(fps*.5),dt)
    local fr=g.RowOfZ(z)
    local wa,wb=K.KeyWindow(g,tierN,fr,h[1]=='+Z'and 1 or h[1]=='-Z'and-1 or(h[1]:find('shallow')and 0)or 0)
    local nb=bare(wa,wb);worstBare=max(worstBare,nb)
    if nb>0 and #lines<12 then lines[#lines+1]=('tier %d %d fps %s: %d rows of the window bare'):format(tierN,fps,h[1],nb)end
   end
  end
 end
 for _,l in ipairs(lines)do print('  '..l)end
 check(worstNear==0,('R151: the near zone is never missing a key: %d teleports into every biome and %d sprint frames (141 .. 2,000 studs/s), tiers 3 / 2 / 1, 60 and 30 fps, camera along / across / down (worst %d)'):format(cases,frameAudits,worstNear))
 check(worstBare==0,('R151: half a second later every row of the wanted window holds keys or the stand-in, for every camera way (worst %d bare rows)'):format(worstBare))
 -- the owner's case: back from a run to base (facing -Z), the camera then looks across the track a little toward +Z: the long side used to stay
 -- behind (only Back rows where he looked); now the window is symmetric and the far side fills nearest first under stand-ins
 fxTier=2;put(cx(11),F+9,2400);look(-100);frames(60*4)
 camera.CFrame=R.CFrame.lookAt(V3(-40,20,2400),V3(60,14,2430)) -- heading ~0.29 toward +Z: across
 local fr=g.RowOfZ(2400);local S2=K.Side(2);local seenBare=0;local maxFill=0
 for f=1,40 do
  frames(1,1/30)
  if f>math.ceil(C.FacingHoldSeconds*30)+1 then seenBare=max(seenBare,bare(fr-S2,fr+S2))end
  maxFill=max(maxFill,#fillers())
 end
 local lo,hi=1e9,-1e9;for _,p in ipairs(keyParts())do local z=p.CFrame.Position.Z;lo=min(lo,z);hi=max(hi,z)end
 check(hi-2400>=(S2-1)*P and 2400-lo>=(S2-1)*P,('R151 (the owner\'s screenshot): looking across after a run back, keys reach %.0f studs toward +Z and %.0f toward -Z (Side %d rows); before R151 only %d rows toward +Z'):format(hi-2400,2400-lo,S2,8))
 check(seenBare==0,'...and while the far side fills no row of the window is bare (stand-ins cover what waits): '..seenBare)
 check(maxFill>0 and maxFill<=C.FillerSlabs,('...stand-ins were used (%d slabs at most, budget %d)'):format(maxFill,C.FillerSlabs))
 frames(60)
 check(#fillers()==0,'...and parked once every row has its keys')
 -- a stand-in never shares a plane with a key top and sits under the resting tops
 local fl=nil;for _,p in ipairs(keysF:GetChildren())do if p.Name=='KeyFiller'then fl=p end end
 check(fl~=nil and near(fl.Size.Y,K.KeyTop(0)-C.FillerDrop-(K.BedTop()+.02),1e-6)and C.FillerDrop>=.04 and C.FillerDrop<=.2,
  ('a stand-in reaches from the bed to %.2f under the resting key tops (.04 .. .2: never coplanar with a key top, never above one)'):format(C.FillerDrop))
 fxTier=3;look(100);put(cx(11),F+9,2400);frames(60*4)
end
-- 5e. R152 (owner: "keys behind also not rendering and its not loud enough"; his screenshot looked down the track and the far keys were bare caps).
-- From anywhere on the track and looking any way, every key that can reasonably be seen has its keycap AND its letter: along the camera's way out to the view distance
-- (~1000 / 600 / 365 studs of keys, letters 500 / 340 / 230), behind it (keys 327 / 229 / 180 studs, letters 229 / 180 / 147: a camera zoomed out to 128 studs sees its own
-- surroundings), and each way when it looks across the track. The numbers below are written out here, not read from the module. Then the budget per tier: parts, SurfaceGuis,
-- TextLabels (the far rows carry one cheap strip each: a single SurfaceGui at 4 px / stud, not two 16 px ones).
local H={} -- helpers shared by 5e and 5g (one local: the main chunk is near Luau's limit of local variables)
 -- every visible label of every bound strip (near and far) audited against the keys: exactly over its key's centre, its legend, upright, inside its canvas, above the key top
 function H.letterAudit()
  local keyTop={}
  for _,p in ipairs(keysF:GetChildren())do
   if p.Name=='Key'and p.Transparency==0 then local pos=p.CFrame.Position;keyTop[g.RowOfZ(pos.Z)*64+g.ColOfX(pos.X)]=pos.Y+p.Size.Y/2 end
  end
  local perRow,bad={}, {pos=0,canvas=0,text=0,upright=0,above=0,nokey=0,gui=0,twice=0}
  local nearN,farN,labels=0,0,0
  for _,st in ipairs(legF:GetChildren())do
   local far=st.Name=='LegendFar'
   if(st.Name=='LegendStrip'or far)and st.CFrame.Position.Y>0 then
    local gui=st:FindFirstChildWhichIsA('SurfaceGui');local pps=gui.PixelsPerStud;local cw,ch=canvasOf(st,pps)
    if far then farN+=1 else nearN+=1 end
    -- (R153 perf, lag audit D8: on tier 2 the far letters render to FarMaxDistanceByTier[2] = 500 studs, elsewhere at least 700)
    if gui.Enabled==false or gui.Face~=R.Enum.NormalId.Top or gui.AlwaysOnTop~=false or gui.LightInfluence~=0 or gui.MaxDistance<(far and((LT.FarMaxDistanceByTier or{})[fxTier]or 700)or 400)or pps~=(far and LT.FarPixelsPerStud or LT.PixelsPerStud)then bad.gui+=1 end
    for _,l in ipairs(gui:GetChildren())do
     if l._class=='TextLabel'and l.Visible and l.TextTransparency<1 then
      labels+=1
      local px,py=l.Position.X.Offset,l.Position.Y.Offset;local hw,hh=l.Size.X.Offset/2,l.Size.Y.Offset/2
      local wx,wz=worldOf(st,px,py,pps);local row,col=g.RowOfZ(wz),g.ColOfX(wx);local kx,kz=g.CellCenter(row,col)
      local rr=perRow[row];if not rr then rr={};perRow[row]=rr end
      if rr[col]then bad.twice+=1 end;rr[col]=true
      if px-hw<-1e-6 or px+hw>cw+1e-6 or py-hh<-1e-6 or py+hh>ch+1e-6 then bad.canvas+=1 end
      if not kx or abs(kx-wx)>1e-6 or abs(kz-wz)>1e-6 then bad.pos+=1 end
      if l.Text~=K.Legend(row,col)then bad.text+=1 end
      local rx,rz=readsAlong(l.Rotation);local ux,uz=upOf(l.Rotation)
      if not(near(rx,-1,1e-9)and near(rz,0,1e-9)and near(ux,0,1e-9)and near(uz,1,1e-9))then bad.upright+=1 end
      local kt=keyTop[row*64+col]
      if not kt then bad.nokey+=1 elseif st.CFrame.Position.Y+st.Size.Y/2<kt+LT.Margin-1e-6 then bad.above+=1 end
     end
    end
   end
  end
  return perRow,bad,nearN,farN,labels
 end
 -- rows a..b (bars excepted) that do not carry exactly one label per key
 function H.lettersMissing(perRow,a,b)
  local missing,rows=0,0
  for r=max(1,a),min(g.Rows,b)do if not g.BarOfRow[r]then rows+=1;local rr=perRow[r];for c=1,22 do if not(rr and rr[c])then missing+=1 end end end end
  return missing,rows
 end
 -- how far (studs) from z the keys / letters reach toward +Z and -Z without a gap (bars skipped)
 function H.reach(perRow,z)
  local fr=g.RowOfZ(z);local idx=keyIndex()
  local function run(from,to,step,has)
   local far=0
   for r=from,to,step do
    if not g.BarOfRow[r]then local n=0;for c=1,22 do if has(r,c)then n+=1 end end;if n==22 then local za,zb=g.RowZ(r);far=step>0 and zb-z or z-za else break end end
   end
   return far
  end
  local hasKey=function(r,c)local e=idx[r*64+c];return e and e[1]==1 end
  local hasLetter=function(r,c)return perRow[r]and perRow[r][c]end
  return run(fr,g.Rows,1,hasKey),run(fr,1,-1,hasKey),run(fr,g.Rows,1,hasLetter),run(fr,1,-1,hasLetter)
 end
 function H.budget()
  -- what is in use: visible keys, bound strips, bars, bed, stand-ins, click anchors; guis bound; labels shown (the pools themselves only grow, see the print)
  local parts,pool,bound,shown,labelsAll,inst=0,0,0,0,0,0
  for _,o in ipairs(vis:GetDescendants())do
   inst+=1
   if o:IsA('BasePart')then
    pool+=1
    if o.Name=='Key'or o.Name=='KeyFiller'then if o.Transparency==0 then parts+=1 end
    elseif o.Name=='LegendStrip'or o.Name=='LegendFar'then if o.CFrame.Position.Y>0 then parts+=1 end
    else parts+=1 end
   elseif o._class=='SurfaceGui'then if o.Enabled~=false and o.Parent and o.Parent.CFrame and o.Parent.CFrame.Position.Y>0 then bound+=1 end
   elseif o._class=='TextLabel'then labelsAll+=1;if o.Visible and o.Parent and o.Parent.Parent and o.Parent.Parent.CFrame and o.Parent.Parent.CFrame.Position.Y>0 then shown+=1 end end
  end
  return parts,pool,bound,shown,labelsAll,inst
 end
 do
 local need={ -- keys along the way / behind / each way across; letters along / behind / each way across (studs)
  [3]={ka=990,kb=320,ks=600,la=500,lb=220,ls=360,parts=4000,guis=150,labels=2300},
  [2]={ka=600,kb=225,ks=380,la=340,lb=170,ls=260,parts=2600,guis=110,labels=1700},
  [1]={ka=350,kb=175,ks=250,la=230,lb=140,ls=190,parts=1700,guis=80,labels=1300}}
 local dirs={{'+Z',1,function()look(100)end},{'-Z',-1,function()look(-100)end},{'across',0,function()look(0,100)end}}
 local lines,worst={}, {}
 hum.FloorMaterial=AIR
 for _,tierN in ipairs({3,2,1})do
  fxTier=tierN;put(cx(11),F+9,2400);look(100);frames(60*4)
  local nd=need[tierN];worst[tierN]={parts=0,pool=0,bound=0,labels=0,inst=0,keys=0}
  for _,d in ipairs(dirs)do
   put(cx(11),F+9,2400);d[3]();frames(60*3)
   local fr=g.RowOfZ(2400);local wa,wb=K.KeyWindow(g,tierN,fr,d[2])
   coverage(wa,wb,('tier %d facing %s'):format(tierN,d[1]))
   local perRow,bad,nearN,farN,labels=H.letterAudit()
   local la,lb=K.FarLegendWindow(g,tierN,fr,d[2])
   local missing,rowsN=H.lettersMissing(perRow,la,lb)
   local flaws=0;for _,v in pairs(bad)do flaws+=v end
   check(missing==0 and flaws==0 and rowsN>=40,('tier %d facing %s: every key of the %d letter rows %d .. %d has its letter (%d near + %d far strips, %d labels; %d missing; wrong place / text / turn / height / canvas / gui: %d %d %d %d %d %d %d %d)'):format(
    tierN,d[1],rowsN,la,lb,nearN,farN,labels,missing,bad.pos,bad.text,bad.upright,bad.above,bad.canvas,bad.nokey,bad.gui,bad.twice))
   local kPlus,kMinus,lPlus,lMinus=H.reach(perRow,2400)
   local along,behind,lAlong,lBehind
   if d[2]==1 then along,behind,lAlong,lBehind=kPlus,kMinus,lPlus,lMinus elseif d[2]==-1 then along,behind,lAlong,lBehind=kMinus,kPlus,lMinus,lPlus end
   if d[2]~=0 then
    check(along>=nd.ka and behind>=nd.kb,('tier %d facing %s: keys %.0f studs along the camera\'s way (need %d), %.0f behind it (need %d)'):format(tierN,d[1],along,nd.ka,behind,nd.kb))
    check(lAlong>=nd.la and lBehind>=nd.lb,('tier %d facing %s: letters %.0f studs along the camera\'s way (need %d), %.0f behind it (need %d)'):format(tierN,d[1],lAlong,nd.la,lBehind,nd.lb))
    lines[#lines+1]=('tier %d %s: keys %.0f ahead / %.0f behind, letters %.0f / %.0f'):format(tierN,d[1],along,behind,lAlong,lBehind)
   else
    check(kPlus>=nd.ks and kMinus>=nd.ks and lPlus>=nd.ls and lMinus>=nd.ls,('tier %d looking across: keys %.0f / %.0f studs each way (need %d), letters %.0f / %.0f (need %d)'):format(tierN,kPlus,kMinus,nd.ks,lPlus,lMinus,nd.ls))
    lines[#lines+1]=('tier %d across: keys %.0f / %.0f each way, letters %.0f / %.0f'):format(tierN,kPlus,kMinus,lPlus,lMinus)
   end
   local parts,pool,bound,shown,labelsAll,inst=H.budget()
   local w=worst[tierN];w.parts=max(w.parts,parts);w.pool=max(w.pool,pool);w.bound=max(w.bound,bound);w.labels=max(w.labels,shown);w.inst=max(w.inst,inst);w.keys=max(w.keys,#keyParts())
  end
  local w=worst[tierN]
  check(w.parts<=nd.parts and w.bound<=nd.guis and w.labels<=nd.labels,('tier %d budget in use: %d parts (%d of them keys), %d SurfaceGuis, %d letters shown; caps %d / %d / %d'):format(tierN,w.parts,w.keys,w.bound,w.labels,nd.parts,nd.guis,nd.labels))
  print(('budget tier %d: %d parts in use (%d keys), %d SurfaceGuis, %d letters shown (pools made so far: %d parts, %d instances under the keyboard folder)'):format(tierN,w.parts,w.keys,w.bound,w.labels,w.pool,w.inst))
 end
 print('reach: '..table.concat(lines,' | '))
 -- the ends of the track: no row behind the first / past the last, a window that is clamped still has its keys and its letters
 for _,e in ipairs({{-40,-1,'the start, looking back toward base'},{-40,1,'the start, looking along'},{5850,1,'the end, looking along'},{5850,-1,'the end, looking back'}})do
  fxTier=2;put(cx(11),F+9,e[1]);look(e[2]*100);frames(60*5)
  local fr=g.RowOfZ(e[1]);local wa,wb=K.KeyWindow(g,2,fr,e[2])
  coverage(wa,wb,'tier 2, '..e[3])
  local perRow,bad=H.letterAudit();local la,lb=K.FarLegendWindow(g,2,fr,e[2]);local missing=H.lettersMissing(perRow,la,lb)
  local flaws=0;for _,v in pairs(bad)do flaws+=v end
  check(missing==0 and flaws==0,('tier 2, %s: every letter row %d .. %d is complete (%d missing, %d flaws)'):format(e[3],la,lb,missing,flaws))
 end
 -- the near zone (R151) is unchanged by all this: still dressed in the frame it is wanted (a teleport: the very first frame)
 fxTier=3;frames(60*4);put(cx(11),F+9,2400);look(100);frames(60)
 put(cx(11),F+9,4000);frames(1);local idx=keyIndex();local f4=g.RowOfZ(4000);local nm=0
 for r=f4-K.Near(3),f4+K.Near(3)do if not g.BarOfRow[r]then for c=1,22 do local e=idx[r*64+c];if not e or e[1]~=1 then nm+=1 end end end end
 check(nm==0 and K.Near(3)==14,'the R151 near zone (14 rows each side on tier 3) is complete on the very first frame after a teleport (R152 left it as it was): '..nm..' missing')
 put(cx(11),F+9,cz(BR));frames(60*3)
end

-- 5f. R152 (owner: "this audio [73942179280083] is played for all keys which are as wide and big as the forest jungle keys so it goes for snow and lava and crystal and so on too";
-- "its not loud enough"): every normal key of EVERY biome plays the key sound, the spacebars (a different size) keep the click; the same voice pool cap, roll-off, range, cadence
-- and gain cycle; the click is louder.
do
 hum.FloorMaterial=PLASTIC;fxTier=3;frames(60*4)
 local KEYSND,CLICK='rbxassetid://73942179280083','rbxassetid://113108830240353'
 local function pressAt(row,col,z)
  put(cx(col)+25,nil,z or cz(row));frames(14) -- everything up first
  plays={};put(cx(col),nil,z or cz(row));frames(12);local list=table.clone(plays)
  put(cx(col)+25,nil,z or cz(row));frames(14)
  return list
 end
 local summary={}
 for _,seg in ipairs(g.Segs)do
  -- a normal key (row 10 into the biome, column 9) ...
  local row=seg.KeyFirst+min(9,seg.Rows-3);local list=pressAt(row,9)
  local id=list[1]and list[1].Id
  check(#list==1 and id==KEYSND,('a press on a normal key in %s (row %d) plays 73942179280083 (%s)'):format(seg.Name,row,tostring(id)))
  check(list[1]and list[1].Min==C.ClickRollOffMin and list[1].Max==C.ClickRollOffMax and list[1].Mode==R.Enum.RollOffMode.InverseTapered and list[1].Group and list[1].Group.Name=='GardenEffects',
   ('...with the same 3D roll-off (%d .. %d, InverseTapered) and the Effects group as every click'):format(C.ClickRollOffMin,C.ClickRollOffMax))
  -- ... the first row of the biome: its spacebar (the huge full-width key), the original click
  local bar=nil
  for _,b in ipairs(g.Bars)do if b.Name==seg.Name then bar=b end end
  put(cx(8),nil,bar.Z0+70);frames(14);plays={};put(cx(8),nil,bar.Z0+2);frames(12);local lb=table.clone(plays) -- (a whole bar goes down: it is pressed once, from away)
  put(cx(8),nil,bar.Z0+70);frames(14)
  local bid=lb[1]and lb[1].Id
  check(#lb==1 and bid==CLICK and lb[1].Volume<=C.ClickVolume+1e-9,('the %s spacebar plays the original click 113108830240353 at the click volume (%s)'):format(seg.Name,tostring(bid)))
  summary[#summary+1]=seg.Name..' key '..(id==KEYSND and'sound'or'?')..' / bar '..(bid==CLICK and'click'or'?')
 end
 print('press sounds: '..table.concat(summary,', '))
 -- one pool of ClickVoices voices per sound, strict rotation inside it, nothing shared between the two sounds
 do
  plays={};local zJ=cz(g.Segs[3].KeyFirst+4);local voices,ids={},{}
  for i=1,26 do put(cx(11),nil,zJ+i*8.2);frames(6)end
  for _,p in ipairs(plays)do voices[p.Sound]=true;ids[p.Id]=true end
  local nv=0;for _ in pairs(voices)do nv+=1 end
  local n=0;for _ in pairs(ids)do n+=1 end
  check(#plays>=20 and nv==C.ClickVoices and n==1,('running through the Desert: %d key presses use the key sound\'s pool of %d voices (%d distinct), none of the click\'s'):format(#plays,C.ClickVoices,nv))
  local mixed=false;for _,p in ipairs(plays)do if p.Sound.SoundId~=KEYSND then mixed=true end end
  check(not mixed,'every voice of that pool plays the key sound')
 end
 -- loudness (Desert keys): every press at the key sound's volume times a slight gain; the peak is the config volume; pitch as before
 do
  plays={};local zD=cz(g.Segs[3].KeyFirst+10);local lo,hi,sum,n=1e9,0,0,0
  for i=1,40 do put(cx(11),nil,zD+i*8.2);frames(6)end
  for _,p in ipairs(plays)do lo=min(lo,p.Volume);hi=max(hi,p.Volume);sum+=p.Volume;n+=1 end
  local gmin=1;for _,gn in ipairs(C.ClickGains)do gmin=min(gmin,gn)end
  check(n>=30 and near(hi,C.PressSoundVolume,1e-9)and lo>=C.PressSoundVolume*gmin-1e-9 and lo<hi-.05 and sum/n>=C.PressSoundVolume*.9,('Desert key presses: volume %.2f .. %.2f (mean %.2f) over %d presses: the peak is PressSoundVolume %.1f, the gain cycle takes at most %d%% off'):format(lo,hi,sum/max(1,n),n,C.PressSoundVolume,floor((1-gmin)*100+.5)))
  local pitches={};for _,p in ipairs(plays)do pitches[p.Speed]=true end;local np=0;for _ in pairs(pitches)do np+=1 end
  check(np>=3 and np<=#C.ClickPitches,'...and the pitch still varies only within 0.98 .. 1.02 ('..np..' pitches)')
 end
 -- the sound per key KIND (and its volume) is in the config; an optional per-biome override exists (empty)
 do
  local oldK,oldS,oldV=C.PressSound.Key,C.PressSound.Spacebar,C.PressSoundVolume
  C.PressSound.Key=123456;C.PressSoundVolume=3.25
  check(K.PressSoundId('Key',2)=='rbxassetid://123456'and K.PressSoundId('Key',6)=='rbxassetid://123456'and K.PressSoundId('Spacebar',2)==CLICK and K.PressVolume('Key',2)==3.25 and K.PressVolume('Spacebar',2)==C.ClickVolume,
   'Config.PressSound.Key / PressSoundVolume change the sound and volume of every normal key at once (a number is an asset id); the spacebar is untouched')
  C.PressSound.Key=oldK;C.PressSoundVolume=oldV
  C.PressSound.Spacebar='rbxassetid://555';check(K.PressSoundId('Spacebar')=='rbxassetid://555'and K.PressSoundId('Key')==KEYSND,'...and PressSound.Spacebar changes the spacebars\' sound only');C.PressSound.Spacebar=oldS
  C.PressSound.Key=nil;check(K.PressSoundId('Key')==CLICK and K.PressVolume('Key')==C.ClickVolume,'a kind with no entry plays the click at the click volume');C.PressSound.Key=oldK
  C.PressSoundBiome.Desert='rbxassetid://777'
  check(K.PressSoundId('Key',2)=='rbxassetid://777'and K.PressSoundId('Key',6)==KEYSND and K.PressSoundId('Spacebar',2)==CLICK and K.PressVolume('Key',2)==C.PressSoundVolume,'the optional PressSoundBiome (by biome name) overrides the key sound of that biome only')
  C.PressSoundBiome.Desert=nil
  check(K.PressSoundId('Key',2)==KEYSND,'...and removing the entry gives the key sound back')
 end
 hum.FloorMaterial=AIR;put(cx(11),F+9,cz(BR));frames(60)
end

-- 5g. R152 (owner: "for some areas on the track like this make sure that there is no keyboard tiles there": a Desert oasis with keys inside and under its water and a palm
-- tree at its edge; rocks, logs and palm bases clip into keys too). The cells to leave out are data (map attribute KeyboardSkip, written by KeyboardSkip152 on the server);
-- every key, letter and press agrees. 5g.1 the shared encoding and geometry, 5g.2 the scan on a synthetic map, 5g.3 the client with cells left out (live: the attribute changes).
do
 local X={} -- state shared by the blocks below (the main chunk is near Luau's limit of 200 local variables)
 do -- 5g.1 --------------------------------------------------------------------------------------------------------------------
 local set={}
 for _,k in ipairs({{5,3},{5,4},{5,5},{6,4},{7,1},{7,22},{9,22},{9,21},{300,10},{728,22},{728,1}})do set[k[1]*64+k[2]]=true end
 local enc=K.EncodeSkip(set,22,728,0)
 check(enc=='1|22|728|0.000|5:3-5;6:4;7:1,22;9:21-22;300:10;728:1,22','K.EncodeSkip: column runs per row, in row order ('..enc..')')
 local dset,drow,dn=K.DecodeSkip(enc,22,728,0)
 local same=dn==11;for key in pairs(set)do if not dset[key]then same=false end end;for key in pairs(dset)do if not set[key]then same=false end end
 check(same and drow[5]==3 and drow[7]==2 and drow[728]==2 and drow[8]==nil,'K.DecodeSkip gives the same cells back, and how many each row has')
 local e1,e2,e3=K.DecodeSkip(enc,22,729,0);local f1,f2,f3=K.DecodeSkip(enc,26,728,0);local h1,h2,h3=K.DecodeSkip(enc,22,728,12)
 check(e3==0 and f3==0 and h3==0,'a string written for another grid (other row count / columns / centre) is ignored: keys everywhere, as before R152')
 local junk={'',nil,42,'1|22|728|0.000|','1|22|728|0.000|x:y;5:;:3;999999:1-2;3:0-99','2|22|728|0.000|5:3','1|22|728','garbage'}
 local junkOk=true;for i=1,8 do local ok,_,_,n=pcall(K.DecodeSkip,junk[i],22,728,0);if not ok or(n or 0)>22 then junkOk=false end end
 check(junkOk,'K.DecodeSkip never errors on junk (empty, nil, a number, a wrong version, half a header, bad runs) and never invents more than the grid')
 local a2=table.clone(ATTR);a2.KeyboardSkip=enc
 local gs=K.Geometry(a2,0)
 check(gs.SkipCount==11 and gs.Skipped(5,4)and not gs.Skipped(5,6)and gs.RowSkip[5]==3 and K.Geometry(ATTR,0).SkipCount==0 and not K.Geometry(ATTR,0).Skipped(5,4),'K.Geometry carries the skipped cells (Skip, RowSkip, SkipCount, Skipped(row, col)); a map with no attribute has none')
 end
 do -- 5g.2 --------------------------------------------------------------------------------------------------------------------
 local S=W.module('KeyboardSkip152');local SC=S.Config
 check(SC.Flat==.10 and SC.Prop==.60 and SC.Grid==8,'scan thresholds: a flat feature (water / lava / ...) leaves a key out from 10% of its footprint, a prop only when it is mostly buried: from 60% (a key partly covered by a wall bank stays, as in R151)')
 local synth=R.new('Model');synth.Name='SynthMap';for k,v in pairs(ATTR)do synth:SetAttribute(k,v)end;synth.Parent=workspace
 local function folder(parent,name)local f=R.new('Folder');f.Name=name;f.Parent=parent;return f end
 local obbyS=folder(synth,'Obby');local biomesS=folder(obbyS,'Biomes');local desert=folder(biomesS,'Biome_2_GOLDEN_DESERT');local scen=folder(desert,'GeneratedScenery')
 local polish=folder(synth,'EnvironmentPolishV127');local lobbyS=folder(synth,'Lobby');local basesS=folder(synth,'Bases')
 local DR=100 -- a Desert row (stage 2)
 local KW=K.KeySize(g.Pitch)
 local function mk(parent,name,x,y,z,sx,sy,sz,t,rot)
  local pt=R.new('Part');pt.Name=name;pt.Size=V3(sx,sy,sz);pt.Transparency=t or 0
  if rot then pt.CFrame=R.CFrame.new(x,y,z,rot[1],rot[2],rot[3],rot[4],rot[5],rot[6],rot[7],rot[8],rot[9])else pt.CFrame=CF(x,y,z)end
  pt.Parent=parent;return pt
 end
 -- a feature covering the left (+X) frac of cell (row, col)'s key footprint over its full depth: x from the key edge - .2 (inside the .5 grout) to edge - frac * KW
 local function coverLeft(parent,name,row,col,frac,height,y0)
  local xc=g.ColCenter(col);local zc=cz(row);local xe=xc+KW/2
  local x1=xe+.2;local x0=xe-frac*KW
  return mk(parent,name,(x0+x1)/2,(y0 or F)+height/2,zc,x1-x0,height,KW+.4)
 end
 local function pool(parent,name,height)local m=folder(parent,name);return m end
 -- cells: (DR, 3) pool half: 50% -> out; (DR, 5) pool sliver ~4% -> in; (DR, 7) pool 15% (2 of 5 sample columns hit one -> 20%) -> out
 local oasis=folder(scen,'Small oasis')
 coverLeft(oasis,'Oasis water',DR,3,.5,.3);coverLeft(oasis,'Water edge',DR,5,.05,.3);coverLeft(oasis,'Water corner',DR,7,.15,.3)
 -- props (not flat): 15% -> in, 40% -> out; a flush patch (top .05 over the floor) and a bridge (foot 12 over the floor) never count
 local rocks=folder(scen,'Rock garden')
 coverLeft(rocks,'Boulder',DR,9,.15,3);coverLeft(rocks,'Boulder',DR,11,.40,3);coverLeft(rocks,'Boulder',DR+8,11,.75,3);coverLeft(folder(scen,'Right wall bank'),'Wall bank slope',DR+10,1,.42,4.5);coverLeft(rocks,'Dirt patch',DR,13,1,.05);coverLeft(rocks,'Bridge',DR,15,1,3,F+12)
 -- a palm trunk (1.9 square) with its stone base (7.4 x 5.6 = 70% of a key): the base buries its key, the trunk 1.9 x 1.9 does not
 local palm=folder(scen,'Palm corner')
 mk(palm,'Palm trunk',g.ColCenter(17)-2,F+5,cz(DR),1.9,10,1.9);mk(palm,'Stone base',g.ColCenter(19),F+1,cz(DR),7.4,2,5.6)
 -- liquid by an ancestor's name, by Material.Water, by a pit name; lava in another root
 mk(folder(scen,'Frozen pond'),'Ice',g.ColCenter(21),F+.1,cz(DR),KW,.2,KW)
 local wm=mk(scen,'Slab',g.ColCenter(1),F+.1,cz(DR+2),KW,.2,KW);wm.Material=R.Enum.Material.Water
 mk(scen,'Sinkhole',g.ColCenter(2),F+.1,cz(DR+2),KW,.2,KW)
 local lava=folder(folder(polish,'IrregularMagmaPools'),'LavaPool_1');mk(lava,'MagmaSurface',g.ColCenter(10),F+.4,cz(DR+2),KW,.2,KW)
 -- never features: an invisible barrier, a part outside the scenery roots (Lobby, Bases), a spacebar row
 mk(scen,'Oasis water',g.ColCenter(12),F+.4,cz(DR+2),KW,.4,KW,1)
 mk(lobbyS,'Water',g.ColCenter(14),F+.4,cz(DR+2),KW,.4,KW);mk(basesS,'Lava',g.ColCenter(16),F+.4,cz(DR+2),KW,.4,KW)
 local barRow=g.Segs[3].FirstRow
 check(g.BarOfRow[barRow]~=nil,'(row '..barRow..' is the Desert spacebar)')
 mk(scen,'Oasis water',g.ColCenter(10),F+.4,cz(barRow),KW,.4,KW)
 -- a diamond pool (a square turned 45 degrees, half-diagonal 6) on (DR+4, 5): only its own cell; the axis-aligned box of the same part would reach the neighbours
 local c45=math.cos(math.rad(45));local s45=math.sin(math.rad(45));local half=6/math.sqrt(2)*2/ 2
 mk(scen,'Diamond pool',g.ColCenter(5),F+.2,cz(DR+4),12/math.sqrt(2)*1,.3,12/math.sqrt(2)*1,0,{c45,0,s45,0,1,0,-s45,0,c45})
 -- round pools: a ball (radius 5.3: a box of that size would take the neighbours, a circle only 1 sample of one) and a standing disc (radius 5) on (DR+6, 5) and (DR+6, 12)
 local ball=mk(scen,'Round pool',g.ColCenter(5),F+.5,cz(DR+6),10.6,10.6,10.6);ball.Shape=R.Enum.PartType.Ball
 local disc=mk(scen,'Disc pool',g.ColCenter(12),F+.2,cz(DR+6),.4,10,10,0,{0,-1,0,1,0,0,0,0,1});disc.Shape=R.Enum.PartType.Cylinder
 local res=S.Apply(synth,0)
 local cells=res and res.Cells or {}
 local function out(row,col)return cells[row*64+col]==true end
 check(out(DR,3)and not out(DR,5)and out(DR,7),'flat features: a key half covered by water is left out, a 5% sliver stays, one with 15% of its width covered (20% of its footprint: over the 10%) is left out')
 check(not out(DR,9)and not out(DR,11)and out(DR+8,11),'props: a key 20% or 40% covered by a boulder stays (an edge key poking into a bank, as in R151), one 75% buried goes')
 check(not out(DR+10,1)and not out(DR+10,2),'a wall bank 3.2 studs wide on the outer column (42% of its key) leaves the edge key in: no bare gaps along the walls (a coarse sample grid read it as 60%)')
 check(not out(DR,13)and not out(DR,15),'a flush patch (top .05 over the floor: under the key) and a bridge (foot 12 over the floor: above the key) never count')
 check(out(DR,17)==false and out(DR,19),'a palm trunk (1.9 x 1.9 = 5% of a key) leaves it alone; its stone base (70% of a key) does not')
 check(out(DR,21)and out(DR+2,1)and out(DR+2,2)and out(DR+2,10),'liquid by the ancestor\'s name (Frozen pond), by Material.Water, by a pit name (Sinkhole), by a lava pool\'s name in another scenery root')
 check(not out(DR+2,12)and not out(DR+2,14)and not out(DR+2,16)and not out(barRow,10)and not out(barRow,9),'an invisible barrier, a part under Lobby / Bases (not scenery) and a feature on a spacebar row leave the keys alone')
 check(out(DR+4,5)and not out(DR+4,4)and not out(DR+4,6)and not out(DR+3,5)and not out(DR+5,5),'a pool turned 45 degrees uses its real footprint (the hull of the turned box): its own key only; its axis-aligned box would take the neighbours too')
 check(out(DR+6,5)and out(DR+6,12)and not out(DR+6,4)and not out(DR+6,6)and not out(DR+6,11)and not out(DR+6,13),'a ball and a standing disc are round: their own key only')
 local n=0;for _ in pairs(cells)do n+=1 end
 do local l={};for key in pairs(cells)do l[#l+1]=(key//64-DR)..':'..key%64 end;table.sort(l);print('scan cells (row - '..DR..': col): '..table.concat(l,' '))end
 check(res and res.Count==n and n==11,'the scan counts what it leaves out ('..tostring(n)..' cells)')
 local rep=res and res.Report[2]or{};local names={};for _,e in ipairs(rep)do names[e.Name]=e end
 check(names['Small oasis']and names['Small oasis'].Class=='flat'and names['Small oasis'].Cells==2 and names['Rock garden']and names['Rock garden'].Class=='prop'and names['Rock garden'].Cells==1 and names['Palm corner']and names['Palm corner'].Cells==1,
  'the report lists the areas per biome (stage 2): Small oasis (flat, 2 cells), Rock garden (prop, 1), Palm corner (prop, 1) ...')
 local attrStr=synth:GetAttribute('KeyboardSkip');local back,_,backN=K.DecodeSkip(attrStr,22,728,0)
 local sameCells=backN==n;for key in pairs(cells)do if not back[key]then sameCells=false end end
 check(type(attrStr)=='string'and sameCells,'Apply publishes the cells as the map attribute KeyboardSkip (and it decodes to the same cells)')
 S.Apply(synth,0)
 check(synth:GetAttribute('KeyboardSkip')==attrStr,'scanning again gives the same string (the previous attribute is not read as a feature)')
 do
  local a3=synth:GetAttributes();a3.KeyboardSkip=nil
  S.Config.Ignore={'rock garden'};local r2=S.Scan(synth,K.Geometry(a3,0));S.Config.Ignore={}
  check(#SC.Ignore==0 and r2.Cells[(DR+8)*64+11]==nil and r2.Cells[DR*64+3]==true and r2.Count==n-1,'Config.Ignore: a model whose name has one of the words is never a feature (here Rock garden: one key back, the others stay); empty by default')
 end
 synth:Destroy()
 end
 do -- 5g.3 --------------------------------------------------------------------------------------------------------------------
 hum.FloorMaterial=AIR;fxTier=3;frames(60*4);look(100)
 local R0=BR -- Jungle row 60: the runner stands on (60, 11); every skipped cell lies within the near / far letter zone around him
 local skip={}
 local function add(r,a,b)for c=a,b do skip[r*64+c]=true end end
 add(55,3,8);add(56,3,8);add(57,3,8);add(58,3,8)     -- a pool: 4 rows x 6 columns
 add(60,15,15)                                        -- one cell
 add(62,1,4);add(62,20,22)                            -- both ends of a row: strips trimmed
 add(64,1,11)                                         -- the whole first half row: its strip is empty
 add(66,1,22)                                         -- a whole row: no keys, no strips
 add(68,5,7)                                          -- a gap in the middle of a half row: its letters are hidden
 add(R0+50,10,13);add(R0+54,1,6)                      -- far rows (far letters: trimmed / gap); the stand-ins of a teleport reach them (they wait for their keys)
 local skipStr=K.EncodeSkip(skip,22,g.Rows,0)
 put(cx(11),F+9,cz(R0));frames(60)
 local keysBefore=#keyParts()
 map:SetAttribute('KeyboardSkip',skipStr);frames(60*3)  -- the attribute arrives after the keys were dressed: every bound row is dressed again
 local nSkip=0;for _ in pairs(skip)do nSkip+=1 end
 local idx=keyIndex();local wa,wb=K.KeyWindow(g,3,g.RowOfZ(cz(R0)),1)
 local leaked,bare,total=0,0,0
 for r=wa,wb do if not g.BarOfRow[r]then for c=1,22 do
  local e=idx[r*64+c];total+=1
  if skip[r*64+c]then if e then leaked+=1 end else if not e or e[1]~=1 then bare+=1 end end
 end end end
 check(leaked==0 and bare==0,('%d cells left out (a pool, a single cell, row ends, half and whole rows, gaps, far rows): none of them has a key, every other cell of the window rows %d .. %d does (%d keys in a window, %d leaked, %d bare)'):format(nSkip,wa,wb,total,leaked,bare))
 check(#keyParts()<=total-nSkip+22*K.Tier(3).Hyst*2,('the keys bound: %d for %d keyed cells of the window rows (+ the rows kept by the hysteresis)'):format(#keyParts(),total-nSkip))
 -- pressing: a runner on a left-out cell presses nothing and nothing clicks; next to it a key goes down
 hum.FloorMaterial=PLASTIC;plays={}
 put(cx(5),nil,cz(56));frames(20)
 local downNear=0;for _,p in ipairs(keyParts())do if near(top(p),K.KeyTop(1),1e-6)then downNear+=1 end end
 check(downNear==0 and #plays==0,'a runner standing in the pool (left-out cells) presses nothing and nothing clicks ('..downNear..' keys down, '..#plays..' plays)')
 put(cx(11),nil,cz(R0));frames(20)
 check(near(topOf(R0,11),K.KeyTop(1),1e-6)and #plays==1,'...a key next to the pool still goes down with its sound ('..#plays..')')
 hum.FloorMaterial=AIR;put(cx(11),F+9,cz(R0));frames(30)
 X.skip,X.nSkip,X.wa,X.wb,X.R0,X.skipStr=skip,nSkip,wa,wb,R0,skipStr
 end
 do
 local skip,nSkip,wa,wb,R0=X.skip,X.nSkip,X.wa,X.wb,X.R0
 -- letters: none over a left-out cell, exactly one over every other key of the letter rows; strips trimmed to their keys; empty strips are off
 local perRow,bad,nearN,farN,labels=H.letterAudit()
 local la,lb=K.FarLegendWindow(g,3,g.RowOfZ(cz(R0)),1)
 local missing,over=0,0
 for r=la,lb do if not g.BarOfRow[r]then for c=1,22 do
  local has=perRow[r]and perRow[r][c]
  if skip[r*64+c]then if has then over+=1 end else if not has then missing+=1 end end
 end end end
 local flaws=0;for _,v in pairs(bad)do flaws+=v end
 check(missing==0 and over==0 and flaws==0,('letters: none over the %d left-out cells (%d floating), one over every other key of rows %d .. %d (%d missing), no flaws (%d); %d near + %d far strips'):format(nSkip,over,la,lb,missing,flaws,nearN,farN))
 local trimBad,spanN,emptyOn,stripOverGap=0,0,0,0
 for _,st in ipairs(legF:GetChildren())do
  if(st.Name=='LegendStrip'or st.Name=='LegendFar')then
   local gui=st:FindFirstChildWhichIsA('SurfaceGui');local pos=st.CFrame.Position
   if pos.Y>0 and gui.Enabled~=false then
    spanN+=1
    local row=g.RowOfZ(pos.Z);local c1=g.ColOfX(pos.X+st.Size.X/2-.01);local c2=g.ColOfX(pos.X-st.Size.X/2+.01)
    if skip[row*64+c1]or skip[row*64+c2]or c1<1 or c2>22 then trimBad+=1 end -- an end of the strip over a left-out cell = a strip floating over a gap
    local shown=0;for _,l in ipairs(gui:GetChildren())do if l._class=='TextLabel'and l.Visible then shown+=1 end end
    if shown==0 then emptyOn+=1 end
    if row==66 then stripOverGap+=1 end
   end
  end
 end
 check(trimBad==0 and spanN>=40,('no letter strip floats over a gap: all %d bound strips start and end on a key (trimmed at row ends); none lies over the whole-row gap (%d), none is bound with no letter (%d)'):format(spanN,stripOverGap,emptyOn))
 check(stripOverGap==0 and emptyOn==0,'a half row with no key has no strip; a strip with no visible letter is parked and its SurfaceGui is off')
 local r62=0;for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 and g.RowOfZ(st.CFrame.Position.Z)==62 then r62+=1;check(st.Size.X<11*g.Pitch-1,'row 62: a near strip is shorter than a whole half row ('..string.format('%.1f',st.Size.X)..' of '..string.format('%.1f',11*g.Pitch)..')')end end
 check(r62==2,'row 62 still has its two trimmed strips ('..r62..')')
 end
 do
 local skip,nSkip,wa,wb,R0=X.skip,X.nSkip,X.wa,X.wb,X.R0
 -- the real floor stays under the left-out cells: local copies at the floor's height and colour; none under a key
 local patches=0;local covered=0;local keyedCovered=0
 for _,pt in ipairs(groundF:GetChildren())do
  if pt.Name=='GroundPatch'and pt.CFrame.Position.Z<5000 then
   patches+=1
   local fl=floors[g.RowStage[g.RowOfZ(pt.CFrame.Position.Z)]]
   check(fl and near(pt.CFrame.Position.Y+pt.Size.Y/2,F,1e-6)and near(pt.Color.R,fl.Color.R,1e-6)and pt.CanCollide==false and pt.Anchored==true,'a floor copy lies at the floor top ('..F..') in its biome\'s floor colour, anchored, not solid')
  end
 end
 for key in pairs(skip)do
  local r,c=key//64,key%64;local x,z=g.CellCenter(r,c);local found=false
  for _,pt in ipairs(groundF:GetChildren())do if pt.Name=='GroundPatch'and pt.CFrame.Position.Z<5000 then
   local p=pt.CFrame.Position;if abs(x-p.X)<=pt.Size.X/2+1e-6 and abs(z-p.Z)<=pt.Size.Z/2+1e-6 then found=true end end end
  if found then covered+=1 end
 end
 for r=wa,wb do for c=1,22 do if not skip[r*64+c]and not g.BarOfRow[r]then
  local x,z=g.CellCenter(r,c)
  for _,pt in ipairs(groundF:GetChildren())do if pt.Name=='GroundPatch'and pt.CFrame.Position.Z<5000 then
   local p=pt.CFrame.Position;if abs(x-p.X)<=pt.Size.X/2 and abs(z-p.Z)<=pt.Size.Z/2 then keyedCovered+=1 end end end
 end end end
 check(covered==nSkip and keyedCovered==0,('every left-out cell has the real floor under it (%d of %d), no key stands on a floor copy (%d)'):format(covered,nSkip,keyedCovered))
 check(patches>=7 and patches<=14,('...in %d merged patches (a block of cells is one part: the pool is one, not 24)'):format(patches))
 -- effects authored at floor level stay at the floor over a left-out cell, and lift onto the keys elsewhere
 local KS=W.module('KeyboardSurface149')
 local px,pz=g.CellCenter(56,4);local kx,kz=g.CellCenter(R0,11)
 check(KS.TopY(px,pz)==nil and KS.Lift(px,pz,F)==0 and near(KS.TopY(kx,kz),K.KeyTop(0)),'KeyboardSurface149: no lift over a left-out cell (the effect stays on the floor), the usual lift over a key')
 end
 do
 local skip,nSkip,wa,wb,R0,skipStr=X.skip,X.nSkip,X.wa,X.wb,X.R0,X.skipStr
 -- stand-ins never cover a row with left-out cells: teleport far away and back (the far rows wait under stand-ins): none lies over a row of the pool / gaps
 local skipRows={};for key in pairs(skip)do skipRows[key//64]=true end
 local slabOver,slabSeen=0,0
 for _,jump in ipairs({1500,-1500,900})do
  put(cx(11),F+9,cz(R0)+jump);frames(3);put(cx(11),F+9,cz(R0))
  for f=1,8 do frames(1)
   for _,p in ipairs(keysF:GetChildren())do if p.Name=='KeyFiller'and p.Transparency==0 then
    slabSeen+=1
    local z0,z1=p.CFrame.Position.Z-p.Size.Z/2,p.CFrame.Position.Z+p.Size.Z/2
    for r in pairs(skipRows)do local a,b=g.RowZ(r);if a<z1-1e-6 and b>z0+1e-6 then slabOver+=1 end end
   end end
  end
 end
 check(slabOver==0 and slabSeen>0,('a stand-in never covers a row that has a left-out cell (%d overlaps in %d slab sightings)'):format(slabOver,slabSeen))
 frames(60)
 -- the attribute changes again: back to every key, floor copies gone
 map:SetAttribute('KeyboardSkip',nil);frames(60*3)
 local idx2=keyIndex();local bare2=0
 for r=wa,wb do if not g.BarOfRow[r]then for c=1,22 do local e=idx2[r*64+c];if not e or e[1]~=1 then bare2+=1 end end end end
 local left=0;for _,pt in ipairs(groundF:GetChildren())do if pt.Name=='GroundPatch'and pt.CFrame.Position.Z<5000 then left+=1 end end
 check(bare2==0 and left==0,('with the attribute cleared every cell has its key again (%d bare) and no floor copy is left (%d)'):format(bare2,left))
 local pn=0;local _,bad3=H.letterAudit();for _,v in pairs(bad3)do pn+=v end
 check(pn==0,'...letters back on every key, no flaws ('..pn..')')
 -- a string for another grid is ignored
 map:SetAttribute('KeyboardSkip',(skipStr:gsub('^1|22|','1|24|')));frames(60*2)
 local idx3=keyIndex();local bare3=0
 for r=wa,wb do if not g.BarOfRow[r]then for c=1,22 do local e=idx3[r*64+c];if not e or e[1]~=1 then bare3+=1 end end end end
 check(bare3==0,'an attribute written for another grid changes nothing: keys everywhere ('..bare3..' bare)')
 map:SetAttribute('KeyboardSkip',nil);frames(30)
 put(cx(11),F+9,cz(BR));frames(40)
 end
end

-- 6. other players
do
hum.FloorMaterial=AIR
put(cx(11),F+9,cz(BR));frames(40)
local other=R.new('Player');other.Name='Pal';other.UserId=5;other.Parent=Players;others[1]=other
local ochar,oroot=makeCharacter('Pal',cx(8),cz(BR));other.Character=ochar
plays={};frames(8) -- a 30 Hz sample (up to 2 frames) + the .07 s press
check(near(topOf(BR,8),K.KeyTop(1),1e-6),'another player standing on a key presses it')
check(#plays==1 and plays[1].Speed>=.98 and plays[1].Speed<=1.02 and pressVol(plays[1],g.RowStage[BR])and plays[1].Id==K.PressSoundId('Key',g.RowStage[BR]),'...with one sound, the key sound, pitch and volume rule as your own ('..#plays..')')
oroot.CFrame=CF(cx(8),F+9,cz(BR));frames(14)
check(near(topOf(BR,8),K.KeyTop(0),1e-6),'jumping high (feet more than 3 studs up) releases it')
oroot.CFrame=CF(cx(8),F+5.5,cz(BR));frames(10)
check(near(topOf(BR,8),K.KeyTop(1),1e-6),'feet within about 3 studs of the floor still press')
oroot.CFrame=CF(300,F+3,cz(BR));frames(14)
check(near(topOf(BR,8),K.KeyTop(0),1e-6),'walking off the keyboard releases')
-- a crowd of 12 runners sprinting by: every runner keeps his own steady clicks (no shared budget starving some of them)
plays={}
for i=1,12 do local pl=R.new('Player');pl.Name='P'..i;pl.UserId=100+i;pl.Parent=Players;others[#others+1]=pl;local _,r2=makeCharacter('P'..i,cx(i+5),cz(BR));pl.Character=r2.Parent end
frames(4);plays={}
local runnerZ=cz(BR)
for f=1,120 do
 for i=2,13 do others[i].Character.HumanoidRootPart.CFrame=CF(cx(i+4),F+3,runnerZ)end
 put(cx(11),F+9,runnerZ-10)
 runnerZ+=400/60;frames(1)
end
local per={};for _,p in ipairs(plays)do local col=g.ColOfX(p.Pos.X);per[col]=(per[col]or 0)+1 end
local lo,hi,cols=1e9,0,0;for c=6,17 do local n=per[c]or 0;lo=min(lo,n);hi=max(hi,n);if n>0 then cols+=1 end end
check(cols==12 and lo>=18,('12 players running by at 400 studs/s for 2 s: every one of them clicks steadily (%d .. %d clicks each, %d of 12 heard)'):format(lo,hi,cols))
check(hi<=25,'...and none more than his own cadence allows (12 / s each)')
plays={};local farP=others[2].Character.HumanoidRootPart;for i=3,13 do others[i].Character.HumanoidRootPart.CFrame=CF(300,F+3,0)end
put(cx(11),F+9,cz(BR));farP.CFrame=CF(cx(11),F+3,cz(BR)+200);frames(10)
check(#plays==0,'other players more than 90 studs away are silent ('..#plays..')')
for i=#others,1,-1 do others[i]=nil end
put(cx(11),F+9,cz(BR));frames(40)
end
-- 7. keepers
do
local keeper=R.new('Model');keeper.Name='ForestKeeper';keeper:SetAttribute('PersistentBiomeGuardian',true)
local kroot=R.new('Part');kroot.Name='HumanoidRootPart';kroot.Size=V3(6,10,6);kroot.CFrame=CF(cx(14),F+5,cz(BR+4));kroot.Parent=keeper;keeper.PrimaryPart=kroot
keeper.Parent=camps;W.CS:AddTag(keeper,'BiomeKeeper')
plays={};frames(12)
local ek=K.KeeperFootprint(6,6);local kdown=0
for cc=12,16 do for rr=BR+2,BR+6 do if near(topOf(rr,cc)or 99,K.KeyTop(1),1e-6)then kdown+=1 end end end
check(near(ek,1.8)and kdown>=1 and kdown<=4,'a keeper presses the keys under its feet (footprint '..ek..', '..kdown..' keys down)')
check(#plays==0,'keeper: its presses make no sound (R153: only a player who steps on the keys clicks; the keys still go down under it) ('..#plays..')')
kroot.CFrame=CF(300,F+5,cz(BR+4));frames(14)
kdown=0;for cc=12,16 do for rr=BR+2,BR+6 do if near(topOf(rr,cc)or 99,K.KeyTop(1),1e-6)then kdown+=1 end end end
check(kdown==0,'the keys come back up when the keeper walks away')
kroot.CFrame=CF(cx(14),F+40,cz(BR+4));frames(14)
kdown=0;for cc=12,16 do for rr=BR+2,BR+6 do if near(topOf(rr,cc)or 99,K.KeyTop(1),1e-6)then kdown+=1 end end end
check(kdown==0,'a keeper high in the air presses nothing')
kroot.CFrame=CF(300,F+5,cz(BR+4))
keeper:SetAttribute('GuardianBehavior','DASHING');keeper:SetAttribute('GuardianLeaseToken',7);keeper:SetAttribute('KeeperDashToken',7)
keeper:SetAttribute('KeeperDashFrom',CF(cx(18),F+5,cz(BR+4)));keeper:SetAttribute('KeeperDashTo',V3(cx(4),F+5,cz(BR+4)));keeper:SetAttribute('KeeperDashAt',R.clock);keeper:SetAttribute('KeeperDashDuration',.2)
frames(6)
local mid=false;for cc=1,22 do for rr=BR+2,BR+6 do local t=topOf(rr,cc);if t and t<K.KeyTop(0)-.05 then mid=true end end end
check(mid,'a dashing keeper presses where its dash is drawn (KeeperRecoveryDash.VisualFrame)')
keeper:SetAttribute('GuardianBehavior','GUARDING');frames(15)
local veiled=R.new('Model');veiled.Name='Veiled';veiled:SetAttribute('VeiledKeeper81',true)
local vroot=R.new('Part');vroot.Name='HumanoidRootPart';vroot.Size=V3(8,12,8);vroot.CFrame=CF(cx(18),F+6,cz(BR));vroot.Parent=veiled;veiled.PrimaryPart=vroot;veiled.Parent=runtime
frames(130)
local vdown=0;for cc=16,20 do for rr=BR-2,BR+2 do if near(topOf(rr,cc)or 99,K.KeyTop(1),1e-6)then vdown+=1 end end end
check(vdown>=1,'the event keeper (VeiledKeeper81 in _GameplayRuntime) presses keys (found by the scan)')
veiled:Destroy();frames(15)
vdown=0;for cc=16,20 do for rr=BR-2,BR+2 do if near(topOf(rr,cc)or 99,K.KeyTop(1),1e-6)then vdown+=1 end end end
check(vdown==0,'a destroyed keeper lets go')
keeper:Destroy();frames(5)
end
-- 7b. many keys down at once (a crowd / keepers): the letters riding on keys are pooled and capped per tier, the rest stay hidden
do
 hum.FloorMaterial=AIR;put(cx(11),F+9,cz(BR));frames(20)
 local crowd={}
 for i=1,60 do local pl=R.new('Player');pl.Name='C'..i;pl.UserId=500+i;pl.Parent=Players;others[#others+1]=pl
  local col=(i-1)%22+1;local row=BR+1+(i-1)//22*2
  local _,r2=makeCharacter('C'..i,cx(col),cz(row));pl.Character=r2.Parent;crowd[#crowd+1]=r2 end
 frames(20)
 local riding,down=0,0
 for _,p in ipairs(keyParts())do if p:FindFirstChildWhichIsA('SurfaceGui')then riding+=1 end;if near(top(p),K.KeyTop(1),1e-6)then down+=1 end end
 check(down>=60 and riding==K.Tier(3).KeyLegends,('60 runners on 60 keys: all down, letters ride on %d of them (the tier-3 pool of %d)'):format(riding,K.Tier(3).KeyLegends))
 local voiceSet={};for i=#plays-11,#plays do if plays[i]then voiceSet[plays[i].Sound]=true end end;local nv=0;for _ in pairs(voiceSet)do nv+=1 end
 check(nv==min(12,#plays),'click voices rotate: the last 12 clicks used 12 different voices (the one reused is always the oldest)')
 local volOk=true;for _,o in ipairs(R.created)do if o._class=='Sound'and o._props.Name=='KeyClickSound'and(o.Volume>C.ClickVolume+1e-9 or o.Volume<C.ClickVolume*.85 or o.RollOffMinDistance~=C.ClickRollOffMin or o.RollOffMaxDistance~=C.ClickRollOffMax)then volOk=false end end
 check(volOk,'every voice keeps the same roll-off and a volume within .85 .. 1 of the peak (one volume-by-distance rule for every presser)')
 for i=#others,1,-1 do others[i]=nil end
 for _,r2 in ipairs(crowd)do r2.Parent:Destroy()end
 frames(30)
 local left=0;for _,p in ipairs(keyParts())do if p:FindFirstChildWhichIsA('SurfaceGui')then left+=1 end end
 check(left==0,'when they leave, every key gives its letter back to its strip ('..left..' left riding)')
end
-- 7c. R153 (owner playtest of R152: "when keepers knock players up the keyboard clicking sounds play, it should only play when players step on the keyboard"). A key SOUNDS only when a
-- player character really steps on it: grounded (feet at the floor top), not rising fast (a knock-up's first frames), not ragdolled / flung / knocked back (RagdollService: the player's
-- GuardianRagdollActive / GuardianFlingActive, the character's ChestChaseRagdollActive, PlatformStand, the Physics / FallingDown states). Keepers never sound. The keys still go down
-- (silently) under a body lying on them, none under one flying over them. A player who landed and walks again clicks normally; the sound per key kind is unchanged.
do
local ST=R.Enum.HumanoidStateType
function R.Inst.GetState(self)return rawget(self._props,'TestState')or ST.Running end
local KEYSND,CLICK='rbxassetid://73942179280083','rbxassetid://113108830240353'
local ZERO=V3(0,0,0)
-- K.Steps on its own
check(K.Steps(F,0,false)and K.Steps(F+C.StepReach-.01,0,false)and not K.Steps(F+C.StepReach+.1,0,false)and K.Steps(F,C.StepMaxRise,false)and not K.Steps(F,C.StepMaxRise+1,false)and K.Steps(F,-90,false)and K.Steps(F,nil,false)and not K.Steps(F,0,true),
 'K.Steps: feet within StepReach '..C.StepReach..' of the floor top, not rising faster than StepMaxRise '..C.StepMaxRise..' (falling is fine: a landing), never while thrown')
-- the state flags a thrown runner carries (the same list for you and for the other players)
local FLAGS={
 {'GuardianRagdollActive on the player',function(p,c,h,on)p:SetAttribute('GuardianRagdollActive',on or nil)end},
 {'GuardianFlingActive on the player',function(p,c,h,on)p:SetAttribute('GuardianFlingActive',on or nil)end},
 {'ChestChaseRagdollActive on the character',function(p,c,h,on)c:SetAttribute('ChestChaseRagdollActive',on or nil)end},
 {'PlatformStand',function(p,c,h,on)h.PlatformStand=on or false end},
 {'the Physics state',function(p,c,h,on)h.TestState=on and ST.Physics or nil end},
 {'the FallingDown state',function(p,c,h,on)h.TestState=on and ST.FallingDown or nil end},
}
local function allOff(p,c,h)for _,f in ipairs(FLAGS)do f[2](p,c,h,false)end end
local function ids(list,id)for _,p in ipairs(list)do if p.Id~=id then return false end end;return #list>0 end
local function down(row,c0,n)local d=0;for c=c0,c0+n-1 do if near(topOf(row,c),K.KeyTop(1),1e-6)then d+=1 end end;return d end
local function park()hum.FloorMaterial=AIR;root.AssemblyLinearVelocity=ZERO;allOff(player,char,hum);put(cx(20),F+9,cz(BR));frames(20);plays={} end
-- you: the runner crosses n fresh keys (6 frames each) starting at column c0, at height y (nil: on the floor), with FloorMaterial `mat`
local function lrun(c0,n,y,mat)plays={};hum.FloorMaterial=mat or PLASTIC;for i=0,n-1 do put(cx(c0+i),y,cz(BR));frames(6)end;local l=plays;plays={};return l end
-- a grounded walk clicks
park()
check(not K.Thrown(player,char,hum),'K.Thrown: a standing runner is not thrown')
local l=lrun(2,6)
check(#l>=5 and ids(l,KEYSND),'you: a grounded walk across 6 keys clicks, the key sound ('..#l..' clicks)')
check(down(BR,7,1)==1,'...and the keys go down under him')
-- every state flag: lying on the keys (FloorMaterial still reads Plastic) = the keys go down, no click; flying over them (a stale FloorMaterial) = nothing at all
for _,f in ipairs(FLAGS)do
 park();f[2](player,char,hum,true)
 check(K.Thrown(player,char,hum),'K.Thrown sees '..f[1])
 l=lrun(2,6)
 check(#l==0 and down(BR,7,1)==1,'you, ragdolled / flung ('..f[1]..') lying on the keys: they go down, no click ('..#l..' clicks)')
 park();f[2](player,char,hum,true)
 l=lrun(2,6,F+25)
 check(#l==0 and down(BR,2,6)==0,'you, flung over the keys with a stale FloorMaterial ('..f[1]..'): no key goes down, no click ('..#l..' clicks, '..down(BR,2,6)..' keys down)')
 f[2](player,char,hum,false)
 check(not K.Thrown(player,char,hum),'K.Thrown lets go of '..f[1])
end
-- a flung runner lands and walks again: the flags clear (the server's recovery) and he clicks normally
park();for _,f in ipairs(FLAGS)do f[2](player,char,hum,true)end
l=lrun(2,6,F+25);local flying=#l
l=lrun(2,6);local lying=#l
allOff(player,char,hum);frames(4)
l=lrun(2,6)
check(flying==0 and lying==0 and #l>=5 and ids(l,KEYSND),('you: flown (%d clicks), lying (%d), then recovered and walking again: %d clicks, the key sound'):format(flying,lying,#l))
-- the first frames of a knock-up (the flags have not arrived yet): feet still at the floor, FloorMaterial not Air yet, rising fast
park();root.AssemblyLinearVelocity=V3(0,60,0)
l=lrun(2,6)
check(#l==0,'you, knocked up (rising at 60 studs/s) before any flag arrives: no click ('..#l..')')
root.AssemblyLinearVelocity=V3(0,-80,0);l=lrun(2,6)
check(#l>=5,'...a fast fall onto the keys is a landing: it clicks ('..#l..')')
root.AssemblyLinearVelocity=ZERO
-- in the air, no FloorMaterial: still nothing
park();l=lrun(2,6,F+9,AIR)
check(#l==0 and down(BR,2,6)==0,'you, in the air (FloorMaterial Air): no click, no key down')
-- a runner a little above the floor (a platform edge, a hop): the key may go down, but silently
park();l=lrun(2,6,F+3+C.StepReach+.8)
check(#l==0,'you, feet '..string.format('%.1f',C.StepReach+.8)..' above the floor: no click ('..#l..')')

-- other players (their presses are computed here, at 30 Hz); you wait in the air
park()
local function newPal(name,uid)
 local pl=R.new('Player');pl.Name=name;pl.UserId=uid;pl.Parent=Players;others[#others+1]=pl
 local pc,pr,ph=makeCharacter(name,cx(20),cz(BR)+300);pl.Character=pc;return pl,pc,pr,ph
end
local pal,pchar,proot,phum=newPal('Pal153',153)
local function parkP()proot.AssemblyLinearVelocity=ZERO;allOff(pal,pchar,phum);proot.CFrame=CF(cx(20),F+3,cz(BR)+300);frames(22);plays={} end
local function prun(c0,n,y)plays={};for i=0,n-1 do proot.CFrame=CF(cx(c0+i),y or F+3,cz(BR));frames(6)end;local pl=plays;plays={};return pl end
parkP()
l=prun(2,6)
check(#l>=5 and ids(l,KEYSND)and l[1].Speed>=.98 and l[1].Speed<=1.02,'another player: a grounded walk across 6 keys clicks, the key sound ('..#l..' clicks)')
for _,f in ipairs(FLAGS)do
 parkP();f[2](pal,pchar,phum,true)
 check(K.Thrown(pal,pchar,phum),'K.Thrown sees '..f[1]..' on another player')
 l=prun(2,6)
 check(#l==0 and down(BR,7,1)==1,'another player, ragdolled / flung ('..f[1]..') lying on the keys: they go down, no click ('..#l..' clicks)')
 parkP();f[2](pal,pchar,phum,true)
 l=prun(2,6,F+25)
 check(#l==0 and down(BR,2,6)==0,'another player, flung over the keys ('..f[1]..'): no key goes down, no click ('..#l..' clicks)')
 f[2](pal,pchar,phum,false)
end
parkP();for _,f in ipairs(FLAGS)do f[2](pal,pchar,phum,true)end
l=prun(2,6,F+25);flying=#l
l=prun(2,6);lying=#l
allOff(pal,pchar,phum);frames(4)
l=prun(2,6)
check(flying==0 and lying==0 and #l>=5 and ids(l,KEYSND),('another player: flown (%d clicks), lying (%d), then recovered and walking again: %d clicks, the key sound'):format(flying,lying,#l))
parkP();proot.AssemblyLinearVelocity=V3(0,60,0)
l=prun(2,6)
check(#l==0,'another player, knocked up before any flag arrives: no click ('..#l..')')
proot.AssemblyLinearVelocity=ZERO
parkP();l=prun(2,6,F+3+C.StepReach+.8)
check(#l==0,'another player, feet '..string.format('%.1f',C.StepReach+.8)..' above the floor (a high hop): no click ('..#l..')')

-- a thrown body pressing a key the same frame as a walker never takes his click away (the thrown one is listed first)
do
 parkP()
 local pal2,pchar2,proot2=newPal('Pal153b',154)
 proot2.CFrame=CF(cx(20),F+3,cz(BR)+300);frames(14)
 pal:SetAttribute('GuardianRagdollActive',true)
 plays={};proot.CFrame=CF(cx(9),F+3,cz(BR));proot2.CFrame=CF(cx(9),F+3,cz(BR));frames(10)
 check(#plays==1 and plays[1].Id==KEYSND and down(BR,9,1)==1,'a ragdolled body and a walker on the same key in the same frame: the key goes down once and the walker\'s click still plays ('..#plays..' clicks)')
 pal:SetAttribute('GuardianRagdollActive',nil)
 proot.CFrame=CF(cx(20),F+3,cz(BR)+300);proot2.CFrame=CF(cx(20),F+3,cz(BR)+300);frames(14)
 for i=#others,2,-1 do others[i]=nil end;pchar2:Destroy();pal2:Destroy()
end

-- R153 review (client 4): another player's LANDING clicks. On the way down his feet are 1.2 .. 3 studs over the floor for a frame or two: the key goes down silently (a runner a little above the
-- floor), and the landing on that key then found it already down and clicked nothing. Now the runner who pressed it silently clicks once when he really steps on it. A thrown body still never does.
do
 local function land(startY,speed,flag)
  parkP()
  if flag then pal:SetAttribute('GuardianFlingActive',true)end
  local y=startY;plays={}
  proot.AssemblyLinearVelocity=V3(0,-speed,0);proot.CFrame=CF(cx(3),y,cz(BR));frames(1)
  while y>F+3 do y=math.max(F+3,y-speed/60);proot.CFrame=CF(cx(3),y,cz(BR));frames(1)end
  proot.AssemblyLinearVelocity=ZERO;frames(14)
  local n=#plays;local dn=near(topOf(BR,3),K.KeyTop(1),1e-6)
  pal:SetAttribute('GuardianFlingActive',nil);plays={}
  return n,dn
 end
 local lo,hi,downAll=9,0,true
 for k=0,9 do local n,dn=land(F+9+k*.19,50);lo=min(lo,n);hi=max(hi,n);downAll=downAll and dn end
 check(lo==1 and hi==1 and downAll,('another player falls from 6 studs at 50 studs/s onto a fresh key (10 start heights, so the 30 Hz sample catches his feet in the 1.2 .. 3 stud band or not): ONE click each time, the key down (%d .. %d clicks)'):format(lo,hi))
 local nf,dnf=land(F+9,50,true)
 check(nf==0 and dnf,'...a flung body falling onto the keys stays silent ('..nf..' clicks, key down '..tostring(dnf)..')')
 parkP();plays={}
 l=prun(2,6,F+3+C.StepReach+.8)
 check(#l==0,'...and a runner who only hops past (feet always above the floor) still never clicks ('..#l..')')
 parkP()
end

-- keepers press the keys down and never sound, even next to a walker
do
 parkP()
 local keeper=R.new('Model');keeper.Name='ForestKeeper153';keeper:SetAttribute('PersistentBiomeGuardian',true)
 local kroot=R.new('Part');kroot.Name='HumanoidRootPart';kroot.Size=V3(6,10,6);kroot.CFrame=CF(cx(16),F+5,cz(BR+3));kroot.Parent=keeper;keeper.PrimaryPart=kroot
 keeper.Parent=camps;W.CS:AddTag(keeper,'BiomeKeeper');frames(2)
 plays={};for cc=8,12 do kroot.CFrame=CF(cx(cc+4),F+5,cz(BR+3));frames(8)end -- it walks over fresh keys
 local kd=0;for cc=11,18 do for rr=BR+1,BR+5 do if near(topOf(rr,cc)or 99,K.KeyTop(1),1e-6)then kd+=1 end end end
 check(kd>=1 and #plays==0,'a keeper walking over the keys: they go down ('..kd..'), no click ('..#plays..')')
 kroot.CFrame=CF(cx(16),F+5,cz(BR+3));frames(12)
 l=prun(2,6)
 local nearKeeper=0;for _,pl in ipairs(l)do if abs(pl.Pos.Z-cz(BR+3))<20 and abs(pl.Pos.X-kroot.CFrame.Position.X)<20 then nearKeeper+=1 end end
 check(#l>=5 and nearKeeper==0,'...and the clicks around it are the walker\'s ('..#l..' clicks, '..nearKeeper..' at the keeper)')
 keeper:Destroy();frames(10)
end

-- the sound per key kind is unchanged: a normal key the key sound, a spacebar the click (for a player who steps on it; silent for a thrown one)
do
 local bar=g.Bars[1];local zb=bar.Z0+2;local zFar=bar.Z0+70
 local function barRun(set)set(zFar);frames(14);plays={};set(zb);frames(12);local pl=table.clone(plays);set(zFar);frames(14);return pl end
 parkP();park()
 hum.FloorMaterial=PLASTIC
 local lb=barRun(function(z)put(cx(8),nil,z)end)
 check(#lb==1 and lb[1].Id==CLICK and lb[1].Volume<=C.ClickVolume+1e-9,'you, grounded on a spacebar: the original click 113108830240353 ('..#lb..')')
 hum.FloorMaterial=AIR;put(cx(20),F+9,zb+8);frames(10) -- you hover near the bar (a click is only heard within ClickRange of you)
 pal:SetAttribute('GuardianFlingActive',true)
 lb=barRun(function(z)proot.CFrame=CF(cx(8),F+3,z)end)
 check(#lb==0,'another player, flung, lying on a spacebar: no click ('..#lb..')')
 pal:SetAttribute('GuardianFlingActive',nil)
 lb=barRun(function(z)proot.CFrame=CF(cx(8),F+3,z)end)
 check(#lb==1 and lb[1].Id==CLICK,'...recovered: the spacebar click again ('..#lb..')')
 proot.CFrame=CF(cx(20),F+3,cz(BR)+300);frames(10)
 player:SetAttribute('GuardianRagdollActive',true);hum.FloorMaterial=PLASTIC
 lb=barRun(function(z)put(cx(8),nil,z)end)
 check(#lb==0,'you, ragdolled on a spacebar: no click ('..#lb..')')
 player:SetAttribute('GuardianRagdollActive',nil)
end
check(K.PressSoundId('Key',g.RowStage[BR])==KEYSND and K.PressSoundId('Spacebar')==CLICK,'the per-kind sounds are unchanged: normal key 73942179280083, spacebar the click')

-- back to the state the next section expects
for i=#others,1,-1 do others[i]=nil end
pchar:Destroy();pal:Destroy()
allOff(player,char,hum);root.AssemblyLinearVelocity=nil
hum.FloorMaterial=AIR;put(cx(11),F+9,cz(BR));frames(40);plays={}
end
-- 8. shovel holes: they lie on the keys (near and far); the keys under them stay up
-- R153: the holes are the server's (TrackHoleService._build, sizes from TrackHoleConfig: pit 5.1 across, rim .45 wider all round; was 3.4 / .3), Rim .05 thick at +.025 and Pit .10 thick at +.05 (R153: tops .05 and .10 over the floor; the pit's top is .05 above the rim's, more than the 4 depth steps (.043) a 300-stud view of a 5-stud overlap has).
do
local holes=R.new('Folder');holes.Name='TrackHoles';holes.Parent=runtime
local THC=W.module('TrackHoleConfig');local rimD=THC.Diameter+2*THC.RimWidth
local function dig(id,x,z)
 local m=R.new('Model');m.Name='TrackHole_'..id
 local pit=R.new('Part');pit.Name='Pit';pit.Size=V3(.10,THC.Diameter,THC.Diameter);pit.CFrame=CF(x,F+.05,z);pit.Parent=m
 local rim=R.new('Part');rim.Name='Rim';rim.Size=V3(.05,rimD,rimD);rim.CFrame=CF(x,F+.025,z);rim.Parent=m
 local crumb=R.new('Part');crumb.Name='Crumb';crumb.Size=V3(.3,.3,.3);crumb.CFrame=CF(x+rimD/2+.3,F+.1,z);crumb.Parent=m
 m.PrimaryPart=pit;m.Parent=holes;return m,pit,rim,crumb
end
put(cx(11),nil,cz(BR));hum.FloorMaterial=PLASTIC;frames(40)
local HR,HC=BR+4,6
local hx,hzz=cx(HC),cz(HR)
local h1,pit1,rim1=dig(1,hx,hzz);frames(30)
check(keyAt(HR,HC)~=nil and near(topOf(HR,HC),K.KeyTop(0),1e-6),'a hole leaves its key in place, at rest')
check(near(pit1.CFrame.Position.Y,F+.05+C.HoleLift,1e-6)and near(rim1.CFrame.Position.Y,F+.025+C.HoleLift,1e-6),'the hole parts are lifted onto the key tops')
local rimBottom=rim1.CFrame.Position.Y-.025;local rimTop=rim1.CFrame.Position.Y+.025;local pitTop=pit1.CFrame.Position.Y+.05
check(rimBottom>=K.KeyTop(0)+.015 and rimTop-K.KeyTop(0)>=.06 and pitTop-K.KeyTop(0)>=.08 and pitTop-rimTop>=.045,'z-fighting: the Rim / Pit tops are .11 / .16 above the key top and .05 apart (more than the .043 of 4 depth steps at 300 studs, where a 5-stud hole is still seen)')
do -- (TrackHoleService: Rim .05 thick at +.025, Pit .10 thick at +.05 above the floor; the letter strips' tops lie at the key top + Legend.Margin .05)
 local stripTop=K.KeyTop(0)+LT.Margin
 check((F+.025+C.HoleLift+.025)-stripTop>=.05-1e-9 and (F+.05+C.HoleLift+.05)-stripTop>=.08-1e-9,'z-fighting (review part 2): a lifted hole\'s Rim top stands .06 and its Pit top .11 above the letter strips (R151: HoleLift = RestRise + .06 keeps the clearance over the strips: .05 since R152, the least the R149 depth rule allows)')
end
local sl=nil
for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 and g.RowOfZ(st.CFrame.Position.Z)==HR then
 for _,l in ipairs(st:FindFirstChildWhichIsA('SurfaceGui'):GetChildren())do if l._class=='TextLabel'and g.ColOfX((worldOf(st,l.Position.X.Offset,l.Position.Y.Offset,LT.PixelsPerStud)))==HC and l.Text==K.Legend(HR,HC)then sl=l end end end end
check(sl and sl.Visible==false,'the letter of the key under a hole is hidden (the hole covers it)')
plays={};put(hx,nil,hzz);frames(12)
check(near(topOf(HR,HC),K.KeyTop(0),1e-6)and #plays==0,'stepping on the hole does not press its key (the hole would float above a pressed key)')
local nb=keyAt(HR,HC+2);put(cx(HC+2),nil,hzz);frames(12)
check(near(topOf(HR,HC+2),K.KeyTop(1),1e-6),'the keys around it still press')
put(cx(11),nil,cz(BR));frames(14)
h1:Destroy();frames(30)
check(sl.Visible==true,'the letter comes back when the hole is filled')
put(hx,nil,hzz);frames(12);check(near(topOf(HR,HC),K.KeyTop(1),1e-6),'...and the key presses again')
-- R153: 1.5x the radius. HoleReach covers the rim (3.0 from the centre): every key under ANY part of the rim stays up (a pressed key under it would leave the hole floating over a dip),
-- also at the corner of four keys; two holes at MinSpacing both lie on the keys.
do
 local rimR=THC.Diameter/2+THC.RimWidth
 local reachNeed=rimR+THC.CrumbSpread+THC.CrumbSizeMax
 check(C.HoleReach>=reachNeed-1e-9 and C.HoleReach<=reachNeed+.3,'HoleReach '..C.HoleReach..' covers the bigger hole\'s rim radius '..rimR..' AND the ring of crumbs outside it (R153 review: rim + CrumbSpread '..THC.CrumbSpread..' + CrumbSizeMax '..THC.CrumbSizeMax..' = '..reachNeed..'; it was 2 for the old rim, 3 for the rim only)')
 put(cx(11),nil,cz(BR));frames(14)
 local gx,gz=(cx(HC)+cx(HC+1))/2,(cz(HR)+cz(HR+1))/2 -- the corner shared by four keys
 local hc,pc,rc=dig(7,gx,gz);frames(30)
 check(near(pc.CFrame.Position.Y,F+.05+C.HoleLift,1e-6)and near(rc.CFrame.Position.Y,F+.025+C.HoleLift,1e-6),'a hole at the corner of four keys is lifted onto the key tops')
 local cells,n,bad,pressed={},0,0,0
 for a=0,359,10 do cells[g.RowOfZ(gz+rimR*math.sin(math.rad(a)))*64+g.ColOfX(gx+rimR*math.cos(math.rad(a)))]=true end
 cells[g.RowOfZ(gz)*64+g.ColOfX(gx)]=true
 for key in pairs(cells)do
  local row,col=key//64,key%64;n+=1;plays={}
  put(cx(col),nil,cz(row));frames(12)
  if not near(topOf(row,col),K.KeyTop(0),1e-6)or #plays>0 then bad+=1 end
 end
 check(n>=4 and bad==0,'every key under the hole (the circle of its rim and its centre: '..n..' keys) stays up and silent when stepped on ('..bad..' pressed)')
 put(cx(HC+3),nil,cz(HR));frames(12);check(near(topOf(HR,HC+3),K.KeyTop(1),1e-6),'a key two columns past the rim still presses')
 local h2,p2=dig(8,gx+THC.MinSpacing,gz);frames(30)
 check(near(p2.CFrame.Position.Y,F+.05+C.HoleLift,1e-6)and near(pc.CFrame.Position.Y,F+.05+C.HoleLift,1e-6),'two holes at MinSpacing ('..THC.MinSpacing..') both lie on the keys')
 put(cx(11),nil,cz(BR));frames(14)
 h2:Destroy();hc:Destroy();frames(30)
 local back=0;for key in pairs(cells)do local row,col=key//64,key%64;put(cx(col),nil,cz(row));frames(12);if near(topOf(row,col),K.KeyTop(1),1e-6)then back+=1 end end
 check(back==n,'...and every one of those keys presses again once the holes are filled ('..back..' of '..n..')')
 put(cx(11),nil,cz(BR));frames(14)
 -- R153 review (client 2): the crumbs lie up to CrumbSpread outside the rim (the server draws them 3.1 .. 4.1 studs from the centre): the key under each of them stays up too, wherever
 -- the hole sits on the grid (a crumb lifted onto a key that went down when someone stepped on it hung 1.16 studs in the air in about 28% of the holes)
 do
  local far=rimR+THC.CrumbSpread;local bad,n2=0,0
  for k,off in ipairs({0,1,2,3,4})do
   local x0,z0=cx(HC)+off,cz(HR)+off*.5
   local hm=dig(40+k,x0,z0);local crumbs={}
   for a=0,315,45 do local c=R.new('Part');c.Name='Crumb';c.Size=V3(.4,.4,.4);c.CFrame=CF(x0+far*math.cos(math.rad(a)),F+.14,z0+far*math.sin(math.rad(a)));c.Parent=hm;crumbs[#crumbs+1]=c end
   frames(20)
   for _,c in ipairs(crumbs)do
    local pp=c.CFrame.Position;local row,col=g.RowOfZ(pp.Z),g.ColOfX(pp.X)
    plays={};put(cx(col),nil,cz(row));frames(12);n2+=1
    if not near(topOf(row,col),K.KeyTop(0),1e-6)or #plays>0 then bad+=1 end
   end
   put(cx(11),nil,cz(BR));frames(14);hm:Destroy();frames(10)
  end
  check(n2==40 and bad==0,'a crumb at the server\'s largest radius ('..string.format('%.1f',far)..' studs from the pit, 8 directions, the hole at 5 places on its key): the key under every one of them stays up and silent when stepped on ('..bad..' of '..n2..' went down)')
 end
 -- R153 review (client 1): a hole dug 10 studs from a small pack (PackClearance) can share a key with the pack's platform. The platform holds its keys down, the hole keeps its keys up: where both
 -- want a key the HOLE wins (a pressed key would leave the pit floating over a dip); the platform's other keys are still down
 do
  local sharedN,badUp,badDown,platN=0,0,0,0
  for t=0,8 do
   local x0,z0=cx(14)+t-4,cz(BR+8);local px,pz=x0+10,z0
   local hm=dig(70+t,x0,z0)
   local seedM=R.new('Model');seedM.Name='SeedShare'..t;seedM.Parent=seeds
   local pl=R.new('Model');pl.Name='PackPlatform';pl:SetAttribute('PlatformRadius',1.0)
   local st=R.new('Part');st.Name='BiomeStone';st.CFrame=CF(px,F+.3,pz);st.Parent=pl;pl.PrimaryPart=st;pl.Parent=seedM
   frames(30)
   local hc1,hc2,hr1,hr2=g.CellRange(x0-C.HoleReach,x0+C.HoleReach,z0-C.HoleReach,z0+C.HoleReach)
   local rr=1.0+C.PlatformClearance
   local pc1,pc2,pr1,pr2=g.CellRange(px-rr,px+rr,pz-rr,pz+rr)
   for r=hr1,hr2 do for c=hc1,hc2 do
    if c>=pc1 and c<=pc2 and r>=pr1 and r<=pr2 then sharedN+=1 end
    if keyAt(r,c)and not near(topOf(r,c),K.KeyTop(0),1e-6)then badUp+=1 end
   end end
   for r=pr1,pr2 do for c=pc1,pc2 do
    if not(c>=hc1 and c<=hc2 and r>=hr1 and r<=hr2)and keyAt(r,c)then platN+=1;if not near(topOf(r,c),K.KeyTop(1),1e-6)then badDown+=1 end end
   end end
   seedM:Destroy();hm:Destroy();frames(20)
  end
  check(sharedN>=1 and badUp==0,'a hole and a pack platform 10 studs apart (9 offsets, '..sharedN..' keys wanted by both): every key under the hole stays up, the hole wins ('..badUp..' pressed)')
  check(platN>=1 and badDown==0,'...and the platform\'s own keys (not under the hole) are still held down ('..badDown..' of '..platN..' up)')
 end
end
put(cx(11),nil,cz(BR));frames(14)
-- the lift is per part: streamed-in parts, crumb tweens, rebuilt models
do
 local h5,pit5,rim5,crumb5=dig(5,hx,hzz);frames(2)
 check(near(crumb5.CFrame.Position.Y,F+.1+C.HoleLift,1e-6)and near(pit5.CFrame.Position.Y,F+.05+C.HoleLift,1e-6),'every part of a hole (Pit, Rim, crumbs) is lifted')
 pit5:Destroy()
 local pit5b=R.new('Part');pit5b.Name='Pit';pit5b.Size=V3(.10,THC.Diameter,THC.Diameter);pit5b.CFrame=CF(hx,F+.05,hzz);pit5b.Parent=h5
 frames(1)
 check(near(pit5b.CFrame.Position.Y,F+.05+C.HoleLift,1e-6),'a hole part that streams in again (a new instance at the server height) is lifted within a frame')
 local crumbB=R.new('Part');crumbB.Name='Crumb';crumbB.Size=V3(.3,.3,.3);crumbB.CFrame=CF(hx-1.9,F+.1,hzz);crumbB.Parent=h5;frames(1)
 check(near(crumbB.CFrame.Position.Y,F+.1+C.HoleLift,1e-6),'...also a streamed-in crumb')
 crumb5.Position=V3(hx,F+.35,hzz);frames(8)
 check(near(crumb5.CFrame.Position.Y,F+.35,1e-6),'a crumb in mid-tween is not touched')
 crumb5.Position=V3(hx+1.9,F+.1,hzz);frames(30)
 check(near(crumb5.CFrame.Position.Y,F+.1+C.HoleLift,1e-6),'a crumb the tween put back at the server height is lifted again')
 check(near(pit5b.CFrame.Position.Y,F+.05+C.HoleLift,1e-6),'parts already lifted are never lifted twice')
 h5:Destroy();frames(5)
 local h5c,pit5c=dig(6,hx,hzz);frames(1)
 check(near(pit5c.CFrame.Position.Y,F+.05+C.HoleLift,1e-6),'a rebuilt hole model is lifted')
 h5c:Destroy();frames(30)
end
-- far away (600 studs ahead): the same
local farRow=g.RowOfZ(cz(BR)+600);local farX,farZ=cx(15),cz(farRow)
local farHole,farPit=dig(3,farX,farZ);frames(30)
check(keyAt(farRow,15)~=nil and near(topOf(farRow,15),K.KeyTop(0),1e-6)and near(farPit.CFrame.Position.Y,F+.05+C.HoleLift,1e-6),'a hole 600 studs ahead lies on its key the same way (visible from afar)')
farHole:Destroy();frames(10)
-- a hole on a spacebar: the bar stays (unpressable) and the hole lies on it
put(cx(11),nil,cz(BR));frames(10)
local bar1=barPart(1)
local barHole=dig(4,0,(g.Bars[1].Z0+g.Bars[1].Z1)/2);frames(30)
check(bar1.Transparency==0,'a hole on a spacebar leaves the bar in place')
put(cx(4),nil,g.Bars[1].Z0+3);frames(20)
check(near(top(bar1),K.KeyTop(0),1e-6),'...and the bar cannot be pressed while the hole is on it')
barHole:Destroy();frames(30);check(near(top(bar1),K.KeyTop(1),1e-6),'...it presses again once the hole is filled')
put(cx(11),nil,cz(BR));frames(30)
-- pack platforms: their keys are held down (silently), so the platform stone shows on them
local seed=R.new('Model');seed.Name='Seed1';seed.Parent=seeds
local plat=R.new('Model');plat.Name='PackPlatform';plat:SetAttribute('PlatformRadius',1.5)
local stone=R.new('Part');stone.Name='BiomeStone';stone.CFrame=CF(cx(16),F+.3,cz(BR+8));stone.Parent=plat;plat.PrimaryPart=stone
plays={};plat.Parent=seed;frames(30)
check(near(topOf(BR+8,16),K.KeyTop(1),1e-6)and #plays==0,'a pack platform holds the keys under it down, silently (its stone shows on them)')
check(near(topOf(BR+8,18),K.KeyTop(0),1e-6),'...only those under it')
plat:Destroy();frames(30);check(near(topOf(BR+8,16),K.KeyTop(0),1e-6),'...and lets them up when the platform goes')
check(floors[1].Transparency==0 and floors[1].CanCollide==true,'the real floor\'s gameplay properties are still untouched')
-- a hole that is still there at teardown goes back to its server height (checked in 10.)
local keepHole,keepPit=dig(9,cx(3),cz(BR+12));frames(5)
keepPitRef=keepPit
end
-- 8b. R153 (owner: "fix the bug where dirt piles would float up into the sky", a screenshot of dug holes hanging over the hub): a shovel hole climbed ~5 studs a second.
-- Cause: the lift onto the key tops was remembered in two weak tables keyed by the Instance and applied as "Position + HoleLift". Roblox hands a script a NEW wrapper for an
-- Instance it let go of, so the memory vanished and the scan (4 a second) lifted the same part again, for as long as the hole lived (180 s). Here the engine's behaviour is
-- modelled for the hole folder (every part a script gets from it is a fresh wrapper; the stable-identity mock could never show the climb), with the REAL TrackHoleClient (its
-- dig animation on a time-stepped TweenService) and the real keyboard: a hole is dug, left for 20 s, the runner leaves (rows recycle) and comes back, teleports.
do
 local THC=W.module('TrackHoleConfig');local rimD=THC.Diameter+2*THC.RimWidth
 local holesF=runtime:FindFirstChild('TrackHoles')
 local restTop=K.KeyTop(0);local CEIL=C.HoleCeiling or 1
 -- stand-ins for what TrackHoleClient asks of the world: a time-stepped TweenService (the shared mock jumps to the end value and never completes), the TrackHole remote
 -- (a BindableEvent here: the keyboard itself must never make or use a RemoteEvent), the PlayerGui and the input / sound services it binds
 local Tw=W.service('TweenService');local create0=Tw.Create;local live={}
 local function ease(style,dir,t)
  if style==R.Enum.EasingStyle.Back then local c1=1.70158;local c3=c1+1;if dir==R.Enum.EasingDirection.Out then return 1+c3*(t-1)^3+c1*(t-1)^2 end;return c3*t*t*t-c1*t*t end
  if dir==R.Enum.EasingDirection.In then return t*t end
  return 1-(1-t)*(1-t)
 end
 Tw.Create=function(_,obj,info,props)
  local tw={Completed=R.signal(),T=0,On=false}
  function tw.Play()tw.On=true;tw.T=0;tw.From={};for k in pairs(props)do tw.From[k]=obj[k]end;live[#live+1]=tw end
  function tw.Cancel()tw.On=false end
  tw.Step=function(dt)
   tw.T+=dt;local a=math.min(1,tw.T/math.max(info.Time,1e-6));local e=ease(info.Style,info.Dir,a)
   for k,v in pairs(props)do
    local f=tw.From[k]
    if R.typeof(v)=='CFrame'then obj[k]=(a>=1)and v or CF(f.Position:Lerp(v.Position,e))
    elseif R.typeof(v)=='Vector3'then obj[k]=f:Lerp(v,e)
    else obj[k]=f+(v-f)*e end
   end
   if a>=1 then tw.On=false;tw.Completed:Fire()end
  end
  return tw
 end
 local tweenConn=W.Run.Heartbeat:Connect(function(dt)
  for i=#live,1,-1 do local tw=live[i];if tw.On then tw.Step(dt)else table.remove(live,i)end end
 end)
 local debris=W.service('Debris');local debris0=debris.AddItem
 debris.AddItem=function(_,o,t)R.task.delay(t,function()if o.Parent then o:Destroy()end end)end
 local CAS=W.service('ContextActionService');function CAS.BindActionAtPriority(_,name,fn)W.actions[name]=fn end
 local UIS=W.UIS;UIS.TouchTapInWorld=R.signal();UIS.GamepadEnabled=false;function UIS.GetMouseLocation()return R.Vector2.new(640,360)end
 local pgui=R.new('PlayerGui');pgui.Name='PlayerGui';pgui.Parent=player
 local remotesF=R.new('Folder');remotesF.Name='ChestChaseRemotes';remotesF.Parent=RS
 local holeRemote=R.new('BindableEvent');holeRemote.Name='TrackHole';holeRemote.OnClientEvent=R.signal();holeRemote.Parent=remotesF
 local motionM=RS:FindFirstChild('RunnerMotion');motionM:SetAttribute('TrackBoundaryZ',0);motionM:SetAttribute('TrackCenterX',0);motionM:SetAttribute('TrackHalfWidth',114)
 local hsc=R.new('LocalScript');hsc.Name='TrackHoleClient'
 local okHole,errHole=pcall(W.load,'TrackHoleClient',hsc);check(okHole,'the real TrackHoleClient loads in the keyboard world: '..tostring(errHole))

 -- the engine's wrappers: every Instance a script gets from the hole folder (GetChildren / GetDescendants / FindFirstChild / DescendantAdded) is a NEW object, equal only in what
 -- it stands for (a table key made from it never finds an earlier entry)
 local realOf=setmetatable({},{__mode='k'});local rewrap=false;local wraps=0
 local function isUnder(o)local p=o;while p do if p==holesF then return true end;p=p._parent end;return false end
 local function unwrap(v)return realOf[v]or v end
 local function wrap(o)
  if not rewrap or type(o)~='table'or getmetatable(o)~=R.instMeta then return o end
  wraps+=1;local proxy={};realOf[proxy]=o
  return setmetatable(proxy,{
   __index=function(_,k)local v=o[k];if type(v)=='function'then return function(_,...)return v(o,...)end end;return v end,
   __newindex=function(_,k,val)o[k]=unwrap(val)end,
   __tostring=function()return tostring(o)end,
  })
 end
 local function wrapList(list)local out={};for i,v in ipairs(list)do out[i]=wrap(v)end;return out end
 local gc0,gd0,ff0=R.Inst.GetChildren,R.Inst.GetDescendants,R.Inst.FindFirstChild
 R.Inst.GetChildren=function(self,...)local r=gc0(self,...);if rewrap and isUnder(self)then return wrapList(r)end;return r end
 R.Inst.GetDescendants=function(self,...)local r=gd0(self,...);if rewrap and isUnder(self)then return wrapList(r)end;return r end
 R.Inst.FindFirstChild=function(self,...)local r=ff0(self,...);if rewrap and r and isUnder(self)then return wrap(r)end;return r end
 local sig=holesF.DescendantAdded;local fire0=sig.Fire
 sig.Fire=function(self,d,...)return fire0(self,wrap(d),...)end

 -- a hole as the server builds it (TrackHoleService._build): Rim .05 thick at +.025, Pit .10 at +.05, 12 crumbs outside the rim; the model is parented last
 local auth={};local seedN=7
 local function rnd(a,b)seedN=(seedN*1103515245+12345)%2147483648;return a+(b-a)*seedN/2147483648 end
 local function build(id,x,z)
  local m=R.new('Model');m.Name='TrackHole_'..id
  local function part(name,size,y,px,pz)local p=R.new('Part');p.Name=name;p.Size=size;p.CFrame=CF(px,y,pz);p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Parent=m;auth[p]=y;return p end
  local rim=part('Rim',V3(.05,rimD,rimD),F+.025,x,z)
  local pit=part('Pit',V3(.10,THC.Diameter,THC.Diameter),F+.05,x,z)
  for i=1,THC.CrumbCount do
   local a=(i/THC.CrumbCount)*math.pi*2+rnd(-.3,.3);local rr=rimD/2+rnd(.1,1.1);local s=rnd(.22,.5)
   part('Crumb',V3(s,s*rnd(.6,1),s),F+s*.35,x+math.cos(a)*rr,z+math.sin(a)*rr)
  end
  m.PrimaryPart=pit;m.Parent=holesF
  return m,pit,rim
 end
 local function parts(m)local out={};for _,d in ipairs(m:GetDescendants())do if realOf[d]then out[#out+1]=realOf[d]elseif d:IsA('BasePart')then out[#out+1]=d end end;return out end
 -- how far each part of the hole is from where one lift puts it: the worst, and the highest centre
 local function drift(m)
  local worst,hi=0,-1e9
  for _,p in ipairs(parts(m))do local y=p.CFrame.Position.Y;worst=max(worst,abs(y-(auth[p]+C.HoleLift)));hi=max(hi,y)end
  return worst,hi
 end
 local function hz()return cx(7),cz(BR+6)end

 put(cx(11),nil,cz(BR));hum.FloorMaterial=PLASTIC;frames(40)
 local hx,hzz=hz()

 -- (1) a hole dug and left alone: ONE lift (the dig animation tweens the crumbs back to where they were, the keyboard puts them on the keys again)
 local m1=build(21,hx,hzz);frames(2)
 holeRemote.OnClientEvent:Fire({Kind='Dig',Id=21,Position=V3(hx,F,hzz)})
 frames(120)
 local d1,hi1=drift(m1)
 check(d1<1e-6 and #parts(m1)==14,('dug with the real client: every part of the hole (rim, pit, 12 crumbs) stands exactly one HoleLift (%.2f) over where the server put it (worst error %.2g)'):format(C.HoleLift,d1))
 -- (2) the engine's wrappers: the same hole, now with every part a script gets from the folder a fresh wrapper. 20 s next to it, a run 450 rows away (the rows around it are recycled), back, teleports
 rewrap=true;wraps=0
 local m2=build(22,hx+THC.MinSpacing,hzz);frames(2)
 holeRemote.OnClientEvent:Fire({Kind='Dig',Id=22,Position=V3(hx+THC.MinSpacing,F,hzz)})
 local samples={}
 for s=1,20 do frames(60);local _,hi=drift(m2);samples[#samples+1]=hi end
 for i=1,5 do put(cx(11),nil,cz(BR+90*i));frames(80);local _,hi=drift(m2);samples[#samples+1]=hi end
 put(cx(11),nil,cz(BR));frames(120)
 for i=1,6 do put(cx(2+i*3),nil,cz(BR+i*40));frames(6);local _,hi=drift(m2);samples[#samples+1]=hi end
 put(cx(11),nil,cz(BR));frames(240)
 local d2,hi2=drift(m2);local top=-1e9;for _,v in ipairs(samples)do top=max(top,v)end
 print(('dirt float: with re-wrapped instances the highest hole part stands at Y %.2f after 20 s, a 450-row run and 6 teleports (key top %.2f, one lift puts a crumb at most at %.2f; the R152 code reached ~5 studs a second); %d wrappers made'):format(max(top,hi2),restTop,F+.175+C.HoleLift,wraps))
 check(d2<1e-6 and top<=F+.25+C.HoleLift+1e-6,('R153: a hole never climbs: after 20 s, a 450-row run (rows recycled), a return and 6 teleports every part is still one lift over the server height (worst error %.2g, highest centre %.2f <= %.2f)'):format(d2,top,F+.25+C.HoleLift))
 check(rewrap and wraps>1000,'(the test really handed the keyboard new wrappers: '..wraps..')')
 -- (3) the part's own record is gone (any other way the memory could be lost): a part that already stands on the key tops is never lifted again
 local pit2=parts(m2)[2];local y0=pit2.CFrame.Position.Y
 pit2:SetAttribute('KbHoleBase',nil);for _,p in ipairs(parts(m2))do p:SetAttribute('KbHoleBase',nil)end
 frames(40)
 local d3=drift(m2)
 check(d3<1e-6 and near(pit2.CFrame.Position.Y,y0,1e-9),'a part with no record that stands at or above the resting key top is left where it is (never lifted twice)')
 -- (4) dirt stranded in the air (whatever put it there) is brought back within a scan: with a record to where the lift puts it, without one to the key tops
 local kids=parts(m2);local crumbA,crumbB=kids[5],kids[6]
 crumbA.Position=V3(crumbA.Position.X,60,crumbA.Position.Z);crumbB.Position=V3(crumbB.Position.X,90,crumbB.Position.Z)
 frames(20)
 check(crumbA.CFrame.Position.Y<=restTop+CEIL+1e-6 and crumbB.CFrame.Position.Y<=restTop+CEIL+1e-6,('stranded dirt (crumbs at Y 60 and 90, no record) is back on the key tops within a scan (%.2f, %.2f)'):format(crumbA.CFrame.Position.Y,crumbB.CFrame.Position.Y))
 rewrap=false
 local m3=build(23,hx,hzz+THC.MinSpacing);frames(2)
 local crumbC=parts(m3)[7];local cy=crumbC.CFrame.Position.Y
 crumbC.Position=V3(crumbC.Position.X,cy+70,crumbC.Position.Z);frames(20)
 check(near(crumbC.CFrame.Position.Y,cy,1e-6),'...a crumb with its record goes back exactly where the lift put it')
 -- (5) write on change (R152): a hole at rest is not written to
 local writes=0;local prev=R.instMeta.__newindex;local watch={}
 for _,mm in ipairs({m1,m3})do for _,p in ipairs(parts(mm))do watch[p]=true end end
 R.instMeta.__newindex=function(o,k,v)if watch[o]and(k=='CFrame'or k=='Position')then writes+=1 end;return prev(o,k,v)end
 frames(120)
 R.instMeta.__newindex=prev
 check(writes==0,'a hole at rest is never written to ('..writes..' CFrame / Position writes to 2 holes in 2 s)')
 -- (6) a part that streams in again (a new instance at the server height) is lifted once, also with new wrappers
 rewrap=true
 local rimOld=m3:FindFirstChild('Rim');rimOld=unwrap(rimOld);rimOld:Destroy()
 local rimNew=R.new('Part');rimNew.Name='Rim';rimNew.Size=V3(.05,rimD,rimD);rimNew.CFrame=CF(hx,F+.025,hzz+THC.MinSpacing);rimNew.Anchored=true;rimNew.Parent=m3;auth[rimNew]=F+.025
 frames(40)
 check(near(rimNew.CFrame.Position.Y,F+.025+C.HoleLift,1e-6),'a rim streamed in again is lifted once')
 rewrap=false
 for _,mm in ipairs({m1,m2,m3})do mm:Destroy()end
 frames(10)
 -- put the shared mock back
 R.Inst.GetChildren,R.Inst.GetDescendants,R.Inst.FindFirstChild=gc0,gd0,ff0;sig.Fire=fire0
 tweenConn:Disconnect();Tw.Create=create0;debris.AddItem=debris0
 put(cx(11),nil,cz(BR));frames(30)
end
-- 9. tiers: a change applies after it has held a few seconds, and only adds / removes rows at the window's end
do
put(cx(11),nil,cz(BR));hum.FloorMaterial=AIR;frames(60)
local function keySet()local t={};for _,p in ipairs(keyParts())do t[p]=true end;return t end
local before=keySet();local nb=0;for _ in pairs(before)do nb+=1 end
resetWrites()
fxTier=1;frames(60*2)
local mid1=keySet();local nm=0;for _ in pairs(mid1)do nm+=1 end
check(nm==nb and writes.key==0,'tier 1 for 2 s: nothing changes yet (a tier must hold ~3 s)')
fxTier=3;frames(60*5)
check(writes.key==0,'a tier that flips back before 3 s never changed anything')
fxTier=2;frames(60*4)
local after2=keySet();local n2=0;local kept=0;for p in pairs(after2)do n2+=1;if before[p]then kept+=1 end end
local a,b=windowRows(cz(BR),2);local want2=0;for r=a,b do if not g.BarOfRow[r]then want2+=22 end end
local h2=K.Tier(2).Hyst*2*22
check(n2>=want2 and n2<=want2+h2 and kept==n2 and writes.key==0,('tier 2 held: rows %d .. %d (%d keys wanted, %d kept with the hysteresis rows), the keys that stay are the same parts, untouched (%d re-dressed)'):format(a,b,want2,n2,writes.key))
check(n2<=K.KeyCap(2,22),'tier 2 cap holds ('..n2..' <= '..K.KeyCap(2,22)..')')
coverage(a,b,'tier 2')
local strips2=0;for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 then strips2+=1 end end
local la2,lb2=K.LegendWindow(g,2,g.RowOfZ(cz(BR)));check(strips2>=2*(lb2-la2+1)and strips2<=2*(lb2-la2+3),'tier 2: letters on '..(lb2-la2+1)..' rows (+1 row kept each side: '..strips2..' strips)')
fxTier=1;frames(60*4)
a,b=windowRows(cz(BR),1);local n1=#keyParts();local want1=0;for r=a,b do if not g.BarOfRow[r]then want1+=22 end end
check(n1>=want1 and n1<=want1+K.Tier(1).Hyst*2*22 and n1<=K.KeyCap(1,22),('tier 1: rows %d .. %d (%d keys, %d kept, cap %d)'):format(a,b,want1,n1,K.KeyCap(1,22)))
coverage(a,b,'tier 1')
fxTier=3;frames(60*4)
a,b=windowRows(cz(BR),3);local n3=#keyParts();local want3=0;for r=a,b do if not g.BarOfRow[r]then want3+=22 end end
check(n3>=want3 and n3<=want3+K.Tier(3).Hyst*2*22,'back to tier 3: '..n3..' keys ('..want3..' wanted)')
coverage(a,b,'tier 3 again')
-- a key dressed under a standing runner is down at once and silent
hum.FloorMaterial=PLASTIC;plays={};put(cx(11),nil,2500);frames(14)
check(#plays==0 and near(topOf(g.RowOfZ(2500),g.ColOfX(cx(11)))or 99,K.KeyTop(1),1e-6),'a key dressed under a standing runner is down at once and silent ('..#plays..' clicks)')
end
-- 10. teardown: the folder goes, the floor comes back
sc.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'the folder goes with the script')
local restored=true;for _,fp in ipairs(floors)do if fp.LocalTransparencyModifier~=0 then restored=false end end
check(restored and grassTex.LocalTransparencyModifier==0,'teardown shows the real floor (and its texture) again')
check(keepPitRef and near(keepPitRef.CFrame.Position.Y,F+.05,1e-6),'teardown puts a lifted shovel hole back at its server height')
check(W.module('KeyboardSurface149').Lift(W.fxProbe.X,W.fxProbe.Z,F)==0,'teardown: floor-level effects are no longer lifted (no keyboard folder, no keys)')
for _,h in ipairs(runtime:GetDescendants())do if h.Name=='TrackHoles'then h:Destroy()end end
local before2=#R.created;frames(30);check(#R.created==before2,'nothing runs after the script is destroyed')
check(nonRemote(),'still no RemoteEvent / RemoteFunction anywhere')
-- 11. a floor part that streams in later is hidden at once; one that streams out takes its local copy with it
do
 local scS=R.new('LocalScript');scS.Name='KeyboardTrack';W.load('KeyboardTrackClient',scS)
 put(cx(11),nil,cz(BR));frames(30)
 local storm=floors[7];local m7=storm.Parent
 check(#workspace.KeyboardTrackVisuals.Ground:GetChildren()==1,'(the arena copy is there)')
 storm.Parent=nil;frames(60*3)
 check(#workspace.KeyboardTrackVisuals.Ground:GetChildren()==0,'a floor part that streams out takes its arena copy with it')
 local fresh=R.new('Part');fresh.Name='BiomeGround_7';fresh.Size=storm.Size;fresh.CFrame=storm.CFrame;fresh.Archivable=true;fresh.Parent=m7
 frames(1)
 check(fresh.LocalTransparencyModifier==1 and #workspace.KeyboardTrackVisuals.Ground:GetChildren()==1,'a floor part that streams in again is hidden at once (and its arena copy made)')
 scS.Destroying:Fire();frames(2)
 check(fresh.LocalTransparencyModifier==0,'teardown restores it too')
 fresh:Destroy();storm.Parent=m7
end
-- 11b. R149 review part 1 (finding 15): the script's connection list does not grow with every floor part / biome model that streams back in
-- (each one used to add a ChildAdded connection that stayed in the list after it was disconnected). The list is found by watching table.insert.
do
 local realTable=table;local captured={}
 local proxy=setmetatable({insert=function(t,...)local v=select(select('#',...),...);if type(v)=='table'and v.Connected~=nil and v._f then captured[t]=true end;return realTable.insert(t,...)end},{__index=realTable})
 local saved=W.env.table;W.env.table=proxy
 local scC=R.new('LocalScript');scC.Name='KeyboardTrack';W.load('KeyboardTrackClient',scC)
 put(cx(11),nil,cz(BR));frames(30)
 local conns,best=nil,0;for t in pairs(captured)do if #t>best then best=#t;conns=t end end
 check(conns~=nil and best>=5,'(found the script\'s connection list: '..best..' connections)')
 local base=conns and #conns or 0
 local storm=floors[7];local m7=storm.Parent
 for _=1,15 do
  local fresh=R.new('Part');fresh.Name='BiomeGround_7';fresh.Size=storm.Size;fresh.CFrame=storm.CFrame;fresh.Archivable=true;fresh.Parent=m7
  frames(1);local late=R.new('Decal');late.Name='Late';late.Parent=fresh
  fresh.Parent=nil;frames(60*2+20)
 end
 local grown=conns and #conns or 0
 check(grown<=base,('15 floor parts that streamed in and out: the connection list has %d entries (%d before)'):format(grown,base))
 -- a whole biome model that streams out and comes back as a new instance
 for n=1,10 do
  local m=R.new('Model');m.Name='Biome'..(10+n);m.Parent=biomesF;frames(1)
  local part=R.new('Part');part.Name='BiomeGround_9';part.Size=V3(180,4,100);part.CFrame=CF(0,2,6500);part.Parent=m;frames(1)
  m.Parent=nil;frames(60*2+20)
 end
 check(conns and #conns<=base,('...and 10 biome models that streamed in and out: %d entries'):format(conns and #conns or -1))
 -- teardown disconnects what is left
 scC.Destroying:Fire();frames(2)
 local live=0;for _,c in ipairs(conns or{})do if c.Connected then live+=1 end end
 check(live==0 and workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'teardown leaves no connection of the keyboard connected')
 W.env.table=saved
end
-- 12. no template: plain blocks, still works; columns on RunnerMotion.TrackCenterX
template.Parent=nil
RS:FindFirstChild('RunnerMotion'):SetAttribute('TrackCenterX',12)
local sc2=R.new('LocalScript');sc2.Name='KeyboardTrack'
check(pcall(W.load,'KeyboardTrackClient',sc2),'loads without the R142Keycap template')
put(cx(11)+12,nil,cz(BR));hum.FloorMaterial=PLASTIC;frames(60)
local vis2=workspace:FindFirstChild('KeyboardTrackVisuals');local k2=vis2 and vis2:FindFirstChild('Keys')
local nk=0;local allParts=true;for _,p in ipairs(k2:GetChildren())do if p.Name=='Key'and p.Transparency==0 then nk+=1;if p._class~='Part'or not near(p.Size.X,KW)then allParts=false end end end
check(k2 and nk>2500 and allParts,'without the template every key is the same plain block ('..nk..')')
local shifted=false;for _,p in ipairs(k2:GetChildren())do if p.Name=='Key'and p.Transparency==0 and near(p.CFrame.Position.X,12+g.ColCenter(5),.01)then shifted=true end end
local bed2=nil;for _,p in ipairs(vis2:FindFirstChild('Bed'):GetChildren())do if p.Name=='Bed'then bed2=p;break end end
check(shifted and bed2 and near(bed2.CFrame.Position.X,12),'the columns and the bed are centred on RunnerMotion.TrackCenterX (12)')
RS:FindFirstChild('RunnerMotion'):SetAttribute('TrackCenterX',nil)
sc2.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'teardown again')
-- 12b. the mesh can be switched off (Config.UseKeycapMesh = false): every key a plain block of the same size and colours
do
 template.Parent=RS;C.UseKeycapMesh=false
 local scM=R.new('LocalScript');scM.Name='KeyboardTrack';W.load('KeyboardTrackClient',scM)
 put(cx(11),nil,cz(BR));frames(60)
 local visM=workspace:FindFirstChild('KeyboardTrackVisuals');local plainM,meshM=0,0
 for _,p in ipairs(visM.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then if p._class=='Part'and near(p.Size.X,KW)and near(p.Size.Y,C.KeyY)then plainM+=1 else meshM+=1 end end end
 check(plainM>2500 and meshM==0,'UseKeycapMesh = false: every key is the same plain block ('..plainM..'), the template is not used')
 -- R151: the block keys' letters too: a block's top is exactly the configured top, every key of the bound rows has its label over it
 hum.FloorMaterial=AIR;frames(30)
 labelAudit(visM.Legends,visM.Keys,0,'UseKeycapMesh = false (plain blocks)')
 check(visM:GetAttribute('KeyTopExtra')==0 and visM:FindFirstChild('KeyProbe')==nil,'plain blocks: no mesh to measure, no probe, KeyTopExtra 0')
 hum.FloorMaterial=PLASTIC
 scM.Destroying:Fire();frames(2);C.UseKeycapMesh=true;template.Parent=nil
end
-- 12c. R151: a keycap mesh whose VISIBLE top stands higher than the configured key top (domed / taller than Size says). A probe key (a clone of the template, parked
-- far off the track, queryable only for the instant of the rays) measures it; the letter strips and the per-key letters follow, so no letter can end up inside a keycap.
do
 template.Parent=RS
 local sawQueryable,casts=false,0
 local function scenario(name,want,frames_,setup,afterCheck)
  setup()
  local scT=R.new('LocalScript');scT.Name='KeyboardTrack';W.load('KeyboardTrackClient',scT)
  hum.FloorMaterial=AIR;put(cx(11),nil,cz(BR));frames(frames_)
  local visT=workspace:FindFirstChild('KeyboardTrackVisuals')
  check(visT~=nil and near(visT:GetAttribute('KeyTopExtra')or-1,want,1e-9)and near(visT:GetAttribute('LegendTop')or-1,K.KeyTop(0)+(visT.Keys:FindFirstChild('Key')and visT.Keys.Key._class=='MeshPart'and C.TopOffset or 0)+want+LT.Margin,1e-9),('%s: the measured excess is %.2f (KeyTopExtra %s, LegendTop %s)'):format(name,want,tostring(visT and visT:GetAttribute('KeyTopExtra')),tostring(visT and visT:GetAttribute('LegendTop'))))
  check(visT:FindFirstChild('KeyProbe')==nil,name..': the probe key is gone once measured')
  labelAudit(visT.Legends,visT.Keys,want,name)
  if afterCheck then afterCheck(visT)end
  scT.Destroying:Fire();frames(2)
  workspace.Raycast=nil
  for _,d in ipairs(template:GetChildren())do if d._class=='SpecialMesh'then d:Destroy()end end
 end
 local function dome(extraCentre,extraEdge,instanceOverride)
  return function(_,origin,dir,params)
   casts+=1
   local probe=params.FilterDescendantsInstances[1]
   if probe.CanQuery==true then sawQueryable=true end
   local pos=probe.CFrame.Position
   local topCfg=pos.Y+probe.Size.Y/2
   local centre=abs(origin.X-pos.X)<1e-6 and abs(origin.Z-pos.Z)<1e-6
   return{Instance=instanceOverride or probe,Position=V3(origin.X,topCfg+(centre and extraCentre or extraEdge),origin.Z)}
  end
 end
 scenario('domed mesh (rays hit .3 above the configured top in the middle, .1 at the edges)',.3,90,function()workspace.Raycast=dome(.3,.1)end,function(visT)
  check(sawQueryable and casts>=9,'the probe was queryable while it was cast at ('..casts..' rays: centre, edge middles, corners)')
  -- a pressed key's own letter is offset toward the camera by the same amount, so it clears the mesh too
  hum.FloorMaterial=PLASTIC;put(cx(9),nil,cz(BR));frames(10)
  local kp=nil;for _,p in ipairs(visT.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then local pos=p.CFrame.Position;if g.RowOfZ(pos.Z)==BR and g.ColOfX(pos.X)==9 then kp=p end end end
  local kg=kp and kp:FindFirstChildWhichIsA('SurfaceGui')
  check(kg and near(kg.ZOffset,.3+LT.Margin,1e-9),'a pressed key\'s own letter is drawn .35 toward the camera (ZOffset), clearing the taller mesh ('..tostring(kg and kg.ZOffset)..')')
  hum.FloorMaterial=AIR;put(cx(11),nil,cz(BR));frames(20)
  local tops={};for _,st in ipairs(visT.Legends:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 then tops[#tops+1]=st.CFrame.Position.Y+st.Size.Y/2 end end
  local minTop=1e9;for _,y in ipairs(tops)do minTop=min(minTop,y)end
  check(#tops>=30 and near(minTop,K.KeyTop(0)+.3+LT.Margin,1e-6),'...and every strip stands .3 + .05 above the configured resting top ('..string.format('%.3f',minTop-K.KeyTop(0))..')')
 end)
 scenario('a ray that answers with something else (not the probe)',0,60*4,function()workspace.Raycast=dome(.3,.3,workspace)end)
 scenario('an absurd hit 4 studs up is capped at Legend.MaxExtra',1.5,90,function()workspace.Raycast=dome(4,4)end)
 scenario('a rays-only failure (the cast throws)',0,60*4,function()workspace.Raycast=function()error('injected: raycast failed')end end)
 scenario('a SpecialMesh offset .25 on the template, no raycast API',.25,90,function()
  workspace.Raycast=nil
  local sm=R.new('SpecialMesh');sm.Name='Mesh';sm.MeshType=R.Enum.MeshType.FileMesh;sm.Offset=V3(0,.25,0);sm.Scale=V3(1,1,1);sm.Parent=template
 end)
 scenario('a mesh whose top is the configured one, no raycast API',0,45,function()workspace.Raycast=nil end)
 scenario('TopOffset tuned to .1 in Studio (the mesh keys stand .1 higher), no raycast API',0,45,function()workspace.Raycast=nil;C.TopOffset=.1 end,function()C.TopOffset=0 end)
 template.Parent=nil
end
-- 13. the keycap template is still loading: plain blocks meanwhile, swapped in place for keycaps when it arrives (no gap)
do
 local origWait=R.Inst.WaitForChild;local resume=nil
 R.Inst.WaitForChild=function(self,n,t)if n=='R142Keycap'then resume=coroutine.running();coroutine.yield();return template end;return origWait(self,n,t)end
 local scL=R.new('LocalScript');scL.Name='KeyboardTrack'
 check(pcall(W.load,'KeyboardTrackClient',scL),'loads while the keycap template is still replicating')
 put(cx(11),nil,cz(BR));hum.FloorMaterial=AIR;frames(60)
 local visL=workspace:FindFirstChild('KeyboardTrackVisuals')
 local plain,mesh=0,0;for _,p in ipairs(visL.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then if p._class=='MeshPart'then mesh+=1 else plain+=1 end end end
 check(mesh==0 and plain>2500,'no keycaps yet: plain blocks cover the window meanwhile ('..plain..')')
 template.Parent=RS
 if resume then coroutine.resume(resume)end
 local gapFree=true
 for f=1,30 do frames(1);local idx=keyIndex and nil
  local cnt={};for _,p in ipairs(visL.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then local pos=p.CFrame.Position;local k=g.RowOfZ(pos.Z)*64+g.ColOfX(pos.X);cnt[k]=(cnt[k]or 0)+1 end end
  local fr=g.RowOfZ(cz(BR));for r=fr-3,fr+40 do if not g.BarOfRow[r]then for c=1,22 do if cnt[r*64+c]~=1 then gapFree=false end end end end
 end
 plain,mesh=0,0;for _,p in ipairs(visL.Keys:GetChildren())do if p.Name=='Key'then if p._class=='MeshPart'then mesh+=1 else plain+=1 end end end
 check(plain==0 and mesh>2500,'once it arrives every key becomes the keycap ('..mesh..' keycaps, '..plain..' blocks left)')
 check(gapFree,'...swapped in place: no key missing or doubled during the swap')
 scL.Destroying:Fire();frames(2)
 R.Inst.WaitForChild=origWait
end
-- 13b. R149 review part 1 (finding 11): a template that stops cloning after it was accepted must not make swapPass create and destroy a Part
-- every frame for ever: the keys stay plain blocks, one warning, nothing retried.
do
 template.Parent=nil
 local origWait=R.Inst.WaitForChild;local resume=nil
 R.Inst.WaitForChild=function(self,n,t)if n=='R142Keycap'then resume=coroutine.running();coroutine.yield();return template end;return origWait(self,n,t)end
 local scF=R.new('LocalScript');scF.Name='KeyboardTrack'
 W.load('KeyboardTrackClient',scF)
 put(cx(11),nil,cz(BR));hum.FloorMaterial=AIR;frames(60)
 local visF=workspace:FindFirstChild('KeyboardTrackVisuals')
 template.Parent=RS
 local cloneBroken=false;local origClone=R.Inst.Clone
 R.Inst.Clone=function(self,...)if cloneBroken and self._class=='MeshPart'then error('injected: Archivable is off')end;return origClone(self,...)end
 if resume then coroutine.resume(resume)end -- accepted: one clone is made and stripped
 cloneBroken=true                            -- from now on every clone of the keycap fails
 local warns0=W.warns or 0;local created0=#R.created
 frames(1);local firstGrowth=#R.created-created0
 frames(40)
 local grown=#R.created-created0
 local plain,mesh=0,0;for _,p in ipairs(visF.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then if p._class=='MeshPart'then mesh+=1 else plain+=1 end end end
 check(grown<=1,('a template that stops cloning: no Part is created and destroyed again every frame (%d instances in 41 frames, %d in the first)'):format(grown,firstGrowth))
 check((W.warns or 0)==warns0+1,'...it is reported once ('..((W.warns or 0)-warns0)..' warnings)')
 check(mesh==0 and plain>2500,'...the keys stay plain blocks ('..plain..'), none is missing')
 -- the keys still press and the window still moves with plain blocks only
 hum.FloorMaterial=PLASTIC;put(cx(11),nil,cz(BR+300));frames(40)
 local plain2=0;for _,p in ipairs(visF.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then plain2+=1 end end
 check(plain2>2500 and #R.created-created0<=4000,'...and the window keeps following the runner with plain blocks ('..plain2..' keys)')
 R.Inst.Clone=origClone;R.Inst.WaitForChild=origWait
 scF.Destroying:Fire();frames(2)
 template.Parent=nil
end
-- 14. a map that describes only its first biome: built after a short wait
template.Parent=RS
for n=2,7 do map:SetAttribute('BiomeStartZ_'..n,nil);map:SetAttribute('BiomeEndZ_'..n,nil)end
local sc3=R.new('LocalScript');sc3.Name='KeyboardTrack'
check(pcall(W.load,'KeyboardTrackClient',sc3),'loads on a partly described map')
put(cx(11),nil,cz(BR));frames(60);check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil,'...it waits for the other biomes (1 s so far)')
R.advance(2);frames(60)
local vis3=workspace:FindFirstChild('KeyboardTrackVisuals')
local n3=0;if vis3 then for _,p in ipairs(vis3.Keys:GetChildren())do if p.Name=='Key'and p.Transparency==0 then n3+=1 end end end
check(vis3~=nil and n3>=500,'...and builds after the wait with what the map has ('..n3..' keys)')
local wides=0;for _,p in ipairs(vis3.Keys:GetChildren())do if p.Name=='Spacebar'then wides+=1 end end
check(wides==1,'a one-biome map has one spacebar ('..wides..')')
sc3.Destroying:Fire();frames(2)
check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil and floors[1].LocalTransparencyModifier==0,'and tears down (floor shown again)')

-- 15. R149 review part 1 (finding 9): start() hid the real floor before the rest was built, so an error later left an invisible floor and no
-- keys for the session. Now the floor is hidden at the very end (everything that can fail is above it) and any failure (start-up, or three
-- frames in a row) gives the floor back, removes what was made and is not retried.
do
 for k,v in pairs(ATTR)do map:SetAttribute(k,v)end
 template.Parent=RS
 local function allShown()for _,fp in ipairs(floors)do if fp.LocalTransparencyModifier~=0 then return false end end;return true end
 local function clean(label)
  check(allShown(),label..': the real floor is visible')
  check(workspace:FindFirstChild('KeyboardTrackVisuals')==nil and W.rsBound['KeyboardCameraFloor']==nil,label..': the keyboard folder and the camera clamp are gone')
 end
 -- (a) an error before anything is hidden (the keeper scan fails)
 do
  local realGet=W.CS.GetTagged;W.CS.GetTagged=function(self,tag)if tag=='BiomeKeeper'then error('injected: keeper lookup failed')end;return realGet(self,tag)end
  local warns0=W.warns or 0;hideSeen=nil
  local scA=R.new('LocalScript');scA.Name='KeyboardTrack';check(pcall(W.load,'KeyboardTrackClient',scA),'(a) loading does not raise')
  frames(10);W.CS.GetTagged=realGet
  check(hideSeen==nil,'(a) start() failed before the floor was touched: it was never hidden')
  clean('(a) start() fails early');check((W.warns or 0)>warns0,'(a) the failure is reported')
  local c0=#R.created;map:SetAttribute('Poke',1);frames(30);check(#R.created==c0,'(a) it is not retried')
  scA.Destroying:Fire();frames(2)
 end
 -- (b) an error after the floor was hidden (connecting the frame step fails): the pcall around start() gives it back
 do
  local sig=W.Run.RenderStepped;local realConnect=sig.Connect
  sig.Connect=function()error('injected: connect failed')end
  hideSeen=nil;local warns0=W.warns or 0
  local scB=R.new('LocalScript');scB.Name='KeyboardTrack';check(pcall(W.load,'KeyboardTrackClient',scB),'(b) loading does not raise')
  sig.Connect=realConnect;frames(10)
  check(hideSeen~=nil,'(b) the floor WAS hidden (the failure came after it)')
  clean('(b) start() fails after the floor was hidden');check((W.warns or 0)>warns0,'(b) the failure is reported')
  scB.Destroying:Fire();frames(2)
 end
 -- (c) the frame step fails every frame (a destroyed part, a bad value): three in a row and the keyboard gives up, the floor comes back
 do
  local warns0=W.warns or 0
  local scC2=R.new('LocalScript');scC2.Name='KeyboardTrack';W.load('KeyboardTrackClient',scC2)
  put(cx(11),nil,cz(BR));hum.FloorMaterial=AIR;frames(30)
  check(not allShown() and workspace:FindFirstChild('KeyboardTrackVisuals')~=nil,'(c) a healthy keyboard has the real floor hidden')
  hum.FloorMaterial=PLASTIC;local zw=cz(BR)
  local function walk()zw+=P*1.5;put(cx(11),nil,zw);frames(1)end
  bulkBreak=true;walk()
  check(not allShown(),'(c) one failing frame is tolerated')
  for _=1,5 do walk()end;bulkBreak=false
  clean('(c) the frame step failed three frames in a row');check((W.warns or 0)>=warns0+3,'(c) every failing frame is reported ('..((W.warns or 0)-warns0)..' warnings)')
  frames(30)
  scC2.Destroying:Fire();frames(2)
 end
 -- (d) a single failing frame in between is forgiven: the count is of frames IN A ROW
 do
  local scD=R.new('LocalScript');scD.Name='KeyboardTrack';W.load('KeyboardTrackClient',scD)
  hum.FloorMaterial=PLASTIC;put(cx(11),nil,cz(BR));frames(30);local zw=cz(BR)
  local function walk()zw+=P*1.5;put(cx(11),nil,zw);frames(1)end
  for _=1,4 do bulkBreak=true;walk();bulkBreak=false;walk();walk();walk()end
  check(not allShown()and workspace:FindFirstChild('KeyboardTrackVisuals')~=nil,'(d) failing frames that are not three in a row do not stop the keyboard')
  scD.Destroying:Fire();frames(2)
  check(allShown(),'(d) teardown shows the floor')
 end
end

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
