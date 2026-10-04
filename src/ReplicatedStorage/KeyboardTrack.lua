-- R148 (owner playtest of R147): the candy keyboard runway covers the whole track floor, edge to edge, the way the reference game
-- ("+1 Speed Keyboard Escape (Candy & Chocolate)") looks: small, tightly packed keys with a letter on each near key, one colour family
-- per biome in a few shades picked per key. Pure config + grid maths for the client script KeyboardTrack.client.lua: no instances, no
-- Roblox services, no randomness (every colour, letter and cell is a function of the grid position, so every client builds the same).
--
--  GRID  pitch 3 (see Config.Pitch), 60 columns across the 180-wide floor (x = centre +-90), column 1 on the +X edge so that a runner
--        heading +Z (+X is on his LEFT) reads the keys left -> right: Q W E R T Y ... Rows run from the first biome's start to
--        BiomeTrackEndZ - 120 (The Darkened's arena keeps its ground). Every biome has its own grid origin: its first rows start exactly on
--        its BiomeStartZ_n (a biome's row pitch is its length / whole rows, about 3), and its first SpaceRows rows are one cream spacebar.
--  LOD   the client draws the grid in layers around the runner: near keycap MeshParts (legend, press, click), then plain block keys at
--        the same pitch, then plain blocks covering 2x2, 4x4, 8x8 and 16x16 keys (same zone colours, gaps scale with the block). Layers are
--        rectangles; a layer leaves out the cells the finer layer covers, aligned to its own cell boundaries (K.Hierarchy / K.Windows).
local K={Version=148}
local floor,ceil,max,min=math.floor,math.ceil,math.max,math.min
local C3=Color3.fromRGB

K.Config={
 Pitch=3,Gap=.28,FieldWidth=180,CenterX=0,
 EndMargin=120,DefaultEndZ=1445,DefaultStartZ=-100,
 SpaceRows=3,                                       -- a biome's spacebar is this many rows deep (a bigger label)
 KeyY=1.3,BlockY=.6,                                -- keycap mesh height (template proportions) / plain block thickness
 FloorTop=4.0,RestRise=.45,PressedRise=.1,          -- key top above the floor: resting / pressed
 TopOffset=0,                                       -- studs added to a mesh key's centre height (mesh top alignment fudge, tune in Studio)
 PressSeconds=.06,ReleaseSeconds=.14,               -- quad-out down, back-out up
 -- The dark bed under the keys (the gaps between keys, no grass). It sits clearly above the real floor so the two never z-fight; the
 -- client lifts shovel-hole parts by the same amount (they were authored to sit a few hundredths above the floor).
 BedRise=.1,BedThickness=.4,BedMaxLength=1024,BedColor={44,27,20},
 PlayerFootprint=1.2,PlayerFeetReach=3,PlayerRootToFeet=3, -- half-size of a runner's footprint; other players press while their feet (root - 3) are within 3 studs of the floor
 HoleReach=2,                                       -- keys within this many studs of a shovel hole's Pit hide while it exists
 PlatformClearance=.5,                              -- pack platforms: keys within the platform radius + this are left out (fine layers only)
 KeeperMinFootprint=1.5,KeeperMaxFootprint=6,KeeperFootprintShare=.3,
 PlayerSampleHz=30,KeeperPitch=.7,
 OwnClicksPerSecond=12,OtherClicksPerSecond=8,OtherClickRange=90,
 ClickSoundIds={113108830240353,88838553648526,96591611478915},
 ClickPitches={.96,1.01,.99,1.05,.97,1.03,1.0,1.06,.98,1.04},   -- own steps cycle through these (0.96 .. 1.06)
 ClickVolume=.8,
 TierHoldSeconds=3,                                 -- a ClientFxBudget tier change applies after it has held this long
 -- cells bound per layer per frame, times min(2, dt * 60) (a slower frame has more distance to cover). 1000 studs/s at 60 fps is ~5.6 rows per
 -- frame: 26 x 5.6 = 146 keycaps, 60 x 5.6 = 336 plain keys, 30 x 2.8 = 84 of the 2x2 blocks.
 MaxReassignPerFrame={mesh=160,plain=360,coarse=120},
 GateStallFrames=150,                               -- a cell kept only to avoid a gap is released anyway after this many frames
 LayerDrop=.03,                                     -- each coarser layer's tops sit this much lower, so a finer block always wins an overlap
 MaxLegendChangesPerFrame=64,
}
local C=K.Config
K.StageCount=7
-- Stable stage ids (not track order): Forest 1, Desert 2, Snow 3, Lava 4, Crystal 5, Jungle 6, Storm Peaks 7.
-- The map may override a name with a BiomeName_<id> attribute.
K.BiomeNames={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm Peaks'}
-- One colour family per biome, four shades; a key's shade is a hash of its cell (never a per-row cycle). Ink = legend colour.
K.Zones={
 [1]={Name='Forest',Family='mint',Shades={{176,244,218},{112,224,186},{72,198,158},{140,232,202}},Ink={34,86,66}},
 [6]={Name='Jungle',Family='pistachio',Shades={{200,238,130},{154,214,92},{218,244,160},{112,186,72}},Ink={54,86,26}},
 [2]={Name='Desert',Family='caramel',Shades={{240,180,112},{255,208,160},{208,142,80},{248,192,132}},Ink={96,54,24}},
 [3]={Name='Snow',Family='vanilla',Shades={{255,240,200},{205,230,255},{236,244,255},{184,214,244}},Ink={84,76,96}},
 [4]={Name='Lava',Family='strawberry',Shades={{255,120,150},{232,72,104},{255,150,170},{196,48,84}},Ink={255,238,230}},
 [5]={Name='Crystal',Family='pink-purple',Shades={{255,160,228},{184,136,255},{226,120,246},{246,180,255}},Ink={84,40,110}},
 [7]={Name='Storm Peaks',Family='chocolate',Shades={{104,64,46},{130,84,58},{84,52,36},{150,100,70}},Ink={252,236,214}},
}
K.Fallback={Name='Track',Family='cream',Shades={{255,214,180},{255,226,200},{240,198,166},{250,208,176}},Ink={84,48,33}}
K.Cream={255,250,236}                                -- the spacebar
K.CreamInk={84,48,33}
-- Legend rows: a runner reads each row left -> right in keyboard order (the string repeats across the 40 columns).
K.LegendRows={'QWERTYUIOP','ASDFGHJKL','ZXCVBNM','1234567890'}
K.JitterAmount=.04

-- Easing (t in 0..1 -> 0..1; BackOut overshoots, then settles at 1).
K.Ease={
 Linear=function(t)return t end,
 QuadOut=function(t)return 1-(1-t)*(1-t)end,
 BackOut=function(t)local c1=1.70158;local c3=c1+1;local u=t-1;return 1+c3*u*u*u+c1*u*u end,
}

-- Level of detail per ClientFxBudget tier (3 best .. 1 lowest). Layers run finest -> coarsest. M = how many keys a block spans (1, 2,
-- 4, 8, 16). Cols = columns of that layer's cells (full width = 40 / M); Back / Ahead = cells (rows of that layer) behind / ahead of the
-- runner, the runner's own cell counting as Ahead. Mesh = near keycap MeshParts (press, legend); Legends = lit SurfaceGuis within
-- LegendRadius; Plain = all block parts together. The caps are asserted by the tests over every position of the track.
K.Tiers={
 [3]={Mesh=700,Legends=150,Plain=2500,LegendRadius=20,Layers={
  {M=1, Kind='mesh', Cols=26,Back=9, Ahead=17},
  {M=1, Kind='plain',Cols=56,Back=10,Ahead=19},
  {M=2, Kind='plain',Cols=30,Back=9, Ahead=17},
  {M=4, Kind='plain',Cols=15,Back=10,Ahead=20},
  {M=8, Kind='plain',Cols=8, Back=14,Ahead=24},
  {M=16,Kind='plain',Cols=4, Back=20,Ahead=48}}},
 [2]={Mesh=450,Legends=100,Plain=1500,LegendRadius=16.5,Layers={
  {M=1, Kind='mesh', Cols=20,Back=7, Ahead=14},
  {M=1, Kind='plain',Cols=36,Back=8, Ahead=14},
  {M=2, Kind='plain',Cols=30,Back=6, Ahead=11},
  {M=4, Kind='plain',Cols=15,Back=8, Ahead=14},
  {M=8, Kind='plain',Cols=8, Back=10,Ahead=18},
  {M=16,Kind='plain',Cols=4, Back=14,Ahead=34}}},
 [1]={Mesh=250,Legends=60,Plain=800,LegendRadius=12.5,Layers={
  {M=1, Kind='mesh', Cols=14,Back=5, Ahead=11},
  {M=1, Kind='plain',Cols=20,Back=4, Ahead=10},
  {M=2, Kind='plain',Cols=30,Back=4, Ahead=6},
  {M=4, Kind='plain',Cols=15,Back=5, Ahead=9},
  {M=8, Kind='plain',Cols=8, Back=7, Ahead=12},
  {M=16,Kind='plain',Cols=4, Back=8, Ahead=22}}},
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

-- Zone of a stage id; shade index 1..4 of a block (stage, first row, first column, M) - a hash of the cell, never the row alone.
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
-- Legend ink for a key colour: the zone's ink (dark chocolate on light zones, cream on dark ones).
function K.InkRGB(stage)local z=K.Zone(stage);return z.Ink[1],z.Ink[2],z.Ink[3]end
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

-- Key heights: depth 0 = resting, 1 = pressed (BackOut may dip below 0 for a moment = the key springs past rest).
function K.KeyTop(depth)return C.FloorTop+C.RestRise-(C.RestRise-C.PressedRise)*depth end
function K.KeyCenterY(depth)return K.KeyTop(depth)-C.KeyY/2+C.TopOffset end
-- Plain blocks of layer i (2 = the plain keys at the keycap pitch, 3 .. 6 = 2x2 .. 16x16 blocks): finer layers sit a touch higher.
function K.BlockTop(layer)return C.FloorTop+C.RestRise-C.LayerDrop*((layer or 2)-1)end
function K.BlockCenterY(layer)return K.BlockTop(layer)-C.BlockY/2 end
function K.KeySize()return C.Pitch-C.Gap end
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

-- Geometry(attrs, centerX, fieldWidth): the whole grid for this map. Fields: Pitch, Cols, HalfWidth, CenterX, Z0 (start of the first
-- biome), KeyEndZ (BiomeTrackEndZ - 120), Rows (all fine rows, spacebars included), Segs (one per biome, sorted by start: {Id, Name,
-- StartZ, EndZ, Rows, FirstRow, LastRow, RowPitch, SpaceLast, KeyFirst}), RowSeg[row], RowStage[row], Bars (one spacebar per biome:
-- {Seg, Stage, Name, Row0, Row1, Z0, Z1}), BarOfRow[row]. Helpers (call with a dot): ColCenter(col), ColOfX(x), RowZ(row) -> zmin,zmax,
-- RowOfZ(z), CellCenter(row,col) -> x,z, CellRange(xmin,xmax,zmin,zmax) -> c1,c2,r1,r2 (no allocation; empty when c1>c2 or r1>r2),
-- CellsInRect(...) -> list of {row=,col=}, BiomeAt(z).
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
 local P=C.Pitch;local cols=max(1,floor(fieldWidth/P+.5));local half=cols*P/2
 local z0=#stages>0 and stages[1].StartZ or C.DefaultStartZ
 local keyEnd=endZ-C.EndMargin
 local g={Pitch=P,Cols=cols,HalfWidth=half,CenterX=centerX,Z0=z0,EndZ=endZ,KeyEndZ=keyEnd,Segs={},RowSeg={},RowStage={},Bars={},BarOfRow={}}
 local rows=0
 if #stages==0 then stages[1]={Id=0,StartZ=z0,EndZ=endZ,Name='Track'}end
 for i,s in ipairs(stages)do
  local a=s.StartZ;local b=stages[i+1]and stages[i+1].StartZ or keyEnd;b=min(b,keyEnd)
  if b-a>=P*(C.SpaceRows+1)then
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
 function g.ColOfX(x)return floor((left-x)/P)+1 end
 function g.RowZ(row)
  local s=segs[g.RowSeg[row]];if not s then return nil end
  local a=s.StartZ+(row-s.FirstRow)*s.RowPitch;return a,a+s.RowPitch
 end
 function g.RowOfZ(z)
  if rows==0 or z<z0 then return 0 end
  for i=1,#segs do local s=segs[i];if z<s.EndZ then return s.FirstRow+floor((z-s.StartZ)/s.RowPitch)end end
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
  local c1=floor((left-xmax)/P)+1;local c2=xmax>xmin and ceil((left-xmin)/P)or c1
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

-- Hierarchy(geo): the key rows (spacebars excluded) grouped for each LOD layer. Level M (1, 2, 4, 8, 16) cuts every biome's key rows into
-- groups of M consecutive rows (the last may be shorter); a group of level 2M is exactly two consecutive groups of level M (so every
-- coarse boundary is also a fine boundary). H[M] = {Count, R0[g], R1[g] (first / last fine row), Seg[g]}, H.Ord[M][row] = the group of
-- a fine row (nil for spacebar rows). Groups are numbered in track order, 1 .. Count.
function K.Hierarchy(geo)
 local H={Levels={1,2,4,8,16},Ord={}}
 local level16={}
 for si,s in ipairs(geo.Segs)do
  local r=s.KeyFirst
  while r<=s.LastRow do local r1=min(s.LastRow,r+15);level16[#level16+1]={r,r1,si};r=r1+1 end
 end
 local cur=level16
 local list={[16]=level16}
 for _,m in ipairs({8,4,2,1})do
  local nextList={}
  for _,gr in ipairs(cur)do
   local r0,r1=gr[1],gr[2]
   nextList[#nextList+1]={r0,min(r1,r0+m-1),gr[3]}
   if r0+m<=r1 then nextList[#nextList+1]={r0+m,r1,gr[3]}end
  end
  list[m]=nextList;cur=nextList
 end
 for _,m in ipairs(H.Levels)do
  local lv={M=m,Count=#list[m],R0={},R1={},Seg={}};local ord={}
  for i,gr in ipairs(list[m])do
   lv.R0[i]=gr[1];lv.R1[i]=gr[2];lv.Seg[i]=gr[3]
   for r=gr[1],gr[2]do ord[r]=i end
  end
  H[m]=lv;H.Ord[m]=ord
 end
 return H
end

-- The ordinal of the group at level m nearest a fine row (a spacebar row maps to the next key row, outside the track to the ends).
function K.NearestOrd(H,m,row)
 local lv=H[m];if lv.Count==0 then return 0 end
 local ord=H.Ord[m]
 if row<=lv.R0[1]then return 1 end
 if row>=lv.R1[lv.Count]then return lv.Count end
 local o=ord[row]
 if o then return o end
 for d=1,C.SpaceRows+2 do o=ord[row+d];if o then return o end end
 return lv.Count
end

-- Windows(geo, H, tier, focusRow, focusCol): the LOD rectangles around a focus. One entry per layer (finest first):
-- {M, Kind, A, B, CA, CB (group / column ranges of that layer, empty when A>B), Hole = {A, B, CA, CB} in this layer's units or nil}.
-- Each layer's window is snapped to the cell boundaries of the next coarser layer, so a coarse cell is either wholly drawn by the
-- finer layer or not at all (no overlap, no sliver).
function K.Windows(geo,H,tier,focusRow,focusCol,out)
 local plan=K.Tier(tier).Layers;local n=#plan
 out=out or {}
 local cols=geo.Cols
 for j=1,n do
  local pl=plan[j];local m=pl.M;local lv=H[m];local ncols=(cols+m-1)//m
  local w=out[j];if not w then w={};out[j]=w end
  w.M=m;w.Kind=pl.Kind;w.Hole=w.Hole or{};w.HasHole=false
  local center=K.NearestOrd(H,m,focusRow)
  local a=max(1,center-pl.Back);local b=min(lv.Count,center+pl.Ahead-1)
  local fc=(max(1,min(cols,focusCol))-1)//m+1
  local ca=max(1,fc-(pl.Cols-1)//2);local cb=min(ncols,ca+min(pl.Cols,ncols)-1);ca=max(1,cb-min(pl.Cols,ncols)+1)
  local nextM=plan[j+1]and plan[j+1].M or m
  if nextM>m and b>=a then
   local cl=H[nextM];local o=H.Ord[nextM]
   a=H.Ord[m][cl.R0[o[lv.R0[a]]]];b=H.Ord[m][cl.R1[o[lv.R1[b]]]]
   local r=nextM//m
   ca=((ca-1)//r)*r+1;cb=min(ncols,((cb-1)//r+1)*r)
  end
  w.A,w.B,w.CA,w.CB=a,b,ca,cb
  w.Cols=ncols
 end
 -- a finer window never reaches outside the next coarser one (coarse edges are fine edges, so the snapping survives)
 for j=n-1,1,-1 do
  local w,c=out[j],out[j+1]
  if c.B>=c.A and c.CB>=c.CA and w.B>=w.A then
   local m,cm=w.M,c.M
   local lo=H.Ord[m][H[cm].R0[c.A]];local hi=H.Ord[m][H[cm].R1[c.B]]
   if lo and hi then w.A=max(w.A,lo);w.B=min(w.B,hi)end
   w.CA=max(w.CA,((c.CA-1)*cm)//m+1);w.CB=min(w.CB,(min(cols,c.CB*cm)-1)//m+1)
  end
 end
 -- holes: the finer layer's window in this layer's units
 for j=2,n do
  local w,f=out[j],out[j-1]
  if f.B>=f.A and f.CB>=f.CA and w.B>=w.A then
   local fm,m=f.M,w.M;local flv=H[fm]
   local r0,r1=flv.R0[f.A],flv.R1[f.B]
   local h=w.Hole;h.A=H.Ord[m][r0];h.B=H.Ord[m][r1]
   h.CA=((f.CA-1)*fm)//m+1;h.CB=((f.CB*fm)-1)//m+1
   w.HasHole=h.A~=nil and h.B~=nil
  end
 end
 for j=n+1,#out do out[j]=nil end
 return out
end

-- Cells a window draws (rect minus hole).
function K.WindowCount(w)
 if w.B<w.A or w.CB<w.CA then return 0 end
 local total=(w.B-w.A+1)*(w.CB-w.CA+1)
 if w.HasHole then
  local h=w.Hole;local ra,rb=max(w.A,h.A),min(w.B,h.B);local ca,cb=max(w.CA,h.CA),min(w.CB,h.CB)
  if rb>=ra and cb>=ca then total-=(rb-ra+1)*(cb-ca+1)end
 end
 return total
end

-- Bed / rail segments: the track length cut into pieces of at most BedMaxLength studs.
-- Returns a list of {Z0=,Z1=,Centre=,Length=}.
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

-- Sliding-window limiter: at most `count` events in any `window` seconds (default 1).
function K.NewLimiter(count,window)
 local times={};for i=1,count do times[i]=-math.huge end
 return {N=count,Times=times,Head=1,Window=window or 1}
end
function K.Allow(limiter,now)
 local oldest=limiter.Times[limiter.Head]
 if now-oldest>=limiter.Window then
  limiter.Times[limiter.Head]=now;limiter.Head=limiter.Head%limiter.N+1
  return true
 end
 return false
end

return K
