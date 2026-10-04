-- R147 (owner): the candy keyboard runway ("+1 Speed Keyboard Escape (Candy & Chocolate)"): the biome track is one long
-- keyboard of giant candy keys that click down under the runners. Pure config + grid maths for the client script
-- KeyboardTrack.client.lua: no instances, no Roblox services, no randomness (every colour, letter and row is a function
-- of the row / column, so every client builds the same keyboard).
--  Grid: 6 columns of pitch 8 centred on RunnerMotion.TrackCenterX, rows of pitch 8 from Z0 = -96 down to BiomeTrackEndZ - 120
--  (the Darkened's arena keeps its ground). Row r covers z in [Z0 + (r-1)*8, Z0 + r*8); column c covers x in
--  [x0 + (c-1)*8, x0 + c*8) with x0 = centre - 24. The first row of every biome is one cream spacebar labelled with the biome.
local K={Version=147}
local floor,ceil,max,min=math.floor,math.ceil,math.max,math.min
local C3=Color3.fromRGB

K.Config={
 Pitch=8,Columns=6,CenterX=0,
 Z0=-96,EndMargin=120,DefaultEndZ=1445,           -- rows run Z0 .. BiomeTrackEndZ - EndMargin
 KeyX=7.5,KeyY=3.42,KeyZ=7.5,SpaceX=47.5,           -- key size from the keycap template proportions; spacebar = all six columns
 FloorTop=4.0,RestRise=.8,PressedRise=.15,         -- key top above the floor: resting / pressed
 TopOffset=0,                                       -- studs added to a key's centre height (mesh top alignment fudge, tune in Studio)
 PressSeconds=.06,ReleaseSeconds=.14,               -- quad-out down, back-out up
 -- the bed top sits just above the floor but clearly below a shovel hole's Rim (+0.06) and Pit (+0.08) tops, so the hole shows without z-fighting
 BedWidth=50,BedRise=.01,BedThickness=.3,BedMaxLength=1024,BedColor={86,52,34},
 RailColor={62,36,24},RailWidth=1.2,RailHeight=1.0,RailX=25.6,
 StripSize={47.5,.6,7.5},                           -- far rows: one thin slab per row (top = rest top)
 NearRadius={[1]=80,[2]=120,[3]=160},               -- by ClientFxBudget tier
 LegendRadius=56,MaxNear=240,TierHoldSeconds=3,   -- a ClientFxBudget tier change applies after it has held this long
 StripChunk=16,BuildRadius=1100,FreeRadius=1300,
 MaxReassignPerFrame=64,MaxStripsPerFrame=16,
 PlayerFootprint=1.6,PlayerFeetReach=3,PlayerRootToFeet=3, -- half-size of a runner's footprint; other players press while their feet (root - 3) are within 3 studs of the floor
 HoleReach=2,                                       -- keys within this many studs of a shovel hole's Pit hide while it exists
 KeeperMinFootprint=1.5,KeeperMaxFootprint=6,KeeperFootprintShare=.3,
 PlayerSampleHz=30,KeeperPitch=.7,
 OwnClicksPerSecond=12,OtherClicksPerSecond=8,OtherClickRange=90,
 ClickSoundIds={113108830240353,88838553648526,96591611478915},
 ClickPitches={.96,1.01,.99,1.05,.97,1.03,1.0,1.06,.98,1.04},   -- own steps cycle through these (0.96 .. 1.06)
 ClickVolume=.8,
}
local C=K.Config
K.StageCount=7
-- Stable stage ids (not track order): Forest 1, Desert 2, Snow 3, Lava 4, Crystal 5, Jungle 6, Storm Peaks 7.
-- The map may override a name with a BiomeName_<id> attribute.
K.BiomeNames={[1]='Forest',[2]='Desert',[3]='Snow',[4]='Lava',[5]='Crystal',[6]='Jungle',[7]='Storm Peaks'}
K.Palette={
 {Name='strawberry',RGB={255,120,165}},{Name='lemon',RGB={255,224,102}},{Name='mint',RGB={110,222,182}},
 {Name='blueberry',RGB={110,165,255}},{Name='grape',RGB={184,136,255}},{Name='orange',RGB={255,160,96}},
}
K.Cream={Name='cream',RGB={255,244,214}}
K.InkRGB={84,48,33}                                  -- chocolate legend ink
K.LegendRows={'QWERTY','ASDFGH','ZXCVBN','123456'}
K.JitterAmount=.06

-- Easing (t in 0..1 -> 0..1; BackOut overshoots, then settles at 1).
K.Ease={
 Linear=function(t)return t end,
 QuadOut=function(t)return 1-(1-t)*(1-t)end,
 BackOut=function(t)local c1=1.70158;local c3=c1+1;local u=t-1;return 1+c3*u*u*u+c1*u*u end,
}

local function rgbColor(rgb)return C3(rgb[1],rgb[2],rgb[3])end
local styles={}
-- Row look: candy colour cycling per row (offset by the biome so every biome starts on a different sweet), cream for a
-- spacebar row. Cached, read-only tables: Fill / Ink are Color3, RGB the 0-255 triple. `space` marks a spacebar row.
function K.RowStyle(row,stage,space)
 local entry,key
 if space then entry,key=K.Cream,0
 else key=(floor(row)-1+(tonumber(stage)or 0))%#K.Palette+1;entry=K.Palette[key]end
 local s=styles[key]
 if not s then s={Index=key,Name=entry.Name,RGB=entry.RGB,Fill=rgbColor(entry.RGB),Ink=rgbColor(K.InkRGB),Space=space==true};styles[key]=s end
 return s
end
-- Deterministic +-6% brightness per key (an integer hash of row and column, no randomness).
function K.Jitter(row,col)
 local h=bit32.bxor(row*73856093,col*19349663)
 h=bit32.bxor(h,bit32.rshift(h,13));h=(h*1664525+1013904223)%4294967296;h=bit32.bxor(h,bit32.rshift(h,16))
 return 1+(h/4294967295*2-1)*K.JitterAmount
end
function K.KeyRGB(style,row,col)
 local j=K.Jitter(row,col);local c=style.RGB
 return min(255,floor(c[1]*j+.5)),min(255,floor(c[2]*j+.5)),min(255,floor(c[3]*j+.5))
end
function K.KeyColor(style,row,col)local r,g,b=K.KeyRGB(style,row,col);return C3(r,g,b)end
-- The letter printed on a key (keyboard rows QWERTY / ASDFGH / ZXCVBN / 123456, cycling per row).
function K.Legend(row,col)
 local line=K.LegendRows[(floor(row)-1)%#K.LegendRows+1]
 local i=(floor(col)-1)%#line+1
 return line:sub(i,i)
end

-- Key height: depth 0 = resting, 1 = pressed (BackOut may dip below 0 for a moment = the key springs past rest).
function K.KeyTop(depth)return C.FloorTop+C.RestRise-(C.RestRise-C.PressedRise)*depth end
function K.KeyCenterY(depth)return K.KeyTop(depth)-C.KeyY/2+C.TopOffset end
-- Rows of keys kept as MeshParts at once for a ClientFxBudget tier (the window is |dz| <= NearRadius); never above MaxNear keys.
function K.NearRadiusFor(tier)return C.NearRadius[tier]or C.NearRadius[3]end
function K.NearRows(tier)
 return max(1,min(floor(C.MaxNear/C.Columns),floor(2*K.NearRadiusFor(tier)/C.Pitch)))
end
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

-- Geometry(attrs, centerX): the whole grid for this map. Fields: Z0, Rows, EndZ, CenterX, Pitch, Columns, X0 (left edge),
-- Stages (sorted by start: {Id, StartZ, EndZ, Name, FirstRow, LastRow}), RowStage[row] (stage id), SpaceRow[row] (stage record
-- of a biome's spacebar row). Helpers (call with a dot): CellCenter(row,col) -> x,z; CellRange(xmin,xmax,zmin,zmax) -> c1,c2,r1,r2
-- (no allocation; empty when c1>c2 or r1>r2); CellsInRect(...) -> list of {row=,col=}; RowOfZ(z); RowZ(row) -> zmin,zmax; BiomeAt(z).
function K.Geometry(attrs,centerX)
 attrs=type(attrs)=='table'and attrs or {}
 centerX=type(centerX)=='number'and centerX or C.CenterX
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
 local pitch,cols,z0=C.Pitch,C.Columns,C.Z0
 local rows=max(0,floor((endZ-C.EndMargin-z0)/pitch))
 local x0=centerX-cols*pitch/2
 local g={Z0=z0,Rows=rows,EndZ=endZ,CenterX=centerX,Pitch=pitch,Columns=cols,X0=x0,Stages=stages,RowStage={},SpaceRow={}}
 for _,s in ipairs(stages)do s.FirstRow=min(max(floor((s.StartZ-z0)/pitch)+1,1),max(rows,1))end
 for i,s in ipairs(stages)do
  local nextStage=stages[i+1]
  s.LastRow=nextStage and nextStage.FirstRow-1 or rows
  if rows>=1 and s.FirstRow<=rows then
   g.SpaceRow[s.FirstRow]=s
   for r=s.FirstRow,s.LastRow do g.RowStage[r]=s.Id end
  end
 end
 function g.CellCenter(row,col)return x0+(col-.5)*pitch,z0+(row-.5)*pitch end
 function g.RowOfZ(z)return floor((z-z0)/pitch)+1 end
 function g.RowZ(row)return z0+(row-1)*pitch,z0+row*pitch end
 function g.CellRange(xmin,xmax,zmin,zmax)
  if xmin~=xmin or xmax~=xmax or zmin~=zmin or zmax~=zmax then return 1,0,1,0 end
  if xmax<xmin then xmin,xmax=xmax,xmin end
  if zmax<zmin then zmin,zmax=zmax,zmin end
  -- Open intervals: a rect that only touches a cell edge does not claim the neighbour (a degenerate rect = one point).
  local c1=floor((xmin-x0)/pitch)+1;local c2=xmax>xmin and ceil((xmax-x0)/pitch)or c1
  local r1=floor((zmin-z0)/pitch)+1;local r2=zmax>zmin and ceil((zmax-z0)/pitch)or r1
  return max(c1,1),min(c2,cols),max(r1,1),min(r2,rows)
 end
 function g.CellsInRect(xmin,xmax,zmin,zmax)
  local out={};local c1,c2,r1,r2=g.CellRange(xmin,xmax,zmin,zmax)
  for r=r1,r2 do for c=c1,c2 do out[#out+1]={row=r,col=c}end end
  return out
 end
 function g.BiomeAt(z)
  for i=1,#stages do local s=stages[i];if z>=s.StartZ and z<s.EndZ then return s.Id,s.Name end end
  return 0,nil
 end
 return g
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
