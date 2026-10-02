# R123 sound sync audit

Scope: every sound the game plays (client and server), checked against its visual or game moment.
Columns: **Trigger** = what starts it (event path and latency). **Pre** = preloaded before first use. **Off** = leading-silence offset
(SoundTiming `Starts` / module `Start`). **Mix** = AudioMixer group. **Pos** = positional (3D) or 2D. **Sync** = OK, FIXED or NOTE.

Global plumbing (unchanged, verified):
- `AudioMixer.Start()` (SettingsClient) routes every Sound already present or added later under SoundService/workspace:
  `Interaction_*` to Interface, music names to Music/Chase, biome beds to Ambience, everything else to Effects. Sounds that set a
  group explicitly keep it.
- `SoundTiming.Play` applies the leading-silence offset. If the sound is still loading it plays on load, but drops it if that
  is more than 0.5 s after the call, so a cue never plays long after its visual.
- `LocalSfx.Play` caps one-shots at 12 concurrent. **R123:** the same id fired again within 35 ms and 6 studs now plays once,
  which stops doubled or phased hits.

## Table

| # | Sound (id) | Where | Visual / moment | Trigger (latency) | Pre | Off | Mix | Pos | Sync / fix |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Dig variants (93793180254708) | DigSoundVariants via TrackHoleClient | hole opens + dirt burst | server `TrackHole` FireAllClients `Dig`/`Cover`; digger waits one RTT (no prediction, server can refuse) | yes (LocalSfx.Preload) | per-segment Start | Effects | 3D at hole | OK. Sound and burst start in the same handler. The new Sound instance waits for `Loaded` (cache hit, at most a frame or two) with a 0.5 s stale guard |
| 2 | Trap thud (137853494539894, planting Land) | TrackHoleClient `Trap` | thief falls in hole + dirt burst | server event | **FIXED**: was not preloaded (first fall silent or late), now preloaded with the dig id | 0 | Effects | 3D | FIXED |
| 3 | Veiled arrival (113339179211972) | VeiledArrivalFx | 1 s lights-out | server `VeiledArrival81` with server stamp; >1.5 s old ignored; once per serial | yes (client start) | 0 (unmeasured) | Effects | 2D (global event) | OK. Sound and darkness start on the same call. Late joiners get neither |
| 4 | Planting Dig / Land / Settle (118769294546013 / 137853494539894 / 97631814076710) | PlantingEffects | pile pops / last chunk lands / pile sinks | crop replication + PlantedAt freshness; queued per pile beat; the Start beat fires in the same Heartbeat step as the pile | yes (3 emitters warmed in `new`) | layer Start | Effects | 3D | OK. Rate limit 0.09 s; a load wait of more than 0.25 s is skipped. NOTE: 3 pooled emitters, so a 4th planting within ~3 s moves the attachment and a queued Sink of pile 1 can sound at pile 4 |
| 5 | Interaction clicks Bubble04/06, MenuClick, UpgradeClick, Equip, KaChing, GemClaim | InteractionAudio (ButtonHighlights, HudLayout, EconomyClient, ChestIndex, InteractionFeedback, Tutorial, GardenWallet, FruitGift, PackOpening) | button press / confirmed transaction | local `Activated` (0 latency); KaChing/Equip/GemClaim/Harvest after the server reply (RTT, success only, by design) | yes (module load + SettingsClient) | 15 ms / 100 ms entries | Interface | 2D | OK. 0.09 s per-key de-dupe; a cold click is dropped. HUD/menu buttons set `ButtonSound=false` so they never double with MenuClick |
| 6 | Pack click Bubble04 | PackOpeningFeedback `pulse` | bag shake | local click; server echo only if ahead | yes | 100 ms | Interface | 2D | OK. No double: the echo only fires when `serverCount > count` |
| 7 | Reveal Whoosh/Impact/Royal/Chime (9120768742, 9120769331, 12222253, ping) | RarityRevealAudio via PackOpeningFeedback | rarity screen build, seed burst | `RevealAt` attribute (one-way latency) | yes | .44 / .04 / 0 | Effects | 2D | **FIXED**: `Begin(rank, elapsed)` now joins the whoosh mid-build so its peak lands on the burst. A stale opener chime (>0.35 s, burst ring already gone) is dropped. Burst/Step were already frame-synced |
| 8 | Paper tear (9125725227) | SeedPackClient | bag tears + scraps | `RevealAt` (one-way latency) | yes | 0.10 | Effects | 3D (bag) | **FIXED**: played only if the reveal arrived <0.10 s after RevealAt, so most real pings got no tear. Now plays up to +0.25 s late (scraps still flying) with its 0.18 s envelope shifted to start then |
| 9 | Heavenly chord (ping x3-4) | SeedPackClient | rank 4+ seed appears | same timeline as #7 Burst (SeedAt) | built-in | 0 | Effects | 3D | OK. Layered on #7 by design; 2.4 s cooldown |
| 10 | Frostbell jingle (ping) | FrostbellMotion / HeldHarvestRig | bell strike | client animation phase | built-in asset | 0 | Effects | 3D | OK |
| 11 | Refresh countdown 3-2-1 (ping) | TrackRefreshSky | wall sign "3s/2s/1s" | server deadline attribute, client clock | yes | 0 | Effects | 2D | **FIXED**: the wall repaint was throttled to 10 Hz, so the number changed up to 100 ms after the beep (test: old `-1,-1,1`, new `3,2,1`). It now repaints on the beep frame |
| 12 | Start horn (9120386436) | RefreshHorn | track reopens | `BiomesRefreshing` -> false (same replication as the wall removal) | yes | StartTime attr | Effects | 2D | OK. Falls back to the ping if not loaded |
| 13 | Chase alarm (135684635714618 / fallback 3992992190) | ChestRunAlert | "RUN!!" label + chase vignette | server `Show` | **FIXED**: the id arrived only with the first Show, so it downloaded then and started late. ChaseService now publishes `AlarmSoundId` on the remote and the client preloads it. Play goes through SoundTiming (0.5 s stale guard) | 0 (unmeasured) | Effects | 2D | FIXED. Same RenderStepped as the label |
| 14 | Heartbeat (6724333590) | ChestRunAlert | danger vignette strength | server proximity at 10 Hz, smoothed | yes | n/a loop | Effects | 2D | OK |
| 15 | Success (82180364878410) | ChestRunAlert | green wash | server `Success` | yes | 0 | Effects | 2D | OK. Same call as the wash |
| 16 | Keeper close ping (ping + EQ) | KeeperNearAlarm | keeper distance | proximity stream | yes | 0 | Effects | 2D | OK. Interval 0.8-1.25 s |
| 17 | Keeper hit snap / bat slap (138131702183716 / 81700629330286) + catch voice | KeeperHitEffects (**do-not-touch**) | strike contact burst / ring | server `KeeperHit` with stamp | yes | .040 | Effects | 3D | **NOTE (main session)**: the stale guard is `>2 s`, so a hit can play its snap and voice up to 2 s after the strike pose (KeeperStrikeFrames). Suggest ~0.35 s for audio and burst |
| 18 | Keeper voices (KeeperVoices 9113980319, ...; Knight 100834376603587) | BeastAnimation (**do-not-touch**) | ALERTED/CHASING state | replicated GuardianBehavior attribute | yes (KeeperHitEffects preload) | Knight .225 | Effects | 3D | OK. NOTE: the per-stage Gap repeat is fine; the wake roar coincides with the alarm (#13) and chase music by design |
| 19 | Snore (9113862735) | KeeperSleep | sleeping keeper + Zzz | client state | yes (probe) | n/a loop | Effects | 3D | OK |
| 20 | Storm thunder / rumble (9120016037 / 9120018695) | StormWeather | lightning strike / warning ring | server strike state; impact skipped if >0.6 s late | yes | 0 | Effects | 3D | OK. One per strike id |
| 21 | Ambient thunder (9120016037) | WorldEvents | distant bolt + flash | local timer | **FIXED**: not preloaded here (only when the storm biome script had run), so the first bolt's thunder could be late or dropped | 0 | Effects | 2D (folder) | FIXED |
| 22 | Notice cues RarePack / WeatherAdopted (118818986767152 / 133449446616894) | NoticeFeed83 | notice line appears | plays when the line is shown | **FIXED**: they warmed only on the first Push, so the first rare-pack cue was always skipped (cold cues are skipped). NotificationClient83 now calls `Feed.Preload()` at start | 0 | Interface | 2D | FIXED |
| 23 | Music: playlist, scenic, chase, special (1846088038, 1844513698, 1839530854, 96110001912212, 9042664292, ...) | BackgroundMusic | track zone / chase start | `ChestChaseRunActive` attribute (same server step as alarm) | yes (waitForTrack) | n/a | Music / Chase | 2D | OK. Crossfades 0.45-1.25 s |
| 24 | Biome beds (BiomeMood.Audio) | BiomeAmbience | biome stage | 10 Hz position | yes | n/a | Ambience | 2D | OK |
| 25 | Footsteps | QuietFootsteps87 | n/a | engine | n/a | n/a | n/a | n/a | Intentionally muted |
| 26 | GamePass purchase KaChing | GamePassClient (**do-not-touch**) | purchase success | server reply | yes | 0 | Interface | 2D | OK |
| 27 | Treadmill / trail / boot effects | TreadmillFx, RunnerTrail*, RunnerBootFx | n/a | n/a | n/a | n/a | n/a | n/a | No sounds in these systems |

Server side: no Sound instances are created on the server. ChaseService/ConcurrentKeeperService only send ids/volumes to clients.

## Leading silence (not measured)

SoundTiming has measured offsets for 5 ids only. These play from 0 with unknown front silence: 113339179211972 (veiled arrival),
135684635714618 (alarm), 81700629330286 (slap), 118818986767152 / 133449446616894 (notice cues), the KeeperVoices ids and
82180364878410 (success). If any sounds late in Studio, set `Start_<id>` (seconds) on the SoundTiming ModuleScript. No code
change is needed. A generic version of the DigSoundAnalyzer onset tool would measure them.

## For the main session (files I must not edit)

1. **KeeperHitEffects**: lower the `>2` s stale guard on `KeeperHit` (snap, voice and burst) to about 0.35 s so a late packet
   cannot play a hit long after the strike pose.
2. **WorldStatusHud**: if it shows a refresh countdown, it should repaint on the same second boundary as TrackRefreshSky's beep
   (`math.ceil(deadline - now)`, read every frame rather than throttled).
3. **BeastAnimation**: no change needed. The voice is already preloaded and gated.

## Verification

- `docs/proposals/audio_R123/tests/run.sh`: **22 checks, 0 failures**. The same test on the pre-R123 sources gives 14 failures,
  including the wall number lagging the beep (`-1,-1,1`).
- Re-run: holes_R122 (91 + 64 pass), veiled_R122 (92 / 73 / 37 pass), perf_R121 (no mismatches), wall_notifier_R122
  wall_test (158 pass).
- `luau-compile` on all 451 `src` scripts: 0 failures. `luau-lsp analyze` on the changed files: no new diagnostics apart from
  sourcemap "unknown require" noise of the kind the other files already show.
- Reasoned only, not run in Studio: actual asset load times, the leading silence of unmeasured ids, and how audible the
  late-tear path is.
