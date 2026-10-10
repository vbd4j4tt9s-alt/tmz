#!/bin/sh
# Usage: sh run_dropped158b.sh [scratch dir]   (needs /opt/luau/luau + luau-compile, python3, git)
# R158b, three owner requests, on the Roblox mock (/opt/luau/luau) with the REAL code of this checkout:
#  1. "make it so that dropped packs have a highlight and can be seen": DroppedPackHighlight158b.client.lua + DroppedPackLook158b.lua (client only; the server is untouched)
#  2. "remove the sound effect for swinging a bat, there is only a sound effect for hitting someone": the whoosh is gone (its tests and mutants are in
#     docs/proposals/R158/tests/run_bats158.sh, R150's test_inputs.luau and the older suites; here: the whole src still has no swing sound, and the whoosh still serves the others)
#  3. "add the dirt sound effect when making holes": digging a hole plays the planting 'Dig' sound (TrackHoleClient; its tests are holes_R122's test_holes_client.luau)
#  0. static        everything compiles at -O0 and is in src/MANIFEST.tsv, the new client script starts with the R152 load guard, no model names, the server and
#                   the R151 frozen files are untouched, nothing is made per frame, words players see are simple, registered in tools/tests/run_all_suites.sh
#  1. test_dropped158b.luau   the rules; the look (Highlight, marker, beam); gone when taken / returned / destroyed / streamed out; the 31-Highlight budget with
#                   other Highlights around; Fast Mode, Reduced Motion, a slow device; StreamingEnabled; no per-frame cost; no leaks over 400 drops
#  2. the holes tests   test_holes_client.luau (digging plays the planting Dig sound; covering and the trap thud as before), also with the Dig id swapped in
#                   PlantingEffects (the client reads it from there)
#  3. mutations     broken copies of the client script / the rules / TrackHoleClient: each must fail a test
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${R158B_BASE:-047b5c8}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;SP=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
RC=0;fail(){ echo "FAIL: $1";RC=1; }
CLIENT=$SP/DroppedPackHighlight158b.client.lua;LOOK=$RSD/DroppedPackLook158b.lua
echo "== 0. static"
for f in "$CLIENT" "$LOOK" "$SP/TrackHoleClient.client.lua" "$SP/BatClient.client.lua" "$RSD/BatConfig.lua";do
 /opt/luau/luau-compile -O0 --binary "$f" >/dev/null 2>&1 || fail "$f does not compile at -O0"
done
echo "ok: the new and the changed scripts compile at -O0"
grep -q "	ReplicatedStorage/DroppedPackLook158b	ReplicatedStorage/DroppedPackLook158b.lua" "$S/MANIFEST.tsv" && grep -q "	StarterPlayer/StarterPlayerScripts/DroppedPackHighlight158b	StarterPlayer/StarterPlayerScripts/DroppedPackHighlight158b.client.lua" "$S/MANIFEST.tsv" \
 && echo "ok: the two new scripts are in src/MANIFEST.tsv" || fail "a new script is not in src/MANIFEST.tsv"
head -1 "$CLIENT" | grep -q "R152: start once the whole game has arrived" && [ "$(grep -c "R152: start once the whole game has arrived" "$CLIENT")" = 1 ] && [ "$(head -1 "$CLIENT")" = "$(head -1 "$SP/MutationHighlights.client.lua")" ] \
 && echo "ok: DroppedPackHighlight158b starts with the R152 load guard (line 1, once, the same line as the others)" || fail "line 1 of DroppedPackHighlight158b.client.lua is not the R152 load guard"
for f in "$SP/TrackHoleClient.client.lua" "$SP/BatClient.client.lua";do head -1 "$f" | grep -q "R152: start once the whole game has arrived" || fail "line 1 of $f is not the load guard";done
echo "ok: TrackHoleClient and BatClient keep their load guard on line 1"
if grep -niE "cla[u]de|op[u]s|sonn[e]t|haik[u]|gp[t]-?[0-9]" "$CLIENT" "$LOOK" "$HERE"/* "$P/R158b"/*.md >/dev/null 2>&1;then fail "a model name in the R158b files";else echo "ok: no model names in the R158b files";fi
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 if [ -z "$(git -C "$REPO" diff --name-only "$BASE" -- src/ServerScriptService docs/proposals/R151/tests/frozen.sha256 src/StarterPlayer/StarterPlayerScripts/SeedPackRender.client.lua src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua src/ReplicatedStorage/LocalSfx.lua)" ];then
  echo "ok: the server, the frozen list, SeedPackRender, the Hotbar and LocalSfx are identical to $BASE (the dropped pack is drawn by the client alone)"
 else fail "a server / frozen / shared file changed against $BASE: $(git -C "$REPO" diff --name-only "$BASE" -- src/ServerScriptService docs/proposals/R151/tests/frozen.sha256 src/StarterPlayer/StarterPlayerScripts/SeedPackRender.client.lua src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua src/ReplicatedStorage/LocalSfx.lua)";fi
 if [ "$(git -C "$REPO" show "$BASE:src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua" | sed -n 1,2p)" = "$(sed -n 1,2p "$SP/Hotbar.client.lua")" ];then echo "ok: Hotbar lines 1-2 unchanged";else fail "Hotbar lines 1-2 changed";fi
else echo "skip: $BASE is not in this checkout (the unchanged-files checks need it)";fi
(cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | sha256sum -c --quiet) && echo "ok: the R151 frozen hashes hold (Config.lua and the rest)" || fail "the R151 frozen hash check fails"
python3 - "$CLIENT" "$LOOK" <<'EOF' || fail "something is made per frame / a word players see is not simple"
import re, sys
bad = 0
client = open(sys.argv[1], encoding='utf-8').read()
# the per-frame function: no table, no closure, no instance
i = client.find('local function frame(dt)');j = client.find('\nend', i)
body = re.sub(r"'[^'\n]*'", "''", client[i:j]);body = re.sub(r'--[^\n]*', '', body)
for what, pat in (('a table', r'\{'), ('a closure', r'function\s*\('), ('an instance', r'Instance\.new')):
    if re.search(pat, body[len('local function frame(dt)'):]): print('per frame:', what, 'made in frame()'); bad += 1
# the strings players can see
texts = re.findall(r"\.Text='([^']*)'", client) + re.findall(r"string\.format\('([^']*)'", open(sys.argv[2], encoding='utf-8').read())
for t in texts:
    if re.search(r"\b(u|ur|ya|plz)\b", t, re.I): print('not simple words:', t); bad += 1
if not texts: print('no player-visible text found'); bad += 1
print('ok: nothing is made per frame in frame() (no table, no closure, no instance); player-visible text: %s' % ', '.join('"%s"' % t for t in texts) if not bad else 'FAIL')
sys.exit(1 if bad else 0)
EOF
# 3 owner requests, the files they may touch
if grep -nE "digSound:Play\(fx\.Position\)$|118769294546013" "$SP/TrackHoleClient.client.lua" | grep -vE "^[0-9]+: *--";then fail "TrackHoleClient digs with the old recording or hard-codes the Dig id";else echo "ok: TrackHoleClient reads the Dig sound from PlantingEffects.Sounds (no id in the script) and digging does not play the long recording";fi
grep -q "Id='rbxassetid://118769294546013',Volume=.5,Pitch={.96,1.04}" "$RSD/PlantingEffects.lua" && echo "ok: the planting Dig sound is 118769294546013 at .5, pitch .96 - 1.04" || fail "the planting Dig row changed"
grep -q "burst(fx.Position,6,soil,1);digSound:Play(fx.Position,C.DigSound.CoverPitch)" "$SP/TrackHoleClient.client.lua" && grep -q "burst(fx.Position,10,soil,3);Sfx.Play(sounds.Land,fx.Position,.5,.9,2)" "$SP/TrackHoleClient.client.lua" \
 && echo "ok: the COVER sound and the trap (Land) sound lines are as they were" || fail "the cover or the trap sound line changed"
grep -q "^Sfx.WhooshId='rbxassetid://9120768742'" "$RSD/LocalSfx.lua" && echo "ok: LocalSfx.WhooshId stays (fast travel and go-to-top use it); the bat no longer does" || fail "LocalSfx.WhooshId is gone"
if grep -rnE "WhooshId|SwingSound" "$S" | grep -vE "LocalSfx.lua|TravelButtons.client.lua|EconomyClient.client.lua";then fail "something else still uses the whoosh / swing-sound settings";else echo "ok: nothing in src but LocalSfx, TravelButtons and EconomyClient mentions the whoosh; no SwingSound setting anywhere";fi
sed -n 6p "$T/run_all_suites.sh" | grep -q " docs/proposals/R158b/tests/run_dropped158b.sh .* docs/proposals/R156/tests/run_pyramid156.sh; do" && echo "ok: registered on line 6 of tools/tests/run_all_suites.sh (just before the pyramid suite)" || fail "not registered on line 6 of run_all_suites.sh just before run_pyramid156.sh"
# -- the world -------------------------------------------------------------------------------------------------------------------------------------
build(){ # $1 dir, then Name=path overrides (this checkout's modules and script, as a bundle for the R113 world)
 d=$1;shift;mkdir -p "$d"
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$HERE/test_dropped158b.luau" "$d/"
 python3 "$T/bundle.py" "$d/rs_bundle.luau" ClientFxBudget="$RSD/ClientFxBudget.lua" DroppedPackLook158b="$LOOK" DroppedPackHighlight158b="$CLIENT" "$@" >/dev/null
}
run(){ # $1 dir, $2 test: 0 when it passes
 if (cd "$1" && timeout 900 /opt/luau/luau "$2" > "$2.log" 2>&1);then return 0;else return 1;fi
}
echo "== 1. test_dropped158b"
build "$OUT/dp"
if run "$OUT/dp" test_dropped158b.luau;then grep -v '^WARN' "$OUT/dp/test_dropped158b.luau.log" | tail -1;else fail "test_dropped158b";grep -v '^WARN' "$OUT/dp/test_dropped158b.luau.log" | tail -30;fi
holes(){ # $1 dir, optional $2 old, $3 new: the holes_R122 client test with this checkout's bundle (one text replaced in it when asked)
 d=$1;mkdir -p "$d"
 cp "$T/roblox.luau" "$P/holes_R122/tests/world.luau" "$P/holes_R122/tests/test_holes_client.luau" "$d/"
 python3 "$P/holes_R122/tests/mkbundle.py" "$d" >/dev/null
 if [ -n "$2" ];then python3 - "$d/rs_bundle.luau" "$2" "$3" <<'EOF'
import sys
p, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(p, encoding='utf-8').read()
if old not in s: print('the replaced text is not in the bundle: ' + old); sys.exit(1)
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
EOF
 fi
}
echo "== 2. the holes client test: digging plays the planting Dig sound"
holes "$OUT/holes"
if run "$OUT/holes" test_holes_client.luau;then grep -v '^WARN' "$OUT/holes/test_holes_client.luau.log" | tail -1;else fail "test_holes_client";grep -v '^WARN' "$OUT/holes/test_holes_client.luau.log" | tail -20;fi
holes "$OUT/holes_swapped" "Id='rbxassetid://118769294546013',Volume=.5" "Id='rbxassetid://5550001',Volume=.5"
if run "$OUT/holes_swapped" test_holes_client.luau;then echo "ok: with the Dig id swapped in PlantingEffects the holes play the NEW id (the client reads it from there): $(grep -v '^WARN' "$OUT/holes_swapped/test_holes_client.luau.log" | tail -1)";else fail "test_holes_client with a swapped Dig id";grep -v '^WARN' "$OUT/holes_swapped/test_holes_client.luau.log" | tail -20;fi
[ $RC = 0 ] || { echo "R158b dropped pack / holes: FAILED (before the mutations)";exit 1; }
echo "== 3. mutations (each break must make a test fail)"
M=$OUT/mut;mkdir -p "$M"
mutate(){ # $1 name, $2 source file, $3 sed expression, $4 module name in the bundle
 m=$M/$1.lua;sed "$3" "$2" > "$m"
 if cmp -s "$m" "$2";then fail "bad mutation $1: the sed changed nothing";return;fi
 d=$M/w_$1;rm -rf "$d";build "$d" "$4=$m"
 if run "$d" test_dropped158b.luau;then fail "MUTATION $1 SURVIVED (test_dropped158b passed)"
 else echo "killed $1: $(grep -c '^FAIL' "$d/test_dropped158b.luau.log") failing checks, e.g. $(grep -m1 '^FAIL' "$d/test_dropped158b.luau.log" | cut -c1-110)";fi
 rm -rf "$d"
}
C=DroppedPackHighlight158b;K=DroppedPackLook158b
mutate not_always_on_top "$CLIENT" "s/h.Adornee=d.Bag;h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop/h.Adornee=d.Bag;h.DepthMode=Enum.HighlightDepthMode.Occluded/" $C
mutate marker_not_on_top "$CLIENT" "s/g.Adornee=d.Anchor;g.AlwaysOnTop=true;/g.Adornee=d.Anchor;g.AlwaysOnTop=false;/" $C
mutate not_in_the_budget "$CLIENT" "s/^ if Fx then pcall(Fx.TrackHighlight,h)end.*\$//" $C
mutate room_ignored "$CLIENT" "s/L.Limits(tier,held,roomNow())/L.Limits(tier,held,99)/" $C
mutate no_limit "$LOOK" "s/^L.MaxHighlights={3,4,4}/L.MaxHighlights={99,99,99}/" $K
mutate farthest_first "$LOOK" "s/table.sort(items,function(a,b)return a.Score<b.Score end)/table.sort(items,function(a,b)return a.Score>b.Score end)/" $K
mutate no_stickiness "$LOOK" "s/^L.Stick=6 /L.Stick=0 /" $K
mutate no_highlight_in_fast_mode "$LOOK" "s/^L.MaxHighlights={3,4,4}/L.MaxHighlights={0,4,4}/" $K
mutate beam_in_fast_mode "$LOOK" "s/^L.MaxBeams={0,3,6}/L.MaxBeams={6,3,6}/" $K
mutate beam_too_low "$LOOK" "s/^L.BeamHeight=90;/L.BeamHeight=6;/" $K
mutate unlimited_markers "$LOOK" "s/^L.MaxMarkers=16/L.MaxMarkers=99/" $K
mutate pulse_in_fast_mode "$CLIENT" "s/moving=tier>1 and Gui.ReducedMotionEnabled~=true/moving=Gui.ReducedMotionEnabled~=true/" $C
mutate reduced_motion_ignored "$CLIENT" "s/moving=tier>1 and Gui.ReducedMotionEnabled~=true/moving=tier>1/" $C
mutate everyone_bobs "$LOOK" "s/^L.MaxAnimated=6 /L.MaxAnimated=99 /" $K
mutate any_pack_highlighted "$CLIENT" "s/ if not host or host:GetAttribute(L.Attribute)~=true then return end.*\$/ if not host then return end/;s/or host:GetAttribute(L.Attribute)~=true or now-d.Born>L.MaxAge then stale/or now-d.Born>L.MaxAge then stale/" $C
mutate no_cleanup_on_destroy "$CLIENT" "s/^ table.insert(d.Conns,bag.Destroying:Connect(function()remove(bag)end))\$//;s/^ table.insert(d.Conns,bag.AncestryChanged:Connect(function()if not bag:IsDescendantOf(workspace)then remove(bag)end end))\$//" $C
mutate no_cleanup_on_ancestry "$CLIENT" "s/^ table.insert(d.Conns,bag.AncestryChanged:Connect(function()if not bag:IsDescendantOf(workspace)then remove(bag)end end))\$//" $C
mutate no_cleanup_on_tag_removed "$CLIENT" "s/,CS:GetInstanceRemovedSignal(L.PackTag):Connect(remove)}/}/" $C
mutate anchor_not_destroyed "$CLIENT" "s/^ if d.Anchor then d.Anchor:Destroy()end\$//" $C
mutate connections_left "$CLIENT" "s/^ for _,c in ipairs(d.Conns)do c:Disconnect()end\$//" $C
mutate loop_never_stops "$CLIENT" "s/ if count<=0 and loop then loop:Disconnect();loop=nil end\$//" $C
mutate marker_made_every_tick "$CLIENT" "s/  if d.Rank<=nM and not d.Gui then makeMarker(d)end/  if d.Rank<=nM then makeMarker(d)end/" $C
mutate no_retry_until_placed "$CLIENT" "s/    local pos,fromBody=whereIs(d);if pos then local ok=pcall(build,d,pos)/    local pos,fromBody=whereIs(d);if pos and os.clock()-d.Born<.01 then local ok=pcall(build,d,pos)/" $C
mutate no_move_onto_body "$CLIENT" "s/   elseif not d.FromBody then/   elseif false then/" $C
mutate no_pivot_fallback "$CLIENT" "s/ local ok,pivot=pcall(function()return d.Bag:GetPivot()end)/ local ok,pivot=false,nil/" $C
mutate drawn_at_the_origin "$CLIENT" "s/^ if not d.Bag:FindFirstChildWhichIsA('BasePart',true)then return nil end.*\$//" $C
mutate no_watchdog "$CLIENT" "s/or host:GetAttribute(L.Attribute)~=true or now-d.Born>L.MaxAge then stale/or now-d.Born>L.MaxAge then stale/" $C
mutate script_leaves_effects "$CLIENT" "s/ if loop then loop:Disconnect();loop=nil end;folder:Destroy()\$/ if loop then loop:Disconnect();loop=nil end/" $C
mutate script_keeps_tags "$CLIENT" "s/ alive=false;for _,c in ipairs(conns)do c:Disconnect()end\$/ alive=false/" $C
mutate no_start_scan "$CLIENT" "s/^for _,bag in ipairs(CS:GetTagged(L.PackTag))do add(bag)end\$//" $C
mutate marker_inside_pack "$CLIENT" "s/d.Up=d.Height\*.5+L.MarkerAbove/d.Up=L.MarkerAbove/" $C
mutate no_distance_text "$CLIENT" "s/ if d.Away then local text=L.Distance(d.Distance);if d.Away.Text~=text then d.Away.Text=text end end//" $C
mutate no_marker_on_far_drops "$LOOK" "s/^L.MarkerRange=3000 /L.MarkerRange=100 /" $K
# TrackHoleClient (the dirt sound): digging must play the planting Dig sound from PlantingEffects
hmut(){ # $1 name, $2 old text, $3 new text (replaced in the bundle's TrackHoleClient)
 d=$M/h_$1;rm -rf "$d";if ! holes "$d" "$2" "$3";then fail "bad mutation $1: its text is not in the bundle";return;fi
 if run "$d" test_holes_client.luau;then fail "MUTATION $1 SURVIVED (test_holes_client passed)"
 else echo "killed $1: $(grep -c '^FAIL' "$d/test_holes_client.luau.log") failing checks, e.g. $(grep -m1 '^FAIL' "$d/test_holes_client.luau.log" | cut -c1-110)";fi
 rm -rf "$d"
}
hmut dig_old_recording "burst(fx.Position,8,soil,2.2);digThud(fx.Position)" "burst(fx.Position,8,soil,2.2);digSound:Play(fx.Position)"
hmut dig_silent "burst(fx.Position,8,soil,2.2);digThud(fx.Position)" "burst(fx.Position,8,soil,2.2)"
hmut dig_fixed_pitch "lo+(hi-lo)*math.random()" "1"
hmut dig_wrong_volume "Sfx.Play(digDef.Id,position,digDef.Volume," "Sfx.Play(digDef.Id,position,.2,"
hmut dig_not_positional "Sfx.Play(digDef.Id,position,digDef.Volume," "Sfx.Play(digDef.Id,nil,digDef.Volume,"
# (a hard-coded id plays the same file today: only a swapped Dig id shows it)
d=$M/h_dig_id_hard_coded_swapped;rm -rf "$d";holes "$d" "Sfx.Play(digDef.Id,position," "Sfx.Play('rbxassetid://118769294546013',position,"
python3 - "$d/rs_bundle.luau" <<'EOF'
import sys
p = sys.argv[1];s = open(p, encoding='utf-8').read()
a = "Id='rbxassetid://118769294546013',Volume=.5";assert a in s;open(p, 'w', encoding='utf-8').write(s.replace(a, "Id='rbxassetid://5550001',Volume=.5", 1))
EOF
if run "$d" test_holes_client.luau;then fail "MUTATION dig_id_hard_coded survived a swapped Dig id";else echo "killed dig_id_hard_coded (with the Dig id swapped in PlantingEffects): $(grep -c '^FAIL' "$d/test_holes_client.luau.log") failing checks, e.g. $(grep -m1 '^FAIL' "$d/test_holes_client.luau.log" | cut -c1-110)";fi
hmut cover_loses_its_sound "burst(fx.Position,6,soil,1);digSound:Play(fx.Position,C.DigSound.CoverPitch)" "burst(fx.Position,6,soil,1)"
[ $RC = 0 ] && echo "R158b dropped pack / holes: all passed" || echo "R158b dropped pack / holes: FAILED"
exit $RC
