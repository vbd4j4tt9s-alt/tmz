#!/bin/sh
# Usage: sh run_fling_swoosh.sh [scratch dir]   (needs /opt/luau/luau and python3)
# R153 (owner: "102531686500130 this fast swoosh sound effect also plays when players get hit and fly through the air"): the fast swoosh when a
# keeper launches a player (FlingSwoosh153 module + FlingSwoosh153.client.lua, its own listener on the KeeperHit packet), on the Roblox mock with the
# REAL modules / scripts of this checkout (KeeperHitEffects runs beside it: its impact sound must come first).
#  0. static   - both new scripts compile and are in src/MANIFEST.tsv, the client script starts with the R152 load guard, the frozen gameplay files
#                (chase / ragdoll / knockback / keeper combat services and the two hit / ragdoll client scripts) are byte-identical to the R152 release
#                (FLING_BASE, default e36b71b; the load guard line and the release number in Config.Version are ignored), Config.Version is unchanged
#  1. test_fling_swoosh.luau - once, the id, the Effects group, the volume cap, 2D for the flung player, 3D on the flung body for the others (never
#                both), after the impact, the swell on the fastest moment, the lead-in (SoundTiming / Start), late packets, a cold file, NOT on a jump /
#                the trampoline / a track-hole fall / a bat hit / lightning / a malformed packet, the voice cap, the cooldown, the Effects slider
#  2. mutations - each of these breaks the module one way and the test must fail: the Cause gate, the Stage gate, the 2D / 3D split, the voice cap, the
#                group, the volume cap, the gap after the impact, the Effects-0 gate, the cooldown
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
BASE=${FLING_BASE:-e36b71b}
S=$REPO/src;SP=$S/StarterPlayer/StarterPlayerScripts;P=$REPO/docs/proposals;T=$REPO/tools/tests
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
M=$S/ReplicatedStorage/FlingSwoosh153.lua;C=$SP/FlingSwoosh153.client.lua
/opt/luau/luau-compile --binary "$M" >/dev/null && /opt/luau/luau-compile --binary "$C" >/dev/null && echo "ok: luau-compile clean" || fail "a new script does not compile"
grep -q "	ReplicatedStorage/FlingSwoosh153	" "$S/MANIFEST.tsv" && grep -q "	StarterPlayer/StarterPlayerScripts/FlingSwoosh153	" "$S/MANIFEST.tsv" && echo "ok: both scripts are in src/MANIFEST.tsv" || fail "a new script is not in src/MANIFEST.tsv"
head -1 "$C" | grep -q "R152: start once the whole game has arrived" && [ "$(grep -c "R152: start once the whole game has arrived" "$C")" = 1 ] && echo "ok: the client script starts with the load guard (once)" || fail "the load guard is not line 1 of FlingSwoosh153.client.lua"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|gp[t]-?[0-9]" "$M" "$C" "$HERE" 2>/dev/null | grep -v "^$HERE/run_fling_swoosh.sh";then fail "a model name in the R153 swoosh files";else echo "ok: no model names in the swoosh files";fi
grep -q "KeeperHit" "$C" && ! grep -q "OnServerEvent\|FireServer\|InvokeServer" "$C" "$M" && echo "ok: client only: it listens to KeeperHit and calls nothing on the server" || fail "the swoosh must be client only"
# the packet's shape is what the swoosh trusts: every KeeperHit packet the server sends is either a keeper's (carries Stage, no Cause) or has a Cause
# (Bat today); a keeper packet must carry Stage. (Holes / lightning never send one; the trampoline may send its own with a Cause.)
python3 - "$S/ServerScriptService" <<'EOF' || fail "a KeeperHit packet on the server is neither a keeper's (Stage) nor marked with a Cause"
import os, re, sys
keeper = other = 0
for d, _, fs in os.walk(sys.argv[1]):
    for f in fs:
        if not f.endswith('.lua'): continue
        s = open(os.path.join(d, f), encoding='utf-8').read()
        for m in re.finditer(r'HitRemote:FireAllClients\((.*?)\}\)', s, re.S):
            body = m.group(1)
            if 'Cause=' in body: other += 1
            elif 'Stage=' in body: keeper += 1
            else: print('KeeperHit packet with neither Cause nor Stage in', f); sys.exit(1)
if keeper < 1: print('no keeper packet (Stage, no Cause) found'); sys.exit(1)
print('ok: the server sends %d keeper packet(s) (Stage, no Cause) and %d with a Cause (bat, others): the swoosh gate (Stage and no Cause) fits' % (keeper, other))
EOF
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 FROZEN="src/ServerScriptService/ChestChaseServer/ChaseService.lua src/ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua src/ServerScriptService/ChestChaseServer/RagdollService.lua src/ServerScriptService/ChestChaseServer/Config.lua src/ReplicatedStorage/KeeperCombat.lua src/ReplicatedStorage/KnockbackConfig.lua src/ReplicatedStorage/KeeperAudio.lua src/ReplicatedStorage/KeeperFx.lua src/ReplicatedStorage/KeeperSignatureStrike.lua src/ReplicatedStorage/SoundTiming.lua src/ReplicatedStorage/LocalSfx.lua src/ReplicatedStorage/AudioMixer.lua src/StarterPlayer/StarterPlayerScripts/KeeperHitEffects.client.lua src/StarterPlayer/StarterPlayerScripts/RagdollClient.client.lua"
 if sh "$T/r152_real_diff.sh" "$REPO" "$BASE" $FROZEN >/dev/null;then echo "ok: the chase / ragdoll / knockback / keeper services, the hit effects, the ragdoll client and the shared sound modules are byte-identical to $BASE"
 else fail "a frozen file changed against $BASE:";sh "$T/r152_real_diff.sh" "$REPO" "$BASE" $FROZEN || true;fi
 git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/Config.lua" | grep 'Config.Version' | sed "s/Config.Version='V150 R15[0-9a-z]*'/Config.Version='V150 R15x'/" > "$OUT/version_base.txt"
 grep 'Config.Version' "$S/ServerScriptService/ChestChaseServer/Config.lua" | sed "s/Config.Version='V150 R15[0-9a-z]*'/Config.Version='V150 R15x'/" > "$OUT/version_now.txt"
 cmp -s "$OUT/version_base.txt" "$OUT/version_now.txt" && echo "ok: Config.Version unchanged apart from the release number" || fail "Config.Version changed"
else echo "skip: $BASE is not in this checkout (frozen-file and Config.Version checks not run)";fi
# -- the world --------------------------------------------------------------------------------------------------------------------------------------
INV=$P/inventory_R113/tests
bundle(){ # $1 = dir, $2 = FlingSwoosh153 module source
 python3 "$P/R150/tests/mkbundle_sfx.py" "$1" KeeperHitEffects=StarterPlayer/StarterPlayerScripts/KeeperHitEffects.client.lua FlingSwoosh153="$2" FlingSwoosh153Client="$C" >/dev/null
}
run(){ # $1 = dir
 (cd "$1" && timeout 300 /opt/luau/luau test_fling_swoosh.luau > test.log 2>&1)
}
prepare(){ mkdir -p "$1";cp "$T/roblox.luau" "$INV/world.luau" "$P/R150/tests/sfx_env.luau" "$HERE/test_fling_swoosh.luau" "$1/";}
# (the module and the client script share a name: a bundle keeps the MODULE under FlingSwoosh153 and the client script under FlingSwoosh153Client)
echo "== 1. test_fling_swoosh"
D=$OUT/now;prepare "$D";bundle "$D" "$M"
run "$D" || { grep -v '^WARN' "$D/test.log" | tail -40;fail "test_fling_swoosh";exit 1; }
grep -v '^WARN' "$D/test.log" | tail -3
echo "== 2. mutations (each break must make the test fail)"
mutate(){ # $1 name, $2 sed expression
 d=$OUT/mut_$1;prepare "$d";sed "$2" "$M" > "$d/FlingSwoosh153.lua"
 if cmp -s "$d/FlingSwoosh153.lua" "$M";then fail "bad mutation $1: the sed changed nothing";return;fi
 bundle "$d" "$d/FlingSwoosh153.lua"
  if run "$d";then fail "MUTATION $1 SURVIVED (the test passed)";else echo "killed $1: $(grep -c '^FAIL' "$d/test.log") failing checks, e.g. $(grep -m1 '^FAIL' "$d/test.log" | cut -c1-110)";fi
}
mutate cause_gate "s/or hit.Cause~=nil or/or/"
mutate stage_gate "s/or type(hit.Stage)~='number'//"
mutate own_split "s/local own=player~=nil and hit.VictimUserId==player.UserId/local own=false/"
mutate voice_cap "s/if not room(own)then return nil end//"
mutate group "s/mixer.Route(sound,'Effects')/mixer.Route(sound,'Interface')/"
mutate volume_cap "s/sound.Volume=math.clamp(num('Volume'),0,M.MaxVolume)/sound.Volume=num('Volume')/"
mutate gap "s/^M.MinGap=.04 /M.MinGap=0 /"
mutate effects_gate "s/if mixer.Get('Effects')<=0 then return nil end//"
mutate cooldown "s/if seen and now-seen<M.Cooldown then return nil end//"
mutate range "s/or(camera.CFrame.Position-hit.Position).Magnitude>M.MaxStuds then return nil end/then return nil end/"
mutate on_body "s/if root then parent=root/if false then parent=root/"
[ $RC = 0 ] && echo "R153 fling swoosh: all checks passed" || echo "R153 fling swoosh: FAILED"
exit $RC
