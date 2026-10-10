-- R151 Seed Festival Square, client half ("life"): trees, bushes, topiary, flower beds, verges, lamps, benches, bunting,
-- wall lanterns, grass patches, pebbles and butterflies, built on each player's screen by HubLife151.client. (R152: no Seed Fountain, no
-- signposts, a third of the trees: the square's plaza at the south end is an open space.)
-- Owner (approving the design): "polish the trees, give them more variety and the stuff and everything". So every prop comes in species /
-- variants, and each instance gets its own deterministic variation (scale, lean, turn, colour shade, canopy layering) from a seed made of
-- its kind and position: every client builds the same square, and no two trees look cloned.
-- Owner (R151, later): "make sure they are studded" - the trees, bushes and topiary are studded Plastic blocks, and the owner's studded tree
-- models (ReplicatedStorage.HubTreeTemplates151) take the leafy slots when they are there (HubStudTrees151).
-- Detail levels (A.Build puts every part in a per-cell Folder of its level, the client shows / hides those Folders by distance):
--   core    silhouettes seen from anywhere: trunks and main crowns, lamps, benches, grass patches
--   detail  within ~230 studs and device tier >= 2: extra crown layers, flowers, pots, pebbles, bunting, wall lanterns
--   fine    within ~130 studs and tier 3: butterflies, blossom petals, small extras
-- Nothing here collides or can be touched / queried; nothing stands on a street, a base, the run-up, the market, Verity or the reserved
-- back corners (R151 displays) - A.Clear(x, z, r) checks it.
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'))
local Trees=require(RS:WaitForChild('HubStudTrees151'))
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
-- Owner (R151): "remove the apples or red stuff on the trees the trees are just trees" - no fruit, berries, coconuts, flowers or glowing bits
-- on any tree; the former fruit-tree slots are plain leafy trees in four green tones.
local LEAFY={fresh={{120,196,92},{132,204,98},{110,188,86}},deep={{62,138,64},{70,146,70},{56,128,60}},lime={{150,204,84},{162,212,94},{140,196,78}},
 sage={{110,158,96},{120,168,104},{100,148,90}}}
local BARKS={{150,104,64},{132,92,58},{164,116,72},{120,86,56}}
local EMBERS={{214,150,60},{232,176,72},{200,140,56},{240,196,96}} -- (autumn amber and gold: no red on any tree)
local FLOWERS={warm={{255,96,120},{255,214,80},{255,255,255},{255,150,60},{255,120,170}},cool={{170,120,255},{120,200,255},{255,255,255},{255,170,220},{140,220,200}},
 desert={{255,200,90},{255,120,60},{255,255,255},{240,90,120}},lava={{255,90,40},{255,170,40},{150,30,30},{255,220,90}},snow={{200,230,255},{255,255,255},{150,190,255}}}
local BUNTING={rainbow={{255,96,96},{255,206,72},{96,200,120},{90,170,255},{190,120,255}},candy={{236,104,92},{252,244,226},{52,168,160},{244,196,86}}}
A.Palettes={Greens=GREENS,Blossoms=BLOSSOMS,Leafy=LEAFY,Flowers=FLOWERS,Embers=EMBERS}

-- Where props may stand -------------------------------------------------------------------------------------------------------------------------
local BLOCKED={ -- (x0, x1, z0, z1): the market, the leaderboards, the gate towers' feet
 {-30,30,-296,-244},{-131,-101,-121,-105},{101,131,-121,-105},{-110,-88,-110,-92},{88,110,-110,-92},
}
function A.Clear(x,z,r,bases,allowPaving)
 r=r or 0
 if math.abs(x)>333-r or z>-106+r or z<-616+r then return false,'wall'end
 if K.InReserved(x,z,r)then return false,'reserved'end
 for _,o in ipairs(K.Open)do if(x-o[1])^2+(z-o[2])^2<(o[3]+r)^2 then return false,'open'end end -- (R152: the free Void Pack pedestal's plaza)
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
 local ctx={Root=root,Tier=tier,Cells={},Counts={core=0,detail=0,fine=0},Lights={},LightAt={},Heads={},Emitters={},Butterflies={},Lanterns={},Templated={},TemplateParts=0}
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
-- Owner (R151): "make sure they are studded". Every part-built tree, bush and topiary is made of Plastic blocks with Studs on top and Inlet
-- underneath - the classic Roblox look of the place's own track trees (Plastic blocks with Studs) and of the owner's studded tree models.
-- Stud surfaces show on block faces, so crowns are clusters of turned blocks. Each block of a tree keeps its top and bottom off the planes of
-- the tree's other blocks (freeY: coplanar faces would flicker). The owner's tree models replace the leafy trees (oaks, blossoms, leafy
-- trees) when ReplicatedStorage.HubTreeTemplates151 has them (A.TemplateTree, HubStudTrees151).
local function block(ctx,level,x,z,name,size,cf,color)return ctx.Part(level,x,z,name,size,cf,color,Mat.Plastic,{studs=true})end
local function turned(pos,yaw)return CF(pos)*CFrame.Angles(0,yaw,0)end
-- y for a block of height h whose top / bottom stay .09 off every plane already used by this tree (bottoms under the floor are hidden).
local function freeY(pl,y,h)
 for _=1,40 do
  local clash=false
  for _,p in ipairs(pl)do if math.abs(y+h/2-p)<.09 or(y-h/2>FLOOR-.02 and math.abs(y-h/2-p)<.09)then clash=true;break end end
  if not clash then break end
  y+=.13
 end
 pl[#pl+1]=y+h/2;if y-h/2>FLOOR-.02 then pl[#pl+1]=y-h/2 end
 return y
end
-- A crown block (square, its own turn); returns the part (nil when the level is not built here) and its CFrame.
local function crown(ctx,pl,x,z,level,name,w,h,pos,yaw,color)
 local cf=turned(V(pos.X,freeY(pl,pos.Y,h),pos.Z),yaw)
 return block(ctx,level,x,z,name,V(w,h,w),cf,color),cf
end
-- A square beam between two points (palm trunks, cactus arms, branches), a little longer so the joints overlap.
local function beam(ctx,level,x,z,name,a,b,d,color)
 local mid=(a+b)/2
 return block(ctx,level,x,z,name,V(d,d,(b-a).Magnitude+.6),CFrame.lookAt(mid,b),color)
end
-- A leaning square trunk: returns the CFrame at its top so crowns follow the lean.
local function trunk(ctx,x,z,rng,d,h,color,level)
 local lean=CFrame.Angles(math.rad(rng(-6,6)),rng(0,math.pi*2),math.rad(rng(-6,6)))
 local base=CF(x,FLOOR,z)*lean
 block(ctx,level or'core',x,z,'Tree trunk',V(d*.85,h+.3,d*.85),base*CF(0,h/2-.15,0),color)
 return base*CF(0,h,0)
end
local function yawOf(rng)return rng(0,math.pi/2)end
local function petals(ctx,x,z,at,w,pal)
 local host=ctx.Part('fine',x,z,'Petal source',V(w,.2,w),CF(at),{255,255,255},Mat.SmoothPlastic,{t=1,shadow=false})
 if host then
  local pe=Instance.new('ParticleEmitter');pe.Name='Falling petals';pe.Rate=1.5;pe.Lifetime=NumberRange.new(5,7);pe.Speed=NumberRange.new(.3,.8)
  pe.Acceleration=V(0,-.5,0);pe.Color=ColorSequence.new(K.C(pal[1]));pe.Size=NumberSequence.new(.35);pe.LightEmission=.1;pe.Rotation=NumberRange.new(0,360);pe.RotSpeed=NumberRange.new(-60,60)
  pe.Enabled=false;pe.Parent=host;table.insert(ctx.Emitters,pe)
 end
end
-- Round oak: S / M / L, a big crown block with 2-4 side blocks and a top block in neighbouring greens, a root flare.
function A.Oak(ctx,x,z,size)
 local rng=K.Rng('oak'..size..x..z);local s=({S=.75,M=1,L=1.3})[size]*rng(.9,1.12);local pl={}
 local g=pick(rng,GREENS);local top=trunk(ctx,x,z,rng,1.9*s,8.5*s,pick(rng,BARKS))
 block(ctx,'detail',x,z,'Root flare',V(2.8*s,1.2*s,2.8*s),turned(V(x,FLOOR-.25+.6*s,z),yawOf(rng)),P.WoodDark)
 crown(ctx,pl,x,z,'core','Tree crown',9*s,6.4*s,(top*CF(0,3.2*s,0)).Position,yawOf(rng),shade(g,rng))
 local n=math.floor(rng(2,4.99))
 for i=1,n do local a=i/n*math.pi*2+rng(0,1)
  crown(ctx,pl,x,z,'detail','Tree crown',rng(5.2,7)*s,rng(3.6,4.8)*s,(top*CF(math.cos(a)*4.2*s,rng(1,4.4)*s,math.sin(a)*4.2*s)).Position,yawOf(rng),shade(pick(rng,GREENS),rng))
 end
 crown(ctx,pl,x,z,'detail','Tree crown top',rng(4.8,6.2)*s,rng(3,3.8)*s,(top*CF(rng(-1.5,1.5)*s,7*s,rng(-1.5,1.5)*s)).Position,yawOf(rng),shade(g,rng,16))
end
-- Tall poplar / cypress: a slim trunk and a column of tapering blocks, each turned 45 degrees from the one below.
function A.Poplar(ctx,x,z)
 local rng=K.Rng('poplar'..x..z);local s=rng(.85,1.15);local g=pick(rng,DARK_GREENS);local pl={}
 local top=trunk(ctx,x,z,rng,1.1*s,3.5*s,pick(rng,BARKS))
 local ds={6.4,5.8,5,4,2.8};local y=1.8*s;local yaw=yawOf(rng)
 for i,d in ipairs(ds)do local h=d*.72*s
  crown(ctx,pl,x,z,i<=2 and'core'or'detail','Poplar crown',d*.84*s,h,(top*CF(0,y,0)).Position,yaw+i*math.pi/4,shade(g,rng,8))
  y+=h*.8
 end
end
-- Blossom trees in pink / white / lilac with a green leaf tuft and falling petals.
function A.Blossom(ctx,x,z,colour)
 local rng=K.Rng('blossom'..colour..x..z);local s=rng(.85,1.1);local pal=BLOSSOMS[colour];local pl={}
 local top=trunk(ctx,x,z,rng,1.6*s,8*s,{110,78,60})
 local main=crown(ctx,pl,x,z,'core','Blossom crown',8.8*s,6*s,(top*CF(0,3*s,0)).Position,yawOf(rng),shade(pick(rng,pal),rng,6))
 for i=1,3 do local a=i*2.1+rng(0,1)
  crown(ctx,pl,x,z,'detail','Blossom crown',rng(4.8,6.4)*s,rng(3.2,4.2)*s,(top*CF(math.cos(a)*4*s,rng(1.5,4.5)*s,math.sin(a)*4*s)).Position,yawOf(rng),shade(pick(rng,pal),rng,6))
 end
 crown(ctx,pl,x,z,'detail','Leaf tuft',3.2*s,2.2*s,(top*CF(rng(-3,3)*s,-.4*s,rng(-3,3)*s)).Position,yawOf(rng),pick(rng,GREENS))
 petals(ctx,x,z,(top*CF(0,1.5*s,0)).Position,6*s,pal)
 return main
end
-- Leafy trees (the former fruit-tree slots; owner: "the trees are just trees"): a crown block, a top block and a side block in one of four
-- green tones (fresh, deep, lime, sage). Just leaves.
function A.LeafyTree(ctx,x,z,tone)
 local rng=K.Rng('leafy'..tostring(tone)..x..z);local s=rng(.8,1);local pl={};local pal=LEAFY[tone]or LEAFY.fresh
 local top=trunk(ctx,x,z,rng,1.6*s,6.5*s,pick(rng,BARKS))
 local w,h=8.4*s,6.6*s
 local _,cf=crown(ctx,pl,x,z,'core','Tree crown',w,h,(top*CF(0,3*s,0)).Position,yawOf(rng),shade(pick(rng,pal),rng,8))
 crown(ctx,pl,x,z,'detail','Tree crown',5.2*s,3.2*s,cf.Position+V(rng(-1.5,1.5)*s,h/2+1.1*s,rng(-1.5,1.5)*s),yawOf(rng),shade(pick(rng,pal),rng,8))
 local a=rng(0,math.pi*2)
 crown(ctx,pl,x,z,'detail','Tree crown',rng(4,5)*s,rng(2.8,3.6)*s,cf.Position+V(math.cos(a)*3.8*s,rng(-1,.6)*s,math.sin(a)*3.8*s),yawOf(rng),shade(pick(rng,pal),rng,10))
end
-- Pines for the Snow lane: 3-4 square tiers, each turned 45 degrees, snow on their tops.
function A.Pine(ctx,x,z,s)
 local rng=K.Rng('pine'..x..z);s=(s or 1)*rng(.85,1.15);local g=pick(rng,DARK_GREENS);local pl={}
 local yaw=yawOf(rng)
 block(ctx,'core',x,z,'Pine trunk',V(1.2*s,3.6*s+.3,1.2*s),turned(V(x,FLOOR-.3+(3.6*s+.3)/2,z),yaw),P.WoodDark)
 local tiers=rng()<.5 and 3 or 4;local y=FLOOR+3*s
 for i=1,tiers do local d=(9.4-i*(tiers==3 and 2 or 1.6))*s*.84;local h=3*s;local ty=yaw+i*math.pi/4
  local cy=freeY(pl,y+h/2,h)
  block(ctx,i<=2 and'core'or'detail',x,z,'Pine tier',V(d,h,d),turned(V(x,cy,z),ty),shade(g,rng,6))
  if i>1 then -- snow on the tier's top (its underside just inside the tier)
   block(ctx,'detail',x,z,'Snow rim',V(d*.82,.34,d*.82),turned(V(x,cy+h/2+.13,z),ty),{246,250,255})
   pl[#pl+1]=cy+h/2+.3
  end
  y+=h*.8
 end
 local sy=freeY(pl,y+1.2*s,2*s)
 block(ctx,'detail',x,z,'Pine snow',V(1.9*s,2*s,1.9*s),turned(V(x,sy,z),yaw),{246,250,255})
end
-- Palms for the Desert garden: a curving trunk of square segments, drooping leaves (no coconuts: "the trees are just trees").
function A.Palm(ctx,x,z)
 local rng=K.Rng('palm'..x..z);local s=rng(.85,1.15);local a=rng(0,math.pi*2)
 local lean=V(math.cos(a),0,math.sin(a))*rng(.8,1.5)*s;local base=V(x,FLOOR-.3,z);local prev=base
 for k=1,3 do local nxt=base+lean*(k*k*.45)+V(0,k*4.3*s,0)
  beam(ctx,'core',x,z,'Palm trunk',prev,nxt,(1.4-k*.15)*s,{150,112,72});prev=nxt
 end
 local crownAt=prev;local n=math.floor(rng(6,8.99))
 for i=1,n do local ang=i/n*math.pi*2+rng(0,.4);local reach=rng(5.5,7)*s
  local tip=crownAt+V(math.cos(ang)*reach,-rng(2,3.4)*s,math.sin(ang)*reach)
  ctx.Part(i<=4 and'core'or'detail',x,z,'Palm leaf',V(reach+1,.35,rng(1.7,2.3)*s),CFrame.lookAt((crownAt+tip)/2,tip)*CFrame.Angles(0,math.pi/2,0),shade({60,150,72},rng,14),Mat.Plastic,{studs=true})
 end
end
-- Cacti: a saguaro with one or two arms, or a barrel cactus (plain: no flower balls on top).
function A.Cactus(ctx,x,z,kind)
 local rng=K.Rng('cactus'..kind..x..z);local s=rng(.85,1.2);local g=shade({86,160,74},rng,12);local yaw=yawOf(rng);local pl={}
 if kind=='barrel'then
  block(ctx,'core',x,z,'Barrel cactus',V(3*s,2.6*s,3*s),turned(V(x,FLOOR-.2+1.3*s,z),yaw),g)
  return
 end
 local h=rng(6,8.5)*s
 block(ctx,'core',x,z,'Cactus',V(2*s,h+.2,2*s),turned(V(x,FLOOR-.2+(h+.2)/2,z),yaw),g);pl[#pl+1]=FLOOR+h
 local cy=freeY(pl,FLOOR+h+.3*s,1.2*s)
 block(ctx,'core',x,z,'Cactus top',V(1.5*s,1.2*s,1.5*s),turned(V(x,cy,z),yaw+math.pi/4),g)
 local arms=rng()<.5 and 1 or 2;local a=rng(0,math.pi*2)
 for i=1,arms do local ang=a+(i-1)*math.pi;local dx,dz=math.cos(ang)*1.9*s,math.sin(ang)*1.9*s
  local y0=freeY(pl,FLOOR+rng(2.4,3.6)*s,1.2*s)
  beam(ctx,'detail',x,z,'Cactus arm',V(x,y0,z),V(x+dx,y0,z+dz),1.2*s,g)
  local ah=rng(2,3.2)*s;local ay=freeY(pl,y0-.4*s+ah/2,ah)
  block(ctx,'detail',x,z,'Cactus arm',V(1.3*s,ah,1.3*s),turned(V(x+dx,ay,z+dz),ang),g)
 end
end
-- Ember trees for the Lava garden: charred leaning trunks, autumn amber / gold crown blocks (no glowing bits, no red: "the trees are just
-- trees"). The garden's glow stays on its basalt rocks.
function A.EmberTree(ctx,x,z)
 local rng=K.Rng('ember'..x..z);local s=rng(.8,1.1);local pl={}
 local top=trunk(ctx,x,z,rng,1.8*s,8*s,{58,44,44})
 local _,cf=crown(ctx,pl,x,z,'core','Ember crown',8*s,6*s,(top*CF(0,2.6*s,0)).Position,yawOf(rng),pick(rng,EMBERS))
 local c=cf.Position
 for i=1,2 do local a=i*2.6+rng(0,1)
  crown(ctx,pl,x,z,'detail','Ember crown',rng(4.4,6)*s,rng(3,4)*s,c+V(math.cos(a)*3.6*s,rng(.5,3)*s,math.sin(a)*3.6*s),yawOf(rng),pick(rng,EMBERS))
 end
 beam(ctx,'detail',x,z,'Charred branch',(top*CF(0,-2*s,0)).Position,(top*CF(4*s,1*s,1*s)).Position,.7*s,{58,44,44})
end
function A.GlowRock(ctx,x,z)
 local rng=K.Rng('rock'..x..z);local s=rng(.8,1.3)
 ctx.Ball('core',x,z,'Basalt rock',4*s,V(x,FLOOR+.8*s,z),shade({66,56,66},rng,8),Mat.Basalt)
 ctx.Ball('detail',x,z,'Basalt rock',2.4*s,V(x+2.2*s,FLOOR+.3*s,z+.8*s),shade({76,62,70},rng,8),Mat.Basalt)
 ctx.Ball('detail',x,z,'Ember glow',1.5*s,V(x+1.1*s,FLOOR+2.1*s,z-.4*s),{255,140,40},Mat.Neon)
end
-- The owner's studded tree model in a leafy slot (HubStudTrees151.Place: fitted, turned, leaned, grounded, leaves in the slot's colour; any
-- fruit in the model was removed by HubStudTrees151.Prepare); blossoms keep their petals. nil when the clone cannot be placed.
function A.TemplateTree(ctx,x,z,kind,variant,info)
 local f=ctx.Folder('core',x,z);if not f then return nil end
 local rng=K.Rng('leaf'..kind..tostring(variant)..x..z)
 local leaf=kind=='blossom'and shade(pick(rng,BLOSSOMS[variant]or BLOSSOMS.pink),rng,6)or kind=='leafy'and shade(pick(rng,LEAFY[variant]or LEAFY.fresh),rng,8)or shade(pick(rng,GREENS),rng)
 local m=Trees.Place(info,{Kind=kind,Variant=variant,X=x,Z=z},{Floor=FLOOR,Leaf=leaf,Shadows=ctx.Tier>=2})
 if not m then return nil end
 m.Name='Studded tree';m:SetAttribute('Template',info.Name);m.Parent=f
 ctx.Counts.core+=info.Parts;ctx.Templated[kind]=(ctx.Templated[kind]or 0)+1;ctx.TemplateParts+=info.Parts
 local c,size=Trees.LeafBox(m)
 if kind=='blossom'and c then petals(ctx,x,z,c+V(0,-size.Y*.2,0),math.min(size.X,size.Z)*.6,BLOSSOMS[variant]or BLOSSOMS.pink)end
 return m
end
-- Bushes and topiary (studded blocks too).
function A.Bush(ctx,x,z,palette)
 local rng=K.Rng('bush'..x..z);local s=rng(.8,1.25);local g=pick(rng,palette or GREENS);local pl={}
 crown(ctx,pl,x,z,'core','Bush',4*s,2.6*s,V(x,FLOOR-.2+1.3*s,z),yawOf(rng),shade(g,rng))
 for i=1,math.floor(rng(1,2.99))do local a=rng(0,math.pi*2);local h=rng(1.6,2.2)*s
  crown(ctx,pl,x,z,'detail','Bush',rng(2.4,3.2)*s,h,V(x+math.cos(a)*2*s,FLOOR-.2+h/2,z+math.sin(a)*2*s),yawOf(rng),shade(g,rng,14))
 end
end
function A.Topiary(ctx,x,z,kind,potColor)
 local rng=K.Rng('topiary'..kind..x..z);local s=rng(.9,1.1);local g=pick(rng,DARK_GREENS);local yaw=yawOf(rng)
 local pot=potColor or pick(rng,{{214,142,110},{236,220,190},{52,168,160}})
 ctx.VCyl('detail',x,z,'Topiary pot',2.6*s,FLOOR,FLOOR+1.8*s,x,z,pot,Mat.SmoothPlastic)
 ctx.VCyl('detail',x,z,'Topiary pot rim',3*s,FLOOR+1.8*s,FLOOR+2.2*s,x,z,P.Gold,Mat.SmoothPlastic)
 if kind=='cone'then
  local y=FLOOR+2.2*s
  for i,d in ipairs({2.5,1.9,1.25})do block(ctx,'detail',x,z,'Topiary cone',V(d*s,1.5*s,d*s),turned(V(x,y+.75*s,z),yaw+i*math.pi/4),shade(g,rng,6));y+=1.5*s end
 else
  block(ctx,'detail',x,z,'Topiary stem',V(.4*s,2.6*s,.4*s),turned(V(x,FLOOR+3.3*s,z),yaw),P.WoodDark)
  block(ctx,'detail',x,z,'Topiary ball',V(2.4*s,2.4*s,2.4*s),turned(V(x,FLOOR+5.6*s,z),yaw+math.pi/4),shade(g,rng,6))
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
-- R151 Cloudy (WeatherCycle151): every lamp head (ctx.Heads: all 30 neon lanterns, at every device tier) and every wall lantern (ctx.Lanterns) warms its colour
-- with the sky; the lit lamps' real lights (ctx.Lights, in priority order, see A.OrderLights) switch on for it within the tier's cap.
-- R154 (owner, with the tidy's fewer lamps: "make each lamp brighter in its warmth"): a lit lamp's real light, before and after (it was Range 22, Brightness 1.4). HubLife151.client
-- takes it further under Cloudy and in the dark (WeatherCycle151.Lamps.Boost: x1.5 brightness and x1.3 range at full glow, the colour warming toward amber).
A.LampLight={Range=28,Brightness=1.8}
function A.Lamp(ctx,x,z,kind,lit,yaw)
 local metal,trim=P.Metal,P.Gold
 if kind=='bollard'then
  ctx.VCyl('core',x,z,'Bollard',1.4,FLOOR,FLOOR+3.4,x,z,metal,Mat.Metal)
  local glow=ctx.Part('core',x,z,'Lamp lantern',V(1.3,1.2,1.3),CF(x,FLOOR+4,z),{255,222,150},Mat.Neon,{shadow=false})
  ctx.Part('core',x,z,'Lamp cap',V(1.9,.4,1.9),CF(x,FLOOR+4.8,z),metal,Mat.Metal)
  if glow then table.insert(ctx.Heads,glow)end
  return glow
 end
 ctx.VCyl('core',x,z,'Lamp base',1.8,FLOOR,FLOOR+1.4,x,z,metal,Mat.Metal)
 ctx.VCyl('detail',x,z,'Lamp collar',1.2,FLOOR+1.4,FLOOR+2,x,z,trim,Mat.SmoothPlastic)
 ctx.VCyl('core',x,z,'Lamp pole',.7,FLOOR+1.4,FLOOR+12,x,z,metal,Mat.Metal)
 local glows={}
 local function lantern(c)
  local head=ctx.Part('core',x,z,'Lamp lantern',V(1.6,2,1.6),c,{255,222,150},Mat.Neon,{shadow=false})
  glows[#glows+1]=head;if head then table.insert(ctx.Heads,head)end
  ctx.Part('core',x,z,'Lamp cap',V(2.4,.5,2.4),c*CF(0,1.25,0),metal,Mat.Metal)
 end
 if kind=='double'then
  local turn=CFrame.Angles(0,yaw or 0,0)
  ctx.Part('core',x,z,'Lamp arm',V(5.4,.4,.4),CF(x,FLOOR+12.15,z)*turn,metal,Mat.Metal) -- (R154: .05 under the caps' bottoms, was flush: textured metal flickered)
  for _,sx in ipairs({-1,1})do lantern(CF(x,FLOOR+11,z)*turn*CF(sx*2.5,0,0))end
 else lantern(CF(x,FLOOR+13,z))end
 if lit then for _,g in ipairs(glows)do
  local l=Instance.new('PointLight');l.Name='HubLampLight';l.Color=RGB(255,214,150);l.Range=A.LampLight.Range;l.Brightness=A.LampLight.Brightness;l.Shadows=false;l.Enabled=false;l.Parent=g
  table.insert(ctx.Lights,l);ctx.LightAt[l]={x,z};break
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
-- Bunting. R158 (owner: "fix the disconnect flags": the pennants floated beside and under a straight white string): the string hangs in a SAG, the curve
-- a:Lerp(b,t) - (0, sin(t * pi) * BuntingSag, 0), drawn as n + 1 straight rod pieces (n = one pennant every ~5 studs) whose ends sit ON that curve, so the string
-- really follows the sag and its pieces meet end to end (each overlaps the next by BuntingOverlap: a bend of a few degrees leaves no sliver on its outside). The
-- joints are half a spacing off the pennants: pennant k (k = 1 .. n - 1, at t = k / n) hangs from the MIDDLE of the straight piece k + 1, so its top edge lies on the
-- rod's axis (the 0.12 plate is hidden inside the 0.15 rod there: no gap, no coplanar face) and its two sides never cross a bend. A pennant is a right
-- isosceles triangle (a WedgePart, .12 thick): the top edge (the hypotenuse, PennantWidth long) lies along the string's direction at that piece, the point hangs
-- PennantWidth / 2 straight DOWN under the middle of the edge (a right angle: the corner of a right triangle on its hypotenuse's circle), in the vertical plane
-- of the string, so it faces along the string and reads as a triangle from either side. Parts, per string: n + 1 rod pieces + n - 1 pennants (the same colours).
A.BuntingSag=2.2;A.BuntingLine=.15;A.BuntingOverlap=.06;A.PennantWidth=2.55;A.PennantThick=.12
function A.BuntingCurve(a,b,t)return a:Lerp(b,t)-V(0,math.sin(t*math.pi)*A.BuntingSag,0)end
-- The plan of one string (pure): Points = the rod pieces' ends in order (Points[1] = a, Points[#Points] = b, the rest on the sag curve), Pennants = for each
-- pennant its Index (the colour slot), Mid (on the string), and the triangle's three corners: Left / Right (the ends of the top edge) and Tip (the point, below Mid).
function A.BuntingPlan(a,b,spacing)
 local n=math.floor((b-a).Magnitude/(spacing or 5))
 local pts={a}
 for j=1,n do pts[#pts+1]=A.BuntingCurve(a,b,(j-.5)/n)end
 pts[#pts+1]=b
 local pennants,half={},A.PennantWidth/2
 for k=1,n-1 do
  local p,q=pts[k+1],pts[k+2] -- the straight piece centred on t = k / n
  local mid,dir=(p+q)/2,(q-p).Unit
  pennants[#pennants+1]={Index=k,Mid=mid,Left=mid-dir*half,Right=mid+dir*half,Tip=mid-V(0,half,0)}
 end
 return{Points=pts,Pennants=pennants}
end
function A.Bunting(ctx,a,b,colours,spacing)
 local home=(a+b)/2 -- (every piece goes into the cell / level folder of the string's middle, as before)
 local plan=A.BuntingPlan(a,b,spacing)
 local pts=plan.Points
 for s=1,#pts-1 do
  local dir=(pts[s+1]-pts[s]).Unit
  ctx.Rod('detail',home.X,home.Z,'Bunting line',pts[s]-dir*A.BuntingOverlap,pts[s+1]+dir*A.BuntingOverlap,A.BuntingLine,{250,250,250})
 end
 for _,p in ipairs(plan.Pennants)do
  -- the wedge's own corners: right angle at its back-bottom edge, tall side +Y, long side along Z (the slope is the hypotenuse): Tip is the right angle
  local up,along=p.Right-p.Tip,p.Tip-p.Left
  local y,z=up.Unit,along.Unit
  ctx.Wedge('detail',home.X,home.Z,'Pennant',V(A.PennantThick,up.Magnitude,along.Magnitude),CFrame.fromMatrix(p.Mid,y:Cross(z),y,z),colours[(p.Index-1)%#colours+1],Mat.Fabric,{shadow=false})
 end
end

-- Grass patches (two layers: a layer-2 patch lies over the layer-1 patch it meets), pebbles, butterflies, wall lanterns, base verges and pots.
-- R154 (owner: "remove the cases of z fighting in the hub area too"): Grass is a textured material, laid out from each part's own position, so
-- two overlapping discs in one plane flicker even in one colour (the blob's three discs did, all over the square). Every grass disc now takes
-- the lowest of A.PatchPlanes that stands at least A.PatchGap from each grass disc it overlaps, above every disc of a lower layer it overlaps
-- and under every disc of a higher one (ctx.Grass keeps the discs already laid; the layout order is fixed, so every client gets the same).
-- A.PatchDiscs gives the same discs as pure data: HubSnow151 keeps the blizzard's drift tops off them.
A.PatchPlanes={4.07,4.12,4.17,4.22,4.27};A.PatchGap=.049
function A.PatchTop(ctx,x,z,r,base)
 local laid=ctx.Grass or{};ctx.Grass=laid
 local chosen=A.PatchPlanes[#A.PatchPlanes]
 for _,top in ipairs(A.PatchPlanes)do if top>=base-1e-6 then
  local ok=true
  for _,g in ipairs(laid)do if(g.X-x)^2+(g.Z-z)^2<(g.R+r)^2 then
   if math.abs(g.Top-top)<A.PatchGap or(g.Base<base and top<g.Top)or(g.Base>base and top>g.Top)then ok=false;break end
  end end
  if ok then chosen=top;break end
 end end
 laid[#laid+1]={X=x,Z=z,R=r,Top=chosen,Base=base}
 return chosen
end
-- a soft blob: a disc and two smaller ones of the same colour, each on its own plane ({x, z, radius, top} in the order they are laid)
function A.PatchShape(ctx,x,z,r,top)
 local rng=K.Rng('patch'..x..z)
 local out={{x,z,r,A.PatchTop(ctx,x,z,r,top)}}
 for i=1,2 do local a=rng(0,math.pi*2);local rr=r*rng(.45,.7);local cx,cz=x+math.cos(a)*r*.75,z+math.sin(a)*r*.75
  out[#out+1]={cx,cz,rr,A.PatchTop(ctx,cx,cz,rr,top)}
 end
 return out
end
function A.Patch(ctx,x,z,r,color,top)
 local main
 for i,d in ipairs(A.PatchShape(ctx,x,z,r,top))do
  local p=ctx.VCyl('core',x,z,'Grass patch',d[3]*2,3.9,d[4],d[1],d[2],color,Mat.Grass,{shadow=false})
  if i==1 then main=p end
 end
 return main
end
-- Every lawn disc of the layout as A.Build lays it: {X, Z, R, Top} (pure data, no parts).
function A.PatchDiscs()
 local ctx,out={},{}
 for _,p in ipairs(A.Layout.patches)do
  for _,d in ipairs(A.PatchShape(ctx,p[1],p[2],p[3],p[5]==1 and 4.07 or 4.12))do out[#out+1]={X=d[1],Z=d[2],R=d[3],Top=d[4]}end
 end
 return out
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
A.Full={ -- (R154: everything the square had; A.Layout, below, is what is built after the tidy)
 trees={
  -- R152 (owner: "reduce the amount of trees"): 24 of the 62 stay. They frame the square - the front corners by the gate, the lawns' outer
  -- edges, the market's sides, the south corners, the garden alleys' ends, the snow lane's far end; the middle, the streets and the
  -- lanes in front of the bases are clear (the welcome lawns by the gate first: the layout's order is the owner's models' order)
  {'oak',134,-136,'M'},{'oak',-134,-136,'M'},{'blossom',100,-142,'lilac'},{'blossom',-100,-142,'pink'},{'oak',96,-184,'L'},{'oak',-96,-184,'L'},
  {'oak',84,-300,'M'},{'oak',-84,-300,'L'},{'poplar',100,-262},{'poplar',-100,-262},
  {'oak',92,-372,'L'},{'oak',-92,-372,'M'},{'leafy',72,-392,'fresh'},{'leafy',-72,-392,'sage'},
  -- Desert garden (+X alley): palms and a saguaro
  {'palm',170,-252},{'palm',262,-252},{'palm',300,-286},{'cactus',240,-252,'saguaro'},
  -- Lava garden (-X alley): ember trees and a glowing rock
  {'ember',-170,-252},{'ember',-262,-252},{'ember',-300,-286},{'rock',-245,-252},
  -- Snow lane between Bases 5 and 6: the two pines at its far end
  {'pine',-8.7,-560,.5},{'pine',8.7,-585,.5},
 },
 bushes={
  {84,-172},{-84,-172},{20,-196},{-20,-196},{137,-290},{-137,-290},{137,-248},{-137,-248},{100,-320},{-100,-320},{58,-374},{-58,-374},
  {230,-248,'desert'},{280,-288,'desert'},{-230,-249,'ember'},{-280,-289,'ember'},
 },
 beds={{60,-196,5.5,'warm'},{-60,-196,5.5,'cool'},{36,-250,3.5,'warm',4.2},{-36,-250,3.5,'cool',4.2},{36,-300,3.5,'cool',4.2},{-36,-300,3.5,'warm',4.2},
  {118,-159,4,'warm',4.26},{-118,-159,4,'cool',4.26},{118,-411,4,'cool',4.26},{-118,-411,4,'warm',4.26}}, -- (R153: the three nooks' beds went with their benches: a trampoline fills each brick circle)
 topiary={{49,-236,'cone',true},{-49,-236,'cone',true},{49,-308,'ball',true},{-49,-308,'ball',true},{16,-170,'ball'},{-16,-170,'ball'},{322,-284,'cone'},{-322,-284,'cone'}},
 lamps={
  {106,-190,'post'},{106,-240,'post',true},{106,-290,'post'},{106,-340,'post',true},{106,-390,'post'},
  {-106,-190,'post'},{-106,-240,'post',true},{-106,-290,'post'},{-106,-340,'post',true},{-106,-390,'post'},
  {15.4,-200,'post',true},{-15.4,-200,'post',true},{15.4,-228,'post'},{-15.4,-228,'post'},
  {55,-236,'double',true,0},{-55,-236,'double',true,0},{55,-308,'double',false,0},{-55,-308,'double',false,0},
  {30,-400,'post'},{-30,-400,'post'},{140,-257,'post'},{-140,-257,'post'},
  {200,-279,'bollard'},{260,-259,'bollard'},{-200,-279,'bollard'},{-260,-259,'bollard'},
 },
 benches={ -- (R152: the four benches round the fountain are gone with it; R153: so are the two pairs at the garden nooks and the stone one at the lane nook, where the trampolines stand)
  {75,-200,math.pi/2,'wood'},{-75,-200,-math.pi/2,'wood'},{44,-275,math.pi/2,'garden'},{-44,-275,-math.pi/2,'garden'}},
 -- bunting: from, to ({x, y, z}), palette. R158: a string's ends are on something. The post lamps' ends are inside the lantern (y 17.4: the lantern is 16 to 18); the market ends
 -- are inside the eave's green roof course (the lowest course reaches z -290 .. -248.5, so z -250 and -287 are on it). The four market-corner DOUBLE lamps' ends were
 -- (+-55, 17.4): 1 stud over the arm's top, in the air (R151 hung them from a single post's height); they are now at the middle of the cap on the lamp's market-side head
 -- (x +-52.5, y 16.25 = FLOOR + 12.25), so the string leaves that head's cap and the lamp holds it.
 bunting={{{-15.4,17.4,-200},{15.4,17.4,-228},'rainbow'},{{15.4,17.4,-200},{-15.4,17.4,-228},'rainbow'},
  {{52.5,16.25,-236},{22,23,-250},'candy'},{{-52.5,16.25,-236},{-22,23,-250},'candy'},{{52.5,16.25,-308},{22,23,-287},'candy'},{{-52.5,16.25,-308},{-22,23,-287},'candy'}},
 patches={ -- x, z, r, shade (1 light, 2 deep, 3 sand, 4 ash), height layer (1 = 4.07, 2 = 4.12)
  {62,-205,16,1,1},{-62,-205,16,2,1},{78,-215,9,2,2},{-78,-195,9,1,2},{88,-282,13,1,1},{-88,-282,13,2,1},{82,-368,15,2,1},{-82,-368,15,1,1},
  {124,-134,9,1,1},{-124,-134,9,2,1},{232,-286,8,3,1},{276,-252,7,3,2},{-232,-286,8,4,1},{-276,-252,7,4,2},
 },
 butterflies={{60,8,-196},{-60,9,-198},{36,7,-252},{-36,8,-300},{118,8,-161},{-118,7,-409},{70,8,-382},{-70,9,-376},{312,8,-266},{-312,8,-272},{0,7,-592},{90,9,-240}},
}

-- R154 TIDY (owner: "reduce the amount of props in the base area like reduce the amount of lamps and to remove the soil beds and benches beside it just leave those parts
-- empty. basically just tidy up the base area"; then "the bushes and flags can stay"). ONE table says what the square keeps; flip a value to bring a kind back (A.Full has
-- all of it, A.Layout is A.Full through this table, and the whole build, the clearance tests and the lights follow A.Layout):
--   Beds     the round flower beds (white rim, black soil, orange / pink flowers): 10 on the lawns and round the market, none now (the trampoline nooks have none either)
--   Benches  the 4 benches beside them: none now
--   Pebbles  the scattered pebbles along the side streets and the garden walks (40 balls): gone
--   Lamps    the lamp posts kept, by their x, z in A.Full.lamps: 12 of 26, evenly spaced along the streets and round the market (all 8 that carry a real light, and the 4
--            that hold the bunting up); true keeps all 26. A lamp's bunting goes with it unless re-hung (BuntingExtra)
--            (a butterfly homed on a bed that went goes too: 6 of the 12 circled the beds' flowers; the other 6, over the lawns, the nooks and the lane, stay)
--   everything else the square had stays (trees, bushes, topiary, bunting, grass patches, verges, wall lanterns, the other butterflies)
A.Tidy={
 Beds=false,Benches=false,Pebbles=false,
 Lamps={
  {106,-240},{106,-340},{-106,-240},{-106,-340}, -- the side streets (both lit; the old 5 per street were 50 studs apart, these are 100)
  {15.4,-200},{-15.4,-200},                      -- the avenue's mouth (lit); its two lower posts are gone
  {55,-236},{-55,-236},{55,-308},{-55,-308},     -- the market's four corner doubles (the first pair lit); they hold the candy bunting
  {140,-257},{-140,-257},                        -- the garden walks' first posts
 },
 BuntingExtra={{{-15.4,17.4,-200},{15.4,17.4,-200},'rainbow'}}, -- (the avenue's two crossing strings lost their lower posts: one string now joins the two that stay)
}
local function lampAt(l,x,z)return math.abs(l[1]-x)<.01 and math.abs(l[2]-z)<.01 end
-- A layout from the full one through a tidy table (pure).
function A.Filter(full,tidy)
 local out={}
 for k,v in pairs(full)do out[k]=v end
 if tidy.Beds==false then
  out.beds={}
  -- a butterfly homed on a bed that went circled its flowers; with no flowers it would circle bare lawn: it goes with the bed (and comes back with Beds on). Those that stay
  -- keep their number in the full list (their wing colour and flutter are seeded by it), as the 4th entry.
  out.butterflies={}
  for k,b in ipairs(full.butterflies)do
   local home=false
   for _,bed in ipairs(full.beds)do if (b[1]-bed[1])^2+(b[3]-bed[2])^2<=(bed[3]+2)^2 then home=true end end
   if not home then out.butterflies[#out.butterflies+1]={b[1],b[2],b[3],k} end
  end
 end
 if tidy.Benches==false then out.benches={} end
 local keptLamp=function(x,z)
  if tidy.Lamps==true or tidy.Lamps==nil then return true end
  for _,k in ipairs(tidy.Lamps)do if lampAt(k,x,z)then return true end end
  return false
 end
 if tidy.Lamps~=true and tidy.Lamps~=nil then
  out.lamps={};for _,l in ipairs(full.lamps)do if keptLamp(l[1],l[2])then out.lamps[#out.lamps+1]=l end end
  -- a string of bunting hangs between two lamps: one whose end stood on a lamp that went is dropped
  -- (R158: a double lamp's string is tied to one of its two heads, 2.5 studs off the post: the lamp an end hangs from is the one within 3 studs)
  local function hungFrom(e)for _,l in ipairs(full.lamps)do if (l[1]-e[1])^2+(l[2]-e[3])^2<=3^2 then return l end end;return nil end
  out.bunting={}
  for _,b in ipairs(full.bunting)do
   local ok=true
   for _,e in ipairs({b[1],b[2]})do local l=hungFrom(e);if l and not keptLamp(l[1],l[2])then ok=false end end
   if ok then out.bunting[#out.bunting+1]=b end
  end
  for _,b in ipairs(tidy.BuntingExtra or{})do out.bunting[#out.bunting+1]=b end
 end
 return out
end
A.Layout=A.Filter(A.Full,A.Tidy)
-- (tests and the owner: A.SetTidy(table) rebuilds A.Layout; nil puts the shipped table back)
local shipped=A.Tidy
function A.SetTidy(t)A.Tidy=t or shipped;A.Layout=A.Filter(A.Full,A.Tidy);return A.Layout end
A.LayoutFns={}
-- The tree slots in layout order (HubStudTrees151.Plan fills the leafy ones with the owner's models in this order).
function A.TreeSlots()
 local out={}
 for i,t in ipairs(A.Layout.trees)do out[#out+1]={Index=i,Kind=t[1],X=t[2],Z=t[3],Variant=t[4]}end
 return out
end
local PATCH_COLOURS={{112,198,98},{70,150,74},{226,206,150},{90,78,80}}

-- The lit lamps' real lights in priority order: mirror pairs (x, -x at the same z) side by side, the layout's order kept between pairs, so any even cap
-- (HubLife151 caps them by device tier while only Cloudy asks) leaves the square symmetric and the street lamps first.
function A.OrderLights(ctx)
 local lights,order,taken=ctx.Lights,{},{}
 for i,l in ipairs(lights)do if not taken[i]then
  taken[i]=true;order[#order+1]=l
  local a=ctx.LightAt[l]
  for j=i+1,#lights do if not taken[j]then
   local b=ctx.LightAt[lights[j]]
   if a and b and math.abs(a[1]+b[1])<.01 and math.abs(a[2]-b[2])<.01 then taken[j]=true;order[#order+1]=lights[j];break end
  end end
 end end
 ctx.Lights=order
 return order
end
-- Build everything for a device tier (1..3). bases: {[i]={Frame=CFrame, Size=Vector3, Color=Color3}};
-- templates: HubStudTrees151.Collect's list (the owner's studded tree models; nil or empty = the part-built studded trees).
function A.Build(root,tier,bases,templates)
 local ctx=context(root,tier)
 ctx.Bases=bases
 local L=A.Layout
 local plan,sum=Trees.Plan(templates or{},tier,A.TreeSlots())
 for i,t in ipairs(L.trees)do
  local kind,x,z=t[1],t[2],t[3]
  if plan[i]and A.TemplateTree(ctx,x,z,kind,t[4],plan[i])then -- (the owner's model)
  elseif kind=='oak'then A.Oak(ctx,x,z,t[4])elseif kind=='poplar'then A.Poplar(ctx,x,z)elseif kind=='blossom'then A.Blossom(ctx,x,z,t[4])
  elseif kind=='leafy'then A.LeafyTree(ctx,x,z,t[4])elseif kind=='pine'then A.Pine(ctx,x,z,t[4])elseif kind=='palm'then A.Palm(ctx,x,z)
  elseif kind=='cactus'then A.Cactus(ctx,x,z,t[4])elseif kind=='ember'then A.EmberTree(ctx,x,z)elseif kind=='rock'then A.GlowRock(ctx,x,z)end
 end
 for _,b in ipairs(L.bushes)do A.Bush(ctx,b[1],b[2],b[3]=='desert'and{{150,170,80},{170,176,96}}or b[3]=='ember'and{{120,50,40},{150,70,40}}or nil)end
 for _,b in ipairs(L.beds)do A.FlowerBed(ctx,b[1],b[2],b[3],b[4],b[5])end
 for _,t in ipairs(L.topiary)do A.Topiary(ctx,t[1],t[2],t[3])end
 for _,l in ipairs(L.lamps)do A.Lamp(ctx,l[1],l[2],l[3],l[4],l[5])end
 A.OrderLights(ctx)
 for _,b in ipairs(L.benches)do A.Bench(ctx,b[1],b[2],b[3],b[4])end
 for _,b in ipairs(L.bunting)do A.Bunting(ctx,V(b[1][1],b[1][2],b[1][3]),V(b[2][1],b[2][2],b[2][3]),BUNTING[b[3]])end
 for _,p in ipairs(L.patches)do A.Patch(ctx,p[1],p[2],p[3],PATCH_COLOURS[p[4]],p[5]==1 and 4.07 or 4.12)end
 -- pebbles along the outer edges of the side streets and the garden walks (R154 tidy: gone unless A.Tidy.Pebbles)
 if A.Tidy.Pebbles~=false then for _,sx in ipairs({-1,1})do
  for _,z in ipairs({-222,-320,-386})do A.Pebbles(ctx,sx*131,z,3,1.6,'s')end
  for _,x in ipairs({160,215,250,290})do A.Pebbles(ctx,sx*x,-279.5,2,1.2,'g');A.Pebbles(ctx,sx*(x+12),-258.5,2,1.2,'g')end
 end end
 for i,b in pairs(bases or{})do
  A.Verge(ctx,b,i) -- (R152: no potted topiary guarding the spur's street end any more: nothing gate-like at a base)
 end
 for _,l in ipairs(K.WallLanterns)do local sec=K.Sections[l.Sec];A.WallLantern(ctx,sec,K.SOf(sec,l.W),K.WallTop)end
 local wings={{255,140,60},{255,230,90},{120,200,255},{240,130,230},{255,255,255}}
 for k,p in ipairs(L.butterflies)do local id=p[4]or k;A.Butterfly(ctx,p[1],p[2],p[3],wings[(id-1)%#wings+1],id)end
 for _,cell in pairs(ctx.Cells)do cell.Center=cell.N>0 and cell.Sum/cell.N or V(0,0,0)end
 -- what was really placed (a clone that could not be placed fell back to the part-built tree)
 local used=0;for _,n in pairs(ctx.Templated)do used+=n end
 sum.Used,sum.ByKind,sum.Parts=used,ctx.Templated,ctx.TemplateParts;ctx.TreePlan=sum
 return ctx
end
return A
