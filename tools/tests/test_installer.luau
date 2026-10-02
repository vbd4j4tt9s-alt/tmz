--!nocheck
-- Runs the real paste script against mock copies of the live scripts: install, idempotency, undo, redo, refusals.
local R=require('./roblox');local D=require('./inst_bundle');local BACKUP=D.BACKUP
local new=R.new
local fails,checks=0,0
local function check(c,msg)checks+=1;if not c then fails+=1;print('FAIL: '..msg)end end
local function world(mutate)
 local game=new('DataModel');game.Name='Game'
 local services={}
 local function service(n)local s=services[n];if not s then s=new(n);s.Name=n;s.Parent=game;services[n]=s end;return s end
 game.GetService=function(_,n)return service(n)end
 local running=false
 service('RunService').IsRunning=function()return running end
 local editor=service('ScriptEditorService')
 editor.GetEditorSource=function(_,item)return item.Source end
 editor.UpdateSourceAsync=function(_,item,fn)item.Source=fn(item.Source)end
 service('ChangeHistoryService').SetWaypoint=function()end
 service('ServerStorage')
 local items={}
 for _,s in ipairs(D.Scripts)do
  local parent=game
  local parts=string.split(s.Path,'/')
  for i=1,#parts-1 do parent=parent:FindFirstChild(parts[i])or(function()local f=new(i==1 and parts[i]or'Folder');f.Name=parts[i];f.Parent=parent;return f end)()end
  if not s.New then local item=new(s.Class);item.Name=parts[#parts];item.Source=mutate and mutate(s)or s.Before;item.Parent=parent;items[s.Path]=item end
 end
 -- Look scripts up by path each time: added scripts appear and disappear.
 setmetatable(items,{__index=function(_,path)local item=game;for n in string.gmatch(path,'[^/]+')do item=item and item:FindFirstChild(n)end;return item end})
 local env
 local cache={}
 local function req(m)
  if cache[m]==nil then local fn=assert(loadstring(m.Source,'='..m.Name));setfenv(fn,setmetatable({script=m},{__index=env}));cache[m]=fn()end
  return cache[m]
 end
 local printed={}
 env=setmetatable({game=game,Instance=R.Instance,require=req,print=function(...)printed[#printed+1]=table.concat({...},' ')end,task=R.task},{__index=_G})
 local function run(text)local fn=assert(loadstring(text,'=paste'));setfenv(fn,setmetatable({},{__index=env}));return pcall(fn)end
 return {Game=game,Items=items,Run=run,Printed=printed,Storage=service('ServerStorage'),SetRunning=function(v)running=v end,Req=req}
end
local function all(w,key)
 for _,s in ipairs(D.Scripts)do
  local item=w.Items[s.Path]
  if s.New and key=='Before'then if item~=nil then return false,s.Path end
  elseif not item or item.Source~=s[key]then return false,s.Path end
 end
 return true
end
-- 1) Fresh install.
local w=world();local t0=os.clock();local ok,err=w.Run(D.PASTE);local took=os.clock()-t0
check(ok,'paste runs: '..tostring(err));check(all(w,'After'),'all scripts now match the new sources')
local backup=w.Storage:FindFirstChild(BACKUP);check(backup~=nil,'backup created')
check(backup and backup:GetAttribute('State')=='Installed','state Installed')
check(backup and #backup.Sources:GetChildren()==#D.Scripts,'one backup entry per script')
print(('paste run took %.2fs in the CLI'):format(took))
-- 2) Pasting again is harmless.
ok,err=w.Run(D.PASTE);check(ok,'second paste ok: '..tostring(err));check(all(w,'After'),'still installed')
-- 3) Undo restores the exact originals; redo re-applies.
local installer=w.Req(backup.Installer)
ok,err=pcall(installer,'undo');check(ok,'undo ok: '..tostring(err));check(all(w,'Before'),'undo restores originals byte-for-byte');check(backup:GetAttribute('State')=='Undone','state Undone')
ok,err=pcall(installer,'undo');check(ok,'double undo ok')
ok,err=pcall(installer,'install');check(ok,'redo ok: '..tostring(err));check(all(w,'After'),'redo re-applies')
-- 4) Later hand edits block undo without changing anything.
local firstSpec=D.Scripts[#D.Scripts] -- an added script when the update has one
local first=w.Items[firstSpec.Path];first.Source=first.Source..'\n-- my edit'
ok,err=pcall(installer,'undo');check(not ok and tostring(err):find('later edits',1,true)~=nil,'undo refuses after hand edits')
for _,s in ipairs(D.Scripts)do if s~=firstSpec then check(w.Items[s.Path]~=nil and w.Items[s.Path].Source==s.After,'other scripts untouched by refused undo: '..s.Path)end end
-- 5) Play running refuses.
w.SetRunning(true);ok,err=pcall(installer,'undo');check(not ok and tostring(err):find('Stop Play',1,true)~=nil,'refuses during Play');w.SetRunning(false)
-- 6) A place whose script differs from the expected version: refuses, no changes, no backup.
local victim;local modified=0;for _,s in ipairs(D.Scripts)do if not s.New then victim=s;modified+=1 end end
local w2=world(function(s)if s==victim then return s.Before..' ' end end)
ok,err=w2.Run(D.PASTE);check(not ok and tostring(err):find('not the version',1,true)~=nil,'refuses unexpected version: '..tostring(err))
check(w2.Storage:FindFirstChild(BACKUP)==nil,'no backup left behind on refusal')
local unchanged=true;for i,s in ipairs(D.Scripts)do if s~=victim and not s.New and w2.Items[s.Path].Source~=s.Before then unchanged=false end;if s.New and w2.Items[s.Path]~=nil then unchanged=false end end
check(unchanged,'nothing written on refusal')
-- 6b) A backup left by a DIFFERENT build of the same release: refuse, never run the old installer.
local w4=world()
do local f=R.new('Folder');f.Name=BACKUP;f:SetAttribute('Build','an-older-build');f.Parent=w4.Storage end
ok,err=w4.Run(D.PASTE);check(not ok and tostring(err):find('older',1,true)~=nil and tostring(err):find('undo',1,true)~=nil,'older backup refused with undo steps: '..tostring(err))
check(all(w4,'Before'),'nothing written when an older backup exists')
-- 6c) This same build's backup made by a paste script that never set Build (undone since): recognised by its Installer, re-installed.
local w5=world();ok,err=w5.Run(D.PASTE);check(ok,'6c setup install: '..tostring(err))
local b5=w5.Storage:FindFirstChild(BACKUP);local sha=b5:GetAttribute('Build');b5:SetAttribute('Build',nil)
ok,err=pcall(w5.Req(b5.Installer),'undo');check(ok and all(w5,'Before'),'6c setup undo: '..tostring(err))
ok,err=w5.Run(D.PASTE);check(ok,'same build without Build attribute is re-used, not refused: '..tostring(err))
check(all(w5,'After')and b5:GetAttribute('State')=='Installed','...and installs from it')
check(b5:GetAttribute('Build')==sha and #w5.Storage:GetChildren()==1,'...stamps Build, no second backup')
-- 7) A write failure midway rolls everything back.
local w3=world();local writes=0
local editor=w3.Game:GetService('ScriptEditorService');local real=editor.UpdateSourceAsync
editor.UpdateSourceAsync=function(self,item,fn)writes+=1;if writes==math.min(3,modified)then error('simulated write failure')end;return real(self,item,fn)end
ok,err=w3.Run(D.PASTE);check(not ok and tostring(err):find('rolled back',1,true)~=nil,'failure reports rollback: '..tostring(err))
check(all(w3,'Before'),'rollback restored every script')
-- 8) Added scripts: a name clash at the destination refuses without changes.
local hasNew=false;for _,s in ipairs(D.Scripts)do if s.New then hasNew=true end end
if hasNew then
 local w4=world()
 for _,s in ipairs(D.Scripts)do if s.New then local parts=string.split(s.Path,'/');local parent=w4.Game;for i=1,#parts-1 do parent=parent:FindFirstChild(parts[i])end;local clash=R.new('Folder');clash.Name=parts[#parts];clash.Parent=parent;break end end
 ok,err=w4.Run(D.PASTE);check(not ok and tostring(err):find('already exists',1,true)~=nil,'name clash refused: '..tostring(err))
 check(w4.Storage:FindFirstChild(BACKUP)==nil,'no backup after clash')
 print('added-script paths covered')
end
print(('%d checks, %d failures'):format(checks,fails))
