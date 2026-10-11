#!/bin/sh
# Usage: sh run_store158k.sh [scratch dir]      (TEETH=0 skips the mutants; BEFORE=<commit> also runs both tests on that commit's src, e.g. BEFORE=20d6e07, and needs them to FAIL)
# R158k (owner: "there are some bugs in the game where players can't purchase things in the store when their money is sufficient enough", then "if clicking on
# something and players don't have enough money, it just tells the player not enough cash"), on the Roblox mock with the real scripts of this checkout:
#  static             - the frozen files are byte-identical (R151 / R150 frozen.sha256; EconomyService's line is the R158k one); no function over 180 registers
#                       (check_compile_O0); line 1 of the edited client scripts is the load guard (Hotbar untouched); ProfileVersion 22; StoreMoney158k is in
#                       MANIFEST.tsv; no server script sends the old money words any more and every money refusal reads StoreMoney158k; no model names
#  test_store_client  - StoreMoney158k (equal money pays, exact at any size, "1e+20", not-an-amount = not known, the words, a balance known only once loaded);
#                       the HUD wallet / the market's Cash line never read more money than there is, a price never less (every real price); the REAL EconomyClient
#                       market: Buy buttons read the price and can always be pressed, a press the cash cannot pay = "Not enough cash!" (plain notice, Denied, nothing
#                       sent), equal cash buys, the server's money refusal = the same notice, an older reply's Cash never overrides the live stat, loading = the
#                       server decides, "Visit shop" / Equip keep their words, a double click sends one purchase, a press during a state refresh waits for it, every trail around its price; the REAL
#                       GamePassClient shop: the gem buttons and CONVERT the same way ("Not enough gems!" / "Not enough cash!"), a full Bag told first, Robux untouched
#  test_store_server  - the REAL PlayerDataService / PremiumProgress / EconomyService / GardenUpgradeService: SpendCash takes the money exactly when the screens'
#                       rule says it pays (every price, one under / equal / one over) and once; the market / gems / Cash to Gems / treadmill and fence pads: one short
#                       = the shared words and nothing charged, equal money buys, a replay is charged once, other refusals keep their own words; the pads show the
#                       same plain notice
#  prices (owner: "make sure store prices are always the same") - in both tests: a price is never rounded on a button or sign (short only when exact, else in
#                       full), every press sends the price its button shows and the server (market, PremiumService) refuses another one with "The price changed!
#                       Check the new price.", charges nothing and its reply puts its prices on the buttons; the same words on a narrow and a wide window
#  teeth              - mutants that put each old line back (the HUD's nearest rounding, the dead "Need $X" button, no press check, the status line, the reply's
#                       Cash, a press dropped while a refresh is on its way, the old server words, the pad without the notice, MAX 0, equal money refused...): each must make a test fail. Skip them with TEETH=0.
set -e
HERE=$(cd "$(dirname "$0")" && pwd);REPO=$(cd "$HERE/../../../.." && pwd)
OUT=${1:-$(mktemp -d)};mkdir -p "$OUT"
S=$REPO/src;C=$S/StarterPlayer/StarterPlayerScripts;RSD=$S/ReplicatedStorage;SRV=$S/ServerScriptService/ChestChaseServer;T=$REPO/tools/tests
TB=$REPO/docs/proposals/treadmill_bonus_R123/tests;INV=$REPO/docs/proposals/inventory_R113/tests
fail(){ echo "FAIL: $*";exit 1; }
echo "== static"
(cd "$REPO" && grep -v '^#' docs/proposals/R151/tests/frozen.sha256 | sha256sum -c --quiet) || fail "an R151 frozen file changed"
(cd "$REPO" && grep -v '^#' docs/proposals/R150/tests/frozen.sha256 | sha256sum -c --quiet) || fail "an R150 frozen file changed"
grep -q "^# R158k (on purpose): EconomyService.lua" "$REPO/docs/proposals/R151/tests/frozen.sha256" || fail "EconomyService's frozen line needs its R158k comment"
echo "ok: the frozen files are byte-identical (EconomyService's line is the R158k one)"
sh "$T/check_compile_O0.sh" "$REPO" > "$OUT/o0.log" 2>&1 || { tail -5 "$OUT/o0.log";fail "check_compile_O0"; }
tail -1 "$OUT/o0.log"
for f in EconomyClient GamePassClient;do head -1 "$C/$f.client.lua" | grep -q "^do local ok,loaded=pcall(function()return game:IsLoaded()end);if ok and loaded==false then game.Loaded:Wait()end end -- R152: start once the whole game has arrived" || fail "line 1 of $f is not the load guard";done
head -2 "$C/Hotbar.client.lua" | grep -q "R152" || fail "Hotbar lines 1-2 changed"
echo "ok: line 1 of the edited client scripts is the load guard (Hotbar untouched)"
grep -q "Config.ProfileVersion=22" "$SRV/Config.lua" || fail "ProfileVersion must stay 22"
grep -q "ReplicatedStorage/StoreMoney158k	ReplicatedStorage/StoreMoney158k.lua" "$S/MANIFEST.tsv" || fail "StoreMoney158k is not in MANIFEST.tsv"
if grep -rn "'NOT ENOUGH CASH'\|\"NOT ENOUGH CASH\"\|'NOT ENOUGH GEMS'\|\"NOT ENOUGH GEMS\"\|'Not enough Gems!'\|'Not enough cash!'" "$S/ServerScriptService";then fail "a server script still writes its own money words (use StoreMoney158k.Cash / .Gems)";fi
[ "$(grep -c "Money.Cash" "$SRV/PremiumProgress.lua")" = 2 ] && [ "$(grep -c "Money.Gems" "$SRV/PremiumProgress.lua")" = 4 ] || fail "PremiumProgress: Cash to Gems (2) and the gem purchases (4) must answer with StoreMoney158k's words"
for f in EconomyService PlayerDataService GardenFenceData PassGiftService GardenUpgradeService PremiumService;do grep -q "StoreMoney158k" "$SRV/$f.lua" || fail "$f must use StoreMoney158k";done
if grep -rn "The price changed" "$S/ServerScriptService";then fail "a server script writes its own price-changed words (use StoreMoney158k.PriceChanged)";fi
grep -q "StoreMoney158k" "$RSD/ShopMenu.lua" && grep -q "StoreMoney158k" "$C/EconomyClient.client.lua" && grep -q "StoreMoney158k" "$C/GamePassClient.client.lua" || fail "the store screens must use StoreMoney158k"
if grep -niE "claude|opus|sonnet|haiku|anthropic|gpt" "$HERE"/*.luau "$HERE/../store158k.md" "$RSD/StoreMoney158k.lua";then fail "a model name in the R158k files";fi
echo "ok: ProfileVersion 22, StoreMoney158k in the manifest, no server script writes its own money words, the screens and the server share StoreMoney158k"
prep_client() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$INV/world.luau" "$HERE/test_store_client158k.luau" "$2/"
 sed "s#'/home/user/tmz/src'#'$1'#" "$INV/mkbundle.py" > "$2/mkbundle.py"
 python3 "$2/mkbundle.py" "$2/rs_bundle.luau" EconomyClient="$1/StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua" GamePassClient="$1/StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua" >/dev/null
}
prep_server() { # $1 = a src tree, $2 = the run dir
 mkdir -p "$2";cp "$T/roblox.luau" "$TB/world.luau" "$HERE/test_store_server158k.luau" "$2/"
 sed "s#'../../../../src'#'$1'#" "$TB/mkbundle.py" > "$2/mkbundle.py";python3 "$2/mkbundle.py" "$2" >/dev/null
}
run_client() { (cd "$1" && timeout 600 /opt/luau/luau test_store_client158k.luau > client.log 2>&1); }
run_server() { (cd "$1" && timeout 600 /opt/luau/luau test_store_server158k.luau > server.log 2>&1); }
prep_client "$S" "$OUT/client";prep_server "$S" "$OUT/server"
echo "== test_store_client"
run_client "$OUT/client" || { grep -v '^WARN' "$OUT/client/client.log" | tail -25;fail "client test"; }
grep -v '^WARN' "$OUT/client/client.log" | tail -1
echo "== test_store_server"
run_server "$OUT/server" || { grep -v '^WARN' "$OUT/server/server.log" | tail -25;fail "server test"; }
grep -v '^WARN' "$OUT/server/server.log" | tail -1
if [ -n "$BEFORE" ];then
 echo "== before ($BEFORE): the same tests on the old scripts must fail"
 B=$OUT/before;rm -rf "$B";mkdir -p "$B";(cd "$REPO" && git archive "$BEFORE" src) | tar -x -C "$B"
 prep_client "$B/src" "$B/client";prep_server "$B/src" "$B/server"
 if run_client "$B/client";then fail "the client test passes on $BEFORE";fi
 grep '^FAIL' "$B/client/client.log" | sed 's/^/  old client /';grep -v '^WARN' "$B/client/client.log" | grep 'checks,' | sed 's/^/  /'
 if run_server "$B/server";then fail "the server test passes on $BEFORE";fi
 grep '^FAIL' "$B/server/server.log" | sed 's/^/  old server /';grep -v '^WARN' "$B/server/server.log" | grep 'checks,' | sed 's/^/  /'
fi
[ "${TEETH:-1}" = 0 ] && { echo "R158k store suite passed (teeth skipped)";exit 0; }
echo "== teeth"
mutant() { # $1 name, $2 file (relative to src), $3 from (fixed string), $4 to, $5 client|server
 M=$OUT/mut_$1;rm -rf "$M";mkdir -p "$M";cp -r "$S" "$M/src"
 python3 - "$M/src/$2" "$3" "$4" <<'PY' || fail "mutant $1: pattern not found"
import sys
p,a,b=sys.argv[1:4];s=open(p,encoding='utf-8').read()
if a not in s: sys.exit(1)
open(p,'w',encoding='utf-8').write(s.replace(a,b,1))
PY
 if [ "$5" = client ];then prep_client "$M/src" "$M/run";if run_client "$M/run";then fail "mutant $1 was not caught";fi
 else prep_server "$M/src" "$M/run";if run_server "$M/run";then fail "mutant $1 was not caught";fi;fi
 echo "caught: $1";rm -rf "$M"
}
mutant hud_rounds_nearest ReplicatedStorage/GardenWallet.lua "(self.Kind=='Speed'and Numbers.Compact(value)or Numbers.Balance(value))" "Numbers.Compact(value)" client
mutant market_line_nearest StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua 'cashLabel.Text = "Cash  $" .. CashNumbers.Balance(state.Cash)' 'cashLabel.Text = "Cash  $" .. CashNumbers.Compact(state.Cash)' client
mutant price_rounds_down ReplicatedStorage/CashNumbers.lua "function Numbers.Price(value)return rounded(value,true)end" "function Numbers.Price(value)return rounded(value,false)end" client
mutant dead_need_button ReplicatedStorage/ShopMenu.lua " return 'Buy  \$'..Cash.Price(product.Price),true" " if (cash or 0)<(product.Price or 0)then return 'Need \$'..Cash.Compact(product.Price-(cash or 0)),false end
 return 'Buy  \$'..Cash.Price(product.Price),true" client
mutant no_press_check ReplicatedStorage/ShopMenu.lua "  if M.Short(record.Product)then if self.OnShort then pcall(self.OnShort)end;Money.Notice('Cash');return end" "" client
mutant market_status_line StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua 'if money then setStatus("", false); require(ReplicatedStorage:WaitForChild("StoreMoney158k")).Notice(money) else' 'if false then else' client
mutant press_dropped_while_busy StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua "	for _ = 1, 300 do
		if not requestBusy then break end" "	for _ = 1, 0 do
		if not requestBusy then break end" client
mutant market_reply_cash StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua "	if live ~= nil then state.Cash = live end" "" client
mutant loading_refuses ReplicatedStorage/StoreMoney158k.lua " if not player or player:GetAttribute('DataStatus')~='Loaded'then return nil end" " if not player then return nil end" client
mutant shop_gem_no_check StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua " if currency and shown and Money.Short(player,currency,shown)then setStatus('');Money.Notice(currency);return end" "" client
mutant shop_money_strip StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua "and result.Success==false and Money.Refusal(result.Message)" "and false" client
mutant max_zero StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua "tostring(math.max(1,math.min(9000," "tostring((math.min(9000," client
mutant rule_strict ReplicatedStorage/StoreMoney158k.lua " return M.Compare(b,p)>=0" " return M.Compare(b,p)>0" server
mutant spend_ignores_rule ServerScriptService/ChestChaseServer/PlayerDataService.lua 'not require(game:GetService("ReplicatedStorage").StoreMoney158k).CanAfford(cashValue.Value, amount)' "cashValue.Value <= amount" server
mutant market_old_words ServerScriptService/ChestChaseServer/EconomyService.lua 'Message = require(ReplicatedStorage:WaitForChild("StoreMoney158k")).Cash}' 'Message = "NOT ENOUGH CASH"}' server
mutant gems_old_words ServerScriptService/ChestChaseServer/PremiumProgress.lua "if not Money.CanAfford(state.Gems,offer.GemPrice)then return false,Money.Gems end" "if state.Gems<offer.GemPrice then return false,'NOT ENOUGH GEMS'end" server
mutant convert_old_words ServerScriptService/ChestChaseServer/PremiumProgress.lua "  if not Money.CanAfford(self:GetCash(player),cost)then return false,Money.Cash end" "  if self:GetCash(player)<cost then return false,'NOT ENOUGH CASH'end" server
mutant pad_no_notice ServerScriptService/ChestChaseServer/GardenUpgradeService.lua "   if not okay and money.Refusal(message)and self.Notifications then" "   if false then" server
# (owner: "make sure store prices are always the same")
mutant price_rounded ReplicatedStorage/CashNumbers.lua "then return commas(digits)end -- (a price the short form cannot write exactly: in full)" "then scaled+=1 end" client
mutant market_price_not_sent ReplicatedStorage/ShopMenu.lua "pcall(self.OnPurchase,record.Product.Id,record.Product.Price)" "pcall(self.OnPurchase,record.Product.Id)" client
mutant market_no_refresh StarterPlayer/StarterPlayerScripts/EconomyClient.client.lua " elseif type(reply)=='table'and type(reply.Products)=='table'then reply.Message=nil;adoptState(reply)end" " end" client
mutant shop_price_not_sent StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua "pcall(request.InvokeServer,request,action,value,shown)" "pcall(request.InvokeServer,request,action,value)" client
mutant shop_caption_catalog StarterPlayer/StarterPlayerScripts/GamePassClient.client.lua "if type(offer)=='table'and type(offer.GemPrice)=='number'then price=offer.GemPrice end" "" client
mutant market_ignores_shown ServerScriptService/ChestChaseServer/EconomyService.lua "	if shown ~= nil and shown ~= product.Price then" "	if false then" server
mutant shop_ignores_shown ServerScriptService/ChestChaseServer/PremiumService.lua "  if shown~=nil and price~=nil and shown~=price then okay,message=false,Money.PriceChanged" "  if false then okay,message=false,Money.PriceChanged" server
mutant sign_rounded ServerScriptService/ChestChaseServer/GardenUpgradeService.lua "  if not require(RS:WaitForChild('CashNumbers')).Reads(short,cost)then" "  if false then" server
echo "R158k store suite passed"
