#!/usr/bin/env python3
"""R153 (owner: "make the best pull of the day refresh every 10 minutes and its a local server only thing to increase performance"): static checks that BEST PULL
never goes through a store, a save or another server. Reads the sources of the checkout; prints one "ok:" line per check and exits 1 on the first failure.
Usage: python3 check_best_pull_local.py REPO
Checked:
  * no hub script mentions MessagingService or a DataStore (the only shared store is HubDisplayStore's MemoryStore, which is BIGGEST FRUIT's);
  * HubDisplayStore.Merge refuses anything but the fruit before it counts a request;
  * HubDisplayBoard: only the fruit board has a Remote slot and can be Unsynced; a window clears the pull board only, a day the fruit board only;
  * HubDisplayService: the shared-store code (_merge, _needsWrite, _push, _poll) works on the SHARED list (the fruit) only; the code that handles a pull and its window
    (NotePull, InjectPull, Window, _syncWindow, _restamp, SleepSeconds, _clock, _text, _stamp) touches no store, no MessagingService, no DataStore, no MemoryStore;
    the step looks at the window before the preview check; the loop sleeps through SleepSeconds;
  * HubDisplayRules: no store form of a pull (StorePull is gone), the shared document is {v, fruit};
  * PullAnnounceRules.RecordScope never returns 'Global'; PullAnnouncer.Send never publishes a BestPull record."""
import re
import sys

REPO = sys.argv[1]
SRV = REPO + '/src/ServerScriptService/ChestChaseServer/'
RS = REPO + '/src/ReplicatedStorage/'


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def code(src):
    """The source without its comments (a line comment starts at the first `--`; none of these scripts has `--` inside a string)."""
    return '\n'.join(line.split('--')[0] for line in src.split('\n'))


def fail(msg):
    print('FAIL: ' + msg)
    sys.exit(1)


def ok(msg):
    print('ok: ' + msg)


def body(src, header):
    """The text of the function whose header line starts with `header` (up to the next line that is exactly 'end')."""
    i = src.find(header)
    if i < 0:
        fail('function not found: ' + header)
    eol = src.find('\n', i)
    if src[i:eol].rstrip().endswith('end'):  # (a one-line function)
        return src[i:eol]
    j = src.find('\nend\n', i)
    if j < 0:
        fail('function end not found: ' + header)
    return src[i:j + 5]


hub_files = ['HubDisplayStore', 'HubDisplayBoard', 'HubDisplayService', 'HubDisplayArt', 'HubDisplayAvatar']
for f in hub_files:
    src = code(read(SRV + f + '.lua'))
    if 'MessagingService' in src or 'DataStore' in src:
        fail(f + ' uses MessagingService or a DataStore')
for path in [RS + 'HubDisplayRules.lua', REPO + '/src/StarterPlayer/StarterPlayerScripts/HubDisplayClient.client.lua']:
    src = code(read(path))
    if 'MessagingService' in src or 'DataStore' in src or 'MemoryStore' in src:
        fail(path + ' uses a store')
ok('no hub script uses MessagingService or a DataStore (MemoryStoreService only in HubDisplayStore: BIGGEST FRUIT\'s shared board)')
for f in ['HubDisplayBoard', 'HubDisplayService', 'HubDisplayArt', 'HubDisplayAvatar']:
    if 'MemoryStoreService' in code(read(SRV + f + '.lua')):
        fail(f + ' uses MemoryStoreService (only HubDisplayStore may)')
ok('only HubDisplayStore reaches MemoryStoreService')

store = code(read(SRV + 'HubDisplayStore.lua'))
merge = body(store, 'function S:Merge(')
first = merge.split('\n')[1]
if "if kind~='Fruit'then return false,'local only'end" not in first:
    fail("HubDisplayStore.Merge does not refuse a pull as its first statement: " + first.strip())
if 'request(' in first:
    fail('the refusal comes after a request')
ok("HubDisplayStore.Merge refuses anything but the fruit before it counts a request ('local only')")

board = code(read(SRV + 'HubDisplayBoard.lua'))
if "function B:MergeRemote(kind,rec)\n if kind~='Fruit'then return false end" not in board:
    fail('HubDisplayBoard.MergeRemote takes a pull')
if "function B:Unsynced(kind)\n if kind~='Fruit'then return false end" not in board:
    fail('HubDisplayBoard.Unsynced can say a pull needs writing')
if 'self.Window=window;self.Boards.Pull=fresh()' not in board or 'self.Boards.Fruit=fresh()' not in board:
    fail('HubDisplayBoard: a window must clear the pull board, a day the fruit board')
sd = body(board, 'function B:SetDay(')
sw = body(board, 'function B:SetWindow(')
if 'Boards.Pull' in sd or 'Boards.Fruit' in sw or 'Boards={' in sd or 'Boards={' in sw:
    fail('HubDisplayBoard: SetDay touches the pull board or SetWindow the fruit board')
ok('HubDisplayBoard: the pull board has no Remote and is never Unsynced; a window clears it alone, a day clears the fruit board alone')

svc = code(read(SRV + 'HubDisplayService.lua'))
for name in ['_merge', '_needsWrite', '_push', '_poll']:
    b = body(svc, 'function S:' + name + '(')
    if 'ipairs(KINDS)' in b or "'Pull'" in b:
        fail('HubDisplayService:' + name + ' (the shared store) works on the pull board')
if svc.count('ipairs(SHARED)') != 2:
    fail('HubDisplayService: _needsWrite and _push must loop over SHARED (the fruit) only')
ok('HubDisplayService: the shared-store code (_merge, _needsWrite, _push, _poll) never touches the pull board')
pull_functions = ['S:NotePull(', 'S:InjectPull(', 'S:Window(', 'S:_syncWindow(', 'S:_restamp(', 'S:SleepSeconds(', 'S:_clock(', 'S:_text(', 'S:_stamp(']
for header in pull_functions:
    b = body(svc, 'function ' + header)
    for word in ['self.Store', 'Store:', 'Messaging', 'DataStore', 'MemoryStore', 'GetService', 'SHARED']:
        if word in b:
            fail('HubDisplayService ' + header + ' mentions ' + word)
ok('HubDisplayService: the code that handles a pull and its window (' + ', '.join(h[2:-1] for h in pull_functions) + ') touches no store, no MessagingService, no DataStore')
step = body(svc, 'function S:Step(')
if step.find('self:_syncWindow()') < 0 or step.find('self:_syncWindow()') > step.find('self:_preview()'):
    fail('HubDisplayService.Step must look at the pull window before the preview check')
if 'task.wait(self:SleepSeconds())' not in svc:
    fail('the loop must sleep through SleepSeconds (it wakes just after each window mark)')
if re.search(r'task\.wait\(S\.LoopSeconds\)', svc):
    fail('the loop still sleeps a flat LoopSeconds')
ok('the step looks at the window before the preview check, and the loop sleeps through SleepSeconds (no per-frame work, no polling for the pull)')

rules = code(read(RS + 'HubDisplayRules.lua'))
if 'function R.StorePull' in rules or 'out.pull=' in body(rules, 'function R.StoreDoc(') or 'out.pull=' in body(rules, 'function R.CleanDoc('):
    fail('HubDisplayRules still has a store form of a pull')
ok('HubDisplayRules: a pull has no store form; the shared document is {v, fruit}')

announce = code(read(RS + 'PullAnnounceRules.lua'))
scope = body(announce, 'function R.RecordScope(')
if "return'Global'" in scope or 'return "Global"' in scope:
    fail("PullAnnounceRules.RecordScope can return 'Global'")
ok("PullAnnounceRules.RecordScope never returns 'Global': a record is this server's or nobody's")
announcer = code(read(SRV + 'PullAnnouncer.lua'))
if "global=scope=='Global'and e.Record~='BestPull'" not in announcer:
    fail('PullAnnouncer.Send may publish a BestPull record')
ok('PullAnnouncer.Send never publishes a BestPull record, whatever Scope is asked for')
