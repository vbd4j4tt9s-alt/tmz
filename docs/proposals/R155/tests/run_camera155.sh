#!/bin/sh
# Usage: sh run_camera155.sh [scratch dir] [only]
# R155 cinematic camera for the Secret / Cosmic / King story scenes (docs/proposals/R155/cinematic_camera.md), on the Roblox mock (/opt/luau/luau)
# with the REAL scripts of this checkout:
#  0. static  - the new module is in src/MANIFEST.tsv (sorted); since the R154 release (8aa15fd) exactly four files of src changed (the new
#               RarePullCamera155, RarePullCinematic, the manifest, and RarePullCard for the R155 SKIP button): no client script (their load
#               guard lines), no BackgroundMusic, no Config.Version; the three modules compile at -O0 within 180 local registers per function;
#               no R155 line touches Lighting; the camera's per-frame code makes no table and no closure, nor does the director's (sceneCamera);
#               no model names in the R155 files.
#  1. test_rare_camera155.luau - the rig on its own (cuts on their beats and sounds, comfort limits, dead stop / skip frame, depth of field,
#               the hero framing through a 120 s wait, the wait's drift, Calm, the clearance from every stage part) and the real director frame by
#               frame at 30 / 60 / 144 fps (the camera before / after the stage = today's, in the stage = the rig, the cuts on their frames with
#               their sounds within 0.01 s, RarePullDof on every device, every exit path, a skip at every phase, the setting, Common..Mythic);
#               the R155 SKIP button (where it goes on every screen, clear of the HUD, its timing, the only skip: spam does nothing); R155 review: modal exactly while it shows
#               (Shift Lock / first person), no modal button left on any way out, the keyboard's Enter key / the gamepad's B, never over the pity bars, nothing made per frame.
#  2. against the R154 release, byte for byte: R152's seed-opening fingerprints (run_perf152.sh, PERF_BASE=8aa15fd, ONLY=seed: every rarity on
#               desktop / phone / low quality at 60 and 30 fps and an onlooker's Secret / King; every frame of the stage, the world effects, the
#               characters, the card, the camera and its grade / blur, Lighting, and the sound schedule) with perf155_opts.luau: the ONLY allowed
#               differences are the Camera's CFrame / Focus / FieldOfView while a story stage is on screen, the RarePullDof effect, and the skip's
#               own UI (the SKIP button; the corner hint while it is not the collect hint: R154's "CLICK TO SKIP").
#               "only" skips this step (it takes a few minutes; the seed runs need no place file, so none is read).
# The other suites this change is run with: R151 run_rare_pull.sh, R152 run_seed_opening.sh (only), R152 run_zfight_sweep.sh (its opening step
# also checks the camera's clearance), R152 run_perf152.sh, R152 run_load_guard.sh, R153 run_jitter.sh / run_hotbar.sh, tools/tests/check_compile_O0.sh.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};MODE=$2;BASE=${R155_BASE:-8aa15fd}
mkdir -p "$OUT/cl"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;RSD=$S/ReplicatedStorage
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static (since $BASE)"
grep -q "^ModuleScript	ReplicatedStorage/RarePullCamera155	ReplicatedStorage/RarePullCamera155.lua$" "$S/MANIFEST.tsv" || fail "RarePullCamera155 is not in src/MANIFEST.tsv"
python3 - "$S/MANIFEST.tsv" <<'PY' || RC=1
import sys
rows=open(sys.argv[1]).read().splitlines()[1:]
assert rows==sorted(rows,key=lambda l:l.split('\t')[1]),'FAIL: MANIFEST not sorted'
print('ok: RarePullCamera155 is in src/MANIFEST.tsv (sorted)')
PY
# (other R155 work changes other src files too: this checks the camera's own corner - the RarePull* modules - and the two never-touch files)
CHANGED=$( (git -C "$REPO" diff --name-only "$BASE" -- 'src/ReplicatedStorage/RarePull*';git -C "$REPO" ls-files -o --exclude-standard -- 'src/ReplicatedStorage/RarePull*') | sort -u | tr '\n' ' ')
WANT="src/ReplicatedStorage/RarePullCamera155.lua src/ReplicatedStorage/RarePullCard.lua src/ReplicatedStorage/RarePullCinematic.lua "
[ "$CHANGED" = "$WANT" ] && echo "ok: of the RarePull modules exactly these changed since $BASE: $CHANGED" || fail "RarePull modules changed since $BASE: $CHANGED(want: $WANT)"
{ git -C "$REPO" diff --quiet "$BASE" -- src/StarterPlayer/StarterPlayerScripts/BackgroundMusic.client.lua || sh "$REPO/tools/tests/bgm_frozen.sh" "$REPO"; } && echo "ok: BackgroundMusic untouched (or the R156 music script frozen in frozen.sha256)" || fail "BackgroundMusic changed"
for f in RarePullCamera155 RarePullCinematic RarePullCard;do
 /opt/luau/luau-compile -O0 --binary "$RSD/$f.lua" >/dev/null 2>"$OUT/c.err" && ! grep -q Error "$OUT/c.err" || { fail "$f does not compile at -O0";cat "$OUT/c.err"; }
 peak=$(/opt/luau/luau-compile -O0 -g2 --text "$RSD/$f.lua" 2>/dev/null | awk '/^local [0-9]+ \(.*\): reg [0-9]+,/ { s=$0; sub(/.*\): reg /,"",s); sub(/,.*/,"",s); if(s+1>m) m=s+1 } END{print m+0}')
 [ "$peak" -le 180 ] && echo "ok: $f compiles at -O0, its busiest function uses $peak local registers (limit 180)" || fail "$f uses $peak local registers at -O0"
done
if grep -n "Lighting" "$RSD/RarePullCamera155.lua";then fail "the camera module names Lighting";else echo "ok: the camera never touches Lighting (its depth of field lives on the Camera)";fi
if git -C "$REPO" diff "$BASE" -- "$RSD/RarePullCinematic.lua" "$RSD/RarePullCard.lua" | grep -E "^\+" | grep -v "^+++" | grep -n "Lighting";then fail "an R155 line names Lighting";else echo "ok: no R155 line in the director or the card names Lighting";fi
python3 - "$RSD/RarePullCamera155.lua" "$RSD/RarePullCinematic.lua" <<'PY' || RC=1
import re,sys
def code(s):
    s=re.sub(r"--\[(=*)\[.*?\]\1\]",'',s,flags=re.S)
    s=re.sub(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"","''",s)
    return '\n'.join(l.split('--',1)[0] for l in s.split('\n'))
cam=open(sys.argv[1],encoding='utf-8').read()
i=cam.index('-- Per frame (no table, no closure)');j=cam.rindex('return C')
per=code(cam[i:j])
bad=[l for l in per.split('\n') if '{' in l]
fns=[l for l in per.split('\n') if re.search(r'\bfunction\b',l) and not re.match(r'^(local function \w+\(|function C\.Shot\()',l)]
assert not bad,'FAIL: a table constructor in the camera\'s per-frame code: %s'%bad
assert not fns,'FAIL: a closure in the camera\'s per-frame code: %s'%fns
d=open(sys.argv[2],encoding='utf-8').read()
a=d.index('local function sceneCamera(');b=d.index('\nend',a)
sc=code(d[a:b])
assert '{' not in sc and sc.count('function')==1,'FAIL: the director\'s sceneCamera makes a table or a closure'
print('ok: no table and no closure per frame (the camera\'s Per frame section: %d lines; the director\'s sceneCamera)'%len(per.split('\n')))
PY
if grep -rniE "cla[u]de[ -]?(op[u]s|sonn[e]t|haik[u]|[0-9])|cla[u]de-[a-z]+-[0-9]|(op[u]s|sonn[e]t|haik[u])[ -]?[0-9]|gp[t]-?[0-9]" "$P/R155" 2>/dev/null | grep -v "^Binary";then fail "a model name in the R155 files";else echo "ok: no model names in the R155 files";fi
echo "== 1. test_rare_camera155"
INV=$P/inventory_R113/tests
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$P/R151/tests/rare_env.luau" "$P/R152/tests/rare152_env.luau" "$P/R152/tests/sound_levels.luau" "$HERE/test_rare_camera155.luau" "$OUT/cl/"
python3 "$P/R151/tests/mkbundle_rare.py" "$OUT/cl" all-client >/dev/null
if (cd "$OUT/cl" && timeout 3600 /opt/luau/luau test_rare_camera155.luau > test_rare_camera155.log 2>&1);then grep -v '^WARN' "$OUT/cl/test_rare_camera155.log" | tail -2
else grep -v '^WARN' "$OUT/cl/test_rare_camera155.log" | tail -40;fail "test_rare_camera155";fi
if [ "$MODE" != "only" ];then
 echo "== 2. against the R154 release ($BASE), byte for byte: R152's seed-opening fingerprints, the stage camera, its depth of field and the SKIP button allowed"
 if PERF_BASE=$BASE ONLY=seed JOBS=${JOBS:-2} PERF_EXTRA="$P/R153/tests/perf153_opts.luau $HERE/perf155_opts.luau" sh "$P/R152/tests/run_perf152.sh" "$OUT/r154" "$OUT/no_place.rbxl" > "$OUT/r154.log" 2>&1;then
  grep -E "^seed |^ok:|^\(base" "$OUT/r154.log";echo "ok: every Common..Mythic reveal, every in-place / result card (but its SKIP button), the onlookers and the world before / after each stage are identical to R154"
 else grep -vE "^ +allowed|PERF |^[a-z_0-9]+ +(seed|kb|hub)\." "$OUT/r154.log" | tail -40;fail "the fingerprints against R154 differ beyond the stage camera";fi
fi
[ "$RC" = 0 ] && echo "R155 camera suites passed"
exit $RC
