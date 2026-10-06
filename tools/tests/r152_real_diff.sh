#!/bin/sh
# R152: "did this file really change since <base>?" for the byte-identical checks of older suites. Ignored: the R152 load guard every client
# script now starts with (and Hotbar's one Backpack line before it), and the release number inside Config.Version ('V150 R15x...'), which
# every release bumps. Anything else counts.
# Usage: sh r152_real_diff.sh <repo> <base> <path>...  -> prints each path that differs beyond those; exit 1 when one does.
REPO=$1;BASE=$2;shift 2
exec python3 - "$REPO" "$BASE" "$@" <<'EOF'
import os, re, subprocess, sys
repo, base, paths = sys.argv[1], sys.argv[2], sys.argv[3:]
skip = ("R152: start once the whole game has arrived", "R152: hide Roblox's own backpack before waiting")
def norm(text):
    lines = [l for l in text.split('\n') if not any(s in l for s in skip)]
    return re.sub(r"Config\.Version='V150 R15[0-9a-z]*'", "Config.Version='V150 R15x'", '\n'.join(lines))
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
