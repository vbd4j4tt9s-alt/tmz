"""R153 server fixes: break the fixes one at a time in a copy of the file, rebuild the mock world with the broken file in place of the real one and run the test that must notice it.
Usage: python3 mutate_fixes_server.py SRC_DIR OUT_DIR TESTS_DIR TOOLS_TESTS_DIR PROPOSALS_DIR
Every mutation must make its test fail (exit code != 0). Prints one line per mutation; exits 1 if one survives or its pattern is not in the file."""
import os
import shutil
import subprocess
import sys

src, out, here, tools, proposals = [os.path.abspath(a) for a in sys.argv[1:6]]
SRV = 'ServerScriptService/ChestChaseServer/'
MUTATIONS = [
    # (name, file under src, old text, new text, test)
    ('quest packs use the login arm', SRV + 'DailyProgress.lua', "source=='DailyQuest'and'DailyQuest'or'Daily'", "'Daily'", 'test_fixes_server'),
    ('daily done arms nothing for the quests', SRV + 'OwnerUpdateCommands82.lua', "TestPacks.Arm(p,'DailyQuest',open,nil,left)", "TestPacks.Arm(p,'DailyQuest',0)", 'test_fixes_server'),
    ('the test day lasts 15 minutes', SRV + 'OwnerUpdateCommands82.lua', "TestPacks.Arm(p,'Daily',1,nil,left)", "TestPacks.Arm(p,'Daily',1)", 'test_fixes_server'),
    ('the daily commands do not taint the hub', SRV + 'OwnerUpdateCommands82.lua', "if hub then pcall(hub.NoteOwnerGrant,hub,p)end", "if false then end", 'test_fixes_server'),
    ('the arm has no DailyQuest source', SRV + 'OwnerTestPacks.lua', "Daily=true,DailyQuest=true,Bonus=true", "Daily=true,Bonus=true", 'test_fixes_server'),
    ('the seed loses the lock at the open', SRV + 'PlayerDataService.lua', "GiftLocked=pack.GiftLocked==true or nil, -- R153 (review M2)", "GiftLocked=nil, -- R153 (review M2)", 'test_fixes_server'),
    ('a save drops the lock of a seed', SRV + 'PlayerDataService.lua', "GiftLocked=chestRecord.GiftLocked==true or nil,", "GiftLocked=(chestRecord.Kind==\"Pack\" and chestRecord.GiftLocked==true) or nil,", 'test_fixes_server'),
    ('a load drops the lock of a seed', SRV + 'PlayerDataService.lua', "GiftLocked=savedChest.GiftLocked==true or nil,", "GiftLocked=(savedChest.Kind==\"Pack\" and savedChest.GiftLocked==true) or nil,", 'test_fixes_server'),
    ('the plant loses the lock', 'ReplicatedStorage/PlantRules.lua', "GiftLocked=seed.GiftLocked==true or nil}", "GiftLocked=nil}", 'test_fixes_server'),
    ('locked fruit can be offered and accepted', SRV + 'FruitGiftService.lua', [" if crop.GiftLocked then self.Remote:FireClient(from,'Status',S.LockedFruitText);return end -- R153: fruit from a gift-locked seed\n", " if crop.GiftLocked then self.Remote:FireClient(from,'Status',S.LockedFruitText);return end\n if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then return end"], ["\n", " if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then return end"], 'test_fixes_server'),
    ('locked fruit can be accepted (the offer check alone is not enough)', SRV + 'FruitGiftService.lua', " if crop.GiftLocked then self.Remote:FireClient(from,'Status',S.LockedFruitText);return end\n if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then return end", " if crop.PaidRandom and(from:GetAttribute('PaidTradingAllowed')~=true or to:GetAttribute('PaidTradingAllowed')~=true)then return end", 'test_fixes_server'),
    ('a locked seed or pack can be offered and accepted', SRV + 'FruitGiftService.lua', ["if record.GiftLocked then self.Remote:FireClient(from,'Status',record.Kind=='Seed'and S.LockedSeedText or S.LockedText);return end\n if self:SeedPaidBlocked(record,from,to)then self.Remote:FireClient(from,'Status','This bought '", "if record.GiftLocked then self.Remote:FireClient(from,'Status',record.Kind=='Seed'and S.LockedSeedText or S.LockedText);return end\n local garden=self.Data.Gardens[from]"], ["if false then end\n if self:SeedPaidBlocked(record,from,to)then self.Remote:FireClient(from,'Status','This bought '", "local garden=self.Data.Gardens[from]"], 'test_fixes_server'),
    ('the day-7 Void Pack is not locked', SRV + 'DailyProgress.lua', "GiftLocked=D.LockDay7Void~=false or nil", "GiftLocked=nil", 'test_fixes_server'),
    ('the day-7 switch is ignored', SRV + 'DailyProgress.lua', "GiftLocked=D.LockDay7Void~=false or nil", "GiftLocked=true", 'test_fixes_server'),
    ('the day-7 switch off by default', 'ReplicatedStorage/DailyRewards.lua', "D.LockDay7Void=true", "D.LockDay7Void=false", 'test_fixes_server'),
    ('the BEST PULL loop is not guarded', SRV + 'HubDisplayService.lua', "    local ok,err=pcall(function()\n     task.wait(self:SleepSeconds())\n     if self.Dead then return end\n     self:Step()\n    end)\n", "    local ok,err=true,nil\n    task.wait(self:SleepSeconds())\n    if self.Dead then break end\n    self:Step()\n", 'test_fixes_server'),
    ('a failed loop pass is not warned', SRV + 'HubDisplayService.lua', "if failures==1 or failures%12==0 then warn(", "if false then warn(", 'test_fixes_server'),
    ('the walk-speed hook is not guarded', SRV + 'Config.lua', "local okTest,temporary=pcall(ownerTestSpeed,player)", "local okTest,temporary=true,ownerTestSpeed(player)", 'test_fixes_server'),
    ('the pack open hook is not guarded', SRV + 'PlayerDataService.lua', "local okTest,expected=pcall(function()return require(script.Parent.RarePackTests).Expected(self,player,pack.Id)end)", "local okTest,expected=true,require(script.Parent.RarePackTests).Expected(self,player,pack.Id)", 'test_fixes_server'),
    ('the pack tool hook is not guarded', SRV + 'ChestService.lua', "local okTest,expected=pcall(function()return require(script.Parent.RarePackTests).Expected(self.PlayerData,player,record.Id)end)", "local okTest,expected=true,require(script.Parent.RarePackTests).Expected(self.PlayerData,player,record.Id)", 'test_fixes_server'),
    ('the owner tools start without a pcall', 'ServerScriptService/ChestChaseServerMain.server.lua', "local okTools, toolsError = pcall(function()\n\t\t\trequire(modules.StudioTestCommands).Start(Config, playerData, chestService, chaseService, baseService, notifications, mapService)\n\t\tend)", "local okTools, toolsError = true, require(modules.StudioTestCommands).Start(Config, playerData, chestService, chaseService, baseService, notifications, mapService)", 'test_fixes_boot'),
    ('the owner tools start in the main thread', 'ServerScriptService/ChestChaseServerMain.server.lua', "\ttask.spawn(function()\n\t\tlocal okTools, toolsError", "\t(function()\n\t\tlocal okTools, toolsError", 'test_fixes_boot'),
    ('the guard waits 900 s', 'ServerScriptService/ChestChaseServerMain.server.lua', "local STARTUP_TIMEOUT = 90", "local STARTUP_TIMEOUT = 900", 'test_fixes_boot'),
    ('the guard waits 20 s (misfires on a slow start)', 'ServerScriptService/ChestChaseServerMain.server.lua', "local STARTUP_TIMEOUT = 90", "local STARTUP_TIMEOUT = 20", 'test_fixes_boot'),
    ('the guard ignores a Failed state', 'ServerScriptService/ChestChaseServerMain.server.lua', "if state == \"Failed\" then\n\t\t\t\treason =", "if false then\n\t\t\t\treason =", 'test_fixes_boot'),
    ('a Ready start is still guarded', 'ServerScriptService/ChestChaseServerMain.server.lua', "if state == \"Ready\" then return end", "if false then return end", 'test_fixes_boot'),
    ('late joiners are not kicked', 'ServerScriptService/ChestChaseServerMain.server.lua', "\t\tPlayers.PlayerAdded:Connect(kick)\n", "", 'test_fixes_boot'),
    ('players in the server are not kicked', 'ServerScriptService/ChestChaseServerMain.server.lua', "\t\t\tfor _, player in ipairs(Players:GetPlayers()) do kick(player) end\n", "", 'test_fixes_boot'),
    ('Studio kicks too', 'ServerScriptService/ChestChaseServerMain.server.lua', "if RunService:IsStudio() then", "if false then", 'test_fixes_boot'),
    ('Studio shows no message', 'ServerScriptService/ChestChaseServerMain.server.lua', "ReplicatedStorage:SetAttribute(\"ChestChaseStartupNotice\", STARTUP_KICK_TEXT", "ReplicatedStorage:SetAttribute(\"ChestChaseStartupNoticeX\", STARTUP_KICK_TEXT", 'test_fixes_boot'),
    ('Studio does not warn the reason', 'ServerScriptService/ChestChaseServerMain.server.lua', "warn(\"[R153] THIS SERVER DID NOT START: \" .. reason)", "", 'test_fixes_boot'),
    ('a late Ready undoes the failure', 'ServerScriptService/ChestChaseServerMain.server.lua', "\t\tReplicatedStorage:SetAttribute(\"ChestChaseStartupState\", \"Failed\")\n\t\tif ReplicatedStorage", "\t\tif ReplicatedStorage", 'test_fixes_boot'),
    ('main marks Ready over a Failed state', 'ServerScriptService/ChestChaseServerMain.server.lua', "if ReplicatedStorage:GetAttribute(\"ChestChaseStartupState\") == \"Failed\" then\n\t\twarn(\"[R153] This server was already marked failed", "if false then\n\t\twarn(\"[R153] This server was already marked failed", 'test_fixes_boot'),
    ('the guard is never started', 'ServerScriptService/ChestChaseServerMain.server.lua', "do local okGuard,guardError = pcall(guardStartup);", "do local okGuard,guardError = true,nil;", 'test_fixes_boot'),
    ('the kick message is not the owner\'s', 'ServerScriptService/ChestChaseServerMain.server.lua', "this server broke while loading 😭 pls rejoin\"", "Server failed to start.\"", 'test_fixes_boot'),
    ('ChaseService starts the owner commands again', SRV + 'ChaseService.lua', "return ChaseService", "local startV142=ChaseService.Start\nfunction ChaseService:Start(...)\n startV142(self,...)\n require(script.Parent:WaitForChild('StudioTestCommands')).Start(self.Config,self.PlayerData,self.Chests,self,self.Bases,self.Notifications,self.Map)\nend\nreturn ChaseService", 'test_fixes_boot'),
    ('the notice is never shown', 'StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua', "label.Text=string.sub(text,1,400);gui.Enabled=true", "label.Text=string.sub(text,1,400)", 'test_fixes_notice'),
    ('the notice is never hidden', 'StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua', "if type(text)~='string'or text==''then if gui then gui.Enabled=false end;return end", "if type(text)~='string'or text==''then return end", 'test_fixes_notice'),
]
survived = []
caught = 0
mut = os.path.join(out)
shutil.rmtree(mut, ignore_errors=True)
os.makedirs(mut)
for index, (name, rel, old, new, test) in enumerate(MUTATIONS):
    path = os.path.join(src, rel)
    if not os.path.exists(path):
        print('FAIL: mutation "%s": %s is not in the tree' % (name, rel))
        survived.append(name)
        continue
    text = open(path, encoding='utf-8').read()
    olds, news = (old, new) if isinstance(old, list) else ([old], [new])
    if any(o not in text for o in olds):
        print('FAIL: mutation "%s": the pattern is not in %s' % (name, rel))
        survived.append(name)
        continue
    mutated_text = text
    for o, n in zip(olds, news):
        mutated_text = mutated_text.replace(o, n, 1)
    mutated = os.path.join(mut, 'm%d.lua' % index)
    open(mutated, 'w', encoding='utf-8').write(mutated_text)
    world = os.path.join(mut, 'w%d' % index)
    os.makedirs(world)
    for f in [os.path.join(tools, 'roblox.luau'), os.path.join(proposals, 'treadmill_bonus_R123/tests/world.luau')] + [os.path.join(here, f) for f in os.listdir(here) if f.endswith('.luau')]:
        shutil.copy(f, world)
    module = os.path.basename(rel)
    for suffix in ('.server.lua', '.client.lua', '.lua'):
        if module.endswith(suffix):
            module = module[:-len(suffix)]
            break
    extra = []
    main = os.path.join(src, 'ServerScriptService/ChestChaseServerMain.server.lua')
    notice = os.path.join(src, 'StarterPlayer/StarterPlayerScripts/StartupNotice153.client.lua')
    if os.path.exists(main):
        extra.append('ChestChaseServerMain=' + main)
    if os.path.exists(notice):
        extra.append('StartupNotice153=' + notice)
    extra.append('%s=%s' % (module, mutated))
    subprocess.run([sys.executable, os.path.join(here, 'mkbundle_clover.py'), world, '--src', src] + extra, check=True, stdout=subprocess.DEVNULL)
    if test == 'test_fixes_r152':
        raise SystemExit('r152 mutations are not supported')
    result = subprocess.run(['/opt/luau/luau', test + '.luau'], cwd=world, capture_output=True, text=True, timeout=900)
    log = result.stdout + result.stderr
    failing = sum(1 for line in log.split('\n') if line.startswith('FAIL: '))
    if result.returncode != 0:
        caught += 1
        print('ok: "%s" -> %s fails (%d failing checks)' % (name, test, failing))
    else:
        survived.append(name)
        print('FAIL: mutation SURVIVED: "%s" (%s still passes)' % (name, test))
    shutil.rmtree(world, ignore_errors=True)
print('%d of %d mutations caught' % (caught, len(MUTATIONS)))
sys.exit(1 if survived else 0)
