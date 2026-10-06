#!/bin/sh
# R152: "did this file really change since <base>?" for the byte-identical checks of older suites. Every client script now starts with the
# R152 load guard (and Hotbar with one Backpack line before it); those integration lines are ignored, anything else counts.
# Usage: sh r152_real_diff.sh <repo> <base> <path>...  -> prints each path that differs beyond those lines; exit 1 when one does.
REPO=$1;BASE=$2;shift 2;RC=0
for f in "$@";do
 if git -C "$REPO" diff -U0 "$BASE" -- "$f" | grep '^[-+]' | grep -v '^\(---\|+++\) ' | grep -v 'R152: start once the whole game has arrived' | grep -v "R152: hide Roblox's own backpack before waiting" | grep -q .;then echo "$f";RC=1;fi
done
exit $RC
