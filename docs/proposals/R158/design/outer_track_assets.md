# Outer track: the models (R158)

You said: "I will give you asset ids for the pyramids, volcanos and mountains and everything else, don't have to model them yourself, just place the stuff."
So the game now builds **only the flat ground** outside the walls from parts. Everything that stands on it is a **model**: yours, or one the game already has.

Where it is: `ServerScriptService/ChestChaseServer/OuterTrackAssets158` (the keys, the ids, the spots). You can read and edit it. `OuterTrackLoader158` places the models.

## Two ways to give me a model

1. **Send me the asset id.** I paste it into `OuterTrackAssets158.Ids` (for example `StormTower = 123456`). Roblox only lets a game load models that **the game's owner owns**. A model by someone else fails with "not authorized": the Output then says one plain line ("can't be loaded (not your asset)") and that key is skipped. No warning, nothing breaks.
2. **Drag the model into `ServerStorage.OuterTrackAssets158`** (make that Folder if it is not there) and **name it with the key** from the table (`DesertDune`). This always works, also for models by someone else. Want more than one look? Name them `DesertDune`, `DesertDune2`, `DesertDune3`: the spots take turns.

A model dragged in always wins over everything else for its key.

## What happens to a model

* It is **scaled evenly** until it fits the spot's box (W wide across its front, H tall, D deep), **stood on the ground**, turned a little (each spot has its own turn), and every copy of a key has a different size / turn (and tint, for some).
* It is made safe like the hub trees: **every script, sound, light, particle and joint is removed**, decals and textures stay.
* Every part is **anchored, no collision, no touch, no query** (players, keepers, packs and the camera go through it) and **casts no shadow**.
* It stays at least 100 studs from the middle of the track (`|x| >= 100`), never over the hub. A spot that would break that is refused.
* Nothing runs per frame. The parts stream in and out like any other part.
* The model's **front is its -Z side** (Roblox's front). For the temple and the cliff, that side is turned toward the track.

## The keys

| Key | Where | What to send | How many | Box (W x H x D studs) | Status |
|---|---|---|---|---|---|
| `ForestOak` | Forest, both sides | a tall round oak | 12 | 28-44 x 76-102 x 28-44 | **uses the game's own Oak** (scaled up, tinted). Send a model to replace it. |
| `JungleTree` | Jungle, both sides | a giant flat-top jungle tree | 6 | 52 x 94-104 x 52 | **uses the game's own Tall jungle tree.** |
| `JungleTemple` | Jungle, far left | a stepped stone temple | 1 | 140 x 141 x 140 | **waiting for a model** |
| `JungleCliff` | Jungle, far right | a mossy cliff with a waterfall and a pool | 1 | 104 x 156 x 108 | **waiting for a model** |
| `DesertDune` | Desert, both sides | a big sand dune | 5 | 320-420 x 75-115 x 360-480 | **waiting for a model** |
| `DesertObelisk` | Desert | a tall sandstone obelisk, gold tip | 2 | 9 x 108-122 x 9 | **waiting for a model** |
| `DesertPyramid` | Desert, far right | the great pyramid | 1 | 293 x 192 x 320 | **DONE from your file** (asset 9981304: 82 blocks, built in as data, so it needs no loading). Drag a model named `DesertPyramid` in to replace it. |
| `SnowTree` | Snow, both sides | a snowy tree | 8 | 45-51 x 100-114 x 45-51 | **uses the game's own IceTree** (the translucent ice trees). |
| `SnowMountains` | Snow, one cluster each side | your Low Poly Island Hills | 2 | 489-564 x 156-181 x 698-806 | **DONE from your file**: 16 hills, 4 meshes loaded by id (5150938211, 5150934668, 5153142324, 5153169732). The trees are **re-placed unevenly** (some hills bare, clusters, singles, sizes 0.7-1.45x, a lean each) and about 4 in 10 are the game's own snowy trees. Or drag the whole model in as `SnowMountains` (then it is used as you made it). |
| `LavaVolcano` | Lava, four spots | your volcano | 4 | 149-319 x 112-240 x 127-273 | **DONE from your file**: needs the model in `ServerStorage.OuterTrackAssets158.LavaVolcano`, **or it loads by mesh id** (5138886694, texture 5138888007) when the server starts. The four copies differ in size (x2.1), turn, a little lean, tint, and two have a small glowing mouth. **No lava streams.** |
| `CrystalSpire` | Crystal, both sides | a crystal cluster / spire | 6 | 45-73 x 90-146 x 45-73 | **uses the game's own Crystal clusters** (the smallest one, scaled up, tinted). |
| `CrystalMountain` | Crystal | a big purple mountain | 3 | 556-669 x 196-236 x 556-669 | **waiting for a model** |
| `StormDarkMount` | Storm Peaks, 2 each side | your dark mountain | 4 | 366-488 x 216-288 x 489-652 | **DONE from your file**, cut down: 280 of its 1,532 blocks per copy, built in as data (see below). Drag a model named `StormDarkMount` in to replace it. |
| `StormTower` | Storm Peaks | a copper lightning tower with a glowing ball | 2 | 8 x 143 x 8 | **waiting for a model** |
| `StormLightning` | Storm Peaks | a lightning bolt effect | 3 | 16 x 100 x 16 (two), 70 x 155 x 8 (one, behind the end wall) | **waiting for a model** |
| `StormEndPeak` | behind the end wall | a huge dark mountain | 1 | 839 x 299 x 839 | **waiting for a model** |

"Waiting" keys place nothing. The Output says one plain line each ("no model yet ... drag a model named X into ServerStorage.OuterTrackAssets158").
Rule from you: anything you did not send a model for uses **the game's own models** (its trees, crystals) with variation, never new part-built shapes. The game has no temple, cliff, dune, obelisk, mountain or tower model, so those keys wait.

## The ones made from your files

* **Desert pyramid (asset 9981304).** All 82 blocks (Concrete, 215,197,154), the welds dropped, rebuilt as anchored parts, scaled evenly from 128 x 84 x 140 to 293 x 192 x 320. No block shares a plane with another that points the same way (checked with the same z-fighting detector as the rest of the map). The R157 pyramid on the track (x -62) is untouched.
* **Dark mountain (dark_mount.rbxm).** 1,532 blocks became **280**: all welds, the 19 spot lights, the 32 cylinder meshes and the 172 "Steps" are gone (the Steps lie inside the other blocks' silhouette), then the 280 biggest blocks stay. The front / side / top silhouettes overlap the full model by **97.7 % / 96.8 % / 99.8 %** (`dark_mount_cut.png`: before and after, differences in red). I kept **no lights** (they would cost a light each and the mountain stands 300+ studs from the track). Two copies on each side, each with its own size (x1.8 - 2.4), turn and mirror. The data is a packed string in `OuterTrackModels158` (the module is 17 KB with the pyramid and the hills' layout; the whole R158 change is six new scripts, about 109 KB of Lua, well under the installer's 300 KB paste limit).
* **Volcano (asset 5138892863).** A mesh cannot be rebuilt from parts, so it loads by mesh id (or from the model you drag in). The same model also **replaces the volcano on the track** (see design.md "Built").
* **Snow hills.** The hills' sizes and places are data; the four meshes load by id. If a mesh cannot load, `SnowMountains` is skipped with one plain note and you can drag the whole model in instead.

## What it costs

With nothing dragged in, the outer track is **15 ground slabs + 1,900 model parts** (Forest 204, Jungle 198, Desert 82, Snow 152, Crystal 144, Storm 1,120); the volcano and the hills add a few hundred mesh parts when they load. Far parts stream out when you are far away.
