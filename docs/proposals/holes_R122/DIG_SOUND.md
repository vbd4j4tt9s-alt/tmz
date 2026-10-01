# Shovel dig sound: cutting one recording into dig variants

The dig and cover sounds come from one long recording, `rbxassetid://93793180254708`, which holds several digs.
Each time someone digs, the game plays one short piece of it. It picks a piece at random, never plays the same
piece twice in a row, and changes the pitch slightly (0.93 to 1.07). Covering a hole plays a piece a little lower
(x0.86). The sound comes from the hole, so only nearby players hear it (roll-off 12 to 150 studs). It plays
through the AudioMixer **Effects** volume.

All settings are in `ReplicatedStorage.TrackHoleConfig`, in the `DigSound` table.

## Where the pieces come from

The game uses the first of these that exists:

1. **The `DigSegments` attribute** on the `TrackHoleConfig` ModuleScript. This is JSON, written by the tool below.
2. **`DigSound.Segments`** in `TrackHoleConfig`. This is a Lua list such as `{{Start=0.49,Length=0.24},...}`, in seconds.
3. **The fallback.** Once the sound has loaded, the game splits its full length into `FallbackVariants` (6) equal
   pieces. Each piece is at most `MaxLength` (1.2 s) long.

The game works with nothing set up, because it uses the fallback. The fallback pieces may start a little before a
dig or in the middle of one. Run the tool once to get clean cuts.

## Finding every dig (Studio, about one minute)

1. Press **Play** in Studio. In the Command Bar, switch the context to **Client** so you can hear the sound.
2. Run:
   ```lua
   require(game.ReplicatedStorage.DigSoundAnalyzer).Run()
   ```
   The tool plays the recording once through the Audio API (`AudioPlayer` -> `AudioAnalyzer`, plus
   `AudioDeviceOutput` so you hear it). It reads `PeakLevel` on every frame. A dig counts as "heard" when the level
   rises above the threshold after a quiet gap. Each piece starts 0.03 s before the dig and ends when the sound dies
   away, or just before the next dig.
3. The Output window lists every dig, then two save lines:
   ```
   [DigSound]  #1  dig heard at 0.517 s   variant 0.487 -> 0.727 s ...
   Segments={{Start=0.487,Length=0.240},...},
   game.ReplicatedStorage.TrackHoleConfig:SetAttribute('DigSegments','[...]')
   ```
   The new pieces work in this play session right away.
4. To listen to the pieces one by one:
   `require(game.ReplicatedStorage.DigSoundAnalyzer).Preview()`.
5. **Save them** (changes made during Play mode are lost when you stop). Do one of these:
   - Paste the `Segments={...},` line into `TrackHoleConfig.DigSound`, replacing the empty `Segments={},`.
   - Stop the game and run the printed `SetAttribute(...)` line in the Command Bar in Edit mode.

### Tuning

Pass options to `Run`, for example `Run({Sensitivity=.2, QuietGap=.1})`:

| Option | Default | Effect |
|---|---|---|
| `Sensitivity` | 0.3 | Threshold = floor + (peak - floor) x this. Lower finds quieter digs. |
| `Threshold` | auto | Sets an exact level (0-1) in place of the automatic one. |
| `QuietGap` | 0.12 s | Silence needed before a new dig counts. Lower splits digs that are close together. |
| `Preroll` / `Tail` | 0.03 / 0.06 s | Extra time kept before the start and after the end of each dig. |
| `MinLength` / `MaxLength` | 0.08 / 1.2 s | Pieces shorter than the minimum are dropped. Longer ones are cut. |
| `Use` | `'Peak'` | `'Rms'` uses `RmsLevel`, which is smoother. |

- If two digs come out as one piece, lower `QuietGap`.
- If scrapes or noise come out as digs, raise `Sensitivity`.

## Files

- `ReplicatedStorage/DigSoundVariants.lua`: chooses the pieces (attribute, then list, then fallback), picks one
  with no repeats, plays it positionally and stops it at the piece's length. It also holds the dig detector.
  - The piece start is set here and not with `SoundTiming.Play`, because SoundTiming caps start times at 10 s and
    this recording is longer.
  - It keeps SoundTiming's rule of skipping a sound that loads too late.
- `ReplicatedStorage/DigSoundAnalyzer.lua`: the Studio-only tool (`Run`, `Preview`, `Report`).
- `StarterPlayer/StarterPlayerScripts/TrackHoleClient.client.lua`: plays a piece for every dig or cover event.
- Offline tests are in `tests/test_holes_client.luau`, section 4 (variants) and sections 5-6 (detector and tool on
  synthetic levels). Nobody has listened to the real recording yet.
