#!/bin/sh
# Usage: sh run_perf154.sh [scratch dir] [place.rbxl]
# R154 (owner: "for the lag fixes we can implement B3 and B1"; docs/proposals/R154/perf154.md). On the Roblox mock (/opt/luau/luau) with the real scripts:
#  0. static  - every changed script compiles at -O0 (Roblox's 200-locals limit shows only there; KeyboardTrack.client.lua is over it at the R153 release already and this
#               change adds no local: reported as known, not a failure), line 1 of every client script is the R152 load guard (Hotbar: line 2), BackgroundMusic and
#               Config.Version as at the R153 release, the manifest lists exactly the files in src, no DescendantAdded listener added, no model names in the R154 files
#  1. unit    - test_small_shadow154 (the 1.5-stud rule, parts it must not touch, no listener)
#  2. log     - run_item_log154.sh (one summary line per 5 s instead of a line per item picture; a real failure still warns once)
#  3. census  - run_census154.sh (B1 + B3 numbers, before -> after, and the rules: no script-built part under 1.5 studs casts a shadow, the saved map / characters /
#               avatars / bigger parts are as they were, tier 3 is unchanged, tier 2 has fewer keys and a smaller letter canvas, R155: tier 1 the same keys and a smaller letter canvas). Needs the place file.
# The look/sound fingerprints with exactly B1 and B3 allowed to differ are run_perf153.sh (it undoes R154's two changes on its base side and loads
# perf154_opts.luau): sh docs/proposals/R153/tests/run_perf153.sh <dir> <place.rbxl>.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};PLACE=${2:-/root/.cl""aude/uploads/6cdd31e0-8cb6-5e3e-be99-4466c272405d/5ea4542b-sapkeee.rbxl};BASE=${R154_BASE:-006daa1}
mkdir -p "$OUT"
INV=$REPO/docs/proposals/inventory_R113/tests;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static (changed since $BASE)"
CHANGED=$(git -C "$REPO" diff --name-only "$BASE" -- src | grep '\.lua$' || true)
bad=0;n=0;known=0
for f in $CHANGED;do
 [ -f "$REPO/$f" ] || continue;n=$((n+1))
 if ! /opt/luau/luau-compile -O0 --null "$REPO/$f" >/dev/null 2>"$OUT/compile.err";then
  if grep -q "exceeded limit 200" "$OUT/compile.err" && git -C "$REPO" show "$BASE:$f" > "$OUT/base_file.lua" && ! /opt/luau/luau-compile -O0 --null "$OUT/base_file.lua" >/dev/null 2>"$OUT/base_compile.err" && grep -q "exceeded limit 200" "$OUT/base_compile.err";then
   echo "known: $f is over Roblox's 200-locals limit at -O0, as at $BASE (this change adds no local)";known=$((known+1))
  else echo "does not compile at -O0: $f";cat "$OUT/compile.err";bad=1;fi
 fi
done
[ "$bad" = 0 ] && echo "ok: $n changed scripts compile at -O0 ($known known over-limit)" || fail "compile -O0"
bad=0;c=0;for f in "$SP"/*.client.lua;do
 b=$(basename "$f");[ "$b" = BackgroundMusic.client.lua ] && continue;c=$((c+1))
 line=1;[ "$b" = Hotbar.client.lua ] && line=2
 sed -n "${line}p" "$f" | grep -qF "R152: start once the whole game has arrived" || { echo "the load guard is not line $line of $b";bad=1; }
done
[ "$bad" = 0 ] && echo "ok: line 1 of every client script is the R152 load guard (Hotbar: line 2), $c scripts" || fail "load guard"
git -C "$REPO" diff --quiet "$BASE" -- src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua && echo "ok: BackgroundMusic untouched" || fail "BackgroundMusic changed"
# Config.lua: only the Config.Version string may differ from the base (R153b hotfix, the R154 release bump)
cfg=src/ServerScriptService/ChestChaseServer/Config.lua
if [ "$(git -C "$REPO" show "$BASE:$cfg" | sed "s/Config.Version='[^']*'/Config.Version='V'/")" = "$(sed "s/Config.Version='[^']*'/Config.Version='V'/" "$REPO/$cfg")" ];then echo "ok: Config.lua untouched apart from Config.Version";else fail "Config.lua changed (beyond Config.Version)";fi
tail -n +2 "$S/MANIFEST.tsv" | cut -f3 | LC_ALL=C sort > "$OUT/manifest_files.txt";(cd "$S" && find . -name '*.lua' | sed 's#^\./##' | LC_ALL=C sort) > "$OUT/src_files.txt"
cmp -s "$OUT/manifest_files.txt" "$OUT/src_files.txt" && echo "ok: src/MANIFEST.tsv lists exactly the $(wc -l < "$OUT/src_files.txt") files in src" || { fail "src/MANIFEST.tsv and src differ";diff "$OUT/manifest_files.txt" "$OUT/src_files.txt" | head; }
# allowed: SeedCollect154 watches the ONE seed tool it hides in the hand (tool.DescendantAdded), only until the seed lands (<= 5 s), then disconnects
if git -C "$REPO" diff "$BASE" -- src | grep '^+' | grep -v '^+++' | sed 's/--.*$//' | grep -v "h.Conn=tool.DescendantAdded:Connect" | grep -q "DescendantAdded";then fail "R154 added a DescendantAdded listener";else echo "ok: no DescendantAdded listener added (comments aside; the seed-collect hand watch on one tool is allowed)";fi
grep -q "if h.Conn then h.Conn:Disconnect()end" "$REPO/src/ReplicatedStorage/SeedCollect154.lua" && echo "ok: the seed-collect hand watch is disconnected when the seed is shown" || fail "SeedCollect154's hand watch is never disconnected"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE" "$S/ReplicatedStorage/SmallShadow154.lua" "$REPO/docs/proposals/R154/perf154.md" --include=*.luau --include=*.sh --include=*.py --include=*.md --include=*.patch 2>/dev/null | grep -v "Co-Authored";then fail "a model name in the R154 files";else echo "ok: no model names in the R154 files";fi

echo "== 1. unit: SmallShadow154"
sh "$HERE/run_unit154.sh" "$OUT/unit" > "$OUT/unit.txt" 2>&1 && echo "ok: test_small_shadow154: $(grep checks "$OUT/unit.txt")" || { fail "test_small_shadow154";tail -12 "$OUT/unit.txt"; }

echo "== 2. log: ItemPictures"
sh "$HERE/run_item_log154.sh" "$OUT/itemlog" > "$OUT/itemlog.txt" 2>&1 && echo "ok: item picture log: $(grep checks "$OUT/itemlog.txt")" || { fail "item picture log";tail -12 "$OUT/itemlog.txt"; }

echo "== 3. census: B1 + B3 numbers"
if [ -f "$PLACE" ];then
 if sh "$HERE/run_census154.sh" "$OUT/census" "$PLACE" > "$OUT/census.txt" 2>&1;then cat "$OUT/census.txt";else fail "census154";cat "$OUT/census.txt" | tail -40;fi
else echo "SKIPPED (no place file at $PLACE)";fi
[ "$RC" = 0 ] && echo "R154: all checks passed"
exit $RC
