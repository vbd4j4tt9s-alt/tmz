--!nocheck
-- R158 track walls, outer ground and base wall caps: the PART DATA (owner approved docs/proposals/R158/design/: "look into designing each of the track walls and also the outer
-- track designs can be added and so on and also polish up the base walls especially the top"; base walls: option A, stone caps).
-- Pure Luau (no Roblox API, no randomness from the engine): every builder returns a list of part SPECS and TrackWalls158 turns each into an Instance. So the same data can be
-- counted, checked and drawn in the offline suites (docs/proposals/R158/tests) exactly as the server builds it.
--   {Group=, Name=, Shape='Block'|'Wedge'|'Cylinder'|'Ball', Size={x,y,z}, CF={x,y,z, R00,R01,R02, R10,R11,R12, R20,R21,R22}, Color={r,g,b}, Material='Slate'|..., Transparency=0,
--    Mesh='Sphere' (a SpecialMesh; the walls make none: no ball, egg or sphere is built for any wall), Shadow=false, Bay=true}
--   CF is CFrame:GetComponents() order, so CFrame.new(table.unpack(spec.CF)) rebuilds it. Shadow=false: only parts 20+ studs long cast a shadow. Bay=true: a small extra (vines, faces,
--   suns, doors, icicles, cracks, bolts, ...) the lite version (D.TrackWalls({Lite=true})) leaves out.
--   EVERY part is Anchored, CanCollide false, CanQuery false, CanTouch false (TrackWalls158 sets that): nothing new to stand on, nothing the runner sweep, the camera, the pack placement
--   ray or a Touched event sees. No scripts; the glow is Neon; nothing moves.
-- NOT REPEATED (owner: "make sure the walls have no repetitive design as in like green balls on each wooden stick like forest"): every wall (biome x side) draws its details from its OWN
--   fixed seed (D.Seed), so the same server always builds the same wall and a rebuild is identical, but along the wall the rhythm is hand-made: posts / pillars / teeth are spaced
--   unevenly, details skip some posts and bunch up on others, sizes run 0.7 - 1.3 x, heights and leans differ, long bands are cut into runs in close shades, and now and then
--   something is broken (a short log, a missing crenel, a cracked face, a patch of moss). Nothing is random at run time.
-- Placement rules every part keeps (tests: docs/proposals/R158/tests): the track walls' inner face is |x| 89, outer |x| 94, Y 3 .. 51 (they keep their size, height and collision);
--   new pieces stand at most 3.2 studs into the track near the ground (Y < 12), 4.5 up to Y 45, 6 on the wall top, at most 1 stud past the outer face; nothing lower than Y 5.25
--   inside |x| 89.75 (the keyboard's keys reach 5.2); nothing in the gatehouse (z -104.5 .. -95.5, Y > 44); the Desert walkway (z 972 .. 1038 along the LEFT wall, 4.5 studs between the
--   R157 pyramid and the wall) only gets flat bands under 0.7 proud; the ground slabs stay outside the walls (|x| >= 94) and off the hub (z >= -99).
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

-------------------------------------------------------------------------------------------------------------------------------- seeded randomness
-- A small linear congruential generator (exact in doubles: 1664525 x 2^32 < 2^53): the same seed gives the same numbers on every server and in every test.
function D.Rng(seed)
 local st=(seed*2654435761+12345)%4294967296
 local R={}
 local function nxt()st=(st*1664525+1013904223)%4294967296;return st/4294967296 end
 nxt();nxt();nxt()
 function R.f()return nxt()end                                  -- [0, 1)
 function R.r(a,b)return a+(b-a)*nxt()end                       -- a .. b
 function R.i(a,b)return a+math.floor(nxt()*(b-a+1))end         -- whole number a .. b
 function R.chance(p)return nxt()<p end
 function R.pick(t)return t[1+math.floor(nxt()*#t)]end
 function R.sign()return nxt()<.5 and-1 or 1 end
 return R
end
-- One seed per wall: biome stage and side (-1 left, +1 right); the end wall and the border towers have their own.
function D.Seed(stage,side)return 158000+stage*100+(side<0 and 10 or 20)end
local function tint(R,c,amt)return{math.max(0,math.min(255,math.floor(c[1]+R.r(-amt,amt)+.5))),math.max(0,math.min(255,math.floor(c[2]+R.r(-amt,amt)+.5))),math.max(0,math.min(255,math.floor(c[3]+R.r(-amt,amt)+.5)))}end
-- Cut points about `pitch` apart between z0 and z1, each moved by up to `wob` of a step (wob <= .3 keeps them in order): the piers (inner cut points) and the bays {z=middle, w=width}.
local function spread(R,z0,z1,pitch,wob)
 local n=math.max(2,math.floor((z1-z0)/pitch+.5));local step=(z1-z0)/n
 local cuts={z0}
 for k=1,n-1 do cuts[#cuts+1]=z0+k*step+R.r(-wob,wob)*step end
 cuts[#cuts+1]=z1
 local piers,bays={},{}
 for k=2,#cuts-1 do piers[#piers+1]=cuts[k] end
 for k=1,#cuts-1 do bays[#bays+1]={z=(cuts[k]+cuts[k+1])/2,w=cuts[k+1]-cuts[k]}end
 return piers,bays
end
-- Runs of random length along z0 .. z1 (lengths lo .. hi, a gap of gl .. gh between runs; no gap when gh is 0): fn(a, b) for each.
local function runs(R,z0,z1,lo,hi,gl,gh,fn)
 local c=z0
 while c<z1-.5 do
  local b=math.min(z1,c+R.r(lo,hi));if z1-b<lo*.4 then b=z1 end
  fn(c,b)
  c=b+(gh>0 and R.r(gl,gh)or 0)
 end
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
-- (Owner: "remove those leaf balls, don't have plain balls or anything that might reduce the look of the walls": no ball, egg or sphere is made here any more, for any wall, and the
-- "Lava drip" pieces are gone; docs/proposals/R158/tests checks that no wall part is round or named like a ball / blob / leaf / drip. Every wall draws its pieces from its own fixed seed,
-- so the draws the removed pieces used to make are still made (spend): every piece that stays is exactly where and what it was.)
local function spend(R,n)for _=1,n do R.f()end end
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

-- The world-axis box of a spec's part (lo, hi: {x,y,z}), from its size and rotation. Exact for blocks; balls, cylinders and eggs use their box (they fit inside it).
function D.Extent(spec)
 local c,sz=spec.CF,spec.Size
 local e={}
 for i=1,3 do e[i]=(math.abs(c[3*i+1])*sz[1]+math.abs(c[3*i+2])*sz[2]+math.abs(c[3*i+3])*sz[3])/2 end
 return {c[1]-e[1],c[2]-e[2],c[3]-e[3]},{c[1]+e[1],c[2]+e[2],c[3]+e[3]}
end
-- The refresh cover (ReplicatedStorage.TrackBlackout: |x| <= 94, up to Y 55) hides the track while it refreshes. A wall piece that stands over its roof (above Y 55) or sticks out of
-- its sides (past |x| 94: the top bands, pillows and temple tops reach up to a stud beyond the wall's outer face), inside |x| 95, would show as a dark outline against the black box:
-- TrackWalls158 hides those pieces for as long as the track refreshes.
D.CoverTop=55
D.CoverSide=94
function D.OverCover(spec)
 local lo,hi=D.Extent(spec)
 local reach=math.max(math.abs(lo[1]),math.abs(hi[1]))
 return(hi[2]>D.CoverTop or reach>D.CoverSide+1e-6)and reach<=95 and hi[3]>-99
end

-------------------------------------------------------------------------------------------------------------------------------- biomes
-- Colours are RGB 0-255. Materials are Roblox Enum.Material names. Key colours: KeyboardTrack's palettes (HubDecorKit151.Biomes).
D.Biomes={
 {Stage=1,Id='forest',Name='Forest',Z0=-100,Z1=80,Key={96,186,90},Ground={{92,150,70},'Grass'},
  Wall={Color={78,58,40},Material='Wood'},Look='Log fort: a row of round logs with sharp tips along the whole wall (no two alike), two log rails across them, a mossy bank at the foot, ivy strands here and there.'},
 {Stage=6,Id='jungle',Name='Jungle',Z0=80,Z1=530,Key={44,146,100},Ground={{70,120,62},'Grass'},
  Wall={Color={104,120,96},Material='Cobblestone'},Look='Temple ruins: mossy stone, stepped temple tops, carved stone faces, a glyph band, stone pillars and vines hanging down.'},
 {Stage=2,Id='desert',Name='Desert',Z0=530,Z1=1180,Key={228,192,112},Ground={{224,190,120},'Sand'},
  Wall={Color={226,198,140},Material='Sandstone'},Look='Sandstone temple: a big flared top lip, painted bands, pilasters with small gold-tipped obelisks, golden winged suns and carved doors.'},
 {Stage=3,Id='snow',Name='Snow',Z0=1180,Z1=2030,Key={170,208,232},Ground={{236,242,248},'Snow'},
  Wall={Color={168,204,226},Material='Brick'},Look='Ice bricks: pale blue brick, ice pillars, a snow cap, icicles under it and snow drifts at the foot.'},
 {Stage=4,Id='lava',Name='Lava',Z0=2030,Z1=3080,Key={236,108,34},Ground={{52,44,46},'Basalt'},
  Wall={Color={56,48,50},Material='Basalt'},Look='Volcano rock: dark basalt, a jagged rocky top, glowing cracks and a glowing seam at the foot.'},
 {Stage=5,Id='crystal',Name='Crystal',Z0=3080,Z1=4380,Key={150,108,208},Ground={{86,68,120},'Slate'},
  Wall={Color={98,78,134},Material='Slate'},Look='Crystal cave stone: deep purple stone, crystal clusters growing on top, glowing pillar stripes and a glow line, crystals in the wall.'},
 {Stage=7,Id='storm',Name='Storm Peaks',Z0=4380,Z1=5980,Key={108,118,156},Ground={{60,66,80},'Slate'},
  Wall={Color={68,78,98},Material='Slate'},Look='Storm fort: dark slate, broken teeth on top, buttresses with copper lightning rods, big lightning bolts.'},
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
local BORDER=5.8 -- half the border tower (cap) width: the pieces of a biome stay this far from its ends
-- "Bay" pieces (vines, faces, suns, doors, icicles, cracks, studs, bolts) are tagged; the lite version (phones on low) leaves them out.
local BAY={bay=true}
local function inside(z,z0,z1,m)return z>=z0+BORDER+m and z<=z1-BORDER-m end

local W={} -- per-biome wall builders: W[id](s, z0, z1, R)
-- FOREST: a log fort. Logs of uneven thickness stand in an uneven row (a few gaps, a few short broken ones, tops rolling up and down, each leaning a little), most with a sharp
-- tip (some chisel-cut, some flat), two log rails in pieces, a bank of moss in patches, ivy strands in a few places.
function W.forest(s,z0,z1,R)
 local woods={{116,82,52},{104,74,48},{126,92,60},{110,78,50},{98,70,46},{122,88,56}}
 local cuts={{176,134,90},{168,126,84},{184,142,98},{96,70,48}}
 local za,zb=-93,z1-BORDER -- the gatehouse (Y 44 - 58) and the rook tower bases stand on the first studs
 local ph=R.r(0,6.28)
 local c=za
 while true do
  local d=R.r(3.1,4.3)
  if R.chance(.05)then c=c+R.r(1.2,2.8)end -- a gap: the wall shows between two logs
  local z=c+d/2
  if z+d/2>zb then break end
  c=c+d*R.r(.92,1.1)
  local lean,inward=R.r(-.03,.03),R.r(0,.025)
  local top=54.2+1.8*math.sin(z*.045+ph)+R.r(-1.4,1.4)
  local kind=R.f()
  local broken=kind<.07
  if broken then top=R.r(41,49.5)elseif kind<.13 then top=top+R.r(2.5,4.5)end
  local foot=5.6
  local M=mul(Rz(-s*inward),Rx(lean))
  local up,span=col(M,2),col(M,3)
  local len=(top-foot)/up[2]
  local x=s*(IN-R.r(.2,1.0))
  local wood=tint(R,R.pick(woods),5)
  cyl('Log',len,d,cf(x+up[1]*len/2,foot+up[2]*len/2,z+up[3]*len/2,mul(M,UPRIGHT)),wood,'Wood')
  local tip={x+up[1]*len,foot+up[2]*len,z+up[3]*len}
  local style=R.f()
  if broken then tooth('Log tip',tip,up,span,R.r(1.2,3),d*.8,d*.7,R.sign(),R.pick(cuts),'Wood')
  elseif style<.12 then -- a flat cut: no tip
  elseif style<.37 then tooth('Log tip',tip,up,span,R.r(2,3.2),d,d*.9,R.sign(),R.pick(cuts),'Wood')
  else spike('Log tip',tip,up,span,R.r(2.1,3.7),d,d*.9,R.pick(cuts),'Wood')end
 end
 -- two rails tied across the logs, in pieces (a post to post run, a short gap, a slightly different height and thickness each)
 for _,y in ipairs({17,43})do
  runs(R,za,zb,34,88,1.2,4.5,function(a,b)
   local t=R.r(-.012,.012)
   cyl('Log rail',b-a,R.r(1.4,1.9),cf(s*(IN-2.9+R.r(-.2,.2)),y+R.r(-.5,.5),(a+b)/2,mul(Rx(t),ALONG_Z)),tint(R,{88,62,40},5),'Wood')
  end)
 end
 -- a mossy bank over the log feet, in patches of different height
 runs(R,za-1,zb,10,38,0,7,function(a,b)
  face('Moss bank',s,a,b,5.3,5.3+R.r(1.6,3.2),R.r(1.9,3.0),tint(R,{82,132,62},9),'Grass')
  if R.chance(.3)then spend(R,10)end -- (the moss tufts are gone)
 end)
 -- ivy: strands of uneven width and length, bunched in a few places
 local n=R.i(3,6);local zi=za+R.r(8,16)
 for _=1,n do
  zi=zi+R.r(8,46)
  if zi>zb-4 then break end
  local len,w=R.r(7,26),R.r(.8,1.7)
  face('Ivy',s,zi-w/2,zi+w/2,50.4-len,50.4,3.4,tint(R,{62,128,58},8),'LeafyGrass',BAY)
  local f=R.f() -- (the leaf balls on the ivy are gone)
  if f<.6 then spend(R,7)elseif f<.8 then spend(R,13)end
  if R.chance(.3)then zi=zi+R.r(1.5,3)end -- a second strand close by
 end
end

-- JUNGLE: temple ruins. The long bands are runs in close stone shades; crenels differ (stepped, plain, worn down, missing); pillars are unevenly spaced, some broken; carved faces are
-- whole, weathered or blank; vines hang here and there.
function W.jungle(s,z0,z1,R)
 local stone,dark={112,128,100},{78,96,72}
 runs(R,z0,z1,70,150,0,0,function(a,b)face('Stone foot',s,a,b,5.5,11,1.0,tint(R,dark,9),'Cobblestone')end)
 runs(R,z0,z1,70,150,0,0,function(a,b)face('Glyph band',s,a,b,27,31.5,.7,tint(R,{126,134,104},9),'Slate')end)
 runs(R,z0,z1,70,150,0,0,function(a,b)face('Top step',s,a,b,46.6,49,1.5,tint(R,{100,116,90},8),'Slate')end)
 runs(R,z0,z1,70,150,0,0,function(a,b)wrap('Temple top',s,a,b,49,52.6,.8,.5,tint(R,stone,9),'Cobblestone')end)
 -- crenels along the top
 local _,crenels=spread(R,z0+BORDER,z1-BORDER,22.5,.3)
 for _,bay in ipairs(crenels)do
  local z=bay.z+R.r(-.12,.12)*bay.w
  local hw=math.min(bay.w*.36,R.r(2.2,4.2))
  local roll=R.f()
  if roll<.12 then -- a missing crenel
  elseif roll<.42 then box('Temple step',s*(IN-.6),s*(IN+3.6),52.6,52.6+R.r(1.6,3.4),z-hw,z+hw,tint(R,stone,10),'Cobblestone')
  elseif roll<.52 then spend(R,6) -- (a rubble blob stood here: gone, the crenel is missing)
  else
   local h1=R.r(2.2,3.6);local c=tint(R,stone,10)
   box('Temple step',s*(IN-.6),s*(IN+3.6),52.6,52.6+h1,z-hw,z+hw,c,'Cobblestone')
   if R.chance(.7)then box('Temple step top',s*(IN+.2),s*(IN+2.8),52.6+h1,52.6+h1+R.r(1.6,2.8),z-hw*.5,z+hw*.5,tint(R,{124,140,110},9),'Cobblestone')end
  end
 end
 -- pillars, unevenly spaced
 local piers=spread(R,z0+BORDER,z1-BORDER,45,.3)
 for _,z in ipairs(piers)do
  local hw=R.r(2.2,2.9)
  local broken=R.chance(.2)
  local top=broken and R.r(36,47)or 50.4
  face('Temple pillar',s,z-hw,z+hw,5.3,top,R.r(2.2,2.7),tint(R,{96,116,88},8),'Slate')
  if broken then spend(R,9)elseif R.chance(.55)then spend(R,7)end -- (the rubble at a broken pillar's foot and the leaf crowns are gone)
 end
 -- carved faces: a few, each different (whole, weathered, or only the slab); glyph tiles in some places
 local _,fbays=spread(R,z0+BORDER,z1-BORDER,85,.3)
 for _,bay in ipairs(fbays)do
  if R.chance(.8)then
   local z=bay.z+R.r(-.15,.15)*bay.w;local k=R.r(.8,1.2);local y0=R.r(11,15);local c=tint(R,{120,132,106},8)
   face('Stone face',s,z-4.5*k,z+4.5*k,y0,y0+9*k,.6,c,'Slate',BAY)
   local kind=R.f()
   if kind<.55 then -- whole
    face('Stone brow',s,z-4.8*k,z+4.8*k,y0+7*k,y0+8.4*k,1.0,{100,114,90},'Slate',BAY)
    for _,dz in ipairs({-2,2})do face('Stone eye',s,z+(dz-1)*k,z+(dz+1)*k,y0+4.4*k,y0+6.2*k,.85,{36,44,34},'Slate',BAY)end
    face('Stone mouth',s,z-2.4*k,z+2.4*k,y0+k,y0+2.4*k,.85,{36,44,34},'Slate',BAY)
   elseif kind<.8 then -- weathered: one eye and the mouth
    face('Stone eye',s,z+(R.sign()*2-1)*k,z+(R.sign()*2+1)*k,y0+4.4*k,y0+6.2*k,.85,{36,44,34},'Slate',BAY)
    face('Stone mouth',s,z-2.4*k,z+2.4*k,y0+k,y0+2.4*k,.85,{36,44,34},'Slate',BAY)
   end
  end
 end
 local _,tiles=spread(R,z0+BORDER,z1-BORDER,52,.3)
 for _,bay in ipairs(tiles)do
  if R.chance(.65)then
   local z=bay.z+R.r(-.2,.2)*bay.w;local hw=R.r(1.1,1.9);local y0=27.75+R.r(-.3,.4)
   face('Glyph tile',s,z-hw,z+hw,y0,y0+R.r(2.4,3.0),.95,tint(R,{70,90,64},8),'Slate',BAY)
  end
 end
 -- vines hanging here and there
 local zv=z0+BORDER+R.r(2,10)
 for _=1,R.i(6,10)do
  zv=zv+R.r(14,60)
  if not inside(zv,z0,z1,2)then break end
  local a,w=R.r(8,26),R.r(.6,1.4)
  face('Vine',s,zv-w/2,zv+w/2,46.6-a,46.6,1.65,tint(R,{43,108,56},8),'LeafyGrass',BAY)
  if R.chance(.65)then spend(R,4)end -- (the leaf balls on the vines are gone)
 end
end

-- DESERT: sandstone temple. Bands in runs of a few warm shades; pilasters unevenly spaced, only some with an obelisk (each of its own height, gold or turquoise tipped), a tile,
-- or a plain stone cap; suns, cartouches and carved doors in some bays only.
function W.desert(s,z0,z1,R)
 runs(R,z0,z1,80,170,0,0,function(a,b)face('Sandstone foot',s,a,b,5.5,9.4,.6,tint(R,{198,164,108},8),'Sandstone')end)
 runs(R,z0,z1,60,140,0,0,function(a,b)face('Painted band',s,a,b,31,32.2,.3,tint(R,R.pick({{178,98,62},{190,110,70},{164,90,58}}),4),'Slate')end)
 face('Turquoise band',s,z0,z1,32.6,33.6,.25,{60,168,168},'SmoothPlastic')
 runs(R,z0,z1,60,140,0,0,function(a,b)face('Painted band',s,a,b,34,35.2,.3,tint(R,R.pick({{178,98,62},{190,110,70},{164,90,58}}),4),'Slate')end)
 face('Lip line',s,z0,z1,46.6,47.4,.5,{60,168,168},'SmoothPlastic')
 face('Lip shadow',s,z0,z1,47.4,48.8,1.0,{204,170,112},'Sandstone')
 wrap('Top lip',s,z0,z1,48.8,51.8,2.0,.6,{240,216,164},'Sandstone')
 local piers,bays=spread(R,z0+BORDER,z1-BORDER,65,.3)
 for _,z in ipairs(piers)do
  local hw=R.r(2.5,3.6)
  if clear(s,z,hw+1)then
   face('Pilaster',s,z-hw,z+hw,5.3,46.6,1.3,tint(R,{214,182,124},7),'Sandstone')
   if R.chance(.7)then
    local th=R.r(1.2,1.8);local y0=R.r(11,17)
    face('Turquoise tile',s,z-th,z+th,y0,y0+R.r(2.4,3.4),1.55,tint(R,{52,160,170},8),'SmoothPlastic')
   end
   local roll=R.f()
   if roll<.55 then -- an obelisk, its own height, gold or turquoise tipped
    local ow=R.r(1.0,1.5);local h=R.r(4.8,8.4)
    box('Obelisk',s*(IN-1.6),s*(IN+.8),51.8,51.8+h,z-ow,z+ow,tint(R,{232,206,150},6),'Sandstone')
    local tc=R.chance(.7)and{236,190,92}or{52,160,170}
    spike('Obelisk tip',{s*(IN-.4),51.8+h,z},{0,1,0},{0,0,1},R.r(2,3.2),ow*2,ow*2,tc,'SmoothPlastic')
   elseif roll<.8 then box('Pilaster cap',s*(IN-1.8),s*(IN+.8),51.8,51.8+R.r(1.2,2.4),z-hw,z+hw,tint(R,{226,196,138},6),'Sandstone')
   end
  end
 end
 for _,bay in ipairs(bays)do
  local z=bay.z+R.r(-.12,.12)*bay.w
  local roll=R.f()
  if roll<.55 then -- a golden winged sun (a disc and two turquoise wings), its own size and height
   local k=R.r(.8,1.25);local y=R.r(38,43)
   cyl('Sun disc',.6,4.4*k,cf(s*(IN-.6),y,z,ALONG_X),tint(R,{240,196,84},6),'SmoothPlastic',BAY)
   for _,dir in ipairs({-1,1})do tooth('Sun wing',{s*(IN-.1),y+1.2*k,z+dir*2.1*k},{0,-1,0},{0,0,1},2.4*k,7*k,.8,dir,{52,160,170},'SmoothPlastic',BAY)end
  elseif roll<.7 then -- a plain cartouche panel
   local hw=R.r(2,3.4);local y=R.r(37,41)
   face('Cartouche',s,z-hw,z+hw,y,y+R.r(3,4.4),.45,tint(R,{208,156,96},6),'Sandstone',BAY)
  end
  local hw=R.r(2.7,3.7)
  if R.chance(.55)and clear(s,z,hw+1.2)then -- a carved door below it (not on the pyramid walkway)
   local h=R.r(11,14.5)
   face('Carved door',s,z-hw,z+hw,9.4,9.4+h,.25,tint(R,{176,136,88},7),'Sandstone',BAY)
   face('Door lintel',s,z-hw-1.2,z+hw+1.2,9.4+h,9.4+h+1.6,.7,tint(R,{204,170,112},6),'Sandstone',BAY)
  end
 end
end

-- SNOW: ice bricks. Snow drifts of every size at the foot, a snow cap, ice pillars (some broken), icicles in bunches of one to three of different lengths.
function W.snow(s,z0,z1,R)
 runs(R,z0,z1,140,260,0,0,function(a,b)local y=27+R.r(-.4,.4);face('Ice band',s,a,b,y,y+R.r(1.1,1.6),.4,tint(R,{140,188,214},6),'Ice')end)
 runs(R,z0,z1,34,90,0,8,function(a,b)face('Snow drift',s,a,b,5.5,5.5+R.r(2.2,3.6),R.r(1.2,1.9),tint(R,{236,242,248},4),'Snow')end)
 wrap('Snow cap',s,z0,z1,50.2,52.6,1.5,.6,{240,246,250},'Snow')
 -- (the snow pillows that lay along the cap are gone)
 local z=z0+BORDER+R.r(2,12)
 while z<z1-BORDER-8 do
  spend(R,8)
  z=z+R.r(15,50)
 end
 local piers=spread(R,z0+BORDER,z1-BORDER,50,.3)
 for _,z in ipairs(piers)do
  local hw=R.r(2.0,3.2);local broken=R.chance(.18)
  face('Ice pillar',s,z-hw,z+hw,5.3,broken and R.r(38,47)or 50.2,1.2,tint(R,{150,196,222},6),'Ice')
  if R.chance(.75)then spend(R,2)end -- (the snow mounds at the foot are gone)
 end
 -- icicles: bunches of 0 - 5 hanging from the cap, each a different length and lean, bunched unevenly
 local zi=z0+BORDER+R.r(2,12)
 while zi<z1-BORDER-6 do
  local edge=zi-1
  for _=1,R.i(1,3)do
   local len=R.chance(.15)and R.r(9,12)or R.r(2.6,8)
   local t=R.r(.7,1.1) -- (an icicle hangs wholly in front of an ice pillar's face, 1.2 proud: its planes never share the pillar's)
   local w,dir=R.r(.9,2),R.sign()
   local a=math.max(zi,edge+.3+(dir<0 and w or 0)) -- (icicles never overlap: their tops share the cap's underside)
   -- (its wall side stands 1.3 - 1.45 proud, under the cap's inner face at 1.5 proud, so its top touches the cap's underside)
   tooth('Icicle',{s*(IN-(1.2+t/2+R.r(.1,.25))),50.2,a},{0,-1,0},{0,0,1},len,w,t,dir,tint(R,{204,232,246},5),'Ice',BAY)
   edge=dir>0 and a+w or a
   zi=edge+R.r(.3,3.5)
  end
  zi=zi+R.r(22,62)
 end
end

-- LAVA: volcano rock. Teeth of every height and width leaning both ways, columns (some broken), glowing seams in pieces, cracks of different length and bend. (Owner: the Neon "Lava drip" pieces under the wall top are gone, for good.)
function W.lava(s,z0,z1,R)
 runs(R,z0,z1,100,220,0,0,function(a,b)face('Basalt foot',s,a,b,5.5,9.2,1.0,tint(R,{40,34,36},4),'Basalt')end)
 runs(R,z0,z1,60,160,8,40,function(a,b)face('Ember seam',s,a,b,9.2,9.2+R.r(.3,.7),.7,{255,106,36},'Neon')end)
 runs(R,z0,z1,50,150,8,40,function(a,b)local y=49.4+R.r(-.05,.1);face('Under glow',s,a,b,y,y+R.r(.4,.7),.5,{255,96,30},'Neon')end)
 wrap('Basalt top',s,z0,z1,49.9,52.4,1.2,.5,{46,40,42},'Basalt')
 -- a jagged rocky crest
 local z=z0+BORDER+R.r(1,8)
 while z<z1-BORDER-4 do
  local w=R.r(3.4,8)
  tooth('Rock tooth',{s*(IN+R.r(.5,1.4)),52.4,z},{0,1,0},{0,0,1},R.r(2,9.5),w,R.r(2.6,4),R.sign(),tint(R,{58,50,52},5),'Basalt')
  z=z+R.r(14,54)
 end
 local piers=spread(R,z0+BORDER,z1-BORDER,60,.3)
 for _,pz in ipairs(piers)do
  local hw=R.r(2.0,3.2)
  face('Basalt column',s,pz-hw,pz+hw,5.3,R.chance(.25)and R.r(35,46)or 49.4,1.6,tint(R,{50,44,46},4),'Basalt')
 end
 local zc=z0+BORDER+R.r(2,12)
 while zc<z1-BORDER-14 do
  local n,len=R.i(1,3),R.r(6,12)
  zigzag('Glowing crack',s,zc,R.r(n*len+13,47),n,len,R.r(.4,.9),.12,R.r(.25,.6),{255,R.i(110,134),40},'Neon',BAY) -- (never lower than Y 12: the keys)
  zc=zc+R.r(36,125)
 end
end

-- CRYSTAL: purple stone. Clusters of one to four crystals of every height and lean, unevenly placed, a glow line in pieces, glow stripes of different length on some pillars,
-- small crystals in the wall in some places only.
function W.crystal(s,z0,z1,R)
 runs(R,z0,z1,100,220,0,0,function(a,b)face('Stone foot',s,a,b,5.5,10,1.0,tint(R,{74,60,104},5),'Slate')end)
 runs(R,z0,z1,40,150,8,30,function(a,b)face('Glow line',s,a,b,22+R.r(-.2,.2),22.5+R.r(-.1,.3),.3,{206,150,255},'Neon')end)
 wrap('Stone top',s,z0,z1,49.8,52.2,1.1,.5,{112,92,150},'Slate')
 local cols={{186,150,236},{140,206,242},{232,160,226}}
 local function cluster(z,n)
  local x=s*(IN+1.2)
  for k=1,n do
   local c=tint(R,R.pick(cols),8)
   local zz=z+(k-1)*R.r(3,5)*(k%2==0 and 1 or-1)*R.r(.6,1)
   local h=(k==1)and R.r(15,26)or R.r(7,15)
   local w=(k==1)and R.r(4.6,7)or R.r(3,5)
   local leanX=s*R.r(-.06,.13) -- (more than that and a tall crystal reaches over the track or past the wall)
   local leanZ=R.r(.04,.38)*R.sign()
   if k==1 then shard('Crystal',x,51.6,zz,h,w,leanX,leanZ,c,'SmoothPlastic')
   else shard('Crystal',x,51.6,zz,h,w,leanX,leanZ,c,'SmoothPlastic',nil,R.sign())end
  end
 end
 local piers,bays=spread(R,z0+BORDER,z1-BORDER,100,.3)
 for _,z in ipairs(piers)do
  local hw=R.r(2.1,3)
  face('Crystal pillar',s,z-hw,z+hw,5.3,49.8,1.4,tint(R,{86,68,120},5),'Slate')
  local roll=R.f()
  if roll<.65 then
   local y0=R.r(10,20)
   face('Glow stripe',s,z-R.r(.3,.5),z+R.r(.3,.5),y0,R.r(30,46),1.55,{222,170,255},'Neon')
  end
  if R.chance(.85)then cluster(z,R.i(1,3))end
 end
 for i,bay in ipairs(bays)do
  if R.chance(.4)then cluster(bay.z+R.r(-.2,.2)*bay.w,R.i(1,3))end
  for _=1,R.i(0,1)do if R.chance(.6)then
   local c=R.chance(.5)and cols[2]or cols[3]
   local k=R.r(.7,1.1)
   shard('Wall crystal',s*(IN+.6),R.r(14,28),bay.z+R.r(-.4,.4)*bay.w,5*k,2.2*k,s*R.r(.75,1.0),R.r(.2,.4)*R.sign(),c,'Neon',BAY)
  end end
 end
end

-- STORM PEAKS: dark slate fort. Buttresses of different height, only some with a lightning rod (each its own length and lean), a few with a stone cap,
-- broken battlement teeth of every height, bolts of two to four segments in some bays.
function W.storm(s,z0,z1,R)
 runs(R,z0,z1,120,260,0,0,function(a,b)face('Slate foot',s,a,b,5.5,10,1.0,tint(R,{52,60,76},4),'Slate')end)
 face('Copper band',s,z0,z1,30,30.8,.35,{184,108,64},'Metal')
 wrap('Slate top',s,z0,z1,49.8,52.2,1.2,.5,{84,94,114},'Slate')
 local piers,bays=spread(R,z0+BORDER,z1-BORDER,100,.3)
 for _,z in ipairs(piers)do
  local hw=R.r(2.3,3.3);local top=R.r(48,58)
  face('Buttress',s,z-hw,z+hw,5.3,top,1.8,tint(R,{60,70,88},5),'Slate')
  if R.chance(.8)then local sw=R.r(.3,.55);face('Copper strap',s,z-sw,z+sw,R.r(8,12),top+.3,1.95,tint(R,{190,112,66},6),'Metal')end
  local roll=R.f()
  if roll<.55 then -- a rod, its own length and lean
   local len=R.r(5,13);local lx,lz=R.r(-.1,.1),R.r(-.1,.1)
   local M=mul(Rz(lx*-s),Rx(lz));local up=col(M,2)
   local base={s*(IN-.6),top,z}
   cyl('Lightning rod',len,.6,cf(base[1]+up[1]*len/2,base[2]+up[2]*len/2,base[3]+up[3]*len/2,mul(M,UPRIGHT)),tint(R,{196,120,70},6),'Metal')
   if R.chance(.7)then spend(R,1)end -- (the glow balls on the rods' tips are gone)
  elseif roll<.8 then box('Buttress cap',s*(IN-2.1),s*(IN+.8),top,top+R.r(1,2.2),z-hw-.3,z+hw+.3,tint(R,{74,84,104},5),'Slate')
  end
 end
 for _,bay in ipairs(bays)do
  -- broken battlement teeth between the buttresses
  local zt=bay.z-bay.w*.4
  while zt<bay.z+bay.w*.4 do
   local hw=R.r(1.4,3.5)
   if R.chance(.65)then box('Slate tooth',s*(IN-.6),s*(IN+3),52.2,52.2+R.r(1,6.5),zt-hw,zt+hw,tint(R,{74,84,104},6),'Slate')end
   zt=zt+hw*2+R.r(4,40)
  end
  if R.chance(.35)then
   local n,len=R.i(2,4),R.r(7,11)
   while n*len>33 do n=n-1 end
   zigzag('Lightning bolt',s,bay.z+R.r(-.3,.3)*bay.w,R.r(n*len+13,47),n,len,R.r(.6,1),.14,R.r(.3,.6),{186,220,255},'Neon',BAY)
  end
 end
end
-- The end wall (z 5980, its face looks back down the track): the Storm bands across it, two buttresses with rods and one big bolt, its own seed.
local function endWall(R)
 local z=D.EndZ;local x0,x1=-(IN-1.2),IN-1.2
 box('Slate foot',x0,x1,5.5,10,z-1.0,z+SINK,{52,60,76},'Slate')
 box('Copper band',x0,x1,30,30.8,z-.35,z+SINK,{184,108,64},'Metal')
 box('Slate top',x0,x1,49.8,52.2,z-1.2,z+5.5,{84,94,114},'Slate')
 for _,sx in ipairs({-1,1})do
  local x=sx*R.r(24,38);local hw=R.r(2.6,3.4);local top=R.r(53,58)
  box('Buttress',x-hw,x+hw,5.3,top,z-1.8,z+SINK,{60,70,88},'Slate')
  box('Copper strap',x-.4,x+.4,10,top+.3,z-1.95,z+SINK,{190,112,66},'Metal')
  local len=R.r(7,12);vcyl('Lightning rod',x,z-.6,top,top+len,.6,{196,120,70},'Metal')
  spend(R,1)
 end
 local tx=-66
 for _=1,4 do
  tx=tx+R.r(22,40)
  if math.abs(tx)>66 then break end
  if math.abs(tx)>26 or R.chance(.4)then local hw=R.r(2.2,3.4);box('Slate tooth',tx-hw,tx+hw,52.2,52.2+R.r(1.5,5),z-.6,z+3,{74,84,104},'Slate')end
 end
 local cz,cy=R.r(-12,12),44
 for i=1,3 do
  local a=(i%2==1)and R.r(.4,.6)or-R.r(.4,.6);local len=R.r(9,11);local dx,dy=math.sin(a)*len,-math.cos(a)*len
  block('Lightning bolt',{.9,len+.5,.25+.04*i},cf(cz+dx/2,cy+dy/2,z-(.25+.04*i)/2+.1,Rz(a)),{186,220,255},'Neon',BAY)
  cz,cy=cz+dx,cy+dy
 end
end
-- Border towers where two biomes meet (they also hide the seam between two wall styles): plain stone, a glowing band in the NEXT biome's colour, each a little different.
local function borderTower(s,z,nextKey,R)
 local top=R.r(58.6,61.2)
 face('Border tower',s,z-5,z+5,5.3,top,2.4,tint(R,{112,106,100},6),'Cobblestone')
 local by=R.r(38,43)
 box('Border band',s*(IN-2.6),s*(IN+.6),by,by+1.4,z-5.2,z+5.2,nextKey,'Neon') -- (sunk deeper than the tower: their backs never share a plane)
 box('Border tower cap',s*(IN-3),s*(OUT+.8),top,top+R.r(1.3,1.8),z-5.8,z+5.8,tint(R,{134,128,120},5),'Slate')
end

function D.TrackWalls(opt)
 opt=opt or{};out={}
 for i,b in ipairs(D.Biomes)do
  group='TrackWalls158/'..b.Name
  for _,s in ipairs({-1,1})do W[b.Id](s,b.Z0,b.Z1,D.Rng(D.Seed(b.Stage,s)))end
  if b.Id=='storm'then endWall(D.Rng(D.Seed(b.Stage,0)+3))end
  local nb=D.Biomes[i+1]
  if nb then group='TrackWalls158/Border '..b.Name..' - '..nb.Name;for _,s in ipairs({-1,1})do borderTower(s,b.Z1,nb.Key,D.Rng(158900+i*2+(s<0 and 0 or 1)))end end
 end
 -- Only parts 20+ studs long cast a shadow, and not the thin bands that lie flat on the wall (their shadow would fall on the wall they sit on).
 local FLAT={['Stone foot']=1,['Glyph band']=1,['Top step']=1,['Sandstone foot']=1,['Painted band']=1,['Turquoise band']=1,['Lip line']=1,['Ice band']=1,['Snow drift']=1,
  ['Moss bank']=1,['Glow line']=1,['Ember seam']=1,['Under glow']=1,['Basalt foot']=1,['Slate foot']=1,['Copper band']=1,['Glow stripe']=1,['Border band']=1}
 for _,p in ipairs(out)do if math.max(p.Size[1],p.Size[2],p.Size[3])<20 or FLAT[p.Name]then p.Shadow=false end end
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

-------------------------------------------------------------------------------------------------------------------------------- outer ground
-- Outside the walls there is nothing today (no terrain, no floor): a flat ground in each biome's own material under what the owner's backdrop models (OuterTrackAssets158) stand on.
-- Rules: never inside |x| 94 (the walls) and never over the hub (z < -99); no shadow, no collision of any kind. The backdrop OBJECTS (trees, mountains, volcanoes, the pyramid ...)
-- are not built from parts: OuterTrackLoader158 places the owner's own models.
D.Ground={Top=FLOOR-.4,Thickness=1,Width=1950}
local function ground(b,z0,z1)
 for _,s in ipairs({-1,1})do box('Outer ground',s*OUT,s*(OUT+D.Ground.Width),FLOOR-1.4,FLOOR-.4,z0,z1,b.Ground[1],b.Ground[2],{shadow=false})end
end
function D.Backdrops()
 out={}
 for i,b in ipairs(D.Biomes)do
  group='TrackBackdrops158/'..b.Name
  ground(b,i==1 and-99 or b.Z0,b.Id=='storm'and D.EndZ+5 or b.Z1)
  if b.Id=='storm'then -- behind the end wall
   box('Outer ground',-1000,1000,FLOOR-1.4,FLOOR-.4,D.EndZ+5,D.EndZ+1905,b.Ground[1],b.Ground[2],{shadow=false})
  end
 end
 return out
end

-------------------------------------------------------------------------------------------------------------------------------- base walls
-- The hub walls (HubDecorKit151, R152): five saved wall parts 48 tall (top Y 51), a chess-rook battlement of 218 square merlons 5 x 6 x 5 (one
-- every ~10 studs, one on each outer corner), the gatehouse (12 + 5 merlons) and two rook towers (8 merlons each). Section frames copied from
-- HubDecorKit151.Sections (s runs along the inner face, d out of it into the hub; local X = t, Y = up, Z = n). Tests keep these equal to the kit's.
local SEC={
 FrontXNeg={o={-94,0,-104},t={-1,0,0},n={0,0,-1},len=241},
 FrontXPos={o={335,0,-104},t={-1,0,0},n={0,0,-1},len=241},
 Back={o={-335,0,-618},t={1,0,0},n={0,0,1},len=670},
 SideXNeg={o={-335,0,-104},t={0,0,-1},n={1,0,0},len=514},
 SideXPos={o={335,0,-618},t={0,0,1},n={-1,0,0},len=514},
}
D.Sections=SEC
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
local STONE,DARK=({178,166,147}),{150,138,120}
-- A band along every section's inner face, `depth` out of it (SINK into the wall); the side bands stop at the front / back bands (as HubDecor151's own do).
-- `back` > 0 carries it over the wall top to `back` past the outer face (a coping).
local function strip(name,y0,y1,depth,color,mat,back)
 local d0=back and-(5+back)or-SINK
 for _,k in ipairs(ORDER)do local sec=SEC[k]
  local s0,s1=0,sec.len
  if k:find('^Side')then s0,s1=depth,sec.len-depth end -- (meets the front / back band exactly: two textured bands never overlap in one plane, R154)
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
-- Close stone shades: a cap takes one of them (and a hair of thickness) from a fixed seed, so a long row of caps is not one copy-pasted colour.
D.CapShades={{150,138,120},{145,133,117},{155,143,125},{148,136,121},{152,140,123}}
-- a cap on every merlon (wall, gatehouse, keep, rook towers): .5 wider than the merlon all round, `h` thick
local function caps(mat,wallH,wallD,h)
 h=h or .8
 local R=D.Rng(158777)
 local function shade()return R.pick(D.CapShades)end
 local function thick(k)return k*R.r(.88,1.14)end
 local tower={} -- the 8 caps of a rook tower touch at their corners: one shade and one thickness per tower (look-alike faces cannot flicker)
 for _,m in ipairs(merlonSpots())do
  local sec=SEC[m.Sec];local d0,d1=-5,wallD or 0
  local t=thick(h)
  block('Merlon cap',{6,t,d1-d0+1},secCF(sec,m.S,wallH+t/2,(d0+d1)/2),shade(),mat)
 end
 gatehouseMerlons(function(x,y0,w,dz)local t=thick(h);block('Merlon cap',{w+1,t,dz+1},cf(x,y0+6+t/2,GATE.zc),shade(),mat)end)
 rookMerlons(function(x,y0,z,o)
  local Z={-o[1],0,-o[3]};local X=cross({0,1,0},Z)
  local key=x<0 and'L'or'R'
  if not tower[key]then tower[key]={shade(),thick(h*.8)}end
  local t=tower[key][2]
  local i=(tower[key][3] or 0);tower[key][3]=i+1 -- every second cap sits .04 lower: neighbours overlap at their corners and never share a top or bottom plane (R154)
  block('Merlon cap',{4.2,t,4.2},cf(x,y0+5.4+t/2-(i%2)*.04,z,axes(X,{0,1,0},Z)),tower[key][1],mat)
 end)
end
D.BaseOptions={
 A={Title='Stone caps',Look='A stone cap on every merlon (in a few close shades) and a stone coping along the whole wall top (inside and out), with a thin dark line under it. Calm and solid: the closest to what you have.'},
}
-- Option A (owner's choice): the only base wall option built. Returns the parts.
function D.BaseWalls(option)
 option=option or'A'
 assert(option=='A','only base wall option A (stone caps) is built')
 out={};group='BaseWalls158'
 caps('Slate',57)
 strip('Wall coping',50.4,51.6,1.4,STONE,'Cobblestone',.5)
 strip('Coping shadow',49.6,50.4,.9,DARK,'Slate')
 for _,p in ipairs(out)do if math.max(p.Size[1],p.Size[2],p.Size[3])<20 then p.Shadow=false end end -- (caps: no shadow, like the merlons)
 return out
end
return D
