#!/bin/sh
# Usage: sh run_sfx.sh [scratch dir] [all]. R150 SFX fix round on the Roblox mock (/opt/luau/luau) with the REAL modules / scripts of this checkout.
#  test_cues.luau   - InteractionAudio (Denied / MenuClose keys, gaps, minGap, Mute), SoundTiming (the one lead-in table), RarityRevealAudio (Pop
#                     offset, late big bursts dropped), RevealFlourish (onlooker trim), VeiledArrivalFx (joins at the packet's age), LocalSfx, the
#                     SeedMenu open / close rule (X / shade / Esc / B / walk away), refusals -> Denied, the HUD row on the beep, AudioMixer (Effects 0
#                     mutes the snore and characters that already existed, the saved mix before SettingsState).
#  test_hotbar.luau - the real Hotbar: equip keys / L1 R1 / slot / Bag card, quiet Bag close, drag, the harvest cue on the arrival flash.
#                     (R152: the hotbar movement sounds were removed, so the equip / slot / drag checks now assert SILENCE; the Equip cue stays only in the shop.)
#  test_packs.luau  - pack-opening clicks at the accepted rate, onlooker Secret / Cosmic / King pulls.
#  test_inputs.luau - (R152: treadmill step-on, prompt hold-begin and plant select are now silent) TravelButtons, InteractionFeedback, BatClient, FruitGiftClient, GardenShovel, SettingsClient, SaleMoneyEffects, the wallet and the
#                     gift picker, TitleScreen104, PlantInspection, the EconomyClient wiring, WorldStatusHud.
#  test_server.luau - the saved mix published at data load, Denied kinds from the server, GardenUpgradeService bought / refused serials.
#  tools/tests/test_fast_travel.luau (extended) - the arrival whoosh and the Denied kinds through the real remote flow (must now be 0 failures).
#  static checks    - Denied / MenuClose reuse existing sounds, the reveal cues and the keyboard click read SoundTiming, every script compiles.
# "all" also runs every existing suite that touches a file this round changed (several extended with R150 checks, marked "R150" in their messages).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT/cl" "$OUT/srv"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer
echo "== static checks"
grep -q "Denied='rbxasset://sounds/electronicpingshort.wav'" "$S/ReplicatedStorage/InteractionAudio.lua"
grep -q "MenuClose=116737765668953" "$S/ReplicatedStorage/InteractionAudio.lua"
echo "ok: Denied and MenuClose are existing sounds at another pitch (the built-in ping, the MenuClick file): no new upload"
if grep -nE "Start=[0-9.]+" "$S/ReplicatedStorage/RarityRevealAudio.lua"; then echo "FAIL: RarityRevealAudio still carries a private Start";exit 1; fi
grep -q "Timing.Play(v.Sound,nil,.25)" "$S/StarterPlayer/StarterPlayerScripts/KeyboardTrack.client.lua"
grep -q "9120769331'\]=.040" "$S/ReplicatedStorage/SoundTiming.lua"
echo "ok: the reveal cues and the keyboard click read the one SoundTiming table"
# R150 review: the tear sound's lead-in is SoundTiming's alone; the old private Rules.TearSoundStart (read by nothing) is gone
if grep -nE "^Rules\.TearSoundStart" "$S/ReplicatedStorage/SeedPackRules.lua"; then echo "FAIL: Rules.TearSoundStart is back";exit 1; fi
if grep -rn "TearSoundStart" "$S" | grep -v "^[^:]*SeedPackRules.lua" | grep -v "SeedPackClient.client.lua"; then echo "FAIL: something reads TearSoundStart";exit 1; fi
echo "ok: no Rules.TearSoundStart (the lead-in is in SoundTiming)"
bad=0;for f in $(find "$S" -name '*.lua');do /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || { echo "FAIL: $f does not compile";bad=1; };done
[ "$bad" = 0 ]
echo "ok: every script in src/ compiles"
# worlds ----------------------------------------------------------------------------------------------------------------------------------------------------
INV=$P/inventory_R113/tests;TB=$P/treadmill_bonus_R123/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$HERE"/*.luau "$OUT/cl/"
python3 "$HERE/mkbundle_sfx.py" "$OUT/cl" all-client NotificationService="$SS/NotificationService.lua" >/dev/null
cd "$OUT/cl"
for t in test_cues test_hotbar test_packs test_inputs; do
 echo "== $t"
 timeout 600 /opt/luau/luau $t.luau > $t.log 2>&1 || { grep -v '^WARN' $t.log | tail -40;exit 1; }
 grep -v '^WARN' $t.log | tail -1
done
cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_server.luau" "$OUT/srv/"
python3 "$TB/mkbundle.py" "$OUT/srv" >/dev/null
cd "$OUT/srv";echo "== test_server"
timeout 600 /opt/luau/luau test_server.luau > server.log 2>&1 || { grep -v '^WARN' server.log | tail -40;exit 1; }
grep -v '^WARN' server.log | tail -1
echo "== tools/tests/test_fast_travel (R150: arrival whoosh + Denied kinds; R150 review: its stale R114 'phone: centred and fits' check, a failure since R140, now checks the pair + DAILY / INVITE group)"
mkdir -p "$OUT/tp";cp "$T/roblox.luau" "$T/test_fast_travel.luau" "$OUT/tp/"
python3 "$T/bundle.py" "$OUT/tp/tp_bundle.luau" FastTravelService="$SS/FastTravelService.lua" MovementGuard="$SS/MovementGuard.lua" SecurityGate="$SS/SecurityGate.lua" \
 HudLayout="$S/ReplicatedStorage/HudLayout.lua" VectorIcons91="$S/ReplicatedStorage/VectorIcons91.lua" TravelButtons="$S/StarterPlayer/StarterPlayerScripts/TravelButtons.client.lua" >/dev/null
(cd "$OUT/tp" && /opt/luau/luau test_fast_travel.luau > ft.log 2>&1; grep -v '^WARN' ft.log | tail -3; grep -q 'ALL PASS' ft.log) || { echo "test_fast_travel FAILED";exit 1; }
if [ "$MODE" = "all" ]; then
 for r in audio_R123/tests/run.sh R136/tests/run.sh R138/tests/run.sh R140/tests/run.sh R147/tests/run_keyboard.sh R147/tests/run_verity.sh R148/tests/run_purchase.sh \
  R149/tests/run_keyboard.sh R149/tests/run_verity.sh holes_R122/tests/run.sh polish_R124/tests/run.sh giving_R122/tests/run.sh treadmill_bonus_R123/tests/run.sh \
  veiled_R122/tests/run.sh wall_notifier_R122/tests/run_wall.sh R129/tests/run.sh borders_R123/tests/run.sh; do
  echo "######## $r";sh "$P/$r" "$OUT/$(echo $r | tr '/' '_')" | tail -3
 done
fi
echo "R150 SFX suites passed"
