"""R152 performance patch, switched off: a copy of a src tree with every optimisation of the patch undone, for run_perf152.sh's default
comparison (this checkout as it is against the same checkout without the patch). Both sides then have the same texts, the same tutorial and
whatever else lands later; only the patch differs. Usage: python3 perf152_off.py <src dir> <out dir> (out gets a full copy of src).

  * PropCache152 -> every Set / Scale writes (the cache remembers nothing); ViewCull152 -> nothing is ever hidden
  * every inline "write only when it changed" / "do not move what did not move" guard of the patch -> the write / move every frame, as before
  * the patch's semantics-neutral parts (reused lists, read-and-compare of a value read back) stay: they cannot change what is drawn

An anchor that is not found exactly as often as listed stops the run (exit 1): the patch's code was edited, so this list must follow it."""
import os, shutil, sys

PASS_CACHE = '''-- (run_perf152.sh: the patch switched off -- every write goes through, nothing is remembered)
local M={}
local function same(a,b)return a==b end
M.Same=same
function M.new()
 local C={}
 function C.Set(o,k,v)o[k]=v end
 function C.Scale(o,k,x,y)o[k]=UDim2.fromScale(x,y)end
 function C.Forget(_o)end
 return C
end
return M
'''
PASS_CULL = '''-- (run_perf152.sh: the patch switched off -- nothing is ever out of view)
local M={}
M.Window=.15;M.Slack=0;M.SlackStuds=0
function M.Hidden()return false end
return M
'''
RS = 'ReplicatedStorage/'
SP = 'StarterPlayer/StarterPlayerScripts/'
# (file, old, new, times)
EDITS = [
 (RS+'VoidPackFx.lua', " if key[k]~=v then key[k]=v;o[k]=v end", " key[k]=v;o[k]=v", 1),
 (RS+'RarePullScenes.lua', " if trans>=1 and self.Gone[p]then return end", " if false then return end", 1),
 (RS+'RarePullScenes.lua', " if trans>=1 and r.Gone then return end", " if false then return end", 1),
 (RS+'RarePullScenes.lua', " if self.PackAt~=at then self.PackAt=at;pcall(function()self.Pack:PivotTo(at)end)end",
                           " self.PackAt=at;pcall(function()self.Pack:PivotTo(at)end)", 1),
 (RS+'RarePullCard.lua', "  if yaw~=self.SeedYawShown then", "  if true then", 1),
 (SP+'SeedPackClient.client.lua', "    if record.SeedPivot~=seedFrame then record.Seed:PivotTo(seedFrame);record.SeedPivot=seedFrame end",
                                  "    record.Seed:PivotTo(seedFrame);record.SeedPivot=seedFrame", 1),
 (RS+'RevealFlourish.lua', " if not list then list={};for _,d in ipairs(self.Folder:GetDescendants())do",
                           " if true then list={};for _,d in ipairs(self.Folder:GetDescendants())do", 1),
 (RS+'RarePullAudio.lua', "local function setLevel(v,x)if wrote[v]~=x then wrote[v]=x;v.Volume=x end end",
                          "local function setLevel(v,x)wrote[v]=x;v.Volume=x end", 1),
 (RS+'RarePullAudio.lua', "if wrote[fx]~=db then wrote[fx]=db;fx.LowGain=db;fx.MidGain=db;fx.HighGain=db end",
                          "wrote[fx]=db;fx.LowGain=db;fx.MidGain=db;fx.HighGain=db", 1),
 (SP+'PackOpeningFeedback.client.lua', "local function vis(o,v)if shown[o]~=v then shown[o]=v;o.Visible=v end;return v end",
                                       "local function vis(o,v)shown[o]=v;o.Visible=v;return v end", 1),
 (RS+'RarityRevealScreen.lua', "local function vis(o,v)if shown[o]~=v then shown[o]=v;o.Visible=v end;return v end",
                               "local function vis(o,v)shown[o]=v;o.Visible=v;return v end", 1),
 (SP+'BeastAnimation.client.lua', "if p.Placed~=cf then p.Placed=cf;table.insert(moveParts,p.Part);table.insert(moveFrames,cf)end",
                                  "p.Placed=cf;table.insert(moveParts,p.Part);table.insert(moveFrames,cf)", 1),
 (RS+'KeeperFx152.lua', "if it.Rate~=r then it.Rate=r;e.Rate=r end", "it.Rate=r;e.Rate=r", 1),
 (RS+'KeeperFx152.lua', "local en=r>0;if it.On~=en then it.On=en;e.Enabled=en end", "local en=r>0;it.On=en;e.Enabled=en", 1),
 (RS+'KeeperFx152.lua', "if t.On~=want then t.On=want;t.Trail.Enabled=want end", "t.On=want;t.Trail.Enabled=want", 1),
 (RS+'KeeperFx.lua', "if not lit[self]then lit[self]=true;self.Light.Enabled=true end", "lit[self]=true;self.Light.Enabled=true", 1),
 (RS+'KeeperFx.lua', "if self.LitB~=b then self.LitB=b;self.Light.Brightness=b end", "self.LitB=b;self.Light.Brightness=b", 1),
 (RS+'KeeperFx.lua', "if self.AmbientRate~=r then self.AmbientRate=r;self.Ambient.Rate=r end", "self.AmbientRate=r;self.Ambient.Rate=r", 1),
 (RS+'KeeperSleep.lua', "if was[1] ~= fade then was[1] = fade; label.TextTransparency = fade end", "was[1] = fade; label.TextTransparency = fade", 1),
 (RS+'KeeperSleep.lua', "if was[2] ~= stroke then was[2] = stroke; label.TextStrokeTransparency = stroke end",
                        "was[2] = stroke; label.TextStrokeTransparency = stroke", 1),
 (RS+'KeeperSurge.lua', " if tr>=1 then\n  for k,p in ipairs(self.Parts)do", " if false then\n  for k,p in ipairs(self.Parts)do", 1),
 (RS+'KeeperSurge.lua', "if shown[k]~=tr then shown[k]=tr;p.Transparency=tr end", "shown[k]=tr;p.Transparency=tr", 2),
 (SP+'HubLife151.client.lua', "if v~=e.Wrote and v~=s.Volume then s.Volume=v end", "if v~=s.Volume then s.Volume=v end", 1),
]

def main():
    src, out = sys.argv[1], sys.argv[2]
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(src, out)
    bad = []
    files = {}
    for rel, old, new, times in EDITS:
        path = os.path.join(out, rel)
        if rel not in files:
            files[rel] = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        text = files[rel]
        n = text.count(old) if text is not None else 0
        if n != times:
            bad.append('%s: found %d times, want %d: %s' % (rel, n, times, old.split('\n')[0][:90]))
            continue
        files[rel] = text.replace(old, new)
    if bad:
        print('perf152_off: the patch\'s code changed, update perf152_off.py:')
        for b in bad:
            print('  ' + b)
        sys.exit(1)
    for rel, text in files.items():
        open(os.path.join(out, rel), 'w', encoding='utf-8').write(text)
    open(os.path.join(out, RS + 'PropCache152.lua'), 'w', encoding='utf-8').write(PASS_CACHE)
    open(os.path.join(out, RS + 'ViewCull152.lua'), 'w', encoding='utf-8').write(PASS_CULL)
    print('perf152_off: %d guards and the two helpers switched off in %s' % (len(EDITS), out))

if __name__ == '__main__':
    main()
