-- R156 the Desert's secret pyramid on the OWNER'S PLACE (Workspace.ChestChaseMap from his .rbxl) after the REAL start-up passes (MapService.new: the scenery passes,
-- TrackExpansion83 moving the Sunscar Pyramid to its runtime spot, then SecretPyramid156.Apply, WalkthroughProps90, the keyboard scan). This file is the TAIL of
-- the scene: run_pyramid156.sh runs it after lines 11 - 63 of R149's zfight_scene.luau (the mock world, the place, MapService.new); owner_slabs.luau is the
-- owner's Classic Pyramid read straight from docs/proposals/R156/pyramid/classic_pyramid_parts.json (his .rbxm), not from PyramidRules156.
--  1. in place     the Sunscar Pyramid is gone (no part of it left), the Classic Pyramid stands on its spot: the same centre and ground, the old 44.8 footprint
--  2. the model    every slab of his model, at the chosen scale: width (X and Z), height, the steps' heights, colour (248, 217, 109), Limestone, blocks, anchored
--  3. hollow       the chamber between the floor and the caps is empty (a 1-stud grid of points at every quarter stud of height), the walls are solid, and
--                  it is sealed: 400 rays from the pack hit a wall, the floor or a cap before they leave the pyramid
--  4. the fit      the full-size model would not fit (it would cross the left wall); the scaled one touches nothing but the ground: not the walls, the camp,
--                  the pack spots, the spawns, any prop; a 4-stud walkway stays along the wall; its edge toward the track is the old one
--  5. the zone     nothing stands in the Hold E zone (the base + 6 studs, up to the top + 6) but the floor and the Desert's wall: no prompt from inside
--                  another building
--  6. the keyboard every key the pyramid stands on is left out (none pokes through its 1.12-stud bottom step), the keys around it stay
local fails2,checks2=0,0
local function check(c,msg)checks2+=1;if not c then fails2+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,e)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(e or 1e-6)end
R.advance(1)
check(okMap and failed==0,'MapService.new ran on the owner\'s place ('..failed..' steps failed)')
local Rules=W.module('PyramidRules156');local Owner=require('./owner_slabs');local G=Rules.Geometry();local s=Rules.Scale
local lm=map:FindFirstChild('MythicLandmarks');local model=lm and lm:FindFirstChild('Biome2_Landmark')
check(model and model:GetAttribute('PyramidVersion')==156,'MythicLandmarks.Biome2_Landmark is the Classic Pyramid')
if not model then error('no pyramid: the rest cannot be checked')end

-- 1. In place --------------------------------------------------------------------------------------------------------------------------------------------------------
local OLD={PyramidTier=true,SunstoneCap=true,RecessedDoor=true,DoorPillar=true,SunInlay=true,DoorLintel=true}
local left=0;for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')and OLD[d.Name]then left+=1 end end
check(left==0,'no part of the Sunscar Pyramid is left ('..left..')')
-- the Sunscar Pyramid's bottom tier after TrackExpansion83 (read from this place: 44.8 x 3.92 x 44.8, centre X -62.0675, foot Y 4, runtime Z 1005)
local SPOT=V3(-62.0675,4,1005)
local floor=model:FindFirstChild('Slab01')
check(floor and near(floor.Position.X,SPOT.X,1e-4)and near(floor.Position.Z,SPOT.Z,1e-4)and near(floor.Position.Y-floor.Size.Y/2,SPOT.Y,1e-4),('it stands on the old spot: base centre (%.2f, %.2f), foot at %.2f'):format(floor.Position.X,floor.Position.Z,floor.Position.Y-floor.Size.Y/2))
check(near(model:GetAttribute('OldWidth'),44.8,1e-3)and near(G.Width,44.8,.01),('the old footprint measured %.2f; the new base is %.3f'):format(model:GetAttribute('OldWidth')or -1,G.Width))

-- 2. The model ----------------------------------------------------------------------------------------------------------------------------------------------------------
local parts={};local bySlab={};local anchor
for _,d in ipairs(model:GetDescendants())do if d:IsA('BasePart')then
 if d.Name==Rules.AnchorName then anchor=d else parts[#parts+1]=d;local i=d:GetAttribute('PyramidSlab');bySlab[i]=bySlab[i]or{};table.insert(bySlab[i],d)end
end end
check(#parts==60 and #Owner.Slabs==18,'60 parts for his 18 slabs')
local y1=Owner.Slabs[1].Y
local shapeOk,looksOk=true,true;local worst=0
for i,o in ipairs(Owner.Slabs)do
 local lo,hi=V3(math.huge,math.huge,math.huge),V3(-math.huge,-math.huge,-math.huge)
 for _,p in ipairs(bySlab[i]or{})do
  local a,b=p.Position-p.Size/2,p.Position+p.Size/2
  lo=V3(math.min(lo.X,a.X),math.min(lo.Y,a.Y),math.min(lo.Z,a.Z));hi=V3(math.max(hi.X,b.X),math.max(hi.Y,b.Y),math.max(hi.Z,b.Z))
  if p.ClassName~='Part'or(p.Shape~=nil and p.Shape~=R.Enum.PartType.Block)or not p.Anchored then shapeOk=false end
  local c=p.Color;if math.floor(c.R*255+.5)~=Owner.Color[1]or math.floor(c.G*255+.5)~=Owner.Color[2]or math.floor(c.B*255+.5)~=Owner.Color[3]or p.Material~=R.Enum.Material[Owner.MaterialName]or p.Transparency~=0 then looksOk=false end
 end
 local err=math.max(math.abs((hi.X-lo.X)-o.SX*s),math.abs((hi.Z-lo.Z)-o.SZ*s),math.abs((hi.Y-lo.Y)-o.SY*s),math.abs(lo.Y-(SPOT.Y+(o.Y-o.SY/2-(y1-Owner.Slabs[1].SY/2))*s)),
  math.abs((hi.X+lo.X)/2-SPOT.X),math.abs((hi.Z+lo.Z)/2-SPOT.Z))
 worst=math.max(worst,err)
end
check(worst<1e-4,('from outside every slab is his: width (X, Z), height and step height of all 18 slabs x %.4f, on one axis (worst %.1e stud)'):format(s,worst))
check(looksOk,('his colour (%d, %d, %d) and %s on every part'):format(Owner.Color[1],Owner.Color[2],Owner.Color[3],Owner.MaterialName))
check(shapeOk,'blocks (Part), anchored, like his')
check(near(G.Top,(Owner.Slabs[18].Y+Owner.Slabs[18].SY/2-(y1-Owner.Slabs[1].SY/2))*s,1e-4),('%.2f studs tall (his %.2f x %.4f)'):format(G.Top,(Owner.Slabs[18].Y+Owner.Slabs[18].SY/2-(y1-Owner.Slabs[1].SY/2)),s))

-- 3. Hollow -----------------------------------------------------------------------------------------------------------------------------------------------------------------
local boxes={};for _,p in ipairs(parts)do local h=p.Size/2;boxes[#boxes+1]={Lo=p.Position-h,Hi=p.Position+h,P=p}end
local function inside(pt,eps)for _,b in ipairs(boxes)do if pt.X>b.Lo.X+eps and pt.X<b.Hi.X-eps and pt.Y>b.Lo.Y+eps and pt.Y<b.Hi.Y-eps and pt.Z>b.Lo.Z+eps and pt.Z<b.Hi.Z-eps then return b.P end end;return nil end
local function slabAt(y)for i,o in ipairs(Owner.Slabs)do local b=SPOT.Y+(o.Y-o.SY/2-(y1-Owner.Slabs[1].SY/2))*s;if y>=b and y<b+o.SY*s then return i end end end
local empty,solid,bad,badWall=0,0,0,0
local yTop=SPOT.Y+G.CeilingY;local y=SPOT.Y+G.FloorTop+.05
while y<yTop-.05 do
 local k=slabAt(y);local inner=Owner.Slabs[k+2];local outer=Owner.Slabs[k]
 local ix,iz=inner.SX*s/2,inner.SZ*s/2;local ox,oz=outer.SX*s/2,outer.SZ*s/2
 for x=-ox+.1,ox-.1,1 do for z=-oz+.1,oz-.1,1 do
  local pt=V3(SPOT.X+x,y,SPOT.Z+z)
  if math.abs(x)<ix-.05 and math.abs(z)<iz-.05 then if inside(pt,0)then bad+=1 else empty+=1 end
  elseif math.abs(x)>ix+.05 or math.abs(z)>iz+.05 then if inside(pt,0)then solid+=1 else badWall+=1 end end
 end end
 y+=.25
end
check(bad==0 and empty>10000,('the chamber is hollow: %d points between the floor and the caps, none inside a part'):format(empty))
check(badWall==0 and solid>1000,('the walls are solid: %d points in the rings, all inside a wall'):format(solid))
-- sealed: rays from the pack's centre (a Fibonacci sphere of 400 directions) each hit a pyramid part before they leave its box
local pack=anchor.Position
local function hitBox(o,d,b)
 local t0,t1=0,1e9
 for _,ax in ipairs({'X','Y','Z'})do
  local oa,da,lo,hi=o[ax],d[ax],b.Lo[ax],b.Hi[ax]
  if math.abs(da)<1e-12 then if oa<lo or oa>hi then return nil end
  else local a,c=(lo-oa)/da,(hi-oa)/da;if a>c then a,c=c,a end;t0=math.max(t0,a);t1=math.min(t1,c);if t0>t1 then return nil end end
 end
 return t0
end
local open=0;local maxT=0
for i=0,399 do
 local yy=1-(i+.5)/400*2;local r=math.sqrt(1-yy*yy);local th=i*math.pi*(3-math.sqrt(5))
 local d=V3(math.cos(th)*r,yy,math.sin(th)*r)
 local best=nil;for _,b in ipairs(boxes)do local t=hitBox(pack,d,b);if t and(not best or t<best)then best=t end end
 if not best then open+=1 else maxT=math.max(maxT,best)end
end
check(open==0,('sealed: all 400 rays from the pack hit a wall, the floor or a cap (no opening, no passage); the farthest at %.2f studs'):format(maxT))
check(anchor.Transparency==1 and pack.Y>SPOT.Y+G.FloorTop and pack.Y<SPOT.Y+G.CeilingY and near(pack.X,SPOT.X,1e-6)and near(pack.Z,SPOT.Z,1e-6),('the pack floats at the chamber\'s centre, %.2f over the floor'):format(pack.Y-SPOT.Y-G.FloorTop))

-- 4. The fit -------------------------------------------------------------------------------------------------------------------------------------------------------------------
local function aabb(p)
 local cf,sz=p.CFrame,p.Size;local r=cf.R
 local e=V3((math.abs(r[1][1])*sz.X+math.abs(r[1][2])*sz.Y+math.abs(r[1][3])*sz.Z)/2,(math.abs(r[2][1])*sz.X+math.abs(r[2][2])*sz.Y+math.abs(r[2][3])*sz.Z)/2,(math.abs(r[3][1])*sz.X+math.abs(r[3][2])*sz.Y+math.abs(r[3][3])*sz.Z)/2)
 return cf.Position-e,cf.Position+e
end
local wall=map:FindFirstChild('Obby')and map.Obby:FindFirstChild('BiomeWalls')and map.Obby.BiomeWalls:FindFirstChild('Biome_2_LeftWall')
local wlo,whi=aabb(wall)
local fullHalf=Owner.Slabs[1].SX/2
check(SPOT.X-fullHalf<whi.X,('at full size (%.2f wide) it would reach X %.2f, through the Desert\'s left wall (inner face X %.2f): it is scaled to the old footprint'):format(fullHalf*2,SPOT.X-fullHalf,whi.X))
local lo0,hi0=V3(SPOT.X-G.Half,SPOT.Y,SPOT.Z-G.Half),V3(SPOT.X+G.Half,SPOT.Y+G.Top,SPOT.Z+G.Half)
local function overlapping(lo,hi,skip)
 local out={}
 for _,d in ipairs(map:GetDescendants())do if d:IsA('BasePart')and not d:IsDescendantOf(model)then
  local t=d.Transparency
  if t<.98 and not skip(d)then
   local a,b=aabb(d)
   if a.X<hi.X-1e-3 and b.X>lo.X+1e-3 and a.Y<hi.Y-1e-3 and b.Y>lo.Y+1e-3 and a.Z<hi.Z-1e-3 and b.Z>lo.Z+1e-3 then out[#out+1]=d:GetFullName()end
  end
 end end
 return out
end
local function ground(d)return d.Name:match('^BiomeGround_')~=nil end
local hits=overlapping(lo0,hi0,ground)
check(#hits==0,'the pyramid touches nothing but the ground'..(#hits>0 and(': '..table.concat(hits,', '))or''))
local gap=lo0.X-whi.X
check(gap>=4,('a %.2f-stud walkway stays between its base and the left wall'):format(gap))
check(hi0.X<=-39.66,('its edge toward the track is the old one (X %.2f; the Sunscar\'s was -39.67)'):format(hi0.X))
local enc=Config.MythicEncounters[2];local home=V3(enc.Home[1],enc.Home[2],enc.Home[3])
local function dist2d(p)local dx=math.max(lo0.X-p.X,0,p.X-hi0.X);local dz=math.max(lo0.Z-p.Z,0,p.Z-hi0.Z);return math.sqrt(dx*dx+dz*dz)end
local seedMin=math.huge;for _,q in ipairs(enc.Seeds)do seedMin=math.min(seedMin,dist2d(V3(q[1],q[2],q[3])))end
check(dist2d(home)>=60 and seedMin>=60,('far from the Sand Snake\'s camp (%.0f studs) and the Desert\'s pack spots (%.0f studs)'):format(dist2d(home),seedMin))
local spawnMin=math.huge;for _,d in ipairs(map:GetDescendants())do if d.ClassName=='SpawnLocation'then spawnMin=math.min(spawnMin,dist2d(d.Position))end end
check(spawnMin>=200,('no spawn point near it (nearest %.0f studs)'):format(spawnMin))

-- 5. The zone --------------------------------------------------------------------------------------------------------------------------------------------------------------------
local m=Rules.Margin
local zhits=overlapping(V3(lo0.X-m,SPOT.Y-Rules.Below,lo0.Z-m),V3(hi0.X+m,SPOT.Y+G.Top+m,hi0.Z+m),function(d)return ground(d)or d==wall end)
check(#zhits==0,'nothing else stands in the Hold E zone (only the floor and the Desert\'s wall): no prompt from inside another building'..(#zhits>0 and(': '..table.concat(zhits,', '))or''))

-- 6. The keyboard ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
local K=W.module('KeyboardTrack');local geo=K.Geometry(map:GetAttributes(),0);local KW=K.KeySize(geo.Pitch)
local under,kept,around,aroundKept=0,0,0,0
local c1,c2,r1,r2=geo.CellRange(lo0.X-2*geo.Pitch,hi0.X+2*geo.Pitch,lo0.Z-2*geo.Pitch,hi0.Z+2*geo.Pitch)
for r=r1,r2 do if not geo.BarOfRow[r]then for c=c1,c2 do
 local x,z=geo.CellCenter(r,c)
 local ox=math.min(hi0.X,x+KW/2)-math.max(lo0.X,x-KW/2);local oz=math.min(hi0.Z,z+KW/2)-math.max(lo0.Z,z-KW/2)
 if ox>0 and oz>0 then under+=1;if not geo.Skipped(r,c)then kept+=1 end
 elseif ox>-geo.Pitch and oz>-geo.Pitch then around+=1;if not geo.Skipped(r,c)then aroundKept+=1 end end
end end end
check(under>0 and kept==0,('every key the pyramid stands on is left out (%d keys): none pokes through its %.2f-stud bottom step (a resting key stands %.2f)'):format(under,G.SlabHeight,K.Config.RestRise))
check(around>0 and aroundKept==around,('the %d keys around it stay'):format(around))
print(('GEO scale %.4f, base %.2f, top %.2f, slab %.3f, wall %.3f, chamber %.2f high, floor %.2f wide, pack %.2f over the floor, reach %.1f, walkway %.2f, keys left out %d, parts %d')
 :format(s,G.Width,G.Top,G.SlabHeight,G.Wall,G.CeilingY-G.FloorTop,G.FloorHalf*2,Rules.Lift,G.Reach,gap,under,#parts))
print(('R156 pyramid map: %d checks, %d failures'):format(checks2,fails2))
if fails2>0 then error('failed')end
