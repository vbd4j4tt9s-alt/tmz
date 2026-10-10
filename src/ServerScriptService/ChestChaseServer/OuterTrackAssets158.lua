-- R158 outer track: WHAT goes outside the track's walls and WHERE (owner: "I will give you asset ids for the pyramids, volcanos and mountains and everything else, don't have to
-- model them yourself, just place the stuff"). Pure data, edited by hand: the asset ids, the list of keys and the spots. OuterTrackLoader158 places the models.
-- The picture: a flat ground outside the walls (TrackWalls158 builds it) and big simple models far outside (|x| >= 100, never over the hub), all anchored, no collision / touch /
-- query, no shadows (A.Shadows), streamed in and out like any part. docs/proposals/R158/design/outer_track_assets.md explains the keys to the owner.
--
-- WHERE A KEY'S MODEL COMES FROM (the first that works; nothing part-built is ever made up):
--   1. hand       a model the owner dragged into ServerStorage.OuterTrackAssets158, named by the key (or Key2, Key3 ... for more looks of the same thing)
--   2. owner      the owner's own file, built into the game (DesertPyramid: the 82-part file as data; StormDarkMount: his 1,532-part mountain cut down to 280 parts; LavaVolcano and
--                 SnowMountains: his meshes, loaded by id with AssetService:CreateMeshPartAsync when the server starts)
--   3. game       a model the game already builds (its oaks, jungle trees, ice trees, crystal clusters), copied from the map and scaled up (A.Game)
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
 ForestOak=0,JungleTree=0,JungleTemple=0,JungleCliff=0,
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
-- Models the game already has (found in the map by name under the biome's folder): Biome = the Obby.Biomes child's name starts with it, Name = a Lua pattern for the model's name,
-- Max = how many different ones are used (picked in name order, spread over the spots), Smallest = the ones with the fewest parts first.
A.Game={
 ForestOak={Biome='Biome_1_',Name='^Oak$',Max=3},
 JungleTree={Biome='Biome_6_',Name='^Tall jungle tree$',Max=2},
 SnowTree={Biome='Biome_3_',Name='^IceTree_%d+$',Max=4},
 CrystalSpire={Biome='Biome_5_',Name='^Crystal$',Max=1,Smallest=true},
}
-- The keys, in the order they are looked at: biome (the folder under TrackBackdrops158), who gives the model, what it is. Source: 'owner' (built in from his file / meshes), 'game' (the
-- game's own model), 'waiting' (nothing yet: send an id or drag a model into the folder).
A.Keys={
 {Key='ForestOak',Biome='Forest',Source='game',What='a tall round oak (the game\'s own Oak)'},
 {Key='JungleTree',Biome='Jungle',Source='game',What='a giant flat-top jungle tree (the game\'s own Tall jungle tree)'},
 {Key='JungleTemple',Biome='Jungle',Source='waiting',What='a stepped stone temple, about 140 studs wide and 140 tall (one, far left; its front faces the track)'},
 {Key='JungleCliff',Biome='Jungle',Source='waiting',What='a mossy cliff with a waterfall and a pool at its foot, about 100 wide and 156 tall (one, far right; its front faces the track)'},
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
-- Tilt = degrees of lean (the volcano), Tint = colour multiplier {r,g,b} / 255, Glow = a small glowing mouth on top (the volcano; no lava streams).
-- Every box obeys the rules (checked by docs/proposals/R158/tests/run_walls158.sh): all of it at |x| >= 100 (or behind the end wall, z > 5990) and off the hub (z >= -99).
A.Slots={
 -- Forest: tall oaks behind both walls (the game's own Oak model, scaled to the spot's height)
 {Key='ForestOak',X=-122,Z=-56,Yaw=0,W=30,H=80.4,D=30,Tint={255,244,250}},
 {Key='ForestOak',X=-136,Z=8,Yaw=53,W=34,H=86.4,D=34,Tint={248,251,251}},
 {Key='ForestOak',X=-122,Z=56,Yaw=106,W=28,H=76.4,D=28,Tint={241,228,252}},
 {Key='ForestOak',X=-168,Z=-24,Yaw=159,W=40,H=92.4,D=40,Tint={234,235,253}},
 {Key='ForestOak',X=-164,Z=44,Yaw=212,W=36,H=88.4,D=36,Tint={227,242,254}},
 {Key='ForestOak',X=-216,Z=10,Yaw=265,W=44,H=100.4,D=44,Tint={250,249,255}},
 {Key='ForestOak',X=127,Z=-44,Yaw=318,W=32,H=82.4,D=32,Tint={243,226,226}},
 {Key='ForestOak',X=132,Z=16,Yaw=11,W=28,H=78.4,D=28,Tint={236,233,227}},
 {Key='ForestOak',X=126,Z=64,Yaw=64,W=32,H=86.4,D=32,Tint={229,240,228}},
 {Key='ForestOak',X=170,Z=-12,Yaw=117,W=40,H=94.4,D=40,Tint={252,247,229}},
 {Key='ForestOak',X=166,Z=50,Yaw=170,W=38,H=96.4,D=38,Tint={245,254,230}},
 {Key='ForestOak',X=220,Z=24,Yaw=223,W=44,H=102.4,D=44,Tint={238,231,231}},
 -- Jungle: giant jungle trees (the game's own Tall jungle tree), a stepped temple, a waterfall cliff
 {Key='JungleTree',X=-130,Z=140,Yaw=0,W=52,H=103.9,D=52,Tint={234,235,253}},
 {Key='JungleTree',X=-140,Z=300,Yaw=71,W=52,H=93.9,D=52,Tint={227,242,254}},
 {Key='JungleTree',X=-141,Z=460,Yaw=142,W=52,H=98.9,D=52,Tint={250,249,255}},
 {Key='JungleTree',X=140,Z=190,Yaw=213,W=52,H=98.9,D=52,Tint={243,226,226}},
 {Key='JungleTree',X=142,Z=360,Yaw=284,W=52,H=93.9,D=52,Tint={236,233,227}},
 {Key='JungleTree',X=133,Z=500,Yaw=355,W=52,H=103.9,D=52,Tint={229,240,228}},
 {Key='JungleTemple',X=-320,Z=320,Yaw=-90,W=140,H=141,D=140},
 {Key='JungleCliff',X=318,Z=250,Yaw=90,W=104,H=156,D=108},
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
