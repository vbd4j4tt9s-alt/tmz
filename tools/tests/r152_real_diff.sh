#!/bin/sh
# R152: "did this file really change since <base>?" for the byte-identical checks of older suites. Ignored: the R152 load guard every client
# script now starts with (and Hotbar's one Backpack line before it), and the release number inside Config.Version ('V150 R15x...'), which
# every release bumps, and (R153) ChaseService's one line that stamps KeeperHome on a keeper (the spawn point the SPEED NEEDED sign is pinned to;
# marked by its comment, nothing in the chase reads it), and (R153, architecture review) the owner test hooks that moved off the boot path: ChaseService's Start override that started
# the owner commands (now started by the main script inside a pcall) and Config.GetPlayerWalkSpeed's OwnerTestState82 lookup (now inside a pcall), and (R157b fix) AudioMixer's
# require of SettingsConfig with WaitForChild (the title can load the audio modules before SettingsConfig has replicated). Anything else counts.
# Usage: sh r152_real_diff.sh <repo> <base> <path>...  -> prints each path that differs beyond those; exit 1 when one does.
REPO=$1;BASE=$2;shift 2
exec python3 - "$REPO" "$BASE" "$@" <<'EOF'
import os, re, subprocess, sys
repo, base, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
skip = ("R152: start once the whole game has arrived", "R152: hide Roblox's own backpack before waiting", "R153: the spawn point the SPEED NEEDED sign is pinned to",
        "R153 (architecture review): the owner / test commands no longer start from here", "and with it the whole server). ChestChaseServerMain starts them",
        "OwnerTestState82).GetSpeed", "ownerTestSpeed", "R153: a broken owner test module", "return temporary end")
def norm(text):
    text = re.sub(r"local startV142=ChaseService\.Start\nfunction ChaseService:Start\(\.\.\.\)\n startV142\(self,\.\.\.\)\n require\(script\.Parent:WaitForChild\('StudioTestCommands'\)\)\.Start\([^\n]*\)\nend\n", "", text)
    lines = [l for l in text.split('\n') if not any(s in l for s in skip)]
    out = '\n'.join(lines)
    # (R157b fix) AudioMixer waits for SettingsConfig: the one require, and the comment after it, are put back to the old text; the rest of that line still counts
    out = out.replace("require(script.Parent:WaitForChild('SettingsConfig'))", "require(script.Parent.SettingsConfig)")
    out = re.sub(r" -- R157b fix: WaitForChild \(this module can be required before SettingsConfig has replicated[^\n]*", "", out)
    return re.sub(r"Config\.Version='V150 R15[0-9a-z]*'", "Config.Version='V150 R15x'", out)
rc = 0
for p in paths:
    rel = os.path.relpath(os.path.join(repo, p), repo) if os.path.isabs(p) else p
    try: old = subprocess.run(['git', '-C', repo, 'show', f'{base}:{rel}'], capture_output=True, check=True).stdout.decode('utf-8', 'replace')
    except subprocess.CalledProcessError: old = None
    path = os.path.join(repo, rel)
    new = open(path, encoding='utf-8', errors='replace').read() if os.path.exists(path) else None
    if old is None or new is None or norm(old) != norm(new):
        print(p); rc = 1
sys.exit(rc)
EOF
