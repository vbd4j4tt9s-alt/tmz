--!nocheck
-- R153 (owner, after R152's rook gate: "the barrier's moon and 6s sit up behind the hanging biome keys and the panel is taller than the opening"): the night refresh barrier
-- (ReplicatedStorage.RefreshBarrier) against the REAL gate (ChestChaseServer.HubDecor151.Apply on the Roblox mock, HubDecorKit151 numbers) with the REAL module:
--  1. the barrier (a centre slab + a wing slab and a wedge on each side) is opaque, colliding and in the track-start plane, and fits the gate's OPENING: between the two tower
--     shafts (a small gap each side), from the floor (line.Y - 1) up to just under the lowest thing that hangs in it (the gatehouse wall's lower edge, and the biome keys that
--     hang below it) and under the haunches' slope: its parts tile that polygon exactly (no gap, no overlap among themselves)
--  2. no part of it enters a haunch, the gatehouse, a key, the sign or a tower shaft (2D overlap of the true outlines, wedges as triangles); it only tucks under the (non-colliding)
--     stone steps of the tower bases; no face of it lies in (nearly) one plane with a same-facing face it overlaps, the run-up lanes and the other paving included (z-fighting)
--  3. the sign (moon, countdown, caption, dots) fits the panel for every count, sits clear of the haunches' shoulders, and stays big enough to read from the hub
--  4. the numbers come from HubDecorKit151.Gate (a gate that changes moves the barrier with it), with the same values when the kit is missing
--  5. the gate's keys (R153, owner: "facing the right direction and upright"): each key's legend reads left to right and upright for a viewer in the hub, from the key's frame
local Z=require('./zfight_world');local W=Z.W;local R=Z.R;local V3,CF=R.Vector3.new,R.CFrame.new
local RS=W.RS
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end;return c end
local function near(a,b,tol)return type(a)=='number'and type(b)=='number'and math.abs(a-b)<=(tol or 1e-6)end
local Run=W.service('RunService');Run.IsServer=function()return true end;Run.IsClient=function()return false end
local folder=R.new('Folder');folder.Name='ChestChaseServer';folder.Parent=W.service('ServerScriptService')
for _,n in ipairs(require('./srv_names'))do RS[n].Parent=folder end
local function server(n)return W.require(folder[n])end
local map=R.new('Folder');map.Name='ChestChaseMap';map.Parent=W.workspace
local lobby=R.new('Folder');lobby.Name='Lobby';lobby.Parent=map
-- the owner's BaseBoundaryLine (Lobby.BaseBoundaryLine, 180 x .24 x 1 at 0, 4.12, -99.275) and the runtime folder MapService.SetBiomeRefreshing builds into
local line=R.new('Part');line.Name='BaseBoundaryLine';line.Size=V3(180,.24,1);line.CFrame=CF(0,4.12,-99.275);line.Parent=lobby
local runtime=R.new('Folder');runtime.Name='_GameplayRuntime';runtime.Parent=map
local K=W.module('HubDecorKit151');local G=K.Gate
local root=server('HubDecor151').Apply(map)
local gate=root:FindFirstChild('Gate')
local Bar=W.module('RefreshBarrier')
local wall,labels=Bar.Build(line,-100,runtime)
-- geometry of a part: its axis-aligned box (the gate only turns parts by quarter turns) -------------------------------------------------------------------------------
local function aabb(p)
 local c=p.CFrame;local s=p.Size;local r=c.R;local pos=c.Position
 local ex=(math.abs(r[1][1])*s.X+math.abs(r[1][2])*s.Y+math.abs(r[1][3])*s.Z)/2
 local ey=(math.abs(r[2][1])*s.X+math.abs(r[2][2])*s.Y+math.abs(r[2][3])*s.Z)/2
 local ez=(math.abs(r[3][1])*s.X+math.abs(r[3][2])*s.Y+math.abs(r[3][3])*s.Z)/2
 return{x0=pos.X-ex,x1=pos.X+ex,y0=pos.Y-ey,y1=pos.Y+ey,z0=pos.Z-ez,z1=pos.Z+ez}
end
local gateParts={};for _,d in ipairs(gate:GetDescendants())do if d:IsA('BasePart')then gateParts[#gateParts+1]=d end end
local function named(prefix)local out={};for _,p in ipairs(gateParts)do if p.Name:sub(1,#prefix)==prefix then out[#out+1]=p end end;return out end
check(gate~=nil and #gateParts>60,'the real rook gate is built ('..#gateParts..' parts)')
local wings={};for _,d in ipairs(wall:GetChildren())do if d:IsA('BasePart')then wings[#wings+1]=d end end
local parts={wall};for _,w in ipairs(wings)do parts[#parts+1]=w end
local b={x0=math.huge,x1=-math.huge,y0=math.huge,y1=-math.huge,z0=math.huge,z1=-math.huge}
for _,p in ipairs(parts)do local a=aabb(p);for _,k in ipairs({'x0','y0','z0'})do b[k]=math.min(b[k],a[k])end;for _,k in ipairs({'x1','y1','z1'})do b[k]=math.max(b[k],a[k])end end
local centre=aabb(wall)
-- 1. the barrier -------------------------------------------------------------------------------------------------------------------------------------------
check(wall.Name=='BiomeRefreshWall'and wall.Parent==runtime and wall:GetAttribute('BiomeRefreshBarrier')==true,'the BiomeRefreshWall (the centre, with the sign) is in the runtime folder, the barrier attribute set')
local slabs,wedges=0,0;for _,w in ipairs(wings)do if w.ClassName=='WedgePart'then wedges+=1 else slabs+=1 end end
check(#wings==4 and slabs==2 and wedges==2,'four wings under it: a slab and a wedge each side ('..#wings..': '..slabs..' slabs, '..wedges..' wedges)')
local solid=true;for _,p in ipairs(parts)do if not(p.CanCollide==true and p.Anchored==true and p.CanQuery==true and p.CanTouch==false and p.Transparency==0 and p.Color.R==wall.Color.R)then solid=false end end
check(solid,'every part is opaque paper and collides (anchored, queryable, no touch events): the barrier still blocks the whole opening')
local inPlane=true;for _,p in ipairs(parts)do local a=aabb(p);if not(near(a.z0,-102)and near(a.z1,-98))then inPlane=false end end
check(inPlane and near(wall.CFrame.Position.X,0),'track-start plane unchanged: Z -102 .. -98 (centre -100, 4 thick), centred on the track (X 0)')
local shaftHalf=math.huge;local shafts=named('Gate tower')
for _,p in ipairs(shafts)do if p.CanCollide and p.Name=='Gate tower'then local a=aabb(p);shaftHalf=math.min(shaftHalf,math.abs(p.CFrame.Position.X)-(a.x1-a.x0)/2)end end
check(shaftHalf<math.huge,'the colliding shafts: inner edge at |x| '..string.format('%.2f',shaftHalf))
check(b.x1<=shaftHalf-.2 and b.x0>=-(shaftHalf-.2),string.format('BETWEEN the tower shafts with a gap: barrier x %.2f .. %.2f, shaft edge +-%.2f',b.x0,b.x1,shaftHalf))
check(b.x1>=shaftHalf-1 and b.x0<=-(shaftHalf-1),'... and fills the opening to within a stud of the shafts (nothing to squeeze through, no gap to see the track)')
local floorTop=K.Floor;check(b.y0<=floorTop and b.y0>=floorTop-1.5,string.format('from the FLOOR: its bottom %.2f is at / just under the floor top (%d), line.Y - 1',b.y0,floorTop))
local beamBottom=math.huge;for _,p in ipairs(named('Gatehouse wall'))do beamBottom=math.min(beamBottom,aabb(p).y0)end
local keyBottom=math.huge;local keys=named('Biome key');for _,p in ipairs(keys)do keyBottom=math.min(keyBottom,aabb(p).y0)end
check(#keys==7 and near(keyBottom,G.KeyY-G.KeySize/2)and near(beamBottom,G.BeamY0),string.format('7 keys hang down to %.2f, the gatehouse wall starts at %.2f',keyBottom,beamBottom))
check(b.y1<=beamBottom and b.y1<=keyBottom-.5,string.format('NOTHING above the gatehouse edge: barrier top %.2f is under the wall (%.2f) and clear of the keys\' bottoms (%.2f)',b.y1,beamBottom,keyBottom))
check(b.y1>=keyBottom-2.5,string.format('... and only a small margin below them (top %.2f, keys %.2f)',b.y1,keyBottom))
-- the true outlines in the x / y plane (a wedge is its triangle, anything else its box): convex polygons
local function outline(p)
 if p.ClassName=='WedgePart'then
  local c=p.CFrame;local r=c.R;local pos=c.Position;local h,d=p.Size.Y,p.Size.Z
  local function w(ly,lz)return{r[1][2]*ly+r[1][3]*lz+pos.X,r[2][2]*ly+r[2][3]*lz+pos.Y}end
  return{w(-h/2,d/2),w(-h/2,-d/2),w(h/2,d/2)}
 end
 local a=aabb(p);return{{a.x0,a.y0},{a.x1,a.y0},{a.x1,a.y1},{a.x0,a.y1}}
end
local function area(poly)local t=0;for i=1,#poly do local j=i%#poly+1;t+=poly[i][1]*poly[j][2]-poly[j][1]*poly[i][2]end;return t/2 end
local function ccw(poly)if area(poly)<0 then local o={};for i=#poly,1,-1 do o[#o+1]=poly[i]end;return o end;return poly end
local function clip(subject,clipper) -- Sutherland - Hodgman, both convex
 subject,clipper=ccw(subject),ccw(clipper);local out=subject
 for i=1,#clipper do
  local a,c=clipper[i],clipper[i%#clipper+1];local input=out;out={}
  local function inside(q)return(c[1]-a[1])*(q[2]-a[2])-(c[2]-a[2])*(q[1]-a[1])>=-1e-9 end
  local function cut(p1,p2)
   local x1,y1,x2,y2,x3,y3,x4,y4=p1[1],p1[2],p2[1],p2[2],a[1],a[2],c[1],c[2]
   local den=(x1-x2)*(y3-y4)-(y1-y2)*(x3-x4);local t=((x1-x3)*(y3-y4)-(y1-y3)*(x3-x4))/den
   return{x1+t*(x2-x1),y1+t*(y2-y1)}
  end
  for k=1,#input do
   local cur,prev=input[k],input[(k-2)%#input+1]
   if inside(cur)then if not inside(prev)then out[#out+1]=cut(prev,cur)end;out[#out+1]=cur elseif inside(prev)then out[#out+1]=cut(prev,cur)end
  end
  if #out==0 then return{}end
 end
 return out
end
local function overlapArea(p,q)local poly=clip(outline(p),outline(q));if #poly<3 then return 0 end;return math.abs(area(poly))end
-- the opening: x +- Half, floor .. Top, under the haunches' slope. Its parts tile it exactly.
local Op=Bar.Opening(line)
local function underSlope(x)local ax=math.abs(x);local foot=G.HaunchOuter-G.HaunchRun;if ax<=foot then return G.BeamY0 end;return G.BeamY0-(ax-foot)*G.HaunchRise/G.HaunchRun end
local total=0;for _,p in ipairs(parts)do total+=math.abs(area(outline(p)))end
local want=2*Op.Half*(Op.Top-Op.Bottom)-2*(.5*(Op.Half-Op.Core)*(Op.Top-Op.Edge))
check(near(total,want,1e-6),string.format('the five-part polygon has the area of the opening under the haunches\' slope (%.3f of %.3f sq studs)',total,want))
local overlaps=0;for i=1,#parts do for j=i+1,#parts do if overlapArea(parts[i],parts[j])>1e-6 then overlaps+=1 end end end
check(overlaps==0,'the parts of the barrier do not overlap each other ('..overlaps..' pairs)')
local gaps,leaks,samples=0,0,0
local function inPoly(poly,x,y)poly=ccw(poly);for i=1,#poly do local a,c=poly[i],poly[i%#poly+1];if (c[1]-a[1])*(y-a[2])-(c[2]-a[2])*(x-a[1])<-1e-9 then return false end end;return true end
local function covered(x,y)for _,p in ipairs(parts)do if inPoly(outline(p),x,y)then return true end end;return false end
for x=-Op.Half+.25,Op.Half-.25,.5 do for y=Op.Bottom+.25,Op.Top-.25,.5 do
 samples+=1;local open=y<underSlope(x)-1e-6
 if open and not covered(x,y)then gaps+=1 elseif y>underSlope(x)+1e-6 and covered(x,y)then leaks+=1 end
end end
check(gaps==0 and samples>5000,'no gap: every point of the opening ('..samples..' sampled, 0.5 stud apart) is behind a part of the barrier ('..gaps..' holes)')
check(leaks==0,'no leak into the haunches: no sampled point above the slope is inside the barrier ('..leaks..')')
-- 2. what it overlaps / z-fighting ------------------------------------------------------------------------------------------------------------------------------
local touched={}
for _,p in ipairs(gateParts)do
 local pa=aabb(p)
 if pa.z0<b.z1-1e-6 and pa.z1>b.z0+1e-6 then -- (same depth range as the barrier)
  for _,mine in ipairs(parts)do local ov=overlapArea(mine,p);if ov>1e-6 then touched[p.Name]=(touched[p.Name]or 0)+ov end end
 end
end
local bad={};for n,ov in pairs(touched)do if not n:find('^Gate base %d$')then bad[#bad+1]=n..string.format(' (%.2f sq studs)',ov)end end
check(#bad==0,'no part of the barrier enters a haunch, the gatehouse, a key, the sign or a tower shaft (outlines overlap only: '..table.concat(bad,', ')..')')
local steps=0;for n in pairs(touched)do if n:find('^Gate base %d$')then steps+=1 end end
check(true,'(it only tucks under the non-colliding stone steps of the tower bases: '..steps..' steps, the outer 1.1 stud of its edge)')
-- flat faces of the gate parts that point the same way as one of the barrier's (a cylinder's flat faces are its caps, +-Y only), within the depth rule's .043 stud
local function planes(p)
 local a=aabb(p);local cyl=p.Shape and p.Shape.Name=='Cylinder'
 local out={}
 if not cyl then out[#out+1]={axis='x',side=1,at=a.x1,a=a};out[#out+1]={axis='x',side=-1,at=a.x0,a=a};out[#out+1]={axis='z',side=1,at=a.z1,a=a};out[#out+1]={axis='z',side=-1,at=a.z0,a=a}end
 out[#out+1]={axis='y',side=1,at=a.y1,a=a};out[#out+1]={axis='y',side=-1,at=a.y0,a=a}
 return out
end
local function faceOverlap(axis,fa,fb)
 local others={x={'y','z'},y={'x','z'},z={'x','y'}}
 for _,ax in ipairs(others[axis])do if not(fa[ax..'0']<fb[ax..'1']-1e-6 and fa[ax..'1']>fb[ax..'0']+1e-6)then return false end end
 return true
end
local worst=math.huge;local flicker={}
local others={};for _,p in ipairs(gateParts)do others[#others+1]=p end
local paths=root:FindFirstChild('Paths');if paths then for _,d in ipairs(paths:GetDescendants())do if d:IsA('BasePart')then others[#others+1]=d end end end
local mineAll={};for _,p in ipairs(parts)do for _,pl in ipairs(planes(p))do mineAll[#mineAll+1]=pl end end
for _,mine in ipairs(mineAll)do
 for _,p in ipairs(others)do for _,theirs in ipairs(planes(p))do
  if theirs.axis==mine.axis and theirs.side==mine.side and faceOverlap(mine.axis,mine.a,theirs.a)then
   local d=math.abs(theirs.at-mine.at);worst=math.min(worst,d)
   if d<.05 then flicker[#flicker+1]=p.Name..' '..mine.axis..(mine.side>0 and'+'or'-')..' ('..string.format('%.3f',d)..')' end
  end
 end end
end
check(#flicker==0,'no face of the barrier lies within .05 stud of a same-facing overlapping face of a gate part or of the paving (run-up lanes, streets) (z-fighting): '..table.concat(flicker,', '))
-- 3. the sign -----------------------------------------------------------------------------------------------------------------------------------------------------
local PPS=Bar.PixelsPerStud
local faces={};for _,g in ipairs(wall:GetChildren())do if g:IsA('SurfaceGui')then faces[#faces+1]=g end end
check(#faces==2 and faces[1].Face~=faces[2].Face,'a SurfaceGui on the front and one on the back')
local gui=faces[1];local canvas=gui.CanvasSize
check(near(canvas.X,math.floor(wall.Size.X*PPS),1)and near(canvas.Y,math.floor(wall.Size.Y*PPS),1),'the canvas is the panel ('..canvas.X..' x '..canvas.Y..' px at '..PPS..' px / stud)')
local panel=gui.NightSign;local sign=panel.Sign
local fit=sign:GetAttribute('Fit')
check(fit and fit<1 and fit>=.7,'the R124 sign is scaled to fit the panel (Fit '..tostring(fit)..'): its digits stay readable')
local sw,sh=sign.Size.X.Offset,sign.Size.Y.Offset
check(sh<=canvas.Y*.9 and sh>=canvas.Y*.75,'the sign block fills about 86% of the panel height ('..sh..' of '..canvas.Y..' px)')
check(sw<=canvas.X*.72,'... and well under the centre panel\'s width ('..sw..' of '..canvas.X..' px)')
local cx=canvas.X/2;local cy=(1-Bar.SignHeight)*canvas.Y
check(sign.Position.X.Scale==.5 and near(sign.Position.Y.Scale,1-Bar.SignHeight)and sign.AnchorPoint.X==.5 and sign.AnchorPoint.Y==.5,'centred on the panel')
-- the block in world studs on the barrier's hub-side face: x from the panel centre, y down from the barrier's top
local function world(px,py)return(px-cx)/PPS,b.y1-py/PPS end
local x0,y1=world(cx-sw/2,cy-sh/2);local x1,y0=world(cx+sw/2,cy+sh/2)
check(y1<=b.y1-1 and y0>=b.y0+1.5,string.format('the sign block (y %.1f .. %.1f) is inside the panel (%.1f .. %.1f) with a margin',y0,y1,b.y0,b.y1))
local haunchX=math.huge;for _,p in ipairs(named('Gate haunch'))do local a=aabb(p);haunchX=math.min(haunchX,math.abs(p.CFrame.Position.X)-(a.x1-a.x0)/2)end
check(haunchX<math.huge and x1<haunchX-2,string.format('the block (x +-%.1f) is clear of the haunches\' shoulders (they start at |x| %.1f)',x1,haunchX))
for _,txt in ipairs({'0','6','10','88'})do
 for _,l in ipairs(labels)do l.Text=txt end
 local c=sign.Count;local moon=sign.MoonIcon;local cap=sign.Caption
 local glyph=c.Size.Y.Offset*c.UIScale.Scale/PPS
 local right=c.Position.X.Offset+(c.Size.X.Offset-8)*c.UIScale.Scale
 check(c.Text==txt..'s','the count reads '..txt..'s ('..c.Text..')')
 check(glyph>=20,txt..'s: the digits are '..string.format('%.1f',glyph)..' studs tall (>= 20: readable from the hub)')
 check(moon.Size.X.Offset/PPS>=20 and moon.Position.X.Offset>=0 and right<=sw,txt..'s: the moon ('..string.format('%.1f',moon.Size.X.Offset/PPS)..' studs) and the count fit the sign')
 check(moon.Position.Y.Offset>=0 and moon.Position.Y.Offset+moon.Size.Y.Offset<=sh,txt..'s: the moon is inside the sign vertically')
 local left=moon.Position.X.Offset;check(math.abs(left-(sw-right))<=14,txt..'s: moon + count are centred as one group (left '..left..', right '..(sw-right)..')')
 check(cap.TextSize/PPS>=4 and cap.Position.Y.Offset+cap.Size.Y.Offset/2<=sh and cap.Position.Y.Offset-cap.Size.Y.Offset/2>=c.Position.Y.Offset+c.Size.Y.Offset*c.UIScale.Scale/2-4,txt..'s: the caption ('..cap.TextSize..' px = '..string.format('%.1f',cap.TextSize/PPS)..' studs) sits under the count, inside the sign')
end
for _,l in ipairs(labels)do l.Text='7' end
local dotsRight=0;for i=1,3 do local d=sign['Dot'..i];dotsRight=math.max(dotsRight,d.Position.X.Offset+d.Size.X.Offset);check(d.Position.Y.Offset+d.Size.Y.Offset<=sh+2,'dot '..i..' is inside the sign')end
check(dotsRight<=sw,'the caption dots end inside the sign ('..dotsRight..' of '..sw..' px)')
-- the stars stay outside the sign block; the inset border follows the panel
for i=1,8 do local s=panel['Star'..i];local sxp=s.Position.X.Scale*canvas.X;check(sxp<cx-sw/2-4 or sxp>cx+sw/2+4,'star '..i..' is outside the sign block')end
check(panel.InsetBorder.Size.Y.Offset==canvas.Y-36,'the inset border follows the panel')
check(faces[2].NightSign.Sign:GetAttribute('Fit')==fit and faces[2].NightSign.Sign.Size.X.Offset==sw,'both faces carry the same sign')
-- 4. the numbers come from the kit ----------------------------------------------------------------------------------------------------------------------------
local o=Bar.Opening(line)
check(near(o.Half,G.TowerX-G.TowerD/2-Bar.Margin.Side)and near(o.Top,math.min(G.BeamY0,G.KeyY-G.KeySize/2)-Bar.Margin.Top)and near(o.Bottom,3.12),'Opening() = the kit\'s TowerX / TowerD / BeamY0 / KeyY / KeySize minus the margins, from line.Y - 1')
check(near(o.Core,G.HaunchOuter-G.HaunchRun+(G.BeamY0-o.Top)*G.HaunchRun/G.HaunchRise)and near(o.Edge,G.BeamY0-(o.Half-(G.HaunchOuter-G.HaunchRun))*G.HaunchRise/G.HaunchRun),string.format('... and the wings follow the kit\'s haunch (HaunchRise / Run / Outer): the centre reaches |x| %.2f, the wing is %.2f tall at the shaft',o.Core,o.Edge))
local hr=G.HaunchRun;G.HaunchRun=24
check(not near(Bar.Opening(line).Core,o.Core),'a different haunch (HaunchRun 24) moves where the wings start')
G.HaunchRun=hr
-- the gate's own haunches are built from the same numbers
local hz=named('Gate haunch');local hok=#hz==2
for _,p in ipairs(hz)do local a=aabb(p);if not(near(a.y1-a.y0,G.HaunchRise)and near(a.x1-a.x0,G.HaunchRun)and near(math.max(math.abs(a.x0),math.abs(a.x1)),G.HaunchOuter))then hok=false end end
check(hok,'the two haunches are HaunchRise tall, HaunchRun wide and end at |x| = HaunchOuter (the kit\'s numbers)')
local keep={G.TowerX,G.TowerD,G.BeamY0,G.KeyY,G.KeySize}
G.TowerX,G.TowerD,G.KeyY,G.KeySize=120,16,70,10
local moved=Bar.Opening(line)
check(near(moved.Half,120-8-Bar.Margin.Side)and near(moved.Top,math.min(G.BeamY0,65)-Bar.Margin.Top),'a gate that changes (towers at 120, keys at 70) moves the barrier with it (half '..moved.Half..', top '..moved.Top..')')
G.TowerX,G.TowerD,G.BeamY0,G.KeyY,G.KeySize=table.unpack(keep)
local kit=K.Gate;K.Gate=nil
local fb=Bar.Opening(line)
check(near(fb.Half,o.Half)and near(fb.Top,o.Top),'without HubDecorKit151.Gate the same numbers (99, 14.4, 44, 50, 15 are the fallback)')
K.Gate=kit
-- the keys are sized by the kit (the barrier reads KeySize)
local sizes=true;for _,p in ipairs(keys)do local a=aabb(p);if not(near(a.y1-a.y0,G.KeySize,.01))then sizes=false end end
check(sizes,'every key is KeySize ('..G.KeySize..') tall: what the barrier clears is what hangs')
-- 5. the gate's keys face the hub and read left to right, upright ------------------------------------------------------------------------------------------
do
 local Kb=W.module('KeyboardTrack')
 -- KeyboardTrack's measured Top-face frame (owner's screenshots): the canvas x axis (reading direction) of an unrotated part is world -Z = its LookVector, the canvas y axis (down the
 -- canvas) is world +X = its RightVector. (TopReading(0) = the reading direction; TopPoint's canvas y grows with world x.)
 local rx,rz=Kb.TopReading(0)
 local _,py0=Kb.TopPoint(0,0,10,10,1,0,0);local _,py1=Kb.TopPoint(0,0,10,10,1,1,0)
 check(near(rx,0)and near(rz,-1)and py1>py0,'(the convention: an unrotated part\'s Top canvas reads along -Z = its LookVector and runs down along +X = its RightVector)')
 local function col(c,i)local r=c.R;return{r[1][i],r[2][i],r[3][i]}end
 local function vec(t)return string.format('(%.2f, %.2f, %.2f)',t[1],t[2],t[3])end
 local function eq(t,x,y,z)return near(t[1],x,1e-6)and near(t[2],y,1e-6)and near(t[3],z,1e-6)end
 local ok,why=true,nil;local order={}
 for i,key in ipairs(keys)do
  local c=key.CFrame;local right,up,back=col(c,1),col(c,2),col(c,3);local look={-back[1],-back[2],-back[3]}
  local reading,down,normal=look,right,up
  -- the viewer stands in the hub (z < -104) looking +Z: his right is world -X, his up world +Y
  if not eq(reading,-1,0,0)then ok=false;why='key '..i..' reads along '..vec(reading)end
  if not eq(down,0,-1,0)then ok=false;why=(why or'')..' key '..i..' runs down along '..vec(down)end
  if not eq(normal,0,0,-1)then ok=false;why=(why or'')..' key '..i..' top faces '..vec(normal)end
  local cross={reading[2]*down[3]-reading[3]*down[2],reading[3]*down[1]-reading[1]*down[3],reading[1]*down[2]-reading[2]*down[1]} -- (screen right x screen down = into the screen)
  if not eq(cross,0,0,1)then ok=false;why=(why or'')..' key '..i..' is mirrored '..vec(cross)end
  order[#order+1]={Name=key.Name,X=c.Position.X}
 end
 check(ok,'every key\'s legend reads left to right (= world -X, the viewer\'s right), the canvas runs down toward world -Y (upright) and the top faces the hub (-Z), not mirrored'..(why and(': '..why)or''))
 local sorted=true;for i=2,#order do if order[i].X>=order[i-1].X then sorted=false end end
 check(sorted and #order==7,'Forest on the left (world +X) to Storm Peaks on the right (world -X): the keys step -24 studs each')
 local k1=keys[1];local gui=k1:FindFirstChild('KeyLegend')
 check(gui and gui.Face.Name=='Top'and gui:FindFirstChild('Line1')and gui.Line1.Position.Y.Scale<gui.Line2.Position.Y.Scale and gui.Line2.Position.Y.Scale<gui.Line3.Position.Y.Scale,'the legend is on the key\'s Top face, the emoji line above the name above the speed')
 check(K.KeyFrame~=nil and eq(col(K.KeyFrame(V3(1,2,3)),2),0,0,-1),'HubDecorKit151.KeyFrame is what the gate uses')
end
print(string.format('barrier: x %.2f .. %.2f, y %.2f .. %.2f (%.1f x %.1f studs); shafts +-%.2f, gatehouse from %.1f, keys from %.1f; closest same-facing gate plane %.2f stud; sign Fit %.3f, digits %.1f studs, caption %.1f studs',
 b.x0,b.x1,b.y0,b.y1,b.x1-b.x0,b.y1-b.y0,shaftHalf,beamBottom,keyBottom,worst,fit,sign.Count.Size.Y.Offset*sign.Count.UIScale.Scale/PPS,sign.Caption.TextSize/PPS))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
