-- R158 outer track: WHAT goes outside the track's walls and WHERE (owner: "I will give you asset ids for the pyramids, volcanos and mountains and everything else, don't have to
-- model them yourself, just place the stuff"). Pure data, edited by hand: the asset ids, the list of keys and the spots. OuterTrackLoader158 places the models.
-- The picture: a flat ground outside the walls (TrackWalls158 builds it) and big simple models far outside (|x| >= 100, never over the hub), all anchored, no collision / touch /
-- query, no shadows (A.Shadows), streamed in and out like any part. docs/proposals/R158/design/outer_track_assets.md explains the keys to the owner.
--
-- WHERE A KEY'S MODEL COMES FROM (the first that works; nothing part-built is ever made up):
--   1. hand       a model the owner dragged into ServerStorage.OuterTrackAssets158, named by the key (or Key2, Key3 ... for more looks of the same thing)
--   2. owner      the owner's own file, built into the game (DesertPyramid: the 82-part file as data; StormDarkMount: his 1,532-part mountain cut down to 280 parts; LavaVolcano and
--                 SnowMountains: his meshes, loaded by id with AssetService:CreateMeshPartAsync when the server starts)
--   3. game       a model the game already has (the map's oak, jungle trees, ice trees, crystal clusters, copied from the map; and the hub's own trees, which HubLifeArt151 builds),
--                 scaled up (A.Game)
--   4. id         A.Ids[key] (a Creator Store / inventory model id; 0 = not set), loaded with AssetService:LoadAssetAsync / InsertService:LoadAsset. Roblox only lets a game load models
--                 its owner owns: a model by someone else fails with "not authorized", which is why the dragged-in model (1) comes first.
--   A key with none of these is skipped with one plain note in the Output.
-- A model is scaled evenly until it fits the spot's W x H x D box (W across its front, H up, D deep, before the turn), stood on the ground at X / Z and turned by Yaw degrees.
local A={Version=158}
A.Folder='OuterTrackAssets158' -- ServerStorage.OuterTrackAssets158: the owner's dragged-in models
A.Shadows=false                -- the design: the outer track casts no shadow (true: only parts 20+ studs long cast one)
A.Ground=3.6                   -- the outer ground's top (TrackWallSpecs158.Ground.Top): models stand on it
A.LoadSeconds=8                -- the longest the server waits for one model to load (a hung request is given up, the old look stays)

-- Asset ids (0 = not set). 9981304 = the owner's pyramid, 5138892863 = his volcano: both are built into the game, the ids are kept for reference / as the last resort.
A.Ids={
 ForestTree=0,JungleTree=0,
 DesertDune=0,DesertObelisk=0,DesertPyramid=9981304,
 SnowTree=0,SnowMountains=0,
 LavaVolcano=5138892863,
 CrystalSpire=0,CrystalMountain=0,
 StormDarkMount=0,StormTower=0,StormLightning=0,StormEndPeak=0,
}
-- The owner's meshes (the files in docs/proposals/R158/design/assets: his .rbxm models). A MeshPart cannot be rebuilt as part data, so they load by id at server start.
A.Mesh={
 LavaVolcano={MeshId='rbxassetid://5138886694',TextureId='rbxassetid://5138888007',Size={69.97479248046875,52.653690338134766,59.81602096557617},Color={163,162,165}},
}
-- Models the game already has. Found in the map by name under the biome's folder: Biome = the Obby.Biomes child's name starts with it, Name = a Lua pattern for the model's name (Parent =
-- one for its parent's name, when given), Max = how many different ones are used (picked in name order), Smallest = the ones with the fewest parts first, Also = more entries of the same
-- shape. Hub = the hub's own trees (ReplicatedStorage.HubLifeArt151 builds them): {Kind = 'Oak' | 'Leafy' | 'Poplar' | 'Palm', Arg = its size S / M / L or its tone, X, Z = the builder's
-- seed (a different seed, a different crown)}. The models of a key, in this order: the map's, then the hub's. A spot's Look picks one of them (1, 2, 3 ...; no Look: they take turns).
-- The map has ONE oak design (the Forest's three Oaks and the Jungle's two are the same tree in different sizes and greens): the rest of the variety is the hub's trees.
A.Game={
 ForestTree={Biome='Biome_1_',Name='^Oak$',Max=1,Hub={
  {Kind='Oak',Arg='L',X=780,Z=10},{Kind='Oak',Arg='M',X=480,Z=20},{Kind='Oak',Arg='L',X=1020,Z=50},
  {Kind='Oak',Arg='M',X=420,Z=10},{Kind='Oak',Arg='S',X=240,Z=40},
  {Kind='Poplar',X=2580,Z=10},{Kind='Poplar',X=2880,Z=60},
 }},
 JungleTree={Biome='Biome_6_',Name='^Tall jungle tree$',Max=1,Also={{Name='^Oak$',Parent='^Jungle corner$',Max=1}},Hub={
  {Kind='Palm',X=2940,Z=10},{Kind='Palm',X=3060,Z=30},{Kind='Palm',X=3240,Z=60},
  {Kind='Oak',Arg='M',X=540,Z=30},{Kind='Poplar',X=2700,Z=30},{Kind='Oak',Arg='M',X=420,Z=10},
 }},
 SnowTree={Biome='Biome_3_',Name='^IceTree_%d+$',Max=4},
 CrystalSpire={Biome='Biome_5_',Name='^Crystal$',Max=1,Smallest=true},
}
-- The keys, in the order they are looked at: biome (the folder under TrackBackdrops158), who gives the model, what it is. Source: 'owner' (built in from his file / meshes), 'game' (the
-- game's own model), 'waiting' (nothing yet: send an id or drag a model into the folder).
A.Keys={
 {Key='ForestTree',Biome='Forest',Source='game',What='large trees (the game\'s own Forest oak and the hub\'s oaks and poplars), 95 - 170 studs tall: a loose forest on both sides in three bands, denser at the back'},
 {Key='JungleTree',Biome='Jungle',Source='game',What='large trees (the game\'s own Tall jungle tree and Jungle oak, and the hub\'s palms, oaks and poplar), 95 - 165 studs tall: a loose jungle on both sides in three bands, denser at the back'},
 {Key='DesertDune',Biome='Desert',Source='waiting',What='a big sand dune, about 340 wide and 85 tall (five)'},
 {Key='DesertObelisk',Biome='Desert',Source='waiting',What='a tall sandstone obelisk with a gold tip, about 9 wide and 110 tall (two)'},
 {Key='DesertPyramid',Biome='Desert',Source='owner',What='the great pyramid, the owner\'s asset 9981304 (82 parts, built in as data; one, far right)'},
 {Key='SnowTree',Biome='Snow',Source='game',What='a snowy tree (the game\'s own IceTree)'},
 {Key='SnowMountains',Biome='Snow',Source='owner',What='the owner\'s Low Poly Island Hills (16 hills, meshes by id): two clusters, one each side, trees placed unevenly'},
 {Key='LavaVolcano',Biome='Lava',Source='owner',What='the owner\'s volcano (asset 5138892863, mesh 5138886694): four spots, each different; it also replaces the volcano on the track'},
 {Key='CrystalSpire',Biome='Crystal',Source='game',What='a crystal cluster scaled up into a giant spire (the game\'s own Crystal)'},
 {Key='CrystalMountain',Biome='Crystal',Source='waiting',What='a big purple mountain, about 650 wide and 230 tall (three)'},
 {Key='StormDarkMount',Biome='Storm Peaks',Source='owner',What='the owner\'s dark mountain (dark_mount.rbxm, cut down to 280 parts per copy): two copies each side'},
 {Key='StormTower',Biome='Storm Peaks',Source='waiting',What='a tall copper lightning tower with a glowing ball, about 8 wide and 143 tall (two)'},
 {Key='StormLightning',Biome='Storm Peaks',Source='waiting',What='a lightning bolt effect, about 16 wide and 100 tall (by each tower), one bigger (70 x 155) behind the end wall'},
 {Key='StormEndPeak',Biome='Storm Peaks',Source='waiting',What='a huge dark storm mountain behind the end wall, about 840 wide and 300 tall (one)'},
}
-- The spots. X / Z = where the model's base centre stands (Y = its base, default the ground), Yaw = degrees about the up axis (the model's front, -Z, turns toward -X for +90, as Roblox's CFrame.Angles does),
-- W / H / D = the box it must fit (see above), Scale = for the owner's own models: the size relative to his file, Mirror = left and right swapped (parts only),
-- Tilt = degrees of lean (the volcano), Tint = colour multiplier {r,g,b} / 255, Glow = a small glowing mouth on top (the volcano; no lava streams), Look = which of the key's models
-- the spot gets (1, 2, 3 ... in the order of A.Game; the Forest and Jungle trees). The Forest and Jungle spots (between TREES158 BEGIN / END) are laid out by
-- docs/proposals/R158/design/make_trees158.py from a fixed seed; edit them by hand or run it again with --write.
-- Every box obeys the rules (checked by docs/proposals/R158/tests/run_walls158.sh): all of it at |x| >= 100 (or behind the end wall, z > 5990) and off the hub (z >= -99).
A.Slots={
 -- TREES158 BEGIN
 -- Forest: large trees on both sides in three bands (front, middle, back: taller and denser the further out); Look = the key's model (A.Game order)
 {Key='ForestTree',X=-152,Z=-50,Yaw=5,W=86.0,H=95.0,D=86.2,Tint={220,226,221},Look=3},
 {Key='ForestTree',X=-161,Z=33,Yaw=355,W=87.7,H=107.6,D=75.7,Tint={254,244,243},Look=1},
 {Key='ForestTree',X=-247,Z=-28,Yaw=226,W=93.9,H=115.2,D=81.1,Tint={246,244,236},Look=1},
 {Key='ForestTree',X=-211,Z=30,Yaw=61,W=48.7,H=134.9,D=48.5,Tint={234,241,232},Look=8},
 {Key='ForestTree',X=-263,Z=-67,Yaw=186,W=48.1,H=133.3,D=47.9,Tint={237,246,235},Look=8},
 {Key='ForestTree',X=-315,Z=-18,Yaw=290,W=107.2,H=131.5,D=92.6,Tint={247,240,245},Look=1},
 {Key='ForestTree',X=-295,Z=44,Yaw=16,W=56.7,H=145.2,D=56.7,Tint={237,246,239},Look=7},
 {Key='ForestTree',X=152,Z=-49,Yaw=178,W=88.0,H=105.5,D=89.6,Tint={206,220,210},Look=6},
 {Key='ForestTree',X=170,Z=29,Yaw=16,W=89.8,H=110.2,D=77.6,Tint={255,245,238},Look=1},
 {Key='ForestTree',X=202,Z=-58,Yaw=329,W=53.4,H=147.9,D=53.1,Tint={236,245,243},Look=8},
 {Key='ForestTree',X=213,Z=11,Yaw=251,W=94.1,H=123.1,D=82.1,Tint={220,223,216},Look=5},
 {Key='ForestTree',X=303,Z=-60,Yaw=267,W=58.0,H=160.7,D=57.7,Tint={230,248,235},Look=8},
 {Key='ForestTree',X=278,Z=-27,Yaw=193,W=66.2,H=169.4,D=66.2,Tint={235,246,235},Look=7},
 {Key='ForestTree',X=316,Z=17,Yaw=180,W=99.4,H=129.9,D=99.3,Tint={216,227,217},Look=4},
 -- Jungle: large trees on both sides in three bands (front, middle, back: taller and denser the further out); Look = the key's model (A.Game order)
 {Key='JungleTree',X=-178,Z=156,Yaw=45,W=98.8,H=106.2,D=97.8,Tint={169,201,171},Look=3},
 {Key='JungleTree',X=-161,Z=274,Yaw=45,W=79.3,H=100.6,D=69.3,Tint={254,244,249},Look=1},
 {Key='JungleTree',X=-167,Z=360,Yaw=18,W=92.9,H=95.1,D=94.8,Tint={162,191,166},Look=4},
 {Key='JungleTree',X=-168,Z=446,Yaw=190,W=89.6,H=99.1,D=81.1,Tint={149,187,152},Look=6},
 {Key='JungleTree',X=-222,Z=132,Yaw=175,W=96.1,H=96.6,D=90.3,Tint={165,200,175},Look=5},
 {Key='JungleTree',X=-252,Z=211,Yaw=317,W=101.0,H=128.1,D=88.2,Tint={252,243,242},Look=1},
 {Key='JungleTree',X=-212,Z=305,Yaw=79,W=101.8,H=112.6,D=92.2,Tint={145,185,152},Look=6},
 {Key='JungleTree',X=-216,Z=444,Yaw=18,W=61.4,H=157.4,D=61.4,Tint={155,196,175},Look=7},
 {Key='JungleTree',X=-322,Z=146,Yaw=340,W=97.2,H=104.5,D=96.2,Tint={165,198,174},Look=3},
 {Key='JungleTree',X=-331,Z=223,Yaw=28,W=108.9,H=142.5,D=95.0,Tint={152,188,164},Look=8},
 {Key='JungleTree',X=-344,Z=308,Yaw=250,W=108.2,H=116.3,D=107.1,Tint={166,202,172},Look=3},
 {Key='JungleTree',X=-292,Z=372,Yaw=152,W=60.8,H=155.7,D=60.8,Tint={158,190,173},Look=7},
 {Key='JungleTree',X=-305,Z=425,Yaw=194,W=107.9,H=141.1,D=94.0,Tint={151,190,160},Look=8},
 {Key='JungleTree',X=-275,Z=478,Yaw=0,W=97.5,H=117.8,D=85.2,Tint={242,251,248},Look=2},
 {Key='JungleTree',X=172,Z=144,Yaw=155,W=98.3,H=108.7,D=89.0,Tint={146,189,153},Look=6},
 {Key='JungleTree',X=155,Z=227,Yaw=272,W=90.9,H=109.8,D=79.5,Tint={245,247,243},Look=2},
 {Key='JungleTree',X=162,Z=295,Yaw=20,W=90.1,H=114.2,D=78.7,Tint={250,249,238},Look=1},
 {Key='JungleTree',X=216,Z=152,Yaw=145,W=99.9,H=130.6,D=87.0,Tint={151,195,162},Look=8},
 {Key='JungleTree',X=243,Z=246,Yaw=326,W=101.0,H=122.0,D=88.3,Tint={252,242,247},Look=2},
 {Key='JungleTree',X=211,Z=326,Yaw=5,W=102.0,H=102.6,D=95.9,Tint={166,199,171},Look=5},
 {Key='JungleTree',X=206,Z=389,Yaw=36,W=54.6,H=139.9,D=54.6,Tint={157,191,171},Look=7},
 {Key='JungleTree',X=234,Z=461,Yaw=189,W=102.5,H=123.9,D=89.7,Tint={243,242,243},Look=2},
 {Key='JungleTree',X=288,Z=125,Yaw=319,W=54.1,H=138.5,D=54.1,Tint={152,198,173},Look=7},
 {Key='JungleTree',X=348,Z=181,Yaw=53,W=103.5,H=125.1,D=90.5,Tint={247,244,242},Look=2},
 {Key='JungleTree',X=303,Z=252,Yaw=357,W=109.0,H=120.6,D=98.7,Tint={146,184,155},Look=6},
 {Key='JungleTree',X=291,Z=313,Yaw=143,W=60.3,H=154.4,D=60.3,Tint={160,198,176},Look=7},
 {Key='JungleTree',X=309,Z=365,Yaw=287,W=103.8,H=135.7,D=90.4,Tint={149,191,161},Look=8},
 {Key='JungleTree',X=311,Z=414,Yaw=30,W=63.8,H=163.5,D=63.8,Tint={158,199,172},Look=7},
 {Key='JungleTree',X=287,Z=456,Yaw=41,W=53.4,H=136.7,D=53.4,Tint={159,191,170},Look=7},
 -- TREES158 END
 -- Desert: big dunes, two obelisks, the great pyramid (the owner's asset 9981304, placed from data)
 {Key='DesertDune',X=-300,Z=640,Yaw=0,W=340,H=85,D=400},
 {Key='DesertDune',X=-290,Z=1090,Yaw=0,W=320,H=75,D=360},
 {Key='DesertDune',X=300,Z=600,Yaw=0,W=340,H=90,D=420},
 {Key='DesertDune',X=290,Z=1130,Yaw=0,W=320,H=75,D=360},
 {Key='DesertDune',X=-500,Z=860,Yaw=0,W=420,H=115,D=480},
 {Key='DesertObelisk',X=150,Z=820,Yaw=0,W=9,H=122,D=9},
 {Key='DesertObelisk',X=-150,Z=1150,Yaw=0,W=9,H=108,D=9},
 {Key='DesertPyramid',X=470,Z=960,Yaw=0,W=292.6,H=192,D=320},
 -- Snow: the game's own snowy trees, and the owner's Low Poly Island Hills (two clusters, one each side, scaled and turned differently, the trees on them placed unevenly)
 {Key='SnowTree',X=-134,Z=1300,Yaw=0,W=45,H=100,D=45,Tint={236,233,239}},
 {Key='SnowTree',X=-150,Z=1520,Yaw=89,W=50.4,H=112,D=50.4,Tint={247,252,234}},
 {Key='SnowTree',X=-136,Z=1700,Yaw=178,W=46.8,H=104,D=46.8,Tint={234,247,253}},
 {Key='SnowTree',X=-146,Z=1920,Yaw=267,W=49.5,H=110,D=49.5,Tint={245,242,248}},
 {Key='SnowTree',X=138,Z=1400,Yaw=356,W=48.6,H=108,D=48.6,Tint={232,237,243}},
 {Key='SnowTree',X=134,Z=1600,Yaw=85,W=45,H=100,D=45,Tint={243,232,238}},
 {Key='SnowTree',X=150,Z=1820,Yaw=174,W=51.3,H=114,D=51.3,Tint={254,251,233}},
 {Key='SnowTree',X=136,Z=2000,Yaw=263,W=46.8,H=104,D=46.8,Tint={241,246,252}},
 {Key='SnowMountains',X=-370,Z=1480,Yaw=0,W=488.8,H=156.5,D=698.4,Scale=2.6},
 {Key='SnowMountains',X=400,Z=1760,Yaw=180,W=564,H=180.6,D=805.8,Scale=3},
 -- Lava: the owner's volcano (asset 5138892863: mesh 5138886694), four spots, each a different size, turn, tilt, tint and glow
 {Key='LavaVolcano',X=480,Z=2560,Yaw=30,W=319,H=240,D=272.6,Tilt=1.5,Tint={255,236,220},Glow=true},
 {Key='LavaVolcano',X=-360,Z=2280,Yaw=-20,W=190,H=143,D=162.5,Tilt=-2,Tint={232,232,255}},
 {Key='LavaVolcano',X=-380,Z=2860,Yaw=75,W=228.6,H=172,D=195.4,Tilt=2.5,Tint={255,255,235},Glow=true},
 {Key='LavaVolcano',X=430,Z=2160,Yaw=140,W=148.8,H=112,D=127.2,Tilt=-1,Tint={224,214,214}},
 -- Crystal: the game's own crystal clusters, scaled up (6 spots), purple mountains
 {Key='CrystalSpire',X=-170,Z=3200,Yaw=110,W=50,H=100,D=50,Tint={245,233,220}},
 {Key='CrystalSpire',X=-210,Z=3560,Yaw=30,W=68,H=136,D=68,Tint={225,252,242}},
 {Key='CrystalSpire',X=-175,Z=3900,Yaw=145,W=45,H=90,D=45,Tint={246,230,223}},
 {Key='CrystalSpire',X=180,Z=3320,Yaw=180,W=58,H=116,D=58,Tint={227,246,248}},
 {Key='CrystalSpire',X=215,Z=3720,Yaw=65,W=73,H=146,D=73,Tint={224,255,239}},
 {Key='CrystalSpire',X=170,Z=4050,Yaw=110,W=46,H=92,D=46,Tint={254,247,247}},
 {Key='CrystalMountain',X=-440,Z=3700,Yaw=0,W=640.7,H=226.4,D=640.7},
 {Key='CrystalMountain',X=460,Z=4000,Yaw=0,W=669,H=236.4,D=669},
 {Key='CrystalMountain',X=-420,Z=4250,Yaw=0,W=555.8,H=196.4,D=555.8},
 -- Storm Peaks: the owner's dark mountain (dark_mount.rbxm, cut down, placed from data), two copies each side; towers, lightning, the end mountain
 {Key='StormDarkMount',X=-360,Z=4750,Yaw=0,W=407,H=240.2,D=543.6,Scale=2},
 {Key='StormDarkMount',X=-395,Z=5450,Yaw=180,W=488.4,H=288.2,D=652.3,Scale=2.4},
 {Key='StormDarkMount',X=380,Z=5000,Yaw=0,W=447.7,H=264.2,D=598,Scale=2.2,Mirror=true},
 {Key='StormDarkMount',X=410,Z=5650,Yaw=180,W=366.3,H=216.2,D=489.2,Scale=1.8,Mirror=true},
 {Key='StormTower',X=-140,Z=5000,Yaw=0,W=8,H=143,D=8},
 {Key='StormTower',X=140,Z=5500,Yaw=0,W=8,H=143,D=8},
 {Key='StormLightning',X=-140,Z=5000,Yaw=0,W=16,H=100,D=16,Y=135},
 {Key='StormLightning',X=140,Z=5500,Yaw=0,W=16,H=100,D=16,Y=135},
 {Key='StormLightning',X=-27,Z=6080,Yaw=0,W=70,H=155,D=8,Y=175},
 {Key='StormEndPeak',X=0,Z=6560,Yaw=0,W=838.8,H=298.9,D=838.8},
}
-- The box a slot fills in the world (after its turn): {x0,x1,y0,y1,z0,z1}. Used by the rule checks and the loader's last guard.
function A.Box(slot)
 local y=math.rad(slot.Yaw or 0)
 local c,s=math.abs(math.cos(y)),math.abs(math.sin(y))
 local hx=(slot.W*c+slot.D*s)/2;local hz=(slot.W*s+slot.D*c)/2
 local y0=slot.Y or A.Ground
 return{slot.X-hx,slot.X+hx,y0,y0+slot.H,slot.Z-hz,slot.Z+hz}
end
-- The slots of one key, in order.
function A.SlotsOf(key)
 local list={}
 for _,s in ipairs(A.Slots)do if s.Key==key then list[#list+1]=s end end
 return list
end
function A.Key(key)for _,k in ipairs(A.Keys)do if k.Key==key then return k end end end
return A
