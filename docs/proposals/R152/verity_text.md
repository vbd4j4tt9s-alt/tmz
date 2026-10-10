# R152: Verity's quest texts with personality

> **Update (R152 text pass).** The owner then asked for every text in the game to be typed "like how I talk", so the words of this window were rewritten once more
> (casual, "u" / "ur", still bubbly): the new wording of every line is in section "10. Verity" of [`game_text.md`](game_text.md), and [`verity_text.png`](verity_text.png)
> is redrawn with it. The tables below keep the wording of the first pass (the "New" column) as history.

Owner: "add more personality to the texts above" (the quest window of Verity, the big yellow ball behind the market).

Voice: cheerful, bubbly, a little cheeky and dramatic about The Darkened One, kid friendly, short. Every line still says what to do:
steal a Void Pack from The Darkened One at the end of Storm Peaks, bring it to Verity, get a Verity Pack. Words only: no number, no timing
(her greeting still ends at `GreetingEnd` 2.35) and no rule changed, `Config.Version` is untouched.

Picture of the window in its main states (computer, phone upright, phone sideways, her sign, her prompt, the two notices): [`verity_text.png`](verity_text.png).

All her copy now lives in one place, `src/ReplicatedStorage/VerityConfig.lua` ("Texts" block: `Quest`, `RewardText`, `Thanks`, `Notice`, `Dialog`, `Hint`,
`Reasons`, plus `Event`, `PromptActionText`). The window's own labels used to be literals inside `VerityClient.client.lua`; they are in `C.Dialog` now.

## Old text -> new text

### The quest line

| # | Where | Old | New |
|---|-------|-----|-----|
| 1 | `C.Quest` (window, top) | Steal a Void Pack from The Darkened One at the end of Storm Peaks and bring it to me. I'll give you a Verity Pack! | I dare you to steal a Void Pack from the scary Darkened One at the end of Storm Peaks! Bring it to me and I'll give you a Verity Pack! |

### The line about The Darkened (purple while it is here, blue before; hidden when the server has no schedule, as before)

| # | State | Old | New |
|---|-------|-----|-----|
| 2 | here now | 🌑 THE DARKENED IS HERE NOW! | 🌑 EEK! THE DARKENED IS HERE NOW! |
| 3 | not here yet (countdown) | 🌑 THE DARKENED ARRIVES IN 12m 3s | 🌑 THE DARKENED WAKES IN 12m 3s |
| 4 | the countdown reached 0, waiting for the server | 🌑 THE DARKENED IS ARRIVING... | 🌑 THE DARKENED IS WAKING UP... |

### The two stat boxes and the exchange

| # | Where | Old | New |
|---|-------|-----|-----|
| 5 | left box title (count below it) | VOID PACKS YOU HAVE | YOUR VOID PACKS |
| 6 | right box title | HANDED IN | YOU GAVE ME |
| 7 | exchange line (`C.RewardText`, next to the two pack pictures; the server sends it) | 1 VOID PACK = 1 VERITY PACK | SWAP! 1 VOID PACK = 1 VERITY PACK |

### The status line under the exchange (new: it was empty until the server answered a hand-in)

The line now says what to do next while nothing else is shown, by what you carry (`C.Hint`). A good answer from the server (the thanks) or a refusal
replaces it, and the next time the window opens it is back. While a hand-in waits for the server the line is quiet.

| # | State | Old | New | Colour |
|---|-------|-----|-----|--------|
| 8 | you carry at least 1 Void Pack | (empty) | Ooh, a Void Pack! Hand it over! | green |
| 9 | 0 Void Packs, The Darkened is here | (empty) | Quick! Steal one in Storm Peaks! | gold |
| 10 | 0 Void Packs, it is not here (countdown or no schedule) | (empty) | Get ready to steal one! | pale blue |
| 11 | the event is over | (empty) | Thanks for playing, you were great! | pale blue |

### After a hand-in

| # | Where | Old | New |
|---|-------|-----|-----|
| 12 | status line, green (`C.Thanks`) | Thank you! Here is your Verity Pack. | Yay, thanks! Here's your Verity Pack! |
| 13 | notification on the HUD for 4 s (`C.Notice`, from the server) | 🌟 Verity gave you a Verity Pack! | 🌟 Yippee! Verity gave you a Verity Pack! |

### The buttons

| # | Where | Old | New |
|---|-------|-----|-----|
| 14 | hand-in button (a no-break space joins "PACK" and the emoji, so a narrow phone wraps "GIVE VOID / PACK 🌑", never the emoji alone) | GIVE VOID PACK | GIVE VOID PACK 🌑 |
| 15 | the same button while it waits for the server | HANDING IT OVER... | SWAPPING... ✨ |
| 16 | the same button, disabled, after the event (`C.Event.Ended`, also on her sign, red) | EVENT ENDED | EVENT OVER! THANKS! |
| 17 | other button | CLOSE | BYE! 👋 |

### Refusals and errors (red status line, `C.Reasons`; shown in capitals, as the game does for refusals)

| # | Key | When | Old | New |
|---|-----|------|-----|-----|
| 18 | `Loading` | your data is not loaded yet | YOUR DATA IS STILL LOADING | HOLD ON, YOUR DATA IS LOADING! |
| 19 | `CannotSave` | your data cannot save | YOUR DATA CANNOT SAVE RIGHT NOW | OOPS! YOUR DATA CAN'T SAVE NOW |
| 20 | `TooFar` | more than 38 studs from her | COME CLOSER TO VERITY | OVER HERE! COME CLOSER TO ME! |
| 21 | `Busy` | carrying a stolen pack, in a run, queued | FINISH YOUR RUN FIRST | WHOA, FINISH YOUR RUN FIRST! |
| 22 | `Moment` | ragdolled / flung, or no body | WAIT A MOMENT AND TRY AGAIN | ONE MOMENT, THEN TRY AGAIN! |
| 23 | `Opening` | a pack reveal is playing | FINISH OPENING THAT PACK FIRST | PLEASE FINISH OPENING THAT PACK! |
| 24 | `NoVoid` | no Void Pack in the bag | YOU NEED A VOID PACK | NO VOID PACK YET! GO STEAL ONE! |
| 25 | `NotReady` | the pack service is missing | VERITY IS NOT READY | I'M NOT READY YET! ONE SEC! |
| 26 | `Failed` | the swap failed or threw | VERITY COULD NOT TAKE IT. TRY AGAIN | OOPS! THAT DIDN'T WORK. TRY AGAIN |
| 27 | `EventEnded` | after the end of the limited event | THE VERITY EVENT HAS ENDED | EVENT'S OVER! THANKS FOR PLAYING! |
| 28 | `Invalid` | the pack id is not an id (cannot happen from her window) | INVALID PACK | HMM, I CAN'T USE THAT PACK |
| 29 | `NotVoid` | the pack named is not a Void Pack (cannot happen from her window) | ONLY A VOID PACK CAN BE GIVEN TO VERITY | ONLY A VOID PACK WORKS FOR ME! |
| 30 | `Gone` | the pack left the bag in between (cannot happen: nothing yields) | THAT PACK IS NO LONGER IN YOUR INVENTORY | THAT PACK LEFT YOUR BAG! TRY AGAIN |

Rows 28 to 30 are the reasons `PlayerDataService:CheckVoidPack` and `ChestService:ConvertVoidPack` give; the hand-in passes them on as they are, so they are in
`VerityConfig.Reasons` too and those two functions read them from there (their literals "YOUR DATA IS STILL LOADING" -> `Loading`, "YOU HAVE NO VOID PACK TO GIVE" ->
`NoVoid`, "WAIT FOR THAT PACK TO FINISH OPENING" -> `Opening`, "INVALID PACK" / "ONLY A VOID PACK ..." / "THAT PACK IS NO LONGER ..." -> `Invalid` / `NotVoid` / `Gone`).
There is no "inventory full" refusal: the swap replaces the Void Pack in its own slot, so a full bag never blocks it.

### Her sign, her prompt and the notice when The Darkened arrives

| # | Where | Old | New |
|---|-------|-----|-----|
| 31 | the timer line on her sign (`C.Event.Prefix`, then the time left) | EVENT ENDS IN 27d 04h 12m 09s | HURRY! ENDS IN 27d 04h 12m 09s |
| 32 | her sign after the end: see row 16 | EVENT ENDED | EVENT OVER! THANKS! |
| 33 | the proximity prompt's action (`C.PromptActionText`; the object text stays "Verity", the prompt is still named `Talk`) | Talk | Say hi! |
| 34 | the notice when The Darkened arrives (`NoticeCopy83.Arrival`, same colours on the same words; "Verity" is gold) | 🌑 The Darkened has arrived...  Two Void Packs await in Storm Peaks. | 🌑 Eek! The Darkened is here...  Two Void Packs await in Storm Peaks. Verity wants one! |

### Not changed on purpose

- Her name and the window title ("🌟 VERITY"), the "!" and "?" markers, the "➜" in the exchange row, the "-" shown before the server has answered.
- Her voice ("Hello, my name is Verity"): audio, `GreetingStart` / `GreetingEnd 2.35`, the greeting distance and cooldown. There are no subtitles for it in the code.
- `NoticeCopy83.VoidShift` ("The void shifts... The Void Packs in Storm Peaks changed."): about the event's packs, not about Verity's quest.
- `WorldStatusHud` (the "THE DARKENED" card in the corner) and the "STEAL / Void Pack" prompt on The Darkened's packs (`VeiledEvent81`, a keeper file): not hers.
- The owner help rows in `StudioTestHelp` / the `/test verity...` replies: not shown to players.

## Fit on phones

Nothing got a new box. The lines are about as long as the ones they replace (the longest status line is as wide as the old longest refusal, about 20 em of
FredokaOne), and every label is fitted by `GardenTextFit`, which takes the largest size that fits. With the real FredokaOne widths (and the emoji font), on a 360 x 640
phone: quest 17 to 18 px in 5 lines, The Darkened's line 16 px, status line 16 px, stat box titles 12 px, exchange line 16 px in 3 lines, hand-in button 20 to 21 px
in 2 lines ("GIVE VOID / PACK 🌑"), BYE! button 20 px. Sideways (844 x 390) the quest is 15 px in 4 lines. The stat box titles are 8 px in the sideways layout as they were
before (their box is 12 px high there).

The test suite checks this on 13 screen sizes, four states each, with the mock's font and again with a font 15% wider than it.

## How the preview is made

`preview/verity_text.html` is an HTML drawing of the window (layout and text fitting ported from `VerityClient.client.lua` and `GardenTextFit.lua`, real FredokaOne);
`preview/copy.json` holds the strings, printed from the real `VerityConfig` and `NoticeCopy83` on the Roblox mock; `preview/render_verity_text.mjs` renders it with
Playwright and Chromium:

```
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers node docs/proposals/R152/preview/render_verity_text.mjs     # writes docs/proposals/R152/verity_text.png
```

## Tests

`docs/proposals/R147/tests` (`run_verity.sh`, `run_verity_pack.sh`) pin the new words and check them: the quest and every other text, the status line in every state
(section 4b of `test_verity_client.luau`), no old wording left, the sign timer, the end of the event, every reason through the real `PlayerDataService` and
`ChestService`, the 13 screen sizes with four Open states each, and one-line texts readable (12 px) with the wider font. The full runner `tools/tests/run_all_suites.sh` passes.
