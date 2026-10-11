#!/bin/sh
# Usage: sh run_gems_column.sh [scratch dir] [mutate]   (needs /opt/luau/luau and python3)
# R153 (owner: a gems indicator in the player list, next to Speed and Cash). On the Roblox mock with the REAL modules of this checkout:
#  1. static: PlayerDataService compiles; Config.Version / ProfileVersion untouched; every line in src that changes the gem balance publishes it (PublishPremium on the same line or
#     within two lines: that sets the Gems attribute the cell follows), so a future gem source that forgets to publish fails here, not in the player list.
#  2. test_gems_column.luau - the cell (StringValue tagged ChestChaseDisplayStat, Priority 0 under Speed 2 / Cash 1, PlayerList text), every gain and spend (money auto-collect, daily quest
#     gems, converter, gem pass, Speed bundle, mech pack, gift debit, owner command), no second saved value, stray "Gems" values, the Cash migration, clean-up on leave.
# With "mutate" as the 2nd argument, broken copies of src must each make the test fail (ONLY=<word of one mutation's name> runs one).
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;mkdir -p "$OUT"
P=$REPO/docs/proposals
suite() { # $1 = src dir, $2 = work dir, $3 = log
 mkdir -p "$2"
 cp "$REPO/tools/tests/roblox.luau" "$P/treadmill_bonus_R123/tests/world.luau" "$P/R151/tests/announce_env.luau" "$HERE/test_gems_column.luau" "$2/"
 python3 "$P/R152/tests/bundle_giveaway.py" "$1" "$2" >/dev/null
 (cd "$2" && timeout 600 /opt/luau/luau test_gems_column.luau > "$3" 2>&1) || { grep -v '^WARN' "$3" | tail -30;return 1; }
 grep -v '^WARN' "$3" | tail -1
}
echo "== static checks"
SRV=$REPO/src/ServerScriptService/ChestChaseServer
/opt/luau/luau-compile --null "$SRV/PlayerDataService.lua" >/dev/null || { echo "FAIL: PlayerDataService does not compile";exit 1; }
grep -qE "Config\.Version='V150 R15[0-9a-z]*'" "$SRV/Config.lua" && grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" || { echo "FAIL: Config.Version / ProfileVersion changed";exit 1; }
n=0
for f in "$SRV"/*.lua; do
 hits=$(awk '{c=$0;sub(/--.*$/,"",c)} c~/Gems[ \t]*[+-]=/ || (c~/[A-Za-z]\.Gems[ \t]*=[^=]/ && c!~/Values\.Gems/) {print FILENAME":"FNR}' "$f")
 for h in $hits; do
  ln=${h##*:};n=$((n+1))
  sed -n "${ln},$((ln+2))p" "$f" | grep -q PublishPremium || { echo "FAIL: $h changes Gems without publishing it";exit 1; }
 done
done
[ "$n" -ge 6 ] || { echo "FAIL: the audit saw only $n places that change the balance";exit 1; }
echo "ok: PlayerDataService compiles; Config untouched; $n places change the gem balance and each publishes it (the Gems attribute the cell follows)"
echo "== test_gems_column"
suite "$REPO/src" "$OUT/real" "$OUT/real.log"
[ "$MODE" = mutate ] || { echo "R153 gems column suite passed";exit 0; }
echo "== mutations (each must make the test fail)"
FAILED=0
mutate() { # $1 = name  $2 = file under src/ServerScriptService/ChestChaseServer  $3 = text to find  $4 = replacement
 [ -z "$ONLY" ] || case "$1" in *"$ONLY"*) ;; *) return 0;; esac
 rm -rf "$OUT/m";mkdir -p "$OUT/m";cp -r "$REPO/src" "$OUT/m/src"
 python3 - "$OUT/m/src/ServerScriptService/ChestChaseServer/$2" "$3" "$4" <<'PY'
import sys
p,a,b=sys.argv[1:4]
s=open(p,encoding='utf-8').read()
assert s.count(a)==1,'mutation target found %d times'%s.count(a)
open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
 if suite "$OUT/m/src" "$OUT/m/w" "$OUT/m/log" >/dev/null 2>&1;then echo "SURVIVED: $1";FAILED=1;else echo "caught:   $1";fi
}
F=PlayerDataService.lua
mutate "the column is not created" $F "	self:GetOrCreateGemsDisplay(player) -- R153" ""
mutate "wrong priority" $F "displayStat(statFolder(player,'leaderstats'),'Gems',0)" "displayStat(statFolder(player,'leaderstats'),'Gems',3)"
mutate "not a tagged display" $F " display:SetAttribute('ChestChaseDisplayStat',true)" " display:SetAttribute('ChestChaseDisplayStat',false)"
mutate "raw text instead of PlayerList" $F "PlayerList(player:GetAttribute('Gems'))" "Exact(player:GetAttribute('Gems'))"
mutate "does not follow the attribute" $F "link.Connections={player:GetAttributeChangedSignal('Gems'):Connect(update),display.Destroying:Connect(unbind)}" "link.Connections={display.Destroying:Connect(unbind)}"
mutate "links stack" $F " if previous and previous.Display==display then return display end
 if previous then disconnectStat(previous)end" ""
mutate "left connections after leaving" $F " for _,link in pairs(links.Values)do disconnectStat(link)end" " for _,link in pairs(links.Values)do if link.Raw then disconnectStat(link)end end"
mutate "Gems saved a second time" $F "        Premium = gardenClonePremium(self:GetPremium(player))," "        Premium = gardenClonePremium(self:GetPremium(player)),GemsDisplay=self:GetPremium(player).Gems,"
[ "$FAILED" = 0 ] || exit 1
echo "R153 gems column suite passed (every mutation caught)"
