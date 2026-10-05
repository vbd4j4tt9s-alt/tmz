#!/bin/sh
# Usage: sh static_checks.sh <repo root>. R151 pull announcements: facts about the source that a mock run cannot show.
set -e
REPO=${1:?repo root}
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;C=$S/StarterPlayer/StarterPlayerScripts;RS=$S/ReplicatedStorage
fail(){ echo "FAIL: $1";exit 1; }
count(){ grep -c "$1" "$2" || true; }
# 1. the hooks in shared files are ONE line each (merge safety)
[ "$(count PullAnnouncer "$SS/PlayerDataService.lua")" = 1 ] || fail "PlayerDataService must mention PullAnnouncer on exactly one line"
[ "$(count PullAnnouncer "$S/ServerScriptService/ChestChaseServerMain.server.lua")" = 1 ] || fail "ChestChaseServerMain must mention PullAnnouncer on exactly one line"
[ "$(count PullAnnouncer "$SS/OwnerUpdateCommands82.lua")" = 1 ] || fail "OwnerUpdateCommands82 must mention PullAnnouncer on exactly one line"
grep -q "announce=true}}" "$SS/OwnerUpdateCommands82.lua" || fail "announce is not in OwnerUpdateCommands82.Actions"
[ "$(count PullBannerBottom "$C/HudNotices.client.lua")" = 1 ] || fail "HudNotices must read PullBannerBottom on exactly one line"
echo "ok: the hooks are one line each (PlayerDataService, ChestChaseServerMain, OwnerUpdateCommands82 + its Actions entry, HudNotices)"
# 2. the open of a real pack is the ONLY caller of the announcer's pull hook, and it is told whether the pack was a TEST pack
grep -q "OnOpened(player,pack,reward,testSeed~=nil)" "$SS/PlayerDataService.lua" || fail "the hook must pass testSeed~=nil as wasTest"
n=$(grep -rn "PullAnnouncer" "$S" --include=*.lua | grep -v "PullAnnouncer.lua:" | grep -v "PullAnnouncerClient.client.lua:" | grep -v "PullAnnounceRules.lua:" | wc -l)
[ "$n" = 5 ] || fail "PullAnnouncer is referenced from $n other scripts (expected 5: PlayerDataService, ChestChaseServerMain, OwnerUpdateCommands82, and comments in SettingsConfig and HudNotices)"
echo "ok: PullAnnouncer is reached from PlayerDataService:OpenSeedPack, the server main script and the owner commands only"
for f in RarePackTests StudioSeedCommands StudioTestCommands FruitGiftService PassGiftService MysteryPackService TreadmillBonusService DailyProgress; do
 if grep -q "PullAnnouncer" "$SS/$f.lua"; then fail "$f (a TEST pack, gift or grant path) must not announce"; fi
done
echo "ok: TEST packs, seed grants, gifts, the mystery pedestal, bonus rolls and daily rewards never reach the announcer"
# 3. MessagingService lives in the announcer alone; no client -> server channel; no player-typed text
m=$(grep -rl "GetService('MessagingService')" "$S" --include=*.lua | wc -l)
[ "$m" = 1 ] && grep -q "GetService('MessagingService')" "$SS/PullAnnouncer.lua" || fail "MessagingService must be used by PullAnnouncer only (found in $m scripts)"
echo "ok: MessagingService is used by PullAnnouncer only"
if grep -n "OnServerEvent\|OnServerInvoke\|Chatted\|TextChatService" "$SS/PullAnnouncer.lua" | grep -v "^[0-9]*:--"; then fail "the announcer must not listen to clients or chat"; fi
if grep -n "FireServer\|InvokeServer" "$C/PullAnnouncerClient.client.lua"; then fail "the announcer client must not call the server"; fi
if grep -n "DisplaySystemMessage\|SendAsync" "$SS/PullAnnouncer.lua"; then fail "chat lines are made on the client"; fi
echo "ok: the remote is server -> client only; the announcer reads no chat and no client message"
# 4. the hub displays are not built here: nothing but the API and the test command produce a Record
r=$(grep -rln "Kind='Record'" "$S" --include=*.lua | wc -l)
[ "$r" = 0 ] || [ "$r" = 1 ] || fail "records are made by the announcer's own command only (found $r files)"
echo "ok: no hub-display code was added (the record banner is only an API plus the owner command)"
# 5. every script compiles, and the manifest lists the new ones
for f in "$RS/PullAnnounceRules.lua" "$SS/PullAnnouncer.lua" "$C/PullAnnouncerClient.client.lua" "$RS/SettingsConfig.lua" "$C/SettingsClient.client.lua" "$C/HudNotices.client.lua" \
 "$SS/PlayerDataService.lua" "$SS/OwnerUpdateCommands82.lua" "$RS/StudioTestHelp.lua" "$S/ServerScriptService/ChestChaseServerMain.server.lua"; do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || fail "$f does not compile"
done
for f in ReplicatedStorage/PullAnnounceRules.lua ServerScriptService/ChestChaseServer/PullAnnouncer.lua StarterPlayer/StarterPlayerScripts/PullAnnouncerClient.client.lua; do
 grep -q "$f" "$S/MANIFEST.tsv" || fail "$f is not in src/MANIFEST.tsv"
done
miss=0;while IFS="$(printf '\t')" read -r class place file; do [ "$class" = class ] && continue; [ -f "$S/$file" ] || { echo "manifest file missing: $file";miss=1; }; done < "$S/MANIFEST.tsv"
[ "$miss" = 0 ] || fail "MANIFEST.tsv lists a file that does not exist"
echo "ok: every touched script compiles; the three new scripts are in MANIFEST.tsv and every manifest line has its file"
# 6. no saved-data change
grep -q "Config.ProfileVersion=22" "$SS/Config.lua" || fail "Config.ProfileVersion must stay 22"
echo "ok: ProfileVersion is still 22 (the setting lives in the existing Premium settings table)"
