-- R148 (owner): plant art of Desert's two new seeds, in the RarityRework spec format PlantVisuals reads (like VerityPlantArt).
--  * DesertAloeSeed (Rare, "Aloe"): a rich blue-green rosette of thick pointed leaves (pale spots, red-brown teeth) with three tall,
--    DENSE red-orange flower spikes (24 hanging florets on each, red at the bottom grading to yellow tips). Each spike is one fruit
--    (group 1-3); harvesting it leaves the rosette.
--  * SandFruitSeed (Legendary, "Sand Fruit"): a ROUND (barrel) cactus built from the game's own cactus vocabulary: the Prickly Pear's stem
--    green, the Crown Cactus' ribs and ivory spines, the Prickly Pear's fruit attachment. Four sand fruits grow out of its shoulders:
--    each a slightly lumpy, squashed ball in Enum.Material.Sand with a tiny nub. Each fruit is one fruit (group 1-4).
-- The cactus colours / sizes are read from those existing art modules when they are there (their constants below are the same values).
-- FOUR designs per id (growth variations, like the approved plants): ApprovedPlantArt gives a crop one by a hash of its id, then the usual small size / turn
-- jitter. Aloe: leaf count / length / lean, rosette spread, the three spikes' heights, leans and positions, floret density and colour balance, leaf spots.
-- Sand Fruit: barrel height and width, rib count (7-9), spine density, pups (0-3), the four fruits' positions and sizes. Each design has its own sockets,
-- fruit centres, fruit radii and bounds. Built once per id; numbers are studs at PlantScale 1. Nothing is required at load time (ApprovedPlantArt and Roster149 load this module).
local A={}
local V,CF=Vector3.new,CFrame.new
A.AloeScale=1.5
A.Ids={DesertAloeSeed=true,SandFruitSeed=true}
A.DesignCount=4 -- designs per id (ApprovedPlantArt keys a crop's design by it)
function A.Is(id)return A.Ids[id]==true end
local function comps(cf)local x,y,z,a,b,c,d,e,f,g,h,i=cf:GetComponents();return {x,y,z,a,b,c,d,e,f,g,h,i}end
-- A frame at `pos` whose local Y runs along `dir` and whose local X is `normal` (made perpendicular to dir).
local function along(pos,dir,normal)
 local y=dir.Unit;local x=(normal-y*normal:Dot(y)).Unit
 return CFrame.fromMatrix(pos,x,y)
end
local function new()
 local specs={}
 local self={Specs=specs}
 function self.add(s)s.p=1;s._ArtIndex=#specs+1;specs[#specs+1]=s;return s end
 -- A pointed leaf of two Wedges: base at `base`, tip at base+dir*len, width across, thickness along `up`.
 function self.blade(base,dir,up,len,width,thick,k1,k2,g,role,name)
  local L=along(base,dir,up)
  self.add({s='Wedge',z={thick,len,width/2},c=comps(L*CF(0,len/2,-width/4)),k=k1,m='SmoothPlastic',t=0,g=g,r=role,f=name})
  self.add({s='Wedge',z={thick,len,width/2},c=comps(L*CF(0,len/2,width/4)*CFrame.Angles(0,math.pi,0)),k=k2,m='SmoothPlastic',t=0,g=g,r=role,f=name})
  return L
 end
 -- A round rod from a to b (spec 'Cylinder': z = {diameter, length, diameter}, axis = local Y).
 function self.rod(a,b,d,k,m,g,role,name)
  local dir=b-a;local side=math.abs(dir.Unit.Y)>.98 and V(1,0,0)or V(0,1,0)
  return self.add({s='Cylinder',z={d,dir.Magnitude,d},c=comps(along((a+b)/2,dir,side)),k=k,m=m or'SmoothPlastic',t=0,g=g,r=role,f=name})
 end
 function self.ball(shape,pos,size,k,m,g,role,name,frame)
  return self.add({s=shape,z=size,c=comps(CF(pos)*(frame or CF())),k=k,m=m or'SmoothPlastic',t=0,g=g,r=role,f=name})
 end
 return self
end
local function bounds(art)
 local top,radius=0,0
 for _,s in ipairs(art.Specs)do
  local c=s.c;local z=s.z
  local ey=(math.abs(c[7])*z[1]+math.abs(c[8])*z[2]+math.abs(c[9])*z[3])/2
  local ex=(math.abs(c[4])*z[1]+math.abs(c[5])*z[2]+math.abs(c[6])*z[3])/2
  local ez=(math.abs(c[10])*z[1]+math.abs(c[11])*z[2]+math.abs(c[12])*z[3])/2
  top=math.max(top,c[2]+ey);radius=math.max(radius,math.sqrt(c[1]^2+c[3]^2)+math.max(ex,ez))
 end
 art.Height=math.floor(top*1000+.5)/1000;art.Radius=math.floor(radius*1000+.5)/1000
end
-- Aloe ----------------------------------------------------------------------------------------------------------------
-- Four designs (owner: growth variations in every plant, like the approved plants). ApprovedPlantArt gives a crop one of them by a hash of its id
-- and then the small size / turn jitter every approved plant gets. Every design keeps three flower spikes (groups 1-3) and stays within ~130 parts.
-- Ring: count, first yaw (deg), base radius, base y, elevation (deg), length, width, thickness, two colours, whether its leaves carry spots / teeth.
local function ring(n,yaw,r,y,elev,len,w,t,c1,c2,spotted)return{n=n,yaw=yaw,r=r,y=y,elev=elev,len=len,w=w,t=t,c1=c1,c2=c2,spotted=spotted}end
-- Floret colours from the bottom of a spike to its tip.
local RED_TO_YELLOW={{226,44,30},{248,84,30},{255,138,36},{255,196,64},{255,226,92}}
local SUNSET={{240,70,30},{255,120,34},{255,170,50},{255,208,70},{255,232,110}}
local EMBER={{200,30,30},{226,44,30},{246,70,30},{255,130,36},{255,196,64}}
local GOLDEN={{255,96,34},{255,150,40},{255,200,60},{255,226,90},{255,240,130}}
local ALOE={
 { -- 1 "classic": a balanced rosette of 17 leaves, three spikes of 24 florets, red at the bottom and yellow at the tip
  heart={48,134,114},
  rings={ring(7,0,.35,.25,28,3.4,.9,.42,{42,124,110},{56,142,124},true),ring(6,25.7,.25,.35,48,3.0,.8,.40,{52,142,124},{66,160,140}),ring(4,45,.12,.45,68,2.4,.65,.36,{64,160,138},{80,178,152})},
  spots={.4},teeth={.5},
  spikes={{15,4.6,10},{135,4.0,10},{255,3.5,10}},socketR=.15,stalk=.18,florets=24,from=.38,to=.98,stops=RED_TO_YELLOW,bud={238,218,96},
 },
 { -- 2 "tall": fewer, longer leaves and three slim, nearly upright spikes (25 florets, more orange and yellow)
  heart={58,142,120},
  rings={ring(6,0,.30,.25,34,3.9,.85,.40,{50,134,118},{66,152,134},true),ring(5,36,.22,.35,52,3.4,.75,.38,{60,150,130},{76,168,146}),ring(3,50,.12,.45,70,2.6,.60,.34,{72,166,142},{92,186,160})},
  spots={.35,.62},teeth={.5},
  spikes={{10,5.6,5},{130,4.9,7},{250,4.3,4}},socketR=.12,stalk=.15,florets=25,from=.35,to=.99,stops=SUNSET,bud={250,226,120},
 },
 { -- 3 "wide": a low, dense rosette of 20 broad leaves and three short spikes that lean well out (21 florets, red-heavy)
  heart={40,120,104},
  rings={ring(8,0,.38,.22,22,3.2,1.0,.44,{34,112,100},{48,130,114},true),ring(7,22,.30,.32,40,2.9,.9,.42,{44,128,112},{58,146,126}),ring(5,40,.15,.42,60,2.3,.7,.38,{56,146,126},{72,164,140})},
  spots={.4},teeth={.5},
  spikes={{40,3.6,20},{160,3.2,22},{280,3.9,16}},socketR=.22,stalk=.2,florets=21,from=.5,to=.98,stops=EMBER,bud={232,196,90},
 },
 { -- 4 "windswept": 15 leaves and three spikes bunched to one side, of different heights and leans (23 florets, golden)
  heart={52,138,112},
  rings={ring(6,10,.35,.25,30,3.5,.9,.42,{44,128,112},{58,146,126},true),ring(5,40,.25,.35,50,3.0,.8,.40,{56,144,124},{70,162,140}),ring(4,20,.12,.45,70,2.4,.65,.36,{68,162,138},{84,182,154})},
  spots={.3,.62},teeth={.4},
  spikes={{0,5.0,14},{55,3.2,24},{210,4.2,8}},socketR=.18,stalk=.17,florets=23,from=.3,to=.98,stops=GOLDEN,bud={252,236,140},
 },
}
local function aloe(P)
 local S=A.AloeScale;local b=new();local up=V(0,1,0)
 b.ball('Ball',V(0,.35,0)*S,{1.1*S,.7*S,1.1*S},P.heart,nil,0,'Stem','Rosette heart')
 for _,r in ipairs(P.rings)do
  for k=0,r.n-1 do
   local a=math.rad(r.yaw+k*360/r.n);local out=V(math.cos(a),0,-math.sin(a));local e=math.rad(r.elev)
   local dir=out*math.cos(e)+up*math.sin(e);local t=V(math.sin(a),0,math.cos(a));local n=t:Cross(dir)
   local base=(out*r.r+V(0,r.y,0))*S
   local L=b.blade(base,dir,n,r.len*S,r.w*S,r.t*S,r.c1,r.c2,0,'Leaf','Aloe leaf')
   if r.spotted then
    -- outer leaves: pale spots on the upper face and red-brown teeth on the margin (alternating sides)
    for j,f in ipairs(P.spots)do
     local w=r.w*(1-f);local side=((k+j-1)%2==0)and-1 or 1
     b.ball('Ball',(L*CF((r.t/2+.01)*S,f*r.len*S,side*w*.22*S)).Position,{.04*S,.24*S,.15*S},{214,236,222},nil,0,'Leaf','Aloe leaf spot',L.Rotation)
    end
    for j,s in ipairs(P.teeth)do
     -- a thin spike leaning out of the margin toward the tip
     local side=((k+j-1)%2==0)and 1 or-1;local w2=r.w*(1-s)
     local spike=L:VectorToWorldSpace(V(0,.6,side)).Unit
     local root=(L*CF(0,s*r.len*S,side*w2/2*S)).Position
     b.add({s='Ball',z={.06*S,.24*S,.06*S},c=comps(along(root+spike*.1*S,spike,up)),k={200,92,60},m='SmoothPlastic',t=0,g=0,r='Leaf',f='Aloe leaf tooth'})
    end
   end
  end
 end
 -- three flower spikes (groups 1-3): a stalk from the heart, tilted out, with florets filling its top part; the florets grade from the bottom colour to the tip
 local F=P.florets;local stops=P.stops
 local function grade(t)local x=t*(#stops-1);local i=math.min(#stops-2,math.floor(x));local f=x-i;local a,c=stops[i+1],stops[i+2];return{math.floor(a[1]+(c[1]-a[1])*f+.5),math.floor(a[2]+(c[2]-a[2])*f+.5),math.floor(a[3]+(c[3]-a[3])*f+.5)}end
 local art={Sockets={},FruitCenters={},FruitRadii={}}
 for g,sp in ipairs(P.spikes)do
  local a=math.rad(sp[1]);local out=V(math.cos(a),0,-math.sin(a));local tilt=math.rad(sp[3])
  local dir=(up*math.cos(tilt)+out*math.sin(tilt)).Unit
  local socket=(out*P.socketR+V(0,.7,0))*S;local len=sp[2]*S;local tip=socket+dir*len
  b.rod(socket,tip,P.stalk*S,{112,150,92},nil,g,'Fruit','Aloe flower stalk')
  for i=0,F-1 do
   local f=P.from+(P.to-P.from)*i/(F-1);local yaw=math.rad(sp[1]+i*137.5);local o=V(math.cos(yaw),0,-math.sin(yaw))
   local at=socket+dir*(len*f)+o*.12*S
   local hang=(o*math.cos(math.rad(-30))+up*math.sin(math.rad(-30))).Unit -- florets hang 30 degrees below level
   b.add({s='Ball',z={.19*S,.44*S,.19*S},c=comps(along(at+hang*.18*S,hang,up)),k=grade(i/(F-1)),m='SmoothPlastic',t=0,g=g,r='Fruit',f='Aloe floret'})
  end
  b.ball('Ball',tip+dir*.1*S,{.2*S,.32*S,.2*S},P.bud,nil,g,'Fruit','Aloe bud tip',along(V(),dir,V(1,0,0)).Rotation)
  local center=socket+dir*(len*.7)
  art.Sockets[g]={socket.X,socket.Y,socket.Z};art.FruitCenters[g]={center.X,center.Y,center.Z};art.FruitRadii[g]=len*.3
 end
 art.Specs=b.Specs;art.RarityRework=true;bounds(art);return art
end
-- Sand Fruit: a round cactus ---------------------------------------------------------------------------------------
-- A part of an existing art module (by its name) as a template: its colour / material / size, so this plant uses the game's own cactus
-- pieces. If the module or the piece is missing (a stripped place), the constants given are used (they are those pieces' values).
local function template(module,name,fallback)
 local ok,art=pcall(function()return require(script.Parent[module])end)
 if ok and type(art)=='table'then
  for _,spec in ipairs(art.Specs or art[1]and art[1].Specs or{})do if spec.f==name then return{k=spec.k,m=spec.m,z=spec.z}end end
 end
 return fallback
end
-- Four designs, like the Aloe. RX x RY: the barrel's radii; ribs: 7-9; spines: areole latitudes on a rib (r = the rib number); crown: spines on the top;
-- pups: small round cacti at the foot ({yaw deg, width, height}, 0-3); fruits: {yaw deg (between two ribs: rib spacing x (index + .5)), latitude deg, size}.
local function ribSpines2(r)return{5+r%2*12,38+r%2*8}end
local function ribSpines3(r)return{-20+r%2*12,10+r%2*10,40+r%2*8}end
local function ribSpines4(r)return{-30+r%2*10,-5+r%2*10,20+r%2*8,45+r%2*6}end
local CACTUS={
 { -- 1 "barrel": the round barrel with 8 ribs, two pups and a fruit on each shoulder
  RX=5.4,RY=4.7,ribs=8,spines=ribSpines3,crown=6,pups={{V(-4.3,1.5,1.2),3.2,2.8},{V(3.4,1.3,-3.4),2.8,2.5}},
  fruits={{22.5,46,1},{112.5,38,1},{202.5,46,1},{292.5,38,1}},
 },
 { -- 2 "tall": a taller, narrower barrel with 9 ribs, sparse spines, one pup and the fruits high on the shoulders, in different sizes
  RX=4.4,RY=6.2,ribs=9,spines=ribSpines2,crown=4,pups={{154,2.6,2.4}},
  fruits={{20,58,1},{100,50,.9},{180,58,1.05},{300,50,.85}},
 },
 { -- 3 "squat": a wide, low barrel with 7 ribs, dense spines, three pups and big fruits low on the shoulders
  RX=6.4,RY=3.9,ribs=7,spines=ribSpines4,crown=8,pups={{200,3.0,2.6},{20,2.6,2.3},{300,2.2,2.0}},
  fruits={{25.7,34,1.1},{128.6,40,1.1},{231.4,34,1.1},{334.3,40,1.1}},
 },
 { -- 4 "ribbed": a barrel with 9 ribs, no pups and four fruits scattered unevenly, one almost on top
  RX=5.0,RY=5.4,ribs=9,spines=ribSpines3,crown=5,pups={},
  fruits={{20,40,1.1},{100,56,.9},{220,36,1},{300,64,.85}},
 },
}
-- A pup (small round cactus) at the foot, its centre a little outside the barrel's surface at that height so that it touches it.
local function pupAt(P,yawDeg,w,h)
 local y=h*.52;local body=P.RX*math.sqrt(math.max(0,1-((P.RY-y)/P.RY)^2));local d=body+w*.15;local a=math.rad(yawDeg)
 return{V(d*math.cos(a),y,d*math.sin(a)),w,h}
end
local function cactus(P)
 local b=new();local up=V(0,1,0)
 -- the existing cactus pieces: Prickly Pear stem green, Crown Cactus rib and ivory spine, Prickly Pear fruit attachment
 local stem=template('ApprovedPlantArt6','Rectangular cactus stem',{k={65,143,69},m='SmoothPlastic'})
 local rib=template('AgaveSeedArt45','Cactus rib',{k={83,153,107},m='SmoothPlastic',z={21,.34,.34}})
 local spine=template('AgaveSeedArt45','Ivory spine',{k={235,225,170},m='SmoothPlastic',z={.18,.7,.4}})
 local attach=template('ApprovedPlantArt6','Upper surface fruit attachment',{k={98,143,65},m='SmoothPlastic'})
 -- the body: a squat ball (radii RX x RY x RX) standing on the soil
 local RX,RY=P.RX,P.RY;local CY=RY
 local big=1.5 -- the spines are scaled up with the body (the Prickly Pear's are x3 on its pads)
 local function surface(lat,yaw)
  local cl,sl=math.cos(lat),math.sin(lat)
  local p=V(RX*cl*math.cos(yaw),CY+RY*sl,RX*cl*math.sin(yaw))
  return p,V(p.X/(RX*RX),(p.Y-CY)/(RY*RY),p.Z/(RX*RX)).Unit
 end
 b.ball('Ball',V(0,CY,0),{2*RX,2*RY,2*RX},stem.k,stem.m,0,'Stem','Cactus body')
 -- pups at the foot (small round cacti), each with three ivory spines
 for k,pup in ipairs(P.pups)do
  if type(pup[1])=='number'then pup=pupAt(P,pup[1],pup[2],pup[3])end
  b.ball('Ball',pup[1],{pup[2],pup[3],pup[2]},stem.k,stem.m,0,'Stem','Cactus pup')
  for j=0,2 do
   local a=math.rad(k*70+j*120);local out=V(math.cos(a),.55,math.sin(a)).Unit
   local base=pup[1]+V(out.X*pup[2]*.46,out.Y*pup[3]*.46,out.Z*pup[2]*.46)
   b.add({s='Wedge',z={spine.z[1]*big,spine.z[2]*big,spine.z[3]*big},c=comps(along(base+out*.3*big,out,V(math.sin(a),0,-math.cos(a)))),k=spine.k,m=spine.m,t=0,g=0,r='Stem',f='Ivory spine'})
  end
 end
 -- ribs from the foot to the crown, five raised pieces each (the Crown Cactus' rib, bent round the ball: short enough that the chord
 -- between two ends stays on the surface)
 local lats={-56,-31,-6,19,44,68}
 local ribWidth=rib.z[2]*1.25
 local function spineAt(p,n,dir,tangent)
  b.add({s='Wedge',z={spine.z[1]*big,spine.z[2]*big,spine.z[3]*big},c=comps(along(p+dir*.3*big,dir,tangent)),k=spine.k,m=spine.m,t=0,g=0,r='Stem',f='Ivory spine'})
 end
 for r=0,P.ribs-1 do
  local yaw=math.rad(r*360/P.ribs)
  for i=1,#lats-1 do
   local p1,n1=surface(math.rad(lats[i]),yaw);local p2,n2=surface(math.rad(lats[i+1]),yaw)
   b.rod(p1+n1*.1,p2+n2*.1,ribWidth,rib.k,rib.m,0,'Stem','Cactus rib')
  end
  -- ivory spines at the areoles of every rib, leaning outward and a little up
  for _,lat in ipairs(P.spines(r))do
   local p,n=surface(math.rad(lat),yaw);spineAt(p,n,(n*.85+up*.25).Unit,V(-math.sin(yaw),0,math.cos(yaw)))
  end
 end
 -- a crown of ivory spines on the very top, fanning outward
 for j=0,P.crown-1 do
  local a=math.rad(j*360/P.crown+15);local p,n=surface(math.rad(80),a);local out=V(math.cos(a),0,math.sin(a))
  spineAt(p,n,(n*.6+out*.7+up*.2).Unit,V(-math.sin(a),0,math.cos(a)))
 end
 -- four sand fruits (groups 1-4) growing out of the shoulders, between the ribs: a short green attachment, a squashed Sand ball, a lump
 -- on one side and a tiny nub on top, so each is slightly irregular. Fruit radius ~1.15 x its size.
 local art={Sockets={},FruitCenters={},FruitRadii={}}
 local sands={{226,194,128},{216,183,118},{232,202,138},{221,188,123}}
 local lumps={{206,172,106},{212,178,112},{200,166,102},{210,176,110}}
 for g,fruit in ipairs(P.fruits)do
  local yaw=math.rad(fruit[1]);local lat=math.rad(fruit[2]);local s=fruit[3]
  local p,n=surface(lat,yaw);local tangent=V(-math.sin(yaw),0,math.cos(yaw))
  local center=p+n*.92*s
  b.rod(p-n*.3,center-n*.2,.5,attach.k,attach.m,g,'Fruit','Fruit stem')
  local frame=along(center,n,tangent)
  b.add({s='Ball',z={2.4*s,2.0*s,2.2*s},c=comps(frame*CFrame.Angles(0,.5*g,.12*(g%2==0 and 1 or -1))),k=sands[g],m='Sand',t=0,g=g,r='Fruit',f='Sand fruit'})
  local side=(tangent*math.cos(g*1.7)+n:Cross(tangent)*math.sin(g*1.7)).Unit
  b.add({s='Ball',z={1.3*s,1.1*s,1.25*s},c=comps(CF(center+side*.62*s-n*.12*s)*frame.Rotation),k=lumps[g],m='Sand',t=0,g=g,r='Fruit',f='Sand fruit lump'})
  b.add({s='Ball',z={.5*s,.56*s,.5*s},c=comps(CF(center+n*.95*s-side*.12*s)*frame.Rotation),k={236,210,150},m='Sand',t=0,g=g,r='Fruit',f='Sand fruit nub'})
  art.Sockets[g]={p.X,p.Y,p.Z};art.FruitCenters[g]={center.X,center.Y,center.Z};art.FruitRadii[g]=1.15*s
 end
 art.Specs=b.Specs;art.RarityRework=true;bounds(art);return art
end
-- The designs of an id (built once). Design 1 is the base design: what a crop without an id (a preview) shows, and what the catalog's sockets come from.
A.Names={DesertAloeSeed={'classic','tall','wide','windswept'},SandFruitSeed={'barrel','tall','squat','ribbed'}}
local built={}
function A.Designs(id)
 if not A.Is(id)then return nil end
 if not built[id]then
  local list={}
  if id=='DesertAloeSeed'then for i,P in ipairs(ALOE)do list[i]=aloe(P)end
  else for i,P in ipairs(CACTUS)do list[i]=cactus(P)end end
  built[id]=list
 end
 return built[id]
end
function A.Get(id)local list=A.Designs(id);return list and list[1]end
-- The catalog's bounds: the biggest design's, with the 5% margin the approved plants' bounds carry for the per-crop size jitter (ApprovedPlantArt).
A.BoundsMargin=1.05
function A.Bounds(id)
 local height,radius=0,0
 for _,art in ipairs(A.Designs(id)or{})do height=math.max(height,art.Height);radius=math.max(radius,art.Radius)end
 return height*A.BoundsMargin,radius*A.BoundsMargin
end
return A
