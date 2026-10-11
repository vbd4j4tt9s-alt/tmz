"""R155: the checks have teeth. Each mutant is a broken copy of the R155 source (made in a private copy of the tree); run_mech_coats.sh, restricted to the step that must catch it, has to FAIL.
Usage: python3 mutate_mech_coats.py <scratch dir> [name ...]     (no name = every mutant; prints one line per mutant and exits 1 if any survived)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '..', '..', '..', '..'))
SS = 'src/ServerScriptService/ChestChaseServer/'
RSD = 'src/ReplicatedStorage/'
SP = 'src/StarterPlayer/StarterPlayerScripts/'
COPY = ['src', 'tools/tests'] + ['docs/proposals/%s/tests' % d for d in ('inventory_R113', 'R149', 'R150', 'R151', 'R152', 'R153', 'R155', 'treadmill_bonus_R123')]

# name: (steps that must catch it, [(file, old, new), ...])
M = {
    'no_roll': ('1', [(SS + 'PremiumProgress.lua', "PackMutation=paid==true and P.RollCoat()or'None'", "PackMutation='None'")]),
    'free_packs_roll': ('1', [(SS + 'PremiumProgress.lua', "PackMutation=paid==true and P.RollCoat()or'None'", "PackMutation=P.RollCoat()")]),
    'one_coat_per_batch': ('1', [
        (SS + 'PremiumProgress.lua', "PackMutation=paid==true and P.RollCoat()or'None'", "PackMutation=shared"),
        (SS + 'PremiumProgress.lua', "  local success,err=pcall(function()\n   for _=1,offer.Count do", "  local shared=paid==true and P.RollCoat()or'None'\n  local success,err=pcall(function()\n   for _=1,offer.Count do")]),
    'wrong_rates': ('1', [(SS + 'PremiumProgress.lua', "function P.RollCoat()return PackRules.RollMutation(CoatRandom:NextNumber())end", "function P.RollCoat()return PackRules.RollMutation(math.min(.9999,CoatRandom:NextNumber()+.04))end")]),
    'sale_ignores_event': ('1', [(RSD + 'MechCatalog.lua', "and(untilTime==0 or now<untilTime)and Limited.Active(now)", "and(untilTime==0 or now<untilTime)")]),
    'event_never_over': ('1', [(RSD + 'MechCatalog.lua', "function C.EventOver(now)return not Limited.Active(now or os.time())end", "function C.EventOver(now)return false end")]),
    'late_receipt_refused': ('1', [(SS + 'PremiumService.lua', "or self.Busy[player]then return later end", "or self.Busy[player]or(mech and Catalog.EventOver())then return later end")]),
    'gems_charged_after_end': ('1', [
        (SS + 'PremiumProgress.lua', "  if Catalog.EventOver()then return false,Catalog.Event.Refused end -- R155: the limited event is over: nothing is charged, nothing is granted\n  if not Catalog.OnSale()then return false,'THIS PACK IS OFF SALE'end\n", ""),
        (RSD + 'MechCatalog.lua', "and(untilTime==0 or now<untilTime)and Limited.Active(now)", "and(untilTime==0 or now<untilTime)")]),
    'prompt_after_end': ('1', [(SS + 'PremiumService.lua', "if offer and Catalog.EventOver()then okay=false;message=Catalog.Event.Refused\n   elseif entry and entry.RobuxAvailable", "if false then\n   elseif entry and entry.RobuxAvailable"),
                               (RSD + 'MechCatalog.lua', "and(untilTime==0 or now<untilTime)and Limited.Active(now)", "and(untilTime==0 or now<untilTime)")]),
    'label_without_coat': ('1', [(RSD + 'SeedPackRules.lua', "if variant=='MechLimited'then local m=Rules.MutationKey(mutation);return(m~='None'and m..' 'or'')..'Limited Mech Pack'end", "if variant=='MechLimited'then return 'Limited Mech Pack'end")]),
    'tooltip_without_coat_line': ('1', [(SS + 'ChestService.lua', "if record.BagVariant=='MechLimited' and record.PaidRandom==true then table.insert(rows,require(ReplicatedStorage.MechCatalog).CoatLine()) end", "")]),
    'tooltip_coat_on_free_packs': ('1', [(SS + 'ChestService.lua', "if record.BagVariant=='MechLimited' and record.PaidRandom==true then", "if record.BagVariant=='MechLimited' then")]),
    'notice_without_coats': ('1', [(SS + 'PurchaseAnnouncer.lua', "..(kind=='Pack'and coatSuffix(extra)or'')", "")]),
    'reveal_loses_coat': ('1', [(SS + 'PlayerDataService.lua', "PackSize=PackRules.SanitizePackSize(pack.PackSize),PackMutation=PackRules.MutationKey(pack.PackMutation),Weather=Weather.Key(pack.Weather),WeatherCheckedEvent=Weather.CheckedEvent(pack.WeatherCheckedEvent),\n            TestGrant=(pack.TestGrant", "PackSize=PackRules.SanitizePackSize(pack.PackSize),PackMutation='None',Weather=Weather.Key(pack.Weather),WeatherCheckedEvent=Weather.CheckedEvent(pack.WeatherCheckedEvent),\n            TestGrant=(pack.TestGrant")]),
    'fruit_inherit_half': ('1', [(RSD + 'BalanceRules.lua', "B.MutationInheritance=.20", "B.MutationInheritance=.50")]),
    'shop_never_ticks': ('2', [(SP + 'GamePassClient.client.lua', "if value then if changed then startTicking()end else tickToken+=1 end", "if value then else tickToken+=1 end")]),
    'shop_buttons_stay_on': ('2', [
        (SP + 'GamePassClient.client.lua', "local gemLive=available.GemAvailable==true and not over and not bagFull", "local gemLive=available.GemAvailable==true and not bagFull"),
        (SP + 'GamePassClient.client.lua', "packInfo.IsForSale~=false and not over and not bagFull", "packInfo.IsForSale~=false and not bagFull")]),
    # R157: a full Bag says "Bag full" (the flag, the words, a press that only shows the notice)
    'bagfull_flag_missing': ('1', [(SS + 'PremiumService.lua', "RobuxPrice=info and info.PriceInRobux,BagFull=ready and not allowed and why==Catalog.BagFullNotice(count)or nil}", "RobuxPrice=info and info.PriceInRobux}")]),
    'bagfull_robux_old_words': ('1', [(SS + 'PremiumService.lua', "   elseif offer and entry and entry.BagFull then okay=false;message=Catalog.BagFullNotice(count) -- R157: a full Bag is told plainly (no prompt); R157b review: with the real count for more than one pack\n", "")]),
    'bagfull_gems_old_words': ('1', [(SS + 'PremiumProgress.lua', "if type(self.RoomFor)=='function'and not self:RoomFor(player,offer.Count,{Receipt=receipt==true})then return false,Catalog.BagFullNotice(offer.Count)end", "if type(self.RoomFor)=='function'and not self:RoomFor(player,offer.Count,{Receipt=receipt==true})then return false,'MAKE ROOM FOR '..offer.Count..' PACKS FIRST!'end")]),
    'bagfull_flag_when_off_sale': ('1', [(SS + 'PremiumService.lua', "local ready=saveReady and Catalog.OnSale()and player:GetAttribute('PaidRandomAllowed')==true", "local ready=saveReady and player:GetAttribute('PaidRandomAllowed')==true")]),
    'shop_bagfull_press_buys': ('2', [(SP + 'GamePassClient.client.lua', "gemBuy.Activated:Connect(function()if gemBuy:GetAttribute('BagFull')then bagFullPress()elseif gemBuy.Active then act('BuyPack',packCount)end end)", "gemBuy.Activated:Connect(function()if gemBuy.Active then act('BuyPack',packCount)end end)")]),
    'shop_bagfull_no_notice': ('2', [(SP + 'GamePassClient.client.lua', "Feed.Plain(Catalog.BagFullNotice(packCount),require(RS:WaitForChild('SimpleGameText')).Red,2.5)", "")]),
    # R157b review: the notice names the quantity that does not fit; room made in the Bag while the shop is open reaches the buttons (a throttled State read on HeldItemCount / HeldItemCap / ChestChaseSeedCarrying)
    'bagfull_words_ignore_count': ('1 2', [(RSD + 'MechCatalog.lua', "if count>1 then return string.format(C.BagFull.Many,math.floor(count))end", "")]),
    'bagfull_server_gems_one_pack_words': ('1', [(SS + 'PremiumProgress.lua', "if type(self.RoomFor)=='function'and not self:RoomFor(player,offer.Count,{Receipt=receipt==true})then return false,Catalog.BagFullNotice(offer.Count)end", "if type(self.RoomFor)=='function'and not self:RoomFor(player,offer.Count,{Receipt=receipt==true})then return false,Catalog.BagFull.Notice end")]),
    'bagfull_server_robux_one_pack_words': ('1', [(SS + 'PremiumService.lua', "message=Catalog.BagFullNotice(count) -- R157: a full Bag is told plainly", "message=Catalog.BagFull.Notice -- R157: a full Bag is told plainly")]),
    'shop_bagfull_press_one_pack_words': ('2', [(SP + 'GamePassClient.client.lua', "Feed.Plain(Catalog.BagFullNotice(packCount),", "Feed.Plain(Catalog.BagFull.Notice,")]),
    'shop_bagfull_text_not_red': ('2', [(RSD + 'SimpleGameText.lua', 'if message:match("^BAG FULL! MAKE ROOM FOR %d+ PACKS FIRST$") then return message, Text.Red end', "")]),
    'shop_bag_change_not_read': ('2', [(SP + 'GamePassClient.client.lua', "for _,name in ipairs({'HeldItemCount','HeldItemCap','ChestChaseSeedCarrying'})do watch(player:GetAttributeChangedSignal(name),heldChanged)end\n", "")]),
    'shop_bag_change_cap_not_watched': ('2', [(SP + 'GamePassClient.client.lua', "ipairs({'HeldItemCount','HeldItemCap','ChestChaseSeedCarrying'})", "ipairs({'HeldItemCount','ChestChaseSeedCarrying'})")]),
    'shop_bag_change_carry_not_watched': ('2', [(SP + 'GamePassClient.client.lua', "ipairs({'HeldItemCount','HeldItemCap','ChestChaseSeedCarrying'})", "ipairs({'HeldItemCount','HeldItemCap'})")]),
    'shop_bag_change_unthrottled': ('2', [(SP + 'GamePassClient.client.lua', "task.delay(math.max(0,lastHeldRead+.5-os.clock()),function()", "task.delay(0,function()")]),
    'shop_bag_change_dropped_in_flight': ('2', [(SP + 'GamePassClient.client.lua', "lastHeldRead=os.clock();if busy then pendingState=true else act('State')end", "lastHeldRead=os.clock();if not busy then act('State')end")]),
    'shop_bagfull_says_unavailable': ('2', [(SP + 'GamePassClient.client.lua', "or bagFull and Catalog.BagFull.Button or(gemLive", "or(gemLive")]),
    'shop_no_coat_line': ('2', [(SP + 'GamePassClient.client.lua', "Art.Text(pack,'CoatNote',Catalog.CoatLine(),15", "Art.Text(pack,'CoatNote','',15")]),
    'keep_flag_removed': ('3', [(RSD + 'MechPackArt153.lua', "  if s.Keep then p:SetAttribute('MechCoatKeep',true)end -- R155: a Gold / Diamond coat leaves this part's colour alone\n", "")]),
    'coat_paints_the_lit_parts': ('3', [(RSD + 'SeedPackVisuals.lua', " and not p:GetAttribute('MechCoatKeep')then", " then")]),
    'mech_plant_not_coated': ('3', [(RSD + 'MechArt.lua', "if mutation=='Gold'or mutation=='Diamond'then\n   q.Color=", "if false then\n   q.Color=")]),
    'mythic_skip_comes_back': ('4', [(RSD + 'RarePullRules.lua', "Letterbox=tier.Letterbox==true,Quick=quick==true}", "Letterbox=tier.Letterbox==true,Quick=quick==true,SkipFrom=L.CardSkipFrom}")]),  # R157: a Mythic card's skip must stay ignored
    'opening_seed_loses_coat': ('4', [(SP + 'SeedPackClient.client.lua', 'require(ReplicatedStorage:WaitForChild("PlantVisuals")).Coat(seed,record.Bag:GetAttribute("PackMutation"))', "")]),
    'layer_too_thin': ('5', [(RSD + 'MechPackArt153.lua', "local A={Revision=153,TemplateKey='Forest_01',Layer=.046}", "local A={Revision=153,TemplateKey='Forest_01',Layer=.004}")]),
}


def run(scratch, name):
    steps, edits = M[name]
    tree = os.path.join(scratch, 'm_' + name)
    shutil.rmtree(tree, ignore_errors=True)
    for rel in COPY:
        shutil.copytree(os.path.join(REPO, rel), os.path.join(tree, rel))
    for rel, old, new in edits:
        path = os.path.join(tree, rel)
        text = open(path, encoding='utf-8').read()
        if text.count(old) != 1:
            return 'BROKEN MUTANT (%d matches of %r in %s)' % (text.count(old), old[:60], rel)
        open(path, 'w', encoding='utf-8').write(text.replace(old, new))
    env = dict(os.environ, STEPS=steps)
    r = subprocess.run(['sh', os.path.join(tree, 'docs/proposals/R155/tests/run_mech_coats.sh'), os.path.join(tree, 'w')], env=env, capture_output=True, text=True, timeout=3600)
    shutil.rmtree(tree, ignore_errors=True)
    if r.returncode == 0:
        return 'SURVIVED'
    why = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith('FAIL') or 'failures' in l][:1]
    return 'killed (step %s): %s' % (steps, (why[0] if why else 'failed')[:150])


def main():
    scratch = sys.argv[1]
    os.makedirs(scratch, exist_ok=True)
    names = sys.argv[2:] or list(M)
    survived = 0
    for name in names:
        res = run(scratch, name)
        print('%-28s %s' % (name, res), flush=True)
        if not res.startswith('killed'):
            survived += 1
    print('%d mutants, %d not killed' % (len(names), survived))
    sys.exit(1 if survived else 0)


if __name__ == '__main__':
    main()
