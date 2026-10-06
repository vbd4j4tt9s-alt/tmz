-- R151 Seed Festival Square, server half (owner approved docs/proposals/R151/base_area.md; "As built" there; R152 docs/proposals/R152/hub.md
-- took the fountain, murals, banners, base arches, corner towers, hedge and topiary out and rebuilt the gate). Built once at start-up by
-- MapService (after MarketLayout), into Workspace.ChestChaseMap.HubDecor151:
--   Walls          the five saved wall parts keep their size, position and collision; they are recoloured (cream plaster) and dressed with a
--                  stone plinth, a gold string course and pilasters, all flush BELOW the wall top (51), and crowned with a chess-rook
--                  battlement: 218 square merlons (K.MerlonSpots), evenly spaced, one on each outer corner; nothing else stands above the
--                  top. (The saved wood caps, 51 - 52, are hidden, like the timber strips.)
--   Gate           the track gate: two chess-rook towers on the wall ends (stepped round base, tapering shaft, gold ring, collar, flared crown
--                  with 8 merlons; their shafts are the ONLY new parts that collide) and a crenellated gatehouse wall between them with a
--                  raised keep carrying the sign, one big key per biome (each client ticks the keys it is fast enough for) hanging in front.
--   Paths          paved streets, squares and plazas joining spawn, market, every base, the gate and the side gardens; base-coloured curbs.
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
 -- the thin timber strips are replaced by the pilasters; the 1-stud wood caps (51 - 52) would hide the merlons' feet: hidden
 if design then for _,d in ipairs(design:GetChildren())do if d:IsA('BasePart')and(d.Name:find('TimberPier')or d.Name:find('^Lobby.*Cap$'))then d.Transparency=1 end end end
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
  -- pilasters end .8 under the wall top (their stone caps .1 under it), flush below the battlement
  for _,w in ipairs(K.Pilasters[name]or{})do
   local s=K.SOf(sec,w)
   K.Part(f,'Pilaster',V(7,TOP-.8-FLOOR,2.4),K.SecFrame(sec,s,(FLOOR+TOP-.8)/2,.8),P.Pilaster,Mat.Plaster)
   K.Part(f,'Pilaster base',V(8,2.2,3),K.SecFrame(sec,s,FLOOR+1.1,1.1),P.StoneDark,Mat.Slate)
   K.Part(f,'Pilaster cap',V(8.4,1.2,3.2),K.SecFrame(sec,s,TOP-.7,1.2),P.Stone,Mat.Cobblestone)
  end
 end
 -- the battlement: square merlons on the wall top, flush with both faces (their bottoms rest on the saved top: opposite faces never fight)
 local B=K.Battlement
 for _,m in ipairs(K.MerlonSpots())do
  K.Part(f,'Wall merlon',V(B.Size,B.Height,B.Size),K.SecFrame(K.Sections[m.Sec],m.S,TOP+B.Height/2,-2.5),P.Plaster,Mat.Plaster,{shadow=false})
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
-- R152: the gate is two chess rooks and a castle gatehouse (owner: "the gate of the track has to be a castle like gate like u know a rook in
-- chess that shape"). A rook tower: a wide stepped round base, a round shaft that tapers a little, a gold ring (at the wall's string course),
-- a neck collar, a flared crown and 8 square merlons round its rim. Between the towers: a crenellated wall with a raised keep that carries
-- the sign; the biome keys hang in front of it. Planes: no two same-facing faces share a height (every ring, step and merlon top differs).
local ROOK={ -- heights of the tower's rings (floor top 4)
 Base={{17.4,3.4,7.4,'Stone'},{16.2,7.4,10.4,'StoneDark'},{15.2,10.4,12.6,'Stone'}},Ring=33.6,Step=34.2,Shaft=58,Collar={15.4,58,60.4},Flare={16.4,60.4,62.6},Crown={17.4,62.6,68.4},
 MerlonH=5.4,
}
local function buildRook(f,x,z,G)
 local mat={Stone=Mat.Cobblestone,StoneDark=Mat.Slate}
 for i,b in ipairs(ROOK.Base)do K.VCyl(f,'Gate base '..i,b[1],b[2],b[3],x,z,P[b[4]],mat[b[4]])end
 -- the shaft: two stacked cylinders (the tower's collision; its lower inner edge is x = 91.8), the step hidden under the gold ring
 K.VCyl(f,'Gate tower',G.TowerD,3.2,ROOK.Step,x,z,P.Plaster,Mat.Plaster,{collide=true})
 K.VCyl(f,'Gate tower',G.TowerD-1.4,ROOK.Step,ROOK.Shaft,x,z,P.Plaster,Mat.Plaster,{collide=true})
 K.VCyl(f,'Gate tower ring',G.TowerD+.8,ROOK.Ring,TOP-16.2,x,z,P.Gold) -- (TOP - 16.2 = the walls' string course top)
 -- two arrow slits on the hub side, standing .3 proud of the shaft
 for _,y in ipairs({{17.5,24.5},{27,33}})do K.Part(f,'Gate slit',V(1.1,y[2]-y[1],.8),CF(x,(y[1]+y[2])/2,z-G.TowerD/2+.1-.05),P.Ink,Mat.SmoothPlastic,{shadow=false})end
 for _,r in ipairs({'Collar','Flare','Crown'})do
  local c=ROOK[r];K.VCyl(f,'Gate '..string.lower(r),c[1],c[2],c[3],x,z,r=='Crown'and P.Pilaster or r=='Collar'and P.Stone or P.StoneDark,r=='Flare'and Mat.Slate or r=='Collar'and Mat.Cobblestone or Mat.Plaster)
 end
 -- 8 merlons on the crown's rim (two gaps face the hub and the track, so the silhouette is the classic rook from either side)
 local top=ROOK.Crown[3]
 for k=0,7 do
  local a=(k+.5)*math.pi/4;local out=V(math.cos(a),0,math.sin(a));local at=V(x,top+ROOK.MerlonH/2,z)+out*6.6
  K.Part(f,'Gate merlon',V(3.4,ROOK.MerlonH,3.4),CFrame.lookAt(at,at+out),P.Plaster,Mat.Plaster) -- (square, outer corners inside the rim)
 end
end
local function buildGate(root)
 local f=K.Model(root,'Gate',true)
 local G=K.Gate;local zc=G.TowerZ
 for _,sx in ipairs({-1,1})do
  buildRook(f,sx*G.TowerX,zc,G)
  -- the haunch: an upside-down wedge from the tower under the wall (its tall side against the tower) gives the opening its pointed shoulders
  K.Wedge(f,'Gate haunch',V(9,12,32),K.Frame(V(sx*78,G.BeamY0-6,zc),V(0,-1,0),V(sx,0,0)),P.Plaster,Mat.Plaster)
 end
 -- the gatehouse: a wall between the rooks (its ends inside the shafts), a gold course under it, a stone cornice over it, merlons along the top
 -- and a raised keep in the middle with the sign and five merlons of its own
 local top=G.BeamY1+1.3 -- the cornice's top (57.7 - 59.3: it clears the shafts' top, 58, and the keys' tops, 57.5)
 K.Part(f,'Gatehouse wall',V(191,G.BeamY1-G.BeamY0,9),CF(0,(G.BeamY0+G.BeamY1)/2,zc),P.Plaster,Mat.Plaster)
 K.Part(f,'Gatehouse trim',V(190,1.2,10),CF(0,G.BeamY0+.2,zc),P.Gold)
 K.Part(f,'Gatehouse cornice',V(192,1.6,11),CF(0,G.BeamY1+.5,zc),P.Stone,Mat.Cobblestone)
 local B=K.Battlement -- (the wall's merlon size and 10-stud rhythm; the merlons span the wall they stand on)
 for k=3,8 do for _,sx in ipairs({-1,1})do K.Part(f,'Gatehouse merlon',V(B.Size,B.Height,9),CF(sx*(k*10+5),top+B.Height/2,zc),P.Plaster,Mat.Plaster)end end
 local keepH=8;local keepY=top+keepH/2
 K.Part(f,'Gatehouse keep',V(52,keepH,7),CF(0,keepY,zc),P.Plaster,Mat.Plaster)
 for k=-2,2 do K.Part(f,'Gatehouse keep merlon',V(B.Size,B.Height,7),CF(k*10,top+keepH+B.Height/2,zc),P.Plaster,Mat.Plaster)end
 local sy=keepY
 local sign=K.Part(f,'Gate sign',V(46,5,.8),CF(0,sy,zc-3.5-.9-.4),{62,44,34},Mat.Wood)
 K.Part(f,'Gate sign frame',V(49,6.4,.9),CF(0,sy,zc-3.5-.45),P.Gold)
 K.Label(sign,Enum.NormalId.Front,'THE TRACK',{ink={255,236,180},pps=24})
 for i,b in ipairs(K.Biomes)do
  local x=G.KeyX[i];local need,escape=M.SpeedNeed(b.Stage)
  local k=K.Keycap(f,'Biome key '..i,V(15,3.6,15),CFrame.fromMatrix(V(x,G.KeyY,zc-6.1),V(-1,0,0),V(0,0,-1),V(0,-1,0)),b.Key,
   {b.Emoji,b.Name,'⚡ '..need},{name='KeyLegend',weights={.42,.24,.34},ink={255,255,255},stroke=b.Ink,strokeT=.1,pps=20})
  k:SetAttribute('R151Stage',b.Stage);k:SetAttribute('R151Need',need);k:SetAttribute('R151EscapeSpeed',escape)
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
  curb(f,sx*21,sx*106,-404,-403.4)                           -- south street, north edge (the open plaza in the middle)
  for _,seg in ipairs({{-196.2,-262},{-276,-342.3},{-373.7,-399}})do curb(f,sx*127,sx*127.6,seg[1],seg[2])end -- side street, outer edge between spurs
  for _,seg in ipairs({{106,89.6},{58.4,6.6}})do curb(f,sx*seg[1],sx*seg[2],-418.6,-418)end -- south street, south edge between spurs and lane
 end
 slab(f,'South street',-127,127,-404,-418,4.20,P.Street)
 slab(f,'Avenue',-12,12,-166,-232,4.20,P.Street)
 curb(f,-12.6,-12,-166.6,-232);curb(f,12,12.6,-166.6,-232)
 slab(f,'Market square',-52,52,-232,-312,4.20,P.Brick,Mat.Brick)
 disc(f,'Stage circle',0,-340,30,4.14,P.Street,Mat.Cobblestone)
 disc(f,'South plaza',0,-392,21,4.26,P.Brick,Mat.Brick) -- (R152: an open square, the fountain is gone)
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

function M.Apply(map)
 assert(map,'HubDecor151: no map')
 local old=map:FindFirstChild(K.FolderName);if old then old:Destroy()end
 local made0=K.Made
 local root=Instance.new('Folder');root.Name=K.FolderName;root:SetAttribute('Version',M.Version)
 restyleWalls(map)
 local bases=basesByIndex(map)
 -- what the client needs about the bases (their pads may be streamed out on a far client)
 for i,b in pairs(bases)do
  root:SetAttribute('Pad'..i,b.Pad.CFrame);root:SetAttribute('PadSize'..i,b.Pad.Size);root:SetAttribute('Color'..i,baseColour(b.Model))
 end
 buildWalls(root);buildGate(root);buildPaths(root,bases)
 root:SetAttribute('Parts',K.Made-made0)
 root.Parent=map
 -- R153: the trampolines in the two garden nooks (their own folder; HubTrampoline153 builds the collision and the look)
 do local ok,err=pcall(function()require(script.Parent.HubTrampoline153).Build(map)end);if not ok then warn('[R153] Trampolines skipped: '..tostring(err))end end
 -- the owner's studded tree models (loaded once per server; the clients use them as tree templates)
 task.spawn(function()local ok,err=pcall(function()require(script.Parent.HubTreeLoader151).Run()end);if not ok then warn('[R151 trees] '..tostring(err))end end)
 return root
end
return M
