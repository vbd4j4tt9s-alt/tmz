--!nocheck
-- R158 DESIGN PREVIEW (not game code yet): the track walls per biome, the outer track (what you see outside the walls) and three options for the
-- top of the base (hub) walls. Owner: "look into designing each of the track walls and also the outer track designs can be added and so on and also
-- polish up the base walls especially the top. these will be the final changes." See design.md (this folder) for the pictures and the choices.
--
-- Pure Luau (no Roblox API). Every builder returns a list of part SPECS; a later build step turns each into an Instance:
--   {Group=, Name=, Shape='Block'|'Wedge'|'Cylinder'|'Ball', Size={x,y,z}, CF={x,y,z, R00,R01,R02, R10,R11,R12, R20,R21,R22},
--    Color={r,g,b}, Material='Slate'|..., Transparency=0, Mesh='Sphere' (a SpecialMesh: an egg / dune / snow pillow shape), Shadow=false}
--   CF is CFrame:GetComponents() order, so CFrame.new(table.unpack(spec.CF)) rebuilds it. No CornerWedges (their corner is easy to get wrong).
--   EVERY part: Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false (nothing new to stand on, nothing the runner sweep, the
--   camera's pop-in, the pack placement ray or a Touched event sees). Parts under 1.5 studs cast no shadow (R154 SmallShadow154 rule); the outer
--   track casts none at all. No scripts: the glow is Neon, nothing moves.
-- D.Restyle lists the property changes on the saved wall parts (the 15 track wall parts: Color / Material only; size / position / collision untouched).
-- D.BaseWalls(option) also returns the built parts that option hides (option B rebuilds the 218 wall merlons on its flared crown).
--
-- Numbers measured on the owner's place after every start-up pass (R152 sweep world, 10 Oct):
--   side walls: inner face |x| 89, outer face |x| 94, Y 3 .. 51 (48 tall); the floor's top Y 4; keyboard keys reach |x| 89.75 and Y 5.2;
--   R153 blockers: invisible, |x| 88.98 .. 97, Y 45 .. 1051 (nothing here changes them); end wall z 5980 .. 5985, x -94 .. 94.
--   Biomes along +Z: Forest -100..80, Jungle 80..530, Desert 530..1180, Snow 1180..2030, Lava 2030..3080, Crystal 3080..4380, Storm 4380..5980.
--   Hub gate (HubDecor151): rook towers at x +-99, z -100 (base reaches |x| 90.3, z -108.7 .. -91.3); the gatehouse wall z -104.5 .. -95.5, Y 44 .. 58
--   sits on the Forest walls' first 4.5 studs. Hub walls: front z -104 .. -99 (x 94 .. 335 each side), sides x +-(335 .. 340) z -623 .. -99, back
--   z -623 .. -618; top Y 51; merlons 5 x 6 x 5 on top (K.MerlonSpots).
--   Desert pyramid (R157): centre x -62.07, z 1005, 44.8 wide (x -84.47 .. -39.67): the 4.5-stud walkway along the Desert's LEFT wall is kept clear.
--   Nothing outside the walls today: no terrain, no ground (the place's Terrain is empty): the outer track adds a ground under its scenery.
--   The refresh cover (TrackBlackout) is |x| <= 94, Y -15 .. 55: wall pieces above Y 55 stand over it during a refresh (a dark fort outline at night).
local D={}
D.Version=158
local IN,OUT,TOP,FLOOR=89,94,51,4
D.Wall={Inner=IN,Outer=OUT,Top=TOP,Floor=FLOOR,KeyTop=5.2}
local SINK=.4 -- face pieces reach this far into the wall (their back faces never share the wall's face plane)

-------------------------------------------------------------------------------------------------------------------------------- math
local function mul(a,b)local r={}for i=1,3 do r[i]={}for j=1,3 do r[i][j]=a[i][1]*b[1][j]+a[i][2]*b[2][j]+a[i][3]*b[3][j]end end;return r end
local function Rx(t)local c,s=math.cos(t),math.sin(t);return{{1,0,0},{0,c,-s},{0,s,c}}end
local function Ry(t)local c,s=math.cos(t),math.sin(t);return{{c,0,s},{0,1,0},{-s,0,c}}end
local function Rz(t)local c,s=math.cos(t),math.sin(t);return{{c,-s,0},{s,c,0},{0,0,1}}end
local I3={{1,0,0},{0,1,0},{0,0,1}}
local function cross(a,b)return{a[2]*b[3]-a[3]*b[2],a[3]*b[1]-a[1]*b[3],a[1]*b[2]-a[2]*b[1]}end
local function axes(X,Y,Z)return{{X[1],Y[1],Z[1]},{X[2],Y[2],Z[2]},{X[3],Y[3],Z[3]}}end -- columns = the part's local X / Y / Z in world
local function cf(x,y,z,r)r=r or I3;return{x,y,z,r[1][1],r[1][2],r[1][3],r[2][1],r[2][2],r[2][3],r[3][1],r[3][2],r[3][3]}end
local function col(r,i)return{r[1][i],r[2][i],r[3][i]}end
local UPRIGHT=axes({0,1,0},{-1,0,0},{0,0,1})  -- a Cylinder's axis (local X) pointing up
local ALONG_Z=axes({0,0,1},{0,1,0},{-1,0,0})  -- a Cylinder's axis along the track
local ALONG_X=I3                              -- a Cylinder's axis across the track (a disc facing the track)
-- A cube turned so that one corner points straight up (its long diagonal vertical): seen from the side, a three-faced peak. `yaw` turns it.
local function cornerUp(yaw)
 local k,s3=math.sqrt(2/3),1/math.sqrt(3);local e={}
 for i=0,2 do local t=yaw+i*2*math.pi/3;e[i+1]={k*math.cos(t),s3,k*math.sin(t)}end
 local c=cross(e[1],e[2]);if c[1]*e[3][1]+c[2]*e[3][2]+c[3]*e[3][3]<0 then e[1],e[2]=e[2],e[1]end
 return axes(e[1],e[2],e[3])
end

-------------------------------------------------------------------------------------------------------------------------------- part makers
local out -- the list being filled
local group='?'
local function part(name,shape,size,frame,color,material,opt)
 opt=opt or{}
 local p={Group=group,Name=name,Shape=shape,Size={size[1],size[2],size[3]},CF=frame,Color=color,Material=material or'SmoothPlastic',
  Transparency=opt.t or 0,Mesh=opt.mesh,Bay=opt.bay}
 if opt.shadow==false or math.max(size[1],size[2],size[3])<1.5 then p.Shadow=false end
 out[#out+1]=p;return p
end
local function block(name,size,frame,color,material,opt)return part(name,'Block',size,frame,color,material,opt)end
local function cyl(name,len,d,frame,color,material,opt)return part(name,'Cylinder',{len,d,d},frame,color,material,opt)end
local function vcyl(name,x,z,y0,y1,d,color,material,opt)return cyl(name,y1-y0,d,cf(x,(y0+y1)/2,z,UPRIGHT),color,material,opt)end
local function ball(name,d,x,y,z,color,material,opt)return part(name,'Ball',{d,d,d},cf(x,y,z),color,material,opt)end
local function egg(name,size,x,y,z,color,material,opt)
 local o={};for k,v in pairs(opt or{})do o[k]=v end;o.mesh='Sphere' -- (a copy: the shared option tables stay as they are)
 return block(name,size,cf(x,y,z),color,material,o)
end
-- A box between two corners (axis-aligned).
local function box(name,x0,x1,y0,y1,z0,z1,color,material,opt)
 return block(name,{math.abs(x1-x0),y1-y0,math.abs(z1-z0)},cf((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),color,material,opt)
end
-- A piece on a side wall's inner face: s = -1 left wall, +1 right wall; it stands `proud` studs out of the face into the track and SINK into the wall.
local function face(name,s,z0,z1,y0,y1,proud,color,material,opt)
 return box(name,s*(IN-proud),s*(IN+SINK),y0,y1,z0,z1,color,material,opt)
end
-- A piece that wraps the wall top: from `proud` out of the inner face, over the wall, `back` past the outer face.
local function wrap(name,s,z0,z1,y0,y1,proud,back,color,material,opt)
 return box(name,s*(IN-proud),s*(OUT+back),y0,y1,z0,z1,color,material,opt)
end
-- A triangle made of two wedges (a spike / tent): base centre `b`, apex `h` along `up`, base `w` wide along `span`, `t` thick.
-- Seen across `t` it is a triangle; the two wedges meet back to back on the centre line (opposite faces: they cannot flicker).
local function spike(name,b,up,span,h,w,t,color,material,opt)
 for _,k in ipairs({-1,1})do
  local Z={-k*span[1],-k*span[2],-k*span[3]};local X=cross(up,Z)
  local c={b[1]+up[1]*h/2+span[1]*k*w/4,b[2]+up[2]*h/2+span[2]*k*w/4,b[3]+up[3]*h/2+span[3]*k*w/4}
  part(name,'Wedge',{t,h,w/2},cf(c[1],c[2],c[3],axes(X,up,Z)),color,material,opt)
 end
end
-- Two spikes crossed at right angles (a little pyramid that reads as a triangle from any side): a pine tier, an obelisk tip.
local function cone4(name,x,y,z,h,w,color,material,opt)
 spike(name,{x,y,z},{0,1,0},{0,0,1},h,w,w*.9,color,material,opt)
 spike(name,{x,y,z},{0,1,0},{1,0,0},h,w*.9,w,color,material,opt)
end
-- One wedge with its tall side at `b` (a right triangle: icicle, jagged tooth, wing): `dir` = +1 / -1 picks which way it runs along `span`.
local function tooth(name,b,up,span,h,w,t,dir,color,material,opt)
 local Z={-dir*span[1],-dir*span[2],-dir*span[3]};local X=cross(up,Z)
 local c={b[1]+up[1]*h/2+span[1]*dir*w/2,b[2]+up[2]*h/2+span[2]*dir*w/2,b[3]+up[3]*h/2+span[3]*dir*w/2}
 return part(name,'Wedge',{t,h,w},cf(c[1],c[2],c[3],axes(X,up,Z)),color,material,opt)
end
-- A strip lying flat on a side wall's face, turned by `angle` (radians) in the wall's plane (a crack, a bolt).
local function streak(name,s,z,y,len,width,proud,angle,color,material,opt)
 return block(name,{proud+SINK,len,width},cf(s*(IN-(proud-SINK)/2),y,z,Rx(angle)),color,material,opt)
end
-- A zigzag of `n` streaks from (z, y) downwards (a crack or a lightning bolt): each segment `len` long, leaning +-`lean`.
local function zigzag(name,s,z,y,n,len,width,proud,lean,color,material,opt)
 local cz,cy=z,y
 for i=1,n do
  local a=(i%2==1)and lean or-lean
  local dz,dy=math.sin(a)*len,-math.cos(a)*len
  streak(name,s,cz+dz/2,cy+dy/2,len+width*.6,width,proud+.03*i,-a,color,material,opt) -- (each a hair prouder: the joints never share a plane)
  cz,cy=cz+dz,cy+dy
 end
end
-- A crystal shard: a tall pointed spike (two wedges; one wedge when `half`) growing from (x, y, z), leaning by leanX across the track
-- (Rz: + leans toward -X) and leanZ along it (Rx). Seen from the track it is a sharp triangle.
local function shard(name,x,y,z,h,w,leanX,leanZ,color,material,opt,half)
 local r=mul(Rz(leanX),Rx(leanZ));local up,span=col(r,2),col(r,3)
 if half then return tooth(name,{x,y,z},up,span,h,w*.6,w*.8,half,color,material,opt)end
 spike(name,{x,y,z},up,span,h,w,w*.8,color,material,opt)
end
-- A low-poly mountain: a cube with a corner up, sunk so deep that only its top shows: a three-sided pyramid with its peak at `peak`.
-- (The cube is 1.8 x the height: its middle ring of corners stays under the ground, so nothing reaches out sideways.) Over the ground its
-- base is a triangle whose corners are 1.414 x the height from the centre: the centre must be at least that + 110 from the walls.
-- `cap` adds a snow cap (a smaller cube, same turn, its peak 2.5 higher: its faces stand 1.4 off the mountain's, parallel).
local GROUND=FLOOR-.4
local function mountain(name,x,z,peak,yaw,color,material,cap,capColor,capMaterial)
 local h=peak-GROUND;local a=1.8*h;local r=cornerUp(yaw)
 block(name,{a,a,a},cf(x,peak-a*math.sqrt(3)/2,z,r),color,material,{shadow=false})
 if cap then local b=a*cap;block(name..' cap',{b,b,b},cf(x,peak+2.5-b*math.sqrt(3)/2,z,r),capColor,capMaterial,{shadow=false})end
 return math.sqrt(2)*h,r
end
-- A flat strip lying on a mountain's face, from its peak straight down that face (a lava stream): the face most turned toward `dirX`
-- (-1: toward -X). It lies 1 stud off the face (parallel to it), `off` across the face from its middle line.
local function faceStrip(name,x,z,peak,r,dirX,len,width,off,color,material)
 local bi,best=1,-2
 for i=1,3 do local e=col(r,i);if e[1]*dirX>best then best=e[1]*dirX;bi=i end end
 local n,o1,o2=col(r,bi),col(r,bi%3+1),col(r,(bi+1)%3+1)
 local k=1/math.sqrt(2);local Y={-(o1[1]+o2[1])*k,-(o1[2]+o2[2])*k,-(o1[3]+o2[3])*k};local Z=cross(n,Y)
 local c={x+Y[1]*len/2+n[1]*1.6+Z[1]*off,peak+Y[2]*len/2+n[2]*1.6+Z[2]*off,z+Y[3]*len/2+n[3]*1.6+Z[3]*off}
 block(name,{1.2,len,width},cf(c[1],c[2],c[3],axes(n,Y,Z)),color,material,{shadow=false})
end
-- A tall rock or crystal spire: a square column turned 45 degrees, leaning a little, with a pointed tip (two wedges).
local function spire(name,x,z,w,h,lean,color,material)
 local r=mul(Rz(lean),Ry(math.pi/4));local up,span=col(r,2),col(r,3)
 block(name,{w,h,w},cf(x+up[1]*h/2,GROUND-2+up[2]*h/2,z+up[3]*h/2,r),color,material,{shadow=false})
 spike(name..' tip',{x+up[1]*h,GROUND-2+up[2]*h,z+up[3]*h},up,span,w*1.2,w,w,color,material,{shadow=false})
end

-------------------------------------------------------------------------------------------------------------------------------- biomes
-- Colours are RGB 0-255. Materials are Roblox Enum.Material names. Key colours: KeyboardTrack's palettes (HubDecorKit151.Biomes).
D.Biomes={
 {Stage=1,Id='forest',Name='Forest',Z0=-100,Z1=80,Key={96,186,90},Ground={{92,150,70},'Grass'},
  Wall={Color={78,58,40},Material='Wood'},Look='Log fort: a row of round logs with sharp tips along the whole wall, two log rails across them, moss at the foot, ivy here and there.'},
 {Stage=6,Id='jungle',Name='Jungle',Z0=80,Z1=530,Key={44,146,100},Ground={{70,120,62},'Grass'},
  Wall={Color={104,120,96},Material='Cobblestone'},Look='Temple ruins: mossy stone, stepped temple tops, carved stone faces, a glyph band, leafy pillars, vines and bushes spilling over.'},
 {Stage=2,Id='desert',Name='Desert',Z0=530,Z1=1180,Key={228,192,112},Ground={{224,190,120},'Sand'},
  Wall={Color={226,198,140},Material='Sandstone'},Look='Sandstone temple: a big flared top lip, painted bands, pilasters with small gold-tipped obelisks, golden winged suns and carved doors.'},
 {Stage=3,Id='snow',Name='Snow',Z0=1180,Z1=2030,Key={170,208,232},Ground={{236,242,248},'Snow'},
  Wall={Color={168,204,226},Material='Brick'},Look='Ice bricks: pale blue brick, ice pillars, a soft lumpy snow cap, icicles under it and snow drifts at the foot.'},
 {Stage=4,Id='lava',Name='Lava',Z0=2030,Z1=3080,Key={236,108,34},Ground={{52,44,46},'Basalt'},
  Wall={Color={56,48,50},Material='Basalt'},Look='Volcano rock: dark basalt, a jagged rocky top, glowing cracks, a glowing seam at the foot and lava dripping under the top.'},
 {Stage=5,Id='crystal',Name='Crystal',Z0=3080,Z1=4380,Key={150,108,208},Ground={{86,68,120},'Slate'},
  Wall={Color={98,78,134},Material='Slate'},Look='Crystal cave stone: deep purple stone, crystal clusters growing on top, glowing pillar stripes and a glow line, crystals in the wall.'},
 {Stage=7,Id='storm',Name='Storm Peaks',Z0=4380,Z1=5980,Key={108,118,156},Ground={{60,66,80},'Slate'},
  Wall={Color={68,78,98},Material='Slate'},Look='Storm fort: dark slate, broken teeth on top, buttresses with copper lightning rods and glowing tips, big lightning bolts.'},
}
D.ByStage={};for i,b in ipairs(D.Biomes)do b.Order=i;D.ByStage[b.Stage]=b end
D.EndZ=5980
-- Keep-out on the wall faces (no pillar or bay piece in these spans; flat bands under 0.7 proud only):
D.KeepClear={
 {Side=-1,Z0=972,Z1=1038,Why='Desert walkway (4.5 studs) between the pyramid and the left wall'},
}
local function clear(s,z,half)
 for _,k in ipairs(D.KeepClear)do if k.Side==s and z+half>k.Z0 and z-half<k.Z1 then return false end end
 return true
end
-- Evenly spaced piers between a stretch's ends (the border towers stand on the ends) and the bays between them.
local function rhythm(z0,z1,pitch)
 local n=math.max(2,math.floor((z1-z0)/pitch+.5));local step=(z1-z0)/n
 local piers,bays={},{}
 for k=1,n-1 do piers[#piers+1]=z0+k*step end
 for k=0,n-1 do bays[#bays+1]=z0+(k+.5)*step end
 return piers,bays,step
end
local BORDER=5.8 -- half the border tower (cap) width: the pieces of a biome stay this far from its ends
-- "Bay" pieces (vines, faces, suns, doors, icicles, cracks, studs, bolts) are tagged; the lite version (phones on low) leaves them out.
local BAY={bay=true}

local W={} -- per-biome wall builders: W[id](s, z0, z1)
function W.forest(s,z0,z1)
 local woods={{116,82,52},{104,74,48},{126,92,60},{110,78,50}}
 local cut={176,134,90}
 local za,zb=-93.5,z1-BORDER -- the gatehouse (Y 44 - 58) and the rook tower bases stand on the first studs
 local d,pitch=3.8,3.6
 local n=math.floor((zb-za-d)/pitch)+1;local first=za+(zb-za-(n-1)*pitch)/2
 for i=0,n-1 do
  local z=first+i*pitch
  local top=53.2+((i*7)%5)*.55 -- tops at 5 heights: a hand-made fence
  vcyl('Log',s*(IN-.7),z,5.3,top,d,woods[i%4+1],'Wood')
  spike('Log tip',{s*(IN-.7),top,z},{0,1,0},{0,0,1},2.6,d,d*.9,cut,'Wood')
 end
 -- two rails tied across the logs, a mossy bank over their feet
 for _,y in ipairs({17,43})do cyl('Log rail',zb-za,1.6,cf(s*(IN-2.9),y,(za+zb)/2,ALONG_Z),{88,62,40},'Wood')end
 face('Moss bank',s,za-1,zb,5.3,7.4,3.0,{82,132,62},'Grass')
 local _,bays=rhythm(za,zb,30)
 for i,z in ipairs(bays)do
  local h=12+(i*7)%10
  face('Ivy',s,z-.6,z+.6,50.4-h,50.4,2.75,{62,128,58},'LeafyGrass',BAY)
  ball('Ivy leaves',3.2,s*(IN-2.6),50.4-h,z,{78,150,66},'LeafyGrass',BAY)
 end
end
function W.jungle(s,z0,z1)
 local stone,dark,moss={112,128,100},{78,96,72},{70,124,62}
 face('Stone foot',s,z0,z1,5.5,11,1.0,dark,'Cobblestone')
 face('Glyph band',s,z0,z1,27,31.5,.7,{126,134,104},'Slate')
 face('Top step',s,z0,z1,46.6,49,1.5,{100,116,90},'Slate')
 wrap('Temple top',s,z0,z1,49,52.6,.8,.5,stone,'Cobblestone')
 -- stepped temple crenels along the top (two blocks: a wide one and a narrow one on it)
 local _,crenels=rhythm(z0+BORDER,z1-BORDER,22.5)
 for _,z in ipairs(crenels)do
  box('Temple step',s*(IN-.6),s*(IN+3.6),52.6,55,z-3.4,z+3.4,stone,'Cobblestone')
  box('Temple step top',s*(IN+.2),s*(IN+2.8),55,57.2,z-1.6,z+1.6,{124,140,110},'Cobblestone')
 end
 local piers,bays=rhythm(z0+BORDER,z1-BORDER,45)
 for _,z in ipairs(piers)do
  face('Temple pillar',s,z-2.6,z+2.6,5.3,50.4,2.1,{96,116,88},'Slate')
  ball('Leaf crown',6.4,s*(IN-1),55.8,z,{58,124,58},'LeafyGrass')
 end
 for i,z in ipairs(bays)do
  face('Glyph tile',s,z-1.6,z+1.6,27.75,30.75,.95,{70,90,64},'Slate',BAY)
  if i%2==1 then -- a carved stone face: a slab, a brow, two eyes and a mouth
   face('Stone face',s,z-4.5,z+4.5,12,21,.6,{120,132,106},'Slate',BAY)
   face('Stone brow',s,z-4.8,z+4.8,19,20.4,1.0,{100,114,90},'Slate',BAY)
   for _,dz in ipairs({-2,2})do face('Stone eye',s,z+dz-1,z+dz+1,16.4,18.2,.85,{36,44,34},'Slate',BAY)end
   face('Stone mouth',s,z-2.4,z+2.4,13,14.4,.85,{36,44,34},'Slate',BAY)
  end
  local a=14+(i*7)%9
  face('Vine',s,z+8-.5,z+8+.5,46.6-a,46.6,1.65,{43,108,56},'LeafyGrass',BAY)
  ball('Vine leaves',3,s*(IN-1.4),46.6-a,z+8,{61,129,62},'LeafyGrass',BAY)
  egg('Overgrowth',{5,4.2,10},s*(IN+1.4),53.4,z-9+(i%3)*2,moss,'LeafyGrass',BAY)
 end
end
function W.desert(s,z0,z1)
 face('Sandstone foot',s,z0,z1,5.5,9.4,.6,{198,164,108},'Sandstone')
 face('Painted band',s,z0,z1,31,32.2,.3,{178,98,62},'Slate')
 face('Turquoise band',s,z0,z1,32.6,33.6,.25,{60,168,168},'SmoothPlastic')
 face('Painted band',s,z0,z1,34,35.2,.3,{178,98,62},'Slate')
 face('Lip line',s,z0,z1,46.6,47.4,.5,{60,168,168},'SmoothPlastic')
 face('Lip shadow',s,z0,z1,47.4,48.8,1.0,{204,170,112},'Sandstone')
 wrap('Top lip',s,z0,z1,48.8,51.8,2.0,.6,{240,216,164},'Sandstone')
 local piers,bays=rhythm(z0+BORDER,z1-BORDER,65)
 for _,z in ipairs(piers)do if clear(s,z,4)then
  face('Pilaster',s,z-3,z+3,5.3,46.6,1.3,{214,182,124},'Sandstone')
  face('Turquoise tile',s,z-1.5,z+1.5,14,17,1.55,{52,160,170},'SmoothPlastic')
  box('Obelisk',s*(IN-1.6),s*(IN+.8),51.8,58.2,z-1.2,z+1.2,{232,206,150},'Sandstone')
  spike('Obelisk tip',{s*(IN-.4),58.2,z},{0,1,0},{0,0,1},2.6,2.4,2.4,{236,190,92},'SmoothPlastic')
 end end
 for _,z in ipairs(bays)do
  -- a golden winged sun high in every bay (a disc and two turquoise wings)
  cyl('Sun disc',.6,4.4,cf(s*(IN-.9+.3),40.5,z,ALONG_X),{240,196,84},'SmoothPlastic',BAY)
  for _,dir in ipairs({-1,1})do tooth('Sun wing',{s*(IN-.1),41.7,z+dir*2.1},{0,-1,0},{0,0,1},2.4,7,.8,dir,{52,160,170},'SmoothPlastic',BAY)end
  if clear(s,z,6)then -- a carved door below it (not on the pyramid walkway)
   face('Carved door',s,z-3.2,z+3.2,9.4,22,.25,{176,136,88},'Sandstone',BAY)
   face('Door lintel',s,z-4.4,z+4.4,22,23.6,.7,{204,170,112},'Sandstone',BAY)
  end
 end
end
function W.snow(s,z0,z1)
 face('Ice band',s,z0,z1,27,28.4,.4,{140,188,214},'Ice')
 face('Snow drift',s,z0,z1,5.5,9,1.6,{236,242,248},'Snow')
 wrap('Snow cap',s,z0,z1,50.2,52.6,1.5,.6,{240,246,250},'Snow')
 -- soft lumps all along the cap
 local _,lumps=rhythm(z0+BORDER,z1-BORDER,26)
 for i,z in ipairs(lumps)do egg('Snow pillow',{8.6,4.6+(i%3)*.8,24},s*(IN+1.7),52.6,z,{246,250,252},'Snow')end
 local piers,bays=rhythm(z0+BORDER,z1-BORDER,50)
 for _,z in ipairs(piers)do
  face('Ice pillar',s,z-2.5,z+2.5,5.3,50.2,1.2,{150,196,222},'Ice')
  egg('Snow mound',{5,6,16},s*(IN-.6),8.6,z,{246,250,252},'Snow')
 end
 for i,z in ipairs(bays)do
  local L={5.5+(i%3),8.5+(i*3)%3,5+(i%2)*1.5}
  for k,dz in ipairs({-9,0,9})do
   tooth('Icicle',{s*(IN-1.0),50.2,z+dz},{0,-1,0},{0,0,1},L[k],1.4,.9,(k%2==0)and 1 or-1,{204,232,246},'Ice',BAY)
  end
 end
end
function W.lava(s,z0,z1)
 face('Basalt foot',s,z0,z1,5.5,9.2,1.0,{40,34,36},'Basalt')
 face('Ember seam',s,z0,z1,9.2,9.6,.7,{255,106,36},'Neon')
 face('Under glow',s,z0,z1,49.4,49.9,.5,{255,96,30},'Neon')
 wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')
 -- a jagged rocky crest: teeth of five heights leaning both ways
 local _,teeth=rhythm(z0+BORDER,z1-BORDER,20)
 for i,z in ipairs(teeth)do
  local h=2.6+((i*7)%5)*1.1
  tooth('Rock tooth',{s*(IN+.9),52.4,z},{0,1,0},{0,0,1},h,4.2+(i%3),3.4,(i%2==0)and 1 or-1,{58,50,52},'Basalt')
 end
 local piers,bays=rhythm(z0+BORDER,z1-BORDER,60)
 for _,z in ipairs(piers)do face('Basalt column',s,z-2.5,z+2.5,5.3,49.4,1.6,{50,44,46},'Basalt')end
 for i,z in ipairs(bays)do
  zigzag('Glowing crack',s,z-3+(i%3)*2,28+(i%2)*6,2,9,.6,.12,.42,{255,122,40},'Neon',BAY)
  if i%2==0 then face('Lava drip',s,z+9,z+9.6,44.5-(i%3)*2,49.4,.46,{255,110,36},'Neon',BAY)end
 end
end
function W.crystal(s,z0,z1)
 face('Stone foot',s,z0,z1,5.5,10,1.0,{74,60,104},'Slate')
 face('Glow line',s,z0,z1,22,22.5,.3,{206,150,255},'Neon')
 wrap('Stone top',s,z0,z1,49.8,52.2,1.1,.5,{112,92,150},'Slate')
 local cols={{186,150,236},{140,206,242},{232,160,226}}
 local piers,bays=rhythm(z0+BORDER,z1-BORDER,100)
 local function cluster(z,n,k)
  local x=s*(IN+1.2)
  shard('Crystal',x,51.6,z,19+(k%3)*3,6,s*.12,.08*((k%2)*2-1),cols[k%3+1],'SmoothPlastic')
  shard('Crystal',x,51.6,z+4.4,12,4.4,s*.34,-.34,cols[(k+1)%3+1],'SmoothPlastic',nil,1)
  if n==3 then shard('Crystal',x,51.6,z-4.4,10,4,s*.4,.38,cols[(k+2)%3+1],'SmoothPlastic',nil,-1)end
 end
 for i,z in ipairs(piers)do
  face('Crystal pillar',s,z-2.5,z+2.5,5.3,49.8,1.4,{86,68,120},'Slate')
  face('Glow stripe',s,z-.4,z+.4,12,46,1.55,{222,170,255},'Neon')
  cluster(z,3,i)
 end
 for i,z in ipairs(bays)do
  if i%2==0 then cluster(z,2,i+1)end
  shard('Wall crystal',s*(IN+.6),15+(i%3)*4,z-12+(i%2)*6,5,2.2,s*.95,(i%2==0)and .3 or-.3,(i%2==0)and cols[2]or cols[3],'Neon',BAY)
 end
end
function W.storm(s,z0,z1)
 face('Slate foot',s,z0,z1,5.5,10,1.0,{52,60,76},'Slate')
 face('Copper band',s,z0,z1,30,30.8,.35,{184,108,64},'Metal')
 wrap('Slate top',s,z0,z1,49.8,52.2,1.2,.5,{84,94,114},'Slate')
 local piers,bays,step=rhythm(z0+BORDER,z1-BORDER,100)
 for _,z in ipairs(piers)do
  face('Buttress',s,z-3,z+3,5.3,55,1.8,{60,70,88},'Slate')
  face('Copper strap',s,z-.4,z+.4,10,55.3,1.95,{190,112,66},'Metal')
  vcyl('Lightning rod',s*(IN-.6),z,55,65,.6,{196,120,70},'Metal')
  ball('Charged tip',1.8,s*(IN-.6),65.6,z,{176,220,255},'Neon')
 end
 for i,z in ipairs(bays)do
  -- broken battlement teeth between the buttresses
  for k,dz in ipairs({-step/4,step/4})do
   local h=2+((i*3+k*5)%4)*.9
   box('Slate tooth',s*(IN-.6),s*(IN+3),52.2,52.2+h,z+dz-2.6,z+dz+2.6,{74,84,104},'Slate')
  end
  if i%2==0 then zigzag('Lightning bolt',s,z+1,44,3,9,.8,.14,.5,{186,220,255},'Neon',BAY)end
 end
end
-- The end wall (z 5980, its face looks back down the track): the Storm bands across it, two buttresses with rods and one big bolt.
local function endWall()
 local z=D.EndZ;local x0,x1=-(IN-1.2),IN-1.2
 box('Slate foot',x0,x1,5.5,10,z-1.0,z+SINK,{52,60,76},'Slate')
 box('Copper band',x0,x1,30,30.8,z-.35,z+SINK,{184,108,64},'Metal')
 box('Slate top',x0,x1,49.8,52.2,z-1.2,z+5.5,{84,94,114},'Slate')
 for _,x in ipairs({-30,30})do
  box('Buttress',x-3,x+3,5.3,55,z-1.8,z+SINK,{60,70,88},'Slate')
  box('Copper strap',x-.4,x+.4,10,55.3,z-1.95,z+SINK,{190,112,66},'Metal')
  vcyl('Lightning rod',x,z-.6,55,65,.6,{196,120,70},'Metal')
  ball('Charged tip',1.8,x,65.6,z-.6,{176,220,255},'Neon')
 end
 for _,x in ipairs({-60,-15,15,60})do box('Slate tooth',x-2.6,x+2.6,52.2,55+math.abs(x)%3,z-.6,z+3,{74,84,104},'Slate')end
 local cz,cy=0,44
 for i=1,3 do
  local a=(i%2==1)and .5 or-.5;local dx,dy=math.sin(a)*10,-math.cos(a)*10
  block('Lightning bolt',{.9,10.5,.25+.04*i},cf(cz+dx/2,cy+dy/2,z-(.25+.04*i)/2+.1,Rz(a)),{186,220,255},'Neon',BAY)
  cz,cy=cz+dx,cy+dy
 end
end
-- Border towers where two biomes meet (they also hide the seam between two wall styles): plain stone, a glowing band in the NEXT biome's colour.
local function borderTower(s,z,nextKey)
 face('Border tower',s,z-5,z+5,5.3,60,2.4,{112,106,100},'Cobblestone')
 box('Border band',s*(IN-2.6),s*(IN+.6),40,41.4,z-5.2,z+5.2,nextKey,'Neon') -- (sunk deeper than the tower: their backs never share a plane)
 box('Border tower cap',s*(IN-3),s*(OUT+.8),60,61.6,z-5.8,z+5.8,{134,128,120},'Slate')
end

function D.TrackWalls(opt)
 opt=opt or{};out={}
 for i,b in ipairs(D.Biomes)do
  group='TrackWalls158/'..b.Name
  for _,s in ipairs({-1,1})do W[b.Id](s,b.Z0,b.Z1)end
  if b.Id=='storm'then endWall()end
  local nb=D.Biomes[i+1]
  if nb then group='TrackWalls158/Border '..b.Name..' - '..nb.Name;for _,s in ipairs({-1,1})do borderTower(s,b.Z1,nb.Key)end end
 end
 for _,p in ipairs(out)do if math.max(p.Size[1],p.Size[2],p.Size[3])<20 then p.Shadow=false end end -- (small decorations cast no shadow)
 if opt.Lite then local keep={};for _,p in ipairs(out)do if not p.Bay then keep[#keep+1]=p end end;out=keep end
 return out
end
-- What the build step changes on the saved wall parts (Obby/BiomeWalls/Biome_<stage>_LeftWall / _RightWall; the end wall takes Storm's).
function D.Restyle()
 local r={}
 for _,b in ipairs(D.Biomes)do
  for _,side in ipairs({'LeftWall','RightWall'})do r['Obby/BiomeWalls/Biome_'..b.Stage..'_'..side]={Color=b.Wall.Color,Material=b.Wall.Material}end
 end
 r['Obby/BiomeWalls/Biome_5_EndWall']={Color=D.ByStage[7].Wall.Color,Material=D.ByStage[7].Wall.Material}
 return r
end

-------------------------------------------------------------------------------------------------------------------------------- outer track
-- Outside the walls: a ground under it all (today there is nothing: no terrain, no floor), and per biome a few big, simple shapes that rise
-- over the walls. Rules: never inside |x| 94 (the walls) and never over the hub (z < -99); no shadows, no collision of any kind.
-- What the track sees: a camera 25 high in the middle sees over the wall top (51 at |x| 89) only what is higher than about 25 + 0.29 |x|,
-- so trees right behind the wall need ~75+ and far mountains ~150+.
local B={}
local function ground(b,z0,z1)
 for _,s in ipairs({-1,1})do box('Outer ground',s*OUT,s*(OUT+1950),FLOOR-1.4,FLOOR-.4,z0,z1,b.Ground[1],b.Ground[2],{shadow=false})end
end
local function oak(x,z,top,crown,color)
 vcyl('Trunk',x,z,FLOOR-.4,top-crown*.25,4.6,{96,68,44},'Wood',{shadow=false})
 ball('Crown',crown,x,top-crown*.5,z,color,'LeafyGrass',{shadow=false})
 ball('Crown',crown*.72,x+(x>0 and 1 or-1)*crown*.28,top-crown*.62,z-crown*.22,{color[1]+14,color[2]+16,color[3]+8},'LeafyGrass',{shadow=false})
end
function B.forest()
 for _,t in ipairs({{-122,-56,84,30},{-136,8,90,34},{-120,56,80,28},{-168,-24,96,40},{-164,44,92,36},{-216,10,104,44},
                    {124,-44,86,32},{132,16,82,28},{124,64,90,32},{170,-12,98,40},{166,50,100,38},{220,24,106,44}})do
  oak(t[1],t[2],t[3],t[4],(t[4]>35)and{62,132,58}or{76,150,64})
 end
end
function B.jungle()
 for _,t in ipairs({{-130,140},{-140,300},{-128,460},{132,190},{142,360},{130,500}})do
  local x,z=t[1],t[2];local h=88+(z%3)*5
  vcyl('Giant trunk',x,z,FLOOR-.4,h,7,{88,64,44},'Wood',{shadow=false})
  cyl('Canopy',7,48,cf(x,h,z,UPRIGHT),{52,124,58},'LeafyGrass',{shadow=false})
  cyl('Canopy top',6,30,cf(x+3,h+6.5,z-2,UPRIGHT),{70,146,66},'LeafyGrass',{shadow=false})
 end
 -- a stepped temple far left
 local x,z=-320,320
 for k=0,4 do local w=140-k*26;box('Temple step',x-w/2,x+w/2,FLOOR-.4+k*24,FLOOR-.4+(k+1)*24,z-w/2,z+w/2,(k%2==0)and{120,128,104}or{106,116,92},'Cobblestone',{shadow=false})end
 box('Temple shrine',x-10,x+10,FLOOR-.4+120,FLOOR-.4+138,z-10,z+10,{136,140,114},'Cobblestone',{shadow=false})
 box('Shrine roof',x-12,x+12,FLOOR-.4+138,FLOOR-.4+141,z-12,z+12,{96,104,82},'Cobblestone',{shadow=false})
 -- a mossy cliff with a waterfall far right (the water faces the track), a pool at its foot
 box('Waterfall cliff',300,370,FLOOR-.4,FLOOR+150,200,300,{78,96,82},'Slate',{shadow=false})
 box('Cliff moss',298,372,FLOOR+150,FLOOR+156,198,302,{70,124,62},'LeafyGrass',{shadow=false})
 box('Waterfall',299,300,FLOOR+2,FLOOR+150,240,262,{150,212,240},'SmoothPlastic',{shadow=false,t=.1})
 egg('Waterfall pool',{40,3,56},284,FLOOR-.3,251,{110,190,226},'SmoothPlastic',{shadow=false})
end
function B.desert()
 for _,d in ipairs({{-300,640,340,170,400},{-290,1090,320,150,360},{300,600,340,180,420},{290,1130,320,150,360},{-500,860,420,230,480}})do
  egg('Dune',{d[3],d[4],d[5]},d[1],FLOOR-.4,d[2],{232,198,128},'Sand',{shadow=false})
 end
 for _,o in ipairs({{150,820,110},{-150,1150,96}})do
  local x,z,h=o[1],o[2],o[3]
  box('Obelisk',x-4.5,x+4.5,FLOOR-.4,FLOOR+h,z-4.5,z+4.5,{236,206,150},'Sandstone',{shadow=false})
  cone4('Obelisk tip',x,FLOOR+h,z,12,9,{232,186,90},'SmoothPlastic',{shadow=false})
 end
 -- the great pyramid far away on the right: stepped like the game's own Classic Pyramid
 local x,z,n,w0,step=470,960,10,320,20
 for k=0,n-1 do local w=w0-k*w0/n;box('Great pyramid',x-w/2,x+w/2,FLOOR-.4+k*step,FLOOR-.4+(k+1)*step,z-w/2,z+w/2,(k%2==0)and{222,190,128}or{212,180,120},'Sandstone',{shadow=false})end
end
-- a snowy fir: a tall egg of dark green on a short trunk, a cap of snow on top
local function fir(x,z,h)
 vcyl('Fir trunk',x,z,GROUND,GROUND+h*.25,3.4,{86,64,48},'Wood',{shadow=false})
 egg('Fir',{h*.3,h*.78,h*.3},x,GROUND+h*.56,z,{46,90,78},'Grass',{shadow=false})
 egg('Fir snow',{h*.2,h*.24,h*.2},x,GROUND+h*.88,z,{236,244,248},'Snow',{shadow=false})
end
function B.snow()
 for _,p in ipairs({{-134,1300,100},{-150,1520,112},{-136,1700,104},{-146,1920,110},{138,1400,108},{134,1600,100},{150,1820,114},{136,2000,104}})do fir(p[1],p[2],p[3])end
 for _,m in ipairs({{-440,1420,230,.3},{-500,1860,262,1.1},{430,1340,220,2},{500,1800,270,.8}})do
  mountain('Mountain',m[1],m[2],m[3],m[4],{122,140,160},'Slate',.36,{242,248,252},'Snow')
 end
end
function B.lava()
 for _,v in ipairs({{480,2560,250,.5,30},{-360,2280,170,1.7,18},{-380,2860,180,.9,20},{430,2160,150,2.6,0}})do
  local x,z,peak,yaw,glow=v[1],v[2],v[3],v[4],v[5]
  local dir=x>0 and-1 or 1
  local _,r=mountain(glow>0 and'Volcano'or'Rock peak',x,z,peak,yaw,{52,44,46},'Basalt')
  if glow>0 then
   ball('Crater glow',glow,x,peak,z,{255,110,40},'Neon',{shadow=false})
   faceStrip('Lava stream',x,z,peak,r,dir,peak*.62,glow*.5,-glow*.5,{255,100,34},'Neon')
   faceStrip('Lava stream',x,z,peak,r,dir,peak*.45,glow*.4,glow*.55,{255,132,48},'Neon')
  end
 end
end
function B.crystal()
 local spires={{-122,3200,14,100,{170,130,230}},{-156,3560,18,136,{130,190,240}},{-128,3900,12,90,{210,150,230}},{-174,4250,20,146,{170,130,230}},
  {126,3320,16,116,{130,190,240}},{164,3720,20,146,{170,130,230}},{122,4050,12,92,{210,150,230}},{156,4320,16,126,{130,190,240}}}
 for i,c in ipairs(spires)do spire('Crystal spire',c[1],c[2],c[3],c[4],((i%2==0)and 1 or-1)*.1*(c[1]>0 and 1 or-1),c[5],'SmoothPlastic')end
 for _,m in ipairs({{-440,3700,230,.4},{460,4000,240,1.3},{-420,4250,200,2.2}})do
  mountain('Purple mountain',m[1],m[2],m[3],m[4],{92,72,128},'Slate',.3,{186,150,236},'SmoothPlastic')
 end
end
function B.storm()
 for _,p in ipairs({{-460,4600,230,.2},{-520,5150,270,1.4},{-450,5700,220,2.4},{480,4800,250,.9},{500,5350,256,1.9},{470,5860,236,.4}})do
  mountain('Dark peak',p[1],p[2],p[3],p[4],{62,70,86},'Slate',.28,{120,130,150},'Slate')
 end
 for _,t in ipairs({{-140,5000},{140,5500}})do
  local x,z=t[1],t[2]
  vcyl('Lightning tower',x,z,FLOOR-.4,FLOOR+136,3,{184,108,64},'Metal',{shadow=false})
  ball('Tower ball',7,x,FLOOR+139,z,{176,220,255},'Neon',{shadow=false})
  for k,seg in ipairs({{0,214,40,.42},{-6,180,34,-.5},{2,151,28,.38}})do
   block('Lightning bolt',{1,seg[3],1.6},cf(x,seg[2],z+seg[1],Rx(seg[4])),{200,228,255},'Neon',{shadow=false})
  end
 end
  -- the storm mountain behind the end wall (seen all the way down the Storm stretch), lightning over it
 mountain('End peak',0,6560,300,.25,{56,62,78},'Slate',.26,{120,130,150},'Slate')
 for k,seg in ipairs({{-40,300,60,.5},{-12,248,52,-.45},{-30,205,40,.4}})do
  block('Lightning bolt',{2,seg[3],2},cf(seg[1],seg[2],6080,Rz(seg[4])),{200,228,255},'Neon',{shadow=false})
 end
end
function D.Backdrops()
 out={}
 for i,b in ipairs(D.Biomes)do
  group='TrackBackdrops158/'..b.Name
  ground(b,i==1 and-99 or b.Z0,b.Id=='storm'and D.EndZ+5 or b.Z1)
  if b.Id=='storm'then -- behind the end wall
   box('Outer ground',-1000,1000,FLOOR-1.4,FLOOR-.4,D.EndZ+5,D.EndZ+1905,b.Ground[1],b.Ground[2],{shadow=false})
  end
  B[b.Id]()
 end
 return out
end

-------------------------------------------------------------------------------------------------------------------------------- base walls
-- The hub walls (HubDecorKit151, R152): five saved wall parts 48 tall (top Y 51), a chess-rook battlement of 218 square merlons 5 x 6 x 5 (one
-- every ~10 studs, one on each outer corner), the gatehouse (12 + 5 merlons) and two rook towers (8 merlons each). Section frames copied from
-- HubDecorKit151.Sections (s runs along the inner face, d out of it into the hub; local X = t, Y = up, Z = n).
local SEC={
 FrontXNeg={o={-94,0,-104},t={-1,0,0},n={0,0,-1},len=241},
 FrontXPos={o={335,0,-104},t={-1,0,0},n={0,0,-1},len=241},
 Back={o={-335,0,-618},t={1,0,0},n={0,0,1},len=670},
 SideXNeg={o={-335,0,-104},t={0,0,-1},n={1,0,0},len=514},
 SideXPos={o={335,0,-618},t={0,0,1},n={-1,0,0},len=514},
}
local ORDER={'FrontXNeg','FrontXPos','Back','SideXNeg','SideXPos'}
local function secCF(sec,s,y,d)
 local p={sec.o[1]+sec.t[1]*s+sec.n[1]*d,y,sec.o[3]+sec.t[3]*s+sec.n[3]*d}
 return cf(p[1],p[2],p[3],axes(sec.t,{0,1,0},sec.n))
end
local function merlonSpots() -- HubDecorKit151.MerlonSpots
 local r={}
 local function run(name,s0,s1,n,first,last)for i=first,last do r[#r+1]={Sec=name,S=s0+(s1-s0)*i/n,I=i}end end
 run('FrontXPos',-2.5,227.5,23,0,23);run('FrontXNeg',13.5,243.5,23,0,23)
 run('SideXPos',-2.5,516.5,52,1,51);run('SideXNeg',-2.5,516.5,52,1,51)
 run('Back',-2.5,672.5,67,0,67)
 return r
end
D.MerlonSpots=merlonSpots
local STONE,DARK,GOLD,PLASTER,CREAM,PIL={178,166,147},{150,138,120},{244,196,86},{243,231,206},{252,244,226},{229,210,172}
-- A band along every section's inner face, `depth` out of it (SINK into the wall); the side bands stop at the front / back bands (as HubDecor151's own do).
-- `back` > 0 carries it over the wall top to `back` past the outer face (a coping).
local function strip(name,y0,y1,depth,color,mat,back)
 local d0=back and-(5+back)or-SINK
 for _,k in ipairs(ORDER)do local sec=SEC[k]
  local s0,s1=0,sec.len
  if k:find('^Side')then s0,s1=depth-SINK,sec.len-(depth-SINK)end
  if back then -- over the corner squares too (the side walls own them); the front walls' other end is the gate tower
   if k=='Back'then s0,s1=-5-back,sec.len+5+back elseif k=='FrontXNeg'then s1=sec.len+5+back elseif k=='FrontXPos'then s0=-5-back end
  end
  block(name,{s1-s0,y1-y0,depth-d0},secCF(sec,(s0+s1)/2,(y0+y1)/2,(depth+d0)/2),color,mat)
 end
end
local GATE={zc=-100,top=59.3,keepTop=67.3}
local function gatehouseMerlons(fn) -- fn(x, y0 (its foot), w, depth)
 for k=3,8 do for _,sx in ipairs({-1,1})do fn(sx*(k*10+5),GATE.top,5,9)end end
 for k=-2,2 do fn(k*10,GATE.keepTop,5,7)end
end
local function rookMerlons(fn) -- fn(x, y0, z, out direction)
 for _,x in ipairs({-99,99})do for k=0,7 do
  local a=(k+.5)*math.pi/4;local o={math.cos(a),0,math.sin(a)}
  fn(x+o[1]*6.6,68.4,-100+o[3]*6.6,o)
 end end
end
-- a cap on every merlon (wall, gatehouse, keep, rook towers): .5 wider than the merlon all round, `h` thick
local function caps(capColor,mat,wallH,wallD,h)
 h=h or .8
 for _,m in ipairs(merlonSpots())do
  local sec=SEC[m.Sec];local d0,d1=-5,wallD or 0
  block('Merlon cap',{6,h,d1-d0+1},secCF(sec,m.S,wallH+h/2,(d0+d1)/2),capColor,mat)
 end
 gatehouseMerlons(function(x,y0,w,dz)block('Merlon cap',{w+1,h,dz+1},cf(x,y0+6+h/2,GATE.zc),capColor,mat)end)
 rookMerlons(function(x,y0,z,o)
  local Z={-o[1],0,-o[3]};local X=cross({0,1,0},Z)
  block('Merlon cap',{4.2,h*.8,4.2},cf(x,y0+5.4+h*.4,z,axes(X,{0,1,0},Z)),capColor,mat)
 end)
end
D.BaseOptions={
 A={Title='Stone caps',Look='A stone cap on every merlon and a stone coping along the whole wall top (inside and out), with a thin dark line under it. Calm and solid: the closest to what you have.'},
 B={Title='Rook crown',Look='The wall top flares out like the rook towers at the gate: a collar, a dark step and a wide crown band on stone corbels, with the merlons standing on the crown and capped.'},
 C={Title='Lantern walk',Look='Stone caps, a stone walkway ledge on brackets along the inside with a cream lip, and small lanterns on it that glow warm at dusk and in cloudy weather.'},
}
function D.BaseWalls(option)
 out={};local hide={}
 group='BaseWalls158/'..option
 if option=='A'then
  caps(DARK,'Slate',57)
  strip('Wall coping',50.4,51.6,1.4,STONE,'Cobblestone',.5)
  strip('Coping shadow',49.6,50.4,.9,DARK,'Slate')
 elseif option=='B'then
  -- the crown band (proud 2.2) carries rebuilt merlons that stand on its rim; the pilasters (proud 2.0) run up into it
  hide[#hide+1]='HubDecor151/Walls/Wall merlon'
  strip('Crown band',47.6,51.6,2.2,PIL,'Plaster',.5)
  strip('Crown flare',46.2,47.6,1.5,DARK,'Slate')
  strip('Crown collar',45.0,46.2,.9,STONE,'Cobblestone')
  for _,m in ipairs(merlonSpots())do
   local sec=SEC[m.Sec]
   block('Wall merlon',{5,6,7.2},secCF(sec,m.S,51.6+3,-1.4),PLASTER,'Plaster',{shadow=false})
   if not(m.Sec:find('^Side')and(m.I==0))then block('Crown corbel',{1.8,3.0,1.85+SINK},secCF(sec,m.S,44.6+1.5,(1.85-SINK)/2),STONE,'Cobblestone')end
  end
  caps(STONE,'Cobblestone',57.6,2.2)
 elseif option=='C'then
  caps(DARK,'Slate',57)
  strip('Walkway ledge',49.0,51.3,2.9,STONE,'Cobblestone')
  for _,k in ipairs(ORDER)do local sec=SEC[k] -- a cream lip on the ledge's front edge (the side lips stop at the front / back ones)
   local s0,s1=0,sec.len
   if k:find('^Side')then s0,s1=2.9,sec.len-2.9 end
   block('Ledge lip',{s1-s0,.6,.5},secCF(sec,(s0+s1)/2,51.6,2.65),CREAM,'SmoothPlastic')
  end
  -- brackets under the ledge at every other merlon, lanterns on the ledge in every fourth crenel (the gap after a merlon)
  local spots=merlonSpots()
  for i,m in ipairs(spots)do
   local sec=SEC[m.Sec];local nxt=spots[i+1]
   if m.I%2==1 then block('Ledge bracket',{1.8,2.6,2.6},secCF(sec,m.S,46.4+1.3,.9),STONE,'Cobblestone')end
   if i%4==2 and nxt and nxt.Sec==m.Sec then
    local s=(m.S+nxt.S)/2
    block('Lantern post',{.5,1.6,.5},secCF(sec,s,51.3+.8,1.5),{44,84,76},'Metal')
    block('Lantern',{1.4,1.9,1.4},secCF(sec,s,51.3+1.6+.95,1.5),{255,206,128},'Neon')
    block('Lantern roof',{2,.45,2},secCF(sec,s,51.3+1.6+1.9+.225,1.5),{44,84,76},'Metal')
   end
  end
 end
 for _,p in ipairs(out)do if math.max(p.Size[1],p.Size[2],p.Size[3])<20 then p.Shadow=false end end -- (caps, corbels, lanterns: no shadow, like the merlons)
 return out,hide
end
return D
