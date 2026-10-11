--!nocheck
-- R151 PROPOSAL ONLY - scratch builder for the base-area / walls redesign renders (docs/proposals/R151/base_area.md).
-- NOT game code: it lives in docs/proposals/R151/preview/, runs on the Roblox mock (base_area_scene.luau) and is written in plain Roblox
-- Luau (Instance.new, CFrame, Enum ...) so a coder can port it piece by piece after the owner approves. Nothing here touches gameplay:
-- the saved walls keep their size, position and collision; every new part is Anchored, CanTouch / CanQuery off and (except the two
-- gate towers, which sit on the wall ends) CanCollide off.
--
-- Theme: "Seed Festival Square" - the hub is the seed-thieves' village square on festival day. The walls become a cream garden rampart
-- topped with a hedge; seven framed biome murals go round it in track order (Forest by the gate ... Storm Peaks by the gate), the gate
-- becomes a keyboard arch (one big key per biome with that keeper's speed), paved streets join spawn, market, bases and gate, and the
-- grass gets trees, flower beds, lamps, benches, bunting and a seed-pack fountain.
--
-- M.BuildServer(map, opts)  Phase 1: static geometry everyone shares (walls dressing, murals, gate, paths, base arches, base banners).
-- M.BuildClient(map, opts)  Phase 2: the "life" layer, built on each player's screen (trees, flower beds, lamps, benches, signposts,
--                           bunting, fountain, base flower verges, butterflies, petals) + the owner options (low wall + skyline).
-- opts.Wall = 'tall' (Phase 1: the 48-stud wall, dressed) | 'low' (owner option: the visible wall stops at 30 studs, the old wall stays
-- as an invisible barrier, a biome skyline shows beyond).  opts.Slots = true draws the reserved future slots as see-through ghosts.
local M={}
local RS=game:GetService('ReplicatedStorage')
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Mat=Enum.Material
local FLOOR=4 -- top of Workspace.ChestChaseMap.Lobby.LobbyFloor
M.Version=151

-- Palette ------------------------------------------------------------------------------------------------------------------------------
local P={
 Plaster={243,231,206},Pilaster={229,210,172},Stone={178,166,147},Gold={244,196,86},GoldDeep={214,160,58},Hedge={86,162,74},HedgeDark={66,138,62},
 RoofRed={230,96,84},RoofTeal={52,168,160},Wood={150,104,64},WoodDark={104,72,46},Cream={252,244,226},Street={222,206,172},Brick={214,142,110},
 Metal={44,84,76},Soil={104,74,52},Leaf={92,172,74},Leaf2={124,194,86},Blossom={248,172,204},Blossom2={255,206,224},Water={120,200,236},Ink={58,40,30},
}
local BIOMES={ -- track order (stage ids: Forest 1, Jungle 6, Desert 2, Snow 3, Lava 4, Crystal 5, Storm 7); colours from KeyboardTrack.Palettes
 {Stage=1,Name='FOREST',Emoji='🌲',Key={96,186,90},Light={164,218,120},Ink={16,48,20}},
 {Stage=6,Name='JUNGLE',Emoji='🌴',Key={44,146,100},Light={150,198,72},Ink={14,40,18}},
 {Stage=2,Name='DESERT',Emoji='🌵',Key={228,192,112},Light={244,216,152},Ink={84,50,20}},
 {Stage=3,Name='SNOW',Emoji='❄️',Key={170,208,232},Light={238,244,248},Ink={40,72,104}},
 {Stage=4,Name='LAVA',Emoji='🌋',Key={236,108,34},Light={198,58,26},Ink={54,14,8}},
 {Stage=5,Name='CRYSTAL',Emoji='💎',Key={150,108,208},Light={222,156,226},Ink={46,22,78}},
 {Stage=7,Name='STORM PEAKS',Emoji='⚡',Key={108,118,156},Light={130,122,178},Ink={18,20,34}},
}
M.Biomes=BIOMES
local function C(t)return typeof(t)=='Color3'and t or RGB(t[1],t[2],t[3])end

-- Part helpers ---------------------------------------------------------------------------------------------------------------------------
local count={}
M.Count=count
local function folder(parent,name,phase)
 local f=parent:FindFirstChild(name);if f then return f end
 f=Instance.new('Folder');f.Name=name;f:SetAttribute('R151Phase',phase);f.Parent=parent;return f
end
local function part(parent,name,size,cf,color,mat,o)
 o=o or{}
 local p=Instance.new(o.class or'Part')
 p.Name=name;p.Size=size;p.CFrame=cf;p.Color=C(color);p.Material=mat or Mat.SmoothPlastic
 p.Anchored=true;p.CanCollide=o.collide==true;p.CanTouch=false;p.CanQuery=false;p.CastShadow=o.shadow~=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if o.shape then p.Shape=o.shape end
 if o.t then p.Transparency=o.t end
 p.Parent=parent
 local g=parent.Name;count[g]=(count[g]or 0)+1
 return p
end
local function ball(parent,name,d,pos,color,mat,o)o=o or{};o.shape=Enum.PartType.Ball;return part(parent,name,V(d,d,d),CF(pos),color,mat,o)end
local UPRIGHT=CFrame.Angles(0,0,math.pi/2) -- a Cylinder's axis is its X: this stands it up
local function cyl(parent,name,d,h,cf,color,mat,o)o=o or{};o.shape=Enum.PartType.Cylinder;return part(parent,name,V(h,d,d),cf*UPRIGHT,color,mat,o)end
local function vcyl(parent,name,d,y0,y1,x,z,color,mat,o)return cyl(parent,name,d,y1-y0,CF(x,(y0+y1)/2,z),color,mat,o)end
local function wedge(parent,name,size,cf,color,mat,o)o=o or{};o.class='WedgePart';return part(parent,name,size,cf,color,mat,o)end
-- A CFrame from a position and two axes (X = Y x Z keeps it right-handed).
local function frame(pos,y,z)local x=y:Cross(z);return CFrame.fromMatrix(pos,x,y,z)end
-- A rod between two points (a thin cylinder).
local function rod(parent,name,a,b,d,color,mat)
 local mid=(a+b)/2;local len=(b-a).Magnitude
 local look=CFrame.lookAt(mid,b)
 return part(parent,name,V(len,d,d),look*CFrame.Angles(0,math.pi/2,0),color,mat,{shape=Enum.PartType.Cylinder,shadow=false})
end
-- SurfaceGui text on one face of a part.
local function label(p,face,text,o)
 o=o or{}
 local gui=Instance.new('SurfaceGui');gui.Name='R151Text';gui.Face=face;gui.LightInfluence=o.light or 0
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=o.pps or 40;gui.Parent=p
 local lines=type(text)=='table'and text or{text}
 local n=#lines
 for i,line in ipairs(lines)do
  local l=Instance.new('TextLabel');l.Name='Line'..i;l.BackgroundTransparency=1
  local h=o.weights and o.weights[i]or 1/n;local y=0;for j=1,i-1 do y+=o.weights and o.weights[j]or 1/n end
  l.Position=UDim2.fromScale(.04,y+.03);l.Size=UDim2.fromScale(.92,h-.06)
  l.Font=Enum.Font.FredokaOne;l.TextScaled=true;l.Text=line
  local ink=o.inks and o.inks[i]or o.ink or{255,255,255}
  l.TextColor3=C(ink);l.TextStrokeColor3=C(o.stroke or{30,24,20});l.TextStrokeTransparency=o.strokeT or .35
  l.Parent=gui
 end
 return gui
end
-- A keycap (the place's R142Keycap mesh, as the track uses) with a legend on its top face; `cf` puts the cap's top (+Y) where it faces.
local function keycap(parent,name,size,cf,color,legend,o)
 o=o or{}
 local template=RS:FindFirstChild('R142Keycap')
 local k
 if template then k=template:Clone();for _,c in ipairs(k:GetChildren())do c:Destroy()end else k=Instance.new('Part')end
 k.Name=name;k.Size=size;k.CFrame=cf;k.Color=C(color);k.Material=Mat.SmoothPlastic;k.Anchored=true;k.CanCollide=false;k.CanTouch=false;k.CanQuery=false
 k.Parent=parent;local g=parent.Name;count[g]=(count[g]or 0)+1
 if legend then label(k,Enum.NormalId.Top,legend,o)end
 return k
end

-- Hub geometry (measured from the owner's place: docs/proposals/R151/base_area.md section 1) ------------------------------------------
-- Inner faces of the five saved wall parts. s runs along the face to the viewer's right (seen from inside), d is the distance out of the
-- face into the hub, y is the world height. For every section the local frame is X = t (along), Y = up, Z = n (into the hub).
local SECTIONS={
 FrontXNeg={o=V(-94,0,-104),t=V(-1,0,0),n=V(0,0,-1),len=241},
 FrontXPos={o=V(335,0,-104),t=V(-1,0,0),n=V(0,0,-1),len=241},
 Back={o=V(-335,0,-618),t=V(1,0,0),n=V(0,0,1),len=670},
 SideXNeg={o=V(-335,0,-104),t=V(0,0,-1),n=V(1,0,0),len=514},
 SideXPos={o=V(335,0,-618),t=V(0,0,1),n=V(-1,0,0),len=514},
}
local function at(sec,s,y,d)return sec.o+sec.t*s+V(0,y,0)+sec.n*d end
local function secFrame(sec,s,y,d)return CFrame.fromMatrix(at(sec,s,y,d),sec.t,V(0,1,0),sec.n)end
-- s of a world x (front / back) or z (sides) on a section
local function sOf(sec,w)if sec.t.X~=0 then return(w-sec.o.X)/sec.t.X end;return(w-sec.o.Z)/sec.t.Z end
M.Sections=SECTIONS

-- Mural layout: centre (world x or z), section. Order = track order, starting left of the gate (+X, as you face the track) and coming
-- back on its right: Forest, Jungle (front wall +X), Desert (the +X alley), Snow (back wall, end of the main avenue), Lava (the -X alley),
-- Crystal, Storm Peaks (front wall -X).
local MURALS={
 {Biome=1,Sec='FrontXPos',W=160},{Biome=2,Sec='FrontXPos',W=262},{Biome=3,Sec='SideXPos',W=-269},{Biome=4,Sec='Back',W=0},
 {Biome=5,Sec='SideXNeg',W=-269},{Biome=6,Sec='FrontXNeg',W=-262},{Biome=7,Sec='FrontXNeg',W=-160},
}
M.Murals=MURALS
-- Wall banners in each base's colour, on the wall behind the base.
local BANNERS={{Base=1,Sec='SideXNeg',W=-180.5},{Base=3,Sec='SideXNeg',W=-358},{Base=2,Sec='SideXPos',W=-180.5},{Base=4,Sec='SideXPos',W=-358},
 {Base=5,Sec='Back',W=-74},{Base=6,Sec='Back',W=74}}
-- Pilasters: at the ends of every mural / banner bay and spaced along the plain stretches.
local PILASTERS={
 FrontXNeg={-131.5,-188.5,-233.5,-290.5},FrontXPos={131.5,188.5,233.5,290.5},
 Back={-300,-240,-180,-120,-28.5,28.5,120,180,240,300},
 SideXNeg={-140,-214,-240.5,-297.5,-322,-394,-460,-530,-590},SideXPos={-140,-214,-240.5,-297.5,-322,-394,-460,-530,-590},
}

-- Walls ------------------------------------------------------------------------------------------------------------------------------
local function wallTop(opts)return opts.Wall=='low'and 34 or 51 end
local function buildWalls(root,map,opts)
 local f=folder(root,'Walls',1)
 local top=wallTop(opts)
 local walls=map:FindFirstChild('ChestChaseWalls');local design=map:FindFirstChild('GardenHubDesign')
 -- 1. The saved walls keep size, place and collision; only their look changes (cream plaster instead of plain sage plastic).
 if walls then for _,w in ipairs(walls:GetChildren())do if w:IsA('BasePart')and w.Name:find('^Lobby')then
  w:SetAttribute('R151OldColor',w.Color);w.Color=C(P.Plaster);w.Material=Mat.Plaster
  if opts.Wall=='low'then -- owner option: the saved wall stays as the (invisible) barrier above the visible one
   w.Transparency=1;for _,t in ipairs(w:GetChildren())do if t:IsA('Texture')or t:IsA('Decal')then t.Transparency=1 end end
  end
 end end end
 -- The old timber piers are hidden (the pilasters replace them); the wood caps end up inside the hedge.
 if design then for _,d in ipairs(design:GetChildren())do if d:IsA('BasePart')then
  if d.Name:find('TimberPier')then d.Transparency=1 end
  if opts.Wall=='low'and d.Name:find('Cap$')then d.Transparency=1 end
 end end end
 if opts.Wall=='low'then -- the visible 30-stud wall, on the saved wall's footprint
  for _,spec in ipairs({{V(-214.5,0,-101.5),V(241,0,5)},{V(214.5,0,-101.5),V(241,0,5)},{V(0,0,-620.5),V(670,0,5)},{V(-337.5,0,-361),V(5,0,524)},{V(337.5,0,-361),V(5,0,524)}})do
   local c,s=spec[1],spec[2]
   part(f,'Visible wall (low option)',V(s.X-.04,top-3,s.Z-.04),CF(c.X,(3+top)/2,c.Z),P.Plaster,Mat.Plaster)
  end
 end
 for name,sec in pairs(SECTIONS)do
  local side=name:find('^Side')~=nil
  local function run(label,y0,y1,depth,color,mat)
   -- a strip along the whole face, `depth` proud of it (.4 sunk into the wall); side strips stop at the front / back strips
   local s0,s1=0,sec.len
   if side then s0,s1=depth-.4,sec.len-(depth-.4)end
   part(f,label,V(s1-s0,y1-y0,depth),secFrame(sec,(s0+s1)/2,(y0+y1)/2,depth/2-.4),color,mat)
  end
  run('Stone plinth',FLOOR,FLOOR+6,1.6,P.Stone,Mat.Cobblestone)
  run('Gold string course',top-17.4,top-16.2,1.3,P.Gold,Mat.SmoothPlastic)
  -- 2. A clipped hedge on top (7 thick: 1 over each face), so the skyline reads "garden", not "prison".
  local s0,s1=-1,sec.len+1
  if side then s0,s1=1,sec.len-1 end
  if name=='FrontXNeg'then s0=0 elseif name=='FrontXPos'then s1=sec.len end -- (the gate towers cap the ends at the gap)
  part(f,'Hedge',V(s1-s0,6.3,7),secFrame(sec,(s0+s1)/2,top-.8+3.15,-2.5),P.Hedge,Mat.Grass)
  -- 3. Pilasters with caps and topiary balls.
  for _,w in ipairs(PILASTERS[name]or{})do
   local s=sOf(sec,w)
   part(f,'Pilaster',V(7,top-.8-FLOOR,2.4),secFrame(sec,s,(FLOOR+top-.8)/2,.8),P.Pilaster,Mat.Plaster)
   part(f,'Pilaster cap',V(8.4,1.2,3.2),secFrame(sec,s,top-.6,1.2),P.Gold,Mat.SmoothPlastic)
   ball(f,'Topiary ball',6.6,at(sec,s,top+5.5+3.1,-2.5),P.HedgeDark,Mat.Grass)
  end
 end
 -- 4. Round corner towers (mostly outside the hub: 6.5 studs reach in) with stepped candy roofs.
 for _,c in ipairs({V(-337.5,0,-101.5),V(337.5,0,-101.5),V(-337.5,0,-620.5),V(337.5,0,-620.5)})do
  local h=top+12
  vcyl(f,'Corner tower',18,3.2,h,c.X,c.Z,P.Plaster,Mat.Plaster)
  vcyl(f,'Tower band',19.2,top-17.6,top-16,c.X,c.Z,P.Gold)
  vcyl(f,'Tower roof 1',21,h,h+3,c.X,c.Z,P.RoofRed,Mat.SmoothPlastic)
  vcyl(f,'Tower roof 2',15,h+3,h+7,c.X,c.Z,P.Cream,Mat.SmoothPlastic)
  vcyl(f,'Tower roof 3',9,h+7,h+11,c.X,c.Z,P.RoofRed,Mat.SmoothPlastic)
  ball(f,'Tower finial',3.4,V(c.X,h+12.4,c.Z),P.Gold)
 end
 return f
end

-- Murals: a framed relief of each biome, built from blocks, wedges, balls and discs on a plate; layers step .07 studs out from the plate so
-- nothing is coplanar (z-fighting rule: >= .02 offsets; .07 keeps the far-distance depth limit too).
local function muralPainter(f,sec,sc,y0,W,H)
 -- u in [-.5,.5] across (to the viewer's right), v in [0,1] up; sizes are fractions of the height H (so shapes keep their shape)
 local plateFront=1.0;local layer=0
 local D={}
 local function nextD(th)layer+=1;return plateFront+.07*layer-th/2 end
 local function pos(u,v,d)return at(sec,sc+u*W,y0+v*H,d)end
 function D.rect(u,v,du,dv,color,mat,rot)
  local th=.5;local d=nextD(th)
  local cf=secFrame(sec,sc+u*W,y0+v*H,d)*CFrame.Angles(0,0,math.rad(rot or 0))
  return part(f,'Mural piece',V(du*H,dv*H,th),cf,color,mat or Mat.SmoothPlastic,{shadow=false})
 end
 function D.tri(u,v,hw,h,color,mat) -- isosceles triangle, base centre (u, v), half-width hw, height h (fractions of H)
  local th=.5;local d=nextD(th)
  for _,side in ipairs({-1,1})do
   local cx=sc+u*W+side*hw*H/2
   -- wedge: local Y up, local Z towards the apex column (the wedge's tall back), X = Y x Z
   local z=sec.t*(-side);local cf=frame(at(sec,cx,y0+(v+h/2)*H,d),V(0,1,0),z)
   wedge(f,'Mural piece',V(th,h*H,hw*H),cf,color,mat or Mat.SmoothPlastic,{shadow=false})
  end
 end
 function D.disc(u,v,dd,color,mat)
  local th=.4;local d=nextD(th)
  local cf=CFrame.fromMatrix(pos(u,v,d),sec.n,V(0,1,0),sec.n:Cross(V(0,1,0)))
  return part(f,'Mural piece',V(th,dd*H,dd*H),cf,color,mat or Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder,shadow=false})
 end
 function D.ball(u,v,dd,color,mat)
  layer+=1;local r=dd*H/2
  return ball(f,'Mural piece',dd*H,pos(u,v,plateFront+.07*layer-r*.55),color,mat,{shadow=false})
 end
 return D
end
local MURAL_W,MURAL_H=44,27
local function drawBiome(D,i)
 local b=BIOMES[i]
 if i==1 then -- Forest: meadow, pines, a round oak, the sun
  D.rect(0,.5,1.63,1,{168,220,246});D.disc(.32,.78,.26,{255,226,92})
  D.ball(-.3,.2,.5,{120,196,96},Mat.Grass);D.ball(.25,.16,.56,{104,184,86},Mat.Grass);D.rect(0,.1,1.63,.2,{92,170,78},Mat.Grass)
  for _,t in ipairs({{-.36,.18,.15,.62},{-.2,.2,.12,.5},{.36,.18,.13,.56}})do D.rect(t[1],t[2]+.03,.05,.1,P.WoodDark);D.tri(t[1],t[2]+.06,t[3],t[4],{52,128,62},Mat.Grass)end
  D.rect(.08,.33,.07,.32,P.Wood);D.ball(.08,.6,.38,{88,170,72},Mat.Grass);D.ball(.0,.55,.24,{108,186,84},Mat.Grass)
 elseif i==2 then -- Jungle: misty green, waterfall, palm, vines, big leaves
  D.rect(0,.5,1.63,1,{150,212,170});D.rect(-.26,.55,.18,.9,{124,206,232});D.rect(-.26,.08,.36,.1,{96,186,224})
  D.rect(0,.06,1.63,.12,{58,122,58},Mat.Grass)
  D.rect(.2,.32,.06,.56,{140,100,62},Mat.Wood,-8)
  for _,a in ipairs({-60,-20,20,55,95})do D.rect(.22+math.cos(math.rad(a))*.07,.62+math.sin(math.rad(a))*.02,.32,.06,{44,146,100},Mat.Grass,a)end
  for _,x in ipairs({-.46,-.06,.42})do D.rect(x,.86,.03,.3,{60,140,60},Mat.Grass)end
  D.ball(-.44,.12,.34,{66,124,58},Mat.Grass);D.ball(.44,.1,.3,{98,156,66},Mat.Grass);D.ball(.0,.08,.22,{150,198,72},Mat.Grass)
 elseif i==3 then -- Desert: hot sky, sun, pyramid, dunes, a cactus
  D.rect(0,.5,1.63,1,{252,226,170});D.disc(-.3,.74,.34,{255,170,70})
  D.tri(.18,.18,.42,.5,{214,170,98},Mat.Sandstone)
  D.tri(-.3,0,.5,.3,{236,200,128},Mat.Sand);D.tri(.35,0,.46,.24,{244,216,152},Mat.Sand)
  D.rect(-.08,.3,.07,.44,{86,160,74});D.rect(-.13,.36,.05,.16,{86,160,74});D.rect(-.03,.42,.05,.14,{86,160,74})
  D.rect(0,.04,1.63,.08,{228,192,112},Mat.Sand)
 elseif i==4 then -- Snow: three peaks with snow caps, pines, snowflakes
  D.rect(0,.5,1.63,1,{206,230,246})
  for _,m in ipairs({{-.25,.1,.36,.72},{.22,.1,.42,.84},{.0,.1,.26,.5}})do D.tri(m[1],m[2],m[3],m[4],{120,150,182},Mat.Slate);D.tri(m[1],m[2]+m[4]*.62,m[3]*.38*1.08,m[4]*.38,{250,252,255},Mat.Snow)end
  D.rect(0,.06,1.63,.12,{238,244,248},Mat.Snow)
  for _,x in ipairs({-.42,.4})do D.tri(x,.1,.08,.36,{60,120,96},Mat.Grass);D.tri(x,.3,.05,.18,{246,250,255},Mat.Snow)end
  for _,s in ipairs({{-.4,.82},{-.08,.9},{.38,.76},{.1,.68}})do D.ball(s[1],s[2],.06,{255,255,255},Mat.SmoothPlastic)end
 elseif i==5 then -- Lava: dark red sky, volcano with glowing top and streams
  D.rect(0,.5,1.63,1,{96,42,54});D.disc(.36,.8,.18,{255,150,90},Mat.Neon)
  D.tri(-.02,.1,.48,.74,{60,52,62},Mat.Basalt)
  D.tri(-.02,.66,.1,.18,{255,120,30},Mat.Neon)
  D.rect(-.08,.46,.04,.36,{246,119,28},Mat.Neon,12);D.rect(.06,.4,.04,.42,{236,90,26},Mat.Neon,-14)
  D.rect(0,.06,1.63,.12,{48,40,48},Mat.Basalt);D.rect(.0,.12,1.0,.03,{246,119,28},Mat.Neon)
  D.ball(-.45,.1,.2,{80,64,70},Mat.Basalt);D.ball(.44,.12,.24,{70,58,66},Mat.Basalt)
 elseif i==6 then -- Crystal: violet night, crystal clusters, stars
  D.rect(0,.5,1.63,1,{72,52,112})
  for _,s in ipairs({{-.38,.86},{-.12,.74},{.3,.88},{.42,.66},{.08,.92}})do D.ball(s[1],s[2],.05,{255,240,190},Mat.Neon)end
  D.rect(0,.06,1.63,.12,{94,78,123},Mat.Slate)
  for _,c in ipairs({{-.3,.3,.12,.5,-12,{150,108,208}},{-.2,.34,.14,.62,8,{204,178,237}},{-.08,.28,.1,.4,22,{222,156,226}},
   {.22,.32,.14,.56,-6,{190,156,236}},{.34,.26,.1,.36,18,{118,80,170}},{.12,.24,.08,.28,-26,{222,156,226}}})do
   D.rect(c[1],c[2],c[3],c[4],c[6],Mat.Glass,c[5])
  end
 else -- Storm Peaks: slate sky, dark peak, clouds, lightning
  D.rect(0,.5,1.63,1,{96,110,140})
  D.tri(.12,.08,.5,.66,{68,76,100},Mat.Slate);D.tri(.12,.56,.15,.18,{220,226,240},Mat.Snow)
  for _,c in ipairs({{-.34,.8,.3},{-.18,.84,.36},{-.02,.78,.28},{.3,.86,.3},{.44,.8,.22}})do D.ball(c[1],c[2],c[3],{150,156,180},Mat.SmoothPlastic)end
  D.rect(-.24,.6,.035,.24,{255,232,90},Mat.Neon,-24);D.rect(-.2,.44,.035,.2,{255,232,90},Mat.Neon,28);D.rect(-.25,.3,.035,.2,{255,232,90},Mat.Neon,-24)
  D.rect(0,.05,1.63,.1,{84,98,128},Mat.Slate)
 end
end
local function buildMurals(root,opts)
 local f=folder(root,'Murals',1)
 local top=wallTop(opts)
 local H=opts.Wall=='low'and 17 or MURAL_H;local Wd=H*MURAL_W/MURAL_H
 local y0=opts.Wall=='low'and 11.5 or 15
 for n,m in ipairs(MURALS)do
  local sec=SECTIONS[m.Sec];local s=sOf(sec,m.W);local b=BIOMES[m.Biome]
  -- the plate (1.2 deep: sunk .2) hides the string course inside its own volume; the frame is 3.4 proud
  part(f,'Mural plate',V(Wd,H,1.2),secFrame(sec,s,y0+H/2,.4),{60,52,46})
  drawBiome(muralPainter(f,sec,s,y0,Wd,H),m.Biome)
  local fd=3.4
  for _,bar in ipairs({{0,H+1,Wd+4,2},{0,-1,Wd+4,2},{-Wd/2-1,H/2,2,H},{Wd/2+1,H/2,2,H}})do
   part(f,'Mural frame',V(bar[3],bar[4],fd+.4),secFrame(sec,s+bar[1],y0+bar[2],fd/2-.2),P.Gold,Mat.SmoothPlastic)
  end
  -- the name plaque under the frame; above it a crest (half a disc: its lower half is hidden behind the plate) with the number key
  local plaque=part(f,'Mural plaque',V(math.min(24,Wd*.6),4.2,.9),secFrame(sec,s,y0-4.4,1.75),{62,44,34},Mat.Wood)
  label(plaque,Enum.NormalId.Back,{n..' · '..b.Emoji..' '..b.Name},{ink={255,236,180}})
  if opts.Wall~='low'then -- (the low wall has no room above the frame for the crest and its key)
   part(f,'Mural crest',V(.6,12,12),CFrame.fromMatrix(at(sec,s,y0+H+2,.3),sec.n,V(0,1,0),sec.n:Cross(V(0,1,0))),b.Key,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
   keycap(f,'Mural number key',V(4.4,1.6,4.4),CFrame.fromMatrix(at(sec,s,y0+H+4.6,1.0),sec.t,sec.n,V(0,-1,0)),b.Light,tostring(n),{ink=b.Ink,stroke=b.Light,strokeT=1,pps=60})
  end
 end
 return f
end

local function baseColour(base)
 local c=base:GetAttribute('BaseColor');if typeof(c)=='Color3'then return c end
 return RGB(240,240,240)
end
local function buildBanners(root,map,opts)
 local f=folder(root,'Banners',1)
 local top=wallTop(opts)
 local bases={};for _,b in ipairs(map.Bases:GetChildren())do local i=b:GetAttribute('BaseIndex');if i then bases[i]=b end end
 for _,bn in ipairs(BANNERS)do
  local base=bases[bn.Base];if base then
   local sec=SECTIONS[bn.Sec];local s=sOf(sec,bn.W);local col=baseColour(base)
   local h=opts.Wall=='low'and 14 or 26;local y1=top-2;local y0=y1-h
   part(f,'Banner rod',V(13,.7,.7),secFrame(sec,s,y1+.6,1.3),P.GoldDeep)
   local cloth=part(f,'Banner cloth',V(10,h,.3),secFrame(sec,s,(y0+y1)/2,1.3),col,Mat.Fabric)
   wedge(f,'Banner tail',V(.3,3.5,5),frame(at(sec,s-2.5,y0-1.75,1.3),V(0,-1,0),-sec.t),col,Mat.Fabric)
   wedge(f,'Banner tail',V(.3,3.5,5),frame(at(sec,s+2.5,y0-1.75,1.3),V(0,-1,0),sec.t),col,Mat.Fabric)
   label(cloth,Enum.NormalId.Back,{'BASE',tostring(bn.Base)},{weights={.25,.5},ink={255,255,255},pps=24})
  end
 end
 return f
end

-- Track gate: two round towers on the wall ends, an arch beam 40 studs up, one big key per biome (emoji, name, the keeper's speed),
-- seven flags, and the crest "THE TRACK". The run-up in front is paved in seven biome lanes (paths, below).
M.Gate={TowerX=99,TowerZ=-100,TowerD=16,BeamY0=44,BeamY1=56,KeyX={72,48,24,0,-24,-48,-72}}
local function speedText(stage)
 -- the same number the keeper's sign shows (KeeperSpeedLabels.client.lua: points needed to be strictly faster, 2 significant figures)
 local ok,txt=pcall(function()
  local Pursuit=require(RS:WaitForChild('KeeperPursuit'));local Progress=require(RS:WaitForChild('Progression81'));local Points=require(RS:WaitForChild('SpeedPoints'))
  local speed=Pursuit.EscapeSpeed(stage)
  if speed<Progress.Speed(0)then return'0'end
  return Points.NeedText(Points.Add(Progress.PointsText(speed),'1'))
 end)
 return ok and txt or'?'
end
M.SpeedText=speedText
local function buildGate(root,opts)
 local f=folder(root,'Gate',1)
 local G=M.Gate
 for _,sx in ipairs({-1,1})do
  local x=sx*G.TowerX
  vcyl(f,'Gate tower',G.TowerD,3.2,66,x,G.TowerZ,P.Plaster,Mat.Plaster,{collide=true})
  vcyl(f,'Gate tower plinth',G.TowerD+1.4,FLOOR-.5,FLOOR+6,x,G.TowerZ,P.Stone,Mat.Cobblestone)
  vcyl(f,'Gate tower band',G.TowerD+1.2,29,31,x,G.TowerZ,P.Gold)
  vcyl(f,'Gate tower band',G.TowerD+1.2,52,54,x,G.TowerZ,P.Gold)
  vcyl(f,'Gate roof 1',G.TowerD+3.6,66,69,x,G.TowerZ,P.RoofTeal)
  vcyl(f,'Gate roof 2',G.TowerD-2,69,74,x,G.TowerZ,P.Cream)
  vcyl(f,'Gate roof 3',G.TowerD-7,74,79,x,G.TowerZ,P.RoofTeal)
  ball(f,'Gate finial',3.6,V(x,80.6,G.TowerZ),P.Gold)
  -- the arch's haunch: an upside-down wedge from the tower to the beam (its tall side against the tower)
  wedge(f,'Arch haunch',V(9,12,32),frame(V(sx*78,G.BeamY0-6,-100),V(0,-1,0),V(sx,0,0)),P.Plaster,Mat.Plaster)
 end
 part(f,'Arch beam',V(190,G.BeamY1-G.BeamY0,9),CF(0,(G.BeamY0+G.BeamY1)/2,-100),P.Plaster,Mat.Plaster)
 part(f,'Arch trim',V(184,1.2,10),CF(0,G.BeamY0+.2,-100),P.Gold)
 part(f,'Arch cornice',V(194,1.6,11),CF(0,G.BeamY1+.8,-100),P.Gold)
 -- crest + sign
 local crest=part(f,'Gate crest',V(1.2,42,42),CFrame.fromMatrix(V(0,G.BeamY1+1.6,-99.4),V(0,0,1),V(0,1,0)),P.RoofRed,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
 local sign=part(f,'Gate sign',V(46,8,1.2),CF(0,G.BeamY1+7,-105.4),{62,44,34},Mat.Wood)
 part(f,'Gate sign frame',V(48,10,1),CF(0,G.BeamY1+7,-104.6),P.Gold)
 label(sign,Enum.NormalId.Front,'THE TRACK',{ink={255,236,180},pps=30})
 -- one key per biome, its top facing the hub: emoji, name, the keeper's speed (client: green with a tick once you are faster)
 for i,b in ipairs(BIOMES)do
  local x=G.KeyX[i];local need=speedText(b.Stage)
  local k=keycap(f,'Biome key '..i,V(15,3.6,15),CFrame.fromMatrix(V(x,(G.BeamY0+G.BeamY1)/2,-106.1),V(-1,0,0),V(0,0,-1),V(0,-1,0)),b.Key,
   {b.Emoji,b.Name,'⚡ '..need},{weights={.42,.24,.34},ink={255,255,255},stroke=b.Ink,strokeT=.1,pps=24})
  k:SetAttribute('R151Stage',b.Stage)
  -- flags on the beam above the keys (the middle one on the crest)
  local fx=({80,60,40,0,-40,-60,-80})[i];local y0=i==4 and G.BeamY1+22.6 or G.BeamY1+1.6
  vcyl(f,'Flag pole',.5,y0,y0+13,fx,-100,P.WoodDark)
  ball(f,'Flag pole ball',1.1,V(fx,y0+13.4,-100),P.Gold)
  part(f,'Flag',V(.3,4.6,7.2),CFrame.fromMatrix(V(fx-3.85,y0+10.4,-100),V(0,0,1),V(0,1,0)),b.Key,Mat.Fabric)
 end
 return f
end

-- Paths: paving slabs on the grass. Rectangles top at 4.20 and never overlap each other; round plazas are discs with their own tops
-- (4.14 under the square, 4.26 over a street); curbs 4.32; the gate run-up's lanes stop at 4.06 so the saved "safe zone" ground title
-- (4.12 - 4.20) still draws on top of them.
local function slab(f,name,x0,x1,z0,z1,top,color,mat)
 return part(f,name,V(math.abs(x1-x0),top-3.9,math.abs(z1-z0)),CF((x0+x1)/2,(top+3.9)/2,(z0+z1)/2),color,mat or Mat.Cobblestone,{shadow=false})
end
local function disc(f,name,x,z,r,top,color,mat)return vcyl(f,name,r*2,3.9,top,x,z,color,mat or Mat.Cobblestone,{shadow=false})end
local function curb(f,x0,x1,z0,z1,color)return slab(f,'Curb',x0,x1,z0,z1,4.32,color or P.Cream,Mat.SmoothPlastic)end
M.Paths={StreetX={109,127},FrontZ={-150,-166},SouthZ={-404,-418},Avenue=12,Square={52,-232,-312},Verity={0,-340,30},Fountain={0,-392,21}}
local function buildPaths(root,map)
 local f=folder(root,'Paths',1)
 -- gate run-up: seven lanes in the biome colours (Forest on the left as you face the gate ... Storm Peaks on the right)
 local w=180/7
 for i,b in ipairs(BIOMES)do
  local x1=90-(i-1)*w;local x0=x1-w
  local c=C(b.Light):Lerp(RGB(255,255,255),.35)
  slab(f,'Run-up lane '..b.Name,x0+.15,x1-.15,-100.3,-150,4.06,c,Mat.SmoothPlastic)
 end
 slab(f,'Run-up edge',-90,90,-150,-152,4.14,P.Cream,Mat.SmoothPlastic)
 -- the street ring: front street, the two side streets, the south street; the avenue down the middle
 slab(f,'Front street',-127,127,-152,-166,4.20,P.Street)
 for _,sx in ipairs({-1,1})do
  slab(f,'Side street',sx*109,sx*127,-166,-404,4.20,P.Street)
  curb(f,sx*108.4,sx*109,-166,-404) -- (inner curb only: the outer side is broken by the spurs and the garden walks)
 end
 slab(f,'South street',-127,127,-404,-418,4.20,P.Street)
 slab(f,'Avenue',-12,12,-166,-232,4.20,P.Street)
 curb(f,-12.6,-12,-166,-232);curb(f,12,12.6,-166,-232)
 -- market square (brick), Verity's round stage (under the square's edge), the fountain plaza (over the south street)
 slab(f,'Market square',-52,52,-232,-312,4.20,P.Brick,Mat.Brick)
 disc(f,'Stage circle',0,-340,30,4.14,P.Street,Mat.Cobblestone)
 disc(f,'Fountain plaza',0,-392,21,4.26,P.Brick,Mat.Brick)
 -- round corners of the ring (discs over the joints)
 for _,c in ipairs({{-118,-159},{118,-159},{-118,-411},{118,-411}})do disc(f,'Corner circle',c[1],c[2],12,4.26,P.Street) end
 -- spurs to each base's entrance (to the pad's edge), with curbs in the base's colour
 for _,base in ipairs(map.Bases:GetChildren())do local i=base:GetAttribute('BaseIndex');local pad=base:FindFirstChild('Pad')
  if i and pad then
   local col=baseColour(base)
   local front=pad.CFrame*CF(0,0,pad.Size.Z/2)
   local out=pad.CFrame.LookVector*-1 -- pad +Z (the entrance side) in world
   local p0=front.Position
   if math.abs(out.X)>.5 then -- bases 1-4: entrance faces the side street
    local x0=p0.X+out.X*.1;local x1=(p0.X>0 and 1 or-1)*127
    slab(f,'Base spur '..i,x0,x1,p0.Z-15,p0.Z+15,4.20,P.Street)
    curb(f,x0,x1,p0.Z-15.6,p0.Z-15,col);curb(f,x0,x1,p0.Z+15,p0.Z+15.6,col)
    disc(f,'Welcome mat '..i,(x0+x1)/2,p0.Z,6,4.32,col,Mat.SmoothPlastic)
   else -- bases 5 / 6: entrance faces the south street
    local z0=p0.Z+.1;local z1=-418
    slab(f,'Base spur '..i,p0.X-15,p0.X+15,z0,z1,4.20,P.Street)
    curb(f,p0.X-15.6,p0.X-15,z0,z1,col);curb(f,p0.X+15,p0.X+15.6,z0,z1,col)
   end
  end
 end
 -- the side gardens (alleys between bases 1/3 and 2/4) and the back lane between bases 5 and 6, each ending at its mural
 for _,sx in ipairs({-1,1})do
  slab(f,'Garden walk',sx*144.9,sx*312,-262,-276,4.20,P.Street)
  disc(f,'Garden nook',sx*312,-269,13,4.26,P.Brick,Mat.Brick)
  slab(f,'Garden walk',sx*127,sx*144.9,-262,-276,4.20,P.Street)
 end
 slab(f,'Back lane',-6,6,-418,-594,4.20,P.Street)
 disc(f,'Lane nook',0,-596,10,4.26,P.Brick,Mat.Brick)
 return f
end

-- Base entrances: two posts, a beam in the base's colour with the owner's name, a number key on top, pennants. The beam's underside is 15
-- studs over the pad (the pad top is 5): runners carrying packs and the camera pass under it.
local function buildBaseArches(root,map)
 local f=folder(root,'BaseEntrances',1)
 for _,base in ipairs(map.Bases:GetChildren())do local i=base:GetAttribute('BaseIndex');local pad=base:FindFirstChild('Pad')
  if i and pad then
   local col=baseColour(base);local front=pad.Size.Z/2-2
   local top=pad.CFrame*CF(0,pad.Size.Y/2,0)
   local function L(x,y,z)return top*CF(x,y,z)end
   for _,sx in ipairs({-1,1})do
    part(f,'Arch footing',V(4.4,1.6,4.8),L(sx*19.5,.8-.02,front),P.Stone,Mat.Cobblestone)
    part(f,'Arch post',V(3.2,19.8,3.2),L(sx*19.5,9.9,front),P.Plaster,Mat.Plaster)
    ball(f,'Arch post ball',4.4,L(sx*19.5,21.4,front).Position,col)
    cyl(f,'Pennant pole',.4,6,L(sx*19.5,26.4,front),P.WoodDark)
    wedge(f,'Pennant',V(.25,3,3.2),frame(L(sx*19.5+sx*1.8,27.6,front).Position,V(0,-1,0),top.RightVector*-sx),col,Mat.Fabric)
   end
   local beam=part(f,'Arch name beam',V(41,4.6,2.6),L(0,17.1,front),col,Mat.SmoothPlastic)
   part(f,'Arch beam trim',V(41.6,.6,3),L(0,14.6,front),P.Gold)
   local name=base:GetAttribute('BaseOwnerDisplayName')
   local text=(name and name~='')and(string.upper(name)..'\'S BASE')or'FREE BASE'
   label(beam,Enum.NormalId.Back,text,{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=30})
   label(beam,Enum.NormalId.Front,'BASE '..i,{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=30})
   -- a medallion on top with the base number on both faces (readable leaving and arriving)
   part(f,'Arch medallion rim',V(1.4,8.6,8.6),L(0,23.6,front)*CFrame.Angles(0,math.pi/2,0),P.Gold,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
   local medal=part(f,'Arch medallion',V(2.0,7.4,7.4),L(0,23.6,front)*CFrame.Angles(0,math.pi/2,0),col,Mat.SmoothPlastic,{shape=Enum.PartType.Cylinder})
   label(medal,Enum.NormalId.Right,tostring(i),{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=40})
   label(medal,Enum.NormalId.Left,tostring(i),{ink={255,255,255},stroke={20,20,30},strokeT=.2,pps=40})
  end
 end
 return f
end

function M.BuildServer(map,opts)
 opts=opts or{}
 local root=workspace:FindFirstChild('R151HubDressing')or Instance.new('Folder');root.Name='R151HubDressing';root.Parent=workspace
 buildWalls(root,map,opts);buildMurals(root,opts);buildBanners(root,map,opts);buildGate(root,opts);buildPaths(root,map);buildBaseArches(root,map)
 return root
end

-- Client layer (Phase 2) ----------------------------------------------------------------------------------------------------------------
local function tree(f,x,z,kind,s)
 s=s or 1;local y=FLOOR
 if kind=='pine'then
  vcyl(f,'Pine trunk',1.4*s,y,y+4*s,x,z,P.WoodDark,Mat.Wood)
  vcyl(f,'Pine tier',9*s,y+4*s,y+7*s,x,z,{52,128,84},Mat.Grass);vcyl(f,'Pine tier',6.6*s,y+7*s,y+10*s,x,z,{60,140,90},Mat.Grass)
  vcyl(f,'Pine tier',4*s,y+10*s,y+13*s,x,z,{70,150,96},Mat.Grass);ball(f,'Pine snow',2.6*s,V(x,y+13.6*s,z),{246,250,255},Mat.Snow)
  return
 end
 if kind=='palm'then
  local base=V(x,y,z);local lean=V(1.2,0,.6)*s
  for k=0,2 do rod(f,'Palm trunk',base+lean*k+V(0,k*4.2*s,0),base+lean*(k+1)+V(0,(k+1)*4.2*s,0),1.3*s,{150,112,72},Mat.Wood)end
  local crown=base+lean*3+V(0,12.6*s,0)
  for a=0,5 do local ang=a*math.pi/3
   local tip=crown+V(math.cos(ang)*6*s,-2.6*s,math.sin(ang)*6*s)
   part(f,'Palm leaf',V(7*s,.4,2*s),CFrame.lookAt((crown+tip)/2,tip)*CFrame.Angles(0,math.pi/2,0),{60,150,72},Mat.Grass,{shadow=true})
  end
  ball(f,'Coconuts',1.8*s,crown-V(0,.6,0),{120,84,52})
  return
 end
 if kind=='cactus'then
  vcyl(f,'Cactus',2.2*s,y,y+7*s,x,z,{86,160,74},Mat.Grass);ball(f,'Cactus top',2.2*s,V(x,y+7*s,z),{86,160,74},Mat.Grass)
  vcyl(f,'Cactus arm',1.4*s,y+3*s,y+5.6*s,x+1.9*s,z,{86,160,74},Mat.Grass);ball(f,'Cactus flower',1.0*s,V(x,y+8.1*s,z),{255,120,150})
  return
 end
 local leaf,leaf2=P.Leaf,P.Leaf2
 if kind=='blossom'then leaf,leaf2=P.Blossom,P.Blossom2 elseif kind=='ember'then leaf,leaf2={200,72,40},{246,140,52}end
 vcyl(f,'Tree trunk',1.9*s,y,y+9*s,x,z,P.Wood,Mat.Wood)
 local crown=ball(f,'Tree crown',11*s,V(x,y+12.5*s,z),leaf,Mat.Grass)
 ball(f,'Tree crown',8*s,V(x+3.6*s,y+10.6*s,z+1.4*s),leaf2,Mat.Grass)
 ball(f,'Tree crown',7*s,V(x-2.4*s,y+16*s,z-1.2*s),leaf2,Mat.Grass)
 if kind=='apple'then for a=0,2 do local ang=a*2.1;ball(f,'Apple',1.4*s,V(x+math.cos(ang)*5.6*s,y+12*s+(a%2)*1.4,z+math.sin(ang)*5.6*s),{226,52,52})end end
 if kind=='blossom'then
  local pe=Instance.new('ParticleEmitter');pe.Name='Falling petals';pe.Rate=2;pe.Lifetime=NumberRange.new(5,7);pe.Speed=NumberRange.new(.4,.9)
  pe.Acceleration=V(0,-.6,0);pe.Color=ColorSequence.new(RGB(255,196,220));pe.Size=NumberSequence.new(.35);pe.LightEmission=.1
  pe.Parent=crown
 end
end
local function flowerBed(f,x,z,r,colours)
 vcyl(f,'Bed rim',r*2+1,FLOOR-.1,FLOOR+1.1,x,z,P.Cream,Mat.SmoothPlastic)
 vcyl(f,'Bed soil',r*2,FLOOR+1.1,FLOOR+1.3,x,z,P.Soil,Mat.Ground)
 local n=math.max(4,math.floor(r*1.1))
 for k=1,n do local a=k/n*math.pi*2;local rr=(k%2==0)and r*.55 or r*.2
  ball(f,'Flower',1.4,V(x+math.cos(a)*rr,FLOOR+1.9,z+math.sin(a)*rr),colours[(k-1)%#colours+1])
 end
end
local function lamp(f,x,z,lit)
 vcyl(f,'Lamp base',1.8,FLOOR,FLOOR+1.4,x,z,P.Metal,Mat.Metal)
 vcyl(f,'Lamp pole',.7,FLOOR+1.4,FLOOR+12,x,z,P.Metal,Mat.Metal)
 local bulb=part(f,'Lamp lantern',V(1.6,2,1.6),CF(x,FLOOR+13,z),{255,222,150},Mat.Neon,{shadow=false})
 part(f,'Lamp cap',V(2.4,.5,2.4),CF(x,FLOOR+14.25,z),P.Metal,Mat.Metal)
 if lit then local l=Instance.new('PointLight');l.Name='R151LampLight';l.Color=RGB(255,214,150);l.Range=22;l.Brightness=1.4;l.Shadows=false;l.Enabled=false;l.Parent=bulb end
 return bulb
end
local function bench(f,x,z,yaw)
 local c=CF(x,FLOOR,z)*CFrame.Angles(0,yaw,0)
 part(f,'Bench seat',V(6,.5,2),c*CF(0,2,0),P.Wood,Mat.WoodPlanks)
 part(f,'Bench back',V(6,1.8,.4),c*CF(0,3.3,.9)*CFrame.Angles(math.rad(-10),0,0),P.Wood,Mat.WoodPlanks)
 for _,sx in ipairs({-1,1})do part(f,'Bench leg',V(.5,1.8,1.7),c*CF(sx*2.5,.9,.05),P.Metal,Mat.Metal)end
end
local function signpost(f,x,z,boards)
 vcyl(f,'Signpost pole',.9,FLOOR,FLOOR+15,x,z,P.WoodDark,Mat.Wood)
 ball(f,'Signpost cap',1.6,V(x,FLOOR+15.4,z),P.Gold)
 for i,b in ipairs(boards)do
  local yaw=b.Yaw;local y=FLOOR+13.4-(i-1)*2.4
  local board=part(f,'Sign board',V(9,1.9,.4),CF(x,y,z)*CFrame.Angles(0,yaw,0)*CF(4.6,0,0),b.Color or P.Cream,Mat.SmoothPlastic)
  label(board,Enum.NormalId.Front,b.Text,{ink=b.Ink or{60,40,30},stroke={255,255,255},strokeT=.6,pps=30})
  label(board,Enum.NormalId.Back,b.Back or b.Text,{ink=b.Ink or{60,40,30},stroke={255,255,255},strokeT=.6,pps=30})
 end
end
local function bunting(f,a,b,colours)
 rod(f,'Bunting line',a,b,.15,{250,250,250})
 local n=math.floor((b-a).Magnitude/4.2)
 for k=1,n-1 do local t=k/n;local p=a:Lerp(b,t)-V(0,math.sin(t*math.pi)*2.2,0)
  local dir=(b-a).Unit;local side=V(0,1,0):Cross(dir).Unit
  wedge(f,'Pennant',V(.12,1.8,1.8),CFrame.fromMatrix(p,-side,V(0,1,0))*CFrame.Angles(math.rad(45),0,0),colours[(k-1)%#colours+1],Mat.Fabric,{shadow=false})
 end
end
local function butterfly(f,x,y,z,color,yaw)
 local c=CF(x,y,z)*CFrame.Angles(0,yaw,0)
 part(f,'Butterfly wing',V(1.1,.06,.9),c*CF(-.5,.2,0)*CFrame.Angles(0,0,math.rad(35)),color,Mat.SmoothPlastic,{shadow=false})
 part(f,'Butterfly wing',V(1.1,.06,.9),c*CF(.5,.2,0)*CFrame.Angles(0,0,math.rad(-35)),color,Mat.SmoothPlastic,{shadow=false})
end
local function fountain(f,x,z)
 local y=4.26
 vcyl(f,'Fountain wall',22,y-.3,y+2.4,x,z,P.Plaster,Mat.Plaster)
 vcyl(f,'Fountain rim',23,y+2.4,y+2.9,x,z,P.Gold)
 vcyl(f,'Fountain water',20.4,y+2.9,y+3.0,x,z,P.Water,Mat.Glass,{t=.15})
 vcyl(f,'Fountain column',3.2,y+3.0,y+8.6,x,z,P.Pilaster,Mat.Plaster)
 vcyl(f,'Fountain bowl',10,y+8.6,y+10.2,x,z,P.Plaster,Mat.Plaster)
 vcyl(f,'Fountain bowl rim',10.8,y+10.2,y+10.6,x,z,P.Gold)
 vcyl(f,'Fountain bowl water',9.2,y+10.6,y+10.7,x,z,P.Water,Mat.Glass,{t=.15})
 vcyl(f,'Fountain jet',1.2,y+10.7,y+15.4,x,z,{200,236,255},Mat.Glass,{t=.35})
 -- a giant seed pack balancing on the jet (Phase 2: SeedPackVisuals.Bag of today's best pack, turning slowly; stand-in here)
 local pack=part(f,'Seed pack (stand-in)',V(5.2,6.6,1.8),CF(x,y+19,z)*CFrame.Angles(0,math.rad(25),math.rad(-8)),{120,92,214},Mat.SmoothPlastic)
 label(pack,Enum.NormalId.Front,{'🌱','SEED','PACK'},{weights={.4,.3,.3},ink={255,240,190},pps=30})
 local pe=Instance.new('ParticleEmitter');pe.Name='Splash';pe.Rate=6;pe.Lifetime=NumberRange.new(1,1.6);pe.Speed=NumberRange.new(2,4);pe.Color=ColorSequence.new(RGB(220,244,255));pe.Parent=pack
 for a=0,3 do local ang=a*math.pi/2+math.pi/4
  vcyl(f,'Fountain spout',1.2,y+2.9,y+4.6,x+math.cos(ang)*8.4,z+math.sin(ang)*8.4,P.Gold)
 end
end
local function verges(f,map)
 for _,base in ipairs(map.Bases:GetChildren())do local i=base:GetAttribute('BaseIndex');local pad=base:FindFirstChild('Pad')
  if i and pad then
   local col=baseColour(base);local top=pad.CFrame*CF(0,pad.Size.Y/2,0)
   for _,sx in ipairs({1})do -- (the left side is the reserved trophy-shelf slot)
    local cx=sx*37.5;local cz=pad.Size.Z/2+.3+.95
    part(f,'Verge rim',V(29,1.0,1.9),top*CF(cx,-1+.5-.02,cz),P.Cream)
    part(f,'Verge soil',V(28,.2,1.5),top*CF(cx,-1+1.08,cz),P.Soil,Mat.Ground)
    for k=0,5 do local fx=cx-11.8+k*4.72
     ball(f,'Verge flower',1.3,(top*CF(fx,-1+1.7,cz)).Position,({col,{255,255,255},{255,214,80}})[k%3+1])
    end
   end
  end
 end
end
local function slots(f,map)
 -- see-through ghosts of the reserved future slots (only when opts.Slots): trophy shelf at each base, the gate towers' boards
 for _,base in ipairs(map.Bases:GetChildren())do local i=base:GetAttribute('BaseIndex');local pad=base:FindFirstChild('Pad')
  if i and pad then
   local top=pad.CFrame*CF(0,pad.Size.Y/2,0)
   local shelf=part(f,'SLOT trophy shelf',V(16,5,2.6),top*CF(-37.5,-1+2.5,pad.Size.Z/2+1.6),{255,255,255},Mat.SmoothPlastic,{t=.55,shadow=false})
   label(shelf,Enum.NormalId.Back,{'FUTURE SLOT','trophy shelf'},{ink={60,60,80},stroke={255,255,255},strokeT=.5,pps=20})
  end
 end
 for _,sx in ipairs({-1,1})do
  local board=part(f,'SLOT gate board',V(10,14,.6),CF(sx*M.Gate.TowerX,23.5,M.Gate.TowerZ-8.4),{255,255,255},Mat.SmoothPlastic,{t=.5,shadow=false})
  label(board,Enum.NormalId.Front,sx>0 and{'FUTURE SLOT','event clock'}or{'FUTURE SLOT','live track board'},{ink={60,60,80},stroke={255,255,255},strokeT=.5,pps=20})
 end
end
local function skyline(f)
 -- owner option (low wall): far biome silhouettes beyond the walls, in track order round the hub; client-only, no collision
 local K,CZ=1.35,-361 -- distances from the hub centre are scaled out by K
 local function far(x,z)return x*K,CZ+(z-CZ)*K end
 local function hill(x,z,d,h,col,mat)x,z=far(x,z);local p=ball(f,'Skyline',d,V(x,FLOOR-d/2+h,z),col,mat,{shadow=false});return p end
 local function peak(x,z,w,h,col,cap)
  x,z=far(x,z)
  for _,ax in ipairs({0,math.pi/2})do
   local cf=CF(x,FLOOR+h/2-6,z)*CFrame.Angles(0,ax,0)
   wedge(f,'Skyline',V(w,h,w/2),cf*CF(0,0,-w/4),col,Mat.Slate,{shadow=false})
   wedge(f,'Skyline',V(w,h,w/2),cf*CF(0,0,w/4)*CFrame.Angles(0,math.pi,0),col,Mat.Slate,{shadow=false})
  end
  if cap then ball(f,'Skyline',w*.32,V(x,FLOOR+h-6-w*.08,z),cap,Mat.Snow,{shadow=false})end
 end
 hill(300,60,160,70,{88,170,80},Mat.Grass);hill(430,-80,190,80,{76,150,70},Mat.Grass)                           -- Forest
 hill(520,-300,200,95,{50,120,60},Mat.Grass);hill(470,-180,120,70,{44,146,100},Mat.Grass)                         -- Jungle
 peak(520,-520,150,90,{222,184,110},nil);hill(450,-640,220,46,{236,204,140},Mat.Sand)                            -- Desert
 peak(0,-800,190,140,{132,160,190},{250,252,255});peak(-150,-760,140,110,{120,150,182},{250,252,255});peak(160,-760,130,100,{140,168,196},{250,252,255}) -- Snow
 peak(-470,-640,180,110,{70,60,70},nil);ball(f,'Skyline',30,V(-470*K,FLOOR+100,CZ+(-640-CZ)*K),{255,120,40},Mat.Neon,{shadow=false})                     -- Lava
 for k=0,3 do part(f,'Skyline',V(18,90+k*20,18),CF((-500+k*28)*K,FLOOR+20+k*10,CZ+(-340+k*30-CZ)*K)*CFrame.Angles(0,k,math.rad(8-k*5)),({{150,108,208},{204,178,237},{118,80,170},{222,156,226}})[k+1],Mat.Glass,{shadow=false})end -- Crystal
 peak(-420,-60,160,120,{70,80,104},nil);for k=0,3 do ball(f,'Skyline',50,V((-430+k*30)*K,FLOOR+120+(k%2)*10,CZ+(-60+k*8-CZ)*K),{120,128,150},Mat.SmoothPlastic,{shadow=false})end -- Storm
end
function M.BuildClient(map,opts)
 opts=opts or{}
 local root=workspace:FindFirstChild('R151HubDressing')or Instance.new('Folder');root.Name='R151HubDressing';root.Parent=workspace
 local f=folder(root,'Life',2)
 -- trees: avenue / welcome lawns / market / fountain / corners; themed gardens in the alleys (Desert: palms + cacti, Lava: ember trees)
 -- and the back lane (Snow: pines)
 for _,sx in ipairs({-1,1})do
  tree(f,sx*28,-190,'blossom');tree(f,sx*24,-220,'round',.9);tree(f,sx*96,-182,'round',1.1);tree(f,sx*60,-224,'apple',.9);tree(f,sx*96,-226,'round')
  tree(f,sx*84,-250,'apple');tree(f,sx*84,-300,'round',1.05);tree(f,sx*62,-330,'blossom',.95);tree(f,sx*92,-372,'round',1.1);tree(f,sx*40,-392,'round',.85)
  tree(f,sx*138,-132,'round',1.2);tree(f,sx*100,-142,'blossom',.8)
 end
 for _,p in ipairs({{170,-252},{220,-286},{262,-252},{300,-286},{196,-286},{240,-252}})do tree(f,p[1],p[2],(p[1]//1)%3==0 and'cactus'or'palm')end -- Desert garden (+X)
 for _,p in ipairs({{-170,-252},{-220,-286},{-262,-252},{-300,-286}})do tree(f,p[1],p[2],'ember',.9)end                          -- Lava garden (-X)
 for _,p in ipairs({{-195,-286},{-245,-252}})do ball(f,'Ember rock',4,V(p[1],FLOOR+1,p[2]),{66,56,66},Mat.Basalt);ball(f,'Ember glow',1.6,V(p[1]+1.2,FLOOR+2.6,p[2]),{255,140,40},Mat.Neon)end
 for _,z in ipairs({-470,-530})do tree(f,-8.7,z,'pine',.55);tree(f,8.7,z-30,'pine',.55)end                                      -- Snow lane
 -- flower beds
 local warm={{255,96,120},{255,214,80},{255,255,255},{255,150,60}};local cool={{170,120,255},{120,200,255},{255,255,255},{255,170,220}}
 for _,sx in ipairs({-1,1})do
  flowerBed(f,sx*60,-196,5.5,sx>0 and warm or cool);flowerBed(f,sx*36,-250,3.5,warm);flowerBed(f,sx*36,-300,3.5,cool)
  flowerBed(f,sx*118,-159,4,warm);flowerBed(f,sx*118,-411,4,cool)
  flowerBed(f,sx*312,-269,4,sx>0 and{{255,200,90},{255,120,60},{255,255,255}}or{{255,90,40},{255,170,40},{120,30,30}})
 end
 flowerBed(f,0,-596,3.5,{{200,230,255},{255,255,255},{150,190,255}})
 -- lamp posts along the streets (8 of them get a PointLight that the client turns on in the dark: The Darkened, storms, a future night)
 local lit=0
 for _,sx in ipairs({-1,1})do
  for _,z in ipairs({-190,-240,-290,-340,-390})do lamp(f,sx*106,z,(z==-240 or z==-340))end
  for _,z in ipairs({-200,-228})do lamp(f,sx*15.4,z,z==-200)end
  lamp(f,sx*55,-236,true);lamp(f,sx*55,-308)
  lamp(f,sx*30,-400);lamp(f,sx*140,-257)
 end
 -- bunting: across the avenue and from the market square's lamps to the market's eaves
 local bright={{255,96,96},{255,206,72},{96,200,120},{90,170,255},{190,120,255}}
 bunting(f,V(-15.4,FLOOR+13.4,-200),V(15.4,FLOOR+13.4,-228),bright);bunting(f,V(15.4,FLOOR+13.4,-200),V(-15.4,FLOOR+13.4,-228),bright)
 for _,sx in ipairs({-1,1})do bunting(f,V(sx*55,FLOOR+13.4,-236),V(sx*22,23,-250),bright);bunting(f,V(sx*55,FLOOR+13.4,-308),V(sx*22,23,-287),bright)end
 -- benches
 for a=0,3 do local ang=a*math.pi/2+math.pi/4;local r=17.5
  bench(f,math.cos(ang)*r,-392+math.sin(ang)*r,math.atan2(math.cos(ang),math.sin(ang)))
 end
 for _,sx in ipairs({-1,1})do bench(f,sx*306,-258,0);bench(f,sx*306,-280,math.pi);bench(f,sx*75,-200,sx*math.pi/2);bench(f,sx*44,-275,sx*math.pi/2)end
 bench(f,0,-588,math.pi)
 -- signposts (Phase 2: the base boards show the owners' names on each player's screen)
 local function own(i)local b=map.Bases:FindFirstChild('Base_'..i);local n=b and b:GetAttribute('BaseOwnerDisplayName');return(n and n~='')and n or('Base '..i)end
 signpost(f,19,-171,{{Yaw=math.rad(-90),Text='THE TRACK',Color={255,236,180}},{Yaw=math.rad(90),Text='MARKET',Color={190,236,226}},
  {Yaw=math.pi,Text=own(1)..' · '..own(3),Color={255,214,214}},{Yaw=0,Text=own(2)..' · '..own(4),Color={214,226,255}}})
 signpost(f,-34,-372,{{Yaw=math.rad(-90),Text='THE TRACK',Color={255,236,180}},{Yaw=math.rad(90),Text='SEED FOUNTAIN',Color={200,236,255}},
  {Yaw=math.pi,Text=own(5),Color={214,255,226}},{Yaw=0,Text=own(6),Color={255,226,200}}})
 fountain(f,0,-392)
 verges(f,map)
 -- wall lanterns on the pilasters either side of every mural (they glow in the dark)
 local top=wallTop(opts)
 for _,m in ipairs(MURALS)do local sec=SECTIONS[m.Sec];local s=sOf(sec,m.W)
  for _,ds in ipairs({-28.5,28.5})do
   part(f,'Wall lantern bracket',V(.6,.6,1.8),secFrame(sec,s+ds,top-24+2.0,2.7),P.Metal,Mat.Metal)
   part(f,'Wall lantern',V(1.6,2.4,1.6),secFrame(sec,s+ds,top-24,3.4),{255,214,140},Mat.Neon,{shadow=false})
   part(f,'Wall lantern cap',V(2.2,.5,2.2),secFrame(sec,s+ds,top-24+1.45,3.4),P.Metal,Mat.Metal)
  end
 end
 -- butterflies near the flower beds (animated on the client: flutter + slow drift; 12 at most, hidden past 120 studs)
 local wings={{255,140,60},{255,230,90},{120,200,255},{240,130,230},{255,255,255}}
 for k,p in ipairs({{60,8,-196},{-60,9,-198},{36,7,-252},{-36,8,-300},{118,8,-161},{-118,7,-409},{0,9,-380},{20,10,-372},{312,8,-266},{-312,8,-272},{0,7,-592},{90,9,-240}})do
  butterfly(f,p[1],p[2],p[3],wings[(k-1)%#wings+1],k)
 end
 -- the gate keys on this player's screen: green with a tick once you are faster than that biome's keeper (KeeperSpeedLabels' rule)
 local me=opts.Player;local mine=me and tonumber(me:GetAttribute('PhysicalWalkSpeed'))
 local gate=root:FindFirstChild('Gate')
 if mine and gate then for _,k in ipairs(gate:GetChildren())do local st=k:GetAttribute('R151Stage')
  if st then local ok,esc=pcall(function()return require(RS:WaitForChild('KeeperPursuit')).EscapeSpeed(st)end)
   local gui=k:FindFirstChild('R151Text');local line=gui and gui:FindFirstChild('Line3')
   if ok and line and mine>esc then line.Text='✓ '..line.Text:gsub('^⚡ ','');line.TextColor3=RGB(110,236,96)end
  end
 end end
 if opts.Slots then slots(folder(root,'Slots',3),map)end
 if opts.Wall=='low'then skyline(folder(root,'Skyline',3))end
 return f
end
return M
