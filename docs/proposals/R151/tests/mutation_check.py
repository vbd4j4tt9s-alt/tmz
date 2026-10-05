"""R151 mutation check: breaks the announcer on purpose, one change at a time, and runs the suite that must notice. Every mutation must make that suite FAIL.
Usage: python3 mutation_check.py SCRATCHDIR [name filter]   (needs /opt/luau; the source is restored after every mutation, also when this script is interrupted)"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, '../../../..'))
S = REPO + '/src'
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
SERVER = S + '/ServerScriptService/ChestChaseServer/PullAnnouncer.lua'
RULES = S + '/ReplicatedStorage/PullAnnounceRules.lua'
CLIENT = S + '/StarterPlayer/StarterPlayerScripts/PullAnnouncerClient.client.lua'
PDS = S + '/ServerScriptService/ChestChaseServer/PlayerDataService.lua'
CFG = S + '/ReplicatedStorage/SettingsConfig.lua'
NOTICES = S + '/StarterPlayer/StarterPlayerScripts/HudNotices.client.lua'

MUTATIONS = [
    # (name, file, old, new, suite that must fail)
    ('TEST packs announce', SERVER, " if wasTest then return false,'test pack'end\n", "\n", 'test_server'),
    ('hook ignores the TEST flag', PDS, "OnOpened(player,pack,reward,testSeed~=nil)", "OnOpened(player,pack,reward,false)", 'test_server'),
    ('no reveal delay', SERVER, "task.delay(ok and type(delay)=='number'and delay or 5,function()", "task.delay(0,function()", 'test_server'),
    ('Legendary also goes global', RULES, "GlobalMinRarity='Secret',", "GlobalMinRarity='Legendary',", 'test_rules'),
    ('Mythic below the in-server threshold', RULES, "InServerMinRarity='Legendary',", "InServerMinRarity='Mythic',", 'test_rules'),
    ('origin server shows its own global message', SERVER, "if data.j==self.JobId then self.Stats.Origin+=1;return end", "", 'test_server'),
    ('no dedupe', SERVER, "elseif self:_seen(data.j..':'..e.Id)then self.Stats.Repeat+=1", "elseif false then self.Stats.Repeat+=1", 'test_server'),
    ('stale messages accepted', RULES, "return age<=R.Setting('StaleSeconds')and age>=-R.Setting('FutureSeconds')", "return true", 'test_rules'),
    ('no publish gap', SERVER, "local wait=Rules.Setting('PublishGapSeconds')-(self.Clock()-self.LastPublish)", "local wait=0", 'test_server'),
    ('failed publishes retried forever', SERVER, "if item.Attempts<A.MaxAttempts then", "if true then", 'test_server'),
    ('subscription never retried', SERVER, "task.delay(wait,function()self:_subscribe(attempt+1)end)", "", 'test_server'),
    ('rarity trusted from the message', RULES, " e.SeedId,e.SeedName,e.Rarity,e.Stage=info.Id,info.Name,info.Rarity,info.Stage", " e.SeedId,e.SeedName,e.Rarity,e.Stage=info.Id,info.Name,fields.Rarity or info.Rarity,info.Stage", 'test_rules'),
    ('names keep markup', RULES, "if cp==60 or cp==62 or cp==38 or cp==34 or cp==39 then -- < > & \" '", "if false then", 'test_rules'),
    ('setting ignored for other servers', SERVER, "return not(type(settings)=='table'and settings.GlobalAnnouncements==false)", "return true", 'test_settings'),
    ('a saved false turns back on', CFG, "if type(saved)=='table'and C.Valid(k,saved[k])then out[k]=saved[k]else out[k]=v end", "out[k]=type(saved)=='table'and C.Valid(k,saved[k])and saved[k]or v", 'test_settings'),
    ('own pull makes a sound', CLIENT, " if e.Self or not Reveal then return end", " if not Reveal then return end", 'test_client'),
    ('Effects 0 still asks for a sound', CLIENT, "if ok and volume==0 then return end end", "end", 'test_client'),
    ('queue unlimited', RULES, " MaxWaiting=3,", " MaxWaiting=6,", 'test_rules'),
    ('banner ignores ReducedMotion', CLIENT, "local timing=Rules.Timing(#queue.Items,reduced())\n local box", "local timing=Rules.Timing(#queue.Items,false)\n local box", 'test_client'),
    ('HudNotices ignores the banner', NOTICES, "top=math.max(top,tonumber(pg:GetAttribute('PullBannerBottom'))or 0)", "", 'test_client'),
    ('banner ignores the tutorial card', CLIENT, " return math.max(top,tonumber(pg:GetAttribute('TutorialCardBottom'))or 0)", " return top", 'test_layout'),
    ('banner ignores the tutorial card (client test)', CLIENT, " return math.max(top,tonumber(pg:GetAttribute('TutorialCardBottom'))or 0)", " return top", 'test_client'),
    ('banner placed over the notice rows', RULES, "local first=Notice.Calculate(w,h,top or 0,{}).Bottom", "local first=8", 'test_layout'),
    ('chat line not rate limited', RULES, " if#log>=burst then return false end", "", 'test_client'),
    ('headshot asked every time', CLIENT, " if entry then\n  if entry.Image then", " if false then\n  if entry.Image then", 'test_client'),
    ('shine / sparkles keep running when idle', CLIENT, " if t>=1 then if burst then burst:Destroy();burst=nil end;return true end", " if false then return true end", 'test_client'),
]


def run(suite):
    r = subprocess.run(['sh', HERE + '/run_one.sh', OUT, suite], capture_output=True, text=True, timeout=1800)
    return r.returncode, (r.stdout + r.stderr)


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
        try:
            open(path, 'w', encoding='utf-8').write(original.replace(old, new))
            code, text = run(suite)
        finally:
            open(path, 'w', encoding='utf-8').write(original)
        status = 'caught by ' + suite if code != 0 else 'SURVIVED'
        print('%-48s %s' % (name, status))
        if code == 0:
            survived.append(name)
    print('%d mutations, %d survived' % (len([m for m in MUTATIONS if not only or only in m[0]]), len(survived)))
    if survived:
        print('SURVIVORS:', survived)
        sys.exit(1)


main()
