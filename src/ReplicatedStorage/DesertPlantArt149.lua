-- R148 (owner): plant art of Desert's two new seeds, in the RarityRework spec format PlantVisuals reads (like VerityPlantArt).
--  * DesertAloeSeed (Rare, "Aloe"): a blue-green rosette of thick pointed leaves (pale spots, red-brown teeth) with three tall
--    red-orange flower spikes. Each spike is one fruit (group 1-3); harvesting it leaves the rosette.
--  * SandFruitSeed (Legendary, "Sand Fruit"): a leaning desert palm (ringed trunk, eight arching fronds) with four bunches of
--    three round sand-gold fruits under the crown. Each bunch is one fruit (group 1-4).
-- Built once per id; numbers are studs at PlantScale 1. No requires (ApprovedPlantArt and Roster149 load it).
local A={}
local V,CF=Vector3.new,CFrame.new
A.AloeScale=1.5
A.Ids={DesertAloeSeed=true,SandFruitSeed=true}
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
local function aloe()
 local S=A.AloeScale;local b=new();local up=V(0,1,0)
 b.ball('Ball',V(0,.35,0)*S,{1.1*S,.7*S,1.1*S},{98,150,128},nil,0,'Stem','Rosette heart')
 -- three rings: count, first yaw (deg), base radius, base y, elevation (deg), length, width, thickness, two colours, outer?
 local rings={
  {7,0,.35,.25,28,3.4,.9,.42,{88,140,122},{100,154,134},true},
  {6,25.7,.25,.35,48,3.0,.8,.40,{100,156,138},{112,168,148},false},
  {4,45,.12,.45,68,2.4,.65,.36,{116,172,152},{128,184,160},false},
 }
 for _,r in ipairs(rings)do
  for k=0,r[1]-1 do
   local a=math.rad(r[2]+k*360/r[1]);local out=V(math.cos(a),0,-math.sin(a));local e=math.rad(r[5])
   local dir=out*math.cos(e)+up*math.sin(e);local t=V(math.sin(a),0,math.cos(a));local n=t:Cross(dir)
   local base=(out*r[3]+V(0,r[4],0))*S
   local L=b.blade(base,dir,n,r[6]*S,r[7]*S,r[8]*S,r[9],r[10],0,'Leaf','Aloe leaf')
   if r[11]then
    -- outer leaves: two pale spots on the upper face and one red-brown tooth on each margin (halfway up)
    for _,s in ipairs({.3,.55})do
     local w=r[7]*(1-s)
     b.ball('Ball',(L*CF((r[8]/2+.01)*S,s*r[6]*S,(s<.4 and -1 or 1)*w*.22*S)).Position,{.04*S,.24*S,.15*S},{204,228,214},nil,0,'Leaf','Aloe leaf spot',L.Rotation)
    end
    for _,side in ipairs({-1,1})do
     -- a thin spike leaning out of the margin toward the tip
     local s=.5;local w=r[7]*(1-s)
     local spike=L:VectorToWorldSpace(V(0,.6,side)).Unit
     local root=(L*CF(0,s*r[6]*S,side*w/2*S)).Position
     b.add({s='Ball',z={.06*S,.24*S,.06*S},c=comps(along(root+spike*.1*S,spike,up)),k={176,120,96},m='SmoothPlastic',t=0,g=0,r='Leaf',f='Aloe leaf tooth'})
    end
   end
  end
 end
 -- three flower spikes (groups 1-3): a stalk from the heart, tilted 10 degrees out, with 9 tubular florets on its top 40%
 local spikes={{15,4.6},{135,4.0},{255,3.5}}
 local art={Sockets={},FruitCenters={},FruitRadii={}}
 for g,sp in ipairs(spikes)do
  local a=math.rad(sp[1]);local out=V(math.cos(a),0,-math.sin(a));local tilt=math.rad(10)
  local dir=(up*math.cos(tilt)+out*math.sin(tilt)).Unit
  local socket=(out*.15+V(0,.7,0))*S;local len=sp[2]*S;local tip=socket+dir*len
  b.rod(socket,tip,.16*S,{126,146,100},nil,g,'Fruit','Aloe flower stalk')
  for i=0,8 do
   local f=.6+.4*i/9;local yaw=math.rad(sp[1]+i*137.5);local o=V(math.cos(yaw),0,-math.sin(yaw))
   local at=socket+dir*(len*f)+o*.12*S
   local hang=(o*math.cos(math.rad(-30))+up*math.sin(math.rad(-30))).Unit -- florets hang 30 degrees below level
   local color=i<4 and{236,96,48}or i<7 and{250,150,60}or{240,196,92}
   b.add({s='Ball',z={.16*S,.42*S,.16*S},c=comps(along(at+hang*.18*S,hang,up)),k=color,m='SmoothPlastic',t=0,g=g,r='Fruit',f='Aloe floret'})
  end
  b.ball('Ball',tip+dir*.1*S,{.18*S,.3*S,.18*S},{226,206,110},nil,g,'Fruit','Aloe bud tip',along(V(),dir,V(1,0,0)).Rotation)
  local center=socket+dir*(len*.8)
  art.Sockets[g]={socket.X,socket.Y,socket.Z};art.FruitCenters[g]={center.X,center.Y,center.Z};art.FruitRadii[g]=len*.3
 end
 art.Specs=b.Specs;art.RarityRework=true;bounds(art);return art
end
-- Sand Fruit palm --------------------------------------------------------------------------------------------------
local function palm()
 local b=new();local up=V(0,1,0)
 -- root flare and trunk: 5 segments leaning toward +X, darker rings at the joints
 b.rod(V(0,0,0),V(0,.6,0),2.0,{128,94,58},'Wood',0,'Stem','Palm root flare')
 for k=0,2 do
  local a=math.rad(30+k*120);local out=V(math.cos(a),0,-math.sin(a))
  b.add({s='Wedge',z={.35,.5,.9},c=comps(along(out*1.05+V(0,.25,0),up,out)*CFrame.Angles(0,math.pi/2,0)),k={120,88,54},m='Wood',t=0,g=0,r='Stem',f='Palm root toe'})
 end
 local joints={V(0,0,0),V(.05,2.2,0),V(.2,4.4,0),V(.45,6.6,0),V(.75,8.8,0),V(1.1,11.0,0)}
 local diam={1.45,1.35,1.25,1.15,1.05}
 for i=1,5 do
  b.rod(joints[i],joints[i+1],diam[i],i%2==1 and{150,110,70}or{136,99,62},'Wood',0,'Stem','Palm trunk')
  local d=(joints[i+1]-joints[i]).Unit
  b.rod(joints[i+1]-d*.11,joints[i+1]+d*.11,diam[i]+.25,{112,80,50},'Wood',0,'Stem','Palm trunk ring')
 end
 local crown=V(1.1,11.4,0)
 b.ball('Ball',crown,{1.7,1.3,1.7},{108,130,60},nil,0,'Leaf','Palm crown heart')
 -- four dried frond boots under the crown
 for k=0,3 do
  local a=math.rad(45+k*90);local out=V(math.cos(a),0,-math.sin(a))
  b.blade(crown+out*.45-V(0,.55,0),(out*.8-up*.6).Unit,up,1.1,.55,.18,{170,130,80},{158,120,72},0,'Leaf','Dry frond boot')
 end
 -- eight fronds: a rising inner blade with a rachis, then a drooping outer blade
 for k=0,7 do
  local a=math.rad(k*45+(k%2)*6);local out=V(math.cos(a),0,-math.sin(a))
  local e1,e2=math.rad(k%2==0 and 25 or 18),math.rad(-25)
  local d1=out*math.cos(e1)+up*math.sin(e1);local d2=out*math.cos(e2)+up*math.sin(e2)
  local t=V(math.sin(a),0,math.cos(a))
  local base=crown+out*.5
  b.rod(base,base+d1*3.0,.14,{120,150,70},nil,0,'Leaf','Palm frond rachis')
  b.blade(base,d1,t:Cross(d1),3.0,1.5,.12,{86,150,72},{98,164,80},0,'Leaf','Palm frond')
  b.blade(base+d1*3.0,d2,t:Cross(d2),3.2,1.2,.12,{98,160,76},{124,160,82},0,'Leaf','Palm frond tip')
 end
 -- two young fronds standing up in the middle
 for k=0,1 do
  local a=math.rad(90+k*180);local out=V(math.cos(a),0,-math.sin(a));local e=math.rad(65)
  local d=out*math.cos(e)+up*math.sin(e);local t=V(math.sin(a),0,math.cos(a))
  b.blade(crown+V(0,.4,0),d,t:Cross(d),2.6,1.0,.12,{112,176,86},{124,186,94},0,'Leaf','Young palm frond')
 end
 -- four bunches (groups 1-4) between the fronds: a stalk and three round sand fruits, each with a dune-ripple band
 local art={Sockets={},FruitCenters={},FruitRadii={}}
 local skins={{222,182,112},{214,170,98},{230,192,124}}
 for g=1,4 do
  local a=math.rad(22.5+(g-1)*90);local out=V(math.cos(a),0,-math.sin(a))
  local socket=crown+out*.95-V(0,.6,0)
  local tip=socket+(out*.5-up*.78).Unit*.9
  -- R134 floating check: the stalk starts INSIDE the crown heart (it is the bunch's stem, taken from the crown with the bunch) and its tip
  -- ends inside the three fruits (their centres are .47 from it, the fruit radius .525), so nothing in a bunch hangs loose.
  b.rod(crown+out*.45-V(0,.3,0),tip,.18,{140,110,60},nil,g,'Fruit','Sand fruit stalk')
  local center=tip-V(0,.22,0)
  for j=0,2 do
   local ja=a+math.rad(j*120+60);local o=V(math.cos(ja),0,-math.sin(ja))
   local p=center+o*.42-V(0,.05*j,0)
   b.ball('Sphere',p,{1.05,1.05,1.05},skins[j+1],nil,g,'Fruit','Sand fruit')
   b.ball('Ball',p+V(0,.08,0),{1.1,.16,1.1},{184,138,78},nil,g,'Fruit','Sand fruit ripple',CFrame.Angles(.18,0,.1))
  end
  b.ball('Ball',center+V(math.cos(a)*.42,.42,-math.sin(a)*.42),{.18,.18,.18},{255,236,170},'Neon',g,'Fruit','Sand sparkle')
  art.Sockets[g]={socket.X,socket.Y,socket.Z};art.FruitCenters[g]={center.X,center.Y,center.Z};art.FruitRadii[g]=1.05
 end
 art.Specs=b.Specs;art.RarityRework=true;bounds(art);return art
end
local built={}
function A.Get(id)
 if not A.Is(id)then return nil end
 if not built[id]then built[id]=id=='DesertAloeSeed'and aloe()or palm()end
 return built[id]
end
return A
