# R153: one fixed rarity per seed

Owner: "Ik that the rates of seed is not fixed for every seed but we should make it fixed visibly so when players pull a cosmic seed from a void pack they are still reminded of how rare it is
for example a change from 1/12 to 1/(the original rate) in the index".

**Display only.** What the server rolls (odds, pity, size, luck) is untouched: `dump_odds.luau` (8,131 lines: every `SeedOdds` row, the Void / Verity / Mech rows, seeded rolls, every seed's rarity)
is byte-identical to the R152 release. The odds files keep their frozen hashes. Announcements still decide by rarity tier; nothing reads a displayed chance back.

## The canonical rate

`ReplicatedStorage/SeedRarity153.lua`. `Canonical(seedId) -> N`, `Text(seedId) -> "1/N"` (also `Percent`, `Count` = the "N" text, `Home`, `All`). N is the seed's chance in its **home pack**:

* a biome seed: the biome's plain Common pack (`Pack01`) at the current odds version (`SeedPackRules.OddsVersion`), luck 1, no boots, no friend / starter boost, no pity, no size;
* the Verity seed: the Verity pack (1/100); a Mech seed: the Limited Mech pack (its own `Chance`);
* a retired seed (nobody can pull it): none (`nil`, text "—").

It is computed from the existing odds code (`SeedPackRules.SeedOdds` over `BuildSeedCatalog()`, the catalog the server's Config is built from), never copied, cached, and printed by `OddsText85`
exactly like every chance (whole numbers under a million, 1/1.67B above). The Index already showed this number (it always used `Pack01`), so its values do not change; the card, chat and plaque did.

## Where it is shown

| Surface | Code | Was |
|---|---|---|
| Index card chip | `ChestIndex` (`SeedRarity153.Text`); `ChestService` writes `BaseChance = Percent` | the same number (Pack01) |
| Reveal "1 in N" (ladder card, Secret / Cosmic / King scenes, in-place card) | `RarePullCinematic.SeedInfo` | the held pack's tooltip row |
| Chat lines: a pull here, a pull from another server | `PullAnnounceRules.Event` derives `Odds` from the seed (whatever the sender wrote); `PullAnnouncer.OddsOf` | the pack's own chance |
| Hub plaque "BEST PULL TODAY" (and owner `bestpull` / `hubdisplays` text) | `HubDisplayRules.PullOddsText` | the pack's own chance |
| Owner `/test announce` | `PullAnnouncer` (default odds) | Pack06 / Pack03 / ... |

## Kept pack-specific

* the held pack's tooltip rows (`ChestService:_holdPack`): a pack's drop table, "what can THIS pack give";
* owner commands about packs (`/test odds ...`, `voidcheck`, `odds`);
* the Limited Mech pack's shop drop table (`GamePassClient`): a pack's contents (its numbers are the Mech seeds' fixed chances anyway);
* pack alerts / pack tiers (`RarePackRules`, `MysteryPackRules`, `TreadmillBonusRules`): they are about packs, not seeds;
* the hub board's stored `Odds` (the pull's real chance): it still ranks pulls (a Cosmic from a Void pack does not outrank one from a plain pack), only the plaque's words changed.

## Before / after

| Pull | Before (chat / card / plaque) | After |
|---|---|---|
| Polar Starbloom (Cosmic) from a Void pack | `(1/101)` / `1 in 101` / `Cosmic · 1/101` | `(1/1M)` / `1 in 1M` / `Cosmic · 1/1M` (Index: 1/1M, as before) |
| Hollow Geode (Secret) from a Void pack | 1/5 | 1/10K |
| Winter Crownwood (King) from a Void pack | 1/1.01B | 1/1T |
| Diamond Vine (Mythic) from a Pack05 | 1/12 | 1/1,000 |
| Fire Pepper (Mythic) from a Pack06 / Pack03 | 1/6 / 1/120 | 1/800 |
| Winter Crownwood from a Pack06 with Thunder boots | 1/100 | 1/1T |
| Elderbloom from the free starter pack (2x) | 1/200 | 1/400 |
| Plasma Pepper (Mech) from a Void pack | 1/417 | 1/2 (the Limited Mech pack's rate; it is also its Index number) |

## Single-seed packs (owner, after R152: "the mythic forest pack can only roll elderbloom ... make it not 100%")

**No real pack is 100% one seed, so no roll table was changed.** Checked on the real tables (`test_seed_rarity.luau`, section 9): every stage x pack (Pack01-06 and the legacy Small / Standard / Grand)
x odds version (none / 0 / 81 / 112 / 137 / 149) x luck (1 / 500 / 5e7) x starter boost lists **2 or more seeds** (the Void, Verity and Mech packs 5 or more), and `dump_odds.luau` still shows every table
byte-identical to R152. The live packs (odds version 149, what every pack made since R148 carries), luck 1:

| Biome | Pack01 | Pack02 | Pack03 | Pack04 | Pack05 | Pack06 (Mythic) |
|---|---|---|---|---|---|---|
| Forest | 6 seeds, top 61% | 6, 43% | 5, 51% | 4, 36% | 4, 28% | **2, 73%** |
| Jungle | 6, 61% | 6, 44% | 5, 53% | 4, 38% | 4, 31% | **2, 77%** |
| Desert | 7, 86% | 7, 77% | 7, 54% | 6, 78% | 6, 67% | 5, 78% |
| Snow | 7, 86% | 7, 78% | 7, 55% | 6, 81% | 6, 71% | 5, 80% |
| Lava | 7, 50% | 7, 49% | 7, 48% | 7, 41% | 7, 37% | 5, 82% |
| Crystal | 7, 50% | 7, 49% | 7, 48% | 7, 43% | 7, 39% | 5, 85% |
| Storm | 7, 50% | 7, 49% | 7, 49% | 7, 44% | 7, 40% | 5, 87% |

(seeds that can drop at all, and the favourite's share.) The Forest Mythic pack (Pack06) is **Sunflower 73.3% / Elderbloom 26.7%** (through the real roll: 2,180 / 820 of 3,000 seeded opens); the Jungle one
is Tiger Orchid 77.1% / Ancient Worldroot 22.9%: the two thinnest packs, still two seeds each. The nearest thing to a one-seed pack is a BANKED one (made before R148 and still in someone's bag, which keeps the table it was made with: the R148 "no windfall" decision): Desert Pack01-04 at odds version 137
(Prickly Pear 94.8-99.8%), Desert Pack04-06 at version 112 (Dune Lotus 98.0-99.8%), Lava Pack06 at 112 / 137 (Lava Lotus 98.0%) and Crystal Pack06 at 112 (Diamond Vine 98.0%): all still list 4-5 seeds
and none is touched. What reads as "the Mythic Forest pack only rolls Elderbloom" is the owner's TEST pack: `/test rarepacks mythic` (`RarePackTests`) is a guaranteed
reveal of the FIRST Mythic seed in the roster, which is Elderbloom, on purpose (marked `TestGrant`, never announced).
If a real pack was meant (for example the Forest / Jungle Mythic packs favouring their Mythic seed more), it is a separate change to `PackOdds137` (the frozen odds file): say which packs and the shares.
Section 9 of the test keeps the rule as an invariant: a later roster change that leaves a pack with a single seed fails the suite.

## Every seed

| Seed | Id | Rarity | Home pack | Canonical | As a Void pack drop (before) |
|---|---|---|---|---|---|
| Watermelon | `SunflowerSeed` | Common | Forest Common pack | **1/2** | - |
| Blueberry | `BluebellSeed` | Uncommon | Forest Common pack | **1/4** | - |
| Apple | `AppleSeed` | Rare | Forest Common pack | **1/16** | - |
| Mooncap | `MooncapSeed` | Rare | Forest Common pack | **1/16** | - |
| Sunflower | `SunflowerBloomSeed` | Legendary | Forest Common pack | **1/60** | - |
| Elderbloom | `ElderbloomSeed` | Mythic | Forest Common pack | **1/400** | - |
| Cocoa | `CocoaSeed` | Common | Jungle Common pack | **1/2** | - |
| Pineapple | `PineappleSeed` | Uncommon | Jungle Common pack | **1/4** | - |
| Lantern Fern | `LanternFernSeed` | Rare | Jungle Common pack | **1/16** | - |
| Venom Vine | `VenomVineSeed` | Rare | Jungle Common pack | **1/16** | - |
| Tiger Orchid | `TigerOrchidSeed` | Legendary | Jungle Common pack | **1/75** | - |
| Ancient Worldroot | `AncientWorldrootSeed` | Mythic | Jungle Common pack | **1/500** | - |
| Prickly Pear | `CactusSeed` | Uncommon | Desert Common pack | **1/1** | - |
| Aloe | `DesertAloeSeed` | Rare | Desert Common pack | **1/8** | - |
| Sand Fruit | `SandFruitSeed` | Legendary | Desert Common pack | **1/90** | - |
| Dune Lotus | `DatePalmSeed` | Mythic | Desert Common pack | **1/600** | - |
| Dune Starfruit | `StarfruitSeed` | Secret | Desert Common pack | **1/10K** | 1/5 |
| Mirage Fig | `MirageFigSeed` | Cosmic | Desert Common pack | **1/1M** | 1/101 |
| Solar Starfruit | `SolarStarfruitSeed` | King | Desert Common pack | **1/1T** | 1/1.01B |
| Snow Melon | `SnowdropSeed` | Uncommon | Snow Common pack | **1/1** | - |
| Iceberry | `IceberrySeed` | Rare | Snow Common pack | **1/8** | - |
| Aurora Lily | `WinterPineSeed` | Legendary | Snow Common pack | **1/105** | - |
| Glacier Lotus | `CrystalLilySeed` | Mythic | Snow Common pack | **1/700** | - |
| Silent Frostbell | `SilentFrostbellSeed` | Secret | Snow Common pack | **1/10K** | 1/5 |
| Polar Starbloom | `PolarStarbloomSeed` | Cosmic | Snow Common pack | **1/1M** | 1/101 |
| Winter Crownwood | `WinterCrownwoodSeed` | King | Snow Common pack | **1/1T** | 1/1.01B |
| Ash Tomato | `AshRoseSeed` | Rare | Lava Common pack | **1/2** | - |
| Ember Pumpkin | `EmberBloomSeed` | Rare | Lava Common pack | **1/2** | - |
| Lava Lotus | `LavaLotusSeed` | Legendary | Lava Common pack | **1/120** | - |
| Fire Pepper | `FirePepperSeed` | Mythic | Lava Common pack | **1/800** | - |
| Obsidian Maw | `ObsidianMawSeed` | Secret | Lava Common pack | **1/10K** | 1/5 |
| Boom Bloom | `SupernovaBloomSeed` | Cosmic | Lava Common pack | **1/1M** | 1/101 |
| Ember Emperor | `EmberEmperorSeed` | King | Lava Common pack | **1/1T** | 1/1.01B |
| Amethyst Grape | `AmethystSeed` | Rare | Crystal Common pack | **1/2** | - |
| Prism Pepper | `PrismOrchidSeed` | Rare | Crystal Common pack | **1/2** | - |
| Moon Melon | `MoonflowerSeed` | Legendary | Crystal Common pack | **1/150** | - |
| Diamond Vine | `DiamondVineSeed` | Mythic | Crystal Common pack | **1/1,000** | - |
| Hollow Geode | `HollowGeodeSeed` | Secret | Crystal Common pack | **1/10K** | 1/5 |
| Orbit Lotus | `OrbitLotusSeed` | Cosmic | Crystal Common pack | **1/1M** | 1/101 |
| Prism Monarch | `PrismMonarchSeed` | King | Crystal Common pack | **1/1T** | 1/1.01B |
| Spark Reed | `SparkReedSeed` | Rare | Storm Peaks Common pack | **1/2** | - |
| Thunder Tulip | `ThunderTulipSeed` | Rare | Storm Peaks Common pack | **1/2** | - |
| Volt Orchid | `VoltOrchidSeed` | Legendary | Storm Peaks Common pack | **1/180** | - |
| Tempest Lotus | `TempestLotusSeed` | Mythic | Storm Peaks Common pack | **1/1,200** | - |
| Blackout Bloom | `BlackoutBloomSeed` | Secret | Storm Peaks Common pack | **1/10K** | 1/5 |
| Storm Sovereign | `StormSovereignSeed` | Cosmic | Storm Peaks Common pack | **1/1M** | 1/101 |
| Pulsar Starfruit | `PulsarStarfruitSeed` | King | Storm Peaks Common pack | **1/1T** | 1/1.01B |
| Plasma Pepper | `PlasmaPepperSeed` | Legendary | Limited Mech pack | **1/2** | 1/417 |
| Holo Melon | `HoloMelonSeed` | Mythic | Limited Mech pack | **1/4** | 1/769 |
| Prism Lotus | `PrismLotusSeed` | Mythic | Limited Mech pack | **1/6** | 1/1,250 |
| Holo Apple Tree | `HoloAppleTreeSeed` | Secret | Limited Mech pack | **1/14** | 1/2,860 |
| Nebula Vine | `NebulaVineSeed` | Cosmic | Limited Mech pack | **1/40** | 1/8,000 |
| Crowncore Tree | `CrowncoreTreeSeed` | King | Limited Mech pack | **1/200** | 1/40K |
| Verity | `VeritySeed` | King | Verity pack | **1/100** | - |

Every seed above reads the same text on the Index, the reveal card, the chat (client and rules) and the plaque (`check_surfaces.py`: 54 seeds x 5 surfaces).

## Tests

`docs/proposals/R153/tests/run_seed_rarity.sh` (in `tools/tests/run_all_suites.sh`): static checks (manifest, no copied odds, frozen odds files, no text read back); the base-vs-now roll dump; the server test
(54 canonical Ns, the Void example, ChestService's catalog, a held Void pack keeps its rows, a real Void pack opened through the real announcer, plaque ranking, owner commands); the real Index, the real
reveal (54 seeds, ladder + scenes) and the real chat client with every pack / catalog / payload number set to the wrong "1/12"; the cross-surface comparison; and a "teeth" run that puts the R152
scripts back and expects each test to fail. Existing tests that asserted pack-dependent odds text (R151 announce rules / client / server, R151 hub service, R151 reveal cinematic, R147 Verity pack) now assert the fixed text.
