--!nocheck
-- R149 (owner: "Ash Tomato also keeps, make growth variations"): derives three more designs of the Ash Tomato from its CURRENT art
-- (ApprovedPlantArt5's one design, left byte for byte as it is) so ApprovedPlantArt.Get / .Key can pick one of four per crop. Same
-- FruitCount (4), same parts per fruit, same look: a variant only changes
--   * the whole plant: mirror, overall size (<= the original), yaw, a slight lean;
--   * the leaf arrangement: every leaf (4 wedges + a midrib) swings about the point where it meets its stem, and a few leaves are dropped;
--   * each tomato: scale about its socket, a twist about the vertical axis through its socket, a shade of red;
--   * the leaf shade.
-- Everything is a rigid move of a part about a point the part shares with its neighbour (or a uniform scale about a shared socket), so
-- the plant stays in one piece (the R134 floating check runs on every variant in test_fruit_models.luau).
-- Prints  VARIANT <n> <literal of one design>  (the file's own style, ["z"]={..},["c"]={..},...) for gen_ash_tomato_variants.py.
local W=require('./world')
local base=W.module('ApprovedPlantArt5')[1]
local function num(v)local s=string.format('%.5f',v);s=s:gsub('0+$',''):gsub('%.$','');if s=='-0'or s==''then s='0'end;return s end
local function list(t,fmt)local o={};for i,v in ipairs(t)do o[i]=fmt(v)end;return '{'..table.concat(o,',')..'}'end
-- 3x3 row-major matrices as {a,b,c,d,e,f,g,h,i}; vectors {x,y,z}
local function mulM(A,B)
 return {A[1]*B[1]+A[2]*B[4]+A[3]*B[7],A[1]*B[2]+A[2]*B[5]+A[3]*B[8],A[1]*B[3]+A[2]*B[6]+A[3]*B[9],
         A[4]*B[1]+A[5]*B[4]+A[6]*B[7],A[4]*B[2]+A[5]*B[5]+A[6]*B[8],A[4]*B[3]+A[5]*B[6]+A[6]*B[9],
         A[7]*B[1]+A[8]*B[4]+A[9]*B[7],A[7]*B[2]+A[8]*B[5]+A[9]*B[8],A[7]*B[3]+A[8]*B[6]+A[9]*B[9]}
end
local function mulV(A,v)return {A[1]*v[1]+A[2]*v[2]+A[3]*v[3],A[4]*v[1]+A[5]*v[2]+A[6]*v[3],A[7]*v[1]+A[8]*v[2]+A[9]*v[3]}end
local function yaw(a)local c,s=math.cos(a),math.sin(a);return {c,0,s,0,1,0,-s,0,c}end
local function rotX(a)local c,s=math.cos(a),math.sin(a);return {1,0,0,0,c,-s,0,s,c}end
local function rotZ(a)local c,s=math.cos(a),math.sin(a);return {c,-s,0,s,c,0,0,0,1}end
local I3={1,0,0,0,1,0,0,0,1}
local function add(a,b)return {a[1]+b[1],a[2]+b[2],a[3]+b[3]}end
local function sub(a,b)return {a[1]-b[1],a[2]-b[2],a[3]-b[3]}end
local function mul(a,k)return {a[1]*k,a[2]*k,a[3]*k}end
local function dist(a,b)local d=sub(a,b);return math.sqrt(d[1]^2+d[2]^2+d[3]^2)end
local function rotOf(s)return {s.c[4],s.c[5],s.c[6],s.c[7],s.c[8],s.c[9],s.c[10],s.c[11],s.c[12]}end
local function copy(s)local t={};for k,v in pairs(s)do t[k]=type(v)=='table'and table.clone(v)or v end;return t end
-- a rigid move of spec s: new position p, new rotation matrix R
local function put(s,p,R)s.c={p[1],p[2],p[3],R[1],R[2],R[3],R[4],R[5],R[6],R[7],R[8],R[9]}end
-- rotate spec s by matrix A about the point P
local function swing(s,A,P)put(s,add(P,mulV(A,sub({s.c[1],s.c[2],s.c[3]},P))),mulM(A,rotOf(s)))end

-- surface samples of a spec (its box, or the axis of a CylinderX), in world space
local function samples(s)
 local R=rotOf(s);local p={s.c[1],s.c[2],s.c[3]};local out={}
 if s.s=='CylinderX'then
  local n=math.max(2,math.ceil(s.z[1]/.08))
  for i=0,n do out[#out+1]=add(p,mulV(R,{(i/n-.5)*s.z[1],0,0}))end
 else
  for _,x in ipairs({-.5,0,.5})do for _,y in ipairs({-.5,0,.5})do for _,z in ipairs({-.5,0,.5})do out[#out+1]=add(p,mulV(R,{x*s.z[1],y*s.z[2],z*s.z[3]}))end end end
 end
 return out
end
-- leaf units: 4 wedges + their midrib, in file order
local units,current={},{}
for i,s in ipairs(base.Specs)do
 if s.g==0 and(s.f=='Ash tomato leaf'or s.f=='Leaf midrib')then
  current[#current+1]=i
  if s.f=='Leaf midrib'then units[#units+1]=current;current={}end
 end
end
assert(#units==8,'8 leaf units')
local stems={}
for i,s in ipairs(base.Specs)do if s.f=='Living stem'then stems[#stems+1]=samples(s)end end
-- the pivot of a leaf: the middle of the closest pair of sample points between the leaf and any stem
local function pivot(unit)
 local best,bp=math.huge,nil
 for _,i in ipairs(unit)do for _,a in ipairs(samples(base.Specs[i]))do for _,st in ipairs(stems)do for _,b in ipairs(st)do
  local d=dist(a,b);if d<best then best=d;bp=mul(add(a,b),.5)end
 end end end end
 return bp,best
end
local pivots={}
for u,unit in ipairs(units)do local p=pivot(unit);pivots[u]=p end

-- the highest point and the widest reach of a spec list (the same two numbers measure the base art and every variant)
local function extent(list)
 local top,reach=0,0
 for _,s in ipairs(list)do
  local R=rotOf(s);local ex,ey,ez=0,0,0
  for a=1,3 do ex+=math.abs(R[a])*s.z[a]/2;ey+=math.abs(R[3+a])*s.z[a]/2;ez+=math.abs(R[6+a])*s.z[a]/2 end
  top=math.max(top,s.c[2]+ey);reach=math.max(reach,math.sqrt(s.c[1]^2+s.c[3]^2)+math.max(ex,ez))
 end
 return top,reach
end
local baseTop,baseReach=extent(base.Specs)
local VARIANTS={
 {mirror=false,scale=.97,yaw=0,lean={'z',.07},swing=.30,drop={},
  fruitScale={1.10,1.00,1.08,.95},twist={.35,-.25,.55,-.45},shade={-24,-12,-6},leafShade={9,8,4}},
 {mirror=true,scale=.95,yaw=0,lean={'x',-.07},swing=-.35,drop={4},
  fruitScale={.92,1.06,.94,1.04},twist={-.30,.42,-.52,.21},shade={9,15,-2},leafShade={-14,-12,-8}},
 {mirror=false,scale=.90,yaw=1.92,lean={'z',-.12},swing=.45,drop={2,7},
  fruitScale={1.04,.90,1.12,.98},twist={.70,.10,-.38,.50},shade={-7,-8,9},leafShade={16,10,-16}},
}
local function clamp(v)return math.max(0,math.min(255,v))end
local function shade(k,d)return {clamp(k[1]+d[1]),clamp(k[2]+d[2]),clamp(k[3]+d[3])}end

for n,v in ipairs(VARIANTS)do
 local specs={};local dropped={}
 for _,u in ipairs(v.drop)do for _,i in ipairs(units[u])do dropped[i]=true end end
 local unitOf={};for u,unit in ipairs(units)do for _,i in ipairs(unit)do unitOf[i]=u end end
 -- 1. each part's own move (tomatoes about their socket, leaves about their pivot, colours)
 local S0={};for g=1,#base.Sockets do S0[g]=table.clone(base.Sockets[g])end
 for i,orig in ipairs(base.Specs)do
  if not dropped[i]then
   local s=copy(orig)
   if s.g>0 then
    local g=s.g;local S=S0[g]
    if s.f~='Tomato stem'then
     -- scale about the socket, then twist about the vertical axis through it
     local f=v.fruitScale[g];local rel=mul(sub({s.c[1],s.c[2],s.c[3]},S),f)
     s.z={s.z[1]*f,s.z[2]*f,s.z[3]*f}
     local Y=yaw(v.twist[g]);put(s,add(S,mulV(Y,rel)),mulM(Y,rotOf(s)))
     if s.f=='Squared ash tomato'then s.k=shade(s.k,v.shade)end
    end
   elseif unitOf[i]then
    local u=unitOf[i];local sign=(u%2==0)and-1 or 1
    swing(s,yaw(v.swing*sign),pivots[u])
    s.k=shade(s.k,v.leafShade)
   end
   specs[#specs+1]=s
  end
 end
 -- 2. the whole plant: mirror, size, yaw, lean (all about the origin, where the stem meets the soil)
 local Rg=I3
 local function glob(p)
  local q={p[1]*(v.mirror and-1 or 1),p[2],p[3]};q=mul(q,v.scale);q=mulV(yaw(v.yaw),q)
  q=mulV(v.lean[1]=='z'and rotZ(v.lean[2])or rotX(v.lean[2]),q);return q
 end
 local Mr={v.mirror and-1 or 1,0,0,0,1,0,0,0,1}
 local function globR(R) -- M R S (S flips the local X axis back: boxes, cylinders, wedges and balls are symmetric in it), then yaw, lean
  local r=R
  if v.mirror then r=mulM(mulM(Mr,R),Mr)end
  r=mulM(yaw(v.yaw),r);r=mulM(v.lean[1]=='z'and rotZ(v.lean[2])or rotX(v.lean[2]),r)
  return r
 end
 for _,s in ipairs(specs)do
  put(s,glob({s.c[1],s.c[2],s.c[3]}),globR(rotOf(s)));s.z={s.z[1]*v.scale,s.z[2]*v.scale,s.z[3]*v.scale}
 end
 local top,reach=extent(specs)
 for i,s in ipairs(specs)do s._ArtIndex=i end
 -- 3. sockets, fruit centres (the tomato scaled about its socket first), radii, size
 local sockets,centres,radii={},{},{}
 for g=1,#base.Sockets do
  local S=S0[g];local C=base.FruitCenters[g];local f=v.fruitScale[g]
  sockets[g]=glob(S);centres[g]=glob(add(S,mul(sub(C,S),f)));radii[g]=base.FruitRadii[g]*f*v.scale
 end
 local function ser(s)
  local o={'["z"]='..list(s.z,num),'["c"]='..list(s.c,num),'["t"]='..num(s.t),'["m"]="'..s.m..'"','["g"]='..s.g,'["k"]='..list(s.k,function(x)return string.format('%d',math.floor(x+.5))end),
   '["f"]="'..s.f..'"','["s"]="'..s.s..'"','["_ArtIndex"]='..s._ArtIndex,'["r"]="'..s.r..'"'}
  return '{'..table.concat(o,',')..'}'
 end
 local specText={};for i,s in ipairs(specs)do specText[i]=ser(s)end
 local function pts(t)local o={};for i,p in ipairs(t)do o[i]=list(p,num)end;return '{'..table.concat(o,',')..'}'end
 print(string.format('VARIANT\t%d\t{["Specs"]={%s},["Sockets"]=%s,["FruitCenters"]=%s,["FruitRadii"]=%s,["Height"]=%s,["Radius"]=%s}',n,table.concat(specText,','),pts(sockets),pts(centres),list(radii,num),num(base.Height*top/baseTop),num(base.Radius*reach/baseReach)))
end
-- log: the base design's own numbers and every leaf's pivot
print(string.format('BASE\ttop %.4f (Height %.4f)\treach %.4f (Radius %.4f)',baseTop,base.Height,baseReach,base.Radius))
for u,p in ipairs(pivots)do local _,d=pivot(units[u]);print(string.format('PIVOT\t%d\t%.3f,%.3f,%.3f\tgap %.4f',u,p[1],p[2],p[3],d))end
