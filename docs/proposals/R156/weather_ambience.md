# R156 weather ambience

The owner uploaded three looping ambiences. Each now plays during its own weather.

| Weather (`ReplicatedStorage` attribute `GlobalWeather`) | Sound | Asset id | Volume |
|---|---|---|---|
| Rain | `WeatherRainAmbience` | 107960597100236 | 0.30 |
| Thunderstorm | `WeatherThunderAmbience` | 137593145026034 | 0.32 |
| Blizzard | `WeatherBlizzardAmbience` | 87749574738390 | 0.30 |
| Clear, Cloudy | none | | |

## What plays where

- Only off the track (`stage == 0`: the base and hub), while the character is alive. Only the bed that matches the weather plays, never two.
- The track (stages 1-7) is silent, like its weather. Walking onto it fades the bed out; coming back fades it in.
- Rain to Thunderstorm (or any change) is a crossfade: the old bed fades out while the new one fades in. A bed that has faded to 0 is paused, so it costs nothing.
- The existing beds (Birds, Leaves, Wind, Crystal, Rumble) give exactly the same targets as before.

## Volumes

All three are in one table in `src/ReplicatedStorage/BiomeMood.lua`:

```lua
M.WeatherBeds={Rain={Key='RainBed',Volume=.3},Thunderstorm={Key='ThunderBed',Volume=.32},Blizzard={Key='BlizzardBed',Volume=.3}}
```

For louder or quieter, change the `Volume` number (0 to 1) and nothing else. The player's Ambience slider is applied on top.

To swap an upload without a code change, set an attribute on the `BiomeMood` module: `RainBedAssetId`, `ThunderBedAssetId` or `BlizzardBedAssetId`, to the new id. A bad value gives no sound rather than a wrong one.

## Slider and chase

- The beds are routed to the Ambience SoundGroup, so they follow the Ambience slider (0 mutes them).
- In a chase every target is multiplied by 0.12, the beds included, so the weather ducks under the chase music and comes back after.
- The track-refresh rule only changes Birds, Leaves and Wind, as before; it leaves the beds alone.
- Fades use the existing alpha in `BiomeAmbience.client.lua`: about a second to get most of the way in the base, several times faster in a chase.

## Files changed

- `src/ReplicatedStorage/BiomeMood.lua`: three rows in `M.Audio`, `M.WeatherBeds`, the three new keys in `M.SoundTargets`.
- `BiomeAmbience.client.lua` needed no change. It builds, preloads and fades one Sound per `M.Audio` row, and its 12 second "unavailable" warning names the sound (for example `WeatherRainAmbience`). Its line 1 is untouched.
- `tools/tests/run_all_suites.sh`: runs the new suite.
- `docs/proposals/R156/tests/test_weather_ambience.luau` and `run_weather_ambience.sh`: the tests. `BackgroundMusic.client.lua` and `Config.lua` are untouched, which the runner checks.
