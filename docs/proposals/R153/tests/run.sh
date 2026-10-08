#!/bin/sh
# Usage: sh run.sh [scratch dir]. R153 (owner: "make it so that players can also roll and open packs whilst on the treadmill") on the Roblox mock (/opt/luau/luau) with the REAL
# server code of this checkout (R151's pack harness, the real PlayerDataService, ChestService hold / opening, BaseService:_updateTrainingPlayer, TreadmillBonusService, ChaseService):
#  static                       nothing in the pack hold / opening, in OpenSeedPack, in the bonus roll or in the clients' roll / hotbar code reads the treadmill lock
#                               (BaseService.TrainingSessions / TreadmillTraining); training is stopped by a chase only: BaseService:_trainingBusy -> the chase-only checker (ChestChaseServerMain) (a pack reveal
#                               used to count: ChaseService:IsPlayerBusy includes ChestService:IsOpening, so the fifth click of a pack ended the treadmill session)
#  test_treadmill_open153.luau  a pack is held, opened (five clicks) and revealed on a treadmill and the training goes on (same session, anchored, same gain per tick); the bonus
#                               roll works on the treadmill; the other blocks (carrying a stolen pack, a chase, queued, ragdolled, flung, PlatformStand, another reveal, dead) still refuse
# The bonus UI (button phases, the Secret tease, the pack picture, no head pill) is docs/proposals/R150/tests/run_bonus_ui.sh.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
T=$REPO/tools/tests;P=$REPO/docs/proposals;S=$REPO/src;SS=$S/ServerScriptService/ChestChaseServer;SP=$S/StarterPlayer/StarterPlayerScripts;INV=$P/inventory_R113/tests;R151=$P/R151/tests
echo "== static: the treadmill is not what blocks packs or rolls"
python3 - "$SS" "$SP" "$S" <<'EOF'
import re, sys
ss, sp, s = sys.argv[1:4]
bad = []
def body(path, start, stop=r"\n(?:local )?function |\nreturn "):
    text = open(path, encoding='utf-8').read()
    m = re.search(start, text)
    if not m:
        bad.append('missing: %s in %s' % (start, path)); return ''
    rest = text[m.end():]
    n = re.search(stop, rest)
    return text[m.start():m.end() + (n.start() if n else len(rest))]
chest = ss + '/ChestService.lua'
for name, start in (('ChestService:_canOpenPack', r"function ChestService:_canOpenPack"), ('settleHold', r"local function settleHold"), ('ChestService:_holdPack', r"function ChestService:_holdPack"),
                    ('ChestService:_activatePack', r"function ChestService:_activatePack"), ('ChestService:IsOpening', r"function ChestService:IsOpening")):
    t = body(chest, start)
    if 'Training' in t: bad.append(name + ' reads the treadmill lock')
t = body(ss + '/PlayerDataService.lua', r"function PlayerDataService:OpenSeedPack")
if 'Training' in t: bad.append('PlayerDataService:OpenSeedPack reads the treadmill lock')
t = body(ss + '/TreadmillBonusService.lua', r"function S:Roll", r"\nreturn S")
if 'Training' in t or 'TrainingSessions' in t: bad.append('TreadmillBonusService:Roll reads the treadmill lock')
t = body(sp + '/TreadmillBonusClient.client.lua', r"local function requestRoll", r"\nconnect\(button\.Activated")
if 'training()' in t or 'TreadmillTraining' in t: bad.append('TreadmillBonusClient.requestRoll reads the treadmill')
for f in ('Hotbar.client.lua', 'SeedPackClient.client.lua', 'PackOpeningFeedback.client.lua'):
    if 'TreadmillTraining' in open(sp + '/' + f, encoding='utf-8').read(): bad.append(f + ' reads TreadmillTraining')
main = open(ss + '/../ChestChaseServerMain.server.lua', encoding='utf-8').read()
if not re.search(r"baseService:SetTrainingBusyChecker\(function\(player\)\s*if type\(chaseService\.Runs\) == \"table\" and type\(chaseService\.Starting\) == \"table\" then return chaseService\.Runs\[player\] ~= nil or chaseService\.Starting\[player\] == true end", main): bad.append('ChestChaseServerMain does not give the treadmill the chase-only checker (Runs / Starting)')
t = body(ss + '/ConcurrentKeeperService.lua', r"function Service:IsPlayerBusy", r"\n    function Service:")
if 'self.Runs[player] ~= nil' not in t or 'self.Starting[player] == true' not in t or 'IsOpening' not in t: bad.append('ConcurrentKeeperService:IsPlayerBusy changed: the treadmill checker in ChestChaseServerMain mirrors its Runs / Starting')
t = body(ss + '/BaseService.lua', r"function BaseService:_updateTrainingPlayer")
if 'BusyChecker(' in t.replace('_trainingBusy(', '') or '_trainingBusy(' not in t: bad.append('BaseService:_updateTrainingPlayer must ask _trainingBusy (the chase-only checker), not BusyChecker')
t = body(ss + '/BaseService.lua', r"function BaseService:_trainingBusy")
if 'TrainingBusyChecker' not in t: bad.append('BaseService:_trainingBusy lost its checker')
if bad:
    print('FAIL: ' + '; '.join(bad)); sys.exit(1)
print('ok: the pack hold / opening / OpenSeedPack, the bonus roll and the hotbar / roll clients never look at the treadmill; BaseService stops training only for a chase (a reveal no longer does)')
EOF
echo "== test_treadmill_open153 (the real server code)"
SRV=$OUT/srv;mkdir -p "$SRV"
cp "$T/roblox.luau" "$INV/world.luau" "$INV/fixtures.luau" "$R151/pack_world.luau" "$R151/pack_templates.luau" "$R151/pouch_mock.luau" "$R151/pack_shape_samples.luau" "$HERE/test_treadmill_open153.luau" "$SRV/"
python3 "$R151/mkbundle_packs.py" "$SRV" "$S" --server >/dev/null
cd "$SRV"
timeout 900 /opt/luau/luau test_treadmill_open153.luau > test_treadmill_open153.log 2>&1 || { grep -v '^WARN' test_treadmill_open153.log | tail -40;exit 1; }
grep -v '^WARN' test_treadmill_open153.log | tail -1
echo "R153 treadmill suites passed"
