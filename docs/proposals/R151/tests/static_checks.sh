#!/bin/sh
# Usage: sh static_checks.sh <repo root>. R151 pull announcements (chat only): facts about the source that a mock run cannot show.
set -e
REPO=${1:?repo root}
S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;C=$S/StarterPlayer/StarterPlayerScripts;RS=$S/ReplicatedStorage
fail(){ echo "FAIL: $1";exit 1; }
count(){ grep -c "$1" "$2" || true; }
# 1. the hooks in shared files are ONE line each (merge safety)
[ "$(count PullAnnouncer "$SS/PlayerDataService.lua")" = 1 ] || fail "PlayerDataService must mention PullAnnouncer on exactly one line"
[ "$(count PullAnnouncer "$S/ServerScriptService/ChestChaseServerMain.server.lua")" = 1 ] || fail "ChestChaseServerMain must mention PullAnnouncer on exactly one line"
[ "$(count PullAnnouncer "$SS/OwnerUpdateCommands82.lua")" = 1 ] || fail "OwnerUpdateCommands82 must mention PullAnnouncer on exactly one line"
grep -qE "Actions=\{[^}]*announce=true" "$SS/OwnerUpdateCommands82.lua" || fail "announce is not in OwnerUpdateCommands82.Actions"
echo "ok: the hooks are one line each (PlayerDataService, ChestChaseServerMain, OwnerUpdateCommands82 + its Actions entry)"
# 2. chat only: HudNotices is exactly what R150 shipped, nothing anywhere speaks of a banner row, the client makes no Gui, no sound, no tween, no per-frame code
if grep -rn "PullBannerBottom" "$S"; then fail "PullBannerBottom must not exist any more (HudNotices has no banner hook)"; fi
if grep -n "PullAnnounce\|PullBanner" "$C/HudNotices.client.lua"; then fail "HudNotices must not mention the pull announcements"; fi
if git -C "$REPO" cat-file -e a1390a7 2>/dev/null; then
 sh "$REPO/tools/tests/r152_real_diff.sh" "$REPO" a1390a7 src/StarterPlayer/StarterPlayerScripts/HudNotices.client.lua >/dev/null || fail "HudNotices differs from its R150 version (it must be restored exactly)"
 echo "ok: HudNotices is byte for byte its R150 version apart from the R152 load guard line"
else echo "skip: no R150 commit in this checkout, HudNotices compared by name only"; fi
if grep -n "Instance.new\|ScreenGui\|Sound\|TweenService\|RenderStepped\|Heartbeat\|RarityRevealAudio\|AudioMixer\|GetUserThumbnailAsync\|ItemPictures\|BonusGiftArt\|SetAttribute\|FireServer\|InvokeServer" "$C/PullAnnouncerClient.client.lua" | grep -v "^[0-9]*:--"; then fail "the announcer client must not build any Gui, play any sound or tween, run per frame, fetch pictures, write attributes or call the server"; fi
if grep -n "Metrics\|Enqueue\|Dequeue\|NewQueue\|Subline\|Headline\|Sparkles\|HudNoticeLayout\|HudLayout\|BannerSeconds\|MaxWaiting\|WaitSeconds" "$RS/PullAnnounceRules.lua" | grep -v "^[0-9]*:--"; then fail "PullAnnounceRules must not keep any banner rule"; fi
echo "ok: chat only: no PullBannerBottom anywhere; the client has no Gui, sound, tween, per-frame code, picture, attribute or server call; the rules keep no banner layout / queue / timing"
# 3. the open of a real pack is the ONLY caller of the announcer's pull hook, and it is told whether the pack was a TEST pack
grep -q "OnOpened(player,pack,reward,testSeed~=nil or luckTest)" "$SS/PlayerDataService.lua" || fail "the hook must pass testSeed~=nil (or luck from owner-given boots, R152) as wasTest"
grep -q "pack.TestGrant==true" "$SS/PullAnnouncer.lua" || fail "PullAnnouncer:Pulled must refuse a pack whose record has TestGrant"
n=$(grep -rn "PullAnnouncer" "$S" --include=*.lua | grep -v "PullAnnouncer.lua:" | grep -v "PullAnnouncerClient.client.lua:" | grep -v "PullAnnounceRules.lua:" | grep -v "OwnerTestPacks.lua:" | grep -v "HubDisplayService.lua:" | wc -l)
[ "$n" = 4 ] || fail "PullAnnouncer is referenced from $n other lines (expected 4: PlayerDataService, ChestChaseServerMain, OwnerUpdateCommands82 and the comment in SettingsConfig; the hub's own use is checked in 6)"
grep -q "Test=testSeed~=nil or pack.TestGrant==true" "$SS/PlayerDataService.lua" || fail "the hub's pack-opened hook must be told about owner-made (TestGrant) packs too"
echo "ok: PullAnnouncer is reached from PlayerDataService:OpenSeedPack, the server main script, the owner commands and the hub's record call only; it refuses TestGrant packs; the hub is told about them too"
# 3b. when a line may go out is derived from the tables the PULLER's client plays (one source of truth): the announcer asks PullAnnounceRules.RevealDelay, which reads RarePullRules
if grep -n "GetRevealDuration" "$SS/PullAnnouncer.lua" | grep -v "^[0-9]*:--"; then fail "PullAnnouncer must not time its lines by the old server reveal length (SeedPackRules.GetRevealDuration)"; fi
grep -q "Rules.RevealDelay(rarity)" "$SS/PullAnnouncer.lua" && grep -q "Reveal.LatestSeedShown" "$RS/PullAnnounceRules.lua" && grep -q "function L.LatestSeedShown" "$RS/RarePullRules.lua" || fail "the announcer's delay must be PullAnnounceRules.RevealDelay -> RarePullRules.LatestSeedShown"
grep -q "PlayerRemoving" "$SS/PullAnnouncer.lua" || fail "a puller who leaves must release their waiting lines (PlayerRemoving)"
echo "ok: the announcer times its lines by PullAnnounceRules.RevealDelay -> RarePullRules.LatestSeedShown (the tables the client plays), not by the old reveal length; a leaving puller releases them"
for f in RarePackTests StudioSeedCommands StudioTestCommands FruitGiftService PassGiftService MysteryPackService TreadmillBonusService DailyProgress OwnerUpdateCommands82; do
 if [ "$f" != OwnerUpdateCommands82 ] && grep -q "PullAnnouncer" "$SS/$f.lua"; then fail "$f (a TEST pack, gift or grant path) must not announce"; fi
done
echo "ok: TEST packs, seed grants, gifts, the mystery pedestal, bonus rolls and daily rewards never call the announcer"
# 4. every owner-command path that makes a pack marks it (TestGrant), and the services behind the indirect commands claim the arm
grep -q "PackMutation=coat,TestGrant=true," "$SS/StudioTestCommands.lua" || fail "/test pack and /test seed(s) must set TestGrant on the record (R152: seeds too)"
grep -q "TestGrant=true" "$SS/RarePackTests.lua" || fail "/test rarepacks must set TestGrant on every pack record"
[ "$(grep -c "{TestGrant=true})" "$SS/OwnerUpdateCommands82.lua")" = 1 ] || fail "packset / eclipse (void) / verity must call AddChest with {TestGrant=true} (one AddChest line serves all three)"
for source in Mystery Daily DailyQuest Bonus; do # R153: the login pack ('Daily') and a quest pack ('DailyQuest') have their own arms
 grep -q "TestPacks.Arm(p,'$source'" "$SS/OwnerUpdateCommands82.lua" || fail "the $source owner commands must arm OwnerTestPacks"
done
grep -q "OwnerTestPacks).Claim(player,'Mystery'" "$SS/MysteryPackService.lua" || fail "MysteryPackService must Claim the Mystery arm when it adds the pack"
grep -q "OwnerTestPacks).Claim(player,source=='DailyQuest'and'DailyQuest'or'Daily'" "$SS/DailyProgress.lua" || fail "DailyProgress must Claim the Daily (login pack) or DailyQuest (quest pack) arm when it adds the pack"
grep -q "OwnerTestPacks).Claim(player,'Bonus'" "$SS/TreadmillBonusService.lua" || fail "TreadmillBonusService must Claim the Bonus arm when it adds the pack"
grep -q "TestGrant=self.Forced==true" "$SS/VeiledEvent81.lua" && grep -q "self.Forced=force==true" "$SS/VeiledEvent81.lua" || fail "an owner-forced event must mark its world packs (TestGrant)"
grep -q "seed.TestGrant == true then record.TestGrant = true" "$SS/ChestService.lua" || fail "ChestService:Bank must hand a world pack's TestGrant to the pack record"
for want in "options.TestGrant == true" "TestGrant = pack.TestGrant == true or nil" "savedChest.TestGrant==true" "chestRecord.TestGrant==true"; do
 grep -q "$want" "$SS/PlayerDataService.lua" || fail "PlayerDataService: missing '$want' (AddChest option, Void -> Verity conversion, load, save)"
done
echo "ok: /test pack, rarepacks, packset, void / eclipse, verity, the mystery / daily / bonus commands, forced events and the pack record (add, save, load, Verity conversion) all handle TestGrant"
# 4b. every place that adds a pack to a bag or builds a pack record is known: a NEW one must be classified (a real source that announces, or an owner command that marks its packs). R152: VoidGiveaway152 (the free Void Pack pedestal) is a REAL source: its pack is not TestGrant, so it announces when opened. R156: SecretPyramid156 (the Desert pyramid's one-time pack) is a REAL source too: a Desert Mythic world-pack record carried and banked by the normal steal code (ChestService:Bank), never TestGrant, so it announces when opened
found=$(grep -rlE "AddChest\(|[ ,{]Kind *= *['\"]Pack['\"]|Kind=isPack and'Pack'" "$SS" --include=*.lua | xargs -n1 basename | sort | tr '\n' ' ')
want="ChestService.lua DailyProgress.lua MysteryPackService.lua OwnerUpdateCommands82.lua PlayerDataService.lua PremiumProgress.lua RarePackTests.lua SecretPyramid156.lua StudioTestCommands.lua TreadmillBonusService.lua TutorialProgress.lua VeiledEvent81.lua VoidGiveaway152.lua "
[ "$found" = "$want" ] || fail "the files that add packs changed: found [$found] expected [$want]. A new pack source must announce (a real one) or mark its packs TestGrant (an owner one); then add it here."
echo "ok: the files that add or build packs are the known ones (ChestService, DailyProgress, MysteryPackService, OwnerUpdateCommands82, PlayerDataService, PremiumProgress, RarePackTests, SecretPyramid156, StudioTestCommands, TreadmillBonusService, TutorialProgress, VeiledEvent81, VoidGiveaway152)"
# 5. MessagingService lives in the announcer alone; no client -> server channel; no player-typed text
m=$(grep -rl "GetService('MessagingService')" "$S" --include=*.lua | xargs -n1 basename | sort | tr '\n' ' ')
[ "$m" = "PullAnnouncer.lua VoidGiveaway152.lua " ] && grep -q "GetService('MessagingService')" "$SS/PullAnnouncer.lua" || fail "MessagingService must be used by PullAnnouncer and the R152 giveaway only (found in [$m])"
echo "ok: MessagingService is used by PullAnnouncer (the announcements) and VoidGiveaway152 (the giveaway's count) only"
if grep -n "OnServerEvent\|OnServerInvoke\|Chatted\|TextChatService" "$SS/PullAnnouncer.lua" | grep -v "^[0-9]*:--"; then fail "the announcer must not listen to clients or chat"; fi
if grep -n "FireServer\|InvokeServer" "$C/PullAnnouncerClient.client.lua"; then fail "the announcer client must not call the server"; fi
if grep -n "DisplaySystemMessage\|SendAsync" "$SS/PullAnnouncer.lua" | grep -v "^[0-9]*:--"; then fail "chat lines are made on the client"; fi
grep -q "DisplaySystemMessage" "$C/PullAnnouncerClient.client.lua" && grep -q "RBXGeneral" "$C/PullAnnouncerClient.client.lua" && grep -q "ChatMakeSystemMessage" "$C/PullAnnouncerClient.client.lua" || fail "the client writes RBXGeneral:DisplaySystemMessage with the old chat as the fallback"
echo "ok: the remote is server -> client only; the announcer reads no chat and no client message; the client writes RBXGeneral (old chat as a fallback)"
# 6. hub records: only the announcer's own command and HubDisplayService make a Record; the hub has no notice of its own any more (ONE message, in chat), and says whose test it is
r=$(grep -rln "Kind='Record'" "$S" --include=*.lua | xargs -n1 basename | sort | tr '\n' ' ')
[ "$r" = "HubDisplayService.lua PullAnnouncer.lua " ] || fail "records are made by the announcer's own command and HubDisplayService only (found [$r])"
if grep -n "Notes:Show\|self\.Notes\|PullNotice\|FruitNotice\|NoticeMinRank" "$SS/HubDisplayService.lua" "$RS/HubDisplayRules.lua" | grep -v ":[0-9]*:--"; then fail "the hub must not keep a notice of its own (it would be a second message next to the chat line)"; fi
grep -q "announcer.Announce(spec)" "$SS/HubDisplayService.lua" && grep -q "spec.AfterReveal=true" "$SS/HubDisplayService.lua" && grep -q "spec.To=player" "$SS/HubDisplayService.lua" || fail "HubDisplayService must announce through PullAnnouncer.Announce, a pull record AfterReveal and an owner's test To its target only"
echo "ok: hub records go through PullAnnouncer.Announce (a pull record after the reveal, an owner's test private); the hub keeps no notice of its own"
# 7. every script compiles, and the manifest lists the new ones
for f in "$RS/PullAnnounceRules.lua" "$SS/PullAnnouncer.lua" "$SS/OwnerTestPacks.lua" "$C/PullAnnouncerClient.client.lua" "$RS/SettingsConfig.lua" "$C/SettingsClient.client.lua" "$C/HudNotices.client.lua" \
 "$SS/PlayerDataService.lua" "$SS/OwnerUpdateCommands82.lua" "$SS/StudioTestCommands.lua" "$SS/RarePackTests.lua" "$SS/MysteryPackService.lua" "$SS/DailyProgress.lua" "$SS/TreadmillBonusService.lua" \
 "$SS/VeiledEvent81.lua" "$SS/ChestService.lua" "$RS/StudioTestHelp.lua" "$S/ServerScriptService/ChestChaseServerMain.server.lua" \
 "$RS/RarePullRules.lua" "$SS/HubDisplayService.lua" "$RS/HubDisplayRules.lua"; do
 /opt/luau/luau-compile --null "$f" >/dev/null 2>&1 || fail "$f does not compile"
done
for f in ReplicatedStorage/PullAnnounceRules.lua ServerScriptService/ChestChaseServer/PullAnnouncer.lua ServerScriptService/ChestChaseServer/OwnerTestPacks.lua StarterPlayer/StarterPlayerScripts/PullAnnouncerClient.client.lua; do
 grep -q "$f" "$S/MANIFEST.tsv" || fail "$f is not in src/MANIFEST.tsv"
done
miss=0;while IFS="$(printf '\t')" read -r class place file; do [ "$class" = class ] && continue; [ -f "$S/$file" ] || { echo "manifest file missing: $file";miss=1; }; done < "$S/MANIFEST.tsv"
[ "$miss" = 0 ] || fail "MANIFEST.tsv lists a file that does not exist"
echo "ok: every touched script compiles; the four new scripts are in MANIFEST.tsv and every manifest line has its file"
# 8. no saved-data change that needs a version bump: the extra pack field is optional, and the setting lives in the existing Premium settings table
grep -q "Config.ProfileVersion=22" "$SS/Config.lua" || fail "Config.ProfileVersion must stay 22"
echo "ok: ProfileVersion is still 22 (TestGrant is an optional field of a pack record; the setting lives in the existing Premium settings table)"
