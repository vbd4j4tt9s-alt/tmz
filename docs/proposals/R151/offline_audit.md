# R151 offline audit: the "your plant is ready" notifier, the Esc-menu text, and other notices

Owner: *"search for cases where the offline notifier or some things will just not function as intended and make sure they are fixed; for the offline text when players press esc just make it a simple big rainbow text that says "Plants grow offline""*

Preview: `docs/proposals/R151/offline_text.png` (made by `docs/proposals/R151/preview/run_offline_text_preview.sh`).
Tests: `sh docs/proposals/R151/tests/run_offline.sh [scratch dir]` (the new plant-notify test + the R140 and polish_R124 suites).

## In short

- **The notifier mostly worked on a quiet day with one server, and failed in the common real cases.** It lost every player's notification when a server shut down (game updates), handled only 20 entries a minute for the whole game, threw away the second plant of a day, lost entries on any error, and could hide a later plant behind one ready in 2 minutes. All of these are fixed and tested (A1–A8).
- **Two things code can't fix:**
  - The setup the owner has to do (checklist below).
  - Roblox's own rules: 1 notification per player per day, only for players who are 13+ and opted in, and only sent while some server of the game is running.
- **The Esc text is now one big line:** `🌱 Plants grow offline` in Fredoka One, with a sliding rainbow and a dark outline. It sits in the free band below Roblox's menu on computers and on the bottom edge on phones.
  - Roblox draws its menu and its dimming above every game GUI, so the line is dimmed on all screens. On phones it can only show faintly through the menu sheet. No game script can draw on top of Roblox's menu.
- **Notice sweep:** the daily login window never opened by itself for returning players, because it gave up while the title screen was up. That's fixed. The other findings are listed in C.

## A. The offline "your plant is ready" notifier

Code: `src/ServerScriptService/ChestChaseServer/SocialService.lua` (+ one `BindToClose` line in `ChestChaseServerMain`, the owner command in `OwnerUpdateCommands82`, the opt-in in `DailyRewardsClient`).

**How it works now:**
1. **When a player leaves**, their earliest plant that is ready at least 5 min later goes into a shared MemoryStore sorted map (`PlantReady140`), keyed by user id and sorted by the ready time.
2. **Every minute, any running server reads the due entries** in pages, up to 300 a pass. It claims each one with `UpdateAsync`, and the committed value decides which server owns it. Then it checks the shared 24 h cooldown (`PlantReadySent140`) and sends `POST https://apis.roblox.com/cloud/v2/users/{id}/notifications` with the key from the `PlantReadyKey` secret.
3. **What happens after the send:**
   - Success: the entry is removed and the cooldown starts.
   - A passing failure: the entry is tried again after 2, 4 and 8 min.
   - A setup failure: the entry is kept, and that server pauses for 10 min.
   - A player who is back in the game: their entry is cancelled on join, and cleared again every 2 min.

| # | Case | Status | Severity | Evidence (R140 code) | Fix + test (`test_plantnotify.luau` unless named) |
|---|---|---|---|---|---|
| A1 | **Server shuts down** (update, "shut down all servers", Studio stop). | CONFIRMED | High | `BindToClose` ran `PlayerDataService:Shutdown`, which marks every profile `Finalizing` before it yields, so `IsLoaded` was false. The `PlayerRemoving` that the shutdown fires then reached `Schedule`, which returned false, so nothing was queued. Nothing waited for the spawned `SetAsync` either. | `SocialService:Shutdown` has its own `BindToClose`. It queues everyone whose garden is still readable (`Loaded` is still true while finalizing), stops sending, and waits up to 8 s for the writes. A `PlayerRemoving` after that doesn't write again. The order of the two callbacks doesn't matter. Section 2 (8 checks). |
| A2 | **Two servers claim the same entry.** | CONFIRMED | Medium | Roblox re-runs an `UpdateAsync` transform when another server committed first. R140 kept `claimed` from the first run (`claimed.Claimed==game.JobId`), so the loser also sent. In Studio every local server has the same empty `JobId`. Roblox's 1/day throttle usually refused the second one, so the visible cost was a wasted call and a console error. | The winner is read from `UpdateAsync`'s committed return value, and each server has a GUID token. Section 4, which fails on the R140 file. |
| A3 | **A busy game.** | CONFIRMED | High | Each pass read only the first 20 due entries (`GetRangeAsync(...,20,...)`), and every server read the same 20. So about 20 a minute went out for the whole game, and the rest aged past their 1-day lifetime unsent. | Paged reads (100 a page, up to 300 a pass), and each server walks the page from a random start. 250 due entries all went out in one pass of two servers, none twice (R140: 20 + 20). Section 5. |
| A4 | **The second plant of a day.** | CONFIRMED | High | The cooldown was 12 h, but Roblox delivers **1 notification per player per day** and answers `429 RESOURCE_EXHAUSTED` ("1 notification per recipient"). The 2nd send in 12–24 h was refused, warned about, and its entry was already deleted. | The cooldown is 24 h. An entry that becomes due inside it waits until the cooldown ends, if that's at most 24 h after the plant was ready; otherwise it's dropped. Roblox's own 429 starts the cooldown and is not retried or logged as an error. The cooldown row is shared by all servers. Section 6. |
| A5 | **A plant ready within 5 min hid later plants.** | CONFIRMED | Medium | `NextReady` returned the earliest ready time, and `Schedule` gave up when that was under 5 min. A player leaving with fruit due in 2 min and a plant due in 2 h got nothing. | It now picks the earliest time that is at least 5 min out. Section 1. |
| A6 | **Any failure lost the entry.** | CONFIRMED | Medium | The entry was removed before sending, so a 5xx, a timeout, HTTP off, a missing secret or a refused key each ate an entry, with one console line per entry. | Passing failures (429 not per recipient, 408, 5xx, network) are retried after 2, 4 and 8 min, then dropped and counted. Setup failures (HTTP off, no secret, 401/403, "not allowed", GameId 0) keep the entry and pause that server 10 min, with one console line an hour that names the fix. A 400 drops the entry and points at the MessageId. Section 7 (11 checks). |
| A7 | **A server dies mid-send.** | PLAUSIBLE | Low | The claim set a 120 s life and the entry was removed right after. A crash between the two meant the entry quietly expired. | A claim lives with the entry, and another server takes over a claim older than 5 min. Section 4. |
| A8 | **Rejoin race.** The player's old server writes the entry after the new server already cancelled it: a crash seen late, or a quick server hop. | PLAUSIBLE | Medium | `Cancel` ran once, on join. The late write stayed, and another server sent "your plant is ready" while the player was playing. | `Sweep`: every 2 min a server clears the entries of the players in it. Players who are leaving are skipped. Section 8. |
| A9 | **No server running at the ready time** (quiet game). | CONFIRMED (inherent) | Low | Roblox has no scheduled sends, so entries wait for the next server. Its first pass came about 60 s after start. | The first pass now runs 15 s after a server starts. Entries up to 24 h past their ready time are still sent (the plant is still ready); older ones are dropped. The only full fix is an external sender (see below). Section 3. |
| A10 | **Missing setup was silent.** | CONFIRMED | Medium | MessageId missing: off, with no word in Studio. HTTP off or no secret: nothing until a send failed, live, one line per entry. | At server start the console says what is missing (and in Studio also that it is off). The `/test plantnotify` command has `status`, `send` and `reset`. Section 10. |
| A11 | **A MessageId pasted with spaces or quotes.** | CONFIRMED | Low | It passed the length check and was sent as is, so Roblox refused it with 400. | The id is trimmed. Section 0. |
| A12 | **Unpublished place** (Studio, GameId 0). | CONFIRMED | Low | It sent `universes/0` and got a 4xx. | Reported as a setup problem. Section 9. |
| A13 | **MemoryStore size quota.** | PLAUSIBLE | Low | The quota is 64 KB + 1 KB per player **online**, but cooldown rows live 24 h per player **notified**. | The cooldown row is now a single number. Write failures are logged once an hour. Request use (about 4–6 calls per notification, 0.5 per online player a minute) is far below 1000 + 100 × online players a minute. |
| A14 | **Opt-in prompt.** | CONFIRMED (one case) | Low | When `CanPromptOptInAsync` errored (web hiccup), the session's only try was used up. | It is tried again at the next planting. `test_daily_client`, which fails on the R140 file. |
| A15 | **Ready times read from stale data.** | CHECKED OK | – | Crop times are absolute `os.time()` stamps. The 2x pass shortens the stored times when bought (`GrowthBoostRules`), regrowth and fence durations are stored per fruit, and weather and mutations change value, not time. GrowthPace125 applies to the catalog at planting. A harvest just before leaving is already in the garden. | Nothing to fix. A player who buys the 2x pass on the website while offline keeps the stored times until they join, so the notification still matches the game. |
| A16 | **Clock.** | CHECKED OK | – | `os.time()` (UTC) for crops, the queue and the cooldown. Server clock skew is seconds, against 5 min claims and 1 min polls. | – |
| A17 | **Request shape.** | CHECKED | – | It matches the Open Cloud reference schema `UserNotification`: `source.universe`, then `payload.messageId` / `type: MOMENT` / `parameters.plantName.stringValue` / `joinExperience.launchData` (200 bytes max) / `analyticsData.category`, in camelCase as in the reference and Roblox's own Luau package. HttpService only allows the `x-api-key` and `content-type` headers, which is exactly what is sent, and the key is a `Secret`. | Section 9 checks every field. **Risk:** the guide lists CreateUserNotification as callable from HttpService, but the reference file flags it `apiKeyWithHttpService:false`. If `/test plantnotify send` reports "not allowed", game servers cannot call it and an external sender is needed (below). The guide's curl example puts `join_experience` / `analytics_data` outside `payload`; the reference schema and the Luau package put them inside, which is what we do. |
| A18 | **A player rejoins in the second before a send.** | PLAUSIBLE | Negligible | `Cancel` removes the entry; a server that already claimed it may still send within that second. | Accepted. |
| A19 | **Under 13, not opted in, never planted.** | By Roblox's design | – | Roblox doesn't deliver, and still answers 200. Players who never planted are never asked to opt in and have nothing queued. | – |
| A20 | **Friend boost.** | CONFIRMED | Low | A failed `IsFriendsWith` was only tried again on the next join, so two friends could play a whole session without the boost. | Tried again 30 s later. Section 11. |

The R140 `SocialService` fails **20 of the 34 checks it reaches** in `test_plantnotify.luau` (the cases that call new methods stop early). The R140 `DailyRewardsClient` fails 3 checks in `test_daily_client`.

### If game servers cannot call the API (A17), or the game is often empty (A9)
Run the same queue from outside Roblox, for example a small scheduled job such as a cloud function or a GitHub Action every 5 minutes. Use an API key with `memory-store` read/write and `user-notification` write. It should:
1. List due items with the Open Cloud `ListMemoryStoreSortedMapItems` (`PlantReady140`, filter `sortKey <= now`).
2. Send them with `CreateUserNotification`.
3. Delete them with `DeleteMemoryStoreSortedMapItem` and write the cooldown row.

The data format is in `SocialService.lua`. This is not built; it's the owner's choice.

## Owner setup checklist (one time; code can't do these)
1. **Create a notification string.** Creator Dashboard → your experience → Engagement → Notifications → create a string, for example `Your {plantName} is ready to pick! 🌱`. The parameter must be named exactly `plantName`. Copy its **asset id**.
2. **Set the MessageId in Studio.** Add a string attribute `MessageId` on `ServerScriptService.ChestChaseServer.SocialService` and paste the id. Spaces or quotes around it are fine now.
3. **Create the API key.** Creator Dashboard → Open Cloud → API Keys → Create:
   - Access: **user-notification**, this experience, **write**.
   - IP restrictions: `0.0.0.0/0`, since the calls come from game servers.
   - Note the expiry date if you set one.
4. **Add the secret.** Creator Dashboard → your experience → **Secrets** → Create:
   - Name: `PlantReadyKey`. To use another name, also set a `SecretName` attribute on SocialService.
   - Value: the key.
   - Domain: `apis.roblox.com`.
   - To test in Studio: File → Experience Settings → Security → **Local Secrets**, with the same name.
5. **Allow HTTP requests.** Game Settings → Security → **Allow HTTP Requests: ON**, then publish.
6. **Check Roblox's conditions:** at least 100 visits, and the game is not under moderation.
7. **Live check.**
   - Join a live server and type `/test plantnotify`. Expect `Plant-ready notifications: ON` and no problems listed.
   - Then `/test plantnotify send`. It sends you one right away, if your account is 13+ and opted in (Roblox → Settings → Notifications, or say yes to the prompt that appears after planting).
   - This uses Roblox's one-per-day allowance for you. `/test plantnotify reset` clears the game's cooldown, but not Roblox's.
8. **Real flow.**
   - Plant something that takes 10+ min and leave.
   - Keep some server running at the ready time: another account in the game, or someone playing.
   - The notification should arrive within about a minute of the ready time. Don't rejoin before then: joining cancels it.
9. **Watch the logs.** Developer Console → Server: lines start with `[R140]`. A setup problem is printed once an hour per server, and the server waits 10 min before trying again.

## B. The Esc-menu text
Code: `src/StarterPlayer/StarterPlayerScripts/OfflineGrowthNotice.client.lua`. It replaces the R125 card.

### Look
- **The words:** one line, `🌱` + `Plants grow offline` (owner's words). The plant count is dropped, as the owner asked for something simple.
- **Letters:** Fredoka One, white, with a 7-stop `UIGradient` rainbow over the whole colour wheel. The first and last stop are the same hue, so it loops without a seam.
- **Motion:** while the menu is open the rainbow slides about one turn every 4.5 s, updated 30 times a second. With Reduced Motion it is a still rainbow and nothing runs per frame.
- **Outline:** a dark `UIStroke` (22,14,38), rounded, about size/13 thick.
- **No panel:** no background, card or corner anywhere.
- **Emoji:** the 🌱 is its own label, so the gradient doesn't tint it.

### Where it goes
Roblox's menu is CoreGui and is drawn above every game GUI, with the whole screen dimmed. The line therefore goes in the biggest free band around the menu panel. The panel size comes from the 2026 CoreScripts (`Settings/SettingsHub.lua`, `Settings/Theme.lua`, MaximumADHD/Roblox-Client-Tracker):

| Screen | Roblox menu | Where the line goes | Text size |
|---|---|---|---|
| Computer, tablet (not a small touch screen) | A panel 840 px wide and min(600, 90% of height − 120) + 134 px tall, centred 10 px below the middle | The larger of the bands above and below the panel (below the top bar) | 78% of the band, 22–100 px |
| Console (10-foot UI) | min(800, 86% − 200) + 214 px tall | The same rule | Same |
| Phone (touch, under 500 px tall or 700 px wide) | A bottom sheet over the whole height | The bottom edge, seen through the sheet | 10% of the height, 30–56 px |
| Any screen with no band of at least 34 px (for example a 1366×768 laptop) | – | The bottom edge | Same as phones |

- **Safe area:** the `ScreenGui` uses `ScreenInsets = DeviceSafeInsets`, so it stays clear of notches, the home bar and TV edges. The line is at most 92% of the safe width and shrinks to fit.
- **DisplayOrder 10001:** above every game GUI, including the 10000 title screen.
- **Rotating or resizing** re-fits the line while the menu is open.

### Showing and hiding
- `GuiService.MenuOpened` / `MenuClosed`, plus `GetPropertyChangedSignal('MenuIsOpen')` as a fallback: either is enough.
- If the menu is already open when the script starts, the line shows at once.
- `ResetOnSpawn=false`, so respawns don't matter.
- **While the menu is closed nothing runs:** the frame and resize listeners exist only while it is open.
- A newer copy or a destroyed script disconnects everything.
- The R150 click on open and close is kept.

### Limits (measured in the preview)
- The text sits behind Roblox's dimming, which halves its brightness.
- On phones, and on short laptops and tablets, part or all of it is behind the menu's see-through sheet. The game can't change that.
- An alternative, if the owner wants the line fully bright on phones: show it for a few seconds right after the menu **closes**. Not built.

### Studio check
- Press Esc at 1920×1080: the line is under the panel. Do the same at 1366×768 and with the phone emulator.
- Turn on Reduced Motion (Roblox Settings): the rainbow is still.
- Respawn, then open the menu again.
- Open the menu while the title screen is up.

## C. Other notices: sweep

| # | Finding | Status | What happened |
|---|---|---|---|
| C1 | **Daily login week never opened by itself for returning players.** `autoOpen` used up its once-a-session try 3 s after the reward was published, which is while the player is still on the title screen (`TitleActive`). The same happened with any menu open. | CONFIRMED, fixed | It now waits for the title screen or menu to close, then opens 3 s later (`DailyRewardsClient`). `test_daily_client`: not over the title screen, still waiting 30 s later, opens once it closes; fails on the R140 file. |
| C2 | Notification opt-in gave up after one failed check | CONFIRMED, fixed | A14 above. |
| C3 | Friend boost missed after a failed friend check | CONFIRMED, fixed | A20 above. |
| C4 | **HUD notices dropped on a crowded short phone.** `NoticeFeed83` shows `NoticeLayout85.Notices().Count` rows. That is 0 when the HUD stack (tutorial card + biome title + run warning + banners) reaches about 330 px on a 390 px tall screen, and queued notices then expire after 15 s unseen. | PLAUSIBLE, listed | Rare (tutorial + several banners at once). A fix would always show at least one row, which risks overlap, so it's left for a layout pass. |
| C5 | HUD notices keep timing out while the Roblox menu is open (they're behind it) | Listed | Probably fine (they're short-lived feedback). |
| C6 | Notice plumbing | CHECKED OK | See the list below. |
| C7 | PullAnnouncer / chat announcements | Not reviewed | Another agent is converting them to chat-only right now (PullAnnouncer* not touched). Re-run `docs/proposals/R151/tests/run_announce.sh` after that lands. |
| C8 | No "your plants grew while you were away" notice on rejoin, and no in-game "your plant is ready" notice | Absent | Nothing is broken. Could be a future feature. |

What was checked in C6:
- Remotes are created by the server before players join, and Roblox queues events fired before the client connects.
- Every notice `ScreenGui` has `ResetOnSpawn=false`.
- `HudNotices` lays the stack out again every 0.1 s.
- "QUEST DONE" fires once per finished quest.
- The mystery "make room" notice fires once a session, and "unlocked" once per unlock.
- A gift's "Received" fires once (Ready → Delivered).
- Index badges are recounted on every change.
- Friend notices are shown once per join.

## Tests (all pass)

**New and changed tests:**

| Suite | Test | Checks |
|---|---|---|
| `docs/proposals/R151/tests/run_offline.sh` | wiring check (BindToClose → `social:Shutdown`) | ok |
| | `test_plantnotify.luau` (new) | **65** |
| R140 (`docs/proposals/R140/tests/run.sh`) | `test_daily` | **129** |
| | `test_daily_client` (+3) | **71** |
| polish_R124 (`docs/proposals/polish_R124/tests/run.sh`) | `test_offline.luau`, rewritten for the rainbow text: 12 screens, safe area, size, clear of the panel, show/hide, no work while closed, Reduced Motion, fallback, already open, rotation | **85** |
| | growth | 394 |
| | keepers | 61 |
| | notifier | 11 |
| | perf | 11 |

**Other suites that load the changed files, re-run:**

| Suite | Checks |
|---|---|
| R127 | 53 + 25 |
| R147 | 285 + 187 |
| R148 roster | 257 + 978 |
| R149 verity | 151 + 122 + 185 + 242 + static |
| holes_R122 | 106 + 79 |
| treadmill_bonus_R123 | 109 + 129 + 718 |
| R151 announce | 148 + 126 + 138 + 16768 + 23 + 46 + 27 + static |
| R151 hub displays | 110 + 51 + 134 + 55 + 71 + 61 + 51 |
| R151 static_checks | ok |

All changed scripts compile (`luau-compile`).

For the R151 release notes: `docs/releases/R140.md` still says "at most 1 per player every 12 hours". It is now 24 h, Roblox's own limit, and a second plant the same day waits instead of being dropped.

## Files
- `src/ServerScriptService/ChestChaseServer/SocialService.lua`: A1–A13, A20, status and `Command`.
- `src/ServerScriptService/ChestChaseServerMain.server.lua`: one `BindToClose` line.
- `src/ServerScriptService/ChestChaseServer/OwnerUpdateCommands82.lua`, `src/ReplicatedStorage/StudioTestHelp.lua`, `docs/COMMANDS.md`: `plantnotify`.
- `src/StarterPlayer/StarterPlayerScripts/DailyRewardsClient.client.lua`: C1, A14.
- `src/StarterPlayer/StarterPlayerScripts/OfflineGrowthNotice.client.lua`: B.
- Tests:
  - `docs/proposals/R151/tests/run_offline.sh`
  - `docs/proposals/R151/tests/test_plantnotify.luau`
  - `docs/proposals/R140/tests/test_daily_client.luau`
  - `docs/proposals/polish_R124/tests/test_offline.luau`
- Preview: `docs/proposals/R151/preview/{run_offline_text_preview.sh, offline_text_scenes.luau, render_offline_text.mjs, make_offline_text.py}` → `docs/proposals/R151/offline_text.png`.

## Sources
- User notifications (Open Cloud), including the one-per-day limit: https://create.roblox.com/docs/cloud/guides/experience-notifications
- Experience notifications (eligibility, the opt-in prompt rules, the Luau package payload): https://create.roblox.com/docs/production/promotion/experience-notifications
- In-game HTTP requests: Open Cloud from HttpService, the supported endpoints (CreateUserNotification), only the `x-api-key` / `content-type` headers, 2500 Open Cloud requests a minute per server: https://create.roblox.com/docs/cloud-services/http-service
- Secrets stores (Creator Dashboard secrets, Local Secrets for Studio): https://create.roblox.com/docs/cloud-services/secrets
- Open Cloud v2 reference schema (`UserNotification`, `x-roblox-engine-usability`): Roblox/creator-docs `content/en-us/reference/cloud/cloud.docs.json`
- The 429 `RESOURCE_EXHAUSTED` "1 notification per recipient" answer: https://devforum.roblox.com/t/issues-with-opencloud-experience-notifications/3874557
- The Roblox menu layout: CoreScripts `Modules/Settings/SettingsHub.lua` and `Theme.lua` (MaximumADHD/Roblox-Client-Tracker, `roblox` branch)
