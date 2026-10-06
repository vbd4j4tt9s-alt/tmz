--!nocheck
-- R153 (owner, after R152's rook gate: "the barrier's moon and 6s sit up behind the hanging biome keys and the panel is taller than the opening"): the night refresh barrier
-- (ReplicatedStorage.RefreshBarrier) against the REAL gate (ChestChaseServer.HubDecor151.Apply on the Roblox mock, HubDecorKit151 numbers) with the REAL module:
--  1. the barrier is one opaque colliding slab in the track-start plane that fits the gate's OPENING: between the two tower shafts (a small gap each side), from the floor
--     (line.Y - 1) up to just under the lowest thing that hangs in it (the gatehouse wall's lower edge, and the biome keys that hang below it), nothing above that
--  2. its volume touches only what it may hide behind (the haunches under the gatehouse, the stone steps of the tower bases): never the shafts, the gatehouse, the keys,
--     the sign; no face of it lies in (nearly) one plane with a same-facing face of a gate part that it overlaps (no z-fighting, the 0.043 stud depth rule)
--  3. the sign (moon, countdown, caption, dots) fits the panel for every count, sits clear of the haunches' shoulders, and stays big enough to read from the hub
--  4. the numbers come from HubDecorKit151.Gate (a gate that changes moves the barrier with it), with the same values when the kit is missing
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
local b=aabb(wall)
-- 1. the slab ---------------------------------------------------------------------------------------------------------------------------------------------------
check(wall.Name=='BiomeRefreshWall'and wall.Parent==runtime and wall:GetAttribute('BiomeRefreshBarrier')==true,'one BiomeRefreshWall in the runtime folder, the barrier attribute set')
check(wall.CanCollide==true and wall.Anchored==true and wall.CanQuery==true and wall.CanTouch==false and wall.Transparency==0,'it is opaque and still collides (anchored, queryable, no touch events)')
check(near(wall.CFrame.Position.Z,-100)and near(wall.Size.Z,4)and near(wall.CFrame.Position.X,0),'track-start plane unchanged: Z -100, 4 thick, centred on the track (X 0)')
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
local extra=0;for _,p in ipairs(wall:GetDescendants())do if p:IsA('BasePart')then extra+=1 end end
check(extra==0,'the barrier is one part (no extra part sticks out above the gate)')
-- 2. what it overlaps / z-fighting ------------------------------------------------------------------------------------------------------------------------------
local function overlap(a,c)return a.x0<c.x1-1e-6 and a.x1>c.x0+1e-6 and a.y0<c.y1-1e-6 and a.y1>c.y0+1e-6 and a.z0<c.z1-1e-6 and a.z1>c.z0+1e-6 end
local touched={}
for _,p in ipairs(gateParts)do if overlap(b,aabb(p))then touched[p.Name]=(touched[p.Name]or 0)+1 end end
local bad={};for n in pairs(touched)do if not(n=='Gate haunch'or n:find('^Gate base %d$'))then bad[#bad+1]=n end end
check(#bad==0,'its volume reaches only the haunches and the stone steps of the tower bases (hidden behind / inside them), not '..table.concat(bad,', '))
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
for _,mine in ipairs(planes(wall))do
 for _,p in ipairs(gateParts)do for _,theirs in ipairs(planes(p))do
  if theirs.axis==mine.axis and theirs.side==mine.side and faceOverlap(mine.axis,mine.a,theirs.a)then
   local d=math.abs(theirs.at-mine.at);worst=math.min(worst,d)
   if d<.05 then flicker[#flicker+1]=p.Name..' '..mine.axis..(mine.side>0 and'+'or'-')..' ('..string.format('%.3f',d)..')' end
  end
 end end
end
check(#flicker==0,'no face of the barrier lies within .05 stud of a same-facing overlapping face of a gate part (z-fighting): '..table.concat(flicker,', '))
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
check(sw<=canvas.X*.6,'... and well under the panel width ('..sw..' of '..canvas.X..' px)')
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
print(string.format('barrier: x %.2f .. %.2f, y %.2f .. %.2f (%.1f x %.1f studs); shafts +-%.2f, gatehouse from %.1f, keys from %.1f; closest same-facing gate plane %.2f stud; sign Fit %.3f, digits %.1f studs, caption %.1f studs',
 b.x0,b.x1,b.y0,b.y1,b.x1-b.x0,b.y1-b.y0,shaftHalf,beamBottom,keyBottom,worst,fit,sign.Count.Size.Y.Offset*sign.Count.UIScale.Scale/PPS,sign.Caption.TextSize/PPS))
print(('%d checks, %d failures'):format(checks,fails))
if fails>0 then error('FAILED')end
