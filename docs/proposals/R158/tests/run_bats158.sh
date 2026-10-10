#!/bin/sh
# Usage: sh run_bats158.sh [scratch dir] [swings per sim cell, default 400]   (needs /opt/luau/luau, python3, git)
# R158 bats, BUILT (docs/proposals/R158/bats, owner-approved; owner's choices: no camera shake for the hitter, no "SMACK!" word, a white trail), on the
# Roblox mock (/opt/luau/luau) with the REAL code of this checkout. "Today" = the base commit BATS_BASE (default e9c0900, V150 R157b + notes), read with git.
#  0. static        the changed scripts compile at -O0 and are in src/MANIFEST.tsv, the client scripts' line 1 is the R152 load guard, no model names; what a
#                   hit does is untouched (ConcurrentKeeperService's HitByBat, the ragdoll, knockback, MovementGuard, the pyramid, the chase, Config, the
#                   Hotbar and SeedPackClient are byte-identical to today); the hit time (Windup .30) and the cooldown (1.0) as before; SecurityGate BatHit
#                   2/s burst 3; no "SMACK" and no camera write in the new client code; nothing made per frame in the per-frame functions; registered in
#                   tools/tests/run_all_suites.sh
#  1. test_bat_anticheat158.luau  BatHitbox (the sector, paths not points), BatLagComp.Validate (the prototype's 32 cases + teleports + the slack
#                   through a wall + the bonus cap), BatService:Claim (no swing, wrong swing, one claim per swing, claim spam, bad victims, NaN, expired,
#                   tool put away, a teleport mid-strike, faked starts, the cooldown, walls, who cannot be hit), the refusal counters, the cost
#  2. sim_bat_hits158.luau  the hit-rate mock on the REAL code, honest swings at 24 / 141 / 285 / 500 / 575 studs/s and swinger pings 50 / 120 / 250 ms
#                   in 5 scenarios: every NEW cell must count >= 90 % of the hits the swinger saw; today's code (git) for comparison
#  3. test_bat_pose158.luau  the swing: contact at .30 = Windup, .85 s, the keys, = the approved preview, upper body only, R6 60 % twist / no lean, smooth
#  4. test_bat_client158.luau + test_hit_effects158.luau  the click (no wait), the sweep and the claim, your hit at once (slap, pooled star, sparks,
#                   hit-stop), NO hitter shake (the victim / bystanders keep theirs), the white trail on the strike only, Fast Mode, nothing made per frame,
#                   upper body only R15 / R6, the carrier (right arm only, order of the two scripts does not matter), no SMACK word; the star pool, sparks
#  5. test_bat_pyramid158  R156's pyramid server world (its own set-up), then a REAL bat claim on the secret-pack carrier: back in the pyramid ('Bat')
#  6. mutations     broken copies (no rewind cap, no path check, no once-per-swing, no wall ray, no BatHit limit, an uncapped bonus, teleports swept,
#                   points not paths, no history, no HitByBat, the swing waits for the server, a hitter shake, the own hit not skipped, a SMACK word, no
#                   star pool, a coloured trail, the carry pose takes the bat's arm, contact moved, a leg in the swing, no hit-stop): each must fail a test
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};N=${2:-400};mkdir -p "$OUT"
BASE=${BATS_BASE:-e9c0900}
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;SP=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage
RC=0;fail(){ echo "FAIL: $1";RC=1; }
echo "== 0. static"
for f in "$RSD/BatConfig.lua" "$RSD/BatHitbox.lua" "$RSD/BatSwingPose.lua" "$RSD/HitBurstFx.lua" "$RSD/SeedCarryPose.lua" "$SS/BatLagComp.lua" "$SS/BatService.lua" "$SS/SecurityGate.lua" "$SP/BatClient.client.lua" "$SP/KeeperHitEffects.client.lua";do
 /opt/luau/luau-compile -O0 --binary "$f" >/dev/null 2>&1 || fail "$f does not compile at -O0"
done
echo "ok: the changed scripts compile at -O0"
grep -q "	ReplicatedStorage/HitBurstFx	ReplicatedStorage/HitBurstFx.lua" "$S/MANIFEST.tsv" && grep -q "	ServerScriptService/ChestChaseServer/BatLagComp	ServerScriptService/ChestChaseServer/BatLagComp.lua" "$S/MANIFEST.tsv" \
 && echo "ok: the new modules (HitBurstFx, BatLagComp) are in src/MANIFEST.tsv" || fail "a new module is not in src/MANIFEST.tsv"
for f in BatClient KeeperHitEffects;do
 head -1 "$SP/$f.client.lua" | grep -q "R152: start once the whole game has arrived" && [ "$(grep -c "R152: start once the whole game has arrived" "$SP/$f.client.lua")" = 1 ] || fail "line 1 of $f.client.lua is not the R152 load guard"
done
echo "ok: BatClient and KeeperHitEffects start with the R152 load guard (line 1, once)"
if grep -rniE "cla[u]de|op[u]s|sonn[e]t|haik[u]|gp[t]-?[0-9]" "$RSD/BatConfig.lua" "$RSD/BatHitbox.lua" "$RSD/BatSwingPose.lua" "$RSD/HitBurstFx.lua" "$SS/BatLagComp.lua" "$SS/BatService.lua" "$SP/BatClient.client.lua" "$HERE"/*bat* "$HERE"/*hit* "$P/R158/bats"/*.md >/dev/null 2>&1;then fail "a model name in the R158 bat files";else echo "ok: no model names in the bat files";fi
if git -C "$REPO" cat-file -e "$BASE^{commit}" 2>/dev/null;then
 FROZEN="src/ServerScriptService/ChestChaseServer/ConcurrentKeeperService.lua src/ServerScriptService/ChestChaseServer/RagdollService.lua src/ReplicatedStorage/KnockbackConfig.lua src/ServerScriptService/ChestChaseServer/MovementGuard.lua src/ServerScriptService/ChestChaseServer/SecretPyramid156.lua src/ReplicatedStorage/PyramidRules156.lua src/ServerScriptService/ChestChaseServer/ChaseService.lua src/ServerScriptService/ChestChaseServer/Config.lua src/ServerScriptService/ChestChaseServer/BatArt.lua src/StarterPlayer/StarterPlayerScripts/Hotbar.client.lua src/StarterPlayer/StarterPlayerScripts/SeedPackClient.client.lua src/StarterPlayer/StarterPlayerScripts/RagdollClient.client.lua src/StarterPlayer/StarterPlayerScripts/FlingSwoosh153.client.lua src/ReplicatedStorage/LocalSfx.lua"
 if git -C "$REPO" diff --quiet "$BASE" -- $FROZEN;then echo "ok: what a hit does is untouched: HitByBat (ConcurrentKeeperService), the ragdoll, knockback, MovementGuard, the pyramid, the chase, Config, BatArt, the Hotbar, SeedPackClient, the ragdoll / fling clients, LocalSfx are byte-identical to $BASE"
 else fail "a file that must not change changed against $BASE:";git -C "$REPO" diff --stat "$BASE" -- $FROZEN;fi
else echo "skip: $BASE is not in this checkout (the unchanged-files check and today's side of the sim need it)";fi
grep -q "Windup=.30,Recovery=.55,Cooldown=1.0," "$RSD/BatConfig.lua" && echo "ok: the hit time (Windup .30) and the cooldown (1.0 s) as before; the swing is .85 s" || fail "BatConfig Windup / Cooldown changed"
grep -q "BatHit={Rate=2,Burst=3}" "$SS/SecurityGate.lua" && echo "ok: SecurityGate BatHit = 2 a second, 3 at once" || fail "no SecurityGate BatHit policy"
if grep -niE "smack" "$SP/BatClient.client.lua" "$RSD/HitBurstFx.lua" "$SS/BatService.lua" "$SS/BatLagComp.lua" "$RSD/BatHitbox.lua" | grep -vE '^[^:]+:[0-9]+: *--';then fail "a SMACK word in the new bat code";else echo "ok: no SMACK word in the new bat code (the server's notices are unchanged)";fi
if grep -nE "CurrentCamera\.CFrame *=|camera\.CFrame *=|Camera\.CFrame *\*=" "$SP/BatClient.client.lua" "$RSD/HitBurstFx.lua";then fail "the new bat code writes the camera (the hitter must not shake)";else echo "ok: BatClient / HitBurstFx never write the camera (no hitter shake)";fi
python3 - "$SP/BatClient.client.lua" "$RSD/HitBurstFx.lua" "$SS/BatService.lua" "$SS/BatLagComp.lua" "$RSD/BatHitbox.lua" <<'EOF' || fail "something is made per frame"
import re, sys
# the functions that run every frame (client) / every server frame / per sample: no table constructor, no closure, no Instance.new
want = {sys.argv[1]: ['local function sweepFrame(', 'local function poseFrame(', 'local function hittable(', 'local function resetJoint(', 'preAnimation=Run.PreAnimation:Connect(function()', 'preSimulation=Run.PreSimulation:Connect(function()'],
        sys.argv[2]: ['function Fx.Step('], sys.argv[3]: ['function M:Step(', 'function M:_record('],
        sys.argv[4]: ['function L.Record(', 'function L.Sample(', 'function L.Velocity(', 'local function pointSegment(', 'local function piece(', 'function L.Validate('],
        sys.argv[5]: ['function B.InSector(', 'function B.Sweep(', 'function B.ClientFrame(']}
bad = 0
for path, heads in want.items():
    src = open(path, encoding='utf-8').read()
    for h in heads:
        i = src.find(h)
        if i < 0: print('missing', h, 'in', path); bad += 1; continue
        j = src.find('\nend', i + len(h))
        body = src[i + len(h):j]
        body = re.sub(r"'[^'\n]*'", "''", body)          # (strings may hold anything)
        body = re.sub(r'--[^\n]*', '', body)              # (comments too)
        for what, pat in (('a table', r'\{'), ('a closure', r'function\s*\('), ('an instance', r'Instance\.new')):
            if re.search(pat, body): print('per frame:', what, 'made in', h, 'of', path); bad += 1
print('ok: nothing is made per frame in %d per-frame functions (no table, no closure, no instance)' % sum(len(v) for v in want.values()) if not bad else 'FAIL')
sys.exit(1 if bad else 0)
EOF
sed -n 6p "$T/run_all_suites.sh" | grep -q "docs/proposals/R158/tests/run_bats158.sh docs/proposals/R156/tests/run_pyramid156.sh" && echo "ok: registered in tools/tests/run_all_suites.sh (before the pyramid suite)" || fail "not registered on line 6 of run_all_suites.sh"
# -- the worlds ----------------------------------------------------------------------------------------------------------------------------------------------
basefiles(){ # $1 dir: today's bat files from git
 git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatConfig.lua" > "$1/BatConfig_base.lua"
 git -C "$REPO" show "$BASE:src/ReplicatedStorage/BatHitbox.lua" > "$1/BatHitbox_base.lua"
 git -C "$REPO" show "$BASE:src/ServerScriptService/ChestChaseServer/BatService.lua" > "$1/BatService_base.lua"
}
srv(){ # $1 dir, then Name=path overrides; -> bat_bundle.luau (this checkout's server side + today's)
 d=$1;shift;mkdir -p "$d";basefiles "$d"
 cp "$T/roblox.luau" "$HERE/bat_world158.luau" "$HERE/test_bat_anticheat158.luau" "$HERE/sim_bat_hits158.luau" "$d/"
 python3 "$T/bundle.py" "$d/bat_bundle.luau" BatConfig="$RSD/BatConfig.lua" BatHitbox="$RSD/BatHitbox.lua" BatLagComp="$SS/BatLagComp.lua" BatService="$SS/BatService.lua" \
  SecurityGate="$SS/SecurityGate.lua" BatConfig_base="$d/BatConfig_base.lua" BatHitbox_base="$d/BatHitbox_base.lua" BatService_base="$d/BatService_base.lua" "$@" >/dev/null
}
pose(){ # $1 dir, then Name=path overrides
 d=$1;shift;mkdir -p "$d";cp "$HERE/test_bat_pose158.luau" "$d/"
 python3 "$T/bundle.py" "$d/pose_bundle.luau" BatConfig="$RSD/BatConfig.lua" BatSwingPose="$RSD/BatSwingPose.lua" BatSwingPose158="$P/R158/bats/preview/BatSwingPose158.luau" "$@" >/dev/null
}
cli(){ # $1 dir, then Name=path overrides (absolute)
 d=$1;shift;mkdir -p "$d"
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R150/tests/sfx_env.luau" "$HERE/test_bat_client158.luau" "$HERE/test_hit_effects158.luau" "$d/"
 python3 "$P/R150/tests/mkbundle_sfx.py" "$d" BatClient=StarterPlayer/StarterPlayerScripts/BatClient.client.lua KeeperHitEffects=StarterPlayer/StarterPlayerScripts/KeeperHitEffects.client.lua "$@" >/dev/null
}
pyr(){ # $1 dir, then Name=path overrides
 d=$1;shift;mkdir -p "$d"
 cp "$T/roblox.luau" "$P/inventory_R113/tests/world.luau" "$P/inventory_R113/tests/fixtures.luau" "$P/R151/tests/pack_world.luau" "$P/R151/tests/pack_templates.luau" "$P/R151/tests/pouch_mock.luau" "$d/"
 sed '/^-- 6\. Caught \/ lost: back in the pyramid/,$d' "$P/R156/tests/test_pyramid_server156.luau" > "$d/prelude.luau"
 grep -q "Ava" "$d/prelude.luau" && grep -q "local okTake,whyTake=take(A)" "$d/prelude.luau" || { echo "FAIL: R156's server test no longer has the set-up this test appends to";return 1; }
 cat "$d/prelude.luau" "$HERE/test_bat_pyramid158_tail.luau" > "$d/test_bat_pyramid158.luau"
 python3 "$P/R151/tests/mkbundle_packs.py" "$d" "$S" --server "$@" >/dev/null
}
run(){ # $1 dir, $2 test, $3 label, [$4 args]: 0 when it passes
 if (cd "$1" && timeout 900 /opt/luau/luau "$2" ${4:+-a $4} > "$2.log" 2>&1);then return 0;else return 1;fi
}
show(){ grep -v '^WARN' "$1" | grep -E '^FAIL|checks|failed|counted' | tail -${2:-3}; }
echo "== 1. test_bat_anticheat158"
srv "$OUT/srv"
if run "$OUT/srv" test_bat_anticheat158.luau;then show "$OUT/srv/test_bat_anticheat158.luau.log" 2;else fail "test_bat_anticheat158";grep -v '^WARN' "$OUT/srv/test_bat_anticheat158.luau.log" | tail -25;fi
echo "== 2. sim_bat_hits158 ($N swings per cell)"
if run "$OUT/srv" sim_bat_hits158.luau x "$N";then grep -v '^WARN' "$OUT/srv/sim_bat_hits158.luau.log";else fail "sim_bat_hits158";grep -v '^WARN' "$OUT/srv/sim_bat_hits158.luau.log" | tail -60;fi
echo "== 3. test_bat_pose158"
pose "$OUT/pose"
if run "$OUT/pose" test_bat_pose158.luau;then show "$OUT/pose/test_bat_pose158.luau.log" 1;else fail "test_bat_pose158";grep -v '^WARN' "$OUT/pose/test_bat_pose158.luau.log" | tail -20;fi
echo "== 4. test_bat_client158 + test_hit_effects158"
cli "$OUT/cli"
for t in test_bat_client158 test_hit_effects158;do
 if run "$OUT/cli" $t.luau;then show "$OUT/cli/$t.luau.log" 1;else fail "$t";grep -v '^WARN' "$OUT/cli/$t.luau.log" | tail -25;fi
done
echo "== 5. test_bat_pyramid158"
if pyr "$OUT/pyr" && run "$OUT/pyr" test_bat_pyramid158.luau;then show "$OUT/pyr/test_bat_pyramid158.luau.log" 1;else fail "test_bat_pyramid158";grep -v '^WARN' "$OUT/pyr/test_bat_pyramid158.luau.log" | tail -20;fi
[ $RC = 0 ] || { echo "R158 bats: FAILED (before the mutations)";exit 1; }
echo "== 6. mutations (each break must make a test fail)"
M=$OUT/mut;mkdir -p "$M"
mutate(){ # $1 name, $2 source file, $3 sed expression, $4 kind (srv / sim / pose / cli / fx / pyr), $5 module name in the bundle
 m=$M/$1.lua;sed "$3" "$2" > "$m"
 if cmp -s "$m" "$2";then fail "bad mutation $1: the sed changed nothing";return;fi
 d=$M/w_$1;rm -rf "$d"
 case $4 in
  srv) srv "$d" "$5=$m";t=test_bat_anticheat158.luau;a=;;
  sim) srv "$d" "$5=$m";t=sim_bat_hits158.luau;a=60;;
  pose) pose "$d" "$5=$m";t=test_bat_pose158.luau;a=;;
  cli) cli "$d" "$5=$m";t=test_bat_client158.luau;a=;;
  fx) cli "$d" "$5=$m";t=test_hit_effects158.luau;a=;;
  pyr) pyr "$d" "$5=$m";t=test_bat_pyramid158.luau;a=;;
 esac
 if run "$d" $t "" $a;then fail "MUTATION $1 SURVIVED ($t passed)"
 else echo "killed $1: $(grep -c '^FAIL' "$d/$t.log") failing checks, e.g. $(grep -m1 '^FAIL' "$d/$t.log" | cut -c1-110)";fi
 rm -rf "$d"
}
mutate no_rewind_cap "$SS/BatLagComp.lua" "s/local back=math.min(C.MaxRewind,/local back=math.min(1e9,/" srv BatLagComp
mutate no_path_check "$SS/BatLagComp.lua" "s/if best>C.OwnSlack then return false,'swinger not where it claims'end//" srv BatLagComp
mutate no_once_per_swing "$SS/BatService.lua" "s/local resolved=swing.Resolved;swing.Resolved=true/local resolved=false/" srv BatService
mutate no_wall_ray "$SS/BatService.lua" "s/ return workspace:Raycast(Vector3.new(ax,ay,az),Vector3.new(bx-ax,by-ay,bz-az),params)~=nil/ return false/" srv BatService
mutate no_claim_limit "$SS/SecurityGate.lua" "s/BatHit={Rate=2,Burst=3}/BatHit={Rate=200,Burst=300}/" srv SecurityGate
mutate uncapped_bonus "$SS/BatLagComp.lua" "s/math.min(C.MaxBonus,C.BonusPerSpeed/math.max(C.MaxBonus,C.BonusPerSpeed/" srv BatLagComp
mutate teleport_swept "$SS/BatLagComp.lua" "s/>C.JumpSpeed\*math.max(0,t-h.T\[p\])+10 then jump=true end/>1e12 then jump=true end/" srv BatLagComp
mutate points_not_paths "$RSD/BatHitbox.lua" "s/ for i=0,n do/ for i=n,n do/" srv BatHitbox
mutate no_eligibility "$SS/BatService.lua" "s/if not self:_eligible(player)or not character or not self.Chase.Ragdoll:CanHit(victim)then/if false then/" srv BatService
mutate no_history "$SS/BatService.lua" "s/   Lag.Record(h,server,p.X,p.Y,p.Z,lx,lz,true)//" sim BatService
mutate today_buffer "$RSD/BatConfig.lua" "s/Buffer=.10,MaxRewind=.30/Buffer=0,MaxRewind=0/" sim BatConfig
mutate no_hitbybat "$SS/BatService.lua" "s/if not self.Chase:HitByBat(player,victim,character)then/if true then/" pyr BatService
mutate waits_for_server "$SP/BatClient.client.lua" "s/^ begin(character,tool,handle,start)$//" cli BatClient
mutate hitter_shake "$SP/BatClient.client.lua" "s/^ Sfx.Play(C.SlapSoundId,at,C.SlapVolume,1,2);/ workspace.CurrentCamera.CFrame=workspace.CurrentCamera.CFrame*CFrame.new(0,.3,0);Sfx.Play(C.SlapSoundId,at,C.SlapVolume,1,2);/" cli BatClient
mutate own_hit_not_skipped "$SP/KeeperHitEffects.client.lua" "s/ if batHit and Burst.IsOwnHit(hit.VictimUserId)then return end.*//" cli KeeperHitEffects
mutate smack_word "$SP/BatClient.client.lua" "s/^ Burst.NoteOwnHit(other.UserId)$/ Burst.NoteOwnHit(other.UserId);local g=Instance.new('TextLabel');g.Text='SMACK!';g.Parent=workspace/" cli BatClient
mutate no_hit_stop "$SP/BatClient.client.lua" "s/^ if p and not p.StopUntil then p.StopAt=now-p.At;p.StopUntil=now+C.HitStop end$//" cli BatClient
mutate trail_colour "$RSD/BatConfig.lua" "s/TrailRGB={255,255,255}/TrailRGB={255,120,40}/" cli BatConfig
mutate trail_always "$SP/BatClient.client.lua" "s/local on=p.TrailAllowed and t>=C.TrailFrom and t<C.TrailTo/local on=p.TrailAllowed/" cli BatClient
mutate carry_takes_bat_arm "$RSD/SeedCarryPose.lua" "s/        if batArm and side==\"Right\" then continue end//" cli SeedCarryPose
mutate bat_takes_left_arm "$SP/BatClient.client.lua" "s/elseif carrying and entry.Left then written=nil/elseif false then written=nil/" cli BatClient
mutate no_star_pool "$RSD/HitBurstFx.lua" "s/if not pick and #stars<Fx.PoolSize then/if true then/" fx HitBurstFx
mutate sparks_in_fast_mode "$RSD/HitBurstFx.lua" "s/if typeof(position)~='Vector3'or Fx.Low()then return false end/if typeof(position)~='Vector3'then return false end/" fx HitBurstFx
mutate contact_moved "$RSD/BatSwingPose.lua" "s/P.Keys={A=.07,A2=.22,B=.26,C=.30,/P.Keys={A=.07,A2=.22,B=.26,C=.32,/" pose BatSwingPose
mutate leg_in_swing "$RSD/BatSwingPose.lua" "s/^ LeftElbow={a(20,0,0)/ RightHip={a(20,0,0)/" pose BatSwingPose
[ $RC = 0 ] && echo "R158 bats: all passed" || echo "R158 bats: FAILED"
exit $RC
