-- R151 Seed Festival Square, server half (owner approved docs/proposals/R151/base_area.md; "As built" there). Built once at start-up by
-- MapService (after MarketLayout), into Workspace.ChestChaseMap.HubDecor151:
--   Walls          the five saved wall parts keep their size, position and collision; they are recoloured (cream plaster) and dressed
--                  with a stone plinth, a gold string course, pilasters with topiary, a clipped hedge on top and four corner towers.
--   Murals         seven framed biome reliefs in track order round the hub (Forest and Jungle left of the gate ... Crystal and Storm Peaks right).
--   Banners        one banner per base, in the base's colour, on the wall behind it.
--   Gate           the keyboard arch over the track gap: two towers on the wall ends (the ONLY new parts that collide), a beam 40 studs up
--                  with one big key per biome showing that keeper's speed (each client ticks the keys it is fast enough for), flags, a crest.
--   Paths          paved streets, squares and plazas joining spawn, market, every base, the gate and the side gardens; base-coloured curbs.
--   BaseEntrances  an arch outside each base's 32-stud opening: the owner's name on a beam in the base's colour, a number medallion.
-- Everything is Anchored with CanTouch / CanQuery off; nothing stands on a base pad, plot, fence opening, treadmill, pedestal, spawn, the
-- run-up / track (|x| < 90 north of the walls), the safe line, the leaderboards, the market, Verity or the two reserved back corners
-- (the R151 displays). Trees and props are the client's (HubLifeArt151 / HubLife151.client).
local RS=game:GetService('ReplicatedStorage')
local K=require(RS:WaitForChild('HubDecorKit151'))
local M={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Mat=Enum.Material
local P,FLOOR,TOP=K.P,K.Floor,K.WallTop
M.Version=151

-- Walls -------------------------------------------------------------------------------------------------------------------------------------
M.WallColor={243,231,206}
local function restyleWalls(map)
 local walls=map:FindFirstChild('ChestChaseWalls');local design=map:FindFirstChild('GardenHubDesign')
 if walls then for _,w in ipairs(walls:GetChildren())do if w:IsA('BasePart')and w.Name:find('^Lobby')then
  if w:GetAttribute('R151OldColor')==nil then w:SetAttribute('R151OldColor',w.Color);w:SetAttribute('R151OldMaterial',w.Material.Name)end
  w.Color=K.C(M.WallColor);w.Material=Mat.Plaster -- size, CFrame, CanCollide untouched
 end end end
 -- the thin timber strips are replaced by the pilasters; the wood caps end up inside the hedge
 if design then for _,d in ipairs(design:GetChildren())do if d:IsA('BasePart')and d.Name:find('TimberPier')then d.Transparency=1 end end end
end
local function buildWalls(root)
 local f=K.Model(root,'Walls',true)
 for _,name in ipairs(K.SectionOrder)do local sec=K.Sections[name]
  local side=name:find('^Side')~=nil
  local function run(label,y0,y1,depth,color,mat)
   -- a strip along the whole face, `depth` out of it (.4 sunk into the wall); the side strips stop at the front / back strips
   local s0,s1=0,sec.len
   if side then s0,s1=depth-.4,sec.len-(depth-.4)end
   K.Part(f,label,V(s1-s0,y1-y0,depth),K.SecFrame(sec,(s0+s1)/2,(y0+y1)/2,depth/2-.4),color,mat)
  end
  run('Stone plinth',FLOOR,FLOOR+6,1.6,P.Stone,Mat.Cobblestone)
  run('Plinth cap',FLOOR+6,FLOOR+6.5,2.0,P.StoneDark,Mat.Slate)
  run('Gold string course',TOP-17.4,TOP-16.2,1.3,P.Gold,Mat.SmoothPlastic)
  -- a clipped hedge on top (7 thick: 1 over each face) so the skyline reads "garden", not "prison"
  local s0,s1=-1,sec.len+1
  if side then s0,s1=1,sec.len-1 end
  if name=='FrontXNeg'then s0=0 elseif name=='FrontXPos'then s1=sec.len end -- (the gate towers cap the ends at the gap)
  K.Part(f,'Hedge',V(s1-s0,6.3,7),K.SecFrame(sec,(s0+s1)/2,TOP-.8+3.15,-2.5),P.Hedge,Mat.Grass)
  for i,w in ipairs(K.Pilasters[name]or{})do
   local s=K.SOf(sec,w)
   K.Part(f,'Pilaster',V(7,TOP-.8-FLOOR,2.4),K.SecFrame(sec,s,(FLOOR+TOP-.8)/2,.8),P.Pilaster,Mat.Plaster)
   K.Part(f,'Pilaster base',V(8,2.2,3),K.SecFrame(sec,s,FLOOR+1.1,1.1),P.StoneDark,Mat.Slate)
   K.Part(f,'Pilaster cap',V(8.4,1.2,3.2),K.SecFrame(sec,s,TOP-.6,1.2),P.Gold,Mat.SmoothPlastic)
   -- topiary on the hedge: balls, with every third a two-tier "wedding cake"
   local c=K.At(sec,s,TOP+5.5,-2.5)
   if i%3==0 then
    K.VCyl(f,'Topiary tier',6.6,TOP+5.4,TOP+7.6,c.X,c.Z,P.HedgeDark,Mat.Grass);K.Ball(f,'Topiary ball',4.6,c+V(0,4.3,0),P.Hedge,Mat.Grass)
   else K.Ball(f,'Topiary ball',6.6,c+V(0,3.1,0),P.HedgeDark,Mat.Grass)end
  end
 end
 -- round corner towers on the walls' outer corners (they reach only 4 studs into the hub) with stepped candy roofs
 for _,c in ipairs({V(-340,0,-99),V(340,0,-99),V(-340,0,-623),V(340,0,-623)})do
  local h=TOP+12
  K.VCyl(f,'Corner tower',18,3.2,h,c.X,c.Z,P.Plaster,Mat.Plaster)
  K.VCyl(f,'Tower plinth',19.4,FLOOR-.4,FLOOR+6.6,c.X,c.Z,P.Stone,Mat.Cobblestone)
  K.VCyl(f,'Tower band',19.2,TOP-17.6,TOP-16,c.X,c.Z,P.Gold)
  K.VCyl(f,'Tower roof 1',21,h,h+3,c.X,c.Z,P.RoofRed,Mat.SmoothPlastic)
  K.VCyl(f,'Tower roof 2',15,h+3,h+7,c.X,c.Z,P.Cream,Mat.SmoothPlastic)
  K.VCyl(f,'Tower roof 3',9,h+7,h+11,c.X,c.Z,P.RoofRed,Mat.SmoothPlastic)
  K.Ball(f,'Tower finial',3.4,V(c.X,h+12.4,c.Z),P.Gold)
 end
 return f
end

-- Murals: framed reliefs built from thin blocks, wedges and discs (and balls for depth) on a plate. Each new piece sits .05 further out
-- than the last and is only .045 thick, so no two pieces share a plane: fronts are >= .05 apart (the z-fighting rule asks >= .043 at any
-- distance) and their tops / bottoms / sides never overlap in depth.
local STEP,TH=.05,.045
local function painter(f,sec,sc,y0,W,H)
 -- u in [-.5,.5] across (to the viewer's right), v in [0,1] up; sizes are fractions of the height H (shapes keep their shape)
 local front=1.0;local layer=0
 local D={}
 local function nextD(th)layer+=1;return front+STEP*layer-th/2 end
 local function pos(u,v,d)return K.At(sec,sc+u*W,y0+v*H,d)end
 function D.rect(u,v,du,dv,color,mat,rot)
  local th=TH;local d=nextD(th)
  local cf=K.SecFrame(sec,sc+u*W,y0+v*H,d)*CFrame.Angles(0,0,math.rad(rot or 0))
  return K.Part(f,'Mural piece',V(du*H,dv*H,th),cf,color,mat or Mat.SmoothPlastic,{shadow=false})
 end
 function D.tri(u,v,hw,h,color,mat) -- isosceles triangle: base centre (u, v), half-width hw, height h (fractions of H)
  local th=TH;local d=nextD(th)
  for _,side in ipairs({-1,1})do
   local cx=sc+u*W+side*hw*H/2
   K.Wedge(f,'Mural piece',V(th,h*H,hw*H),K.Frame(K.At(sec,cx,y0+(v+h/2)*H,d),V(0,1,0),sec.t*(-side)),color,mat or Mat.SmoothPlastic,{shadow=false})
  end
 end
 function D.disc(u,v,dd,color,mat)
  local th=TH;local d=nextD(th)
  return K.Part(f,'Mural piece',V(th,dd*H,dd*H),CFrame.fromMatrix(pos(u,v,d),sec.n,V(0,1,0),sec.n:Cross(V(0,1,0))),color,mat or Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder,shadow=false})
 end
 function D.ball(u,v,dd,color,mat)
  layer+=1;local r=dd*H/2
  return K.Ball(f,'Mural piece',dd*H,pos(u,v,front+STEP*layer-r*.55),color,mat,{shadow=false})
 end
 function D.cloud(u,v,s,color)
  for _,b in ipairs({{-.05,0,.09},{.0,.02,.12},{.06,0,.08}})do D.ball(u+b[1]*s,v+b[2]*s,b[3]*s,color or{255,255,255})end
 end
 function D.depth()return front+STEP*(layer+1)end
 return D
end
-- the seven scenes (each about 30 pieces)
local function drawBiome(D,i)
 local G={92,170,78}
 if i==1 then -- Forest: meadow, hills, pines, a round oak, a path, flowers, the sun and clouds
  D.rect(0,.5,1.63,1,{168,220,246});D.disc(.3,.78,.34,{255,244,190});D.disc(.3,.78,.24,{255,222,80})
  D.cloud(-.3,.82,1.1);D.cloud(.02,.9,.8)
  D.ball(-.32,.22,.56,{132,206,108},Mat.Grass);D.ball(.28,.18,.62,{116,194,96},Mat.Grass);D.rect(0,.1,1.63,.2,G,Mat.Grass)
  for _,t in ipairs({{-.42,.16,.13,.56},{-.3,.2,.1,.44},{-.18,.15,.12,.6},{.4,.18,.12,.52}})do D.rect(t[1],t[2]+.03,.04,.1,P.WoodDark);D.tri(t[1],t[2]+.06,t[3],t[4],{46,120,58},Mat.Grass)end
  D.rect(.12,.34,.07,.32,P.Wood);D.ball(.12,.6,.36,{88,170,72},Mat.Grass);D.ball(.05,.55,.24,{110,190,84},Mat.Grass);D.ball(.19,.57,.22,{100,180,78},Mat.Grass)
  D.rect(.02,.06,.1,.12,{236,220,180},Mat.Sand,8)
  for k,x in ipairs({-.08,.25,.33,-.24})do D.ball(x,.07,.035,({{255,96,120},{255,220,80},{255,255,255},{190,120,255}})[k])end
 elseif i==2 then -- Jungle: misty hills, a waterfall into a pool, palms, vines, big leaves, a parrot
  D.rect(0,.5,1.63,1,{150,212,170});D.tri(.25,.3,.5,.55,{70,140,92},Mat.Grass);D.tri(-.05,.3,.4,.45,{88,156,100},Mat.Grass)
  D.rect(-.26,.55,.16,.9,{124,206,232});D.rect(-.26,.08,.4,.1,{96,186,224});D.ball(-.3,.14,.08,{255,255,255});D.ball(-.22,.15,.07,{255,255,255})
  D.rect(0,.04,1.63,.08,{58,122,58},Mat.Grass)
  for _,pt in ipairs({{.2,.32,.56,-8,1},{.4,.24,.38,6,.7}})do
   D.rect(pt[1],pt[2],.05,pt[3],{140,100,62},Mat.Wood,pt[4])
   for _,a in ipairs({-60,-20,20,55,95})do D.rect(pt[1]+math.cos(math.rad(a))*.07*pt[5],pt[2]+pt[3]/2+.02+math.sin(math.rad(a))*.02,.3*pt[5],.05*pt[5],{44,146,100},Mat.Grass,a)end
  end
  for _,x in ipairs({-.46,-.08,.06,.46})do D.rect(x,.86,.025,.28,{60,140,60},Mat.Grass)end
  D.ball(-.44,.12,.32,{66,124,58},Mat.Grass);D.ball(.45,.1,.3,{98,156,66},Mat.Grass);D.ball(.0,.08,.22,{150,198,72},Mat.Grass)
  D.ball(-.1,.12,.06,{255,120,170});D.ball(.3,.1,.05,{255,90,90});D.ball(.04,.66,.05,{230,40,40});D.ball(.065,.63,.03,{255,210,60})
 elseif i==3 then -- Desert: hot sky, sun, pyramids, dunes, cacti, an oasis palm, rocks
  D.rect(0,.5,1.63,1,{252,226,170});D.disc(-.3,.76,.4,{255,214,140});D.disc(-.3,.76,.3,{255,170,70})
  D.cloud(.32,.86,.7,{255,248,230})
  D.tri(.2,.18,.42,.5,{214,170,98},Mat.Sandstone);D.tri(.4,.18,.22,.28,{224,182,112},Mat.Sandstone)
  D.tri(-.3,0,.5,.3,{236,200,128},Mat.Sand);D.tri(.35,0,.46,.24,{244,216,152},Mat.Sand);D.tri(-.02,0,.36,.18,{230,196,122},Mat.Sand)
  for _,c in ipairs({{-.1,.28,.44,1},{.12,.14,.24,.6}})do local x,y,h,s=c[1],c[2],c[3],c[4]
   D.rect(x,y,.07*s,h,{86,160,74},Mat.Grass);D.rect(x-.05*s,y+.04*s,.05*s,.16*s,{86,160,74},Mat.Grass);D.rect(x+.05*s,y+.1*s,.05*s,.14*s,{86,160,74},Mat.Grass)
  end
  D.ball(-.42,.06,.1,{170,130,90},Mat.Sandstone);D.ball(.46,.05,.08,{180,140,96},Mat.Sandstone)
  D.rect(0,.03,1.63,.06,{228,192,112},Mat.Sand)
 elseif i==4 then -- Snow: three peaks with caps, pines with snow, a snowman, an ice pond, snowflakes
  D.rect(0,.5,1.63,1,{206,230,246});D.cloud(-.32,.86,.8);D.cloud(.3,.9,.6)
  for _,m in ipairs({{-.25,.1,.36,.72},{.22,.1,.42,.84},{.0,.1,.26,.5}})do D.tri(m[1],m[2],m[3],m[4],{120,150,182},Mat.Slate);D.tri(m[1],m[2]+m[4]*.62,m[3]*.38*1.08,m[4]*.38,{250,252,255},Mat.Snow)end
  D.rect(0,.06,1.63,.12,{238,244,248},Mat.Snow);D.rect(-.16,.08,.3,.05,{176,220,240},Mat.Ice)
  for _,x in ipairs({-.44,-.36,.4,.46})do D.tri(x,.1,.07,.34,{60,120,96},Mat.Grass);D.tri(x,.28,.05,.16,{246,250,255},Mat.Snow)end
  D.ball(.18,.17,.14,{255,255,255});D.ball(.18,.29,.1,{255,255,255});D.ball(.18,.37,.07,{255,255,255});D.rect(.205,.37,.04,.012,{255,140,40})
  for _,s in ipairs({{-.4,.8},{-.08,.92},{.38,.74},{.1,.68},{-.2,.62}})do D.ball(s[1],s[2],.04,{255,255,255})end
 elseif i==5 then -- Lava: dark red sky, a volcano with a glowing crater and streams, smoke, a lava river, embers
  D.rect(0,.5,1.63,1,{96,42,54});D.disc(.38,.82,.16,{255,150,90},Mat.Neon)
  D.tri(.32,.1,.3,.34,{70,56,66},Mat.Basalt);D.tri(-.02,.1,.48,.74,{60,52,62},Mat.Basalt)
  D.tri(-.02,.66,.1,.18,{255,120,30},Mat.Neon)
  for _,s in ipairs({{-.04,.94,.12},{.04,.98,.1},{-.1,.99,.08}})do D.ball(s[1],s[2],s[3],{110,96,104})end
  D.rect(-.08,.46,.035,.36,{246,119,28},Mat.Neon,12);D.rect(.06,.4,.035,.42,{236,90,26},Mat.Neon,-14);D.rect(.0,.36,.03,.3,{255,160,60},Mat.Neon,3)
  D.rect(0,.06,1.63,.12,{48,40,48},Mat.Basalt);D.rect(.0,.11,1.2,.03,{246,119,28},Mat.Neon)
  D.ball(-.45,.1,.2,{80,64,70},Mat.Basalt);D.ball(.44,.12,.24,{70,58,66},Mat.Basalt);D.ball(-.3,.08,.12,{90,70,76},Mat.Basalt)
  for _,e in ipairs({{-.2,.6},{.22,.7},{.3,.5}})do D.ball(e[1],e[2],.03,{255,200,90},Mat.Neon)end
 elseif i==6 then -- Crystal: violet night, moon, stars, crystal clusters, glowing gems
  D.rect(0,.5,1.63,1,{72,52,112});D.disc(-.36,.8,.18,{240,236,255})
  for _,s in ipairs({{-.12,.86},{.06,.74},{.3,.88},{.42,.66},{.16,.94},{-.2,.7}})do D.ball(s[1],s[2],.04,{255,240,190},Mat.Neon)end
  D.rect(0,.06,1.63,.12,{94,78,123},Mat.Slate)
  for _,c in ipairs({{-.3,.3,.12,.5,-12,{150,108,208}},{-.2,.34,.14,.62,8,{204,178,237}},{-.08,.28,.1,.4,22,{222,156,226}},
   {.22,.32,.14,.56,-6,{190,156,236}},{.34,.26,.1,.36,18,{118,80,170}},{.12,.24,.08,.28,-26,{222,156,226}},{.44,.2,.07,.22,10,{204,178,237}},{-.44,.2,.08,.24,-16,{190,156,236}}})do
   D.rect(c[1],c[2],c[3],c[4],c[6],Mat.Glass,c[5])
  end
  for _,g in ipairs({{-.25,.1},{.05,.12},{.3,.1}})do D.ball(g[1],g[2],.05,{150,240,255},Mat.Neon)end
 else -- Storm Peaks: slate sky, a dark peak, clouds, lightning, rain
  D.rect(0,.5,1.63,1,{96,110,140})
  D.tri(-.34,.08,.26,.4,{84,94,120},Mat.Slate);D.tri(.12,.08,.5,.66,{68,76,100},Mat.Slate);D.tri(.12,.56,.15,.18,{220,226,240},Mat.Snow)
  for _,c in ipairs({{-.34,.8,.3},{-.18,.84,.36},{-.02,.78,.28},{.3,.86,.3},{.44,.8,.22},{.14,.9,.2}})do D.ball(c[1],c[2],c[3],{150,156,180},Mat.SmoothPlastic)end
  D.rect(-.24,.6,.035,.24,{255,232,90},Mat.Neon,-24);D.rect(-.2,.44,.035,.2,{255,232,90},Mat.Neon,28);D.rect(-.25,.3,.035,.2,{255,232,90},Mat.Neon,-24)
  for _,r in ipairs({{.3,.6},{.38,.52},{.46,.62},{.0,.62}})do D.rect(r[1],r[2],.012,.16,{190,214,240},Mat.SmoothPlastic,14)end
  D.rect(0,.05,1.63,.1,{84,98,128},Mat.Slate)
 end
end
local function buildMurals(root)
 local f=K.Model(root,'Murals',true)
 local H,Wd,y0=K.MuralH,K.MuralW,K.MuralY0
 for n,m in ipairs(K.Murals)do
  local sec=K.Sections[m.Sec];local s=K.SOf(sec,m.W);local b=K.Biomes[m.Biome]
  -- the plate (1.2 deep: sunk .2) holds the string course inside its own volume
  K.Part(f,'Mural plate',V(Wd,H,1.2),K.SecFrame(sec,s,y0+H/2,.4),{60,52,46})
  local D=painter(f,sec,s,y0,Wd,H);drawBiome(D,m.Biome)
  local fd=D.depth()+.4 -- the frame stands out past every piece
  for _,bar in ipairs({{0,H+1,Wd+4,2},{0,-1,Wd+4,2},{-Wd/2-1,H/2,2,H},{Wd/2+1,H/2,2,H}})do
   K.Part(f,'Mural frame',V(bar[3],bar[4],fd+.4),K.SecFrame(sec,s+bar[1],y0+bar[2],fd/2-.2),P.Gold,Mat.SmoothPlastic)
  end
  -- the name plaque under the frame; above it a half-disc crest (its lower half hides behind the plate) with the number key
  local plaque=K.Part(f,'Mural plaque',V(24,4.2,.9),K.SecFrame(sec,s,y0-4.4,1.75),{62,44,34},Mat.Wood)
  K.Label(plaque,Enum.NormalId.Back,n..' · '..b.Emoji..' '..b.Name,{ink={255,236,180},pps=40})
  K.Part(f,'Mural crest',V(.6,12,12),CFrame.fromMatrix(K.At(sec,s,y0+H+2,.3),sec.n,V(0,1,0),sec.n:Cross(V(0,1,0))),b.Key,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
  K.Keycap(f,'Mural number key',V(4.4,1.6,4.4),CFrame.fromMatrix(K.At(sec,s,y0+H+4.6,1.0),sec.t,sec.n,V(0,-1,0)),b.Light,tostring(n),{ink=b.Ink,stroke=b.Light,strokeT=1,pps=60})
 end
 return f
end

local function baseColour(base)local c=base:GetAttribute('BaseColor');return typeof(c)=='Color3'and c or RGB(240,240,240)end
local function basesByIndex(map)
 local out={};local bases=map:FindFirstChild('Bases')
 if bases then for _,b in ipairs(bases:GetChildren())do local i=b:GetAttribute('BaseIndex');local pad=b:FindFirstChild('Pad')
  if i and pad and pad:IsA('BasePart')then out[i]={Model=b,Pad=pad}end end end
 return out
end
local function buildBanners(root,bases)
 local f=K.Model(root,'Banners',false)
 for _,bn in ipairs(K.Banners)do local b=bases[bn.Base];if b then
  local sec=K.Sections[bn.Sec];local s=K.SOf(sec,bn.W);local col=baseColour(b.Model)
  local h=26;local y1=TOP-2;local y0=y1-h
  K.Part(f,'Banner rod',V(13,.7,.7),K.SecFrame(sec,s,y1+.6,1.3),P.GoldDeep)
  for _,e in ipairs({-1,1})do K.Ball(f,'Banner rod end',1.2,K.At(sec,s+e*6.9,y1+.6,1.3),P.Gold)end
  local cloth=K.Part(f,'Banner cloth',V(10,h,.3),K.SecFrame(sec,s,(y0+y1)/2,1.3),col,Mat.Fabric)
  K.Part(f,'Banner stripe',V(10.4,.8,.5),K.SecFrame(sec,s,y1-2.4,1.35),P.Gold,Mat.Fabric)
  for _,e in ipairs({-1,1})do K.Wedge(f,'Banner tail',V(.3,3.5,5),K.Frame(K.At(sec,s+e*2.5,y0-1.75,1.3),V(0,-1,0),sec.t*e),col,Mat.Fabric)end
  K.Label(cloth,Enum.NormalId.Back,{'BASE',tostring(bn.Base)},{weights={.25,.5},ink={255,255,255},pps=20})
 end end
 return f
end

-- Track gate ------------------------------------------------------------------------------------------------------------------------------
local GREEN=RGB(110,236,96)
function M.SpeedNeed(stage)
 -- the number the keeper's sign shows (KeeperSpeedLabels: points needed to be strictly faster, rounded up to 2 significant figures)
 local ok,escape,txt=pcall(function()
  local Pursuit=require(RS:WaitForChild('KeeperPursuit'));local Progress=require(RS:WaitForChild('Progression81'));local Points=require(RS:WaitForChild('SpeedPoints'))
  local speed=Pursuit.EscapeSpeed(stage)
  if speed<Progress.Speed(0)then return speed,'0'end
  return speed,Points.NeedText(Points.Add(Progress.PointsText(speed),'1'))
 end)
 if ok then return txt,escape end
 return'?',math.huge
end
local function buildGate(root)
 local f=K.Model(root,'Gate',true)
 local G=K.Gate
 for _,sx in ipairs({-1,1})do
  local x=sx*G.TowerX
  K.VCyl(f,'Gate tower',G.TowerD,3.2,66,x,G.TowerZ,P.Plaster,Mat.Plaster,{collide=true}) -- (the only new part that collides)
  K.VCyl(f,'Gate tower plinth',G.TowerD+1.4,FLOOR-.5,FLOOR+6,x,G.TowerZ,P.Stone,Mat.Cobblestone)
  K.VCyl(f,'Gate tower band',G.TowerD+1.2,29,31,x,G.TowerZ,P.Gold)
  K.VCyl(f,'Gate tower band',G.TowerD+1.2,52,54,x,G.TowerZ,P.Gold)
  K.VCyl(f,'Gate roof 1',G.TowerD+3.6,66,69,x,G.TowerZ,P.RoofTeal)
  K.VCyl(f,'Gate roof 2',G.TowerD-2,69,74,x,G.TowerZ,P.Cream)
  K.VCyl(f,'Gate roof 3',G.TowerD-7,74,79,x,G.TowerZ,P.RoofTeal)
  K.Ball(f,'Gate finial',3.6,V(x,80.6,G.TowerZ),P.Gold)
  -- the haunch: an upside-down wedge from the tower to the beam (its tall side against the tower)
  K.Wedge(f,'Arch haunch',V(9,12,32),K.Frame(V(sx*78,G.BeamY0-6,G.TowerZ),V(0,-1,0),V(sx,0,0)),P.Plaster,Mat.Plaster)
 end
 K.Part(f,'Arch beam',V(190,G.BeamY1-G.BeamY0,9),CF(0,(G.BeamY0+G.BeamY1)/2,G.TowerZ),P.Plaster,Mat.Plaster)
 K.Part(f,'Arch trim',V(184,1.2,10),CF(0,G.BeamY0+.2,G.TowerZ),P.Gold)
 K.Part(f,'Arch cornice',V(194,1.6,11),CF(0,G.BeamY1+.8,G.TowerZ),P.Gold)
 K.Part(f,'Gate crest',V(1.2,42,42),CFrame.fromMatrix(V(0,G.BeamY1+1.6,G.TowerZ+.6),V(0,0,1),V(0,1,0)),P.RoofRed,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
 local sign=K.Part(f,'Gate sign',V(46,8,1.2),CF(0,G.BeamY1+7,G.TowerZ-5.4),{62,44,34},Mat.Wood)
 K.Part(f,'Gate sign frame',V(48,10,1),CF(0,G.BeamY1+7,G.TowerZ-4.6),P.Gold)
 K.Label(sign,Enum.NormalId.Front,'THE TRACK',{ink={255,236,180},pps=24})
 for i,b in ipairs(K.Biomes)do
  local x=G.KeyX[i];local need,escape=M.SpeedNeed(b.Stage)
  local k=K.Keycap(f,'Biome key '..i,V(15,3.6,15),CFrame.fromMatrix(V(x,(G.BeamY0+G.BeamY1)/2,G.TowerZ-6.1),V(-1,0,0),V(0,0,-1),V(0,-1,0)),b.Key,
   {b.Emoji,b.Name,'⚡ '..need},{name='KeyLegend',weights={.42,.24,.34},ink={255,255,255},stroke=b.Ink,strokeT=.1,pps=20})
  k:SetAttribute('R151Stage',b.Stage);k:SetAttribute('R151Need',need);k:SetAttribute('R151EscapeSpeed',escape)
  local fx=G.FlagX[i];local y0=i==4 and G.BeamY1+22.6 or G.BeamY1+1.6
  K.VCyl(f,'Flag pole',.5,y0,y0+13,fx,G.TowerZ,P.WoodDark)
  K.Ball(f,'Flag pole ball',1.1,V(fx,y0+13.4,G.TowerZ),P.Gold)
  K.Part(f,'Flag',V(.3,4.6,7.2),CFrame.fromMatrix(V(fx-3.85,y0+10.4,G.TowerZ),V(0,0,1),V(0,1,0)),b.Key,Mat.Fabric)
 end
 return f
end
M.TickColor=GREEN

-- Paths: rectangles top at 4.20 never overlap each other; discs have their own tops (4.14 under the square, 4.26 over a street); curbs and
-- mats 4.32; the gate run-up lanes stop at 4.06 so the saved "SAFE ZONE" ground title (4.12 - 4.20) still draws on top of them.
local function slab(f,name,x0,x1,z0,z1,top,color,mat)
 return K.Part(f,name,V(math.abs(x1-x0),top-3.9,math.abs(z1-z0)),CF((x0+x1)/2,(top+3.9)/2,(z0+z1)/2),color,mat or Mat.Cobblestone,{shadow=false})
end
local function disc(f,name,x,z,r,top,color,mat)return K.VCyl(f,name,r*2,3.9,top,x,z,color,mat or Mat.Cobblestone,{shadow=false})end
local function curb(f,x0,x1,z0,z1,color)return slab(f,'Curb',x0,x1,z0,z1,4.32,color or P.Cream,Mat.SmoothPlastic)end
local function buildPaths(root,bases)
 local f=K.Model(root,'Paths',false)
 local w=180/7
 for i,b in ipairs(K.Biomes)do
  local x1=90-(i-1)*w;local x0=x1-w
  slab(f,'Run-up lane '..b.Name,x0+.15,x1-.15,-100.3,-150,4.06,K.C(b.Light):Lerp(RGB(255,255,255),.35),Mat.SmoothPlastic)
 end
 slab(f,'Run-up edge',-90,90,-150,-152,4.14,P.Cream,Mat.SmoothPlastic)
 slab(f,'Front street',-127,127,-152,-166,4.20,P.Street)
 for _,sx in ipairs({-1,1})do
  slab(f,'Side street',sx*109,sx*127,-166,-404,4.20,P.Street)
  curb(f,sx*108.4,sx*109,-171,-399)                          -- inner edge (the corner circles cover the ends)
  curb(f,sx*12.6,sx*106,-166.6,-166)                         -- front street, south edge between the avenue and the side street
  curb(f,sx*21,sx*106,-404,-403.4)                           -- south street, north edge (the fountain plaza in the middle)
  for _,seg in ipairs({{-196.2,-262},{-276,-342.3},{-373.7,-399}})do curb(f,sx*127,sx*127.6,seg[1],seg[2])end -- side street, outer edge between spurs
  for _,seg in ipairs({{106,89.6},{58.4,6.6}})do curb(f,sx*seg[1],sx*seg[2],-418.6,-418)end -- south street, south edge between spurs and lane
 end
 slab(f,'South street',-127,127,-404,-418,4.20,P.Street)
 slab(f,'Avenue',-12,12,-166,-232,4.20,P.Street)
 curb(f,-12.6,-12,-166.6,-232);curb(f,12,12.6,-166.6,-232)
 slab(f,'Market square',-52,52,-232,-312,4.20,P.Brick,Mat.Brick)
 disc(f,'Stage circle',0,-340,30,4.14,P.Street,Mat.Cobblestone)
 disc(f,'Fountain plaza',0,-392,21,4.26,P.Brick,Mat.Brick)
 for _,c in ipairs({{-118,-159},{118,-159},{-118,-411},{118,-411}})do disc(f,'Corner circle',c[1],c[2],12,4.26,P.Street)end
 for i,b in pairs(bases)do
  local col=baseColour(b.Model);local pad=b.Pad
  local p0=(pad.CFrame*CF(0,0,pad.Size.Z/2)).Position
  local out=-pad.CFrame.LookVector -- pad +Z (the entrance side) in world
  if math.abs(out.X)>.5 then -- bases 1-4: the entrance faces a side street
   local x0=p0.X+out.X*.1;local x1=(p0.X>0 and 1 or-1)*127
   slab(f,'Base spur '..i,x0,x1,p0.Z-15,p0.Z+15,4.20,P.Street)
   curb(f,x0,x1,p0.Z-15.6,p0.Z-15,col);curb(f,x0,x1,p0.Z+15,p0.Z+15.6,col)
   disc(f,'Welcome mat '..i,(x0+x1)/2,p0.Z,6,4.32,col,Mat.SmoothPlastic)
  else -- bases 5 / 6: the entrance faces the south street
   local z0=p0.Z+.1;local z1=-418
   slab(f,'Base spur '..i,p0.X-15,p0.X+15,z0,z1,4.20,P.Street)
   curb(f,p0.X-15.6,p0.X-15,z0,z1,col);curb(f,p0.X+15,p0.X+15.6,z0,z1,col)
  end
 end
 for _,sx in ipairs({-1,1})do
  slab(f,'Garden walk',sx*144.9,sx*299,-262,-276,4.20,P.Street);slab(f,'Garden walk',sx*299,sx*312,-262,-276,4.20,P.Street)
  slab(f,'Garden walk',sx*127,sx*144.9,-262,-276,4.20,P.Street)
  disc(f,'Garden nook',sx*312,-269,13,4.26,P.Brick,Mat.Brick)
  for _,z in ipairs({-261.4,-276.6})do curb(f,sx*145.5,sx*298,z-.3,z+.3,sx>0 and{236,200,128}or{150,70,50})end -- garden walk edging
 end
 slab(f,'Back lane',-6,6,-418,-594,4.20,P.Street)
 curb(f,-6.6,-6,-418.6,-586);curb(f,6,6.6,-418.6,-586)
 disc(f,'Lane nook',0,-596,10,4.26,P.Brick,Mat.Brick)
 return f
end

-- Base entrances: two posts, a beam in the base's colour with the owner's name, a number medallion, pennants. The beam's gold trim is
-- 14.3 studs over the pad: runners with packs and the follow camera pass under it. (R151: the owner asked for arches; the opening
-- itself, 32 studs wide, stays clear.)
M.FreeText='FREE BASE'
local function nameText(base)
 local n=base:GetAttribute('BaseOwnerDisplayName')
 return(type(n)=='string'and n~='')and(string.upper(n)..'\'S BASE')or M.FreeText
end
local function buildArches(root,bases)
 local f=K.Model(root,'BaseEntrances',false)
 for i,b in pairs(bases)do
  local col=baseColour(b.Model);local pad=b.Pad;local front=pad.Size.Z/2-2
  local m=Instance.new('Model');m.Name='Base'..i..'Arch';m.Parent=f
  local top=pad.CFrame*CF(0,pad.Size.Y/2,0)
  local function L(x,y,z)return top*CF(x,y,z)end
  for _,sx in ipairs({-1,1})do
   K.Part(m,'Arch footing',V(4.4,1.6,4.8),L(sx*19.5,.78,front),P.Stone,Mat.Cobblestone)
   K.Part(m,'Arch post',V(3.2,19.8,3.2),L(sx*19.5,9.9,front),P.Plaster,Mat.Plaster)
   K.Part(m,'Arch post band',V(3.6,.8,3.6),L(sx*19.5,6.4,front),col)
   K.Ball(m,'Arch post ball',4.4,L(sx*19.5,21.4,front).Position,col)
   K.Cyl(m,'Pennant pole',.4,6,L(sx*19.5,26.4,front),P.WoodDark)
   K.Wedge(m,'Pennant',V(.25,3,3.2),K.Frame(L(sx*19.5+sx*1.8,27.6,front).Position,V(0,-1,0),top.RightVector*-sx),col,Mat.Fabric)
  end
  local beam=K.Part(m,'Arch name beam',V(41,4.6,2.6),L(0,17.1,front),col,Mat.SmoothPlastic)
  K.Part(m,'Arch beam trim',V(41.6,.6,3),L(0,14.6,front),P.Gold)
  K.Label(beam,Enum.NormalId.Back,nameText(b.Model),{name='OwnerName',ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=24})
  K.Label(beam,Enum.NormalId.Front,'BASE '..i,{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=24})
  K.Part(m,'Arch medallion rim',V(1.4,8.6,8.6),L(0,23.6,front)*CFrame.Angles(0,math.pi/2,0),P.Gold,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
  local medal=K.Part(m,'Arch medallion',V(2.0,7.4,7.4),L(0,23.6,front)*CFrame.Angles(0,math.pi/2,0),col,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
  K.Label(medal,Enum.NormalId.Right,tostring(i),{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=30})
  K.Label(medal,Enum.NormalId.Left,tostring(i),{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=30})
 end
 return f
end
function M.UpdateOwnerNames(root,map)
 local bases=basesByIndex(map)
 for i,b in pairs(bases)do
  local arch=root:FindFirstChild('BaseEntrances')and root.BaseEntrances:FindFirstChild('Base'..i..'Arch')
  local beam=arch and arch:FindFirstChild('Arch name beam');local gui=beam and beam:FindFirstChild('OwnerName')
  if gui and gui:FindFirstChild('Line1')then gui.Line1.Text=nameText(b.Model)end
 end
end

local connections={}
function M.Apply(map)
 assert(map,'HubDecor151: no map')
 for _,c in ipairs(connections)do c:Disconnect()end;table.clear(connections)
 local old=map:FindFirstChild(K.FolderName);if old then old:Destroy()end
 local made0=K.Made
 local root=Instance.new('Folder');root.Name=K.FolderName;root:SetAttribute('Version',M.Version)
 restyleWalls(map)
 local bases=basesByIndex(map)
 -- what the client needs about the bases (their pads may be streamed out on a far client)
 for i,b in pairs(bases)do
  root:SetAttribute('Pad'..i,b.Pad.CFrame);root:SetAttribute('PadSize'..i,b.Pad.Size);root:SetAttribute('Color'..i,baseColour(b.Model))
 end
 buildWalls(root);buildMurals(root);buildBanners(root,bases);buildGate(root);buildPaths(root,bases);buildArches(root,bases)
 root:SetAttribute('Parts',K.Made-made0)
 root.Parent=map
 for _,b in pairs(bases)do
  connections[#connections+1]=b.Model:GetAttributeChangedSignal('BaseOwnerDisplayName'):Connect(function()M.UpdateOwnerNames(root,map)end)
 end
 -- the owner's studded tree models (loaded once per server; the clients use them as tree templates)
 task.spawn(function()local ok,err=pcall(function()require(script.Parent.HubTreeLoader151).Run()end);if not ok then warn('[R151 trees] '..tostring(err))end end)
 return root
end
return M
