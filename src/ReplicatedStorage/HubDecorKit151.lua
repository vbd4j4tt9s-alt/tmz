-- R151 Seed Festival Square (owner approved the docs/proposals/R151/base_area.md design): the shared kit of the hub dressing.
-- Palette, biome list, the measured hub geometry (the saved walls' inner faces, pilaster / lantern spots, the track gate, the reserved
-- back corners), small part constructors and a deterministic random source. Used by the server (ChestChaseServer.HubDecor151: walls,
-- rook gate, paths) and the client (HubLifeArt151 + HubLife151.client: trees and props). R152: no murals, banners or base arches. Pure: builds only what it
-- is asked to, never touches gameplay; every part it makes is Anchored with CanTouch / CanQuery off and CanCollide off unless asked.
local RS=game:GetService('ReplicatedStorage')
local K={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Mat=Enum.Material
K.Version=151
K.Floor=4 -- top of Workspace.ChestChaseMap.Lobby.LobbyFloor
K.FolderName='HubDecor151'

K.P={
 Plaster={243,231,206},Pilaster={229,210,172},Stone={178,166,147},StoneDark={150,138,120},Gold={244,196,86},GoldDeep={214,160,58},
 Hedge={86,162,74},HedgeDark={66,138,62},RoofRed={230,96,84},RoofTeal={52,168,160},Wood={150,104,64},WoodDark={104,72,46},
 Cream={252,244,226},Street={222,206,172},Brick={214,142,110},Metal={44,84,76},Soil={104,74,52},Water={120,200,236},Ink={58,40,30},
}
-- Track order. Stage ids are the game's (Forest 1, Jungle 6, Desert 2, Snow 3, Lava 4, Crystal 5, Storm Peaks 7); colours from
-- KeyboardTrack's palettes so the gate keys match the track's keys.
K.Biomes={
 {Stage=1,Name='FOREST',Emoji='🌲',Key={96,186,90},Light={164,218,120},Ink={16,48,20}},
 {Stage=6,Name='JUNGLE',Emoji='🌴',Key={44,146,100},Light={150,198,72},Ink={14,40,18}},
 {Stage=2,Name='DESERT',Emoji='🌵',Key={228,192,112},Light={244,216,152},Ink={84,50,20}},
 {Stage=3,Name='SNOW',Emoji='❄️',Key={170,208,232},Light={238,244,248},Ink={40,72,104}},
 {Stage=4,Name='LAVA',Emoji='🌋',Key={236,108,34},Light={198,58,26},Ink={54,14,8}},
 {Stage=5,Name='CRYSTAL',Emoji='💎',Key={150,108,208},Light={222,156,226},Ink={46,22,78}},
 {Stage=7,Name='STORM PEAKS',Emoji='⚡',Key={108,118,156},Light={130,122,178},Ink={18,20,34}},
}
function K.C(t)return typeof(t)=='Color3'and t or RGB(t[1],t[2],t[3])end

-- Hub geometry (measured from the owner's place, 4 Oct). The inner faces of the five saved wall parts: s runs along the face to the
-- viewer's right (seen from inside), d is the distance out of the face into the hub; the local frame is X = t, Y = up, Z = n.
K.Sections={
 FrontXNeg={o=V(-94,0,-104),t=V(-1,0,0),n=V(0,0,-1),len=241},
 FrontXPos={o=V(335,0,-104),t=V(-1,0,0),n=V(0,0,-1),len=241},
 Back={o=V(-335,0,-618),t=V(1,0,0),n=V(0,0,1),len=670},
 SideXNeg={o=V(-335,0,-104),t=V(0,0,-1),n=V(1,0,0),len=514},
 SideXPos={o=V(335,0,-618),t=V(0,0,1),n=V(-1,0,0),len=514},
}
K.SectionOrder={'FrontXNeg','FrontXPos','Back','SideXNeg','SideXPos'}
function K.At(sec,s,y,d)return sec.o+sec.t*s+V(0,y,0)+sec.n*d end
function K.SecFrame(sec,s,y,d)return CFrame.fromMatrix(K.At(sec,s,y,d),sec.t,V(0,1,0),sec.n)end
function K.SOf(sec,w)if sec.t.X~=0 then return(w-sec.o.X)/sec.t.X end;return(w-sec.o.Z)/sec.t.Z end
K.WallTop=51
-- R152: the wall top is a chess-rook battlement: one square merlon (Size x Size, the walls' own 5-stud thickness, flush with both faces) every
-- ~10 studs round the whole top, a merlon on each outer corner (no tower, nothing higher), sitting on WallTop. Pilasters stop under it.
K.Battlement={Size=5,Height=6}
-- Where the merlons stand, as {Sec, S} (S along the section, the centre of the wall's thickness is 2.5 behind its inner face). Each run is evenly
-- spaced between two fixed merlons: the corners (a merlon on each outer corner square) and, on the front walls, x = +-107.5 next to the gate
-- towers: front 23 pitches of 10.0, sides 52 of 9.98, back 67 of 10.07. 218 merlons in all (4 corners, 46 front, 102 side, 66 back).
function K.MerlonSpots()
 local out={}
 local function run(name,s0,s1,n,first,last)
  for i=first,last do out[#out+1]={Sec=name,S=s0+(s1-s0)*i/n,I=i,Run=name}end
 end
 run('FrontXPos',-2.5,227.5,23,0,23);run('FrontXNeg',13.5,243.5,23,0,23)           -- 24 each: the corner (x = +-337.5) .. 107.5
 run('SideXPos',-2.5,516.5,52,1,51);run('SideXNeg',-2.5,516.5,52,1,51)              -- 51 each between the two corners
 run('Back',-2.5,672.5,67,0,67)                                                   -- 68: both back corners and the 66 between them
 return out
end
K.Pilasters={
 FrontXNeg={-131.5,-188.5,-233.5,-290.5},FrontXPos={131.5,188.5,233.5,290.5},
 Back={-300,-240,-180,-120,-28.5,28.5,120,180,240,300},
 SideXNeg={-140,-214,-240.5,-297.5,-322,-394,-460,-530,-590},SideXPos={-140,-214,-240.5,-297.5,-322,-394,-460,-530,-590},
}
-- The track gate (R152: two chess-rook towers and a crenellated gatehouse). TowerD is the colliding shaft's lower diameter (its inner edge,
-- 91.8, stays outside the 180-wide run-up); the stepped base reaches 17.4 (inner edge 90.3, as the R151 plinth did). The gatehouse wall runs
-- BeamY0 .. BeamY1 between the towers; the keys hang over the opening in front of it.
-- R153: KeySize is a key's width and height (a key hangs from KeyY + KeySize / 2 down to KeyY - KeySize / 2 = 42.5); the track's refresh barrier (ReplicatedStorage.RefreshBarrier) fills the opening under it.
-- R153: the haunches (the pointed shoulders under the gatehouse at both ends): a wedge HaunchRise tall and HaunchRun wide, its tall side against the tower at |x| = HaunchOuter,
-- its slope running from (HaunchOuter, BeamY0 - HaunchRise) up to (HaunchOuter - HaunchRun, BeamY0); the refresh barrier's wings follow that slope.
K.Gate={TowerX=99,TowerZ=-100,TowerD=14.4,BeamY0=44,BeamY1=58,KeyY=50,KeySize=15,HaunchRise=12,HaunchRun=32,HaunchOuter=94,KeyX={72,48,24,0,-24,-48,-72}}
-- The 14 wall lanterns (client): on the pilasters, 28.5 either side of the old mural spots.
K.WallLanterns={
 {Sec='FrontXPos',W=131.5},{Sec='FrontXPos',W=188.5},{Sec='FrontXPos',W=233.5},{Sec='FrontXPos',W=290.5},
 {Sec='FrontXNeg',W=-131.5},{Sec='FrontXNeg',W=-188.5},{Sec='FrontXNeg',W=-233.5},{Sec='FrontXNeg',W=-290.5},
 {Sec='SideXPos',W=-240.5},{Sec='SideXPos',W=-297.5},{Sec='SideXNeg',W=-240.5},{Sec='SideXNeg',W=-297.5},{Sec='Back',W=-28.5},{Sec='Back',W=28.5},
}
-- The two back corners are reserved for the R151 Best Pull / Biggest Fruit displays: nothing of the dressing may stand in them.
K.Reserved={{X0=145,X1=335,Z0=-618,Z1=-420},{X0=-335,X1=-145,Z0=-618,Z1=-420}}
function K.InReserved(x,z,margin)
 margin=margin or 0
 for _,r in ipairs(K.Reserved)do if x>r.X0-margin and x<r.X1+margin and z>r.Z0-margin and z<r.Z1+margin then return true end end
 return false
end
-- Streets (see HubDecor151.Paths): used by the client to keep props off the paving.
K.Streets={
 {-90,90,-100.3,-152},{-127,127,-152,-166},{-127,-109,-166,-404},{109,127,-166,-404},{-127,127,-404,-418},{-12,12,-166,-232},{-52,52,-232,-312},
 {-312,-127,-262,-276},{127,312,-262,-276},{-6,6,-418,-594},
}
-- R152: open circles nothing of the dressing may stand in (x, z, radius): the old fountain spot, the south plaza's centre, where the free Void
-- Pack giveaway pedestal goes. Plain paving only: no trees, benches, lamps, signs or flower beds (HubLifeArt151.Clear refuses it).
K.Open={{0,-392,18},{312,-269,7.5},{-312,-269,7.5}} -- (R153: and the two trampolines in the garden nooks, HubTrampolineRules153.Spots)
K.Discs={{0,-340,30},{0,-392,21},{-118,-159,12},{118,-159,12},{-118,-411,12},{118,-411,12},{-312,-269,13},{312,-269,13},{0,-596,10}}

-- Deterministic randomness: the same seed always gives the same props (every client sees the same square).
function K.Hash(s)local h=2166136261;s=tostring(s);for i=1,#s do h=(h*16777619+s:byte(i))%4294967296 end;return h end
function K.Rng(seed)
 local state=K.Hash(seed)%2147483646+1
 return function(a,b)
  state=state*16807%2147483647;local u=state/2147483647
  if a==nil then return u end;return a+(b-a)*u
 end
end

-- Studded trees (owner: "tress can also use this" / "there are different variations of trees that we can use make sure they are studded"):
-- the Creator Store models the server loads at start (ChestChaseServer.HubTreeLoader151) into ReplicatedStorage.HubTreeTemplates151, where
-- the owner can also drop any tree model by hand. Add more asset ids here; every model in the folder becomes one more variation.
K.TreeAssetIds={16637971059,17280628013} -- "Stud-Tree", "studded-tree"
K.TreeFolder='HubTreeTemplates151'
-- What a template tree may cost (HubStudTrees151.Plan): a clone with more than PerTree parts is not used on that device tier, and all
-- clones together add at most Total parts (the slots are filled in the layout's order: the welcome lawns by the gate first). The part-built
-- tree a clone replaces costs 2 core + about 5 detail parts. Tier 1 = phones on low / FastMode, 2 = phones, 3 = desktop.
K.TreeBudget={PerTree={[1]=6,[2]=16,[3]=40},Total={[1]=90,[2]=300,[3]=600},MaxParts=400,Kinds={oak=true,blossom=true,leafy=true}}

-- Part constructors -----------------------------------------------------------------------------------------------------------------------
K.Made=0
local UPRIGHT=CFrame.Angles(0,0,math.pi/2) -- a Cylinder's axis is its X: this stands it up
-- The classic Roblox stud look, as the place's own track trees have it (Plastic blocks with Studs on top, Inlet underneath): Studs on the
-- face that points up, Inlet on the one that points down, whatever the part's turn (an upright cylinder's top is its Right face).
local FACE_PAIRS={{'RightSurface','LeftSurface'},{'TopSurface','BottomSurface'},{'BackSurface','FrontSurface'}}
function K.Studs(p)
 local c=p.CFrame;local up={c.RightVector.Y,c.UpVector.Y,-c.LookVector.Y}
 local best=1;for i=2,3 do if math.abs(up[i])>math.abs(up[best])then best=i end end
 local top,bottom=FACE_PAIRS[best][1],FACE_PAIRS[best][2];if up[best]<0 then top,bottom=bottom,top end
 for _,pair in ipairs(FACE_PAIRS)do p[pair[1]]=Enum.SurfaceType.Smooth;p[pair[2]]=Enum.SurfaceType.Smooth end
 p[top]=Enum.SurfaceType.Studs;p[bottom]=Enum.SurfaceType.Inlet;p.Material=Mat.Plastic
 return top
end
function K.Part(parent,name,size,cf,color,mat,o)
 o=o or{}
 local p=Instance.new(o.class or'Part')
 p.Name=name;p.Size=size;p.CFrame=cf;p.Color=K.C(color);p.Material=mat or Mat.SmoothPlastic
 p.Anchored=true;p.CanCollide=o.collide==true;p.CanTouch=false;p.CanQuery=false;p.CastShadow=o.shadow~=false
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if o.shape then p.Shape=o.shape end
 if o.t then p.Transparency=o.t end
 if o.studs then K.Studs(p)end
 p.Parent=parent;K.Made+=1
 return p
end
function K.Ball(parent,name,d,pos,color,mat,o)o=o or{};o.shape=Enum.PartType.Ball;return K.Part(parent,name,V(d,d,d),CF(pos),color,mat,o)end
function K.Cyl(parent,name,d,h,cf,color,mat,o)o=o or{};o.shape=Enum.PartType.Cylinder;return K.Part(parent,name,V(h,d,d),cf*UPRIGHT,color,mat,o)end
function K.VCyl(parent,name,d,y0,y1,x,z,color,mat,o)return K.Cyl(parent,name,d,y1-y0,CF(x,(y0+y1)/2,z),color,mat,o)end
function K.Wedge(parent,name,size,cf,color,mat,o)o=o or{};o.class='WedgePart';return K.Part(parent,name,size,cf,color,mat,o)end
-- A CFrame from a position and two axes (X = Y x Z keeps it right-handed).
function K.Frame(pos,y,z)local x=y:Cross(z);return CFrame.fromMatrix(pos,x,y,z)end
-- R153 (owner: "make sure that the forest jungle and so on tiles at the track gate are facing the right direction and upright"): the frame of a gate key at `pos`, its top
-- facing the hub (-Z) with its legend reading left to right and upright for someone standing in the hub looking at the gate (looking +Z, his right is world -X).
-- A part's Top-face SurfaceGui reads along the part's LookVector (canvas x, = local -Z) and runs DOWN along its RightVector (canvas y, = local +X): the frame measured on the
-- owner's screenshots, see KeyboardTrack.TopReading / TopCanvas. So: LookVector = world -X (reading to the viewer's right), RightVector = world -Y (down the canvas is down in the
-- world), UpVector = world -Z (the top faces the hub): fromMatrix(pos, X = right = (0,-1,0), Y = up = (0,0,-1), Z = back = -look = (1,0,0)), right-handed (X x Y = Z).
-- (R152 had X = (-1,0,0), Y = (0,0,-1), Z = (0,-1,0): look = world UP, so the legends read from the bottom to the top, tops to the viewer's left.)
function K.KeyFrame(pos)return CFrame.fromMatrix(pos,V(0,-1,0),V(0,0,-1),V(1,0,0))end
-- A rod (thin cylinder) between two points.
function K.Rod(parent,name,a,b,d,color,mat,o)
 local mid=(a+b)/2;local len=(b-a).Magnitude
 o=o or{};o.shape=Enum.PartType.Cylinder;if o.shadow==nil then o.shadow=false end
 return K.Part(parent,name,V(len,d,d),CFrame.lookAt(mid,b)*CFrame.Angles(0,math.pi/2,0),color,mat,o)
end
-- SurfaceGui text on one face: lines (a string or a list), weights (heights as fractions), inks, stroke.
function K.Label(p,face,text,o)
 o=o or{}
 local gui=Instance.new('SurfaceGui');gui.Name=o.name or'HubText';gui.Face=face;gui.LightInfluence=o.light or 0
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=o.pps or 30
 pcall(function()gui.MaxDistance=o.maxDistance or 400 end) -- (phones: far labels are not drawn)
 gui.Parent=p
 local lines=type(text)=='table'and text or{text}
 local n=#lines;local y=0
 for i,line in ipairs(lines)do
  local h=o.weights and o.weights[i]or 1/n
  local l=Instance.new('TextLabel');l.Name='Line'..i;l.BackgroundTransparency=1
  l.Position=UDim2.fromScale(.04,y+.03);l.Size=UDim2.fromScale(.92,h-.06);y+=h
  l.Font=Enum.Font.FredokaOne;l.TextScaled=true;l.Text=line
  l.TextColor3=K.C(o.inks and o.inks[i]or o.ink or{255,255,255});l.TextStrokeColor3=K.C(o.stroke or{30,24,20});l.TextStrokeTransparency=o.strokeT or .35
  l.Parent=gui
 end
 return gui
end
-- A keycap: the place's R142Keycap mesh (the one the keyboard track uses), legend on its top face; `cf` puts the cap's top (+Y) where it
-- faces. Falls back to a plain part when the mesh is missing.
function K.Keycap(parent,name,size,cf,color,legend,o)
 o=o or{}
 local template=RS:FindFirstChild('R142Keycap')
 local k
 if template and template:IsA('BasePart')then k=template:Clone();for _,c in ipairs(k:GetChildren())do c:Destroy()end else k=Instance.new('Part')end
 k.Name=name;k.Size=size;k.CFrame=cf;k.Color=K.C(color);k.Material=Mat.SmoothPlastic;k.Anchored=true;k.CanCollide=false;k.CanTouch=false;k.CanQuery=false
 k.Parent=parent;K.Made+=1
 if legend then K.Label(k,Enum.NormalId.Top,legend,o)end
 return k
end
function K.Model(parent,name,persistent)
 local m=Instance.new('Model');m.Name=name
 if persistent then m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent end
 m.Parent=parent;return m
end
return K
