-- R151 Seed Festival Square, client half ("life"): trees, bushes, topiary, flower beds, verges, lamps, benches, signposts, bunting, the
-- Seed Fountain, wall lanterns, grass patches, pebbles and butterflies, built on each player's screen by HubLife151.client.
-- Owner (approving the design): "polish the trees, give them more variety and the stuff and everything". So every prop comes in species /
-- variants, and each instance gets its own deterministic variation (scale, lean, turn, colour shade, canopy layering) from a seed made of
-- its kind and position: every client builds the same square, and no two trees look cloned.
-- Detail levels (A.Build puts every part in a per-cell Folder of its level, the client shows / hides those Folders by distance):
--   core    silhouettes seen from anywhere: trunks and main crowns, lamps, benches, signposts, the fountain, grass patches
--   detail  within ~230 studs and device tier >= 2: extra crown layers, fruit, flowers, pots, pebbles, bunting, wall lanterns
--   fine    within ~130 studs and tier 3: butterflies, blossom petals, fountain sparkles, small extras
-- Nothing here collides or can be touched / queried; nothing stands on a street, a base, the run-up, the market, Verity or the reserved
-- back corners (R151 displays) - A.Clear(x, z, r) checks it.
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'))
local A={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Mat=Enum.Material
local P,FLOOR=K.P,K.Floor
A.Version=151
A.CellSize=100
A.Levels={'core','detail','fine'}
A.LevelOf={core=1,detail=2,fine=3}

-- Palettes (shared colours keep it instancing-friendly) --------------------------------------------------------------------------------------
local GREENS={{88,170,72},{104,184,84},{76,156,66},{120,196,92},{96,176,70},{70,148,74}}
local DARK_GREENS={{58,128,66},{70,140,74},{52,118,60},{64,134,80}}
local BLOSSOMS={pink={{248,172,204},{255,200,224},{236,150,190}},white={{255,246,250},{250,236,242},{240,240,232}},lilac={{206,170,240},{224,196,250},{190,150,228}}}
local FRUITS={apple={226,52,52},orange={255,150,40},lemon={250,220,60},plum={140,70,170}}
local BARKS={{150,104,64},{132,92,58},{164,116,72},{120,86,56}}
local EMBERS={{176,52,34},{214,84,40},{150,40,36},{236,120,48}}
local FLOWERS={warm={{255,96,120},{255,214,80},{255,255,255},{255,150,60},{255,120,170}},cool={{170,120,255},{120,200,255},{255,255,255},{255,170,220},{140,220,200}},
 desert={{255,200,90},{255,120,60},{255,255,255},{240,90,120}},lava={{255,90,40},{255,170,40},{150,30,30},{255,220,90}},snow={{200,230,255},{255,255,255},{150,190,255}}}
local BUNTING={rainbow={{255,96,96},{255,206,72},{96,200,120},{90,170,255},{190,120,255}},candy={{236,104,92},{252,244,226},{52,168,160},{244,196,86}}}
A.Palettes={Greens=GREENS,Blossoms=BLOSSOMS,Fruits=FRUITS,Flowers=FLOWERS}

-- Where props may stand -------------------------------------------------------------------------------------------------------------------------
local BLOCKED={ -- (x0, x1, z0, z1): the market, the leaderboards, the gate towers' feet
 {-30,30,-296,-244},{-131,-101,-121,-105},{101,131,-121,-105},{-110,-88,-110,-92},{88,110,-110,-92},
}
function A.Clear(x,z,r,bases,allowPaving)
 r=r or 0
 if math.abs(x)>333-r or z>-106+r or z<-616+r then return false,'wall'end
 if K.InReserved(x,z,r)then return false,'reserved'end
 if z>-152-r and math.abs(x)<92+r then return false,'run-up'end
 for _,b in ipairs(BLOCKED)do if x>b[1]-r and x<b[2]+r and z>b[3]-r and z<b[4]+r then return false,'blocked'end end
 if (x*x+(z+340)^2)<(16+r)^2 then return false,'verity'end
 if not allowPaving then
  for _,s in ipairs(K.Streets)do if x>math.min(s[1],s[2])-r and x<math.max(s[1],s[2])+r and z>math.min(s[3],s[4])-r and z<math.max(s[3],s[4])+r then return false,'street'end end
  for _,d in ipairs(K.Discs)do if((x-d[1])^2+(z-d[2])^2)<(d[3]+r)^2 then return false,'plaza'end end
 end
 for _,b in pairs(bases or{})do -- base pads plus their fences (2.2 out) and the spur in front of the opening
  local l=b.Frame:PointToObjectSpace(V(x,0,z));local hx,hz=b.Size.X/2+2.6+r,b.Size.Z/2+2.6+r
  if math.abs(l.X)<hx and math.abs(l.Z)<hz then return false,'base'end
 end
 return true
end

-- The builder context: parts go into per-cell level folders; levels above the tier are skipped -----------------------------------------------
local function context(root,tier)
 local ctx={Root=root,Tier=tier,Cells={},Counts={core=0,detail=0,fine=0},Lights={},Emitters={},Butterflies={},Signs={},Lanterns={},Fountain=nil}
 function ctx.Folder(level,x,z)
  if A.LevelOf[level]>ctx.Tier then return nil end
  local cx,cz=math.floor(x/A.CellSize),math.floor(z/A.CellSize);local key=cx..':'..cz
  local cell=ctx.Cells[key]
  if not cell then
   local f=Instance.new('Folder');f.Name='Cell '..key;f.Parent=root
   cell={Key=key,Folder=f,Levels={},Sum=V(0,0,0),N=0};ctx.Cells[key]=cell
  end
  cell.Sum+=V(x,0,z);cell.N+=1
  local lf=cell.Levels[level]
  if not lf then lf=Instance.new('Folder');lf.Name=level;lf.Parent=cell.Folder;cell.Levels[level]=lf end
  return lf
 end
 -- wrappers that skip (return nil) when the level is not built on this device
 local function counted(level,fn)return function(x,z,...)local f=ctx.Folder(level,x,z);if not f then return nil end;ctx.Counts[level]+=1;return fn(f,...)end end
 ctx.Part=function(level,x,z,...)return counted(level,K.Part)(x,z,...)end
 ctx.Ball=function(level,x,z,...)return counted(level,K.Ball)(x,z,...)end
 ctx.Cyl=function(level,x,z,...)return counted(level,K.Cyl)(x,z,...)end
 ctx.VCyl=function(level,x,z,...)return counted(level,K.VCyl)(x,z,...)end
 ctx.Wedge=function(level,x,z,...)return counted(level,K.Wedge)(x,z,...)end
 ctx.Rod=function(level,x,z,...)return counted(level,K.Rod)(x,z,...)end
 return ctx
end
local function pick(rng,list)return list[math.floor(rng(1,#list+.999))]end
local function shade(c,rng,k)k=k or 10;local d=rng(-k,k);return{math.clamp(c[1]+d,0,255),math.clamp(c[2]+d,0,255),math.clamp(c[3]+d*.6,0,255)}end

-- Trees ---------------------------------------------------------------------------------------------------------------------------------------
-- A leaning trunk: returns the CFrame at its top so crowns follow the lean.
local function trunk(ctx,x,z,rng,d,h,color,level)
 local lean=CFrame.Angles(math.rad(rng(-6,6)),rng(0,math.pi*2),math.rad(rng(-6,6)))
 local base=CF(x,FLOOR,z)*lean
 ctx.Cyl(level or'core',x,z,'Tree trunk',d,h+.2,base*CF(0,h/2-.1,0),color,Mat.Wood)
 return base*CF(0,h,0)
end
local function crown(ctx,x,z,level,name,d,pos,color,mat)return ctx.Ball(level,x,z,name,d,pos,color,mat or Mat.Grass)end
-- Round oak: S / M / L, 3-5 layered crown balls in neighbouring greens, a root flare.
function A.Oak(ctx,x,z,size)
 local rng=K.Rng('oak'..size..x..z);local s=({S=.75,M=1,L=1.3})[size]*rng(.9,1.12)
 local g=pick(rng,GREENS);local top=trunk(ctx,x,z,rng,1.9*s,8.5*s,pick(rng,BARKS))
 ctx.VCyl('detail',x,z,'Root flare',3*s,FLOOR-.1,FLOOR+1.1*s,x,z,P.WoodDark,Mat.Wood)
 crown(ctx,x,z,'core','Tree crown',11*s,(top*CF(0,3.4*s,0)).Position,shade(g,rng))
 local n=math.floor(rng(2,4.99))
 for i=1,n do local a=i/n*math.pi*2+rng(0,1)
  crown(ctx,x,z,'detail','Tree crown',rng(6,8.5)*s,(top*CF(math.cos(a)*4.2*s,rng(1,5)*s,math.sin(a)*4.2*s)).Position,shade(pick(rng,GREENS),rng))
 end
 crown(ctx,x,z,'detail','Tree crown top',rng(5.5,7)*s,(top*CF(rng(-1.5,1.5)*s,7.6*s,rng(-1.5,1.5)*s)).Position,shade(g,rng,16))
end
-- Tall poplar / cypress: a slim trunk and a column of tapering balls.
function A.Poplar(ctx,x,z)
 local rng=K.Rng('poplar'..x..z);local s=rng(.85,1.15);local g=pick(rng,DARK_GREENS)
 local top=trunk(ctx,x,z,rng,1.1*s,3.5*s,pick(rng,BARKS))
 local ds={6.4,5.8,5,4,2.8};local y=1.8*s
 for i,d in ipairs(ds)do
  crown(ctx,x,z,i<=2 and'core'or'detail','Poplar crown',d*s,(top*CF(0,y,0)).Position,shade(g,rng,8))
  y+=d*s*.62
 end
end
-- Blossom trees in pink / white / lilac with a couple of green leaf tufts and falling petals.
function A.Blossom(ctx,x,z,colour)
 local rng=K.Rng('blossom'..colour..x..z);local s=rng(.85,1.1);local pal=BLOSSOMS[colour]
 local top=trunk(ctx,x,z,rng,1.6*s,8*s,{110,78,60})
 local main=crown(ctx,x,z,'core','Blossom crown',10.5*s,(top*CF(0,3*s,0)).Position,shade(pick(rng,pal),rng,6),Mat.SmoothPlastic)
 for i=1,3 do local a=i*2.1+rng(0,1)
  crown(ctx,x,z,'detail','Blossom crown',rng(5.5,7.5)*s,(top*CF(math.cos(a)*4*s,rng(1.5,4.5)*s,math.sin(a)*4*s)).Position,shade(pick(rng,pal),rng,6),Mat.SmoothPlastic)
 end
 crown(ctx,x,z,'detail','Leaf tuft',3.6*s,(top*CF(rng(-3,3)*s,-.4*s,rng(-3,3)*s)).Position,pick(rng,GREENS))
 local host=ctx.Part('fine',x,z,'Petal source',V(6*s,.2,6*s),CF((top*CF(0,1.5*s,0)).Position),{255,255,255},Mat.SmoothPlastic,{t=1,shadow=false})
 if host then
  local pe=Instance.new('ParticleEmitter');pe.Name='Falling petals';pe.Rate=1.5;pe.Lifetime=NumberRange.new(5,7);pe.Speed=NumberRange.new(.3,.8)
  pe.Acceleration=V(0,-.5,0);pe.Color=ColorSequence.new(K.C(pal[1]));pe.Size=NumberSequence.new(.35);pe.LightEmission=.1;pe.Rotation=NumberRange.new(0,360);pe.RotSpeed=NumberRange.new(-60,60)
  pe.Enabled=false;pe.Parent=host;table.insert(ctx.Emitters,pe)
 end
 return main
end
-- Fruit trees: a smaller round crown with fruit just showing on its surface.
function A.FruitTree(ctx,x,z,fruit)
 local rng=K.Rng('fruit'..fruit..x..z);local s=rng(.8,1)
 local top=trunk(ctx,x,z,rng,1.6*s,6.5*s,pick(rng,BARKS))
 local c=(top*CF(0,3*s,0)).Position;local d=9.5*s
 crown(ctx,x,z,'core','Tree crown',d,c,shade(pick(rng,GREENS),rng))
 crown(ctx,x,z,'detail','Tree crown',6*s,c+V(rng(-2,2)*s,3.4*s,rng(-2,2)*s),shade(pick(rng,GREENS),rng))
 local n=math.floor(rng(4,6.99))
 for i=1,n do local a=i/n*math.pi*2+rng(0,.6);local e=rng(-.35,.55)
  local dir=V(math.cos(a)*math.cos(e),math.sin(e),math.sin(a)*math.cos(e))
  ctx.Ball('detail',x,z,'Fruit',rng(1.1,1.5)*s,c+dir*(d/2+.15),FRUITS[fruit],Mat.SmoothPlastic)
 end
end
-- Pines for the Snow lane: 3-4 tapered tiers, snow on the tips.
function A.Pine(ctx,x,z,s)
 local rng=K.Rng('pine'..x..z);s=(s or 1)*rng(.85,1.15);local g=pick(rng,DARK_GREENS)
 ctx.VCyl('core',x,z,'Pine trunk',1.3*s,FLOOR,FLOOR+3.6*s,x,z,P.WoodDark,Mat.Wood)
 local tiers=rng()<.5 and 3 or 4;local y=FLOOR+3*s
 for i=1,tiers do local d=(9.4-i*(tiers==3 and 2 or 1.6))*s;local h=3.4*s
  ctx.VCyl(i<=2 and'core'or'detail',x,z,'Pine tier',d,y,y+h,x,z,shade(g,rng,6),Mat.Grass)
  if i>1 then ctx.VCyl('detail',x,z,'Snow rim',d*.86,y+h,y+h+.3,x,z,{246,250,255},Mat.Snow)end
  y+=h*.8
 end
 ctx.Ball('detail',x,z,'Pine snow',2.4*s,V(x,y+1.6*s,z),{246,250,255},Mat.Snow)
end
-- Palms for the Desert garden: a curving trunk, drooping leaves, coconuts.
function A.Palm(ctx,x,z)
 local rng=K.Rng('palm'..x..z);local s=rng(.85,1.15);local a=rng(0,math.pi*2)
 local lean=V(math.cos(a),0,math.sin(a))*rng(.8,1.5)*s;local base=V(x,FLOOR,z);local prev=base
 for k=1,3 do local nxt=base+lean*(k*k*.45)+V(0,k*4.3*s,0)
  ctx.Rod(k==1 and'core'or'core',x,z,'Palm trunk',prev,nxt,(1.5-k*.15)*s,{150,112,72},Mat.Wood,{shadow=true});prev=nxt
 end
 local crownAt=prev;local n=math.floor(rng(6,8.99))
 for i=1,n do local ang=i/n*math.pi*2+rng(0,.4);local reach=rng(5.5,7)*s
  local tip=crownAt+V(math.cos(ang)*reach,-rng(2,3.4)*s,math.sin(ang)*reach)
  ctx.Part(i<=4 and'core'or'detail',x,z,'Palm leaf',V(reach+1,.35,rng(1.7,2.3)*s),CFrame.lookAt((crownAt+tip)/2,tip)*CFrame.Angles(0,math.pi/2,0),shade({60,150,72},rng,14),Mat.Grass)
 end
 for i=1,math.floor(rng(2,3.99))do ctx.Ball('detail',x,z,'Coconut',1.3*s,crownAt+V(rng(-.8,.8),-1.1,rng(-.8,.8)),{120,84,52})end
end
-- Cacti: a saguaro with one or two arms, or a barrel cactus; flowers on top.
function A.Cactus(ctx,x,z,kind)
 local rng=K.Rng('cactus'..kind..x..z);local s=rng(.85,1.2);local g=shade({86,160,74},rng,12)
 if kind=='barrel'then
  ctx.Ball('core',x,z,'Barrel cactus',3.2*s,V(x,FLOOR+1.2*s,z),g,Mat.Grass)
  ctx.Ball('detail',x,z,'Cactus flower',1.1*s,V(x,FLOOR+2.8*s,z),pick(rng,FLOWERS.desert))
  return
 end
 local h=rng(6,8.5)*s
 ctx.VCyl('core',x,z,'Cactus',2.2*s,FLOOR,FLOOR+h,x,z,g,Mat.Grass);ctx.Ball('core',x,z,'Cactus top',2.2*s,V(x,FLOOR+h,z),g,Mat.Grass)
 local arms=rng()<.5 and 1 or 2;local a=rng(0,math.pi*2)
 for i=1,arms do local ang=a+(i-1)*math.pi;local dx,dz=math.cos(ang)*1.9*s,math.sin(ang)*1.9*s;local y0=FLOOR+rng(2.4,3.6)*s
  ctx.Rod('detail',x,z,'Cactus arm',V(x,y0,z),V(x+dx,y0,z+dz),1.3*s,g,Mat.Grass,{shadow=true})
  ctx.VCyl('detail',x,z,'Cactus arm',1.4*s,y0,y0+rng(2,3.2)*s,x+dx,z+dz,g,Mat.Grass)
 end
 ctx.Ball('detail',x,z,'Cactus flower',1*s,V(x,FLOOR+h+1,z),pick(rng,FLOWERS.desert))
end
-- Ember trees for the Lava garden: charred leaning trunks, smouldering crowns with a few glowing embers.
function A.EmberTree(ctx,x,z)
 local rng=K.Rng('ember'..x..z);local s=rng(.8,1.1)
 local top=trunk(ctx,x,z,rng,1.8*s,8*s,{58,44,44})
 local c=(top*CF(0,2.6*s,0)).Position
 crown(ctx,x,z,'core','Ember crown',9.5*s,c,pick(rng,EMBERS),Mat.SmoothPlastic)
 for i=1,2 do local a=i*2.6+rng(0,1)
  crown(ctx,x,z,'detail','Ember crown',rng(5,7)*s,c+V(math.cos(a)*3.6*s,rng(.5,3)*s,math.sin(a)*3.6*s),pick(rng,EMBERS),Mat.SmoothPlastic)
 end
 ctx.Rod('detail',x,z,'Charred branch',(top*CF(0,-2*s,0)).Position,(top*CF(4*s,1*s,1*s)).Position,.7*s,{58,44,44},Mat.Wood)
 for i=1,3 do ctx.Ball('detail',x,z,'Ember',rng(.8,1.2),c+V(rng(-4,4)*s,rng(-3.5,-2)*s,rng(-4,4)*s),{255,170,60},Mat.Neon)end
end
function A.GlowRock(ctx,x,z)
 local rng=K.Rng('rock'..x..z);local s=rng(.8,1.3)
 ctx.Ball('core',x,z,'Basalt rock',4*s,V(x,FLOOR+.8*s,z),shade({66,56,66},rng,8),Mat.Basalt)
 ctx.Ball('detail',x,z,'Basalt rock',2.4*s,V(x+2.2*s,FLOOR+.3*s,z+.8*s),shade({76,62,70},rng,8),Mat.Basalt)
 ctx.Ball('detail',x,z,'Ember glow',1.5*s,V(x+1.1*s,FLOOR+2.1*s,z-.4*s),{255,140,40},Mat.Neon)
end
-- Bushes and topiary.
function A.Bush(ctx,x,z,palette)
 local rng=K.Rng('bush'..x..z);local s=rng(.8,1.25);local g=pick(rng,palette or GREENS)
 ctx.Ball('core',x,z,'Bush',4.4*s,V(x,FLOOR+1.2*s,z),shade(g,rng),Mat.Grass)
 for i=1,math.floor(rng(1,2.99))do local a=rng(0,math.pi*2)
  ctx.Ball('detail',x,z,'Bush',rng(2.6,3.6)*s,V(x+math.cos(a)*2*s,FLOOR+.9*s,z+math.sin(a)*2*s),shade(g,rng,14),Mat.Grass)
 end
end
function A.Topiary(ctx,x,z,kind,potColor)
 local rng=K.Rng('topiary'..kind..x..z);local s=rng(.9,1.1);local g=pick(rng,DARK_GREENS)
 local pot=potColor or pick(rng,{{214,142,110},{236,220,190},{52,168,160}})
 ctx.VCyl('detail',x,z,'Topiary pot',2.6*s,FLOOR,FLOOR+1.8*s,x,z,pot,Mat.SmoothPlastic)
 ctx.VCyl('detail',x,z,'Topiary pot rim',3*s,FLOOR+1.8*s,FLOOR+2.2*s,x,z,P.Gold,Mat.SmoothPlastic)
 if kind=='cone'then
  local y=FLOOR+2.2*s
  for i,d in ipairs({2.8,2.1,1.4})do ctx.VCyl('detail',x,z,'Topiary cone',d*s,y,y+1.5*s,x,z,shade(g,rng,6),Mat.Grass);y+=1.5*s end
 else
  ctx.VCyl('detail',x,z,'Topiary stem',.35*s,FLOOR+2.2*s,FLOOR+4.6*s,x,z,P.WoodDark,Mat.Wood)
  ctx.Ball('detail',x,z,'Topiary ball',2.8*s,V(x,FLOOR+5.6*s,z),shade(g,rng,6),Mat.Grass)
 end
end

-- Flower beds: mixed colours and heights, a few tall flowers on stems.
function A.FlowerBed(ctx,x,z,r,set,top)
 local rng=K.Rng('bed'..x..z);top=top or FLOOR
 ctx.VCyl('core',x,z,'Bed rim',r*2+1,top-.1,top+1.1,x,z,P.Cream,Mat.SmoothPlastic)
 ctx.VCyl('core',x,z,'Bed soil',r*2,top+1.1,top+1.3,x,z,P.Soil,Mat.Ground)
 local n=math.max(4,math.floor(r*1.4));local pal=FLOWERS[set]or FLOWERS.warm
 for k=1,n do local a=k/n*math.pi*2+rng(0,.5);local rr=(k%2==0)and r*rng(.45,.7)or r*rng(.1,.3)
  local fx,fz=x+math.cos(a)*rr,z+math.sin(a)*rr;local h=rng(0,1)<.35 and rng(1.4,2.4)or rng(.5,.9)
  if h>1.2 then ctx.VCyl('fine',x,z,'Flower stem',.22,top+1.3,top+1.3+h,fx,fz,{70,150,70},Mat.Grass)end
  ctx.Ball('detail',x,z,'Flower',rng(1,1.6),V(fx,top+1.3+h,fz),pick(rng,pal),Mat.SmoothPlastic)
 end
end

-- Lamps: post / double / bollard variants; 'lit' ones carry a PointLight the client turns on in the dark.
function A.Lamp(ctx,x,z,kind,lit,yaw)
 local metal,trim=P.Metal,P.Gold
 if kind=='bollard'then
  ctx.VCyl('core',x,z,'Bollard',1.4,FLOOR,FLOOR+3.4,x,z,metal,Mat.Metal)
  local glow=ctx.Part('core',x,z,'Lamp lantern',V(1.3,1.2,1.3),CF(x,FLOOR+4,z),{255,222,150},Mat.Neon,{shadow=false})
  ctx.Part('core',x,z,'Lamp cap',V(1.9,.4,1.9),CF(x,FLOOR+4.8,z),metal,Mat.Metal)
  return glow
 end
 ctx.VCyl('core',x,z,'Lamp base',1.8,FLOOR,FLOOR+1.4,x,z,metal,Mat.Metal)
 ctx.VCyl('detail',x,z,'Lamp collar',1.2,FLOOR+1.4,FLOOR+2,x,z,trim,Mat.SmoothPlastic)
 ctx.VCyl('core',x,z,'Lamp pole',.7,FLOOR+1.4,FLOOR+12,x,z,metal,Mat.Metal)
 local glows={}
 local function lantern(c)
  glows[#glows+1]=ctx.Part('core',x,z,'Lamp lantern',V(1.6,2,1.6),c,{255,222,150},Mat.Neon,{shadow=false})
  ctx.Part('core',x,z,'Lamp cap',V(2.4,.5,2.4),c*CF(0,1.25,0),metal,Mat.Metal)
 end
 if kind=='double'then
  local turn=CFrame.Angles(0,yaw or 0,0)
  ctx.Part('core',x,z,'Lamp arm',V(5.4,.4,.4),CF(x,FLOOR+12.2,z)*turn,metal,Mat.Metal)
  for _,sx in ipairs({-1,1})do lantern(CF(x,FLOOR+11,z)*turn*CF(sx*2.5,0,0))end
 else lantern(CF(x,FLOOR+13,z))end
 if lit then for _,g in ipairs(glows)do
  local l=Instance.new('PointLight');l.Name='HubLampLight';l.Color=RGB(255,214,150);l.Range=22;l.Brightness=1.4;l.Shadows=false;l.Enabled=false;l.Parent=g
  table.insert(ctx.Lights,l);break
 end end
 return glows[1]
end
-- Benches: wood (slats + back), garden (curved back, painted), stone (slab on blocks).
function A.Bench(ctx,x,z,yaw,kind)
 local rng=K.Rng('bench'..x..z);local c=CF(x,FLOOR,z)*CFrame.Angles(0,yaw,0)
 if kind=='stone'then
  ctx.Part('core',x,z,'Bench slab',V(6.4,.7,2.2),c*CF(0,1.85,0),{214,204,186},Mat.Slate)
  for _,sx in ipairs({-1,1})do ctx.Part('core',x,z,'Bench block',V(1.4,1.5,1.8),c*CF(sx*2.3,.75,0),{178,166,147},Mat.Slate)end
  return
 end
 local wood=kind=='garden'and pick(rng,{{52,168,160},{230,96,84},{236,220,190}})or shade(P.Wood,rng,12)
 ctx.Part('core',x,z,'Bench seat',V(6,.5,2),c*CF(0,2,0),wood,Mat.WoodPlanks)
 ctx.Part('core',x,z,'Bench back',V(6,1.8,.4),c*CF(0,3.3,.9)*CFrame.Angles(math.rad(-10),0,0),wood,Mat.WoodPlanks)
 for _,sx in ipairs({-1,1})do ctx.Part('core',x,z,'Bench leg',V(.5,1.8,1.7),c*CF(sx*2.5,.9,.05),P.Metal,Mat.Metal)end
 if kind=='garden'then for _,sx in ipairs({-1,1})do ctx.Ball('detail',x,z,'Bench knob',.6,(c*CF(sx*3,4.2,1.05)).Position,P.Gold)end end
end
-- Signposts: wooden arrows or a stone pillar; the boards' texts are kept so the client can show the owners' names.
function A.Signpost(ctx,x,z,boards,kind)
 if kind=='stone'then
  ctx.Part('core',x,z,'Signpost pillar',V(1.6,13,1.6),CF(x,FLOOR+6.5,z),{214,204,186},Mat.Slate)
  ctx.Ball('core',x,z,'Signpost cap',2.2,V(x,FLOOR+13.6,z),P.Gold)
 else
  ctx.VCyl('core',x,z,'Signpost pole',.9,FLOOR,FLOOR+15,x,z,P.WoodDark,Mat.Wood)
  ctx.Ball('core',x,z,'Signpost cap',1.6,V(x,FLOOR+15.4,z),P.Gold)
 end
 for i,b in ipairs(boards)do
  local y=FLOOR+(kind=='stone'and 11.8 or 13.4)-(i-1)*2.4
  local cf=CF(x,y,z)*CFrame.Angles(0,b.Yaw,0)*CF(4.6,0,0)
  local board=ctx.Part('core',x,z,'Sign board',V(9,1.9,.4),cf,b.Color or P.Cream,Mat.SmoothPlastic)
  if board then
   ctx.Wedge('detail',x,z,'Sign tip',V(.4,1.9,1.2),K.Frame((cf*CF(5.1,0,0)).Position,cf.UpVector,-cf.RightVector),b.Color or P.Cream,Mat.SmoothPlastic)
   for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back})do
    local gui=K.Label(board,face,b.Text,{ink=b.Ink or{60,40,30},stroke={255,255,255},strokeT=.6,pps=24,maxDistance=220})
    if b.Owner then table.insert(ctx.Signs,{Line=gui.Line1,Base=b.Owner,Other=b.Other})end
   end
  end
 end
end
function A.Bunting(ctx,a,b,colours,spacing)
 local mid=(a+b)/2
 ctx.Rod('detail',mid.X,mid.Z,'Bunting line',a,b,.15,{250,250,250})
 local n=math.floor((b-a).Magnitude/(spacing or 5))
 local dir=(b-a).Unit;local side=V(0,1,0):Cross(dir).Unit
 for k=1,n-1 do local t=k/n;local p=a:Lerp(b,t)-V(0,math.sin(t*math.pi)*2.2,0)
  ctx.Wedge('detail',mid.X,mid.Z,'Pennant',V(.12,1.8,1.8),CFrame.fromMatrix(p,-side,V(0,1,0))*CFrame.Angles(math.rad(45),0,0),colours[(k-1)%#colours+1],Mat.Fabric,{shadow=false})
 end
end

-- The Seed Fountain: basin, rim, water, column, bowl, a jet holding up a giant seed pack, spouts with water arcs, ripple rings, sparkles.
function A.Fountain(ctx,x,z)
 local y=4.26;local F={}
 ctx.VCyl('core',x,z,'Fountain wall',22,y-.3,y+2.4,x,z,P.Plaster,Mat.Plaster)
 ctx.VCyl('core',x,z,'Fountain rim',23,y+2.4,y+2.9,x,z,P.Gold)
 ctx.VCyl('core',x,z,'Fountain water',20.4,y+2.9,y+3.0,x,z,P.Water,Mat.Glass,{t=.15})
 ctx.VCyl('core',x,z,'Fountain column',3.2,y+3.0,y+8.6,x,z,P.Pilaster,Mat.Plaster)
 ctx.VCyl('core',x,z,'Fountain bowl',10,y+8.6,y+10.2,x,z,P.Plaster,Mat.Plaster)
 ctx.VCyl('core',x,z,'Fountain bowl rim',10.8,y+10.2,y+10.6,x,z,P.Gold)
 ctx.VCyl('core',x,z,'Fountain bowl water',9.2,y+10.6,y+10.7,x,z,P.Water,Mat.Glass,{t=.15})
 F.Jet=ctx.VCyl('core',x,z,'Fountain jet',1.2,y+10.7,y+15.4,x,z,{200,236,255},Mat.Glass,{t=.35})
 F.JetBase=F.Jet and F.Jet.CFrame;F.JetSize=F.Jet and F.Jet.Size
 F.Center=V(x,y,z)
 for a=0,3 do local ang=a*math.pi/2+math.pi/4
  local sx,sz=x+math.cos(ang)*8.4,z+math.sin(ang)*8.4
  ctx.VCyl('detail',x,z,'Fountain spout',1.2,y+2.9,y+4.6,sx,sz,P.Gold)
  -- a water arc from the spout toward the column (two glass rods)
  local p0=V(sx,y+4.6,sz);local p2=V(x+math.cos(ang)*4,y+3.05,z+math.sin(ang)*4);local p1=(p0+p2)/2+V(0,1.6,0)
  ctx.Rod('detail',x,z,'Water arc',p0,p1,.45,{200,236,255},Mat.Glass,{t=.35});ctx.Rod('detail',x,z,'Water arc',p1,p2,.45,{200,236,255},Mat.Glass,{t=.35})
 end
 F.Ripples={}
 for i=1,2 do local r=ctx.VCyl('fine',x,z,'Ripple',12+i*3,y+3.0,y+3.06+i*.05,x,z,{230,248,255},Mat.Glass,{t=.55,shadow=false});if r then table.insert(F.Ripples,r)end end
 local packAt=CF(x,y+19,z)
 local ok,model=pcall(function()
  local m=require(RS:WaitForChild('SeedPackVisuals')).Bag(CFrame.new(),nil,1,nil,5,'Pack06',1,1,'None')
  for _,d in ipairs(m:GetDescendants())do
   if d:IsA('BasePart')then d.Anchored=true;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false
   elseif d:IsA('Script')or d:IsA('LocalScript')or d:IsA('Sound')or d:IsA('JointInstance')or d:IsA('WeldConstraint')then d:Destroy()end
  end
  local _,size=m:GetBoundingBox();local k=6.6/math.max(size.X,size.Y,size.Z,.1);m:ScaleTo(m:GetScale()*k)
  m.Name='Seed pack';m:PivotTo(packAt);m.Parent=ctx.Folder('core',x,z);return m
 end)
 if ok and model then F.Pack=model;F.PackBase=packAt
 else -- a part-built packet (the approved pack mesh is missing, e.g. in tests)
  local pk=ctx.Part('core',x,z,'Seed pack',V(5.2,6.6,1.8),packAt,{120,92,214},Mat.SmoothPlastic)
  if pk then
   ctx.Part('detail',x,z,'Seed pack seal',V(5.4,.6,2),packAt*CF(0,3.1,0),P.Gold,Mat.SmoothPlastic)
   K.Label(pk,Enum.NormalId.Front,{'🌱','SEED','PACK'},{weights={.4,.3,.3},ink={255,240,190},pps=24})
   K.Label(pk,Enum.NormalId.Back,{'🌱','SEED','PACK'},{weights={.4,.3,.3},ink={255,240,190},pps=24})
   F.Pack=pk;F.PackBase=packAt
  end
 end
 local host=ctx.Part('fine',x,z,'Sparkle source',V(4,.2,4),CF(x,y+15,z),{255,255,255},Mat.SmoothPlastic,{t=1,shadow=false})
 if host then
  local pe=Instance.new('ParticleEmitter');pe.Name='Fountain sparkles';pe.Rate=5;pe.Lifetime=NumberRange.new(1,1.8);pe.Speed=NumberRange.new(2,4)
  pe.Color=ColorSequence.new(RGB(220,244,255));pe.Size=NumberSequence.new(.3);pe.LightEmission=.6;pe.Enabled=false;pe.Parent=host
  table.insert(ctx.Emitters,pe)
 end
 ctx.Fountain=F
 return F
end

-- Grass patches (two heights, never overlapping at the same height), pebbles, butterflies, wall lanterns, base verges and pots.
function A.Patch(ctx,x,z,r,color,top)
 -- a soft blob: a disc and two smaller ones of the same colour at the same height (look-alike overlaps cannot flicker)
 local rng=K.Rng('patch'..x..z)
 local main=ctx.VCyl('core',x,z,'Grass patch',r*2,3.9,top,x,z,color,Mat.Grass,{shadow=false})
 for i=1,2 do local a=rng(0,math.pi*2);local rr=r*rng(.45,.7)
  ctx.VCyl('core',x,z,'Grass patch',rr*2,3.9,top,x+math.cos(a)*r*.75,z+math.sin(a)*r*.75,color,Mat.Grass,{shadow=false})
 end
 return main
end
function A.Pebbles(ctx,x,z,n,spread,seed)
 local rng=K.Rng('pebbles'..(seed or'')..x..z)
 for i=1,n do local px,pz=x+rng(-spread,spread),z+rng(-spread,spread);local d=rng(.6,1.5)
  ctx.Ball('detail',x,z,'Pebble',d,V(px,FLOOR+d*.1,pz),pick(rng,{{176,168,156},{150,144,134},{200,192,178},{132,124,116}}),Mat.Slate,{shadow=false})
 end
end
function A.Butterfly(ctx,x,y,z,color,seed)
 local l=ctx.Part('fine',x,z,'Butterfly wing',V(1.1,.06,.9),CF(x-.5,y,z),color,Mat.SmoothPlastic,{shadow=false})
 local r=ctx.Part('fine',x,z,'Butterfly wing',V(1.1,.06,.9),CF(x+.5,y,z),color,Mat.SmoothPlastic,{shadow=false})
 if l and r then table.insert(ctx.Butterflies,{Left=l,Right=r,Home=V(x,y,z),Phase=K.Rng('bf'..seed)()*6.28,Speed=.6+K.Rng('bfs'..seed)()*.5})end
end
function A.WallLantern(ctx,sec,s,top)
 local p=K.At(sec,s,top-24,3.4)
 ctx.Part('detail',p.X,p.Z,'Wall lantern bracket',V(.6,.6,1.8),K.SecFrame(sec,s,top-24+2.0,2.7),P.Metal,Mat.Metal)
 local l=ctx.Part('detail',p.X,p.Z,'Wall lantern',V(1.6,2.4,1.6),K.SecFrame(sec,s,top-24,3.4),{255,214,140},Mat.Neon,{shadow=false})
 ctx.Part('detail',p.X,p.Z,'Wall lantern cap',V(2.2,.5,2.2),K.SecFrame(sec,s,top-24+1.45,3.4),P.Metal,Mat.Metal)
 if l then table.insert(ctx.Lanterns,l)end
end
function A.Verge(ctx,b,i)
 local top=b.Frame*CF(0,b.Size.Y/2,0);local col=b.Color
 local cz=b.Size.Z/2+.3+.95;local cx=37.5;local p=(top*CF(cx,0,cz)).Position
 ctx.Part('core',p.X,p.Z,'Verge rim',V(29,1.0,1.9),top*CF(cx,-1+.5-.02,cz),P.Cream)
 ctx.Part('core',p.X,p.Z,'Verge soil',V(28,.2,1.5),top*CF(cx,-1+1.08,cz),P.Soil,Mat.Ground)
 local rng=K.Rng('verge'..i)
 for k=0,4 do local fx=cx-12+k*6;local h=rng(.5,1.3)
  ctx.Ball('detail',p.X,p.Z,'Verge flower',rng(1.1,1.5),(top*CF(fx,-1+1.18+h*.5,cz+rng(-.3,.3))).Position,({{col.R*255,col.G*255,col.B*255},{255,255,255},{255,214,80}})[k%3+1])
 end
end

-- The square's layout --------------------------------------------------------------------------------------------------------------------------
-- (positions avoid the streets, bases, run-up, market, Verity and the reserved corners: tests check every one with A.Clear; a 4th
-- topiary field true = a pot standing on the market square's paving by design)
A.Layout={
 trees={
  -- welcome lawns and the north islands
  {'blossom',28,-190,'pink'},{'blossom',-28,-190,'white'},{'oak',96,-184,'L'},{'oak',-96,-184,'L'},{'oak',94,-224,'M'},{'oak',-94,-224,'M'},
  {'fruit',60,-226,'apple'},{'fruit',-60,-226,'orange'},{'poplar',104,-200},{'poplar',104,-212},{'poplar',-104,-200},{'poplar',-104,-212},
  {'oak',134,-136,'M'},{'oak',-134,-136,'M'},{'blossom',100,-142,'lilac'},{'blossom',-100,-142,'pink'},{'oak',26,-222,'S'},{'oak',-26,-222,'S'},
  -- beside the market square
  {'fruit',84,-250,'lemon'},{'fruit',-84,-250,'apple'},{'oak',84,-300,'M'},{'oak',-84,-300,'L'},{'fruit',70,-276,'plum'},{'fruit',-70,-276,'lemon'},
  {'poplar',100,-262},{'poplar',-100,-262},
  -- round the stage and the fountain
  {'blossom',62,-330,'lilac'},{'blossom',-62,-330,'pink'},{'oak',92,-372,'L'},{'oak',-92,-372,'M'},{'oak',40,-392,'S'},{'oak',-40,-392,'S'},
  {'poplar',96,-340},{'poplar',-96,-340},{'fruit',72,-392,'apple'},{'fruit',-72,-392,'plum'},{'blossom',34,-366,'white'},{'blossom',-34,-360,'lilac'},
  -- Desert garden (+X alley): palms, saguaros, barrel cacti
  {'palm',170,-252},{'palm',262,-252},{'palm',220,-286},{'palm',300,-286},{'palm',196,-288},
  {'cactus',240,-252,'saguaro'},{'cactus',285,-251,'barrel'},{'cactus',182,-288,'barrel'},{'cactus',252,-287,'saguaro'},
  -- Lava garden (-X alley): ember trees and glowing rocks
  {'ember',-170,-252},{'ember',-220,-286},{'ember',-262,-252},{'ember',-300,-286},{'ember',-196,-251},
  {'rock',-195,-287},{'rock',-245,-252},{'rock',-285,-251},{'rock',-160,-288},
  -- Snow lane between Bases 5 and 6
  {'pine',-8.7,-440,.55},{'pine',8.7,-470,.55},{'pine',-8.7,-500,.55},{'pine',8.7,-530,.55},{'pine',-8.7,-560,.5},{'pine',8.7,-585,.5},
 },
 bushes={
  {84,-172},{-84,-172},{20,-196},{-20,-196},{137,-290},{-137,-290},{137,-248},{-137,-248},{100,-320},{-100,-320},{58,-374},{-58,-374},
  {230,-248,'desert'},{280,-288,'desert'},{-230,-249,'ember'},{-280,-289,'ember'},
 },
 beds={{60,-196,5.5,'warm'},{-60,-196,5.5,'cool'},{36,-250,3.5,'warm',4.2},{-36,-250,3.5,'cool',4.2},{36,-300,3.5,'cool',4.2},{-36,-300,3.5,'warm',4.2},
  {118,-159,4,'warm',4.26},{-118,-159,4,'cool',4.26},{118,-411,4,'cool',4.26},{-118,-411,4,'warm',4.26},{312,-269,4,'desert',4.26},{-312,-269,4,'lava',4.26},{0,-596,3.5,'snow',4.26}},
 topiary={{49,-236,'cone',true},{-49,-236,'cone',true},{49,-308,'ball',true},{-49,-308,'ball',true},{16,-170,'ball'},{-16,-170,'ball'},{322,-284,'cone'},{-322,-284,'cone'}},
 lamps={
  {106,-190,'post'},{106,-240,'post',true},{106,-290,'post'},{106,-340,'post',true},{106,-390,'post'},
  {-106,-190,'post'},{-106,-240,'post',true},{-106,-290,'post'},{-106,-340,'post',true},{-106,-390,'post'},
  {15.4,-200,'post',true},{-15.4,-200,'post',true},{15.4,-228,'post'},{-15.4,-228,'post'},
  {55,-236,'double',true,0},{-55,-236,'double',true,0},{55,-308,'double',false,0},{-55,-308,'double',false,0},
  {30,-400,'post'},{-30,-400,'post'},{140,-257,'post'},{-140,-257,'post'},
  {200,-279,'bollard'},{260,-259,'bollard'},{-200,-279,'bollard'},{-260,-259,'bollard'},
 },
 benches={{12.4,-379.6,'wood'},{-12.4,-379.6,'wood'},{12.4,-404.4,'stone'},{-12.4,-404.4,'stone'},
  {306,-258,0,'garden'},{306,-280,math.pi,'garden'},{-306,-258,0,'garden'},{-306,-280,math.pi,'garden'},
  {75,-200,math.pi/2,'wood'},{-75,-200,-math.pi/2,'wood'},{44,-275,math.pi/2,'garden'},{-44,-275,-math.pi/2,'garden'},{0,-588,math.pi,'stone'}},
 bunting={{{-15.4,17.4,-200},{15.4,17.4,-228},'rainbow'},{{15.4,17.4,-200},{-15.4,17.4,-228},'rainbow'},
  {{55,17.4,-236},{22,23,-250},'candy'},{{-55,17.4,-236},{-22,23,-250},'candy'},{{55,17.4,-308},{22,23,-287},'candy'},{{-55,17.4,-308},{-22,23,-287},'candy'}},
 patches={ -- x, z, r, shade (1 light, 2 deep, 3 sand, 4 ash), height layer (1 = 4.07, 2 = 4.12)
  {62,-205,16,1,1},{-62,-205,16,2,1},{78,-215,9,2,2},{-78,-195,9,1,2},{88,-282,13,1,1},{-88,-282,13,2,1},{82,-368,15,2,1},{-82,-368,15,1,1},
  {124,-134,9,1,1},{-124,-134,9,2,1},{232,-286,8,3,1},{276,-252,7,3,2},{-232,-286,8,4,1},{-276,-252,7,4,2},
 },
 butterflies={{60,8,-196},{-60,9,-198},{36,7,-252},{-36,8,-300},{118,8,-161},{-118,7,-409},{8,9,-380},{20,10,-372},{312,8,-266},{-312,8,-272},{0,7,-592},{90,9,-240}},
}
A.LayoutFns={}
local PATCH_COLOURS={{112,198,98},{70,150,74},{226,206,150},{90,78,80}}

-- Build everything for a device tier (1..3). bases: {[i]={Frame=CFrame, Size=Vector3, Color=Color3}}; owners(i) -> name or nil.
function A.Build(root,tier,bases,owners)
 local ctx=context(root,tier)
 ctx.Bases=bases
 local L=A.Layout
 for _,t in ipairs(L.trees)do
  local kind,x,z=t[1],t[2],t[3]
  if kind=='oak'then A.Oak(ctx,x,z,t[4])elseif kind=='poplar'then A.Poplar(ctx,x,z)elseif kind=='blossom'then A.Blossom(ctx,x,z,t[4])
  elseif kind=='fruit'then A.FruitTree(ctx,x,z,t[4])elseif kind=='pine'then A.Pine(ctx,x,z,t[4])elseif kind=='palm'then A.Palm(ctx,x,z)
  elseif kind=='cactus'then A.Cactus(ctx,x,z,t[4])elseif kind=='ember'then A.EmberTree(ctx,x,z)elseif kind=='rock'then A.GlowRock(ctx,x,z)end
 end
 for _,b in ipairs(L.bushes)do A.Bush(ctx,b[1],b[2],b[3]=='desert'and{{150,170,80},{170,176,96}}or b[3]=='ember'and{{120,50,40},{150,70,40}}or nil)end
 for _,b in ipairs(L.beds)do A.FlowerBed(ctx,b[1],b[2],b[3],b[4],b[5])end
 for _,t in ipairs(L.topiary)do A.Topiary(ctx,t[1],t[2],t[3])end
 for _,l in ipairs(L.lamps)do A.Lamp(ctx,l[1],l[2],l[3],l[4],l[5])end
 for _,b in ipairs(L.benches)do
  if #b==3 then -- around the fountain: face its middle
   local yaw=math.atan2(-b[1],-(b[2]+392));A.Bench(ctx,b[1],b[2],yaw+math.pi,b[3])
  else A.Bench(ctx,b[1],b[2],b[3],b[4])end
 end
 for _,b in ipairs(L.bunting)do A.Bunting(ctx,V(b[1][1],b[1][2],b[1][3]),V(b[2][1],b[2][2],b[2][3]),BUNTING[b[3]])end
 for _,p in ipairs(L.patches)do A.Patch(ctx,p[1],p[2],p[3],PATCH_COLOURS[p[4]],p[5]==1 and 4.07 or 4.12)end
 -- pebbles along the outer edges of the side streets and the garden walks
 for _,sx in ipairs({-1,1})do
  for _,z in ipairs({-222,-320,-386})do A.Pebbles(ctx,sx*131,z,3,1.6,'s')end
  for _,x in ipairs({160,215,250,290})do A.Pebbles(ctx,sx*x,-279.5,2,1.2,'g');A.Pebbles(ctx,sx*(x+12),-258.5,2,1.2,'g')end
 end
 -- signposts (the base boards show the owners' names, kept fresh by the client)
 local function own(i)return(owners and owners(i))or('Base '..i)end
 A.Signpost(ctx,19,-171,{{Yaw=math.rad(-90),Text='THE TRACK',Color={255,236,180}},{Yaw=math.rad(90),Text='MARKET',Color={190,236,226}},
  {Yaw=math.pi,Text=own(1)..' · '..own(3),Color={255,214,214},Owner=1,Other=3},{Yaw=0,Text=own(2)..' · '..own(4),Color={214,226,255},Owner=2,Other=4}},'wood')
 A.Signpost(ctx,-34,-372,{{Yaw=math.rad(-90),Text='THE TRACK',Color={255,236,180}},{Yaw=math.rad(90),Text='SEED FOUNTAIN',Color={200,236,255}},
  {Yaw=math.pi,Text=own(5),Color={214,255,226},Owner=5},{Yaw=0,Text=own(6),Color={255,226,200},Owner=6}},'stone')
 A.Fountain(ctx,0,-392)
 for i,b in pairs(bases or{})do
  A.Verge(ctx,b,i)
  -- potted topiary either side of the spur's street end
  local top=b.Frame*CF(0,b.Size.Y/2,0);local look=top.LookVector*-1
  if math.abs(look.X)>.5 then
   local x=(top.Position.X>0 and 1 or-1)*131;for _,dz in ipairs({-18.2,18.2})do A.Topiary(ctx,x,top.Position.Z+dz,'ball',{b.Color.R*255,b.Color.G*255,b.Color.B*255})end
  else
   for _,dx in ipairs({-18.4,18.4})do A.Topiary(ctx,top.Position.X+dx,-420.4,'cone',{b.Color.R*255,b.Color.G*255,b.Color.B*255})end
  end
 end
 for _,m in ipairs(K.Murals)do local sec=K.Sections[m.Sec];local s=K.SOf(sec,m.W)
  for _,ds in ipairs({-28.5,28.5})do A.WallLantern(ctx,sec,s+ds,K.WallTop)end
 end
 local wings={{255,140,60},{255,230,90},{120,200,255},{240,130,230},{255,255,255}}
 for k,p in ipairs(L.butterflies)do A.Butterfly(ctx,p[1],p[2],p[3],wings[(k-1)%#wings+1],k)end
 for _,cell in pairs(ctx.Cells)do cell.Center=cell.N>0 and cell.Sum/cell.N or V(0,0,0)end
 return ctx
end
return A
