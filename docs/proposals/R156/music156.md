# R156: music (track playlist, three more base tracks, louder track ambience)

Owner: "for the track ambience and pre existing music we can just increase the volume by a bit and add these sound tracks 74095461107598, 132448918728086, that alternate.
for base music we can add these tracks 1837487700, 1837487818, 1836280952."

## What plays where

| Where | What | Volume |
|---|---|---|
| Track (`insideTrack`) | a playlist of three, in this order, forever: Nature Inspiration `96110001912212` -> `74095461107598` -> `132448918728086` -> Nature Inspiration ... | `.07` each (was `.055`) |
| Base | the base playlist, random start, in order, 3 s crossfade: Morning Mood `1846088038`, Clair de Lune `1844513698`, then "Base track" `1837487700`, `1837487818`, `1836280952` (real titles not known) | `.2` (unchanged) |
| Chase | the GTA chase theme (`.10`) or The Darkened's theme (`.16`); the track music fades out and pauses, then resumes where it was | unchanged |
| Track ambience | birds / leaves / wind / crystal hum / rumble of the track stages 1-7 | x1.25 (stage 0, the weather rules and the R156 weather beds are unchanged) |

How the track playlist behaves: each track plays once to its end. 3 s before the end (`PLAYLIST_CROSSFADE_SECONDS`) the next one starts from 0 and the two cross over (the volumes add up to `.07`
all the way); the old one is then stopped and rewound. Leaving the track fades out (1.2 s) and pauses where it is; coming back resumes the same track at that position. Leaving in the middle of a
crossfade makes the incoming track the one that resumes. A track that does not load (10 s, 3 tries) is skipped with the usual `Music not ready: ...` warning (once a minute per track); one that
arrives late joins the rotation; a track alone loops; none loaded = silence, and the base music is not ducked. All three sounds are named `BiomeScenicMusic`, so `AudioMixer.Route` keeps them on
the Music slider (same `ChestChaseMusic` SoundGroup as the base music). The only work while idle is a read of three Sounds' properties every 0.1 s; nothing is created per frame.

## How to change it

- Track volume: `SCENIC_VOLUME` in `BackgroundMusic.client.lua` (one number for all three).
- Track order / tracks: `SCENIC_PLAYLIST` (the first entry is the one that starts). Crossfade length: `PLAYLIST_CROSSFADE_SECONDS` (shared with the base playlist).
- Base tracks: `PEACEFUL_PLAYLIST` (add an entry); base volume: `PEACEFUL_VOLUME`.
- Track ambience: `TRACK_GAIN` in `BiomeMood.lua` (x1.25).

## Files

- `src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua`: the track playlist, `SCENIC_VOLUME`, the three base tracks (line 1 and the base playlist code are as they were).
- `src/ReplicatedStorage/BiomeMood.lua`: `TRACK_GAIN`, applied in the `stage==1..7` branches of `SoundTargets`.
- Tests: `docs/proposals/R156/tests/run_music156.sh` + `test_music156.luau` (new, 140 checks + 20 breaks it must catch; registered in `tools/tests/run_all_suites.sh`), `test_weather_ambience.luau` (its reference formula now has the track stages x1.25) and `run_weather_ambience.sh` (two more breaks).
- The older "BackgroundMusic untouched" checks accept exactly this script by hash: `docs/proposals/R151/tests/frozen.sha256` (new line + note), `tools/tests/bgm_frozen.sh` (new, a small helper), and a one-line `|| sh bgm_frozen.sh` in `R153/tests/run_fixes_client.sh`, `run_fixes_server.sh`, `run_perf153.sh`, `run_track_walls.sh`, `R154/tests/run_luck_odds.sh`, `run_perf154.sh`, `R155/tests/run_camera155.sh`, `run_pity.sh` and `R156/tests/run_weather_ambience.sh`.
  Any other edit of BackgroundMusic changes the hash and those checks fail again.
- Not done here: `installers/R156_install.lua` and `docs/releases/R156.md` were built before this change (they say BackgroundMusic is not touched); the release step has to add BackgroundMusic and the new BiomeMood.
