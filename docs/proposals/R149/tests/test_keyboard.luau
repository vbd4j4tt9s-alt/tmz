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
check(near(K.KeyTop(0),F+.55)and near(K.KeyTop(1),F+.08)and near(K.BedTop(),F-1.6),'heights: resting tops 0.55 above the floor, pressed 0.08 above it, the grout bed 1.6 below it')
check(near(K.KeyTop(0)-K.BedTop(),2.15)and K.KeyTop(0)-K.BedTop()>=1.5 and K.KeyTop(0)-K.BedTop()<=3,'a resting key stands 2.15 studs proud of the bed (tall sides, owner: "not tall enough")')
check(K.KeyTop(0)-C.KeyY<K.BedTop()-1 and K.KeyTop(1.15)-C.KeyY<K.BedTop()-1,'a key\'s bottom stays well under the bed even pressed past its travel (its foot never shows)')
check(C.PressSeconds==.07 and C.ReleaseSeconds==.16 and near(C.HoleLift,C.RestRise+.02),'press .07 s, release .16 s; hole parts are lifted onto the resting key tops (+.02)')
check(C.ClickSoundId==113108830240353 and C.ClickSoundIds[1]==C.ClickSoundId and near(C.ClickGap,1/12)and C.KeeperPitch>=.9 and C.KeeperPitch<1 and C.ClickVoices>=10,'clicks: one recording, at most one click per 1/12 s per presser, keepers a touch deeper (0.94), a pool of '..C.ClickVoices..' voices')
local pitchOk=#C.ClickPitches>=3;for _,p in ipairs(C.ClickPitches)do if p<.98 or p>1.02 then pitchOk=false end end
check(pitchOk,'click pitch varies only a little: 0.98 .. 1.02')
check(C.ClickRollOffMin>=10 and C.ClickRollOffMax==C.ClickRange and C.ClickVolume==.8,'one volume rule for every click: volume .8 with a 3D roll-off to the 90-stud range')
local LT=C.Legend
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
check(near(K.KeyCenterY(0),F+.55-C.KeyY/2),'KeyCenterY = resting top - half the key height')
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
for tier,want in pairs({[3]={990,3200,140},[2]={600,2000,95},[1]={370,1250,55}})do
 local t=K.Tier(tier)
 if t.Ahead*P<want[1]or K.KeyCap(tier,22)>want[2]or t.LegendAhead*P<want[3]then capOk=false end
 local ra,rb,ka,kb=K.KeyWindow(g,tier,300)
 if ra~=300-t.Back or rb~=300+t.Ahead or ka~=ra-t.Hyst or kb~=rb+t.Hyst then capOk=false end
 if K.KeyCap(tier,22)~=(t.Back+t.Ahead+1+2*t.Hyst)*22 then capOk=false end
end
check(capOk,'tiers: keys reach >= 990 / 600 / 370 studs ahead (tier 3 / 2 / 1) with at most 3200 / 2000 / 1250 keys; letters >= 140 / 95 / 55 studs ahead')
local a1,b1=K.KeyWindow(g,3,1);local a2,b2=K.KeyWindow(g,3,728);check(a1==1 and b2==728 and b1==123 and a2==716,'KeyWindow clamps to the track')
do
 local t=K.Tier(3);local ra,rb,ka,kb=K.KeyWindow(g,3,400,-1)
 check(ra==400-t.Ahead and rb==400+t.Back and ka==ra-t.Hyst and kb==rb+t.Hyst,'KeyWindow facing -Z (a runner carrying a pack back to base): the long side lies toward -Z')
 local la,lb=K.LegendWindow(g,3,400,-1);check(la==400-t.LegendAhead and lb==400+t.LegendBehind,'LegendWindow follows the facing too')
 check(K.Facing(.9,1)==1 and K.Facing(-.9,1)==-1 and K.Facing(.1,-1)==-1 and K.Facing(-.1,1)==1 and K.Facing(0/0,-1)==-1 and K.Facing(.26,-1)==1,'Facing: +-0.25 dead zone around sideways keeps the current way')
end
check(K.LegendAlpha(3,0)==0 and K.LegendAlpha(3,-2)==0 and K.LegendAlpha(3,14)==0 and K.LegendAlpha(3,15)>0 and K.LegendAlpha(3,18)<1 and K.LegendAlpha(3,19)==1,'letters fade over their last 4 rows (tier 3: solid to 14 rows ahead, gone after 18)')
local fadeUp=true;for d=14,18 do if K.LegendAlpha(3,d+1)<K.LegendAlpha(3,d)then fadeUp=false end end;check(fadeUp,'...monotonically')
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
local bulkCalls,inBulk=0,false
function workspace.BulkMoveTo(_,parts,cfs)
 bulkCalls+=1;assert(#parts==#cfs,'BulkMoveTo lists must match')
 inBulk=true;for i,p in ipairs(parts)do p.CFrame=cfs[i]end;inBulk=false
end
local plays={}
function R.Inst.Play(self)
 local anchor=self.Parent;self.Playing=true
 plays[#plays+1]={Id=self.SoundId,Speed=self.PlaybackSpeed,Volume=self.Volume,T=R.clock,Pos=anchor and anchor._props.CFrame and anchor._props.CFrame.Position,Group=self.SoundGroup,
  Min=self.RollOffMinDistance,Max=self.RollOffMaxDistance,Mode=self.RollOffMode,Sound=self}
end
function R.Inst.Stop(self)self.Playing=false end
local contentCalls=0
W.service('ContentProvider').PreloadAsync=function()contentCalls+=1 end
-- the shared mock's Clone copies an instance's tag set by reference; Roblox gives the clone its own copy of the tags
do local clone=R.Inst.Clone;R.Inst.Clone=function(self)local c=clone(self);local t=rawget(c._props,'_tags');if t then c._props._tags=table.clone(t)end;return c end end
local fxTier=3
W.stub('ClientFxBudget',{Get=function()return fxTier end,Low=function()return fxTier==1 end})
-- count writes per frame: Color on keys (= keys dressed), CFrame on keys outside BulkMoveTo
local writes={key=0};local cframeWrites=0
local origNew=R.instMeta.__newindex
R.instMeta.__newindex=function(o,k,v)
 if k=='Color'and o._props.Name=='Key'then writes.key+=1 end
 if k=='CFrame'and o._props.Name=='Key'and not inBulk then cframeWrites+=1 end
 return origNew(o,k,v)
end
local function resetWrites()writes.key=0 end

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
local vis=workspace:FindFirstChild('KeyboardTrackVisuals')
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
check(restOk,'every resting key top is at the floor + 0.55 (near and far alike)')
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
-- no z-fighting: every horizontal surface the keyboard shows is clear of the (hidden) floor plane and of every other one it touches
local planes={}
for _,p in ipairs(vis:GetDescendants())do
 if p:IsA('BasePart')and p.Transparency<1 and p.Name~='GroundPatch'then local t=floor((p.CFrame.Position.Y+p.Size.Y/2)*1000+.5)/1000;planes[t]=(planes[t]or 0)+1 end
end
local nearFloor=0;local list={};for y in pairs(planes)do list[#list+1]=y;if abs(y-F)<.015 then nearFloor+=1 end end
table.sort(list)
check(nearFloor==0 and #list>=3,'no visible keyboard surface lies within 0.015 of the floor plane (planes: '..table.concat(list,', ')..')')
check(planes[floor(K.KeyTop(0)*1000+.5)/1000]and planes[floor(K.BedTop()*1000+.5)/1000]and K.KeyTop(0)-F>=.5 and F-K.BedTop()>=1.5,'key tops 0.55 above and the bed 1.6 below the floor: nothing is coplanar with it')
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
local stripOk,orderOk,inkOk2,posOk,yOk=true,true,true,true,true
local rowsSeen={}
for _,st in ipairs(strips)do
 local gui=st:FindFirstChildWhichIsA('SurfaceGui');local pos=st.CFrame.Position
 if not gui or gui.Face~=R.Enum.NormalId.Top or gui.SizingMode~=R.Enum.SurfaceGuiSizingMode.PixelsPerStud or gui.PixelsPerStud~=LT.PixelsPerStud or st.Transparency~=1 then stripOk=false end
 if not near(pos.Y+st.Size.Y/2,K.KeyTop(0)+LT.Lift,1e-6)then yOk=false end
 local row=g.RowOfZ(pos.Z);rowsSeen[row]=(rowsSeen[row]or 0)+1
 local xMin=pos.X-st.Size.X/2
 for _,l in ipairs(gui:GetChildren())do
  if l._class=='TextLabel'and l.Visible then
   -- canvas x -> world +X, canvas y -> world +Z (Top face, up toward -Z)
   local wx=xMin+l.Position.X.Offset/LT.PixelsPerStud;local wz=pos.Z-st.Size.Z/2+l.Position.Y.Offset/LT.PixelsPerStud
   local col=g.ColOfX(wx);local x,z=g.CellCenter(row,col)
   if abs(x-wx)>1e-6 or abs(z-wz)>1e-6 then posOk=false end
   if l.Text~=K.Legend(row,col)or l.Rotation~=180 or l.AnchorPoint.X~=.5 or l.TextSize~=floor(LT.TextHeight*LT.PixelsPerStud+.5)then orderOk=false end
   local ink=K.ShadeInk(g.RowStage[row],K.ShadeIndex(g.RowStage[row],row,col,1))
   if abs(l.TextColor3.R*255-ink[1])>.5 or abs(l.TextColor3.G*255-ink[2])>.5 then inkOk2=false end
  end
 end
end
check(stripOk and yOk,'strips: invisible parts 0.03 above the resting key tops, a Top-face SurfaceGui at 16 px / stud each')
check(posOk,'every letter sits exactly on its key\'s centre')
check(orderOk,'every letter is its key\'s legend, turned 180 degrees about its centre (upright for a runner facing +Z), 4.6 studs tall')
check(inkOk2,'every letter has its key shade\'s ink')
-- a runner reads his row left -> right in keyboard order
local function lettersInRow(row)
 local out={}
 for _,st in ipairs(strips)do if g.RowOfZ(st.CFrame.Position.Z)==row then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui');local xMin=st.CFrame.Position.X-st.Size.X/2
  for _,l in ipairs(gui:GetChildren())do if l._class=='TextLabel'and l.Visible then out[#out+1]={X=xMin+l.Position.X.Offset/LT.PixelsPerStud,T=l.Text}end end
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
check(blabel and blabel.Text=='DESERT'and blabel.Rotation==180 and blabel.AnchorPoint.X==.5 and bgui.Face==R.Enum.NormalId.Top and bgui.Enabled~=false,'its label reads DESERT, Top face turned 180 degrees = upright for a runner arriving at the biome')
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
for _,o in ipairs(R.created)do if o._class=='Sound'and o._props.Name=='KeyClickSound'then voices+=1;ids[o.SoundId]=true;if o.SoundGroup~=nil then routed+=1 end end end
local nIds=0;for _ in pairs(ids)do nIds+=1 end
check(voices==C.ClickVoices and routed==voices,'a pool of '..C.ClickVoices..' click voices, routed through AudioMixer (Effects group) ('..routed..')')
check(nIds==1 and ids['rbxassetid://113108830240353'],'every voice plays the same recording (one click sound; was three alternating)')
check(contentCalls>=1,'the click is preloaded')
print(('parts: %d keys (%d dressed), %d bed / rim parts, %d letter strips (%d letters), %d ground patches, 7 spacebars'):format(keyN,#keyParts(),#bedF:GetChildren(),#strips,#strips*11,#groundF:GetChildren()))
local c0=#R.created;frames(60);check(#R.created==c0,'standing still: no instance is created frame to frame ('..(#R.created-c0)..' in 60 frames)')
end

-- 2. a runner presses a key and releases it
local R10,C20=BR,9
do
plays={};hum.FloorMaterial=PLASTIC;put(cx(C20),nil,cz(R10));frames(3)
check(topOf(R10,C20)and topOf(R10,C20)<K.KeyTop(0)-.1,'a key goes down under the runner (mid-press)')
frames(8)
check(near(topOf(R10,C20),K.KeyTop(1),1e-6),'...to the pressed height (top = floor + 0.08, got '..tostring(topOf(R10,C20))..')')
check(near(topOf(R10,C20+1),K.KeyTop(0),1e-6)and near(topOf(R10+1,C20),K.KeyTop(0),1e-6)and near(topOf(R10-1,C20),K.KeyTop(0),1e-6),'its neighbours stay up')
check(#plays==1 and plays[1].Id=='rbxassetid://113108830240353','one click played for the one key ('..#plays..')')
check(plays[1]and plays[1].Speed>=.98 and plays[1].Speed<=1.02 and plays[1].Volume==C.ClickVolume,'own click: pitch within 0.98 .. 1.02, volume .8')
check(plays[1]and plays[1].Group and plays[1].Group.Name=='GardenEffects','clicks go through the Effects sound group (AudioMixer.Route)')
check(plays[1]and near(plays[1].Pos.X,cx(C20),.01)and near(plays[1].Pos.Z,cz(R10),.01)and plays[1].Min==C.ClickRollOffMin and plays[1].Max==C.ClickRollOffMax,'the click is played at the key, with the one roll-off rule')
-- the pressed key carries its letter; the strip's label for it is hidden meanwhile
local kp=keyAt(R10,C20);local kgui=kp and kp:FindFirstChildWhichIsA('SurfaceGui');local klabel=kgui and kgui:FindFirstChildWhichIsA('TextLabel')
check(kgui and kgui.Face==R.Enum.NormalId.Top and klabel and klabel.Text==K.Legend(R10,C20)and klabel.Rotation==180 and klabel.TextSize==floor(LT.TextHeight*LT.PixelsPerStud+.5),'a key that is down carries its own letter (same size, upright) while it moves')
local function stripLabel(row,col)
 for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 and g.RowOfZ(st.CFrame.Position.Z)==row then
  local gui=st:FindFirstChildWhichIsA('SurfaceGui');local xMin=st.CFrame.Position.X-st.Size.X/2
  for _,l in ipairs(gui:GetChildren())do if l._class=='TextLabel'and l.Text~=''and g.ColOfX(xMin+l.Position.X.Offset/LT.PixelsPerStud)==col and(xMin+l.Position.X.Offset/LT.PixelsPerStud)<xMin+st.Size.X then return l end end
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
put(cx(C20)+20,nil,cz(R10));frames(14);plays={}
-- standing on a corner shared by 4 keys presses all 4 - with ONE click (owner: no stacked bursts)
local zc=select(2,g.RowZ(R10))
put(cx(C20)-P/2,nil,zc);frames(12)
local cornerDown=0;for _,cc in ipairs({C20,C20+1})do for _,rr in ipairs({R10,R10+1})do if near(topOf(rr,cc),K.KeyTop(1),1e-6)then cornerDown+=1 end end end
check(cornerDown==4 and #plays==1,'standing on a corner presses the 4 keys under the +-1.2 footprint with one click, not four stacked ('..cornerDown..' down, '..#plays..' clicks)')
put(cx(C20)+20,nil,cz(R10))
local maxTop=0
for _=1,15 do frames(1);local t=topOf(R10,C20);if t then maxTop=max(maxTop,t)end end
check(maxTop>K.KeyTop(0)+.01,'release springs a little past rest (back-out, max '..string.format('%.3f',maxTop)..')')
frames(10);check(near(topOf(R10,C20),K.KeyTop(0),1e-6),'...and settles at rest')
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
 check(ahead>=990 and behind<=12*P+4*P+P,('facing +Z: keys reach %.0f studs ahead, %.0f behind'):format(ahead,behind))
 look(0,100);frames(30);local b2,a2=reach()
 check(near(b2,behind,1e-6)and near(a2,ahead,1e-6),'looking sideways (inside the dead zone) changes nothing')
 look(-100);frames(6);local b3=reach()
 check(near(b3,behind,1e-6),'a glance back shorter than the hold (0.2 s) changes nothing')
 look(100);frames(30);look(-100)
 local over,settled=0,nil;resetWrites()
 for f=1,40 do
  resetWrites();frames(1)
  if writes.key>K.Tier(3).Bind*C.TeleportBurst then over+=1 end
  local bb,aa=reach();if not settled and bb>=990 then settled=f end
 end
 local bk,ak=reach()
 check(bk>=990 and ak<=12*P+4*P+P,('after turning round (camera toward -Z): keys reach %.0f studs toward -Z, %.0f toward +Z'):format(bk,ak))
 check(settled and settled<=0.2*60+6,'...the long side is rebuilt within ~6 frames after the 0.2 s hold ('..tostring(settled)..' frames)')
 check(over==0,'...within the turn budget per frame')
 local a,b=K.KeyWindow(g,3,g.RowOfZ(2400),-1);coverage(a,b,'facing -Z')
 local stripsZ={};for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 then stripsZ[#stripsZ+1]=st.CFrame.Position.Z end end
 local lo,hi=1e9,-1e9;for _,z in ipairs(stripsZ)do lo=min(lo,z);hi=max(hi,z)end
 check(2400-lo>=140 and hi-2400<=3*P+P,('letters follow the facing too: %.0f studs toward -Z, %.0f toward +Z'):format(2400-lo,hi-2400))
 look(100);frames(40)
 local _,aBack=reach();check(aBack>=990,'turning back to +Z restores the long side ahead')
end
-- 6. other players
do
hum.FloorMaterial=AIR
put(cx(11),F+9,cz(BR));frames(40)
local other=R.new('Player');other.Name='Pal';other.UserId=5;other.Parent=Players;others[1]=other
local ochar,oroot=makeCharacter('Pal',cx(8),cz(BR));other.Character=ochar
plays={};frames(8) -- a 30 Hz sample (up to 2 frames) + the .07 s press
check(near(topOf(BR,8),K.KeyTop(1),1e-6),'another player standing on a key presses it')
check(#plays==1 and plays[1].Speed>=.98 and plays[1].Speed<=1.02 and plays[1].Volume==C.ClickVolume,'...with one click, same recording, pitch and volume rule as your own ('..#plays..')')
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
check(#plays==1 and near(plays[1].Speed,C.KeeperPitch)and plays[1].Id=='rbxassetid://113108830240353','keeper: one click, the same recording a touch deeper (0.94)')
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
 local volOk=true;for _,o in ipairs(R.created)do if o._class=='Sound'and o._props.Name=='KeyClickSound'and(o.Volume~=C.ClickVolume or o.RollOffMinDistance~=C.ClickRollOffMin or o.RollOffMaxDistance~=C.ClickRollOffMax)then volOk=false end end
 check(volOk,'every voice keeps the same volume and roll-off (one volume-by-distance rule for every presser)')
 for i=#others,1,-1 do others[i]=nil end
 for _,r2 in ipairs(crowd)do r2.Parent:Destroy()end
 frames(30)
 local left=0;for _,p in ipairs(keyParts())do if p:FindFirstChildWhichIsA('SurfaceGui')then left+=1 end end
 check(left==0,'when they leave, every key gives its letter back to its strip ('..left..' left riding)')
end
-- 8. shovel holes: they lie on the keys (near and far); the keys under them stay up
do
local holes=R.new('Folder');holes.Name='TrackHoles';holes.Parent=runtime
local function dig(id,x,z)
 local m=R.new('Model');m.Name='TrackHole_'..id
 local pit=R.new('Part');pit.Name='Pit';pit.Size=V3(.08,3.4,3.4);pit.CFrame=CF(x,F+.04,z);pit.Parent=m
 local rim=R.new('Part');rim.Name='Rim';rim.Size=V3(.06,4,4);rim.CFrame=CF(x,F+.03,z);rim.Parent=m
 local crumb=R.new('Part');crumb.Name='Crumb';crumb.Size=V3(.3,.3,.3);crumb.CFrame=CF(x+1.9,F+.1,z);crumb.Parent=m
 m.PrimaryPart=pit;m.Parent=holes;return m,pit,rim,crumb
end
put(cx(11),nil,cz(BR));hum.FloorMaterial=PLASTIC;frames(40)
local HR,HC=BR+4,6
local hx,hzz=cx(HC),cz(HR)
local h1,pit1,rim1=dig(1,hx,hzz);frames(30)
check(keyAt(HR,HC)~=nil and near(topOf(HR,HC),K.KeyTop(0),1e-6),'a hole leaves its key in place, at rest')
check(near(pit1.CFrame.Position.Y,F+.04+C.HoleLift,1e-6)and near(rim1.CFrame.Position.Y,F+.03+C.HoleLift,1e-6),'the hole parts are lifted onto the key tops')
local rimBottom=rim1.CFrame.Position.Y-.03;local rimTop=rim1.CFrame.Position.Y+.03;local pitTop=pit1.CFrame.Position.Y+.04
check(rimBottom>=K.KeyTop(0)+.015 and rimTop-K.KeyTop(0)>=.06 and pitTop-K.KeyTop(0)>=.08,'z-fighting: the Rim / Pit tops are 0.08 / 0.10 above the key top (no shared plane)')
local sl=nil
for _,st in ipairs(legF:GetChildren())do if st.Name=='LegendStrip'and st.CFrame.Position.Y>0 and g.RowOfZ(st.CFrame.Position.Z)==HR then
 for _,l in ipairs(st:FindFirstChildWhichIsA('SurfaceGui'):GetChildren())do if l._class=='TextLabel'and g.ColOfX(st.CFrame.Position.X-st.Size.X/2+l.Position.X.Offset/LT.PixelsPerStud)==HC and l.Text==K.Legend(HR,HC)then sl=l end end end end
check(sl and sl.Visible==false,'the letter of the key under a hole is hidden (the hole covers it)')
plays={};put(hx,nil,hzz);frames(12)
check(near(topOf(HR,HC),K.KeyTop(0),1e-6)and #plays==0,'stepping on the hole does not press its key (the hole would float above a pressed key)')
local nb=keyAt(HR,HC+2);put(cx(HC+2),nil,hzz);frames(12)
check(near(topOf(HR,HC+2),K.KeyTop(1),1e-6),'the keys around it still press')
put(cx(11),nil,cz(BR));frames(14)
h1:Destroy();frames(30)
check(sl.Visible==true,'the letter comes back when the hole is filled')
put(hx,nil,hzz);frames(12);check(near(topOf(HR,HC),K.KeyTop(1),1e-6),'...and the key presses again')
put(cx(11),nil,cz(BR));frames(14)
-- the lift is per part: streamed-in parts, crumb tweens, rebuilt models
do
 local h5,pit5,rim5,crumb5=dig(5,hx,hzz);frames(2)
 check(near(crumb5.CFrame.Position.Y,F+.1+C.HoleLift,1e-6)and near(pit5.CFrame.Position.Y,F+.04+C.HoleLift,1e-6),'every part of a hole (Pit, Rim, crumbs) is lifted')
 pit5:Destroy()
 local pit5b=R.new('Part');pit5b.Name='Pit';pit5b.Size=V3(.08,3.4,3.4);pit5b.CFrame=CF(hx,F+.04,hzz);pit5b.Parent=h5
 frames(1)
 check(near(pit5b.CFrame.Position.Y,F+.04+C.HoleLift,1e-6),'a hole part that streams in again (a new instance at the server height) is lifted within a frame')
 local crumbB=R.new('Part');crumbB.Name='Crumb';crumbB.Size=V3(.3,.3,.3);crumbB.CFrame=CF(hx-1.9,F+.1,hzz);crumbB.Parent=h5;frames(1)
 check(near(crumbB.CFrame.Position.Y,F+.1+C.HoleLift,1e-6),'...also a streamed-in crumb')
 crumb5.Position=V3(hx,F+.35,hzz);frames(8)
 check(near(crumb5.CFrame.Position.Y,F+.35,1e-6),'a crumb in mid-tween is not touched')
 crumb5.Position=V3(hx+1.9,F+.1,hzz);frames(30)
 check(near(crumb5.CFrame.Position.Y,F+.1+C.HoleLift,1e-6),'a crumb the tween put back at the server height is lifted again')
 check(near(pit5b.CFrame.Position.Y,F+.04+C.HoleLift,1e-6),'parts already lifted are never lifted twice')
 h5:Destroy();frames(5)
 local h5c,pit5c=dig(6,hx,hzz);frames(1)
 check(near(pit5c.CFrame.Position.Y,F+.04+C.HoleLift,1e-6),'a rebuilt hole model is lifted')
 h5c:Destroy();frames(30)
end
-- far away (600 studs ahead): the same
local farRow=g.RowOfZ(cz(BR)+600);local farX,farZ=cx(15),cz(farRow)
local farHole,farPit=dig(3,farX,farZ);frames(30)
check(keyAt(farRow,15)~=nil and near(topOf(farRow,15),K.KeyTop(0),1e-6)and near(farPit.CFrame.Position.Y,F+.04+C.HoleLift,1e-6),'a hole 600 studs ahead lies on its key the same way (visible from afar)')
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
check(keepPitRef and near(keepPitRef.CFrame.Position.Y,F+.04,1e-6),'teardown puts a lifted shovel hole back at its server height')
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
 scM.Destroying:Fire();frames(2);C.UseKeycapMesh=true;template.Parent=nil
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

print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
