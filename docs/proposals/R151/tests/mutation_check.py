"""R151 mutation check: breaks the chat-only announcements on purpose, one change at a time, and runs the suite that must notice. Every mutation must make that suite FAIL.
Usage: python3 mutation_check.py SCRATCHDIR [name filter]   (needs /opt/luau; the source is restored after every mutation, also when this script is interrupted)"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
S = REPO + '/src'
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
SS = S + '/ServerScriptService/ChestChaseServer/'
SERVER = SS + 'PullAnnouncer.lua'
RULES = S + '/ReplicatedStorage/PullAnnounceRules.lua'
CLIENT = S + '/StarterPlayer/StarterPlayerScripts/PullAnnouncerClient.client.lua'
PDS = SS + 'PlayerDataService.lua'
CFG = S + '/ReplicatedStorage/SettingsConfig.lua'
TESTPACKS = SS + 'OwnerTestPacks.lua'
RARE = S + '/ReplicatedStorage/RarePullRules.lua'
OWNER = SS + 'OwnerUpdateCommands82.lua'

MUTATIONS = [
    # (name, file, old, new, suite that must fail)
    # --- who is announced -----------------------------------------------------------------------------------------------------------------------------------
    ('TEST guaranteed reveals announce', SERVER, " if wasTest then return false,'test pack'end\n", "\n", 'test_server'),
    ('packs marked TestGrant announce', SERVER, " if pack.TestGrant==true then return false,'test pack'end\n", "\n", 'test_server'),
    ('hook ignores the TEST flag', PDS, "OnOpened(player,pack,reward,testSeed~=nil)", "OnOpened(player,pack,reward,false)", 'test_server'),
    ('no reveal delay', SERVER, " local wait=Rules.RevealDelay(rarity)+(tonumber(lag)or 0)", " local wait=0", 'test_server'),
    ('Legendary also goes global', RULES, "GlobalMinRarity='Secret',", "GlobalMinRarity='Legendary',", 'test_rules'),
    ('Mythic below the in-server threshold', RULES, "InServerMinRarity='Legendary',", "InServerMinRarity='Mythic',", 'test_rules'),
    # --- owner-made packs are marked (each command path) ---------------------------------------------------------------------------------------------------------
    ('/test pack does not mark its packs', SS + 'StudioTestCommands.lua', "PackMutation=coat,TestGrant=isPack or nil})", "PackMutation=coat})", 'test_server'),
    ('/test pack marks seeds too', SS + 'StudioTestCommands.lua', "PackMutation=coat,TestGrant=isPack or nil})", "PackMutation=coat,TestGrant=true})", 'test_server'),
    ('/test rarepacks does not mark its packs', SS + 'RarePackTests.lua', "PackSize=1,PackMutation='None',TestGrant=true})", "PackSize=1,PackMutation='None'})", 'test_server'),
    ('packset / void / verity do not mark their packs', OWNER, "OddsVersion=Packs.OddsVersion},{TestGrant=true})", "OddsVersion=Packs.OddsVersion})", 'test_server'),
    ('mystery commands do not arm', OWNER, "  if sub=='ready'or sub=='next'then TestPacks.Arm(p,'Mystery',1)end", "  if false then TestPacks.Arm(p,'Mystery',1)end", 'test_server'),
    ('mystery next leaves the arm for the next normal pack', OWNER, "  if sub=='next'then TestPacks.Disarm(p,'Mystery')end", "  if false then TestPacks.Disarm(p,'Mystery')end", 'test_server'),
    ('the mystery service does not claim the arm', SS + 'MysteryPackService.lua', " pcall(function()require(script.Parent.OwnerTestPacks).Claim(player,'Mystery',record)end)", " pcall(function()local _=record end)", 'test_server'),
    ('daily commands do not arm', OWNER, "  if sub=='next'or sub=='week'or sub=='reset'then TestPacks.Arm(p,'Daily',1)end", "  if false then TestPacks.Arm(p,'Daily',1)end", 'test_server'),
    ('the daily claim does not claim the arm', SS + 'DailyProgress.lua', "   pcall(function()require(script.Parent.OwnerTestPacks).Claim(player,'Daily',added)end)", "   pcall(function()local _=added end)", 'test_server'),
    ('bonus roll does not arm', OWNER, "   TestPacks.Arm(p,'Bonus',1);local result=bonus:Roll(p);", "   local result=bonus:Roll(p);", 'test_server'),
    ('bonus ready does not arm', OWNER, "TestPacks.Arm(p,'Bonus',n);return ok,'Bonus rolls ready: '", "return ok,'Bonus rolls ready: '", 'test_server'),
    ('the bonus service does not claim the arm', SS + 'TreadmillBonusService.lua', " pcall(function()require(script.Parent.OwnerTestPacks).Claim(player,'Bonus',record)end)", " pcall(function()local _=record end)", 'test_server'),
    ('an owner-forced event pack is not marked on Bank', SS + 'ChestService.lua', "\tif seed.TestGrant == true then record.TestGrant = true end", "\tif false then record.TestGrant = true end", 'test_server'),
    ('AddChest ignores the TestGrant option', PDS, "TestGrant = (type(options) == \"table\" and options.TestGrant == true) or nil, -- R151: made by an owner command", "TestGrant = nil, -- R151: made by an owner command", 'test_server'),
    ('every pack is marked as a test pack', PDS, "TestGrant = (type(options) == \"table\" and options.TestGrant == true) or nil, -- R151: made by an owner command", "TestGrant = true, -- R151: made by an owner command", 'test_server'),
    ('the Void -> Verity conversion drops the mark', PDS, "TestGrant = pack.TestGrant == true or nil, -- R151: an owner-made Void pack", "TestGrant = nil, -- R151: an owner-made Void pack", 'test_server'),
    ('the save drops the mark', PDS, "TestGrant=(chestRecord.Kind==\"Pack\" and chestRecord.TestGrant==true) or nil,", "TestGrant=nil,", 'test_server'),
    ('the load drops the mark', PDS, "TestGrant=(savedChest.Kind==\"Pack\" and savedChest.TestGrant==true) or nil,", "TestGrant=nil,", 'test_server'),
    ('a Seed record serialises the mark', PDS, "TestGrant=(chestRecord.Kind==\"Pack\" and chestRecord.TestGrant==true) or nil,", "TestGrant=chestRecord.TestGrant==true or nil,", 'test_server'),
    ('an arm never expires', TESTPACKS, " if(now or os.clock())>entry.Expires then row[source]=nil;return false end\n", "\n", 'test_server'),
    ('an arm is never used up', TESTPACKS, " entry.Left-=1;if entry.Left<=0 then row[source]=nil end\n", "\n", 'test_server'),
    # --- publishing / receiving (MessagingService) ---------------------------------------------------------------------------------------------------------------
    ('origin server shows its own global message', SERVER, "if data.j==self.JobId then self.Stats.Origin+=1;return end", "", 'test_server'),
    ('no dedupe', SERVER, "elseif self:_seen(data.j..':'..e.Id)then self.Stats.Repeat+=1", "elseif false then self.Stats.Repeat+=1", 'test_server'),
    ('stale messages accepted', RULES, "return age<=R.Setting('StaleSeconds')and age>=-R.Setting('FutureSeconds')", "return true", 'test_rules'),
    ('no publish gap', SERVER, "local wait=Rules.Setting('PublishGapSeconds')-(self.Clock()-self.LastPublish)", "local wait=0", 'test_server'),
    ('failed publishes retried forever', SERVER, "if item.Attempts<A.MaxAttempts then", "if true then", 'test_server'),
    ('subscription never retried', SERVER, "task.delay(wait,function()self:_subscribe(attempt+1)end)", "", 'test_server'),
    ('rarity trusted from the message', RULES, " e.SeedId,e.SeedName,e.Rarity=info.Id,info.Name,info.Rarity", " e.SeedId,e.SeedName,e.Rarity=info.Id,info.Name,fields.Rarity or info.Rarity", 'test_rules'),
    ('every player is sent each line twice', SERVER, "   if pcall(self.Remote.FireClient,self.Remote,p,payload)then sent+=1 end", "   pcall(self.Remote.FireClient,self.Remote,p,payload);if pcall(self.Remote.FireClient,self.Remote,p,payload)then sent+=1 end", 'test_server'),
    # --- [timing] the line waits for the PULLER's reveal (one source of truth: RarePullRules) -------------------------------------------------------------------------
    ('[timing] the delay is the old server reveal length', RULES, " if okReveal and type(Reveal)=='table'and Reveal.LatestSeedShown then", " if false then", 'test_server'),
    ('[timing] the delay has no margin', RULES, " return shown+R.Setting('RevealMargin')", " return shown", 'test_server'),
    ('[timing] the delay takes the quick ladder', RARE, " if rank<=5 then return L.SeedShown(rank,nil,false)end", " if rank<=5 then return L.SeedShown(rank,nil,true)end", 'test_server'),
    ('[timing] the delay takes only the Calm scene', RARE, "latest=math.max(latest,L.SeedShown(rank,variant))", "latest=L.SeedShown(rank,'Calm')", 'test_server'),
    ('[timing] the seed counts as shown at the hit, not the "1 in N"', RARE, " return math.max(tl.Climax,tl.Rise or 0,tl.Odds or 0)", " return tl.Climax", 'test_server'),
    ('[timing] a leaving puller does not release the line', SERVER, "self.Players.PlayerRemoving:Connect(function(player)self:_released(player)end)", "self.Players.PlayerRemoving:Connect(function(player)end)", 'test_server'),
    ('[timing] a line is not cancelled by Destroy', SERVER, " for entry in pairs(self.Waiting)do entry.Done=true end\n", "\n", 'test_server'),
    ('[timing] the puller\'s own line is not held on their screen', CLIENT, " local wait=holdFor(e)", " local wait=0", 'test_client'),
    ('[timing] a held line is written after teardown', CLIENT, "task.delay(wait,function()if not dead then chat(e)end end)", "task.delay(wait,function()chat(e)end)", 'test_client'),
    ('[timing] a held line can wait forever', CLIENT, "local HOLD_MAX=8", "local HOLD_MAX=1e9", 'test_client'),
    # --- [records] hub records through the announcer ------------------------------------------------------------------------------------------------------------------
    ('[records] a fruit record travels to every server when its seed is Secret+', RULES, " if record~='BestPull'then return'InServer'end", " if false then return'InServer'end", 'test_server'),
    ('[records] a record below the threshold is announced', RULES, " if R.Qualifies('InServer',rarity)then return'InServer'end\n return nil", " if R.Qualifies('InServer',rarity)then return'InServer'end\n return'InServer'", 'test_rules'),
    ('[records] a Secret+ record stays at home', RULES, " if R.Qualifies('Global',rarity)then return'Global'end", " if false then return'Global'end", 'test_rules'),
    ('[records] a record travels without its key', RULES, "k=e.Kind=='Record'and e.Record or nil", "k=nil", 'test_server'),
    ('[records] another server accepts any record', SERVER, "   local travels=e and(record and Rules.RecordScope(e.Record,e.Rarity)=='Global'or not record and Rules.Qualifies('Global',e.Rarity))", "   local travels=e", 'test_server'),
    ('[records] a private record is broadcast', SERVER, "  self:_broadcast(e,only and function(player)return player==only end or nil)", "  self:_broadcast(e)", 'test_server'),
    ('[records] AfterReveal is ignored', SERVER, " if spec.AfterReveal==true and not only and e.Rarity then", " if false then", 'test_server'),
    ('[records] the record line has no lag behind the pull line', RULES, " RecordLag=.4, ", " RecordLag=0, ", 'test_rules'),
    # --- settings -------------------------------------------------------------------------------------------------------------------------------------------------
    ('setting ignored for other servers', SERVER, "return not(type(settings)=='table'and settings.GlobalAnnouncements==false)", "return true", 'test_settings'),
    ('a saved false turns back on', CFG, "if type(saved)=='table'and C.Valid(k,saved[k])then out[k]=saved[k]else out[k]=v end", "out[k]=type(saved)=='table'and C.Valid(k,saved[k])and saved[k]or v", 'test_settings'),
    # --- the chat lines -------------------------------------------------------------------------------------------------------------------------------------------
    ('names keep markup', RULES, "if cp==60 or cp==62 or cp==38 or cp==34 or cp==39 then -- < > & \" '", "if false then", 'test_rules'),
    ('rich text is not escaped', RULES, " local function esc(text)return rich and R.Escape(text)or tostring(text)end", " local function esc(text)return tostring(text)end", 'test_rules'),
    ('an other-server line is not gold', RULES, "function R.ChatColor(e)return e.Kind=='Pull'and", "function R.ChatColor(e)return e.Kind~='Record'and", 'test_rules'),
    ('the line is not in the rarity colour', RULES, "function R.ChatColor(e)return e.Kind=='Pull'and R.RarityColor(e.Rarity)or", "function R.ChatColor(e)return e.Kind=='Pull'and R.Gold or", 'test_rules'),
    ('long names are cut without an ellipsis', RULES, "..'…' -- (limit-1 characters", " -- (limit-1 characters", 'test_rules'),
    ('chat line not rate limited', RULES, " if#log>=burst then return false end", "", 'test_client'),
    # --- the client: chat only ------------------------------------------------------------------------------------------------------------------------------------
    ('the client builds a banner (an Instance)', CLIENT, " if not Rules.ChatAllowed(chatLog,os.clock())then return end\n", " if not Rules.ChatAllowed(chatLog,os.clock())then return end\n Instance.new('ScreenGui')\n", 'test_client'),
    ('the client plays a sound', CLIENT, " if not Rules.ChatAllowed(chatLog,os.clock())then return end\n", " if not Rules.ChatAllowed(chatLog,os.clock())then return end\n pcall(function()require(RS:WaitForChild('RarityRevealAudio')).Burst(5)end)\n", 'test_client'),
    ('the client writes both chats', CLIENT, "  if ok then return end -- (one line: the old chat below is only for when this did not work)", "  -- (no return)", 'test_client'),
    ('the client does not dedupe', CLIENT, " if seen[id]then return false end", "", 'test_client'),
    ('the client accepts an event without an id', CLIENT, " if not e or not e.Id or not remember(e.Id)then return end", " if not e then return end", 'test_client'),
    ('the client ignores the chat limit', CLIENT, " if not Rules.ChatAllowed(chatLog,os.clock())then return end\n", "\n", 'test_client'),
    ('the client trusts a sent rarity', CLIENT, " local e=Rules.Event(payload.Kind,payload)\n", " local e=Rules.Event(payload.Kind,payload);if e and payload.Rarity then e.Rarity=payload.Rarity end\n", 'test_client'),
]


def compiles(path):
    return subprocess.run(['/opt/luau/luau-compile', '--null', path], capture_output=True).returncode == 0


def run(suite):
    r = subprocess.run(['sh', HERE + '/run_one.sh', OUT, suite], capture_output=True, text=True, timeout=1800)
    log = ''
    try:
        log = open(os.path.join(OUT, suite + '.log'), encoding='utf-8', errors='replace').read()
    except OSError:
        pass
    return r.returncode, log


def main():
    survived = []
    only = sys.argv[2] if len(sys.argv) > 2 else ''
    for name, path, old, new, suite in MUTATIONS:
        if only and only not in name:
            continue
        original = open(path, encoding='utf-8').read()
        if original.count(old) != 1:
            print('MUTATION TARGET NOT FOUND (%d): %s' % (original.count(old), name))
            survived.append(name + ' (target not found)')
            continue
        valid = True
        try:
            open(path, 'w', encoding='utf-8').write(original.replace(old, new))
            valid = compiles(path)
            code, text = run(suite) if valid else (0, '')
        finally:
            open(path, 'w', encoding='utf-8').write(original)
        if not valid:
            print('%-56s INVALID MUTANT (does not compile)' % name)
            survived.append(name + ' (the mutant does not compile)')
            continue
        asserts = sum(1 for line in text.splitlines() if line.startswith('FAIL:'))
        status = 'caught by %s (%d failed checks)' % (suite, asserts) if code != 0 and asserts > 0 else ('crashed %s without a failed check' % suite if code != 0 else 'SURVIVED')
        print('%-56s %s' % (name, status))
        if code == 0 or asserts == 0:
            survived.append(name)
    print('%d mutations, %d survived' % (len([m for m in MUTATIONS if not only or only in m[0]]), len(survived)))
    if survived:
        print('SURVIVORS:', survived)
        sys.exit(1)


main()
