#!/bin/sh
# Usage: sh tools/tests/check_compile_O0.sh <repo root>
# Every script under src/ must compile the way Roblox compiles it: without the constant folding of -O1, which drops constant locals and so
# hides how many registers a function really needs. Luau refuses a function with more than 200 live locals ("Out of local registers when
# trying to allocate X: exceeded limit 200"); R153's KeyboardTrack client passed every suite at -O1 and was dead in Studio for exactly that.
#  1. every src/**/*.lua compiles with luau-compile -O0 --binary (any CompileError / SyntaxError fails);
#  2. every function's peak register use by its locals (luau-compile -O0 -g2 --text: the highest register a named local sits in, + 1; this is
#     at least the compiler's live-locals count, numeric / generic for loops add their hidden registers) must stay at or under LIMIT (180).
#     Above it FAILS, not a warning: a function at 181+ is a few locals from a script that does not run at all, and a warning in a
#     suite log is read too late. Functions above WARN (160) are listed as a heads-up only.
REPO=${1:?repo root}
LC=${LUAU_COMPILE:-/opt/luau/luau-compile}
LIMIT=${O0_LOCALS_LIMIT:-180}
WARN=${O0_LOCALS_WARN:-160}
[ -x "$LC" ] || { echo "FAIL: $LC not found";exit 1; }
[ -d "$REPO/src" ] || { echo "FAIL: $REPO/src not found";exit 1; }
n=0;bad=0;over=0;near=0;top=0;topAt=
for f in $(find "$REPO/src" -name '*.lua' | sort);do
 n=$((n+1));rel=${f#"$REPO"/}
 err=$("$LC" -O0 --binary "$f" 2>&1 >/dev/null);rc=$?
 if [ $rc -ne 0 ] || echo "$err" | grep -q 'Error'; then
  echo "FAIL: $rel does not compile at -O0: $(echo "$err" | head -1)";bad=$((bad+1));continue
 fi
 # one line per function: <peak> <first source line> <name>
 peaks=$("$LC" -O0 -g2 --text "$f" 2>/dev/null | awk '
  function flush(){ if(fn!="") print peak, (line==""?"?":line), fn }
  /^Function [0-9]+ \(/ { flush(); fn=$0; sub(/^Function [0-9]+ \(/,"",fn); sub(/\):$/,"",fn); peak=0; line=""; next }
  /^local [0-9]+ \(.*\): reg [0-9]+,/ { s=$0; sub(/.*\): reg /,"",s); sub(/,.*/,"",s); if(s+1>peak) peak=s+1; next }
  line=="" && /^ +[0-9]+: / { l=$1; sub(/:$/,"",l); line=l }
  END { flush() }')
 fmax=$(echo "$peaks" | awk 'BEGIN{m=0} $1+0>m{m=$1+0} END{print m}')
 if [ "$fmax" -gt "$top" ];then top=$fmax;topAt=$rel;fi
 if [ "$fmax" -gt "$WARN" ];then
  echo "$peaks" | awk -v file="$rel" -v lim="$LIMIT" -v warn="$WARN" '$1+0>warn{ name=$3; for(i=4;i<=NF;i++) name=name" "$i; printf "%s: %s:%s function %s uses %d local registers at -O0 (limit %d, hard limit 200)\n", ($1+0>lim?"FAIL":"note"), file, $2, (name=="??"?"<main chunk or anonymous>":name), $1, lim }'
  o=$(echo "$peaks" | awk -v lim="$LIMIT" '$1+0>lim{c++} END{print c+0}');w=$(echo "$peaks" | awk -v lim="$LIMIT" -v warn="$WARN" '$1+0>warn && $1+0<=lim{c++} END{print c+0}')
  over=$((over+o));near=$((near+w))
 fi
done
echo "checked $n scripts at -O0: $bad do not compile, $over functions over $LIMIT local registers, $near between $WARN and $LIMIT; the busiest function uses $top ($topAt)"
[ $n -gt 0 ] || { echo "FAIL: no scripts found under $REPO/src";exit 1; }
[ $bad -eq 0 ] && [ $over -eq 0 ] || { echo "FAIL: -O0 compile check";exit 1; }
echo "ok: all checks passed - every script compiles at -O0 and no function needs more than $LIMIT local registers"
