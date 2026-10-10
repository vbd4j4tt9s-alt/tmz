#!/bin/sh
# Usage: sh run_pack_leak158d.sh [scratch dir]   (needs /opt/luau/luau + luau-compile, python3, git)
# R158d (owner: "the mech pack seeds, and also check for other seeds that have similar issues: their effects are already there even before the pack opens. This ruins
# the surprise of the pack opening"), on the Roblox mock (/opt/luau/luau) with the REAL scripts of this checkout (docs/proposals/R158b/pack_leak158d.md):
#  0. static   everything compiles at -O0 (no function over 180 local registers), line 1 of every client script and Hotbar lines 1-2 are as they were, Config.lua and
#              the R151 frozen files are untouched, nothing of the server changed, only the four files of this fix changed in src, the hooks are one line each,
#              no model names in the R158d files, registered in tools/tests/run_all_suites.sh
#  1. test_pack_leak158d.luau   the real SeedPackClient, PackOpeningFeedback, RarePullCinematic / RarePullScenes, ItemCosmetics and ItemEffectAnchor:
#              before the reveal a pack (Mech, Void, Verity, biome) carries no result and no effect; while the seed is hidden in the pack (the world reveal and the
#              story scenes on the stage) not one frame shows its Mech scanner, its weather effect or an effect built into it; they come with the seed (within 3 frames);
#              nothing is left
#  2. the teeth   the same test against the commit before this fix (R158D_BASE, default f6ad8c3: git archive): it must FAIL there (the leak is real and the test sees it)
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R158D_BASE:-f6ad8c3}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
for f in "$RSD/ItemEffectAnchor.lua" "$RSD/RarePullScenes.lua" "$SP/SeedPackClient.client.lua" "$SP/ItemCosmetics.client.lua";do
 /opt/luau/luau-compile -O0 --binary "$f" >/dev/null 2>&1 || fail "$f does not compile at -O0"
done
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 && echo "ok: $(tail -1 "$OUT/o0.log")" || { tail -5 "$OUT/o0.log";fail "the -O0 compile check (no function over 180 local registers)"; }
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 changed=$(git -C "$REPO" diff --name-only "$BASE" -- src | sort | tr '\n' ' ')
 want="src/ReplicatedStorage/ItemEffectAnchor.lua src/ReplicatedStorage/RarePullScenes.lua src/StarterPlayer/StarterPlayerScripts/ItemCosmetics.client.lua src/StarterPlayer/StarterPlayerScripts/SeedPackClient.client.lua "
 [ "$changed" = "$want" ] && echo "ok: since $BASE exactly four files of src changed: ItemEffectAnchor, RarePullScenes, ItemCosmetics, SeedPackClient (no server file, no Config, no pack art, no reveal timing)" || echo "note: src files changed since $BASE: $changed(this fix's four: $want)"
 for f in src/StarterPlayer/StarterPlayerScripts/ItemCosmetics.client.lua src/StarterPlayer/StarterPlayerScripts/SeedPackClient.client.lua;do
  [ "$(head -1 "$REPO/$f")" = "$(git -C "$REPO" show "$BASE:$f" | head -1)" ] || fail "$f: line 1 (the load guard) changed"
 done
 echo "ok: line 1 (the R152 load guard) of the two changed client scripts is as it was"
 [ "$(git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" | sed -n 1,2p)" = "$(sed -n 1,2p "$SP/Hotbar.client.lua")" ] && echo "ok: Hotbar lines 1-2 unchanged" || fail "Hotbar lines 1-2 changed"
 srv=$(for c in $(git -C "$REPO" rev-list "$BASE"..HEAD -- src/ReplicatedStorage/ItemEffectAnchor.lua);do git -C "$REPO" diff-tree --no-commit-id --name-only -r "$c" -- src/ServerScriptService;done | grep -v "ChestChaseServer/Config.lua$" | sort -u)
 # (only this fix's own commits; Config.lua's release Version line is pinned by frozen.sha256)
 [ -z "$srv" ] && echo "ok: nothing of the server changed (the client was never told the result early: the server sets RevealSeedId / Rarity / Weather and RevealAt on the 5th click, in one go)" || fail "a server file changed"
 # every line of this fix in SeedPackClient / RarePullScenes is an ADDED line (no existing line was edited), so the pins of the older suites hold
 gone=$(git -C "$REPO" diff -U0 "$BASE" -- src/StarterPlayer/StarterPlayerScripts/SeedPackClient.client.lua src/ReplicatedStorage/RarePullScenes.lua | grep '^-' | grep -vc '^---' || true)
 [ "$gone" = 0 ] && echo "ok: SeedPackClient and RarePullScenes only gained lines (no existing line edited: every older suite's line pin still holds)" || fail "$gone existing lines of SeedPackClient / RarePullScenes were edited"
else echo "skip: $BASE is not in this checkout (the changed-files checks and the teeth need it)";fi
[ "$(grep -c "ItemEffectAnchor).Hold(seed)" "$SP/SeedPackClient.client.lua")" = 1 ] && [ "$(grep -c "ItemEffectAnchor).Release(record.Seed)" "$SP/SeedPackClient.client.lua")" = 1 ] \
 && echo "ok: SeedPackClient: the hold is one line (when the seed is cloned), the release one line (on the frame it shows)" || fail "SeedPackClient: the hold / release hooks are not one line each"
[ "$(grep -c "Anchor.Hold" "$RSD/RarePullScenes.lua")" = 1 ] && [ "$(grep -c "Anchor.Release" "$RSD/RarePullScenes.lua")" = 1 ] && echo "ok: RarePullScenes: the hold is one line (the hero seed is built), the release one line (its first visible frame)" || fail "RarePullScenes: the hold / release hooks are not one line each"
[ "$(grep -c "FxHeld" "$SP/ItemCosmetics.client.lua")" = 3 ] && echo "ok: ItemCosmetics: the flag is one comment, one watch (it looks again the frame the seed is released) and one check" || fail "ItemCosmetics: FxHeld is not read in exactly three places"
(cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | sha256sum -c --quiet) && echo "ok: the R151 frozen hashes hold (Config.lua and the rest)" || fail "the R151 frozen hash check fails"
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R158b/tests/run_pack_leak158d.sh " && echo "ok: registered on line 6 of tools/tests/run_all_suites.sh" || fail "not registered on line 6 of tools/tests/run_all_suites.sh"
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$HERE/test_pack_leak158d.luau" "$HERE/run_pack_leak158d.sh" "$P/R158b/pack_leak158d.md" "$RSD/ItemEffectAnchor.lua" 2>/dev/null | grep -v "^Binary";then fail "a model name in the R158d files";else echo "ok: no model names in the R158d files";fi
[ $RC = 0 ] || exit 1
INV=$P/inventory_R113/tests
prep() { # $1 = a src tree, $2 = the run dir: the mock, the harness, the test and a bundle of that tree's modules and scripts
 mkdir -p "$2"
 cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$P/R152/tests/rare152_env.luau" "$P/R152/tests/sound_levels.luau" "$HERE/test_pack_leak158d.luau" "$2/"
 sed "s#^src = .*#src = '$1'#" "$P/R151/tests/mkbundle_rare.py" > "$2/mkbundle_rare.py"
 python3 "$2/mkbundle_rare.py" "$2" all-client >/dev/null
}
echo "== 1. test_pack_leak158d (this checkout)"
prep "$S" "$OUT/run"
if (cd "$OUT/run" && timeout 1800 /opt/luau/luau test_pack_leak158d.luau > test.log 2>&1);then grep -v '^WARN' "$OUT/run/test.log" | grep -v '^  ' | tail -3
else grep -v '^WARN' "$OUT/run/test.log" | tail -40;fail "test_pack_leak158d";fi
[ $RC = 0 ] || exit 1
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 echo "== 2. the teeth: the same test against $BASE (it must fail there)"
 rm -rf "$OUT/base";mkdir -p "$OUT/base"
 git -C "$REPO" archive "$BASE" src | tar -x -C "$OUT/base"
 prep "$OUT/base/src" "$OUT/base/run"
 (cd "$OUT/base/run" && timeout 1800 /opt/luau/luau test_pack_leak158d.luau > test.log 2>&1) && fail "the test passes on $BASE: it does not see the leak" || true
 n=$(grep -c '^FAIL' "$OUT/base/run/test.log" || true)
 if [ "$n" -ge 10 ];then echo "ok: on $BASE the test fails $n checks (the Mech scanner round the closed pack, a weather effect, the hero seed's sparkles): the leak is real and the test sees it"
 else fail "on $BASE only $n checks fail (want at least 10)";fi
fi
[ $RC = 0 ] || exit 1
echo "R158d pack leak suite passed"
