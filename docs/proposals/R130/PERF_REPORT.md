# R130 performance pass

Goal from the owner: "make it smoother and run better without compromising quality and look". Rule for this pass: no
visual or gameplay change. Everything below was measured on the offline Roblox mock (call counts, not frame times).
No live MicroProfiler capture was taken.

## Changed

| Where | Before | After | How it was checked |
|---|---|---|---|
| Idle keepers at home (server, `ConcurrentKeeperService._maintainGuardians`, 4 times a second) | Every keeper was fully re-prepared on every pass: all parts' transparency and collision rewritten, a visibility scan, a re-pivot and 4 attribute writes. Over 20 s with 7 keepers: **567 full prepares, 2,240 attribute writes, 240 re-pivots** | A prepared keeper only gets cheap checks: put back home if it moved, idle attributes written only when wrong. It is fully re-prepared when its parts change, when it is reparented or replaced, after a chase, and every 5 s as a safety net. Same 20 s: **35 full prepares, 0 attribute writes, 0 re-pivots** | `R130/tests/test_keeper_idle.luau`, 30 checks. Run against the R129 file it fails on exactly these counts |
| Movement check (server, `MovementGuard`, 10 times a second per moving player) | A new `RaycastParams` and filter list on every check | One `RaycastParams` reused. The barrier list is still read on every check; the filter is only rewritten when the list changes, so the refresh wall blocks from the first check after it appears | `R130/tests/test_micro.luau`, 11 checks (one params object over 20 checks, wall added and removed, runner still stopped at a wall). R112 motion test output is identical, line for line. Fast travel 59 |
| Gift hover (client, new in R130) | — | The hover ray runs 12 times a second and only while a fruit, seed or pack is held; its filter list is built once per character | Giving client test, 33 checks |

## Looked at and left alone

| Where | Why it stays |
|---|---|
| Server per-frame steps: biome refresh, treadmill bonus, bat, track holes, storm, base training | Each is a few comparisons per player per frame, or already throttled |
| Client: keeper animation, garden visuals, seed pack render | Already budgeted (distance tiers, throttles, part caps) since R121/R124 |
| Workspace-wide `DescendantAdded` listeners (lava, keeper animation, audio mixer, economy) | Each callback is a cheap class or tag check. Scoping them would mean touching 4 systems for little gain |
| `CarryNameplate84` child scan | Runs at 10 Hz and only scans a character's children when the carry attribute is missing |
| Per-frame held-item effects from R128 | They follow every frame on purpose (the orbit-lag fix). They only run for carried items |

## Not measured

- Real frame times on a phone or PC. The changes cut work, but how much smoother it feels depends on the place and
  the device. A MicroProfiler capture in a live server, before and after, would show it.
